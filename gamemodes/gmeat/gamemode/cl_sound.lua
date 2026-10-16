local cvAmbient = CreateClientConVar("gmeat_ambient_volume", tostring(GMEAT.Sounds.AmbientVolume or 0.6), true, false,
	"Volume of the Gmeat map ambience (0 = off).", 0, 1)

GMEAT.AmbientChannel = GMEAT.AmbientChannel or nil
local amb = { pos = 0, loading = false, nextCheck = 0 }

local function startAmbient()
	if amb.loading or IsValid(GMEAT.AmbientChannel) or not GMEAT.Sounds.Ambient or cvAmbient:GetFloat() <= 0 then return end
	amb.loading = true
	sound.PlayFile("sound/" .. GMEAT.Sounds.Ambient, "noplay", function(channel, errId, errName)
		amb.loading = false
		if not IsValid(channel) then
			MsgC(Color(255, 120, 80), "[Gmeat] couldn't play the ambience (" .. tostring(errName or errId) .. ")\n")
			return
		end
		if IsValid(GMEAT.AmbientChannel) then channel:Stop() return end
		GMEAT.AmbientChannel = channel
		channel:EnableLooping(true)
		channel:SetVolume(cvAmbient:GetFloat())
		if amb.pos > 0 then channel:SetTime(amb.pos) end
		channel:Play()
	end)
end

local function keepAmbientPlaying()
	if cvAmbient:GetFloat() <= 0 then return end
	local ch = GMEAT.AmbientChannel
	if not IsValid(ch) then
		GMEAT.AmbientChannel = nil
		startAmbient()
	elseif ch:GetState() == GMOD_CHANNEL_STOPPED then
		ch:SetTime(amb.pos)
		ch:Play()
	end
end

hook.Add("Think", "Gmeat_AmbientWatch", function()
	local now = RealTime()
	if now < amb.nextCheck then return end
	amb.nextCheck = now + 0.5
	local ch = GMEAT.AmbientChannel
	if IsValid(ch) and ch:GetState() == GMOD_CHANNEL_PLAYING then
		amb.pos = ch:GetTime()
	else
		keepAmbientPlaying()
	end
end)

hook.Add("InitPostEntity", "Gmeat_Ambient", startAmbient)
hook.Add("PostCleanupMap", "Gmeat_Ambient", function()
	timer.Simple(0.1, keepAmbientPlaying)
end)
if IsValid(LocalPlayer()) then startAmbient() end

cvars.AddChangeCallback("gmeat_ambient_volume", function(_, _, new)
	local v = tonumber(new) or 0
	if IsValid(GMEAT.AmbientChannel) then
		GMEAT.AmbientChannel:SetVolume(v)
	elseif v > 0 then
		startAmbient()
	end
end, "Gmeat_Ambient")

local cvLowHealth = CreateClientConVar("gmeat_lowhealth_volume", tostring(GMEAT.Sounds.LowHealthVolume or 0.8), true, false,
	"Volume of the low-health sound (0 = off).", 0, 1)

GMEAT.LowHealthChannel = GMEAT.LowHealthChannel or nil
local low = { level = 0, loading = false }

local function lowHealthWanted()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() or not GMEAT.Sounds.LowHealth then return false end
	return ply:Health() <= math.max(ply:GetMaxHealth(), 1) * (GMEAT.Sounds.LowHealthBelow or 0.25)
end

local function startLowHealth()
	if low.loading or IsValid(GMEAT.LowHealthChannel) then return end
	low.loading = true
	sound.PlayFile("sound/" .. GMEAT.Sounds.LowHealth, "noplay", function(channel, errId, errName)
		low.loading = false
		if not IsValid(channel) then
			MsgC(Color(255, 120, 80), "[Gmeat] couldn't play the low-health sound (" .. tostring(errName or errId) .. ")\n")
			return
		end
		if IsValid(GMEAT.LowHealthChannel) then channel:Stop() return end
		GMEAT.LowHealthChannel = channel
		channel:EnableLooping(true)
		channel:SetVolume(0)
	end)
end

hook.Add("Think", "Gmeat_LowHealthSound", function()
	local want = lowHealthWanted() and cvLowHealth:GetFloat() > 0
	low.level = math.Approach(low.level, want and 1 or 0, FrameTime() * (want and 1 / 0.6 or 1 / 1.2))
	local ch = GMEAT.LowHealthChannel
	if want and not IsValid(ch) then
		GMEAT.LowHealthChannel = nil
		startLowHealth()
		return
	end
	if not IsValid(ch) then return end
	ch:SetVolume(low.level * cvLowHealth:GetFloat())
	local state = ch:GetState()
	if low.level > 0 and state ~= GMOD_CHANNEL_PLAYING then
		ch:Play()
	elseif low.level <= 0 and state == GMOD_CHANNEL_PLAYING then
		ch:Pause()
	end
end)

local MAX_WAIT = 4
local MAX_WAIT_PERSONAL = 8
local narrator = { busyUntil = 0, queue = {} }

local function lineLength(path)
	local d = GMEAT.NarratorDurations and GMEAT.NarratorDurations[path]
	if d then return d end
	d = SoundDuration(path)
	return (d and d > 0) and d or 3
end

local function playNow(path)
	surface.PlaySound(path)
	narrator.busyUntil = RealTime() + lineLength(path) + 0.15
end

function GM:PlayNarrator(path, personal)
	if not path or path == "" then return end
	if RealTime() >= narrator.busyUntil and #narrator.queue == 0 then
		playNow(path)
		return
	end
	local item = { path = path, at = RealTime(), personal = personal }
	local pos = #narrator.queue + 1
	if personal then
		pos = 1
		while pos <= #narrator.queue and narrator.queue[pos].personal do pos = pos + 1 end
	end
	table.insert(narrator.queue, pos, item)
end

hook.Add("Think", "Gmeat_NarratorQueue", function()
	if #narrator.queue == 0 or RealTime() < narrator.busyUntil then return end
	while #narrator.queue > 0 do
		local item = table.remove(narrator.queue, 1)
		if RealTime() - item.at <= (item.personal and MAX_WAIT_PERSONAL or MAX_WAIT) then
			playNow(item.path)
			return
		end
	end
end)

net.Receive("Gmeat_Narrate", function()
	GAMEMODE:PlayNarrator(net.ReadString(), true)
end)
