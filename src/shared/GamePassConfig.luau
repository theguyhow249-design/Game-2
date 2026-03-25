local GamePassConfig = {
	Passes = {
		SkillTreeDouble = {
			Id = 1767537515,
			Key = "skill_tree_double",
			DisplayName = "2x Skill Tree Pass",
			SkillTreeExperienceMultiplier = 2,
		},
		VipOperation = {
			Id = 1765913819,
			Key = "vip_operation",
			DisplayName = "VIP Operation",
			TokenRewardMultiplier = 2,
			BonusTitle = "VIP Operator",
		},
		StarterLoadout = {
			Id = 1767991467,
			Key = "starter_loadout",
			DisplayName = "Starter Loadout",
			StarterLoadout = {
				Weapons = {
					"weapon_service_pistol",
					"weapon_patrol_carbine",
					"weapon_fire_axe",
				},
				Cosmetics = {
					"cosmetic_field_cap",
					"cosmetic_bunker_glow",
				},
				DefaultEquipWeapon = "weapon_patrol_carbine",
				DefaultEquipCosmetic = "cosmetic_bunker_glow",
			},
		},
		DoubleDropChance = {
			Id = 1765047588,
			Key = "double_drop_chance",
			DisplayName = "Double Drop Chance",
			DropChanceMultiplier = 2,
		},
	},
}

function GamePassConfig.getAllPasses()
	local passes = {}
	for _, pass in pairs(GamePassConfig.Passes) do
		table.insert(passes, pass)
	end
	table.sort(passes, function(a, b)
		return (a.Id or 0) < (b.Id or 0)
	end)
	return passes
end

function GamePassConfig.getPassById(passId)
	local targetId = tonumber(passId) or 0
	for _, pass in pairs(GamePassConfig.Passes) do
		if tonumber(pass.Id) == targetId then
			return pass
		end
	end
	return nil
end

return table.freeze(GamePassConfig)
