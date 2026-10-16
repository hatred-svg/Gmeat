GM.Quests = GM.Quests or {}
GM.QuestOrder = GM.QuestOrder or {}

function GM:RegisterQuest(quest)
	if not self.Quests[quest.ID] then
		table.insert(self.QuestOrder, quest.ID)
	end
	self.Quests[quest.ID] = quest
end

local folder = GM.FolderName .. "/gamemode/quests/"
for _, fileName in ipairs(file.Find(folder .. "*.lua", "LUA")) do
	if SERVER then AddCSLuaFile(folder .. fileName) end
	include(folder .. fileName)
end
