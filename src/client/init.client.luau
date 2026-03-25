local controllers = script:FindFirstChild("Controllers") or script.Parent:WaitForChild("Controllers")
local FlowController = require(controllers:WaitForChild("FlowController"))

FlowController.start()
