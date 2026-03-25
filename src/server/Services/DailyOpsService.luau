local Players = game:GetService("Players")

local DailyOpsService = {}
DailyOpsService.__index = DailyOpsService

function DailyOpsService.new(context)
	local self = setmetatable({}, DailyOpsService)
	self._config = context.DailyOpsConfig
	self._persistenceService = context.PersistenceService
	self._tokenService = context.TokenService
	self._skillTreeService = context.SkillTreeService
	self._subscriptionService = context.SubscriptionService
	self._gamePassService = context.GamePassService
	self._remoteNames = context.RemoteNames
	self._remotes = context.Remotes
	return self
end

function DailyOpsService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:_ensureCurrentDay(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_ensureCurrentDay(player)
	end
end

function DailyOpsService:_makeEmptyState(dayKey)
	return {
		dayKey = dayKey,
		progress = {},
		claimed = {},
	}
end

function DailyOpsService:_ensureCurrentDay(player)
	local state = self._persistenceService:GetDailyOpsState(player)
	local todayKey = self._config.getDayKey()
	if state.dayKey ~= todayKey then
		state = self:_makeEmptyState(todayKey)
		self._persistenceService:SetDailyOpsState(player, state.dayKey, state.progress, state.claimed)
	end
	return state
end

function DailyOpsService:_getAdjustedTokenRewardAmount(player, amount)
	local rewardAmount = math.max(0, math.floor(amount or 0))
	if self._subscriptionService then
		rewardAmount = self._subscriptionService:GetAdjustedTokenRewardAmount(player, rewardAmount)
	end
	if self._gamePassService then
		rewardAmount = math.max(0, math.floor((rewardAmount * self._gamePassService:GetTokenRewardMultiplier(player)) + 0.5))
	end
	return rewardAmount
end

function DailyOpsService:GetState(player)
	local profileState = self:_ensureCurrentDay(player)
	local tasks = {}

	for _, task in ipairs(self._config.getTasksForDay(profileState.dayKey)) do
		local progress = math.max(0, math.floor(profileState.progress[task.Id] or 0))
		local goal = math.max(1, math.floor(task.Goal or 1))
		local claimed = profileState.claimed[task.Id] == true
		table.insert(tasks, {
			id = task.Id,
			displayName = task.DisplayName,
			description = task.Description,
			progress = math.min(progress, goal),
			goal = goal,
			progressPercent = math.clamp(progress / goal, 0, 1),
			canClaim = progress >= goal and not claimed,
			claimed = claimed,
			rewardTokens = task.RewardTokens or 0,
			rewardExperience = task.RewardExperience or 0,
		})
	end

	return {
		dayKey = profileState.dayKey,
		nextResetAt = (profileState.dayKey + 1) * 86400,
		tasks = tasks,
	}
end

function DailyOpsService:IncrementProgress(player, eventKey, amount)
	if not player or not player.Parent then
		return
	end

	local state = self:_ensureCurrentDay(player)
	local changed = false
	local delta = math.max(0, math.floor(amount or 0))
	local progressLines = {}
	if delta <= 0 then
		return
	end

	for _, task in ipairs(self._config.getTasksForDay(state.dayKey)) do
		if task.Event == eventKey then
			local goal = math.max(1, math.floor(task.Goal or 1))
			local current = math.max(0, math.floor(state.progress[task.Id] or 0))
			local updated = math.min(goal, current + delta)
			if updated ~= current then
				state.progress[task.Id] = updated
				changed = true
				table.insert(progressLines, {
					taskId = task.Id,
					displayName = task.DisplayName,
					progress = updated,
					goal = goal,
					complete = updated >= goal,
					rewardTokens = task.RewardTokens or 0,
					rewardExperience = task.RewardExperience or 0,
				})
			end
		end
	end

	if changed then
		self._persistenceService:SetDailyOpsState(player, state.dayKey, state.progress, state.claimed)
		if self._remotes and #progressLines > 0 then
			self._remotes:FireEventFor(player, self._remoteNames.Events.Notification, {
				userId = player.UserId,
				kind = "DailyOpsProgress",
				lines = progressLines,
			})
		end
	end
end

function DailyOpsService:ClaimReward(player, taskId)
	local task = self._config.getTaskDefinition(taskId)
	if not task then
		return false, "missing_task", self:GetState(player)
	end

	local state = self:_ensureCurrentDay(player)
	local progress = math.max(0, math.floor(state.progress[task.Id] or 0))
	local goal = math.max(1, math.floor(task.Goal or 1))
	if progress < goal then
		return false, "not_ready", self:GetState(player)
	end
	if state.claimed[task.Id] == true then
		return false, "already_claimed", self:GetState(player)
	end

	state.claimed[task.Id] = true
	self._persistenceService:SetDailyOpsState(player, state.dayKey, state.progress, state.claimed)

	local rewardTokens = self:_getAdjustedTokenRewardAmount(player, task.RewardTokens or 0)
	local rewardExperience = math.max(0, math.floor(task.RewardExperience or 0))
	if rewardTokens > 0 then
		self._tokenService:AddTokens(player, rewardTokens, "DailyReward", "daily_ops_reward")
	end
	if rewardExperience > 0 and self._skillTreeService and self._skillTreeService.AwardExperience then
		self._skillTreeService:AwardExperience(player, rewardExperience, "DailyOpsReward")
	end
	if self._remotes then
		self._remotes:FireEventFor(player, self._remoteNames.Events.Notification, {
			userId = player.UserId,
			message = ("Daily op completed: %s. +%d tokens%s"):format(
				task.DisplayName,
				rewardTokens,
				rewardExperience > 0 and (" +%d XP"):format(rewardExperience) or ""
			),
		})
	end

	return true, {
		tokens = rewardTokens,
		experience = rewardExperience,
		taskId = task.Id,
	}, self:GetState(player)
end

return DailyOpsService
