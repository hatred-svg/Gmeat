local QUEST = {}
QUEST.ID = "delivery"
QUEST.Name = "Hot Delivery"
QUEST.Color = Color(255, 150, 60)
QUEST.StartLine = "quest_delivery"

function QUEST:Describe()
	return "Grab the package and carry it to the drop-off."
end

if SERVER then
	local PACKAGE_ROOM = 4
	local PACKAGE_FALLBACK = 40
	local ZONE_RADIUS = 110
	local ZONE_COLOR = Color(255, 220, 90)

	function QUEST:Start()
		self.carry = nil
		self.zone = nil
		self.packageRoom = nil
		self.startTime = CurTime()
		self.nextProgress = 0
		for _, ply in ipairs(player.GetAll()) do
			ply.GmeatHeld = 0
			self:UpdateProgress(ply)
		end
		local neutral = GAMEMODE:PickNeutralRoom()
		if neutral then self:SpawnPackage(neutral, true) end
		for _, info in ipairs(GAMEMODE.RoomList) do
			self:OnRoomRegistered(info)
		end
	end

	function QUEST:UpdateProgress(ply)
		local held = ply.GmeatHeld or 0
		if self.carry and self.carry.carrier == ply then
			ply:SetNWFloat("GmeatProgress", 0.6 + math.min(0.3, held / 300))
			ply:SetNWString("GmeatProgressText", "You have the package! Get to the drop-off.")
		else
			ply:SetNWFloat("GmeatProgress", math.min(0.5, held / 120))
			ply:SetNWString("GmeatProgressText", held > 0 and string.format("Package held for %ds", math.floor(held)) or "")
		end
	end

	function QUEST:SpawnPackage(info, quiet)
		local pos = GAMEMODE:PickSpot(info, 16)
		if not pos then return false end
		GAMEMODE:ReserveSpot(pos)
		self.carry = GAMEMODE:CarrySpawn("package", pos)
		self.packageRoom = info
		if not quiet then GAMEMODE:Announce("package_spawned") end
		return true
	end

	function QUEST:OnRoomRegistered(info)
		if self.carry or info.isStart or info.spawnRoom or info.order < PACKAGE_ROOM then return end
		self:SpawnPackage(info)
	end

	function QUEST:CreateDropZone()
		local home = self.carry.home
		local room = GAMEMODE:PickRoom(function(info)
			if info == self.packageRoom then return nil end
			return info.center:DistToSqr(home)
		end) or GAMEMODE.StartRoom
		local pos = room and (GAMEMODE:PickSpot(room, 32) or room.spots[1])
		if not pos then pos = home end
		self.zone = GAMEMODE:CreateZone(pos, ZONE_RADIUS, ZONE_COLOR, "Drop-off")
		GAMEMODE:Announce("dropzone")
	end

	function QUEST:Think()
		if not self.carry then
			if CurTime() - self.startTime > PACKAGE_FALLBACK then
				local room = GAMEMODE:PickRoom(function(info) return info.depth + (info.isStart and -100 or 0) end)
				if room then self:SpawnPackage(room) end
				self.startTime = CurTime()
			end
			return
		end

		if GAMEMODE:CarryThink(self.carry) then
			GAMEMODE:Announce("package_returned")
		end

		local carrier = self.carry.carrier
		if IsValid(carrier) then
			carrier.GmeatHeld = (carrier.GmeatHeld or 0) + engine.TickInterval()
			if GAMEMODE:InZone(carrier, self.zone) then
				GAMEMODE:EndRound(carrier, "Package delivered.")
				return
			end
		end

		if CurTime() >= self.nextProgress then
			self.nextProgress = CurTime() + 0.25
			for _, ply in ipairs(player.GetAll()) do self:UpdateProgress(ply) end
		end
	end

	function QUEST:OnPickup(ent, ply)
		if not self.carry or ent ~= self.carry.ent then return false end
		GAMEMODE:CarryPickup(self.carry, ply)
		if not IsValid(self.zone) then self:CreateDropZone() end
		GAMEMODE:Announce("package_taken", ply:Nick())
		self:UpdateProgress(ply)
		return true
	end

	function QUEST:DropIfCarrier(ply)
		if self.carry and self.carry.carrier == ply then
			GAMEMODE:CarryDrop(self.carry, ply:GetPos())
			GAMEMODE:Announce("package_dropped")
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
		if carry then
			if IsValid(carry.carrier) then
				list[#list + 1] = {
					type = GMEAT_MARKER_OBJECTIVE,
					pos = carry.carrier:GetPos() + Vector(0, 0, 80),
					ent = carry.carrier,
					color = self.Color,
					label = carry.carrier:Nick() .. " (package)",
					hud = true,
				}
			elseif IsValid(carry.ent) then
				list[#list + 1] = {
					type = GMEAT_MARKER_OBJECTIVE,
					pos = carry.ent:GetPos() + Vector(0, 0, 20),
					color = self.Color,
					label = carry.droppedAt and "Package (dropped)" or "Package",
					hud = true,
				}
			end
		end
		if IsValid(self.zone) then
			list[#list + 1] = {
				type = GMEAT_MARKER_AREA,
				pos = self.zone:GetPos(),
				color = ZONE_COLOR,
				label = "Drop-off",
				radius = self.zone:GetRadius(),
				hud = true,
			}
		end
	end
end

GM:RegisterQuest(QUEST)
