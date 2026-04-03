local SkillTreeConfig = {
	BaseExperienceForLevel = 100,
	ExperienceGrowthPerLevel = 40,
	SkillPointsPerLevel = 1,
	BranchOrder = { "Survivor", "Combat", "Logistics" },
	ExperienceRewards = {
		ZombieKill = 5,
		WaveClear = 18,
		MissionComplete = 40,
		MissionFailure = 12,
	},
	Skills = {
		{
			Id = "skill_vitality",
			DisplayName = "Vitality",
			Description = "Increase your bunker resilience with more maximum health every run.",
			MaxRank = 3,
			Branch = "Survivor",
			Tier = 1,
			BonusPerRank = 15,
			BonusLabel = "+15 max health / rank",
			Icon = "VIT",
		},
		{
			Id = "skill_weapons_training",
			DisplayName = "Weapons Training",
			Description = "Tighten aim discipline and hit harder with every weapon you carry.",
			MaxRank = 3,
			Branch = "Combat",
			Tier = 1,
			BonusPerRank = 0.08,
			BonusLabel = "+8% weapon damage / rank",
			Icon = "DMG",
		},
		{
			Id = "skill_field_medic",
			DisplayName = "Field Medic",
			Description = "Stretch every medkit further and stabilize harder after a bad push.",
			MaxRank = 2,
			Branch = "Survivor",
			Prerequisite = "skill_vitality",
			Tier = 2,
			BonusPerRank = 12,
			BonusLabel = "+12 medkit healing / rank",
			Icon = "MED",
		},
		{
			Id = "skill_breach_plating",
			DisplayName = "Breach Plating",
			Description = "Reinforce drop armor and hold formation longer after fresh mission inserts or respawns.",
			MaxRank = 2,
			Branch = "Survivor",
			Prerequisite = "skill_vitality",
			Tier = 2,
			BonusPerRank = 0.35,
			BonusLabel = "+0.35s spawn shield / rank",
			Icon = "PLT",
		},
		{
			Id = "skill_scavenger",
			DisplayName = "Scavenger",
			Description = "Strip more value out of each breach with bonus deploy token rewards.",
			MaxRank = 3,
			Branch = "Logistics",
			Tier = 1,
			BonusPerRank = 2,
			BonusLabel = "+2 reward tokens / rank",
			Icon = "TOK",
		},
		{
			Id = "skill_tactical_reserves",
			DisplayName = "Tactical Reserves",
			Description = "Carry deeper ammo reserves before the squad has to rely on pickups.",
			MaxRank = 2,
			Branch = "Combat",
			Prerequisite = "skill_weapons_training",
			Tier = 2,
			BonusPerRank = 0.15,
			BonusLabel = "+15% reserve ammo / rank",
			Icon = "AMO",
		},
		{
			Id = "skill_steady_grip",
			DisplayName = "Steady Grip",
			Description = "Reduce bloom and keep follow-up shots tighter when the lane starts breaking down.",
			MaxRank = 2,
			Branch = "Combat",
			Prerequisite = "skill_weapons_training",
			Tier = 2,
			BonusPerRank = 0.12,
			BonusLabel = "-12% weapon spread / rank",
			Icon = "GRP",
		},
		{
			Id = "skill_quick_hands",
			DisplayName = "Quick Hands",
			Description = "Tighten reload rhythm and get weapons back online faster between pressure spikes.",
			MaxRank = 2,
			Branch = "Combat",
			Prerequisite = "skill_weapons_training",
			Tier = 2,
			BonusPerRank = 0.1,
			BonusLabel = "-10% reload time / rank",
			Icon = "RLD",
		},
		{
			Id = "skill_emergency_response",
			DisplayName = "Emergency Response",
			Description = "Cut revive time and get downed teammates back on their feet before the line breaks.",
			MaxRank = 2,
			Branch = "Survivor",
			Prerequisite = "skill_field_medic",
			Tier = 3,
			BonusPerRank = 0.35,
			BonusLabel = "-0.35s revive hold / rank",
			Icon = "REV",
		},
		{
			Id = "skill_dash_drive",
			DisplayName = "Dash Drive",
			Description = "Recycle dash charge faster so you can reposition more aggressively during swarms.",
			MaxRank = 2,
			Branch = "Combat",
			Prerequisite = "skill_tactical_reserves",
			Tier = 3,
			BonusPerRank = 0.12,
			BonusLabel = "-12% dash cooldown / rank",
			Icon = "DSH",
		},
		{
			Id = "skill_boss_hunter",
			DisplayName = "Boss Hunter",
			Description = "Train for tyrant breaches and hit boss targets harder during pressure windows.",
			MaxRank = 2,
			Branch = "Combat",
			Prerequisite = "skill_weapons_training",
			Tier = 3,
			BonusPerRank = 0.12,
			BonusLabel = "+12% boss damage / rank",
			Icon = "BOS",
		},
		{
			Id = "skill_fast_extract",
			DisplayName = "Fast Extract",
			Description = "Streamline bunker exfil and shave time off the final extraction hold.",
			MaxRank = 2,
			Branch = "Logistics",
			Prerequisite = "skill_scavenger",
			Tier = 2,
			BonusPerRank = 0.1,
			BonusLabel = "-10% extraction hold / rank",
			Icon = "EXT",
		},
		{
			Id = "skill_field_routing",
			DisplayName = "Field Routing",
			Description = "Extend bunker prompt reach so revives, pickups, and objective handoffs are easier under pressure.",
			MaxRank = 2,
			Branch = "Logistics",
			Prerequisite = "skill_scavenger",
			Tier = 2,
			BonusPerRank = 0.08,
			BonusLabel = "+8% prompt reach / rank",
			Icon = "RNG",
		},
		{
			Id = "skill_salvage_doctrine",
			DisplayName = "Salvage Doctrine",
			Description = "Pull more value out of ammo caches and salvage crates scattered across the mission.",
			MaxRank = 2,
			Branch = "Logistics",
			Prerequisite = "skill_scavenger",
			Tier = 3,
			BonusPerRank = 1,
			BonusLabel = "+1 salvage token / rank, +20% ammo cache / rank",
			Icon = "SLV",
		},
	},
}

local function getSkillRank(skillRanks, skillId)
	return math.max(0, math.floor((skillRanks and skillRanks[skillId]) or 0))
end

function SkillTreeConfig.getExperienceForNextLevel(level)
	local currentLevel = math.max(1, math.floor(level or 1))
	return SkillTreeConfig.BaseExperienceForLevel + ((currentLevel - 1) * SkillTreeConfig.ExperienceGrowthPerLevel)
end

function SkillTreeConfig.getSkillDefinition(skillId)
	for _, skill in ipairs(SkillTreeConfig.Skills) do
		if skill.Id == skillId then
			return skill
		end
	end
	return nil
end

function SkillTreeConfig.getOrderedSkills()
	return SkillTreeConfig.Skills
end

function SkillTreeConfig.getBranchOrder()
	local result = table.create(#SkillTreeConfig.BranchOrder)
	for index, branch in ipairs(SkillTreeConfig.BranchOrder) do
		result[index] = branch
	end
	return result
end

function SkillTreeConfig.canSpendPoint(skillRanks, skillId)
	local definition = SkillTreeConfig.getSkillDefinition(skillId)
	if not definition then
		return false, "missing_skill"
	end

	local currentRank = getSkillRank(skillRanks, skillId)
	if currentRank >= (definition.MaxRank or 1) then
		return false, "max_rank"
	end

	if definition.Prerequisite then
		local prereqRank = getSkillRank(skillRanks, definition.Prerequisite)
		if prereqRank <= 0 then
			return false, "missing_prerequisite"
		end
	end

	return true
end

function SkillTreeConfig.buildTreeState(skillRanks)
	local states = table.create(#SkillTreeConfig.Skills)
	for index, definition in ipairs(SkillTreeConfig.Skills) do
		local rank = getSkillRank(skillRanks, definition.Id)
		local maxRank = definition.MaxRank or 1
		local unlocked = true
		local prerequisiteMet = true
		local prerequisiteId = definition.Prerequisite
		if prerequisiteId then
			prerequisiteMet = getSkillRank(skillRanks, prerequisiteId) > 0
			unlocked = prerequisiteMet
		end
		states[index] = {
			id = definition.Id,
			displayName = definition.DisplayName,
			description = definition.Description,
			branch = definition.Branch,
			tier = definition.Tier,
			icon = definition.Icon,
			bonusLabel = definition.BonusLabel,
			maxRank = maxRank,
			rank = rank,
			isMaxed = rank >= maxRank,
			hasPrerequisite = prerequisiteId ~= nil,
			prerequisiteId = prerequisiteId,
			prerequisiteMet = prerequisiteMet,
			available = unlocked and rank < maxRank,
		}
	end
	return states
end

return table.freeze(SkillTreeConfig)
