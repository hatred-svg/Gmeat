util.AddNetworkString("Gmeat_Blood")

GMEAT.Gore = {
	RagdollLifetime = 20,
	MaxRagdolls = 10,
	WritheTime = 7,
	SpasmTime = 0.8,
	GrabSpeed = 320,
	CrawlPull = 100,
	RollSpeed = 300,
	LegSpeed = 240,
	MaxUpSpeed = 120,
	MaxSlide = 170,
	AgitateTime = 1.5,
	DeathPush = 60,
	FullGibDamage = 100,
	CorpseLimbDamage = 10,
	CorpseGibDamage = 120,
	MaxGibs = 48,
	GibLifetime = 10,
	HeadlessCrawlChance = 0.5,
	CrawlTime = { 3.5, 6 },
	CrawlSpeed = { 22, 38 },
	CrawlKnockdown = 25,
}

GMEAT.GibEating = {
	DefaultHeal = 10,
	Heal = {
		["models/gibs/hgibs_spine.mdl"] = 5,
		["models/gmeat/gibs/heart.mdl"] = 25,
		["models/gmeat/gibs/lung.mdl"] = 15,
		["models/gmeat/gibs/trachea.mdl"] = 10,
	},
}

GMEAT_BLOOD_GUSH = 0
GMEAT_BLOOD_HIT = 1
GMEAT_BLOOD_STUMP = 2
GMEAT_BLOOD_BURST = 3

local LIMBS = {
	{ name = "head", bones = { "ValveBiped.Bip01_Head1" }, hitgroup = HITGROUP_HEAD },
	{ name = "l_arm", bones = { "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand" }, hitgroup = HITGROUP_LEFTARM },
	{ name = "r_arm", bones = { "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand" }, hitgroup = HITGROUP_RIGHTARM },
	{ name = "l_leg", bones = { "ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_L_Foot" }, hitgroup = HITGROUP_LEFTLEG },
	{ name = "r_leg", bones = { "ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_R_Foot" }, hitgroup = HITGROUP_RIGHTLEG },
}

local FLAIL_BONES = {
	"ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_R_Hand",
	"ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_R_Forearm",
	"ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_R_UpperArm",
	"ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_R_Calf",
	"ValveBiped.Bip01_L_Foot", "ValveBiped.Bip01_R_Foot",
	"ValveBiped.Bip01_Head1",
}
local TORSO_BONES = { "ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Pelvis" }
local TORSO_REFERENCE = { "ValveBiped.Bip01_Pelvis", "ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Neck1" }

local FLESH_GIBS = {
	"models/gibs/antlion_gib_small_1.mdl",
	"models/gibs/antlion_gib_small_2.mdl",
	"models/gibs/antlion_gib_small_3.mdl",
}
local SPINE_GIB = "models/gibs/hgibs_spine.mdl"

local ORGAN_MODELS = {
	heart = "models/gmeat/gibs/heart.mdl",
	lung = "models/gmeat/gibs/lung.mdl",
	trachea = "models/gmeat/gibs/trachea.mdl",
}
local organAvailable = {}
for key, mdl in pairs(ORGAN_MODELS) do
	organAvailable[key] = file.Exists(mdl, "GAME")
	if organAvailable[key] then
		resource.AddFile(mdl)
		resource.AddFile("materials/models/gmeat/gibs/" .. key .. ".vmt")
		resource.AddFile("materials/models/gmeat/gibs/" .. key .. "_n.vtf")
	end
end

local function bodyOrgans()
	local keys = { "heart", "lung", "lung" }
	if math.random() < 0.5 then keys[#keys + 1] = "trachea" end
	local list = { SPINE_GIB }
	for _, key in ipairs(keys) do
		if organAvailable[key] then list[#list + 1] = ORGAN_MODELS[key] end
	end
	return list
end

local function hitDirection(victim, dmginfo)
	local force = dmginfo:GetDamageForce()
	if not force:IsZero() then return force:GetNormalized() end
	local attacker = dmginfo:GetAttacker()
	if IsValid(attacker) and attacker ~= victim then
		local d = victim:WorldSpaceCenter() - attacker:WorldSpaceCenter()
		if not d:IsZero() then return d:GetNormalized() end
	end
	return Vector(0, 0, 1)
end

local function goreEnabled()
	return GetConVar("gmeat_gore"):GetBool()
end

local function onlyRooms(e) return e:GetClass() == "sector75_room_entity" end

local function floorUnder(pos, depth)
	local tr = util.TraceLine({
		start = pos + Vector(0, 0, 2),
		endpos = pos - Vector(0, 0, depth or 300),
		mask = MASK_SOLID,
		filter = onlyRooms,
	})
	if not tr.Hit or tr.StartSolid or tr.AllSolid or (tr.Fraction or 1) <= 0 or not tr.HitPos then return end
	local normal = tr.HitNormal or Vector(0, 0, 1)
	if normal.z > 0.6 then return tr.HitPos, normal end
end
GM.FloorUnder = function(self, pos, depth) return floorUnder(pos, depth) end

local function hitBone(ent, pos)
	local names = ent:IsPlayer() and GMEAT.HitGroupBones[ent:LastHitGroup()] or nil
	local best, bestDist
	local function try(name)
		local b = ent:LookupBone(name)
		local m = b and ent:GetBoneMatrix(b)
		if m then
			local d = m:GetTranslation():DistToSqr(pos)
			if not bestDist or d < bestDist then best, bestDist = b, d end
		end
	end
	if names then for _, n in ipairs(names) do try(n) end end
	if not best then for n in pairs(GMEAT.BodySegments) do try(n) end end
	return best
end

function GM:SendBlood(kind, ent, pos, dir, amount, bone)
	local onBody = IsValid(ent) and ent.LookupBone ~= nil
	if onBody and not bone and kind == GMEAT_BLOOD_HIT then bone = hitBone(ent, pos) end
	local localPos = Vector(0, 0, 0)
	if onBody and bone then
		local m = ent:GetBoneMatrix(bone)
		if m then localPos = WorldToLocal(pos, angle_zero, m:GetTranslation(), m:GetAngles()) end
	end
	local floor = floorUnder(pos)
	net.Start("Gmeat_Blood")
	net.WriteUInt(kind, 2)
	net.WriteEntity(onBody and ent or NULL)
	net.WriteVector(pos)
	net.WriteNormal(dir)
	net.WriteUInt(math.Clamp(math.floor(amount), 0, 255), 8)
	net.WriteUInt((bone or -1) + 1, 8)
	net.WriteVector(localPos)
	net.WriteFloat(floor and floor.z or (pos.z - 64))
	net.SendPVS(pos)
	self:FloorBlood(kind, onBody and ent or NULL, pos, dir, amount, bone)
end

util.AddNetworkString("Gmeat_FloorStain")

local floorBudget = { t = 0, n = 0 }
function GM:FloorStain(pos, kind, normal, from)
	local now = CurTime()
	if now - floorBudget.t > 1 then floorBudget.t, floorBudget.n = now, 0 end
	if floorBudget.n >= 24 then return false end
	if from and not normal then
		local level = Vector(pos.x, pos.y, from.z)
		local tr = util.TraceLine({ start = from, endpos = level, mask = MASK_SOLID, filter = onlyRooms })
		if tr.StartSolid then return false end
		if tr.Hit and tr.HitPos then
			local back = level - from
			back.z = 0
			if not back:IsZero() then back:Normalize() end
			pos = tr.HitPos - back * 4
		end
	end
	local hit = pos
	if not normal then
		hit, normal = floorUnder(pos, 200)
		if not hit then return false end
	end
	floorBudget.n = floorBudget.n + 1
	net.Start("Gmeat_FloorStain")
	net.WriteVector(hit)
	net.WriteNormal(normal)
	net.WriteUInt(kind or GMEAT_STAIN_DROPS, 2)
	net.WriteUInt(math.random(0, 3), 2)
	net.WriteUInt(math.random(0, 255), 8)
	net.WriteUInt(math.random(80, 125), 7)
	net.Broadcast()
	return true
end
local function floorDecal(kind, pos, from) return GAMEMODE:FloorStain(pos, kind, nil, from) end

local function landing(pos, dir, dist)
	local flat = Vector(dir.x, dir.y, 0)
	if flat:IsZero() then flat = VectorRand() flat.z = 0 end
	flat:Normalize()
	return pos + flat * dist + Vector(math.Rand(-3, 3), math.Rand(-3, 3), 0)
end

local function woundPos(ent, bone, fallback)
	if IsValid(ent) and bone then
		local m = ent:GetBoneMatrix(bone)
		if m then return m:GetTranslation() end
	end
	return IsValid(ent) and ent:WorldSpaceCenter() or fallback
end

function GM:FloorBlood(kind, ent, pos, dir, amount, bone)
	local drops, pool = GMEAT_STAIN_DROPS, GMEAT_STAIN_POOL
	local hadBody = IsValid(ent)
	local function later(delay, name, dist, towards)
		timer.Simple(delay, function()
			if hadBody and not IsValid(ent) then return end
			local from = woundPos(ent, bone, pos)
			floorDecal(name, landing(from, towards or dir, dist), from)
		end)
	end
	if kind == GMEAT_BLOOD_HIT then
		for i = 1, (amount >= 60 and 3 or math.random(1, 2)) do later(math.Rand(0.15, 0.5) + i * 0.25, drops, math.Rand(2, 16)) end
	elseif kind == GMEAT_BLOOD_GUSH or kind == GMEAT_BLOOD_STUMP then
		local duration = kind == GMEAT_BLOOD_GUSH and 7.5 or 8
		later(0.35, pool, kind == GMEAT_BLOOD_STUMP and 10 or 3)
		local t = 0.6
		while t < duration do
			later(t, drops, math.Rand(2, kind == GMEAT_BLOOD_STUMP and 24 or 10))
			t = t + math.Rand(0.5, 0.95) * (1 + t / duration)
		end
	elseif kind == GMEAT_BLOOD_BURST then
		for i = 1, (amount >= 200 and 4 or 2) do
			local d = VectorRand() d.z = 0
			later(math.Rand(0.1, 0.4), i == 1 and pool or drops, math.Rand(4, 30), d)
		end
	end
end

local function wallSplat(victim, pos, dir)
	local tr = util.TraceLine({
		start = pos,
		endpos = pos + dir * 140,
		filter = victim,
		mask = MASK_SOLID,
	})
	if tr.Hit and math.abs(tr.HitNormal.z) < 0.5 then
		util.Decal(GMEAT.BloodDecal or "Blood", tr.HitPos + tr.HitNormal * 2, tr.HitPos - tr.HitNormal * 4, victim)
	end
end

util.AddNetworkString("Gmeat_Flinch")
util.AddNetworkString("Gmeat_WallBleed")

function GM:WallBleed(pos, normal, dir, strength, attacker)
	local who = IsValid(attacker) and attacker or game.GetWorld()
	local now = CurTime()
	if (who.GmeatBleedWindow or 0) < now then who.GmeatBleedWindow, who.GmeatBleedCount = now + 0.1, 0 end
	if who.GmeatBleedCount >= 4 then return end
	who.GmeatBleedCount = who.GmeatBleedCount + 1
	net.Start("Gmeat_WallBleed")
	net.WriteVector(pos)
	net.WriteNormal(normal)
	net.WriteNormal(dir)
	net.WriteUInt(math.Clamp(math.floor(strength or 20), 1, 255), 8)
	net.SendPVS(pos)
end

function GM:EntityFireBullets(ent, data)
	local old = data.Callback
	data.Callback = function(att, tr, dmginfo)
		if GMEAT.IsFleshWall(tr) then
			GAMEMODE:WallBleed(tr.HitPos, tr.HitNormal, tr.Normal, dmginfo and dmginfo:GetDamage() or 20, att)
		end
		if old then return old(att, tr, dmginfo) end
	end
	return true
end

hook.Add("KeyPress", "Gmeat_MeleeWallBleed", function(ply, key)
	if key ~= IN_ATTACK then return end
	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or wep:GetPrimaryAmmoType() ~= -1 then return end
	local before = wep:GetNextPrimaryFire()
	timer.Simple(0.08, function()
		if not IsValid(ply) or not IsValid(wep) or not ply:Alive() then return end
		if wep:GetNextPrimaryFire() <= before then return end
		local start = ply:GetShootPos()
		local tr = util.TraceLine({ start = start, endpos = start + ply:GetAimVector() * 80, filter = ply, mask = MASK_SHOT })
		if GMEAT.IsFleshWall(tr) then GAMEMODE:WallBleed(tr.HitPos, tr.HitNormal, tr.Normal, 30, ply) end
	end)
end)
GMEAT_FLINCH_HIT, GMEAT_FLINCH_FALL, GMEAT_FLINCH_BLAST, GMEAT_FLINCH_BODY = 0, 1, 2, 3

hook.Add("PostEntityTakeDamage", "Gmeat_Flinch", function(ent, dmginfo, took)
	if not took or not IsValid(ent) or not ent:IsPlayer() or not ent:Alive() then return end
	local dmg = dmginfo:GetDamage()
	if dmg <= 0 or (ent.GmeatNextFlinch or 0) > CurTime() then return end
	ent.GmeatNextFlinch = CurTime() + 0.05

	local center = ent:WorldSpaceCenter()
	local kind, pos, dir
	if dmginfo:IsFallDamage() then
		kind, pos, dir = GMEAT_FLINCH_FALL, ent:GetPos(), Vector(0, 0, -1)
	elseif dmginfo:IsExplosionDamage() then
		local origin = dmginfo:GetDamagePosition()
		if origin:IsZero() then origin = IsValid(dmginfo:GetInflictor()) and dmginfo:GetInflictor():GetPos() or center end
		dir = center - origin
		if dir:IsZero() then dir = VectorRand() end
		kind, pos = GMEAT_FLINCH_BLAST, center
	else
		pos = dmginfo:GetDamagePosition()
		kind = GMEAT_FLINCH_HIT
		if pos:IsZero() or pos:DistToSqr(center) > 90 * 90 then
			kind, pos = GMEAT_FLINCH_BODY, center
		end
		dir = dmginfo:GetDamageForce()
		if dir:IsZero() then
			local attacker = dmginfo:GetAttacker()
			if IsValid(attacker) and attacker ~= ent then
				dir = pos - attacker:WorldSpaceCenter()
			else
				dir = Vector(math.Rand(-1, 1), math.Rand(-1, 1), 0)
			end
		end
	end
	dir:Normalize()

	net.Start("Gmeat_Flinch")
	net.WriteEntity(ent)
	net.WriteVector(pos)
	net.WriteNormal(dir)
	net.WriteUInt(math.Clamp(math.floor(dmg), 1, 255), 8)
	net.WriteUInt(kind, 2)
	net.SendPVS(center)
end)

hook.Add("PostEntityTakeDamage", "Gmeat_Blood", function(ent, dmginfo, took)
	if not took or not IsValid(ent) or not ent:IsPlayer() then return end
	local dmg = dmginfo:GetDamage()
	if dmg <= 0 or dmginfo:IsFallDamage() or dmginfo:IsDamageType(DMG_DROWN) then return end
	if (ent.GmeatNextBlood or 0) > CurTime() then return end
	ent.GmeatNextBlood = CurTime() + 0.06

	local pos = dmginfo:GetDamagePosition()
	if pos:IsZero() or pos:DistToSqr(ent:WorldSpaceCenter()) > 90 * 90 then
		pos = ent:WorldSpaceCenter()
	end
	local dir = dmginfo:GetDamageForce()
	if dir:IsZero() then
		local attacker = dmginfo:GetAttacker()
		dir = IsValid(attacker) and (pos - attacker:WorldSpaceCenter()) or VectorRand()
	end
	dir:Normalize()

	local headshot = ent:LastHitGroup() == HITGROUP_HEAD
	GAMEMODE:SendBlood(GMEAT_BLOOD_HIT, ent, pos, dir, dmg * (headshot and 2 or 1))
	wallSplat(ent, pos, dir)
end)

GM.Gibs = GM.Gibs or {}

function GM:CanEatGib(ply, gib)
	return IsValid(ply) and ply:Alive() and IsValid(gib) and not gib.GmeatEaten and ply:Health() < ply:GetMaxHealth()
end

function GM:EatGib(ply, gib)
	if not self:CanEatGib(ply, gib) then return false end
	gib.GmeatEaten = true
	local cfg = GMEAT.GibEating
	local heal = cfg.Heal[string.lower(gib:GetModel() or "")] or cfg.DefaultHeal
	ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + heal))
	if GMEAT.Sounds.GibEat then ply:EmitSound(GMEAT.Sounds.GibEat, 70, math.random(96, 104)) end
	self:SendBlood(GMEAT_BLOOD_HIT, NULL, gib:WorldSpaceCenter(), Vector(0, 0, 1), 25)
	gib:Remove()
	return true, heal
end

hook.Add("AllowPlayerPickup", "Gmeat_NoGibPickup", function(ply, ent)
	if IsValid(ent) and ent:GetClass() == "gmeat_gib" then return false end
end)

function GM:SpawnGibs(pos, dir, flesh, extras)
	extras = extras or {}
	for i = 1, flesh + #extras do
		local extra = extras[i - flesh]
		local gib = ents.Create("gmeat_gib")
		if IsValid(gib) then
			gib:SetModel(extra or FLESH_GIBS[math.random(#FLESH_GIBS)])
			if not extra then gib:SetMaterial("models/flesh") end
			gib:SetPos(pos + VectorRand() * 6)
			gib:SetAngles(AngleRand())
			gib:Spawn()
			local phys = gib:GetPhysicsObject()
			if IsValid(phys) then
				phys:SetVelocity(dir * math.Rand(120, 320) + VectorRand() * math.Rand(140, 280) + Vector(0, 0, math.Rand(160, 300)))
				phys:AddAngleVelocity(VectorRand() * 900)
			end
			table.insert(self.Gibs, gib)
		end
	end
	while #self.Gibs > GMEAT.Gore.MaxGibs do
		local old = table.remove(self.Gibs, 1)
		if IsValid(old) then old:Remove() end
	end
end

GM.Ragdolls = GM.Ragdolls or {}

local function physFor(rag, boneName)
	local bone = rag:LookupBone(boneName)
	if not bone then return end
	local physBone = rag:TranslateBoneToPhysBone(bone)
	if not physBone or physBone < 0 then return end
	local phys = rag:GetPhysicsObjectNum(physBone)
	if IsValid(phys) then return phys end
end

function GM:CreateDeathRagdoll(ply, dmginfo)
	local rag = ents.Create("prop_ragdoll")
	if not IsValid(rag) then return end
	rag:SetModel(ply:GetModel())
	rag:SetPos(ply:GetPos())
	rag:SetAngles(Angle(0, ply:EyeAngles().y, 0))
	rag:SetSkin(ply:GetSkin())
	rag:SetMaterial(ply:GetMaterial())
	if rag.SetBloodColor then rag:SetBloodColor(DONT_BLEED) end
	for _, bg in ipairs(ply:GetBodyGroups()) do
		rag:SetBodygroup(bg.id, ply:GetBodygroup(bg.id))
	end
	rag:Spawn()
	rag:Activate()
	rag:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	rag:SetNWVector("GmeatPlayerColor", ply:GetPlayerColor())

	local cfg = GMEAT.Gore
	local dir = hitDirection(ply, dmginfo)
	local push = Vector(dir.x, dir.y, 0)
	if not push:IsZero() then push:Normalize() end
	push = push * cfg.DeathPush
	local vel = ply:GetVelocity()
	vel.z = math.min(vel.z, 0)
	if vel:Length2D() > 250 then
		local z = vel.z
		vel = Vector(vel.x, vel.y, 0):GetNormalized() * 250
		vel.z = z
	end

	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		local bone = rag:TranslatePhysBoneToBone(i)
		if IsValid(phys) and bone then
			local pos, ang = ply:GetBonePosition(bone)
			if pos and ang then
				phys:SetPos(pos)
				phys:SetAngles(ang)
			end
			phys:SetVelocity(vel + push * math.Rand(0.7, 1.2))
			phys:AddAngleVelocity(VectorRand() * 200)
			phys:Wake()
		end
	end

	local record = {
		ent = rag,
		born = CurTime(),
		deathZ = ply:GetPos().z,
		nextFlail = 0,
		nextJolt = CurTime() + 0.15,
		limbs = {},
		torso = {},
		all = {},
		removed = {},
		damage = 0,
	}
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		if IsValid(phys) then record.all[#record.all + 1] = phys end
	end
	rag.GmeatCorpse = record
	local voice = string.find(string.lower(ply:GetModel() or ""), "female", 1, true) and "female01" or "male01"
	self:SetupWrithe(record, rag, dir, voice)
	for _, name in ipairs(FLAIL_BONES) do
		local phys = physFor(rag, name)
		if phys then record.limbs[#record.limbs + 1] = phys end
	end
	for _, name in ipairs(TORSO_BONES) do
		local phys = physFor(rag, name)
		if phys then record.torso[#record.torso + 1] = phys end
	end
	table.insert(self.Ragdolls, record)
	while #self.Ragdolls > cfg.MaxRagdolls do
		local old = table.remove(self.Ragdolls, 1)
		if IsValid(old.ent) then old.ent:Remove() end
	end

	return rag
end

function GM:DeathCry(rag)
	local rec = rag.GmeatCorpse
	local cries = GMEAT.Sounds and GMEAT.Sounds.Death
	local path
	if cries and #cries > 0 then
		path = cries[math.random(#cries)]
		rag:EmitSound(path, GMEAT.Sounds.DeathLevel or 85)
	else
		path = "vo/npc/" .. (rec and rec.voice or "male01") .. "/pain0" .. math.random(7, 9) .. ".wav"
		rag:EmitSound(path, 80, math.random(95, 115))
	end
	if rec then rec.cry = path end
end

function GM:SilenceCorpse(rag, rec)
	if rec and rec.cry and IsValid(rag) then
		rag:StopSound(rec.cry)
		rec.cry = nil
	end
end

function GM:RagdollThink()
	local now = CurTime()
	local cfg = GMEAT.Gore
	for i = #self.Ragdolls, 1, -1 do
		local rec = self.Ragdolls[i]
		local rag = rec.ent
		local age = now - rec.born
		if not IsValid(rag) then
			table.remove(self.Ragdolls, i)
		elseif age > cfg.RagdollLifetime + 1 or rag:GetPos().z < rec.deathZ - 400 then
			rag:Remove()
			table.remove(self.Ragdolls, i)
		elseif age > cfg.RagdollLifetime then
			rag:SetRenderMode(RENDERMODE_TRANSALPHA)
			rag:SetColor(Color(255, 255, 255, math.Clamp((1 - (age - cfg.RagdollLifetime)) * 255, 0, 255)))
		elseif rec.crawl then
			self:CrawlThink(rec)
		elseif age < cfg.WritheTime + 0.5 or now < (rec.agitatedUntil or 0) then
			self:WritheThink(rec, age)
		end
	end
end

local function findHitBone(ply, dmgPos)
	local hitgroup = ply:LastHitGroup()
	local candidates = {}
	for _, limb in ipairs(LIMBS) do
		if hitgroup == limb.hitgroup or hitgroup == HITGROUP_GENERIC or hitgroup == 0 then
			for _, name in ipairs(limb.bones) do candidates[#candidates + 1] = name end
		end
	end
	local best, bestDist
	for _, name in ipairs(candidates) do
		local bone = ply:LookupBone(name)
		if bone then
			local pos = ply:GetBonePosition(bone)
			if pos then
				local d = pos:Distance(dmgPos)
				if not bestDist or d < bestDist then best, bestDist = name, d end
			end
		end
	end
	if not best then return end
	if hitgroup ~= HITGROUP_GENERIC and hitgroup ~= 0 then return best end
	if bestDist > 22 then return end
	for _, name in ipairs(TORSO_REFERENCE) do
		local bone = ply:LookupBone(name)
		local pos = bone and ply:GetBonePosition(bone)
		if pos and pos:Distance(dmgPos) < bestDist then return end
	end
	return best
end

function GM:HandleDeathBody(ply, attacker, dmginfo)
	local dmgPos = dmginfo:GetDamagePosition()
	if dmgPos:IsZero() or dmgPos:DistToSqr(ply:WorldSpaceCenter()) > 120 * 120 then
		dmgPos = ply:WorldSpaceCenter()
	end
	local dir = hitDirection(ply, dmginfo)
	ply:SetNWVector("GmeatDeathPos", ply:WorldSpaceCenter())

	local gore = goreEnabled()
	local fullGib = gore and (dmginfo:IsExplosionDamage() or dmginfo:GetDamage() >= GMEAT.Gore.FullGibDamage)
	if fullGib then
		local center = ply:WorldSpaceCenter()
		self:SpawnGibs(center, dir, math.random(8, 11), bodyOrgans())
		self:SendBlood(GMEAT_BLOOD_BURST, NULL, center, dir, 255)
		ply:SetNWEntity("GmeatRagdoll", NULL)
		ply:EmitSound("physics/flesh/flesh_bloody_break.wav", 85)
		return
	end

	local hitBone = gore and findHitBone(ply, dmgPos)
	local rag = self:CreateDeathRagdoll(ply, dmginfo)
	ply:SetNWEntity("GmeatRagdoll", rag or NULL)
	if not IsValid(rag) then return end

	local rec = rag.GmeatCorpse
	if hitBone ~= "ValveBiped.Bip01_Head1" then self:DeathCry(rag) end
	self:MaybeBloodVomit(rag, hitBone == "ValveBiped.Bip01_Head1" or ply:LastHitGroup() == HITGROUP_HEAD)
	local woundBone = self:NearestWoundBone(ply, dmgPos)
	if rec then rec.woundBone = woundBone end
	if not hitBone and woundBone then
		local b = rag:LookupBone(woundBone)
		timer.Simple(0.15, function()
			if IsValid(rag) and b then self:SendBlood(GMEAT_BLOOD_GUSH, rag, rag:GetBonePosition(b) or dmgPos, dir, 220, b) end
		end)
	end
	if not hitBone then return end

	local limbPos = ply:GetBonePosition(ply:LookupBone(hitBone)) or dmgPos
	self:BlowOffLimb(rag, rag.GmeatCorpse, hitBone, dir, limbPos)
	if hitBone == "ValveBiped.Bip01_Head1" and math.random() < GMEAT.Gore.HeadlessCrawlChance then
		self:StartHeadlessCrawl(rag, dir)
	end
end

function GM:HideBoneChain(rag, bone)
	rag:ManipulateBoneScale(bone, Vector(0, 0, 0))
	local physBone = rag:TranslateBoneToPhysBone(bone)
	if physBone and physBone >= 0 and rag:TranslatePhysBoneToBone(physBone) == bone then
		local phys = rag:GetPhysicsObjectNum(physBone)
		if IsValid(phys) then phys:EnableCollisions(false) end
	end
	for _, child in ipairs(rag:GetChildBones(bone) or {}) do
		self:HideBoneChain(rag, child)
	end
end

function GM:BlowOffLimb(rag, rec, boneName, dir, limbPos)
	if rec and rec.removed[boneName] then return false end
	local bone = rag:LookupBone(boneName)
	if not bone then return false end
	limbPos = limbPos or rag:GetBonePosition(bone) or rag:WorldSpaceCenter()
	self:HideBoneChain(rag, bone)
	if boneName == "ValveBiped.Bip01_Head1" then self:SilenceCorpse(rag, rec) end

	if rec then
		for _, limb in ipairs(LIMBS) do
			local below = false
			for _, name in ipairs(limb.bones) do
				if name == boneName then below = true end
				if below then rec.removed[name] = true end
			end
		end
	end

	if rec then
		local parent = rag:GetBoneParent(bone)
		if parent and parent >= 0 then rec.woundBone = rag:GetBoneName(parent) end
	end

	local isHead = boneName == "ValveBiped.Bip01_Head1"
	self:SpawnGibs(limbPos, dir, isHead and 4 or 3)
	self:SendBlood(GMEAT_BLOOD_BURST, NULL, limbPos, dir, isHead and 200 or 140)
	rag:EmitSound("physics/flesh/flesh_bloody_break.wav", 80)
	timer.Simple(0.15, function()
		if IsValid(rag) then self:SendBlood(GMEAT_BLOOD_STUMP, rag, limbPos, dir, isHead and 255 or 180, bone) end
	end)
	return true
end

local CORPSE_DAMAGE_TYPES = bit.bor(DMG_BULLET, DMG_BUCKSHOT, DMG_CLUB, DMG_SLASH, DMG_BLAST, DMG_SONIC)

local function findCorpseLimb(rag, rec, pos)
	local best, bestDist
	for _, limb in ipairs(LIMBS) do
		for _, name in ipairs(limb.bones) do
			if not rec.removed[name] then
				local bone = rag:LookupBone(name)
				local bp = bone and rag:GetBonePosition(bone)
				if bp then
					local d = bp:Distance(pos)
					if not bestDist or d < bestDist then best, bestDist = name, d end
				end
			end
		end
	end
	if not best or bestDist > 20 then return end
	for _, name in ipairs(TORSO_REFERENCE) do
		local bone = rag:LookupBone(name)
		local bp = bone and rag:GetBonePosition(bone)
		if bp and bp:Distance(pos) < bestDist then return end
	end
	return best
end

function GM:GibCorpse(rag, rec, dir)
	if rec.gibbed then return end
	rec.gibbed = true
	local center = rag:WorldSpaceCenter()
	self:SpawnGibs(center, dir, math.random(8, 11), bodyOrgans())
	self:SendBlood(GMEAT_BLOOD_BURST, NULL, center, dir, 255)
	rag:EmitSound("physics/flesh/flesh_bloody_break.wav", 85)
	self:SilenceCorpse(rag, rec)
	timer.Simple(0, function() if IsValid(rag) then rag:Remove() end end)
end

function GM:CorpseHit(rag, rec, pos, dir, dmg, explosion)
	if rec.gibbed then return end
	local now = CurTime()
	if (rec.nextBlood or 0) <= now then
		rec.nextBlood = now + 0.05
		self:SendBlood(GMEAT_BLOOD_HIT, rag, pos, dir, dmg)
		wallSplat(rag, pos, dir)
	end

	local nearest, nearestDist
	for _, phys in ipairs(rec.all) do
		if IsValid(phys) then
			local d = phys:GetPos():DistToSqr(pos)
			if not nearestDist or d < nearestDist then nearest, nearestDist = phys, d end
		end
	end
	if nearest then nearest:AddVelocity(Vector(dir.x, dir.y, 0) * 90) end

	rec.agitatedUntil = now + GMEAT.Gore.AgitateTime
	rec.woundBone = self:NearestWoundBone(rag, pos, rec.removed) or rec.woundBone

	if not goreEnabled() then return end
	rec.damage = rec.damage + dmg
	if explosion or dmg >= GMEAT.Gore.FullGibDamage or rec.damage >= GMEAT.Gore.CorpseGibDamage then
		self:GibCorpse(rag, rec, dir)
		return
	end
	if dmg >= GMEAT.Gore.CorpseLimbDamage then
		local boneName = findCorpseLimb(rag, rec, pos)
		if boneName then self:BlowOffLimb(rag, rec, boneName, dir) end
	end
end

hook.Add("EntityTakeDamage", "Gmeat_CorpseDamage", function(ent, dmginfo)
	local rec = IsValid(ent) and ent.GmeatCorpse
	if not rec then return end
	if bit.band(dmginfo:GetDamageType(), CORPSE_DAMAGE_TYPES) == 0 then return end
	local dmg = dmginfo:GetDamage()
	if dmg <= 0 then return end
	local pos = dmginfo:GetDamagePosition()
	if pos:IsZero() or pos:DistToSqr(ent:WorldSpaceCenter()) > 100 * 100 then
		pos = ent:WorldSpaceCenter()
	end
	GAMEMODE:CorpseHit(ent, rec, pos, hitDirection(ent, dmginfo), dmg, dmginfo:IsExplosionDamage())
end)

function GM:PlayerDeathSound()
	return true
end
