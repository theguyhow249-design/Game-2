local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteNames = require(Shared:WaitForChild("RemoteNames"))
local remoteNames = RemoteNames.getAllRemoteNames()

local Remotes = {}

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
	local root = ReplicatedStorage:FindFirstChild(RemoteNames.FolderName) or ReplicatedStorage
	local deadline = os.clock() + (timeout or 5)

	while os.clock() < deadline do
		local remote = root:FindFirstChild(name, true)
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
		return false, "missing_remote"
	end

	return remoteFunction:InvokeServer(...)
end

return Remotes
