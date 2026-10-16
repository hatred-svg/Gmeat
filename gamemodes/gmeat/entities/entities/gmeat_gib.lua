AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Gib"
ENT.Spawnable = false
ENT.GmeatInteractPress = true
ENT.GmeatInteractAim = 0.85
ENT.GmeatInteractCooldown = 0.5

function ENT:Initialize()
	if SERVER then
		if not self:GetModel() or self:GetModel() == "" then
			self:SetModel("models/gibs/antlion_gib_small_1.mdl")
		end
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			local custom = GMEAT.Sounds and GMEAT.Sounds.GibImpact and #GMEAT.Sounds.GibImpact > 0
			phys:SetMaterial(custom and "default_silent" or "flesh")
			phys:Wake()
		end
		self.DieAt = CurTime() + (GMEAT.Gore and GMEAT.Gore.GibLifetime or 10) + math.Rand(0, 2)
		self.MinZ = self:GetPos().z - 400
		self.NextSplat = 0
		if GAMEMODE and GAMEMODE.Interactables then GAMEMODE.Interactables[self] = true end
	end
	self.SpawnTime = CurTime()
end

function ENT:OnRemove()
	if SERVER and GAMEMODE and GAMEMODE.Interactables then GAMEMODE.Interactables[self] = nil end
end

if SERVER then
	function ENT:GmeatInteractInfo(ply)
		if GAMEMODE.CanEatGib and GAMEMODE:CanEatGib(ply, self) then return 0, "Eat" end
	end

	function ENT:GmeatInteractDone(ply)
		GAMEMODE:EatGib(ply, self)
	end

	function ENT:PhysicsCollide(data, phys)
		local now = CurTime()
		if data.Speed >= 50 and now >= (self.NextThud or 0) then
			self.NextThud = now + 0.12
			local list = GMEAT.Sounds and GMEAT.Sounds.GibImpact
			local vol = math.Clamp(data.Speed / 450, 0.25, 1)
			if list and #list > 0 then
				self:EmitSound(list[math.random(#list)], 70, math.random(92, 108), vol)
			else
				self:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(1, 4) .. ".wav", 70, math.random(90, 115), vol)
			end
		end
		if data.Speed < 90 or now < self.NextSplat then return end
		self.NextSplat = now + 0.25
		local hitPos, normal = data.HitPos, data.HitNormal
		local onRoom = not IsValid(data.HitEntity) or data.HitEntity:IsWorld() or data.HitEntity:GetClass() == "sector75_room_entity"
		if normal.z < -0.7 and onRoom and GAMEMODE.FloorStain then
			GAMEMODE:FloorStain(hitPos, GMEAT_STAIN_SPLAT, -normal)
		else
			util.Decal(GMEAT.BloodDecal or "Blood", hitPos - normal * 4, hitPos + normal * 4, self)
		end
	end

	function ENT:Think()
		if CurTime() > self.DieAt or self:GetPos().z < self.MinZ then
			self:Remove()
			return
		end
		self:NextThink(CurTime() + 0.5)
		return true
	end
end

if CLIENT then
	function ENT:Think()
		if CurTime() - (self.SpawnTime or 0) > 1.4 then return end
		local pos = self:GetPos()
		if self.LastPos and pos:DistToSqr(self.LastPos) > 4 and GAMEMODE.GibTrail then
			GAMEMODE:GibTrail(pos)
		end
		self.LastPos = pos
		self:SetNextClientThink(CurTime() + 0.03)
		return true
	end
end
