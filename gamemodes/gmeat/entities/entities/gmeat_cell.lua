AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Power Cell"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.GmeatPickupable = true

function ENT:Initialize()
	self:SetModel("models/items/car_battery01.mdl")
	if SERVER then
		self:SetSolid(SOLID_NONE)
		self:SetMoveType(MOVETYPE_NONE)
		self:DrawShadow(false)
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
	local color = Color(90, 255, 130)

	function ENT:Draw()
		local t = CurTime() + self:EntIndex()
		self:SetRenderOrigin(self:GetPos() + Vector(0, 0, 8 + math.sin(t * 3) * 3))
		self:SetRenderAngles(Angle(0, (t * 80) % 360, 0))
		self:DrawModel()
		self:SetRenderOrigin(nil)
		self:SetRenderAngles(nil)
	end

	function ENT:DrawTranslucent()
		local t = CurTime() + self:EntIndex()
		render.SetMaterial(glow)
		render.DrawSprite(self:GetPos() + Vector(0, 0, 14 + math.sin(t * 3) * 3), 48, 48, color)
	end
end
