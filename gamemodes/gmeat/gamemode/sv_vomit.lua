util.AddNetworkString("Gmeat_Vomit")

GMEAT_VOMIT_COUGH = 0
GMEAT_VOMIT_GUSH = 1

local GRAVITY = 550
local HEAD = "ValveBiped.Bip01_Head1"

local function rand(range) return math.Rand(range[1], range[2]) end

local function headGone(rag)
	local rec = rag.GmeatCorpse
	return rec and rec.removed and rec.removed[HEAD]
end

local function floorBelow(pos, rag)
	local tr = util.TraceLine({
		start = pos + Vector(0, 0, 2),
		endpos = pos - Vector(0, 0, 160),
		mask = MASK_SOLID,
		filter = function(ent) return ent ~= rag and not ent:IsPlayer() and ent:GetClass() ~= "prop_ragdoll" end,
	})
	if tr.Hit then return tr.HitPos.z end
end

local function landingSpot(pos, dir, speed, floorZ)
	local h = math.max(pos.z - floorZ, 0.5)
	local vz = dir.z * speed
	local t = (vz + math.sqrt(vz * vz + 2 * GRAVITY * h)) / GRAVITY
	local flat = Vector(dir.x, dir.y, 0) * speed * t
	return Vector(pos.x + flat.x, pos.y + flat.y, floorZ)
end

local function stain(rag, spot, kind)
	if not GMEAT.BloodVomit.FloorStains then return end
	spot = spot + Vector(math.Rand(-2, 2), math.Rand(-2, 2), 4)
	local mouth = IsValid(rag) and GMEAT.CorpseMouth(rag)
	GAMEMODE:FloorStain(spot, kind, nil, mouth or nil)
end

local function lurch(rag, dir, k)
	local rec = rag.GmeatCorpse
	local p = rec and rec.p
	if not p then return end
	if IsValid(p.chest) then p.chest:AddVelocity(Vector(0, 0, 55 * k) + dir * 20 * k) p.chest:Wake() end
	if IsValid(p.head) and not headGone(rag) then p.head:AddVelocity(dir * 45 * k + Vector(0, 0, 25 * k)) p.head:Wake() end
end

local function episode(rag, kind, duration, strength)
	local cfg = GMEAT.BloodVomit
	local rec = rag.GmeatCorpse
	local pos, dir = GMEAT.CorpseMouth(rag)
	if not pos then return false end
	local floorZ = floorBelow(pos, rag) or (pos.z - 30)

	net.Start("Gmeat_Vomit")
	net.WriteEntity(rag)
	net.WriteUInt(kind, 2)
	net.WriteFloat(duration)
	net.WriteUInt(math.Clamp(math.floor(strength * 255), 1, 255), 8)
	net.WriteFloat(floorZ)
	net.SendPVS(pos)

	if kind == GMEAT_VOMIT_COUGH then
		lurch(rag, dir, 0.8 + strength * 0.4)
		if math.random() < 0.45 then
			local spot = landingSpot(pos, dir, rand(cfg.CoughSpeed) * strength, floorZ)
			timer.Simple(0.2, function() if IsValid(rag) then stain(rag, spot, GMEAT_STAIN_DROPS) end end)
		end
	else
		lurch(rag, dir, 0.5)
		local speed = (cfg.GushSpeed[1] + cfg.GushSpeed[2]) * 0.5 * strength
		timer.Simple(0.3, function()
			if not IsValid(rag) or headGone(rag) then return end
			local p, d = GMEAT.CorpseMouth(rag)
			if p then stain(rag, landingSpot(p, d, speed, floorZ), GMEAT_STAIN_POOL) end
		end)
		for i = 2, math.max(1, math.floor(duration / 0.55)) do
			timer.Simple(0.25 + (i - 1) * math.Rand(0.4, 0.6), function()
				if not IsValid(rag) or headGone(rag) then return end
				local p, d = GMEAT.CorpseMouth(rag)
				if p then stain(rag, landingSpot(p, d, speed * math.Rand(0.6, 1.2), floorZ), GMEAT_STAIN_DROPS) end
			end)
		end
	end
	return true
end

function GM:StartBloodVomit(rag)
	local cfg = GMEAT.BloodVomit
	local born = CurTime()
	local left = math.random(cfg.Episodes[1], cfg.Episodes[2])
	local strength = math.Rand(0.85, 1)
	local gushed = false
	local first = true
	local function nextEpisode()
		if not IsValid(rag) or headGone(rag) or left <= 0 or CurTime() - born > cfg.MaxTime then return end
		left = left - 1
		local gush
		if left == 0 and not gushed then gush = true
		elseif first then gush = math.random() < 0.3
		else gush = math.random() < 0.45 end
		first = false
		local duration
		if gush then
			duration = rand(cfg.GushTime) * math.max(strength, 0.5)
			gushed = true
		else
			duration = rand(cfg.CoughTime)
		end
		if not episode(rag, gush and GMEAT_VOMIT_GUSH or GMEAT_VOMIT_COUGH, duration, strength) then return end
		if gush then strength = strength * cfg.Fade else strength = strength * 0.92 end
		local gap = math.random() < 0.2 and math.Rand(0.25, 0.45) or rand(cfg.Gap)
		timer.Simple(duration + gap, nextEpisode)
	end
	timer.Simple(rand(cfg.StartDelay), nextEpisode)
end

function GM:MaybeBloodVomit(rag, headshot)
	if headshot or not IsValid(rag) or headGone(rag) then return false end
	if math.random() >= GetConVar("gmeat_bloodvomit_chance"):GetFloat() then return false end
	self:StartBloodVomit(rag)
	return true
end
