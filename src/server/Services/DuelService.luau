local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DuelService = {}
DuelService.__index = DuelService

local ROUND_COUNTDOWN = 3
local ROUND_DURATION = 45
local RING_RADIUS = 15
local RING_OUT_GRACE = 2.5
local DUEL_COOLDOWN = 8

function DuelService.new(context)
	local self = setmetatable({}, DuelService)
	self._gameFlowConfig = context.GameFlowConfig
	self._remoteNames = context.RemoteNames
	self._remotes = context.Remotes
	self._flowService = context.FlowService
	self._queuedCorners = {
		red = nil,
		blue = nil,
	}
	self._activeMatch = nil
	self._heartbeatConnection = nil
	self._cooldowns = {}
	return self
end

function DuelService:Start()
	Players.PlayerRemoving:Connect(function(player)
		self:_removePlayer(player, true)
	end)

	self._heartbeatConnection = RunService.Heartbeat:Connect(function()
		self:_updateActiveMatch()
	end)
end

function DuelService:_notify(target, message)
	if not self._remotes or not message then
		return
	end

	if typeof(target) == "Instance" then
		self._remotes:FireEventFor(target, self._remoteNames.Events.Notification, tostring(message))
	elseif type(target) == "table" then
		self._remotes:FireEventForMany(target, self._remoteNames.Events.Notification, tostring(message))
	end
end

function DuelService:_getLobbyRoot()
	return Workspace:FindFirstChild(self._gameFlowConfig.LobbyName)
end

function DuelService:_getDuelRing()
	local lobby = self:_getLobbyRoot()
	local plaza = lobby and lobby:FindFirstChild("OpenSkyLobby")
	local ring = plaza and plaza:FindFirstChild("DuelRing")
	if ring and ring:IsA("Model") then
		return ring
	end
	return nil
end

function DuelService:_getDuelPart(name)
	local ring = self:_getDuelRing()
	local part = ring and ring:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

function DuelService:_getLobbyReturnAnchor()
	local lobby = self:_getLobbyRoot()
	local plaza = lobby and lobby:FindFirstChild("OpenSkyLobby")
	local part = plaza and plaza:FindFirstChild("LobbyReturnAnchor")
	if part and part:IsA("BasePart") then
		return part
	end
	local fallback = lobby and lobby:FindFirstChild("LobbySpawn")
	if fallback and fallback:IsA("BasePart") then
		return fallback
	end
	return nil
end

function DuelService:_teleportPlayer(player, targetPart, offset)
	if not player or not targetPart then
		return
	end

	local character = player.Character
	if not character or not character.Parent then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 2)
	if not rootPart then
		return
	end

	character:PivotTo(targetPart.CFrame + (offset or Vector3.new(0, 4, 0)))
end

function DuelService:_restorePlayer(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end
end

function DuelService:_getCooldownRemaining(player)
	local readyAt = self._cooldowns[player.UserId] or 0
	return math.max(0, math.ceil(readyAt - os.clock()))
end

function DuelService:_setCooldown(player, seconds)
	if not player then
		return
	end
	local duration = math.max(0, seconds or DUEL_COOLDOWN)
	local readyAt = os.clock() + duration
	self._cooldowns[player.UserId] = readyAt
	player:SetAttribute("DuelCooldownUntil", readyAt)
end

function DuelService:_clearQueuePlayer(player)
	if self._queuedCorners.red == player then
		self._queuedCorners.red = nil
	end
	if self._queuedCorners.blue == player then
		self._queuedCorners.blue = nil
	end
	if player then
		player:SetAttribute("DuelCorner", nil)
		player:SetAttribute("InDuelQueue", false)
	end
end

function DuelService:_disconnectMatch()
	local match = self._activeMatch
	if not match then
		return
	end

	for _, connection in ipairs(match.connections) do
		connection:Disconnect()
	end
	self._activeMatch = nil
end

function DuelService:_sendBackToLobby(player)
	local destination = self:_getLobbyReturnAnchor()
	if destination and destination:IsA("BasePart") then
		self:_teleportPlayer(player, destination, Vector3.new(0, 4, 0))
	end
	if player then
		player:SetAttribute("InDuel", false)
		player:SetAttribute("DuelCorner", nil)
		player:SetAttribute("InDuelQueue", false)
	end
end

function DuelService:_finishMatch(winner, loser, reason)
	local match = self._activeMatch
	if not match then
		return
	end

	local players = match.players
	self:_disconnectMatch()

	for _, player in ipairs(players) do
		if player and player.Parent then
			player:SetAttribute("InDuel", false)
			player:SetAttribute("InDuelQueue", false)
			player:SetAttribute("DuelCorner", nil)
			self:_setCooldown(player, DUEL_COOLDOWN)
		end
	end

	if winner and loser then
		self:_notify(players, ("Duel complete. %s defeats %s. %s Cooldown %ds."):format(winner.DisplayName, loser.DisplayName, reason or "Round complete.", DUEL_COOLDOWN))
	elseif reason then
		self:_notify(players, ("%s Cooldown %ds."):format(reason, DUEL_COOLDOWN))
	end

	task.delay(2, function()
		for _, player in ipairs(players) do
			if player and player.Parent then
				self:_sendBackToLobby(player)
			end
		end
	end)
end

function DuelService:_resolveTimer()
	local match = self._activeMatch
	if not match then
		return
	end

	local redPlayer = match.red
	local bluePlayer = match.blue
	local redHumanoid = redPlayer and redPlayer.Character and redPlayer.Character:FindFirstChildOfClass("Humanoid")
	local blueHumanoid = bluePlayer and bluePlayer.Character and bluePlayer.Character:FindFirstChildOfClass("Humanoid")
	local redHealth = redHumanoid and redHumanoid.Health or 0
	local blueHealth = blueHumanoid and blueHumanoid.Health or 0

	if redHealth > blueHealth then
		self:_finishMatch(redPlayer, bluePlayer, "Time expired. Higher health takes the round.")
	elseif blueHealth > redHealth then
		self:_finishMatch(bluePlayer, redPlayer, "Time expired. Higher health takes the round.")
	else
		self:_finishMatch(nil, nil, "Duel ended in a draw.")
	end
end

function DuelService:_startMatch()
	if self._activeMatch then
		return
	end

	local redPlayer = self._queuedCorners.red
	local bluePlayer = self._queuedCorners.blue
	if not redPlayer or not bluePlayer or redPlayer == bluePlayer then
		return
	end

	self._queuedCorners.red = nil
	self._queuedCorners.blue = nil

	local redCorner = self:_getDuelPart("RedCornerPad")
	local blueCorner = self:_getDuelPart("BlueCornerPad")
	local platform = self:_getDuelPart("RingPlatform")
	if not redCorner or not blueCorner or not platform then
		self:_notify({ redPlayer, bluePlayer }, "Duel ring is offline.")
		return
	end

	self:_teleportPlayer(redPlayer, redCorner, Vector3.new(0, 4, 0))
	self:_teleportPlayer(bluePlayer, blueCorner, Vector3.new(0, 4, 0))
	self:_restorePlayer(redPlayer)
	self:_restorePlayer(bluePlayer)

	redPlayer:SetAttribute("InDuel", true)
	bluePlayer:SetAttribute("InDuel", true)
	redPlayer:SetAttribute("InDuelQueue", false)
	bluePlayer:SetAttribute("InDuelQueue", false)

	local match = {
		red = redPlayer,
		blue = bluePlayer,
		players = { redPlayer, bluePlayer },
		center = platform.Position,
		startedAt = nil,
		preparing = true,
		connections = {},
		outSince = {},
	}

	for _, player in ipairs(match.players) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			table.insert(match.connections, humanoid.Died:Connect(function()
				if not self._activeMatch then
					return
				end
				local winner = player == redPlayer and bluePlayer or redPlayer
				self:_finishMatch(winner, player, "Knockout.")
			end))
		end
	end

	self._activeMatch = match
	for countdown = ROUND_COUNTDOWN, 1, -1 do
		task.delay(ROUND_COUNTDOWN - countdown, function()
			if self._activeMatch == match then
				self:_notify(match.players, ("Duel starts in %d..."):format(countdown))
			end
		end)
	end
	task.delay(ROUND_COUNTDOWN, function()
		if self._activeMatch ~= match then
			return
		end
		match.preparing = false
		match.startedAt = os.clock()
		self:_notify(match.players, "Fight. Last fighter standing or highest health at timeout wins.")
		task.delay(ROUND_DURATION, function()
			if self._activeMatch == match then
				self:_resolveTimer()
			end
		end)
	end)
end

function DuelService:_updateActiveMatch()
	local match = self._activeMatch
	if not match or match.preparing then
		return
	end

	for _, player in ipairs(match.players) do
		if player and player.Parent then
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				local distance = (Vector3.new(rootPart.Position.X, match.center.Y, rootPart.Position.Z) - match.center).Magnitude
				if distance > RING_RADIUS then
					local started = match.outSince[player]
					if not started then
						match.outSince[player] = os.clock()
						self:_notify(player, "Return to the duel ring or forfeit.")
					elseif os.clock() - started >= RING_OUT_GRACE then
						local winner = player == match.red and match.blue or match.red
						self:_finishMatch(winner, player, "Ring out.")
						return
					end
				else
					match.outSince[player] = nil
				end
			end
		end
	end
end

function DuelService:_removePlayer(player, silent)
	if self._activeMatch and (self._activeMatch.red == player or self._activeMatch.blue == player) then
		local winner = player == self._activeMatch.red and self._activeMatch.blue or self._activeMatch.red
		if silent then
			self:_finishMatch(winner, player, "Opponent left the duel.")
		else
			self:_finishMatch(winner, player, "Opponent forfeited the duel.")
		end
		return
	end

	local wasQueued = self._queuedCorners.red == player or self._queuedCorners.blue == player
	self:_clearQueuePlayer(player)
	if wasQueued and not silent then
		self:_notify(player, "You left the duel queue.")
	end
end

function DuelService:RequestDuel(player, action)
	if not player or player.Parent ~= Players then
		return false, "invalid_player"
	end
	if self._flowService and self._flowService:GetPhase() ~= "Lobby" then
		return false, "not_in_lobby"
	end
	if player:GetAttribute("InMission") == true then
		return false, "not_in_lobby"
	end

	local normalizedAction = string.lower(tostring(action or ""))
	if normalizedAction == "leave" then
		self:_removePlayer(player, false)
		self:_sendBackToLobby(player)
		return true, "left"
	end

	if normalizedAction ~= "red" and normalizedAction ~= "blue" then
		return false, "invalid_corner"
	end

	local cooldownRemaining = self:_getCooldownRemaining(player)
	if cooldownRemaining > 0 then
		return false, "cooldown", cooldownRemaining
	end

	if self._activeMatch and (self._activeMatch.red == player or self._activeMatch.blue == player) then
		return false, "already_in_match"
	end

	local occupant = self._queuedCorners[normalizedAction]
	if occupant and occupant ~= player then
		return false, "corner_taken"
	end

	self:_clearQueuePlayer(player)
	self._queuedCorners[normalizedAction] = player
	player:SetAttribute("DuelCorner", normalizedAction)
	player:SetAttribute("InDuelQueue", true)

	local targetPart = self:_getDuelPart(normalizedAction == "red" and "RedCornerPad" or "BlueCornerPad")
	if targetPart then
		self:_teleportPlayer(player, targetPart, Vector3.new(0, 4, 0))
	end

	self:_notify(player, ("Locked into the %s corner. Waiting for another fighter."):format(string.upper(normalizedAction)))

	local otherPlayer = self._queuedCorners[normalizedAction == "red" and "blue" or "red"]
	if otherPlayer and otherPlayer ~= player then
		self:_startMatch()
		return true, "started"
	end

	return true, "queued"
end

return DuelService
