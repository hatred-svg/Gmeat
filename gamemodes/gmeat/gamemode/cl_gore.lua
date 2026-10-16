local cvBlood = CreateClientConVar("gmeat_blood", "1", true, false, "Blood particle amount: 0 off, 1 normal, 2 extra.", 0, 2)

local function pickMaterial(paths)
	for _, path in ipairs(paths) do
		local mat = Material(path)
		if mat and not mat:IsError() then return mat end
	end
	return Material("particle/particle_glow_04")
end
local MAT_DROP = pickMaterial({ "effects/blood_drop", "effects/blood_core", "effects/blood2" })
local MAT_MIST = pickMaterial({ "effects/blood_puff", "effects/blood_core", "effects/blood" })
local MAT_CORE = pickMaterial({ "effects/blood_core", "effects/blood_gore", "effects/blood" })

local GRAVITY = 550
local SPURT_SCALE = 0.2
local SPURT_SPEED = math.sqrt(SPURT_SCALE)
local FLOOR_FRACTION = 0.75

local function onlyRooms(ent)
	return ent:GetClass() == "sector75_room_entity"
end

local function heightAboveFloor(pos)
	local tr = util.TraceLine({
		start = pos,
		endpos = pos - Vector(0, 0, 400),
		mask = MASK_SOLID,
		filter = onlyRooms,
	})
	if tr.Hit then return math.max(pos.z - tr.HitPos.z, 1) end
	return 40
end

local function fallTime(vz, drop)
	return math.min((vz + math.sqrt(vz * vz + 2 * GRAVITY * math.max(drop, 0.5))) / GRAVITY, 1.6)
end

local function dropHeight(pos, floorZ)
	if floorZ then return math.max(pos.z - floorZ, 0.5) end
	return heightAboveFloor(pos) * FLOOR_FRACTION
end

local function safeLifetime(vz, maxDrop, wanted)
	local t = (vz + math.sqrt(vz * vz + 2 * GRAVITY * maxDrop)) / GRAVITY
	return math.min(wanted, t * 0.9)
end

local function amountScale()
	return cvBlood:GetFloat()
end

local function liquidColor(p)
	local r = math.random(70, 105)
	p:SetColor(r, math.random(0, 4), math.random(0, 4))
end

local function wallHit(pos, vel, life)
	local g = Vector(0, 0, -GRAVITY)
	local prev, prevT = pos, 0
	for i = 1, 4 do
		local t = life * i / 4
		local nextPos = pos + vel * t + g * (0.5 * t * t)
		local tr = util.TraceLine({ start = prev, endpos = nextPos, mask = MASK_SOLID, filter = onlyRooms })
		if tr.Hit then
			if tr.HitNormal and math.abs(tr.HitNormal.z) < 0.5 then
				return tr.HitPos, tr.HitNormal, prevT + (t - prevT) * tr.Fraction
			end
			return
		end
		prev, prevT = nextPos, t
	end
end

local function splatWall(pos, vel, life, hitPos, normal, t)
	if not hitPos then hitPos, normal, t = wallHit(pos, vel, life) end
	if not hitPos then return false end
	timer.Simple(t, function()
		local spot = hitPos + VectorRand() * 1.5
		util.Decal(GMEAT.SprayDecal or "Blood", spot + normal * 2, spot - normal * 4)
	end)
	return true
end

function GM:BloodSpurt(pos, dir, strength, wound, floorZ)
	local scale = amountScale()
	if scale <= 0 then return end
	floorZ = floorZ or (wound and wound.floorZ)
	local maxDrop = dropHeight(pos, floorZ)
	local function lifeFor(vz, wanted) if floorZ then return fallTime(vz, maxDrop) end return safeLifetime(vz, maxDrop, wanted) end
	local count = math.floor(math.Clamp(16 + strength * 0.2, 16, 46) * scale * (0.5 + 0.5 * SPURT_SCALE))
	dir = (dir + VectorRand() * 0.12):GetNormalized()
	local jetSpeed = math.Rand(110, math.min(150 + strength, 300))
	local jetVel = dir * jetSpeed * SPURT_SPEED
	local jetLife = lifeFor(jetVel.z, 0.7 * SPURT_SPEED)
	local hitPos, hitNormal, hitT = wallHit(pos, jetVel, jetLife)
	local emitter = ParticleEmitter(pos)
	if not emitter then return end
	for i = 1, count do
		local kind = i / count
		local vel, size, life
		if kind <= 0.55 then
			vel = (dir + VectorRand() * 0.2):GetNormalized() * jetSpeed * math.Rand(0.6, 1.15)
			size = math.Rand(1.6, 3.8)
			life = math.Rand(0.45, 0.8)
		elseif kind <= 0.9 then
			vel = (dir * 0.6 + VectorRand() * 0.3 + Vector(0, 0, -0.3)):GetNormalized() * math.Rand(30, 100)
			size = math.Rand(2.5, 5)
			life = math.Rand(0.5, 0.9)
		else
			vel = (dir + VectorRand() * 0.35):GetNormalized() * math.Rand(50, 140)
			size = math.Rand(4.5, 7)
			life = math.Rand(0.4, 0.7)
		end
		vel = vel * SPURT_SPEED
		size = size * SPURT_SCALE
		life = life * SPURT_SPEED
		local wallT = hitT and (kind <= 0.55 or kind > 0.9) and hitT * math.Rand(0.95, 1.1) or nil
		if wallT then life = math.min(life, wallT) end
		local p = emitter:Add(MAT_DROP, pos + VectorRand() * 1.5 * SPURT_SCALE)
		if p then
			p:SetVelocity(vel)
			p:SetGravity(Vector(0, 0, -GRAVITY))
			p:SetAirResistance(math.Rand(5, 25))
			p:SetDieTime(floorZ and math.min(lifeFor(vel.z), wallT or math.huge) or safeLifetime(vel.z, maxDrop, life))
			p:SetStartAlpha(255)
			p:SetEndAlpha(230)
			p:SetStartSize(size)
			p:SetEndSize(size * math.Rand(0.5, 0.8))
			p:SetRoll(math.Rand(0, 360))
			if math.random() < 0.35 then
				p:SetVelocityScale(true)
				p:SetStartLength(size * 0.6)
				p:SetEndLength(size * 0.3)
			end
			liquidColor(p)
			p:SetCollide(false)
		end
	end
	emitter:Finish()

	if hitPos and (not wound or CurTime() >= (wound.nextDecal or 0)) then
		splatWall(pos, jetVel, jetLife, hitPos, hitNormal, hitT)
		if wound then wound.nextDecal = CurTime() + math.Rand(0.4, 0.7) end
	end
end

function GM:BloodDribble(pos, dir, strength, floorZ)
	local scale = amountScale()
	if scale <= 0 then return end
	local maxDrop = dropHeight(pos, floorZ)
	local squirt = math.random() < 0.35
	local count = math.max(1, math.floor((squirt and math.random(4, 8) or math.random(2, 4)) * math.min(scale, 1.5)))
	local aim = (dir + VectorRand() * (squirt and 0.6 or 0.3)):GetNormalized()
	local emitter = ParticleEmitter(pos)
	if not emitter then return end
	for _ = 1, count do
		local vel
		if squirt then
			vel = (aim + VectorRand() * 0.15):GetNormalized() * math.Rand(35, 70) * math.Clamp(strength / 150, 0.6, 1.3)
		else
			vel = aim * math.Rand(4, 18) + VectorRand() * 6 + Vector(0, 0, -math.Rand(5, 20))
		end
		local size = math.Rand(0.35, 0.9) * (squirt and 1 or 1.3)
		local p = emitter:Add(MAT_DROP, pos + VectorRand() * 0.6)
		if p then
			p:SetVelocity(vel)
			p:SetGravity(Vector(0, 0, -GRAVITY))
			p:SetAirResistance(10)
			p:SetDieTime(floorZ and fallTime(vel.z, maxDrop) or safeLifetime(vel.z, maxDrop, math.Rand(0.25, 0.5)))
			p:SetStartAlpha(255)
			p:SetEndAlpha(220)
			p:SetStartSize(size)
			p:SetEndSize(size * 0.6)
			p:SetRoll(math.Rand(0, 360))
			liquidColor(p)
			p:SetCollide(false)
		end
	end
	emitter:Finish()
	if squirt then splatWall(pos, aim * 55, floorZ and fallTime(aim.z * 55, maxDrop) or safeLifetime(aim.z * 55, maxDrop, 0.4)) end
end

function GM:BloodImpact(pos, dir, strength, floorZ)
	local scale = amountScale()
	if scale <= 0 then return end
	local k = math.Clamp(strength / 60, 0.7, 1.5)
	local maxDrop = dropHeight(pos, floorZ)
	local emitter = ParticleEmitter(pos)
	if not emitter then return end

	local core = emitter:Add(MAT_CORE, pos)
	if core then
		core:SetDieTime(0.09)
		core:SetStartAlpha(255)
		core:SetEndAlpha(0)
		core:SetStartSize(2 * k)
		core:SetEndSize(7 * k)
		core:SetRoll(math.Rand(0, 360))
		core:SetColor(170, 10, 10)
	end
	for i = 1, math.max(1, math.floor(3 * math.min(scale, 1.5))) do
		local m = emitter:Add(MAT_MIST, pos + VectorRand() * 1.5)
		if m then
			local away = i == 1 and -dir or (i == 2 and dir or VectorRand())
			m:SetVelocity(away * math.Rand(15, 40) + VectorRand() * 8)
			m:SetAirResistance(120)
			m:SetGravity(Vector(0, 0, -15))
			m:SetDieTime(math.Rand(0.25, 0.4))
			m:SetStartAlpha(i == 1 and 230 or 170)
			m:SetEndAlpha(0)
			m:SetStartSize(math.Rand(2.5, 4) * k)
			m:SetEndSize(math.Rand(9, 13) * k)
			m:SetRoll(math.Rand(0, 360))
			m:SetRollDelta(math.Rand(-2, 2))
			m:SetColor(math.random(120, 150), 4, 4)
			m:SetCollide(false)
		end
	end
	for _ = 1, math.floor(math.Rand(7, 11) * k * math.min(scale, 1.5)) do
		local back = math.random() < 0.6
		local vel = ((back and -dir or dir) + VectorRand() * 0.45):GetNormalized() * math.Rand(70, 170)
		local p = emitter:Add(MAT_DROP, pos)
		if p then
			local size = math.Rand(0.5, 1.1)
			p:SetVelocity(vel)
			p:SetGravity(Vector(0, 0, -GRAVITY))
			p:SetAirResistance(40)
			p:SetDieTime(safeLifetime(vel.z, maxDrop, math.Rand(0.18, 0.35)))
			p:SetStartAlpha(255)
			p:SetEndAlpha(200)
			p:SetStartSize(size)
			p:SetEndSize(size * 0.5)
			p:SetVelocityScale(true)
			p:SetStartLength(0.04)
			p:SetEndLength(0.02)
			liquidColor(p)
			p:SetCollide(false)
		end
	end
	emitter:Finish()
end

function GM:BloodBurst(pos, dir, strength)
	local scale = amountScale()
	if scale <= 0 then return end
	local emitter = ParticleEmitter(pos)
	if not emitter then return end
	for _ = 1, math.floor(90 * scale * (strength / 255 + 0.4)) do
		local p = emitter:Add(MAT_DROP, pos + VectorRand() * 4)
		if p then
			p:SetVelocity((dir * 0.5 + VectorRand()):GetNormalized() * math.Rand(120, 380) + Vector(0, 0, 80))
			p:SetGravity(Vector(0, 0, -GRAVITY))
			p:SetAirResistance(30)
			p:SetDieTime(math.Rand(0.5, 1.1))
			p:SetStartAlpha(255)
			p:SetEndAlpha(200)
			p:SetStartSize(math.Rand(2.5, 6))
			p:SetEndSize(1.5)
			p:SetVelocityScale(true)
			p:SetStartLength(math.Rand(10, 18))
			p:SetEndLength(3)
			liquidColor(p)
			p:SetCollide(true)
		end
	end
	for _ = 1, math.floor(3 * scale) do
		local m = emitter:Add(MAT_MIST, pos + VectorRand() * 6)
		if m then
			m:SetVelocity(VectorRand() * math.Rand(20, 50))
			m:SetDieTime(math.Rand(0.3, 0.5))
			m:SetStartAlpha(140)
			m:SetEndAlpha(0)
			m:SetStartSize(6)
			m:SetEndSize(math.Rand(14, 22))
			m:SetRoll(math.Rand(0, 360))
			m:SetColor(60, 0, 0)
			m:SetCollide(false)
		end
	end
	local core = emitter:Add(MAT_CORE, pos)
	if core then
		core:SetDieTime(0.25)
		core:SetStartAlpha(255)
		core:SetEndAlpha(0)
		core:SetStartSize(8)
		core:SetEndSize(24)
		core:SetColor(80, 0, 0)
	end
	emitter:Finish()
end

function GM:GibTrail(pos)
	local scale = amountScale()
	if scale <= 0 or math.random() > 0.6 * scale then return end
	local emitter = ParticleEmitter(pos)
	if not emitter then return end
	local p = emitter:Add(MAT_DROP, pos)
	if p then
		p:SetVelocity(VectorRand() * 20)
		p:SetGravity(Vector(0, 0, -GRAVITY))
		p:SetDieTime(math.Rand(0.4, 0.8))
		p:SetStartAlpha(255)
		p:SetEndAlpha(0)
		p:SetStartSize(math.Rand(1.2, 2.4))
		p:SetEndSize(0.5)
		p:SetVelocityScale(true)
		p:SetStartLength(5)
		p:SetEndLength(2)
		liquidColor(p)
		p:SetCollide(true)
	end
	emitter:Finish()
end

local wounds = {}

local function nearestBone(ent, pos)
	local best, bestDist
	for i = 0, ent:GetBoneCount() - 1 do
		local bp = ent:GetBonePosition(i)
		if bp and bp ~= ent:GetPos() then
			local d = bp:DistToSqr(pos)
			if not bestDist or d < bestDist then best, bestDist = i, d end
		end
	end
	return best
end

local function boneMatrix(ent, bone)
	local m = ent:GetBoneMatrix(bone)
	if m then return m:GetTranslation(), m:GetAngles() end
end

local function addWound(ent, bone, pos, dir, strength, duration, interval, floorZ)
	local bpos, bang = boneMatrix(ent, bone)
	if not bpos then return end
	local lpos = WorldToLocal(pos, angle_zero, bpos, bang)
	local ldir = WorldToLocal(pos + dir, angle_zero, bpos, bang) - lpos
	wounds[#wounds + 1] = {
		ent = ent, bone = bone, lpos = lpos, ldir = ldir,
		strength = strength, start = CurTime(), duration = duration,
		interval = interval, nextPulse = CurTime() + interval,
		nextDribble = CurTime() + math.Rand(0.1, 0.4),
		floorZ = floorZ,
	}
end

local WOUND_MATS = {}
for i = 1, 4 do WOUND_MATS[i] = Material("gmeat/decals/wound" .. i) end
local WOUND_COLOR = Color(255, 255, 255, 255)

function GM:WoundMark(ent, pos, dir, strength)
	if not IsValid(ent) or not (ent:IsPlayer() or ent:GetClass() == "prop_ragdoll") then return end
	if not util.DecalEx then return end
	local size = math.Clamp(4 + (strength or 30) / 25, 4.5, 8) * math.Rand(0.85, 1.15)
	util.DecalEx(WOUND_MATS[math.random(#WOUND_MATS)], ent, pos, -dir, WOUND_COLOR, size, size)
end

net.Receive("Gmeat_Blood", function()
	local kind = net.ReadUInt(2)
	local ent = net.ReadEntity()
	local pos = net.ReadVector()
	local dir = net.ReadNormal()
	local amount = net.ReadUInt(8)
	local bone = net.ReadUInt(8) - 1
	local localPos = net.ReadVector()
	local floorZ = net.ReadFloat()

	if IsValid(ent) and ent.GetBoneMatrix and kind ~= GMEAT_BLOOD_BURST then
		if bone < 0 then bone = nearestBone(ent, pos) or -1 end
		if bone >= 0 then
			local bpos, bang = boneMatrix(ent, bone)
			if bpos and kind == GMEAT_BLOOD_HIT then
				pos = LocalToWorld(localPos, angle_zero, bpos, bang)
				pos = GMEAT.SnapToBody(ent, bone, pos, -dir)
			end
		end
	end

	if kind == GMEAT_BLOOD_HIT then
		GAMEMODE:BloodImpact(pos, dir, amount, floorZ)
		GAMEMODE:WoundMark(ent, pos, dir, amount)
		GAMEMODE:BloodSpurt(pos, dir, amount, nil, floorZ)
		if IsValid(ent) and bone >= 0 then
			addWound(ent, bone, pos, dir, math.max(amount, 60), amount >= 40 and 2.5 or 1.6, 0.07, floorZ)
		end
	elseif kind == GMEAT_BLOOD_GUSH then
		if IsValid(ent) and bone >= 0 then
			GAMEMODE:WoundMark(ent, pos, dir, amount)
			addWound(ent, bone, pos, dir, amount, 7.5, 0.07, floorZ)
		end
	elseif kind == GMEAT_BLOOD_STUMP then
		if IsValid(ent) then
			local cut = boneMatrix(ent, bone)
			local parent = ent:GetBoneParent(bone)
			local ppos = parent and parent >= 0 and boneMatrix(ent, parent)
			local out = (cut and ppos) and (cut - ppos):GetNormalized() or dir
			addWound(ent, bone, cut or pos, out, amount, 8, 0.06, floorZ)
		end
	elseif kind == GMEAT_BLOOD_BURST then
		GAMEMODE:BloodBurst(pos, dir, amount)
	end
end)

local wallWounds = {}

function GM:WallBleed(pos, normal, dir, strength)
	local flesh = GetConVar("gmeat_flesh_maze")
	if flesh and not flesh:GetBool() then
		util.Decal("Impact.Concrete", pos + normal * 2, pos - normal * 4)
		return
	end
	local out = pos + normal * 1.5
	local into = (dir - normal):GetNormalized()
	self:BloodImpact(out, into, strength)
	util.Decal(GMEAT.WallWoundDecal or "Blood", pos + normal * 2, pos - normal * 4)
	if math.random() < 0.4 then
		local spot = pos + VectorRand() * 3
		util.Decal(GMEAT.SprayDecal or "Blood", spot + normal * 2, spot - normal * 4)
	end
	self:BloodSpurt(out, (normal + Vector(0, 0, -0.3)):GetNormalized(), strength * 0.5)
	wallWounds[#wallWounds + 1] = { pos = out, normal = normal, strength = strength,
		start = CurTime(), duration = math.Rand(2, 3.5), nextT = CurTime() + 0.15 }
	while #wallWounds > 24 do table.remove(wallWounds, 1) end
end

net.Receive("Gmeat_WallBleed", function()
	local pos, normal, dir = net.ReadVector(), net.ReadNormal(), net.ReadNormal()
	GAMEMODE:WallBleed(pos, normal, dir, net.ReadUInt(8))
end)

hook.Add("Think", "Gmeat_WallWounds", function()
	local now = CurTime()
	for i = #wallWounds, 1, -1 do
		local w = wallWounds[i]
		local age = now - w.start
		if age > w.duration then
			table.remove(wallWounds, i)
		elseif now >= w.nextT then
			w.nextT = now + math.Rand(0.18, 0.45)
			GAMEMODE:BloodDribble(w.pos, (w.normal * 0.6 + Vector(0, 0, -1)):GetNormalized(), w.strength * (1 - age / w.duration))
		end
	end
end)

hook.Add("PostCleanupMap", "Gmeat_WallWounds", function() wallWounds = {} end)

GMEAT_BLOOD_GUSH = 0
GMEAT_BLOOD_HIT = 1
GMEAT_BLOOD_STUMP = 2
GMEAT_BLOOD_BURST = 3

hook.Add("Think", "Gmeat_Wounds", function()
	local now = CurTime()
	for i = #wounds, 1, -1 do
		local w = wounds[i]
		local age = now - w.start
		if not IsValid(w.ent) or age > w.duration or (w.ent:IsPlayer() and not w.ent:Alive()) then
			table.remove(wounds, i)
		elseif now >= w.nextPulse or now >= w.nextDribble then
			local bpos, bang = boneMatrix(w.ent, w.bone)
			if bpos then
				local pos = LocalToWorld(w.lpos, angle_zero, bpos, bang)
				local dir = (LocalToWorld(w.lpos + w.ldir, angle_zero, bpos, bang) - pos):GetNormalized()
				local strength = w.strength * (1 - 0.6 * age / w.duration)
				if now >= w.nextPulse then
					w.nextPulse = now + w.interval * math.Rand(0.8, 1.2)
					GAMEMODE:BloodSpurt(pos, dir, strength, w)
				end
				if now >= w.nextDribble then
					w.nextDribble = now + math.Rand(0.12, 0.45)
					GAMEMODE:BloodDribble(pos, dir, strength, w.floorZ)
				end
			else
				w.nextPulse, w.nextDribble = now + w.interval, now + 0.2
			end
		end
	end
end)

hook.Add("PostCleanupMap", "Gmeat_ClearWounds", function()
	wounds = {}
end)

GMEAT_VOMIT_COUGH = 0
GMEAT_VOMIT_GUSH = 1

local vomits = {}

local function fallTime(z, vz, floorZ)
	local h = math.max(z - floorZ, 0.5)
	return (vz + math.sqrt(vz * vz + 2 * GRAVITY * h)) / GRAVITY
end

local function vomitDrop(emitter, pos, vel, size, floorZ, stretch)
	local p = emitter:Add(MAT_DROP, pos)
	if not p then return end
	p:SetVelocity(vel)
	p:SetGravity(Vector(0, 0, -GRAVITY))
	p:SetAirResistance(8)
	p:SetDieTime(math.min(fallTime(pos.z, vel.z, floorZ), 1.2))
	p:SetStartAlpha(255)
	p:SetEndAlpha(235)
	p:SetStartSize(size)
	p:SetEndSize(size * math.Rand(0.7, 0.95))
	p:SetRoll(math.Rand(0, 360))
	if stretch then
		p:SetVelocityScale(true)
		p:SetStartLength(size * 0.5)
		p:SetEndLength(size * 0.8)
	end
	liquidColor(p)
	p:SetCollide(false)
end

local function vomitMist(emitter, pos, dir, k)
	for _ = 1, math.random(2, 4) do
		local m = emitter:Add(MAT_MIST, pos)
		if m then
			m:SetVelocity(dir * math.Rand(15, 40) * k + VectorRand() * 6)
			m:SetAirResistance(140)
			m:SetGravity(Vector(0, 0, -20))
			m:SetDieTime(math.Rand(0.3, 0.5))
			m:SetStartAlpha(150)
			m:SetEndAlpha(0)
			m:SetStartSize(math.Rand(1.2, 2))
			m:SetEndSize(math.Rand(5, 8) * k)
			m:SetRoll(math.Rand(0, 360))
			m:SetRollDelta(math.Rand(-2, 2))
			m:SetColor(math.random(95, 125), 3, 3)
			m:SetCollide(false)
		end
	end
end

local function floorSplash(emitter, spot, k)
	for _ = 1, math.random(1, 3) do
		local p = emitter:Add(MAT_DROP, spot + Vector(math.Rand(-1.5, 1.5), math.Rand(-1.5, 1.5), 0.5))
		if p then
			local vz = math.Rand(15, 40) * k
			p:SetVelocity(Vector(math.Rand(-18, 18), math.Rand(-18, 18), vz))
			p:SetGravity(Vector(0, 0, -GRAVITY))
			p:SetDieTime(math.min(math.Rand(0.12, 0.22), fallTime(spot.z + 0.5, vz, spot.z) * 0.95))
			p:SetStartAlpha(240)
			p:SetEndAlpha(160)
			local size = math.Rand(0.35, 0.8)
			p:SetStartSize(size)
			p:SetEndSize(size * 0.5)
			liquidColor(p)
			p:SetCollide(false)
		end
	end
end

local function landing(pos, dir, speed, floorZ)
	local t = fallTime(pos.z, dir.z * speed, floorZ)
	return Vector(pos.x + dir.x * speed * t, pos.y + dir.y * speed * t, floorZ)
end

local function cough(v, pos, dir, scale)
	local cfg = GMEAT.BloodVomit
	local emitter = ParticleEmitter(pos)
	if not emitter then return end
	vomitMist(emitter, pos, dir, v.strength)
	for _ = 1, math.floor(math.Rand(8, 15) * v.strength * math.min(scale, 1.5)) do
		local vel = (dir + VectorRand() * 0.35):GetNormalized() * math.Rand(cfg.CoughSpeed[1], cfg.CoughSpeed[2]) * v.strength
		vomitDrop(emitter, pos + VectorRand() * 0.4, vel, math.Rand(0.4, 1.2), v.floorZ, math.random() < 0.3)
	end
	floorSplash(emitter, landing(pos, dir, cfg.CoughSpeed[1] * v.strength, v.floorZ), 0.7)
	emitter:Finish()
end

local function gush(v, pos, dir, t, scale, now)
	local cfg = GMEAT.BloodVomit
	local surge = math.min(1, t / 0.12) * (0.6 + 0.4 * math.sin(t * 11 + v.phase)) * (1 - 0.45 * t / v.duration)
	local emitter = ParticleEmitter(pos)
	if not emitter then return end
	local speedHi = cfg.GushSpeed[1] + (cfg.GushSpeed[2] - cfg.GushSpeed[1]) * surge
	for i = 1, math.max(1, math.floor(3 * v.strength * math.min(scale, 1.5))) do
		local aim = (dir + VectorRand() * 0.22 + Vector(0, 0, -0.15)):GetNormalized()
		local speed = math.Rand(cfg.GushSpeed[1] * 0.6, speedHi) * v.strength
		local glob = math.random() < 0.12
		vomitDrop(emitter, pos + VectorRand() * 0.5, aim * speed, glob and math.Rand(1.8, 2.8) or math.Rand(0.7, 1.7), v.floorZ, not glob and math.random() < 0.3)
	end
	if math.random() < 0.15 then vomitMist(emitter, pos, dir, 0.6) end
	if now >= v.nextSplash then
		v.nextSplash = now + math.Rand(0.08, 0.16)
		floorSplash(emitter, landing(pos, dir, (cfg.GushSpeed[1] + speedHi) * 0.5 * v.strength, v.floorZ), surge)
	end
	emitter:Finish()
end

local function drool(v, pos, dir)
	local emitter = ParticleEmitter(pos)
	if not emitter then return end
	vomitDrop(emitter, pos, dir * math.Rand(2, 6) + Vector(0, 0, -math.Rand(4, 12)), math.Rand(0.6, 1.1), v.floorZ, true)
	emitter:Finish()
end

net.Receive("Gmeat_Vomit", function()
	local ent = net.ReadEntity()
	local kind = net.ReadUInt(2)
	local duration = net.ReadFloat()
	local strength = net.ReadUInt(8) / 255
	local floorZ = net.ReadFloat()
	if not IsValid(ent) or amountScale() <= 0 then return end
	local v = { ent = ent, kind = kind, start = CurTime(), duration = duration, strength = strength, floorZ = floorZ,
		phase = math.Rand(0, 6), nextEmit = 0, nextSplash = 0, nextDrool = 0 }
	if kind == GMEAT_VOMIT_COUGH then
		v.hacks = { 0 }
		local n = math.random(1, 3)
		for i = 2, n do v.hacks[i] = duration * (i - 1) / n + math.Rand(-0.04, 0.04) end
		v.drool = 0.4
	else
		v.drool = math.Rand(1.5, 3)
	end
	vomits[#vomits + 1] = v
end)

hook.Add("Think", "Gmeat_Vomit", function()
	if #vomits == 0 then return end
	local now = CurTime()
	local scale = amountScale()
	for i = #vomits, 1, -1 do
		local v = vomits[i]
		local t = now - v.start
		local pos, dir
		if IsValid(v.ent) then pos, dir = GMEAT.CorpseMouth(v.ent) end
		if not pos or t > v.duration + v.drool or scale <= 0 then
			table.remove(vomits, i)
		elseif v.kind == GMEAT_VOMIT_COUGH then
			while v.hacks[1] and t >= v.hacks[1] do
				table.remove(v.hacks, 1)
				cough(v, pos, dir, scale)
			end
			if t > v.duration and now >= v.nextDrool then
				v.nextDrool = now + math.Rand(0.15, 0.35)
				drool(v, pos, dir)
			end
		elseif t <= v.duration then
			if now >= v.nextEmit then
				v.nextEmit = now + 0.025
				gush(v, pos, dir, t, scale, now)
			end
		elseif now >= v.nextDrool then
			v.nextDrool = now + math.Rand(0.25, 0.6) * (1 + (t - v.duration))
			drool(v, pos, dir)
		end
	end
end)

hook.Add("PostCleanupMap", "Gmeat_ClearVomit", function() vomits = {} end)

local stainMats = {}
for k, kind in ipairs(GMEAT.FloorStains) do
	stainMats[k] = {}
	for i, path in ipairs(kind.mats) do stainMats[k][i] = Material(path) end
end
local stains = {}
local STAIN_DRAW_DIST = 2200
local STAIN_LIGHT_EVERY = 0.12

local GAMMA = 1 / 2.2
local function stainLight(st)
	local n = st.normal
	local lit = render.ComputeLighting(st.lightOrigin or (st.pos + n * 4), n)
	local dyn = render.ComputeDynamicLighting and render.ComputeDynamicLighting(st.pos + n * 4, n)
	if dyn then lit = lit + dyn end
	st.r = 255 * math.Clamp(lit.x, 0, 1) ^ GAMMA
	st.g = 255 * math.Clamp(lit.y, 0, 1) ^ GAMMA
	st.b = 255 * math.Clamp(lit.z, 0, 1) ^ GAMMA
end

local function roomCentreAt(pos)
	local best, bestVol
	for _, room in ipairs(ents.FindByClass("sector75_room_entity")) do
		if IsValid(room) then
			local lp = room:WorldToLocal(pos)
			local mins, maxs = room:OBBMins(), room:OBBMaxs()
			if lp.x >= mins.x - 8 and lp.y >= mins.y - 8 and lp.z >= mins.z - 8 and lp.x <= maxs.x + 8 and lp.y <= maxs.y + 8 and lp.z <= maxs.z + 8 then
				local size = maxs - mins
				local vol = size.x * size.y * size.z
				if not bestVol or vol < bestVol then best, bestVol = room, vol end
			end
		end
	end
	return best and best:WorldSpaceCenter()
end

function GM:AddFloorStain(pos, normal, kind, variant, rot, scale)
	local def = GMEAT.FloorStains[kind] or GMEAT.FloorStains[1]
	local mats = stainMats[kind] or stainMats[1]
	stains[#stains + 1] = {
		pos = pos + normal * 0.25,
		normal = normal,
		mat = mats[(variant or 0) % #mats + 1],
		size = def.size * (scale or 1),
		rot = rot or 0,
		born = CurTime(),
		nextLight = 0,
		lightOrigin = roomCentreAt(pos),
		r = 0, g = 0, b = 0,
	}
	while #stains > (GMEAT.MaxFloorStains or 500) do table.remove(stains, 1) end
end

net.Receive("Gmeat_FloorStain", function()
	local pos = net.ReadVector()
	local normal = net.ReadNormal()
	local kind = net.ReadUInt(2)
	local variant = net.ReadUInt(2)
	local rot = net.ReadUInt(8) / 256 * 360
	local scale = net.ReadUInt(7) / 100
	if amountScale() <= 0 then return end
	GAMEMODE:AddFloorStain(pos, normal, kind, variant, rot, scale)
end)

hook.Add("PostDrawTranslucentRenderables", "Gmeat_FloorStains", function(depth, skybox)
	if skybox or depth or #stains == 0 then return end
	local eye = EyePos()
	local now = CurTime()
	local maxDist = STAIN_DRAW_DIST * STAIN_DRAW_DIST
	for i = 1, #stains do
		local st = stains[i]
		if st.pos:DistToSqr(eye) < maxDist then
			if now >= st.nextLight then
				st.nextLight = now + STAIN_LIGHT_EVERY
				stainLight(st)
			end
			local grow = math.min(1, (now - st.born) / 0.25)
			local size = st.size * (0.55 + 0.45 * grow)
			render.SetMaterial(st.mat)
			render.DrawQuadEasy(st.pos, st.normal, size, size, Color(st.r, st.g, st.b, 255), st.rot)
		end
	end
end)

hook.Add("PostCleanupMap", "Gmeat_FloorStains", function() stains = {} end)

hook.Add("OnEntityCreated", "Gmeat_RagdollColor", function(ent)
	if ent:GetClass() == "prop_ragdoll" then
		ent.GetPlayerColor = function(self)
			return self:GetNWVector("GmeatPlayerColor", Vector(1, 1, 1))
		end
	end
end)

hook.Add("CalcView", "Gmeat_DeathCam", function(ply, origin, angles, fov)
	if ply:Alive() or ply:GetObserverMode() ~= OBS_MODE_NONE then return end
	local rag = ply:GetNWEntity("GmeatRagdoll")
	local focus
	if IsValid(rag) then
		focus = rag:GetPos() + Vector(0, 0, 8)
	else
		focus = ply:GetNWVector("GmeatDeathPos", origin)
	end
	local wanted = focus - angles:Forward() * 120 + Vector(0, 0, 24)
	local tr = util.TraceHull({
		start = focus,
		endpos = wanted,
		mins = Vector(-6, -6, -6),
		maxs = Vector(6, 6, 6),
		mask = MASK_SOLID,
		filter = function(ent) return ent:GetClass() == "sector75_room_entity" end,
	})
	return { origin = tr.HitPos, angles = angles, fov = fov, drawviewer = false }
end)

net.Receive("Gmeat_ClearDecals", function()
	local ply = net.ReadEntity()
	if not IsValid(ply) then return end
	ply:RemoveAllDecals()
	timer.Simple(0.2, function()
		if IsValid(ply) then ply:RemoveAllDecals() end
	end)
end)
