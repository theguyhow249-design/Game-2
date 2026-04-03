local LobbyWorld = require(script:WaitForChild("LobbyWorld"))
local ServerSystems = require(script:WaitForChild("ServerSystems"))
local DeploymentRuntime = require(script:WaitForChild("DeploymentRuntime"))
local StartupValidator = require(script:WaitForChild("StartupValidator"))

print("[Server] Initializing game server...")

-- Validate game setup
if not StartupValidator.runPreflight() then
	warn("[Server] ⚠️  Preflight checks failed. Shared configuration is incomplete.")
end

print("[Server] Starting LobbyWorld...")
LobbyWorld.start()

print("[Server] Starting ServerSystems...")
local systems = ServerSystems.start()

print("[Server] Starting DeploymentRuntime...")
DeploymentRuntime.start(systems)

if not StartupValidator.runPostStartupValidation() then
	warn("[Server] ⚠️  Some post-start validation checks failed. The game may not be fully playable.")
end

print("[Server] Server initialization complete!")
