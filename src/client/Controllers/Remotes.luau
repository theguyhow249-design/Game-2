local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteNames = require(Shared:WaitForChild("RemoteNames"))
local remoteNames = RemoteNames.getAllRemoteNames()

local Remotes = {}

local function findRemoteByNameAndClass(container, name, className)
	if not container then
		return nil
	end

	local direct = container:FindFirstChild(name)
	if direct and direct:IsA(className) then
		return direct
	end

	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant.Name == name and descendant:IsA(className) then
			return descendant
		end
	end

	return nil
end

local function connectRemoteEvent(remoteEvent, handlers, connections)
	if connections[remoteEvent] then
		return
	end

	connections[remoteEvent] = remoteEvent.OnClientEvent:Connect(function(...)
		local args = { ... }
		local handler = handlers[remoteEvent.Name]
		if handler then
			handler(table.unpack(args))
		end
	end)
end

function Remotes.bind(handlers)
	local connections = {}

	local function scan(container)
		for _, name in ipairs(remoteNames) do
			local remote = container:FindFirstChild(name, true)
			if remote and remote:IsA("RemoteEvent") then
				connectRemoteEvent(remote, handlers, connections)
			end
		end
	end

	local root = ReplicatedStorage:FindFirstChild(RemoteNames.FolderName) or ReplicatedStorage
	scan(root)

	local descendantConnection = ReplicatedStorage.DescendantAdded:Connect(function(instance)
		if instance:IsA("RemoteEvent") then
			for _, name in ipairs(remoteNames) do
				if instance.Name == name then
					connectRemoteEvent(instance, handlers, connections)
					break
				end
			end
		end
	end)

	return function()
		descendantConnection:Disconnect()
		for _, connection in pairs(connections) do
			connection:Disconnect()
		end
	end
end

function Remotes.waitForRemote(name, className, timeout)
	local deadline = os.clock() + (timeout or 5)

	while os.clock() < deadline do
		local root = ReplicatedStorage:FindFirstChild(RemoteNames.FolderName) or ReplicatedStorage
		local remote = findRemoteByNameAndClass(root, name, className)
			or findRemoteByNameAndClass(ReplicatedStorage, name, className)
		if remote and remote:IsA(className) then
			return remote
		end
		task.wait(0.1)
	end

	return nil
end

function Remotes.invoke(name, ...)
	local remoteFunction = Remotes.waitForRemote(name, "RemoteFunction")
	if not remoteFunction then
		local remotesFolder = ReplicatedStorage:FindFirstChild(RemoteNames.FolderName)
		local direct = ReplicatedStorage:FindFirstChild(name, true)
		warn(("[Remotes] Missing RemoteFunction %s | remotesFolder=%s | directMatch=%s"):format(
			tostring(name),
			remotesFolder and remotesFolder:GetFullName() or "nil",
			direct and (direct:GetFullName() .. ":" .. direct.ClassName) or "nil"
		))
		return false, "missing_remote"
	end

	return remoteFunction:InvokeServer(...)
end

function Remotes.fire(name, ...)
	local remoteEvent = Remotes.waitForRemote(name, "RemoteEvent")
	if not remoteEvent then
		local remotesFolder = ReplicatedStorage:FindFirstChild(RemoteNames.FolderName)
		local direct = ReplicatedStorage:FindFirstChild(name, true)
		warn(("[Remotes] Missing RemoteEvent %s | remotesFolder=%s | directMatch=%s"):format(
			tostring(name),
			remotesFolder and remotesFolder:GetFullName() or "nil",
			direct and (direct:GetFullName() .. ":" .. direct.ClassName) or "nil"
		))
		return false, "missing_remote"
	end

	remoteEvent:FireServer(...)
	return true
end

return Remotes
