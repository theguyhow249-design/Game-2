export type FlowPhase = "Homepage" | "Loading" | "Lobby" | "Intermission" | "Deployment" | "Mission"

local GameFlowConfig = {
	GameTitle = "Zombie Survival",
	Tagline = "Hold the line. Deploy with your squad.",
	HomepagePlayButtonText = "Play",
	LoadingTitle = "Zombie Survival",
	LoadingPromptText = "Press Any Key",
	LobbyName = "Main Lobby",
	IntermissionDurationSeconds = 15,
	LoadingDurationSeconds = 3,
	DeploymentFlyInSeconds = 4,
	HomeToLobbyFadeSeconds = 0.4,
}

function GameFlowConfig.getPhaseOrder(): { FlowPhase }
	return { "Homepage", "Loading", "Lobby", "Intermission", "Deployment", "Mission" }
end

function GameFlowConfig.isValidPhase(phase: string): boolean
	for _, value in ipairs(GameFlowConfig.getPhaseOrder()) do
		if value == phase then
			return true
		end
	end

	return false
end

return table.freeze(GameFlowConfig)
