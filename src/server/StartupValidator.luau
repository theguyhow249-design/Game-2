--[[
	StartupValidator - Validates that all game systems are properly initialized
	Runs checks on server startup to ensure the game is ready to play
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StartupValidator = {}
local REQUIRED_LOBBY_CHILDREN = {
	{ label = "LobbySpawn", names = { "LobbySpawn" } },
	{ label = "MissionStaging", names = { "MissionStaging" } },
	{ label = "map vote", names = { "map vote", "Vote Model", "VoteBoard", "DeployVoteDeck" } },
	{ label = "donation", names = { "donation", "SupportTerminal", "SupporterLounge", "SupportNode", "DonateBoard" } },
	{ label = "Leaderboard (Levels)", names = { "Leaderboard (Levels)", "LeaderboardMonument" } },
	{ label = "Leaderboard (Runs)", names = { "Leaderboard (Runs)", "LeaderboardMonument" } },
	{ label = "Leaderboard (Kills)", names = { "Leaderboard (Kills)", "leaderboard (Kills)", "LeaderboardMonument" } },
	{ label = "TrainingYard", names = { "TrainingYard" } },
	{ label = "ParkourCourse", names = { "ParkourCourse" } },
	{ label = "TargetRange", names = { "TargetRange" } },
	{ label = "SalvageRun", names = { "SalvageRun" } },
}
local REQUIRED_ACTIVITY_PARTS = {
	TrainingYard = { "EntryPad", "TargetFace1", "TargetFace2", "TargetFace3", "Hurdle1", "Hurdle2", "Hurdle3" },
	ParkourCourse = { "StartPad", "Platform1", "Platform2", "Platform3", "Platform4", "Platform5", "FinishPad" },
	TargetRange = { "FiringLine", "TargetFace1", "TargetFace2", "TargetFace3" },
	SalvageRun = { "StartPad", "Cache1", "Cache2", "Cache3", "FinishPad" },
}

local function findRequiredDescendant(root: Instance, name: string): Instance?
	return root:FindFirstChild(name, true)
end

local function findAnyNamedDescendant(root: Instance, names: { string }): Instance?
	for _, name in ipairs(names) do
		local found = root:FindFirstChild(name, true)
		if found then
			return found
		end
	end
	return nil
end

local function collectMissingChildren(root: Instance, requiredEntries): { string }
	local missing = {}
	for _, entry in ipairs(requiredEntries) do
		if type(entry) == "string" then
			if not findRequiredDescendant(root, entry) then
				table.insert(missing, entry)
			end
		elseif type(entry) == "table" then
			local names = type(entry.names) == "table" and entry.names or {}
			if not findAnyNamedDescendant(root, names) then
				table.insert(missing, tostring(entry.label or names[1] or "unknown"))
			end
		end
	end
	return missing
end

local function validateRequiredActivityParts(lobbyRoot: Instance): boolean
	local valid = true
	for activityName, requiredNames in pairs(REQUIRED_ACTIVITY_PARTS) do
		local activityRoot = findRequiredDescendant(lobbyRoot, activityName)
		if activityRoot then
			local missing = collectMissingChildren(activityRoot, requiredNames)
			if #missing > 0 then
				warn(("[StartupValidator] ⚠️  %s is missing required parts: %s"):format(activityName, table.concat(missing, ", ")))
				valid = false
			end
		end
	end
	return valid
end

local function checkLobbySetup()
	local lobbyConfig = require(script.Parent:WaitForChild("LobbyWorldConfig"))
	local lobbyRoot = Workspace:FindFirstChild(lobbyConfig.RootName)
	
	if not lobbyRoot then
		warn("[StartupValidator] ⚠️  Lobby root folder not found. LobbyWorld.start() may have failed.")
		return false
	end
	
	local missingLobbyChildren = collectMissingChildren(lobbyRoot, REQUIRED_LOBBY_CHILDREN)
	if #missingLobbyChildren > 0 then
		warn("[StartupValidator] ⚠️  Lobby root is missing required objects: " .. table.concat(missingLobbyChildren, ", "))
	end
	
	-- Check for mission staging
	local missionStaging = findRequiredDescendant(lobbyRoot, "MissionStaging")
	if not missionStaging then
		warn("[StartupValidator] ⚠️  MissionStaging not found. Mission deployment will fail.")
		return false
	end

	local missionMissing = collectMissingChildren(missionStaging, {
		{ label = "MissionSpawn", names = { "MissionSpawn", "DropMarker", "Base" } },
		{ label = "MissionCameraStart", names = { "MissionCameraStart" } },
		{ label = "MissionCameraEnd", names = { "MissionCameraEnd", "MissionCameraStop" } },
	})
	if #missionMissing > 0 then
		warn("[StartupValidator] ⚠️  MissionStaging is missing required objects: " .. table.concat(missionMissing, ", "))
		return false
	end
	
	-- Check for camera paths
	local cameraStartPath = Workspace:GetAttribute("MissionCameraStartPath")
	local cameraEndPath = Workspace:GetAttribute("MissionCameraEndPath")
	local missionSpawnPath = Workspace:GetAttribute("MissionSpawnPath")
	
	if not cameraStartPath or cameraStartPath == "" then
		warn("[StartupValidator] ⚠️  MissionCameraStartPath not set. Deployment cinematic will not work.")
	end
	if not cameraEndPath or cameraEndPath == "" then
		warn("[StartupValidator] ⚠️  MissionCameraEndPath not set. Deployment cinematic will not work.")
	end
	if not missionSpawnPath or missionSpawnPath == "" then
		warn("[StartupValidator] ⚠️  MissionSpawnPath not set. Players won't be teleported to mission.")
		return false
	end

	if not validateRequiredActivityParts(lobbyRoot) then
		return false
	end
	
	print("[StartupValidator] ✓ Lobby setup validated")
	return true
end

local function checkRemotesSetup()
	local remoteFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remoteFolder then
		warn("[StartupValidator] ⚠️  Remotes folder not found in ReplicatedStorage.")
		return false
	end
	
	-- Check for essential remotes
	local essentialEvents = {
		"DeployStateChanged",
		"CombatFeedback",
		"Notification",
		"FlowChanged",
		"LobbyStateChanged",
	}
	
	local missingEvents = {}
	for _, eventName in ipairs(essentialEvents) do
		if not remoteFolder:FindFirstChild(eventName) then
			table.insert(missingEvents, eventName)
		end
	end
	
	if #missingEvents > 0 then
		warn("[StartupValidator] ⚠️  Missing remote events: " .. table.concat(missingEvents, ", "))
		return false
	end
	
	print("[StartupValidator] ✓ Remotes validated")
	return true
end

local function checkSharedConfigsLoaded()
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local requiredConfigs = {
		"GameFlowConfig",
		"MissionConfig", 
		"RemoteNames",
		"TokenEconomy",
		"SquadConfig",
		"Contracts",
	}
	
	local missingConfigs = {}
	for _, configName in ipairs(requiredConfigs) do
		if not Shared:FindFirstChild(configName) then
			table.insert(missingConfigs, configName)
		end
	end
	
	if #missingConfigs > 0 then
		warn("[StartupValidator] ⚠️  Missing shared configs: " .. table.concat(missingConfigs, ", "))
		return false
	end
	
	print("[StartupValidator] ✓ Shared configs validated")
	return true
end

local function runChecks(label, checks)
	print(("\n========== %s =========="):format(label))

	local passed = 0
	for _, check in ipairs(checks) do
		if check() then
			passed = passed + 1
		end
	end

	print(("========== VALIDATION COMPLETE: %d/%d checks passed ==========\n"):format(passed, #checks))

	return passed == #checks
end

function StartupValidator.runPreflight()
	return runChecks("GAME STARTUP PREFLIGHT", {
		checkSharedConfigsLoaded,
	})
end

function StartupValidator.runPostStartupValidation()
	return runChecks("GAME STARTUP VALIDATION", {
		checkSharedConfigsLoaded,
		checkRemotesSetup,
		checkLobbySetup,
	})
end

function StartupValidator.runValidation()
	return StartupValidator.runPostStartupValidation()
end

return StartupValidator
