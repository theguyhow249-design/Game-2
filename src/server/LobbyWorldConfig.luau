local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameFlowConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameFlowConfig"))
local SquadConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SquadConfig"))
local TokenEconomy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TokenEconomy"))

local Config = {}

Config.RootName = GameFlowConfig.LobbyName
Config.Origin = Vector3.new(2000, 40, 2000)
Config.SpawnOffset = Vector3.new(0, 0, 0)
Config.MissionOffset = Vector3.new(0, 0, 640)
Config.AreaRadius = 56

Config.Areas = {
	Shop = {
		Offset = Vector3.new(0, 0, -58),
		Color = Color3.fromRGB(189, 122, 43),
		Accent = Color3.fromRGB(245, 215, 156),
		Title = "SHOP",
		Subtitle = "Deploy tokens, upgrades, weapons, cosmetics",
	},
	Inventory = {
		Offset = Vector3.new(58, 0, -28),
		Color = Color3.fromRGB(88, 128, 186),
		Accent = Color3.fromRGB(184, 212, 248),
		Title = "LOCKER",
		Subtitle = "Owned weapons, skins, and loadout review",
	},
	SkillTree = {
		Offset = Vector3.new(-58, 0, -28),
		Color = Color3.fromRGB(112, 126, 170),
		Accent = Color3.fromRGB(198, 208, 240),
		Title = "SKILLS",
		Subtitle = "Spend points and unlock branch upgrades",
	},
	Social = {
		Offset = Vector3.new(58, 0, 30),
		Color = Color3.fromRGB(52, 132, 114),
		Accent = Color3.fromRGB(173, 227, 214),
		Title = "SOCIAL",
		Subtitle = "Meet players and build squads",
	},
	Squad = {
		Offset = Vector3.new(-58, 0, 30),
		Color = Color3.fromRGB(68, 111, 158),
		Accent = Color3.fromRGB(171, 205, 237),
		Title = "SQUAD",
		Subtitle = "Form 1-4 player teams",
	},
	QuestBoard = {
		Offset = Vector3.new(0, 0, 54),
		Color = Color3.fromRGB(136, 164, 82),
		Accent = Color3.fromRGB(218, 238, 164),
		Title = "OPS",
		Subtitle = "Daily tasks, stipends, and weekly rewards",
	},
	Training = {
		Offset = Vector3.new(-124, 0, -78),
		Color = Color3.fromRGB(120, 98, 58),
		Accent = Color3.fromRGB(244, 212, 152),
		Title = "TRAIN",
		Subtitle = "Sprint lanes, target drills, and weapon warmup",
	},
	Parkour = {
		Offset = Vector3.new(-132, 0, 28),
		Color = Color3.fromRGB(94, 108, 150),
		Accent = Color3.fromRGB(206, 220, 255),
		Title = "PARKOUR",
		Subtitle = "Run rooftops, jump gaps, and warm up movement tech",
	},
	Duel = {
		Offset = Vector3.new(120, 0, -82),
		Color = Color3.fromRGB(124, 72, 72),
		Accent = Color3.fromRGB(244, 182, 182),
		Title = "DUEL",
		Subtitle = "Step into the spar ring and stage 1v1s",
	},
	TargetRange = {
		Offset = Vector3.new(132, 0, 26),
		Color = Color3.fromRGB(72, 104, 92),
		Accent = Color3.fromRGB(186, 238, 214),
		Title = "RANGE",
		Subtitle = "Line up shots, test recoil, and prep ranged loadouts",
	},
	Salvage = {
		Offset = Vector3.new(-18, 0, -122),
		Color = Color3.fromRGB(118, 92, 64),
		Accent = Color3.fromRGB(244, 214, 168),
		Title = "SALVAGE",
		Subtitle = "Sweep the lane, recover caches, and race the clock",
	},
	Deploy = {
		Offset = Vector3.new(0, 0, 102),
		Color = Color3.fromRGB(255, 94, 94),
		Accent = Color3.fromRGB(255, 214, 214),
		Title = "DEPLOY",
		Subtitle = "Stage the whole fireteam and launch from the HUD",
	},
}

Config.GameTitle = GameFlowConfig.GameTitle
Config.Tagline = GameFlowConfig.Tagline
Config.PlayButtonText = GameFlowConfig.HomepagePlayButtonText
Config.LoadingTitle = GameFlowConfig.LoadingTitle
Config.LoadingPromptText = GameFlowConfig.LoadingPromptText
Config.IntermissionDurationSeconds = GameFlowConfig.IntermissionDurationSeconds
Config.LoadingDurationSeconds = GameFlowConfig.LoadingDurationSeconds
Config.DeploymentFlyInSeconds = GameFlowConfig.DeploymentFlyInSeconds
Config.HomeToLobbyFadeSeconds = GameFlowConfig.HomeToLobbyFadeSeconds

Config.TokenSources = {
	GroupJoin = TokenEconomy.GroupJoinBonus,
	DailyReward = TokenEconomy.DailyRewardAmount,
	RobuxPurchase = TokenEconomy.RobuxTokenPacks.Rookie,
	DeploySpend = -TokenEconomy.DeployTokenCost,
}

Config.TokenCosts = {
	Deploy = TokenEconomy.DeployTokenCost,
}

Config.SquadSize = {
	Min = SquadConfig.MinimumPlayers,
	Max = SquadConfig.MaximumPlayers,
}

function Config.GetScaledLootMultiplier(playerCount: number): number
	return SquadConfig.getLootMultiplier(playerCount)
end

function Config.GetScaledDifficulty(playerCount: number): number
	return SquadConfig.getDifficultyMultiplier(playerCount)
end

return Config
