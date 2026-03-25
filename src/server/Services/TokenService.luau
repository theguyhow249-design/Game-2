local Players = game:GetService("Players")

local TokenService = {}
TokenService.__index = TokenService

function TokenService.new(context)
	local self = setmetatable({}, TokenService)
	self._tokenEconomy = context.TokenEconomy
	self._persistenceService = context.PersistenceService
	self._contracts = context.Contracts
	self._remoteNames = context.RemoteNames
	self._remotes = context.Remotes
	self._balances = {}
	self.BalanceChanged = context.Signal.new()
	return self
end

function TokenService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:BindPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:UnbindPlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:BindPlayer(player)
	end
end

function TokenService:BindPlayer(player)
	if self._balances[player.UserId] == nil then
		self._balances[player.UserId] = self._persistenceService:GetTokenBalance(player)
	end

	self:SetBalance(player, self._balances[player.UserId], nil, "bind")
end

function TokenService:UnbindPlayer(player)
	self._balances[player.UserId] = nil
end

function TokenService:GetBalance(player)
	return self._balances[player.UserId] or self._tokenEconomy.StartingDeployTokens
end

function TokenService:SetBalance(player, amount, source, reason)
	local previous = self:GetBalance(player)
	local clamped = math.max(0, math.floor(amount))
	local delta = clamped - previous

	self._balances[player.UserId] = clamped
	self._persistenceService:SetTokenBalance(player, clamped)
	player:SetAttribute("DeployTokens", clamped)

	local payload = self._contracts.makeTokenBalancePayload(player.UserId, clamped, delta, source, reason)
	self.BalanceChanged:Fire(player, payload)
	if self._remotes then
		self._remotes:FireEventFor(player, self._remoteNames.Events.TokenBalanceChanged, payload)
	end

	return clamped, payload
end

function TokenService:AddTokens(player, amount, source, reason)
	if amount <= 0 then
		return self:GetBalance(player)
	end

	local balance = self:GetBalance(player)
	local updated = balance + amount
	return self:SetBalance(player, updated, source, reason)
end

function TokenService:SpendTokens(player, amount, source, reason)
	if amount < 0 then
		error("SpendTokens expects a non-negative amount")
	end

	local current = self:GetBalance(player)
	if current < amount then
		return false, current
	end

	self:SetBalance(player, current - amount, source, reason)
	return true, self:GetBalance(player)
end

return TokenService
