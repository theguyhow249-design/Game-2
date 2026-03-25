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
	addCorner(popup, UDim.new(0, 18))
	addStroke(popup, strokeColor, 0.08, 1)
	addPadding(popup, UDim.new(0, 14))
	addGradient(popup, gradientStart, gradientEnd, 0)
	new("UIScale", {
		Name = "ScaleDriver",
		Scale = isVisible and 1 or 0.97,
		Parent = popup,
	})

	local headerBand = new("Frame", {
		Name = "HeaderBand",
		BackgroundColor3 = style.headerColor or strokeColor,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 50),
		Parent = popup,
	})
	addCorner(headerBand, UDim.new(0, 18))
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
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 32),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = headerBand,
	})

	local accentStrip = new("Frame", {
		Name = "AccentStrip",
		BackgroundColor3 = style.headerColor or strokeColor,
		BorderSizePixel = 0,
		Position = UDim2.new(0.06, 0, 0.18, 0),
		Size = UDim2.new(0.14, 0, 0, 4),
		Parent = popup,
	})
	addCorner(accentStrip, UDim.new(0, 6))

	local innerFrame = new("Frame", {
		Name = "InnerFrame",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 0, 54),
		Size = UDim2.new(1, -20, 1, -64),
		Parent = popup,
	})
	addStroke(innerFrame, strokeColor, 0.42, 1)

	local lowerRule = new("Frame", {
		Name = "LowerRule",
		BackgroundColor3 = style.headerColor or strokeColor,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0, 54),
		Size = UDim2.new(1, -24, 0, 1),
		Parent = popup,
	})

	local emblem = new("Frame", {
		Name = "Emblem",
		BackgroundColor3 = style.headerColor or strokeColor,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -66, 0, 10),
		Size = UDim2.new(0, 40, 0, 40),
		Parent = popup,
	})
	addCorner(emblem, UDim.new(0, 14))
	addStroke(emblem, style.headerColor or strokeColor, 0.14, 1)
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
			Position = UDim2.new(0.06, 0, 0.08, 0),
			Size = UDim2.new(0, 70, 0, 22),
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
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarImageColor3 = Theme.Colors.AccentWarm,
		ScrollBarThickness = 4,
		Parent = parent,
	})
	addCorner(list, UDim.new(0, 12))
	addStroke(list, Theme.Colors.Stroke, 0.18, 1)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = list,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 8),
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
	addStroke(card, strokeColor, 0.22, 1)
	addGradient(card, backgroundColor:Lerp(Color3.fromRGB(255, 255, 255), 0.06), backgroundColor:Lerp(Color3.fromRGB(0, 0, 0), 0.18), 90)
	local rule = new("Frame", {
		Name = "Rule",
		BackgroundColor3 = strokeColor,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0, 10),
		Size = UDim2.new(0, 62, 0, 3),
		Parent = card,
	})
	addCorner(rule, UDim.new(0, 4))
	local panelTag = new("Frame", {
		Name = "PanelTag",
		BackgroundColor3 = strokeColor,
		BackgroundTransparency = 0.82,
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

	do
	local homePanel = createPopup(home, "HomePanel", UDim2.new(0.54, 0, 0.56, 0), UDim2.new(0.23, 0, 0.22, 0), {
		backgroundColor = Color3.fromRGB(42, 50, 60),
		gradientStart = Color3.fromRGB(58, 69, 82),
		gradientEnd = Color3.fromRGB(36, 44, 54),
		strokeColor = Color3.fromRGB(138, 154, 166),
		headerColor = Color3.fromRGB(86, 112, 138),
		headerColorEnd = Color3.fromRGB(56, 78, 102),
	})
	homePanel.AnchorPoint = Vector2.new(0, 0)
	local homeTitle = label(homePanel, "Title", Theme.GameTitle, UDim2.new(0.08, 0, 0.12, 0), UDim2.new(0.84, 0, 0.22, 0), Theme.Fonts.Title, Theme.Colors.Text)
	homeTitle.TextTransparency = 0
	local homeSubtitle = label(homePanel, "Subtitle", Theme.GameSubtitle, UDim2.new(0.12, 0, 0.34, 0), UDim2.new(0.76, 0, 0.15, 0), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Center)
	homeSubtitle.TextTransparency = 0
	local homePlayButton = createButton(homePanel, "PlayButton", Theme.HomePlayButtonText, UDim2.new(0.32, 0, 0.16, 0), UDim2.new(0.5, 0, 0.68, 0), Theme.Colors.Accent)
	local homeHint = label(homePanel, "Hint", "Press Play to enter the bunker flow.", UDim2.new(0.15, 0, 0.86, 0), UDim2.new(0.7, 0, 0.08, 0), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Center)
	homeHint.TextTransparency = 0
	homeRefs.PlayButton = homePlayButton
	end

	do
	local loadingPanel = createPopup(loading, "LoadingPanel", UDim2.new(0, 820, 0, 380), UDim2.new(0.5, -410, 0.5, -190), {
		backgroundColor = Color3.fromRGB(34, 42, 52),
		gradientStart = Color3.fromRGB(48, 58, 70),
		gradientEnd = Color3.fromRGB(24, 30, 38),
		strokeColor = Color3.fromRGB(126, 146, 168),
		headerColor = Color3.fromRGB(82, 102, 126),
		headerColorEnd = Color3.fromRGB(50, 68, 88),
		badgeText = "DEPLOY",
		badgeColor = Color3.fromRGB(64, 82, 104),
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
	local loadingHeaderRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(126, 146, 168),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, 118),
		Size = UDim2.new(1, -60, 0, 2),
		Parent = loadingPanel,
	})
	addCorner(loadingHeaderRule, UDim.new(0, 4))
	local loadingAccent = new("Frame", {
		Name = "HeaderAccent",
		BackgroundColor3 = Color3.fromRGB(126, 146, 168),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, 86),
		Size = UDim2.new(0, 168, 0, 4),
		Parent = loadingPanel,
	})
	addCorner(loadingAccent, UDim.new(0, 6))
	local loadingTitle = label(loadingPanel, "Title", Theme.GameTitle, UDim2.new(0, 28, 0, 74), UDim2.new(1, -56, 0, 42), Theme.Fonts.Title, Theme.Colors.Text, Enum.TextXAlignment.Center)
	setFixedText(loadingTitle, 34, Enum.TextXAlignment.Center)
	local loadingTag = label(loadingPanel, "Tag", "Deployment corridor online. Synchronizing bunker systems.", UDim2.new(0, 28, 0, 120), UDim2.new(1, -56, 0, 24), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Center)
	setFixedText(loadingTag, 16, Enum.TextXAlignment.Center)
	local loadingPromptPlate = new("Frame", {
		Name = "PromptPlate",
		BackgroundColor3 = Color3.fromRGB(42, 56, 68),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 122, 0, 188),
		Size = UDim2.new(1, -244, 0, 64),
		Parent = loadingPanel,
	})
	addCorner(loadingPromptPlate, UDim.new(0, 16))
	addStroke(loadingPromptPlate, Theme.Colors.BunkerAccent, 0.18, 1)
	local loadingPrompt = label(loadingPromptPlate, "Prompt", Theme.LoadingPrompt, UDim2.new(0, 16, 0, 14), UDim2.new(1, -32, 0, 28), Theme.Fonts.Heading, Theme.Colors.AccentSoft, Enum.TextXAlignment.Center)
	setFixedText(loadingPrompt, 22, Enum.TextXAlignment.Center)
	local loadingStatusPlate = new("Frame", {
		Name = "StatusPlate",
		BackgroundColor3 = Color3.fromRGB(26, 32, 38),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 158, 0, 274),
		Size = UDim2.new(1, -316, 0, 46),
		Parent = loadingPanel,
	})
	addCorner(loadingStatusPlate, UDim.new(0, 14))
	addStroke(loadingStatusPlate, Theme.Colors.Stroke, 0.2, 1)
	local loadingStatus = label(loadingStatusPlate, "Status", Theme.StatusCopy.Loading, UDim2.new(0, 12, 0, 10), UDim2.new(1, -24, 0, 20), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Center)
	setFixedText(loadingStatus, 15, Enum.TextXAlignment.Center)
	loadingRefs.Panel = loadingPanel
	loadingRefs.Prompt = loadingPrompt
	loadingRefs.Status = loadingStatus
	end

	do
	local hudBar = new("Frame", {
		Name = "HudBar",
		BackgroundColor3 = Color3.fromRGB(24, 28, 34),
		BackgroundTransparency = 0.03,
		BorderSizePixel = 0,
		Position = UDim2.new(0.052, 0, 0.032, 0),
		Size = UDim2.new(0, 840, 0, 72),
		Visible = true,
		Parent = lobby,
	})
	addCorner(hudBar, UDim.new(0, 18))
	addStroke(hudBar, Theme.Colors.Stroke, 0.16, 1)
	addGradient(hudBar, Color3.fromRGB(34, 40, 48), Color3.fromRGB(18, 22, 28), 0)
	local hudStrip = new("Frame", {
		Name = "AccentStrip",
		BackgroundColor3 = Theme.Colors.BunkerAccent,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0, 7),
		Size = UDim2.new(0, 44, 0, 3),
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
		Position = UDim2.new(0, 10, 0, 14),
		Size = UDim2.new(0, 170, 0, 44),
		Parent = hudBar,
	})
	addCorner(hudModule, UDim.new(0, 14))
	addStroke(hudModule, Theme.Colors.Stroke, 0.16, 1)
	hudTitle.Parent = hudModule
	hudTitle.Position = UDim2.new(0, 14, 0, 7)
	hudTitle.Size = UDim2.new(1, -24, 0, 16)
	hudTitle.TextSize = 14
	local hudSub = label(hudModule, "Sub", "COMMAND GRID", UDim2.new(0, 14, 0, 22), UDim2.new(1, -28, 0, 12), Theme.Fonts.Body, Theme.Colors.Muted)
	hudSub.Position = UDim2.new(0, 14, 0, 28)
	hudSub.Size = UDim2.new(1, -28, 0, 12)
	setFixedText(hudSub, 10)
	local hudIcon = new("Frame", {
		Name = "Icon",
		BackgroundColor3 = Theme.Colors.BunkerAccent,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 132, 0, 8),
		Size = UDim2.new(0, 24, 0, 24),
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
		Position = UDim2.new(0, 188, 0.5, 0),
		Size = UDim2.new(0, 150, 0, 34),
		Parent = hudBar,
	})
	addCorner(tokenPill, UDim.new(0, 10))
	addStroke(tokenPill, Theme.Colors.Accent, 0.3, 1)
	local tokenValue = label(tokenPill, "Value", "0 Deploy Tokens", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), Theme.Fonts.Heading, Theme.Colors.Text, Enum.TextXAlignment.Center)
	tokenValue.TextScaled = false
	tokenValue.TextSize = 12
	local tokenTag = label(tokenPill, "Tag", "DEPLOY TOKENS", UDim2.new(0, 12, 0, 4), UDim2.new(1, -24, 0, 10), Theme.Fonts.Body, Theme.Colors.AccentSoft, Enum.TextXAlignment.Left)
	setFixedText(tokenTag, 9)
	tokenValue.Position = UDim2.new(0, 12, 0, 15)
	tokenValue.Size = UDim2.new(1, -24, 0, 16)
	tokenValue.TextXAlignment = Enum.TextXAlignment.Left
	tokenValue.Position = UDim2.new(0, 12, 0, 13)
	local deployStatusPill = new("Frame", {
		Name = "DeployStatusPill",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(26, 32, 38),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 352, 0.5, 0),
		Size = UDim2.new(0, 186, 0, 34),
		Parent = hudBar,
	})
	addCorner(deployStatusPill, UDim.new(0, 10))
	addStroke(deployStatusPill, Theme.Colors.AccentWarm, 0.3, 1)
	local deployStatus = label(deployStatusPill, "Value", Theme.StatusCopy.Lobby, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), Theme.Fonts.Heading, Theme.Colors.Text, Enum.TextXAlignment.Center)
	deployStatus.TextScaled = false
	deployStatus.TextSize = 12
	local deployTag = label(deployStatusPill, "Tag", "STATUS", UDim2.new(0, 12, 0, 4), UDim2.new(1, -24, 0, 10), Theme.Fonts.Body, Color3.fromRGB(255, 222, 166), Enum.TextXAlignment.Left)
	setFixedText(deployTag, 9)
	deployStatus.Position = UDim2.new(0, 12, 0, 15)
	deployStatus.Size = UDim2.new(1, -24, 0, 16)
	deployStatus.TextXAlignment = Enum.TextXAlignment.Left
	deployStatus.Position = UDim2.new(0, 12, 0, 13)
	local persistencePill = new("Frame", {
		Name = "PersistencePill",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(26, 44, 34),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 552, 0.5, 0),
		Size = UDim2.new(0, 102, 0, 34),
		Parent = hudBar,
	})
	addCorner(persistencePill, UDim.new(0, 10))
	addStroke(persistencePill, Theme.Colors.Accent, 0.3, 1)
	local persistenceValue = label(persistencePill, "Value", "Saving", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), Theme.Fonts.Heading, Theme.Colors.Text, Enum.TextXAlignment.Center)
	persistenceValue.TextScaled = false
	persistenceValue.TextSize = 11
	local persistenceTag = label(persistencePill, "Tag", "DATA", UDim2.new(0, 12, 0, 4), UDim2.new(1, -24, 0, 10), Theme.Fonts.Body, Theme.Colors.AccentSoft, Enum.TextXAlignment.Left)
	setFixedText(persistenceTag, 9)
	persistenceValue.Position = UDim2.new(0, 12, 0, 15)
	persistenceValue.Size = UDim2.new(1, -24, 0, 16)
	persistenceValue.TextXAlignment = Enum.TextXAlignment.Left
	persistenceValue.Position = UDim2.new(0, 12, 0, 13)
	local subscriptionPill = new("Frame", {
		Name = "SubscriptionPill",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(32, 36, 28),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 668, 0.5, 0),
		Size = UDim2.new(0, 128, 0, 34),
		Parent = hudBar,
	})
	addCorner(subscriptionPill, UDim.new(0, 10))
	addStroke(subscriptionPill, Theme.Colors.AccentWarm, 0.3, 1)
	local subscriptionValue = label(subscriptionPill, "Value", "Free", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), Theme.Fonts.Heading, Theme.Colors.Text, Enum.TextXAlignment.Center)
	subscriptionValue.TextScaled = false
	subscriptionValue.TextSize = 11
	local subscriptionTag = label(subscriptionPill, "Tag", "ACCESS", UDim2.new(0, 12, 0, 4), UDim2.new(1, -24, 0, 10), Theme.Fonts.Body, Color3.fromRGB(255, 222, 166), Enum.TextXAlignment.Left)
	setFixedText(subscriptionTag, 9)
	subscriptionValue.Position = UDim2.new(0, 12, 0, 15)
	subscriptionValue.Size = UDim2.new(1, -24, 0, 16)
	subscriptionValue.TextXAlignment = Enum.TextXAlignment.Left
	subscriptionValue.Position = UDim2.new(0, 12, 0, 13)
	local identityPill = new("Frame", {
		Name = "IdentityPill",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(42, 36, 26),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 810, 0.5, 0),
		Size = UDim2.new(0, 134, 0, 34),
		Parent = hudBar,
	})
	addCorner(identityPill, UDim.new(0, 10))
	addStroke(identityPill, Theme.Colors.AccentWarm, 0.3, 1)
	local identityValue = label(identityPill, "Value", "Survivor", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), Theme.Fonts.Heading, Theme.Colors.Text, Enum.TextXAlignment.Center)
	identityValue.TextScaled = false
	identityValue.TextSize = 11
	local identityTag = label(identityPill, "Tag", "TITLE", UDim2.new(0, 12, 0, 4), UDim2.new(1, -24, 0, 10), Theme.Fonts.Body, Color3.fromRGB(255, 222, 166), Enum.TextXAlignment.Left)
	setFixedText(identityTag, 9)
	identityValue.Position = UDim2.new(0, 12, 0, 13)
	identityValue.Size = UDim2.new(1, -24, 0, 16)
	identityValue.TextXAlignment = Enum.TextXAlignment.Left
	local deployButton = createButton(hudBar, "DeployButton", "Deploy", UDim2.new(0, 116, 0, 36), UDim2.new(1, -18, 0.5, 0), Theme.Colors.AccentWarm)
	deployButton.AnchorPoint = Vector2.new(1, 0.5)
	setFixedText(deployButton, 16, Enum.TextXAlignment.Center)
	local missionPanel = new("Frame", {
		Name = "MissionPanel",
		BackgroundColor3 = Color3.fromRGB(18, 22, 28),
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		Position = UDim2.new(0.03, 0, 0.13, 0),
		Size = UDim2.new(0, 420, 0, 118),
		Visible = false,
		Parent = lobby,
	})
	addCorner(missionPanel, UDim.new(0, 14))
	addStroke(missionPanel, Theme.Colors.Stroke, 0.12, 1)
	addGradient(missionPanel, Color3.fromRGB(24, 30, 38), Color3.fromRGB(12, 16, 22), 0)
	local missionRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Theme.Colors.BunkerAccent,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 16, 0, 32),
		Size = UDim2.new(0, 82, 0, 2),
		Parent = missionPanel,
	})
	addCorner(missionRule, UDim.new(0, 4))
	local missionTitle = label(missionPanel, "Title", "Mission", UDim2.new(0, 16, 0, 10), UDim2.new(1, -32, 0, 16), Theme.Fonts.Heading)
	setFixedText(missionTitle, 14)
	local missionStatus = label(missionPanel, "MissionStatus", "Objective: defend the bunker core", UDim2.new(0.06, 0, 0.34, 0), UDim2.new(0.88, 0, 0.18, 0), Theme.Fonts.Body, Theme.Colors.Text)
	local missionMeta = label(missionPanel, "MissionMeta", "Wave 0 | Core 100%", UDim2.new(0.06, 0, 0.56, 0), UDim2.new(0.88, 0, 0.13, 0), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	local missionLoadout = label(missionPanel, "MissionLoadout", "Loadout: Training Blade | Ammo: --", UDim2.new(0.06, 0, 0.75, 0), UDim2.new(0.88, 0, 0.12, 0), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	missionStatus.Position = UDim2.new(0, 16, 0, 42)
	missionStatus.Size = UDim2.new(1, -32, 0, 24)
	missionStatus.TextScaled = false
	missionStatus.TextSize = 13
	missionMeta.Position = UDim2.new(0, 16, 0, 76)
	missionMeta.Size = UDim2.new(1, -32, 0, 14)
	missionMeta.TextScaled = false
	missionMeta.TextSize = 11
	missionLoadout.Position = UDim2.new(0, 16, 0, 94)
	missionLoadout.Size = UDim2.new(1, -32, 0, 14)
	missionLoadout.TextScaled = false
	missionLoadout.TextSize = 11
	local leaderboardBoard = new("Frame", {
		Name = "LeaderboardBoard",
		BackgroundColor3 = Color3.fromRGB(18, 22, 28),
		BackgroundTransparency = 0.03,
		BorderSizePixel = 0,
		Position = UDim2.new(0.03, 0, 1, -266),
		Size = UDim2.new(0, 430, 0, 216),
		Parent = lobby,
	})
	addCorner(leaderboardBoard, UDim.new(0, 14))
	addStroke(leaderboardBoard, Theme.Colors.Stroke, 0.12, 1)
	addGradient(leaderboardBoard, Color3.fromRGB(24, 30, 38), Color3.fromRGB(12, 16, 22), 0)
	local leaderboardRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(196, 166, 108),
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 16, 0, 32),
		Size = UDim2.new(0, 110, 0, 2),
		Parent = leaderboardBoard,
	})
	addCorner(leaderboardRule, UDim.new(0, 4))
	local leaderboardTitle = label(leaderboardBoard, "Title", "Lobby Leaderboard", UDim2.new(0, 16, 0, 10), UDim2.new(1, -32, 0, 18), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(leaderboardTitle, 15)
	local leaderboardSummary = label(leaderboardBoard, "Summary", "Top operators in this server session.", UDim2.new(0, 16, 0, 42), UDim2.new(1, -32, 0, 16), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(leaderboardSummary, 12)
	local leaderboardColumns = {}
	for index, info in ipairs({
		{ key = "Levels", title = "LEVELS", color = Color3.fromRGB(132, 178, 232) },
		{ key = "Runs", title = "RUNS", color = Color3.fromRGB(122, 198, 156) },
		{ key = "Kills", title = "KILLS", color = Color3.fromRGB(214, 174, 104) },
	}) do
		local column = new("Frame", {
			Name = info.key .. "Column",
			BackgroundColor3 = Color3.fromRGB(28, 34, 42),
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 16 + ((index - 1) * 134), 0, 72),
			Size = UDim2.new(0, 126, 0, 128),
			Parent = leaderboardBoard,
		})
		addCorner(column, UDim.new(0, 12))
		addStroke(column, info.color, 0.18, 1)
		local columnTitle = label(column, "Title", info.title, UDim2.new(0, 12, 0, 10), UDim2.new(1, -24, 0, 14), Theme.Fonts.Heading, info.color)
		setFixedText(columnTitle, 11)
		local columnBody = label(column, "Body", "Waiting for players...", UDim2.new(0, 12, 0, 30), UDim2.new(1, -24, 1, -40), Theme.Fonts.Body, Theme.Colors.Text)
		columnBody.TextWrapped = true
		columnBody.TextYAlignment = Enum.TextYAlignment.Top
		setFixedText(columnBody, 12)
		leaderboardColumns[info.key] = columnBody
	end
	local adminButton = createButton(lobby, "AdminButton", "Owner", UDim2.new(0, 112, 0, 34), UDim2.new(1, -28, 0, 84), Color3.fromRGB(138, 108, 58))
	adminButton.AnchorPoint = Vector2.new(1, 0)
	adminButton.Visible = false
	adminButton.ZIndex = 20
	setFixedText(adminButton, 15, Enum.TextXAlignment.Center)
	lobbyRefs.HudBar = hudBar
	lobbyRefs.MissionPanel = missionPanel
	lobbyRefs.MissionStatus = missionStatus
	lobbyRefs.MissionMeta = missionMeta
	lobbyRefs.MissionLoadout = missionLoadout
	lobbyRefs.LeaderboardBoard = leaderboardBoard
	lobbyRefs.LeaderboardSummary = leaderboardSummary
	lobbyRefs.LeaderboardColumns = leaderboardColumns
	lobbyRefs.AdminButton = adminButton
	lobbyRefs.CombatOverlay = combatOverlay
	lobbyRefs.HitMarker = hitMarker
	lobbyRefs.RewardFloatLayer = rewardFloatLayer
	lobbyRefs.TokenValue = tokenValue
	lobbyRefs.DeployStatus = deployStatus
	lobbyRefs.PersistenceValue = persistenceValue
	lobbyRefs.SubscriptionValue = subscriptionValue
	lobbyRefs.IdentityValue = identityValue
	lobbyRefs.DeployButton = deployButton

	local missionToastStack = new("Frame", {
		Name = "MissionToastStack",
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -324, 0.13, 0),
		Size = UDim2.new(0, 288, 0, 220),
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
		local button = createButton(parent, name, "", UDim2.new(1, 0, 0, 44), UDim2.new(), accentColor)
		button.AnchorPoint = Vector2.new(0, 0)
		button.LayoutOrder = layoutOrder
		button.Text = ""
		button.BackgroundTransparency = 0.02
		addGradient(
			button,
			accentColor:Lerp(Color3.fromRGB(255, 255, 255), 0.08),
			accentColor:Lerp(Color3.fromRGB(0, 0, 0), 0.34),
			0
		)

		local accentRail = new("Frame", {
			Name = "AccentRail",
			BackgroundColor3 = accentColor:Lerp(Color3.fromRGB(255, 255, 255), 0.18),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 4, 1, 0),
			Parent = button,
		})
		addCorner(accentRail, UDim.new(0, 4))

		local topRule = new("Frame", {
			Name = "TopRule",
			BackgroundColor3 = Theme.Colors.Text,
			BackgroundTransparency = 0.78,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 10, 0, 6),
			Size = UDim2.new(0, 26, 0, 1),
			Parent = button,
		})
		addCorner(topRule, UDim.new(0, 2))

		local badge = new("Frame", {
			Name = "Badge",
			BackgroundColor3 = accentColor:Lerp(Color3.fromRGB(255, 255, 255), 0.08),
			BackgroundTransparency = 0.02,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.new(0, 30, 0, 30),
			AnchorPoint = Vector2.new(0, 0.5),
			Parent = button,
		})
		addCorner(badge, UDim.new(0, 10))
		addStroke(badge, Theme.Colors.Text, 0.72, 1)
		createQuickAccessGlyph(badge, iconKind)

		local title = new("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 50, 0, 6),
			Size = UDim2.new(1, -64, 0, 16),
			Text = titleText,
			TextColor3 = Theme.Colors.Text,
			TextScaled = false,
			TextSize = 14,
			Font = Theme.Fonts.Heading,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = button,
		})

		local subtitle = new("TextLabel", {
			Name = "Subtitle",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 50, 0, 22),
			Size = UDim2.new(1, -64, 0, 12),
			Text = subtitleText,
			TextColor3 = Theme.Colors.Text:Lerp(Theme.Colors.Muted, 0.35),
			TextScaled = false,
			TextSize = 9,
			Font = Theme.Fonts.Body,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = button,
		})
		subtitle.TextTransparency = 0.08

		local arrow = new("TextLabel", {
			Name = "Arrow",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(0, 16, 0, 16),
			Text = ">",
			TextColor3 = accentColor:Lerp(Theme.Colors.Text, 0.32),
			TextScaled = false,
			TextSize = 15,
			Font = Theme.Fonts.Heading,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = button,
		})
		arrow.TextTransparency = 0.08

		return button
	end

	local quickAccessBar = new("Frame", {
		Name = "QuickAccessBar",
		BackgroundColor3 = Color3.fromRGB(18, 22, 28),
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -232, 0.11, 0),
		Size = UDim2.new(0, 198, 0, 404),
		Parent = lobby,
	})
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
		Position = UDim2.new(0, 16, 0, 12),
		Size = UDim2.new(0, 64, 0, 3),
		Parent = quickAccessBar,
	})
	addCorner(quickAccessRule, UDim.new(0, 4))
	local quickAccessTitle = label(quickAccessBar, "Title", "Quick Access", UDim2.new(0, 16, 0, 20), UDim2.new(1, -32, 0, 22), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(quickAccessTitle, 18)
	local quickAccessTag = label(quickAccessBar, "Tag", "COMMAND STRIP", UDim2.new(0, 102, 0, 22), UDim2.new(0, 80, 0, 12), Theme.Fonts.Heading, Theme.Colors.AccentSoft)
	setFixedText(quickAccessTag, 9)
	local quickAccessBody = label(quickAccessBar, "Body", "Open bunker systems without walking back to each station.", UDim2.new(0, 16, 0, 46), UDim2.new(1, -32, 0, 42), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(quickAccessBody, 11)
	local quickAccessButtons = new("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 102),
		Size = UDim2.new(1, -32, 1, -144),
		Parent = quickAccessBar,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = quickAccessButtons,
	})
	local shopQuickButton = createQuickAccessButton(quickAccessButtons, "ShopQuickButton", "Shop", "Quartermaster", "shop", Theme.Colors.AccentWarm, 1)
	local inventoryQuickButton = createQuickAccessButton(quickAccessButtons, "InventoryQuickButton", "Inventory", "Loadout and skins", "inventory", Color3.fromRGB(86, 122, 176), 2)
	local squadQuickButton = createQuickAccessButton(quickAccessButtons, "SquadQuickButton", "Squad", "Fireteam control", "squad", Color3.fromRGB(92, 146, 214), 3)
	local inviteQuickButton = createQuickAccessButton(quickAccessButtons, "InviteQuickButton", "Invite", "Open comms roster", "invite", Color3.fromRGB(76, 158, 136), 4)
	local settingsQuickButton = createQuickAccessButton(quickAccessButtons, "SettingsQuickButton", "Settings", "Local comfort", "settings", Theme.Colors.Backdrop, 5)
	local quickAccessFooterRule = new("Frame", {
		Name = "FooterRule",
		BackgroundColor3 = Theme.Colors.BunkerAccent,
		BackgroundTransparency = 0.74,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 16, 1, -48),
		Size = UDim2.new(1, -32, 0, 1),
		Parent = quickAccessBar,
	})
	local quickAccessFooter = label(quickAccessBar, "Footer", "Shop covers loadout and cosmetics. Invite opens the comms roster.", UDim2.new(0, 16, 1, -36), UDim2.new(1, -32, 0, 26), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(quickAccessFooter, 10)
	lobbyRefs.QuickAccessBar = quickAccessBar
	lobbyRefs.ShopQuickButton = shopQuickButton
	lobbyRefs.InventoryQuickButton = inventoryQuickButton
	lobbyRefs.SquadQuickButton = squadQuickButton
	lobbyRefs.InviteQuickButton = inviteQuickButton
	lobbyRefs.SettingsQuickButton = settingsQuickButton
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
	local shopPopup = createPopup(lobby, "ShopPopup", UDim2.new(0, 1240, 0, 710), UDim2.new(0.025, 0, 0.075, 0), {
		backgroundColor = shopStyle.backgroundColor,
		gradientStart = shopStyle.gradientStart,
		gradientEnd = shopStyle.gradientEnd,
		strokeColor = shopStyle.strokeColor,
		headerColor = shopStyle.headerColor,
		headerColorEnd = shopStyle.headerColorEnd,
		badgeText = shopStyle.badgeText,
		badgeColor = shopStyle.badgeColor,
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
		BackgroundColor3 = Color3.fromRGB(228, 181, 96),
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, 118),
		Size = UDim2.new(1, -60, 0, 2),
		Parent = shopPopup,
	})
	addCorner(shopHeaderRule, UDim.new(0, 4))
	local shopPopupAccent = new("Frame", {
		Name = "HeaderAccent",
		BackgroundColor3 = Color3.fromRGB(239, 184, 83),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, 84),
		Size = UDim2.new(0, 148, 0, 3),
		Parent = shopPopup,
	})
	addCorner(shopPopupAccent, UDim.new(0, 6))
	local leftRail = new("Frame", {
		Name = "LeftRail",
		BackgroundColor3 = Color3.fromRGB(88, 62, 40),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 28, 0, 132),
		Size = UDim2.new(0, 224, 1, -160),
		Parent = shopPopup,
	})
	addCorner(leftRail, UDim.new(0, 18))
	addStroke(leftRail, Color3.fromRGB(220, 176, 98), 0.16, 1)
	local leftRailTitle = label(leftRail, "RailTitle", "Quartermaster Lanes", UDim2.new(0, 16, 0, 14), UDim2.new(1, -32, 0, 22), Theme.Fonts.Heading, Color3.fromRGB(255, 246, 224))
	setFixedText(leftRailTitle, 19)
	local leftRailBody = label(leftRail, "RailBody", "Route tokens, upgrades, armory gear, cosmetics, and specialization through dedicated bunker lanes.", UDim2.new(0, 16, 0, 42), UDim2.new(1, -32, 0, 54), Theme.Fonts.Body, Color3.fromRGB(244, 223, 186))
	setFixedText(leftRailBody, 13)

	local centerPane = new("Frame", {
		Name = "CenterPane",
		BackgroundColor3 = Color3.fromRGB(104, 74, 48),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 270, 0, 132),
		Size = UDim2.new(0, 292, 1, -160),
		Parent = shopPopup,
	})
	addCorner(centerPane, UDim.new(0, 18))
	addStroke(centerPane, Color3.fromRGB(214, 168, 92), 0.18, 1)

	local rightPane = new("Frame", {
		Name = "RightPane",
		BackgroundColor3 = Color3.fromRGB(116, 86, 58),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 580, 0, 132),
		Size = UDim2.new(1, -608, 1, -160),
		Parent = shopPopup,
	})
	addCorner(rightPane, UDim.new(0, 18))
	addStroke(rightPane, Color3.fromRGB(228, 181, 96), 0.16, 1)

	local shopTitle = label(shopPopup, "Title", "Quartermaster", UDim2.new(0, 34, 0, 58), UDim2.new(1, -190, 0, 30), Theme.Fonts.Heading, Color3.fromRGB(255, 248, 236))
	setFixedText(shopTitle, 32)
	local shopTag = label(shopPopup, "Tag", "Route bunker currency, armory stock, and specialist support through the command market.", UDim2.new(0, 34, 0, 92), UDim2.new(1, -220, 0, 18), Theme.Fonts.Body, Color3.fromRGB(248, 228, 190))
	setFixedText(shopTag, 15)
	local rewardCard = createInsetCard(centerPane, "RewardCard", UDim2.new(0, 18, 0, 18), UDim2.new(1, -36, 0, 118), Color3.fromRGB(146, 112, 70), Color3.fromRGB(226, 184, 96))
	local dailyRewardStatus = label(rewardCard, "DailyRewardStatus", "Daily reward ready.", UDim2.new(0, 14, 0, 34), UDim2.new(1, -28, 0, 34), Theme.Fonts.Body, Color3.fromRGB(220, 239, 164))
	setFixedText(dailyRewardStatus, 16)
	local rewardTitle = label(rewardCard, "RewardTitle", "Daily Quartermaster Drop", UDim2.new(0, 14, 0, 14), UDim2.new(1, -54, 0, 20), Theme.Fonts.Heading, Color3.fromRGB(255, 246, 222))
	setFixedText(rewardTitle, 18)
	local claimDailyButton = createButton(rewardCard, "ClaimDailyButton", "Claim Daily", UDim2.new(1, -28, 0, 42), UDim2.new(0, 14, 0, 68), Theme.Colors.Accent)
	claimDailyButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(claimDailyButton, 18, Enum.TextXAlignment.Center)
	local loadoutCard = createInsetCard(centerPane, "LoadoutCard", UDim2.new(0, 18, 0, 148), UDim2.new(1, -36, 0, 150), Color3.fromRGB(118, 88, 56), Color3.fromRGB(220, 176, 98))
	local loadoutTitle = label(loadoutCard, "LoadoutTitle", "Current Field Kit", UDim2.new(0, 14, 0, 14), UDim2.new(1, -54, 0, 20), Theme.Fonts.Heading, Color3.fromRGB(255, 246, 224))
	setFixedText(loadoutTitle, 18)
	local loadoutSummary = label(loadoutCard, "LoadoutSummary", "Weapon: Training Blade | Cosmetic: None", UDim2.new(0, 14, 0, 38), UDim2.new(1, -28, 0, 32), Theme.Fonts.Heading, Color3.fromRGB(255, 248, 234))
	setFixedText(loadoutSummary, 14)
	local statsSummary = label(loadoutCard, "StatsSummary", "Missions: 0 | Kills: 0", UDim2.new(0, 14, 0, 84), UDim2.new(1, -28, 0, 18), Theme.Fonts.Body, Color3.fromRGB(248, 228, 186))
	setFixedText(statsSummary, 13)
	local skillSummary = label(loadoutCard, "SkillSummary", "Bunker Level 1 | 0 skill points ready", UDim2.new(0, 14, 0, 108), UDim2.new(1, -28, 0, 30), Theme.Fonts.Body, Color3.fromRGB(220, 239, 164))
	setFixedText(skillSummary, 13)
	local servicesCard = createInsetCard(centerPane, "ServicesCard", UDim2.new(0, 18, 0, 316), UDim2.new(1, -36, 1, -334), Color3.fromRGB(112, 82, 54), Color3.fromRGB(220, 176, 98))
	local servicesTitle = label(servicesCard, "ServicesTitle", "Quartermaster Brief", UDim2.new(0, 14, 0, 14), UDim2.new(1, -54, 0, 20), Theme.Fonts.Heading, Color3.fromRGB(255, 247, 227))
	setFixedText(servicesTitle, 17)
	local servicesBody = label(servicesCard, "ServicesBody", "Select a lane on the left. The center tracks bunker status, your field kit, and daily support while the right board shows stock.", UDim2.new(0, 14, 0, 42), UDim2.new(1, -28, 1, -50), Theme.Fonts.Body, Color3.fromRGB(250, 227, 188))
	setFixedText(servicesBody, 13)
	local inventoryBadge = new("TextLabel", {
		Name = "InventoryBadge",
		BackgroundColor3 = Color3.fromRGB(92, 66, 40),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 22, 0, 18),
		Size = UDim2.new(0, 136, 0, 28),
		Text = "LIVE INVENTORY",
		TextColor3 = Color3.fromRGB(255, 243, 214),
		TextScaled = false,
		TextSize = 13,
		Font = Theme.Fonts.Heading,
		Parent = rightPane,
	})
	addCorner(inventoryBadge, UDim.new(0, 10))
	addStroke(inventoryBadge, Color3.fromRGB(228, 181, 96), 0.12, 1)
	local shopBody = label(rightPane, "Body", Theme.ShopCopy["Deploy Tokens"], UDim2.new(0, 22, 0, 56), UDim2.new(1, -44, 0, 38), Theme.Fonts.Body, Color3.fromRGB(248, 232, 204))
	setFixedText(shopBody, 16)
	local inventoryTitle = label(rightPane, "InventoryTitle", "Quartermaster Stock", UDim2.new(0, 22, 0, 102), UDim2.new(1, -44, 0, 26), Theme.Fonts.Heading, Color3.fromRGB(255, 248, 232))
	setFixedText(inventoryTitle, 28)
	local tabButtons = new("Frame", {
		Name = "TabButtons",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 118),
		Size = UDim2.new(1, -32, 1, -172),
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
			BackgroundColor3 = Color3.fromRGB(44, 54, 66),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 44),
			Text = tabName,
			TextColor3 = Theme.Colors.Text,
			TextScaled = false,
			TextSize = 18,
			Font = Theme.Fonts.Heading,
			AutoButtonColor = false,
			LayoutOrder = index,
			Parent = tabButtons,
		})
		addCorner(tabButton, UDim.new(0, 12))
		addStroke(tabButton, Color3.fromRGB(152, 166, 178), 0.16, 1)
		shopTabs[tabName] = tabButton
	end
	local railFooter = label(leftRail, "RailFooter", "Select a lane on the left. The center tracks bunker status. The right board handles live stock.", UDim2.new(0, 16, 1, -42), UDim2.new(1, -32, 0, 28), Theme.Fonts.Body, Color3.fromRGB(242, 221, 186))
	setFixedText(railFooter, 11)
	local shopStatus = label(rightPane, "Status", "Select a lane to browse bunker gear, deployment currency, and mission-ready kit.", UDim2.new(0, 22, 0, 136), UDim2.new(1, -44, 0, 20), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	setFixedText(shopStatus, 14)
	local shopRarityFilters = new("Frame", {
		Name = "RarityFilters",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 22, 0, 162),
		Size = UDim2.new(1, -44, 0, 30),
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
		Position = UDim2.new(0, 22, 0, 196),
		Size = UDim2.new(1, -44, 0, 30),
		Visible = false,
		Parent = rightPane,
	})
	local shopPremiumButtons = {}
	for index, filterName in ipairs({ "All", "Packs", "Passes", "Supporter" }) do
		local filterButton = createButton(shopPremiumFilters, filterName .. "ShopPremiumFilter", filterName, UDim2.new(0, 102, 0, 26), UDim2.new(0, (index - 1) * 108, 0, 0), Theme.Colors.Backdrop)
		filterButton.AnchorPoint = Vector2.new(0, 0)
		setFixedText(filterButton, 12, Enum.TextXAlignment.Center)
		shopPremiumButtons[filterName] = filterButton
	end
	local shopItemsFrame = createListFrame(rightPane, "Items", UDim2.new(0, 22, 0, 232), UDim2.new(1, -44, 1, -254))
	shopItemsFrame.BackgroundColor3 = Color3.fromRGB(82, 94, 108)
	local shopEmptyLabel = label(rightPane, "Empty", "This quartermaster lane is still waiting for inventory.", UDim2.new(0, 28, 0, 252), UDim2.new(1, -56, 0, 22), Theme.Fonts.Body, Color3.fromRGB(255, 241, 220), Enum.TextXAlignment.Center)
	setFixedText(shopEmptyLabel, 14, Enum.TextXAlignment.Center)
	shopEmptyLabel.Visible = false
	local closeShopButton = createButton(shopPopup, "CloseShopButton", "Close", UDim2.new(0, 122, 0, 44), UDim2.new(1, -28, 0, 56), Color3.fromRGB(56, 68, 82))
	closeShopButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(closeShopButton, 19, Enum.TextXAlignment.Center)
	lobbyRefs.Popups.Shop = shopPopup
	lobbyRefs.ShopBody = shopBody
	lobbyRefs.LoadoutSummary = loadoutSummary
	lobbyRefs.StatsSummary = statsSummary
	lobbyRefs.SkillSummary = skillSummary
	lobbyRefs.ShopStatus = shopStatus
	lobbyRefs.ShopRarityButtons = shopRarityButtons
	lobbyRefs.ShopPremiumFilters = shopPremiumFilters
	lobbyRefs.ShopPremiumButtons = shopPremiumButtons
	lobbyRefs.ShopTabs = shopTabs
	lobbyRefs.ShopItemsFrame = shopItemsFrame
	lobbyRefs.ShopEmptyLabel = shopEmptyLabel
	lobbyRefs.CloseShopButton = closeShopButton
	lobbyRefs.ClaimDailyButton = claimDailyButton
	lobbyRefs.DailyRewardStatus = dailyRewardStatus
	end

	do
	local inventoryPopup = createPopup(lobby, "InventoryPopup", UDim2.new(0, 1080, 0, 650), UDim2.new(0.07, 0, 0.08, 0), {
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
		Position = UDim2.new(0, 30, 0, 118),
		Size = UDim2.new(1, -60, 0, 2),
		Parent = inventoryPopup,
	})
	addCorner(inventoryHeaderRule, UDim.new(0, 4))
	local inventoryAccent = new("Frame", {
		Name = "HeaderAccent",
		BackgroundColor3 = Color3.fromRGB(120, 148, 196),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, 86),
		Size = UDim2.new(0, 168, 0, 4),
		Parent = inventoryPopup,
	})
	addCorner(inventoryAccent, UDim.new(0, 6))
	local inventoryLeftRail = new("Frame", {
		Name = "LeftRail",
		BackgroundColor3 = Color3.fromRGB(38, 46, 62),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 28, 0, 144),
		Size = UDim2.new(0, 280, 1, -176),
		Parent = inventoryPopup,
	})
	addCorner(inventoryLeftRail, UDim.new(0, 18))
	addStroke(inventoryLeftRail, Color3.fromRGB(120, 148, 196), 0.18, 1)
	local inventoryRightPane = new("Frame", {
		Name = "RightPane",
		BackgroundColor3 = Color3.fromRGB(30, 38, 52),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 326, 0, 144),
		Size = UDim2.new(1, -354, 1, -176),
		Parent = inventoryPopup,
	})
	addCorner(inventoryRightPane, UDim.new(0, 18))
	addStroke(inventoryRightPane, Color3.fromRGB(120, 148, 196), 0.22, 1)
	createStationMark(inventoryRightPane, "InventoryMark", "IV", "KIT", UDim2.new(1, -136, 0, 18), Color3.fromRGB(120, 148, 196))
	local inventoryTitle = label(inventoryPopup, "Title", "Locker Inventory", UDim2.new(0, 30, 0, 58), UDim2.new(1, -190, 0, 34), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(inventoryTitle, 31)
	local inventoryBody = label(inventoryPopup, "Body", "Review owned weapons and cosmetics, then swap your active bunker loadout.", UDim2.new(0, 30, 0, 94), UDim2.new(1, -220, 0, 32), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(inventoryBody, 15)
	local inventorySummaryCard = createInsetCard(inventoryLeftRail, "SummaryCard", UDim2.new(0, 18, 0, 18), UDim2.new(1, -36, 0, 176), Color3.fromRGB(42, 50, 66), Color3.fromRGB(120, 148, 196))
	local inventoryLoadoutSummary = label(inventorySummaryCard, "LoadoutSummary", "Weapon: Training Blade | Cosmetic: None", UDim2.new(0, 14, 0, 16), UDim2.new(1, -28, 0, 40), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(inventoryLoadoutSummary, 18)
	local inventoryWeaponStats = label(inventorySummaryCard, "WeaponStats", "Damage: -- | Range: -- | Rate: --", UDim2.new(0, 14, 0, 66), UDim2.new(1, -28, 0, 18), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	setFixedText(inventoryWeaponStats, 13)
	local inventoryWeaponXp = label(inventorySummaryCard, "WeaponXp", "Bunker XP: 0/100 | Weapon XP: not tracked", UDim2.new(0, 14, 0, 88), UDim2.new(1, -28, 0, 18), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(inventoryWeaponXp, 12)
	local inventoryBonusSummary = label(inventorySummaryCard, "BonusSummary", "Skill Bonus: none", UDim2.new(0, 14, 0, 110), UDim2.new(1, -28, 0, 30), Theme.Fonts.Body, Color3.fromRGB(214, 228, 255))
	setFixedText(inventoryBonusSummary, 12)
	local inventoryStatsSummary = label(inventorySummaryCard, "StatsSummary", "Missions: 0 | Kills: 0", UDim2.new(0, 14, 0, 144), UDim2.new(1, -28, 0, 18), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(inventoryStatsSummary, 13)
	local inventorySkillSummary = label(inventorySummaryCard, "SkillSummary", "Bunker Level 1 | 0 skill points ready", UDim2.new(0, 14, 0, 162), UDim2.new(1, -28, 0, 14), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	setFixedText(inventorySkillSummary, 13)
	local inventoryTabCard = createInsetCard(inventoryLeftRail, "TabCard", UDim2.new(0, 18, 0, 210), UDim2.new(1, -36, 0, 154), Color3.fromRGB(38, 46, 60), Color3.fromRGB(120, 148, 196))
	local inventoryTabTitle = label(inventoryTabCard, "Title", "Locker Sections", UDim2.new(0, 14, 0, 14), UDim2.new(1, -28, 0, 22), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(inventoryTabTitle, 18)
	local inventoryTabBody = label(inventoryTabCard, "Body", "Weapons change combat handling. Cosmetics only affect look and hub presence.", UDim2.new(0, 14, 0, 40), UDim2.new(1, -28, 0, 42), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(inventoryTabBody, 12)
	local inventoryWeaponTab = createButton(inventoryTabCard, "WeaponTab", "Weapons", UDim2.new(1, -28, 0, 42), UDim2.new(0, 14, 0, 92), Color3.fromRGB(92, 122, 176))
	inventoryWeaponTab.AnchorPoint = Vector2.new(0, 0)
	setFixedText(inventoryWeaponTab, 18, Enum.TextXAlignment.Center)
	local inventoryCosmeticTab = createButton(inventoryTabCard, "CosmeticTab", "Cosmetics", UDim2.new(1, -28, 0, 42), UDim2.new(0, 14, 0, 140), Color3.fromRGB(84, 128, 184))
	inventoryCosmeticTab.AnchorPoint = Vector2.new(0, 0)
	setFixedText(inventoryCosmeticTab, 18, Enum.TextXAlignment.Center)
	local inventoryRailFooter = label(inventoryLeftRail, "RailFooter", "Inventory only shows owned gear. Use the shop when you need to unlock more stock.", UDim2.new(0, 18, 1, -56), UDim2.new(1, -36, 0, 32), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(inventoryRailFooter, 11)
	local inventoryStatus = label(inventoryRightPane, "Status", "Owned gear appears here. Equip a weapon or cosmetic from the locker.", UDim2.new(0, 20, 0, 22), UDim2.new(1, -40, 0, 22), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	setFixedText(inventoryStatus, 15)
	local inventoryRarityFilters = new("Frame", {
		Name = "RarityFilters",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 20, 0, 52),
		Size = UDim2.new(1, -40, 0, 30),
		Parent = inventoryRightPane,
	})
	local inventoryRarityButtons = {}
	for index, filterName in ipairs({ "All", "Common", "Uncommon", "Rare", "Epic", "Supporter" }) do
		local filterButton = createButton(inventoryRarityFilters, filterName .. "InventoryRarityFilter", filterName, UDim2.new(0, 92, 0, 26), UDim2.new(0, (index - 1) * 98, 0, 0), Theme.Colors.Backdrop)
		filterButton.AnchorPoint = Vector2.new(0, 0)
		setFixedText(filterButton, 12, Enum.TextXAlignment.Center)
		inventoryRarityButtons[filterName] = filterButton
	end
	local inventoryItemsFrame = createListFrame(inventoryRightPane, "Items", UDim2.new(0, 20, 0, 88), UDim2.new(1, -40, 1, -112))
	inventoryItemsFrame.BackgroundColor3 = Color3.fromRGB(24, 30, 40)
	local inventoryEmptyLabel = label(inventoryRightPane, "Empty", "You do not own any items in this locker section yet.", UDim2.new(0, 24, 0, 104), UDim2.new(1, -48, 0, 24), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Center)
	setFixedText(inventoryEmptyLabel, 15, Enum.TextXAlignment.Center)
	inventoryEmptyLabel.Visible = false
	local closeInventoryButton = createButton(inventoryPopup, "CloseInventoryButton", "Close", UDim2.new(0, 122, 0, 44), UDim2.new(1, -28, 0, 56), Theme.Colors.Backdrop)
	closeInventoryButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(closeInventoryButton, 19, Enum.TextXAlignment.Center)
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
	lobbyRefs.InventoryItemsFrame = inventoryItemsFrame
	lobbyRefs.InventoryEmptyLabel = inventoryEmptyLabel
	lobbyRefs.InventoryWeaponTab = inventoryWeaponTab
	lobbyRefs.InventoryCosmeticTab = inventoryCosmeticTab
	lobbyRefs.CloseInventoryButton = closeInventoryButton
	end

	do
	local skillTreePopup = createPopup(lobby, "SkillTreePopup", UDim2.new(0, 1100, 0, 650), UDim2.new(0.04, 0, 0.08, 0), {
		backgroundColor = Color3.fromRGB(48, 58, 70),
		gradientStart = Color3.fromRGB(62, 74, 88),
		gradientEnd = Color3.fromRGB(36, 44, 54),
		strokeColor = Color3.fromRGB(138, 154, 166),
		headerColor = Color3.fromRGB(88, 118, 152),
		headerColorEnd = Color3.fromRGB(52, 72, 96),
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
		BackgroundColor3 = Color3.fromRGB(138, 154, 166),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, 118),
		Size = UDim2.new(1, -60, 0, 2),
		Parent = skillTreePopup,
	})
	addCorner(skillTreeHeaderRule, UDim.new(0, 4))
	local skillTreeAccent = new("Frame", {
		Name = "HeaderAccent",
		BackgroundColor3 = Color3.fromRGB(138, 154, 166),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 30, 0, 86),
		Size = UDim2.new(0, 168, 0, 4),
		Parent = skillTreePopup,
	})
	addCorner(skillTreeAccent, UDim.new(0, 6))
	local skillTreeLeftRail = new("Frame", {
		Name = "LeftRail",
		BackgroundColor3 = Color3.fromRGB(38, 48, 58),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 28, 0, 144),
		Size = UDim2.new(0, 302, 1, -176),
		Parent = skillTreePopup,
	})
	addCorner(skillTreeLeftRail, UDim.new(0, 18))
	addStroke(skillTreeLeftRail, Color3.fromRGB(138, 154, 166), 0.2, 1)
	local skillTreeRightPane = new("Frame", {
		Name = "RightPane",
		BackgroundColor3 = Color3.fromRGB(30, 38, 46),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 348, 0, 144),
		Size = UDim2.new(1, -376, 1, -176),
		Parent = skillTreePopup,
	})
	addCorner(skillTreeRightPane, UDim.new(0, 18))
	addStroke(skillTreeRightPane, Color3.fromRGB(138, 154, 166), 0.22, 1)
	createStationMark(skillTreeRightPane, "SkillMark", "SK", "TREE", UDim2.new(1, -136, 0, 18), Color3.fromRGB(138, 154, 166))
	local skillTreeTitle = label(skillTreePopup, "Title", "Bunker Skill Tree", UDim2.new(0, 30, 0, 58), UDim2.new(1, -190, 0, 34), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(skillTreeTitle, 31)
	local skillTreeBody = label(skillTreePopup, "Body", "Spend points across Survivor, Combat, and Logistics. Deeper nodes unlock off earlier training.", UDim2.new(0, 30, 0, 94), UDim2.new(1, -220, 0, 32), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(skillTreeBody, 15)
	local skillTreeSummaryCard = createInsetCard(skillTreeLeftRail, "SummaryCard", UDim2.new(0, 18, 0, 18), UDim2.new(1, -36, 0, 112), Color3.fromRGB(42, 52, 64), Color3.fromRGB(138, 154, 166))
	local skillTreeSummary = label(skillTreeSummaryCard, "Summary", "Level 1 | XP 0/100 | 0 points ready", UDim2.new(0, 14, 0, 14), UDim2.new(1, -28, 0, 44), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(skillTreeSummary, 18)
	local skillTreeBranchCopy = label(skillTreeSummaryCard, "BranchCopy", "Survivor keeps you alive. Combat sharpens pressure. Logistics boosts payout.", UDim2.new(0, 14, 0, 58), UDim2.new(1, -28, 0, 32), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(skillTreeBranchCopy, 12)
	local skillTreeStatusCard = createInsetCard(skillTreeLeftRail, "StatusCard", UDim2.new(0, 18, 0, 140), UDim2.new(1, -36, 0, 96), Color3.fromRGB(36, 46, 56), Color3.fromRGB(138, 154, 166))
	local skillTreeStatus = label(skillTreeStatusCard, "Status", "Allocate points to unlock deeper branch nodes.", UDim2.new(0, 14, 0, 14), UDim2.new(1, -28, 0, 42), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	setFixedText(skillTreeStatus, 14)
	local skillTreeRespecCopy = label(skillTreeStatusCard, "RespecCopy", "Respec refunds every spent point from your current level progress.", UDim2.new(0, 14, 0, 58), UDim2.new(1, -28, 0, 24), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(skillTreeRespecCopy, 12)
	local respecSkillTreeButton = createButton(skillTreeLeftRail, "RespecSkillTreeButton", "Respec Tree", UDim2.new(1, -36, 0, 44), UDim2.new(0, 18, 0, 250), Theme.Colors.AccentWarm)
	respecSkillTreeButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(respecSkillTreeButton, 18, Enum.TextXAlignment.Center)
	local skillTreeBranchGuide = createInsetCard(skillTreeLeftRail, "BranchGuide", UDim2.new(0, 18, 0, 308), UDim2.new(1, -36, 0, 104), Color3.fromRGB(40, 50, 62), Color3.fromRGB(138, 154, 166))
	local branchGuideTitle = label(skillTreeBranchGuide, "Title", "Branch Guide", UDim2.new(0, 14, 0, 12), UDim2.new(1, -28, 0, 22), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(branchGuideTitle, 17)
	for index, branchId in ipairs(Theme.SkillTreeBranchOrder) do
		local branch = Theme.SkillTreeBranches[branchId]
		if branch then
			local row = new("Frame", {
				Name = branchId .. "Row",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 14, 0, 40 + ((index - 1) * 20)),
				Size = UDim2.new(1, -28, 0, 16),
				Parent = skillTreeBranchGuide,
			})
			local chip = new("TextLabel", {
				Name = "Chip",
				BackgroundColor3 = branch.Color,
				BackgroundTransparency = 0.1,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(0, 16, 0, 16),
				Text = branch.Icon,
				TextColor3 = Theme.Colors.Text,
				TextScaled = false,
				TextSize = 8,
				Font = Theme.Fonts.Heading,
				Parent = row,
			})
			addCorner(chip, UDim.new(0, 6))
			addStroke(chip, branch.Color, 0.18, 1)
			local rowLabel = label(row, "Label", branch.ShortLabel or branch.DisplayName or branchId, UDim2.new(0, 24, 0, -1), UDim2.new(1, -24, 0, 16), Theme.Fonts.Body, Theme.Colors.Muted)
			setFixedText(rowLabel, 12)
		end
	end
	local skillTreeRailFooter = label(skillTreeLeftRail, "RailFooter", "Left rail: summary and reset. Right board: live node graph.", UDim2.new(0, 18, 1, -42), UDim2.new(1, -36, 0, 18), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(skillTreeRailFooter, 10)
	local skillTreeList = createListFrame(skillTreeRightPane, "SkillTreeItems", UDim2.new(0, 20, 0, 92), UDim2.new(1, -40, 1, -242))
	skillTreeList.BackgroundColor3 = Color3.fromRGB(23, 30, 36)
	skillTreeList.AutomaticCanvasSize = Enum.AutomaticSize.None
	local skillTreeEmpty = label(skillTreeRightPane, "Empty", "No skill nodes are available yet.", UDim2.new(0, 24, 0, 106), UDim2.new(1, -48, 0, 24), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Center)
	setFixedText(skillTreeEmpty, 15, Enum.TextXAlignment.Center)
	skillTreeEmpty.Visible = false
	local skillTreePaneTitle = label(skillTreeRightPane, "PaneTitle", "Branch Nodes", UDim2.new(0, 20, 0, 16), UDim2.new(1, -40, 0, 24), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(skillTreePaneTitle, 22)
	local skillTreePaneSub = label(skillTreeRightPane, "PaneSub", "Filter by branch to focus one lane, or keep all branches visible.", UDim2.new(0, 20, 0, 44), UDim2.new(1, -176, 0, 32), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(skillTreePaneSub, 14)
	local skillTreeFilterRow = new("Frame", {
		Name = "FilterRow",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 20, 0, 78),
		Size = UDim2.new(1, -40, 0, 28),
		Parent = skillTreeRightPane,
	})
	local skillTreeFilterButtons = {}
	local filterNames = { "All", "Survivor", "Combat", "Logistics" }
	for index, filterName in ipairs(filterNames) do
		local filterButton = createButton(skillTreeFilterRow, filterName .. "FilterButton", filterName, UDim2.new(0, 110, 0, 28), UDim2.new(0, (index - 1) * 118, 0, 0), Theme.Colors.Backdrop)
		filterButton.AnchorPoint = Vector2.new(0, 0)
		setFixedText(filterButton, 13, Enum.TextXAlignment.Center)
		skillTreeFilterButtons[filterName] = filterButton
	end
	local skillTreePaneRule = new("Frame", {
		Name = "PaneRule",
		BackgroundColor3 = Color3.fromRGB(138, 154, 166),
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 20, 0, 114),
		Size = UDim2.new(1, -40, 0, 1),
		Parent = skillTreeRightPane,
	})
	local skillTreeDetailCard = createInsetCard(skillTreeRightPane, "DetailCard", UDim2.new(0, 20, 1, -136), UDim2.new(1, -40, 0, 112), Color3.fromRGB(34, 42, 50), Color3.fromRGB(138, 154, 166))
	local skillTreeDetailTitle = label(skillTreeDetailCard, "Title", "Select a node", UDim2.new(0, 14, 0, 12), UDim2.new(1, -180, 0, 22), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(skillTreeDetailTitle, 18)
	local skillTreeDetailMeta = label(skillTreeDetailCard, "Meta", "Choose a skill card to inspect its branch, rank, and unlock path.", UDim2.new(0, 14, 0, 36), UDim2.new(1, -180, 0, 16), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	setFixedText(skillTreeDetailMeta, 12)
	local skillTreeDetailBody = label(skillTreeDetailCard, "Body", "Detailed skill information appears here.", UDim2.new(0, 14, 0, 56), UDim2.new(1, -180, 0, 36), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(skillTreeDetailBody, 12)
	local skillTreeDetailBonus = new("TextLabel", {
		Name = "Bonus",
		BackgroundColor3 = Color3.fromRGB(112, 84, 54),
		BorderSizePixel = 0,
		Position = UDim2.new(1, -166, 0, 16),
		Size = UDim2.new(0, 150, 0, 22),
		Text = "NO NODE",
		TextColor3 = Theme.Colors.Text,
		TextScaled = false,
		TextSize = 11,
		Font = Theme.Fonts.Heading,
		Parent = skillTreeDetailCard,
	})
	addCorner(skillTreeDetailBonus, UDim.new(0, 8))
	addStroke(skillTreeDetailBonus, Color3.fromRGB(112, 84, 54), 0.18, 1)
	local skillTreeDetailRank = label(skillTreeDetailCard, "Rank", "Rank --/--", UDim2.new(1, -166, 0, 46), UDim2.new(0, 150, 0, 16), Theme.Fonts.Heading, Theme.Colors.Text, Enum.TextXAlignment.Right)
	setFixedText(skillTreeDetailRank, 12, Enum.TextXAlignment.Right)
	local skillTreeDetailState = label(skillTreeDetailCard, "State", "State: --", UDim2.new(1, -166, 0, 66), UDim2.new(0, 150, 0, 16), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Right)
	setFixedText(skillTreeDetailState, 11, Enum.TextXAlignment.Right)
	local closeSkillTreeButton = createButton(skillTreePopup, "CloseSkillTreeButton", "Close", UDim2.new(0, 122, 0, 44), UDim2.new(1, -28, 0, 56), Theme.Colors.Backdrop)
	closeSkillTreeButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(closeSkillTreeButton, 19, Enum.TextXAlignment.Center)
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
	local respecConfirmPopup = createPopup(lobby, "RespecConfirmPopup", UDim2.new(0, 470, 0, 248), UDim2.new(0.58, 0, 0.16, 0), {
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

	local settingsPopup = createPopup(lobby, "SettingsPopup", UDim2.new(0, 520, 0, 320), UDim2.new(0.6, 0, 0.12, 0), {
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
	local settingsSummary = label(settingsPopup, "Summary", "UI audio and screen shake are active.", UDim2.new(0, 24, 0, 172), UDim2.new(1, -48, 0, 22), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	setFixedText(settingsSummary, 14)
	local toggleUiAudioButton = createButton(settingsPopup, "ToggleUiAudioButton", "UI Audio: On", UDim2.new(0, 220, 0, 44), UDim2.new(0, 24, 1, -64), Theme.Colors.AccentWarm)
	toggleUiAudioButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(toggleUiAudioButton, 17, Enum.TextXAlignment.Center)
	local toggleScreenShakeButton = createButton(settingsPopup, "ToggleScreenShakeButton", "Screen Shake: On", UDim2.new(0, 220, 0, 44), UDim2.new(0, 256, 1, -64), Color3.fromRGB(86, 122, 176))
	toggleScreenShakeButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(toggleScreenShakeButton, 17, Enum.TextXAlignment.Center)
	local closeSettingsButton = createButton(settingsPopup, "CloseSettingsButton", "Close", UDim2.new(0, 112, 0, 40), UDim2.new(1, -24, 0, 20), Theme.Colors.Backdrop)
	closeSettingsButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(closeSettingsButton, 16, Enum.TextXAlignment.Center)
	lobbyRefs.Popups.Settings = settingsPopup
	lobbyRefs.SettingsPopup = settingsPopup
	lobbyRefs.SettingsSummary = settingsSummary
	lobbyRefs.ToggleUiAudioButton = toggleUiAudioButton
	lobbyRefs.ToggleScreenShakeButton = toggleScreenShakeButton
	lobbyRefs.CloseSettingsButton = closeSettingsButton

	local adminPopup = createPopup(lobby, "AdminPopup", UDim2.new(0, 540, 0, 442), UDim2.new(0.58, 0, 0.11, 0), {
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
	local adminTitle = label(adminPopup, "Title", "Owner Control Panel", UDim2.new(0, 24, 0, 62), UDim2.new(1, -48, 0, 28), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(adminTitle, 24)
	local adminBody = label(adminPopup, "Body", "Run quick owner/admin commands without leaving the game session.", UDim2.new(0, 24, 0, 98), UDim2.new(1, -48, 0, 38), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(adminBody, 15)
	local adminSummary = label(adminPopup, "Summary", "Commands ready.", UDim2.new(0, 24, 0, 146), UDim2.new(1, -48, 0, 22), Theme.Fonts.Body, Color3.fromRGB(255, 226, 166))
	setFixedText(adminSummary, 14)
	local adminHealButton = createButton(adminPopup, "HealButton", "Heal Self", UDim2.new(0, 230, 0, 42), UDim2.new(0, 24, 0, 196), Color3.fromRGB(94, 156, 108))
	adminHealButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(adminHealButton, 16, Enum.TextXAlignment.Center)
	local adminHealSquadButton = createButton(adminPopup, "HealSquadButton", "Heal Squad", UDim2.new(0, 230, 0, 42), UDim2.new(0, 286, 0, 196), Color3.fromRGB(82, 146, 118))
	adminHealSquadButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(adminHealSquadButton, 16, Enum.TextXAlignment.Center)
	local adminTokensButton = createButton(adminPopup, "TokensButton", "+250 Tokens", UDim2.new(0, 230, 0, 42), UDim2.new(0, 286, 0, 196), Color3.fromRGB(188, 142, 76))
	adminTokensButton.Position = UDim2.new(0, 24, 0, 248)
	adminTokensButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(adminTokensButton, 16, Enum.TextXAlignment.Center)
	local adminTokensLargeButton = createButton(adminPopup, "TokensLargeButton", "+1000 Tokens", UDim2.new(0, 230, 0, 42), UDim2.new(0, 286, 0, 248), Color3.fromRGB(204, 158, 84))
	adminTokensLargeButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(adminTokensLargeButton, 16, Enum.TextXAlignment.Center)
	local adminXpButton = createButton(adminPopup, "XpButton", "+250 XP", UDim2.new(0, 230, 0, 42), UDim2.new(0, 24, 0, 300), Color3.fromRGB(88, 132, 188))
	adminXpButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(adminXpButton, 16, Enum.TextXAlignment.Center)
	local adminXpLargeButton = createButton(adminPopup, "XpLargeButton", "+1000 XP", UDim2.new(0, 230, 0, 42), UDim2.new(0, 286, 0, 300), Color3.fromRGB(102, 144, 204))
	adminXpLargeButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(adminXpLargeButton, 16, Enum.TextXAlignment.Center)
	local adminReviveSquadButton = createButton(adminPopup, "ReviveSquadButton", "Revive Squad", UDim2.new(0, 230, 0, 42), UDim2.new(0, 24, 0, 352), Color3.fromRGB(92, 168, 132))
	adminReviveSquadButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(adminReviveSquadButton, 16, Enum.TextXAlignment.Center)
	local adminReturnButton = createButton(adminPopup, "ReturnButton", "Return To Lobby", UDim2.new(0, 230, 0, 42), UDim2.new(0, 286, 0, 352), Color3.fromRGB(168, 92, 92))
	adminReturnButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(adminReturnButton, 16, Enum.TextXAlignment.Center)
	local adminRefreshButton = createButton(adminPopup, "RefreshButton", "Refresh Access", UDim2.new(0, 176, 0, 40), UDim2.new(0, 24, 1, -54), Theme.Colors.Backdrop)
	adminRefreshButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(adminRefreshButton, 15, Enum.TextXAlignment.Center)
	local closeAdminButton = createButton(adminPopup, "CloseAdminButton", "Close", UDim2.new(0, 112, 0, 40), UDim2.new(1, -24, 1, -54), Theme.Colors.Backdrop)
	closeAdminButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(closeAdminButton, 16, Enum.TextXAlignment.Center)
	lobbyRefs.Popups.Admin = adminPopup
	lobbyRefs.AdminPopup = adminPopup
	lobbyRefs.AdminSummary = adminSummary
	lobbyRefs.AdminHealButton = adminHealButton
	lobbyRefs.AdminHealSquadButton = adminHealSquadButton
	lobbyRefs.AdminTokensButton = adminTokensButton
	lobbyRefs.AdminTokensLargeButton = adminTokensLargeButton
	lobbyRefs.AdminXpButton = adminXpButton
	lobbyRefs.AdminXpLargeButton = adminXpLargeButton
	lobbyRefs.AdminReviveSquadButton = adminReviveSquadButton
	lobbyRefs.AdminReturnButton = adminReturnButton
	lobbyRefs.AdminRefreshButton = adminRefreshButton
	lobbyRefs.CloseAdminButton = closeAdminButton

	local npcDialoguePopup = createPopup(lobby, "NpcDialoguePopup", UDim2.new(0, 520, 0, 286), UDim2.new(0.59, 0, 0.14, 0), {
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

	local questBoardPopup = createPopup(lobby, "QuestBoardPopup", UDim2.new(0, 560, 0, 456), UDim2.new(0.56, 0, 0.12, 0), {
		backgroundColor = Color3.fromRGB(42, 48, 38),
		gradientStart = Color3.fromRGB(58, 68, 50),
		gradientEnd = Color3.fromRGB(28, 34, 24),
		strokeColor = Color3.fromRGB(182, 198, 122),
		headerColor = Color3.fromRGB(120, 144, 74),
		headerColorEnd = Color3.fromRGB(74, 92, 44),
		badgeText = "OPS",
		badgeColor = Color3.fromRGB(74, 90, 48),
		iconText = "OBJ",
		visible = false,
	})
	local questBoardBadgeNode = questBoardPopup:FindFirstChild("Badge")
	if questBoardBadgeNode and questBoardBadgeNode:IsA("GuiObject") then
		questBoardBadgeNode.Visible = false
	end
	local questBoardEmblemNode = questBoardPopup:FindFirstChild("Emblem")
	if questBoardEmblemNode and questBoardEmblemNode:IsA("GuiObject") then
		questBoardEmblemNode.Visible = false
	end
	local questBoardRule = new("Frame", {
		Name = "HeaderRule",
		BackgroundColor3 = Color3.fromRGB(188, 214, 128),
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 24, 0, 112),
		Size = UDim2.new(1, -48, 0, 2),
		Parent = questBoardPopup,
	})
	addCorner(questBoardRule, UDim.new(0, 4))
	local questBoardTitle = label(questBoardPopup, "Title", "Operations Board", UDim2.new(0, 24, 0, 62), UDim2.new(1, -48, 0, 28), Theme.Fonts.Heading, Theme.Colors.Text)
	setFixedText(questBoardTitle, 26)
	local questBoardBody = label(questBoardPopup, "Body", "Track daily bunker objectives and supporter crate timing from one board.", UDim2.new(0, 24, 0, 98), UDim2.new(1, -48, 0, 20), Theme.Fonts.Body, Theme.Colors.Muted)
	setFixedText(questBoardBody, 14)
	local dailyQuestTitle = label(questBoardPopup, "DailyQuestTitle", "Daily Objective", UDim2.new(0, 24, 0, 132), UDim2.new(0.44, -18, 0, 18), Theme.Fonts.Heading, Color3.fromRGB(236, 244, 208))
	setFixedText(dailyQuestTitle, 17)
	local dailyQuestBody = label(questBoardPopup, "DailyQuestBody", "Claim the daily bunker stipend to keep your deployment budget healthy.", UDim2.new(0, 24, 0, 156), UDim2.new(0.44, -18, 0, 44), Theme.Fonts.Body, Color3.fromRGB(212, 224, 184))
	setFixedText(dailyQuestBody, 13)
	local dailyQuestStatus = label(questBoardPopup, "DailyQuestStatus", "Daily reward ready.", UDim2.new(0, 24, 0, 204), UDim2.new(0.44, -18, 0, 24), Theme.Fonts.Body, Color3.fromRGB(220, 239, 164))
	setFixedText(dailyQuestStatus, 14)
	local weeklyQuestTitle = label(questBoardPopup, "WeeklyQuestTitle", "Weekly Supporter Crate", UDim2.new(0.52, 0, 0, 132), UDim2.new(0.44, -18, 0, 18), Theme.Fonts.Heading, Color3.fromRGB(244, 232, 182))
	setFixedText(weeklyQuestTitle, 17)
	local weeklyQuestBody = label(questBoardPopup, "WeeklyQuestBody", "Supporter access unlocks a weekly logistics crate with tokens and skill tree XP.", UDim2.new(0.52, 0, 0, 156), UDim2.new(0.44, -18, 0, 44), Theme.Fonts.Body, Color3.fromRGB(226, 214, 174))
	setFixedText(weeklyQuestBody, 13)
	local weeklyQuestStatus = label(questBoardPopup, "WeeklyQuestStatus", "Supporter access inactive.", UDim2.new(0.52, 0, 0, 204), UDim2.new(0.44, -18, 0, 24), Theme.Fonts.Body, Color3.fromRGB(240, 214, 148))
	setFixedText(weeklyQuestStatus, 14)
	local questOpsList = createListFrame(questBoardPopup, "QuestOpsList", UDim2.new(0, 24, 0, 242), UDim2.new(1, -48, 0, 128))
	local questOpsEmpty = label(questBoardPopup, "QuestOpsEmpty", "Daily ops offline.", UDim2.new(0, 24, 0, 280), UDim2.new(1, -48, 0, 24), Theme.Fonts.Body, Theme.Colors.Muted, Enum.TextXAlignment.Center)
	setFixedText(questOpsEmpty, 14)
	local questBoardSummary = label(questBoardPopup, "Summary", "Complete the daily cycle and return each week for the supporter crate.", UDim2.new(0, 24, 1, -102), UDim2.new(1, -48, 0, 24), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	setFixedText(questBoardSummary, 14)
	local claimDailyQuestButton = createButton(questBoardPopup, "ClaimDailyQuestButton", "Claim Daily", UDim2.new(0, 184, 0, 42), UDim2.new(0, 24, 1, -58), Theme.Colors.AccentWarm)
	claimDailyQuestButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(claimDailyQuestButton, 16, Enum.TextXAlignment.Center)
	local claimWeeklyQuestButton = createButton(questBoardPopup, "ClaimWeeklyQuestButton", "Claim Weekly", UDim2.new(0, 184, 0, 42), UDim2.new(0, 220, 1, -58), Color3.fromRGB(180, 154, 86))
	claimWeeklyQuestButton.AnchorPoint = Vector2.new(0, 0)
	setFixedText(claimWeeklyQuestButton, 16, Enum.TextXAlignment.Center)
	local closeQuestBoardButton = createButton(questBoardPopup, "CloseQuestBoardButton", "Close", UDim2.new(0, 112, 0, 42), UDim2.new(1, -24, 1, -58), Theme.Colors.Backdrop)
	closeQuestBoardButton.AnchorPoint = Vector2.new(1, 0)
	setFixedText(closeQuestBoardButton, 16, Enum.TextXAlignment.Center)
	lobbyRefs.Popups.QuestBoard = questBoardPopup
	lobbyRefs.QuestBoardPopup = questBoardPopup
	lobbyRefs.DailyQuestStatus = dailyQuestStatus
	lobbyRefs.WeeklyQuestStatus = weeklyQuestStatus
	lobbyRefs.QuestOpsList = questOpsList
	lobbyRefs.QuestOpsEmpty = questOpsEmpty
	lobbyRefs.QuestBoardSummary = questBoardSummary
	lobbyRefs.ClaimDailyQuestButton = claimDailyQuestButton
	lobbyRefs.ClaimWeeklyQuestButton = claimWeeklyQuestButton
	lobbyRefs.CloseQuestBoardButton = closeQuestBoardButton

	local lobbyStatus = label(lobby, "LobbyStatus", Theme.StatusCopy.Lobby, UDim2.new(0.05, 0, 0.93, 0), UDim2.new(0.4, 0, 0.04, 0), Theme.Fonts.Body, Theme.Colors.AccentSoft)
	lobbyStatus.Visible = false
	lobbyRefs.LobbyStatus = lobbyStatus

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
	local resultsSummaryCard = createInsetCard(resultsLeft, "SummaryCard", UDim2.new(0, 18, 0, 18), UDim2.new(1, -36, 0, 168), Color3.fromRGB(42, 52, 64), Color3.fromRGB(138, 154, 166))
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
	local resultsStatsCard = createInsetCard(resultsRight, "StatsCard", UDim2.new(0, 20, 0, 64), UDim2.new(1, -40, 0, 264), Color3.fromRGB(34, 42, 50), Color3.fromRGB(138, 154, 166))
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
