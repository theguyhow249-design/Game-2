local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MissionConfig = require(Shared:WaitForChild("MissionConfig"))
local RemoteNames = require(Shared:WaitForChild("RemoteNames"))
local SkillTreeConfig = require(Shared:WaitForChild("SkillTreeConfig"))
local TokenEconomy = require(Shared:WaitForChild("TokenEconomy"))
local Theme = require(script.Parent.Theme)
local CinematicController = require(script.Parent.CinematicController)
local Remotes = require(script.Parent.Remotes)
local UiBuilder = require(script.Parent.Parent.UI.UiBuilder)

local FlowController = {}

local SOUND_IDS = {
	UiOpen = "rbxasset://sounds/action_get.wav",
	UiClose = "rbxasset://sounds/button.wav",
	Deploy = "rbxasset://sounds/electronicpingshort.wav",
	Alert = "rbxasset://sounds/uuhhh.wav",
	Success = "rbxasset://sounds/action_get.wav",
	CombatShot = "rbxasset://sounds/electronicpingshort.wav",
	CombatHit = "rbxasset://sounds/action_get.wav",
}

local COMBAT_AUDIO = {
	weapon_service_pistol = { volume = 0.18, pitch = 0.92 },
	weapon_patrol_carbine = { volume = 0.2, pitch = 0.8 },
	weapon_street_smg = { volume = 0.12, pitch = 1.28 },
	weapon_trench_shotgun = { volume = 0.32, pitch = 0.58 },
	weapon_training_blade = { volume = 0.1, pitch = 1.08 },
	weapon_crowbar = { volume = 0.11, pitch = 0.86 },
	weapon_fire_axe = { volume = 0.12, pitch = 0.78 },
	weapon_fists = { volume = 0.09, pitch = 1.22 },
}

local started = false
local player = nil
local ui = nil

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
		CornerRadius = radius or UDim.new(0, 12),
		Parent = parent,
	})
end

local function addStroke(parent, color, transparency, thickness)
	return new("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Transparency = transparency or 0.12,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function addTextConstraint(parent, maxSize, minSize)
	return new("UITextSizeConstraint", {
		MaxTextSize = maxSize or 18,
		MinTextSize = minSize or 10,
		Parent = parent,
	})
end

local function clearGeneratedChildren(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function cloneNames(list)
	local result = table.create(#list)
	for index, value in ipairs(list) do
		result[index] = value
	end
	return result
end

local function safeInvoke(name, ...)
	local args = table.pack(...)
	return pcall(function()
		return Remotes.invoke(name, table.unpack(args, 1, args.n))
	end)
end

local function formatTokenLabel(amount)
	return tostring(math.max(0, math.floor(amount or 0))) .. " Deploy Tokens"
end

local function formatShortDuration(seconds)
	local remaining = math.max(0, math.floor(seconds or 0))
	local hours = math.floor(remaining / 3600)
	local minutes = math.floor((remaining % 3600) / 60)
	local secs = remaining % 60

	if hours > 0 then
		return ("%dh %02dm"):format(hours, minutes)
	end

	if minutes > 0 then
		return ("%dm %02ds"):format(minutes, secs)
	end

	return ("%ds"):format(secs)
end

local function trimLabel(text, maxLength)
	local value = tostring(text or "")
	if #value <= maxLength then
		return value
	end

	return value:sub(1, maxLength - 3) .. "..."
end

local function formatLeaderboardMinutes(minutes)
	local totalMinutes = math.max(0, math.floor(minutes or 0))
	local hours = math.floor(totalMinutes / 60)
	local mins = totalMinutes % 60
	if hours > 0 then
		return ("%dh %02dm"):format(hours, mins)
	end
	return ("%dm"):format(mins)
end

local function formatSquadSlot(member)
	local name = member.displayName or member.name or member.userId or "Player"
	if member.isLeader then
		name = tostring(name) .. " (L)"
	end
	return trimLabel(name, 14)
end

local function normalizeDailyRewardState(payload)
	if type(payload) ~= "table" then
		return nil
	end

	return {
		lastClaimAt = tonumber(payload.lastClaimAt or payload.LastClaimAt),
		nextClaimAt = tonumber(payload.nextClaimAt or payload.NextClaimAt) or 0,
		canClaim = payload.canClaim == true or payload.CanClaim == true,
	}
end

local function normalizeWeeklyRewardState(payload)
	if type(payload) ~= "table" then
		return nil
	end

	return {
		lastClaimAt = tonumber(payload.lastClaimAt or payload.LastClaimAt),
		nextClaimAt = tonumber(payload.nextClaimAt or payload.NextClaimAt) or 0,
		canClaim = payload.canClaim == true or payload.CanClaim == true,
		active = payload.active == true or payload.Active == true,
	}
end

local function normalizeDailyOpsState(payload)
	if type(payload) ~= "table" then
		return nil
	end

	local tasks = {}
	for _, entry in ipairs(payload.tasks or {}) do
		if type(entry) == "table" then
			table.insert(tasks, {
				id = tostring(entry.id or entry.Id or ""),
				displayName = tostring(entry.displayName or entry.DisplayName or "Daily Op"),
				description = tostring(entry.description or entry.Description or ""),
				progress = tonumber(entry.progress or entry.Progress) or 0,
				goal = math.max(1, tonumber(entry.goal or entry.Goal) or 1),
				progressPercent = tonumber(entry.progressPercent or entry.ProgressPercent) or 0,
				canClaim = entry.canClaim == true or entry.CanClaim == true,
				claimed = entry.claimed == true or entry.Claimed == true,
				rewardTokens = tonumber(entry.rewardTokens or entry.RewardTokens) or 0,
				rewardExperience = tonumber(entry.rewardExperience or entry.RewardExperience) or 0,
			})
		end
	end

	return {
		dayKey = tonumber(payload.dayKey or payload.DayKey) or 0,
		nextResetAt = tonumber(payload.nextResetAt or payload.NextResetAt) or 0,
		tasks = tasks,
	}
end

local function normalizeSubscriptionState(payload)
	if type(payload) ~= "table" then
		return nil
	end

	local subscriptionId = tostring(payload.subscriptionId or payload.SubscriptionId or "")
	return {
		subscriptionId = subscriptionId,
		displayName = tostring(payload.displayName or payload.DisplayName or "Supporter"),
		isActive = payload.isActive == true or payload.IsActive == true,
		lastCheckedAt = tonumber(payload.lastCheckedAt or payload.LastCheckedAt),
		weeklyRewardClaimedAt = tonumber(payload.weeklyRewardClaimedAt or payload.WeeklyRewardClaimedAt),
		weeklyRewardAvailable = payload.weeklyRewardAvailable == true or payload.WeeklyRewardAvailable == true,
		tokenRewardMultiplier = tonumber(payload.tokenRewardMultiplier or payload.TokenRewardMultiplier) or 1,
		experienceMultiplier = tonumber(payload.experienceMultiplier or payload.ExperienceMultiplier) or 1,
		extractionHoldMultiplier = tonumber(payload.extractionHoldMultiplier or payload.ExtractionHoldMultiplier) or 1,
		dailyBonusTokens = tonumber(payload.dailyBonusTokens or payload.DailyBonusTokens) or 0,
		extraInventorySlots = tonumber(payload.extraInventorySlots or payload.ExtraInventorySlots) or 0,
	}
end

local function normalizeSquadSnapshot(payload)
	if type(payload) ~= "table" then
		return nil
	end

	local sourceMembers = payload.members or payload.Members or {}
	local members = {}
	for index, entry in ipairs(sourceMembers) do
		if type(entry) == "table" then
			table.insert(members, {
				userId = tonumber(entry.userId or entry.UserId) or index,
				displayName = tostring(entry.displayName or entry.DisplayName or entry.name or entry.Name or ("Player " .. index)),
				isLeader = entry.isLeader == true or entry.IsLeader == true,
				ready = entry.ready == true or entry.Ready == true,
			})
		else
			table.insert(members, {
				userId = index,
				displayName = tostring(entry),
				isLeader = false,
				ready = false,
			})
		end
	end

	table.sort(members, function(a, b)
		return a.userId < b.userId
	end)

	return {
		squadId = tostring(payload.squadId or payload.SquadId or ""),
		leaderUserId = tonumber(payload.leaderUserId or payload.LeaderUserId) or 0,
		maxPlayers = tonumber(payload.maxPlayers or payload.MaxPlayers) or Theme.SquadLimit,
		members = members,
	}
end

local function normalizeSquadDirectory(payload)
	if type(payload) ~= "table" then
		return {}
	end

	local entries = {}
	for _, entry in ipairs(payload) do
		if type(entry) == "table" then
			local names = {}
			for _, memberName in ipairs(entry.memberNames or entry.MemberNames or {}) do
				table.insert(names, tostring(memberName))
			end

			table.insert(entries, {
				squadId = tostring(entry.squadId or entry.SquadId or ""),
				leaderName = tostring(entry.leaderName or entry.LeaderName or "Squad Leader"),
				leaderUserId = tonumber(entry.leaderUserId or entry.LeaderUserId) or 0,
				memberCount = tonumber(entry.memberCount or entry.MemberCount) or #names,
				maxPlayers = tonumber(entry.maxPlayers or entry.MaxPlayers) or Theme.SquadLimit,
				locked = entry.locked == true or entry.Locked == true,
				state = tostring(entry.state or entry.State or "Lobby"),
				memberNames = names,
				canJoin = entry.canJoin == true or entry.CanJoin == true,
				isCurrentSquad = entry.isCurrentSquad == true or entry.IsCurrentSquad == true,
			})
		end
	end

	return entries
end

local function normalizeInviteablePlayers(payload)
	if type(payload) ~= "table" then
		return {}
	end

	local entries = {}
	for _, entry in ipairs(payload) do
		if type(entry) == "table" then
			table.insert(entries, {
				userId = tonumber(entry.userId or entry.UserId) or 0,
				displayName = tostring(entry.displayName or entry.DisplayName or "Survivor"),
				canInvite = entry.canInvite == true or entry.CanInvite == true,
				isSameSquad = entry.isSameSquad == true or entry.IsSameSquad == true,
			})
		end
	end

	table.sort(entries, function(a, b)
		if a.canInvite ~= b.canInvite then
			return a.canInvite
		end
		return a.displayName < b.displayName
	end)

	return entries
end

local function formatDailyRewardStatus(state)
	if not state then
		return "Daily reward syncing..."
	end

	if state.canClaim then
		return "Daily reward ready: claim +10 deploy tokens."
	end

	local remaining = state.nextClaimAt - os.time()
	return ("Daily reward claimed. Next reset in %s."):format(formatShortDuration(remaining))
end

local function formatSquadSummary(snapshot)
	if not snapshot or type(snapshot.members) ~= "table" then
		return "Squad data syncing..."
	end

	local memberCount = #snapshot.members
	local leaderName = "Unknown"
	for _, member in ipairs(snapshot.members) do
		if member.isLeader then
			leaderName = member.displayName
			break
		end
	end

	if memberCount <= 1 then
		return ("Solo squad active. Leader: %s. Invite up to %d more survivors."):format(leaderName, math.max(0, snapshot.maxPlayers - 1))
	end

	return ("%d/%d survivors in squad. Leader: %s. More players increase danger and improve loot."):format(
		memberCount,
		snapshot.maxPlayers,
		leaderName
	)
end

local function normalizeShopTab(tabName)
	if type(tabName) ~= "string" then
		return nil
	end

	return Theme.ShopCategoryToTab[tabName] or tabName
end

local function normalizeStationPanelName(panelName)
	if type(panelName) ~= "string" then
		return nil
	end

	local lowerName = string.lower(panelName)
	if lowerName == "shop" or string.find(lowerName, "quartermaster", 1, true) or string.find(lowerName, "market", 1, true) then
		return "Shop"
	end
	if lowerName == "squad" or string.find(lowerName, "fireteam", 1, true) or string.find(lowerName, "command", 1, true) then
		return "Squad"
	end
	if lowerName == "social" or string.find(lowerName, "comms", 1, true) or string.find(lowerName, "lounge", 1, true) then
		return "Social"
	end
	if lowerName == "inventory" or string.find(lowerName, "locker", 1, true) or string.find(lowerName, "loadout", 1, true) then
		return "Inventory"
	end
	if lowerName == "skilltree" or lowerName == "skill tree" or string.find(lowerName, "skill", 1, true) or string.find(lowerName, "branch", 1, true) then
		return "SkillTree"
	end
	if lowerName == "questboard" or lowerName == "ops" or string.find(lowerName, "operations", 1, true) or string.find(lowerName, "daily", 1, true) then
		return "QuestBoard"
	end

	return nil
end

local function setPageVisibility(ui, activeName)
	for name, page in pairs(ui.Pages) do
		local active = name == activeName
		page.Visible = active
	end
end

local function animatePopupFrame(popup, isActive)
	local scaleDriver = popup:FindFirstChild("ScaleDriver")
	local openY = popup:GetAttribute("OpenY")
	local closedY = popup:GetAttribute("ClosedY")
	if isActive then
		popup.Visible = true
		if typeof(closedY) == "number" then
			popup.Position = UDim2.new(popup.Position.X.Scale, popup.Position.X.Offset, popup.Position.Y.Scale, closedY)
		end
		if scaleDriver then
			scaleDriver.Scale = 0.97
			TweenService:Create(scaleDriver, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
		if typeof(openY) == "number" then
			TweenService:Create(popup, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(popup.Position.X.Scale, popup.Position.X.Offset, popup.Position.Y.Scale, openY),
			}):Play()
		end
	else
		if scaleDriver then
			TweenService:Create(scaleDriver, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Scale = 0.98,
			}):Play()
		end
		if typeof(closedY) == "number" then
			TweenService:Create(popup, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(popup.Position.X.Scale, popup.Position.X.Offset, popup.Position.Y.Scale, closedY),
			}):Play()
		end
		task.delay(0.13, function()
			if popup.Parent and not popup:GetAttribute("KeepOpen") then
				popup.Visible = false
			end
		end)
	end
end

local function restoreCameraToPlayer(player)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function styleButton(button, accent)
	local baseColor = accent or button.BackgroundColor3
	local hoverColor = baseColor:Lerp(Color3.new(1, 1, 1), 0.12)
	button.MouseEnter:Connect(function()
		if button.Active == false then
			return
		end
		TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			BackgroundColor3 = hoverColor,
		}):Play()
	end)
	button.MouseLeave:Connect(function()
		local target = button:GetAttribute("BaseButtonColor")
		TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			BackgroundColor3 = typeof(target) == "Color3" and target or baseColor,
		}):Play()
	end)
end

local function playUiSound(soundId, volume, pitch)
	if RunService:IsStudio() then
		return
	end
	if SoundService:GetAttribute("UiAudioEnabled") == false then
		return
	end
	if type(soundId) ~= "string" or soundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.45
	sound.PlaybackSpeed = pitch or 1
	sound.RollOffMaxDistance = 60
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(4, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function setButtonEnabled(button, enabled, enabledColor)
	local baseColor = enabled and (enabledColor or button.BackgroundColor3) or Theme.Colors.Backdrop
	button.Active = enabled
	button.Selectable = enabled
	button.AutoButtonColor = false
	button.TextColor3 = enabled and Theme.Colors.Text or Theme.Colors.Muted
	button:SetAttribute("BaseButtonColor", baseColor)
	button.BackgroundColor3 = baseColor
end

local function pulseGuiObject(target, accentColor)
	if not target or not target.Parent then
		return
	end

	local scaleDriver = target:FindFirstChild("RewardPulseScale")
	if not scaleDriver or not scaleDriver:IsA("UIScale") then
		scaleDriver = new("UIScale", {
			Name = "RewardPulseScale",
			Scale = 1,
			Parent = target,
		})
	end
	scaleDriver.Scale = 1
	TweenService:Create(scaleDriver, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = 1.05,
	}):Play()
	task.delay(0.12, function()
		if scaleDriver and scaleDriver.Parent then
			TweenService:Create(scaleDriver, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Scale = 1,
			}):Play()
		end
	end)

	local flash = new("Frame", {
		Name = "RewardPulseFlash",
		BackgroundColor3 = accentColor or Theme.Colors.AccentWarm,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 20,
		Parent = target,
	})
	addCorner(flash, UDim.new(0, 10))
	TweenService:Create(flash, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	task.delay(0.26, function()
		if flash.Parent then
			flash:Destroy()
		end
	end)
end

local function getSkillTreeTotalExperience(skillTree)
	if type(skillTree) ~= "table" then
		return 0
	end

	local level = math.max(1, tonumber(skillTree.level) or 1)
	local experienceIntoLevel = math.max(0, tonumber(skillTree.experienceIntoLevel) or 0)
	local total = experienceIntoLevel
	for currentLevel = 1, level - 1 do
		total += SkillTreeConfig.getExperienceForNextLevel(currentLevel)
	end
	return total
end

local function getRewardFloatAnchorPosition()
	local camera = Workspace.CurrentCamera
	if not camera then
		return UDim2.new(0.5, 0, 0.62, 0)
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	local anchorPart = head or rootPart
	if anchorPart and anchorPart:IsA("BasePart") then
		local worldPosition = anchorPart.Position + Vector3.new(0, 1.8, 0)
		local viewportPoint, onScreen = camera:WorldToViewportPoint(worldPosition)
		if onScreen and viewportPoint.Z > 0 then
			return UDim2.fromOffset(math.floor(viewportPoint.X), math.floor(viewportPoint.Y))
		end
	end

	return UDim2.new(0.5, 0, 0.62, 0)
end

local function getWorldAnchorPosition(instance, yOffset, fallback)
	local camera = Workspace.CurrentCamera
	if not camera or not instance then
		return fallback or getRewardFloatAnchorPosition()
	end

	local worldPosition = nil
	if instance:IsA("BasePart") then
		worldPosition = instance.Position
	elseif instance:IsA("Model") then
		local pivot = instance:GetPivot()
		worldPosition = pivot.Position
	end

	if worldPosition then
		worldPosition += Vector3.new(0, yOffset or 0, 0)
		local viewportPoint, onScreen = camera:WorldToViewportPoint(worldPosition)
		if onScreen and viewportPoint.Z > 0 then
			return UDim2.fromOffset(math.floor(viewportPoint.X), math.floor(viewportPoint.Y))
		end
	end

	return fallback or getRewardFloatAnchorPosition()
end

local function getWorldVectorAnchorPosition(worldPosition, yOffset, fallback)
	local camera = Workspace.CurrentCamera
	if not camera or typeof(worldPosition) ~= "Vector3" then
		return fallback or getRewardFloatAnchorPosition()
	end

	local viewportPoint, onScreen = camera:WorldToViewportPoint(worldPosition + Vector3.new(0, yOffset or 0, 0))
	if onScreen and viewportPoint.Z > 0 then
		return UDim2.fromOffset(math.floor(viewportPoint.X), math.floor(viewportPoint.Y))
	end

	return fallback or getRewardFloatAnchorPosition()
end

local function getMissionObjectiveRewardAnchor(reason)
	local fallback = reason == "mission_complete"
		and UDim2.new(0.5, 0, 0.4, 0)
		or UDim2.new(0.5, 0, 0.52, 0)
	local objective = Workspace:FindFirstChild("ObjectiveCore", true)
	if objective then
		return getWorldAnchorPosition(objective, 6.5, fallback)
	end

	if reason == "mission_complete" then
		local extractionPad = Workspace:FindFirstChild("ExtractionPad", true)
		if extractionPad then
			return getWorldAnchorPosition(extractionPad, 5.5, fallback)
		end
	end

	return fallback
end

local function spawnFloatingRewardText(text, accentColor, options)
	local layer = ui and ui.Lobby and ui.Lobby.RewardFloatLayer
	if not layer or type(text) ~= "string" or text == "" then
		return
	end

	options = type(options) == "table" and options or {}
	local anchor = options.position or getRewardFloatAnchorPosition()
	local xJitter = math.random(-40, 40)
	local yJitter = math.random(-10, 16)
	local rise = tonumber(options.rise) or 46
	local lifetime = tonumber(options.lifetime) or 0.65
	local rewardLabel = new("TextLabel", {
		Name = "RewardFloat",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(anchor.X.Scale, anchor.X.Offset + xJitter, anchor.Y.Scale, anchor.Y.Offset + yJitter),
		Size = UDim2.new(0, 180, 0, 28),
		Text = text,
		TextColor3 = accentColor or Theme.Colors.AccentWarm,
		TextSize = tonumber(options.textSize) or 20,
		TextScaled = false,
		Font = Theme.Fonts.Heading,
		ZIndex = 83,
		Parent = layer,
	})
	local stroke = new("UIStroke", {
		Color = Color3.new(0.04, 0.05, 0.07),
		Transparency = 0.22,
		Thickness = 1.2,
		Parent = rewardLabel,
	})
	local scaleDriver = new("UIScale", {
		Scale = 0.88,
		Parent = rewardLabel,
	})

	TweenService:Create(scaleDriver, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	TweenService:Create(rewardLabel, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(anchor.X.Scale, anchor.X.Offset + xJitter, anchor.Y.Scale, anchor.Y.Offset + yJitter - rise),
		TextTransparency = 1,
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
	}):Play()
	task.delay(lifetime + 0.06, function()
		if rewardLabel.Parent then
			rewardLabel:Destroy()
		end
	end)
end

local function makeListCard(parent, name, height)
	local card = new("Frame", {
		Name = name,
		BackgroundColor3 = Theme.Colors.PanelAlt,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		Parent = parent,
	})
	addCorner(card, UDim.new(0, 12))
	addStroke(card, Theme.Colors.Stroke, 0.18, 1)
	local shine = new("Frame", {
		Name = "Shine",
		BackgroundColor3 = Theme.Colors.Text,
		BackgroundTransparency = 0.96,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = card,
	})
	addCorner(shine, UDim.new(0, 4))
	return card
end

local function makeListButton(parent, name, text, position, size, color)
	local button = new("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		AutoButtonColor = false,
		Text = text,
		TextColor3 = Theme.Colors.Text,
		TextScaled = false,
		TextSize = 15,
		TextWrapped = true,
		Font = Theme.Fonts.Heading,
		Parent = parent,
	})
	addCorner(button, UDim.new(0, 10))
	addStroke(button, Theme.Colors.Stroke, 0.2, 1)
	setButtonEnabled(button, true, color)
	styleButton(button, color)
	return button
end

local function getBranchTheme(branchName)
	return Theme.SkillTreeBranches[branchName] or Theme.SkillTreeBranches.Survivor
end

local function getSkillRank(skillTree, skillId)
	local skills = skillTree and skillTree.skills
	return math.max(0, math.floor((skills and skills[skillId]) or 0))
end

local function getRarityStyle(rarity)
	local value = tostring(rarity or "Common")
	if value == "Uncommon" then
		return value, Color3.fromRGB(88, 166, 108)
	elseif value == "Rare" then
		return value, Color3.fromRGB(88, 136, 214)
	elseif value == "Epic" then
		return value, Color3.fromRGB(176, 108, 214)
	elseif value == "Legendary" then
		return value, Color3.fromRGB(232, 173, 78)
	elseif value == "Supporter" then
		return value, Color3.fromRGB(214, 190, 108)
	end
	return value, Color3.fromRGB(126, 138, 150)
end

local function getRarityWeight(rarity)
	local value = tostring(rarity or "Common")
	if value == "Legendary" then
		return 5
	elseif value == "Epic" then
		return 4
	elseif value == "Rare" then
		return 3
	elseif value == "Uncommon" then
		return 2
	elseif value == "Supporter" then
		return 1
	end
	return 0
end

local function getDropChanceText(item, seasonalEventState)
	if type(item) ~= "table" then
		return "Drop Chance: --"
	end
	if item.CostType == "Robux" then
		return "Drop Chance: store only"
	end

	local chance = TokenEconomy.getDropChanceForItem(item, seasonalEventState, 1)
	if chance <= 0 then
		if item.SeasonalEvent then
			return "Drop Chance: seasonal event only"
		end
		if item.DropOnly then
			return "Drop Chance: mission drop only"
		end
		return "Drop Chance: none"
	end

	local suffix = ""
	if seasonalEventState then
		if item.SeasonalEvent and item.SeasonalEvent == seasonalEventState.Id then
			suffix = (" (%s boosted)"):format(tostring(seasonalEventState.DisplayName or seasonalEventState.Id))
		elseif tonumber(seasonalEventState.GlobalDropBonus or 0) > 0 then
			suffix = (" (%s active)"):format(tostring(seasonalEventState.DisplayName or seasonalEventState.Id))
		end
	end

	return ("Drop Chance: %.1f%%%s"):format(chance, suffix)
end

local function matchesRarityFilter(rarity, filterName)
	if filterName == nil or filterName == "All" then
		return true
	end
	return tostring(rarity or "Common") == tostring(filterName)
end

local function matchesPremiumFilter(item, filterName)
	if filterName == nil or filterName == "All" then
		return true
	end
	if type(item) ~= "table" then
		return false
	end
	if filterName == "Passes" then
		return type(item.GamePassId) == "number" and item.GamePassId > 0
	elseif filterName == "Supporter" then
		return type(item.SubscriptionId) == "string" and item.SubscriptionId ~= ""
	elseif filterName == "Packs" then
		return (item.CostType == "Robux") and not (type(item.GamePassId) == "number" and item.GamePassId > 0) and not (type(item.SubscriptionId) == "string" and item.SubscriptionId ~= "")
	end
	return true
end

local function getSkillState(skillId, skill, currentRank, maxRank, prereqMet, prereqName, availablePoints, spendingSkillId)
	if spendingSkillId == skillId then
		return "APPLYING", Theme.Colors.AccentWarm, false
	end

	if currentRank >= maxRank then
		return "MAXED", Color3.fromRGB(108, 136, 76), false
	end

	if not prereqMet then
		return prereqName and ("NEED " .. prereqName) or "CHAINED", Color3.fromRGB(86, 96, 108), false
	end

	if availablePoints <= 0 then
		return "LOCKED", Color3.fromRGB(86, 96, 108), false
	end

	return "READY", Color3.fromRGB(70, 112, 82), true
end

local function createSkillNodeBadge(parent, name, text, position, size, color, textColor, textSize)
	local badge = new("TextLabel", {
		Name = name,
		BackgroundColor3 = color,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		Text = text,
		TextColor3 = textColor or Theme.Colors.Text,
		TextScaled = false,
		TextSize = textSize or 11,
		Font = Theme.Fonts.Heading,
		Parent = parent,
	})
	addCorner(badge, UDim.new(0, 8))
	addStroke(badge, color, 0.14, 1)
	return badge
end

function FlowController.start()
	if started then
		return
	end
	started = true

	player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	ui = UiBuilder.create(playerGui)

	local state = "Home"
	local loadingStartedAt = 0
	local awaitingContinuePrompt = false
	local promptTween = nil
	local activePopup = nil
	local tokenBalance = Theme.DefaultTokenBalance
	local currentDeployStatus = Theme.StatusCopy.Lobby
	local persistenceOnline = true
	local persistenceReason = "Saving"
	local currentSocialMessage = Theme.LobbyBlurb
	local currentShopTab = Theme.ShopTabs[1]
	local currentShopStatus = "Select a quartermaster lane to browse bunker gear and deployment kit."
	local seasonalEventState = nil
	local currentShopRarityFilter = "All"
	local currentShopPremiumFilter = "All"
	local currentInventoryTab = "Weapons"
	local currentInventoryStatus = "Owned gear appears here. Equip a weapon or cosmetic from the locker."
	local currentInventoryRarityFilter = "All"
	local currentSkillTreeStatus = "Allocate points to unlock deeper branch nodes."
	local currentSkillTreeBranchFilter = "All"
	local selectedSkillTreeNodeId = nil
	local currentAdminStatus = "Commands ready."
	local currentAdminEventLabel = "Event Mode: Auto Rotation"
	local selectedAdminTargetUserId = nil
	local activeAdminTab = "Session"
	local squadSnapshot = nil
	local squadDirectory = {}
	local inviteablePlayers = {}
	local dailyRewardState = nil
	local dailyOpsState = nil
	local weeklyRewardState = nil
	local subscriptionState = nil
	local shopCatalog = {}
	local progression = {
		equippedWeapon = "weapon_training_blade",
		equippedCosmetic = nil,
		identity = {
			title = "Survivor",
			badge = nil,
			isModerator = false,
			isAdmin = false,
			isOwner = false,
		},
		unlocks = {},
		weaponExperience = {
			weapon_training_blade = 0,
		},
		stats = {
			missionsCompleted = 0,
			zombiesDefeated = 0,
		},
		skillTree = {
			level = 1,
			experience = 0,
			experienceIntoLevel = 0,
			experienceForNextLevel = SkillTreeConfig.getExperienceForNextLevel(1),
			skillPoints = 0,
			skills = {},
		},
	}
	local missionTelemetry = {
		phase = "Staging",
		scenarioName = "Hold The Core",
		scenarioDescription = "",
		wave = 0,
		totalWaves = 0,
		objectiveHealthPercent = 100,
		ammo = nil,
		reserveAmmo = nil,
	}
	local nextMissionPreview = {
		scenarioName = "Hold The Core",
		scenarioDescription = "Standard bunker defense. Hold the center and clear the waves.",
		layoutName = "Breach Yard",
		layoutDescription = "Wide yard lanes with long sightlines and exposed flanks.",
		modifierName = "Standard Ops",
		modifierDescription = "Balanced bunker-defense pressure.",
	}
	local nextMissionVoteOptions = {}
	local leadingMissionVoteOptionId = nil
	local currentVoteOptionId = nil
	local currentVoteSessionId = 0
	local cameraKick = Vector2.zero
	local hitMarkerToken = 0
	local isClaimingDailyReward = false
	local isRefreshingDirectory = false
	local purchasingItemId = nil
	local equippingItemId = nil
	local spendingSkillId = nil
	local pendingRespecConfirmation = false
	local pendingResults = nil
	local pendingInvite = nil
	local pendingNpcDialogue = nil
	local isRefreshingInvitePlayers = false
	local uiAudioEnabled = true
	local screenShakeEnabled = true
	local missionToastNonce = 0
	local suppressedMissionPrompts = {}
	SoundService:SetAttribute("UiAudioEnabled", uiAudioEnabled)

	local renderShopItems
	local renderInventoryItems
	local renderSkillTreeItems
	local renderSquadDirectory
	local renderInvitePlayerList
	local renderDailyOpsItems
	local renderLeaderboardBoard
	local renderAdminTargetList
	local setLobbyValue
	local refreshSquadDirectory
	local refreshInviteablePlayers
	local refreshDailyRewardState
	local refreshDailyOpsState
	local refreshWeeklyRewardState
	local refreshShopCatalog
	local enterLobby
	local homeSignalSweepTween = nil
	local homeSignalPulseTweens = {}
	local homeIntroPlayed = false

	local function cancelHomeAnimations()
		if homeSignalSweepTween then
			homeSignalSweepTween:Cancel()
			homeSignalSweepTween = nil
		end
		for _, tween in ipairs(homeSignalPulseTweens) do
			tween:Cancel()
		end
		table.clear(homeSignalPulseTweens)
	end

	local function animateHomeScreen(playIntro)
		if not ui or not ui.Home or not ui.Home.Panel then
			return
		end

		cancelHomeAnimations()

		local panel = ui.Home.Panel
		local leftPane = ui.Home.LeftCommandPane
		local rightPane = ui.Home.RightHeroPane
		local readinessCard = ui.Home.ReadinessCard
		local glow = ui.Home.BackdropGlow
		local heroBand = ui.Home.HeroBand
		local heroStatus = ui.Home.HeroStatus
		local heroTitle = ui.Home.HeroTitle
		local heroBody = ui.Home.HeroBody
		local hint = ui.Home.Hint
		local playButton = ui.Home.PlayButton
		local signalSweep = ui.Home.SignalSweep
		local signalBars = ui.Home.SignalBars or {}
		local infoCards = ui.Home.InfoCards or {}

		if playIntro or not homeIntroPlayed then
			homeIntroPlayed = true

			leftPane.Position = UDim2.new(0, -28, 0, 0)
			leftPane.BackgroundTransparency = 0.18
			rightPane.Position = UDim2.new(0, 388, 0, 0)
			rightPane.BackgroundTransparency = 0.18
			readinessCard.Position = UDim2.new(0, 24, 0, 192)
			readinessCard.BackgroundTransparency = 0.22
			glow.BackgroundTransparency = 0.96
			heroStatus.TextTransparency = 1
			heroTitle.TextTransparency = 1
			heroBody.TextTransparency = 1
			hint.TextTransparency = 1
			for _, card in ipairs(infoCards) do
				if card then
					card.Position = card.Position + UDim2.fromOffset(0, 18)
					card.BackgroundTransparency = 0.2
				end
			end
			local playScale = playButton:FindFirstChild("HomeIntroScale") or new("UIScale", {
				Name = "HomeIntroScale",
				Scale = 0.92,
				Parent = playButton,
			})
			playScale.Scale = 0.92

			TweenService:Create(leftPane, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 0.06,
			}):Play()
			TweenService:Create(rightPane, TweenInfo.new(0.46, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, 360, 0, 0),
				BackgroundTransparency = 0.02,
			}):Play()
			TweenService:Create(readinessCard, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, 24, 0, 172),
				BackgroundTransparency = 0.08,
			}):Play()
			TweenService:Create(glow, TweenInfo.new(0.52, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0.88,
			}):Play()
			TweenService:Create(heroStatus, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 0,
			}):Play()
			TweenService:Create(heroTitle, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 0,
			}):Play()
			TweenService:Create(heroBody, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 0,
			}):Play()
			TweenService:Create(hint, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 0,
			}):Play()
			TweenService:Create(playScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
			for index, card in ipairs(infoCards) do
				if card then
					local targetPosition = UDim2.new(0, (index - 1) * 148, 0, 0)
					TweenService:Create(card, TweenInfo.new(0.32 + (index * 0.05), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Position = targetPosition,
						BackgroundTransparency = 0.06,
					}):Play()
				end
			end
		end

		if glow then
			local glowTween = TweenService:Create(glow, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				BackgroundTransparency = 0.93,
			})
			glowTween:Play()
			table.insert(homeSignalPulseTweens, glowTween)
		end
		if heroBand then
			local bandTween = TweenService:Create(heroBand, TweenInfo.new(1.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				Size = UDim2.new(0, 212, 0, 4),
				BackgroundTransparency = 0.18,
			})
			bandTween:Play()
			table.insert(homeSignalPulseTweens, bandTween)
		end
		if signalSweep then
			signalSweep.Position = UDim2.new(0, -72, 0, 8)
			homeSignalSweepTween = TweenService:Create(signalSweep, TweenInfo.new(1.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1), {
				Position = UDim2.new(1, 12, 0, 8),
			})
			homeSignalSweepTween:Play()
		end
		for index, bar in ipairs(signalBars) do
			if bar then
				local pulseTween = TweenService:Create(bar, TweenInfo.new(0.7 + (index * 0.08), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
					BackgroundTransparency = 0.28,
					Size = UDim2.new(0, 16, 0, bar.Size.Y.Offset + (index % 2 == 0 and 8 or 4)),
				})
				pulseTween:Play()
				table.insert(homeSignalPulseTweens, pulseTween)
			end
		end
	end

	local function getAdminTargetPlayer()
		if selectedAdminTargetUserId and tonumber(selectedAdminTargetUserId) and tonumber(selectedAdminTargetUserId) ~= player.UserId then
			return Players:GetPlayerByUserId(tonumber(selectedAdminTargetUserId))
		end
		return player
	end

	local function updateAdminTargetSummary()
		if not ui or not ui.Lobby.AdminTargetName then
			return
		end
		local targetPlayer = getAdminTargetPlayer()
		local targetIsSelf = not targetPlayer or targetPlayer == player
		local levelValue = targetPlayer and math.max(1, tonumber(targetPlayer:GetAttribute("SkillTreeLevel")) or 1) or (progression.skillTree and progression.skillTree.level or 1)
		local titleValue = targetPlayer and tostring(targetPlayer:GetAttribute("PlayerTitle") or "Survivor") or tostring(progression.identity and progression.identity.title or "Survivor")
		ui.Lobby.AdminTargetName.Text = ("Target: %s"):format(targetIsSelf and "Self" or tostring(targetPlayer.DisplayName or targetPlayer.Name))
		ui.Lobby.AdminTargetRole.Text = ("%s | Lv.%d"):format(titleValue, levelValue)
		ui.Lobby.AdminTargetMeta.Text = targetIsSelf and "Self-targeted commands affect your own operator profile." or ("Selected server target: %s"):format(tostring(targetPlayer.Name or targetPlayer.DisplayName))
	end

	local function getAllowedAdminTabs(identity)
		local isModerator = identity.isModerator == true or identity.isAdmin == true or identity.isOwner == true
		local isAdmin = identity.isAdmin == true or identity.isOwner == true
		local isOwner = identity.isOwner == true
		return {
			Session = isModerator,
			Progression = isAdmin,
			LiveOps = isAdmin,
			Access = isOwner,
		}
	end

	local function updateAdminTabVisibility()
		if not ui or not ui.Lobby.AdminTabs or not ui.Lobby.AdminPages then
			return
		end
		local allowedTabs = getAllowedAdminTabs(progression.identity or {})
		if not allowedTabs[activeAdminTab] then
			if allowedTabs.Session then
				activeAdminTab = "Session"
			elseif allowedTabs.Progression then
				activeAdminTab = "Progression"
			elseif allowedTabs.LiveOps then
				activeAdminTab = "LiveOps"
			elseif allowedTabs.Access then
				activeAdminTab = "Access"
			end
		end
		local activeColors = {
			Session = Color3.fromRGB(92, 150, 112),
			Progression = Color3.fromRGB(188, 142, 76),
			LiveOps = Color3.fromRGB(102, 132, 188),
			Access = Color3.fromRGB(148, 86, 86),
		}
		for tabKey, tabButton in pairs(ui.Lobby.AdminTabs) do
			local isAllowed = allowedTabs[tabKey] == true
			local isActive = isAllowed and activeAdminTab == tabKey
			tabButton.Visible = isAllowed
			setButtonEnabled(tabButton, isAllowed, isActive and activeColors[tabKey] or Theme.Colors.Backdrop)
			if ui.Lobby.AdminPages[tabKey] then
				ui.Lobby.AdminPages[tabKey].Visible = isActive
			end
		end
	end

	local function setAdminTab(tabKey)
		local allowedTabs = getAllowedAdminTabs(progression.identity or {})
		if allowedTabs[tabKey] ~= true then
			return
		end
		activeAdminTab = tabKey
		updateAdminTabVisibility()
	end

	local function describeMapVoteError(code)
		if code == "busy" then
			return "Map voting closes once deployment starts."
		end
		if code == "invalid_option" then
			return "That map option is no longer available."
		end
		return "Map vote unavailable."
	end

	local function findShopItem(category, itemId)
		local items = shopCatalog[category] or {}
		for _, item in ipairs(items) do
			if item.Id == itemId then
				return item
			end
		end
		return nil
	end

	local function playerOwnsItem(category, item)
		if type(item) ~= "table" or not item.Id then
			return false
		end
		if category == Theme.ShopTabToCategory.Weapons and progression.equippedWeapon == item.Id then
			return true
		end
		if category == Theme.ShopTabToCategory.Cosmetics and progression.equippedCosmetic == item.Id then
			return true
		end
		local ownedAttribute = ("ShopUnlocked_%s_%s"):format(category, item.Id)
		return player:GetAttribute(ownedAttribute) == true
	end

	local function updateSkillTreeDetailPanel(skillTree)
		local selectedId = selectedSkillTreeNodeId
		local definition = selectedId and SkillTreeConfig.getSkillDefinition(selectedId) or nil
		if not definition then
			ui.Lobby.SkillTreeDetailTitle.Text = "Select a node"
			ui.Lobby.SkillTreeDetailMeta.Text = "Choose a skill card to inspect its branch, rank, and unlock path."
			ui.Lobby.SkillTreeDetailBody.Text = "Detailed skill information appears here."
			ui.Lobby.SkillTreeDetailBonus.Text = "NO NODE"
			ui.Lobby.SkillTreeDetailRank.Text = "Rank --/--"
			ui.Lobby.SkillTreeDetailState.Text = "State: --"
			return
		end

		local currentRank = getSkillRank(skillTree, definition.Id)
		local maxRank = tonumber(definition.MaxRank) or 1
		local prereqDefinition = definition.Prerequisite and SkillTreeConfig.getSkillDefinition(definition.Prerequisite) or nil
		local prereqMet = definition.Prerequisite == nil or getSkillRank(skillTree, definition.Prerequisite) > 0
		local stateText = select(1, getSkillState(definition.Id, definition, currentRank, maxRank, prereqMet, prereqDefinition and prereqDefinition.DisplayName or nil, skillTree.skillPoints or 0, spendingSkillId))
		local branchTheme = getBranchTheme(definition.Branch)
		ui.Lobby.SkillTreeDetailTitle.Text = definition.DisplayName
		ui.Lobby.SkillTreeDetailMeta.Text = ("%s | Tier %d | %s"):format(branchTheme.DisplayName or definition.Branch or "General", tonumber(definition.Tier) or 1, prereqDefinition and ("Requires " .. prereqDefinition.DisplayName) or "Root node")
		ui.Lobby.SkillTreeDetailBody.Text = definition.Description or "No description available."
		ui.Lobby.SkillTreeDetailBonus.Text = definition.BonusLabel or "BONUS"
		ui.Lobby.SkillTreeDetailBonus.BackgroundColor3 = branchTheme.Color or Theme.Colors.AccentWarm
		ui.Lobby.SkillTreeDetailRank.Text = ("Rank %d/%d"):format(currentRank, maxRank)
		ui.Lobby.SkillTreeDetailState.Text = "State: " .. stateText
	end

	local function playCombatSound(weaponId, hitConfirmed, killConfirmed)
		local profile = COMBAT_AUDIO[weaponId] or { volume = 0.16, pitch = 1 }
		if hitConfirmed then
			local hitPitch = killConfirmed and 1.16 or 1.06
			playUiSound(SOUND_IDS.CombatHit, killConfirmed and 0.16 or 0.12, hitPitch)
			return
		end
		playUiSound(SOUND_IDS.CombatShot, profile.volume, profile.pitch)
	end

	local function getCurrentSquadMembers()
		if squadSnapshot and type(squadSnapshot.members) == "table" then
			return squadSnapshot.members
		end
		return {}
	end

	local function queueCameraKick(horizontal, vertical)
		if not screenShakeEnabled then
			return
		end
		cameraKick += Vector2.new(horizontal or 0, vertical or 0)
		cameraKick = Vector2.new(math.clamp(cameraKick.X, -1.8, 1.8), math.clamp(cameraKick.Y, -2.2, 2.2))
	end

	local function updateSettingsControls()
		local uiAudioOn = uiAudioEnabled == true
		local screenShakeOn = screenShakeEnabled == true
		ui.Lobby.ToggleUiAudioButton.Text = uiAudioOn and "UI Audio: On" or "UI Audio: Off"
		ui.Lobby.ToggleScreenShakeButton.Text = screenShakeOn and "Screen Shake: On" or "Screen Shake: Off"
		ui.Lobby.SettingsSummary.Text = ("%s. %s."):format(
			uiAudioOn and "UI audio is active" or "UI audio is muted",
			screenShakeOn and "Screen shake is active" or "Screen shake is disabled"
		)
		setButtonEnabled(ui.Lobby.ToggleUiAudioButton, true, uiAudioOn and Theme.Colors.AccentWarm or Theme.Colors.Backdrop)
		setButtonEnabled(ui.Lobby.ToggleScreenShakeButton, true, screenShakeOn and Color3.fromRGB(86, 122, 176) or Theme.Colors.Backdrop)
	end

	local function updateAdminControls()
		local identity = progression.identity or {}
		local isModerator = identity.isModerator == true or identity.isAdmin == true or identity.isOwner == true
		local isAdmin = identity.isAdmin == true or identity.isOwner == true
		local isOwner = identity.isOwner == true
		local supportBotsAuto = player:GetAttribute("AutoSupportBots") == true
		local targetPlayer = getAdminTargetPlayer()
		local hasTarget = targetPlayer ~= nil
		local hasOtherTarget = hasTarget and targetPlayer ~= player
		if ui.Lobby.AdminButton then
			ui.Lobby.AdminButton.Visible = isModerator
			ui.Lobby.AdminButton.Text = identity.isOwner and "Owner" or (identity.isAdmin and "Admin" or "Mod")
		end
		if ui.Lobby.AdminSummary then
			ui.Lobby.AdminSummary.Text = isModerator and currentAdminStatus or "Owner access unavailable."
		end
		updateAdminTabVisibility()
		if ui.Lobby.AdminEventLabel then
			ui.Lobby.AdminEventLabel.Text = currentAdminEventLabel
		end
		if ui.Lobby.AdminHealButton then
			setButtonEnabled(ui.Lobby.AdminHealButton, isModerator, Color3.fromRGB(94, 156, 108))
			setButtonEnabled(ui.Lobby.AdminHealSquadButton, isAdmin, Color3.fromRGB(82, 146, 118))
			setButtonEnabled(ui.Lobby.AdminTokensButton, isAdmin, Color3.fromRGB(188, 142, 76))
			setButtonEnabled(ui.Lobby.AdminTokensLargeButton, isAdmin, Color3.fromRGB(204, 158, 84))
			setButtonEnabled(ui.Lobby.AdminXpButton, isAdmin, Color3.fromRGB(88, 132, 188))
			setButtonEnabled(ui.Lobby.AdminXpLargeButton, isAdmin, Color3.fromRGB(102, 144, 204))
			setButtonEnabled(ui.Lobby.AdminReviveSquadButton, isAdmin, Color3.fromRGB(92, 168, 132))
			setButtonEnabled(ui.Lobby.AdminReturnButton, isAdmin, Color3.fromRGB(168, 92, 92))
			setButtonEnabled(ui.Lobby.AdminRefreshButton, isModerator, Theme.Colors.Backdrop)
			setButtonEnabled(ui.Lobby.AdminGrantTokensTargetButton, isAdmin and hasOtherTarget, Color3.fromRGB(182, 138, 74))
			setButtonEnabled(ui.Lobby.AdminGrantXpTargetButton, isAdmin and hasOtherTarget, Color3.fromRGB(82, 124, 186))
			setButtonEnabled(ui.Lobby.AdminHealTargetButton, isAdmin and hasTarget, Color3.fromRGB(82, 154, 118))
			setButtonEnabled(ui.Lobby.AdminGrantWeaponsButton, isAdmin and hasOtherTarget, Color3.fromRGB(166, 112, 78))
			setButtonEnabled(ui.Lobby.AdminGrantCosmeticsButton, isAdmin and hasOtherTarget, Color3.fromRGB(122, 94, 172))
			setButtonEnabled(ui.Lobby.AdminTerminateButton, isAdmin and hasOtherTarget, Color3.fromRGB(158, 86, 86))
			setButtonEnabled(ui.Lobby.AdminRoleModButton, isOwner and hasOtherTarget, Color3.fromRGB(86, 118, 188))
			setButtonEnabled(ui.Lobby.AdminRoleAdminButton, isOwner and hasOtherTarget, Color3.fromRGB(122, 96, 188))
			setButtonEnabled(ui.Lobby.AdminRoleClearButton, isOwner and hasOtherTarget, Color3.fromRGB(82, 82, 92))
			setButtonEnabled(ui.Lobby.AdminBanButton, isOwner and hasOtherTarget, Color3.fromRGB(156, 76, 76))
			setButtonEnabled(ui.Lobby.AdminEventAutoButton, isOwner, Theme.Colors.Backdrop)
			setButtonEnabled(ui.Lobby.AdminEventOffButton, isOwner, Color3.fromRGB(126, 78, 78))
			setButtonEnabled(ui.Lobby.AdminEventSpringButton, isOwner, Color3.fromRGB(86, 146, 102))
			setButtonEnabled(ui.Lobby.AdminEventHarvestButton, isOwner, Color3.fromRGB(168, 122, 74))
			setButtonEnabled(ui.Lobby.AdminEventWinterButton, isOwner, Color3.fromRGB(82, 132, 188))
			setButtonEnabled(ui.Lobby.AdminSkipWaveButton, isAdmin, Color3.fromRGB(188, 132, 78))
			setButtonEnabled(ui.Lobby.AdminForceBossButton, isAdmin, Color3.fromRGB(166, 86, 92))
			setButtonEnabled(ui.Lobby.AdminRefillAmmoButton, isAdmin, Color3.fromRGB(82, 128, 188))
			setButtonEnabled(ui.Lobby.AdminTeleportSquadButton, isAdmin, Color3.fromRGB(96, 164, 132))
			setButtonEnabled(ui.Lobby.AdminSpawnBruteButton, isAdmin, Color3.fromRGB(168, 122, 84))
			setButtonEnabled(ui.Lobby.AdminSpawnRunnerButton, isAdmin, Color3.fromRGB(126, 174, 96))
			setButtonEnabled(ui.Lobby.AdminGiveDropsButton, isAdmin, Color3.fromRGB(132, 96, 184))
			setButtonEnabled(ui.Lobby.AdminSpawnSupportBotsButton, isAdmin, Color3.fromRGB(92, 152, 188))
			setButtonEnabled(ui.Lobby.AdminToggleSupportBotsButton, isAdmin, supportBotsAuto and Color3.fromRGB(102, 168, 212) or Color3.fromRGB(88, 118, 168))
			if ui.Lobby.AdminToggleSupportBotsButton then
				ui.Lobby.AdminToggleSupportBotsButton.Text = supportBotsAuto and "Bots Auto: On" or "Bots Auto: Off"
			end
		end
		updateAdminTargetSummary()
		if renderAdminTargetList and ui.Lobby.AdminPopup and ui.Lobby.AdminPopup.Visible then
			renderAdminTargetList()
		end
	end

	local function buildLeaderboardBody(playersList, valueGetter, valueFormatter)
		local entries = {}
		for _, candidate in ipairs(playersList) do
			local value = valueGetter(candidate)
			if value > 0 then
				table.insert(entries, {
					name = candidate.DisplayName or candidate.Name,
					value = value,
				})
			end
		end

		table.sort(entries, function(a, b)
			if a.value == b.value then
				return a.name < b.name
			end
			return a.value > b.value
		end)

		if #entries == 0 then
			return "No data yet."
		end

		local lines = {}
		for index = 1, math.min(4, #entries) do
			local entry = entries[index]
			lines[index] = ("%d. %s\n%s"):format(index, trimLabel(entry.name, 12), valueFormatter(entry.value))
		end
		return table.concat(lines, "\n\n")
	end

	renderLeaderboardBoard = function()
		if not ui.Lobby.LeaderboardSummary then
			return
		end

		local playersList = Players:GetPlayers()
		local playerCount = #playersList
		ui.Lobby.LeaderboardSummary.Text = ("Global Top 100 at Archive Walk. %d operator%s in this server. Use the world board for All Time, Monthly, Weekly, and Daily."):format(
			playerCount,
			playerCount == 1 and "" or "s"
		)
	end

	local function flashHitMarker(color)
		local token = hitMarkerToken + 1
		hitMarkerToken = token
		local marker = ui.Lobby.HitMarker
		marker.Visible = true
		for _, child in ipairs(marker:GetChildren()) do
			if child:IsA("Frame") then
				child.BackgroundColor3 = color
				child.BackgroundTransparency = 0.02
				child.Size = UDim2.new(0, 12, 0, 3)
			end
		end
		task.delay(0.08, function()
			if hitMarkerToken ~= token then
				return
			end
			for _, child in ipairs(marker:GetChildren()) do
				if child:IsA("Frame") then
					child.BackgroundTransparency = 0.36
					child.Size = UDim2.new(0, 9, 0, 2)
				end
			end
		end)
		task.delay(0.14, function()
			if hitMarkerToken == token and marker.Parent then
				marker.Visible = false
			end
		end)
	end

	local function handleCombatFeedback(payload)
		if type(payload) ~= "table" then
			return
		end

	local kind = tostring(payload.kind or "")
	local weaponId = tostring(payload.weaponId or progression.equippedWeapon or "")
	if kind == "shot" then
		local recoil = tonumber(payload.recoil) or 0.14
		local twist = tonumber(payload.twist) or 0.08
			queueCameraKick(twist, recoil)
			playCombatSound(weaponId, false, false)
	elseif kind == "hit" then
		local killConfirmed = payload.kill == true
		local markerColor = killConfirmed and Color3.fromRGB(255, 214, 128) or Color3.fromRGB(255, 255, 255)
		flashHitMarker(markerColor)
		queueCameraKick(0, -0.04)
		playCombatSound(weaponId, true, killConfirmed)
		if state == "Mission" then
			local critical = payload.critical == true
			local damage = math.max(1, tonumber(payload.damage) or 0)
			local damageColor = critical and Color3.fromRGB(255, 212, 104)
				or (killConfirmed and Color3.fromRGB(255, 236, 148) or Color3.fromRGB(238, 242, 255))
			local anchor = getWorldVectorAnchorPosition(payload.hitPosition, critical and 4.8 or 4.2, UDim2.new(0.58, 0, 0.44, 0))
			if damage > 0 then
				spawnFloatingRewardText(tostring(damage), damageColor, {
					position = anchor,
					textSize = critical and 27 or (killConfirmed and 24 or 21),
					rise = critical and 62 or 48,
					lifetime = critical and 0.82 or 0.66,
				})
			end
			if critical then
				spawnFloatingRewardText("CRIT", Color3.fromRGB(255, 162, 76), {
					position = anchor,
					textSize = 18,
					rise = 84,
					lifetime = 0.9,
				})
			elseif killConfirmed then
				spawnFloatingRewardText("DOWN", Color3.fromRGB(255, 226, 128), {
					position = anchor,
					textSize = 16,
					rise = 74,
					lifetime = 0.74,
				})
			end
		end
	end
end

	RunService.RenderStepped:Connect(function(dt)
		if math.abs(cameraKick.X) < 0.001 and math.abs(cameraKick.Y) < 0.001 then
			return
		end

		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		camera.CFrame *= CFrame.Angles(math.rad(-cameraKick.Y), math.rad(cameraKick.X), 0)
		local decay = math.clamp(dt * 14, 0, 1)
		cameraKick = cameraKick:Lerp(Vector2.zero, decay)
	end)

	local function updateSquadSlots()
		local labels = {}
		for _, member in ipairs(getCurrentSquadMembers()) do
			table.insert(labels, formatSquadSlot(member))
		end

		local names = cloneNames(labels)
		for slot = 1, Theme.SquadLimit do
			local label = ui.Lobby.SquadSlots[slot]
			if label then
				label.Text = names[slot] or ("Slot " .. slot)
			end
		end
	end

	local function updateRewardControls()
		ui.Lobby.DailyRewardStatus.Text = formatDailyRewardStatus(dailyRewardState)
		if isClaimingDailyReward then
			ui.Lobby.ClaimDailyButton.Text = "Claiming..."
			setButtonEnabled(ui.Lobby.ClaimDailyButton, false, Theme.Colors.Accent)
			return
		end

		local canClaim = dailyRewardState ~= nil and dailyRewardState.canClaim
		ui.Lobby.ClaimDailyButton.Text = canClaim and "Claim Daily" or "Claim Locked"
		setButtonEnabled(ui.Lobby.ClaimDailyButton, canClaim, Theme.Colors.Accent)
	end

	local function formatWeeklyRewardStatus(stateValue)
		if not stateValue or not stateValue.active then
			return "Supporter access inactive."
		end
		if stateValue.canClaim then
			return "Weekly crate ready for pickup."
		end
		return ("Next weekly crate in %s."):format(formatShortDuration((stateValue.nextClaimAt or 0) - os.time()))
	end

	local function normalizeProgression(payload)
		if type(payload) ~= "table" then
			return nil
		end

		local incomingSkillTree = type(payload.skillTree) == "table" and payload.skillTree or progression.skillTree
		local incomingSubscription = type(payload.subscription) == "table" and payload.subscription or subscriptionState
		return {
			equippedWeapon = tostring(payload.equippedWeapon or progression.equippedWeapon),
			equippedCosmetic = payload.equippedCosmetic and tostring(payload.equippedCosmetic) or nil,
			identity = type(payload.identity) == "table" and payload.identity or progression.identity,
			unlocks = type(payload.unlocks) == "table" and payload.unlocks or progression.unlocks,
			weaponExperience = type(payload.weaponExperience) == "table" and payload.weaponExperience or progression.weaponExperience,
			stats = {
				missionsCompleted = tonumber(payload.stats and payload.stats.missionsCompleted) or 0,
				zombiesDefeated = tonumber(payload.stats and payload.stats.zombiesDefeated) or 0,
			},
			skillTree = {
				level = tonumber(incomingSkillTree.level) or progression.skillTree.level or 1,
				experience = tonumber(incomingSkillTree.experience) or progression.skillTree.experience or 0,
				experienceIntoLevel = tonumber(incomingSkillTree.experienceIntoLevel) or progression.skillTree.experienceIntoLevel or 0,
				experienceForNextLevel = tonumber(incomingSkillTree.experienceForNextLevel) or progression.skillTree.experienceForNextLevel or SkillTreeConfig.getExperienceForNextLevel(1),
				experienceRemaining = tonumber(incomingSkillTree.experienceRemaining) or progression.skillTree.experienceRemaining or 0,
				progressPercent = tonumber(incomingSkillTree.progressPercent) or progression.skillTree.progressPercent or 0,
				skillPoints = tonumber(incomingSkillTree.skillPoints) or progression.skillTree.skillPoints or 0,
				skills = type(incomingSkillTree.skills) == "table" and incomingSkillTree.skills or progression.skillTree.skills,
			},
			subscription = normalizeSubscriptionState(incomingSubscription) or subscriptionState,
		}
	end

	local function updateSquadControls()
		ui.Lobby.SquadSummary.Text = formatSquadSummary(squadSnapshot)
		local memberCount = #getCurrentSquadMembers()
		setButtonEnabled(ui.Lobby.LeaveSquadButton, memberCount > 1, Theme.Colors.Accent)
		ui.Lobby.LeaveSquadButton.Text = memberCount > 1 and "Leave Squad" or "Solo Squad"
		local refreshText = isRefreshingDirectory and "Refreshing..." or "Refresh Board"
		ui.Lobby.RefreshSquadsButton.Text = refreshText
		ui.Lobby.RefreshBoardButton.Text = refreshText
		setButtonEnabled(ui.Lobby.RefreshSquadsButton, not isRefreshingDirectory, Theme.Colors.AccentWarm)
		setButtonEnabled(ui.Lobby.RefreshBoardButton, not isRefreshingDirectory, Theme.Colors.AccentWarm)
		local isLeader = squadSnapshot ~= nil and squadSnapshot.leaderUserId == player.UserId
		local isPrivate = player:GetAttribute("SquadLocked") == true
		ui.Lobby.PrivacySquadButton.Text = isPrivate and "Private Squad: On" or "Private Squad: Off"
		setButtonEnabled(ui.Lobby.PrivacySquadButton, isLeader, isPrivate and Theme.Colors.AccentWarm or Theme.Colors.Backdrop)
		setButtonEnabled(ui.Lobby.InviteSquadButton, isLeader, Theme.Colors.AccentWarm)
	end

	local function updateInvitePopup()
		if not pendingInvite then
			ui.Lobby.InvitePopup:SetAttribute("KeepOpen", false)
			animatePopupFrame(ui.Lobby.InvitePopup, false)
			return
		end

		ui.Lobby.InviteTitle.Text = "Fireteam Invite"
		ui.Lobby.InviteBody.Text = ("%s wants you in their fireteam. Accept to join the squad before the invite expires."):format(
			tostring(pendingInvite.fromLeaderName or "A squad leader")
		)
		ui.Lobby.InvitePopup:SetAttribute("KeepOpen", true)
		animatePopupFrame(ui.Lobby.InvitePopup, true)
	end

	local function updateNpcDialoguePopup()
		if not ui.Lobby.NpcDialoguePopup then
			return
		end
		if not pendingNpcDialogue then
			ui.Lobby.NpcDialoguePopup:SetAttribute("KeepOpen", false)
			animatePopupFrame(ui.Lobby.NpcDialoguePopup, false)
			return
		end

		ui.Lobby.NpcDialogueTitle.Text = tostring(pendingNpcDialogue.title or "Outpost Contact")
		ui.Lobby.NpcDialogueRole.Text = tostring(pendingNpcDialogue.role or "Station lead")
		ui.Lobby.NpcDialogueBody.Text = tostring(pendingNpcDialogue.body or "Local contact update.")
		ui.Lobby.NpcDialogueActionButton.Text = tostring(pendingNpcDialogue.actionLabel or "Open Station")
		ui.Lobby.NpcDialogueActionButton.Visible = type(pendingNpcDialogue.actionPanel) == "string" and pendingNpcDialogue.actionPanel ~= ""
		ui.Lobby.NpcDialoguePopup:SetAttribute("KeepOpen", true)
		animatePopupFrame(ui.Lobby.NpcDialoguePopup, true)
	end

	local function updateRespecPopup()
		if pendingRespecConfirmation then
			ui.Lobby.RespecConfirmPopup:SetAttribute("KeepOpen", true)
			animatePopupFrame(ui.Lobby.RespecConfirmPopup, true)
		else
			ui.Lobby.RespecConfirmPopup:SetAttribute("KeepOpen", false)
			animatePopupFrame(ui.Lobby.RespecConfirmPopup, false)
		end
	end

	local function updateLobbyText()
		local skillTree = progression.skillTree or {}
		local level = skillTree.level or 1
		local skillPoints = skillTree.skillPoints or 0
		local experienceIntoLevel = skillTree.experienceIntoLevel or 0
		local experienceForNextLevel = math.max(1, skillTree.experienceForNextLevel or 1)
		local experienceRemaining = skillTree.experienceRemaining or math.max(0, experienceForNextLevel - experienceIntoLevel)
		local spentSkillPoints = 0
		for _, rank in pairs(skillTree.skills or {}) do
			spentSkillPoints += tonumber(rank) or 0
		end
		ui.Lobby.TokenValue.Text = formatTokenLabel(tokenBalance)
		ui.Lobby.DeployStatus.Text = currentDeployStatus
		local persistenceText = "Saving"
		local lowerPersistenceReason = string.lower(persistenceReason or "")
		if not persistenceOnline then
			if string.find(lowerPersistenceReason, "retry", 1, true) then
				persistenceText = "Retrying"
			elseif string.find(lowerPersistenceReason, "api", 1, true) then
				persistenceText = "Offline"
			else
				persistenceText = "Offline"
			end
		elseif string.find(lowerPersistenceReason, "retry", 1, true) then
			persistenceText = "Retrying"
		end
		ui.Lobby.PersistenceValue.Text = persistenceText
		local persistencePill = ui.Lobby.PersistenceValue.Parent
		if persistencePill then
			persistencePill.BackgroundColor3 = persistenceOnline and Color3.fromRGB(26, 44, 34) or Color3.fromRGB(60, 42, 36)
		end
		if ui.Lobby.SubscriptionValue then
			local isActive = subscriptionState and subscriptionState.isActive == true
			local weeklyReady = subscriptionState and subscriptionState.weeklyRewardAvailable == true
			ui.Lobby.SubscriptionValue.Text = isActive and (weeklyReady and "Supporter Ready" or "Supporter Active") or "Free Access"
			local subscriptionPill = ui.Lobby.SubscriptionValue.Parent
			if subscriptionPill then
				subscriptionPill.BackgroundColor3 = isActive and Color3.fromRGB(50, 54, 34) or Color3.fromRGB(32, 36, 28)
			end
		end
		if ui.Lobby.IdentityValue then
			local identity = progression.identity or {}
			ui.Lobby.IdentityValue.Text = tostring(identity.title or "Survivor")
			local identityPill = ui.Lobby.IdentityValue.Parent
			if identityPill then
				identityPill.BackgroundColor3 = identity.isOwner and Color3.fromRGB(68, 54, 28)
					or (identity.isAdmin and Color3.fromRGB(56, 48, 32) or Color3.fromRGB(36, 40, 46))
			end
		end
		if state == "Mission" then
			ui.Lobby.MissionStatus.Text = ("%s\n%s"):format(missionTelemetry.scenarioName or "Hold The Core", currentDeployStatus)
			ui.Lobby.MissionMeta.Text = ("Wave %d/%d | Core %d%%"):format(
				missionTelemetry.wave or 0,
				missionTelemetry.totalWaves or 0,
				missionTelemetry.objectiveHealthPercent or 100
			)
		else
			local previewModifier = tostring(nextMissionPreview.modifierName or "Standard Ops")
			ui.Lobby.MissionStatus.Text = ("Next Run: %s\n%s [%s]"):format(
				tostring(nextMissionPreview.layoutName or "Breach Yard"),
				tostring(nextMissionPreview.scenarioName or "Hold The Core"),
				previewModifier
			)
			ui.Lobby.MissionMeta.Text = ("%s\nYour squad launches into its own run instance."):format(
				tostring(nextMissionPreview.modifierDescription or nextMissionPreview.layoutDescription or nextMissionPreview.scenarioDescription or "Mission preview pending.")
			)
		end
		ui.Lobby.SocialBody.Text = currentSocialMessage
		ui.Lobby.ShopBody.Text = Theme.ShopCopy[currentShopTab] or Theme.ShopCopy["Deploy Tokens"]
		local weaponName = findShopItem(Theme.ShopTabToCategory.Weapons, progression.equippedWeapon)
		local cosmeticName = progression.equippedCosmetic and findShopItem(Theme.ShopTabToCategory.Cosmetics, progression.equippedCosmetic) or nil
		local weaponDefinition = MissionConfig.getWeaponDefinition(progression.equippedWeapon)
		local weaponExperience = tonumber(progression.weaponExperience and progression.weaponExperience[progression.equippedWeapon]) or 0
		local weaponLevel, weaponXpIntoLevel, weaponXpForNextLevel = MissionConfig.getWeaponLevelFromExperience(weaponExperience)
		local damageBonusRank = getSkillRank(skillTree, "skill_weapons_training")
		local reserveBonusRank = getSkillRank(skillTree, "skill_tactical_reserves")
		local bossBonusRank = getSkillRank(skillTree, "skill_boss_hunter")
		local bonusParts = {}
		if damageBonusRank > 0 then
			table.insert(bonusParts, ("+%d%% dmg"):format(math.floor(damageBonusRank * 8)))
		end
		if reserveBonusRank > 0 then
			table.insert(bonusParts, ("+%d%% reserve"):format(math.floor(reserveBonusRank * 15)))
		end
		if bossBonusRank > 0 then
			table.insert(bonusParts, ("+%d%% boss"):format(math.floor(bossBonusRank * 12)))
		end
		ui.Lobby.LoadoutSummary.Text = ("Weapon: %s | Cosmetic: %s"):format(
			weaponName and weaponName.DisplayName or "Training Blade",
			cosmeticName and cosmeticName.DisplayName or "None"
		)
		ui.Lobby.InventoryLoadoutSummary.Text = ui.Lobby.LoadoutSummary.Text
		ui.Lobby.InventoryWeaponStats.Text = ("Damage: %d | Range: %d | Rate: %.2fs"):format(
			weaponDefinition.Damage or 0,
			weaponDefinition.Range or 0,
			weaponDefinition.Cooldown or 0
		)
		if weaponXpForNextLevel > 0 then
			ui.Lobby.InventoryWeaponXp.Text = ("Bunker XP: %d/%d | %s Lv.%d XP %d/%d"):format(
				experienceIntoLevel,
				experienceForNextLevel,
				weaponDefinition.DisplayName or "Weapon",
				weaponLevel,
				weaponXpIntoLevel,
				weaponXpForNextLevel
			)
		else
			ui.Lobby.InventoryWeaponXp.Text = ("Bunker XP: %d/%d | %s Lv.%d MAX"):format(
				experienceIntoLevel,
				experienceForNextLevel,
				weaponDefinition.DisplayName or "Weapon",
				weaponLevel
			)
		end
		ui.Lobby.InventoryBonusSummary.Text = "Skill Bonus: " .. (#bonusParts > 0 and table.concat(bonusParts, " | ") or "none")
		ui.Lobby.StatsSummary.Text = ("Missions: %d | Kills: %d"):format(
			progression.stats.missionsCompleted or 0,
			progression.stats.zombiesDefeated or 0
		)
		ui.Lobby.InventoryStatsSummary.Text = ui.Lobby.StatsSummary.Text
		ui.Lobby.SkillSummary.Text = ("Bunker Level %d | %d point%s ready | %d XP to next"):format(
			level,
			skillPoints,
			skillPoints == 1 and "" or "s",
			experienceRemaining
		)
		ui.Lobby.InventorySkillSummary.Text = ui.Lobby.SkillSummary.Text
		ui.Lobby.SkillTreeSummary.Text = ("Level %d | XP %d/%d | %d point%s ready"):format(
			level,
			experienceIntoLevel,
			experienceForNextLevel,
			skillPoints,
			skillPoints == 1 and "" or "s"
		)
		ui.Lobby.SkillTreeStatus.Text = currentSkillTreeStatus
		if ui.Lobby.SkillTreePaneTitle then
			ui.Lobby.SkillTreePaneTitle.Text = currentSkillTreeBranchFilter == "All"
				and "Branch Nodes"
				or (((Theme.SkillTreeBranches[currentSkillTreeBranchFilter] and Theme.SkillTreeBranches[currentSkillTreeBranchFilter].DisplayName) or currentSkillTreeBranchFilter) .. " Nodes")
		end
		if ui.Lobby.SkillTreePaneSub then
			ui.Lobby.SkillTreePaneSub.Text = currentSkillTreeBranchFilter == "All"
				and "Filter by branch to focus one lane, or keep all branches visible."
				or "Focused branch view. Switch filters to inspect another specialization lane."
		end
		setButtonEnabled(ui.Lobby.RespecSkillTreeButton, spentSkillPoints > 0, Theme.Colors.AccentWarm)
		local ammoText = "--"
		if missionTelemetry.ammo ~= nil then
			ammoText = ("%d/%d"):format(missionTelemetry.ammo or 0, missionTelemetry.reserveAmmo or 0)
		end
		if state == "Mission" then
			ui.Lobby.MissionLoadout.Text = ("Loadout: %s | Ammo: %s"):format(weaponName and weaponName.DisplayName or "Training Blade", ammoText)
		else
			ui.Lobby.MissionLoadout.Text = "Your squad deploys into its own run instance."
		end
		if ui.Lobby.MissionVoteLabel then
			local showVoteUi = state ~= "Mission" and #nextMissionVoteOptions > 0
			ui.Lobby.MissionVoteLabel.Visible = showVoteUi
			ui.Lobby.MissionVoteLabel.Text = currentVoteOptionId and "Route selected. You can still change it before deploy." or "Pick your squad's next run:"
			for index, button in ipairs(ui.Lobby.MissionVoteButtons or {}) do
				local option = nextMissionVoteOptions[index]
				button.Visible = showVoteUi and option ~= nil
				if option then
					local isLeading = option.optionId == leadingMissionVoteOptionId
					local isSelected = option.optionId == currentVoteOptionId
					local accentColor = isSelected and Color3.fromRGB(228, 178, 96) or (isLeading and Color3.fromRGB(96, 144, 216) or Theme.Colors.Backdrop)
					local modifierName = trimLabel(option.modifierName or "Standard Ops", 18)
					local voteCount = tonumber(option.voteCount) or 0
					button.Text = ("%s\n%s\n%s\n%d vote%s%s"):format(
						trimLabel(option.layoutName or "Map", 18),
						trimLabel(option.scenarioName or "Directive", 22),
						modifierName,
						voteCount,
						voteCount == 1 and "" or "s",
						isSelected and " | YOUR PICK" or (isLeading and " | LEADING" or "")
					)
					button:SetAttribute("VoteOptionId", option.optionId)
					setButtonEnabled(button, showVoteUi, accentColor)
				end
			end
		end
		local seasonalText = seasonalEventState and (" | Event: " .. tostring(seasonalEventState.DisplayName or seasonalEventState.Id)) or ""
		ui.Lobby.ShopStatus.Text = currentShopStatus .. seasonalText
		ui.Lobby.InventoryStatus.Text = currentInventoryStatus
		ui.Lobby.LobbyStatus.Text = currentDeployStatus
		if ui.Lobby.DailyQuestStatus then
			ui.Lobby.DailyQuestStatus.Text = formatDailyRewardStatus(dailyRewardState)
		end
		if ui.Lobby.WeeklyQuestStatus then
			ui.Lobby.WeeklyQuestStatus.Text = formatWeeklyRewardStatus(weeklyRewardState)
		end
		if ui.Lobby.QuestBoardSummary then
			local resetText = dailyOpsState and dailyOpsState.nextResetAt > 0
				and ("Daily ops reset in " .. formatShortDuration((dailyOpsState.nextResetAt or 0) - os.time()) .. ".")
				or "Daily ops reset on the next server cycle."
			ui.Lobby.QuestBoardSummary.Text = (weeklyRewardState and weeklyRewardState.active
				and "Daily stipend, daily ops, and weekly supporter crate are all tracked here. "
				or "Daily stipend and daily ops are available to everyone. Weekly crates unlock with supporter access. ")
				.. resetText
		end
		if ui.Lobby.ClaimDailyQuestButton then
			local canClaimDaily = dailyRewardState ~= nil and dailyRewardState.canClaim
			ui.Lobby.ClaimDailyQuestButton.Text = canClaimDaily and "Claim Daily" or "Daily Locked"
			setButtonEnabled(ui.Lobby.ClaimDailyQuestButton, canClaimDaily and not isClaimingDailyReward, Theme.Colors.AccentWarm)
		end
		if ui.Lobby.ClaimWeeklyQuestButton then
			local canClaimWeekly = weeklyRewardState ~= nil and weeklyRewardState.canClaim
			ui.Lobby.ClaimWeeklyQuestButton.Text = canClaimWeekly and "Claim Weekly" or "Weekly Locked"
			setButtonEnabled(ui.Lobby.ClaimWeeklyQuestButton, canClaimWeekly, Color3.fromRGB(180, 154, 86))
		end
		updateSquadSlots()
		updateRewardControls()
		updateSquadControls()
		if renderShopItems then
			renderShopItems()
		end
		if renderInventoryItems then
			renderInventoryItems()
		end
		if renderSkillTreeItems then
			renderSkillTreeItems()
		end
		updateSkillTreeDetailPanel(skillTree)
		if renderSquadDirectory then
			renderSquadDirectory()
		end
		if renderInvitePlayerList then
			renderInvitePlayerList()
		end
		if renderDailyOpsItems then
			renderDailyOpsItems()
		end
		if renderLeaderboardBoard then
			renderLeaderboardBoard()
		end
		updateInvitePopup()
		updateNpcDialoguePopup()
		updateRespecPopup()
		updateSettingsControls()
		updateAdminControls()

		for name, button in pairs(ui.Lobby.ShopTabs) do
			local isCurrent = name == currentShopTab
			setButtonEnabled(button, true, isCurrent and Theme.Colors.AccentWarm or Theme.Colors.Backdrop)
		end
		if ui.Lobby.ShopRarityButtons then
			for filterName, button in pairs(ui.Lobby.ShopRarityButtons) do
				local _, color = getRarityStyle(filterName == "All" and "Legendary" or filterName)
				setButtonEnabled(button, true, currentShopRarityFilter == filterName and (filterName == "All" and Theme.Colors.AccentWarm or color) or Theme.Colors.Backdrop)
			end
		end
		if ui.Lobby.ShopPremiumFilters then
			ui.Lobby.ShopPremiumFilters.Visible = currentShopTab == "Deploy Tokens"
		end
		if ui.Lobby.ShopPremiumFilterLabel then
			ui.Lobby.ShopPremiumFilterLabel.Visible = currentShopTab == "Deploy Tokens"
		end
		if ui.Lobby.ShopPremiumButtons then
			for filterName, button in pairs(ui.Lobby.ShopPremiumButtons) do
				local activeColor = filterName == "Packs" and Color3.fromRGB(104, 214, 164)
					or (filterName == "Passes" and Color3.fromRGB(104, 168, 232)
					or (filterName == "Supporter" and Color3.fromRGB(214, 182, 96) or Theme.Colors.AccentWarm))
				setButtonEnabled(button, true, currentShopPremiumFilter == filterName and activeColor or Theme.Colors.Backdrop)
			end
		end
		if ui.Lobby.InventoryRarityButtons then
			for filterName, button in pairs(ui.Lobby.InventoryRarityButtons) do
				local _, color = getRarityStyle(filterName == "All" and "Legendary" or filterName)
				setButtonEnabled(button, true, currentInventoryRarityFilter == filterName and (filterName == "All" and Theme.Colors.AccentWarm or color) or Theme.Colors.Backdrop)
			end
		end
		if ui.Lobby.SkillTreeFilterButtons then
			for filterName, button in pairs(ui.Lobby.SkillTreeFilterButtons) do
				local branchTheme = Theme.SkillTreeBranches[filterName]
				local activeColor = filterName == "All"
					and Theme.Colors.AccentWarm
					or ((branchTheme and branchTheme.Color) or Theme.Colors.Backdrop)
				setButtonEnabled(button, true, currentSkillTreeBranchFilter == filterName and activeColor or Theme.Colors.Backdrop)
			end
		end
		setButtonEnabled(ui.Lobby.InventoryWeaponTab, true, currentInventoryTab == "Weapons" and Color3.fromRGB(92, 122, 176) or Theme.Colors.Backdrop)
		setButtonEnabled(ui.Lobby.InventoryCosmeticTab, true, currentInventoryTab == "Cosmetics" and Color3.fromRGB(84, 128, 184) or Theme.Colors.Backdrop)
	end

	local function setWorldHudMode()
		ui.Root.BackgroundTransparency = 1
		if ui.RootGradient then
			ui.RootGradient.Enabled = false
		end
	end

	local function updateHudVisibility()
		local inMission = state == "Mission"
			or player:GetAttribute("InMission") == true
		local missionPanelOpen = ui.Lobby.MissionPanel and ui.Lobby.MissionPanel.Visible == true
		if ui.Lobby.HudBar then
			ui.Lobby.HudBar.Visible = not inMission
		end
		if ui.Lobby.QuickAccessBar then
			ui.Lobby.QuickAccessBar.Visible = (not inMission) and activePopup == nil
		end
		if ui.Lobby.MissionToastStack then
			ui.Lobby.MissionToastStack.Visible = inMission
		end
		if ui.Lobby.RewardFloatLayer then
			ui.Lobby.RewardFloatLayer.Visible = inMission
		end
		if ui.Lobby.LeaderboardBoard then
			ui.Lobby.LeaderboardBoard.Visible = (not inMission) and activePopup == nil and (not missionPanelOpen)
		end
		if not inMission and next(suppressedMissionPrompts) ~= nil then
			for prompt in pairs(suppressedMissionPrompts) do
				if prompt and prompt.Parent then
					prompt.Enabled = true
				end
			end
			table.clear(suppressedMissionPrompts)
		end
	end

	local function pushMissionToast(titleText, bodyText, accentColor, isComplete, rewardText)
		if not ui.Lobby.MissionToastStack then
			return
		end

		missionToastNonce += 1
		local toastId = missionToastNonce
		local card = new("Frame", {
			Name = "Toast_" .. toastId,
			BackgroundColor3 = isComplete and Color3.fromRGB(34, 42, 28) or Color3.fromRGB(20, 24, 30),
			BackgroundTransparency = 0.04,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 62),
			Parent = ui.Lobby.MissionToastStack,
		})
		addCorner(card, UDim.new(0, 14))
		addStroke(card, accentColor or Theme.Colors.AccentWarm, 0.16, 1)

		local rail = new("Frame", {
			Name = "AccentRail",
			BackgroundColor3 = accentColor or Theme.Colors.AccentWarm,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 4, 1, 0),
			Parent = card,
		})
		addCorner(rail, UDim.new(0, 4))

		local title = new("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 14, 0, 9),
			Size = UDim2.new(1, -28, 0, 18),
			Text = titleText,
			TextColor3 = Theme.Colors.Text,
			TextScaled = false,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Theme.Fonts.Heading,
			Parent = card,
		})

		local body = new("TextLabel", {
			Name = "Body",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 14, 0, 29),
			Size = UDim2.new(1, isComplete and -116 or -28, 0, 22),
			Text = bodyText,
			TextColor3 = Theme.Colors.Muted,
			TextScaled = false,
			TextSize = 11,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Theme.Fonts.Body,
			Parent = card,
		})

		if isComplete and type(rewardText) == "string" and rewardText ~= "" then
			local rewardChip = new("TextLabel", {
				Name = "RewardChip",
				BackgroundColor3 = accentColor or Theme.Colors.AccentWarm,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.new(0, 88, 0, 24),
				Text = rewardText,
				TextColor3 = Color3.fromRGB(18, 22, 18),
				TextScaled = false,
				TextSize = 10,
				Font = Theme.Fonts.Heading,
				Parent = card,
			})
			addCorner(rewardChip, UDim.new(0, 10))
		end

		card.BackgroundTransparency = 1
		card.Position = UDim2.new(0, 18, 0, 0)
		local scaleDriver = new("UIScale", {
			Scale = isComplete and 0.92 or 0.97,
			Parent = card,
		})
		TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.04,
			Position = UDim2.new(0, 0, 0, 0),
		}):Play()
		TweenService:Create(scaleDriver, TweenInfo.new(isComplete and 0.24 or 0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()

		playUiSound(isComplete and SOUND_IDS.Success or SOUND_IDS.Alert, isComplete and 0.32 or 0.2, isComplete and 1.12 or 1.06)

		if isComplete then
			local flash = new("Frame", {
				Name = "CompleteFlash",
				BackgroundColor3 = accentColor or Theme.Colors.AccentWarm,
				BackgroundTransparency = 0.78,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 1, 0),
				Parent = card,
			})
			addCorner(flash, UDim.new(0, 14))
			TweenService:Create(flash, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}):Play()
			task.delay(0.3, function()
				if flash.Parent then
					flash:Destroy()
				end
			end)
		end

		task.delay(3.6, function()
			if not card.Parent then
				return
			end
			TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 18, 0, 0),
			}):Play()
			task.delay(0.2, function()
				if card.Parent then
					card:Destroy()
				end
			end)
		end)

		local children = ui.Lobby.MissionToastStack:GetChildren()
		local cards = {}
		for _, child in ipairs(children) do
			if child:IsA("Frame") and child ~= rail then
				table.insert(cards, child)
			end
		end
		if #cards > 4 then
			table.sort(cards, function(a, b)
				return a.Name < b.Name
			end)
			if cards[1] and cards[1] ~= card then
				cards[1]:Destroy()
			end
		end
	end

	local function setFullscreenMode()
		ui.Root.BackgroundTransparency = 0
		if ui.RootGradient then
			ui.RootGradient.Enabled = true
		end
	end

	local function setActivePopup(name)
		local previousActive = activePopup
		activePopup = name
		for popupName, popup in pairs(ui.Lobby.Popups) do
			local isActive = popupName == name
			popup:SetAttribute("KeepOpen", isActive)
			animatePopupFrame(popup, isActive)
		end
		updateHudVisibility()
		if name and previousActive ~= name then
			playUiSound(SOUND_IDS.UiOpen, 0.4, 1.02)
		elseif not name and previousActive then
			playUiSound(SOUND_IDS.UiClose, 0.32, 1)
		end
	end

	local function hideResultsPopup()
		ui.Lobby.ResultsPopup:SetAttribute("KeepOpen", false)
		animatePopupFrame(ui.Lobby.ResultsPopup, false)
	end

	local function showResultsPopup(payload)
		if type(payload) ~= "table" then
			return
		end
		pendingResults = payload
		ui.Lobby.ResultsOutcome.Text = payload.success and "SUCCESS" or "FAILED"
		ui.Lobby.ResultsOutcome.TextColor3 = payload.success and Theme.Colors.Accent or Color3.fromRGB(255, 132, 132)
		ui.Lobby.ResultsSummary.Text = tostring(payload.summary or "Run complete.")
		ui.Lobby.ResultsReward.Text = ("+%d Deploy Tokens"):format(tonumber(payload.rewardTokens) or 0)
		ui.Lobby.ResultsStats.Scenario.Text = "Scenario: " .. tostring(payload.scenarioName or "--")
		ui.Lobby.ResultsStats.Layout.Text = "Layout: " .. tostring(payload.layoutName or "--")
		ui.Lobby.ResultsStats.Waves.Text = ("Waves: %d/%d"):format(tonumber(payload.wave) or 0, tonumber(payload.totalWaves) or 0)
		ui.Lobby.ResultsStats.Kills.Text = "Kills: " .. tostring(payload.kills or 0)
		ui.Lobby.ResultsStats.Tokens.Text = "Tokens: +" .. tostring(payload.rewardTokens or 0)
		ui.Lobby.ResultsStats.XP.Text = "XP: +" .. tostring(payload.xpGained or 0)
		ui.Lobby.ResultsStats.Level.Text = ("Level: %d | Points Ready: %d"):format(tonumber(payload.level) or 1, tonumber(payload.skillPoints) or 0)
		local breakdown = type(payload.xpBreakdown) == "table" and payload.xpBreakdown or {}
		ui.Lobby.ResultsXpBreakdown.Text = ("XP Breakdown:\nKills: +%d XP\nWaves: +%d XP\nSuccess/Fail: +%d XP"):format(
			tonumber(breakdown.ZombieKill) or 0,
			tonumber(breakdown.WaveClear) or 0,
			(tonumber(breakdown.MissionComplete) or 0) + (tonumber(breakdown.MissionFailure) or 0)
		)
		local dailyOpsEntries = type(payload.dailyOps) == "table" and payload.dailyOps or {}
		local dailyOpsLines = {}
		for _, entry in ipairs(dailyOpsEntries) do
			if type(entry) == "table" then
				local name = tostring(entry.displayName or entry.DisplayName or "Daily Op")
				local progress = tonumber(entry.progress or entry.Progress) or 0
				local goal = math.max(1, tonumber(entry.goal or entry.Goal) or 1)
				local claimed = entry.claimed == true or entry.Claimed == true
				local marker = claimed and "Claimed" or (((entry.canClaim == true or entry.CanClaim == true) and "Ready") or "Tracking")
				table.insert(dailyOpsLines, ("%s: %d/%d %s"):format(name, progress, goal, marker))
			end
		end
		ui.Lobby.ResultsDailyOps.Text = "Daily Ops:\n" .. (#dailyOpsLines > 0 and table.concat(dailyOpsLines, "\n") or "No tracked progress this run.")
		ui.Lobby.ResultsPopup:SetAttribute("KeepOpen", true)
		animatePopupFrame(ui.Lobby.ResultsPopup, true)
		playUiSound(payload.success and SOUND_IDS.Success or SOUND_IDS.Alert, 0.45, payload.success and 1.03 or 0.94)
	end

	local function openStationPanel(panelName)
		if state ~= "Lobby" then
			return
		end

		panelName = normalizeStationPanelName(panelName)
		if not panelName then
			return
		end

		if panelName == "Shop" then
			setActivePopup("Shop")
			currentShopStatus = Theme.ShopCopy[currentShopTab] or currentShopStatus
			updateLobbyText()
			return
		end

		if panelName == "Inventory" then
			setInventoryTab("Weapons")
			setActivePopup("Inventory")
			updateLobbyText()
			return
		end

		if panelName == "SkillTree" then
			setActivePopup("SkillTree")
			currentSkillTreeStatus = "Allocate points to unlock deeper branch nodes."
			updateLobbyText()
			return
		end

		if panelName == "QuestBoard" then
			setActivePopup("QuestBoard")
			refreshDailyRewardState()
			refreshDailyOpsState()
			refreshWeeklyRewardState()
			refreshSubscriptionState()
			updateLobbyText()
			return
		end

		if panelName == "Squad" or panelName == "Social" then
			setActivePopup(panelName)
			refreshSquadDirectory()
			if panelName == "Social" then
				refreshInviteablePlayers()
				currentSocialMessage = "Browse squads, invite survivors, and team up from the bunker board."
			end
			updateLobbyText()
		end
	end

	local function enterHome()
		state = "Home"
		ui.Root.Visible = true
		setFullscreenMode()
		CinematicController.stop(ui.Root)
		restoreCameraToPlayer(player)
		setActivePopup(nil)
		currentDeployStatus = Theme.StatusCopy.Home
		ui.Lobby.MissionPanel.Visible = false
		currentSocialMessage = Theme.LobbyBlurb
		if promptTween then
			promptTween:Cancel()
			promptTween = nil
		end
		setPageVisibility(ui, "Home")
		animateHomeScreen(true)
		updateHudVisibility()
	end

	local function enterLoading(message, waitForInput)
		state = "Loading"
		ui.Root.Visible = true
		setFullscreenMode()
		CinematicController.stop(ui.Root)
		cancelHomeAnimations()
		setActivePopup(nil)
		loadingStartedAt = os.clock()
		awaitingContinuePrompt = waitForInput == true
		currentDeployStatus = message or Theme.StatusCopy.Loading
		ui.Lobby.MissionPanel.Visible = false
		ui.Loading.Prompt.Text = awaitingContinuePrompt and Theme.LoadingPrompt or "Synchronizing deployment..."
		ui.Loading.Status.Text = currentDeployStatus
		ui.Lobby.LobbyStatus.Text = currentDeployStatus
		if promptTween then
			promptTween:Cancel()
		end
		promptTween = TweenService:Create(ui.Loading.Prompt, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			TextTransparency = 0.2,
		})
		promptTween:Play()
		setPageVisibility(ui, "Loading")
		updateHudVisibility()
		playUiSound(SOUND_IDS.Deploy, 0.35, 1)
		local loadingScale = ui.Loading.Panel:FindFirstChild("ScaleDriver")
		if loadingScale then
			loadingScale.Scale = 0.965
			TweenService:Create(loadingScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end

		if awaitingContinuePrompt then
			task.delay(1.25, function()
				if state == "Loading" and awaitingContinuePrompt then
					enterLobby()
					refreshDailyRewardState()
					refreshShopCatalog()
					refreshSquadDirectory()
				end
			end)
		end
	end

	enterLobby = function(message)
		state = "Lobby"
		ui.Root.Visible = true
		setWorldHudMode()
		CinematicController.stop(ui.Root)
		cancelHomeAnimations()
		restoreCameraToPlayer(player)
		setActivePopup(nil)
		awaitingContinuePrompt = false
		currentDeployStatus = message or Theme.StatusCopy.Lobby
		ui.Lobby.MissionPanel.Visible = false
		ui.Loading.Status.Text = currentDeployStatus
		ui.Lobby.LobbyStatus.Text = currentDeployStatus
		if promptTween then
			promptTween:Cancel()
			promptTween = nil
		end
		setPageVisibility(ui, "Lobby")
		updateHudVisibility()
		updateLobbyText()
		if pendingResults then
			task.delay(0.12, function()
				if state == "Lobby" and pendingResults then
					showResultsPopup(pendingResults)
				end
			end)
		end
	end

	local function enterMission(message)
		state = "Mission"
		awaitingContinuePrompt = false
		currentDeployStatus = message or "Mission staging ready."
		setActivePopup(nil)
		if promptTween then
			promptTween:Cancel()
			promptTween = nil
		end
		ui.Root.Visible = true
		setWorldHudMode()
		cancelHomeAnimations()
		restoreCameraToPlayer(player)
		setPageVisibility(ui, "Lobby")
		ui.Lobby.MissionPanel.Visible = true
		updateHudVisibility()
		updateLobbyText()
	end

	local function enforceUiState()
		if state == "Home" then
			ui.Root.Visible = true
			setFullscreenMode()
			if not ui.Pages.Home.Visible then
				setPageVisibility(ui, "Home")
			end
		elseif state == "Loading" then
			ui.Root.Visible = true
			setFullscreenMode()
			if not ui.Pages.Loading.Visible then
				setPageVisibility(ui, "Loading")
			end
		elseif state == "Lobby" then
			ui.Root.Visible = true
			setWorldHudMode()
			if not ui.Pages.Lobby.Visible then
				setPageVisibility(ui, "Lobby")
			end
		elseif state == "Mission" then
			ui.Root.Visible = true
			setWorldHudMode()
			if not ui.Pages.Lobby.Visible then
				setPageVisibility(ui, "Lobby")
			end
			ui.Lobby.MissionPanel.Visible = true
		end

		updateHudVisibility()

		if state ~= "Mission" and state ~= "Loading" and CinematicController.isPlaying() then
			CinematicController.stop(ui.Root)
		end
	end

	local function setShopTab(tabName)
		tabName = normalizeShopTab(tabName)
		if Theme.ShopCopy[tabName] then
			currentShopTab = tabName
			currentShopStatus = Theme.ShopCopy[tabName]
			updateLobbyText()
		end
	end

	local function setInventoryTab(tabName)
		if tabName ~= "Weapons" and tabName ~= "Cosmetics" then
			return
		end
		currentInventoryTab = tabName
		currentInventoryStatus = tabName == "Weapons"
			and "Owned weapons are listed here. Equip the one you want for the next run."
			or "Owned cosmetics are listed here. Equip one to change your bunker look."
		updateLobbyText()
	end

	local function setTokenValue(value)
		if type(value) == "table" and value.userId and value.userId ~= player.UserId then
			return
		end

		local payload = type(value) == "table" and value or nil
		local previousBalance = tokenBalance
		if typeof(value) == "number" then
			tokenBalance = value
		elseif type(value) == "table" then
			tokenBalance = tonumber(value.tokens or value.balance or value.amount or tokenBalance) or tokenBalance
		end

		if payload then
			local delta = tonumber(payload.delta) or (tokenBalance - previousBalance)
			local source = tostring(payload.source or "")
			local reason = tostring(payload.reason or "")
			if delta > 0 and source == "MissionReward" and ui.Lobby.TokenValue and ui.Lobby.TokenValue.Parent then
				local accent = Theme.Colors.AccentWarm
				if reason == "salvage_pickup" then
					accent = Color3.fromRGB(228, 188, 112)
				elseif reason == "wave_clear" then
					accent = Color3.fromRGB(122, 170, 220)
				elseif reason == "mission_complete" then
					accent = Color3.fromRGB(188, 214, 128)
				end
				pulseGuiObject(ui.Lobby.TokenValue.Parent, accent)
				if state == "Mission" then
					local rewardAnchor = (reason == "salvage_pickup" or reason == "wave_clear" or reason == "mission_complete")
						and getMissionObjectiveRewardAnchor(reason)
						or nil
					spawnFloatingRewardText(("+%dT"):format(delta), accent, {
						position = rewardAnchor,
						textSize = 22,
						rise = reason == "mission_complete" and 58 or 46,
					})
					local title = reason == "salvage_pickup" and "Salvage Secured"
						or (reason == "wave_clear" and "Wave Reward" or (reason == "mission_complete" and "Mission Reward" or "Reward Added"))
					pushMissionToast(title, ("+%d Deploy Tokens"):format(delta), accent, reason == "mission_complete", nil)
				end
			end
		end
		updateLobbyText()
	end

	local function setDailyRewardValue(value)
		local normalized = normalizeDailyRewardState(value)
		if normalized then
			dailyRewardState = normalized
			updateLobbyText()
		end
	end

	local function setWeeklyRewardValue(value)
		local normalized = normalizeWeeklyRewardState(value)
		if normalized then
			weeklyRewardState = normalized
			updateLobbyText()
		end
	end

	local function setDailyOpsValue(value)
		local normalized = normalizeDailyOpsState(value)
		if normalized then
			dailyOpsState = normalized
			updateLobbyText()
		end
	end

	local function setSeasonalEventValue(value)
		seasonalEventState = type(value) == "table" and value or nil
		updateLobbyText()
	end

	local function setShopCatalogValue(value)
		if type(value) ~= "table" then
			return
		end

		shopCatalog = value
		updateLobbyText()
	end

	local function setProgressionValue(value)
		local normalized = normalizeProgression(value)
		if normalized then
			local previousSkillTree = progression.skillTree or {}
			local previousLevel = tonumber(previousSkillTree.level) or 1
			local previousXp = tonumber(previousSkillTree.experienceIntoLevel) or 0
			local previousTotalXp = getSkillTreeTotalExperience(previousSkillTree)
			local previousWeaponId = tostring(progression.equippedWeapon or "")
			local previousWeaponExperience = tonumber(progression.weaponExperience and progression.weaponExperience[previousWeaponId]) or 0
			local previousWeaponLevel = MissionConfig.getWeaponLevelFromExperience(previousWeaponExperience)
			progression = normalized
			if normalized.subscription then
				subscriptionState = normalized.subscription
			end
			local nextSkillTree = normalized.skillTree or {}
			local nextLevel = tonumber(nextSkillTree.level) or previousLevel
			local nextXp = tonumber(nextSkillTree.experienceIntoLevel) or previousXp
			local nextTotalXp = getSkillTreeTotalExperience(nextSkillTree)
			local leveledUp = nextLevel > previousLevel
			local gainedXp = leveledUp or nextXp > previousXp
			if gainedXp then
				local xpDelta = math.max(0, nextTotalXp - previousTotalXp)
				local accent = leveledUp and Color3.fromRGB(188, 214, 128) or Color3.fromRGB(122, 170, 220)
				if ui.Lobby.SkillSummary then
					pulseGuiObject(ui.Lobby.SkillSummary, accent)
				end
				if ui.Lobby.InventorySkillSummary then
					pulseGuiObject(ui.Lobby.InventorySkillSummary, accent)
				end
				if ui.Lobby.SkillTreeSummary then
					pulseGuiObject(ui.Lobby.SkillTreeSummary, accent)
				end
				if state == "Mission" then
					if xpDelta > 0 then
						spawnFloatingRewardText(("+%d XP"):format(xpDelta), accent, {
							position = UDim2.new(0.5, 0, 0.56, 0),
							textSize = leveledUp and 24 or 20,
							rise = leveledUp and 58 or 48,
						})
					end
					local title = leveledUp and "Bunker Level Up" or "XP Gained"
					local body = leveledUp
						and ("Level %d reached • %d point%s ready"):format(
							nextLevel,
							tonumber(nextSkillTree.skillPoints) or 0,
							(tonumber(nextSkillTree.skillPoints) or 0) == 1 and "" or "s"
						)
						or ("Bunker XP %d/%d"):format(
							nextXp,
							tonumber(nextSkillTree.experienceForNextLevel) or 1
						)
					pushMissionToast(title, body, accent, leveledUp, nil)
				end
			end
			local nextWeaponId = tostring(normalized.equippedWeapon or "")
			local nextWeaponExperience = tonumber(normalized.weaponExperience and normalized.weaponExperience[nextWeaponId]) or 0
			local nextWeaponLevel, nextWeaponXpIntoLevel, nextWeaponXpForNextLevel = MissionConfig.getWeaponLevelFromExperience(nextWeaponExperience)
			if nextWeaponId ~= "" and nextWeaponId == previousWeaponId and nextWeaponExperience > previousWeaponExperience then
				local weaponXpDelta = nextWeaponExperience - previousWeaponExperience
				local weaponAccent = nextWeaponLevel > previousWeaponLevel and Color3.fromRGB(232, 196, 118) or Color3.fromRGB(122, 170, 220)
				if ui.Lobby.InventoryWeaponXp then
					pulseGuiObject(ui.Lobby.InventoryWeaponXp, weaponAccent)
				end
				if state == "Mission" then
					spawnFloatingRewardText(("+%d WXP"):format(weaponXpDelta), weaponAccent, {
						position = UDim2.new(0.5, 0, 0.68, 0),
						textSize = nextWeaponLevel > previousWeaponLevel and 23 or 19,
						rise = nextWeaponLevel > previousWeaponLevel and 56 or 44,
					})
					local weaponDefinition = MissionConfig.getWeaponDefinition(nextWeaponId)
					local title = nextWeaponLevel > previousWeaponLevel and "Weapon Level Up" or "Weapon XP"
					local body = nextWeaponLevel > previousWeaponLevel
						and ("%s Lv.%d • +%d XP"):format(weaponDefinition.DisplayName or "Weapon", nextWeaponLevel, weaponXpDelta)
						or ("%s +%d XP • %d/%d"):format(
							weaponDefinition.DisplayName or "Weapon",
							weaponXpDelta,
							nextWeaponXpIntoLevel,
							math.max(1, nextWeaponXpForNextLevel)
						)
					pushMissionToast(title, body, weaponAccent, nextWeaponLevel > previousWeaponLevel, nil)
				end
			end
			updateLobbyText()
		end
	end

	local function setPersistenceStateValue(value)
		if type(value) == "table" then
			persistenceOnline = value.enabled == true
			if value.reason ~= nil then
				persistenceReason = tostring(value.reason)
			end
			updateLobbyText()
		end
	end

	local function setSubscriptionStateValue(value)
		local normalized = normalizeSubscriptionState(value)
		if normalized then
			subscriptionState = normalized
			updateLobbyText()
		end
	end

	local function setMissionTelemetryValue(payload)
		if type(payload) ~= "table" then
			return
		end

		missionTelemetry.phase = tostring(payload.missionPhase or missionTelemetry.phase)
		missionTelemetry.scenarioName = tostring(payload.scenarioName or missionTelemetry.scenarioName)
		missionTelemetry.scenarioDescription = tostring(payload.scenarioDescription or missionTelemetry.scenarioDescription)
		missionTelemetry.wave = tonumber(payload.wave or missionTelemetry.wave) or 0
		missionTelemetry.totalWaves = tonumber(payload.totalWaves or missionTelemetry.totalWaves) or 0
		missionTelemetry.objectiveHealthPercent = tonumber(payload.objectiveHealthPercent or missionTelemetry.objectiveHealthPercent) or 100
		if payload.currentAmmo ~= nil then
			missionTelemetry.ammo = tonumber(payload.currentAmmo)
		end
		if payload.reserveAmmo ~= nil then
			missionTelemetry.reserveAmmo = tonumber(payload.reserveAmmo)
		end
		local statusText = tostring(payload.status or "")
		if string.find(statusText, "Core integrity", 1, true) or string.find(statusText, "Warning", 1, true) then
			playUiSound(SOUND_IDS.Alert, 0.28, 0.98)
		end
		updateLobbyText()
	end

	local function setSquadDirectoryValue(value)
		squadDirectory = normalizeSquadDirectory(value)
		updateLobbyText()
	end

	local function setInviteablePlayersValue(value)
		inviteablePlayers = normalizeInviteablePlayers(value)
		updateLobbyText()
	end

	local function setSquadValue(value)
		local normalized = normalizeSquadSnapshot(value)
		if not normalized then
			squadSnapshot = nil
			updateLobbyText()
			return
		end

		local includesLocalPlayer = false
		for _, member in ipairs(normalized.members) do
			if member.userId == player.UserId then
				includesLocalPlayer = true
				break
			end
		end
		if not includesLocalPlayer then
			return
		end

		squadSnapshot = normalized
		updateLobbyText()
		if refreshSquadDirectory then
			task.defer(refreshSquadDirectory)
		end
		if refreshInviteablePlayers then
			task.defer(refreshInviteablePlayers)
		end
	end

	local function describeDailyRewardError(code)
		if code == "already_claimed" then
			return "Daily reward already claimed. Wait for the next reset."
		end
		return "Daily reward unavailable right now."
	end

	local function describeWeeklyRewardError(code)
		if code == "inactive" then
			return "Weekly crate requires active supporter access."
		elseif code == "already_claimed" then
			return "Weekly crate already collected. Return next cycle."
		elseif code == "busy" then
			return "Weekly crate is already being processed."
		end
		return "Weekly crate unavailable right now."
	end

	local function describeDailyOpsError(code)
		if code == "missing_task" then
			return "That daily op is no longer active."
		elseif code == "not_ready" then
			return "Finish the daily op before claiming its reward."
		elseif code == "already_claimed" then
			return "That daily op reward is already collected."
		end
		return "Daily op reward unavailable."
	end

	local function describeShopError(code)
		if code == "missing_item" then
			return "That shop item no longer exists on the server."
		elseif code == "drop_only_item" then
			return "That item is recovered from mission drops, not bought in the shop."
		elseif code == "season_locked" then
			return "That seasonal item is locked until its event goes live."
		elseif code == "insufficient_tokens" then
			return "Not enough deploy tokens for that purchase."
		elseif code == "deploy_token_purchase_is_reward_flow" then
			return "Deploy token packs need linked Robux products or reward hooks."
		elseif code == "invalid_currency" then
			return "The selected currency is not valid for that item."
		end
		return "Purchase failed."
	end

	local function describeSquadError(code)
		if code == "missing_squad" then
			return "That squad is no longer available."
		elseif code == "locked" then
			return "That squad is already locked for deployment."
		elseif code == "full" then
			return "That squad is already full."
		elseif code == "not_leader" then
			return "Only the squad leader can do that."
		elseif code == "missing_invite" then
			return "That invite expired or is no longer valid."
		elseif code == "same_squad" then
			return "That survivor is already in your fireteam."
		end
		return "Unable to join squad."
	end

	local function describeDuelError(code)
		if code == "corner_taken" then
			return "That duel corner is already occupied."
		elseif code == "already_in_match" then
			return "You are already in an active duel."
		elseif code == "cooldown" then
			return "Duel cooldown active. Give it a few seconds before requeueing."
		elseif code == "not_in_lobby" then
			return "Duel ring is only available from the lobby."
		elseif code == "invalid_corner" then
			return "That duel entry is offline."
		end
		return "Unable to join the duel ring."
	end

	refreshDailyRewardState = function()
		local callOk, rewardState = safeInvoke(RemoteNames.Functions.GetDailyRewardState)
		if callOk and type(rewardState) == "table" then
			setDailyRewardValue(rewardState)
		end
	end

	refreshDailyOpsState = function()
		local callOk, stateValue = safeInvoke(RemoteNames.Functions.GetDailyOpsState)
		if callOk and type(stateValue) == "table" then
			setDailyOpsValue(stateValue)
		end
	end

	refreshWeeklyRewardState = function()
		local callOk, rewardState = safeInvoke(RemoteNames.Functions.GetWeeklyRewardState)
		if callOk and type(rewardState) == "table" then
			setWeeklyRewardValue(rewardState)
		end
	end

	refreshSubscriptionState = function()
		local callOk, state = safeInvoke(RemoteNames.Functions.GetSubscriptionState)
		if callOk and type(state) == "table" then
			setSubscriptionStateValue(state)
		end
	end

	refreshShopCatalog = function()
		local callOk, catalog = safeInvoke(RemoteNames.Functions.GetShopCatalog)
		if callOk and type(catalog) == "table" then
			setShopCatalogValue(catalog)
		end
	end

	refreshSquadDirectory = function()
		isRefreshingDirectory = true
		updateLobbyText()
		local callOk, directory = safeInvoke(RemoteNames.Functions.GetSquadDirectory)
		isRefreshingDirectory = false
		if callOk and type(directory) == "table" then
			squadDirectory = normalizeSquadDirectory(directory)
		end
		updateLobbyText()
	end

	refreshInviteablePlayers = function()
		isRefreshingInvitePlayers = true
		updateLobbyText()
		local callOk, playersList = safeInvoke(RemoteNames.Functions.GetInviteablePlayers)
		isRefreshingInvitePlayers = false
		if callOk and type(playersList) == "table" then
			inviteablePlayers = normalizeInviteablePlayers(playersList)
		end
		updateLobbyText()
	end

	local function requestDailyReward()
		if isClaimingDailyReward then
			return
		end

		isClaimingDailyReward = true
		updateLobbyText()
		local callOk, success, amountOrCode, rewardState = safeInvoke(RemoteNames.Functions.ClaimDailyReward)
		isClaimingDailyReward = false

		if not callOk then
			currentSocialMessage = "Daily reward request failed."
			updateLobbyText()
			return
		end

		if success then
			currentSocialMessage = ("Daily reward claimed: +%d deploy tokens."):format(tonumber(amountOrCode) or 0)
			setDailyRewardValue(rewardState)
			if ui.Lobby.TokenValue and ui.Lobby.TokenValue.Parent then
				pulseGuiObject(ui.Lobby.TokenValue.Parent, Theme.Colors.AccentWarm)
			end
		else
			currentSocialMessage = describeDailyRewardError(amountOrCode)
			setDailyRewardValue(rewardState)
		end
		updateLobbyText()
	end

	local function requestWeeklyReward()
		local callOk, success, payloadOrCode, rewardState = safeInvoke(RemoteNames.Functions.ClaimWeeklyRewardCrate)
		if not callOk then
			currentSocialMessage = "Weekly crate request failed."
			updateLobbyText()
			return
		end

		if success then
			local rewardPayload = type(payloadOrCode) == "table" and payloadOrCode or {}
			currentSocialMessage = ("Weekly crate claimed: +%d tokens%s"):format(
				tonumber(rewardPayload.tokens) or 0,
				(tonumber(rewardPayload.experience) or 0) > 0 and (" +%d XP"):format(tonumber(rewardPayload.experience) or 0) or ""
			)
			setWeeklyRewardValue(rewardState)
			refreshSubscriptionState()
			if ui.Lobby.TokenValue and ui.Lobby.TokenValue.Parent then
				pulseGuiObject(ui.Lobby.TokenValue.Parent, Color3.fromRGB(180, 154, 86))
			end
			if (tonumber(rewardPayload.experience) or 0) > 0 then
				if ui.Lobby.SkillSummary then
					pulseGuiObject(ui.Lobby.SkillSummary, Color3.fromRGB(188, 214, 128))
				end
				if ui.Lobby.InventorySkillSummary then
					pulseGuiObject(ui.Lobby.InventorySkillSummary, Color3.fromRGB(188, 214, 128))
				end
				if ui.Lobby.SkillTreeSummary then
					pulseGuiObject(ui.Lobby.SkillTreeSummary, Color3.fromRGB(188, 214, 128))
				end
			end
		else
			currentSocialMessage = describeWeeklyRewardError(payloadOrCode)
			setWeeklyRewardValue(rewardState)
		end
		updateLobbyText()
	end

	local function requestClaimDailyOp(taskId)
		local callOk, success, payloadOrCode, stateValue = safeInvoke(RemoteNames.Functions.ClaimDailyOpsReward, taskId)
		if not callOk then
			currentSocialMessage = "Daily op claim failed."
			updateLobbyText()
			return
		end

		if success then
			local rewardPayload = type(payloadOrCode) == "table" and payloadOrCode or {}
			currentSocialMessage = ("Daily op reward claimed: +%d tokens%s"):format(
				tonumber(rewardPayload.tokens) or 0,
				(tonumber(rewardPayload.experience) or 0) > 0 and (" +%d XP"):format(tonumber(rewardPayload.experience) or 0) or ""
			)
			setDailyOpsValue(stateValue)
			if ui.Lobby.TokenValue and ui.Lobby.TokenValue.Parent then
				pulseGuiObject(ui.Lobby.TokenValue.Parent, Theme.Colors.AccentWarm)
			end
			if ui.Lobby.SkillSummary then
				pulseGuiObject(ui.Lobby.SkillSummary, Color3.fromRGB(188, 214, 128))
			end
			if ui.Lobby.InventorySkillSummary then
				pulseGuiObject(ui.Lobby.InventorySkillSummary, Color3.fromRGB(188, 214, 128))
			end
			if ui.Lobby.SkillTreeSummary then
				pulseGuiObject(ui.Lobby.SkillTreeSummary, Color3.fromRGB(188, 214, 128))
			end
		else
			currentSocialMessage = describeDailyOpsError(payloadOrCode)
			setDailyOpsValue(stateValue)
		end
		updateLobbyText()
	end

	local function requestLeaveSquad()
		local callOk, success, resultOrCode, snapshot = safeInvoke(RemoteNames.Functions.LeaveSquad)
		if not callOk then
			currentSocialMessage = "Leave squad request failed."
			updateLobbyText()
			return
		end

		if success and type(snapshot) == "table" then
			setSquadValue(snapshot)
			currentSocialMessage = "Returned to a solo squad."
		elseif success then
			currentSocialMessage = "Squad state updated."
			refreshSquadDirectory()
		else
			currentSocialMessage = describeSquadError(resultOrCode)
		end
		updateLobbyText()
	end

	local function requestJoinSquad(squadId)
		local callOk, success, resultOrCode, snapshot = safeInvoke(RemoteNames.Functions.CreateOrJoinSquad, squadId)
		if not callOk then
			currentSocialMessage = "Squad join request failed."
			updateLobbyText()
			return
		end

		if success then
			if type(snapshot) == "table" then
				setSquadValue(snapshot)
			end
			currentSocialMessage = "Joined squad from the bunker board."
			refreshSquadDirectory()
			return
		end

		currentSocialMessage = describeSquadError(resultOrCode)
		updateLobbyText()
	end

	local function requestSendInvite(targetUserId)
		local callOk, success, payloadOrCode = safeInvoke(RemoteNames.Functions.SendSquadInvite, targetUserId)
		if not callOk then
			currentSocialMessage = "Invite request failed."
		elseif success then
			currentSocialMessage = "Fireteam invite sent."
		else
			currentSocialMessage = describeSquadError(payloadOrCode)
		end
		updateLobbyText()
	end

	local function requestSetSquadPrivacy(isPrivate)
		local callOk, success, resultOrCode = safeInvoke(RemoteNames.Functions.SetSquadPrivacy, isPrivate)
		if not callOk then
			currentSocialMessage = "Unable to update squad privacy."
		elseif success then
			currentSocialMessage = isPrivate and "Squad switched to private." or "Squad reopened to public joins."
		else
			currentSocialMessage = describeSquadError(resultOrCode)
		end
		updateLobbyText()
	end

	local function requestDeploy()
		local callOk, success, resultOrCode = safeInvoke(RemoteNames.Functions.RequestDeploy)
		if not callOk then
			currentDeployStatus = "Deploy request failed."
			updateLobbyText()
			return
		end
		if success then
			currentDeployStatus = "Intermission starting..."
		elseif resultOrCode == "insufficient_tokens" then
			currentDeployStatus = "Need more deploy tokens to start."
		elseif resultOrCode == "busy" then
			currentDeployStatus = "Squad launch already in progress."
		else
			currentDeployStatus = "Unable to deploy right now."
		end
		updateLobbyText()
	end

	local function requestMapVote(optionId)
		local callOk, success, payloadOrCode = safeInvoke(RemoteNames.Functions.RequestMapVote, optionId)
		if not callOk then
			currentDeployStatus = "Map vote request failed."
			updateLobbyText()
			return
		end
		if success then
			if type(payloadOrCode) == "table" then
				currentVoteOptionId = tostring(payloadOrCode.selectedOptionId or optionId)
				if type(payloadOrCode.lobbyState) == "table" then
					setLobbyValue(payloadOrCode.lobbyState)
				end
				currentDeployStatus = ("Vote locked for %s."):format(tostring(payloadOrCode.layoutName or "next run"))
			else
				currentVoteOptionId = tostring(optionId)
				currentDeployStatus = "Map vote locked."
			end
		else
			currentDeployStatus = describeMapVoteError(payloadOrCode)
		end
		updateLobbyText()
	end

	local function requestDuel(action)
		local callOk, success, resultOrCode = safeInvoke(RemoteNames.Functions.RequestDuel, action)
		if not callOk then
			currentSocialMessage = "Duel request failed."
		elseif success then
			if resultOrCode == "started" then
				currentSocialMessage = "Duel started. Hold the ring."
			elseif resultOrCode == "left" then
				currentSocialMessage = "You left the duel ring."
			else
				currentSocialMessage = "Duel corner locked in. Waiting for an opponent."
			end
		else
			currentSocialMessage = describeDuelError(resultOrCode)
		end
		updateLobbyText()
	end

	local function requestAdminCommand(commandRequest)
		local requestPayload = commandRequest
		if type(requestPayload) ~= "table" then
			requestPayload = {
				commandId = tostring(commandRequest or ""),
			}
		end
		local callOk, success, payloadOrCode = safeInvoke(RemoteNames.Functions.AdminCommand, requestPayload)
		if not callOk then
			currentAdminStatus = "Owner command failed."
			updateLobbyText()
			return
		end

		if success and type(payloadOrCode) == "table" then
			currentAdminStatus = tostring(payloadOrCode.status or "Owner command completed.")
			if type(payloadOrCode.progression) == "table" then
				setProgressionValue(payloadOrCode.progression)
			end
			if type(payloadOrCode.panelState) == "table" then
				local panelState = payloadOrCode.panelState
				if panelState.overrideId == "none" then
					currentAdminEventLabel = "Event Mode: Disabled"
				elseif type(panelState.activeEventName) == "string" and panelState.activeEventName ~= "" then
					if panelState.overrideId and panelState.overrideId ~= "" then
						currentAdminEventLabel = ("Event Mode: %s"):format(panelState.activeEventName)
					else
						currentAdminEventLabel = ("Event Mode: Auto Rotation (%s)"):format(panelState.activeEventName)
					end
				else
					currentAdminEventLabel = "Event Mode: Auto Rotation"
				end
			end
		elseif success then
			currentAdminStatus = "Owner command completed."
		elseif payloadOrCode == "unauthorized" then
			currentAdminStatus = "Owner access denied."
		elseif payloadOrCode == "no_active_run" or payloadOrCode == "no_active_mission" then
			currentAdminStatus = "No active run to return."
		elseif payloadOrCode == "missing_character" then
			currentAdminStatus = "Character unavailable for heal."
		elseif payloadOrCode == "no_downed_targets" then
			currentAdminStatus = "No downed squad members to revive."
		elseif payloadOrCode == "missing_target" then
			currentAdminStatus = "Select a valid server target first."
		else
			currentAdminStatus = "Owner command unavailable."
		end
		updateLobbyText()
	end

	local function requestAdminTargetCommand(commandId)
		local targetPlayer = getAdminTargetPlayer()
		requestAdminCommand({
			commandId = commandId,
			targetUserId = targetPlayer and targetPlayer.UserId or player.UserId,
		})
	end

	local function respondToInvite(acceptInvite)
		if not pendingInvite then
			return
		end

		local fromSquadId = pendingInvite.fromSquadId
		local callOk, success, resultOrCode, snapshot = safeInvoke(RemoteNames.Functions.RespondToSquadInvite, fromSquadId, acceptInvite)
		pendingInvite = nil
		if not callOk then
			currentSocialMessage = "Invite response failed."
			updateLobbyText()
			return
		end

		if acceptInvite and success then
			if type(snapshot) == "table" then
				setSquadValue(snapshot)
			end
			currentSocialMessage = "Joined fireteam from invite."
			refreshSquadDirectory()
			refreshInviteablePlayers()
		elseif not acceptInvite and success then
			currentSocialMessage = "Invite declined."
		else
			currentSocialMessage = describeSquadError(resultOrCode)
		end
		updateLobbyText()
	end

	local function promptRobuxPurchase(item)
		if type(item) ~= "table" or type(item.ProductId) ~= "number" or item.ProductId <= 0 then
			currentShopStatus = "This token pack needs a linked dev product ID before Robux purchases work."
			updateLobbyText()
			return
		end

		currentShopStatus = ("Opening Robux purchase for %s."):format(item.DisplayName or item.Id)
		updateLobbyText()
		MarketplaceService:PromptProductPurchase(player, item.ProductId)
	end

	local function refreshEntitlements()
		local callOk, payload = safeInvoke(RemoteNames.Functions.RefreshEntitlements)
		if callOk and type(payload) == "table" then
			setProgressionValue(payload)
		end
	end

	local function promptGamePassPurchase(item)
		if type(item) ~= "table" or type(item.GamePassId) ~= "number" or item.GamePassId <= 0 then
			currentShopStatus = "This game pass needs a linked pass ID before purchase works."
			updateLobbyText()
			return
		end

		currentShopStatus = ("Opening game pass purchase for %s."):format(item.DisplayName or item.Id)
		updateLobbyText()
		MarketplaceService:PromptGamePassPurchase(player, item.GamePassId)
	end

	local function promptSubscriptionPurchase(item)
		if type(item) ~= "table" or type(item.SubscriptionId) ~= "string" or item.SubscriptionId == "" then
			currentShopStatus = "This subscription needs a linked subscription ID before purchase works."
			updateLobbyText()
			return
		end

		currentShopStatus = ("Opening subscription purchase for %s."):format(item.DisplayName or item.Id)
		updateLobbyText()
		local callOk = pcall(function()
			MarketplaceService:PromptSubscriptionPurchase(player, item.SubscriptionId)
		end)
		if not callOk then
			currentShopStatus = "Subscription purchase could not be opened right now."
			updateLobbyText()
			return
		end
		task.delay(6, function()
			if player.Parent then
				refreshSubscriptionState()
				updateLobbyText()
			end
		end)
	end

	local function requestShopPurchase(category, item)
		if purchasingItemId then
			return
		end

		if type(item) == "table" and item.SubscriptionId then
			promptSubscriptionPurchase(item)
			return
		end
		if type(item) == "table" and type(item.GamePassId) == "number" then
			promptGamePassPurchase(item)
			return
		end

		if category == Theme.ShopTabToCategory["Deploy Tokens"] or item.CostType == "Robux" then
			promptRobuxPurchase(item)
			return
		end

		purchasingItemId = item.Id
		updateLobbyText()

		local request = {
			category = category,
			itemId = item.Id,
			quantity = 1,
			currency = "Tokens",
		}
		local callOk, success, payloadOrCode = safeInvoke(RemoteNames.Functions.PurchaseShopItem, request)

		purchasingItemId = nil
		if not callOk then
			currentShopStatus = "Shop request failed."
			updateLobbyText()
			return
		end

		if success then
			currentShopStatus = ("Unlocked %s."):format(item.DisplayName or item.Id)
		else
			currentShopStatus = describeShopError(payloadOrCode)
		end
		updateLobbyText()
	end

	local function requestEquipItem(category, item)
		if equippingItemId then
			return
		end

		equippingItemId = item.Id
		updateLobbyText()

		local callOk, success, payloadOrCode = safeInvoke(RemoteNames.Functions.EquipLoadoutItem, {
			category = category,
			itemId = item.Id,
		})

		equippingItemId = nil
		if not callOk then
			currentShopStatus = "Equip request failed."
			updateLobbyText()
			return
		end

		if success then
			if category == Theme.ShopTabToCategory.Weapons then
				progression.equippedWeapon = item.Id
				currentShopStatus = ("Equipped %s."):format(item.DisplayName or item.Id)
				currentInventoryStatus = currentShopStatus
			elseif category == Theme.ShopTabToCategory.Cosmetics then
				progression.equippedCosmetic = item.Id
				currentShopStatus = ("Equipped %s."):format(item.DisplayName or item.Id)
				currentInventoryStatus = currentShopStatus
			end
		else
			currentShopStatus = tostring(payloadOrCode or "Unable to equip item.")
			currentInventoryStatus = currentShopStatus
		end

		updateLobbyText()
	end

	local function requestSpendSkillPoint(skillId)
		if not skillId or spendingSkillId then
			return
		end

		spendingSkillId = skillId
		currentShopStatus = "Allocating skill point..."
		updateLobbyText()

		local callOk, success, payloadOrCode = safeInvoke(RemoteNames.Functions.SpendSkillPoint, skillId)
		spendingSkillId = nil
		if not callOk then
			currentShopStatus = "Skill tree request failed."
			updateLobbyText()
			return
		end

		if success then
			setProgressionValue(payloadOrCode)
			local definition = SkillTreeConfig.getSkillDefinition(skillId)
			currentShopStatus = definition and (definition.DisplayName .. " advanced.") or "Skill upgraded."
		else
			local reason = tostring(payloadOrCode or "Unable to spend point.")
			if reason == "no_points" then
				currentShopStatus = "No skill points ready yet."
			elseif reason == "max_rank" then
				currentShopStatus = "That node is already maxed."
			elseif reason == "missing_prerequisite" then
				currentShopStatus = "Unlock the previous node first."
			else
				currentShopStatus = reason
			end
		end

		updateLobbyText()
	end

	local function requestRespecSkillTree()
		pendingRespecConfirmation = false
		currentSkillTreeStatus = "Resetting specialization..."
		updateLobbyText()

		local callOk, success, payloadOrCode = safeInvoke(RemoteNames.Functions.RespecSkillTree)
		if not callOk then
			currentSkillTreeStatus = "Respec request failed."
			updateLobbyText()
			return
		end

		if success then
			setProgressionValue(payloadOrCode)
			currentSkillTreeStatus = "Skill tree reset. Points refunded."
		else
			local reason = tostring(payloadOrCode or "Unable to respec.")
			if reason == "nothing_to_respec" then
				currentSkillTreeStatus = "No spent points to refund."
			else
				currentSkillTreeStatus = reason
			end
		end

		updateLobbyText()
	end

	renderShopItems = function()
		clearGeneratedChildren(ui.Lobby.ShopItemsFrame)

		local category = Theme.ShopTabToCategory[currentShopTab]
		local items = {}
		for _, item in ipairs(shopCatalog[category] or {}) do
			if matchesRarityFilter(item.Rarity, currentShopRarityFilter)
				and (currentShopTab ~= "Deploy Tokens" or matchesPremiumFilter(item, currentShopPremiumFilter)) then
				table.insert(items, item)
			end
		end
		table.sort(items, function(a, b)
			local rarityA = getRarityWeight(a.Rarity)
			local rarityB = getRarityWeight(b.Rarity)
			if rarityA ~= rarityB then
				return rarityA > rarityB
			end
			local costA = tonumber(a.Cost) or 0
			local costB = tonumber(b.Cost) or 0
			if costA ~= costB then
				return costA < costB
			end
			return tostring(a.DisplayName or a.Id) < tostring(b.DisplayName or b.Id)
		end)
		ui.Lobby.ShopEmptyLabel.Visible = #items == 0

		for index, item in ipairs(items) do
			local card = makeListCard(ui.Lobby.ShopItemsFrame, "Item_" .. index, 178)
			card.LayoutOrder = index
			local isSubscriptionItem = type(item.SubscriptionId) == "string" and item.SubscriptionId ~= ""
			local isGamePassItem = type(item.GamePassId) == "number" and item.GamePassId > 0
			local isPremiumPack = not isSubscriptionItem and not isGamePassItem and (item.CostType == "Robux" or category == Theme.ShopTabToCategory["Deploy Tokens"])
			local premiumAccent = isSubscriptionItem and Color3.fromRGB(214, 182, 96)
				or (isGamePassItem and Color3.fromRGB(104, 168, 232) or (isPremiumPack and Color3.fromRGB(104, 214, 164) or Theme.Colors.AccentWarm))
			local premiumPanel = isSubscriptionItem and Color3.fromRGB(60, 54, 40)
				or (isGamePassItem and Color3.fromRGB(42, 54, 76) or (isPremiumPack and Color3.fromRGB(36, 58, 60) or Color3.fromRGB(36, 46, 58)))
			local premiumLabel = isSubscriptionItem and "SUBSCRIPTION"
				or (isGamePassItem and "GAME PASS" or (isPremiumPack and "PRODUCT" or nil))
			card.BackgroundColor3 = premiumPanel
			local cardGradient = Instance.new("UIGradient")
			cardGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, premiumPanel:Lerp(Color3.fromRGB(255, 255, 255), 0.04)),
				ColorSequenceKeypoint.new(1, premiumPanel:Lerp(Color3.fromRGB(0, 0, 0), 0.12)),
			})
			cardGradient.Rotation = 0
			cardGradient.Parent = card

			local accentBar = new("Frame", {
				Name = "AccentBar",
				BackgroundColor3 = premiumAccent,
				BorderSizePixel = 0,
				Position = UDim2.new(0.02, 0, 0.12, 0),
				Size = UDim2.new(0, 4, 0.8, 0),
				Parent = card,
			})
			addCorner(accentBar, UDim.new(0, 4))
			addStroke(card, premiumAccent, 0.14, 1)

			local topRule = new("Frame", {
				Name = "TopRule",
				BackgroundColor3 = premiumAccent,
				BackgroundTransparency = 0.4,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 16, 0, 12),
				Size = UDim2.new(0, 82, 0, 2),
				Parent = card,
			})
			addCorner(topRule, UDim.new(0, 4))

			local featuredEvent = item.SeasonalEvent and seasonalEventState and seasonalEventState.Id == item.SeasonalEvent
			local eventRibbonText = featuredEvent and ((seasonalEventState and seasonalEventState.DisplayName) or "EVENT LIVE")
				or (item.SeasonalEvent and "SEASONAL CACHE" or (item.DropOnly and "MISSION DROP" or nil))
			if eventRibbonText then
				local ribbonColor = featuredEvent and Color3.fromRGB(132, 196, 118)
					or (item.SeasonalEvent and Color3.fromRGB(178, 122, 214) or Color3.fromRGB(86, 156, 214))
				local ribbon = new("TextLabel", {
					Name = "EventRibbon",
					BackgroundColor3 = ribbonColor:Lerp(Color3.fromRGB(18, 22, 30), 0.2),
					BackgroundTransparency = 0.08,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -18, 0, 10),
					Size = UDim2.new(0, 118, 0, 20),
					Text = string.upper(eventRibbonText),
					TextColor3 = Theme.Colors.Text,
					TextScaled = false,
					TextSize = 9,
					Font = Theme.Fonts.Heading,
					Parent = card,
				})
				addCorner(ribbon, UDim.new(0, 8))
				addStroke(ribbon, ribbonColor, 0.12, 1)
			end

			local infoPane = new("Frame", {
				Name = "InfoPane",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 22, 0, 18),
				Size = UDim2.new(1, -214, 1, -34),
				Parent = card,
			})

			local rightPane = new("Frame", {
				Name = "RightPane",
				BackgroundColor3 = Color3.fromRGB(26, 32, 40),
				BackgroundTransparency = 0.1,
				BorderSizePixel = 0,
				Position = UDim2.new(1, -182, 0, 14),
				Size = UDim2.new(0, 164, 1, -28),
				Parent = card,
			})
			addCorner(rightPane, UDim.new(0, 14))
			addStroke(rightPane, premiumAccent, 0.18, 1)

			local title = new("TextLabel", {
				Name = "Title",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 0, 26),
				Text = tostring(item.DisplayName or item.Id),
				TextColor3 = Theme.Colors.Text,
				TextScaled = false,
				TextSize = 21,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Fonts.Heading,
				Parent = infoPane,
			})
			local laneText = premiumLabel
				or ((category == Theme.ShopTabToCategory.Weapons and "ARMORY STOCK")
				or (category == Theme.ShopTabToCategory.Upgrades and "FIELD UPGRADE")
				or (category == Theme.ShopTabToCategory.Cosmetics and "COSMETIC SKIN")
				or "DEPLOY STOCK")
			local laneTag = new("TextLabel", {
				Name = "LaneTag",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 0, 28),
				Size = UDim2.new(1, 0, 0, 14),
				Text = laneText,
				TextColor3 = premiumAccent,
				TextScaled = false,
				TextSize = 10,
				Font = Theme.Fonts.Heading,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = infoPane,
			})
			local featuredBlock = new("Frame", {
				Name = "FeaturedBlock",
				BackgroundColor3 = featuredEvent and Color3.fromRGB(38, 60, 48)
					or (item.SeasonalEvent and Color3.fromRGB(48, 42, 66)
					or (item.DropOnly and Color3.fromRGB(34, 50, 68) or Color3.fromRGB(28, 36, 46))),
				BackgroundTransparency = 0.08,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 0, 52),
				Size = UDim2.new(0, 98, 0, 46),
				Parent = infoPane,
			})
			addCorner(featuredBlock, UDim.new(0, 14))
			addStroke(
				featuredBlock,
				featuredEvent and Color3.fromRGB(132, 196, 118)
					or (item.SeasonalEvent and Color3.fromRGB(178, 122, 214)
					or (item.DropOnly and Color3.fromRGB(86, 156, 214) or premiumAccent)),
				0.14,
				1
			)
			local featuredMark = new("TextLabel", {
				Name = "FeaturedMark",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 10),
				Size = UDim2.new(1, -24, 0, 14),
				Text = item.DropOnly and "FIELD FIND" or (item.SeasonalEvent and "EVENT ISSUE" or "STOCK"),
				TextColor3 = Theme.Colors.Text,
				TextScaled = false,
				TextSize = 9,
				Font = Theme.Fonts.Heading,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = featuredBlock,
			})
			local featuredGlyph = new("TextLabel", {
				Name = "FeaturedGlyph",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.62, 0),
				Size = UDim2.new(1, -20, 0, 26),
				Text = item.SeasonalEvent and "FEATURED" or (item.DropOnly and "DROP CACHE" or "STANDARD"),
				TextColor3 = featuredEvent and Color3.fromRGB(198, 255, 188)
					or (item.SeasonalEvent and Color3.fromRGB(224, 186, 255)
					or (item.DropOnly and Color3.fromRGB(172, 218, 255) or premiumAccent)),
				TextScaled = false,
				TextSize = 12,
				Font = Theme.Fonts.Heading,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = featuredBlock,
			})
			local details = new("TextLabel", {
				Name = "Details",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 110, 0, 52),
				Size = UDim2.new(1, -110, 0, 58),
				Text = tostring(item.Description or "No description set."),
				TextColor3 = Color3.fromRGB(194, 204, 216),
				TextScaled = false,
				TextSize = 13,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Font = Theme.Fonts.Body,
				Parent = infoPane,
			})
			local intelLine = new("TextLabel", {
				Name = "DropChance",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 1, -52),
				Size = UDim2.new(1, 0, 0, 26),
				Text = getDropChanceText(item, seasonalEventState),
				TextColor3 = Color3.fromRGB(150, 200, 170),
				TextScaled = false,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				Font = Theme.Fonts.Body,
				Parent = infoPane,
			})
			local priceText
			local rarityLabel, rarityColor = getRarityStyle(item.Rarity or (isSubscriptionItem and "Supporter" or "Common"))
			if isSubscriptionItem then
				priceText = "Subscription"
			elseif isGamePassItem then
				priceText = "Game Pass"
			elseif item.DropOnly then
				priceText = "Mission drop"
			elseif item.SeasonalEvent and (not seasonalEventState or seasonalEventState.Id ~= item.SeasonalEvent) then
				priceText = "Season locked"
			elseif item.CostType == "Tokens" then
				priceText = ("%d Tokens"):format(tonumber(item.Cost) or 0)
			else
				priceText = "Robux product"
			end

			local badgeText = string.upper(rarityLabel)
			local badge = new("TextLabel", {
				Name = "CategoryBadge",
				BackgroundColor3 = rarityColor,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 1, -20),
				Size = UDim2.new(0, 92, 0, 20),
				Text = badgeText,
				TextColor3 = Theme.Colors.Text,
				TextScaled = false,
				TextSize = 11,
				Font = Theme.Fonts.Heading,
				Parent = infoPane,
			})
			addCorner(badge, UDim.new(0, 8))
			local rarityBadge = new("TextLabel", {
				Name = "TypeBadge",
				BackgroundColor3 = Color3.fromRGB(46, 56, 70),
				BorderSizePixel = 0,
				Position = UDim2.new(0, 100, 1, -20),
				Size = UDim2.new(0, premiumLabel and 118 or 102, 0, 20),
				Text = string.upper(premiumLabel or ((category == Theme.ShopTabToCategory.Weapons and "ARMORY") or (category == Theme.ShopTabToCategory.Upgrades and "UPGRADE") or (category == Theme.ShopTabToCategory.Cosmetics and "COSMETIC") or "TOKEN")),
				TextColor3 = Theme.Colors.Text,
				TextScaled = false,
				TextSize = 11,
				Font = Theme.Fonts.Heading,
				Parent = infoPane,
			})
			addCorner(rarityBadge, UDim.new(0, 8))

			local price = new("TextLabel", {
				Name = "Price",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 14, 0, 16),
				Size = UDim2.new(1, -28, 0, 30),
				Text = priceText,
				TextColor3 = premiumAccent:Lerp(Theme.Colors.Text, 0.26),
				TextScaled = false,
				TextSize = 16,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Fonts.Heading,
				Parent = rightPane,
			})
			local priceMeta = new("TextLabel", {
				Name = "PriceMeta",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 14, 0, 44),
				Size = UDim2.new(1, -28, 0, 28),
				Text = premiumLabel and "Premium access item" or (item.DropOnly and "Mission reward only" or "Quartermaster stock"),
				TextColor3 = Theme.Colors.Muted,
				TextScaled = false,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				Font = Theme.Fonts.Body,
				Parent = rightPane,
			})
			local premiumChip = new("TextLabel", {
				Name = "PremiumChip",
				BackgroundColor3 = premiumAccent:Lerp(Color3.fromRGB(30, 38, 50), 0.22),
				BackgroundTransparency = premiumLabel and 0.12 or 0.18,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 14, 0, 78),
				Size = UDim2.new(0, premiumLabel and 110 or 92, 0, 20),
				Text = premiumLabel or "STANDARD",
				TextColor3 = Theme.Colors.Text,
				TextScaled = false,
				TextSize = 10,
				Font = Theme.Fonts.Heading,
				Parent = rightPane,
			})
			addCorner(premiumChip, UDim.new(0, 8))
			addStroke(premiumChip, premiumAccent, 0.14, 1)
			local ownedAttribute = ("ShopUnlocked_%s_%s"):format(category, item.Id)
			local isOwned = (isGamePassItem and player:GetAttribute("GamePassOwned_" .. tostring(item.GamePassKey or "")) == true)
				or player:GetAttribute(ownedAttribute) == true
			local isRobuxItem = item.CostType == "Robux" or category == Theme.ShopTabToCategory["Deploy Tokens"]
			local buttonText = "Buy"
			local buttonColor = Theme.Colors.Accent
			local canPurchase = true

			if purchasingItemId == item.Id then
				buttonText = "Buying..."
				canPurchase = false
			elseif equippingItemId == item.Id then
				buttonText = "Equipping..."
				buttonColor = Theme.Colors.AccentWarm
				canPurchase = false
			elseif isGamePassItem and isOwned then
				buttonText = "Owned"
				buttonColor = Theme.Colors.Backdrop
				canPurchase = false
			elseif item.DropOnly then
				buttonText = "Drop Only"
				buttonColor = Theme.Colors.Backdrop
				canPurchase = false
			elseif item.SeasonalEvent and (not seasonalEventState or seasonalEventState.Id ~= item.SeasonalEvent) then
				buttonText = "Season Locked"
				buttonColor = Theme.Colors.Backdrop
				canPurchase = false
			elseif isOwned and not isRobuxItem then
				if category == Theme.ShopTabToCategory.Weapons then
					if progression.equippedWeapon == item.Id then
						buttonText = "Equipped"
						buttonColor = Theme.Colors.Backdrop
						canPurchase = false
					else
						buttonText = "Equip"
						buttonColor = Theme.Colors.AccentWarm
					end
				elseif category == Theme.ShopTabToCategory.Cosmetics then
					if progression.equippedCosmetic == item.Id then
						buttonText = "Equipped"
						buttonColor = Theme.Colors.Backdrop
						canPurchase = false
					else
						buttonText = "Equip"
						buttonColor = Theme.Colors.AccentWarm
					end
				else
					buttonText = "Owned"
					buttonColor = Theme.Colors.Backdrop
					canPurchase = false
				end
			elseif isSubscriptionItem then
				buttonText = "Subscribe"
				buttonColor = Theme.Colors.AccentWarm
			elseif isRobuxItem then
				buttonText = "Robux"
				buttonColor = Theme.Colors.AccentWarm
			elseif (tonumber(item.Cost) or 0) > tokenBalance then
				buttonText = "Need Tokens"
				buttonColor = Theme.Colors.Backdrop
				canPurchase = false
			else
				buttonText = "Buy"
			end

			local button = makeListButton(
				card,
				"PurchaseButton",
				buttonText,
				UDim2.new(1, -18, 1, -18),
				UDim2.new(0, 118, 0, 36),
				buttonColor
			)
			button.TextSize = 15
			setButtonEnabled(button, canPurchase or isRobuxItem, buttonColor)
			button.MouseButton1Click:Connect(function()
				if isOwned and (category == Theme.ShopTabToCategory.Weapons or category == Theme.ShopTabToCategory.Cosmetics) then
					requestEquipItem(category, item)
				else
					requestShopPurchase(category, item)
				end
			end)
		end
	end

	renderInventoryItems = function()
		clearGeneratedChildren(ui.Lobby.InventoryItemsFrame)
		local category = currentInventoryTab == "Cosmetics" and Theme.ShopTabToCategory.Cosmetics or Theme.ShopTabToCategory.Weapons
		local items = {}
		for _, item in ipairs(shopCatalog[category] or {}) do
			if playerOwnsItem(category, item) and matchesRarityFilter(item.Rarity, currentInventoryRarityFilter) then
				table.insert(items, item)
			end
		end
		table.sort(items, function(a, b)
			local rarityA = getRarityWeight(a.Rarity)
			local rarityB = getRarityWeight(b.Rarity)
			if rarityA ~= rarityB then
				return rarityA > rarityB
			end
			return tostring(a.DisplayName or a.Id) < tostring(b.DisplayName or b.Id)
		end)

		ui.Lobby.InventoryEmptyLabel.Visible = #items == 0

		for index, item in ipairs(items) do
			local card = makeListCard(ui.Lobby.InventoryItemsFrame, "InventoryItem_" .. index, 122)
			card.LayoutOrder = index
			card.BackgroundColor3 = Color3.fromRGB(58, 70, 88)
			local rarityLabel, rarityColor = getRarityStyle(item.Rarity or "Common")

			local accentBar = new("Frame", {
				Name = "AccentBar",
				BackgroundColor3 = rarityColor,
				BorderSizePixel = 0,
				Position = UDim2.new(0.02, 0, 0.1, 0),
				Size = UDim2.new(0, 4, 0.8, 0),
				Parent = card,
			})
			addCorner(accentBar, UDim.new(0, 4))

			local infoPane = new("Frame", {
				Name = "InfoPane",
				BackgroundTransparency = 1,
				Position = UDim2.new(0.06, 0, 0.12, 0),
				Size = UDim2.new(0.62, 0, 0.76, 0),
				Parent = card,
			})

			new("TextLabel", {
				Name = "Title",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 0, 24),
				Text = tostring(item.DisplayName or item.Id),
				TextColor3 = Theme.Colors.Text,
				TextScaled = false,
				TextSize = 19,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Fonts.Heading,
				Parent = infoPane,
			})
			new("TextLabel", {
				Name = "Details",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 0, 30),
				Size = UDim2.new(1, 0, 0, 34),
				Text = tostring(item.Description or "Owned item."),
				TextColor3 = Theme.Colors.Muted,
				TextScaled = false,
				TextSize = 13,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Font = Theme.Fonts.Body,
				Parent = infoPane,
			})
			new("TextLabel", {
				Name = "DropChance",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 0, 66),
				Size = UDim2.new(1, 0, 0, 14),
				Text = getDropChanceText(item, seasonalEventState),
				TextColor3 = Theme.Colors.AccentSoft,
				TextScaled = false,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Fonts.Body,
				Parent = infoPane,
			})
			local equipped = (category == Theme.ShopTabToCategory.Weapons and progression.equippedWeapon == item.Id)
				or (category == Theme.ShopTabToCategory.Cosmetics and progression.equippedCosmetic == item.Id)
			local badge = new("TextLabel", {
				Name = "OwnedBadge",
				BackgroundColor3 = equipped and Theme.Colors.AccentWarm or Color3.fromRGB(70, 94, 126),
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 1, -22),
				Size = UDim2.new(0, 110, 0, 20),
				Text = equipped and "EQUIPPED" or "OWNED",
				TextColor3 = Theme.Colors.Text,
				TextScaled = false,
				TextSize = 11,
				Font = Theme.Fonts.Heading,
				Parent = infoPane,
			})
			addCorner(badge, UDim.new(0, 8))
			local rarityBadge = new("TextLabel", {
				Name = "RarityBadge",
				BackgroundColor3 = rarityColor,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 118, 1, -22),
				Size = UDim2.new(0, 88, 0, 20),
				Text = string.upper(rarityLabel),
				TextColor3 = Theme.Colors.Text,
				TextScaled = false,
				TextSize = 11,
				Font = Theme.Fonts.Heading,
				Parent = infoPane,
			})
			addCorner(rarityBadge, UDim.new(0, 8))

			local buttonText = equipped and "Equipped" or (equippingItemId == item.Id and "Equipping..." or "Equip")
			local buttonColor = equipped and Theme.Colors.Backdrop or Theme.Colors.AccentWarm
			local canEquip = not equipped and equippingItemId == nil
			local button = makeListButton(card, "EquipButton", buttonText, UDim2.new(0.91, 0, 0.7, 0), UDim2.new(0.22, 0, 0.32, 0), buttonColor)
			button.TextSize = 16
			setButtonEnabled(button, canEquip, buttonColor)
			button.MouseButton1Click:Connect(function()
				requestEquipItem(category, item)
				currentInventoryStatus = ("Equipping %s..."):format(item.DisplayName or item.Id)
				updateLobbyText()
			end)
		end
	end

	renderSkillTreeItems = function()
		clearGeneratedChildren(ui.Lobby.SkillTreeList)
		local skillTree = progression.skillTree or {}
		local availablePoints = skillTree.skillPoints or 0
		local skills = SkillTreeConfig.getOrderedSkills()
		ui.Lobby.SkillTreeEmpty.Visible = #skills == 0

		if #skills == 0 then
			ui.Lobby.SkillTreeList.CanvasSize = UDim2.new()
			selectedSkillTreeNodeId = nil
			return
		end
		if not selectedSkillTreeNodeId and skills[1] then
			selectedSkillTreeNodeId = skills[1].Id
		end

		local visibleBranches = {}
		if currentSkillTreeBranchFilter == "All" then
			for _, branchId in ipairs(Theme.SkillTreeBranchOrder) do
				table.insert(visibleBranches, branchId)
			end
		else
			table.insert(visibleBranches, currentSkillTreeBranchFilter)
		end

		local branchGroups = {}
		for _, branchId in ipairs(visibleBranches) do
			branchGroups[branchId] = {}
		end

		for index, skill in ipairs(skills) do
			local branchId = skill.Branch or "Survivor"
			local branch = branchGroups[branchId]
			if branch then
				local tier = math.max(1, tonumber(skill.Tier) or 1)
				branch[tier] = branch[tier] or {}
				table.insert(branch[tier], {
					index = index,
					skill = skill,
				})
			end
		end
		local selectedVisible = false
		for _, branchId in ipairs(visibleBranches) do
			for _, tierEntries in pairs(branchGroups[branchId] or {}) do
				for _, entry in ipairs(tierEntries) do
					if entry.skill.Id == selectedSkillTreeNodeId then
						selectedVisible = true
						break
					end
				end
				if selectedVisible then
					break
				end
			end
			if selectedVisible then
				break
			end
		end
		if not selectedVisible then
			for _, branchId in ipairs(visibleBranches) do
				for _, tierEntries in pairs(branchGroups[branchId] or {}) do
					if tierEntries[1] and tierEntries[1].skill then
						selectedSkillTreeNodeId = tierEntries[1].skill.Id
						selectedVisible = true
						break
					end
				end
				if selectedVisible then
					break
				end
			end
		end

		local nodeHeight = 122
		local rowGap = 10
		local tierSpacing = 142
		local branchTop = 82
		local branchHeaderHeight = 66
		local graphHeight = branchTop + branchHeaderHeight + 28

		for _, branchId in ipairs(visibleBranches) do
			local tiers = branchGroups[branchId] or {}
			local branchBottom = branchTop + branchHeaderHeight
			local maxTier = 0
			for tier in pairs(tiers) do
				maxTier = math.max(maxTier, tier)
			end
			for tier = 1, maxTier do
				local tierEntries = tiers[tier] or {}
				for slotIndex, _ in ipairs(tierEntries) do
					local nodeY = branchTop + branchHeaderHeight + ((tier - 1) * tierSpacing) + ((slotIndex - 1) * (nodeHeight + rowGap))
					branchBottom = math.max(branchBottom, nodeY + nodeHeight)
				end
			end
			graphHeight = math.max(graphHeight, branchBottom + 28)
		end

		local graphSurface = new("Frame", {
			Name = "GraphSurface",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -8, 0, graphHeight),
			Parent = ui.Lobby.SkillTreeList,
		})
		graphSurface.ClipsDescendants = false
		ui.Lobby.SkillTreeList.CanvasSize = UDim2.new(0, 0, 0, graphHeight + 12)

		local branchCount = #visibleBranches
		local columnScale = branchCount == 1 and 1 or 0.313
		local gapScale = branchCount == 1 and 0 or 0.02
		for index, branchId in ipairs(visibleBranches) do
			local branch = getBranchTheme(branchId)
			local tierMap = branchGroups[branchId] or {}
			local column = new("Frame", {
				Name = branchId .. "Column",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.new(branchCount == 1 and 0 or (gapScale + ((index - 1) * (columnScale + gapScale))), 0, 0, 0),
				Size = UDim2.new(columnScale, 0, 0, graphHeight),
				Parent = graphSurface,
			})

			local header = new("Frame", {
				Name = "BranchHeader",
				BackgroundColor3 = branch.Panel or Theme.Colors.PanelAlt,
				BackgroundTransparency = 0.1,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 0, 66),
				Parent = column,
			})
			addCorner(header, UDim.new(0, 16))
			addStroke(header, branch.Color or Theme.Colors.Stroke, 0.18, 1)

			createSkillNodeBadge(header, "BranchChip", branch.Icon or branchId, UDim2.new(0, 14, 0, 14), UDim2.new(0, 38, 0, 38), branch.Color or Theme.Colors.AccentWarm, Theme.Colors.Text, 12)
			local headerTitle = new("TextLabel", {
				Name = "Title",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 62, 0, 12),
				Size = UDim2.new(1, -74, 0, 22),
				Text = branch.DisplayName or branchId,
				TextColor3 = Theme.Colors.Text,
				TextScaled = false,
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Fonts.Heading,
				Parent = header,
			})
			new("TextLabel", {
				Name = "Summary",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 62, 0, 34),
				Size = UDim2.new(1, -74, 0, 20),
				Text = branch.Summary or "Specialization branch.",
				TextColor3 = Theme.Colors.Muted,
				TextScaled = false,
				TextSize = 11,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Fonts.Body,
				Parent = header,
			})

			local stem = new("Frame", {
				Name = "ConnectorStem",
				BackgroundColor3 = branch.Color or Theme.Colors.AccentWarm,
				BackgroundTransparency = 0.64,
				BorderSizePixel = 0,
				Position = UDim2.new(0.5, -2, 0, 72),
				Size = UDim2.new(0, 4, 0, math.max(0, graphHeight - 92)),
				Parent = column,
			})
			addCorner(stem, UDim.new(0, 6))

			local tierIndexes = {}
			for tier in pairs(tierMap) do
				table.insert(tierIndexes, tier)
			end
			table.sort(tierIndexes)
			local nodeAnchors = {}

			for _, tier in ipairs(tierIndexes) do
				local tierEntries = tierMap[tier] or {}
				table.sort(tierEntries, function(a, b)
					if (a.skill.DisplayName or a.skill.Id) == (b.skill.DisplayName or b.skill.Id) then
						return a.index < b.index
					end
					return (a.skill.DisplayName or a.skill.Id) < (b.skill.DisplayName or b.skill.Id)
				end)

				for slotIndex, entry in ipairs(tierEntries) do
					local skill = entry.skill
					local currentRank = tonumber(skillTree.skills and skillTree.skills[skill.Id]) or 0
					local maxRank = tonumber(skill.MaxRank) or 1
					local prereqMet = true
					local prereqName = nil
					if skill.Prerequisite then
						local prereqDefinition = SkillTreeConfig.getSkillDefinition(skill.Prerequisite)
						prereqName = prereqDefinition and prereqDefinition.DisplayName or skill.Prerequisite
						prereqMet = (tonumber(skillTree.skills and skillTree.skills[skill.Prerequisite]) or 0) > 0
					end
					local stateText, stateColor, canUnlock = getSkillState(skill.Id, skill, currentRank, maxRank, prereqMet, prereqName, availablePoints, spendingSkillId)
					local branchColor = branch.Color or Theme.Colors.AccentWarm
					local isSelectedNode = selectedSkillTreeNodeId == skill.Id
					local nodeY = branchTop + branchHeaderHeight + ((tier - 1) * tierSpacing) + ((slotIndex - 1) * (nodeHeight + rowGap))
					nodeAnchors[skill.Id] = {
						topY = nodeY,
						bottomY = nodeY + nodeHeight,
					}

					local card = makeListCard(column, "SkillTree_" .. skill.Id, nodeHeight)
					card.LayoutOrder = entry.index
					card.Position = UDim2.new(0, 0, 0, nodeY)
					card.BackgroundColor3 = isSelectedNode
						and branchColor:Lerp(Color3.fromRGB(255, 255, 255), 0.5)
						or (canUnlock and Color3.fromRGB(58, 82, 68) or (currentRank >= maxRank and Color3.fromRGB(74, 82, 58) or Color3.fromRGB(58, 70, 82)))
					if isSelectedNode then
						addStroke(card, branchColor, 0.02, 2.5)
						local pulse = new("Frame", {
							Name = "SelectionPulse",
							BackgroundColor3 = branchColor,
							BackgroundTransparency = 0.84,
							BorderSizePixel = 0,
							Size = UDim2.new(1, 0, 1, 0),
							Parent = card,
						})
						addCorner(pulse, UDim.new(0, 12))
						task.defer(function()
							if pulse.Parent then
								TweenService:Create(pulse, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
									BackgroundTransparency = 0.92,
								}):Play()
							end
						end)
					end

					local connectorDot = new("Frame", {
						Name = "ConnectorDot",
						BackgroundColor3 = branchColor,
						BackgroundTransparency = 0.08,
						BorderSizePixel = 0,
						Position = UDim2.new(0.5, -6, 0, -6),
						Size = UDim2.new(0, 12, 0, 12),
						Parent = card,
					})
					addCorner(connectorDot, UDim.new(1, 0))
					addStroke(connectorDot, branchColor, 0.16, 1)

					local accentBar = new("Frame", {
						Name = "AccentBar",
						BackgroundColor3 = canUnlock and branchColor or Theme.Colors.AccentWarm,
						BorderSizePixel = 0,
						Position = UDim2.new(0.02, 0, 0.12, 0),
						Size = UDim2.new(0, 4, 0.76, 0),
						Parent = card,
					})
					addCorner(accentBar, UDim.new(0, 4))

					createSkillNodeBadge(card, "BranchBadge", string.upper(skill.Icon or branch.Icon or branchId), UDim2.new(0.68, 0, 0.12, 0), UDim2.new(0, 52, 0, 18), branchColor, Theme.Colors.Text, 9)
					createSkillNodeBadge(card, "NodeState", stateText, UDim2.new(0.68, 58, 0.12, 0), UDim2.new(0, 78, 0, 18), stateColor, Theme.Colors.Text, 9)

					local infoPane = new("Frame", {
						Name = "InfoPane",
						BackgroundTransparency = 1,
						Position = UDim2.new(0.06, 0, 0.1, 0),
						Size = UDim2.new(0.6, 0, 0.8, 0),
						Parent = card,
					})

					new("TextLabel", {
						Name = "Title",
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 0, 0, 0),
						Size = UDim2.new(1, 0, 0, 22),
						Text = skill.DisplayName,
						TextColor3 = Theme.Colors.Text,
						TextScaled = false,
						TextSize = 16,
						TextXAlignment = Enum.TextXAlignment.Left,
						Font = Theme.Fonts.Heading,
						Parent = infoPane,
					})
					new("TextLabel", {
						Name = "Branch",
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 0, 0, 22),
						Size = UDim2.new(1, 0, 0, 14),
						Text = ("%s | Tier %d"):format(branch.DisplayName or skill.Branch or "General", tonumber(skill.Tier) or 1),
						TextColor3 = branchColor,
						TextScaled = false,
						TextSize = 10,
						TextXAlignment = Enum.TextXAlignment.Left,
						Font = Theme.Fonts.Heading,
						Parent = infoPane,
					})
					new("TextLabel", {
						Name = "Details",
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 0, 0, 38),
						Size = UDim2.new(1, 0, 0, 32),
						Text = skill.Description,
						TextColor3 = Theme.Colors.Muted,
						TextScaled = false,
						TextSize = 10,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						Font = Theme.Fonts.Body,
						Parent = infoPane,
					})
					new("TextLabel", {
						Name = "Prerequisite",
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 0, 0, 74),
						Size = UDim2.new(1, 0, 0, 14),
						Text = prereqName and ("Requires: " .. prereqName) or "Root node",
						TextColor3 = prereqMet and Theme.Colors.AccentSoft or Color3.fromRGB(255, 168, 140),
						TextScaled = false,
						TextSize = 10,
						TextXAlignment = Enum.TextXAlignment.Left,
						Font = Theme.Fonts.Body,
						Parent = infoPane,
					})
					local bonus = new("TextLabel", {
						Name = "Bonus",
						BackgroundColor3 = Color3.fromRGB(112, 84, 54),
						BorderSizePixel = 0,
						Position = UDim2.new(0, 0, 1, -20),
						Size = UDim2.new(0, 168, 0, 18),
						Text = skill.BonusLabel,
						TextColor3 = Theme.Colors.Text,
						TextScaled = false,
						TextSize = 10,
						Font = Theme.Fonts.Heading,
						Parent = infoPane,
					})
					addCorner(bonus, UDim.new(0, 8))

					new("TextLabel", {
						Name = "Rank",
						BackgroundTransparency = 1,
						Position = UDim2.new(0.7, 0, 0.34, 0),
						Size = UDim2.new(0.14, 0, 0.16, 0),
						Text = ("Rank %d/%d"):format(currentRank, maxRank),
						TextColor3 = Theme.Colors.AccentSoft,
						TextScaled = false,
						TextSize = 11,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Right,
						Font = Theme.Fonts.Heading,
						Parent = card,
					})

					local inspectButton = new("TextButton", {
						Name = "InspectButton",
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Position = UDim2.new(0, 0, 0, 0),
						Size = UDim2.new(0.78, 0, 1, 0),
						Text = "",
						AutoButtonColor = false,
						Parent = card,
					})
					inspectButton.MouseButton1Click:Connect(function()
						selectedSkillTreeNodeId = skill.Id
						updateLobbyText()
					end)

					local buttonText = "Spend Point"
					local buttonColor = Theme.Colors.Accent
					if spendingSkillId == skill.Id then
						buttonText = "Applying..."
					elseif currentRank >= maxRank then
						buttonText = "Maxed"
						buttonColor = Theme.Colors.Backdrop
					elseif not prereqMet then
						buttonText = prereqName and ("Need " .. prereqName) or "Locked"
						buttonColor = Theme.Colors.Backdrop
					elseif availablePoints <= 0 then
						buttonText = "No Points"
						buttonColor = Theme.Colors.Backdrop
					end

					local button = makeListButton(card, "SpendButton", buttonText, UDim2.new(0.88, 0, 0.72, 0), UDim2.new(0.16, 0, 0.24, 0), buttonColor)
					button.TextSize = 13
					setButtonEnabled(button, canUnlock, buttonColor)
					button.MouseButton1Click:Connect(function()
						requestSpendSkillPoint(skill.Id)
					end)
				end
			end

			for _, tier in ipairs(tierIndexes) do
				local tierEntries = tierMap[tier] or {}
				for _, entry in ipairs(tierEntries) do
					local skill = entry.skill
					if skill.Prerequisite then
						local parentAnchor = nodeAnchors[skill.Prerequisite]
						local childAnchor = nodeAnchors[skill.Id]
						if parentAnchor and childAnchor then
							local connectorX = 16
							local elbowX = 28
							local verticalStart = parentAnchor.bottomY - 6
							local verticalHeight = math.max(8, childAnchor.topY - verticalStart + 6)
							local isSelectedPath = selectedSkillTreeNodeId == skill.Id or selectedSkillTreeNodeId == skill.Prerequisite
							local connectorTransparency = isSelectedPath and 0.12 or 0.42

							local vertical = new("Frame", {
								Name = skill.Id .. "_PrereqVertical",
								BackgroundColor3 = branch.Color or Theme.Colors.AccentWarm,
								BackgroundTransparency = connectorTransparency,
								BorderSizePixel = 0,
								Position = UDim2.new(0, connectorX, 0, verticalStart),
								Size = UDim2.new(0, 2, 0, verticalHeight),
								ZIndex = 0,
								Parent = column,
							})
							addCorner(vertical, UDim.new(0, 4))

							local topElbow = new("Frame", {
								Name = skill.Id .. "_PrereqTopElbow",
								BackgroundColor3 = branch.Color or Theme.Colors.AccentWarm,
								BackgroundTransparency = connectorTransparency,
								BorderSizePixel = 0,
								Position = UDim2.new(0, connectorX, 0, verticalStart),
								Size = UDim2.new(0, elbowX - connectorX, 0, 2),
								ZIndex = 0,
								Parent = column,
							})
							addCorner(topElbow, UDim.new(0, 4))

							local bottomElbow = new("Frame", {
								Name = skill.Id .. "_PrereqBottomElbow",
								BackgroundColor3 = branch.Color or Theme.Colors.AccentWarm,
								BackgroundTransparency = connectorTransparency,
								BorderSizePixel = 0,
								Position = UDim2.new(0, connectorX, 0, childAnchor.topY + 10),
								Size = UDim2.new(0, elbowX - connectorX, 0, 2),
								ZIndex = 0,
								Parent = column,
							})
							addCorner(bottomElbow, UDim.new(0, 4))
						end
					end
				end
			end
		end
	end

	renderSquadDirectory = function()
		clearGeneratedChildren(ui.Lobby.SquadDirectoryList)
		ui.Lobby.SquadDirectoryEmpty.Visible = #squadDirectory == 0

		for index, entry in ipairs(squadDirectory) do
			local card = makeListCard(ui.Lobby.SquadDirectoryList, "Squad_" .. index, 98)
			card.LayoutOrder = index
			card.BackgroundColor3 = Color3.fromRGB(44, 60, 56)

			local accentBar = new("Frame", {
				Name = "AccentBar",
				BackgroundColor3 = entry.isCurrentSquad and Theme.Colors.AccentWarm or Color3.fromRGB(88, 174, 154),
				BorderSizePixel = 0,
				Position = UDim2.new(0.02, 0, 0.12, 0),
				Size = UDim2.new(0, 4, 0.76, 0),
				Parent = card,
			})
			addCorner(accentBar, UDim.new(0, 4))

			local infoPane = new("Frame", {
				Name = "InfoPane",
				BackgroundTransparency = 1,
				Position = UDim2.new(0.06, 0, 0.1, 0),
				Size = UDim2.new(0.58, 0, 0.8, 0),
				Parent = card,
			})

			local title = new("TextLabel", {
				Name = "Title",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 0, 22),
				Text = trimLabel(entry.leaderName, 20),
				TextColor3 = Theme.Colors.Text,
				TextScaled = false,
				TextSize = 18,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Fonts.Heading,
				Parent = infoPane,
			})

			local subtitle = new("TextLabel", {
				Name = "Subtitle",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 0, 28),
				Size = UDim2.new(1, 0, 0, 18),
				Text = ("%d/%d survivors"):format(entry.memberCount, entry.maxPlayers),
				TextColor3 = Theme.Colors.AccentSoft,
				TextScaled = false,
				TextSize = 13,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Fonts.Heading,
				Parent = infoPane,
			})

			local body = new("TextLabel", {
				Name = "Body",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 0, 50),
				Size = UDim2.new(1, 0, 0, 18),
				Text = trimLabel(table.concat(entry.memberNames, ", "), 40),
				TextColor3 = Theme.Colors.Muted,
				TextScaled = false,
				TextSize = 12,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Font = Theme.Fonts.Body,
				Parent = infoPane,
			})

			local boardBadge = new("TextLabel", {
				Name = "BoardBadge",
				BackgroundColor3 = entry.locked and Color3.fromRGB(96, 62, 62) or Color3.fromRGB(50, 86, 78),
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 1, -22),
				Size = UDim2.new(0, 112, 0, 20),
				Text = entry.locked and "LOCKED" or "PUBLIC BOARD",
				TextColor3 = Theme.Colors.Text,
				TextScaled = false,
				TextSize = 10,
				Font = Theme.Fonts.Heading,
				Parent = infoPane,
			})
			addCorner(boardBadge, UDim.new(0, 8))

			local buttonText = "Join"
			local buttonColor = Theme.Colors.Accent
			local canJoin = entry.canJoin
			if entry.isCurrentSquad then
				buttonText = "Current"
				buttonColor = Theme.Colors.Backdrop
				canJoin = false
			elseif entry.locked then
				buttonText = "Locked"
				buttonColor = Theme.Colors.Backdrop
				canJoin = false
			elseif entry.memberCount >= entry.maxPlayers then
				buttonText = "Full"
				buttonColor = Theme.Colors.Backdrop
				canJoin = false
			end

			local button = makeListButton(
				card,
				"JoinButton",
				buttonText,
				UDim2.new(0.88, 0, 0.68, 0),
				UDim2.new(0.22, 0, 0.3, 0),
				buttonColor
			)
			button.TextSize = 15
			setButtonEnabled(button, canJoin, buttonColor)
			button.MouseButton1Click:Connect(function()
				requestJoinSquad(entry.squadId)
			end)
		end
	end

	renderAdminTargetList = function()
		if not ui.Lobby.AdminTargetList then
			return
		end

		clearGeneratedChildren(ui.Lobby.AdminTargetList)
		local playersList = Players:GetPlayers()
		table.sort(playersList, function(a, b)
			if a == player then
				return true
			end
			if b == player then
				return false
			end
			return tostring(a.DisplayName or a.Name) < tostring(b.DisplayName or b.Name)
		end)

		for index, candidate in ipairs(playersList) do
			local card = makeListCard(ui.Lobby.AdminTargetList, "AdminTarget_" .. tostring(candidate.UserId), 68)
			card.LayoutOrder = index
			card.BackgroundColor3 = candidate == player and Color3.fromRGB(64, 54, 38) or Color3.fromRGB(42, 36, 30)

			local selected = (candidate == player and not selectedAdminTargetUserId) or (selectedAdminTargetUserId == candidate.UserId)
			local accentBar = new("Frame", {
				Name = "AccentBar",
				BackgroundColor3 = selected and Color3.fromRGB(214, 182, 116) or Color3.fromRGB(106, 92, 74),
				BorderSizePixel = 0,
				Position = UDim2.new(0.02, 0, 0.14, 0),
				Size = UDim2.new(0, 4, 0.72, 0),
				Parent = card,
			})
			addCorner(accentBar, UDim.new(0, 4))

			local selectButton = new("TextButton", {
				Name = "SelectButton",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				Text = "",
				Parent = card,
			})

			local identityTitle = tostring(candidate:GetAttribute("PlayerTitle") or "Survivor")
			local levelValue = math.max(1, tonumber(candidate:GetAttribute("SkillTreeLevel")) or 1)
			local title = new("TextLabel", {
				Name = "Title",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 18, 0, 10),
				Size = UDim2.new(0.62, 0, 0, 22),
				Text = candidate == player and ("Self • " .. tostring(candidate.DisplayName or candidate.Name)) or tostring(candidate.DisplayName or candidate.Name),
				TextColor3 = Theme.Colors.Text,
				TextScaled = false,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Fonts.Heading,
				Parent = card,
			})
			local meta = new("TextLabel", {
				Name = "Meta",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 18, 0, 34),
				Size = UDim2.new(0.62, 0, 0, 16),
				Text = ("%s | Lv.%d"):format(identityTitle, levelValue),
				TextColor3 = Color3.fromRGB(214, 196, 172),
				TextScaled = false,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Fonts.Body,
				Parent = card,
			})
			local stateChip = new("TextLabel", {
				Name = "StateChip",
				BackgroundColor3 = selected and Color3.fromRGB(132, 98, 52) or Color3.fromRGB(58, 48, 36),
				BackgroundTransparency = 0.08,
				BorderSizePixel = 0,
				Position = UDim2.new(1, -92, 0.5, -14),
				Size = UDim2.new(0, 76, 0, 28),
				Text = selected and "Selected" or "Target",
				TextColor3 = Theme.Colors.Text,
				TextScaled = false,
				TextSize = 13,
				Font = Theme.Fonts.Heading,
				Parent = card,
			})
			addCorner(stateChip, UDim.new(0, 10))
			addStroke(stateChip, Color3.fromRGB(196, 166, 108), 0.2, 1)

			selectButton.MouseButton1Click:Connect(function()
				if candidate == player then
					selectedAdminTargetUserId = nil
				else
					selectedAdminTargetUserId = candidate.UserId
				end
				updateAdminTargetSummary()
				updateAdminControls()
				renderAdminTargetList()
			end)
		end

		updateAdminTargetSummary()
	end

	renderInvitePlayerList = function()
		clearGeneratedChildren(ui.Lobby.InvitePlayerList)
		ui.Lobby.InvitePlayerEmpty.Visible = #inviteablePlayers == 0

		for index, entry in ipairs(inviteablePlayers) do
			local card = makeListCard(ui.Lobby.InvitePlayerList, "InvitePlayer_" .. index, 86)
			card.LayoutOrder = index
			card.BackgroundColor3 = Color3.fromRGB(42, 56, 52)

			local accentBar = new("Frame", {
				Name = "AccentBar",
				BackgroundColor3 = entry.canInvite and Theme.Colors.AccentWarm or Color3.fromRGB(88, 174, 154),
				BorderSizePixel = 0,
				Position = UDim2.new(0.02, 0, 0.12, 0),
				Size = UDim2.new(0, 4, 0.76, 0),
				Parent = card,
			})
			addCorner(accentBar, UDim.new(0, 4))

			local title = new("TextLabel", {
				Name = "Title",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 18, 0, 12),
				Size = UDim2.new(1, -150, 0, 20),
				Text = trimLabel(entry.displayName, 20),
				TextColor3 = Theme.Colors.Text,
				TextScaled = false,
				TextSize = 17,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Fonts.Heading,
				Parent = card,
			})

			local subtitle = new("TextLabel", {
				Name = "Subtitle",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 18, 0, 38),
				Size = UDim2.new(1, -150, 0, 18),
				Text = entry.isSameSquad and "Already in your fireteam" or "Available for invite",
				TextColor3 = entry.isSameSquad and Theme.Colors.Muted or Theme.Colors.AccentSoft,
				TextScaled = false,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Fonts.Body,
				Parent = card,
			})

			local buttonText = entry.canInvite and "Invite" or "In Squad"
			local buttonColor = entry.canInvite and Theme.Colors.AccentWarm or Theme.Colors.Backdrop
			local button = makeListButton(card, "InviteButton", buttonText, UDim2.new(0.9, 0, 0.66, 0), UDim2.new(0.22, 0, 0.34, 0), buttonColor)
			button.TextSize = 14
			setButtonEnabled(button, entry.canInvite and not isRefreshingInvitePlayers, buttonColor)
			button.MouseButton1Click:Connect(function()
				requestSendInvite(entry.userId)
			end)
		end
	end

	renderDailyOpsItems = function()
		clearGeneratedChildren(ui.Lobby.QuestOpsList)
		local tasks = (dailyOpsState and dailyOpsState.tasks) or {}
		ui.Lobby.QuestOpsEmpty.Visible = #tasks == 0

		for index, entry in ipairs(tasks) do
			local card = makeListCard(ui.Lobby.QuestOpsList, "DailyOp_" .. index, 72)
			card.LayoutOrder = index
			card.BackgroundColor3 = entry.claimed and Color3.fromRGB(52, 66, 52) or Color3.fromRGB(50, 56, 46)

			local title = new("TextLabel", {
				Name = "Title",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 14, 0, 8),
				Size = UDim2.new(1, -152, 0, 18),
				Text = trimLabel(entry.displayName, 28),
				TextColor3 = Theme.Colors.Text,
				TextScaled = false,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Fonts.Heading,
				Parent = card,
			})

			local body = new("TextLabel", {
				Name = "Body",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 14, 0, 28),
				Size = UDim2.new(1, -172, 0, 14),
				Text = trimLabel(entry.description, 54),
				TextColor3 = Theme.Colors.Muted,
				TextScaled = false,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Fonts.Body,
				Parent = card,
			})

			local track = new("Frame", {
				Name = "ProgressTrack",
				BackgroundColor3 = Color3.fromRGB(32, 36, 30),
				BorderSizePixel = 0,
				Position = UDim2.new(0, 14, 1, -18),
				Size = UDim2.new(1, -168, 0, 8),
				Parent = card,
			})
			addCorner(track, UDim.new(0, 8))

			local fill = new("Frame", {
				Name = "ProgressFill",
				BackgroundColor3 = entry.claimed and Color3.fromRGB(124, 194, 116) or Color3.fromRGB(198, 214, 128),
				BorderSizePixel = 0,
				Size = UDim2.new(math.clamp(entry.progressPercent or 0, 0, 1), 0, 1, 0),
				Parent = track,
			})
			addCorner(fill, UDim.new(0, 8))

			local progressLabel = new("TextLabel", {
				Name = "ProgressLabel",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -94, 0, 10),
				Size = UDim2.new(0, 80, 0, 16),
				Text = ("%d/%d"):format(entry.progress or 0, entry.goal or 1),
				TextColor3 = entry.claimed and Color3.fromRGB(196, 240, 184) or Theme.Colors.AccentSoft,
				TextScaled = false,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
				Font = Theme.Fonts.Body,
				Parent = card,
			})

			local rewardLabel = new("TextLabel", {
				Name = "RewardLabel",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -94, 0, 28),
				Size = UDim2.new(0, 80, 0, 14),
				Text = ("+%dT +%dXP"):format(entry.rewardTokens or 0, entry.rewardExperience or 0),
				TextColor3 = Color3.fromRGB(232, 220, 164),
				TextScaled = false,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Right,
				Font = Theme.Fonts.Body,
				Parent = card,
			})

			local buttonColor = entry.claimed and Theme.Colors.Backdrop or Color3.fromRGB(176, 154, 88)
			local buttonText = entry.claimed and "Claimed" or (entry.canClaim and "Claim" or "Locked")
			local button = makeListButton(card, "ClaimButton", buttonText, UDim2.new(0.9, 0, 0.72, 0), UDim2.new(0.16, 0, 0.14, 0), buttonColor)
			button.TextSize = 13
			setButtonEnabled(button, entry.canClaim and not entry.claimed, buttonColor)
			button.MouseButton1Click:Connect(function()
				requestClaimDailyOp(entry.id)
			end)
		end
	end

	local function setDeployValue(value)
		if typeof(value) == "string" then
			currentDeployStatus = value
		elseif type(value) == "table" then
			if value.userId and value.userId ~= player.UserId then
				return
			end
			currentDeployStatus = tostring(value.message or value.status or currentDeployStatus)
			if value.message then
				currentSocialMessage = tostring(value.message)
			end
			if value.stage == "Loading" then
				enterLoading(currentDeployStatus, false)
				return
			elseif value.stage == "Deployment" then
				enterLoading(currentDeployStatus, false)
				task.defer(function()
					CinematicController.play(ui.Gui, ui.Root, value)
				end)
				return
			elseif value.stage == "Lobby" then
				CinematicController.stop(ui.Root)
				enterLobby(currentDeployStatus)
				refreshSquadDirectory()
				refreshDailyRewardState()
				refreshDailyOpsState()
				refreshWeeklyRewardState()
				return
			elseif value.stage == "Mission" then
				setMissionTelemetryValue(value)
				CinematicController.stop(ui.Root)
				enterMission(currentDeployStatus)
				return
			end
		end
		updateLobbyText()
	end

	setLobbyValue = function(payload)
		if type(payload) ~= "table" then
			return
		end

		if payload.tokens ~= nil or payload.balance ~= nil or payload.amount ~= nil then
			tokenBalance = tonumber(payload.tokens or payload.balance or payload.amount) or tokenBalance
		end

		if payload.status or payload.deployStatus then
			currentDeployStatus = tostring(payload.status or payload.deployStatus)
		end

		if payload.social or payload.announcement then
			currentSocialMessage = tostring(payload.social or payload.announcement)
		end

		if type(payload.nextMissionPreview) == "table" then
			nextMissionPreview = {
				scenarioName = tostring(payload.nextMissionPreview.scenarioName or nextMissionPreview.scenarioName),
				scenarioDescription = tostring(payload.nextMissionPreview.scenarioDescription or nextMissionPreview.scenarioDescription),
				layoutName = tostring(payload.nextMissionPreview.layoutName or nextMissionPreview.layoutName),
				layoutDescription = tostring(payload.nextMissionPreview.layoutDescription or nextMissionPreview.layoutDescription),
				modifierName = tostring(payload.nextMissionPreview.modifierName or nextMissionPreview.modifierName),
				modifierDescription = tostring(payload.nextMissionPreview.modifierDescription or nextMissionPreview.modifierDescription),
			}
		end
		if type(payload.nextMissionVote) == "table" then
			local incomingSessionId = tonumber(payload.nextMissionVote.sessionId) or 0
			if incomingSessionId ~= currentVoteSessionId then
				currentVoteSessionId = incomingSessionId
				currentVoteOptionId = nil
			end
			nextMissionVoteOptions = {}
			leadingMissionVoteOptionId = type(payload.nextMissionVote.leadingOptionId) == "string" and payload.nextMissionVote.leadingOptionId or nil
			for index, option in ipairs(payload.nextMissionVote.options or {}) do
				nextMissionVoteOptions[index] = {
					optionId = tostring(option.optionId or ("map_" .. tostring(index))),
					scenarioName = tostring(option.scenarioName or "Hold The Core"),
					layoutName = tostring(option.layoutName or "Breach Yard"),
					modifierName = tostring(option.modifierName or "Standard Ops"),
					modifierDescription = tostring(option.modifierDescription or ""),
					voteCount = tonumber(option.voteCount) or 0,
				}
			end
			if currentVoteOptionId then
				local voteStillExists = false
				for _, option in ipairs(nextMissionVoteOptions) do
					if option.optionId == currentVoteOptionId then
						voteStillExists = true
						break
					end
				end
				if not voteStillExists then
					currentVoteOptionId = nil
				end
			end
		end

		local shopTab = normalizeShopTab(payload.shopTab)
		if shopTab and Theme.ShopCopy[shopTab] then
			currentShopTab = shopTab
		end

		if payload.squad or payload.members then
			setSquadValue(payload.squad or payload.members)
		end

		if payload.stage == "Loading" then
			enterLoading(currentDeployStatus, false)
			return
		elseif payload.stage == "Lobby" then
			CinematicController.stop(ui.Root)
			enterLobby(currentDeployStatus)
			return
		elseif payload.stage == "Mission" or payload.phase == "Mission" then
			CinematicController.stop(ui.Root)
			enterMission(currentDeployStatus)
			return
		end

		updateLobbyText()
	end

	setPageVisibility(ui, "Home")
	animateHomeScreen(true)
	for _, popup in pairs(ui.Lobby.Popups) do
		popup.Visible = false
	end
	ui.Loading.Prompt.TextTransparency = 0
	updateLobbyText()

	styleButton(ui.Home.PlayButton, Theme.Colors.Accent)
	styleButton(ui.Lobby.ClaimDailyButton, Theme.Colors.Accent)
	styleButton(ui.Lobby.RefreshSquadsButton, Theme.Colors.AccentWarm)
	styleButton(ui.Lobby.InviteSquadButton, Theme.Colors.AccentWarm)
	styleButton(ui.Lobby.PrivacySquadButton, Theme.Colors.Backdrop)
	styleButton(ui.Lobby.LeaveSquadButton, Theme.Colors.Accent)
	styleButton(ui.Lobby.RefreshBoardButton, Theme.Colors.AccentWarm)
	styleButton(ui.Lobby.ShopQuickButton, Theme.Colors.AccentWarm)
	styleButton(ui.Lobby.InventoryQuickButton, Color3.fromRGB(86, 122, 176))
	styleButton(ui.Lobby.SkillTreeQuickButton, Color3.fromRGB(118, 132, 166))
	styleButton(ui.Lobby.SquadQuickButton, Color3.fromRGB(92, 146, 214))
	styleButton(ui.Lobby.InviteQuickButton, Color3.fromRGB(76, 158, 136))
	styleButton(ui.Lobby.SettingsQuickButton, Theme.Colors.Backdrop)
	styleButton(ui.Lobby.CloseShopButton, Theme.Colors.Backdrop)
	styleButton(ui.Lobby.InventoryWeaponTab, Color3.fromRGB(92, 122, 176))
	styleButton(ui.Lobby.InventoryCosmeticTab, Color3.fromRGB(84, 128, 184))
	styleButton(ui.Lobby.CloseInventoryButton, Theme.Colors.Backdrop)
	styleButton(ui.Lobby.CloseSkillTreeButton, Theme.Colors.Backdrop)
	styleButton(ui.Lobby.RespecSkillTreeButton, Theme.Colors.AccentWarm)
	styleButton(ui.Lobby.RespecConfirmAccept, Theme.Colors.AccentWarm)
	styleButton(ui.Lobby.RespecConfirmCancel, Theme.Colors.Backdrop)
	styleButton(ui.Lobby.CloseSquadButton, Theme.Colors.Backdrop)
	styleButton(ui.Lobby.CloseSocialButton, Theme.Colors.Backdrop)
	styleButton(ui.Lobby.ToggleUiAudioButton, Theme.Colors.AccentWarm)
	styleButton(ui.Lobby.ToggleScreenShakeButton, Color3.fromRGB(86, 122, 176))
	styleButton(ui.Lobby.CloseSettingsButton, Theme.Colors.Backdrop)
	styleButton(ui.Lobby.NpcDialogueActionButton, Theme.Colors.AccentWarm)
	styleButton(ui.Lobby.NpcDialogueCloseButton, Theme.Colors.Backdrop)
	styleButton(ui.Lobby.ClaimDailyQuestButton, Theme.Colors.AccentWarm)
	styleButton(ui.Lobby.ClaimWeeklyQuestButton, Color3.fromRGB(180, 154, 86))
	styleButton(ui.Lobby.CloseQuestBoardButton, Theme.Colors.Backdrop)
	styleButton(ui.Lobby.AcceptInviteButton, Theme.Colors.Accent)
	styleButton(ui.Lobby.DeclineInviteButton, Theme.Colors.Backdrop)
	styleButton(ui.Lobby.DeployButton, Theme.Colors.AccentWarm)
	if ui.Lobby.MissionVoteButtons then
		for _, button in ipairs(ui.Lobby.MissionVoteButtons) do
			styleButton(button, Theme.Colors.Backdrop)
		end
	end
	if ui.Lobby.SkillTreeFilterButtons then
		for filterName, button in pairs(ui.Lobby.SkillTreeFilterButtons) do
			local branchTheme = Theme.SkillTreeBranches[filterName]
			styleButton(button, filterName == "All" and Theme.Colors.AccentWarm or ((branchTheme and branchTheme.Color) or Theme.Colors.Backdrop))
		end
	end
	if ui.Lobby.ShopRarityButtons then
		for filterName, button in pairs(ui.Lobby.ShopRarityButtons) do
			local _, color = getRarityStyle(filterName == "All" and "Epic" or filterName)
			styleButton(button, filterName == "All" and Theme.Colors.AccentWarm or color)
		end
	end
	if ui.Lobby.ShopPremiumButtons then
		for filterName, button in pairs(ui.Lobby.ShopPremiumButtons) do
			local color = filterName == "Packs" and Color3.fromRGB(104, 214, 164)
				or (filterName == "Passes" and Color3.fromRGB(104, 168, 232)
				or (filterName == "Supporter" and Color3.fromRGB(214, 182, 96) or Theme.Colors.AccentWarm))
			styleButton(button, color)
		end
	end
	if ui.Lobby.InventoryRarityButtons then
		for filterName, button in pairs(ui.Lobby.InventoryRarityButtons) do
			local _, color = getRarityStyle(filterName == "All" and "Epic" or filterName)
			styleButton(button, filterName == "All" and Theme.Colors.AccentWarm or color)
		end
	end
	for tabName, button in pairs(ui.Lobby.ShopTabs) do
		styleButton(button, tabName == currentShopTab and Theme.Colors.AccentWarm or Theme.Colors.Backdrop)
	end

	ui.Home.PlayButton.MouseButton1Click:Connect(function()
		if state == "Home" then
			enterLoading("Preparing lobby...", true)
		end
	end)

	ui.Lobby.ClaimDailyButton.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			requestDailyReward()
		end
	end)

	ui.Lobby.RefreshSquadsButton.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			refreshSquadDirectory()
		end
	end)

	ui.Lobby.RefreshBoardButton.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			refreshSquadDirectory()
		end
	end)

	ui.Lobby.ShopQuickButton.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			setActivePopup("Shop")
			currentShopStatus = Theme.ShopCopy[currentShopTab] or currentShopStatus
			updateLobbyText()
		end
	end)

	ui.Lobby.InventoryQuickButton.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			setInventoryTab("Weapons")
			setActivePopup("Inventory")
		end
	end)

	ui.Lobby.SkillTreeQuickButton.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			setActivePopup("SkillTree")
			currentSkillTreeStatus = "Allocate points to unlock deeper branch nodes."
			updateLobbyText()
		end
	end)

	ui.Lobby.SquadQuickButton.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			setActivePopup("Squad")
			refreshSquadDirectory()
			updateLobbyText()
		end
	end)

	ui.Lobby.InviteQuickButton.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			setActivePopup("Social")
			refreshSquadDirectory()
			refreshInviteablePlayers()
			currentSocialMessage = "Pick a survivor from the roster and send the invite."
			updateLobbyText()
		end
	end)

	ui.Lobby.SettingsQuickButton.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			setActivePopup("Settings")
			updateLobbyText()
		end
	end)

	ui.Lobby.CloseShopButton.MouseButton1Click:Connect(function()
		setActivePopup(nil)
	end)

	ui.Lobby.DeployButton.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			requestDeploy()
		end
	end)
	if ui.Lobby.MissionVoteButtons then
		for _, button in ipairs(ui.Lobby.MissionVoteButtons) do
			button.MouseButton1Click:Connect(function()
				if state == "Lobby" then
					local optionId = button:GetAttribute("VoteOptionId")
					if type(optionId) == "string" and optionId ~= "" then
						requestMapVote(optionId)
					end
				end
			end)
		end
	end

	ui.Lobby.InventoryWeaponTab.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			setInventoryTab("Weapons")
		end
	end)

	ui.Lobby.InventoryCosmeticTab.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			setInventoryTab("Cosmetics")
		end
	end)

	ui.Lobby.CloseInventoryButton.MouseButton1Click:Connect(function()
		setActivePopup(nil)
	end)

	ui.Lobby.CloseSkillTreeButton.MouseButton1Click:Connect(function()
		setActivePopup(nil)
	end)
	if ui.Lobby.SkillTreeFilterButtons then
		for filterName, button in pairs(ui.Lobby.SkillTreeFilterButtons) do
			button.MouseButton1Click:Connect(function()
				if state == "Lobby" then
					currentSkillTreeBranchFilter = filterName
					updateLobbyText()
				end
			end)
		end
	end
	ui.Lobby.RespecConfirmCancel.MouseButton1Click:Connect(function()
		pendingRespecConfirmation = false
		updateLobbyText()
	end)
	ui.Lobby.RespecConfirmAccept.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			requestRespecSkillTree()
		end
	end)

	ui.Lobby.CloseSquadButton.MouseButton1Click:Connect(function()
		setActivePopup(nil)
	end)

	ui.Lobby.CloseSocialButton.MouseButton1Click:Connect(function()
		setActivePopup(nil)
	end)

	ui.Lobby.NpcDialogueActionButton.MouseButton1Click:Connect(function()
		if state ~= "Lobby" or not pendingNpcDialogue then
			return
		end
		local actionPanel = pendingNpcDialogue.actionPanel
		local panelName = normalizeStationPanelName(actionPanel)
		pendingNpcDialogue = nil
		if actionPanel == "QuestBoard" then
			setActivePopup("QuestBoard")
			refreshDailyRewardState()
			refreshDailyOpsState()
			refreshWeeklyRewardState()
			refreshSubscriptionState()
		elseif panelName == "Social" then
			setActivePopup("Social")
			refreshSquadDirectory()
			refreshInviteablePlayers()
		elseif panelName == "Inventory" then
			setInventoryTab("Weapons")
			setActivePopup("Inventory")
		elseif panelName == "SkillTree" then
			setActivePopup("SkillTree")
			currentSkillTreeStatus = "Allocate points to unlock deeper branch nodes."
		elseif panelName == "Squad" then
			setActivePopup("Squad")
			refreshSquadDirectory()
		elseif panelName == "Shop" then
			setActivePopup("Shop")
		else
			setActivePopup(nil)
		end
		updateLobbyText()
	end)

	ui.Lobby.NpcDialogueCloseButton.MouseButton1Click:Connect(function()
		pendingNpcDialogue = nil
		if activePopup == "NpcDialogue" then
			setActivePopup(nil)
		end
		updateLobbyText()
	end)

	ui.Lobby.ClaimDailyQuestButton.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			requestDailyReward()
		end
	end)

	ui.Lobby.ClaimWeeklyQuestButton.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			requestWeeklyReward()
		end
	end)

	ui.Lobby.CloseQuestBoardButton.MouseButton1Click:Connect(function()
		setActivePopup(nil)
	end)

	ui.Lobby.ToggleUiAudioButton.MouseButton1Click:Connect(function()
		uiAudioEnabled = not uiAudioEnabled
		SoundService:SetAttribute("UiAudioEnabled", uiAudioEnabled)
		updateLobbyText()
	end)

	ui.Lobby.ToggleScreenShakeButton.MouseButton1Click:Connect(function()
		screenShakeEnabled = not screenShakeEnabled
		if not screenShakeEnabled then
			cameraKick = Vector2.zero
		end
		updateLobbyText()
	end)

	ui.Lobby.CloseSettingsButton.MouseButton1Click:Connect(function()
		setActivePopup(nil)
	end)

	ui.Lobby.AdminButton.MouseButton1Click:Connect(function()
		if progression.identity and (progression.identity.isModerator == true or progression.identity.isAdmin == true or progression.identity.isOwner == true) then
			setAdminTab("Session")
			setActivePopup("Admin")
			requestAdminCommand({
				commandId = "get_panel_state",
			})
			if renderAdminTargetList then
				renderAdminTargetList()
			end
			updateLobbyText()
		end
	end)

	ui.Lobby.AdminHealButton.MouseButton1Click:Connect(function()
		requestAdminCommand("heal_self")
	end)

	ui.Lobby.AdminHealSquadButton.MouseButton1Click:Connect(function()
		requestAdminCommand("heal_squad")
	end)

	ui.Lobby.AdminTokensButton.MouseButton1Click:Connect(function()
		requestAdminCommand("grant_tokens")
	end)

	ui.Lobby.AdminTokensLargeButton.MouseButton1Click:Connect(function()
		requestAdminCommand("grant_tokens_large")
	end)

	ui.Lobby.AdminXpButton.MouseButton1Click:Connect(function()
		requestAdminCommand("grant_xp")
	end)

	ui.Lobby.AdminXpLargeButton.MouseButton1Click:Connect(function()
		requestAdminCommand("grant_xp_large")
	end)

	ui.Lobby.AdminReviveSquadButton.MouseButton1Click:Connect(function()
		requestAdminCommand("revive_squad")
	end)

	ui.Lobby.AdminReturnButton.MouseButton1Click:Connect(function()
		requestAdminCommand("return_to_lobby")
	end)

	ui.Lobby.AdminRefreshButton.MouseButton1Click:Connect(function()
		requestAdminCommand("refresh_access")
	end)

	ui.Lobby.AdminGrantTokensTargetButton.MouseButton1Click:Connect(function()
		requestAdminTargetCommand("grant_tokens_target")
	end)

	ui.Lobby.AdminGrantXpTargetButton.MouseButton1Click:Connect(function()
		requestAdminTargetCommand("grant_xp_target")
	end)

	ui.Lobby.AdminHealTargetButton.MouseButton1Click:Connect(function()
		requestAdminTargetCommand("heal_target")
	end)

	ui.Lobby.AdminGrantWeaponsButton.MouseButton1Click:Connect(function()
		requestAdminTargetCommand("unlock_all_weapons_target")
	end)

	ui.Lobby.AdminGrantCosmeticsButton.MouseButton1Click:Connect(function()
		requestAdminTargetCommand("unlock_all_cosmetics_target")
	end)

	ui.Lobby.AdminTerminateButton.MouseButton1Click:Connect(function()
		requestAdminTargetCommand("terminate_player")
	end)

	ui.Lobby.AdminRoleModButton.MouseButton1Click:Connect(function()
		requestAdminTargetCommand("promote_moderator")
	end)

	ui.Lobby.AdminRoleAdminButton.MouseButton1Click:Connect(function()
		requestAdminTargetCommand("promote_admin")
	end)

	ui.Lobby.AdminRoleClearButton.MouseButton1Click:Connect(function()
		requestAdminTargetCommand("clear_access")
	end)

	ui.Lobby.AdminBanButton.MouseButton1Click:Connect(function()
		requestAdminTargetCommand("ban_player")
	end)

	ui.Lobby.AdminEventAutoButton.MouseButton1Click:Connect(function()
		requestAdminCommand("event_auto")
	end)

	ui.Lobby.AdminEventOffButton.MouseButton1Click:Connect(function()
		requestAdminCommand("event_none")
	end)

	ui.Lobby.AdminEventSpringButton.MouseButton1Click:Connect(function()
		requestAdminCommand("event_spring")
	end)

	ui.Lobby.AdminEventHarvestButton.MouseButton1Click:Connect(function()
		requestAdminCommand("event_harvest")
	end)

	ui.Lobby.AdminEventWinterButton.MouseButton1Click:Connect(function()
		requestAdminCommand("event_winter")
	end)

	ui.Lobby.AdminSkipWaveButton.MouseButton1Click:Connect(function()
		requestAdminCommand("skip_wave")
	end)

	ui.Lobby.AdminForceBossButton.MouseButton1Click:Connect(function()
		requestAdminCommand("force_boss")
	end)

	ui.Lobby.AdminRefillAmmoButton.MouseButton1Click:Connect(function()
		requestAdminCommand("refill_ammo")
	end)

	ui.Lobby.AdminTeleportSquadButton.MouseButton1Click:Connect(function()
		requestAdminCommand("teleport_squad")
	end)

	ui.Lobby.AdminSpawnBruteButton.MouseButton1Click:Connect(function()
		requestAdminCommand("spawn_brute")
	end)

	ui.Lobby.AdminSpawnRunnerButton.MouseButton1Click:Connect(function()
		requestAdminCommand("spawn_runner")
	end)

	ui.Lobby.AdminGiveDropsButton.MouseButton1Click:Connect(function()
		requestAdminCommand("give_all_drops")
	end)

	ui.Lobby.AdminSpawnSupportBotsButton.MouseButton1Click:Connect(function()
		requestAdminCommand("spawn_support_bots")
	end)

	ui.Lobby.AdminToggleSupportBotsButton.MouseButton1Click:Connect(function()
		requestAdminCommand("toggle_support_bots_auto")
	end)

	if ui.Lobby.AdminTabs then
		for tabKey, tabButton in pairs(ui.Lobby.AdminTabs) do
			tabButton.MouseButton1Click:Connect(function()
				setAdminTab(tabKey)
			end)
		end
	end

	ui.Lobby.CloseAdminButton.MouseButton1Click:Connect(function()
		setActivePopup(nil)
	end)

	Players.PlayerAdded:Connect(function()
		if renderAdminTargetList then
			renderAdminTargetList()
		end
	end)

	Players.PlayerRemoving:Connect(function(leavingPlayer)
		if selectedAdminTargetUserId == leavingPlayer.UserId then
			selectedAdminTargetUserId = nil
		end
		if renderAdminTargetList then
			renderAdminTargetList()
		end
	end)

	ui.Lobby.AcceptInviteButton.MouseButton1Click:Connect(function()
		respondToInvite(true)
	end)

	ui.Lobby.DeclineInviteButton.MouseButton1Click:Connect(function()
		respondToInvite(false)
	end)

	ui.Lobby.RespecSkillTreeButton.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			pendingRespecConfirmation = true
			updateLobbyText()
		end
	end)

	ui.Lobby.ResultsContinue.MouseButton1Click:Connect(function()
		pendingResults = nil
		hideResultsPopup()
	end)

	ui.Lobby.LeaveSquadButton.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			requestLeaveSquad()
		end
	end)

	ui.Lobby.InviteSquadButton.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			setActivePopup("Social")
			refreshInviteablePlayers()
			currentSocialMessage = "Pick a survivor from the roster and send the invite."
			updateLobbyText()
		end
	end)

	ui.Lobby.PrivacySquadButton.MouseButton1Click:Connect(function()
		if state == "Lobby" then
			requestSetSquadPrivacy(not (player:GetAttribute("SquadLocked") == true))
		end
	end)

	for tabName, button in pairs(ui.Lobby.ShopTabs) do
		button.MouseButton1Click:Connect(function()
			currentShopStatus = Theme.ShopCopy[tabName] or currentShopStatus
			setShopTab(tabName)
		end)
	end
	if ui.Lobby.ShopRarityButtons then
		for filterName, button in pairs(ui.Lobby.ShopRarityButtons) do
			button.MouseButton1Click:Connect(function()
				if state == "Lobby" then
					currentShopRarityFilter = filterName
					updateLobbyText()
				end
			end)
		end
	end
	if ui.Lobby.ShopPremiumButtons then
		for filterName, button in pairs(ui.Lobby.ShopPremiumButtons) do
			button.MouseButton1Click:Connect(function()
				if state == "Lobby" then
					currentShopPremiumFilter = filterName
					updateLobbyText()
				end
			end)
		end
	end
	if ui.Lobby.InventoryRarityButtons then
		for filterName, button in pairs(ui.Lobby.InventoryRarityButtons) do
			button.MouseButton1Click:Connect(function()
				if state == "Lobby" then
					currentInventoryRarityFilter = filterName
					updateLobbyText()
				end
			end)
		end
	end

	local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if state == "Loading" and awaitingContinuePrompt and os.clock() - loadingStartedAt > 0.15 then
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then
				enterLobby()
				refreshDailyRewardState()
				refreshDailyOpsState()
				refreshWeeklyRewardState()
				refreshShopCatalog()
				refreshSquadDirectory()
				refreshInviteablePlayers()
			end
		end
	end)

	local gamePassPromptConnection = MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(finishedPlayer, gamePassId, wasPurchased)
		if finishedPlayer ~= player then
			return
		end

		if wasPurchased then
			currentShopStatus = ("Game pass granted: %d. Refreshing entitlements."):format(tonumber(gamePassId) or 0)
			refreshEntitlements()
		else
			currentShopStatus = "Game pass purchase canceled."
		end
		updateLobbyText()
	end)

	local promptConnection = ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if state ~= "Lobby" or not prompt then
			return
		end

		local duelAction = prompt:GetAttribute("DuelAction")
		if duelAction ~= nil then
			requestDuel(duelAction)
			return
		end

		if prompt.Name == "LobbyNpcPrompt" or prompt:GetAttribute("NpcDialogueTitle") ~= nil then
			pendingNpcDialogue = {
				title = prompt:GetAttribute("NpcDialogueTitle"),
				role = prompt:GetAttribute("NpcDialogueRole"),
				body = prompt:GetAttribute("NpcDialogueBody"),
				actionLabel = prompt:GetAttribute("NpcActionLabel"),
				actionPanel = prompt:GetAttribute("NpcActionPanel"),
			}
			setActivePopup("NpcDialogue")
			updateLobbyText()
			return
		end

		local panelName = normalizeStationPanelName(prompt.ObjectText)
			or normalizeStationPanelName(prompt.ActionText)
			or normalizeStationPanelName(prompt.Parent and prompt.Parent.Name)
		if panelName then
			openStationPanel(panelName)
		end
	end)

	local promptShownConnection = ProximityPromptService.PromptShown:Connect(function(prompt)
		if not prompt then
			return
		end

		local inMission = state == "Mission" or player:GetAttribute("InMission") == true
		if inMission and prompt:GetAttribute("MissionPrompt") ~= true then
			suppressedMissionPrompts[prompt] = true
			prompt.Enabled = false
		end
	end)

	local leaderboardPlayerConnections = {}
	local function bindLeaderboardPlayer(candidate)
		if leaderboardPlayerConnections[candidate] then
			return
		end
		leaderboardPlayerConnections[candidate] = {
			candidate:GetAttributeChangedSignal("SkillTreeLevel"):Connect(updateLobbyText),
			candidate:GetAttributeChangedSignal("MissionsCompleted"):Connect(updateLobbyText),
			candidate:GetAttributeChangedSignal("ZombiesDefeated"):Connect(updateLobbyText),
			candidate:GetAttributeChangedSignal("AllTimeMissionsCompleted"):Connect(updateLobbyText),
			candidate:GetAttributeChangedSignal("AllTimeZombiesDefeated"):Connect(updateLobbyText),
			candidate:GetAttributeChangedSignal("WeeklyMissionsCompleted"):Connect(updateLobbyText),
			candidate:GetAttributeChangedSignal("WeeklyZombiesDefeated"):Connect(updateLobbyText),
			candidate:GetAttributeChangedSignal("DailyMissionsCompleted"):Connect(updateLobbyText),
			candidate:GetAttributeChangedSignal("DailyZombiesDefeated"):Connect(updateLobbyText),
			candidate:GetAttributeChangedSignal("LeaderboardRank"):Connect(updateLobbyText),
		}
	end

	local function unbindLeaderboardPlayer(candidate)
		local connections = leaderboardPlayerConnections[candidate]
		if not connections then
			return
		end
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		leaderboardPlayerConnections[candidate] = nil
	end

	for _, candidate in ipairs(Players:GetPlayers()) do
		bindLeaderboardPlayer(candidate)
	end
	local leaderboardPlayerAddedConnection = Players.PlayerAdded:Connect(function(candidate)
		bindLeaderboardPlayer(candidate)
		updateLobbyText()
	end)
	local leaderboardPlayerRemovingConnection = Players.PlayerRemoving:Connect(function(candidate)
		unbindLeaderboardPlayer(candidate)
		updateLobbyText()
	end)

	local remoteCleanup = Remotes.bind({
		[RemoteNames.Events.LobbyStateChanged] = setLobbyValue,
		[RemoteNames.Events.TokenBalanceChanged] = setTokenValue,
		[RemoteNames.Events.SquadUpdated] = setSquadValue,
		[RemoteNames.Events.DeployStateChanged] = setDeployValue,
		[RemoteNames.Events.CombatFeedback] = handleCombatFeedback,
		[RemoteNames.Events.Notification] = function(message)
			if type(message) == "table" then
				if message.userId and message.userId ~= player.UserId then
					return
				end
				if message.kind == "Results" then
					showResultsPopup(message)
					return
				elseif message.kind == "DailyOpsProgress" then
					local lines = type(message.lines) == "table" and message.lines or {}
					for _, line in ipairs(lines) do
						if type(line) == "table" then
							local title = line.complete and "Daily Op Complete" or "Daily Op Updated"
							local progressText = ("%d/%d"):format(tonumber(line.progress) or 0, tonumber(line.goal) or 1)
							local body = ("%s • %s"):format(tostring(line.displayName or "Daily Op"), progressText)
							local rewardText = nil
							if line.complete then
								rewardText = ("+%dT +%dXP"):format(
									tonumber(line.rewardTokens) or 0,
									tonumber(line.rewardExperience) or 0
								)
							end
							pushMissionToast(
								title,
								body,
								line.complete and Color3.fromRGB(188, 214, 128) or Color3.fromRGB(122, 170, 220),
								line.complete == true,
								rewardText
							)
						end
					end
					return
				elseif message.kind == "Invite" then
					pendingInvite = message
					currentSocialMessage = tostring(message.message or currentSocialMessage)
					playUiSound(SOUND_IDS.Alert, 0.32, 1.02)
					updateLobbyText()
					return
				end
				currentSocialMessage = tostring(message.message or message.status or currentSocialMessage)
				if string.find(currentSocialMessage, "Warning", 1, true) then
					playUiSound(SOUND_IDS.Alert, 0.28, 0.98)
				end
				updateLobbyText()
			elseif typeof(message) == "string" then
				currentSocialMessage = message
				if string.find(currentSocialMessage, "Warning", 1, true) then
					playUiSound(SOUND_IDS.Alert, 0.28, 0.98)
				end
				updateLobbyText()
			end
		end,
		[RemoteNames.Events.ShopStateChanged] = function(payload)
			if type(payload) == "table" then
				local shopTab = normalizeShopTab(payload.tab or payload.category)
				if shopTab and Theme.ShopCopy[shopTab] then
					currentShopTab = shopTab
					local category = Theme.ShopTabToCategory[shopTab]
					local item = findShopItem(category, payload.itemId)
					if item then
						local isEquipUpdate = payload.equippedWeapon ~= nil or payload.equippedCosmetic ~= nil
						currentShopStatus = isEquipUpdate
							and ("Equipped %s."):format(item.DisplayName or item.Id)
							or ("Unlocked %s."):format(item.DisplayName or item.Id)
						if isEquipUpdate then
							currentInventoryStatus = currentShopStatus
						end
					end
					if payload.equippedWeapon then
						progression.equippedWeapon = tostring(payload.equippedWeapon)
						currentInventoryTab = "Weapons"
					end
					if payload.equippedCosmetic ~= nil then
						progression.equippedCosmetic = payload.equippedCosmetic ~= "" and tostring(payload.equippedCosmetic) or nil
						if progression.equippedCosmetic then
							currentInventoryTab = "Cosmetics"
						end
					end
					if activePopup == "Inventory" and (payload.equippedWeapon ~= nil or payload.equippedCosmetic ~= nil) then
						setActivePopup("Inventory")
					else
						setActivePopup("Shop")
					end
					updateLobbyText()
				end
			elseif typeof(payload) == "string" then
				local shopTab = normalizeShopTab(payload)
				if shopTab and Theme.ShopCopy[shopTab] then
					currentShopTab = shopTab
					currentShopStatus = Theme.ShopCopy[shopTab]
					setActivePopup("Shop")
					updateLobbyText()
				end
			end
		end,
		[RemoteNames.Events.ProgressionUpdated] = function(payload)
			setProgressionValue(payload)
		end,
		[RemoteNames.Events.SubscriptionStateChanged] = function(payload)
			setSubscriptionStateValue(payload)
		end,
		[RemoteNames.Events.PersistenceStateChanged] = function(payload)
			setPersistenceStateValue(payload)
		end,
	})

	local function applyBootstrap(bootstrap)
		if bootstrap.tokenBalance ~= nil then
			setTokenValue(bootstrap.tokenBalance)
		end
		if bootstrap.squadSnapshot ~= nil then
			setSquadValue(bootstrap.squadSnapshot)
		end
		if bootstrap.squadDirectory ~= nil then
			setSquadDirectoryValue(bootstrap.squadDirectory)
		end
		if bootstrap.inviteablePlayers ~= nil then
			setInviteablePlayersValue(bootstrap.inviteablePlayers)
		end
		if bootstrap.dailyRewardState ~= nil then
			setDailyRewardValue(bootstrap.dailyRewardState)
		end
		if bootstrap.dailyOpsState ~= nil then
			setDailyOpsValue(bootstrap.dailyOpsState)
		end
		if bootstrap.weeklyRewardState ~= nil then
			setWeeklyRewardValue(bootstrap.weeklyRewardState)
		end
		if bootstrap.subscriptionState ~= nil then
			setSubscriptionStateValue(bootstrap.subscriptionState)
		end
		if bootstrap.seasonalEventState ~= nil then
			setSeasonalEventValue(bootstrap.seasonalEventState)
		end
		if bootstrap.shopCatalog ~= nil then
			setShopCatalogValue(bootstrap.shopCatalog)
		end
		if bootstrap.progression ~= nil then
			setProgressionValue(bootstrap.progression)
		end
		if bootstrap.persistenceState ~= nil then
			setPersistenceStateValue(bootstrap.persistenceState)
		end
		if bootstrap.lobbyState ~= nil then
			setLobbyValue(bootstrap.lobbyState)
		end
	end

	enterHome()
	task.defer(function()
		for _ = 1, 20 do
			local callOk, bootstrap = safeInvoke(RemoteNames.Functions.GetBootstrapData)
			if callOk and type(bootstrap) == "table" then
				applyBootstrap(bootstrap)
				return
			end
			task.wait(0.25)
		end

		refreshDailyRewardState()
		refreshDailyOpsState()
		refreshWeeklyRewardState()
		refreshSubscriptionState()
		refreshShopCatalog()
		refreshSquadDirectory()
		refreshInviteablePlayers()
		updateLobbyText()
	end)

	task.spawn(function()
		while ui.Gui.Parent and player.Parent do
			enforceUiState()
			task.wait(0.75)
		end
	end)

	local function cleanup()
		if inputConnection then
			inputConnection:Disconnect()
		end
		if promptConnection then
			promptConnection:Disconnect()
		end
		if promptShownConnection then
			promptShownConnection:Disconnect()
		end
		if leaderboardPlayerAddedConnection then
			leaderboardPlayerAddedConnection:Disconnect()
		end
		if leaderboardPlayerRemovingConnection then
			leaderboardPlayerRemovingConnection:Disconnect()
		end
		for candidate in pairs(leaderboardPlayerConnections) do
			unbindLeaderboardPlayer(candidate)
		end
		if promptTween then
			promptTween:Cancel()
		end
		if remoteCleanup then
			remoteCleanup()
		end
	end

	return cleanup
end

return FlowController
