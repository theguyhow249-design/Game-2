local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LeaderboardService = {}
LeaderboardService.__index = LeaderboardService

local TOP_RANK_THEMES = {
	[1] = {
		id = "galaxy",
		label = "Galaxy Crown",
		primary = Color3.fromRGB(172, 110, 255),
		secondary = Color3.fromRGB(88, 220, 255),
	},
	[2] = {
		id = "solar",
		label = "Solar Crest",
		primary = Color3.fromRGB(255, 194, 94),
		secondary = Color3.fromRGB(255, 120, 72),
	},
	[3] = {
		id = "aurora",
		label = "Aurora Mark",
		primary = Color3.fromRGB(108, 242, 214),
		secondary = Color3.fromRGB(94, 164, 255),
	},
}

local TOP_RANK_TITLES = {
	[1] = "Apex Warden",
	[2] = "Rift Runner",
	[3] = "Iron Ghost",
}

local WINDOW_CONFIG = {
	allTime = {
		label = "ALL TIME",
		attributePrefix = "AllTime",
		storeSuffix = "AllTime",
	},
	monthly = {
		label = "MONTHLY",
		attributePrefix = "Monthly",
		storeSuffix = "Monthly",
	},
	weekly = {
		label = "THIS WEEK",
		attributePrefix = "Weekly",
		storeSuffix = "Weekly",
	},
	daily = {
		label = "TODAY",
		attributePrefix = "Daily",
		storeSuffix = "Daily",
	},
}

local GLOBAL_REFRESH_SECONDS = 60
local WORLD_SCROLL_STEP = 4
local PUBLISH_FLUSH_SECONDS = 30

function LeaderboardService.new(context)
	local self = setmetatable({}, LeaderboardService)
	self._persistenceService = context.PersistenceService
	self._gameFlowConfig = context.GameFlowConfig
	self._sessionStartedAt = {}
	self._committedMinutes = {}
	self._playerConnections = {}
	self._orderedStores = {}
	self._nameCache = {}
	self._publishQueue = {}
	self._lastPublishedValues = {}
	for windowName, windowInfo in pairs(WINDOW_CONFIG) do
		self._orderedStores[windowName] = {}
		for _, categoryKey in ipairs({ "Levels", "Runs", "Kills" }) do
			local storeName = ("ZombieSurvivalLeaderboard_v1_%s_%s"):format(categoryKey, windowInfo.storeSuffix)
			local ok, store = pcall(function()
				return DataStoreService:GetOrderedDataStore(storeName)
			end)
			if ok then
				self._orderedStores[windowName][categoryKey] = store
			end
		end
	end
	self._worldBoardCycle = { "Levels", "Runs", "Kills" }
	self._worldBoardIndex = 1
	self._worldBoardWindow = "allTime"
	self._worldBoardScrollIndex = 1
	self._worldControlConnections = {}
	return self
end

local function colorToHex(color)
	return string.format("%02X%02X%02X", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))
end

local function safeNumber(value, fallback)
	local parsed = tonumber(value)
	if parsed == nil then
		return fallback or 0
	end
	return parsed
end

function LeaderboardService:_buildEntries()
	local entries = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local stats = self._persistenceService:GetStats(player) or {}
		local monthlyStats = self._persistenceService:GetStatsWindow(player, "monthly") or {}
		local weeklyStats = self._persistenceService:GetStatsWindow(player, "weekly") or {}
		local dailyStats = self._persistenceService:GetStatsWindow(player, "daily") or {}
		table.insert(entries, {
			player = player,
			name = tostring(player.DisplayName or player.Name or "Operator"),
			level = safeNumber(player:GetAttribute("SkillTreeLevel"), safeNumber(player:GetAttribute("Level"), 1)),
			runs = safeNumber(stats.missionsCompleted, 0),
			kills = safeNumber(stats.zombiesDefeated, 0),
			monthlyRuns = safeNumber(monthlyStats.missionsCompleted, 0),
			monthlyKills = safeNumber(monthlyStats.zombiesDefeated, 0),
			weeklyRuns = safeNumber(weeklyStats.missionsCompleted, 0),
			weeklyKills = safeNumber(weeklyStats.zombiesDefeated, 0),
			dailyRuns = safeNumber(dailyStats.missionsCompleted, 0),
			dailyKills = safeNumber(dailyStats.zombiesDefeated, 0),
		})
	end
	return entries
end

function LeaderboardService:_sortEntries(entries, key)
	local clone = {}
	for _, entry in ipairs(entries) do
		table.insert(clone, entry)
	end
	table.sort(clone, function(a, b)
		local aValue = safeNumber(a[key], 0)
		local bValue = safeNumber(b[key], 0)
		if aValue ~= bValue then
			return aValue > bValue
		end
		local aLevel = safeNumber(a.level, 0)
		local bLevel = safeNumber(b.level, 0)
		if aLevel ~= bLevel then
			return aLevel > bLevel
		end
		local aRuns = safeNumber(a.runs, 0)
		local bRuns = safeNumber(b.runs, 0)
		if aRuns ~= bRuns then
			return aRuns > bRuns
		end
		local aKills = safeNumber(a.kills, 0)
		local bKills = safeNumber(b.kills, 0)
		if aKills ~= bKills then
			return aKills > bKills
		end
		return tostring(a.name) < tostring(b.name)
	end)
	return clone
end

function LeaderboardService:_applyTopRanks(entries)
	local overall = self:_sortEntries(entries, "level")
	local rankByUserId = {}
	for rank = 1, math.min(3, #overall) do
		local entry = overall[rank]
		if entry.player then
			rankByUserId[entry.player.UserId] = rank
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local rank = rankByUserId[player.UserId] or 0
		local theme = TOP_RANK_THEMES[rank]
		player:SetAttribute("LeaderboardRank", rank)
		player:SetAttribute("LeaderboardTheme", theme and theme.id or "")
		player:SetAttribute("LeaderboardThemeLabel", theme and theme.label or "")
	end
end

function LeaderboardService:_formatBoardLines(entries, key, formatter)
	if #entries == 0 then
		return "No data yet."
	end

	local lines = {}
	for index = 1, math.min(4, #entries) do
		local entry = entries[index]
		local nameText = tostring(entry.name)
		local valueText = formatter(safeNumber(entry[key], 0))
		local line = index == 1
			and ("<font size=\"22\">%d. %s</font>\n<font size=\"19\">%s</font>"):format(index, nameText, valueText)
			or ("%d. %s\n%s"):format(index, nameText, valueText)
		local theme = TOP_RANK_THEMES[index]
		if theme then
			line = ("<font color=\"#%s\">%s</font>"):format(colorToHex(theme.primary), line)
		end
		lines[index] = line
	end
	return table.concat(lines, "\n\n")
end

function LeaderboardService:_setBoardColumnText(columnName, text)
	local lobbyRoot = Workspace:FindFirstChild(self._gameFlowConfig.LobbyName)
	local plaza = lobbyRoot and lobbyRoot:FindFirstChild("OpenSkyLobby")
	local monument = plaza and plaza:FindFirstChild("LeaderboardMonument")
	local boardFace = monument and monument:FindFirstChild("BoardFace")
	local boardGui = boardFace and boardFace:FindFirstChild("BoardGui")
	local frame = boardGui and boardGui:FindFirstChild("Frame")
	local column = frame and frame:FindFirstChild(columnName .. "Column")
	local body = column and column:FindFirstChild("Body")
	if body and body:IsA("TextLabel") then
		body.Text = text
	end
end

function LeaderboardService:_setBoardHeaderText(text)
	local lobbyRoot = Workspace:FindFirstChild(self._gameFlowConfig.LobbyName)
	local plaza = lobbyRoot and lobbyRoot:FindFirstChild("OpenSkyLobby")
	local monument = plaza and plaza:FindFirstChild("LeaderboardMonument")
	local boardFace = monument and monument:FindFirstChild("BoardFace")
	local boardGui = boardFace and boardFace:FindFirstChild("BoardGui")
	local frame = boardGui and boardGui:FindFirstChild("Frame")
	local header = frame and frame:FindFirstChild("Header")
	if header and header:IsA("TextLabel") then
		header.Text = text
	end
end

function LeaderboardService:_setWorldBoardText(boardName, headerText, subheaderText, bodyText)
	local lobbyRoot = Workspace:FindFirstChild(self._gameFlowConfig.LobbyName)
	local plaza = lobbyRoot and lobbyRoot:FindFirstChild("OpenSkyLobby")
	local monument = plaza and plaza:FindFirstChild("LeaderboardMonument")
	local boardFace = monument and monument:FindFirstChild(boardName)
	local boardGui = boardFace and boardFace:FindFirstChild("BoardGui")
	local frame = boardGui and boardGui:FindFirstChild("Frame")
	local header = frame and frame:FindFirstChild("Header")
	local subheader = frame and frame:FindFirstChild("Subheader")
	local body = frame and frame:FindFirstChild("Body")
	local bodyScroll = frame and frame:FindFirstChild("BodyScroll")
	if header and header:IsA("TextLabel") then
		header.Text = headerText
	end
	if subheader and subheader:IsA("TextLabel") then
		subheader.Text = subheaderText
	end
	if body and body:IsA("TextLabel") then
		body.Text = bodyText
		local newlineCount = select(2, string.gsub(bodyText or "", "\n", ""))
		local estimatedHeight = math.max(420, (newlineCount + 1) * 24)
		body.Size = UDim2.new(1, -20, 0, estimatedHeight)
		if bodyScroll and bodyScroll:IsA("ScrollingFrame") then
			bodyScroll.CanvasSize = UDim2.fromOffset(0, estimatedHeight + 24)
		end
	end
end

function LeaderboardService:_getWorldBoardFrame()
	local lobbyRoot = Workspace:FindFirstChild(self._gameFlowConfig.LobbyName)
	local plaza = lobbyRoot and lobbyRoot:FindFirstChild("OpenSkyLobby")
	local monument = plaza and plaza:FindFirstChild("LeaderboardMonument")
	local boardFace = monument and monument:FindFirstChild("MasterBoard")
	local boardGui = boardFace and boardFace:FindFirstChild("BoardGui")
	return boardGui and boardGui:FindFirstChild("Frame")
end

function LeaderboardService:_setMasterBoardTabState(frame, categoryKey)
	if not frame then
		return
	end

	frame:SetAttribute("ActiveCategory", categoryKey)
	local tabMap = {
		Levels = "LevelsTab",
		Runs = "RunsTab",
		Kills = "KillsTab",
	}
	for key, tabName in pairs(tabMap) do
		local tab = frame:FindFirstChild(tabName)
		if tab and tab:IsA("TextLabel") then
			local isActive = key == categoryKey
			tab.TextTransparency = isActive and 0 or 0.06
		end
	end
end

function LeaderboardService:_setMasterBoardWindowState(frame, windowName)
	if not frame then
		return
	end

	frame:SetAttribute("ActiveWindow", windowName)
	local windowMap = {
		allTime = "AllTimeWindow",
		monthly = "MonthlyWindow",
		weekly = "WeeklyWindow",
		daily = "DailyWindow",
	}
	for key, buttonName in pairs(windowMap) do
		local button = frame:FindFirstChild(buttonName)
		local stroke = button and button:FindFirstChild("Stroke")
		if button and button:IsA("TextLabel") then
			local isActive = key == windowName
			button.BackgroundColor3 = isActive and Color3.fromRGB(206, 222, 238) or Color3.fromRGB(228, 224, 214)
			button.TextColor3 = isActive and Color3.fromRGB(24, 38, 62) or Color3.fromRGB(58, 48, 34)
			if stroke and stroke:IsA("UIStroke") then
				stroke.Color = isActive and Color3.fromRGB(102, 166, 236) or Color3.fromRGB(168, 154, 132)
				stroke.Transparency = isActive and 0.06 or 0.28
			end
		end
	end
end

function LeaderboardService:_setMasterWorldBoard(categoryKey, headerText, subheaderText, bodyText, valueHeaderText)
	local frame = self:_getWorldBoardFrame()
	if not frame then
		return
	end

	local header = frame:FindFirstChild("Header")
	local subheader = frame:FindFirstChild("Subheader")
	local listHeader = frame:FindFirstChild("ListHeader")
	local body = frame:FindFirstChild("Body")
	local bodyScroll = frame:FindFirstChild("BodyScroll")
	if header and header:IsA("TextLabel") then
		header.Text = headerText
	end
	if subheader and subheader:IsA("TextLabel") then
		subheader.Text = subheaderText
	end
	if listHeader and listHeader:IsA("TextLabel") then
		listHeader.Text = string.format("#   Username                              %s", valueHeaderText)
	end
	if body and body:IsA("TextLabel") then
		body.Text = bodyText
		local newlineCount = select(2, string.gsub(bodyText or "", "\n", ""))
		local estimatedHeight = math.max(1200, (newlineCount + 1) * 24)
		body.Size = UDim2.new(1, -20, 0, estimatedHeight)
		if bodyScroll and bodyScroll:IsA("ScrollingFrame") then
			bodyScroll.CanvasSize = UDim2.fromOffset(0, estimatedHeight + 24)
			bodyScroll.CanvasPosition = Vector2.new(0, math.max(0, (self._worldBoardScrollIndex - 1) * 74))
		end
	end

	self:_setMasterBoardTabState(frame, categoryKey)
	self:_setMasterBoardWindowState(frame, self._worldBoardWindow)
end

function LeaderboardService:_setWorldBoardCountdown(secondsRemaining)
	local frame = self:_getWorldBoardFrame()
	local countdownText = ("REFRESH IN %02ds"):format(math.max(0, math.floor(secondsRemaining or 0)))
	local countdown = frame and frame:FindFirstChild("Countdown")
	if countdown and countdown:IsA("TextLabel") then
		countdown.Text = countdownText
	end
end

function LeaderboardService:_formatSingleBoardLines(entries, formatter)
	local lines = {}
	local maxEntries = 100
	for index = 1, maxEntries do
		local entry = entries[index]
		local nameText = entry and tostring(entry.name or ("User " .. tostring(entry.userId or 0))) or "Awaiting operator"
		local valueText = entry and formatter(safeNumber(entry.value, 0)) or "No record yet"
		local titleText = TOP_RANK_TITLES[index]
		local line = titleText
			and ("%d. %s\n%s\n%s"):format(index, nameText, titleText, valueText)
			or ("%d. %s\n%s"):format(index, nameText, valueText)
		local theme = TOP_RANK_THEMES[index]
		if theme then
			line = ("<font color=\"#%s\">%s</font>"):format(colorToHex(theme.primary), line)
		elseif not entry then
			line = ("<font color=\"#8A93A2\">%s</font>"):format(line)
		end
		lines[index] = line
	end
	return table.concat(lines, "\n\n")
end

function LeaderboardService:_publishPlayerScores(player)
	if not player then
		return
	end
	local userId = player.UserId
	local stats = self._persistenceService:GetStats(player) or {}
	local monthlyStats = self._persistenceService:GetStatsWindow(player, "monthly") or {}
	local weeklyStats = self._persistenceService:GetStatsWindow(player, "weekly") or {}
	local dailyStats = self._persistenceService:GetStatsWindow(player, "daily") or {}
	local values = {
		allTime = {
			Levels = safeNumber(player:GetAttribute("SkillTreeLevel"), safeNumber(player:GetAttribute("Level"), 1)),
			Runs = safeNumber(stats.missionsCompleted, 0),
			Kills = safeNumber(stats.zombiesDefeated, 0),
		},
		monthly = {
			Levels = safeNumber(player:GetAttribute("SkillTreeLevel"), safeNumber(player:GetAttribute("Level"), 1)),
			Runs = safeNumber(monthlyStats.missionsCompleted, 0),
			Kills = safeNumber(monthlyStats.zombiesDefeated, 0),
		},
		weekly = {
			Levels = safeNumber(player:GetAttribute("SkillTreeLevel"), safeNumber(player:GetAttribute("Level"), 1)),
			Runs = safeNumber(weeklyStats.missionsCompleted, 0),
			Kills = safeNumber(weeklyStats.zombiesDefeated, 0),
		},
		daily = {
			Levels = safeNumber(player:GetAttribute("SkillTreeLevel"), safeNumber(player:GetAttribute("Level"), 1)),
			Runs = safeNumber(dailyStats.missionsCompleted, 0),
			Kills = safeNumber(dailyStats.zombiesDefeated, 0),
		},
	}
	self._publishQueue[userId] = values
	self._nameCache[userId] = tostring(player.DisplayName or player.Name or ("User " .. tostring(userId)))
end

function LeaderboardService:_flushPublishedScoresForUserId(userId)
	local queuedValues = self._publishQueue[userId]
	if not queuedValues then
		return
	end

	self._lastPublishedValues[userId] = self._lastPublishedValues[userId] or {}
	local previousValues = self._lastPublishedValues[userId]
	for windowName, bucket in pairs(queuedValues) do
		previousValues[windowName] = previousValues[windowName] or {}
		for categoryKey, value in pairs(bucket) do
			local store = self._orderedStores[windowName] and self._orderedStores[windowName][categoryKey]
			local lastValue = previousValues[windowName][categoryKey]
			if store and lastValue ~= value then
				local ok = pcall(function()
					store:SetAsync(tostring(userId), value)
				end)
				if ok then
					previousValues[windowName][categoryKey] = value
				end
			end
		end
	end

	self._publishQueue[userId] = nil
end

function LeaderboardService:_flushPublishedScores()
	if RunService:IsStudio() then
		for userId, _ in pairs(self._publishQueue) do
			self._lastPublishedValues[userId] = self._publishQueue[userId]
			self._publishQueue[userId] = nil
		end
		return
	end

	for userId, _ in pairs(self._publishQueue) do
		self:_flushPublishedScoresForUserId(userId)
	end
end

function LeaderboardService:_resolveDisplayName(userId)
	if self._nameCache[userId] then
		return self._nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		local displayName = tostring(player.DisplayName or player.Name or ("User " .. tostring(userId)))
		self._nameCache[userId] = displayName
		return displayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local displayName = ok and tostring(name) or ("User " .. tostring(userId))
	self._nameCache[userId] = displayName
	return displayName
end

function LeaderboardService:_getGlobalEntries(windowName, categoryKey, limit)
	local store = self._orderedStores[windowName] and self._orderedStores[windowName][categoryKey]
	if not store then
		return {}
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, limit or 100)
	end)
	if not ok or not pages then
		return {}
	end
	local page = pages:GetCurrentPage()
	local entries = {}
	for index = 1, math.min(limit or 100, #page) do
		local item = page[index]
		local userId = tonumber(item.key)
		if userId then
			table.insert(entries, {
				userId = userId,
				name = self:_resolveDisplayName(userId),
				value = safeNumber(item.value, 0),
			})
		end
	end
	return entries
end

function LeaderboardService:_advanceWorldBoardCategory()
	self._worldBoardIndex = (self._worldBoardIndex % #self._worldBoardCycle) + 1
	self._worldBoardScrollIndex = 1
	self:_refreshGlobalWorldBoards()
end

function LeaderboardService:_setWorldBoardWindow(windowName)
	if not WINDOW_CONFIG[windowName] then
		return
	end
	self._worldBoardWindow = windowName
	self._worldBoardScrollIndex = 1
	self:_refreshGlobalWorldBoards()
end

function LeaderboardService:_scrollWorldBoard(direction)
	local maxStart = 97
	self._worldBoardScrollIndex = math.clamp(self._worldBoardScrollIndex + direction, 1, maxStart)
	self:_refreshGlobalWorldBoards()
end

function LeaderboardService:_primeWorldBoardData()
	self._globalEntriesCache = {}
	for windowName, _ in pairs(WINDOW_CONFIG) do
		self._globalEntriesCache[windowName] = {
			Levels = self:_getGlobalEntries(windowName, "Levels", 100),
			Runs = self:_getGlobalEntries(windowName, "Runs", 100),
			Kills = self:_getGlobalEntries(windowName, "Kills", 100),
		}
	end
end

function LeaderboardService:_refreshGlobalWorldBoards()
	local categoryKey = self._worldBoardCycle[self._worldBoardIndex] or "Levels"
	local windowName = WINDOW_CONFIG[self._worldBoardWindow] and self._worldBoardWindow or "allTime"
	local entries = (self._globalEntriesCache and self._globalEntriesCache[windowName] and self._globalEntriesCache[windowName][categoryKey]) or {}
	local windowLabel = WINDOW_CONFIG[windowName] and WINDOW_CONFIG[windowName].label or "ALL TIME"
	if categoryKey == "Levels" then
		self:_setMasterWorldBoard(
			"Levels",
			"Top Operators",
			("GLOBAL %s • TOP 100 • LEVELS"):format(windowLabel),
			self:_formatSingleBoardLines(entries, function(value)
				return ("Level %d"):format(value)
			end),
			"Level"
		)
	elseif categoryKey == "Runs" then
		self:_setMasterWorldBoard(
			"Runs",
			"Top Operators",
			("GLOBAL %s • TOP 100 • RUNS"):format(windowLabel),
			self:_formatSingleBoardLines(entries, function(value)
				return ("%d run%s"):format(value, value == 1 and "" or "s")
			end),
			"Runs"
		)
	else
		self:_setMasterWorldBoard(
			"Kills",
			"Top Operators",
			("GLOBAL %s • TOP 100 • KILLS"):format(windowLabel),
			self:_formatSingleBoardLines(entries, function(value)
				return ("%d kill%s"):format(value, value == 1 and "" or "s")
			end),
			"Kills"
		)
	end
end

function LeaderboardService:_bindWorldBoardControls()
	if self._worldControlsBound then
		return
	end

	local lobbyRoot = Workspace:FindFirstChild(self._gameFlowConfig.LobbyName)
	local plaza = lobbyRoot and lobbyRoot:FindFirstChild("OpenSkyLobby")
	local monument = plaza and plaza:FindFirstChild("LeaderboardMonument")
	local controls = monument and monument:FindFirstChild("Controls")
	if not controls then
		return
	end

	local bindings = {
		AllTimeButton = function()
			self:_setWorldBoardWindow("allTime")
		end,
		MonthlyButton = function()
			self:_setWorldBoardWindow("monthly")
		end,
		WeeklyButton = function()
			self:_setWorldBoardWindow("weekly")
		end,
		DailyButton = function()
			self:_setWorldBoardWindow("daily")
		end,
		LevelsButton = function()
			self._worldBoardIndex = 1
			self._worldBoardScrollIndex = 1
			self:_refreshGlobalWorldBoards()
		end,
		RunsButton = function()
			self._worldBoardIndex = 2
			self._worldBoardScrollIndex = 1
			self:_refreshGlobalWorldBoards()
		end,
		KillsButton = function()
			self._worldBoardIndex = 3
			self._worldBoardScrollIndex = 1
			self:_refreshGlobalWorldBoards()
		end,
		ScrollUpButton = function()
			self:_scrollWorldBoard(-WORLD_SCROLL_STEP)
		end,
		ScrollDownButton = function()
			self:_scrollWorldBoard(WORLD_SCROLL_STEP)
		end,
	}

	for partName, callback in pairs(bindings) do
		local button = controls:FindFirstChild(partName)
		local detector = button and button:FindFirstChildOfClass("ClickDetector")
		local prompt = button and button:FindFirstChild("Prompt")
		if detector then
			table.insert(self._worldControlConnections, detector.MouseClick:Connect(callback))
		end
		if prompt and prompt:IsA("ProximityPrompt") then
			table.insert(self._worldControlConnections, prompt.Triggered:Connect(function()
				callback()
			end))
		end
	end

	self._worldControlsBound = true
end

function LeaderboardService:RefreshWorldBoard(windowName)
	local entries = self:_buildEntries()
	self:_applyTopRanks(entries)
	local targetWindow = WINDOW_CONFIG[windowName] and windowName or (self._currentWindow or "allTime")
	self._currentWindow = targetWindow
	local headerLabel = WINDOW_CONFIG[targetWindow].label
	self:_setBoardHeaderText(("OUTPOST LEADERBOARD • %s"):format(headerLabel))

	local runsKey = targetWindow == "daily" and "dailyRuns"
		or (targetWindow == "weekly" and "weeklyRuns"
		or (targetWindow == "monthly" and "monthlyRuns" or "runs"))
	local killsKey = targetWindow == "daily" and "dailyKills"
		or (targetWindow == "weekly" and "weeklyKills"
		or (targetWindow == "monthly" and "monthlyKills" or "kills"))

	self:_setBoardColumnText("Levels", self:_formatBoardLines(self:_sortEntries(entries, "level"), "level", function(value)
		return ("Level %d"):format(value)
	end))
	self:_setBoardColumnText("Runs", self:_formatBoardLines(self:_sortEntries(entries, runsKey), runsKey, function(value)
		return ("%d run%s"):format(value, value == 1 and "" or "s")
	end))
	self:_setBoardColumnText("Kills", self:_formatBoardLines(self:_sortEntries(entries, killsKey), killsKey, function(value)
		return ("%d kill%s"):format(value, value == 1 and "" or "s")
	end))
	self:_refreshGlobalWorldBoards()
end

function LeaderboardService:_applyPlayerAttributes(player)
	local stats = self._persistenceService:GetStats(player)
	local monthlyStats = self._persistenceService:GetStatsWindow(player, "monthly")
	local weeklyStats = self._persistenceService:GetStatsWindow(player, "weekly")
	local dailyStats = self._persistenceService:GetStatsWindow(player, "daily")
	player:SetAttribute("TimePlayedMinutes", tonumber(stats.timePlayedMinutes) or 0)
	player:SetAttribute("DonationScore", tonumber(stats.donationScore) or 0)
	player:SetAttribute("AllTimeMissionsCompleted", tonumber(stats.missionsCompleted) or 0)
	player:SetAttribute("AllTimeZombiesDefeated", tonumber(stats.zombiesDefeated) or 0)
	player:SetAttribute("MonthlyMissionsCompleted", tonumber(monthlyStats.missionsCompleted) or 0)
	player:SetAttribute("MonthlyZombiesDefeated", tonumber(monthlyStats.zombiesDefeated) or 0)
	player:SetAttribute("WeeklyMissionsCompleted", tonumber(weeklyStats.missionsCompleted) or 0)
	player:SetAttribute("WeeklyZombiesDefeated", tonumber(weeklyStats.zombiesDefeated) or 0)
	player:SetAttribute("DailyMissionsCompleted", tonumber(dailyStats.missionsCompleted) or 0)
	player:SetAttribute("DailyZombiesDefeated", tonumber(dailyStats.zombiesDefeated) or 0)
end

function LeaderboardService:BindPlayer(player)
	self._sessionStartedAt[player.UserId] = os.time()
	self._committedMinutes[player.UserId] = 0
	self:_applyPlayerAttributes(player)
	if self._playerConnections[player] then
		for _, connection in ipairs(self._playerConnections[player]) do
			connection:Disconnect()
		end
	end
	self._playerConnections[player] = {
		player:GetAttributeChangedSignal("SkillTreeLevel"):Connect(function()
			self:_publishPlayerScores(player)
			self:RefreshWorldBoard()
		end),
		player:GetAttributeChangedSignal("MissionsCompleted"):Connect(function()
			self:_publishPlayerScores(player)
			self:RefreshWorldBoard()
		end),
		player:GetAttributeChangedSignal("ZombiesDefeated"):Connect(function()
			self:_publishPlayerScores(player)
			self:RefreshWorldBoard()
		end),
	}
	self:_publishPlayerScores(player)
	self:RefreshWorldBoard()
end

function LeaderboardService:UnbindPlayer(player)
	self:CommitPlaytime(player)
	self:_flushPublishedScoresForUserId(player.UserId)
	self._sessionStartedAt[player.UserId] = nil
	self._committedMinutes[player.UserId] = nil
	if self._playerConnections[player] then
		for _, connection in ipairs(self._playerConnections[player]) do
			connection:Disconnect()
		end
		self._playerConnections[player] = nil
	end
	self._publishQueue[player.UserId] = nil
	self._lastPublishedValues[player.UserId] = nil
	self:RefreshWorldBoard()
end

function LeaderboardService:CommitPlaytime(player)
	local startedAt = self._sessionStartedAt[player.UserId]
	if not startedAt then
		return
	end

	local sessionMinutes = math.max(0, math.floor((os.time() - startedAt) / 60))
	local committedMinutes = self._committedMinutes[player.UserId] or 0
	local delta = sessionMinutes - committedMinutes
	if delta > 0 then
		self._persistenceService:IncrementStat(player, "timePlayedMinutes", delta)
		self._committedMinutes[player.UserId] = committedMinutes + delta
	end
	self:_applyPlayerAttributes(player)
	self:RefreshWorldBoard()
end

function LeaderboardService:AddDonationScore(player, amount)
	local donationAmount = math.max(0, math.floor(amount or 0))
	if donationAmount <= 0 then
		return
	end

	self._persistenceService:IncrementStat(player, "donationScore", donationAmount)
	self:_applyPlayerAttributes(player)
	self:RefreshWorldBoard()
end

function LeaderboardService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:BindPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:UnbindPlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:BindPlayer(player)
	end

	task.defer(function()
		self:_bindWorldBoardControls()
		self:_primeWorldBoardData()
		self:RefreshWorldBoard()
	end)

	task.spawn(function()
		local remaining = GLOBAL_REFRESH_SECONDS
		self:_setWorldBoardCountdown(remaining)
		while true do
			task.wait(1)
			remaining -= 1
			if remaining <= 0 then
				for _, player in ipairs(Players:GetPlayers()) do
					self:CommitPlaytime(player)
				end
				self:_flushPublishedScores()
				self:_primeWorldBoardData()
				self:RefreshWorldBoard()
				remaining = GLOBAL_REFRESH_SECONDS
			end
			self:_setWorldBoardCountdown(remaining)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(PUBLISH_FLUSH_SECONDS)
			self:_flushPublishedScores()
		end
	end)
end

return LeaderboardService
