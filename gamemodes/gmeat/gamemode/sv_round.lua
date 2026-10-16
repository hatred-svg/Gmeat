function GM:SetRoundState(state, duration)
	self.RoundState = state
	SetGlobalInt("GmeatState", state)
	SetGlobalFloat("GmeatStateEnd", duration and (CurTime() + duration) or 0)
end

function GM:ChooseQuest()
	local forced = string.lower(string.Trim(GetConVar("gmeat_quest"):GetString()))
	if self.Quests[forced] then return self.Quests[forced] end
	local options = {}
	for _, id in ipairs(self.QuestOrder) do
		if id ~= self.LastQuestID or #self.QuestOrder == 1 then
			options[#options + 1] = id
		end
	end
	return self.Quests[options[math.random(#options)]]
end

function GM:ResetPlayerProgress(ply)
	ply:SetNWFloat("GmeatProgress", 0)
	ply:SetNWString("GmeatProgressText", "")
	ply:SetNWString("GmeatCarrying", "")
	ply:SetNWBool("GmeatInSite", false)
end

function GM:PlaceAllInStart()
	for _, ply in ipairs(player.GetAll()) do
		if ply:Alive() then
			local spot, yaw = self:GetStartSpot()
			if spot then
				ply:SetPos(spot + Vector(0, 0, 2))
				ply:SetEyeAngles(Angle(0, yaw, 0))
				ply:SetVelocity(-ply:GetVelocity())
			end
			ply:Freeze(self:GetRoundState() == GMEAT_PREP)
		end
	end
end

function GM:StartPrep()
	self:ApplySector75Settings()
	self:FinishQuest()

	local quest = self:ChooseQuest()
	self.PendingQuest = quest
	self.LastQuestID = quest.ID
	self.Overtime = false
	self.WarnedMinute = false
	self.Drops = {}

	SetGlobalString("GmeatQuest", quest.ID)
	SetGlobalEntity("GmeatWinner", NULL)
	SetGlobalBool("GmeatOvertime", false)
	for _, ply in ipairs(player.GetAll()) do
		self:ResetPlayerProgress(ply)
	end

	self:SetRoundState(GMEAT_PREP, GetConVar("gmeat_prep_time"):GetFloat())
	game.CleanUpMap(false)
	self:ResetPrebuild()
	timer.Simple(0.6, function()
		if GAMEMODE:GetRoundState() == GMEAT_PREP then GAMEMODE:PlaceAllInStart() end
	end)
	self:Announce("round_prep")
end

function GM:StartActive()
	local quest = self.PendingQuest or self:ChooseQuest()
	self.ActiveQuest = quest
	self.RoundStart = CurTime()
	if self.Prebuild and not self.Prebuild.placed then
		self.Prebuild.placed = true
		self:PlaceInSeparateRooms()
	end
	self:SetRoundState(GMEAT_ACTIVE, GetConVar("gmeat_round_time"):GetFloat())

	for _, ply in ipairs(player.GetAll()) do
		ply:Freeze(false)
	end

	self:BuildWeaponPool()
	self.NextDrop = CurTime() + GetConVar("gmeat_drop_first"):GetFloat()

	if quest.Start then quest:Start() end
	if quest.StartLineArgs then
		self:Announce(quest.StartLine, quest:StartLineArgs())
	else
		self:Announce(quest.StartLine)
	end
end

function GM:FinishQuest()
	local quest = self.ActiveQuest
	self.ActiveQuest = nil
	if quest and quest.Finish then quest:Finish() end
end

function GM:EndRound(winner, reason)
	local state = self:GetRoundState()
	if state ~= GMEAT_ACTIVE and state ~= GMEAT_PREP then return end

	self:FinishQuest()
	self:SetRoundState(GMEAT_POST, GetConVar("gmeat_post_time"):GetFloat())

	if IsValid(winner) then
		SetGlobalEntity("GmeatWinner", winner)
		self:Announce("round_win", winner:Nick(), reason or "")
	elseif reason then
		self:Announce("round_abort", reason)
	else
		self:Announce("round_draw")
	end

	if IsValid(winner) or not reason then
		for _, ply in ipairs(player.GetAll()) do
			self:Narrate(ply, ply == winner and GMEAT.Sounds.Win or GMEAT.Sounds.Lose)
		end
	end

	for _, ply in ipairs(player.GetAll()) do
		self:ClearHold(ply)
		ply:SetNWString("GmeatCarrying", "")
		if ply:Alive() then ply:GodEnable() end
	end
end

function GM:TimeUp()
	local best, bestProgress, tie = nil, 0, false
	for _, ply in ipairs(player.GetAll()) do
		local p = ply:GetNWFloat("GmeatProgress", 0)
		if p > bestProgress then
			best, bestProgress, tie = ply, p, false
		elseif p > 0 and p == bestProgress then
			tie = true
		end
	end
	if best and not tie then
		self:EndRound(best, "Most progress when time ran out.")
	else
		self:EndRound(nil)
	end
end

function GM:RoundThink()
	local state = self.RoundState or GMEAT_WAITING
	local now = CurTime()
	local players = player.GetCount()
	local minPlayers = GetConVar("gmeat_min_players"):GetInt()
	local stateEnd = GetGlobalFloat("GmeatStateEnd", 0)

	if state == GMEAT_WAITING then
		if players >= minPlayers and now >= (self.NextWaitCheck or 0) then
			self.NextWaitCheck = now + 2
			self:StartPrep()
		end

	elseif state == GMEAT_PREP then
		self:PrebuildThink()
		if now >= stateEnd then self:StartActive() end

	elseif state == GMEAT_ACTIVE then
		if players < minPlayers then
			self:EndRound(nil, "Not enough players.")
			return
		end
		local quest = self.ActiveQuest
		if quest and quest.Think then quest:Think() end
		if self:GetRoundState() ~= GMEAT_ACTIVE then return end

		self:DropsThink()

		local remaining = stateEnd - now
		if not self.WarnedMinute and remaining <= 60 and GetConVar("gmeat_round_time"):GetFloat() > 90 then
			self.WarnedMinute = true
			self:Announce("one_minute")
		end
		if remaining <= 0 then
			if quest and quest.InOvertime and quest:InOvertime() then
				if not self.Overtime then
					self.Overtime = true
					SetGlobalBool("GmeatOvertime", true)
					self:Announce("overtime")
				end
			else
				self:TimeUp()
			end
		end

	elseif state == GMEAT_POST then
		if now >= stateEnd then
			if players >= minPlayers then
				self:StartPrep()
			else
				self:SetRoundState(GMEAT_WAITING)
				for _, ply in ipairs(player.GetAll()) do
					if ply:Alive() and not ply.GmeatProtectUntil then ply:GodDisable() end
				end
				self:Announce("waiting")
			end
		end
	end
end
