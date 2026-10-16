local HIDDEN = {
	CHudHealth = true,
	CHudBattery = true,
	CHudAmmo = true,
	CHudSecondaryAmmo = true,
	CHudWeaponSelection = true,
	CHudSuitPower = true,
	CHudDamageIndicator = true,
	CHudPoisonDamageIndicator = true,
}

hook.Add("HUDShouldDraw", "Gmeat_HideDefaultHUD", function(name)
	if HIDDEN[name] then return false end
end)

local HUD = GMEAT.HUD
local WHITE = HUD.Text
local DIM = HUD.TextDim
local LOW = Color(255, 90, 80)
local WARN = Color(255, 180, 70)

local function localize(name)
	if string.sub(name, 1, 1) == "#" then return language.GetPhrase(name) end
	return name
end

local function weaponName(wep)
	local name = wep:GetPrintName()
	if not name or name == "" then name = wep:GetClass() end
	return localize(name)
end

local function text(str, font, x, y, col, ax, ay)
	draw.SimpleTextOutlined(str, font, x, y, col, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP, 1, Color(0, 0, 0, col.a * 0.8))
end

local function fitText(str, font, maxW)
	surface.SetFont(font)
	if surface.GetTextSize(str) <= maxW then return str end
	while #str > 1 do
		local last = utf8 and utf8.offset and utf8.offset(str, -1) or #str
		str = string.sub(str, 1, last - 1)
		if surface.GetTextSize(str .. "...") <= maxW then break end
	end
	return str .. "..."
end

local plateMat = Material(HUD.Plate)

local function plateCapWidth(w, h)
	return math.min(math.floor(h * HUD.PlateAspect * HUD.PlateCap + 0.5), math.floor(w / 2))
end

local function drawPlate(x, y, w, h, tint, alpha)
	x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
	local cap = HUD.PlateCap
	local capW = plateCapWidth(w, h)
	surface.SetMaterial(plateMat)
	if tint then surface.SetDrawColor(tint.r, tint.g, tint.b, alpha or 255) else surface.SetDrawColor(255, 255, 255, alpha or 255) end
	surface.DrawTexturedRectUV(x, y, capW, h, 0, 0, cap, 1)
	surface.DrawTexturedRectUV(x + w - capW, y, capW, h, 1 - cap, 0, 1, 1)
	local midW = w - 2 * capW
	if midW <= 0 then return end
	local native = h * HUD.PlateAspect * (1 - 2 * cap)
	local n = math.max(1, math.floor(midW / native + 0.5))
	for i = 0, n - 1 do
		local sx0 = x + capW + math.floor(midW * i / n)
		local sx1 = x + capW + math.floor(midW * (i + 1) / n)
		local u0, u1 = cap, 1 - cap
		if i % 2 == 1 then u0, u1 = u1, u0 end
		surface.DrawTexturedRectUV(sx0, y, sx1 - sx0, h, u0, 0, u1, 1)
	end
end

local function plateInner(x, w, h)
	local capW = plateCapWidth(w, h)
	return x + capW * 0.92, x + w - capW * 0.92
end

function GM:DrawHudPlate(x, y, w, h, tint, alpha) drawPlate(x, y, w, h, tint, alpha) end
function GM:HudPlateInner(x, w, h) return plateInner(x, w, h) end
function GM:HudPlateCapWidth(w, h) return plateCapWidth(w, h) end

local barFrame = Material(HUD.BarFrame)
local barFill = Material(HUD.BarFill)

function GM:DrawBloodBar(x, y, w, h, frac, alpha, pulse)
	local src = HUD.BarSource
	x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
	alpha = alpha or 255
	local k = h / src.h
	local capW = math.min(math.floor(src.cap * k + 0.5), math.floor(w / 2))
	local fx0, fx1 = x + math.floor(src.fillLeft * k), x + w - math.floor(src.fillRight * k)
	local fy0, fy1 = y + math.floor(src.fillTop * k), y + h - math.floor(src.fillBottom * k)

	local e = HUD.BarEmpty
	surface.SetDrawColor(e.r, e.g, e.b, e.a * alpha / 255)
	surface.DrawRect(fx0, fy0, fx1 - fx0, fy1 - fy0)
	frac = math.Clamp(frac or 0, 0, 1)
	local fw = math.floor((fx1 - fx0) * frac + 0.5)
	if fw > 0 then
		local glow = 1
		if pulse and pulse > 0 then glow = 1 - pulse * 0.45 * (0.5 + 0.5 * math.sin(CurTime() * 8)) end
		surface.SetMaterial(barFill)
		surface.SetDrawColor(255 * glow, 255 * glow, 255 * glow, alpha)
		surface.DrawTexturedRectUV(fx0, fy0, fw, fy1 - fy0, 0, 0, frac, 1)
	end

	local cu = src.cap / src.w
	surface.SetMaterial(barFrame)
	surface.SetDrawColor(255, 255, 255, alpha)
	surface.DrawTexturedRectUV(x, y, capW, h, 0, 0, cu, 1)
	surface.DrawTexturedRectUV(x + capW, y, w - 2 * capW, h, cu, 0, 1 - cu, 1)
	surface.DrawTexturedRectUV(x + w - capW, y, capW, h, 1 - cu, 0, 1, 1)
end

local shownHealth = 100

local function drawHealth(ply, s)
	local w, h = 330 * s, 110 * s
	local x, y = 24 * s, ScrH() - h - 20 * s
	local hp = math.max(ply:Health(), 0)
	local maxHp = math.max(ply:GetMaxHealth(), 1)
	shownHealth = Lerp(FrameTime() * 10, shownHealth, hp)

	local col = WHITE
	if hp <= maxHp * 0.25 then
		col = (math.sin(CurTime() * 8) > 0) and LOW or WHITE
	end
	drawPlate(x, y, w, h)
	local x0, x1 = plateInner(x, w, h)
	text("HEALTH", "GmeatSmall", x0, y + h * 0.17, DIM)
	text(tostring(hp), "GmeatHuge", x0, y + h * 0.56, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local bx, bh = x0 + 100 * s, 24 * s
	GAMEMODE:DrawBloodBar(bx, y + h * 0.56 - bh / 2 + 4 * s, x1 - bx, bh, shownHealth / maxHp, 255, hp <= maxHp * 0.25 and 1 or 0)
end

local function ammoInfo(ply, wep)
	if wep.DrawAmmo == false then return end
	if wep.CustomAmmoDisplay then
		local d = wep:CustomAmmoDisplay()
		if d then
			if d.Draw == false then return end
			return d.PrimaryClip, wep:GetMaxClip1(), d.PrimaryAmmo, d.SecondaryAmmo
		end
	end
	local clip, maxClip = wep:Clip1(), wep:GetMaxClip1()
	local primaryType = wep:GetPrimaryAmmoType()
	local reserve = primaryType >= 0 and ply:GetAmmoCount(primaryType) or nil
	local secondaryType = wep:GetSecondaryAmmoType()
	local secondary = secondaryType >= 0 and ply:GetAmmoCount(secondaryType) or nil
	if clip < 0 then clip = nil end
	return clip, maxClip, reserve, secondary
end

local function drawAmmo(ply, s)
	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) then return end

	local w, h = 360 * s, 110 * s
	local x, y = ScrW() - w - 24 * s, ScrH() - h - 20 * s
	drawPlate(x, y, w, h)
	local x0, x1 = plateInner(x, w, h)

	local clip, maxClip, reserve, secondary = ammoInfo(ply, wep)
	local altW = 0
	if secondary and secondary > 0 then
		local alt = "ALT  " .. secondary
		text(alt, "GmeatSmall", x1, y + h * 0.17, WARN, TEXT_ALIGN_RIGHT)
		surface.SetFont("GmeatSmall")
		altW = surface.GetTextSize(alt) + 12 * s
	end
	text(fitText(string.upper(weaponName(wep)), "GmeatSmall", x1 - x0 - altW), "GmeatSmall", x0, y + h * 0.17, DIM)

	local cy = y + h * 0.56
	if clip then
		local low = maxClip and maxClip > 0 and clip <= maxClip * 0.25
		local col = clip == 0 and LOW or (low and WARN or WHITE)
		text(tostring(clip), "GmeatHuge", x0, cy, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetFont("GmeatHuge")
		local cw = surface.GetTextSize(tostring(clip))
		local textEnd = x0 + cw
		if reserve then
			local r = "/ " .. reserve
			text(r, "GmeatMedium", x0 + cw + 8 * s, cy + 8 * s, reserve == 0 and LOW or DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			surface.SetFont("GmeatMedium")
			textEnd = textEnd + 8 * s + surface.GetTextSize(r)
		end
		if maxClip and maxClip > 0 then
			local bh = 24 * s
			local bx = math.max(textEnd + 12 * s, x1 - 120 * s)
			if x1 - bx >= 40 * s then
				GAMEMODE:DrawBloodBar(bx, cy - bh / 2 + 4 * s, x1 - bx, bh, clip / maxClip, 255, low and 1 or 0)
			end
		end
	elseif reserve then
		text(tostring(reserve), "GmeatHuge", x0, cy, reserve == 0 and LOW or WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

local SHOW_TIME = 1.6
local listShownUntil = 0
local lastWeapon

local function sortedWeapons(ply)
	local list = {}
	for _, wep in ipairs(ply:GetWeapons()) do
		if IsValid(wep) then list[#list + 1] = wep end
	end
	table.sort(list, function(a, b)
		if a:GetSlot() ~= b:GetSlot() then return a:GetSlot() < b:GetSlot() end
		if a:GetSlotPos() ~= b:GetSlotPos() then return a:GetSlotPos() < b:GetSlotPos() end
		return a:GetClass() < b:GetClass()
	end)
	return list
end

local function switchTo(ply, wep)
	local current = ply:GetActiveWeapon()
	if IsValid(current) and current ~= wep then lastWeapon = current end
	input.SelectWeapon(wep)
	listShownUntil = CurTime() + SHOW_TIME
	surface.PlaySound(GMEAT.Sounds.WeaponScroll or "common/wpn_moveselect.wav")
end

hook.Add("PlayerBindPress", "Gmeat_WeaponSwitch", function(ply, bind, pressed)
	if not pressed or not ply:Alive() then return end
	if GAMEMODE.IsMinimapOpen and GAMEMODE:IsMinimapOpen() then return end

	local isNext = string.find(bind, "invnext", 1, true)
	local isPrev = string.find(bind, "invprev", 1, true)
	local slot = tonumber(string.match(bind, "^slot(%d+)"))
	local isLast = string.find(bind, "lastinv", 1, true)
	if not (isNext or isPrev or slot or isLast) then return end

	local list = sortedWeapons(ply)
	if #list == 0 then return true end
	local current = ply:GetActiveWeapon()
	local index = 0
	for i, wep in ipairs(list) do
		if wep == current then index = i break end
	end

	if isNext then
		switchTo(ply, list[index % #list + 1])
	elseif isPrev then
		switchTo(ply, list[index <= 1 and #list or index - 1])
	elseif slot then
		local inSlot = {}
		for _, wep in ipairs(list) do
			if wep:GetSlot() + 1 == slot then inSlot[#inSlot + 1] = wep end
		end
		if #inSlot > 0 then
			local pick = inSlot[1]
			for i, wep in ipairs(inSlot) do
				if wep == current then pick = inSlot[i % #inSlot + 1] break end
			end
			switchTo(ply, pick)
		end
	elseif isLast then
		if IsValid(lastWeapon) and lastWeapon:GetOwner() == ply then switchTo(ply, lastWeapon) end
	end
	return true
end)

local function drawWeaponList(ply, s)
	if CurTime() > listShownUntil then return end
	local list = sortedWeapons(ply)
	if #list == 0 then return end
	local alpha = math.Clamp((listShownUntil - CurTime()) / 0.3, 0, 1)
	local current = ply:GetActiveWeapon()
	local rowH, w, gap = 46 * s, 300 * s, 2 * s
	local x = ScrW() - w - 24 * s
	local y = ScrH() / 2 - (#list * (rowH + gap)) / 2

	for i, wep in ipairs(list) do
		local ry = y + (i - 1) * (rowH + gap)
		local selected = wep == current
		local rx = selected and x - 16 * s or x
		drawPlate(rx, ry, w, rowH, selected and color_white or Color(150, 140, 140), (selected and 255 or 200) * alpha)
		local x0, x1 = plateInner(rx, w, rowH)
		local a = 255 * alpha
		local col = selected and Color(WHITE.r, WHITE.g, WHITE.b, a) or Color(DIM.r, DIM.g, DIM.b, a * 0.85)
		local slotCol = selected and Color(HUD.RedBright.r, HUD.RedBright.g, HUD.RedBright.b, a) or Color(HUD.Red.r, HUD.Red.g, HUD.Red.b, a)
		local cy = ry + rowH / 2
		text(tostring(wep:GetSlot() + 1), "GmeatSmall", x0, cy, slotCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		local font = selected and "GmeatMedium" or "GmeatSmall"
		text(fitText(weaponName(wep), font, x1 - x0 - 24 * s), font, x0 + 24 * s, cy, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

function GM:DrawPlayerHUD()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end
	local s = ScrH() / 1080
	drawHealth(ply, s)
	drawAmmo(ply, s)
	drawWeaponList(ply, s)
end
