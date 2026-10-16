AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Gmeat Zone"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "Radius")
	self:NetworkVar("Vector", 0, "ZoneColor")
	self:NetworkVar("String", 0, "Label")
end

function ENT:Initialize()
	self:SetModel("models/hunter/plates/plate1x1.mdl")
	if SERVER then
		self:SetSolid(SOLID_NONE)
		self:SetMoveType(MOVETYPE_NONE)
		self:DrawShadow(false)
	end
end

if CLIENT then
	local SEGMENTS = 32

	function ENT:Think()
		local r = self:GetRadius()
		self:SetRenderBounds(Vector(-r, -r, 0), Vector(r, r, 220))
	end

	function ENT:Draw()
	end

	function ENT:DrawTranslucent()
		local r = self:GetRadius()
		if r <= 0 then return end
		local c = self:GetZoneColor()
		local pulse = (math.sin(CurTime() * 3) + 1) * 0.5
		local ring = Color(c.x, c.y, c.z, 140 + pulse * 100)
		local wall = Color(c.x, c.y, c.z, 25 + pulse * 20)
		local base = self:GetPos() + Vector(0, 0, 2)

		render.SetColorMaterial()
		local prev
		for i = 0, SEGMENTS do
			local a = (i / SEGMENTS) * math.pi * 2
			local p = base + Vector(math.cos(a) * r, math.sin(a) * r, 0)
			if prev then
				render.DrawBeam(prev, p, 4, 0, 1, ring)
				render.DrawQuad(prev, p, p + Vector(0, 0, 80), prev + Vector(0, 0, 80), wall)
				render.DrawQuad(prev + Vector(0, 0, 80), p + Vector(0, 0, 80), p, prev, wall)
			end
			prev = p
		end
		render.DrawBeam(base, base + Vector(0, 0, 200), 10, 0, 1, Color(c.x, c.y, c.z, 70))
	end
end
