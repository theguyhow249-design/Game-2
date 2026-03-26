local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent:WaitForChild("LobbyWorldConfig"))

local LobbyWorld = {}

local function clearExisting(rootName: string)
	local existing = Workspace:FindFirstChild(rootName)
	if existing then
		existing:Destroy()
	end
end

local function makePart(parent: Instance, className: string, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material)
	local part = Instance.new(className)
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = true
	part.Color = color
	part.Material = material
	part.CFrame = cframe
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function attachLabel(part: BasePart, title: string, subtitle: string, accent: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(164, 52)
	gui.StudsOffset = Vector3.new(0, 1.6, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 60
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(28, 32, 38)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 1
	stroke.Transparency = 0.22
	stroke.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, -16, 0.5, -6)
	titleLabel.Position = UDim2.fromOffset(8, 4)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = false
	titleLabel.TextSize = 15
	titleLabel.Parent = frame

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.new(0, 8, 0.5, 0)
	subtitleLabel.Size = UDim2.new(1, -16, 0.5, -6)
	subtitleLabel.Font = Enum.Font.GothamMedium
	subtitleLabel.Text = subtitle
	subtitleLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	subtitleLabel.TextScaled = false
	subtitleLabel.TextSize = 10
	subtitleLabel.TextWrapped = true
	subtitleLabel.Parent = frame
end

local function makeGlowPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, transparency: number)
	local glow = makePart(parent, "Part", name, size, cframe, color, Enum.Material.Neon)
	glow.Transparency = transparency
	glow.CanCollide = false
	glow.CanQuery = false
	return glow
end

local function attachWorldText(part: BasePart, text: string, offset: Vector3, accent: Color3, size: Vector2?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldText"
	gui.Size = UDim2.fromOffset((size and size.X) or 160, (size and size.Y) or 38)
	gui.StudsOffset = offset
	gui.AlwaysOnTop = false
	gui.MaxDistance = 78
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = accent
	label.TextScaled = false
	label.TextSize = 14
	label.Parent = gui
end

local function attachSurfaceBoard(part: BasePart, title: string, accent: Color3, animatedBoardEffects)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 28
	gui.LightInfluence = 1
	gui.AlwaysOnTop = false
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 2
	stroke.Transparency = 0.18
	stroke.Parent = frame

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(24, 18)
	header.Size = UDim2.new(1, -48, 0, 26)
	header.Font = Enum.Font.GothamBlack
	header.Text = title
	header.TextColor3 = Color3.fromRGB(238, 242, 248)
	header.TextSize = 24
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = frame

	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BackgroundColor3 = accent
	rule.BackgroundTransparency = 0.12
	rule.BorderSizePixel = 0
	rule.Position = UDim2.fromOffset(24, 54)
	rule.Size = UDim2.fromOffset(170, 4)
	rule.Parent = frame

	local layout = {
		{ key = "Levels", title = "LEVELS", color = Color3.fromRGB(132, 178, 232), x = 24 },
		{ key = "Runs", title = "RUNS", color = Color3.fromRGB(122, 198, 156), x = 230 },
		{ key = "Kills", title = "KILLS", color = Color3.fromRGB(214, 174, 104), x = 436 },
	}
	local rankThemes = {
		{
			label = "#1",
			base = Color3.fromRGB(150, 104, 255),
			glow = Color3.fromRGB(102, 222, 255),
			y = 40,
			height = 56,
			width = 12,
			badgeSize = Vector2.new(68, 24),
			badgeX = 26,
			title = "CROWN",
		},
		{
			label = "#2",
			base = Color3.fromRGB(255, 194, 94),
			glow = Color3.fromRGB(255, 132, 74),
			y = 104,
			height = 42,
			width = 8,
			badgeSize = Vector2.new(36, 18),
			badgeX = 22,
			title = nil,
		},
		{
			label = "#3",
			base = Color3.fromRGB(108, 242, 214),
			glow = Color3.fromRGB(94, 164, 255),
			y = 160,
			height = 42,
			width = 8,
			badgeSize = Vector2.new(36, 18),
			badgeX = 22,
			title = nil,
		},
	}
	for _, info in ipairs(layout) do
		local column = Instance.new("Frame")
		column.Name = info.key .. "Column"
		column.BackgroundColor3 = Color3.fromRGB(22, 26, 32)
		column.BackgroundTransparency = 0.04
		column.BorderSizePixel = 0
		column.Position = UDim2.fromOffset(info.x, 86)
		column.Size = UDim2.fromOffset(182, 252)
		column.Parent = frame

		local columnStroke = Instance.new("UIStroke")
		columnStroke.Color = info.color
		columnStroke.Transparency = 0.18
		columnStroke.Parent = column

		local columnTitle = Instance.new("TextLabel")
		columnTitle.Name = "Title"
		columnTitle.BackgroundTransparency = 1
		columnTitle.Position = UDim2.fromOffset(14, 12)
		columnTitle.Size = UDim2.new(1, -28, 0, 20)
		columnTitle.Font = Enum.Font.GothamBold
		columnTitle.Text = info.title
		columnTitle.TextColor3 = info.color
		columnTitle.TextSize = 16
		columnTitle.TextXAlignment = Enum.TextXAlignment.Left
		columnTitle.Parent = column

		for rank, theme in ipairs(rankThemes) do
			local rail = Instance.new("Frame")
			rail.Name = ("Rank%dRail"):format(rank)
			rail.BackgroundColor3 = theme.base
			rail.BackgroundTransparency = 0.2
			rail.BorderSizePixel = 0
			rail.Position = UDim2.fromOffset(10, theme.y)
			rail.Size = UDim2.fromOffset(theme.width, theme.height)
			rail.Parent = column

			local railCorner = Instance.new("UICorner")
			railCorner.CornerRadius = UDim.new(0, 8)
			railCorner.Parent = rail

			local railGradient = Instance.new("UIGradient")
			railGradient.Name = "Flow"
			railGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, theme.base),
				ColorSequenceKeypoint.new(0.45, theme.glow),
				ColorSequenceKeypoint.new(1, theme.base),
			})
			railGradient.Rotation = 90
			railGradient.Parent = rail

			local badge = Instance.new("TextLabel")
			badge.Name = ("Rank%dBadge"):format(rank)
			badge.BackgroundColor3 = Color3.fromRGB(12, 16, 22)
			badge.BackgroundTransparency = 0.14
			badge.BorderSizePixel = 0
			badge.Position = UDim2.fromOffset(theme.badgeX, theme.y + 2)
			badge.Size = UDim2.fromOffset(theme.badgeSize.X, theme.badgeSize.Y)
			badge.Font = Enum.Font.GothamBlack
			badge.Text = theme.title and (theme.label .. " " .. theme.title) or theme.label
			badge.TextColor3 = theme.base
			badge.TextSize = rank == 1 and 11 or 12
			badge.Parent = column

			local badgeCorner = Instance.new("UICorner")
			badgeCorner.CornerRadius = UDim.new(0, rank == 1 and 11 or 9)
			badgeCorner.Parent = badge

			local badgeStroke = Instance.new("UIStroke")
			badgeStroke.Color = theme.glow
			badgeStroke.Transparency = 0.18
			badgeStroke.Parent = badge

			local badgeGradient = Instance.new("UIGradient")
			badgeGradient.Name = "BadgeFlow"
			badgeGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 20, 28)),
				ColorSequenceKeypoint.new(0.55, theme.base:Lerp(theme.glow, 0.3)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 20, 28)),
			})
			badgeGradient.Rotation = rank == 1 and 0 or 90
			badgeGradient.Parent = badge

			local crownIcon = nil
			if rank == 1 then
				crownIcon = Instance.new("TextLabel")
				crownIcon.Name = "CrownIcon"
				crownIcon.BackgroundTransparency = 1
				crownIcon.Position = UDim2.fromOffset(theme.badgeX + 2, theme.y - 18)
				crownIcon.Size = UDim2.fromOffset(28, 18)
				crownIcon.Font = Enum.Font.GothamBlack
				crownIcon.Text = "CROWN"
				crownIcon.TextColor3 = theme.glow
				crownIcon.TextSize = 10
				crownIcon.Parent = column
			end

			if animatedBoardEffects then
				table.insert(animatedBoardEffects, {
					type = "boardRail",
					frame = rail,
					gradient = railGradient,
					badge = badge,
					badgeGradient = badgeGradient,
					crownIcon = crownIcon,
					base = theme.base,
					glow = theme.glow,
					speed = rank == 1 and 0.28 or (0.16 + (rank * 0.03)),
					phase = rank * 0.45 + (info.x / 180),
					isChampion = rank == 1,
				})
			end
		end

		local body = Instance.new("TextLabel")
		body.Name = "Body"
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromOffset(14, 42)
		body.Size = UDim2.new(1, -28, 1, -56)
		body.Font = Enum.Font.GothamMedium
		body.Text = "Waiting for players..."
		body.TextColor3 = Color3.fromRGB(230, 236, 244)
		body.TextSize = 17
		body.RichText = true
		body.TextWrapped = true
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.Parent = column
	end

	return gui
end

local LEADERBOARD_MASTER_PPS = 16
local LEADERBOARD_MASTER_WINDOW_BUTTONS = {
	{ name = "AllTimeWindow", controlName = "AllTimeButton", text = "All Time", x = 24, y = 84, width = 104, height = 26 },
	{ name = "MonthlyWindow", controlName = "MonthlyButton", text = "Monthly", x = 136, y = 84, width = 98, height = 26 },
	{ name = "WeeklyWindow", controlName = "WeeklyButton", text = "Weekly", x = 242, y = 84, width = 92, height = 26 },
	{ name = "DailyWindow", controlName = "DailyButton", text = "Daily", x = 342, y = 84, width = 84, height = 26 },
}
local LEADERBOARD_MASTER_CATEGORY_TABS = {
	{ name = "LevelsTab", controlName = "LevelsButton", text = "All Levels", key = "Levels", x = 24, y = 118, width = 128, height = 26 },
	{ name = "RunsTab", controlName = "RunsButton", text = "Runs", key = "Runs", x = 164, y = 118, width = 98, height = 26 },
	{ name = "KillsTab", controlName = "KillsButton", text = "Kills", key = "Kills", x = 278, y = 118, width = 98, height = 26 },
}
local LEADERBOARD_MASTER_SCROLL_BUTTONS = {
	{ name = "ScrollUpButton", x = 556, y = 182, width = 32, height = 78 },
	{ name = "ScrollDownButton", x = 556, y = 264, width = 32, height = 78 },
}

local function attachLeaderboardMasterBoard(part: BasePart, animatedBoardEffects)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = LEADERBOARD_MASTER_PPS
	gui.LightInfluence = 1
	gui.AlwaysOnTop = false
	gui.Active = true
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.BackgroundColor3 = Color3.fromRGB(244, 241, 232)
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui

	local frameGradient = Instance.new("UIGradient")
	frameGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(252, 249, 242)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(242, 238, 228)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(232, 226, 214)),
	})
	frameGradient.Rotation = 90
	frameGradient.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(96, 78, 54)
	stroke.Thickness = 2
	stroke.Transparency = 0.1
	stroke.Parent = frame

	local topSheen = Instance.new("Frame")
	topSheen.Name = "TopSheen"
	topSheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	topSheen.BackgroundTransparency = 0.78
	topSheen.BorderSizePixel = 0
	topSheen.Position = UDim2.fromOffset(0, 0)
	topSheen.Size = UDim2.new(1, 0, 0, 34)
	topSheen.Parent = frame

	local topSheenGradient = Instance.new("UIGradient")
	topSheenGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	topSheenGradient.Rotation = 90
	topSheenGradient.Parent = topSheen

	local accentChip = Instance.new("Frame")
	accentChip.Name = "AccentChip"
	accentChip.BackgroundColor3 = Color3.fromRGB(202, 168, 76)
	accentChip.BackgroundTransparency = 0
	accentChip.BorderSizePixel = 0
	accentChip.Position = UDim2.fromOffset(28, 18)
	accentChip.Size = UDim2.fromOffset(8, 30)
	accentChip.Parent = frame

	local accentGlow = Instance.new("Frame")
	accentGlow.Name = "AccentGlow"
	accentGlow.BackgroundColor3 = Color3.fromRGB(232, 214, 156)
	accentGlow.BackgroundTransparency = 0.72
	accentGlow.BorderSizePixel = 0
	accentGlow.Position = UDim2.fromOffset(24, 14)
	accentGlow.Size = UDim2.fromOffset(16, 38)
	accentGlow.Parent = frame

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(44, 18)
	header.Size = UDim2.new(1, -72, 0, 30)
	header.Font = Enum.Font.GothamBlack
	header.Text = "Top Operators"
	header.TextColor3 = Color3.fromRGB(44, 34, 18)
	header.TextSize = 26
	header.TextXAlignment = Enum.TextXAlignment.Center
	header.Parent = frame

	local subheader = Instance.new("TextLabel")
	subheader.Name = "Subheader"
	subheader.BackgroundTransparency = 1
	subheader.Position = UDim2.fromOffset(24, 56)
	subheader.Size = UDim2.new(1, -168, 0, 18)
	subheader.Font = Enum.Font.GothamBold
	subheader.Text = "GLOBAL ALL-TIME • TOP 100"
	subheader.TextColor3 = Color3.fromRGB(96, 78, 54)
	subheader.TextSize = 14
	subheader.TextXAlignment = Enum.TextXAlignment.Left
	subheader.Parent = frame

	local countdown = Instance.new("TextLabel")
	countdown.Name = "Countdown"
	countdown.BackgroundTransparency = 1
	countdown.Position = UDim2.new(1, -164, 0, 52)
	countdown.Size = UDim2.fromOffset(136, 20)
	countdown.Font = Enum.Font.GothamBlack
	countdown.Text = "REFRESH IN 60s"
	countdown.TextColor3 = Color3.fromRGB(88, 82, 70)
	countdown.TextSize = 14
	countdown.TextXAlignment = Enum.TextXAlignment.Right
	countdown.Parent = frame

	for _, info in ipairs(LEADERBOARD_MASTER_WINDOW_BUTTONS) do
		local button = Instance.new("TextLabel")
		button.Name = info.name
		button.BackgroundColor3 = Color3.fromRGB(228, 224, 214)
		button.BackgroundTransparency = 0
		button.BorderSizePixel = 0
		button.Position = UDim2.fromOffset(info.x, info.y)
		button.Size = UDim2.fromOffset(info.width, info.height)
		button.Font = Enum.Font.GothamBold
		button.Text = info.text
		button.TextColor3 = Color3.fromRGB(58, 48, 34)
		button.TextSize = 14
		button.Parent = frame

		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 8)
		buttonCorner.Parent = button

		local buttonStroke = Instance.new("UIStroke")
		buttonStroke.Name = "Stroke"
		buttonStroke.Color = Color3.fromRGB(168, 154, 132)
		buttonStroke.Transparency = 0.28
		buttonStroke.Parent = button
	end

	for _, info in ipairs(LEADERBOARD_MASTER_CATEGORY_TABS) do
		local tab = Instance.new("TextLabel")
		tab.Name = info.name
		tab.BackgroundColor3 = Color3.fromRGB(228, 224, 214)
		tab.BackgroundTransparency = 0
		tab.BorderSizePixel = 0
		tab.Position = UDim2.fromOffset(info.x, info.y)
		tab.Size = UDim2.fromOffset(info.width, info.height)
		tab.Font = Enum.Font.GothamBold
		tab.Text = info.text
		tab.TextColor3 = Color3.fromRGB(58, 48, 34)
		tab.TextSize = 14
		tab.Parent = frame

		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = UDim.new(0, 8)
		tabCorner.Parent = tab

		local tabStroke = Instance.new("UIStroke")
		tabStroke.Name = "Stroke"
		tabStroke.Color = Color3.fromRGB(168, 154, 132)
		tabStroke.Transparency = 0.28
		tabStroke.Parent = tab

		if animatedBoardEffects then
			table.insert(animatedBoardEffects, {
				type = "leaderboardTab",
				frame = tab,
				stroke = tabStroke,
				board = frame,
				categoryKey = info.key,
			})
		end
	end

	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BackgroundColor3 = Color3.fromRGB(210, 184, 108)
	rule.BackgroundTransparency = 0.08
	rule.BorderSizePixel = 0
	rule.Position = UDim2.fromOffset(24, 152)
	rule.Size = UDim2.new(1, -48, 0, 2)
	rule.Parent = frame

	local headerRow = Instance.new("TextLabel")
	headerRow.Name = "ListHeader"
	headerRow.BackgroundTransparency = 1
	headerRow.Position = UDim2.fromOffset(24, 160)
	headerRow.Size = UDim2.new(1, -48, 0, 18)
	headerRow.Font = Enum.Font.GothamBold
	headerRow.Text = "#   Username                              Score"
	headerRow.TextColor3 = Color3.fromRGB(40, 38, 34)
	headerRow.TextSize = 14
	headerRow.TextXAlignment = Enum.TextXAlignment.Left
	headerRow.Parent = frame

	for index = 0, 4 do
		local slot = Instance.new("Frame")
		slot.Name = "RankSlot" .. tostring(index + 1)
		slot.BackgroundColor3 = index % 2 == 0 and Color3.fromRGB(248, 246, 240) or Color3.fromRGB(238, 234, 226)
		slot.BackgroundTransparency = 0.16
		slot.BorderSizePixel = 0
		slot.Position = UDim2.fromOffset(18, 184 + (index * 90))
		slot.Size = UDim2.new(1, -36, 0, 74)
		slot.Parent = frame

		local slotStroke = Instance.new("UIStroke")
		slotStroke.Color = Color3.fromRGB(194, 186, 170)
		slotStroke.Transparency = 0.58
		slotStroke.Thickness = 1
		slotStroke.Parent = slot
	end

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "BodyScroll"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(24, 182)
	scroll.Size = UDim2.new(1, -48, 1, -198)
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = Color3.fromRGB(168, 156, 132)
	scroll.Active = true
	scroll.Parent = frame

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(10, 6)
	body.Size = UDim2.new(1, -20, 0, 1200)
	body.Font = Enum.Font.GothamMedium
	body.Text = "Loading..."
	body.RichText = true
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextColor3 = Color3.fromRGB(38, 36, 32)
	body.TextSize = 18
	body.Parent = scroll

		local bodyGradient = Instance.new("UIGradient")
	bodyGradient.Name = "Flow"
	bodyGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 44, 36)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(108, 92, 64)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 44, 36)),
	})
	bodyGradient.Rotation = 90
	bodyGradient.Parent = body

	local countdownGradient = Instance.new("UIGradient")
	countdownGradient.Name = "Flow"
	countdownGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(130, 116, 88)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(210, 184, 108)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 116, 88)),
	})
	countdownGradient.Parent = countdown

	if animatedBoardEffects then
		table.insert(animatedBoardEffects, {
			type = "leaderboardUiFlow",
			gradient = bodyGradient,
			phase = 0.4,
		})
		table.insert(animatedBoardEffects, {
			type = "leaderboardUiFlow",
			gradient = countdownGradient,
			phase = 1.2,
		})
	end

	frame:SetAttribute("ActiveCategory", "Levels")
	frame:SetAttribute("ActiveWindow", "allTime")
end

local function teleportPlayerToPart(player, targetPart: BasePart, offset: Vector3?)
	local character = player.Character
	if not character or not character.Parent then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		rootPart = character:WaitForChild("HumanoidRootPart", 2)
	end
	if not rootPart then
		return
	end

	local lift = offset or Vector3.new(0, 4, 0)
	character:PivotTo(targetPart.CFrame + lift)
end

local function addTeleportPrompt(parent: Instance, name: string, actionText: string, objectText: string, destination: BasePart, offset: Vector3?, maxDistance: number?)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = maxDistance or 12
	prompt.Parent = parent

	prompt.Triggered:Connect(function(player)
		teleportPlayerToPart(player, destination, offset)
	end)

	return prompt
end

local function addTravelPad(root: Instance, name: string, position: Vector3, palette, destination: BasePart?, actionText: string, objectText: string, subtitle: string?, offset: Vector3?)
	local node = Instance.new("Model")
	node.Name = name
	node.Parent = root
	local transitStyle = palette.TransitStyle or "default"

	local base = makePart(
		node,
		"Part",
		"Base",
		Vector3.new(14, 0.8, 10),
		CFrame.new(position),
		palette.Color:Lerp(Color3.fromRGB(58, 64, 72), 0.5),
		Enum.Material.Metal
	)
	base.CanQuery = false

	local trim = makeGlowPart(
		node,
		"Trim",
		Vector3.new(14, 0.12, 10),
		CFrame.new(position + Vector3.new(0, 0.48, 0)),
		palette.Accent,
		0.82
	)
	trim.CanCollide = false
	trim.CanQuery = false

	local pad = makePart(
		node,
		"Part",
		"Pad",
		Vector3.new(8, 0.24, 5.4),
		CFrame.new(position + Vector3.new(0, 0.56, -1.4)),
		palette.Accent:Lerp(Color3.fromRGB(236, 242, 248), 0.2),
		Enum.Material.Metal
	)
	pad.CanCollide = false
	pad.CanQuery = false

	local sign = makePart(
		node,
		"Part",
		"Sign",
		Vector3.new(10, 0.8, 0.5),
		CFrame.new(position + Vector3.new(0, 3.2, 3.8)),
		Color3.fromRGB(44, 50, 58),
		Enum.Material.Metal
	)
	sign.CanCollide = false
	sign.CanQuery = false

	attachLabel(sign, actionText:upper(), subtitle or objectText, palette.Accent)
	attachWorldText(pad, actionText:upper(), Vector3.new(0, 1.95, 0), palette.Accent, Vector2.new(110, 24))

	if transitStyle == "training" then
		local lane = makeGlowPart(
			node,
			"TrainingLane",
			Vector3.new(3.2, 0.08, 12),
			CFrame.new(position + Vector3.new(0, 0.7, 0)),
			Color3.fromRGB(244, 218, 154),
			0.8
		)
		lane.CanCollide = false
		lane.CanQuery = false
		for _, x in ipairs({ -5.2, 5.2 }) do
			local rail = makePart(
				node,
				"Part",
				"TrainingRail",
				Vector3.new(0.8, 2.6, 10),
				CFrame.new(position + Vector3.new(x, 1.34, 0)),
				Color3.fromRGB(126, 108, 74),
				Enum.Material.Metal
			)
			rail.CanQuery = false
		end
	elseif transitStyle == "combat" then
		local spine = makePart(
			node,
			"Part",
			"CombatSpine",
			Vector3.new(2.2, 1.6, 11),
			CFrame.new(position + Vector3.new(0, 1.02, 0)),
			Color3.fromRGB(58, 64, 70),
			Enum.Material.Metal
		)
		spine.CanQuery = false
		local stripe = makeGlowPart(
			node,
			"CombatStripe",
			Vector3.new(1.2, 0.08, 11),
			spine.CFrame * CFrame.new(0, 0.86, 0),
			Color3.fromRGB(255, 186, 114),
			0.74
		)
		stripe.CanCollide = false
		stripe.CanQuery = false
	elseif transitStyle == "salvage" then
		local corridor = makePart(
			node,
			"Part",
			"SalvageCorridor",
			Vector3.new(10, 0.2, 16),
			CFrame.new(position + Vector3.new(0, 0.54, 1)),
			Color3.fromRGB(112, 98, 76),
			Enum.Material.DiamondPlate
		)
		corridor.CanCollide = false
		corridor.CanQuery = false
		local guide = makeGlowPart(
			node,
			"SalvageGuide",
			Vector3.new(2.2, 0.08, 14),
			CFrame.new(position + Vector3.new(0, 0.66, 1)),
			Color3.fromRGB(236, 216, 166),
			0.8
		)
		guide.CanCollide = false
		guide.CanQuery = false
	elseif transitStyle == "deploy" then
		local apron = makePart(
			node,
			"Part",
			"DeployApron",
			Vector3.new(16, 0.2, 12),
			CFrame.new(position + Vector3.new(0, 0.56, 0)),
			Color3.fromRGB(118, 78, 78),
			Enum.Material.Metal
		)
		apron.CanCollide = false
		apron.CanQuery = false
		for _, x in ipairs({ -6.2, 6.2 }) do
			local pylon = makePart(
				node,
				"Part",
				"DeployPylon",
				Vector3.new(1, 3.2, 1),
				CFrame.new(position + Vector3.new(x, 1.74, 2.6)),
				Color3.fromRGB(92, 58, 58),
				Enum.Material.Metal
			)
			pylon.CanQuery = false
		end
	end

	if destination then
		addTeleportPrompt(pad, name .. "Prompt", actionText, objectText, destination, offset or Vector3.new(0, 4, 0), 14)
	end

	return node
end

local function makeTrainingYard(root: Instance, worldPosition: Vector3, palette, lobbyReturnPart: BasePart?)
	local yard = Instance.new("Model")
	yard.Name = "TrainingYard"
	yard.Parent = root

	local base = makePart(yard, "Part", "Base", Vector3.new(40, 1, 34), CFrame.new(worldPosition), palette.Color:Lerp(Color3.fromRGB(58, 64, 72), 0.58), Enum.Material.Metal)
	base.CanQuery = false
	yard.PrimaryPart = base

	local ring = makeGlowPart(yard, "BaseTrim", Vector3.new(40, 0.14, 34), CFrame.new(worldPosition + Vector3.new(0, 0.72, 0)), palette.Accent, 0.9)
	ring.CanCollide = false
	ring.CanQuery = false

	local backWall = makePart(yard, "Part", "BackWall", Vector3.new(32, 8, 2), CFrame.new(worldPosition + Vector3.new(0, 4, 12)), Color3.fromRGB(48, 54, 62), Enum.Material.Metal)
	backWall.CanQuery = false
	local leftFence = makePart(yard, "Part", "LeftFence", Vector3.new(2, 6, 24), CFrame.new(worldPosition + Vector3.new(-15, 3, -2)), Color3.fromRGB(64, 70, 80), Enum.Material.Metal)
	leftFence.CanQuery = false
	local rightFence = makePart(yard, "Part", "RightFence", Vector3.new(2, 6, 24), CFrame.new(worldPosition + Vector3.new(15, 3, -2)), Color3.fromRGB(64, 70, 80), Enum.Material.Metal)
	rightFence.CanQuery = false

	local entryPad = makePart(yard, "Part", "EntryPad", Vector3.new(10, 0.28, 8), CFrame.new(worldPosition + Vector3.new(0, 0.86, -11)), palette.Accent:Lerp(Color3.fromRGB(255, 244, 220), 0.25), Enum.Material.Metal)
	entryPad.CanCollide = false
	entryPad.CanQuery = false
	makeGlowPart(yard, "EntryGlow", Vector3.new(6, 0.08, 2.6), entryPad.CFrame * CFrame.new(0, 0.16, 0), palette.Accent, 0.58)

	for lane = -1, 1 do
		local laneX = lane * 8
		local strip = makePart(yard, "Part", "LaneStrip" .. tostring(lane + 2), Vector3.new(5.6, 0.08, 22), CFrame.new(worldPosition + Vector3.new(laneX, 0.95, -1)), palette.Accent, Enum.Material.Neon)
		strip.Transparency = 0.84
		strip.CanCollide = false
		strip.CanQuery = false

		local target = makePart(yard, "Part", "TargetColumn" .. tostring(lane + 2), Vector3.new(2.8, 5.4, 2.8), CFrame.new(worldPosition + Vector3.new(laneX, 2.7, 8.6)), Color3.fromRGB(72, 78, 88), Enum.Material.Metal)
		target.CanQuery = false
		local targetFace = makeGlowPart(yard, "TargetFace" .. tostring(lane + 2), Vector3.new(2.2, 2.2, 0.18), target.CFrame * CFrame.new(0, 0.4, -1.32), palette.Accent, 0.24)
		targetFace.CanCollide = false
		targetFace.CanQuery = false

		local hurdle = makePart(yard, "Part", "Hurdle" .. tostring(lane + 2), Vector3.new(4.8, 1.2, 0.8), CFrame.new(worldPosition + Vector3.new(laneX, 1.2, -5.8)), Color3.fromRGB(96, 82, 58), Enum.Material.WoodPlanks)
		hurdle.CanQuery = false
	end

	local benchLeft = makePart(yard, "Part", "BenchLeft", Vector3.new(6, 1.2, 2), CFrame.new(worldPosition + Vector3.new(-10.4, 1.2, 12.4)), Color3.fromRGB(98, 82, 58), Enum.Material.WoodPlanks)
	benchLeft.CanQuery = false
	local benchRight = makePart(yard, "Part", "BenchRight", Vector3.new(6, 1.2, 2), CFrame.new(worldPosition + Vector3.new(10.4, 1.2, 12.4)), Color3.fromRGB(98, 82, 58), Enum.Material.WoodPlanks)
	benchRight.CanQuery = false

	local returnPad = makePart(yard, "Part", "ReturnPad", Vector3.new(8, 0.24, 6), CFrame.new(worldPosition + Vector3.new(0, 0.84, 13.4)), Color3.fromRGB(70, 76, 84), Enum.Material.Metal)
	returnPad.CanCollide = false
	returnPad.CanQuery = false

	attachLabel(backWall, "TRAINING YARD", "Warm up movement and range control", palette.Accent)
	attachWorldText(entryPad, "TRAIN", Vector3.new(0, 2.2, 0), palette.Accent, Vector2.new(116, 28))
	attachWorldText(returnPad, "RETURN", Vector3.new(0, 2.1, 0), Color3.fromRGB(224, 232, 242), Vector2.new(110, 26))

	addTeleportPrompt(entryPad, "TrainingEnterPrompt", "Train", "Training Yard", entryPad, Vector3.new(0, 4, 6), 14)
	addTeleportPrompt(returnPad, "TrainingReturnPrompt", "Return", "Main Plaza", lobbyReturnPart or base, Vector3.new(0, 4, 0), 14)

	return yard
end

local function makeParkourCourse(root: Instance, worldPosition: Vector3, palette, lobbyReturnPart: BasePart?)
	local course = Instance.new("Model")
	course.Name = "ParkourCourse"
	course.Parent = root

	local base = makePart(course, "Part", "Base", Vector3.new(44, 1, 28), CFrame.new(worldPosition), palette.Color:Lerp(Color3.fromRGB(54, 60, 72), 0.62), Enum.Material.Metal)
	base.CanQuery = false
	course.PrimaryPart = base

	local trim = makeGlowPart(course, "BaseTrim", Vector3.new(44, 0.14, 28), CFrame.new(worldPosition + Vector3.new(0, 0.72, 0)), palette.Accent, 0.9)
	trim.CanCollide = false
	trim.CanQuery = false

	local startPad = makePart(course, "Part", "StartPad", Vector3.new(10, 0.28, 8), CFrame.new(worldPosition + Vector3.new(-14, 0.86, -8)), palette.Accent:Lerp(Color3.fromRGB(232, 240, 255), 0.18), Enum.Material.Metal)
	startPad.CanCollide = false
	startPad.CanQuery = false
	local returnPad = makePart(course, "Part", "ReturnPad", Vector3.new(8, 0.24, 6), CFrame.new(worldPosition + Vector3.new(16, 0.84, 8)), Color3.fromRGB(70, 76, 84), Enum.Material.Metal)
	returnPad.CanCollide = false
	returnPad.CanQuery = false

	for index, info in ipairs({
		{ Vector3.new(-6, 2, -2), Vector3.new(8, 1, 8) },
		{ Vector3.new(4, 4, -6), Vector3.new(7, 1, 7) },
		{ Vector3.new(13, 6, 0), Vector3.new(7, 1, 7) },
		{ Vector3.new(2, 8, 8), Vector3.new(6, 1, 6) },
		{ Vector3.new(-10, 10, 4), Vector3.new(6, 1, 6) },
	}) do
		local platform = makePart(course, "Part", "Platform" .. tostring(index), info[2], CFrame.new(worldPosition + info[1]), Color3.fromRGB(82, 90, 104), Enum.Material.DiamondPlate)
		platform.CanQuery = false
		makeGlowPart(course, "PlatformGlow" .. tostring(index), Vector3.new(info[2].X + 0.4, 0.08, info[2].Z + 0.4), platform.CFrame * CFrame.new(0, 0.54, 0), palette.Accent, 0.7)
	end

	local finishTower = makePart(course, "Part", "FinishTower", Vector3.new(8, 12, 8), CFrame.new(worldPosition + Vector3.new(-16, 6, 10)), Color3.fromRGB(60, 66, 82), Enum.Material.Metal)
	finishTower.CanQuery = false
	local finishPad = makePart(course, "Part", "FinishPad", Vector3.new(8, 1, 8), finishTower.CFrame * CFrame.new(0, 6.5, 0), Color3.fromRGB(92, 106, 146), Enum.Material.DiamondPlate)
	finishPad.CanQuery = false
	makeGlowPart(course, "FinishGlow", Vector3.new(8.4, 0.08, 8.4), finishPad.CFrame * CFrame.new(0, 0.54, 0), palette.Accent, 0.56)

	attachLabel(finishTower, "PARKOUR LINE", "Run the blocks and claim the roof", palette.Accent)
	attachWorldText(startPad, "START", Vector3.new(0, 2.1, 0), palette.Accent, Vector2.new(110, 26))
	attachWorldText(returnPad, "RETURN", Vector3.new(0, 2.1, 0), Color3.fromRGB(224, 232, 242), Vector2.new(110, 26))

	addTeleportPrompt(startPad, "ParkourStartPrompt", "Run Course", "Parkour Line", startPad, Vector3.new(0, 4, 0), 14)
	addTeleportPrompt(returnPad, "ParkourReturnPrompt", "Return", "Main Plaza", lobbyReturnPart or base, Vector3.new(0, 4, 0), 14)

	return course
end

local function makeDuelRing(root: Instance, worldPosition: Vector3, palette)
	local ring = Instance.new("Model")
	ring.Name = "DuelRing"
	ring.Parent = root

	local base = makePart(ring, "Part", "Base", Vector3.new(38, 1, 38), CFrame.new(worldPosition), palette.Color:Lerp(Color3.fromRGB(58, 62, 70), 0.62), Enum.Material.Metal)
	base.CanQuery = false
	ring.PrimaryPart = base

	local platform = makePart(ring, "Part", "RingPlatform", Vector3.new(24, 1.4, 24), CFrame.new(worldPosition + Vector3.new(0, 1.2, 0)), Color3.fromRGB(76, 78, 86), Enum.Material.DiamondPlate)
	platform.CanQuery = false
	local platformGlow = makeGlowPart(ring, "RingGlow", Vector3.new(24.4, 0.12, 24.4), platform.CFrame * CFrame.new(0, 0.76, 0), palette.Accent, 0.72)
	platformGlow.CanCollide = false
	platformGlow.CanQuery = false

	for _, offset in ipairs({
		Vector3.new(-10.8, 4.2, -10.8),
		Vector3.new(10.8, 4.2, -10.8),
		Vector3.new(-10.8, 4.2, 10.8),
		Vector3.new(10.8, 4.2, 10.8),
	}) do
		local post = makePart(ring, "Part", "CornerPost", Vector3.new(1.4, 6.4, 1.4), CFrame.new(worldPosition + offset), Color3.fromRGB(84, 88, 96), Enum.Material.Metal)
		post.CanQuery = false
		makeGlowPart(ring, "CornerLamp", Vector3.new(1.8, 0.14, 1.8), post.CFrame * CFrame.new(0, 3.18, 0), palette.Accent, 0.42)
	end

	for _, info in ipairs({
		{ "North", Vector3.new(0, 4.8, -10.8), Vector3.new(22, 0.28, 0.4) },
		{ "South", Vector3.new(0, 4.8, 10.8), Vector3.new(22, 0.28, 0.4) },
		{ "West", Vector3.new(-10.8, 4.8, 0), Vector3.new(0.4, 0.28, 22) },
		{ "East", Vector3.new(10.8, 4.8, 0), Vector3.new(0.4, 0.28, 22) },
	}) do
		local rope = makePart(ring, "Part", info[1] .. "Rope", info[3], CFrame.new(worldPosition + info[2]), palette.Accent, Enum.Material.Neon)
		rope.Transparency = 0.3
		rope.CanCollide = false
		rope.CanQuery = false
	end

	local redCorner = makePart(ring, "Part", "RedCornerPad", Vector3.new(7, 0.24, 7), CFrame.new(worldPosition + Vector3.new(-7.2, 2.02, 7.2)), Color3.fromRGB(148, 82, 82), Enum.Material.Metal)
	redCorner.CanCollide = false
	redCorner.CanQuery = false
	local blueCorner = makePart(ring, "Part", "BlueCornerPad", Vector3.new(7, 0.24, 7), CFrame.new(worldPosition + Vector3.new(7.2, 2.02, -7.2)), Color3.fromRGB(82, 108, 162), Enum.Material.Metal)
	blueCorner.CanCollide = false
	blueCorner.CanQuery = false
	local returnPad = makePart(ring, "Part", "ReturnPad", Vector3.new(8, 0.24, 6), CFrame.new(worldPosition + Vector3.new(0, 0.84, 14.4)), Color3.fromRGB(70, 76, 84), Enum.Material.Metal)
	returnPad.CanCollide = false
	returnPad.CanQuery = false

	local banner = makePart(ring, "Part", "Banner", Vector3.new(14, 1.2, 0.6), CFrame.new(worldPosition + Vector3.new(0, 7.4, 12.8)), Color3.fromRGB(82, 44, 44), Enum.Material.Metal)
	banner.CanCollide = false
	banner.CanQuery = false
	attachLabel(banner, "DUEL RING", "Stage 1v1s and settle bragging rights", palette.Accent)
	attachWorldText(redCorner, "RED", Vector3.new(0, 2.1, 0), Color3.fromRGB(255, 194, 194), Vector2.new(88, 24))
	attachWorldText(blueCorner, "BLUE", Vector3.new(0, 2.1, 0), Color3.fromRGB(198, 218, 255), Vector2.new(88, 24))
	attachWorldText(returnPad, "RETURN", Vector3.new(0, 2.1, 0), Color3.fromRGB(224, 232, 242), Vector2.new(110, 26))

	local redPrompt = Instance.new("ProximityPrompt")
	redPrompt.Name = "DuelRedPrompt"
	redPrompt.ActionText = "Enter Red Corner"
	redPrompt.ObjectText = "Duel Ring"
	redPrompt.KeyboardKeyCode = Enum.KeyCode.E
	redPrompt.HoldDuration = 0
	redPrompt.RequiresLineOfSight = false
	redPrompt.MaxActivationDistance = 14
	redPrompt:SetAttribute("DuelAction", "red")
	redPrompt.Parent = redCorner

	local bluePrompt = Instance.new("ProximityPrompt")
	bluePrompt.Name = "DuelBluePrompt"
	bluePrompt.ActionText = "Enter Blue Corner"
	bluePrompt.ObjectText = "Duel Ring"
	bluePrompt.KeyboardKeyCode = Enum.KeyCode.E
	bluePrompt.HoldDuration = 0
	bluePrompt.RequiresLineOfSight = false
	bluePrompt.MaxActivationDistance = 14
	bluePrompt:SetAttribute("DuelAction", "blue")
	bluePrompt.Parent = blueCorner

	local returnPrompt = Instance.new("ProximityPrompt")
	returnPrompt.Name = "DuelReturnPrompt"
	returnPrompt.ActionText = "Return"
	returnPrompt.ObjectText = "Main Plaza"
	returnPrompt.KeyboardKeyCode = Enum.KeyCode.E
	returnPrompt.HoldDuration = 0
	returnPrompt.RequiresLineOfSight = false
	returnPrompt.MaxActivationDistance = 14
	returnPrompt:SetAttribute("DuelAction", "leave")
	returnPrompt.Parent = returnPad

	return ring
end

local function makeTargetRange(root: Instance, worldPosition: Vector3, palette, lobbyReturnPart: BasePart?)
	local range = Instance.new("Model")
	range.Name = "TargetRange"
	range.Parent = root

	local base = makePart(range, "Part", "Base", Vector3.new(42, 1, 30), CFrame.new(worldPosition), palette.Color:Lerp(Color3.fromRGB(54, 62, 60), 0.62), Enum.Material.Metal)
	base.CanQuery = false
	range.PrimaryPart = base

	local trim = makeGlowPart(range, "BaseTrim", Vector3.new(42, 0.14, 30), CFrame.new(worldPosition + Vector3.new(0, 0.72, 0)), palette.Accent, 0.9)
	trim.CanCollide = false
	trim.CanQuery = false

	local firingLine = makePart(range, "Part", "FiringLine", Vector3.new(22, 0.24, 4), CFrame.new(worldPosition + Vector3.new(0, 0.86, -9)), palette.Accent:Lerp(Color3.fromRGB(236, 246, 240), 0.2), Enum.Material.Metal)
	firingLine.CanCollide = false
	firingLine.CanQuery = false
	local returnPad = makePart(range, "Part", "ReturnPad", Vector3.new(8, 0.24, 6), CFrame.new(worldPosition + Vector3.new(0, 0.84, 11.4)), Color3.fromRGB(70, 76, 84), Enum.Material.Metal)
	returnPad.CanCollide = false
	returnPad.CanQuery = false

	for lane = -1, 1 do
		local laneX = lane * 10
		local barrier = makePart(range, "Part", "Barrier" .. tostring(lane + 2), Vector3.new(6, 3, 2), CFrame.new(worldPosition + Vector3.new(laneX, 1.5, -2)), Color3.fromRGB(92, 84, 70), Enum.Material.WoodPlanks)
		barrier.CanQuery = false
		local targetBack = makePart(range, "Part", "TargetBack" .. tostring(lane + 2), Vector3.new(4, 6, 1.2), CFrame.new(worldPosition + Vector3.new(laneX, 3, 10)), Color3.fromRGB(54, 62, 66), Enum.Material.Metal)
		targetBack.CanQuery = false
		local targetFace = makeGlowPart(range, "TargetFace" .. tostring(lane + 2), Vector3.new(2.8, 2.8, 0.18), targetBack.CFrame * CFrame.new(0, 0, -0.7), palette.Accent, 0.3)
		targetFace.CanCollide = false
		targetFace.CanQuery = true
	end

	local sign = makePart(range, "Part", "Sign", Vector3.new(16, 1.2, 0.6), CFrame.new(worldPosition + Vector3.new(0, 7.4, 13.2)), Color3.fromRGB(56, 82, 72), Enum.Material.Metal)
	sign.CanCollide = false
	sign.CanQuery = false
	attachLabel(sign, "TARGET RANGE", "Dial in aim and test recoil control", palette.Accent)
	attachWorldText(firingLine, "RANGE", Vector3.new(0, 2.1, 0), palette.Accent, Vector2.new(112, 26))
	attachWorldText(returnPad, "RETURN", Vector3.new(0, 2.1, 0), Color3.fromRGB(224, 232, 242), Vector2.new(110, 26))

	addTeleportPrompt(firingLine, "TargetRangePrompt", "Enter Range", "Target Range", firingLine, Vector3.new(0, 4, 0), 14)
	addTeleportPrompt(returnPad, "TargetRangeReturnPrompt", "Return", "Main Plaza", lobbyReturnPart or base, Vector3.new(0, 4, 0), 14)

	return range
end

local function makeSalvageRun(root: Instance, worldPosition: Vector3, palette, lobbyReturnPart: BasePart?)
	local run = Instance.new("Model")
	run.Name = "SalvageRun"
	run.Parent = root

	local base = makePart(run, "Part", "Base", Vector3.new(28, 0.7, 14), CFrame.new(worldPosition), palette.Color:Lerp(Color3.fromRGB(56, 60, 66), 0.62), Enum.Material.Metal)
	base.CanQuery = false
	run.PrimaryPart = base

	local trim = makeGlowPart(run, "BaseTrim", Vector3.new(28, 0.12, 14), CFrame.new(worldPosition + Vector3.new(0, 0.48, 0)), palette.Accent, 0.9)
	trim.CanCollide = false
	trim.CanQuery = false

	local startPad = makePart(run, "Part", "StartPad", Vector3.new(7, 0.24, 5), CFrame.new(worldPosition + Vector3.new(0, 0.58, -4.2)), palette.Accent:Lerp(Color3.fromRGB(246, 234, 210), 0.22), Enum.Material.Metal)
	startPad.CanCollide = false
	startPad.CanQuery = false

	local finishPad = makePart(run, "Part", "FinishPad", Vector3.new(7, 0.22, 5), CFrame.new(worldPosition + Vector3.new(0, 0.56, 4.2)), Color3.fromRGB(88, 94, 104), Enum.Material.Metal)
	finishPad.CanCollide = false
	finishPad.CanQuery = false

	local nodeOffsets = {
		Vector3.new(-8, 0.95, -0.8),
		Vector3.new(8, 0.95, 0),
		Vector3.new(0, 0.95, 2.1),
	}
	for index, offset in ipairs(nodeOffsets) do
		local crate = makePart(run, "Part", "Cache" .. tostring(index), Vector3.new(2.8, 1.9, 2.8), CFrame.new(worldPosition + offset), Color3.fromRGB(108, 84, 58), Enum.Material.WoodPlanks)
		crate.CanQuery = false
		makeGlowPart(run, "CacheGlow" .. tostring(index), Vector3.new(3.1, 0.08, 3.1), crate.CFrame * CFrame.new(0, 1.08, 0), palette.Accent, 0.7)
	end

	local sign = makePart(run, "Part", "Sign", Vector3.new(8, 0.7, 0.5), CFrame.new(worldPosition + Vector3.new(-9.2, 2.8, 0)), Color3.fromRGB(82, 62, 42), Enum.Material.Metal)
	sign.CanCollide = false
	sign.CanQuery = false
	attachLabel(sign, "SALVAGE RUN", "Recover bunker caches before the timer burns out", palette.Accent)
	attachWorldText(startPad, "START", Vector3.new(0, 1.75, 0), palette.Accent, Vector2.new(96, 24))
	attachWorldText(finishPad, "EXTRACT", Vector3.new(0, 1.75, 0), Color3.fromRGB(224, 232, 242), Vector2.new(100, 24))

	addTeleportPrompt(startPad, "SalvageStartPrompt", "Start Run", "Salvage Run", startPad, Vector3.new(0, 4, 0), 14)
	addTeleportPrompt(finishPad, "SalvageReturnPrompt", "Return", "Main Plaza", lobbyReturnPart or base, Vector3.new(0, 4, 0), 14)

	return run
end

local function makePathSegment(parent: Instance, name: string, startPosition: Vector3, endPosition: Vector3, color: Color3)
	local delta = endPosition - startPosition
	local distance = delta.Magnitude
	if distance <= 0.01 then
		return
	end

	local midpoint = startPosition:Lerp(endPosition, 0.5)
	local segment = makePart(
		parent,
		"Part",
		name,
		Vector3.new(2.6, 0.1, distance),
		CFrame.lookAt(midpoint, endPosition) * CFrame.new(0, 0.2, 0),
		color,
		Enum.Material.Neon
	)
	segment.Transparency = 0.82
	segment.CanCollide = false
	segment.CanQuery = false

	local lane = makePart(
		parent,
		"Part",
		name .. "Lane",
		Vector3.new(5.8, 0.06, distance),
		CFrame.lookAt(midpoint, endPosition) * CFrame.new(0, 0.05, 0),
		color:Lerp(Color3.fromRGB(44, 50, 58), 0.5),
		Enum.Material.Metal
	)
	lane.Transparency = 0.9
	lane.CanCollide = false
	lane.CanQuery = false
end

local makeStation
local makeGuidePaths
local makeDeployPad

local function makeOpenSkyLobby(root: Instance, worldPosition: Vector3)
	local plaza = Instance.new("Model")
	plaza.Name = "OpenSkyLobby"
	plaza.Parent = root

	local beaconLights = {}
	local ambientActors = {}
	local animatedBoardEffects = {}

	local function addLamp(basePart: BasePart, offset: Vector3, color: Color3, brightness: number, range: number, transparency: number?)
		local lamp = makeGlowPart(
			plaza,
			basePart.Name .. "Lamp",
			Vector3.new(3.2, 0.18, 3.2),
			basePart.CFrame * CFrame.new(offset),
			color,
			transparency or 0.48
		)
		local light = Instance.new("PointLight")
		light.Range = range
		light.Brightness = brightness
		light.Color = color
		light.Parent = lamp
		table.insert(beaconLights, {
			part = lamp,
			light = light,
			baseCFrame = lamp.CFrame,
		})
		return lamp
	end

	local function addCargoStack(name: string, position: Vector3, accent: Color3)
		local stack = Instance.new("Model")
		stack.Name = name
		stack.Parent = plaza

		local base = makePart(
			stack,
			"Part",
			"Base",
			Vector3.new(18, 2.4, 12),
			CFrame.new(position + Vector3.new(0, 1.2, 0)),
			Color3.fromRGB(70, 78, 90),
			Enum.Material.Metal
		)
		base.CanQuery = false

		local top = makePart(
			stack,
			"Part",
			"Top",
			Vector3.new(14, 2.4, 10),
			CFrame.new(position + Vector3.new(0, 3.8, 0)),
			Color3.fromRGB(52, 58, 68),
			Enum.Material.Metal
		)
		top.CanQuery = false

		local strap = makeGlowPart(
			stack,
			"StatusStrip",
			Vector3.new(14.4, 0.14, 0.7),
			top.CFrame * CFrame.new(0, 1.28, -5.1),
			accent,
			0.46
		)
		strap.CanCollide = false
		strap.CanQuery = false
	end

	local function addLeaderboardMonument(position: Vector3)
		local monument = Instance.new("Model")
		monument.Name = "LeaderboardMonument"
		monument.Parent = plaza

		local plinth = makePart(monument, "Part", "Plinth", Vector3.new(64, 0.8, 18), CFrame.new(position + Vector3.new(0, 0.4, 0)), Color3.fromRGB(166, 154, 132), Enum.Material.WoodPlanks)
		plinth.CanQuery = false
		local base = makePart(monument, "Part", "Base", Vector3.new(56, 0.5, 12), CFrame.new(position + Vector3.new(0, 0.92, 0)), Color3.fromRGB(122, 96, 68), Enum.Material.WoodPlanks)
		base.CanQuery = false
		local baseGlow = makeGlowPart(monument, "BaseGlow", Vector3.new(56, 0.08, 12), base.CFrame * CFrame.new(0, 0.28, 0), Color3.fromRGB(214, 202, 176), 0.9)
		baseGlow.CanCollide = false
		baseGlow.CanQuery = false

		local approachPad = makePart(monument, "Part", "ApproachPad", Vector3.new(22, 0.32, 28), CFrame.new(position + Vector3.new(0, 0.18, 24)), Color3.fromRGB(170, 162, 146), Enum.Material.Concrete)
		approachPad.CanQuery = false
		local approachInset = makePart(monument, "Part", "ApproachInset", Vector3.new(14, 0.08, 20), CFrame.new(position + Vector3.new(0, 0.39, 24)), Color3.fromRGB(232, 228, 214), Enum.Material.SmoothPlastic)
		approachInset.CanQuery = false
		local centerStrip = makeGlowPart(monument, "CenterStrip", Vector3.new(3.6, 0.06, 20), CFrame.new(position + Vector3.new(0, 0.44, 24)), Color3.fromRGB(236, 224, 190), 0.88)
		centerStrip.CanCollide = false
		centerStrip.CanQuery = false
		table.insert(animatedBoardEffects, {
			type = "leaderPulse",
			part = centerStrip,
			baseTransparency = 0.88,
			baseColor = Color3.fromRGB(236, 224, 190),
			pulseColor = Color3.fromRGB(255, 244, 216),
			phase = 1.1,
		})

		local threshold = makePart(monument, "Part", "Threshold", Vector3.new(18, 0.22, 3.4), CFrame.new(position + Vector3.new(0, 0.52, 11.2)), Color3.fromRGB(122, 96, 68), Enum.Material.WoodPlanks)
		threshold.CanQuery = false
		local thresholdGlow = makeGlowPart(monument, "ThresholdGlow", Vector3.new(17, 0.06, 0.9), threshold.CFrame * CFrame.new(0, 0.15, -1.08), Color3.fromRGB(255, 236, 196), 0.82)
		thresholdGlow.CanCollide = false
		thresholdGlow.CanQuery = false
		table.insert(animatedBoardEffects, {
			type = "leaderPulse",
			part = thresholdGlow,
			baseTransparency = 0.82,
			baseColor = Color3.fromRGB(226, 208, 168),
			pulseColor = Color3.fromRGB(255, 242, 208),
			phase = 1.7,
		})

		local headerBand = makePart(monument, "Part", "HeaderBand", Vector3.new(42, 1.2, 2.4), CFrame.new(position + Vector3.new(0, 21.4, -2.6)), Color3.fromRGB(88, 62, 40), Enum.Material.WoodPlanks)
		headerBand.CanQuery = false
		local headerGlow = makeGlowPart(monument, "HeaderGlow", Vector3.new(36, 0.12, 1.1), headerBand.CFrame * CFrame.new(0, 0.38, 0.58), Color3.fromRGB(236, 214, 156), 0.84)
		headerGlow.CanCollide = false
		headerGlow.CanQuery = false
		local headerFill = Instance.new("PointLight")
		headerFill.Range = 36
		headerFill.Brightness = 0.48
		headerFill.Color = Color3.fromRGB(232, 214, 166)
		headerFill.Parent = headerGlow
		table.insert(animatedBoardEffects, {
			type = "leaderPulse",
			part = headerGlow,
			light = headerFill,
			baseTransparency = 0.7,
			baseColor = Color3.fromRGB(214, 196, 142),
			pulseColor = Color3.fromRGB(255, 230, 182),
			phase = 0.2,
		})

		local laneGlow = makeGlowPart(monument, "LaneGlow", Vector3.new(56, 0.08, 15.4), CFrame.new(position + Vector3.new(0, 1.72, 3.2)), Color3.fromRGB(138, 154, 186), 0.82)
		laneGlow.CanCollide = false
		laneGlow.CanQuery = false
		table.insert(animatedBoardEffects, {
			type = "leaderPulse",
			part = laneGlow,
			baseTransparency = 0.82,
			baseColor = Color3.fromRGB(138, 154, 186),
			pulseColor = Color3.fromRGB(182, 204, 244),
			phase = 0.7,
		})

		for _, offset in ipairs({
			Vector3.new(-20.6, 8.2, -0.8),
			Vector3.new(20.6, 8.2, -0.8),
		}) do
			local fin = makePart(monument, "Part", "SideFin", Vector3.new(2, 14, 4), CFrame.new(position + offset) * CFrame.Angles(0, math.rad(offset.X > 0 and -7 or 7), 0), Color3.fromRGB(96, 74, 50), Enum.Material.WoodPlanks)
			fin.CanQuery = false
		end

		for index, direction in ipairs({ -1, 1 }) do
			local wing = makePart(
				monument,
				"Part",
				"LaneWing" .. tostring(index),
				Vector3.new(3.8, 4.4, 14),
				CFrame.new(position + Vector3.new(14.6 * direction, 2.2, 24)) * CFrame.Angles(0, math.rad(direction > 0 and -8 or 8), 0),
				Color3.fromRGB(104, 80, 54),
				Enum.Material.WoodPlanks
			)
			wing.CanQuery = false
			local wingGlow = makeGlowPart(
				monument,
				"LaneWingGlow" .. tostring(index),
				Vector3.new(0.12, 3.4, 10),
				wing.CFrame * CFrame.new(-1.88 * direction, 0, 0),
				Color3.fromRGB(214, 202, 176),
				0.84
			)
			wingGlow.CanCollide = false
			wingGlow.CanQuery = false
			table.insert(animatedBoardEffects, {
				type = "leaderPulse",
				part = wingGlow,
				baseTransparency = 0.84,
				baseColor = Color3.fromRGB(214, 202, 176),
				pulseColor = Color3.fromRGB(255, 244, 216),
				phase = 2.5 + index,
			})
		end

		local boardBase = makePart(monument, "Part", "BoardBase", Vector3.new(42, 0.7, 8.8), CFrame.new(position + Vector3.new(0, 1.12, 0.9)), Color3.fromRGB(114, 88, 60), Enum.Material.WoodPlanks)
		boardBase.CanQuery = false
		local boardBaseGlow = makeGlowPart(monument, "BoardBaseGlow", Vector3.new(42, 0.08, 8.8), boardBase.CFrame * CFrame.new(0, 0.24, 0), Color3.fromRGB(230, 224, 210), 0.9)
		boardBaseGlow.CanCollide = false
		boardBaseGlow.CanQuery = false

		local leftPillar = makePart(monument, "Part", "LeftPillar", Vector3.new(1.4, 20.4, 1.4), CFrame.new(position + Vector3.new(-18.8, 10.7, 0.9)), Color3.fromRGB(88, 62, 40), Enum.Material.WoodPlanks)
		leftPillar.CanQuery = false
		local rightPillar = makePart(monument, "Part", "RightPillar", Vector3.new(1.4, 20.4, 1.4), CFrame.new(position + Vector3.new(18.8, 10.7, 0.9)), Color3.fromRGB(88, 62, 40), Enum.Material.WoodPlanks)
		rightPillar.CanQuery = false
		local crown = makePart(monument, "Part", "Crown", Vector3.new(42.4, 1, 1.4), CFrame.new(position + Vector3.new(0, 20.2, 0.9)), Color3.fromRGB(92, 66, 42), Enum.Material.WoodPlanks)
		crown.CanQuery = false
		local crownGlow = makeGlowPart(monument, "CrownGlow", Vector3.new(42.4, 0.08, 1), crown.CFrame * CFrame.new(0, 0.28, 0), Color3.fromRGB(236, 214, 156), 0.84)
		table.insert(animatedBoardEffects, {
			type = "crownGlow",
			part = crownGlow,
			baseTransparency = 0.56,
			baseColor = Color3.fromRGB(218, 196, 140),
		})

		local boardFace = makePart(monument, "Part", "MasterBoard", Vector3.new(38.8, 22.4, 0.4), CFrame.new(position + Vector3.new(0, 11.6, 1.18)), Color3.fromRGB(246, 243, 234), Enum.Material.SmoothPlastic)
		boardFace.CanQuery = false
		attachLeaderboardMasterBoard(boardFace, animatedBoardEffects)

		for index, direction in ipairs({ -1, 1 }) do
			local sideGlow = makeGlowPart(monument, "SideGlow" .. tostring(index), Vector3.new(0.12, 19.6, 0.4), boardFace.CFrame * CFrame.new(19.5 * direction, 0, -0.02), Color3.fromRGB(214, 202, 176), 0.78)
			sideGlow.CanCollide = false
			sideGlow.CanQuery = false
			table.insert(animatedBoardEffects, {
				type = "leaderPulse",
				part = sideGlow,
				baseTransparency = 0.78,
				baseColor = Color3.fromRGB(214, 202, 176),
				pulseColor = Color3.fromRGB(255, 244, 216),
				phase = 0.8 + index,
			})
		end

		local footLight = makeGlowPart(monument, "FootLight", Vector3.new(28, 0.08, 2.4), CFrame.new(position + Vector3.new(0, 1.42, 3.8)), Color3.fromRGB(236, 224, 190), 0.86)
		footLight.CanCollide = false
		footLight.CanQuery = false
		local fill = Instance.new("PointLight")
		fill.Range = 26
		fill.Brightness = 0.28
		fill.Color = Color3.fromRGB(255, 242, 214)
		fill.Parent = footLight
		table.insert(animatedBoardEffects, {
			type = "leaderPulse",
			part = footLight,
			light = fill,
			baseTransparency = 0.86,
			baseColor = Color3.fromRGB(236, 224, 190),
			pulseColor = Color3.fromRGB(255, 244, 216),
			phase = 2.2,
		})

		for index, direction in ipairs({ -1, 1 }) do
			local crownLamp = makeGlowPart(monument, "CrownLamp" .. tostring(index), Vector3.new(0.8, 0.8, 0.8), crown.CFrame * CFrame.new(19 * direction, -0.12, 0.22), Color3.fromRGB(255, 234, 194), 0.36)
			crownLamp.CanCollide = false
			crownLamp.CanQuery = false
			local lampLight = Instance.new("PointLight")
			lampLight.Range = 12
			lampLight.Brightness = 0.2
			lampLight.Color = Color3.fromRGB(255, 238, 204)
			lampLight.Parent = crownLamp
		end

		for index, offset in ipairs({
			Vector3.new(-7.2, 1.7, 20),
			Vector3.new(7.2, 1.7, 20),
			Vector3.new(-7.2, 1.7, 28),
			Vector3.new(7.2, 1.7, 28),
		}) do
			local bollard = makePart(monument, "Part", "LaneBollard" .. tostring(index), Vector3.new(0.8, 2.8, 0.8), CFrame.new(position + offset), Color3.fromRGB(94, 82, 62), Enum.Material.Metal)
			bollard.CanQuery = false
			local cap = makeGlowPart(monument, "LaneBollardCap" .. tostring(index), Vector3.new(1.12, 0.14, 1.12), bollard.CFrame * CFrame.new(0, 1.28, 0), Color3.fromRGB(255, 236, 196), 0.36)
			cap.CanCollide = false
			cap.CanQuery = false
			local bollardLight = Instance.new("PointLight")
			bollardLight.Range = 10
			bollardLight.Brightness = 0.18
			bollardLight.Color = Color3.fromRGB(255, 238, 204)
			bollardLight.Parent = cap
			table.insert(animatedBoardEffects, {
				type = "leaderPulse",
				part = cap,
				light = bollardLight,
				baseTransparency = 0.48,
				baseColor = Color3.fromRGB(228, 214, 186),
				pulseColor = Color3.fromRGB(255, 242, 208),
				phase = 3.2 + index * 0.2,
			})
		end

		attachWorldText(approachPad, "ARCHIVE", Vector3.new(0, 1.6, 8.8), Color3.fromRGB(118, 92, 58), Vector2.new(104, 18))

		local controls = Instance.new("Model")
		controls.Name = "Controls"
		controls.Parent = monument

		local buttonPlane = boardFace.CFrame * CFrame.new(0, 0, -0.45)
		local pixelWidth = boardFace.Size.X * LEADERBOARD_MASTER_PPS
		local pixelHeight = boardFace.Size.Y * LEADERBOARD_MASTER_PPS
		local function addControlButton(name: string, x: number, y: number, width: number, height: number)
			local button = makePart(
				controls,
				"Part",
				name,
				Vector3.new(width, height, 0.18),
				buttonPlane * CFrame.new(x, y, 0),
				Color3.fromRGB(255, 255, 255),
				Enum.Material.SmoothPlastic
			)
			button.Transparency = 1
			button.CanCollide = false
			button.CanTouch = false
			button.CanQuery = true
			local detector = Instance.new("ClickDetector")
			detector.MaxActivationDistance = 32
			detector.Parent = button
			return button
		end

		local function addControlFromRect(name: string, rect)
			local rectCenterX = rect.x + (rect.width * 0.5)
			local rectCenterY = rect.y + (rect.height * 0.5)
			local localX = (rectCenterX - (pixelWidth * 0.5)) / LEADERBOARD_MASTER_PPS
			local localY = ((pixelHeight * 0.5) - rectCenterY) / LEADERBOARD_MASTER_PPS
			local localWidth = rect.width / LEADERBOARD_MASTER_PPS
			local localHeight = rect.height / LEADERBOARD_MASTER_PPS
			addControlButton(name, localX, localY, localWidth, localHeight)
		end

		for _, info in ipairs(LEADERBOARD_MASTER_WINDOW_BUTTONS) do
			addControlFromRect(info.controlName, {
				x = info.x - 8,
				y = info.y - 4,
				width = info.width + 16,
				height = info.height + 8,
			})
		end
		for _, info in ipairs(LEADERBOARD_MASTER_CATEGORY_TABS) do
			addControlFromRect(info.controlName, {
				x = info.x - 8,
				y = info.y - 4,
				width = info.width + 16,
				height = info.height + 8,
			})
		end
		for _, info in ipairs(LEADERBOARD_MASTER_SCROLL_BUTTONS) do
			addControlFromRect(info.name, info)
		end

		attachWorldText(base, "GLOBAL LEADERBOARDS", Vector3.new(0, 14.2, 0), Color3.fromRGB(255, 228, 182), Vector2.new(220, 28))
		return monument
	end

	local function addWatchTower(name: string, position: Vector3, accent: Color3)
		local tower = Instance.new("Model")
		tower.Name = name
		tower.Parent = plaza

		local core = makePart(
			tower,
			"Part",
			"Core",
			Vector3.new(3.2, 9, 3.2),
			CFrame.new(position + Vector3.new(0, 4.5, 0)),
			Color3.fromRGB(50, 56, 66),
			Enum.Material.Metal
		)
		core.CanQuery = false

		local deck = makePart(
			tower,
			"Part",
			"Deck",
			Vector3.new(7, 0.8, 7),
			CFrame.new(position + Vector3.new(0, 9.3, 0)),
			Color3.fromRGB(72, 80, 92),
			Enum.Material.DiamondPlate
		)
		deck.CanQuery = false

		for _, offset in ipairs({
			Vector3.new(-2.4, 10.3, -2.4),
			Vector3.new(2.4, 10.3, -2.4),
			Vector3.new(-2.4, 10.3, 2.4),
			Vector3.new(2.4, 10.3, 2.4),
		}) do
			local rail = makePart(
				tower,
				"Part",
				"Rail",
				Vector3.new(0.7, 1.6, 0.7),
				CFrame.new(position + offset),
				Color3.fromRGB(92, 100, 112),
				Enum.Material.Metal
			)
			rail.CanQuery = false
		end

		addLamp(core, Vector3.new(0, 5.2, 0), accent, 0.38, 30, 0.46)
	end

	local function addPatrolNpc(name: string, title: string, startPosition: Vector3, endPosition: Vector3, accent: Color3, phase: number, dialogue)
		local npc = Instance.new("Model")
		npc.Name = name
		npc.Parent = plaza

		local lowerTitle = string.lower(title)
		local seatedRole = string.find(lowerTitle, "quartermaster", 1, true) ~= nil
			or string.find(lowerTitle, "dispatcher", 1, true) ~= nil
			or string.find(lowerTitle, "coordinator", 1, true) ~= nil
		local greetingText = "Standing by."
		if string.find(lowerTitle, "quartermaster", 1, true) then
			greetingText = "Need gear?"
		elseif string.find(lowerTitle, "officer", 1, true) then
			greetingText = "Need a fireteam?"
		elseif string.find(lowerTitle, "dispatcher", 1, true) then
			greetingText = "Need an invite?"
		elseif string.find(lowerTitle, "marshal", 1, true) then
			greetingText = "Ready to deploy?"
		elseif string.find(lowerTitle, "coordinator", 1, true) then
			greetingText = "Check your ops board."
		end
		local rolePalette = {
			suit = Color3.fromRGB(34, 39, 48),
			armor = Color3.fromRGB(58, 66, 80),
			belt = Color3.fromRGB(22, 25, 32),
			pack = Color3.fromRGB(26, 30, 38),
			packRoll = Color3.fromRGB(86, 96, 110),
			helmet = Color3.fromRGB(30, 34, 42),
			helmetBrim = Color3.fromRGB(40, 44, 52),
			boots = Color3.fromRGB(18, 20, 24),
			padColor = Color3.fromRGB(54, 62, 74),
			shoulder = Color3.fromRGB(70, 82, 98),
			extra = nil,
		}
		if string.find(lowerTitle, "quartermaster", 1, true) then
			rolePalette.suit = Color3.fromRGB(56, 44, 34)
			rolePalette.armor = Color3.fromRGB(120, 96, 70)
			rolePalette.belt = Color3.fromRGB(46, 36, 28)
			rolePalette.pack = Color3.fromRGB(64, 48, 36)
			rolePalette.packRoll = Color3.fromRGB(152, 124, 84)
			rolePalette.helmet = Color3.fromRGB(60, 46, 34)
			rolePalette.helmetBrim = Color3.fromRGB(86, 66, 46)
			rolePalette.padColor = Color3.fromRGB(76, 60, 44)
			rolePalette.shoulder = Color3.fromRGB(132, 102, 72)
			rolePalette.extra = "supply"
		elseif string.find(lowerTitle, "officer", 1, true) or string.find(lowerTitle, "marshal", 1, true) then
			rolePalette.suit = Color3.fromRGB(34, 46, 60)
			rolePalette.armor = Color3.fromRGB(72, 100, 138)
			rolePalette.belt = Color3.fromRGB(20, 26, 34)
			rolePalette.pack = Color3.fromRGB(24, 34, 46)
			rolePalette.packRoll = Color3.fromRGB(96, 122, 154)
			rolePalette.helmet = Color3.fromRGB(26, 36, 48)
			rolePalette.helmetBrim = Color3.fromRGB(44, 60, 78)
			rolePalette.padColor = Color3.fromRGB(46, 60, 78)
			rolePalette.shoulder = Color3.fromRGB(94, 126, 172)
			rolePalette.extra = string.find(lowerTitle, "marshal", 1, true) and "marshal" or "command"
		elseif string.find(lowerTitle, "dispatcher", 1, true) then
			rolePalette.suit = Color3.fromRGB(34, 54, 48)
			rolePalette.armor = Color3.fromRGB(64, 114, 102)
			rolePalette.belt = Color3.fromRGB(20, 30, 28)
			rolePalette.pack = Color3.fromRGB(26, 40, 36)
			rolePalette.packRoll = Color3.fromRGB(92, 142, 128)
			rolePalette.helmet = Color3.fromRGB(24, 42, 38)
			rolePalette.helmetBrim = Color3.fromRGB(42, 70, 64)
			rolePalette.padColor = Color3.fromRGB(42, 70, 64)
			rolePalette.shoulder = Color3.fromRGB(86, 154, 138)
			rolePalette.extra = "comms"
		elseif string.find(lowerTitle, "coordinator", 1, true) then
			rolePalette.suit = Color3.fromRGB(46, 58, 34)
			rolePalette.armor = Color3.fromRGB(96, 126, 68)
			rolePalette.belt = Color3.fromRGB(26, 32, 20)
			rolePalette.pack = Color3.fromRGB(34, 44, 26)
			rolePalette.packRoll = Color3.fromRGB(132, 158, 94)
			rolePalette.helmet = Color3.fromRGB(38, 48, 28)
			rolePalette.helmetBrim = Color3.fromRGB(62, 78, 42)
			rolePalette.padColor = Color3.fromRGB(62, 78, 42)
			rolePalette.shoulder = Color3.fromRGB(138, 176, 88)
			rolePalette.extra = "ops"
		end

		local basePad = makePart(
			npc,
			"Part",
			"Pad",
			Vector3.new(9, 0.45, 9),
			CFrame.new(startPosition + Vector3.new(0, 0.3, 0)),
			rolePalette.padColor,
			Enum.Material.Metal
		)
		basePad.CanCollide = false
		basePad.CanQuery = false
		local baseRing = makeGlowPart(
			npc,
			"PadRing",
			Vector3.new(7.2, 0.1, 7.2),
			basePad.CFrame * CFrame.new(0, 0.28, 0),
			accent,
			0.88
		)
		baseRing.CanCollide = false
		baseRing.CanQuery = false
		local promptHalo = makeGlowPart(
			npc,
			"PromptHalo",
			Vector3.new(4.2, 0.08, 4.2),
			basePad.CFrame * CFrame.new(0, 0.32, 0),
			accent,
			0.94
		)
		promptHalo.CanCollide = false
		promptHalo.CanQuery = false

		local seatBase = nil
		local seatBack = nil
		if seatedRole then
			seatBase = makePart(
				npc,
				"Part",
				"SeatBase",
				Vector3.new(2.8, 0.42, 2.8),
				CFrame.new(startPosition + Vector3.new(0, 1.1, 0.4)),
				rolePalette.armor:Lerp(Color3.fromRGB(40, 44, 52), 0.35),
				Enum.Material.Metal
			)
			seatBase.CanCollide = false
			seatBase.CanQuery = false
			seatBack = makePart(
				npc,
				"Part",
				"SeatBack",
				Vector3.new(2.8, 3.4, 0.38),
				CFrame.new(startPosition + Vector3.new(0, 2.8, 1.62)),
				rolePalette.armor:Lerp(Color3.fromRGB(32, 36, 42), 0.28),
				Enum.Material.Metal
			)
			seatBack.CanCollide = false
			seatBack.CanQuery = false
		end

		local rootPart = Instance.new("Part")
		rootPart.Name = "HumanoidRootPart"
		rootPart.Size = Vector3.new(2, 2, 1)
		rootPart.Anchored = true
		rootPart.CanCollide = false
		rootPart.CanQuery = false
		rootPart.Transparency = 1
		rootPart.CFrame = CFrame.new(startPosition + Vector3.new(0, seatedRole and 2.25 or 3, 0), endPosition + Vector3.new(0, seatedRole and 2.25 or 3, 0))
		rootPart.Parent = npc

		local torso = makePart(
			npc,
			"Part",
			"Torso",
			Vector3.new(2.45, 2.9, 1.38),
			rootPart.CFrame * CFrame.new(0, 1.5, 0),
			rolePalette.suit,
			Enum.Material.SmoothPlastic
		)
		torso.CanCollide = false
		torso.CanQuery = false
		local chestPlate = makePart(
			npc,
			"Part",
			"ChestPlate",
			Vector3.new(2.18, 2.28, 0.42),
			rootPart.CFrame * CFrame.new(0, 1.5, -0.48),
			rolePalette.armor,
			Enum.Material.Metal
		)
		chestPlate.CanCollide = false
		chestPlate.CanQuery = false
		local chestStrip = makeGlowPart(
			npc,
			"ChestStrip",
			Vector3.new(1.24, 0.12, 0.1),
			chestPlate.CFrame * CFrame.new(0, 0.52, -0.18),
			accent,
			0.44
		)
		chestStrip.CanCollide = false
		chestStrip.CanQuery = false
		local utilityBelt = makePart(
			npc,
			"Part",
			"UtilityBelt",
			Vector3.new(2.56, 0.44, 1.18),
			rootPart.CFrame * CFrame.new(0, 0.18, 0),
			rolePalette.belt,
			Enum.Material.Metal
		)
		utilityBelt.CanCollide = false
		utilityBelt.CanQuery = false
		local backpack = makePart(
			npc,
			"Part",
			"Backpack",
			Vector3.new(1.82, 2.22, 0.88),
			rootPart.CFrame * CFrame.new(0, 1.48, 0.84),
			rolePalette.pack,
			Enum.Material.Metal
		)
		backpack.CanCollide = false
		backpack.CanQuery = false
		local backpackRoll = makePart(
			npc,
			"Part",
			"BackpackRoll",
			Vector3.new(1.96, 0.42, 0.74),
			rootPart.CFrame * CFrame.new(0, 2.62, 0.78),
			rolePalette.packRoll,
			Enum.Material.SmoothPlastic
		)
		backpackRoll.CanCollide = false
		backpackRoll.CanQuery = false

		local head = makePart(
			npc,
			"Part",
			"Head",
			Vector3.new(1.58, 1.58, 1.58),
			rootPart.CFrame * CFrame.new(0, 3.7, 0),
			Color3.fromRGB(204, 196, 188),
			Enum.Material.SmoothPlastic
		)
		head.Shape = Enum.PartType.Ball
		head.CanCollide = false
		head.CanQuery = false
		local helmet = makePart(
			npc,
			"Part",
			"Helmet",
			Vector3.new(1.92, 0.92, 1.92),
			head.CFrame * CFrame.new(0, 0.44, 0),
			rolePalette.helmet,
			Enum.Material.Metal
		)
		helmet.CanCollide = false
		helmet.CanQuery = false
		local helmetBrim = makePart(
			npc,
			"Part",
			"HelmetBrim",
			Vector3.new(2.12, 0.18, 1.96),
			head.CFrame * CFrame.new(0, 0.08, -0.04),
			rolePalette.helmetBrim,
			Enum.Material.Metal
		)
		helmetBrim.CanCollide = false
		helmetBrim.CanQuery = false

		local leftArm = makePart(
			npc,
			"Part",
			"LeftArm",
			Vector3.new(0.78, 2.6, 0.78),
			rootPart.CFrame * CFrame.new(-1.7, 1.42, 0),
			rolePalette.suit,
			Enum.Material.SmoothPlastic
		)
		leftArm.CanCollide = false
		leftArm.CanQuery = false
		local leftShoulder = makePart(
			npc,
			"Part",
			"LeftShoulder",
			Vector3.new(0.96, 0.72, 0.96),
			rootPart.CFrame * CFrame.new(-1.46, 2.48, 0),
			rolePalette.shoulder,
			Enum.Material.Metal
		)
		leftShoulder.CanCollide = false
		leftShoulder.CanQuery = false

		local rightArm = makePart(
			npc,
			"Part",
			"RightArm",
			Vector3.new(0.78, 2.6, 0.78),
			rootPart.CFrame * CFrame.new(1.7, 1.42, 0),
			rolePalette.suit,
			Enum.Material.SmoothPlastic
		)
		rightArm.CanCollide = false
		rightArm.CanQuery = false
		local rightShoulder = makePart(
			npc,
			"Part",
			"RightShoulder",
			Vector3.new(0.96, 0.72, 0.96),
			rootPart.CFrame * CFrame.new(1.46, 2.48, 0),
			rolePalette.shoulder,
			Enum.Material.Metal
		)
		rightShoulder.CanCollide = false
		rightShoulder.CanQuery = false

		local leftLeg = makePart(
			npc,
			"Part",
			"LeftLeg",
			Vector3.new(0.88, 2.95, 0.88),
			rootPart.CFrame * CFrame.new(-0.64, -0.34, 0),
			rolePalette.suit:Lerp(Color3.fromRGB(20, 22, 28), 0.35),
			Enum.Material.SmoothPlastic
		)
		leftLeg.CanCollide = false
		leftLeg.CanQuery = false
		local leftBoot = makePart(
			npc,
			"Part",
			"LeftBoot",
			Vector3.new(0.98, 0.72, 1.12),
			rootPart.CFrame * CFrame.new(-0.64, -2.06, 0.08),
			rolePalette.boots,
			Enum.Material.Metal
		)
		leftBoot.CanCollide = false
		leftBoot.CanQuery = false

		local rightLeg = makePart(
			npc,
			"Part",
			"RightLeg",
			Vector3.new(0.88, 2.95, 0.88),
			rootPart.CFrame * CFrame.new(0.64, -0.34, 0),
			rolePalette.suit:Lerp(Color3.fromRGB(20, 22, 28), 0.35),
			Enum.Material.SmoothPlastic
		)
		rightLeg.CanCollide = false
		rightLeg.CanQuery = false
		local rightBoot = makePart(
			npc,
			"Part",
			"RightBoot",
			Vector3.new(0.98, 0.72, 1.12),
			rootPart.CFrame * CFrame.new(0.64, -2.06, 0.08),
			rolePalette.boots,
			Enum.Material.Metal
		)

		if rolePalette.extra == "supply" then
			local satchel = makePart(
				npc,
				"Part",
				"Satchel",
				Vector3.new(1.1, 1.6, 0.72),
				rootPart.CFrame * CFrame.new(-1.18, 0.74, 0.58),
				Color3.fromRGB(118, 88, 54),
				Enum.Material.WoodPlanks
			)
			satchel.CanCollide = false
			satchel.CanQuery = false
		elseif rolePalette.extra == "command" then
			local tablet = makePart(
				npc,
				"Part",
				"CommandTablet",
				Vector3.new(0.96, 1.28, 0.14),
				rootPart.CFrame * CFrame.new(1.18, 0.92, -0.62),
				Color3.fromRGB(78, 112, 168),
				Enum.Material.Metal
			)
			tablet.CanCollide = false
			tablet.CanQuery = false
			makeGlowPart(npc, "CommandTabletGlow", Vector3.new(0.76, 1.02, 0.08), tablet.CFrame * CFrame.new(0, 0, -0.08), accent, 0.34).CanQuery = false
		elseif rolePalette.extra == "marshal" then
			local marshalStripe = makeGlowPart(
				npc,
				"MarshalStripe",
				Vector3.new(0.22, 2.1, 0.08),
				rootPart.CFrame * CFrame.new(0.84, 1.52, -0.76),
				accent,
				0.24
			)
			marshalStripe.CanCollide = false
			marshalStripe.CanQuery = false
		elseif rolePalette.extra == "comms" then
			local headset = makePart(
				npc,
				"Part",
				"Headset",
				Vector3.new(0.18, 0.78, 0.18),
				head.CFrame * CFrame.new(-0.78, 0.08, 0),
				Color3.fromRGB(88, 124, 116),
				Enum.Material.Metal
			)
			headset.CanCollide = false
			headset.CanQuery = false
			local commsAntenna = makePart(
				npc,
				"Part",
				"CommsAntenna",
				Vector3.new(0.08, 1.24, 0.08),
				rootPart.CFrame * CFrame.new(0.42, 2.54, 0.92),
				Color3.fromRGB(98, 142, 128),
				Enum.Material.Metal
			)
			commsAntenna.CanCollide = false
			commsAntenna.CanQuery = false
		elseif rolePalette.extra == "ops" then
			local opsClipboard = makePart(
				npc,
				"Part",
				"OpsClipboard",
				Vector3.new(0.92, 1.16, 0.14),
				rootPart.CFrame * CFrame.new(-1.14, 0.98, -0.58),
				Color3.fromRGB(146, 170, 92),
				Enum.Material.Metal
			)
			opsClipboard.CanCollide = false
			opsClipboard.CanQuery = false
			makeGlowPart(npc, "OpsClipboardGlow", Vector3.new(0.72, 0.92, 0.08), opsClipboard.CFrame * CFrame.new(0, 0, -0.08), accent, 0.4).CanQuery = false
		end
		rightBoot.CanCollide = false
		rightBoot.CanQuery = false

		local visor = makeGlowPart(
			npc,
			"Visor",
			Vector3.new(1.18, 0.24, 0.18),
			head.CFrame * CFrame.new(0, 0.02, -0.76),
			accent,
			0.08
		)
		local scanner = Instance.new("SpotLight")
		scanner.Angle = 42
		scanner.Range = 20
		scanner.Brightness = 1.45
		scanner.Face = Enum.NormalId.Front
		scanner.Color = accent
		scanner.Parent = visor

		local shoulderLamp = makeGlowPart(
			npc,
			"ShoulderLamp",
			Vector3.new(0.32, 0.32, 0.32),
			torso.CFrame * CFrame.new(1.0, 0.7, -0.2),
			accent,
			0.08
		)
		local shoulderLight = Instance.new("PointLight")
		shoulderLight.Range = 14
		shoulderLight.Brightness = 0.45
		shoulderLight.Color = accent
		shoulderLight.Parent = shoulderLamp

		local humanoid = Instance.new("Humanoid")
		humanoid.Name = "Humanoid"
		humanoid.DisplayName = title
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.NameDisplayDistance = 28
		humanoid.MaxHealth = 100
		humanoid.Health = 100
		humanoid.WalkSpeed = 0
		humanoid.Parent = npc

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "LobbyNpcPrompt"
		prompt.ActionText = tostring((dialogue and dialogue.actionLabel) or "Talk")
		prompt.ObjectText = title
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 10
		prompt:SetAttribute("NpcDialogueTitle", tostring((dialogue and dialogue.title) or title))
		prompt:SetAttribute("NpcDialogueRole", tostring((dialogue and dialogue.role) or "Outpost contact"))
		prompt:SetAttribute("NpcDialogueBody", tostring((dialogue and dialogue.body) or "Stay alert and keep the bunker secure."))
		prompt:SetAttribute("NpcActionLabel", tostring((dialogue and dialogue.actionLabel) or "Close"))
		prompt:SetAttribute("NpcActionPanel", dialogue and dialogue.actionPanel or "")
		prompt.Parent = rootPart

		local greetingGui = Instance.new("BillboardGui")
		greetingGui.Name = "GreetingGui"
		greetingGui.Size = UDim2.fromOffset(148, 28)
		greetingGui.StudsOffset = Vector3.new(0, seatedRole and 5.1 or 5.8, 0)
		greetingGui.AlwaysOnTop = false
		greetingGui.MaxDistance = 34
		greetingGui.Parent = rootPart

		local greetingFrame = Instance.new("Frame")
		greetingFrame.Name = "Frame"
		greetingFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
		greetingFrame.BackgroundTransparency = 1
		greetingFrame.BorderSizePixel = 0
		greetingFrame.Size = UDim2.fromScale(1, 1)
		greetingFrame.Parent = greetingGui

		local greetingStroke = Instance.new("UIStroke")
		greetingStroke.Color = accent
		greetingStroke.Transparency = 1
		greetingStroke.Thickness = 1
		greetingStroke.Parent = greetingFrame

		local greetingLabel = Instance.new("TextLabel")
		greetingLabel.Name = "Label"
		greetingLabel.BackgroundTransparency = 1
		greetingLabel.Size = UDim2.fromScale(1, 1)
		greetingLabel.Font = Enum.Font.GothamBold
		greetingLabel.Text = greetingText
		greetingLabel.TextColor3 = Color3.new(1, 1, 1)
		greetingLabel.TextSize = 12
		greetingLabel.TextTransparency = 1
		greetingLabel.Parent = greetingFrame

		npc.PrimaryPart = rootPart
		local stationary = (startPosition - endPosition).Magnitude <= 1
		table.insert(ambientActors, {
			root = rootPart,
			greetingGui = greetingGui,
			greetingFrame = greetingFrame,
			greetingStroke = greetingStroke,
			greetingLabel = greetingLabel,
			promptHalo = promptHalo,
			prompt = prompt,
			accent = accent,
			scanner = scanner,
			shoulderLight = shoulderLight,
			seated = seatedRole,
			seatBase = seatBase,
			seatBack = seatBack,
			baseRing = baseRing,
			head = head,
			helmet = helmet,
			helmetBrim = helmetBrim,
			torso = torso,
			chestPlate = chestPlate,
			chestStrip = chestStrip,
			utilityBelt = utilityBelt,
			backpack = backpack,
			backpackRoll = backpackRoll,
			leftArm = leftArm,
			rightArm = rightArm,
			leftShoulder = leftShoulder,
			rightShoulder = rightShoulder,
			leftLeg = leftLeg,
			rightLeg = rightLeg,
			leftBoot = leftBoot,
			rightBoot = rightBoot,
			shoulderLamp = shoulderLamp,
			visor = visor,
			routeStart = startPosition + Vector3.new(0, seatedRole and 2.25 or 3, 0),
			routeEnd = endPosition + Vector3.new(0, seatedRole and 2.25 or 3, 0),
			stationary = stationary,
			idleLookTarget = worldPosition + Vector3.new(0, seatedRole and 2.4 or 3, 0),
			phase = phase,
			speed = stationary and 0.06 or 0.12,
		})

		table.insert(beaconLights, {
			part = visor,
			light = scanner,
			baseCFrame = visor.CFrame,
			scanOnly = true,
		})
		table.insert(beaconLights, {
			part = shoulderLamp,
			light = shoulderLight,
			baseCFrame = shoulderLamp.CFrame,
		})
	end

	local outerGround = makePart(
		plaza,
		"Part",
		"OuterGround",
		Vector3.new(324, 2, 288),
		CFrame.new(worldPosition + Vector3.new(0, -1.2, 0)),
		Color3.fromRGB(28, 30, 34),
		Enum.Material.Asphalt
	)
	outerGround.CanQuery = false

	local centralDeck = makePart(
		plaza,
		"Part",
		"CentralDeck",
		Vector3.new(164, 1.2, 150),
		CFrame.new(worldPosition + Vector3.new(0, -0.2, 0)),
		Color3.fromRGB(54, 60, 70),
		Enum.Material.Concrete
	)
	centralDeck.CanQuery = false

	local innerDeck = makePart(
		plaza,
		"Part",
		"InnerDeck",
		Vector3.new(100, 0.5, 90),
		CFrame.new(worldPosition + Vector3.new(0, 0.62, 0)),
		Color3.fromRGB(82, 90, 102),
		Enum.Material.DiamondPlate
	)
	innerDeck.CanCollide = false
	innerDeck.CanQuery = false

	local centerPlinth = makePart(
		plaza,
		"Part",
		"CenterPlinth",
		Vector3.new(54, 2.6, 44),
		CFrame.new(worldPosition + Vector3.new(0, 1.28, 0)),
		Color3.fromRGB(68, 78, 92),
		Enum.Material.Metal
	)
	centerPlinth.CanQuery = false

	local upperPlinth = makePart(
		plaza,
		"Part",
		"UpperPlinth",
		Vector3.new(28, 1.4, 28),
		CFrame.new(worldPosition + Vector3.new(0, 2.9, 0)),
		Color3.fromRGB(94, 110, 132),
		Enum.Material.DiamondPlate
	)
	upperPlinth.CanQuery = false

	local centerRing = makeGlowPart(
		plaza,
		"CenterRing",
		Vector3.new(34, 0.12, 32),
		CFrame.new(worldPosition + Vector3.new(0, 3.68, 0)),
		Color3.fromRGB(126, 152, 186),
		0.9
	)
	centerRing.CanCollide = false
	centerRing.CanQuery = false

	local lowerRing = makeGlowPart(
		plaza,
		"LowerCenterRing",
		Vector3.new(64, 0.1, 54),
		CFrame.new(worldPosition + Vector3.new(0, 2.7, 0)),
		Color3.fromRGB(108, 132, 170),
		0.92
	)
	lowerRing.CanCollide = false
	lowerRing.CanQuery = false

	local lobbyReturnAnchor = makePart(
		plaza,
		"Part",
		"LobbyReturnAnchor",
		Vector3.new(10, 1, 10),
		CFrame.new(worldPosition + Vector3.new(0, 1.4, 18)),
		Color3.fromRGB(96, 110, 132),
		Enum.Material.Metal
	)
	lobbyReturnAnchor.Transparency = 1
	lobbyReturnAnchor.CanCollide = false
	lobbyReturnAnchor.CanQuery = false

	for _, info in ipairs({
		{ "NorthwestSpur", Vector3.new(-23, 0.82, -21), Vector3.new(22, 0.4, 8), math.rad(32), Color3.fromRGB(74, 82, 96) },
		{ "NortheastSpur", Vector3.new(23, 0.82, -19), Vector3.new(20, 0.4, 8), math.rad(-28), Color3.fromRGB(76, 84, 96) },
		{ "SouthwestSpur", Vector3.new(-25, 0.82, 19), Vector3.new(18, 0.4, 8), math.rad(-26), Color3.fromRGB(80, 86, 90) },
		{ "SoutheastSpur", Vector3.new(21, 0.82, 23), Vector3.new(22, 0.4, 8), math.rad(30), Color3.fromRGB(78, 88, 92) },
	}) do
		local spur = makePart(
			plaza,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]) * CFrame.Angles(0, info[4], 0),
			info[5],
			Enum.Material.DiamondPlate
		)
		spur.CanQuery = false
		local spurLine = makeGlowPart(
			plaza,
			info[1] .. "Line",
			Vector3.new(info[3].X - 3, 0.08, 1),
			spur.CFrame * CFrame.new(0, 0.24, 0),
			Color3.fromRGB(118, 138, 170),
			0.86
		)
		spurLine.CanCollide = false
		spurLine.CanQuery = false
	end

	for _, info in ipairs({
		{ "NorthSpineLeft", Vector3.new(-10, 0.82, -42), Vector3.new(14, 0.36, 16), math.rad(10), Color3.fromRGB(72, 80, 92) },
		{ "NorthSpineRight", Vector3.new(12, 0.82, -40), Vector3.new(16, 0.36, 14), math.rad(-14), Color3.fromRGB(74, 82, 94) },
		{ "SouthSpineLeft", Vector3.new(-12, 0.82, 42), Vector3.new(16, 0.36, 14), math.rad(-12), Color3.fromRGB(82, 88, 84) },
		{ "SouthSpineRight", Vector3.new(14, 0.82, 44), Vector3.new(14, 0.36, 16), math.rad(12), Color3.fromRGB(82, 90, 86) },
	}) do
		local spine = makePart(
			plaza,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]) * CFrame.Angles(0, info[4], 0),
			info[5],
			Enum.Material.Metal
		)
		spine.CanQuery = false
	end

	for _, info in ipairs({
		{ "North", Vector3.new(0, 1.1, -34), Vector3.new(54, 0.14, 2) },
		{ "South", Vector3.new(0, 1.1, 34), Vector3.new(54, 0.14, 2) },
		{ "West", Vector3.new(-34, 1.1, 0), Vector3.new(2, 0.14, 54) },
		{ "East", Vector3.new(34, 1.1, 0), Vector3.new(2, 0.14, 54) },
	}) do
		local strip = makeGlowPart(
			plaza,
			"DistrictStrip" .. info[1],
			info[3],
			CFrame.new(worldPosition + info[2]),
			Color3.fromRGB(108, 122, 144),
			0.8
		)
		strip.CanCollide = false
		strip.CanQuery = false
	end

	for _, info in ipairs({
		{ "WestRailNorth", Vector3.new(-94, 0.9, -34), Vector3.new(2.4, 2.8, 40) },
		{ "WestRailSouth", Vector3.new(-94, 0.9, 42), Vector3.new(2.4, 2.2, 36) },
		{ "EastRailNorth", Vector3.new(94, 0.9, -34), Vector3.new(2.4, 2.8, 40) },
		{ "EastRailSouth", Vector3.new(94, 0.9, 42), Vector3.new(2.4, 2.2, 36) },
		{ "NorthBackLeft", Vector3.new(-42, 0.9, -90), Vector3.new(52, 2.8, 2.4) },
		{ "NorthBackRight", Vector3.new(42, 0.9, -90), Vector3.new(52, 2.8, 2.4) },
	}) do
		local rail = makePart(
			plaza,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]),
			Color3.fromRGB(26, 28, 34),
			Enum.Material.Metal
		)
		rail.CanQuery = false
		local cap = makeGlowPart(
			plaza,
			info[1] .. "Cap",
			Vector3.new(info[3].X + 0.2, 0.1, info[3].Z + 0.2),
			rail.CFrame * CFrame.new(0, (info[3].Y * 0.5) + 0.08, 0),
			Color3.fromRGB(110, 128, 158),
			0.84
		)
		cap.CanCollide = false
		cap.CanQuery = false
	end

	for _, info in ipairs({
		{ "SouthBraceLeft", Vector3.new(-70, 0.72, 88), Vector3.new(28, 1.5, 2.2), math.rad(18) },
		{ "SouthBraceRight", Vector3.new(70, 0.72, 88), Vector3.new(28, 1.5, 2.2), math.rad(-18) },
	}) do
		local brace = makePart(
			plaza,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]) * CFrame.Angles(0, info[4], 0),
			Color3.fromRGB(30, 34, 40),
			Enum.Material.Metal
		)
		brace.CanQuery = false
		local braceCap = makeGlowPart(
			plaza,
			info[1] .. "Cap",
			Vector3.new(info[3].X + 0.2, 0.1, info[3].Z + 0.2),
			brace.CFrame * CFrame.new(0, 0.82, 0),
			Color3.fromRGB(108, 126, 154),
			0.86
		)
		braceCap.CanCollide = false
		braceCap.CanQuery = false
	end

	for _, info in ipairs({
		{ "NorthOpeningLeft", Vector3.new(-12, 0.4, -89.5), Vector3.new(18, 0.8, 4) },
		{ "NorthOpeningRight", Vector3.new(12, 0.4, -89.5), Vector3.new(18, 0.8, 4) },
		{ "SouthOpening", Vector3.new(0, 0.4, 89.5), Vector3.new(28, 0.8, 4) },
		{ "WestOpening", Vector3.new(-93.5, 0.4, 10), Vector3.new(4, 0.8, 22) },
		{ "EastOpening", Vector3.new(93.5, 0.4, 10), Vector3.new(4, 0.8, 22) },
	}) do
		local sill = makePart(
			plaza,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]),
			Color3.fromRGB(58, 66, 78),
			Enum.Material.DiamondPlate
		)
		sill.CanQuery = false
	end

	for _, info in ipairs({
		{ "NorthConcourse", Vector3.new(0, 0.08, -74), Vector3.new(48, 0.2, 32), Color3.fromRGB(86, 90, 104) },
		{ "SouthConcourse", Vector3.new(-4, 0.08, 84), Vector3.new(36, 0.2, 18), Color3.fromRGB(92, 94, 84) },
		{ "WestConcourse", Vector3.new(-68, 0.08, 6), Vector3.new(38, 0.2, 56), Color3.fromRGB(76, 84, 100) },
		{ "EastConcourse", Vector3.new(68, 0.08, 4), Vector3.new(38, 0.2, 56), Color3.fromRGB(76, 92, 88) },
	}) do
		local apron = makePart(
			plaza,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]),
			info[4],
			Enum.Material.DiamondPlate
		)
		apron.CanQuery = false
	end

	for _, info in ipairs({
		{ "DRILL DISTRICT", Vector3.new(-68, 2.4, 33), Color3.fromRGB(244, 220, 164), Vector2.new(154, 22) },
		{ "COMBAT DISTRICT", Vector3.new(68, 2.4, 33), Color3.fromRGB(244, 186, 154), Vector2.new(168, 22) },
		{ "ARCHIVE WALK", Vector3.new(-86, 2.4, 82), Color3.fromRGB(232, 214, 176), Vector2.new(144, 22) },
		{ "DEPLOY CORRIDOR", Vector3.new(0, 2.8, 78), Color3.fromRGB(255, 206, 182), Vector2.new(170, 22) },
	}) do
		local marker = makePart(
			plaza,
			"Part",
			"DistrictMarker",
			Vector3.new(8, 0.2, 8),
			CFrame.new(worldPosition + info[2]),
			Color3.fromRGB(40, 44, 52),
			Enum.Material.Metal
		)
		marker.Transparency = 1
		marker.CanCollide = false
		marker.CanQuery = false
		attachWorldText(marker, info[1], Vector3.new(0, 0, 0), info[3], info[4])
	end

	local southSpine = makePart(
		plaza,
		"Part",
		"SouthCoreSpine",
		Vector3.new(14, 0.2, 92),
		CFrame.new(worldPosition + Vector3.new(0, 0.16, 44)),
		Color3.fromRGB(98, 102, 92),
		Enum.Material.DiamondPlate
	)
	southSpine.CanCollide = false
	southSpine.CanQuery = false
	local southSpineGuide = makeGlowPart(
		plaza,
		"SouthCoreSpineGuide",
		Vector3.new(3.8, 0.08, 88),
		CFrame.new(worldPosition + Vector3.new(0, 0.34, 44)),
		Color3.fromRGB(210, 220, 242),
		0.84
	)
	southSpineGuide.CanCollide = false
	southSpineGuide.CanQuery = false
	local spawnThreshold = makePart(
		plaza,
		"Part",
		"SpawnThreshold",
		Vector3.new(28, 0.32, 4.4),
		CFrame.new(worldPosition + Vector3.new(0, 0.42, 26)),
		Color3.fromRGB(122, 132, 148),
		Enum.Material.Metal
	)
	spawnThreshold.CanCollide = false
	spawnThreshold.CanQuery = false
	local spawnThresholdGlow = makeGlowPart(
		plaza,
		"SpawnThresholdGlow",
		Vector3.new(22, 0.08, 1.2),
		spawnThreshold.CFrame * CFrame.new(0, 0.16, -1.12),
		Color3.fromRGB(208, 220, 244),
		0.78
	)
	spawnThresholdGlow.CanCollide = false
	spawnThresholdGlow.CanQuery = false

	for _, info in ipairs({
		{ "SpawnFrameWingLeft", Vector3.new(-48, 0.7, 62), Vector3.new(28, 1.6, 2.8), math.rad(18), Color3.fromRGB(34, 38, 44) },
		{ "SpawnFrameWingRight", Vector3.new(48, 0.7, 62), Vector3.new(28, 1.6, 2.8), math.rad(-18), Color3.fromRGB(34, 38, 44) },
	}) do
		local wing = makePart(
			plaza,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]) * CFrame.Angles(0, info[4], 0),
			info[5],
			Enum.Material.Metal
		)
		wing.CanQuery = false
		local wingCap = makeGlowPart(
			plaza,
			info[1] .. "Cap",
			Vector3.new(info[3].X - 4, 0.08, 0.9),
			wing.CFrame * CFrame.new(0, 0.92, 0),
			Color3.fromRGB(126, 144, 174),
			0.84
		)
		wingCap.CanCollide = false
		wingCap.CanQuery = false
	end

	for _, info in ipairs({
		{ "SpawnGateLeft", Vector3.new(-16, 4.2, 24), Vector3.new(2.4, 8.4, 2.4) },
		{ "SpawnGateRight", Vector3.new(16, 4.2, 24), Vector3.new(2.4, 8.4, 2.4) },
	}) do
		local pylon = makePart(
			plaza,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]),
			Color3.fromRGB(74, 82, 96),
			Enum.Material.Metal
		)
		pylon.CanQuery = false
		local pylonGlow = makeGlowPart(
			plaza,
			info[1] .. "Glow",
			Vector3.new(0.16, 5.8, 1.6),
			pylon.CFrame * CFrame.new(0, 0.3, 0),
			Color3.fromRGB(196, 216, 246),
			0.7
		)
		pylonGlow.CanCollide = false
		pylonGlow.CanQuery = false
	end

	local spawnGateHeader = makeGlowPart(
		plaza,
		"SpawnGateHeader",
		Vector3.new(34, 0.12, 1.2),
		CFrame.new(worldPosition + Vector3.new(0, 8.24, 24)),
		Color3.fromRGB(202, 222, 248),
		0.78
	)
	spawnGateHeader.CanCollide = false
	spawnGateHeader.CanQuery = false

	for index, zOffset in ipairs({ 30, 8, -18 }) do
		local mast = makePart(
			plaza,
			"Part",
			"AxisPylon" .. tostring(index),
			Vector3.new(1.8, 6.2, 1.8),
			CFrame.new(worldPosition + Vector3.new(0, 3.2, zOffset)),
			Color3.fromRGB(70, 78, 92),
			Enum.Material.Metal
		)
		mast.CanQuery = false
		local mastGlow = makeGlowPart(
			plaza,
			"AxisPylonGlow" .. tostring(index),
			Vector3.new(0.16, 4.8, 1.2),
			mast.CFrame * CFrame.new(0, 0.2, 0),
			Color3.fromRGB(188, 208, 238),
			0.72
		)
		mastGlow.CanCollide = false
		mastGlow.CanQuery = false
	end

	for _, info in ipairs({
		{ "NorthRamp", Vector3.new(0, 0.82, -34), Vector3.new(18, 0.54, 10), Color3.fromRGB(82, 90, 106), CFrame.Angles(0, math.rad(180), 0) },
		{ "SouthRamp", Vector3.new(0, 0.96, 34), Vector3.new(24, 0.8, 14), Color3.fromRGB(88, 96, 88), CFrame.new() },
		{ "WestRamp", Vector3.new(-34, 0.96, 0), Vector3.new(14, 0.8, 24), Color3.fromRGB(80, 88, 104), CFrame.Angles(0, math.rad(90), 0) },
		{ "EastRamp", Vector3.new(34, 0.96, 0), Vector3.new(14, 0.8, 24), Color3.fromRGB(80, 94, 88), CFrame.Angles(0, math.rad(-90), 0) },
	}) do
		local ramp = makePart(
			plaza,
			"WedgePart",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]) * info[5],
			info[4],
			Enum.Material.Metal
		)
		ramp.CanQuery = false
	end

	local activityModels = {}
	if Config.Areas.Training then
		activityModels.Training = makeTrainingYard(plaza, worldPosition + Config.Areas.Training.Offset, Config.Areas.Training, lobbyReturnAnchor)
	end
	if Config.Areas.Parkour then
		activityModels.Parkour = makeParkourCourse(plaza, worldPosition + Config.Areas.Parkour.Offset, Config.Areas.Parkour, lobbyReturnAnchor)
	end
	if Config.Areas.Duel then
		activityModels.Duel = makeDuelRing(plaza, worldPosition + Config.Areas.Duel.Offset, Config.Areas.Duel)
	end
	if Config.Areas.TargetRange then
		activityModels.TargetRange = makeTargetRange(plaza, worldPosition + Config.Areas.TargetRange.Offset, Config.Areas.TargetRange, lobbyReturnAnchor)
	end
	if Config.Areas.Salvage then
		activityModels.Salvage = makeSalvageRun(plaza, worldPosition + Config.Areas.Salvage.Offset, Config.Areas.Salvage, lobbyReturnAnchor)
	end

	local transitAreas = {
		Training = {
			Offset = Vector3.new(-68, 0, -18),
			Color = Config.Areas.Training.Color,
			Accent = Config.Areas.Training.Accent,
			Title = Config.Areas.Training.Title,
			TransitStyle = "training",
		},
		Parkour = {
			Offset = Vector3.new(-68, 0, 28),
			Color = Config.Areas.Parkour.Color,
			Accent = Config.Areas.Parkour.Accent,
			Title = Config.Areas.Parkour.Title,
			TransitStyle = "training",
		},
		Duel = {
			Offset = Vector3.new(68, 0, -20),
			Color = Config.Areas.Duel.Color,
			Accent = Config.Areas.Duel.Accent,
			Title = Config.Areas.Duel.Title,
			TransitStyle = "combat",
		},
		TargetRange = {
			Offset = Vector3.new(68, 0, 26),
			Color = Config.Areas.TargetRange.Color,
			Accent = Config.Areas.TargetRange.Accent,
			Title = Config.Areas.TargetRange.Title,
			TransitStyle = "combat",
		},
		Salvage = {
			Offset = Vector3.new(-8, 0, -76),
			Color = Config.Areas.Salvage.Color,
			Accent = Config.Areas.Salvage.Accent,
			Title = Config.Areas.Salvage.Title,
			TransitStyle = "salvage",
		},
		QuestBoard = {
			Offset = Vector3.new(0, 0, 74),
			Color = Config.Areas.QuestBoard.Color,
			Accent = Config.Areas.QuestBoard.Accent,
			Title = Config.Areas.QuestBoard.Title,
			TransitStyle = "deploy",
		},
	}

	for areaName, palette in pairs(transitAreas) do
		local target = worldPosition + palette.Offset
		local zone = makeGlowPart(
			plaza,
			areaName .. "ZoneGlow",
			Vector3.new(10, 0.05, 10),
			CFrame.new(target + Vector3.new(0, 0.88, 0)),
			palette.Accent,
			0.95
		)
		zone.CanCollide = false
		zone.CanQuery = false

		local marker = makePart(
			plaza,
			"Part",
			areaName .. "Marker",
			Vector3.new(1.8, 5.6, 1.8),
			CFrame.new(target + Vector3.new(0, 2.8, 0)),
			Color3.fromRGB(50, 56, 66),
			Enum.Material.Metal
		)
		marker.CanQuery = false

		local cap = makeGlowPart(
			plaza,
			areaName .. "MarkerCap",
			Vector3.new(2.2, 0.14, 2.2),
			marker.CFrame * CFrame.new(0, 2.4, 0),
			palette.Accent,
			0.5
		)
		local pulse = Instance.new("PointLight")
		pulse.Range = 20
		pulse.Brightness = 0.42
		pulse.Color = palette.Accent
		pulse.Parent = cap

		attachWorldText(marker, palette.Title, Vector3.new(0, 4.1, 0), palette.Accent, Vector2.new(116, 22))
	end

	local trainingEntry = activityModels.Training and activityModels.Training:FindFirstChild("EntryPad")
	if trainingEntry and trainingEntry:IsA("BasePart") then
		addTravelPad(plaza, "TrainingTransit", worldPosition + transitAreas.Training.Offset, Config.Areas.Training, trainingEntry, "Train", "Training Yard", "Travel to the drill yard", Vector3.new(0, 4, 6))
	end
	local parkourEntry = activityModels.Parkour and activityModels.Parkour:FindFirstChild("StartPad")
	if parkourEntry and parkourEntry:IsA("BasePart") then
		addTravelPad(plaza, "ParkourTransit", worldPosition + transitAreas.Parkour.Offset, Config.Areas.Parkour, parkourEntry, "Parkour", "Parkour Line", "Travel to the movement course", Vector3.new(0, 4, 0))
	end
	local duelEntry = activityModels.Duel and activityModels.Duel:FindFirstChild("ReturnPad")
	if duelEntry and duelEntry:IsA("BasePart") then
		addTravelPad(plaza, "DuelTransit", worldPosition + transitAreas.Duel.Offset, Config.Areas.Duel, duelEntry, "Duel", "Duel Ring", "Travel to the spar ring", Vector3.new(0, 4, -6))
	end
	local rangeEntry = activityModels.TargetRange and activityModels.TargetRange:FindFirstChild("FiringLine")
	if rangeEntry and rangeEntry:IsA("BasePart") then
		addTravelPad(plaza, "RangeTransit", worldPosition + transitAreas.TargetRange.Offset, Config.Areas.TargetRange, rangeEntry, "Range", "Target Range", "Travel to the firing lanes", Vector3.new(0, 4, 0))
	end
	local salvageEntry = activityModels.Salvage and activityModels.Salvage:FindFirstChild("StartPad")
	if salvageEntry and salvageEntry:IsA("BasePart") then
		addTravelPad(plaza, "SalvageTransit", worldPosition + transitAreas.Salvage.Offset, Config.Areas.Salvage, salvageEntry, "Salvage", "Salvage Run", "Travel to the cache sweep lane", Vector3.new(0, 4, 0))
	end

	makeGuidePaths(plaza, worldPosition, transitAreas)

	local westDrillLane = makeGlowPart(
		plaza,
		"WestDrillLane",
		Vector3.new(10, 0.08, 46),
		CFrame.new(worldPosition + Vector3.new(-68, 0.32, 4)),
		Color3.fromRGB(236, 214, 152),
		0.86
	)
	westDrillLane.CanCollide = false
	westDrillLane.CanQuery = false
	for _, offset in ipairs({
		Vector3.new(-82, 2.8, -18),
		Vector3.new(-82, 2.8, 18),
	}) do
		local scaffold = makePart(
			plaza,
			"Part",
			"WestDrillScaffold",
			Vector3.new(2.2, 5.6, 18),
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(118, 102, 72),
			Enum.Material.Metal
		)
		scaffold.CanQuery = false
	end

	local eastCombatSpine = makePart(
		plaza,
		"Part",
		"EastCombatSpine",
		Vector3.new(8, 1.8, 48),
		CFrame.new(worldPosition + Vector3.new(68, 0.94, 3)),
		Color3.fromRGB(58, 64, 70),
		Enum.Material.Metal
	)
	eastCombatSpine.CanQuery = false
	local eastCombatStripe = makeGlowPart(
		plaza,
		"EastCombatStripe",
		Vector3.new(1.2, 0.08, 44),
		eastCombatSpine.CFrame * CFrame.new(0, 0.98, 0),
		Color3.fromRGB(255, 188, 112),
		0.76
	)
	eastCombatStripe.CanCollide = false
	eastCombatStripe.CanQuery = false

	local salvageCorridor = makePart(
		plaza,
		"Part",
		"SalvageCorridor",
		Vector3.new(18, 0.24, 42),
		CFrame.new(worldPosition + Vector3.new(-8, 0.16, -96)),
		Color3.fromRGB(96, 86, 72),
		Enum.Material.DiamondPlate
	)
	salvageCorridor.CanCollide = false
	salvageCorridor.CanQuery = false
	local salvageGuide = makeGlowPart(
		plaza,
		"SalvageCorridorGuide",
		Vector3.new(3.2, 0.08, 36),
		CFrame.new(worldPosition + Vector3.new(-8, 0.32, -96)),
		Color3.fromRGB(232, 210, 156),
		0.82
	)
	salvageGuide.CanCollide = false
	salvageGuide.CanQuery = false

	local deployPad = makeDeployPad(plaza, worldPosition + Config.Areas.Deploy.Offset)
	for index, offset in ipairs({
		Vector3.new(-28, 0, 78),
		Vector3.new(28, 0, 78),
	}) do
		local stagingBay = makePart(
			plaza,
			"Part",
			"DeployDistrictBay" .. tostring(index),
			Vector3.new(8, 3.4, 12),
			CFrame.new(worldPosition + offset + Vector3.new(0, 2.1, 0)),
			Color3.fromRGB(84, 58, 58),
			Enum.Material.Metal
		)
		stagingBay.CanQuery = false
		local bayGlow = makeGlowPart(
			plaza,
			"DeployDistrictBayGlow" .. tostring(index),
			Vector3.new(8, 0.12, 10),
			stagingBay.CFrame * CFrame.new(0, 2.18, 0),
			Color3.fromRGB(255, 190, 160),
			0.74
		)
		bayGlow.CanCollide = false
		bayGlow.CanQuery = false
	end
	addCargoStack("WestCargoStack", worldPosition + Vector3.new(-86, 0, -22), Color3.fromRGB(160, 186, 234))
	addCargoStack("EastCargoStack", worldPosition + Vector3.new(82, 0, -24), Color3.fromRGB(182, 232, 204))
	addCargoStack("SouthCargoStack", worldPosition + Vector3.new(18, 0, 88), Color3.fromRGB(236, 214, 156))
	addWatchTower("WestWatch", worldPosition + Vector3.new(-108, 0, -78), Color3.fromRGB(194, 214, 255))
	addWatchTower("EastWatch", worldPosition + Vector3.new(108, 0, -78), Color3.fromRGB(214, 236, 196))
	addLeaderboardMonument(worldPosition + Vector3.new(-92, 0, 90))
	makePathSegment(plaza, "ArchiveWalkLink", worldPosition + Vector3.new(-34, 0, 54), worldPosition + Vector3.new(-88, 0, 76), Color3.fromRGB(220, 206, 168))
	makePathSegment(plaza, "ArchiveWalkLinkWide", worldPosition + Vector3.new(-40, 0, 62), worldPosition + Vector3.new(-90, 0, 84), Color3.fromRGB(198, 184, 150))
	makePathSegment(plaza, "DeploySpineLink", worldPosition + Vector3.new(0, 0, 44), worldPosition + Vector3.new(0, 0, 90), Color3.fromRGB(255, 188, 154))
	for _, offset in ipairs({
		Vector3.new(-58, 1.5, 68),
		Vector3.new(-72, 1.5, 78),
		Vector3.new(-86, 1.5, 88),
	}) do
		local bollard = makePart(
			plaza,
			"Part",
			"ArchiveWalkBollard",
			Vector3.new(1, 2.6, 1),
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(92, 82, 64),
			Enum.Material.Metal
		)
		bollard.CanQuery = false
		local cap = makeGlowPart(
			plaza,
			"ArchiveWalkBollardGlow",
			Vector3.new(1.3, 0.14, 1.3),
			bollard.CFrame * CFrame.new(0, 1.22, 0),
			Color3.fromRGB(255, 238, 204),
			0.42
		)
		cap.CanCollide = false
		cap.CanQuery = false
	end
	for _, info in ipairs({
		{ "ArchiveStand", Vector3.new(-72, 1.2, 82), Vector3.new(7.2, 2.2, 2.2), Color3.fromRGB(96, 82, 60), Enum.Material.WoodPlanks },
		{ "ArchiveBench", Vector3.new(-60, 0.7, 74), Vector3.new(6.2, 1.0, 2.2), Color3.fromRGB(108, 96, 74), Enum.Material.WoodPlanks },
		{ "ArchiveCase", Vector3.new(-76, 1.0, 88), Vector3.new(3.2, 1.6, 2.6), Color3.fromRGB(168, 154, 126), Enum.Material.SmoothPlastic },
	}) do
		local prop = makePart(
			plaza,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]),
			info[4],
			info[5]
		)
		prop.CanQuery = false
	end

	for _, info in ipairs({
		{
			"TrainingMarshal",
			"Trainer Sol",
			Vector3.new(-60, 0, -34),
			Vector3.new(-60, 0, -34),
			Color3.fromRGB(244, 212, 152),
			0.18,
			{
				title = "Trainer Sol",
				role = "Combat drill supervisor",
				body = "Use the training yard to warm up movement, line up target drills, and get your hands settled before you step into a live run.",
				actionLabel = "Train",
				actionPanel = "",
			},
		},
		{
			"NorthPatrol",
			"Quartermaster Rhea",
			Vector3.new(0, 0, -46),
			Vector3.new(0, 0, -46),
			Color3.fromRGB(245, 215, 156),
			0.1,
			{
				title = "Quartermaster Rhea",
				role = "Supply corridor lead",
				body = "Fresh bunker stock is routed through my lane. Weapons, cosmetics, and premium support are all logged through the quartermaster board.",
				actionLabel = "Open Shop",
				actionPanel = "Shop",
			},
		},
		{
			"WestPatrol",
			"Officer Vale",
			Vector3.new(-46, 0, 28),
			Vector3.new(-46, 0, 28),
			Color3.fromRGB(171, 205, 237),
			0.35,
			{
				title = "Officer Vale",
				role = "Fireteam command liaison",
				body = "Solo runs are allowed, but organized squads survive longer. Keep your roster tight, lock privacy when needed, and assign a clear lead before deployment.",
				actionLabel = "Open Squad",
				actionPanel = "Squad",
			},
		},
		{
			"ParkourMarshal",
			"Runner Kez",
			Vector3.new(-70, 0, 16),
			Vector3.new(-70, 0, 16),
			Color3.fromRGB(206, 220, 255),
			0.27,
			{
				title = "Runner Kez",
				role = "Movement drill lead",
				body = "The parkour line is for movement reps. Hit the platforms, chain your jumps, and get comfortable reading elevation before a live mission.",
				actionLabel = "Run Course",
				actionPanel = "",
			},
		},
		{
			"DuelMarshal",
			"Arbiter Nox",
			Vector3.new(60, 0, -34),
			Vector3.new(60, 0, -34),
			Color3.fromRGB(244, 182, 182),
			0.74,
			{
				title = "Arbiter Nox",
				role = "Spar ring referee",
				body = "Step into either duel corner to stage a quick 1v1. Use the ring for bragging rights, screenshots, and pre-run squad rivalry.",
				actionLabel = "Enter Ring",
				actionPanel = "",
			},
		},
		{
			"RangeMarshal",
			"Spotter Hale",
			Vector3.new(70, 0, 16),
			Vector3.new(70, 0, 16),
			Color3.fromRGB(186, 238, 214),
			0.69,
			{
				title = "Spotter Hale",
				role = "Range controller",
				body = "Use the target range to settle recoil, spacing, and aim before you burn deploy tokens on a live run.",
				actionLabel = "Enter Range",
				actionPanel = "",
			},
		},
		{
			"SalvageMarshal",
			"Broker Venn",
			Vector3.new(0, 0, -58),
			Vector3.new(0, 0, -58),
			Color3.fromRGB(244, 214, 168),
			0.52,
			{
				title = "Broker Venn",
				role = "Salvage route coordinator",
				body = "The salvage lane is a speed sweep. Hit every cache, reach extract clean, and keep your run tight if you want repeatable payout.",
				actionLabel = "Start Run",
				actionPanel = "",
			},
		},
		{
			"EastPatrol",
			"Dispatcher Iona",
			Vector3.new(46, 0, 28),
			Vector3.new(46, 0, 28),
			Color3.fromRGB(173, 227, 214),
			0.62,
			{
				title = "Dispatcher Iona",
				role = "Comms and roster control",
				body = "Use the comms lounge to spot online survivors and push invites before the next cycle starts. The social board stays live while you remain in lobby.",
				actionLabel = "Open Comms",
				actionPanel = "Social",
			},
		},
		{
			"SouthPatrol",
			"Marshal Kade",
			Vector3.new(0, 0, 54),
			Vector3.new(0, 0, 54),
			Color3.fromRGB(255, 214, 214),
			0.82,
			{
				title = "Marshal Kade",
				role = "Deployment marshal",
				body = "Mission staging is armed and ready. Lock your loadout, spend any skill points, and use the HUD deploy button once the squad is set.",
				actionLabel = "Close",
				actionPanel = "",
			},
		},
		{
			"OpsCoordinator",
			"Coordinator Nyra",
			Vector3.new(0, 0, 40),
			Vector3.new(0, 0, 40),
			Color3.fromRGB(198, 228, 132),
			0.54,
			{
				title = "Coordinator Nyra",
				role = "Operations board keeper",
				body = "Daily bunker stipends and weekly supporter crates rotate through my board. Check the live objective timing and collect anything ready before you deploy.",
				actionLabel = "Open Ops Board",
				actionPanel = "QuestBoard",
			},
		},
	}) do
		addPatrolNpc(info[1], info[2], worldPosition + info[3], worldPosition + info[4], info[5], info[6], info[7])
	end

	task.spawn(function()
		while plaza.Parent == root and root.Parent == Workspace do
			local t = Workspace:GetServerTimeNow()
			for index, entry in ipairs(beaconLights) do
				local wobble = math.sin(t * 0.7 + index * 0.9)
				if entry.fogOnly then
					entry.part.CFrame = entry.baseCFrame * CFrame.new(wobble * 8, math.sin(t * 0.22 + index) * 1.2, 0)
					entry.part.Transparency = 0.9 + ((math.sin(t * 0.45 + index) + 1) * 0.02)
				elseif entry.scanOnly then
					entry.part.CFrame = entry.baseCFrame * CFrame.Angles(0, math.rad(wobble * 32), 0)
				else
					entry.part.CFrame = entry.baseCFrame * CFrame.Angles(0, math.rad(wobble * 24), 0)
					if entry.light then
						entry.light.Brightness = 0.45 + ((math.sin(t * 1.4 + index) + 1) * 0.18)
					end
				end
			end
			for _, actor in ipairs(ambientActors) do
				local travelAlpha = (math.sin(t * actor.speed + actor.phase * math.pi * 2) + 1) * 0.5
				local anchor = actor.stationary and actor.routeStart or actor.routeStart:Lerp(actor.routeEnd, travelAlpha)
				local lookTarget = if actor.stationary
					then (actor.idleLookTarget + Vector3.new(math.sin(t * 0.55 + actor.phase) * 1.4, 0, math.cos(t * 0.4 + actor.phase) * 0.6))
					else actor.routeStart:Lerp(actor.routeEnd, math.clamp(travelAlpha + 0.02, 0, 1))
				local reactionTarget = nil
				local nearestDistance = math.huge
				for _, player in ipairs(Players:GetPlayers()) do
					local character = player.Character
					local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
					if targetRoot and player:GetAttribute("InMission") ~= true then
						local distance = (targetRoot.Position - actor.root.Position).Magnitude
						if distance < nearestDistance and distance <= 18 then
							nearestDistance = distance
							reactionTarget = targetRoot.Position + Vector3.new(0, 1.4, 0)
						end
					end
				end
				local reactionAlpha = reactionTarget and math.clamp(1 - (nearestDistance / 18), 0, 1) or 0
				if reactionTarget then
					lookTarget = lookTarget:Lerp(reactionTarget, 0.78)
				end
				local bob = math.sin(t * 2.2 + actor.phase * 4) * 0.08
				local stride = math.sin(t * 4.4 + actor.phase * 6) * (actor.stationary and 0.12 or 1)
				local breathing = math.sin(t * 2.8 + actor.phase * 7) * 0.05
				local rootCFrame = CFrame.lookAt(anchor + Vector3.new(0, bob, 0), lookTarget + Vector3.new(0, bob, 0))
				actor.root.CFrame = rootCFrame
				if actor.seated then
					if actor.seatBase then
						actor.seatBase.CFrame = rootCFrame * CFrame.new(0, -1.15, 0.4)
					end
					if actor.seatBack then
						actor.seatBack.CFrame = rootCFrame * CFrame.new(0, 0.55, 1.62)
					end
					actor.torso.CFrame = rootCFrame * CFrame.new(0, 0.95 + (breathing * 0.2), -0.18) * CFrame.Angles(math.rad(-8), 0, 0)
					actor.chestPlate.CFrame = actor.torso.CFrame * CFrame.new(0, 0, -0.48)
					actor.chestStrip.CFrame = actor.chestPlate.CFrame * CFrame.new(0, 0.52, -0.18)
					actor.utilityBelt.CFrame = rootCFrame * CFrame.new(0, -0.18, 0.22) * CFrame.Angles(math.rad(-10), 0, 0)
					actor.backpack.CFrame = rootCFrame * CFrame.new(0, 1.02, 0.98) * CFrame.Angles(math.rad(-10), 0, 0)
					actor.backpackRoll.CFrame = rootCFrame * CFrame.new(0, 2.02, 0.92)
					actor.head.CFrame = rootCFrame * CFrame.new(0, 2.92 + (breathing * 0.12), -0.34) * CFrame.Angles(math.rad(-6), math.rad(stride * 6), 0)
					actor.helmet.CFrame = actor.head.CFrame * CFrame.new(0, 0.44, 0)
					actor.helmetBrim.CFrame = actor.head.CFrame * CFrame.new(0, 0.08, -0.04)
					actor.leftArm.CFrame = rootCFrame * CFrame.new(-1.58, 0.98, -0.08) * CFrame.Angles(math.rad(26 + (stride * 5)), 0, math.rad(6))
					actor.rightArm.CFrame = rootCFrame * CFrame.new(1.58, 0.98, -0.14) * CFrame.Angles(math.rad(18 - (stride * 5)), 0, math.rad(-8))
					actor.leftShoulder.CFrame = rootCFrame * CFrame.new(-1.42, 1.98, -0.08)
					actor.rightShoulder.CFrame = rootCFrame * CFrame.new(1.42, 1.98, -0.08)
					actor.leftLeg.CFrame = rootCFrame * CFrame.new(-0.62, -1.04, -0.76) * CFrame.Angles(math.rad(88), 0, 0)
					actor.rightLeg.CFrame = rootCFrame * CFrame.new(0.62, -1.04, -0.76) * CFrame.Angles(math.rad(88), 0, 0)
					actor.leftBoot.CFrame = rootCFrame * CFrame.new(-0.62, -1.14, -2.02) * CFrame.Angles(math.rad(90), 0, 0)
					actor.rightBoot.CFrame = rootCFrame * CFrame.new(0.62, -1.14, -2.02) * CFrame.Angles(math.rad(90), 0, 0)
				else
					actor.torso.CFrame = rootCFrame * CFrame.new(0, 1.5 + (breathing * 0.3), 0)
					actor.chestPlate.CFrame = rootCFrame * CFrame.new(0, 1.5 + (breathing * 0.3), -0.48)
					actor.chestStrip.CFrame = actor.chestPlate.CFrame * CFrame.new(0, 0.52, -0.18)
					actor.utilityBelt.CFrame = rootCFrame * CFrame.new(0, 0.18, 0)
					actor.backpack.CFrame = rootCFrame * CFrame.new(0, 1.48, 0.84)
					actor.backpackRoll.CFrame = rootCFrame * CFrame.new(0, 2.62, 0.78)
					actor.head.CFrame = rootCFrame * CFrame.new(0, 3.7 + (breathing * 0.15), 0) * CFrame.Angles(0, math.rad(stride * 8), 0)
					actor.helmet.CFrame = actor.head.CFrame * CFrame.new(0, 0.44, 0)
					actor.helmetBrim.CFrame = actor.head.CFrame * CFrame.new(0, 0.08, -0.04)
					actor.leftArm.CFrame = rootCFrame * CFrame.new(-1.7, 1.42, 0) * CFrame.Angles(math.rad(stride * 18), 0, math.rad(5))
					actor.rightArm.CFrame = rootCFrame * CFrame.new(1.7, 1.42, 0) * CFrame.Angles(math.rad(-stride * 18), 0, math.rad(-5))
					actor.leftShoulder.CFrame = rootCFrame * CFrame.new(-1.46, 2.48, 0) * CFrame.Angles(math.rad(stride * 4), 0, math.rad(3))
					actor.rightShoulder.CFrame = rootCFrame * CFrame.new(1.46, 2.48, 0) * CFrame.Angles(math.rad(-stride * 4), 0, math.rad(-3))
					actor.leftLeg.CFrame = rootCFrame * CFrame.new(-0.64, -0.34, 0) * CFrame.Angles(math.rad(-stride * 14), 0, 0)
					actor.rightLeg.CFrame = rootCFrame * CFrame.new(0.64, -0.34, 0) * CFrame.Angles(math.rad(stride * 14), 0, 0)
					actor.leftBoot.CFrame = rootCFrame * CFrame.new(-0.64, -2.06, 0.08) * CFrame.Angles(math.rad(-stride * 10), 0, 0)
					actor.rightBoot.CFrame = rootCFrame * CFrame.new(0.64, -2.06, 0.08) * CFrame.Angles(math.rad(stride * 10), 0, 0)
				end
				actor.visor.CFrame = actor.head.CFrame * CFrame.new(0, 0.02, -0.76)
				actor.shoulderLamp.CFrame = rootCFrame * CFrame.new(1.0, actor.seated and 1.76 or 2.2, -0.2)
				actor.baseRing.CFrame = CFrame.new(anchor.X, 0.58, anchor.Z)
				actor.promptHalo.CFrame = CFrame.new(anchor.X, 0.62, anchor.Z)
				actor.baseRing.Transparency = 0.88 - (reactionAlpha * 0.3)
				actor.baseRing.Color = actor.accent:Lerp(Color3.fromRGB(255, 248, 228), reactionAlpha * 0.28)
				actor.promptHalo.Transparency = 0.94 - (reactionAlpha * 0.5)
				actor.promptHalo.Size = Vector3.new(4.2 + (reactionAlpha * 1.2), 0.08, 4.2 + (reactionAlpha * 1.2))
				actor.chestStrip.Transparency = 0.44 - (reactionAlpha * 0.16)
				actor.visor.Transparency = 0.08 - (reactionAlpha * 0.03)
				actor.shoulderLamp.Transparency = 0.08 - (reactionAlpha * 0.03)
				actor.greetingFrame.BackgroundTransparency = 1 - (reactionAlpha * 0.46)
				actor.greetingStroke.Transparency = 1 - (reactionAlpha * 0.7)
				actor.greetingLabel.TextTransparency = 1 - (reactionAlpha * 0.94)
				actor.greetingGui.StudsOffset = Vector3.new(0, (actor.seated and 5.1 or 5.8) + (reactionAlpha * 0.16), 0)
				if actor.scanner then
					actor.scanner.Brightness = 1.45 + (reactionAlpha * 0.55)
				end
				if actor.shoulderLight then
					actor.shoulderLight.Brightness = 0.45 + (reactionAlpha * 0.42)
				end
			end
			for _, effect in ipairs(animatedBoardEffects) do
				if effect.type == "boardRail" then
					local wave = (math.sin(t * (1.2 + effect.speed) + effect.phase) + 1) * 0.5
					if effect.gradient then
						effect.gradient.Offset = Vector2.new(0, (wave * 2) - 1)
						effect.gradient.Rotation = 90 + math.sin(t * 0.9 + effect.phase) * (effect.isChampion and 16 or 10)
					end
					if effect.frame then
						effect.frame.BackgroundTransparency = (effect.isChampion and 0.06 or 0.14) + ((1 - wave) * (effect.isChampion and 0.12 or 0.18))
						effect.frame.BackgroundColor3 = effect.base:Lerp(effect.glow, wave * (effect.isChampion and 0.68 or 0.4))
					end
					if effect.badge then
						effect.badge.TextColor3 = effect.base:Lerp(effect.glow, wave * (effect.isChampion and 0.82 or 0.55))
						effect.badge.BackgroundTransparency = (effect.isChampion and 0.04 or 0.1) + ((1 - wave) * (effect.isChampion and 0.08 or 0.12))
					end
					if effect.badgeGradient then
						effect.badgeGradient.Offset = Vector2.new((wave * 2) - 1, 0)
					end
					if effect.crownIcon then
						effect.crownIcon.TextColor3 = effect.base:Lerp(effect.glow, wave * 0.9)
						effect.crownIcon.Rotation = math.sin(t * 1.8 + effect.phase) * 3
					end
				elseif effect.type == "crownGlow" and effect.part then
					local wave = (math.sin(t * 1.35) + 1) * 0.5
					effect.part.Transparency = effect.baseTransparency - (wave * 0.12)
					effect.part.Color = effect.baseColor:Lerp(Color3.fromRGB(255, 228, 164), wave * 0.35)
				elseif effect.type == "leaderPulse" and effect.part then
					local wave = (math.sin((t * 1.6) + (effect.phase or 0)) + 1) * 0.5
					effect.part.Transparency = effect.baseTransparency - (wave * 0.16)
					effect.part.Color = effect.baseColor:Lerp(effect.pulseColor or effect.baseColor, wave * 0.55)
					if effect.light then
						effect.light.Brightness = 0.24 + (wave * 0.42)
					end
				elseif effect.type == "leaderboardUiFlow" and effect.gradient then
					local wave = math.sin((t * 0.8) + (effect.phase or 0))
					effect.gradient.Offset = Vector2.new(0, wave)
					effect.gradient.Rotation = 90 + (math.sin((t * 0.45) + (effect.phase or 0)) * 8)
				elseif effect.type == "leaderboardTab" and effect.frame and effect.stroke then
					local activeCategory = effect.board and effect.board:GetAttribute("ActiveCategory") or "Levels"
					local isActive = activeCategory == effect.categoryKey
					local wave = (math.sin((t * 2.1) + (effect.phase or 0)) + 1) * 0.5
					effect.frame.BackgroundColor3 = isActive and Color3.fromRGB(206, 222, 238) or Color3.fromRGB(228, 224, 214)
					effect.frame.TextColor3 = isActive and Color3.fromRGB(24, 38, 62) or Color3.fromRGB(58, 48, 34)
					effect.frame.BackgroundTransparency = isActive and (0.04 + ((1 - wave) * 0.08)) or 0
					effect.stroke.Color = isActive and Color3.fromRGB(102, 166, 236) or Color3.fromRGB(168, 154, 132)
					effect.stroke.Transparency = isActive and (0.04 + ((1 - wave) * 0.12)) or 0.28
				end
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

local function makeBunkerShell(root: Instance, worldPosition: Vector3)
	local shell = Instance.new("Model")
	shell.Name = "BunkerShell"
	shell.Parent = root

	local wallColor = Color3.fromRGB(64, 72, 82)
	local trimColor = Color3.fromRGB(122, 134, 150)
	local radius = 126

	local floor = makePart(shell, "Part", "Floor", Vector3.new(280, 2, 280), CFrame.new(worldPosition + Vector3.new(0, -1, 0)), Color3.fromRGB(74, 82, 92), Enum.Material.Concrete)
	floor.CanQuery = false

	local innerFloor = makePart(shell, "Part", "InnerFloor", Vector3.new(220, 0.3, 220), CFrame.new(worldPosition + Vector3.new(0, 0.16, 0)), Color3.fromRGB(102, 112, 124), Enum.Material.DiamondPlate)
	innerFloor.CanCollide = false
	innerFloor.CanQuery = false

	local north = makePart(shell, "Part", "NorthWall", Vector3.new(280, 28, 6), CFrame.new(worldPosition + Vector3.new(0, 14, -radius)), wallColor, Enum.Material.Metal)
	local south = makePart(shell, "Part", "SouthWall", Vector3.new(280, 28, 6), CFrame.new(worldPosition + Vector3.new(0, 14, radius)), wallColor, Enum.Material.Metal)
	local west = makePart(shell, "Part", "WestWall", Vector3.new(6, 28, 280), CFrame.new(worldPosition + Vector3.new(-radius, 14, 0)), wallColor, Enum.Material.Metal)
	local east = makePart(shell, "Part", "EastWall", Vector3.new(6, 28, 280), CFrame.new(worldPosition + Vector3.new(radius, 14, 0)), wallColor, Enum.Material.Metal)
	local ceiling = makePart(shell, "Part", "Ceiling", Vector3.new(280, 4, 280), CFrame.new(worldPosition + Vector3.new(0, 28, 0)), Color3.fromRGB(54, 60, 68), Enum.Material.DiamondPlate)

	north.CanQuery = false
	south.CanQuery = false
	west.CanQuery = false
	east.CanQuery = false
	ceiling.CanQuery = false

	makeGlowPart(shell, "NorthTrim", Vector3.new(264, 0.35, 1.2), CFrame.new(worldPosition + Vector3.new(0, 20, -122.8)), trimColor, 0.2)
	makeGlowPart(shell, "SouthTrim", Vector3.new(264, 0.35, 1.2), CFrame.new(worldPosition + Vector3.new(0, 20, 122.8)), trimColor, 0.2)
	makeGlowPart(shell, "WestTrim", Vector3.new(1.2, 0.35, 264), CFrame.new(worldPosition + Vector3.new(-122.8, 20, 0)), trimColor, 0.2)
	makeGlowPart(shell, "EastTrim", Vector3.new(1.2, 0.35, 264), CFrame.new(worldPosition + Vector3.new(122.8, 20, 0)), trimColor, 0.2)

	for index = -2, 2 do
		local z = index * 42
		local beam = makePart(shell, "Part", "CeilingBeam" .. tostring(index + 3), Vector3.new(240, 2, 4), CFrame.new(worldPosition + Vector3.new(0, 25.5, z)), Color3.fromRGB(86, 94, 104), Enum.Material.Metal)
		beam.CanQuery = false
		local lightBar = makeGlowPart(shell, "LightBar" .. tostring(index + 3), Vector3.new(84, 0.4, 2), CFrame.new(worldPosition + Vector3.new(0, 24.1, z)), Color3.fromRGB(224, 236, 255), 0.18)
		local light = Instance.new("PointLight")
		light.Range = 52
		light.Brightness = 1.15
		light.Color = Color3.fromRGB(222, 232, 255)
		light.Parent = lightBar
	end

	for _, info in ipairs({
		{"North", Vector3.new(-84, 10, -123), Vector3.new(6, 18, 2)},
		{"North", Vector3.new(84, 10, -123), Vector3.new(6, 18, 2)},
		{"South", Vector3.new(-84, 10, 123), Vector3.new(6, 18, 2)},
		{"South", Vector3.new(84, 10, 123), Vector3.new(6, 18, 2)},
		{"West", Vector3.new(-123, 10, -84), Vector3.new(2, 18, 6)},
		{"West", Vector3.new(-123, 10, 84), Vector3.new(2, 18, 6)},
		{"East", Vector3.new(123, 10, -84), Vector3.new(2, 18, 6)},
		{"East", Vector3.new(123, 10, 84), Vector3.new(2, 18, 6)},
	}) do
		local rib = makePart(
			shell,
			"Part",
			info[1] .. "WallRib",
			info[3],
			CFrame.new(worldPosition + info[2]),
			Color3.fromRGB(94, 102, 114),
			Enum.Material.Metal
		)
		rib.CanQuery = false
		local sconce = makeGlowPart(
			shell,
			info[1] .. "WallSconce",
			Vector3.new(math.max(info[3].X - 0.5, 1), 0.18, math.max(info[3].Z - 0.5, 1)),
			rib.CFrame * CFrame.new(0, 6.5, 0),
			Color3.fromRGB(170, 190, 214),
			0.78
		)
		local fill = Instance.new("PointLight")
		fill.Range = 20
		fill.Brightness = 0.52
		fill.Color = Color3.fromRGB(210, 220, 236)
		fill.Parent = sconce
	end

	for index = -2, 2 do
		local x = index * 42
		local seam = makePart(shell, "Part", "FloorSeamX" .. tostring(index + 3), Vector3.new(2, 0.08, 220), CFrame.new(worldPosition + Vector3.new(x, 0.22, 0)), Color3.fromRGB(116, 124, 136), Enum.Material.Metal)
		seam.CanCollide = false
		seam.CanQuery = false
		seam.Transparency = 0.72
	end

	for index = -2, 2 do
		local z = index * 42
		local seam = makePart(shell, "Part", "FloorSeamZ" .. tostring(index + 3), Vector3.new(220, 0.08, 2), CFrame.new(worldPosition + Vector3.new(0, 0.22, z)), Color3.fromRGB(116, 124, 136), Enum.Material.Metal)
		seam.CanCollide = false
		seam.CanQuery = false
		seam.Transparency = 0.72
	end
end

local function applyLobbyLighting()
	Lighting.ClockTime = 5
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(148, 156, 170)
	Lighting.OutdoorAmbient = Color3.fromRGB(94, 102, 116)
	Lighting.ColorShift_Top = Color3.fromRGB(48, 62, 84)
	Lighting.ColorShift_Bottom = Color3.fromRGB(24, 28, 36)
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.GlobalShadows = true

	local atmosphere = Lighting:FindFirstChild("LobbyAtmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "LobbyAtmosphere"
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.11
	atmosphere.Offset = 0.05
	atmosphere.Color = Color3.fromRGB(188, 198, 214)
	atmosphere.Decay = Color3.fromRGB(118, 126, 140)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.18

	local bloom = Lighting:FindFirstChild("LobbyBloom")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "LobbyBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.015
	bloom.Size = 10
	bloom.Threshold = 3.6

	local colorCorrection = Lighting:FindFirstChild("LobbyColorCorrection")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "LobbyColorCorrection"
		colorCorrection.Parent = Lighting
	end
	colorCorrection.Brightness = 0.08
	colorCorrection.Contrast = 0.06
	colorCorrection.Saturation = 0
	colorCorrection.TintColor = Color3.fromRGB(236, 240, 255)
end

local function makeArch(model: Instance, worldPosition: Vector3, palette)
	local left = makePart(
		model,
		"Part",
		"ArchLeft",
		Vector3.new(2, 12, 2),
		CFrame.new(worldPosition + Vector3.new(-9, 6, -4)),
		Color3.fromRGB(26, 29, 34),
		Enum.Material.Metal
	)
	left.CanQuery = false

	local right = makePart(
		model,
		"Part",
		"ArchRight",
		Vector3.new(2, 12, 2),
		CFrame.new(worldPosition + Vector3.new(9, 6, -4)),
		Color3.fromRGB(26, 29, 34),
		Enum.Material.Metal
	)
	right.CanQuery = false

	local top = makePart(
		model,
		"Part",
		"ArchTop",
		Vector3.new(20, 2, 2),
		CFrame.new(worldPosition + Vector3.new(0, 11, -4)),
		palette.Color:Lerp(Color3.fromRGB(36, 40, 46), 0.45),
		Enum.Material.SmoothPlastic
	)
	top.CanCollide = false
	top.CanQuery = false

	makeGlowPart(model, "ArchGlow", Vector3.new(20.4, 0.16, 2.2), CFrame.new(worldPosition + Vector3.new(0, 10.2, -4)), palette.Accent, 0.78)
end

local function makeStationBackdrop(model: Instance, worldPosition: Vector3, palette)
	local wall = makePart(
		model,
		"Part",
		"BackdropWall",
		Vector3.new(22, 7, 1.2),
		CFrame.new(worldPosition + Vector3.new(0, 4.1, 10.8)),
		Color3.fromRGB(54, 60, 70),
		Enum.Material.Metal
	)
	wall.CanQuery = false

	local inset = makePart(
		model,
		"Part",
		"BackdropInset",
		Vector3.new(16, 4.2, 0.5),
		CFrame.new(worldPosition + Vector3.new(0, 4.2, 10.02)),
		Color3.fromRGB(36, 42, 50),
		Enum.Material.SmoothPlastic
	)
	inset.CanCollide = false
	inset.CanQuery = false

	local stripe = makePart(
		model,
		"Part",
		"BackdropStripe",
		Vector3.new(16, 0.24, 0.32),
		CFrame.new(worldPosition + Vector3.new(0, 6.8, 9.72)),
		palette.Color:Lerp(Color3.fromRGB(70, 76, 84), 0.52),
		Enum.Material.Neon
	)
	stripe.CanCollide = false
	stripe.CanQuery = false
	stripe.Transparency = 0.84
end

local function makeStationProp(model: Instance, name: string, size: Vector3, offset: Vector3, palette, material: Enum.Material?, colorOverride: Color3?)
	local prop = makePart(
		model,
		"Part",
		name,
		size,
		CFrame.new(model.PrimaryPart.Position + offset),
		colorOverride or palette.Accent,
		material or Enum.Material.SmoothPlastic
	)
	prop.CanQuery = false
	return prop
end

local function addBayFillLight(model: Instance, name: string, worldPosition: Vector3, color: Color3, brightness: number, range: number)
	local bayLight = makeGlowPart(model, name, Vector3.new(2.8, 0.18, 2.8), CFrame.new(worldPosition), color, 0.72)
	bayLight.CanCollide = false
	bayLight.CanQuery = false
	local fill = Instance.new("PointLight")
	fill.Range = range
	fill.Brightness = brightness
	fill.Color = color
	fill.Parent = bayLight
	return bayLight
end

local function makeStationAlcove(model: Instance, worldPosition: Vector3, palette)
	local wallColor = Color3.fromRGB(56, 64, 74)
	local leftWall = makePart(
		model,
		"Part",
		"AlcoveLeft",
		Vector3.new(2, 12, 20),
		CFrame.new(worldPosition + Vector3.new(-13, 6, 2)),
		wallColor,
		Enum.Material.Metal
	)
	leftWall.CanQuery = false

	local rightWall = makePart(
		model,
		"Part",
		"AlcoveRight",
		Vector3.new(2, 12, 20),
		CFrame.new(worldPosition + Vector3.new(13, 6, 2)),
		wallColor,
		Enum.Material.Metal
	)
	rightWall.CanQuery = false

	local canopy = makePart(
		model,
		"Part",
		"AlcoveCanopy",
		Vector3.new(24, 1.5, 20),
		CFrame.new(worldPosition + Vector3.new(0, 11.8, 2)),
		Color3.fromRGB(50, 56, 64),
		Enum.Material.Metal
	)
	canopy.CanQuery = false

	local canopyLip = makePart(
		model,
		"Part",
		"CanopyLip",
		Vector3.new(20, 0.6, 1.2),
		CFrame.new(worldPosition + Vector3.new(0, 10.8, -5.2)),
		Color3.fromRGB(110, 118, 132),
		Enum.Material.Metal
	)
	canopyLip.CanQuery = false

	makeGlowPart(model, "AlcoveAccentLeft", Vector3.new(0.18, 8, 16), CFrame.new(worldPosition + Vector3.new(-11.9, 6, 3)), palette.Color, 0.88)
	makeGlowPart(model, "AlcoveAccentRight", Vector3.new(0.18, 8, 16), CFrame.new(worldPosition + Vector3.new(11.9, 6, 3)), palette.Color, 0.88)

	local floorInset = makePart(
		model,
		"Part",
		"AlcoveFloorInset",
		Vector3.new(20, 0.18, 14),
		CFrame.new(worldPosition + Vector3.new(0, 0.82, 0.6)),
		Color3.fromRGB(48, 54, 62),
		Enum.Material.DiamondPlate
	)
	floorInset.CanQuery = false

	local entryPadLeft = makePart(
		model,
		"Part",
		"EntryPadLeft",
		Vector3.new(5.2, 0.12, 5.2),
		CFrame.new(worldPosition + Vector3.new(-5.6, 0.8, -6.8)),
		palette.Color:Lerp(Color3.fromRGB(28, 32, 38), 0.52),
		Enum.Material.Metal
	)
	entryPadLeft.CanCollide = false
	entryPadLeft.CanQuery = false

	local entryPadRight = makePart(
		model,
		"Part",
		"EntryPadRight",
		Vector3.new(5.2, 0.12, 5.2),
		CFrame.new(worldPosition + Vector3.new(5.6, 0.8, -6.8)),
		palette.Color:Lerp(Color3.fromRGB(28, 32, 38), 0.52),
		Enum.Material.Metal
	)
	entryPadRight.CanCollide = false
	entryPadRight.CanQuery = false

	local frameLeft = makePart(
		model,
		"Part",
		"FrontFrameLeft",
		Vector3.new(1.1, 9.2, 1.1),
		CFrame.new(worldPosition + Vector3.new(-10.2, 4.8, -2.4)),
		Color3.fromRGB(56, 64, 72),
		Enum.Material.Metal
	)
	frameLeft.CanQuery = false

	local frameRight = makePart(
		model,
		"Part",
		"FrontFrameRight",
		Vector3.new(1.1, 9.2, 1.1),
		CFrame.new(worldPosition + Vector3.new(10.2, 4.8, -2.4)),
		Color3.fromRGB(56, 64, 72),
		Enum.Material.Metal
	)
	frameRight.CanQuery = false

	local rearBulkhead = makePart(
		model,
		"Part",
		"RearBulkhead",
		Vector3.new(24, 12, 2),
		CFrame.new(worldPosition + Vector3.new(0, 6, 13)),
		Color3.fromRGB(68, 76, 88),
		Enum.Material.Metal
	)
	rearBulkhead.CanQuery = false

	local sideInsetLeft = makePart(
		model,
		"Part",
		"SideInsetLeft",
		Vector3.new(3, 8, 6),
		CFrame.new(worldPosition + Vector3.new(-10.4, 4.5, 10)),
		Color3.fromRGB(44, 50, 58),
		Enum.Material.SmoothPlastic
	)
	sideInsetLeft.CanQuery = false

	local sideInsetRight = makePart(
		model,
		"Part",
		"SideInsetRight",
		Vector3.new(3, 8, 6),
		CFrame.new(worldPosition + Vector3.new(10.4, 4.5, 10)),
		Color3.fromRGB(28, 32, 38),
		Enum.Material.SmoothPlastic
	)
	sideInsetRight.CanQuery = false

	for _, offset in ipairs({
		Vector3.new(-7.4, 9.7, 1.8),
		Vector3.new(7.4, 9.7, 1.8),
	}) do
		local bayLight = makeGlowPart(
			model,
			"BayLight",
			Vector3.new(5.6, 0.18, 1),
			CFrame.new(worldPosition + offset),
			palette.Accent:Lerp(Color3.fromRGB(220, 228, 238), 0.45),
			0.74
		)
		local fill = Instance.new("PointLight")
		fill.Range = 18
		fill.Brightness = 0.45
		fill.Color = palette.Accent:Lerp(Color3.fromRGB(214, 224, 236), 0.55)
		fill.Parent = bayLight
	end
end

local function makeStationForecourt(model: Instance, name: string, worldPosition: Vector3, palette)
	local deckColor = palette.Color:Lerp(Color3.fromRGB(56, 62, 72), 0.56)
	local trimColor = palette.Accent:Lerp(Color3.fromRGB(236, 242, 250), 0.18)

	local forecourt = makePart(
		model,
		"Part",
		"Forecourt",
		Vector3.new(24, 0.24, 22),
		CFrame.new(worldPosition + Vector3.new(0, 0.82, -10.5)),
		deckColor,
		Enum.Material.DiamondPlate
	)
	forecourt.CanCollide = false
	forecourt.CanQuery = false

	local forecourtFrame = makePart(
		model,
		"Part",
		"ForecourtFrame",
		Vector3.new(28, 0.12, 26),
		CFrame.new(worldPosition + Vector3.new(0, 0.9, -10.5)),
		trimColor,
		Enum.Material.Metal
	)
	forecourtFrame.Transparency = 0.84
	forecourtFrame.CanCollide = false
	forecourtFrame.CanQuery = false

	local laneCore = makePart(
		model,
		"Part",
		"ForecourtLaneCore",
		Vector3.new(5.2, 0.08, 20),
		CFrame.new(worldPosition + Vector3.new(0, 0.96, -10.5)),
		palette.Accent,
		Enum.Material.Neon
	)
	laneCore.Transparency = 0.84
	laneCore.CanCollide = false
	laneCore.CanQuery = false

	for index, offsetX in ipairs({ -8.6, 8.6 }) do
		local sideRail = makePart(
			model,
			"Part",
			"ForecourtRail" .. tostring(index),
			Vector3.new(0.9, 2.4, 18),
			CFrame.new(worldPosition + Vector3.new(offsetX, 1.3, -10.5)),
			Color3.fromRGB(66, 72, 82),
			Enum.Material.Metal
		)
		sideRail.CanQuery = false

		local sideRailGlow = makePart(
			model,
			"Part",
			"ForecourtRailGlow" .. tostring(index),
			Vector3.new(0.18, 1.8, 14),
			CFrame.new(worldPosition + Vector3.new(offsetX * 0.98, 1.3, -10.5)),
			palette.Accent,
			Enum.Material.Neon
		)
		sideRailGlow.Transparency = 0.76
		sideRailGlow.CanCollide = false
		sideRailGlow.CanQuery = false
	end

	for index, offsetX in ipairs({ -6.2, 6.2 }) do
		local bollard = makePart(
			model,
			"Part",
			"ForecourtBollard" .. tostring(index),
			Vector3.new(1.1, 2.4, 1.1),
			CFrame.new(worldPosition + Vector3.new(offsetX, 1.24, -18.8)),
			Color3.fromRGB(76, 84, 98),
			Enum.Material.Metal
		)
		bollard.CanQuery = false

		local bollardLight = makeGlowPart(
			model,
			"ForecourtBollardLight" .. tostring(index),
			Vector3.new(1.4, 0.12, 1.4),
			bollard.CFrame * CFrame.new(0, 1.18, 0),
			trimColor,
			0.58
		)
		local fill = Instance.new("PointLight")
		fill.Range = 12
		fill.Brightness = 0.34
		fill.Color = trimColor
		fill.Parent = bollardLight
	end

	if name == "Shop" or name == "Inventory" or name == "QuestBoard" then
		local crateLeft = makePart(
			model,
			"Part",
			"ForecourtCrateLeft",
			Vector3.new(2.8, 2.1, 2.8),
			CFrame.new(worldPosition + Vector3.new(-10.4, 1.05, -4.2)),
			Color3.fromRGB(88, 74, 56),
			Enum.Material.WoodPlanks
		)
		crateLeft.CanQuery = false

		local crateRight = makePart(
			model,
			"Part",
			"ForecourtCrateRight",
			Vector3.new(2.8, 2.1, 2.8),
			CFrame.new(worldPosition + Vector3.new(10.4, 1.05, -4.2)),
			Color3.fromRGB(88, 74, 56),
			Enum.Material.WoodPlanks
		)
		crateRight.CanQuery = false
	elseif name == "Social" or name == "Squad" then
		local leftSeat = makePart(
			model,
			"Part",
			"ForecourtSeatLeft",
			Vector3.new(3.8, 1.1, 2.4),
			CFrame.new(worldPosition + Vector3.new(-10.4, 0.76, -4.6)),
			Color3.fromRGB(74, 80, 88),
			Enum.Material.SmoothPlastic
		)
		leftSeat.CanCollide = false
		leftSeat.CanQuery = false

		local rightSeat = makePart(
			model,
			"Part",
			"ForecourtSeatRight",
			Vector3.new(3.8, 1.1, 2.4),
			CFrame.new(worldPosition + Vector3.new(10.4, 0.76, -4.6)),
			Color3.fromRGB(74, 80, 88),
			Enum.Material.SmoothPlastic
		)
		rightSeat.CanCollide = false
		rightSeat.CanQuery = false
	elseif name == "SkillTree" then
		for index, offsetX in ipairs({ -9.8, 9.8 }) do
			local nodePillar = makePart(
				model,
				"Part",
				"ForecourtNodePillar" .. tostring(index),
				Vector3.new(1.8, 4.2, 1.8),
				CFrame.new(worldPosition + Vector3.new(offsetX, 2.1, -4.8)),
				Color3.fromRGB(86, 92, 120),
				Enum.Material.Metal
			)
			nodePillar.CanQuery = false

			local nodeGlow = makePart(
				model,
				"Part",
				"ForecourtNodeGlow" .. tostring(index),
				Vector3.new(2.4, 0.14, 2.4),
				nodePillar.CFrame * CFrame.new(0, 2.18, 0),
				palette.Accent,
				Enum.Material.Neon
			)
			nodeGlow.Transparency = 0.66
			nodeGlow.CanCollide = false
			nodeGlow.CanQuery = false
		end
	end
end

local function decorateStation(model: Instance, name: string, worldPosition: Vector3, palette)
	makeStationForecourt(model, name, worldPosition, palette)
	makeGlowPart(model, "FloorHalo", Vector3.new(12, 0.1, 12), CFrame.new(worldPosition + Vector3.new(0, 0.8, 0)), palette.Color, 0.86)
	addBayFillLight(model, "BayFillCenter", worldPosition + Vector3.new(0, 9.6, 1.8), palette.Accent:Lerp(Color3.fromRGB(255, 255, 255), 0.25), 0.62, 20)
	addBayFillLight(model, "BayFillRear", worldPosition + Vector3.new(0, 7.8, 8.8), palette.Accent:Lerp(Color3.fromRGB(255, 255, 255), 0.12), 0.38, 14)

	if name == "QuestBoard" then
		local signPost = model:FindFirstChild("SignPost")
		if signPost and signPost:IsA("BasePart") then
			signPost.CFrame = CFrame.new(worldPosition + Vector3.new(0, 6.1, 8.2))
		end

		local signTop = model:FindFirstChild("SignTop")
		if signTop and signTop:IsA("BasePart") then
			signTop.Size = Vector3.new(6.6, 0.7, 0.4)
			signTop.CFrame = CFrame.new(worldPosition + Vector3.new(0, 6.25, 8.55))
		end

		local alcoveLeft = model:FindFirstChild("AlcoveLeft")
		if alcoveLeft and alcoveLeft:IsA("BasePart") then
			alcoveLeft.Size = Vector3.new(1.2, 9.4, 12)
			alcoveLeft.CFrame = CFrame.new(worldPosition + Vector3.new(-9.4, 4.7, 4.8))
		end

		local alcoveRight = model:FindFirstChild("AlcoveRight")
		if alcoveRight and alcoveRight:IsA("BasePart") then
			alcoveRight.Size = Vector3.new(1.2, 9.4, 12)
			alcoveRight.CFrame = CFrame.new(worldPosition + Vector3.new(9.4, 4.7, 4.8))
		end

		local canopy = model:FindFirstChild("AlcoveCanopy")
		if canopy and canopy:IsA("BasePart") then
			canopy.Size = Vector3.new(18, 1, 12)
			canopy.CFrame = CFrame.new(worldPosition + Vector3.new(0, 9.8, 4.8))
		end

		local canopyLip = model:FindFirstChild("CanopyLip")
		if canopyLip and canopyLip:IsA("BasePart") then
			canopyLip.Size = Vector3.new(12, 0.42, 0.9)
			canopyLip.CFrame = CFrame.new(worldPosition + Vector3.new(0, 8.9, -0.6))
		end

		local frameLeft = model:FindFirstChild("FrontFrameLeft")
		if frameLeft and frameLeft:IsA("BasePart") then
			frameLeft.Size = Vector3.new(0.8, 6.4, 0.8)
			frameLeft.CFrame = CFrame.new(worldPosition + Vector3.new(-7.8, 3.5, -0.8))
		end

		local frameRight = model:FindFirstChild("FrontFrameRight")
		if frameRight and frameRight:IsA("BasePart") then
			frameRight.Size = Vector3.new(0.8, 6.4, 0.8)
			frameRight.CFrame = CFrame.new(worldPosition + Vector3.new(7.8, 3.5, -0.8))
		end

		local rearBulkhead = model:FindFirstChild("RearBulkhead")
		if rearBulkhead and rearBulkhead:IsA("BasePart") then
			rearBulkhead.Size = Vector3.new(18, 8.2, 1.2)
			rearBulkhead.CFrame = CFrame.new(worldPosition + Vector3.new(0, 4.4, 10.2))
		end

		local backdropWall = model:FindFirstChild("BackdropWall")
		if backdropWall and backdropWall:IsA("BasePart") then
			backdropWall.Size = Vector3.new(16, 5.4, 0.8)
			backdropWall.CFrame = CFrame.new(worldPosition + Vector3.new(0, 4.1, 9.7))
		end

		local backdropInset = model:FindFirstChild("BackdropInset")
		if backdropInset and backdropInset:IsA("BasePart") then
			backdropInset.Size = Vector3.new(12, 3.4, 0.34)
			backdropInset.CFrame = CFrame.new(worldPosition + Vector3.new(0, 4.0, 9.1))
		end

		local backdropStripe = model:FindFirstChild("BackdropStripe")
		if backdropStripe and backdropStripe:IsA("BasePart") then
			backdropStripe.Size = Vector3.new(12, 0.18, 0.24)
			backdropStripe.CFrame = CFrame.new(worldPosition + Vector3.new(0, 6.05, 8.92))
		end
	end

	if name == "Shop" then
		makeStationProp(model, "Counter", Vector3.new(14, 4, 3), Vector3.new(0, 2, 2), palette, Enum.Material.WoodPlanks, Color3.fromRGB(128, 104, 76))
		makeStationProp(model, "CrateLeft", Vector3.new(4, 4, 4), Vector3.new(-7, 2, 5), palette, Enum.Material.WoodPlanks, Color3.fromRGB(102, 82, 58))
		makeStationProp(model, "CrateRight", Vector3.new(4, 3, 4), Vector3.new(7, 1.5, 5), palette, Enum.Material.WoodPlanks, Color3.fromRGB(102, 82, 58))
		makeStationProp(model, "TokenBoard", Vector3.new(7, 3.2, 0.5), Vector3.new(-5.6, 4.2, 8.6), palette, Enum.Material.SmoothPlastic, Color3.fromRGB(130, 98, 70))
		makeStationProp(model, "HangingLamp", Vector3.new(1.6, 2.8, 1.6), Vector3.new(0, 8.2, -1.2), palette, Enum.Material.Metal, Color3.fromRGB(178, 134, 78))
		makeStationProp(model, "ShelfLeft", Vector3.new(3, 7, 1.2), Vector3.new(-8.5, 3.6, 9.8), palette, Enum.Material.Metal, Color3.fromRGB(78, 68, 58))
		makeStationProp(model, "ShelfRight", Vector3.new(3, 7, 1.2), Vector3.new(8.5, 3.6, 9.8), palette, Enum.Material.Metal, Color3.fromRGB(78, 68, 58))
		makeStationProp(model, "RearStock", Vector3.new(8, 3, 1), Vector3.new(0, 2.2, 10), palette, Enum.Material.WoodPlanks, Color3.fromRGB(120, 96, 70))
		makeStationProp(model, "MarketCanopy", Vector3.new(14, 0.8, 5), Vector3.new(0, 7.6, 1.8), palette, Enum.Material.WoodPlanks, Color3.fromRGB(154, 120, 72))
		makeStationProp(model, "DisplayCase", Vector3.new(6, 1.8, 2.4), Vector3.new(0, 4.6, 4.2), palette, Enum.Material.Glass, Color3.fromRGB(212, 194, 164)).Transparency = 0.38
		makeStationProp(model, "SupplyStackA", Vector3.new(2.2, 2.2, 2.2), Vector3.new(-4.4, 1.2, 8.4), palette, Enum.Material.WoodPlanks, Color3.fromRGB(112, 88, 60))
		makeStationProp(model, "SupplyStackB", Vector3.new(2.2, 3.4, 2.2), Vector3.new(4.4, 1.8, 8.2), palette, Enum.Material.WoodPlanks, Color3.fromRGB(112, 88, 60))
		makeStationProp(model, "BarrelStack", Vector3.new(2.8, 3.6, 2.8), Vector3.new(-9.4, 1.8, 7.2), palette, Enum.Material.Metal, Color3.fromRGB(86, 72, 52))
		makeStationProp(model, "RationShelfCenter", Vector3.new(7.2, 0.4, 2), Vector3.new(0, 5.4, 9.2), palette, Enum.Material.WoodPlanks, Color3.fromRGB(132, 104, 74))
		makeStationProp(model, "AmmoCaseLeft", Vector3.new(2.4, 1.4, 2.8), Vector3.new(-8.6, 0.95, 3.6), palette, Enum.Material.Metal, Color3.fromRGB(92, 82, 62))
		makeStationProp(model, "AmmoCaseRight", Vector3.new(2.4, 1.4, 2.8), Vector3.new(8.6, 0.95, 3.6), palette, Enum.Material.Metal, Color3.fromRGB(92, 82, 62))
	elseif name == "Squad" then
		makeStationProp(model, "CommandTable", Vector3.new(12, 2, 6), Vector3.new(0, 1.2, 2), palette, Enum.Material.Metal, Color3.fromRGB(52, 62, 74))
		makeStationProp(model, "TacScreenLeft", Vector3.new(2.2, 4.4, 0.4), Vector3.new(-6, 3.6, 6), palette, Enum.Material.Neon).Transparency = 0.66
		makeStationProp(model, "TacScreenRight", Vector3.new(2.2, 4.4, 0.4), Vector3.new(6, 3.6, 6), palette, Enum.Material.Neon).Transparency = 0.66
		makeStationProp(model, "RearConsole", Vector3.new(10, 2.6, 1.2), Vector3.new(0, 1.8, 10), palette, Enum.Material.Metal, Color3.fromRGB(56, 66, 78))
		makeStationProp(model, "MapPanel", Vector3.new(8, 3.8, 0.4), Vector3.new(0, 5.2, 10.1), palette, Enum.Material.Neon).Transparency = 0.72
		makeStationProp(model, "LockerLeft", Vector3.new(2.8, 8, 2.4), Vector3.new(-8.4, 4, 7.8), palette, Enum.Material.Metal, Color3.fromRGB(58, 68, 82))
		makeStationProp(model, "LockerRight", Vector3.new(2.8, 8, 2.4), Vector3.new(8.4, 4, 7.8), palette, Enum.Material.Metal, Color3.fromRGB(58, 68, 82))
		makeStationProp(model, "BriefingStrip", Vector3.new(10, 0.24, 0.4), Vector3.new(0, 8.6, 9.9), palette, Enum.Material.Neon, Color3.fromRGB(134, 182, 236)).Transparency = 0.52
		makeStationProp(model, "OpsCrate", Vector3.new(3.6, 2.4, 3.6), Vector3.new(0, 1.4, 7.6), palette, Enum.Material.Metal, Color3.fromRGB(44, 54, 66))
		makeStationProp(model, "BriefingSeatsLeft", Vector3.new(3, 1.2, 2.6), Vector3.new(-5.4, 0.9, 4.8), palette, Enum.Material.SmoothPlastic, Color3.fromRGB(74, 82, 94))
		makeStationProp(model, "BriefingSeatsRight", Vector3.new(3, 1.2, 2.6), Vector3.new(5.4, 0.9, 4.8), palette, Enum.Material.SmoothPlastic, Color3.fromRGB(74, 82, 94))
		makeStationProp(model, "WallGrid", Vector3.new(9.5, 0.3, 0.4), Vector3.new(0, 6.4, 10.25), palette, Enum.Material.Neon, Color3.fromRGB(142, 196, 255)).Transparency = 0.82
		makeStationProp(model, "FireteamRackLeft", Vector3.new(2.2, 6.6, 1.1), Vector3.new(-10, 3.4, 5.8), palette, Enum.Material.Metal, Color3.fromRGB(76, 88, 102))
		makeStationProp(model, "FireteamRackRight", Vector3.new(2.2, 6.6, 1.1), Vector3.new(10, 3.4, 5.8), palette, Enum.Material.Metal, Color3.fromRGB(76, 88, 102))
		makeStationProp(model, "BriefingStripLower", Vector3.new(8.4, 0.18, 0.4), Vector3.new(0, 4.4, 10.05), palette, Enum.Material.Neon, Color3.fromRGB(110, 168, 228)).Transparency = 0.72
	elseif name == "Social" then
		makeStationProp(model, "BenchLeft", Vector3.new(6, 1.5, 2), Vector3.new(-5, 0.9, 3), palette, Enum.Material.WoodPlanks, Color3.fromRGB(84, 90, 82))
		makeStationProp(model, "BenchRight", Vector3.new(6, 1.5, 2), Vector3.new(5, 0.9, 3), palette, Enum.Material.WoodPlanks, Color3.fromRGB(84, 90, 82))
		makeStationProp(model, "Board", Vector3.new(12, 6, 0.8), Vector3.new(0, 4, 6), palette, Enum.Material.SmoothPlastic, Color3.fromRGB(58, 74, 70))
		makeStationProp(model, "SideTable", Vector3.new(4, 1.4, 4), Vector3.new(0, 0.8, 9.4), palette, Enum.Material.WoodPlanks, Color3.fromRGB(90, 94, 84))
		makeStationProp(model, "PosterLeft", Vector3.new(2.4, 3.4, 0.3), Vector3.new(-7, 4.5, 10.1), palette, Enum.Material.SmoothPlastic, Color3.fromRGB(74, 108, 100))
		makeStationProp(model, "PosterRight", Vector3.new(2.4, 3.4, 0.3), Vector3.new(7, 4.5, 10.1), palette, Enum.Material.SmoothPlastic, Color3.fromRGB(74, 108, 100))
		makeStationProp(model, "CafeCounter", Vector3.new(8, 2.4, 2.2), Vector3.new(0, 1.3, 7.8), palette, Enum.Material.WoodPlanks, Color3.fromRGB(98, 92, 78))
		makeStationProp(model, "LoungeTableLeft", Vector3.new(2.4, 1.1, 2.4), Vector3.new(-7.2, 0.65, 8.6), palette, Enum.Material.WoodPlanks, Color3.fromRGB(86, 88, 80))
		makeStationProp(model, "LoungeTableRight", Vector3.new(2.4, 1.1, 2.4), Vector3.new(7.2, 0.65, 8.6), palette, Enum.Material.WoodPlanks, Color3.fromRGB(86, 88, 80))
		makeStationProp(model, "NeonNotice", Vector3.new(8.4, 0.22, 0.4), Vector3.new(0, 7.8, 10.05), palette, Enum.Material.Neon, Color3.fromRGB(112, 204, 186)).Transparency = 0.64
		makeStationProp(model, "LoungeSeatLeft", Vector3.new(3.2, 1.6, 2.8), Vector3.new(-6.4, 0.9, 6.1), palette, Enum.Material.SmoothPlastic, Color3.fromRGB(68, 82, 78))
		makeStationProp(model, "LoungeSeatRight", Vector3.new(3.2, 1.6, 2.8), Vector3.new(6.4, 0.9, 6.1), palette, Enum.Material.SmoothPlastic, Color3.fromRGB(68, 82, 78))
		makeStationProp(model, "CommsStand", Vector3.new(2.4, 4.4, 1.2), Vector3.new(0, 2.4, 9.2), palette, Enum.Material.Metal, Color3.fromRGB(72, 104, 96))
		makeStationProp(model, "MessageRail", Vector3.new(10.4, 0.22, 0.4), Vector3.new(0, 5.4, 10.04), palette, Enum.Material.Neon, Color3.fromRGB(132, 220, 196)).Transparency = 0.76
		makeStationProp(model, "CafeShelf", Vector3.new(7.2, 0.36, 1.2), Vector3.new(0, 4.8, 8.8), palette, Enum.Material.WoodPlanks, Color3.fromRGB(106, 96, 82))
	elseif name == "Inventory" then
		makeStationProp(model, "LockerBankLeft", Vector3.new(3.2, 8.6, 2.6), Vector3.new(-8.4, 4.3, 8.2), palette, Enum.Material.Metal, Color3.fromRGB(70, 86, 110))
		makeStationProp(model, "LockerBankRight", Vector3.new(3.2, 8.6, 2.6), Vector3.new(8.4, 4.3, 8.2), palette, Enum.Material.Metal, Color3.fromRGB(70, 86, 110))
		makeStationProp(model, "LoadoutBench", Vector3.new(10.6, 1.8, 4.8), Vector3.new(0, 1.1, 3.2), palette, Enum.Material.Metal, Color3.fromRGB(52, 68, 90))
		makeStationProp(model, "ArmorCase", Vector3.new(7.6, 3.4, 1), Vector3.new(0, 4.8, 10.1), palette, Enum.Material.Glass, Color3.fromRGB(188, 212, 240)).Transparency = 0.42
		makeStationProp(model, "WeaponRackLeft", Vector3.new(1.8, 5.8, 1), Vector3.new(-10, 3.1, 5.4), palette, Enum.Material.Metal, Color3.fromRGB(88, 106, 132))
		makeStationProp(model, "WeaponRackRight", Vector3.new(1.8, 5.8, 1), Vector3.new(10, 3.1, 5.4), palette, Enum.Material.Metal, Color3.fromRGB(88, 106, 132))
		makeStationProp(model, "InventoryStrip", Vector3.new(9.8, 0.2, 0.4), Vector3.new(0, 6.4, 10.02), palette, Enum.Material.Neon, Color3.fromRGB(166, 204, 250)).Transparency = 0.72
	elseif name == "SkillTree" then
		makeStationProp(model, "BranchTable", Vector3.new(11.6, 1.6, 5.4), Vector3.new(0, 1.0, 2.8), palette, Enum.Material.Metal, Color3.fromRGB(62, 68, 94))
		makeStationProp(model, "BranchScreen", Vector3.new(9.8, 4.4, 0.4), Vector3.new(0, 5.1, 10.08), palette, Enum.Material.Neon, Color3.fromRGB(184, 194, 244)).Transparency = 0.72
		makeStationProp(model, "NodeColumnLeft", Vector3.new(2.2, 6.4, 1), Vector3.new(-8.4, 3.4, 7.2), palette, Enum.Material.Metal, Color3.fromRGB(88, 96, 126))
		makeStationProp(model, "NodeColumnCenter", Vector3.new(2.2, 7.4, 1), Vector3.new(0, 3.9, 7.6), palette, Enum.Material.Metal, Color3.fromRGB(98, 104, 136))
		makeStationProp(model, "NodeColumnRight", Vector3.new(2.2, 6.4, 1), Vector3.new(8.4, 3.4, 7.2), palette, Enum.Material.Metal, Color3.fromRGB(88, 96, 126))
		makeStationProp(model, "TreeStripUpper", Vector3.new(10.6, 0.18, 0.4), Vector3.new(0, 7.7, 10.04), palette, Enum.Material.Neon, Color3.fromRGB(188, 198, 250)).Transparency = 0.66
		makeStationProp(model, "TreeStripLower", Vector3.new(8.2, 0.18, 0.4), Vector3.new(0, 4.5, 10.04), palette, Enum.Material.Neon, Color3.fromRGB(150, 166, 228)).Transparency = 0.76
	elseif name == "QuestBoard" then
		makeStationProp(model, "OpsCounter", Vector3.new(9.2, 1.8, 3), Vector3.new(0, 0.95, 2.1), palette, Enum.Material.WoodPlanks, Color3.fromRGB(88, 96, 68))
		makeStationProp(model, "OpsBoardMain", Vector3.new(8.8, 3.9, 0.42), Vector3.new(0, 4.0, 9.4), palette, Enum.Material.SmoothPlastic, Color3.fromRGB(70, 88, 56))
		makeStationProp(model, "OpsBoardLeft", Vector3.new(1.8, 2.4, 0.28), Vector3.new(-5.6, 3.8, 9.52), palette, Enum.Material.SmoothPlastic, Color3.fromRGB(92, 116, 70))
		makeStationProp(model, "OpsBoardRight", Vector3.new(1.8, 2.4, 0.28), Vector3.new(5.6, 3.8, 9.52), palette, Enum.Material.SmoothPlastic, Color3.fromRGB(92, 116, 70))
		makeStationProp(model, "CrateCluster", Vector3.new(3.6, 1.8, 3.2), Vector3.new(-5.4, 1.0, 6.4), palette, Enum.Material.WoodPlanks, Color3.fromRGB(98, 92, 70))
		makeStationProp(model, "RewardCase", Vector3.new(4.2, 1.4, 2.1), Vector3.new(5.4, 0.82, 6.4), palette, Enum.Material.Metal, Color3.fromRGB(110, 122, 82))
		makeStationProp(model, "OpsStrip", Vector3.new(8.2, 0.14, 0.24), Vector3.new(0, 6.2, 9.48), palette, Enum.Material.Neon, Color3.fromRGB(216, 234, 172)).Transparency = 0.72
		makeStationProp(model, "OpsDeskLeft", Vector3.new(1.8, 0.9, 1.6), Vector3.new(-7.2, 0.62, 4.8), palette, Enum.Material.WoodPlanks, Color3.fromRGB(92, 88, 66))
		makeStationProp(model, "OpsDeskRight", Vector3.new(1.8, 0.9, 1.6), Vector3.new(7.2, 0.62, 4.8), palette, Enum.Material.WoodPlanks, Color3.fromRGB(92, 88, 66))
	end
end

local function makeCentralHub(root: Instance, worldPosition: Vector3)
	local hub = Instance.new("Model")
	hub.Name = "CentralHub"
	hub.Parent = root

	local outerPad = makePart(
		hub,
		"Part",
		"OuterPad",
		Vector3.new(20, 0.24, 20),
		CFrame.new(worldPosition + Vector3.new(0, 2.18, 0)),
		Color3.fromRGB(118, 132, 152),
		Enum.Material.Metal
	)
	outerPad.Transparency = 0.62
	outerPad.CanCollide = false
	outerPad.CanQuery = false

	local plinth = makePart(
		hub,
		"Part",
		"HubPlinth",
		Vector3.new(10, 0.8, 10),
		CFrame.new(worldPosition + Vector3.new(0, 2.02, 0)),
		Color3.fromRGB(78, 86, 98),
		Enum.Material.Metal
	)
	plinth.CanCollide = false
	plinth.CanQuery = false

	local innerPad = makePart(
		hub,
		"Part",
		"InnerPad",
		Vector3.new(6.5, 0.22, 6.5),
		CFrame.new(worldPosition + Vector3.new(0, 2.5, 0)),
		Color3.fromRGB(114, 126, 140),
		Enum.Material.SmoothPlastic
	)
	innerPad.CanQuery = false
	innerPad.CanCollide = false

	local ring = makeGlowPart(hub, "HubRing", Vector3.new(18, 0.12, 18), CFrame.new(worldPosition + Vector3.new(0, 2.08, 0)), Color3.fromRGB(148, 176, 214), 0.56)
	ring.CanCollide = false
	ring.CanQuery = false
	local ringOuter = makeGlowPart(hub, "HubRingOuter", Vector3.new(24, 0.08, 24), CFrame.new(worldPosition + Vector3.new(0, 1.28, 0)), Color3.fromRGB(118, 142, 176), 0.82)
	ringOuter.CanCollide = false
	ringOuter.CanQuery = false
	local commandCore = makePart(
		hub,
		"Part",
		"CommandCore",
		Vector3.new(4.8, 1.6, 4.8),
		CFrame.new(worldPosition + Vector3.new(0, 2.7, 0)),
		Color3.fromRGB(86, 96, 112),
		Enum.Material.SmoothPlastic
	)
	commandCore.CanQuery = false
	commandCore.CanCollide = false
	local commandGlow = makeGlowPart(hub, "CommandGlow", Vector3.new(5.6, 0.12, 5.6), CFrame.new(worldPosition + Vector3.new(0, 3.56, 0)), Color3.fromRGB(196, 214, 236), 0.56)
	commandGlow.CanCollide = false
	commandGlow.CanQuery = false
	local commandLamp = Instance.new("PointLight")
	commandLamp.Range = 18
	commandLamp.Brightness = 0.62
	commandLamp.Color = Color3.fromRGB(196, 214, 236)
	commandLamp.Parent = commandGlow
	for _, offset in ipairs({
		Vector3.new(-7.2, 0.95, -7.2),
		Vector3.new(7.2, 0.95, -7.2),
		Vector3.new(-7.2, 0.95, 7.2),
		Vector3.new(7.2, 0.95, 7.2),
	}) do
		local bollard = makePart(
			hub,
			"Part",
			"HubBollard",
			Vector3.new(0.9, 2, 0.9),
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(92, 102, 116),
			Enum.Material.Metal
		)
		bollard.CanQuery = false
		makeGlowPart(hub, "HubBollardLamp", Vector3.new(1.2, 0.1, 1.2), bollard.CFrame * CFrame.new(0, 1.08, 0), Color3.fromRGB(170, 194, 226), 0.56)
	end

	for _, info in ipairs({
		{"NorthRail", Vector3.new(0, 1.2, -10.6), Vector3.new(14, 1.6, 1)},
		{"SouthRail", Vector3.new(0, 1.2, 10.6), Vector3.new(14, 1.6, 1)},
	}) do
		local rail = makePart(
			hub,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]),
			Color3.fromRGB(78, 88, 102),
			Enum.Material.Metal
		)
		rail.CanQuery = false
	end

	for _, offset in ipairs({
		Vector3.new(-5.2, 0.9, 0),
		Vector3.new(5.2, 0.9, 0),
	}) do
		local console = makePart(
			hub,
			"Part",
			"HubConsole",
			Vector3.new(2.2, 1.1, 2.2),
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(92, 104, 118),
			Enum.Material.DiamondPlate
		)
		console.CanQuery = false
		local consoleGlow = makeGlowPart(hub, "HubConsoleGlow", Vector3.new(1.6, 0.08, 0.8), console.CFrame * CFrame.new(0, 0.6, -0.24), Color3.fromRGB(164, 196, 236), 0.76)
		consoleGlow.CanCollide = false
		consoleGlow.CanQuery = false
	end

	for _, info in ipairs({
		{"NorthWalkway", Vector3.new(0, 0.25, -18), Vector3.new(12, 0.3, 14)},
		{"SouthWalkway", Vector3.new(0, 0.25, 18), Vector3.new(12, 0.3, 14)},
	}) do
		local walkway = makePart(
			hub,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]),
			Color3.fromRGB(88, 98, 112),
			Enum.Material.DiamondPlate
		)
		walkway.CanCollide = false
		walkway.CanQuery = false
	end

	for _, offset in ipairs({
		Vector3.new(0, 0.34, -13),
		Vector3.new(0, 0.34, 13),
		Vector3.new(-13, 0.34, 0),
		Vector3.new(13, 0.34, 0),
	}) do
		local hubPlate = makePart(
			hub,
			"Part",
			"HubPlate",
			Vector3.new(7, 0.12, 4),
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(102, 114, 128),
			Enum.Material.Metal
		)
		hubPlate.CanCollide = false
		hubPlate.CanQuery = false
	end

	for _, info in ipairs({
		{"NorthNav", Vector3.new(0, 2.1, -8.6), Vector3.new(5.6, 0.12, 8)},
		{"SouthNav", Vector3.new(0, 2.1, 8.6), Vector3.new(5.6, 0.12, 8)},
		{"WestNav", Vector3.new(-8.6, 2.1, 0), Vector3.new(8, 0.12, 5.6)},
		{"EastNav", Vector3.new(8.6, 2.1, 0), Vector3.new(8, 0.12, 5.6)},
	}) do
		local navPlate = makePart(
			hub,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]),
			Color3.fromRGB(118, 128, 142),
			Enum.Material.Metal
		)
		navPlate.CanCollide = false
		navPlate.CanQuery = false
	end

	local commandPlate = makePart(
		hub,
		"Part",
		"CommandPlate",
		Vector3.new(12, 0.12, 4),
		CFrame.new(worldPosition + Vector3.new(0, 2.12, 0)),
		Color3.fromRGB(154, 176, 206),
		Enum.Material.Neon
	)
	commandPlate.CanCollide = false
	commandPlate.CanQuery = false
	commandPlate.Transparency = 0.78

	attachWorldText(commandCore, "COMMAND HUB", Vector3.new(0, 2.8, 0), Color3.fromRGB(235, 239, 244), Vector2.new(160, 34))
end

makeStation = function(root: Instance, name: string, worldPosition: Vector3, palette)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = root
	model:SetAttribute("LobbyArea", name)

	local base = makePart(
		model,
		"Part",
		"Base",
		Vector3.new(30, 1, 30),
		CFrame.new(worldPosition),
		palette.Color:Lerp(Color3.fromRGB(52, 58, 66), 0.62),
		Enum.Material.Metal
	)
	base.CanQuery = false
	CollectionService:AddTag(base, "LobbyArea")

	local trim = makePart(
		model,
		"Part",
		"Trim",
		Vector3.new(30, 0.18, 30),
		CFrame.new(worldPosition + Vector3.new(0, 0.7, 0)),
		palette.Accent,
		Enum.Material.Neon
	)
	trim.Transparency = 0.88
	trim.CanCollide = false
	trim.CanQuery = false

	local signPost = makePart(
		model,
		"Part",
		"SignPost",
		Vector3.new(1, 3.4, 1),
		CFrame.new(worldPosition + Vector3.new(0, 7.2, 8.9)),
		Color3.fromRGB(44, 48, 54),
		Enum.Material.Metal
	)
	signPost.CanQuery = false

	local signTop = makePart(
		model,
		"Part",
		"SignTop",
		Vector3.new(7.6, 0.8, 0.4),
		CFrame.new(worldPosition + Vector3.new(0, 7.4, 9.25)),
		palette.Color:Lerp(Color3.fromRGB(58, 64, 72), 0.58),
		Enum.Material.Metal
	)
	signTop.CanCollide = false
	signTop.CanQuery = false

	attachLabel(signTop, palette.Title, palette.Subtitle, palette.Accent)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StationPrompt"
	prompt.ActionText = palette.Title
	prompt.ObjectText = name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = signPost

	model.PrimaryPart = base
	decorateStation(model, name, worldPosition, palette)

	local apron = makePart(
		model,
		"Part",
		"Apron",
		Vector3.new(22, 0.3, 18),
		CFrame.new(worldPosition + Vector3.new(0, 0.76, -8)),
		Color3.fromRGB(76, 84, 94),
		Enum.Material.DiamondPlate
	)
	apron.CanCollide = false
	apron.CanQuery = false

	local lane = makePart(
		model,
		"Part",
		"Lane",
		Vector3.new(10, 0.08, 20),
		CFrame.new(worldPosition + Vector3.new(0, 0.84, -18)),
		palette.Accent,
		Enum.Material.Neon
	)
	lane.CanCollide = false
	lane.CanQuery = false
	lane.Transparency = 0.94

	return model, base, prompt
end

local function makeSpawn(root: Instance, worldPosition: Vector3)
	local spawnZone = Instance.new("Model")
	spawnZone.Name = "SpawnZone"
	spawnZone.Parent = root

	local apron = makePart(
		spawnZone,
		"Part",
		"SpawnApron",
		Vector3.new(38, 0.8, 30),
		CFrame.new(worldPosition + Vector3.new(0, 0.4, 18)),
		Color3.fromRGB(78, 86, 98),
		Enum.Material.DiamondPlate
	)
	apron.CanCollide = false
	apron.CanQuery = false

	local frame = makePart(
		spawnZone,
		"Part",
		"SpawnFrame",
		Vector3.new(42, 0.12, 34),
		CFrame.new(worldPosition + Vector3.new(0, 0.9, 18)),
		Color3.fromRGB(132, 148, 176),
		Enum.Material.Metal
	)
	frame.Transparency = 0.8
	frame.CanCollide = false
	frame.CanQuery = false

	local guide = makeGlowPart(
		spawnZone,
		"SpawnGuide",
		Vector3.new(4.2, 0.08, 30),
		CFrame.new(worldPosition + Vector3.new(0, 0.84, 14)),
		Color3.fromRGB(186, 212, 244),
		0.72
	)
	guide.CanCollide = false
	guide.CanQuery = false

	for _, info in ipairs({
		{ "SpawnWingLeft", Vector3.new(-22, 0.64, 19), Vector3.new(10, 0.48, 18), math.rad(14) },
		{ "SpawnWingRight", Vector3.new(22, 0.64, 19), Vector3.new(10, 0.48, 18), math.rad(-14) },
	}) do
		local wing = makePart(
			spawnZone,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]) * CFrame.Angles(0, info[4], 0),
			Color3.fromRGB(64, 72, 84),
			Enum.Material.Metal
		)
		wing.CanCollide = false
		wing.CanQuery = false
	end

	local gateLeft = makePart(spawnZone, "Part", "SpawnGateLeft", Vector3.new(2.4, 7.2, 2.4), CFrame.new(worldPosition + Vector3.new(-13.5, 3.6, 27)), Color3.fromRGB(66, 74, 88), Enum.Material.Metal)
	local gateRight = makePart(spawnZone, "Part", "SpawnGateRight", Vector3.new(2.4, 7.2, 2.4), CFrame.new(worldPosition + Vector3.new(13.5, 3.6, 27)), Color3.fromRGB(66, 74, 88), Enum.Material.Metal)
	gateLeft.CanQuery = false
	gateRight.CanQuery = false
	local gateTop = makePart(spawnZone, "Part", "SpawnGateTop", Vector3.new(30, 0.9, 2.6), CFrame.new(worldPosition + Vector3.new(0, 7.2, 27)), Color3.fromRGB(78, 86, 98), Enum.Material.Metal)
	gateTop.CanCollide = false
	gateTop.CanQuery = false
	local gateTopGlow = makeGlowPart(spawnZone, "SpawnGateTopGlow", Vector3.new(22, 0.08, 0.8), gateTop.CFrame * CFrame.new(0, -0.24, -0.88), Color3.fromRGB(222, 232, 244), 0.72)
	gateTopGlow.CanCollide = false
	gateTopGlow.CanQuery = false

	for _, offset in ipairs({
		Vector3.new(0, 0.88, 20),
		Vector3.new(0, 0.88, 3),
		Vector3.new(0, 0.88, -18),
	}) do
		local axisPylon = makePart(
			spawnZone,
			"Part",
			"SpawnAxisPylon",
			Vector3.new(0.9, 1.2, 0.9),
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(108, 118, 134),
			Enum.Material.Metal
		)
		axisPylon.CanCollide = false
		axisPylon.CanQuery = false
		local axisPylonGlow = makeGlowPart(spawnZone, "SpawnAxisPylonGlow", Vector3.new(1.4, 0.08, 1.4), axisPylon.CFrame * CFrame.new(0, 0.66, 0), Color3.fromRGB(232, 238, 246), 0.7)
		axisPylonGlow.CanCollide = false
		axisPylonGlow.CanQuery = false
	end

	local leftBeacon = makePart(spawnZone, "Part", "SpawnBeaconLeft", Vector3.new(2, 8, 2), CFrame.new(worldPosition + Vector3.new(-20, 4, 18)), Color3.fromRGB(74, 82, 96), Enum.Material.Metal)
	local rightBeacon = makePart(spawnZone, "Part", "SpawnBeaconRight", Vector3.new(2, 8, 2), CFrame.new(worldPosition + Vector3.new(20, 4, 18)), Color3.fromRGB(74, 82, 96), Enum.Material.Metal)
	leftBeacon.CanQuery = false
	rightBeacon.CanQuery = false
	makeGlowPart(spawnZone, "SpawnBeaconLeftGlow", Vector3.new(2.2, 0.14, 2.2), leftBeacon.CFrame * CFrame.new(0, 4.1, 0), Color3.fromRGB(186, 212, 244), 0.46)
	makeGlowPart(spawnZone, "SpawnBeaconRightGlow", Vector3.new(2.2, 0.14, 2.2), rightBeacon.CFrame * CFrame.new(0, 4.1, 0), Color3.fromRGB(186, 212, 244), 0.46)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(18, 1, 18)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Enabled = true
	spawn.Duration = 0
	spawn.Material = Enum.Material.Concrete
	spawn.Color = Color3.fromRGB(110, 122, 138)
	spawn.CFrame = CFrame.new(worldPosition + Vector3.new(0, 1.5, 18))
	spawn.Parent = spawnZone
	CollectionService:AddTag(spawn, "LobbySpawn")
	attachWorldText(spawn, "SPAWN", Vector3.new(0, 2.6, 0), Color3.fromRGB(228, 236, 246), Vector2.new(120, 28))
	return spawn
end

makeDeployPad = function(root: Instance, worldPosition: Vector3)
	local bayModel = Instance.new("Model")
	bayModel.Name = "DeployBay"
	bayModel.Parent = root

	local deployWallColor = Color3.fromRGB(72, 42, 42)
	local deployTrimColor = Color3.fromRGB(156, 88, 88)
	local deployAccent = Color3.fromRGB(255, 188, 154)

	local bayFloor = makePart(
		bayModel,
		"Part",
		"DeployBayFloor",
		Vector3.new(34, 0.45, 42),
		CFrame.new(worldPosition + Vector3.new(0, 0.24, -4)),
		Color3.fromRGB(106, 84, 84),
		Enum.Material.DiamondPlate
	)
	bayFloor.CanCollide = false
	bayFloor.CanQuery = false

	local launchConcourse = makePart(
		root,
		"Part",
		"DeployConcourse",
		Vector3.new(46, 0.36, 54),
		CFrame.new(worldPosition + Vector3.new(0, 0.18, -24)),
		Color3.fromRGB(110, 92, 90),
		Enum.Material.Concrete
	)
	launchConcourse.CanCollide = false
	launchConcourse.CanQuery = false

	local concourseInset = makePart(
		root,
		"Part",
		"DeployConcourseInset",
		Vector3.new(34, 0.08, 42),
		CFrame.new(worldPosition + Vector3.new(0, 0.4, -24)),
		Color3.fromRGB(154, 136, 130),
		Enum.Material.SmoothPlastic
	)
	concourseInset.CanCollide = false
	concourseInset.CanQuery = false

	local concourseGuide = makeGlowPart(
		root,
		"DeployConcourseGuide",
		Vector3.new(6, 0.08, 36),
		CFrame.new(worldPosition + Vector3.new(0, 0.44, -24)),
		Color3.fromRGB(255, 204, 172),
		0.82
	)
	concourseGuide.CanCollide = false
	concourseGuide.CanQuery = false
	local launchLaneMarker = makePart(
		root,
		"Part",
		"DeployLaunchLaneMarker",
		Vector3.new(6, 0.2, 6),
		CFrame.new(worldPosition + Vector3.new(0, 1.4, -10)),
		Color3.fromRGB(48, 36, 36),
		Enum.Material.Metal
	)
	launchLaneMarker.Transparency = 1
	launchLaneMarker.CanCollide = false
	launchLaneMarker.CanQuery = false
	attachWorldText(launchLaneMarker, "LAUNCH", Vector3.new(0, 0, 0), Color3.fromRGB(255, 212, 188), Vector2.new(92, 18))

	local voteApron = makePart(
		root,
		"Part",
		"DeployVoteApron",
		Vector3.new(24, 0.22, 12),
		CFrame.new(worldPosition + Vector3.new(0, 0.52, -44)),
		Color3.fromRGB(132, 92, 92),
		Enum.Material.Metal
	)
	voteApron.CanCollide = false
	voteApron.CanQuery = false
	voteApron.Transparency = 0.18
	local voteApronGlow = makeGlowPart(
		root,
		"DeployVoteApronGlow",
		Vector3.new(20, 0.08, 7.2),
		voteApron.CFrame * CFrame.new(0, 0.16, 0),
		Color3.fromRGB(255, 172, 148),
		0.72
	)
	voteApronGlow.CanCollide = false
	voteApronGlow.CanQuery = false
	attachWorldText(voteApron, "MISSION AIRLOCK", Vector3.new(0, 2.5, 0), Color3.fromRGB(255, 218, 202), Vector2.new(164, 24))
	attachWorldText(voteApron, "Squad route and launch pad", Vector3.new(0, 1.35, 0), Color3.fromRGB(244, 194, 176), Vector2.new(192, 16))

	for index, direction in ipairs({ -1, 1 }) do
		local signalPylon = makePart(
			root,
			"Part",
			"DeploySignalPylon" .. tostring(index),
			Vector3.new(2.4, 11.5, 2.4),
			CFrame.new(worldPosition + Vector3.new(14 * direction, 5.8, -46)),
			Color3.fromRGB(92, 58, 58),
			Enum.Material.Metal
		)
		signalPylon.CanQuery = false
		local signalGlow = makeGlowPart(
			root,
			"DeploySignalPylonGlow" .. tostring(index),
			Vector3.new(0.16, 8.2, 1.5),
			signalPylon.CFrame * CFrame.new(0, 0.2, 0),
			Color3.fromRGB(255, 198, 166),
			0.72
		)
		signalGlow.CanCollide = false
		signalGlow.CanQuery = false
	end

	local signalHeader = makeGlowPart(
		root,
		"DeploySignalHeader",
		Vector3.new(30, 0.12, 1.4),
		CFrame.new(worldPosition + Vector3.new(0, 11.36, -46)),
		Color3.fromRGB(255, 214, 188),
		0.78
	)
	signalHeader.CanCollide = false
	signalHeader.CanQuery = false

	for index, direction in ipairs({ -1, 1 }) do
		local sideWing = makePart(
			root,
			"Part",
			"DeployConcourseWing" .. tostring(index),
			Vector3.new(5.2, 4.2, 24),
			CFrame.new(worldPosition + Vector3.new(17.8 * direction, 2.1, -23)) * CFrame.Angles(0, math.rad(direction > 0 and -8 or 8), 0),
			Color3.fromRGB(80, 50, 50),
			Enum.Material.Metal
		)
		sideWing.CanQuery = false
		local sideStrip = makeGlowPart(
			root,
			"DeployConcourseWingGlow" .. tostring(index),
			Vector3.new(0.16, 3.2, 18),
			sideWing.CFrame * CFrame.new(-2.18 * direction, 0, 0),
			Color3.fromRGB(255, 188, 154),
			0.76
		)
		sideStrip.CanCollide = false
		sideStrip.CanQuery = false
	end

	for index, direction in ipairs({ -1, 1 }) do
		local routeConsole = makePart(
			root,
			"Part",
			"DeployRouteConsole" .. tostring(index),
			Vector3.new(2.8, 2.4, 2.2),
			CFrame.new(worldPosition + Vector3.new(9.6 * direction, 1.3, -29)),
			Color3.fromRGB(88, 58, 58),
			Enum.Material.Metal
		)
		routeConsole.CanQuery = false
		local routeScreen = makeGlowPart(
			root,
			"DeployRouteConsoleScreen" .. tostring(index),
			Vector3.new(1.6, 1.2, 0.1),
			routeConsole.CFrame * CFrame.new(0, 0.3, -1.06),
			Color3.fromRGB(255, 196, 172),
			0.42
		)
		routeScreen.CanCollide = false
		routeScreen.CanQuery = false
	end

	local bayLeftWall = makePart(
		bayModel,
		"Part",
		"DeployBayLeft",
		Vector3.new(2.6, 16, 26),
		CFrame.new(worldPosition + Vector3.new(-16, 8, -4)),
		deployWallColor,
		Enum.Material.Metal
	)
	bayLeftWall.CanQuery = false

	local bayRightWall = makePart(
		bayModel,
		"Part",
		"DeployBayRight",
		Vector3.new(2.6, 16, 26),
		CFrame.new(worldPosition + Vector3.new(16, 8, -4)),
		deployWallColor,
		Enum.Material.Metal
	)
	bayRightWall.CanQuery = false

	local bayCanopy = makePart(
		bayModel,
		"Part",
		"DeployBayCanopy",
		Vector3.new(34, 2, 20),
		CFrame.new(worldPosition + Vector3.new(0, 13.5, -4)),
		Color3.fromRGB(58, 34, 34),
		Enum.Material.Metal
	)
	bayCanopy.CanQuery = false

	local bayFrontBrace = makePart(
		bayModel,
		"Part",
		"DeployBayFrontBrace",
		Vector3.new(30, 1.2, 2.4),
		CFrame.new(worldPosition + Vector3.new(0, 11.3, -14.8)),
		Color3.fromRGB(132, 66, 66),
		Enum.Material.Metal
	)
	bayFrontBrace.CanQuery = false

	local bayCrown = makePart(
		bayModel,
		"Part",
		"DeployBayCrown",
		Vector3.new(24, 1.6, 6),
		CFrame.new(worldPosition + Vector3.new(0, 15.4, -10.2)),
		Color3.fromRGB(92, 48, 48),
		Enum.Material.Metal
	)
	bayCrown.CanQuery = false
	makeGlowPart(bayModel, "DeployBayCrownGlow", Vector3.new(24.4, 0.18, 6.4), bayCrown.CFrame * CFrame.new(0, 0.6, 0), deployAccent, 0.72)

	local bayRear = makePart(
		bayModel,
		"Part",
		"DeployBayRear",
		Vector3.new(34, 14, 2),
		CFrame.new(worldPosition + Vector3.new(0, 7, 8.5)),
		Color3.fromRGB(88, 46, 46),
		Enum.Material.Metal
	)
	bayRear.CanQuery = false

	local bayLeftInset = makePart(
		bayModel,
		"Part",
		"DeployLeftInset",
		Vector3.new(4, 8, 8),
		CFrame.new(worldPosition + Vector3.new(-12.2, 4.5, 6.4)),
		Color3.fromRGB(48, 30, 30),
		Enum.Material.SmoothPlastic
	)
	bayLeftInset.CanQuery = false

	local bayRightInset = makePart(
		bayModel,
		"Part",
		"DeployRightInset",
		Vector3.new(4, 8, 8),
		CFrame.new(worldPosition + Vector3.new(12.2, 4.5, 6.4)),
		Color3.fromRGB(48, 30, 30),
		Enum.Material.SmoothPlastic
	)
	bayRightInset.CanQuery = false

	local bayChevronLeft = makeGlowPart(
		bayModel,
		"DeployBayChevronLeft",
		Vector3.new(4.8, 0.12, 1.1),
		CFrame.new(worldPosition + Vector3.new(-8.2, 0.86, -11.2)) * CFrame.Angles(0, math.rad(18), 0),
		deployAccent,
		0.72
	)
	local bayChevronRight = makeGlowPart(
		bayModel,
		"DeployBayChevronRight",
		Vector3.new(4.8, 0.12, 1.1),
		CFrame.new(worldPosition + Vector3.new(8.2, 0.86, -11.2)) * CFrame.Angles(0, math.rad(-18), 0),
		deployAccent,
		0.72
	)
	bayChevronLeft.CanCollide = false
	bayChevronLeft.CanQuery = false
	bayChevronRight.CanCollide = false
	bayChevronRight.CanQuery = false

	makeGlowPart(bayModel, "DeployBayStripLeft", Vector3.new(0.2, 10, 18), CFrame.new(worldPosition + Vector3.new(-14.8, 7.4, -2)), deployTrimColor, 0.82)
	makeGlowPart(bayModel, "DeployBayStripRight", Vector3.new(0.2, 10, 18), CFrame.new(worldPosition + Vector3.new(14.8, 7.4, -2)), deployTrimColor, 0.82)
	makeGlowPart(bayModel, "DeployBayLintel", Vector3.new(20, 0.24, 1), CFrame.new(worldPosition + Vector3.new(0, 12, -10.8)), deployAccent, 0.72)

	for _, offset in ipairs({
		Vector3.new(-10.2, 10.8, -2.4),
		Vector3.new(10.2, 10.8, -2.4),
	}) do
		local bayLight = makeGlowPart(bayModel, "DeployBayLight", Vector3.new(5.4, 0.18, 1), CFrame.new(worldPosition + offset), deployAccent, 0.64)
		local fill = Instance.new("PointLight")
		fill.Range = 24
		fill.Brightness = 0.82
		fill.Color = Color3.fromRGB(255, 208, 182)
		fill.Parent = bayLight
	end

	local pad = makePart(
		root,
		"Part",
		"DeployPad",
		Vector3.new(24, 1, 24),
		CFrame.new(worldPosition),
		Color3.fromRGB(154, 86, 86),
		Enum.Material.Metal
	)
	pad.CanQuery = false
	pad.Transparency = 0.04
	pad:SetAttribute("DeployPad", true)
	pad:SetAttribute("RequiresDeployTokens", true)
	CollectionService:AddTag(pad, "DeployPad")

	local outerRing = makeGlowPart(root, "DeployOuterRing", Vector3.new(24, 0.1, 24), CFrame.new(worldPosition + Vector3.new(0, 0.7, 0)), Color3.fromRGB(255, 176, 122), 0.72)
	local innerRing = makeGlowPart(root, "DeployInnerRing", Vector3.new(12, 0.08, 12), CFrame.new(worldPosition + Vector3.new(0, 0.9, 0)), Color3.fromRGB(255, 228, 214), 0.66)
	local leftPylon = makePart(root, "Part", "DeployPylonLeft", Vector3.new(2, 14, 2), CFrame.new(worldPosition + Vector3.new(-11, 7, -11)), Color3.fromRGB(72, 40, 40), Enum.Material.Metal)
	local rightPylon = makePart(root, "Part", "DeployPylonRight", Vector3.new(2, 14, 2), CFrame.new(worldPosition + Vector3.new(11, 7, -11)), Color3.fromRGB(72, 40, 40), Enum.Material.Metal)
	leftPylon.CanQuery = false
	rightPylon.CanQuery = false
	makeGlowPart(root, "DeployHeader", Vector3.new(18, 0.24, 1.4), CFrame.new(worldPosition + Vector3.new(0, 13, -11)), Color3.fromRGB(255, 162, 142), 0.62)
	attachWorldText(pad, "DEPLOY", Vector3.new(0, 6, 0), Color3.fromRGB(255, 214, 214), Vector2.new(120, 30))
	outerRing.Name = "DeployOuterRing"
	innerRing.Name = "DeployInnerRing"

	local runway = makePart(
		root,
		"Part",
		"DeployRunway",
		Vector3.new(22, 0.3, 32),
		CFrame.new(worldPosition + Vector3.new(0, 0.76, -22)),
		Color3.fromRGB(116, 94, 94),
		Enum.Material.DiamondPlate
	)
	runway.CanCollide = false
	runway.CanQuery = false

	local runwayThreshold = makePart(
		root,
		"Part",
		"DeployRunwayThreshold",
		Vector3.new(18, 0.24, 4),
		CFrame.new(worldPosition + Vector3.new(0, 0.92, -5.4)),
		Color3.fromRGB(138, 92, 92),
		Enum.Material.Metal
	)
	runwayThreshold.CanCollide = false
	runwayThreshold.CanQuery = false
	local thresholdGlow = makeGlowPart(
		root,
		"DeployRunwayThresholdGlow",
		Vector3.new(16, 0.08, 1.2),
		runwayThreshold.CFrame * CFrame.new(0, 0.16, -1.1),
		Color3.fromRGB(255, 212, 178),
		0.66
	)
	thresholdGlow.CanCollide = false
	thresholdGlow.CanQuery = false

	local runwayFrame = makePart(
		root,
		"Part",
		"DeployRunwayFrame",
		Vector3.new(26, 0.12, 36),
		CFrame.new(worldPosition + Vector3.new(0, 0.92, -22)),
		Color3.fromRGB(92, 54, 54),
		Enum.Material.Metal
	)
	runwayFrame.CanCollide = false
	runwayFrame.CanQuery = false
	runwayFrame.Transparency = 0.78

	local runwayGuide = makeGlowPart(
		root,
		"DeployRunwayGuide",
		Vector3.new(4, 0.08, 26),
		CFrame.new(worldPosition + Vector3.new(0, 0.84, -22)),
		Color3.fromRGB(255, 196, 154),
		0.72
	)
	runwayGuide.Name = "DeployRunwayGuide"

	local runwaySideLeft = makeGlowPart(
		root,
		"DeployRunwaySideLeft",
		Vector3.new(0.22, 0.08, 26),
		CFrame.new(worldPosition + Vector3.new(-8.8, 0.84, -22)),
		Color3.fromRGB(238, 150, 134),
		0.74
	)
	runwaySideLeft.Name = "DeployRunwaySideLeft"

	local runwaySideRight = makeGlowPart(
		root,
		"DeployRunwaySideRight",
		Vector3.new(0.22, 0.08, 26),
		CFrame.new(worldPosition + Vector3.new(8.8, 0.84, -22)),
		Color3.fromRGB(238, 150, 134),
		0.74
	)
	runwaySideRight.Name = "DeployRunwaySideRight"

	for _, offset in ipairs({
		Vector3.new(-9.5, 1.4, -30),
		Vector3.new(9.5, 1.4, -30),
		Vector3.new(-15.5, 1.4, -42),
		Vector3.new(15.5, 1.4, -42),
	}) do
		local bollard = makePart(
			root,
			"Part",
			"DeployRunwayBollard",
			Vector3.new(1.4, 2.8, 1.4),
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(108, 64, 64),
			Enum.Material.Metal
		)
		bollard.CanQuery = false
		local lamp = makeGlowPart(root, "DeployRunwayLamp", Vector3.new(1.8, 0.14, 1.8), bollard.CFrame * CFrame.new(0, 1.5, 0), Color3.fromRGB(255, 188, 154), 0.54)
		local lampLight = Instance.new("PointLight")
		lampLight.Range = 12
		lampLight.Brightness = 0.62
		lampLight.Color = Color3.fromRGB(255, 204, 178)
		lampLight.Parent = lamp
	end

	for _, offset in ipairs({
		Vector3.new(-12.8, 0.9, -22),
		Vector3.new(12.8, 0.9, -22),
	}) do
		local sideBeacon = makePart(
			root,
			"Part",
			"DeployRunwayBeacon",
			Vector3.new(1.2, 3.6, 1.2),
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(118, 62, 62),
			Enum.Material.Metal
		)
		sideBeacon.CanQuery = false
		local beaconGlow = makeGlowPart(root, "DeployRunwayBeaconLight", Vector3.new(1.4, 1.4, 1.4), sideBeacon.CFrame * CFrame.new(0, 1.8, 0), Color3.fromRGB(255, 156, 132), 0.28)
		local beaconLight = Instance.new("PointLight")
		beaconLight.Range = 14
		beaconLight.Brightness = 0.58
		beaconLight.Color = Color3.fromRGB(255, 176, 148)
		beaconLight.Parent = beaconGlow
	end

	local prepCrateLeft = makePart(root, "Part", "DeployPrepCrateLeft", Vector3.new(3.2, 2.6, 3.2), CFrame.new(worldPosition + Vector3.new(-11.4, 1.4, 4.8)), Color3.fromRGB(92, 62, 54), Enum.Material.WoodPlanks)
	local prepCrateRight = makePart(root, "Part", "DeployPrepCrateRight", Vector3.new(3.2, 2.6, 3.2), CFrame.new(worldPosition + Vector3.new(11.4, 1.4, 4.8)), Color3.fromRGB(92, 62, 54), Enum.Material.WoodPlanks)
	prepCrateLeft.CanQuery = false
	prepCrateRight.CanQuery = false

	local prepLockerLeft = makePart(root, "Part", "DeployPrepLockerLeft", Vector3.new(2.4, 8, 2.4), CFrame.new(worldPosition + Vector3.new(-12.4, 4, 8.2)), Color3.fromRGB(86, 52, 52), Enum.Material.Metal)
	local prepLockerRight = makePart(root, "Part", "DeployPrepLockerRight", Vector3.new(2.4, 8, 2.4), CFrame.new(worldPosition + Vector3.new(12.4, 4, 8.2)), Color3.fromRGB(86, 52, 52), Enum.Material.Metal)
	prepLockerLeft.CanQuery = false
	prepLockerRight.CanQuery = false
	local prepBenchLeft = makePart(root, "Part", "DeployPrepBenchLeft", Vector3.new(5.2, 1.2, 2.2), CFrame.new(worldPosition + Vector3.new(-8.8, 0.72, 10.6)), Color3.fromRGB(118, 86, 72), Enum.Material.WoodPlanks)
	local prepBenchRight = makePart(root, "Part", "DeployPrepBenchRight", Vector3.new(5.2, 1.2, 2.2), CFrame.new(worldPosition + Vector3.new(8.8, 0.72, 10.6)), Color3.fromRGB(118, 86, 72), Enum.Material.WoodPlanks)
	prepBenchLeft.CanQuery = false
	prepBenchRight.CanQuery = false

	local gateModel = Instance.new("Model")
	gateModel.Name = "DeployGate"
	gateModel.Parent = root

	local gateLeft = makePart(gateModel, "Part", "GateLeft", Vector3.new(6, 20, 4), CFrame.new(worldPosition + Vector3.new(-18, 10, -14)), Color3.fromRGB(64, 34, 34), Enum.Material.Metal)
	local gateRight = makePart(gateModel, "Part", "GateRight", Vector3.new(6, 20, 4), CFrame.new(worldPosition + Vector3.new(18, 10, -14)), Color3.fromRGB(64, 34, 34), Enum.Material.Metal)
	local gateTop = makePart(gateModel, "Part", "GateTop", Vector3.new(42, 3, 4), CFrame.new(worldPosition + Vector3.new(0, 19, -14)), Color3.fromRGB(96, 48, 48), Enum.Material.Metal)
	local blastDoor = makePart(gateModel, "Part", "BlastDoor", Vector3.new(24, 16, 2), CFrame.new(worldPosition + Vector3.new(0, 8, -15.2)), Color3.fromRGB(108, 56, 56), Enum.Material.DiamondPlate)
	gateLeft.CanQuery = false
	gateRight.CanQuery = false
	gateTop.CanQuery = false
	blastDoor.CanQuery = false

	local leftTower = makePart(gateModel, "Part", "GateTowerLeft", Vector3.new(4, 24, 6), CFrame.new(worldPosition + Vector3.new(-23, 12, -12)), Color3.fromRGB(82, 42, 42), Enum.Material.Metal)
	local rightTower = makePart(gateModel, "Part", "GateTowerRight", Vector3.new(4, 24, 6), CFrame.new(worldPosition + Vector3.new(23, 12, -12)), Color3.fromRGB(82, 42, 42), Enum.Material.Metal)
	local upperBridge = makePart(gateModel, "Part", "GateBridge", Vector3.new(54, 2, 6), CFrame.new(worldPosition + Vector3.new(0, 23, -12)), Color3.fromRGB(112, 58, 58), Enum.Material.Metal)
	leftTower.CanQuery = false
	rightTower.CanQuery = false
	upperBridge.CanQuery = false

	local gateCrown = makePart(gateModel, "Part", "GateCrown", Vector3.new(28, 2, 6), CFrame.new(worldPosition + Vector3.new(0, 26.2, -12)), Color3.fromRGB(138, 72, 72), Enum.Material.Metal)
	gateCrown.CanQuery = false
	makeGlowPart(gateModel, "GateCrownGlow", Vector3.new(28.4, 0.18, 6.4), gateCrown.CFrame * CFrame.new(0, 0.7, 0), Color3.fromRGB(255, 188, 164), 0.64)

	for _, offset in ipairs({
		Vector3.new(-32, 15, -13.5),
		Vector3.new(32, 15, -13.5),
	}) do
		local wing = makePart(gateModel, "Part", "GateWing", Vector3.new(6, 18, 3), CFrame.new(worldPosition + offset), Color3.fromRGB(92, 48, 48), Enum.Material.Metal)
		wing.CanQuery = false
		makeGlowPart(gateModel, "GateWingGlow", Vector3.new(6.4, 0.16, 3.4), wing.CFrame * CFrame.new(0, 8.5, 0), Color3.fromRGB(255, 176, 154), 0.76)
	end

	for _, offset in ipairs({
		Vector3.new(-13, 8, -13.2),
		Vector3.new(13, 8, -13.2),
	}) do
		local brace = makePart(gateModel, "Part", "GateBrace", Vector3.new(10, 2, 2), CFrame.new(worldPosition + offset) * CFrame.Angles(0, 0, math.rad(22 * (offset.X > 0 and -1 or 1))), Color3.fromRGB(134, 72, 72), Enum.Material.Metal)
		brace.CanQuery = false
	end

	local gateLight = makeGlowPart(gateModel, "GateLight", Vector3.new(24, 0.26, 1), CFrame.new(worldPosition + Vector3.new(0, 16.5, -12.2)), Color3.fromRGB(255, 164, 144), 0.46)
	local gateFill = Instance.new("PointLight")
	gateFill.Range = 28
	gateFill.Brightness = 0.88
	gateFill.Color = Color3.fromRGB(255, 188, 164)
	gateFill.Parent = gateLight
	local bridgeLight = makeGlowPart(gateModel, "BridgeLight", Vector3.new(34, 0.18, 1.2), CFrame.new(worldPosition + Vector3.new(0, 21.8, -8.8)), Color3.fromRGB(255, 150, 136), 0.56)
	local bridgeFill = Instance.new("PointLight")
	bridgeFill.Range = 20
	bridgeFill.Brightness = 0.52
	bridgeFill.Color = Color3.fromRGB(255, 172, 152)
	bridgeFill.Parent = bridgeLight
	attachWorldText(gateTop, "MISSION AIRLOCK", Vector3.new(0, 2.8, 0), Color3.fromRGB(255, 214, 214), Vector2.new(170, 30))
	attachWorldText(gateTop, "Squads launch into their own run instance", Vector3.new(0, 1.55, 0), Color3.fromRGB(255, 194, 180), Vector2.new(248, 18))

	for _, offset in ipairs({
		Vector3.new(-23, 21, -9),
		Vector3.new(23, 21, -9),
	}) do
		local beacon = makeGlowPart(gateModel, "WarningBeacon", Vector3.new(1.8, 1.8, 1.8), CFrame.new(worldPosition + offset), Color3.fromRGB(255, 118, 118), 0.22)
		local light = Instance.new("PointLight")
		light.Range = 16
		light.Brightness = 0.72
		light.Color = Color3.fromRGB(255, 108, 108)
		light.Parent = beacon
	end

	local stagingPlate = makePart(root, "Part", "DeployStagingPlate", Vector3.new(12, 0.18, 6), CFrame.new(worldPosition + Vector3.new(0, 0.82, 8.4)), Color3.fromRGB(138, 96, 96), Enum.Material.Metal)
	stagingPlate.CanCollide = false
	stagingPlate.CanQuery = false
	stagingPlate.Transparency = 0.24
	makeGlowPart(root, "DeployStagingGuide", Vector3.new(8, 0.08, 2), CFrame.new(worldPosition + Vector3.new(0, 0.96, 5.8)), Color3.fromRGB(255, 194, 168), 0.64)

	attachWorldText(stagingPlate, "READY BAY", Vector3.new(0, 2.2, 0), Color3.fromRGB(255, 198, 184), Vector2.new(124, 28))
	attachWorldText(stagingPlate, "Squad up, confirm the vote, then deploy", Vector3.new(0, 1.1, 0), Color3.fromRGB(244, 190, 176), Vector2.new(230, 18))

	local stagingStrutLeft = makePart(root, "Part", "DeployStagingStrutLeft", Vector3.new(1.4, 7.2, 1.4), CFrame.new(worldPosition + Vector3.new(-12, 3.6, 13.2)), Color3.fromRGB(86, 52, 52), Enum.Material.Metal)
	local stagingStrutRight = makePart(root, "Part", "DeployStagingStrutRight", Vector3.new(1.4, 7.2, 1.4), CFrame.new(worldPosition + Vector3.new(12, 3.6, 13.2)), Color3.fromRGB(86, 52, 52), Enum.Material.Metal)
	stagingStrutLeft.CanQuery = false
	stagingStrutRight.CanQuery = false

	local stagingCrown = makePart(root, "Part", "DeployStagingCrown", Vector3.new(14, 0.9, 3), CFrame.new(worldPosition + Vector3.new(0, 8.2, 11.8)), Color3.fromRGB(118, 70, 70), Enum.Material.Metal)
	stagingCrown.CanQuery = false
	makeGlowPart(root, "DeployStagingCrownGlow", Vector3.new(14.4, 0.12, 3.4), stagingCrown.CFrame * CFrame.new(0, 0.4, 0), Color3.fromRGB(255, 194, 168), 0.68)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DeployPrompt"
	prompt.ActionText = "Deploy"
	prompt.ObjectText = "Main Game"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = pad

	for index, offset in ipairs({
		Vector3.new(-18, 2.1, -38),
		Vector3.new(18, 2.1, -38),
		Vector3.new(-18, 2.1, -12),
		Vector3.new(18, 2.1, -12),
	}) do
		local pylon = makePart(
			root,
			"Part",
			"DeployConcoursePylon" .. tostring(index),
			Vector3.new(1.2, 3.6, 1.2),
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(94, 62, 62),
			Enum.Material.Metal
		)
		pylon.CanQuery = false
		local pylonCap = makeGlowPart(
			root,
			"DeployConcoursePylonCap" .. tostring(index),
			Vector3.new(1.6, 0.16, 1.6),
			pylon.CFrame * CFrame.new(0, 1.82, 0),
			Color3.fromRGB(255, 188, 154),
			0.42
		)
		pylonCap.CanCollide = false
		pylonCap.CanQuery = false
		local pylonLight = Instance.new("PointLight")
		pylonLight.Range = 12
		pylonLight.Brightness = 0.24
		pylonLight.Color = Color3.fromRGB(255, 204, 176)
		pylonLight.Parent = pylonCap
	end

	return pad, prompt
end

makeGuidePaths = function(root: Instance, origin: Vector3, areaConfig)
	for areaName, palette in pairs(areaConfig) do
		local target = origin + palette.Offset
		makePathSegment(root, areaName .. "GuidePath", origin, target, palette.Accent)
	end
end

local function makeMissionStaging(root: Instance, worldPosition: Vector3)
	local mission = Instance.new("Model")
	mission.Name = "MissionStaging"
	mission.Parent = root

	local outerFloor = makePart(
		mission,
		"Part",
		"OuterFloor",
		Vector3.new(236, 2, 236),
		CFrame.new(worldPosition + Vector3.new(0, -1.2, 0)),
		Color3.fromRGB(18, 21, 26),
		Enum.Material.Concrete
	)
	outerFloor.CanQuery = false

	local base = makePart(
		mission,
		"Part",
		"Base",
		Vector3.new(176, 2, 176),
		CFrame.new(worldPosition + Vector3.new(0, -1, 0)),
		Color3.fromRGB(32, 36, 42),
		Enum.Material.DiamondPlate
	)
	base.CanQuery = false

	for index = -2, 2 do
		local seam = makePart(
			mission,
			"Part",
			"FloorSeamX" .. tostring(index + 3),
			Vector3.new(2, 0.08, 156),
			CFrame.new(worldPosition + Vector3.new(index * 34, 0.16, 0)),
			Color3.fromRGB(70, 76, 84),
			Enum.Material.Metal
		)
		seam.CanCollide = false
		seam.CanQuery = false
		seam.Transparency = 0.78
	end

	for index = -2, 2 do
		local seam = makePart(
			mission,
			"Part",
			"FloorSeamZ" .. tostring(index + 3),
			Vector3.new(156, 0.08, 2),
			CFrame.new(worldPosition + Vector3.new(0, 0.16, index * 34)),
			Color3.fromRGB(70, 76, 84),
			Enum.Material.Metal
		)
		seam.CanCollide = false
		seam.CanQuery = false
		seam.Transparency = 0.78
	end

	local glow = makePart(
		mission,
		"Part",
		"Glow",
		Vector3.new(136, 0.4, 136),
		CFrame.new(worldPosition + Vector3.new(0, 1.2, 0)),
		Color3.fromRGB(214, 118, 72),
		Enum.Material.Neon
	)
	glow.Transparency = 0.88
	glow.CanCollide = false
	glow.CanQuery = false

	local perimeter = makePart(
		mission,
		"Part",
		"PerimeterFrame",
		Vector3.new(186, 1, 186),
		CFrame.new(worldPosition + Vector3.new(0, 0.9, 0)),
		Color3.fromRGB(79, 47, 37),
		Enum.Material.Metal
	)
	perimeter.CanCollide = false
	perimeter.CanQuery = false
	perimeter.Transparency = 0.88

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MissionSpawn"
	spawn.Size = Vector3.new(18, 1, 18)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Enabled = false
	spawn.Duration = 0
	spawn.Material = Enum.Material.Metal
	spawn.Color = Color3.fromRGB(106, 92, 78)
	spawn.CFrame = CFrame.new(worldPosition + Vector3.new(0, 1.5, 0))
	spawn.Parent = mission

	local marker = makePart(
		mission,
		"Part",
		"DropMarker",
		Vector3.new(34, 1, 34),
		CFrame.new(worldPosition + Vector3.new(0, 2.6, 0)),
		Color3.fromRGB(140, 86, 58),
		Enum.Material.Metal
	)
	marker.Transparency = 0.52
	marker.CanCollide = false
	marker.CanQuery = false

	local markerRing = makeGlowPart(
		mission,
		"DropMarkerRing",
		Vector3.new(40, 0.08, 40),
		CFrame.new(worldPosition + Vector3.new(0, 2.72, 0)),
		Color3.fromRGB(236, 160, 108),
		0.82
	)
	markerRing.CanCollide = false
	markerRing.CanQuery = false

	local rearGantry = makePart(
		mission,
		"Part",
		"RearGantry",
		Vector3.new(72, 2, 4),
		CFrame.new(worldPosition + Vector3.new(0, 16, 54)),
		Color3.fromRGB(52, 58, 66),
		Enum.Material.Metal
	)
	rearGantry.CanQuery = false
	makeGlowPart(mission, "RearGantryLight", Vector3.new(58, 0.22, 1), CFrame.new(worldPosition + Vector3.new(0, 14.8, 55.8)), Color3.fromRGB(236, 160, 112), 0.8)

	for _, offset in ipairs({
		Vector3.new(-54, 1.4, -54),
		Vector3.new(54, 1.4, -54),
		Vector3.new(-54, 1.4, 54),
		Vector3.new(54, 1.4, 54),
	}) do
		local cornerPylon = makePart(
			mission,
			"Part",
			"CornerPylon",
			Vector3.new(2, 12, 2),
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(50, 56, 64),
			Enum.Material.Metal
		)
		cornerPylon.CanQuery = false
		makeGlowPart(mission, "CornerPylonLight", Vector3.new(2.2, 0.16, 2.2), cornerPylon.CFrame * CFrame.new(0, 6, 0), Color3.fromRGB(255, 174, 122), 0.86)
	end

	local leftWall = makePart(
		mission,
		"Part",
		"ZoneWallLeft",
		Vector3.new(6, 22, 132),
		CFrame.new(worldPosition + Vector3.new(-72, 10, 0)),
		Color3.fromRGB(28, 31, 36),
		Enum.Material.Metal
	)
	leftWall.CanQuery = false

	local rightWall = makePart(
		mission,
		"Part",
		"ZoneWallRight",
		Vector3.new(6, 22, 132),
		CFrame.new(worldPosition + Vector3.new(72, 10, 0)),
		Color3.fromRGB(28, 31, 36),
		Enum.Material.Metal
	)
	rightWall.CanQuery = false

	local backWall = makePart(
		mission,
		"Part",
		"ZoneWallBack",
		Vector3.new(144, 22, 6),
		CFrame.new(worldPosition + Vector3.new(0, 10, -72)),
		Color3.fromRGB(28, 31, 36),
		Enum.Material.Metal
	)
	backWall.CanQuery = false

	local gantry = makePart(
		mission,
		"Part",
		"Gantry",
		Vector3.new(62, 2, 4),
		CFrame.new(worldPosition + Vector3.new(0, 16, -28)),
		Color3.fromRGB(54, 58, 64),
		Enum.Material.Metal
	)
	gantry.CanQuery = false

	makeGlowPart(mission, "GantryLight", Vector3.new(46, 0.25, 1), CFrame.new(worldPosition + Vector3.new(0, 14.7, -26.2)), Color3.fromRGB(236, 162, 118), 0.78)
	makeGlowPart(mission, "WallStripLeft", Vector3.new(0.22, 10, 92), CFrame.new(worldPosition + Vector3.new(-68.8, 8, 0)), Color3.fromRGB(176, 122, 94), 0.84)
	makeGlowPart(mission, "WallStripRight", Vector3.new(0.22, 10, 92), CFrame.new(worldPosition + Vector3.new(68.8, 8, 0)), Color3.fromRGB(176, 122, 94), 0.84)

	local cameraStart = makePart(
		mission,
		"Part",
		"MissionCameraStart",
		Vector3.new(2, 2, 2),
		CFrame.new(worldPosition + Vector3.new(-108, 82, -132)),
		Color3.fromRGB(255, 255, 255),
		Enum.Material.SmoothPlastic
	)
	cameraStart.Transparency = 1
	cameraStart.CanCollide = false
	cameraStart.CanQuery = false

	local cameraEnd = makePart(
		mission,
		"Part",
		"MissionCameraEnd",
		Vector3.new(2, 2, 2),
		CFrame.new(worldPosition + Vector3.new(0, 28, -58)),
		Color3.fromRGB(255, 255, 255),
		Enum.Material.SmoothPlastic
	)
	cameraEnd.Transparency = 1
	cameraEnd.CanCollide = false
	cameraEnd.CanQuery = false

	attachLabel(marker, "DROP ZONE", "Forward breach staging", Color3.fromRGB(255, 196, 128))

	return mission, spawn, cameraStart, cameraEnd
end

function LobbyWorld.start()
	clearExisting(Config.RootName)
	applyLobbyLighting()

	local root = Instance.new("Folder")
	root.Name = Config.RootName
	root.Parent = Workspace
	root:SetAttribute("WorldType", "LobbyHub")
	root:SetAttribute("PlayerCountMax", Config.SquadSize.Max)
	makeOpenSkyLobby(root, Config.Origin)

	local lobbyAnchor = root:FindFirstChild("OpenSkyLobby")
	if lobbyAnchor and lobbyAnchor:IsA("Model") then
		local anchorPart = lobbyAnchor:FindFirstChild("OuterGround")
		if anchorPart and anchorPart:IsA("BasePart") then
			CollectionService:AddTag(anchorPart, "LobbyAnchor")
		end
	end

	local compositionRoot = (lobbyAnchor and lobbyAnchor:IsA("Model")) and lobbyAnchor or root
	makeSpawn(compositionRoot, Config.Origin + Config.SpawnOffset)
	makeCentralHub(compositionRoot, Config.Origin + Config.SpawnOffset + Vector3.new(0, 0, 0))
	local mission, missionSpawn, cameraStart, cameraEnd = makeMissionStaging(root, Config.Origin + Config.MissionOffset)
	root:SetAttribute("DeployPadName", "")
	root:SetAttribute("DeployPromptName", "")
	root:SetAttribute("LootMultiplierAt4", Config.GetScaledLootMultiplier(4))
	root:SetAttribute("DifficultyAt4", Config.GetScaledDifficulty(4))
	root:SetAttribute("MissionModelName", mission.Name)
	root:SetAttribute("MissionSpawnName", missionSpawn.Name)
	root:SetAttribute("MissionCameraStartName", cameraStart.Name)
	root:SetAttribute("MissionCameraEndName", cameraEnd.Name)

	Workspace:SetAttribute("MissionSpawnPath", missionSpawn:GetFullName())
	Workspace:SetAttribute("MissionCameraStartPath", cameraStart:GetFullName())
	Workspace:SetAttribute("MissionCameraEndPath", cameraEnd:GetFullName())

	local info = Instance.new("Folder")
	info.Name = "LobbyMetadata"
	info.Parent = root

	for sourceName, amount in pairs(Config.TokenSources) do
		info:SetAttribute(sourceName .. "Tokens", amount)
	end

	return root
end

return LobbyWorld
