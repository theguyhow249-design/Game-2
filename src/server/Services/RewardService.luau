local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local RewardService = {}
RewardService.__index = RewardService

function RewardService.new(context)
	local self = setmetatable({}, RewardService)
	self._tokenEconomy = context.TokenEconomy
	self._contracts = context.Contracts
	self._remoteNames = context.RemoteNames
	self._remotes = context.Remotes
	self._tokenService = context.TokenService
	self._persistenceService = context.PersistenceService
	self._skillTreeService = context.SkillTreeService
	self._gamePassService = context.GamePassService
	self._subscriptionConfig = context.SubscriptionConfig
	self._subscriptionService = context.SubscriptionService
	self._leaderboardService = context.LeaderboardService
	self._dailyClaimedAt = {}
	self._groupRewardClaimed = {}
	self._weeklyRewardGranting = {}
	self._groupPredicate = nil
	self._robuxProductMap = {}
	self.DailyRewardGranted = context.Signal.new()
	self.GroupRewardGranted = context.Signal.new()
	self.PurchaseGranted = context.Signal.new()
	self.WeeklyRewardGranted = context.Signal.new()
	return self
end

function RewardService:_bindPlayer(player)
	self._dailyClaimedAt[player.UserId] = self._persistenceService:GetDailyClaimedAt(player)
	self._groupRewardClaimed[player.UserId] = self._persistenceService:HasGroupRewardClaimed(player)
	player:SetAttribute("CanClaimDailyReward", self:CanClaimDailyReward(player))
	player:SetAttribute("DailyRewardClaimed", self._dailyClaimedAt[player.UserId] ~= nil)
	player:SetAttribute("GroupRewardClaimed", self._groupRewardClaimed[player.UserId] == true)
	self:GrantGroupJoinReward(player)
	self:_maybeGrantWeeklyReward(player)
end

function RewardService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:_bindPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._dailyClaimedAt[player.UserId] = nil
		self._groupRewardClaimed[player.UserId] = nil
	end)

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return self:_processReceipt(receiptInfo)
	end

	if self._subscriptionService and self._subscriptionService.StateChanged then
		self._subscriptionService.StateChanged:Connect(function(player)
			self:_maybeGrantWeeklyReward(player)
		end)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		self:_bindPlayer(player)
	end
end

function RewardService:SetGroupEligibilityPredicate(predicate)
	self._groupPredicate = predicate
	if predicate then
		for _, player in ipairs(Players:GetPlayers()) do
			self:GrantGroupJoinReward(player)
		end
	end
end

function RewardService:SetRobuxProductMap(productMap)
	self._robuxProductMap = productMap or {}
end

function RewardService:GetSubscriptionState(player)
	return self._subscriptionService and self._subscriptionService:GetState(player) or nil
end

function RewardService:_getAdjustedTokenRewardAmount(player, amount)
	local rewardAmount = math.max(0, math.floor(amount or 0))
	if self._subscriptionService then
		rewardAmount = self._subscriptionService:GetAdjustedTokenRewardAmount(player, rewardAmount)
	end
	if self._gamePassService then
		rewardAmount = math.max(0, math.floor((rewardAmount * self._gamePassService:GetTokenRewardMultiplier(player)) + 0.5))
	end
	return rewardAmount
end

function RewardService:GetWeeklyRewardState(player)
	if not self._subscriptionService then
		return {
			lastClaimAt = nil,
			nextClaimAt = 0,
			canClaim = false,
			active = false,
		}
	end

	return self._subscriptionService:GetWeeklyRewardState(player)
end

function RewardService:_maybeGrantWeeklyReward(player)
	if not player or not player.Parent or not self._subscriptionService then
		return
	end

	local userId = player.UserId
	if self._weeklyRewardGranting[userId] then
		return
	end

	local weeklyState = self:GetWeeklyRewardState(player)
	if weeklyState.canClaim then
		self:ClaimWeeklyRewardCrate(player)
	end
end

function RewardService:GetDailyRewardState(player)
	local lastClaimAt = self._dailyClaimedAt[player.UserId]
	local nextClaimAt = lastClaimAt and (lastClaimAt + 24 * 60 * 60) or 0
	return self._contracts.makeDailyRewardState(lastClaimAt, nextClaimAt)
end

function RewardService:CanClaimDailyReward(player)
	return self:GetDailyRewardState(player).canClaim
end

function RewardService:ClaimDailyReward(player)
	local state = self:GetDailyRewardState(player)
	if not state.canClaim then
		return false, "already_claimed", state
	end

	local claimedAt = os.time()
	self._dailyClaimedAt[player.UserId] = claimedAt
	self._persistenceService:SetDailyClaimedAt(player, claimedAt)
	player:SetAttribute("CanClaimDailyReward", false)
	player:SetAttribute("DailyRewardClaimed", true)

	local baseReward = self._tokenEconomy.DailyRewardAmount
	local rewardAmount = self:_getAdjustedTokenRewardAmount(player, baseReward)
	local bonusTokens = self._subscriptionService and self._subscriptionService:GetDailyBonusTokens(player) or 0
	self._tokenService:AddTokens(player, rewardAmount, "DailyReward", "daily_reward")
	if bonusTokens > 0 then
		self._tokenService:AddTokens(player, bonusTokens, "SubscriptionReward", "daily_bonus_tokens")
	end
	self.DailyRewardGranted:Fire(player, rewardAmount + bonusTokens)
	if self._remotes then
		self._remotes:FireEventFor(player, self._remoteNames.Events.Notification, {
			userId = player.UserId,
			message = bonusTokens > 0 and ("Daily reward granted: +%d tokens (+%d supporter bonus)"):format(rewardAmount, bonusTokens)
				or ("Daily reward granted: +%d tokens"):format(rewardAmount),
		})
	end

	return true, rewardAmount + bonusTokens, self:GetDailyRewardState(player)
end

function RewardService:GrantGroupJoinReward(player)
	if not self._groupPredicate or not self._groupPredicate(player) then
		return false, "not_eligible"
	end

	if self._groupRewardClaimed[player.UserId] then
		return false, "already_claimed"
	end

	self._groupRewardClaimed[player.UserId] = true
	self._persistenceService:SetGroupRewardClaimed(player, true)
	player:SetAttribute("GroupRewardClaimed", true)
	local rewardAmount = self:_getAdjustedTokenRewardAmount(player, self._tokenEconomy.GroupJoinBonus)
	self._tokenService:AddTokens(player, rewardAmount, "GroupJoin", "group_reward")
	self.GroupRewardGranted:Fire(player, rewardAmount)
	return true, rewardAmount
end

function RewardService:ClaimWeeklyRewardCrate(player)
	local userId = player and player.UserId or nil
	if not player or not player.Parent then
		return false, "inactive", {
			lastClaimAt = nil,
			nextClaimAt = 0,
			canClaim = false,
			active = false,
		}
	end
	if userId and self._weeklyRewardGranting[userId] then
		return false, "busy", self:GetWeeklyRewardState(player)
	end
	if userId then
		self._weeklyRewardGranting[userId] = true
	end

	local function finalize(...)
		if userId then
			self._weeklyRewardGranting[userId] = nil
		end
		return ...
	end

	if not self._subscriptionService or not self._subscriptionService:IsActive(player) then
		return finalize(false, "inactive", self:GetWeeklyRewardState(player))
	end

	local weeklyState = self:GetWeeklyRewardState(player)
	if not weeklyState.canClaim then
		return finalize(false, "already_claimed", weeklyState)
	end

	local crate = self._subscriptionConfig and self._subscriptionConfig.WeeklyRewardCrate or { TokenAmount = 0, ExperienceAmount = 0 }
	local tokenAmount = self:_getAdjustedTokenRewardAmount(player, crate.TokenAmount or 0)
	local experienceAmount = self._subscriptionService:GetAdjustedExperienceAmount(player, crate.ExperienceAmount or 0)
	local claimedAt = os.time()
	self._persistenceService:SetSubscriptionWeeklyRewardClaimedAt(player, claimedAt)
	player:SetAttribute("SubscriptionWeeklyRewardClaimedAt", claimedAt)
	self._tokenService:AddTokens(player, tokenAmount, "SubscriptionReward", "weekly_reward_crate")
	if experienceAmount > 0 and self._skillTreeService and self._skillTreeService.AwardExperience then
		self._skillTreeService:AwardExperience(player, experienceAmount, "SubscriptionWeeklyCrate")
	end
	self.WeeklyRewardGranted:Fire(player, tokenAmount, experienceAmount)
	if self._remotes then
		self._remotes:FireEventFor(player, self._remoteNames.Events.Notification, {
			userId = player.UserId,
			message = ("Weekly supporter crate granted: +%d tokens%s"):format(
				tokenAmount,
				experienceAmount > 0 and (" +%d XP"):format(experienceAmount) or ""
			),
		})
	end
	if self._subscriptionService then
		self._subscriptionService:RefreshState(player)
	end
	return finalize(true, {
		tokens = tokenAmount,
		experience = experienceAmount,
		claimedAt = claimedAt,
	}, self:GetWeeklyRewardState(player))
end

function RewardService:GrantRobuxTokens(player, productId)
	local packName = self._robuxProductMap[productId]
	local reward = packName and self._tokenEconomy.getPackAmount(packName) or nil
	if not reward then
		return false, "missing_product"
	end

	self._tokenService:AddTokens(player, reward, "RobuxPurchase", "robux_purchase")
	if self._leaderboardService then
		self._leaderboardService:AddDonationScore(player, reward)
	end
	self.PurchaseGranted:Fire(player, productId, reward)
	return true, reward
end

function RewardService:_processReceipt(receiptInfo)
	local productId = receiptInfo.ProductId
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local packName = self._robuxProductMap[productId]
	local rewardAmount = packName and self._tokenEconomy.getPackAmount(packName) or nil
	if not rewardAmount then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	self._tokenService:AddTokens(player, rewardAmount, "RobuxPurchase", "robux_purchase")
	if self._leaderboardService then
		self._leaderboardService:AddDonationScore(player, rewardAmount)
	end
	self.PurchaseGranted:Fire(player, productId, rewardAmount)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return RewardService
