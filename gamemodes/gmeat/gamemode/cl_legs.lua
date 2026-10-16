local cvLegs = CreateClientConVar("gmeat_legs", "1", true, false, "Show your own legs when you look down (0 = off).", 0, 1)

GMEAT.Legs = {
	Back = 20,
	Lean = 12,
}
local CFG = GMEAT.Legs

local ANCHOR = "ValveBiped.Bip01_Spine"
local HIDE_FROM = {
	["ValveBiped.Bip01_Spine1"] = true,
	["ValveBiped.Bip01_Spine2"] = true,
	["ValveBiped.Bip01_Spine4"] = true,
	["ValveBiped.Bip01_Neck1"] = true,
	["ValveBiped.Bip01_Head1"] = true,
	["ValveBiped.Bip01_L_Clavicle"] = true,
	["ValveBiped.Bip01_R_Clavicle"] = true,
	["ValveBiped.Bip01_L_UpperArm"] = true,
	["ValveBiped.Bip01_R_UpperArm"] = true,
}
local UPPER_NAMES = {}
do
	local B = "ValveBiped.Bip01_"
	for _, n in ipairs({ "Spine1", "Spine2", "Spine3", "Spine4", "Neck1", "Head1" }) do UPPER_NAMES[#UPPER_NAMES + 1] = B .. n end
	for _, side in ipairs({ "L_", "R_" }) do
		for _, n in ipairs({ "Clavicle", "UpperArm", "Forearm", "Hand", "Wrist", "Ulna", "Elbow", "Shoulder", "Bicep", "Trapezius", "Pectoral" }) do
			UPPER_NAMES[#UPPER_NAMES + 1] = B .. side .. n
		end
		for _, f in ipairs({ "0", "01", "02", "1", "11", "12", "2", "21", "22", "3", "31", "32", "4", "41", "42" }) do
			UPPER_NAMES[#UPPER_NAMES + 1] = B .. side .. "Finger" .. f
		end
	end
end

local LEG_BONES = {
	"ValveBiped.Bip01_Pelvis",
	"ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_L_Foot",
	"ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_R_Foot",
}
local ZERO = Vector(0, 0, 0)

local legs = { ent = nil, model = nil, hidden = nil, anchor = nil, legBones = {} }

local function shouldDraw(ply)
	if not cvLegs:GetBool() or not IsValid(ply) or not ply:Alive() then return false end
	if ply:ShouldDrawLocalPlayer() or GetViewEntity() ~= ply then return false end
	if ply:InVehicle() or ply:GetObserverMode() ~= OBS_MODE_NONE then return false end
	return true
end

local function removeLegs()
	if IsValid(legs.ent) then legs.ent:Remove() end
	legs.ent, legs.model, legs.hidden, legs.anchor = nil, nil, nil, nil
	legs.legBones = {}
end

local function underHidden(ent, bone)
	local guard = 0
	while bone and bone >= 0 and guard < 128 do
		if HIDE_FROM[ent:GetBoneName(bone)] then return true end
		bone = ent:GetBoneParent(bone)
		guard = guard + 1
	end
	return false
end

local function buildLegs(ply)
	removeLegs()
	local model = ply:GetModel()
	if not model or model == "" then return end
	local ent = ClientsideModel(model, RENDERGROUP_OPAQUE)
	if not IsValid(ent) then return end
	legs.ent, legs.model = ent, model
	ent:SetNoDraw(false)
	ent:DrawShadow(false)
	ent:DestroyShadow()
	ent:SetSkin(ply:GetSkin())
	for _, bg in ipairs(ply:GetBodyGroups() or {}) do ent:SetBodygroup(bg.id, ply:GetBodygroup(bg.id)) end
	ent.GetPlayerColor = function() return IsValid(ply) and ply:GetPlayerColor() or Vector(1, 1, 1) end
	ent:SetRenderBounds(Vector(-40, -40, -10), Vector(40, 40, 90))

	ent:AddCallback("BuildBonePositions", function(self, count)
		if not legs.hidden or not legs.anchor then return end
		local am = self:GetBoneMatrix(legs.anchor)
		if not am then return end
		local point = am:GetTranslation()
		for _, b in ipairs(legs.hidden) do
			local m = self:GetBoneMatrix(b)
			if m then
				m:Scale(ZERO)
				m:SetTranslation(point)
				self:SetBoneMatrix(b, m)
			end
		end
	end)

	ent.RenderOverride = function(self, flags)
		if flags and STUDIO_SHADOWDEPTHTEXTURE and bit.band(flags, STUDIO_SHADOWDEPTHTEXTURE) ~= 0 then return end
		if not shouldDraw(LocalPlayer()) then return end
		legs.place(self, LocalPlayer())
		self:InvalidateBoneCache()
		if not legs.hidden then
			self:SetupBones()
			legs.findBones(self)
			if not legs.hidden then return end
			self:InvalidateBoneCache()
		end
		self:DrawModel()
	end
end

function legs.place(ent, ply)
	if not IsValid(ent) or not IsValid(ply) then return end
	local eye, view = EyePos(), EyeAngles()
	local offset = ply.GetCurrentViewOffset and ply:GetCurrentViewOffset()
		or ((ply:Crouching() and ply:GetViewOffsetDucked()) or ply:GetViewOffset())
	local yaw = Angle(0, view.y, 0)
	local feet = Vector(eye.x, eye.y, eye.z - offset.z)
	ent:SetPos(feet - yaw:Forward() * CFG.Back)
	ent:SetAngles(Angle(-CFG.Lean, view.y, 0))
end

local function probeBones(src)
	local info = { count = 0, invalid = 0, hidden = {}, anchor = nil }
	if not IsValid(src) then return info end
	info.count = src:GetBoneCount() or 0
	for b = 0, info.count - 1 do
		local name = src:GetBoneName(b)
		if not name or name == "" or name == "__INVALIDBONE__" then
			info.invalid = info.invalid + 1
		elseif underHidden(src, b) then
			info.hidden[#info.hidden + 1] = b
		end
	end
	local seen = {}
	for _, b in ipairs(info.hidden) do seen[b] = true end
	for _, name in ipairs(UPPER_NAMES) do
		local b = src:LookupBone(name)
		if b and not seen[b] then
			seen[b] = true
			info.hidden[#info.hidden + 1] = b
		end
	end
	info.anchor = src:LookupBone(ANCHOR) or src:LookupBone("ValveBiped.Bip01_Pelvis")
	return info
end
legs.probeBones = probeBones

function legs.findBones(src)
	if not IsValid(src) then return false end
	local info = probeBones(src)
	if info.count < 2 then return false end
	local hidden, anchor = info.hidden, info.anchor
	if not anchor or #hidden == 0 then return false end
	legs.anchor, legs.hidden = anchor, hidden
	legs.legBones = {}
	for _, name in ipairs(LEG_BONES) do
		local b = src:LookupBone(name)
		if b then legs.legBones[#legs.legBones + 1] = b end
	end
	return true
end

hook.Add("Think", "Gmeat_Legs", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	if not cvLegs:GetBool() then
		if legs.ent then removeLegs() end
		return
	end
	if not IsValid(legs.ent) or legs.model ~= ply:GetModel() then buildLegs(ply) end
	local ent = legs.ent
	if not IsValid(ent) then return end

	if not legs.hidden and ply:GetModel() == legs.model then
		if not legs.findBones(ply) then legs.findBones(ent) end
	end

	local mat = ply:GetMaterial() or ""
	if mat == "" then mat = GMEAT.PlayerMaterial or "" end
	if ent:GetMaterial() ~= mat then ent:SetMaterial(mat) end
	if not shouldDraw(ply) then return end

	legs.place(ent, ply)

	ent:SetSequence(ply:GetSequence())
	ent:SetCycle(ply:GetCycle())
	ent:SetPlaybackRate(0)
	for i = 0, ply:GetNumPoseParameters() - 1 do
		local name = ply:GetPoseParameterName(i)
		local lo, hi = ply:GetPoseParameterRange(i)
		if name and lo and hi then ent:SetPoseParameter(name, lo + (hi - lo) * ply:GetPoseParameter(name)) end
	end

	for _, b in ipairs(legs.legBones) do
		ent:ManipulateBoneAngles(b, ply:GetManipulateBoneAngles(b) or angle_zero)
	end
end)

hook.Add("ShutDown", "Gmeat_Legs", removeLegs)

concommand.Add("gmeat_legs_debug", function()
	local ply = LocalPlayer()
	local ent = legs.ent
	print("[Gmeat legs] setting gmeat_legs = " .. cvLegs:GetString() .. ", should draw now: " .. tostring(IsValid(ply) and shouldDraw(ply)))
	print("  player model " .. tostring(IsValid(ply) and ply:GetModel()) .. ", player bones " .. tostring(IsValid(ply) and ply:GetBoneCount()))
	print("  leg model valid " .. tostring(IsValid(ent)) .. (IsValid(ent) and (", model " .. tostring(ent:GetModel()) .. ", bones " .. tostring(ent:GetBoneCount())
		.. ", position " .. tostring(ent:GetPos()) .. ", material '" .. tostring(ent:GetMaterial()) .. "'") or ""))
	print("  hidden upper-body bones " .. (legs.hidden and #legs.hidden or "none yet") .. ", anchor bone " .. tostring(legs.anchor)
		.. (legs.anchor and IsValid(ent) and (" (" .. tostring(ent:GetBoneName(legs.anchor)) .. ")") or ""))
	for label, src in pairs({ player = ply, ["leg model"] = ent }) do
		if IsValid(src) then
			local info = probeBones(src)
			local names = {}
			for b = 0, math.min(info.count, 6) - 1 do names[#names + 1] = b .. "=" .. tostring(src:GetBoneName(b)) end
			print(string.format("  probe %s: %d bones, %d unnamed, %d to hide, anchor %s, Spine1 %s, first bones: %s", label, info.count, info.invalid,
				#info.hidden, tostring(info.anchor), tostring(src:LookupBone("ValveBiped.Bip01_Spine1")), table.concat(names, " ")))
		end
	end
end)
