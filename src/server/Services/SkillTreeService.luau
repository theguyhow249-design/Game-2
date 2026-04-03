local Players = game:GetService("Players")

local SkillTreeService = {}
SkillTreeService.__index = SkillTreeService

function SkillTreeService.new(context)
	local self = setmetatable({}, SkillTreeService)
	self._contracts = context.Contracts
	self._inventoryService = nil
	self._persistenceService = context.PersistenceService
	self._gamePassService = context.GamePassService
	self._remoteNames = context.RemoteNames
	self._remotes = context.Remotes
	self._skillTreeConfig = context.SkillTreeConfig
	return self
end

function SkillTreeService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:_applyPlayerAttributes(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_applyPlayerAttributes(player)
	end
end

function SkillTreeService:SetInventoryService(inventoryService)
	self._inventoryService = inventoryService
end

function SkillTreeService:_applyPlayerAttributes(player)
	local payload = self:BuildPayload(player)
	player:SetAttribute("SkillTreeLevel", payload.level)
	player:SetAttribute("SkillTreePoints", payload.skillPoints)
end

function SkillTreeService:_emitProgression(player)
	self:_applyPlayerAttributes(player)
	if self._remotes and self._inventoryService then
		self._remotes:FireEventFor(player, self._remoteNames.Events.ProgressionUpdated, self._inventoryService:BuildProgressionPayload(player))
	end
end

function SkillTreeService:BuildPayload(player)
	local level = self._persistenceService:GetLevel(player)
	local experience = self._persistenceService:GetExperience(player)
	local skillPoints = self._persistenceService:GetSkillPoints(player)
	local skills = self._persistenceService:GetSkills(player)
	local experienceForNextLevel = self._skillTreeConfig.getExperienceForNextLevel(level)
	local experienceRemaining = math.max(0, experienceForNextLevel - experience)
	return {
		level = level,
		experience = experience,
		experienceIntoLevel = experience,
		experienceForNextLevel = experienceForNextLevel,
		experienceRemaining = experienceRemaining,
		progressPercent = math.clamp(experienceForNextLevel > 0 and (experience / experienceForNextLevel) or 0, 0, 1),
		skillPoints = skillPoints,
		skills = skills,
		nodes = self._skillTreeConfig.buildTreeState(skills),
	}
end

function SkillTreeService:GetSkillRank(player, skillId)
	return self._persistenceService:GetSkillRank(player, skillId)
end

function SkillTreeService:_getScaledBonus(player, skillId)
	local definition = self._skillTreeConfig.getSkillDefinition(skillId)
	if not definition then
		return 0
	end
	return self:GetSkillRank(player, skillId) * (definition.BonusPerRank or 0)
end

function SkillTreeService:GetMaxHealthBonus(player)
	return self:_getScaledBonus(player, "skill_vitality")
end

function SkillTreeService:GetWeaponDamageMultiplier(player)
	return 1 + self:_getScaledBonus(player, "skill_weapons_training")
end

function SkillTreeService:GetMedkitBonus(player)
	return self:_getScaledBonus(player, "skill_field_medic")
end

function SkillTreeService:GetRewardBonus(player)
	return self:_getScaledBonus(player, "skill_scavenger")
end

function SkillTreeService:GetReserveAmmoMultiplier(player)
	return 1 + self:_getScaledBonus(player, "skill_tactical_reserves")
end

function SkillTreeService:GetReloadDuration(player, baseDuration)
	return math.max(0.35, (baseDuration or 0) * (1 - self:_getScaledBonus(player, "skill_quick_hands")))
end

function SkillTreeService:GetSpawnProtectionSeconds(player, baseDuration)
	return math.max(0, (baseDuration or 0) + self:_getScaledBonus(player, "skill_breach_plating"))
end

function SkillTreeService:GetWeaponSpreadMultiplier(player)
	return math.max(0.6, 1 - self:_getScaledBonus(player, "skill_steady_grip"))
end

function SkillTreeService:GetPromptDistance(player, baseDistance)
	return math.max(0, (baseDistance or 0) * (1 + self:_getScaledBonus(player, "skill_field_routing")))
end

function SkillTreeService:GetReviveHoldDuration(player, baseDuration)
	return math.max(0.75, (baseDuration or 0) - self:_getScaledBonus(player, "skill_emergency_response"))
end

function SkillTreeService:GetDashCooldown(player, baseDuration)
	return math.max(1.5, (baseDuration or 0) * (1 - self:_getScaledBonus(player, "skill_dash_drive")))
end

function SkillTreeService:GetBossDamageMultiplier(player)
	return 1 + self:_getScaledBonus(player, "skill_boss_hunter")
end

function SkillTreeService:GetExtractionHoldSeconds(players, baseDuration)
	local bestReduction = 0
	for _, player in ipairs(players or {}) do
		if player and player.Parent then
			bestReduction = math.max(bestReduction, self:_getScaledBonus(player, "skill_fast_extract"))
		end
	end
	return math.max(1, (baseDuration or 0) * (1 - bestReduction))
end

function SkillTreeService:GetAmmoPickupAmount(player, baseAmount)
	local bonusRanks = self:GetSkillRank(player, "skill_salvage_doctrine")
	return math.max(0, math.floor((baseAmount or 0) * (1 + (bonusRanks * 0.2))))
end

function SkillTreeService:GetSalvagePickupAmount(player, baseAmount)
	return math.max(0, math.floor((baseAmount or 0) + self:_getScaledBonus(player, "skill_salvage_doctrine")))
end

function SkillTreeService:AwardExperience(player, amount, reason)
	local xpAmount = math.max(0, math.floor(amount or 0))
	if self._gamePassService then
		xpAmount = math.max(0, math.floor((xpAmount * self._gamePassService:GetSkillTreeExperienceMultiplier(player)) + 0.5))
	end
	if xpAmount <= 0 then
		return self:BuildPayload(player), {
			awarded = 0,
			levelsGained = 0,
			skillPointsGained = 0,
			reason = reason,
		}
	end

	local level = self._persistenceService:GetLevel(player)
	local experience = self._persistenceService:GetExperience(player) + xpAmount
	local skillPoints = self._persistenceService:GetSkillPoints(player)
	local leveledUp = false
	local levelsGained = 0

	while experience >= self._skillTreeConfig.getExperienceForNextLevel(level) do
		experience -= self._skillTreeConfig.getExperienceForNextLevel(level)
		level += 1
		skillPoints += self._skillTreeConfig.SkillPointsPerLevel
		leveledUp = true
		levelsGained += 1
	end

	self._persistenceService:SetExperience(player, experience)
	self._persistenceService:SetLevel(player, level)
	self._persistenceService:SetSkillPoints(player, skillPoints)
	self:_emitProgression(player)

	if leveledUp and self._remotes then
		self._remotes:FireEventFor(player, self._remoteNames.Events.Notification, {
			userId = player.UserId,
			message = ("Level up. You are now bunker level %d with %d skill point%s ready."):format(
				level,
				skillPoints,
				skillPoints == 1 and "" or "s"
			),
		})
	end

	return self:BuildPayload(player), {
		awarded = xpAmount,
		levelsGained = levelsGained,
		skillPointsGained = levelsGained * self._skillTreeConfig.SkillPointsPerLevel,
		reason = reason,
	}
end

function SkillTreeService:SpendSkillPoint(player, skillId)
	local definition = self._skillTreeConfig.getSkillDefinition(skillId)
	if not definition then
		return false, "missing_skill"
	end

	local skillPoints = self._persistenceService:GetSkillPoints(player)
	if skillPoints <= 0 then
		return false, "no_points"
	end

	local canSpend, reason = self._skillTreeConfig.canSpendPoint(self._persistenceService:GetSkills(player), skillId)
	if not canSpend then
		return false, reason
	end

	local currentRank = self:GetSkillRank(player, skillId)
	self._persistenceService:SetSkillRank(player, skillId, currentRank + 1)
	self._persistenceService:SetSkillPoints(player, skillPoints - 1)
	self:_emitProgression(player)

	if self._remotes then
		self._remotes:FireEventFor(player, self._remoteNames.Events.Notification, {
			userId = player.UserId,
			message = ("%s advanced to rank %d."):format(definition.DisplayName, currentRank + 1),
		})
	end

	return true, self._inventoryService and self._inventoryService:BuildProgressionPayload(player) or self:BuildPayload(player)
end

function SkillTreeService:Respec(player)
	local skills = self._persistenceService:GetSkills(player)
	local refundedPoints = 0

	for skillId, rank in pairs(skills) do
		if type(rank) == "number" and rank > 0 then
			refundedPoints += math.floor(rank)
		end
		skills[skillId] = nil
	end

	if refundedPoints <= 0 then
		return false, "nothing_to_respec"
	end

	self._persistenceService:SetSkillPoints(player, self._persistenceService:GetSkillPoints(player) + refundedPoints)
	self:_emitProgression(player)

	if self._remotes then
		self._remotes:FireEventFor(player, self._remoteNames.Events.Notification, {
			userId = player.UserId,
			message = ("Skill tree reset. %d point%s refunded."):format(refundedPoints, refundedPoints == 1 and "" or "s"),
		})
	end

	return true, self._inventoryService and self._inventoryService:BuildProgressionPayload(player) or self:BuildPayload(player)
end

return SkillTreeService
