local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ActivityService = {}
ActivityService.__index = ActivityService

local PARKOUR_CHECKPOINT_COUNT = 5
local RANGE_DURATION = 20
local RANGE_REPEAT_GRACE = 0.45
local SALVAGE_CACHE_COUNT = 3
local TOUCH_COOLDOWN = 0.75

function ActivityService.new(context)
	local self = setmetatable({}, ActivityService)
	self._gameFlowConfig = context.GameFlowConfig
	self._flowService = context.FlowService
	self._persistenceService = context.PersistenceService
	self._tokenService = context.TokenService
	self._remoteNames = context.RemoteNames
	self._remotes = context.Remotes
	self._parkourSessions = {}
	self._rangeSessions = {}
	self._salvageSessions = {}
	self._touchDebounces = {}
	return self
end

function ActivityService:Start()
	Players.PlayerRemoving:Connect(function(player)
		self._parkourSessions[player.UserId] = nil
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

function ActivityService:_awardActivityTokens(player, baseAmount, reason)
	local amount = math.max(0, math.floor(baseAmount or 0))
	if amount <= 0 then
		return 0
	end
	self._tokenService:AddTokens(player, amount, "ActivityReward", reason or "activity_reward")
	return amount
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

	local improved, bestMs = self._persistenceService:UpdateActivityBest(player, "parkourBestMs", elapsedMs, true)
	local reward = self:_awardActivityTokens(player, improved and 3 or 2, improved and "parkour_personal_best" or "parkour_complete")
	self:_notify(
		player,
		("Parkour clear: %s. Best: %s. +%d tokens%s"):format(
			self:_formatSecondsFromMs(elapsedMs),
			self:_formatSecondsFromMs(bestMs),
			reward,
			improved and " [PB]" or ""
		)
	)
end

function ActivityService:_startRange(player)
	if not self:_canUseLobbyActivity(player) then
		return
	end

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
	local improved, bestScore = self._persistenceService:UpdateActivityBest(player, "rangeBestScore", score, false)
	local reward = self:_awardActivityTokens(player, math.min(6, math.floor(score / 3) + (improved and 1 or 0)), improved and "range_personal_best" or "range_complete")
	local suffix = timedOut and " Trial over." or ""
	self:_notify(
		player,
		("Range score: %d. Best: %d. +%d tokens%s%s"):format(
			score,
			bestScore,
			reward,
			improved and " [PB]" or "",
			suffix
		)
	)
end

function ActivityService:_startSalvage(player)
	if not self:_canUseLobbyActivity(player) then
		return
	end

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

	local improved, bestMs = self._persistenceService:UpdateActivityBest(player, "salvageBestMs", elapsedMs, true)
	local reward = self:_awardActivityTokens(player, improved and 4 or 3, improved and "salvage_personal_best" or "salvage_complete")
	self:_notify(
		player,
		("Salvage clear: %s. Best: %s. +%d tokens%s"):format(
			self:_formatSecondsFromMs(elapsedMs),
			self:_formatSecondsFromMs(bestMs),
			reward,
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

function ActivityService:_bindParkour(plaza)
	local course = plaza and plaza:FindFirstChild("ParkourCourse")
	if not course then
		return
	end

	self:_bindTouched(course:FindFirstChild("StartPad"), "parkour_start", function(player)
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

function ActivityService:_bindRange(plaza)
	local range = plaza and plaza:FindFirstChild("TargetRange")
	if not range then
		return
	end

	self:_bindTouched(range:FindFirstChild("FiringLine"), "range_start", function(player)
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
	for cacheIndex = 1, SALVAGE_CACHE_COUNT do
		self:_bindTouched(run:FindFirstChild("Cache" .. tostring(cacheIndex)), "salvage_cache_" .. tostring(cacheIndex), function(player)
			self:_collectSalvageCache(player, cacheIndex)
		end)
	end
	self:_bindTouched(run:FindFirstChild("FinishPad"), "salvage_finish", function(player)
		self:_finishSalvage(player)
	end)
end

function ActivityService:_bindLobbyActivities()
	local plaza = self:_getPlaza()
	if not plaza then
		return
	end

	self:_bindParkour(plaza)
	self:_bindRange(plaza)
	self:_bindSalvage(plaza)
end

return ActivityService
