AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Planted Explosive"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "DetonateAt")
	self:NetworkVar("Entity", 0, "Planter")
end

function ENT:Initialize()
	self:SetModel(GMEAT.CarryModels.bomb)
	if SERVER then
		self:SetSolid(SOLID_NONE)
		self:SetMoveType(MOVETYPE_NONE)
		GAMEMODE.Interactables[self] = true
		self.NextBeep = 0
	end
end

function ENT:OnRemove()
	if SERVER and GAMEMODE and GAMEMODE.Interactables then
		GAMEMODE.Interactables[self] = nil
	end
end

if SERVER then
	function ENT:GmeatInteractInfo(ply)
		return GAMEMODE:QuestCall("InteractInfo", self, ply)
	end

	function ENT:GmeatInteractDone(ply)
		GAMEMODE:QuestCall("InteractDone", self, ply)
	end

	function ENT:Think()
		local left = self:GetDetonateAt() - CurTime()
		if left <= 0 then
			if GAMEMODE:GetRoundState() == GMEAT_ACTIVE and GAMEMODE.ActiveQuest and GAMEMODE.ActiveQuest.OnBombDetonate then
				GAMEMODE.ActiveQuest:OnBombDetonate(self)
			else
				self:Remove()
			end
			return
		end
		if CurTime() >= self.NextBeep then
			self:EmitSound("buttons/blip1.wav", 85, left < 5 and 130 or 100)
			self.NextBeep = CurTime() + math.Clamp(left / 10, 0.12, 1)
		end
		self:NextThink(CurTime() + 0.05)
		return true
	end

	function ENT:Explode()
		local pos = self:GetPos() + Vector(0, 0, 16)
		local ed = EffectData()
		ed:SetOrigin(pos)
		ed:SetMagnitude(8)
		ed:SetScale(2)
		util.Effect("Explosion", ed, true, true)
		util.Effect("HelicopterMegaBomb", ed, true, true)
		util.ScreenShake(pos, 25, 150, 2, 2000)
		local planter = self:GetPlanter()
		util.BlastDamage(self, IsValid(planter) and planter or self, pos, 520, 400)
		self:Remove()
	end
end

if CLIENT then
	local glow = Material("sprites/light_glow02_add")

	function ENT:DrawTranslucent()
		local left = math.max(0, self:GetDetonateAt() - CurTime())
		local rate = left < 5 and 10 or 3
		if math.sin(CurTime() * rate) > 0 then
			render.SetMaterial(glow)
			render.DrawSprite(self:GetPos() + Vector(0, 0, 6), 40, 40, Color(255, 40, 40))
		end

		local pos = self:GetPos() + Vector(0, 0, 30)
		local eye = LocalPlayer():EyePos()
		if eye:DistToSqr(pos) > 500 * 500 then return end
		local ang = (eye - pos):Angle()
		ang = Angle(0, ang.y + 90, 90)
		cam.Start3D2D(pos, ang, 0.15)
			draw.SimpleTextOutlined(string.format("%.1f", left), "DermaLarge", 0, 0, Color(255, 60, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
		cam.End3D2D()
	end
end
