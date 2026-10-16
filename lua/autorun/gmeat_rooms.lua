AddCSLuaFile()
if game.GetMap() ~= "sector75" then return end

GMEAT_SET = "gmeat"

local FACING = { forward = 0, left = 90, back = 180, right = 270 }

function GmeatDoor(room, pos, ang, x, y, z, facing, forceSet)
	local offset = room:GetForward() * x - room:GetRight() * y + room:GetUp() * z
	local door = Sector75_CreateRoomDoor(room, pos, offset, ang + Angle(0, FACING[facing or "forward"], 0))
	if IsValid(door) and forceSet then
		door.ForceSet = forceSet
	end
	return door
end

local function Local(room, x, y, z)
	return room:LocalToWorld(Vector(x, y, z))
end

GmeatRoomCounts = GmeatRoomCounts or {}
hook.Add("PreCleanupMap", "Gmeat_ResetRoomCounts", function()
	GmeatRoomCounts = {}
end)
local function UnderLimit(name, limit)
	return (GmeatRoomCounts[name] or 0) < limit
end
local function Count(name)
	GmeatRoomCounts[name] = (GmeatRoomCounts[name] or 0) + 1
end

local warnedMissing = {}
local function GmeatAddRoom(props)
	if not file.Exists(props.RoomModel, "GAME") then
		props.RoomDevNoSpawn = true
		if not warnedMissing[props.RoomModel] then
			warnedMissing[props.RoomModel] = true
			print("[Gmeat] Room model missing, skipping until it exists: " .. props.RoomModel)
		end
	end
	Sector75_AddRoom(props)
end

hook.Add("Sector75_AddSets", "Gmeat_AddSets", function()
	Sector75_CustomSets["Gmeat"] = GMEAT_SET
end)

hook.Add("Sector75_AddCustomRooms", "Gmeat_AddCustomRooms", function()

	GmeatAddRoom({
		RoomWeight = 2,
		RoomDevNoSpawn = false,
		RoomDesc = "A beige office hallway with a filing cabinet that rattles when you walk past.",
		RoomName = "gmeat_cooler_hall_01a",
		RoomNameTrimmed = "gmeat_cooler_hall_01",
		RoomModel = "models/gmeat/cooler_hall_01a.mdl",
		ExtraGenRequired = false,
		IgnoreBaseIterateNav = false,
		ForceLightsOut = false,
		MinimumRoomsReq = 0,
		RoomDescriptor = "hallway_unique",
		RoomSet = GMEAT_SET,
		RoomLightCol = {255, 240, 200},

		RoomCreationPredicate = function(self, parentIndex, pos, ang)
			return true
		end,

		OnRoomCreated = function(self, roomIndex, pos, ang)
			local room = ents.GetByIndex(roomIndex)
			if not IsValid(room) then return end

			GmeatDoor(room, pos, ang, 536, 0, 0, "forward")
			GmeatDoor(room, pos, ang, 272, 104, 0, "left")

			Sector75_CreateRoomProp(pos, ang, {
				"sector75_prop_dynamic", "models/props_wasteland/controlroom_filecabinet002a.mdl",
				room:GetForward() * 260 + room:GetRight() * 60, Angle(0, 180, 0)
			})

			room.GmeatDropSpots = { Local(room, 400, 0, 8) }
			room.GmeatVoiceTrigger = Local(room, 64, 0, 40)
		end
	})

end)

GmeatTrapRooms = {
	sets = { sector75_underhalls = true },
	descriptors = { deadend = true },
	namePatterns = { "^fakedeadend", "^underhallsentrance" },
}
function GmeatIsTrapRoom(roomname, properties)
	if GmeatTrapRooms.sets[properties.RoomSet or ""] or GmeatTrapRooms.descriptors[properties.RoomDescriptor or ""] then return true end
	for _, pattern in ipairs(GmeatTrapRooms.namePatterns) do
		if string.find(roomname or "", pattern) then return true end
	end
	return false
end

hook.Add("Sector75_ModifyRoomWeight", "Gmeat_ModifyRoomWeight", function(weight, sets, roomname, properties)
	if engine.ActiveGamemode() ~= "gmeat" then return end
	if GmeatIsTrapRoom(roomname, properties) then return 0 end
	if properties.RoomSet == GMEAT_SET then
		return weight * 2
	end
end)
