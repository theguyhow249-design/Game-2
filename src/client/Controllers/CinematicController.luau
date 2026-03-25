local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)

local CinematicController = {}

local overlay
local playing = false

local function new(className, props)
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		instance[key] = value
	end
	return instance
end

local function ensureOverlay(screenGui)
	if overlay and overlay.Parent == screenGui then
		return overlay
	end

	local root = new("Frame", {
		Name = "DeploymentCinematic",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = screenGui,
	})

	local topBar = new("Frame", {
		Name = "TopBar",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.12, 0),
		Position = UDim2.new(0, 0, -0.12, 0),
		Parent = root,
	})

	local bottomBar = new("Frame", {
		Name = "BottomBar",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.14, 0),
		Position = UDim2.new(0, 0, 1, 0),
		Parent = root,
	})

	local title = new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.04, 0),
		Size = UDim2.new(0.5, 0, 0.08, 0),
		Text = "DEPLOYING",
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
		Font = Theme.Fonts.Title,
		Parent = root,
	})

	local subtitle = new("TextLabel", {
		Name = "Subtitle",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.95, 0),
		Size = UDim2.new(0.6, 0, 0.08, 0),
		Text = "Flying into the outbreak zone",
		TextColor3 = Theme.Colors.AccentSoft,
		TextScaled = true,
		Font = Theme.Fonts.Heading,
		Parent = root,
	})

	overlay = {
		Root = root,
		TopBar = topBar,
		BottomBar = bottomBar,
		Title = title,
		Subtitle = subtitle,
	}

	return overlay
end

local function resolvePath(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end

	local current = game
	for segment in string.gmatch(path, "[^%.]+") do
		if segment == "Workspace" then
			current = Workspace
		else
			current = current:FindFirstChild(segment)
		end

		if not current then
			return nil
		end
	end

	return current
end

function CinematicController.play(screenGui, uiRoot, payload)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local nodes = ensureOverlay(screenGui)
	local duration = tonumber(payload and payload.duration) or 4
	local startNode = resolvePath(payload and payload.cameraStart)
	local endNode = resolvePath(payload and payload.cameraEnd)

	playing = true
	nodes.Root.Visible = true
	nodes.Title.Text = "DEPLOYING"
	nodes.Subtitle.Text = payload and payload.status or "Flying into the outbreak zone"
	nodes.Root.BackgroundTransparency = 1
	nodes.TopBar.Position = UDim2.new(0, 0, -0.12, 0)
	nodes.BottomBar.Position = UDim2.new(0, 0, 1, 0)

	if uiRoot then
		uiRoot.Visible = false
	end

	local originalCameraType = camera.CameraType
	local originalSubject = camera.CameraSubject
	camera.CameraType = Enum.CameraType.Scriptable

	if startNode and startNode:IsA("BasePart") then
		camera.CFrame = startNode.CFrame
	end

	TweenService:Create(nodes.Root, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.55,
	}):Play()
	TweenService:Create(nodes.TopBar, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0),
	}):Play()
	TweenService:Create(nodes.BottomBar, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0.86, 0),
	}):Play()

	if endNode and endNode:IsA("BasePart") then
		TweenService:Create(camera, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			CFrame = endNode.CFrame,
		}):Play()
	end

	task.delay(duration, function()
		if not playing then
			return
		end

		camera.CameraType = originalCameraType
		camera.CameraSubject = originalSubject
	end)
end

function CinematicController.stop(uiRoot)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end

	if overlay then
		overlay.Root.Visible = false
	end

	if uiRoot then
		uiRoot.Visible = true
	end

	playing = false
end

function CinematicController.isPlaying()
	return playing
end

return CinematicController
