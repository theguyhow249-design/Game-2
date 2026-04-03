local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteHub = {}
RemoteHub.__index = RemoteHub

local function ensureChild(parent, className, name)
	local child = parent:FindFirstChild(name)
	if child and child.ClassName ~= className then
		child:Destroy()
		child = nil
	end

	if not child then
		child = Instance.new(className)
		child.Name = name
		child.Parent = parent
	end

	return child
end

function RemoteHub.new(context)
	local self = setmetatable({}, RemoteHub)
	self._remoteNames = context.RemoteNames
	self._events = {}
	self._functions = {}
	self._eventAliases = {}
	self._functionAliases = {}
	self._handlers = {}
	return self
end

function RemoteHub:_ensureRemotes()
	local folder = ReplicatedStorage:FindFirstChild(self._remoteNames.FolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = self._remoteNames.FolderName
		folder.Parent = ReplicatedStorage
	end

	self._folder = folder

	for _, name in pairs(self._remoteNames.Events) do
		self._events[name] = ensureChild(folder, "RemoteEvent", name)
	end

	for _, name in ipairs({
		self._remoteNames.Events.DeployRequested,
	}) do
		if type(name) == "string" and name ~= "" then
			self._eventAliases[name] = ensureChild(ReplicatedStorage, "RemoteEvent", name)
		end
	end

	for _, name in pairs(self._remoteNames.Functions) do
		self._functions[name] = ensureChild(folder, "RemoteFunction", name)
	end

	for _, name in ipairs({
		self._remoteNames.Functions.GetBootstrapData,
		self._remoteNames.Functions.RequestDeploy,
		self._remoteNames.Functions.RequestMapVote,
		self._remoteNames.Functions.LeaveMission,
	}) do
		if type(name) == "string" and name ~= "" then
			self._functionAliases[name] = ensureChild(ReplicatedStorage, "RemoteFunction", name)
		end
	end

	for name, handler in pairs(self._handlers) do
		local remoteFunction = self._functions[name]
		if remoteFunction then
			remoteFunction.OnServerInvoke = handler
		end
		local alias = self._functionAliases[name]
		if alias then
			alias.OnServerInvoke = handler
		end
	end
end

function RemoteHub:Start()
	self:_ensureRemotes()

	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == self._remoteNames.FolderName or child:IsA("RemoteFunction") or child:IsA("RemoteEvent") then
			task.defer(function()
				self:_ensureRemotes()
			end)
		end
	end)

	ReplicatedStorage.ChildRemoved:Connect(function(child)
		if child.Name == self._remoteNames.FolderName or child:IsA("RemoteFunction") or child:IsA("RemoteEvent") then
			task.defer(function()
				self:_ensureRemotes()
			end)
		end
	end)
end

function RemoteHub:GetEvent(name)
	return self._events[name] or self._eventAliases[name]
end

function RemoteHub:GetFunction(name)
	return self._functions[name]
end

function RemoteHub:FireEvent(name, ...)
	local event = self._events[name]
	if event then
		event:FireAllClients(...)
	end
end

function RemoteHub:FireEventFor(player, name, ...)
	local event = self._events[name]
	if event and player then
		event:FireClient(player, ...)
	end
end

function RemoteHub:FireEventForMany(players, name, ...)
	local event = self._events[name]
	if not event then
		return
	end

	for _, player in ipairs(players) do
		if player and player.Parent then
			event:FireClient(player, ...)
		end
	end
end

function RemoteHub:SetFunctionHandler(name, handler)
	self._handlers[name] = handler
	self:_ensureRemotes()
end

return RemoteHub
