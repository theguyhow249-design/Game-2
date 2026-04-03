local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local FlowService = {}
FlowService.__index = FlowService

local function getLobbyPlaza(lobbyName)
	local lobbyRoot = Workspace:FindFirstChild(lobbyName)
	if not lobbyRoot then
		for _, child in ipairs(Workspace:GetChildren()) do
			if child:GetAttribute("WorldType") == "LobbyHub" then
				lobbyRoot = child
				break
			end
		end
	end
	if not lobbyRoot then
		return nil
	end
	if lobbyRoot:IsA("Model") then
		return lobbyRoot
	end
	return lobbyRoot:FindFirstChildWhichIsA("Model")
end

local function findMissionEntryById(entries, entryId)
	if type(entryId) ~= "string" or entryId == "" then
		return nil
	end
	for _, entry in ipairs(entries or {}) do
		if entry.Id == entryId then
			return entry
		end
	end
	return nil
end

local function resolveMissionRuntimeParts(lobbyName)
	local lobbyRoot = Workspace:FindFirstChild(lobbyName)
	if not lobbyRoot then
		return nil, nil, nil
	end

	local missionStaging = lobbyRoot:FindFirstChild("MissionStaging", true)
	if not missionStaging then
		return nil, nil, nil
	end

	local missionSpawn = missionStaging:FindFirstChild("MissionSpawn", true)
		or missionStaging:FindFirstChild("DropMarker", true)
		or missionStaging:FindFirstChild("Base", true)
	local cameraStart = missionStaging:FindFirstChild("MissionCameraStart", true)
	local cameraEnd = missionStaging:FindFirstChild("MissionCameraEnd", true)
		or missionStaging:FindFirstChild("MissionCameraStop", true)

	return missionSpawn, cameraStart, cameraEnd
end

local MAP_VOTE_OPTION_COUNT = 3
local RECENT_MISSION_HISTORY = 4
local LAYOUT_PREVIEW_COPY = {
	arena_breach_yard = "Wide yard lanes with long sightlines and exposed flanks.",
	arena_service_tunnel = "Tight tunnel pressure with narrow fallback routes.",
	arena_crossroads = "Four approach lanes colliding at a central depot hold.",
	arena_reactor_fields = "Split reactor decks with elevated tower pressure.",
	arena_power_relay = "Chained relay nodes across split platforms with pressure on every flank.",
	arena_evac_tunnel = "Long evac corridor with staged checkpoints and very little cover once pressure spikes.",
	arena_blacksite_sweep = "Blacksite labs and command decks built for a final commander takedown.",
}

function FlowService.new(context)
	local self = setmetatable({}, FlowService)
	self._gameFlowConfig = context.GameFlowConfig
	self._contracts = context.Contracts
	self._remoteNames = context.RemoteNames
	self._remotes = context.Remotes
	self._missionConfig = context.MissionConfig
	self._squadService = context.SquadService
	self._scalingService = context.ScalingService
	self._tokenService = context.TokenService
	self._tokenEconomy = context.TokenEconomy
	self._antiExploitService = context.AntiExploitService
	self._state = {
		phase = "Lobby",
		activeRequest = nil,
		activePad = nil,
		intermissionEndsAt = 0,
	}
	self._registeredPads = {}
	self._registeredVotePads = {}
	self._voteTouchDebounce = {}
	self._deployPadDebounce = {}
	self._deployPadLocked = false
	self._nextMissionPreview = nil
	self._mapVote = nil
	self._mapVoteSessionId = 0
	self._recentMissionKeys = {}
	self._instanceDeploymentService = context.InstanceDeploymentService
	self._instanceDeploymentTransactions = {}
	self.IntermissionStarted = context.Signal.new()
	self.IntermissionTicked = context.Signal.new()
	self.DeploymentStarted = context.Signal.new()
	self.DeploymentResolved = context.Signal.new()
	self.PhaseChanged = context.Signal.new()
	return self
end

function FlowService:_isMissionRuntimeReady()
	local missionSpawnPath = Workspace:GetAttribute("MissionSpawnPath")
	local missionCameraStartPath = Workspace:GetAttribute("MissionCameraStartPath")
	local missionCameraEndPath = Workspace:GetAttribute("MissionCameraEndPath")
	if type(missionSpawnPath) == "string" and missionSpawnPath ~= ""
		and type(missionCameraStartPath) == "string" and missionCameraStartPath ~= ""
		and type(missionCameraEndPath) == "string" and missionCameraEndPath ~= "" then
		return true
	end

	local missionSpawn, cameraStart, cameraEnd = resolveMissionRuntimeParts(self._gameFlowConfig.LobbyName)
	if missionSpawn and cameraStart and cameraEnd then
		Workspace:SetAttribute("MissionSpawnPath", missionSpawn:GetFullName())
		Workspace:SetAttribute("MissionCameraStartPath", cameraStart:GetFullName())
		Workspace:SetAttribute("MissionCameraEndPath", cameraEnd:GetFullName())
		return true
	end

	return false
end

function FlowService:SetInstanceDeploymentService(service)
	self._instanceDeploymentService = service
end

function FlowService:Start()
	self:_rollNextMissionVote()
	self:_broadcastLobbyState()

	Players.PlayerAdded:Connect(function(player)
		self:_bindPlayerSpawn(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if self._mapVote and self._mapVote.votesByUserId then
			self._mapVote.votesByUserId[player.UserId] = nil
			self:_refreshVoteResults()
			self:_broadcastLobbyState()
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_bindPlayerSpawn(player)
	end

	for _, instance in ipairs(CollectionService:GetTagged("DeployPad")) do
		self:RegisterDeployPad(instance)
	end
	for _, instance in ipairs(CollectionService:GetTagged("MapVotePad")) do
		self:RegisterMapVotePad(instance)
	end

	CollectionService:GetInstanceAddedSignal("DeployPad"):Connect(function(instance)
		self:RegisterDeployPad(instance)
	end)
	CollectionService:GetInstanceAddedSignal("MapVotePad"):Connect(function(instance)
		self:RegisterMapVotePad(instance)
	end)

	self._squadService.SquadChanged:Connect(function()
		self:_broadcastLobbyState()
	end)

	self._squadService.SquadRemoved:Connect(function()
		self:_broadcastLobbyState()
	end)
end

function FlowService:_buildPreviewPayload(preview)
	if type(preview) ~= "table" then
		return nil
	end

	local scenario = findMissionEntryById(self._missionConfig and self._missionConfig.Scenarios, preview.scenarioId)
	local modifier = findMissionEntryById(self._missionConfig and self._missionConfig.MissionModifiers, preview.modifierId)
	local scenarioBonus = tonumber(scenario and scenario.RewardBonus) or 0
	local modifierBonus = tonumber(modifier and modifier.RewardBonus) or 0
	local totalRewardBonus = scenarioBonus + modifierBonus
	local threatScore = (tonumber(scenario and scenario.HealthScale) or 1) + (tonumber(scenario and scenario.DamageScale) or 1) + (tonumber(modifier and modifier.HealthScale) or 1) + (tonumber(modifier and modifier.DamageScale) or 1)
	local threatLabel = threatScore >= 4.25 and "HIGH" or (threatScore >= 4.1 and "ELEVATED" or "STANDARD")

	return {
		optionId = tostring(preview.optionId or ""),
		scenarioId = tostring(preview.scenarioId or ""),
		scenarioName = tostring(preview.scenarioName or "Hold The Core"),
		scenarioDescription = tostring(preview.scenarioDescription or "Standard bunker defense."),
		layoutId = tostring(preview.layoutId or ""),
		layoutName = tostring(preview.layoutName or "Breach Yard"),
		layoutDescription = tostring(preview.layoutDescription or "Wide yard lanes with long sightlines."),
		modifierId = tostring(preview.modifierId or "modifier_standard_ops"),
		modifierName = tostring(preview.modifierName or "Standard Ops"),
		modifierDescription = tostring(preview.modifierDescription or "Baseline bunker deployment."),
		rewardBonus = totalRewardBonus,
		threatLabel = threatLabel,
	}
end

function FlowService:_buildVoteOption(optionId, scenario, layout, modifier)
	local scenarioBonus = tonumber(scenario and scenario.RewardBonus) or 0
	local modifierBonus = tonumber(modifier and modifier.RewardBonus) or 0
	local totalRewardBonus = scenarioBonus + modifierBonus
	local threatScore = (tonumber(scenario and scenario.HealthScale) or 1) + (tonumber(scenario and scenario.DamageScale) or 1) + (tonumber(modifier and modifier.HealthScale) or 1) + (tonumber(modifier and modifier.DamageScale) or 1)
	local threatLabel = threatScore >= 4.25 and "HIGH" or (threatScore >= 4.1 and "ELEVATED" or "STANDARD")
	return {
		optionId = tostring(optionId),
		scenarioId = scenario and scenario.Id or "directive_hold",
		scenarioName = scenario and scenario.DisplayName or "Hold The Core",
		scenarioDescription = scenario and scenario.Description or "Standard bunker defense.",
		layoutId = layout and layout.Id or "arena_breach_yard",
		layoutName = layout and layout.DisplayName or "Breach Yard",
		layoutDescription = layout and (LAYOUT_PREVIEW_COPY[layout.Id] or ("Deployment route: " .. tostring(layout.DisplayName or "Unknown layout") .. ".")) or "Wide yard lanes with long sightlines.",
		modifierId = modifier and modifier.Id or "modifier_standard_ops",
		modifierName = modifier and modifier.DisplayName or "Standard Ops",
		modifierDescription = modifier and modifier.Description or "Baseline bunker deployment.",
		rewardBonus = totalRewardBonus,
		threatLabel = threatLabel,
		voteCount = 0,
	}
end

function FlowService:_buildMissionKey(scenarioId, layoutId, modifierId)
	return ("%s::%s::%s"):format(
		tostring(scenarioId or "directive_hold"),
		tostring(layoutId or "arena_breach_yard"),
		tostring(modifierId or "modifier_standard_ops")
	)
end

function FlowService:_rememberMissionPreview(preview)
	if type(preview) ~= "table" then
		return
	end
	local missionKey = self:_buildMissionKey(preview.scenarioId, preview.layoutId, preview.modifierId)
	for index = #self._recentMissionKeys, 1, -1 do
		if self._recentMissionKeys[index] == missionKey then
			table.remove(self._recentMissionKeys, index)
		end
	end
	table.insert(self._recentMissionKeys, 1, missionKey)
	while #self._recentMissionKeys > RECENT_MISSION_HISTORY do
		table.remove(self._recentMissionKeys)
	end
end

function FlowService:_shuffleList(list)
	for index = #list, 2, -1 do
		local swapIndex = math.random(1, index)
		list[index], list[swapIndex] = list[swapIndex], list[index]
	end
end

function FlowService:_refreshVoteResults()
	if not self._mapVote or not self._mapVote.options then
		self._nextMissionPreview = nil
		return
	end

	local options = self._mapVote.options
	local voteCounts = {}
	local currentPlayers = {}
	for _, player in ipairs(Players:GetPlayers()) do
		currentPlayers[player.UserId] = true
	end

	for userId, optionId in pairs(self._mapVote.votesByUserId or {}) do
		if currentPlayers[userId] == true then
			voteCounts[optionId] = (voteCounts[optionId] or 0) + 1
		end
	end

	local leadingOption = options[1]
	local leadingVoteCount = -1
	local previousLeadingOptionId = self._mapVote.leadingOptionId
	for _, option in ipairs(options) do
		option.voteCount = voteCounts[option.optionId] or 0
		if option.voteCount > leadingVoteCount then
			leadingOption = option
			leadingVoteCount = option.voteCount
		elseif option.voteCount == leadingVoteCount and option.optionId == previousLeadingOptionId then
			leadingOption = option
		end
	end

	self._mapVote.leadingOptionId = leadingOption and leadingOption.optionId or nil
	self._nextMissionPreview = self:_buildPreviewPayload(leadingOption)
end

function FlowService:_buildVotePayload()
	if not self._mapVote then
		return nil
	end

	local options = {}
	for index, option in ipairs(self._mapVote.options or {}) do
		options[index] = {
			optionId = tostring(option.optionId or ""),
			scenarioName = tostring(option.scenarioName or "Hold The Core"),
			layoutName = tostring(option.layoutName or "Breach Yard"),
			modifierName = tostring(option.modifierName or "Standard Ops"),
			modifierDescription = tostring(option.modifierDescription or ""),
			voteCount = math.max(0, math.floor(option.voteCount or 0)),
		}
	end

	return {
		sessionId = self._mapVote.sessionId or 0,
		leadingOptionId = self._mapVote.leadingOptionId,
		options = options,
	}
end

function FlowService:_rollMissionPreview(previousPreview)
	local missionConfig = self._missionConfig
	if not missionConfig then
		return nil
	end

	local scenario = missionConfig.getScenario()
	local layout = missionConfig.getLayout()
	local modifier = missionConfig.getModifier and missionConfig.getModifier() or nil

	if previousPreview then
		for _ = 1, 4 do
			local sameScenario = scenario and previousPreview.scenarioId == scenario.Id
			local sameLayout = layout and previousPreview.layoutId == layout.Id
			local sameModifier = modifier and previousPreview.modifierId == modifier.Id
			if not (sameScenario and sameLayout and sameModifier) then
				break
			end
			scenario = missionConfig.getScenario()
			layout = missionConfig.getLayout()
			modifier = missionConfig.getModifier and missionConfig.getModifier() or nil
		end
	end

	return self:_buildPreviewPayload({
		optionId = tostring(previousPreview and previousPreview.optionId or ""),
		scenarioId = scenario and scenario.Id or "directive_hold",
		scenarioName = scenario and scenario.DisplayName or "Hold The Core",
		scenarioDescription = scenario and scenario.Description or "Standard bunker defense.",
		layoutId = layout and layout.Id or "arena_breach_yard",
		layoutName = layout and layout.DisplayName or "Breach Yard",
		layoutDescription = layout and (LAYOUT_PREVIEW_COPY[layout.Id] or ("Deployment route: " .. tostring(layout.DisplayName or "Unknown layout") .. ".")) or "Wide yard lanes with long sightlines.",
		modifierId = modifier and modifier.Id or "modifier_standard_ops",
		modifierName = modifier and modifier.DisplayName or "Standard Ops",
		modifierDescription = modifier and modifier.Description or "Baseline bunker deployment.",
	})
end

function FlowService:_rollNextMissionVote(previousPreview)
	local missionConfig = self._missionConfig
	if not missionConfig then
		self._mapVote = nil
		self._nextMissionPreview = nil
		return
	end

	local combos = {}
	local previousKey = previousPreview and self:_buildMissionKey(previousPreview.scenarioId, previousPreview.layoutId, previousPreview.modifierId) or nil
	local recentLookup = {}
	for _, missionKey in ipairs(self._recentMissionKeys or {}) do
		recentLookup[missionKey] = true
	end

	local function appendCombos(includeRecent)
		for _, layout in ipairs(missionConfig.Layouts or {}) do
			for _, scenario in ipairs(missionConfig.Scenarios or {}) do
				for _, modifier in ipairs(missionConfig.MissionModifiers or {}) do
					local missionKey = self:_buildMissionKey(scenario.Id, layout.Id, modifier.Id)
					local isRecent = recentLookup[missionKey] == true
					local isPrevious = previousKey ~= nil and missionKey == previousKey
					if (includeRecent or not isRecent) and not isPrevious then
						table.insert(combos, {
							missionKey = missionKey,
							layout = layout,
							scenario = scenario,
							modifier = modifier,
						})
					end
				end
			end
		end
	end

	appendCombos(false)
	if #combos < MAP_VOTE_OPTION_COUNT then
		appendCombos(true)
	end

	self:_shuffleList(combos)

	local options = {}
	local usedMissionKeys = {}
	local usedLayouts = {}
	for _, combo in ipairs(combos) do
		if #options >= MAP_VOTE_OPTION_COUNT then
			break
		end
		if not usedMissionKeys[combo.missionKey] and (not usedLayouts[combo.layout.Id] or #combos < MAP_VOTE_OPTION_COUNT) then
			table.insert(options, self:_buildVoteOption(("map_%d"):format(#options + 1), combo.scenario, combo.layout, combo.modifier))
			usedMissionKeys[combo.missionKey] = true
			usedLayouts[combo.layout.Id] = true
		end
	end

	if #options == 0 then
		local preview = self:_rollMissionPreview(previousPreview)
		options[1] = self:_buildVoteOption("map_1", {
			Id = preview and preview.scenarioId or "directive_hold",
			DisplayName = preview and preview.scenarioName or "Hold The Core",
			Description = preview and preview.scenarioDescription or "Standard bunker defense.",
		}, {
			Id = preview and preview.layoutId or "arena_breach_yard",
			DisplayName = preview and preview.layoutName or "Breach Yard",
		}, {
			Id = preview and preview.modifierId or "modifier_standard_ops",
			DisplayName = preview and preview.modifierName or "Standard Ops",
			Description = preview and preview.modifierDescription or "Baseline bunker deployment.",
		})
	end

	self._mapVote = {
		sessionId = self._mapVoteSessionId + 1,
		options = options,
		votesByUserId = {},
		leadingOptionId = options[1] and options[1].optionId or nil,
	}
	self._mapVoteSessionId = self._mapVote.sessionId
	self:_refreshVoteResults()
end

function FlowService:ForceMissionPreview(scenarioId, layoutId, modifierId)
	local missionConfig = self._missionConfig
	if not missionConfig then
		return false, "missing_config"
	end

	local scenario = findMissionEntryById(missionConfig.Scenarios, scenarioId)
	local layout = findMissionEntryById(missionConfig.Layouts, layoutId)
	local modifier = findMissionEntryById(missionConfig.MissionModifiers, modifierId or "modifier_standard_ops")
	if not scenario or not layout or not modifier then
		return false, "invalid_preview"
	end

	local forcedOption = self:_buildVoteOption("map_1", scenario, layout, modifier)
	local options = { forcedOption }
	local forcedKey = self:_buildMissionKey(scenario.Id, layout.Id, modifier.Id)

	for _, option in ipairs((self._mapVote and self._mapVote.options) or {}) do
		if #options >= MAP_VOTE_OPTION_COUNT then
			break
		end
		local optionKey = self:_buildMissionKey(option.scenarioId, option.layoutId, option.modifierId)
		if optionKey ~= forcedKey then
			table.insert(options, self:_buildVoteOption(
				("map_%d"):format(#options + 1),
				findMissionEntryById(missionConfig.Scenarios, option.scenarioId),
				findMissionEntryById(missionConfig.Layouts, option.layoutId),
				findMissionEntryById(missionConfig.MissionModifiers, option.modifierId)
			))
		end
	end

	if #options < MAP_VOTE_OPTION_COUNT then
		local combos = {}
		for _, candidateLayout in ipairs(missionConfig.Layouts or {}) do
			for _, candidateScenario in ipairs(missionConfig.Scenarios or {}) do
				for _, candidateModifier in ipairs(missionConfig.MissionModifiers or {}) do
					local missionKey = self:_buildMissionKey(candidateScenario.Id, candidateLayout.Id, candidateModifier.Id)
					if missionKey ~= forcedKey then
						table.insert(combos, {
							missionKey = missionKey,
							layout = candidateLayout,
							scenario = candidateScenario,
							modifier = candidateModifier,
						})
					end
				end
			end
		end

		self:_shuffleList(combos)
		local usedKeys = {
			[forcedKey] = true,
		}
		for _, option in ipairs(options) do
			usedKeys[self:_buildMissionKey(option.scenarioId, option.layoutId, option.modifierId)] = true
		end
		for _, combo in ipairs(combos) do
			if #options >= MAP_VOTE_OPTION_COUNT then
				break
			end
			if not usedKeys[combo.missionKey] then
				table.insert(options, self:_buildVoteOption(("map_%d"):format(#options + 1), combo.scenario, combo.layout, combo.modifier))
				usedKeys[combo.missionKey] = true
			end
		end
	end

	self._mapVote = {
		sessionId = self._mapVoteSessionId + 1,
		options = options,
		votesByUserId = {},
		leadingOptionId = forcedOption.optionId,
	}
	self._mapVoteSessionId = self._mapVote.sessionId
	self._nextMissionPreview = self:_buildPreviewPayload(forcedOption)
	self:_broadcastLobbyState()
	return true, self._nextMissionPreview
end

function FlowService:_getLobbySpawn()
	local lobby = Workspace:FindFirstChild(self._gameFlowConfig.LobbyName)
	if not lobby then
		for _, child in ipairs(Workspace:GetChildren()) do
			if child:GetAttribute("WorldType") == "LobbyHub" then
				lobby = child
				break
			end
		end
	end
	if not lobby then
		return nil
	end

	local arrivalAnchor = lobby:FindFirstChild("LobbyArrivalAnchor", true)
	if arrivalAnchor and arrivalAnchor:IsA("BasePart") then
		return arrivalAnchor
	end

	for _, spawn in ipairs(CollectionService:GetTagged("LobbySpawn")) do
		if spawn:IsDescendantOf(lobby) and spawn:IsA("BasePart") and spawn:FindFirstAncestor("MissionStaging") == nil then
			if spawn.Name == "LobbyArrivalAnchor" then
				return spawn
			end
			return spawn
		end
	end

	local nestedSpawn = lobby:FindFirstChild("LobbySpawn", true)
	if nestedSpawn and nestedSpawn:IsA("BasePart") and nestedSpawn:FindFirstAncestor("MissionStaging") == nil then
		return nestedSpawn
	end

	for _, descendant in ipairs(lobby:GetDescendants()) do
		if descendant:IsA("SpawnLocation") and descendant:FindFirstAncestor("MissionStaging") == nil then
			return descendant
		end
	end

	return nil
end

function FlowService:_shouldUseLobbySpawn(player)
	local deploymentState = tostring(player:GetAttribute("DeploymentState") or "Lobby")
	return not (
		player:GetAttribute("InMission") == true
		or player:GetAttribute("MissionInstancePending") == true
		or deploymentState == "Mission"
		or deploymentState == "Deployment"
		or deploymentState == "Intermission"
		or deploymentState == "Returning"
		or deploymentState == "ReturnFailed"
		or self._state.phase == "Deployment"
		or self._state.phase == "Intermission"
	)
end

function FlowService:_movePlayerToLobbySpawn(player, character)
	if not (player and character and character.Parent) then
		return false
	end
	if not self:_shouldUseLobbySpawn(player) then
		return false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 3)
	if not rootPart then
		return false
	end

	local lobbySpawn = nil
	for _ = 1, 40 do
		lobbySpawn = self:_getLobbySpawn()
		if lobbySpawn then
			break
		end
		task.wait(0.1)
	end
	if not lobbySpawn then
		return false
	end
	if lobbySpawn:IsA("SpawnLocation") then
		player.RespawnLocation = lobbySpawn
	end

	local targetCFrame = lobbySpawn.CFrame + Vector3.new(0, 4, 0)
	for _ = 1, 8 do
		if not (character.Parent and rootPart.Parent) then
			return false
		end
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
		character:PivotTo(targetCFrame)
		task.wait(0.1)
	end

	player:SetAttribute("DeploymentState", "Lobby")
	player:SetAttribute("InMission", false)
	return true
end

function FlowService:_maintainLobbySpawn(player)
	task.spawn(function()
		local attempts = 0
		while player and player.Parent == Players and attempts < 60 do
			attempts += 1
			if self:_shouldUseLobbySpawn(player) then
				local character = player.Character
				local lobbySpawn = self:_getLobbySpawn()
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				if character and rootPart and lobbySpawn then
					if lobbySpawn:IsA("SpawnLocation") then
						player.RespawnLocation = lobbySpawn
					end
					local distance = (rootPart.Position - lobbySpawn.Position).Magnitude
					if distance > 24 then
						self:_movePlayerToLobbySpawn(player, character)
					end
				end
			end
			task.wait(0.5)
		end
	end)
end

function FlowService:_bindPlayerSpawn(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(0.1)
		self:_movePlayerToLobbySpawn(player, character)
		self:_maintainLobbySpawn(player)
	end)
	if player.Character then
		task.defer(function()
			self:_movePlayerToLobbySpawn(player, player.Character)
			self:_maintainLobbySpawn(player)
		end)
	end
end

function FlowService:ForceLobbySpawnSync()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			task.defer(function()
				self:_movePlayerToLobbySpawn(player, player.Character)
			end)
		end
	end
end

function FlowService:_broadcastLobbyState()
	local lobbyState = self._contracts.makeLobbyState(
		self._state.phase,
		self._squadService:GetActiveSquadCount(),
		true,
		self._deployPadLocked,
		self._nextMissionPreview,
		self:_buildVotePayload()
	)

	Workspace:SetAttribute("GamePhase", self._state.phase)
	Workspace:SetAttribute("LobbyPhase", self._state.phase)
	Workspace:SetAttribute("ActiveSquads", lobbyState.activeSquads)
	Workspace:SetAttribute("ShopOpen", lobbyState.shopOpen)
	Workspace:SetAttribute("DeployPadLocked", lobbyState.deployPadLocked)
	self:_updateDeployVoteBoard(lobbyState.nextMissionVote)
	if self._remotes then
		self._remotes:FireEvent(self._remoteNames.Events.LobbyStateChanged, lobbyState)
	end

	return lobbyState
end

function FlowService:_getDeployVoteBoards()
	local plaza = getLobbyPlaza(self._gameFlowConfig.LobbyName)
	local board = plaza and (
		plaza:FindFirstChild("VoteBoard", true)
		or plaza:FindFirstChild("Vote Model", true)
		or plaza:FindFirstChild("DeployVoteDeck", true)
	)
	if board and board.Name == "DeployVoteDeck" then
		board = board:FindFirstChild("VoteBoard") or board:FindFirstChild("VoteBoard", true)
	end
	if board and not board:IsA("BasePart") then
		board = board:FindFirstChildWhichIsA("BasePart", true)
	end
	local frames = {}
	if board then
		for _, child in ipairs(board:GetChildren()) do
			if child:IsA("SurfaceGui") and (child.Name == "BoardGui" or child.Name == "BoardGuiMirror") then
				local frame = child:FindFirstChild("Frame")
				if frame and frame:IsA("Frame") then
					table.insert(frames, frame)
				end
			end
		end
	end
	return frames
end

function FlowService:_updateDeployVoteBoard(votePayload)
	local padBaseColors = {
		[1] = Color3.fromRGB(104, 184, 124),
		[2] = Color3.fromRGB(90, 146, 218),
		[3] = Color3.fromRGB(208, 164, 94),
	}
	for _, frame in ipairs(self:_getDeployVoteBoards()) do
		local title = frame:FindFirstChild("Title")
		local subtitle = frame:FindFirstChild("Subtitle")
		if title and title:IsA("TextLabel") then
			title.Text = "Vote For The Next Run"
		end
		if subtitle and subtitle:IsA("TextLabel") then
			subtitle.Text = self._state.phase == "Lobby"
				and "Step on a floor pad to cast your vote."
				or "Voting locks while the server is deploying."
		end

		for index = 1, 3 do
			local option = votePayload and votePayload.options and votePayload.options[index] or nil
			local optionFrame = frame:FindFirstChild("Option" .. tostring(index))
			if optionFrame and optionFrame:IsA("Frame") then
				optionFrame.Visible = option ~= nil
				local mapLabel = optionFrame:FindFirstChild("MapName")
				local scenarioLabel = optionFrame:FindFirstChild("Scenario")
				local votesLabel = optionFrame:FindFirstChild("Votes")
				local padLabel = optionFrame:FindFirstChild("PadLabel")
				local leadingChip = optionFrame:FindFirstChild("LeadingChip")
				if mapLabel and mapLabel:IsA("TextLabel") then
					mapLabel.Text = option and tostring(option.layoutName or "Unknown Map") or ""
				end
				if scenarioLabel and scenarioLabel:IsA("TextLabel") then
					scenarioLabel.Text = option and tostring(option.scenarioName or "Mission") or ""
				end
				if votesLabel and votesLabel:IsA("TextLabel") then
					local count = option and math.max(0, tonumber(option.voteCount) or 0) or 0
					votesLabel.Text = ("%d vote%s"):format(count, count == 1 and "" or "s")
				end
				if padLabel and padLabel:IsA("TextLabel") then
					padLabel.Text = ("PAD %d"):format(index)
				end

				local isLeading = option ~= nil and votePayload and option.optionId == votePayload.leadingOptionId
				if leadingChip and leadingChip:IsA("TextLabel") then
					leadingChip.Visible = isLeading
				end
				local stroke = optionFrame:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = isLeading and Color3.fromRGB(120, 212, 140) or Color3.fromRGB(112, 98, 78)
					stroke.Transparency = isLeading and 0.06 or 0.22
				end
				optionFrame.BackgroundColor3 = isLeading and Color3.fromRGB(244, 245, 232) or Color3.fromRGB(234, 229, 218)
			end
		end
	end

	for index = 1, 3 do
		local option = votePayload and votePayload.options and votePayload.options[index] or nil

		for _, pad in ipairs(CollectionService:GetTagged("MapVotePad")) do
			if pad:IsA("BasePart") and math.floor(tonumber(pad:GetAttribute("VoteOptionIndex")) or 0) == index then
				local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
				if prompt then
					prompt.ObjectText = option and tostring(option.layoutName or "Map Vote") or "Map Vote"
				end
				local sign = pad:FindFirstChild("WorldText")
				local label = sign and sign:FindFirstChildWhichIsA("TextLabel")
				if label then
					local count = option and math.max(0, tonumber(option.voteCount) or 0) or 0
					local mapName = option and tostring(option.layoutName or ("PAD " .. tostring(index))) or ("PAD " .. tostring(index))
					label.Text = string.format("%s\n%d vote%s", mapName, count, count == 1 and "" or "s")
				end
				local isLeading = votePayload and option and option.optionId == votePayload.leadingOptionId
				pad.Color = isLeading and Color3.fromRGB(108, 182, 112) or (padBaseColors[index] or pad.Color)
				local glow = pad.Parent and pad.Parent:FindFirstChild("VotePadGlow" .. tostring(index))
				if glow and glow:IsA("BasePart") then
					glow.Transparency = isLeading and 0.18 or 0.58
					glow.Color = isLeading and Color3.fromRGB(214, 255, 176) or ({
						[1] = Color3.fromRGB(178, 255, 154),
						[2] = Color3.fromRGB(158, 212, 255),
						[3] = Color3.fromRGB(255, 212, 156),
					})[index] or glow.Color
				end
				local ring = pad.Parent and pad.Parent:FindFirstChild("VotePadRing" .. tostring(index))
				if ring and ring:IsA("BasePart") then
					ring.Transparency = isLeading and 0.14 or 0.86
					ring.Color = isLeading and Color3.fromRGB(242, 255, 196) or ({
						[1] = Color3.fromRGB(178, 255, 154),
						[2] = Color3.fromRGB(158, 212, 255),
						[3] = Color3.fromRGB(255, 212, 156),
					})[index] or ring.Color
				end
			end
		end
	end
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

function FlowService:SetPartyPlayerState(players, stateName, profile)
	self:_setPlayerState(players, stateName, profile)
end

function FlowService:_broadcastDeployState(players, payload)
	if self._remotes then
		self._remotes:FireEventForMany(players, self._remoteNames.Events.DeployStateChanged, payload)
	end
end

function FlowService:BroadcastPartyDeployState(players, payload)
	self:_broadcastDeployState(players, payload)
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

function FlowService:_getPreviewForPlayer(player)
	if self._mapVote and self._mapVote.options then
		local optionId = self._mapVote.votesByUserId and self._mapVote.votesByUserId[player.UserId] or nil
		if optionId then
			for _, option in ipairs(self._mapVote.options) do
				if option.optionId == optionId then
					return self:_buildPreviewPayload(option)
				end
			end
		end
	end
	return self._nextMissionPreview
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

function FlowService:_beginInstanceDeploymentTransaction(squad, party)
	if not squad or not squad.id or squad.id == "" then
		return false, "missing_squad"
	end
	if self._instanceDeploymentTransactions[squad.id] then
		return false, "busy"
	end

	local chargedPlayers = {}
	for _, player in ipairs(party) do
		local success = self._tokenService:SpendTokens(player, self._tokenEconomy.DeployTokenCost, "DeploySpend", "deployment_cost")
		if not success then
			for _, chargedPlayer in ipairs(chargedPlayers) do
				if chargedPlayer and chargedPlayer.Parent == Players then
					self._tokenService:AddTokens(chargedPlayer, self._tokenEconomy.DeployTokenCost, "DeployRefund", "deployment_rollback")
				end
			end
			return false, "spend_failed", player
		end
		table.insert(chargedPlayers, player)
	end

	self._instanceDeploymentTransactions[squad.id] = {
		squadId = squad.id,
		chargedPlayers = chargedPlayers,
		startedAt = os.clock(),
	}
	return true
end

function FlowService:_refundInstanceDeploymentTransaction(transaction, reason)
	if type(transaction) ~= "table" then
		return
	end

	for _, player in ipairs(transaction.chargedPlayers or {}) do
		if player and player.Parent == Players then
			self._tokenService:AddTokens(player, self._tokenEconomy.DeployTokenCost, "DeployRefund", reason or "deployment_launch_failed")
		end
	end
end

function FlowService:StartMissionInstance(payload)
	local party = payload and payload.party or {}
	local profile = payload and payload.profile or nil
	self._state.phase = "Mission"
	self._state.activeRequest = {
		squadId = payload and payload.squadId or nil,
		party = party,
		profile = profile,
		preview = payload and payload.preview or nil,
	}
	self._state.activePad = nil
	self._state.intermissionEndsAt = 0
	self._state.deployStartedAt = nil
	self._deployPadLocked = false
	self:_setPlayerState(party, "Mission", profile)
	self:_broadcastLobbyState()
	self:_broadcastDeployState(party, {
		stage = "Mission",
		status = "Mission staging ready.",
		squadId = payload and payload.squadId or nil,
		playerCount = #party,
	})
end

function FlowService:UnlockSquadAfterDispatch(squadId)
	if squadId and squadId ~= "" then
		self._instanceDeploymentTransactions[squadId] = nil
	end
	if squadId and squadId ~= "" then
		self._squadService:SetLocked(squadId, false)
	end
end

function FlowService:UnlockSquadAfterFailedDeployment(squadId)
	local transaction = squadId and self._instanceDeploymentTransactions[squadId] or nil
	if transaction then
		self:_refundInstanceDeploymentTransaction(transaction, "deployment_launch_failed")
		self._instanceDeploymentTransactions[squadId] = nil
	end
	if squadId and squadId ~= "" then
		self._squadService:SetLocked(squadId, false)
	end
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

	local function requestFromPad(player)
		if not player or player.Parent ~= Players then
			return
		end

		local debounceKey = tostring(player.UserId) .. ":" .. tostring(pad:GetFullName())
		local now = os.clock()
		if self._deployPadDebounce[debounceKey] and (now - self._deployPadDebounce[debounceKey]) < 1.5 then
			return
		end
		self._deployPadDebounce[debounceKey] = now
		self:RequestDeployment(player, pad)
	end

	prompt.Triggered:Connect(function(player)
		requestFromPad(player)
	end)

	if pad:GetAttribute("AutoDeployOnTouch") == true then
		pad.Touched:Connect(function(hit)
			local character = hit and hit.Parent
			if not character then
				return
			end

			local player = Players:GetPlayerFromCharacter(character)
			if player then
				requestFromPad(player)
			end
		end)
	end
end

function FlowService:RegisterMapVotePad(instance)
	if self._registeredVotePads[instance] then
		return
	end

	local pad = instance
	if not pad:IsA("BasePart") then
		pad = pad:FindFirstChildWhichIsA("BasePart", true)
	end
	if not pad or not pad:IsA("BasePart") then
		return
	end

	self._registeredVotePads[instance] = true
	self:_updateDeployVoteBoard(self:_buildVotePayload())

	local function castVote(player)
		if not player or player.Parent ~= Players or self._state.phase ~= "Lobby" then
			return
		end
		local optionIndex = math.max(1, math.floor(tonumber(pad:GetAttribute("VoteOptionIndex")) or 1))
		local option = self._mapVote and self._mapVote.options and self._mapVote.options[optionIndex] or nil
		if option and option.optionId then
			self:RequestMapVote(player, option.optionId)
		end
	end

	pad.Touched:Connect(function(hit)
		local character = hit and hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local debounceKey = tostring(player.UserId) .. ":" .. tostring(pad:GetFullName())
		local now = os.clock()
		if self._voteTouchDebounce[debounceKey] and (now - self._voteTouchDebounce[debounceKey]) < 1.25 then
			return
		end
		self._voteTouchDebounce[debounceKey] = now
		castVote(player)
	end)

	local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(castVote)
	end
end

function FlowService:RequestDeployment(requestingPlayer, pad)
	if self._antiExploitService and not self._antiExploitService:AllowRequest(requestingPlayer, "DeployWorldAction", 3, 2.5) then
		warn("[FlowService] RequestDeployment denied: rate_limited")
		return false, "rate_limited", nil
	end
	if pad and self._antiExploitService and not self._antiExploitService:RequireProximity(requestingPlayer, pad, 18, "deploy_pad_distance") then
		warn("[FlowService] RequestDeployment denied: too_far")
		return false, "too_far", nil
	end

	if self._instanceDeploymentService and not self._instanceDeploymentService:IsMissionInstanceServer() then
		local squad, party = self:_buildParty(requestingPlayer)
		if not squad or not party then
			return false, "missing_squad", self._state
		end
		if squad.locked or self._instanceDeploymentTransactions[squad.id] then
			return false, "busy", nil
		end

		local canDeploy, blockedPlayer = self:_canPartyDeploy(party)
		if not canDeploy then
			local blockedName = blockedPlayer and blockedPlayer.DisplayName or "A squad member"
			self:_notifyPlayers(party, ("%s needs more deploy tokens."):format(blockedName))
			return false, "insufficient_tokens", blockedPlayer and blockedPlayer.UserId or nil
		end

		local spendSuccess, spendReason = self:_beginInstanceDeploymentTransaction(squad, party)
		if not spendSuccess then
			if spendReason == "busy" then
				return false, "busy", nil
			end
			self:_notifyPlayers(party, "Unable to spend deploy tokens for this run.")
			return false, "spend_failed", nil
		end

		local profile = self._scalingService:GetProfile(#party)
		local preview = self:_getPreviewForPlayer(requestingPlayer)
		self._squadService:SetLocked(squad.id, true)
		local started = self._instanceDeploymentService:DeployPartyToMissionInstance(squad, party, profile, preview)
		if not started then
			self:UnlockSquadAfterFailedDeployment(squad.id)
			self:_notifyPlayers(party, "Mission instance launch failed. Staying in lobby.")
			return false, "launch_failed", nil
		end
		return true, "started", {
			squadId = squad.id,
			party = party,
			profile = profile,
			preview = preview,
		}
	end

	if self._state.phase ~= "Lobby" then
		warn(("[FlowService] RequestDeployment denied: busy | phase=%s"):format(tostring(self._state.phase)))
		return false, "busy", self._state
	end
	if not self:_isMissionRuntimeReady() then
		warn(("[FlowService] Deployment blocked because mission staging paths are unavailable | spawn=%s | cameraStart=%s | cameraEnd=%s"):format(
			tostring(Workspace:GetAttribute("MissionSpawnPath")),
			tostring(Workspace:GetAttribute("MissionCameraStartPath")),
			tostring(Workspace:GetAttribute("MissionCameraEndPath"))
		))
		return false, "mission_unavailable", nil
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
		preview = self._nextMissionPreview,
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
		warn("[FlowService] _beginDeployment aborted: no active request")
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
	-- Validate camera paths are available before deployment
	if not payload.cameraStart or not payload.cameraEnd then
		warn("[FlowService] Camera paths not available for deployment cinematic. Skipping cinematic.")
		payload.cameraStart = nil
		payload.cameraEnd = nil
	end

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
	self:_rememberMissionPreview(request.preview)
	self:_rollNextMissionVote(request.preview)
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

function FlowService:GetNextMissionPreview()
	return self._nextMissionPreview
end

function FlowService:GetMapVoteState()
	return self:_buildVotePayload()
end

function FlowService:RequestMapVote(player, optionId)
	if self._antiExploitService and not self._antiExploitService:AllowRequest(player, "MapVoteAction", 6, 2) then
		return false, "rate_limited"
	end
	if self._state.phase ~= "Lobby" then
		return false, "busy"
	end
	if type(optionId) ~= "string" or optionId == "" then
		return false, "invalid_option"
	end
	if not self._mapVote or not self._mapVote.options then
		self:_rollNextMissionVote()
	end

	local selectedOption = nil
	for _, option in ipairs(self._mapVote.options or {}) do
		if option.optionId == optionId then
			selectedOption = option
			break
		end
	end
	if not selectedOption then
		return false, "invalid_option"
	end

	self._mapVote.votesByUserId[player.UserId] = optionId
	self:_refreshVoteResults()
	local lobbyState = self:_broadcastLobbyState()
	return true, {
		selectedOptionId = optionId,
		layoutName = selectedOption.layoutName,
		lobbyState = lobbyState,
	}
end

return FlowService
