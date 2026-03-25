local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
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

		local base = makePart(monument, "Part", "Base", Vector3.new(46, 2.2, 14), CFrame.new(position + Vector3.new(0, 1.1, 0)), Color3.fromRGB(48, 54, 64), Enum.Material.Metal)
		base.CanQuery = false
		local rear = makePart(monument, "Part", "Rear", Vector3.new(44, 18, 3), CFrame.new(position + Vector3.new(0, 10, 4.6)), Color3.fromRGB(36, 40, 48), Enum.Material.Metal)
		rear.CanQuery = false
		local leftPillar = makePart(monument, "Part", "LeftPillar", Vector3.new(3.4, 18, 4), CFrame.new(position + Vector3.new(-20.4, 10, 2.8)), Color3.fromRGB(56, 62, 74), Enum.Material.Metal)
		leftPillar.CanQuery = false
		local rightPillar = makePart(monument, "Part", "RightPillar", Vector3.new(3.4, 18, 4), CFrame.new(position + Vector3.new(20.4, 10, 2.8)), Color3.fromRGB(56, 62, 74), Enum.Material.Metal)
		rightPillar.CanQuery = false
		local crown = makePart(monument, "Part", "Crown", Vector3.new(46, 2.2, 5), CFrame.new(position + Vector3.new(0, 19, 3.6)), Color3.fromRGB(72, 62, 42), Enum.Material.Metal)
		crown.CanQuery = false
		local crownGlow = makeGlowPart(monument, "CrownGlow", Vector3.new(45, 0.16, 4.6), crown.CFrame * CFrame.new(0, 0.8, 0), Color3.fromRGB(214, 182, 116), 0.54)
		table.insert(animatedBoardEffects, {
			type = "crownGlow",
			part = crownGlow,
			baseTransparency = 0.56,
			baseColor = Color3.fromRGB(214, 182, 116),
		})

		local boardFace = makePart(monument, "Part", "BoardFace", Vector3.new(40, 15, 0.6), CFrame.new(position + Vector3.new(0, 10, 3.04)), Color3.fromRGB(12, 14, 18), Enum.Material.SmoothPlastic)
		boardFace.CanQuery = false
		attachSurfaceBoard(boardFace, "OUTPOST LEADERBOARD", Color3.fromRGB(214, 182, 116), animatedBoardEffects)
		attachWorldText(crown, "LEADERBOARD", Vector3.new(0, 2.8, 0), Color3.fromRGB(255, 228, 182), Vector2.new(188, 36))
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
			Vector3.new(5, 20, 5),
			CFrame.new(position + Vector3.new(0, 10, 0)),
			Color3.fromRGB(50, 56, 66),
			Enum.Material.Metal
		)
		core.CanQuery = false

		local deck = makePart(
			tower,
			"Part",
			"Deck",
			Vector3.new(12, 1.2, 12),
			CFrame.new(position + Vector3.new(0, 20.6, 0)),
			Color3.fromRGB(72, 80, 92),
			Enum.Material.DiamondPlate
		)
		deck.CanQuery = false

		for _, offset in ipairs({
			Vector3.new(-4.2, 23.8, -4.2),
			Vector3.new(4.2, 23.8, -4.2),
			Vector3.new(-4.2, 23.8, 4.2),
			Vector3.new(4.2, 23.8, 4.2),
		}) do
			local rail = makePart(
				tower,
				"Part",
				"Rail",
				Vector3.new(1.1, 3.2, 1.1),
				CFrame.new(position + offset),
				Color3.fromRGB(92, 100, 112),
				Enum.Material.Metal
			)
			rail.CanQuery = false
		end

		addLamp(core, Vector3.new(0, 11.2, 0), accent, 0.7, 56, 0.34)
	end

	local function addPatrolNpc(name: string, title: string, startPosition: Vector3, endPosition: Vector3, accent: Color3, phase: number, dialogue)
		local npc = Instance.new("Model")
		npc.Name = name
		npc.Parent = plaza

		local basePad = makePart(
			npc,
			"Part",
			"Pad",
			Vector3.new(8, 0.6, 8),
			CFrame.new(startPosition + Vector3.new(0, 0.3, 0)),
			Color3.fromRGB(60, 68, 80),
			Enum.Material.Metal
		)
		basePad.CanCollide = false
		basePad.CanQuery = false

		local rootPart = Instance.new("Part")
		rootPart.Name = "HumanoidRootPart"
		rootPart.Size = Vector3.new(2, 2, 1)
		rootPart.Anchored = true
		rootPart.CanCollide = false
		rootPart.CanQuery = false
		rootPart.Transparency = 1
		rootPart.CFrame = CFrame.new(startPosition + Vector3.new(0, 3, 0), endPosition + Vector3.new(0, 3, 0))
		rootPart.Parent = npc

		local torso = makePart(
			npc,
			"Part",
			"Torso",
			Vector3.new(2.3, 2.8, 1.3),
			rootPart.CFrame * CFrame.new(0, 1.5, 0),
			Color3.fromRGB(36, 40, 46),
			Enum.Material.SmoothPlastic
		)
		torso.CanCollide = false
		torso.CanQuery = false

		local head = makePart(
			npc,
			"Part",
			"Head",
			Vector3.new(1.6, 1.6, 1.6),
			rootPart.CFrame * CFrame.new(0, 3.7, 0),
			Color3.fromRGB(202, 194, 186),
			Enum.Material.SmoothPlastic
		)
		head.Shape = Enum.PartType.Ball
		head.CanCollide = false
		head.CanQuery = false

		local leftArm = makePart(
			npc,
			"Part",
			"LeftArm",
			Vector3.new(0.7, 2.5, 0.7),
			rootPart.CFrame * CFrame.new(-1.55, 1.4, 0),
			Color3.fromRGB(58, 66, 78),
			Enum.Material.SmoothPlastic
		)
		leftArm.CanCollide = false
		leftArm.CanQuery = false

		local rightArm = makePart(
			npc,
			"Part",
			"RightArm",
			Vector3.new(0.7, 2.5, 0.7),
			rootPart.CFrame * CFrame.new(1.55, 1.4, 0),
			Color3.fromRGB(58, 66, 78),
			Enum.Material.SmoothPlastic
		)
		rightArm.CanCollide = false
		rightArm.CanQuery = false

		local leftLeg = makePart(
			npc,
			"Part",
			"LeftLeg",
			Vector3.new(0.8, 2.8, 0.8),
			rootPart.CFrame * CFrame.new(-0.6, -0.4, 0),
			Color3.fromRGB(28, 31, 36),
			Enum.Material.SmoothPlastic
		)
		leftLeg.CanCollide = false
		leftLeg.CanQuery = false

		local rightLeg = makePart(
			npc,
			"Part",
			"RightLeg",
			Vector3.new(0.8, 2.8, 0.8),
			rootPart.CFrame * CFrame.new(0.6, -0.4, 0),
			Color3.fromRGB(28, 31, 36),
			Enum.Material.SmoothPlastic
		)
		rightLeg.CanCollide = false
		rightLeg.CanQuery = false

		local visor = makeGlowPart(
			npc,
			"Visor",
			Vector3.new(1.2, 0.24, 0.2),
			head.CFrame * CFrame.new(0, 0.1, -0.74),
			accent,
			0.16
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
			Vector3.new(0.35, 0.35, 0.35),
			torso.CFrame * CFrame.new(0.9, 0.6, -0.3),
			accent,
			0.18
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

		npc.PrimaryPart = rootPart
		table.insert(ambientActors, {
			root = rootPart,
			head = head,
			torso = torso,
			leftArm = leftArm,
			rightArm = rightArm,
			leftLeg = leftLeg,
			rightLeg = rightLeg,
			visor = visor,
			routeStart = startPosition + Vector3.new(0, 3, 0),
			routeEnd = endPosition + Vector3.new(0, 3, 0),
			phase = phase,
			speed = 0.12,
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
		Vector3.new(332, 2, 332),
		CFrame.new(worldPosition + Vector3.new(0, -1.2, 0)),
		Color3.fromRGB(28, 30, 34),
		Enum.Material.Asphalt
	)
	outerGround.CanQuery = false

	local centralDeck = makePart(
		plaza,
		"Part",
		"CentralDeck",
		Vector3.new(188, 1.2, 188),
		CFrame.new(worldPosition + Vector3.new(0, -0.2, 0)),
		Color3.fromRGB(54, 60, 70),
		Enum.Material.Concrete
	)
	centralDeck.CanQuery = false

	local innerDeck = makePart(
		plaza,
		"Part",
		"InnerDeck",
		Vector3.new(132, 0.4, 132),
		CFrame.new(worldPosition + Vector3.new(0, 0.62, 0)),
		Color3.fromRGB(82, 90, 102),
		Enum.Material.DiamondPlate
	)
	innerDeck.CanCollide = false
	innerDeck.CanQuery = false

	local centerRing = makeGlowPart(
		plaza,
		"CenterRing",
		Vector3.new(86, 0.12, 86),
		CFrame.new(worldPosition + Vector3.new(0, 1.04, 0)),
		Color3.fromRGB(126, 152, 186),
		0.86
	)
	centerRing.CanCollide = false
	centerRing.CanQuery = false

	for _, info in ipairs({
		{ "North", Vector3.new(0, 1.1, -70), Vector3.new(104, 0.22, 2) },
		{ "South", Vector3.new(0, 1.1, 70), Vector3.new(104, 0.22, 2) },
		{ "West", Vector3.new(-70, 1.1, 0), Vector3.new(2, 0.22, 104) },
		{ "East", Vector3.new(70, 1.1, 0), Vector3.new(2, 0.22, 104) },
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

	for areaName, palette in pairs(Config.Areas) do
		local target = worldPosition + palette.Offset
		local zone = makeGlowPart(
			plaza,
			areaName .. "ZoneGlow",
			Vector3.new(26, 0.08, 26),
			CFrame.new(target + Vector3.new(0, 0.9, 0)),
			palette.Accent,
			0.88
		)
		zone.CanCollide = false
		zone.CanQuery = false

		local marker = makePart(
			plaza,
			"Part",
			areaName .. "Marker",
			Vector3.new(4, 16, 4),
			CFrame.new(target + Vector3.new(0, 8, 0)),
			Color3.fromRGB(50, 56, 66),
			Enum.Material.Metal
		)
		marker.CanQuery = false

		local cap = makeGlowPart(
			plaza,
			areaName .. "MarkerCap",
			Vector3.new(5.4, 0.22, 5.4),
			marker.CFrame * CFrame.new(0, 6.6, 0),
			palette.Accent,
			0.28
		)
		local pulse = Instance.new("PointLight")
		pulse.Range = 32
		pulse.Brightness = 0.65
		pulse.Color = palette.Accent
		pulse.Parent = cap

		attachWorldText(marker, palette.Title, Vector3.new(0, 9.8, 0), palette.Accent, Vector2.new(200, 42))
	end

	for _, offset in ipairs({
		Vector3.new(-108, 6, -108),
		Vector3.new(108, 6, -108),
		Vector3.new(-108, 6, 108),
		Vector3.new(108, 6, 108),
		Vector3.new(0, 6, -132),
		Vector3.new(0, 6, 132),
		Vector3.new(-132, 6, 0),
		Vector3.new(132, 6, 0),
	}) do
		local pylon = makePart(
			plaza,
			"Part",
			"PerimeterPylon",
			Vector3.new(3.2, 14, 3.2),
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(58, 64, 74),
			Enum.Material.Metal
		)
		pylon.CanQuery = false

		local pylonGlow = makeGlowPart(
			plaza,
			"PerimeterPylonGlow",
			Vector3.new(4.2, 0.18, 4.2),
			pylon.CFrame * CFrame.new(0, 6.4, 0),
			Color3.fromRGB(214, 226, 244),
			0.52
		)
		local pylonLight = Instance.new("PointLight")
		pylonLight.Range = 46
		pylonLight.Brightness = 0.45
		pylonLight.Color = Color3.fromRGB(214, 226, 244)
		pylonLight.Parent = pylonGlow
	end

	for _, info in ipairs({
		{ "NorthWestRise", Vector3.new(-92, 2, -92), Vector3.new(42, 4, 42) },
		{ "NorthEastRise", Vector3.new(92, 2, -92), Vector3.new(42, 4, 42) },
		{ "SouthWestRise", Vector3.new(-92, 2, 92), Vector3.new(42, 4, 42) },
		{ "SouthEastRise", Vector3.new(92, 2, 92), Vector3.new(42, 4, 42) },
	}) do
		local rise = makePart(
			plaza,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]),
			Color3.fromRGB(42, 46, 54),
			Enum.Material.Slate
		)
		rise.CanQuery = false
	end

	for _, info in ipairs({
		{ "NorthRoad", Vector3.new(0, -0.8, -176), Vector3.new(52, 0.2, 148) },
		{ "SouthRoad", Vector3.new(0, -0.8, 176), Vector3.new(52, 0.2, 148) },
		{ "WestRoad", Vector3.new(-176, -0.8, 0), Vector3.new(148, 0.2, 52) },
		{ "EastRoad", Vector3.new(176, -0.8, 0), Vector3.new(148, 0.2, 52) },
	}) do
		local road = makePart(
			plaza,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]),
			Color3.fromRGB(24, 26, 30),
			Enum.Material.Asphalt
		)
		road.CanQuery = false
	end

	for _, info in ipairs({
		{ "NorthLine", Vector3.new(0, -0.68, -174), Vector3.new(6, 0.06, 132) },
		{ "SouthLine", Vector3.new(0, -0.68, 174), Vector3.new(6, 0.06, 132) },
		{ "WestLine", Vector3.new(-174, -0.68, 0), Vector3.new(132, 0.06, 6) },
		{ "EastLine", Vector3.new(174, -0.68, 0), Vector3.new(132, 0.06, 6) },
	}) do
		local line = makeGlowPart(
			plaza,
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]),
			Color3.fromRGB(228, 196, 112),
			0.68
		)
		line.CanCollide = false
		line.CanQuery = false
	end

	for _, info in ipairs({
		{ "ShopCargo", Vector3.new(-42, 0, -124), Color3.fromRGB(245, 215, 156) },
		{ "SquadCargo", Vector3.new(-126, 0, 44), Color3.fromRGB(171, 205, 237) },
		{ "SocialCargo", Vector3.new(126, 0, -18), Color3.fromRGB(173, 227, 214) },
		{ "DeployCargo", Vector3.new(34, 0, 126), Color3.fromRGB(255, 214, 214) },
	}) do
		addCargoStack(info[1], worldPosition + info[2], info[3])
	end

	addLeaderboardMonument(worldPosition + Vector3.new(112, 0, 92))

	for _, info in ipairs({
		{ "NorthWestTower", Vector3.new(-146, 0, -146), Color3.fromRGB(198, 214, 236) },
		{ "NorthEastTower", Vector3.new(146, 0, -146), Color3.fromRGB(198, 214, 236) },
		{ "SouthWestTower", Vector3.new(-146, 0, 146), Color3.fromRGB(198, 214, 236) },
		{ "SouthEastTower", Vector3.new(146, 0, 146), Color3.fromRGB(198, 214, 236) },
	}) do
		addWatchTower(info[1], worldPosition + info[2], info[3])
	end

	for _, info in ipairs({
		{
			"NorthPatrol",
			"Quartermaster Rhea",
			Vector3.new(-18, 0, -114),
			Vector3.new(18, 0, -114),
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
			Vector3.new(-114, 0, -18),
			Vector3.new(-114, 0, 18),
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
			"EastPatrol",
			"Dispatcher Iona",
			Vector3.new(114, 0, -18),
			Vector3.new(114, 0, 18),
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
			Vector3.new(-18, 0, 114),
			Vector3.new(18, 0, 114),
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
			Vector3.new(-14, 0, 66),
			Vector3.new(14, 0, 66),
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

	for _, info in ipairs({
		{ "NorthFence", Vector3.new(0, 4, -154), Vector3.new(224, 8, 3) },
		{ "SouthFence", Vector3.new(0, 4, 154), Vector3.new(224, 8, 3) },
		{ "WestFence", Vector3.new(-154, 4, 0), Vector3.new(3, 8, 224) },
		{ "EastFence", Vector3.new(154, 4, 0), Vector3.new(3, 8, 224) },
	}) do
		local fence = makePart(
			plaza,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]),
			Color3.fromRGB(58, 64, 72),
			Enum.Material.Metal
		)
		fence.CanCollide = false
		fence.CanQuery = false
		fence.Transparency = 0.42
	end

	for _, info in ipairs({
		{ "NorthGate", Vector3.new(0, 7, -154), Vector3.new(44, 14, 4) },
		{ "SouthGate", Vector3.new(0, 7, 154), Vector3.new(44, 14, 4) },
		{ "WestGate", Vector3.new(-154, 7, 0), Vector3.new(4, 14, 44) },
		{ "EastGate", Vector3.new(154, 7, 0), Vector3.new(4, 14, 44) },
	}) do
		local gate = makePart(
			plaza,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]),
			Color3.fromRGB(88, 98, 112),
			Enum.Material.Metal
		)
		gate.CanCollide = false
		gate.CanQuery = false
		gate.Transparency = 0.18
	end

	for _, info in ipairs({
		{ "NorthSkylineA", Vector3.new(-84, 17, -206), Vector3.new(38, 34, 30) },
		{ "NorthSkylineB", Vector3.new(0, 22, -214), Vector3.new(52, 44, 34) },
		{ "NorthSkylineC", Vector3.new(92, 15, -204), Vector3.new(30, 30, 26) },
		{ "SouthSkylineA", Vector3.new(-106, 18, 210), Vector3.new(28, 36, 28) },
		{ "SouthSkylineB", Vector3.new(-14, 24, 220), Vector3.new(48, 48, 34) },
		{ "SouthSkylineC", Vector3.new(88, 16, 206), Vector3.new(34, 32, 26) },
		{ "WestSkylineA", Vector3.new(-214, 20, -70), Vector3.new(30, 40, 36) },
		{ "WestSkylineB", Vector3.new(-224, 14, 36), Vector3.new(38, 28, 30) },
		{ "EastSkylineA", Vector3.new(214, 18, -42), Vector3.new(34, 36, 32) },
		{ "EastSkylineB", Vector3.new(224, 23, 48), Vector3.new(42, 46, 34) },
	}) do
		local skyline = makePart(
			plaza,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]),
			Color3.fromRGB(20, 22, 26),
			Enum.Material.Concrete
		)
		skyline.CanQuery = false
	end

	for _, info in ipairs({
		{ "FogNorth", Vector3.new(0, 12, -196), Vector3.new(220, 44, 8), Color3.fromRGB(176, 188, 206) },
		{ "FogSouth", Vector3.new(0, 12, 196), Vector3.new(220, 44, 8), Color3.fromRGB(176, 188, 206) },
		{ "FogWest", Vector3.new(-196, 12, 0), Vector3.new(8, 44, 220), Color3.fromRGB(176, 188, 206) },
		{ "FogEast", Vector3.new(196, 12, 0), Vector3.new(8, 44, 220), Color3.fromRGB(176, 188, 206) },
	}) do
		local fog = makePart(
			plaza,
			"Part",
			info[1],
			info[3],
			CFrame.new(worldPosition + info[2]),
			info[4],
			Enum.Material.ForceField
		)
		fog.CanCollide = false
		fog.CanQuery = false
		fog.Transparency = 0.92
		table.insert(beaconLights, {
			part = fog,
			baseCFrame = fog.CFrame,
			fogOnly = true,
		})
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
				local anchor = actor.routeStart:Lerp(actor.routeEnd, travelAlpha)
				local lookTarget = actor.routeStart:Lerp(actor.routeEnd, math.clamp(travelAlpha + 0.02, 0, 1))
				local bob = math.sin(t * 2.2 + actor.phase * 4) * 0.08
				local stride = math.sin(t * 4.4 + actor.phase * 6)
				local rootCFrame = CFrame.lookAt(anchor + Vector3.new(0, bob, 0), lookTarget + Vector3.new(0, bob, 0))
				actor.root.CFrame = rootCFrame
				actor.torso.CFrame = rootCFrame * CFrame.new(0, 1.5, 0)
				actor.head.CFrame = rootCFrame * CFrame.new(0, 3.7, 0) * CFrame.Angles(0, math.rad(stride * 8), 0)
				actor.leftArm.CFrame = rootCFrame * CFrame.new(-1.55, 1.4, 0) * CFrame.Angles(math.rad(stride * 18), 0, math.rad(4))
				actor.rightArm.CFrame = rootCFrame * CFrame.new(1.55, 1.4, 0) * CFrame.Angles(math.rad(-stride * 18), 0, math.rad(-4))
				actor.leftLeg.CFrame = rootCFrame * CFrame.new(-0.6, -0.4, 0) * CFrame.Angles(math.rad(-stride * 14), 0, 0)
				actor.rightLeg.CFrame = rootCFrame * CFrame.new(0.6, -0.4, 0) * CFrame.Angles(math.rad(stride * 14), 0, 0)
				actor.visor.CFrame = actor.head.CFrame * CFrame.new(0, 0.1, -0.74)
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

local function decorateStation(model: Instance, name: string, worldPosition: Vector3, palette)
	makeStationAlcove(model, worldPosition, palette)
	makeArch(model, worldPosition, palette)
	makeStationBackdrop(model, worldPosition, palette)
	makeGlowPart(model, "FloorHalo", Vector3.new(12, 0.1, 12), CFrame.new(worldPosition + Vector3.new(0, 0.8, 0)), palette.Color, 0.86)
	addBayFillLight(model, "BayFillCenter", worldPosition + Vector3.new(0, 9.6, 1.8), palette.Accent:Lerp(Color3.fromRGB(255, 255, 255), 0.25), 0.62, 20)
	addBayFillLight(model, "BayFillRear", worldPosition + Vector3.new(0, 7.8, 8.8), palette.Accent:Lerp(Color3.fromRGB(255, 255, 255), 0.12), 0.38, 14)

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
		Vector3.new(36, 1.2, 36),
		CFrame.new(worldPosition + Vector3.new(0, 0.6, 0)),
		Color3.fromRGB(56, 62, 72),
		Enum.Material.Metal
	)
	outerPad.CanQuery = false

	local plinth = makePart(
		hub,
		"Part",
		"HubPlinth",
		Vector3.new(18, 2.4, 18),
		CFrame.new(worldPosition + Vector3.new(0, 1, 0)),
		Color3.fromRGB(74, 82, 94),
		Enum.Material.Slate
	)
	plinth.CanQuery = false

	local innerPad = makePart(
		hub,
		"Part",
		"InnerPad",
		Vector3.new(10, 1.1, 10),
		CFrame.new(worldPosition + Vector3.new(0, 2.1, 0)),
		Color3.fromRGB(110, 120, 134),
		Enum.Material.DiamondPlate
	)
	innerPad.CanQuery = false
	innerPad.CanCollide = false

	local ring = makeGlowPart(hub, "HubRing", Vector3.new(24, 0.16, 24), CFrame.new(worldPosition + Vector3.new(0, 2.1, 0)), Color3.fromRGB(148, 176, 214), 0.42)
	local beacon = makePart(
		hub,
		"Part",
		"HubBeacon",
		Vector3.new(3, 16, 3),
		CFrame.new(worldPosition + Vector3.new(0, 10, 0)),
		Color3.fromRGB(68, 76, 90),
		Enum.Material.Metal
	)
	beacon.CanQuery = false
	local beaconLight = makeGlowPart(hub, "HubBeaconLight", Vector3.new(3.2, 3.2, 3.2), CFrame.new(worldPosition + Vector3.new(0, 17, 0)), Color3.fromRGB(196, 214, 236), 0.36)
	local beaconLamp = Instance.new("PointLight")
	beaconLamp.Range = 28
	beaconLamp.Brightness = 0.92
	beaconLamp.Color = Color3.fromRGB(196, 214, 236)
	beaconLamp.Parent = beaconLight
	local lowerRing = makeGlowPart(hub, "HubLowerRing", Vector3.new(32, 0.12, 32), CFrame.new(worldPosition + Vector3.new(0, 0.82, 0)), Color3.fromRGB(118, 142, 176), 0.76)
	lowerRing.CanCollide = false
	lowerRing.CanQuery = false
	local hubSpine = makePart(
		hub,
		"Part",
		"HubSpine",
		Vector3.new(4, 20, 4),
		CFrame.new(worldPosition + Vector3.new(0, 12, 0)),
		Color3.fromRGB(88, 98, 112),
		Enum.Material.Metal
	)
	hubSpine.CanQuery = false
	local hubCrown = makePart(
		hub,
		"Part",
		"HubCrown",
		Vector3.new(18, 1.4, 18),
		CFrame.new(worldPosition + Vector3.new(0, 20.2, 0)),
		Color3.fromRGB(70, 78, 90),
		Enum.Material.DiamondPlate
	)
	hubCrown.CanQuery = false
	hubCrown.CanCollide = false
	local hubCrownGlow = makeGlowPart(hub, "HubCrownGlow", Vector3.new(20, 0.16, 20), CFrame.new(worldPosition + Vector3.new(0, 21.1, 0)), Color3.fromRGB(182, 206, 236), 0.62)
	hubCrownGlow.CanCollide = false
	hubCrownGlow.CanQuery = false
	for _, offset in ipairs({
		Vector3.new(-9, 1.4, -9),
		Vector3.new(9, 1.4, -9),
		Vector3.new(-9, 1.4, 9),
		Vector3.new(9, 1.4, 9),
	}) do
		local bollard = makePart(
			hub,
			"Part",
			"HubBollard",
			Vector3.new(1.2, 2.8, 1.2),
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(92, 102, 116),
			Enum.Material.Metal
		)
		bollard.CanQuery = false
		makeGlowPart(hub, "HubBollardLamp", Vector3.new(1.6, 0.14, 1.6), bollard.CFrame * CFrame.new(0, 1.5, 0), Color3.fromRGB(170, 194, 226), 0.46)
	end

	for _, info in ipairs({
		{"NorthRail", Vector3.new(0, 1.7, -14), Vector3.new(18, 2.6, 1.4)},
		{"SouthRail", Vector3.new(0, 1.7, 14), Vector3.new(18, 2.6, 1.4)},
		{"WestRail", Vector3.new(-14, 1.7, 0), Vector3.new(1.4, 2.6, 18)},
		{"EastRail", Vector3.new(14, 1.7, 0), Vector3.new(1.4, 2.6, 18)},
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
		Vector3.new(-6, 1.3, -6),
		Vector3.new(6, 1.3, -6),
		Vector3.new(-6, 1.3, 6),
		Vector3.new(6, 1.3, 6),
	}) do
		local console = makePart(
			hub,
			"Part",
			"HubConsole",
			Vector3.new(4, 2.2, 4),
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(92, 104, 118),
			Enum.Material.DiamondPlate
		)
		console.CanQuery = false
		local consoleGlow = makeGlowPart(hub, "HubConsoleGlow", Vector3.new(2.8, 0.12, 1.4), console.CFrame * CFrame.new(0, 1.16, -0.6), Color3.fromRGB(164, 196, 236), 0.68)
		consoleGlow.CanCollide = false
		consoleGlow.CanQuery = false
	end

	for _, info in ipairs({
		{"NorthWalkway", Vector3.new(0, 0.35, -26), Vector3.new(18, 0.5, 22)},
		{"SouthWalkway", Vector3.new(0, 0.35, 26), Vector3.new(18, 0.5, 22)},
		{"WestWalkway", Vector3.new(-26, 0.35, 0), Vector3.new(22, 0.5, 18)},
		{"EastWalkway", Vector3.new(26, 0.35, 0), Vector3.new(22, 0.5, 18)},
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
		Vector3.new(0, 0.42, -20),
		Vector3.new(0, 0.42, 20),
		Vector3.new(-20, 0.42, 0),
		Vector3.new(20, 0.42, 0),
	}) do
		local hubPlate = makePart(
			hub,
			"Part",
			"HubPlate",
			Vector3.new(10, 0.16, 6),
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(102, 114, 128),
			Enum.Material.Metal
		)
		hubPlate.CanCollide = false
		hubPlate.CanQuery = false
	end

	for _, offset in ipairs({
		Vector3.new(0, 3.1, -16),
		Vector3.new(0, 3.1, 16),
		Vector3.new(-16, 3.1, 0),
		Vector3.new(16, 3.1, 0),
	}) do
		local hubArm = makePart(
			hub,
			"Part",
			"HubArm",
			Vector3.new(6, 0.28, 14),
			CFrame.new(worldPosition + offset),
			Color3.fromRGB(112, 128, 148),
			Enum.Material.Metal
		)
		hubArm.CanCollide = false
		hubArm.CanQuery = false
		makeGlowPart(hub, "HubArmGlow", Vector3.new(6.4, 0.1, 14.4), hubArm.CFrame * CFrame.new(0, 0.2, 0), Color3.fromRGB(194, 216, 240), 0.82)
	end

	for _, info in ipairs({
		{"NorthNav", Vector3.new(0, 2.24, -12.2), Vector3.new(8, 0.16, 12)},
		{"SouthNav", Vector3.new(0, 2.24, 12.2), Vector3.new(8, 0.16, 12)},
		{"WestNav", Vector3.new(-12.2, 2.24, 0), Vector3.new(12, 0.16, 8)},
		{"EastNav", Vector3.new(12.2, 2.24, 0), Vector3.new(12, 0.16, 8)},
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

	attachWorldText(beacon, "MAIN LOBBY", Vector3.new(0, 6.6, 0), Color3.fromRGB(235, 239, 244), Vector2.new(170, 38))
end

local function makeStation(root: Instance, name: string, worldPosition: Vector3, palette)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = root
	model:SetAttribute("LobbyArea", name)

	local base = makePart(
		model,
		"Part",
		"Base",
		Vector3.new(26, 1, 26),
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
		Vector3.new(26, 0.18, 26),
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
		Vector3.new(18, 0.3, 14),
		CFrame.new(worldPosition + Vector3.new(0, 0.76, -7)),
		Color3.fromRGB(76, 84, 94),
		Enum.Material.DiamondPlate
	)
	apron.CanCollide = false
	apron.CanQuery = false

	local lane = makePart(
		model,
		"Part",
		"Lane",
		Vector3.new(10, 0.08, 16),
		CFrame.new(worldPosition + Vector3.new(0, 0.84, -16)),
		palette.Accent,
		Enum.Material.Neon
	)
	lane.CanCollide = false
	lane.CanQuery = false
	lane.Transparency = 0.94

	return model, base, prompt
end

local function makeSpawn(root: Instance, worldPosition: Vector3)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Enabled = true
	spawn.Duration = 0
	spawn.Material = Enum.Material.Concrete
	spawn.Color = Color3.fromRGB(92, 100, 110)
	spawn.CFrame = CFrame.new(worldPosition + Vector3.new(0, 1.5, 0))
	spawn.Parent = root
	CollectionService:AddTag(spawn, "LobbySpawn")
	return spawn
end

local function makeDeployPad(root: Instance, worldPosition: Vector3)
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

	local stagingPlate = makePart(root, "Part", "DeployStagingPlate", Vector3.new(16, 0.24, 8), CFrame.new(worldPosition + Vector3.new(0, 0.88, 9.2)), Color3.fromRGB(138, 96, 96), Enum.Material.Metal)
	stagingPlate.CanCollide = false
	stagingPlate.CanQuery = false
	stagingPlate.Transparency = 0.24
	makeGlowPart(root, "DeployStagingGuide", Vector3.new(10, 0.08, 2.4), CFrame.new(worldPosition + Vector3.new(0, 1.02, 5.8)), Color3.fromRGB(255, 194, 168), 0.64)

	attachWorldText(stagingPlate, "READY BAY", Vector3.new(0, 2.2, 0), Color3.fromRGB(255, 198, 184), Vector2.new(124, 28))

	local stagingStrutLeft = makePart(root, "Part", "DeployStagingStrutLeft", Vector3.new(2, 10, 2), CFrame.new(worldPosition + Vector3.new(-14, 5, 14)), Color3.fromRGB(86, 52, 52), Enum.Material.Metal)
	local stagingStrutRight = makePart(root, "Part", "DeployStagingStrutRight", Vector3.new(2, 10, 2), CFrame.new(worldPosition + Vector3.new(14, 5, 14)), Color3.fromRGB(86, 52, 52), Enum.Material.Metal)
	stagingStrutLeft.CanQuery = false
	stagingStrutRight.CanQuery = false

	local stagingCrown = makePart(root, "Part", "DeployStagingCrown", Vector3.new(18, 1.2, 4), CFrame.new(worldPosition + Vector3.new(0, 11.2, 12.2)), Color3.fromRGB(118, 70, 70), Enum.Material.Metal)
	stagingCrown.CanQuery = false
	makeGlowPart(root, "DeployStagingCrownGlow", Vector3.new(18.4, 0.12, 4.4), stagingCrown.CFrame * CFrame.new(0, 0.5, 0), Color3.fromRGB(255, 194, 168), 0.68)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DeployPrompt"
	prompt.ActionText = "Deploy"
	prompt.ObjectText = "Main Game"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = pad

	return pad, prompt
end

local function makeGuidePaths(root: Instance, origin: Vector3, areaConfig)
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
		Vector3.new(168, 2, 168),
		CFrame.new(worldPosition + Vector3.new(0, -1.2, 0)),
		Color3.fromRGB(18, 21, 26),
		Enum.Material.Concrete
	)
	outerFloor.CanQuery = false

	local base = makePart(
		mission,
		"Part",
		"Base",
		Vector3.new(120, 2, 120),
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
			Vector3.new(2, 0.08, 108),
			CFrame.new(worldPosition + Vector3.new(index * 24, 0.16, 0)),
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
			Vector3.new(108, 0.08, 2),
			CFrame.new(worldPosition + Vector3.new(0, 0.16, index * 24)),
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
		Vector3.new(92, 0.4, 92),
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
		Vector3.new(126, 1, 126),
		CFrame.new(worldPosition + Vector3.new(0, 0.9, 0)),
		Color3.fromRGB(79, 47, 37),
		Enum.Material.Metal
	)
	perimeter.CanCollide = false
	perimeter.CanQuery = false
	perimeter.Transparency = 0.88

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MissionSpawn"
	spawn.Size = Vector3.new(12, 1, 12)
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
		Vector3.new(26, 1, 26),
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
		Vector3.new(30, 0.08, 30),
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
		Vector3.new(50, 2, 4),
		CFrame.new(worldPosition + Vector3.new(0, 16, 34)),
		Color3.fromRGB(52, 58, 66),
		Enum.Material.Metal
	)
	rearGantry.CanQuery = false
	makeGlowPart(mission, "RearGantryLight", Vector3.new(40, 0.22, 1), CFrame.new(worldPosition + Vector3.new(0, 14.8, 35.8)), Color3.fromRGB(236, 160, 112), 0.8)

	for _, offset in ipairs({
		Vector3.new(-34, 1.4, -34),
		Vector3.new(34, 1.4, -34),
		Vector3.new(-34, 1.4, 34),
		Vector3.new(34, 1.4, 34),
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
		Vector3.new(6, 22, 90),
		CFrame.new(worldPosition + Vector3.new(-48, 10, 0)),
		Color3.fromRGB(28, 31, 36),
		Enum.Material.Metal
	)
	leftWall.CanQuery = false

	local rightWall = makePart(
		mission,
		"Part",
		"ZoneWallRight",
		Vector3.new(6, 22, 90),
		CFrame.new(worldPosition + Vector3.new(48, 10, 0)),
		Color3.fromRGB(28, 31, 36),
		Enum.Material.Metal
	)
	rightWall.CanQuery = false

	local backWall = makePart(
		mission,
		"Part",
		"ZoneWallBack",
		Vector3.new(96, 22, 6),
		CFrame.new(worldPosition + Vector3.new(0, 10, -48)),
		Color3.fromRGB(28, 31, 36),
		Enum.Material.Metal
	)
	backWall.CanQuery = false

	local gantry = makePart(
		mission,
		"Part",
		"Gantry",
		Vector3.new(44, 2, 4),
		CFrame.new(worldPosition + Vector3.new(0, 16, -18)),
		Color3.fromRGB(54, 58, 64),
		Enum.Material.Metal
	)
	gantry.CanQuery = false

	makeGlowPart(mission, "GantryLight", Vector3.new(34, 0.25, 1), CFrame.new(worldPosition + Vector3.new(0, 14.7, -16.2)), Color3.fromRGB(236, 162, 118), 0.78)
	makeGlowPart(mission, "WallStripLeft", Vector3.new(0.22, 10, 64), CFrame.new(worldPosition + Vector3.new(-44.8, 8, 0)), Color3.fromRGB(176, 122, 94), 0.84)
	makeGlowPart(mission, "WallStripRight", Vector3.new(0.22, 10, 64), CFrame.new(worldPosition + Vector3.new(44.8, 8, 0)), Color3.fromRGB(176, 122, 94), 0.84)

	local cameraStart = makePart(
		mission,
		"Part",
		"MissionCameraStart",
		Vector3.new(2, 2, 2),
		CFrame.new(worldPosition + Vector3.new(-70, 70, -90)),
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
		CFrame.new(worldPosition + Vector3.new(0, 24, -38)),
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

	makeSpawn(root, Config.Origin + Config.SpawnOffset)
	makeCentralHub(root, Config.Origin + Config.SpawnOffset + Vector3.new(0, 0, 0))
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
