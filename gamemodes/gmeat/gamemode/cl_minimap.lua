local cvRotate = CreateClientConVar("gmeat_minimap_rotate", "0", true, false, "Rotate the minimap with your view.")
local cvCorner = CreateClientConVar("gmeat_minimap_corner", "0", true, false, "Always show a small minimap in the corner.")

local mapOpen = false
local zoomMul = 1

concommand.Add("+menu", function() mapOpen = true zoomMul = 1 reportedBlank = false end)
concommand.Add("-menu", function() mapOpen = false end)

hook.Add("PlayerBindPress", "Gmeat_MinimapZoom", function(ply, bind, pressed)
	if not mapOpen or not pressed then return end
	if string.find(bind, "invprev", 1, true) then
		zoomMul = math.min(zoomMul * 1.25, 6)
		return true
	elseif string.find(bind, "invnext", 1, true) then
		zoomMul = math.max(zoomMul / 1.25, 0.5)
		return true
	end
end)

local COL_ROOM = Color(92, 62, 60)
local COL_VISITED = Color(138, 82, 78)
local COL_CURRENT = Color(205, 42, 34)
local COL_START = Color(70, 125, 85)
local COL_DOOR = Color(255, 215, 80)

local quad = { { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 } }

local function fillQuad(x1, y1, x2, y2, x3, y3, x4, y4)
	if (x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1) < 0 then
		x2, y2, x4, y4 = x4, y4, x2, y2
	end
	quad[1].x, quad[1].y = x1, y1
	quad[2].x, quad[2].y = x2, y2
	quad[3].x, quad[3].y = x3, y3
	quad[4].x, quad[4].y = x4, y4
	surface.DrawPoly(quad)
end

local tri = { { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 } }
local function fillTri(x1, y1, x2, y2, x3, y3)
	if (x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1) < 0 then
		x2, y2, x3, y3 = x3, y3, x2, y2
	end
	tri[1].x, tri[1].y = x1, y1
	tri[2].x, tri[2].y = x2, y2
	tri[3].x, tri[3].y = x3, y3
	surface.DrawPoly(tri)
end

local function lerpColor(t, a, b)
	return Lerp(t, a.r, b.r), Lerp(t, a.g, b.g), Lerp(t, a.b, b.b)
end

function GM:MinimapFitScale(w, h)
	local ply = LocalPlayer()
	if not IsValid(ply) then return 0.09 end
	local pp = ply:GetPos()
	local far = 400
	for _, room in ipairs(self.MapRoomList) do
		local d = math.sqrt((room.center.x - pp.x) ^ 2 + (room.center.y - pp.y) ^ 2) + room.extent * 0.75
		if d > far then far = d end
	end
	return math.Clamp((math.min(w, h) / 2 - 24) / far, 0.03, 0.25)
end

function GM:DrawMinimap(x, y, w, h, scale, rotate)
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	local pp = ply:GetPos()
	local yaw = ply:EyeAngles().y
	local cx, cy = x + w / 2, y + h / 2
	local r = rotate and math.rad(90 - yaw) or 0
	local cr, sr = math.cos(r), math.sin(r)

	local function toScreen(wx, wy)
		local dx, dy = wx - pp.x, wy - pp.y
		return cx + (dx * cr - dy * sr) * scale, cy - (dx * sr + dy * cr) * scale
	end

	render.SetScissorRect(x, y, x + w, y + h, true)
	draw.NoTexture()

	local now = CurTime()
	local current = self.CurrentRoom
	local drawn = 0

	for _, room in ipairs(self.MapRoomList) do
		local sx, sy = toScreen(room.center.x, room.center.y)
		local reach = room.extent * scale + 8
		if sx + reach > x and sx - reach < x + w and sy + reach > y and sy - reach < y + h then
			drawn = drawn + 1
			local base = COL_ROOM
			if room == current then base = COL_CURRENT
			elseif room.isStart then base = COL_START
			elseif self.Visited[room.id] then base = COL_VISITED end

			local sameFloor = pp.z > room.zmin - 64 and pp.z < room.zmax + 32
			local alpha = sameFloor and 240 or 110
			local age = math.Clamp((now - room.born) / 0.6, 0, 1)
			local rr, gg, bb = lerpColor(age, color_white, base)
			surface.SetDrawColor(rr, gg, bb, alpha * (0.3 + 0.7 * age))

			for _, s in ipairs(room.strips) do
				local ax, ay = toScreen(s[1], s[2])
				local bx, by = toScreen(s[3], s[4])
				local qx, qy = toScreen(s[5], s[6])
				local dx, dy = toScreen(s[7], s[8])
				fillQuad(ax, ay, bx, by, qx, qy, dx, dy)
			end
		end
	end

	local doorSize = math.Clamp(scale * 40, 3, 7)
	surface.SetDrawColor(COL_DOOR)
	for _, door in pairs(self.MapDoors) do
		if door.state == 0 then
			local sx, sy = toScreen(door.pos.x, door.pos.y)
			if sx > x and sx < x + w and sy > y and sy < y + h then
				surface.DrawRect(sx - doorSize / 2, sy - doorSize / 2, doorSize, doorSize)
			end
		end
	end

	for _, m in ipairs(self.Markers) do
		local pos = self:MarkerPos(m)
		local sx, sy = toScreen(pos.x, pos.y)
		local col = m.color
		if m.type == GMEAT_MARKER_AREA then
			local rad = math.max(m.radius * scale, 6)
			local pulse = 150 + math.sin(now * 3) * 80
			surface.DrawCircle(sx, sy, rad, col.r, col.g, col.b, pulse)
			surface.DrawCircle(sx, sy, rad - 1, col.r, col.g, col.b, pulse * 0.6)
			draw.SimpleTextOutlined(m.label, "GmeatSmall", sx, sy, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
		elseif m.type == GMEAT_MARKER_PROXIMITY then
			if pos:DistToSqr(pp) < 1200 * 1200 then
				surface.SetDrawColor(col.r, col.g, col.b, 230)
				surface.DrawRect(sx - 3, sy - 3, 6, 6)
			end
		else
			local pad = 14
			local px, py = math.Clamp(sx, x + pad, x + w - pad), math.Clamp(sy, y + pad, y + h - pad)
			local size = 7
			draw.NoTexture()
			surface.SetDrawColor(0, 0, 0, 220)
			fillQuad(px, py - size - 2, px + size + 2, py, px, py + size + 2, px - size - 2, py)
			surface.SetDrawColor(col.r, col.g, col.b, 255)
			fillQuad(px, py - size, px + size, py, px, py + size, px - size, py)
			if m.label ~= "" then
				draw.SimpleTextOutlined(m.label, "GmeatSmall", px, py - size - 4, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, color_black)
			end
		end
	end

	local dirX, dirY
	if rotate then
		dirX, dirY = 0, -1
	else
		local yr = math.rad(yaw)
		dirX, dirY = math.cos(yr), -math.sin(yr)
	end
	local perpX, perpY = -dirY, dirX
	local c = GMEAT.HUD.Text
	draw.NoTexture()
	surface.SetDrawColor(0, 0, 0, 255)
	fillTri(cx + dirX * 13, cy + dirY * 13, cx - dirX * 8 + perpX * 9, cy - dirY * 8 + perpY * 9, cx - dirX * 8 - perpX * 9, cy - dirY * 8 - perpY * 9)
	surface.SetDrawColor(c.r, c.g, c.b, 255)
	fillTri(cx + dirX * 10, cy + dirY * 10, cx - dirX * 6 + perpX * 7, cy - dirY * 6 + perpY * 7, cx - dirX * 6 - perpX * 7, cy - dirY * 6 - perpY * 7)

	render.SetScissorRect(0, 0, 0, 0, false)
	return drawn
end

local function debugBlankMap(scale)
	local ply = LocalPlayer()
	print(string.format("[Gmeat] Minimap drew 0 of %d rooms. Player at %s, scale %.4f", #GAMEMODE.MapRoomList, tostring(ply:GetPos()), scale))
	for i, room in ipairs(GAMEMODE.MapRoomList) do
		if i > 5 then break end
		print(string.format("  room %d: pos %s yaw %.0f extent %.0f strips %d zmin %.0f zmax %.0f", room.id, tostring(room.pos), room.yaw, room.extent, #room.strips, room.zmin, room.zmax))
	end
end
local reportedBlank = false

local function drawPanel(x, y, w, h)
	surface.SetDrawColor(GMEAT.HUD.Panel.r, GMEAT.HUD.Panel.g, GMEAT.HUD.Panel.b, 225)
	surface.DrawRect(x, y, w, h)
	surface.SetDrawColor(GMEAT.HUD.Red.r, GMEAT.HUD.Red.g, GMEAT.HUD.Red.b, 90)
	surface.DrawOutlinedRect(x, y, w, h, 2)
end

function GM:DrawMinimapHUD()
	if mapOpen then
		local size = math.floor(math.min(ScrW(), ScrH()) * 0.82)
		local x, y = math.floor((ScrW() - size) / 2), math.floor((ScrH() - size) / 2)
		drawPanel(x, y, size, size)
		local scale = math.Clamp(GAMEMODE:MinimapFitScale(size - 8, size - 8) * zoomMul, 0.02, 0.5)
		local drawn = GAMEMODE:DrawMinimap(x + 4, y + 4, size - 8, size - 8, scale, cvRotate:GetBool())
		if drawn == 0 and #GAMEMODE.MapRoomList > 0 then
			draw.SimpleTextOutlined("No rooms in view - diagnostic printed to console", "GmeatSmall", x + size / 2, y + size - 40, Color(255, 120, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, color_black)
			if not reportedBlank then reportedBlank = true debugBlankMap(scale) end
		end

		draw.SimpleTextOutlined("SECTOR 75", "GmeatMedium", x + 16, y + 12, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, color_black)
		draw.SimpleTextOutlined(#GAMEMODE.MapRoomList .. " rooms mapped", "GmeatSmall", x + 16, y + 44, Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, color_black)
		draw.SimpleTextOutlined("Mouse wheel: zoom (resets when reopened)    Yellow: unopened door", "GmeatSmall", x + size - 16, y + size - 14, Color(180, 180, 180), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, color_black)
	elseif cvCorner:GetBool() then
		local size = math.floor(ScrH() * 0.24)
		local x, y = ScrW() - size - 20, 20
		drawPanel(x, y, size, size)
		GAMEMODE:DrawMinimap(x + 2, y + 2, size - 4, size - 4, 0.06, cvRotate:GetBool())
	end
end

function GM:IsMinimapOpen()
	return mapOpen
end
