local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ActivityService = {}
ActivityService.__index = ActivityService

local PARKOUR_CHECKPOINT_COUNT = 5
local TRAINING_HURDLE_COUNT = 3
local TRAINING_TARGET_COUNT = 3
local RANGE_DURATION = 20
local RANGE_REPEAT_GRACE = 0.45
local SALVAGE_CACHE_COUNT = 3
local TOUCH_COOLDOWN = 0.75
local ACTIVITY_THRESHOLDS = {
	parkour = { 1, 3, 6 },
	training = { 1, 4, 8 },
	range = { 6, 12, 20 },
	salvage = { 1, 3, 6 },
}
local ACTIVITY_REWARDS = {
	parkour = {
		[2] = { itemId = "cosmetic_rooftop_glow", message = "Rooftop Glow unlocked." },
		[3] = { tokens = 6, message = "Parkour master cache secured." },
	},
	training = {
		[2] = { itemId = "cosmetic_cadet_stripe", message = "Cadet Stripe unlocked." },
		[3] = { tokens = 6, message = "Training command cache secured." },
	},
	range = {
		[2] = { itemId = "cosmetic_deadeye_trace", message = "Deadeye Trace unlocked." },
		[3] = { tokens = 8, message = "Deadeye locker unlocked." },
	},
	salvage = {
		[2] = { itemId = "cosmetic_salvage_signal", message = "Salvage Signal unlocked." },
		[3] = { tokens = 8, message = "Salvage reserve cache secured." },
	},
}
local SECRET_REWARDS = {
	TrainingSecret = {
		key = "training_secret",
		label = "Hidden Locker",
		tokens = 3,
	},
	ParkourSecret = {
		key = "parkour_secret",
		label = "Roof Stash",
		tokens = 3,
	},
	RangeSecret = {
		key = "range_secret",
		label = "Deadeye Cache",
		tokens = 3,
	},
	SalvageSecret = {
		key = "salvage_secret",
		label = "Smuggler Crate",
		tokens = 3,
	},
}

function ActivityService.new(context)
	local self = setmetatable({}, ActivityService)
	self._gameFlowConfig = context.GameFlowConfig
	self._flowService = context.FlowService
	self._inventoryService = context.InventoryService
	self._persistenceService = context.PersistenceService
	self._skillTreeService = context.SkillTreeService
	self._tokenService = context.TokenService
	self._remoteNames = context.RemoteNames
	self._remotes = context.Remotes
	self._parkourSessions = {}
	self._trainingSessions = {}
	self._rangeSessions = {}
	self._salvageSessions = {}
	self._touchDebounces = {}
	return self
end

function ActivityService:Start()
	Players.PlayerRemoving:Connect(function(player)
		self._parkourSessions[player.UserId] = nil
		self._trainingSessions[player.UserId] = nil
		self._rangeSessions[player.UserId] = nil
		self._salvageSessions[player.UserId] = nil
		self._touchDebounces[player.UserId] = nil
	end)

	task.defer(function()
		self:_bindLobbyActivities()
	end)
end

function ActivityService:_notify(player, message)
	if not self._remotes or not player or not message then
		return
	end
	self._remotes:FireEventFor(player, self._remoteNames.Events.Notification, {
		userId = player.UserId,
		message = tostring(message),
	})
end

function ActivityService:_canUseLobbyActivity(player)
	if not player or player.Parent ~= Players then
		return false
	end
	if self._flowService and self._flowService:GetPhase() ~= "Lobby" then
		return false
	end
	if player:GetAttribute("InMission") == true then
		return false
	end
	if player:GetAttribute("InDuel") == true or player:GetAttribute("InDuelQueue") == true then
		return false
	end
	return true
end

function ActivityService:_getLobbyRoot()
	return Workspace:FindFirstChild(self._gameFlowConfig.LobbyName)
end

function ActivityService:_getPlaza()
	local lobby = self:_getLobbyRoot()
	return lobby and lobby:FindFirstChild("OpenSkyLobby")
end

function ActivityService:_resolvePlayerFromHit(hit)
	local character = hit and hit.Parent
	if not character then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

function ActivityService:_isTouchReady(player, key, cooldown)
	local userId = player.UserId
	self._touchDebounces[userId] = self._touchDebounces[userId] or {}
	local now = os.clock()
	local readyAt = self._touchDebounces[userId][key] or 0
	if now < readyAt then
		return false
	end
	self._touchDebounces[userId][key] = now + (cooldown or TOUCH_COOLDOWN)
	return true
end

function ActivityService:_clearActivitySession(userId, exceptKey)
	if exceptKey ~= "parkour" then
		self._parkourSessions[userId] = nil
	end
	if exceptKey ~= "training" then
		self._trainingSessions[userId] = nil
	end
	if exceptKey ~= "range" then
		self._rangeSessions[userId] = nil
	end
	if exceptKey ~= "salvage" then
		self._salvageSessions[userId] = nil
	end
end

function ActivityService:_resetTouchDebounces(player, prefixes)
	if not player or type(prefixes) ~= "table" then
		return
	end
	local touches = self._touchDebounces[player.UserId]
	if not touches then
		return
	end
	for key in pairs(touches) do
		for _, prefix in ipairs(prefixes) do
			if string.find(key, prefix, 1, true) == 1 then
				touches[key] = nil
				break
			end
		end
	end
end

function ActivityService:_awardActivityTokens(player, baseAmount, reason)
	local amount = math.max(0, math.floor(baseAmount or 0))
	if amount <= 0 then
		return 0
	end
	self._tokenService:AddTokens(player, amount, "ActivityReward", reason or "activity_reward")
	return amount
end

function ActivityService:_awardActivityExperience(player, baseAmount, reason)
	if not self._skillTreeService then
		return 0
	end
	local amount = math.max(0, math.floor(baseAmount or 0))
	if amount <= 0 then
		return 0
	end
	local _, result = self._skillTreeService:AwardExperience(player, amount, reason or "activity_reward")
	return result and math.max(0, math.floor(result.awarded or 0)) or 0
end

function ActivityService:_emitProgression(player)
	if not (self._remotes and self._inventoryService and player) then
		return
	end
	self._remotes:FireEventFor(player, self._remoteNames.Events.ProgressionUpdated, self._inventoryService:BuildProgressionPayload(player))
end

function ActivityService:_grantUnlockReward(player, itemId, reasonLabel)
	if not (self._inventoryService and itemId and itemId ~= "") then
		return false
	end
	if self._inventoryService:IsUnlocked(player, itemId) then
		return false
	end
	self._inventoryService:UnlockItem(player, itemId)
	if string.find(itemId, "cosmetic_", 1, true) == 1 then
		self._inventoryService:EquipCosmetic(player, itemId)
	end
	self:_emitProgression(player)
	self:_notify(player, reasonLabel or "Exclusive reward unlocked.")
	return true
end

function ActivityService:_computeActivityLevel(activityKey, value)
	local thresholds = ACTIVITY_THRESHOLDS[activityKey] or {}
	local level = 0
	for _, threshold in ipairs(thresholds) do
		if value >= threshold then
			level += 1
		end
	end
	return level
end

function ActivityService:_unlockActivityAchievement(player, achievementKey, label)
	if self._persistenceService:HasActivityFlag(player, "achievements", achievementKey) then
		return false
	end
	self._persistenceService:SetActivityFlag(player, "achievements", achievementKey, true)
	self:_notify(player, ("Badge unlocked: %s"):format(label))
	return true
end

function ActivityService:_applyActivityProgression(player, activityKey, currentValue)
	local levelStatName = activityKey .. "Level"
	local currentLevel = math.max(0, math.floor((self._persistenceService:GetActivityStats(player)[levelStatName] or 0)))
	local nextLevel = self:_computeActivityLevel(activityKey, currentValue)
	if nextLevel <= currentLevel then
		return currentLevel
	end

	self._persistenceService:SetActivityStat(player, levelStatName, nextLevel)
	for unlockedLevel = currentLevel + 1, nextLevel do
		self:_unlockActivityAchievement(player, activityKey .. "_level_" .. tostring(unlockedLevel), ("%s Lv.%d"):format(string.upper(activityKey), unlockedLevel))
		local reward = ACTIVITY_REWARDS[activityKey] and ACTIVITY_REWARDS[activityKey][unlockedLevel] or nil
		if reward then
			if reward.itemId and not self._persistenceService:HasActivityFlag(player, "rewards", reward.itemId) then
				self._persistenceService:SetActivityFlag(player, "rewards", reward.itemId, true)
				self:_grantUnlockReward(player, reward.itemId, reward.message)
			end
			if reward.tokens and reward.tokens > 0 then
				local tokens = self:_awardActivityTokens(player, reward.tokens, activityKey .. "_level_reward")
				if tokens > 0 then
					self:_notify(player, ("%s +%d tokens"):format(reward.message or "Milestone reward", tokens))
				end
			end
		end
	end
	return nextLevel
end

function ActivityService:_checkSecretMastery(player)
	local foundCount = 0
	for _, info in pairs(SECRET_REWARDS) do
		if self._persistenceService:HasActivityFlag(player, "secrets", info.key) then
			foundCount += 1
		end
	end
	if foundCount < 4 or self._persistenceService:HasActivityFlag(player, "rewards", "cosmetic_cipher_sigil") then
		return
	end
	self._persistenceService:SetActivityFlag(player, "rewards", "cosmetic_cipher_sigil", true)
	self:_grantUnlockReward(player, "cosmetic_cipher_sigil", "Cipher Sigil unlocked for finding every bunker secret.")
	self:_unlockActivityAchievement(player, "secret_mastery", "Secret Mastery")
end

function ActivityService:_claimSecret(player, secretName)
	local secretInfo = SECRET_REWARDS[secretName]
	if not secretInfo or not self:_canUseLobbyActivity(player) then
		return
	end
	if self._persistenceService:HasActivityFlag(player, "secrets", secretInfo.key) then
		return
	end
	self._persistenceService:SetActivityFlag(player, "secrets", secretInfo.key, true)
	local tokens = self:_awardActivityTokens(player, secretInfo.tokens, "activity_secret")
	self:_unlockActivityAchievement(player, "secret_" .. secretInfo.key, secretInfo.label)
	self:_notify(player, ("%s found. +%d tokens"):format(secretInfo.label, tokens))
	self:_checkSecretMastery(player)
end

function ActivityService:_formatSecondsFromMs(milliseconds)
	local totalMs = math.max(0, math.floor(milliseconds or 0))
	return ("%.2fs"):format(totalMs / 1000)
end

function ActivityService:_flashRangeTarget(targetPart)
	if not targetPart then
		return
	end
	local originalTransparency = targetPart.Transparency
	targetPart.Transparency = 0.02
	task.delay(0.14, function()
		if targetPart.Parent then
			targetPart.Transparency = originalTransparency
		end
	end)
end

function ActivityService:_startParkour(player)
	if not self:_canUseLobbyActivity(player) then
		return
	end

	self:_clearActivitySession(player.UserId, "parkour")
	self:_resetTouchDebounces(player, { "parkour_checkpoint_", "parkour_finish" })
	self._parkourSessions[player.UserId] = {
		startedAt = os.clock(),
		nextCheckpoint = 1,
	}
	self:_notify(player, "Parkour run started. Hit every platform in order, then reach the roof.")
end

function ActivityService:_hitParkourCheckpoint(player, checkpointIndex)
	local session = self._parkourSessions[player.UserId]
	if not session or not self:_canUseLobbyActivity(player) then
		return
	end
	if checkpointIndex ~= session.nextCheckpoint then
		return
	end

	session.nextCheckpoint += 1
	if checkpointIndex < PARKOUR_CHECKPOINT_COUNT then
		self:_notify(player, ("Parkour checkpoint %d/%d."):format(checkpointIndex, PARKOUR_CHECKPOINT_COUNT))
	end
end

function ActivityService:_finishParkour(player)
	local session = self._parkourSessions[player.UserId]
	self._parkourSessions[player.UserId] = nil
	if not session or not self:_canUseLobbyActivity(player) then
		return
	end
	if session.nextCheckpoint <= PARKOUR_CHECKPOINT_COUNT then
		self:_notify(player, "Parkour failed. Clear the full route before claiming the finish.")
		return
	end

	local elapsedMs = math.max(0, math.floor((os.clock() - session.startedAt) * 1000))
	if elapsedMs < 2500 then
		self:_notify(player, "Parkour run invalidated. Stay on the full route.")
		return
	end

	local clears = self._persistenceService:IncrementActivityStat(player, "parkourClears", 1)
	local improved, bestMs = self._persistenceService:UpdateActivityBest(player, "parkourBestMs", elapsedMs, true)
	self:_applyActivityProgression(player, "parkour", clears)
	self:_unlockActivityAchievement(player, "parkour_clear", "Rooftop Scout")
	local reward = self:_awardActivityTokens(player, improved and 3 or 2, improved and "parkour_personal_best" or "parkour_complete")
	local xpAward = self:_awardActivityExperience(player, improved and 18 or 12, improved and "parkour_personal_best" or "parkour_complete")
	self:_notify(
		player,
		("Parkour clear: %s. Best: %s. +%d tokens +%d XP%s"):format(
			self:_formatSecondsFromMs(elapsedMs),
			self:_formatSecondsFromMs(bestMs),
			reward,
			xpAward,
			improved and " [PB]" or ""
		)
	)
end

function ActivityService:_ensureTrainingSession(player)
	if not self:_canUseLobbyActivity(player) then
		return nil
	end
	local session = self._trainingSessions[player.UserId]
	if session then
		return session
	end
	session = {
		startedAt = os.clock(),
		hurdles = {},
		targets = {},
	}
	self._trainingSessions[player.UserId] = session
	self:_notify(player, "Training drill started. Clear all hurdles and tag every target.")
	return session
end

function ActivityService:_startTraining(player)
	if not self:_canUseLobbyActivity(player) then
		return
	end

	self:_clearActivitySession(player.UserId, "training")
	self:_resetTouchDebounces(player, { "training_hurdle_", "training_hurdle_trigger_" })
	self._trainingSessions[player.UserId] = {
		startedAt = os.clock(),
		hurdles = {},
		targets = {},
	}
	self:_notify(player, "Training drill started. Clear all hurdles and tag every target.")
end

function ActivityService:_recordTrainingHurdle(player, hurdleIndex)
	local session = self:_ensureTrainingSession(player)
	if not session or session.hurdles[hurdleIndex] then
		return
	end
	session.hurdles[hurdleIndex] = true
	local total = 0
	for _ in pairs(session.hurdles) do
		total += 1
	end
	self:_notify(player, ("Training hurdle %d/%d."):format(total, TRAINING_HURDLE_COUNT))
end

function ActivityService:_recordTrainingTarget(player, targetIndex, targetPart)
	local session = self:_ensureTrainingSession(player)
	if not session or session.targets[targetIndex] then
		return
	end
	session.targets[targetIndex] = true
	self:_flashRangeTarget(targetPart)
	local targetCount = 0
	for _ in pairs(session.targets) do
		targetCount += 1
	end
	if targetCount < TRAINING_TARGET_COUNT then
		self:_notify(player, ("Training targets %d/%d."):format(targetCount, TRAINING_TARGET_COUNT))
	end

	local hurdleCount = 0
	for _ in pairs(session.hurdles) do
		hurdleCount += 1
	end
	if hurdleCount >= TRAINING_HURDLE_COUNT and targetCount >= TRAINING_TARGET_COUNT then
		self:_finishTraining(player)
	end
end

function ActivityService:_finishTraining(player)
	local session = self._trainingSessions[player.UserId]
	self._trainingSessions[player.UserId] = nil
	if not session or not self:_canUseLobbyActivity(player) then
		return
	end

	local hurdleCount = 0
	for _ in pairs(session.hurdles) do
		hurdleCount += 1
	end
	local targetCount = 0
	for _ in pairs(session.targets) do
		targetCount += 1
	end
	if hurdleCount < TRAINING_HURDLE_COUNT or targetCount < TRAINING_TARGET_COUNT then
		self:_notify(player, "Training drill incomplete. Clear all hurdles and targets.")
		return
	end

	local elapsedMs = math.max(0, math.floor((os.clock() - session.startedAt) * 1000))
	if elapsedMs < 2500 then
		self:_notify(player, "Training drill invalidated. Run the full drill route.")
		return
	end

	local score = math.max(10, 100 - math.floor(elapsedMs / 180))
	local clears = self._persistenceService:IncrementActivityStat(player, "trainingClears", 1)
	local improved, bestScore = self._persistenceService:UpdateActivityBest(player, "trainingBestScore", score, false)
	self:_applyActivityProgression(player, "training", clears)
	self:_unlockActivityAchievement(player, "training_clear", "Cadet Operator")
	local reward = self:_awardActivityTokens(player, improved and 3 or 2, improved and "training_personal_best" or "training_complete")
	local xpAward = self:_awardActivityExperience(player, improved and 16 or 10, improved and "training_personal_best" or "training_complete")
	self:_notify(
		player,
		("Training clear: %s | score %d. Best: %d. +%d tokens +%d XP%s"):format(
			self:_formatSecondsFromMs(elapsedMs),
			score,
			bestScore,
			reward,
			xpAward,
			improved and " [PB]" or ""
		)
	)
end

function ActivityService:_startRange(player)
	if not self:_canUseLobbyActivity(player) then
		return
	end

	self:_clearActivitySession(player.UserId, "range")
	local token = os.clock()
	self._rangeSessions[player.UserId] = {
		token = token,
		startedAt = token,
		endsAt = token + RANGE_DURATION,
		score = 0,
		lastTargetIndex = nil,
		lastHitAt = 0,
	}
	self:_notify(player, "Range trial started. Tag targets for 20 seconds. Mix your target order to keep the streak alive.")

	task.delay(RANGE_DURATION + 0.05, function()
		local session = self._rangeSessions[player.UserId]
		if session and session.token == token then
			self:_finishRange(player, true)
		end
	end)
end

function ActivityService:_hitRangeTarget(player, targetIndex, targetPart)
	local session = self._rangeSessions[player.UserId]
	if not session or not self:_canUseLobbyActivity(player) then
		return
	end

	local now = os.clock()
	if now > session.endsAt then
		self:_finishRange(player, true)
		return
	end
	if session.lastTargetIndex == targetIndex and (now - session.lastHitAt) < RANGE_REPEAT_GRACE then
		return
	end

	session.score += 1
	session.lastTargetIndex = targetIndex
	session.lastHitAt = now
	self:_flashRangeTarget(targetPart)
	if session.score % 5 == 0 then
		self:_notify(player, ("Range streak: %d tags."):format(session.score))
	end
end

function ActivityService:_finishRange(player, timedOut)
	local session = self._rangeSessions[player.UserId]
	self._rangeSessions[player.UserId] = nil
	if not session then
		return
	end
	if not self:_canUseLobbyActivity(player) then
		return
	end

	local score = math.max(0, math.floor(session.score or 0))
	self._persistenceService:IncrementActivityStat(player, "rangeRuns", 1)
	local improved, bestScore = self._persistenceService:UpdateActivityBest(player, "rangeBestScore", score, false)
	self:_applyActivityProgression(player, "range", math.max(bestScore, score))
	self:_unlockActivityAchievement(player, "range_clear", "Range Cadet")
	if score >= 12 then
		self:_unlockActivityAchievement(player, "range_deadeye", "Deadeye")
	end
	local reward = self:_awardActivityTokens(player, math.min(6, math.floor(score / 3) + (improved and 1 or 0)), improved and "range_personal_best" or "range_complete")
	local xpAward = self:_awardActivityExperience(player, math.max(6, score + (improved and 4 or 0)), improved and "range_personal_best" or "range_complete")
	local suffix = timedOut and " Trial over." or ""
	self:_notify(
		player,
		("Range score: %d. Best: %d. +%d tokens +%d XP%s%s"):format(
			score,
			bestScore,
			reward,
			xpAward,
			improved and " [PB]" or "",
			suffix
		)
	)
end

function ActivityService:_startSalvage(player)
	if not self:_canUseLobbyActivity(player) then
		return
	end

	self:_clearActivitySession(player.UserId, "salvage")
	self:_resetTouchDebounces(player, { "salvage_cache_", "salvage_finish" })
	self._salvageSessions[player.UserId] = {
		startedAt = os.clock(),
		nextCache = 1,
	}
	self:_notify(player, "Salvage sweep started. Recover every cache, then extract.")
end

function ActivityService:_collectSalvageCache(player, cacheIndex)
	local session = self._salvageSessions[player.UserId]
	if not session or not self:_canUseLobbyActivity(player) then
		return
	end
	if cacheIndex ~= session.nextCache then
		return
	end

	session.nextCache += 1
	self:_notify(player, ("Salvage cache secured: %d/%d."):format(cacheIndex, SALVAGE_CACHE_COUNT))
end

function ActivityService:_finishSalvage(player)
	local session = self._salvageSessions[player.UserId]
	self._salvageSessions[player.UserId] = nil
	if not session or not self:_canUseLobbyActivity(player) then
		return
	end
	if session.nextCache <= SALVAGE_CACHE_COUNT then
		self:_notify(player, "Salvage run incomplete. Recover every cache before extract.")
		return
	end

	local elapsedMs = math.max(0, math.floor((os.clock() - session.startedAt) * 1000))
	if elapsedMs < 3000 then
		self:_notify(player, "Salvage run invalidated. Stay on the full route.")
		return
	end

	local clears = self._persistenceService:IncrementActivityStat(player, "salvageClears", 1)
	local improved, bestMs = self._persistenceService:UpdateActivityBest(player, "salvageBestMs", elapsedMs, true)
	self:_applyActivityProgression(player, "salvage", clears)
	self:_unlockActivityAchievement(player, "salvage_clear", "Cache Runner")
	local reward = self:_awardActivityTokens(player, improved and 4 or 3, improved and "salvage_personal_best" or "salvage_complete")
	local xpAward = self:_awardActivityExperience(player, improved and 20 or 14, improved and "salvage_personal_best" or "salvage_complete")
	self:_notify(
		player,
		("Salvage clear: %s. Best: %s. +%d tokens +%d XP%s"):format(
			self:_formatSecondsFromMs(elapsedMs),
			self:_formatSecondsFromMs(bestMs),
			reward,
			xpAward,
			improved and " [PB]" or ""
		)
	)
end

function ActivityService:_bindTouched(part, key, handler)
	if not part then
		return
	end
	part.Touched:Connect(function(hit)
		local player = self:_resolvePlayerFromHit(hit)
		if not player or not self:_isTouchReady(player, key) then
			return
		end
		handler(player)
	end)
end

function ActivityService:_bindPrompt(prompt, handler)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Triggered:Connect(function(player)
		if not player or not self:_isTouchReady(player, "prompt_" .. prompt.Name, 0.35) then
			return
		end
		handler(player)
	end)
end

function ActivityService:_bindParkour(plaza)
	local course = plaza and plaza:FindFirstChild("ParkourCourse")
	if not course then
		return
	end

	self:_bindTouched(course:FindFirstChild("StartPad"), "parkour_start", function(player)
		self:_startParkour(player)
	end)
	self:_bindPrompt(course:FindFirstChild("ParkourStartPrompt"), function(player)
		self:_startParkour(player)
	end)
	for checkpointIndex = 1, PARKOUR_CHECKPOINT_COUNT do
		self:_bindTouched(course:FindFirstChild("Platform" .. tostring(checkpointIndex)), "parkour_checkpoint_" .. tostring(checkpointIndex), function(player)
			self:_hitParkourCheckpoint(player, checkpointIndex)
		end)
	end
	self:_bindTouched(course:FindFirstChild("FinishPad"), "parkour_finish", function(player)
		self:_finishParkour(player)
	end)
end

function ActivityService:_bindTraining(plaza)
	local yard = plaza and plaza:FindFirstChild("TrainingYard")
	if not yard then
		return
	end

	self:_bindTouched(yard:FindFirstChild("EntryPad"), "training_start", function(player)
		self:_startTraining(player)
	end)
	self:_bindPrompt(yard:FindFirstChild("TrainingEnterPrompt"), function(player)
		self:_startTraining(player)
	end)
	for hurdleIndex = 1, TRAINING_HURDLE_COUNT do
		self:_bindTouched(yard:FindFirstChild("Hurdle" .. tostring(hurdleIndex)), "training_hurdle_" .. tostring(hurdleIndex), function(player)
			self:_recordTrainingHurdle(player, hurdleIndex)
		end)
		self:_bindTouched(yard:FindFirstChild("HurdleTrigger" .. tostring(hurdleIndex)), "training_hurdle_trigger_" .. tostring(hurdleIndex), function(player)
			self:_recordTrainingHurdle(player, hurdleIndex)
		end)
	end
	for targetIndex = 1, TRAINING_TARGET_COUNT do
		local targetFace = yard:FindFirstChild("TargetFace" .. tostring(targetIndex))
		if targetFace and targetFace:IsA("BasePart") then
			local detector = targetFace:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
			detector.MaxActivationDistance = 48
			detector.Parent = targetFace
			detector.MouseClick:Connect(function(player)
				self:_recordTrainingTarget(player, targetIndex, targetFace)
			end)
		end
	end
end

function ActivityService:_bindRange(plaza)
	local range = plaza and plaza:FindFirstChild("TargetRange")
	if not range then
		return
	end

	self:_bindTouched(range:FindFirstChild("FiringLine"), "range_start", function(player)
		self:_startRange(player)
	end)
	self:_bindPrompt(range:FindFirstChild("TargetRangePrompt"), function(player)
		self:_startRange(player)
	end)

	for targetIndex = 1, 3 do
		local targetFace = range:FindFirstChild("TargetFace" .. tostring(targetIndex))
		if targetFace and targetFace:IsA("BasePart") then
			local detector = targetFace:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
			detector.MaxActivationDistance = 48
			detector.Parent = targetFace
			detector.MouseClick:Connect(function(player)
				self:_hitRangeTarget(player, targetIndex, targetFace)
			end)
		end
	end
end

function ActivityService:_bindSalvage(plaza)
	local run = plaza and plaza:FindFirstChild("SalvageRun")
	if not run then
		return
	end

	self:_bindTouched(run:FindFirstChild("StartPad"), "salvage_start", function(player)
		self:_startSalvage(player)
	end)
	self:_bindPrompt(run:FindFirstChild("SalvageStartPrompt"), function(player)
		self:_startSalvage(player)
	end)
	for cacheIndex = 1, SALVAGE_CACHE_COUNT do
		self:_bindTouched(run:FindFirstChild("Cache" .. tostring(cacheIndex)), "salvage_cache_" .. tostring(cacheIndex), function(player)
			self:_collectSalvageCache(player, cacheIndex)
		end)
	end
	self:_bindTouched(run:FindFirstChild("FinishPad"), "salvage_finish", function(player)
		self:_finishSalvage(player)
	end)
	self:_bindPrompt(run:FindFirstChild("SalvageExtractPrompt"), function(player)
		self:_finishSalvage(player)
	end)
end

function ActivityService:_bindSecrets(plaza)
	for secretName in pairs(SECRET_REWARDS) do
		local secretPart = plaza and plaza:FindFirstChild(secretName, true)
		if secretPart and secretPart:IsA("BasePart") then
			self:_bindTouched(secretPart, "secret_" .. secretName, function(player)
				self:_claimSecret(player, secretName)
			end)
		end
	end
end

function ActivityService:_bindLobbyActivities()
	local plaza = self:_getPlaza()
	if not plaza then
		return
	end

	self:_bindTraining(plaza)
	self:_bindParkour(plaza)
	self:_bindRange(plaza)
	self:_bindSalvage(plaza)
	self:_bindSecrets(plaza)
end

return ActivityService
