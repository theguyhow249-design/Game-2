local SubscriptionConfig = require(script.Parent.SubscriptionConfig)

export type TokenSource = "GroupJoin" | "DailyReward" | "RobuxPurchase" | "DeploySpend" | "MissionReward" | "SubscriptionReward" | "ActivityReward"
export type ShopCategory = "DeployTokens" | "Upgrades" | "Weapons" | "Cosmetics"

local TokenEconomy = {
	StartingDeployTokens = 5,
	GroupJoinBonus = 15,
	DailyRewardAmount = 10,
	DeployTokenCost = 1,
	ShopCategories = {
		DeployTokens = "DeployTokens",
		Upgrades = "Upgrades",
		Weapons = "Weapons",
		Cosmetics = "Cosmetics",
	},
	RobuxTokenPacks = {
		Rookie = 50,
		Survivor = 250,
		Veteran = 750,
	},
	SeasonalEvents = {
		{
			Id = "spring_surge",
			DisplayName = "Spring Surge",
			Description = "Fresh bunker stock rotates in and spring operations increase gear recovery rates.",
			StartMonth = 3,
			StartDay = 1,
			EndMonth = 5,
			EndDay = 31,
			GlobalDropBonus = 1.5,
			FeaturedDropBonus = 4,
		},
		{
			Id = "harvest_hunt",
			DisplayName = "Harvest Hunt",
			Description = "Autumn breach runs favor brutal salvage pulls and heavy melee drops.",
			StartMonth = 9,
			StartDay = 15,
			EndMonth = 11,
			EndDay = 15,
			GlobalDropBonus = 1,
			FeaturedDropBonus = 5,
		},
		{
			Id = "winter_siege",
			DisplayName = "Winter Siege",
			Description = "Frozen bunker sorties boost elite weapon recovery and winter event drops.",
			StartMonth = 12,
			StartDay = 1,
			EndMonth = 1,
			EndDay = 20,
			GlobalDropBonus = 2,
			FeaturedDropBonus = 6,
		},
	},
	ShopCatalog = {
		DeployTokens = {
			{
				Id = "deploy_pack_small",
				DisplayName = "Small Token Pack",
				Description = "A small grant of deploy tokens.",
				CostType = "Robux",
				Rarity = "Supporter",
				TokenAmount = 50,
			},
			{
				Id = "pass_skill_tree_double",
				DisplayName = "2x Skill Tree Pass",
				Description = "Doubles bunker skill tree XP gains from kills, waves, missions, and other XP rewards.",
				CostType = "Robux",
				Rarity = "Supporter",
				GamePassId = 1767537515,
				GamePassKey = "skill_tree_double",
			},
			{
				Id = "pass_vip_operation",
				DisplayName = "VIP Operation",
				Description = "Doubles token rewards across daily claims, mission payouts, and other bunker reward flows.",
				CostType = "Robux",
				Rarity = "Supporter",
				GamePassId = 1765913819,
				GamePassKey = "vip_operation",
			},
			{
				Id = "pass_starter_loadout",
				DisplayName = "Starter Loadout",
				Description = "Instantly grants an upgraded starter weapon set and bunker cosmetics for new operators.",
				CostType = "Robux",
				Rarity = "Supporter",
				GamePassId = 1767991467,
				GamePassKey = "starter_loadout",
			},
			{
				Id = "pass_double_drop_chance",
				DisplayName = "Double Drop Chance",
				Description = "Doubles mission loot roll chances for weapon and cosmetic drops, including seasonal event drops.",
				CostType = "Robux",
				Rarity = "Supporter",
				GamePassId = 1765047588,
				GamePassKey = "double_drop_chance",
			},
			{
				Id = "subscription_bunker_supporter",
				DisplayName = SubscriptionConfig.DisplayName,
				Description = "Boosts loot and token gains, speeds progression, and unlocks weekly bunker support rewards.",
				CostType = "Robux",
				Rarity = "Supporter",
				SubscriptionId = SubscriptionConfig.SubscriptionId,
			},
		},
		Upgrades = {
			{
				Id = "upgrade_max_health",
				DisplayName = "Max Health I",
				Description = "Raise player survivability.",
				CostType = "Tokens",
				Rarity = "Common",
				Cost = 15,
			},
		},
		Weapons = {
			{
				Id = "weapon_crowbar",
				DisplayName = "Crowbar",
				Description = "Longer melee reach for tougher bunker runs.",
				CostType = "Tokens",
				Rarity = "Common",
				Cost = 18,
				DropChance = 18,
			},
			{
				Id = "weapon_salvage_machete",
				DisplayName = "Salvage Machete",
				Description = "Fast recovery melee blade for aggressive close-range runs.",
				CostType = "Tokens",
				Rarity = "Uncommon",
				Cost = 22,
				DropChance = 12,
			},
			{
				Id = "weapon_service_pistol",
				DisplayName = "Service Pistol",
				Description = "Fast sidearm with limited stopping power.",
				CostType = "Tokens",
				Rarity = "Common",
				Cost = 26,
				DropChance = 14,
			},
			{
				Id = "weapon_breacher_pistol",
				DisplayName = "Breacher Pistol",
				Description = "Harder-hitting sidearm with a tighter magazine and stronger recoil.",
				CostType = "Tokens",
				Rarity = "Rare",
				Cost = 32,
				DropChance = 7,
			},
			{
				Id = "weapon_patrol_carbine",
				DisplayName = "Patrol Carbine",
				Description = "Balanced bunker-issued rifle with stronger sustained ranged pressure.",
				CostType = "Tokens",
				Rarity = "Uncommon",
				Cost = 34,
				DropChance = 10,
			},
			{
				Id = "weapon_marksman_carbine",
				DisplayName = "Marksman Carbine",
				Description = "Precision-focused carbine for steadier mid-range kills.",
				CostType = "Tokens",
				Rarity = "Epic",
				Cost = 46,
				DropChance = 3,
			},
			{
				Id = "weapon_street_smg",
				DisplayName = "Street SMG",
				Description = "Fast-firing close-quarters weapon for crowd control and panic clears.",
				CostType = "Tokens",
				Rarity = "Rare",
				Cost = 42,
				DropChance = 6,
			},
			{
				Id = "weapon_fire_axe",
				DisplayName = "Fire Axe",
				Description = "Slow but heavy zombie-clearing melee weapon.",
				CostType = "Tokens",
				Rarity = "Rare",
				Cost = 30,
				DropChance = 8,
			},
			{
				Id = "weapon_trench_shotgun",
				DisplayName = "Trench Shotgun",
				Description = "Close-range blast weapon for bunker breach defense.",
				CostType = "Tokens",
				Rarity = "Epic",
				Cost = 38,
				DropChance = 4,
			},
			{
				Id = "weapon_vernal_carbine",
				DisplayName = "Vernal Carbine",
				Description = "Spring event rifle with sharp recoil recovery and stronger mid-range stopping power.",
				CostType = "Tokens",
				Rarity = "Epic",
				Cost = 0,
				DropChance = 5,
				DropOnly = true,
				SeasonalEvent = "spring_surge",
			},
			{
				Id = "weapon_harvest_reaper",
				DisplayName = "Harvest Reaper",
				Description = "Autumn event axe tuned for brutal heavy swings and stronger infected clears.",
				CostType = "Tokens",
				Rarity = "Epic",
				Cost = 0,
				DropChance = 5,
				DropOnly = true,
				SeasonalEvent = "harvest_hunt",
			},
			{
				Id = "weapon_frost_lancer",
				DisplayName = "Frost Lancer",
				Description = "Winter event carbine built for accurate siege pressure and cold-weather response teams.",
				CostType = "Tokens",
				Rarity = "Epic",
				Cost = 0,
				DropChance = 5,
				DropOnly = true,
				SeasonalEvent = "winter_siege",
			},
		},
		Cosmetics = {
			{
				Id = "cosmetic_field_cap",
				DisplayName = "Field Cap",
				Description = "Basic fieldwear cosmetic for survivors who want a lighter locker look.",
				CostType = "Tokens",
				Rarity = "Common",
				Cost = 8,
				DropChance = 22,
			},
			{
				Id = "cosmetic_neon_outline",
				DisplayName = "Galaxy Skin",
				Description = "Animated galaxy weapon finish with shifting cosmic color bands.",
				CostType = "Tokens",
				Rarity = "Rare",
				Cost = 14,
				DropChance = 8,
			},
			{
				Id = "cosmetic_bunker_glow",
				DisplayName = "Bunker Steel Skin",
				Description = "Cold steel-blue weapon finish tuned for bunker-issued hardware.",
				CostType = "Tokens",
				Rarity = "Uncommon",
				Cost = 18,
				DropChance = 12,
			},
			{
				Id = "cosmetic_ember_trace",
				DisplayName = "Ember Skin",
				Description = "Heated ember-metal weapon skin with a live furnace color shift.",
				CostType = "Tokens",
				Rarity = "Epic",
				Cost = 20,
				DropChance = 5,
			},
			{
				Id = "cosmetic_medic_aura",
				DisplayName = "Medic Skin",
				Description = "Clean rescue-green weapon finish for support-focused loadouts.",
				CostType = "Tokens",
				Rarity = "Uncommon",
				Cost = 16,
				DropChance = 12,
			},
			{
				Id = "cosmetic_vernal_glow",
				DisplayName = "Vernal Skin",
				Description = "Seasonal spring weapon skin with bright fresh bunker tones.",
				CostType = "Tokens",
				Rarity = "Rare",
				Cost = 0,
				DropChance = 9,
				DropOnly = true,
				SeasonalEvent = "spring_surge",
			},
		},
	},
}

local seasonalEventOverrideId = nil

local function isMonthDayOnOrAfter(month, day, targetMonth, targetDay)
	if month ~= targetMonth then
		return month > targetMonth
	end
	return day >= targetDay
end

local function isMonthDayOnOrBefore(month, day, targetMonth, targetDay)
	if month ~= targetMonth then
		return month < targetMonth
	end
	return day <= targetDay
end

local function isEventActive(event, month, day)
	if event.StartMonth < event.EndMonth or (event.StartMonth == event.EndMonth and event.StartDay <= event.EndDay) then
		return isMonthDayOnOrAfter(month, day, event.StartMonth, event.StartDay)
			and isMonthDayOnOrBefore(month, day, event.EndMonth, event.EndDay)
	end
	return isMonthDayOnOrAfter(month, day, event.StartMonth, event.StartDay)
		or isMonthDayOnOrBefore(month, day, event.EndMonth, event.EndDay)
end

function TokenEconomy.isValidSource(source: string): boolean
	for _, value in ipairs({ "GroupJoin", "DailyReward", "RobuxPurchase", "DeploySpend", "MissionReward", "SubscriptionReward" }) do
		if value == source then
			return true
		end
	end

	return false
end

function TokenEconomy.getSourceAmount(source: TokenSource): number
	if source == "GroupJoin" then
		return TokenEconomy.GroupJoinBonus
	elseif source == "DailyReward" then
		return TokenEconomy.DailyRewardAmount
	elseif source == "RobuxPurchase" then
		return TokenEconomy.RobuxTokenPacks.Rookie
	elseif source == "DeploySpend" then
		return -TokenEconomy.DeployTokenCost
	elseif source == "SubscriptionReward" then
		return 0
	end

	return 5
end

function TokenEconomy.getPackAmount(packName: string): number?
	return TokenEconomy.RobuxTokenPacks[packName]
end

function TokenEconomy.getCategoryItems(category: ShopCategory)
	return TokenEconomy.ShopCatalog[category] or {}
end

function TokenEconomy.getSeasonalEventById(eventId)
	local normalizedId = tostring(eventId or "")
	for _, event in ipairs(TokenEconomy.SeasonalEvents) do
		if event.Id == normalizedId then
			return event
		end
	end
	return nil
end

function TokenEconomy.setSeasonalEventOverride(eventId)
	if eventId == nil or eventId == "" or eventId == "auto" then
		seasonalEventOverrideId = nil
		return true
	end
	if eventId == "none" then
		seasonalEventOverrideId = "none"
		return true
	end
	if TokenEconomy.getSeasonalEventById(eventId) then
		seasonalEventOverrideId = tostring(eventId)
		return true
	end
	return false
end

function TokenEconomy.clearSeasonalEventOverride()
	seasonalEventOverrideId = nil
end

function TokenEconomy.getSeasonalEventOverrideId()
	return seasonalEventOverrideId
end

function TokenEconomy.getActiveSeasonalEvent(nowTable)
	if seasonalEventOverrideId == "none" then
		return nil
	end
	if seasonalEventOverrideId then
		return TokenEconomy.getSeasonalEventById(seasonalEventOverrideId)
	end
	local current = nowTable or os.date("*t")
	local month = tonumber(current.month) or 1
	local day = tonumber(current.day) or 1
	for _, event in ipairs(TokenEconomy.SeasonalEvents) do
		if isEventActive(event, month, day) then
			return event
		end
	end
	return nil
end

function TokenEconomy.getDropChanceForItem(item, activeEvent, sourceMultiplier)
	if type(item) ~= "table" then
		return 0
	end

	local eventState = activeEvent
	if eventState == nil then
		eventState = TokenEconomy.getActiveSeasonalEvent()
	end

	if item.SeasonalEvent and (not eventState or eventState.Id ~= item.SeasonalEvent) then
		return 0
	end

	local chance = tonumber(item.DropChance) or 0
	if chance <= 0 then
		return 0
	end

	if eventState then
		chance += tonumber(eventState.GlobalDropBonus) or 0
		if item.SeasonalEvent and item.SeasonalEvent == eventState.Id then
			chance += tonumber(eventState.FeaturedDropBonus) or 0
		end
	end

	chance *= tonumber(sourceMultiplier) or 1
	return math.clamp(chance, 0, 95)
end

function TokenEconomy.getDroppableItems()
	local results = {}
	for _, categoryName in ipairs({ TokenEconomy.ShopCategories.Weapons, TokenEconomy.ShopCategories.Cosmetics }) do
		for _, item in ipairs(TokenEconomy.getCategoryItems(categoryName)) do
			if tonumber(item.DropChance) and tonumber(item.DropChance) > 0 then
				table.insert(results, {
					category = categoryName,
					item = item,
				})
			end
		end
	end
	return results
end

return table.freeze(TokenEconomy)
