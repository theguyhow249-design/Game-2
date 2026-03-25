local ShopService = {}
ShopService.__index = ShopService

function ShopService.new(context)
	local self = setmetatable({}, ShopService)
	self._tokenEconomy = context.TokenEconomy
	self._missionConfig = context.MissionConfig
	self._contracts = context.Contracts
	self._remoteNames = context.RemoteNames
	self._remotes = context.Remotes
	self._tokenService = context.TokenService
	self._inventoryService = context.InventoryService
	return self
end

function ShopService:Start()
end

function ShopService:GetCatalog()
	return self._tokenEconomy.ShopCatalog
end

function ShopService:GetSeasonalEventState()
	return self._tokenEconomy.getActiveSeasonalEvent()
end

function ShopService:GetCategory(categoryName)
	return self._tokenEconomy.getCategoryItems(categoryName)
end

function ShopService:GetItem(categoryName, itemId)
	for _, item in ipairs(self:GetCategory(categoryName)) do
		if item.Id == itemId then
			return item
		end
	end

	return nil
end

function ShopService:Purchase(player, request)
	local category = request.category
	local itemId = request.itemId
	local quantity = math.max(1, request.quantity or 1)
	local currency = request.currency
	local item = self:GetItem(category, itemId)
	if not item then
		return false, "missing_item"
	end

	local activeEvent = self:GetSeasonalEventState()
	if item.DropOnly then
		return false, "drop_only_item"
	end
	if item.SeasonalEvent and (not activeEvent or activeEvent.Id ~= item.SeasonalEvent) then
		return false, "season_locked"
	end

	if item.CostType == "Robux" or category == "DeployTokens" then
		return false, "deploy_token_purchase_is_reward_flow"
	end

	if currency ~= "Tokens" or item.CostType ~= "Tokens" then
		return false, "invalid_currency"
	end

	local cost = (item.Cost or 0) * quantity
	if cost > 0 then
		local success = self._tokenService:SpendTokens(player, cost, "DeploySpend", "shop_purchase")
		if not success then
			return false, "insufficient_tokens"
		end
	end

	self._inventoryService:UnlockItem(player, itemId)
	local unlockAttribute = ("ShopUnlocked_%s_%s"):format(category, itemId)
	player:SetAttribute(unlockAttribute, true)
	if category == self._tokenEconomy.ShopCategories.Weapons and self._missionConfig.Weapons[itemId] then
		self._inventoryService:EquipWeapon(player, itemId)
	elseif category == self._tokenEconomy.ShopCategories.Cosmetics then
		self._inventoryService:EquipCosmetic(player, itemId)
	end

	local payload = self._contracts.makeShopPurchaseRequest(itemId, category, quantity, currency)
	player:SetAttribute("LastShopItem", itemId)
	player:SetAttribute("LastShopCategory", category)
	if self._remotes then
		self._remotes:FireEventFor(player, self._remoteNames.Events.ProgressionUpdated, self._inventoryService:BuildProgressionPayload(player))
		self._remotes:FireEventFor(player, self._remoteNames.Events.ShopStateChanged, payload)
	end

	return true, payload
end

function ShopService:EquipItem(player, request)
	if type(request) ~= "table" then
		return false, "invalid_request"
	end

	local category = request.category
	local itemId = request.itemId

	if category == self._tokenEconomy.ShopCategories.Weapons then
		local success, reason = self._inventoryService:EquipWeapon(player, itemId)
		if not success then
			return false, reason
		end
	elseif category == self._tokenEconomy.ShopCategories.Cosmetics then
		local success, reason = self._inventoryService:EquipCosmetic(player, itemId)
		if not success then
			return false, reason
		end
	else
		return false, "unsupported_category"
	end

	local payload = {
		category = category,
		itemId = itemId,
		equippedWeapon = self._inventoryService:GetEquippedWeaponId(player),
		equippedCosmetic = self._inventoryService:GetEquippedCosmetic(player),
	}
	if self._remotes then
		self._remotes:FireEventFor(player, self._remoteNames.Events.ProgressionUpdated, self._inventoryService:BuildProgressionPayload(player))
		self._remotes:FireEventFor(player, self._remoteNames.Events.ShopStateChanged, payload)
	end
	return true, payload
end

return ShopService
