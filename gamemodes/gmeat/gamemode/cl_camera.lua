DEFINE_BASECLASS("gamemode_base")

local cvShake = CreateClientConVar("gmeat_camshake", "1", true, false, "Handheld camera shake strength (0 off, 1 normal, 2 double).", 0, 2)
local cvGrain = CreateClientConVar("gmeat_grain", "1", true, false, "Film grain and low-health screen effects (0 off, 1 normal, 2 double).", 0, 2)

GMEAT.Camera = {
	DriftAngle = 0.55,
	DriftSpeed = 0.35,
	TremorAngle = 0.05,
	TremorHurt = 0.4,
	HurtShake = 1.2,
	BreathAngle = 0.22,
	BobAngle = 0.7,
	BobHeight = 1.3,
	GlanceAngle = 2.0,
	GlanceEvery = { 4, 10 },
	AimCalm = 0.45,

	FlinchMin = 2.5,
	FlinchMax = 11,
	FlinchPerDamage = 0.14,
	FlinchPush = 2.5,
	FlinchSettle = 0.12,
	FlinchBounce = 14,

	KillShakeTime = 0.55,
	KillShakeAngle = 2.8,
	KillFovPunch = 7,
	KillRedTime = 0.9,
	KillMazeAlpha = 0.85,
	KillMazeFPS = 20,
	KillImageChance = 1 / 3,
	KillImageAlpha = 1.0,
	KillImages = {
		"gmeat/fx/kill_maze2",
		"gmeat/fx/kill_manmaze",
	},

	GrainMin = 0.02,
	GrainMax = 0.09,
	FlickerMax = 0.006,
}
local CFG = GMEAT.Camera

local function hash(i)
	return (math.sin(i * 127.1 + 311.7) * 43758.5453) % 1
end

local function valueNoise(x)
	local i = math.floor(x)
	local f = x - i
	local u = f * f * (3 - 2 * f)
	local a = hash(i)
	return (a + (hash(i + 1) - a) * u) * 2 - 1
end

local function fbm(x, seed)
	return valueNoise(x + seed * 17.31) * 0.62 + valueNoise(x * 2.17 + seed * 31.7) * 0.28 + valueNoise(x * 4.93 + seed * 7.13) * 0.1
end

local st = {
	active = false,
	ang = Angle(0, 0, 0), z = 0, fov = 0, push = Vector(0, 0, 0), flinches = {},
	hurt = 0, exert = 0, calm = 1, moveFrac = 0,
	breath = 0, step = 0,
	nextGlance = 0, glance = nil,
	killAt = -100, red = 0,
	grainStep = -1, gu = 0, gv = 0, flicker = 0,
}
GMEAT.CameraState = st

local function viewingOwnEyes(ply)
	return IsValid(ply) and ply:Alive() and not ply:InVehicle() and ply:GetObserverMode() == OBS_MODE_NONE
		and ply:GetViewEntity() == ply
end

local function updateCamera()
	local ply = LocalPlayer()
	local t, dt = RealTime(), math.min(FrameTime(), 0.1)
	st.active = viewingOwnEyes(ply)

	local ka = t - st.killAt
	if ka < CFG.KillRedTime then
		st.red = ka < 0.06 and ka / 0.06 or (1 - (ka - 0.06) / (CFG.KillRedTime - 0.06)) ^ 1.5
	else
		st.red = 0
	end

	if not st.active then
		st.ang, st.z, st.fov, st.push = Angle(0, 0, 0), 0, 0, Vector(0, 0, 0)
		st.flinches = {}
		return
	end

	local hp = math.Clamp(ply:Health() / math.max(ply:GetMaxHealth(), 1), 0, 1)
	st.hurt = Lerp(math.min(dt * 3, 1), st.hurt, 1 - hp)
	local hurt = st.hurt
	local speed = ply:GetVelocity():Length2D()
	local onGround = ply:IsOnGround()
	local sprinting = ply:KeyDown(IN_SPEED) and speed > 200 and onGround
	st.exert = Lerp(math.min(dt * (sprinting and 0.5 or 0.12), 1), st.exert, sprinting and 1 or 0)
	local focused = ply:KeyDown(IN_ATTACK) or ply:KeyDown(IN_ATTACK2)
	st.calm = Lerp(math.min(dt * (focused and 10 or 1.5), 1), st.calm, focused and CFG.AimCalm or 1)
	st.moveFrac = Lerp(math.min(dt * 6, 1), st.moveFrac, onGround and math.Clamp(speed / 320, 0, 1) or 0)

	local strength = cvShake:GetFloat()
	local amp = (1 + CFG.HurtShake * hurt) * strength

	local d = CFG.DriftAngle * amp * (1 + 0.6 * st.exert) * st.calm
	local s = CFG.DriftSpeed
	local p = fbm(t * s, 1) * d
	local y = fbm(t * s * 0.85, 2) * d
	local r = fbm(t * s * 0.7, 3) * d * 0.9

	local tr = (CFG.TremorAngle + CFG.TremorHurt * hurt ^ 1.5 + 0.1 * st.exert) * strength * st.calm
	p = p + fbm(t * 9, 4) * tr
	y = y + fbm(t * 8.3, 5) * tr
	r = r + fbm(t * 7.1, 6) * tr * 0.5

	st.breath = st.breath + dt * (0.28 + 0.45 * st.exert + 0.25 * hurt) * math.pi * 2
	p = p + math.sin(st.breath) * CFG.BreathAngle * (1 + 1.5 * st.exert + hurt) * strength

	if onGround then st.step = st.step + dt * speed * 0.033 end
	local m = st.moveFrac * strength
	local plant = math.abs(math.cos(st.step))
	p = p + plant * CFG.BobAngle * 0.5 * m
	r = r + math.sin(st.step) * CFG.BobAngle * 0.8 * m
	y = y + math.sin(st.step) * CFG.BobAngle * 0.25 * m
	local z = -plant * CFG.BobHeight * m

	if t >= st.nextGlance then
		local lo, hi = CFG.GlanceEvery[1], CFG.GlanceEvery[2]
		st.nextGlance = t + math.Rand(lo, hi) * (1 - 0.5 * hurt)
		if not st.glance and not focused and strength > 0 then
			st.glance = {
				start = t,
				yaw = (math.random() < 0.5 and -1 or 1) * math.Rand(0.6, 1) * CFG.GlanceAngle * (1 + 0.5 * hurt),
				pitch = math.Rand(-0.5, 0.3) * CFG.GlanceAngle * 0.5,
				hold = math.Rand(0.25, 0.6),
			}
		end
	end
	local g = st.glance
	if g then
		local age = t - g.start
		local env
		if age < 0.12 then
			env = math.sin(age / 0.12 * math.pi / 2)
		elseif age < 0.12 + g.hold then
			env = 1
		else
			env = 1 - math.Clamp((age - 0.12 - g.hold) / 0.8, 0, 1)
			env = env * env * (3 - 2 * env)
		end
		if age > 0.12 + g.hold + 0.8 then st.glance = nil end
		env = env * st.calm * strength
		y = y + g.yaw * env
		p = p + g.pitch * env
		r = r - g.yaw * 0.15 * env
	end

	local fov = 0
	if ka < CFG.KillShakeTime then
		local k = 1 - ka / CFG.KillShakeTime
		local a = CFG.KillShakeAngle * k * k * strength
		p = p + fbm(t * 26, 7) * a
		y = y + fbm(t * 24, 8) * a
		r = r + fbm(t * 22, 9) * a * 1.3
		fov = CFG.KillFovPunch * math.sin(math.min(ka / 0.08, 1) * math.pi / 2) * k * math.min(strength, 1)
	end

	local push = Vector(0, 0, 0)
	for i = #st.flinches, 1, -1 do
		local f = st.flinches[i]
		local age = t - f.start
		if age > 0.7 then
			table.remove(st.flinches, i)
		else
			local e
			if age < 0.03 then
				e = math.sin(age / 0.03 * math.pi / 2)
			else
				local x = age - 0.03
				e = math.exp(-x / CFG.FlinchSettle) * math.cos(x * CFG.FlinchBounce)
			end
			p = p + f.p * e * strength
			y = y + f.y * e * strength
			r = r + f.r * e * strength
			push = push + f.push * (e * strength)
		end
	end

	st.ang = Angle(p, y, r)
	st.z = z
	st.fov = fov
	st.push = push
end

function GM:CameraFlinch(dir, dmg, regionScale)
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	local mag = math.Clamp(CFG.FlinchMin + dmg * CFG.FlinchPerDamage, CFG.FlinchMin, CFG.FlinchMax) * (regionScale or 1)
	local eye = ply:EyeAngles()
	local fwd, right = eye:Forward(), eye:Right()
	local f, rt = dir:Dot(fwd), dir:Dot(right)
	table.insert(st.flinches, {
		start = RealTime(),
		p = (f - dir.z * 0.7) * mag,
		y = -rt * mag * 0.8,
		r = rt * mag * 0.6,
		push = dir * (CFG.FlinchPush * math.min(mag / CFG.FlinchMax, 1.2)),
	})
	while #st.flinches > 6 do table.remove(st.flinches, 1) end
end

hook.Add("Think", "Gmeat_Camera", updateCamera)

net.Receive("Gmeat_KillFX", function()
	st.killAt = RealTime()
	st.killImage = nil
	local list = CFG.KillImages
	if list and #list > 0 and math.random() < CFG.KillImageChance then
		st.killImage = Material(list[math.random(#list)])
	end
end)

function GM:CalcView(ply, origin, angles, fov, znear, zfar)
	local view = BaseClass.CalcView(self, ply, origin, angles, fov, znear, zfar) or {}
	if st.active and ply == LocalPlayer() and not view.drawviewer then
		view.angles = (view.angles or angles) + st.ang
		view.origin = (view.origin or origin) + Vector(0, 0, st.z) + st.push
		view.fov = (view.fov or fov) - st.fov
	end
	return view
end

function GM:CalcViewModelView(wep, vm, oldPos, oldAng, pos, ang)
	local p, a = BaseClass.CalcViewModelView(self, wep, vm, oldPos, oldAng, pos, ang)
	p, a = p or pos, a or ang
	if st.active then
		a = a + st.ang * 0.8
		p = p + Vector(0, 0, st.z * 0.8) + st.push * 0.8
	end
	return p, a
end

local GRAIN = Material("gmeat/fx/grain")
local VIGNETTE = Material("gmeat/fx/vignette")
local KILL_MAZE = Material("gmeat/fx/killmaze")
local KILL_MAZE_FRAMES = 24
local KILL_MAZE_ASPECT = 640 / 527
local GRAIN_FPS = 24

hook.Add("RenderScreenspaceEffects", "Gmeat_CameraColour", function()
	local grain = cvGrain:GetFloat()
	local hurt = st.active and st.hurt * math.min(grain, 1) or 0
	local red = st.red
	local g = GAMEMODE.SlasherGrade and GAMEMODE:SlasherGrade()
	if hurt < 0.01 and red < 0.01 and grain <= 0 and not g then return end
	g = g or { add = { 0, 0, 0 }, brightness = 0, contrast = 1, colour = 1 }
	DrawColorModify({
		["$pp_colour_addr"] = g.add[1] + 0.05 * red,
		["$pp_colour_addg"] = g.add[2] * (1 - red),
		["$pp_colour_addb"] = g.add[3] * (1 - red),
		["$pp_colour_brightness"] = g.brightness + (st.active and st.flicker or 0) - 0.04 * hurt - 0.04 * red,
		["$pp_colour_contrast"] = g.contrast * (1 + 0.15 * hurt + 0.25 * red),
		["$pp_colour_colour"] = g.colour * (1 - 0.6 * hurt ^ 1.2 - 0.4 * red),
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0,
	})
end)

hook.Add("HUDPaintBackground", "Gmeat_CameraOverlay", function()
	local w, h = ScrW(), ScrH()
	local grain = cvGrain:GetFloat()
	local hurt = st.active and st.hurt or 0

	if st.red > 0.005 then
		local k = st.red
		render.OverrideBlend(true, BLEND_DST_COLOR, BLEND_ZERO, BLENDFUNC_ADD)
		surface.SetDrawColor(255, Lerp(k, 255, 28), Lerp(k, 255, 20), 255)
		surface.DrawRect(0, 0, w, h)
		render.OverrideBlend(false)
		surface.SetMaterial(VIGNETTE)
		surface.SetDrawColor(70, 0, 0, 255 * k)
		surface.DrawTexturedRect(0, 0, w, h)

		local age = RealTime() - st.killAt
		local frame = math.min(math.floor(age * CFG.KillMazeFPS), KILL_MAZE_FRAMES - 1)
		KILL_MAZE:SetInt("$frame", frame)
		local glow = math.Clamp(age / 0.05, 0, 1) * k * CFG.KillMazeAlpha * 255 * (st.killImage and 0.4 or 1)
		local zoom = 1 + 0.12 * (1 - math.Clamp(age / 0.5, 0, 1)) ^ 2
		local mw = math.max(w, h * KILL_MAZE_ASPECT) * zoom
		local mh = mw / KILL_MAZE_ASPECT
		surface.SetMaterial(KILL_MAZE)
		surface.SetDrawColor(glow, glow, glow, glow)
		surface.DrawTexturedRect((w - mw) / 2, (h - mh) / 2, mw, mh)

		if st.killImage then
			local stutter = (age < 0.06 or age > 0.11) and 1 or 0
			local a = stutter * math.Clamp(age / 0.03, 0, 1) * k * CFG.KillImageAlpha * 255
			local size = h * 0.8 * (1 + 0.18 * (1 - math.Clamp(age / 0.35, 0, 1)) ^ 2)
			surface.SetMaterial(st.killImage)
			surface.SetDrawColor(a, a, a, a)
			surface.DrawTexturedRect((w - size) / 2, (h - size) / 2, size, size)
		end
	end

	if not st.active or grain <= 0 then return end

	surface.SetMaterial(VIGNETTE)
	surface.SetDrawColor(0, 0, 0, math.min(255, (70 + 150 * hurt) * math.min(grain, 1)))
	surface.DrawTexturedRect(0, 0, w, h)

	local frame = math.floor(RealTime() * GRAIN_FPS)
	if frame ~= st.grainStep then
		st.grainStep = frame
		st.gu, st.gv = math.random(), math.random()
		st.flicker = math.Rand(-1, 1) * (0.002 + CFG.FlickerMax * hurt) * math.min(grain, 1)
	end
	local strength = (CFG.GrainMin + (CFG.GrainMax - CFG.GrainMin) * hurt ^ 1.3) * grain
	local texel = math.max(1, h / 720) * (1 + 0.15 * hurt)
	local tile = 256 * texel
	surface.SetMaterial(GRAIN)
	surface.SetDrawColor(255, 255, 255, math.min(255, 255 * strength))
	surface.DrawTexturedRectUV(0, 0, w, h, st.gu, st.gv, st.gu + w / tile, st.gv + h / tile)
	if strength > 1 then
		surface.SetDrawColor(255, 255, 255, math.min(255, 255 * (strength - 1)))
		surface.DrawTexturedRectUV(0, 0, w, h, st.gv, st.gu, st.gv + w / tile, st.gu + h / tile)
	end
end)
