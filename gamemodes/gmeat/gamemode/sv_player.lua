DEFINE_BASECLASS("gamemode_base")

function GM:AssignColor(ply)
	local used = {}
	for _, other in ipairs(player.GetAll()) do
		if other ~= ply and other.GmeatColorIndex then used[other.GmeatColorIndex] = true end
	end
	local index = 1
	for i = 1, #GMEAT.PlayerColors do
		if not used[i] then index = i break end
	end
	ply.GmeatColorIndex = index
	local c = GMEAT.PlayerColors[index]
	ply:SetNWVector("GmeatColor", Vector(c.r, c.g, c.b))
end

function GM:PlayerInitialSpawn(ply, transition)
	BaseClass.PlayerInitialSpawn(self, ply, transition)
	ply.GmeatModel = GMEAT.PlayerModels[math.random(#GMEAT.PlayerModels)]
	self:AssignColor(ply)
end

function GM:PlayerSpawn(ply, transition)
	BaseClass.PlayerSpawn(self, ply, transition)
	ply:SetupHands()

	ply:SetWalkSpeed(GMEAT.Movement.walk)
	ply:SetRunSpeed(GMEAT.Movement.run)
	ply:SetSlowWalkSpeed(GMEAT.Movement.slowwalk)
	ply:SetJumpPower(GMEAT.Movement.jump)
	ply:SetCrouchedWalkSpeed(GMEAT.Movement.crouch)

	ply:SetArmor(0)
	ply.GmeatLifeKills = 0
	ply:SetBloodColor(DONT_BLEED)
	ply:AllowFlashlight(false)
	if ply:FlashlightIsOn() then ply:Flashlight(false) end

	ply:RemoveAllDecals()
	net.Start("Gmeat_ClearDecals")
	net.WriteEntity(ply)
	net.Broadcast()
	ply:SetNWString("GmeatCarrying", "")
	ply:SetNWBool("GmeatInSite", false)
	ply:SetNWFloat("GmeatRespawnAt", 0)
	self:ClearHold(ply)

	local spot, yaw
	if self:GetRoundState() == GMEAT_ACTIVE then
		spot, yaw = self:GetRespawnSpot(ply, ply.GmeatLastKiller)
	end
	ply.GmeatRespawning = nil
	ply.GmeatLastKiller = nil
	if not spot then spot, yaw = self:GetStartSpot() end
	if spot then
		ply:SetPos(spot + Vector(0, 0, 2))
		ply:SetEyeAngles(Angle(0, yaw, 0))
	end

	local state = self:GetRoundState()
	ply:Freeze(state == GMEAT_PREP)
	self:ApplySpawnProtection(ply)
	if state == GMEAT_POST then
		ply:GodEnable()
	elseif not ply.GmeatProtectUntil then
		ply:GodDisable()
	end
end

function GM:PlayerLoadout(ply)
	ply:StripWeapons()
	ply:StripAmmo()
	return true
end

function GM:PlayerSetModel(ply)
	local model = ply.GmeatModel or GMEAT.PlayerModels[1]
	util.PrecacheModel(model)
	ply:SetModel(model)
	ply:SetMaterial(GMEAT.PlayerMaterial or "")
	local c = ply:GetNWVector("GmeatColor", Vector(255, 255, 255))
	ply:SetPlayerColor(Vector(c.x / 255, c.y / 255, c.z / 255))
end

function GM:PlayerSwitchFlashlight(ply, enabled)
	return not enabled
end

timer.Create("Gmeat_NoFlashlight", 0.5, 0, function()
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:FlashlightIsOn() then ply:Flashlight(false) end
	end
end)

function GM:PlayerSetHandsModel(ply, ent)
	local simple = player_manager.TranslateToPlayerModelName(ply:GetModel())
	local info = player_manager.TranslatePlayerHands(simple)
	if info then
		ent:SetModel(info.model)
		ent:SetSkin(info.skin)
		ent:SetBodyGroups(info.body)
	end
	ent:SetMaterial(GMEAT.PlayerMaterial or "")
end

function GM:ApplySpawnProtection(ply)
	local duration = GetConVar("gmeat_spawn_protect"):GetFloat()
	if duration <= 0 then
		ply.GmeatProtectUntil = nil
		return
	end
	ply.GmeatProtectUntil = CurTime() + duration
	ply:SetNWFloat("GmeatProtectUntil", ply.GmeatProtectUntil)
	ply:GodEnable()
	ply:SetRenderMode(RENDERMODE_TRANSCOLOR)
	ply:SetColor(Color(255, 255, 255, 110))
end

function GM:EndSpawnProtection(ply)
	ply.GmeatProtectUntil = nil
	ply:SetNWFloat("GmeatProtectUntil", 0)
	ply:SetColor(Color(255, 255, 255, 255))
	if self:GetRoundState() ~= GMEAT_POST then
		ply:GodDisable()
	end
end

function GM:ProtectionThink()
	local now = CurTime()
	for _, ply in ipairs(player.GetAll()) do
		if ply.GmeatProtectUntil and now >= ply.GmeatProtectUntil then
			self:EndSpawnProtection(ply)
		end
	end
end

function GM:KeyPress(ply, key)
	if ply.GmeatProtectUntil and (key == IN_ATTACK or key == IN_ATTACK2) then
		self:EndSpawnProtection(ply)
	end
end

function GM:DoPlayerDeath(ply, attacker, dmginfo)
	local weps = ply:GetWeapons()
	for i, wep in ipairs(weps) do
		if IsValid(wep) then
			local a = (i / #weps) * math.pi * 2
			ply:DropWeapon(wep, nil, Vector(math.cos(a) * 90, math.sin(a) * 90, 120))
		end
	end

	ply:AddDeaths(1)
	ply.GmeatLifeKills = 0
	if IsValid(attacker) and attacker:IsPlayer() then
		attacker:AddFrags(attacker == ply and -1 or 1)
		if attacker ~= ply then
			attacker.GmeatLifeKills = (attacker.GmeatLifeKills or 0) + 1
			local line = GMEAT.Sounds.Killstreaks[attacker.GmeatLifeKills]
			if line then self:Narrate(attacker, line) end
			net.Start("Gmeat_KillFX")
			net.Send(attacker)
		end
	end

	local ok, err = pcall(self.HandleDeathBody, self, ply, attacker, dmginfo)
	if not ok then
		ErrorNoHalt("[Gmeat] death body error: " .. tostring(err) .. "\n")
	end
end

function GM:PlayerDeath(ply, inflictor, attacker)
	BaseClass.PlayerDeath(self, ply, inflictor, attacker)
	local respawnAt = CurTime() + GetConVar("gmeat_respawn_time"):GetFloat()
	ply.GmeatRespawnAt = respawnAt
	ply:SetNWFloat("GmeatRespawnAt", respawnAt)
	ply.GmeatRespawning = true
	ply.GmeatLastKiller = (IsValid(attacker) and attacker:IsPlayer() and attacker ~= ply) and attacker or nil
	self:ClearHold(ply)
	self:QuestCall("PlayerDeath", ply, attacker)
	ply:SetNWString("GmeatCarrying", "")
end

function GM:PlayerDeathThink(ply)
	if (ply.GmeatRespawnAt or 0) > CurTime() then return false end
	ply:Spawn()
	return true
end

function GM:PlayerDisconnected(ply)
	if BaseClass.PlayerDisconnected then BaseClass.PlayerDisconnected(self, ply) end
	self:QuestCall("PlayerDisconnected", ply)
end

function GM:GetFallDamage(ply, speed)
	return math.max(0, (speed - 526.5) * (100 / 396))
end

function GM:PlayerNoClip(ply, desired)
	if not desired then return true end
	return ply:IsAdmin() and GetConVar("gmeat_admin_noclip"):GetBool()
end

hook.Add("EntityTakeDamage", "Gmeat_InterruptHolds", function(target, dmginfo)
	if IsValid(target) and target:IsPlayer() and dmginfo:GetDamage() > 0 then
		target.GmeatHurtAt = CurTime()
		if target.GmeatHold and GAMEMODE then GAMEMODE:ClearHold(target) end
	end
end)

function GM:PlayerCanPickupItem(ply, item)
	if item:GetClass() == "item_battery" then return false end
	return true
end

hook.Add("PlayerUse", "Gmeat_NoSuitCharger", function(ply, ent)
	if IsValid(ent) and ent:GetClass() == "item_suitcharger" then return false end
end)
