GM.Name = "Gmeat"
GM.Author = "Gmeat team"
GM.Email = ""
GM.Website = ""
GM.TeamBased = false

DeriveGamemode("base")

GMEAT = GMEAT or {}

GMEAT_WAITING = 0
GMEAT_PREP = 1
GMEAT_ACTIVE = 2
GMEAT_POST = 3

GMEAT_MARKER_OBJECTIVE = 1
GMEAT_MARKER_AREA = 2
GMEAT_MARKER_PROXIMITY = 3

local SHARED = { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY }

CreateConVar("gmeat_min_players", "2", SHARED, "Players needed before a round starts. Set to 1 to test alone.", 1, 32)
CreateConVar("gmeat_round_time", "240", SHARED, "Round length in seconds.", 30, 3600)
CreateConVar("gmeat_prep_time", "6", SHARED, "Countdown before a round starts.", 0, 60)
CreateConVar("gmeat_post_time", "8", SHARED, "Time the winner screen is shown.", 1, 60)
CreateConVar("gmeat_respawn_time", "3", SHARED, "Seconds before a dead player respawns.", 0, 60)
CreateConVar("gmeat_spawn_protect", "3", SHARED, "Seconds of spawn protection (ends early if you shoot).", 0, 30)
CreateConVar("gmeat_quest", "random", SHARED, "Quest to play: random, assembly, delivery, bomb or killconfirmed.")
CreateConVar("gmeat_killconfirmed_goal", "9", SHARED, "Confirmed kills needed to win Kill Confirmed.", 1, 100)
CreateConVar("gmeat_drop_first", "10", SHARED, "Seconds into a round before the first supply drop.", 0, 600)
CreateConVar("gmeat_drop_interval", "25", SHARED, "Seconds between supply drops.", 5, 600)
CreateConVar("gmeat_drop_max", "2", SHARED, "Maximum unopened supply drops at once.", 1, 10)
CreateConVar("gmeat_weapon_blacklist", "", SHARED, "Comma separated weapon classes that never appear in supply drops.")
CreateConVar("gmeat_weapon_whitelist", "", SHARED, "If set, ONLY these comma separated weapon classes appear in supply drops.")
CreateConVar("gmeat_hl2_weapons", "1", SHARED, "Include the Half-Life 2 weapons in supply drops.", 0, 1)
CreateConVar("gmeat_assembly_cells", "6", SHARED, "Power cells each player must install in the Assembly quest.", 1, 10)
CreateConVar("gmeat_bomb_fuse", "30", SHARED, "Seconds between planting the bomb and detonation.", 5, 120)
CreateConVar("gmeat_room_sets", "sector75,gmeat", SHARED, "Value Gmeat writes to sector75_room_set each round.")
CreateConVar("gmeat_s75_exploration", "1", SHARED, "Turn on Sector 75 exploration mode (no dead ends, fewer generic hallways).", 0, 1)
CreateConVar("gmeat_gore", "1", SHARED, "Limbs blow off and bodies gib on death (0 = corpses only).", 0, 1)
CreateConVar("gmeat_bloodvomit_chance", "0.4", SHARED, "Chance a corpse coughs and vomits blood (0 = never, 1 = every death).", 0, 1)
CreateConVar("gmeat_admin_noclip", "0", SHARED, "Allow admins to noclip (for testing).", 0, 1)

include("sh_config.lua")
include("sh_announcer.lua")
include("sh_quests.lua")

function GM:GetRoundState()
	return GetGlobalInt("GmeatState", GMEAT_WAITING)
end

function GM:GetActiveQuestTable()
	return self.Quests[GetGlobalString("GmeatQuest", "")]
end

function GMEAT.SplitList(str)
	local out = {}
	for _, part in ipairs(string.Explode(",", str or "")) do
		part = string.Trim(part)
		if part ~= "" then out[#out + 1] = part end
	end
	return out
end

function GMEAT.Dist2DSqr(a, b)
	local dx, dy = a.x - b.x, a.y - b.y
	return dx * dx + dy * dy
end

hook.Add("SetupMove", "Gmeat_Movement", function(ply, mv)
	if not ply:Alive() or ply:GetMoveType() ~= MOVETYPE_WALK then return end

	local speed = ply:GetWalkSpeed()
	local moving = mv:GetForwardSpeed() ~= 0 or mv:GetSideSpeed() ~= 0
	if mv:KeyDown(IN_SPEED) and moving and not ply:Crouching() and not mv:KeyDown(IN_WALK) then
		speed = ply:GetRunSpeed()
	elseif mv:KeyDown(IN_WALK) then
		speed = ply:GetSlowWalkSpeed()
	end

	local kind = ply:GetNWString("GmeatCarrying", "")
	if kind ~= "" then
		speed = speed * (GMEAT.CarrySpeedMul[kind] or 1)
	end

	if ply:Crouching() then
		if kind ~= "" then
			mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * (GMEAT.CarrySpeedMul[kind] or 1))
		end
		return
	end
	mv:SetMaxClientSpeed(speed)
	mv:SetMaxSpeed(speed)
end)

if game.GetMap() ~= "sector75" then
	MsgC(Color(255, 80, 80), "[Gmeat] This gamemode is built for the map 'sector75'. Rooms will not generate on '" .. game.GetMap() .. "'.\n")
end
