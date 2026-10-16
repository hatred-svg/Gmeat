local backModels = {}

local function getBackModel(kind)
	local model = GMEAT.CarryModels[kind]
	if not model then return end
	local ent = backModels[kind]
	if not IsValid(ent) then
		ent = ClientsideModel(model, RENDERGROUP_OPAQUE)
		if not IsValid(ent) then return end
		ent:SetNoDraw(true)
		backModels[kind] = ent
	end
	return ent
end

hook.Add("PostPlayerDraw", "Gmeat_CarryOnBack", function(ply)
	local kind = ply:GetNWString("GmeatCarrying", "")
	if kind == "" or not ply:Alive() then return end
	local ent = getBackModel(kind)
	if not ent then return end
	local bone = ply:LookupBone("ValveBiped.Bip01_Spine2")
	if not bone then return end
	local matrix = ply:GetBoneMatrix(bone)
	if not matrix then return end

	local yaw = Angle(0, ply:GetRenderAngles().y, 0)
	local pos = matrix:GetTranslation() - yaw:Forward() * 10
	local ang = Angle(yaw.p, yaw.y + 90, 90)
	ent:SetPos(pos)
	ent:SetAngles(ang)
	ent:SetupBones()
	ent:DrawModel()
end)

hook.Add("PreDrawHalos", "Gmeat_CarrierHalo", function()
	local byKind = {}
	for _, ply in ipairs(player.GetAll()) do
		local kind = ply:GetNWString("GmeatCarrying", "")
		if kind ~= "" and ply:Alive() and ply ~= LocalPlayer() then
			byKind[kind] = byKind[kind] or {}
			table.insert(byKind[kind], ply)
		end
	end
	for kind, list in pairs(byKind) do
		halo.Add(list, GMEAT.CarryColors[kind] or color_white, 2, 2, 1, true, true)
	end
end)
