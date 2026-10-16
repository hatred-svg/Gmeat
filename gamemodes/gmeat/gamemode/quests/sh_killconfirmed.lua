local QUEST = {}
QUEST.ID = "killconfirmed"
QUEST.Name = "Kill Confirmed"
QUEST.Color = Color(240, 220, 120)
QUEST.StartLine = "quest_killconfirmed"

function QUEST:Describe()
	return string.format("Kill players and collect the skulls they drop. First to %d confirmed kills wins.", GetConVar("gmeat_killconfirmed_goal"):GetInt())
end

if SERVER then
	local SKULL_LIFETIME = 60
	local ALLOW_DENY = true
	local DENY_COLOR = Color(255, 90, 90)

	function QUEST:StartLineArgs()
		return self.goal
	end

	function QUEST:Start()
		self.goal = math.max(1, GetConVar("gmeat_killconfirmed_goal"):GetInt())
		for _, ply in ipairs(player.GetAll()) do
			ply.GmeatConfirmed = 0
			self:UpdateProgress(ply)
		end
	end

	function QUEST:UpdateProgress(ply)
		local confirmed = ply.GmeatConfirmed or 0
		ply:SetNWFloat("GmeatProgress", math.min(0.99, confirmed / self.goal))
		ply:SetNWString("GmeatProgressText", string.format("Confirmed kills: %d/%d", confirmed, self.goal))
	end

	function QUEST:PlayerDeath(victim, attacker)
		if not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim then return end
		local floor = GAMEMODE:FindFloorBelow(victim:GetPos())
		if not floor then return end
		local skull = ents.Create("gmeat_skull")
		skull:SetPos(floor)
		skull:SetKiller(attacker)
		skull:SetVictim(victim)
		skull:Spawn()
		GAMEMODE:PlaceOnFloor(skull, floor)
		skull.GmeatExpires = CurTime() + SKULL_LIFETIME
	end

	function QUEST:OnPickup(ent, ply)
		if ent:GetClass() ~= "gmeat_skull" then return false end
		local killer = ent:GetKiller()

		if ply == killer then
			ply.GmeatConfirmed = (ply.GmeatConfirmed or 0) + 1
			self:UpdateProgress(ply)
			ply:EmitSound("buttons/button14.wav")
			local victim = ent:GetVictim()
			GAMEMODE:Notify(ply, string.format("Kill confirmed%s (%d/%d)", IsValid(victim) and (": " .. victim:Nick()) or "", ply.GmeatConfirmed, self.goal))
			if ply.GmeatConfirmed >= self.goal then
				GAMEMODE:EndRound(ply, string.format("%d kills confirmed.", self.goal))
			elseif self.goal - ply.GmeatConfirmed == 2 then
				GAMEMODE:Announce("kc_close", ply:Nick(), 2)
			end
			return true
		end

		if not ALLOW_DENY then return false end
		ply:EmitSound("buttons/button10.wav")
		GAMEMODE:Notify(ply, IsValid(killer) and ("Kill denied: " .. killer:Nick()) or "Kill denied")
		if IsValid(killer) then
			GAMEMODE:Notify(killer, ply:Nick() .. " denied your kill!")
		end
		return true
	end

	function QUEST:Think()
		local now = CurTime()
		for _, skull in ipairs(ents.FindByClass("gmeat_skull")) do
			if skull.GmeatExpires and now > skull.GmeatExpires then
				skull:Remove()
			end
		end
	end

	function QUEST:GetMarkers(list)
		for _, skull in ipairs(ents.FindByClass("gmeat_skull")) do
			local killer = skull:GetKiller()
			if IsValid(killer) then
				list[#list + 1] = {
					type = GMEAT_MARKER_OBJECTIVE,
					pos = skull:GetPos() + Vector(0, 0, 20),
					color = self.Color,
					label = "Your kill",
					hud = true,
					viewer = killer,
				}
			end
			list[#list + 1] = {
				type = GMEAT_MARKER_PROXIMITY,
				pos = skull:GetPos(),
				color = DENY_COLOR,
				label = "",
			}
		end
	end
end

GM:RegisterQuest(QUEST)
