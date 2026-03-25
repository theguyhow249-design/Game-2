local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameFlowConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameFlowConfig"))
local SquadConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SquadConfig"))
local TokenEconomy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TokenEconomy"))

local Config = {}

Config.RootName = GameFlowConfig.LobbyName
Config.Origin = Vector3.new(2000, 40, 2000)
Config.SpawnOffset = Vector3.new(0, 0, 0)
Config.MissionOffset = Vector3.new(0, 0, 420)
Config.AreaRadius = 40

Config.Areas = {
	Shop = {
		Offset = Vector3.new(0, 0, -40),
		Color = Color3.fromRGB(189, 122, 43),
		Accent = Color3.fromRGB(245, 215, 156),
		Title = "SHOP",
		Subtitle = "Deploy tokens, upgrades, weapons, cosmetics",
	},
	Social = {
		Offset = Vector3.new(40, 0, 0),
		Color = Color3.fromRGB(52, 132, 114),
		Accent = Color3.fromRGB(173, 227, 214),
		Title = "SOCIAL",
		Subtitle = "Meet players and build squads",
	},
	Squad = {
		Offset = Vector3.new(-40, 0, 0),
		Color = Color3.fromRGB(68, 111, 158),
		Accent = Color3.fromRGB(171, 205, 237),
		Title = "SQUAD",
		Subtitle = "Form 1-4 player teams",
	},
	Deploy = {
		Offset = Vector3.new(0, 0, 44),
		Color = Color3.fromRGB(255, 94, 94),
		Accent = Color3.fromRGB(255, 214, 214),
		Title = "DEPLOY",
		Subtitle = "Use the HUD deploy button to begin intermission",
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
