local Players = game:GetService("Players")
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

function LeaderboardService.new(context)
	local self = setmetatable({}, LeaderboardService)
	self._persistenceService = context.PersistenceService
	self._gameFlowConfig = context.GameFlowConfig
	self._sessionStartedAt = {}
	self._committedMinutes = {}
	self._playerConnections = {}
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
		table.insert(entries, {
			player = player,
			name = tostring(player.DisplayName or player.Name or "Operator"),
			level = safeNumber(player:GetAttribute("SkillTreeLevel"), safeNumber(player:GetAttribute("Level"), 1)),
			runs = safeNumber(stats.missionsCompleted, 0),
			kills = safeNumber(stats.zombiesDefeated, 0),
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

function LeaderboardService:RefreshWorldBoard()
	local entries = self:_buildEntries()
	self:_applyTopRanks(entries)

	self:_setBoardColumnText("Levels", self:_formatBoardLines(self:_sortEntries(entries, "level"), "level", function(value)
		return ("Level %d"):format(value)
	end))
	self:_setBoardColumnText("Runs", self:_formatBoardLines(self:_sortEntries(entries, "runs"), "runs", function(value)
		return ("%d run%s"):format(value, value == 1 and "" or "s")
	end))
	self:_setBoardColumnText("Kills", self:_formatBoardLines(self:_sortEntries(entries, "kills"), "kills", function(value)
		return ("%d kill%s"):format(value, value == 1 and "" or "s")
	end))
end

function LeaderboardService:_applyPlayerAttributes(player)
	local stats = self._persistenceService:GetStats(player)
	player:SetAttribute("TimePlayedMinutes", tonumber(stats.timePlayedMinutes) or 0)
	player:SetAttribute("DonationScore", tonumber(stats.donationScore) or 0)
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
			self:RefreshWorldBoard()
		end),
		player:GetAttributeChangedSignal("MissionsCompleted"):Connect(function()
			self:RefreshWorldBoard()
		end),
		player:GetAttributeChangedSignal("ZombiesDefeated"):Connect(function()
			self:RefreshWorldBoard()
		end),
	}
	self:RefreshWorldBoard()
end

function LeaderboardService:UnbindPlayer(player)
	self:CommitPlaytime(player)
	self._sessionStartedAt[player.UserId] = nil
	self._committedMinutes[player.UserId] = nil
	if self._playerConnections[player] then
		for _, connection in ipairs(self._playerConnections[player]) do
			connection:Disconnect()
		end
		self._playerConnections[player] = nil
	end
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
		self:RefreshWorldBoard()
	end)

	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in ipairs(Players:GetPlayers()) do
				self:CommitPlaytime(player)
			end
			self:RefreshWorldBoard()
		end
	end)
end

return LeaderboardService
