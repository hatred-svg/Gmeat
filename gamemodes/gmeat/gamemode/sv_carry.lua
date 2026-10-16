local RETURN_TIME = 30

function GM:CarrySpawn(kind, pos)
	local carry = { kind = kind, home = pos }
	self:CarryPlace(carry, pos, true)
	return carry
end

function GM:CarryPlace(carry, pos, atHome)
	if IsValid(carry.ent) then carry.ent:Remove() end
	if IsValid(carry.carrier) then carry.carrier:SetNWString("GmeatCarrying", "") end
	carry.carrier = nil
	local ent = ents.Create("gmeat_carriable")
	ent:SetKind(carry.kind)
	ent:SetPos(pos)
	ent:SetAngles(Angle(0, math.random(0, 359), 0))
	ent:Spawn()
	self:PlaceOnFloor(ent, pos)
	ent.GmeatCarry = carry
	carry.ent = ent
	carry.droppedAt = (not atHome) and CurTime() or nil
end

function GM:CarryPickup(carry, ply)
	if IsValid(carry.ent) then
		carry.ent.GmeatTaken = true
		carry.ent:Remove()
	end
	carry.ent = nil
	carry.droppedAt = nil
	carry.carrier = ply
	ply:SetNWString("GmeatCarrying", carry.kind)
	ply:EmitSound("items/ammo_pickup.wav")
end

function GM:CarryDrop(carry, pos)
	local floor = pos and self:FindFloorBelow(pos)
	if floor then
		self:CarryPlace(carry, floor, false)
	else
		self:CarryReturn(carry)
	end
end

function GM:CarryReturn(carry)
	self:CarryPlace(carry, carry.home, true)
end

function GM:CarryRemove(carry)
	if IsValid(carry.ent) then carry.ent:Remove() end
	if IsValid(carry.carrier) then carry.carrier:SetNWString("GmeatCarrying", "") end
	carry.ent = nil
	carry.carrier = nil
	carry.droppedAt = nil
end

function GM:CarryThink(carry)
	if IsValid(carry.carrier) and not carry.carrier:Alive() then
		self:CarryDrop(carry, carry.carrier:GetPos())
	end
	if carry.droppedAt and CurTime() - carry.droppedAt > RETURN_TIME then
		self:CarryReturn(carry)
		return true
	end
	return false
end

function GM:InZone(ply, zone)
	if not IsValid(ply) or not IsValid(zone) then return false end
	local pp, zp = ply:GetPos(), zone:GetPos()
	local r = zone:GetRadius()
	return math.abs(pp.z - zp.z) < 100 and GMEAT.Dist2DSqr(pp, zp) < r * r
end

function GM:CreateZone(pos, radius, color, label)
	local zone = ents.Create("gmeat_zone")
	zone:SetPos(pos)
	zone:SetRadius(radius)
	zone:SetZoneColor(Vector(color.r, color.g, color.b))
	zone:SetLabel(label)
	zone:Spawn()
	self:ReserveSpot(pos)
	return zone
end
