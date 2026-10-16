AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Skull"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.GmeatPickupable = true

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "Killer")
	self:NetworkVar("Entity", 1, "Victim")
end

function ENT:Initialize()
	self:SetModel("models/gibs/hgibs.mdl")
	if SERVER then
		self:SetSolid(SOLID_NONE)
		self:SetMoveType(MOVETYPE_NONE)
		GAMEMODE.Pickups[self] = true
		self:EmitSound("physics/flesh/flesh_squishy_impact_hard1.wav")
	end
end

function ENT:OnRemove()
	if SERVER and GAMEMODE and GAMEMODE.Pickups then
		GAMEMODE.Pickups[self] = nil
	end
end

if CLIENT then
	local glow = Material("sprites/light_glow02_add")
	local GOLD = Color(255, 215, 80)
	local RED = Color(255, 70, 70)

	function ENT:Draw()
		local t = CurTime() + self:EntIndex()
		self:SetRenderOrigin(self:GetPos() + Vector(0, 0, 14 + math.sin(t * 3) * 3))
		self:SetRenderAngles(Angle(0, (t * 90) % 360, 0))
		self:DrawModel()
		self:SetRenderOrigin(nil)
		self:SetRenderAngles(nil)
	end

	function ENT:DrawTranslucent()
		local mine = self:GetKiller() == LocalPlayer()
		local color = mine and GOLD or RED
		local t = CurTime() + self:EntIndex()
		local pos = self:GetPos() + Vector(0, 0, 16 + math.sin(t * 3) * 3)
		render.SetMaterial(glow)
		render.DrawSprite(pos, 56, 56, color)

		local eye = LocalPlayer():EyePos()
		if eye:DistToSqr(pos) > 500 * 500 then return end
		local ang = (eye - pos):Angle()
		ang = Angle(0, ang.y + 90, 90)
		cam.Start3D2D(pos + Vector(0, 0, 18), ang, 0.12)
			draw.SimpleTextOutlined(mine and "CONFIRM" or "DENY", "DermaLarge", 0, 0, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
		cam.End3D2D()
	end
end
