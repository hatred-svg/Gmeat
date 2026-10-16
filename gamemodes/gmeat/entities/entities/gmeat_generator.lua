AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Generator"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:Initialize()
	self:SetModel("models/props_c17/trappropeller_engine.mdl")
	if SERVER then
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end
		GAMEMODE.Interactables[self] = true
		self.Hum = CreateSound(self, "ambient/machines/turbine_loop_1.wav")
		self.Hum:PlayEx(0.35, 90)
	end
end

function ENT:OnRemove()
	if SERVER then
		if self.Hum then self.Hum:Stop() end
		if GAMEMODE and GAMEMODE.Interactables then GAMEMODE.Interactables[self] = nil end
	end
end

if SERVER then
	function ENT:GmeatInteractInfo(ply)
		return GAMEMODE:QuestCall("InteractInfo", self, ply)
	end

	function ENT:GmeatInteractDone(ply)
		GAMEMODE:QuestCall("InteractDone", self, ply)
	end
end

if CLIENT then
	local glow = Material("sprites/light_glow02_add")

	function ENT:DrawTranslucent()
		local pos = self:WorldSpaceCenter() + Vector(0, 0, 30)
		local blink = (math.sin(CurTime() * 4) + 1) * 0.5
		render.SetMaterial(glow)
		render.DrawSprite(pos, 40 + blink * 30, 40 + blink * 30, Color(255, 200, 60))

		local eye = LocalPlayer():EyePos()
		if eye:DistToSqr(pos) > 600 * 600 then return end
		local ang = (eye - pos):Angle()
		ang = Angle(0, ang.y + 90, 90)
		cam.Start3D2D(pos + Vector(0, 0, 18), ang, 0.15)
			draw.SimpleTextOutlined("GENERATOR", "DermaLarge", 0, 0, Color(255, 200, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
		cam.End3D2D()
	end
end
