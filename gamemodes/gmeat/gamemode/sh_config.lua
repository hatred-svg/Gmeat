GMEAT.WeaponBlacklist = {
	weapon_physgun = true,
	weapon_physcannon = true,
	gmod_tool = true,
	gmod_camera = true,
	weapon_medkit = true,
	manhack_welder = true,
	weapon_flechettegun = true,
	weapon_bugbait = true,
	weapon_fists = true,
}

GMEAT.HL2Weapons = {
	weapon_crowbar = 1,
	weapon_stunstick = 1,
	weapon_pistol = 1,
	weapon_smg1 = 2,
	weapon_frag = 2,
	weapon_357 = 3,
	weapon_shotgun = 3,
	weapon_slam = 3,
	weapon_ar2 = 4,
	weapon_crossbow = 4,
	weapon_rpg = 5,
}

GMEAT.WeaponTierOverrides = {
}

GMEAT.Movement = {
	walk = 190,
	run = 320,
	slowwalk = 100,
	jump = 200,
	crouch = 0.4,
}

GMEAT.CarrySpeedMul = {
	package = 0.85,
	bomb = 0.92,
}

GMEAT.CarryModels = {
	package = "models/props_c17/briefcase001a.mdl",
	bomb = "models/weapons/w_slam.mdl",
}

GMEAT.CarryColors = {
	package = Color(255, 150, 60),
	bomb = Color(255, 60, 60),
}

GMEAT.HUD = {
	Red = Color(205, 32, 26),
	RedBright = Color(255, 72, 56),
	Panel = Color(20, 7, 7, 205),
	Text = Color(246, 234, 222),
	TextDim = Color(214, 182, 166),
	Plate = "gmeat/hud/plate",
	PlateAspect = 300 / 87,
	PlateCap = 0.17,
	BarFrame = "gmeat/hud/bar_frame",
	BarFill = "gmeat/hud/bar_fill",
	BarSource = { w = 300, h = 40, cap = 15, fillLeft = 7, fillRight = 7, fillTop = 8, fillBottom = 8 },
	BarEmpty = Color(12, 4, 4, 215),
}

GMEAT.PlayerColors = {
	Color(80, 170, 255),
	Color(255, 90, 90),
	Color(110, 230, 110),
	Color(255, 210, 70),
	Color(200, 110, 255),
	Color(255, 140, 200),
	Color(80, 230, 220),
	Color(255, 150, 60),
}

GMEAT.PlayerMaterial = "models/flesh"

GMEAT.PlayerModels = {
	"models/player/group01/male_01.mdl",
	"models/player/group01/male_02.mdl",
	"models/player/group01/male_03.mdl",
	"models/player/group01/male_04.mdl",
	"models/player/group01/male_05.mdl",
	"models/player/group01/male_06.mdl",
	"models/player/group01/male_07.mdl",
	"models/player/group01/male_08.mdl",
	"models/player/group01/male_09.mdl",
	"models/player/group01/female_01.mdl",
	"models/player/group01/female_02.mdl",
	"models/player/group01/female_03.mdl",
	"models/player/group01/female_04.mdl",
	"models/player/group01/female_06.mdl",
}

GMEAT.BloodDecalMaterials = {
	"gmeat/decals/splat1",
	"gmeat/decals/splat2",
	"gmeat/decals/splat3",
	"gmeat/decals/splat4",
}
GMEAT.SprayDecalMaterials = {
	"gmeat/decals/spray1",
	"gmeat/decals/spray2",
	"gmeat/decals/spray3",
	"gmeat/decals/spray4",
}

local function registerDecal(name, materials)
	if not materials or #materials == 0 then return "Blood" end
	game.AddDecal(name, #materials == 1 and materials[1] or materials)
	if SERVER then
		for _, mat in ipairs(materials) do
			for _, suffix in ipairs({ ".vmt", "_model.vmt", ".vtf" }) do
				local path = "materials/" .. mat .. suffix
				if file.Exists(path, "GAME") then resource.AddFile(path) end
			end
		end
	end
	return name
end
if SERVER then
	for i = 1, 4 do
		resource.AddFile("materials/gmeat/decals/wound" .. i .. ".vmt")
		resource.AddFile("materials/gmeat/decals/wound" .. i .. ".vtf")
	end
	for i = 1, 8 do
		for _, suffix in ipairs({ "", "_subrect" }) do
			resource.AddFile("materials/decals/blood" .. i .. suffix .. ".vmt")
			resource.AddFile("materials/gmeat/decals/hl2/decals_blood" .. i .. suffix .. "_model.vmt")
			if i <= 5 then
				resource.AddFile("materials/decals/flesh/blood" .. i .. suffix .. ".vmt")
				resource.AddFile("materials/gmeat/decals/hl2/decals_flesh_blood" .. i .. suffix .. "_model.vmt")
			end
		end
	end
end

GMEAT.BloodDecal = registerDecal("GmeatBlood", GMEAT.BloodDecalMaterials)
GMEAT.SprayDecal = registerDecal("GmeatBloodSpray", GMEAT.SprayDecalMaterials)
GMEAT.WallWoundDecalMaterials = { "gmeat/decals/fleshwound1", "gmeat/decals/fleshwound2", "gmeat/decals/fleshwound3", "gmeat/decals/fleshwound4" }
GMEAT.WallWoundDecal = registerDecal("GmeatFleshWound", GMEAT.WallWoundDecalMaterials)
GMEAT.VomitPoolDecal = registerDecal("GmeatVomitPool", { "gmeat/decals/vomitpool1", "gmeat/decals/vomitpool2", "gmeat/decals/vomitpool3", "gmeat/decals/vomitpool4" })
GMEAT.VomitDropsDecal = registerDecal("GmeatVomitDrops", { "gmeat/decals/vomitdrops1", "gmeat/decals/vomitdrops2", "gmeat/decals/vomitdrops3", "gmeat/decals/vomitdrops4" })

GMEAT.Sounds = {
	Ambient = "gmeat/ambient/mazeambient.ogg",
	AmbientVolume = 0.6,
	Death = {},
	DeathLevel = 85,
	GibImpact = {},
	BombPlant = "gmeat/sfx/bombplant.mp3",
	BombDefuse = "gmeat/sfx/bombdefuse.mp3",
	BombDefuseRepeat = 1.1,
	DropOpen = "gmeat/sfx/dropopen.mp3",
	WeaponScroll = "gmeat/sfx/weaponscroll.mp3",
	LowHealth = "gmeat/sfx/lowhealth.ogg",
	LowHealthBelow = 0.25,
	LowHealthVolume = 0.8,
	GibEat = "gmeat/sfx/gibeat.mp3",
	Win = "gmeat/vo/narrator_win.mp3",
	Lose = "gmeat/vo/narrator_lose.mp3",
	Killstreaks = {
		[3] = "gmeat/vo/killstreak_3.mp3",
		[5] = "gmeat/vo/killstreak_5.mp3",
		[10] = "gmeat/vo/killstreak_10.mp3",
	},
}
for i = 1, 14 do GMEAT.Sounds.Death[i] = "gmeat/death/playerdeath" .. i .. ".mp3" end
for i = 1, 5 do GMEAT.Sounds.GibImpact[i] = "gmeat/sfx/gibimpact" .. i .. ".mp3" end

GMEAT.NarratorDurations = {
	["gmeat/vo/killstreak_10.mp3"] = 2.82,
	["gmeat/vo/killstreak_3.mp3"] = 2.35,
	["gmeat/vo/killstreak_5.mp3"] = 2.51,
	["gmeat/vo/narrator_lose.mp3"] = 6.4,
	["gmeat/vo/narrator_win.mp3"] = 3.45,
	["gmeat/vo/quest_assembly.mp3"] = 3.84,
	["gmeat/vo/quest_bomb.mp3"] = 2.19,
	["gmeat/vo/quest_delivery.mp3"] = 3.24,
	["gmeat/vo/quest_killconfirmed.mp3"] = 3.13,
	["gmeat/vo/supply_drop_1.mp3"] = 2.43,
	["gmeat/vo/supply_drop_2.mp3"] = 2.51,
	["gmeat/vo/supply_drop_3.mp3"] = 3.06,
	["gmeat/vo/supply_drop_4.mp3"] = 2.9,
}

if SERVER then
	local function add(path) resource.AddFile("sound/" .. path) end
	add(GMEAT.Sounds.Ambient)
	for _, list in ipairs({ GMEAT.Sounds.Death, GMEAT.Sounds.GibImpact, GMEAT.Sounds.Killstreaks }) do
		for _, path in pairs(list) do add(path) end
	end
	for _, key in ipairs({ "BombPlant", "BombDefuse", "DropOpen", "WeaponScroll", "LowHealth", "GibEat", "Win", "Lose" }) do add(GMEAT.Sounds[key]) end
	for path in pairs(GMEAT.NarratorDurations) do add(path) end
	for _, mat in ipairs({ GMEAT.HUD.Plate, GMEAT.HUD.BarFrame, GMEAT.HUD.BarFill }) do
		resource.AddFile("materials/" .. mat .. ".vmt")
		resource.AddFile("materials/" .. mat .. ".vtf")
	end
end

GMEAT.BloodVomit = {
	Episodes = { 2, 5 },
	StartDelay = { 0.8, 2.2 },
	Gap = { 0.5, 3.2 },
	CoughTime = { 0.35, 0.8 },
	GushTime = { 0.9, 2.2 },
	GushSpeed = { 45, 110 },
	CoughSpeed = { 60, 140 },
	Fade = 0.75,
	FloorStains = true,
	MaxTime = 16,
}

GMEAT.FloorStains = {
	{ name = "drops", mats = { "gmeat/decals/floor_spray1", "gmeat/decals/floor_spray2", "gmeat/decals/floor_spray3", "gmeat/decals/floor_spray4" }, size = 17 },
	{ name = "pool", mats = { "gmeat/decals/floor_splat1", "gmeat/decals/floor_splat2", "gmeat/decals/floor_splat3", "gmeat/decals/floor_splat4" }, size = 30 },
	{ name = "splat", mats = { "gmeat/decals/floor_splat1", "gmeat/decals/floor_splat2", "gmeat/decals/floor_splat3", "gmeat/decals/floor_splat4" }, size = 22 },
}
GMEAT_STAIN_DROPS, GMEAT_STAIN_POOL, GMEAT_STAIN_SPLAT = 1, 2, 3
GMEAT.MaxFloorStains = 500
if SERVER then
	for _, kind in ipairs(GMEAT.FloorStains) do
		for _, mat in ipairs(kind.mats) do resource.AddFile("materials/" .. mat .. ".vmt") end
	end
end

do
	local B = "ValveBiped.Bip01_"
	GMEAT.BodySegments = {
		[B .. "Head1"] = { to = nil, along = 7, radius = 4.5 },
		[B .. "Neck1"] = { to = B .. "Head1", radius = 2.8 },
		[B .. "Spine4"] = { to = B .. "Neck1", radius = 7 },
		[B .. "Spine2"] = { to = B .. "Neck1", radius = 7.5 },
		[B .. "Spine1"] = { to = B .. "Spine2", radius = 7.5 },
		[B .. "Spine"] = { to = B .. "Spine1", radius = 7 },
		[B .. "Pelvis"] = { to = B .. "Spine", radius = 7 },
	}
	for _, s in ipairs({ "L_", "R_" }) do
		GMEAT.BodySegments[B .. s .. "UpperArm"] = { to = B .. s .. "Forearm", radius = 2.8 }
		GMEAT.BodySegments[B .. s .. "Forearm"] = { to = B .. s .. "Hand", radius = 2.3 }
		GMEAT.BodySegments[B .. s .. "Hand"] = { to = B .. s .. "Finger2", along = 4, radius = 1.8 }
		GMEAT.BodySegments[B .. s .. "Thigh"] = { to = B .. s .. "Calf", radius = 4 }
		GMEAT.BodySegments[B .. s .. "Calf"] = { to = B .. s .. "Foot", radius = 3 }
		GMEAT.BodySegments[B .. s .. "Foot"] = { to = B .. s .. "Toe0", along = 6, radius = 2.2 }
	end
	GMEAT.HitGroupBones = {
		[HITGROUP_HEAD or 1] = { B .. "Head1", B .. "Neck1" },
		[HITGROUP_CHEST or 2] = { B .. "Spine2", B .. "Spine4", B .. "Spine1" },
		[HITGROUP_STOMACH or 3] = { B .. "Spine", B .. "Spine1", B .. "Pelvis" },
		[HITGROUP_LEFTARM or 4] = { B .. "L_UpperArm", B .. "L_Forearm", B .. "L_Hand" },
		[HITGROUP_RIGHTARM or 5] = { B .. "R_UpperArm", B .. "R_Forearm", B .. "R_Hand" },
		[HITGROUP_LEFTLEG or 6] = { B .. "L_Thigh", B .. "L_Calf", B .. "L_Foot" },
		[HITGROUP_RIGHTLEG or 7] = { B .. "R_Thigh", B .. "R_Calf", B .. "R_Foot" },
	}
end

function GMEAT.BodySegment(ent, bone)
	local name = ent:GetBoneName(bone)
	local seg = name and GMEAT.BodySegments[name]
	local m = ent:GetBoneMatrix(bone)
	if not m then return end
	local a = m:GetTranslation()
	if not seg then return a, a, 6 end
	local b
	local child = seg.to and ent:LookupBone(seg.to)
	local cm = child and ent:GetBoneMatrix(child)
	if cm then b = cm:GetTranslation() end
	if seg.along then
		local parent = ent:GetBoneParent(bone)
		local pm = parent and parent >= 0 and ent:GetBoneMatrix(parent)
		local axis = (b and (b - a)) or (pm and (a - pm:GetTranslation())) or Vector(0, 0, 1)
		if axis:IsZero() then axis = Vector(0, 0, 1) end
		b = a + axis:GetNormalized() * seg.along
	end
	return a, b or a, seg.radius
end

function GMEAT.SnapToBody(ent, bone, pos, facing)
	local a, b, radius = GMEAT.BodySegment(ent, bone)
	if not a then return pos end
	local ab = b - a
	local len2 = ab:LengthSqr()
	local t = len2 > 0.01 and math.Clamp((pos - a):Dot(ab) / len2, 0, 1) or 0
	local c = a + ab * t
	local out = pos - c
	if out:LengthSqr() < 0.25 then out = facing or Vector(0, 0, 1) end
	return c + out:GetNormalized() * radius
end

function GMEAT.CorpseMouth(ent)
	local eyes, mouth
	local id = ent:LookupAttachment("eyes")
	if id and id > 0 then eyes = ent:GetAttachment(id) end
	id = ent:LookupAttachment("mouth")
	if id and id > 0 then mouth = ent:GetAttachment(id) end
	if mouth or eyes then
		local pos = mouth and mouth.Pos or (eyes.Pos - eyes.Ang:Up() * 3.5)
		local dir = eyes and eyes.Ang:Forward() or mouth.Ang:Forward()
		return pos, dir
	end
	local bone = ent:LookupBone("ValveBiped.Bip01_Head1")
	local pos = bone and ent:GetBonePosition(bone)
	if pos then return pos, Vector(0, 0, 1) end
end

GMEAT.FleshMaze = {
	Material = "models/flesh",
	FloorUpShare = 0.55,
	SkipNames = { "light", "lamp", "glow", "fluor", "neon", "bulb", "emit", "window", "glass", "sign",
		"sky", "water", "screen", "monitor", "tools/", "nodraw" },

	TentacleModel = "models/barnacle.mdl",
	TentaclesPerRoom = { 1, 3 },
	CellsPerTentacle = 10,
	TentacleLength = { 40, 110 },
	TipMinHeight = 76,
	MinCeiling = 110,
	DoorClearance = 80,
	BoneChance = 0.35,
	BoneModels = {
		"models/gibs/hgibs.mdl",
	},
	SwayAmount = 6,
}

function GMEAT.IsFleshWall(tr)
	return tr ~= nil and tr.Hit == true and IsValid(tr.Entity) and tr.Entity:GetClass() == "sector75_room_entity"
		and tr.HitNormal ~= nil and tr.HitNormal.z < 0.7
end

hook.Add("OnEntityCreated", "Gmeat_FleshImpacts", function(ent)
	timer.Simple(0, function()
		if not IsValid(ent) or not ent:IsWeapon() or ent.GmeatImpactWrapped then return end
		ent.GmeatImpactWrapped = true
		local old = ent.DoImpactEffect
		ent.DoImpactEffect = function(self, tr, dmgType)
			if GMEAT.IsFleshWall(tr) then return true end
			if old then return old(self, tr, dmgType) end
		end
	end)
end)
