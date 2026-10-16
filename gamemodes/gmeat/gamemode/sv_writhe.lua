local P = {
	pelvis = "ValveBiped.Bip01_Pelvis",
	chest = "ValveBiped.Bip01_Spine2",
	head = "ValveBiped.Bip01_Head1",
	lhand = "ValveBiped.Bip01_L_Hand",
	rhand = "ValveBiped.Bip01_R_Hand",
	lfore = "ValveBiped.Bip01_L_Forearm",
	rfore = "ValveBiped.Bip01_R_Forearm",
	lfoot = "ValveBiped.Bip01_L_Foot",
	rfoot = "ValveBiped.Bip01_R_Foot",
	lthigh = "ValveBiped.Bip01_L_Thigh",
	rthigh = "ValveBiped.Bip01_R_Thigh",
}

local ARM_BONES = {
	l = { "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand" },
	r = { "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand" },
}

GMEAT.WoundBones = {
	"ValveBiped.Bip01_Head1", "ValveBiped.Bip01_Neck1",
	"ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Spine1", "ValveBiped.Bip01_Spine", "ValveBiped.Bip01_Pelvis",
	"ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm",
	"ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm",
	"ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_L_Calf",
	"ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf",
}

local function physFor(rag, boneName)
	local bone = rag:LookupBone(boneName)
	if not bone then return end
	local physBone = rag:TranslateBoneToPhysBone(bone)
	if not physBone or physBone < 0 then return end
	local phys = rag:GetPhysicsObjectNum(physBone)
	if IsValid(phys) then return phys end
end

local function steer(phys, target, maxSpeed, gain)
	if not IsValid(phys) then return end
	local delta = target - phys:GetPos()
	local dist = delta:Length()
	if dist < 0.5 then return end
	local desired = delta * (math.min(dist * 8, maxSpeed) / dist)
	phys:AddVelocity((desired - phys:GetVelocity()) * gain)
	phys:Wake()
end

local function spin(phys, worldAngVel, gain)
	if not IsValid(phys) then return end
	local want = phys:WorldToLocalVector(worldAngVel)
	phys:AddAngleVelocity((want - phys:GetAngleVelocity()) * gain)
end

local function armFree(rec, side)
	for _, name in ipairs(ARM_BONES[side]) do
		if rec.removed[name] then return false end
	end
	return true
end

function GM:NearestWoundBone(ent, pos, removed)
	local best, bestDist
	for _, name in ipairs(GMEAT.WoundBones) do
		if not (removed and removed[name]) then
			local bone = ent:LookupBone(name)
			local bp = bone and ent:GetBonePosition(bone)
			if bp then
				local d = bp:DistToSqr(pos)
				if not bestDist or d < bestDist then best, bestDist = name, d end
			end
		end
	end
	return best
end

function GM:SetupWrithe(rec, rag, awayDir, voice)
	rec.p = {}
	for key, name in pairs(P) do rec.p[key] = physFor(rag, name) end
	local crawl = Vector(awayDir.x, awayDir.y, 0)
	if crawl:IsZero() then crawl = Vector(math.Rand(-1, 1), math.Rand(-1, 1), 0) end
	crawl:Normalize()
	rec.crawlDir = crawl
	rec.seed = math.Rand(0, 100)
	rec.voice = voice
	rec.nextMoan = CurTime() + math.Rand(0.9, 1.4)
	rec.nextSpasm = CurTime() + 0.25
	rec.nextJerk = 0
	rec.crawlCycle = math.Rand(1.2, 1.6)
end

function GM:WritheThink(rec, age)
	local cfg = GMEAT.Gore
	local now = CurTime()
	local rag, p = rec.ent, rec.p
	if not p or not IsValid(p.pelvis) or not IsValid(p.chest) then return end

	local k = age < 2.5 and 1 or math.max(0, 1 - (age - 2.5) / (cfg.WritheTime - 2.5))
	if now < (rec.agitatedUntil or 0) then k = math.max(k, 0.8) end
	if k <= 0 then
		if not rec.gasped then
			rec.gasped = true
			if rec.removed["ValveBiped.Bip01_Head1"] then return end
			if #(GMEAT.Sounds and GMEAT.Sounds.Death or {}) > 0 then return end
			rag:EmitSound("vo/npc/" .. rec.voice .. "/pain0" .. math.random(1, 6) .. ".wav", 75, math.random(78, 88))
		end
		return
	end
	local t = age + rec.seed

	local pelvis, chest = p.pelvis:GetPos(), p.chest:GetPos()
	local up = chest - pelvis
	if up:IsZero() then return end
	up:Normalize()
	local side = (IsValid(p.lthigh) and IsValid(p.rthigh)) and (p.lthigh:GetPos() - p.rthigh:GetPos()) or up:Cross(Vector(0, 0, 1))
	if side:IsZero() then side = Vector(1, 0, 0) end
	side:Normalize()
	local front = side:Cross(up)
	front:Normalize()

	if age < cfg.SpasmTime and now >= rec.nextJerk then
		rec.nextJerk = now + 0.06
		local s = 1 - age / cfg.SpasmTime
		for _, phys in ipairs(rec.limbs) do
			if IsValid(phys) then phys:AddVelocity(VectorRand() * 260 * s) end
		end
	end

	local woundPos
	if rec.woundBone then
		local b = rag:LookupBone(rec.woundBone)
		woundPos = b and rag:GetBonePosition(b)
	end
	woundPos = woundPos or chest
	local woundSide = rec.woundBone and ((string.find(rec.woundBone, "_L_", 1, true) and "l") or (string.find(rec.woundBone, "_R_", 1, true) and "r"))
	local grabbers, crawlSide = {}, nil
	for _, s in ipairs({ "l", "r" }) do
		if armFree(rec, s) and s ~= woundSide then grabbers[#grabbers + 1] = s end
	end
	if #grabbers == 2 and age > 3 then
		crawlSide = (math.floor(t / 3) % 2 == 0) and "l" or "r"
		grabbers = { crawlSide == "l" and "r" or "l" }
	elseif #grabbers == 1 then
		local other = grabbers[1] == "l" and "r" or "l"
		if armFree(rec, other) then crawlSide = other end
	end
	for _, s in ipairs(grabbers) do
		local target = woundPos + front * 5 + side * (s == "l" and 3 or -3)
		steer(p[s .. "hand"], target, cfg.GrabSpeed * (0.4 + 0.6 * k), 0.3)
		steer(p[s .. "fore"], LerpVector(0.5, chest, target) + front * 8, cfg.GrabSpeed * 0.6, 0.15)
	end

	if crawlSide and IsValid(p[crawlSide .. "hand"]) then
		local phase = (t % rec.crawlCycle) / rec.crawlCycle
		local reach = chest + rec.crawlDir * 42 + side * (crawlSide == "l" and 10 or -10)
		reach.z = math.min(reach.z, pelvis.z)
		if phase < 0.55 then
			steer(p[crawlSide .. "hand"], reach, 300, 0.3)
		else
			steer(p[crawlSide .. "hand"], reach, 120, 0.1)
			local want = rec.crawlDir * cfg.CrawlPull * k
			for _, phys in ipairs({ p.chest, p.pelvis }) do
				local v = phys:GetVelocity()
				phys:AddVelocity(Vector(want.x - v.x, want.y - v.y, 0) * 0.08)
			end
		end
	end

	local roll = math.sin(t * 2.6) * cfg.RollSpeed * k
	spin(p.chest, up * roll + side * math.sin(t * 1.7) * cfg.RollSpeed * 0.4 * k, 0.12)
	spin(p.pelvis, up * (-roll * 0.7), 0.1)

	for i, s in ipairs({ "l", "r" }) do
		local foot = p[s .. "foot"]
		local footName = s == "l" and "ValveBiped.Bip01_L_Foot" or "ValveBiped.Bip01_R_Foot"
		if IsValid(foot) and not rec.removed[footName] then
			local bend = (math.sin(t * 3.3 + (i == 1 and 0 or math.pi)) + 1) * 0.5
			local target = pelvis - up * (34 - bend * 18) + front * (bend * 14) + side * (s == "l" and 7 or -7)
			steer(foot, target, cfg.LegSpeed * k, 0.18)
		end
	end

	if IsValid(p.head) and not rec.removed["ValveBiped.Bip01_Head1"] then
		steer(p.head, chest + up * 14 + side * math.sin(t * 4.3) * 9 + front * 3, 200 * k, 0.15)
	end

	if now >= rec.nextSpasm then
		rec.nextSpasm = now + math.Rand(0.5, 1.3) / math.max(k, 0.3)
		for _, phys in ipairs(rec.limbs) do
			if IsValid(phys) and math.random() < 0.5 then phys:AddVelocity(VectorRand() * 220 * k) end
		end
		p.chest:AddVelocity(Vector(0, 0, 70 * k))
	end

	if now >= rec.nextMoan and k > 0.2 and not rec.removed["ValveBiped.Bip01_Head1"]
		and #(GMEAT.Sounds and GMEAT.Sounds.Death or {}) == 0 then
		rec.nextMoan = now + math.Rand(1.4, 2.6)
		rag:EmitSound("vo/npc/" .. rec.voice .. "/moan0" .. math.random(1, 5) .. ".wav", 75, math.random(90, 105))
	end

	for _, phys in ipairs({ p.pelvis, p.chest }) do
		local v = phys:GetVelocity()
		local changed = false
		if v.z > cfg.MaxUpSpeed then
			v.z = cfg.MaxUpSpeed
			changed = true
		end
		local h = math.sqrt(v.x * v.x + v.y * v.y)
		if h > cfg.MaxSlide then
			v.x, v.y = v.x / h * cfg.MaxSlide, v.y / h * cfg.MaxSlide
			changed = true
		end
		if changed then phys:SetVelocity(v) end
	end
end
