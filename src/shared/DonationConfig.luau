local DonationConfig = {
	Tiers = {
		{
			Id = "rookie",
			Label = "50 TOKENS",
			ProductId = 0,
			Amount = 50,
			Color = Color3.fromRGB(126, 194, 138),
		},
		{
			Id = "survivor",
			Label = "250 TOKENS",
			ProductId = 0,
			Amount = 250,
			Color = Color3.fromRGB(236, 188, 108),
		},
		{
			Id = "veteran",
			Label = "750 TOKENS",
			ProductId = 0,
			Amount = 750,
			Color = Color3.fromRGB(122, 176, 242),
		},
	},
}

return table.freeze(DonationConfig)
