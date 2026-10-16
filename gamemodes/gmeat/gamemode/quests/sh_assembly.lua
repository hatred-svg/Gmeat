local QUEST = {}
QUEST.ID = "assembly"
QUEST.Name = "Assembly"
QUEST.Color = Color(255, 196, 64)
QUEST.StartLine = "quest_assembly"

function QUEST:Describe()
	return string.format("Collect %d power cells and install them in the generator.", GetConVar("gmeat_assembly_cells"):GetInt())
end

if SERVER then
	local GENERATOR_ROOM = 4
	local GENERATOR_FALLBACK = 40
	local CELL_COLOR = Color(90, 255, 130)

	function QUEST:StartLineArgs()
		return self.needed
	end

	function QUEST:Start()
		self.needed = math.max(1, GetConVar("gmeat_assembly_cells"):GetInt())
		self.generator = nil
		self.startTime = CurTime()
		self.nextProgress = 0
		for _, ply in ipairs(player.GetAll()) do
			ply.GmeatCarried = 0
			ply.GmeatInstalled = 0
			self:UpdateProgress(ply)
		end
		local neutral = GAMEMODE:PickNeutralRoom()
		if neutral then self:SpawnGenerator(neutral, true) end
		for _, info in ipairs(GAMEMODE.RoomList) do
			self:OnRoomRegistered(info)
		end
	end

	function QUEST:UpdateProgress(ply)
		local carried, installed = ply.GmeatCarried or 0, ply.GmeatInstalled or 0
		ply:SetNWFloat("GmeatProgress", math.min(0.99, (installed + carried * 0.5) / self.needed))
		ply:SetNWString("GmeatProgressText", string.format("Cells: %d carried, %d/%d installed", carried, installed, self.needed))
	end

	function QUEST:CellChance()
		local outstanding = 0
		for _, ply in ipairs(player.GetAll()) do
			outstanding = outstanding + math.max(0, self.needed - (ply.GmeatInstalled or 0) - (ply.GmeatCarried or 0))
		end
		local onGround = #ents.FindByClass("gmeat_cell")
		if onGround >= outstanding + 2 then return 0.15 end
		return math.Clamp(0.4 + (outstanding - onGround) * 0.08, 0.4, 0.9)
	end

	function QUEST:SpawnGenerator(info, quiet)
		local gen = GAMEMODE:SpawnInRoom("gmeat_generator", info, 40)
		if IsValid(gen) then
			self.generator = gen
			if not quiet then GAMEMODE:Announce("generator_found") end
			return true
		end
		return false
	end

	function QUEST:OnRoomRegistered(info)
		if info.isStart or info.spawnRoom then return end
		if not IsValid(self.generator) and info.order >= GENERATOR_ROOM then
			if self:SpawnGenerator(info) then return end
		end
		if math.random() < self:CellChance() then
			GAMEMODE:SpawnInRoom("gmeat_cell", info, 12)
		end
	end

	function QUEST:Think()
		if not IsValid(self.generator) and CurTime() - self.startTime > GENERATOR_FALLBACK then
			local room = GAMEMODE:PickRoom(function(info) return info.depth + (info.isStart and -100 or 0) end)
			if room then self:SpawnGenerator(room) end
			self.startTime = CurTime()
		end
		if CurTime() >= self.nextProgress then
			self.nextProgress = CurTime() + 0.5
			for _, ply in ipairs(player.GetAll()) do self:UpdateProgress(ply) end
		end
	end

	function QUEST:OnPickup(ent, ply)
		if ent:GetClass() ~= "gmeat_cell" then return false end
		ply.GmeatCarried = (ply.GmeatCarried or 0) + 1
		ply:EmitSound("items/battery_pickup.wav")
		self:UpdateProgress(ply)
		return true
	end

	function QUEST:InteractInfo(ent, ply)
		if ent ~= self.generator then return end
		if (ply.GmeatCarried or 0) > 0 then
			return 2, "Install power cells"
		end
		return nil, "Generator: find power cells first"
	end

	function QUEST:InteractDone(ent, ply)
		if ent ~= self.generator or (ply.GmeatCarried or 0) <= 0 then return end
		ply.GmeatInstalled = (ply.GmeatInstalled or 0) + ply.GmeatCarried
		ply.GmeatCarried = 0
		ent:EmitSound("ambient/energy/zap" .. math.random(1, 3) .. ".wav")
		self:UpdateProgress(ply)
		if ply.GmeatInstalled >= self.needed then
			GAMEMODE:EndRound(ply, "They got the generator running.")
		else
			GAMEMODE:Announce("cell_installed", ply:Nick(), ply.GmeatInstalled, self.needed)
		end
	end

	function QUEST:DropCells(ply)
		local count = ply.GmeatCarried or 0
		ply.GmeatCarried = 0
		for i = 1, count do
			local offset = Vector(math.cos(i * 2.1), math.sin(i * 2.1), 0) * 24
			local floor = GAMEMODE:FindFloorBelow(ply:GetPos() + offset)
			if floor then
				local cell = ents.Create("gmeat_cell")
				cell:SetPos(floor)
				cell:Spawn()
				GAMEMODE:PlaceOnFloor(cell, floor)
			end
		end
		self:UpdateProgress(ply)
	end

	function QUEST:PlayerDeath(ply)
		self:DropCells(ply)
	end

	function QUEST:PlayerDisconnected(ply)
		self:DropCells(ply)
	end

	function QUEST:GetMarkers(list)
		if IsValid(self.generator) then
			list[#list + 1] = {
				type = GMEAT_MARKER_OBJECTIVE,
				pos = self.generator:GetPos() + Vector(0, 0, 50),
				color = self.Color,
				label = "Generator",
				hud = true,
			}
		end
		for _, cell in ipairs(ents.FindByClass("gmeat_cell")) do
			list[#list + 1] = {
				type = GMEAT_MARKER_PROXIMITY,
				pos = cell:GetPos(),
				color = CELL_COLOR,
				label = "",
			}
		end
	end
end

GM:RegisterQuest(QUEST)
