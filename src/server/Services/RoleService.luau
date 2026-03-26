local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RoleService = {}
RoleService.__index = RoleService

local ROLE_OVERRIDES = {
	OwnerUserIds = {},
	AdminUserIds = {},
	ModeratorUserIds = {},
}

local ACCESSSTORE_NAME = "ZombieSurvivalAccessControl_v1"

local function hasUserId(list, userId)
	for _, value in ipairs(list) do
		if tonumber(value) == tonumber(userId) then
			return true
		end
	end
	return false
end

function RoleService.new(_context)
	local self = setmetatable({}, RoleService)
	self._gamePassService = _context.GamePassService
	self._grants = {}
	self._accessStore = nil
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(ACCESSSTORE_NAME)
	end)
	if ok then
		self._accessStore = store
	end
	return self
end

function RoleService:_getStoreKey(userId)
	return ("access_%d"):format(tonumber(userId) or 0)
end

function RoleService:_loadGrant(userId)
	local normalizedUserId = tonumber(userId) or 0
	if normalizedUserId <= 0 then
		return nil
	end
	if self._grants[normalizedUserId] ~= nil then
		return self._grants[normalizedUserId]
	end
	if not self._accessStore then
		self._grants[normalizedUserId] = false
		return nil
	end

	local ok, data = pcall(function()
		return self._accessStore:GetAsync(self:_getStoreKey(normalizedUserId))
	end)
	if ok and type(data) == "table" and type(data.role) == "string" then
		self._grants[normalizedUserId] = {
			role = string.lower(data.role),
			grantedBy = tonumber(data.grantedBy) or nil,
			updatedAt = tonumber(data.updatedAt) or os.time(),
		}
	else
		self._grants[normalizedUserId] = false
	end

	return self._grants[normalizedUserId] or nil
end

function RoleService:GetGrant(userId)
	return self:_loadGrant(userId)
end

function RoleService:SetGrant(userId, role, grantedBy)
	local normalizedUserId = tonumber(userId) or 0
	local normalizedRole = string.lower(tostring(role or ""))
	if normalizedUserId <= 0 or (normalizedRole ~= "moderator" and normalizedRole ~= "admin") then
		return false
	end

	local payload = {
		role = normalizedRole,
		grantedBy = tonumber(grantedBy) or 0,
		updatedAt = os.time(),
	}
	self._grants[normalizedUserId] = payload
	if self._accessStore then
		pcall(function()
			self._accessStore:SetAsync(self:_getStoreKey(normalizedUserId), payload)
		end)
	end

	local player = Players:GetPlayerByUserId(normalizedUserId)
	if player then
		self:Apply(player)
	end
	return true
end

function RoleService:ClearGrant(userId)
	local normalizedUserId = tonumber(userId) or 0
	if normalizedUserId <= 0 then
		return false
	end

	self._grants[normalizedUserId] = false
	if self._accessStore then
		pcall(function()
			self._accessStore:RemoveAsync(self:_getStoreKey(normalizedUserId))
		end)
	end

	local player = Players:GetPlayerByUserId(normalizedUserId)
	if player then
		self:Apply(player)
	end
	return true
end

function RoleService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:Apply(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:Apply(player)
	end
end

function RoleService:GetIdentity(player)
	local identity = {
		title = "Survivor",
		badge = nil,
		isModerator = false,
		isAdmin = false,
		isOwner = false,
	}

	if not player then
		return identity
	end

	local userId = tonumber(player.UserId) or 0
	local isOwner = false

	if hasUserId(ROLE_OVERRIDES.OwnerUserIds, userId) then
		isOwner = true
	elseif game.CreatorType == Enum.CreatorType.User and tonumber(game.CreatorId) == userId then
		isOwner = true
	elseif tonumber(game.PrivateServerOwnerId) and tonumber(game.PrivateServerOwnerId) == userId then
		isOwner = true
	elseif game.CreatorType == Enum.CreatorType.Group and tonumber(game.CreatorId) and tonumber(game.CreatorId) > 0 then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		if ok and tonumber(rank) and tonumber(rank) >= 255 then
			isOwner = true
		end
	end

	local grant = self:_loadGrant(userId)
	local grantRole = grant and grant.role or nil
	local isModerator = hasUserId(ROLE_OVERRIDES.ModeratorUserIds, userId) or grantRole == "moderator"
	local isAdmin = isOwner or hasUserId(ROLE_OVERRIDES.AdminUserIds, userId) or grantRole == "admin" or RunService:IsStudio()
	local vipOwned = self._gamePassService and self._gamePassService:HasPass(player, "vip_operation")
	if isOwner then
		identity.title = "Creator / Owner"
		identity.badge = "OWNER"
		identity.isOwner = true
		identity.isAdmin = true
	elseif isAdmin then
		identity.title = "Admin"
		identity.badge = "ADMIN"
		identity.isAdmin = true
	elseif isModerator then
		identity.title = "Moderator"
		identity.badge = "MOD"
		identity.isModerator = true
	elseif vipOwned then
		identity.title = "VIP Operator"
		identity.badge = "VIP"
	end

	if identity.isAdmin then
		identity.isModerator = true
	end

	return identity
end

function RoleService:GetDecoratedDisplayName(player)
	if not player then
		return "Unknown"
	end

	local identity = self:GetIdentity(player)
	if identity.badge and identity.badge ~= "" then
		return ("[%s] %s"):format(identity.badge, player.DisplayName)
	end
	return player.DisplayName
end

function RoleService:Apply(player)
	if not player then
		return
	end

	local identity = self:GetIdentity(player)
	player:SetAttribute("PlayerTitle", identity.title)
	player:SetAttribute("PlayerBadge", identity.badge)
	player:SetAttribute("IsModerator", identity.isModerator == true)
	player:SetAttribute("IsAdmin", identity.isAdmin == true)
	player:SetAttribute("IsOwner", identity.isOwner == true)
end

return RoleService
