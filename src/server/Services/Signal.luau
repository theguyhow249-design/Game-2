local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({
		_event = Instance.new("BindableEvent"),
		_destroyed = false,
	}, Signal)
end

function Signal:Connect(handler)
	return self._event.Event:Connect(handler)
end

function Signal:Once(handler)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal:Fire(...)
	if self._destroyed then
		return
	end

	self._event:Fire(...)
end

function Signal:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._event:Destroy()
end

return Signal
