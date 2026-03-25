local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local NameplateService = {}
NameplateService.__index = NameplateService

local TOP_RANK_STYLES = {
	[1] = {
		title = "GALAXY CROWN",
		stroke = Color3.fromRGB(164, 118, 255),
		frame = Color3.fromRGB(18, 12, 30),
		alwaysOnTop = true,
		size = UDim2.fromOffset(194, 64),
		maxDistance = 110,
		offset = Vector3.new(0, 3.45, 0),
		speed = 0.2,
		sequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 230, 255)),
			ColorSequenceKeypoint.new(0.32, Color3.fromRGB(255, 122, 232)),
			ColorSequenceKeypoint.new(0.64, Color3.fromRGB(138, 114, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 230, 255)),
		}),
	},
	[2] = {
		title = "SOLAR CREST",
		stroke = Color3.fromRGB(255, 188, 92),
		frame = Color3.fromRGB(34, 20, 10),
		alwaysOnTop = true,
		size = UDim2.fromOffset(188, 62),
		maxDistance = 96,
		offset = Vector3.new(0, 3.35, 0),
		speed = 0.16,
		sequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 124)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 154, 74)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(255, 240, 176)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 230, 124)),
		}),
	},
	[3] = {
		title = "AURORA MARK",
		stroke = Color3.fromRGB(104, 224, 214),
		frame = Color3.fromRGB(10, 22, 28),
		alwaysOnTop = true,
		size = UDim2.fromOffset(184, 60),
		maxDistance = 90,
		offset = Vector3.new(0, 3.3, 0),
		speed = 0.14,
		sequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(112, 245, 214)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(94, 164, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(112, 245, 214)),
		}),
	},
}

function NameplateService.new(_context)
	local self = setmetatable({}, NameplateService)
	self._animatedTags = {}
	self._heartbeatConnection = nil
	return self
end

function NameplateService:Start()
	if not self._heartbeatConnection then
		self._heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
			self:_stepAnimations(deltaTime)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		self:BindPlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:BindPlayer(player)
	end
end

function NameplateService:_getAccent(player)
	if player:GetAttribute("IsOwner") == true then
		return Color3.fromRGB(230, 192, 108)
	elseif player:GetAttribute("IsAdmin") == true then
		return Color3.fromRGB(214, 164, 102)
	end
	return Color3.fromRGB(132, 178, 232)
end

function NameplateService:_stepAnimations(deltaTime)
	for gradient, state in pairs(self._animatedTags) do
		if not gradient or gradient.Parent == nil then
			self._animatedTags[gradient] = nil
		else
			local speed = state.speed or 0.1
			local offset = ((state.offset or 0) + deltaTime * speed) % 2
			state.offset = offset
			gradient.Offset = Vector2.new(offset - 1, 0)
			gradient.Rotation = (state.rotationBase or 0) + math.sin(os.clock() * 1.6) * 8
		end
	end
end

function NameplateService:_clearAnimatedGradient(label)
	if not label then
		return
	end
	local gradient = label:FindFirstChild("AnimatedGradient")
	if gradient and gradient:IsA("UIGradient") then
		self._animatedTags[gradient] = nil
		gradient:Destroy()
	end
end

function NameplateService:_applyAnimatedGradient(label, rank)
	if not label then
		return
	end
	local style = TOP_RANK_STYLES[rank]
	if not style then
		self:_clearAnimatedGradient(label)
		return
	end

	local gradient = label:FindFirstChild("AnimatedGradient")
	if not gradient or not gradient:IsA("UIGradient") then
		gradient = Instance.new("UIGradient")
		gradient.Name = "AnimatedGradient"
		gradient.Parent = label
	end
	gradient.Color = style.sequence
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Rotation = 0
	self._animatedTags[gradient] = {
		speed = style.speed,
		offset = 0,
		rotationBase = rank == 1 and -10 or (rank == 2 and 0 or 8),
	}
end

function NameplateService:_updateTag(player, character)
	if not player or not character then
		return
	end

	local head = character:FindFirstChild("Head")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid then
		return
	end

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.NameDisplayDistance = 0
	humanoid.HealthDisplayDistance = 0

	local tag = head:FindFirstChild("PlayerTag")
	if not tag then
		tag = Instance.new("BillboardGui")
		tag.Name = "PlayerTag"
		tag.Size = UDim2.fromOffset(180, 58)
		tag.StudsOffset = Vector3.new(0, 3.2, 0)
		tag.AlwaysOnTop = false
		tag.MaxDistance = 70
		tag.LightInfluence = 1
		tag.Adornee = head
		tag.Parent = head

		local frame = Instance.new("Frame")
		frame.Name = "Frame"
		frame.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
		frame.BackgroundTransparency = 0.34
		frame.BorderSizePixel = 0
		frame.Size = UDim2.fromScale(1, 1)
		frame.Parent = tag

		local stroke = Instance.new("UIStroke")
		stroke.Name = "Stroke"
		stroke.Transparency = 0.22
		stroke.Thickness = 1
		stroke.Parent = frame

		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 6)
		padding.PaddingBottom = UDim.new(0, 6)
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.Parent = frame

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, 0, 0, 12)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 10
		title.TextXAlignment = Enum.TextXAlignment.Center
		title.Parent = frame

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.fromOffset(0, 14)
		nameLabel.Size = UDim2.new(1, 0, 0, 18)
		nameLabel.Font = Enum.Font.GothamBlack
		nameLabel.TextSize = 14
		nameLabel.TextColor3 = Color3.fromRGB(244, 247, 252)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		nameLabel.Parent = frame

		local level = Instance.new("TextLabel")
		level.Name = "Level"
		level.BackgroundTransparency = 1
		level.Position = UDim2.fromOffset(0, 34)
		level.Size = UDim2.new(1, 0, 0, 12)
		level.Font = Enum.Font.GothamMedium
		level.TextSize = 11
		level.TextColor3 = Color3.fromRGB(196, 208, 224)
		level.TextXAlignment = Enum.TextXAlignment.Center
		level.Parent = frame
	end

	local frame = tag:FindFirstChild("Frame")
	local stroke = frame and frame:FindFirstChild("Stroke")
	local title = frame and frame:FindFirstChild("Title")
	local nameLabel = frame and frame:FindFirstChild("Name")
	local level = frame and frame:FindFirstChild("Level")
	local rank = math.max(0, tonumber(player:GetAttribute("LeaderboardRank")) or 0)
	local rankStyle = TOP_RANK_STYLES[rank]
	local accent = self:_getAccent(player)
	local badge = tostring(player:GetAttribute("PlayerBadge") or "")
	local titleText = tostring(player:GetAttribute("PlayerTitle") or "Survivor")
	local levelValue = tonumber(player:GetAttribute("SkillTreeLevel")) or 1

	tag.Size = rankStyle and rankStyle.size or UDim2.fromOffset(180, 58)
	tag.StudsOffset = rankStyle and rankStyle.offset or Vector3.new(0, 3.2, 0)
	tag.AlwaysOnTop = rankStyle and rankStyle.alwaysOnTop or false
	tag.MaxDistance = rankStyle and rankStyle.maxDistance or 70

	if frame then
		frame.BackgroundColor3 = rankStyle and rankStyle.frame
			or (player:GetAttribute("IsOwner") == true and Color3.fromRGB(28, 24, 18)
			or (player:GetAttribute("IsAdmin") == true and Color3.fromRGB(28, 22, 18) or Color3.fromRGB(16, 18, 24)))
	end
	if stroke then
		stroke.Color = rankStyle and rankStyle.stroke or accent
		stroke.Thickness = rankStyle and 1.4 or 1
	end
	if title and title:IsA("TextLabel") then
		local prefix = rank > 0 and ("TOP %d | "):format(rank) or ""
		local titleValue = badge ~= "" and ("[%s] %s"):format(badge, titleText) or titleText
		title.Text = prefix .. titleValue
		title.TextColor3 = rankStyle and rankStyle.stroke or accent
	end
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = player.DisplayName
		nameLabel.TextColor3 = rank > 0 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(244, 247, 252)
		self:_applyAnimatedGradient(nameLabel, rank)
	end
	if level and level:IsA("TextLabel") then
		level.Text = ("Level %d"):format(levelValue)
		level.TextColor3 = rankStyle and rankStyle.stroke:Lerp(Color3.fromRGB(232, 240, 252), 0.28) or Color3.fromRGB(196, 208, 224)
	end
end

function NameplateService:BindPlayer(player)
	local function bindCharacter(character)
		task.defer(function()
			self:_updateTag(player, character)
		end)
	end

	player.CharacterAdded:Connect(bindCharacter)
	player:GetAttributeChangedSignal("PlayerTitle"):Connect(function()
		if player.Character then
			self:_updateTag(player, player.Character)
		end
	end)
	player:GetAttributeChangedSignal("PlayerBadge"):Connect(function()
		if player.Character then
			self:_updateTag(player, player.Character)
		end
	end)
	player:GetAttributeChangedSignal("SkillTreeLevel"):Connect(function()
		if player.Character then
			self:_updateTag(player, player.Character)
		end
	end)
	player:GetAttributeChangedSignal("IsAdmin"):Connect(function()
		if player.Character then
			self:_updateTag(player, player.Character)
		end
	end)
	player:GetAttributeChangedSignal("IsOwner"):Connect(function()
		if player.Character then
			self:_updateTag(player, player.Character)
		end
	end)
	player:GetAttributeChangedSignal("LeaderboardRank"):Connect(function()
		if player.Character then
			self:_updateTag(player, player.Character)
		end
	end)

	if player.Character then
		bindCharacter(player.Character)
	end
end

return NameplateService
