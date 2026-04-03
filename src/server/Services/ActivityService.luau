local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LobbyWorld = require(script.Parent.Parent:WaitForChild("LobbyWorld"))

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
local ACTIVITY_COLORS = {
	parkour = Color3.fromRGB(178, 202, 255),
	training = Color3.fromRGB(242, 210, 156),
	range = Color3.fromRGB(182, 236, 206),
	salvage = Color3.fromRGB(244, 212, 154),
	reward = Color3.fromRGB(214, 168, 255),
}

local ACTIVITY_PART_ALIASES = {
	ParkourCourse = { "ParkourCourse", "Parkour", "ParkourLane", "Course" },
	TrainingYard = { "TrainingYard", "Training", "TrainingLane", "Yard" },
	TargetRange = { "TargetRange", "Range", "ShootingRange" },
	SalvageRun = { "SalvageRun", "Salvage", "SalvageLane" },
	StartPad = { "StartPad", "Start", "StartLine", "EntryPad", "LaunchPad" },
	FinishPad = { "FinishPad", "Finish", "EndPad", "ExitPad", "ExtractPad" },
	EntryPad = { "EntryPad", "StartPad", "Entry", "Start", "TrainingPad" },
	FiringLine = { "FiringLine", "StartPad", "Line", "RangeLine" },
}
local ACTIVITY_TRANSIT_TARGETS = {
	Training = { area = "TrainingYard", entry = "EntryPad" },
	Parkour = { area = "ParkourCourse", entry = "StartPad" },
	Range = { area = "TargetRange", entry = "FiringLine" },
	Salvage = { area = "SalvageRun", entry = "StartPad" },
}
local ACTIVITY_START_HANDLERS = {
	Training = "_startTraining",
	Parkour = "_startParkour",
	Range = "_startRange",
	Salvage = "_startSalvage",
}
local ACTIVITY_TRANSIT_PROMPTS = {
	Training = { model = "TrainingTransit", prompt = "TrainingTransitPrompt" },
	Parkour = { model = "ParkourTransit", prompt = "ParkourTransitPrompt" },
	Range = { model = "RangeTransit", prompt = "RangeTransitPrompt" },
	Salvage = { model = "SalvageTransit", prompt = "SalvageTransitPrompt" },
}

local function normalizeName(value)
	return string.lower((tostring(value or ""):gsub("[%s%p_]+", "")))
end

local function warnMissingActivityContent(areaName, entryName)
	warn(("[ActivityService] %s is missing %s. That activity will be partially or fully inactive until the content is added."):format(areaName, entryName))
end

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
	self._activitiesBound = false
	self._boundActivityKeys = {}
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
		for attempt = 1, 8 do
			LobbyWorld.ensureActivityContent()
			if self:_bindLobbyActivities() then
				return
			end
			task.wait(1)
		end
		warn("[ActivityService] Lobby activities never fully bound after startup retries.")
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

function ActivityService:_notifyActivity(player, title, body, accent, complete, rewardText)
	if not self._remotes or not player then
		return
	end
	self._remotes:FireEventFor(player, self._remoteNames.Events.Notification, {
		userId = player.UserId,
		kind = "Activity",
		title = tostring(title or "Activity"),
		body = tostring(body or ""),
		message = tostring(body or title or "Activity"),
		accent = accent,
		complete = complete == true,
		rewardText = rewardText ~= nil and tostring(rewardText) or nil,
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
	local lobby = Workspace:FindFirstChild(self._gameFlowConfig.LobbyName)
	if lobby then
		return lobby
	end

	for _, child in ipairs(Workspace:GetChildren()) do
		if child:GetAttribute("WorldType") == "LobbyHub" then
			return child
		end
	end

	return Workspace:FindFirstChild("OpenSkyLobby")
end

function ActivityService:_getPlaza()
	local lobby = self:_getLobbyRoot()
	if not lobby then
		return nil
	end
	if lobby:IsA("Model") then
		return lobby
	end
	return lobby:FindFirstChild("OpenSkyLobby") or lobby:FindFirstChildWhichIsA("Model")
end

function ActivityService:_resolveNamedDescendant(root, childName)
	if not root or not childName or childName == "" then
		return nil
	end

	local exact = root:FindFirstChild(childName, true)
	if exact then
		return exact
	end

	local aliases = ACTIVITY_PART_ALIASES[childName] or { childName }
	for _, alias in ipairs(aliases) do
		local aliasExact = root:FindFirstChild(alias, true)
		if aliasExact then
			return aliasExact
		end
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		local descendantName = normalizeName(descendant.Name)
		for _, alias in ipairs(aliases) do
			local aliasName = normalizeName(alias)
			if descendantName == aliasName or string.find(descendantName, aliasName, 1, true) then
				return descendant
			end
		end
	end

	return nil
end

function ActivityService:_resolvePlayerFromHit(hit)
	local character = hit and hit.Parent
	if not character then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

function ActivityService:_teleportPlayerToPart(player, targetPart, offset)
	local character = player and player.Character
	if not (character and character.Parent and targetPart and targetPart:IsA("BasePart")) then
		return false
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 2)
	if not rootPart then
		return false
	end
	character:PivotTo(targetPart.CFrame + (offset or Vector3.new(0, 4, 0)))
	return true
end

function ActivityService:_beginActivityFromKey(player, activityKey)
	local handlerName = ACTIVITY_START_HANDLERS[tostring(activityKey or "")]
	local handler = handlerName and self[handlerName]
	if type(handler) == "function" then
		handler(self, player)
		return true
	end
	return false
end

function ActivityService:_bindTransitPrompt(plaza, activityKey, transitInfo)
	local boundKey = "transit_" .. string.lower(tostring(activityKey or ""))
	if self._boundActivityKeys[boundKey] then
		return true
	end

	local transitModel = plaza and self:_resolveNamedDescendant(plaza, transitInfo.model)
	if not transitModel then
		return false
	end

	local prompt = self:_resolveNamedDescendant(transitModel, transitInfo.prompt)
	if not (prompt and prompt:IsA("ProximityPrompt")) then
		return false
	end

	prompt.Triggered:Connect(function(player)
		if not player or not self:_canUseLobbyActivity(player) then
			return
		end
		task.defer(function()
			if player and player.Parent == Players then
				task.wait(0.15)
				self:_beginActivityFromKey(player, activityKey)
			end
		end)
	end)

	self._boundActivityKeys[boundKey] = true
	return true
end

function ActivityService:_bindTransitPrompts(plaza)
	local allBound = true
	for activityKey, transitInfo in pairs(ACTIVITY_TRANSIT_PROMPTS) do
		if not self:_bindTransitPrompt(plaza, activityKey, transitInfo) then
			allBound = false
		end
	end
	return allBound
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
	self:_notifyActivity(player, "BADGE UNLOCKED", tostring(label), ACTIVITY_COLORS.reward, true, nil)
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
					self:_notifyActivity(player, "ACTIVITY REWARD", tostring(reward.message or "Milestone reward"), ACTIVITY_COLORS.reward, true, ("+%dT"):format(tokens))
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
	self:_notifyActivity(player, "SECRET FOUND", tostring(secretInfo.label), ACTIVITY_COLORS.reward, true, ("+%dT"):format(tokens))
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
	self:_notifyActivity(player, "PARKOUR LIVE", "Hit every platform in order, then reach the roof.", ACTIVITY_COLORS.parkour, false, nil)
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
		self:_notifyActivity(player, "PARKOUR CHECKPOINT", ("%d/%d platforms linked"):format(checkpointIndex, PARKOUR_CHECKPOINT_COUNT), ACTIVITY_COLORS.parkour, false, nil)
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
	self:_notifyActivity(player, "PARKOUR CLEAR", ("Route %s | Best %s"):format(self:_formatSecondsFromMs(elapsedMs), self:_formatSecondsFromMs(bestMs)), ACTIVITY_COLORS.parkour, true, ("+%dT +%dXP%s"):format(reward, xpAward, improved and " PB" or ""))
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
	self:_notifyActivity(player, "TRAINING LIVE", "Clear all hurdles and tag every target.", ACTIVITY_COLORS.training, false, nil)
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
	self:_notifyActivity(player, "TRAINING LIVE", "Clear all hurdles and tag every target.", ACTIVITY_COLORS.training, false, nil)
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
	self:_notifyActivity(player, "TRAINING HURDLE", ("%d/%d hurdles cleared"):format(total, TRAINING_HURDLE_COUNT), ACTIVITY_COLORS.training, false, nil)
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
		self:_notifyActivity(player, "TRAINING TARGET", ("%d/%d targets tagged"):format(targetCount, TRAINING_TARGET_COUNT), ACTIVITY_COLORS.training, false, nil)
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
	self:_notifyActivity(player, "TRAINING CLEAR", ("Score %d | Best %d"):format(score, bestScore), ACTIVITY_COLORS.training, true, ("+%dT +%dXP%s"):format(reward, xpAward, improved and " PB" or ""))
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
	self:_notifyActivity(player, "RANGE LIVE", "Tag targets for 20 seconds. Mix the order to keep the streak alive.", ACTIVITY_COLORS.range, false, nil)

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
		self:_notifyActivity(player, "RANGE STREAK", ("%d tags landed"):format(session.score), ACTIVITY_COLORS.range, false, nil)
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
	self:_notifyActivity(player, "RANGE COMPLETE", ("Score %d | Best %d%s"):format(score, bestScore, timedOut and " | Timer expired" or ""), ACTIVITY_COLORS.range, true, ("+%dT +%dXP%s"):format(reward, xpAward, improved and " PB" or ""))
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
	self:_notifyActivity(player, "SALVAGE LIVE", "Recover every cache, then extract.", ACTIVITY_COLORS.salvage, false, nil)
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
	self:_notifyActivity(player, "CACHE SECURED", ("%d/%d salvage caches recovered"):format(cacheIndex, SALVAGE_CACHE_COUNT), ACTIVITY_COLORS.salvage, false, nil)
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
	self:_notifyActivity(player, "SALVAGE CLEAR", ("Extract %s | Best %s"):format(self:_formatSecondsFromMs(elapsedMs), self:_formatSecondsFromMs(bestMs)), ACTIVITY_COLORS.salvage, true, ("+%dT +%dXP%s"):format(reward, xpAward, improved and " PB" or ""))
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

function ActivityService:_ensurePrompt(part, promptName, actionText, objectText, maxDistance)
	if not part or not part:IsA("BasePart") then
		return nil
	end

	local prompt = part:FindFirstChild(promptName)
	if prompt and not prompt:IsA("ProximityPrompt") then
		prompt:Destroy()
		prompt = nil
	end

	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = promptName
		prompt.Parent = part
	end

	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = maxDistance or 10

	return prompt
end

function ActivityService:_requireChild(root, childName, areaName)
	local child = self:_resolveNamedDescendant(root, childName)
	if not child then
		warnMissingActivityContent(areaName, childName)
		return nil
	end
	return child
end

function ActivityService:_bindRequiredTouched(root, childName, key, areaName, handler)
	local part = self:_requireChild(root, childName, areaName)
	if not part then
		return
	end
	if part:IsA("BasePart") then
		self:_bindTouched(part, key, handler)
	else
		warnMissingActivityContent(areaName, childName)
	end
end

function ActivityService:_bindRequiredPrompt(root, childName, areaName, handler)
	local prompt = self:_requireChild(root, childName, areaName)
	if not prompt then
		return
	end
	if prompt:IsA("ProximityPrompt") then
		self:_bindPrompt(prompt, handler)
	else
		warnMissingActivityContent(areaName, childName)
	end
end

function ActivityService:_bindOptionalPromptOnPart(root, partName, promptName, areaName, actionText, objectText, maxDistance, handler)
	local part = self:_requireChild(root, partName, areaName)
	if not part then
		return
	end
	if not part:IsA("BasePart") then
		warnMissingActivityContent(areaName, partName)
		return
	end

	local prompt = self:_ensurePrompt(part, promptName, actionText, objectText, maxDistance)
	if prompt then
		self:_bindPrompt(prompt, handler)
	end
end

function ActivityService:_bindTargetInteraction(targetPart, key, promptName, objectText, handler)
	if not targetPart or not targetPart:IsA("BasePart") then
		return
	end

	self:_bindTouched(targetPart, key, handler)

	local prompt = self:_ensurePrompt(targetPart, promptName, "Tag", objectText, 12)
	if prompt then
		self:_bindPrompt(prompt, handler)
	end

	local detector = targetPart:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
	detector.MaxActivationDistance = 48
	detector.Parent = targetPart
	detector.MouseClick:Connect(function(player)
		if not player or not self:_isTouchReady(player, "click_" .. key, 0.2) then
			return
		end
		handler(player)
	end)
end

function ActivityService:_bindParkour(plaza)
	if self._boundActivityKeys.parkour then
		return true
	end
	local course = self:_resolveNamedDescendant(plaza, "ParkourCourse")
	if not course then
		warnMissingActivityContent("ParkourCourse", "ParkourCourse")
		return false
	end

	self:_bindRequiredTouched(course, "StartPad", "parkour_start", "ParkourCourse", function(player)
		self:_startParkour(player)
	end)
	self:_bindOptionalPromptOnPart(course, "StartPad", "ParkourStartPrompt", "ParkourCourse", "Start", "Parkour Line", 10, function(player)
		self:_startParkour(player)
	end)
	for checkpointIndex = 1, PARKOUR_CHECKPOINT_COUNT do
		self:_bindRequiredTouched(course, "Platform" .. tostring(checkpointIndex), "parkour_checkpoint_" .. tostring(checkpointIndex), "ParkourCourse", function(player)
			self:_hitParkourCheckpoint(player, checkpointIndex)
		end)
	end
	self:_bindRequiredTouched(course, "FinishPad", "parkour_finish", "ParkourCourse", function(player)
		self:_finishParkour(player)
	end)
	self:_bindOptionalPromptOnPart(course, "FinishPad", "ParkourFinishPrompt", "ParkourCourse", "Finish", "Parkour Line", 10, function(player)
		self:_finishParkour(player)
	end)
	self._boundActivityKeys.parkour = true
	return true
end

function ActivityService:_bindTraining(plaza)
	if self._boundActivityKeys.training then
		return true
	end
	local yard = self:_resolveNamedDescendant(plaza, "TrainingYard")
	if not yard then
		warnMissingActivityContent("TrainingYard", "TrainingYard")
		return false
	end

	self:_bindRequiredTouched(yard, "EntryPad", "training_start", "TrainingYard", function(player)
		self:_startTraining(player)
	end)
	self:_bindOptionalPromptOnPart(yard, "EntryPad", "TrainingEnterPrompt", "TrainingYard", "Train", "Training Yard", 10, function(player)
		self:_startTraining(player)
	end)
	for hurdleIndex = 1, TRAINING_HURDLE_COUNT do
		self:_bindRequiredTouched(yard, "Hurdle" .. tostring(hurdleIndex), "training_hurdle_" .. tostring(hurdleIndex), "TrainingYard", function(player)
			self:_recordTrainingHurdle(player, hurdleIndex)
		end)
		self:_bindRequiredTouched(yard, "HurdleTrigger" .. tostring(hurdleIndex), "training_hurdle_trigger_" .. tostring(hurdleIndex), "TrainingYard", function(player)
			self:_recordTrainingHurdle(player, hurdleIndex)
		end)
	end
	for targetIndex = 1, TRAINING_TARGET_COUNT do
		local targetFace = self:_requireChild(yard, "TargetFace" .. tostring(targetIndex), "TrainingYard")
		if targetFace and targetFace:IsA("BasePart") then
			self:_bindTargetInteraction(targetFace, "training_target_" .. tostring(targetIndex), "TrainingTargetPrompt" .. tostring(targetIndex), "Training Target", function(player)
				self:_recordTrainingTarget(player, targetIndex, targetFace)
			end)
		end
	end
	self._boundActivityKeys.training = true
	return true
end

function ActivityService:_bindRange(plaza)
	if self._boundActivityKeys.range then
		return true
	end
	local range = self:_resolveNamedDescendant(plaza, "TargetRange")
	if not range then
		warnMissingActivityContent("TargetRange", "TargetRange")
		return false
	end

	self:_bindRequiredTouched(range, "FiringLine", "range_start", "TargetRange", function(player)
		self:_startRange(player)
	end)
	self:_bindOptionalPromptOnPart(range, "FiringLine", "TargetRangePrompt", "TargetRange", "Range", "Target Range", 10, function(player)
		self:_startRange(player)
	end)

	for targetIndex = 1, 3 do
		local targetFace = self:_requireChild(range, "TargetFace" .. tostring(targetIndex), "TargetRange")
		if targetFace and targetFace:IsA("BasePart") then
			self:_bindTargetInteraction(targetFace, "range_target_" .. tostring(targetIndex), "RangeTargetPrompt" .. tostring(targetIndex), "Range Target", function(player)
				self:_hitRangeTarget(player, targetIndex, targetFace)
			end)
		end
	end
	self._boundActivityKeys.range = true
	return true
end

function ActivityService:_bindSalvage(plaza)
	if self._boundActivityKeys.salvage then
		return true
	end
	local run = self:_resolveNamedDescendant(plaza, "SalvageRun")
	if not run then
		warnMissingActivityContent("SalvageRun", "SalvageRun")
		return false
	end

	self:_bindRequiredTouched(run, "StartPad", "salvage_start", "SalvageRun", function(player)
		self:_startSalvage(player)
	end)
	self:_bindOptionalPromptOnPart(run, "StartPad", "SalvageStartPrompt", "SalvageRun", "Salvage", "Salvage Run", 10, function(player)
		self:_startSalvage(player)
	end)
	for cacheIndex = 1, SALVAGE_CACHE_COUNT do
		local cachePart = self:_requireChild(run, "Cache" .. tostring(cacheIndex), "SalvageRun")
		if cachePart and cachePart:IsA("BasePart") then
			self:_bindTargetInteraction(cachePart, "salvage_cache_" .. tostring(cacheIndex), "SalvageCachePrompt" .. tostring(cacheIndex), "Salvage Cache", function(player)
				self:_collectSalvageCache(player, cacheIndex)
			end)
		end
	end
	self:_bindRequiredTouched(run, "FinishPad", "salvage_finish", "SalvageRun", function(player)
		self:_finishSalvage(player)
	end)
	self:_bindOptionalPromptOnPart(run, "FinishPad", "SalvageExtractPrompt", "SalvageRun", "Extract", "Salvage Run", 10, function(player)
		self:_finishSalvage(player)
	end)
	self._boundActivityKeys.salvage = true
	return true
end

function ActivityService:_bindSecrets(plaza)
	if self._boundActivityKeys.secrets then
		return
	end
	for secretName in pairs(SECRET_REWARDS) do
		local secretPart = plaza and plaza:FindFirstChild(secretName, true)
		if secretPart and secretPart:IsA("BasePart") then
			self:_bindTouched(secretPart, "secret_" .. secretName, function(player)
				self:_claimSecret(player, secretName)
			end)
			local prompt = self:_ensurePrompt(secretPart, secretName .. "Prompt", "Claim", "Hidden Cache", 12)
			if prompt then
				self:_bindPrompt(prompt, function(player)
					self:_claimSecret(player, secretName)
				end)
			end
		end
	end
	self._boundActivityKeys.secrets = true
end

function ActivityService:_bindLobbyActivities()
	if self._activitiesBound then
		return true
	end

	LobbyWorld.ensureActivityContent()

	local plaza = self:_getPlaza()
	if not plaza then
		warn(("[ActivityService] %s is missing. Lobby activities will not bind."):format(self._gameFlowConfig.LobbyName))
		return false
	end

	local trainingBound = self:_bindTraining(plaza)
	local parkourBound = self:_bindParkour(plaza)
	local rangeBound = self:_bindRange(plaza)
	local salvageBound = self:_bindSalvage(plaza)
	self:_bindTransitPrompts(plaza)
	self:_bindSecrets(plaza)
	self._activitiesBound = trainingBound and parkourBound and rangeBound and salvageBound
	return self._activitiesBound
end

function ActivityService:RequestTransit(player, activityKey)
	if not self:_canUseLobbyActivity(player) then
		return false, "unavailable"
	end
	LobbyWorld.ensureActivityContent()
	local targetInfo = ACTIVITY_TRANSIT_TARGETS[tostring(activityKey or "")]
	if not targetInfo then
		return false, "invalid_activity"
	end
	local plaza = self:_getPlaza()
	if not plaza then
		return false, "lobby_unavailable"
	end
	local area = self:_resolveNamedDescendant(plaza, targetInfo.area)
	if not area then
		return false, "activity_missing"
	end
	local entryPart = self:_resolveNamedDescendant(area, targetInfo.entry)
	if not (entryPart and entryPart:IsA("BasePart")) then
		return false, "entry_missing"
	end
	if not self:_teleportPlayerToPart(player, entryPart, Vector3.new(0, 4, 0)) then
		return false, "teleport_failed"
	end
	task.defer(function()
		if player and player.Parent == Players then
			self:_beginActivityFromKey(player, activityKey)
		end
	end)
	self:_notify(player, ("Transit routed to %s. Activity live."):format(tostring(targetInfo.area)))
	return true, targetInfo.area
end

return ActivityService
