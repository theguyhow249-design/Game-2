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
	return self
end

function RemoteHub:Start()
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

	for _, name in pairs(self._remoteNames.Functions) do
		self._functions[name] = ensureChild(folder, "RemoteFunction", name)
	end
end

function RemoteHub:GetEvent(name)
	return self._events[name]
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
	local remoteFunction = self._functions[name]
	if remoteFunction then
		remoteFunction.OnServerInvoke = handler
	end
end

return RemoteHub
