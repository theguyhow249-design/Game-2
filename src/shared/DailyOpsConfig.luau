local DailyOpsConfig = {}

DailyOpsConfig.Tasks = {
	{
		Id = "kill_25",
		DisplayName = "Cull 25 Infected",
		Description = "Eliminate 25 infected across bunker operations.",
		Goal = 25,
		Event = "ZombieKill",
		RewardTokens = 60,
		RewardExperience = 25,
	},
	{
		Id = "kill_50",
		DisplayName = "Cull 50 Infected",
		Description = "Push deeper into the breach and eliminate 50 infected.",
		Goal = 50,
		Event = "ZombieKill",
		RewardTokens = 110,
		RewardExperience = 50,
	},
	{
		Id = "complete_1",
		DisplayName = "Finish 1 Deployment",
		Description = "Complete one mission run and return through extraction.",
		Goal = 1,
		Event = "MissionComplete",
		RewardTokens = 80,
		RewardExperience = 35,
	},
	{
		Id = "complete_2",
		DisplayName = "Finish 2 Deployments",
		Description = "Complete two successful mission runs today.",
		Goal = 2,
		Event = "MissionComplete",
		RewardTokens = 150,
		RewardExperience = 70,
	},
	{
		Id = "squad_1",
		DisplayName = "Run With A Squad",
		Description = "Complete one deployment while grouped with at least one other survivor.",
		Goal = 1,
		Event = "SquadMissionComplete",
		RewardTokens = 95,
		RewardExperience = 40,
	},
	{
		Id = "squad_2",
		DisplayName = "Lead 2 Squad Runs",
		Description = "Complete two deployments with a live squad today.",
		Goal = 2,
		Event = "SquadMissionComplete",
		RewardTokens = 170,
		RewardExperience = 80,
	},
}

DailyOpsConfig.TasksPerDay = 3

local function getUtcDayKey(timestamp)
	return math.floor((timestamp or os.time()) / 86400)
end

function DailyOpsConfig.getDayKey(timestamp)
	return getUtcDayKey(timestamp)
end

function DailyOpsConfig.getTaskDefinition(taskId)
	for _, task in ipairs(DailyOpsConfig.Tasks) do
		if task.Id == taskId then
			return task
		end
	end
	return nil
end

function DailyOpsConfig.getTasksForDay(dayKey)
	local resolvedDayKey = tonumber(dayKey) or getUtcDayKey()
	local poolSize = #DailyOpsConfig.Tasks
	local count = math.min(DailyOpsConfig.TasksPerDay, poolSize)
	local selected = {}
	local used = {}
	local seed = (resolvedDayKey * 7919) + 104729

	for index = 1, count do
		local offset = (seed + (index * 37)) % poolSize
		local cursor = 1 + offset
		while used[cursor] do
			cursor += 1
			if cursor > poolSize then
				cursor = 1
			end
		end
		used[cursor] = true
		table.insert(selected, DailyOpsConfig.Tasks[cursor])
	end

	table.sort(selected, function(a, b)
		return tostring(a.Id) < tostring(b.Id)
	end)

	return selected
end

return table.freeze(DailyOpsConfig)
