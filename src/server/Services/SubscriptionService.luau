local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local SubscriptionService = {}
SubscriptionService.__index = SubscriptionService

local function isSubscribedStatus(status)
	if type(status) == "table" then
		if status.IsSubscribed ~= nil then
			return status.IsSubscribed == true
		end
		if status["IsSubscribed"] ~= nil then
			return status["IsSubscribed"] == true
		end
		if status.IsActive ~= nil then
			return status.IsActive == true
		end
	end

	local statusText = tostring(status or "")
	if statusText == "" then
		return false
	end

	if string.find(statusText, "NotSubscribed", 1, true) then
		return false
	end

	return string.find(statusText, "IsSubscribed", 1, true) ~= nil or string.find(statusText, "Subscribed", 1, true) ~= nil
end

function SubscriptionService.new(context)
	local self = setmetatable({}, SubscriptionService)
	self._contracts = context.Contracts
	self._persistenceService = context.PersistenceService
	self._remoteNames = context.RemoteNames
	self._remotes = context.Remotes
	self._subscriptionConfig = context.SubscriptionConfig
	self._states = {}
	self.StateChanged = context.Signal.new()
	return self
end

function SubscriptionService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:RefreshState(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._states[player.UserId] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:RefreshState(player)
	end
end

function SubscriptionService:_buildState(player, active, checkedAt)
	local weeklyClaimedAt = self._persistenceService:GetSubscriptionWeeklyRewardClaimedAt(player)
	local interval = self._subscriptionConfig.WeeklyRewardIntervalSeconds
	local weeklyRewardAvailable = active and (not weeklyClaimedAt or os.time() >= (weeklyClaimedAt + interval))
	local state = {
		subscriptionId = self._subscriptionConfig.SubscriptionId,
		displayName = self._subscriptionConfig.DisplayName,
		isActive = active == true,
		lastCheckedAt = checkedAt,
		weeklyRewardClaimedAt = weeklyClaimedAt,
		weeklyRewardAvailable = weeklyRewardAvailable,
		tokenRewardMultiplier = active and self._subscriptionConfig.TokenRewardMultiplier or 1,
		experienceMultiplier = active and self._subscriptionConfig.ExperienceMultiplier or 1,
		extractionHoldMultiplier = active and self._subscriptionConfig.ExtractionHoldMultiplier or 1,
		dailyBonusTokens = active and self._subscriptionConfig.DailyBonusTokens or 0,
		extraInventorySlots = active and self._subscriptionConfig.ExtraInventorySlots or 0,
	}

	player:SetAttribute("SubscriptionActive", state.isActive)
	player:SetAttribute("SubscriptionWeeklyRewardAvailable", state.weeklyRewardAvailable)
	player:SetAttribute("SubscriptionWeeklyRewardClaimedAt", weeklyClaimedAt or 0)
	player:SetAttribute("SubscriptionTokenRewardMultiplier", state.tokenRewardMultiplier)
	player:SetAttribute("SubscriptionExperienceMultiplier", state.experienceMultiplier)
	player:SetAttribute("SubscriptionExtractionHoldMultiplier", state.extractionHoldMultiplier)
	player:SetAttribute("SubscriptionDailyBonusTokens", state.dailyBonusTokens)
	player:SetAttribute("SubscriptionExtraInventorySlots", state.extraInventorySlots)
	return state
end

function SubscriptionService:RefreshState(player)
	if not player or not player.Parent then
		return nil
	end

	local checkedAt = os.time()
	local active = false
	local statusValue = nil
	local ok, result = pcall(function()
		return MarketplaceService:GetUserSubscriptionStatusAsync(player, self._subscriptionConfig.SubscriptionId)
	end)
	if ok then
		statusValue = result
		active = isSubscribedStatus(result)
	else
		active = self._persistenceService:GetSubscriptionLastKnownActive(player)
	end

	self._persistenceService:SetSubscriptionLastKnownActive(player, active)
	self._persistenceService:SetSubscriptionLastCheckedAt(player, checkedAt)

	local state = self:_buildState(player, active, checkedAt)
	self._states[player.UserId] = state
	if self._remotes then
		self._remotes:FireEventFor(player, self._remoteNames.Events.SubscriptionStateChanged, state)
	end
	self.StateChanged:Fire(player, state, statusValue)
	return state
end

function SubscriptionService:GetState(player)
	if not player then
		return nil
	end

	local cached = self._states[player.UserId]
	if cached then
		return cached
	end

	return self:RefreshState(player)
end

function SubscriptionService:IsActive(player)
	local state = self:GetState(player)
	return state and state.isActive == true or false
end

function SubscriptionService:GetTokenRewardMultiplier(player)
	local state = self:GetState(player)
	return state and state.tokenRewardMultiplier or 1
end

function SubscriptionService:GetExperienceMultiplier(player)
	local state = self:GetState(player)
	return state and state.experienceMultiplier or 1
end

function SubscriptionService:GetExtractionHoldSeconds(player, baseDuration)
	local state = self:GetState(player)
	local multiplier = state and state.extractionHoldMultiplier or 1
	return math.max(1, (baseDuration or 0) * multiplier)
end

function SubscriptionService:GetAdjustedTokenRewardAmount(player, amount)
	local baseAmount = math.max(0, math.floor(amount or 0))
	local multiplier = self:GetTokenRewardMultiplier(player)
	return math.max(0, math.floor((baseAmount * multiplier) + 0.5))
end

function SubscriptionService:GetAdjustedExperienceAmount(player, amount)
	local baseAmount = math.max(0, math.floor(amount or 0))
	local multiplier = self:GetExperienceMultiplier(player)
	return math.max(0, math.floor((baseAmount * multiplier) + 0.5))
end

function SubscriptionService:GetDailyBonusTokens(player)
	local state = self:GetState(player)
	return state and state.dailyBonusTokens or 0
end

function SubscriptionService:GetExtraInventorySlots(player)
	local state = self:GetState(player)
	return state and state.extraInventorySlots or 0
end

function SubscriptionService:GetWeeklyRewardState(player)
	local state = self:GetState(player)
	if not state then
		return {
			lastClaimAt = nil,
			nextClaimAt = 0,
			canClaim = false,
			active = false,
		}
	end

	local lastClaimAt = self._persistenceService:GetSubscriptionWeeklyRewardClaimedAt(player)
	local interval = self._subscriptionConfig.WeeklyRewardIntervalSeconds
	local nextClaimAt = lastClaimAt and (lastClaimAt + interval) or 0
	local canClaim = state.isActive and os.time() >= nextClaimAt
	return {
		lastClaimAt = lastClaimAt,
		nextClaimAt = nextClaimAt,
		canClaim = canClaim,
		active = state.isActive,
	}
end

function SubscriptionService:CanClaimWeeklyReward(player)
	return self:GetWeeklyRewardState(player).canClaim == true
end

function SubscriptionService:MarkWeeklyRewardClaimed(player, timestamp)
	self._persistenceService:SetSubscriptionWeeklyRewardClaimedAt(player, timestamp or os.time())
	self:RefreshState(player)
end

return SubscriptionService
