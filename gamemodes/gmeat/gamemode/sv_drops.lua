GM.Drops = GM.Drops or {}
GM.WeaponPool = GM.WeaponPool or {}

local function num(v)
	return isnumber(v) and v or nil
end

function GM:EstimateWeaponTier(class)
	if GMEAT.WeaponTierOverrides[class] then return GMEAT.WeaponTierOverrides[class] end
	if GMEAT.HL2Weapons[class] then return GMEAT.HL2Weapons[class] end

	local w = weapons.Get(class)
	if not w then return 2 end
	local p = istable(w.Primary) and w.Primary or {}

	local damage = num(p.Damage) or num(w.Damage) or num(w.DamageMax) or num(w.Damage_Max)
	if not damage and istable(w.Bullet) and istable(w.Bullet.Damage) then
		damage = num(w.Bullet.Damage[1])
	end
	if not damage then return 2 end

	local pellets = num(p.NumShots) or num(w.Num) or 1
	local delay = num(p.Delay) or num(w.Delay)
	if not delay then
		local rpm = num(p.RPM) or num(w.RPM)
		delay = rpm and rpm > 0 and (60 / rpm) or 0.15
	end
	local dps = damage * math.max(pellets, 1) / math.max(delay, 0.03)

	if dps < 80 then return 1 end
	if dps < 160 then return 2 end
	if dps < 300 then return 3 end
	if dps < 500 then return 4 end
	return 5
end

function GM:BuildWeaponPool()
	local blacklist = {}
	for class, banned in pairs(GMEAT.WeaponBlacklist) do
		if banned then blacklist[class] = true end
	end
	for _, class in ipairs(GMEAT.SplitList(GetConVar("gmeat_weapon_blacklist"):GetString())) do
		blacklist[class] = true
	end

	local whitelist
	local whiteEntries = GMEAT.SplitList(GetConVar("gmeat_weapon_whitelist"):GetString())
	if #whiteEntries > 0 then
		whitelist = {}
		for _, class in ipairs(whiteEntries) do whitelist[class] = true end
	end

	local pool, seen = {}, {}
	local function add(class)
		if seen[class] or blacklist[class] then return end
		if whitelist and not whitelist[class] then return end
		seen[class] = true
		pool[#pool + 1] = { class = class, tier = self:EstimateWeaponTier(class) }
	end

	if GetConVar("gmeat_hl2_weapons"):GetBool() then
		for class in pairs(GMEAT.HL2Weapons) do add(class) end
	end
	for _, w in ipairs(weapons.GetList()) do
		if w.ClassName and w.Spawnable and not w.AdminOnly then
			add(w.ClassName)
		end
	end

	self.WeaponPool = pool
	return pool
end

function GM:PickWeapon(exclude)
	exclude = exclude or {}
	local candidates = {}
	for _, entry in ipairs(self.WeaponPool) do
		if not exclude[entry.class] then candidates[#candidates + 1] = entry end
	end
	if #candidates == 0 then return end
	return candidates[math.random(#candidates)].class
end

local DROP_WEAPONS_MIN = 2
local DROP_WEAPONS_MAX = 3
local DROP_THIRD_WEAPON_CHANCE = 0.4

function GM:OpenSupplyDrop(crate, ply)
	if crate.GmeatOpened then return end
	crate.GmeatOpened = true

	local count = math.random() < DROP_THIRD_WEAPON_CHANCE and DROP_WEAPONS_MAX or DROP_WEAPONS_MIN

	local chosen, names, best, bestTier = {}, {}, nil, -1
	for _ = 1, count do
		local class = self:PickWeapon(chosen)
		if not class then break end
		chosen[class] = true
		local had = ply:HasWeapon(class)
		local wep = had and ply:GetWeapon(class) or ply:Give(class)
		if IsValid(wep) then
			local ammoType = wep:GetPrimaryAmmoType()
			if ammoType and ammoType >= 0 then
				local clip = wep:GetMaxClip1()
				local amount = clip > 0 and clip * (had and 2 or 3) or 2
				ply:GiveAmmo(amount, ammoType)
			end
			local name = wep:GetPrintName()
			names[#names + 1] = name ~= "" and name or class
			local wepTier = self:EstimateWeaponTier(class)
			if wepTier > bestTier then best, bestTier = class, wepTier end
		end
	end
	if best then ply:SelectWeapon(best) end
	local message = #names > 0 and ("Supply drop: " .. table.concat(names, ", ")) or "The supply drop was empty"

	local ed = EffectData()
	ed:SetOrigin(crate:WorldSpaceCenter())
	util.Effect("ManhackSparks", ed, true, true)
	self:Notify(ply, message)
	self.Drops[crate] = nil
	crate:Remove()
end

function GM:SpawnSupplyDrop(ignorePlayers)
	local weighted = {}
	for _, info in ipairs(self.RoomList) do
		if not info.isStart and IsValid(info.ent) and #info.spots > 0 then
			local near = false
			if not ignorePlayers then
				for _, ply in ipairs(player.GetAll()) do
					if ply:Alive() and ply:GetPos():DistToSqr(info.center) < 700 * 700 then
						near = true
						break
					end
				end
			end
			if not near then
				for _ = 1, math.min(info.order, 40) do weighted[#weighted + 1] = info end
			end
		end
	end

	for _ = 1, 5 do
		if #weighted == 0 then return false end
		local info = weighted[math.random(#weighted)]
		local crate, pos = self:SpawnInRoom("gmeat_supplydrop", info, 24)
		if IsValid(crate) then
			self.Drops[crate] = true
			local ed = EffectData()
			ed:SetOrigin(pos)
			ed:SetScale(1)
			util.Effect("ThumperDust", ed, true, true)
			self:Announce("supply_drop")
			return true
		end
	end
	return false
end

function GM:DropsThink()
	if CurTime() < (self.NextDrop or math.huge) then return end
	local active = 0
	for crate in pairs(self.Drops) do
		if IsValid(crate) then active = active + 1 else self.Drops[crate] = nil end
	end
	if active >= GetConVar("gmeat_drop_max"):GetInt() then
		self.NextDrop = CurTime() + 5
		return
	end
	if self:SpawnSupplyDrop() then
		self.NextDrop = CurTime() + GetConVar("gmeat_drop_interval"):GetFloat()
	else
		self.NextDrop = CurTime() + 5
	end
end

function GM:DropMarkers(list)
	for crate in pairs(self.Drops) do
		if IsValid(crate) then
			list[#list + 1] = {
				type = GMEAT_MARKER_OBJECTIVE,
				pos = crate:WorldSpaceCenter() + Vector(0, 0, 24),
				ent = crate,
				color = Color(90, 170, 255),
				label = "Supply drop",
				hud = true,
			}
		end
	end
end
