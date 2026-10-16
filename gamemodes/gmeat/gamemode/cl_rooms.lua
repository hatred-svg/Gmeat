GM.MapRooms = GM.MapRooms or {}
GM.MapRoomList = GM.MapRoomList or {}
GM.MapDoors = GM.MapDoors or {}
GM.Visited = GM.Visited or {}
GM.Markers = GM.Markers or {}

local function toWorld2D(room, lx, ly)
	return room.pos.x + lx * room.cos - ly * room.sin, room.pos.y + lx * room.sin + ly * room.cos
end

local function buildStrips(room)
	room.strips = {}
	local nx, cell = room.nx, room.cell
	for iy = 1, room.ny do
		local ix = 1
		while ix <= nx do
			if room.cells[(iy - 1) * nx + ix] then
				local first = ix
				while ix < nx and room.cells[(iy - 1) * nx + ix + 1] do ix = ix + 1 end
				local x0, x1 = room.mins.x + (first - 1) * cell, room.mins.x + ix * cell
				local y0, y1 = room.mins.y + (iy - 1) * cell, room.mins.y + iy * cell
				local ax, ay = toWorld2D(room, x0, y0)
				local bx, by = toWorld2D(room, x1, y0)
				local cx, cy = toWorld2D(room, x1, y1)
				local dx, dy = toWorld2D(room, x0, y1)
				room.strips[#room.strips + 1] = { ax, ay, bx, by, cx, cy, dx, dy }
			end
			ix = ix + 1
		end
	end
	if #room.strips == 0 then
		local ax, ay = toWorld2D(room, room.mins.x, room.mins.y)
		local bx, by = toWorld2D(room, room.maxs.x, room.mins.y)
		local cx, cy = toWorld2D(room, room.maxs.x, room.maxs.y)
		local dx, dy = toWorld2D(room, room.mins.x, room.maxs.y)
		room.strips[1] = { ax, ay, bx, by, cx, cy, dx, dy }
	end
end

net.Receive("Gmeat_RoomsReset", function()
	GAMEMODE.MapRooms = {}
	GAMEMODE.MapRoomList = {}
	GAMEMODE.MapDoors = {}
	GAMEMODE.Visited = {}
	GAMEMODE.CurrentRoom = nil
	GAMEMODE.Markers = {}
end)

net.Receive("Gmeat_Room", function()
	local room = {}
	room.id = net.ReadUInt(16)
	room.order = net.ReadUInt(16)
	room.depth = net.ReadUInt(8)
	room.isStart = net.ReadBool()
	room.pos = net.ReadVector()
	room.yaw = net.ReadFloat()
	room.mins = net.ReadVector()
	room.maxs = net.ReadVector()
	room.cell = net.ReadUInt(8)
	room.nx = net.ReadUInt(8)
	room.ny = net.ReadUInt(8)
	room.cells = {}
	for i = 1, room.nx * room.ny do
		room.cells[i] = net.ReadBool()
	end
	room.doors = {}
	for i = 1, net.ReadUInt(8) do
		local door = { id = net.ReadUInt(16), pos = net.ReadVector(), state = net.ReadUInt(2) }
		room.doors[i] = door
		GAMEMODE.MapDoors[door.id] = door
	end
	room.name = net.ReadString()
	room.anchors = {}
	for i = 1, net.ReadUInt(4) do
		room.anchors[i] = { ceil = net.ReadVector(), floorZ = net.ReadFloat() }
	end

	local rad = math.rad(room.yaw)
	room.cos, room.sin = math.cos(rad), math.sin(rad)
	room.zmin = room.pos.z + room.mins.z
	room.zmax = room.pos.z + room.maxs.z
	local cx, cy = toWorld2D(room, (room.mins.x + room.maxs.x) / 2, (room.mins.y + room.maxs.y) / 2)
	room.center = Vector(cx, cy, room.pos.z)
	room.extent = math.max(room.maxs.x - room.mins.x, room.maxs.y - room.mins.y)
	room.born = CurTime()
	buildStrips(room)

	local old = GAMEMODE.MapRooms[room.id]
	if old then table.RemoveByValue(GAMEMODE.MapRoomList, old) end
	GAMEMODE.MapRooms[room.id] = room
	table.insert(GAMEMODE.MapRoomList, room)
end)

net.Receive("Gmeat_DoorState", function()
	local id, state = net.ReadUInt(16), net.ReadUInt(2)
	local door = GAMEMODE.MapDoors[id]
	if door then door.state = state end
end)

net.Receive("Gmeat_Markers", function()
	local list = {}
	for i = 1, net.ReadUInt(8) do
		local m = {}
		m.type = net.ReadUInt(3)
		m.pos = net.ReadVector()
		m.ent = net.ReadUInt(16)
		m.color = Color(net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8))
		m.label = net.ReadString()
		m.radius = net.ReadUInt(12)
		m.hud = net.ReadBool()
		local viewer = net.ReadUInt(16)
		if viewer == 0 or viewer == LocalPlayer():EntIndex() then
			list[#list + 1] = m
		end
	end
	GAMEMODE.Markers = list
end)

function GM:MarkerPos(m)
	if m.ent > 0 then
		local ent = Entity(m.ent)
		if IsValid(ent) and not ent:IsDormant() then
			if ent:IsPlayer() then return ent:GetPos() + Vector(0, 0, 80) end
			return ent:WorldSpaceCenter() + Vector(0, 0, 24)
		end
	end
	return m.pos
end

local function roomContains(room, pos)
	if pos.z < room.zmin - 16 or pos.z > room.zmax + 16 then return false end
	local dx, dy = pos.x - room.pos.x, pos.y - room.pos.y
	local lx = dx * room.cos + dy * room.sin
	local ly = -dx * room.sin + dy * room.cos
	if lx < room.mins.x or lx > room.maxs.x or ly < room.mins.y or ly > room.maxs.y then return false end
	local ix = math.floor((lx - room.mins.x) / room.cell) + 1
	local iy = math.floor((ly - room.mins.y) / room.cell) + 1
	return room.cells[(iy - 1) * room.nx + ix] == true, true
end

hook.Add("Think", "Gmeat_TrackCurrentRoom", function()
	if (GAMEMODE.NextRoomCheck or 0) > CurTime() then return end
	GAMEMODE.NextRoomCheck = CurTime() + 0.2
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end
	local pos = ply:GetPos() + Vector(0, 0, 4)
	local found, fallback
	for _, room in ipairs(GAMEMODE.MapRoomList) do
		local inCell, inBox = roomContains(room, pos)
		if inCell then found = room break end
		if inBox and not fallback then fallback = room end
	end
	found = found or fallback
	GAMEMODE.CurrentRoom = found
	if found then GAMEMODE.Visited[found.id] = true end
end)
