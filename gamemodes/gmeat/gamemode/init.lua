AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("sh_config.lua")
AddCSLuaFile("sh_announcer.lua")
AddCSLuaFile("sh_quests.lua")
AddCSLuaFile("cl_rooms.lua")
AddCSLuaFile("cl_minimap.lua")
AddCSLuaFile("cl_sound.lua")
AddCSLuaFile("cl_hud.lua")
AddCSLuaFile("cl_hud_player.lua")
AddCSLuaFile("cl_effects.lua")
AddCSLuaFile("cl_gore.lua")
AddCSLuaFile("cl_slasher.lua")
AddCSLuaFile("cl_fleshmaze.lua")
AddCSLuaFile("cl_camera.lua")
AddCSLuaFile("cl_flinch.lua")
AddCSLuaFile("cl_legs.lua")

include("shared.lua")

util.AddNetworkString("Gmeat_Announce")
util.AddNetworkString("Gmeat_Notify")
util.AddNetworkString("Gmeat_ClearDecals")
util.AddNetworkString("Gmeat_KillFX")
util.AddNetworkString("Gmeat_Narrate")

for _, name in ipairs({ "grain", "vignette", "killmaze", "kill_maze2", "kill_manmaze" }) do
	resource.AddFile("materials/gmeat/fx/" .. name .. ".vmt")
	resource.AddFile("materials/gmeat/fx/" .. name .. ".vtf")
end

include("sv_rooms.lua")
include("sv_interact.lua")
include("sv_carry.lua")
include("sv_player.lua")
include("sv_drops.lua")
include("sv_gore.lua")
include("sv_writhe.lua")
include("sv_crawl.lua")
include("sv_vomit.lua")
include("sv_markers.lua")
include("sv_prebuild.lua")
include("sv_round.lua")
include("sv_commands.lua")

function GM:Initialize()
	self.RoundState = GMEAT_WAITING
	SetGlobalInt("GmeatState", GMEAT_WAITING)
	util.PrecacheModel(GMEAT.FleshMaze.TentacleModel)
	for _, mdl in ipairs(GMEAT.FleshMaze.BoneModels) do util.PrecacheModel(mdl) end
	self:MigrateDefaults()
end

local DEFAULT_CHANGES = {
	{ marker = "gmeat/defaults_v2.txt", note = "assembly cells 6, kill confirmed goal 9",
		{ "gmeat_assembly_cells", "3", "6" },
		{ "gmeat_killconfirmed_goal", "12", "9" } },
	{ marker = "gmeat/defaults_v3.txt", note = "blood vomit chance 0.4",
		{ "gmeat_bloodvomit_chance", "0.5", "0.4" } },
}
function GM:MigrateDefaults()
	for _, batch in ipairs(DEFAULT_CHANGES) do
		if not file.Exists(batch.marker, "DATA") then
			for _, c in ipairs(batch) do
				local cv = GetConVar(c[1])
				if cv and cv:GetString() == c[2] then RunConsoleCommand(c[1], c[3]) end
			end
			file.CreateDir("gmeat")
			file.Write(batch.marker, "Gmeat moved settings still on old defaults to the new ones (" .. batch.note .. ").\n")
		end
	end
end

function GM:InitPostEntity()
	self:ApplySector75Settings()
	for _, room in ipairs(ents.FindByClass("sector75_room_entity")) do
		self:RegisterRoom(room)
	end
end

function GM:Think()
	self:RoundThink()
	self:InteractThink()
	self:DoorThink()
	self:MarkerThink()
	self:ProtectionThink()
	self:RagdollThink()
end

function GM:Announce(key, ...)
	local fmt = GMEAT.Lines[key] or key
	local text = fmt
	if select("#", ...) > 0 then
		local ok, result = pcall(string.format, fmt, ...)
		text = ok and result or fmt
	end
	net.Start("Gmeat_Announce")
	net.WriteString(key)
	net.WriteString(text)
	net.Broadcast()
end

function GM:Narrate(ply, path)
	if not path or path == "" then return end
	net.Start("Gmeat_Narrate")
	net.WriteString(path)
	net.Send(ply)
end

function GM:Notify(ply, text)
	net.Start("Gmeat_Notify")
	net.WriteString(text)
	net.Send(ply)
end

local function setConVar(name, value)
	local cv = GetConVar(name)
	if cv and cv:GetString() ~= tostring(value) then
		cv:SetString(tostring(value))
	end
end

function GM:ApplySector75Settings()
	if not GetConVar("sector75_room_set") then
		MsgC(Color(255, 80, 80), "[Gmeat] Sector 75 is not loaded. Subscribe to the map and load 'sector75'.\n")
		return
	end
	setConVar("sector75_nextbotless_mode", 1)
	setConVar("sector75_dungeon_crawler_enabled", 0)
	setConVar("sector75_autogenerate_mode", 0)
	setConVar("sector75_autogenerate_global", 0)
	setConVar("sector75_darkness_mode", 0)
	setConVar("sector75_exploration_mode", GetConVar("gmeat_s75_exploration"):GetInt())
	setConVar("sector75_room_set", GetConVar("gmeat_room_sets"):GetString())
end
