local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local FlowService = {}
FlowService.__index = FlowService

function FlowService.new(context)
	local self = setmetatable({}, FlowService)
	self._gameFlowConfig = context.GameFlowConfig
	self._contracts = context.Contracts
	self._remoteNames = context.RemoteNames
	self._remotes = context.Remotes
	self._squadService = context.SquadService
	self._scalingService = context.ScalingService
	self._tokenService = context.TokenService
	self._tokenEconomy = context.TokenEconomy
	self._state = {
		phase = "Lobby",
		activeRequest = nil,
		activePad = nil,
		intermissionEndsAt = 0,
	}
	self._registeredPads = {}
	self._deployPadLocked = false
	self.IntermissionStarted = context.Signal.new()
	self.IntermissionTicked = context.Signal.new()
	self.DeploymentStarted = context.Signal.new()
	self.DeploymentResolved = context.Signal.new()
	self.PhaseChanged = context.Signal.new()
	return self
end

function FlowService:Start()
	self:_broadcastLobbyState()

	Players.PlayerAdded:Connect(function(player)
		self:_bindPlayerSpawn(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_bindPlayerSpawn(player)
	end

	for _, instance in ipairs(CollectionService:GetTagged("DeployPad")) do
		self:RegisterDeployPad(instance)
	end

	CollectionService:GetInstanceAddedSignal("DeployPad"):Connect(function(instance)
		self:RegisterDeployPad(instance)
	end)

	self._squadService.SquadChanged:Connect(function()
		self:_broadcastLobbyState()
	end)

	self._squadService.SquadRemoved:Connect(function()
		self:_broadcastLobbyState()
	end)
end

function FlowService:_getLobbySpawn()
	local lobby = Workspace:FindFirstChild(self._gameFlowConfig.LobbyName)
	return lobby and lobby:FindFirstChild("LobbySpawn")
end

function FlowService:_bindPlayerSpawn(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(0.1)
		if not character or not character.Parent then
			return
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			rootPart = character:WaitForChild("HumanoidRootPart", 3)
		end
		if not rootPart then
			return
		end

		if player:GetAttribute("InMission") == true or self._state.phase == "Deployment" or self._state.phase == "Intermission" then
			return
		end

		local lobbySpawn = self:_getLobbySpawn()
		if lobbySpawn then
			character:PivotTo(lobbySpawn.CFrame + Vector3.new(0, 4, 0))
			player:SetAttribute("DeploymentState", "Lobby")
			player:SetAttribute("InMission", false)
		end
	end)
end

function FlowService:_broadcastLobbyState()
	local lobbyState = self._contracts.makeLobbyState(
		self._state.phase,
		self._squadService:GetActiveSquadCount(),
		true,
		self._deployPadLocked
	)

	Workspace:SetAttribute("GamePhase", self._state.phase)
	Workspace:SetAttribute("LobbyPhase", self._state.phase)
	Workspace:SetAttribute("ActiveSquads", lobbyState.activeSquads)
	Workspace:SetAttribute("ShopOpen", lobbyState.shopOpen)
	Workspace:SetAttribute("DeployPadLocked", lobbyState.deployPadLocked)
	if self._remotes then
		self._remotes:FireEvent(self._remoteNames.Events.LobbyStateChanged, lobbyState)
	end

	return lobbyState
end

function FlowService:_setPlayerState(players, stateName, profile)
	for _, player in ipairs(players) do
		if player and player.Parent then
			player:SetAttribute("DeploymentState", stateName)
			player:SetAttribute("InMission", stateName == "Mission")
			player:SetAttribute("PartySize", #players)
			player:SetAttribute("DifficultyMultiplier", profile and profile.difficultyMultiplier or 1)
			player:SetAttribute("LootMultiplier", profile and profile.lootMultiplier or 1)
		end
	end
end

function FlowService:_broadcastDeployState(players, payload)
	if self._remotes then
		self._remotes:FireEventForMany(players, self._remoteNames.Events.DeployStateChanged, payload)
	end
end

function FlowService:_notifyPlayers(players, message)
	if self._remotes then
		for _, player in ipairs(players) do
			if player and player.Parent then
				self._remotes:FireEventFor(player, self._remoteNames.Events.Notification, {
					userId = player.UserId,
					message = message,
				})
			end
		end
	end
end

function FlowService:_buildParty(requestingPlayer)
	local squad = self._squadService:GetPlayerSquad(requestingPlayer) or self._squadService:EnsureSoloSquad(requestingPlayer)
	if not squad then
		return nil, nil
	end

	local party = self._squadService:GetMembersInSquad(squad.id)
	if #party == 0 then
		party = { requestingPlayer }
	end

	return squad, party
end

function FlowService:_canPartyDeploy(party)
	for _, player in ipairs(party) do
		if self._tokenService:GetBalance(player) < self._tokenEconomy.DeployTokenCost then
			return false, player
		end
	end

	return true
end

function FlowService:_spendPartyTokens(party)
	for _, player in ipairs(party) do
		local success = self._tokenService:SpendTokens(player, self._tokenEconomy.DeployTokenCost, "DeploySpend", "deployment_cost")
		if not success then
			return false, player
		end
	end

	return true
end

function FlowService:RegisterDeployPad(instance)
	if self._registeredPads[instance] then
		return
	end

	local pad = instance
	if not pad:IsA("BasePart") then
		pad = pad:FindFirstChildWhichIsA("BasePart", true)
	end

	if not pad or not pad:IsA("BasePart") then
		return
	end

	self._registeredPads[instance] = true

	local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DeployPrompt"
		prompt.ActionText = "Deploy"
		prompt.ObjectText = self._gameFlowConfig.LobbyName
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad
	end

	prompt.Triggered:Connect(function(player)
		self:RequestDeployment(player, pad)
	end)

	pad.Touched:Connect(function(hit)
		local character = hit and hit.Parent
		if not character then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if player then
			self:RequestDeployment(player, pad)
		end
	end)
end

function FlowService:RequestDeployment(requestingPlayer, pad)
	if self._state.phase ~= "Lobby" then
		return false, "busy", self._state
	end

	local squad, party = self:_buildParty(requestingPlayer)
	if not squad or not party then
		return false, "missing_squad", self._state
	end

	local canDeploy, blockedPlayer = self:_canPartyDeploy(party)
	if not canDeploy then
		local blockedName = blockedPlayer and blockedPlayer.DisplayName or "A squad member"
		self:_notifyPlayers(party, ("%s needs more deploy tokens."):format(blockedName))
		return false, "insufficient_tokens", blockedPlayer and blockedPlayer.UserId or nil
	end

	local spendSuccess = self:_spendPartyTokens(party)
	if not spendSuccess then
		self:_notifyPlayers(party, "Unable to spend deploy tokens for this run.")
		return false, "spend_failed", nil
	end

	local profile = self._scalingService:GetProfile(#party)
	local request = self._contracts.makeDeployRequest(squad.id, #party, os.clock() + self._gameFlowConfig.IntermissionDurationSeconds, nil)

	self._state.phase = "Intermission"
	self._state.activeRequest = {
		squadId = squad.id,
		pad = pad,
		party = party,
		profile = profile,
		requestedBy = requestingPlayer.UserId,
		intermissionEndsAt = request.intermissionEndsAt,
	}
	self._state.activePad = pad
	self._state.intermissionEndsAt = request.intermissionEndsAt
	self._deployPadLocked = true

	self._squadService:SetLocked(squad.id, true)
	self:_broadcastLobbyState()
	self:_setPlayerState(party, "Intermission", profile)

	local intermissionPayload = {
		stage = "Intermission",
		status = ("Intermission: %ds"):format(self._gameFlowConfig.IntermissionDurationSeconds),
		squadId = squad.id,
		partySize = #party,
		difficultyMultiplier = profile.difficultyMultiplier,
		lootMultiplier = profile.lootMultiplier,
		intermissionEndsAt = request.intermissionEndsAt,
	}

	self.IntermissionStarted:Fire(self._state.activeRequest)
	self:_broadcastDeployState(party, intermissionPayload)
	self:_notifyPlayers(party, ("Intermission started for %s squad."):format(profile.label))

	task.spawn(function()
		for remaining = self._gameFlowConfig.IntermissionDurationSeconds, 1, -1 do
			if self._state.phase ~= "Intermission" or self._state.activeRequest == nil then
				return
			end

			local tickPayload = {
				stage = "Intermission",
				status = ("Intermission: %ds"):format(remaining),
				squadId = squad.id,
				partySize = #party,
				difficultyMultiplier = profile.difficultyMultiplier,
				lootMultiplier = profile.lootMultiplier,
				intermissionEndsAt = request.intermissionEndsAt,
			}

			self.IntermissionTicked:Fire(remaining, self._state.activeRequest)
			self:_broadcastDeployState(party, tickPayload)
			task.wait(1)
		end

		if self._state.phase ~= "Intermission" then
			return
		end

		self:_beginDeployment()
	end)

	return true, "started", self._state.activeRequest
end

function FlowService:_beginDeployment()
	local request = self._state.activeRequest
	if not request then
		return
	end

	self._state.phase = "Deployment"
	self._state.deployStartedAt = os.clock()

	local party = request.party
	self:_broadcastLobbyState()
	self:_setPlayerState(party, "Deployment", request.profile)

	Workspace:SetAttribute("DeploymentStartedAt", self._state.deployStartedAt)
	Workspace:SetAttribute("DeploymentCinematicSeconds", self._gameFlowConfig.DeploymentFlyInSeconds)

	local payload = {
		stage = "Deployment",
		status = "Deploying to mission...",
		squadId = request.squadId,
		playerCount = #party,
		duration = self._gameFlowConfig.DeploymentFlyInSeconds,
		intermissionEndsAt = request.intermissionEndsAt,
		destination = Workspace:GetAttribute("MissionSpawnPath"),
		cameraStart = Workspace:GetAttribute("MissionCameraStartPath"),
		cameraEnd = Workspace:GetAttribute("MissionCameraEndPath"),
		difficultyMultiplier = request.profile.difficultyMultiplier,
		lootMultiplier = request.profile.lootMultiplier,
	}

	self.DeploymentStarted:Fire(payload)
	self:_broadcastDeployState(party, payload)
	self:_notifyPlayers(party, "Deployment cinematic started.")

	if self._deploymentHandler then
		self._deploymentHandler({
			squadId = request.squadId,
			pad = request.pad,
			party = party,
			profile = request.profile,
			startedAt = self._state.deployStartedAt,
			deployPayload = payload,
		})
	else
		task.delay(self._gameFlowConfig.DeploymentFlyInSeconds, function()
			if self._state.phase == "Deployment" then
				self:ResolveDeployment()
			end
		end)
	end
end

function FlowService:SetDeploymentHandler(handler)
	self._deploymentHandler = handler
end

function FlowService:ResolveDeployment()
	local request = self._state.activeRequest
	if not request then
		return false, "no_active_deployment"
	end

	self._squadService:SetLocked(request.squadId, false)
	for _, player in ipairs(request.party) do
		if player and player.Parent then
			player:SetAttribute("DeploymentState", "Lobby")
		end
	end

	self._state.phase = "Lobby"
	self._state.activeRequest = nil
	self._state.activePad = nil
	self._state.intermissionEndsAt = 0
	self._state.deployStartedAt = nil
	self._deployPadLocked = false
	self:_broadcastLobbyState()
	self:_broadcastDeployState(request.party, {
		stage = "Lobby",
		status = "Mission staging ready.",
	})

	self.DeploymentResolved:Fire(request)
	return true
end

function FlowService:CompleteDeployment()
	local request = self._state.activeRequest
	if not request then
		return false, "no_active_deployment"
	end

	self._squadService:SetLocked(request.squadId, false)
	for _, player in ipairs(request.party) do
		if player and player.Parent then
			player:SetAttribute("DeploymentState", "Mission")
		end
	end

	self._state.phase = "Mission"
	self._state.activeRequest = nil
	self._state.activePad = nil
	self._state.intermissionEndsAt = 0
	self._state.deployStartedAt = nil
	self._deployPadLocked = false
	self:_broadcastLobbyState()
	self:_broadcastDeployState(request.party, {
		stage = "Mission",
		status = "Mission staging ready.",
	})

	self.DeploymentResolved:Fire(request)
	return true
end

function FlowService:ReturnPlayersToLobby(players, status)
	self._state.phase = "Lobby"
	self._state.activeRequest = nil
	self._state.activePad = nil
	self._state.intermissionEndsAt = 0
	self._state.deployStartedAt = nil
	self._deployPadLocked = false

	for _, player in ipairs(players) do
		if player and player.Parent then
			player:SetAttribute("DeploymentState", "Lobby")
			player:SetAttribute("InMission", false)
		end
	end

	self:_broadcastLobbyState()
	self:_broadcastDeployState(players, {
		stage = "Lobby",
		status = status or self._gameFlowConfig.LobbyName .. " online.",
	})
	return true
end

function FlowService:AbortActiveDeployment(status)
	local request = self._state.activeRequest
	if not request then
		return false, "no_active_deployment"
	end

	self._squadService:SetLocked(request.squadId, false)
	self:ReturnPlayersToLobby(request.party, status or "Deployment canceled. Back in the bunker.")
	self:_notifyPlayers(request.party, status or "Deployment canceled. Returning to bunker.")
	return true
end

function FlowService:GetPhase()
	return self._state.phase
end

function FlowService:IsDeployPadLocked()
	return self._deployPadLocked
end

function FlowService:GetState()
	return self._state
end

return FlowService
