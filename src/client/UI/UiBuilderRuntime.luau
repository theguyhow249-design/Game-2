local Theme = require(script.Parent.Parent.Controllers.Theme)

local UiBuilder = {}

local function new(className, props)
	local instance = Instance.new(className)
	if props then
		for key, value in pairs(props) do
			instance[key] = value
		end
	end
	return instance
end

local function addCorner(parent, radius)
	return new("UICorner", {
		CornerRadius = radius or UDim.new(0, 14),
		Parent = parent,
	})
end

local function addStroke(parent, color, transparency, thickness)
	return new("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Transparency = transparency or 0.08,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function addPadding(parent, pad)
	return new("UIPadding", {
		PaddingTop = pad or UDim.new(0, 16),
		PaddingBottom = pad or UDim.new(0, 16),
		PaddingLeft = pad or UDim.new(0, 16),
		PaddingRight = pad or UDim.new(0, 16),
		Parent = parent,
	})
end

local function addGradient(parent, color1, color2, rotation)
	return new("UIGradient", {
		Rotation = rotation or 25,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color1),
			ColorSequenceKeypoint.new(1, color2),
		}),
		Parent = parent,
	})
end

local function addPage(parent, name)
	return new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	})
end

local function addTextConstraint(parent, maxSize, minSize)
	return new("UITextSizeConstraint", {
		MaxTextSize = maxSize or 28,
		MinTextSize = minSize or 12,
		Parent = parent,
	})
end

local function createButton(parent, name, text, size, position, accentColor)
	local button = new("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accentColor or Theme.Colors.Accent,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		AutoButtonColor = false,
		Text = text,
		TextColor3 = Theme.Colors.Text,
		TextScaled = false,
		TextSize = 18,
		TextWrapped = true,
		Font = Theme.Fonts.Heading,
		Parent = parent,
	})
	addCorner(button, UDim.new(0, 14))
	addStroke(button, Theme.Colors.Stroke, 0.25, 1)
	addGradient(
		button,
		(accentColor or Theme.Colors.Accent):Lerp(Color3.fromRGB(255, 255, 255), 0.08),
		(accentColor or Theme.Colors.Accent):Lerp(Color3.fromRGB(0, 0, 0), 0.34),
		0
	)
	return button
end

local function createPopup(parent, name, size, position, style)
	style = style or {}
	local isVisible = style.visible ~= false
	local backgroundColor = style.backgroundColor or Theme.Colors.Panel
	local gradientStart = style.gradientStart or backgroundColor
	local gradientEnd = style.gradientEnd or Theme.Colors.PanelAlt
	local strokeColor = style.strokeColor or Theme.Colors.Stroke
	local popup = new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = backgroundColor,
		BackgroundTransparency = style.backgroundTransparency or 0,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		Visible = isVisible,
		Parent = parent,
	})
	popup:SetAttribute("ClosedY", position.Y.Offset + 14)
	popup:SetAttribute("OpenY", position.Y.Offset)
	addCorner(popup, UDim.new(0, 20))
	addStroke(popup, strokeColor, 0.05, 1)
	addPadding(popup, UDim.new(0, 18))
	addGradient(popup, gradientStart, gradientEnd, 0)
	new("UISizeConstraint", {
		MaxSize = style.maxSize or Vector2.new(1280, 860),
		Parent = popup,
	})
	new("UIScale", {
		Name = "ScaleDriver",
		Scale = isVisible and 1 or 0.97,
		Parent = popup,
	})

	local headerBand = new("Frame", {
		Name = "HeaderBand",
		BackgroundColor3 = style.headerColor or strokeColor,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 60),
		Parent = popup,
	})
	addCorner(headerBand, UDim.new(0, 20))
	new("UIGradient", {
		Rotation = 0,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, style.headerColor or strokeColor),
			ColorSequenceKeypoint.new(1, style.headerColorEnd or gradientEnd),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.02),
			NumberSequenceKeypoint.new(1, 0.18),
		}),
		Parent = headerBand,
	})

	new("Frame", {
		Name = "HeaderMask",
		BackgroundColor3 = backgroundColor,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 38),
		Size = UDim2.new(1, 0, 0, 28),
		Parent = headerBand,
	})

	local accentStrip = new("Frame", {
		Name = "AccentStrip",
		BackgroundColor3 = style.headerColor or strokeColor,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 24, 0, 18),
		Size = UDim2.new(0, 124, 0, 4),
		Parent = popup,
	})
	addCorner(accentStrip, UDim.new(0, 6))

	local innerFrame = new("Frame", {
		Name = "InnerFrame",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 14, 0, 66),
		Size = UDim2.new(1, -28, 1, -84),
		Parent = popup,
	})
	addStroke(innerFrame, strokeColor, 0.34, 1)
	addCorner(innerFrame, UDim.new(0, 16))

	local lowerRule = new("Frame", {
		Name = "LowerRule",
		BackgroundColor3 = style.headerColor or strokeColor,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 18, 0, 66),
		Size = UDim2.new(1, -32, 0, 1),
		Parent = popup,
	})

	local emblem = new("Frame", {
		Name = "Emblem",
		BackgroundColor3 = style.headerColor or strokeColor,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -74, 0, 12),
		Size = UDim2.new(0, 44, 0, 44),
		Parent = popup,
	})
	addCorner(emblem, UDim.new(0, 16))
	addStroke(emblem, style.headerColor or strokeColor, 0.1, 1)
	local emblemText = new("TextLabel", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = style.iconText or style.badgeText or "UI",
		TextColor3 = style.badgeTextColor or Theme.Colors.Text,
		TextScaled = false,
		TextSize = 13,
		Font = Theme.Fonts.Heading,
		Parent = emblem,
	})
	emblemText.TextXAlignment = Enum.TextXAlignment.Center
	emblemText.TextYAlignment = Enum.TextYAlignment.Center

	if style.badgeText then
		local badge = new("TextLabel", {
			Name = "Badge",
			BackgroundColor3 = style.badgeColor or Theme.Colors.Backdrop,
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			Position = UDim2.new(0.06, 0, 0.085, 0),
			Size = UDim2.new(0, 74, 0, 24),
			Text = style.badgeText,
			TextColor3 = style.badgeTextColor or Theme.Colors.Text,
			TextScaled = true,
			Font = Theme.Fonts.Heading,
			Parent = popup,
		})
		addCorner(badge, UDim.new(0, 9))
		addStroke(badge, style.headerColor or strokeColor, 0.14, 1)
		addTextConstraint(badge, 12, 8)
	end
	return popup
end

local function createListFrame(parent, name, position, size)
	local list = new("ScrollingFrame", {
		Name = name,
		BackgroundColor3 = Theme.Colors.Backdrop,
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarImageColor3 = Theme.Colors.AccentWarm,
		ScrollBarThickness = 6,
		Parent = parent,
	})
	addCorner(list, UDim.new(0, 14))
	addStroke(list, Theme.Colors.Stroke, 0.12, 1)
	addGradient(list, Theme.Colors.Backdrop:Lerp(Color3.fromRGB(255, 255, 255), 0.03), Theme.Colors.Backdrop:Lerp(Color3.fromRGB(0, 0, 0), 0.12), 90)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = list,
	})
	local topRule = new("Frame", {
		Name = "TopRule",
		BackgroundColor3 = Theme.Colors.Stroke,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.new(1, -20, 0, 1),
		Parent = list,
	})
	addCorner(topRule, UDim.new(0, 4))
	new("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	return list
end

local function createInsetCard(parent, name, position, size, backgroundColor, strokeColor)
	local card = new("Frame", {
		Name = name,
		BackgroundColor3 = backgroundColor,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		Parent = parent,
	})
	addCorner(card, UDim.new(0, 14))
	addStroke(card, strokeColor, 0.16, 1)
	addGradient(card, backgroundColor:Lerp(Color3.fromRGB(255, 255, 255), 0.06), backgroundColor:Lerp(Color3.fromRGB(0, 0, 0), 0.18), 90)
	local rule = new("Frame", {
		Name = "Rule",
		BackgroundColor3 = strokeColor,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0, 10),
		Size = UDim2.new(0, 72, 0, 3),
		Parent = card,
	})
	addCorner(rule, UDim.new(0, 4))
	local innerRule = new("Frame", {
		Name = "InnerRule",
		BackgroundColor3 = strokeColor,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0, 20),
		Size = UDim2.new(1, -24, 0, 1),
		Parent = card,
	})
	addCorner(innerRule, UDim.new(0, 4))
	local panelTag = new("Frame", {
		Name = "PanelTag",
		BackgroundColor3 = strokeColor,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -46, 0, 10),
		Size = UDim2.new(0, 28, 0, 28),
		Parent = card,
	})
	addCorner(panelTag, UDim.new(0, 10))
	addStroke(panelTag, strokeColor, 0.18, 1)
	return card
end

local function createStationMark(parent, name, glyph, labelText, position, tint)
	local mark = new("Frame", {
		Name = name,
		BackgroundColor3 = tint,
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
		Position = position,
		Size = UDim2.new(0, 88, 0, 88),
		Parent = parent,
	})
	addCorner(mark, UDim.new(0, 16))
	addStroke(mark, tint, 0.7, 1)
	local glyphLabel = new("TextLabel", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 10),
		Size = UDim2.new(1, 0, 0, 40),
		Text = glyph,
		TextColor3 = tint:Lerp(Color3.fromRGB(255, 255, 255), 0.4),
		TextScaled = false,
		TextSize = 22,
		Font = Theme.Fonts.Title,
		Parent = mark,
	})
	glyphLabel.TextTransparency = 0.72
	glyphLabel.TextXAlignment = Enum.TextXAlignment.Center
	local labelNode = new("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 1, -28),
		Size = UDim2.new(1, -16, 0, 18),
		Text = labelText,
		TextColor3 = tint:Lerp(Color3.fromRGB(255, 255, 255), 0.5),
		TextScaled = false,
		TextSize = 9,
		Font = Theme.Fonts.Heading,
		Parent = mark,
	})
	labelNode.TextTransparency = 0.42
	labelNode.TextXAlignment = Enum.TextXAlignment.Center
	return mark
end

local function setFixedText(instance, textSize, xAlign)
	instance.TextScaled = false
	instance.TextSize = textSize
	if xAlign then
		instance.TextXAlignment = xAlign
	end
end

local function label(parent, name, text, position, size, font, color, xAlign)
	local instance = new("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
		Text = text,
		TextColor3 = color or Theme.Colors.Text,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = xAlign or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = font or Theme.Fonts.Body,
		Parent = parent,
	})
	addTextConstraint(instance, 22, 10)
	return instance
end

local function createResultsPopup(lobby, lobbyRefs)
	local resultsPopup = createPopup(lobby, "ResultsPopup", UDim2.new(0, 860, 0, 560), UDim2.new(0.5, -430, 0.5, -280), {
		backgroundColor = Color3.fromRGB(42, 50, 60),
		gradientStart = Color3.fromRGB(58, 69, 82),
		gradientEnd = Color3.fromRGB(32, 40, 50),
		strokeColor = Color3.fromRGB(138, 154, 166),
		headerColor = Color3.fromRGB(102, 126, 152),
		headerColorEnd = Color3.fromRGB(58, 76, 98),
		badgeText = "DEBRIEF",
		badgeColor = Color3.fromRGB(74, 92, 116),
		iconText = "RPT",
		visible = false,
	})
	resultsPopup.AnchorPoint = Vector2.new(0, 0)
	local resultsBadgeNode = resultsPopup:FindFirstChild("Badge")
	if resultsBadgeNode and resultsBadgeNode:IsA("GuiObject") then
		resultsBadgeNode.Visible = false
	end
	local resultsEmblemNode = resultsPopup:FindFirstChild("Emblem")
	if resultsEmblemNode and resultsEmblemNode:IsA("GuiObject") then
		resultsEmblemNode.Visible = false
	end
	local resultsHeaderRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(138, 154, 166),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, 118),
		Size = UDim2.new(1, -60, 0, 2),
		Parent = resultsPopup,
	})
	addCorner(resultsHeaderRule, UDim.new(0, 4))
	local resultsAccent = new("Frame", {
		Name = "HeaderAccent",
		BackgroundColor3 = Color3.fromRGB(138, 154, 166),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, 86),
		Size = UDim2.new(0, 168, 0, 4),
		Parent = resultsPopup,
	})
	addCorner(resultsAccent, UDim.new(0, 6))
	local resultsTitle = label(resultsPopup, "Title", "Mission Debrief", UDim2.new(0, 30, 0, 58), UDim2.new(1, -190, 0, 34), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(resultsTitle, 31)
	local resultsTag = label(resultsPopup, "Tag", "Review the run, collect the reward, and step back into the bunker.", UDim2.new(0, 30, 0, 94), UDim2.new(1, -220, 0, 32), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(resultsTag, 15)
	local resultsLeft = new("Frame", {
		Name = "LeftPane",
		BackgroundColor3 = Color3.fromRGB(34, 42, 52),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, 144),
		Size = UDim2.new(0, 258, 1, -174),
		Parent = resultsPopup,
	})
	addCorner(resultsLeft, UDim.new(0, 18))
	addStroke(resultsLeft, Theme.Colors.Stroke, 0.22, 1)
	createInsetCard(resultsLeft, "SummaryCard", UDim2.new(0, 18, 0, 18), UDim2.new(1, -36, 0, 168), Color3.fromRGB(42, 52, 64), Color3.fromRGB(138, 154, 166))
	local resultsRight = new("Frame", {
		Name = "RightPane",
		BackgroundColor3 = Color3.fromRGB(28, 34, 42),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 306, 0, 144),
		Size = UDim2.new(1, -336, 1, -174),
		Parent = resultsPopup,
	})
	addCorner(resultsRight, UDim.new(0, 18))
	addStroke(resultsRight, Theme.Colors.Stroke, 0.22, 1)
	createStationMark(resultsRight, "DebriefMark", "DB", "REPORT", UDim2.new(1, -136, 0, 18), Color3.fromRGB(138, 154, 166))
	createInsetCard(resultsRight, "StatsCard", UDim2.new(0, 20, 0, 64), UDim2.new(1, -40, 0, 264), Color3.fromRGB(34, 42, 50), Color3.fromRGB(138, 154, 166))
	local resultsStatsRule = new("Frame", {
		Name = "StatsRule",
		BackgroundColor3 = Theme.Colors.BunkerAccent,
		BackgroundTransparency = 0.24,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 20, 0, 50),
		Size = UDim2.new(0, 84, 0, 3),
		Parent = resultsRight,
	})
	addCorner(resultsStatsRule, UDim.new(0, 4))
	local resultsOutcome = label(resultsLeft, "Outcome", "SUCCESS", UDim2.new(0, 34, 0, 34), UDim2.new(1, -68, 0, 30), Theme.Fonts.Heading, Theme.Colors.Accent)
	setFixedText(resultsOutcome, 28)
	local resultsSummary = label(resultsLeft, "Summary", "Extracted cleanly.", UDim2.new(0, 34, 0, 78), UDim2.new(1, -68, 0, 60), Theme.Fonts.Body, Theme.Colors.Text)
	setFixedText(resultsSummary, 16)
	local resultsReward = label(resultsLeft, "Reward", "+0 Deploy Tokens", UDim2.new(0, 34, 0, 138), UDim2.new(1, -68, 0, 26), Theme.Fonts.Heading, Theme.Colors.AccentWarm)
	setFixedText(resultsReward, 22)
	local resultsContinue = createButton(resultsLeft, "Continue", "Back To Lobby", UDim2.new(1, -36, 0, 46), UDim2.new(0, 18, 1, -64), Theme.Colors.Accent)
	resultsContinue.AnchorPoint = Vector2.new(0, 0)
	setFixedText(resultsContinue, 18, Enum.TextXAlignment.Center)
	local resultsStatsHeader = label(resultsRight, "StatsHeader", "Run Stats", UDim2.new(0, 20, 0, 18), UDim2.new(1, -40, 0, 24), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(resultsStatsHeader, 22)
	local resultsStats = {}
	for index, name in ipairs({ "Scenario", "Layout", "Waves", "Kills", "Tokens", "XP", "Level" }) do
		local stat = label(resultsRight, name, name .. ": --", UDim2.new(0, 34, 0, 82 + ((index - 1) * 32)), UDim2.new(1, -190, 0, 22), Theme.Fonts.Body, Theme.Colors.Muted)
		setFixedText(stat, 16)
		resultsStats[name] = stat
	end
	local xpBreakdownCard = createInsetCard(resultsRight, "XpBreakdownCard", UDim2.new(0, 20, 1, -128), UDim2.new(1, -40, 0, 104), Color3.fromRGB(34, 42, 50), Color3.fromRGB(138, 154, 166))
	local resultsXpBreakdown = label(xpBreakdownCard, "XpBreakdown", "XP Breakdown:\nKills: +0 XP\nWaves: +0 XP\nOutcome: +0 XP", UDim2.new(0, 14, 0, 18), UDim2.new(1, -28, 1, -24), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	setFixedText(resultsXpBreakdown, 14)
	local resultsDailyOpsCard = createInsetCard(resultsLeft, "DailyOpsCard", UDim2.new(0, 18, 0, 194), UDim2.new(1, -36, 0, 98), Color3.fromRGB(44, 56, 42), Color3.fromRGB(182, 198, 122))
	local resultsDailyOps = label(resultsDailyOpsCard, "DailyOps", "Daily Ops:\nNo tracked progress this run.", UDim2.new(0, 14, 0, 14), UDim2.new(1, -28, 1, -20), Theme.Fonts.Body, Color3.fromRGB(214, 228, 182))
	setFixedText(resultsDailyOps, 13)
	lobbyRefs.ResultsPopup = resultsPopup
	lobbyRefs.ResultsTitle = resultsTitle
	lobbyRefs.ResultsTag = resultsTag
	lobbyRefs.ResultsOutcome = resultsOutcome
	lobbyRefs.ResultsSummary = resultsSummary
	lobbyRefs.ResultsReward = resultsReward
	lobbyRefs.ResultsContinue = resultsContinue
	lobbyRefs.ResultsStats = resultsStats
	lobbyRefs.ResultsXpBreakdown = resultsXpBreakdown
	lobbyRefs.ResultsDailyOps = resultsDailyOps
end

local function createActivitiesPopup(lobby, lobbyRefs)
	local activitiesPopup = createPopup(lobby, "ActivitiesPopup", UDim2.new(0, 940, 0, 640), UDim2.new(0.12, 0, 0.08, 0), {
		backgroundColor = Color3.fromRGB(32, 42, 54),
		gradientStart = Color3.fromRGB(42, 56, 70),
		gradientEnd = Color3.fromRGB(18, 24, 32),
		strokeColor = Color3.fromRGB(122, 168, 220),
		headerColor = Color3.fromRGB(72, 112, 158),
		headerColorEnd = Color3.fromRGB(42, 72, 104),
		badgeText = "ACT",
		badgeColor = Color3.fromRGB(54, 82, 116),
		iconText = "LOG",
		visible = false,
	})
	local activitiesTitle = label(activitiesPopup, "Title", "Activity Log", UDim2.new(0, 22, 0, 48), UDim2.new(1, -44, 0, 28), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(activitiesTitle, 27)
	local activitiesBody = label(activitiesPopup, "Body", "Review progression, secrets, badge unlocks, and reward tracks for the remote activity districts.", UDim2.new(0, 22, 0, 80), UDim2.new(1, -44, 0, 32), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(activitiesBody, 14)
	local activitiesRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(136, 188, 236),
		BackgroundTransparency = 0.14,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 22, 0, 118),
		Size = UDim2.new(1, -44, 0, 2),
		Parent = activitiesPopup,
	})
	addCorner(activitiesRule, UDim.new(0, 4))

	local activityCardRefs = {}
	local activityCardOrder = {
		{ key = "Training", title = "Training Yard", accent = Color3.fromRGB(120, 176, 124), position = UDim2.new(0, 22, 0, 136) },
		{ key = "Parkour", title = "Parkour Line", accent = Color3.fromRGB(116, 154, 214), position = UDim2.new(0, 22, 0, 298) },
		{ key = "Range", title = "Target Range", accent = Color3.fromRGB(206, 158, 84), position = UDim2.new(0, 326, 0, 136) },
		{ key = "Salvage", title = "Salvage Run", accent = Color3.fromRGB(174, 134, 88), position = UDim2.new(0, 326, 0, 298) },
	}
	for _, definition in ipairs(activityCardOrder) do
		local card = new("Frame", {
			Name = definition.key .. "Card",
			BackgroundColor3 = Color3.fromRGB(20, 28, 36),
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Position = definition.position,
			Size = UDim2.new(0, 276, 0, 146),
			Parent = activitiesPopup,
		})
		addCorner(card, UDim.new(0, 16))
		addStroke(card, definition.accent, 0.18, 1)
		addGradient(card, Color3.fromRGB(30, 40, 52), Color3.fromRGB(16, 22, 30), 0)
		local badge = new("Frame", {
			Name = "Badge",
			BackgroundColor3 = definition.accent,
			BackgroundTransparency = 0.06,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 16, 0, 14),
			Size = UDim2.new(0, 64, 0, 22),
			Parent = card,
		})
		addCorner(badge, UDim.new(0, 10))
		local badgeText = label(badge, "Text", string.upper(definition.key), UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), Theme.Fonts.Heading, Theme.Colors.Text, Enum.TextXAlignment.Center)
		setFixedText(badgeText, 11, Enum.TextXAlignment.Center)
		local title = label(card, "Title", definition.title, UDim2.new(0, 14, 0, 38), UDim2.new(1, -28, 0, 18), Theme.Fonts.Heading, Theme.Colors.Text)
		setFixedText(title, 17)
		local summary = label(card, "Summary", "Level 0 | No runs logged.", UDim2.new(0, 14, 0, 62), UDim2.new(1, -28, 0, 18), Theme.Fonts.Body, Color3.fromRGB(210, 228, 244))
		setFixedText(summary, 13)
		local meta = label(card, "Meta", "Best: -- | Next unlock: Lv.2 reward", UDim2.new(0, 14, 0, 84), UDim2.new(1, -28, 0, 34), Theme.Fonts.Body, Theme.Colors.Muted)
		setFixedText(meta, 12)
		meta.TextWrapped = true
		meta.TextYAlignment = Enum.TextYAlignment.Top
		local reward = label(card, "Reward", "Reward track offline.", UDim2.new(0, 14, 1, -48), UDim2.new(1, -154, 0, 32), Theme.Fonts.Body, definition.accent)
		setFixedText(reward, 13)
		reward.TextWrapped = true
		reward.TextYAlignment = Enum.TextYAlignment.Top
		local actionButton = createButton(card, "ActionButton", "Go To Lane", UDim2.new(0, 116, 0, 28), UDim2.new(1, -14, 1, -14), definition.accent)
		actionButton.AnchorPoint = Vector2.new(1, 1)
		setFixedText(actionButton, 13, Enum.TextXAlignment.Center)
		activityCardRefs[definition.key] = {
			Frame = card,
			Title = title,
			Summary = summary,
			Meta = meta,
			Reward = reward,
			ActionButton = actionButton,
		}
	end

	local activitySidebar = new("Frame", {
		Name = "Sidebar",
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -290, 0, 136),
		Size = UDim2.new(0, 268, 0, 432),
		Parent = activitiesPopup,
	})
	local function createSidebarPanel(name, titleText, positionY, accent)
		local panel = new("Frame", {
			Name = name,
			BackgroundColor3 = Color3.fromRGB(18, 24, 30),
			BackgroundTransparency = 0.06,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, positionY),
			Size = UDim2.new(1, 0, 0, 132),
			Parent = activitySidebar,
		})
		addCorner(panel, UDim.new(0, 16))
		addStroke(panel, accent, 0.18, 1)
		addGradient(panel, Color3.fromRGB(28, 36, 46), Color3.fromRGB(14, 18, 24), 0)
		local heading = label(panel, "Title", titleText, UDim2.new(0, 14, 0, 12), UDim2.new(1, -28, 0, 18), Theme.Fonts.Heading, Theme.Colors.Text)
		setFixedText(heading, 16)
		local body = label(panel, "Body", "--", UDim2.new(0, 14, 0, 36), UDim2.new(1, -28, 1, -50), Theme.Fonts.Body, Color3.fromRGB(208, 222, 238))
		setFixedText(body, 13)
		body.TextWrapped = true
		body.TextYAlignment = Enum.TextYAlignment.Top
		return body
	end
	local activitySecretsSummary = createSidebarPanel("SecretsPanel", "Secrets", 0, Color3.fromRGB(96, 154, 214))
	local activityRewardsSummary = createSidebarPanel("RewardsPanel", "Exclusive Rewards", 148, Color3.fromRGB(210, 162, 92))
	local activityBadgesSummary = createSidebarPanel("BadgesPanel", "Badge Log", 296, Color3.fromRGB(122, 186, 128))

	local closeActivitiesButton = createButton(activitiesPopup, "CloseActivitiesButton", "Close Panel", UDim2.new(0, 124, 0, 40), UDim2.new(1, -22, 1, -34), Theme.Colors.Backdrop)
	closeActivitiesButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(closeActivitiesButton, 16, Enum.TextXAlignment.Center)
	local backToOpsButton = createButton(activitiesPopup, "BackToOpsButton", "Back To Ops", UDim2.new(0, 152, 0, 40), UDim2.new(1, -154, 1, -34), Theme.Colors.CommandBlue)
	backToOpsButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(backToOpsButton, 16, Enum.TextXAlignment.Center)

	lobbyRefs.Popups.Activities = activitiesPopup
	lobbyRefs.ActivitiesPopup = activitiesPopup
	lobbyRefs.ActivityCards = activityCardRefs
	lobbyRefs.ActivitySecretsSummary = activitySecretsSummary
	lobbyRefs.ActivityRewardsSummary = activityRewardsSummary
	lobbyRefs.ActivityBadgesSummary = activityBadgesSummary
	lobbyRefs.CloseActivitiesButton = closeActivitiesButton
	lobbyRefs.BackToOpsButton = backToOpsButton
end

local function createQuestBoardPopup(lobby, lobbyRefs)
	local questBoardPopup = createPopup(lobby, "QuestBoardPopup", UDim2.new(0, 920, 0, 472), UDim2.new(0.16, 0, 0.12, 0), {
		backgroundColor = Color3.fromRGB(10, 14, 22),
		gradientStart = Color3.fromRGB(18, 28, 52),
		gradientEnd = Color3.fromRGB(6, 10, 18),
		strokeColor = Color3.fromRGB(118, 156, 212),
		headerColor = Color3.fromRGB(38, 66, 122),
		headerColorEnd = Color3.fromRGB(20, 34, 62),
		badgeText = "STAGING",
		badgeColor = Color3.fromRGB(50, 72, 112),
		iconText = "OPS",
		visible = false,
	})
	local questBoardBadgeNode = questBoardPopup:FindFirstChild("Badge")
	if questBoardBadgeNode and questBoardBadgeNode:IsA("GuiObject") then
		questBoardBadgeNode.Position = UDim2.new(0, 56, 0, 36)
		questBoardBadgeNode.Size = UDim2.new(0, 68, 0, 22)
	end
	local questBoardEmblemNode = questBoardPopup:FindFirstChild("Emblem")
	if questBoardEmblemNode and questBoardEmblemNode:IsA("GuiObject") then
		questBoardEmblemNode.Position = UDim2.new(1, -60, 0, 14)
		questBoardEmblemNode.Size = UDim2.new(0, 34, 0, 34)
	end
	new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(116, 154, 214),
		BackgroundTransparency = 0.24,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 24, 0, 92),
		Size = UDim2.new(1, -52, 0, 1),
		Parent = questBoardPopup,
	})
	local questBoardTitle = label(questBoardPopup, "Title", "Zombie Survival", UDim2.new(0, 50, 0, 84), UDim2.new(0, 240, 0, 28), Theme.Fonts.Heading, Color3.fromRGB(244, 248, 255))
	setFixedText(questBoardTitle, 24)
	local questBoardBody = label(questBoardPopup, "Body", "Stage your operator, route the squad, and push into the next breach.", UDim2.new(0, 50, 0, 116), UDim2.new(0, 314, 0, 36), Theme.Fonts.Body, Color3.fromRGB(198, 210, 228))
	setFixedText(questBoardBody, 14)

	local opsLeftCard = createInsetCard(questBoardPopup, "OpsLeftCard", UDim2.new(0, 28, 0, 112), UDim2.new(0, 268, 0, 310), Color3.fromRGB(6, 10, 16), Color3.fromRGB(112, 152, 214))
	local opsRightCard = createInsetCard(questBoardPopup, "OpsRightCard", UDim2.new(0, 316, 0, 112), UDim2.new(1, -344, 0, 310), Color3.fromRGB(6, 10, 16), Color3.fromRGB(112, 152, 214))

	local dailyQuestTitle = label(opsLeftCard, "DailyQuestTitle", "Bunker Ready", UDim2.new(0, 18, 0, 26), UDim2.new(1, -36, 0, 20), Theme.Fonts.Heading, Color3.fromRGB(244, 248, 255))
	setFixedText(dailyQuestTitle, 17)
	local dailyQuestBody = label(opsLeftCard, "DailyQuestBody", "Quartermaster stock, squad routing, and skill branches are live from the lobby shell.", UDim2.new(0, 18, 0, 52), UDim2.new(1, -36, 0, 40), Theme.Fonts.Body, Color3.fromRGB(202, 214, 232))
	setFixedText(dailyQuestBody, 13)
	local readinessCard = createInsetCard(opsLeftCard, "ReadinessCard", UDim2.new(0, 18, 0, 96), UDim2.new(1, -36, 0, 96), Color3.fromRGB(34, 44, 58), Color3.fromRGB(118, 162, 220))
	local readinessTitle = label(readinessCard, "ReadinessTitle", "Bunker Ready", UDim2.new(0, 16, 0, 14), UDim2.new(1, -32, 0, 20), Theme.Fonts.Heading, Color3.fromRGB(242, 246, 255))
	setFixedText(readinessTitle, 16)
	local readinessBody = label(readinessCard, "ReadinessBody", "Quartermaster stock, squad routing, and skill branches are all live from the lobby shell.", UDim2.new(0, 16, 0, 42), UDim2.new(1, -32, 0, 34), Theme.Fonts.Body, Color3.fromRGB(194, 206, 224))
	setFixedText(readinessBody, 12)
	local dailyQuestStatus = label(readinessCard, "DailyQuestStatus", "Live session.", UDim2.new(0, 16, 1, -30), UDim2.new(0, 128, 0, 18), Theme.Fonts.Body, Color3.fromRGB(204, 244, 178))
	setFixedText(dailyQuestStatus, 11)

	local weeklyCard = createInsetCard(opsLeftCard, "WeeklyCard", UDim2.new(0, 18, 0, 206), UDim2.new(0.5, -10, 0, 82), Color3.fromRGB(26, 32, 42), Color3.fromRGB(214, 170, 92))
	local weeklyQuestTitle = label(weeklyCard, "WeeklyQuestTitle", "Ops", UDim2.new(0, 14, 0, 14), UDim2.new(1, -28, 0, 16), Theme.Fonts.Heading, Color3.fromRGB(240, 196, 118))
	setFixedText(weeklyQuestTitle, 14)
	local weeklyQuestBody = label(weeklyCard, "WeeklyQuestBody", "Deploy from the HUD instead of a floor pad.", UDim2.new(0, 14, 0, 38), UDim2.new(1, -28, 0, 34), Theme.Fonts.Body, Color3.fromRGB(206, 214, 228))
	setFixedText(weeklyQuestBody, 12)
	local weeklyQuestStatus = label(weeklyCard, "WeeklyQuestStatus", "Supporter access inactive.", UDim2.new(0, 14, 1, -24), UDim2.new(1, -28, 0, 14), Theme.Fonts.Body, Color3.fromRGB(228, 196, 140))
	setFixedText(weeklyQuestStatus, 11)

	local activityMiniCard = createInsetCard(opsLeftCard, "ActivityMiniCard", UDim2.new(0.5, 10, 0, 206), UDim2.new(0.5, -10, 0, 82), Color3.fromRGB(26, 32, 42), Color3.fromRGB(102, 144, 212))
	local activityQuestTitle = label(activityMiniCard, "ActivityQuestTitle", "Locker", UDim2.new(0, 14, 0, 14), UDim2.new(1, -28, 0, 16), Theme.Fonts.Heading, Color3.fromRGB(152, 194, 246))
	setFixedText(activityQuestTitle, 14)
	local activityQuestBody = label(activityMiniCard, "ActivityQuestBody", "Inventory and skins stay separate from market stock.", UDim2.new(0, 14, 0, 38), UDim2.new(1, -28, 0, 34), Theme.Fonts.Body, Color3.fromRGB(206, 214, 228))
	setFixedText(activityQuestBody, 12)

	local rightTag = label(opsRightCard, "RightTag", "OUTPOST STATUS", UDim2.new(0, 18, 0, 16), UDim2.new(0, 220, 0, 18), Theme.Fonts.Body, Color3.fromRGB(138, 176, 238))
	setFixedText(rightTag, 12)
	local heroTitle = label(opsRightCard, "HeroTitle", "Hold the line.\nDeploy with your squad.", UDim2.new(0, 18, 0, 38), UDim2.new(1, -36, 0, 58), Theme.Fonts.Heading, Color3.fromRGB(248, 250, 255))
	setFixedText(heroTitle, 17)
	local heroBody = label(opsRightCard, "HeroBody", "The bunker shell is stable. Quartermaster stock, skill routing, and squad command are all staged from the lobby.", UDim2.new(0, 18, 0, 104), UDim2.new(1, -36, 0, 38), Theme.Fonts.Body, Color3.fromRGB(198, 210, 228))
	setFixedText(heroBody, 13)

	local signalPane = createInsetCard(opsRightCard, "SignalPane", UDim2.new(0, 18, 0, 160), UDim2.new(1, -36, 0, 94), Color3.fromRGB(34, 44, 58), Color3.fromRGB(118, 152, 214))
	local signalBars = {
		{ x = 20, y = 62, width = 16, height = 40, color = Color3.fromRGB(88, 132, 214) },
		{ x = 50, y = 24, width = 16, height = 78, color = Color3.fromRGB(112, 162, 236) },
		{ x = 80, y = 46, width = 16, height = 56, color = Color3.fromRGB(102, 146, 218) },
		{ x = 110, y = 8, width = 16, height = 94, color = Color3.fromRGB(208, 162, 84) },
	}
	for _, barInfo in ipairs(signalBars) do
		local bar = new("Frame", {
			Name = "SignalBar",
			BackgroundColor3 = barInfo.color,
			BorderSizePixel = 0,
			Position = UDim2.new(0, barInfo.x, 0, barInfo.y),
			Size = UDim2.new(0, barInfo.width, 0, barInfo.height),
			Parent = signalPane,
		})
		addCorner(bar, UDim.new(0, 8))
	end
	local signalTilt = new("Frame", {
		Name = "SignalTilt",
		BackgroundColor3 = Color3.fromRGB(68, 84, 108),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Rotation = 14,
		Position = UDim2.new(1, -184, 0, 14),
		Size = UDim2.new(0, 56, 0, 76),
		Parent = signalPane,
	})
	addCorner(signalTilt, UDim.new(0, 20))
	local signalTitle = label(signalPane, "SignalTitle", "SESSION SIGNAL", UDim2.new(0, 152, 0, 16), UDim2.new(1, -164, 0, 18), Theme.Fonts.Heading, Color3.fromRGB(226, 236, 250))
	setFixedText(signalTitle, 15)
	local signalBody = label(signalPane, "SignalBody", "Squad channels, rewards, and deployment systems are ready for the next run.", UDim2.new(0, 152, 0, 42), UDim2.new(1, -170, 0, 38), Theme.Fonts.Body, Color3.fromRGB(198, 210, 228))
	setFixedText(signalBody, 13)

	local questOpsList = createListFrame(opsRightCard, "QuestOpsList", UDim2.new(0, 18, 0, 264), UDim2.new(1, -36, 0, 32))
	local questOpsEmpty = label(opsRightCard, "QuestOpsEmpty", "Daily ops offline.", UDim2.new(0, 18, 0, 270), UDim2.new(1, -36, 0, 18), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Center)
	setFixedText(questOpsEmpty, 14)

	local summaryStrip = createInsetCard(opsRightCard, "SummaryStrip", UDim2.new(0, 18, 1, -72), UDim2.new(1, -36, 0, 42), Color3.fromRGB(18, 26, 36), Color3.fromRGB(86, 122, 180))
	local questBoardSummary = label(summaryStrip, "Summary", "Quartermaster stock, squad routing, and skill branches are staged from the lobby shell.", UDim2.new(0, 14, 0, 8), UDim2.new(1, -28, 0, 16), Theme.Fonts.Body, Color3.fromRGB(214, 224, 188))
	setFixedText(questBoardSummary, 12)
	local activitySummary = label(summaryStrip, "ActivitySummary", "Training Lv.0 | Parkour Lv.0 | Range Lv.0 | Salvage Lv.0", UDim2.new(0, 14, 0, 22), UDim2.new(1, -28, 0, 14), Theme.Fonts.Body, Color3.fromRGB(196, 220, 248))
	setFixedText(activitySummary, 10)
	local footerHint = label(opsRightCard, "FooterHint", "Enter the bunker flow and open the command grid.", UDim2.new(0, 18, 1, -24), UDim2.new(1, -260, 0, 12), Theme.Fonts.Body, Color3.fromRGB(198, 210, 228))
	setFixedText(footerHint, 10)

	local claimDailyQuestButton = createButton(questBoardPopup, "ClaimDailyQuestButton", "Daily Ops", UDim2.new(0, 126, 0, 38), UDim2.new(0.52, 0, 1, -58), Theme.Colors.AccentWarm)
	claimDailyQuestButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(claimDailyQuestButton, 15, Enum.TextXAlignment.Center)
	local claimWeeklyQuestButton = createButton(questBoardPopup, "ClaimWeeklyQuestButton", "Weekly Crate", UDim2.new(0, 126, 0, 38), UDim2.new(0.665, 0, 1, -58), Color3.fromRGB(180, 154, 86))
	claimWeeklyQuestButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(claimWeeklyQuestButton, 15, Enum.TextXAlignment.Center)
	local closeQuestBoardButton = createButton(questBoardPopup, "CloseQuestBoardButton", "Close", UDim2.new(0, 104, 0, 38), UDim2.new(1, -22, 1, -58), Theme.Colors.Backdrop)
	closeQuestBoardButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(closeQuestBoardButton, 15, Enum.TextXAlignment.Center)
	local openActivitiesButton = createButton(opsRightCard, "OpenActivitiesButton", "Activities", UDim2.new(0, 196, 0, 42), UDim2.new(1, -18, 1, -62), Color3.fromRGB(118, 188, 92))
	openActivitiesButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(openActivitiesButton, 18, Enum.TextXAlignment.Center)

	lobbyRefs.Popups.QuestBoard = questBoardPopup
	lobbyRefs.QuestBoardPopup = questBoardPopup
	lobbyRefs.DailyQuestStatus = dailyQuestStatus
	lobbyRefs.WeeklyQuestStatus = weeklyQuestStatus
	lobbyRefs.QuestOpsList = questOpsList
	lobbyRefs.QuestOpsEmpty = questOpsEmpty
	lobbyRefs.QuestBoardSummary = questBoardSummary
	lobbyRefs.ActivitySummary = activitySummary
	lobbyRefs.ClaimDailyQuestButton = claimDailyQuestButton
	lobbyRefs.ClaimWeeklyQuestButton = claimWeeklyQuestButton
	lobbyRefs.CloseQuestBoardButton = closeQuestBoardButton
	lobbyRefs.OpenActivitiesButton = openActivitiesButton
end

local function createNpcDialoguePopup(lobby, lobbyRefs)
	local npcDialoguePopup = createPopup(lobby, "NpcDialoguePopup", UDim2.new(0, 520, 0, 286), UDim2.new(0.59, 0, 0.16, 0), {
		backgroundColor = Color3.fromRGB(38, 46, 56),
		gradientStart = Color3.fromRGB(50, 62, 76),
		gradientEnd = Color3.fromRGB(24, 30, 38),
		strokeColor = Color3.fromRGB(122, 170, 220),
		headerColor = Color3.fromRGB(82, 122, 176),
		headerColorEnd = Color3.fromRGB(42, 62, 94),
		badgeText = "CONTACT",
		badgeColor = Color3.fromRGB(64, 88, 122),
		iconText = "NPC",
		visible = false,
	})
	local npcDialogueBadgeNode = npcDialoguePopup:FindFirstChild("Badge")
	if npcDialogueBadgeNode and npcDialogueBadgeNode:IsA("GuiObject") then
		npcDialogueBadgeNode.Visible = false
	end
	local npcDialogueEmblemNode = npcDialoguePopup:FindFirstChild("Emblem")
	if npcDialogueEmblemNode and npcDialogueEmblemNode:IsA("GuiObject") then
		npcDialogueEmblemNode.Visible = false
	end
	local npcDialogueRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(122, 170, 220),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 24, 0, 112),
		Size = UDim2.new(1, -48, 0, 2),
		Parent = npcDialoguePopup,
	})
	addCorner(npcDialogueRule, UDim.new(0, 4))
	local npcDialogueTitle = label(npcDialoguePopup, "Title", "Outpost Contact", UDim2.new(0, 24, 0, 62), UDim2.new(1, -48, 0, 28), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(npcDialogueTitle, 25)
	local npcDialogueRole = label(npcDialoguePopup, "Role", "Station lead", UDim2.new(0, 24, 0, 98), UDim2.new(1, -48, 0, 18), Theme.Fonts.Body, Color3.fromRGB(184, 214, 244))
	setFixedText(npcDialogueRole, 13)
	local npcDialogueBody = label(npcDialoguePopup, "Body", "Local contact update.", UDim2.new(0, 24, 0, 126), UDim2.new(1, -48, 0, 74), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(npcDialogueBody, 15)
	local npcDialogueActionButton = createButton(npcDialoguePopup, "NpcDialogueActionButton", "Open Station", UDim2.new(0, 184, 0, 42), UDim2.new(0, 24, 1, -58), Theme.Colors.AccentWarm)
	npcDialogueActionButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(npcDialogueActionButton, 16, Enum.TextXAlignment.Center)
	local npcDialogueCloseButton = createButton(npcDialoguePopup, "NpcDialogueCloseButton", "Close", UDim2.new(0, 112, 0, 42), UDim2.new(0, 220, 1, -58), Theme.Colors.Backdrop)
	npcDialogueCloseButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(npcDialogueCloseButton, 16, Enum.TextXAlignment.Center)

	lobbyRefs.Popups.NpcDialogue = npcDialoguePopup
	lobbyRefs.NpcDialoguePopup = npcDialoguePopup
	lobbyRefs.NpcDialogueTitle = npcDialogueTitle
	lobbyRefs.NpcDialogueRole = npcDialogueRole
	lobbyRefs.NpcDialogueBody = npcDialogueBody
	lobbyRefs.NpcDialogueActionButton = npcDialogueActionButton
	lobbyRefs.NpcDialogueCloseButton = npcDialogueCloseButton
end

local function createAdminPopup(lobby, lobbyRefs)
	local adminPopup = createPopup(lobby, "AdminPopup", UDim2.new(0, 836, 0, 874), UDim2.new(0.5, -418, 0.05, 0), {
		backgroundColor = Color3.fromRGB(48, 40, 30),
		gradientStart = Color3.fromRGB(64, 54, 40),
		gradientEnd = Color3.fromRGB(30, 24, 18),
		strokeColor = Color3.fromRGB(196, 166, 108),
		headerColor = Color3.fromRGB(156, 126, 72),
		headerColorEnd = Color3.fromRGB(92, 72, 40),
		badgeText = "OWNER",
		badgeColor = Color3.fromRGB(82, 62, 32),
		iconText = "CMD",
		visible = false,
	})
	local adminTitle = label(adminPopup, "Title", "Operations Control", UDim2.new(0, 22, 0, 48), UDim2.new(1, -44, 0, 28), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(adminTitle, 22)
	local adminBody = label(adminPopup, "Body", "Run live session, progression, moderation, and event controls without leaving the current server.", UDim2.new(0, 22, 0, 80), UDim2.new(1, -44, 0, 28), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(adminBody, 14)
	local adminSummary = label(adminPopup, "Summary", "Commands ready.", UDim2.new(0, 22, 0, 114), UDim2.new(1, -44, 0, 20), Theme.Fonts.Body, Color3.fromRGB(255, 226, 166))
	setFixedText(adminSummary, 13)
	local adminTargetTitle = label(adminPopup, "TargetTitle", "Server Roster", UDim2.new(0, 22, 0, 152), UDim2.new(0, 206, 0, 22), Theme.Fonts.Heading, Color3.fromRGB(246, 236, 214))
	setFixedText(adminTargetTitle, 17)
	local adminTargetSub = label(adminPopup, "TargetSub", "Select a player to grant items, change access, or moderate this server.", UDim2.new(0, 22, 0, 176), UDim2.new(0, 206, 0, 30), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(adminTargetSub, 12)
	local adminTargetList = createListFrame(adminPopup, "AdminTargetList", UDim2.new(0, 22, 0, 212), UDim2.new(0, 206, 0, 214))
	adminTargetList.BackgroundColor3 = Color3.fromRGB(24, 22, 18)
	local adminTargetSummaryCard = new("Frame", {
		Name = "AdminTargetSummaryCard",
		BackgroundColor3 = Color3.fromRGB(32, 26, 20),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 246, 0, 152),
		Size = UDim2.new(1, -268, 0, 96),
		Parent = adminPopup,
	})
	addCorner(adminTargetSummaryCard, UDim.new(0, 16))
	addStroke(adminTargetSummaryCard, Color3.fromRGB(196, 166, 108), 0.2, 1)
	local adminTargetName = label(adminTargetSummaryCard, "TargetName", "Target: Self", UDim2.new(0, 14, 0, 10), UDim2.new(0.5, -20, 0, 22), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(adminTargetName, 17)
	local adminTargetRole = label(adminTargetSummaryCard, "TargetRole", "Survivor", UDim2.new(0.5, 8, 0, 10), UDim2.new(0.5, -22, 0, 22), Theme.Fonts.Body, Color3.fromRGB(255, 214, 156))
	setFixedText(adminTargetRole, 14)
	local adminTargetMeta = label(adminTargetSummaryCard, "TargetMeta", "Select a player from the server roster or leave it on self for local commands.", UDim2.new(0, 14, 0, 34), UDim2.new(1, -28, 0, 20), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(adminTargetMeta, 12)
	local adminTargetStats = label(adminTargetSummaryCard, "TargetStats", "Lv.1 | Tokens 0 | Runs 0 | Kills 0", UDim2.new(0, 14, 0, 58), UDim2.new(1, -28, 0, 22), Theme.Fonts.Body, Color3.fromRGB(226, 208, 176))
	setFixedText(adminTargetStats, 13)

	local adminOverviewStrip = new("Frame", {
		Name = "AdminOverviewStrip",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 246, 0, 258),
		Size = UDim2.new(1, -268, 0, 54),
		Parent = adminPopup,
	})
	local function createOverviewCard(name, xOffset, width, titleText, valueText, accentColor)
		local card = new("Frame", {
			Name = name,
			BackgroundColor3 = Color3.fromRGB(34, 28, 22),
			BackgroundTransparency = 0.04,
			BorderSizePixel = 0,
			Position = UDim2.new(0, xOffset, 0, 0),
			Size = UDim2.new(0, width, 1, 0),
			Parent = adminOverviewStrip,
		})
		addCorner(card, UDim.new(0, 14))
		addStroke(card, accentColor, 0.22, 1)
		local title = label(card, "Title", titleText, UDim2.new(0, 12, 0, 8), UDim2.new(1, -24, 0, 14), Theme.Fonts.Body, Theme.Colors.Muted)
		setFixedText(title, 11)
		local value = label(card, "Value", valueText, UDim2.new(0, 12, 0, 24), UDim2.new(1, -24, 0, 18), Theme.Fonts.Heading, Theme.Colors.Text)
		setFixedText(value, 14)
		return value
	end
	local adminRoleValue = createOverviewCard("RoleCard", 0, 132, "ROLE", "MOD", Color3.fromRGB(196, 166, 108))
	local adminEventValue = createOverviewCard("EventCard", 146, 150, "EVENT", "AUTO", Color3.fromRGB(102, 132, 188))
	local adminMissionValue = createOverviewCard("MissionCard", 310, 150, "RUN STATE", "LOBBY", Color3.fromRGB(94, 156, 108))
	local adminTargetValue = createOverviewCard("TargetCard", 474, 92, "TARGET", "SELF", Color3.fromRGB(168, 122, 74))

	local adminTabStrip = new("Frame", {
		Name = "AdminTabStrip",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 246, 0, 326),
		Size = UDim2.new(1, -268, 0, 40),
		Parent = adminPopup,
	})
	local adminTabs = {}
	local adminTabOrder = {
		{ key = "Session", text = "Session", color = Color3.fromRGB(92, 150, 112) },
		{ key = "Progression", text = "Progression", color = Color3.fromRGB(188, 142, 76) },
		{ key = "LiveOps", text = "Live Ops", color = Color3.fromRGB(102, 132, 188) },
		{ key = "Access", text = "Access", color = Color3.fromRGB(148, 86, 86) },
	}
	for index, info in ipairs(adminTabOrder) do
		local tabButton = createButton(adminTabStrip, info.key .. "TabButton", info.text, UDim2.new(0, 122, 0, 34), UDim2.new(0, ((index - 1) * 132), 0, 0), info.color)
		tabButton.AnchorPoint = Vector2.zero
		setFixedText(tabButton, 13, Enum.TextXAlignment.Center)
		adminTabs[info.key] = tabButton
	end

	local adminContentFrame = new("Frame", {
		Name = "AdminContentFrame",
		BackgroundColor3 = Color3.fromRGB(28, 24, 18),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 246, 0, 376),
		Size = UDim2.new(1, -268, 1, -432),
		Parent = adminPopup,
	})
	addCorner(adminContentFrame, UDim.new(0, 18))
	addStroke(adminContentFrame, Color3.fromRGB(196, 166, 108), 0.22, 1)

	local adminPages = {
		Session = addPage(adminContentFrame, "SessionPage"),
		Progression = addPage(adminContentFrame, "ProgressionPage"),
		LiveOps = addPage(adminContentFrame, "LiveOpsPage"),
		Access = addPage(adminContentFrame, "AccessPage"),
	}

	local function createAdminSection(page, name, titleText, bodyText, position, size, accentColor)
		local section = new("Frame", {
			Name = name,
			BackgroundColor3 = Color3.fromRGB(34, 28, 22),
			BackgroundTransparency = 0.06,
			BorderSizePixel = 0,
			Position = position,
			Size = size,
			Parent = page,
		})
		addCorner(section, UDim.new(0, 16))
		addStroke(section, accentColor or Color3.fromRGB(196, 166, 108), 0.22, 1)
		local title = label(section, "Title", titleText, UDim2.new(0, 16, 0, 14), UDim2.new(1, -32, 0, 22), Theme.Fonts.Heading, Theme.Colors.Text)
		setFixedText(title, 18)
		local body = label(section, "Body", bodyText, UDim2.new(0, 16, 0, 40), UDim2.new(1, -32, 0, 30), Theme.Fonts.Body, Theme.Colors.Muted)
		setFixedText(body, 13)
		return section
	end

	local sessionSection = createAdminSection(adminPages.Session, "SessionSection", "Session Actions", "Fast recovery and lobby control for the current server squad.", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 212), Color3.fromRGB(94, 156, 108))
	local adminHealButton = createButton(sessionSection, "HealButton", "Heal Self", UDim2.new(0, 170, 0, 40), UDim2.new(0, 16, 0, 92), Color3.fromRGB(94, 156, 108))
	adminHealButton.AnchorPoint = Vector2.zero
	setFixedText(adminHealButton, 15, Enum.TextXAlignment.Center)
	local adminHealSquadButton = createButton(sessionSection, "HealSquadButton", "Heal Squad", UDim2.new(0, 170, 0, 40), UDim2.new(0, 202, 0, 92), Color3.fromRGB(82, 146, 118))
	adminHealSquadButton.AnchorPoint = Vector2.zero
	setFixedText(adminHealSquadButton, 15, Enum.TextXAlignment.Center)
	local adminReviveSquadButton = createButton(sessionSection, "ReviveSquadButton", "Revive Squad", UDim2.new(0, 170, 0, 40), UDim2.new(0, 388, 0, 92), Color3.fromRGB(92, 168, 132))
	adminReviveSquadButton.AnchorPoint = Vector2.zero
	setFixedText(adminReviveSquadButton, 15, Enum.TextXAlignment.Center)
	local adminReturnButton = createButton(sessionSection, "ReturnButton", "Return To Lobby", UDim2.new(0, 264, 0, 40), UDim2.new(0, 16, 0, 138), Color3.fromRGB(168, 92, 92))
	adminReturnButton.AnchorPoint = Vector2.zero
	setFixedText(adminReturnButton, 15, Enum.TextXAlignment.Center)
	local adminRefreshButton = createButton(sessionSection, "RefreshButton", "Refresh Access", UDim2.new(0, 264, 0, 40), UDim2.new(0, 294, 0, 138), Theme.Colors.Backdrop)
	adminRefreshButton.AnchorPoint = Vector2.zero
	setFixedText(adminRefreshButton, 15, Enum.TextXAlignment.Center)
	local adminRestoreSquadButton = createButton(sessionSection, "RestoreSquadButton", "Restore Squad", UDim2.new(0, 264, 0, 40), UDim2.new(0, 16, 0, 184), Color3.fromRGB(92, 164, 138))
	adminRestoreSquadButton.AnchorPoint = Vector2.zero
	setFixedText(adminRestoreSquadButton, 15, Enum.TextXAlignment.Center)
	local adminOpenLiveOpsButton = createButton(sessionSection, "OpenLiveOpsButton", "Jump To Live Ops", UDim2.new(0, 264, 0, 40), UDim2.new(0, 294, 0, 184), Color3.fromRGB(98, 124, 184))
	adminOpenLiveOpsButton.AnchorPoint = Vector2.zero
	setFixedText(adminOpenLiveOpsButton, 15, Enum.TextXAlignment.Center)

	local progressionEconomySection = createAdminSection(adminPages.Progression, "EconomySection", "Economy Grants", "Quick progression boosts for controlled testing and admin recovery.", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 166), Color3.fromRGB(188, 142, 76))
	local adminTokensButton = createButton(progressionEconomySection, "TokensButton", "+250 Tokens", UDim2.new(0, 154, 0, 40), UDim2.new(0, 16, 0, 92), Color3.fromRGB(188, 142, 76))
	adminTokensButton.AnchorPoint = Vector2.zero
	setFixedText(adminTokensButton, 15, Enum.TextXAlignment.Center)
	local adminTokensLargeButton = createButton(progressionEconomySection, "TokensLargeButton", "+1000 Tokens", UDim2.new(0, 154, 0, 40), UDim2.new(0, 184, 0, 92), Color3.fromRGB(204, 158, 84))
	adminTokensLargeButton.AnchorPoint = Vector2.zero
	setFixedText(adminTokensLargeButton, 15, Enum.TextXAlignment.Center)
	local adminXpButton = createButton(progressionEconomySection, "XpButton", "+250 XP", UDim2.new(0, 154, 0, 40), UDim2.new(0, 352, 0, 92), Theme.Colors.CommandBlue)
	adminXpButton.AnchorPoint = Vector2.zero
	setFixedText(adminXpButton, 15, Enum.TextXAlignment.Center)
	local adminXpLargeButton = createButton(progressionEconomySection, "XpLargeButton", "+1000 XP", UDim2.new(0, 154, 0, 40), UDim2.new(0, 16, 0, 138), Color3.fromRGB(102, 144, 204))
	adminXpLargeButton.AnchorPoint = Vector2.zero
	setFixedText(adminXpLargeButton, 15, Enum.TextXAlignment.Center)
	local adminGrantTokensTargetButton = createButton(progressionEconomySection, "GrantTokensTargetButton", "Give Target Tokens", UDim2.new(0, 154, 0, 40), UDim2.new(0, 184, 0, 138), Color3.fromRGB(182, 138, 74))
	adminGrantTokensTargetButton.AnchorPoint = Vector2.zero
	setFixedText(adminGrantTokensTargetButton, 15, Enum.TextXAlignment.Center)
	local adminGrantXpTargetButton = createButton(progressionEconomySection, "GrantXpTargetButton", "Give Target XP", UDim2.new(0, 154, 0, 40), UDim2.new(0, 352, 0, 138), Color3.fromRGB(82, 124, 186))
	adminGrantXpTargetButton.AnchorPoint = Vector2.zero
	setFixedText(adminGrantXpTargetButton, 15, Enum.TextXAlignment.Center)

	local progressionLoadoutSection = createAdminSection(adminPages.Progression, "LoadoutSection", "Target Loadout", "Direct profile changes for the selected operator.", UDim2.new(0, 0, 0, 184), UDim2.new(1, 0, 0, 164), Color3.fromRGB(122, 94, 172))
	local adminHealTargetButton = createButton(progressionLoadoutSection, "HealTargetButton", "Heal Target", UDim2.new(0, 154, 0, 40), UDim2.new(0, 16, 0, 62), Color3.fromRGB(82, 154, 118))
	adminHealTargetButton.AnchorPoint = Vector2.zero
	setFixedText(adminHealTargetButton, 15, Enum.TextXAlignment.Center)
	local adminGrantWeaponsButton = createButton(progressionLoadoutSection, "GrantWeaponsButton", "Give All Weapons", UDim2.new(0, 154, 0, 40), UDim2.new(0, 184, 0, 62), Color3.fromRGB(166, 112, 78))
	adminGrantWeaponsButton.AnchorPoint = Vector2.zero
	setFixedText(adminGrantWeaponsButton, 15, Enum.TextXAlignment.Center)
	local adminGrantCosmeticsButton = createButton(progressionLoadoutSection, "GrantCosmeticsButton", "Give All Cosmetics", UDim2.new(0, 154, 0, 40), UDim2.new(0, 352, 0, 62), Color3.fromRGB(122, 94, 172))
	adminGrantCosmeticsButton.AnchorPoint = Vector2.zero
	setFixedText(adminGrantCosmeticsButton, 15, Enum.TextXAlignment.Center)
	local adminGrantBundleButton = createButton(progressionLoadoutSection, "GrantBundleButton", "Grant Target Bundle", UDim2.new(0, 248, 0, 40), UDim2.new(0, 16, 0, 108), Color3.fromRGB(176, 134, 88))
	adminGrantBundleButton.AnchorPoint = Vector2.zero
	setFixedText(adminGrantBundleButton, 15, Enum.TextXAlignment.Center)
	local adminRestoreTargetButton = createButton(progressionLoadoutSection, "RestoreTargetButton", "Restore Target", UDim2.new(0, 248, 0, 40), UDim2.new(0, 280, 0, 108), Color3.fromRGB(88, 152, 122))
	adminRestoreTargetButton.AnchorPoint = Vector2.zero
	setFixedText(adminRestoreTargetButton, 15, Enum.TextXAlignment.Center)

	local statEditorSection = createAdminSection(adminPages.Progression, "StatEditorSection", "Stat Editor", "Set exact values for the selected target. Use this for leaderboard testing or account recovery.", UDim2.new(0, 0, 0, 366), UDim2.new(1, 0, 0, 220), Color3.fromRGB(104, 132, 198))
	local function createAdminValueEditor(parent, name, labelText, yOffset, buttonText, accentColor)
		local row = new("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 16, 0, yOffset),
			Size = UDim2.new(1, -32, 0, 36),
			Parent = parent,
		})
		local fieldLabel = label(row, "Label", labelText, UDim2.new(0, 0, 0, 8), UDim2.new(0, 96, 0, 18), Theme.Fonts.Body, Theme.Colors.Text)
		setFixedText(fieldLabel, 13)
		local input = new("TextBox", {
			Name = "Input",
			BackgroundColor3 = Color3.fromRGB(26, 30, 38),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 104, 0, 0),
			Size = UDim2.new(0, 150, 1, 0),
			ClearTextOnFocus = false,
			PlaceholderText = "Enter value",
			Text = "",
			TextColor3 = Theme.Colors.Text,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Theme.Fonts.Body,
			Parent = row,
		})
		addCorner(input, UDim.new(0, 10))
		addStroke(input, Color3.fromRGB(118, 136, 164), 0.18, 1)
		local button = createButton(row, "ApplyButton", buttonText, UDim2.new(0, 128, 1, 0), UDim2.new(1, 0, 0, 0), accentColor)
		button.AnchorPoint = Vector2.new(1, 0)
		setFixedText(button, 14, Enum.TextXAlignment.Center)
		return input, button
	end
	local adminLevelInput, adminApplyLevelButton = createAdminValueEditor(statEditorSection, "LevelEditor", "Level", 70, "Apply Level", Color3.fromRGB(92, 138, 198))
	local adminKillsInput, adminApplyKillsButton = createAdminValueEditor(statEditorSection, "KillsEditor", "Kills", 108, "Apply Kills", Color3.fromRGB(188, 124, 84))
	local adminRunsInput, adminApplyRunsButton = createAdminValueEditor(statEditorSection, "RunsEditor", "Runs", 146, "Apply Runs", Color3.fromRGB(104, 156, 118))
	local adminTokensInput, adminApplyTokensButton = createAdminValueEditor(statEditorSection, "TokensEditor", "Tokens", 184, "Apply Tokens", Color3.fromRGB(188, 152, 82))
	local adminMaxLevelButton = createButton(statEditorSection, "MaxLevelButton", "Set Max Level", UDim2.new(0, 168, 0, 36), UDim2.new(1, -16, 0, 30), Color3.fromRGB(122, 104, 196))
	adminMaxLevelButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(adminMaxLevelButton, 14, Enum.TextXAlignment.Center)

	local liveOpsEventSection = createAdminSection(adminPages.LiveOps, "EventSection", "Event Mode", "Control seasonal rotation and force a live event state when needed.", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 122), Color3.fromRGB(112, 140, 196))
	local adminEventLabel = label(liveOpsEventSection, "EventLabel", "Event Mode: Auto Rotation", UDim2.new(0, 16, 0, 64), UDim2.new(1, -32, 0, 20), Theme.Fonts.Body, Color3.fromRGB(255, 226, 166))
	setFixedText(adminEventLabel, 13)
	local adminEventAutoButton = createButton(liveOpsEventSection, "EventAutoButton", "Auto", UDim2.new(0, 96, 0, 34), UDim2.new(0, 16, 0, 88), Theme.Colors.Backdrop)
	adminEventAutoButton.AnchorPoint = Vector2.zero
	setFixedText(adminEventAutoButton, 14, Enum.TextXAlignment.Center)
	local adminEventOffButton = createButton(liveOpsEventSection, "EventOffButton", "Stop Event", UDim2.new(0, 112, 0, 34), UDim2.new(0, 120, 0, 88), Color3.fromRGB(126, 78, 78))
	adminEventOffButton.AnchorPoint = Vector2.zero
	setFixedText(adminEventOffButton, 14, Enum.TextXAlignment.Center)
	local adminEventSpringButton = createButton(liveOpsEventSection, "EventSpringButton", "Spring", UDim2.new(0, 110, 0, 34), UDim2.new(0, 240, 0, 88), Color3.fromRGB(86, 146, 102))
	adminEventSpringButton.AnchorPoint = Vector2.zero
	setFixedText(adminEventSpringButton, 14, Enum.TextXAlignment.Center)
	local adminEventHarvestButton = createButton(liveOpsEventSection, "EventHarvestButton", "Harvest", UDim2.new(0, 110, 0, 34), UDim2.new(0, 358, 0, 88), Color3.fromRGB(168, 122, 74))
	adminEventHarvestButton.AnchorPoint = Vector2.zero
	setFixedText(adminEventHarvestButton, 14, Enum.TextXAlignment.Center)
	local adminEventWinterButton = createButton(liveOpsEventSection, "EventWinterButton", "Winter", UDim2.new(0, 110, 0, 34), UDim2.new(0, 476, 0, 88), Color3.fromRGB(82, 132, 188))
	adminEventWinterButton.AnchorPoint = Vector2.zero
	setFixedText(adminEventWinterButton, 14, Enum.TextXAlignment.Center)

	local liveOpsMissionSection = createAdminSection(adminPages.LiveOps, "MissionSection", "Mission Tools", "Live runtime tools for wave control, mission routing, squad placement, and quick recovery.", UDim2.new(0, 0, 0, 138), UDim2.new(1, 0, 0, 178), Color3.fromRGB(188, 132, 78))
	local adminSkipWaveButton = createButton(liveOpsMissionSection, "SkipWaveButton", "Skip Wave", UDim2.new(0, 128, 0, 36), UDim2.new(0, 16, 0, 84), Color3.fromRGB(188, 132, 78))
	adminSkipWaveButton.AnchorPoint = Vector2.zero
	setFixedText(adminSkipWaveButton, 14, Enum.TextXAlignment.Center)
	local adminForceBossButton = createButton(liveOpsMissionSection, "ForceBossButton", "Force Boss", UDim2.new(0, 128, 0, 36), UDim2.new(0, 156, 0, 84), Color3.fromRGB(166, 86, 92))
	adminForceBossButton.AnchorPoint = Vector2.zero
	setFixedText(adminForceBossButton, 14, Enum.TextXAlignment.Center)
	local adminRefillAmmoButton = createButton(liveOpsMissionSection, "RefillAmmoButton", "Refill Ammo", UDim2.new(0, 128, 0, 36), UDim2.new(0, 296, 0, 84), Color3.fromRGB(82, 128, 188))
	adminRefillAmmoButton.AnchorPoint = Vector2.zero
	setFixedText(adminRefillAmmoButton, 14, Enum.TextXAlignment.Center)
	local adminTeleportSquadButton = createButton(liveOpsMissionSection, "TeleportSquadButton", "Teleport Squad", UDim2.new(0, 128, 0, 36), UDim2.new(0, 436, 0, 84), Color3.fromRGB(96, 164, 132))
	adminTeleportSquadButton.AnchorPoint = Vector2.zero
	setFixedText(adminTeleportSquadButton, 14, Enum.TextXAlignment.Center)
	local adminMissionRouteLabel = label(liveOpsMissionSection, "MissionRouteLabel", "Force next deploy route for quick scenario testing.", UDim2.new(0, 16, 0, 126), UDim2.new(1, -32, 0, 16), Theme.Fonts.Body, Color3.fromRGB(226, 214, 194))
	setFixedText(adminMissionRouteLabel, 12)
	local adminForcePowerRelayButton = createButton(liveOpsMissionSection, "ForcePowerRelayButton", "Power Relay", UDim2.new(0, 170, 0, 36), UDim2.new(0, 16, 0, 146), Color3.fromRGB(94, 156, 188))
	adminForcePowerRelayButton.AnchorPoint = Vector2.zero
	setFixedText(adminForcePowerRelayButton, 14, Enum.TextXAlignment.Center)
	local adminForceEvacTunnelButton = createButton(liveOpsMissionSection, "ForceEvacTunnelButton", "Evac Tunnel", UDim2.new(0, 170, 0, 36), UDim2.new(0, 202, 0, 146), Color3.fromRGB(96, 164, 132))
	adminForceEvacTunnelButton.AnchorPoint = Vector2.zero
	setFixedText(adminForceEvacTunnelButton, 14, Enum.TextXAlignment.Center)
	local adminForceBlacksiteButton = createButton(liveOpsMissionSection, "ForceBlacksiteButton", "Blacksite Sweep", UDim2.new(0, 170, 0, 36), UDim2.new(0, 388, 0, 146), Color3.fromRGB(168, 102, 86))
	adminForceBlacksiteButton.AnchorPoint = Vector2.zero
	setFixedText(adminForceBlacksiteButton, 14, Enum.TextXAlignment.Center)

	local liveOpsBalanceSection = createAdminSection(adminPages.LiveOps, "BalanceSection", "Balance Tools", "Spawn tests, loot grants, and support-bot controls for live balancing.", UDim2.new(0, 0, 0, 332), UDim2.new(1, 0, 0, 310), Color3.fromRGB(132, 96, 184))
	local adminSpawnBruteButton = createButton(liveOpsBalanceSection, "SpawnBruteButton", "Spawn Brute", UDim2.new(0, 170, 0, 38), UDim2.new(0, 16, 0, 92), Color3.fromRGB(168, 122, 84))
	adminSpawnBruteButton.AnchorPoint = Vector2.zero
	setFixedText(adminSpawnBruteButton, 14, Enum.TextXAlignment.Center)
	local adminSpawnRunnerButton = createButton(liveOpsBalanceSection, "SpawnRunnerButton", "Spawn Runner", UDim2.new(0, 170, 0, 38), UDim2.new(0, 202, 0, 92), Color3.fromRGB(126, 174, 96))
	adminSpawnRunnerButton.AnchorPoint = Vector2.zero
	setFixedText(adminSpawnRunnerButton, 14, Enum.TextXAlignment.Center)
	local adminSpawnSpitterButton = createButton(liveOpsBalanceSection, "SpawnSpitterButton", "Spawn Spitter", UDim2.new(0, 170, 0, 38), UDim2.new(0, 388, 0, 92), Color3.fromRGB(96, 188, 136))
	adminSpawnSpitterButton.AnchorPoint = Vector2.zero
	setFixedText(adminSpawnSpitterButton, 14, Enum.TextXAlignment.Center)
	local adminSpawnBruiserButton = createButton(liveOpsBalanceSection, "SpawnBruiserButton", "Spawn Bruiser", UDim2.new(0, 170, 0, 38), UDim2.new(0, 16, 0, 136), Color3.fromRGB(194, 142, 92))
	adminSpawnBruiserButton.AnchorPoint = Vector2.zero
	setFixedText(adminSpawnBruiserButton, 14, Enum.TextXAlignment.Center)
	local adminSpawnWardenHulkButton = createButton(liveOpsBalanceSection, "SpawnWardenHulkButton", "Spawn Warden Hulk", UDim2.new(0, 170, 0, 38), UDim2.new(0, 202, 0, 136), Color3.fromRGB(188, 112, 88))
	adminSpawnWardenHulkButton.AnchorPoint = Vector2.zero
	setFixedText(adminSpawnWardenHulkButton, 14, Enum.TextXAlignment.Center)
	local adminSpawnExploderButton = createButton(liveOpsBalanceSection, "SpawnExploderButton", "Spawn Exploder", UDim2.new(0, 170, 0, 38), UDim2.new(0, 388, 0, 136), Color3.fromRGB(214, 152, 88))
	adminSpawnExploderButton.AnchorPoint = Vector2.zero
	setFixedText(adminSpawnExploderButton, 14, Enum.TextXAlignment.Center)
	local adminSpawnArtilleryButton = createButton(liveOpsBalanceSection, "SpawnArtilleryButton", "Spawn Artillery", UDim2.new(0, 170, 0, 38), UDim2.new(0, 202, 0, 180), Color3.fromRGB(214, 172, 104))
	adminSpawnArtilleryButton.AnchorPoint = Vector2.zero
	setFixedText(adminSpawnArtilleryButton, 14, Enum.TextXAlignment.Center)
	local adminGiveDropsButton = createButton(liveOpsBalanceSection, "GiveDropsButton", "Give All Drops", UDim2.new(0, 170, 0, 38), UDim2.new(0, 388, 0, 92), Color3.fromRGB(132, 96, 184))
	adminGiveDropsButton.Position = UDim2.new(0, 16, 0, 180)
	adminGiveDropsButton.AnchorPoint = Vector2.zero
	setFixedText(adminGiveDropsButton, 14, Enum.TextXAlignment.Center)
	local adminSupportBotsLabel = label(liveOpsBalanceSection, "SupportBotsLabel", "Support bots reinforce the active party and can persist automatically across runs.", UDim2.new(0, 16, 0, 268), UDim2.new(1, -32, 0, 20), Theme.Fonts.Body, Color3.fromRGB(212, 236, 255))
	setFixedText(adminSupportBotsLabel, 13)
	local adminSpawnSupportBotsButton = createButton(liveOpsBalanceSection, "SpawnSupportBotsButton", "Deploy Support Bots", UDim2.new(0, 170, 0, 38), UDim2.new(0, 16, 0, 290), Color3.fromRGB(92, 152, 188))
	adminSpawnSupportBotsButton.AnchorPoint = Vector2.zero
	setFixedText(adminSpawnSupportBotsButton, 14, Enum.TextXAlignment.Center)
	local adminToggleSupportBotsButton = createButton(liveOpsBalanceSection, "ToggleSupportBotsButton", "Bots Auto: Off", UDim2.new(0, 170, 0, 38), UDim2.new(0, 202, 0, 290), Color3.fromRGB(88, 118, 168))
	adminToggleSupportBotsButton.AnchorPoint = Vector2.zero
	setFixedText(adminToggleSupportBotsButton, 14, Enum.TextXAlignment.Center)

	local accessSection = createAdminSection(adminPages.Access, "AccessSection", "Access Control", "Restrict role changes and severe moderation actions to the owner path.", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 224), Color3.fromRGB(148, 86, 86))
	local adminRoleModButton = createButton(accessSection, "RoleModButton", "Make Mod", UDim2.new(0, 170, 0, 40), UDim2.new(0, 16, 0, 92), Color3.fromRGB(86, 118, 188))
	adminRoleModButton.AnchorPoint = Vector2.zero
	setFixedText(adminRoleModButton, 15, Enum.TextXAlignment.Center)
	local adminRoleAdminButton = createButton(accessSection, "RoleAdminButton", "Make Admin", UDim2.new(0, 170, 0, 40), UDim2.new(0, 202, 0, 92), Color3.fromRGB(122, 96, 188))
	adminRoleAdminButton.AnchorPoint = Vector2.zero
	setFixedText(adminRoleAdminButton, 15, Enum.TextXAlignment.Center)
	local adminRoleClearButton = createButton(accessSection, "RoleClearButton", "Clear Access", UDim2.new(0, 170, 0, 40), UDim2.new(0, 388, 0, 92), Color3.fromRGB(82, 82, 92))
	adminRoleClearButton.AnchorPoint = Vector2.zero
	setFixedText(adminRoleClearButton, 15, Enum.TextXAlignment.Center)
	local adminBanButton = createButton(accessSection, "BanButton", "Ban", UDim2.new(0, 264, 0, 40), UDim2.new(0, 16, 0, 138), Color3.fromRGB(156, 76, 76))
	adminBanButton.AnchorPoint = Vector2.zero
	setFixedText(adminBanButton, 15, Enum.TextXAlignment.Center)
	local adminTerminateButton = createButton(accessSection, "TerminateButton", "Terminate Target", UDim2.new(0, 264, 0, 40), UDim2.new(0, 294, 0, 138), Color3.fromRGB(158, 86, 86))
	adminTerminateButton.AnchorPoint = Vector2.zero
	setFixedText(adminTerminateButton, 15, Enum.TextXAlignment.Center)
	local adminUnbanButton = createButton(accessSection, "UnbanButton", "Clear Ban", UDim2.new(0, 264, 0, 40), UDim2.new(0, 16, 0, 184), Color3.fromRGB(102, 116, 140))
	adminUnbanButton.AnchorPoint = Vector2.zero
	setFixedText(adminUnbanButton, 15, Enum.TextXAlignment.Center)
	local adminAccessHint = label(accessSection, "AccessHint", "Owner-only actions apply to the selected roster target and immediately refresh their access state if they remain in-server.", UDim2.new(0, 16, 0, 72), UDim2.new(1, -32, 0, 16), Theme.Fonts.Body, Color3.fromRGB(214, 198, 184))
	setFixedText(adminAccessHint, 12)

	local closeAdminButton = createButton(adminPopup, "CloseAdminButton", "Close", UDim2.new(0, 108, 0, 38), UDim2.new(1, -22, 1, -44), Theme.Colors.Backdrop)
	closeAdminButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(closeAdminButton, 15, Enum.TextXAlignment.Center)

	lobbyRefs.Popups.Admin = adminPopup
	lobbyRefs.AdminPopup = adminPopup
	lobbyRefs.AdminSummary = adminSummary
	lobbyRefs.AdminTargetList = adminTargetList
	lobbyRefs.AdminTargetName = adminTargetName
	lobbyRefs.AdminTargetRole = adminTargetRole
	lobbyRefs.AdminTargetMeta = adminTargetMeta
	lobbyRefs.AdminTargetStats = adminTargetStats
	lobbyRefs.AdminRoleValue = adminRoleValue
	lobbyRefs.AdminEventValue = adminEventValue
	lobbyRefs.AdminMissionValue = adminMissionValue
	lobbyRefs.AdminTargetValue = adminTargetValue
	lobbyRefs.AdminTabs = adminTabs
	lobbyRefs.AdminPages = adminPages
	lobbyRefs.AdminHealButton = adminHealButton
	lobbyRefs.AdminHealSquadButton = adminHealSquadButton
	lobbyRefs.AdminTokensButton = adminTokensButton
	lobbyRefs.AdminTokensLargeButton = adminTokensLargeButton
	lobbyRefs.AdminXpButton = adminXpButton
	lobbyRefs.AdminXpLargeButton = adminXpLargeButton
	lobbyRefs.AdminReviveSquadButton = adminReviveSquadButton
	lobbyRefs.AdminReturnButton = adminReturnButton
	lobbyRefs.AdminRefreshButton = adminRefreshButton
	lobbyRefs.AdminRestoreSquadButton = adminRestoreSquadButton
	lobbyRefs.AdminOpenLiveOpsButton = adminOpenLiveOpsButton
	lobbyRefs.AdminGrantTokensTargetButton = adminGrantTokensTargetButton
	lobbyRefs.AdminGrantXpTargetButton = adminGrantXpTargetButton
	lobbyRefs.AdminHealTargetButton = adminHealTargetButton
	lobbyRefs.AdminGrantWeaponsButton = adminGrantWeaponsButton
	lobbyRefs.AdminGrantCosmeticsButton = adminGrantCosmeticsButton
	lobbyRefs.AdminGrantBundleButton = adminGrantBundleButton
	lobbyRefs.AdminRestoreTargetButton = adminRestoreTargetButton
	lobbyRefs.AdminLevelInput = adminLevelInput
	lobbyRefs.AdminApplyLevelButton = adminApplyLevelButton
	lobbyRefs.AdminKillsInput = adminKillsInput
	lobbyRefs.AdminApplyKillsButton = adminApplyKillsButton
	lobbyRefs.AdminRunsInput = adminRunsInput
	lobbyRefs.AdminApplyRunsButton = adminApplyRunsButton
	lobbyRefs.AdminTokensInput = adminTokensInput
	lobbyRefs.AdminApplyTokensButton = adminApplyTokensButton
	lobbyRefs.AdminMaxLevelButton = adminMaxLevelButton
	lobbyRefs.AdminTerminateButton = adminTerminateButton
	lobbyRefs.AdminRoleModButton = adminRoleModButton
	lobbyRefs.AdminRoleAdminButton = adminRoleAdminButton
	lobbyRefs.AdminRoleClearButton = adminRoleClearButton
	lobbyRefs.AdminBanButton = adminBanButton
	lobbyRefs.AdminUnbanButton = adminUnbanButton
	lobbyRefs.AdminEventLabel = adminEventLabel
	lobbyRefs.AdminEventAutoButton = adminEventAutoButton
	lobbyRefs.AdminEventOffButton = adminEventOffButton
	lobbyRefs.AdminEventSpringButton = adminEventSpringButton
	lobbyRefs.AdminEventHarvestButton = adminEventHarvestButton
	lobbyRefs.AdminEventWinterButton = adminEventWinterButton
	lobbyRefs.AdminSkipWaveButton = adminSkipWaveButton
	lobbyRefs.AdminForceBossButton = adminForceBossButton
	lobbyRefs.AdminRefillAmmoButton = adminRefillAmmoButton
	lobbyRefs.AdminTeleportSquadButton = adminTeleportSquadButton
	lobbyRefs.AdminMissionRouteLabel = adminMissionRouteLabel
	lobbyRefs.AdminForcePowerRelayButton = adminForcePowerRelayButton
	lobbyRefs.AdminForceEvacTunnelButton = adminForceEvacTunnelButton
	lobbyRefs.AdminForceBlacksiteButton = adminForceBlacksiteButton
	lobbyRefs.AdminSpawnBruteButton = adminSpawnBruteButton
	lobbyRefs.AdminSpawnRunnerButton = adminSpawnRunnerButton
	lobbyRefs.AdminSpawnSpitterButton = adminSpawnSpitterButton
	lobbyRefs.AdminSpawnBruiserButton = adminSpawnBruiserButton
	lobbyRefs.AdminSpawnWardenHulkButton = adminSpawnWardenHulkButton
	lobbyRefs.AdminSpawnExploderButton = adminSpawnExploderButton
	lobbyRefs.AdminSpawnArtilleryButton = adminSpawnArtilleryButton
	lobbyRefs.AdminGiveDropsButton = adminGiveDropsButton
	lobbyRefs.AdminSupportBotsLabel = adminSupportBotsLabel
	lobbyRefs.AdminSpawnSupportBotsButton = adminSpawnSupportBotsButton
	lobbyRefs.AdminToggleSupportBotsButton = adminToggleSupportBotsButton
	lobbyRefs.CloseAdminButton = closeAdminButton
end

local function createHomePage(home, homeRefs)
	local homePanel = createPopup(home, "HomePanel", UDim2.new(0, 1100, 0, 620), UDim2.new(0.5, -550, 0.5, -310), {
		backgroundColor = Color3.fromRGB(24, 30, 40),
		gradientStart = Color3.fromRGB(34, 46, 62),
		gradientEnd = Color3.fromRGB(12, 16, 24),
		strokeColor = Color3.fromRGB(126, 156, 196),
		headerColor = Color3.fromRGB(72, 104, 146),
		headerColorEnd = Color3.fromRGB(42, 64, 94),
		badgeText = "STAGING",
		badgeColor = Color3.fromRGB(46, 68, 96),
		iconText = "OPS",
	})
	homePanel.AnchorPoint = Vector2.new(0, 0)

	local homeBackdropGlow = new("Frame", {
		Name = "BackdropGlow",
		BackgroundColor3 = Color3.fromRGB(88, 132, 198),
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 76, 0, 118),
		Size = UDim2.new(0, 468, 0, 344),
		Rotation = -8,
		Parent = homePanel,
	})
	addCorner(homeBackdropGlow, UDim.new(1, 0))

	local homeGrid = new("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 32, 0, 86),
		Size = UDim2.new(1, -64, 1, -120),
		Parent = homePanel,
	})

	local leftCommandPane = new("Frame", {
		Name = "LeftCommandPane",
		BackgroundColor3 = Color3.fromRGB(20, 26, 34),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 320, 1, 0),
		Parent = homeGrid,
	})
	addCorner(leftCommandPane, UDim.new(0, 20))
	addStroke(leftCommandPane, Color3.fromRGB(108, 142, 186), 0.16, 1)
	addGradient(leftCommandPane, Color3.fromRGB(28, 38, 52), Color3.fromRGB(16, 20, 28), 90)

	local leftAccent = new("Frame", {
		Name = "AccentBar",
		BackgroundColor3 = Color3.fromRGB(126, 168, 220),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 18, 0, 18),
		Size = UDim2.new(0, 116, 0, 4),
		Parent = leftCommandPane,
	})
	addCorner(leftAccent, UDim.new(0, 6))

	local homeTitle = label(leftCommandPane, "Title", Theme.GameTitle, UDim2.new(0, 24, 0, 34), UDim2.new(1, -48, 0, 42), Theme.Fonts.Title, Theme.Colors.Text)
	setFixedText(homeTitle, 32)
	homeTitle.TextTransparency = 0

	local homeSubtitle = label(leftCommandPane, "Subtitle", "Command grid online. Stage your operator, review bunker districts, and launch the next breach on your terms.", UDim2.new(0, 24, 0, 82), UDim2.new(1, -48, 0, 72), Theme.Fonts.Body, Color3.fromRGB(212, 224, 238))
	setFixedText(homeSubtitle, 14)
	homeSubtitle.TextTransparency = 0

	local readinessCard = new("Frame", {
		Name = "ReadinessCard",
		BackgroundColor3 = Color3.fromRGB(30, 40, 54),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 24, 0, 176),
		Size = UDim2.new(1, -48, 0, 138),
		Parent = leftCommandPane,
	})
	addCorner(readinessCard, UDim.new(0, 18))
	addStroke(readinessCard, Color3.fromRGB(118, 150, 194), 0.18, 1)
	local readinessTitle = label(readinessCard, "Title", "Bunker Ready", UDim2.new(0, 16, 0, 14), UDim2.new(1, -32, 0, 20), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(readinessTitle, 18)
	local readinessBody = label(readinessCard, "Body", "Quartermaster stock, skill routing, activity lanes, and squad launch systems are all staged from the bunker network.", UDim2.new(0, 16, 0, 42), UDim2.new(1, -32, 0, 56), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(readinessBody, 14)
	local readinessChip = new("TextLabel", {
		Name = "StatusChip",
		BackgroundColor3 = Color3.fromRGB(94, 160, 102),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 16, 1, -34),
		Size = UDim2.new(0, 128, 0, 20),
		Text = "LIVE SESSION",
		TextColor3 = Theme.Colors.Text,
		TextScaled = false,
		TextSize = 11,
		Font = Theme.Fonts.Heading,
		Parent = readinessCard,
	})
	addCorner(readinessChip, UDim.new(0, 8))

	local infoRow = new("Frame", {
		Name = "InfoRow",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 24, 0, 334),
		Size = UDim2.new(1, -48, 0, 112),
		Parent = leftCommandPane,
	})
	local infoCards = {
		{ name = "OpsCard", title = "OPS", body = "Launch from command instead of relying on a world pad.", color = Theme.Colors.CommandAmber },
		{ name = "LockerCard", title = "LOCKER", body = "Owned gear, weapons, and skins stay separate from market stock.", color = Theme.Colors.CommandBlue },
	}
	for index, info in ipairs(infoCards) do
		local card = new("Frame", {
			Name = info.name,
			BackgroundColor3 = Color3.fromRGB(24, 32, 42),
			BackgroundTransparency = 0.06,
			BorderSizePixel = 0,
			Position = UDim2.new(0, (index - 1) * 148, 0, 0),
			Size = UDim2.new(0, 136, 1, 0),
			Parent = infoRow,
		})
		addCorner(card, UDim.new(0, 16))
		addStroke(card, info.color, 0.16, 1)
		local tag = label(card, "Tag", info.title, UDim2.new(0, 14, 0, 14), UDim2.new(1, -28, 0, 16), Theme.Fonts.Heading, info.color)
		setFixedText(tag, 11)
		local body = label(card, "Body", info.body, UDim2.new(0, 14, 0, 40), UDim2.new(1, -28, 1, -54), Theme.Fonts.Body, Theme.Colors.Muted)
		setFixedText(body, 13)
	end

	local rightHeroPane = new("Frame", {
		Name = "RightHeroPane",
		BackgroundColor3 = Color3.fromRGB(18, 24, 32),
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 344, 0, 0),
		Size = UDim2.new(1, -344, 1, 0),
		Parent = homeGrid,
	})
	addCorner(rightHeroPane, UDim.new(0, 22))
	addStroke(rightHeroPane, Color3.fromRGB(98, 124, 152), 0.14, 1)
	addGradient(rightHeroPane, Color3.fromRGB(18, 26, 36), Color3.fromRGB(10, 14, 20), 90)

	local heroGlow = new("Frame", {
		Name = "HeroGlow",
		BackgroundColor3 = Color3.fromRGB(92, 142, 214),
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -248, 0, 42),
		Size = UDim2.new(0, 206, 0, 206),
		Rotation = -10,
		Parent = rightHeroPane,
	})
	addCorner(heroGlow, UDim.new(1, 0))
	local heroFog = new("Frame", {
		Name = "HeroFog",
		BackgroundColor3 = Color3.fromRGB(28, 42, 58),
		BackgroundTransparency = 0.34,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -266, 0, 78),
		Size = UDim2.new(0, 228, 0, 182),
		Parent = rightHeroPane,
	})
	addCorner(heroFog, UDim.new(0, 28))
	addStroke(heroFog, Color3.fromRGB(86, 122, 168), 0.12, 1)
	local heroSilhouette = new("Frame", {
		Name = "HeroSilhouette",
		BackgroundColor3 = Color3.fromRGB(14, 18, 26),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -34, 0, 86),
		Size = UDim2.new(0, 134, 0, 184),
		Parent = rightHeroPane,
	})
	addCorner(heroSilhouette, UDim.new(0, 42))
	local heroHead = new("Frame", {
		Name = "Head",
		BackgroundColor3 = Color3.fromRGB(18, 22, 30),
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, -24, 0, 8),
		Size = UDim2.new(0, 48, 0, 48),
		Parent = heroSilhouette,
	})
	addCorner(heroHead, UDim.new(1, 0))
	local heroChest = new("Frame", {
		Name = "Chest",
		BackgroundColor3 = Color3.fromRGB(22, 28, 38),
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, -38, 0, 44),
		Size = UDim2.new(0, 76, 0, 90),
		Parent = heroSilhouette,
	})
	addCorner(heroChest, UDim.new(0, 28))
	local heroLegLeft = new("Frame", {
		Name = "LegLeft",
		BackgroundColor3 = Color3.fromRGB(18, 24, 32),
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, -34, 0, 118),
		Size = UDim2.new(0, 28, 0, 58),
		Rotation = 4,
		Parent = heroSilhouette,
	})
	addCorner(heroLegLeft, UDim.new(0, 18))
	local heroLegRight = new("Frame", {
		Name = "LegRight",
		BackgroundColor3 = Color3.fromRGB(18, 24, 32),
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 6, 0, 118),
		Size = UDim2.new(0, 28, 0, 58),
		Rotation = -4,
		Parent = heroSilhouette,
	})
	addCorner(heroLegRight, UDim.new(0, 18))
	local heroWeapon = new("Frame", {
		Name = "Weapon",
		BackgroundColor3 = Color3.fromRGB(78, 128, 204),
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 4, 0, 78),
		Size = UDim2.new(0, 76, 0, 10),
		Rotation = -22,
		Parent = heroSilhouette,
	})
	addCorner(heroWeapon, UDim.new(0, 8))
	local heroScanLine = new("Frame", {
		Name = "HeroScanLine",
		BackgroundColor3 = Color3.fromRGB(132, 182, 244),
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -274, 0, 132),
		Size = UDim2.new(0, 238, 0, 2),
		Parent = rightHeroPane,
	})
	addCorner(heroScanLine, UDim.new(0, 4))
	local heroRouteCard = new("Frame", {
		Name = "HeroRouteCard",
		BackgroundColor3 = Color3.fromRGB(20, 28, 38),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -34, 1, -136),
		Size = UDim2.new(0, 218, 0, 62),
		Parent = rightHeroPane,
	})
	addCorner(heroRouteCard, UDim.new(0, 18))
	addStroke(heroRouteCard, Color3.fromRGB(96, 132, 178), 0.14, 1)
	local heroRouteLabel = label(heroRouteCard, "RouteLabel", "NEXT ROUTE", UDim2.new(0, 16, 0, 14), UDim2.new(1, -32, 0, 14), Theme.Fonts.Heading, Color3.fromRGB(132, 178, 232))
	setFixedText(heroRouteLabel, 10)
	local heroRouteTitle = label(heroRouteCard, "RouteTitle", "Reactor perimeter breach", UDim2.new(0, 16, 0, 28), UDim2.new(1, -32, 0, 16), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(heroRouteTitle, 16)
	local heroRouteBody = label(heroRouteCard, "RouteBody", "Squad staging is ready. Review contracts, then launch.", UDim2.new(0, 16, 0, 44), UDim2.new(1, -32, 0, 12), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(heroRouteBody, 11)

	local heroBand = new("Frame", {
		Name = "HeroBand",
		BackgroundColor3 = Color3.fromRGB(60, 86, 120),
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 22, 0, 20),
		Size = UDim2.new(0, 212, 0, 4),
		Parent = rightHeroPane,
	})
	addCorner(heroBand, UDim.new(0, 6))

	local heroStatus = label(rightHeroPane, "HeroStatus", "OUTPOST STATUS", UDim2.new(0, 24, 0, 34), UDim2.new(0, 180, 0, 16), Theme.Fonts.Heading, Color3.fromRGB(132, 178, 232))
	setFixedText(heroStatus, 11)
	local heroTitle = label(rightHeroPane, "HeroTitle", "Bunker stable.\nDeploy on command.", UDim2.new(0, 24, 0, 58), UDim2.new(1, -48, 0, 90), Theme.Fonts.Title, Theme.Colors.Text)
	setFixedText(heroTitle, 28)
	heroTitle.TextYAlignment = Enum.TextYAlignment.Top

	local heroBody = label(rightHeroPane, "HeroBody", "The bunker is stable. Review the quartermaster, tune your loadout, check contracts, and push into the next route when the squad is ready.", UDim2.new(0, 24, 0, 154), UDim2.new(0, 450, 0, 52), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(heroBody, 16)

	local signalPane = new("Frame", {
		Name = "SignalPane",
		BackgroundColor3 = Color3.fromRGB(26, 34, 44),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 24, 0, 214),
		Size = UDim2.new(1, -48, 0, 118),
		Parent = rightHeroPane,
	})
	addCorner(signalPane, UDim.new(0, 18))
	addStroke(signalPane, Color3.fromRGB(88, 118, 156), 0.14, 1)
	local signalSweep = new("Frame", {
		Name = "SignalSweep",
		BackgroundColor3 = Color3.fromRGB(152, 208, 255),
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		Position = UDim2.new(0, -72, 0, 10),
		Rotation = 12,
		Size = UDim2.new(0, 68, 1, -20),
		Parent = signalPane,
	})
	addCorner(signalSweep, UDim.new(0, 18))
	local signalBars = {
		{ x = 18, h = 38, color = Color3.fromRGB(88, 138, 220) },
		{ x = 48, h = 72, color = Color3.fromRGB(116, 170, 232) },
		{ x = 78, h = 54, color = Color3.fromRGB(98, 156, 224) },
		{ x = 108, h = 88, color = Theme.Colors.CommandAmber },
	}
	local signalBarRefs = {}
	for _, info in ipairs(signalBars) do
		local bar = new("Frame", {
			Name = "SignalBar",
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = info.color,
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			Position = UDim2.new(0, info.x, 1, -18),
			Size = UDim2.new(0, 16, 0, info.h),
			Parent = signalPane,
		})
		addCorner(bar, UDim.new(0, 8))
		table.insert(signalBarRefs, bar)
	end
	local signalTitle = label(signalPane, "SignalTitle", "SESSION SIGNAL", UDim2.new(0, 150, 0, 18), UDim2.new(1, -166, 0, 18), Theme.Fonts.Heading, Color3.fromRGB(222, 234, 248))
	setFixedText(signalTitle, 15)
	local signalBody = label(signalPane, "SignalBody", "Squad channels, rewards, extraction links, and deployment systems are ready for the next run.", UDim2.new(0, 150, 0, 42), UDim2.new(1, -166, 0, 40), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(signalBody, 14)
	local signalFooter = label(signalPane, "SignalFooter", "ROUTE LIVE  |  REWARD LINKED  |  SQUAD READY", UDim2.new(0, 150, 1, -22), UDim2.new(1, -166, 0, 10), Theme.Fonts.Heading, Color3.fromRGB(255, 214, 152))
	setFixedText(signalFooter, 10)

	local homePlayButton = createButton(rightHeroPane, "PlayButton", Theme.HomePlayButtonText, UDim2.new(0, 290, 0, 56), UDim2.new(0, 24, 1, -114), Theme.Colors.Accent)
	homePlayButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(homePlayButton, 22, Enum.TextXAlignment.Center)

	local homeHint = label(rightHeroPane, "Hint", "Review the bunker, then deploy when the squad and loadout are ready.", UDim2.new(0, 24, 1, -46), UDim2.new(1, -48, 0, 14), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(homeHint, 12)
	homeHint.TextTransparency = 0
	homeRefs.Panel = homePanel
	homeRefs.BackdropGlow = homeBackdropGlow
	homeRefs.LeftCommandPane = leftCommandPane
	homeRefs.RightHeroPane = rightHeroPane
	homeRefs.ReadinessCard = readinessCard
	homeRefs.InfoRow = infoRow
	homeRefs.InfoCards = {
		infoRow:FindFirstChild("OpsCard"),
		infoRow:FindFirstChild("LockerCard"),
	}
	homeRefs.HeroBand = heroBand
	homeRefs.HeroGlow = heroGlow
	homeRefs.HeroScanLine = heroScanLine
	homeRefs.HeroRouteCard = heroRouteCard
	homeRefs.HeroStatus = heroStatus
	homeRefs.HeroTitle = heroTitle
	homeRefs.HeroBody = heroBody
	homeRefs.SignalPane = signalPane
	homeRefs.SignalSweep = signalSweep
	homeRefs.SignalBars = signalBarRefs
	homeRefs.Hint = homeHint
	homeRefs.PlayButton = homePlayButton
end

local function createLoadingPage(loading, loadingRefs)
	local loadingPanel = createPopup(loading, "LoadingPanel", UDim2.new(0, 920, 0, 430), UDim2.new(0.5, -460, 0.5, -215), {
		backgroundColor = Color3.fromRGB(24, 30, 38),
		gradientStart = Color3.fromRGB(40, 50, 64),
		gradientEnd = Color3.fromRGB(16, 20, 28),
		strokeColor = Color3.fromRGB(112, 142, 174),
		headerColor = Color3.fromRGB(62, 86, 116),
		headerColorEnd = Color3.fromRGB(34, 48, 68),
		badgeText = "DEPLOY",
		badgeColor = Color3.fromRGB(56, 74, 96),
		iconText = "AIR",
	})
	local loadingBadgeNode = loadingPanel:FindFirstChild("Badge")
	if loadingBadgeNode and loadingBadgeNode:IsA("GuiObject") then
		loadingBadgeNode.Visible = false
	end
	local loadingEmblemNode = loadingPanel:FindFirstChild("Emblem")
	if loadingEmblemNode and loadingEmblemNode:IsA("GuiObject") then
		loadingEmblemNode.Visible = false
	end
	local loadingStageChip = new("TextLabel", {
		Name = "StageChip",
		BackgroundColor3 = Color3.fromRGB(38, 52, 72),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 34, 0, 72),
		Size = UDim2.new(0, 150, 0, 28),
		Text = "DEPLOYMENT GRID",
		TextColor3 = Color3.fromRGB(220, 232, 246),
		TextScaled = false,
		TextSize = 12,
		Font = Theme.Fonts.Heading,
		Parent = loadingPanel,
	})
	addCorner(loadingStageChip, UDim.new(0, 12))
	addStroke(loadingStageChip, Color3.fromRGB(112, 162, 214), 0.18, 1)
	local loadingAccent = new("Frame", {
		Name = "HeaderAccent",
		BackgroundColor3 = Color3.fromRGB(112, 162, 214),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 34, 0, 112),
		Size = UDim2.new(0, 188, 0, 4),
		Parent = loadingPanel,
	})
	addCorner(loadingAccent, UDim.new(0, 6))
	local loadingTitle = label(loadingPanel, "Title", Theme.GameTitle, UDim2.new(0, 34, 0, 126), UDim2.new(1, -68, 0, 42), Theme.Fonts.Title, Theme.Colors.Text, Enum.TextXAlignment.Left)
	setFixedText(loadingTitle, 34, Enum.TextXAlignment.Left)
	local loadingTag = label(loadingPanel, "Tag", "Streaming mission geometry, syncing operator data, and preparing bunker systems.", UDim2.new(0, 34, 0, 170), UDim2.new(1, -68, 0, 22), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Left)
	setFixedText(loadingTag, 15, Enum.TextXAlignment.Left)
	local loadingHeaderRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(96, 122, 152),
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 34, 0, 206),
		Size = UDim2.new(1, -68, 0, 2),
		Parent = loadingPanel,
	})
	addCorner(loadingHeaderRule, UDim.new(0, 4))
	local leftIntelCard = new("Frame", {
		Name = "LeftIntelCard",
		BackgroundColor3 = Color3.fromRGB(28, 36, 46),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 34, 0, 232),
		Size = UDim2.new(0, 176, 0, 120),
		Parent = loadingPanel,
	})
	addCorner(leftIntelCard, UDim.new(0, 18))
	addStroke(leftIntelCard, Color3.fromRGB(112, 132, 156), 0.14, 1)
	local leftIntelLabel = label(leftIntelCard, "IntelLabel", "WORLD LINK", UDim2.new(0, 14, 0, 14), UDim2.new(1, -28, 0, 16), Theme.Fonts.Heading, Color3.fromRGB(154, 188, 228))
	setFixedText(leftIntelLabel, 11)
	local leftIntelTitle = label(leftIntelCard, "IntelTitle", "Server sync live", UDim2.new(0, 14, 0, 36), UDim2.new(1, -28, 0, 20), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(leftIntelTitle, 18)
	local leftIntelBody = label(leftIntelCard, "IntelBody", "Mission layouts, rewards, and operator profile data are being staged for the next deployment.", UDim2.new(0, 14, 0, 62), UDim2.new(1, -28, 0, 42), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(leftIntelBody, 12)
	local rightIntelCard = new("Frame", {
		Name = "RightIntelCard",
		BackgroundColor3 = Color3.fromRGB(28, 36, 46),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -210, 0, 232),
		Size = UDim2.new(0, 176, 0, 120),
		Parent = loadingPanel,
	})
	addCorner(rightIntelCard, UDim.new(0, 18))
	addStroke(rightIntelCard, Color3.fromRGB(112, 132, 156), 0.14, 1)
	local rightIntelLabel = label(rightIntelCard, "IntelLabel", "SQUAD CHECK", UDim2.new(0, 14, 0, 14), UDim2.new(1, -28, 0, 16), Theme.Fonts.Heading, Color3.fromRGB(154, 188, 228))
	setFixedText(rightIntelLabel, 11)
	local rightIntelTitle = label(rightIntelCard, "IntelTitle", "Launch corridor stable", UDim2.new(0, 14, 0, 36), UDim2.new(1, -28, 0, 20), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(rightIntelTitle, 18)
	local rightIntelBody = label(rightIntelCard, "IntelBody", "Stay ready while the bunker verifies squad presence, route state, and extraction links.", UDim2.new(0, 14, 0, 62), UDim2.new(1, -28, 0, 42), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(rightIntelBody, 12)
	local loadingPromptPlate = new("Frame", {
		Name = "PromptPlate",
		BackgroundColor3 = Color3.fromRGB(38, 50, 62),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 232, 0, 232),
		Size = UDim2.new(1, -464, 0, 58),
		Parent = loadingPanel,
	})
	addCorner(loadingPromptPlate, UDim.new(0, 16))
	addStroke(loadingPromptPlate, Theme.Colors.BunkerAccent, 0.24, 1)
	local loadingPromptLabel = label(loadingPromptPlate, "PromptLabel", "ACTIVE CALL", UDim2.new(0, 16, 0, 10), UDim2.new(1, -32, 0, 12), Theme.Fonts.Heading, Color3.fromRGB(154, 188, 228), Enum.TextXAlignment.Center)
	setFixedText(loadingPromptLabel, 10, Enum.TextXAlignment.Center)
	local loadingPrompt = label(loadingPromptPlate, "Prompt", Theme.LoadingPrompt, UDim2.new(0, 16, 0, 24), UDim2.new(1, -32, 0, 22), Theme.Fonts.Heading, Theme.Colors.AccentSoft, Enum.TextXAlignment.Center)
	setFixedText(loadingPrompt, 18, Enum.TextXAlignment.Center)
	local loadingStatusPlate = new("Frame", {
		Name = "StatusPlate",
		BackgroundColor3 = Color3.fromRGB(24, 30, 38),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 232, 0, 304),
		Size = UDim2.new(1, -464, 0, 48),
		Parent = loadingPanel,
	})
	addCorner(loadingStatusPlate, UDim.new(0, 14))
	addStroke(loadingStatusPlate, Theme.Colors.Stroke, 0.2, 1)
	local loadingStatusLabel = label(loadingStatusPlate, "StatusLabel", "STATUS", UDim2.new(0, 16, 0, 7), UDim2.new(1, -32, 0, 10), Theme.Fonts.Heading, Color3.fromRGB(255, 210, 148), Enum.TextXAlignment.Left)
	setFixedText(loadingStatusLabel, 9, Enum.TextXAlignment.Left)
	local loadingStatus = label(loadingStatusPlate, "Status", Theme.StatusCopy.Loading, UDim2.new(0, 16, 0, 18), UDim2.new(1, -32, 0, 16), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Left)
	setFixedText(loadingStatus, 14, Enum.TextXAlignment.Left)
	local loadingTrack = new("Frame", {
		Name = "ProgressTrack",
		BackgroundColor3 = Color3.fromRGB(18, 22, 28),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 16, 1, -12),
		Size = UDim2.new(1, -32, 0, 4),
		Parent = loadingStatusPlate,
	})
	addCorner(loadingTrack, UDim.new(0, 4))
	local loadingFill = new("Frame", {
		Name = "ProgressFill",
		BackgroundColor3 = Color3.fromRGB(112, 162, 214),
		BorderSizePixel = 0,
		Size = UDim2.new(0.58, 0, 1, 0),
		Parent = loadingTrack,
	})
	addCorner(loadingFill, UDim.new(0, 4))
	loadingRefs.Panel = loadingPanel
	loadingRefs.Prompt = loadingPrompt
	loadingRefs.Status = loadingStatus
	loadingRefs.Tag = loadingTag
end

local function createLobbyChrome(lobby, lobbyRefs, combatOverlay, hitMarker, rewardFloatLayer)
	local hudBar = new("Frame", {
		Name = "HudBar",
		BackgroundColor3 = Color3.fromRGB(24, 28, 34),
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 22, 0, 28),
		Size = UDim2.new(0.54, 0, 0, 92),
		Visible = true,
		Parent = lobby,
	})
	new("UISizeConstraint", {
		MaxSize = Vector2.new(920, 92),
		Parent = hudBar,
	})
	addCorner(hudBar, UDim.new(0, 18))
	addStroke(hudBar, Theme.Colors.Stroke, 0.16, 1)
	addGradient(hudBar, Color3.fromRGB(34, 40, 48), Color3.fromRGB(18, 22, 28), 0)
	local hudStrip = new("Frame", {
		Name = "AccentStrip",
		BackgroundColor3 = Theme.Colors.BunkerAccent,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 16, 0, 10),
		Size = UDim2.new(0, 54, 0, 3),
		Parent = hudBar,
	})
	addCorner(hudStrip, UDim.new(0, 4))
	local hudTitle = label(hudBar, "Title", Theme.GameTitle, UDim2.new(0, 12, 0, 9), UDim2.new(0, 114, 0, 18), Theme.Fonts.Heading)
	hudTitle.TextScaled = false
	hudTitle.TextSize = 15
	local hudModule = new("Frame", {
		Name = "HudModule",
		BackgroundColor3 = Color3.fromRGB(26, 32, 38),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 14, 0, 16),
		Size = UDim2.new(0, 148, 0, 48),
		Parent = hudBar,
	})
	addCorner(hudModule, UDim.new(0, 14))
	addStroke(hudModule, Theme.Colors.Stroke, 0.16, 1)
	hudTitle.Parent = hudModule
	hudTitle.Position = UDim2.new(0, 14, 0, 8)
	hudTitle.Size = UDim2.new(1, -30, 0, 18)
	hudTitle.TextSize = 12
	local hudSub = label(hudModule, "Sub", "COMMAND GRID", UDim2.new(0, 14, 0, 22), UDim2.new(1, -28, 0, 12), Theme.Fonts.Body, Theme.Colors.Muted)
	hudSub.Position = UDim2.new(0, 14, 0, 25)
	hudSub.Size = UDim2.new(1, -52, 0, 12)
	setFixedText(hudSub, 8)
	local hudIcon = new("Frame", {
		Name = "Icon",
		BackgroundColor3 = Theme.Colors.BunkerAccent,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -34, 0, 14),
		Size = UDim2.new(0, 20, 0, 20),
		Parent = hudModule,
	})
	addCorner(hudIcon, UDim.new(0, 10))
	local hudIconText = new("TextLabel", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "CMD",
		TextColor3 = Theme.Colors.Text,
		TextScaled = false,
		TextSize = 8,
		Font = Theme.Fonts.Heading,
		Parent = hudIcon,
	})
	hudIconText.TextXAlignment = Enum.TextXAlignment.Center
	hudIconText.TextYAlignment = Enum.TextYAlignment.Center
	local tokenPill = new("Frame", {
		Name = "TokenPill",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(26, 32, 38),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 182, 0, 28),
		Size = UDim2.new(0, 170, 0, 24),
		Parent = hudBar,
	})
	addCorner(tokenPill, UDim.new(0, 10))
	addStroke(tokenPill, Theme.Colors.Accent, 0.3, 1)
	local tokenValue = label(tokenPill, "Value", "0 Deploy Tokens", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), Theme.Fonts.Heading, Theme.Colors.Text, Enum.TextXAlignment.Center)
	tokenValue.TextScaled = false
	tokenValue.TextSize = 10
	local tokenTag = label(tokenPill, "Tag", "DEPLOY TOKENS", UDim2.new(0, 12, 0, 4), UDim2.new(1, -24, 0, 10), Theme.Fonts.Body, Theme.Colors.AccentSoft, Enum.TextXAlignment.Left)
	setFixedText(tokenTag, 8)
	tokenValue.Position = UDim2.new(0, 10, 0, 9)
	tokenValue.Size = UDim2.new(1, -24, 0, 16)
	tokenValue.TextXAlignment = Enum.TextXAlignment.Left
	local deployStatusPill = new("Frame", {
		Name = "DeployStatusPill",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(26, 32, 38),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 362, 0, 28),
		Size = UDim2.new(0, 236, 0, 24),
		Parent = hudBar,
	})
	addCorner(deployStatusPill, UDim.new(0, 10))
	addStroke(deployStatusPill, Theme.Colors.AccentWarm, 0.3, 1)
	local deployStatus = label(deployStatusPill, "Value", Theme.StatusCopy.Lobby, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), Theme.Fonts.Heading, Theme.Colors.Text, Enum.TextXAlignment.Center)
	deployStatus.TextScaled = false
	deployStatus.TextSize = 10
	local deployTag = label(deployStatusPill, "Tag", "STATUS", UDim2.new(0, 12, 0, 4), UDim2.new(1, -24, 0, 10), Theme.Fonts.Body, Color3.fromRGB(255, 222, 166), Enum.TextXAlignment.Left)
	setFixedText(deployTag, 8)
	deployStatus.Position = UDim2.new(0, 10, 0, 9)
	deployStatus.Size = UDim2.new(1, -24, 0, 16)
	deployStatus.TextXAlignment = Enum.TextXAlignment.Left
	local persistencePill = new("Frame", {
		Name = "PersistencePill",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(26, 44, 34),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 182, 0, 62),
		Size = UDim2.new(0, 126, 0, 18),
		Parent = hudBar,
	})
	addCorner(persistencePill, UDim.new(0, 10))
	addStroke(persistencePill, Theme.Colors.Accent, 0.3, 1)
	local persistenceValue = label(persistencePill, "Value", "Saving", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), Theme.Fonts.Heading, Theme.Colors.Text, Enum.TextXAlignment.Center)
	persistenceValue.TextScaled = false
	persistenceValue.TextSize = 9
	local persistenceTag = label(persistencePill, "Tag", "DATA", UDim2.new(0, 12, 0, 4), UDim2.new(1, -24, 0, 10), Theme.Fonts.Body, Theme.Colors.AccentSoft, Enum.TextXAlignment.Left)
	setFixedText(persistenceTag, 8)
	persistenceValue.Position = UDim2.new(0, 10, 0, 7)
	persistenceValue.Size = UDim2.new(1, -24, 0, 16)
	persistenceValue.TextXAlignment = Enum.TextXAlignment.Left
	local subscriptionPill = new("Frame", {
		Name = "SubscriptionPill",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(32, 36, 28),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 298, 0, 58),
		Size = UDim2.new(0, 126, 0, 20),
		Parent = hudBar,
	})
	subscriptionPill.Visible = false
	addCorner(subscriptionPill, UDim.new(0, 10))
	addStroke(subscriptionPill, Theme.Colors.AccentWarm, 0.3, 1)
	local subscriptionValue = label(subscriptionPill, "Value", "Free", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), Theme.Fonts.Heading, Theme.Colors.Text, Enum.TextXAlignment.Center)
	subscriptionValue.TextScaled = false
	subscriptionValue.TextSize = 9
	local subscriptionTag = label(subscriptionPill, "Tag", "ACCESS", UDim2.new(0, 12, 0, 4), UDim2.new(1, -24, 0, 10), Theme.Fonts.Body, Color3.fromRGB(255, 222, 166), Enum.TextXAlignment.Left)
	setFixedText(subscriptionTag, 8)
	subscriptionValue.Position = UDim2.new(0, 10, 0, 7)
	subscriptionValue.Size = UDim2.new(1, -24, 0, 16)
	subscriptionValue.TextXAlignment = Enum.TextXAlignment.Left
	local identityPill = new("Frame", {
		Name = "IdentityPill",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(42, 36, 26),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 436, 0, 58),
		Size = UDim2.new(0, 170, 0, 20),
		Parent = hudBar,
	})
	identityPill.Visible = false
	addCorner(identityPill, UDim.new(0, 10))
	addStroke(identityPill, Theme.Colors.AccentWarm, 0.3, 1)
	local identityValue = label(identityPill, "Value", "Survivor", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), Theme.Fonts.Heading, Theme.Colors.Text, Enum.TextXAlignment.Center)
	identityValue.TextScaled = false
	identityValue.TextSize = 9
	local identityTag = label(identityPill, "Tag", "TITLE", UDim2.new(0, 12, 0, 4), UDim2.new(1, -24, 0, 10), Theme.Fonts.Body, Color3.fromRGB(255, 222, 166), Enum.TextXAlignment.Left)
	setFixedText(identityTag, 8)
	identityValue.Position = UDim2.new(0, 10, 0, 7)
	identityValue.Size = UDim2.new(1, -24, 0, 16)
	identityValue.TextXAlignment = Enum.TextXAlignment.Left
	local deployButton = createButton(hudBar, "DeployButton", "Deploy", UDim2.new(0, 126, 0, 38), UDim2.new(1, -14, 0.5, 0), Theme.Colors.AccentWarm)
	deployButton.AnchorPoint = Vector2.new(1, 0.5)
	setFixedText(deployButton, 14, Enum.TextXAlignment.Center)
	local missionPanel = new("Frame", {
		Name = "MissionPanel",
		BackgroundColor3 = Color3.fromRGB(20, 24, 30),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.62, 0, 0, 92),
		Size = UDim2.new(0, 544, 0, 296),
		Visible = false,
		Parent = lobby,
	})
	addCorner(missionPanel, UDim.new(0, 18))
	addStroke(missionPanel, Color3.fromRGB(196, 132, 92), 0.08, 1)
	addGradient(missionPanel, Color3.fromRGB(48, 38, 36), Color3.fromRGB(16, 18, 24), 0)
	local missionHeaderBand = new("Frame", {
		Name = "HeaderBand",
		BackgroundColor3 = Color3.fromRGB(112, 82, 66),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 54),
		Parent = missionPanel,
	})
	addCorner(missionHeaderBand, UDim.new(0, 18))
	addGradient(missionHeaderBand, Color3.fromRGB(138, 98, 76), Color3.fromRGB(72, 54, 48), 0)
	new("Frame", {
		Name = "HeaderMask",
		BackgroundColor3 = Color3.fromRGB(20, 24, 30),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = missionHeaderBand,
	})
	local missionRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(255, 188, 154),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 20, 0, 12),
		Size = UDim2.new(0, 88, 0, 4),
		Parent = missionPanel,
	})
	addCorner(missionRule, UDim.new(0, 4))
	local missionTag = label(missionPanel, "Tag", "DEPLOY ROUTE", UDim2.new(0, 20, 0, 18), UDim2.new(0, 104, 0, 14), Theme.Fonts.Heading, Color3.fromRGB(255, 214, 176))
	setFixedText(missionTag, 9)
	local missionTitle = label(missionPanel, "Title", "Deploy Route", UDim2.new(0, 20, 0, 28), UDim2.new(1, -40, 0, 20), Theme.Fonts.Heading)
	setFixedText(missionTitle, 18)
	local missionReadyLabel = label(missionPanel, "ReadyLabel", "SQUAD READY", UDim2.new(1, -122, 0, 20), UDim2.new(0, 98, 0, 16), Theme.Fonts.Heading, Color3.fromRGB(255, 224, 196), Enum.TextXAlignment.Right)
	setFixedText(missionReadyLabel, 9)
	local missionInfoCard = new("Frame", {
		Name = "MissionInfoCard",
		BackgroundColor3 = Color3.fromRGB(24, 28, 34),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 16, 0, 68),
		Size = UDim2.new(0, 210, 0, 154),
		Parent = missionPanel,
	})
	addCorner(missionInfoCard, UDim.new(0, 12))
	addStroke(missionInfoCard, Color3.fromRGB(92, 102, 118), 0.35, 1)
	local missionInfoRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(164, 198, 255),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0, 9),
		Size = UDim2.new(0, 34, 0, 2),
		Parent = missionInfoCard,
	})
	addCorner(missionInfoRule, UDim.new(0, 4))
	local missionInfoTag = label(missionInfoCard, "Tag", "ROUTE BRIEF", UDim2.new(0, 12, 0, 14), UDim2.new(1, -24, 0, 12), Theme.Fonts.Heading, Color3.fromRGB(196, 215, 255))
	setFixedText(missionInfoTag, 8)
	local missionStatus = label(missionPanel, "MissionStatus", "Objective: defend the bunker core", UDim2.new(0.06, 0, 0.34, 0), UDim2.new(0.88, 0, 0.18, 0), Theme.Fonts.Body, Theme.Colors.Text)
	local missionMeta = label(missionPanel, "MissionMeta", "Wave 0 | Core 100%", UDim2.new(0.06, 0, 0.56, 0), UDim2.new(0.88, 0, 0.13, 0), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	local missionLoadout = label(missionPanel, "MissionLoadout", "Loadout: Training Blade | Ammo: --", UDim2.new(0.06, 0, 0.75, 0), UDim2.new(0.88, 0, 0.12, 0), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	missionStatus.Position = UDim2.new(0, 18, 0, 40)
	missionStatus.Size = UDim2.new(0, 174, 0, 48)
	missionStatus.TextScaled = false
	missionStatus.TextSize = 14
	missionMeta.Position = UDim2.new(0, 18, 0, 102)
	missionMeta.Size = UDim2.new(0, 174, 0, 16)
	missionMeta.TextScaled = false
	missionMeta.TextSize = 12
	missionLoadout.Position = UDim2.new(0, 18, 0, 122)
	missionLoadout.Size = UDim2.new(0, 174, 0, 22)
	missionLoadout.TextScaled = false
	missionLoadout.TextSize = 11
	local missionVoteDeck = new("Frame", {
		Name = "MissionVoteDeck",
		BackgroundColor3 = Color3.fromRGB(20, 24, 30),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 242, 0, 68),
		Size = UDim2.new(1, -258, 0, 154),
		Parent = missionPanel,
	})
	addCorner(missionVoteDeck, UDim.new(0, 12))
	addStroke(missionVoteDeck, Color3.fromRGB(112, 82, 66), 0.3, 1)
	local missionVoteRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(255, 192, 152),
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0, 9),
		Size = UDim2.new(0, 42, 0, 2),
		Parent = missionVoteDeck,
	})
	addCorner(missionVoteRule, UDim.new(0, 4))
	local missionVoteTitle = label(missionVoteDeck, "Title", "MAP VOTE", UDim2.new(0, 12, 0, 14), UDim2.new(1, -24, 0, 12), Theme.Fonts.Heading, Color3.fromRGB(255, 210, 186))
	setFixedText(missionVoteTitle, 8)
	local missionVoteLabel = label(missionVoteDeck, "MissionVoteLabel", "Pick a route, review the threat package, then launch when the squad is ready.", UDim2.new(0, 12, 0, 28), UDim2.new(1, -24, 0, 28), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(missionVoteLabel, 11)
	local missionVoteButtons = {}
	for index = 1, 3 do
		local voteButton = createButton(
			missionVoteDeck,
			"MissionVoteButton" .. tostring(index),
			"Option",
			UDim2.new(1, -24, 0, 28),
			UDim2.new(0, 12, 0, 70 + ((index - 1) * 32)),
			Color3.fromRGB(72, 52, 46)
		)
		voteButton.AnchorPoint = Vector2.new(0, 0)
		setFixedText(voteButton, 12, Enum.TextXAlignment.Left)
		missionVoteButtons[index] = voteButton
	end
	local missionCloseButton = createButton(missionPanel, "MissionCloseButton", "Stand Down", UDim2.new(0, 118, 0, 34), UDim2.new(1, -182, 1, -18), Theme.Colors.Backdrop)
	missionCloseButton.AnchorPoint = Vector2.new(1, 1)
	setFixedText(missionCloseButton, 13, Enum.TextXAlignment.Center)
	local missionLaunchButton = createButton(missionPanel, "MissionLaunchButton", "Launch Contract", UDim2.new(0, 156, 0, 34), UDim2.new(1, -18, 1, -18), Theme.Colors.AccentWarm)
	missionLaunchButton.AnchorPoint = Vector2.new(1, 1)
	setFixedText(missionLaunchButton, 13, Enum.TextXAlignment.Center)
	local leaderboardBoard = new("Frame", {
		Name = "LeaderboardBoard",
		BackgroundColor3 = Color3.fromRGB(18, 22, 28),
		BackgroundTransparency = 0.34,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 22, 1, -22),
		Size = UDim2.new(0, 188, 0, 30),
		Visible = false,
		Parent = lobby,
	})
	addCorner(leaderboardBoard, UDim.new(0, 11))
	addStroke(leaderboardBoard, Theme.Colors.Stroke, 0.22, 1)
	addGradient(leaderboardBoard, Color3.fromRGB(24, 30, 38), Color3.fromRGB(12, 16, 22), 0)
	local leaderboardRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(196, 166, 108),
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 0, 18),
		Size = UDim2.new(0, 28, 0, 2),
		Parent = leaderboardBoard,
	})
	addCorner(leaderboardRule, UDim.new(0, 4))
	local leaderboardTitle = label(leaderboardBoard, "Title", "Archive Walk", UDim2.new(0, 10, 0, 7), UDim2.new(0, 104, 0, 14), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(leaderboardTitle, 10)
	local leaderboardSummary = label(leaderboardBoard, "Summary", "Top 100 ->", UDim2.new(1, -70, 0, 8), UDim2.new(0, 60, 0, 12), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Right)
	setFixedText(leaderboardSummary, 8)
	local adminButton = createButton(lobby, "AdminButton", "Owner", UDim2.new(0, 90, 0, 30), UDim2.new(1, -24, 0, 92), Color3.fromRGB(138, 108, 58))
	adminButton.AnchorPoint = Vector2.new(1, 0)
	adminButton.Visible = false
	adminButton.ZIndex = 20
	setFixedText(adminButton, 15, Enum.TextXAlignment.Center)

	lobbyRefs.HudBar = hudBar
	lobbyRefs.MissionPanel = missionPanel
	lobbyRefs.MissionInfoCard = missionInfoCard
	lobbyRefs.MissionStatus = missionStatus
	lobbyRefs.MissionMeta = missionMeta
	lobbyRefs.MissionLoadout = missionLoadout
	lobbyRefs.MissionVoteDeck = missionVoteDeck
	lobbyRefs.MissionVoteLabel = missionVoteLabel
	lobbyRefs.MissionVoteButtons = missionVoteButtons
	lobbyRefs.MissionCloseButton = missionCloseButton
	lobbyRefs.MissionLaunchButton = missionLaunchButton
	lobbyRefs.LeaderboardBoard = leaderboardBoard
	lobbyRefs.LeaderboardSummary = leaderboardSummary
	lobbyRefs.AdminButton = adminButton
	lobbyRefs.CombatOverlay = combatOverlay
	lobbyRefs.HitMarker = hitMarker
	lobbyRefs.RewardFloatLayer = rewardFloatLayer
	lobbyRefs.TokenValue = tokenValue
	lobbyRefs.TokenPill = tokenPill
	lobbyRefs.DeployStatus = deployStatus
	lobbyRefs.DeployStatusPill = deployStatusPill
	lobbyRefs.PersistenceValue = persistenceValue
	lobbyRefs.PersistencePill = persistencePill
	lobbyRefs.SubscriptionValue = subscriptionValue
	lobbyRefs.IdentityValue = identityValue
	lobbyRefs.DeployButton = deployButton

	local missionToastStack = new("Frame", {
		Name = "MissionToastStack",
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -276, 0.14, 0),
		Size = UDim2.new(0, 244, 0, 196),
		Parent = lobby,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Parent = missionToastStack,
	})
	lobbyRefs.MissionToastStack = missionToastStack

	local premiumUnlockBanner = new("Frame", {
		Name = "PremiumUnlockBanner",
		BackgroundColor3 = Color3.fromRGB(18, 22, 28),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.11, 0),
		Size = UDim2.new(0, 468, 0, 88),
		Visible = false,
		Parent = lobby,
	})
	addCorner(premiumUnlockBanner, UDim.new(0, 18))
	addStroke(premiumUnlockBanner, Color3.fromRGB(132, 182, 244), 0.12, 1)
	addGradient(premiumUnlockBanner, Color3.fromRGB(28, 36, 46), Color3.fromRGB(12, 16, 22), 90)
	local premiumBannerRail = new("Frame", {
		Name = "AccentRail",
		BackgroundColor3 = Color3.fromRGB(132, 182, 244),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 7, 1, 0),
		Parent = premiumUnlockBanner,
	})
	addCorner(premiumBannerRail, UDim.new(0, 7))
	local premiumBannerTitle = label(premiumUnlockBanner, "Title", "VIP ACCESS UNLOCKED", UDim2.new(0, 24, 0, 14), UDim2.new(1, -48, 0, 22), Theme.Fonts.Title, Theme.Colors.Text)
	setFixedText(premiumBannerTitle, 22)
	local premiumBannerBody = label(premiumUnlockBanner, "Body", "VIP Operations access is now active.", UDim2.new(0, 24, 0, 42), UDim2.new(1, -48, 0, 20), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(premiumBannerBody, 12)
	local premiumBannerChip = new("TextLabel", {
		Name = "Chip",
		BackgroundColor3 = Color3.fromRGB(132, 182, 244),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.new(0, 124, 0, 28),
		Text = "ACCESS GRANTED",
		TextColor3 = Color3.fromRGB(16, 20, 24),
		TextScaled = false,
		TextSize = 11,
		Font = Theme.Fonts.Heading,
		Parent = premiumUnlockBanner,
	})
	addCorner(premiumBannerChip, UDim.new(0, 12))
	lobbyRefs.PremiumUnlockBanner = premiumUnlockBanner
	lobbyRefs.PremiumUnlockBannerRail = premiumBannerRail
	lobbyRefs.PremiumUnlockBannerTitle = premiumBannerTitle
	lobbyRefs.PremiumUnlockBannerBody = premiumBannerBody
	lobbyRefs.PremiumUnlockBannerChip = premiumBannerChip

	local combatHud = new("Frame", {
		Name = "CombatHud",
		BackgroundColor3 = Color3.fromRGB(14, 18, 24),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -18),
		Size = UDim2.new(0, 236, 0, 114),
		Visible = false,
		Parent = lobby,
	})
	addCorner(combatHud, UDim.new(0, 14))
	addStroke(combatHud, Color3.fromRGB(96, 122, 156), 0.18, 1)
	addGradient(combatHud, Color3.fromRGB(24, 30, 38), Color3.fromRGB(12, 16, 22), 0)
	local combatHudRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(164, 194, 236),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0, 12),
		Size = UDim2.new(0, 42, 0, 2),
		Parent = combatHud,
	})
	addCorner(combatHudRule, UDim.new(0, 4))
	local combatWeapon = label(combatHud, "Weapon", "TRAINING BLADE", UDim2.new(0, 12, 0, 18), UDim2.new(1, -24, 0, 16), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(combatWeapon, 12)
	local combatAmmo = label(combatHud, "Ammo", "AMMO --", UDim2.new(0, 12, 0, 36), UDim2.new(0.56, -6, 0, 22), Theme.Fonts.Title, Color3.fromRGB(236, 196, 112))
	setFixedText(combatAmmo, 18)
	local combatStatus = label(combatHud, "Status", "WEAPON READY", UDim2.new(1, -114, 0, 40), UDim2.new(0, 102, 0, 16), Theme.Fonts.Body, Theme.Colors.AccentSoft, Enum.TextXAlignment.Right)
	setFixedText(combatStatus, 10)
	local combatProgressLabel = label(combatHud, "ProgressLabel", "WAVE PRESSURE", UDim2.new(0, 12, 0, 62), UDim2.new(1, -24, 0, 14), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(combatProgressLabel, 10)
	local combatProgressTrack = new("Frame", {
		Name = "ProgressTrack",
		BackgroundColor3 = Color3.fromRGB(22, 28, 36),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0, 80),
		Size = UDim2.new(1, -24, 0, 10),
		Parent = combatHud,
	})
	addCorner(combatProgressTrack, UDim.new(0, 999))
	local combatProgressFill = new("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.fromRGB(132, 182, 244),
		BorderSizePixel = 0,
		Size = UDim2.new(0.32, 0, 1, 0),
		Parent = combatProgressTrack,
	})
	addCorner(combatProgressFill, UDim.new(0, 999))
	addGradient(combatProgressFill, Color3.fromRGB(132, 182, 244), Color3.fromRGB(84, 148, 236), 0)
	local combatProgressText = label(combatHud, "ProgressText", "0/0 hostiles cleared", UDim2.new(0, 12, 0, 94), UDim2.new(1, -24, 0, 12), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	setFixedText(combatProgressText, 10)
	local combatLeaveButton = createButton(combatHud, "CombatLeaveButton", "Leave Mission", UDim2.new(0, 118, 0, 28), UDim2.new(1, -12, 1, -10), Theme.Colors.Backdrop)
	combatLeaveButton.AnchorPoint = Vector2.new(1, 1)
	combatLeaveButton.Visible = false
	combatLeaveButton.TextSize = 12
	lobbyRefs.CombatHud = combatHud
	lobbyRefs.CombatWeapon = combatWeapon
	lobbyRefs.CombatAmmo = combatAmmo
	lobbyRefs.CombatStatus = combatStatus
	lobbyRefs.CombatProgressLabel = combatProgressLabel
	lobbyRefs.CombatProgressTrack = combatProgressTrack
	lobbyRefs.CombatProgressFill = combatProgressFill
	lobbyRefs.CombatProgressText = combatProgressText
	lobbyRefs.CombatLeaveButton = combatLeaveButton

	local function createQuickAccessGlyph(parent, iconKind)
		local icon = new("Frame", {
			Name = "Glyph",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(1, -8, 1, -8),
			Parent = parent,
		})
		local function makeBar(position, size, rotation)
			local bar = new("Frame", {
				BackgroundColor3 = Theme.Colors.Text,
				BorderSizePixel = 0,
				Position = position,
				Size = size,
				Rotation = rotation or 0,
				Parent = icon,
			})
			addCorner(bar, UDim.new(0, 4))
			return bar
		end
		local function makeDot(position, size)
			local dot = new("Frame", {
				BackgroundColor3 = Theme.Colors.Text,
				BorderSizePixel = 0,
				Position = position,
				Size = size,
				Parent = icon,
			})
			addCorner(dot, UDim.new(1, 0))
			return dot
		end
		if iconKind == "shop" then
			makeBar(UDim2.new(0.18, 0, 0.22, 0), UDim2.new(0.64, 0, 0, 3))
			makeBar(UDim2.new(0.22, 0, 0.46, 0), UDim2.new(0.56, 0, 0, 3))
			makeBar(UDim2.new(0.28, 0, 0.7, 0), UDim2.new(0.44, 0, 0, 3))
		elseif iconKind == "inventory" then
			local outline = new("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.new(0.18, 0, 0.2, 0),
				Size = UDim2.new(0.64, 0, 0.6, 0),
				Parent = icon,
			})
			addStroke(outline, Theme.Colors.Text, 0.18, 1)
			addCorner(outline, UDim.new(0, 5))
			makeBar(UDim2.new(0.28, 0, 0.26, 0), UDim2.new(0.44, 0, 0, 3))
			makeBar(UDim2.new(0.28, 0, 0.46, 0), UDim2.new(0.44, 0, 0, 3))
			makeBar(UDim2.new(0.28, 0, 0.66, 0), UDim2.new(0.32, 0, 0, 3))
		elseif iconKind == "skill" then
			makeDot(UDim2.new(0.2, 0, 0.2, 0), UDim2.new(0, 8, 0, 8))
			makeDot(UDim2.new(0.54, 0, 0.2, 0), UDim2.new(0, 8, 0, 8))
			makeDot(UDim2.new(0.37, 0, 0.56, 0), UDim2.new(0, 8, 0, 8))
			makeBar(UDim2.new(0.28, 0, 0.32, 0), UDim2.new(0.22, 0, 0, 3), 22)
			makeBar(UDim2.new(0.38, 0, 0.32, 0), UDim2.new(0.22, 0, 0, 3), -22)
			makeBar(UDim2.new(0.31, 0, 0.52, 0), UDim2.new(0.16, 0, 0, 3), 90)
		elseif iconKind == "squad" then
			makeDot(UDim2.new(0.18, 0, 0.18, 0), UDim2.new(0, 8, 0, 8))
			makeDot(UDim2.new(0.52, 0, 0.18, 0), UDim2.new(0, 8, 0, 8))
			makeBar(UDim2.new(0.14, 0, 0.52, 0), UDim2.new(0.28, 0, 0, 3))
			makeBar(UDim2.new(0.48, 0, 0.52, 0), UDim2.new(0.28, 0, 0, 3))
			makeBar(UDim2.new(0.3, 0, 0.7, 0), UDim2.new(0.28, 0, 0, 3))
		elseif iconKind == "invite" then
			makeDot(UDim2.new(0.16, 0, 0.34, 0), UDim2.new(0, 8, 0, 8))
			makeBar(UDim2.new(0.34, 0, 0.46, 0), UDim2.new(0.26, 0, 0, 3))
			makeBar(UDim2.new(0.54, 0, 0.34, 0), UDim2.new(0.18, 0, 0, 3), 38)
			makeBar(UDim2.new(0.54, 0, 0.56, 0), UDim2.new(0.18, 0, 0, 3), -38)
		elseif iconKind == "settings" then
			makeBar(UDim2.new(0.18, 0, 0.24, 0), UDim2.new(0.5, 0, 0, 3))
			makeBar(UDim2.new(0.32, 0, 0.48, 0), UDim2.new(0.42, 0, 0, 3))
			makeBar(UDim2.new(0.18, 0, 0.72, 0), UDim2.new(0.48, 0, 0, 3))
			makeDot(UDim2.new(0.56, 0, 0.14, 0), UDim2.new(0, 8, 0, 8))
			makeDot(UDim2.new(0.24, 0, 0.38, 0), UDim2.new(0, 8, 0, 8))
			makeDot(UDim2.new(0.48, 0, 0.62, 0), UDim2.new(0, 8, 0, 8))
		end
	end

	local function createQuickAccessButton(parent, name, titleText, subtitleText, iconKind, accentColor, layoutOrder)
		local button = createButton(parent, name, "", UDim2.new(1, 0, 0, 42), UDim2.new(), accentColor)
		button.AnchorPoint = Vector2.new(0, 0)
		button.LayoutOrder = layoutOrder
		button.Text = ""
		button.BackgroundTransparency = 0.02
		addGradient(button, accentColor:Lerp(Color3.fromRGB(255, 255, 255), 0.08), accentColor:Lerp(Color3.fromRGB(0, 0, 0), 0.34), 0)
		local accentRail = new("Frame", {
			Name = "AccentRail",
			BackgroundColor3 = accentColor:Lerp(Color3.fromRGB(255, 255, 255), 0.18),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 3, 1, 0),
			Parent = button,
		})
		addCorner(accentRail, UDim.new(0, 4))
		local topRule = new("Frame", {
			Name = "TopRule",
			BackgroundColor3 = Theme.Colors.Text,
			BackgroundTransparency = 0.78,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 10, 0, 4),
			Size = UDim2.new(0, 26, 0, 1),
			Parent = button,
		})
		addCorner(topRule, UDim.new(0, 2))
		topRule.Visible = false
		local badge = new("Frame", {
			Name = "Badge",
			BackgroundColor3 = accentColor:Lerp(Color3.fromRGB(255, 255, 255), 0.08),
			BackgroundTransparency = 0.02,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.new(0, 18, 0, 18),
			AnchorPoint = Vector2.new(0, 0.5),
			Parent = button,
		})
		addCorner(badge, UDim.new(0, 9))
		addStroke(badge, Theme.Colors.Text, 0.72, 1)
		createQuickAccessGlyph(badge, iconKind)
		local title = new("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 36, 0, 8),
			Size = UDim2.new(1, -54, 0, 12),
			Text = titleText,
			TextColor3 = Theme.Colors.Text,
			TextScaled = false,
			TextSize = 12,
			Font = Theme.Fonts.Heading,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = button,
		})
		local subtitle = new("TextLabel", {
			Name = "Subtitle",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 36, 0, 21),
			Size = UDim2.new(1, -54, 0, 12),
			Text = subtitleText,
			TextColor3 = Theme.Colors.Text:Lerp(Theme.Colors.Muted, 0.35),
			TextScaled = false,
			TextSize = 10,
			Font = Theme.Fonts.Body,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = button,
		})
		subtitle.Visible = subtitleText ~= ""
		if not subtitle.Visible then
			title.Position = UDim2.new(0, 36, 0.5, -6)
			title.Size = UDim2.new(1, -54, 0, 12)
		end
		subtitle.TextTransparency = 0.08
		subtitle.Visible = true
		local arrow = new("TextLabel", {
			Name = "Arrow",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.new(0, 12, 0, 12),
			Text = ">",
			TextColor3 = accentColor:Lerp(Theme.Colors.Text, 0.32),
			TextScaled = false,
			TextSize = 13,
			Font = Theme.Fonts.Heading,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = button,
		})
		arrow.TextTransparency = 0.08
		arrow.Visible = true
		return button
	end

	local quickAccessBar = new("Frame", {
		Name = "QuickAccessBar",
		BackgroundColor3 = Color3.fromRGB(18, 22, 28),
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -22, 0, 132),
		Size = UDim2.new(0, 178, 0, 454),
		Parent = lobby,
	})
	quickAccessBar.AnchorPoint = Vector2.new(1, 0)
	addCorner(quickAccessBar, UDim.new(0, 18))
	addStroke(quickAccessBar, Theme.Colors.BunkerAccent, 0.08, 1)
	addGradient(quickAccessBar, Color3.fromRGB(28, 34, 42), Color3.fromRGB(12, 16, 22), 90)
	local quickAccessNoise = new("Frame", {
		Name = "NoiseLine",
		BackgroundColor3 = Theme.Colors.Text,
		BackgroundTransparency = 0.93,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 14, 0, 10),
		Size = UDim2.new(1, -28, 0, 1),
		Parent = quickAccessBar,
	})
	addCorner(quickAccessNoise, UDim.new(0, 2))
	local quickAccessRule = new("Frame", {
		Name = "Rule",
		BackgroundColor3 = Theme.Colors.AccentWarm,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0, 10),
		Size = UDim2.new(0, 34, 0, 3),
		Parent = quickAccessBar,
	})
	addCorner(quickAccessRule, UDim.new(0, 4))
	local quickAccessTitle = label(quickAccessBar, "Title", "Command Rail", UDim2.new(0, 14, 0, 20), UDim2.new(1, -28, 0, 16), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(quickAccessTitle, 13)
	local quickAccessTag = label(quickAccessBar, "Tag", "LIVE", UDim2.new(1, -46, 0, 20), UDim2.new(0, 36, 0, 12), Theme.Fonts.Heading, Theme.Colors.AccentSoft)
	setFixedText(quickAccessTag, 8)
	quickAccessTag.Visible = true
	local quickAccessBody = label(quickAccessBar, "Body", "Bunker systems and squad tools.", UDim2.new(0, 14, 0, 40), UDim2.new(1, -28, 0, 14), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(quickAccessBody, 9)
	quickAccessBody.Visible = false
	local quickAccessButtons = new("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 54),
		Size = UDim2.new(1, -20, 1, -132),
		Parent = quickAccessBar,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = quickAccessButtons,
	})
	local shopQuickButton = createQuickAccessButton(quickAccessButtons, "ShopQuickButton", "Shop", "", "shop", Theme.Colors.AccentWarm, 1)
	local inventoryQuickButton = createQuickAccessButton(quickAccessButtons, "InventoryQuickButton", "Inventory", "", "inventory", Theme.Colors.CommandBlue, 2)
	local skillTreeQuickButton = createQuickAccessButton(quickAccessButtons, "SkillTreeQuickButton", "Skill Tree", "", "skill", Color3.fromRGB(118, 132, 166), 3)
	local activitiesQuickButton = createQuickAccessButton(quickAccessButtons, "ActivitiesQuickButton", "Activities", "", "activity", Theme.Colors.CommandOlive, 4)
	local squadQuickButton = createQuickAccessButton(quickAccessButtons, "SquadQuickButton", "Squad", "", "squad", Theme.Colors.CommandBlue, 5)
	local inviteQuickButton = createQuickAccessButton(quickAccessButtons, "InviteQuickButton", "Invite", "", "invite", Theme.Colors.CommandTeal, 6)
	local settingsQuickButton = createQuickAccessButton(quickAccessButtons, "SettingsQuickButton", "Settings", "", "settings", Theme.Colors.Backdrop, 7)
	local quickAccessFooterRule = new("Frame", {
		Name = "FooterRule",
		BackgroundColor3 = Theme.Colors.BunkerAccent,
		BackgroundTransparency = 0.74,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 14, 1, -58),
		Size = UDim2.new(1, -28, 0, 1),
		Parent = quickAccessBar,
	})
	quickAccessFooterRule.Visible = true
	local quickAccessFooter = label(quickAccessBar, "Footer", "Quartermaster buys stock. Locker handles owned gear. Activities and squad tools stay separate.", UDim2.new(0, 14, 1, -54), UDim2.new(1, -28, 0, 44), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(quickAccessFooter, 10)
	quickAccessFooter.Visible = true
	lobbyRefs.QuickAccessBar = quickAccessBar
	lobbyRefs.ShopQuickButton = shopQuickButton
	lobbyRefs.InventoryQuickButton = inventoryQuickButton
	lobbyRefs.SkillTreeQuickButton = skillTreeQuickButton
	lobbyRefs.ActivitiesQuickButton = activitiesQuickButton
	lobbyRefs.SquadQuickButton = squadQuickButton
	lobbyRefs.InviteQuickButton = inviteQuickButton
	lobbyRefs.SettingsQuickButton = settingsQuickButton
end

function UiBuilder.create(playerGui)
	local existing = playerGui:FindFirstChild("ZombieLobbyGui")
	if existing then
		existing:Destroy()
	end

	local gui = new("ScreenGui", {
		Name = "ZombieLobbyGui",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	local root = new("Frame", {
		Name = "Root",
		BackgroundColor3 = Theme.Colors.Background,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		Parent = gui,
	})
	local rootGradient = addGradient(root, Theme.Colors.Background, Theme.Colors.Backdrop, 25)

	local overlay = new("Frame", {
		Name = "Overlay",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Parent = root,
	})

	local combatOverlay = new("Frame", {
		Name = "CombatOverlay",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 80,
		Parent = root,
	})
	local hitMarker = new("Frame", {
		Name = "HitMarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 40, 0, 40),
		Visible = false,
		ZIndex = 81,
		Parent = combatOverlay,
	})
	for index, data in ipairs({
		{ name = "TL", position = UDim2.new(0, 5, 0, 18), rotation = 45 },
		{ name = "TR", position = UDim2.new(1, -17, 0, 18), rotation = -45 },
		{ name = "BL", position = UDim2.new(0, 5, 1, -22), rotation = -45 },
		{ name = "BR", position = UDim2.new(1, -17, 1, -22), rotation = 45 },
	}) do
		local line = new("Frame", {
			Name = data.name,
			BackgroundColor3 = Theme.Colors.Text,
			BorderSizePixel = 0,
			Position = data.position,
			Size = UDim2.new(0, 12, 0, 3),
			Rotation = data.rotation,
			ZIndex = 81,
			Parent = hitMarker,
		})
		addCorner(line, UDim.new(0, 3))
		line.LayoutOrder = index
	end
	local rewardFloatLayer = new("Frame", {
		Name = "RewardFloatLayer",
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 82,
		Parent = combatOverlay,
	})

	local home = addPage(overlay, "HomePage")
	local loading = addPage(overlay, "LoadingPage")
	local lobby = addPage(overlay, "LobbyPage")
	local homeRefs = {}
	local loadingRefs = {}
	local lobbyRefs = {
		Popups = {},
	}

	createHomePage(home, homeRefs)
	createLoadingPage(loading, loadingRefs)
	createLobbyChrome(lobby, lobbyRefs, combatOverlay, hitMarker, rewardFloatLayer)
	local shopStyle = {
		backgroundColor = Color3.fromRGB(132, 101, 66),
		backgroundTransparency = 0,
		gradientStart = Color3.fromRGB(168, 130, 84),
		gradientEnd = Color3.fromRGB(108, 81, 53),
		strokeColor = Theme.Colors.AccentWarm,
		headerColor = Color3.fromRGB(244, 186, 98),
		headerColorEnd = Color3.fromRGB(164, 116, 58),
		badgeText = "MARKET",
		badgeColor = Color3.fromRGB(190, 140, 74),
	}
	local squadStyle = {
		backgroundColor = Color3.fromRGB(42, 54, 66),
		gradientStart = Color3.fromRGB(52, 66, 80),
		gradientEnd = Color3.fromRGB(32, 40, 50),
		strokeColor = Color3.fromRGB(118, 170, 224),
		headerColor = Color3.fromRGB(86, 136, 194),
		headerColorEnd = Color3.fromRGB(48, 78, 114),
		badgeText = "TACTICAL",
		badgeColor = Color3.fromRGB(56, 86, 112),
	}
	local socialStyle = {
		backgroundColor = Color3.fromRGB(30, 43, 40),
		gradientStart = Color3.fromRGB(36, 52, 48),
		gradientEnd = Color3.fromRGB(25, 35, 33),
		strokeColor = Color3.fromRGB(88, 174, 154),
		headerColor = Color3.fromRGB(52, 132, 114),
		headerColorEnd = Color3.fromRGB(31, 79, 69),
		badgeText = "SOCIAL",
		badgeColor = Color3.fromRGB(34, 70, 64),
	}

	do
	local squadPopup = createPopup(lobby, "SquadPopup", UDim2.new(0, 1240, 0, 700), UDim2.new(0.025, 0, 0.08, 0), {
		backgroundColor = squadStyle.backgroundColor,
		gradientStart = squadStyle.gradientStart,
		gradientEnd = squadStyle.gradientEnd,
		strokeColor = squadStyle.strokeColor,
		headerColor = squadStyle.headerColor,
		headerColorEnd = squadStyle.headerColorEnd,
		badgeText = squadStyle.badgeText,
		badgeColor = squadStyle.badgeColor,
		iconText = "SQD",
		visible = false,
	})
	local squadBadgeNode = squadPopup:FindFirstChild("Badge")
	if squadBadgeNode and squadBadgeNode:IsA("GuiObject") then
		squadBadgeNode.Visible = false
	end
	local squadEmblemNode = squadPopup:FindFirstChild("Emblem")
	if squadEmblemNode and squadEmblemNode:IsA("GuiObject") then
		squadEmblemNode.Visible = false
	end
	local squadHeaderRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(110, 160, 212),
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, 128),
		Size = UDim2.new(1, -60, 0, 2),
		Parent = squadPopup,
	})
	addCorner(squadHeaderRule, UDim.new(0, 4))
	local squadPopupAccent = new("Frame", {
		Name = "HeaderAccent",
		BackgroundColor3 = Color3.fromRGB(122, 176, 230),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, 92),
		Size = UDim2.new(0, 148, 0, 3),
		Parent = squadPopup,
	})
	addCorner(squadPopupAccent, UDim.new(0, 6))
	local squadLeftRail = new("Frame", {
		Name = "LeftRail",
		BackgroundColor3 = Color3.fromRGB(42, 56, 72),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 28, 0, 132),
		Size = UDim2.new(0, 224, 1, -160),
		Parent = squadPopup,
	})
	addCorner(squadLeftRail, UDim.new(0, 18))
	addStroke(squadLeftRail, Color3.fromRGB(122, 176, 230), 0.16, 1)
	local squadRailTitle = label(squadLeftRail, "RailTitle", "Command Actions", UDim2.new(0, 16, 0, 14), UDim2.new(1, -32, 0, 22), Theme.Fonts.Heading, Color3.fromRGB(236, 245, 255))
	setFixedText(squadRailTitle, 19)
	local squadRailBody = label(squadLeftRail, "RailBody", "Control the roster, lock privacy, and route survivors into the fireteam before deployment.", UDim2.new(0, 16, 0, 42), UDim2.new(1, -32, 0, 50), Theme.Fonts.Body, Color3.fromRGB(196, 218, 242))
	setFixedText(squadRailBody, 12)

	local squadCenterPane = new("Frame", {
		Name = "CenterPane",
		BackgroundColor3 = Color3.fromRGB(44, 58, 72),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 270, 0, 132),
		Size = UDim2.new(0, 292, 1, -160),
		Parent = squadPopup,
	})
	addCorner(squadCenterPane, UDim.new(0, 18))
	addStroke(squadCenterPane, Color3.fromRGB(110, 160, 212), 0.18, 1)

	local squadRightPane = new("Frame", {
		Name = "RightPane",
		BackgroundColor3 = Color3.fromRGB(34, 46, 58),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 580, 0, 132),
		Size = UDim2.new(1, -608, 1, -160),
		Parent = squadPopup,
	})
	addCorner(squadRightPane, UDim.new(0, 18))
	addStroke(squadRightPane, Color3.fromRGB(110, 160, 212), 0.16, 1)

	local squadTitle = label(squadPopup, "Title", "Fireteam Command", UDim2.new(0, 34, 0, 58), UDim2.new(1, -190, 0, 34), Theme.Fonts.Heading, Color3.fromRGB(244, 249, 255))
	setFixedText(squadTitle, 32)
	local squadTag = label(squadPopup, "Tag", "Assemble the team, assign the lead, and lock the roster before deployment.", UDim2.new(0, 34, 0, 94), UDim2.new(1, -220, 0, 22), Theme.Fonts.Body, Color3.fromRGB(214, 232, 249))
	setFixedText(squadTag, 15)
	local squadSummary = label(squadCenterPane, "Summary", "A fireteam can run solo or stack four deep. Bigger squads pull heavier pressure but better salvage.", UDim2.new(0, 18, 0, 20), UDim2.new(1, -36, 0, 56), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(squadSummary, 15)
	local squadReadinessCard = createInsetCard(squadCenterPane, "ReadinessCard", UDim2.new(0, 18, 0, 86), UDim2.new(1, -36, 0, 110), Color3.fromRGB(32, 43, 56), Color3.fromRGB(122, 176, 230))
	local readinessTitle = label(squadReadinessCard, "ReadinessTitle", "Fireteam State", UDim2.new(0, 14, 0, 12), UDim2.new(1, -28, 0, 22), Theme.Fonts.Heading, Color3.fromRGB(234, 242, 255))
	setFixedText(readinessTitle, 18)
	local readinessBody = label(squadReadinessCard, "ReadinessBody", "Keep the lead slot stable, stage the roster, and lock the team before the siren starts.", UDim2.new(0, 14, 0, 38), UDim2.new(1, -28, 0, 52), Theme.Fonts.Body, Color3.fromRGB(194, 216, 240))
	setFixedText(readinessBody, 14)
	local squadOpsCard = createInsetCard(squadCenterPane, "OpsCard", UDim2.new(0, 18, 0, 214), UDim2.new(1, -36, 0, 104), Color3.fromRGB(36, 48, 60), Color3.fromRGB(110, 160, 212))
	local squadOpsTitle = label(squadOpsCard, "OpsTitle", "Ops Status", UDim2.new(0, 14, 0, 12), UDim2.new(1, -28, 0, 20), Theme.Fonts.Heading, Color3.fromRGB(240, 246, 255))
	setFixedText(squadOpsTitle, 17)
	local squadOpsBody = label(squadOpsCard, "OpsBody", "Invite survivors, switch public or private, and keep solo fallback ready.", UDim2.new(0, 14, 0, 36), UDim2.new(1, -28, 0, 48), Theme.Fonts.Body, Color3.fromRGB(190, 211, 234))
	setFixedText(squadOpsBody, 13)
	local squadBriefCard = createInsetCard(squadCenterPane, "BriefCard", UDim2.new(0, 18, 0, 332), UDim2.new(1, -36, 1, -350), Color3.fromRGB(28, 38, 48), Color3.fromRGB(102, 154, 208))
	local squadBriefTitle = label(squadBriefCard, "BriefTitle", "Command Brief", UDim2.new(0, 14, 0, 10), UDim2.new(1, -28, 0, 20), Theme.Fonts.Heading, Color3.fromRGB(240, 246, 255))
	setFixedText(squadBriefTitle, 16)
	local squadBriefBody = label(squadBriefCard, "BriefBody", "Small squads move clean. Full squads pull harder waves, tougher infected, and richer payouts.", UDim2.new(0, 14, 0, 32), UDim2.new(1, -28, 0, 28), Theme.Fonts.Body, Color3.fromRGB(190, 211, 234))
	setFixedText(squadBriefBody, 13)
	local squadRosterBadge = new("TextLabel", {
		Name = "RosterBadge",
		BackgroundColor3 = Color3.fromRGB(54, 70, 88),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 20, 0, 20),
		Size = UDim2.new(0, 126, 0, 28),
		Text = "LIVE ROSTER",
		TextColor3 = Color3.fromRGB(234, 242, 255),
		TextScaled = false,
		TextSize = 13,
		Font = Theme.Fonts.Heading,
		Parent = squadRightPane,
	})
	addCorner(squadRosterBadge, UDim.new(0, 10))
	addStroke(squadRosterBadge, Color3.fromRGB(122, 176, 230), 0.12, 1)
	local squadSlotsHeader = label(squadRightPane, "SlotsHeader", "Fireteam Roster", UDim2.new(0, 20, 0, 58), UDim2.new(1, -40, 0, 26), Theme.Fonts.Heading, Color3.fromRGB(242, 247, 255))
	setFixedText(squadSlotsHeader, 27)
	local squadSlotsSub = label(squadRightPane, "SlotsSub", "Roster slots, lead control, and open seats stay visible here during staging.", UDim2.new(0, 20, 0, 92), UDim2.new(1, -40, 0, 34), Theme.Fonts.Body, Color3.fromRGB(184, 208, 236))
	setFixedText(squadSlotsSub, 14)
	local squadSlots = {}
	for slot = 1, Theme.SquadLimit do
		local slotCard = new("Frame", {
			Name = "SlotCard" .. slot,
			BackgroundColor3 = Color3.fromRGB(34, 46, 58),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 20, 0, 144 + ((slot - 1) * 92)),
			Size = UDim2.new(1, -40, 0, 74),
			Parent = squadRightPane,
		})
		addCorner(slotCard, UDim.new(0, 10))
		addStroke(slotCard, squadStyle.strokeColor, 0.2, 1)

		local slotAccent = new("Frame", {
			Name = "Accent",
			BackgroundColor3 = squadStyle.headerColor,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 12, 0, 12),
			Size = UDim2.new(0, 4, 1, -24),
			Parent = slotCard,
		})
		addCorner(slotAccent, UDim.new(0, 4))

		local slotBadge = new("TextLabel", {
			Name = "Badge",
			BackgroundColor3 = Color3.fromRGB(54, 70, 88),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 24, 0, 12),
			Size = UDim2.new(0, 62, 0, 20),
			Text = ("SLOT %d"):format(slot),
			TextColor3 = Color3.fromRGB(228, 238, 255),
			TextScaled = false,
			TextSize = 10,
			Font = Theme.Fonts.Heading,
			Parent = slotCard,
		})
		addCorner(slotBadge, UDim.new(0, 8))

		local slotLabel = new("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 24, 0, 34),
			Size = UDim2.new(1, -56, 0, 22),
			Text = "Slot " .. slot,
			TextColor3 = Theme.Colors.Text,
			TextScaled = false,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Theme.Fonts.Heading,
			Parent = slotCard,
		})

		local slotHint = new("TextLabel", {
			Name = "Hint",
			BackgroundTransparency = 1,
			Position = UDim2.new(1, -144, 0, 14),
			Size = UDim2.new(0, 122, 0, 16),
			Text = slot == 1 and "Lead slot" or "Open slot",
			TextColor3 = Color3.fromRGB(182, 205, 232),
			TextScaled = false,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Theme.Fonts.Body,
			Parent = slotCard,
		})

		squadSlots[slot] = slotLabel
	end
	local refreshSquadsButton = createButton(squadLeftRail, "RefreshSquadsButton", "Refresh Squad Board", UDim2.new(1, -32, 0, 46), UDim2.new(0, 16, 0, 122), Theme.Colors.AccentWarm)
	refreshSquadsButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(refreshSquadsButton, 18, Enum.TextXAlignment.Center)
	refreshSquadsButton.Position = UDim2.new(0, 16, 1, -214)
	local inviteSquadButton = createButton(squadLeftRail, "InviteSquadButton", "Invite Survivors", UDim2.new(1, -32, 0, 46), UDim2.new(0, 16, 1, -160), Theme.Colors.AccentWarm)
	inviteSquadButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(inviteSquadButton, 18, Enum.TextXAlignment.Center)
	local privacySquadButton = createButton(squadLeftRail, "PrivacySquadButton", "Private Squad: Off", UDim2.new(1, -32, 0, 46), UDim2.new(0, 16, 1, -106), Theme.Colors.Backdrop)
	privacySquadButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(privacySquadButton, 18, Enum.TextXAlignment.Center)
	local leaveSquadButton = createButton(squadLeftRail, "LeaveSquadButton", "Return To Solo", UDim2.new(1, -32, 0, 46), UDim2.new(0, 16, 1, -52), Theme.Colors.Accent)
	leaveSquadButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(leaveSquadButton, 18, Enum.TextXAlignment.Center)
	local squadRailFooter = label(squadLeftRail, "RailFooter", "Use the left rail for actions, the center for command status, and the right board for the live roster.", UDim2.new(0, 16, 1, -290), UDim2.new(1, -32, 0, 48), Theme.Fonts.Body, Color3.fromRGB(196, 218, 242))
	setFixedText(squadRailFooter, 11)
	local closeSquadButton = createButton(squadPopup, "CloseSquadButton", "Close", UDim2.new(0, 122, 0, 44), UDim2.new(1, -28, 0, 56), Theme.Colors.Backdrop)
	closeSquadButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(closeSquadButton, 19, Enum.TextXAlignment.Center)
	lobbyRefs.Popups.Squad = squadPopup
	lobbyRefs.SquadSlots = squadSlots
	lobbyRefs.SquadSummary = squadSummary
	lobbyRefs.RefreshSquadsButton = refreshSquadsButton
	lobbyRefs.InviteSquadButton = inviteSquadButton
	lobbyRefs.PrivacySquadButton = privacySquadButton
	lobbyRefs.LeaveSquadButton = leaveSquadButton
	lobbyRefs.CloseSquadButton = closeSquadButton
	end

	do
	local socialPopup = createPopup(lobby, "SocialPopup", UDim2.new(0, 1240, 0, 700), UDim2.new(0.025, 0, 0.08, 0), {
		backgroundColor = socialStyle.backgroundColor,
		gradientStart = socialStyle.gradientStart,
		gradientEnd = socialStyle.gradientEnd,
		strokeColor = socialStyle.strokeColor,
		headerColor = socialStyle.headerColor,
		headerColorEnd = socialStyle.headerColorEnd,
		badgeText = socialStyle.badgeText,
		badgeColor = socialStyle.badgeColor,
		iconText = "SOC",
		visible = false,
	})
	local socialBadgeNode = socialPopup:FindFirstChild("Badge")
	if socialBadgeNode and socialBadgeNode:IsA("GuiObject") then
		socialBadgeNode.Visible = false
	end
	local socialEmblemNode = socialPopup:FindFirstChild("Emblem")
	if socialEmblemNode and socialEmblemNode:IsA("GuiObject") then
		socialEmblemNode.Visible = false
	end
	local socialHeaderRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(100, 184, 164),
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, 128),
		Size = UDim2.new(1, -60, 0, 2),
		Parent = socialPopup,
	})
	addCorner(socialHeaderRule, UDim.new(0, 4))
	local socialPopupAccent = new("Frame", {
		Name = "HeaderAccent",
		BackgroundColor3 = Color3.fromRGB(100, 184, 164),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, 92),
		Size = UDim2.new(0, 148, 0, 3),
		Parent = socialPopup,
	})
	addCorner(socialPopupAccent, UDim.new(0, 6))
	local socialLeftRail = new("Frame", {
		Name = "LeftRail",
		BackgroundColor3 = Color3.fromRGB(34, 58, 52),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 28, 0, 132),
		Size = UDim2.new(0, 224, 1, -160),
		Parent = socialPopup,
	})
	addCorner(socialLeftRail, UDim.new(0, 18))
	addStroke(socialLeftRail, Color3.fromRGB(100, 184, 164), 0.16, 1)
	local socialRailTitle = label(socialLeftRail, "RailTitle", "Comms Routing", UDim2.new(0, 16, 0, 14), UDim2.new(1, -32, 0, 22), Theme.Fonts.Heading, Color3.fromRGB(236, 250, 245))
	setFixedText(socialRailTitle, 19)
	local socialRailBody = label(socialLeftRail, "RailBody", "Track open squads, watch online survivors, and route invites through the comms board.", UDim2.new(0, 16, 0, 42), UDim2.new(1, -32, 0, 50), Theme.Fonts.Body, Color3.fromRGB(184, 226, 214))
	setFixedText(socialRailBody, 12)

	local socialCenterPane = new("Frame", {
		Name = "CenterPane",
		BackgroundColor3 = Color3.fromRGB(34, 54, 48),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 270, 0, 132),
		Size = UDim2.new(0, 292, 1, -160),
		Parent = socialPopup,
	})
	addCorner(socialCenterPane, UDim.new(0, 18))
	addStroke(socialCenterPane, Color3.fromRGB(100, 184, 164), 0.18, 1)

	local socialRightPane = new("Frame", {
		Name = "RightPane",
		BackgroundColor3 = Color3.fromRGB(28, 46, 42),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 580, 0, 132),
		Size = UDim2.new(1, -608, 1, -160),
		Parent = socialPopup,
	})
	addCorner(socialRightPane, UDim.new(0, 18))
	addStroke(socialRightPane, Color3.fromRGB(88, 174, 154), 0.16, 1)

	local socialTitle = label(socialPopup, "Title", "Comms Lounge", UDim2.new(0, 34, 0, 58), UDim2.new(1, -190, 0, 34), Theme.Fonts.Heading, Color3.fromRGB(241, 251, 247))
	setFixedText(socialTitle, 32)
	local socialBody = label(socialPopup, "Body", "Watch the public board, find online survivors, and jump into an open squad before the next cycle.", UDim2.new(0, 34, 0, 94), UDim2.new(1, -220, 0, 22), Theme.Fonts.Body, Color3.fromRGB(173, 227, 214))
	setFixedText(socialBody, 15)
	local socialRailCopy = label(socialCenterPane, "RailCopy", "This board tracks open bunker squads and lets solo survivors jump into active teams fast.", UDim2.new(0, 18, 0, 20), UDim2.new(1, -36, 0, 56), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(socialRailCopy, 15)
	local socialBulletin = createInsetCard(socialCenterPane, "Bulletin", UDim2.new(0, 18, 0, 88), UDim2.new(1, -36, 0, 132), Color3.fromRGB(24, 44, 40), Color3.fromRGB(88, 174, 154))
	local bulletinTitle = label(socialBulletin, "BulletinTitle", "Community Board", UDim2.new(0, 14, 0, 12), UDim2.new(1, -28, 0, 20), Theme.Fonts.Heading, Color3.fromRGB(233, 248, 243))
	setFixedText(bulletinTitle, 17)
	local bulletinBody = label(socialBulletin, "BulletinBody", "This room is for quick team pickup, public runs, and bunker chatter before deployment.", UDim2.new(0, 14, 0, 38), UDim2.new(1, -28, 0, 56), Theme.Fonts.Body, Color3.fromRGB(176, 226, 214))
	setFixedText(bulletinBody, 14)
	local bulletinTag = label(socialBulletin, "BulletinTag", "Open squads rotate live during the session.", UDim2.new(0, 14, 1, -28), UDim2.new(1, -28, 0, 18), Theme.Fonts.Body, Color3.fromRGB(134, 200, 182))
	setFixedText(bulletinTag, 12)
	local inviteRosterTitle = label(socialCenterPane, "InviteRosterTitle", "Online Survivors", UDim2.new(0, 18, 0, 238), UDim2.new(1, -36, 0, 24), Theme.Fonts.Heading, Color3.fromRGB(236, 249, 244))
	setFixedText(inviteRosterTitle, 18)
	local invitePlayerList = createListFrame(socialCenterPane, "InvitePlayerList", UDim2.new(0, 18, 0, 270), UDim2.new(1, -36, 1, -288))
	invitePlayerList.BackgroundColor3 = Color3.fromRGB(23, 33, 30)
	local invitePlayerEmpty = label(socialCenterPane, "InvitePlayerEmpty", "No invite targets visible right now.", UDim2.new(0, 24, 0, 282), UDim2.new(1, -48, 0, 24), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Center)
	setFixedText(invitePlayerEmpty, 13, Enum.TextXAlignment.Center)
	invitePlayerEmpty.Visible = false
	local socialBoardBadge = new("TextLabel", {
		Name = "BoardBadge",
		BackgroundColor3 = Color3.fromRGB(42, 66, 60),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 20, 0, 20),
		Size = UDim2.new(0, 134, 0, 28),
		Text = "PUBLIC BOARD",
		TextColor3 = Color3.fromRGB(236, 249, 244),
		TextScaled = false,
		TextSize = 13,
		Font = Theme.Fonts.Heading,
		Parent = socialRightPane,
	})
	addCorner(socialBoardBadge, UDim.new(0, 10))
	addStroke(socialBoardBadge, Color3.fromRGB(100, 184, 164), 0.12, 1)
	local socialDirectoryTitle = label(socialRightPane, "DirectoryTitle", "Open Squad Directory", UDim2.new(0, 20, 0, 58), UDim2.new(1, -40, 0, 26), Theme.Fonts.Heading, Color3.fromRGB(240, 252, 247))
	setFixedText(socialDirectoryTitle, 27)
	local socialDirectorySub = label(socialRightPane, "DirectorySub", "Browse public teams, check open slots, and join survivors already staging for the breach.", UDim2.new(0, 20, 0, 92), UDim2.new(1, -40, 0, 34), Theme.Fonts.Body, Color3.fromRGB(180, 232, 220))
	setFixedText(socialDirectorySub, 14)
	local squadDirectoryList = createListFrame(socialRightPane, "SquadDirectory", UDim2.new(0, 20, 0, 144), UDim2.new(1, -40, 1, -166))
	squadDirectoryList.BackgroundColor3 = Color3.fromRGB(23, 33, 30)
	local squadDirectoryEmpty = label(socialRightPane, "DirectoryEmpty", "No public squads are posting to the board yet.", UDim2.new(0, 24, 0, 156), UDim2.new(1, -48, 0, 24), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Center)
	setFixedText(squadDirectoryEmpty, 15, Enum.TextXAlignment.Center)
	squadDirectoryEmpty.Visible = false
	local refreshBoardButton = createButton(socialLeftRail, "RefreshBoardButton", "Refresh Board", UDim2.new(1, -32, 0, 46), UDim2.new(0, 16, 1, -56), Theme.Colors.AccentWarm)
	refreshBoardButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(refreshBoardButton, 18, Enum.TextXAlignment.Center)
	local socialRailFooter = label(socialLeftRail, "RailFooter", "Use the left rail for actions, the center for survivors, and the right board for the live public feed.", UDim2.new(0, 16, 1, -118), UDim2.new(1, -32, 0, 48), Theme.Fonts.Body, Color3.fromRGB(184, 226, 214))
	setFixedText(socialRailFooter, 11)
	local closeSocialButton = createButton(socialPopup, "CloseSocialButton", "Close", UDim2.new(0, 122, 0, 44), UDim2.new(1, -28, 0, 56), Theme.Colors.Backdrop)
	closeSocialButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(closeSocialButton, 19, Enum.TextXAlignment.Center)
	lobbyRefs.Popups.Social = socialPopup
	lobbyRefs.SquadDirectoryList = squadDirectoryList
	lobbyRefs.SquadDirectoryEmpty = squadDirectoryEmpty
	lobbyRefs.InvitePlayerList = invitePlayerList
	lobbyRefs.InvitePlayerEmpty = invitePlayerEmpty
	lobbyRefs.RefreshBoardButton = refreshBoardButton
	lobbyRefs.CloseSocialButton = closeSocialButton
	lobbyRefs.SocialBody = socialBody

	local invitePopup = createPopup(lobby, "InvitePopup", UDim2.new(0, 460, 0, 240), UDim2.new(0.58, 0, 0.13, 0), {
		backgroundColor = Color3.fromRGB(42, 54, 66),
		gradientStart = Color3.fromRGB(52, 66, 80),
		gradientEnd = Color3.fromRGB(30, 40, 50),
		strokeColor = Color3.fromRGB(118, 170, 224),
		headerColor = Color3.fromRGB(86, 136, 194),
		headerColorEnd = Color3.fromRGB(48, 78, 114),
		badgeText = "INVITE",
		badgeColor = Color3.fromRGB(56, 86, 112),
		iconText = "INV",
		visible = false,
	})
	local inviteTitle = label(invitePopup, "Title", "Fireteam Invite", UDim2.new(0, 24, 0, 62), UDim2.new(1, -48, 0, 28), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(inviteTitle, 24)
	local inviteBody = label(invitePopup, "Body", "An online survivor invited you to join their fireteam.", UDim2.new(0, 24, 0, 100), UDim2.new(1, -48, 0, 54), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(inviteBody, 16)
	local inviteAccept = createButton(invitePopup, "AcceptInviteButton", "Accept", UDim2.new(0, 150, 0, 42), UDim2.new(0, 24, 1, -58), Theme.Colors.Accent)
	inviteAccept.AnchorPoint = Vector2.new(0, 0)
	setFixedText(inviteAccept, 18, Enum.TextXAlignment.Center)
	local inviteDecline = createButton(invitePopup, "DeclineInviteButton", "Decline", UDim2.new(0, 150, 0, 42), UDim2.new(0, 186, 1, -58), Theme.Colors.Backdrop)
	inviteDecline.AnchorPoint = Vector2.new(0, 0)
	setFixedText(inviteDecline, 18, Enum.TextXAlignment.Center)
	lobbyRefs.InvitePopup = invitePopup
	lobbyRefs.InviteTitle = inviteTitle
	lobbyRefs.InviteBody = inviteBody
	lobbyRefs.AcceptInviteButton = inviteAccept
	lobbyRefs.DeclineInviteButton = inviteDecline
	end

	do
	local shopPopup = createPopup(lobby, "ShopPopup", UDim2.new(0, 1200, 0, 670), UDim2.new(0.04, 0, 0.085, 0), {
		backgroundColor = Color3.fromRGB(28, 34, 42),
		gradientStart = Color3.fromRGB(42, 50, 62),
		gradientEnd = Color3.fromRGB(18, 24, 32),
		strokeColor = Color3.fromRGB(112, 132, 156),
		headerColor = Color3.fromRGB(74, 98, 132),
		headerColorEnd = Color3.fromRGB(48, 64, 88),
		badgeText = "STOCK",
		badgeColor = Color3.fromRGB(56, 76, 104),
		iconText = "QTR",
		visible = false,
	})
	local shopBadgeNode = shopPopup:FindFirstChild("Badge")
	if shopBadgeNode and shopBadgeNode:IsA("GuiObject") then
		shopBadgeNode.Visible = false
	end
	local shopEmblemNode = shopPopup:FindFirstChild("Emblem")
	if shopEmblemNode and shopEmblemNode:IsA("GuiObject") then
		shopEmblemNode.Visible = false
	end
	local shopHeaderRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(112, 162, 214),
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 28, 0, 104),
		Size = UDim2.new(1, -60, 0, 2),
		Parent = shopPopup,
	})
	addCorner(shopHeaderRule, UDim.new(0, 4))
	local shopPopupAccent = new("Frame", {
		Name = "HeaderAccent",
		BackgroundColor3 = Color3.fromRGB(112, 162, 214),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 28, 0, 76),
		Size = UDim2.new(0, 148, 0, 3),
		Parent = shopPopup,
	})
	addCorner(shopPopupAccent, UDim.new(0, 6))
	local leftRail = new("Frame", {
		Name = "LeftRail",
		BackgroundColor3 = Color3.fromRGB(34, 42, 52),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 24, 0, 118),
		Size = UDim2.new(0, 196, 1, -142),
		Parent = shopPopup,
	})
	addCorner(leftRail, UDim.new(0, 18))
	addStroke(leftRail, Color3.fromRGB(112, 162, 214), 0.16, 1)
	local leftRailTitle = label(leftRail, "RailTitle", "Quartermaster", UDim2.new(0, 16, 0, 14), UDim2.new(1, -32, 0, 22), Theme.Fonts.Heading, Color3.fromRGB(236, 244, 255))
	setFixedText(leftRailTitle, 19)
	local leftRailBody = label(leftRail, "RailBody", "Pick a stock lane, inspect the feed, and unlock gear without mixing it up with your locker.", UDim2.new(0, 16, 0, 42), UDim2.new(1, -32, 0, 46), Theme.Fonts.Body, Color3.fromRGB(182, 202, 224))
	setFixedText(leftRailBody, 12)

	local centerPane = new("Frame", {
		Name = "CenterPane",
		BackgroundColor3 = Color3.fromRGB(36, 46, 58),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 230, 0, 118),
		Size = UDim2.new(0, 236, 1, -142),
		Parent = shopPopup,
	})
	addCorner(centerPane, UDim.new(0, 18))
	addStroke(centerPane, Color3.fromRGB(112, 162, 214), 0.18, 1)

	local rightPane = new("Frame", {
		Name = "RightPane",
		BackgroundColor3 = Color3.fromRGB(40, 50, 62),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 480, 0, 118),
		Size = UDim2.new(1, -504, 1, -142),
		Parent = shopPopup,
	})
	addCorner(rightPane, UDim.new(0, 18))
	addStroke(rightPane, Color3.fromRGB(112, 162, 214), 0.16, 1)

	local shopTitle = label(shopPopup, "Title", "Quartermaster Board", UDim2.new(0, 32, 0, 52), UDim2.new(1, -190, 0, 28), Theme.Fonts.Heading, Color3.fromRGB(236, 244, 255))
	setFixedText(shopTitle, 28)
	local shopTag = label(shopPopup, "Tag", "Buy new stock here. Owned weapons and cosmetics belong to the locker, not the market feed.", UDim2.new(0, 32, 0, 84), UDim2.new(1, -220, 0, 18), Theme.Fonts.Body, Color3.fromRGB(180, 202, 224))
	setFixedText(shopTag, 14)
	local rewardCard = createInsetCard(centerPane, "RewardCard", UDim2.new(0, 14, 0, 14), UDim2.new(1, -28, 0, 74), Color3.fromRGB(30, 40, 50), Color3.fromRGB(112, 162, 214))
	local dailyRewardStatus = label(rewardCard, "DailyRewardStatus", "Daily reward ready.", UDim2.new(0, 14, 0, 32), UDim2.new(1, -28, 0, 18), Theme.Fonts.Body, Color3.fromRGB(220, 239, 164))
	setFixedText(dailyRewardStatus, 15)
	local rewardTitle = label(rewardCard, "RewardTitle", "Daily Quartermaster", UDim2.new(0, 14, 0, 14), UDim2.new(1, -54, 0, 20), Theme.Fonts.Heading, Color3.fromRGB(236, 244, 255))
	setFixedText(rewardTitle, 18)
	local claimDailyButton = createButton(rewardCard, "ClaimDailyButton", "Claim Daily", UDim2.new(1, -28, 0, 28), UDim2.new(0, 14, 0, 46), Color3.fromRGB(96, 152, 104))
	claimDailyButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(claimDailyButton, 16, Enum.TextXAlignment.Center)
	local loadoutCard = createInsetCard(centerPane, "LoadoutCard", UDim2.new(0, 14, 0, 94), UDim2.new(1, -28, 0, 104), Color3.fromRGB(30, 40, 50), Color3.fromRGB(112, 162, 214))
	local loadoutTitle = label(loadoutCard, "LoadoutTitle", "Active Loadout", UDim2.new(0, 14, 0, 14), UDim2.new(1, -54, 0, 20), Theme.Fonts.Heading, Color3.fromRGB(236, 244, 255))
	setFixedText(loadoutTitle, 18)
	local loadoutSummary = label(loadoutCard, "LoadoutSummary", "Weapon: Training Blade | Cosmetic: None", UDim2.new(0, 14, 0, 34), UDim2.new(1, -28, 0, 26), Theme.Fonts.Heading, Color3.fromRGB(236, 244, 255))
	setFixedText(loadoutSummary, 15)
	local statsSummary = label(loadoutCard, "StatsSummary", "Missions: 0 | Kills: 0", UDim2.new(0, 14, 0, 66), UDim2.new(1, -28, 0, 14), Theme.Fonts.Body, Color3.fromRGB(182, 202, 224))
	setFixedText(statsSummary, 12)
	local skillSummary = label(loadoutCard, "SkillSummary", "Bunker Level 1 | 0 skill points ready", UDim2.new(0, 14, 0, 84), UDim2.new(1, -28, 0, 14), Theme.Fonts.Body, Color3.fromRGB(144, 202, 160))
	setFixedText(skillSummary, 12)
	local previewCard = createInsetCard(centerPane, "PreviewCard", UDim2.new(0, 14, 0, 214), UDim2.new(1, -28, 1, -228), Color3.fromRGB(30, 40, 50), Color3.fromRGB(112, 162, 214))
	local previewTitle = label(previewCard, "PreviewTitle", "Weapon Preview", UDim2.new(0, 14, 0, 14), UDim2.new(1, -28, 0, 20), Theme.Fonts.Heading, Color3.fromRGB(236, 244, 255))
	setFixedText(previewTitle, 17)
	local previewBody = label(previewCard, "PreviewBody", "Selected stock appears here with live bunker weapon stats and cosmetic preview.", UDim2.new(0, 14, 0, 38), UDim2.new(1, -28, 0, 34), Theme.Fonts.Body, Color3.fromRGB(182, 202, 224))
	setFixedText(previewBody, 12)
	local previewViewport = new("ViewportFrame", {
		Name = "PreviewViewport",
		BackgroundColor3 = Color3.fromRGB(20, 26, 34),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 14, 0, 78),
		Size = UDim2.new(1, -28, 0, 128),
		Parent = previewCard,
	})
	addCorner(previewViewport, UDim.new(0, 16))
	addStroke(previewViewport, Color3.fromRGB(112, 162, 214), 0.14, 1)
	local previewStats = label(previewCard, "PreviewStats", "DMG -- | RNG -- | RATE -- | AMMO --", UDim2.new(0, 14, 0, 218), UDim2.new(1, -28, 0, 30), Theme.Fonts.Heading, Color3.fromRGB(236, 216, 154))
	setFixedText(previewStats, 11)
	local previewCosmetic = label(previewCard, "PreviewCosmetic", "Preview Cosmetic: None", UDim2.new(0, 14, 0, 250), UDim2.new(1, -28, 0, 22), Theme.Fonts.Body, Color3.fromRGB(144, 202, 160))
	setFixedText(previewCosmetic, 11)
	local previewCompareTitle = label(previewCard, "PreviewCompareTitle", "Compared To Equipped", UDim2.new(0, 14, 0, 278), UDim2.new(1, -28, 0, 14), Theme.Fonts.Heading, Color3.fromRGB(168, 198, 236))
	setFixedText(previewCompareTitle, 10)
	local previewCompareRows = {}
	local compareDefinitions = {
		{ key = "Damage", title = "Damage", color = Color3.fromRGB(236, 122, 98) },
		{ key = "Range", title = "Range", color = Color3.fromRGB(112, 182, 244) },
		{ key = "Rate", title = "Speed", color = Color3.fromRGB(236, 196, 112) },
		{ key = "Ammo", title = "Ammo", color = Color3.fromRGB(144, 208, 152) },
	}
	for index, definition in ipairs(compareDefinitions) do
		local y = 298 + ((index - 1) * 20)
		local row = new("Frame", {
			Name = definition.key .. "CompareRow",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 14, 0, y),
			Size = UDim2.new(1, -28, 0, 18),
			Parent = previewCard,
		})
		local rowLabel = label(row, "Label", definition.title, UDim2.new(0, 0, 0, 0), UDim2.new(0, 48, 1, 0), Theme.Fonts.Body, Color3.fromRGB(192, 210, 228))
		setFixedText(rowLabel, 10)
		local barBack = new("Frame", {
			Name = "BarBack",
			BackgroundColor3 = Color3.fromRGB(26, 34, 42),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 54, 0.5, -4),
			Size = UDim2.new(1, -144, 0, 8),
			Parent = row,
		})
		addCorner(barBack, UDim.new(0, 6))
		local barFill = new("Frame", {
			Name = "BarFill",
			BackgroundColor3 = definition.color,
			BorderSizePixel = 0,
			Size = UDim2.new(0.5, 0, 1, 0),
			Parent = barBack,
		})
		addCorner(barFill, UDim.new(0, 6))
		local rowDelta = label(row, "Delta", "=", UDim2.new(1, -86, 0, 0), UDim2.new(0, 32, 1, 0), Theme.Fonts.Heading, Color3.fromRGB(236, 244, 255))
		setFixedText(rowDelta, 10)
		local rowValue = label(row, "Value", "--", UDim2.new(1, -50, 0, 0), UDim2.new(0, 50, 1, 0), Theme.Fonts.Body, Color3.fromRGB(192, 210, 228))
		setFixedText(rowValue, 10)
		previewCompareRows[definition.key] = {
			BarFill = barFill,
			Delta = rowDelta,
			Value = rowValue,
		}
	end
	local previewHint = label(previewCard, "PreviewHint", "Hover a stock card to inspect the weapon build.", UDim2.new(0, 14, 1, -20), UDim2.new(1, -28, 0, 14), Theme.Fonts.Body, Color3.fromRGB(164, 186, 208))
	setFixedText(previewHint, 10)
	local inventoryBadge = new("TextLabel", {
		Name = "InventoryBadge",
		BackgroundColor3 = Color3.fromRGB(44, 58, 76),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 22, 0, 18),
		Size = UDim2.new(0, 136, 0, 28),
		Text = "QUARTERMASTER STOCK",
		TextColor3 = Color3.fromRGB(236, 244, 255),
		TextScaled = false,
		TextSize = 13,
		Font = Theme.Fonts.Heading,
		Parent = rightPane,
	})
	addCorner(inventoryBadge, UDim.new(0, 10))
	addStroke(inventoryBadge, Color3.fromRGB(112, 162, 214), 0.12, 1)
	local shopBody = label(rightPane, "Body", Theme.ShopCopy["Deploy Tokens"], UDim2.new(0, 20, 0, 50), UDim2.new(1, -40, 0, 24), Theme.Fonts.Body, Color3.fromRGB(182, 202, 224))
	setFixedText(shopBody, 13)
	local inventoryTitle = label(rightPane, "InventoryTitle", "Market Feed", UDim2.new(0, 20, 0, 82), UDim2.new(1, -40, 0, 22), Theme.Fonts.Heading, Color3.fromRGB(236, 244, 255))
	setFixedText(inventoryTitle, 21)
	local tabButtons = new("Frame", {
		Name = "TabButtons",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 106),
		Size = UDim2.new(1, -28, 1, -154),
		Parent = leftRail,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = tabButtons,
	})
	local shopTabs = {}
	for index, tabName in ipairs(Theme.ShopTabs) do
		local tabButton = new("TextButton", {
			Name = tabName:gsub("%s+", ""),
			BackgroundColor3 = Color3.fromRGB(34, 42, 52),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 40),
			Text = tabName,
			TextColor3 = Theme.Colors.Text,
			TextScaled = false,
			TextSize = 16,
			Font = Theme.Fonts.Heading,
			AutoButtonColor = false,
			LayoutOrder = index,
			Parent = tabButtons,
		})
		addCorner(tabButton, UDim.new(0, 12))
		addStroke(tabButton, Color3.fromRGB(112, 132, 156), 0.16, 1)
		shopTabs[tabName] = tabButton
	end
	local railFooter = label(leftRail, "RailFooter", "Quartermaster is for buying. Locker Inventory is for owned gear and active loadout swaps.", UDim2.new(0, 14, 1, -42), UDim2.new(1, -28, 0, 28), Theme.Fonts.Body, Color3.fromRGB(164, 186, 208))
	setFixedText(railFooter, 11)
	local shopStatus = label(rightPane, "Status", "Inspect a stock card, then unlock or equip it. Owned weapons and skins will switch to Equip.", UDim2.new(0, 20, 0, 108), UDim2.new(1, -40, 0, 18), Theme.Fonts.Body, Color3.fromRGB(144, 202, 160))
	setFixedText(shopStatus, 12)
	local rarityFilterLabel = label(rightPane, "RarityFilterLabel", "RARITY FILTER", UDim2.new(0, 20, 0, 132), UDim2.new(1, -40, 0, 14), Theme.Fonts.Heading, Color3.fromRGB(144, 176, 214))
	setFixedText(rarityFilterLabel, 10)
	local shopRarityFilters = new("Frame", {
		Name = "RarityFilters",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 20, 0, 148),
		Size = UDim2.new(1, -40, 0, 30),
		Parent = rightPane,
	})
	local shopRarityButtons = {}
	for index, filterName in ipairs({ "All", "Common", "Uncommon", "Rare", "Epic", "Supporter" }) do
		local filterButton = createButton(shopRarityFilters, filterName .. "ShopRarityFilter", filterName, UDim2.new(0, 92, 0, 26), UDim2.new(0, (index - 1) * 98, 0, 0), Theme.Colors.Backdrop)
		filterButton.AnchorPoint = Vector2.new(0, 0)
		setFixedText(filterButton, 12, Enum.TextXAlignment.Center)
		shopRarityButtons[filterName] = filterButton
	end
	local shopPremiumFilters = new("Frame", {
		Name = "PremiumFilters",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 20, 0, 194),
		Size = UDim2.new(1, -40, 0, 30),
		Visible = false,
		Parent = rightPane,
	})
	local premiumFilterLabel = label(rightPane, "PremiumFilterLabel", "PREMIUM FILTER", UDim2.new(0, 20, 0, 178), UDim2.new(1, -40, 0, 14), Theme.Fonts.Heading, Color3.fromRGB(144, 176, 214))
	setFixedText(premiumFilterLabel, 10)
	premiumFilterLabel.Visible = false
	local shopPremiumButtons = {}
	for index, filterName in ipairs({ "All", "Packs", "Passes", "Supporter" }) do
		local filterButton = createButton(shopPremiumFilters, filterName .. "ShopPremiumFilter", filterName, UDim2.new(0, 102, 0, 26), UDim2.new(0, (index - 1) * 108, 0, 0), Theme.Colors.Backdrop)
		filterButton.AnchorPoint = Vector2.new(0, 0)
		setFixedText(filterButton, 12, Enum.TextXAlignment.Center)
		shopPremiumButtons[filterName] = filterButton
	end
	local shopItemsFrame = createListFrame(rightPane, "Items", UDim2.new(0, 20, 0, 228), UDim2.new(1, -40, 1, -248))
	shopItemsFrame.BackgroundColor3 = Color3.fromRGB(28, 36, 46)
	local shopEmptyLabel = label(rightPane, "Empty", "No stock matches this filter. Change the lane or widen the filter.", UDim2.new(0, 24, 0, 210), UDim2.new(1, -48, 0, 22), Theme.Fonts.Body, Color3.fromRGB(255, 241, 220), Enum.TextXAlignment.Center)
	setFixedText(shopEmptyLabel, 14, Enum.TextXAlignment.Center)
	shopEmptyLabel.Visible = false
	local closeShopButton = createButton(shopPopup, "CloseShopButton", "Close", UDim2.new(0, 116, 0, 40), UDim2.new(1, -28, 0, 48), Color3.fromRGB(52, 64, 80))
	closeShopButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(closeShopButton, 17, Enum.TextXAlignment.Center)
	lobbyRefs.Popups.Shop = shopPopup
	lobbyRefs.ShopBody = shopBody
	lobbyRefs.LoadoutSummary = loadoutSummary
	lobbyRefs.StatsSummary = statsSummary
	lobbyRefs.SkillSummary = skillSummary
	lobbyRefs.ShopStatus = shopStatus
	lobbyRefs.ShopRarityButtons = shopRarityButtons
	lobbyRefs.ShopPremiumFilters = shopPremiumFilters
	lobbyRefs.ShopPremiumButtons = shopPremiumButtons
	lobbyRefs.ShopPremiumFilterLabel = premiumFilterLabel
	lobbyRefs.ShopTabs = shopTabs
	lobbyRefs.ShopItemsFrame = shopItemsFrame
	lobbyRefs.ShopEmptyLabel = shopEmptyLabel
	lobbyRefs.CloseShopButton = closeShopButton
	lobbyRefs.ClaimDailyButton = claimDailyButton
	lobbyRefs.DailyRewardStatus = dailyRewardStatus
	lobbyRefs.ShopPreviewViewport = previewViewport
	lobbyRefs.ShopPreviewTitle = previewTitle
	lobbyRefs.ShopPreviewBody = previewBody
	lobbyRefs.ShopPreviewStats = previewStats
	lobbyRefs.ShopPreviewCosmetic = previewCosmetic
	lobbyRefs.ShopPreviewCompareRows = previewCompareRows
	lobbyRefs.ShopPreviewHint = previewHint
	end

	local shopStyle = {
		backgroundColor = Color3.fromRGB(132, 101, 66),
		backgroundTransparency = 0,
		gradientStart = Color3.fromRGB(168, 130, 84),
		gradientEnd = Color3.fromRGB(108, 81, 53),
		strokeColor = Theme.Colors.AccentWarm,
		headerColor = Color3.fromRGB(244, 186, 98),
		headerColorEnd = Color3.fromRGB(164, 116, 58),
		badgeText = "MARKET",
		badgeColor = Color3.fromRGB(190, 140, 74),
	}
	local squadStyle = {
		backgroundColor = Color3.fromRGB(42, 54, 66),
		gradientStart = Color3.fromRGB(52, 66, 80),
		gradientEnd = Color3.fromRGB(32, 40, 50),
		strokeColor = Color3.fromRGB(118, 170, 224),
		headerColor = Color3.fromRGB(86, 136, 194),
		headerColorEnd = Color3.fromRGB(48, 78, 114),
		badgeText = "TACTICAL",
		badgeColor = Color3.fromRGB(56, 86, 112),
	}
	local socialStyle = {
		backgroundColor = Color3.fromRGB(30, 43, 40),
		gradientStart = Color3.fromRGB(36, 52, 48),
		gradientEnd = Color3.fromRGB(25, 35, 33),
		strokeColor = Color3.fromRGB(88, 174, 154),
		headerColor = Color3.fromRGB(52, 132, 114),
		headerColorEnd = Color3.fromRGB(31, 79, 69),
		badgeText = "SOCIAL",
		badgeColor = Color3.fromRGB(34, 70, 64),
	}

	do
	local squadPopup = createPopup(lobby, "SquadPopup", UDim2.new(0, 1240, 0, 700), UDim2.new(0.025, 0, 0.08, 0), {
		backgroundColor = squadStyle.backgroundColor,
		gradientStart = squadStyle.gradientStart,
		gradientEnd = squadStyle.gradientEnd,
		strokeColor = squadStyle.strokeColor,
		headerColor = squadStyle.headerColor,
		headerColorEnd = squadStyle.headerColorEnd,
		badgeText = squadStyle.badgeText,
		badgeColor = squadStyle.badgeColor,
		iconText = "SQD",
		visible = false,
	})
	local squadBadgeNode = squadPopup:FindFirstChild("Badge")
	if squadBadgeNode and squadBadgeNode:IsA("GuiObject") then
		squadBadgeNode.Visible = false
	end
	local squadEmblemNode = squadPopup:FindFirstChild("Emblem")
	if squadEmblemNode and squadEmblemNode:IsA("GuiObject") then
		squadEmblemNode.Visible = false
	end
	local squadHeaderRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(110, 160, 212),
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, 128),
		Size = UDim2.new(1, -60, 0, 2),
		Parent = squadPopup,
	})
	addCorner(squadHeaderRule, UDim.new(0, 4))
	local squadPopupAccent = new("Frame", {
		Name = "HeaderAccent",
		BackgroundColor3 = Color3.fromRGB(122, 176, 230),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, 92),
		Size = UDim2.new(0, 148, 0, 3),
		Parent = squadPopup,
	})
	addCorner(squadPopupAccent, UDim.new(0, 6))
	local squadLeftRail = new("Frame", {
		Name = "LeftRail",
		BackgroundColor3 = Color3.fromRGB(42, 56, 72),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 28, 0, 132),
		Size = UDim2.new(0, 224, 1, -160),
		Parent = squadPopup,
	})
	addCorner(squadLeftRail, UDim.new(0, 18))
	addStroke(squadLeftRail, Color3.fromRGB(122, 176, 230), 0.16, 1)
	local squadRailTitle = label(squadLeftRail, "RailTitle", "Command Actions", UDim2.new(0, 16, 0, 14), UDim2.new(1, -32, 0, 22), Theme.Fonts.Heading, Color3.fromRGB(236, 245, 255))
	setFixedText(squadRailTitle, 19)
	local squadRailBody = label(squadLeftRail, "RailBody", "Control the roster, lock privacy, and route survivors into the fireteam before deployment.", UDim2.new(0, 16, 0, 42), UDim2.new(1, -32, 0, 50), Theme.Fonts.Body, Color3.fromRGB(196, 218, 242))
	setFixedText(squadRailBody, 12)

	local squadCenterPane = new("Frame", {
		Name = "CenterPane",
		BackgroundColor3 = Color3.fromRGB(44, 58, 72),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 270, 0, 132),
		Size = UDim2.new(0, 292, 1, -160),
		Parent = squadPopup,
	})
	addCorner(squadCenterPane, UDim.new(0, 18))
	addStroke(squadCenterPane, Color3.fromRGB(110, 160, 212), 0.18, 1)

	local squadRightPane = new("Frame", {
		Name = "RightPane",
		BackgroundColor3 = Color3.fromRGB(34, 46, 58),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 580, 0, 132),
		Size = UDim2.new(1, -608, 1, -160),
		Parent = squadPopup,
	})
	addCorner(squadRightPane, UDim.new(0, 18))
	addStroke(squadRightPane, Color3.fromRGB(110, 160, 212), 0.16, 1)

	local squadTitle = label(squadPopup, "Title", "Fireteam Command", UDim2.new(0, 34, 0, 58), UDim2.new(1, -190, 0, 34), Theme.Fonts.Heading, Color3.fromRGB(244, 249, 255))
	setFixedText(squadTitle, 32)
	local squadTag = label(squadPopup, "Tag", "Assemble the team, assign the lead, and lock the roster before deployment.", UDim2.new(0, 34, 0, 94), UDim2.new(1, -220, 0, 22), Theme.Fonts.Body, Color3.fromRGB(214, 232, 249))
	setFixedText(squadTag, 15)
	local squadSummary = label(squadCenterPane, "Summary", "A fireteam can run solo or stack four deep. Bigger squads pull heavier pressure but better salvage.", UDim2.new(0, 18, 0, 20), UDim2.new(1, -36, 0, 56), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(squadSummary, 15)
	local squadReadinessCard = createInsetCard(squadCenterPane, "ReadinessCard", UDim2.new(0, 18, 0, 86), UDim2.new(1, -36, 0, 110), Color3.fromRGB(32, 43, 56), Color3.fromRGB(122, 176, 230))
	local readinessTitle = label(squadReadinessCard, "ReadinessTitle", "Fireteam State", UDim2.new(0, 14, 0, 12), UDim2.new(1, -28, 0, 22), Theme.Fonts.Heading, Color3.fromRGB(234, 242, 255))
	setFixedText(readinessTitle, 18)
	local readinessBody = label(squadReadinessCard, "ReadinessBody", "Keep the lead slot stable, stage the roster, and lock the team before the siren starts.", UDim2.new(0, 14, 0, 38), UDim2.new(1, -28, 0, 52), Theme.Fonts.Body, Color3.fromRGB(194, 216, 240))
	setFixedText(readinessBody, 14)
	local squadOpsCard = createInsetCard(squadCenterPane, "OpsCard", UDim2.new(0, 18, 0, 214), UDim2.new(1, -36, 0, 104), Color3.fromRGB(36, 48, 60), Color3.fromRGB(110, 160, 212))
	local squadOpsTitle = label(squadOpsCard, "OpsTitle", "Ops Status", UDim2.new(0, 14, 0, 12), UDim2.new(1, -28, 0, 20), Theme.Fonts.Heading, Color3.fromRGB(240, 246, 255))
	setFixedText(squadOpsTitle, 17)
	local squadOpsBody = label(squadOpsCard, "OpsBody", "Invite survivors, switch public or private, and keep solo fallback ready.", UDim2.new(0, 14, 0, 36), UDim2.new(1, -28, 0, 48), Theme.Fonts.Body, Color3.fromRGB(190, 211, 234))
	setFixedText(squadOpsBody, 13)
	local squadBriefCard = createInsetCard(squadCenterPane, "BriefCard", UDim2.new(0, 18, 0, 332), UDim2.new(1, -36, 1, -350), Color3.fromRGB(28, 38, 48), Color3.fromRGB(102, 154, 208))
	local squadBriefTitle = label(squadBriefCard, "BriefTitle", "Command Brief", UDim2.new(0, 14, 0, 10), UDim2.new(1, -28, 0, 20), Theme.Fonts.Heading, Color3.fromRGB(240, 246, 255))
	setFixedText(squadBriefTitle, 16)
	local squadBriefBody = label(squadBriefCard, "BriefBody", "Small squads move clean. Full squads pull harder waves, tougher infected, and richer payouts.", UDim2.new(0, 14, 0, 32), UDim2.new(1, -28, 0, 28), Theme.Fonts.Body, Color3.fromRGB(190, 211, 234))
	setFixedText(squadBriefBody, 13)
	local squadRosterBadge = new("TextLabel", {
		Name = "RosterBadge",
		BackgroundColor3 = Color3.fromRGB(54, 70, 88),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 20, 0, 20),
		Size = UDim2.new(0, 126, 0, 28),
		Text = "LIVE ROSTER",
		TextColor3 = Color3.fromRGB(234, 242, 255),
		TextScaled = false,
		TextSize = 13,
		Font = Theme.Fonts.Heading,
		Parent = squadRightPane,
	})
	addCorner(squadRosterBadge, UDim.new(0, 10))
	addStroke(squadRosterBadge, Color3.fromRGB(122, 176, 230), 0.12, 1)
	local squadSlotsHeader = label(squadRightPane, "SlotsHeader", "Fireteam Roster", UDim2.new(0, 20, 0, 58), UDim2.new(1, -40, 0, 26), Theme.Fonts.Heading, Color3.fromRGB(242, 247, 255))
	setFixedText(squadSlotsHeader, 27)
	local squadSlotsSub = label(squadRightPane, "SlotsSub", "Roster slots, lead control, and open seats stay visible here during staging.", UDim2.new(0, 20, 0, 92), UDim2.new(1, -40, 0, 34), Theme.Fonts.Body, Color3.fromRGB(184, 208, 236))
	setFixedText(squadSlotsSub, 14)
	local squadSlots = {}
	for slot = 1, Theme.SquadLimit do
		local slotCard = new("Frame", {
			Name = "SlotCard" .. slot,
			BackgroundColor3 = Color3.fromRGB(34, 46, 58),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 20, 0, 144 + ((slot - 1) * 92)),
			Size = UDim2.new(1, -40, 0, 74),
			Parent = squadRightPane,
		})
		addCorner(slotCard, UDim.new(0, 10))
		addStroke(slotCard, squadStyle.strokeColor, 0.2, 1)

		local slotAccent = new("Frame", {
			Name = "Accent",
			BackgroundColor3 = squadStyle.headerColor,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 12, 0, 12),
			Size = UDim2.new(0, 4, 1, -24),
			Parent = slotCard,
		})
		addCorner(slotAccent, UDim.new(0, 4))

		local slotBadge = new("TextLabel", {
			Name = "Badge",
			BackgroundColor3 = Color3.fromRGB(54, 70, 88),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 24, 0, 12),
			Size = UDim2.new(0, 62, 0, 20),
			Text = ("SLOT %d"):format(slot),
			TextColor3 = Color3.fromRGB(228, 238, 255),
			TextScaled = false,
			TextSize = 10,
			Font = Theme.Fonts.Heading,
			Parent = slotCard,
		})
		addCorner(slotBadge, UDim.new(0, 8))

		local slotLabel = new("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 24, 0, 34),
			Size = UDim2.new(1, -56, 0, 22),
			Text = "Slot " .. slot,
			TextColor3 = Theme.Colors.Text,
			TextScaled = false,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Theme.Fonts.Heading,
			Parent = slotCard,
		})

		local slotHint = new("TextLabel", {
			Name = "Hint",
			BackgroundTransparency = 1,
			Position = UDim2.new(1, -144, 0, 14),
			Size = UDim2.new(0, 122, 0, 16),
			Text = slot == 1 and "Lead slot" or "Open slot",
			TextColor3 = Color3.fromRGB(182, 205, 232),
			TextScaled = false,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Theme.Fonts.Body,
			Parent = slotCard,
		})

		squadSlots[slot] = slotLabel
	end
	local refreshSquadsButton = createButton(squadLeftRail, "RefreshSquadsButton", "Refresh Squad Board", UDim2.new(1, -32, 0, 46), UDim2.new(0, 16, 0, 122), Theme.Colors.AccentWarm)
	refreshSquadsButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(refreshSquadsButton, 18, Enum.TextXAlignment.Center)
	refreshSquadsButton.Position = UDim2.new(0, 16, 1, -214)
	local inviteSquadButton = createButton(squadLeftRail, "InviteSquadButton", "Invite Survivors", UDim2.new(1, -32, 0, 46), UDim2.new(0, 16, 1, -160), Theme.Colors.AccentWarm)
	inviteSquadButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(inviteSquadButton, 18, Enum.TextXAlignment.Center)
	local privacySquadButton = createButton(squadLeftRail, "PrivacySquadButton", "Private Squad: Off", UDim2.new(1, -32, 0, 46), UDim2.new(0, 16, 1, -106), Theme.Colors.Backdrop)
	privacySquadButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(privacySquadButton, 18, Enum.TextXAlignment.Center)
	local leaveSquadButton = createButton(squadLeftRail, "LeaveSquadButton", "Return To Solo", UDim2.new(1, -32, 0, 46), UDim2.new(0, 16, 1, -52), Theme.Colors.Accent)
	leaveSquadButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(leaveSquadButton, 18, Enum.TextXAlignment.Center)
	local squadRailFooter = label(squadLeftRail, "RailFooter", "Use the left rail for actions, the center for command status, and the right board for the live roster.", UDim2.new(0, 16, 1, -290), UDim2.new(1, -32, 0, 48), Theme.Fonts.Body, Color3.fromRGB(196, 218, 242))
	setFixedText(squadRailFooter, 11)
	local closeSquadButton = createButton(squadPopup, "CloseSquadButton", "Close", UDim2.new(0, 122, 0, 44), UDim2.new(1, -28, 0, 56), Theme.Colors.Backdrop)
	closeSquadButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(closeSquadButton, 19, Enum.TextXAlignment.Center)
	lobbyRefs.Popups.Squad = squadPopup
	lobbyRefs.SquadSlots = squadSlots
	lobbyRefs.SquadSummary = squadSummary
	lobbyRefs.RefreshSquadsButton = refreshSquadsButton
	lobbyRefs.InviteSquadButton = inviteSquadButton
	lobbyRefs.PrivacySquadButton = privacySquadButton
	lobbyRefs.LeaveSquadButton = leaveSquadButton
	lobbyRefs.CloseSquadButton = closeSquadButton
	end

	do
	local socialPopup = createPopup(lobby, "SocialPopup", UDim2.new(0, 1240, 0, 700), UDim2.new(0.025, 0, 0.08, 0), {
		backgroundColor = socialStyle.backgroundColor,
		gradientStart = socialStyle.gradientStart,
		gradientEnd = socialStyle.gradientEnd,
		strokeColor = socialStyle.strokeColor,
		headerColor = socialStyle.headerColor,
		headerColorEnd = socialStyle.headerColorEnd,
		badgeText = socialStyle.badgeText,
		badgeColor = socialStyle.badgeColor,
		iconText = "SOC",
		visible = false,
	})
	local socialBadgeNode = socialPopup:FindFirstChild("Badge")
	if socialBadgeNode and socialBadgeNode:IsA("GuiObject") then
		socialBadgeNode.Visible = false
	end
	local socialEmblemNode = socialPopup:FindFirstChild("Emblem")
	if socialEmblemNode and socialEmblemNode:IsA("GuiObject") then
		socialEmblemNode.Visible = false
	end
	local socialHeaderRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(100, 184, 164),
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, 128),
		Size = UDim2.new(1, -60, 0, 2),
		Parent = socialPopup,
	})
	addCorner(socialHeaderRule, UDim.new(0, 4))
	local socialPopupAccent = new("Frame", {
		Name = "HeaderAccent",
		BackgroundColor3 = Color3.fromRGB(100, 184, 164),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, 92),
		Size = UDim2.new(0, 148, 0, 3),
		Parent = socialPopup,
	})
	addCorner(socialPopupAccent, UDim.new(0, 6))
	local socialLeftRail = new("Frame", {
		Name = "LeftRail",
		BackgroundColor3 = Color3.fromRGB(34, 58, 52),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 28, 0, 132),
		Size = UDim2.new(0, 224, 1, -160),
		Parent = socialPopup,
	})
	addCorner(socialLeftRail, UDim.new(0, 18))
	addStroke(socialLeftRail, Color3.fromRGB(100, 184, 164), 0.16, 1)
	local socialRailTitle = label(socialLeftRail, "RailTitle", "Comms Routing", UDim2.new(0, 16, 0, 14), UDim2.new(1, -32, 0, 22), Theme.Fonts.Heading, Color3.fromRGB(236, 250, 245))
	setFixedText(socialRailTitle, 19)
	local socialRailBody = label(socialLeftRail, "RailBody", "Track open squads, watch online survivors, and route invites through the comms board.", UDim2.new(0, 16, 0, 42), UDim2.new(1, -32, 0, 50), Theme.Fonts.Body, Color3.fromRGB(184, 226, 214))
	setFixedText(socialRailBody, 12)

	local socialCenterPane = new("Frame", {
		Name = "CenterPane",
		BackgroundColor3 = Color3.fromRGB(34, 54, 48),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 270, 0, 132),
		Size = UDim2.new(0, 292, 1, -160),
		Parent = socialPopup,
	})
	addCorner(socialCenterPane, UDim.new(0, 18))
	addStroke(socialCenterPane, Color3.fromRGB(100, 184, 164), 0.18, 1)

	local socialRightPane = new("Frame", {
		Name = "RightPane",
		BackgroundColor3 = Color3.fromRGB(28, 46, 42),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 580, 0, 132),
		Size = UDim2.new(1, -608, 1, -160),
		Parent = socialPopup,
	})
	addCorner(socialRightPane, UDim.new(0, 18))
	addStroke(socialRightPane, Color3.fromRGB(88, 174, 154), 0.16, 1)

	local socialTitle = label(socialPopup, "Title", "Comms Lounge", UDim2.new(0, 34, 0, 58), UDim2.new(1, -190, 0, 34), Theme.Fonts.Heading, Color3.fromRGB(241, 251, 247))
	setFixedText(socialTitle, 32)
	local socialBody = label(socialPopup, "Body", "Watch the public board, find online survivors, and jump into an open squad before the next cycle.", UDim2.new(0, 34, 0, 94), UDim2.new(1, -220, 0, 22), Theme.Fonts.Body, Color3.fromRGB(173, 227, 214))
	setFixedText(socialBody, 15)
	local socialRailCopy = label(socialCenterPane, "RailCopy", "This board tracks open bunker squads and lets solo survivors jump into active teams fast.", UDim2.new(0, 18, 0, 20), UDim2.new(1, -36, 0, 56), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(socialRailCopy, 15)
	local socialBulletin = createInsetCard(socialCenterPane, "Bulletin", UDim2.new(0, 18, 0, 88), UDim2.new(1, -36, 0, 132), Color3.fromRGB(24, 44, 40), Color3.fromRGB(88, 174, 154))
	local bulletinTitle = label(socialBulletin, "BulletinTitle", "Community Board", UDim2.new(0, 14, 0, 12), UDim2.new(1, -28, 0, 20), Theme.Fonts.Heading, Color3.fromRGB(233, 248, 243))
	setFixedText(bulletinTitle, 17)
	local bulletinBody = label(socialBulletin, "BulletinBody", "This room is for quick team pickup, public runs, and bunker chatter before deployment.", UDim2.new(0, 14, 0, 38), UDim2.new(1, -28, 0, 56), Theme.Fonts.Body, Color3.fromRGB(176, 226, 214))
	setFixedText(bulletinBody, 14)
	local bulletinTag = label(socialBulletin, "BulletinTag", "Open squads rotate live during the session.", UDim2.new(0, 14, 1, -28), UDim2.new(1, -28, 0, 18), Theme.Fonts.Body, Color3.fromRGB(134, 200, 182))
	setFixedText(bulletinTag, 12)
	local inviteRosterTitle = label(socialCenterPane, "InviteRosterTitle", "Online Survivors", UDim2.new(0, 18, 0, 238), UDim2.new(1, -36, 0, 24), Theme.Fonts.Heading, Color3.fromRGB(236, 249, 244))
	setFixedText(inviteRosterTitle, 18)
	local invitePlayerList = createListFrame(socialCenterPane, "InvitePlayerList", UDim2.new(0, 18, 0, 270), UDim2.new(1, -36, 1, -288))
	invitePlayerList.BackgroundColor3 = Color3.fromRGB(23, 33, 30)
	local invitePlayerEmpty = label(socialCenterPane, "InvitePlayerEmpty", "No invite targets visible right now.", UDim2.new(0, 24, 0, 282), UDim2.new(1, -48, 0, 24), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Center)
	setFixedText(invitePlayerEmpty, 13, Enum.TextXAlignment.Center)
	invitePlayerEmpty.Visible = false
	local socialBoardBadge = new("TextLabel", {
		Name = "BoardBadge",
		BackgroundColor3 = Color3.fromRGB(42, 66, 60),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 20, 0, 20),
		Size = UDim2.new(0, 134, 0, 28),
		Text = "PUBLIC BOARD",
		TextColor3 = Color3.fromRGB(236, 249, 244),
		TextScaled = false,
		TextSize = 13,
		Font = Theme.Fonts.Heading,
		Parent = socialRightPane,
	})
	addCorner(socialBoardBadge, UDim.new(0, 10))
	addStroke(socialBoardBadge, Color3.fromRGB(100, 184, 164), 0.12, 1)
	local socialDirectoryTitle = label(socialRightPane, "DirectoryTitle", "Open Squad Directory", UDim2.new(0, 20, 0, 58), UDim2.new(1, -40, 0, 26), Theme.Fonts.Heading, Color3.fromRGB(240, 252, 247))
	setFixedText(socialDirectoryTitle, 27)
	local socialDirectorySub = label(socialRightPane, "DirectorySub", "Browse public teams, check open slots, and join survivors already staging for the breach.", UDim2.new(0, 20, 0, 92), UDim2.new(1, -40, 0, 34), Theme.Fonts.Body, Color3.fromRGB(180, 232, 220))
	setFixedText(socialDirectorySub, 14)
	local squadDirectoryList = createListFrame(socialRightPane, "SquadDirectory", UDim2.new(0, 20, 0, 144), UDim2.new(1, -40, 1, -166))
	squadDirectoryList.BackgroundColor3 = Color3.fromRGB(23, 33, 30)
	local squadDirectoryEmpty = label(socialRightPane, "DirectoryEmpty", "No public squads are posting to the board yet.", UDim2.new(0, 24, 0, 156), UDim2.new(1, -48, 0, 24), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Center)
	setFixedText(squadDirectoryEmpty, 15, Enum.TextXAlignment.Center)
	squadDirectoryEmpty.Visible = false
	local refreshBoardButton = createButton(socialLeftRail, "RefreshBoardButton", "Refresh Board", UDim2.new(1, -32, 0, 46), UDim2.new(0, 16, 1, -56), Theme.Colors.AccentWarm)
	refreshBoardButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(refreshBoardButton, 18, Enum.TextXAlignment.Center)
	local socialRailFooter = label(socialLeftRail, "RailFooter", "Use the left rail for actions, the center for survivors, and the right board for the live public feed.", UDim2.new(0, 16, 1, -118), UDim2.new(1, -32, 0, 48), Theme.Fonts.Body, Color3.fromRGB(184, 226, 214))
	setFixedText(socialRailFooter, 11)
	local closeSocialButton = createButton(socialPopup, "CloseSocialButton", "Close", UDim2.new(0, 122, 0, 44), UDim2.new(1, -28, 0, 56), Theme.Colors.Backdrop)
	closeSocialButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(closeSocialButton, 19, Enum.TextXAlignment.Center)
	lobbyRefs.Popups.Social = socialPopup
	lobbyRefs.SquadDirectoryList = squadDirectoryList
	lobbyRefs.SquadDirectoryEmpty = squadDirectoryEmpty
	lobbyRefs.InvitePlayerList = invitePlayerList
	lobbyRefs.InvitePlayerEmpty = invitePlayerEmpty
	lobbyRefs.RefreshBoardButton = refreshBoardButton
	lobbyRefs.CloseSocialButton = closeSocialButton
	lobbyRefs.SocialBody = socialBody

	local invitePopup = createPopup(lobby, "InvitePopup", UDim2.new(0, 460, 0, 240), UDim2.new(0.58, 0, 0.13, 0), {
		backgroundColor = Color3.fromRGB(42, 54, 66),
		gradientStart = Color3.fromRGB(52, 66, 80),
		gradientEnd = Color3.fromRGB(30, 40, 50),
		strokeColor = Color3.fromRGB(118, 170, 224),
		headerColor = Color3.fromRGB(86, 136, 194),
		headerColorEnd = Color3.fromRGB(48, 78, 114),
		badgeText = "INVITE",
		badgeColor = Color3.fromRGB(56, 86, 112),
		iconText = "INV",
		visible = false,
	})
	local inviteTitle = label(invitePopup, "Title", "Fireteam Invite", UDim2.new(0, 24, 0, 62), UDim2.new(1, -48, 0, 28), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(inviteTitle, 24)
	local inviteBody = label(invitePopup, "Body", "An online survivor invited you to join their fireteam.", UDim2.new(0, 24, 0, 100), UDim2.new(1, -48, 0, 54), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(inviteBody, 16)
	local inviteAccept = createButton(invitePopup, "AcceptInviteButton", "Accept", UDim2.new(0, 150, 0, 42), UDim2.new(0, 24, 1, -58), Theme.Colors.Accent)
	inviteAccept.AnchorPoint = Vector2.new(0, 0)
	setFixedText(inviteAccept, 18, Enum.TextXAlignment.Center)
	local inviteDecline = createButton(invitePopup, "DeclineInviteButton", "Decline", UDim2.new(0, 150, 0, 42), UDim2.new(0, 186, 1, -58), Theme.Colors.Backdrop)
	inviteDecline.AnchorPoint = Vector2.new(0, 0)
	setFixedText(inviteDecline, 18, Enum.TextXAlignment.Center)
	lobbyRefs.InvitePopup = invitePopup
	lobbyRefs.InviteTitle = inviteTitle
	lobbyRefs.InviteBody = inviteBody
	lobbyRefs.AcceptInviteButton = inviteAccept
	lobbyRefs.DeclineInviteButton = inviteDecline
	end

	do
	local shopPopup = createPopup(lobby, "ShopPopup", UDim2.new(0, 1140, 0, 650), UDim2.new(0.05, 0, 0.09, 0), {
		backgroundColor = Color3.fromRGB(28, 34, 42),
		gradientStart = Color3.fromRGB(42, 50, 62),
		gradientEnd = Color3.fromRGB(18, 24, 32),
		strokeColor = Color3.fromRGB(112, 132, 156),
		headerColor = Color3.fromRGB(74, 98, 132),
		headerColorEnd = Color3.fromRGB(48, 64, 88),
		badgeText = "STOCK",
		badgeColor = Color3.fromRGB(56, 76, 104),
		iconText = "QTR",
		visible = false,
	})
	local shopBadgeNode = shopPopup:FindFirstChild("Badge")
	if shopBadgeNode and shopBadgeNode:IsA("GuiObject") then
		shopBadgeNode.Visible = false
	end
	local shopEmblemNode = shopPopup:FindFirstChild("Emblem")
	if shopEmblemNode and shopEmblemNode:IsA("GuiObject") then
		shopEmblemNode.Visible = false
	end
	local shopHeaderRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(112, 162, 214),
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 28, 0, 104),
		Size = UDim2.new(1, -60, 0, 2),
		Parent = shopPopup,
	})
	addCorner(shopHeaderRule, UDim.new(0, 4))
	local shopPopupAccent = new("Frame", {
		Name = "HeaderAccent",
		BackgroundColor3 = Color3.fromRGB(112, 162, 214),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 28, 0, 76),
		Size = UDim2.new(0, 148, 0, 3),
		Parent = shopPopup,
	})
	addCorner(shopPopupAccent, UDim.new(0, 6))
	local leftRail = new("Frame", {
		Name = "LeftRail",
		BackgroundColor3 = Color3.fromRGB(34, 42, 52),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 24, 0, 118),
		Size = UDim2.new(0, 196, 1, -142),
		Parent = shopPopup,
	})
	addCorner(leftRail, UDim.new(0, 18))
	addStroke(leftRail, Color3.fromRGB(112, 162, 214), 0.16, 1)
	local leftRailTitle = label(leftRail, "RailTitle", "Quartermaster", UDim2.new(0, 16, 0, 14), UDim2.new(1, -32, 0, 22), Theme.Fonts.Heading, Color3.fromRGB(236, 244, 255))
	setFixedText(leftRailTitle, 19)
	local leftRailBody = label(leftRail, "RailBody", "Pick a stock lane, claim your daily crate, and keep one clean catalog in view.", UDim2.new(0, 16, 0, 42), UDim2.new(1, -32, 0, 46), Theme.Fonts.Body, Color3.fromRGB(182, 202, 224))
	setFixedText(leftRailBody, 12)

	local centerPane = new("Frame", {
		Name = "CenterPane",
		BackgroundColor3 = Color3.fromRGB(36, 46, 58),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 234, 0, 118),
		Size = UDim2.new(0, 256, 1, -142),
		Parent = shopPopup,
	})
	addCorner(centerPane, UDim.new(0, 18))
	addStroke(centerPane, Color3.fromRGB(112, 162, 214), 0.18, 1)

	local rightPane = new("Frame", {
		Name = "RightPane",
		BackgroundColor3 = Color3.fromRGB(40, 50, 62),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 504, 0, 118),
		Size = UDim2.new(1, -528, 1, -142),
		Parent = shopPopup,
	})
	addCorner(rightPane, UDim.new(0, 18))
	addStroke(rightPane, Color3.fromRGB(112, 162, 214), 0.16, 1)

	local shopTitle = label(shopPopup, "Title", "Quartermaster Board", UDim2.new(0, 32, 0, 52), UDim2.new(1, -190, 0, 28), Theme.Fonts.Heading, Color3.fromRGB(236, 244, 255))
	setFixedText(shopTitle, 28)
	local shopTag = label(shopPopup, "Tag", "Buy new stock here. Owned weapons and cosmetics belong to the locker, not the market feed.", UDim2.new(0, 32, 0, 84), UDim2.new(1, -220, 0, 18), Theme.Fonts.Body, Color3.fromRGB(180, 202, 224))
	setFixedText(shopTag, 13)
	local rewardCard = createInsetCard(centerPane, "RewardCard", UDim2.new(0, 14, 0, 14), UDim2.new(1, -28, 0, 74), Color3.fromRGB(30, 40, 50), Color3.fromRGB(112, 162, 214))
	local dailyRewardStatus = label(rewardCard, "DailyRewardStatus", "Daily reward ready.", UDim2.new(0, 14, 0, 32), UDim2.new(1, -28, 0, 26), Theme.Fonts.Body, Color3.fromRGB(220, 239, 164))
	setFixedText(dailyRewardStatus, 15)
	local rewardTitle = label(rewardCard, "RewardTitle", "Daily Quartermaster", UDim2.new(0, 14, 0, 14), UDim2.new(1, -54, 0, 20), Theme.Fonts.Heading, Color3.fromRGB(236, 244, 255))
	setFixedText(rewardTitle, 18)
	local claimDailyButton = createButton(rewardCard, "ClaimDailyButton", "Claim Daily", UDim2.new(1, -28, 0, 30), UDim2.new(0, 14, 0, 42), Color3.fromRGB(96, 152, 104))
	claimDailyButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(claimDailyButton, 15, Enum.TextXAlignment.Center)
	local loadoutCard = createInsetCard(centerPane, "LoadoutCard", UDim2.new(0, 14, 0, 96), UDim2.new(1, -28, 0, 108), Color3.fromRGB(30, 40, 50), Color3.fromRGB(112, 162, 214))
	local loadoutTitle = label(loadoutCard, "LoadoutTitle", "Active Loadout", UDim2.new(0, 14, 0, 14), UDim2.new(1, -54, 0, 20), Theme.Fonts.Heading, Color3.fromRGB(236, 244, 255))
	setFixedText(loadoutTitle, 18)
	local loadoutSummary = label(loadoutCard, "LoadoutSummary", "Weapon: Training Blade | Cosmetic: None", UDim2.new(0, 14, 0, 36), UDim2.new(1, -28, 0, 30), Theme.Fonts.Heading, Color3.fromRGB(236, 244, 255))
	setFixedText(loadoutSummary, 13)
	local statsSummary = label(loadoutCard, "StatsSummary", "Missions: 0 | Kills: 0", UDim2.new(0, 14, 0, 70), UDim2.new(1, -28, 0, 16), Theme.Fonts.Body, Color3.fromRGB(182, 202, 224))
	setFixedText(statsSummary, 12)
	local skillSummary = label(loadoutCard, "SkillSummary", "Bunker Level 1 | 0 skill points ready", UDim2.new(0, 14, 0, 88), UDim2.new(1, -28, 0, 16), Theme.Fonts.Body, Color3.fromRGB(144, 202, 160))
	setFixedText(skillSummary, 12)
	local previewCard = createInsetCard(centerPane, "PreviewCard", UDim2.new(0, 14, 0, 214), UDim2.new(1, -28, 1, -228), Color3.fromRGB(30, 40, 50), Color3.fromRGB(112, 162, 214))
	local previewTitle = label(previewCard, "PreviewTitle", "Weapon Preview", UDim2.new(0, 14, 0, 14), UDim2.new(1, -28, 0, 20), Theme.Fonts.Heading, Color3.fromRGB(236, 244, 255))
	setFixedText(previewTitle, 17)
	local previewBody = label(previewCard, "PreviewBody", "Selected stock appears here with live bunker weapon stats and cosmetic preview.", UDim2.new(0, 14, 0, 38), UDim2.new(1, -28, 0, 28), Theme.Fonts.Body, Color3.fromRGB(182, 202, 224))
	setFixedText(previewBody, 11)
	local previewViewport = new("ViewportFrame", {
		Name = "PreviewViewport",
		BackgroundColor3 = Color3.fromRGB(20, 26, 34),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 14, 0, 72),
		Size = UDim2.new(1, -28, 0, 126),
		Parent = previewCard,
	})
	addCorner(previewViewport, UDim.new(0, 16))
	addStroke(previewViewport, Color3.fromRGB(112, 162, 214), 0.14, 1)
	local previewStats = label(previewCard, "PreviewStats", "DMG -- | RNG -- | RATE -- | AMMO --", UDim2.new(0, 14, 0, 204), UDim2.new(1, -28, 0, 28), Theme.Fonts.Heading, Color3.fromRGB(236, 216, 154))
	setFixedText(previewStats, 11)
	local previewCosmetic = label(previewCard, "PreviewCosmetic", "Preview Cosmetic: None", UDim2.new(0, 14, 0, 236), UDim2.new(1, -28, 0, 18), Theme.Fonts.Body, Color3.fromRGB(144, 202, 160))
	setFixedText(previewCosmetic, 11)
	local previewCompareTitle = label(previewCard, "PreviewCompareTitle", "Compared To Equipped", UDim2.new(0, 14, 0, 262), UDim2.new(1, -28, 0, 16), Theme.Fonts.Heading, Color3.fromRGB(168, 198, 236))
	setFixedText(previewCompareTitle, 10)
	local previewCompareRows = {}
	local compareDefinitions = {
		{ key = "Damage", title = "Damage", color = Color3.fromRGB(236, 122, 98) },
		{ key = "Range", title = "Range", color = Color3.fromRGB(112, 182, 244) },
		{ key = "Rate", title = "Speed", color = Color3.fromRGB(236, 196, 112) },
		{ key = "Ammo", title = "Ammo", color = Color3.fromRGB(144, 208, 152) },
	}
	for index, definition in ipairs(compareDefinitions) do
		local y = 282 + ((index - 1) * 20)
		local row = new("Frame", {
			Name = definition.key .. "CompareRow",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 14, 0, y),
			Size = UDim2.new(1, -28, 0, 18),
			Parent = previewCard,
		})
		local rowLabel = label(row, "Label", definition.title, UDim2.new(0, 0, 0, 0), UDim2.new(0, 48, 1, 0), Theme.Fonts.Body, Color3.fromRGB(192, 210, 228))
		setFixedText(rowLabel, 10)
		local barBack = new("Frame", {
			Name = "BarBack",
			BackgroundColor3 = Color3.fromRGB(26, 34, 42),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 54, 0.5, -4),
			Size = UDim2.new(1, -144, 0, 8),
			Parent = row,
		})
		addCorner(barBack, UDim.new(0, 6))
		local barFill = new("Frame", {
			Name = "BarFill",
			BackgroundColor3 = definition.color,
			BorderSizePixel = 0,
			Size = UDim2.new(0.5, 0, 1, 0),
			Parent = barBack,
		})
		addCorner(barFill, UDim.new(0, 6))
		local rowDelta = label(row, "Delta", "=", UDim2.new(1, -72, 0, 0), UDim2.new(0, 22, 1, 0), Theme.Fonts.Heading, Color3.fromRGB(236, 244, 255))
		setFixedText(rowDelta, 11)
		local rowValue = label(row, "Value", "--", UDim2.new(1, -48, 0, 0), UDim2.new(0, 48, 1, 0), Theme.Fonts.Body, Color3.fromRGB(192, 210, 228))
		setFixedText(rowValue, 10)
		previewCompareRows[definition.key] = {
			BarFill = barFill,
			Delta = rowDelta,
			Value = rowValue,
		}
	end
	local previewHint = label(previewCard, "PreviewHint", "Hover a stock card to inspect the weapon build.", UDim2.new(0, 14, 1, -20), UDim2.new(1, -28, 0, 12), Theme.Fonts.Body, Color3.fromRGB(164, 186, 208))
	setFixedText(previewHint, 10)
	local inventoryBadge = new("TextLabel", {
		Name = "InventoryBadge",
		BackgroundColor3 = Color3.fromRGB(44, 58, 76),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 22, 0, 18),
		Size = UDim2.new(0, 136, 0, 28),
		Text = "QUARTERMASTER STOCK",
		TextColor3 = Color3.fromRGB(236, 244, 255),
		TextScaled = false,
		TextSize = 13,
		Font = Theme.Fonts.Heading,
		Parent = rightPane,
	})
	addCorner(inventoryBadge, UDim.new(0, 10))
	addStroke(inventoryBadge, Color3.fromRGB(112, 162, 214), 0.12, 1)
	local shopBody = label(rightPane, "Body", Theme.ShopCopy["Deploy Tokens"], UDim2.new(0, 20, 0, 50), UDim2.new(1, -40, 0, 34), Theme.Fonts.Body, Color3.fromRGB(182, 202, 224))
	setFixedText(shopBody, 14)
	local inventoryTitle = label(rightPane, "InventoryTitle", "Market Feed", UDim2.new(0, 20, 0, 92), UDim2.new(1, -40, 0, 22), Theme.Fonts.Heading, Color3.fromRGB(236, 244, 255))
	setFixedText(inventoryTitle, 21)
	local tabButtons = new("Frame", {
		Name = "TabButtons",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 106),
		Size = UDim2.new(1, -28, 1, -154),
		Parent = leftRail,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = tabButtons,
	})
	local shopTabs = {}
	for index, tabName in ipairs(Theme.ShopTabs) do
		local tabButton = new("TextButton", {
			Name = tabName:gsub("%s+", ""),
			BackgroundColor3 = Color3.fromRGB(34, 42, 52),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 40),
			Text = tabName,
			TextColor3 = Theme.Colors.Text,
			TextScaled = false,
			TextSize = 16,
			Font = Theme.Fonts.Heading,
			AutoButtonColor = false,
			LayoutOrder = index,
			Parent = tabButtons,
		})
		addCorner(tabButton, UDim.new(0, 12))
		addStroke(tabButton, Color3.fromRGB(112, 132, 156), 0.16, 1)
		shopTabs[tabName] = tabButton
	end
	local railFooter = label(leftRail, "RailFooter", "Buy fresh stock here. Use the locker for owned gear and cosmetic loadouts.", UDim2.new(0, 14, 1, -48), UDim2.new(1, -28, 0, 34), Theme.Fonts.Body, Color3.fromRGB(164, 186, 208))
	setFixedText(railFooter, 11)
	local shopStatus = label(rightPane, "Status", "Check the active lane, then buy stock or inspect state chips before you commit.", UDim2.new(0, 20, 0, 118), UDim2.new(1, -40, 0, 28), Theme.Fonts.Body, Color3.fromRGB(144, 202, 160))
	setFixedText(shopStatus, 13)
	local rarityFilterLabel = label(rightPane, "RarityFilterLabel", "RARITY FILTER", UDim2.new(0, 20, 0, 154), UDim2.new(1, -40, 0, 14), Theme.Fonts.Heading, Color3.fromRGB(144, 176, 214))
	setFixedText(rarityFilterLabel, 10)
	local shopRarityFilters = new("Frame", {
		Name = "RarityFilters",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 20, 0, 170),
		Size = UDim2.new(1, -40, 0, 26),
		Parent = rightPane,
	})
	local shopRarityButtons = {}
	for index, filterName in ipairs({ "All", "Common", "Uncommon", "Rare", "Epic", "Supporter" }) do
		local filterButton = createButton(shopRarityFilters, filterName .. "ShopRarityFilter", filterName, UDim2.new(0, 92, 0, 24), UDim2.new(0, (index - 1) * 98, 0, 0), Theme.Colors.Backdrop)
		filterButton.AnchorPoint = Vector2.new(0, 0)
		setFixedText(filterButton, 12, Enum.TextXAlignment.Center)
		shopRarityButtons[filterName] = filterButton
	end
	local shopPremiumFilters = new("Frame", {
		Name = "PremiumFilters",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 20, 0, 218),
		Size = UDim2.new(1, -40, 0, 26),
		Visible = false,
		Parent = rightPane,
	})
	local premiumFilterLabel = label(rightPane, "PremiumFilterLabel", "PREMIUM FILTER", UDim2.new(0, 20, 0, 202), UDim2.new(1, -40, 0, 14), Theme.Fonts.Heading, Color3.fromRGB(144, 176, 214))
	setFixedText(premiumFilterLabel, 10)
	premiumFilterLabel.Visible = false
	local shopPremiumButtons = {}
	for index, filterName in ipairs({ "All", "Packs", "Passes", "Supporter" }) do
		local filterButton = createButton(shopPremiumFilters, filterName .. "ShopPremiumFilter", filterName, UDim2.new(0, 102, 0, 24), UDim2.new(0, (index - 1) * 108, 0, 0), Theme.Colors.Backdrop)
		filterButton.AnchorPoint = Vector2.new(0, 0)
		setFixedText(filterButton, 12, Enum.TextXAlignment.Center)
		shopPremiumButtons[filterName] = filterButton
	end
	local shopItemsFrame = createListFrame(rightPane, "Items", UDim2.new(0, 20, 0, 254), UDim2.new(1, -40, 1, -274))
	shopItemsFrame.BackgroundColor3 = Color3.fromRGB(28, 36, 46)
	local shopEmptyLabel = label(rightPane, "Empty", "No stock matches the current lane and filter set.", UDim2.new(0, 24, 0, 232), UDim2.new(1, -48, 0, 22), Theme.Fonts.Body, Color3.fromRGB(255, 241, 220), Enum.TextXAlignment.Center)
	setFixedText(shopEmptyLabel, 14, Enum.TextXAlignment.Center)
	shopEmptyLabel.Visible = false
	local closeShopButton = createButton(shopPopup, "CloseShopButton", "Close Panel", UDim2.new(0, 124, 0, 40), UDim2.new(1, -24, 0, 48), Color3.fromRGB(52, 64, 80))
	closeShopButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(closeShopButton, 17, Enum.TextXAlignment.Center)
	lobbyRefs.Popups.Shop = shopPopup
	lobbyRefs.ShopBody = shopBody
	lobbyRefs.LoadoutSummary = loadoutSummary
	lobbyRefs.StatsSummary = statsSummary
	lobbyRefs.SkillSummary = skillSummary
	lobbyRefs.ShopStatus = shopStatus
	lobbyRefs.ShopRarityButtons = shopRarityButtons
	lobbyRefs.ShopPremiumFilters = shopPremiumFilters
	lobbyRefs.ShopPremiumButtons = shopPremiumButtons
	lobbyRefs.ShopPremiumFilterLabel = premiumFilterLabel
	lobbyRefs.ShopTabs = shopTabs
	lobbyRefs.ShopItemsFrame = shopItemsFrame
	lobbyRefs.ShopEmptyLabel = shopEmptyLabel
	lobbyRefs.CloseShopButton = closeShopButton
	lobbyRefs.ClaimDailyButton = claimDailyButton
	lobbyRefs.DailyRewardStatus = dailyRewardStatus
	lobbyRefs.ShopPreviewViewport = previewViewport
	lobbyRefs.ShopPreviewTitle = previewTitle
	lobbyRefs.ShopPreviewBody = previewBody
	lobbyRefs.ShopPreviewStats = previewStats
	lobbyRefs.ShopPreviewCosmetic = previewCosmetic
	lobbyRefs.ShopPreviewCompareRows = previewCompareRows
	lobbyRefs.ShopPreviewHint = previewHint
	end
	do
	local inventoryPopup = createPopup(lobby, "InventoryPopup", UDim2.new(0, 1020, 0, 610), UDim2.new(0.1, 0, 0.11, 0), {
		backgroundColor = Color3.fromRGB(50, 58, 78),
		gradientStart = Color3.fromRGB(66, 76, 98),
		gradientEnd = Color3.fromRGB(34, 42, 58),
		strokeColor = Color3.fromRGB(120, 148, 196),
		headerColor = Color3.fromRGB(84, 118, 174),
		headerColorEnd = Color3.fromRGB(50, 74, 108),
		badgeText = "LOADOUT",
		badgeColor = Color3.fromRGB(58, 82, 116),
		iconText = "INV",
		visible = false,
	})
	local inventoryBadgeNode = inventoryPopup:FindFirstChild("Badge")
	if inventoryBadgeNode and inventoryBadgeNode:IsA("GuiObject") then
		inventoryBadgeNode.Visible = false
	end
	local inventoryEmblemNode = inventoryPopup:FindFirstChild("Emblem")
	if inventoryEmblemNode and inventoryEmblemNode:IsA("GuiObject") then
		inventoryEmblemNode.Visible = false
	end
	local inventoryHeaderRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(120, 148, 196),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 24, 0, 104),
		Size = UDim2.new(1, -48, 0, 2),
		Parent = inventoryPopup,
	})
	addCorner(inventoryHeaderRule, UDim.new(0, 4))
	local inventoryAccent = new("Frame", {
		Name = "HeaderAccent",
		BackgroundColor3 = Color3.fromRGB(120, 148, 196),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 24, 0, 74),
		Size = UDim2.new(0, 156, 0, 4),
		Parent = inventoryPopup,
	})
	addCorner(inventoryAccent, UDim.new(0, 6))
	local inventoryLeftRail = new("Frame", {
		Name = "LeftRail",
		BackgroundColor3 = Color3.fromRGB(38, 46, 62),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 22, 0, 126),
		Size = UDim2.new(0, 244, 1, -148),
		Parent = inventoryPopup,
	})
	addCorner(inventoryLeftRail, UDim.new(0, 18))
	addStroke(inventoryLeftRail, Color3.fromRGB(120, 148, 196), 0.18, 1)
	local inventoryRightPane = new("Frame", {
		Name = "RightPane",
		BackgroundColor3 = Color3.fromRGB(30, 38, 52),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 282, 0, 126),
		Size = UDim2.new(1, -304, 1, -148),
		Parent = inventoryPopup,
	})
	addCorner(inventoryRightPane, UDim.new(0, 18))
	addStroke(inventoryRightPane, Color3.fromRGB(120, 148, 196), 0.22, 1)
	createStationMark(inventoryRightPane, "InventoryMark", "IV", "KIT", UDim2.new(1, -136, 0, 18), Color3.fromRGB(120, 148, 196))
	local inventoryPaneRule = new("Frame", {
		Name = "SectionRule",
		BackgroundColor3 = Color3.fromRGB(120, 148, 196),
		BackgroundTransparency = 0.68,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 18, 0, 44),
		Size = UDim2.new(1, -36, 0, 1),
		Parent = inventoryRightPane,
	})
	addCorner(inventoryPaneRule, UDim.new(0, 4))
	local inventoryTitle = label(inventoryPopup, "Title", "Locker Inventory", UDim2.new(0, 24, 0, 48), UDim2.new(1, -172, 0, 32), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(inventoryTitle, 29)
	local inventoryBody = label(inventoryPopup, "Body", "Review owned weapons and cosmetics, then swap your active bunker loadout without reopening the market.", UDim2.new(0, 24, 0, 82), UDim2.new(1, -200, 0, 28), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(inventoryBody, 15)
	local inventorySummaryCard = createInsetCard(inventoryLeftRail, "SummaryCard", UDim2.new(0, 16, 0, 16), UDim2.new(1, -32, 0, 154), Color3.fromRGB(42, 50, 66), Color3.fromRGB(120, 148, 196))
	local inventoryLoadoutSummary = label(inventorySummaryCard, "LoadoutSummary", "Weapon: Training Blade | Cosmetic: None", UDim2.new(0, 14, 0, 14), UDim2.new(1, -28, 0, 36), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(inventoryLoadoutSummary, 18)
	local inventoryWeaponStats = label(inventorySummaryCard, "WeaponStats", "Damage: -- | Range: -- | Rate: --", UDim2.new(0, 14, 0, 56), UDim2.new(1, -28, 0, 16), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	setFixedText(inventoryWeaponStats, 12)
	local inventoryWeaponXp = label(inventorySummaryCard, "WeaponXp", "Bunker XP: 0/100 | Weapon XP: not tracked", UDim2.new(0, 14, 0, 76), UDim2.new(1, -28, 0, 16), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(inventoryWeaponXp, 12)
	local inventoryBonusSummary = label(inventorySummaryCard, "BonusSummary", "Skill Bonus: none", UDim2.new(0, 14, 0, 98), UDim2.new(1, -28, 0, 24), Theme.Fonts.Body, Color3.fromRGB(214, 228, 255))
	setFixedText(inventoryBonusSummary, 12)
	local inventoryStatsSummary = label(inventorySummaryCard, "StatsSummary", "Missions: 0 | Kills: 0", UDim2.new(0, 14, 0, 124), UDim2.new(1, -28, 0, 16), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(inventoryStatsSummary, 12)
	local inventorySkillSummary = label(inventorySummaryCard, "SkillSummary", "Bunker Level 1 | 0 skill points ready", UDim2.new(0, 14, 0, 138), UDim2.new(1, -28, 0, 14), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	setFixedText(inventorySkillSummary, 12)
	local inventoryTabCard = createInsetCard(inventoryLeftRail, "TabCard", UDim2.new(0, 16, 0, 186), UDim2.new(1, -32, 0, 138), Color3.fromRGB(38, 46, 60), Color3.fromRGB(120, 148, 196))
	local inventoryTabTitle = label(inventoryTabCard, "Title", "Locker Sections", UDim2.new(0, 14, 0, 12), UDim2.new(1, -28, 0, 22), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(inventoryTabTitle, 17)
	local inventoryTabBody = label(inventoryTabCard, "Body", "Weapons change combat handling. Cosmetics change appearance. This panel only shows owned gear.", UDim2.new(0, 14, 0, 36), UDim2.new(1, -28, 0, 32), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(inventoryTabBody, 12)
	local inventoryWeaponTab = createButton(inventoryTabCard, "WeaponTab", "Weapons", UDim2.new(1, -28, 0, 38), UDim2.new(0, 14, 0, 80), Color3.fromRGB(92, 122, 176))
	inventoryWeaponTab.AnchorPoint = Vector2.new(0, 0)
	setFixedText(inventoryWeaponTab, 16, Enum.TextXAlignment.Center)
	local inventoryCosmeticTab = createButton(inventoryTabCard, "CosmeticTab", "Cosmetics", UDim2.new(1, -28, 0, 38), UDim2.new(0, 14, 0, 122), Theme.Colors.CommandBlue)
	inventoryCosmeticTab.AnchorPoint = Vector2.new(0, 0)
	setFixedText(inventoryCosmeticTab, 16, Enum.TextXAlignment.Center)
	local inventoryRailFooter = label(inventoryLeftRail, "RailFooter", "Locker Inventory only shows owned gear. Return to Quartermaster when you need new stock.", UDim2.new(0, 16, 1, -40), UDim2.new(1, -32, 0, 24), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(inventoryRailFooter, 11)
	local inventoryStatus = label(inventoryRightPane, "Status", "Owned gear appears here. Equip a weapon or cosmetic from the locker.", UDim2.new(0, 18, 0, 18), UDim2.new(1, -36, 0, 24), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	setFixedText(inventoryStatus, 13)
	local inventoryRarityLabel = label(inventoryRightPane, "RarityLabel", "RARITY", UDim2.new(0, 18, 0, 58), UDim2.new(1, -36, 0, 12), Theme.Fonts.Heading, Color3.fromRGB(170, 194, 228))
	setFixedText(inventoryRarityLabel, 9)
	local inventoryRarityFilters = new("Frame", {
		Name = "RarityFilters",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 18, 0, 74),
		Size = UDim2.new(1, -36, 0, 28),
		Parent = inventoryRightPane,
	})
	local inventoryRarityButtons = {}
	for index, filterName in ipairs({ "All", "Common", "Uncommon", "Rare", "Epic", "Supporter" }) do
		local filterButton = createButton(inventoryRarityFilters, filterName .. "InventoryRarityFilter", filterName, UDim2.new(0, 86, 0, 24), UDim2.new(0, (index - 1) * 92, 0, 0), Theme.Colors.Backdrop)
		filterButton.AnchorPoint = Vector2.new(0, 0)
		setFixedText(filterButton, 11, Enum.TextXAlignment.Center)
		inventoryRarityButtons[filterName] = filterButton
	end
	local inventoryTypeLabel = label(inventoryRightPane, "TypeLabel", "TYPE", UDim2.new(0, 18, 0, 94), UDim2.new(1, -36, 0, 12), Theme.Fonts.Heading, Color3.fromRGB(170, 194, 228))
	setFixedText(inventoryTypeLabel, 9)
	local inventoryTypeFilters = new("Frame", {
		Name = "TypeFilters",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 18, 0, 110),
		Size = UDim2.new(1, -36, 0, 28),
		Parent = inventoryRightPane,
	})
	local inventoryTypeButtons = {}
	for index, filterName in ipairs({ "All", "Melee", "Sidearm", "Primary", "CQB" }) do
		local filterButton = createButton(inventoryTypeFilters, filterName .. "InventoryTypeFilter", filterName, UDim2.new(0, 96, 0, 24), UDim2.new(0, (index - 1) * 102, 0, 0), Theme.Colors.Backdrop)
		filterButton.AnchorPoint = Vector2.new(0, 0)
		setFixedText(filterButton, 11, Enum.TextXAlignment.Center)
		inventoryTypeButtons[filterName] = filterButton
	end
	local inventorySortLabel = label(inventoryRightPane, "SortLabel", "SORT", UDim2.new(0, 18, 0, 130), UDim2.new(1, -36, 0, 12), Theme.Fonts.Heading, Color3.fromRGB(170, 194, 228))
	setFixedText(inventorySortLabel, 9)
	local inventorySortFilters = new("Frame", {
		Name = "SortFilters",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 18, 0, 146),
		Size = UDim2.new(1, -36, 0, 28),
		Parent = inventoryRightPane,
	})
	local inventorySortButtons = {}
	for index, filterName in ipairs({ "Rarity", "Power", "Name" }) do
		local filterButton = createButton(inventorySortFilters, filterName .. "InventorySortFilter", filterName, UDim2.new(0, 100, 0, 24), UDim2.new(0, (index - 1) * 106, 0, 0), Theme.Colors.Backdrop)
		filterButton.AnchorPoint = Vector2.new(0, 0)
		setFixedText(filterButton, 11, Enum.TextXAlignment.Center)
		inventorySortButtons[filterName] = filterButton
	end
	local inventoryItemsHeading = label(inventoryRightPane, "ItemsHeading", "LOCKER FEED", UDim2.new(0, 18, 0, 184), UDim2.new(1, -36, 0, 12), Theme.Fonts.Heading, Color3.fromRGB(170, 194, 228))
	setFixedText(inventoryItemsHeading, 9)
	local inventoryItemsFrame = createListFrame(inventoryRightPane, "Items", UDim2.new(0, 18, 0, 204), UDim2.new(1, -36, 1, -222))
	inventoryItemsFrame.BackgroundColor3 = Color3.fromRGB(24, 30, 40)
	local inventoryEmptyLabel = label(inventoryRightPane, "Empty", "Nothing owned in this locker section yet. Unlock more stock from the Quartermaster.", UDim2.new(0, 24, 0, 224), UDim2.new(1, -48, 0, 24), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Center)
	setFixedText(inventoryEmptyLabel, 15, Enum.TextXAlignment.Center)
	inventoryEmptyLabel.Visible = false
	local closeInventoryButton = createButton(inventoryPopup, "CloseInventoryButton", "Close Panel", UDim2.new(0, 124, 0, 40), UDim2.new(1, -24, 0, 44), Theme.Colors.Backdrop)
	closeInventoryButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(closeInventoryButton, 17, Enum.TextXAlignment.Center)
	lobbyRefs.Popups.Inventory = inventoryPopup
	lobbyRefs.InventoryPopup = inventoryPopup
	lobbyRefs.InventoryLoadoutSummary = inventoryLoadoutSummary
	lobbyRefs.InventoryWeaponStats = inventoryWeaponStats
	lobbyRefs.InventoryWeaponXp = inventoryWeaponXp
	lobbyRefs.InventoryBonusSummary = inventoryBonusSummary
	lobbyRefs.InventoryStatsSummary = inventoryStatsSummary
	lobbyRefs.InventorySkillSummary = inventorySkillSummary
	lobbyRefs.InventoryStatus = inventoryStatus
	lobbyRefs.InventoryRarityButtons = inventoryRarityButtons
	lobbyRefs.InventoryTypeButtons = inventoryTypeButtons
	lobbyRefs.InventorySortButtons = inventorySortButtons
	lobbyRefs.InventoryItemsFrame = inventoryItemsFrame
	lobbyRefs.InventoryEmptyLabel = inventoryEmptyLabel
	lobbyRefs.InventoryWeaponTab = inventoryWeaponTab
	lobbyRefs.InventoryCosmeticTab = inventoryCosmeticTab
	lobbyRefs.CloseInventoryButton = closeInventoryButton
	end

	do
	local skillTreePopup = createPopup(lobby, "SkillTreePopup", UDim2.new(0, 1160, 0, 662), UDim2.new(0.06, 0, 0.105, 0), {
		backgroundColor = Color3.fromRGB(24, 30, 38),
		gradientStart = Color3.fromRGB(38, 48, 62),
		gradientEnd = Color3.fromRGB(14, 20, 28),
		strokeColor = Color3.fromRGB(118, 146, 184),
		headerColor = Color3.fromRGB(72, 108, 156),
		headerColorEnd = Color3.fromRGB(42, 64, 92),
		badgeText = "SPECIALIZE",
		badgeColor = Color3.fromRGB(64, 86, 110),
		iconText = "SKL",
		visible = false,
	})
	local skillTreeBadgeNode = skillTreePopup:FindFirstChild("Badge")
	if skillTreeBadgeNode and skillTreeBadgeNode:IsA("GuiObject") then
		skillTreeBadgeNode.Visible = false
	end
	local skillTreeEmblemNode = skillTreePopup:FindFirstChild("Emblem")
	if skillTreeEmblemNode and skillTreeEmblemNode:IsA("GuiObject") then
		skillTreeEmblemNode.Visible = false
	end
	local skillTreeHeaderRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(118, 146, 184),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 24, 0, 104),
		Size = UDim2.new(1, -48, 0, 2),
		Parent = skillTreePopup,
	})
	addCorner(skillTreeHeaderRule, UDim.new(0, 4))
	local skillTreeAccent = new("Frame", {
		Name = "HeaderAccent",
		BackgroundColor3 = Color3.fromRGB(118, 146, 184),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 24, 0, 74),
		Size = UDim2.new(0, 156, 0, 4),
		Parent = skillTreePopup,
	})
	addCorner(skillTreeAccent, UDim.new(0, 6))
	local skillTreeLeftRail = new("Frame", {
		Name = "LeftRail",
		BackgroundColor3 = Color3.fromRGB(32, 40, 52),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 22, 0, 128),
		Size = UDim2.new(0, 212, 1, -150),
		Parent = skillTreePopup,
	})
	addCorner(skillTreeLeftRail, UDim.new(0, 18))
	addStroke(skillTreeLeftRail, Color3.fromRGB(118, 146, 184), 0.2, 1)
	local skillTreeRightPane = new("Frame", {
		Name = "RightPane",
		BackgroundColor3 = Color3.fromRGB(28, 36, 46),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 250, 0, 128),
		Size = UDim2.new(1, -272, 1, -150),
		Parent = skillTreePopup,
	})
	addCorner(skillTreeRightPane, UDim.new(0, 18))
	addStroke(skillTreeRightPane, Color3.fromRGB(118, 146, 184), 0.22, 1)
	createStationMark(skillTreeRightPane, "SkillMark", "SK", "TREE", UDim2.new(1, -136, 0, 18), Color3.fromRGB(118, 146, 184))
	local skillTreePaneSectionRule = new("Frame", {
		Name = "SectionRule",
		BackgroundColor3 = Color3.fromRGB(118, 146, 184),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 18, 0, 58),
		Size = UDim2.new(1, -36, 0, 1),
		Parent = skillTreeRightPane,
	})
	addCorner(skillTreePaneSectionRule, UDim.new(0, 4))
	local skillTreeTitle = label(skillTreePopup, "Title", "Bunker Skill Tree", UDim2.new(0, 24, 0, 48), UDim2.new(1, -172, 0, 32), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(skillTreeTitle, 29)
	local skillTreeBody = label(skillTreePopup, "Body", "Spend bunker points across Survivor, Combat, and Logistics. Filter branches, inspect a node, and commit upgrades from one dedicated progression board.", UDim2.new(0, 24, 0, 82), UDim2.new(1, -200, 0, 30), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(skillTreeBody, 15)
	local skillTreeSummaryCard = createInsetCard(skillTreeLeftRail, "SummaryCard", UDim2.new(0, 16, 0, 16), UDim2.new(1, -32, 0, 100), Color3.fromRGB(28, 36, 48), Color3.fromRGB(118, 146, 184))
	local skillTreeSummary = label(skillTreeSummaryCard, "Summary", "Level 1 | XP 0/100 | 0 points ready", UDim2.new(0, 14, 0, 12), UDim2.new(1, -28, 0, 40), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(skillTreeSummary, 17)
	local skillTreeBranchCopy = label(skillTreeSummaryCard, "BranchCopy", "Survivor keeps you alive. Combat sharpens pressure. Logistics boosts extraction and payout.", UDim2.new(0, 14, 0, 52), UDim2.new(1, -28, 0, 30), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(skillTreeBranchCopy, 11)
	local skillTreeStatusCard = createInsetCard(skillTreeLeftRail, "StatusCard", UDim2.new(0, 16, 0, 126), UDim2.new(1, -32, 0, 82), Color3.fromRGB(26, 34, 44), Color3.fromRGB(118, 146, 184))
	local skillTreeStatus = label(skillTreeStatusCard, "Status", "Allocate points to unlock deeper branch nodes.", UDim2.new(0, 14, 0, 12), UDim2.new(1, -28, 0, 38), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	setFixedText(skillTreeStatus, 14)
	local skillTreeRespecCopy = label(skillTreeStatusCard, "RespecCopy", "Respec refunds every spent point from current level progress.", UDim2.new(0, 14, 0, 48), UDim2.new(1, -28, 0, 18), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(skillTreeRespecCopy, 11)
	local respecSkillTreeButton = createButton(skillTreeLeftRail, "RespecSkillTreeButton", "Respec Tree", UDim2.new(1, -32, 0, 40), UDim2.new(0, 16, 0, 222), Color3.fromRGB(188, 150, 78))
	respecSkillTreeButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(respecSkillTreeButton, 16, Enum.TextXAlignment.Center)
	local skillTreeBranchGuide = createInsetCard(skillTreeLeftRail, "BranchGuide", UDim2.new(0, 16, 0, 276), UDim2.new(1, -32, 0, 108), Color3.fromRGB(26, 34, 44), Color3.fromRGB(118, 146, 184))
	local branchGuideTitle = label(skillTreeBranchGuide, "Title", "Branch Guide", UDim2.new(0, 14, 0, 12), UDim2.new(1, -28, 0, 22), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(branchGuideTitle, 17)
	for index, branchId in ipairs(Theme.SkillTreeBranchOrder) do
		local branch = Theme.SkillTreeBranches[branchId]
		if branch then
			local row = new("Frame", {
				Name = branchId .. "Row",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 14, 0, 34 + ((index - 1) * 22)),
				Size = UDim2.new(1, -28, 0, 18),
				Parent = skillTreeBranchGuide,
			})
			local chip = new("TextLabel", {
				Name = "Chip",
				BackgroundColor3 = branch.Color,
				BackgroundTransparency = 0.1,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(0, 18, 0, 18),
				Text = branch.Icon,
				TextColor3 = Theme.Colors.Text,
				TextScaled = false,
				TextSize = 9,
				Font = Theme.Fonts.Heading,
				Parent = row,
			})
			addCorner(chip, UDim.new(0, 6))
			addStroke(chip, branch.Color, 0.18, 1)
			local rowLabel = label(row, "Label", branch.ShortLabel or branch.DisplayName or branchId, UDim2.new(0, 28, 0, -1), UDim2.new(1, -28, 0, 18), Theme.Fonts.Body, Theme.Colors.Muted)
			setFixedText(rowLabel, 13)
		end
	end
	local skillTreeRailFooter = label(skillTreeLeftRail, "RailFooter", "Left rail for summary and reset. Right board for filters, graph, and selected-node detail.", UDim2.new(0, 16, 1, -34), UDim2.new(1, -32, 0, 18), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(skillTreeRailFooter, 10)
	local skillTreeListHeading = label(skillTreeRightPane, "ItemsHeading", "NODE GRID", UDim2.new(0, 18, 0, 100), UDim2.new(1, -36, 0, 12), Theme.Fonts.Heading, Color3.fromRGB(170, 194, 228))
	setFixedText(skillTreeListHeading, 9)
	local skillTreeList = createListFrame(skillTreeRightPane, "SkillTreeItems", UDim2.new(0, 18, 0, 118), UDim2.new(1, -36, 1, -218))
	skillTreeList.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
	skillTreeList.AutomaticCanvasSize = Enum.AutomaticSize.None
	local skillTreeEmpty = label(skillTreeRightPane, "Empty", "No skill nodes are available yet.", UDim2.new(0, 24, 0, 126), UDim2.new(1, -48, 0, 24), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Center)
	setFixedText(skillTreeEmpty, 15, Enum.TextXAlignment.Center)
	skillTreeEmpty.Visible = false
	local skillTreePaneTitle = label(skillTreeRightPane, "PaneTitle", "Branch Nodes", UDim2.new(0, 18, 0, 14), UDim2.new(1, -36, 0, 22), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(skillTreePaneTitle, 20)
	local skillTreePaneSub = label(skillTreeRightPane, "PaneSub", "Filter by branch to focus one lane, or keep all branches visible.", UDim2.new(0, 18, 0, 38), UDim2.new(1, -164, 0, 22), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(skillTreePaneSub, 13)
	local skillTreeFilterRow = new("Frame", {
		Name = "FilterRow",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 18, 0, 66),
		Size = UDim2.new(1, -36, 0, 28),
		Parent = skillTreeRightPane,
	})
	local skillTreeFilterButtons = {}
	local filterNames = { "All", "Survivor", "Combat", "Logistics" }
	for index, filterName in ipairs(filterNames) do
		local filterButton = createButton(skillTreeFilterRow, filterName .. "FilterButton", filterName, UDim2.new(0, 108, 0, 28), UDim2.new(0, (index - 1) * 114, 0, 0), Theme.Colors.Backdrop)
		filterButton.AnchorPoint = Vector2.new(0, 0)
		setFixedText(filterButton, 12, Enum.TextXAlignment.Center)
		skillTreeFilterButtons[filterName] = filterButton
	end
	local skillTreePaneRule = new("Frame", {
		Name = "PaneRule",
		BackgroundColor3 = Color3.fromRGB(118, 146, 184),
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 18, 0, 100),
		Size = UDim2.new(1, -36, 0, 1),
		Parent = skillTreeRightPane,
	})
	local skillTreeDetailCard = createInsetCard(skillTreeRightPane, "DetailCard", UDim2.new(0, 18, 1, -112), UDim2.new(1, -36, 0, 90), Color3.fromRGB(22, 30, 40), Color3.fromRGB(118, 146, 184))
	local skillTreeDetailTitle = label(skillTreeDetailCard, "Title", "Select a node", UDim2.new(0, 14, 0, 10), UDim2.new(1, -170, 0, 20), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(skillTreeDetailTitle, 17)
	local skillTreeDetailMeta = label(skillTreeDetailCard, "Meta", "Choose a skill card to inspect its branch, rank, and unlock path.", UDim2.new(0, 14, 0, 32), UDim2.new(1, -170, 0, 14), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	setFixedText(skillTreeDetailMeta, 11)
	local skillTreeDetailBody = label(skillTreeDetailCard, "Body", "Detailed skill information appears here.", UDim2.new(0, 14, 0, 50), UDim2.new(1, -170, 0, 24), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(skillTreeDetailBody, 11)
	local skillTreeDetailBonus = new("TextLabel", {
		Name = "Bonus",
		BackgroundColor3 = Color3.fromRGB(112, 84, 54),
		BorderSizePixel = 0,
		Position = UDim2.new(1, -156, 0, 12),
		Size = UDim2.new(0, 142, 0, 20),
		Text = "NO NODE",
		TextColor3 = Theme.Colors.Text,
		TextScaled = false,
		TextSize = 10,
		Font = Theme.Fonts.Heading,
		Parent = skillTreeDetailCard,
	})
	addCorner(skillTreeDetailBonus, UDim.new(0, 8))
	addStroke(skillTreeDetailBonus, Color3.fromRGB(112, 84, 54), 0.18, 1)
	local skillTreeDetailRank = label(skillTreeDetailCard, "Rank", "Rank --/--", UDim2.new(1, -156, 0, 38), UDim2.new(0, 142, 0, 16), Theme.Fonts.Heading, Theme.Colors.Text, Enum.TextXAlignment.Right)
	setFixedText(skillTreeDetailRank, 11, Enum.TextXAlignment.Right)
	local skillTreeDetailState = label(skillTreeDetailCard, "State", "State: --", UDim2.new(1, -156, 0, 58), UDim2.new(0, 142, 0, 14), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Right)
	setFixedText(skillTreeDetailState, 10, Enum.TextXAlignment.Right)
	local closeSkillTreeButton = createButton(skillTreePopup, "CloseSkillTreeButton", "Close Panel", UDim2.new(0, 124, 0, 40), UDim2.new(1, -24, 0, 44), Theme.Colors.Backdrop)
	closeSkillTreeButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(closeSkillTreeButton, 17, Enum.TextXAlignment.Center)
	lobbyRefs.Popups.SkillTree = skillTreePopup
	lobbyRefs.SkillTreeSummary = skillTreeSummary
	lobbyRefs.SkillTreeStatus = skillTreeStatus
	lobbyRefs.SkillTreeList = skillTreeList
	lobbyRefs.SkillTreeEmpty = skillTreeEmpty
	lobbyRefs.SkillTreePaneTitle = skillTreePaneTitle
	lobbyRefs.SkillTreePaneSub = skillTreePaneSub
	lobbyRefs.SkillTreeFilterButtons = skillTreeFilterButtons
	lobbyRefs.SkillTreeDetailTitle = skillTreeDetailTitle
	lobbyRefs.SkillTreeDetailMeta = skillTreeDetailMeta
	lobbyRefs.SkillTreeDetailBody = skillTreeDetailBody
	lobbyRefs.SkillTreeDetailBonus = skillTreeDetailBonus
	lobbyRefs.SkillTreeDetailRank = skillTreeDetailRank
	lobbyRefs.SkillTreeDetailState = skillTreeDetailState
	lobbyRefs.RespecSkillTreeButton = respecSkillTreeButton
	lobbyRefs.CloseSkillTreeButton = closeSkillTreeButton
	local respecConfirmPopup = createPopup(lobby, "RespecConfirmPopup", UDim2.new(0, 470, 0, 248), UDim2.new(0.58, 0, 0.18, 0), {
		backgroundColor = Color3.fromRGB(48, 42, 36),
		gradientStart = Color3.fromRGB(64, 54, 46),
		gradientEnd = Color3.fromRGB(36, 30, 26),
		strokeColor = Theme.Colors.AccentWarm,
		headerColor = Color3.fromRGB(164, 118, 64),
		headerColorEnd = Color3.fromRGB(102, 72, 42),
		badgeText = "RESET",
		badgeColor = Color3.fromRGB(114, 80, 48),
		iconText = "RSP",
		visible = false,
	})
	local respecBadgeNode = respecConfirmPopup:FindFirstChild("Badge")
	if respecBadgeNode and respecBadgeNode:IsA("GuiObject") then
		respecBadgeNode.Visible = false
	end
	local respecEmblemNode = respecConfirmPopup:FindFirstChild("Emblem")
	if respecEmblemNode and respecEmblemNode:IsA("GuiObject") then
		respecEmblemNode.Visible = false
	end
	local respecRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Theme.Colors.AccentWarm,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 24, 0, 112),
		Size = UDim2.new(1, -48, 0, 2),
		Parent = respecConfirmPopup,
	})
	addCorner(respecRule, UDim.new(0, 4))
	local respecConfirmTitle = label(respecConfirmPopup, "Title", "Reset Skill Tree?", UDim2.new(0, 24, 0, 64), UDim2.new(1, -48, 0, 28), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(respecConfirmTitle, 24)
	local respecConfirmBody = label(respecConfirmPopup, "Body", "This refunds every spent point and clears all unlocked skill nodes. Your level and XP stay the same.", UDim2.new(0, 24, 0, 122), UDim2.new(1, -48, 0, 54), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(respecConfirmBody, 15)
	local respecConfirmAccept = createButton(respecConfirmPopup, "ConfirmButton", "Confirm Reset", UDim2.new(0, 164, 0, 42), UDim2.new(0, 24, 1, -58), Theme.Colors.AccentWarm)
	respecConfirmAccept.AnchorPoint = Vector2.new(0, 0)
	setFixedText(respecConfirmAccept, 17, Enum.TextXAlignment.Center)
	local respecConfirmCancel = createButton(respecConfirmPopup, "CancelButton", "Cancel", UDim2.new(0, 120, 0, 42), UDim2.new(0, 200, 1, -58), Theme.Colors.Backdrop)
	respecConfirmCancel.AnchorPoint = Vector2.new(0, 0)
	setFixedText(respecConfirmCancel, 17, Enum.TextXAlignment.Center)
	lobbyRefs.RespecConfirmPopup = respecConfirmPopup
	lobbyRefs.RespecConfirmAccept = respecConfirmAccept
	lobbyRefs.RespecConfirmCancel = respecConfirmCancel

	local settingsPopup = createPopup(lobby, "SettingsPopup", UDim2.new(0, 560, 0, 392), UDim2.new(0.58, 0, 0.13, 0), {
		backgroundColor = Color3.fromRGB(42, 48, 58),
		gradientStart = Color3.fromRGB(56, 64, 76),
		gradientEnd = Color3.fromRGB(30, 36, 44),
		strokeColor = Color3.fromRGB(142, 154, 170),
		headerColor = Color3.fromRGB(92, 108, 128),
		headerColorEnd = Color3.fromRGB(58, 70, 86),
		badgeText = "CONFIG",
		badgeColor = Color3.fromRGB(66, 78, 94),
		iconText = "SET",
		visible = false,
	})
	local settingsBadgeNode = settingsPopup:FindFirstChild("Badge")
	if settingsBadgeNode and settingsBadgeNode:IsA("GuiObject") then
		settingsBadgeNode.Visible = false
	end
	local settingsEmblemNode = settingsPopup:FindFirstChild("Emblem")
	if settingsEmblemNode and settingsEmblemNode:IsA("GuiObject") then
		settingsEmblemNode.Visible = false
	end
	local settingsRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(142, 154, 170),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 24, 0, 112),
		Size = UDim2.new(1, -48, 0, 2),
		Parent = settingsPopup,
	})
	addCorner(settingsRule, UDim.new(0, 4))
	local settingsTitle = label(settingsPopup, "Title", "Field Settings", UDim2.new(0, 24, 0, 62), UDim2.new(1, -48, 0, 28), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(settingsTitle, 26)
	local settingsBody = label(settingsPopup, "Body", "Adjust local client comfort without affecting squad or server state.", UDim2.new(0, 24, 0, 124), UDim2.new(1, -48, 0, 44), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(settingsBody, 15)
	local settingsSummary = label(settingsPopup, "Summary", "UI audio and screen shake are active.", UDim2.new(0, 24, 0, 172), UDim2.new(1, -48, 0, 40), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	setFixedText(settingsSummary, 14)
	local settingsSectionRule = new("Frame", {
		Name = "SectionRule",
		BackgroundColor3 = Color3.fromRGB(142, 154, 170),
		BackgroundTransparency = 0.62,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 24, 0, 226),
		Size = UDim2.new(1, -48, 0, 1),
		Parent = settingsPopup,
	})
	addCorner(settingsSectionRule, UDim.new(0, 4))
	local settingsAudioLabel = label(settingsPopup, "AudioLabel", "AUDIO + CAMERA", UDim2.new(0, 24, 0, 232), UDim2.new(1, -48, 0, 12), Theme.Fonts.Heading, Color3.fromRGB(196, 214, 242))
	setFixedText(settingsAudioLabel, 9)
	local toggleUiAudioButton = createButton(settingsPopup, "ToggleUiAudioButton", "UI Audio: On", UDim2.new(0, 240, 0, 44), UDim2.new(0, 24, 0, 244), Theme.Colors.AccentWarm)
	toggleUiAudioButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(toggleUiAudioButton, 17, Enum.TextXAlignment.Center)
	local toggleScreenShakeButton = createButton(settingsPopup, "ToggleScreenShakeButton", "Screen Shake: On", UDim2.new(0, 240, 0, 44), UDim2.new(0, 288, 0, 244), Theme.Colors.CommandBlue)
	toggleScreenShakeButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(toggleScreenShakeButton, 17, Enum.TextXAlignment.Center)
	local settingsComfortLabel = label(settingsPopup, "ComfortLabel", "COMBAT + FEEDBACK", UDim2.new(0, 24, 0, 284), UDim2.new(1, -48, 0, 12), Theme.Fonts.Heading, Color3.fromRGB(196, 214, 242))
	setFixedText(settingsComfortLabel, 9)
	local toggleCombatFloatsButton = createButton(settingsPopup, "ToggleCombatFloatsButton", "Combat Floats: On", UDim2.new(0, 240, 0, 44), UDim2.new(0, 24, 0, 296), Color3.fromRGB(104, 156, 118))
	toggleCombatFloatsButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(toggleCombatFloatsButton, 17, Enum.TextXAlignment.Center)
	local toggleCompactToastsButton = createButton(settingsPopup, "ToggleCompactToastsButton", "Compact Toasts: Off", UDim2.new(0, 240, 0, 44), UDim2.new(0, 288, 0, 296), Color3.fromRGB(176, 136, 92))
	toggleCompactToastsButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(toggleCompactToastsButton, 17, Enum.TextXAlignment.Center)
	local closeSettingsButton = createButton(settingsPopup, "CloseSettingsButton", "Close", UDim2.new(0, 112, 0, 40), UDim2.new(1, -24, 0, 20), Theme.Colors.Backdrop)
	closeSettingsButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(closeSettingsButton, 16, Enum.TextXAlignment.Center)
	lobbyRefs.Popups.Settings = settingsPopup
	lobbyRefs.SettingsPopup = settingsPopup
	lobbyRefs.SettingsSummary = settingsSummary
	lobbyRefs.ToggleUiAudioButton = toggleUiAudioButton
	lobbyRefs.ToggleScreenShakeButton = toggleScreenShakeButton
	lobbyRefs.ToggleCombatFloatsButton = toggleCombatFloatsButton
	lobbyRefs.ToggleCompactToastsButton = toggleCompactToastsButton
	lobbyRefs.CloseSettingsButton = closeSettingsButton
	end

	createAdminPopup(lobby, lobbyRefs)
	createNpcDialoguePopup(lobby, lobbyRefs)
	createQuestBoardPopup(lobby, lobbyRefs)
	createActivitiesPopup(lobby, lobbyRefs)
	
	local lobbyStatus = label(lobby, "LobbyStatus", Theme.StatusCopy.Lobby, UDim2.new(0.05, 0, 0.93, 0), UDim2.new(0.4, 0, 0.04, 0), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	lobbyStatus.Visible = false
	lobbyRefs.LobbyStatus = lobbyStatus

	createResultsPopup(lobby, lobbyRefs)

	return {
		Gui = gui,
		Root = root,
		RootGradient = rootGradient,
		Pages = {
			Home = home,
			Loading = loading,
			Lobby = lobby,
		},
		Home = homeRefs,
		Loading = loadingRefs,
		Lobby = lobbyRefs,
	}
end

return UiBuilder
