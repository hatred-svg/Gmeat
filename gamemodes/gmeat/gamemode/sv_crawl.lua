local P = "ValveBiped.Bip01_"

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
	if dist < 0.3 then return end
	local desired = delta * (math.min(dist * 8, maxSpeed) / dist)
	phys:AddVelocity((desired - phys:GetVelocity()) * gain)
	phys:Wake()
end

local function steady(phys, gain)
	if IsValid(phys) then phys:AddAngleVelocity(-phys:GetAngleVelocity() * gain) end
end

local function flat(v)
	local f = Vector(v.x, v.y, 0)
	if f:IsZero() then f = Vector(1, 0, 0) end
	f:Normalize()
	return f
end

local function armGone(rec, s)
	local S = s == "l" and "L" or "R"
	return rec.removed[P .. S .. "_UpperArm"] or rec.removed[P .. S .. "_Forearm"] or rec.removed[P .. S .. "_Hand"]
end

function GM:StartHeadlessCrawl(rag, dir)
	local rec = IsValid(rag) and rag.GmeatCorpse
	if not rec then return false end
	if armGone(rec, "l") and armGone(rec, "r") then return false end
	local cfg = GMEAT.Gore
	local p = {}
	for key, name in pairs({ pelvis = "Pelvis", chest = "Spine2", lhand = "L_Hand", rhand = "R_Hand", lfore = "L_Forearm", rfore = "R_Forearm",
		lfoot = "L_Foot", rfoot = "R_Foot", lcalf = "L_Calf", rcalf = "R_Calf" }) do
		p[key] = physFor(rag, P .. name)
	end
	if not (IsValid(p.pelvis) and IsValid(p.chest)) then return false end

	local now = CurTime()
	rec.crawl = {
		start = now,
		begin = now + math.Rand(0.5, 0.8),
		ends = now + math.Rand(cfg.CrawlTime[1], cfg.CrawlTime[2]),
		heading = flat(dir):Angle().y + math.Rand(-25, 25),
		speed = math.Rand(cfg.CrawlSpeed[1], cfg.CrawlSpeed[2]),
		period = math.Rand(1.0, 1.3),
		floorZ = rec.deathZ,
		damage = rec.damage or 0,
		lead = math.random() < 0.5 and "l" or "r",
		cycleStart = 0,
		plant = {},
		lastChest = p.chest:GetPos(),
		seed = math.Rand(0, 100),
		p = p,
	}
	return true
end

function GM:EndHeadlessCrawl(rec)
	rec.crawl = nil
end

function GM:CrawlThink(rec)
	local cr = rec.crawl
	local now = CurTime()
	local p = cr.p
	local cfg = GMEAT.Gore
	if now >= cr.ends or (rec.damage or 0) - cr.damage >= cfg.CrawlKnockdown or not IsValid(p.pelvis) or not IsValid(p.chest)
		or (armGone(rec, "l") and armGone(rec, "r")) then
		self:EndHeadlessCrawl(rec)
		return
	end
	if armGone(rec, cr.lead) then
		cr.lead = cr.lead == "l" and "r" or "l"
		cr.plant[cr.lead] = nil
	end

	if now < cr.begin then
		steady(p.chest, 0.15)
		steady(p.pelvis, 0.15)
		return
	end

	local progress = (now - cr.begin) / math.max(cr.ends - cr.begin, 0.1)
	local period = cr.period * (1 + 0.6 * progress)
	if cr.cycleStart == 0 then cr.cycleStart = now end
	local u = (now - cr.cycleStart) / period
	if u >= 1 then
		cr.cycleStart = now
		u = 0
		local other = cr.lead == "l" and "r" or "l"
		if not armGone(rec, other) then cr.lead = other end
		local chestNow = p.chest:GetPos()
		if (Vector(chestNow.x, chestNow.y, 0) - Vector(cr.lastChest.x, cr.lastChest.y, 0)):Length() < 4 then
			cr.heading = cr.heading + (math.random() < 0.5 and -1 or 1) * math.Rand(40, 75)
		end
		cr.lastChest = chestNow
		cr.heading = cr.heading + math.Rand(-15, 15)
		cr.plant[cr.lead] = nil
	end

	local fwd = Angle(0, cr.heading, 0):Forward()
	local side = Vector(-fwd.y, fwd.x, 0)
	local chest, pelvis = p.chest:GetPos(), p.pelvis:GetPos()
	local floor = cr.floorZ
	local lead = cr.lead
	local sideSign = lead == "l" and 1 or -1
	local reach = 0.45

	local hand = p[lead .. "hand"]
	if IsValid(hand) then
		if u < reach then
			local k = u / reach
			local target = Vector(chest.x, chest.y, floor + 4) + fwd * (8 + 22 * k) + side * sideSign * 7 + Vector(0, 0, math.sin(k * math.pi) * 7)
			steer(hand, target, 260, 0.3)
			steer(p[lead .. "fore"], LerpVector(0.5, chest, target) + Vector(0, 0, 3), 200, 0.15)
		else
			cr.plant[lead] = cr.plant[lead] or (Vector(chest.x, chest.y, floor + 3) + fwd * 30 + side * sideSign * 7)
			steer(hand, cr.plant[lead], 260, 0.35)
		end
	end
	local other = lead == "l" and "r" or "l"
	if IsValid(p[other .. "hand"]) and not armGone(rec, other) then
		steer(p[other .. "hand"], Vector(chest.x, chest.y, floor + 3) + side * -sideSign * 10 - fwd * 2, 180, 0.15)
	end

	local low = floor + 7
	if u >= reach and cr.plant[lead] then
		local k = (u - reach) / (1 - reach)
		local pull = math.sin(k * math.pi)
		local toward = Vector(cr.plant[lead].x, cr.plant[lead].y, low) - fwd * 12
		steer(p.chest, LerpVector(0.35, Vector(chest.x, chest.y, low), toward), cr.speed * (0.4 + 1.6 * pull), 0.25)
		steer(p.pelvis, Vector(chest.x, chest.y, floor + 6) - fwd * 24, cr.speed * (0.3 + 1.4 * pull), 0.2)
	else
		steer(p.chest, Vector(chest.x, chest.y, low), 60, 0.08)
		steer(p.pelvis, Vector(chest.x, chest.y, floor + 6) - fwd * 24, 60, 0.08)
	end
	steady(p.chest, 0.15)
	steady(p.pelvis, 0.15)

	for _, s in ipairs({ "l", "r" }) do
		local foot = p[s .. "foot"]
		local S = s == "l" and "L" or "R"
		if IsValid(foot) and not rec.removed[P .. S .. "_Foot"] then
			local pushing = s ~= lead and u >= reach
			local back = pushing and 18 or 32
			local target = Vector(pelvis.x, pelvis.y, floor + 3) - fwd * back + side * (s == "l" and 6 or -6)
			steer(foot, target, 160, 0.15)
			local calf = p[s .. "calf"]
			if IsValid(calf) and pushing then steer(calf, (target + pelvis) * 0.5 + side * (s == "l" and 6 or -6) + Vector(0, 0, 4), 140, 0.1) end
		end
	end

	for _, phys in ipairs({ p.chest, p.pelvis }) do
		local v = phys:GetVelocity()
		if v.z > 40 then phys:SetVelocity(Vector(v.x, v.y, 40)) end
	end
end
