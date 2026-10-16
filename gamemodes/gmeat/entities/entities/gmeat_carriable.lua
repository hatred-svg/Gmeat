AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Gmeat Objective"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.GmeatPickupable = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "Kind")
end

function ENT:Initialize()
	if SERVER then
		self:SetModel(GMEAT.CarryModels[self:GetKind()] or "models/props_c17/briefcase001a.mdl")
		self:SetSolid(SOLID_NONE)
		self:SetMoveType(MOVETYPE_NONE)
		GAMEMODE.Pickups[self] = true
	end
end

function ENT:OnRemove()
	if SERVER and GAMEMODE and GAMEMODE.Pickups then
		GAMEMODE.Pickups[self] = nil
	end
end

if CLIENT then
	local glow = Material("sprites/light_glow02_add")

	function ENT:Draw()
		local t = CurTime()
		self:SetRenderOrigin(self:GetPos() + Vector(0, 0, 6 + math.sin(t * 2.5) * 3))
		self:SetRenderAngles(Angle(0, (t * 60) % 360, 0))
		self:DrawModel()
		self:SetRenderOrigin(nil)
		self:SetRenderAngles(nil)
	end

	function ENT:DrawTranslucent()
		local color = GMEAT.CarryColors[self:GetKind()] or color_white
		local pos = self:GetPos()
		render.SetMaterial(glow)
		render.DrawSprite(pos + Vector(0, 0, 14), 72, 72, color)
		render.SetColorMaterial()
		render.DrawBeam(pos, pos + Vector(0, 0, 160), 6, 0, 1, Color(color.r, color.g, color.b, 60))
	end
end
