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

Config.LobbyLayout = {
	CentralHubOffset = Vector3.new(0, 0, 0),
	LeaderboardOffset = Vector3.new(-92, 0, 90),
	CargoStacks = {
		West = Vector3.new(-86, 0, -22),
		East = Vector3.new(82, 0, -24),
		South = Vector3.new(18, 0, 88),
	},
	WatchTowers = {
		West = Vector3.new(-108, 0, -78),
		East = Vector3.new(108, 0, -78),
	},
	PrivacyScreens = {
		{ name = "WestPrivacyNorth", offset = Vector3.new(-150, 0, -22), size = Vector3.new(7, 20, 92), rotationY = 8, color = Color3.fromRGB(54, 60, 72), accent = Color3.fromRGB(136, 164, 214) },
		{ name = "WestPrivacySouth", offset = Vector3.new(-146, 0, 58), size = Vector3.new(7, 18, 68), rotationY = -10, color = Color3.fromRGB(56, 62, 74), accent = Color3.fromRGB(154, 182, 224) },
		{ name = "EastPrivacyNorth", offset = Vector3.new(150, 0, -22), size = Vector3.new(7, 20, 92), rotationY = -8, color = Color3.fromRGB(54, 60, 72), accent = Color3.fromRGB(148, 196, 182) },
		{ name = "EastPrivacySouth", offset = Vector3.new(146, 0, 58), size = Vector3.new(7, 18, 68), rotationY = 10, color = Color3.fromRGB(56, 62, 74), accent = Color3.fromRGB(176, 214, 188) },
		{ name = "SouthPrivacyWall", offset = Vector3.new(0, 0, -144), size = Vector3.new(148, 20, 7), rotationY = 0, color = Color3.fromRGB(52, 58, 68), accent = Color3.fromRGB(210, 188, 146) },
		{ name = "NorthPrivacyWest", offset = Vector3.new(-74, 0, 132), size = Vector3.new(74, 18, 7), rotationY = 4, color = Color3.fromRGB(62, 48, 48), accent = Color3.fromRGB(236, 188, 164) },
		{ name = "NorthPrivacyEast", offset = Vector3.new(74, 0, 132), size = Vector3.new(74, 18, 7), rotationY = -4, color = Color3.fromRGB(62, 48, 48), accent = Color3.fromRGB(236, 188, 164) },
	},
	ArchiveLane = {
		LinkStart = Vector3.new(-34, 0, 54),
		LinkEnd = Vector3.new(-88, 0, 76),
		LinkWideStart = Vector3.new(-40, 0, 62),
		LinkWideEnd = Vector3.new(-90, 0, 84),
		LeadInStart = Vector3.new(-46, 0, 66),
		LeadInEnd = Vector3.new(-70, 0, 76),
		EntryPadOffset = Vector3.new(-56, 0.12, 70),
		EntryGlowOffset = Vector3.new(-56, 0.28, 70),
		EntryPylonLeftOffset = Vector3.new(-63.2, 2.7, 69.2),
		EntryPylonRightOffset = Vector3.new(-48.8, 2.7, 69.2),
		EntryHeaderOffset = Vector3.new(-56, 4.8, 68.4),
		Bollards = {
			Size = Vector3.new(1, 2.6, 1),
			GlowSize = Vector3.new(1.3, 0.14, 1.3),
			Color = Color3.fromRGB(92, 82, 64),
			GlowColor = Color3.fromRGB(255, 238, 204),
			GlowTransparency = 0.42,
			Offsets = {
				Vector3.new(-58, 1.5, 68),
				Vector3.new(-72, 1.5, 78),
				Vector3.new(-86, 1.5, 88),
			},
		},
		Props = {
			{ Name = "ArchiveStand", Offset = Vector3.new(-72, 1.2, 82), Size = Vector3.new(7.2, 2.2, 2.2), Color = Color3.fromRGB(96, 82, 60), Material = Enum.Material.WoodPlanks },
			{ Name = "ArchiveBench", Offset = Vector3.new(-60, 0.7, 74), Size = Vector3.new(6.2, 1.0, 2.2), Color = Color3.fromRGB(108, 96, 74), Material = Enum.Material.WoodPlanks },
			{ Name = "ArchiveCase", Offset = Vector3.new(-76, 1.0, 88), Size = Vector3.new(3.2, 1.6, 2.6), Color = Color3.fromRGB(168, 154, 126), Material = Enum.Material.SmoothPlastic },
		},
	},
	TransitPads = {
		Training = { Name = "TrainingTransit", Action = "Train", Object = "Training Yard", Subtitle = "Travel to the drill yard", TextOffset = Vector3.new(0, 4, 6), EntryPartName = "EntryPad" },
		Parkour = { Name = "ParkourTransit", Action = "Parkour", Object = "Parkour Line", Subtitle = "Travel to the movement course", TextOffset = Vector3.new(0, 4, 0), EntryPartName = "StartPad" },
		Duel = { Name = "DuelTransit", Action = "Duel", Object = "Duel Ring", Subtitle = "Travel to the spar ring", TextOffset = Vector3.new(0, 4, -6), EntryPartName = "ReturnPad" },
		TargetRange = { Name = "RangeTransit", Action = "Range", Object = "Target Range", Subtitle = "Travel to the firing lanes", TextOffset = Vector3.new(0, 4, 0), EntryPartName = "FiringLine" },
		Salvage = { Name = "SalvageTransit", Action = "Salvage", Object = "Salvage Run", Subtitle = "Travel to the cache sweep lane", TextOffset = Vector3.new(0, 4, 0), EntryPartName = "StartPad" },
		Supporter = { Name = "SupporterTransit", Action = "Support", Object = "Supporter Lounge", Subtitle = "Supporter-only lounge and reward terminal", TextOffset = Vector3.new(0, 4, 0), EntryPartName = "EntryPad" },
		Vip = { Name = "VipTransit", Action = "VIP", Object = "VIP Operations", Subtitle = "VIP-only operator lounge and fast lane", TextOffset = Vector3.new(0, 4, 0), EntryPartName = "EntryPad" },
	},
}

Config.SpawnLayout = {
	Apron = { Size = Vector3.new(38, 0.8, 30), Offset = Vector3.new(0, 0.4, 18), Color = Color3.fromRGB(78, 86, 98) },
	Frame = { Size = Vector3.new(42, 0.12, 34), Offset = Vector3.new(0, 0.9, 18), Color = Color3.fromRGB(132, 148, 176), Transparency = 0.8 },
	Guide = { Size = Vector3.new(4.2, 0.08, 30), Offset = Vector3.new(0, 0.84, 14), Color = Color3.fromRGB(186, 212, 244), Transparency = 0.72 },
	Wings = {
		{ Name = "SpawnWingLeft", Offset = Vector3.new(-22, 0.64, 19), Size = Vector3.new(10, 0.48, 18), RotationY = math.rad(14), Color = Color3.fromRGB(64, 72, 84) },
		{ Name = "SpawnWingRight", Offset = Vector3.new(22, 0.64, 19), Size = Vector3.new(10, 0.48, 18), RotationY = math.rad(-14), Color = Color3.fromRGB(64, 72, 84) },
	},
	Gate = {
		Left = { Size = Vector3.new(2.4, 7.2, 2.4), Offset = Vector3.new(-13.5, 3.6, 27), Color = Color3.fromRGB(66, 74, 88) },
		Right = { Size = Vector3.new(2.4, 7.2, 2.4), Offset = Vector3.new(13.5, 3.6, 27), Color = Color3.fromRGB(66, 74, 88) },
		Top = { Size = Vector3.new(30, 0.9, 2.6), Offset = Vector3.new(0, 7.2, 27), Color = Color3.fromRGB(78, 86, 98) },
		TopGlow = { Size = Vector3.new(22, 0.08, 0.8), Offset = Vector3.new(0, 6.96, 26.12), Color = Color3.fromRGB(222, 232, 244), Transparency = 0.72 },
	},
	AxisPylons = {
		PartSize = Vector3.new(0.9, 1.2, 0.9),
		GlowSize = Vector3.new(1.4, 0.08, 1.4),
		Color = Color3.fromRGB(108, 118, 134),
		GlowColor = Color3.fromRGB(232, 238, 246),
		GlowTransparency = 0.7,
		Offsets = {
			Vector3.new(0, 0.88, 20),
			Vector3.new(0, 0.88, 3),
			Vector3.new(0, 0.88, -18),
		},
	},
	Beacons = {
		PartSize = Vector3.new(2, 8, 2),
		GlowSize = Vector3.new(2.2, 0.14, 2.2),
		Color = Color3.fromRGB(74, 82, 96),
		GlowColor = Color3.fromRGB(186, 212, 244),
		GlowTransparency = 0.46,
		LeftOffset = Vector3.new(-20, 4, 18),
		RightOffset = Vector3.new(20, 4, 18),
	},
	SpawnLocation = {
		Size = Vector3.new(18, 1, 18),
		Offset = Vector3.new(0, 1.5, 18),
		Color = Color3.fromRGB(110, 122, 138),
	},
}

Config.LaneEntries = {
	WestDrill = {
		Lane = { Size = Vector3.new(7.2, 0.06, 42), Offset = Vector3.new(-68, 0.32, 4), Color = Color3.fromRGB(236, 214, 152), Transparency = 0.9 },
		EntryPad = { Size = Vector3.new(12, 0.18, 8), Offset = Vector3.new(-58, 0.12, 18), Color = Color3.fromRGB(156, 146, 118) },
		EntryGlow = { Size = Vector3.new(7.2, 0.05, 1.8), Offset = Vector3.new(-58, 0.28, 18), Color = Color3.fromRGB(236, 216, 156), Transparency = 0.88 },
		EntryHeader = { Size = Vector3.new(10.4, 0.56, 1.2), Offset = Vector3.new(-58, 4.5, 17.2), Color = Color3.fromRGB(110, 94, 62), Text = "DRILL LANE", TextColor = Color3.fromRGB(244, 224, 164), TextSize = Vector2.new(96, 16) },
		Scaffolds = {
			Size = Vector3.new(2.2, 5.6, 18),
			Color = Color3.fromRGB(118, 102, 72),
			Offsets = {
				Vector3.new(-82, 2.8, -18),
				Vector3.new(-82, 2.8, 18),
			},
		},
	},
	EastCombat = {
		Spine = { Size = Vector3.new(8, 1.8, 48), Offset = Vector3.new(68, 0.94, 3), Color = Color3.fromRGB(58, 64, 70) },
		Stripe = { Size = Vector3.new(0.8, 0.06, 40), Offset = Vector3.new(68, 1.92, 3), Color = Color3.fromRGB(255, 188, 112), Transparency = 0.84 },
		EntryPad = { Size = Vector3.new(12, 0.18, 8), Offset = Vector3.new(58, 0.12, 18), Color = Color3.fromRGB(92, 96, 104) },
		EntryGlow = { Size = Vector3.new(7.2, 0.05, 1.8), Offset = Vector3.new(58, 0.28, 18), Color = Color3.fromRGB(255, 188, 112), Transparency = 0.88 },
		EntryHeader = { Size = Vector3.new(11.8, 0.56, 1.2), Offset = Vector3.new(58, 4.5, 17.2), Color = Color3.fromRGB(82, 74, 64), Text = "COMBAT LANE", TextColor = Color3.fromRGB(244, 196, 154), TextSize = Vector2.new(106, 16) },
	},
	Salvage = {
		Corridor = { Size = Vector3.new(18, 0.24, 42), Offset = Vector3.new(-8, 0.16, -96), Color = Color3.fromRGB(96, 86, 72) },
		Guide = { Size = Vector3.new(2.2, 0.06, 32), Offset = Vector3.new(-8, 0.32, -96), Color = Color3.fromRGB(232, 210, 156), Transparency = 0.88 },
		EntryPad = { Size = Vector3.new(13.6, 0.18, 8.4), Offset = Vector3.new(-8, 0.12, -76), Color = Color3.fromRGB(126, 112, 92) },
		EntryGlow = { Size = Vector3.new(8.2, 0.05, 1.8), Offset = Vector3.new(-8, 0.28, -76), Color = Color3.fromRGB(236, 214, 158), Transparency = 0.88 },
		EntryHeader = { Size = Vector3.new(11.8, 0.56, 1.2), Offset = Vector3.new(-8, 4.6, -76.8), Color = Color3.fromRGB(104, 88, 64), Text = "SALVAGE LANE", TextColor = Color3.fromRGB(240, 220, 166), TextSize = Vector2.new(108, 16) },
	},
}

Config.LobbyNpcs = {
	{ Id = "TrainingMarshal", DisplayName = "Trainer Sol", RouteStart = Vector3.new(-60, 0, -34), RouteEnd = Vector3.new(-60, 0, -34), Accent = Color3.fromRGB(244, 212, 152), Phase = 0.18, Panel = { title = "Trainer Sol", role = "Drill supervisor", body = "Use training before you deploy. Run the hurdle lane, hit the targets, and settle your movement before you spend tokens on a live mission.", actionLabel = "Training Lane", actionPanel = "" } },
	{ Id = "NorthPatrol", DisplayName = "Quartermaster Rhea", RouteStart = Vector3.new(0, 0, -46), RouteEnd = Vector3.new(0, 0, -46), Accent = Color3.fromRGB(245, 215, 156), Phase = 0.1, Panel = { title = "Quartermaster Rhea", role = "Quartermaster lead", body = "Weapons, cosmetics, and bunker stock all route through my board. If you want cleaner gear or stronger tools, start with the quartermaster lane.", actionLabel = "Open Shop", actionPanel = "Shop" } },
	{ Id = "WestPatrol", DisplayName = "Officer Vale", RouteStart = Vector3.new(-46, 0, 28), RouteEnd = Vector3.new(-46, 0, 28), Accent = Color3.fromRGB(171, 205, 237), Phase = 0.35, Panel = { title = "Officer Vale", role = "Fireteam liaison", body = "Keep the roster tight. Solo is fine, but squads survive longer if someone owns the lead slot and the group deploys with a clear route.", actionLabel = "Open Squad", actionPanel = "Squad" } },
	{ Id = "OpsCoordinator", DisplayName = "Coordinator Nyra", RouteStart = Vector3.new(0, 0, 40), RouteEnd = Vector3.new(0, 0, 40), Accent = Color3.fromRGB(198, 228, 132), Phase = 0.54, Panel = { title = "Coordinator Nyra", role = "Operations keeper", body = "Daily ops, stipend timing, activity progress, and weekly reward lanes are tracked here. Check the board before every run so you do not leave rewards behind.", actionLabel = "Open Ops Board", actionPanel = "QuestBoard" } },
	{ Id = "SouthPatrol", DisplayName = "Marshal Kade", RouteStart = Vector3.new(0, 0, 54), RouteEnd = Vector3.new(0, 0, 54), Accent = Color3.fromRGB(255, 214, 214), Phase = 0.82, Panel = { title = "Marshal Kade", role = "Launch marshal", body = "Vote the route on the floor pads, watch the board for the current lead, and launch once the squad is ready. Everything past this lane is live combat.", actionLabel = "Ready To Launch", actionPanel = "" } },
}

Config.LeaderboardLayout = {
	Podium = {
		Size = UDim2.new(1, -48, 0, 134),
		Cards = {
			FirstCard = {
				x = 136,
				y = 0,
				width = 248,
				height = 72,
				accent = Color3.fromRGB(172, 110, 255),
				glow = Color3.fromRGB(88, 220, 255),
			},
			SecondCard = {
				x = 44,
				y = 82,
				width = 148,
				height = 46,
				accent = Color3.fromRGB(255, 194, 94),
				glow = Color3.fromRGB(255, 120, 72),
			},
			ThirdCard = {
				x = 328,
				y = 82,
				width = 148,
				height = 46,
				accent = Color3.fromRGB(108, 242, 214),
				glow = Color3.fromRGB(94, 164, 255),
			},
		},
	},
	List = {
		HeaderY = 236,
		HeaderHeight = 22,
		SlotStartY = 268,
		SlotSpacing = 50,
		SlotCount = 12,
		ScrollY = 266,
		ScrollBottomPadding = 276,
	},
}

Config.CentralHubLayout = {
	OuterPad = { Size = Vector3.new(20, 0.24, 20), Offset = Vector3.new(0, 2.18, 0) },
	Plinth = { Size = Vector3.new(10, 0.8, 10), Offset = Vector3.new(0, 2.02, 0) },
	InnerPad = { Size = Vector3.new(6.5, 0.22, 6.5), Offset = Vector3.new(0, 2.5, 0) },
	HubRing = { Size = Vector3.new(18, 0.12, 18), Offset = Vector3.new(0, 2.08, 0) },
	HubRingOuter = { Size = Vector3.new(24, 0.08, 24), Offset = Vector3.new(0, 1.28, 0) },
	CommandCore = { Size = Vector3.new(4.8, 1.6, 4.8), Offset = Vector3.new(0, 2.7, 0) },
	CommandGlow = { Size = Vector3.new(5.6, 0.12, 5.6), Offset = Vector3.new(0, 3.56, 0) },
	Bollards = {
		Size = Vector3.new(0.9, 2, 0.9),
		Offsets = {
			Vector3.new(-7.2, 0.95, -7.2),
			Vector3.new(7.2, 0.95, -7.2),
			Vector3.new(-7.2, 0.95, 7.2),
			Vector3.new(7.2, 0.95, 7.2),
		},
	},
	Rails = {
		{ Name = "NorthRail", Offset = Vector3.new(0, 1.2, -10.6), Size = Vector3.new(14, 1.6, 1) },
		{ Name = "SouthRail", Offset = Vector3.new(0, 1.2, 10.6), Size = Vector3.new(14, 1.6, 1) },
	},
	Consoles = {
		Size = Vector3.new(2.2, 1.1, 2.2),
		Offsets = {
			Vector3.new(-5.2, 0.9, 0),
			Vector3.new(5.2, 0.9, 0),
		},
	},
	Walkways = {
		{ Name = "NorthWalkway", Offset = Vector3.new(0, 0.25, -18), Size = Vector3.new(12, 0.3, 14) },
		{ Name = "SouthWalkway", Offset = Vector3.new(0, 0.25, 18), Size = Vector3.new(12, 0.3, 14) },
	},
	HubPlates = {
		Size = Vector3.new(7, 0.12, 4),
		Offsets = {
			Vector3.new(0, 0.34, -13),
			Vector3.new(0, 0.34, 13),
			Vector3.new(-13, 0.34, 0),
			Vector3.new(13, 0.34, 0),
		},
	},
	NavPlates = {
		{ Name = "NorthNav", Offset = Vector3.new(0, 2.1, -8.6), Size = Vector3.new(5.6, 0.12, 8) },
		{ Name = "SouthNav", Offset = Vector3.new(0, 2.1, 8.6), Size = Vector3.new(5.6, 0.12, 8) },
		{ Name = "WestNav", Offset = Vector3.new(-8.6, 2.1, 0), Size = Vector3.new(8, 0.12, 5.6) },
		{ Name = "EastNav", Offset = Vector3.new(8.6, 2.1, 0), Size = Vector3.new(8, 0.12, 5.6) },
	},
	CommandPlate = { Size = Vector3.new(12, 0.12, 4), Offset = Vector3.new(0, 2.12, 0) },
}

Config.DeployLayout = {
	VoteDeck = {
		Floor = { Size = Vector3.new(40, 0.4, 34), Offset = Vector3.new(0, 0.2, 0), Color = Color3.fromRGB(74, 52, 46) },
		Frame = { Size = Vector3.new(34, 10.8, 1.6), Offset = Vector3.new(0, 5.6, -11.4), Color = Color3.fromRGB(94, 60, 54) },
		FrameGlow = { Size = Vector3.new(26, 0.18, 0.8), Offset = Vector3.new(0, 9.4, -10.5), Color = Color3.fromRGB(255, 204, 176), Transparency = 0.72 },
		Board = { Size = Vector3.new(26, 8.8, 0.6), Offset = Vector3.new(0, 5.2, -10.6), Color = Color3.fromRGB(228, 218, 202) },
		Pads = {
			Size = Vector3.new(6.6, 0.8, 6.6),
			GlowSize = Vector3.new(5.0, 0.08, 5.0),
			Offsets = { Vector3.new(-11, 0.6, -2.2), Vector3.new(0, 0.6, -2.2), Vector3.new(11, 0.6, -2.2) },
			TextOffset = Vector3.new(0, 1.8, 0),
			TextSize = Vector2.new(72, 20),
			Palettes = {
				{ base = Color3.fromRGB(122, 164, 102), glow = Color3.fromRGB(178, 255, 154) },
				{ base = Color3.fromRGB(104, 138, 188), glow = Color3.fromRGB(158, 212, 255) },
				{ base = Color3.fromRGB(186, 134, 94), glow = Color3.fromRGB(255, 212, 156) },
			},
		},
		LaunchPad = {
			Size = Vector3.new(15.5, 1, 8.8),
			Offset = Vector3.new(0, 0.7, 11.8),
			Color = Color3.fromRGB(154, 96, 82),
			GlowSize = Vector3.new(11.6, 0.08, 4.2),
			GlowColor = Color3.fromRGB(255, 188, 154),
			GlowTransparency = 0.5,
			Text = "LAUNCH",
			TextOffset = Vector3.new(0, 2.2, 0),
			TextColor = Color3.fromRGB(255, 220, 194),
			TextSize = Vector2.new(92, 22),
		},
		Pylons = {
			Size = Vector3.new(1.4, 4.2, 1.4),
			GlowSize = Vector3.new(1.8, 0.12, 1.8),
			Color = Color3.fromRGB(102, 72, 62),
			GlowColor = Color3.fromRGB(255, 204, 176),
			GlowTransparency = 0.42,
			Offsets = {
				Vector3.new(-16, 2.2, -8),
				Vector3.new(16, 2.2, -8),
				Vector3.new(-16, 2.2, 8),
				Vector3.new(16, 2.2, 8),
			},
		},
	},
	Concourse = {
		Floor = { Size = Vector3.new(46, 0.36, 54), Offset = Vector3.new(0, 0.18, -24) },
		Inset = { Size = Vector3.new(34, 0.08, 42), Offset = Vector3.new(0, 0.4, -24) },
		Guide = { Size = Vector3.new(6, 0.08, 36), Offset = Vector3.new(0, 0.44, -24) },
		VoteApron = { Size = Vector3.new(24, 0.22, 12), Offset = Vector3.new(0, 0.52, -44) },
		VoteApronGlow = { Size = Vector3.new(20, 0.08, 7.2), Offset = Vector3.new(0, 0.68, -44) },
		SignalPylons = {
			Size = Vector3.new(2.4, 11.5, 2.4),
			GlowSize = Vector3.new(0.16, 8.2, 1.5),
			Offsets = {
				Vector3.new(-14, 5.8, -46),
				Vector3.new(14, 5.8, -46),
			},
		},
		SignalHeader = { Size = Vector3.new(30, 0.12, 1.4), Offset = Vector3.new(0, 11.36, -46) },
		SideWings = {
			Size = Vector3.new(5.2, 4.2, 24),
			GlowSize = Vector3.new(0.16, 3.2, 18),
			Entries = {
				{ Offset = Vector3.new(-17.8, 2.1, -23), RotationY = 8 },
				{ Offset = Vector3.new(17.8, 2.1, -23), RotationY = -8 },
			},
		},
		RouteConsoles = {
			Size = Vector3.new(2.8, 2.4, 2.2),
			ScreenSize = Vector3.new(1.6, 1.2, 0.1),
			Offsets = {
				Vector3.new(-9.6, 1.3, -29),
				Vector3.new(9.6, 1.3, -29),
			},
		},
		Pylons = {
			Size = Vector3.new(1.2, 3.6, 1.2),
			CapSize = Vector3.new(1.6, 0.16, 1.6),
			Offsets = {
				Vector3.new(-18, 2.1, -38),
				Vector3.new(18, 2.1, -38),
				Vector3.new(-18, 2.1, -12),
				Vector3.new(18, 2.1, -12),
			},
		},
	},
	Bay = {
		Floor = { Size = Vector3.new(34, 0.45, 42), Offset = Vector3.new(0, 0.24, -4) },
		LeftWall = { Size = Vector3.new(2.6, 16, 26), Offset = Vector3.new(-16, 8, -4) },
		RightWall = { Size = Vector3.new(2.6, 16, 26), Offset = Vector3.new(16, 8, -4) },
		Canopy = { Size = Vector3.new(34, 2, 20), Offset = Vector3.new(0, 13.5, -4) },
		FrontBrace = { Size = Vector3.new(30, 1.2, 2.4), Offset = Vector3.new(0, 11.3, -14.8) },
		Crown = { Size = Vector3.new(24, 1.6, 6), Offset = Vector3.new(0, 15.4, -10.2) },
		Rear = { Size = Vector3.new(34, 14, 2), Offset = Vector3.new(0, 7, 8.5) },
		LeftInset = { Size = Vector3.new(4, 8, 8), Offset = Vector3.new(-12.2, 4.5, 6.4) },
		RightInset = { Size = Vector3.new(4, 8, 8), Offset = Vector3.new(12.2, 4.5, 6.4) },
		Chevrons = {
			Size = Vector3.new(4.8, 0.12, 1.1),
			Entries = {
				{ Offset = Vector3.new(-8.2, 0.86, -11.2), RotationY = 18 },
				{ Offset = Vector3.new(8.2, 0.86, -11.2), RotationY = -18 },
			},
		},
		SideStrips = {
			Size = Vector3.new(0.2, 10, 18),
			Offsets = {
				Vector3.new(-14.8, 7.4, -2),
				Vector3.new(14.8, 7.4, -2),
			},
		},
		Lintel = { Size = Vector3.new(20, 0.24, 1), Offset = Vector3.new(0, 12, -10.8) },
		Lights = {
			Size = Vector3.new(5.4, 0.18, 1),
			Offsets = {
				Vector3.new(-10.2, 10.8, -2.4),
				Vector3.new(10.2, 10.8, -2.4),
			},
		},
	},
	Pad = {
		Pad = { Size = Vector3.new(24, 1, 24), Offset = Vector3.new(0, 0, 0) },
		OuterRing = { Size = Vector3.new(24, 0.1, 24), Offset = Vector3.new(0, 0.7, 0) },
		InnerRing = { Size = Vector3.new(12, 0.08, 12), Offset = Vector3.new(0, 0.9, 0) },
		PylonLeft = { Size = Vector3.new(2, 14, 2), Offset = Vector3.new(-11, 7, -11) },
		PylonRight = { Size = Vector3.new(2, 14, 2), Offset = Vector3.new(11, 7, -11) },
		Header = { Size = Vector3.new(18, 0.24, 1.4), Offset = Vector3.new(0, 13, -11) },
	},
	Runway = {
		Runway = { Size = Vector3.new(22, 0.3, 32), Offset = Vector3.new(0, 0.76, -22) },
		Threshold = { Size = Vector3.new(18, 0.24, 4), Offset = Vector3.new(0, 0.92, -5.4) },
		ThresholdGlow = { Size = Vector3.new(16, 0.08, 1.2), Offset = Vector3.new(0, 1.08, -6.5) },
		Frame = { Size = Vector3.new(26, 0.12, 36), Offset = Vector3.new(0, 0.92, -22) },
		Guide = { Size = Vector3.new(4, 0.08, 26), Offset = Vector3.new(0, 0.84, -22) },
		SideLeft = { Size = Vector3.new(0.22, 0.08, 26), Offset = Vector3.new(-8.8, 0.84, -22) },
		SideRight = { Size = Vector3.new(0.22, 0.08, 26), Offset = Vector3.new(8.8, 0.84, -22) },
		Bollards = {
			Size = Vector3.new(1.4, 2.8, 1.4),
			LampSize = Vector3.new(1.8, 0.14, 1.8),
			Offsets = {
				Vector3.new(-9.5, 1.4, -30),
				Vector3.new(9.5, 1.4, -30),
				Vector3.new(-15.5, 1.4, -42),
				Vector3.new(15.5, 1.4, -42),
			},
		},
		Beacons = {
			Size = Vector3.new(1.2, 3.6, 1.2),
			GlowSize = Vector3.new(1.4, 1.4, 1.4),
			Offsets = {
				Vector3.new(-12.8, 0.9, -22),
				Vector3.new(12.8, 0.9, -22),
			},
		},
	},
	Prep = {
		Crates = {
			Size = Vector3.new(3.2, 2.6, 3.2),
			Offsets = {
				Vector3.new(-11.4, 1.4, 4.8),
				Vector3.new(11.4, 1.4, 4.8),
			},
		},
		Lockers = {
			Size = Vector3.new(2.4, 8, 2.4),
			Offsets = {
				Vector3.new(-12.4, 4, 8.2),
				Vector3.new(12.4, 4, 8.2),
			},
		},
		Benches = {
			Size = Vector3.new(5.2, 1.2, 2.2),
			Offsets = {
				Vector3.new(-8.8, 0.72, 10.6),
				Vector3.new(8.8, 0.72, 10.6),
			},
		},
		StagingPlate = { Size = Vector3.new(12, 0.18, 6), Offset = Vector3.new(0, 0.82, 8.4) },
		StagingGuide = { Size = Vector3.new(8, 0.08, 2), Offset = Vector3.new(0, 0.96, 5.8) },
		StagingStruts = {
			Size = Vector3.new(1.4, 7.2, 1.4),
			Offsets = {
				Vector3.new(-12, 3.6, 13.2),
				Vector3.new(12, 3.6, 13.2),
			},
		},
		StagingCrown = { Size = Vector3.new(14, 0.9, 3), Offset = Vector3.new(0, 8.2, 11.8) },
	},
	Gate = {
		Left = { Size = Vector3.new(6, 20, 4), Offset = Vector3.new(-18, 10, -14) },
		Right = { Size = Vector3.new(6, 20, 4), Offset = Vector3.new(18, 10, -14) },
		Top = { Size = Vector3.new(42, 3, 4), Offset = Vector3.new(0, 19, -14) },
		BlastDoor = { Size = Vector3.new(24, 16, 2), Offset = Vector3.new(0, 8, -15.2) },
		TowerLeft = { Size = Vector3.new(4, 24, 6), Offset = Vector3.new(-23, 12, -12) },
		TowerRight = { Size = Vector3.new(4, 24, 6), Offset = Vector3.new(23, 12, -12) },
		Bridge = { Size = Vector3.new(54, 2, 6), Offset = Vector3.new(0, 23, -12) },
		Crown = { Size = Vector3.new(28, 2, 6), Offset = Vector3.new(0, 26.2, -12) },
		Wings = {
			Size = Vector3.new(6, 18, 3),
			Offsets = {
				Vector3.new(-32, 15, -13.5),
				Vector3.new(32, 15, -13.5),
			},
		},
		Braces = {
			Size = Vector3.new(10, 2, 2),
			Entries = {
				{ Offset = Vector3.new(-13, 8, -13.2), RotationZ = 22 },
				{ Offset = Vector3.new(13, 8, -13.2), RotationZ = -22 },
			},
		},
		Light = { Size = Vector3.new(24, 0.26, 1), Offset = Vector3.new(0, 16.5, -12.2) },
		BridgeLight = { Size = Vector3.new(34, 0.18, 1.2), Offset = Vector3.new(0, 21.8, -8.8) },
		WarningBeacons = {
			Size = Vector3.new(1.8, 1.8, 1.8),
			Offsets = {
				Vector3.new(-23, 21, -9),
				Vector3.new(23, 21, -9),
			},
		},
	},
	Lane = {
		SpineLinkStart = Vector3.new(0, 0, 44),
		SpineLinkEnd = Vector3.new(0, 0, 90),
		SpineLeadInStart = Vector3.new(0, 0, 58),
		SpineLeadInEnd = Vector3.new(0, 0, 76),
		EntryPad = { Size = Vector3.new(18, 0.18, 9.2), Offset = Vector3.new(0, 0.12, 66) },
		EntryGlow = { Size = Vector3.new(7.8, 0.04, 1.5), Offset = Vector3.new(0, 0.28, 66) },
		EntryPylons = {
			Size = Vector3.new(1.6, 6.2, 1.6),
			Offsets = {
				Vector3.new(-9.2, 3.1, 65.2),
				Vector3.new(9.2, 3.1, 65.2),
			},
		},
		EntryHeader = { Size = Vector3.new(14.8, 0.62, 1.3), Offset = Vector3.new(0, 5.1, 64.6) },
		DistrictBays = {
			Size = Vector3.new(8, 3.4, 12),
			GlowSize = Vector3.new(6.4, 0.08, 8.2),
			Offsets = {
				Vector3.new(-28, 2.1, 78),
				Vector3.new(28, 2.1, 78),
			},
		},
	},
}

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
	Supporter = {
		Offset = Vector3.new(540, -58, 320),
		Color = Color3.fromRGB(142, 116, 62),
		Accent = Color3.fromRGB(246, 220, 138),
		Title = "SUPPORTER",
		Subtitle = "Lounge access, weekly crate lane, and premium briefing",
	},
	Vip = {
		Offset = Vector3.new(-540, -58, 320),
		Color = Color3.fromRGB(86, 112, 154),
		Accent = Color3.fromRGB(186, 220, 255),
		Title = "VIP",
		Subtitle = "Operator lounge, fast lane, and priority mission prep",
	},
	Training = {
		Offset = Vector3.new(-620, -64, -280),
		Color = Color3.fromRGB(120, 98, 58),
		Accent = Color3.fromRGB(244, 212, 152),
		Title = "TRAIN",
		Subtitle = "Sprint lanes, target drills, and weapon warmup",
	},
	Parkour = {
		Offset = Vector3.new(-620, -64, 20),
		Color = Color3.fromRGB(94, 108, 150),
		Accent = Color3.fromRGB(206, 220, 255),
		Title = "PARKOUR",
		Subtitle = "Run rooftops, jump gaps, and warm up movement tech",
	},
	Duel = {
		Offset = Vector3.new(620, -64, -280),
		Color = Color3.fromRGB(124, 72, 72),
		Accent = Color3.fromRGB(244, 182, 182),
		Title = "DUEL",
		Subtitle = "Step into the spar ring and stage 1v1s",
	},
	TargetRange = {
		Offset = Vector3.new(620, -64, 20),
		Color = Color3.fromRGB(72, 104, 92),
		Accent = Color3.fromRGB(186, 238, 214),
		Title = "RANGE",
		Subtitle = "Line up shots, test recoil, and prep ranged loadouts",
	},
	Salvage = {
		Offset = Vector3.new(0, -68, -640),
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
