local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RoleService = {}
RoleService.__index = RoleService

local ROLE_OVERRIDES = {
	OwnerUserIds = {},
	AdminUserIds = {},
}

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
	return self
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

	local isAdmin = isOwner or hasUserId(ROLE_OVERRIDES.AdminUserIds, userId) or RunService:IsStudio()
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
	elseif vipOwned then
		identity.title = "VIP Operator"
		identity.badge = "VIP"
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
	player:SetAttribute("IsAdmin", identity.isAdmin == true)
	player:SetAttribute("IsOwner", identity.isOwner == true)
end

return RoleService
