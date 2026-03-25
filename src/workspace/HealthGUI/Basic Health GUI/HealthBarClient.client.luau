--[[
	Hey if you're reading this HI!!
	I made this model a few years ago. It wasn't really put together well but im surprised it got a lot of notice!

	I went back (it's 2024) and made some small adjustments.
	
	Other edit: OK. Final changes, it's 2025, my last changes were a bit rushed and do not use proper techniques
	to updates the health bar UI. The UI now automatically updates when the player spawns in too. (Init)
	
	I have also made the bar more vibrant than the dark green it was before.
	Feel free to make any changes to the UI, whatever suits your game style best.
	
--]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local GUI = script.Parent
local HEALTHBAR = GUI:WaitForChild("Healthbar")
local PROGRESSBAR = HEALTHBAR:WaitForChild("Healthbar")
local PERCENTAGE = HEALTHBAR:WaitForChild("percentage")

local PLR = Players.LocalPlayer
local CHARACTER = PLR.Character or PLR.CharacterAdded:Wait()
local HUMANOID = CHARACTER:WaitForChild("Humanoid")

local TweenColourInfo = TweenInfo.new(.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0)
local Colours = {
	LowHealth = Color3.new(1, .25, .25),
	MidHealth = Color3.new(1, .75, 0),
	FullHealth = PROGRESSBAR.BackgroundColor3,
}
local Tweens = {
	LowHealth = {
		TweenService:Create(PROGRESSBAR, TweenColourInfo, { BackgroundColor3 = Colours.LowHealth }),
		TweenService:Create(HEALTHBAR.UIStroke, TweenColourInfo, { Color = Colours.LowHealth:Lerp(Color3.new(0, 0, 0), .75) }),
	},
	MidHealth = {
		TweenService:Create(PROGRESSBAR, TweenColourInfo, { BackgroundColor3 = Colours.MidHealth }),
		TweenService:Create(HEALTHBAR.UIStroke, TweenColourInfo, { Color = Colours.MidHealth:Lerp(Color3.new(0, 0, 0), .75) }),
	},
	FullHealth = {
		TweenService:Create(PROGRESSBAR, TweenColourInfo, { BackgroundColor3 = Colours.FullHealth }),
		TweenService:Create(HEALTHBAR.UIStroke, TweenColourInfo, { Color = Colours.FullHealth:Lerp(Color3.new(0, 0, 0), .75) }),
	},
}
local Connections = {}

local function RunTween(TweenName: string)
	if not Tweens[TweenName] then
		error(("Invalid Tween Name %s"):format(TweenName))
	end

	if Tweens[TweenName][1].PlaybackState == Enum.PlaybackState.Playing then
		return
	end

	for _, Tween in pairs(Tweens[TweenName]) do
		Tween:Cancel()
		Tween:Play()
	end
end

local function UpdateHP(ForceHP: number?)
	local HealthScale = 1 / (HUMANOID.MaxHealth / math.floor(ForceHP or (HUMANOID.Health + .5)))
	PROGRESSBAR:TweenSize(UDim2.new(HealthScale, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Linear, .25)
	PERCENTAGE.Text = tostring(math.floor(100 / (HUMANOID.MaxHealth / (ForceHP or HUMANOID.Health))) .. "%")

	if HealthScale > .85 then
		RunTween("FullHealth")
	elseif HealthScale >= .35 then
		RunTween("MidHealth")
	else
		RunTween("LowHealth")
	end
end

local function Cleanup()
	for i, v in pairs(Connections) do
		v:Disconnect()
		Connections[i] = nil
	end
end

table.insert(Connections, HUMANOID:GetPropertyChangedSignal("Health"):Connect(UpdateHP))
table.insert(Connections, HUMANOID:GetPropertyChangedSignal("MaxHealth"):Connect(UpdateHP))
table.insert(Connections, HUMANOID.Died:Once(function()
	UpdateHP(0)
	Cleanup()
end))

UpdateHP()
