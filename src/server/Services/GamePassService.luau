local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local GamePassService = {}
GamePassService.__index = GamePassService

function GamePassService.new(context)
	local self = setmetatable({}, GamePassService)
	self._gamePassConfig = context.GamePassConfig
	self._inventoryService = nil
	self._persistenceService = context.PersistenceService
	self._roleService = context.RoleService
	self._ownership = {}
	return self
end

function GamePassService:SetInventoryService(inventoryService)
	self._inventoryService = inventoryService
end

function GamePassService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:Refresh(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._ownership[player.UserId] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:Refresh(player)
	end
end

function GamePassService:_getFlags(player)
	local flags = self._ownership[player.UserId]
	if not flags then
		flags = {}
		self._ownership[player.UserId] = flags
	end
	return flags
end

function GamePassService:_setPlayerAttributes(player, flags)
	player:SetAttribute("GamePassSkillTreeDouble", flags.skill_tree_double == true)
	player:SetAttribute("GamePassVipOperation", flags.vip_operation == true)
	player:SetAttribute("GamePassStarterLoadout", flags.starter_loadout == true)
	player:SetAttribute("GamePassDoubleDropChance", flags.double_drop_chance == true)
	player:SetAttribute("GamePassOwned_skill_tree_double", flags.skill_tree_double == true)
	player:SetAttribute("GamePassOwned_vip_operation", flags.vip_operation == true)
	player:SetAttribute("GamePassOwned_starter_loadout", flags.starter_loadout == true)
	player:SetAttribute("GamePassOwned_double_drop_chance", flags.double_drop_chance == true)
end

function GamePassService:_grantStarterLoadout(player, flags)
	if flags.starter_loadout ~= true or not self._inventoryService then
		return
	end

	local profile = self._persistenceService:GetProfile(player)
	profile.claimedRewards = profile.claimedRewards or {}
	if profile.claimedRewards.starter_loadout == true then
		return
	end

	local passDefinition = self._gamePassConfig.Passes.StarterLoadout
	local loadout = passDefinition and passDefinition.StarterLoadout or nil
	if not loadout then
		return
	end

	for _, itemId in ipairs(loadout.Weapons or {}) do
		self._inventoryService:UnlockItem(player, itemId)
	end
	for _, itemId in ipairs(loadout.Cosmetics or {}) do
		self._inventoryService:UnlockItem(player, itemId)
	end
	if loadout.DefaultEquipWeapon then
		self._inventoryService:EquipWeapon(player, loadout.DefaultEquipWeapon)
	end
	if loadout.DefaultEquipCosmetic then
		self._inventoryService:EquipCosmetic(player, loadout.DefaultEquipCosmetic)
	end

	profile.claimedRewards.starter_loadout = true
	player:SetAttribute("StarterLoadoutGranted", true)
end

function GamePassService:Refresh(player)
	if not player or not player.Parent then
		return {}
	end

	local flags = {}
	for _, pass in ipairs(self._gamePassConfig.getAllPasses()) do
		local owns = false
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
		end)
		if ok and result == true then
			owns = true
		end
		flags[pass.Key] = owns
	end

	self._ownership[player.UserId] = flags
	self:_setPlayerAttributes(player, flags)
	self:_grantStarterLoadout(player, flags)
	if self._roleService then
		self._roleService:Apply(player)
	end
	return flags
end

function GamePassService:HasPass(player, key)
	if not player then
		return false
	end
	local flags = self._ownership[player.UserId]
	if not flags then
		flags = self:Refresh(player)
	end
	return flags[key] == true
end

function GamePassService:GetTokenRewardMultiplier(player)
	return self:HasPass(player, "vip_operation") and 2 or 1
end

function GamePassService:GetSkillTreeExperienceMultiplier(player)
	return self:HasPass(player, "skill_tree_double") and 2 or 1
end

function GamePassService:GetDropChanceMultiplier(player)
	return self:HasPass(player, "double_drop_chance") and 2 or 1
end

function GamePassService:GetIdentityExtras(player)
	return {
		isVip = self:HasPass(player, "vip_operation"),
	}
end

return GamePassService
