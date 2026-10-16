local PREBUILD_PER_PLAYER = 2
local PREBUILD_MIN = 6
local PREBUILD_MAX = 14
local PREBUILD_INTERVAL = 0.25
local PREBUILD_DELAY = 0.5
local PREBUILD_DEADLINE = 1.0

function GM:ResetPrebuild()
	self.Prebuild = {
		target = math.Clamp(player.GetCount() * PREBUILD_PER_PLAYER + 1, PREBUILD_MIN, PREBUILD_MAX),
		nextOpen = CurTime() + PREBUILD_DELAY,
		attempts = 0,
		placed = false,
	}
end

function GM:PickPrebuildDoor()
	local origin = self.StartRoom.center
	local candidates = {}
	for _, info in ipairs(self.RoomList) do
		for _, d in ipairs(info.doors) do
			local door = d.ent
			if IsValid(door) and not door.GeneratedSector75 and not door.AttemptedSector75Gen
				and not door.FailedSector75GenTime and not door.Sector75Sealed and not door.Sector75DoorNoGen then
				candidates[#candidates + 1] = { door = door, dist = door:GetPos():Distance(origin) }
			end
		end
	end
	if #candidates == 0 then return end
	table.sort(candidates, function(a, b) return a.dist > b.dist end)
	return candidates[math.random(math.min(3, #candidates))].door
end

function GM:PrebuildThink()
	local pb = self.Prebuild
	if not pb or pb.placed then return end
	local now = CurTime()
	local prepEnd = GetGlobalFloat("GmeatStateEnd", now)

	local finished = #self.RoomList >= pb.target or now >= prepEnd - PREBUILD_DEADLINE or pb.attempts > pb.target * 3
	if finished then
		if self.StartRoom then
			self:PlaceInSeparateRooms()
			pb.placed = true
		end
		return
	end

	if now < pb.nextOpen or not self.StartRoom then return end
	pb.nextOpen = now + PREBUILD_INTERVAL
	pb.attempts = pb.attempts + 1
	local door = self:PickPrebuildDoor()
	if IsValid(door) then door:Fire("Open") end
end

local function shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

function GM:PlaceInSeparateRooms()
	local rooms = {}
	for _, info in ipairs(self.RoomList) do
		if not info.isStart and IsValid(info.ent) and #info.spots > 0 then rooms[#rooms + 1] = info end
	end
	local players = {}
	for _, ply in ipairs(player.GetAll()) do
		if ply:Alive() then players[#players + 1] = ply end
	end
	if #rooms == 0 or #players == 0 then return end

	local origin = self.StartRoom and self.StartRoom.center or rooms[1].center
	local chosen, used = {}, {}
	while #chosen < math.min(#players, #rooms) do
		local best, bestScore
		for _, info in ipairs(rooms) do
			if not used[info] then
				local score = math.huge
				if #chosen == 0 then
					score = info.center:Distance(origin)
				else
					for _, c in ipairs(chosen) do score = math.min(score, info.center:Distance(c.center)) end
				end
				if not bestScore or score > bestScore then best, bestScore = info, score end
			end
		end
		used[best] = true
		chosen[#chosen + 1] = best
	end

	local freeze = self:GetRoundState() == GMEAT_PREP
	local takenSpots = {}
	for i, ply in ipairs(shuffle(players)) do
		local info = chosen[(i - 1) % #chosen + 1]
		info.spawnRoom = true
		local spots = shuffle(table.Copy(info.spots))
		local spot = spots[1]
		for _, p in ipairs(spots) do
			if not takenSpots[p] then spot = p break end
		end
		takenSpots[spot] = true
		ply:SetPos(spot + Vector(0, 0, 2))
		ply:SetEyeAngles(Angle(0, info.ang.y, 0))
		ply:SetVelocity(-ply:GetVelocity())
		ply:Freeze(freeze)
	end
end

function GM:PickNeutralRoom()
	local players = {}
	for _, ply in ipairs(player.GetAll()) do
		if ply:Alive() then players[#players + 1] = ply:GetPos() end
	end
	if #players == 0 then return end
	return self:PickRoom(function(info)
		if info.isStart or info.spawnRoom then return nil end
		local nearest, farthest = math.huge, 0
		for _, p in ipairs(players) do
			local d = p:Distance(info.center)
			nearest = math.min(nearest, d)
			farthest = math.max(farthest, d)
		end
		return 0.5 * nearest - (farthest - nearest)
	end)
end
