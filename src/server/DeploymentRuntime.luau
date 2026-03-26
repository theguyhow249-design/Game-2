local Workspace = game:GetService("Workspace")

local LobbyWorldConfig = require(script.Parent:WaitForChild("LobbyWorldConfig"))

local DeploymentRuntime = {}

local function findMissionSpawn()
	local root = Workspace:FindFirstChild(LobbyWorldConfig.RootName)
	if not root then
		return nil
	end

	local mission = root:FindFirstChild("MissionStaging")
	if not mission then
		return nil
	end

	return mission:FindFirstChild("MissionSpawn")
end

local function getDeploymentOffset(index: number): Vector3
	local formation = {
		Vector3.new(-5, 4, -5),
		Vector3.new(5, 4, -5),
		Vector3.new(-5, 4, 5),
		Vector3.new(5, 4, 5),
	}
	return formation[index] or Vector3.new(((index - 1) % 2 == 0 and -5 or 5), 4, math.floor((index - 1) / 2) * 6)
end

function DeploymentRuntime.start(serverSystems)
	local flowService = serverSystems.FlowService
	local missionService = serverSystems.MissionService
	if not flowService then
		return
	end

	flowService:SetDeploymentHandler(function(request)
		local missionSpawn = findMissionSpawn()
		local flyInDuration = request.deployPayload.duration or 4

		task.delay(math.max(0.25, flyInDuration * 0.6), function()
			if flowService:GetPhase() ~= "Deployment" then
				return
			end

			if not missionSpawn then
				return
			end

			for index, player in ipairs(request.party) do
				local character = player and player.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					local offset = getDeploymentOffset(index)
					character:PivotTo(missionSpawn.CFrame + offset)
					player:SetAttribute("DeploymentState", "Mission")
				end
			end
		end)

		task.delay(flyInDuration + 0.5, function()
			if flowService:GetPhase() == "Deployment" then
				flowService:CompleteDeployment()
				if missionService then
					missionService:StartMission(request)
				end
			end
		end)
	end)
end

return DeploymentRuntime
