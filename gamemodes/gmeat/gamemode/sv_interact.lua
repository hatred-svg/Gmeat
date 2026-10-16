GM.Pickups = GM.Pickups or {}
GM.Interactables = GM.Interactables or {}

local PICKUP_RADIUS = 44
local USE_RANGE = 110

function GM:SetHoldBar(ply, startTime, endTime, label)
	ply:SetNWFloat("GmeatHoldStart", startTime)
	ply:SetNWFloat("GmeatHoldEnd", endTime)
	ply:SetNWString("GmeatHoldLabel", label or "")
end

function GM:ClearHoldBar(ply)
	ply:SetNWFloat("GmeatHoldStart", 0)
	ply:SetNWFloat("GmeatHoldEnd", 0)
end

function GM:ClearHold(ply, completed)
	local hold = ply.GmeatHold
	if hold and hold.sound and not completed and IsValid(hold.ent) then
		hold.ent:StopSound(hold.sound.path)
	end
	ply.GmeatHold = nil
	self:ClearHoldBar(ply)
end

local function holdSound(hold, now)
	local snd = hold.sound
	if not snd or now < (hold.nextSound or 0) or not IsValid(hold.ent) then return end
	hold.ent:EmitSound(snd.path, snd.level or 75)
	hold.nextSound = snd.repeatEvery and (now + snd.repeatEvery) or math.huge
end

local function setHint(ply, text)
	text = text or ""
	if ply.GmeatHint ~= text then
		ply.GmeatHint = text
		ply:SetNWString("GmeatHint", text)
	end
end

function GM:FindInteractTarget(ply)
	local eye = ply:EyePos()
	local aim = ply:GetAimVector()
	local best, bestDist, bestDur, bestLabel, bestSound
	local press, pressDist, pressLabel
	for ent in pairs(self.Interactables) do
		if not IsValid(ent) then
			self.Interactables[ent] = nil
		else
			local center = ent:WorldSpaceCenter()
			local dist = eye:Distance(center)
			local instant = ent.GmeatInteractPress
			local nearer
			if instant then nearer = not pressDist or dist < pressDist else nearer = not bestDist or dist < bestDist end
			if dist < USE_RANGE and nearer then
				local dir = (center - eye):GetNormalized()
				if aim:Dot(dir) > (ent.GmeatInteractAim or 0.55) or dist < (instant and 30 or 50) then
					local tr = util.TraceLine({
						start = eye,
						endpos = center,
						filter = function(e) return e:GetClass() == "sector75_room_entity" end,
						mask = MASK_SOLID,
					})
					if not tr.Hit then
						local dur, label, snd = ent:GmeatInteractInfo(ply)
						if label and dur == 0 then
							press, pressDist, pressLabel = ent, dist, label
						elseif label then
							best, bestDist, bestDur, bestLabel, bestSound = ent, dist, dur, label, snd
						end
					end
				end
			end
		end
	end
	if best then return best, bestDur, bestLabel, bestSound end
	if press then return press, 0, pressLabel end
end

hook.Add("KeyPress", "Gmeat_InteractPress", function(ply, key)
	if key == IN_USE then ply.GmeatUsePressed = true end
end)

function GM:InteractThink()
	local now = CurTime()
	local active = self:GetRoundState() == GMEAT_ACTIVE
	for _, ply in ipairs(player.GetAll()) do
		if not ply:Alive() or ply:IsFrozen() then
			if ply.GmeatHold then self:ClearHold(ply) end
			ply.GmeatUsePressed = nil
			setHint(ply, nil)
		else
			if active then
				local pp = ply:GetPos()
				for ent in pairs(self.Pickups) do
					if not IsValid(ent) then
						self.Pickups[ent] = nil
					elseif not ent.GmeatTaken then
						local ep = ent:GetPos()
						if math.abs(ep.z - pp.z) < 72 and GMEAT.Dist2DSqr(ep, pp) < PICKUP_RADIUS * PICKUP_RADIUS then
							if self:QuestCall("OnPickup", ent, ply) then
								ent.GmeatTaken = true
								if IsValid(ent) then ent:Remove() end
							end
						end
					end
				end
			end

			local target, dur, label, snd = self:FindInteractTarget(ply)
			local pressed = ply.GmeatUsePressed
			ply.GmeatUsePressed = nil
			if target and dur == 0 then
				setHint(ply, "E: " .. label)
				if pressed and now >= (ply.GmeatNextPress or 0) then
					ply.GmeatNextPress = now + (target.GmeatInteractCooldown or 0.5)
					target:GmeatInteractDone(ply)
				end
			elseif target and dur then
				setHint(ply, "Hold E: " .. label)
			else
				setHint(ply, label)
			end

			local hold = ply.GmeatHold
			if dur == 0 or not target or not dur or not ply:KeyDown(IN_USE) then
				if hold then self:ClearHold(ply) end
			elseif not hold or hold.ent ~= target then
				if hold then self:ClearHold(ply) end
				ply.GmeatHold = { ent = target, start = now, duration = dur, sound = snd }
				self:SetHoldBar(ply, now, now + dur, label)
				holdSound(ply.GmeatHold, now)
			elseif now >= hold.start + hold.duration then
				self:ClearHold(ply, true)
				target:GmeatInteractDone(ply)
			else
				holdSound(hold, now)
			end
		end
	end
end

function GM:QuestCall(name, ...)
	local quest = self.ActiveQuest
	if quest and quest[name] and self:GetRoundState() == GMEAT_ACTIVE then
		return quest[name](quest, ...)
	end
end
