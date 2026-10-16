GMEAT.Flinch = {
	BodyMin = 10, BodyMax = 38,
	BodyPerDamage = 0.55,
	Snap = 0.035,
	Settle = 0.11,
	Bounce = 13,
	Duration = 0.6,
	Invert = false,
}
local CFG = GMEAT.Flinch

local B = function(n) return "ValveBiped.Bip01_" .. n end
local CHAINS = {
	[B"Head1"] = { { B"Head1", 1 }, { B"Neck1", 0.6 }, { B"Spine2", 0.2 } },
	[B"Neck1"] = { { B"Head1", 0.8 }, { B"Neck1", 0.8 }, { B"Spine2", 0.3 } },
	[B"Spine2"] = { { B"Spine2", 0.7 }, { B"Spine1", 0.5 }, { B"Head1", 0.35 } },
	[B"Spine1"] = { { B"Spine1", 0.7 }, { B"Spine", 0.5 }, { B"Spine2", 0.3 }, { B"Head1", 0.25 } },
	[B"Spine"] = { { B"Spine", 0.7 }, { B"Spine1", 0.4 }, { B"Head1", 0.2 } },
	[B"Pelvis"] = { { B"Spine", 0.6 }, { B"Spine1", 0.3 } },
}
for _, side in ipairs({ "L", "R" }) do
	local s = side .. "_"
	CHAINS[B(s .. "UpperArm")] = { { B(s .. "UpperArm"), 1 }, { B(s .. "Clavicle"), 0.4 } }
	CHAINS[B(s .. "Forearm")] = { { B(s .. "Forearm"), 1 }, { B(s .. "UpperArm"), 0.5 } }
	CHAINS[B(s .. "Hand")] = { { B(s .. "Hand"), 1 }, { B(s .. "Forearm"), 0.6 } }
	CHAINS[B(s .. "Thigh")] = { { B(s .. "Thigh"), 1 }, { B"Pelvis", 0.15 } }
	CHAINS[B(s .. "Calf")] = { { B(s .. "Calf"), 1 }, { B(s .. "Thigh"), 0.5 } }
	CHAINS[B(s .. "Foot")] = { { B(s .. "Foot"), 1 }, { B(s .. "Calf"), 0.6 } }
end
local CANDIDATES = {}
for name in pairs(CHAINS) do CANDIDATES[#CANDIDATES + 1] = name end

local CAMERA_REGION = { head = 1.5, torso = 1, limb = 0.55, fall = 1.2, blast = 1.35 }

local function regionOf(name)
	if name == B"Head1" or name == B"Neck1" then return "head" end
	if string.find(name, "Spine", 1, true) or name == B"Pelvis" then return "torso" end
	return "limb"
end

local function nearestBone(ent, pos)
	local best, bestDist
	for _, name in ipairs(CANDIDATES) do
		local id = ent:LookupBone(name)
		local bp = id and ent:GetBonePosition(id)
		if bp then
			local d = bp:DistToSqr(pos)
			if not bestDist or d < bestDist then best, bestDist = name, d end
		end
	end
	return best
end

local function flinchAngle(ent, bone, pos, dir, degrees)
	local m = ent:GetBoneMatrix(bone)
	if not m then return end
	local pivot = m:GetTranslation()
	local arm = pos - pivot
	local axis = arm:Cross(dir)
	if axis:Length() < 0.1 * math.max(arm:Length(), 1) then
		axis = Vector(0, 0, 1):Cross(dir)
		if axis:IsZero() then axis = Vector(1, 0, 0) end
	end
	axis:Normalize()
	if CFG.Invert then axis = -axis end
	local rot = Matrix()
	rot:SetAngles(m:GetAngles())
	local localAxis = rot:GetInverseTR() * axis
	local a = Angle(0, 0, 0)
	a:RotateAroundAxis(localAxis, degrees)
	return a
end

local function envelope(t)
	if t < CFG.Snap then return math.sin(t / CFG.Snap * math.pi / 2) end
	local x = t - CFG.Snap
	return math.exp(-x / CFG.Settle) * math.cos(x * CFG.Bounce)
end

local flinching = {}

function GM:BodyFlinch(ent, pos, dir, dmg, kind)
	if not IsValid(ent) or not ent:Alive() then return nil end
	local deg = math.Clamp(CFG.BodyMin + dmg * CFG.BodyPerDamage, CFG.BodyMin, CFG.BodyMax)
	local hitName, aimPos = nil, pos
	if kind == GMEAT_FLINCH_FALL then
		local chest = ent:LookupBone(B"Spine2")
		local cp = chest and ent:GetBonePosition(chest) or ent:WorldSpaceCenter()
		hitName, aimPos = B"Spine2", cp + ent:GetForward() * 6
		dir = (Vector(0, 0, -1) + ent:GetForward() * 0.35):GetNormalized()
		deg = deg * 0.7
	elseif kind == GMEAT_FLINCH_BLAST or kind == GMEAT_FLINCH_BODY then
		hitName = B"Spine2"
		local chest = ent:LookupBone(hitName)
		aimPos = (chest and ent:GetBonePosition(chest) or pos) + Vector(0, 0, 8)
	else
		hitName = nearestBone(ent, pos)
	end
	if not hitName then return nil end

	local rec = flinching[ent] or { list = {}, touched = {} }
	flinching[ent] = rec
	local start = CurTime()
	for _, link in ipairs(CHAINS[hitName]) do
		local bone = ent:LookupBone(link[1])
		if bone then
			local a = flinchAngle(ent, bone, aimPos, dir, deg * link[2])
			if a then
				rec.list[#rec.list + 1] = { bone = bone, ang = a, start = start }
				rec.touched[bone] = true
			end
		end
	end
	return regionOf(hitName)
end

hook.Add("Think", "Gmeat_Flinch", function()
	local now = CurTime()
	for ent, rec in pairs(flinching) do
		if not IsValid(ent) or not ent:Alive() then
			if IsValid(ent) then for bone in pairs(rec.touched) do ent:ManipulateBoneAngles(bone, Angle(0, 0, 0)) end end
			flinching[ent] = nil
		else
			local sum = {}
			for i = #rec.list, 1, -1 do
				local f = rec.list[i]
				local t = now - f.start
				if t > CFG.Duration then
					table.remove(rec.list, i)
				else
					local e = envelope(t)
					local cur = sum[f.bone] or Angle(0, 0, 0)
					sum[f.bone] = Angle(cur.p + f.ang.p * e, cur.y + f.ang.y * e, cur.r + f.ang.r * e)
				end
			end
			for bone in pairs(rec.touched) do
				ent:ManipulateBoneAngles(bone, sum[bone] or Angle(0, 0, 0))
			end
			if #rec.list == 0 then flinching[ent] = nil end
		end
	end
end)

net.Receive("Gmeat_Flinch", function()
	local ent = net.ReadEntity()
	local pos = net.ReadVector()
	local dir = net.ReadNormal()
	local dmg = net.ReadUInt(8)
	local kind = net.ReadUInt(2)
	if not IsValid(ent) then return end
	local region = GAMEMODE:BodyFlinch(ent, pos, dir, dmg, kind)
	if ent == LocalPlayer() and GAMEMODE.CameraFlinch then
		if kind == GMEAT_FLINCH_FALL then region = "fall"
		elseif kind == GMEAT_FLINCH_BLAST then region = "blast" end
		GAMEMODE:CameraFlinch(dir, dmg, CAMERA_REGION[region or "torso"] or 1)
	end
end)

GMEAT_FLINCH_HIT, GMEAT_FLINCH_FALL, GMEAT_FLINCH_BLAST, GMEAT_FLINCH_BODY = 0, 1, 2, 3
