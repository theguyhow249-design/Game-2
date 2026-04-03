local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PersistenceService = {}
PersistenceService.__index = PersistenceService

local DATASTORE_NAME = "ZombieSurvivalPlayerData_v1"

local function getDayKey(timestamp)
	return math.floor((timestamp or os.time()) / 86400)
end

local function getWeekKey(timestamp)
	return math.floor((timestamp or os.time()) / 604800)
end

local function getMonthKey(timestamp)
	local utc = os.date("!*t", timestamp or os.time())
	return (utc.year * 100) + utc.month
end

local function defaultTrackedStats()
	return {
		missionsCompleted = 0,
		zombiesDefeated = 0,
		timePlayedMinutes = 0,
		donationScore = 0,
	}
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local result = {}
	for key, entry in pairs(value) do
		result[key] = deepCopy(entry)
	end
	return result
end

local function defaultActivityStats()
	return {
		parkourBestMs = 0,
		rangeBestScore = 0,
		salvageBestMs = 0,
		trainingBestScore = 0,
		parkourClears = 0,
		rangeRuns = 0,
		salvageClears = 0,
		trainingClears = 0,
		parkourLevel = 0,
		rangeLevel = 0,
		salvageLevel = 0,
		trainingLevel = 0,
		secrets = {},
		achievements = {},
		rewards = {},
	}
end

function PersistenceService.new(context)
	local self = setmetatable({}, PersistenceService)
	self._tokenEconomy = context.TokenEconomy
	self._missionConfig = context.MissionConfig
	self._remoteNames = context.RemoteNames
	self._remotes = context.Remotes
	self._profiles = {}
	self._dirty = {}
	self._saveQueued = {}
	self._dataStore = nil
	self._persistenceEnabled = true
	self._persistenceReason = "Saving"
	self._lastPersistenceError = nil

	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok then
		self._dataStore = store
	else
		self._persistenceEnabled = false
		self._persistenceReason = "Offline: datastore unavailable"
		self._lastPersistenceError = tostring(store)
	end

	return self
end

function PersistenceService:_isApiAccessError(errorText)
	local message = string.lower(tostring(errorText or ""))
	return string.find(message, "studioaccesstoapisnotallowed", 1, true) ~= nil
		or string.find(message, "cannot write to datastore from studio if api access is not enabled", 1, true) ~= nil
		or string.find(message, "cannot read from datastore from studio if api access is not enabled", 1, true) ~= nil
end

function PersistenceService:_setPersistenceState(enabled, reason, errorText, player)
	self._persistenceEnabled = enabled == true
	self._persistenceReason = reason or (self._persistenceEnabled and "Saving" or "Offline")
	self._lastPersistenceError = errorText
	if player then
		self:_emitPersistenceState(player)
	else
		for _, connectedPlayer in ipairs(Players:GetPlayers()) do
			self:_emitPersistenceState(connectedPlayer)
		end
	end
end

function PersistenceService:_emitPersistenceState(player)
	if not self._remotes or not player then
		return
	end

	self._remotes:FireEventFor(player, self._remoteNames.Events.PersistenceStateChanged, {
		enabled = self._persistenceEnabled and self._dataStore ~= nil,
		reason = self._persistenceReason,
		lastError = self._lastPersistenceError,
		inStudio = RunService:IsStudio(),
	})
end

function PersistenceService:_setPersistenceEnabled(enabled, player)
	self:_setPersistenceState(enabled, enabled and "Saving" or "Offline", nil, player)
end

function PersistenceService:_defaultProfile()
	return {
		tokens = self._tokenEconomy.StartingDeployTokens,
		dailyClaimedAt = nil,
		groupRewardClaimed = false,
		unlocks = deepCopy(self._missionConfig.DefaultWeaponUnlocks),
		equippedWeapon = self._missionConfig.DefaultWeaponId,
		equippedCosmetic = nil,
		weaponExperience = {
			[self._missionConfig.DefaultWeaponId] = 0,
		},
		experience = 0,
		level = 1,
		skillPoints = 0,
		skills = {},
		subscription = {
			weeklyRewardClaimedAt = nil,
			lastKnownActive = false,
			lastCheckedAt = nil,
		},
		stats = {
			allTime = defaultTrackedStats(),
			monthly = defaultTrackedStats(),
			weekly = defaultTrackedStats(),
			daily = defaultTrackedStats(),
			monthKey = getMonthKey(),
			weekKey = getWeekKey(),
			dayKey = getDayKey(),
		},
		dailyOps = {
			dayKey = 0,
			progress = {},
			claimed = {},
		},
		claimedRewards = {},
		activities = defaultActivityStats(),
	}
end

function PersistenceService:_applyActivityAttributes(player, activities)
	if not player then
		return
	end

	local stats = activities or defaultActivityStats()
	player:SetAttribute("ParkourBestMs", math.max(0, math.floor(stats.parkourBestMs or 0)))
	player:SetAttribute("RangeBestScore", math.max(0, math.floor(stats.rangeBestScore or 0)))
	player:SetAttribute("SalvageBestMs", math.max(0, math.floor(stats.salvageBestMs or 0)))
	player:SetAttribute("TrainingBestScore", math.max(0, math.floor(stats.trainingBestScore or 0)))
	player:SetAttribute("ParkourClears", math.max(0, math.floor(stats.parkourClears or 0)))
	player:SetAttribute("RangeRuns", math.max(0, math.floor(stats.rangeRuns or 0)))
	player:SetAttribute("SalvageClears", math.max(0, math.floor(stats.salvageClears or 0)))
	player:SetAttribute("TrainingClears", math.max(0, math.floor(stats.trainingClears or 0)))
	player:SetAttribute("ParkourLevel", math.max(0, math.floor(stats.parkourLevel or 0)))
	player:SetAttribute("RangeLevel", math.max(0, math.floor(stats.rangeLevel or 0)))
	player:SetAttribute("SalvageLevel", math.max(0, math.floor(stats.salvageLevel or 0)))
	player:SetAttribute("TrainingLevel", math.max(0, math.floor(stats.trainingLevel or 0)))
end

function PersistenceService:_normalizeStats(profile)
	profile.stats = profile.stats or {}
	local stats = profile.stats

	if stats.missionsCompleted ~= nil or stats.zombiesDefeated ~= nil or stats.timePlayedMinutes ~= nil or stats.donationScore ~= nil then
		local legacyStats = {
			missionsCompleted = math.max(0, math.floor(tonumber(stats.missionsCompleted) or 0)),
			zombiesDefeated = math.max(0, math.floor(tonumber(stats.zombiesDefeated) or 0)),
			timePlayedMinutes = math.max(0, math.floor(tonumber(stats.timePlayedMinutes) or 0)),
			donationScore = math.max(0, math.floor(tonumber(stats.donationScore) or 0)),
		}
		stats = {
			allTime = legacyStats,
			monthly = defaultTrackedStats(),
			weekly = defaultTrackedStats(),
			daily = defaultTrackedStats(),
			monthKey = getMonthKey(),
			weekKey = getWeekKey(),
			dayKey = getDayKey(),
		}
		profile.stats = stats
	end

	stats.allTime = stats.allTime or defaultTrackedStats()
	stats.monthly = stats.monthly or defaultTrackedStats()
	stats.weekly = stats.weekly or defaultTrackedStats()
	stats.daily = stats.daily or defaultTrackedStats()
	stats.monthKey = tonumber(stats.monthKey) or getMonthKey()
	stats.weekKey = tonumber(stats.weekKey) or getWeekKey()
	stats.dayKey = tonumber(stats.dayKey) or getDayKey()

	local currentMonthKey = getMonthKey()
	local currentWeekKey = getWeekKey()
	local currentDayKey = getDayKey()
	if stats.monthKey ~= currentMonthKey then
		stats.monthly = defaultTrackedStats()
		stats.monthKey = currentMonthKey
	end
	if stats.weekKey ~= currentWeekKey then
		stats.weekly = defaultTrackedStats()
		stats.weekKey = currentWeekKey
	end
	if stats.dayKey ~= currentDayKey then
		stats.daily = defaultTrackedStats()
		stats.dayKey = currentDayKey
	end

	for _, bucketName in ipairs({ "allTime", "monthly", "weekly", "daily" }) do
		local bucket = stats[bucketName]
		for statName, defaultValue in pairs(defaultTrackedStats()) do
			bucket[statName] = math.max(0, math.floor(tonumber(bucket[statName]) or defaultValue))
		end
	end

	return stats
end

function PersistenceService:_getKey(userId)
	return ("player_%d"):format(userId)
end

function PersistenceService:_scheduleSave(userId)
	if self._saveQueued[userId] then
		return
	end

	self._saveQueued[userId] = true
	task.delay(8, function()
		self._saveQueued[userId] = nil
		local player = Players:GetPlayerByUserId(userId)
		if player then
			self:SavePlayer(player)
		end
	end)
end

function PersistenceService:_markDirty(userId)
	self._dirty[userId] = true
	self:_scheduleSave(userId)
end

function PersistenceService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:BindPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:SavePlayer(player)
		self._profiles[player.UserId] = nil
		self._dirty[player.UserId] = nil
		self._saveQueued[player.UserId] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:BindPlayer(player)
	end

	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(Players:GetPlayers()) do
				if self._dirty[player.UserId] then
					self:SavePlayer(player)
				end
			end
		end
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			self:SavePlayer(player)
		end
	end)
end

function PersistenceService:BindPlayer(player)
	local profile = self:_defaultProfile()

	if self._dataStore then
		local ok, data = pcall(function()
			return self._dataStore:GetAsync(self:_getKey(player.UserId))
		end)
		if ok and type(data) == "table" then
			for key, value in pairs(data) do
				if type(profile[key]) == "table" and type(value) == "table" then
					for nestedKey, nestedValue in pairs(value) do
						profile[key][nestedKey] = nestedValue
					end
				else
					profile[key] = value
				end
			end
		elseif not ok then
			if self:_isApiAccessError(data) then
				self:_setPersistenceState(false, "Offline: API access disabled", tostring(data), player)
			else
				self:_setPersistenceState(true, "Saving (retrying)", tostring(data), player)
			end
		elseif RunService:IsStudio() then
			self:_setPersistenceState(false, "Offline: API access disabled", "DataStore load failed", player)
		end
	end

	if not profile.unlocks[self._missionConfig.DefaultWeaponId] then
		profile.unlocks[self._missionConfig.DefaultWeaponId] = true
	end

	self:_normalizeStats(profile)

	profile.weaponExperience = profile.weaponExperience or {}
	if profile.weaponExperience[self._missionConfig.DefaultWeaponId] == nil then
		profile.weaponExperience[self._missionConfig.DefaultWeaponId] = 0
	end

	if not self._missionConfig.Weapons[profile.equippedWeapon] then
		profile.equippedWeapon = self._missionConfig.DefaultWeaponId
	end

	self._profiles[player.UserId] = profile
	profile.activities = profile.activities or defaultActivityStats()
	for key, value in pairs(defaultActivityStats()) do
		if profile.activities[key] == nil then
			profile.activities[key] = deepCopy(value)
		end
	end
	self:_applyActivityAttributes(player, profile.activities)
	self:_emitPersistenceState(player)
end

function PersistenceService:GetProfile(player)
	if not player or type(player.UserId) ~= "number" then
		warn("[PersistenceService] GetProfile called without a valid player. Returning a temporary default profile.")
		return self:_defaultProfile()
	end

	if not self._profiles[player.UserId] then
		self:BindPlayer(player)
	end
	return self._profiles[player.UserId]
end

function PersistenceService:GetTokenBalance(player)
	return self:GetProfile(player).tokens
end

function PersistenceService:SetTokenBalance(player, amount)
	self:GetProfile(player).tokens = math.max(0, math.floor(amount))
	self:_markDirty(player.UserId)
end

function PersistenceService:GetDailyClaimedAt(player)
	return self:GetProfile(player).dailyClaimedAt
end

function PersistenceService:SetDailyClaimedAt(player, timestamp)
	self:GetProfile(player).dailyClaimedAt = timestamp
	self:_markDirty(player.UserId)
end

function PersistenceService:HasGroupRewardClaimed(player)
	return self:GetProfile(player).groupRewardClaimed == true
end

function PersistenceService:SetGroupRewardClaimed(player, claimed)
	self:GetProfile(player).groupRewardClaimed = claimed == true
	self:_markDirty(player.UserId)
end

function PersistenceService:GetUnlocks(player)
	return self:GetProfile(player).unlocks
end

function PersistenceService:IsUnlocked(player, itemId)
	return self:GetProfile(player).unlocks[itemId] == true
end

function PersistenceService:UnlockItem(player, itemId)
	self:GetProfile(player).unlocks[itemId] = true
	self:_markDirty(player.UserId)
end

function PersistenceService:GetEquippedWeapon(player)
	return self:GetProfile(player).equippedWeapon
end

function PersistenceService:SetEquippedWeapon(player, itemId)
	self:GetProfile(player).equippedWeapon = itemId
	self:_markDirty(player.UserId)
end

function PersistenceService:GetEquippedCosmetic(player)
	return self:GetProfile(player).equippedCosmetic
end

function PersistenceService:SetEquippedCosmetic(player, itemId)
	self:GetProfile(player).equippedCosmetic = itemId
	self:_markDirty(player.UserId)
end

function PersistenceService:GetWeaponExperienceMap(player)
	local profile = self:GetProfile(player)
	profile.weaponExperience = profile.weaponExperience or {}
	return profile.weaponExperience
end

function PersistenceService:GetWeaponExperience(player, weaponId)
	local targetWeaponId = weaponId or self._missionConfig.DefaultWeaponId
	return math.max(0, math.floor(self:GetWeaponExperienceMap(player)[targetWeaponId] or 0))
end

function PersistenceService:AddWeaponExperience(player, weaponId, amount)
	if not weaponId or not self._missionConfig.Weapons[weaponId] then
		return
	end

	local profile = self:GetProfile(player)
	profile.weaponExperience = profile.weaponExperience or {}
	profile.weaponExperience[weaponId] = math.max(0, math.floor((profile.weaponExperience[weaponId] or 0) + (amount or 0)))
	self:_markDirty(player.UserId)
end

function PersistenceService:IncrementStat(player, statName, amount)
	local profile = self:GetProfile(player)
	local stats = self:_normalizeStats(profile)
	local delta = math.floor(amount or 0)
	stats.allTime[statName] = math.max(0, math.floor((stats.allTime[statName] or 0) + delta))
	stats.monthly[statName] = math.max(0, math.floor((stats.monthly[statName] or 0) + delta))
	stats.weekly[statName] = math.max(0, math.floor((stats.weekly[statName] or 0) + delta))
	stats.daily[statName] = math.max(0, math.floor((stats.daily[statName] or 0) + delta))
	self:_markDirty(player.UserId)
end

function PersistenceService:GetStats(player)
	return self:_normalizeStats(self:GetProfile(player)).allTime
end

function PersistenceService:GetStatsWindow(player, windowName)
	local stats = self:_normalizeStats(self:GetProfile(player))
	if windowName == "daily" then
		return stats.daily
	elseif windowName == "weekly" then
		return stats.weekly
	elseif windowName == "monthly" then
		return stats.monthly
	end
	return stats.allTime
end

function PersistenceService:GetDailyOpsState(player)
	local profile = self:GetProfile(player)
	profile.dailyOps = profile.dailyOps or {
		dayKey = 0,
		progress = {},
		claimed = {},
	}
	profile.dailyOps.progress = profile.dailyOps.progress or {}
	profile.dailyOps.claimed = profile.dailyOps.claimed or {}
	return profile.dailyOps
end

function PersistenceService:SetDailyOpsState(player, dayKey, progress, claimed)
	local profile = self:GetProfile(player)
	profile.dailyOps = {
		dayKey = tonumber(dayKey) or 0,
		progress = type(progress) == "table" and progress or {},
		claimed = type(claimed) == "table" and claimed or {},
	}
	self:_markDirty(player.UserId)
end

function PersistenceService:GetExperience(player)
	return math.max(0, math.floor(self:GetProfile(player).experience or 0))
end

function PersistenceService:SetExperience(player, amount)
	self:GetProfile(player).experience = math.max(0, math.floor(amount or 0))
	self:_markDirty(player.UserId)
end

function PersistenceService:GetLevel(player)
	return math.max(1, math.floor(self:GetProfile(player).level or 1))
end

function PersistenceService:SetLevel(player, amount)
	self:GetProfile(player).level = math.max(1, math.floor(amount or 1))
	self:_markDirty(player.UserId)
end

function PersistenceService:GetSkillPoints(player)
	return math.max(0, math.floor(self:GetProfile(player).skillPoints or 0))
end

function PersistenceService:SetSkillPoints(player, amount)
	self:GetProfile(player).skillPoints = math.max(0, math.floor(amount or 0))
	self:_markDirty(player.UserId)
end

function PersistenceService:GetSkills(player)
	local profile = self:GetProfile(player)
	profile.skills = profile.skills or {}
	return profile.skills
end

function PersistenceService:GetSubscription(player)
	local profile = self:GetProfile(player)
	profile.subscription = profile.subscription or {
		weeklyRewardClaimedAt = nil,
		lastKnownActive = false,
		lastCheckedAt = nil,
	}
	return profile.subscription
end

function PersistenceService:GetSubscriptionWeeklyRewardClaimedAt(player)
	return self:GetSubscription(player).weeklyRewardClaimedAt
end

function PersistenceService:SetSubscriptionWeeklyRewardClaimedAt(player, timestamp)
	self:GetSubscription(player).weeklyRewardClaimedAt = timestamp
	self:_markDirty(player.UserId)
end

function PersistenceService:GetSubscriptionLastKnownActive(player)
	return self:GetSubscription(player).lastKnownActive == true
end

function PersistenceService:SetSubscriptionLastKnownActive(player, isActive)
	self:GetSubscription(player).lastKnownActive = isActive == true
	self:_markDirty(player.UserId)
end

function PersistenceService:GetSubscriptionLastCheckedAt(player)
	return self:GetSubscription(player).lastCheckedAt
end

function PersistenceService:SetSubscriptionLastCheckedAt(player, timestamp)
	self:GetSubscription(player).lastCheckedAt = timestamp
	self:_markDirty(player.UserId)
end

function PersistenceService:GetSkillRank(player, skillId)
	return math.max(0, math.floor(self:GetSkills(player)[skillId] or 0))
end

function PersistenceService:SetSkillRank(player, skillId, rank)
	self:GetSkills(player)[skillId] = math.max(0, math.floor(rank or 0))
	self:_markDirty(player.UserId)
end

function PersistenceService:GetActivityStats(player)
	local profile = self:GetProfile(player)
	profile.activities = profile.activities or defaultActivityStats()
	for key, value in pairs(defaultActivityStats()) do
		if profile.activities[key] == nil then
			profile.activities[key] = deepCopy(value)
		end
	end
	return profile.activities
end

function PersistenceService:SetActivityStat(player, statName, amount)
	local stats = self:GetActivityStats(player)
	local value = math.max(0, math.floor(amount or 0))
	stats[statName] = value
	self:_applyActivityAttributes(player, stats)
	self:_markDirty(player.UserId)
	return value
end

function PersistenceService:IncrementActivityStat(player, statName, amount)
	local stats = self:GetActivityStats(player)
	local current = math.max(0, math.floor(stats[statName] or 0))
	return self:SetActivityStat(player, statName, current + math.floor(amount or 0))
end

function PersistenceService:UpdateActivityBest(player, statName, amount, lowerIsBetter)
	local stats = self:GetActivityStats(player)
	local candidate = math.max(0, math.floor(amount or 0))
	local current = math.max(0, math.floor(stats[statName] or 0))
	local improved = false
	if lowerIsBetter then
		improved = candidate > 0 and (current <= 0 or candidate < current)
	else
		improved = candidate > current
	end
	if improved then
		current = self:SetActivityStat(player, statName, candidate)
	end
	return improved, current
end

function PersistenceService:HasActivityFlag(player, bucketName, flagName)
	local stats = self:GetActivityStats(player)
	local bucket = stats[bucketName]
	return type(bucket) == "table" and bucket[flagName] == true
end

function PersistenceService:SetActivityFlag(player, bucketName, flagName, value)
	local stats = self:GetActivityStats(player)
	stats[bucketName] = type(stats[bucketName]) == "table" and stats[bucketName] or {}
	stats[bucketName][flagName] = value == true
	self:_markDirty(player.UserId)
	return stats[bucketName][flagName]
end

function PersistenceService:SavePlayer(player)
	if not player then
		return false
	end

	local userId = player.UserId
	if not self._dirty[userId] then
		return true
	end

	local profile = self._profiles[userId]
	if not profile then
		return false
	end

	if not self._persistenceEnabled or not self._dataStore then
		self._dirty[userId] = nil
		return true
	end

	local payload = deepCopy(profile)
	local ok, errorText = pcall(function()
		self._dataStore:UpdateAsync(self:_getKey(userId), function()
			return payload
		end)
	end)

	if ok then
		self._dirty[userId] = nil
	else
		errorText = tostring(errorText)
		if self:_isApiAccessError(errorText) then
			self:_setPersistenceState(false, "Offline: API access disabled", errorText, player)
			self._dirty[userId] = nil
		else
			self:_setPersistenceState(true, "Saving (retrying)", errorText, player)
			self._dirty[userId] = true
			self:_scheduleSave(userId)
		end
	end

	return ok
end

function PersistenceService:IsPersistenceEnabled()
	return self._persistenceEnabled and self._dataStore ~= nil
end

function PersistenceService:GetPersistenceState()
	return {
		enabled = self:IsPersistenceEnabled(),
		reason = self._persistenceReason,
		lastError = self._lastPersistenceError,
	}
end

return PersistenceService
