local Players = game:GetService("Players")

local LeaderstatsService = {}
LeaderstatsService.__index = LeaderstatsService

local LEADERSTAT_FIELDS = {
	{ name = "Level", className = "IntValue" },
	{ name = "Kills", className = "IntValue" },
	{ name = "Runs", className = "IntValue" },
}

function LeaderstatsService.new(context)
	local self = setmetatable({}, LeaderstatsService)
	self._persistenceService = context.PersistenceService
	self._skillTreeService = context.SkillTreeService
	return self
end

function LeaderstatsService:_ensureLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	for _, field in ipairs(LEADERSTAT_FIELDS) do
		local valueObject = leaderstats:FindFirstChild(field.name)
		if not valueObject then
			valueObject = Instance.new(field.className)
			valueObject.Name = field.name
			valueObject.Parent = leaderstats
		end
	end

	return leaderstats
end

function LeaderstatsService:RefreshPlayer(player)
	if not player or not player.Parent then
		return
	end

	local leaderstats = self:_ensureLeaderstats(player)
	local stats = self._persistenceService:GetStats(player)
	local skillTree = self._skillTreeService:BuildPayload(player)
	player:SetAttribute("MissionsCompleted", tonumber(stats.missionsCompleted) or 0)
	player:SetAttribute("ZombiesDefeated", tonumber(stats.zombiesDefeated) or 0)

	local values = {
		Level = tonumber(skillTree.level) or 1,
		Kills = tonumber(stats.zombiesDefeated) or 0,
		Runs = tonumber(stats.missionsCompleted) or 0,
	}

	for name, value in pairs(values) do
		local statValue = leaderstats:FindFirstChild(name)
		if statValue and statValue:IsA("IntValue") then
			statValue.Value = math.max(0, math.floor(value))
		end
	end
end

function LeaderstatsService:BindPlayer(player)
	self:_ensureLeaderstats(player)
	self:RefreshPlayer(player)
end

function LeaderstatsService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:BindPlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:BindPlayer(player)
	end

	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in ipairs(Players:GetPlayers()) do
				self:RefreshPlayer(player)
			end
		end
	end)
end

return LeaderstatsService
