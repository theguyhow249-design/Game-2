local ReplicatedStorage = game:GetService("ReplicatedStorage")

local serverRoot = script.Parent
local servicesFolder = serverRoot:WaitForChild("Services")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")

local GameFlowConfig = require(sharedFolder:WaitForChild("GameFlowConfig"))
local GamePassConfig = require(sharedFolder:WaitForChild("GamePassConfig"))
local DailyOpsConfig = require(sharedFolder:WaitForChild("DailyOpsConfig"))
local MissionConfig = require(sharedFolder:WaitForChild("MissionConfig"))
local RemoteNames = require(sharedFolder:WaitForChild("RemoteNames"))
local SkillTreeConfig = require(sharedFolder:WaitForChild("SkillTreeConfig"))
local SubscriptionConfig = require(sharedFolder:WaitForChild("SubscriptionConfig"))
local TokenEconomy = require(sharedFolder:WaitForChild("TokenEconomy"))
local SquadConfig = require(sharedFolder:WaitForChild("SquadConfig"))
local Contracts = require(sharedFolder:WaitForChild("Contracts"))

local Signal = require(servicesFolder:WaitForChild("Signal"))
local RemoteHub = require(servicesFolder:WaitForChild("RemoteHub"))
local PersistenceService = require(servicesFolder:WaitForChild("PersistenceService"))
local GamePassService = require(servicesFolder:WaitForChild("GamePassService"))
local RoleService = require(servicesFolder:WaitForChild("RoleService"))
local SkillTreeService = require(servicesFolder:WaitForChild("SkillTreeService"))
local SubscriptionService = require(servicesFolder:WaitForChild("SubscriptionService"))
local TokenService = require(servicesFolder:WaitForChild("TokenService"))
local AntiExploitService = require(servicesFolder:WaitForChild("AntiExploitService"))
local SquadService = require(servicesFolder:WaitForChild("SquadService"))
local RewardService = require(servicesFolder:WaitForChild("RewardService"))
local DailyOpsService = require(servicesFolder:WaitForChild("DailyOpsService"))
local LeaderboardService = require(servicesFolder:WaitForChild("LeaderboardService"))
local LeaderstatsService = require(servicesFolder:WaitForChild("LeaderstatsService"))
local InventoryService = require(servicesFolder:WaitForChild("InventoryService"))
local ShopService = require(servicesFolder:WaitForChild("ShopService"))
local ScalingService = require(servicesFolder:WaitForChild("ScalingService"))
local FlowService = require(servicesFolder:WaitForChild("FlowService"))
local ActivityService = require(servicesFolder:WaitForChild("ActivityService"))
local DuelService = require(servicesFolder:WaitForChild("DuelService"))
local MissionService = require(servicesFolder:WaitForChild("MissionService"))
local InstanceDeploymentService = require(servicesFolder:WaitForChild("InstanceDeploymentService"))
local AdminService = require(servicesFolder:WaitForChild("AdminService"))
local NameplateService = require(servicesFolder:WaitForChild("NameplateService"))

local ServerSystems = {}

local started = false
local controller = nil

local function buildBootstrapData(player, services, config)
	local squadSnapshot = services.SquadService:GetSquadSnapshot(player)
	local dailyRewardState = services.RewardService:GetDailyRewardState(player)
	local unlocks = services.InventoryService:GetUnlockedItems(player)
	local weaponExperience = services.PersistenceService:GetWeaponExperienceMap(player)
	local equippedWeapon = services.InventoryService:GetEquippedWeaponId(player)
	local equippedCosmetic = services.InventoryService:GetEquippedCosmetic(player)
	local stats = services.PersistenceService:GetStats(player)
	local skillTree = services.SkillTreeService:BuildPayload(player)
	local subscription = services.SubscriptionService:GetState(player)
	local weeklyRewardState = services.RewardService:GetWeeklyRewardState(player)
	local dailyOpsState = services.DailyOpsService:GetState(player)
	local identity = services.RoleService:GetIdentity(player)
	local activities = services.PersistenceService:GetActivityStats(player)

	return {
		gameTitle = config.GameTitle,
		tagline = config.Tagline,
		phaseOrder = config.getPhaseOrder(),
		gameFlow = {
			gameTitle = config.GameTitle,
			tagline = config.Tagline,
			homepagePlayButtonText = config.HomepagePlayButtonText,
			loadingTitle = config.LoadingTitle,
			loadingPromptText = config.LoadingPromptText,
			lobbyName = config.LobbyName,
			intermissionDurationSeconds = config.IntermissionDurationSeconds,
			loadingDurationSeconds = config.LoadingDurationSeconds,
			deploymentFlyInSeconds = config.DeploymentFlyInSeconds,
			homeToLobbyFadeSeconds = config.HomeToLobbyFadeSeconds,
		},
		missionConfig = MissionConfig,
		tokenEconomy = {
			startingDeployTokens = TokenEconomy.StartingDeployTokens,
			groupJoinBonus = TokenEconomy.GroupJoinBonus,
			dailyRewardAmount = TokenEconomy.DailyRewardAmount,
			deployTokenCost = TokenEconomy.DeployTokenCost,
			shopCategories = TokenEconomy.ShopCategories,
			robuxTokenPacks = TokenEconomy.RobuxTokenPacks,
			shopCatalog = TokenEconomy.ShopCatalog,
		},
		squadConfig = {
			minimumPlayers = SquadConfig.MinimumPlayers,
			maximumPlayers = SquadConfig.MaximumPlayers,
			difficultyPerExtraPlayer = SquadConfig.DifficultyPerExtraPlayer,
			lootPerExtraPlayer = SquadConfig.LootPerExtraPlayer,
		},
		remoteNames = {
			folderName = RemoteNames.FolderName,
			events = RemoteNames.Events,
			functions = RemoteNames.Functions,
		},
		progression = Contracts.makeProgressionProfile(equippedWeapon, equippedCosmetic, unlocks, weaponExperience, stats, skillTree, subscription, identity, activities),
		subscriptionState = subscription,
		seasonalEventState = services.ShopService:GetSeasonalEventState(),
		lobbyState = Contracts.makeLobbyState(
			services.FlowService:GetPhase(),
			services.SquadService:GetActiveSquadCount(),
			true,
			services.FlowService:IsDeployPadLocked(),
			services.FlowService:GetNextMissionPreview(),
			services.FlowService:GetMapVoteState()
		),
		tokenBalance = services.TokenService:GetBalance(player),
		squadSnapshot = squadSnapshot,
		squadDirectory = services.SquadService:GetPublicSquadDirectory(player),
		inviteablePlayers = services.SquadService:GetInviteablePlayers(player),
		dailyRewardState = dailyRewardState,
		weeklyRewardState = weeklyRewardState,
		dailyOpsState = dailyOpsState,
		shopCatalog = services.ShopService:GetCatalog(),
		persistenceState = services.PersistenceService:GetPersistenceState(),
	}
end

function ServerSystems.start()
	if started then
		return controller
	end

	started = true

	local context = {
		GameFlowConfig = GameFlowConfig,
		RemoteNames = RemoteNames,
		TokenEconomy = TokenEconomy,
		SquadConfig = SquadConfig,
		Contracts = Contracts,
		Signal = Signal,
		MissionConfig = MissionConfig,
		GamePassConfig = GamePassConfig,
		DailyOpsConfig = DailyOpsConfig,
		SkillTreeConfig = SkillTreeConfig,
		SubscriptionConfig = SubscriptionConfig,
	}

	local remotes = RemoteHub.new(context)
	remotes:Start()
	context.Remotes = remotes

	local persistenceService = PersistenceService.new(context)
	context.PersistenceService = persistenceService

	local gamePassService = GamePassService.new(context)
	context.GamePassService = gamePassService

	local roleService = RoleService.new(context)
	context.RoleService = roleService

	local skillTreeService = SkillTreeService.new(context)
	context.SkillTreeService = skillTreeService

	local subscriptionService = SubscriptionService.new(context)
	context.SubscriptionService = subscriptionService

	local tokenService = TokenService.new(context)
	context.TokenService = tokenService

	local antiExploitService = AntiExploitService.new(context)
	context.AntiExploitService = antiExploitService

	local squadService = SquadService.new(context)
	context.SquadService = squadService

	local leaderboardService = LeaderboardService.new(context)
	context.LeaderboardService = leaderboardService

	local leaderstatsService = LeaderstatsService.new(context)
	context.LeaderstatsService = leaderstatsService

	local rewardService = RewardService.new(context)
	context.RewardService = rewardService

	local dailyOpsService = DailyOpsService.new(context)
	context.DailyOpsService = dailyOpsService

	local inventoryService = InventoryService.new(context)
	context.InventoryService = inventoryService
	skillTreeService:SetInventoryService(inventoryService)
	gamePassService:SetInventoryService(inventoryService)
	gamePassService:SetSubscriptionService(subscriptionService)

	local shopService = ShopService.new(context)
	context.ShopService = shopService

	local scalingService = ScalingService.new(context)
	context.ScalingService = scalingService

	local flowService = FlowService.new(context)
	context.FlowService = flowService

	local activityService = ActivityService.new(context)
	context.ActivityService = activityService

	local duelService = DuelService.new(context)
	context.DuelService = duelService

	local missionService = MissionService.new(context)
	context.MissionService = missionService

	local instanceDeploymentService = InstanceDeploymentService.new(context)
	context.InstanceDeploymentService = instanceDeploymentService
	flowService:SetInstanceDeploymentService(instanceDeploymentService)
	missionService:SetInstanceDeploymentService(instanceDeploymentService)

	local adminService = AdminService.new(context)
	context.AdminService = adminService

	local nameplateService = NameplateService.new(context)
	context.NameplateService = nameplateService

	persistenceService:Start()
	gamePassService:Start()
	roleService:Start()
	skillTreeService:Start()
	subscriptionService:Start()
	subscriptionService.StateChanged:Connect(function(player)
		if player and player.Parent then
			gamePassService:RefreshDerivedState(player)
			roleService:Apply(player)
		end
	end)
	tokenService:Start()
	antiExploitService:Start()
	squadService:Start()
	leaderboardService:Start()
	leaderstatsService:Start()
	rewardService:Start()
	dailyOpsService:Start()
	inventoryService:Start()
	shopService:Start()
	scalingService:Start()
	flowService:Start()
	activityService:Start()
	duelService:Start()
	missionService:Start()
	instanceDeploymentService:Start()
	adminService:Start()
	nameplateService:Start()
	task.defer(function()
		for _, delaySeconds in ipairs({ 1, 3, 6 }) do
			task.wait(delaySeconds)
			flowService:ForceLobbySpawnSync()
		end
	end)

	local function guardRequest(player, actionKey, limit, windowSeconds)
		return antiExploitService:AllowRequest(player, actionKey, limit, windowSeconds)
	end

	local function makeDeployStatus(code)
		if code == "insufficient_tokens" then
			return "Need more deploy tokens to start."
		elseif code == "busy" then
			return "Squad launch already in progress."
		elseif code == "mission_unavailable" then
			return "Mission staging is offline right now."
		elseif code == "missing_squad" then
			return "No active squad found."
		elseif code == "rate_limited" then
			return "Deploy request is cooling down."
		end
		return ("Unable to deploy right now. [%s]"):format(tostring(code))
	end

	remotes:SetFunctionHandler(RemoteNames.Functions.GetBootstrapData, function(player)
		return buildBootstrapData(player, context, GameFlowConfig)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.GetDailyRewardState, function(player)
		return rewardService:GetDailyRewardState(player)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.GetDailyOpsState, function(player)
		return dailyOpsService:GetState(player)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.GetSubscriptionState, function(player)
		return subscriptionService:RefreshState(player)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.GetWeeklyRewardState, function(player)
		return rewardService:GetWeeklyRewardState(player)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.RefreshEntitlements, function(player)
		gamePassService:Refresh(player)
		if subscriptionService then
			subscriptionService:RefreshState(player)
		end
		roleService:Apply(player)
		return inventoryService:BuildProgressionPayload(player)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.ClaimDailyReward, function(player)
		if not guardRequest(player, "ClaimDailyReward", 3, 5) then
			return false, "rate_limited"
		end
		return rewardService:ClaimDailyReward(player)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.ClaimDailyOpsReward, function(player, taskId)
		if not guardRequest(player, "ClaimDailyOpsReward", 4, 5) then
			return false, "rate_limited"
		end
		return dailyOpsService:ClaimReward(player, taskId)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.ClaimWeeklyRewardCrate, function(player)
		if not guardRequest(player, "ClaimWeeklyRewardCrate", 2, 8) then
			return false, "rate_limited"
		end
		return rewardService:ClaimWeeklyRewardCrate(player)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.GetSquadDirectory, function(player)
		return squadService:GetPublicSquadDirectory(player)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.GetInviteablePlayers, function(player)
		return squadService:GetInviteablePlayers(player)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.CreateOrJoinSquad, function(player, squadId)
		if not guardRequest(player, "CreateOrJoinSquad", 4, 3) then
			return false, "rate_limited"
		end
		return squadService:CreateOrJoinSquad(player, squadId)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.SendSquadInvite, function(player, targetUserId)
		if not guardRequest(player, "SendSquadInvite", 4, 6) then
			return false, "rate_limited"
		end
		return squadService:SendInvite(player, targetUserId)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.RespondToSquadInvite, function(player, fromSquadId, acceptInvite)
		if not guardRequest(player, "RespondToSquadInvite", 4, 6) then
			return false, "rate_limited"
		end
		return squadService:RespondToInvite(player, fromSquadId, acceptInvite)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.SetSquadPrivacy, function(player, isPrivate)
		if not guardRequest(player, "SetSquadPrivacy", 4, 4) then
			return false, "rate_limited"
		end
		return squadService:SetPrivacyForLeader(player, isPrivate)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.LeaveSquad, function(player)
		if not guardRequest(player, "LeaveSquad", 4, 4) then
			return false, "rate_limited"
		end
		return squadService:LeaveSquad(player)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.RequestDeploy, function(player)
		if not guardRequest(player, "RequestDeploy", 2, 2.5) then
			return false, "rate_limited"
		end
		return flowService:RequestDeployment(player)
	end)
	local deployRequestedEvent = remotes:GetEvent(RemoteNames.Events.DeployRequested)
	if deployRequestedEvent then
		deployRequestedEvent.OnServerEvent:Connect(function(player)
			if not player or player.Parent ~= game:GetService("Players") then
				return
			end
			if not guardRequest(player, "RequestDeployEvent", 2, 2.5) then
				remotes:FireEventFor(player, RemoteNames.Events.DeployStateChanged, {
					userId = player.UserId,
					stage = "Lobby",
					status = "Deploy request is cooling down.",
				})
				return
			end
			local success, code = flowService:RequestDeployment(player)
			if not success then
				remotes:FireEventFor(player, RemoteNames.Events.DeployStateChanged, {
					userId = player.UserId,
					stage = "Lobby",
					status = makeDeployStatus(code),
				})
			end
		end)
	end
	remotes:SetFunctionHandler(RemoteNames.Functions.RequestActivityTransit, function(player, activityKey)
		if not guardRequest(player, "RequestActivityTransit", 4, 1.5) then
			return false, "rate_limited"
		end
		return activityService:RequestTransit(player, activityKey)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.LeaveMission, function(player)
		if not guardRequest(player, "LeaveMission", 2, 3) then
			return false, "rate_limited"
		end
		if player:GetAttribute("InMission") ~= true then
			return false, "not_in_mission"
		end
		return missionService:AbortMissionForPlayer(player, "Returning to bunker.")
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.RequestMapVote, function(player, optionId)
		if not guardRequest(player, "RequestMapVote", 5, 2) then
			return false, "rate_limited"
		end
		return flowService:RequestMapVote(player, optionId)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.RequestDuel, function(player, action)
		if not guardRequest(player, "RequestDuel", 4, 3) then
			return false, "rate_limited"
		end
		return duelService:RequestDuel(player, action)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.GetShopCatalog, function()
		return shopService:GetCatalog()
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.PurchaseShopItem, function(player, request)
		if not guardRequest(player, "PurchaseShopItem", 5, 4) then
			return false, "rate_limited"
		end
		if not antiExploitService:ValidateShopRequest(player, request) then
			return false, "invalid_request"
		end
		return shopService:Purchase(player, request)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.EquipLoadoutItem, function(player, request)
		if not guardRequest(player, "EquipLoadoutItem", 8, 4) then
			return false, "rate_limited"
		end
		if not antiExploitService:ValidateShopRequest(player, request) then
			return false, "invalid_request"
		end
		return shopService:EquipItem(player, request)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.SpendSkillPoint, function(player, skillId)
		if not guardRequest(player, "SpendSkillPoint", 8, 4) then
			return false, "rate_limited"
		end
		return skillTreeService:SpendSkillPoint(player, skillId)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.RespecSkillTree, function(player)
		if not guardRequest(player, "RespecSkillTree", 2, 10) then
			return false, "rate_limited"
		end
		return skillTreeService:Respec(player)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.AdminCommand, function(player, commandId)
		if not guardRequest(player, "AdminCommand", 6, 3) then
			return false, "rate_limited"
		end
		return adminService:Execute(player, commandId)
	end)

	controller = {
		Remotes = remotes,
		TokenService = tokenService,
		AntiExploitService = antiExploitService,
		PersistenceService = persistenceService,
		GamePassService = gamePassService,
		RoleService = roleService,
		SkillTreeService = skillTreeService,
		SubscriptionService = subscriptionService,
		SquadService = squadService,
		LeaderboardService = leaderboardService,
		LeaderstatsService = leaderstatsService,
		RewardService = rewardService,
		DailyOpsService = dailyOpsService,
		InventoryService = inventoryService,
		ShopService = shopService,
		ScalingService = scalingService,
		FlowService = flowService,
		ActivityService = activityService,
		DuelService = duelService,
		MissionService = missionService,
		InstanceDeploymentService = instanceDeploymentService,
		AdminService = adminService,
		NameplateService = nameplateService,
		ConfigureGroupRewards = function(predicate)
			rewardService:SetGroupEligibilityPredicate(predicate)
		end,
		ConfigureRobuxProducts = function(productMap)
			rewardService:SetRobuxProductMap(productMap)
		end,
	}

	return controller
end

return ServerSystems
