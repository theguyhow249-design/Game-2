local Players = game:GetService("Players")

local InventoryService = {}
InventoryService.__index = InventoryService

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

local function buildWeaponVisual(parent, handle, weapon, scale)
	scale = scale or 1
	local accentColor = weapon.AccentColor or weapon.HandleColor:Lerp(Color3.fromRGB(255, 255, 255), 0.25)
	local style = weapon.ModelStyle or weapon.WeaponType

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

	if style == "Pistol" then
		handle.Size = scaleVector3(Vector3.new(0.26, 0.92, 0.54), scale)
		attachWeaponPart(parent, handle, "Slide", scaleVector3(Vector3.new(0.32, 0.2, 1.08), scale), CFrame.new(0, 0.3 * scale, -0.12 * scale), accentColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Barrel", scaleVector3(Vector3.new(0.14, 0.14, 0.88), scale), CFrame.new(0, 0.22 * scale, -0.88 * scale), accentColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Sight", scaleVector3(Vector3.new(0.1, 0.08, 0.22), scale), CFrame.new(0, 0.44 * scale, -0.12 * scale), Color3.fromRGB(22, 24, 28), Enum.Material.Metal)
		return
	end

	if style == "Carbine" then
		handle.Size = scaleVector3(Vector3.new(0.22, 1.02, 0.34), scale)
		attachWeaponPart(parent, handle, "UpperReceiver", scaleVector3(Vector3.new(0.34, 0.26, 1.24), scale), CFrame.new(0, 0.34 * scale, -0.16 * scale), accentColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "LowerReceiver", scaleVector3(Vector3.new(0.28, 0.34, 0.82), scale), CFrame.new(0, 0.08 * scale, 0.02 * scale), weapon.HandleColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Barrel", scaleVector3(Vector3.new(0.1, 0.1, 1.84), scale), CFrame.new(0, 0.32 * scale, -1.62 * scale), accentColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Handguard", scaleVector3(Vector3.new(0.24, 0.2, 0.96), scale), CFrame.new(0, 0.22 * scale, -0.92 * scale), Color3.fromRGB(34, 36, 42), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "StockCore", scaleVector3(Vector3.new(0.24, 0.46, 0.96), scale), CFrame.new(0, 0.02 * scale, 0.88 * scale), weapon.HandleColor, Enum.Material.SmoothPlastic)
		attachWeaponPart(parent, handle, "ButtPad", scaleVector3(Vector3.new(0.28, 0.54, 0.18), scale), CFrame.new(0, -0.04 * scale, 1.44 * scale), Color3.fromRGB(24, 24, 28), Enum.Material.Rubber)
		attachWeaponPart(parent, handle, "Magazine", scaleVector3(Vector3.new(0.18, 0.52, 0.22), scale), CFrame.new(0, -0.42 * scale, -0.08 * scale) * CFrame.Angles(math.rad(-8), 0, 0), weapon.HandleColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Sight", scaleVector3(Vector3.new(0.14, 0.12, 0.36), scale), CFrame.new(0, 0.54 * scale, -0.22 * scale), Color3.fromRGB(24, 26, 30), Enum.Material.Metal)
		return
	end

	if style == "SMG" then
		handle.Size = scaleVector3(Vector3.new(0.24, 0.9, 0.32), scale)
		attachWeaponPart(parent, handle, "Receiver", scaleVector3(Vector3.new(0.32, 0.24, 1.02), scale), CFrame.new(0, 0.28 * scale, -0.08 * scale), accentColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Barrel", scaleVector3(Vector3.new(0.1, 0.1, 1.02), scale), CFrame.new(0, 0.22 * scale, -1.06 * scale), accentColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Shroud", scaleVector3(Vector3.new(0.18, 0.18, 0.54), scale), CFrame.new(0, 0.24 * scale, -0.62 * scale), Color3.fromRGB(28, 30, 36), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Magazine", scaleVector3(Vector3.new(0.16, 0.72, 0.2), scale), CFrame.new(0, -0.5 * scale, -0.06 * scale), weapon.HandleColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Stock", scaleVector3(Vector3.new(0.18, 0.18, 0.72), scale), CFrame.new(0, 0.18 * scale, 0.72 * scale), Color3.fromRGB(26, 28, 32), Enum.Material.Metal)
		return
	end

	if style == "Shotgun" then
		handle.Size = scaleVector3(Vector3.new(0.26, 1, 0.34), scale)
		attachWeaponPart(parent, handle, "Receiver", scaleVector3(Vector3.new(0.36, 0.24, 1.08), scale), CFrame.new(0, 0.28 * scale, -0.1 * scale), accentColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Barrel", scaleVector3(Vector3.new(0.1, 0.1, 2.02), scale), CFrame.new(0, 0.22 * scale, -1.76 * scale), accentColor, Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Tube", scaleVector3(Vector3.new(0.08, 0.08, 1.74), scale), CFrame.new(0, 0.02 * scale, -1.54 * scale), Color3.fromRGB(96, 82, 64), Enum.Material.Metal)
		attachWeaponPart(parent, handle, "Pump", scaleVector3(Vector3.new(0.22, 0.18, 0.58), scale), CFrame.new(0, 0.08 * scale, -0.98 * scale), weapon.HandleColor, Enum.Material.WoodPlanks)
		attachWeaponPart(parent, handle, "StockCore", scaleVector3(Vector3.new(0.24, 0.42, 0.92), scale), CFrame.new(0, 0.02 * scale, 0.86 * scale), weapon.HandleColor, Enum.Material.WoodPlanks)
		attachWeaponPart(parent, handle, "ButtPad", scaleVector3(Vector3.new(0.28, 0.46, 0.16), scale), CFrame.new(0, -0.06 * scale, 1.38 * scale), Color3.fromRGB(30, 28, 24), Enum.Material.Rubber)
	end
end

local function getShowcaseMount(weapon)
	local style = weapon.ModelStyle or weapon.WeaponType
	if style == "Pistol" then
		return {
			anchorName = "RightUpperLeg",
			fallbackName = "RightLowerLeg",
			offset = CFrame.new(-0.18, 0.08, -0.14) * CFrame.Angles(math.rad(4), math.rad(90), math.rad(86)),
			scale = 0.68,
		}
	elseif style == "SMG" then
		return {
			anchorName = "UpperTorso",
			fallbackName = "Torso",
			offset = CFrame.new(0.84, -0.06, 0.58) * CFrame.Angles(math.rad(-2), math.rad(26), math.rad(98)),
			scale = 0.64,
		}
	elseif style == "Carbine" then
		return {
			anchorName = "UpperTorso",
			fallbackName = "Torso",
			offset = CFrame.new(0.92, -0.16, 0.62) * CFrame.Angles(math.rad(-6), math.rad(32), math.rad(94)),
			scale = 0.6,
		}
	elseif style == "Shotgun" then
		return {
			anchorName = "UpperTorso",
			fallbackName = "Torso",
			offset = CFrame.new(0.96, -0.22, 0.58) * CFrame.Angles(math.rad(-10), math.rad(36), math.rad(90)),
			scale = 0.56,
		}
	elseif style == "Blade" then
		return {
			anchorName = "UpperTorso",
			fallbackName = "Torso",
			offset = CFrame.new(-0.86, -0.34, 0.8) * CFrame.Angles(math.rad(24), math.rad(-10), math.rad(150)),
			scale = 0.68,
		}
	elseif style == "Crowbar" then
		return {
			anchorName = "UpperTorso",
			fallbackName = "Torso",
			offset = CFrame.new(-0.8, -0.3, 0.76) * CFrame.Angles(math.rad(16), math.rad(-8), math.rad(142)),
			scale = 0.72,
		}
	elseif style == "Axe" then
		return {
			anchorName = "UpperTorso",
			fallbackName = "Torso",
			offset = CFrame.new(0.98, -0.42, 0.54) * CFrame.Angles(math.rad(-12), math.rad(34), math.rad(88)),
			scale = 0.5,
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
		offset = CFrame.new(-0.14, 0.12, 0.86) * CFrame.Angles(math.rad(12), math.rad(4), math.rad(126)),
		scale = 0.8,
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
	return self
end

function InventoryService:Start()
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
		existing:Destroy()
	end
end

function InventoryService:_applyShowcaseCosmetic(player, showcaseModel, handle)
	local cosmeticId = self:GetEquippedCosmetic(player)
	local cosmetic = self._missionConfig.getCosmeticDefinition(cosmeticId)
	if not cosmetic or not showcaseModel or not handle then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "ShowcaseCosmeticHighlight"
	highlight.FillColor = cosmetic.HighlightColor
	highlight.OutlineColor = cosmetic.HighlightColor
	highlight.FillTransparency = math.clamp((cosmetic.FillTransparency or 0.85) + 0.08, 0, 1)
	highlight.OutlineTransparency = math.max(0, (cosmetic.OutlineTransparency or 0.05) - 0.02)
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = showcaseModel

	local attachment = Instance.new("Attachment")
	attachment.Name = "ShowcaseEffectAttachment"
	attachment.Parent = handle

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "ShowcaseEmitter"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, cosmetic.HighlightColor),
		ColorSequenceKeypoint.new(1, cosmetic.HighlightColor:Lerp(Color3.new(1, 1, 1), 0.32)),
	})
	emitter.LightEmission = 0.72
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.16),
		NumberSequenceKeypoint.new(0.55, 0.34),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Rate = 10
	emitter.Speed = NumberRange.new(0.15, 0.45)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Parent = attachment

	local light = Instance.new("PointLight")
	light.Name = "ShowcaseGlow"
	light.Color = cosmetic.HighlightColor
	light.Brightness = 0.55
	light.Range = 10
	light.Parent = handle

	local trailAttachment0 = Instance.new("Attachment")
	trailAttachment0.Name = "ShowcaseTrailStart"
	trailAttachment0.Position = Vector3.new(0, 0.2, -0.35)
	trailAttachment0.Parent = handle

	local trailAttachment1 = Instance.new("Attachment")
	trailAttachment1.Name = "ShowcaseTrailEnd"
	trailAttachment1.Position = Vector3.new(0, -0.2, 0.35)
	trailAttachment1.Parent = handle

	local trail = Instance.new("Trail")
	trail.Name = "ShowcaseTrail"
	trail.Attachment0 = trailAttachment0
	trail.Attachment1 = trailAttachment1
	trail.Color = ColorSequence.new(
		cosmetic.HighlightColor:Lerp(Color3.new(1, 1, 1), 0.18),
		cosmetic.HighlightColor
	)
	trail.LightEmission = 0.85
	trail.LightInfluence = 0
	trail.Lifetime = 0.18
	trail.MinLength = 0.02
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.26),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = handle

	local ring = Instance.new("Part")
	ring.Name = "ShowcaseRing"
	ring.Size = Vector3.new(0.9, 0.08, 0.9)
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = false
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.Massless = true
	ring.Transparency = 0.52
	ring.Material = Enum.Material.Neon
	ring.Color = cosmetic.HighlightColor
	ring.CFrame = handle.CFrame * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = showcaseModel

	local ringWeld = Instance.new("WeldConstraint")
	ringWeld.Part0 = handle
	ringWeld.Part1 = ring
	ringWeld.Parent = ring
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
	mount.CFrame = anchorPart.CFrame * mountInfo.offset
	mount.Parent = showcaseModel

	local torsoWeld = Instance.new("WeldConstraint")
	torsoWeld.Part0 = anchorPart
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
	handle.CFrame = mount.CFrame
	handle.Parent = showcaseModel

	local mountWeld = Instance.new("WeldConstraint")
	mountWeld.Part0 = mount
	mountWeld.Part1 = handle
	mountWeld.Parent = handle

	buildWeaponVisual(showcaseModel, handle, weapon, mountInfo.scale or 0.8)
	self:_applyShowcaseCosmetic(player, showcaseModel, handle)
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
	}
end

function InventoryService:GetMaxHealthBonus(player)
	local upgradeBonus = self._missionConfig.getMaxHealthBonus(self:GetUnlockedItems(player))
	local skillBonus = self._skillTreeService and self._skillTreeService:GetMaxHealthBonus(player) or 0
	return upgradeBonus + skillBonus
end

return InventoryService
