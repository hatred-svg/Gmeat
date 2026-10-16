local cvFlesh = CreateClientConVar("gmeat_flesh_maze", "1", true, false, "Flesh walls and ceiling tentacles (0 = off).", 0, 1)

local CFG = GMEAT.FleshMaze

local function normName(name)
	name = string.lower(tostring(name or "")):gsub("\\", "/")
	name = name:gsub("^materials/", ""):gsub("%.vmt$", "")
	return name
end

local function skipByName(name)
	for _, word in ipairs(CFG.SkipNames) do
		if string.find(name, word, 1, true) then return true end
	end
	return false
end

local function skipByMaterial(name)
	local mat = Material(name)
	if not mat or mat:IsError() then return false end
	if mat.IsTranslucent and mat:IsTranslucent() then return true end
	if (mat:GetInt("$selfillum") or 0) ~= 0 then return true end
	if (mat:GetInt("$additive") or 0) ~= 0 then return true end
	return false
end

local classes = {}

local function classify(model)
	if classes[model] then return classes[model] end
	local areas = {}
	local meshes = util.GetModelMeshes(model)
	for _, m in ipairs(meshes or {}) do
		local name = normName(m.material)
		local a = areas[name] or { up = 0, total = 0 }
		areas[name] = a
		local tris = m.triangles or {}
		for i = 1, #tris - 2, 3 do
			local v1, v2, v3 = tris[i], tris[i + 1], tris[i + 2]
			local area = (v2.pos - v1.pos):Cross(v3.pos - v1.pos):Length() * 0.5
			local n = (v1.normal or Vector()) + (v2.normal or Vector()) + (v3.normal or Vector())
			a.total = a.total + area
			if n:Length() > 0 and n.z / n:Length() > 0.7 then a.up = a.up + area end
		end
	end
	local result = {}
	for name, a in pairs(areas) do
		if skipByName(name) or skipByMaterial(name) then
			result[name] = "skip"
		elseif a.total > 0 and a.up / a.total >= CFG.FloorUpShare then
			result[name] = "floor"
		else
			result[name] = "flesh"
		end
	end
	classes[model] = result
	return result
end

local function fleshRoom(room)
	local model = room:GetModel()
	if not model or model == "" then return false end
	local cls = classify(model)
	for i, name in ipairs(room:GetMaterials() or {}) do
		if cls[normName(name)] == "flesh" then room:SetSubMaterial(i - 1, CFG.Material) end
	end
	room.GmeatFleshed = true
	return true
end

local function unfleshRoom(room)
	for i = 1, #(room:GetMaterials() or {}) do room:SetSubMaterial(i - 1, "") end
	room.GmeatFleshed = nil
end

local decor = {}

local function removeDecor(d)
	for _, m in ipairs(d.models) do if IsValid(m) then m:Remove() end end
end

local function seededRandom(seed)
	local s = (seed * 7919 + 104729) % 2147483647
	return function(a, b)
		s = (s * 48271) % 2147483647
		local f = s / 2147483647
		if a then return a + f * (b - a) end
		return f
	end
end

local function tongueBones(ent)
	local list = {}
	local first = ent:LookupBone("Barnacle.tongue1")
	if first then
		for i = first, first + 7 do
			if string.find(string.lower(ent:GetBoneName(i) or ""), "tongue", 1, true) then list[#list + 1] = i end
		end
	else
		for i = 0, (ent:GetBoneCount() or 0) - 1 do
			if string.find(string.lower(ent:GetBoneName(i) or ""), "tongue", 1, true) then list[#list + 1] = i end
		end
	end
	return list
end

local function hangTongue(ent)
	local bones = ent.GmeatTongue
	if not bones or #bones == 0 then return end
	local baseBone = ent:LookupBone("Barnacle.base")
	local baseM = baseBone and ent:GetBoneMatrix(baseBone) or ent:GetBoneMatrix(bones[1])
	if not baseM then return end
	local top = baseM:GetTranslation()
	local len = math.max(math.min(ent.GmeatLength, top.z - (ent.GmeatMinTipZ or -math.huge)), 4)
	local t = CurTime() + ent.GmeatPhase
	local segments = math.max(#bones - 2, 1)
	local prev = top
	local right = ent:GetRight()
	for k, bone in ipairs(bones) do
		local m = ent:GetBoneMatrix(bone)
		if m then
			local f = math.min(k - 1, segments) / segments
			local sway = CFG.SwayAmount * f ^ 1.5
			local pos = top + Vector(math.sin(t * 0.7 + f * 1.3) * sway, math.cos(t * 0.53 + f * 1.1) * sway, -len * f)
			local fwd = pos - prev
			if fwd:Length() < 0.01 then fwd = Vector(0, 0, -1) end
			fwd:Normalize()
			local r = right - fwd * right:Dot(fwd)
			if r:Length() < 0.01 then r = Vector(1, 0, 0) end
			r:Normalize()
			m:SetTranslation(pos)
			m:SetAngles(fwd:AngleEx(r:Cross(fwd)))
			ent:SetBoneMatrix(bone, m)
			if k <= segments + 1 then prev = pos end
			ent.GmeatTip = pos
		end
	end
end

local stats = { rooms = 0, anchors = 0, tentacles = 0, tongues = 0, bones = 0, noModel = 0, failed = 0 }

local function spawnTentacle(anchor, rand)
	if not file.Exists(CFG.TentacleModel, "GAME") then stats.noModel = stats.noModel + 1 return end
	util.PrecacheModel(CFG.TentacleModel)
	local ent = ClientsideModel(CFG.TentacleModel, RENDERGROUP_OPAQUE)
	if not IsValid(ent) then stats.failed = stats.failed + 1 return end
	ent:SetPos(anchor.ceil - Vector(0, 0, 1))
	ent:SetAngles(Angle(0, rand(0, 360), 0))
	ent:SetMaterial(CFG.Material)
	local seq = ent:LookupSequence("idle01")
	if seq and seq >= 0 then ent:ResetSequence(seq) end
	ent:SetupBones()
	ent.GmeatTongue = tongueBones(ent)
	ent.GmeatLength = rand(CFG.TentacleLength[1], CFG.TentacleLength[2])
	ent.GmeatMinTipZ = anchor.floorZ + CFG.TipMinHeight
	ent.GmeatPhase = rand(0, 100)
	ent.GmeatAnimRate = rand(0.6, 1)
	ent:AddCallback("BuildBonePositions", hangTongue)
	ent:SetRenderBounds(Vector(-24, -24, -(ent.GmeatLength + 40)), Vector(24, 24, 8))
	stats.tentacles = stats.tentacles + 1
	if #ent.GmeatTongue > 0 then stats.tongues = stats.tongues + 1 end
	local models = { ent }
	if rand() < CFG.BoneChance and #ent.GmeatTongue > 0 then
		local bone = ClientsideModel(CFG.BoneModels[math.floor(rand(1, #CFG.BoneModels + 0.999))], RENDERGROUP_OPAQUE)
		if IsValid(bone) then
			bone:SetPos(anchor.ceil - Vector(0, 0, ent.GmeatLength))
			bone.GmeatHangFrom = ent
			bone.GmeatSpin = rand(-25, 25)
			models[#models + 1] = bone
			stats.bones = stats.bones + 1
		end
	end
	return models
end

local function decorateRoom(info)
	local room = Entity(info.id)
	if not IsValid(room) or room:GetClass() ~= "sector75_room_entity" then return false end
	for _, existing in ipairs(decor) do
		if existing.room == room then info.GmeatDecorated = true return true end
	end
	local rand = seededRandom(info.id)
	local d = { room = room, models = {} }
	for _, anchor in ipairs(info.anchors or {}) do
		local models = spawnTentacle(anchor, rand)
		for _, m in ipairs(models or {}) do d.models[#d.models + 1] = m end
	end
	stats.rooms = stats.rooms + 1
	stats.anchors = stats.anchors + #(info.anchors or {})
	decor[#decor + 1] = d
	info.GmeatDecorated = true
	return true
end

concommand.Add("gmeat_flesh_debug", function()
	local known = #(GAMEMODE.MapRoomList or {})
	local fleshed = 0
	for _, r in ipairs(ents.FindByClass("sector75_room_entity")) do if r.GmeatFleshed then fleshed = fleshed + 1 end end
	print(string.format("[Gmeat] rooms on the map: %d known, %d fleshed, %d decorated (others are decorated once you've been near them)", known, fleshed, stats.rooms))
	print(string.format("[Gmeat] tentacle anchors from the server: %d; tentacles spawned: %d (%d with a tongue, %d with a bone)",
		stats.anchors, stats.tentacles, stats.tongues, stats.bones))
	print(string.format("[Gmeat] problems: barnacle model file not found %d times (%s), couldn't create the model %d times",
		stats.noModel, CFG.TentacleModel, stats.failed))
end)

local nextScan = 0
hook.Add("Think", "Gmeat_FleshMaze", function()
	local now = RealTime()
	local on = cvFlesh:GetBool()

	for i = #decor, 1, -1 do
		local d = decor[i]
		if not IsValid(d.room) or not on then
			removeDecor(d)
			table.remove(decor, i)
		else
			for _, m in ipairs(d.models) do
				if IsValid(m) then
					if m.GmeatHangFrom then
						local tip = IsValid(m.GmeatHangFrom) and m.GmeatHangFrom.GmeatTip
						if tip then
							m:SetPos(tip - Vector(0, 0, 3))
							m:SetAngles(Angle(0, CurTime() * m.GmeatSpin, 0))
						end
					else
						m:SetCycle((CurTime() * 0.25 * (m.GmeatAnimRate or 1) + (m.GmeatPhase or 0)) % 1)
					end
				end
			end
		end
	end

	if now < nextScan then return end
	nextScan = now + 0.5

	local budget = 1
	for _, room in ipairs(ents.FindByClass("sector75_room_entity")) do
		if on and not room.GmeatFleshed then
			local known = classes[room:GetModel() or ""] ~= nil
			if known or budget > 0 then
				if not known then budget = budget - 1 end
				fleshRoom(room)
			end
		elseif not on and room.GmeatFleshed then
			unfleshRoom(room)
		end
	end

	if on then
		for _, info in ipairs(GAMEMODE.MapRoomList or {}) do
			if not info.GmeatDecorated then decorateRoom(info) end
		end
	else
		for _, info in ipairs(GAMEMODE.MapRoomList or {}) do info.GmeatDecorated = nil end
	end
end)

hook.Add("PostCleanupMap", "Gmeat_FleshMaze", function()
	for _, d in ipairs(decor) do removeDecor(d) end
	decor = {}
	for k in pairs(stats) do stats[k] = 0 end
	for _, info in ipairs(GAMEMODE.MapRoomList or {}) do info.GmeatDecorated = nil end
end)
