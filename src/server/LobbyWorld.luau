local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent:WaitForChild("LobbyWorldConfig"))
local DonationConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("DonationConfig"))

local LobbyWorld = {}
local clearNamedChildren

local REQUIRED_LOBBY_TEMPLATE_PARTS = {
	"OuterGround",
	"VoteBoard",
	"VotePad1",
	"VotePad2",
	"VotePad3",
}

local OPTIONAL_LOBBY_FEATURES = {
	{ label = "deploy pad", names = { "LaunchPad", "DeployPad" } },
	{ label = "leaderboard monument", names = { "LeaderboardMonument", "MasterBoard", "LeaderboardBoard" } },
	{ label = "duel ring", names = { "DuelRing" } },
	{ label = "parkour course", names = { "ParkourCourse" } },
	{ label = "training yard", names = { "TrainingYard" } },
	{ label = "target range", names = { "TargetRange" } },
	{ label = "salvage run", names = { "SalvageRun" } },
	{ label = "supporter lounge", names = { "SupporterLounge", "Supporter" } },
	{ label = "vip lounge", names = { "VipLounge", "Vip" } },
}
local REQUIRED_ACTIVITY_PARTS = {
	TrainingYard = { "EntryPad", "TargetFace1", "TargetFace2", "TargetFace3", "Hurdle1", "Hurdle2", "Hurdle3" },
	ParkourCourse = { "StartPad", "Platform1", "Platform2", "Platform3", "Platform4", "Platform5", "FinishPad" },
	TargetRange = { "FiringLine", "TargetFace1", "TargetFace2", "TargetFace3" },
	SalvageRun = { "StartPad", "Cache1", "Cache2", "Cache3", "FinishPad" },
}

local function clearExisting(rootName: string)
	local existing = Workspace:FindFirstChild(rootName)
	if existing then
		existing:Destroy()
	end
end

local function isConfiguredLobbyRootReady(candidate: Instance?): boolean
	if not (candidate and (candidate:IsA("Model") or candidate:IsA("Folder"))) then
		return false
	end
	if candidate:FindFirstChildWhichIsA("BasePart", true) then
		return true
	end
	return #getLobbyTemplateIssues(candidate) == 0
end

local function waitForConfiguredLobbyRoot(timeoutSeconds: number): Instance?
	if timeoutSeconds == nil then
		while true do
			local candidate = Workspace:FindFirstChild(Config.RootName)
			if isConfiguredLobbyRootReady(candidate) then
				return candidate
			end
			task.wait(0.1)
		end
	end
	local deadline = os.clock() + math.max(0, timeoutSeconds or 0)
	repeat
		local candidate = Workspace:FindFirstChild(Config.RootName)
		if isConfiguredLobbyRootReady(candidate) then
			return candidate
		end
		task.wait(0.1)
	until os.clock() >= deadline
	return nil
end

local function clearLegacyLobbyDuplicates()
	local currentRootName = string.lower((tostring(Config.RootName or ""):gsub("[%s%p_]+", "")))
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("Model") or child:IsA("Folder") then
			local childName = child.Name
			local normalizedName = string.lower((childName:gsub("[%s%p_]+", "")))
			if normalizedName ~= ""
				and normalizedName ~= currentRootName
				and (normalizedName == "mainlobby"
					or normalizedName == "wronglobby"
					or string.find(normalizedName, "lobby", 1, true) ~= nil)
			then
				child:Destroy()
			end
		end
	end
end

local function findFirstNamedDescendant(root: Instance, names: { string }): Instance?
	for _, name in ipairs(names) do
		local found = root:FindFirstChild(name, true)
		if found then
			return found
		end
	end
	return nil
end

local function getLobbyTemplateIssues(template: Instance): { string }
	local issues = {}
	for _, name in ipairs(REQUIRED_LOBBY_TEMPLATE_PARTS) do
		if not template:FindFirstChild(name, true) then
			table.insert(issues, name)
		end
	end

	if not findFirstNamedDescendant(template, { "LaunchPad", "DeployPad" }) then
		table.insert(issues, "LaunchPad/DeployPad")
	end

	return issues
end

local function validateLobbyFeatures(lobbyModel: Instance)
	for _, feature in ipairs(OPTIONAL_LOBBY_FEATURES) do
		if not findFirstNamedDescendant(lobbyModel, feature.names) then
			warn(("[LobbyWorld] Lobby is missing %s. Related systems will stay inactive until that content is added."):format(feature.label))
		end
	end
end

local function hasRequiredActivityParts(activityRoot: Instance?, requiredNames: { string }): boolean
	if not activityRoot then
		return false
	end
	for _, name in ipairs(requiredNames) do
		if not activityRoot:FindFirstChild(name, true) then
			return false
		end
	end
	return true
end

local function ensureCompleteActivityModel(lobbyModel: Instance, activityName: string, requiredNames: { string }, buildFn)
	local existing = lobbyModel:FindFirstChild(activityName, true)
	if existing and hasRequiredActivityParts(existing, requiredNames) then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	return buildFn()
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
	if clearNamedChildren then
		clearNamedChildren(part, { "Sign" })
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(204, 66)
	gui.StudsOffset = Vector3.new(0, 1.9, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
	frame.BackgroundTransparency = 0.04
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 1.6
	stroke.Transparency = 0.08
	stroke.Parent = frame

	local accentBar = Instance.new("Frame")
	accentBar.BackgroundColor3 = accent
	accentBar.BackgroundTransparency = 0.08
	accentBar.BorderSizePixel = 0
	accentBar.Position = UDim2.fromOffset(10, 10)
	accentBar.Size = UDim2.new(0, 4, 1, -20)
	accentBar.Parent = frame

	local accentGlow = Instance.new("Frame")
	accentGlow.BackgroundColor3 = accent
	accentGlow.BackgroundTransparency = 0.7
	accentGlow.BorderSizePixel = 0
	accentGlow.Position = UDim2.fromOffset(18, 10)
	accentGlow.Size = UDim2.new(0, 18, 1, -20)
	accentGlow.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, -44, 0, 24)
	titleLabel.Position = UDim2.fromOffset(30, 8)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = false
	titleLabel.TextSize = 17
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.fromOffset(30, 32)
	subtitleLabel.Size = UDim2.new(1, -42, 0, 24)
	subtitleLabel.Font = Enum.Font.GothamMedium
	subtitleLabel.Text = subtitle
	subtitleLabel.TextColor3 = Color3.fromRGB(222, 228, 236)
	subtitleLabel.TextScaled = false
	subtitleLabel.TextSize = 11
	subtitleLabel.TextWrapped = true
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
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
	if clearNamedChildren then
		clearNamedChildren(part, { "WorldText" })
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldText"
	gui.Size = UDim2.fromOffset((size and size.X) or 160, (size and size.Y) or 38)
	gui.StudsOffset = offset
	gui.AlwaysOnTop = false
	gui.MaxDistance = 110
	gui.LightInfluence = 0
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = accent
	label.TextScaled = false
	label.TextSize = 16
	label.TextStrokeTransparency = 0.72
	label.Parent = gui
end

local function attachDonationShowcase(part: BasePart)
	if clearNamedChildren then
		clearNamedChildren(part, { "DonationBoard" })
	end

	local board = Instance.new("BillboardGui")
	board.Name = "DonationBoard"
	board.Size = UDim2.fromOffset(244, 158)
	board.StudsOffset = Vector3.new(0, 5.1, 0)
	board.AlwaysOnTop = false
	board.MaxDistance = 100
	board.LightInfluence = 0
	board.Parent = part

	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.BackgroundColor3 = Color3.fromRGB(18, 16, 12)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = board

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(244, 206, 126)
	stroke.Thickness = 1.6
	stroke.Transparency = 0.08
	stroke.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 30, 14)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(70, 48, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 20, 10)),
	})
	gradient.Rotation = 18
	gradient.Parent = frame

	local shimmer = Instance.new("Frame")
	shimmer.Name = "Shimmer"
	shimmer.BackgroundColor3 = Color3.fromRGB(255, 230, 170)
	shimmer.BackgroundTransparency = 0.86
	shimmer.BorderSizePixel = 0
	shimmer.Position = UDim2.new(0, -80, 0, 0)
	shimmer.Size = UDim2.new(0, 70, 1, 0)
	shimmer.Rotation = 18
	shimmer.Parent = frame

	local shimmerCorner = Instance.new("UICorner")
	shimmerCorner.CornerRadius = UDim.new(0, 14)
	shimmerCorner.Parent = shimmer

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 14)
	title.Size = UDim2.new(1, -32, 0, 20)
	title.Font = Enum.Font.GothamBlack
	title.Text = "BUNKER SUPPORT"
	title.TextColor3 = Color3.fromRGB(255, 240, 198)
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(16, 34)
	subtitle.Size = UDim2.new(1, -32, 0, 28)
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.Text = "Support new ops, visual polish, and bunker upgrades."
	subtitle.TextColor3 = Color3.fromRGB(234, 224, 198)
	subtitle.TextSize = 11
	subtitle.TextWrapped = true
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextYAlignment = Enum.TextYAlignment.Top
	subtitle.Parent = frame

	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BackgroundColor3 = Color3.fromRGB(244, 206, 126)
	rule.BackgroundTransparency = 0.16
	rule.BorderSizePixel = 0
	rule.Position = UDim2.fromOffset(16, 66)
	rule.Size = UDim2.fromOffset(94, 3)
	rule.Parent = frame

	local pulse = Instance.new("Frame")
	pulse.Name = "Pulse"
	pulse.BackgroundColor3 = Color3.fromRGB(255, 220, 152)
	pulse.BackgroundTransparency = 0.8
	pulse.BorderSizePixel = 0
	pulse.Position = UDim2.fromOffset(16, 66)
	pulse.Size = UDim2.fromOffset(94, 3)
	pulse.Parent = frame

	local tiers = Instance.new("Frame")
	tiers.Name = "Tiers"
	tiers.BackgroundTransparency = 1
	tiers.Position = UDim2.fromOffset(14, 78)
	tiers.Size = UDim2.new(1, -28, 0, 52)
	tiers.Parent = frame

	local tierLayout = Instance.new("UIListLayout")
	tierLayout.FillDirection = Enum.FillDirection.Horizontal
	tierLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	tierLayout.Padding = UDim.new(0, 8)
	tierLayout.Parent = tiers

	local tierBars = {}
	for index, tier in ipairs(DonationConfig.Tiers) do
		if index > 3 then
			break
		end
		local tierCard = Instance.new("Frame")
		tierCard.Name = ("Tier%d"):format(index)
		tierCard.BackgroundColor3 = Color3.fromRGB(36, 28, 18)
		tierCard.BackgroundTransparency = 0.08
		tierCard.BorderSizePixel = 0
		tierCard.Size = UDim2.fromOffset(66, 52)
		tierCard.Parent = tiers

		local tierCorner = Instance.new("UICorner")
		tierCorner.CornerRadius = UDim.new(0, 12)
		tierCorner.Parent = tierCard

		local tierStroke = Instance.new("UIStroke")
		tierStroke.Color = Color3.fromRGB(214, 182, 116)
		tierStroke.Transparency = 0.18
		tierStroke.Parent = tierCard

		local amount = Instance.new("TextLabel")
		amount.Name = "Amount"
		amount.BackgroundTransparency = 1
		amount.Position = UDim2.fromOffset(8, 8)
		amount.Size = UDim2.new(1, -16, 0, 16)
		amount.Font = Enum.Font.GothamBlack
		amount.Text = ("%sT"):format(tostring(math.max(0, math.floor(tonumber(tier.Amount) or 0))))
		amount.TextColor3 = Color3.fromRGB(255, 232, 176)
		amount.TextSize = 15
		amount.TextXAlignment = Enum.TextXAlignment.Left
		amount.Parent = tierCard

		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(8, 24)
		name.Size = UDim2.new(1, -16, 0, 12)
		name.Font = Enum.Font.GothamBold
		name.Text = tostring(tier.Label or ("Tier " .. tostring(index)))
		name.TextColor3 = Color3.fromRGB(226, 220, 202)
		name.TextSize = 10
		name.TextWrapped = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Parent = tierCard

		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.BackgroundColor3 = Color3.fromRGB(244, 206, 126)
		bar.BackgroundTransparency = 0.2
		bar.BorderSizePixel = 0
		bar.Position = UDim2.fromOffset(8, 40)
		bar.Size = UDim2.fromOffset(24 + (index * 8), 4)
		bar.Parent = tierCard

		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(0, 4)
		barCorner.Parent = bar

		table.insert(tierBars, {
			card = tierCard,
			stroke = tierStroke,
			bar = bar,
			phase = index * 0.8,
		})
	end

	local footer = Instance.new("TextLabel")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.Position = UDim2.fromOffset(16, 132)
	footer.Size = UDim2.new(1, -32, 0, 14)
	footer.Font = Enum.Font.GothamMedium
	footer.Text = "Use 1 / 2 / 3 or the prompt to support"
	footer.TextColor3 = Color3.fromRGB(236, 224, 188)
	footer.TextSize = 10
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.Parent = frame

	task.spawn(function()
		while board.Parent and part.Parent do
			local t = os.clock()
			local wave = (math.sin(t * 1.8) + 1) * 0.5
			local shimmerWave = (math.sin(t * 1.2) + 1) * 0.5
			stroke.Color = Color3.fromRGB(244, 206, 126):Lerp(Color3.fromRGB(255, 234, 176), wave * 0.45)
			frame.BackgroundColor3 = Color3.fromRGB(18, 16, 12):Lerp(Color3.fromRGB(34, 26, 16), wave * 0.22)
			title.TextColor3 = Color3.fromRGB(255, 240, 198):Lerp(Color3.fromRGB(255, 248, 220), wave * 0.4)
			rule.Size = UDim2.fromOffset(94 + math.floor(wave * 44), 3)
			pulse.Size = UDim2.fromOffset(110 + math.floor(wave * 74), 3)
			pulse.BackgroundTransparency = 0.88 - (wave * 0.28)
			shimmer.Position = UDim2.new(0, -60 + (shimmerWave * 250), 0, 0)
			shimmer.BackgroundTransparency = 0.92 - (wave * 0.12)
			board.StudsOffset = Vector3.new(0, 5.1 + (math.sin(t * 1.4) * 0.08), 0)
			for _, entry in ipairs(tierBars) do
				local tierWave = (math.sin((t * 2.2) + entry.phase) + 1) * 0.5
				entry.bar.BackgroundTransparency = 0.38 - (tierWave * 0.24)
				entry.card.BackgroundColor3 = Color3.fromRGB(36, 28, 18):Lerp(Color3.fromRGB(54, 40, 20), tierWave * 0.25)
				entry.stroke.Color = Color3.fromRGB(214, 182, 116):Lerp(Color3.fromRGB(255, 224, 158), tierWave * 0.5)
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

local function attachSurfaceBoard(part: BasePart, title: string, accent: Color3, animatedBoardEffects)
	clearNamedChildren(part, { "BoardGui", "BoardGuiMirror" })
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

local function attachCategoryLeaderboardBoard(part: BasePart, title: string, accent: Color3)
	clearNamedChildren(part, { "BoardGui", "BoardGuiMirror" })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 1
	gui.AlwaysOnTop = false
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
	frame.BackgroundTransparency = 0.06
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 2
	stroke.Transparency = 0.14
	stroke.Parent = frame

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(20, 18)
	header.Size = UDim2.new(1, -40, 0, 28)
	header.Font = Enum.Font.GothamBlack
	header.Text = title
	header.TextColor3 = Color3.fromRGB(238, 242, 248)
	header.TextSize = 24
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = frame

	local subheader = Instance.new("TextLabel")
	subheader.Name = "Subheader"
	subheader.BackgroundTransparency = 1
	subheader.Position = UDim2.fromOffset(20, 48)
	subheader.Size = UDim2.new(1, -40, 0, 18)
	subheader.Font = Enum.Font.GothamBold
	subheader.Text = "TOP OPERATORS"
	subheader.TextColor3 = accent
	subheader.TextSize = 12
	subheader.TextXAlignment = Enum.TextXAlignment.Left
	subheader.Parent = frame

	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BackgroundColor3 = accent
	rule.BackgroundTransparency = 0.14
	rule.BorderSizePixel = 0
	rule.Position = UDim2.fromOffset(20, 74)
	rule.Size = UDim2.new(1, -40, 0, 2)
	rule.Parent = frame

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(20, 86)
	body.Size = UDim2.new(1, -40, 1, -104)
	body.Font = Enum.Font.GothamMedium
	body.Text = "Waiting for players..."
	body.TextColor3 = Color3.fromRGB(226, 232, 240)
	body.TextSize = 18
	body.RichText = true
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Parent = frame
end

local LEADERBOARD_MASTER_PPS = 16
local LEADERBOARD_MASTER_WINDOW_BUTTONS = {
	{ name = "AllTimeWindow", controlName = "AllTimeButton", text = "All Time", x = 24, y = 70, width = 86, height = 22 },
	{ name = "MonthlyWindow", controlName = "MonthlyButton", text = "Monthly", x = 118, y = 70, width = 82, height = 22 },
	{ name = "WeeklyWindow", controlName = "WeeklyButton", text = "Weekly", x = 208, y = 70, width = 78, height = 22 },
	{ name = "DailyWindow", controlName = "DailyButton", text = "Daily", x = 294, y = 70, width = 72, height = 22 },
}
local LEADERBOARD_MASTER_CATEGORY_TABS = {
	{ name = "LevelsTab", controlName = "LevelsButton", text = "Levels", key = "Levels", x = 24, y = 98, width = 88, height = 22 },
	{ name = "RunsTab", controlName = "RunsButton", text = "Runs", key = "Runs", x = 122, y = 98, width = 72, height = 22 },
	{ name = "KillsTab", controlName = "KillsButton", text = "Kills", key = "Kills", x = 204, y = 98, width = 72, height = 22 },
}
local LEADERBOARD_MASTER_SCROLL_BUTTONS = {
	{ name = "ScrollUpButton", x = 556, y = 232, width = 30, height = 64 },
	{ name = "ScrollDownButton", x = 556, y = 300, width = 30, height = 64 },
}

local function attachLeaderboardMasterBoard(part: BasePart, animatedBoardEffects)
	clearNamedChildren(part, { "BoardGui", "BoardGuiMirror" })
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
	header.Position = UDim2.fromOffset(44, 16)
	header.Size = UDim2.new(1, -72, 0, 30)
	header.Font = Enum.Font.GothamBlack
	header.Text = "Top Operators"
	header.TextColor3 = Color3.fromRGB(44, 34, 18)
	header.TextSize = 24
	header.TextXAlignment = Enum.TextXAlignment.Center
	header.Parent = frame

	local subheader = Instance.new("TextLabel")
	subheader.Name = "Subheader"
	subheader.BackgroundTransparency = 1
	subheader.Position = UDim2.fromOffset(24, 48)
	subheader.Size = UDim2.new(1, -168, 0, 18)
	subheader.Font = Enum.Font.GothamBold
	subheader.Text = "GLOBAL ALL-TIME • TOP 100"
	subheader.TextColor3 = Color3.fromRGB(96, 78, 54)
	subheader.TextSize = 12
	subheader.TextXAlignment = Enum.TextXAlignment.Left
	subheader.Parent = frame

	local countdown = Instance.new("TextLabel")
	countdown.Name = "Countdown"
	countdown.BackgroundTransparency = 1
	countdown.Position = UDim2.new(1, -154, 0, 48)
	countdown.Size = UDim2.fromOffset(128, 18)
	countdown.Font = Enum.Font.GothamBlack
	countdown.Text = "REFRESH IN 60s"
	countdown.TextColor3 = Color3.fromRGB(88, 82, 70)
	countdown.TextSize = 12
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
		button.TextSize = 12
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
		tab.TextSize = 12
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
	rule.Position = UDim2.fromOffset(24, 128)
	rule.Size = UDim2.new(1, -48, 0, 2)
	rule.Parent = frame

	local podium = Instance.new("Frame")
	podium.Name = "TopThree"
	podium.BackgroundTransparency = 1
	podium.Position = UDim2.fromOffset(24, 138)
	local leaderboardLayout = Config.LeaderboardLayout
	local podiumLayout = leaderboardLayout.Podium
	local listLayout = leaderboardLayout.List
	podium.Size = podiumLayout.Size
	podium.ClipsDescendants = true
	podium.Parent = frame

	for _, info in ipairs({
		{ name = "FirstCard", rank = 1 },
		{ name = "SecondCard", rank = 2 },
		{ name = "ThirdCard", rank = 3 },
	}) do
		local layout = podiumLayout.Cards[info.name]
		local compact = layout.height <= 72
		local ultraCompact = compact and layout.width <= 140
		local card = Instance.new("Frame")
		card.Name = info.name
		card.BackgroundColor3 = Color3.fromRGB(246, 242, 232)
		card.BackgroundTransparency = 0.02
		card.BorderSizePixel = 0
		card.Position = UDim2.fromOffset(layout.x, layout.y)
		card.Size = UDim2.fromOffset(layout.width, layout.height)
		card.Parent = podium

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, compact and 10 or 12)
		cardCorner.Parent = card

		local cardStroke = Instance.new("UIStroke")
		cardStroke.Name = "Stroke"
		cardStroke.Color = layout.accent
		cardStroke.Transparency = compact and 0.26 or 0.2
		cardStroke.Thickness = compact and 1 or 1.4
		cardStroke.Parent = card

		local cardGradient = Instance.new("UIGradient")
		cardGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(252, 249, 241)),
			ColorSequenceKeypoint.new(0.65, Color3.fromRGB(244, 239, 229)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(238, 231, 218)),
		})
		cardGradient.Rotation = 90
		cardGradient.Parent = card

		local accent = Instance.new("Frame")
		accent.Name = "Accent"
		accent.BackgroundColor3 = layout.accent
		accent.BorderSizePixel = 0
		accent.Position = UDim2.fromOffset(0, 0)
		accent.Size = UDim2.new(0, compact and 4 or 6, 1, 0)
		accent.Parent = card

		local accentGlow = Instance.new("Frame")
		accentGlow.Name = "AccentGlow"
		accentGlow.BackgroundColor3 = layout.accent
		accentGlow.BackgroundTransparency = compact and 0.95 or 0.92
		accentGlow.BorderSizePixel = 0
		accentGlow.Position = UDim2.fromOffset(compact and 6 or 8, compact and (ultraCompact and 6 or 8) or 12)
		accentGlow.Size = UDim2.new(1, compact and -12 or -16, 0, compact and (ultraCompact and 12 or 16) or 22)
		accentGlow.Parent = card

		local accentGlowCorner = Instance.new("UICorner")
		accentGlowCorner.CornerRadius = UDim.new(0, 8)
		accentGlowCorner.Parent = accentGlow

		local crest = Instance.new("Frame")
		crest.Name = "AvatarFrame"
		crest.BackgroundColor3 = layout.accent
		crest.BackgroundTransparency = 0.9
		crest.BorderSizePixel = 0
		crest.Position = UDim2.fromOffset(compact and 8 or 12, compact and (ultraCompact and 6 or 10) or 12)
		crest.Size = UDim2.fromOffset(compact and (ultraCompact and 24 or 38) or 54, compact and (ultraCompact and 24 or 38) or 54)
		crest.Parent = card

		local crestCorner = Instance.new("UICorner")
		crestCorner.CornerRadius = UDim.new(0, compact and 10 or 14)
		crestCorner.Parent = crest

		local crestStroke = Instance.new("UIStroke")
		crestStroke.Color = layout.accent
		crestStroke.Transparency = compact and 0.3 or 0.18
		crestStroke.Thickness = 1.2
		crestStroke.Parent = crest

		local avatar = Instance.new("ImageLabel")
		avatar.Name = "Avatar"
		avatar.BackgroundTransparency = 1
		avatar.Position = UDim2.fromOffset(4, 4)
		avatar.Size = UDim2.new(1, -8, 1, -8)
		avatar.Image = ""
		avatar.ScaleType = Enum.ScaleType.Crop
		avatar.Parent = crest

		local avatarCorner = Instance.new("UICorner")
		avatarCorner.CornerRadius = UDim.new(1, 0)
		avatarCorner.Parent = avatar

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(compact and (ultraCompact and 38 or 56) or 78, compact and (ultraCompact and 4 or 10) or 14)
		title.Size = UDim2.new(1, compact and (ultraCompact and -76 or -114) or -132, 0, compact and (ultraCompact and 14 or 18) or 24)
		title.Font = Enum.Font.GothamBlack
		title.Text = "Awaiting Operator"
		title.TextColor3 = Color3.fromRGB(54, 42, 26)
		title.TextSize = compact and (ultraCompact and 8 or 12) or (layout.width > 240 and 18 or 15)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = card

		local subtitle = Instance.new("TextLabel")
		subtitle.Name = "Subtitle"
		subtitle.BackgroundTransparency = 1
		subtitle.Position = UDim2.fromOffset(compact and (ultraCompact and 38 or 56) or 78, compact and (ultraCompact and 15 or 28) or 42)
		subtitle.Size = UDim2.new(1, compact and (ultraCompact and -76 or -114) or -132, 0, compact and (ultraCompact and 9 or 14) or 18)
		subtitle.Font = Enum.Font.GothamBold
		subtitle.Text = "No record yet"
		subtitle.TextColor3 = Color3.fromRGB(112, 96, 72)
		subtitle.TextSize = compact and (ultraCompact and 6 or 9) or (layout.width > 240 and 11 or 10)
		subtitle.TextXAlignment = Enum.TextXAlignment.Left
		subtitle.Visible = not ultraCompact
		subtitle.Parent = card

		local value = Instance.new("TextLabel")
		value.Name = "Value"
		value.BackgroundTransparency = 1
		value.Position = UDim2.fromOffset(compact and (ultraCompact and 38 or 14) or 14, compact and (ultraCompact and 15 or 40) or 68)
		value.Size = UDim2.new(1, compact and (ultraCompact and -48 or -28) or -28, 0, compact and (ultraCompact and 12 or 28) or 28)
		value.Font = Enum.Font.GothamBlack
		value.Text = "-"
		value.TextColor3 = Color3.fromRGB(44, 34, 18)
		value.TextSize = compact and (ultraCompact and 8 or 11) or (layout.width > 240 and 20 or 17)
		value.TextXAlignment = Enum.TextXAlignment.Left
		value.Parent = card

		local valueLabel = Instance.new("TextLabel")
		valueLabel.Name = "ValueLabel"
		valueLabel.BackgroundTransparency = 1
		valueLabel.Position = UDim2.fromOffset(16, compact and (ultraCompact and 40 or 50) or 94)
		valueLabel.Size = UDim2.new(1, compact and (ultraCompact and -84 or -94) or -120, 0, 16)
		valueLabel.Font = Enum.Font.GothamBold
		valueLabel.Text = "TRACKED VALUE"
		valueLabel.TextColor3 = Color3.fromRGB(118, 102, 76)
		valueLabel.TextSize = compact and (ultraCompact and 7 or 8) or 9
		valueLabel.TextXAlignment = Enum.TextXAlignment.Left
		valueLabel.Visible = not ultraCompact
		valueLabel.Parent = card

		local rankChip = Instance.new("Frame")
		rankChip.Name = "RankChip"
		rankChip.BackgroundColor3 = layout.accent
		rankChip.BackgroundTransparency = compact and 0.94 or 0.91
		rankChip.BorderSizePixel = 0
		rankChip.Position = UDim2.new(1, compact and (ultraCompact and -34 or -62) or -88, 0, compact and (ultraCompact and 5 or 10) or 12)
		rankChip.Size = UDim2.fromOffset(compact and (ultraCompact and 26 or 50) or 74, compact and (ultraCompact and 14 or 18) or 24)
		rankChip.Parent = card

		local rankChipCorner = Instance.new("UICorner")
		rankChipCorner.CornerRadius = UDim.new(0, compact and 9 or 12)
		rankChipCorner.Parent = rankChip

		local rankChipStroke = Instance.new("UIStroke")
		rankChipStroke.Color = layout.accent
		rankChipStroke.Transparency = compact and 0.24 or 0.16
		rankChipStroke.Thickness = 1.1
		rankChipStroke.Parent = rankChip

		local rank = Instance.new("TextLabel")
		rank.Name = "Rank"
		rank.BackgroundTransparency = 1
		rank.Position = UDim2.new(1, compact and (ultraCompact and -32 or -58) or -84, 0, compact and (ultraCompact and 4 or 9) or 13)
		rank.Size = UDim2.fromOffset(compact and (ultraCompact and 24 or 42) or 66, compact and (ultraCompact and 14 or 18) or 22)
		rank.Font = Enum.Font.GothamBlack
		rank.Text = "#" .. tostring(info.rank)
		rank.TextColor3 = layout.accent
		rank.TextSize = compact and (ultraCompact and 7 or 11) or 15
		rank.TextXAlignment = Enum.TextXAlignment.Center
		rank.Parent = card

		local glow = Instance.new("Frame")
		glow.Name = "Glow"
		glow.BackgroundColor3 = layout.glow
		glow.BackgroundTransparency = compact and 0.96 or 0.93
		glow.BorderSizePixel = 0
		glow.Position = UDim2.fromOffset(12, compact and (ultraCompact and 44 or 56) or 100)
		glow.Size = UDim2.new(1, -24, 0, compact and (ultraCompact and 4 or 6) or 10)
		glow.Parent = card
	end

	local listSectionLabel = Instance.new("TextLabel")
	listSectionLabel.Name = "ListSectionLabel"
	listSectionLabel.BackgroundTransparency = 1
	listSectionLabel.Position = UDim2.fromOffset(24, listLayout.HeaderY - 18)
	listSectionLabel.Size = UDim2.new(1, -48, 0, 14)
	listSectionLabel.Font = Enum.Font.GothamBold
	listSectionLabel.Text = "RANKED OPERATORS  #4-100"
	listSectionLabel.TextColor3 = Color3.fromRGB(124, 106, 78)
	listSectionLabel.TextSize = 9
	listSectionLabel.TextXAlignment = Enum.TextXAlignment.Left
	listSectionLabel.Parent = frame

	local headerRow = Instance.new("TextLabel")
	headerRow.Name = "ListHeader"
	headerRow.BackgroundColor3 = Color3.fromRGB(239, 233, 220)
	headerRow.BackgroundTransparency = 0.12
	headerRow.Position = UDim2.fromOffset(24, listLayout.HeaderY)
	headerRow.Size = UDim2.new(1, -48, 0, listLayout.HeaderHeight)
	headerRow.Font = Enum.Font.RobotoMono
	headerRow.Text = "#  USERNAME                          SCORE"
	headerRow.TextColor3 = Color3.fromRGB(54, 48, 36)
	headerRow.TextSize = 13
	headerRow.TextXAlignment = Enum.TextXAlignment.Left
	headerRow.Parent = frame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 8)
	headerCorner.Parent = headerRow

	local headerStroke = Instance.new("UIStroke")
	headerStroke.Color = Color3.fromRGB(194, 186, 170)
	headerStroke.Transparency = 0.42
	headerStroke.Thickness = 1
	headerStroke.Parent = headerRow

	for index = 0, listLayout.SlotCount - 1 do
		local slot = Instance.new("Frame")
		slot.Name = "RankSlot" .. tostring(index + 1)
		slot.BackgroundColor3 = index % 2 == 0 and Color3.fromRGB(248, 246, 240) or Color3.fromRGB(238, 234, 226)
		slot.BackgroundTransparency = 0.2
		slot.BorderSizePixel = 0
		slot.Position = UDim2.fromOffset(18, listLayout.SlotStartY + (index * listLayout.SlotSpacing))
		slot.Size = UDim2.new(1, -36, 0, 62)
		slot.Parent = frame

		local slotStroke = Instance.new("UIStroke")
		slotStroke.Color = Color3.fromRGB(194, 186, 170)
		slotStroke.Transparency = 0.64
		slotStroke.Thickness = 1
		slotStroke.Parent = slot
	end

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "BodyScroll"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(24, listLayout.ScrollY)
	scroll.Size = UDim2.new(1, -48, 1, -listLayout.ScrollBottomPadding)
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.ScrollBarThickness = 10
	scroll.ScrollBarImageColor3 = Color3.fromRGB(176, 154, 112)
	scroll.Active = true
	scroll.Parent = frame

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(10, 6)
	body.Size = UDim2.new(1, -20, 0, 1200)
	body.Font = Enum.Font.RobotoMono
	body.Text = "Loading..."
	body.RichText = true
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextColor3 = Color3.fromRGB(38, 36, 32)
	body.TextSize = 16
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

local function addPremiumTeleportPrompt(parent: Instance, name: string, actionText: string, objectText: string, destination: BasePart, requiredAttribute: string, requiredAttributeFlag: string, offset: Vector3?, maxDistance: number?)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = maxDistance or 12
	prompt:SetAttribute(requiredAttributeFlag, true)
	prompt:SetAttribute("UnlockedActionText", actionText)
	prompt:SetAttribute("UnlockedObjectText", objectText)
	if requiredAttributeFlag == "RequiresSupporter" then
		prompt:SetAttribute("LockedActionText", "Supporter Locked")
		prompt:SetAttribute("LockedObjectText", "Bunker Supporter Required")
	elseif requiredAttributeFlag == "RequiresVip" then
		prompt:SetAttribute("LockedActionText", "VIP Locked")
		prompt:SetAttribute("LockedObjectText", "VIP Access Required")
	end
	prompt.Parent = parent

	prompt.Triggered:Connect(function(player)
		if not player or player:GetAttribute(requiredAttribute) ~= true then
			return
		end
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
	elseif transitStyle == "supporter" then
		local loungeDeck = makePart(
			node,
			"Part",
			"SupporterDeck",
			Vector3.new(12, 0.2, 12),
			CFrame.new(position + Vector3.new(0, 0.56, 0)),
			Color3.fromRGB(108, 88, 54),
			Enum.Material.WoodPlanks
		)
		loungeDeck.CanCollide = false
		loungeDeck.CanQuery = false
		local deckGlow = makeGlowPart(
			node,
			"SupporterDeckGlow",
			Vector3.new(8.4, 0.06, 2.2),
			CFrame.new(position + Vector3.new(0, 0.68, 1.4)),
			Color3.fromRGB(248, 222, 138),
			0.78
		)
		deckGlow.CanCollide = false
		deckGlow.CanQuery = false
		for _, x in ipairs({ -4.6, 4.6 }) do
			local post = makePart(
				node,
				"Part",
				"SupporterPost",
				Vector3.new(0.9, 3.2, 0.9),
				CFrame.new(position + Vector3.new(x, 1.74, 2.8)),
				Color3.fromRGB(112, 90, 56),
				Enum.Material.Metal
			)
			post.CanQuery = false
		end
	elseif transitStyle == "vip" then
		local apron = makePart(
			node,
			"Part",
			"VipApron",
			Vector3.new(12, 0.2, 12),
			CFrame.new(position + Vector3.new(0, 0.56, 0)),
			Color3.fromRGB(74, 90, 122),
			Enum.Material.Metal
		)
		apron.CanCollide = false
		apron.CanQuery = false
		local laneGlow = makeGlowPart(
			node,
			"VipApronGlow",
			Vector3.new(8.2, 0.06, 2.0),
			CFrame.new(position + Vector3.new(0, 0.68, 1.6)),
			Color3.fromRGB(186, 220, 255),
			0.8
		)
		laneGlow.CanCollide = false
		laneGlow.CanQuery = false
		for _, x in ipairs({ -4.8, 4.8 }) do
			local post = makePart(
				node,
				"Part",
				"VipPost",
				Vector3.new(1.0, 3.2, 1.0),
				CFrame.new(position + Vector3.new(x, 1.74, 2.8)),
				Color3.fromRGB(90, 108, 146),
				Enum.Material.Metal
			)
			post.CanQuery = false
		end
	end

	if destination then
		if palette.RequiresSupporter == true then
			addPremiumTeleportPrompt(pad, name .. "Prompt", actionText, objectText, destination, "SubscriptionActive", "RequiresSupporter", offset or Vector3.new(0, 4, 0), 14)
		elseif palette.RequiresVip == true then
			addPremiumTeleportPrompt(pad, name .. "Prompt", actionText, objectText, destination, "GamePassVipOperation", "RequiresVip", offset or Vector3.new(0, 4, 0), 14)
		else
			addTeleportPrompt(pad, name .. "Prompt", actionText, objectText, destination, offset or Vector3.new(0, 4, 0), 14)
		end
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
	local backWallSign = makePart(yard, "Part", "BackWallSign", Vector3.new(18, 1.1, 0.4), backWall.CFrame * CFrame.new(0, 1.7, -1.18), Color3.fromRGB(64, 72, 84), Enum.Material.Metal)
	backWallSign.CanCollide = false
	backWallSign.CanQuery = false
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
		local hurdleTrigger = makePart(yard, "Part", "HurdleTrigger" .. tostring(lane + 2), Vector3.new(5.6, 3.2, 3.4), CFrame.new(worldPosition + Vector3.new(laneX, 2.0, -4.6)), Color3.fromRGB(255, 255, 255), Enum.Material.ForceField)
		hurdleTrigger.Transparency = 1
		hurdleTrigger.CanCollide = false
		hurdleTrigger.CanQuery = false
	end

	local benchLeft = makePart(yard, "Part", "BenchLeft", Vector3.new(6, 1.2, 2), CFrame.new(worldPosition + Vector3.new(-10.4, 1.2, 12.4)), Color3.fromRGB(98, 82, 58), Enum.Material.WoodPlanks)
	benchLeft.CanQuery = false
	local benchRight = makePart(yard, "Part", "BenchRight", Vector3.new(6, 1.2, 2), CFrame.new(worldPosition + Vector3.new(10.4, 1.2, 12.4)), Color3.fromRGB(98, 82, 58), Enum.Material.WoodPlanks)
	benchRight.CanQuery = false
	local trainingSecret = makeGlowPart(yard, "TrainingSecret", Vector3.new(1.2, 1.2, 1.2), CFrame.new(worldPosition + Vector3.new(13.2, 2.2, 11.2)), Color3.fromRGB(214, 162, 255), 0.34)
	trainingSecret.CanCollide = false
	trainingSecret.CanQuery = false

	local returnPad = makePart(yard, "Part", "ReturnPad", Vector3.new(8, 0.24, 6), CFrame.new(worldPosition + Vector3.new(0, 0.84, 13.4)), Color3.fromRGB(70, 76, 84), Enum.Material.Metal)
	returnPad.CanCollide = false
	returnPad.CanQuery = false

	attachLabel(backWallSign, "TRAINING YARD", "Warm up movement and range control", palette.Accent)
	attachWorldText(returnPad, "RETURN", Vector3.new(0, 1.74, 0), Color3.fromRGB(224, 232, 242), Vector2.new(84, 20))

	local trainingPrompt = Instance.new("ProximityPrompt")
	trainingPrompt.Name = "TrainingEnterPrompt"
	trainingPrompt.ActionText = "Start Drill"
	trainingPrompt.ObjectText = "Training Yard"
	trainingPrompt.KeyboardKeyCode = Enum.KeyCode.E
	trainingPrompt.HoldDuration = 0
	trainingPrompt.RequiresLineOfSight = false
	trainingPrompt.MaxActivationDistance = 14
	trainingPrompt.Parent = entryPad
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
	local finishBanner = makePart(course, "Part", "FinishBanner", Vector3.new(10, 1.1, 0.5), finishTower.CFrame * CFrame.new(0, 2.1, -4.24), Color3.fromRGB(72, 80, 96), Enum.Material.Metal)
	finishBanner.CanCollide = false
	finishBanner.CanQuery = false
	local finishPad = makePart(course, "Part", "FinishPad", Vector3.new(8, 1, 8), finishTower.CFrame * CFrame.new(0, 6.5, 0), Color3.fromRGB(92, 106, 146), Enum.Material.DiamondPlate)
	finishPad.CanQuery = false
	makeGlowPart(course, "FinishGlow", Vector3.new(8.4, 0.08, 8.4), finishPad.CFrame * CFrame.new(0, 0.54, 0), palette.Accent, 0.56)
	local parkourSecret = makeGlowPart(course, "ParkourSecret", Vector3.new(1.2, 1.2, 1.2), finishTower.CFrame * CFrame.new(0, 8.9, 0), Color3.fromRGB(214, 162, 255), 0.34)
	parkourSecret.CanCollide = false
	parkourSecret.CanQuery = false

	attachLabel(finishBanner, "PARKOUR LINE", "Run the blocks and claim the roof", palette.Accent)
	attachWorldText(returnPad, "RETURN", Vector3.new(0, 1.74, 0), Color3.fromRGB(224, 232, 242), Vector2.new(84, 20))

	local parkourPrompt = Instance.new("ProximityPrompt")
	parkourPrompt.Name = "ParkourStartPrompt"
	parkourPrompt.ActionText = "Run Course"
	parkourPrompt.ObjectText = "Parkour Line"
	parkourPrompt.KeyboardKeyCode = Enum.KeyCode.E
	parkourPrompt.HoldDuration = 0
	parkourPrompt.RequiresLineOfSight = false
	parkourPrompt.MaxActivationDistance = 14
	parkourPrompt.Parent = startPad
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

	local banner = makePart(ring, "Part", "Banner", Vector3.new(9.4, 0.82, 0.4), CFrame.new(worldPosition + Vector3.new(0, 6.0, 12.8)), Color3.fromRGB(82, 44, 44), Enum.Material.Metal)
	banner.CanCollide = false
	banner.CanQuery = false
	attachLabel(banner, "DUEL RING", "Stage 1v1s and settle bragging rights", palette.Accent)
	attachWorldText(redCorner, "RED", Vector3.new(0, 1.72, 0), Color3.fromRGB(255, 194, 194), Vector2.new(64, 18))
	attachWorldText(blueCorner, "BLUE", Vector3.new(0, 1.72, 0), Color3.fromRGB(198, 218, 255), Vector2.new(64, 18))
	attachWorldText(returnPad, "RETURN", Vector3.new(0, 1.74, 0), Color3.fromRGB(224, 232, 242), Vector2.new(84, 20))

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
	local rangeSecret = makeGlowPart(range, "RangeSecret", Vector3.new(1.2, 1.2, 1.2), CFrame.new(worldPosition + Vector3.new(-13.2, 2.4, 11.6)), Color3.fromRGB(214, 162, 255), 0.34)
	rangeSecret.CanCollide = false
	rangeSecret.CanQuery = false

	local sign = makePart(range, "Part", "Sign", Vector3.new(12.4, 1.0, 0.5), CFrame.new(worldPosition + Vector3.new(0, 6.6, 13.2)), Color3.fromRGB(56, 82, 72), Enum.Material.Metal)
	sign.CanCollide = false
	sign.CanQuery = false
	attachLabel(sign, "TARGET RANGE", "Dial in aim and test recoil control", palette.Accent)
	attachWorldText(returnPad, "RETURN", Vector3.new(0, 1.74, 0), Color3.fromRGB(224, 232, 242), Vector2.new(84, 20))

	local rangePrompt = Instance.new("ProximityPrompt")
	rangePrompt.Name = "TargetRangePrompt"
	rangePrompt.ActionText = "Start Trial"
	rangePrompt.ObjectText = "Target Range"
	rangePrompt.KeyboardKeyCode = Enum.KeyCode.E
	rangePrompt.HoldDuration = 0
	rangePrompt.RequiresLineOfSight = false
	rangePrompt.MaxActivationDistance = 14
	rangePrompt.Parent = firingLine
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
	local returnPad = makePart(run, "Part", "ReturnPad", Vector3.new(6.4, 0.22, 4.4), CFrame.new(worldPosition + Vector3.new(10.2, 0.56, -4.4)), Color3.fromRGB(74, 80, 88), Enum.Material.Metal)
	returnPad.CanCollide = false
	returnPad.CanQuery = false

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
	local salvageSecret = makeGlowPart(run, "SalvageSecret", Vector3.new(1.2, 1.2, 1.2), CFrame.new(worldPosition + Vector3.new(10.4, 2.2, 9.6)), Color3.fromRGB(214, 162, 255), 0.34)
	salvageSecret.CanCollide = false
	salvageSecret.CanQuery = false

	local sign = makePart(run, "Part", "Sign", Vector3.new(7, 0.6, 0.4), CFrame.new(worldPosition + Vector3.new(-9.2, 2.4, 0)), Color3.fromRGB(82, 62, 42), Enum.Material.Metal)
	sign.CanCollide = false
	sign.CanQuery = false
	attachLabel(sign, "SALVAGE RUN", "Recover bunker caches before the timer burns out", palette.Accent)
	attachWorldText(finishPad, "EXTRACT", Vector3.new(0, 1.46, 0), Color3.fromRGB(224, 232, 242), Vector2.new(82, 20))
	attachWorldText(returnPad, "RETURN", Vector3.new(0, 1.46, 0), Color3.fromRGB(224, 232, 242), Vector2.new(82, 20))

	local salvageStartPrompt = Instance.new("ProximityPrompt")
	salvageStartPrompt.Name = "SalvageStartPrompt"
	salvageStartPrompt.ActionText = "Start Run"
	salvageStartPrompt.ObjectText = "Salvage Run"
	salvageStartPrompt.KeyboardKeyCode = Enum.KeyCode.E
	salvageStartPrompt.HoldDuration = 0
	salvageStartPrompt.RequiresLineOfSight = false
	salvageStartPrompt.MaxActivationDistance = 14
	salvageStartPrompt.Parent = startPad

	local salvageExtractPrompt = Instance.new("ProximityPrompt")
	salvageExtractPrompt.Name = "SalvageExtractPrompt"
	salvageExtractPrompt.ActionText = "Extract"
	salvageExtractPrompt.ObjectText = "Salvage Run"
	salvageExtractPrompt.KeyboardKeyCode = Enum.KeyCode.E
	salvageExtractPrompt.HoldDuration = 0
	salvageExtractPrompt.RequiresLineOfSight = false
	salvageExtractPrompt.MaxActivationDistance = 14
	salvageExtractPrompt.Parent = finishPad

	addTeleportPrompt(returnPad, "SalvageReturnPrompt", "Return", "Main Plaza", lobbyReturnPart or base, Vector3.new(0, 4, 0), 14)

	return run
end

local function makeSupporterLounge(root: Instance, worldPosition: Vector3, palette, lobbyReturnPart: BasePart?)
	local lounge = Instance.new("Model")
	lounge.Name = "SupporterLounge"
	lounge.Parent = root

	local base = makePart(lounge, "Part", "Base", Vector3.new(54, 1, 38), CFrame.new(worldPosition), palette.Color:Lerp(Color3.fromRGB(60, 56, 46), 0.28), Enum.Material.WoodPlanks)
	base.CanQuery = false
	lounge.PrimaryPart = base

	local trim = makeGlowPart(lounge, "BaseTrim", Vector3.new(54, 0.12, 38), CFrame.new(worldPosition + Vector3.new(0, 0.72, 0)), palette.Accent, 0.9)
	trim.CanCollide = false
	trim.CanQuery = false

	local rearTerrace = makePart(lounge, "Part", "RearTerrace", Vector3.new(34, 1.2, 12), CFrame.new(worldPosition + Vector3.new(0, 0.6, 11.8)), Color3.fromRGB(112, 90, 58), Enum.Material.WoodPlanks)
	rearTerrace.CanQuery = false
	local rearWall = makePart(lounge, "Part", "RearWall", Vector3.new(34, 8.2, 1.6), CFrame.new(worldPosition + Vector3.new(0, 4.4, 17.0)), Color3.fromRGB(92, 74, 48), Enum.Material.WoodPlanks)
	rearWall.CanQuery = false
	local canopy = makePart(lounge, "Part", "Canopy", Vector3.new(26, 0.9, 10), CFrame.new(worldPosition + Vector3.new(0, 8.6, 11.6)), Color3.fromRGB(116, 92, 58), Enum.Material.WoodPlanks)
	canopy.CanQuery = false
	local canopyGlow = makeGlowPart(lounge, "CanopyGlow", Vector3.new(18, 0.08, 1.2), canopy.CFrame * CFrame.new(0, -0.3, -3.6), palette.Accent, 0.62)
	canopyGlow.CanCollide = false
	canopyGlow.CanQuery = false

	local signBand = makePart(lounge, "Part", "SignBand", Vector3.new(18, 1.1, 0.3), rearWall.CFrame * CFrame.new(0, 2.0, -0.96), Color3.fromRGB(132, 104, 64), Enum.Material.Metal)
	signBand.CanCollide = false
	signBand.CanQuery = false
	attachLabel(signBand, "SUPPORTER LOUNGE", "Weekly crate lane, quiet briefing deck, and premium bunker access", palette.Accent)

	local loungeDeck = makePart(lounge, "Part", "LoungeDeck", Vector3.new(20, 0.4, 12), CFrame.new(worldPosition + Vector3.new(0, 1.1, 2.8)), Color3.fromRGB(136, 110, 72), Enum.Material.WoodPlanks)
	loungeDeck.CanCollide = false
	loungeDeck.CanQuery = false
	local loungeDeckGlow = makeGlowPart(lounge, "LoungeDeckGlow", Vector3.new(10, 0.06, 2.4), loungeDeck.CFrame * CFrame.new(0, 0.22, -2.6), palette.Accent, 0.72)
	loungeDeckGlow.CanCollide = false
	loungeDeckGlow.CanQuery = false

	for _, x in ipairs({ -17.5, 17.5 }) do
		local tower = makePart(lounge, "Part", "WatchPost", Vector3.new(2.0, 6.2, 2.0), CFrame.new(worldPosition + Vector3.new(x, 3.2, 8.0)), Color3.fromRGB(106, 84, 52), Enum.Material.Metal)
		tower.CanQuery = false
		local cap = makeGlowPart(lounge, "WatchPostGlow", Vector3.new(2.2, 0.12, 2.2), tower.CFrame * CFrame.new(0, 2.86, 0), palette.Accent, 0.54)
		cap.CanCollide = false
		cap.CanQuery = false
	end

	local cratePad = makePart(lounge, "Part", "CratePad", Vector3.new(12, 0.24, 10), CFrame.new(worldPosition + Vector3.new(-14, 0.84, 2.0)), Color3.fromRGB(148, 118, 76), Enum.Material.Metal)
	cratePad.CanCollide = false
	cratePad.CanQuery = false
	local crateStack = makePart(lounge, "Part", "WeeklyCrate", Vector3.new(4.2, 3.4, 4.2), CFrame.new(worldPosition + Vector3.new(-14, 2.14, 2.0)), Color3.fromRGB(122, 96, 58), Enum.Material.WoodPlanks)
	crateStack.CanQuery = false
	local crateGlow = makeGlowPart(lounge, "WeeklyCrateGlow", Vector3.new(5.0, 0.1, 5.0), crateStack.CFrame * CFrame.new(0, 1.84, 0), palette.Accent, 0.48)
	crateGlow.CanCollide = false
	crateGlow.CanQuery = false

	local briefingWall = makePart(lounge, "Part", "BriefingWall", Vector3.new(10, 4.4, 0.4), CFrame.new(worldPosition + Vector3.new(0, 4.0, 15.9)), Color3.fromRGB(238, 232, 216), Enum.Material.SmoothPlastic)
	briefingWall.CanCollide = false
	briefingWall.CanQuery = false
	local briefingGlow = makeGlowPart(lounge, "BriefingWallGlow", Vector3.new(12, 0.08, 0.5), briefingWall.CFrame * CFrame.new(0, -2.1, -0.24), palette.Accent, 0.78)
	briefingGlow.CanCollide = false
	briefingGlow.CanQuery = false

	local terminalPad = makePart(lounge, "Part", "SupportTerminalPad", Vector3.new(12, 0.24, 10), CFrame.new(worldPosition + Vector3.new(14, 0.84, 2.0)), Color3.fromRGB(98, 86, 62), Enum.Material.Metal)
	terminalPad.CanCollide = false
	terminalPad.CanQuery = false
	local terminal = makePart(lounge, "Part", "SupportTerminal", Vector3.new(5.2, 3.4, 2.0), CFrame.new(worldPosition + Vector3.new(14, 2.2, 4.9)), Color3.fromRGB(82, 74, 58), Enum.Material.Metal)
	terminal.CanQuery = false
	local terminalScreen = makeGlowPart(lounge, "SupportTerminalScreen", Vector3.new(3.6, 2.2, 0.12), terminal.CFrame * CFrame.new(0, 0.34, -1.02), Color3.fromRGB(246, 220, 138), 0.32)
	terminalScreen.CanCollide = false
	terminalScreen.CanQuery = false

	for _, offset in ipairs({
		Vector3.new(-4.6, 0.74, -6.4),
		Vector3.new(4.6, 0.74, -6.4),
	}) do
		local bench = makePart(lounge, "Part", "Bench", Vector3.new(7.4, 1.1, 2.4), CFrame.new(worldPosition + offset), Color3.fromRGB(108, 86, 56), Enum.Material.WoodPlanks)
		bench.CanQuery = false
	end

	local entryWalk = makePart(lounge, "Part", "EntryWalk", Vector3.new(18, 0.2, 16), CFrame.new(worldPosition + Vector3.new(0, 0.56, -10.0)), Color3.fromRGB(118, 96, 62), Enum.Material.WoodPlanks)
	entryWalk.CanCollide = false
	entryWalk.CanQuery = false
	local entryPad = makePart(lounge, "Part", "EntryPad", Vector3.new(11.2, 0.24, 7.2), CFrame.new(worldPosition + Vector3.new(0, 0.84, -12.8)), palette.Accent:Lerp(Color3.fromRGB(248, 240, 220), 0.18), Enum.Material.Metal)
	entryPad.CanCollide = false
	entryPad.CanQuery = false
	local entryGlow = makeGlowPart(lounge, "EntryPadGlow", Vector3.new(7.2, 0.06, 1.8), entryPad.CFrame * CFrame.new(0, 0.16, 1.0), palette.Accent, 0.66)
	entryGlow.CanCollide = false
	entryGlow.CanQuery = false

	local returnPad = makePart(lounge, "Part", "ReturnPad", Vector3.new(8, 0.24, 6), CFrame.new(worldPosition + Vector3.new(0, 0.84, 14.2)), Color3.fromRGB(70, 76, 84), Enum.Material.Metal)
	returnPad.CanCollide = false
	returnPad.CanQuery = false
	attachWorldText(returnPad, "RETURN", Vector3.new(0, 1.62, 0), Color3.fromRGB(224, 232, 242), Vector2.new(80, 18))

	addPremiumTeleportPrompt(entryPad, "SupporterEnterPrompt", "Enter Lounge", "Supporter Lounge", entryPad, "SubscriptionActive", "RequiresSupporter", Vector3.new(0, 4, 0), 14)
	addTeleportPrompt(returnPad, "SupporterReturnPrompt", "Return", "Main Plaza", lobbyReturnPart or base, Vector3.new(0, 4, 0), 14)

	local terminalPrompt = Instance.new("ProximityPrompt")
	terminalPrompt.Name = "SupporterTerminalPrompt"
	terminalPrompt.ActionText = "Open Support Board"
	terminalPrompt.ObjectText = "Supporter Lounge"
	terminalPrompt.KeyboardKeyCode = Enum.KeyCode.E
	terminalPrompt.HoldDuration = 0
	terminalPrompt.RequiresLineOfSight = false
	terminalPrompt.MaxActivationDistance = 14
	terminalPrompt:SetAttribute("RequiresSupporter", true)
	terminalPrompt:SetAttribute("NpcDialogueTitle", "Supporter Terminal")
	terminalPrompt:SetAttribute("NpcDialogueRole", "Premium ops terminal")
	terminalPrompt:SetAttribute("NpcDialogueBody", "Track your weekly crate, supporter status, and bunker stipend timing from this terminal.")
	terminalPrompt:SetAttribute("NpcActionLabel", "Open Ops Board")
	terminalPrompt:SetAttribute("NpcActionPanel", "QuestBoard")
	terminalPrompt.Parent = terminalPad

	return lounge
end

local function makeVipLounge(root: Instance, worldPosition: Vector3, palette, lobbyReturnPart: BasePart?)
	local lounge = Instance.new("Model")
	lounge.Name = "VipLounge"
	lounge.Parent = root

	local base = makePart(lounge, "Part", "Base", Vector3.new(56, 1, 40), CFrame.new(worldPosition), palette.Color:Lerp(Color3.fromRGB(52, 60, 80), 0.22), Enum.Material.Metal)
	base.CanQuery = false
	lounge.PrimaryPart = base

	local trim = makeGlowPart(lounge, "BaseTrim", Vector3.new(56, 0.12, 40), CFrame.new(worldPosition + Vector3.new(0, 0.72, 0)), palette.Accent, 0.92)
	trim.CanCollide = false
	trim.CanQuery = false

	local rearDais = makePart(lounge, "Part", "RearDais", Vector3.new(30, 1.4, 12), CFrame.new(worldPosition + Vector3.new(0, 0.7, 13.8)), Color3.fromRGB(66, 80, 112), Enum.Material.Metal)
	rearDais.CanQuery = false
	local rearWall = makePart(lounge, "Part", "RearWall", Vector3.new(30, 9.2, 1.4), CFrame.new(worldPosition + Vector3.new(0, 4.9, 19.2)), Color3.fromRGB(58, 72, 98), Enum.Material.Metal)
	rearWall.CanQuery = false
	local canopy = makePart(lounge, "Part", "Canopy", Vector3.new(24, 0.9, 10), CFrame.new(worldPosition + Vector3.new(0, 9.1, 13.4)), Color3.fromRGB(56, 68, 94), Enum.Material.Metal)
	canopy.CanQuery = false
	local canopyGlow = makeGlowPart(lounge, "CanopyGlow", Vector3.new(18, 0.08, 1.2), canopy.CFrame * CFrame.new(0, -0.32, -3.4), palette.Accent, 0.58)
	canopyGlow.CanCollide = false
	canopyGlow.CanQuery = false

	local leftWing = makePart(lounge, "WedgePart", "LeftWing", Vector3.new(6.8, 8.2, 16), CFrame.new(worldPosition + Vector3.new(-19.8, 4.2, 10.6)) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(60, 74, 102), Enum.Material.Metal)
	leftWing.CanQuery = false
	local rightWing = makePart(lounge, "WedgePart", "RightWing", Vector3.new(6.8, 8.2, 16), CFrame.new(worldPosition + Vector3.new(19.8, 4.2, 10.6)), Color3.fromRGB(60, 74, 102), Enum.Material.Metal)
	rightWing.CanQuery = false

	local signBand = makePart(lounge, "Part", "SignBand", Vector3.new(16.4, 1.0, 0.3), rearWall.CFrame * CFrame.new(0, 2.2, -0.86), Color3.fromRGB(82, 104, 144), Enum.Material.Metal)
	signBand.CanCollide = false
	signBand.CanQuery = false
	attachLabel(signBand, "VIP OPERATIONS", "Priority launch deck, route prep, and operator fast lane", palette.Accent)

	local centralDeck = makePart(lounge, "Part", "CentralDeck", Vector3.new(20, 0.4, 16), CFrame.new(worldPosition + Vector3.new(0, 1.1, 3.0)), Color3.fromRGB(72, 86, 116), Enum.Material.Metal)
	centralDeck.CanCollide = false
	centralDeck.CanQuery = false
	local centralGlow = makeGlowPart(lounge, "CentralDeckGlow", Vector3.new(10, 0.06, 3.0), centralDeck.CFrame * CFrame.new(0, 0.22, -3.2), palette.Accent, 0.72)
	centralGlow.CanCollide = false
	centralGlow.CanQuery = false

	local mapTable = makePart(lounge, "Part", "MapTable", Vector3.new(10.6, 1.4, 5.8), CFrame.new(worldPosition + Vector3.new(0, 1.8, 5.8)), Color3.fromRGB(66, 80, 112), Enum.Material.Metal)
	mapTable.CanQuery = false
	local mapGlow = makeGlowPart(lounge, "MapTableGlow", Vector3.new(7.8, 0.08, 4.0), mapTable.CFrame * CFrame.new(0, 0.78, 0), palette.Accent, 0.42)
	mapGlow.CanCollide = false
	mapGlow.CanQuery = false

	for _, offset in ipairs({
		Vector3.new(-14.0, 1.2, 4.4),
		Vector3.new(14.0, 1.2, 4.4),
	}) do
		local prepBay = makePart(lounge, "Part", "PrepBay", Vector3.new(8.2, 3.8, 6.0), CFrame.new(worldPosition + offset), Color3.fromRGB(72, 88, 122), Enum.Material.Metal)
		prepBay.CanQuery = false
		local prepGlow = makeGlowPart(lounge, "PrepBayGlow", Vector3.new(6.0, 0.08, 1.4), prepBay.CFrame * CFrame.new(0, 1.82, -2.12), palette.Accent, 0.46)
		prepGlow.CanCollide = false
		prepGlow.CanQuery = false
	end

	local briefingScreen = makeGlowPart(lounge, "BriefingScreen", Vector3.new(10.6, 2.8, 0.12), CFrame.new(worldPosition + Vector3.new(0, 5.0, 18.18)), palette.Accent, 0.28)
	briefingScreen.CanCollide = false
	briefingScreen.CanQuery = false

	for _, offset in ipairs({
		Vector3.new(-17.4, 3.0, -1.6),
		Vector3.new(17.4, 3.0, -1.6),
	}) do
		local pylon = makePart(lounge, "Part", "EntryPylon", Vector3.new(1.6, 5.8, 1.6), CFrame.new(worldPosition + offset), Color3.fromRGB(74, 94, 128), Enum.Material.Metal)
		pylon.CanQuery = false
		local pylonGlow = makeGlowPart(lounge, "EntryPylonGlow", Vector3.new(1.8, 0.12, 1.8), pylon.CFrame * CFrame.new(0, 2.62, 0), palette.Accent, 0.5)
		pylonGlow.CanCollide = false
		pylonGlow.CanQuery = false
	end

	local entryWalk = makePart(lounge, "Part", "EntryWalk", Vector3.new(20, 0.22, 16), CFrame.new(worldPosition + Vector3.new(0, 0.68, -11.2)), Color3.fromRGB(74, 88, 118), Enum.Material.DiamondPlate)
	entryWalk.CanCollide = false
	entryWalk.CanQuery = false
	local entryPad = makePart(lounge, "Part", "EntryPad", Vector3.new(10.8, 0.24, 7.0), CFrame.new(worldPosition + Vector3.new(0, 0.84, -14.0)), palette.Accent:Lerp(Color3.fromRGB(236, 244, 255), 0.18), Enum.Material.Metal)
	entryPad.CanCollide = false
	entryPad.CanQuery = false
	local entryGlow = makeGlowPart(lounge, "EntryPadGlow", Vector3.new(7.0, 0.06, 1.8), entryPad.CFrame * CFrame.new(0, 0.16, 1.0), palette.Accent, 0.66)
	entryGlow.CanCollide = false
	entryGlow.CanQuery = false

	local returnPad = makePart(lounge, "Part", "ReturnPad", Vector3.new(8, 0.24, 6), CFrame.new(worldPosition + Vector3.new(0, 0.84, 16.0)), Color3.fromRGB(70, 76, 84), Enum.Material.Metal)
	returnPad.CanCollide = false
	returnPad.CanQuery = false
	attachWorldText(returnPad, "RETURN", Vector3.new(0, 1.62, 0), Color3.fromRGB(224, 232, 242), Vector2.new(80, 18))

	addPremiumTeleportPrompt(entryPad, "VipEnterPrompt", "Enter VIP", "VIP Operations", entryPad, "GamePassVipOperation", "RequiresVip", Vector3.new(0, 4, 0), 14)
	addTeleportPrompt(returnPad, "VipReturnPrompt", "Return", "Main Plaza", lobbyReturnPart or base, Vector3.new(0, 4, 0), 14)

	return lounge
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
		Vector3.new(1.8, 0.08, distance),
		CFrame.lookAt(midpoint, endPosition) * CFrame.new(0, 0.2, 0),
		color,
		Enum.Material.Neon
	)
	segment.Transparency = 0.88
	segment.CanCollide = false
	segment.CanQuery = false

	local lane = makePart(
		parent,
		"Part",
		name .. "Lane",
		Vector3.new(4.2, 0.05, distance),
		CFrame.lookAt(midpoint, endPosition) * CFrame.new(0, 0.05, 0),
		color:Lerp(Color3.fromRGB(44, 50, 58), 0.5),
		Enum.Material.Metal
	)
	lane.Transparency = 0.94
	lane.CanCollide = false
	lane.CanQuery = false
end

local makeStation
local makeGuidePaths
local makeDeployPad

local function buildDeployVoteBoardGui(part: BasePart, guiName: string, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = guiName
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 18
	gui.LightInfluence = 1
	gui.AlwaysOnTop = false
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.BackgroundColor3 = Color3.fromRGB(238, 232, 220)
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ClipsDescendants = true
	frame.Parent = gui

	local headerBand = Instance.new("Frame")
	headerBand.Name = "HeaderBand"
	headerBand.BackgroundColor3 = Color3.fromRGB(218, 206, 186)
	headerBand.BorderSizePixel = 0
	headerBand.Position = UDim2.fromScale(0, 0)
	headerBand.Size = UDim2.fromScale(1, 0.22)
	headerBand.Parent = frame

	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Color3.fromRGB(106, 88, 64)
	frameStroke.Thickness = 2
	frameStroke.Transparency = 0.12
	frameStroke.Parent = frame

	local header = Instance.new("TextLabel")
	header.Name = "Title"
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromScale(0.05, 0.045)
	header.Size = UDim2.fromScale(0.9, 0.1)
	header.Font = Enum.Font.GothamBlack
	header.Text = "Vote For The Next Run"
	header.TextColor3 = Color3.fromRGB(48, 38, 24)
	header.TextScaled = true
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = frame

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromScale(0.05, 0.13)
	subtitle.Size = UDim2.fromScale(0.9, 0.06)
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.Text = "Step on a floor pad to cast your vote."
	subtitle.TextColor3 = Color3.fromRGB(96, 80, 58)
	subtitle.TextScaled = true
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Parent = frame

	local topRule = Instance.new("Frame")
	topRule.BackgroundColor3 = Color3.fromRGB(212, 186, 118)
	topRule.BorderSizePixel = 0
	topRule.Position = UDim2.fromScale(0.05, 0.21)
	topRule.Size = UDim2.fromScale(0.9, 0.008)
	topRule.Parent = frame

	local sectionLabel = Instance.new("TextLabel")
	sectionLabel.Name = "SectionLabel"
	sectionLabel.BackgroundTransparency = 1
	sectionLabel.Position = UDim2.fromScale(0.05, 0.235)
	sectionLabel.Size = UDim2.fromScale(0.9, 0.05)
	sectionLabel.Font = Enum.Font.GothamBold
	sectionLabel.Text = "PAD VOTE OPTIONS"
	sectionLabel.TextColor3 = Color3.fromRGB(102, 84, 62)
	sectionLabel.TextScaled = true
	sectionLabel.TextXAlignment = Enum.TextXAlignment.Left
	sectionLabel.Parent = frame

	local cardX = { 0.04, 0.36, 0.68 }
	for index = 1, 3 do
		local option = Instance.new("Frame")
		option.Name = "Option" .. tostring(index)
		option.BackgroundColor3 = Color3.fromRGB(214, 205, 188)
		option.BorderSizePixel = 0
		option.Position = UDim2.fromScale(cardX[index], 0.31)
		option.Size = UDim2.fromScale(0.28, 0.42)
		option.Parent = frame

		local optionCorner = Instance.new("UICorner")
		optionCorner.CornerRadius = UDim.new(0, 10)
		optionCorner.Parent = option

		local optionStroke = Instance.new("UIStroke")
		optionStroke.Color = Color3.fromRGB(88, 72, 52)
		optionStroke.Transparency = 0.08
		optionStroke.Thickness = 2
		optionStroke.Parent = option

		local accentBand = Instance.new("Frame")
		accentBand.Name = "AccentBand"
		accentBand.BorderSizePixel = 0
		accentBand.Position = UDim2.fromScale(0.04, 0.08)
		accentBand.Size = UDim2.fromScale(0.02, 0.8)
		accentBand.BackgroundColor3 = ({
			Color3.fromRGB(126, 194, 126),
			Color3.fromRGB(112, 168, 228),
			Color3.fromRGB(232, 182, 108),
		})[index]
		accentBand.Parent = option

		local cardInset = Instance.new("Frame")
		cardInset.Name = "CardInset"
		cardInset.BackgroundColor3 = Color3.fromRGB(228, 220, 204)
		cardInset.BackgroundTransparency = 0.18
		cardInset.BorderSizePixel = 0
		cardInset.Position = UDim2.fromScale(0.06, 0.08)
		cardInset.Size = UDim2.fromScale(0.88, 0.84)
		cardInset.Parent = option

		local insetCorner = Instance.new("UICorner")
		insetCorner.CornerRadius = UDim.new(0, 8)
		insetCorner.Parent = cardInset

		local leadingChip = Instance.new("TextLabel")
		leadingChip.Name = "LeadingChip"
		leadingChip.Visible = false
		leadingChip.BackgroundColor3 = Color3.fromRGB(126, 196, 108)
		leadingChip.BorderSizePixel = 0
		leadingChip.Position = UDim2.fromScale(0.62, 0.08)
		leadingChip.Size = UDim2.fromScale(0.28, 0.16)
		leadingChip.Font = Enum.Font.GothamBlack
		leadingChip.Text = "LEADING"
		leadingChip.TextColor3 = Color3.fromRGB(24, 44, 22)
		leadingChip.TextScaled = true
		leadingChip.Parent = option

		local leadingCorner = Instance.new("UICorner")
		leadingCorner.CornerRadius = UDim.new(0, 8)
		leadingCorner.Parent = leadingChip

		local padChip = Instance.new("TextLabel")
		padChip.Name = "PadLabel"
		padChip.BackgroundColor3 = Color3.fromRGB(198, 178, 138)
		padChip.BorderSizePixel = 0
		padChip.Position = UDim2.fromScale(0.1, 0.08)
		padChip.Size = UDim2.fromScale(0.4, 0.15)
		padChip.Font = Enum.Font.GothamBlack
		padChip.Text = "PAD " .. tostring(index)
		padChip.TextColor3 = Color3.fromRGB(54, 40, 22)
		padChip.TextScaled = true
		padChip.Parent = option

		local chipCorner = Instance.new("UICorner")
		chipCorner.CornerRadius = UDim.new(0, 8)
		chipCorner.Parent = padChip

		local mapName = Instance.new("TextLabel")
		mapName.Name = "MapName"
		mapName.BackgroundTransparency = 1
		mapName.Position = UDim2.fromScale(0.1, 0.28)
		mapName.Size = UDim2.fromScale(0.8, 0.22)
		mapName.Font = Enum.Font.GothamBlack
		mapName.Text = "Map Name"
		mapName.TextColor3 = Color3.fromRGB(34, 28, 18)
		mapName.TextScaled = true
		mapName.TextTruncate = Enum.TextTruncate.AtEnd
		mapName.TextWrapped = true
		mapName.TextXAlignment = Enum.TextXAlignment.Left
		mapName.TextYAlignment = Enum.TextYAlignment.Center
		mapName.Parent = option

		local scenario = Instance.new("TextLabel")
		scenario.Name = "Scenario"
		scenario.BackgroundTransparency = 1
		scenario.Position = UDim2.fromScale(0.1, 0.54)
		scenario.Size = UDim2.fromScale(0.8, 0.12)
		scenario.Font = Enum.Font.GothamMedium
		scenario.Text = "Scenario"
		scenario.TextColor3 = Color3.fromRGB(92, 78, 60)
		scenario.TextScaled = true
		scenario.TextTruncate = Enum.TextTruncate.AtEnd
		scenario.TextXAlignment = Enum.TextXAlignment.Left
		scenario.Parent = option

		local voteRule = Instance.new("Frame")
		voteRule.Name = "VoteRule"
		voteRule.BackgroundColor3 = Color3.fromRGB(188, 170, 140)
		voteRule.BorderSizePixel = 0
		voteRule.Position = UDim2.fromScale(0.1, 0.69)
		voteRule.Size = UDim2.fromScale(0.8, 0.012)
		voteRule.Parent = option

		local votes = Instance.new("TextLabel")
		votes.Name = "Votes"
		votes.BackgroundTransparency = 1
		votes.Position = UDim2.fromScale(0.1, 0.72)
		votes.Size = UDim2.fromScale(0.8, 0.16)
		votes.Font = Enum.Font.GothamBlack
		votes.Text = "0 votes"
		votes.TextColor3 = Color3.fromRGB(44, 104, 58)
		votes.TextScaled = true
		votes.TextXAlignment = Enum.TextXAlignment.Left
		votes.Parent = option
	end

	local footer = Instance.new("TextLabel")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.Position = UDim2.fromScale(0.05, 0.88)
	footer.Size = UDim2.fromScale(0.9, 0.06)
	footer.Font = Enum.Font.GothamMedium
	footer.Text = "Stand on a pad, then step onto launch when your squad is ready."
	footer.TextColor3 = Color3.fromRGB(110, 94, 72)
	footer.TextScaled = true
	footer.TextXAlignment = Enum.TextXAlignment.Center
	footer.Parent = frame

	return gui
end

local function attachDeployVoteBoard(part: BasePart)
	clearNamedChildren(part, { "BoardGui", "BoardGuiMirror" })
	buildDeployVoteBoardGui(part, "BoardGui", Enum.NormalId.Front)
end

clearNamedChildren = function(parent: Instance, childNames: { string })
	for _, childName in ipairs(childNames) do
		local child = parent:FindFirstChild(childName)
		if child then
			child:Destroy()
		end
	end
end

local function clearBoardPresentation(part: BasePart)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("SurfaceGui") or child:IsA("BillboardGui") then
			child:Destroy()
		end
	end
end

local function normalizeLobbySpawnPoints(lobbyModel: Instance)
	local outerGround = lobbyModel:FindFirstChild("OuterGround", true)
	local worldOrigin = Config.Origin
	if outerGround and outerGround:IsA("BasePart") then
		worldOrigin = outerGround.Position - Vector3.new(0, -1.2, 0)
	else
		local primary = lobbyModel:IsA("Model") and lobbyModel.PrimaryPart or lobbyModel:FindFirstChildWhichIsA("BasePart", true)
		if primary and primary:IsA("BasePart") then
			worldOrigin = primary.Position
		end
	end

	local preferredSpawn = lobbyModel:FindFirstChild("LobbySpawn", true)
	if not (preferredSpawn and preferredSpawn:IsA("SpawnLocation")) then
		preferredSpawn = nil
	end

	if not preferredSpawn then
		for _, descendant in ipairs(lobbyModel:GetDescendants()) do
			if descendant:IsA("SpawnLocation") and descendant:FindFirstAncestor("MissionStaging") == nil then
				preferredSpawn = descendant
				preferredSpawn.Name = "LobbySpawn"
				break
			end
		end
	end

	if not preferredSpawn then
		preferredSpawn = Instance.new("SpawnLocation")
		preferredSpawn.Name = "LobbySpawn"
		preferredSpawn.Parent = lobbyModel
		preferredSpawn.CFrame = CFrame.new(worldOrigin + Config.SpawnOffset + Config.SpawnLayout.SpawnLocation.Offset)
	end

	preferredSpawn.Size = Config.SpawnLayout.SpawnLocation.Size
	preferredSpawn.Anchored = true
	preferredSpawn.CanCollide = true
	preferredSpawn.Neutral = true
	preferredSpawn.Enabled = true
	preferredSpawn.Duration = 0
	preferredSpawn.Material = Enum.Material.Concrete
	preferredSpawn.Color = Config.SpawnLayout.SpawnLocation.Color
	CollectionService:AddTag(preferredSpawn, "LobbySpawn")

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("SpawnLocation") and descendant ~= preferredSpawn then
			descendant.Enabled = false
			if CollectionService:HasTag(descendant, "LobbySpawn") then
				CollectionService:RemoveTag(descendant, "LobbySpawn")
			end
		end
	end

	return preferredSpawn
end

local function ensureLobbyArrivalAnchor(lobbyModel: Instance): BasePart?
	local existing = lobbyModel:FindFirstChild("LobbyArrivalAnchor", true)
	if existing and existing:IsA("BasePart") then
		CollectionService:AddTag(existing, "LobbySpawn")
		existing.Anchored = true
		existing.CanCollide = false
		existing.CanQuery = false
		existing.Transparency = 1
		return existing
	end

	local preferredSpawn = lobbyModel:FindFirstChild("LobbySpawn", true)
	local anchorCFrame
	if preferredSpawn and preferredSpawn:IsA("BasePart") then
		anchorCFrame = preferredSpawn.CFrame + Vector3.new(0, 4, 0)
	elseif lobbyModel:IsA("Model") then
		local boundsCFrame, boundsSize = lobbyModel:GetBoundingBox()
		anchorCFrame = boundsCFrame + Vector3.new(0, math.max(6, boundsSize.Y * 0.1), 0)
	else
		local primary = lobbyModel:FindFirstChildWhichIsA("BasePart", true)
		if primary then
			anchorCFrame = primary.CFrame + Vector3.new(0, 6, 0)
		end
	end

	if not anchorCFrame then
		return nil
	end

	local anchor = Instance.new("Part")
	anchor.Name = "LobbyArrivalAnchor"
	anchor.Size = Vector3.new(4, 1, 4)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.CFrame = anchorCFrame
	anchor.Parent = lobbyModel
	CollectionService:AddTag(anchor, "LobbySpawn")
	return anchor
end

local function clearLegacyLeaderboardRigs(lobbyModel: Instance)
	local monument = lobbyModel:FindFirstChild("LeaderboardMonument", true)
	if not monument then
		return
	end

	for _, child in ipairs(monument:GetChildren()) do
		if child:IsA("Model") then
			local humanoid = child:FindFirstChildWhichIsA("Humanoid", true)
			local normalizedName = string.lower((child.Name:gsub("[%s%p_]+", "")))
			if humanoid
				or string.find(normalizedName, "podium", 1, true)
				or string.find(normalizedName, "top1", 1, true)
				or string.find(normalizedName, "top2", 1, true)
				or string.find(normalizedName, "top3", 1, true)
				or string.find(normalizedName, "rig", 1, true)
			then
				child:Destroy()
			end
		end
	end
end

local function ensurePrompt(part: BasePart, promptName: string, actionText: string, objectText: string, maxDistance: number)
	local prompt = part:FindFirstChild(promptName)
	if not (prompt and prompt:IsA("ProximityPrompt")) then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = promptName
		prompt.Parent = part
	end

	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = maxDistance
	return prompt
end

local makeMissionStaging
local makeOpenSkyLobby

local function publishLobbyExport(lobbyModel: Instance)
	return
end

local function ensureLobbyActivityContent(lobbyModel: Instance)
	if not lobbyModel then
		return
	end

	local spawn = lobbyModel:FindFirstChild("LobbySpawn", true)
	local worldOrigin
	if spawn and spawn:IsA("BasePart") then
		worldOrigin = spawn.Position - Config.SpawnOffset
	else
		local primary = lobbyModel:IsA("Model") and lobbyModel.PrimaryPart or lobbyModel:FindFirstChildWhichIsA("BasePart", true)
		if primary and primary:IsA("BasePart") then
			worldOrigin = primary.Position
		else
			worldOrigin = Config.Origin
		end
	end

	local lobbyReturnAnchor = lobbyModel:FindFirstChild("LobbyReturnAnchor", true)
	if not (lobbyReturnAnchor and lobbyReturnAnchor:IsA("BasePart")) then
		lobbyReturnAnchor = spawn
	end

	if Config.Areas.Training then
		ensureCompleteActivityModel(lobbyModel, "TrainingYard", REQUIRED_ACTIVITY_PARTS.TrainingYard, function()
			return makeTrainingYard(lobbyModel, worldOrigin + Config.Areas.Training.Offset, Config.Areas.Training, lobbyReturnAnchor)
		end)
	end
	if Config.Areas.Parkour then
		ensureCompleteActivityModel(lobbyModel, "ParkourCourse", REQUIRED_ACTIVITY_PARTS.ParkourCourse, function()
			return makeParkourCourse(lobbyModel, worldOrigin + Config.Areas.Parkour.Offset, Config.Areas.Parkour, lobbyReturnAnchor)
		end)
	end
	if Config.Areas.TargetRange then
		ensureCompleteActivityModel(lobbyModel, "TargetRange", REQUIRED_ACTIVITY_PARTS.TargetRange, function()
			return makeTargetRange(lobbyModel, worldOrigin + Config.Areas.TargetRange.Offset, Config.Areas.TargetRange, lobbyReturnAnchor)
		end)
	end
	if Config.Areas.Salvage then
		ensureCompleteActivityModel(lobbyModel, "SalvageRun", REQUIRED_ACTIVITY_PARTS.SalvageRun, function()
			return makeSalvageRun(lobbyModel, worldOrigin + Config.Areas.Salvage.Offset, Config.Areas.Salvage, lobbyReturnAnchor)
		end)
	end
end

local function getActiveLobbyCompositionRoot(): Instance?
	local root = Workspace:FindFirstChild(Config.RootName)
	if not root then
		for _, child in ipairs(Workspace:GetChildren()) do
			if child:GetAttribute("WorldType") == "LobbyHub" then
				root = child
				break
			end
		end
	end
	if not root then
		return nil
	end
	if root:IsA("Model") then
		return root
	end
	return root:FindFirstChildWhichIsA("Model")
end

local function getLobbyWorldOrigin(lobbyRoot: Instance): Vector3
	if not lobbyRoot then
		return Config.Origin
	end

	local spawn = lobbyRoot:FindFirstChild("LobbySpawn", true)
	if spawn and spawn:IsA("BasePart") then
		return spawn.Position - Config.SpawnOffset
	end

	local anchor = lobbyRoot:FindFirstChild("OuterGround", true)
	if anchor and anchor:IsA("BasePart") then
		return anchor.Position - Vector3.new(0, -1.2, 0)
	end

	local primary = lobbyRoot:IsA("Model") and lobbyRoot.PrimaryPart or lobbyRoot:FindFirstChildWhichIsA("BasePart", true)
	if primary and primary:IsA("BasePart") then
		return primary.Position
	end

	return Config.Origin
end

local function isSystemAnchorDescendant(instance: Instance): boolean
	return instance:FindFirstAncestor("MissionStaging") ~= nil
		or instance:FindFirstAncestor("LeaderboardMonument") ~= nil
		or instance:FindFirstAncestor("Vote Model") ~= nil
		or instance:FindFirstAncestor("map vote") ~= nil
		or instance:FindFirstAncestor("donation") ~= nil
		or instance:FindFirstAncestor("TrainingYard") ~= nil
		or instance:FindFirstAncestor("ParkourCourse") ~= nil
		or instance:FindFirstAncestor("TargetRange") ~= nil
		or instance:FindFirstAncestor("SalvageRun") ~= nil
		or instance:FindFirstAncestor("CentralHub") ~= nil
		or instance:FindFirstAncestor("DuelRing") ~= nil
		or instance:FindFirstAncestor("SpawnZone") ~= nil
		or instance:FindFirstAncestor("NorthPatrol") ~= nil
		or instance:FindFirstAncestor("OpsCoordinator") ~= nil
		or instance:FindFirstAncestor("LobbyMetadata") ~= nil
end

local function hasPlayableLobbyGeometry(lobbyModel: Instance): boolean
	if lobbyModel:FindFirstChild("PlayableShell") then
		return true
	end

	local largeFloorCount = 0
	local structuralCount = 0
	for _, descendant in ipairs(lobbyModel:GetDescendants()) do
		if descendant:IsA("BasePart") and not isSystemAnchorDescendant(descendant) then
			local size = descendant.Size
			local isLargeFloor = size.X >= 80 and size.Z >= 80 and size.Y <= 8
			local isMajorStructure = (size.X >= 40 and size.Z >= 40) or (size.Y >= 16 and (size.X >= 4 or size.Z >= 4))
			if isLargeFloor then
				largeFloorCount += 1
			end
			if isMajorStructure then
				structuralCount += 1
			end
		end
	end

	return largeFloorCount >= 1 and structuralCount >= 6
end

local function findAnchorPosition(root: Instance, names: { string }, fallback: Vector3): Vector3
	for _, name in ipairs(names) do
		local instance = root:FindFirstChild(name, true)
		if instance then
			if instance:IsA("BasePart") then
				return instance.Position
			end
			if instance:IsA("Model") then
				local primary = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
				if primary then
					return primary.Position
				end
			end
		end
	end
	return fallback
end

local function buildPlayableLobbyShell(lobbyModel: Instance, worldOrigin: Vector3)
	local shell = Instance.new("Model")
	shell.Name = "PlayableShell"
	shell.Parent = lobbyModel

	local shellFloorColor = Color3.fromRGB(28, 32, 40)
	local shellTrimColor = Color3.fromRGB(116, 132, 156)
	local wallColor = Color3.fromRGB(46, 52, 62)
	local ceilingColor = Color3.fromRGB(34, 38, 46)

	local floor = makePart(
		shell,
		"Part",
		"OuterGround",
		Vector3.new(300, 2, 276),
		CFrame.new(worldOrigin + Vector3.new(0, -1, 0)),
		shellFloorColor,
		Enum.Material.SmoothPlastic
	)
	floor.CanQuery = false

	local concourse = makePart(
		shell,
		"Part",
		"MainConcourse",
		Vector3.new(232, 1.2, 188),
		CFrame.new(worldOrigin + Vector3.new(0, -0.4, 4)),
		Color3.fromRGB(34, 38, 46),
		Enum.Material.DiamondPlate
	)
	concourse.CanQuery = false
	makeGlowPart(shell, "MainConcourseTrim", Vector3.new(236, 0.08, 192), concourse.CFrame * CFrame.new(0, 0.66, 0), shellTrimColor, 0.9).CanQuery = false

	for _, deckInfo in ipairs({
		{ "WestGalleryDeck", Vector3.new(86, 1, 116), Vector3.new(-92, -0.46, 14), Color3.fromRGB(40, 42, 36) },
		{ "EastGalleryDeck", Vector3.new(86, 1, 116), Vector3.new(92, -0.46, 14), Color3.fromRGB(36, 40, 46) },
		{ "SouthArchiveDeck", Vector3.new(124, 1, 56), Vector3.new(0, -0.46, 98), Color3.fromRGB(42, 40, 36) },
		{ "NorthDeployDeck", Vector3.new(108, 1, 52), Vector3.new(0, -0.46, -98), Color3.fromRGB(46, 38, 36) },
	}) do
		local deck = makePart(
			shell,
			"Part",
			deckInfo[1],
			deckInfo[2],
			CFrame.new(worldOrigin + deckInfo[3]),
			deckInfo[4],
			Enum.Material.Metal
		)
		deck.CanQuery = false
		makeGlowPart(shell, deckInfo[1] .. "Glow", Vector3.new(deckInfo[2].X - 6, 0.06, deckInfo[2].Z - 6), deck.CFrame * CFrame.new(0, 0.56, 0), shellTrimColor, 0.92).CanQuery = false
	end

	local ceiling = makePart(
		shell,
		"Part",
		"Ceiling",
		Vector3.new(300, 2, 276),
		CFrame.new(worldOrigin + Vector3.new(0, 26, 0)),
		ceilingColor,
		Enum.Material.Metal
	)
	ceiling.CanQuery = false

	local wallData = {
		{ "NorthWall", Vector3.new(300, 24, 4), Vector3.new(0, 11, -138) },
		{ "SouthWall", Vector3.new(300, 24, 4), Vector3.new(0, 11, 138) },
		{ "WestWall", Vector3.new(4, 24, 268), Vector3.new(-148, 11, 0) },
		{ "EastWall", Vector3.new(4, 24, 268), Vector3.new(148, 11, 0) },
	}
	for _, info in ipairs(wallData) do
		local wall = makePart(
			shell,
			"Part",
			info[1],
			info[2],
			CFrame.new(worldOrigin + info[3]),
			wallColor,
			Enum.Material.Metal
		)
		wall.CanQuery = false
	end

	for _, trimInfo in ipairs({
		{ "NorthTrim", Vector3.new(286, 0.24, 1.2), Vector3.new(0, 21.6, -135.8) },
		{ "SouthTrim", Vector3.new(286, 0.24, 1.2), Vector3.new(0, 21.6, 135.8) },
		{ "WestTrim", Vector3.new(1.2, 0.24, 254), Vector3.new(-145.8, 21.6, 0) },
		{ "EastTrim", Vector3.new(1.2, 0.24, 254), Vector3.new(145.8, 21.6, 0) },
	}) do
		makeGlowPart(shell, trimInfo[1], trimInfo[2], CFrame.new(worldOrigin + trimInfo[3]), shellTrimColor, 0.24).CanQuery = false
	end

	for _, offset in ipairs({
		Vector3.new(-132, 12, -122),
		Vector3.new(132, 12, -122),
		Vector3.new(-132, 12, 122),
		Vector3.new(132, 12, 122),
	}) do
		local pillar = makePart(
			shell,
			"Part",
			"CornerPillar",
			Vector3.new(8, 24, 8),
			CFrame.new(worldOrigin + offset),
			Color3.fromRGB(58, 66, 80),
			Enum.Material.Metal
		)
		pillar.CanQuery = false
	end

	local centerPlatform = makePart(
		shell,
		"Part",
		"CenterPlatform",
		Vector3.new(64, 3, 64),
		CFrame.new(worldOrigin + Vector3.new(0, 1.5, 0)),
		Color3.fromRGB(54, 62, 74),
		Enum.Material.DiamondPlate
	)
	centerPlatform.CanQuery = false
	makeGlowPart(shell, "CenterPlatformTrim", Vector3.new(68, 0.1, 68), centerPlatform.CFrame * CFrame.new(0, 1.56, 0), shellTrimColor, 0.82).CanQuery = false

	for _, rampInfo in ipairs({
		{ "NorthRamp", Vector3.new(14, 1.2, 18), Vector3.new(0, 0.62, -40) },
		{ "SouthRamp", Vector3.new(14, 1.2, 18), Vector3.new(0, 0.62, 40) },
		{ "WestRamp", Vector3.new(18, 1.2, 14), Vector3.new(-40, 0.62, 0) },
		{ "EastRamp", Vector3.new(18, 1.2, 14), Vector3.new(40, 0.62, 0) },
	}) do
		local ramp = makePart(
			shell,
			"Part",
			rampInfo[1],
			rampInfo[2],
			CFrame.new(worldOrigin + rampInfo[3]),
			Color3.fromRGB(62, 68, 80),
			Enum.Material.Metal
		)
		ramp.CanQuery = false
		makeGlowPart(shell, rampInfo[1] .. "Glow", Vector3.new(math.max(rampInfo[2].X - 3, 8), 0.06, math.max(rampInfo[2].Z - 3, 8)), ramp.CFrame * CFrame.new(0, 0.66, 0), shellTrimColor, 0.88).CanQuery = false
	end

	local lanes = {
		{ "NorthSpine", Vector3.new(26, 1.2, 94), Vector3.new(0, 0.6, -72), Color3.fromRGB(82, 66, 62), Color3.fromRGB(244, 184, 156) },
		{ "SouthSpine", Vector3.new(26, 1.2, 88), Vector3.new(0, 0.6, 74), Color3.fromRGB(64, 62, 58), Color3.fromRGB(240, 224, 182) },
		{ "WestWingLane", Vector3.new(98, 1.2, 28), Vector3.new(-82, 0.6, 8), Color3.fromRGB(64, 66, 58), Color3.fromRGB(234, 214, 146) },
		{ "EastWingLane", Vector3.new(98, 1.2, 28), Vector3.new(82, 0.6, 8), Color3.fromRGB(58, 64, 68), Color3.fromRGB(156, 194, 244) },
	}
	for _, lane in ipairs(lanes) do
		local plate = makePart(
			shell,
			"Part",
			lane[1],
			lane[2],
			CFrame.new(worldOrigin + lane[3]),
			lane[4],
			Enum.Material.Metal
		)
		plate.CanQuery = false
		makeGlowPart(shell, lane[1] .. "Glow", Vector3.new(lane[2].X - 4, 0.08, math.max(lane[2].Z - 4, 8)), plate.CFrame * CFrame.new(0, lane[2].Y * 0.5 + 0.08, 0), lane[5], 0.88).CanQuery = false
	end

	for _, divider in ipairs({
		{ "NorthDeployFrame", Vector3.new(58, 12, 3), Vector3.new(0, 6, -98), Color3.fromRGB(84, 58, 54), Color3.fromRGB(244, 186, 164), "DEPLOY" },
		{ "SouthArchiveFrame", Vector3.new(56, 12, 3), Vector3.new(0, 6, 104), Color3.fromRGB(74, 70, 58), Color3.fromRGB(236, 224, 182), "ARCHIVE" },
		{ "WestTrainingFrame", Vector3.new(3, 12, 58), Vector3.new(-92, 6, 8), Color3.fromRGB(78, 74, 56), Color3.fromRGB(234, 214, 146), "TRAINING" },
		{ "EastOpsFrame", Vector3.new(3, 12, 58), Vector3.new(92, 6, 8), Color3.fromRGB(60, 70, 82), Color3.fromRGB(156, 194, 244), "OPERATIONS" },
	}) do
		local frame = makePart(
			shell,
			"Part",
			divider[1],
			divider[2],
			CFrame.new(worldOrigin + divider[3]),
			divider[4],
			Enum.Material.Metal
		)
		frame.CanQuery = false
		makeGlowPart(shell, divider[1] .. "Accent", Vector3.new(math.max(divider[2].X - 1, 1), 0.14, math.max(divider[2].Z - 1, 1)), frame.CFrame * CFrame.new(0, divider[2].Y * 0.45, 0), divider[5], 0.72).CanQuery = false
		attachWorldText(frame, divider[6], Vector3.new(0, divider[2].Y * 0.45 + 0.8, 0), divider[5], Vector2.new(112, 18))
		local signGlow = makeGlowPart(
			shell,
			divider[1] .. "SignGlow",
			Vector3.new(math.max(divider[2].X - 10, 10), 0.08, math.max(divider[2].Z - 1.6, 1)),
			frame.CFrame * CFrame.new(0, divider[2].Y * 0.45 - 0.18, 0),
			divider[5],
			0.82
		)
		signGlow.CanQuery = false
	end

	local boardZones = {
		{
			"VoteZone",
			findAnchorPosition(lobbyModel, { "Vote Model", "map vote", "VoteBoard", "DeployVoteDeck" }, worldOrigin + Vector3.new(0, 0, -104)),
			Vector3.new(60, 10, 28),
			Color3.fromRGB(96, 62, 56),
			Color3.fromRGB(244, 186, 164),
		},
		{
			"DonationZone",
			findAnchorPosition(lobbyModel, { "donation", "SupportTerminal" }, worldOrigin + Vector3.new(92, 0, 18)),
			Vector3.new(28, 8, 24),
			Color3.fromRGB(82, 72, 48),
			Color3.fromRGB(244, 214, 132),
		},
		{
			"LeaderboardZone",
			findAnchorPosition(lobbyModel, { "LeaderboardMonument", "MasterBoard", "LeaderboardBoard", "BoardFace", "Leaderboard (Levels)" }, worldOrigin + Vector3.new(-116, 0, 92)),
			Vector3.new(58, 12, 28),
			Color3.fromRGB(72, 68, 60),
			Color3.fromRGB(236, 224, 182),
		},
	}
	for _, zone in ipairs(boardZones) do
		local pos = zone[2]
		local platform = makePart(
			shell,
			"Part",
			zone[1] .. "Platform",
			Vector3.new(zone[3].X, 1.2, zone[3].Z),
			CFrame.new(Vector3.new(pos.X, worldOrigin.Y + 0.6, pos.Z)),
			zone[4],
			Enum.Material.Metal
		)
		platform.CanQuery = false
		local backplate = makePart(
			shell,
			"Part",
			zone[1] .. "Backplate",
			zone[3],
			CFrame.new(Vector3.new(pos.X, worldOrigin.Y + zone[3].Y * 0.5, pos.Z - zone[3].Z * 0.5 - 1.6)),
			wallColor,
			Enum.Material.Metal
		)
		backplate.CanQuery = false
		makeGlowPart(shell, zone[1] .. "Accent", Vector3.new(zone[3].X - 8, 0.12, 1), backplate.CFrame * CFrame.new(0, zone[3].Y * 0.35, 2.1), zone[5], 0.62).CanQuery = false
		local threshold = makePart(
			shell,
			"Part",
			zone[1] .. "Threshold",
			Vector3.new(math.max(zone[3].X * 0.34, 12), 0.16, 2.2),
			CFrame.new(Vector3.new(pos.X, worldOrigin.Y + 0.18, pos.Z + zone[3].Z * 0.5 - 1.8)),
			Color3.fromRGB(74, 80, 92),
			Enum.Material.Metal
		)
		threshold.CanQuery = false
		makeGlowPart(shell, zone[1] .. "ThresholdGlow", Vector3.new(math.max(zone[3].X * 0.34 - 2, 10), 0.06, 0.8), threshold.CFrame * CFrame.new(0, 0.14, 0), zone[5], 0.76).CanQuery = false
		attachWorldText(backplate, string.upper(string.gsub(zone[1], "Zone", "")), Vector3.new(0, zone[3].Y * 0.32 + 0.8, 0), zone[5], Vector2.new(108, 18))
	end

	local leaderboardCore = findAnchorPosition(lobbyModel, { "LeaderboardMonument", "MasterBoard", "LeaderboardBoard", "BoardFace", "Leaderboard (Levels)" }, worldOrigin + Vector3.new(-116, 0, 92))
	local leaderboardDeck = makePart(
		shell,
		"Part",
		"LeaderboardDeck",
		Vector3.new(68, 1.2, 34),
		CFrame.new(Vector3.new(leaderboardCore.X, worldOrigin.Y + 0.6, leaderboardCore.Z + 8)),
		Color3.fromRGB(78, 72, 60),
		Enum.Material.DiamondPlate
	)
	leaderboardDeck.CanQuery = false
	makeGlowPart(shell, "LeaderboardDeckGlow", Vector3.new(60, 0.08, 24), leaderboardDeck.CFrame * CFrame.new(0, 0.66, -1.2), Color3.fromRGB(236, 224, 182), 0.84).CanQuery = false
	local leaderboardHeader = makePart(
		shell,
		"Part",
		"LeaderboardHeader",
		Vector3.new(46, 1.1, 2.6),
		CFrame.new(Vector3.new(leaderboardCore.X, worldOrigin.Y + 9.8, leaderboardCore.Z - 8.6)),
		Color3.fromRGB(86, 78, 60),
		Enum.Material.Metal
	)
	leaderboardHeader.CanQuery = false
	makeGlowPart(shell, "LeaderboardHeaderGlow", Vector3.new(36, 0.12, 0.8), leaderboardHeader.CFrame * CFrame.new(0, 0.28, 0.8), Color3.fromRGB(236, 224, 182), 0.62).CanQuery = false
	attachWorldText(leaderboardHeader, "ARCHIVE RANKING", Vector3.new(0, 1.1, 0), Color3.fromRGB(240, 228, 192), Vector2.new(132, 18))
	for _, bollardOffset in ipairs({
		Vector3.new(-24, 1.1, 18),
		Vector3.new(-10, 1.1, 18),
		Vector3.new(10, 1.1, 18),
		Vector3.new(24, 1.1, 18),
	}) do
		local bollard = makePart(
			shell,
			"Part",
			"LeaderboardBollard",
			Vector3.new(1.2, 2.2, 1.2),
			CFrame.new(Vector3.new(leaderboardCore.X, worldOrigin.Y, leaderboardCore.Z) + bollardOffset),
			Color3.fromRGB(112, 100, 76),
			Enum.Material.Metal
		)
		bollard.CanQuery = false
		makeGlowPart(shell, "LeaderboardBollardGlow", Vector3.new(1.4, 0.1, 1.4), bollard.CFrame * CFrame.new(0, 1.14, 0), Color3.fromRGB(250, 236, 196), 0.42).CanQuery = false
	end

	local donationCore = findAnchorPosition(lobbyModel, { "donation", "SupportTerminal" }, worldOrigin + Vector3.new(92, 0, 18))
	local donationDeck = makePart(
		shell,
		"Part",
		"DonationDeck",
		Vector3.new(34, 1.1, 28),
		CFrame.new(Vector3.new(donationCore.X, worldOrigin.Y + 0.55, donationCore.Z + 4)),
		Color3.fromRGB(92, 80, 52),
		Enum.Material.DiamondPlate
	)
	donationDeck.CanQuery = false
	makeGlowPart(shell, "DonationDeckGlow", Vector3.new(26, 0.08, 18), donationDeck.CFrame * CFrame.new(0, 0.62, -0.6), Color3.fromRGB(244, 214, 132), 0.82).CanQuery = false
	local donationHeader = makePart(
		shell,
		"Part",
		"DonationHeader",
		Vector3.new(22, 1.1, 2.2),
		CFrame.new(Vector3.new(donationCore.X, worldOrigin.Y + 8.4, donationCore.Z - 7.4)),
		Color3.fromRGB(98, 82, 52),
		Enum.Material.Metal
	)
	donationHeader.CanQuery = false
	makeGlowPart(shell, "DonationHeaderGlow", Vector3.new(18, 0.12, 0.8), donationHeader.CFrame * CFrame.new(0, 0.28, 0.8), Color3.fromRGB(244, 214, 132), 0.62).CanQuery = false
	attachWorldText(donationHeader, "SUPPORT NODE", Vector3.new(0, 1.1, 0), Color3.fromRGB(252, 228, 160), Vector2.new(120, 18))
	for _, side in ipairs({ -1, 1 }) do
		local post = makePart(
			shell,
			"Part",
			"DonationPost",
			Vector3.new(1.8, 6.8, 1.8),
			CFrame.new(Vector3.new(donationCore.X + side * 14, worldOrigin.Y + 3.4, donationCore.Z + 2)),
			Color3.fromRGB(106, 90, 58),
			Enum.Material.Metal
		)
		post.CanQuery = false
		makeGlowPart(shell, "DonationPostGlow", Vector3.new(1.6, 0.12, 1.6), post.CFrame * CFrame.new(0, 3.42, 0), Color3.fromRGB(244, 214, 132), 0.38).CanQuery = false
	end
	local donorBench = makePart(
		shell,
		"Part",
		"DonationBench",
		Vector3.new(9, 1, 2.8),
		CFrame.new(Vector3.new(donationCore.X - 12, worldOrigin.Y + 0.5, donationCore.Z + 13)),
		Color3.fromRGB(114, 98, 70),
		Enum.Material.WoodPlanks
	)
	donorBench.CanQuery = false

	local contractCore = findAnchorPosition(lobbyModel, { "QuestBoard", "ContractBoard", "Contracts" }, worldOrigin + Vector3.new(-48, 0, -102))
	local contractDeck = makePart(
		shell,
		"Part",
		"ContractDeck",
		Vector3.new(42, 1.1, 24),
		CFrame.new(Vector3.new(contractCore.X, worldOrigin.Y + 0.55, contractCore.Z + 6)),
		Color3.fromRGB(88, 64, 54),
		Enum.Material.DiamondPlate
	)
	contractDeck.CanQuery = false
	makeGlowPart(shell, "ContractDeckGlow", Vector3.new(34, 0.08, 16), contractDeck.CFrame * CFrame.new(0, 0.62, -0.6), Color3.fromRGB(244, 186, 164), 0.84).CanQuery = false
	local contractHeader = makePart(
		shell,
		"Part",
		"ContractHeader",
		Vector3.new(28, 1.1, 2.2),
		CFrame.new(Vector3.new(contractCore.X, worldOrigin.Y + 8.8, contractCore.Z - 6.4)),
		Color3.fromRGB(98, 64, 56),
		Enum.Material.Metal
	)
	contractHeader.CanQuery = false
	makeGlowPart(shell, "ContractHeaderGlow", Vector3.new(22, 0.12, 0.8), contractHeader.CFrame * CFrame.new(0, 0.28, 0.8), Color3.fromRGB(244, 186, 164), 0.62).CanQuery = false
	attachWorldText(contractHeader, "CONTRACT BOARD", Vector3.new(0, 1.08, 0), Color3.fromRGB(255, 214, 190), Vector2.new(124, 18))

	local challengeCore = findAnchorPosition(lobbyModel, { "DailyBoard", "WeeklyBoard", "ChallengeBoard", "QuestBoard" }, worldOrigin + Vector3.new(46, 0, 102))
	local challengeDeck = makePart(
		shell,
		"Part",
		"ChallengeDeck",
		Vector3.new(44, 1.1, 24),
		CFrame.new(Vector3.new(challengeCore.X, worldOrigin.Y + 0.55, challengeCore.Z + 4)),
		Color3.fromRGB(84, 78, 56),
		Enum.Material.DiamondPlate
	)
	challengeDeck.CanQuery = false
	makeGlowPart(shell, "ChallengeDeckGlow", Vector3.new(36, 0.08, 16), challengeDeck.CFrame * CFrame.new(0, 0.62, -0.4), Color3.fromRGB(236, 224, 182), 0.84).CanQuery = false
	local challengeHeader = makePart(
		shell,
		"Part",
		"ChallengeHeader",
		Vector3.new(30, 1.1, 2.2),
		CFrame.new(Vector3.new(challengeCore.X, worldOrigin.Y + 8.8, challengeCore.Z - 6.4)),
		Color3.fromRGB(92, 84, 60),
		Enum.Material.Metal
	)
	challengeHeader.CanQuery = false
	makeGlowPart(shell, "ChallengeHeaderGlow", Vector3.new(24, 0.12, 0.8), challengeHeader.CFrame * CFrame.new(0, 0.28, 0.8), Color3.fromRGB(236, 224, 182), 0.62).CanQuery = false
	attachWorldText(challengeHeader, "DAILY OPS", Vector3.new(0, 1.08, 0), Color3.fromRGB(240, 228, 192), Vector2.new(118, 18))

	local quartermasterCore = findAnchorPosition(lobbyModel, { "Shop", "Inventory", "SkillTree" }, worldOrigin + Vector3.new(112, 0, 4))
	local quartermasterDeck = makePart(
		shell,
		"Part",
		"QuartermasterDeck",
		Vector3.new(56, 1.1, 34),
		CFrame.new(Vector3.new(quartermasterCore.X, worldOrigin.Y + 0.55, quartermasterCore.Z)),
		Color3.fromRGB(62, 76, 96),
		Enum.Material.DiamondPlate
	)
	quartermasterDeck.CanQuery = false
	makeGlowPart(shell, "QuartermasterDeckGlow", Vector3.new(48, 0.08, 24), quartermasterDeck.CFrame * CFrame.new(0, 0.62, 0), Color3.fromRGB(156, 194, 244), 0.84).CanQuery = false
	local quartermasterHeader = makePart(
		shell,
		"Part",
		"QuartermasterHeader",
		Vector3.new(34, 1.1, 2.4),
		CFrame.new(Vector3.new(quartermasterCore.X, worldOrigin.Y + 8.8, quartermasterCore.Z - 10.8)),
		Color3.fromRGB(70, 84, 106),
		Enum.Material.Metal
	)
	quartermasterHeader.CanQuery = false
	makeGlowPart(shell, "QuartermasterHeaderGlow", Vector3.new(28, 0.12, 0.8), quartermasterHeader.CFrame * CFrame.new(0, 0.28, 0.8), Color3.fromRGB(156, 194, 244), 0.62).CanQuery = false
	attachWorldText(quartermasterHeader, "QUARTERMASTER", Vector3.new(0, 1.08, 0), Color3.fromRGB(192, 220, 255), Vector2.new(132, 18))
	for _, kioskOffset in ipairs({
		Vector3.new(-16, 1.05, -6),
		Vector3.new(0, 1.05, -6),
		Vector3.new(16, 1.05, -6),
	}) do
		local kiosk = makePart(
			shell,
			"Part",
			"QuartermasterKiosk",
			Vector3.new(10, 2.1, 10),
			CFrame.new(Vector3.new(quartermasterCore.X, worldOrigin.Y, quartermasterCore.Z) + kioskOffset),
			Color3.fromRGB(76, 88, 110),
			Enum.Material.Metal
		)
		kiosk.CanQuery = false
		makeGlowPart(shell, "QuartermasterKioskGlow", Vector3.new(7.2, 0.08, 7.2), kiosk.CFrame * CFrame.new(0, 1.08, 0), Color3.fromRGB(156, 194, 244), 0.68).CanQuery = false
	end

	local socialCore = findAnchorPosition(lobbyModel, { "Social", "Squad" }, worldOrigin + Vector3.new(88, 0, 94))
	local socialDeck = makePart(
		shell,
		"Part",
		"SocialDeck",
		Vector3.new(52, 1.1, 28),
		CFrame.new(Vector3.new(socialCore.X, worldOrigin.Y + 0.55, socialCore.Z)),
		Color3.fromRGB(58, 74, 68),
		Enum.Material.DiamondPlate
	)
	socialDeck.CanQuery = false
	makeGlowPart(shell, "SocialDeckGlow", Vector3.new(44, 0.08, 18), socialDeck.CFrame * CFrame.new(0, 0.62, 0), Color3.fromRGB(134, 228, 188), 0.82).CanQuery = false
	local socialHeader = makePart(
		shell,
		"Part",
		"SocialHeader",
		Vector3.new(30, 1.1, 2.2),
		CFrame.new(Vector3.new(socialCore.X, worldOrigin.Y + 8.2, socialCore.Z - 8.4)),
		Color3.fromRGB(66, 88, 78),
		Enum.Material.Metal
	)
	socialHeader.CanQuery = false
	makeGlowPart(shell, "SocialHeaderGlow", Vector3.new(24, 0.12, 0.8), socialHeader.CFrame * CFrame.new(0, 0.28, 0.8), Color3.fromRGB(134, 228, 188), 0.62).CanQuery = false
	attachWorldText(socialHeader, "SQUAD CORNER", Vector3.new(0, 1.08, 0), Color3.fromRGB(188, 246, 220), Vector2.new(122, 18))
	for _, seatOffset in ipairs({
		Vector3.new(-14, 0.6, 8),
		Vector3.new(0, 0.6, 8),
		Vector3.new(14, 0.6, 8),
	}) do
		local seatBase = makePart(
			shell,
			"Part",
			"SocialSeatBase",
			Vector3.new(8, 1.1, 3),
			CFrame.new(Vector3.new(socialCore.X, worldOrigin.Y, socialCore.Z) + seatOffset),
			Color3.fromRGB(92, 108, 96),
			Enum.Material.WoodPlanks
		)
		seatBase.CanQuery = false
	end

	local archiveWall = makePart(
		shell,
		"Part",
		"ResultsArchiveWall",
		Vector3.new(86, 10, 3),
		CFrame.new(worldOrigin + Vector3.new(0, 5.2, 118)),
		Color3.fromRGB(66, 64, 54),
		Enum.Material.Metal
	)
	archiveWall.CanQuery = false
	makeGlowPart(shell, "ResultsArchiveWallGlow", Vector3.new(72, 0.12, 0.8), archiveWall.CFrame * CFrame.new(0, 2.8, 1), Color3.fromRGB(236, 224, 182), 0.58).CanQuery = false
	attachWorldText(archiveWall, "RESULTS ARCHIVE", Vector3.new(0, 3.6, 0), Color3.fromRGB(240, 228, 192), Vector2.new(138, 18))
	for _, panelOffset in ipairs({ -24, 0, 24 }) do
		local panel = makePart(
			shell,
			"Part",
			"ArchivePanel",
			Vector3.new(18, 5.8, 0.6),
			archiveWall.CFrame * CFrame.new(panelOffset, -0.2, 1.4),
			Color3.fromRGB(44, 48, 56),
			Enum.Material.SmoothPlastic
		)
		panel.CanQuery = false
		makeGlowPart(shell, "ArchivePanelGlow", Vector3.new(14, 0.06, 0.2), panel.CFrame * CFrame.new(0, 2.2, 0.22), Color3.fromRGB(236, 224, 182), 0.74).CanQuery = false
	end

	local activityZones = {
		{
			name = "TrainingLane",
			position = findAnchorPosition(lobbyModel, { "TrainingYard", "EntryPad" }, worldOrigin + Vector3.new(-108, 0, -26)),
			size = Vector3.new(54, 1.1, 28),
			color = Color3.fromRGB(90, 82, 58),
			accent = Color3.fromRGB(234, 214, 146),
			label = "DRILL LANE",
		},
		{
			name = "RangeLane",
			position = findAnchorPosition(lobbyModel, { "TargetRange", "FiringLine" }, worldOrigin + Vector3.new(108, 0, -26)),
			size = Vector3.new(54, 1.1, 28),
			color = Color3.fromRGB(64, 74, 92),
			accent = Color3.fromRGB(156, 194, 244),
			label = "TARGET RANGE",
		},
		{
			name = "ParkourLane",
			position = findAnchorPosition(lobbyModel, { "ParkourCourse", "StartPad" }, worldOrigin + Vector3.new(-108, 0, 54)),
			size = Vector3.new(54, 1.1, 28),
			color = Color3.fromRGB(72, 84, 62),
			accent = Color3.fromRGB(182, 228, 136),
			label = "PARKOUR LINE",
		},
		{
			name = "SalvageLane",
			position = findAnchorPosition(lobbyModel, { "SalvageRun", "StartPad" }, worldOrigin + Vector3.new(108, 0, 54)),
			size = Vector3.new(54, 1.1, 28),
			color = Color3.fromRGB(92, 80, 58),
			accent = Color3.fromRGB(240, 212, 154),
			label = "SALVAGE RUN",
		},
	}
	for _, zone in ipairs(activityZones) do
		local plate = makePart(
			shell,
			"Part",
			zone.name .. "Deck",
			zone.size,
			CFrame.new(Vector3.new(zone.position.X, worldOrigin.Y + 0.55, zone.position.Z)),
			zone.color,
			Enum.Material.Metal
		)
		plate.CanQuery = false
		makeGlowPart(shell, zone.name .. "DeckGlow", Vector3.new(zone.size.X - 8, 0.08, zone.size.Z - 8), plate.CFrame * CFrame.new(0, 0.62, 0), zone.accent, 0.84).CanQuery = false
		local frame = makePart(
			shell,
			"Part",
			zone.name .. "Header",
			Vector3.new(zone.size.X - 12, 1, 2.2),
			CFrame.new(Vector3.new(zone.position.X, worldOrigin.Y + 7.6, zone.position.Z - zone.size.Z * 0.5 + 3.2)),
			zone.color:Lerp(Color3.fromRGB(208, 208, 208), 0.1),
			Enum.Material.Metal
		)
		frame.CanQuery = false
		makeGlowPart(shell, zone.name .. "HeaderGlow", Vector3.new(zone.size.X - 18, 0.12, 0.8), frame.CFrame * CFrame.new(0, 0.24, 0.8), zone.accent, 0.68).CanQuery = false
		attachWorldText(frame, zone.label, Vector3.new(0, 1.02, 0), zone.accent, Vector2.new(118, 18))
		local threshold = makePart(
			shell,
			"Part",
			zone.name .. "Threshold",
			Vector3.new(16, 0.16, 2.2),
			CFrame.new(Vector3.new(zone.position.X, worldOrigin.Y + 0.18, zone.position.Z + zone.size.Z * 0.5 - 2)),
			Color3.fromRGB(74, 82, 94),
			Enum.Material.Metal
		)
		threshold.CanQuery = false
		makeGlowPart(shell, zone.name .. "ThresholdGlow", Vector3.new(12.8, 0.06, 0.8), threshold.CFrame * CFrame.new(0, 0.14, 0), zone.accent, 0.76).CanQuery = false
	end

	local deployCore = findAnchorPosition(lobbyModel, { "DeployPad", "LaunchPad", "Vote Model", "map vote", "VoteBoard", "DeployVoteDeck" }, worldOrigin + Vector3.new(0, 0, -98))
	local deployDeck = makePart(
		shell,
		"Part",
		"DeployDeck",
		Vector3.new(44, 1.4, 34),
		CFrame.new(Vector3.new(deployCore.X, worldOrigin.Y + 0.7, deployCore.Z + 8)),
		Color3.fromRGB(88, 56, 50),
		Enum.Material.DiamondPlate
	)
	deployDeck.CanQuery = false
	makeGlowPart(shell, "DeployDeckGlow", Vector3.new(38, 0.08, 26), deployDeck.CFrame * CFrame.new(0, 0.76, -2), Color3.fromRGB(244, 186, 164), 0.84).CanQuery = false

	for _, supportOffset in ipairs({
		Vector3.new(-18, 4.6, -8),
		Vector3.new(18, 4.6, -8),
		Vector3.new(-18, 4.6, 12),
		Vector3.new(18, 4.6, 12),
	}) do
		local pylon = makePart(
			shell,
			"Part",
			"DeployPylon",
			Vector3.new(2.4, 9.2, 2.4),
			CFrame.new(Vector3.new(deployCore.X, worldOrigin.Y, deployCore.Z) + supportOffset),
			Color3.fromRGB(86, 64, 60),
			Enum.Material.Metal
		)
		pylon.CanQuery = false
		makeGlowPart(shell, "DeployPylonGlow", Vector3.new(1.8, 0.12, 1.8), pylon.CFrame * CFrame.new(0, 4.7, 0), Color3.fromRGB(255, 210, 182), 0.34).CanQuery = false
	end

	local deployHeader = makePart(
		shell,
		"Part",
		"DeployHeaderBridge",
		Vector3.new(40, 1.2, 3),
		CFrame.new(Vector3.new(deployCore.X, worldOrigin.Y + 10.2, deployCore.Z - 8)),
		Color3.fromRGB(94, 60, 54),
		Enum.Material.Metal
	)
	deployHeader.CanQuery = false
	makeGlowPart(shell, "DeployHeaderBridgeGlow", Vector3.new(32, 0.12, 0.8), deployHeader.CFrame * CFrame.new(0, 0.28, 0.9), Color3.fromRGB(255, 208, 176), 0.62).CanQuery = false
	attachWorldText(deployHeader, "LAUNCH CORRIDOR", Vector3.new(0, 1.2, 0), Color3.fromRGB(255, 214, 190), Vector2.new(138, 18))

	for _, railInfo in ipairs({
		{ "DeployRailLeft", Vector3.new(1.2, 2.2, 30), Vector3.new(-21.2, 1.6, 8) },
		{ "DeployRailRight", Vector3.new(1.2, 2.2, 30), Vector3.new(21.2, 1.6, 8) },
		{ "DeployFrontRail", Vector3.new(34, 2.2, 1.2), Vector3.new(0, 1.6, 22.4) },
	}) do
		local rail = makePart(
			shell,
			"Part",
			railInfo[1],
			railInfo[2],
			CFrame.new(Vector3.new(deployCore.X, worldOrigin.Y, deployCore.Z) + railInfo[3]),
			Color3.fromRGB(110, 84, 78),
			Enum.Material.Metal
		)
		rail.CanQuery = false
	end

	for _, markerInfo in ipairs({
		Vector3.new(-10, 0.2, 8),
		Vector3.new(0, 0.2, 8),
		Vector3.new(10, 0.2, 8),
	}) do
		makeGlowPart(
			shell,
			"DeployLaneMarker",
			Vector3.new(4.8, 0.06, 8.4),
			CFrame.new(Vector3.new(deployCore.X, worldOrigin.Y, deployCore.Z) + markerInfo),
			Color3.fromRGB(255, 196, 166),
			0.84
		).CanQuery = false
	end

	local wingRooms = {
		{ "WestRoomNorth", Vector3.new(-106, 7, -34), Vector3.new(56, 14, 42) },
		{ "WestRoomSouth", Vector3.new(-106, 7, 52), Vector3.new(56, 14, 42) },
		{ "EastRoomNorth", Vector3.new(106, 7, -34), Vector3.new(56, 14, 42) },
		{ "EastRoomSouth", Vector3.new(106, 7, 52), Vector3.new(56, 14, 42) },
	}
	for _, room in ipairs(wingRooms) do
		local roomFloor = makePart(
			shell,
			"Part",
			room[1] .. "Floor",
			Vector3.new(room[3].X, 1, room[3].Z),
			CFrame.new(worldOrigin + Vector3.new(room[2].X, 0.5, room[2].Z)),
			Color3.fromRGB(40, 44, 52),
			Enum.Material.Concrete
		)
		roomFloor.CanQuery = false
		local rearWall = makePart(
			shell,
			"Part",
			room[1] .. "RearWall",
			Vector3.new(room[3].X, room[3].Y, 3),
			CFrame.new(worldOrigin + Vector3.new(room[2].X, room[2].Y, room[2].Z - room[3].Z * 0.5)),
			wallColor,
			Enum.Material.Metal
		)
		rearWall.CanQuery = false
		for _, sideOffset in ipairs({ -room[3].X * 0.5, room[3].X * 0.5 }) do
			local sideWall = makePart(
				shell,
				"Part",
				room[1] .. "SideWall",
				Vector3.new(3, room[3].Y, room[3].Z),
				CFrame.new(worldOrigin + Vector3.new(room[2].X + sideOffset, room[2].Y, room[2].Z)),
				wallColor,
				Enum.Material.Metal
			)
			sideWall.CanQuery = false
		end
		makeGlowPart(shell, room[1] .. "RoomTrim", Vector3.new(room[3].X - 6, 0.1, 1), CFrame.new(worldOrigin + Vector3.new(room[2].X, room[2].Y + room[3].Y * 0.35, room[2].Z - room[3].Z * 0.5 + 1.8)), shellTrimColor, 0.72).CanQuery = false
	end

	for _, support in ipairs({
		Vector3.new(-54, 8, -72),
		Vector3.new(54, 8, -72),
		Vector3.new(-54, 8, 72),
		Vector3.new(54, 8, 72),
		Vector3.new(-92, 8, 8),
		Vector3.new(92, 8, 8),
	}) do
		local beam = makePart(
			shell,
			"Part",
			"SupportColumn",
			Vector3.new(4, 16, 4),
			CFrame.new(worldOrigin + support),
			Color3.fromRGB(62, 70, 84),
			Enum.Material.Metal
		)
		beam.CanQuery = false
		makeGlowPart(shell, "SupportColumnCap", Vector3.new(1.6, 0.12, 1.6), beam.CFrame * CFrame.new(0, 8.1, 0), shellTrimColor, 0.46).CanQuery = false
	end

	for _, bridge in ipairs({
		{ "WestBridge", Vector3.new(42, 0.8, 10), Vector3.new(-48, 0.4, 8), Color3.fromRGB(54, 58, 50) },
		{ "EastBridge", Vector3.new(42, 0.8, 10), Vector3.new(48, 0.4, 8), Color3.fromRGB(50, 56, 62) },
		{ "SouthBridge", Vector3.new(18, 0.8, 24), Vector3.new(0, 0.4, 54), Color3.fromRGB(58, 56, 50) },
	}) do
		local plate = makePart(
			shell,
			"Part",
			bridge[1],
			bridge[2],
			CFrame.new(worldOrigin + bridge[3]),
			bridge[4],
			Enum.Material.Metal
		)
		plate.CanQuery = false
	end

	local propClusters = {
		{
			base = worldOrigin + Vector3.new(-108, 0.7, -32),
			color = Color3.fromRGB(118, 100, 74),
			accent = Color3.fromRGB(236, 214, 146),
		},
		{
			base = worldOrigin + Vector3.new(108, 0.7, -28),
			color = Color3.fromRGB(72, 86, 108),
			accent = Color3.fromRGB(156, 194, 244),
		},
		{
			base = worldOrigin + Vector3.new(-18, 0.7, 106),
			color = Color3.fromRGB(106, 94, 72),
			accent = Color3.fromRGB(236, 224, 182),
		},
		{
			base = worldOrigin + Vector3.new(98, 0.7, 18),
			color = Color3.fromRGB(98, 88, 62),
			accent = Color3.fromRGB(244, 214, 132),
		},
	}
	for index, cluster in ipairs(propClusters) do
		local crateA = makePart(
			shell,
			"Part",
			"CrateCluster" .. tostring(index) .. "A",
			Vector3.new(6, 2.2, 4),
			CFrame.new(cluster.base),
			cluster.color,
			Enum.Material.WoodPlanks
		)
		crateA.CanQuery = false
		local crateB = makePart(
			shell,
			"Part",
			"CrateCluster" .. tostring(index) .. "B",
			Vector3.new(3.4, 3.2, 3.4),
			CFrame.new(cluster.base + Vector3.new(4.4, 0.5, 1.8)),
			cluster.color:Lerp(Color3.fromRGB(210, 202, 178), 0.16),
			Enum.Material.WoodPlanks
		)
		crateB.CanQuery = false
		makeGlowPart(shell, "CrateCluster" .. tostring(index) .. "Glow", Vector3.new(7.4, 0.08, 5.6), crateA.CFrame * CFrame.new(0, 1.16, 0), cluster.accent, 0.82).CanQuery = false
	end

	for _, benchInfo in ipairs({
		{ "WestBench", Vector3.new(-34, 0.7, 78), Vector3.new(10, 1, 2.6), Color3.fromRGB(102, 90, 68) },
		{ "EastBench", Vector3.new(34, 0.7, 78), Vector3.new(10, 1, 2.6), Color3.fromRGB(82, 92, 108) },
	}) do
		local bench = makePart(
			shell,
			"Part",
			benchInfo[1],
			benchInfo[3],
			CFrame.new(worldOrigin + benchInfo[2]),
			benchInfo[4],
			Enum.Material.WoodPlanks
		)
		bench.CanQuery = false
	end

	for index, beaconInfo in ipairs({
		{ Vector3.new(-118, 4, 94), Color3.fromRGB(236, 224, 182) },
		{ Vector3.new(92, 4, 18), Color3.fromRGB(244, 214, 132) },
		{ Vector3.new(0, 4, -102), Color3.fromRGB(244, 186, 164) },
		{ Vector3.new(0, 4, 100), Color3.fromRGB(236, 224, 182) },
	}) do
		local beacon = makePart(
			shell,
			"Part",
			"GuideBeacon" .. tostring(index),
			Vector3.new(1.6, 8, 1.6),
			CFrame.new(worldOrigin + beaconInfo[1]),
			Color3.fromRGB(74, 82, 96),
			Enum.Material.Metal
		)
		beacon.CanQuery = false
		makeGlowPart(shell, "GuideBeaconGlow" .. tostring(index), Vector3.new(2.1, 0.12, 2.1), beacon.CFrame * CFrame.new(0, 4.1, 0), beaconInfo[2], 0.34).CanQuery = false
	end

	for _, pathInfo in ipairs({
		{ "DeployGuide", Vector3.new(2.2, 0.06, 54), Vector3.new(0, 0.18, -74), Color3.fromRGB(244, 186, 164) },
		{ "DeployGuideWide", Vector3.new(18, 0.06, 62), Vector3.new(0, 0.16, -70), Color3.fromRGB(164, 112, 102) },
		{ "ArchiveGuide", Vector3.new(2.2, 0.06, 42), Vector3.new(0, 0.18, 82), Color3.fromRGB(236, 224, 182) },
		{ "ContractGuide", Vector3.new(30, 0.06, 2.2), Vector3.new(-48, 0.18, -92), Color3.fromRGB(244, 186, 164) },
		{ "ChallengeGuide", Vector3.new(30, 0.06, 2.2), Vector3.new(46, 0.18, 92), Color3.fromRGB(236, 224, 182) },
		{ "TrainingGuide", Vector3.new(52, 0.06, 2.2), Vector3.new(-82, 0.18, 8), Color3.fromRGB(234, 214, 146) },
		{ "OpsGuide", Vector3.new(52, 0.06, 2.2), Vector3.new(82, 0.18, 8), Color3.fromRGB(156, 194, 244) },
		{ "SocialGuide", Vector3.new(28, 0.06, 2.2), Vector3.new(88, 0.18, 86), Color3.fromRGB(134, 228, 188) },
	}) do
		makeGlowPart(shell, pathInfo[1], pathInfo[2], CFrame.new(worldOrigin + pathInfo[3]), pathInfo[4], 0.9).CanQuery = false
	end

	for index, z in ipairs({ -88, -24, 40, 104 }) do
		makeGlowPart(shell, "CeilingBar" .. tostring(index), Vector3.new(220, 0.24, 2), CFrame.new(worldOrigin + Vector3.new(0, 24.2, z)), Color3.fromRGB(220, 232, 248), 0.28).CanQuery = false
	end
end

local function ensurePlayableLobbyShell(lobbyModel: Instance, worldOrigin: Vector3)
	local staleShell = lobbyModel:FindFirstChild("PlayableShell")
	if staleShell then
		warn("[LobbyWorld] Removing stale PlayableShell before lobby validation.")
		staleShell:Destroy()
	end

	if hasPlayableLobbyGeometry(lobbyModel) then
		return
	end

	buildPlayableLobbyShell(lobbyModel, worldOrigin)
end

local function ensureAuthoredLobbyDistricts(lobbyModel: Instance, worldOrigin: Vector3)
	local staleDistricts = lobbyModel:FindFirstChild("AuthoredDistricts")
	if staleDistricts then
		staleDistricts:Destroy()
	end

	if lobbyModel:FindFirstChild("PlayableShell") then
		return
	end

	local districts = Instance.new("Model")
	districts.Name = "AuthoredDistricts"
	districts.Parent = lobbyModel

	local centralConcourse = makePart(
		districts,
		"Part",
		"CentralConcourse",
		Vector3.new(112, 0.9, 84),
		CFrame.new(worldOrigin + Vector3.new(0, 0.45, 10)),
		Color3.fromRGB(42, 48, 58),
		Enum.Material.DiamondPlate
	)
	centralConcourse.CanQuery = false
	makeGlowPart(districts, "CentralConcourseGlow", Vector3.new(96, 0.08, 68), centralConcourse.CFrame * CFrame.new(0, 0.5, 0), Color3.fromRGB(118, 132, 156), 0.9).CanQuery = false

	local commandRing = makePart(
		districts,
		"Part",
		"CommandRing",
		Vector3.new(42, 0.3, 42),
		CFrame.new(worldOrigin + Vector3.new(0, 0.82, 10)),
		Color3.fromRGB(70, 82, 98),
		Enum.Material.Metal
	)
	commandRing.CanCollide = false
	commandRing.CanQuery = false
	commandRing.Transparency = 0.16
	makeGlowPart(districts, "CommandRingGlow", Vector3.new(48, 0.08, 48), commandRing.CFrame * CFrame.new(0, 0.08, 0), Color3.fromRGB(156, 184, 228), 0.76).CanQuery = false

	for _, stripInfo in ipairs({
		{ "NorthRouteStrip", Vector3.new(12, 0.12, 54), Vector3.new(0, 0.16, -42), Color3.fromRGB(156, 118, 104) },
		{ "SouthRouteStrip", Vector3.new(12, 0.12, 44), Vector3.new(0, 0.16, 70), Color3.fromRGB(186, 178, 132) },
		{ "EastRouteStrip", Vector3.new(54, 0.12, 12), Vector3.new(76, 0.16, 10), Color3.fromRGB(132, 178, 236) },
		{ "WestRouteStrip", Vector3.new(54, 0.12, 12), Vector3.new(-76, 0.16, 10), Color3.fromRGB(208, 194, 132) },
	}) do
		local strip = makePart(
			districts,
			"Part",
			stripInfo[1],
			stripInfo[2],
			CFrame.new(worldOrigin + stripInfo[3]),
			Color3.fromRGB(62, 66, 74),
			Enum.Material.Metal
		)
		strip.CanCollide = false
		strip.CanQuery = false
		makeGlowPart(districts, stripInfo[1] .. "Glow", Vector3.new(math.max(stripInfo[2].X - 6, 8), 0.06, math.max(stripInfo[2].Z - 6, 8)), strip.CFrame * CFrame.new(0, 0.1, 0), stripInfo[4], 0.82).CanQuery = false
	end

	local function makeDeck(name: string, position: Vector3, size: Vector3, color: Color3, accent: Color3, label: string, labelWidth: number, headerOffset: Vector3)
		local deck = makePart(
			districts,
			"Part",
			name,
			size,
			CFrame.new(Vector3.new(position.X, worldOrigin.Y + (size.Y * 0.5), position.Z)),
			color,
			Enum.Material.DiamondPlate
		)
		deck.CanQuery = false
		makeGlowPart(districts, name .. "Glow", Vector3.new(math.max(size.X - 8, 12), 0.08, math.max(size.Z - 8, 12)), deck.CFrame * CFrame.new(0, (size.Y * 0.5) + 0.08, 0), accent, 0.84).CanQuery = false
		local header = makePart(
			districts,
			"Part",
			name .. "Header",
			Vector3.new(math.max(size.X * 0.62, 20), 1.1, 2.2),
			CFrame.new(Vector3.new(position.X, worldOrigin.Y, position.Z) + headerOffset),
			color:Lerp(Color3.fromRGB(218, 218, 218), 0.12),
			Enum.Material.Metal
		)
		header.CanQuery = false
		makeGlowPart(districts, name .. "HeaderGlow", Vector3.new(math.max(size.X * 0.48, 16), 0.12, 0.8), header.CFrame * CFrame.new(0, 0.28, 0.8), accent, 0.62).CanQuery = false
		attachWorldText(header, label, Vector3.new(0, 1.08, 0), accent, Vector2.new(labelWidth, 18))
		local threshold = makePart(
			districts,
			"Part",
			name .. "Threshold",
			Vector3.new(math.max(size.X * 0.38, 14), 0.16, 2.4),
			CFrame.new(Vector3.new(position.X, worldOrigin.Y + 0.16, position.Z + (size.Z * 0.5) - 2)),
			Color3.fromRGB(74, 82, 94),
			Enum.Material.Metal
		)
		threshold.CanCollide = false
		threshold.CanQuery = false
		makeGlowPart(districts, name .. "ThresholdGlow", Vector3.new(math.max(size.X * 0.3, 10), 0.06, 0.8), threshold.CFrame * CFrame.new(0, 0.12, 0), accent, 0.78).CanQuery = false
		for _, side in ipairs({ -1, 1 }) do
			local rail = makePart(
				districts,
				"Part",
				name .. "Rail",
				Vector3.new(1.2, 2.2, math.max(size.Z - 8, 10)),
				CFrame.new(Vector3.new(position.X + (side * ((size.X * 0.5) - 1.4)), worldOrigin.Y + 1.1, position.Z)),
				color:Lerp(Color3.fromRGB(196, 196, 196), 0.08),
				Enum.Material.Metal
			)
			rail.CanQuery = false
		end
		return deck
	end

	local contractCore = findAnchorPosition(lobbyModel, { "QuestBoard", "ContractBoard", "Contracts", "Vote Model", "map vote" }, worldOrigin + Vector3.new(-46, 0, -94))
	local contractDeck = makeDeck("AuthoredContractDeck", contractCore + Vector3.new(0, 0, 6), Vector3.new(40, 1.1, 22), Color3.fromRGB(88, 64, 54), Color3.fromRGB(244, 186, 164), "CONTRACT BOARD", 124, Vector3.new(0, 8.8, -6.2))
	for _, panelOffset in ipairs({ -10, 10 }) do
		local boardPanel = makePart(
			districts,
			"Part",
			"ContractStatusPanel",
			Vector3.new(12, 5.4, 0.8),
			contractDeck.CFrame * CFrame.new(panelOffset, 3.3, -8.8),
			Color3.fromRGB(42, 48, 56),
			Enum.Material.SmoothPlastic
		)
		boardPanel.CanQuery = false
		makeGlowPart(districts, "ContractStatusPanelGlow", Vector3.new(8.8, 0.06, 0.2), boardPanel.CFrame * CFrame.new(0, 1.8, 0.18), Color3.fromRGB(244, 186, 164), 0.72).CanQuery = false
	end

	local challengeCore = findAnchorPosition(lobbyModel, { "DailyBoard", "WeeklyBoard", "ChallengeBoard", "QuestBoard", "LeaderboardMonument" }, worldOrigin + Vector3.new(34, 0, 96))
	local challengeDeck = makeDeck("AuthoredChallengeDeck", challengeCore + Vector3.new(0, 0, 4), Vector3.new(42, 1.1, 22), Color3.fromRGB(84, 78, 56), Color3.fromRGB(236, 224, 182), "DAILY OPS", 110, Vector3.new(0, 8.8, -6.2))
	for _, tileOffset in ipairs({ -12, 0, 12 }) do
		local tile = makePart(
			districts,
			"Part",
			"ChallengeTile",
			Vector3.new(9, 0.42, 9),
			challengeDeck.CFrame * CFrame.new(tileOffset, 0.76, -2),
			Color3.fromRGB(104, 98, 72),
			Enum.Material.Metal
		)
		tile.CanQuery = false
		makeGlowPart(districts, "ChallengeTileGlow", Vector3.new(6.8, 0.06, 6.8), tile.CFrame * CFrame.new(0, 0.08, 0), Color3.fromRGB(236, 224, 182), 0.76).CanQuery = false
	end

	local quartermasterCore = findAnchorPosition(lobbyModel, { "Shop", "Inventory", "SkillTree" }, worldOrigin + Vector3.new(88, 0, 8))
	local quartermasterDeck = makeDeck("AuthoredQuartermasterDeck", quartermasterCore, Vector3.new(54, 1.1, 30), Color3.fromRGB(62, 76, 96), Color3.fromRGB(156, 194, 244), "QUARTERMASTER", 132, Vector3.new(0, 8.8, -10))
	for _, kioskOffset in ipairs({
		Vector3.new(-16, 1.05, -6),
		Vector3.new(0, 1.05, -6),
		Vector3.new(16, 1.05, -6),
	}) do
		local kiosk = makePart(
			districts,
			"Part",
			"QuartermasterKiosk",
			Vector3.new(10, 2.1, 10),
			CFrame.new(quartermasterCore + kioskOffset),
			Color3.fromRGB(76, 88, 110),
			Enum.Material.Metal
		)
		kiosk.CanQuery = false
		makeGlowPart(districts, "QuartermasterKioskGlow", Vector3.new(7.2, 0.08, 7.2), kiosk.CFrame * CFrame.new(0, 1.08, 0), Color3.fromRGB(156, 194, 244), 0.68).CanQuery = false
		local screen = makeGlowPart(districts, "QuartermasterScreenGlow", Vector3.new(5.8, 1.8, 0.12), kiosk.CFrame * CFrame.new(0, 0.4, -5.06), Color3.fromRGB(172, 214, 255), 0.26)
		screen.CanQuery = false
	end
	local quartermasterCounter = makePart(
		districts,
		"Part",
		"QuartermasterCounter",
		Vector3.new(44, 1.2, 4),
		quartermasterDeck.CFrame * CFrame.new(0, 0.6, 8.6),
		Color3.fromRGB(78, 90, 110),
		Enum.Material.Metal
	)
	quartermasterCounter.CanQuery = false

	local socialCore = findAnchorPosition(lobbyModel, { "Social", "Squad" }, worldOrigin + Vector3.new(76, 0, 88))
	local socialDeck = makeDeck("AuthoredSocialDeck", socialCore, Vector3.new(50, 1.1, 26), Color3.fromRGB(58, 74, 68), Color3.fromRGB(134, 228, 188), "SQUAD CORNER", 122, Vector3.new(0, 8.2, -8))
	for _, seatOffset in ipairs({
		Vector3.new(-14, 0.55, 8),
		Vector3.new(0, 0.55, 8),
		Vector3.new(14, 0.55, 8),
	}) do
		local seatBase = makePart(
			districts,
			"Part",
			"SocialSeatBase",
			Vector3.new(8, 1.1, 3),
			CFrame.new(socialCore + seatOffset),
			Color3.fromRGB(92, 108, 96),
			Enum.Material.WoodPlanks
		)
		seatBase.CanQuery = false
	end
	local socialTable = makePart(
		districts,
		"Part",
		"SocialTable",
		Vector3.new(14, 1.2, 6),
		socialDeck.CFrame * CFrame.new(0, 0.62, -1),
		Color3.fromRGB(84, 102, 94),
		Enum.Material.WoodPlanks
	)
	socialTable.CanQuery = false
	makeGlowPart(districts, "SocialTableGlow", Vector3.new(10, 0.06, 3.2), socialTable.CFrame * CFrame.new(0, 0.12, 0), Color3.fromRGB(134, 228, 188), 0.84).CanQuery = false

	local archiveCore = findAnchorPosition(lobbyModel, { "LeaderboardMonument", "MasterBoard", "Leaderboard (Levels)", "BoardFace" }, worldOrigin + Vector3.new(0, 0, 102))
	local archiveWall = makePart(
		districts,
		"Part",
		"ResultsArchiveWall",
		Vector3.new(82, 10, 3),
		CFrame.new(Vector3.new(archiveCore.X, worldOrigin.Y + 5.2, archiveCore.Z + 18)),
		Color3.fromRGB(66, 64, 54),
		Enum.Material.Metal
	)
	archiveWall.CanQuery = false
	makeGlowPart(districts, "ResultsArchiveWallGlow", Vector3.new(68, 0.12, 0.8), archiveWall.CFrame * CFrame.new(0, 2.8, 1), Color3.fromRGB(236, 224, 182), 0.58).CanQuery = false
	attachWorldText(archiveWall, "RESULTS ARCHIVE", Vector3.new(0, 3.6, 0), Color3.fromRGB(240, 228, 192), Vector2.new(138, 18))
	for _, panelOffset in ipairs({ -22, 0, 22 }) do
		local archivePanel = makePart(
			districts,
			"Part",
			"AuthoredArchivePanel",
			Vector3.new(16, 5.6, 0.6),
			archiveWall.CFrame * CFrame.new(panelOffset, -0.2, 1.4),
			Color3.fromRGB(40, 46, 54),
			Enum.Material.SmoothPlastic
		)
		archivePanel.CanQuery = false
		makeGlowPart(districts, "AuthoredArchivePanelGlow", Vector3.new(12.4, 0.06, 0.2), archivePanel.CFrame * CFrame.new(0, 2.08, 0.18), Color3.fromRGB(236, 224, 182), 0.76).CanQuery = false
	end

	local deployCore = findAnchorPosition(lobbyModel, { "DeployPad", "LaunchPad", "Vote Model", "map vote", "VoteBoard", "DeployVoteDeck" }, worldOrigin + Vector3.new(0, 0, -88))
	makeGlowPart(districts, "AuthoredDeployGuide", Vector3.new(4, 0.06, 56), CFrame.new(Vector3.new(deployCore.X, worldOrigin.Y + 0.18, deployCore.Z + 20)), Color3.fromRGB(244, 186, 164), 0.9).CanQuery = false
	makeGlowPart(districts, "AuthoredDeployGuideWide", Vector3.new(18, 0.06, 62), CFrame.new(Vector3.new(deployCore.X, worldOrigin.Y + 0.16, deployCore.Z + 20)), Color3.fromRGB(164, 112, 102), 0.9).CanQuery = false
	makeGlowPart(districts, "AuthoredArchiveGuide", Vector3.new(28, 0.06, 2.2), CFrame.new(Vector3.new(archiveCore.X, worldOrigin.Y + 0.18, archiveCore.Z + 8)), Color3.fromRGB(236, 224, 182), 0.9).CanQuery = false
	makeGlowPart(districts, "AuthoredSocialGuide", Vector3.new(28, 0.06, 2.2), CFrame.new(Vector3.new(socialCore.X, worldOrigin.Y + 0.18, socialCore.Z - 10)), Color3.fromRGB(134, 228, 188), 0.9).CanQuery = false
	for _, pylonOffset in ipairs({
		Vector3.new(-10, 3.8, -4),
		Vector3.new(10, 3.8, -4),
		Vector3.new(-10, 3.8, 22),
		Vector3.new(10, 3.8, 22),
	}) do
		local pylon = makePart(
			districts,
			"Part",
			"AuthoredDeployPylon",
			Vector3.new(2, 7.6, 2),
			CFrame.new(Vector3.new(deployCore.X, worldOrigin.Y, deployCore.Z) + pylonOffset),
			Color3.fromRGB(102, 72, 66),
			Enum.Material.Metal
		)
		pylon.CanQuery = false
		makeGlowPart(districts, "AuthoredDeployPylonGlow", Vector3.new(1.6, 0.12, 1.6), pylon.CFrame * CFrame.new(0, 3.92, 0), Color3.fromRGB(255, 206, 174), 0.36).CanQuery = false
	end
	for _, beaconInfo in ipairs({
		{ "ContractBeacon", contractDeck.Position + Vector3.new(-18, 3.2, 0), Color3.fromRGB(244, 186, 164) },
		{ "ChallengeBeacon", challengeDeck.Position + Vector3.new(18, 3.2, 0), Color3.fromRGB(236, 224, 182) },
		{ "QuartermasterBeacon", quartermasterDeck.Position + Vector3.new(24, 3.2, 0), Color3.fromRGB(156, 194, 244) },
		{ "SocialBeacon", socialDeck.Position + Vector3.new(-22, 3.2, 0), Color3.fromRGB(134, 228, 188) },
	}) do
		local beacon = makePart(
			districts,
			"Part",
			beaconInfo[1],
			Vector3.new(1.6, 6.4, 1.6),
			CFrame.new(beaconInfo[2]),
			Color3.fromRGB(74, 82, 94),
			Enum.Material.Metal
		)
		beacon.CanQuery = false
		makeGlowPart(districts, beaconInfo[1] .. "Glow", Vector3.new(1.8, 0.12, 1.8), beacon.CFrame * CFrame.new(0, 3.28, 0), beaconInfo[3], 0.38).CanQuery = false
	end

	for index, z in ipairs({ -96, -34, 26, 88 }) do
		local bar = makeGlowPart(
			districts,
			"AuthoredCeilingBar" .. tostring(index),
			Vector3.new(176, 0.24, 2.4),
			CFrame.new(worldOrigin + Vector3.new(0, 18.4, z)),
			Color3.fromRGB(216, 228, 244),
			0.32
		)
		bar.CanQuery = false
	end

	for _, ribInfo in ipairs({
		{ "WestRibA", Vector3.new(-104, 8, -20), Vector3.new(3, 16, 34) },
		{ "WestRibB", Vector3.new(-104, 8, 54), Vector3.new(3, 16, 34) },
		{ "EastRibA", Vector3.new(104, 8, -20), Vector3.new(3, 16, 34) },
		{ "EastRibB", Vector3.new(104, 8, 54), Vector3.new(3, 16, 34) },
		{ "NorthRib", Vector3.new(0, 8, -112), Vector3.new(78, 16, 3) },
		{ "SouthRib", Vector3.new(0, 8, 122), Vector3.new(82, 16, 3) },
	}) do
		local rib = makePart(
			districts,
			"Part",
			ribInfo[1],
			ribInfo[3],
			CFrame.new(worldOrigin + ribInfo[2]),
			Color3.fromRGB(56, 62, 74),
			Enum.Material.Metal
		)
		rib.CanQuery = false
		makeGlowPart(districts, ribInfo[1] .. "Glow", Vector3.new(math.max(ribInfo[3].X - 6, 1), 0.12, math.max(ribInfo[3].Z - 1.4, 1)), rib.CFrame * CFrame.new(0, 6.2, 0), Color3.fromRGB(118, 132, 156), 0.72).CanQuery = false
	end

	for _, trimInfo in ipairs({
		{ "NorthWallTrim", Vector3.new(168, 0.2, 1.6), Vector3.new(0, 11.2, -118), Color3.fromRGB(244, 186, 164) },
		{ "SouthWallTrim", Vector3.new(168, 0.2, 1.6), Vector3.new(0, 11.2, 126), Color3.fromRGB(236, 224, 182) },
		{ "WestWallTrim", Vector3.new(1.6, 0.2, 126), Vector3.new(-118, 11.2, 14), Color3.fromRGB(208, 194, 132) },
		{ "EastWallTrim", Vector3.new(1.6, 0.2, 126), Vector3.new(118, 11.2, 14), Color3.fromRGB(156, 194, 244) },
	}) do
		local trim = makeGlowPart(
			districts,
			trimInfo[1],
			trimInfo[2],
			CFrame.new(worldOrigin + trimInfo[3]),
			trimInfo[4],
			0.54
		)
		trim.CanQuery = false
	end

	for _, shadowInfo in ipairs({
		{ "NorthCornerShadow", Vector3.new(34, 0.12, 34), Vector3.new(-96, 0.2, -102) },
		{ "NorthCornerShadow", Vector3.new(34, 0.12, 34), Vector3.new(96, 0.2, -102) },
		{ "SouthCornerShadow", Vector3.new(34, 0.12, 34), Vector3.new(-96, 0.2, 114) },
		{ "SouthCornerShadow", Vector3.new(34, 0.12, 34), Vector3.new(96, 0.2, 114) },
	}) do
		local shadow = makePart(
			districts,
			"Part",
			shadowInfo[1],
			shadowInfo[2],
			CFrame.new(worldOrigin + shadowInfo[3]),
			Color3.fromRGB(18, 20, 26),
			Enum.Material.SmoothPlastic
		)
		shadow.Transparency = 0.42
		shadow.CanCollide = false
		shadow.CanQuery = false
	end

	for _, wallInfo in ipairs({
		{ "ContractBackplate", contractDeck.Position + Vector3.new(0, 4.2, -11.2), Vector3.new(44, 8, 1.2), Color3.fromRGB(46, 38, 36), Color3.fromRGB(244, 186, 164) },
		{ "ChallengeBackplate", challengeDeck.Position + Vector3.new(0, 4.2, -11.2), Vector3.new(46, 8, 1.2), Color3.fromRGB(54, 50, 38), Color3.fromRGB(236, 224, 182) },
		{ "QuartermasterBackplate", quartermasterDeck.Position + Vector3.new(0, 4.8, -15.2), Vector3.new(58, 9.2, 1.4), Color3.fromRGB(40, 50, 64), Color3.fromRGB(156, 194, 244) },
		{ "SocialBackplate", socialDeck.Position + Vector3.new(0, 4.0, -13.4), Vector3.new(54, 8.2, 1.2), Color3.fromRGB(38, 50, 46), Color3.fromRGB(134, 228, 188) },
	}) do
		local backplate = makePart(
			districts,
			"Part",
			wallInfo[1],
			wallInfo[3],
			CFrame.new(wallInfo[2]),
			wallInfo[4],
			Enum.Material.Metal
		)
		backplate.CanQuery = false
		makeGlowPart(districts, wallInfo[1] .. "Glow", Vector3.new(math.max(wallInfo[3].X - 10, 10), 0.1, 0.4), backplate.CFrame * CFrame.new(0, 2.8, 0.7), wallInfo[5], 0.62).CanQuery = false
	end
end

function LobbyWorld.ensureActivityContent(): boolean
	local compositionRoot = getActiveLobbyCompositionRoot()
	if not compositionRoot then
		return false
	end
	ensureLobbyActivityContent(compositionRoot)
	local root = Workspace:FindFirstChild(Config.RootName)
	if root and root:IsA("Model") and compositionRoot == root then
		wireLobbyRoot(root, root)
	end
	return hasRequiredActivityParts(compositionRoot:FindFirstChild("TrainingYard", true), REQUIRED_ACTIVITY_PARTS.TrainingYard)
		and hasRequiredActivityParts(compositionRoot:FindFirstChild("ParkourCourse", true), REQUIRED_ACTIVITY_PARTS.ParkourCourse)
		and hasRequiredActivityParts(compositionRoot:FindFirstChild("TargetRange", true), REQUIRED_ACTIVITY_PARTS.TargetRange)
		and hasRequiredActivityParts(compositionRoot:FindFirstChild("SalvageRun", true), REQUIRED_ACTIVITY_PARTS.SalvageRun)
end

local function resolveMissionStaging(root: Instance, compositionRoot: Instance)
	local mission = root:FindFirstChild("MissionStaging")
	if not mission then
		local nestedMission = compositionRoot and compositionRoot:FindFirstChild("MissionStaging", true)
		if nestedMission and nestedMission:IsA("Model") then
			nestedMission.Parent = root
			mission = nestedMission
		end
	end

	if mission and mission:IsA("Model") then
		local missionSpawn = mission:FindFirstChild("MissionSpawn", true)
			or mission:FindFirstChild("DropMarker", true)
			or mission:FindFirstChild("Base", true)
		local cameraStart = mission:FindFirstChild("MissionCameraStart", true)
		local cameraEnd = mission:FindFirstChild("MissionCameraEnd", true)
			or mission:FindFirstChild("MissionCameraStop", true)
		if missionSpawn and missionSpawn:IsA("BasePart") and cameraStart and cameraStart:IsA("BasePart") and cameraEnd and cameraEnd:IsA("BasePart") then
			return mission, missionSpawn, cameraStart, cameraEnd
		end
		warn("[LobbyWorld] Authored MissionStaging is missing a valid mission spawn or mission cameras. Falling back to generated staging.")
		mission:Destroy()
	end

	return makeMissionStaging(root, Config.Origin + Config.MissionOffset)
end

local function findLabelAnchor(instance: Instance?): BasePart?
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		local model = instance :: Model
		if model.PrimaryPart then
			return model.PrimaryPart
		end
	end
	local sign = instance:FindFirstChild("Sign", true) or instance:FindFirstChild("SignBand", true) or instance:FindFirstChild("BackWallSign", true)
	if sign and sign:IsA("BasePart") then
		return sign
	end
	local header = instance:FindFirstChild("Header", true) or instance:FindFirstChild("Banner", true)
	if header and header:IsA("BasePart") then
		return header
	end
	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local attachAnchorLight
local function attachAreaIdentityLabel(root: Instance, areaName: string, title: string, subtitle: string, accent: Color3)
	local area = root:FindFirstChild(areaName, true)
	local anchor = findLabelAnchor(area)
	if anchor then
		attachLabel(anchor, title, subtitle, accent)
	end
end

attachAnchorLight = function(part: BasePart, color: Color3, brightness: number?, range: number?)
	clearNamedChildren(part, { "LandmarkLight" })

	local light = Instance.new("PointLight")
	light.Name = "LandmarkLight"
	light.Color = color
	light.Brightness = brightness or 1.4
	light.Range = range or 18
	light.Shadows = true
	light.Parent = part
end

local function attachAreaEntryMarker(root: Instance, areaName: string, entryName: string, text: string, accent: Color3, size: Vector2?)
	local area = root:FindFirstChild(areaName, true)
	local entry = area and area:FindFirstChild(entryName, true)
	if entry and entry:IsA("BasePart") then
		attachWorldText(entry, text, Vector3.new(0, 1.9, 0), accent, size or Vector2.new(92, 18))
		if text ~= "RETURN" then
			attachAnchorLight(entry, accent, 0.9, 10)
		end
	end
end

local function findAreaEntryPart(root: Instance, areaName: string, entryName: string): BasePart?
	local area = root:FindFirstChild(areaName, true)
	local entry = area and area:FindFirstChild(entryName, true)
	if entry and entry:IsA("BasePart") then
		return entry
	end
	return nil
end

local function findDonationAnchor(root: Instance): BasePart?
	local keywordHits = {
		"donat",
		"tipjar",
		"tip_jar",
		"tip-jar",
		"supportterminal",
		"support terminal",
		"supporterterminal",
		"supporter terminal",
		"mr.pluto board",
		"mr pluto board",
	}
	local function nameMatches(name: string): boolean
		local lowered = string.lower(name)
		for _, keyword in ipairs(keywordHits) do
			if string.find(lowered, keyword, 1, true) then
				return true
			end
		end
		return false
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") and nameMatches(descendant.Name) then
			return descendant
		end
		if descendant:IsA("Model") and nameMatches(descendant.Name) then
			local primary = descendant.PrimaryPart
			if primary then
				return primary
			end
			local firstPart = descendant:FindFirstChildWhichIsA("BasePart", true)
			if firstPart then
				return firstPart
			end
		end
	end

	local supportTerminal = root:FindFirstChild("SupportTerminal", true)
	if supportTerminal and supportTerminal:IsA("BasePart") then
		return supportTerminal
	end

	return nil
end

local function polishDonationAnchor(root: Instance, lobbyModel: Instance)
	local donationAnchor = findDonationAnchor(lobbyModel)
	if not donationAnchor then
		root:SetAttribute("DonationAnchorName", "")
		return
	end

	root:SetAttribute("DonationAnchorName", donationAnchor.Name)
	attachLabel(donationAnchor, "SUPPORT THE GAME", "Back bunker upgrades, polish passes, and new ops", Color3.fromRGB(246, 214, 132))
	attachWorldText(donationAnchor, "DONATE", Vector3.new(0, 2.05, 0), Color3.fromRGB(255, 228, 164), Vector2.new(92, 20))
	attachAnchorLight(donationAnchor, Color3.fromRGB(244, 206, 126), 1.2, 14)
	clearNamedChildren(donationAnchor, {
		"DonationTierPrompt1",
		"DonationTierPrompt2",
		"DonationTierPrompt3",
	})
	for index, tier in ipairs(DonationConfig.Tiers) do
		if type(tier) == "table" then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = ("DonationTierPrompt%d"):format(index)
			prompt.ActionText = "Donate"
			prompt.ObjectText = tostring(tier.Label or ("Tier " .. tostring(index)))
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Style = Enum.ProximityPromptStyle.Default
			prompt.KeyboardKeyCode = index == 1 and Enum.KeyCode.One or (index == 2 and Enum.KeyCode.Two or Enum.KeyCode.Three)
			prompt:SetAttribute("DonationTierId", tostring(tier.Id or index))
			prompt:SetAttribute("DonationProductId", tonumber(tier.ProductId) or 0)
			prompt:SetAttribute("DonationAmount", tonumber(tier.Amount) or 0)
			prompt.Parent = donationAnchor
		end
	end
end

local function wireLobbyRoot(root: Instance, lobbyModel: Instance)
	local anchorPart = lobbyModel:FindFirstChild("OuterGround", true)
	if anchorPart and anchorPart:IsA("BasePart") then
		CollectionService:AddTag(anchorPart, "LobbyAnchor")
	end

	local spawn = normalizeLobbySpawnPoints(lobbyModel)
	if spawn and spawn:IsA("BasePart") then
		CollectionService:AddTag(spawn, "LobbySpawn")
		attachWorldText(spawn, "SPAWN", Vector3.new(0, 2.4, 0), Color3.fromRGB(214, 230, 252), Vector2.new(88, 20))
		attachAnchorLight(spawn, Color3.fromRGB(184, 214, 255), 1.35, 15)
	end
	ensureLobbyArrivalAnchor(lobbyModel)

	local board = lobbyModel:FindFirstChild("VoteBoard", true)
		or lobbyModel:FindFirstChild("Vote Model", true)
		or lobbyModel:FindFirstChild("map vote", true)
		or lobbyModel:FindFirstChild("DeployVoteDeck", true)
	if board and not board:IsA("BasePart") then
		board = board:FindFirstChildWhichIsA("BasePart", true)
	end
	if board and board:IsA("BasePart") then
		clearNamedChildren(board, { "BoardGui", "BoardGuiMirror" })
		attachDeployVoteBoard(board)
		attachLabel(board, "VOTE BOARD", "Pick the next run before launch", Color3.fromRGB(240, 214, 166))
		attachAnchorLight(board, Color3.fromRGB(240, 214, 166), 1.45, 18)
	end

	for index = 1, 3 do
		local votePad = lobbyModel:FindFirstChild("VotePad" .. tostring(index), true)
		if votePad and votePad:IsA("BasePart") then
			votePad:SetAttribute("VoteOptionIndex", index)
			CollectionService:AddTag(votePad, "MapVotePad")
			ensurePrompt(votePad, "VotePrompt", "Vote", "Map Vote", 10)
		end
	end

	local launchPad = lobbyModel:FindFirstChild("LaunchPad", true) or lobbyModel:FindFirstChild("DeployPad", true)
	if launchPad and launchPad:IsA("BasePart") then
		launchPad:SetAttribute("DeployPad", true)
		launchPad:SetAttribute("RequiresDeployTokens", true)
		CollectionService:AddTag(launchPad, "DeployPad")
		local prompt = ensurePrompt(launchPad, "DeployPrompt", "Launch Run", "Mission Vote Ready", 12)
		root:SetAttribute("DeployPadName", launchPad.Name)
		root:SetAttribute("DeployPromptName", prompt.Name)
		attachWorldText(launchPad, "DEPLOY", Vector3.new(0, 2.25, 0), Color3.fromRGB(255, 214, 190), Vector2.new(96, 20))
		attachAnchorLight(launchPad, Color3.fromRGB(255, 214, 190), 1.85, 20)
	else
		root:SetAttribute("DeployPadName", "")
		root:SetAttribute("DeployPromptName", "")
	end

	local leaderboardBoard = lobbyModel:FindFirstChild("MasterBoard", true)
		or lobbyModel:FindFirstChild("LeaderboardBoard", true)
		or lobbyModel:FindFirstChild("BoardFace", true)
	if leaderboardBoard and leaderboardBoard:IsA("BasePart") then
		clearLegacyLeaderboardRigs(lobbyModel)
		for _, boardName in ipairs({ "BoardFace", "MasterBoard", "LeaderboardBoard" }) do
			local boardPart = lobbyModel:FindFirstChild(boardName, true)
			if boardPart and boardPart:IsA("BasePart") then
				clearNamedChildren(boardPart, { "BoardGui", "BoardGuiMirror", "Sign", "WorldText" })
				clearBoardPresentation(boardPart)
				local isActiveBoard = boardPart == leaderboardBoard
				boardPart.Transparency = isActiveBoard and 0 or 1
				boardPart.CastShadow = isActiveBoard
			end
		end
		attachLeaderboardMasterBoard(leaderboardBoard, {})
		attachLabel(leaderboardBoard, "LEADERBOARD", "Top operators and current standings", Color3.fromRGB(200, 214, 255))
		attachAnchorLight(leaderboardBoard, Color3.fromRGB(200, 214, 255), 1.1, 14)
	end

	for _, boardInfo in ipairs({
		{ name = "Leaderboard (Levels)", title = "LEVELS", accent = Color3.fromRGB(132, 178, 232) },
		{ name = "Leaderboard (Runs)", title = "RUNS", accent = Color3.fromRGB(122, 198, 156) },
		{ name = "leaderboard (Kills)", title = "KILLS", accent = Color3.fromRGB(214, 174, 104) },
		{ name = "Leaderboard (Kills)", title = "KILLS", accent = Color3.fromRGB(214, 174, 104) },
	}) do
		local boardPart = lobbyModel:FindFirstChild(boardInfo.name, true)
		if boardPart and boardPart:IsA("BasePart") then
			attachCategoryLeaderboardBoard(boardPart, boardInfo.title, boardInfo.accent)
			attachAnchorLight(boardPart, boardInfo.accent, 1, 12)
		end
	end

	attachAreaIdentityLabel(lobbyModel, "TrainingYard", "TRAINING YARD", "Warm up movement and range control", Color3.fromRGB(244, 212, 152))
	attachAreaIdentityLabel(lobbyModel, "ParkourCourse", "PARKOUR LINE", "Run the blocks and claim the roof", Color3.fromRGB(206, 220, 255))
	attachAreaIdentityLabel(lobbyModel, "DuelRing", "DUEL RING", "Stage 1v1s and settle bragging rights", Color3.fromRGB(244, 182, 182))
	attachAreaIdentityLabel(lobbyModel, "TargetRange", "TARGET RANGE", "Dial in aim and test recoil control", Color3.fromRGB(186, 238, 214))
	attachAreaIdentityLabel(lobbyModel, "SalvageRun", "SALVAGE RUN", "Recover bunker caches before the timer burns out", Color3.fromRGB(244, 214, 168))
	attachAreaIdentityLabel(lobbyModel, "SupporterLounge", "SUPPORTER LOUNGE", "Weekly crate lane and premium bunker access", Color3.fromRGB(246, 220, 138))
	attachAreaIdentityLabel(lobbyModel, "VipLounge", "VIP OPERATIONS", "Priority launch deck and fast lane", Color3.fromRGB(186, 220, 255))

	attachAreaEntryMarker(lobbyModel, "TrainingYard", "EntryPad", "TRAIN", Color3.fromRGB(244, 212, 152))
	attachAreaEntryMarker(lobbyModel, "ParkourCourse", "StartPad", "START", Color3.fromRGB(206, 220, 255))
	attachAreaEntryMarker(lobbyModel, "DuelRing", "RedCornerPad", "RED", Color3.fromRGB(255, 194, 194), Vector2.new(64, 18))
	attachAreaEntryMarker(lobbyModel, "DuelRing", "BlueCornerPad", "BLUE", Color3.fromRGB(198, 218, 255), Vector2.new(64, 18))
	attachAreaEntryMarker(lobbyModel, "TargetRange", "FiringLine", "RANGE", Color3.fromRGB(186, 238, 214))
	attachAreaEntryMarker(lobbyModel, "SalvageRun", "StartPad", "SALVAGE", Color3.fromRGB(244, 214, 168))
	attachAreaEntryMarker(lobbyModel, "SalvageRun", "FinishPad", "EXTRACT", Color3.fromRGB(224, 232, 242))
	attachAreaEntryMarker(lobbyModel, "TrainingYard", "ReturnPad", "RETURN", Color3.fromRGB(224, 232, 242))
	attachAreaEntryMarker(lobbyModel, "ParkourCourse", "ReturnPad", "RETURN", Color3.fromRGB(224, 232, 242))
	attachAreaEntryMarker(lobbyModel, "DuelRing", "ReturnPad", "RETURN", Color3.fromRGB(224, 232, 242))
	attachAreaEntryMarker(lobbyModel, "TargetRange", "ReturnPad", "RETURN", Color3.fromRGB(224, 232, 242))
	attachAreaEntryMarker(lobbyModel, "SalvageRun", "ReturnPad", "RETURN", Color3.fromRGB(224, 232, 242))
	attachAreaEntryMarker(lobbyModel, "SupporterLounge", "ReturnPad", "RETURN", Color3.fromRGB(224, 232, 242))
	attachAreaEntryMarker(lobbyModel, "VipLounge", "ReturnPad", "RETURN", Color3.fromRGB(224, 232, 242))

	polishDonationAnchor(root, lobbyModel)

end

makeOpenSkyLobby = function(root: Instance, worldPosition: Vector3)
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

	local function addPrivacyScreen(name: string, position: Vector3, size: Vector3, rotationY: number, color: Color3, accent: Color3)
		local base = makePart(
			plaza,
			"Part",
			name,
			size,
			CFrame.new(position + Vector3.new(0, size.Y * 0.5, 0)) * CFrame.Angles(0, math.rad(rotationY), 0),
			color,
			Enum.Material.Metal
		)
		base.CanQuery = false
		local cap = makeGlowPart(
			plaza,
			name .. "CapGlow",
			Vector3.new(math.max(4, size.X - 1.8), 0.08, math.max(0.8, size.Z - 1.8)),
			base.CFrame * CFrame.new(0, (size.Y * 0.5) + 0.1, 0),
			accent,
			0.9
		)
		cap.CanCollide = false
		cap.CanQuery = false
		local berm = makePart(
			plaza,
			"Part",
			name .. "Berm",
			Vector3.new(size.X + 8, 2.4, size.Z + 8),
			CFrame.new(position + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, math.rad(rotationY), 0),
			color:Lerp(Color3.fromRGB(38, 44, 54), 0.34),
			Enum.Material.Slate
		)
		berm.CanQuery = false
	end

	local function addLeaderboardMonument(position: Vector3)
		local monument = Instance.new("Model")
		monument.Name = "LeaderboardMonument"
		monument.Parent = plaza

		local plinth = makePart(monument, "Part", "Plinth", Vector3.new(58, 0.56, 15), CFrame.new(position + Vector3.new(0, 0.28, 0)), Color3.fromRGB(172, 164, 146), Enum.Material.SmoothPlastic)
		plinth.CanQuery = false
		local base = makePart(monument, "Part", "Base", Vector3.new(48, 0.32, 9.4), CFrame.new(position + Vector3.new(0, 0.72, 0.2)), Color3.fromRGB(132, 118, 94), Enum.Material.SmoothPlastic)
		base.CanQuery = false
		local baseGlow = makeGlowPart(monument, "BaseGlow", Vector3.new(48, 0.08, 9.4), base.CFrame * CFrame.new(0, 0.22, 0), Color3.fromRGB(214, 202, 176), 0.92)
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

		local threshold = makePart(monument, "Part", "Threshold", Vector3.new(14, 0.16, 2.6), CFrame.new(position + Vector3.new(0, 0.46, 8.8)), Color3.fromRGB(148, 136, 112), Enum.Material.SmoothPlastic)
		threshold.CanQuery = false
		local thresholdGlow = makeGlowPart(monument, "ThresholdGlow", Vector3.new(12.8, 0.05, 0.7), threshold.CFrame * CFrame.new(0, 0.12, -0.8), Color3.fromRGB(255, 236, 196), 0.86)
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

		local headerBand = makePart(monument, "Part", "HeaderBand", Vector3.new(34, 0.72, 1.6), CFrame.new(position + Vector3.new(0, 20.4, -0.2)), Color3.fromRGB(110, 92, 70), Enum.Material.SmoothPlastic)
		headerBand.CanQuery = false
		local headerGlow = makeGlowPart(monument, "HeaderGlow", Vector3.new(30, 0.08, 0.8), headerBand.CFrame * CFrame.new(0, 0.24, 0.32), Color3.fromRGB(236, 214, 156), 0.9)
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
			local fin = makePart(monument, "Part", "SideFin", Vector3.new(1.2, 11.6, 2.6), CFrame.new(position + offset) * CFrame.Angles(0, math.rad(offset.X > 0 and -5 or 5), 0), Color3.fromRGB(116, 102, 82), Enum.Material.SmoothPlastic)
			fin.CanQuery = false
		end

		for index, direction in ipairs({ -1, 1 }) do
			local wing = makePart(
				monument,
				"Part",
				"LaneWing" .. tostring(index),
				Vector3.new(2.6, 3.6, 12),
				CFrame.new(position + Vector3.new(14.6 * direction, 2.2, 24)) * CFrame.Angles(0, math.rad(direction > 0 and -8 or 8), 0),
				Color3.fromRGB(136, 126, 108),
				Enum.Material.SmoothPlastic
			)
			wing.CanQuery = false
			local wingGlow = makeGlowPart(
				monument,
				"LaneWingGlow" .. tostring(index),
				Vector3.new(0.08, 2.8, 8),
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

		local boardBase = makePart(monument, "Part", "BoardBase", Vector3.new(38.8, 0.42, 6.6), CFrame.new(position + Vector3.new(0, 0.96, 0.9)), Color3.fromRGB(154, 144, 126), Enum.Material.SmoothPlastic)
		boardBase.CanQuery = false
		local boardBaseGlow = makeGlowPart(monument, "BoardBaseGlow", Vector3.new(38.8, 0.06, 6.6), boardBase.CFrame * CFrame.new(0, 0.18, 0), Color3.fromRGB(230, 224, 210), 0.92)
		boardBaseGlow.CanCollide = false
		boardBaseGlow.CanQuery = false

		local leftPillar = makePart(monument, "Part", "LeftPillar", Vector3.new(0.9, 19.0, 0.9), CFrame.new(position + Vector3.new(-18.2, 10.0, 0.9)), Color3.fromRGB(118, 102, 82), Enum.Material.SmoothPlastic)
		leftPillar.CanQuery = false
		local rightPillar = makePart(monument, "Part", "RightPillar", Vector3.new(0.9, 19.0, 0.9), CFrame.new(position + Vector3.new(18.2, 10.0, 0.9)), Color3.fromRGB(118, 102, 82), Enum.Material.SmoothPlastic)
		rightPillar.CanQuery = false
		local crown = makePart(monument, "Part", "Crown", Vector3.new(39.6, 0.56, 0.9), CFrame.new(position + Vector3.new(0, 19.6, 0.9)), Color3.fromRGB(132, 118, 94), Enum.Material.SmoothPlastic)
		crown.CanQuery = false
		local crownGlow = makeGlowPart(monument, "CrownGlow", Vector3.new(39.6, 0.06, 0.7), crown.CFrame * CFrame.new(0, 0.18, 0), Color3.fromRGB(236, 214, 156), 0.9)
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
			detector.MaxActivationDistance = 48
			detector.Parent = button
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "Prompt"
			prompt.ActionText = name:gsub("Button", "")
			prompt.ObjectText = "Leaderboard"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
			prompt.MaxActivationDistance = 18
			prompt.Parent = button
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

		local worldControls = Instance.new("Model")
		worldControls.Name = "WorldControls"
		worldControls.Parent = monument

		local function addWorldControlPad(name: string, label: string, positionOffset: Vector3, size: Vector3, color: Color3)
			local pad = makePart(
				worldControls,
				"Part",
				name,
				size,
				CFrame.new(position + positionOffset),
				color,
				Enum.Material.Metal
			)
			pad.CanQuery = true
			local glow = makeGlowPart(
				worldControls,
				name .. "Glow",
				Vector3.new(size.X - 0.6, 0.08, size.Z - 0.6),
				pad.CFrame * CFrame.new(0, (size.Y * 0.5) + 0.08, 0),
				color,
				0.42
			)
			glow.CanCollide = false
			glow.CanQuery = false
			local detector = Instance.new("ClickDetector")
			detector.MaxActivationDistance = 48
			detector.Parent = pad
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "Prompt"
			prompt.ActionText = label
			prompt.ObjectText = "Leaderboard"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
			prompt.MaxActivationDistance = 18
			prompt.Parent = pad
			attachWorldText(pad, label, Vector3.new(0, 1.2, 0), Color3.fromRGB(244, 244, 244), Vector2.new(72, 16))
			return pad
		end

		local windowPadY = 0.64
		for index, info in ipairs({
			{ "AllTimeButton", "ALL TIME", Vector3.new(-20, windowPadY, 36), Color3.fromRGB(92, 116, 156) },
			{ "MonthlyButton", "MONTHLY", Vector3.new(-6, windowPadY, 36), Color3.fromRGB(92, 116, 156) },
			{ "WeeklyButton", "WEEKLY", Vector3.new(8, windowPadY, 36), Color3.fromRGB(92, 116, 156) },
			{ "DailyButton", "DAILY", Vector3.new(22, windowPadY, 36), Color3.fromRGB(92, 116, 156) },
		}) do
			addWorldControlPad(info[1], info[2], info[3], Vector3.new(11, 1.1, 5.5), info[4])
		end

		for _, info in ipairs({
			{ "LevelsButton", "LEVELS", Vector3.new(-16, windowPadY, 44), Color3.fromRGB(104, 146, 204) },
			{ "RunsButton", "RUNS", Vector3.new(0, windowPadY, 44), Color3.fromRGB(92, 176, 136) },
			{ "KillsButton", "KILLS", Vector3.new(16, windowPadY, 44), Color3.fromRGB(206, 162, 92) },
		}) do
			addWorldControlPad(info[1], info[2], info[3], Vector3.new(13, 1.1, 5.5), info[4])
		end

		addWorldControlPad("ScrollUpButton", "UP", Vector3.new(28, windowPadY, 28), Vector3.new(7, 1.1, 7), Color3.fromRGB(132, 144, 164))
		addWorldControlPad("ScrollDownButton", "DOWN", Vector3.new(28, windowPadY, 52), Vector3.new(7, 1.1, 7), Color3.fromRGB(132, 144, 164))

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

		if rolePalette.extra == "supply" then
			local stockCrate = makePart(
				npc,
				"Part",
				"StockCrate",
				Vector3.new(2.4, 1.8, 2),
				CFrame.new(startPosition + Vector3.new(-2.2, 0.98, -2.1)),
				Color3.fromRGB(112, 86, 58),
				Enum.Material.WoodPlanks
			)
			stockCrate.CanCollide = false
			stockCrate.CanQuery = false
			local stockTerminal = makePart(
				npc,
				"Part",
				"StockTerminal",
				Vector3.new(1.2, 1.6, 0.22),
				CFrame.new(startPosition + Vector3.new(2.26, 1.42, -1.88)),
				Color3.fromRGB(74, 96, 124),
				Enum.Material.Metal
			)
			stockTerminal.CanCollide = false
			stockTerminal.CanQuery = false
			makeGlowPart(npc, "StockTerminalGlow", Vector3.new(0.92, 1.28, 0.08), stockTerminal.CFrame * CFrame.new(0, 0, -0.1), accent, 0.38).CanQuery = false
		elseif rolePalette.extra == "command" then
			local commandConsole = makePart(
				npc,
				"Part",
				"CommandConsole",
				Vector3.new(2.6, 1.12, 1.8),
				CFrame.new(startPosition + Vector3.new(2.28, 0.64, -2.12)),
				Color3.fromRGB(44, 58, 78),
				Enum.Material.Metal
			)
			commandConsole.CanCollide = false
			commandConsole.CanQuery = false
			local commandScreen = makePart(
				npc,
				"Part",
				"CommandScreen",
				Vector3.new(1.76, 1.02, 0.08),
				commandConsole.CFrame * CFrame.new(0, 0.78, -0.88),
				Color3.fromRGB(112, 162, 228),
				Enum.Material.Neon
			)
			commandScreen.CanCollide = false
			commandScreen.CanQuery = false
		elseif rolePalette.extra == "marshal" then
			local launchBeacon = makePart(
				npc,
				"Part",
				"LaunchBeacon",
				Vector3.new(0.42, 3.2, 0.42),
				CFrame.new(startPosition + Vector3.new(-2.6, 1.72, -2.04)),
				Color3.fromRGB(84, 102, 132),
				Enum.Material.Metal
			)
			launchBeacon.CanCollide = false
			launchBeacon.CanQuery = false
			makeGlowPart(npc, "LaunchBeaconGlow", Vector3.new(0.68, 0.68, 0.68), launchBeacon.CFrame * CFrame.new(0, 1.42, 0), accent, 0.14).CanQuery = false
			local laneCase = makePart(
				npc,
				"Part",
				"LaneCase",
				Vector3.new(2.2, 1.2, 1.4),
				CFrame.new(startPosition + Vector3.new(2.14, 0.72, -2.18)),
				Color3.fromRGB(60, 72, 90),
				Enum.Material.Metal
			)
			laneCase.CanCollide = false
			laneCase.CanQuery = false
		elseif rolePalette.extra == "ops" then
			local opsBoard = makePart(
				npc,
				"Part",
				"OpsBoard",
				Vector3.new(2.2, 1.4, 0.18),
				CFrame.new(startPosition + Vector3.new(2.2, 1.46, -2.08)),
				Color3.fromRGB(86, 112, 64),
				Enum.Material.Metal
			)
			opsBoard.CanCollide = false
			opsBoard.CanQuery = false
			makeGlowPart(npc, "OpsBoardGlow", Vector3.new(1.78, 1.02, 0.08), opsBoard.CFrame * CFrame.new(0, 0, -0.1), accent, 0.3).CanQuery = false
			local stipendCrate = makePart(
				npc,
				"Part",
				"StipendCrate",
				Vector3.new(1.9, 1.1, 1.5),
				CFrame.new(startPosition + Vector3.new(-2.14, 0.66, -1.98)),
				Color3.fromRGB(98, 116, 72),
				Enum.Material.WoodPlanks
			)
			stipendCrate.CanCollide = false
			stipendCrate.CanQuery = false
		elseif string.find(lowerTitle, "trainer", 1, true) then
			local drillRack = makePart(
				npc,
				"Part",
				"DrillRack",
				Vector3.new(2.4, 1.4, 0.22),
				CFrame.new(startPosition + Vector3.new(2.18, 1.38, -2.1)),
				Color3.fromRGB(126, 98, 62),
				Enum.Material.Metal
			)
			drillRack.CanCollide = false
			drillRack.CanQuery = false
			local drillGlow = makeGlowPart(npc, "DrillRackGlow", Vector3.new(1.88, 0.14, 0.08), drillRack.CFrame * CFrame.new(0, 0.42, -0.1), accent, 0.22)
			drillGlow.CanCollide = false
			drillGlow.CanQuery = false
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

	local southSpine = makePart(
		plaza,
		"Part",
		"SouthCoreSpine",
		Vector3.new(10, 0.18, 92),
		CFrame.new(worldPosition + Vector3.new(0, 0.16, 44)),
		Color3.fromRGB(98, 102, 92),
		Enum.Material.DiamondPlate
	)
	southSpine.CanCollide = false
	southSpine.CanQuery = false
	local southSpineGuide = makeGlowPart(
		plaza,
		"SouthCoreSpineGuide",
		Vector3.new(2.6, 0.08, 88),
		CFrame.new(worldPosition + Vector3.new(0, 0.34, 44)),
		Color3.fromRGB(210, 220, 242),
		0.84
	)
	southSpineGuide.CanCollide = false
	southSpineGuide.CanQuery = false
	for index, zOffset in ipairs({ 22, -6 }) do
		local mast = makePart(
			plaza,
			"Part",
			"AxisPylon" .. tostring(index),
			Vector3.new(1.6, 5.2, 1.6),
			CFrame.new(worldPosition + Vector3.new(0, 2.7, zOffset)),
			Color3.fromRGB(70, 78, 92),
			Enum.Material.Metal
		)
		mast.CanQuery = false
		local mastGlow = makeGlowPart(
			plaza,
			"AxisPylonGlow" .. tostring(index),
			Vector3.new(0.16, 3.8, 1.0),
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
	if Config.Areas.Supporter then
		activityModels.Supporter = makeSupporterLounge(plaza, worldPosition + Config.Areas.Supporter.Offset, Config.Areas.Supporter, lobbyReturnAnchor)
	end
	if Config.Areas.Vip then
		activityModels.Vip = makeVipLounge(plaza, worldPosition + Config.Areas.Vip.Offset, Config.Areas.Vip, lobbyReturnAnchor)
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
		Supporter = {
			Offset = Vector3.new(54, 0, 74),
			Color = Config.Areas.Supporter.Color,
			Accent = Config.Areas.Supporter.Accent,
			Title = Config.Areas.Supporter.Title,
			TransitStyle = "supporter",
			RequiresSupporter = true,
		},
		Vip = {
			Offset = Vector3.new(-54, 0, 78),
			Color = Config.Areas.Vip.Color,
			Accent = Config.Areas.Vip.Accent,
			Title = Config.Areas.Vip.Title,
			TransitStyle = "vip",
			RequiresVip = true,
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
	end

	for areaName, travelInfo in pairs(Config.LobbyLayout.TransitPads) do
		local areaModel = activityModels[areaName == "TargetRange" and "TargetRange" or areaName]
		local entryPart = areaModel and areaModel:FindFirstChild(travelInfo.EntryPartName)
		local areaPalette = transitAreas[areaName]
		if areaPalette and entryPart and entryPart:IsA("BasePart") then
			addTravelPad(plaza, travelInfo.Name, worldPosition + areaPalette.Offset, areaPalette, entryPart, travelInfo.Action, travelInfo.Object, travelInfo.Subtitle, travelInfo.TextOffset)
		end
	end

	makeGuidePaths(plaza, worldPosition, transitAreas)
	local laneEntries = Config.LaneEntries
	local westDrillLayout = laneEntries.WestDrill
	local westDrillLane = makeGlowPart(
		plaza,
		"WestDrillLane",
		westDrillLayout.Lane.Size,
		CFrame.new(worldPosition + westDrillLayout.Lane.Offset),
		westDrillLayout.Lane.Color,
		westDrillLayout.Lane.Transparency
	)
	westDrillLane.CanCollide = false
	westDrillLane.CanQuery = false
	local westEntryPad = makePart(
		plaza,
		"Part",
		"WestDrillEntryPad",
		westDrillLayout.EntryPad.Size,
		CFrame.new(worldPosition + westDrillLayout.EntryPad.Offset),
		westDrillLayout.EntryPad.Color,
		Enum.Material.Concrete
	)
	westEntryPad.CanQuery = false
	local westEntryGlow = makeGlowPart(
		plaza,
		"WestDrillEntryGlow",
		westDrillLayout.EntryGlow.Size,
		CFrame.new(worldPosition + westDrillLayout.EntryGlow.Offset),
		westDrillLayout.EntryGlow.Color,
		westDrillLayout.EntryGlow.Transparency
	)
	westEntryGlow.CanCollide = false
	westEntryGlow.CanQuery = false
	local westEntryHeader = makePart(
		plaza,
		"Part",
		"WestDrillEntryHeader",
		westDrillLayout.EntryHeader.Size,
		CFrame.new(worldPosition + westDrillLayout.EntryHeader.Offset),
		westDrillLayout.EntryHeader.Color,
		Enum.Material.Metal
	)
	westEntryHeader.CanQuery = false
	attachWorldText(westEntryHeader, westDrillLayout.EntryHeader.Text, Vector3.new(0, 0.82, 0), westDrillLayout.EntryHeader.TextColor, westDrillLayout.EntryHeader.TextSize)
	for _, offset in ipairs(westDrillLayout.Scaffolds.Offsets) do
		local scaffold = makePart(
			plaza,
			"Part",
			"WestDrillScaffold",
			westDrillLayout.Scaffolds.Size,
			CFrame.new(worldPosition + offset),
			westDrillLayout.Scaffolds.Color,
			Enum.Material.Metal
		)
		scaffold.CanQuery = false
	end

	local eastCombatLayout = laneEntries.EastCombat
	local eastCombatSpine = makePart(
		plaza,
		"Part",
		"EastCombatSpine",
		eastCombatLayout.Spine.Size,
		CFrame.new(worldPosition + eastCombatLayout.Spine.Offset),
		eastCombatLayout.Spine.Color,
		Enum.Material.Metal
	)
	eastCombatSpine.CanQuery = false
	local eastCombatStripe = makeGlowPart(
		plaza,
		"EastCombatStripe",
		eastCombatLayout.Stripe.Size,
		CFrame.new(worldPosition + eastCombatLayout.Stripe.Offset),
		eastCombatLayout.Stripe.Color,
		eastCombatLayout.Stripe.Transparency
	)
	eastCombatStripe.CanCollide = false
	eastCombatStripe.CanQuery = false
	local eastEntryPad = makePart(
		plaza,
		"Part",
		"EastCombatEntryPad",
		eastCombatLayout.EntryPad.Size,
		CFrame.new(worldPosition + eastCombatLayout.EntryPad.Offset),
		eastCombatLayout.EntryPad.Color,
		Enum.Material.Concrete
	)
	eastEntryPad.CanQuery = false
	local eastEntryGlow = makeGlowPart(
		plaza,
		"EastCombatEntryGlow",
		eastCombatLayout.EntryGlow.Size,
		CFrame.new(worldPosition + eastCombatLayout.EntryGlow.Offset),
		eastCombatLayout.EntryGlow.Color,
		eastCombatLayout.EntryGlow.Transparency
	)
	eastEntryGlow.CanCollide = false
	eastEntryGlow.CanQuery = false
	local eastEntryHeader = makePart(
		plaza,
		"Part",
		"EastCombatEntryHeader",
		eastCombatLayout.EntryHeader.Size,
		CFrame.new(worldPosition + eastCombatLayout.EntryHeader.Offset),
		eastCombatLayout.EntryHeader.Color,
		Enum.Material.Metal
	)
	eastEntryHeader.CanQuery = false
	attachWorldText(eastEntryHeader, eastCombatLayout.EntryHeader.Text, Vector3.new(0, 0.82, 0), eastCombatLayout.EntryHeader.TextColor, eastCombatLayout.EntryHeader.TextSize)

	local salvageLayout = laneEntries.Salvage
	local salvageCorridor = makePart(
		plaza,
		"Part",
		"SalvageCorridor",
		salvageLayout.Corridor.Size,
		CFrame.new(worldPosition + salvageLayout.Corridor.Offset),
		salvageLayout.Corridor.Color,
		Enum.Material.DiamondPlate
	)
	salvageCorridor.CanCollide = false
	salvageCorridor.CanQuery = false
	local salvageGuide = makeGlowPart(
		plaza,
		"SalvageCorridorGuide",
		salvageLayout.Guide.Size,
		CFrame.new(worldPosition + salvageLayout.Guide.Offset),
		salvageLayout.Guide.Color,
		salvageLayout.Guide.Transparency
	)
	salvageGuide.CanCollide = false
	salvageGuide.CanQuery = false
	local salvageEntryPad = makePart(
		plaza,
		"Part",
		"SalvageEntryPad",
		salvageLayout.EntryPad.Size,
		CFrame.new(worldPosition + salvageLayout.EntryPad.Offset),
		salvageLayout.EntryPad.Color,
		Enum.Material.Concrete
	)
	salvageEntryPad.CanQuery = false
	local salvageEntryGlow = makeGlowPart(
		plaza,
		"SalvageEntryGlow",
		salvageLayout.EntryGlow.Size,
		CFrame.new(worldPosition + salvageLayout.EntryGlow.Offset),
		salvageLayout.EntryGlow.Color,
		salvageLayout.EntryGlow.Transparency
	)
	salvageEntryGlow.CanCollide = false
	salvageEntryGlow.CanQuery = false
	local salvageEntryHeader = makePart(
		plaza,
		"Part",
		"SalvageEntryHeader",
		salvageLayout.EntryHeader.Size,
		CFrame.new(worldPosition + salvageLayout.EntryHeader.Offset),
		salvageLayout.EntryHeader.Color,
		Enum.Material.Metal
	)
	salvageEntryHeader.CanQuery = false
	attachWorldText(salvageEntryHeader, salvageLayout.EntryHeader.Text, Vector3.new(0, 0.82, 0), salvageLayout.EntryHeader.TextColor, salvageLayout.EntryHeader.TextSize)

	local deployPad = makeDeployPad(plaza, worldPosition + Config.Areas.Deploy.Offset)
	local deployLaneLayout = Config.DeployLayout.Lane
	for index, offset in ipairs(deployLaneLayout.DistrictBays.Offsets) do
		local stagingBay = makePart(
			plaza,
			"Part",
			"DeployDistrictBay" .. tostring(index),
			deployLaneLayout.DistrictBays.Size,
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(84, 58, 58),
			Enum.Material.Metal
		)
		stagingBay.CanQuery = false
		local bayGlow = makeGlowPart(
			plaza,
			"DeployDistrictBayGlow" .. tostring(index),
			deployLaneLayout.DistrictBays.GlowSize,
			stagingBay.CFrame * CFrame.new(0, 2.18, 0),
			Color3.fromRGB(255, 190, 160),
			0.82
		)
		bayGlow.CanCollide = false
		bayGlow.CanQuery = false
	end
	local lobbyLayout = Config.LobbyLayout
	addCargoStack("WestCargoStack", worldPosition + lobbyLayout.CargoStacks.West, Color3.fromRGB(160, 186, 234))
	addCargoStack("EastCargoStack", worldPosition + lobbyLayout.CargoStacks.East, Color3.fromRGB(182, 232, 204))
	addCargoStack("SouthCargoStack", worldPosition + lobbyLayout.CargoStacks.South, Color3.fromRGB(236, 214, 156))
	addWatchTower("WestWatch", worldPosition + lobbyLayout.WatchTowers.West, Color3.fromRGB(194, 214, 255))
	addWatchTower("EastWatch", worldPosition + lobbyLayout.WatchTowers.East, Color3.fromRGB(214, 236, 196))
	for _, screen in ipairs(lobbyLayout.PrivacyScreens) do
		addPrivacyScreen(screen.name, worldPosition + screen.offset, screen.size, screen.rotationY, screen.color, screen.accent)
	end
	addLeaderboardMonument(worldPosition + lobbyLayout.LeaderboardOffset)
	makePathSegment(plaza, "ArchiveWalkLink", worldPosition + lobbyLayout.ArchiveLane.LinkStart, worldPosition + lobbyLayout.ArchiveLane.LinkEnd, Color3.fromRGB(220, 206, 168))
	makePathSegment(plaza, "ArchiveWalkLinkWide", worldPosition + lobbyLayout.ArchiveLane.LinkWideStart, worldPosition + lobbyLayout.ArchiveLane.LinkWideEnd, Color3.fromRGB(198, 184, 150))
	makePathSegment(plaza, "ArchiveWalkLeadIn", worldPosition + lobbyLayout.ArchiveLane.LeadInStart, worldPosition + lobbyLayout.ArchiveLane.LeadInEnd, Color3.fromRGB(232, 220, 182))
	local archiveEntryPad = makePart(
		plaza,
		"Part",
		"ArchiveEntryPad",
		Vector3.new(13.6, 0.18, 8.4),
		CFrame.new(worldPosition + lobbyLayout.ArchiveLane.EntryPadOffset),
		Color3.fromRGB(182, 170, 144),
		Enum.Material.Concrete
	)
	archiveEntryPad.CanQuery = false
	local archiveEntryGlow = makeGlowPart(
		plaza,
		"ArchiveEntryGlow",
		Vector3.new(6.2, 0.04, 1.4),
		CFrame.new(worldPosition + lobbyLayout.ArchiveLane.EntryGlowOffset),
		Color3.fromRGB(248, 234, 192),
		0.91
	)
	archiveEntryGlow.CanCollide = false
	archiveEntryGlow.CanQuery = false
	table.insert(animatedBoardEffects, {
		type = "leaderPulse",
		part = archiveEntryGlow,
		baseTransparency = 0.91,
		baseColor = Color3.fromRGB(232, 218, 176),
		pulseColor = Color3.fromRGB(255, 244, 210),
		phase = 1.9,
	})
	for index, entryOffset in ipairs({ lobbyLayout.ArchiveLane.EntryPylonLeftOffset, lobbyLayout.ArchiveLane.EntryPylonRightOffset }) do
		local pylon = makePart(
			plaza,
			"Part",
			"ArchiveEntryPylon" .. tostring(index),
			Vector3.new(1.4, 5.4, 1.4),
			CFrame.new(worldPosition + entryOffset),
			Color3.fromRGB(96, 82, 64),
			Enum.Material.Metal
		)
		pylon.CanQuery = false
		local capGlow = makeGlowPart(
			plaza,
			"ArchiveEntryPylonGlow" .. tostring(index),
			Vector3.new(1.4, 0.1, 1.4),
			pylon.CFrame * CFrame.new(0, 2.34, 0),
			Color3.fromRGB(255, 238, 204),
			0.68
		)
		capGlow.CanCollide = false
		capGlow.CanQuery = false
	end
	local archiveHeader = makePart(
		plaza,
		"Part",
		"ArchiveEntryHeader",
		Vector3.new(12.4, 0.56, 1.2),
		CFrame.new(worldPosition + lobbyLayout.ArchiveLane.EntryHeaderOffset),
		Color3.fromRGB(104, 84, 58),
		Enum.Material.WoodPlanks
	)
	archiveHeader.CanQuery = false
	attachWorldText(archiveHeader, "ARCHIVE", Vector3.new(0, 0.84, 0), Color3.fromRGB(240, 226, 186), Vector2.new(84, 16))
	makePathSegment(plaza, "DeploySpineLink", worldPosition + deployLaneLayout.SpineLinkStart, worldPosition + deployLaneLayout.SpineLinkEnd, Color3.fromRGB(255, 188, 154))
	makePathSegment(plaza, "DeploySpineLeadIn", worldPosition + deployLaneLayout.SpineLeadInStart, worldPosition + deployLaneLayout.SpineLeadInEnd, Color3.fromRGB(255, 206, 172))
	local deployEntryPad = makePart(
		plaza,
		"Part",
		"DeployEntryPad",
		deployLaneLayout.EntryPad.Size,
		CFrame.new(worldPosition + deployLaneLayout.EntryPad.Offset),
		Color3.fromRGB(136, 96, 96),
		Enum.Material.Concrete
	)
	deployEntryPad.CanQuery = false
	local deployEntryGlow = makeGlowPart(
		plaza,
		"DeployEntryGlow",
		deployLaneLayout.EntryGlow.Size,
		CFrame.new(worldPosition + deployLaneLayout.EntryGlow.Offset),
		Color3.fromRGB(255, 196, 164),
		0.9
	)
	deployEntryGlow.CanCollide = false
	deployEntryGlow.CanQuery = false
	table.insert(animatedBoardEffects, {
		type = "leaderPulse",
		part = deployEntryGlow,
		baseTransparency = 0.9,
		baseColor = Color3.fromRGB(236, 184, 154),
		pulseColor = Color3.fromRGB(255, 214, 188),
		phase = 0.9,
	})
	for index, offset in ipairs(deployLaneLayout.EntryPylons.Offsets) do
		local pylon = makePart(
			plaza,
			"Part",
			"DeployEntryPylon" .. tostring(index),
			deployLaneLayout.EntryPylons.Size,
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(92, 52, 52),
			Enum.Material.Metal
		)
		pylon.CanQuery = false
		local capGlow = makeGlowPart(
			plaza,
			"DeployEntryPylonGlow" .. tostring(index),
			Vector3.new(1.6, 0.1, 1.6),
			pylon.CFrame * CFrame.new(0, 2.72, 0),
			Color3.fromRGB(255, 188, 154),
			0.68
		)
		capGlow.CanCollide = false
		capGlow.CanQuery = false
	end
	local deployHeader = makePart(
		plaza,
		"Part",
		"DeployEntryHeader",
		deployLaneLayout.EntryHeader.Size,
		CFrame.new(worldPosition + deployLaneLayout.EntryHeader.Offset),
		Color3.fromRGB(110, 62, 62),
		Enum.Material.Metal
	)
	deployHeader.CanQuery = false
	attachWorldText(deployHeader, "LAUNCH LANE", Vector3.new(0, 0.88, 0), Color3.fromRGB(255, 212, 188), Vector2.new(106, 18))
	for _, offset in ipairs(lobbyLayout.ArchiveLane.Bollards.Offsets) do
		local bollard = makePart(
			plaza,
			"Part",
			"ArchiveWalkBollard",
			lobbyLayout.ArchiveLane.Bollards.Size,
			CFrame.new(worldPosition + offset),
			lobbyLayout.ArchiveLane.Bollards.Color,
			Enum.Material.Metal
		)
		bollard.CanQuery = false
		local cap = makeGlowPart(
			plaza,
			"ArchiveWalkBollardGlow",
			lobbyLayout.ArchiveLane.Bollards.GlowSize,
			bollard.CFrame * CFrame.new(0, 1.22, 0),
			lobbyLayout.ArchiveLane.Bollards.GlowColor,
			lobbyLayout.ArchiveLane.Bollards.GlowTransparency
		)
		cap.CanCollide = false
		cap.CanQuery = false
	end
	for _, info in ipairs(lobbyLayout.ArchiveLane.Props) do
		local prop = makePart(
			plaza,
			"Part",
			info.Name,
			info.Size,
			CFrame.new(worldPosition + info.Offset),
			info.Color,
			info.Material
		)
		prop.CanQuery = false
	end

	for _, info in ipairs(Config.LobbyNpcs) do
		addPatrolNpc(info.Id, info.DisplayName, worldPosition + info.RouteStart, worldPosition + info.RouteEnd, info.Accent, info.Phase, info.Panel)
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
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	Lighting.ClockTime = 5.7
	Lighting.Brightness = 2.28
	Lighting.Ambient = Color3.fromRGB(154, 162, 176)
	Lighting.OutdoorAmbient = Color3.fromRGB(102, 110, 126)
	Lighting.ColorShift_Top = Color3.fromRGB(66, 84, 114)
	Lighting.ColorShift_Bottom = Color3.fromRGB(32, 36, 46)
	Lighting.EnvironmentDiffuseScale = 0.62
	Lighting.EnvironmentSpecularScale = 0.34
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.28

	local atmosphere = Lighting:FindFirstChild("LobbyAtmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "LobbyAtmosphere"
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.14
	atmosphere.Offset = 0.01
	atmosphere.Color = Color3.fromRGB(194, 204, 222)
	atmosphere.Decay = Color3.fromRGB(122, 130, 148)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.34

	local bloom = Lighting:FindFirstChild("LobbyBloom")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "LobbyBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.06
	bloom.Size = 16
	bloom.Threshold = 2.08

	local colorCorrection = Lighting:FindFirstChild("LobbyColorCorrection")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "LobbyColorCorrection"
		colorCorrection.Parent = Lighting
	end
	colorCorrection.Brightness = 0.028
	colorCorrection.Contrast = 0.1
	colorCorrection.Saturation = -0.02
	colorCorrection.TintColor = Color3.fromRGB(244, 238, 228)
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
	local hubLayout = Config.CentralHubLayout

	local outerPad = makePart(
		hub,
		"Part",
		"OuterPad",
		hubLayout.OuterPad.Size,
		CFrame.new(worldPosition + hubLayout.OuterPad.Offset),
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
		hubLayout.Plinth.Size,
		CFrame.new(worldPosition + hubLayout.Plinth.Offset),
		Color3.fromRGB(78, 86, 98),
		Enum.Material.Metal
	)
	plinth.CanCollide = false
	plinth.CanQuery = false

	local innerPad = makePart(
		hub,
		"Part",
		"InnerPad",
		hubLayout.InnerPad.Size,
		CFrame.new(worldPosition + hubLayout.InnerPad.Offset),
		Color3.fromRGB(114, 126, 140),
		Enum.Material.SmoothPlastic
	)
	innerPad.CanQuery = false
	innerPad.CanCollide = false

	local ring = makeGlowPart(hub, "HubRing", hubLayout.HubRing.Size, CFrame.new(worldPosition + hubLayout.HubRing.Offset), Color3.fromRGB(148, 176, 214), 0.56)
	ring.CanCollide = false
	ring.CanQuery = false
	local ringOuter = makeGlowPart(hub, "HubRingOuter", hubLayout.HubRingOuter.Size, CFrame.new(worldPosition + hubLayout.HubRingOuter.Offset), Color3.fromRGB(118, 142, 176), 0.82)
	ringOuter.CanCollide = false
	ringOuter.CanQuery = false
	local commandCore = makePart(
		hub,
		"Part",
		"CommandCore",
		hubLayout.CommandCore.Size,
		CFrame.new(worldPosition + hubLayout.CommandCore.Offset),
		Color3.fromRGB(86, 96, 112),
		Enum.Material.SmoothPlastic
	)
	commandCore.CanQuery = false
	commandCore.CanCollide = false
	local commandGlow = makeGlowPart(hub, "CommandGlow", hubLayout.CommandGlow.Size, CFrame.new(worldPosition + hubLayout.CommandGlow.Offset), Color3.fromRGB(196, 214, 236), 0.56)
	commandGlow.CanCollide = false
	commandGlow.CanQuery = false
	local commandLamp = Instance.new("PointLight")
	commandLamp.Range = 18
	commandLamp.Brightness = 0.62
	commandLamp.Color = Color3.fromRGB(196, 214, 236)
	commandLamp.Parent = commandGlow
	for _, offset in ipairs(hubLayout.Bollards.Offsets) do
		local bollard = makePart(
			hub,
			"Part",
			"HubBollard",
			hubLayout.Bollards.Size,
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(92, 102, 116),
			Enum.Material.Metal
		)
		bollard.CanQuery = false
		makeGlowPart(hub, "HubBollardLamp", Vector3.new(1.2, 0.1, 1.2), bollard.CFrame * CFrame.new(0, 1.08, 0), Color3.fromRGB(170, 194, 226), 0.56)
	end

	for _, info in ipairs(hubLayout.Rails) do
		local rail = makePart(
			hub,
			"Part",
			info.Name,
			info.Size,
			CFrame.new(worldPosition + info.Offset),
			Color3.fromRGB(78, 88, 102),
			Enum.Material.Metal
		)
		rail.CanQuery = false
	end

	for _, offset in ipairs(hubLayout.Consoles.Offsets) do
		local console = makePart(
			hub,
			"Part",
			"HubConsole",
			hubLayout.Consoles.Size,
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(92, 104, 118),
			Enum.Material.DiamondPlate
		)
		console.CanQuery = false
		local consoleGlow = makeGlowPart(hub, "HubConsoleGlow", Vector3.new(1.6, 0.08, 0.8), console.CFrame * CFrame.new(0, 0.6, -0.24), Color3.fromRGB(164, 196, 236), 0.76)
		consoleGlow.CanCollide = false
		consoleGlow.CanQuery = false
	end

	for _, info in ipairs(hubLayout.Walkways) do
		local walkway = makePart(
			hub,
			"Part",
			info.Name,
			info.Size,
			CFrame.new(worldPosition + info.Offset),
			Color3.fromRGB(88, 98, 112),
			Enum.Material.DiamondPlate
		)
		walkway.CanCollide = false
		walkway.CanQuery = false
	end

	for _, offset in ipairs(hubLayout.HubPlates.Offsets) do
		local hubPlate = makePart(
			hub,
			"Part",
			"HubPlate",
			hubLayout.HubPlates.Size,
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(102, 114, 128),
			Enum.Material.Metal
		)
		hubPlate.CanCollide = false
		hubPlate.CanQuery = false
	end

	for _, info in ipairs(hubLayout.NavPlates) do
		local navPlate = makePart(
			hub,
			"Part",
			info.Name,
			info.Size,
			CFrame.new(worldPosition + info.Offset),
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
		hubLayout.CommandPlate.Size,
		CFrame.new(worldPosition + hubLayout.CommandPlate.Offset),
		Color3.fromRGB(154, 176, 206),
		Enum.Material.Neon
	)
	commandPlate.CanCollide = false
	commandPlate.CanQuery = false
	commandPlate.Transparency = 0.78

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
	local spawnLayout = Config.SpawnLayout

	local apron = makePart(
		spawnZone,
		"Part",
		"SpawnApron",
		spawnLayout.Apron.Size,
		CFrame.new(worldPosition + spawnLayout.Apron.Offset),
		spawnLayout.Apron.Color,
		Enum.Material.DiamondPlate
	)
	apron.CanCollide = false
	apron.CanQuery = false

	local frame = makePart(
		spawnZone,
		"Part",
		"SpawnFrame",
		spawnLayout.Frame.Size,
		CFrame.new(worldPosition + spawnLayout.Frame.Offset),
		spawnLayout.Frame.Color,
		Enum.Material.Metal
	)
	frame.Transparency = spawnLayout.Frame.Transparency
	frame.CanCollide = false
	frame.CanQuery = false

	local guide = makeGlowPart(
		spawnZone,
		"SpawnGuide",
		spawnLayout.Guide.Size,
		CFrame.new(worldPosition + spawnLayout.Guide.Offset),
		spawnLayout.Guide.Color,
		spawnLayout.Guide.Transparency
	)
	guide.CanCollide = false
	guide.CanQuery = false

	for _, info in ipairs(spawnLayout.Wings) do
		local wing = makePart(
			spawnZone,
			"Part",
			info.Name,
			info.Size,
			CFrame.new(worldPosition + info.Offset) * CFrame.Angles(0, info.RotationY, 0),
			info.Color,
			Enum.Material.Metal
		)
		wing.CanCollide = false
		wing.CanQuery = false
	end

	local gateLeft = makePart(spawnZone, "Part", "SpawnGateLeft", spawnLayout.Gate.Left.Size, CFrame.new(worldPosition + spawnLayout.Gate.Left.Offset), spawnLayout.Gate.Left.Color, Enum.Material.Metal)
	local gateRight = makePart(spawnZone, "Part", "SpawnGateRight", spawnLayout.Gate.Right.Size, CFrame.new(worldPosition + spawnLayout.Gate.Right.Offset), spawnLayout.Gate.Right.Color, Enum.Material.Metal)
	gateLeft.CanQuery = false
	gateRight.CanQuery = false
	local gateTop = makePart(spawnZone, "Part", "SpawnGateTop", spawnLayout.Gate.Top.Size, CFrame.new(worldPosition + spawnLayout.Gate.Top.Offset), spawnLayout.Gate.Top.Color, Enum.Material.Metal)
	gateTop.CanCollide = false
	gateTop.CanQuery = false
	local gateTopGlow = makeGlowPart(spawnZone, "SpawnGateTopGlow", spawnLayout.Gate.TopGlow.Size, CFrame.new(worldPosition + spawnLayout.Gate.TopGlow.Offset), spawnLayout.Gate.TopGlow.Color, spawnLayout.Gate.TopGlow.Transparency)
	gateTopGlow.CanCollide = false
	gateTopGlow.CanQuery = false

	for _, offset in ipairs(spawnLayout.AxisPylons.Offsets) do
		local axisPylon = makePart(
			spawnZone,
			"Part",
			"SpawnAxisPylon",
			spawnLayout.AxisPylons.PartSize,
			CFrame.new(worldPosition + offset),
			spawnLayout.AxisPylons.Color,
			Enum.Material.Metal
		)
		axisPylon.CanCollide = false
		axisPylon.CanQuery = false
		local axisPylonGlow = makeGlowPart(spawnZone, "SpawnAxisPylonGlow", spawnLayout.AxisPylons.GlowSize, axisPylon.CFrame * CFrame.new(0, 0.66, 0), spawnLayout.AxisPylons.GlowColor, spawnLayout.AxisPylons.GlowTransparency)
		axisPylonGlow.CanCollide = false
		axisPylonGlow.CanQuery = false
	end

	local leftBeacon = makePart(spawnZone, "Part", "SpawnBeaconLeft", spawnLayout.Beacons.PartSize, CFrame.new(worldPosition + spawnLayout.Beacons.LeftOffset), spawnLayout.Beacons.Color, Enum.Material.Metal)
	local rightBeacon = makePart(spawnZone, "Part", "SpawnBeaconRight", spawnLayout.Beacons.PartSize, CFrame.new(worldPosition + spawnLayout.Beacons.RightOffset), spawnLayout.Beacons.Color, Enum.Material.Metal)
	leftBeacon.CanQuery = false
	rightBeacon.CanQuery = false
	makeGlowPart(spawnZone, "SpawnBeaconLeftGlow", spawnLayout.Beacons.GlowSize, leftBeacon.CFrame * CFrame.new(0, 4.1, 0), spawnLayout.Beacons.GlowColor, spawnLayout.Beacons.GlowTransparency)
	makeGlowPart(spawnZone, "SpawnBeaconRightGlow", spawnLayout.Beacons.GlowSize, rightBeacon.CFrame * CFrame.new(0, 4.1, 0), spawnLayout.Beacons.GlowColor, spawnLayout.Beacons.GlowTransparency)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = spawnLayout.SpawnLocation.Size
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Enabled = true
	spawn.Duration = 0
	spawn.Material = Enum.Material.Concrete
	spawn.Color = spawnLayout.SpawnLocation.Color
	spawn.CFrame = CFrame.new(worldPosition + spawnLayout.SpawnLocation.Offset)
	spawn.Parent = spawnZone
	CollectionService:AddTag(spawn, "LobbySpawn")
	return spawn
end

makeDeployPad = function(root: Instance, worldPosition: Vector3)
	local deployModel = Instance.new("Model")
	deployModel.Name = "DeployVoteDeck"
	deployModel.Parent = root
	local voteDeckLayout = Config.DeployLayout.VoteDeck
	local deployAccent = voteDeckLayout.LaunchPad.GlowColor

	local floor = makePart(
		deployModel,
		"Part",
		"DeckFloor",
		voteDeckLayout.Floor.Size,
		CFrame.new(worldPosition + voteDeckLayout.Floor.Offset),
		voteDeckLayout.Floor.Color,
		Enum.Material.Concrete
	)
	floor.CanCollide = false
	floor.CanQuery = false

	local inset = makePart(
		deployModel,
		"Part",
		"DeckInset",
		voteDeckLayout.Frame.Size,
		CFrame.new(worldPosition + voteDeckLayout.Frame.Offset),
		voteDeckLayout.Frame.Color,
		Enum.Material.SmoothPlastic
	)
	inset.CanCollide = false
	inset.CanQuery = false

	local board = makePart(
		deployModel,
		"Part",
		"VoteBoard",
		voteDeckLayout.Board.Size,
		CFrame.new(worldPosition + voteDeckLayout.Board.Offset),
		voteDeckLayout.Board.Color,
		Enum.Material.SmoothPlastic
	)
	board.CanQuery = false
	attachDeployVoteBoard(board)

	local boardHeader = makePart(
		deployModel,
		"Part",
		"VoteBoardHeader",
		voteDeckLayout.FrameGlow.Size,
		CFrame.new(worldPosition + voteDeckLayout.FrameGlow.Offset),
		voteDeckLayout.FrameGlow.Color,
		Enum.Material.WoodPlanks
	)
	boardHeader.CanQuery = false
	boardHeader.Transparency = voteDeckLayout.FrameGlow.Transparency

	local boardBase = makePart(
		deployModel,
		"Part",
		"VoteBoardBase",
		Vector3.new(voteDeckLayout.Frame.Size.X + 1.2, voteDeckLayout.Frame.Size.Y + 1.2, 1.2),
		CFrame.new(worldPosition + voteDeckLayout.Frame.Offset + Vector3.new(0, 0, -0.7)),
		voteDeckLayout.Frame.Color,
		Enum.Material.WoodPlanks
	)
	boardBase.CanCollide = false
	boardBase.CanQuery = false

	for index, xOffset in ipairs({ -11.5, 11.5 }) do
		local support = makePart(
			deployModel,
			"Part",
			"VoteBoardSupport" .. tostring(index),
			Vector3.new(2.2, 18, 2.2),
			CFrame.new(worldPosition + Vector3.new(xOffset, 9, -24.2)),
			Color3.fromRGB(108, 82, 66),
			Enum.Material.WoodPlanks
		)
		support.CanQuery = false
	end

	local padPalette = voteDeckLayout.Pads.Palettes
	for index, padOffset in ipairs(voteDeckLayout.Pads.Offsets) do
		local votePad = makePart(
			deployModel,
			"Part",
			"VotePad" .. tostring(index),
			voteDeckLayout.Pads.Size,
			CFrame.new(worldPosition + padOffset),
			padPalette[index].base,
			Enum.Material.Metal
		)
		votePad.CanQuery = false
		votePad:SetAttribute("VoteOptionIndex", index)
		CollectionService:AddTag(votePad, "MapVotePad")

		local voteGlow = makeGlowPart(
			deployModel,
			"VotePadGlow" .. tostring(index),
			voteDeckLayout.Pads.GlowSize,
			votePad.CFrame * CFrame.new(0, 0.46, 0),
			padPalette[index].glow,
			0.58
		)
		voteGlow.CanCollide = false
		voteGlow.CanQuery = false

		local voteRing = makeGlowPart(
			deployModel,
			"VotePadRing" .. tostring(index),
			Vector3.new(voteDeckLayout.Pads.Size.X + 0.8, 0.08, voteDeckLayout.Pads.Size.Z + 0.8),
			votePad.CFrame * CFrame.new(0, 0.5, 0),
			padPalette[index].glow,
			0.86
		)
		voteRing.CanCollide = false
		voteRing.CanQuery = false

		local votePrompt = Instance.new("ProximityPrompt")
		votePrompt.Name = "VotePrompt"
		votePrompt.ActionText = "Vote"
		votePrompt.ObjectText = "Map Vote"
		votePrompt.KeyboardKeyCode = Enum.KeyCode.E
		votePrompt.HoldDuration = 0
		votePrompt.RequiresLineOfSight = false
		votePrompt.MaxActivationDistance = 10
		votePrompt.Parent = votePad

		attachWorldText(votePad, "PAD " .. tostring(index), voteDeckLayout.Pads.TextOffset, padPalette[index].glow, voteDeckLayout.Pads.TextSize)
	end

	local launchPad = makePart(
		deployModel,
		"Part",
		"DeployPad",
		voteDeckLayout.LaunchPad.Size,
		CFrame.new(worldPosition + voteDeckLayout.LaunchPad.Offset),
		voteDeckLayout.LaunchPad.Color,
		Enum.Material.Metal
	)
	launchPad.CanQuery = false
	launchPad:SetAttribute("DeployPad", true)
	launchPad:SetAttribute("RequiresDeployTokens", true)
	CollectionService:AddTag(launchPad, "DeployPad")

	local launchGlow = makeGlowPart(
		deployModel,
		"LaunchPadGlow",
		voteDeckLayout.LaunchPad.GlowSize,
		launchPad.CFrame * CFrame.new(0, 0.52, 0),
		deployAccent,
		voteDeckLayout.LaunchPad.GlowTransparency
	)
	launchGlow.CanCollide = false
	launchGlow.CanQuery = false
	attachWorldText(launchPad, voteDeckLayout.LaunchPad.Text, voteDeckLayout.LaunchPad.TextOffset, voteDeckLayout.LaunchPad.TextColor, voteDeckLayout.LaunchPad.TextSize)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DeployPrompt"
	prompt.ActionText = "Launch Run"
	prompt.ObjectText = "Mission Vote Ready"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = launchPad

	for _, offset in ipairs(voteDeckLayout.Pylons.Offsets) do
		local pylon = makePart(
			deployModel,
			"Part",
			"DeckPylon",
			voteDeckLayout.Pylons.Size,
			CFrame.new(worldPosition + offset),
			voteDeckLayout.Pylons.Color,
			Enum.Material.Metal
		)
		pylon.CanQuery = false
		local cap = makeGlowPart(
			deployModel,
			"DeckPylonCap",
			voteDeckLayout.Pylons.GlowSize,
			pylon.CFrame * CFrame.new(0, 2.12, 0),
			voteDeckLayout.Pylons.GlowColor,
			voteDeckLayout.Pylons.GlowTransparency
		)
		cap.CanCollide = false
		cap.CanQuery = false
	end

	return launchPad, prompt
end

makeGuidePaths = function(root: Instance, origin: Vector3, areaConfig)
	for areaName, palette in pairs(areaConfig) do
		local target = origin + palette.Offset
		makePathSegment(root, areaName .. "GuidePath", origin, target, palette.Accent)
	end
end

makeMissionStaging = function(root: Instance, worldPosition: Vector3)
	local mission = Instance.new("Model")
	mission.Name = "MissionStaging"
	mission.Parent = root

	local outerFloor = makePart(
		mission,
		"Part",
		"OuterFloor",
		Vector3.new(320, 2, 320),
		CFrame.new(worldPosition + Vector3.new(0, -1.2, 0)),
		Color3.fromRGB(18, 21, 26),
		Enum.Material.Concrete
	)
	outerFloor.CanQuery = false

	local base = makePart(
		mission,
		"Part",
		"Base",
		Vector3.new(252, 2, 252),
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
			Vector3.new(2, 0.08, 220),
			CFrame.new(worldPosition + Vector3.new(index * 46, 0.16, 0)),
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
			Vector3.new(220, 0.08, 2),
			CFrame.new(worldPosition + Vector3.new(0, 0.16, index * 46)),
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
		Vector3.new(204, 0.4, 204),
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
		Vector3.new(264, 1, 264),
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
		Vector3.new(-92, 1.4, -92),
		Vector3.new(92, 1.4, -92),
		Vector3.new(-92, 1.4, 92),
		Vector3.new(92, 1.4, 92),
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
		Vector3.new(8, 26, 212),
		CFrame.new(worldPosition + Vector3.new(-104, 12, 0)),
		Color3.fromRGB(28, 31, 36),
		Enum.Material.Metal
	)
	leftWall.CanQuery = false

	local rightWall = makePart(
		mission,
		"Part",
		"ZoneWallRight",
		Vector3.new(8, 26, 212),
		CFrame.new(worldPosition + Vector3.new(104, 12, 0)),
		Color3.fromRGB(28, 31, 36),
		Enum.Material.Metal
	)
	rightWall.CanQuery = false

	local backWall = makePart(
		mission,
		"Part",
		"ZoneWallBack",
		Vector3.new(212, 26, 8),
		CFrame.new(worldPosition + Vector3.new(0, 12, -104)),
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
	local dropZoneGui = marker:FindFirstChild("Sign")
	if dropZoneGui and dropZoneGui:IsA("BillboardGui") then
		dropZoneGui.Size = UDim2.fromOffset(112, 32)
		dropZoneGui.StudsOffset = Vector3.new(0, 1.0, 0)
		dropZoneGui.MaxDistance = 22
		local frame = dropZoneGui:FindFirstChildOfClass("Frame")
		if frame then
			frame.BackgroundTransparency = 0.72
			local stroke = frame:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = 0.58
				stroke.Thickness = 1
			end
		end
		local labels = frame and frame:GetChildren() or {}
		for _, child in ipairs(labels) do
			if child:IsA("TextLabel") then
				if child.Font == Enum.Font.GothamBlack then
					child.TextSize = 10
				else
					child.TextSize = 8
				end
			end
		end
	end

	return mission, spawn, cameraStart, cameraEnd
end

function LobbyWorld.start()
	clearLegacyLobbyDuplicates()
	applyLobbyLighting()

	local existingRoot = Workspace:FindFirstChild(Config.RootName)
	if existingRoot and not (existingRoot:IsA("Model") or existingRoot:IsA("Folder")) then
		existingRoot:Destroy()
		existingRoot = nil
	end
	if not existingRoot or not isConfiguredLobbyRootReady(existingRoot) then
		existingRoot = waitForConfiguredLobbyRoot(nil)
	end

	local root = existingRoot
	if root then
		root:SetAttribute("WorldType", "LobbyHub")
		root:SetAttribute("PlayerCountMax", Config.SquadSize.Max)
	end

	if not root then
		warn(("[LobbyWorld] %s was not available. Generated fallback lobbies are disabled."):format(Config.RootName))
		return
	end

	local compositionRoot = root
	local worldOrigin = getLobbyWorldOrigin(compositionRoot)
	ensurePlayableLobbyShell(compositionRoot, worldOrigin)
	ensureAuthoredLobbyDistricts(compositionRoot, worldOrigin)
	compositionRoot = root
	worldOrigin = getLobbyWorldOrigin(compositionRoot)
	if not compositionRoot:FindFirstChild("LobbySpawn", true) then
		makeSpawn(compositionRoot, worldOrigin + Config.SpawnOffset)
	end
	if not (compositionRoot:FindFirstChild("DeployPad", true) or compositionRoot:FindFirstChild("LaunchPad", true)) then
		makeDeployPad(compositionRoot, worldOrigin + Config.Areas.Deploy.Offset)
	end
	if not compositionRoot:FindFirstChild("CentralHub", true) then
		makeCentralHub(compositionRoot, worldOrigin + Config.SpawnOffset + Config.LobbyLayout.CentralHubOffset)
	end
	ensureLobbyActivityContent(compositionRoot)
	if root and root:IsA("Model") then
		wireLobbyRoot(root, compositionRoot)
	end
	validateLobbyFeatures(compositionRoot)
	publishLobbyExport(compositionRoot)
	local mission, missionSpawn, cameraStart, cameraEnd = resolveMissionStaging(root, compositionRoot)
	if not root:GetAttribute("DeployPadName") then
		root:SetAttribute("DeployPadName", "")
	end
	if not root:GetAttribute("DeployPromptName") then
		root:SetAttribute("DeployPromptName", "")
	end
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
