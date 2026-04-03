local RemoteNames = {
	FolderName = "Remotes",
	Events = {
		FlowChanged = "FlowChanged",
		LobbyStateChanged = "LobbyStateChanged",
		TokenBalanceChanged = "TokenBalanceChanged",
		SquadUpdated = "SquadUpdated",
		DeployRequested = "DeployRequested",
		DeployStateChanged = "DeployStateChanged",
		CombatFeedback = "CombatFeedback",
		Notification = "Notification",
		ShopStateChanged = "ShopStateChanged",
		ProgressionUpdated = "ProgressionUpdated",
		PersistenceStateChanged = "PersistenceStateChanged",
		SubscriptionStateChanged = "SubscriptionStateChanged",
	},
	Functions = {
		GetBootstrapData = "GetBootstrapData",
		GetDailyRewardState = "GetDailyRewardState",
		GetDailyOpsState = "GetDailyOpsState",
		GetSubscriptionState = "GetSubscriptionState",
		GetWeeklyRewardState = "GetWeeklyRewardState",
		RefreshEntitlements = "RefreshEntitlements",
		ClaimDailyReward = "ClaimDailyReward",
		ClaimDailyOpsReward = "ClaimDailyOpsReward",
		ClaimWeeklyRewardCrate = "ClaimWeeklyRewardCrate",
		GetSquadDirectory = "GetSquadDirectory",
		GetInviteablePlayers = "GetInviteablePlayers",
		CreateOrJoinSquad = "CreateOrJoinSquad",
		SendSquadInvite = "SendSquadInvite",
		RespondToSquadInvite = "RespondToSquadInvite",
		GiftTokensToPlayer = "GiftTokensToPlayer",
		GiftLoadoutItemToPlayer = "GiftLoadoutItemToPlayer",
		SetSquadPrivacy = "SetSquadPrivacy",
		LeaveSquad = "LeaveSquad",
		RequestMapVote = "RequestMapVote",
		RequestDuel = "RequestDuel",
		RequestDeploy = "RequestDeploy",
		RequestActivityTransit = "RequestActivityTransit",
		LeaveMission = "LeaveMission",
		GetShopCatalog = "GetShopCatalog",
		PurchaseShopItem = "PurchaseShopItem",
		EquipLoadoutItem = "EquipLoadoutItem",
		SpendSkillPoint = "SpendSkillPoint",
		RespecSkillTree = "RespecSkillTree",
		AdminCommand = "AdminCommand",
	},
}

function RemoteNames.getAllRemoteNames(): { string }
	local result = {}

	for _, name in pairs(RemoteNames.Events) do
		table.insert(result, name)
	end

	for _, name in pairs(RemoteNames.Functions) do
		table.insert(result, name)
	end

	return result
end

return table.freeze(RemoteNames)
