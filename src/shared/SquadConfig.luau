local SquadConfig = {
	MinimumPlayers = 1,
	MaximumPlayers = 4,
	DifficultyPerExtraPlayer = 0.25,
	LootPerExtraPlayer = 0.2,
}

function SquadConfig.clampSquadSize(playerCount: number): number
	return math.clamp(playerCount, SquadConfig.MinimumPlayers, SquadConfig.MaximumPlayers)
end

function SquadConfig.getDifficultyMultiplier(playerCount: number): number
	local squadSize = SquadConfig.clampSquadSize(playerCount)
	return 1 + ((squadSize - 1) * SquadConfig.DifficultyPerExtraPlayer)
end

function SquadConfig.getLootMultiplier(playerCount: number): number
	local squadSize = SquadConfig.clampSquadSize(playerCount)
	return 1 + ((squadSize - 1) * SquadConfig.LootPerExtraPlayer)
end

function SquadConfig.getSquadLabel(playerCount: number): string
	local squadSize = SquadConfig.clampSquadSize(playerCount)
	if squadSize == 1 then
		return "Solo"
	elseif squadSize == 2 then
		return "Duo"
	elseif squadSize == 3 then
		return "Trio"
	end

	return "Quad"
end

return table.freeze(SquadConfig)
