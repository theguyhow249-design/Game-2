--[[
	STARTUP_TEST.luau - Quick verification that game initializes correctly
	Run this after game loads to verify system health
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("\n===== GAME STARTUP TEST =====\n")

-- Test 1: Check Workspace attributes set correctly
print("Test 1: Checking Workspace attributes...")
local missionSpawn = Workspace:GetAttribute("MissionSpawnPath")
local cameraStart = Workspace:GetAttribute("MissionCameraStartPath")
local cameraEnd = Workspace:GetAttribute("MissionCameraEndPath")

if missionSpawn and missionSpawn ~= "" then
	print("  ✅ MissionSpawnPath set")
else
	print("  ⚠️  MissionSpawnPath NOT set")
end

if cameraStart and cameraStart ~= "" then
	print("  ✅ MissionCameraStartPath set")
else
	print("  ⚠️  MissionCameraStartPath NOT set")
end

if cameraEnd and cameraEnd ~= "" then
	print("  ✅ MissionCameraEndPath set")
else
	print("  ⚠️  MissionCameraEndPath NOT set")
end

-- Test 2: Check Remotes folder
print("\nTest 2: Checking Remotes...")
local Shared = ReplicatedStorage:FindFirstChild("Shared")
local remotes = ReplicatedStorage:FindFirstChild("Remotes")

if remotes then
	print("  ✅ Remotes folder found")
	
	local events = {"DeployStateChanged", "CombatFeedback", "Notification", "FlowChanged"}
	for _, eventName in ipairs(events) do
		if remotes:FindFirstChild(eventName) then
			print(("  ✅ %s event exists"):format(eventName))
		else
			print(("  ⚠️  %s event missing"):format(eventName))
		end
	end
else
	print("  ❌ Remotes folder NOT found")
end

-- Test 3: Check shared configs
print("\nTest 3: Checking Shared configs...")
if Shared then
	local configs = {"GameFlowConfig", "MissionConfig", "RemoteNames", "TokenEconomy"}
	for _, configName in ipairs(configs) do
		if Shared:FindFirstChild(configName) then
			print(("  ✅ %s loaded"):format(configName))
		else
			print(("  ⚠️  %s NOT found"):format(configName))
		end
	end
else
	print("  ❌ Shared folder NOT found")
end

-- Test 4: Check lobby exists
print("\nTest 4: Checking Lobby...")
local lobbyRoot = Workspace:FindFirstChild("LobbyHub")
if lobbyRoot then
	print("  ✅ Lobby root exists (LobbyHub)")
	
	local missionStaging = lobbyRoot:FindFirstChild("MissionStaging")
	if missionStaging then
		print("  ✅ MissionStaging exists")
	else
		print("  ⚠️  MissionStaging NOT found")
	end
else
	print("  ⚠️  Lobby root NOT found")
end

print("\n===== TEST COMPLETE =====\n")
print("Interpretation:")
print("  ✅ = System ready")
print("  ⚠️  = Might need attention but won't break game")
print("  ❌ = Critical issue")
