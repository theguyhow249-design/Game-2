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
local SquadService = require(servicesFolder:WaitForChild("SquadService"))
local RewardService = require(servicesFolder:WaitForChild("RewardService"))
local DailyOpsService = require(servicesFolder:WaitForChild("DailyOpsService"))
local LeaderboardService = require(servicesFolder:WaitForChild("LeaderboardService"))
local LeaderstatsService = require(servicesFolder:WaitForChild("LeaderstatsService"))
local InventoryService = require(servicesFolder:WaitForChild("InventoryService"))
local ShopService = require(servicesFolder:WaitForChild("ShopService"))
local ScalingService = require(servicesFolder:WaitForChild("ScalingService"))
local FlowService = require(servicesFolder:WaitForChild("FlowService"))
local MissionService = require(servicesFolder:WaitForChild("MissionService"))
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
		progression = Contracts.makeProgressionProfile(equippedWeapon, equippedCosmetic, unlocks, weaponExperience, stats, skillTree, subscription, identity),
		subscriptionState = subscription,
		seasonalEventState = services.ShopService:GetSeasonalEventState(),
		lobbyState = Contracts.makeLobbyState(
			services.FlowService:GetPhase(),
			services.SquadService:GetActiveSquadCount(),
			true,
			services.FlowService:IsDeployPadLocked()
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

	local shopService = ShopService.new(context)
	context.ShopService = shopService

	local scalingService = ScalingService.new(context)
	context.ScalingService = scalingService

	local flowService = FlowService.new(context)
	context.FlowService = flowService

	local missionService = MissionService.new(context)
	context.MissionService = missionService

	local adminService = AdminService.new(context)
	context.AdminService = adminService

	local nameplateService = NameplateService.new(context)
	context.NameplateService = nameplateService

	persistenceService:Start()
	gamePassService:Start()
	roleService:Start()
	skillTreeService:Start()
	subscriptionService:Start()
	tokenService:Start()
	squadService:Start()
	leaderboardService:Start()
	leaderstatsService:Start()
	rewardService:Start()
	dailyOpsService:Start()
	inventoryService:Start()
	shopService:Start()
	scalingService:Start()
	flowService:Start()
	missionService:Start()
	adminService:Start()
	nameplateService:Start()

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
		return rewardService:ClaimDailyReward(player)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.ClaimDailyOpsReward, function(player, taskId)
		return dailyOpsService:ClaimReward(player, taskId)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.ClaimWeeklyRewardCrate, function(player)
		return rewardService:ClaimWeeklyRewardCrate(player)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.GetSquadDirectory, function(player)
		return squadService:GetPublicSquadDirectory(player)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.GetInviteablePlayers, function(player)
		return squadService:GetInviteablePlayers(player)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.CreateOrJoinSquad, function(player, squadId)
		return squadService:CreateOrJoinSquad(player, squadId)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.SendSquadInvite, function(player, targetUserId)
		return squadService:SendInvite(player, targetUserId)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.RespondToSquadInvite, function(player, fromSquadId, acceptInvite)
		return squadService:RespondToInvite(player, fromSquadId, acceptInvite)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.SetSquadPrivacy, function(player, isPrivate)
		return squadService:SetPrivacyForLeader(player, isPrivate)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.LeaveSquad, function(player)
		return squadService:LeaveSquad(player)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.RequestDeploy, function(player)
		return flowService:RequestDeployment(player)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.GetShopCatalog, function()
		return shopService:GetCatalog()
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.PurchaseShopItem, function(player, request)
		return shopService:Purchase(player, request)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.EquipLoadoutItem, function(player, request)
		return shopService:EquipItem(player, request)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.SpendSkillPoint, function(player, skillId)
		return skillTreeService:SpendSkillPoint(player, skillId)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.RespecSkillTree, function(player)
		return skillTreeService:Respec(player)
	end)
	remotes:SetFunctionHandler(RemoteNames.Functions.AdminCommand, function(player, commandId)
		return adminService:Execute(player, commandId)
	end)

	controller = {
		Remotes = remotes,
		TokenService = tokenService,
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
		MissionService = missionService,
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
