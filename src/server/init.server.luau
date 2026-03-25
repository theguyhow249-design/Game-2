local LobbyWorld = require(script:WaitForChild("LobbyWorld"))
local ServerSystems = require(script:WaitForChild("ServerSystems"))
local DeploymentRuntime = require(script:WaitForChild("DeploymentRuntime"))

LobbyWorld.start()

local systems = ServerSystems.start()
DeploymentRuntime.start(systems)
