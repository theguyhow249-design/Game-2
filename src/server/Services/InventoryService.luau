local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local InventoryService = {}
InventoryService.__index = InventoryService

local WEAPON_SKIN_PROFILES = {
	cosmetic_field_cap = {
		base = Color3.fromRGB(108, 118, 86),
		accent = Color3.fromRGB(142, 156, 106),
		dark = Color3.fromRGB(44, 50, 40),
		grip = Color3.fromRGB(84, 90, 72),
		material = Enum.Material.SmoothPlastic,
	},
	cosmetic_neon_outline = {
		base = Color3.fromRGB(28, 34, 52),
		accent = Color3.fromRGB(116, 92, 255),
		dark = Color3.fromRGB(14, 18, 30),
		grip = Color3.fromRGB(46, 54, 82),
		material = Enum.Material.SmoothPlastic,
		animated = true,
		palette = {
			Color3.fromRGB(88, 210, 255),
			Color3.fromRGB(120, 84, 255),
			Color3.fromRGB(255, 96, 214),
		},
		speed = 0.75,
	},
	cosmetic_bunker_glow = {
		base = Color3.fromRGB(76, 104, 152),
		accent = Color3.fromRGB(114, 162, 232),
		dark = Color3.fromRGB(28, 38, 58),
		grip = Color3.fromRGB(58, 74, 108),
		material = Enum.Material.Metal,
	},
	cosmetic_ember_trace = {
		base = Color3.fromRGB(126, 62, 44),
		accent = Color3.fromRGB(224, 112, 74),
		dark = Color3.fromRGB(46, 22, 18),
		grip = Color3.fromRGB(82, 46, 32),
		material = Enum.Material.Metal,
		animated = true,
		palette = {
			Color3.fromRGB(178, 78, 52),
			Color3.fromRGB(255, 132, 78),
			Color3.fromRGB(255, 196, 104),
		},
		speed = 0.45,
	},
	cosmetic_medic_aura = {
		base = Color3.fromRGB(82, 126, 104),
		accent = Color3.fromRGB(136, 218, 170),
		dark = Color3.fromRGB(28, 52, 42),
		grip = Color3.fromRGB(68, 104, 86),
		material = Enum.Material.SmoothPlastic,
	},
	cosmetic_vernal_glow = {
		base = Color3.fromRGB(86, 132, 88),
		accent = Color3.fromRGB(168, 232, 156),
		dark = Color3.fromRGB(34, 58, 34),
		grip = Color3.fromRGB(74, 108, 70),
		material = Enum.Material.SmoothPlastic,
	},
}

local function scaleVector3(vector, scale)
	return Vector3.new(vector.X * scale, vector.Y * scale, vector.Z * scale)
end

local function attachWeaponPart(parent, handle, name, size, offset, color, material, shape, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Material = material or Enum.Material.Metal
	part.Color = color
	part.Transparency = transparency or 0
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = handle.CFrame * offset
	if shape then
		part.Shape = shape
	end
	part.Parent = parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function buildWeaponVisual(parent, handle, weapon, scale, styleOverride)
	scale = scale or 1
	local accentColor = weapon.AccentColor or weapon.HandleColor:Lerp(Color3.fromRGB(255, 255, 255), 0.25)
	local style = styleOverride or weapon.ModelStyle or weapon.WeaponType

	if style == "Fists" then
		handle.Transparency = 1
		attachWeaponPart(parent, handle, "RightFist", scaleVector3(Vector3.new(0.9, 0.9, 0.9), scale), CFrame.new(0, 0, 0), weapon.HandleColor, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		attachWeaponPart(parent, handle, "KnucklePlate", scaleVector3(Vector3.new(1.1, 0.35, 0.55), scale), CFrame.new(0, 0, -0.45 * scale), accentColor, Enum.Material.Metal)
		return
	end

	if style == "Blade" then
		attachWeaponPart(parent, handle, "Blade", scaleVector3(Vector3.new(0.28, 3.8, 0.8), scale), CFrame.new(0, 1.9 * scale, 0), accentColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Guard", scaleVector3(Vector3.new(1.1, 0.2, 0.35), scale), CFrame.new(0, 0.25 * scale, 0), weapon.HandleColor, Enum.Material.SmoothPlastic)
		return
	end

	if style == "Crowbar" then
		attachWeaponPart(parent, handle, "CrowbarHook", scaleVector3(Vector3.new(0.35, 0.35, 1.2), scale), CFrame.new(0, 1.55 * scale, -0.2 * scale) * CFrame.Angles(math.rad(28), 0, 0), accentColor, Enum.Material.Metal)
		return
	end

	if style == "Axe" then
		attachWeaponPart(parent, handle, "AxeHead", scaleVector3(Vector3.new(1.5, 0.9, 0.28), scale), CFrame.new(0.48 * scale, 1.3 * scale, 0), accentColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "AxeBack", scaleVector3(Vector3.new(0.42, 0.55, 0.24), scale), CFrame.new(-0.42 * scale, 1.22 * scale, 0), accentColor, Enum.Material.Metal)
		return
	end

	if style == "PistolBack" then
		handle.Size = scaleVector3(Vector3.new(0.18, 0.72, 0.2), scale)
		attachWeaponPart(parent, handle, "Body", scaleVector3(Vector3.new(0.26, 0.96, 0.18), scale), CFrame.new(0, 0.08 * scale, 0), accentColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Slide", scaleVector3(Vector3.new(0.3, 0.52, 0.14), scale), CFrame.new(0, 0.34 * scale, -0.08 * scale), Color3.fromRGB(28, 30, 36), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Muzzle", scaleVector3(Vector3.new(0.14, 0.16, 0.12), scale), CFrame.new(0, 0.62 * scale, -0.08 * scale), Color3.fromRGB(22, 22, 26), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Grip", scaleVector3(Vector3.new(0.16, 0.42, 0.18), scale), CFrame.new(0, -0.38 * scale, 0.08 * scale), weapon.HandleColor:Lerp(Color3.fromRGB(24, 24, 24), 0.18), Enum.Material.SmoothPlastic)
		return
	end

	if style == "SMGBack" then
		handle.Size = scaleVector3(Vector3.new(0.16, 1.02, 0.18), scale)
		attachWeaponPart(parent, handle, "Body", scaleVector3(Vector3.new(0.28, 1.18, 0.18), scale), CFrame.new(0, 0.02 * scale, 0), accentColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Barrel", scaleVector3(Vector3.new(0.12, 0.7, 0.12), scale), CFrame.new(0, 0.74 * scale, -0.04 * scale), Color3.fromRGB(22, 24, 28), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Magazine", scaleVector3(Vector3.new(0.14, 0.44, 0.16), scale), CFrame.new(0, -0.34 * scale, 0.08 * scale), weapon.HandleColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Stock", scaleVector3(Vector3.new(0.18, 0.46, 0.14), scale), CFrame.new(0, -0.72 * scale, 0), Color3.fromRGB(24, 26, 30), Enum.Material.Metal)
		return
	end

	if style == "CarbineBack" then
		handle.Size = scaleVector3(Vector3.new(0.16, 1.26, 0.18), scale)
		attachWeaponPart(parent, handle, "Body", scaleVector3(Vector3.new(0.28, 1.36, 0.18), scale), CFrame.new(0, 0, 0), accentColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Barrel", scaleVector3(Vector3.new(0.1, 1.2, 0.1), scale), CFrame.new(0, 1.06 * scale, -0.04 * scale), Color3.fromRGB(22, 24, 28), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Magazine", scaleVector3(Vector3.new(0.14, 0.48, 0.16), scale), CFrame.new(0, -0.18 * scale, 0.08 * scale), weapon.HandleColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Stock", scaleVector3(Vector3.new(0.2, 0.56, 0.16), scale), CFrame.new(0, -0.92 * scale, 0.02 * scale), weapon.HandleColor, Enum.Material.SmoothPlastic)
		attachWeaponPart(parent, handle, "Sight", scaleVector3(Vector3.new(0.12, 0.18, 0.1), scale), CFrame.new(0, 0.42 * scale, -0.08 * scale), Color3.fromRGB(20, 22, 26), Enum.Material.Metal)
		return
	end

	if style == "ShotgunBack" then
		handle.Size = scaleVector3(Vector3.new(0.18, 1.32, 0.18), scale)
		attachWeaponPart(parent, handle, "Receiver", scaleVector3(Vector3.new(0.3, 1.08, 0.18), scale), CFrame.new(0, 0.06 * scale, 0), accentColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Barrel", scaleVector3(Vector3.new(0.1, 1.46, 0.1), scale), CFrame.new(0, 1.12 * scale, -0.04 * scale), Color3.fromRGB(24, 24, 26), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Pump", scaleVector3(Vector3.new(0.18, 0.42, 0.16), scale), CFrame.new(0, 0.38 * scale, 0.06 * scale), weapon.HandleColor, Enum.Material.WoodPlanks)
		attachWeaponPart(parent, handle, "Stock", scaleVector3(Vector3.new(0.22, 0.66, 0.16), scale), CFrame.new(0, -0.86 * scale, 0.02 * scale), weapon.HandleColor, Enum.Material.WoodPlanks)
		return
	end

	if style == "Pistol" then
		handle.Size = scaleVector3(Vector3.new(0.26, 0.92, 0.54), scale)
		attachWeaponPart(parent, handle, "Frame", scaleVector3(Vector3.new(0.24, 0.32, 0.58), scale), CFrame.new(0, 0.02 * scale, 0.08 * scale), weapon.HandleColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Slide", scaleVector3(Vector3.new(0.34, 0.2, 1.24), scale), CFrame.new(0, 0.3 * scale, -0.2 * scale), accentColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "SlideTop", scaleVector3(Vector3.new(0.24, 0.05, 0.96), scale), CFrame.new(0, 0.42 * scale, -0.16 * scale), Color3.fromRGB(34, 36, 42), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Barrel", scaleVector3(Vector3.new(0.12, 0.12, 1.02), scale), CFrame.new(0, 0.22 * scale, -0.98 * scale), Color3.fromRGB(24, 26, 30), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Muzzle", scaleVector3(Vector3.new(0.16, 0.16, 0.12), scale), CFrame.new(0, 0.22 * scale, -1.58 * scale), Color3.fromRGB(26, 26, 30), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "GripPanel", scaleVector3(Vector3.new(0.16, 0.5, 0.24), scale), CFrame.new(0, -0.18 * scale, 0.16 * scale), Color3.fromRGB(22, 24, 28), Enum.Material.SmoothPlastic)
		attachWeaponPart(parent, handle, "FrontSight", scaleVector3(Vector3.new(0.04, 0.04, 0.04), scale), CFrame.new(0, 0.48 * scale, -1.16 * scale), Color3.fromRGB(126, 255, 112), Enum.Material.Neon)
		attachWeaponPart(parent, handle, "RearSightLeft", scaleVector3(Vector3.new(0.04, 0.04, 0.04), scale), CFrame.new(-0.08 * scale, 0.48 * scale, 0.02 * scale), Color3.fromRGB(126, 255, 112), Enum.Material.Neon)
		attachWeaponPart(parent, handle, "RearSightRight", scaleVector3(Vector3.new(0.04, 0.04, 0.04), scale), CFrame.new(0.08 * scale, 0.48 * scale, 0.02 * scale), Color3.fromRGB(126, 255, 112), Enum.Material.Neon)
		return
	end

	if style == "Carbine" then
		handle.Size = scaleVector3(Vector3.new(0.22, 1.02, 0.34), scale)
		attachWeaponPart(parent, handle, "UpperReceiver", scaleVector3(Vector3.new(0.34, 0.24, 1.38), scale), CFrame.new(0, 0.34 * scale, -0.24 * scale), accentColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "LowerReceiver", scaleVector3(Vector3.new(0.28, 0.3, 0.78), scale), CFrame.new(0, 0.08 * scale, 0.04 * scale), weapon.HandleColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Barrel", scaleVector3(Vector3.new(0.09, 0.09, 2.12), scale), CFrame.new(0, 0.3 * scale, -1.96 * scale), Color3.fromRGB(24, 26, 30), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Handguard", scaleVector3(Vector3.new(0.22, 0.18, 1.14), scale), CFrame.new(0, 0.2 * scale, -1.08 * scale), Color3.fromRGB(34, 36, 42), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "TopRail", scaleVector3(Vector3.new(0.1, 0.04, 2.06), scale), CFrame.new(0, 0.48 * scale, -0.84 * scale), Color3.fromRGB(18, 20, 24), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "MuzzleBrake", scaleVector3(Vector3.new(0.12, 0.12, 0.18), scale), CFrame.new(0, 0.3 * scale, -2.98 * scale), Color3.fromRGB(20, 20, 22), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "StockStrut", scaleVector3(Vector3.new(0.08, 0.14, 0.84), scale), CFrame.new(0, 0.18 * scale, 1.08 * scale), Color3.fromRGB(22, 24, 28), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "StockCore", scaleVector3(Vector3.new(0.22, 0.4, 1.04), scale), CFrame.new(0, 0.02 * scale, 1.02 * scale), weapon.HandleColor, Enum.Material.SmoothPlastic)
		attachWeaponPart(parent, handle, "ButtPad", scaleVector3(Vector3.new(0.24, 0.48, 0.16), scale), CFrame.new(0, -0.04 * scale, 1.62 * scale), Color3.fromRGB(24, 24, 28), Enum.Material.Rubber)
		attachWeaponPart(parent, handle, "Magazine", scaleVector3(Vector3.new(0.16, 0.58, 0.18), scale), CFrame.new(0, -0.42 * scale, -0.06 * scale) * CFrame.Angles(math.rad(-6), 0, 0), Color3.fromRGB(28, 30, 34), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "FrontSight", scaleVector3(Vector3.new(0.04, 0.04, 0.04), scale), CFrame.new(0, 0.56 * scale, -1.96 * scale), Color3.fromRGB(126, 255, 112), Enum.Material.Neon)
		attachWeaponPart(parent, handle, "RearSightLeft", scaleVector3(Vector3.new(0.04, 0.04, 0.04), scale), CFrame.new(-0.06 * scale, 0.56 * scale, 0.08 * scale), Color3.fromRGB(126, 255, 112), Enum.Material.Neon)
		attachWeaponPart(parent, handle, "RearSightRight", scaleVector3(Vector3.new(0.04, 0.04, 0.04), scale), CFrame.new(0.06 * scale, 0.56 * scale, 0.08 * scale), Color3.fromRGB(126, 255, 112), Enum.Material.Neon)
		return
	end

	if style == "SMG" then
		handle.Size = scaleVector3(Vector3.new(0.24, 0.9, 0.32), scale)
		attachWeaponPart(parent, handle, "Receiver", scaleVector3(Vector3.new(0.32, 0.22, 1.18), scale), CFrame.new(0, 0.28 * scale, -0.16 * scale), accentColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "ReceiverTop", scaleVector3(Vector3.new(0.22, 0.04, 0.96), scale), CFrame.new(0, 0.42 * scale, -0.12 * scale), Color3.fromRGB(18, 20, 24), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Barrel", scaleVector3(Vector3.new(0.09, 0.09, 1.24), scale), CFrame.new(0, 0.22 * scale, -1.22 * scale), Color3.fromRGB(22, 22, 24), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Shroud", scaleVector3(Vector3.new(0.16, 0.16, 0.72), scale), CFrame.new(0, 0.24 * scale, -0.76 * scale), Color3.fromRGB(28, 30, 36), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Muzzle", scaleVector3(Vector3.new(0.12, 0.12, 0.12), scale), CFrame.new(0, 0.22 * scale, -1.86 * scale), Color3.fromRGB(22, 22, 24), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Magazine", scaleVector3(Vector3.new(0.14, 0.82, 0.18), scale), CFrame.new(0, -0.52 * scale, -0.04 * scale), Color3.fromRGB(28, 30, 34), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Stock", scaleVector3(Vector3.new(0.16, 0.16, 0.9), scale), CFrame.new(0, 0.18 * scale, 0.9 * scale), Color3.fromRGB(26, 28, 32), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "StockPad", scaleVector3(Vector3.new(0.18, 0.22, 0.12), scale), CFrame.new(0, 0.18 * scale, 1.4 * scale), Color3.fromRGB(18, 18, 20), Enum.Material.Rubber)
		attachWeaponPart(parent, handle, "FrontSight", scaleVector3(Vector3.new(0.04, 0.04, 0.04), scale), CFrame.new(0, 0.48 * scale, -1.28 * scale), Color3.fromRGB(126, 255, 112), Enum.Material.Neon)
		attachWeaponPart(parent, handle, "RearSightLeft", scaleVector3(Vector3.new(0.04, 0.04, 0.04), scale), CFrame.new(-0.06 * scale, 0.48 * scale, 0.06 * scale), Color3.fromRGB(126, 255, 112), Enum.Material.Neon)
		attachWeaponPart(parent, handle, "RearSightRight", scaleVector3(Vector3.new(0.04, 0.04, 0.04), scale), CFrame.new(0.06 * scale, 0.48 * scale, 0.06 * scale), Color3.fromRGB(126, 255, 112), Enum.Material.Neon)
		return
	end

	if style == "Shotgun" then
		handle.Size = scaleVector3(Vector3.new(0.26, 1, 0.34), scale)
		attachWeaponPart(parent, handle, "Receiver", scaleVector3(Vector3.new(0.36, 0.22, 1.22), scale), CFrame.new(0, 0.28 * scale, -0.16 * scale), accentColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "ReceiverTop", scaleVector3(Vector3.new(0.24, 0.04, 0.86), scale), CFrame.new(0, 0.42 * scale, -0.12 * scale), Color3.fromRGB(34, 30, 28), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Barrel", scaleVector3(Vector3.new(0.09, 0.09, 2.34), scale), CFrame.new(0, 0.22 * scale, -2.06 * scale), Color3.fromRGB(22, 22, 24), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Tube", scaleVector3(Vector3.new(0.08, 0.08, 2.02), scale), CFrame.new(0, 0.02 * scale, -1.82 * scale), Color3.fromRGB(96, 82, 64), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Pump", scaleVector3(Vector3.new(0.2, 0.16, 0.74), scale), CFrame.new(0, 0.08 * scale, -1.18 * scale), weapon.HandleColor, Enum.Material.WoodPlanks)
		attachWeaponPart(parent, handle, "VentRib", scaleVector3(Vector3.new(0.05, 0.03, 1.96), scale), CFrame.new(0, 0.34 * scale, -1.74 * scale), Color3.fromRGB(18, 18, 20), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "FrontBead", scaleVector3(Vector3.new(0.04, 0.04, 0.04), scale), CFrame.new(0, 0.42 * scale, -3.18 * scale), Color3.fromRGB(220, 184, 96), Enum.Material.Neon)
		attachWeaponPart(parent, handle, "StockCore", scaleVector3(Vector3.new(0.22, 0.38, 1.04), scale), CFrame.new(0, 0.02 * scale, 1.02 * scale), weapon.HandleColor, Enum.Material.WoodPlanks)
		attachWeaponPart(parent, handle, "ButtPad", scaleVector3(Vector3.new(0.26, 0.42, 0.16), scale), CFrame.new(0, -0.06 * scale, 1.62 * scale), Color3.fromRGB(30, 28, 24), Enum.Material.Rubber)
		attachWeaponPart(parent, handle, "TriggerGuard", scaleVector3(Vector3.new(0.16, 0.1, 0.18), scale), CFrame.new(0, -0.12 * scale, 0.08 * scale), Color3.fromRGB(18, 18, 20), Enum.Material.Metal)
	end
end

local function getShowcaseMount(weapon)
	local style = weapon.ModelStyle or weapon.WeaponType
	if style == "Pistol" then
		return {
			anchorName = "UpperTorso",
			attachmentName = "BodyBackAttachment",
			fallbackName = "Torso",
			useTorsoBackAnchor = true,
			backOffset = Vector3.new(0.34, -0.02, 0.08),
			offset = CFrame.Angles(math.rad(10), math.rad(90), math.rad(28)),
			handleOffset = CFrame.new(0, -0.08, 0),
			visualStyle = "PistolBack",
			scale = 1.18,
		}
	elseif style == "SMG" then
		return {
			anchorName = "UpperTorso",
			attachmentName = "BodyBackAttachment",
			fallbackName = "Torso",
			useTorsoBackAnchor = true,
			backOffset = Vector3.new(-0.18, 0.12, 0.08),
			offset = CFrame.Angles(math.rad(18), math.rad(90), math.rad(48)),
			handleOffset = CFrame.new(0, -0.16, 0),
			visualStyle = "SMGBack",
			scale = 1.24,
		}
	elseif style == "Carbine" then
		return {
			anchorName = "UpperTorso",
			attachmentName = "BodyBackAttachment",
			fallbackName = "Torso",
			useTorsoBackAnchor = true,
			backOffset = Vector3.new(-0.22, 0.18, 0.08),
			offset = CFrame.Angles(math.rad(22), math.rad(90), math.rad(54)),
			handleOffset = CFrame.new(0, -0.22, 0),
			visualStyle = "CarbineBack",
			scale = 1.2,
		}
	elseif style == "Shotgun" then
		return {
			anchorName = "UpperTorso",
			attachmentName = "BodyBackAttachment",
			fallbackName = "Torso",
			useTorsoBackAnchor = true,
			backOffset = Vector3.new(-0.2, 0.16, 0.06),
			offset = CFrame.Angles(math.rad(24), math.rad(90), math.rad(52)),
			handleOffset = CFrame.new(0, -0.24, 0),
			visualStyle = "ShotgunBack",
			scale = 1.16,
		}
	elseif style == "Blade" then
		return {
			anchorName = "UpperTorso",
			fallbackName = "Torso",
			offset = CFrame.new(-0.72, -0.12, 0.72) * CFrame.Angles(math.rad(32), math.rad(-8), math.rad(138)),
			scale = 1.06,
		}
	elseif style == "Crowbar" then
		return {
			anchorName = "UpperTorso",
			fallbackName = "Torso",
			offset = CFrame.new(-0.68, -0.1, 0.74) * CFrame.Angles(math.rad(22), math.rad(-6), math.rad(136)),
			scale = 1.08,
		}
	elseif style == "Axe" then
		return {
			anchorName = "UpperTorso",
			fallbackName = "Torso",
			offset = CFrame.new(0.82, -0.12, 0.46) * CFrame.Angles(math.rad(-6), math.rad(28), math.rad(94)),
			scale = 0.96,
		}
	elseif style == "Fists" then
		return {
			anchorName = "UpperTorso",
			fallbackName = "Torso",
			offset = CFrame.new(0, -6, 0),
			scale = 0.7,
		}
	end
	return {
		anchorName = "UpperTorso",
		fallbackName = "Torso",
		offset = CFrame.new(-0.18, 0.12, 0.76) * CFrame.Angles(math.rad(18), math.rad(8), math.rad(132)),
		scale = 1.04,
	}
end

function InventoryService.new(context)
	local self = setmetatable({}, InventoryService)
	self._persistenceService = context.PersistenceService
	self._missionConfig = context.MissionConfig
	self._tokenEconomy = context.TokenEconomy
	self._skillTreeService = context.SkillTreeService
	self._subscriptionService = context.SubscriptionService
	self._roleService = context.RoleService
	self._animatedShowcases = {}
	self._showcaseHeartbeat = nil
	return self
end

function InventoryService:Start()
	if not self._showcaseHeartbeat then
		self._showcaseHeartbeat = RunService.Heartbeat:Connect(function()
			self:_stepShowcaseSkins()
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		self:BindPlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:BindPlayer(player)
	end
end

function InventoryService:_applyCosmeticToCharacter(player, character)
	if not character then
		return
	end

	local existing = character:FindFirstChild("EquippedCosmeticHighlight")
	if existing then
		existing:Destroy()
	end
end

function InventoryService:_clearWeaponShowcase(character)
	if not character then
		return
	end
	local existing = character:FindFirstChild("EquippedWeaponShowcase")
	if existing then
		self._animatedShowcases[existing] = nil
		existing:Destroy()
	end
end

function InventoryService:_classifyWeaponPart(part)
	local name = string.lower(part.Name)
	if string.find(name, "barrel", 1, true) or string.find(name, "tube", 1, true) then
		return "barrel"
	end
	if string.find(name, "receiver", 1, true) or string.find(name, "slide", 1, true) or string.find(name, "shroud", 1, true) then
		return "body"
	end
	if string.find(name, "stock", 1, true) or string.find(name, "pump", 1, true) or string.find(name, "guard", 1, true) then
		return "grip"
	end
	if string.find(name, "sight", 1, true) or string.find(name, "butt", 1, true) or string.find(name, "magazine", 1, true) then
		return "detail"
	end
	if name == "handle" then
		return "grip"
	end
	return "body"
end

function InventoryService:_stepShowcaseSkins()
	local timeNow = os.clock()
	for model, state in pairs(self._animatedShowcases) do
		if not model or model.Parent == nil then
			self._animatedShowcases[model] = nil
		else
			local profile = state.profile
			local palette = profile and profile.palette
			if profile and palette and #palette >= 3 then
				local phase = (timeNow * (profile.speed or 0.5)) + (state.phase or 0)
				local blendA = (math.sin(phase) + 1) * 0.5
				local blendB = (math.sin(phase + 1.6) + 1) * 0.5
				local mainColor = palette[1]:Lerp(palette[2], blendA)
				local accentColor = palette[2]:Lerp(palette[3], blendB)
				for _, part in ipairs(state.bodyParts) do
					if part and part.Parent then
						part.Color = mainColor
					end
				end
				for _, part in ipairs(state.accentParts) do
					if part and part.Parent then
						part.Color = accentColor
					end
				end
			end
		end
	end
end

function InventoryService:_applyShowcaseCosmetic(player, showcaseModel)
	local cosmeticId = self:GetEquippedCosmetic(player)
	local profile = WEAPON_SKIN_PROFILES[cosmeticId]
	if not profile or not showcaseModel then
		return
	end

	local bodyParts = {}
	local accentParts = {}
	for _, descendant in ipairs(showcaseModel:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "Mount" then
			local group = self:_classifyWeaponPart(descendant)
			if group == "barrel" or group == "body" then
				descendant.Color = profile.base
				descendant.Material = profile.material
				table.insert(bodyParts, descendant)
			elseif group == "grip" then
				descendant.Color = profile.grip
				descendant.Material = Enum.Material.SmoothPlastic
			else
				descendant.Color = profile.accent
				descendant.Material = Enum.Material.Metal
				table.insert(accentParts, descendant)
			end
		end
	end

	if profile.animated then
		self._animatedShowcases[showcaseModel] = {
			profile = profile,
			bodyParts = bodyParts,
			accentParts = accentParts,
			phase = player.UserId % 17,
		}
	end
end

function InventoryService:_applyWeaponShowcase(player, character)
	if not character then
		return
	end

	self:_clearWeaponShowcase(character)

	if player:GetAttribute("InMission") == true then
		return
	end

	local weaponId = self:GetEquippedWeaponId(player)
	local weapon = self:GetWeaponDefinition(weaponId)
	if not weapon or (weapon.ModelStyle == "Fists") then
		return
	end

	local mountInfo = getShowcaseMount(weapon)
	local anchorPart = character:FindFirstChild(mountInfo.anchorName) or character:FindFirstChild(mountInfo.fallbackName)
	if not anchorPart or not anchorPart:IsA("BasePart") then
		return
	end
	local anchorAttachment = mountInfo.attachmentName and anchorPart:FindFirstChild(mountInfo.attachmentName)
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	local showcaseModel = Instance.new("Model")
	showcaseModel.Name = "EquippedWeaponShowcase"
	showcaseModel.Parent = character

	local mount = Instance.new("Part")
	mount.Name = "Mount"
	mount.Size = Vector3.new(0.2, 0.2, 0.2)
	mount.Transparency = 1
	mount.CanCollide = false
	mount.CanTouch = false
	mount.CanQuery = false
	mount.Massless = true
	if mountInfo.useTorsoBackAnchor and anchorPart and anchorPart:IsA("BasePart") and typeof(mountInfo.backOffset) == "Vector3" then
		local offset = mountInfo.backOffset
		local worldPosition = anchorPart.Position
			+ (anchorPart.CFrame.RightVector * offset.X)
			+ (anchorPart.CFrame.UpVector * offset.Y)
			- (anchorPart.CFrame.LookVector * ((anchorPart.Size.Z * 0.5) + offset.Z))
		mount.CFrame = CFrame.fromMatrix(worldPosition, anchorPart.CFrame.RightVector, anchorPart.CFrame.UpVector) * mountInfo.offset
	elseif mountInfo.useRootBackAnchor and rootPart and rootPart:IsA("BasePart") and typeof(mountInfo.rootOffset) == "Vector3" then
		mount.CFrame = rootPart.CFrame * CFrame.new(mountInfo.rootOffset) * mountInfo.offset
	else
		mount.CFrame = (anchorAttachment and anchorAttachment:IsA("Attachment") and anchorAttachment.WorldCFrame or anchorPart.CFrame) * mountInfo.offset
	end
	mount.Parent = showcaseModel

	local torsoWeld = Instance.new("WeldConstraint")
	torsoWeld.Part0 = (mountInfo.useRootBackAnchor and rootPart and rootPart:IsA("BasePart")) and rootPart or anchorPart
	torsoWeld.Part1 = mount
	torsoWeld.Parent = mount

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = scaleVector3(weapon.HandleSize or Vector3.new(0.7, 1.4, 1), mountInfo.scale or 0.8)
	handle.Material = Enum.Material.SmoothPlastic
	handle.Color = weapon.HandleColor
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CFrame = mount.CFrame * (mountInfo.handleOffset or CFrame.new())
	handle.Parent = showcaseModel

	local mountWeld = Instance.new("WeldConstraint")
	mountWeld.Part0 = mount
	mountWeld.Part1 = handle
	mountWeld.Parent = handle

	buildWeaponVisual(showcaseModel, handle, weapon, mountInfo.scale or 0.8, mountInfo.visualStyle)
	self:_applyShowcaseCosmetic(player, showcaseModel)
end

function InventoryService:BindPlayer(player)
	local unlocks = self._persistenceService:GetUnlocks(player)
	for categoryName, items in pairs(self._tokenEconomy.ShopCatalog) do
		for _, item in ipairs(items) do
			local unlocked = unlocks[item.Id] == true
			player:SetAttribute(("ShopUnlocked_%s_%s"):format(categoryName, item.Id), unlocked)
		end
	end

	local equippedWeapon = self:GetEquippedWeaponId(player)
	player:SetAttribute("EquippedWeaponId", equippedWeapon)
	player:SetAttribute("EquippedWeaponName", self:GetWeaponDefinition(equippedWeapon).DisplayName)
	player:SetAttribute("EquippedCosmeticId", self:GetEquippedCosmetic(player))
	player:SetAttribute("SubscriptionExtraInventorySlots", self._subscriptionService and self._subscriptionService:GetExtraInventorySlots(player) or 0)

	player.CharacterAdded:Connect(function(character)
		task.wait(0.1)
		self:_applyCosmeticToCharacter(player, character)
		self:_applyWeaponShowcase(player, character)
	end)

	player:GetAttributeChangedSignal("EquippedWeaponId"):Connect(function()
		if player.Character then
			self:_applyWeaponShowcase(player, player.Character)
		end
	end)
	player:GetAttributeChangedSignal("EquippedCosmeticId"):Connect(function()
		if player.Character then
			self:_applyCosmeticToCharacter(player, player.Character)
			self:_applyWeaponShowcase(player, player.Character)
		end
	end)
	player:GetAttributeChangedSignal("InMission"):Connect(function()
		if player.Character then
			self:_applyWeaponShowcase(player, player.Character)
		end
	end)

	if player.Character then
		self:_applyCosmeticToCharacter(player, player.Character)
		self:_applyWeaponShowcase(player, player.Character)
	end
end

function InventoryService:GetWeaponDefinition(itemId)
	return self._missionConfig.getWeaponDefinition(itemId)
end

function InventoryService:GetEquippedWeaponId(player)
	local equipped = self._persistenceService:GetEquippedWeapon(player)
	local definition = self._missionConfig.Weapons[equipped]
	if definition then
		return equipped
	end
	return self._missionConfig.DefaultWeaponId
end

function InventoryService:GetUnlockedItems(player)
	return self._persistenceService:GetUnlocks(player)
end

function InventoryService:IsUnlocked(player, itemId)
	return self._persistenceService:IsUnlocked(player, itemId)
end

function InventoryService:UnlockItem(player, itemId)
	self._persistenceService:UnlockItem(player, itemId)
	for categoryName, items in pairs(self._tokenEconomy.ShopCatalog) do
		for _, item in ipairs(items) do
			if item.Id == itemId then
				player:SetAttribute(("ShopUnlocked_%s_%s"):format(categoryName, item.Id), true)
			end
		end
	end
end

function InventoryService:EquipWeapon(player, itemId)
	if not self:IsUnlocked(player, itemId) then
		return false, "locked"
	end

	if not self._missionConfig.Weapons[itemId] then
		return false, "missing_weapon"
	end

	self._persistenceService:SetEquippedWeapon(player, itemId)
	player:SetAttribute("EquippedWeaponId", itemId)
	player:SetAttribute("EquippedWeaponName", self:GetWeaponDefinition(itemId).DisplayName)
	return true
end

function InventoryService:GetEquippedCosmetic(player)
	return self._persistenceService:GetEquippedCosmetic(player)
end

function InventoryService:EquipCosmetic(player, itemId)
	if itemId and itemId ~= "" and not self:IsUnlocked(player, itemId) then
		return false, "locked"
	end

	if itemId and itemId ~= "" and not self._missionConfig.getCosmeticDefinition(itemId) then
		return false, "missing_cosmetic"
	end

	local normalized = (itemId and itemId ~= "") and itemId or nil
	self._persistenceService:SetEquippedCosmetic(player, normalized)
	player:SetAttribute("EquippedCosmeticId", normalized)
	if player.Character then
		self:_applyCosmeticToCharacter(player, player.Character)
	end
	return true
end

function InventoryService:BuildProgressionPayload(player)
	local profile = self._persistenceService:GetProfile(player)
	return {
		equippedWeapon = self:GetEquippedWeaponId(player),
		equippedCosmetic = self:GetEquippedCosmetic(player),
		identity = self._roleService and self._roleService:GetIdentity(player) or nil,
		unlocks = profile.unlocks,
		weaponExperience = self._persistenceService:GetWeaponExperienceMap(player),
		stats = profile.stats,
		skillTree = self._skillTreeService and self._skillTreeService:BuildPayload(player) or nil,
		subscription = self._subscriptionService and self._subscriptionService:GetState(player) or nil,
		activities = self._persistenceService:GetActivityStats(player),
	}
end

function InventoryService:GetMaxHealthBonus(player)
	local upgradeBonus = self._missionConfig.getMaxHealthBonus(self:GetUnlockedItems(player))
	local skillBonus = self._skillTreeService and self._skillTreeService:GetMaxHealthBonus(player) or 0
	return upgradeBonus + skillBonus
end

return InventoryService
