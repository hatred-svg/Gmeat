local QUEST = {}
QUEST.ID = "bomb"
QUEST.Name = "Demolition"
QUEST.Color = Color(235, 70, 70)
QUEST.StartLine = "quest_bomb"

function QUEST:Describe()
	return "Find the explosive, plant it at the demolition site and keep it from being defused."
end

if SERVER then
	local BOMB_ROOM = 3
	local SITE_GAP = 2
	local SITE_MIN_DIST = 700
	local BOMB_FALLBACK = 30
	local SITE_FALLBACK = 70
	local SITE_RADIUS = 150
	local PLANT_TIME = 3
	local DEFUSE_TIME = 5

	function QUEST:Start()
		self.carry = nil
		self.site = nil
		self.planted = nil
		self.plantStart = nil
		self.bombRoom = nil
		self.startTime = CurTime()
		self.nextProgress = 0
		local neutral = GAMEMODE:PickNeutralRoom()
		if neutral then self:SpawnBomb(neutral, true) end
		for _, info in ipairs(GAMEMODE.RoomList) do
			self:OnRoomRegistered(info)
		end
	end

	function QUEST:UpdateProgress(ply)
		if IsValid(self.planted) and self.planted:GetPlanter() == ply then
			ply:SetNWFloat("GmeatProgress", 0.95)
			ply:SetNWString("GmeatProgressText", "Your bomb is ticking. Defend it!")
		elseif self.carry and self.carry.carrier == ply then
			ply:SetNWFloat("GmeatProgress", 0.5)
			ply:SetNWString("GmeatProgressText", IsValid(self.site) and "You have the explosive! Get to the site." or "You have the explosive! Waiting for a site...")
		else
			ply:SetNWFloat("GmeatProgress", 0)
			ply:SetNWString("GmeatProgressText", "")
		end
	end

	function QUEST:SpawnBomb(info, quiet)
		local pos = GAMEMODE:PickSpot(info, 16)
		if not pos then return false end
		GAMEMODE:ReserveSpot(pos)
		self.carry = GAMEMODE:CarrySpawn("bomb", pos)
		self.bombRoom = info
		if not quiet then GAMEMODE:Announce("bomb_spawned") end
		return true
	end

	function QUEST:CreateSite(info)
		local pos = GAMEMODE:PickSpot(info, 32) or info.spots[1]
		if not pos then return false end
		self.site = GAMEMODE:CreateZone(pos, SITE_RADIUS, self.Color, "Demolition site")
		GAMEMODE:Announce("bomb_site")
		return true
	end

	function QUEST:OnRoomRegistered(info)
		if info.isStart or info.spawnRoom then return end
		if not self.carry then
			if info.order >= BOMB_ROOM then self:SpawnBomb(info) end
			return
		end
		if not IsValid(self.site) and info ~= self.bombRoom and info.order >= self.bombRoom.order + SITE_GAP
			and info.center:Distance(self.carry.home) > SITE_MIN_DIST then
			self:CreateSite(info)
		end
	end

	function QUEST:CancelPlant(ply)
		if self.plantStart then
			self.plantStart = nil
			if IsValid(ply) then
				GAMEMODE:ClearHoldBar(ply)
				ply:StopSound(GMEAT.Sounds.BombPlant)
			end
		end
	end

	function QUEST:Plant(ply)
		self.plantStart = nil
		GAMEMODE:ClearHoldBar(ply)
		local pos = GAMEMODE:FindFloorBelow(ply:GetPos()) or ply:GetPos()
		GAMEMODE:CarryRemove(self.carry)
		ply:SetNWBool("GmeatInSite", false)

		local bomb = ents.Create("gmeat_planted_bomb")
		bomb:SetPos(pos)
		bomb:SetAngles(Angle(0, ply:EyeAngles().y, 0))
		bomb:SetPlanter(ply)
		bomb:SetDetonateAt(CurTime() + GetConVar("gmeat_bomb_fuse"):GetFloat())
		bomb:Spawn()
		GAMEMODE:PlaceOnFloor(bomb, pos)
		self.planted = bomb
		GAMEMODE:Announce("bomb_planted", ply:Nick())
	end

	function QUEST:Think()
		local now = CurTime()
		if not self.carry then
			if now - self.startTime > BOMB_FALLBACK then
				local room = GAMEMODE:PickRoom(function(info) return info.depth + (info.isStart and -100 or 0) end)
				if room then self:SpawnBomb(room) end
				self.startTime = now
			end
			return
		end

		if not IsValid(self.site) and now - self.startTime > SITE_FALLBACK then
			local home = self.carry.home
			local room = GAMEMODE:PickRoom(function(info)
				if info == self.bombRoom then return nil end
				return info.center:DistToSqr(home)
			end) or self.bombRoom
			if room then self:CreateSite(room) end
			self.startTime = now
		end

		if not IsValid(self.planted) and GAMEMODE:CarryThink(self.carry) then
			GAMEMODE:Announce("bomb_returned")
		end

		local carrier = self.carry.carrier
		if IsValid(carrier) and IsValid(self.site) and GAMEMODE:InZone(carrier, self.site) then
			carrier:SetNWBool("GmeatInSite", true)
			local steady = carrier:GetVelocity():Length2D() < 80 and now - (carrier.GmeatHurtAt or 0) > 0.15
			if carrier:KeyDown(IN_USE) and steady then
				if not self.plantStart then
					self.plantStart = now
					GAMEMODE:SetHoldBar(carrier, now, now + PLANT_TIME, "Planting explosive")
					carrier:EmitSound(GMEAT.Sounds.BombPlant, 75)
				elseif now >= self.plantStart + PLANT_TIME then
					self:Plant(carrier)
				end
			else
				self:CancelPlant(carrier)
			end
		else
			if IsValid(carrier) then carrier:SetNWBool("GmeatInSite", false) end
			self:CancelPlant(carrier)
		end

		if now >= self.nextProgress then
			self.nextProgress = now + 0.25
			for _, ply in ipairs(player.GetAll()) do self:UpdateProgress(ply) end
		end
	end

	function QUEST:OnPickup(ent, ply)
		if not self.carry or ent ~= self.carry.ent then return false end
		GAMEMODE:CarryPickup(self.carry, ply)
		GAMEMODE:Announce("bomb_taken", ply:Nick())
		self:UpdateProgress(ply)
		return true
	end

	function QUEST:InteractInfo(ent, ply)
		if ent ~= self.planted then return end
		if ent:GetPlanter() == ply then return nil, "Defend your explosive!" end
		return DEFUSE_TIME, "Defuse explosive", { path = GMEAT.Sounds.BombDefuse, repeatEvery = GMEAT.Sounds.BombDefuseRepeat }
	end

	function QUEST:InteractDone(ent, ply)
		if ent ~= self.planted then return end
		local pos = ent:GetPos()
		self.planted = nil
		ent:Remove()
		GAMEMODE:CarryPlace(self.carry, GAMEMODE:FindFloorBelow(pos) or pos, false)
		GAMEMODE:Announce("bomb_defused", ply:Nick())
	end

	function QUEST:OnBombDetonate(bomb)
		if bomb ~= self.planted then return end
		self.planted = nil
		local planter = bomb:GetPlanter()
		bomb:Explode()
		if IsValid(planter) then
			GAMEMODE:EndRound(planter, "The site went up in flames.")
		else
			GAMEMODE:EndRound(nil)
		end
	end

	function QUEST:InOvertime()
		return IsValid(self.planted)
	end

	function QUEST:DropIfCarrier(ply)
		if self.carry and self.carry.carrier == ply then
			self:CancelPlant(ply)
			GAMEMODE:CarryDrop(self.carry, ply:GetPos())
			GAMEMODE:Announce("bomb_dropped")
		end
	end

	function QUEST:PlayerDeath(ply)
		self:DropIfCarrier(ply)
	end

	function QUEST:PlayerDisconnected(ply)
		self:DropIfCarrier(ply)
	end

	function QUEST:GetMarkers(list)
		local carry = self.carry
		if IsValid(self.planted) then
			local left = math.max(0, self.planted:GetDetonateAt() - CurTime())
			list[#list + 1] = {
				type = GMEAT_MARKER_OBJECTIVE,
				pos = self.planted:GetPos() + Vector(0, 0, 20),
				color = self.Color,
				label = string.format("EXPLOSIVE %ds", math.ceil(left)),
				hud = true,
			}
		elseif carry then
			if IsValid(carry.carrier) then
				list[#list + 1] = {
					type = GMEAT_MARKER_OBJECTIVE,
					pos = carry.carrier:GetPos() + Vector(0, 0, 80),
					ent = carry.carrier,
					color = self.Color,
					label = carry.carrier:Nick() .. " (explosive)",
					hud = true,
				}
			elseif IsValid(carry.ent) then
				list[#list + 1] = {
					type = GMEAT_MARKER_OBJECTIVE,
					pos = carry.ent:GetPos() + Vector(0, 0, 20),
					color = self.Color,
					label = carry.droppedAt and "Explosive (dropped)" or "Explosive",
					hud = true,
				}
			end
		end
		if IsValid(self.site) then
			list[#list + 1] = {
				type = GMEAT_MARKER_AREA,
				pos = self.site:GetPos(),
				color = self.Color,
				label = "Demolition site",
				radius = self.site:GetRadius(),
				hud = true,
			}
		end
	end
end

GM:RegisterQuest(QUEST)
