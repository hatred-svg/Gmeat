util.AddNetworkString("Gmeat_Room")
util.AddNetworkString("Gmeat_RoomsReset")
util.AddNetworkString("Gmeat_DoorState")
util.AddNetworkString("Gmeat_ClientReady")

local CELL = 64
local Dist2DSqr = GMEAT.Dist2DSqr

GM.Rooms = GM.Rooms or {}
GM.RoomList = GM.RoomList or {}
GM.Occupied = GM.Occupied or {}

local function onlyRooms(ent)
	return ent:GetClass() == "sector75_room_entity"
end

local function notPlayers(ent)
	return not ent:IsPlayer()
end

function GM:ResetRooms()
	self.Rooms = {}
	self.RoomList = {}
	self.Occupied = {}
	self.StartRoom = nil
	net.Start("Gmeat_RoomsReset")
	net.Broadcast()
end

hook.Add("PreCleanupMap", "Gmeat_ResetRooms", function()
	if GAMEMODE and GAMEMODE.ResetRooms then GAMEMODE:ResetRooms() end
end)

hook.Add("OnEntityCreated", "Gmeat_TrackRooms", function(ent)
	if ent:GetClass() ~= "sector75_room_entity" then return end
	timer.Simple(0.15, function()
		if IsValid(ent) and GAMEMODE and GAMEMODE.RegisterRoom then
			GAMEMODE:RegisterRoom(ent)
		end
	end)
end)

function GM:SampleRoom(info)
	local room = info.ent
	local mins, maxs = info.mins, info.maxs
	local nx = math.Clamp(math.ceil((maxs.x - mins.x) / CELL), 1, 64)
	local ny = math.Clamp(math.ceil((maxs.y - mins.y) / CELL), 1, 64)
	info.cell, info.nx, info.ny = CELL, nx, ny
	info.cells, info.spots, info.ceilings = {}, {}, {}

	local function onlyThisRoom(ent) return ent == room end

	local function trace(from, to)
		return util.TraceLine({ start = from, endpos = to, filter = onlyThisRoom, mask = MASK_SOLID })
	end
	local function floorAt(lx, ly, zTop, zBottom)
		local tr = trace(room:LocalToWorld(Vector(lx, ly, zTop)), room:LocalToWorld(Vector(lx, ly, zBottom)))
		if not (tr.Hit and not tr.StartSolid and tr.Entity == room and tr.HitNormal.z > 0.6) then return end
		local up = trace(tr.HitPos + Vector(0, 0, 8), tr.HitPos + Vector(0, 0, 2000))
		if up.Hit and up.Entity == room then return tr.HitPos, up end
	end
	local OFFSETS = { { 0, 0 }, { 20, 0 }, { -20, 0 }, { 0, 20 }, { 0, -20 } }
	local SLICE = 110
	local function probe(lx, ly)
		local floor, up = floorAt(lx, ly, 56, -40)
		if floor then return floor, up end
		for _, o in ipairs(OFFSETS) do
			local z = maxs.z - 2
			while z > mins.z do
				local z2 = math.max(z - SLICE, mins.z - 8)
				floor, up = floorAt(lx + o[1], ly + o[2], z, z2)
				if floor then return floor, up end
				z = z2
			end
		end
	end

	for iy = 1, ny do
		for ix = 1, nx do
			local lx = mins.x + (ix - 0.5) * CELL
			local ly = mins.y + (iy - 0.5) * CELL
			local floor, up = probe(lx, ly)
			local filled = floor ~= nil
			if filled and up.HitNormal.z < -0.6 then
				info.ceilings[#info.ceilings + 1] = { floor = floor, ceil = up.HitPos }
			end
			info.cells[(iy - 1) * nx + ix] = filled or false
			if filled then
				local head = util.TraceHull({
					start = floor + Vector(0, 0, 4),
					endpos = floor + Vector(0, 0, 72),
					mins = Vector(-16, -16, 0),
					maxs = Vector(16, 16, 4),
					mask = MASK_PLAYERSOLID,
					filter = notPlayers,
				})
				if not head.Hit and not head.StartSolid then
					info.spots[#info.spots + 1] = floor
				end
			end
		end
	end
end

function GM:PickTentacleAnchors(info)
	local cfg = GMEAT.FleshMaze
	local anchors = {}
	if not cfg or #info.ceilings == 0 then return anchors end
	local seed = (info.id * 7919 + 104729) % 2147483647
	local function rand()
		seed = (seed * 48271) % 2147483647
		return seed / 2147483647
	end
	local list = {}
	for i, c in ipairs(info.ceilings) do list[i] = c end
	for i = #list, 2, -1 do
		local j = math.floor(rand() * i) + 1
		list[i], list[j] = list[j], list[i]
	end
	local filled = 0
	for _, v in pairs(info.cells) do if v then filled = filled + 1 end end
	local wanted = math.Clamp(math.Round(filled / cfg.CellsPerTentacle), cfg.TentaclesPerRoom[1], cfg.TentaclesPerRoom[2])
	for _, c in ipairs(list) do
		if #anchors >= wanted then break end
		local height = c.ceil.z - c.floor.z
		local clear = height >= cfg.MinCeiling
		for _, door in ipairs(info.doors) do
			if clear and door.pos:Distance(c.floor) < cfg.DoorClearance then clear = false end
		end
		for _, a in ipairs(anchors) do
			if clear and a.ceil:Distance(c.ceil) < 70 then clear = false end
		end
		if clear then anchors[#anchors + 1] = c end
	end
	return anchors
end

function GM:RegisterRoom(room)
	if not IsValid(room) or self.Rooms[room] then return end

	local props = room.Sector75Properties or {}
	local info = {
		ent = room,
		id = room:EntIndex(),
		pos = room:GetPos(),
		ang = room:GetAngles(),
		mins = room:OBBMins(),
		maxs = room:OBBMaxs(),
		name = props.RoomName or room:GetModel() or "",
		descriptor = props.RoomDescriptor,
		set = props.RoomSet,
		center = room:WorldSpaceCenter(),
		doors = {},
	}

	local parent, bestDist = nil, 64 * 64
	local doors = ents.FindByClass("prop_door_rotating")
	for _, door in ipairs(doors) do
		local owner = door:GetNWEntity("Sector75_ConnectedRoom")
		if IsValid(owner) then
			if owner == room then
				if door.ForceSet and GmeatTrapRooms and GmeatTrapRooms.sets[door.ForceSet] and not door.GeneratedSector75 then
					door.Sector75Sealed = true
					door:Fire("Close")
				end
				info.doors[#info.doors + 1] = { ent = door, id = door:EntIndex(), pos = door:WorldSpaceCenter(), state = 0 }
			elseif door.GeneratedSector75 and self.Rooms[owner] then
				local c = door:WorldSpaceCenter()
				local d = Dist2DSqr(c, info.pos)
				if d < bestDist and math.abs(c.z - info.pos.z) < 100 then
					parent, bestDist = self.Rooms[owner], d
				end
			end
		end
	end

	info.parent = parent
	info.depth = parent and (parent.depth + 1) or 0
	info.isStart = props.RoomDescriptor == "start" or (not parent and #self.RoomList == 0)
	info.order = #self.RoomList + 1

	self:SampleRoom(info)
	info.anchors = self:PickTentacleAnchors(info)

	self.Rooms[room] = info
	self.RoomList[#self.RoomList + 1] = info
	if info.isStart then self.StartRoom = info end

	self:SendRoom(info)
	self:QuestCall("OnRoomRegistered", info)
end

function GM:SendRoom(info, target)
	net.Start("Gmeat_Room")
	net.WriteUInt(info.id, 16)
	net.WriteUInt(info.order, 16)
	net.WriteUInt(math.min(info.depth, 255), 8)
	net.WriteBool(info.isStart)
	net.WriteVector(info.pos)
	net.WriteFloat(info.ang.y)
	net.WriteVector(info.mins)
	net.WriteVector(info.maxs)
	net.WriteUInt(info.cell, 8)
	net.WriteUInt(info.nx, 8)
	net.WriteUInt(info.ny, 8)
	for i = 1, info.nx * info.ny do
		net.WriteBool(info.cells[i] == true)
	end
	net.WriteUInt(#info.doors, 8)
	for _, d in ipairs(info.doors) do
		net.WriteUInt(d.id, 16)
		net.WriteVector(d.pos)
		net.WriteUInt(d.state, 2)
	end
	net.WriteString(info.name)
	local anchors = info.anchors or {}
	net.WriteUInt(math.min(#anchors, 15), 4)
	for i = 1, math.min(#anchors, 15) do
		net.WriteVector(anchors[i].ceil)
		net.WriteFloat(anchors[i].floor.z)
	end
	if target then net.Send(target) else net.Broadcast() end
end

net.Receive("Gmeat_ClientReady", function(_, ply)
	if ply.GmeatSynced then return end
	ply.GmeatSynced = true
	net.Start("Gmeat_RoomsReset")
	net.Send(ply)
	local list = table.Copy(GAMEMODE.RoomList)
	local i = 0
	timer.Create("Gmeat_Sync_" .. ply:EntIndex(), 0.05, math.ceil(#list / 8) + 1, function()
		if not IsValid(ply) then return end
		for _ = 1, 8 do
			i = i + 1
			if list[i] and IsValid(list[i].ent) then GAMEMODE:SendRoom(list[i], ply) end
		end
	end)
end)

function GM:DoorThink()
	if (self.NextDoorPoll or 0) > CurTime() then return end
	self.NextDoorPoll = CurTime() + 0.5
	for _, info in ipairs(self.RoomList) do
		for _, d in ipairs(info.doors) do
			if d.state == 0 then
				local door, state = d.ent, 0
				if not IsValid(door) then
					state = 2
				elseif door.GeneratedSector75 then
					state = 1
				elseif door.FailedSector75GenTime or door.Sector75Sealed then
					state = 2
				end
				if state ~= 0 then
					d.state = state
					net.Start("Gmeat_DoorState")
					net.WriteUInt(d.id, 16)
					net.WriteUInt(state, 2)
					net.Broadcast()
				end
			end
		end
	end
end

function GM:HasClearance(pos, radius)
	local tr = util.TraceHull({
		start = pos + Vector(0, 0, 4),
		endpos = pos + Vector(0, 0, 64),
		mins = Vector(-radius, -radius, 0),
		maxs = Vector(radius, radius, 4),
		mask = MASK_PLAYERSOLID,
		filter = notPlayers,
	})
	return not tr.Hit and not tr.StartSolid
end

function GM:PickSpot(info, clearance, spacing)
	if not info or not IsValid(info.ent) then return end
	clearance = clearance or 16
	spacing = spacing or 96
	local candidates = {}
	for _, p in ipairs(info.spots) do
		local ok = Dist2DSqr(p, info.pos) > 90 * 90
		if ok then
			for _, d in ipairs(info.doors) do
				if Dist2DSqr(p, d.pos) < 90 * 90 then ok = false break end
			end
		end
		if ok then
			for _, o in ipairs(self.Occupied) do
				if p:DistToSqr(o) < spacing * spacing then ok = false break end
			end
		end
		if ok then candidates[#candidates + 1] = p end
	end
	while #candidates > 0 do
		local i = math.random(#candidates)
		local p = candidates[i]
		table.remove(candidates, i)
		if clearance <= 16 or self:HasClearance(p, clearance) then
			return p
		end
	end
end

function GM:ReserveSpot(pos)
	self.Occupied[#self.Occupied + 1] = pos
end

function GM:PlaceOnFloor(ent, pos)
	ent:SetPos(pos + Vector(0, 0, -ent:OBBMins().z + 1))
end

function GM:SpawnInRoom(class, info, clearance, setup)
	local pos = self:PickSpot(info, clearance)
	if not pos then return end
	local ent = ents.Create(class)
	if not IsValid(ent) then return end
	ent:SetPos(pos)
	ent:SetAngles(Angle(0, math.random(0, 359), 0))
	if setup then setup(ent) end
	ent:Spawn()
	ent:Activate()
	self:PlaceOnFloor(ent, pos)
	self:ReserveSpot(pos)
	ent.GmeatRoom = info
	return ent, pos
end

function GM:FindFloorBelow(pos)
	local tr = util.TraceLine({
		start = pos + Vector(0, 0, 24),
		endpos = pos - Vector(0, 0, 400),
		filter = onlyRooms,
		mask = MASK_SOLID,
	})
	if tr.Hit and not tr.StartSolid and IsValid(tr.Entity) and tr.HitNormal.z > 0.6 then
		return tr.HitPos
	end
end

function GM:PickRoom(score)
	local best, bestScore
	for _, info in ipairs(self.RoomList) do
		if IsValid(info.ent) and #info.spots > 0 then
			local s = score(info)
			if s and (not bestScore or s > bestScore) then
				best, bestScore = info, s
			end
		end
	end
	return best
end

function GM:GetStartSpot()
	local info = self.StartRoom
	if not info or not IsValid(info.ent) or #info.spots == 0 then return end
	local best, bestScore
	for _ = 1, 12 do
		local p = info.spots[math.random(#info.spots)]
		local nearest = math.huge
		for _, other in ipairs(player.GetAll()) do
			if other:Alive() then
				nearest = math.min(nearest, other:GetPos():DistToSqr(p))
			end
		end
		if not best or nearest > bestScore then
			best, bestScore = p, nearest
		end
	end
	return best, info.ang.y
end

local RESPAWN_MIN_ENEMY_DIST = 700
local KILLER_WEIGHT = 0.6
local ZONE_AVOID_DIST = 400

function GM:GetRespawnSpot(ply, killer)
	local enemies = {}
	for _, other in ipairs(player.GetAll()) do
		if other ~= ply and other:Alive() then enemies[#enemies + 1] = other end
	end
	local zones = ents.FindByClass("gmeat_zone")

	local scored = {}
	for _, info in ipairs(self.RoomList) do
		if not info.isStart and IsValid(info.ent) and #info.spots > 0 then
			local nearZone = false
			for _, zone in ipairs(zones) do
				if zone:GetPos():Distance(info.center) < ZONE_AVOID_DIST then nearZone = true break end
			end
			if not nearZone then
				local nearest = math.huge
				for _, enemy in ipairs(enemies) do
					local d = enemy:GetPos():Distance(info.center)
					if enemy == killer then d = d * KILLER_WEIGHT end
					nearest = math.min(nearest, d)
				end
				scored[#scored + 1] = { info = info, score = nearest }
			end
		end
	end
	if #scored == 0 then return end

	table.sort(scored, function(a, b) return a.score > b.score end)
	local pool = {}
	for i = 1, math.min(3, #scored) do
		if i == 1 or scored[i].score >= RESPAWN_MIN_ENEMY_DIST then pool[#pool + 1] = scored[i].info end
	end
	local info = pool[math.random(#pool)]

	local spots = table.Copy(info.spots)
	for _ = 1, math.min(#spots, 15) do
		local i = math.random(#spots)
		local p = spots[i]
		table.remove(spots, i)
		local seen = false
		for _, enemy in ipairs(enemies) do
			local tr = util.TraceLine({
				start = enemy:EyePos(),
				endpos = p + Vector(0, 0, 60),
				filter = onlyRooms,
				mask = MASK_SOLID,
			})
			if not tr.Hit then seen = true break end
		end
		if not seen then return p, info.ang.y end
	end
	return info.spots[math.random(#info.spots)], info.ang.y
end
