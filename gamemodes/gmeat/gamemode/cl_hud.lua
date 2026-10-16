DEFINE_BASECLASS("gamemode_base")

local function createFonts()
	local s = ScrH() / 1080
	surface.CreateFont("GmeatHuge", { font = "Roboto", size = math.floor(54 * s), weight = 800 })
	surface.CreateFont("GmeatLarge", { font = "Roboto", size = math.floor(36 * s), weight = 800 })
	surface.CreateFont("GmeatMedium", { font = "Roboto", size = math.floor(26 * s), weight = 700 })
	surface.CreateFont("GmeatSmall", { font = "Roboto", size = math.floor(18 * s), weight = 600 })
end
createFonts()
hook.Add("OnScreenSizeChanged", "Gmeat_Fonts", createFonts)

local function localize(text)
	return (string.gsub(text, "#[%w_]+", function(token) return language.GetPhrase(token) end))
end

local announcement
local notice
local soundCache = {}

local function findVoiceFiles(key)
	if soundCache[key] then return soundCache[key] end
	local found = {}
	local names = { key }
	for i = 1, 5 do names[#names + 1] = key .. "_" .. i end
	for _, name in ipairs(names) do
		for _, ext in ipairs({ ".wav", ".mp3", ".ogg" }) do
			local path = "gmeat/vo/" .. name .. ext
			if file.Exists("sound/" .. path, "GAME") then found[#found + 1] = path end
		end
	end
	soundCache[key] = found
	return found
end

net.Receive("Gmeat_Announce", function()
	local key, text = net.ReadString(), net.ReadString()
	announcement = { text = text, start = CurTime(), duration = 4.5 }
	chat.AddText(GMEAT.HUD.RedBright, "[Gmeat] ", color_white, text)
	local files = findVoiceFiles(key)
	if #files > 0 then
		GAMEMODE:PlayNarrator(files[math.random(#files)])
	else
		local fallback = GMEAT.LineFallbackSounds[key] or GMEAT.DefaultAnnounceSound
		if fallback ~= "" then surface.PlaySound(fallback) end
	end
end)

net.Receive("Gmeat_Notify", function()
	notice = { text = localize(net.ReadString()), start = CurTime(), duration = 3.5 }
end)

local function box(x, y, w, h, alpha)
	local c = GMEAT.HUD.Panel
	surface.SetDrawColor(c.r, c.g, c.b, alpha or c.a)
	surface.DrawRect(x, y, w, h)
end

local function text(str, font, x, y, col, ax, ay)
	draw.SimpleTextOutlined(str, font, x, y, col or color_white, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP, 1, color_black)
end

local function fadeAlpha(item)
	local t = CurTime() - item.start
	if t > item.duration then return 0 end
	return math.Clamp(math.min(t / 0.2, (item.duration - t) / 0.6), 0, 1) * 255
end

local function formatTime(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local TOP_PLATE_H = 100
local function topBarRect(textW)
	local s = ScrH() / 1080
	local bh = TOP_PLATE_H * s
	local capW = GAMEMODE:HudPlateCapWidth(10000, bh)
	local bw = math.max(textW + 2 * capW * 0.92 + 28 * s, 380 * s)
	return (ScrW() - bw) / 2, 8 * s, bw, bh
end

local function drawTopBar(quest, state)
	local w = ScrW()
	local remaining = GetGlobalFloat("GmeatStateEnd", 0) - CurTime()
	local title, sub

	if state == GMEAT_WAITING then
		title = "WAITING FOR PLAYERS"
		sub = string.format("%d / %d players", player.GetCount(), GetConVar("gmeat_min_players"):GetInt())
	elseif state == GMEAT_PREP then
		title = (quest and string.upper(quest.Name) or "GMEAT") .. "  -  STARTING IN " .. math.max(0, math.ceil(remaining))
		sub = quest and quest:Describe() or ""
	elseif state == GMEAT_ACTIVE then
		local timer = GetGlobalBool("GmeatOvertime", false) and "OVERTIME" or formatTime(remaining)
		title = (quest and string.upper(quest.Name) or "GMEAT") .. "   " .. timer
		sub = quest and quest:Describe() or ""
	else
		local winner = GetGlobalEntity("GmeatWinner")
		title = IsValid(winner) and (winner:Nick() .. " WINS") or "ROUND OVER"
		sub = "Next round in " .. math.max(0, math.ceil(remaining))
	end

	surface.SetFont("GmeatLarge")
	local tw = surface.GetTextSize(title)
	surface.SetFont("GmeatSmall")
	local sw = surface.GetTextSize(sub)
	local s = ScrH() / 1080
	local x, y, bw, bh = topBarRect(math.max(tw, sw))
	GAMEMODE:DrawHudPlate(x, y, bw, bh)
	local col = quest and quest.Color or color_white
	if state == GMEAT_ACTIVE and remaining < 30 and not GetGlobalBool("GmeatOvertime", false) then
		col = (math.floor(CurTime() * 2) % 2 == 0) and Color(255, 80, 80) or col
	end
	text(title, "GmeatLarge", w / 2, y + bh * 0.39, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	text(sub, "GmeatSmall", w / 2, y + bh * 0.67, GMEAT.HUD.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function drawProgress(ply)
	local str = ply:GetNWString("GmeatProgressText", "")
	if str == "" then return end
	local s = ScrH() / 1080
	text(str, "GmeatMedium", ScrW() / 2, (8 + TOP_PLATE_H + 8) * s, Color(255, 235, 170), TEXT_ALIGN_CENTER)
end

local function drawAnnouncement()
	if announcement then
		local a = fadeAlpha(announcement)
		if a <= 0 then
			announcement = nil
		else
			draw.SimpleTextOutlined(announcement.text, "GmeatLarge", ScrW() / 2, ScrH() * 0.3, Color(255, 255, 255, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, a))
		end
	end
	if notice then
		local a = fadeAlpha(notice)
		if a <= 0 then
			notice = nil
		else
			draw.SimpleTextOutlined(notice.text, "GmeatMedium", ScrW() / 2, ScrH() * 0.36, Color(255, 120, 100, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, a))
		end
	end
end

local function drawHold(ply)
	local startT, endT = ply:GetNWFloat("GmeatHoldStart", 0), ply:GetNWFloat("GmeatHoldEnd", 0)
	local cx, cy = ScrW() / 2, ScrH() * 0.62
	if endT > startT and endT > 0 then
		local frac = math.Clamp((CurTime() - startT) / (endT - startT), 0, 1)
		local s = ScrH() / 1080
		local w, h = 300 * s, 40 * s
		GAMEMODE:DrawBloodBar(cx - w / 2, cy, w, h, frac)
		text(ply:GetNWString("GmeatHoldLabel", ""), "GmeatSmall", cx, cy - 4 * s, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		return
	end
	local hint = ply:GetNWString("GmeatHint", "")
	if ply:GetNWBool("GmeatInSite", false) then hint = "Hold E: Plant explosive" end
	if hint ~= "" then
		text(hint, "GmeatMedium", cx, cy, color_white, TEXT_ALIGN_CENTER)
	end
end

local function drawWaypoints(ply)
	if GAMEMODE:IsMinimapOpen() then return end
	local eye = ply:EyePos()
	for _, m in ipairs(GAMEMODE.Markers) do
		if m.hud then
			local pos = GAMEMODE:MarkerPos(m)
			local sp = pos:ToScreen()
			if sp.visible then
				local dist = math.floor(eye:Distance(pos) * 0.01905)
				local col = m.color
				draw.NoTexture()
				surface.SetDrawColor(col.r, col.g, col.b, 220)
				surface.DrawRect(sp.x - 4, sp.y - 4, 8, 8)
				text(m.label .. "  " .. dist .. "m", "GmeatSmall", sp.x, sp.y - 8, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			end
		end
	end
end

local function drawDeathAndProtection(ply)
	if not ply:Alive() then
		local left = ply:GetNWFloat("GmeatRespawnAt", 0) - CurTime()
		if left > 0 then
			text("Respawning in " .. math.ceil(left), "GmeatHuge", ScrW() / 2, ScrH() * 0.45, Color(255, 90, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		return
	end
	local protect = ply:GetNWFloat("GmeatProtectUntil", 0) - CurTime()
	if protect > 0 then
		text(string.format("Spawn protection %.1fs (ends if you shoot)", protect), "GmeatSmall", ScrW() / 2, ScrH() * 0.7, Color(255, 130, 115), TEXT_ALIGN_CENTER)
	end
	local carrying = ply:GetNWString("GmeatCarrying", "")
	if carrying ~= "" then
		local col = GMEAT.CarryColors[carrying] or color_white
		text("YOU HAVE THE " .. string.upper(carrying == "bomb" and "explosive" or carrying) .. " - everyone can see you", "GmeatMedium", ScrW() / 2, ScrH() * 0.78, col, TEXT_ALIGN_CENTER)
	end
end

function GM:HUDDrawTargetID()
end

function GM:AddDeathNotice()
end

function GM:DrawDeathNotice()
end

function GM:HUDPaint()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	local state = self:GetRoundState()
	local quest = self:GetActiveQuestTable()

	if state == GMEAT_ACTIVE then drawWaypoints(ply) end
	drawTopBar(quest, state)
	if state == GMEAT_ACTIVE then drawProgress(ply) end
	drawHold(ply)
	drawDeathAndProtection(ply)
	drawAnnouncement()

	self:DrawPlayerHUD()
	BaseClass.HUDPaint(self)
	self:DrawMinimapHUD()
end
