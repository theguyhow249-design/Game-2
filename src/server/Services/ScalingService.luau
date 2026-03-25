local ScalingService = {}
ScalingService.__index = ScalingService

function ScalingService.new(context)
	local self = setmetatable({}, ScalingService)
	self._squadConfig = context.SquadConfig
	return self
end

function ScalingService:Start()
end

function ScalingService:GetProfile(partySize)
	return {
		partySize = self._squadConfig.clampSquadSize(partySize or 1),
		difficultyMultiplier = self._squadConfig.getDifficultyMultiplier(partySize or 1),
		lootMultiplier = self._squadConfig.getLootMultiplier(partySize or 1),
		label = self._squadConfig.getSquadLabel(partySize or 1),
	}
end

function ScalingService:ScaleEnemyStats(baseStats, partySize)
	local profile = self:GetProfile(partySize)
	return {
		health = math.floor((baseStats.health or 100) * profile.difficultyMultiplier),
		damage = math.floor((baseStats.damage or 10) * profile.difficultyMultiplier),
		spawnCount = math.max(1, math.floor((baseStats.spawnCount or 1) * profile.partySize)),
		lootMultiplier = profile.lootMultiplier,
	}
end

return ScalingService
