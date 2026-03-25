local SubscriptionConfig = {
	SubscriptionId = "EXP-562368669561258566",
	DisplayName = "Bunker Supporter",
	TokenRewardMultiplier = 1.5,
	ExperienceMultiplier = 1.25,
	ExtractionHoldMultiplier = 0.85,
	DailyBonusTokens = 5,
	WeeklyRewardIntervalSeconds = 7 * 24 * 60 * 60,
	WeeklyRewardCrate = {
		TokenAmount = 40,
		ExperienceAmount = 20,
	},
	ExtraInventorySlots = 1,
}

return table.freeze(SubscriptionConfig)
