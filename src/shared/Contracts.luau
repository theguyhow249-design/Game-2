export type FlowPhase = "Homepage" | "Loading" | "Lobby" | "Intermission" | "Deployment" | "Mission"
export type TokenSource = "GroupJoin" | "DailyReward" | "RobuxPurchase" | "DeploySpend" | "MissionReward" | "SubscriptionReward" | "ActivityReward"
export type ShopCategory = "DeployTokens" | "Upgrades" | "Weapons" | "Cosmetics"

export type SubscriptionProfile = {
	subscriptionId: string,
	displayName: string,
	isActive: boolean,
	lastCheckedAt: number?,
	weeklyRewardClaimedAt: number?,
	weeklyRewardAvailable: boolean,
	tokenRewardMultiplier: number,
	experienceMultiplier: number,
	extractionHoldMultiplier: number,
	dailyBonusTokens: number,
	extraInventorySlots: number,
}

export type SkillTreeNodeState = {
	id: string,
	displayName: string,
	description: string,
	branch: string,
	tier: number,
	icon: string?,
	bonusLabel: string?,
	maxRank: number,
	rank: number,
	isMaxed: boolean,
	hasPrerequisite: boolean,
	prerequisiteId: string?,
	prerequisiteMet: boolean,
	available: boolean,
}

export type TokenBalancePayload = {
	userId: number,
	balance: number,
	delta: number,
	source: TokenSource?,
	reason: string?,
	updatedAt: number,
}

export type SquadMember = {
	userId: number,
	displayName: string?,
	isLeader: boolean,
	ready: boolean,
}

export type SquadSnapshot = {
	squadId: string,
	leaderUserId: number,
	members: { SquadMember },
	maxPlayers: number,
	createdAt: number,
}

export type LobbyState = {
	phase: FlowPhase,
	activeSquads: number,
	shopOpen: boolean,
	deployPadLocked: boolean,
	nextMissionPreview: {
		optionId: string,
		scenarioId: string,
		scenarioName: string,
		scenarioDescription: string,
		layoutId: string,
		layoutName: string,
		layoutDescription: string,
	}?,
	nextMissionVote: {
		sessionId: number,
		leadingOptionId: string?,
		options: {
			{
				optionId: string,
				scenarioName: string,
				layoutName: string,
				voteCount: number,
			}
		},
	}?,
}

export type DeployRequest = {
	squadId: string?,
	playerCount: number,
	intermissionEndsAt: number,
	destination: string?,
}

export type DailyRewardState = {
	lastClaimAt: number?,
	nextClaimAt: number,
	canClaim: boolean,
}

export type ShopPurchaseRequest = {
	itemId: string,
	category: ShopCategory,
	quantity: number?,
	currency: "Tokens" | "Robux",
}

export type ProgressionProfile = {
	equippedWeapon: string,
	equippedCosmetic: string?,
	identity: {
		title: string,
		badge: string?,
		isModerator: boolean?,
		isAdmin: boolean,
		isOwner: boolean,
	}?,
	unlocks: { [string]: boolean },
	weaponExperience: { [string]: number }?,
	stats: {
		missionsCompleted: number,
		zombiesDefeated: number,
	},
	skillTree: {
		level: number,
		experience: number,
		experienceIntoLevel: number,
		experienceForNextLevel: number,
		experienceRemaining: number?,
		progressPercent: number?,
		skillPoints: number,
		skills: { [string]: number },
		nodes: { SkillTreeNodeState }?,
	},
	subscription: SubscriptionProfile?,
	activities: {
		parkourBestMs: number,
		rangeBestScore: number,
		salvageBestMs: number,
		trainingBestScore: number,
		parkourClears: number,
		rangeRuns: number,
		salvageClears: number,
		trainingClears: number,
		parkourLevel: number,
		rangeLevel: number,
		salvageLevel: number,
		trainingLevel: number,
		secrets: { [string]: boolean }?,
		achievements: { [string]: boolean }?,
		rewards: { [string]: boolean }?,
	},
}

local Contracts = {}

function Contracts.makeTokenBalancePayload(
	userId: number,
	balance: number,
	delta: number,
	source: TokenSource?,
	reason: string?
): TokenBalancePayload
	return {
		userId = userId,
		balance = balance,
		delta = delta,
		source = source,
		reason = reason,
		updatedAt = os.time(),
	}
end

function Contracts.makeSquadMember(userId: number, displayName: string?, isLeader: boolean, ready: boolean): SquadMember
	return {
		userId = userId,
		displayName = displayName,
		isLeader = isLeader,
		ready = ready,
	}
end

function Contracts.makeSquadSnapshot(
	squadId: string,
	leaderUserId: number,
	members: { SquadMember },
	maxPlayers: number
): SquadSnapshot
	return {
		squadId = squadId,
		leaderUserId = leaderUserId,
		members = members,
		maxPlayers = maxPlayers,
		createdAt = os.time(),
	}
end

function Contracts.makeLobbyState(phase: FlowPhase, activeSquads: number, shopOpen: boolean, deployPadLocked: boolean, nextMissionPreview, nextMissionVote): LobbyState
	return {
		phase = phase,
		activeSquads = activeSquads,
		shopOpen = shopOpen,
		deployPadLocked = deployPadLocked,
		nextMissionPreview = nextMissionPreview,
		nextMissionVote = nextMissionVote,
	}
end

function Contracts.makeDeployRequest(
	squadId: string?,
	playerCount: number,
	intermissionEndsAt: number,
	destination: string?
): DeployRequest
	return {
		squadId = squadId,
		playerCount = playerCount,
		intermissionEndsAt = intermissionEndsAt,
		destination = destination,
	}
end

function Contracts.makeDailyRewardState(lastClaimAt: number?, nextClaimAt: number): DailyRewardState
	return {
		lastClaimAt = lastClaimAt,
		nextClaimAt = nextClaimAt,
		canClaim = os.time() >= nextClaimAt,
	}
end

function Contracts.makeShopPurchaseRequest(
	itemId: string,
	category: ShopCategory,
	quantity: number?,
	currency: "Tokens" | "Robux"
): ShopPurchaseRequest
	return {
		itemId = itemId,
		category = category,
		quantity = quantity,
		currency = currency,
	}
end

function Contracts.makeProgressionProfile(equippedWeapon: string, equippedCosmetic: string?, unlocks, weaponExperience, stats, skillTree, subscription, identity, activities): ProgressionProfile
	return {
		equippedWeapon = equippedWeapon,
		equippedCosmetic = equippedCosmetic,
		identity = identity,
		unlocks = unlocks or {},
		weaponExperience = weaponExperience or {},
		stats = {
			missionsCompleted = stats and stats.missionsCompleted or 0,
			zombiesDefeated = stats and stats.zombiesDefeated or 0,
		},
		skillTree = {
			level = skillTree and skillTree.level or 1,
			experience = skillTree and skillTree.experience or 0,
			experienceIntoLevel = skillTree and skillTree.experienceIntoLevel or 0,
			experienceForNextLevel = skillTree and skillTree.experienceForNextLevel or 100,
			experienceRemaining = skillTree and skillTree.experienceRemaining or 0,
			progressPercent = skillTree and skillTree.progressPercent or 0,
			skillPoints = skillTree and skillTree.skillPoints or 0,
			skills = skillTree and skillTree.skills or {},
			nodes = skillTree and skillTree.nodes or {},
		},
		subscription = subscription,
		activities = activities or {
			parkourBestMs = 0,
			rangeBestScore = 0,
			salvageBestMs = 0,
			trainingBestScore = 0,
			parkourClears = 0,
			rangeRuns = 0,
			salvageClears = 0,
			trainingClears = 0,
			parkourLevel = 0,
			rangeLevel = 0,
			salvageLevel = 0,
			trainingLevel = 0,
			secrets = {},
			achievements = {},
			rewards = {},
		},
	}
end

return table.freeze(Contracts)
