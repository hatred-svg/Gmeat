AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Supply Drop"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

local OPEN_TIME = 3

function ENT:Initialize()
	self:SetModel("models/items/item_item_crate.mdl")
	if SERVER then
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end
		GAMEMODE.Interactables[self] = true
		self:EmitSound("physics/metal/metal_box_impact_hard1.wav", 90)
	end
end

function ENT:OnRemove()
	if SERVER and GAMEMODE and GAMEMODE.Interactables then
		GAMEMODE.Interactables[self] = nil
	end
end

if SERVER then
	function ENT:GmeatInteractInfo(ply)
		return OPEN_TIME, "Open supply drop", { path = GMEAT.Sounds.DropOpen }
	end

	function ENT:GmeatInteractDone(ply)
		GAMEMODE:OpenSupplyDrop(self, ply)
	end
end

if CLIENT then
	local glow = Material("sprites/light_glow02_add")
	local blue = Color(90, 170, 255)

	function ENT:DrawTranslucent()
		local pos = self:WorldSpaceCenter()
		local pulse = (math.sin(CurTime() * 4) + 1) * 0.5
		render.SetMaterial(glow)
		render.DrawSprite(pos + Vector(0, 0, 24), 50 + pulse * 30, 50 + pulse * 30, blue)
		render.SetColorMaterial()
		render.DrawBeam(pos, pos + Vector(0, 0, 220), 8, 0, 1, Color(blue.r, blue.g, blue.b, 50))
	end
end
