local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local GameFlowConfig = require(Shared:WaitForChild("GameFlowConfig"))
local RemoteNames = require(Shared:WaitForChild("RemoteNames"))
local SquadConfig = require(Shared:WaitForChild("SquadConfig"))
local TokenEconomy = require(Shared:WaitForChild("TokenEconomy"))

local Theme = {}

Theme.GameTitle = GameFlowConfig.GameTitle
Theme.GameSubtitle = GameFlowConfig.Tagline
Theme.LoadingPrompt = GameFlowConfig.LoadingPromptText
Theme.HomePlayButtonText = GameFlowConfig.HomepagePlayButtonText

Theme.SquadLimit = SquadConfig.MaximumPlayers
Theme.DefaultTokenBalance = TokenEconomy.StartingDeployTokens

Theme.RemoteNames = RemoteNames.getAllRemoteNames()

Theme.ShopTabs = {
	"Deploy Tokens",
	"Upgrades",
	"Weapons",
	"Cosmetics",
	"Skill Tree",
}

Theme.ShopTabToCategory = {
	["Deploy Tokens"] = TokenEconomy.ShopCategories.DeployTokens,
	Upgrades = TokenEconomy.ShopCategories.Upgrades,
	Weapons = TokenEconomy.ShopCategories.Weapons,
	Cosmetics = TokenEconomy.ShopCategories.Cosmetics,
}

Theme.ShopCategoryToTab = {
	[TokenEconomy.ShopCategories.DeployTokens] = "Deploy Tokens",
	[TokenEconomy.ShopCategories.Upgrades] = "Upgrades",
	[TokenEconomy.ShopCategories.Weapons] = "Weapons",
	[TokenEconomy.ShopCategories.Cosmetics] = "Cosmetics",
}

Theme.ShopCopy = {
	["Deploy Tokens"] = "Use deploy tokens for drops, daily claims, group rewards, and premium packs.",
	Upgrades = "Tune armor, stamina, and field utility before harder runs.",
	Weapons = "Arm sidearms, control tools, and bunker-ready hardware.",
	Cosmetics = "Apply bunker colors, field tags, and hub-facing flex gear.",
	["Skill Tree"] = "Spend skill points to specialize into survival, combat, or logistics.",
}

Theme.SkillTreeBranches = {
	Survivor = {
		DisplayName = "Survivor",
		Icon = "VIT",
		ShortLabel = "Survival",
		Summary = "Stay upright, revive faster, and stretch every support tool further.",
		Color = Color3.fromRGB(110, 179, 92),
		Panel = Color3.fromRGB(58, 82, 68),
	},
	Combat = {
		DisplayName = "Combat",
		Icon = "DMG",
		ShortLabel = "Combat",
		Summary = "Increase weapon pressure, dash more often, and punish bosses harder.",
		Color = Color3.fromRGB(214, 124, 92),
		Panel = Color3.fromRGB(86, 62, 52),
	},
	Logistics = {
		DisplayName = "Logistics",
		Icon = "TOK",
		ShortLabel = "Logistics",
		Summary = "Scavenge cleaner, extract faster, and pull more value from every run.",
		Color = Color3.fromRGB(92, 160, 214),
		Panel = Color3.fromRGB(56, 72, 92),
	},
}

Theme.SkillTreeBranchOrder = {
	"Survivor",
	"Combat",
	"Logistics",
}

Theme.Colors = {
	Background = Color3.fromRGB(16, 20, 26),
	Backdrop = Color3.fromRGB(34, 42, 52),
	Panel = Color3.fromRGB(48, 58, 70),
	PanelAlt = Color3.fromRGB(60, 72, 84),
	Stroke = Color3.fromRGB(118, 132, 144),
	Accent = Color3.fromRGB(110, 179, 92),
	AccentSoft = Color3.fromRGB(173, 216, 137),
	AccentWarm = Color3.fromRGB(232, 173, 78),
	BunkerAccent = Color3.fromRGB(126, 146, 168),
	Text = Color3.fromRGB(245, 247, 248),
	Muted = Color3.fromRGB(212, 220, 226),
	Shadow = Color3.fromRGB(0, 0, 0),
}

Theme.Fonts = {
	Title = Enum.Font.GothamBlack,
	Heading = Enum.Font.GothamSemibold,
	Body = Enum.Font.Gotham,
}

Theme.StatusCopy = {
	Home = "Enter bunker command.",
	Loading = "Synchronizing bunker systems.",
	Lobby = GameFlowConfig.LobbyName .. " online.",
	Deploying = "Airlock sequence armed.",
}

Theme.LobbyBlurb = "Track squads, meet survivors, and lock in a fireteam before the next breach."

Theme.TokenLabels = {
	Deploy = "Deploy Tokens",
	Group = "Group Reward",
	Daily = "Daily Reward",
	Robux = "Robux Pack",
}

return Theme
