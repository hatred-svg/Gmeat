local function allowed(ply)
	return not IsValid(ply) or ply:IsAdmin()
end

concommand.Add("gmeat_restart", function(ply)
	if not allowed(ply) then return end
	local state = GAMEMODE:GetRoundState()
	if state == GMEAT_ACTIVE or state == GMEAT_PREP then
		GAMEMODE:EndRound(nil, "Restarted by an admin.")
	end
	GAMEMODE:StartPrep()
end)

concommand.Add("gmeat_drop", function(ply)
	if not allowed(ply) then return end
	if not GAMEMODE:SpawnSupplyDrop(true) then
		print("[Gmeat] No room to put a supply drop in yet. Open a few doors first.")
	end
end)

concommand.Add("gmeat_weapons", function(ply)
	if not allowed(ply) then return end
	local pool = GAMEMODE:BuildWeaponPool()
	table.sort(pool, function(a, b) return a.tier == b.tier and a.class < b.class or a.tier < b.tier end)
	print("[Gmeat] Supply drop pool (" .. #pool .. " weapons):")
	for _, entry in ipairs(pool) do
		print(string.format("  tier %d  %s", entry.tier, entry.class))
	end
end)

concommand.Add("gmeat_rooms", function(ply)
	if not allowed(ply) then return end
	print("[Gmeat] " .. #GAMEMODE.RoomList .. " rooms:")
	for _, info in ipairs(GAMEMODE.RoomList) do
		print(string.format("  #%d depth %d  %-40s spots %d  doors %d%s", info.order, info.depth, info.name, #info.spots, #info.doors, info.isStart and "  (start)" or ""))
	end
end)

concommand.Add("gmeat_show_spots", function(ply)
	if not allowed(ply) then return end
	for _, info in ipairs(GAMEMODE.RoomList) do
		for _, p in ipairs(info.spots) do
			debugoverlay.Cross(p, 8, 15, Color(0, 255, 0), true)
		end
		for _, d in ipairs(info.doors) do
			debugoverlay.Sphere(d.pos, 12, 15, Color(255, 200, 0), true)
		end
	end
end)
