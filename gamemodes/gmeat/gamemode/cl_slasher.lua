local cvLook = CreateClientConVar("gmeat_slasher_look", "1", true, false, "80s slasher film lighting: grade, glow, fog, flickering lights.", 0, 1)

GMEAT.Slasher = {
	Contrast = 1.22,
	Brightness = -0.06,
	Saturation = 0.8,
	ShadowTint = { 0.0, 0.012, 0.035 },
	BloomDarken = 0.62,
	BloomMultiply = 1.3,
	BloomSize = 8,
	BloomTint = { 1.0, 0.72, 0.5 },
	FogColor = { 6, 8, 14 },
	FogStart = 150,
	FogEnd = 1500,
	FogDensity = 0.88,
	FlickerEvery = { 25, 70 },
	FlickerDip = 0.22,
}
local CFG = GMEAT.Slasher

local flicker = { nextAt = 0, dips = nil }

local function flickerAmount()
	local now = RealTime()
	if flicker.nextAt == 0 then flicker.nextAt = now + math.Rand(CFG.FlickerEvery[1] * 0.5, CFG.FlickerEvery[2]) end
	if not flicker.dips and now >= flicker.nextAt then
		local dips, t = {}, now
		for i = 1, math.random(2, 4) do
			local len = math.Rand(0.04, 0.12)
			if i > 1 and math.random() < 0.3 then len = math.Rand(0.2, 0.4) end
			dips[#dips + 1] = { start = t, stop = t + len, depth = math.Rand(0.5, 1) }
			t = t + len + math.Rand(0.04, 0.2)
		end
		flicker.dips, flicker.ends = dips, t
	end
	if not flicker.dips then return 0 end
	if now > flicker.ends then
		flicker.dips = nil
		flicker.nextAt = now + math.Rand(CFG.FlickerEvery[1], CFG.FlickerEvery[2])
		return 0
	end
	for _, d in ipairs(flicker.dips) do
		if now >= d.start and now <= d.stop then return d.depth end
	end
	return 0
end

function GM:SlasherGrade()
	if not cvLook:GetBool() then return end
	local dip = flickerAmount() * CFG.FlickerDip
	return {
		add = CFG.ShadowTint,
		brightness = CFG.Brightness - dip,
		contrast = CFG.Contrast,
		colour = CFG.Saturation,
	}
end

hook.Add("RenderScreenspaceEffects", "Gmeat_SlasherGlow", function()
	if not cvLook:GetBool() then return end
	local t = CFG.BloomTint
	DrawBloom(CFG.BloomDarken, CFG.BloomMultiply, CFG.BloomSize, CFG.BloomSize, 2, 1, t[1], t[2], t[3])
end)

local function applyFog(scale)
	if not cvLook:GetBool() then return end
	scale = scale or 1
	local c = CFG.FogColor
	render.FogMode(MATERIAL_FOG_LINEAR)
	render.FogStart(CFG.FogStart * scale)
	render.FogEnd(CFG.FogEnd * scale)
	render.FogMaxDensity(CFG.FogDensity)
	render.FogColor(c[1], c[2], c[3])
	return true
end

hook.Add("SetupWorldFog", "Gmeat_SlasherFog", function() return applyFog(1) end)
hook.Add("SetupSkyboxFog", "Gmeat_SlasherFog", function(scale) return applyFog(scale) end)
