local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local InstanceDeploymentService = {}
InstanceDeploymentService.__index = InstanceDeploymentService

local INSTANCE_KIND = "mission_instance"
local INSTANCE_START_TIMEOUT = 8

function InstanceDeploymentService.new(context)
	local self = setmetatable({}, InstanceDeploymentService)
	self._gameFlowConfig = context.GameFlowConfig
	self._flowService = context.FlowService
	self._missionService = context.MissionService
	self._scalingService = context.ScalingService
	self._remoteNames = context.RemoteNames
	self._remotes = context.Remotes
	self._pendingTicket = nil
	self._ticketOpenedAt = nil
	self._instanceStarted = false
	self._ticketResolved = false
	self._outgoingMissionLaunches = {}
	self._outgoingMissionLaunchByUserId = {}
	self._outgoingLobbyReturns = {}
	self._outgoingLobbyReturnByUserId = {}
	return self
end

function InstanceDeploymentService:_notifyPlayers(players, message)
	if not self._remotes then
		return
	end
	for _, player in ipairs(players) do
		if player and player.Parent then
			self._remotes:FireEventFor(player, self._remoteNames.Events.Notification, {
				userId = player.UserId,
				message = message,
			})
		end
	end
end

function InstanceDeploymentService:_broadcastDeployState(players, payload)
	if self._flowService then
		self._flowService:BroadcastPartyDeployState(players, payload)
	end
end

function InstanceDeploymentService:_setPlayerState(players, stateName, profile)
	if self._flowService then
		self._flowService:SetPartyPlayerState(players, stateName, profile)
	end
end

function InstanceDeploymentService:_extractTeleportData(player)
	local joinData = player and player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData
	if type(teleportData) ~= "table" then
		return nil
	end
	if teleportData.kind ~= INSTANCE_KIND then
		return nil
	end
	return teleportData
end

function InstanceDeploymentService:_isExpectedPlayer(userId)
	if not self._pendingTicket then
		return false
	end

	for _, expectedUserId in ipairs(self._pendingTicket.expectedUserIds or {}) do
		if tonumber(expectedUserId) == tonumber(userId) then
			return true
		end
	end

	return false
end

function InstanceDeploymentService:_setPlayersPending(players, isPending)
	for _, player in ipairs(players) do
		if player and player.Parent then
			player:SetAttribute("MissionInstancePending", isPending == true)
		end
	end
end

function InstanceDeploymentService:_extractTeleportDataFromOptions(teleportOptions)
	if not teleportOptions or typeof(teleportOptions) ~= "Instance" then
		return nil
	end

	local ok, teleportData = pcall(function()
		return teleportOptions:GetTeleportData()
	end)
	if not ok or type(teleportData) ~= "table" then
		return nil
	end
	return teleportData
end

function InstanceDeploymentService:_registerOutgoingMissionLaunch(squadId, party, profile)
	if not squadId or squadId == "" then
		return
	end

	local launch = {
		squadId = squadId,
		profile = profile,
		userIds = {},
	}
	for _, player in ipairs(party) do
		if player and player.Parent then
			launch.userIds[player.UserId] = true
			self._outgoingMissionLaunchByUserId[player.UserId] = launch
		end
	end
	self._outgoingMissionLaunches[squadId] = launch
end

function InstanceDeploymentService:_registerOutgoingLobbyReturn(status, party)
	local returnState = {
		status = status,
		userIds = {},
		hadFailure = false,
	}
	for _, player in ipairs(party) do
		if player and player.Parent then
			returnState.userIds[player.UserId] = true
			self._outgoingLobbyReturnByUserId[player.UserId] = returnState
		end
	end
	self._outgoingLobbyReturns[status] = returnState
	return returnState
end

function InstanceDeploymentService:_clearOutgoingMissionLaunch(squadId)
	local launch = squadId and self._outgoingMissionLaunches[squadId] or nil
	if not launch then
		return nil
	end

	for userId in pairs(launch.userIds or {}) do
		self._outgoingMissionLaunchByUserId[userId] = nil
	end
	self._outgoingMissionLaunches[squadId] = nil
	return launch
end

function InstanceDeploymentService:_clearOutgoingLobbyReturn(returnState)
	if not returnState then
		return nil
	end
	for userId in pairs(returnState.userIds or {}) do
		self._outgoingLobbyReturnByUserId[userId] = nil
	end
	if returnState.status then
		self._outgoingLobbyReturns[returnState.status] = nil
	end
	return returnState
end

function InstanceDeploymentService:_handleOutgoingLaunchDeparture(player)
	local launch = player and self._outgoingMissionLaunchByUserId[player.UserId] or nil
	if not launch then
		return
	end

	launch.userIds[player.UserId] = nil
	self._outgoingMissionLaunchByUserId[player.UserId] = nil
	if next(launch.userIds) == nil then
		self._outgoingMissionLaunches[launch.squadId] = nil
		if self._flowService then
			self._flowService:UnlockSquadAfterDispatch(launch.squadId)
		end
	end
end

function InstanceDeploymentService:_handleOutgoingLobbyReturnDeparture(player)
	local returnState = player and self._outgoingLobbyReturnByUserId[player.UserId] or nil
	if not returnState then
		return
	end

	returnState.userIds[player.UserId] = nil
	self._outgoingLobbyReturnByUserId[player.UserId] = nil
	if next(returnState.userIds) == nil and not returnState.hadFailure then
		if returnState.status then
			self._outgoingLobbyReturns[returnState.status] = nil
		end
		if self._missionService and self._missionService.FinalizePendingInstanceReturn then
			self._missionService:FinalizePendingInstanceReturn()
		end
	end
end

function InstanceDeploymentService:_handleMissionLaunchInitFailed(player, teleportOptions)
	local teleportData = self:_extractTeleportDataFromOptions(teleportOptions)
	if not teleportData or teleportData.kind ~= INSTANCE_KIND then
		return
	end

	local launch = player and self._outgoingMissionLaunchByUserId[player.UserId] or nil
	if not launch then
		return
	end

	player:SetAttribute("MissionInstancePending", false)
	self:_setPlayerState({ player }, "Lobby", launch.profile)
	self:_broadcastDeployState({ player }, {
		stage = "Lobby",
		status = "Mission launch failed. Tokens refunded.",
	})
	self:_notifyPlayers({ player }, "Mission launch failed. Staying in lobby.")
	self:_clearOutgoingMissionLaunch(launch.squadId)
	if self._flowService then
		self._flowService:UnlockSquadAfterFailedDeployment(launch.squadId)
	end
end

function InstanceDeploymentService:_handleLobbyReturnInitFailed(player, teleportOptions)
	local teleportData = self:_extractTeleportDataFromOptions(teleportOptions)
	if not teleportData or teleportData.kind ~= "lobby_return" then
		return
	end

	local returnState = player and self._outgoingLobbyReturnByUserId[player.UserId] or nil
	if not returnState then
		return
	end

	player:SetAttribute("MissionInstancePending", false)
	self:_setPlayerState({ player }, "Lobby")
	self:_broadcastDeployState({ player }, {
		stage = "Mission",
		status = "Lobby return failed. Retry or rejoin.",
	})
	self:_notifyPlayers({ player }, "Lobby return failed. Rejoin the lobby.")
	returnState.userIds[player.UserId] = nil
	self._outgoingLobbyReturnByUserId[player.UserId] = nil
	self:_clearOutgoingLobbyReturn(returnState)
	if self._missionService and self._missionService.FailPendingInstanceReturn then
		self._missionService:FailPendingInstanceReturn()
	end
end

function InstanceDeploymentService:_returnPlayersToLobby(players, status, failureMessage)
	self:_setPlayersPending(players, false)
	self:_setPlayerState(players, "Lobby")
	local returned = self:ReturnPartyToLobby(players, status)
	if not returned and failureMessage then
		self:_notifyPlayers(players, failureMessage)
	end
	return returned
end

function InstanceDeploymentService:_handleLateArrival(player)
	if not player or not player.Parent then
		return
	end
	player:SetAttribute("MissionInstancePending", false)
	self:_broadcastDeployState({ player }, {
		stage = "Lobby",
		status = "Late arrival rerouted to lobby.",
	})
	self:_notifyPlayers({ player }, "Squad already deployed. Returning you to lobby.")
	self:_returnPlayersToLobby({ player }, "Late arrival rerouted to lobby.", "Late arrival return failed. Rejoin the lobby.")
end

function InstanceDeploymentService:_registerArrivingPlayer(player)
	local teleportData = self:_extractTeleportData(player)
	if not teleportData then
		return
	end

	if self._pendingTicket and (self._instanceStarted or self._ticketResolved) and self:_isExpectedPlayer(player.UserId) then
		self:_handleLateArrival(player)
		return
	end

	player:SetAttribute("MissionInstancePending", true)

	if not self._pendingTicket then
		self._pendingTicket = {
			squadId = tostring(teleportData.squadId or ""),
			preview = teleportData.preview,
			expectedCount = math.max(1, math.floor(tonumber(teleportData.expectedCount) or 1)),
			expectedUserIds = teleportData.expectedUserIds or {},
		}
		self._ticketOpenedAt = os.clock()
	end

	self:_tryStartMissionInstance()
end

function InstanceDeploymentService:_getArrivedParty()
	if not self._pendingTicket then
		return {}
	end

	local expectedLookup = {}
	for _, userId in ipairs(self._pendingTicket.expectedUserIds or {}) do
		expectedLookup[tonumber(userId)] = true
	end

	local party = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if expectedLookup[player.UserId] == true then
			table.insert(party, player)
		end
	end
	return party
end

function InstanceDeploymentService:_tryStartMissionInstance()
	if self._instanceStarted or self._ticketResolved or not self._pendingTicket or not self._missionService then
		return
	end

	local party = self:_getArrivedParty()
	local expectedCount = self._pendingTicket.expectedCount or 1
	local timedOut = self._ticketOpenedAt ~= nil and (os.clock() - self._ticketOpenedAt) >= INSTANCE_START_TIMEOUT
	if #party <= 0 or (#party < expectedCount and not timedOut) then
		if timedOut and #party <= 0 then
			self._ticketResolved = true
		end
		return
	end

	if timedOut and #party < expectedCount then
		self._ticketResolved = true
		self:_broadcastDeployState(party, {
			stage = "Lobby",
			status = "Squad deploy desynced. Back in lobby.",
		})
		self:_notifyPlayers(party, "Squad deploy desynced. Returning arrived operators to lobby.")
		self:_returnPlayersToLobby(party, "Squad deploy desynced. Back to lobby.", "Squad return failed. Rejoin the lobby.")
		return
	end

	self._instanceStarted = true
	self._ticketResolved = true
	local profile = self._scalingService:GetProfile(#party)
	self:_setPlayersPending(party, false)

	if self._flowService then
		self._flowService:StartMissionInstance({
			squadId = self._pendingTicket.squadId,
			party = party,
			profile = profile,
			preview = self._pendingTicket.preview,
		})
	end

	self._missionService:StartMission({
		squadId = self._pendingTicket.squadId,
		party = party,
		profile = profile,
		preview = self._pendingTicket.preview,
	})
end

function InstanceDeploymentService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:_registerArrivingPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_handleOutgoingLaunchDeparture(player)
		self:_handleOutgoingLobbyReturnDeparture(player)
	end)

	TeleportService.TeleportInitFailed:Connect(function(player, _teleportResult, _errorMessage, _placeId, teleportOptions)
		self:_handleMissionLaunchInitFailed(player, teleportOptions)
		self:_handleLobbyReturnInitFailed(player, teleportOptions)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_registerArrivingPlayer(player)
	end

	task.spawn(function()
		while not self._instanceStarted and not self._ticketResolved do
			task.wait(1)
			self:_tryStartMissionInstance()
		end
	end)
end

function InstanceDeploymentService:IsMissionInstanceServer()
	return self._pendingTicket ~= nil
end

function InstanceDeploymentService:DeployPartyToMissionInstance(squad, party, profile, preview)
	local squadId = squad and squad.id or ""
	local expectedUserIds = {}
	for _, player in ipairs(party) do
		table.insert(expectedUserIds, player.UserId)
	end

	self:_setPlayerState(party, "Intermission", profile)
	self:_broadcastDeployState(party, {
		stage = "Intermission",
		status = ("Intermission: %ds"):format(self._gameFlowConfig.IntermissionDurationSeconds),
		squadId = squadId,
		partySize = #party,
		difficultyMultiplier = profile.difficultyMultiplier,
		lootMultiplier = profile.lootMultiplier,
	})

	task.spawn(function()
		for remaining = self._gameFlowConfig.IntermissionDurationSeconds, 1, -1 do
			self:_broadcastDeployState(party, {
				stage = "Intermission",
				status = ("Intermission: %ds"):format(remaining),
				squadId = squadId,
				partySize = #party,
				difficultyMultiplier = profile.difficultyMultiplier,
				lootMultiplier = profile.lootMultiplier,
			})
			task.wait(1)
		end

		self:_setPlayerState(party, "Deployment", profile)
		self:_broadcastDeployState(party, {
			stage = "Deployment",
			status = "Deploying to mission instance...",
			squadId = squadId,
			playerCount = #party,
			duration = self._gameFlowConfig.DeploymentFlyInSeconds,
			difficultyMultiplier = profile.difficultyMultiplier,
			lootMultiplier = profile.lootMultiplier,
		})

		if RunService:IsStudio() then
			self:_setPlayersPending(party, false)
			if self._flowService then
				self._flowService:StartMissionInstance({
					squadId = squadId,
					party = party,
					profile = profile,
					preview = preview,
				})
				self._flowService:UnlockSquadAfterDispatch(squadId)
			end
			if self._missionService then
				self._missionService:StartMission({
					squadId = squadId,
					party = party,
					profile = profile,
					preview = preview,
				})
			end
			return
		end

		local ok, accessCodeOrError = pcall(function()
			local accessCode = TeleportService:ReserveServer(game.PlaceId)
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = accessCode
			options:SetTeleportData({
				kind = INSTANCE_KIND,
				squadId = squadId,
				expectedCount = #party,
				expectedUserIds = expectedUserIds,
				preview = preview,
			})
			self:_registerOutgoingMissionLaunch(squadId, party, profile)
			TeleportService:TeleportAsync(game.PlaceId, party, options)
			return accessCode
		end)

		if not ok then
			self:_clearOutgoingMissionLaunch(squadId)
			self:_setPlayerState(party, "Lobby", profile)
			self:_broadcastDeployState(party, {
				stage = "Lobby",
				status = "Mission instance launch failed.",
			})
			self:_notifyPlayers(party, "Mission instance launch failed. Staying in lobby.")
			if self._flowService then
				self._flowService:UnlockSquadAfterFailedDeployment(squadId)
			end
			return
		end
	end)

	return true
end

function InstanceDeploymentService:ReturnPartyToLobby(party, status)
	if RunService:IsStudio() then
		self:_setPlayersPending(party, false)
		self:_setPlayerState(party, "Lobby")
		if self._flowService then
			return self._flowService:ReturnPlayersToLobby(party, status or "Back in the bunker.")
		end
		return true
	end
	self:_setPlayersPending(party, false)
	self:_setPlayerState(party, "Returning")
	self:_broadcastDeployState(party, {
		stage = "Mission",
		status = "Returning to lobby...",
	})
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({
		kind = "lobby_return",
		status = status,
	})
	local returnState = self:_registerOutgoingLobbyReturn(status or "lobby_return", party)
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, party, options)
	end)
	if not ok then
		self:_clearOutgoingLobbyReturn(returnState)
		self:_setPlayerState(party, "Lobby")
		self:_notifyPlayers(party, "Lobby return failed. Rejoin the lobby.")
	end
	return ok, err
end

return InstanceDeploymentService
