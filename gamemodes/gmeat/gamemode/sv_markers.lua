util.AddNetworkString("Gmeat_Markers")

local INTERVAL = 0.4

function GM:BuildMarkers()
	local list = {}
	if self:GetRoundState() == GMEAT_ACTIVE then
		self:QuestCall("GetMarkers", list)
		self:DropMarkers(list)
	end
	return list
end

function GM:MarkerThink()
	if (self.NextMarkerSend or 0) > CurTime() then return end
	self.NextMarkerSend = CurTime() + INTERVAL

	local list = self:BuildMarkers()
	local count = math.min(#list, 255)
	net.Start("Gmeat_Markers")
	net.WriteUInt(count, 8)
	for i = 1, count do
		local m = list[i]
		local color = m.color or color_white
		net.WriteUInt(m.type or GMEAT_MARKER_OBJECTIVE, 3)
		net.WriteVector(m.pos)
		net.WriteUInt(IsValid(m.ent) and m.ent:EntIndex() or 0, 16)
		net.WriteUInt(color.r, 8)
		net.WriteUInt(color.g, 8)
		net.WriteUInt(color.b, 8)
		net.WriteString(m.label or "")
		net.WriteUInt(math.Clamp(math.floor(m.radius or 0), 0, 4095), 12)
		net.WriteBool(m.hud == true)
		net.WriteUInt(IsValid(m.viewer) and m.viewer:EntIndex() or 0, 16)
	end
	net.Broadcast()
end
