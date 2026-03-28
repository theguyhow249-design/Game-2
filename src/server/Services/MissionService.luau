local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MissionService = {}
MissionService.__index = MissionService

local function createRuntimePart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = true
	part.Color = color
	part.Material = material or Enum.Material.Metal
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = cframe
	part.Parent = parent
	return part
end

local function createRuntimeGlow(parent, name, size, cframe, color, transparency)
	local part = createRuntimePart(parent, name, size, cframe, color, Enum.Material.Neon)
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = transparency or 0.4
	return part
end

local function resolveMaterial(materialName)
	if type(materialName) == "string" then
		return Enum.Material[materialName] or Enum.Material.Metal
	end
	if materialName then
		return materialName
	end
	return Enum.Material.Metal
end

local function createRuntimeDecoration(parent, decoration, cframe)
	local part = createRuntimePart(parent, decoration.Name, decoration.Size, cframe, decoration.Color, resolveMaterial(decoration.Material))
	part.Transparency = decoration.Transparency or 0
	part.CanCollide = decoration.CanCollide ~= false
	part.CanQuery = decoration.CanQuery ~= false
	part.CanTouch = decoration.CanTouch == true
	return part
end

local function findMissionEntryById(entries, entryId, fallback)
	if type(entryId) == "string" then
		for _, entry in ipairs(entries or {}) do
			if entry.Id == entryId then
				return entry
			end
		end
	end
	return fallback
end

local function clampPositiveInteger(value, fallback)
	local parsed = math.floor(tonumber(value) or fallback or 0)
	return math.max(1, parsed)
end

function MissionService.new(context)
	local self = setmetatable({}, MissionService)
	self._missionConfig = context.MissionConfig
	self._tokenEconomy = context.TokenEconomy
	self._flowService = context.FlowService
	self._scalingService = context.ScalingService
	self._tokenService = context.TokenService
	self._inventoryService = context.InventoryService
	self._gamePassService = context.GamePassService
	self._persistenceService = context.PersistenceService
	self._dailyOpsService = context.DailyOpsService
	self._skillTreeConfig = context.SkillTreeConfig
	self._skillTreeService = context.SkillTreeService
	self._subscriptionService = context.SubscriptionService
	self._instanceDeploymentService = context.InstanceDeploymentService
	self._remoteNames = context.RemoteNames
	self._remotes = context.Remotes
	self._activeMission = nil
	self._attackCooldowns = {}
	self._weaponState = {}
	return self
end

function MissionService:SetInstanceDeploymentService(service)
	self._instanceDeploymentService = service
end

function MissionService:Start()
end

function MissionService:_getMissionObjective()
	local mission = self:_getMissionModel()
	local runtime = mission and mission:FindFirstChild("MissionRuntime")
	return runtime and runtime:FindFirstChild("ObjectiveCore")
end

function MissionService:_getExtractionPad()
	local mission = self:_getMissionModel()
	local runtime = mission and mission:FindFirstChild("MissionRuntime")
	return runtime and runtime:FindFirstChild("ExtractionPad")
end

function MissionService:_isCharacterInsideExtractionPad(rootPart, pad)
	if not rootPart or not pad then
		return false
	end

	local localPoint = pad.CFrame:PointToObjectSpace(rootPart.Position)
	local half = pad.Size * 0.5
	local buffer = 2.5
	return math.abs(localPoint.X) <= (half.X + buffer)
		and math.abs(localPoint.Z) <= (half.Z + buffer)
		and math.abs(localPoint.Y) <= 8
end

function MissionService:_getLobbyRoot()
	return Workspace:FindFirstChild(self._flowService._gameFlowConfig.LobbyName)
end

function MissionService:_getMissionModel()
	local root = self:_getLobbyRoot()
	return root and root:FindFirstChild("MissionStaging")
end

function MissionService:_getMissionSpawn()
	local mission = self:_getMissionModel()
	return mission and mission:FindFirstChild("MissionSpawn")
end

function MissionService:_getMissionAnchorCFrame()
	local spawn = self:_getMissionSpawn()
	return spawn and spawn.CFrame or nil
end

function MissionService:_getPlayerMissionSpawnCFrame()
	local anchor = self:_getMissionAnchorCFrame()
	local layout = self:_getActiveLayout()
	if not anchor then
		return nil
	end

	if layout and layout.PlayerSpawnOffset then
		local basePosition = (anchor * CFrame.new(layout.PlayerSpawnOffset)).Position
		local lookOffset = layout.PlayerSpawnLookOffset or Vector3.new(0, 0, 18)
		local lookPosition = (anchor * CFrame.new(layout.PlayerSpawnOffset + lookOffset)).Position
		return CFrame.lookAt(basePosition, lookPosition)
	end

	return anchor
end

function MissionService:_grantSpawnProtection(player)
	if not player then
		return
	end

	local protectionSeconds = self._missionConfig.Mission.SpawnProtectionSeconds or 0
	local expiresAt = os.clock() + protectionSeconds
	player:SetAttribute("MissionSpawnProtectedUntil", expiresAt)

	local character = player.Character
	if character and character.Parent then
		character:SetAttribute("MissionSpawnProtectedUntil", expiresAt)
	end
end

function MissionService:_isSpawnProtected(player, character)
	if not player then
		return false
	end

	local expiresAt = player:GetAttribute("MissionSpawnProtectedUntil")
	if type(expiresAt) ~= "number" and character then
		expiresAt = character:GetAttribute("MissionSpawnProtectedUntil")
	end

	return type(expiresAt) == "number" and os.clock() < expiresAt
end

function MissionService:_getLobbySpawn()
	local root = self:_getLobbyRoot()
	return root and root:FindFirstChild("LobbySpawn")
end

function MissionService:_isPowerCellScenario(mission)
	local currentMission = mission or self._activeMission
	return currentMission and currentMission.scenario and currentMission.scenario.ObjectiveType == "PowerCells"
end

function MissionService:_isNestScenario(mission)
	local currentMission = mission or self._activeMission
	return currentMission and currentMission.scenario and currentMission.scenario.ObjectiveType == "NestHunt"
end

function MissionService:_clearRuntime()
	local mission = self:_getMissionModel()
	if not mission then
		return
	end

	local runtime = mission:FindFirstChild("MissionRuntime")
	if runtime then
		runtime:Destroy()
	end
end

function MissionService:_notifyParty(players, message)
	if not self._remotes then
		return
	end

	for _, player in ipairs(players) do
		if player and player.Parent then
			self._remotes:FireEventFor(player, self._remoteNames.Events.Notification, {
				userId = player.UserId,
				message = message,
			})
		end
	end
end

function MissionService:_notifyResults(mission, success, summary, rewardTokens)
	if not self._remotes or not mission then
		return
	end

	for _, player in ipairs(mission.party) do
		if player and player.Parent then
			local stats = self._persistenceService:GetStats(player)
			local progression = self._skillTreeService and self._skillTreeService:BuildPayload(player) or nil
			local dailyOpsState = self._dailyOpsService and self._dailyOpsService:GetState(player) or nil
			local runStats = mission.runStats and mission.runStats[player.UserId] or nil
			local playerReward = rewardTokens + (self._skillTreeService and self._skillTreeService:GetRewardBonus(player) or 0)
			if self._subscriptionService then
				playerReward = self._subscriptionService:GetAdjustedTokenRewardAmount(player, playerReward)
			end
			if self._gamePassService then
				playerReward = math.max(0, math.floor((playerReward * self._gamePassService:GetTokenRewardMultiplier(player)) + 0.5))
			end
			self._remotes:FireEventFor(player, self._remoteNames.Events.Notification, {
				userId = player.UserId,
				kind = "Results",
				success = success,
				summary = summary,
				rewardTokens = playerReward,
				scenarioName = mission.scenario and mission.scenario.DisplayName or "Hold The Core",
				layoutName = mission.layout and mission.layout.DisplayName or "Mission Arena",
				wave = mission.wave or 0,
				totalWaves = self._missionConfig.Mission.WaveCount,
				kills = runStats and runStats.kills or (stats and stats.zombiesDefeated or 0),
				xpGained = runStats and runStats.xpGained or 0,
				xpBreakdown = runStats and runStats.xpBreakdown or {},
				dailyOps = dailyOpsState and dailyOpsState.tasks or {},
				level = progression and progression.level or 1,
				skillPoints = progression and progression.skillPoints or 0,
			})
		end
	end
end

function MissionService:_getRunStats(player)
	local mission = self._activeMission
	if not mission or not player then
		return nil
	end

	mission.runStats = mission.runStats or {}
	local stats = mission.runStats[player.UserId]
	if not stats then
		stats = {
			kills = 0,
			xpGained = 0,
			xpBreakdown = {},
		}
		mission.runStats[player.UserId] = stats
	end
	return stats
end

function MissionService:_recordZombieDamage(zombieModel, attacker, damage)
	local mission = self._activeMission
	if not mission or not zombieModel or not attacker or not attacker.UserId or not damage or damage <= 0 then
		return
	end

	mission.zombieDamageByZombie = mission.zombieDamageByZombie or setmetatable({}, { __mode = "k" })
	mission.zombieLastHitByZombie = mission.zombieLastHitByZombie or setmetatable({}, { __mode = "k" })

	local damageByPlayer = mission.zombieDamageByZombie[zombieModel]
	if not damageByPlayer then
		damageByPlayer = {}
		mission.zombieDamageByZombie[zombieModel] = damageByPlayer
	end

	damageByPlayer[attacker.UserId] = (damageByPlayer[attacker.UserId] or 0) + math.max(0, math.floor(damage))
	mission.zombieLastHitByZombie[zombieModel] = attacker.UserId
	zombieModel:SetAttribute("LastDamagerUserId", attacker.UserId)
end

function MissionService:_getZombieContributors(zombieModel)
	local mission = self._activeMission
	if not mission or not zombieModel then
		return {}
	end

	local damageByPlayer = mission.zombieDamageByZombie and mission.zombieDamageByZombie[zombieModel] or nil
	local contributors = {}
	local seen = {}

	if damageByPlayer then
		for userId, totalDamage in pairs(damageByPlayer) do
			if totalDamage > 0 then
				local player = Players:GetPlayerByUserId(userId)
				if player and player.Parent and not seen[userId] then
					seen[userId] = true
					table.insert(contributors, player)
				end
			end
		end
	end

	if #contributors == 0 then
		local fallbackUserId = mission.zombieLastHitByZombie and mission.zombieLastHitByZombie[zombieModel] or zombieModel:GetAttribute("LastDamagerUserId")
		local fallbackPlayer = fallbackUserId and Players:GetPlayerByUserId(tonumber(fallbackUserId) or 0) or nil
		if fallbackPlayer and fallbackPlayer.Parent then
			table.insert(contributors, fallbackPlayer)
		end
	end

	return contributors
end

function MissionService:_clearZombieDamageTracking(zombieModel)
	local mission = self._activeMission
	if not mission or not zombieModel then
		return
	end

	if mission.zombieDamageByZombie then
		mission.zombieDamageByZombie[zombieModel] = nil
	end
	if mission.zombieLastHitByZombie then
		mission.zombieLastHitByZombie[zombieModel] = nil
	end
end

function MissionService:_awardMissionExperience(player, rewardKey, fallbackAmount)
	if not self._skillTreeService or not player then
		return 0
	end

	local amount = fallbackAmount or 0
	if self._skillTreeConfig and self._skillTreeConfig.ExperienceRewards then
		amount = self._skillTreeConfig.ExperienceRewards[rewardKey] or amount
	end
	amount = math.max(0, math.floor(amount))
	if amount <= 0 then
		return 0
	end
	if self._subscriptionService then
		amount = self._subscriptionService:GetAdjustedExperienceAmount(player, amount)
	end

	self._skillTreeService:AwardExperience(player, amount, rewardKey)
	local runStats = self:_getRunStats(player)
	if runStats then
		runStats.xpGained += amount
		runStats.xpBreakdown[rewardKey] = (runStats.xpBreakdown[rewardKey] or 0) + amount
	end
	return amount
end

function MissionService:_emitProgressionUpdate(player)
	if not player or not self._remotes or not self._inventoryService then
		return
	end
	self._remotes:FireEventFor(player, self._remoteNames.Events.ProgressionUpdated, self._inventoryService:BuildProgressionPayload(player))
end

function MissionService:_getLootDropSourceConfig(sourceKey)
	local lootDrops = self._missionConfig.Mission and self._missionConfig.Mission.LootDrops or nil
	local sourceConfig = lootDrops and lootDrops[sourceKey] or nil
	return {
		Rolls = clampPositiveInteger(sourceConfig and sourceConfig.Rolls or 1, 1),
		PoolCap = clampPositiveInteger(sourceConfig and sourceConfig.PoolCap or 4, 4),
		MaxUnlocks = clampPositiveInteger(sourceConfig and sourceConfig.MaxUnlocks or 1, 1),
	}
end

function MissionService:_buildLootDropCandidates(player, sourceKey, chanceScale)
	local sourceConfig = self:_getLootDropSourceConfig(sourceKey)
	local activeEvent = self._tokenEconomy.getActiveSeasonalEvent and self._tokenEconomy.getActiveSeasonalEvent() or nil
	local candidates = {}
	local effectiveMultiplier = chanceScale or 1
	if self._gamePassService then
		effectiveMultiplier *= self._gamePassService:GetDropChanceMultiplier(player)
	end

	for _, entry in ipairs(self._tokenEconomy.getDroppableItems and self._tokenEconomy.getDroppableItems() or {}) do
		local category = entry.category
		local item = entry.item
		if item and not self._inventoryService:IsUnlocked(player, item.Id) then
			local chance = self._tokenEconomy.getDropChanceForItem(item, activeEvent, effectiveMultiplier)
			if chance > 0 then
				table.insert(candidates, {
					category = category,
					item = item,
					chance = chance,
				})
			end
		end
	end

	table.sort(candidates, function(a, b)
		return a.chance > b.chance
	end)

	while #candidates > sourceConfig.PoolCap do
		table.remove(candidates)
	end

	return candidates, activeEvent, sourceConfig
end

function MissionService:_pickWeightedLootDrop(candidates)
	local totalWeight = 0
	for _, candidate in ipairs(candidates) do
		totalWeight += candidate.chance
	end
	if totalWeight <= 0 then
		return nil, nil
	end

	local roll = math.random() * totalWeight
	local running = 0
	for index, candidate in ipairs(candidates) do
		running += candidate.chance
		if roll <= running then
			return index, candidate
		end
	end

	return #candidates, candidates[#candidates]
end

function MissionService:_awardLootDrops(player, sourceKey, chanceScale)
	if not player or not player.Parent or not self._inventoryService or not self._tokenEconomy then
		return {}
	end

	local candidates, activeEvent, sourceConfig = self:_buildLootDropCandidates(player, sourceKey, chanceScale)
	local unlocked = {}

	for _ = 1, sourceConfig.Rolls do
		if #unlocked >= sourceConfig.MaxUnlocks or #candidates == 0 then
			break
		end

		local selectedIndex, candidate = self:_pickWeightedLootDrop(candidates)
		if not candidate then
			break
		end

		table.remove(candidates, selectedIndex)
		if (math.random() * 100) <= candidate.chance then
			local item = candidate.item
			self._inventoryService:UnlockItem(player, item.Id)
			table.insert(unlocked, {
				category = candidate.category,
				itemId = item.Id,
				displayName = item.DisplayName or item.Id,
			})
		end
	end

	if #unlocked > 0 and self._remotes then
		self:_emitProgressionUpdate(player)
		local labels = {}
		for _, drop in ipairs(unlocked) do
			table.insert(labels, drop.displayName)
		end
		local eventSuffix = activeEvent and (" [" .. tostring(activeEvent.DisplayName or activeEvent.Id) .. "]") or ""
		self._remotes:FireEventFor(player, self._remoteNames.Events.Notification, {
			userId = player.UserId,
			message = ("Recovered gear%s: %s"):format(eventSuffix, table.concat(labels, ", ")),
		})
	end

	return unlocked
end

function MissionService:_getExtractionHoldDuration(party)
	local holdSeconds = self._missionConfig.Mission.ExtractionHoldSeconds
	if self._skillTreeService then
		holdSeconds = self._skillTreeService:GetExtractionHoldSeconds(party, holdSeconds)
	end
	if not self._subscriptionService then
		return holdSeconds
	end

	local bestHold = holdSeconds
	for _, player in ipairs(party or {}) do
		if player and player.Parent then
			bestHold = math.min(bestHold, self._subscriptionService:GetExtractionHoldSeconds(player, holdSeconds))
		end
	end

	return bestHold
end

function MissionService:_buildMissionPayload(player, status)
	local mission = self._activeMission
	local weaponState = player and self._weaponState[player.UserId] or nil
	local weaponDefinition = weaponState and weaponState.weaponId and self._inventoryService and self._inventoryService:GetWeaponDefinition(weaponState.weaponId) or nil
	local objective = self:_getMissionObjective()
	local objectiveHealth = objective and objective:GetAttribute("ObjectiveHealth") or self._missionConfig.Mission.ObjectiveMaxHealth
	local objectivePercent = math.floor((objectiveHealth / self._missionConfig.Mission.ObjectiveMaxHealth) * 100)
	return {
		stage = "Mission",
		status = status,
		missionPhase = mission and mission.phase or "Combat",
		scenarioName = mission and mission.scenario and mission.scenario.DisplayName or "Hold The Core",
		scenarioDescription = mission and mission.scenario and mission.scenario.Description or "",
		wave = mission and mission.wave or 0,
		totalWaves = self._missionConfig.Mission.WaveCount,
		objectiveHealthPercent = objectivePercent,
		weaponName = weaponDefinition and weaponDefinition.DisplayName or nil,
		weaponType = weaponDefinition and weaponDefinition.WeaponType or nil,
		currentAmmo = weaponState and weaponState.currentAmmo or nil,
		reserveAmmo = weaponState and weaponState.reserveAmmo or nil,
		reloading = weaponState and weaponState.reloading or false,
	}
end

function MissionService:_fireMissionState(players, status)
	if not self._remotes then
		return
	end

	for _, player in ipairs(players) do
		if player and player.Parent then
			self._remotes:FireEventFor(player, self._remoteNames.Events.DeployStateChanged, self:_buildMissionPayload(player, status))
		end
	end
end

function MissionService:_getCombatFeedbackWeaponId(player)
	local character = player and player.Character
	if character and character:FindFirstChild("MissionFists") then
		return "weapon_fists"
	end
	local state = player and self._weaponState[player.UserId] or nil
	if state and state.weaponId then
		return state.weaponId
	end
	return self._inventoryService:GetEquippedWeaponId(player)
end

function MissionService:_fireCombatFeedback(player, payload)
	if not self._remotes or not player or player.Parent ~= Players or type(payload) ~= "table" then
		return
	end
	self._remotes:FireEventFor(player, self._remoteNames.Events.CombatFeedback, payload)
end

function MissionService:_createRuntimeFolder()
	local mission = self:_getMissionModel()
	if not mission then
		return nil
	end

	local runtime = Instance.new("Folder")
	runtime.Name = "MissionRuntime"
	runtime.Parent = mission
	return runtime
end

function MissionService:_getActiveLayout()
	local mission = self._activeMission
	return mission and mission.layout or self._missionConfig.getLayout(1)
end

function MissionService:_getActiveModifier()
	local mission = self._activeMission
	return mission and mission.modifier or (self._missionConfig.getModifier and self._missionConfig.getModifier(1)) or nil
end

function MissionService:_getModifierRuntimeTraits()
	local modifier = self:_getActiveModifier()
	return {
		WaveSurgeDelayScale = tonumber(modifier and modifier.WaveSurgeDelayScale) or 1,
		HazardWindupScale = tonumber(modifier and modifier.HazardWindupScale) or 1,
		HazardActiveScale = tonumber(modifier and modifier.HazardActiveScale) or 1,
		ObjectivePressureInterval = clampPositiveInteger(modifier and modifier.ObjectivePressureInterval or 4, 4),
		ForceRunnerPressure = modifier and modifier.ForceRunnerPressure == true,
		ForceBrutePressure = modifier and modifier.ForceBrutePressure == true,
		BonusSupplyPickup = type(modifier and modifier.BonusSupplyPickup) == "string" and modifier.BonusSupplyPickup or nil,
	}
end

function MissionService:_getLayoutWorldPosition(offset: Vector3)
	local anchor = self:_getMissionAnchorCFrame()
	if not anchor then
		return offset
	end
	return (anchor * CFrame.new(offset)).Position
end

function MissionService:_spawnFrameStructure(parent, prefix, frame, anchor)
	if not frame then
		return
	end

	local frameFolder = Instance.new("Folder")
	frameFolder.Name = prefix
	frameFolder.Parent = parent

	local frameColor = Color3.fromRGB(32, 38, 46)
	local baseColor = Color3.fromRGB(52, 61, 71)
	local glowColor = frame.SignColor or Color3.fromRGB(184, 228, 255)

	local base = createRuntimePart(frameFolder, prefix .. "Base", frame.BaseSize, anchor * CFrame.new(frame.BaseOffset), baseColor, Enum.Material.DiamondPlate)
	base.CanQuery = false

	local backplate = createRuntimePart(frameFolder, prefix .. "Backplate", frame.BackplateSize, anchor * CFrame.new(frame.BackplateOffset), frameColor, Enum.Material.Metal)
	backplate.CanQuery = false

	local leftPillar = createRuntimePart(frameFolder, prefix .. "PillarLeft", frame.PillarSize, anchor * CFrame.new(-frame.PillarOffsetX, frame.BackplateOffset.Y, frame.PillarOffsetZ), frameColor, Enum.Material.Metal)
	leftPillar.CanQuery = false

	local rightPillar = createRuntimePart(frameFolder, prefix .. "PillarRight", frame.PillarSize, anchor * CFrame.new(frame.PillarOffsetX, frame.BackplateOffset.Y, frame.PillarOffsetZ), frameColor, Enum.Material.Metal)
	rightPillar.CanQuery = false

	local glow = createRuntimeGlow(frameFolder, prefix .. "Glow", frame.GlowSize * 0.82, anchor * CFrame.new(frame.GlowOffset), glowColor, 0.82)
	glow.CanQuery = false

	local labelPart, _ = self:_createWorldMarker(frameFolder, prefix .. "Sign", frame.SignText, glowColor, Vector2.new(144, 28), 14)
	labelPart.CFrame = anchor * CFrame.new(0, frame.BackplateOffset.Y + 2.6, frame.BackplateOffset.Z + 1.2)
end

function MissionService:_decorateMissionRuntime(runtime)
	local anchor = self:_getMissionAnchorCFrame()
	local layout = self:_getActiveLayout()
	if not anchor or not layout then
		return
	end

	local shell = Instance.new("Folder")
	shell.Name = "ArenaLayout"
	shell.Parent = runtime

	local floor = createRuntimePart(shell, "ArenaFloor", Vector3.new(150, 1.2, 170), anchor * CFrame.new(0, -0.75, -6), Color3.fromRGB(48, 54, 62), Enum.Material.DiamondPlate)
	floor.CanQuery = false
	local floorTrim = createRuntimePart(shell, "ArenaFloorTrim", Vector3.new(118, 0.18, 138), anchor * CFrame.new(0, -0.05, -6), Color3.fromRGB(72, 80, 92), Enum.Material.SmoothPlastic)
	floorTrim.CanCollide = false
	floorTrim.CanQuery = false
	floorTrim.Transparency = 0.18

	for _, decoration in ipairs(layout.DecorationPieces or {}) do
		createRuntimeDecoration(shell, decoration, anchor * CFrame.new(decoration.Offset))
	end

	self:_spawnFrameStructure(shell, "ObjectiveFrame", layout.ObjectiveFrame, anchor * CFrame.new(layout.ObjectiveOffset or Vector3.new(0, 5, 18)))
	self:_spawnFrameStructure(shell, "ExtractionFrame", layout.ExtractionFrame, anchor * CFrame.new(layout.ExtractionOffset or Vector3.new(0, -0.3, -26)))

	if layout.Id == "arena_breach_yard" then
		floor.Size = Vector3.new(164, 1.2, 184)
		floor.CFrame = anchor * CFrame.new(0, -0.75, -6)
		floorTrim.Size = Vector3.new(128, 0.18, 150)
		floorTrim.CFrame = anchor * CFrame.new(0, -0.05, -6)
	elseif layout.Id == "arena_service_tunnel" then
		floor.Size = Vector3.new(86, 1.2, 198)
		floor.CFrame = anchor * CFrame.new(0, -0.75, -12)
		floorTrim.Size = Vector3.new(58, 0.18, 172)
		floorTrim.CFrame = anchor * CFrame.new(0, -0.05, -12)

		for _, side in ipairs({ -1, 1 }) do
			local wall = createRuntimePart(shell, side < 0 and "TunnelWallLeft" or "TunnelWallRight", Vector3.new(2.6, 6.8, 186), anchor * CFrame.new(side * 40.6, 2.9, -12), Color3.fromRGB(48, 56, 68), Enum.Material.Metal)
			wall.CanQuery = false
			local topRail = createRuntimePart(shell, side < 0 and "TunnelTopRailLeft" or "TunnelTopRailRight", Vector3.new(3.4, 0.42, 178), anchor * CFrame.new(side * 39.8, 6.12, -12), Color3.fromRGB(74, 84, 98), Enum.Material.Metal)
			topRail.CanQuery = false
			local strip = createRuntimeGlow(shell, side < 0 and "TunnelStripLeft" or "TunnelStripRight", Vector3.new(0.14, 1.5, 142), anchor * CFrame.new(side * 39.2, 2.7, -10), Color3.fromRGB(132, 184, 232), 0.88)
			strip.CanQuery = false
			local curb = createRuntimePart(shell, side < 0 and "TunnelCurbLeft" or "TunnelCurbRight", Vector3.new(3.2, 0.48, 188), anchor * CFrame.new(side * 36.8, 0.24, -12), Color3.fromRGB(88, 98, 112), Enum.Material.Metal)
			curb.CanQuery = false
			for _, z in ipairs({ -54, -8, 38 }) do
				local inset = createRuntimePart(shell, ("TunnelInset_%d_%d"):format(side, z), Vector3.new(1.1, 2.8, 18), anchor * CFrame.new(side * 39.3, 1.7, z), Color3.fromRGB(58, 66, 78), Enum.Material.Metal)
				inset.CanQuery = false
			end
		end

		local bulkhead = createRuntimePart(shell, "TunnelBackBulkhead", Vector3.new(74, 7.2, 2.6), anchor * CFrame.new(0, 3.2, 84), Color3.fromRGB(42, 48, 56), Enum.Material.Metal)
		bulkhead.CanQuery = false
		local frame = createRuntimePart(shell, "TunnelFrontFrame", Vector3.new(72, 5.6, 1.2), anchor * CFrame.new(0, 2.9, -92), Color3.fromRGB(66, 74, 84), Enum.Material.Metal)
		frame.CanQuery = false
		local frameHeader = createRuntimePart(shell, "TunnelFrontHeader", Vector3.new(48, 0.44, 1.6), anchor * CFrame.new(0, 5.76, -92), Color3.fromRGB(98, 112, 132), Enum.Material.Metal)
		frameHeader.CanQuery = false
		for _, x in ipairs({ -18, 18 }) do
			local pipe = createRuntimePart(shell, ("TunnelPipe_%d"):format(x), Vector3.new(0.72, 0.72, 176), anchor * CFrame.new(x, 6.7, -12), Color3.fromRGB(96, 108, 122), Enum.Material.Metal)
			pipe.Shape = Enum.PartType.Cylinder
			pipe.Orientation = Vector3.new(0, 0, 90)
			pipe.CanQuery = false
			local pipeGlow = createRuntimeGlow(shell, ("TunnelPipeGlow_%d"):format(x), Vector3.new(0.18, 0.18, 148), anchor * CFrame.new(x, 6.32, -12), Color3.fromRGB(126, 188, 244), 0.62)
			pipeGlow.CanQuery = false
		end
		for _, z in ipairs({ -54, -10, 34 }) do
			local truss = createRuntimePart(shell, ("TunnelTruss_%d"):format(z), Vector3.new(54, 0.3, 0.9), anchor * CFrame.new(0, 6.34, z), Color3.fromRGB(86, 96, 112), Enum.Material.Metal)
			truss.CanQuery = false
		end

		for _, z in ipairs({ -34, 12 }) do
			for _, x in ipairs({ -15, 15 }) do
				local cover = createRuntimePart(shell, ("TunnelCover_%d_%d"):format(x, z), Vector3.new(6.4, 2.4, 2.8), anchor * CFrame.new(x, 1.2, z), Color3.fromRGB(92, 102, 116), Enum.Material.Metal)
				cover.CanQuery = false
				local cap = createRuntimeGlow(shell, ("TunnelCoverCap_%d_%d"):format(x, z), Vector3.new(4.8, 0.08, 0.54), anchor * CFrame.new(x, 2.46, z), Color3.fromRGB(146, 192, 236), 0.52)
				cap.CanQuery = false
			end
		end

		createRuntimeGlow(shell, "TunnelLaneGlow", Vector3.new(5.2, 0.08, 104), anchor * CFrame.new(0, 0.06, -8), Color3.fromRGB(136, 170, 206), 0.9)
		createRuntimeGlow(shell, "TunnelLaneGlowLeft", Vector3.new(2.2, 0.06, 96), anchor * CFrame.new(-14.2, 0.04, -8), Color3.fromRGB(196, 132, 94), 0.95)
		createRuntimeGlow(shell, "TunnelLaneGlowRight", Vector3.new(2.2, 0.06, 96), anchor * CFrame.new(14.2, 0.04, -8), Color3.fromRGB(196, 132, 94), 0.95)
	elseif layout.Id == "arena_crossroads" then
		floor.Size = Vector3.new(176, 1.2, 176)
		floor.CFrame = anchor * CFrame.new(0, -0.75, 0)
		floorTrim.Size = Vector3.new(138, 0.18, 138)
		floorTrim.CFrame = anchor * CFrame.new(0, -0.05, 0)
	elseif layout.Id == "arena_reactor_fields" then
		floor.Size = Vector3.new(168, 1.2, 188)
		floor.CFrame = anchor * CFrame.new(0, -0.75, -2)
		floorTrim.Size = Vector3.new(134, 0.18, 150)
		floorTrim.CFrame = anchor * CFrame.new(0, -0.05, -2)
	else
		for _, data in ipairs({
			{ "YardNorthBarrierWest", Vector3.new(34, 5.5, 3), Vector3.new(-28, 2.2, 49) },
			{ "YardNorthBarrierEast", Vector3.new(34, 5.5, 3), Vector3.new(28, 2.2, 49) },
			{ "YardSouthBarrierWest", Vector3.new(34, 5.5, 3), Vector3.new(-28, 2.2, -57) },
			{ "YardSouthBarrierEast", Vector3.new(34, 5.5, 3), Vector3.new(28, 2.2, -57) },
			{ "YardWestBarrierNorth", Vector3.new(3, 5.5, 34), Vector3.new(-50, 2.2, 22) },
			{ "YardWestBarrierSouth", Vector3.new(3, 5.5, 34), Vector3.new(-50, 2.2, -30) },
			{ "YardEastBarrierNorth", Vector3.new(3, 5.5, 34), Vector3.new(50, 2.2, 22) },
			{ "YardEastBarrierSouth", Vector3.new(3, 5.5, 34), Vector3.new(50, 2.2, -30) },
		}) do
			local barrier = createRuntimePart(shell, data[1], data[2], anchor * CFrame.new(data[3]), Color3.fromRGB(30, 34, 40), Enum.Material.Metal)
			barrier.CanQuery = false
		end

		for _, gatePosition in ipairs({
			Vector3.new(0, 2.3, 52),
			Vector3.new(0, 2.3, -60),
			Vector3.new(-53, 2.3, -4),
			Vector3.new(53, 2.3, -4),
		}) do
			local gateGlow = createRuntimeGlow(shell, "YardGateGlow", Vector3.new(10, 4.6, 0.18), anchor * CFrame.new(gatePosition), Color3.fromRGB(124, 164, 206), 0.72)
			gateGlow.CanQuery = false
		end

		for _, info in ipairs({
			{ "NorthWest", Vector3.new(-20, 0, 25), Vector3.new(14, 2.8, 3.2) },
			{ "NorthEast", Vector3.new(20, 0, 25), Vector3.new(14, 2.8, 3.2) },
			{ "SouthWest", Vector3.new(-18, 0, -6), Vector3.new(12, 2.8, 3.2) },
			{ "SouthEast", Vector3.new(18, 0, -6), Vector3.new(12, 2.8, 3.2) },
			{ "West", Vector3.new(-28, 0, 8), Vector3.new(3.2, 2.8, 14) },
			{ "East", Vector3.new(28, 0, 8), Vector3.new(3.2, 2.8, 14) },
		}) do
			local barricade = createRuntimePart(shell, "YardBarricade" .. info[1], info[3], anchor * CFrame.new(info[2].X, 1.9, info[2].Z), Color3.fromRGB(92, 82, 68), Enum.Material.WoodPlanks)
			barricade.CanQuery = false
		end

		createRuntimeGlow(shell, "YardCentralLaneGlow", Vector3.new(20, 0.08, 62), anchor * CFrame.new(0, 0.05, -4), Color3.fromRGB(108, 138, 170), 0.9)
	end
end

function MissionService:_applyHazardDamage(mission, zone, damage, color)
	local now = os.clock()
	mission.hazardCooldowns = mission.hazardCooldowns or {}
	for _, player in ipairs(self:_getLivePartyMembers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and rootPart then
			local localPoint = zone.CFrame:PointToObjectSpace(rootPart.Position)
			local half = zone.Size * 0.5
			local inside = math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= 6 and math.abs(localPoint.Z) <= half.Z
			if inside and not self:_isCharacterDashing(character) and not self:_isCharacterDowned(character) and not self:_isSpawnProtected(player, character) then
				local key = ("%d_%s"):format(player.UserId, zone.Name)
				if not mission.hazardCooldowns[key] or now - mission.hazardCooldowns[key] >= 1 then
					mission.hazardCooldowns[key] = now
					humanoid:TakeDamage(damage)
					self:_emitPlayerHitEffect(character, color)
				end
			end
		end
	end
end

function MissionService:_spawnHazardZones(runtime)
	local mission = self._activeMission
	local layout = self:_getActiveLayout()
	local modifier = self:_getActiveModifier()
	local modifierTraits = self:_getModifierRuntimeTraits()
	if not mission or not layout or not layout.HazardZones then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "Hazards"
	folder.Parent = runtime

	for _, hazard in ipairs(layout.HazardZones) do
		local worldPosition = self:_getLayoutWorldPosition(hazard.Offset)
		local isSteam = hazard.HazardType == "Steam"
		local baseColor = isSteam and Color3.fromRGB(154, 214, 255) or Color3.fromRGB(255, 142, 92)
		local activeColor = isSteam and Color3.fromRGB(210, 244, 255) or Color3.fromRGB(255, 194, 124)

		local zone = createRuntimeGlow(folder, hazard.Id, hazard.Size, CFrame.new(worldPosition), baseColor, 0.72)
		zone.Name = hazard.Id
		zone.Material = Enum.Material.Neon

		local marker, _ = self:_createWorldMarker(folder, hazard.Id .. "Marker", hazard.DisplayName, activeColor, Vector2.new(130, 30), 14)
		marker.CFrame = CFrame.new(worldPosition + Vector3.new(0, 4.5, 0))

		local emitterPart = createRuntimePart(folder, hazard.Id .. "Emitter", Vector3.new(2.4, isSteam and 6 or 3.2, 2.4), CFrame.new(worldPosition + Vector3.new(0, (isSteam and 3 or 1.6), 0)), baseColor, isSteam and Enum.Material.ForceField or Enum.Material.Neon)
		emitterPart.CanCollide = false
		emitterPart.CanQuery = false
		emitterPart.Transparency = 0.86

		task.spawn(function()
			while self._activeMission == mission and zone.Parent do
				local windup = (isSteam and 2.6 or 3.2) * modifierTraits.HazardWindupScale
				local activeDuration = (isSteam and 1.6 or 2) * modifierTraits.HazardActiveScale

				zone.Transparency = 0.78
				zone.Color = baseColor
				emitterPart.Transparency = 0.9
				task.wait(windup)

				local startedAt = os.clock()
				while self._activeMission == mission and zone.Parent and os.clock() - startedAt < activeDuration do
					local pulse = math.abs(math.sin((os.clock() - startedAt) * 10))
					zone.Transparency = 0.2 + (pulse * 0.12)
					zone.Color = activeColor
					emitterPart.Transparency = isSteam and 0.45 or 0.3
					emitterPart.Color = activeColor
					local scaledHazardDamage = math.max(1, math.floor((hazard.Damage or 6) * (modifier and modifier.HazardDamageScale or 1)))
					self:_applyHazardDamage(mission, zone, scaledHazardDamage, activeColor)
					task.wait(0.2)
				end
			end
		end)
	end
end

function MissionService:_getLivePartyMembers()
	local party = {}
	local activeMission = self._activeMission
	if not activeMission then
		return party
	end

	for _, player in ipairs(activeMission.party) do
		if player and player.Parent == Players then
			table.insert(party, player)
		end
	end
	return party
end

function MissionService:_findNearestZombie(origin, maxRange, minDot)
	local activeMission = self._activeMission
	if not activeMission or not activeMission.zombiesFolder then
		return nil
	end

	local nearestModel = nil
	local nearestDistance = maxRange
	local requiredDot = minDot or 0.3

	for _, model in ipairs(activeMission.zombiesFolder:GetChildren()) do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local rootPart = model.PrimaryPart
		if humanoid and humanoid.Health > 0 and rootPart then
			local distance = (rootPart.Position - origin.Position).Magnitude
			if distance <= nearestDistance then
				local direction = (rootPart.Position - origin.Position).Unit
				if origin.CFrame.LookVector:Dot(direction) >= requiredDot then
					nearestDistance = distance
					nearestModel = model
				end
			end
		end
	end

	return nearestModel
end

function MissionService:_damageZombie(zombieModel, damage, attacker)
	local humanoid = zombieModel and zombieModel:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local healthBefore = humanoid.Health
	local weakPointHit = zombieModel:GetAttribute("Boss") and zombieModel:GetAttribute("WeakPointActive")

	if weakPointHit then
		damage = math.floor(damage * self._missionConfig.Mission.BossWeakPointDamageScale)
	end

	if attacker and self._skillTreeService then
		damage = math.max(1, math.floor(damage * self._skillTreeService:GetWeaponDamageMultiplier(attacker)))
		if zombieModel:GetAttribute("Boss") then
			damage = math.max(1, math.floor(damage * self._skillTreeService:GetBossDamageMultiplier(attacker)))
		end
	end
	self:_recordZombieDamage(zombieModel, attacker, damage)

	if attacker then
		zombieModel:SetAttribute("LastDamagerUserId", attacker.UserId)
		zombieModel:SetAttribute("LastDamagerAt", os.clock())
	end

	local rootPart = zombieModel.PrimaryPart
	if rootPart and attacker and attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart") then
		local impulseDirection = (rootPart.Position - attacker.Character.HumanoidRootPart.Position).Unit
		rootPart.AssemblyLinearVelocity = impulseDirection * 13 + Vector3.new(0, 8, 0)
	end

	local flash = zombieModel:FindFirstChild("DamageHighlight")
	if not flash then
		flash = Instance.new("Highlight")
		flash.Name = "DamageHighlight"
		flash.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		flash.Parent = zombieModel
	end
	flash.FillColor = Color3.fromRGB(255, 120, 120)
	flash.OutlineColor = Color3.fromRGB(255, 240, 240)
	flash.FillTransparency = 0.15
	flash.OutlineTransparency = 0
	task.delay(0.12, function()
		if flash and flash.Parent then
			flash.FillTransparency = 1
			flash.OutlineTransparency = 1
		end
	end)

	humanoid:TakeDamage(damage)
	if humanoid and humanoid.Parent and humanoid.Health > 0 then
		local originalWalkSpeed = humanoid.WalkSpeed
		local staggerSpeed = math.max(4, originalWalkSpeed * 0.72)
		humanoid.WalkSpeed = math.min(humanoid.WalkSpeed, staggerSpeed)
		task.delay(zombieModel:GetAttribute("Brute") and 0.18 or 0.12, function()
			if humanoid and humanoid.Parent and humanoid.Health > 0 then
				humanoid.WalkSpeed = math.max(humanoid.WalkSpeed, originalWalkSpeed)
			end
		end)
	end
	if attacker then
		attacker:SetAttribute("LastHitZombie", zombieModel.Name)
		self:_fireCombatFeedback(attacker, {
			kind = "hit",
			weaponId = self:_getCombatFeedbackWeaponId(attacker),
			damage = damage,
			critical = weakPointHit == true,
			kill = healthBefore - damage <= 0,
			boss = zombieModel:GetAttribute("Boss") == true,
			hitPosition = rootPart and rootPart.Position or nil,
		})
	end
end

function MissionService:_setBossWeakPointState(zombie, active)
	if not zombie or not zombie.Parent then
		return
	end

	zombie:SetAttribute("WeakPointActive", active)

	local aura = zombie:FindFirstChild("BossAura")
	if aura and aura:IsA("Highlight") then
		local enraged = zombie:GetAttribute("Enraged") == true
		aura.FillColor = active and Color3.fromRGB(255, 214, 112) or (enraged and Color3.fromRGB(255, 136, 96) or Color3.fromRGB(255, 88, 88))
		aura.OutlineColor = active and Color3.fromRGB(255, 248, 214) or (enraged and Color3.fromRGB(255, 224, 188) or Color3.fromRGB(255, 228, 196))
		aura.FillTransparency = active and 0.24 or 0.42
	end

	local marker = zombie:FindFirstChild("BossMarker")
	local label = marker and marker:FindFirstChildOfClass("TextLabel")
	if label then
		local enraged = zombie:GetAttribute("Enraged") == true
		label.Text = active and "WEAK POINT OPEN" or (enraged and "SIEGE TYRANT RAGING" or "SIEGE TYRANT")
		label.TextColor3 = active and Color3.fromRGB(255, 242, 152) or (enraged and Color3.fromRGB(255, 180, 160) or Color3.fromRGB(255, 212, 188))
	end
end

function MissionService:_setBossEnrageState(zombie, active)
	if not zombie or not zombie.Parent then
		return
	end

	zombie:SetAttribute("Enraged", active)

	local aura = zombie:FindFirstChild("BossAura")
	if aura and aura:IsA("Highlight") then
		aura.FillColor = active and Color3.fromRGB(255, 136, 96) or (zombie:GetAttribute("WeakPointActive") and Color3.fromRGB(255, 214, 112) or Color3.fromRGB(255, 88, 88))
		aura.OutlineColor = active and Color3.fromRGB(255, 224, 188) or (zombie:GetAttribute("WeakPointActive") and Color3.fromRGB(255, 248, 214) or Color3.fromRGB(255, 228, 196))
		aura.FillTransparency = active and 0.28 or (zombie:GetAttribute("WeakPointActive") and 0.24 or 0.42)
	end

	local marker = zombie:FindFirstChild("BossMarker")
	local label = marker and marker:FindFirstChildOfClass("TextLabel")
	if label and zombie:GetAttribute("WeakPointActive") ~= true then
		label.Text = active and "SIEGE TYRANT RAGING" or "SIEGE TYRANT"
		label.TextColor3 = active and Color3.fromRGB(255, 180, 160) or Color3.fromRGB(255, 212, 188)
	end
end

function MissionService:_openBossWeakPoint(zombie)
	local mission = self._activeMission
	if not mission or not zombie or not zombie.Parent then
		return
	end

	self:_setBossWeakPointState(zombie, true)
	self:_notifyParty(mission.party, "Weak point exposed. Focus fire on the Siege Tyrant.")
	local weakPulse = self:_emitPulse(zombie.PrimaryPart.CFrame * CFrame.new(0, 3.8, 0), Vector3.new(5.4, 5.4, 5.4), Color3.fromRGB(255, 226, 118), 0.24, 0.32)
	if weakPulse then
		weakPulse.Shape = Enum.PartType.Ball
		weakPulse.Material = Enum.Material.ForceField
	end

	task.delay(self._missionConfig.Mission.BossWeakPointDuration, function()
		if self._activeMission == mission and zombie and zombie.Parent then
			self:_setBossWeakPointState(zombie, false)
		end
	end)
end

function MissionService:_resolveRaycastZombie(result)
	if not result or not result.Instance then
		return nil
	end

	local candidate = result.Instance:FindFirstAncestorOfClass("Model")
	if candidate and self._activeMission and candidate.Parent == self._activeMission.zombiesFolder then
		return candidate
	end
	return nil
end

function MissionService:_emitTracer(originPosition, hitPosition, color)
	local distance = (hitPosition - originPosition).Magnitude
	if distance <= 0 then
		return
	end

	local tracer = Instance.new("Part")
	tracer.Name = "BulletTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = color
	tracer.Size = Vector3.new(0.18, 0.18, distance)
	tracer.CFrame = CFrame.lookAt(originPosition:Lerp(hitPosition, 0.5), hitPosition)
	tracer.Parent = Workspace
	Debris:AddItem(tracer, 0.08)
end

function MissionService:_emitPulse(cframe, size, color, transparency, lifetime)
	local pulse = Instance.new("Part")
	pulse.Name = "CombatPulse"
	pulse.Anchored = true
	pulse.CanCollide = false
	pulse.CanQuery = false
	pulse.Material = Enum.Material.Neon
	pulse.Color = color
	pulse.Transparency = transparency
	pulse.Size = size
	pulse.CFrame = cframe
	pulse.Parent = Workspace
	Debris:AddItem(pulse, lifetime or 0.12)
	return pulse
end

function MissionService:_emitMuzzleFlash(handle, color, weaponType, weapon)
	if not handle then
		return
	end

	local offset = weapon and weapon.MuzzleOffset
	if not offset then
		offset = weaponType == "Melee" and Vector3.new(0, 0, -2) or Vector3.new(0, 0, -2.4)
	end
	local size = weapon and weapon.MuzzleFlashSize
	if not size then
		size = weaponType == "Spread" and Vector3.new(1.6, 1.6, 1.6) or Vector3.new(1.1, 1.1, 1.1)
	end
	local flash = self:_emitPulse(handle.CFrame * CFrame.new(offset), size, color, 0.14, 0.07)
	if flash then
		flash.Shape = Enum.PartType.Ball
	end
	local streak = self:_emitPulse(handle.CFrame * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.16, size.Y * 0.9, size.Z * 1.4), color:Lerp(Color3.fromRGB(255, 236, 188), 0.35), 0.26, 0.06)
	if streak then
		streak.Material = Enum.Material.Neon
	end
end

function MissionService:_emitImpactEffect(position, color, hitZombie)
	local impactColor = hitZombie and color:Lerp(Color3.fromRGB(255, 236, 236), 0.45) or color:Lerp(Color3.fromRGB(255, 214, 176), 0.25)
	local spark = self:_emitPulse(CFrame.new(position), Vector3.new(0.7, 0.7, 0.7), impactColor, 0.25, 0.1)
	if spark then
		spark.Shape = Enum.PartType.Ball
	end

	local streak = self:_emitPulse(CFrame.new(position), Vector3.new(0.2, 1.4, 0.2), impactColor, 0.4, 0.12)
	if streak then
		streak.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(25))
	end
end

function MissionService:_emitReloadEffect(handle, color)
	if not handle then
		return
	end

	local pulse = self:_emitPulse(handle.CFrame, Vector3.new(1.2, 3.6, 1.2), color, 0.76, 0.14)
	if pulse then
		pulse.Material = Enum.Material.ForceField
	end
	local ring = self:_emitPulse(handle.CFrame, Vector3.new(1.8, 0.18, 1.8), color:Lerp(Color3.fromRGB(255, 248, 214), 0.2), 0.62, 0.16)
	if ring then
		ring.Material = Enum.Material.Neon
	end
end

function MissionService:_kickWeaponVisual(handle, weapon)
	if not handle or not weapon then
		return
	end

	local originalCFrame = handle.CFrame
	local recoilDistance = weapon.RecoilDistance or (weapon.WeaponType == "Spread" and 0.22 or 0.1)
	local recoilTwist = math.rad(weapon.RecoilTwist or 6)
	local kickCFrame = originalCFrame * CFrame.new(0, 0, recoilDistance) * CFrame.Angles(-recoilTwist, 0, 0)
	handle.CFrame = kickCFrame

	local returnDelay = weapon.RecoilReturnTime or 0.08
	task.delay(returnDelay, function()
		if handle and handle.Parent then
			handle.CFrame = originalCFrame
		end
	end)
end

function MissionService:_pumpShotgunVisual(tool, handle, weapon)
	if not tool or not handle or not weapon or weapon.ModelStyle ~= "Shotgun" then
		return
	end

	local pump = tool:FindFirstChild("Pump")
	if not pump or not pump:IsA("BasePart") then
		return
	end

	local original = pump.CFrame
	local pulled = handle.CFrame * CFrame.new(0, 0.1, -0.95)
	pump.CFrame = pulled
	task.delay(weapon.PumpDelay or 0.18, function()
		if pump and pump.Parent then
			pump.CFrame = original
		end
	end)
end

function MissionService:_attachWeaponPart(tool, handle, name, size, offset, color, material, shape, transparency)
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
	part.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
	return part
end

function MissionService:_buildWeaponVisual(tool, handle, weapon)
	local accentColor = weapon.AccentColor or weapon.HandleColor:Lerp(Color3.fromRGB(255, 255, 255), 0.25)
	local style = weapon.ModelStyle or weapon.WeaponType

	if style == "Fists" then
		handle.Transparency = 1
		self:_attachWeaponPart(tool, handle, "RightFist", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 0, 0), weapon.HandleColor, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		self:_attachWeaponPart(tool, handle, "KnucklePlate", Vector3.new(1.1, 0.35, 0.55), CFrame.new(0, 0, -0.45), accentColor, Enum.Material.Metal)
		return
	end

	if style == "Blade" then
		self:_attachWeaponPart(tool, handle, "Blade", Vector3.new(0.28, 3.8, 0.8), CFrame.new(0, 1.9, 0), accentColor, Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Guard", Vector3.new(1.1, 0.2, 0.35), CFrame.new(0, 0.25, 0), weapon.HandleColor, Enum.Material.SmoothPlastic)
		return
	end

	if style == "Crowbar" then
		self:_attachWeaponPart(tool, handle, "CrowbarHook", Vector3.new(0.35, 0.35, 1.2), CFrame.new(0, 1.55, -0.2) * CFrame.Angles(math.rad(28), 0, 0), accentColor, Enum.Material.Metal)
		return
	end

	if style == "Axe" then
		self:_attachWeaponPart(tool, handle, "AxeHead", Vector3.new(1.5, 0.9, 0.28), CFrame.new(0.48, 1.3, 0), accentColor, Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "AxeBack", Vector3.new(0.42, 0.55, 0.24), CFrame.new(-0.42, 1.22, 0), accentColor, Enum.Material.Metal)
		return
	end

	if style == "Pistol" then
		self:_attachWeaponPart(tool, handle, "Frame", Vector3.new(0.56, 0.4, 1.34), CFrame.new(0, 0.16, -0.04), weapon.HandleColor, Enum.Material.SmoothPlastic)
		self:_attachWeaponPart(tool, handle, "Slide", Vector3.new(0.7, 0.24, 1.54), CFrame.new(0, 0.5, -0.14), accentColor, Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "SlideCap", Vector3.new(0.48, 0.06, 1.08), CFrame.new(0, 0.66, -0.12), Color3.fromRGB(84, 94, 108), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "DustTop", Vector3.new(0.26, 0.05, 0.86), CFrame.new(0, 0.68, 0.08), Color3.fromRGB(112, 120, 134), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Barrel", Vector3.new(0.14, 0.14, 1.08), CFrame.new(0, 0.34, -1.18), accentColor, Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "MuzzleBrake", Vector3.new(0.2, 0.2, 0.16), CFrame.new(0, 0.34, -1.78), Color3.fromRGB(92, 98, 110), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "TriggerGuard", Vector3.new(0.32, 0.16, 0.3), CFrame.new(0, -0.1, -0.22), Color3.fromRGB(62, 68, 80), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Trigger", Vector3.new(0.05, 0.18, 0.08), CFrame.new(0, -0.04, -0.12), Color3.fromRGB(38, 42, 50), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "MagWell", Vector3.new(0.32, 0.16, 0.26), CFrame.new(0, -0.18, 0.12), Color3.fromRGB(54, 60, 70), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "GripPlateLeft", Vector3.new(0.08, 0.72, 0.56), CFrame.new(-0.21, -0.2, 0.08), accentColor:Lerp(Color3.fromRGB(255, 255, 255), 0.1), Enum.Material.SmoothPlastic)
		self:_attachWeaponPart(tool, handle, "GripPlateRight", Vector3.new(0.08, 0.72, 0.56), CFrame.new(0.21, -0.2, 0.08), accentColor:Lerp(Color3.fromRGB(255, 255, 255), 0.1), Enum.Material.SmoothPlastic)
		self:_attachWeaponPart(tool, handle, "Ejector", Vector3.new(0.06, 0.08, 0.22), CFrame.new(0.26, 0.48, -0.18), Color3.fromRGB(198, 206, 214), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "FrontSight", Vector3.new(0.08, 0.12, 0.08), CFrame.new(0, 0.68, -0.9), Color3.fromRGB(236, 242, 250), Enum.Material.Neon)
		self:_attachWeaponPart(tool, handle, "RearSight", Vector3.new(0.14, 0.08, 0.1), CFrame.new(0, 0.66, 0.26), Color3.fromRGB(66, 74, 86), Enum.Material.Metal)
		return
	end

	if style == "Carbine" then
		self:_attachWeaponPart(tool, handle, "LowerReceiver", Vector3.new(0.68, 0.4, 1.08), CFrame.new(0, 0.16, 0.2), weapon.HandleColor, Enum.Material.SmoothPlastic)
		self:_attachWeaponPart(tool, handle, "UpperReceiver", Vector3.new(0.78, 0.24, 1.26), CFrame.new(0, 0.54, -0.06), accentColor, Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "DustCover", Vector3.new(0.42, 0.1, 0.58), CFrame.new(0.18, 0.46, -0.02), Color3.fromRGB(72, 80, 92), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Barrel", Vector3.new(0.14, 0.14, 2.56), CFrame.new(0, 0.32, -2.48), Color3.fromRGB(72, 80, 92), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "MuzzleDevice", Vector3.new(0.2, 0.2, 0.24), CFrame.new(0, 0.32, -3.82), Color3.fromRGB(108, 116, 126), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "StockTube", Vector3.new(0.18, 0.18, 1.24), CFrame.new(0, 0.28, 1.46), Color3.fromRGB(78, 86, 96), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Stock", Vector3.new(0.42, 0.64, 1.16), CFrame.new(0, 0.08, 1.98), weapon.HandleColor, Enum.Material.SmoothPlastic)
		self:_attachWeaponPart(tool, handle, "ButtPad", Vector3.new(0.44, 0.58, 0.12), CFrame.new(0, 0.08, 2.58), Color3.fromRGB(36, 40, 48), Enum.Material.Rubber)
		self:_attachWeaponPart(tool, handle, "Magazine", Vector3.new(0.26, 0.86, 0.38), CFrame.new(0, -0.58, -0.12) * CFrame.Angles(math.rad(14), 0, 0), weapon.HandleColor, Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "MagWell", Vector3.new(0.34, 0.18, 0.3), CFrame.new(0, -0.2, 0.08), Color3.fromRGB(54, 62, 74), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "TopRail", Vector3.new(0.24, 0.05, 1.66), CFrame.new(0, 0.72, -0.08), Color3.fromRGB(78, 88, 102), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "RearSight", Vector3.new(0.16, 0.14, 0.14), CFrame.new(0, 0.8, 0.52), Color3.fromRGB(76, 86, 98), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "FrontSight", Vector3.new(0.08, 0.26, 0.08), CFrame.new(0, 0.76, -2.2), Color3.fromRGB(228, 238, 248), Enum.Material.Neon)
		self:_attachWeaponPart(tool, handle, "Handguard", Vector3.new(0.4, 0.3, 1.74), CFrame.new(0, 0.18, -1.68), weapon.HandleColor, Enum.Material.SmoothPlastic)
		self:_attachWeaponPart(tool, handle, "HandguardTop", Vector3.new(0.28, 0.06, 1.42), CFrame.new(0, 0.36, -1.68), Color3.fromRGB(84, 94, 106), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "SideRailLeft", Vector3.new(0.05, 0.16, 1.04), CFrame.new(-0.22, 0.18, -1.68), Color3.fromRGB(70, 78, 90), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "SideRailRight", Vector3.new(0.05, 0.16, 1.04), CFrame.new(0.22, 0.18, -1.68), Color3.fromRGB(70, 78, 90), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Foregrip", Vector3.new(0.12, 0.52, 0.14), CFrame.new(0, -0.04, -1.44), Color3.fromRGB(58, 66, 78), Enum.Material.Metal)
		return
	end

	if style == "SMG" then
		self:_attachWeaponPart(tool, handle, "Receiver", Vector3.new(0.68, 0.36, 1.38), CFrame.new(0, 0.36, -0.04), accentColor, Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "DustCover", Vector3.new(0.56, 0.1, 1), CFrame.new(0, 0.58, -0.02), Color3.fromRGB(80, 88, 100), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "ChargingTube", Vector3.new(0.1, 0.1, 1.08), CFrame.new(0, 0.5, 0.2), Color3.fromRGB(68, 74, 84), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Barrel", Vector3.new(0.14, 0.14, 1.34), CFrame.new(0, 0.24, -1.68), Color3.fromRGB(70, 78, 90), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Muzzle", Vector3.new(0.2, 0.2, 0.16), CFrame.new(0, 0.24, -2.44), Color3.fromRGB(110, 118, 130), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Magazine", Vector3.new(0.24, 1.02, 0.34), CFrame.new(0, -0.7, -0.02), weapon.HandleColor, Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "MagWell", Vector3.new(0.28, 0.16, 0.22), CFrame.new(0, -0.18, 0.12), Color3.fromRGB(58, 66, 74), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "StockArm", Vector3.new(0.12, 0.12, 1), CFrame.new(0, 0.38, 1.02), Color3.fromRGB(78, 86, 96), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "StockPad", Vector3.new(0.34, 0.3, 0.18), CFrame.new(0, 0.38, 1.54), weapon.HandleColor, Enum.Material.SmoothPlastic)
		self:_attachWeaponPart(tool, handle, "TopRail", Vector3.new(0.2, 0.05, 0.94), CFrame.new(0, 0.66, -0.02), Color3.fromRGB(76, 84, 98), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "RearSight", Vector3.new(0.14, 0.1, 0.12), CFrame.new(0, 0.72, 0.28), Color3.fromRGB(76, 84, 98), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "FrontSight", Vector3.new(0.06, 0.18, 0.06), CFrame.new(0, 0.64, -1.36), Color3.fromRGB(230, 236, 246), Enum.Material.Neon)
		self:_attachWeaponPart(tool, handle, "Foregrip", Vector3.new(0.12, 0.4, 0.14), CFrame.new(0, -0.02, -0.72), weapon.HandleColor, Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "SideShroudLeft", Vector3.new(0.05, 0.18, 0.88), CFrame.new(-0.2, 0.18, -0.84), Color3.fromRGB(66, 74, 86), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "SideShroudRight", Vector3.new(0.05, 0.18, 0.88), CFrame.new(0.2, 0.18, -0.84), Color3.fromRGB(66, 74, 86), Enum.Material.Metal)
		return
	end

	if style == "Shotgun" then
		self:_attachWeaponPart(tool, handle, "Receiver", Vector3.new(0.8, 0.4, 1.54), CFrame.new(0, 0.38, -0.08), accentColor, Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "EjectionPort", Vector3.new(0.06, 0.12, 0.34), CFrame.new(0.28, 0.42, -0.18), Color3.fromRGB(198, 206, 214), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Barrel", Vector3.new(0.16, 0.16, 2.94), CFrame.new(0, 0.3, -2.58), Color3.fromRGB(82, 70, 58), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Tube", Vector3.new(0.12, 0.12, 2.38), CFrame.new(0, 0.04, -2.12), Color3.fromRGB(108, 94, 76), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Pump", Vector3.new(0.42, 0.3, 1.02), CFrame.new(0, 0.08, -1.52), weapon.HandleColor, Enum.Material.WoodPlanks)
		self:_attachWeaponPart(tool, handle, "PumpRailLeft", Vector3.new(0.04, 0.16, 0.82), CFrame.new(-0.18, 0.08, -1.52), Color3.fromRGB(82, 70, 58), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "PumpRailRight", Vector3.new(0.04, 0.16, 0.82), CFrame.new(0.18, 0.08, -1.52), Color3.fromRGB(82, 70, 58), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "HeatShield", Vector3.new(0.36, 0.1, 1.34), CFrame.new(0, 0.48, -1.76), Color3.fromRGB(76, 64, 54), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Stock", Vector3.new(0.5, 0.62, 1.28), CFrame.new(0, 0.02, 1.58), weapon.HandleColor, Enum.Material.WoodPlanks)
		self:_attachWeaponPart(tool, handle, "StockComb", Vector3.new(0.24, 0.14, 0.68), CFrame.new(0, 0.34, 1.22), Color3.fromRGB(120, 94, 72), Enum.Material.WoodPlanks)
		self:_attachWeaponPart(tool, handle, "ButtPad", Vector3.new(0.42, 0.54, 0.12), CFrame.new(0, 0.02, 2.28), Color3.fromRGB(40, 34, 30), Enum.Material.Rubber)
		self:_attachWeaponPart(tool, handle, "FrontBead", Vector3.new(0.06, 0.12, 0.06), CFrame.new(0, 0.54, -3.9), Color3.fromRGB(246, 226, 168), Enum.Material.Neon)
		self:_attachWeaponPart(tool, handle, "ReceiverRail", Vector3.new(0.2, 0.05, 0.76), CFrame.new(0, 0.62, -0.06), Color3.fromRGB(74, 64, 54), Enum.Material.Metal)
	end
end

function MissionService:_getMissionTool(player, toolName)
	local backpack = player and player:FindFirstChildOfClass("Backpack")
	if backpack then
		local backpackTool = backpack:FindFirstChild(toolName)
		if backpackTool then
			return backpackTool
		end
	end

	local character = player and player.Character
	if character then
		return character:FindFirstChild(toolName)
	end

	return nil
end

function MissionService:_equipToolForPlayer(player, toolName)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local tool = self:_getMissionTool(player, toolName)
	if humanoid and tool and tool:IsA("Tool") and tool.Parent ~= character then
		humanoid:EquipTool(tool)
	end
end

function MissionService:_createFistsTool(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local existing = self:_getMissionTool(player, "MissionFists")
	if existing then
		existing:Destroy()
	end

	local weapon = self._inventoryService:GetWeaponDefinition("weapon_fists")
	local tool = Instance.new("Tool")
	tool.Name = "MissionFists"
	tool.ToolTip = weapon.DisplayName
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	if weapon.GripPos then
		tool.GripPos = weapon.GripPos
	end
	if weapon.GripForward then
		tool.GripForward = weapon.GripForward
	end
	if weapon.GripRight then
		tool.GripRight = weapon.GripRight
	end
	if weapon.GripUp then
		tool.GripUp = weapon.GripUp
	end

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = weapon.HandleSize or Vector3.new(1.2, 1.2, 1.2)
	handle.Material = Enum.Material.SmoothPlastic
	handle.Color = weapon.HandleColor
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	self:_buildWeaponVisual(tool, handle, weapon)
	tool.Parent = backpack

	tool.Activated:Connect(function()
		local now = os.clock()
		local lastAttack = self._attackCooldowns[player.UserId] or 0
		if now - lastAttack < weapon.Cooldown then
			return
		end
		self._attackCooldowns[player.UserId] = now

		local currentCharacter = player.Character
		local rootPart = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
		local humanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
		if not rootPart or not humanoid or humanoid.Health <= 0 then
			return
		end

		local zombie = self:_findNearestZombie(rootPart, weapon.Range, 0.1)
		if zombie then
			self:_fireCombatFeedback(player, {
				kind = "shot",
				weaponId = weapon.Id,
				recoil = weapon.RecoilDistance or 0.08,
				twist = (weapon.RecoilTwist or 4) / 100,
			})
			self:_emitMuzzleFlash(handle, weapon.HandleColor, weapon.WeaponType)
			self:_damageZombie(zombie, weapon.Damage, player)
			local swing = self:_emitPulse(rootPart.CFrame * CFrame.new(0, 0, -3.2), Vector3.new(2.4, 1.8, 0.45), weapon.HandleColor, 0.48, 0.1)
			if swing then
				swing.Material = Enum.Material.ForceField
			end
		end
	end)
end

function MissionService:_ensureFistsFallback(player)
	local fists = self:_getMissionTool(player, "MissionFists")
	if not fists then
		self:_createFistsTool(player)
	end
	self:_equipToolForPlayer(player, "MissionFists")
end

function MissionService:_emitZombieDeathEffect(position, isElite, isRunner)
	local color = isElite and Color3.fromRGB(255, 112, 112) or (isRunner and Color3.fromRGB(186, 236, 124) or Color3.fromRGB(162, 202, 255))
	local burst = self:_emitPulse(CFrame.new(position), Vector3.new(2.8, 2.8, 2.8), color, 0.38, 0.18)
	if burst then
		burst.Shape = Enum.PartType.Ball
	end

	local column = self:_emitPulse(CFrame.new(position + Vector3.new(0, 1.2, 0)), Vector3.new(0.4, 3.6, 0.4), color, 0.55, 0.14)
	if column then
		column.Material = Enum.Material.ForceField
	end
end

function MissionService:_emitPlayerHitEffect(character, color)
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local burst = self:_emitPulse(rootPart.CFrame, Vector3.new(3.2, 5.2, 3.2), color, 0.76, 0.12)
	if burst then
		burst.Material = Enum.Material.ForceField
	end
end

function MissionService:_isCharacterDowned(character)
	return character and character:GetAttribute("Downed") == true
end

function MissionService:_isCharacterDashing(character)
	return character and character:GetAttribute("MissionDashing") == true
end

function MissionService:_clearDownedState(player, restoreHealth)
	local mission = self._activeMission
	local state = mission and mission.downedStates and mission.downedStates[player.UserId]
	if state then
		if state.prompt then
			state.prompt:Destroy()
		end
		if state.marker then
			state.marker:Destroy()
		end
		if state.highlight then
			state.highlight:Destroy()
		end
		if state.connection then
			state.connection:Disconnect()
		end
		mission.downedStates[player.UserId] = nil
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character then
		character:SetAttribute("Downed", false)
		character:SetAttribute("BleedoutFinalizing", false)
		character:SetAttribute("MissionDashing", false)
	end
	if humanoid and humanoid.Parent then
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
		humanoid.AutoRotate = true
		humanoid.PlatformStand = false
		if restoreHealth then
			humanoid.Health = math.max(humanoid.Health, math.floor(humanoid.MaxHealth * 0.45))
		end
	end
end

function MissionService:_getObjectiveStateText(mission)
	if not mission then
		return "Objective: defend the bunker core"
	end
	if self:_isPowerCellScenario(mission) then
		return "Objective: deliver power cells"
	end
	if self:_isNestScenario(mission) then
		return "Objective: destroy nests"
	end
	return "Objective: defend the bunker core"
end

function MissionService:_enterDownedState(player, mission, character, humanoid)
	if not mission or not character or not humanoid or self:_isCharacterDowned(character) then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	character:SetAttribute("Downed", true)
	character:SetAttribute("BleedoutFinalizing", false)
	character:SetAttribute("MissionDashing", false)
	humanoid.Health = math.max(1, humanoid.Health)
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true

	local downedHighlight = Instance.new("Highlight")
	downedHighlight.Name = "DownedHighlight"
	downedHighlight.FillColor = Color3.fromRGB(255, 132, 102)
	downedHighlight.OutlineColor = Color3.fromRGB(255, 226, 210)
	downedHighlight.FillTransparency = 0.58
	downedHighlight.OutlineTransparency = 0.04
	downedHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	downedHighlight.Parent = character

	local marker, _ = self:_createWorldMarker(character, "DownedMarker", "REVIVE", Color3.fromRGB(255, 196, 152), Vector2.new(120, 30), 15)
	local markerPart = marker :: BasePart
	markerPart.CFrame = rootPart.CFrame * CFrame.new(0, 4.8, 0)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "Revive"
	prompt.ObjectText = player.DisplayName
	prompt:SetAttribute("MissionPrompt", true)
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = self._skillTreeService and self._skillTreeService:GetReviveHoldDuration(player, self._missionConfig.Mission.ReviveHoldDuration) or self._missionConfig.Mission.ReviveHoldDuration
	prompt.MaxActivationDistance = self._missionConfig.Mission.RevivePromptDistance or 12
	prompt.Parent = rootPart

	local state = {
		startedAt = os.clock(),
		prompt = prompt,
		marker = marker,
		highlight = downedHighlight,
		connection = nil,
	}
	mission.downedStates = mission.downedStates or {}
	mission.downedStates[player.UserId] = state

	state.connection = prompt.Triggered:Connect(function(reviver)
		if not self._activeMission or self._activeMission ~= mission or not reviver or reviver == player or not reviver.Parent then
			return
		end
		local reviverCharacter = reviver.Character
		if self:_isCharacterDowned(reviverCharacter) then
			return
		end
		self:_clearDownedState(player, true)
		self:_notifyParty(mission.party, reviver.DisplayName .. " revived " .. player.DisplayName .. ".")
		self:_fireMissionState(mission.party, player.DisplayName .. " revived")
	end)

	self:_notifyParty(mission.party, player.DisplayName .. " is downed. Revive them.")
	self:_fireMissionState(mission.party, player.DisplayName .. " downed")

	task.delay(self._missionConfig.Mission.DownedBleedoutSeconds, function()
		if not self._activeMission or self._activeMission ~= mission then
			return
		end
		local currentState = mission.downedStates[player.UserId]
		if not currentState then
			return
		end
		self:_clearDownedState(player, false)
		player:SetAttribute("MissionEliminated", true)
		if character and character.Parent then
			character:SetAttribute("BleedoutFinalizing", true)
		end
		if humanoid and humanoid.Parent then
			humanoid.Health = 0
		end
	end)
end

function MissionService:_bossSlam(zombie, root, scaledStats)
	local mission = self._activeMission
	if not mission or not zombie or not zombie.Parent or not root or not root.Parent then
		return
	end

	local radius = self._missionConfig.Mission.BossSlamRadius
	local damage = self._missionConfig.Mission.BossSlamDamage
	local pulse = self:_emitPulse(root.CFrame * CFrame.new(0, -1.8, 0), Vector3.new(radius * 2, 0.35, radius * 2), Color3.fromRGB(255, 118, 96), 0.2, 0.28)
	if pulse then
		pulse.Material = Enum.Material.Neon
	end

	self:_notifyParty(mission.party, "Siege Tyrant slam incoming.")
	task.wait(0.45)

	if not self._activeMission or self._activeMission ~= mission or not zombie.Parent or not root.Parent then
		return
	end

	local burst = self:_emitPulse(root.CFrame * CFrame.new(0, -1.2, 0), Vector3.new(radius * 2.3, 1.2, radius * 2.3), Color3.fromRGB(255, 148, 112), 0.28, 0.18)
	if burst then
		burst.Material = Enum.Material.ForceField
	end

	local objective = self:_getMissionObjective()
	if objective and (objective.Position - root.Position).Magnitude <= radius + 6 then
		self:_damageObjective(math.max(8, math.floor((scaledStats.damage or damage) * 1.2)))
	end

	for _, player in ipairs(self:_getLivePartyMembers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and targetRoot and not self:_isCharacterDowned(character) and not self:_isCharacterDashing(character) and not self:_isSpawnProtected(player, character) then
			local offset = targetRoot.Position - root.Position
			local distance = offset.Magnitude
			if distance <= radius then
				humanoid:TakeDamage(damage)
				self:_emitPlayerHitEffect(character, Color3.fromRGB(255, 112, 112))
				if distance > 0.1 then
					targetRoot.AssemblyLinearVelocity = offset.Unit * 34 + Vector3.new(0, 22, 0)
				end
			end
		end
	end

	self:_openBossWeakPoint(zombie)
end

function MissionService:_bruteImpact(zombie, root, scaledStats)
	local mission = self._activeMission
	if not mission or not zombie or not zombie.Parent or not root or not root.Parent then
		return
	end

	local radius = self._missionConfig.Mission.BruteImpactRadius
	local damage = self._missionConfig.Mission.BruteImpactDamage
	local pulse = self:_emitPulse(root.CFrame * CFrame.new(0, -1.1, 0), Vector3.new(radius * 1.7, 0.3, radius * 1.7), Color3.fromRGB(214, 154, 96), 0.28, 0.22)
	if pulse then
		pulse.Material = Enum.Material.Neon
	end

	local objective = self:_getMissionObjective()
	if objective and (objective.Position - root.Position).Magnitude <= radius + 4 then
		self:_damageObjective(math.max(4, math.floor((scaledStats.damage or damage) * 0.8)))
	end

	for _, player in ipairs(self:_getLivePartyMembers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and targetRoot and not self:_isCharacterDowned(character) and not self:_isCharacterDashing(character) and not self:_isSpawnProtected(player, character) then
			local offset = targetRoot.Position - root.Position
			local distance = offset.Magnitude
			if distance <= radius then
				humanoid:TakeDamage(math.max(1, damage))
				self:_emitPlayerHitEffect(character, Color3.fromRGB(236, 174, 118))
				if distance > 0.1 then
					targetRoot.AssemblyLinearVelocity = offset.Unit * 22 + Vector3.new(0, 14, 0)
				end
			end
		end
	end
end

function MissionService:_bossSummonAdds(root, scaledStats)
	local mission = self._activeMission
	if not mission or not root or not root.Parent then
		return
	end

	local count = self._missionConfig.Mission.BossSummonCount
	self:_notifyParty(mission.party, "Siege Tyrant is calling reinforcements.")
	for summonIndex = 1, count do
		local angle = (math.pi * 2 / count) * summonIndex
		local offset = Vector3.new(math.cos(angle) * 11, 0, math.sin(angle) * 11)
		mission.remainingZombies += 1
		self:_spawnZombie(root.Position + offset, {
			health = math.max(28, math.floor((scaledStats.health or 40) * 0.72)),
			damage = math.max(5, math.floor((scaledStats.damage or 8) * 0.9)),
			spawnCount = count,
		}, summonIndex * 3)
	end

	local boss = root.Parent
	if boss and boss:IsA("Model") then
		self:_openBossWeakPoint(boss)
	end
end

function MissionService:_createWorldMarker(parent, name, text, color, size, textSize)
	local marker = Instance.new("Part")
	marker.Name = name
	marker.Size = Vector3.new(1, 1, 1)
	marker.Transparency = 1
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.Parent = parent

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size.X, size.Y)
	gui.StudsOffset = Vector3.new(0, 1.4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 38
	gui.LightInfluence = 1
	gui.Parent = marker

	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	frame.BackgroundTransparency = 0.62
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = 0.46
	stroke.Thickness = 1
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = false
	label.TextSize = textSize
	label.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = frame

	return marker, label
end

function MissionService:_refreshObjectiveVisuals()
	local objective = self:_getMissionObjective()
	if not objective then
		return
	end

	local maxHealth = objective:GetAttribute("ObjectiveMaxHealth") or self._missionConfig.Mission.ObjectiveMaxHealth
	local currentHealth = objective:GetAttribute("ObjectiveHealth") or maxHealth
	local healthRatio = math.clamp(currentHealth / math.max(1, maxHealth), 0, 1)
	local safeColor = Color3.fromRGB(116, 153, 198)
	local dangerColor = Color3.fromRGB(209, 105, 105)
	if self:_isPowerCellScenario() then
		safeColor = Color3.fromRGB(182, 164, 96)
		dangerColor = Color3.fromRGB(218, 122, 92)
	elseif self:_isNestScenario() then
		safeColor = Color3.fromRGB(166, 122, 96)
		dangerColor = Color3.fromRGB(228, 96, 84)
	end
	local baseColor = dangerColor:Lerp(safeColor, healthRatio)
	objective.Color = baseColor

	local runtime = objective.Parent
	local glow = runtime and runtime:FindFirstChild("ObjectiveGlow")
	if glow and glow:IsA("BasePart") then
		glow.Color = dangerColor:Lerp(safeColor:Lerp(Color3.fromRGB(255, 232, 210), 0.2), healthRatio)
		glow.Transparency = 0.2 + ((1 - healthRatio) * 0.35)
	end

	local shield = runtime and runtime:FindFirstChild("ObjectiveShield")
	if shield and shield:IsA("BasePart") then
		shield.Color = baseColor:Lerp(Color3.fromRGB(255, 235, 235), 0.18)
		shield.Transparency = 0.72 + ((1 - healthRatio) * 0.12)
	end

	local marker = runtime and runtime:FindFirstChild("ObjectiveMarker")
	if marker then
		local gui = marker:FindFirstChildOfClass("BillboardGui")
		local frame = gui and gui:FindFirstChildOfClass("Frame")
		local label = frame and frame:FindFirstChild("Label")
		if label and label:IsA("TextLabel") then
			if self:_isPowerCellScenario() then
				local delivered = objective:GetAttribute("DeliveredPowerCells") or 0
				local required = objective:GetAttribute("RequiredPowerCells") or self._missionConfig.Mission.PowerCellRequiredCount
				label.Text = ("POWER RELAY %d/%d  %d%%"):format(delivered, required, math.floor(healthRatio * 100))
			elseif self:_isNestScenario() then
				local destroyed = objective:GetAttribute("DestroyedNests") or 0
				local required = objective:GetAttribute("RequiredNests") or self._missionConfig.Mission.NestRequiredCount
				label.Text = ("BREACH HUNT %d/%d  %d%%"):format(destroyed, required, math.floor(healthRatio * 100))
			else
				label.Text = ("DEFEND CORE %d%%"):format(math.floor(healthRatio * 100))
			end
			label.TextColor3 = Color3.fromRGB(255, 178, 178):Lerp(Color3.fromRGB(184, 228, 255), healthRatio)
		end
	end
end

function MissionService:_getCarriedPowerCellPart(player)
	local character = player and player.Character
	return character and character:FindFirstChild("CarriedPowerCell")
end

function MissionService:_clearCarriedPowerCell(player)
	local cellId = player and player:GetAttribute("PowerCellId")
	local carried = self:_getCarriedPowerCellPart(player)
	if carried then
		carried:Destroy()
	end
	local character = player and player.Character
	local glow = character and character:FindFirstChild("CarriedPowerCellGlow")
	if glow then
		glow:Destroy()
	end
	if player then
		player:SetAttribute("CarryingPowerCell", false)
		player:SetAttribute("PowerCellId", nil)
	end
	return cellId
end

function MissionService:_spawnPowerCellCarrierVisual(player, cellId)
	local character = player and player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return false
	end

	self:_clearCarriedPowerCell(player)

	local cell = Instance.new("Part")
	cell.Name = "CarriedPowerCell"
	cell.Anchored = false
	cell.CanCollide = false
	cell.CanQuery = false
	cell.Material = Enum.Material.Neon
	cell.Color = Color3.fromRGB(255, 214, 124)
	cell.Size = Vector3.new(1.2, 1.2, 1.2)
	cell.CFrame = rootPart.CFrame * CFrame.new(0, 2.4, 1.6)
	cell.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = cell
	weld.Parent = cell

	local glow = Instance.new("Highlight")
	glow.Name = "CarriedPowerCellGlow"
	glow.FillColor = Color3.fromRGB(255, 220, 122)
	glow.OutlineColor = Color3.fromRGB(255, 242, 194)
	glow.FillTransparency = 0.82
	glow.OutlineTransparency = 0.2
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = character

	player:SetAttribute("CarryingPowerCell", true)
	player:SetAttribute("PowerCellId", cellId)
	return true
end

function MissionService:_deliverPowerCell(player)
	local mission = self._activeMission
	local objective = self:_getMissionObjective()
	if not mission or not objective or not self:_isPowerCellScenario(mission) then
		return false
	end

	if player:GetAttribute("CarryingPowerCell") ~= true then
		return false
	end

	local delivered = objective:GetAttribute("DeliveredPowerCells") or 0
	local required = objective:GetAttribute("RequiredPowerCells") or self._missionConfig.Mission.PowerCellRequiredCount
	if delivered >= required then
		return false
	end

	self:_clearCarriedPowerCell(player)
	delivered += 1
	objective:SetAttribute("DeliveredPowerCells", delivered)
	self:_refreshObjectiveVisuals()
	self:_notifyParty(mission.party, ("%s delivered a power cell (%d/%d)."):format(player.DisplayName, delivered, required))
	self:_fireMissionState(mission.party, ("Power cells delivered %d/%d"):format(delivered, required))

	if delivered >= required and mission.wave >= self._missionConfig.Mission.WaveCount and mission.remainingZombies <= 0 then
		self:_completeMission()
	end

	return true
end

function MissionService:_spawnPowerCell(runtime, position, cellId)
	local cell = Instance.new("Part")
	cell.Name = "PowerCell_" .. tostring(cellId)
	cell.Size = Vector3.new(2.2, 2.2, 2.2)
	cell.Anchored = true
	cell.CanCollide = true
	cell.Material = Enum.Material.Neon
	cell.Color = Color3.fromRGB(255, 214, 124)
	cell.CFrame = CFrame.new(position + Vector3.new(0, 1.4, 0))
	cell.Parent = runtime

	local glow = Instance.new("Part")
	glow.Name = cell.Name .. "_Glow"
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanQuery = false
	glow.Material = Enum.Material.Neon
	glow.Color = cell.Color
	glow.Transparency = 0.42
	glow.Size = Vector3.new(4.6, 0.16, 4.6)
	glow.CFrame = cell.CFrame * CFrame.new(0, -1.22, 0)
	glow.Parent = runtime

	local marker, _ = self:_createWorldMarker(runtime, cell.Name .. "_Marker", "POWER CELL", Color3.fromRGB(255, 235, 172), Vector2.new(130, 30), 14)
	marker.CFrame = cell.CFrame * CFrame.new(0, 4.2, 0)
	local markerGui = marker:FindFirstChildOfClass("BillboardGui")
	if markerGui then
		markerGui.MaxDistance = 30
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Carry Cell"
	prompt.ObjectText = "Power Cell"
	prompt:SetAttribute("MissionPrompt", true)
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = self._missionConfig.Mission.SupplyPickupPromptDistance or 14
	prompt.Parent = cell

	prompt.Triggered:Connect(function(player)
		if not self._activeMission or not player or player.Parent ~= Players then
			return
		end

		if player:GetAttribute("CarryingPowerCell") == true then
			return
		end

		if self:_spawnPowerCellCarrierVisual(player, cellId) then
			self:_notifyParty({ player }, "Power cell secured.")
			cell:Destroy()
			glow:Destroy()
			marker:Destroy()
		end
	end)
end

function MissionService:_spawnPowerCellObjective(runtime, objective)
	local missionSpawn = self:_getMissionSpawn()
	if not missionSpawn then
		return
	end
	local layout = self:_getActiveLayout()

	local required = self._missionConfig.Mission.PowerCellRequiredCount
	objective:SetAttribute("DeliveredPowerCells", 0)
	objective:SetAttribute("RequiredPowerCells", required)

	local socketOffsets = {
		Vector3.new(-6, -3.2, 10),
		Vector3.new(6, -3.2, 10),
	}

	for index = 1, required do
		local socket = Instance.new("Part")
		socket.Name = "PowerSocket" .. tostring(index)
		socket.Size = Vector3.new(3.2, 2.2, 3.2)
		socket.Anchored = true
		socket.CanCollide = true
		socket.Material = Enum.Material.Metal
		socket.Color = Color3.fromRGB(92, 96, 108)
		socket.CFrame = objective.CFrame * CFrame.new(socketOffsets[index] or Vector3.new(0, -3.2, 10))
		socket.Parent = runtime

		local socketGlow = Instance.new("Part")
		socketGlow.Name = socket.Name .. "_Glow"
		socketGlow.Anchored = true
		socketGlow.CanCollide = false
		socketGlow.CanQuery = false
		socketGlow.Material = Enum.Material.Neon
		socketGlow.Color = Color3.fromRGB(255, 220, 142)
		socketGlow.Transparency = 0.78
		socketGlow.Size = Vector3.new(4.4, 0.12, 4.4)
		socketGlow.CFrame = socket.CFrame * CFrame.new(0, -1.04, 0)
		socketGlow.Parent = runtime

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Deposit Cell"
		prompt.ObjectText = "Relay Socket"
		prompt:SetAttribute("MissionPrompt", true)
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = self._missionConfig.Mission.ObjectivePromptDistance or 14
		prompt.Parent = socket

		prompt.Triggered:Connect(function(player)
			if self:_deliverPowerCell(player) then
				socket.Color = Color3.fromRGB(178, 158, 108)
				socketGlow.Transparency = 0.3
			end
		end)
	end

	local cellPositions = {}
	for _, offset in ipairs((layout and layout.PowerCellOffsets) or {}) do
		table.insert(cellPositions, self:_getLayoutWorldPosition(offset))
	end
	if #cellPositions == 0 then
		cellPositions = {
			missionSpawn.Position + Vector3.new(22, 0, 22),
			missionSpawn.Position + Vector3.new(-26, 0, 18),
		}
	end

	for index = 1, required do
		self:_spawnPowerCell(runtime, cellPositions[index] or (missionSpawn.Position + Vector3.new(index * 8, 0, 20)), index)
	end
end

function MissionService:_destroyNest(nest)
	local mission = self._activeMission
	local objective = self:_getMissionObjective()
	if not mission or not objective or not nest or not nest.Parent then
		return false
	end

	local destroyed = objective:GetAttribute("DestroyedNests") or 0
	local required = objective:GetAttribute("RequiredNests") or self._missionConfig.Mission.NestRequiredCount
	if destroyed >= required then
		return false
	end

	destroyed += 1
	objective:SetAttribute("DestroyedNests", destroyed)
	self:_refreshObjectiveVisuals()
	self:_emitPulse(nest:GetPivot(), Vector3.new(7, 4, 7), Color3.fromRGB(255, 142, 118), 0.42, 0.18)
	nest:Destroy()
	self:_notifyParty(mission.party, ("Nest destroyed (%d/%d)."):format(destroyed, required))
	self:_fireMissionState(mission.party, ("Nests destroyed %d/%d"):format(destroyed, required))

	if destroyed >= required and mission.wave >= self._missionConfig.Mission.WaveCount and mission.remainingZombies <= 0 then
		self:_completeMission()
	end

	return true
end

function MissionService:_spawnNest(runtime, position, nestId)
	local nest = Instance.new("Model")
	nest.Name = "Nest_" .. tostring(nestId)
	nest.Parent = runtime

	local mound = Instance.new("Part")
	mound.Name = "Mound"
	mound.Size = Vector3.new(6, 3, 6)
	mound.Anchored = true
	mound.CanCollide = true
	mound.Material = Enum.Material.Slate
	mound.Color = Color3.fromRGB(96, 58, 48)
	mound.CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0))
	mound.Parent = nest

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(2.4, 2.4, 2.4)
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.Material = Enum.Material.Neon
	core.Color = Color3.fromRGB(236, 118, 94)
	core.CFrame = mound.CFrame + Vector3.new(0, 2.1, 0)
	core.Parent = nest

	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Size = Vector3.new(8, 0.14, 8)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 156, 126)
	ring.Transparency = 0.62
	ring.CFrame = mound.CFrame * CFrame.new(0, -1.42, 0)
	ring.Parent = nest

	local marker, _ = self:_createWorldMarker(runtime, "NestMarker_" .. tostring(nestId), "DESTROY NEST", Color3.fromRGB(255, 194, 170), Vector2.new(140, 30), 14)
	marker.CFrame = mound.CFrame * CFrame.new(0, 5, 0)
	local markerGui = marker:FindFirstChildOfClass("BillboardGui")
	if markerGui then
		markerGui.MaxDistance = 34
	end

	local aura = Instance.new("Highlight")
	aura.Name = "NestAura"
	aura.FillColor = Color3.fromRGB(196, 102, 84)
	aura.OutlineColor = Color3.fromRGB(255, 196, 176)
	aura.FillTransparency = 0.72
	aura.OutlineTransparency = 0.16
	aura.DepthMode = Enum.HighlightDepthMode.Occluded
	aura.Parent = nest

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Burn Nest"
	prompt.ObjectText = "Infected Nest"
	prompt:SetAttribute("MissionPrompt", true)
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = self._missionConfig.Mission.NestBurnHoldDuration or 0.35
	prompt.MaxActivationDistance = self._missionConfig.Mission.ObjectivePromptDistance or 14
	prompt.Parent = mound

	prompt.Triggered:Connect(function(player)
		if not self._activeMission or not player or player.Parent ~= Players then
			return
		end

		if self:_destroyNest(nest) then
			marker:Destroy()
		end
	end)
end

function MissionService:_spawnNestObjective(runtime, objective)
	local missionSpawn = self:_getMissionSpawn()
	if not missionSpawn then
		return
	end
	local layout = self:_getActiveLayout()

	local required = self._missionConfig.Mission.NestRequiredCount
	objective:SetAttribute("DestroyedNests", 0)
	objective:SetAttribute("RequiredNests", required)

	local positions = {}
	for _, offset in ipairs((layout and layout.NestOffsets) or {}) do
		table.insert(positions, self:_getLayoutWorldPosition(offset))
	end
	if #positions == 0 then
		positions = {
			missionSpawn.Position + Vector3.new(28, 0, 28),
			missionSpawn.Position + Vector3.new(-30, 0, 20),
			missionSpawn.Position + Vector3.new(0, 0, 40),
		}
	end

	for index = 1, required do
		self:_spawnNest(runtime, positions[index] or (missionSpawn.Position + Vector3.new(index * 10, 0, 28)), index)
	end
end

function MissionService:_createWeaponTool(player)
	local weaponId = self._inventoryService:GetEquippedWeaponId(player)
	local weapon = self._inventoryService:GetWeaponDefinition(weaponId)
	local isRangedWeapon = weapon.WeaponType == "Ranged" or weapon.WeaponType == "Spread"

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local existing = backpack:FindFirstChild("MissionWeapon")
	if existing then
		existing:Destroy()
	end

	local character = player.Character
	if character then
		local equipped = character:FindFirstChild("MissionWeapon")
		if equipped then
			equipped:Destroy()
		end
	end

	local tool = Instance.new("Tool")
	tool.Name = "MissionWeapon"
	tool.ToolTip = weapon.DisplayName
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = weapon.HandleSize or Vector3.new(1, 4, 1)
	handle.Material = Enum.Material.Metal
	handle.Color = weapon.HandleColor
	handle.CanCollide = false
	handle.Massless = true
	handle.Transparency = 1
	handle.CastShadow = false
	handle.Parent = tool

	self:_buildWeaponVisual(tool, handle, weapon)
	tool.Parent = backpack

	if isRangedWeapon then
		self:_createFistsTool(player)
	end

	self._weaponState[player.UserId] = {
		weaponId = weaponId,
		currentAmmo = isRangedWeapon and weapon.MagazineSize or nil,
		reserveAmmo = isRangedWeapon and math.max(
			0,
			math.floor((weapon.ReserveAmmo or 0) * (self._skillTreeService and self._skillTreeService:GetReserveAmmoMultiplier(player) or 1))
		) or nil,
		reloading = false,
		reloadToken = 0,
	}

	local function reloadWeapon()
		local state = self._weaponState[player.UserId]
		if not state or state.reloading or not isRangedWeapon or (state.reserveAmmo or 0) <= 0 or (state.currentAmmo or 0) >= (weapon.MagazineSize or 0) then
			return
		end

		state.reloading = true
		state.reloadToken = (state.reloadToken or 0) + 1
		local reloadToken = state.reloadToken
		self:_emitReloadEffect(handle, weapon.HandleColor)
		self:_fireCombatFeedback(player, {
			kind = "reload_start",
			weaponId = weapon.Id,
		})
		if weapon.WeaponType == "Spread" then
			task.spawn(function()
				while true do
					task.wait(weapon.ShellReloadTime or math.max(0.25, (weapon.ReloadTime or 1.6) / math.max(1, weapon.MagazineSize or 1)))
					local currentState = self._weaponState[player.UserId]
					if not currentState or currentState ~= state or currentState.reloadToken ~= reloadToken or not currentState.reloading then
						return
					end
					if (currentState.reserveAmmo or 0) <= 0 or (currentState.currentAmmo or 0) >= (weapon.MagazineSize or 0) then
						currentState.reloading = false
						self:_emitReloadEffect(handle, weapon.HandleColor:Lerp(Color3.fromRGB(255, 255, 255), 0.2))
						self:_fireCombatFeedback(player, {
							kind = "reload_complete",
							weaponId = weapon.Id,
						})
						self:_fireMissionState({ player }, "Weapon ready")
						return
					end

					currentState.currentAmmo += 1
					currentState.reserveAmmo -= 1
					self:_emitReloadEffect(handle, weapon.HandleColor)
					self:_fireCombatFeedback(player, {
						kind = "reload_insert",
						weaponId = weapon.Id,
						currentAmmo = currentState.currentAmmo,
						reserveAmmo = currentState.reserveAmmo,
					})
					if currentState.currentAmmo >= (weapon.MagazineSize or 0) or (currentState.reserveAmmo or 0) <= 0 then
						currentState.reloading = false
						self:_emitReloadEffect(handle, weapon.HandleColor:Lerp(Color3.fromRGB(255, 255, 255), 0.2))
						self:_fireCombatFeedback(player, {
							kind = "reload_complete",
							weaponId = weapon.Id,
						})
						self:_fireMissionState({ player }, "Weapon ready")
						return
					end
					self:_fireMissionState({ player }, ("Loading shell %d/%d"):format(currentState.currentAmmo, weapon.MagazineSize or currentState.currentAmmo))
				end
			end)
			self:_fireMissionState({ player }, "Loading shell...")
		else
			self:_fireMissionState({ player }, "Reloading...")
			task.delay(weapon.ReloadTime or 1, function()
				local currentState = self._weaponState[player.UserId]
				if not currentState or currentState ~= state or currentState.reloadToken ~= reloadToken then
					return
				end

				local ammoNeeded = (weapon.MagazineSize or 0) - (currentState.currentAmmo or 0)
				local loaded = math.min(ammoNeeded, currentState.reserveAmmo or 0)
				currentState.currentAmmo = (currentState.currentAmmo or 0) + loaded
				currentState.reserveAmmo = (currentState.reserveAmmo or 0) - loaded
				currentState.reloading = false
				self:_emitReloadEffect(handle, weapon.HandleColor:Lerp(Color3.fromRGB(255, 255, 255), 0.2))
				self:_fireCombatFeedback(player, {
					kind = "reload_complete",
					weaponId = weapon.Id,
					currentAmmo = currentState.currentAmmo,
					reserveAmmo = currentState.reserveAmmo,
				})
				self:_fireMissionState({ player }, "Weapon ready")
			end)
		end
	end

	tool.Equipped:Connect(function()
		self:_fireMissionState({ player }, "Weapon ready")
	end)

	tool.Activated:Connect(function()
		local now = os.clock()
		local lastAttack = self._attackCooldowns[player.UserId] or 0
		if now - lastAttack < weapon.Cooldown then
			return
		end
		self._attackCooldowns[player.UserId] = now

		local currentCharacter = player.Character
		local rootPart = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
		local humanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
		if not rootPart or not humanoid or humanoid.Health <= 0 then
			return
		end

		local state = self._weaponState[player.UserId]

		if isRangedWeapon then
			if not state then
				return
			end

			if state.reloading then
				if weapon.WeaponType == "Spread" and (state.currentAmmo or 0) > 0 then
					state.reloading = false
					state.reloadToken = (state.reloadToken or 0) + 1
				else
					return
				end
			end

			if state.reloading then
				return
			end

			if (state.currentAmmo or 0) <= 0 then
				if (state.reserveAmmo or 0) <= 0 then
					self:_ensureFistsFallback(player)
					self:_fireCombatFeedback(player, {
						kind = "dry_fire",
						weaponId = weapon.Id,
					})
					self:_fireMissionState({ player }, "Out of ammo. Switched to fists")
					return
				end
				reloadWeapon()
				return
			end

			state.currentAmmo -= 1
			self:_fireCombatFeedback(player, {
				kind = "shot",
				weaponId = weapon.Id,
				recoil = weapon.RecoilDistance or 0.12,
				twist = (weapon.RecoilTwist or 6) / 100,
			})
			self:_emitMuzzleFlash(handle, weapon.HandleColor, weapon.WeaponType, weapon)
			self:_kickWeaponVisual(handle, weapon)
			if weapon.ModelStyle == "Shotgun" then
				self:_pumpShotgunVisual(tool, handle, weapon)
			end
			local origin = rootPart.Position + Vector3.new(0, 1.5, 0)
			local direction = rootPart.CFrame.LookVector * weapon.Range
			local rayCount = weapon.WeaponType == "Spread" and (weapon.PelletCount or 6) or 1
			local hitRegistry = {}
			for pellet = 1, rayCount do
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				local exclude = {}
				if player.Character then
					table.insert(exclude, player.Character)
				end
				params.FilterDescendantsInstances = exclude

				local pelletDirection = direction
				if weapon.WeaponType == "Spread" then
					local spreadValue = weapon.HipSpread or 0.12
					local spread = Vector3.new(math.random(-100, 100) / 100 * spreadValue, math.random(-100, 100) / 100 * spreadValue, math.random(-100, 100) / 100 * spreadValue)
					pelletDirection = (rootPart.CFrame.LookVector + spread).Unit * weapon.Range
				elseif weapon.HipSpread and weapon.HipSpread > 0 then
					local spreadValue = weapon.HipSpread
					if weapon.ModelStyle == "SMG" then
						spreadValue *= 1 + math.clamp((pellet - 1) * 0.16, 0, 0.65)
					end
					local spread = Vector3.new(math.random(-100, 100) / 100 * spreadValue, math.random(-100, 100) / 100 * spreadValue, math.random(-100, 100) / 100 * spreadValue)
					pelletDirection = (rootPart.CFrame.LookVector + spread).Unit * weapon.Range
				end

				local result = Workspace:Raycast(origin, pelletDirection, params)
				local hitPosition = origin + pelletDirection
				local hitZombie = nil
				if result then
					hitPosition = result.Position
					hitZombie = self:_resolveRaycastZombie(result)
				end
				self:_emitTracer(origin, hitPosition, weapon.HandleColor)
				self:_emitImpactEffect(hitPosition, weapon.HandleColor, hitZombie ~= nil)

				local zombie = hitZombie
				if not zombie and weapon.WeaponType == "Ranged" then
					zombie = self:_findNearestZombie(rootPart, math.min(weapon.Range, 18), weapon.AimAssistDot or 0.92)
				end
				if zombie and not hitRegistry[zombie] then
					hitRegistry[zombie] = true
					self:_damageZombie(zombie, weapon.Damage, player)
				end
			end

			if (state.currentAmmo or 0) <= 0 then
				if (state.reserveAmmo or 0) > 0 then
					reloadWeapon()
				else
					self:_ensureFistsFallback(player)
					self:_fireCombatFeedback(player, {
						kind = "dry_fire",
						weaponId = weapon.Id,
					})
					self:_fireMissionState({ player }, "Out of ammo. Switched to fists")
				end
			elseif (state.currentAmmo or 0) <= math.max(1, math.floor((weapon.MagazineSize or 1) * 0.3)) then
				self:_fireCombatFeedback(player, {
					kind = "low_ammo",
					weaponId = weapon.Id,
					currentAmmo = state.currentAmmo,
					reserveAmmo = state.reserveAmmo,
				})
				self:_fireMissionState({ player }, ("Low ammo: %d/%d"):format(state.currentAmmo, state.reserveAmmo or 0))
			else
				self:_fireMissionState({ player }, "Weapon ready")
			end
		else
			local zombie = self:_findNearestZombie(rootPart, weapon.Range, 0.15)
			if zombie then
				self:_fireCombatFeedback(player, {
					kind = "shot",
					weaponId = weapon.Id,
					recoil = weapon.RecoilDistance or 0.1,
					twist = (weapon.RecoilTwist or 6) / 100,
				})
				self:_emitMuzzleFlash(handle, weapon.HandleColor, weapon.WeaponType, weapon)
				self:_kickWeaponVisual(handle, weapon)
				self:_damageZombie(zombie, weapon.Damage, player)

				local swing = self:_emitPulse(rootPart.CFrame * CFrame.new(0, 0, -4), Vector3.new(3.4, 2.2, 0.4), weapon.HandleColor, 0.45, 0.12)
				if swing then
					swing.Material = Enum.Material.ForceField
				end
			end
		end
	end)
end

function MissionService:_applyPlayerMissionStats(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	character:SetAttribute("Downed", false)
	character:SetAttribute("BleedoutFinalizing", false)
	player:SetAttribute("MissionMedkits", player:GetAttribute("MissionMedkits") or 0)

	local maxHealth = 100 + self._inventoryService:GetMaxHealthBonus(player)
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
	humanoid.WalkSpeed = 16
	character:SetAttribute("MissionDashing", false)
end

function MissionService:_createMedkitTool(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local existing = backpack:FindFirstChild("MissionMedkit")
	if existing then
		existing:Destroy()
	end

	local character = player.Character
	if character then
		local equipped = character:FindFirstChild("MissionMedkit")
		if equipped then
			equipped:Destroy()
		end
	end

	local tool = Instance.new("Tool")
	tool.Name = "MissionMedkit"
	tool.ToolTip = "Field Medkit"
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1.1, 1.1, 1.1)
	handle.Material = Enum.Material.SmoothPlastic
	handle.Color = Color3.fromRGB(146, 216, 164)
	handle.Parent = tool

	local function refreshState()
		local count = player:GetAttribute("MissionMedkits") or 0
		tool.ToolTip = ("Field Medkit x%d"):format(count)
		tool.Enabled = count > 0
	end

	tool.Equipped:Connect(function()
		refreshState()
		if tool.Enabled then
			self:_fireMissionState({ player }, ("Medkits: %d"):format(player:GetAttribute("MissionMedkits") or 0))
		end
	end)

	tool.Activated:Connect(function()
		local characterNow = player.Character
		local humanoid = characterNow and characterNow:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or self:_isCharacterDowned(characterNow) then
			return
		end

		local count = player:GetAttribute("MissionMedkits") or 0
		if count <= 0 or humanoid.Health >= humanoid.MaxHealth then
			return
		end

		player:SetAttribute("MissionMedkits", count - 1)
		local medkitHeal = self._missionConfig.Mission.MedkitHealAmount + (self._skillTreeService and self._skillTreeService:GetMedkitBonus(player) or 0)
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + medkitHeal)
		self:_emitReloadEffect(handle, Color3.fromRGB(146, 216, 164))
		self:_notifyParty({ player }, "Medkit used.")
		self:_fireMissionState({ player }, ("Recovered to %d%%"):format(math.floor((humanoid.Health / humanoid.MaxHealth) * 100)))
		refreshState()
	end)

	refreshState()
	tool.Parent = backpack
end

function MissionService:_grantMedkitPickup(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	player:SetAttribute("MissionMedkits", (player:GetAttribute("MissionMedkits") or 0) + 1)
	self:_createMedkitTool(player)
	self:_fireMissionState({ player }, ("Medkit secured x%d"):format(player:GetAttribute("MissionMedkits") or 0))
	return true
end

function MissionService:_createDashTool(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local existing = backpack:FindFirstChild("MissionDash")
	if existing then
		existing:Destroy()
	end

	local character = player.Character
	if character then
		local equipped = character:FindFirstChild("MissionDash")
		if equipped then
			equipped:Destroy()
		end
	end

	local tool = Instance.new("Tool")
	tool.Name = "MissionDash"
	tool.ToolTip = "Burst Dash"
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Material = Enum.Material.Neon
	handle.Color = Color3.fromRGB(116, 214, 255)
	handle.Parent = tool

	local cooldownEndsAt = 0

	local function refreshState()
		local remaining = math.max(0, cooldownEndsAt - os.clock())
		tool.Enabled = remaining <= 0
		tool.ToolTip = remaining <= 0 and "Burst Dash" or ("Burst Dash %.1fs"):format(remaining)
	end

	tool.Equipped:Connect(function()
		refreshState()
	end)

	tool.Activated:Connect(function()
		local now = os.clock()
		if now < cooldownEndsAt then
			refreshState()
			return
		end

		local characterNow = player.Character
		local humanoid = characterNow and characterNow:FindFirstChildOfClass("Humanoid")
		local rootPart = characterNow and characterNow:FindFirstChild("HumanoidRootPart")
		if not humanoid or not rootPart or humanoid.Health <= 0 or self:_isCharacterDowned(characterNow) then
			return
		end

		local dashCooldown = self._skillTreeService and self._skillTreeService:GetDashCooldown(player, self._missionConfig.Mission.DashCooldown) or self._missionConfig.Mission.DashCooldown
		cooldownEndsAt = now + dashCooldown
		refreshState()
		characterNow:SetAttribute("MissionDashing", true)
		self:_emitPulse(rootPart.CFrame, Vector3.new(3.2, 3.2, 3.2), Color3.fromRGB(132, 224, 255), 0.4, 0.16)
		rootPart.AssemblyLinearVelocity = rootPart.CFrame.LookVector * self._missionConfig.Mission.DashSpeed + Vector3.new(0, rootPart.AssemblyLinearVelocity.Y, 0)
		self:_fireMissionState({ player }, "Dash used")

		task.delay(self._missionConfig.Mission.DashDuration, function()
			if characterNow and characterNow.Parent then
				characterNow:SetAttribute("MissionDashing", false)
			end
		end)

		task.delay(dashCooldown, function()
			if tool and tool.Parent then
				refreshState()
			end
		end)
	end)

	refreshState()
	tool.Parent = backpack
end

function MissionService:_equipPlayer(player)
	self:_applyPlayerMissionStats(player)
	self:_createWeaponTool(player)
	self:_createMedkitTool(player)
	self:_createDashTool(player)
	self:_applyCosmetic(player)
	self:_fireMissionState({ player }, self:_getObjectiveStateText(self._activeMission))
end

function MissionService:_applyCosmetic(player)
	local cosmeticId = self._inventoryService:GetEquippedCosmetic(player)
	local cosmetic = self._inventoryService._missionConfig.getCosmeticDefinition(cosmeticId)
	local character = player.Character
	if not character then
		return
	end

	local existing = character:FindFirstChild("EquippedCosmeticHighlight")
	if existing then
		existing:Destroy()
	end

	if not cosmetic then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "EquippedCosmeticHighlight"
	highlight.FillColor = cosmetic.HighlightColor
	highlight.OutlineColor = cosmetic.HighlightColor
	highlight.FillTransparency = cosmetic.FillTransparency
	highlight.OutlineTransparency = cosmetic.OutlineTransparency
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = character
end

function MissionService:_bindCharacter(player)
	local mission = self._activeMission
	if not mission then
		return
	end

	local function placeCurrentCharacter()
		if self._activeMission ~= mission then
			return
		end
		if player:GetAttribute("MissionEliminated") == true then
			self:_fireMissionState({ player }, "Eliminated. Await squad extraction.")
			return
		end

		local spawn = self:_getPlayerMissionSpawnCFrame()
		local character = player.Character
		if spawn and character then
			character:PivotTo(spawn + Vector3.new(0, 4, 0))
		end
		self:_grantSpawnProtection(player)
		self:_equipPlayer(player)
	end

	local connection = player.CharacterAdded:Connect(function()
		task.wait(0.25)
		placeCurrentCharacter()
	end)

	table.insert(mission.connections, connection)
	task.defer(placeCurrentCharacter)
end

function MissionService:_spawnZombie(spawnPosition, scaledStats, index)
	local runtime = self._activeMission and self._activeMission.zombiesFolder
	if not runtime then
		return
	end

	local zombie = Instance.new("Model")
	zombie.Name = ("Zombie_%d_%d"):format(self._activeMission.wave, index)
	zombie.Parent = runtime
	local isBoss = index == scaledStats.spawnCount and self._activeMission and self._activeMission.wave >= self._missionConfig.Mission.WaveCount
	local isElite = false
	local isBrute = not isBoss and self._activeMission and self._activeMission.wave >= 3 and index % 4 == 0
	local isRunner = not isElite and not isBrute and self._activeMission and self._activeMission.wave >= 2 and index % 3 == 0

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = isBoss and Vector3.new(4.2, 4.2, 2.4) or (isBrute and Vector3.new(2.8, 2.8, 1.4) or Vector3.new(2, 2, 1))
	root.CFrame = CFrame.new(spawnPosition + Vector3.new(0, 3, 0))
	root.Material = Enum.Material.Slate
	root.Color = isBoss and Color3.fromRGB(110, 54, 54) or (isElite and Color3.fromRGB(130, 70, 70) or (isBrute and Color3.fromRGB(114, 88, 68) or (isRunner and Color3.fromRGB(108, 132, 82) or Color3.fromRGB(78, 100, 74))))
	root.Parent = zombie

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = isBoss and Vector3.new(4.8, 5.8, 2.8) or (isElite and Vector3.new(2.6, 3.2, 1.5) or (isBrute and Vector3.new(3.3, 3.8, 1.9) or (isRunner and Vector3.new(2, 2.1, 1.1) or Vector3.new(2.2, 2.5, 1.3))))
	torso.CFrame = root.CFrame + Vector3.new(0, isBoss and 3.2 or (isBrute and 2.1 or 1.6), 0)
	torso.Material = Enum.Material.SmoothPlastic
	torso.Color = isBoss and Color3.fromRGB(148, 64, 64) or (isElite and Color3.fromRGB(156, 82, 82) or (isBrute and Color3.fromRGB(152, 112, 84) or (isRunner and Color3.fromRGB(138, 168, 96) or Color3.fromRGB(95, 125, 88))))
	torso.Parent = zombie

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = isBoss and Vector3.new(2.8, 2.8, 2.8) or (isElite and Vector3.new(1.9, 1.9, 1.9) or (isBrute and Vector3.new(2.1, 2.1, 2.1) or (isRunner and Vector3.new(1.4, 1.4, 1.4) or Vector3.new(1.6, 1.6, 1.6))))
	head.CFrame = root.CFrame + Vector3.new(0, isBoss and 6.2 or (isElite and 3.9 or (isBrute and 4.8 or (isRunner and 3.1 or 3.4))), 0)
	head.Material = Enum.Material.SmoothPlastic
	head.Color = isBoss and Color3.fromRGB(222, 118, 118) or (isElite and Color3.fromRGB(210, 116, 116) or (isBrute and Color3.fromRGB(210, 168, 128) or (isRunner and Color3.fromRGB(182, 204, 136) or Color3.fromRGB(142, 167, 128))))
	head.Parent = zombie

	local leftArm = Instance.new("Part")
	leftArm.Name = "LeftArm"
	leftArm.Size = isBoss and Vector3.new(1.2, 4.4, 1.2) or (isBrute and Vector3.new(0.95, 3.2, 0.95) or (isRunner and Vector3.new(0.45, 2.6, 0.45) or Vector3.new(0.62, 2.8, 0.62)))
	leftArm.CFrame = torso.CFrame * CFrame.new(-(torso.Size.X * 0.5 + leftArm.Size.X * 0.35), 0.05, 0)
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.Color = torso.Color:Lerp(Color3.fromRGB(38, 42, 48), isRunner and 0.18 or 0.1)
	leftArm.Parent = zombie

	local rightArm = Instance.new("Part")
	rightArm.Name = "RightArm"
	rightArm.Size = leftArm.Size
	rightArm.CFrame = torso.CFrame * CFrame.new(torso.Size.X * 0.5 + rightArm.Size.X * 0.35, 0.05, 0)
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.Color = leftArm.Color
	rightArm.Parent = zombie

	local leftArmWeld = Instance.new("WeldConstraint")
	leftArmWeld.Part0 = torso
	leftArmWeld.Part1 = leftArm
	leftArmWeld.Parent = torso

	local rightArmWeld = Instance.new("WeldConstraint")
	rightArmWeld.Part0 = torso
	rightArmWeld.Part1 = rightArm
	rightArmWeld.Parent = torso

	local rootWeld = Instance.new("WeldConstraint")
	rootWeld.Part0 = root
	rootWeld.Part1 = torso
	rootWeld.Parent = root

	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = torso
	headWeld.Part1 = head
	headWeld.Parent = torso

	local eyeGlow = Instance.new("Part")
	eyeGlow.Name = "EyeGlow"
	eyeGlow.Size = isBoss and Vector3.new(0.7, 0.16, 0.16) or (isBrute and Vector3.new(0.46, 0.12, 0.12) or Vector3.new(0.34, 0.1, 0.1))
	eyeGlow.Anchored = false
	eyeGlow.CanCollide = false
	eyeGlow.CanQuery = false
	eyeGlow.Material = Enum.Material.Neon
	eyeGlow.Color = isBoss and Color3.fromRGB(255, 138, 118) or (isBrute and Color3.fromRGB(255, 196, 132) or (isRunner and Color3.fromRGB(198, 255, 142) or Color3.fromRGB(208, 228, 255)))
	eyeGlow.CFrame = head.CFrame * CFrame.new(0, 0.08, -(head.Size.Z * 0.48))
	eyeGlow.Parent = zombie

	local eyeWeld = Instance.new("WeldConstraint")
	eyeWeld.Part0 = head
	eyeWeld.Part1 = eyeGlow
	eyeWeld.Parent = head

	local spinePlate = Instance.new("Part")
	spinePlate.Name = "SpinePlate"
	spinePlate.Size = isBoss and Vector3.new(0.42, 3.1, 0.32) or (isBrute and Vector3.new(0.32, 2.3, 0.24) or Vector3.new(0.18, 1.7, 0.18))
	spinePlate.Material = Enum.Material.Metal
	spinePlate.Color = isBoss and Color3.fromRGB(144, 82, 82) or (isBrute and Color3.fromRGB(156, 128, 88) or (isRunner and Color3.fromRGB(158, 204, 112) or Color3.fromRGB(112, 126, 108)))
	spinePlate.CFrame = torso.CFrame * CFrame.new(0, 0.1, torso.Size.Z * 0.5 + 0.08)
	spinePlate.Parent = zombie
	local spinePlateWeld = Instance.new("WeldConstraint")
	spinePlateWeld.Part0 = torso
	spinePlateWeld.Part1 = spinePlate
	spinePlateWeld.Parent = torso

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	local zombieHealth = isBoss and math.floor(scaledStats.health * self._missionConfig.Mission.BossHealthScale) or (isElite and math.floor(scaledStats.health * 1.8) or scaledStats.health)
	if isBrute then
		zombieHealth = math.max(60, math.floor(scaledStats.health * self._missionConfig.Mission.BruteHealthScale))
	end
	if isRunner then
		zombieHealth = math.max(20, math.floor(zombieHealth * 0.72))
	end
	humanoid.MaxHealth = zombieHealth
	humanoid.Health = zombieHealth
	humanoid.WalkSpeed = isBoss and 9.8 or (isElite and 12.5 or (isBrute and 8.8 or (isRunner and 15.5 or 11)))
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayDistance = 0
	humanoid.NameDisplayDistance = 0
	humanoid.Parent = zombie

	root:SetNetworkOwner(nil)
	zombie.PrimaryPart = root
	local touchDamage = isBoss and math.max(12, math.floor(scaledStats.damage * self._missionConfig.Mission.BossDamageScale)) or (isElite and math.floor(scaledStats.damage * 1.4) or (isBrute and math.max(8, math.floor(scaledStats.damage * self._missionConfig.Mission.BruteDamageScale)) or (isRunner and math.max(4, math.floor(scaledStats.damage * 0.85)) or scaledStats.damage)))
	zombie:SetAttribute("ZombieDamage", touchDamage)
	zombie:SetAttribute("ObjectiveDamage", math.max(4, math.floor(touchDamage * (isBoss and 0.9 or 0.7))))
	zombie:SetAttribute("Elite", isElite)
	zombie:SetAttribute("Brute", isBrute)
	zombie:SetAttribute("Runner", isRunner)
	zombie:SetAttribute("Boss", isBoss)
	local modifierTraits = self:_getModifierRuntimeTraits()
	local objectivePressure = isBoss or isBrute or (self._activeMission.wave >= 3 and index % 3 == 0) or (self._activeMission.wave >= 2 and index % 4 == 0)
	if self._activeMission.wave >= 2 and index % modifierTraits.ObjectivePressureInterval == 0 then
		objectivePressure = true
	end
	if modifierTraits.ForceRunnerPressure and isRunner then
		objectivePressure = true
	end
	if modifierTraits.ForceBrutePressure and isBrute then
		objectivePressure = true
	end
	zombie:SetAttribute("ObjectivePressure", objectivePressure)

	if isBoss then
		zombie.Name = ("SiegeTyrant_%d"):format(self._activeMission.wave)
		local aura = Instance.new("Highlight")
		aura.Name = "BossAura"
		aura.FillColor = Color3.fromRGB(255, 88, 88)
		aura.OutlineColor = Color3.fromRGB(255, 228, 196)
		aura.FillTransparency = 0.42
		aura.OutlineTransparency = 0
		aura.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		aura.Parent = zombie

		local bossGui = Instance.new("BillboardGui")
		bossGui.Name = "BossMarker"
		bossGui.Size = UDim2.fromOffset(200, 44)
		bossGui.StudsOffset = Vector3.new(0, 8.5, 0)
		bossGui.AlwaysOnTop = false
		bossGui.MaxDistance = 70
		bossGui.Adornee = root
		bossGui.Parent = zombie

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.Text = "SIEGE TYRANT"
		label.TextColor3 = Color3.fromRGB(255, 212, 188)
		label.TextStrokeTransparency = 0.35
		label.TextScaled = false
		label.TextSize = 22
		label.Parent = bossGui
	elseif isElite then
		local aura = Instance.new("Highlight")
		aura.Name = "EliteAura"
		aura.FillColor = Color3.fromRGB(255, 104, 104)
		aura.OutlineColor = Color3.fromRGB(255, 221, 221)
		aura.FillTransparency = 0.5
		aura.OutlineTransparency = 0
		aura.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		aura.Parent = zombie
	elseif isBrute then
		local aura = Instance.new("Highlight")
		aura.Name = "BruteAura"
		aura.FillColor = Color3.fromRGB(214, 154, 96)
		aura.OutlineColor = Color3.fromRGB(255, 221, 176)
		aura.FillTransparency = 0.58
		aura.OutlineTransparency = 0.04
		aura.DepthMode = Enum.HighlightDepthMode.Occluded
		aura.Parent = zombie
		local chestPlate = Instance.new("Part")
		chestPlate.Name = "ChestPlate"
		chestPlate.Size = Vector3.new(2.4, 1.2, 0.28)
		chestPlate.Material = Enum.Material.Metal
		chestPlate.Color = Color3.fromRGB(148, 118, 84)
		chestPlate.CFrame = torso.CFrame * CFrame.new(0, 0.2, -(torso.Size.Z * 0.5 + 0.1))
		chestPlate.Parent = zombie
		local chestWeld = Instance.new("WeldConstraint")
		chestWeld.Part0 = torso
		chestWeld.Part1 = chestPlate
		chestWeld.Parent = torso
		local shoulderPad = Instance.new("Part")
		shoulderPad.Name = "ShoulderPad"
		shoulderPad.Size = Vector3.new(3.2, 0.44, 0.8)
		shoulderPad.Material = Enum.Material.Metal
		shoulderPad.Color = Color3.fromRGB(168, 132, 88)
		shoulderPad.CFrame = torso.CFrame * CFrame.new(0, torso.Size.Y * 0.38, -(torso.Size.Z * 0.18))
		shoulderPad.Parent = zombie
		local shoulderWeld = Instance.new("WeldConstraint")
		shoulderWeld.Part0 = torso
		shoulderWeld.Part1 = shoulderPad
		shoulderWeld.Parent = torso
	elseif isRunner then
		local aura = Instance.new("Highlight")
		aura.Name = "RunnerAura"
		aura.FillColor = Color3.fromRGB(178, 236, 118)
		aura.OutlineColor = Color3.fromRGB(238, 255, 214)
		aura.FillTransparency = 0.72
		aura.OutlineTransparency = 0.16
		aura.DepthMode = Enum.HighlightDepthMode.Occluded
		aura.Parent = zombie
		local runnerSpine = Instance.new("Part")
		runnerSpine.Name = "RunnerSpine"
		runnerSpine.Size = Vector3.new(0.18, 1.4, 0.18)
		runnerSpine.Material = Enum.Material.Neon
		runnerSpine.Color = Color3.fromRGB(172, 236, 124)
		runnerSpine.Transparency = 0.18
		runnerSpine.CFrame = torso.CFrame * CFrame.new(0, 0.1, torso.Size.Z * 0.5 + 0.08)
		runnerSpine.Parent = zombie
		local spineWeld = Instance.new("WeldConstraint")
		spineWeld.Part0 = torso
		spineWeld.Part1 = runnerSpine
		spineWeld.Parent = torso
	end

	local hitCooldowns = {}
	local bossSlamReadyAt = os.clock() + 2.5
	local bossSummonReadyAt = os.clock() + 4.5
	local runnerBurstReadyAt = os.clock() + 1.5
	local bruteImpactReadyAt = os.clock() + 2.8
	local bossEnrageActive = false
	local touchConnection = root.Touched:Connect(function(hit)
		local character = hit and hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local now = os.clock()
		if hitCooldowns[player.UserId] and now - hitCooldowns[player.UserId] < 1 then
			return
		end
		hitCooldowns[player.UserId] = now

		local targetHumanoid = character:FindFirstChildOfClass("Humanoid")
		if targetHumanoid and targetHumanoid.Health > 0 and not self:_isCharacterDowned(character) and not self:_isCharacterDashing(character) and not self:_isSpawnProtected(player, character) then
			targetHumanoid:TakeDamage(zombie:GetAttribute("ZombieDamage") or scaledStats.damage)
			self:_emitPlayerHitEffect(character, isBoss and Color3.fromRGB(255, 98, 98) or (isElite and Color3.fromRGB(255, 112, 112) or (isBrute and Color3.fromRGB(236, 174, 118) or (isRunner and Color3.fromRGB(196, 236, 124) or Color3.fromRGB(182, 214, 255)))))
		end
	end)

	local aiThread = task.spawn(function()
		while humanoid.Health > 0 and self._activeMission and self._activeMission.zombiesFolder == runtime do
			local nearestRoot = nil
			local nearestDistance = math.huge

			for _, player in ipairs(self:_getLivePartyMembers()) do
				local character = player.Character
				local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
				local targetHumanoid = character and character:FindFirstChildOfClass("Humanoid")
				if targetRoot and targetHumanoid and targetHumanoid.Health > 0 and not self:_isCharacterDowned(character) and not self:_isCharacterDashing(character) and not self:_isSpawnProtected(player, character) then
					local distance = (targetRoot.Position - root.Position).Magnitude
					if distance < nearestDistance then
						nearestDistance = distance
						nearestRoot = targetRoot
					end
				end
			end

			local objective = self:_getMissionObjective()
			local targetRoot = nearestRoot
			local targetDistance = nearestDistance
			if objective then
				local objectiveDistance = (objective.Position - root.Position).Magnitude
				local objectivePressure = zombie:GetAttribute("ObjectivePressure") == true
				local disruptRange = isBoss and 20 or (isBrute and 14 or (isRunner and 10 or 12))
				if objectivePressure and (not nearestRoot or nearestDistance > disruptRange) then
					targetRoot = objective
					targetDistance = objectiveDistance
				elseif not nearestRoot then
					targetRoot = objective
					targetDistance = objectiveDistance
				end
			end

			if targetRoot then
				local now = os.clock()
				if isRunner and targetRoot ~= objective and targetDistance <= self._missionConfig.Mission.RunnerBurstDistance and now >= runnerBurstReadyAt then
					runnerBurstReadyAt = now + self._missionConfig.Mission.RunnerBurstCooldown
					local burstDirection = targetRoot.Position - root.Position
					if burstDirection.Magnitude > 0.01 then
						self:_emitPulse(root.CFrame, Vector3.new(1.6, 1.6, 1.6), Color3.fromRGB(212, 248, 148), 0.38, 0.08)
						root.AssemblyLinearVelocity = burstDirection.Unit * self._missionConfig.Mission.RunnerBurstSpeed + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
						self:_emitPulse(root.CFrame, Vector3.new(2.4, 2.4, 2.4), Color3.fromRGB(192, 236, 124), 0.45, 0.1)
					end
				end

				if isBrute and targetDistance <= self._missionConfig.Mission.BruteImpactRadius and now >= bruteImpactReadyAt then
					bruteImpactReadyAt = now + self._missionConfig.Mission.BruteImpactCooldown
					self:_emitPulse(root.CFrame * CFrame.new(0, -1.2, 0), Vector3.new(3.2, 0.18, 3.2), Color3.fromRGB(224, 176, 112), 0.26, 0.12)
					self:_bruteImpact(zombie, root, scaledStats)
				end

				if isBoss then
					local healthRatio = humanoid.Health / math.max(1, humanoid.MaxHealth)
					local shouldEnrage = healthRatio <= self._missionConfig.Mission.BossEnrageThreshold
					if shouldEnrage ~= bossEnrageActive then
						bossEnrageActive = shouldEnrage
						self:_setBossEnrageState(zombie, bossEnrageActive)
						if bossEnrageActive then
							self:_notifyParty(mission.party, "Siege Tyrant is enraged.")
							self:_fireMissionState(mission.party, "Siege Tyrant enraged")
						end
					end

					local bossCooldownScale = bossEnrageActive and self._missionConfig.Mission.BossEnrageCooldownScale or 1
					if targetDistance <= self._missionConfig.Mission.BossSlamRadius and now >= bossSlamReadyAt then
						bossSlamReadyAt = now + (self._missionConfig.Mission.BossSlamCooldown * bossCooldownScale)
						self:_bossSlam(zombie, root, scaledStats)
					elseif now >= bossSummonReadyAt then
						bossSummonReadyAt = now + (self._missionConfig.Mission.BossSummonCooldown * bossCooldownScale)
						self:_bossSummonAdds(root, scaledStats)
					end
				end

				humanoid:MoveTo(targetRoot.Position)
				if targetDistance < (isBoss and 20 or 16) then
					local lungeDirection = targetRoot.Position - root.Position
					if lungeDirection.Magnitude > 0.01 then
						local bossLungeScale = bossEnrageActive and self._missionConfig.Mission.BossEnrageSpeedScale or 1
						root.AssemblyLinearVelocity = lungeDirection.Unit * ((isBoss and 18 or (isRunner and 22 or (isBrute and 10 or (isElite and 16 or 13)))) * bossLungeScale) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
					end
				end
			end

			task.wait(isBoss and 0.36 or (isRunner and 0.22 or (isBrute and 0.48 or (isElite and 0.42 or 0.3))))
		end
	end)

	local deathConnection
	deathConnection = humanoid.Died:Connect(function()
		touchConnection:Disconnect()
		if deathConnection then
			deathConnection:Disconnect()
		end

		if root and root.Parent then
			self:_emitZombieDeathEffect(root.Position, isBoss or isElite or isBrute, isRunner)
		end

		local mission = self._activeMission
		if mission then
			local contributors = self:_getZombieContributors(zombie)
			mission.remainingZombies = math.max(0, mission.remainingZombies - 1)
			if isBoss then
				for _, player in ipairs(mission.party) do
					if player and player.Parent then
						self:_awardLootDrops(player, "BossKill", 0.75)
						self:_emitProgressionUpdate(player)
					end
				end
			end

			for _, player in ipairs(contributors) do
				if player and player.Parent then
					self._persistenceService:IncrementStat(player, "zombiesDefeated", 1)
					if self._dailyOpsService then
						self._dailyOpsService:IncrementProgress(player, "ZombieKill", 1)
					end
					local runStats = self:_getRunStats(player)
					if runStats then
						runStats.kills += 1
					end
					local weaponXp = self._missionConfig.WeaponProgression.ZombieKillExperience or 0
					if isElite or isBrute then
						weaponXp += self._missionConfig.WeaponProgression.EliteKillBonus or 0
					end
					if isBoss then
						weaponXp += self._missionConfig.WeaponProgression.BossKillBonus or 0
					end
					local equippedWeaponId = self._inventoryService and self._inventoryService:GetEquippedWeaponId(player) or nil
					if equippedWeaponId and weaponXp > 0 then
						self._persistenceService:AddWeaponExperience(player, equippedWeaponId, weaponXp)
					end
					self:_awardMissionExperience(player, "ZombieKill", 5)
				end
			end

			self:_clearZombieDamageTracking(zombie)

			if mission.remainingZombies <= 0 then
				if mission.phase == "Combat" then
					self:_completeWave()
				end
			end
		end

		Debris:AddItem(zombie, 2)
	end)

	return zombie, aiThread
end

function MissionService:_createObjective(runtime)
	local anchor = self:_getMissionAnchorCFrame()
	local layout = self:_getActiveLayout()
	if not anchor or not layout then
		return nil
	end

	local core = Instance.new("Part")
	core.Name = "ObjectiveCore"
	core.Size = Vector3.new(8, 10, 8)
	core.Anchored = true
	core.CanCollide = true
	core.Material = Enum.Material.Metal
	core.Color = Color3.fromRGB(116, 153, 198)
	core.CFrame = anchor * CFrame.new(layout.ObjectiveOffset or Vector3.new(0, 5, 18))
	core.Parent = runtime
	core:SetAttribute("ObjectiveHealth", self._missionConfig.Mission.ObjectiveMaxHealth)
	core:SetAttribute("ObjectiveMaxHealth", self._missionConfig.Mission.ObjectiveMaxHealth)

	local shield = Instance.new("Part")
	shield.Name = "ObjectiveShield"
	shield.Anchored = true
	shield.CanCollide = false
	shield.CanQuery = false
	shield.Material = Enum.Material.ForceField
	shield.Color = Color3.fromRGB(146, 202, 255)
	shield.Transparency = 0.72
	shield.Shape = Enum.PartType.Ball
	shield.Size = Vector3.new(13, 13, 13)
	shield.CFrame = core.CFrame
	shield.Parent = runtime

	local glow = Instance.new("Part")
	glow.Name = "ObjectiveGlow"
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanQuery = false
	glow.Material = Enum.Material.Neon
	glow.Color = Color3.fromRGB(122, 200, 255)
	glow.Size = Vector3.new(12, 0.4, 12)
	glow.CFrame = core.CFrame * CFrame.new(0, -5.1, 0)
	glow.Parent = runtime

	local marker, _ = self:_createWorldMarker(runtime, "ObjectiveMarker", "DEFEND CORE", Color3.fromRGB(184, 228, 255), Vector2.new(156, 30), 14)
	marker.CFrame = core.CFrame * CFrame.new(0, 7.2, 0)
	local objectiveGui = marker:FindFirstChildOfClass("BillboardGui")
	if objectiveGui then
		objectiveGui.MaxDistance = 42
	end
	if self:_isPowerCellScenario() then
		self:_spawnPowerCellObjective(runtime, core)
	elseif self:_isNestScenario() then
		self:_spawnNestObjective(runtime, core)
	end
	self:_refreshObjectiveVisuals()

	local hitCooldown = {}
	core.Touched:Connect(function(hit)
		local zombie = hit and hit.Parent
		if not zombie or zombie.Parent ~= self._activeMission.zombiesFolder then
			return
		end

		local now = os.clock()
		if hitCooldown[zombie] and now - hitCooldown[zombie] < 1 then
			return
		end
		hitCooldown[zombie] = now

		local damage = zombie:GetAttribute("ObjectiveDamage") or 5
		self:_damageObjective(damage)
	end)

	return core
end

function MissionService:_createExtractionPad(runtime)
	local anchor = self:_getMissionAnchorCFrame()
	local layout = self:_getActiveLayout()
	if not anchor or not layout then
		return nil
	end

	local pad = Instance.new("Part")
	pad.Name = "ExtractionPad"
	pad.Size = Vector3.new(28, 1, 28)
	pad.Anchored = true
	pad.CanCollide = true
	pad.Material = Enum.Material.Neon
	pad.Color = Color3.fromRGB(110, 223, 185)
	pad.Transparency = 0.18
	pad.CFrame = anchor * CFrame.new(layout.ExtractionOffset or Vector3.new(0, -0.3, -26))
	pad.Parent = runtime

	local ring = Instance.new("Part")
	ring.Name = "ExtractionRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(167, 248, 215)
	ring.Transparency = 0.58
	ring.Size = Vector3.new(36, 0.12, 36)
	ring.CFrame = pad.CFrame * CFrame.new(0, 0.1, 0)
	ring.Parent = runtime

	local labelPart, _ = self:_createWorldMarker(runtime, "ExtractionSign", "EXTRACT", Color3.fromRGB(195, 255, 236), Vector2.new(140, 34), 16)
	labelPart.CFrame = pad.CFrame * CFrame.new(0, 6, 0)
	local labelGui = labelPart:FindFirstChildOfClass("BillboardGui")
	if labelGui then
		labelGui.MaxDistance = 64
	end

	return pad
end

function MissionService:_setExtractionVisualState(progress)
	local pad = self:_getExtractionPad()
	if not pad then
		return
	end

	local runtime = pad.Parent
	local ring = runtime and runtime:FindFirstChild("ExtractionRing")
	local sign = runtime and runtime:FindFirstChild("ExtractionSign")
	local label = sign and sign:FindFirstChildOfClass("BillboardGui")
	local frame = label and label:FindFirstChildOfClass("Frame")
	local text = frame and frame:FindFirstChild("Label")

	local clamped = math.clamp(progress or 0, 0, 1)
	pad.Color = Color3.fromRGB(110, 223, 185):Lerp(Color3.fromRGB(210, 255, 233), clamped)
	pad.Transparency = 0.18 - (clamped * 0.08)

	if ring and ring:IsA("BasePart") then
		ring.Color = Color3.fromRGB(167, 248, 215):Lerp(Color3.fromRGB(228, 255, 240), clamped)
		ring.Transparency = 0.58 - (clamped * 0.22)
	end

	if text and text:IsA("TextLabel") then
		text.Text = clamped > 0 and ("EXTRACT %d%%"):format(math.floor(clamped * 100)) or "EXTRACT"
	end
end

function MissionService:_emitObjectiveHitEffect()
	local objective = self:_getMissionObjective()
	if not objective then
		return
	end

	local runtime = objective.Parent
	local flash = self:_emitPulse(objective.CFrame, Vector3.new(11, 11, 11), Color3.fromRGB(255, 120, 120), 0.58, 0.14)
	if flash then
		flash.Material = Enum.Material.ForceField
		flash.Shape = Enum.PartType.Ball
		flash.Parent = runtime or Workspace
	end

	local glow = runtime and runtime:FindFirstChild("ObjectiveGlow")
	if glow and glow:IsA("BasePart") then
		glow.Size = Vector3.new(15, 0.45, 15)
		task.delay(0.14, function()
			if glow and glow.Parent then
				glow.Size = Vector3.new(12, 0.4, 12)
			end
		end)
	end
end

function MissionService:_damageObjective(amount)
	local mission = self._activeMission
	local objective = self:_getMissionObjective()
	if not mission or not objective then
		return
	end

	local current = objective:GetAttribute("ObjectiveHealth") or self._missionConfig.Mission.ObjectiveMaxHealth
	local previous = current
	current = math.max(0, current - amount)
	objective:SetAttribute("ObjectiveHealth", current)
	self:_emitObjectiveHitEffect()
	self:_refreshObjectiveVisuals()
	self:_fireMissionState(mission.party, ("Core integrity: %d%%"):format(math.floor((current / self._missionConfig.Mission.ObjectiveMaxHealth) * 100)))
	mission.objectiveWarningThresholds = mission.objectiveWarningThresholds or {}
	for _, threshold in ipairs({ 75, 50, 25, 10 }) do
		local previousPercent = math.floor((previous / self._missionConfig.Mission.ObjectiveMaxHealth) * 100)
		local currentPercent = math.floor((current / self._missionConfig.Mission.ObjectiveMaxHealth) * 100)
		if previousPercent > threshold and currentPercent <= threshold and not mission.objectiveWarningThresholds[threshold] then
			mission.objectiveWarningThresholds[threshold] = true
			self:_notifyParty(mission.party, ("Warning: core integrity critical at %d%%."):format(currentPercent))
		end
	end

	if current <= 0 then
		self:_failMission("The bunker core was destroyed.")
	end
end

function MissionService:_hasAnyLivingPlayers()
	for _, player in ipairs(self:_getLivePartyMembers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not self:_isCharacterDowned(character) then
			return true
		end
	end
	return false
end

function MissionService:_bindMissionCharacterState(player)
	local mission = self._activeMission
	if not mission then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local healthConnection
	healthConnection = humanoid.HealthChanged:Connect(function(health)
		if not self._activeMission or self._activeMission ~= mission then
			return
		end
		if health > 0 or self:_isCharacterDowned(character) or (character and character:GetAttribute("BleedoutFinalizing")) then
			return
		end

		local droppedCellId = self:_clearCarriedPowerCell(player)
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local runtime = mission.runtime
		if droppedCellId and runtime and rootPart and self:_isPowerCellScenario(mission) then
			self:_spawnPowerCell(runtime, rootPart.Position + Vector3.new(0, 0, -3), droppedCellId)
		end

		self:_enterDownedState(player, mission, character, humanoid)
		if not self:_hasAnyLivingPlayers() then
			self:_failMission("The squad was overrun.")
		end
	end)

	table.insert(mission.connections, healthConnection)
end

function MissionService:_cleanupPlayerMissionTools(player)
	self._weaponState[player.UserId] = nil
	self:_clearCarriedPowerCell(player)
	self:_clearDownedState(player, false)
	player:SetAttribute("MissionEliminated", false)
	player:SetAttribute("MissionMedkits", 0)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		local tool = backpack:FindFirstChild("MissionWeapon")
		if tool then
			tool:Destroy()
		end
		local fistsTool = backpack:FindFirstChild("MissionFists")
		if fistsTool then
			fistsTool:Destroy()
		end
		local medkitTool = backpack:FindFirstChild("MissionMedkit")
		if medkitTool then
			medkitTool:Destroy()
		end
		local dashTool = backpack:FindFirstChild("MissionDash")
		if dashTool then
			dashTool:Destroy()
		end
	end

	local character = player.Character
	if character then
		local equipped = character:FindFirstChild("MissionWeapon")
		if equipped then
			equipped:Destroy()
		end
		local fistsEquipped = character:FindFirstChild("MissionFists")
		if fistsEquipped then
			fistsEquipped:Destroy()
		end
		local medkitEquipped = character:FindFirstChild("MissionMedkit")
		if medkitEquipped then
			medkitEquipped:Destroy()
		end
		local dashEquipped = character:FindFirstChild("MissionDash")
		if dashEquipped then
			dashEquipped:Destroy()
		end
		character:SetAttribute("MissionDashing", false)
		local highlight = character:FindFirstChild("EquippedCosmeticHighlight")
		if highlight then
			highlight:Destroy()
		end
	end
end

function MissionService:_grantAmmoPickup(player)
	local state = self._weaponState[player.UserId]
	if not state then
		return false
	end

	local weapon = self._inventoryService:GetWeaponDefinition(state.weaponId)
	if weapon.WeaponType == "Melee" then
		return false
	end

	state.reserveAmmo += self._missionConfig.Mission.AmmoPickupAmount
	if self._skillTreeService then
		state.reserveAmmo += math.max(0, self._skillTreeService:GetAmmoPickupAmount(player, self._missionConfig.Mission.AmmoPickupAmount) - self._missionConfig.Mission.AmmoPickupAmount)
	end
	self:_fireMissionState({ player }, "Ammo cache secured")
	return true
end

function MissionService:_createSupplyPickup(runtime, pickupType, position)
	local pickup = Instance.new("Part")
	pickup.Name = pickupType == "Ammo" and "AmmoCache" or (pickupType == "Medkit" and "MedkitBag" or "SalvageCrate")
	pickup.Size = Vector3.new(4, 4, 4)
	pickup.Anchored = true
	pickup.CanCollide = true
	pickup.Material = Enum.Material.Metal
	pickup.Color = pickupType == "Ammo" and Color3.fromRGB(92, 170, 226) or (pickupType == "Medkit" and Color3.fromRGB(112, 198, 136) or Color3.fromRGB(226, 176, 92))
	pickup.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))
	pickup.Parent = runtime

	local glow = Instance.new("Part")
	glow.Name = pickup.Name .. "Glow"
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanQuery = false
	glow.Material = Enum.Material.Neon
	glow.Color = pickup.Color
	glow.Transparency = 0.2
	glow.Size = Vector3.new(5.5, 0.25, 5.5)
	glow.CFrame = pickup.CFrame * CFrame.new(0, -2.1, 0)
	glow.Parent = runtime

	local markerText = pickupType == "Ammo" and "AMMO" or (pickupType == "Medkit" and "MEDKIT" or "SALVAGE")
	local markerColor = pickupType == "Ammo" and Color3.fromRGB(184, 226, 255) or (pickupType == "Medkit" and Color3.fromRGB(196, 255, 210) or Color3.fromRGB(255, 222, 164))
	local marker, _ = self:_createWorldMarker(runtime, pickup.Name .. "Marker", markerText, markerColor, Vector2.new(120, 30), 14)
	marker.CFrame = pickup.CFrame * CFrame.new(0, 4.6, 0)
	local markerGui = marker:FindFirstChildOfClass("BillboardGui")
	if markerGui then
		markerGui.MaxDistance = pickupType == "Salvage" and 20 or 26
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = pickupType == "Ammo" and "Refill Ammo" or (pickupType == "Medkit" and "Take Medkit" or "Collect Salvage")
	prompt.ObjectText = pickupType == "Ammo" and "Ammo Cache" or (pickupType == "Medkit" and "Field Medkit" or "Salvage Crate")
	prompt:SetAttribute("MissionPrompt", true)
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = pickup

	prompt.Triggered:Connect(function(player)
		if not self._activeMission or not player or player.Parent ~= Players then
			return
		end

		if pickupType == "Ammo" then
			if self:_grantAmmoPickup(player) then
				self:_notifyParty({ player }, "Ammo cache secured.")
				pickup:Destroy()
				glow:Destroy()
				marker:Destroy()
			end
		elseif pickupType == "Medkit" then
			if self:_grantMedkitPickup(player) then
				self:_notifyParty({ player }, "Field medkit secured.")
				pickup:Destroy()
				glow:Destroy()
				marker:Destroy()
			end
		else
			local salvageAmount = self._skillTreeService and self._skillTreeService:GetSalvagePickupAmount(player, self._missionConfig.Mission.TokenPickupAmount) or self._missionConfig.Mission.TokenPickupAmount
			local rewardAmount = salvageAmount
			if self._subscriptionService then
				rewardAmount = self._subscriptionService:GetAdjustedTokenRewardAmount(player, rewardAmount)
			end
			self._tokenService:AddTokens(player, rewardAmount, "MissionReward", "salvage_pickup")
			self:_notifyParty({ player }, ("Salvage collected: +%d tokens."):format(rewardAmount))
			pickup:Destroy()
			glow:Destroy()
			marker:Destroy()
		end
	end)

	return pickup
end

function MissionService:_spawnSupplyDrops(runtime)
	local layout = self:_getActiveLayout()
	local modifier = self:_getActiveModifier()
	local modifierTraits = self:_getModifierRuntimeTraits()
	if not layout then
		return
	end

	local supplyOffsets = layout.SupplyOffsets or {
		Vector3.new(24, 0, -10),
		Vector3.new(-24, 0, -12),
	}
	self:_createSupplyPickup(runtime, "Ammo", self:_getLayoutWorldPosition(supplyOffsets[1]))
	self:_createSupplyPickup(runtime, "Salvage", self:_getLayoutWorldPosition(supplyOffsets[2]))
	self:_createSupplyPickup(runtime, "Medkit", self:_getLayoutWorldPosition(Vector3.new(0, 0, 10)))

	if modifier and (modifier.ExtraSupplyDrops or 0) > 0 then
		local bonusOffsets = {
			Vector3.new(18, 0, 22),
			Vector3.new(-18, 0, 22),
			Vector3.new(24, 0, -20),
			Vector3.new(-24, 0, -20),
		}
		for index = 1, math.min(modifier.ExtraSupplyDrops, #bonusOffsets) do
			local pickupType = (index % 2 == 1) and "Salvage" or "Ammo"
			self:_createSupplyPickup(runtime, pickupType, self:_getLayoutWorldPosition(bonusOffsets[index]))
		end
	end

	if modifierTraits.BonusSupplyPickup then
		local bonusOffset = modifierTraits.BonusSupplyPickup == "Ammo" and Vector3.new(0, 0, -24) or Vector3.new(0, 0, 24)
		self:_createSupplyPickup(runtime, modifierTraits.BonusSupplyPickup, self:_getLayoutWorldPosition(bonusOffset))
	end
end

function MissionService:_finalizeMissionRuntime(mission)
	self:_clearRuntime()
	for _, connection in ipairs(mission.connections) do
		connection:Disconnect()
	end
	self._activeMission = nil
end

function MissionService:FinalizePendingInstanceReturn()
	local mission = self._activeMission
	if not mission or mission.phase ~= "Returning" then
		return false
	end
	self:_finalizeMissionRuntime(mission)
	return true
end

function MissionService:FailPendingInstanceReturn()
	local mission = self._activeMission
	if not mission or mission.phase ~= "Returning" then
		return false
	end
	mission.phase = "ReturnFailed"
	self:_fireMissionState(mission.party, "Lobby return failed")
	self:_notifyParty(mission.party, "Lobby return failed. Retry or rejoin the lobby.")
	if (mission.returnRetryCount or 0) < 1 then
		mission.returnRetryCount = (mission.returnRetryCount or 0) + 1
		task.delay(3, function()
			if self._activeMission ~= mission or mission.phase ~= "ReturnFailed" then
				return
			end
			self:_notifyParty(mission.party, "Retrying lobby return...")
			self:_fireMissionState(mission.party, "Retrying lobby return")
			self:_tryReturnInstancePartyToLobby(
				mission,
				mission.pendingReturnStatus or "Back in the bunker.",
				mission.pendingReturnFailureState or "Lobby return failed"
			)
		end)
	end
	return true
end

function MissionService:_tryReturnInstancePartyToLobby(mission, status, failureState)
	if not (self._instanceDeploymentService and self._instanceDeploymentService:IsMissionInstanceServer()) then
		return false
	end

	mission.phase = "Returning"
	mission.pendingReturnStatus = status
	mission.pendingReturnFailureState = failureState
	local ok = self._instanceDeploymentService:ReturnPartyToLobby(mission.party, status)
	if ok then
		self:_fireMissionState(mission.party, "Returning to lobby")
		return true
	end

	self:_notifyParty(mission.party, "Lobby return failed. Stay in the server and retry or rejoin.")
	self:_fireMissionState(mission.party, failureState or "Lobby return failed")
	return true
end

function MissionService:_finishAndReturnToLobby(mission, status)
	task.delay(self._missionConfig.Mission.ReturnToLobbyDelay, function()
		if self:_tryReturnInstancePartyToLobby(mission, status, "Lobby return failed") then
			return
		end

		local lobbySpawn = self:_getLobbySpawn()
		for _, player in ipairs(mission.party) do
			if player and player.Parent then
				self:_cleanupPlayerMissionTools(player)

				local character = player.Character
				if character and lobbySpawn then
					character:PivotTo(lobbySpawn.CFrame + Vector3.new(0, 4, 0))
				end
			end
		end

		self:_finalizeMissionRuntime(mission)
		self._flowService:ReturnPlayersToLobby(mission.party, status)
	end)
end

function MissionService:AbortActiveMission(status)
	local mission = self._activeMission
	if not mission then
		return false, "no_active_mission"
	end

	if self:_tryReturnInstancePartyToLobby(mission, status or "Run aborted. Back in the bunker.", "Abort return failed") then
		self:_notifyParty(mission.party, status or "Run aborted. Returning to bunker.")
		return true
	end

	local lobbySpawn = self:_getLobbySpawn()
	for _, player in ipairs(mission.party) do
		if player and player.Parent then
			self:_cleanupPlayerMissionTools(player)
			local character = player.Character
			if character and lobbySpawn then
				character:PivotTo(lobbySpawn.CFrame + Vector3.new(0, 4, 0))
			end
		end
	end

	self:_finalizeMissionRuntime(mission)
	self._flowService:ReturnPlayersToLobby(mission.party, status or "Run aborted. Back in the bunker.")
	self:_notifyParty(mission.party, status or "Run aborted. Returning to bunker.")
	return true
end

function MissionService:_failMission(reason)
	local mission = self._activeMission
	if not mission then
		return
	end

	self:_rewardParty(self._missionConfig.Mission.FailureReward, "mission_fail")
	for _, player in ipairs(mission.party) do
		if player and player.Parent then
			self:_awardMissionExperience(player, "MissionFailure", 12)
		end
	end
	self:_notifyResults(mission, false, reason, self._missionConfig.Mission.FailureReward)
	self:_notifyParty(mission.party, reason .. " Returning to bunker.")
	self:_fireMissionState(mission.party, "Mission failed")
	self:_finishAndReturnToLobby(mission, "Mission failed. Back in the bunker.")
end

function MissionService:_spawnWave()
	local mission = self._activeMission
	if not mission then
		return
	end

	mission.wave += 1
	local missionSpawn = self:_getMissionSpawn()
	if not missionSpawn then
		return
	end
	local layout = self:_getActiveLayout()
	local modifier = self:_getActiveModifier()

	local scenario = mission.scenario or self._missionConfig.getScenario(1)
	local baseSpawnCount = self._missionConfig.Mission.BaseZombieCount
		+ ((mission.wave - 1) * self._missionConfig.Mission.ExtraZombiesPerWave)
		+ (scenario.ExtraSpawnBonus or 0)
		+ (modifier and modifier.ExtraSpawnBonus or 0)
	local scaledStats = self._scalingService:ScaleEnemyStats({
		health = math.floor((self._missionConfig.Mission.ZombieBaseHealth + ((mission.wave - 1) * 10)) * (scenario.HealthScale or 1) * (modifier and modifier.HealthScale or 1)),
		damage = math.floor((self._missionConfig.Mission.ZombieBaseDamage + (mission.wave - 1)) * (scenario.DamageScale or 1) * (modifier and modifier.DamageScale or 1)),
		spawnCount = baseSpawnCount,
	}, #mission.party)

	mission.remainingZombies = scaledStats.spawnCount
	local runnerCount = 0
	local bruteCount = 0
	local bossCount = 0
	local runnerStep = clampPositiveInteger(modifier and modifier.RunnerStep or 3, 3)
	local bruteStep = clampPositiveInteger(modifier and modifier.BruteStep or 4, 4)
	for index = 1, scaledStats.spawnCount do
		local willBeBoss = index == scaledStats.spawnCount and mission.wave >= self._missionConfig.Mission.WaveCount
		local willBeBrute = not willBeBoss and mission.wave >= 3 and index % bruteStep == 0
		local willBeRunner = not willBeBoss and not willBeBrute and mission.wave >= 2 and index % runnerStep == 0
		if willBeBoss then
			bossCount += 1
		elseif willBeBrute then
			bruteCount += 1
		elseif willBeRunner then
			runnerCount += 1
		end
	end

	local mixParts = {}
	if runnerCount > 0 then
		table.insert(mixParts, ("%d runners"):format(runnerCount))
	end
	if bruteCount > 0 then
		table.insert(mixParts, ("%d brutes"):format(bruteCount))
	end
	if bossCount > 0 then
		table.insert(mixParts, ("%d boss"):format(bossCount))
	end

	local mixSummary = #mixParts > 0 and (" Mix: " .. table.concat(mixParts, ", ") .. ".") or ""
	local modifierSummary = modifier and modifier.DisplayName ~= "Standard Ops" and (" Condition: " .. modifier.DisplayName .. ".") or ""
	self:_notifyParty(mission.party, ("%s: Wave %d incoming with %d infected.%s%s"):format(scenario.DisplayName, mission.wave, scaledStats.spawnCount, mixSummary, modifierSummary))
	self:_fireMissionState(mission.party, ("Wave %d/%d"):format(mission.wave, self._missionConfig.Mission.WaveCount))
	if bossCount > 0 then
		self:_notifyParty(mission.party, "Boss contact: Siege Tyrant detected.")
		self:_fireMissionState(mission.party, "Boss wave: Siege Tyrant")
	end

	for index = 1, scaledStats.spawnCount do
		local spawnOffsets = layout and layout.SpawnOffsets or nil
		if spawnOffsets and #spawnOffsets > 0 then
			local baseOffset = spawnOffsets[((index - 1) % #spawnOffsets) + 1]
			local jitter = Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
			self:_spawnZombie(self:_getLayoutWorldPosition(baseOffset + jitter), scaledStats, index)
		else
			local angle = (math.pi * 2 / scaledStats.spawnCount) * index
			local radius = self._missionConfig.Mission.ZombieSpawnRadius + math.random(-6, 6)
			local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			self:_spawnZombie(missionSpawn.Position + offset, scaledStats, index)
		end
	end

	self:_scheduleWaveSurge(mission, scaledStats)
end

function MissionService:_scheduleWaveSurge(mission, scaledStats)
	if not mission or mission.phase ~= "Combat" then
		return
	end

	local startWave = self._missionConfig.Mission.WaveSurgeStartWave or 2
	local modifier = self:_getActiveModifier()
	local modifierTraits = self:_getModifierRuntimeTraits()
	startWave = math.max(1, startWave + (modifier and modifier.SurgeStartWaveOffset or 0))
	if mission.wave < startWave or mission.wave >= self._missionConfig.Mission.WaveCount then
		return
	end

	local waveSurgeDelay = self._missionConfig.Mission.WaveSurgeDelay * modifierTraits.WaveSurgeDelayScale
	task.delay(waveSurgeDelay, function()
		if not self._activeMission or self._activeMission ~= mission then
			return
		end
		if mission.phase ~= "Combat" or mission.remainingZombies <= 0 then
			return
		end

		local liveParty = self:_getLivePartyMembers()
		local partyBonus = math.floor(math.max(0, #liveParty - 1) / 2)
		local surgeCount = math.max(1, (self._missionConfig.Mission.WaveSurgeBaseCount or 2) + partyBonus + (modifier and modifier.WaveSurgeBonus or 0))
		local layout = self:_getActiveLayout()
		local anchor = self:_getMissionSpawn()
		if not anchor then
			return
		end

		local surgeStats = {
			health = math.max(1, math.floor((scaledStats.health or self._missionConfig.Mission.ZombieBaseHealth) * self._missionConfig.Mission.WaveSurgeHealthScale)),
			damage = math.max(1, math.floor((scaledStats.damage or self._missionConfig.Mission.ZombieBaseDamage) * self._missionConfig.Mission.WaveSurgeDamageScale)),
			spawnCount = surgeCount,
		}

		mission.remainingZombies += surgeCount

		self:_notifyParty(mission.party, "Pressure spike: reinforcements inbound.")
		self:_fireMissionState(mission.party, "Breach surge")

		for index = 1, surgeCount do
			if not self._activeMission or self._activeMission ~= mission or mission.phase ~= "Combat" or mission.remainingZombies <= 0 then
				return
			end

			local spawnPosition
			local spawnOffsets = layout and layout.SpawnOffsets or nil
			if spawnOffsets and #spawnOffsets > 0 then
				local baseOffset = spawnOffsets[((index + mission.wave - 1) % #spawnOffsets) + 1]
				local jitter = Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
				spawnPosition = self:_getLayoutWorldPosition(baseOffset + jitter)
			else
				local angle = (math.pi * 2 / surgeCount) * index
				local radius = self._missionConfig.Mission.ZombieSpawnRadius + 8 + math.random(-4, 4)
				local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
				spawnPosition = anchor.Position + offset
			end

			self:_spawnZombie(spawnPosition, surgeStats, scaledStats.spawnCount + index)
		end
	end)
end

function MissionService:_rewardParty(amount, reason)
	local mission = self._activeMission
	if not mission then
		return
	end

	for _, player in ipairs(mission.party) do
		if player and player.Parent then
			local rewardAmount = amount + (self._skillTreeService and self._skillTreeService:GetRewardBonus(player) or 0)
			if self._subscriptionService then
				rewardAmount = self._subscriptionService:GetAdjustedTokenRewardAmount(player, rewardAmount)
			end
			if self._gamePassService then
				rewardAmount = math.max(0, math.floor((rewardAmount * self._gamePassService:GetTokenRewardMultiplier(player)) + 0.5))
			end
			self._tokenService:AddTokens(player, rewardAmount, "MissionReward", reason)
		end
	end
end

function MissionService:_completeMission()
	local mission = self._activeMission
	if not mission then
		return
	end

	if mission.phase == "Extraction" then
		return
	end

	mission.phase = "Extraction"
	mission.extractionStartedAt = nil
	self:_notifyParty(mission.party, "All waves cleared. Regroup on the extraction pad.")
	self:_fireMissionState(mission.party, "Objective: reach extraction")

	task.spawn(function()
		while self._activeMission == mission and mission.phase == "Extraction" do
			local pad = self:_getExtractionPad()
			if not pad then
				task.wait(0.5)
				continue
			end

			local livePlayers = 0
			local insidePlayers = 0
			for _, player in ipairs(self:_getLivePartyMembers()) do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				if humanoid and humanoid.Health > 0 and rootPart and not self:_isCharacterDowned(character) then
					livePlayers += 1
					if self:_isCharacterInsideExtractionPad(rootPart, pad) then
						insidePlayers += 1
					end
				end
			end

			if livePlayers == 0 then
				self:_failMission("The squad was overrun.")
				return
			end

			local requiredInside = livePlayers
			if livePlayers >= 3 then
				requiredInside = livePlayers - 1
			end
			local allInside = insidePlayers >= requiredInside

			if allInside then
				mission.extractionStartedAt = mission.extractionStartedAt or os.clock()
				local extractionHold = self:_getExtractionHoldDuration(mission.party)
				local remaining = math.max(0, extractionHold - (os.clock() - mission.extractionStartedAt))
				local progress = 1 - (remaining / extractionHold)
				self:_setExtractionVisualState(progress)
				self:_fireMissionState(mission.party, ("Extracting in %ds"):format(math.ceil(remaining)))
				if remaining <= 0 then
					local rewardBonus = (mission.scenario and mission.scenario.RewardBonus or 0) + (mission.modifier and mission.modifier.RewardBonus or 0)
					local completionReward = self._missionConfig.Mission.CompletionReward + rewardBonus
					self:_rewardParty(completionReward, "mission_complete")
					for _, player in ipairs(mission.party) do
						if player and player.Parent then
							self._persistenceService:IncrementStat(player, "missionsCompleted", 1)
							if self._dailyOpsService then
								self._dailyOpsService:IncrementProgress(player, "MissionComplete", 1)
								if #mission.party > 1 then
									self._dailyOpsService:IncrementProgress(player, "SquadMissionComplete", 1)
								end
							end
							self:_awardMissionExperience(player, "MissionComplete", 40)
							self:_awardLootDrops(player, "MissionComplete", 1)
							self:_emitProgressionUpdate(player)
						end
					end
					self:_notifyResults(mission, true, "Extraction complete. Squad returned to bunker.", completionReward)
					self:_notifyParty(mission.party, "Extraction complete. Returning to the bunker.")
					self:_fireMissionState(mission.party, "Extraction complete")
					self:_finishAndReturnToLobby(mission, "Back in the bunker.")
					return
				end
			else
				mission.extractionStartedAt = nil
				self:_setExtractionVisualState(0)
				self:_fireMissionState(mission.party, ("Objective: regroup on extraction (%d/%d)"):format(insidePlayers, requiredInside))
			end

			task.wait(0.35)
		end
	end)
end

function MissionService:_completeWave()
	local mission = self._activeMission
	if not mission or mission.phase ~= "Combat" then
		return
	end

	self:_rewardParty(self._missionConfig.Mission.WaveReward, "wave_clear")
	for _, player in ipairs(mission.party) do
		if player and player.Parent then
			self:_awardMissionExperience(player, "WaveClear", 18)
			self:_awardLootDrops(player, "WaveClear", 0.35)
			self:_emitProgressionUpdate(player)
		end
	end

	if mission.wave >= self._missionConfig.Mission.WaveCount then
		if self:_isPowerCellScenario(mission) then
			local objective = self:_getMissionObjective()
			local delivered = objective and objective:GetAttribute("DeliveredPowerCells") or 0
			local required = objective and objective:GetAttribute("RequiredPowerCells") or self._missionConfig.Mission.PowerCellRequiredCount
			if delivered < required then
				self:_notifyParty(mission.party, ("Waves cleared. Deliver the remaining power cells (%d/%d) to unlock extraction."):format(delivered, required))
				self:_fireMissionState(mission.party, ("Objective: deliver power cells %d/%d"):format(delivered, required))
				return
			end
		elseif self:_isNestScenario(mission) then
			local objective = self:_getMissionObjective()
			local destroyed = objective and objective:GetAttribute("DestroyedNests") or 0
			local required = objective and objective:GetAttribute("RequiredNests") or self._missionConfig.Mission.NestRequiredCount
			if destroyed < required then
				self:_notifyParty(mission.party, ("Waves cleared. Burn the remaining nests (%d/%d) to unlock extraction."):format(destroyed, required))
				self:_fireMissionState(mission.party, ("Objective: destroy nests %d/%d"):format(destroyed, required))
				return
			end
		end
		self:_completeMission()
		return
	end

	self:_notifyParty(mission.party, ("Wave %d cleared. Next wave in %ds."):format(mission.wave, self._missionConfig.Mission.InterWaveDelay))
	task.delay(self._missionConfig.Mission.InterWaveDelay, function()
		if self._activeMission == mission then
			self:_spawnWave()
		end
	end)
end

function MissionService:StartMission(request)
	self:_clearRuntime()

	local runtime = self:_createRuntimeFolder()
	if not runtime then
		return false, "missing_runtime"
	end

	local zombiesFolder = Instance.new("Folder")
	zombiesFolder.Name = "Zombies"
	zombiesFolder.Parent = runtime

	self._activeMission = {
		party = request.party,
		profile = request.profile,
		scenario = findMissionEntryById(self._missionConfig.Scenarios, request.preview and request.preview.scenarioId, self._missionConfig.getScenario()),
		layout = findMissionEntryById(self._missionConfig.Layouts, request.preview and request.preview.layoutId, self._missionConfig.getLayout()),
		modifier = findMissionEntryById(self._missionConfig.MissionModifiers, request.preview and request.preview.modifierId, self._missionConfig.getModifier and self._missionConfig.getModifier()),
		runtime = runtime,
		zombiesFolder = zombiesFolder,
		wave = 0,
		remainingZombies = 0,
		phase = "Combat",
		hazardCooldowns = {},
		connections = {},
		downedStates = {},
		zombieDamageByZombie = setmetatable({}, { __mode = "k" }),
		zombieLastHitByZombie = setmetatable({}, { __mode = "k" }),
		runStats = {},
		returnRetryCount = 0,
		pendingReturnStatus = nil,
		pendingReturnFailureState = nil,
	}
	self:_decorateMissionRuntime(runtime)
	self:_createObjective(runtime)
	self:_createExtractionPad(runtime)
	self:_spawnSupplyDrops(runtime)
	self:_spawnHazardZones(runtime)

	for _, player in ipairs(request.party) do
		if player and player.Parent then
			player:SetAttribute("InMission", true)
			player:SetAttribute("MissionEliminated", false)
			self:_bindCharacter(player)
			self:_equipPlayer(player)
			self:_bindMissionCharacterState(player)
		end
	end

	local modifierText = self._activeMission.modifier and self._activeMission.modifier.DisplayName or "Standard Ops"
	local modifierDescription = self._activeMission.modifier and self._activeMission.modifier.Description or ""
	if self:_isPowerCellScenario(self._activeMission) then
		self:_notifyParty(request.party, ("Mission started in %s [%s]. Defend the relay, recover power cells, and survive the waves. %s"):format(self._activeMission.layout.DisplayName, modifierText, modifierDescription))
		self:_fireMissionState(request.party, self:_getObjectiveStateText(self._activeMission))
	elseif self:_isNestScenario(self._activeMission) then
		self:_notifyParty(request.party, ("Mission started in %s [%s]. Defend the relay, hunt infected nests, and survive the waves. %s"):format(self._activeMission.layout.DisplayName, modifierText, modifierDescription))
		self:_fireMissionState(request.party, self:_getObjectiveStateText(self._activeMission))
	else
		self:_notifyParty(request.party, ("Mission started in %s [%s]. Defend the bunker core and survive the waves. %s"):format(self._activeMission.layout.DisplayName, modifierText, modifierDescription))
		self:_fireMissionState(request.party, self:_getObjectiveStateText(self._activeMission))
	end
	task.delay(2, function()
		if self._activeMission then
			self:_spawnWave()
		end
	end)

	return true
end

return MissionService
