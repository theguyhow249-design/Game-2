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

function MissionService:_getExtractionPads()
	local mission = self:_getMissionModel()
	local runtime = mission and mission:FindFirstChild("MissionRuntime")
	if not runtime then
		return {}
	end

	local pads = {}
	local primary = runtime:FindFirstChild("ExtractionPad")
	local secondary = runtime:FindFirstChild("ExtractionPadB")
	if primary and primary:IsA("BasePart") then
		table.insert(pads, primary)
	end
	if secondary and secondary:IsA("BasePart") then
		table.insert(pads, secondary)
	end
	return pads
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

function MissionService:_getExtractionVariant(mission)
	local currentMission = mission or self._activeMission
	if self:_isEvacEscortScenario(currentMission) then
		return "moving"
	end
	if self:_isPowerCellScenario(currentMission) then
		return "split"
	end
	return "standard"
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
	return mission and (
		mission:FindFirstChild("MissionSpawn", true)
		or mission:FindFirstChild("DropMarker", true)
		or mission:FindFirstChild("Base", true)
	)
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
	if self._skillTreeService then
		protectionSeconds = self._skillTreeService:GetSpawnProtectionSeconds(player, protectionSeconds)
	end
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

function MissionService:_isPowerRelayScenario(mission)
	local currentMission = mission or self._activeMission
	return currentMission and currentMission.scenario and currentMission.scenario.ObjectiveType == "PowerRelay"
end

function MissionService:_isEvacEscortScenario(mission)
	local currentMission = mission or self._activeMission
	return currentMission and currentMission.scenario and currentMission.scenario.ObjectiveType == "EvacEscort"
end

function MissionService:_isCommanderHuntScenario(mission)
	local currentMission = mission or self._activeMission
	return currentMission and currentMission.scenario and currentMission.scenario.ObjectiveType == "CommanderHunt"
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

	local scenarioBonus = mission.scenario and (mission.scenario.RewardBonus or 0) or 0
	local modifierBonus = mission.modifier and (mission.modifier.RewardBonus or 0) or 0
	local activeSeasonalEvent, seasonalTokenBonus = self:_getActiveSeasonalMissionBonus()
	local finalePlan = self:_getExtractionFinalePlan(mission)
	local objectiveType = mission.scenario and mission.scenario.ObjectiveType or "CoreDefense"

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
				objectiveType = objectiveType,
				layoutName = mission.layout and mission.layout.DisplayName or "Mission Arena",
				modifierName = mission.modifier and mission.modifier.DisplayName or "Standard Ops",
				finaleLabel = finalePlan and finalePlan.label or "Extraction breach detected",
				wave = mission.wave or 0,
				totalWaves = self._missionConfig.Mission.WaveCount,
				kills = runStats and runStats.kills or (stats and stats.zombiesDefeated or 0),
				xpGained = runStats and runStats.xpGained or 0,
				xpBreakdown = runStats and runStats.xpBreakdown or {},
				specialKills = runStats and runStats.specialKills or {},
				bossesDefeated = runStats and runStats.bossesDefeated or 0,
				bossName = runStats and runStats.lastBossName or nil,
				rewardBreakdown = {
					scenarioBonus = scenarioBonus,
					modifierBonus = modifierBonus,
					seasonalBonus = seasonalTokenBonus,
					seasonalEventName = activeSeasonalEvent and activeSeasonalEvent.DisplayName or nil,
					waveReward = self._missionConfig.Mission.WaveReward,
					completionReward = success and (self._missionConfig.Mission.CompletionReward + scenarioBonus + modifierBonus + seasonalTokenBonus) or self._missionConfig.Mission.FailureReward,
					bossBonus = runStats and runStats.bossRewardTokens or 0,
				},
				dailyOps = dailyOpsState and dailyOpsState.tasks or {},
				level = progression and progression.level or 1,
				skillPoints = progression and progression.skillPoints or 0,
			})
		end
	end
end

function MissionService:_getActiveSeasonalMissionBonus()
	local activeEvent = self._tokenEconomy and self._tokenEconomy.getActiveSeasonalEvent and self._tokenEconomy.getActiveSeasonalEvent() or nil
	if not activeEvent then
		return nil, 0, 0
	end

	return activeEvent, math.max(0, tonumber(activeEvent.MissionRewardBonus) or 0), math.max(0, tonumber(activeEvent.MissionExperienceBonus) or 0)
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
			specialKills = {},
			bossesDefeated = 0,
			lastBossName = nil,
			bossRewardTokens = 0,
			bossExperienceBonus = 0,
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
	local objectiveLabel = "Defend Core"
	local objectiveCurrent = objectivePercent
	local objectiveTarget = 100
	local phaseTimerDuration = mission and mission.phaseTimerDuration or nil
	local phaseTimerRemaining = nil
	if mission and mission.phaseTimerEndsAt and phaseTimerDuration then
		phaseTimerRemaining = math.max(0, mission.phaseTimerEndsAt - os.clock())
	end
	if self:_isCommanderHuntScenario(mission) then
		objectiveLabel = "Commander"
		objectiveCurrent = objective and (objective:GetAttribute("CommanderEliminated") == true and 1 or 0) or 0
		objectiveTarget = 1
	elseif self:_isEvacEscortScenario(mission) then
		objectiveLabel = "Checkpoints"
		objectiveCurrent = objective and (objective:GetAttribute("ReachedEvacCheckpoint") or 0) or 0
		objectiveTarget = objective and (objective:GetAttribute("RequiredEvacCheckpoints") or 3) or 3
	elseif self:_isPowerRelayScenario(mission) then
		objectiveLabel = "Relay Nodes"
		objectiveCurrent = objective and (objective:GetAttribute("StabilizedRelayNodes") or 0) or 0
		objectiveTarget = objective and (objective:GetAttribute("RequiredRelayNodes") or 3) or 3
	elseif self:_isPowerCellScenario(mission) then
		objectiveLabel = "Power Cells"
		objectiveCurrent = objective and (objective:GetAttribute("DeliveredPowerCells") or 0) or 0
		objectiveTarget = objective and (objective:GetAttribute("RequiredPowerCells") or self._missionConfig.Mission.PowerCellRequiredCount) or self._missionConfig.Mission.PowerCellRequiredCount
	elseif self:_isNestScenario(mission) then
		objectiveLabel = "Nests"
		objectiveCurrent = objective and (objective:GetAttribute("DestroyedNests") or 0) or 0
		objectiveTarget = objective and (objective:GetAttribute("RequiredNests") or self._missionConfig.Mission.NestRequiredCount) or self._missionConfig.Mission.NestRequiredCount
	end
	return {
		stage = "Mission",
		status = status,
		missionPhase = mission and mission.phase or "Combat",
		scenarioName = mission and mission.scenario and mission.scenario.DisplayName or "Hold The Core",
		scenarioDescription = mission and mission.scenario and mission.scenario.Description or "",
		wave = mission and mission.wave or 0,
		totalWaves = self._missionConfig.Mission.WaveCount,
		objectiveHealthPercent = objectivePercent,
		objectiveLabel = objectiveLabel,
		objectiveCurrent = objectiveCurrent,
		objectiveTarget = objectiveTarget,
		remainingZombies = mission and mission.remainingZombies or 0,
		waveTargetHostiles = mission and mission.waveTargetHostiles or 0,
		phaseTimerLabel = mission and mission.phaseTimerLabel or "",
		phaseTimerDuration = phaseTimerDuration or 0,
		phaseTimerRemaining = phaseTimerRemaining or 0,
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
		RunnerStep = clampPositiveInteger(modifier and modifier.RunnerStep or 3, 3),
		ShieldCarrierStep = clampPositiveInteger(modifier and modifier.ShieldCarrierStep or 5, 5),
		ScreamerStep = clampPositiveInteger(modifier and modifier.ScreamerStep or 6, 6),
		SpitterStep = clampPositiveInteger(modifier and modifier.SpitterStep or 5, 5),
		ArtilleryStep = clampPositiveInteger(modifier and modifier.ArtilleryStep or 8, 8),
		ExploderStep = clampPositiveInteger(modifier and modifier.ExploderStep or 7, 7),
		BruteStep = clampPositiveInteger(modifier and modifier.BruteStep or 4, 4),
		BruiserStep = clampPositiveInteger(modifier and modifier.BruiserStep or 6, 6),
		AmmoPickupScale = math.max(0.25, tonumber(modifier and modifier.AmmoPickupScale) or 1),
		SalvagePickupBonus = math.max(0, math.floor(tonumber(modifier and modifier.SalvagePickupBonus) or 0)),
		MedkitPickupCount = clampPositiveInteger(modifier and modifier.MedkitPickupCount or 1, 1),
		RunnerSpeedScale = math.max(0.5, tonumber(modifier and modifier.RunnerSpeedScale) or 1),
		ShieldCarrierSpeedScale = math.max(0.5, tonumber(modifier and modifier.ShieldCarrierSpeedScale) or 1),
		ScreamerSpeedScale = math.max(0.5, tonumber(modifier and modifier.ScreamerSpeedScale) or 1),
		SpitterSpeedScale = math.max(0.5, tonumber(modifier and modifier.SpitterSpeedScale) or 1),
		ExploderSpeedScale = math.max(0.5, tonumber(modifier and modifier.ExploderSpeedScale) or 1),
		BruteSpeedScale = math.max(0.5, tonumber(modifier and modifier.BruteSpeedScale) or 1),
		BruiserSpeedScale = math.max(0.5, tonumber(modifier and modifier.BruiserSpeedScale) or 1),
		WaveSurgeLabel = type(modifier and modifier.WaveSurgeLabel) == "string" and modifier.WaveSurgeLabel or "Pressure spike",
		ForceRunnerPressure = modifier and modifier.ForceRunnerPressure == true,
		ForceShieldCarrierPressure = modifier and modifier.ForceShieldCarrierPressure == true,
		ForceScreamerPressure = modifier and modifier.ForceScreamerPressure == true,
		ForceSpitterPressure = modifier and modifier.ForceSpitterPressure == true,
		ForceArtilleryPressure = modifier and modifier.ForceArtilleryPressure == true,
		ForceExploderPressure = modifier and modifier.ForceExploderPressure == true,
		ForceBrutePressure = modifier and modifier.ForceBrutePressure == true,
		ForceBruiserPressure = modifier and modifier.ForceBruiserPressure == true,
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

function MissionService:_getLayoutBounds(layout)
	local activeLayout = layout or self:_getActiveLayout()
	if not activeLayout then
		return nil
	end

	local explicitBounds = activeLayout.PlayBounds
	if explicitBounds and explicitBounds.Min and explicitBounds.Max then
		return {
			min = explicitBounds.Min,
			max = explicitBounds.Max,
		}
	end

	local minX, minZ = math.huge, math.huge
	local maxX, maxZ = -math.huge, -math.huge
	local hasBounds = false

	local function includeOffset(offset, size)
		if typeof(offset) ~= "Vector3" then
			return
		end
		local halfX = 0
		local halfZ = 0
		if typeof(size) == "Vector3" then
			halfX = size.X * 0.5
			halfZ = size.Z * 0.5
		end
		minX = math.min(minX, offset.X - halfX)
		maxX = math.max(maxX, offset.X + halfX)
		minZ = math.min(minZ, offset.Z - halfZ)
		maxZ = math.max(maxZ, offset.Z + halfZ)
		hasBounds = true
	end

	for _, decoration in ipairs(activeLayout.DecorationPieces or {}) do
		includeOffset(decoration.Offset, decoration.Size)
	end
	includeOffset(activeLayout.ObjectiveOffset, Vector3.new(20, 0, 20))
	includeOffset(activeLayout.ExtractionOffset, Vector3.new(24, 0, 24))
	for _, offset in ipairs(activeLayout.SpawnOffsets or {}) do
		includeOffset(offset, Vector3.new(8, 0, 8))
	end
	for _, offset in ipairs(activeLayout.SupplyOffsets or {}) do
		includeOffset(offset, Vector3.new(6, 0, 6))
	end
	for _, offset in ipairs(activeLayout.PowerCellOffsets or {}) do
		includeOffset(offset, Vector3.new(6, 0, 6))
	end
	for _, offset in ipairs(activeLayout.NestOffsets or {}) do
		includeOffset(offset, Vector3.new(8, 0, 8))
	end
	for _, hazard in ipairs(activeLayout.HazardZones or {}) do
		includeOffset(hazard.Offset, hazard.Size)
	end

	if not hasBounds then
		return nil
	end

	local padding = Vector3.new(10, 0, 10)
	return {
		min = Vector3.new(minX - padding.X, 0, minZ - padding.Z),
		max = Vector3.new(maxX + padding.X, 0, maxZ + padding.Z),
	}
end

function MissionService:_clampWorldPositionToLayoutBounds(worldPosition, margin)
	local bounds = self:_getLayoutBounds()
	local anchor = self:_getMissionAnchorCFrame()
	if not bounds or not anchor or typeof(worldPosition) ~= "Vector3" then
		return worldPosition
	end

	local localPosition = anchor:PointToObjectSpace(worldPosition)
	local clampMargin = math.max(0, tonumber(margin) or 0)
	local clampedLocal = Vector3.new(
		math.clamp(localPosition.X, bounds.min.X + clampMargin, bounds.max.X - clampMargin),
		localPosition.Y,
		math.clamp(localPosition.Z, bounds.min.Z + clampMargin, bounds.max.Z - clampMargin)
	)
	return anchor:PointToWorldSpace(clampedLocal)
end

function MissionService:_getContainedSpawnPosition(worldPosition, margin)
	local anchor = self:_getMissionAnchorCFrame()
	local clampedPosition = self:_clampWorldPositionToLayoutBounds(worldPosition, margin)
	if not anchor or typeof(clampedPosition) ~= "Vector3" then
		return clampedPosition
	end

	return Vector3.new(clampedPosition.X, anchor.Position.Y + 0.2, clampedPosition.Z)
end

function MissionService:_describeSpawnLane(offset: Vector3)
	if math.abs(offset.Z) > math.abs(offset.X) + 12 then
		return offset.Z >= 0 and "North breach" or "South breach"
	end
	if math.abs(offset.X) > math.abs(offset.Z) + 12 then
		return offset.X >= 0 and "East breach" or "West breach"
	end
	if offset.X >= 0 and offset.Z >= 0 then
		return "North-east breach"
	elseif offset.X < 0 and offset.Z >= 0 then
		return "North-west breach"
	elseif offset.X >= 0 and offset.Z < 0 then
		return "South-east breach"
	end
	return "South-west breach"
end

function MissionService:_telegraphSpawnLane(runtime, worldPosition, laneName, color)
	self:_emitPulse(CFrame.new(worldPosition + Vector3.new(0, 1.8, 0)), Vector3.new(7.2, 3.6, 7.2), color, 0.72, 0.2)
	self:_emitPulse(CFrame.new(worldPosition + Vector3.new(0, 0.08, 0)), Vector3.new(10.8, 0.16, 10.8), color:Lerp(Color3.fromRGB(255, 244, 214), 0.15), 0.42, 0.24)
	local marker, _ = self:_createWorldMarker(runtime, ("SpawnTelegraph_%s_%d"):format(laneName:gsub("%s+", ""), math.floor(worldPosition.X + worldPosition.Z)), laneName, color, Vector2.new(148, 28), 13)
	marker.CFrame = CFrame.new(worldPosition + Vector3.new(0, 5.4, 0))
	local gui = marker:FindFirstChildOfClass("BillboardGui")
	if gui then
		gui.MaxDistance = 70
	end
	Debris:AddItem(marker, 1.1)
end

function MissionService:_buildSpawnPlan(spawnOffsets, totalCount, cycleSeed)
	if not spawnOffsets or #spawnOffsets == 0 then
		return nil, nil
	end

	local laneCount = math.clamp(totalCount >= 12 and 3 or 2, 1, #spawnOffsets)
	local activeLayout = self:_getActiveLayout()
	local candidateOffsets = {}
	for _, offset in ipairs(spawnOffsets) do
		local allowOffset = true
		if activeLayout and activeLayout.Id == "arena_reactor_fields" and offset.Z <= -72 then
			allowOffset = false
		end
		if allowOffset then
			table.insert(candidateOffsets, offset)
		end
	end
	if #candidateOffsets == 0 then
		candidateOffsets = spawnOffsets
	end

	table.sort(candidateOffsets, function(a, b)
		local scoreA = math.abs(a.X) * 0.7 + math.max(0, a.Z) + math.abs(a.Z) * 0.12
		local scoreB = math.abs(b.X) * 0.7 + math.max(0, b.Z) + math.abs(b.Z) * 0.12
		if scoreA == scoreB then
			return self:_describeSpawnLane(a) < self:_describeSpawnLane(b)
		end
		return scoreA > scoreB
	end)

	local poolSize = math.max(laneCount, math.min(#candidateOffsets, laneCount + 2))
	local startIndex = ((cycleSeed - 1) % poolSize) + 1
	local step = math.max(1, math.floor(poolSize / laneCount))
	local selectedOffsets = {}
	local laneNames = {}
	local seenNames = {}

	for laneIndex = 1, laneCount do
		local offsetIndex = ((startIndex + ((laneIndex - 1) * step) - 1) % poolSize) + 1
		local offset = candidateOffsets[offsetIndex]
		if not offset then
			continue
		end
		local laneName = self:_describeSpawnLane(offset)
		if not seenNames[laneName] then
			seenNames[laneName] = true
			table.insert(selectedOffsets, offset)
			table.insert(laneNames, laneName)
		end
	end

	if #selectedOffsets == 0 then
		table.insert(selectedOffsets, candidateOffsets[1])
		table.insert(laneNames, self:_describeSpawnLane(candidateOffsets[1]))
	end

	return selectedOffsets, laneNames
end

function MissionService:_selectExtractionFinaleOffsets(spawnOffsets)
	if not spawnOffsets or #spawnOffsets == 0 then
		return nil
	end

	local candidates = {}
	for _, offset in ipairs(spawnOffsets) do
		if offset.Z > -12 then
			table.insert(candidates, offset)
		end
	end
	if #candidates == 0 then
		candidates = spawnOffsets
	end

	table.sort(candidates, function(a, b)
		return a.Z > b.Z
	end)

	local selected = {}
	for index = 1, math.min(3, #candidates) do
		table.insert(selected, candidates[index])
	end
	return selected
end

function MissionService:_getObjectivePressurePlan(mission)
	local currentMission = mission or self._activeMission
	if not currentMission then
		return {
			label = "Objective pressure spike",
			color = Color3.fromRGB(255, 182, 124),
			forceObjectivePressure = true,
			stateText = "Objective pressure spike",
			notifyText = "Objective pressure spike inbound. Hold the objective.",
			countBonus = 0,
			healthScale = 1,
			damageScale = 1,
		}
	end

	local plan = {
		label = "Objective pressure spike",
		color = Color3.fromRGB(255, 182, 124),
		forceObjectivePressure = true,
		stateText = "Objective pressure spike",
		notifyText = "Objective pressure spike inbound. Hold the objective.",
		countBonus = 0,
		healthScale = 1,
		damageScale = 1,
	}

	if self:_isCommanderHuntScenario(currentMission) then
		plan.label = "Commander guard counterpush"
		plan.color = Color3.fromRGB(255, 138, 118)
		plan.stateText = "Commander relocated"
		plan.notifyText = "Commander guard counterpush inbound. The target is repositioning under escort."
		plan.countBonus = 1
		plan.healthScale = 1.08
		plan.forceBruiser = true
	elseif self:_isEvacEscortScenario(currentMission) then
		plan.label = "Convoy choke breach"
		plan.color = Color3.fromRGB(244, 196, 128)
		plan.stateText = "Convoy stalled"
		plan.notifyText = "Convoy choke breach inbound. Push through and reopen the lane."
		plan.countBonus = 1
		plan.healthScale = 1.06
		plan.forceBrute = true
	elseif self:_isPowerRelayScenario(currentMission) then
		plan.label = "Relay destabilization wave"
		plan.color = Color3.fromRGB(156, 220, 255)
		plan.stateText = "Relay spike detected"
		plan.notifyText = "Relay destabilization wave inbound. Outer nodes are surging."
		plan.damageScale = 1.08
		plan.forceScreamer = true
	elseif self:_isPowerCellScenario(currentMission) then
		plan.label = "Power cell recovery breach"
		plan.color = Color3.fromRGB(255, 224, 132)
		plan.stateText = "Recover overloaded cell"
		plan.notifyText = "Recovery breach inbound. An overloaded power cell was thrown off-route."
		plan.countBonus = 1
		plan.forceRunner = true
	elseif self:_isNestScenario(currentMission) then
		plan.label = "Nest defender surge"
		plan.color = Color3.fromRGB(184, 255, 146)
		plan.stateText = "Burn fresh nest cluster"
		plan.notifyText = "Nest defender surge inbound. A fresh cluster is rooting near the breach."
		plan.healthScale = 1.04
		plan.forceExploder = true
	else
		plan.label = "Core pressure breach"
		plan.color = Color3.fromRGB(255, 188, 132)
		plan.stateText = "Core under pressure"
		plan.notifyText = "Core pressure breach inbound. Emergency support is dropping near the bunker."
		plan.forceScreamer = true
	end

	local modifier = currentMission.modifier
	local modifierId = modifier and modifier.Id or nil
	if modifierId == "modifier_blackout" then
		plan.label = "Blackout pressure wave"
		plan.color = Color3.fromRGB(202, 176, 255)
		plan.forceScreamer = true
	elseif modifierId == "modifier_hunter" then
		plan.label = "Hunter flank burst"
		plan.color = Color3.fromRGB(198, 255, 142)
		plan.forceRunner = true
	elseif modifierId == "modifier_siege" or modifierId == "modifier_bulwark" then
		plan.label = "Heavy breach wave"
		plan.color = Color3.fromRGB(255, 188, 132)
		plan.forceShieldCarrier = true
	elseif modifierId == "modifier_biohazard" then
		plan.label = "Biohazard pressure wave"
		plan.color = Color3.fromRGB(152, 255, 198)
		plan.forceExploder = true
	elseif modifierId == "modifier_bombardment" then
		plan.label = "Bombardment volley"
		plan.color = Color3.fromRGB(255, 210, 142)
		plan.forceArtillery = true
	end

	return plan
end

function MissionService:_getExtractionFinalePlan(mission)
	local currentMission = mission or self._activeMission
	local plan = {
		label = "Extraction breach detected",
		stateText = "Extraction under pressure",
		notifyText = "Extraction breach detected. Hold the pad.",
		variant = self:_getExtractionVariant(currentMission),
		color = Color3.fromRGB(255, 132, 132),
		countBonus = 0,
		healthScale = 1,
		damageScale = 1,
	}

	if not currentMission then
		return plan
	end

	if self:_isCommanderHuntScenario(currentMission) then
		plan.label = "Commander loyalist breach"
		plan.stateText = "Commander loyalists pushing extraction"
		plan.notifyText = "Commander loyalists are collapsing on extraction. Hold the bunker edge."
		plan.color = Color3.fromRGB(255, 146, 124)
		plan.countBonus = 1
		plan.healthScale = 1.08
		plan.forceBruiser = true
	elseif self:_isEvacEscortScenario(currentMission) then
		plan.label = "Convoy tail breach"
		plan.stateText = "Escort survivors board now"
		plan.notifyText = "The convoy tail is collapsing. Board under pressure and hold the exit."
		plan.variant = "moving"
		plan.color = Color3.fromRGB(255, 196, 138)
		plan.countBonus = 1
		plan.forceBrute = true
	elseif self:_isPowerRelayScenario(currentMission) then
		plan.label = "Relay overload breach"
		plan.stateText = "Relay overload at extraction"
		plan.notifyText = "A relay overload is spilling into extraction. Silence support infected and keep the pad clear."
		plan.color = Color3.fromRGB(156, 220, 255)
		plan.damageScale = 1.08
		plan.forceScreamer = true
	elseif self:_isPowerCellScenario(currentMission) then
		plan.label = "Recovery pack collapse"
		plan.stateText = "Board both extraction pads"
		plan.notifyText = "A recovery pack is swarming the dropped cells. Split the squad across both pads and board immediately."
		plan.variant = "split"
		plan.color = Color3.fromRGB(255, 224, 132)
		plan.forceRunner = true
	elseif self:_isNestScenario(currentMission) then
		plan.label = "Nest rupture breach"
		plan.stateText = "Nest rupture at extraction"
		plan.notifyText = "A fresh rupture opened near extraction. Burn through it and get out."
		plan.color = Color3.fromRGB(184, 255, 146)
		plan.healthScale = 1.04
		plan.forceExploder = true
	end

	local modifier = currentMission.modifier
	local modifierId = modifier and modifier.Id or nil
	if modifierId == "modifier_hunter" then
		plan.label = "Hunter extraction collapse"
		plan.stateText = "Hunter pack on extraction"
		plan.notifyText = "Hunter pack collapsing on extraction. Watch the flanks."
		plan.color = Color3.fromRGB(198, 255, 142)
		plan.forceRunner = true
	elseif modifierId == "modifier_biohazard" then
		plan.label = "Biohazard extraction breach"
		plan.stateText = "Biohazard flooding extraction"
		plan.notifyText = "Biohazard breach at extraction. Clear volatile infected off the pad."
		plan.color = Color3.fromRGB(152, 255, 198)
		plan.forceExploder = true
	elseif modifierId == "modifier_siege" or modifierId == "modifier_bulwark" then
		plan.label = "Shield wall collapse"
		plan.stateText = "Shield carriers on extraction"
		plan.notifyText = "Shield carriers are locking the extraction lane. Break the wall and board."
		plan.color = Color3.fromRGB(184, 214, 255)
		plan.forceShieldCarrier = true
	elseif modifierId == "modifier_bombardment" then
		plan.label = "Bombardment extraction volley"
		plan.stateText = "Artillery on extraction"
		plan.notifyText = "Artillery volley locking onto extraction. Board fast and stay moving."
		plan.color = Color3.fromRGB(255, 210, 142)
		plan.forceArtillery = true
	elseif modifierId == "modifier_blackout" then
		plan.label = "Blackout extraction howl"
		plan.stateText = "Support howls in the dark"
		plan.notifyText = "Screamers are driving the blackout collapse. Cut them down and board fast."
		plan.color = Color3.fromRGB(202, 176, 255)
		plan.forceScreamer = true
	end

	return plan
end

function MissionService:_countRuntimeChildrenWithPrefix(runtime, prefix)
	if not runtime or not prefix then
		return 0
	end

	local count = 0
	for _, child in ipairs(runtime:GetChildren()) do
		if string.sub(child.Name, 1, #prefix) == prefix then
			count += 1
		end
	end
	return count
end

function MissionService:_triggerObjectivePressureEvent(mission, plan, eventIndex, selectedSpawnOffsets)
	if not mission or not plan or not mission.runtime then
		return
	end

	local runtime = mission.runtime
	local objective = self:_getMissionObjective()
	local focusOffset = selectedSpawnOffsets and selectedSpawnOffsets[1] or Vector3.new()
	local focusPosition = self:_getLayoutWorldPosition(focusOffset + Vector3.new(0, 0, 6))

	if self:_isPowerCellScenario(mission) then
		local required = objective and (objective:GetAttribute("RequiredPowerCells") or self._missionConfig.Mission.PowerCellRequiredCount) or self._missionConfig.Mission.PowerCellRequiredCount
		local liveCells = self:_countRuntimeChildrenWithPrefix(runtime, "PowerCell_")
		if liveCells < (required + 1) then
			local cellId = required + eventIndex + 10
			self:_spawnPowerCell(runtime, focusPosition, cellId)
			self:_emitPulse(CFrame.new(focusPosition + Vector3.new(0, 2, 0)), Vector3.new(8, 6, 8), plan.color, 0.38, 0.2)
		end
	elseif self:_isNestScenario(mission) then
		local required = objective and (objective:GetAttribute("RequiredNests") or self._missionConfig.Mission.NestRequiredCount) or self._missionConfig.Mission.NestRequiredCount
		local liveNests = self:_countRuntimeChildrenWithPrefix(runtime, "Nest_")
		if liveNests < (required + 1) then
			local nestId = required + eventIndex + 10
			self:_spawnNest(runtime, focusPosition, nestId)
			self:_emitPulse(CFrame.new(focusPosition + Vector3.new(0, 2, 0)), Vector3.new(9, 5, 9), plan.color, 0.42, 0.18)
		end
	elseif self:_isPowerRelayScenario(mission) then
		local surgeNode = nil
		for _, child in ipairs(runtime:GetChildren()) do
			if string.sub(child.Name, 1, 10) == "RelayNode_" and child:GetAttribute("Stabilized") ~= true then
				surgeNode = child
				break
			end
		end

		if surgeNode then
			local core = surgeNode:FindFirstChild("Core")
			local ring = surgeNode:FindFirstChild("Ring")
			if core and core:IsA("BasePart") then
				core.Color = Color3.fromRGB(255, 188, 118)
			end
			if ring and ring:IsA("BasePart") then
				ring.Color = Color3.fromRGB(255, 210, 144)
				ring.Transparency = 0.24
			end
			self:_emitPulse(surgeNode:GetPivot(), Vector3.new(10, 6, 10), plan.color, 0.32, 0.18)
		end
	elseif self:_isEvacEscortScenario(mission) then
		local convoy = runtime:FindFirstChild("EvacConvoy")
		local convoyGlow = convoy and convoy:FindFirstChild("ConvoyGlow")
		if convoyGlow and convoyGlow:IsA("BasePart") then
			convoyGlow.Color = Color3.fromRGB(255, 172, 124)
			convoyGlow.Transparency = 0.38
		end
		if convoy then
			self:_emitPulse(convoy:GetPivot(), Vector3.new(16, 5, 22), plan.color, 0.26, 0.24)
		end
	elseif self:_isCommanderHuntScenario(mission) then
		local commander = runtime:FindFirstChild("BlacksiteCommander")
		if commander and commander.Parent then
			local relocatePosition = self:_getLayoutWorldPosition((selectedSpawnOffsets and selectedSpawnOffsets[#selectedSpawnOffsets] or focusOffset) + Vector3.new(0, 0, -6))
			commander:PivotTo(CFrame.new(relocatePosition + Vector3.new(0, 3, 0)))
			self:_emitPulse(commander:GetPivot(), Vector3.new(12, 8, 12), plan.color, 0.3, 0.22)
		end
	else
		local supportPosition = objective and (objective.Position + Vector3.new(0, 0, 12)) or focusPosition
		self:_createSupplyPickup(runtime, "Ammo", supportPosition)
		self:_emitPulse(CFrame.new(supportPosition + Vector3.new(0, 2, 0)), Vector3.new(8, 5, 8), plan.color, 0.34, 0.18)
	end
end

function MissionService:_scheduleObjectivePressure(mission, scaledStats)
	if not mission or mission.phase ~= "Combat" or mission.wave < 2 then
		return
	end

	local layout = mission.layout or self:_getActiveLayout()
	local spawnOffsets = layout and layout.SpawnOffsets or nil
	if not spawnOffsets or #spawnOffsets == 0 then
		return
	end

	local modifierTraits = self:_getModifierRuntimeTraits()
	local initialDelay = math.max(
		3,
		tonumber(self._missionConfig.Mission.ObjectivePressureInitialDelay) or 6
	)
	local repeatDelay = math.max(
		5,
		(tonumber(self._missionConfig.Mission.ObjectivePressureWaveDelay) or 8) + ((modifierTraits.ObjectivePressureInterval - 3) * 0.75)
	)
	local pressureCountBase = math.max(1, tonumber(self._missionConfig.Mission.ObjectivePressureBaseCount) or 2)
	local countPerExtraPlayer = math.max(0, tonumber(self._missionConfig.Mission.ObjectivePressureCountPerExtraPlayer) or 1)
	local pressureHealthScale = math.max(0.5, tonumber(self._missionConfig.Mission.ObjectivePressureHealthScale) or 1.06)
	local pressureDamageScale = math.max(0.5, tonumber(self._missionConfig.Mission.ObjectivePressureDamageScale) or 1.08)
	local startWave = mission.wave
	local eventIndex = 0

	task.delay(initialDelay, function()
		while self._activeMission == mission and mission.phase == "Combat" and mission.wave == startWave and mission.remainingZombies > 0 do
			local objective = self:_getMissionObjective()
			if not objective or not objective.Parent then
				return
			end

			eventIndex += 1
			local plan = self:_getObjectivePressurePlan(mission)
			local liveParty = self:_getLivePartyMembers()
			local pressureCount = pressureCountBase + math.max(0, #liveParty - 1) * countPerExtraPlayer + (plan.countBonus or 0)
			if mission.wave >= self._missionConfig.Mission.WaveCount then
				pressureCount += 1
			end
			pressureCount = math.min(6, math.max(1, pressureCount))

			local pressureStats = {
				health = math.max(1, math.floor((scaledStats.health or self._missionConfig.Mission.ZombieBaseHealth) * pressureHealthScale * (plan.healthScale or 1))),
				damage = math.max(1, math.floor((scaledStats.damage or self._missionConfig.Mission.ZombieBaseDamage) * pressureDamageScale * (plan.damageScale or 1))),
				spawnCount = pressureCount,
			}

			local selectedSpawnOffsets, laneNames = self:_buildSpawnPlan(spawnOffsets, pressureCount, startWave + eventIndex + 2)
			if not selectedSpawnOffsets or #selectedSpawnOffsets == 0 then
				return
			end

			mission.remainingZombies += pressureCount
			mission.waveTargetHostiles = (mission.waveTargetHostiles or 0) + pressureCount
			self:_notifyParty(mission.party, ("%s %s"):format(plan.notifyText or (plan.label .. " inbound."), laneNames and #laneNames > 0 and ("Watch " .. table.concat(laneNames, " / ")) or "Hold the objective"))
			self:_fireMissionState(mission.party, plan.stateText or plan.label)

			for _, baseOffset in ipairs(selectedSpawnOffsets) do
				self:_telegraphSpawnLane(mission.runtime, self:_getLayoutWorldPosition(baseOffset), self:_describeSpawnLane(baseOffset), plan.color)
			end
			self:_triggerObjectivePressureEvent(mission, plan, eventIndex, selectedSpawnOffsets)

			task.spawn(function()
				for index = 1, pressureCount do
					if not self._activeMission or self._activeMission ~= mission or mission.phase ~= "Combat" or mission.wave ~= startWave then
						return
					end

					local baseOffset = selectedSpawnOffsets[((index - 1) % #selectedSpawnOffsets) + 1]
					local jitter = Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
					local spawnPosition = self:_getContainedSpawnPosition(self:_getLayoutWorldPosition(baseOffset + jitter), 8)
					self:_spawnZombie(spawnPosition, pressureStats, (scaledStats.spawnCount or 0) + (eventIndex * 10) + index, {
						laneOffset = baseOffset,
						forceObjectivePressure = true,
						forceRunner = plan.forceRunner == true,
						forceShieldCarrier = plan.forceShieldCarrier == true,
						forceSpitter = plan.forceSpitter == true,
						forceArtillery = plan.forceArtillery == true,
						forceExploder = plan.forceExploder == true,
						forceBrute = plan.forceBrute == true,
						forceBruiser = plan.forceBruiser == true,
					})
					if index < pressureCount then
						task.wait(0.12)
					end
				end
			end)

			task.wait(repeatDelay)
		end
	end)
end

function MissionService:_getLaneFocusPosition(laneOffset: Vector3, role: string?)
	if typeof(laneOffset) ~= "Vector3" then
		return nil
	end

	if role == "Flank" then
		local sideBias = laneOffset.X >= 0 and 1 or -1
		return self:_getLayoutWorldPosition(Vector3.new(sideBias * 58, 0, 6))
	elseif role == "Ranged" then
		local sideBias = laneOffset.X >= 0 and 1 or -1
		local depth = laneOffset.Z >= 0 and 44 or -12
		return self:_getLayoutWorldPosition(Vector3.new(sideBias * 52, 0, depth))
	elseif role == "Objective" then
		return self:_getLayoutWorldPosition(Vector3.new(0, 0, 30))
	end

	return self:_getLayoutWorldPosition(Vector3.new(laneOffset.X * 0.45, 0, laneOffset.Z * 0.45))
end

function MissionService:_startExtractionPressure(mission)
	if not mission or self._activeMission ~= mission or mission.phase ~= "Extraction" then
		return
	end
	if mission.extractionFinaleTriggered then
		return
	end
	mission.extractionFinaleTriggered = true

	local runtime = mission.runtime
	local layout = self:_getActiveLayout()
	local spawnOffsets = layout and layout.SpawnOffsets or nil
	local finaleOffsets = self:_selectExtractionFinaleOffsets(spawnOffsets)
	if not finaleOffsets or #finaleOffsets == 0 then
		return
	end

	local liveParty = self:_getLivePartyMembers()
	local plan = self:_getExtractionFinalePlan(mission)
	local finaleCount = (self._missionConfig.Mission.ExtractionFinaleBaseCount or 4)
		+ math.max(0, #liveParty - 1) * (self._missionConfig.Mission.ExtractionFinaleCountPerExtraPlayer or 1)
		+ (plan.countBonus or 0)
	local baseScaledStats = self:_getScaledWaveStats(math.max(1, mission.wave))
	local finaleStats = {
		health = math.max(1, math.floor((baseScaledStats.health or self._missionConfig.Mission.ZombieBaseHealth) * (self._missionConfig.Mission.ExtractionFinaleHealthScale or 1) * (plan.healthScale or 1))),
		damage = math.max(1, math.floor((baseScaledStats.damage or self._missionConfig.Mission.ZombieBaseDamage) * (self._missionConfig.Mission.ExtractionFinaleDamageScale or 1) * (plan.damageScale or 1))),
		spawnCount = finaleCount,
	}

	mission.remainingZombies += finaleCount
	mission.waveTargetHostiles = (mission.waveTargetHostiles or 0) + finaleCount
	self:_notifyParty(mission.party, plan.notifyText or "Extraction breach detected. Hold the pad.")
	self:_fireMissionState(mission.party, plan.stateText or plan.label)

	for _, baseOffset in ipairs(finaleOffsets) do
		self:_telegraphSpawnLane(runtime, self:_getLayoutWorldPosition(baseOffset), self:_describeSpawnLane(baseOffset), plan.color)
	end

	task.spawn(function()
		for index = 1, finaleCount do
			if not self._activeMission or self._activeMission ~= mission or mission.phase ~= "Extraction" then
				return
			end
			local baseOffset = finaleOffsets[((index - 1) % #finaleOffsets) + 1]
			local jitter = Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
			local spawnPosition = self:_getContainedSpawnPosition(self:_getLayoutWorldPosition(baseOffset + jitter), 8)
			self:_spawnZombie(spawnPosition, finaleStats, index, {
				laneOffset = baseOffset,
				forceObjectivePressure = index % 2 == 0,
				extractionFinale = true,
				forceRunner = plan.forceRunner == true,
				forceShieldCarrier = plan.forceShieldCarrier == true,
				forceSpitter = plan.forceSpitter == true,
				forceArtillery = plan.forceArtillery == true,
				forceExploder = plan.forceExploder == true,
				forceBrute = plan.forceBrute == true,
				forceBruiser = plan.forceBruiser == true,
			})
			if index < finaleCount then
				task.wait(index % math.max(2, math.floor(finaleCount / 2)) == 0 and 0.2 or 0.08)
			end
		end
	end)
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
		floor.Size = Vector3.new(246, 1.2, 278)
		floor.CFrame = anchor * CFrame.new(0, -0.75, -2)
		floorTrim.Size = Vector3.new(208, 0.18, 232)
		floorTrim.CFrame = anchor * CFrame.new(0, -0.05, -2)
		createRuntimeGlow(shell, "ReactorCenterLaneGlow", Vector3.new(20, 0.08, 132), anchor * CFrame.new(0, 0.05, 0), Color3.fromRGB(118, 184, 164), 0.92)
		createRuntimeGlow(shell, "ReactorNorthLaneGlow", Vector3.new(52, 0.08, 18), anchor * CFrame.new(0, 0.05, 66), Color3.fromRGB(214, 178, 108), 0.9)
		createRuntimeGlow(shell, "ReactorSouthExtractGlow", Vector3.new(44, 0.08, 16), anchor * CFrame.new(0, 0.05, -54), Color3.fromRGB(112, 208, 176), 0.9)
		for _, data in ipairs({
			{ "ReactorWestPlatform", Vector3.new(34, 0.9, 58), Vector3.new(-54, 0.18, 14), Color3.fromRGB(56, 66, 78), Enum.Material.DiamondPlate },
			{ "ReactorEastPlatform", Vector3.new(34, 0.9, 58), Vector3.new(54, 0.18, 14), Color3.fromRGB(56, 66, 78), Enum.Material.DiamondPlate },
			{ "ReactorNorthBulkhead", Vector3.new(84, 10, 4), Vector3.new(0, 5, 96), Color3.fromRGB(42, 48, 56), Enum.Material.Metal },
			{ "ReactorWestBulkhead", Vector3.new(4, 10, 104), Vector3.new(-96, 5, 0), Color3.fromRGB(42, 48, 56), Enum.Material.Metal },
			{ "ReactorEastBulkhead", Vector3.new(4, 10, 104), Vector3.new(96, 5, 0), Color3.fromRGB(42, 48, 56), Enum.Material.Metal },
			{ "ReactorCenterBridge", Vector3.new(22, 0.5, 118), Vector3.new(0, 0.7, 18), Color3.fromRGB(78, 90, 106), Enum.Material.Metal },
			{ "ReactorSouthStaging", Vector3.new(52, 0.6, 24), Vector3.new(0, 0.36, -56), Color3.fromRGB(72, 82, 96), Enum.Material.DiamondPlate },
			{ "ReactorWestTower", Vector3.new(12, 18, 12), Vector3.new(-72, 9, 44), Color3.fromRGB(62, 74, 88), Enum.Material.Metal },
			{ "ReactorEastTower", Vector3.new(12, 18, 12), Vector3.new(72, 9, 44), Color3.fromRGB(62, 74, 88), Enum.Material.Metal },
			{ "ReactorCenterCore", Vector3.new(18, 7.2, 18), Vector3.new(0, 3.6, 36), Color3.fromRGB(70, 82, 96), Enum.Material.Metal },
		}) do
			local structure = createRuntimePart(shell, data[1], data[2], anchor * CFrame.new(data[3]), data[4], data[5])
			structure.CanQuery = false
		end
		for _, data in ipairs({
			{ "ReactorWestLaneGlow", Vector3.new(14, 0.08, 118), Vector3.new(-54, 0.05, 12), Color3.fromRGB(134, 176, 226), 0.93 },
			{ "ReactorEastLaneGlow", Vector3.new(14, 0.08, 118), Vector3.new(54, 0.05, 12), Color3.fromRGB(134, 176, 226), 0.93 },
			{ "ReactorNorthBreachGlow", Vector3.new(66, 0.08, 16), Vector3.new(0, 0.05, 90), Color3.fromRGB(244, 182, 118), 0.9 },
		}) do
			local glowPart = createRuntimeGlow(shell, data[1], data[2], anchor * CFrame.new(data[3]), data[4], data[5])
			glowPart.CanQuery = false
		end
		for _, data in ipairs({
			{ "ReactorNorthWallLeft", Vector3.new(72, 9.2, 4), Vector3.new(-58, 4.6, 100) },
			{ "ReactorNorthWallRight", Vector3.new(72, 9.2, 4), Vector3.new(58, 4.6, 100) },
			{ "ReactorSouthWallLeft", Vector3.new(76, 8.2, 4), Vector3.new(-60, 4.1, -98) },
			{ "ReactorSouthWallRight", Vector3.new(76, 8.2, 4), Vector3.new(60, 4.1, -98) },
			{ "ReactorWestWallNorth", Vector3.new(4, 9.2, 72), Vector3.new(-98, 4.6, 56) },
			{ "ReactorWestWallSouth", Vector3.new(4, 9.2, 62), Vector3.new(-98, 4.6, -56) },
			{ "ReactorEastWallNorth", Vector3.new(4, 9.2, 72), Vector3.new(98, 4.6, 56) },
			{ "ReactorEastWallSouth", Vector3.new(4, 9.2, 62), Vector3.new(98, 4.6, -56) },
		}) do
			local wall = createRuntimePart(shell, data[1], data[2], anchor * CFrame.new(data[3]), Color3.fromRGB(40, 48, 58), Enum.Material.Metal)
			wall.CanQuery = false
		end
		for _, data in ipairs({
			{ "ReactorNorthGate", Vector3.new(28, 6.2, 2.2), Vector3.new(0, 3.2, 99) },
			{ "ReactorSouthGate", Vector3.new(24, 5.6, 2.2), Vector3.new(0, 2.9, -97) },
			{ "ReactorWestGate", Vector3.new(2.2, 5.8, 24), Vector3.new(-97, 3, 0) },
			{ "ReactorEastGate", Vector3.new(2.2, 5.8, 24), Vector3.new(97, 3, 0) },
		}) do
			local gate = createRuntimeGlow(shell, data[1], data[2], anchor * CFrame.new(data[3]), Color3.fromRGB(122, 184, 226), 0.72)
			gate.CanQuery = false
		end
		for _, data in ipairs({
			{ "ReactorCoverNorthWestA", Vector3.new(8, 3.2, 3), Vector3.new(-46, 1.6, 52), 16 },
			{ "ReactorCoverNorthWestB", Vector3.new(8, 3.2, 3), Vector3.new(-36, 1.6, 46), -18 },
			{ "ReactorCoverNorthEastA", Vector3.new(8, 3.2, 3), Vector3.new(46, 1.6, 52), -16 },
			{ "ReactorCoverNorthEastB", Vector3.new(8, 3.2, 3), Vector3.new(36, 1.6, 46), 18 },
			{ "ReactorCoverSouthWestA", Vector3.new(10, 3.2, 3), Vector3.new(-42, 1.6, -28), -14 },
			{ "ReactorCoverSouthWestB", Vector3.new(10, 3.2, 3), Vector3.new(-26, 1.6, -18), 22 },
			{ "ReactorCoverSouthEastA", Vector3.new(10, 3.2, 3), Vector3.new(42, 1.6, -28), 14 },
			{ "ReactorCoverSouthEastB", Vector3.new(10, 3.2, 3), Vector3.new(26, 1.6, -18), -22 },
		}) do
			local cover = createRuntimePart(shell, data[1], data[2], anchor * CFrame.new(data[3]) * CFrame.Angles(0, math.rad(data[4]), 0), Color3.fromRGB(92, 102, 116), Enum.Material.Metal)
			cover.CanQuery = false
		end
		for _, x in ipairs({ -66, -22, 22, 66 }) do
			local pipe = createRuntimePart(shell, ("ReactorPipe_%d"):format(x), Vector3.new(1, 1, 120), anchor * CFrame.new(x, 7.6, 4), Color3.fromRGB(92, 108, 126), Enum.Material.Metal)
			pipe.Shape = Enum.PartType.Cylinder
			pipe.Orientation = Vector3.new(0, 0, 90)
			pipe.CanQuery = false
			local pipeGlow = createRuntimeGlow(shell, ("ReactorPipeGlow_%d"):format(x), Vector3.new(0.24, 0.24, 96), anchor * CFrame.new(x, 7.18, 4), Color3.fromRGB(132, 200, 246), 0.68)
			pipeGlow.CanQuery = false
		end
		for _, z in ipairs({ -62, -6, 48 }) do
			local catwalk = createRuntimePart(shell, ("ReactorCrossCatwalk_%d"):format(z), Vector3.new(164, 0.44, 7), anchor * CFrame.new(0, 4.8, z), Color3.fromRGB(72, 82, 94), Enum.Material.DiamondPlate)
			catwalk.CanQuery = false
		end
		for _, side in ipairs({ -1, 1 }) do
			local label = side < 0 and "West" or "East"
			local x = side * 70

			local serviceFloor = createRuntimePart(shell, "Reactor" .. label .. "ServiceFloor", Vector3.new(24, 0.8, 66), anchor * CFrame.new(x, 0.12, 6), Color3.fromRGB(60, 70, 82), Enum.Material.DiamondPlate)
			serviceFloor.CanQuery = false

			local serviceBack = createRuntimePart(shell, "Reactor" .. label .. "ServiceBack", Vector3.new(22, 8.2, 3.2), anchor * CFrame.new(x, 4.1, 36), Color3.fromRGB(46, 52, 62), Enum.Material.Metal)
			serviceBack.CanQuery = false

			local serviceFront = createRuntimePart(shell, "Reactor" .. label .. "ServiceFront", Vector3.new(22, 7.6, 3.2), anchor * CFrame.new(x, 3.8, -24), Color3.fromRGB(46, 52, 62), Enum.Material.Metal)
			serviceFront.CanQuery = false

			local serviceInner = createRuntimePart(shell, "Reactor" .. label .. "ServiceInner", Vector3.new(3.2, 8.4, 70), anchor * CFrame.new(side * 57, 4.2, 6), Color3.fromRGB(52, 60, 72), Enum.Material.Metal)
			serviceInner.CanQuery = false

			local serviceOuterNorth = createRuntimePart(shell, "Reactor" .. label .. "ServiceOuterNorth", Vector3.new(3.2, 8.4, 28), anchor * CFrame.new(side * 82, 4.2, 24), Color3.fromRGB(40, 48, 58), Enum.Material.Metal)
			serviceOuterNorth.CanQuery = false

			local serviceOuterSouth = createRuntimePart(shell, "Reactor" .. label .. "ServiceOuterSouth", Vector3.new(3.2, 8.4, 28), anchor * CFrame.new(side * 82, 4.2, -14), Color3.fromRGB(40, 48, 58), Enum.Material.Metal)
			serviceOuterSouth.CanQuery = false

			local serviceDoorNorth = createRuntimeGlow(shell, "Reactor" .. label .. "ServiceDoorNorth", Vector3.new(3.8, 5.2, 12), anchor * CFrame.new(side * 57, 2.8, 52), Color3.fromRGB(128, 196, 238), 0.74)
			serviceDoorNorth.CanQuery = false

			local serviceDoorSouth = createRuntimeGlow(shell, "Reactor" .. label .. "ServiceDoorSouth", Vector3.new(3.8, 5.2, 12), anchor * CFrame.new(side * 57, 2.8, -42), Color3.fromRGB(128, 196, 238), 0.74)
			serviceDoorSouth.CanQuery = false

			local serviceLane = createRuntimeGlow(shell, "Reactor" .. label .. "ServiceLaneGlow", Vector3.new(10, 0.08, 72), anchor * CFrame.new(side * 69, 0.06, 6), Color3.fromRGB(116, 164, 212), 0.92)
			serviceLane.CanQuery = false

			for _, z in ipairs({ -8, 18 }) do
				local console = createRuntimePart(shell, ("Reactor%sConsole_%d"):format(label, z), Vector3.new(6.4, 2.8, 2.8), anchor * CFrame.new(side * 66, 1.4, z), Color3.fromRGB(88, 98, 112), Enum.Material.Metal)
				console.CanQuery = false
				local consoleGlow = createRuntimeGlow(shell, ("Reactor%sConsoleGlow_%d"):format(label, z), Vector3.new(4.2, 0.08, 1.2), anchor * CFrame.new(side * 66, 2.84, z), Color3.fromRGB(154, 218, 255), 0.48)
				consoleGlow.CanQuery = false
			end

			for _, z in ipairs({ -18, 22 }) do
				local crateStack = createRuntimePart(shell, ("Reactor%sCrate_%d"):format(label, z), Vector3.new(6, 4.6, 6), anchor * CFrame.new(side * 74, 2.3, z), Color3.fromRGB(92, 84, 68), Enum.Material.WoodPlanks)
				crateStack.CanQuery = false
			end
		end
		for _, z in ipairs({ -48, -16, 22, 58 }) do
			local divider = createRuntimePart(shell, ("ReactorMidDivider_%d"):format(z), Vector3.new(38, 3.2, 3.2), anchor * CFrame.new(0, 1.6, z), Color3.fromRGB(78, 88, 100), Enum.Material.Metal)
			divider.CanQuery = false
		end
		for _, data in ipairs({
			{ "ReactorNorthApproachLeft", Vector3.new(12, 0.08, 44), Vector3.new(-22, 0.06, 74), Color3.fromRGB(228, 176, 112) },
			{ "ReactorNorthApproachRight", Vector3.new(12, 0.08, 44), Vector3.new(22, 0.06, 74), Color3.fromRGB(228, 176, 112) },
			{ "ReactorExtractApproachLeft", Vector3.new(10, 0.08, 34), Vector3.new(-18, 0.06, -70), Color3.fromRGB(124, 220, 184) },
			{ "ReactorExtractApproachRight", Vector3.new(10, 0.08, 34), Vector3.new(18, 0.06, -70), Color3.fromRGB(124, 220, 184) },
		}) do
			local laneGlow = createRuntimeGlow(shell, data[1], data[2], anchor * CFrame.new(data[3]), data[4], 0.88)
			laneGlow.CanQuery = false
		end
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

	local rootPart = zombieModel.PrimaryPart
	if rootPart and zombieModel:GetAttribute("ShieldCarrier") and attacker and attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart") then
		local incomingDirection = (rootPart.Position - attacker.Character.HumanoidRootPart.Position)
		if incomingDirection.Magnitude > 0.01 then
			local facingDot = rootPart.CFrame.LookVector:Dot((-incomingDirection).Unit)
			if facingDot >= (self._missionConfig.Mission.ShieldCarrierFacingBlockDot or 0.42) then
				damage = math.max(1, math.floor(damage * (self._missionConfig.Mission.ShieldCarrierFrontDamageScale or 0.35)))
				zombieModel:SetAttribute("HitReactUntil", os.clock() + 0.08)
				zombieModel:SetAttribute("HitReactPitch", 0.03)
				zombieModel:SetAttribute("HitReactYaw", 0)
				zombieModel:SetAttribute("HitReactRoll", 0.04)
				self:_emitPulse(rootPart.CFrame * CFrame.new(0, 0.1, -(rootPart.Size.Z * 0.7)), Vector3.new(1.8, 1.8, 0.14), Color3.fromRGB(184, 222, 255), 0.32, 0.08)
			end
		end
	end
	self:_recordZombieDamage(zombieModel, attacker, damage)

	if attacker then
		zombieModel:SetAttribute("LastDamagerUserId", attacker.UserId)
		zombieModel:SetAttribute("LastDamagerAt", os.clock())
	end

	if rootPart and attacker and attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart") then
		local impulseDirection = (rootPart.Position - attacker.Character.HumanoidRootPart.Position).Unit
		rootPart.AssemblyLinearVelocity = impulseDirection * 13 + Vector3.new(0, 8, 0)
		local reactStrength = math.clamp(damage / math.max(18, humanoid.MaxHealth * 0.28), 0.12, 0.45)
		zombieModel:SetAttribute("HitReactUntil", os.clock() + (zombieModel:GetAttribute("Brute") and 0.22 or 0.16))
		zombieModel:SetAttribute("HitReactPitch", math.clamp(reactStrength * 0.48, 0.05, 0.22))
		zombieModel:SetAttribute("HitReactYaw", math.clamp(impulseDirection.X * 0.18, -0.16, 0.16))
		zombieModel:SetAttribute("HitReactRoll", math.clamp(-impulseDirection.X * 0.22, -0.18, 0.18))
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
	local profile = self:_getBossProfile(self._activeMission)

	local aura = zombie:FindFirstChild("BossAura")
	if aura and aura:IsA("Highlight") then
		local enraged = zombie:GetAttribute("Enraged") == true
		aura.FillColor = active and profile.weakFillColor or (enraged and profile.enragedFillColor or profile.fillColor)
		aura.OutlineColor = active and profile.weakOutlineColor or (enraged and profile.enragedOutlineColor or profile.outlineColor)
		aura.FillTransparency = active and 0.24 or 0.42
	end

	local marker = zombie:FindFirstChild("BossMarker")
	local label = marker and marker:FindFirstChildOfClass("TextLabel")
	if label then
		local enraged = zombie:GetAttribute("Enraged") == true
		label.Text = active and "WEAK POINT OPEN" or (enraged and (profile.name .. " RAGING") or profile.name)
		label.TextColor3 = active and profile.weakTextColor or (enraged and profile.enragedTextColor or profile.textColor)
	end
end

function MissionService:_setBossEnrageState(zombie, active)
	if not zombie or not zombie.Parent then
		return
	end

	zombie:SetAttribute("Enraged", active)
	local profile = self:_getBossProfile(self._activeMission)

	local aura = zombie:FindFirstChild("BossAura")
	if aura and aura:IsA("Highlight") then
		aura.FillColor = active and profile.enragedFillColor or (zombie:GetAttribute("WeakPointActive") and profile.weakFillColor or profile.fillColor)
		aura.OutlineColor = active and profile.enragedOutlineColor or (zombie:GetAttribute("WeakPointActive") and profile.weakOutlineColor or profile.outlineColor)
		aura.FillTransparency = active and 0.28 or (zombie:GetAttribute("WeakPointActive") and 0.24 or 0.42)
	end

	local marker = zombie:FindFirstChild("BossMarker")
	local label = marker and marker:FindFirstChildOfClass("TextLabel")
	if label and zombie:GetAttribute("WeakPointActive") ~= true then
		label.Text = active and (profile.name .. " RAGING") or profile.name
		label.TextColor3 = active and profile.enragedTextColor or profile.textColor
	end
end

function MissionService:_openBossWeakPoint(zombie)
	local mission = self._activeMission
	if not mission or not zombie or not zombie.Parent then
		return
	end

	local profile = self:_getBossProfile(mission)
	self:_setBossWeakPointState(zombie, true)
	self:_notifyParty(mission.party, ("Weak point exposed. Focus fire on the %s."):format(profile.notifyName))
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

function MissionService:_emitTracer(originPosition, hitPosition, color, weapon)
	local distance = (hitPosition - originPosition).Magnitude
	if distance <= 0 then
		return
	end

	local width = 0.18
	if weapon then
		if weapon.ModelStyle == "Shotgun" or weapon.WeaponType == "Spread" then
			width = 0.24
		elseif weapon.ModelStyle == "SMG" then
			width = 0.12
		elseif weapon.ModelStyle == "Carbine" then
			width = 0.16
		end
	end

	local tracer = Instance.new("Part")
	tracer.Name = "BulletTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = color
	tracer.Size = Vector3.new(width, width, distance)
	tracer.CFrame = CFrame.lookAt(originPosition:Lerp(hitPosition, 0.5), hitPosition)
	tracer.Parent = Workspace
	Debris:AddItem(tracer, 0.08)

	local core = Instance.new("Part")
	core.Name = "BulletTracerCore"
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.Material = Enum.Material.Neon
	core.Color = color:Lerp(Color3.fromRGB(255, 246, 222), 0.45)
	core.Size = Vector3.new(width * 0.45, width * 0.45, distance)
	core.CFrame = tracer.CFrame
	core.Parent = Workspace
	Debris:AddItem(core, 0.06)
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
	local flash = self:_emitPulse(handle.CFrame * CFrame.new(offset), size, color, 0.14, weaponType == "Spread" and 0.09 or 0.07)
	if flash then
		flash.Shape = Enum.PartType.Ball
	end
	local streak = self:_emitPulse(handle.CFrame * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.16, size.Y * 0.9, size.Z * 1.4), color:Lerp(Color3.fromRGB(255, 236, 188), 0.35), 0.26, 0.06)
	if streak then
		streak.Material = Enum.Material.Neon
	end
	local core = self:_emitPulse(handle.CFrame * CFrame.new(offset), size * 0.42, Color3.fromRGB(255, 246, 224), 0.08, 0.045)
	if core then
		core.Shape = Enum.PartType.Ball
	end
	if weaponType == "Spread" then
		local blast = self:_emitPulse(handle.CFrame * CFrame.new(offset), Vector3.new(size.X * 0.65, size.Y * 0.65, size.Z * 2.1), color:Lerp(Color3.fromRGB(255, 214, 164), 0.55), 0.34, 0.08)
		if blast then
			blast.Material = Enum.Material.Neon
		end
	end
end

function MissionService:_emitImpactEffect(position, color, hitZombie, weapon)
	local impactColor = hitZombie and color:Lerp(Color3.fromRGB(255, 236, 236), 0.45) or color:Lerp(Color3.fromRGB(255, 214, 176), 0.25)
	local impactSize = Vector3.new(0.7, 0.7, 0.7)
	if weapon and (weapon.ModelStyle == "Shotgun" or weapon.WeaponType == "Spread") then
		impactSize = Vector3.new(0.92, 0.92, 0.92)
	elseif weapon and weapon.ModelStyle == "SMG" then
		impactSize = Vector3.new(0.56, 0.56, 0.56)
	end
	local spark = self:_emitPulse(CFrame.new(position), impactSize, impactColor, 0.25, 0.1)
	if spark then
		spark.Shape = Enum.PartType.Ball
	end

	local streak = self:_emitPulse(CFrame.new(position), Vector3.new(0.2, 1.4, 0.2), impactColor, 0.4, 0.12)
	if streak then
		streak.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(25))
	end
	if hitZombie then
		local ring = self:_emitPulse(CFrame.new(position), Vector3.new(0.18, impactSize.X * 1.6, impactSize.Z * 1.6), impactColor:Lerp(Color3.fromRGB(255, 250, 234), 0.35), 0.5, 0.08)
		if ring then
			ring.Material = Enum.Material.ForceField
		end
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
	local lateralKick = weapon.ModelStyle == "SMG" and 0.03 or (weapon.ModelStyle == "Pistol" and 0.018 or 0)
	local verticalLift = weapon.ModelStyle == "Shotgun" and 0.04 or (weapon.ModelStyle == "Carbine" and 0.015 or 0.01)
	local kickCFrame = originalCFrame
		* CFrame.new(lateralKick, verticalLift, recoilDistance)
		* CFrame.Angles(-recoilTwist, 0, math.rad((weapon.ModelStyle == "SMG" and 3.5 or (weapon.ModelStyle == "Shotgun" and 2 or 1.2))))
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
	local pulled = handle.CFrame * CFrame.new(0, 0.08, -1.08) * CFrame.Angles(math.rad(-6), 0, 0)
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
		self:_attachWeaponPart(tool, handle, "Frame", Vector3.new(0.56, 0.34, 1.12), CFrame.new(0, 0.12, 0.02), weapon.HandleColor, Enum.Material.SmoothPlastic)
		self:_attachWeaponPart(tool, handle, "Slide", Vector3.new(0.72, 0.24, 1.72), CFrame.new(0, 0.5, -0.22), accentColor, Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "SlideTop", Vector3.new(0.54, 0.05, 1.38), CFrame.new(0, 0.64, -0.18), Color3.fromRGB(82, 90, 102), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "DustCover", Vector3.new(0.28, 0.08, 0.74), CFrame.new(0, 0.3, -0.64), Color3.fromRGB(70, 76, 88), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Barrel", Vector3.new(0.14, 0.14, 1.02), CFrame.new(0, 0.34, -1.16), Color3.fromRGB(42, 46, 54), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "MuzzleCap", Vector3.new(0.22, 0.22, 0.18), CFrame.new(0, 0.34, -1.82), Color3.fromRGB(88, 94, 106), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "TriggerGuard", Vector3.new(0.3, 0.12, 0.26), CFrame.new(0, -0.08, -0.14), Color3.fromRGB(60, 66, 78), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Trigger", Vector3.new(0.04, 0.16, 0.08), CFrame.new(0, -0.02, -0.08), Color3.fromRGB(36, 40, 48), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "MagWell", Vector3.new(0.28, 0.12, 0.22), CFrame.new(0, -0.16, 0.16), Color3.fromRGB(50, 56, 66), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "GripPlateLeft", Vector3.new(0.07, 0.68, 0.48), CFrame.new(-0.2, -0.18, 0.14), Color3.fromRGB(24, 26, 30), Enum.Material.SmoothPlastic)
		self:_attachWeaponPart(tool, handle, "GripPlateRight", Vector3.new(0.07, 0.68, 0.48), CFrame.new(0.2, -0.18, 0.14), Color3.fromRGB(24, 26, 30), Enum.Material.SmoothPlastic)
		self:_attachWeaponPart(tool, handle, "EjectionPort", Vector3.new(0.06, 0.1, 0.24), CFrame.new(0.26, 0.48, -0.24), Color3.fromRGB(196, 204, 212), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "FrontSightBase", Vector3.new(0.1, 0.08, 0.1), CFrame.new(0, 0.66, -1.02), Color3.fromRGB(52, 56, 64), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "FrontSightDot", Vector3.new(0.05, 0.05, 0.05), CFrame.new(0, 0.73, -1.02), Color3.fromRGB(126, 255, 112), Enum.Material.Neon)
		self:_attachWeaponPart(tool, handle, "RearSightLeft", Vector3.new(0.06, 0.08, 0.12), CFrame.new(-0.1, 0.66, 0.28), Color3.fromRGB(52, 56, 64), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "RearSightRight", Vector3.new(0.06, 0.08, 0.12), CFrame.new(0.1, 0.66, 0.28), Color3.fromRGB(52, 56, 64), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "RearSightDotLeft", Vector3.new(0.04, 0.04, 0.04), CFrame.new(-0.1, 0.72, 0.28), Color3.fromRGB(126, 255, 112), Enum.Material.Neon)
		self:_attachWeaponPart(tool, handle, "RearSightDotRight", Vector3.new(0.04, 0.04, 0.04), CFrame.new(0.1, 0.72, 0.28), Color3.fromRGB(126, 255, 112), Enum.Material.Neon)
		return
	end

	if style == "Carbine" then
		self:_attachWeaponPart(tool, handle, "LowerReceiver", Vector3.new(0.66, 0.36, 1.02), CFrame.new(0, 0.14, 0.18), weapon.HandleColor, Enum.Material.SmoothPlastic)
		self:_attachWeaponPart(tool, handle, "UpperReceiver", Vector3.new(0.74, 0.22, 1.42), CFrame.new(0, 0.52, -0.18), accentColor, Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "DustCover", Vector3.new(0.4, 0.08, 0.64), CFrame.new(0.16, 0.46, -0.14), Color3.fromRGB(66, 74, 84), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Barrel", Vector3.new(0.12, 0.12, 2.92), CFrame.new(0, 0.3, -2.76), Color3.fromRGB(54, 60, 70), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "MuzzleDevice", Vector3.new(0.18, 0.18, 0.26), CFrame.new(0, 0.3, -4.26), Color3.fromRGB(94, 102, 112), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "StockTube", Vector3.new(0.16, 0.16, 1.36), CFrame.new(0, 0.28, 1.58), Color3.fromRGB(72, 78, 90), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Stock", Vector3.new(0.38, 0.58, 1.28), CFrame.new(0, 0.08, 2.18), weapon.HandleColor, Enum.Material.SmoothPlastic)
		self:_attachWeaponPart(tool, handle, "ButtPad", Vector3.new(0.4, 0.54, 0.12), CFrame.new(0, 0.08, 2.86), Color3.fromRGB(34, 38, 44), Enum.Material.Rubber)
		self:_attachWeaponPart(tool, handle, "Magazine", Vector3.new(0.24, 0.92, 0.34), CFrame.new(0, -0.6, -0.08) * CFrame.Angles(math.rad(10), 0, 0), Color3.fromRGB(42, 46, 52), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "MagWell", Vector3.new(0.32, 0.16, 0.26), CFrame.new(0, -0.18, 0.04), Color3.fromRGB(48, 54, 64), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "TopRail", Vector3.new(0.2, 0.04, 2.12), CFrame.new(0, 0.68, -0.34), Color3.fromRGB(66, 74, 86), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "RearSightBase", Vector3.new(0.14, 0.08, 0.18), CFrame.new(0, 0.76, 0.48), Color3.fromRGB(52, 58, 68), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "FrontSightBase", Vector3.new(0.08, 0.18, 0.08), CFrame.new(0, 0.74, -2.68), Color3.fromRGB(52, 58, 68), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "FrontSightDot", Vector3.new(0.04, 0.04, 0.04), CFrame.new(0, 0.86, -2.68), Color3.fromRGB(126, 255, 112), Enum.Material.Neon)
		self:_attachWeaponPart(tool, handle, "Handguard", Vector3.new(0.36, 0.26, 2.02), CFrame.new(0, 0.18, -1.92), Color3.fromRGB(34, 38, 46), Enum.Material.SmoothPlastic)
		self:_attachWeaponPart(tool, handle, "HandguardTop", Vector3.new(0.22, 0.04, 1.72), CFrame.new(0, 0.34, -1.92), Color3.fromRGB(74, 82, 94), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "SideRailLeft", Vector3.new(0.04, 0.14, 1.46), CFrame.new(-0.2, 0.18, -1.92), Color3.fromRGB(62, 70, 82), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "SideRailRight", Vector3.new(0.04, 0.14, 1.46), CFrame.new(0.2, 0.18, -1.92), Color3.fromRGB(62, 70, 82), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Foregrip", Vector3.new(0.1, 0.46, 0.12), CFrame.new(0, -0.02, -1.62), Color3.fromRGB(50, 56, 66), Enum.Material.Metal)
		return
	end

	if style == "SMG" then
		self:_attachWeaponPart(tool, handle, "Receiver", Vector3.new(0.64, 0.32, 1.52), CFrame.new(0, 0.34, -0.18), accentColor, Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "ReceiverTop", Vector3.new(0.44, 0.06, 1.3), CFrame.new(0, 0.54, -0.14), Color3.fromRGB(72, 80, 92), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "ChargingTube", Vector3.new(0.08, 0.08, 1.18), CFrame.new(0, 0.48, 0.1), Color3.fromRGB(58, 64, 74), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Barrel", Vector3.new(0.12, 0.12, 1.54), CFrame.new(0, 0.22, -1.92), Color3.fromRGB(56, 62, 72), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Muzzle", Vector3.new(0.16, 0.16, 0.16), CFrame.new(0, 0.22, -2.78), Color3.fromRGB(96, 104, 116), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Magazine", Vector3.new(0.22, 1.08, 0.3), CFrame.new(0, -0.72, -0.04), Color3.fromRGB(36, 40, 46), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "MagWell", Vector3.new(0.26, 0.14, 0.2), CFrame.new(0, -0.16, 0.06), Color3.fromRGB(50, 56, 66), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "StockArm", Vector3.new(0.1, 0.1, 1.18), CFrame.new(0, 0.34, 1.12), Color3.fromRGB(68, 74, 84), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "StockPad", Vector3.new(0.28, 0.26, 0.18), CFrame.new(0, 0.34, 1.76), Color3.fromRGB(28, 30, 36), Enum.Material.Rubber)
		self:_attachWeaponPart(tool, handle, "TopRail", Vector3.new(0.14, 0.04, 1.18), CFrame.new(0, 0.62, -0.18), Color3.fromRGB(70, 78, 92), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "RearSightBase", Vector3.new(0.12, 0.08, 0.14), CFrame.new(0, 0.68, 0.24), Color3.fromRGB(54, 60, 70), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "FrontSightBase", Vector3.new(0.06, 0.14, 0.06), CFrame.new(0, 0.64, -1.58), Color3.fromRGB(54, 60, 70), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "FrontSightDot", Vector3.new(0.04, 0.04, 0.04), CFrame.new(0, 0.74, -1.58), Color3.fromRGB(126, 255, 112), Enum.Material.Neon)
		self:_attachWeaponPart(tool, handle, "Foregrip", Vector3.new(0.1, 0.34, 0.12), CFrame.new(0, 0, -0.86), Color3.fromRGB(42, 46, 54), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "SideShroudLeft", Vector3.new(0.04, 0.16, 1.08), CFrame.new(-0.18, 0.18, -1.02), Color3.fromRGB(60, 68, 80), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "SideShroudRight", Vector3.new(0.04, 0.16, 1.08), CFrame.new(0.18, 0.18, -1.02), Color3.fromRGB(60, 68, 80), Enum.Material.Metal)
		return
	end

	if style == "Shotgun" then
		self:_attachWeaponPart(tool, handle, "Receiver", Vector3.new(0.76, 0.34, 1.68), CFrame.new(0, 0.34, -0.16), accentColor, Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "ReceiverTop", Vector3.new(0.48, 0.05, 1.1), CFrame.new(0, 0.54, -0.12), Color3.fromRGB(68, 58, 48), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "EjectionPort", Vector3.new(0.06, 0.1, 0.4), CFrame.new(0.28, 0.38, -0.22), Color3.fromRGB(198, 206, 214), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Barrel", Vector3.new(0.14, 0.14, 3.36), CFrame.new(0, 0.28, -3.02), Color3.fromRGB(60, 54, 48), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Tube", Vector3.new(0.1, 0.1, 2.82), CFrame.new(0, 0.04, -2.6), Color3.fromRGB(86, 76, 64), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Pump", Vector3.new(0.38, 0.26, 1.28), CFrame.new(0, 0.08, -1.84), weapon.HandleColor, Enum.Material.WoodPlanks)
		self:_attachWeaponPart(tool, handle, "PumpRailLeft", Vector3.new(0.04, 0.14, 1.06), CFrame.new(-0.16, 0.08, -1.84), Color3.fromRGB(72, 62, 54), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "PumpRailRight", Vector3.new(0.04, 0.14, 1.06), CFrame.new(0.16, 0.08, -1.84), Color3.fromRGB(72, 62, 54), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "HeatShield", Vector3.new(0.32, 0.08, 1.72), CFrame.new(0, 0.44, -2.06), Color3.fromRGB(64, 56, 48), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "Stock", Vector3.new(0.46, 0.56, 1.42), CFrame.new(0, 0.02, 1.8), weapon.HandleColor, Enum.Material.WoodPlanks)
		self:_attachWeaponPart(tool, handle, "StockComb", Vector3.new(0.22, 0.12, 0.8), CFrame.new(0, 0.3, 1.38), Color3.fromRGB(110, 88, 70), Enum.Material.WoodPlanks)
		self:_attachWeaponPart(tool, handle, "ButtPad", Vector3.new(0.38, 0.5, 0.12), CFrame.new(0, 0.02, 2.56), Color3.fromRGB(38, 32, 28), Enum.Material.Rubber)
		self:_attachWeaponPart(tool, handle, "FrontSightBase", Vector3.new(0.06, 0.1, 0.06), CFrame.new(0, 0.48, -4.42), Color3.fromRGB(52, 48, 42), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "FrontSightDot", Vector3.new(0.04, 0.04, 0.04), CFrame.new(0, 0.58, -4.42), Color3.fromRGB(246, 226, 168), Enum.Material.Neon)
		self:_attachWeaponPart(tool, handle, "RearSightLeft", Vector3.new(0.04, 0.06, 0.08), CFrame.new(-0.08, 0.58, 0.26), Color3.fromRGB(60, 54, 48), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "RearSightRight", Vector3.new(0.04, 0.06, 0.08), CFrame.new(0.08, 0.58, 0.26), Color3.fromRGB(60, 54, 48), Enum.Material.Metal)
		self:_attachWeaponPart(tool, handle, "ReceiverRail", Vector3.new(0.18, 0.04, 0.92), CFrame.new(0, 0.62, -0.12), Color3.fromRGB(74, 64, 54), Enum.Material.Metal)
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
			self:_emitMuzzleFlash(handle, weapon.HandleColor, weapon.WeaponType, weapon)
			self:_damageZombie(zombie, weapon.Damage, player)
			local swing = self:_emitPulse(rootPart.CFrame * CFrame.new(0, 0, -3.2) * CFrame.Angles(0, 0, math.rad(18)), Vector3.new(3.4, 0.42, 1.18), weapon.HandleColor, 0.38, 0.1)
			if swing then
				swing.Material = Enum.Material.ForceField
			end
			local afterSlash = self:_emitPulse(rootPart.CFrame * CFrame.new(0, 0.1, -2.6) * CFrame.Angles(0, 0, math.rad(-12)), Vector3.new(2.6, 0.22, 0.92), weapon.HandleColor:Lerp(Color3.fromRGB(255, 244, 224), 0.22), 0.54, 0.08)
			if afterSlash then
				afterSlash.Material = Enum.Material.Neon
			end
			rootPart.AssemblyLinearVelocity = rootPart.AssemblyLinearVelocity + (rootPart.CFrame.LookVector * 8)
			self:_fireMissionState({ player }, "Strike landed")
		else
			self:_fireMissionState({ player }, "No target in range")
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
		if state.beacon then
			state.beacon:Destroy()
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

function MissionService:_getBossProfile(mission, overrideKey)
	local modifierId = mission and mission.modifier and mission.modifier.Id or nil
	local useWarden = overrideKey == "warden_hulk" or self:_isCommanderHuntScenario(mission)
	if useWarden then
		return {
			key = "warden_hulk",
			name = "WARDEN HULK",
			displayName = "Warden Hulk",
			notifyName = "Warden Hulk",
			fillColor = Color3.fromRGB(198, 132, 96),
			outlineColor = Color3.fromRGB(255, 220, 188),
			textColor = Color3.fromRGB(255, 226, 196),
			enragedFillColor = Color3.fromRGB(255, 126, 88),
			enragedOutlineColor = Color3.fromRGB(255, 220, 188),
			enragedTextColor = Color3.fromRGB(255, 188, 164),
			weakFillColor = Color3.fromRGB(255, 220, 118),
			weakOutlineColor = Color3.fromRGB(255, 248, 214),
			weakTextColor = Color3.fromRGB(255, 242, 152),
			healthScale = self._missionConfig.Mission.WardenBossHealthScale or self._missionConfig.Mission.BossHealthScale,
			damageScale = self._missionConfig.Mission.WardenBossDamageScale or self._missionConfig.Mission.BossDamageScale,
			slamRadius = self._missionConfig.Mission.WardenBossSlamRadius or self._missionConfig.Mission.BossSlamRadius,
			slamDamage = self._missionConfig.Mission.WardenBossSlamDamage or self._missionConfig.Mission.BossSlamDamage,
			summonCount = self._missionConfig.Mission.WardenBossSummonCount or self._missionConfig.Mission.BossSummonCount,
			summonCooldown = self._missionConfig.Mission.WardenBossSummonCooldown or self._missionConfig.Mission.BossSummonCooldown,
			enrageThreshold = self._missionConfig.Mission.WardenBossEnrageThreshold or self._missionConfig.Mission.BossEnrageThreshold,
			rewardTokens = self._missionConfig.Mission.WardenBossReward or self._missionConfig.Mission.BossReward or 0,
			lootChanceScale = self._missionConfig.Mission.WardenBossLootChanceScale or self._missionConfig.Mission.BossLootChanceScale or 0.75,
			experienceBonus = self._missionConfig.Mission.WardenBossExperienceBonus or self._missionConfig.Mission.BossExperienceBonus or 0,
			primaryAbility = "slam",
			secondaryAbility = "summon",
		}
	end
	local useRelayBoss = overrideKey == "relay_overseer"
		or self:_isPowerRelayScenario(mission)
		or modifierId == "modifier_blackout"
	if useRelayBoss then
		return {
			key = "relay_overseer",
			name = "RELAY OVERSEER",
			displayName = "Relay Overseer",
			notifyName = "Relay Overseer",
			fillColor = Color3.fromRGB(116, 196, 255),
			outlineColor = Color3.fromRGB(218, 248, 255),
			textColor = Color3.fromRGB(208, 238, 255),
			enragedFillColor = Color3.fromRGB(142, 228, 255),
			enragedOutlineColor = Color3.fromRGB(228, 250, 255),
			enragedTextColor = Color3.fromRGB(222, 244, 255),
			weakFillColor = Color3.fromRGB(154, 255, 236),
			weakOutlineColor = Color3.fromRGB(226, 255, 246),
			weakTextColor = Color3.fromRGB(214, 255, 236),
			healthScale = self._missionConfig.Mission.RelayBossHealthScale or self._missionConfig.Mission.BossHealthScale,
			damageScale = self._missionConfig.Mission.RelayBossDamageScale or self._missionConfig.Mission.BossDamageScale,
			slamRadius = self._missionConfig.Mission.BossSlamRadius,
			slamDamage = self._missionConfig.Mission.BossSlamDamage,
			summonCount = 0,
			summonCooldown = self._missionConfig.Mission.RelayBossPulseCooldown or self._missionConfig.Mission.BossSummonCooldown,
			enrageThreshold = self._missionConfig.Mission.RelayBossEnrageThreshold or self._missionConfig.Mission.BossEnrageThreshold,
			rewardTokens = self._missionConfig.Mission.RelayBossReward or self._missionConfig.Mission.BossReward or 0,
			lootChanceScale = self._missionConfig.Mission.RelayBossLootChanceScale or self._missionConfig.Mission.BossLootChanceScale or 0.75,
			experienceBonus = self._missionConfig.Mission.RelayBossExperienceBonus or self._missionConfig.Mission.BossExperienceBonus or 0,
			primaryAbility = "artillery",
			primaryRange = self._missionConfig.Mission.RelayBossArtilleryRange or self._missionConfig.Mission.ArtilleryPreferredDistance,
			primaryCooldown = self._missionConfig.Mission.RelayBossArtilleryCooldown or self._missionConfig.Mission.ArtilleryVolleyCooldown,
			secondaryAbility = "pulse",
			secondaryCooldown = self._missionConfig.Mission.RelayBossPulseCooldown or self._missionConfig.Mission.ScreamerPulseCooldown or self._missionConfig.Mission.BossSummonCooldown,
		}
	end
	return {
		key = "siege_tyrant",
		name = "SIEGE TYRANT",
		displayName = "Siege Tyrant",
		notifyName = "Siege Tyrant",
		fillColor = Color3.fromRGB(255, 88, 88),
		outlineColor = Color3.fromRGB(255, 228, 196),
		textColor = Color3.fromRGB(255, 212, 188),
		enragedFillColor = Color3.fromRGB(255, 136, 96),
		enragedOutlineColor = Color3.fromRGB(255, 224, 188),
		enragedTextColor = Color3.fromRGB(255, 180, 160),
		weakFillColor = Color3.fromRGB(255, 214, 112),
		weakOutlineColor = Color3.fromRGB(255, 248, 214),
		weakTextColor = Color3.fromRGB(255, 242, 152),
		healthScale = self._missionConfig.Mission.BossHealthScale,
		damageScale = self._missionConfig.Mission.BossDamageScale,
		slamRadius = self._missionConfig.Mission.BossSlamRadius,
		slamDamage = self._missionConfig.Mission.BossSlamDamage,
		summonCount = self._missionConfig.Mission.BossSummonCount,
		summonCooldown = self._missionConfig.Mission.BossSummonCooldown,
		enrageThreshold = self._missionConfig.Mission.BossEnrageThreshold,
		rewardTokens = self._missionConfig.Mission.BossReward or 0,
		lootChanceScale = self._missionConfig.Mission.BossLootChanceScale or 0.75,
		experienceBonus = self._missionConfig.Mission.BossExperienceBonus or 0,
		primaryAbility = "slam",
		secondaryAbility = "summon",
	}
end

function MissionService:_performBossPrimaryAbility(bossProfile, zombie, root, scaledStats, targetDistance)
	local ability = bossProfile and bossProfile.primaryAbility or "slam"
	if ability == "artillery" then
		local range = bossProfile and bossProfile.primaryRange or self._missionConfig.Mission.ArtilleryPreferredDistance
		if targetDistance <= range then
			self:_artilleryBarrage(zombie, root, scaledStats)
			return true
		end
		return false
	end
	local range = bossProfile and bossProfile.slamRadius or self._missionConfig.Mission.BossSlamRadius
	if targetDistance <= range then
		self:_bossSlam(zombie, root, scaledStats)
		return true
	end
	return false
end

function MissionService:_performBossSecondaryAbility(bossProfile, zombie, root, scaledStats)
	local ability = bossProfile and bossProfile.secondaryAbility or "summon"
	if ability == "pulse" then
		self:_screamerPulse(zombie, root)
		return true
	end
	self:_bossSummonAdds(root, scaledStats)
	return true
end

function MissionService:_grantWeaponMasteryRewards(player, weaponId, previousLevel, nextLevel)
	if not player or not weaponId or nextLevel <= previousLevel then
		return
	end

	local rewardTable = self._missionConfig.WeaponMasteryRewards and self._missionConfig.WeaponMasteryRewards[weaponId]
	if type(rewardTable) ~= "table" then
		return
	end

	for level = previousLevel + 1, nextLevel do
		local reward = rewardTable[level]
		if reward and reward.itemId then
			local rewardId = ("weapon_mastery_%s_%d"):format(weaponId, level)
			if not self._persistenceService:HasClaimedReward(player, rewardId) then
				self._persistenceService:MarkRewardClaimed(player, rewardId)
				if self._inventoryService and not self._inventoryService:IsUnlocked(player, reward.itemId) then
					self._inventoryService:UnlockItem(player, reward.itemId)
				end
				self:_notifyParty({ player }, ("%s mastery Lv.%d unlocked %s."):format(
					(self._inventoryService and self._inventoryService:GetWeaponDefinition(weaponId).DisplayName) or "Weapon",
					level,
					reward.label or reward.itemId
				))
				self:_emitProgressionUpdate(player)
			end
		end
	end
end

function MissionService:_getObjectiveStateText(mission)
	if not mission then
		return "Objective: defend the bunker core"
	end
	if self:_isCommanderHuntScenario(mission) then
		return "Objective: eliminate commander"
	end
	if self:_isEvacEscortScenario(mission) then
		return "Objective: escort convoy"
	end
	if self:_isPowerRelayScenario(mission) then
		return "Objective: stabilize relay nodes"
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
	downedHighlight.FillColor = Color3.fromRGB(255, 148, 112)
	downedHighlight.OutlineColor = Color3.fromRGB(255, 226, 210)
	downedHighlight.FillTransparency = 0.44
	downedHighlight.OutlineTransparency = 0
	downedHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	downedHighlight.Parent = character

	local marker, _ = self:_createWorldMarker(character, "DownedMarker", "REVIVE NOW", Color3.fromRGB(255, 214, 164), Vector2.new(164, 38), 18)
	local markerPart = marker :: BasePart
	markerPart.CFrame = rootPart.CFrame * CFrame.new(0, 5.6, 0)
	local downedBeacon = self:_emitPulse(rootPart.CFrame * CFrame.new(0, 1.4, 0), Vector3.new(4.8, 7.2, 4.8), Color3.fromRGB(255, 172, 128), 0.76, 0.22)
	if downedBeacon then
		downedBeacon.Name = "DownedBeacon"
		downedBeacon.Material = Enum.Material.ForceField
		downedBeacon.Parent = character
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "Revive"
	prompt.ObjectText = player.DisplayName
	prompt:SetAttribute("MissionPrompt", true)
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = self._skillTreeService and self._skillTreeService:GetReviveHoldDuration(player, self._missionConfig.Mission.ReviveHoldDuration) or self._missionConfig.Mission.ReviveHoldDuration
	local reviveDistance = self._missionConfig.Mission.RevivePromptDistance or 12
	if self._skillTreeService then
		reviveDistance = self._skillTreeService:GetPromptDistance(player, reviveDistance)
	end
	prompt.MaxActivationDistance = reviveDistance
	prompt.Parent = rootPart

	local state = {
		startedAt = os.clock(),
		prompt = prompt,
		marker = marker,
		highlight = downedHighlight,
		beacon = downedBeacon,
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
		self:_notifyParty(mission.party, player.DisplayName .. " bled out.")
		self:_fireMissionState({ player }, "Eliminated. Spectating squad. Press B to return.")
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

	local profile = self:_getBossProfile(mission)
	local radius = profile.slamRadius
	local damage = profile.slamDamage
	local pulse = self:_emitPulse(root.CFrame * CFrame.new(0, -1.8, 0), Vector3.new(radius * 2, 0.35, radius * 2), Color3.fromRGB(255, 118, 96), 0.2, 0.28)
	if pulse then
		pulse.Material = Enum.Material.Neon
	end

	self:_notifyParty(mission.party, ("%s slam incoming."):format(profile.notifyName))
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

function MissionService:_spitterVolley(zombie, root, scaledStats)
	local mission = self._activeMission
	if not mission or not zombie or not zombie.Parent or not root or not root.Parent then
		return
	end

	local radius = self._missionConfig.Mission.SpitterVolleyRadius
	local damage = math.max(4, math.floor((scaledStats.damage or self._missionConfig.Mission.ZombieBaseDamage) * self._missionConfig.Mission.SpitterVolleyDamage / math.max(1, self._missionConfig.Mission.ZombieBaseDamage)))
	local splash = self:_emitPulse(root.CFrame * CFrame.new(0, -1.1, -4.8), Vector3.new(radius * 1.8, 0.22, radius * 1.8), Color3.fromRGB(142, 236, 168), 0.22, 0.2)
	if splash then
		splash.Material = Enum.Material.Neon
	end

	for _, player in ipairs(self:_getLivePartyMembers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and targetRoot and not self:_isCharacterDowned(character) and not self:_isCharacterDashing(character) and not self:_isSpawnProtected(player, character) then
			local distance = (targetRoot.Position - root.Position).Magnitude
			if distance <= radius + 6 then
				humanoid:TakeDamage(damage)
				self:_emitPlayerHitEffect(character, Color3.fromRGB(166, 244, 172))
			end
		end
	end
end

function MissionService:_screamerPulse(zombie, root)
	local mission = self._activeMission
	if not mission or not zombie or not zombie.Parent or not root or not root.Parent then
		return
	end

	local radius = self._missionConfig.Mission.ScreamerBuffRadius
	local duration = self._missionConfig.Mission.ScreamerBuffDuration
	local speedScale = self._missionConfig.Mission.ScreamerBuffSpeedScale
	local damageScale = self._missionConfig.Mission.ScreamerBuffDamageScale

	local pulse = self:_emitPulse(root.CFrame * CFrame.new(0, 1.2, 0), Vector3.new(radius * 1.8, 2.8, radius * 1.8), Color3.fromRGB(196, 142, 255), 0.3, 0.18)
	if pulse then
		pulse.Material = Enum.Material.Neon
	end
	self:_emitPulse(root.CFrame * CFrame.new(0, -1, 0), Vector3.new(radius * 2.2, 0.18, radius * 2.2), Color3.fromRGB(168, 112, 255), 0.38, 0.14)

	local buffUntil = os.clock() + duration
	for _, candidate in ipairs(mission.zombiesFolder:GetChildren()) do
		if candidate:IsA("Model") and candidate ~= zombie and candidate.Parent == mission.zombiesFolder then
			local candidateRoot = candidate.PrimaryPart or candidate:FindFirstChild("HumanoidRootPart")
			local candidateHumanoid = candidate:FindFirstChildOfClass("Humanoid")
			if candidateRoot and candidateHumanoid and candidateHumanoid.Health > 0 and (candidateRoot.Position - root.Position).Magnitude <= radius then
				local currentUntil = tonumber(candidate:GetAttribute("ScreamBuffUntil")) or 0
				if buffUntil > currentUntil then
					local baseSpeed = tonumber(candidate:GetAttribute("BaseWalkSpeed")) or candidateHumanoid.WalkSpeed
					local baseDamage = tonumber(candidate:GetAttribute("BaseZombieDamage")) or tonumber(candidate:GetAttribute("ZombieDamage")) or self._missionConfig.Mission.ZombieBaseDamage
					local baseObjectiveDamage = tonumber(candidate:GetAttribute("BaseObjectiveDamage")) or tonumber(candidate:GetAttribute("ObjectiveDamage")) or math.max(4, math.floor(baseDamage * 0.7))
					candidate:SetAttribute("ScreamBuffUntil", buffUntil)
					candidate:SetAttribute("ZombieDamage", math.max(baseDamage, math.floor(baseDamage * damageScale)))
					candidate:SetAttribute("ObjectiveDamage", math.max(baseObjectiveDamage, math.floor(baseObjectiveDamage * damageScale)))
					candidateHumanoid.WalkSpeed = math.max(candidateHumanoid.WalkSpeed, baseSpeed * speedScale)
					self:_emitPulse(candidateRoot.CFrame, Vector3.new(1.7, 1.7, 1.7), Color3.fromRGB(202, 154, 255), 0.42, 0.1)
					task.delay(duration + 0.05, function()
						if not candidate.Parent then
							return
						end
						local restoredHumanoid = candidate:FindFirstChildOfClass("Humanoid")
						if not restoredHumanoid or restoredHumanoid.Health <= 0 then
							return
						end
						local activeUntil = tonumber(candidate:GetAttribute("ScreamBuffUntil")) or 0
						if activeUntil > os.clock() then
							return
						end
						local restoreSpeed = tonumber(candidate:GetAttribute("BaseWalkSpeed")) or restoredHumanoid.WalkSpeed
						local restoreDamage = tonumber(candidate:GetAttribute("BaseZombieDamage")) or tonumber(candidate:GetAttribute("ZombieDamage")) or self._missionConfig.Mission.ZombieBaseDamage
						local restoreObjective = tonumber(candidate:GetAttribute("BaseObjectiveDamage")) or tonumber(candidate:GetAttribute("ObjectiveDamage")) or math.max(4, math.floor(restoreDamage * 0.7))
						restoredHumanoid.WalkSpeed = restoreSpeed
						candidate:SetAttribute("ZombieDamage", restoreDamage)
						candidate:SetAttribute("ObjectiveDamage", restoreObjective)
					end)
				end
			end
		end
	end

	if mission.party then
		self:_fireMissionState(mission.party, "Screamer pulse")
	end
end

function MissionService:_artilleryBarrage(zombie, root, scaledStats)
	local mission = self._activeMission
	if not mission or not zombie or not zombie.Parent or not root or not root.Parent then
		return
	end

	local radius = self._missionConfig.Mission.ArtilleryVolleyRadius
	local damage = math.max(8, math.floor((scaledStats.damage or self._missionConfig.Mission.ZombieBaseDamage) * self._missionConfig.Mission.ArtilleryDamageScale))
	local targetPosition = root.Position + (root.CFrame.LookVector * 8)
	local shell = self:_emitPulse(CFrame.new(targetPosition + Vector3.new(0, 5.5, 0)), Vector3.new(radius * 0.6, 5.4, radius * 0.6), Color3.fromRGB(255, 182, 104), 0.48, 0.12)
	if shell then
		shell.Material = Enum.Material.Neon
	end

	task.wait(0.28)
	if not self._activeMission or self._activeMission ~= mission or not zombie.Parent or not root.Parent then
		return
	end

	local blast = self:_emitPulse(CFrame.new(targetPosition), Vector3.new(radius * 2.1, 0.4, radius * 2.1), Color3.fromRGB(255, 164, 96), 0.2, 0.2)
	if blast then
		blast.Material = Enum.Material.ForceField
	end

	local objective = self:_getMissionObjective()
	if objective and (objective.Position - targetPosition).Magnitude <= radius + 5 then
		self:_damageObjective(math.max(6, math.floor(damage * 0.9)))
	end

	for _, player in ipairs(self:_getLivePartyMembers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and targetRoot and not self:_isCharacterDowned(character) and not self:_isCharacterDashing(character) and not self:_isSpawnProtected(player, character) then
			local offset = targetRoot.Position - targetPosition
			local distance = offset.Magnitude
			if distance <= radius then
				humanoid:TakeDamage(damage)
				self:_emitPlayerHitEffect(character, Color3.fromRGB(255, 196, 118))
				if distance > 0.1 then
					targetRoot.AssemblyLinearVelocity = offset.Unit * 24 + Vector3.new(0, 18, 0)
				end
			end
		end
	end
end

function MissionService:_exploderBurst(zombie, root, scaledStats)
	local mission = self._activeMission
	if not mission or not zombie or not zombie.Parent or not root or not root.Parent then
		return
	end
	if zombie:GetAttribute("Detonated") == true then
		return
	end

	zombie:SetAttribute("Detonated", true)
	local radius = self._missionConfig.Mission.ExploderBlastRadius
	local damage = math.max(self._missionConfig.Mission.ExploderBlastDamage or 10, math.floor((scaledStats.damage or self._missionConfig.Mission.ZombieBaseDamage) * self._missionConfig.Mission.ExploderDamageScale))
	local pulse = self:_emitPulse(root.CFrame * CFrame.new(0, -0.8, 0), Vector3.new(radius * 2.2, 1.4, radius * 2.2), Color3.fromRGB(255, 172, 96), 0.18, 0.2)
	if pulse then
		pulse.Material = Enum.Material.ForceField
	end

	local objective = self:_getMissionObjective()
	if objective and (objective.Position - root.Position).Magnitude <= radius + 5 then
		self:_damageObjective(math.max(5, math.floor(damage * (self._missionConfig.Mission.ExploderObjectiveDamageScale or 1))))
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
				self:_emitPlayerHitEffect(character, Color3.fromRGB(255, 188, 112))
				if distance > 0.1 then
					targetRoot.AssemblyLinearVelocity = offset.Unit * 28 + Vector3.new(0, 16, 0)
				end
			end
		end
	end

	local humanoid = zombie:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end

function MissionService:_bruiseCharge(zombie, root, targetRoot)
	if not zombie or not zombie.Parent or not root or not root.Parent or not targetRoot then
		return
	end

	local direction = targetRoot.Position - root.Position
	if direction.Magnitude <= 0.01 then
		return
	end

	self:_emitPulse(root.CFrame, Vector3.new(2.8, 2.8, 2.8), Color3.fromRGB(236, 168, 104), 0.34, 0.12)
	root.AssemblyLinearVelocity = direction.Unit * self._missionConfig.Mission.BruiserChargeSpeed + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
end

function MissionService:_bossSummonAdds(root, scaledStats)
	local mission = self._activeMission
	if not mission or not root or not root.Parent then
		return
	end

	local profile = self:_getBossProfile(mission)
	local count = profile.summonCount or self._missionConfig.Mission.BossSummonCount
	if count <= 0 then
		return
	end
	self:_notifyParty(mission.party, ("%s is calling reinforcements."):format(profile.notifyName))
	for summonIndex = 1, count do
		local angle = (math.pi * 2 / count) * summonIndex
		local offset = Vector3.new(math.cos(angle) * 11, 0, math.sin(angle) * 11)
		mission.remainingZombies += 1
		mission.waveTargetHostiles = (mission.waveTargetHostiles or 0) + 1
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
	if self:_isCommanderHuntScenario() then
		safeColor = Color3.fromRGB(198, 164, 122)
		dangerColor = Color3.fromRGB(236, 108, 96)
	elseif self:_isEvacEscortScenario() then
		safeColor = Color3.fromRGB(122, 198, 176)
		dangerColor = Color3.fromRGB(236, 138, 96)
	elseif self:_isPowerRelayScenario() then
		safeColor = Color3.fromRGB(108, 196, 214)
		dangerColor = Color3.fromRGB(234, 132, 96)
	elseif self:_isPowerCellScenario() then
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
			if self:_isCommanderHuntScenario() then
				local eliminated = objective:GetAttribute("CommanderEliminated") == true
				label.Text = eliminated and ("COMMANDER DOWN  %d%%"):format(math.floor(healthRatio * 100)) or ("COMMANDER LIVE  %d%%"):format(math.floor(healthRatio * 100))
			elseif self:_isEvacEscortScenario() then
				local reached = objective:GetAttribute("ReachedEvacCheckpoint") or 0
				local required = objective:GetAttribute("RequiredEvacCheckpoints") or 3
				label.Text = ("EVAC ESCORT %d/%d  %d%%"):format(reached, required, math.floor(healthRatio * 100))
			elseif self:_isPowerRelayScenario() then
				local stabilized = objective:GetAttribute("StabilizedRelayNodes") or 0
				local required = objective:GetAttribute("RequiredRelayNodes") or 3
				label.Text = ("POWER RELAY %d/%d  %d%%"):format(stabilized, required, math.floor(healthRatio * 100))
			elseif self:_isPowerCellScenario() then
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
	local supplyDistance = self._missionConfig.Mission.SupplyPickupPromptDistance or 14
	prompt.MaxActivationDistance = supplyDistance
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
		local objectiveDistance = self._missionConfig.Mission.ObjectivePromptDistance or 14
		prompt.MaxActivationDistance = objectiveDistance
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

function MissionService:_stabilizeRelayNode(node, player)
	local mission = self._activeMission
	local objective = self:_getMissionObjective()
	if not mission or not objective or not node or not node.Parent or not self:_isPowerRelayScenario(mission) then
		return false
	end

	if node:GetAttribute("Stabilized") == true then
		return false
	end

	node:SetAttribute("Stabilized", true)
	local stabilized = (objective:GetAttribute("StabilizedRelayNodes") or 0) + 1
	local required = objective:GetAttribute("RequiredRelayNodes") or 3
	objective:SetAttribute("StabilizedRelayNodes", stabilized)
	self:_refreshObjectiveVisuals()

	local core = node:FindFirstChild("Core")
	if core and core:IsA("BasePart") then
		core.Color = Color3.fromRGB(134, 246, 220)
	end

	local ring = node:FindFirstChild("Ring")
	if ring and ring:IsA("BasePart") then
		ring.Color = Color3.fromRGB(122, 255, 228)
		ring.Transparency = 0.32
	end

	local prompt = node:FindFirstChild("StabilizePrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = false
	end

	local marker = node:FindFirstChild("NodeMarker")
	local markerGui = marker and marker:FindFirstChildOfClass("BillboardGui")
	local frame = markerGui and markerGui:FindFirstChildOfClass("Frame")
	local label = frame and frame:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = "NODE STABLE"
		label.TextColor3 = Color3.fromRGB(186, 255, 232)
	end

	self:_notifyParty(mission.party, ("%s stabilized a relay node (%d/%d)."):format(player.DisplayName, stabilized, required))
	self:_fireMissionState(mission.party, ("Relay nodes stabilized %d/%d"):format(stabilized, required))

	if stabilized >= required and mission.wave >= self._missionConfig.Mission.WaveCount and mission.remainingZombies <= 0 then
		self:_completeMission()
	end

	return true
end

function MissionService:_spawnRelayNode(runtime, position, nodeId)
	local node = Instance.new("Model")
	node.Name = "RelayNode_" .. tostring(nodeId)
	node:SetAttribute("Stabilized", false)
	node.Parent = runtime

	local pad = Instance.new("Part")
	pad.Name = "Pad"
	pad.Size = Vector3.new(6.5, 1.2, 6.5)
	pad.Anchored = true
	pad.CanCollide = true
	pad.Material = Enum.Material.Metal
	pad.Color = Color3.fromRGB(86, 94, 110)
	pad.CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0))
	pad.Parent = node

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(2.6, 2.6, 2.6)
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.Material = Enum.Material.Neon
	core.Color = Color3.fromRGB(250, 182, 112)
	core.CFrame = pad.CFrame * CFrame.new(0, 2.5, 0)
	core.Parent = node

	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Size = Vector3.new(8.4, 0.14, 8.4)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 210, 144)
	ring.Transparency = 0.62
	ring.CFrame = pad.CFrame * CFrame.new(0, -0.52, 0)
	ring.Parent = node

	local marker, _ = self:_createWorldMarker(node, "NodeMarker", "STABILIZE NODE", Color3.fromRGB(255, 228, 176), Vector2.new(146, 30), 14)
	marker.CFrame = core.CFrame * CFrame.new(0, 4.4, 0)
	local markerGui = marker:FindFirstChildOfClass("BillboardGui")
	if markerGui then
		markerGui.MaxDistance = 34
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StabilizePrompt"
	prompt.ActionText = "Stabilize"
	prompt.ObjectText = "Relay Node"
	prompt:SetAttribute("MissionPrompt", true)
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = self._missionConfig.Mission.RelayStabilizeHoldDuration or 0.65
	prompt.MaxActivationDistance = self._missionConfig.Mission.ObjectivePromptDistance or 14
	prompt.Parent = pad

	prompt.Triggered:Connect(function(player)
		if not self._activeMission or not player or player.Parent ~= Players then
			return
		end

		self:_stabilizeRelayNode(node, player)
	end)
end

function MissionService:_spawnPowerRelayObjective(runtime, objective)
	local missionSpawn = self:_getMissionSpawn()
	if not missionSpawn then
		return
	end

	local layout = self:_getActiveLayout()
	local positions = {}
	for _, offset in ipairs((layout and layout.PowerCellOffsets) or {}) do
		table.insert(positions, self:_getLayoutWorldPosition(offset))
	end
	if #positions == 0 then
		positions = {
			missionSpawn.Position + Vector3.new(-24, 0, 18),
			missionSpawn.Position + Vector3.new(24, 0, 10),
			missionSpawn.Position + Vector3.new(0, 0, 48),
		}
	end

	local required = math.max(1, #positions)
	objective:SetAttribute("StabilizedRelayNodes", 0)
	objective:SetAttribute("RequiredRelayNodes", required)

	for index, position in ipairs(positions) do
		self:_spawnRelayNode(runtime, position, index)
	end
end

function MissionService:_advanceEvacCheckpoint(checkpoint, player)
	local mission = self._activeMission
	local objective = self:_getMissionObjective()
	if not mission or not objective or not checkpoint or not checkpoint.Parent or not self:_isEvacEscortScenario(mission) then
		return false
	end

	if checkpoint:GetAttribute("Secured") == true then
		return false
	end

	checkpoint:SetAttribute("Secured", true)
	local reached = (objective:GetAttribute("ReachedEvacCheckpoint") or 0) + 1
	local required = objective:GetAttribute("RequiredEvacCheckpoints") or 3
	objective:SetAttribute("ReachedEvacCheckpoint", reached)
	self:_refreshObjectiveVisuals()

	local gate = checkpoint:FindFirstChild("Gate")
	if gate and gate:IsA("BasePart") then
		gate.Color = Color3.fromRGB(118, 212, 168)
	end

	local ring = checkpoint:FindFirstChild("Ring")
	if ring and ring:IsA("BasePart") then
		ring.Color = Color3.fromRGB(126, 255, 214)
		ring.Transparency = 0.34
	end

	local prompt = checkpoint:FindFirstChild("AdvancePrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = false
	end

	local marker = checkpoint:FindFirstChild("CheckpointMarker")
	local markerGui = marker and marker:FindFirstChildOfClass("BillboardGui")
	local frame = markerGui and markerGui:FindFirstChildOfClass("Frame")
	local label = frame and frame:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = "CHECKPOINT SECURE"
		label.TextColor3 = Color3.fromRGB(196, 255, 228)
	end

	local convoy = mission.runtime and mission.runtime:FindFirstChild("EvacConvoy")
	local convoyBase = convoy and convoy:FindFirstChild("ConvoyBase")
	if convoyBase and convoyBase:IsA("BasePart") then
		local pivotOffset = convoy:GetAttribute("ConvoyPivotOffsetZ") or 0
		local newCFrame = checkpoint:GetPivot() * CFrame.new(0, 0.6, pivotOffset)
		convoy:PivotTo(newCFrame)
	end

	self:_notifyParty(mission.party, ("%s secured evac checkpoint %d/%d."):format(player.DisplayName, reached, required))
	self:_fireMissionState(mission.party, ("Evac checkpoints secured %d/%d"):format(reached, required))

	if reached >= required and mission.wave >= self._missionConfig.Mission.WaveCount and mission.remainingZombies <= 0 then
		self:_completeMission()
	end

	return true
end

function MissionService:_spawnEvacCheckpoint(runtime, position, checkpointId)
	local checkpoint = Instance.new("Model")
	checkpoint.Name = "EvacCheckpoint_" .. tostring(checkpointId)
	checkpoint:SetAttribute("Secured", false)
	checkpoint.Parent = runtime

	local gate = Instance.new("Part")
	gate.Name = "Gate"
	gate.Size = Vector3.new(18, 7, 3.2)
	gate.Anchored = true
	gate.CanCollide = true
	gate.Material = Enum.Material.Metal
	gate.Color = Color3.fromRGB(96, 106, 118)
	gate.CFrame = CFrame.new(position + Vector3.new(0, 3.5, 0))
	gate.Parent = checkpoint

	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Size = Vector3.new(22, 0.14, 12)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(196, 224, 182)
	ring.Transparency = 0.62
	ring.CFrame = gate.CFrame * CFrame.new(0, -3.44, 0)
	ring.Parent = checkpoint

	local marker, _ = self:_createWorldMarker(checkpoint, "CheckpointMarker", "SECURE CHECKPOINT", Color3.fromRGB(214, 244, 196), Vector2.new(166, 30), 14)
	marker.CFrame = gate.CFrame * CFrame.new(0, 4.8, 0)
	local markerGui = marker:FindFirstChildOfClass("BillboardGui")
	if markerGui then
		markerGui.MaxDistance = 38
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "AdvancePrompt"
	prompt.ActionText = "Advance Convoy"
	prompt.ObjectText = "Evac Checkpoint"
	prompt:SetAttribute("MissionPrompt", true)
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = self._missionConfig.Mission.EvacCheckpointHoldDuration or 0.8
	prompt.MaxActivationDistance = self._missionConfig.Mission.ObjectivePromptDistance or 14
	prompt.Parent = gate

	prompt.Triggered:Connect(function(player)
		if not self._activeMission or not player or player.Parent ~= Players then
			return
		end

		self:_advanceEvacCheckpoint(checkpoint, player)
	end)
end

function MissionService:_spawnEvacEscortObjective(runtime, objective)
	local missionSpawn = self:_getMissionSpawn()
	if not missionSpawn then
		return
	end

	local layout = self:_getActiveLayout()
	local objectiveOffset = layout and layout.ObjectiveOffset or Vector3.new(0, 0, 28)
	local extractionOffset = layout and layout.ExtractionOffset or Vector3.new(0, 0, 72)
	local escortPath = {
		objectiveOffset + Vector3.new(0, 0, -54),
		objectiveOffset + Vector3.new(0, 0, -20),
		objectiveOffset,
	}

	local required = #escortPath
	objective:SetAttribute("ReachedEvacCheckpoint", 0)
	objective:SetAttribute("RequiredEvacCheckpoints", required)

	local convoy = Instance.new("Model")
	convoy.Name = "EvacConvoy"
	convoy.Parent = runtime

	local convoyBase = Instance.new("Part")
	convoyBase.Name = "ConvoyBase"
	convoyBase.Size = Vector3.new(10, 3, 16)
	convoyBase.Anchored = true
	convoyBase.CanCollide = true
	convoyBase.Material = Enum.Material.Metal
	convoyBase.Color = Color3.fromRGB(82, 96, 118)
	convoyBase.CFrame = missionSpawn.CFrame * CFrame.new(objectiveOffset + Vector3.new(0, 0.6, -66))
	convoyBase.Parent = convoy

	local convoyCanopy = Instance.new("Part")
	convoyCanopy.Name = "ConvoyCanopy"
	convoyCanopy.Size = Vector3.new(8, 1.2, 10)
	convoyCanopy.Anchored = true
	convoyCanopy.CanCollide = true
	convoyCanopy.Material = Enum.Material.Metal
	convoyCanopy.Color = Color3.fromRGB(104, 118, 138)
	convoyCanopy.CFrame = convoyBase.CFrame * CFrame.new(0, 3.2, 0)
	convoyCanopy.Parent = convoy

	local convoyGlow = Instance.new("Part")
	convoyGlow.Name = "ConvoyGlow"
	convoyGlow.Size = Vector3.new(14, 0.14, 20)
	convoyGlow.Anchored = true
	convoyGlow.CanCollide = false
	convoyGlow.CanQuery = false
	convoyGlow.Material = Enum.Material.Neon
	convoyGlow.Color = Color3.fromRGB(160, 244, 210)
	convoyGlow.Transparency = 0.72
	convoyGlow.CFrame = convoyBase.CFrame * CFrame.new(0, -1.44, 0)
	convoyGlow.Parent = convoy

	local convoyMarker, _ = self:_createWorldMarker(convoy, "ConvoyMarker", "EVAC CONVOY", Color3.fromRGB(206, 255, 232), Vector2.new(144, 30), 14)
	convoyMarker.CFrame = convoyBase.CFrame * CFrame.new(0, 5.2, 0)
	convoy.PrimaryPart = convoyBase
	convoy:SetAttribute("ConvoyPivotOffsetZ", -8)

	for index, offset in ipairs(escortPath) do
		self:_spawnEvacCheckpoint(runtime, self:_getLayoutWorldPosition(offset), index)
	end

	objective:SetAttribute("EvacExtractionOffsetZ", extractionOffset.Z)
end

function MissionService:_eliminateCommander(commander, player)
	local mission = self._activeMission
	local objective = self:_getMissionObjective()
	if not mission or not objective or not commander or not commander.Parent or not self:_isCommanderHuntScenario(mission) then
		return false
	end

	if objective:GetAttribute("CommanderEliminated") == true then
		return false
	end

	objective:SetAttribute("CommanderEliminated", true)
	self:_refreshObjectiveVisuals()
	self:_emitPulse(commander:GetPivot(), Vector3.new(12, 8, 12), Color3.fromRGB(255, 154, 124), 0.34, 0.22)
	self:_notifyParty(mission.party, ("%s eliminated the blacksite commander."):format(player and player.DisplayName or "The squad"))
	self:_fireMissionState(mission.party, "Commander eliminated")

	if mission.wave >= self._missionConfig.Mission.WaveCount and mission.remainingZombies <= 0 then
		self:_completeMission()
	end

	return true
end

function MissionService:_spawnCommanderTarget(runtime, position)
	local commander = Instance.new("Model")
	commander.Name = "BlacksiteCommander"
	commander.Parent = runtime

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(4, 4, 2.4)
	root.Anchored = true
	root.CanCollide = true
	root.Material = Enum.Material.Slate
	root.Color = Color3.fromRGB(112, 60, 60)
	root.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
	root.Parent = commander

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(4.8, 5.6, 2.8)
	torso.Anchored = true
	torso.CanCollide = true
	torso.Material = Enum.Material.SmoothPlastic
	torso.Color = Color3.fromRGB(156, 72, 72)
	torso.CFrame = root.CFrame * CFrame.new(0, 3, 0)
	torso.Parent = commander

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2.6, 2.6, 2.6)
	head.Anchored = true
	head.CanCollide = true
	head.Material = Enum.Material.SmoothPlastic
	head.Color = Color3.fromRGB(222, 126, 118)
	head.CFrame = torso.CFrame * CFrame.new(0, 3.5, 0)
	head.Parent = commander

	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Size = Vector3.new(10, 0.14, 10)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 176, 142)
	ring.Transparency = 0.54
	ring.CFrame = root.CFrame * CFrame.new(0, -2.02, 0)
	ring.Parent = commander

	local aura = Instance.new("Highlight")
	aura.Name = "CommanderAura"
	aura.FillColor = Color3.fromRGB(184, 82, 82)
	aura.OutlineColor = Color3.fromRGB(255, 206, 176)
	aura.FillTransparency = 0.7
	aura.OutlineTransparency = 0.08
	aura.DepthMode = Enum.HighlightDepthMode.Occluded
	aura.Parent = commander

	local marker, _ = self:_createWorldMarker(commander, "CommanderMarker", "ELIMINATE COMMANDER", Color3.fromRGB(255, 208, 176), Vector2.new(180, 30), 14)
	marker.CFrame = head.CFrame * CFrame.new(0, 4.2, 0)
	local markerGui = marker:FindFirstChildOfClass("BillboardGui")
	if markerGui then
		markerGui.MaxDistance = 44
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EliminatePrompt"
	prompt.ActionText = "Finish Commander"
	prompt.ObjectText = "Blacksite Commander"
	prompt:SetAttribute("MissionPrompt", true)
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = self._missionConfig.Mission.CommanderFinishHoldDuration or 0.9
	prompt.MaxActivationDistance = self._missionConfig.Mission.ObjectivePromptDistance or 14
	prompt.Parent = torso

	prompt.Triggered:Connect(function(player)
		if not self._activeMission or not player or player.Parent ~= Players then
			return
		end

		if self:_eliminateCommander(commander, player) then
			commander:Destroy()
		end
	end)
end

function MissionService:_spawnCommanderHuntObjective(runtime, objective)
	local layout = self:_getActiveLayout()
	local objectiveOffset = layout and layout.ObjectiveOffset or Vector3.new(0, 0, 58)
	objective:SetAttribute("CommanderEliminated", false)
	self:_spawnCommanderTarget(runtime, self:_getLayoutWorldPosition(objectiveOffset + Vector3.new(0, 0, 20)))
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
	local objectiveDistance = self._missionConfig.Mission.ObjectivePromptDistance or 14
	prompt.MaxActivationDistance = objectiveDistance
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
					local shellReloadTime = weapon.ShellReloadTime or math.max(0.25, (weapon.ReloadTime or 1.6) / math.max(1, weapon.MagazineSize or 1))
					if self._skillTreeService then
						shellReloadTime = self._skillTreeService:GetReloadDuration(player, shellReloadTime)
					end
					task.wait(shellReloadTime)
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
			local reloadDuration = weapon.ReloadTime or 1
			if self._skillTreeService then
				reloadDuration = self._skillTreeService:GetReloadDuration(player, reloadDuration)
			end
			task.delay(reloadDuration, function()
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
					if self._skillTreeService then
						spreadValue *= self._skillTreeService:GetWeaponSpreadMultiplier(player)
					end
					local spread = Vector3.new(math.random(-100, 100) / 100 * spreadValue, math.random(-100, 100) / 100 * spreadValue, math.random(-100, 100) / 100 * spreadValue)
					pelletDirection = (rootPart.CFrame.LookVector + spread).Unit * weapon.Range
				elseif weapon.HipSpread and weapon.HipSpread > 0 then
					local spreadValue = weapon.HipSpread
					if self._skillTreeService then
						spreadValue *= self._skillTreeService:GetWeaponSpreadMultiplier(player)
					end
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
				self:_emitTracer(origin, hitPosition, weapon.HandleColor, weapon)
				self:_emitImpactEffect(hitPosition, weapon.HandleColor, hitZombie ~= nil, weapon)

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
	player:SetAttribute("MissionAmmoCrates", player:GetAttribute("MissionAmmoCrates") or self._missionConfig.Mission.SquadAmmoCrateCount or 1)
	player:SetAttribute("MissionSensorBeacons", player:GetAttribute("MissionSensorBeacons") or self._missionConfig.Mission.SensorBeaconCount or 1)
	player:SetAttribute("MissionBarriers", player:GetAttribute("MissionBarriers") or self._missionConfig.Mission.BarrierCount or 1)
	player:SetAttribute("MissionReviveStims", player:GetAttribute("MissionReviveStims") or self._missionConfig.Mission.ReviveStimCount or 1)

	local maxHealth = 100 + self._inventoryService:GetMaxHealthBonus(player)
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
	humanoid.WalkSpeed = 16
	character:SetAttribute("MissionDashing", false)
end

function MissionService:_grantAmmoUtility(player, amount)
	local state = self._weaponState[player.UserId]
	if not state then
		return false
	end

	local weapon = self._inventoryService:GetWeaponDefinition(state.weaponId)
	if weapon.WeaponType == "Melee" then
		return false
	end

	state.reserveAmmo += math.max(1, math.floor(amount or 0))
	return true
end

function MissionService:_markZombieWithSensor(zombie, duration)
	if not zombie or not zombie.Parent then
		return
	end

	local existing = zombie:FindFirstChild("SensorReveal")
	if existing then
		existing:Destroy()
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "SensorReveal"
	highlight.FillColor = Color3.fromRGB(108, 214, 255)
	highlight.OutlineColor = Color3.fromRGB(214, 248, 255)
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0.08
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = zombie
	Debris:AddItem(highlight, duration or 1.5)
end

function MissionService:_deploySensorBeacon(player, rootPart)
	local mission = self._activeMission
	if not mission or not mission.runtime or not rootPart then
		return false
	end

	local duration = self._missionConfig.Mission.SensorBeaconDuration or 12
	local radius = self._missionConfig.Mission.SensorBeaconRadius or 42
	local pulseInterval = self._missionConfig.Mission.SensorBeaconPulseInterval or 1.8
	local beacon = Instance.new("Part")
	beacon.Name = ("SensorBeacon_%d"):format(player.UserId)
	beacon.Size = Vector3.new(1.4, 2.8, 1.4)
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.Material = Enum.Material.Neon
	beacon.Color = Color3.fromRGB(122, 226, 255)
	beacon.CFrame = CFrame.new(self:_getContainedSpawnPosition(rootPart.Position, 4) + Vector3.new(0, 1.4, 0))
	beacon.Parent = mission.runtime

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(162, 238, 255)
	light.Brightness = 1.6
	light.Range = 18
	light.Parent = beacon

	Debris:AddItem(beacon, duration + 0.5)
	self:_emitPulse(beacon.CFrame, Vector3.new(4, 4, 4), Color3.fromRGB(132, 228, 255), 0.4, 0.16)

	task.spawn(function()
		local expiresAt = os.clock() + duration
		while self._activeMission == mission and beacon.Parent and os.clock() < expiresAt do
			self:_emitPulse(beacon.CFrame * CFrame.new(0, -1.2, 0), Vector3.new(radius * 2, 0.16, radius * 2), Color3.fromRGB(112, 224, 255), 0.78, 0.22)
			for _, zombie in ipairs(mission.zombiesFolder:GetChildren()) do
				if zombie:IsA("Model") then
					local zombieRoot = zombie.PrimaryPart or zombie:FindFirstChild("HumanoidRootPart")
					local zombieHumanoid = zombie:FindFirstChildOfClass("Humanoid")
					if zombieRoot and zombieHumanoid and zombieHumanoid.Health > 0 and (zombieRoot.Position - beacon.Position).Magnitude <= radius then
						self:_markZombieWithSensor(zombie, math.min(pulseInterval + 0.25, 2.2))
					end
				end
			end
			task.wait(pulseInterval)
		end
	end)

	return true
end

function MissionService:_deployBarrier(player, rootPart)
	local mission = self._activeMission
	if not mission or not mission.runtime or not rootPart then
		return false
	end

	local forward = rootPart.CFrame.LookVector
	if forward.Magnitude <= 0.01 then
		forward = Vector3.new(0, 0, -1)
	end
	local barrier = Instance.new("Part")
	barrier.Name = ("SquadBarrier_%d"):format(player.UserId)
	barrier.Size = Vector3.new(9, 5, 1.2)
	barrier.Anchored = true
	barrier.CanCollide = true
	barrier.CanQuery = true
	barrier.Material = Enum.Material.ForceField
	barrier.Color = Color3.fromRGB(118, 196, 255)
	local barrierPosition = self:_getContainedSpawnPosition(rootPart.Position + forward.Unit * 7, 6) + Vector3.new(0, 2.5, 0)
	barrier.CFrame = CFrame.lookAt(barrierPosition, barrierPosition + forward.Unit)
	barrier.Parent = mission.runtime
	barrier:SetAttribute("BarrierHealth", self._missionConfig.Mission.BarrierHealth or 420)

	local frame = Instance.new("SelectionBox")
	frame.Name = "BarrierFrame"
	frame.Color3 = Color3.fromRGB(198, 238, 255)
	frame.LineThickness = 0.05
	frame.SurfaceTransparency = 0.82
	frame.Adornee = barrier
	frame.Parent = barrier

	self:_emitPulse(barrier.CFrame, Vector3.new(10, 6, 4), Color3.fromRGB(122, 202, 255), 0.52, 0.16)
	Debris:AddItem(barrier, self._missionConfig.Mission.BarrierDuration or 14)
	return true
end

function MissionService:_useReviveStim(player)
	local mission = self._activeMission
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not mission or not rootPart then
		return false
	end

	local radius = self._missionConfig.Mission.ReviveStimRadius or 14
	local nearestPlayer = nil
	local nearestDistance = math.huge
	for userId in pairs(mission.downedStates or {}) do
		local candidate = Players:GetPlayerByUserId(userId)
		local candidateCharacter = candidate and candidate.Character
		local candidateRoot = candidateCharacter and candidateCharacter:FindFirstChild("HumanoidRootPart")
		if candidate and candidate ~= player and candidateRoot and self:_isCharacterDowned(candidateCharacter) then
			local distance = (candidateRoot.Position - rootPart.Position).Magnitude
			if distance <= radius and distance < nearestDistance then
				nearestDistance = distance
				nearestPlayer = candidate
			end
		end
	end

	if not nearestPlayer then
		return false
	end

	self:_clearDownedState(nearestPlayer, true)
	self:_emitPulse(rootPart.CFrame * CFrame.new(0, 0.5, 0), Vector3.new(radius * 1.4, 3.2, radius * 1.4), Color3.fromRGB(156, 244, 182), 0.5, 0.18)
	self:_notifyParty(mission.party, ("%s stim-revived %s."):format(player.DisplayName, nearestPlayer.DisplayName))
	self:_fireMissionState(mission.party, ("%s revived"):format(nearestPlayer.DisplayName))
	return true
end

function MissionService:_createAmmoCrateTool(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local existing = backpack:FindFirstChild("MissionAmmoCrate")
	if existing then
		existing:Destroy()
	end

	local character = player.Character
	if character then
		local equipped = character:FindFirstChild("MissionAmmoCrate")
		if equipped then
			equipped:Destroy()
		end
	end

	local tool = Instance.new("Tool")
	tool.Name = "MissionAmmoCrate"
	tool.ToolTip = "Ammo Crate"
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1.2, 0.9, 1.2)
	handle.Material = Enum.Material.Metal
	handle.Color = Color3.fromRGB(106, 136, 184)
	handle.Parent = tool

	local function refreshState()
		local count = player:GetAttribute("MissionAmmoCrates") or 0
		tool.ToolTip = ("Ammo Crate x%d"):format(count)
		tool.Enabled = count > 0
	end

	tool.Equipped:Connect(function()
		refreshState()
	end)

	tool.Activated:Connect(function()
		local characterNow = player.Character
		local rootPart = characterNow and characterNow:FindFirstChild("HumanoidRootPart")
		local humanoid = characterNow and characterNow:FindFirstChildOfClass("Humanoid")
		if not rootPart or not humanoid or humanoid.Health <= 0 or self:_isCharacterDowned(characterNow) then
			return
		end

		local count = player:GetAttribute("MissionAmmoCrates") or 0
		if count <= 0 then
			return
		end

		local bonus = self._missionConfig.Mission.SquadAmmoCrateAmmoBonus or 18
		local radius = self._missionConfig.Mission.SquadAmmoCrateRadius or 24
		local helpedPlayers = 0
		for _, squadmate in ipairs(self:_getLivePartyMembers()) do
			local squadCharacter = squadmate.Character
			local squadRoot = squadCharacter and squadCharacter:FindFirstChild("HumanoidRootPart")
			local squadHumanoid = squadCharacter and squadCharacter:FindFirstChildOfClass("Humanoid")
			if squadRoot and squadHumanoid and squadHumanoid.Health > 0 and (squadRoot.Position - rootPart.Position).Magnitude <= radius then
				if self:_grantAmmoUtility(squadmate, bonus) then
					helpedPlayers += 1
					self:_fireMissionState({ squadmate }, "Ammo crate restock")
				end
			end
		end

		if helpedPlayers <= 0 then
			self:_fireMissionState({ player }, "No squadmates nearby for crate")
			return
		end

		player:SetAttribute("MissionAmmoCrates", count - 1)
		self:_emitPulse(rootPart.CFrame * CFrame.new(0, -2.4, 0), Vector3.new(radius * 2, 0.18, radius * 2), Color3.fromRGB(132, 176, 236), 0.52, 0.2)
		self:_emitReloadEffect(handle, Color3.fromRGB(144, 182, 238))
		self:_notifyParty(self._activeMission and self._activeMission.party or { player }, ("%s dropped an ammo crate."):format(player.DisplayName))
		refreshState()
	end)

	refreshState()
	tool.Parent = backpack
end

function MissionService:_createSensorBeaconTool(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local existing = backpack:FindFirstChild("MissionSensorBeacon")
	if existing then
		existing:Destroy()
	end

	local character = player.Character
	if character then
		local equipped = character:FindFirstChild("MissionSensorBeacon")
		if equipped then
			equipped:Destroy()
		end
	end

	local tool = Instance.new("Tool")
	tool.Name = "MissionSensorBeacon"
	tool.ToolTip = "Sensor Beacon"
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.9, 1.2, 0.9)
	handle.Material = Enum.Material.Neon
	handle.Color = Color3.fromRGB(118, 228, 255)
	handle.Parent = tool

	local function refreshState()
		local count = player:GetAttribute("MissionSensorBeacons") or 0
		tool.ToolTip = ("Sensor Beacon x%d"):format(count)
		tool.Enabled = count > 0
	end

	tool.Equipped:Connect(function()
		refreshState()
	end)

	tool.Activated:Connect(function()
		local characterNow = player.Character
		local rootPart = characterNow and characterNow:FindFirstChild("HumanoidRootPart")
		local humanoid = characterNow and characterNow:FindFirstChildOfClass("Humanoid")
		if not rootPart or not humanoid or humanoid.Health <= 0 or self:_isCharacterDowned(characterNow) then
			return
		end

		local count = player:GetAttribute("MissionSensorBeacons") or 0
		if count <= 0 then
			return
		end

		if not self:_deploySensorBeacon(player, rootPart) then
			return
		end

		player:SetAttribute("MissionSensorBeacons", count - 1)
		self:_emitReloadEffect(handle, Color3.fromRGB(132, 228, 255))
		self:_notifyParty(self._activeMission and self._activeMission.party or { player }, ("%s deployed a sensor beacon."):format(player.DisplayName))
		self:_fireMissionState({ player }, "Beacon active")
		refreshState()
	end)

	refreshState()
	tool.Parent = backpack
end

function MissionService:_createBarrierTool(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local existing = backpack:FindFirstChild("MissionBarrier")
	if existing then
		existing:Destroy()
	end

	local character = player.Character
	if character then
		local equipped = character:FindFirstChild("MissionBarrier")
		if equipped then
			equipped:Destroy()
		end
	end

	local tool = Instance.new("Tool")
	tool.Name = "MissionBarrier"
	tool.ToolTip = "Barrier"
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1.2, 1.2, 0.5)
	handle.Material = Enum.Material.Metal
	handle.Color = Color3.fromRGB(88, 126, 196)
	handle.Parent = tool

	local function refreshState()
		local count = player:GetAttribute("MissionBarriers") or 0
		tool.ToolTip = ("Barrier x%d"):format(count)
		tool.Enabled = count > 0
	end

	tool.Equipped:Connect(refreshState)
	tool.Activated:Connect(function()
		local characterNow = player.Character
		local rootPart = characterNow and characterNow:FindFirstChild("HumanoidRootPart")
		local humanoid = characterNow and characterNow:FindFirstChildOfClass("Humanoid")
		if not rootPart or not humanoid or humanoid.Health <= 0 or self:_isCharacterDowned(characterNow) then
			return
		end

		local count = player:GetAttribute("MissionBarriers") or 0
		if count <= 0 then
			return
		end

		if not self:_deployBarrier(player, rootPart) then
			return
		end

		player:SetAttribute("MissionBarriers", count - 1)
		self:_emitReloadEffect(handle, Color3.fromRGB(128, 176, 248))
		self:_notifyParty(self._activeMission and self._activeMission.party or { player }, ("%s deployed a barrier."):format(player.DisplayName))
		self:_fireMissionState({ player }, "Barrier holding lane")
		refreshState()
	end)

	refreshState()
	tool.Parent = backpack
end

function MissionService:_createReviveStimTool(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local existing = backpack:FindFirstChild("MissionReviveStim")
	if existing then
		existing:Destroy()
	end

	local character = player.Character
	if character then
		local equipped = character:FindFirstChild("MissionReviveStim")
		if equipped then
			equipped:Destroy()
		end
	end

	local tool = Instance.new("Tool")
	tool.Name = "MissionReviveStim"
	tool.ToolTip = "Revive Stim"
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.8, 1.1, 0.8)
	handle.Material = Enum.Material.Neon
	handle.Color = Color3.fromRGB(132, 236, 168)
	handle.Parent = tool

	local function refreshState()
		local count = player:GetAttribute("MissionReviveStims") or 0
		tool.ToolTip = ("Revive Stim x%d"):format(count)
		tool.Enabled = count > 0
	end

	tool.Equipped:Connect(refreshState)
	tool.Activated:Connect(function()
		local characterNow = player.Character
		local humanoid = characterNow and characterNow:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or self:_isCharacterDowned(characterNow) then
			return
		end

		local count = player:GetAttribute("MissionReviveStims") or 0
		if count <= 0 then
			return
		end

		if not self:_useReviveStim(player) then
			self:_fireMissionState({ player }, "No downed ally nearby")
			return
		end

		player:SetAttribute("MissionReviveStims", count - 1)
		self:_emitReloadEffect(handle, Color3.fromRGB(146, 238, 174))
		refreshState()
	end)

	refreshState()
	tool.Parent = backpack
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

	local modifierTraits = self:_getModifierRuntimeTraits()
	player:SetAttribute("MissionMedkits", (player:GetAttribute("MissionMedkits") or 0) + modifierTraits.MedkitPickupCount)
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
			self:_fireMissionState({ player }, ("Dash cooling %.1fs"):format(math.max(0, cooldownEndsAt - now)))
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
		local dashDirection = humanoid.MoveDirection
		if dashDirection.Magnitude <= 0.1 then
			dashDirection = rootPart.CFrame.LookVector
		else
			dashDirection = dashDirection.Unit
		end
		local forwardBias = rootPart.CFrame.LookVector
		local blendedDirection = (dashDirection * 0.72 + forwardBias * 0.28)
		if blendedDirection.Magnitude <= 0.01 then
			blendedDirection = forwardBias
		else
			blendedDirection = blendedDirection.Unit
		end
		local currentVelocity = rootPart.AssemblyLinearVelocity
		local planarVelocity = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)
		local carriedSpeed = math.min(planarVelocity.Magnitude, self._missionConfig.Mission.DashSpeed * 0.35)
		local dashVelocity = blendedDirection * (self._missionConfig.Mission.DashSpeed + carriedSpeed)
		rootPart.AssemblyLinearVelocity = dashVelocity + Vector3.new(0, math.max(currentVelocity.Y, 0), 0)
		self:_emitPulse(rootPart.CFrame * CFrame.new(0, 0, -1.4), Vector3.new(2.1, 0.2, 3.8), Color3.fromRGB(164, 238, 255), 0.54, 0.12)
		self:_fireMissionState({ player }, "Dash active")

		task.delay(self._missionConfig.Mission.DashDuration, function()
			if characterNow and characterNow.Parent then
				characterNow:SetAttribute("MissionDashing", false)
				self:_fireMissionState({ player }, "Weapon ready")
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
	self:_createAmmoCrateTool(player)
	self:_createSensorBeaconTool(player)
	self:_createBarrierTool(player)
	self:_createReviveStimTool(player)
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

function MissionService:_spawnZombie(spawnPosition, scaledStats, index, spawnContext)
	local runtime = self._activeMission and self._activeMission.zombiesFolder
	if not runtime then
		return
	end
	spawnContext = type(spawnContext) == "table" and spawnContext or {}

	local zombie = Instance.new("Model")
	zombie.Name = ("Zombie_%d_%d"):format(self._activeMission.wave, index)
	zombie.Parent = runtime
	local forceBoss = scaledStats.forceBoss == true
	local isBoss = forceBoss or (index == scaledStats.spawnCount and self._activeMission and self._activeMission.wave >= self._missionConfig.Mission.WaveCount)
	local wave = self._activeMission and self._activeMission.wave or 1
	local modifierTraits = self:_getModifierRuntimeTraits()
	local forceBruiser = spawnContext.forceBruiser == true
	local forceArtillery = spawnContext.forceArtillery == true
	local forceSpitter = spawnContext.forceSpitter == true
	local forceExploder = spawnContext.forceExploder == true
	local forceBrute = spawnContext.forceBrute == true
	local forceRunner = spawnContext.forceRunner == true
	local forceShieldCarrier = spawnContext.forceShieldCarrier == true
	local forceScreamer = spawnContext.forceScreamer == true
	local isArtillery = not isBoss and (forceArtillery or (wave >= 5 and index % modifierTraits.ArtilleryStep == 0))
	local isElite = isArtillery
	local isBruiser = not isBoss and (forceBruiser or (wave >= 4 and index % modifierTraits.BruiserStep == 0))
	if isBruiser then
		isArtillery = false
		isElite = false
	end
	local isShieldCarrier = not isBoss and not isBruiser and not isArtillery and (forceShieldCarrier or (wave >= 3 and index % modifierTraits.ShieldCarrierStep == 0))
	local isScreamer = not isBoss and not isBruiser and not isArtillery and not isShieldCarrier and (forceScreamer or (wave >= 3 and index % modifierTraits.ScreamerStep == 0))
	local isSpitter = not isBoss and not isBruiser and not isArtillery and not isShieldCarrier and not isScreamer and (forceSpitter or (wave >= 3 and index % modifierTraits.SpitterStep == 0))
	local isExploder = not isBoss and not isBruiser and not isArtillery and not isShieldCarrier and not isScreamer and not isSpitter and (forceExploder or (wave >= 4 and index % modifierTraits.ExploderStep == 0))
	local isBrute = not isElite and not isBruiser and not isShieldCarrier and not isScreamer and not isSpitter and not isExploder and (forceBrute or (wave >= 3 and index % modifierTraits.BruteStep == 0))
	local isRunner = not isElite and not isBruiser and not isShieldCarrier and not isScreamer and not isSpitter and not isExploder and not isBrute and (forceRunner or (wave >= 2 and index % modifierTraits.RunnerStep == 0))
	local bossProfile = isBoss and self:_getBossProfile(self._activeMission, scaledStats.bossProfileKey) or nil
	local laneOffset = typeof(spawnContext.laneOffset) == "Vector3" and spawnContext.laneOffset or nil
	local laneRole = (isRunner and "Flank")
		or (isScreamer and "Support")
		or (isShieldCarrier and "Objective")
		or ((isSpitter or isArtillery) and "Ranged")
		or ((isBruiser or isBrute or isBoss or spawnContext.forceObjectivePressure == true) and "Objective")
		or "Lane"
	local laneFocusPosition = laneOffset and self:_getLaneFocusPosition(laneOffset, laneRole) or nil

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = isBoss and Vector3.new(4.2, 4.2, 2.4) or (isBruiser and Vector3.new(3.1, 3.1, 1.6) or (isArtillery and Vector3.new(2.45, 2.45, 1.28) or (isBrute and Vector3.new(2.8, 2.8, 1.4) or (isShieldCarrier and Vector3.new(2.9, 2.9, 1.46) or (isScreamer and Vector3.new(2.15, 2.15, 1.14) or (isSpitter and Vector3.new(2.1, 2.1, 1.1) or (isExploder and Vector3.new(2.15, 2.15, 1.18) or Vector3.new(2, 2, 1))))))))
	root.CFrame = CFrame.new(spawnPosition + Vector3.new(0, 3, 0))
	root.Material = Enum.Material.Slate
	root.Color = isBoss and Color3.fromRGB(110, 54, 54) or (isArtillery and Color3.fromRGB(134, 92, 66) or (isElite and Color3.fromRGB(130, 70, 70) or (isBruiser and Color3.fromRGB(118, 84, 72) or (isBrute and Color3.fromRGB(114, 88, 68) or (isShieldCarrier and Color3.fromRGB(84, 92, 112) or (isScreamer and Color3.fromRGB(92, 74, 134) or (isSpitter and Color3.fromRGB(72, 112, 86) or (isExploder and Color3.fromRGB(132, 94, 54) or (isRunner and Color3.fromRGB(108, 132, 82) or Color3.fromRGB(78, 100, 74))))))))))
	root.Parent = zombie

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = isBoss and Vector3.new(4.8, 5.8, 2.8) or (isArtillery and Vector3.new(2.8, 3.3, 1.55) or (isElite and Vector3.new(2.6, 3.2, 1.5) or (isBruiser and Vector3.new(3.7, 4.1, 2.2) or (isBrute and Vector3.new(3.3, 3.8, 1.9) or (isShieldCarrier and Vector3.new(3.35, 3.85, 1.95) or (isScreamer and Vector3.new(2.2, 2.95, 1.28) or (isSpitter and Vector3.new(2.1, 2.8, 1.2) or (isExploder and Vector3.new(2.2, 2.7, 1.3) or (isRunner and Vector3.new(2, 2.1, 1.1) or Vector3.new(2.2, 2.5, 1.3))))))))))
	torso.CFrame = root.CFrame + Vector3.new(0, isBoss and 3.2 or (isBruiser and 2.3 or (isShieldCarrier and 2.2 or (isBrute and 2.1 or 1.6))), 0)
	torso.Material = Enum.Material.SmoothPlastic
	torso.Color = isBoss and Color3.fromRGB(148, 64, 64) or (isArtillery and Color3.fromRGB(188, 124, 82) or (isElite and Color3.fromRGB(156, 82, 82) or (isBruiser and Color3.fromRGB(162, 116, 94) or (isBrute and Color3.fromRGB(152, 112, 84) or (isShieldCarrier and Color3.fromRGB(122, 138, 166) or (isScreamer and Color3.fromRGB(132, 102, 188) or (isSpitter and Color3.fromRGB(98, 154, 116) or (isExploder and Color3.fromRGB(188, 132, 78) or (isRunner and Color3.fromRGB(138, 168, 96) or Color3.fromRGB(95, 125, 88))))))))))
	torso.Parent = zombie

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = isBoss and Vector3.new(2.8, 2.8, 2.8) or (isArtillery and Vector3.new(1.95, 1.95, 1.95) or (isElite and Vector3.new(1.9, 1.9, 1.9) or (isBruiser and Vector3.new(2.3, 2.3, 2.3) or (isBrute and Vector3.new(2.1, 2.1, 2.1) or (isShieldCarrier and Vector3.new(2.05, 2.05, 2.05) or (isScreamer and Vector3.new(1.95, 1.95, 1.95) or (isSpitter and Vector3.new(1.75, 1.75, 1.75) or (isExploder and Vector3.new(1.85, 1.85, 1.85) or (isRunner and Vector3.new(1.4, 1.4, 1.4) or Vector3.new(1.6, 1.6, 1.6))))))))))
	head.CFrame = root.CFrame + Vector3.new(0, isBoss and 6.2 or (isArtillery and 4.2 or (isElite and 3.9 or (isBruiser and 5.15 or (isBrute and 4.8 or (isShieldCarrier and 4.85 or (isScreamer and 4.05 or (isSpitter and 3.75 or (isExploder and 3.9 or (isRunner and 3.1 or 3.4))))))))), 0)
	head.Material = Enum.Material.SmoothPlastic
	head.Color = isBoss and Color3.fromRGB(222, 118, 118) or (isArtillery and Color3.fromRGB(244, 172, 118) or (isElite and Color3.fromRGB(210, 116, 116) or (isBruiser and Color3.fromRGB(214, 164, 142) or (isBrute and Color3.fromRGB(210, 168, 128) or (isShieldCarrier and Color3.fromRGB(198, 214, 238) or (isScreamer and Color3.fromRGB(198, 172, 255) or (isSpitter and Color3.fromRGB(162, 228, 176) or (isExploder and Color3.fromRGB(244, 188, 124) or (isRunner and Color3.fromRGB(182, 204, 136) or Color3.fromRGB(142, 167, 128))))))))))
	head.Parent = zombie

	local leftArm = Instance.new("Part")
	leftArm.Name = "LeftArm"
	leftArm.Size = isBoss and Vector3.new(1.2, 4.4, 1.2) or (isBruiser and Vector3.new(1.08, 3.5, 1.08) or (isArtillery and Vector3.new(0.66, 3.1, 0.66) or (isBrute and Vector3.new(0.95, 3.2, 0.95) or (isShieldCarrier and Vector3.new(1.18, 3.2, 1.18) or (isScreamer and Vector3.new(0.5, 3.15, 0.5) or (isSpitter and Vector3.new(0.52, 2.9, 0.52) or (isExploder and Vector3.new(0.58, 2.85, 0.58) or (isRunner and Vector3.new(0.45, 2.6, 0.45) or Vector3.new(0.62, 2.8, 0.62)))))))))
	leftArm.CFrame = torso.CFrame * CFrame.new(-(torso.Size.X * 0.5 + leftArm.Size.X * 0.35), 0.05, 0)
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.Color = torso.Color:Lerp(Color3.fromRGB(38, 42, 48), (isRunner or isScreamer) and 0.18 or 0.1)
	leftArm.Parent = zombie

	local rightArm = Instance.new("Part")
	rightArm.Name = "RightArm"
	rightArm.Size = leftArm.Size
	rightArm.CFrame = torso.CFrame * CFrame.new(torso.Size.X * 0.5 + rightArm.Size.X * 0.35, 0.05, 0)
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.Color = leftArm.Color
	rightArm.Parent = zombie

	local leftLeg = Instance.new("Part")
	leftLeg.Name = "LeftLeg"
	leftLeg.Size = isBoss and Vector3.new(1.34, 4.3, 1.34) or (isBruiser and Vector3.new(1.18, 3.65, 1.18) or (isArtillery and Vector3.new(0.78, 3.2, 0.78) or (isBrute and Vector3.new(1.02, 3.35, 1.02) or (isShieldCarrier and Vector3.new(1.08, 3.25, 1.08) or (isScreamer and Vector3.new(0.58, 3.05, 0.58) or (isSpitter and Vector3.new(0.62, 2.9, 0.62) or (isExploder and Vector3.new(0.68, 2.85, 0.68) or (isRunner and Vector3.new(0.48, 2.85, 0.48) or Vector3.new(0.72, 3, 0.72)))))))))
	leftLeg.CFrame = root.CFrame * CFrame.new(-(root.Size.X * 0.18 + leftLeg.Size.X * 0.2), -(root.Size.Y * 0.52 + leftLeg.Size.Y * 0.5), 0)
	leftLeg.Material = Enum.Material.SmoothPlastic
	leftLeg.Color = torso.Color:Lerp(Color3.fromRGB(44, 48, 54), 0.12)
	leftLeg.Parent = zombie

	local rightLeg = Instance.new("Part")
	rightLeg.Name = "RightLeg"
	rightLeg.Size = leftLeg.Size
	rightLeg.CFrame = root.CFrame * CFrame.new(root.Size.X * 0.18 + rightLeg.Size.X * 0.2, -(root.Size.Y * 0.52 + rightLeg.Size.Y * 0.5), 0)
	rightLeg.Material = Enum.Material.SmoothPlastic
	rightLeg.Color = leftLeg.Color
	rightLeg.Parent = zombie

	local function createLimbMotor(name, part0, part1, c0)
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = part0
		motor.Part1 = part1
		motor.C0 = c0
		motor.C1 = CFrame.new()
		motor.Parent = part0
		return motor
	end

	local torsoJoint = createLimbMotor("RootJoint", root, torso, CFrame.new(0, isBoss and 3.2 or (isBruiser and 2.3 or (isShieldCarrier and 2.2 or (isBrute and 2.1 or 1.6))), 0))
	local neckJoint = createLimbMotor("Neck", torso, head, CFrame.new(0, head.Position.Y - torso.Position.Y, 0))
	local leftShoulder = createLimbMotor("LeftShoulder", torso, leftArm, CFrame.new(-(torso.Size.X * 0.5 + leftArm.Size.X * 0.35), 0.05, 0))
	local rightShoulder = createLimbMotor("RightShoulder", torso, rightArm, CFrame.new(torso.Size.X * 0.5 + rightArm.Size.X * 0.35, 0.05, 0))
	local leftHip = createLimbMotor("LeftHip", root, leftLeg, CFrame.new(-(root.Size.X * 0.18 + leftLeg.Size.X * 0.2), -(root.Size.Y * 0.52 + leftLeg.Size.Y * 0.5), 0))
	local rightHip = createLimbMotor("RightHip", root, rightLeg, CFrame.new(root.Size.X * 0.18 + rightLeg.Size.X * 0.2, -(root.Size.Y * 0.52 + rightLeg.Size.Y * 0.5), 0))

	local eyeGlow = Instance.new("Part")
	eyeGlow.Name = "EyeGlow"
	eyeGlow.Size = isBoss and Vector3.new(0.7, 0.16, 0.16) or (isBruiser and Vector3.new(0.52, 0.13, 0.13) or (isArtillery and Vector3.new(0.54, 0.13, 0.13) or (isBrute and Vector3.new(0.46, 0.12, 0.12) or (isShieldCarrier and Vector3.new(0.42, 0.12, 0.12) or (isScreamer and Vector3.new(0.46, 0.12, 0.12) or Vector3.new(0.34, 0.1, 0.1))))))
	eyeGlow.Anchored = false
	eyeGlow.CanCollide = false
	eyeGlow.CanQuery = false
	eyeGlow.Material = Enum.Material.Neon
	eyeGlow.Color = isBoss and Color3.fromRGB(255, 138, 118) or (isArtillery and Color3.fromRGB(255, 206, 132) or (isBruiser and Color3.fromRGB(255, 174, 132) or (isBrute and Color3.fromRGB(255, 196, 132) or (isShieldCarrier and Color3.fromRGB(196, 224, 255) or (isScreamer and Color3.fromRGB(214, 172, 255) or (isSpitter and Color3.fromRGB(168, 255, 198) or (isExploder and Color3.fromRGB(255, 204, 112) or (isRunner and Color3.fromRGB(198, 255, 142) or Color3.fromRGB(208, 228, 255)))))))))
	eyeGlow.CFrame = head.CFrame * CFrame.new(0, 0.08, -(head.Size.Z * 0.48))
	eyeGlow.Parent = zombie

	local eyeWeld = Instance.new("WeldConstraint")
	eyeWeld.Part0 = head
	eyeWeld.Part1 = eyeGlow
	eyeWeld.Parent = head

	local spinePlate = Instance.new("Part")
	spinePlate.Name = "SpinePlate"
	spinePlate.Size = isBoss and Vector3.new(0.42, 3.1, 0.32) or (isBruiser and Vector3.new(0.36, 2.6, 0.28) or (isArtillery and Vector3.new(0.24, 2.2, 0.2) or (isBrute and Vector3.new(0.32, 2.3, 0.24) or Vector3.new(0.18, 1.7, 0.18))))
	spinePlate.Material = Enum.Material.Metal
	spinePlate.Color = isBoss and Color3.fromRGB(144, 82, 82) or (isArtillery and Color3.fromRGB(202, 152, 92) or (isBruiser and Color3.fromRGB(174, 142, 96) or (isBrute and Color3.fromRGB(156, 128, 88) or (isShieldCarrier and Color3.fromRGB(122, 148, 186) or (isScreamer and Color3.fromRGB(154, 122, 218) or (isSpitter and Color3.fromRGB(112, 188, 136) or (isExploder and Color3.fromRGB(216, 152, 88) or (isRunner and Color3.fromRGB(158, 204, 112) or Color3.fromRGB(112, 126, 108)))))))))
	spinePlate.CFrame = torso.CFrame * CFrame.new(0, 0.1, torso.Size.Z * 0.5 + 0.08)
	spinePlate.Parent = zombie
	local spinePlateWeld = Instance.new("WeldConstraint")
	spinePlateWeld.Part0 = torso
	spinePlateWeld.Part1 = spinePlate
	spinePlateWeld.Parent = torso

	local jaw = Instance.new("Part")
	jaw.Name = "Jaw"
	jaw.Size = isBoss and Vector3.new(1.3, 0.55, 0.82) or (isBruiser and Vector3.new(1.05, 0.42, 0.64) or (isBrute and Vector3.new(0.96, 0.4, 0.58) or Vector3.new(0.72, 0.3, 0.44)))
	jaw.Material = Enum.Material.SmoothPlastic
	jaw.Color = head.Color:Lerp(Color3.fromRGB(58, 42, 42), (isSpitter or isScreamer) and 0.26 or 0.18)
	jaw.CFrame = head.CFrame * CFrame.new(0, -(head.Size.Y * 0.2), -(head.Size.Z * 0.22))
	jaw.Parent = zombie
	local jawWeld = Instance.new("WeldConstraint")
	jawWeld.Part0 = head
	jawWeld.Part1 = jaw
	jawWeld.Parent = head

	local shoulderSpine = Instance.new("Part")
	shoulderSpine.Name = "ShoulderSpine"
	shoulderSpine.Size = isBoss and Vector3.new(0.34, 2.8, 0.24) or (isBruiser and Vector3.new(0.28, 2.2, 0.2) or Vector3.new(0.18, 1.6, 0.16))
	shoulderSpine.Material = Enum.Material.Metal
	shoulderSpine.Color = spinePlate.Color
	shoulderSpine.CFrame = torso.CFrame * CFrame.new(0, torso.Size.Y * 0.24, torso.Size.Z * 0.52)
	shoulderSpine.Parent = zombie
	local shoulderSpineWeld = Instance.new("WeldConstraint")
	shoulderSpineWeld.Part0 = torso
	shoulderSpineWeld.Part1 = shoulderSpine
	shoulderSpineWeld.Parent = torso

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	local zombieHealth = isBoss and math.floor(scaledStats.health * (bossProfile and bossProfile.healthScale or self._missionConfig.Mission.BossHealthScale)) or (isElite and math.floor(scaledStats.health * 1.8) or scaledStats.health)
	if isBruiser then
		zombieHealth = math.max(85, math.floor(scaledStats.health * self._missionConfig.Mission.BruiserHealthScale))
	end
	if isBrute then
		zombieHealth = math.max(60, math.floor(scaledStats.health * self._missionConfig.Mission.BruteHealthScale))
	end
	if isShieldCarrier then
		zombieHealth = math.max(72, math.floor(scaledStats.health * self._missionConfig.Mission.ShieldCarrierHealthScale))
	end
	if isScreamer then
		zombieHealth = math.max(36, math.floor(zombieHealth * self._missionConfig.Mission.ScreamerHealthScale))
	end
	if isSpitter then
		zombieHealth = math.max(32, math.floor(zombieHealth * self._missionConfig.Mission.SpitterHealthScale))
	end
	if isArtillery then
		zombieHealth = math.max(78, math.floor((scaledStats.health or zombieHealth) * self._missionConfig.Mission.ArtilleryHealthScale))
	end
	if isExploder then
		zombieHealth = math.max(26, math.floor(zombieHealth * self._missionConfig.Mission.ExploderHealthScale))
	end
	if isRunner then
		zombieHealth = math.max(20, math.floor(zombieHealth * 0.72))
	end
	humanoid.MaxHealth = zombieHealth
	humanoid.Health = zombieHealth
	local baseWalkSpeed = isBoss and 9.8 or (isArtillery and 10.2 or (isElite and 12.5 or (isBruiser and 9.4 or (isBrute and 8.8 or (isShieldCarrier and 8.6 or (isScreamer and 10.6 or (isSpitter and 10.8 or (isExploder and 11.6 or (isRunner and 15.5 or 11)))))))))
	local walkSpeedScale = 1
	if isBruiser then
		walkSpeedScale = modifierTraits.BruiserSpeedScale
	elseif isArtillery then
		walkSpeedScale = 1
	elseif isBrute then
		walkSpeedScale = modifierTraits.BruteSpeedScale
	elseif isShieldCarrier then
		walkSpeedScale = modifierTraits.ShieldCarrierSpeedScale
	elseif isScreamer then
		walkSpeedScale = modifierTraits.ScreamerSpeedScale
	elseif isSpitter then
		walkSpeedScale = modifierTraits.SpitterSpeedScale
	elseif isExploder then
		walkSpeedScale = modifierTraits.ExploderSpeedScale
	elseif isRunner then
		walkSpeedScale = modifierTraits.RunnerSpeedScale
	end
	humanoid.WalkSpeed = math.max(7, baseWalkSpeed * walkSpeedScale)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayDistance = 0
	humanoid.NameDisplayDistance = 0
	humanoid.Parent = zombie

	local stridePhase = (index % 9) * 0.66 + ((isRunner or isScreamer) and 0.28 or 0)
	local postureBias = ((index % 5) - 2) * 0.028

	root:SetNetworkOwner(nil)
	zombie.PrimaryPart = root
	local touchDamage = isBoss and math.max(12, math.floor(scaledStats.damage * (bossProfile and bossProfile.damageScale or self._missionConfig.Mission.BossDamageScale))) or (isArtillery and math.max(9, math.floor(scaledStats.damage * self._missionConfig.Mission.ArtilleryDamageScale)) or (isElite and math.floor(scaledStats.damage * 1.4) or (isBruiser and math.max(10, math.floor(scaledStats.damage * self._missionConfig.Mission.BruiserDamageScale)) or (isBrute and math.max(8, math.floor(scaledStats.damage * self._missionConfig.Mission.BruteDamageScale)) or (isShieldCarrier and math.max(5, math.floor(scaledStats.damage * self._missionConfig.Mission.ShieldCarrierDamageScale)) or (isScreamer and math.max(4, math.floor(scaledStats.damage * self._missionConfig.Mission.ScreamerDamageScale)) or (isSpitter and math.max(5, math.floor(scaledStats.damage * self._missionConfig.Mission.SpitterDamageScale)) or (isExploder and math.max(6, math.floor(scaledStats.damage * self._missionConfig.Mission.ExploderDamageScale)) or (isRunner and math.max(4, math.floor(scaledStats.damage * 0.85)) or scaledStats.damage)))))))))
	zombie:SetAttribute("ZombieDamage", touchDamage)
	zombie:SetAttribute("BaseZombieDamage", touchDamage)
	zombie:SetAttribute("ObjectiveDamage", math.max(4, math.floor(touchDamage * (isBoss and 0.9 or 0.7))))
	zombie:SetAttribute("BaseObjectiveDamage", zombie:GetAttribute("ObjectiveDamage"))
	zombie:SetAttribute("BaseWalkSpeed", humanoid.WalkSpeed)
	zombie:SetAttribute("Elite", isElite)
	zombie:SetAttribute("Artillery", isArtillery)
	zombie:SetAttribute("Bruiser", isBruiser)
	zombie:SetAttribute("ShieldCarrier", isShieldCarrier)
	zombie:SetAttribute("Screamer", isScreamer)
	zombie:SetAttribute("Spitter", isSpitter)
	zombie:SetAttribute("Exploder", isExploder)
	zombie:SetAttribute("Brute", isBrute)
	zombie:SetAttribute("Runner", isRunner)
	zombie:SetAttribute("Boss", isBoss)
	zombie:SetAttribute("LaneRole", laneRole)
	if laneOffset then
		zombie:SetAttribute("LaneX", laneOffset.X)
		zombie:SetAttribute("LaneZ", laneOffset.Z)
	end
	local objectivePressure = isBoss or isBruiser or isBrute or isExploder or (wave >= 3 and index % 3 == 0) or (wave >= 2 and index % 4 == 0)
	if spawnContext.forceObjectivePressure == true then
		objectivePressure = true
	end
	if self._activeMission.wave >= 2 and index % modifierTraits.ObjectivePressureInterval == 0 then
		objectivePressure = true
	end
	if modifierTraits.ForceRunnerPressure and isRunner then
		objectivePressure = true
	end
	if modifierTraits.ForceShieldCarrierPressure and isShieldCarrier then
		objectivePressure = true
	end
	if modifierTraits.ForceScreamerPressure and isScreamer then
		objectivePressure = true
	end
	if modifierTraits.ForceSpitterPressure and isSpitter then
		objectivePressure = true
	end
	if modifierTraits.ForceArtilleryPressure and isArtillery then
		objectivePressure = true
	end
	if modifierTraits.ForceExploderPressure and isExploder then
		objectivePressure = true
	end
	if modifierTraits.ForceBrutePressure and isBrute then
		objectivePressure = true
	end
	if modifierTraits.ForceBruiserPressure and isBruiser then
		objectivePressure = true
	end
	zombie:SetAttribute("ObjectivePressure", objectivePressure)

	if isBoss then
		zombie.Name = ("%s_%d"):format(bossProfile and bossProfile.displayName:gsub("%s+", "") or "Boss", self._activeMission.wave)
		zombie:SetAttribute("BossType", bossProfile and bossProfile.key or "siege_tyrant")
		local aura = Instance.new("Highlight")
		aura.Name = "BossAura"
		aura.FillColor = bossProfile and bossProfile.fillColor or Color3.fromRGB(255, 88, 88)
		aura.OutlineColor = bossProfile and bossProfile.outlineColor or Color3.fromRGB(255, 228, 196)
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
		label.Text = bossProfile and bossProfile.name or "SIEGE TYRANT"
		label.TextColor3 = bossProfile and bossProfile.textColor or Color3.fromRGB(255, 212, 188)
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
		if isArtillery then
			aura.Name = "ArtilleryAura"
			aura.FillColor = Color3.fromRGB(242, 162, 96)
			aura.OutlineColor = Color3.fromRGB(255, 228, 176)
			aura.FillTransparency = 0.34
			aura.OutlineTransparency = 0
			local launcher = Instance.new("Part")
			launcher.Name = "ArtilleryLauncher"
			launcher.Size = Vector3.new(2.4, 0.42, 1)
			launcher.Material = Enum.Material.Metal
			launcher.Color = Color3.fromRGB(138, 96, 68)
			launcher.CFrame = torso.CFrame * CFrame.new(0, torso.Size.Y * 0.34, -(torso.Size.Z * 0.08))
			launcher.Parent = zombie
			local launcherWeld = Instance.new("WeldConstraint")
			launcherWeld.Part0 = torso
			launcherWeld.Part1 = launcher
			launcherWeld.Parent = torso
			local artilleryCore = Instance.new("Part")
			artilleryCore.Name = "ArtilleryCore"
			artilleryCore.Shape = Enum.PartType.Ball
			artilleryCore.Size = Vector3.new(0.82, 0.82, 0.82)
			artilleryCore.Material = Enum.Material.Neon
			artilleryCore.Color = Color3.fromRGB(255, 196, 118)
			artilleryCore.Transparency = 0.1
			artilleryCore.CFrame = torso.CFrame * CFrame.new(0, torso.Size.Y * 0.18, -(torso.Size.Z * 0.5 + 0.28))
			artilleryCore.Parent = zombie
			local artilleryCoreWeld = Instance.new("WeldConstraint")
			artilleryCoreWeld.Part0 = torso
			artilleryCoreWeld.Part1 = artilleryCore
			artilleryCoreWeld.Parent = torso
			local artilleryAntenna = Instance.new("Part")
			artilleryAntenna.Name = "ArtilleryAntenna"
			artilleryAntenna.Size = Vector3.new(0.16, 2.4, 0.16)
			artilleryAntenna.Material = Enum.Material.Neon
			artilleryAntenna.Color = Color3.fromRGB(255, 214, 142)
			artilleryAntenna.CFrame = head.CFrame * CFrame.new(0, 1.6, 0)
			artilleryAntenna.Parent = zombie
			local artilleryAntennaWeld = Instance.new("WeldConstraint")
			artilleryAntennaWeld.Part0 = head
			artilleryAntennaWeld.Part1 = artilleryAntenna
			artilleryAntennaWeld.Parent = head
		end
	elseif isBruiser then
		local aura = Instance.new("Highlight")
		aura.Name = "BruiserAura"
		aura.FillColor = Color3.fromRGB(228, 162, 108)
		aura.OutlineColor = Color3.fromRGB(255, 224, 182)
		aura.FillTransparency = 0.42
		aura.OutlineTransparency = 0
		aura.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		aura.Parent = zombie
		local chestPlate = Instance.new("Part")
		chestPlate.Name = "BruiserChestPlate"
		chestPlate.Size = Vector3.new(2.8, 1.45, 0.36)
		chestPlate.Material = Enum.Material.Metal
		chestPlate.Color = Color3.fromRGB(158, 124, 92)
		chestPlate.CFrame = torso.CFrame * CFrame.new(0, 0.24, -(torso.Size.Z * 0.5 + 0.12))
		chestPlate.Parent = zombie
		local chestWeld = Instance.new("WeldConstraint")
		chestWeld.Part0 = torso
		chestWeld.Part1 = chestPlate
		chestWeld.Parent = torso
		local shoulderPad = Instance.new("Part")
		shoulderPad.Name = "BruiserShoulderPad"
		shoulderPad.Size = Vector3.new(3.5, 0.54, 0.95)
		shoulderPad.Material = Enum.Material.Metal
		shoulderPad.Color = Color3.fromRGB(178, 142, 98)
		shoulderPad.CFrame = torso.CFrame * CFrame.new(0, torso.Size.Y * 0.39, -(torso.Size.Z * 0.16))
		shoulderPad.Parent = zombie
		local shoulderWeld = Instance.new("WeldConstraint")
		shoulderWeld.Part0 = torso
		shoulderWeld.Part1 = shoulderPad
		shoulderWeld.Parent = torso
	elseif isBrute then
		local aura = Instance.new("Highlight")
		aura.Name = "BruteAura"
		aura.FillColor = Color3.fromRGB(214, 154, 96)
		aura.OutlineColor = Color3.fromRGB(255, 221, 176)
		aura.FillTransparency = 0.46
		aura.OutlineTransparency = 0
		aura.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
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
	elseif isShieldCarrier then
		local aura = Instance.new("Highlight")
		aura.Name = "ShieldCarrierAura"
		aura.FillColor = Color3.fromRGB(154, 188, 236)
		aura.OutlineColor = Color3.fromRGB(228, 240, 255)
		aura.FillTransparency = 0.46
		aura.OutlineTransparency = 0
		aura.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		aura.Parent = zombie
		local shield = Instance.new("Part")
		shield.Name = "ShieldPlate"
		shield.Size = Vector3.new(3.3, 4.2, 0.36)
		shield.Material = Enum.Material.Metal
		shield.Color = Color3.fromRGB(116, 132, 156)
		shield.CFrame = torso.CFrame * CFrame.new(0, 0.1, -(torso.Size.Z * 0.5 + 0.42))
		shield.Parent = zombie
		local shieldWeld = Instance.new("WeldConstraint")
		shieldWeld.Part0 = torso
		shieldWeld.Part1 = shield
		shieldWeld.Parent = torso
		local shieldGlow = Instance.new("Part")
		shieldGlow.Name = "ShieldGlow"
		shieldGlow.Size = Vector3.new(2.5, 3.1, 0.08)
		shieldGlow.Material = Enum.Material.Neon
		shieldGlow.Color = Color3.fromRGB(176, 214, 255)
		shieldGlow.Transparency = 0.12
		shieldGlow.CFrame = shield.CFrame * CFrame.new(0, 0, -0.2)
		shieldGlow.Parent = zombie
		local shieldGlowWeld = Instance.new("WeldConstraint")
		shieldGlowWeld.Part0 = shield
		shieldGlowWeld.Part1 = shieldGlow
		shieldGlowWeld.Parent = shield
		local shoulderPlate = Instance.new("Part")
		shoulderPlate.Name = "ShieldShoulderPlate"
		shoulderPlate.Size = Vector3.new(3.6, 0.54, 0.9)
		shoulderPlate.Material = Enum.Material.Metal
		shoulderPlate.Color = Color3.fromRGB(132, 148, 176)
		shoulderPlate.CFrame = torso.CFrame * CFrame.new(0, torso.Size.Y * 0.38, -(torso.Size.Z * 0.15))
		shoulderPlate.Parent = zombie
		local shoulderPlateWeld = Instance.new("WeldConstraint")
		shoulderPlateWeld.Part0 = torso
		shoulderPlateWeld.Part1 = shoulderPlate
		shoulderPlateWeld.Parent = torso
	elseif isRunner then
		local aura = Instance.new("Highlight")
		aura.Name = "RunnerAura"
		aura.FillColor = Color3.fromRGB(178, 236, 118)
		aura.OutlineColor = Color3.fromRGB(238, 255, 214)
		aura.FillTransparency = 0.6
		aura.OutlineTransparency = 0.04
		aura.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
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
		local runnerCrest = Instance.new("Part")
		runnerCrest.Name = "RunnerCrest"
		runnerCrest.Size = Vector3.new(0.12, 0.9, 0.9)
		runnerCrest.Material = Enum.Material.Neon
		runnerCrest.Color = Color3.fromRGB(206, 255, 142)
		runnerCrest.Transparency = 0.12
		runnerCrest.CFrame = head.CFrame * CFrame.new(0, 0.28, 0)
		runnerCrest.Parent = zombie
		local runnerCrestWeld = Instance.new("WeldConstraint")
		runnerCrestWeld.Part0 = head
		runnerCrestWeld.Part1 = runnerCrest
		runnerCrestWeld.Parent = head
	elseif isScreamer then
		local aura = Instance.new("Highlight")
		aura.Name = "ScreamerAura"
		aura.FillColor = Color3.fromRGB(176, 118, 255)
		aura.OutlineColor = Color3.fromRGB(238, 218, 255)
		aura.FillTransparency = 0.44
		aura.OutlineTransparency = 0.02
		aura.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		aura.Parent = zombie
		local throat = Instance.new("Part")
		throat.Name = "ScreamerThroat"
		throat.Shape = Enum.PartType.Ball
		throat.Size = Vector3.new(0.72, 0.72, 0.72)
		throat.Material = Enum.Material.Neon
		throat.Color = Color3.fromRGB(214, 146, 255)
		throat.Transparency = 0.06
		throat.CFrame = head.CFrame * CFrame.new(0, -(head.Size.Y * 0.28), -(head.Size.Z * 0.2))
		throat.Parent = zombie
		local throatWeld = Instance.new("WeldConstraint")
		throatWeld.Part0 = head
		throatWeld.Part1 = throat
		throatWeld.Parent = head
		local screamerCrest = Instance.new("Part")
		screamerCrest.Name = "ScreamerCrest"
		screamerCrest.Size = Vector3.new(0.16, 1.1, 0.86)
		screamerCrest.Material = Enum.Material.Neon
		screamerCrest.Color = Color3.fromRGB(202, 156, 255)
		screamerCrest.Transparency = 0.08
		screamerCrest.CFrame = head.CFrame * CFrame.new(0, 0.42, 0)
		screamerCrest.Parent = zombie
		local screamerCrestWeld = Instance.new("WeldConstraint")
		screamerCrestWeld.Part0 = head
		screamerCrestWeld.Part1 = screamerCrest
		screamerCrestWeld.Parent = head
	elseif isSpitter then
		local aura = Instance.new("Highlight")
		aura.Name = "SpitterAura"
		aura.FillColor = Color3.fromRGB(102, 224, 154)
		aura.OutlineColor = Color3.fromRGB(220, 255, 228)
		aura.FillTransparency = 0.54
		aura.OutlineTransparency = 0.02
		aura.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		aura.Parent = zombie
		local gland = Instance.new("Part")
		gland.Name = "SpitterGland"
		gland.Shape = Enum.PartType.Ball
		gland.Size = Vector3.new(0.78, 0.78, 0.78)
		gland.Material = Enum.Material.Neon
		gland.Color = Color3.fromRGB(124, 255, 184)
		gland.Transparency = 0.08
		gland.CFrame = torso.CFrame * CFrame.new(0, torso.Size.Y * 0.16, -(torso.Size.Z * 0.5 + 0.24))
		gland.Parent = zombie
		local glandWeld = Instance.new("WeldConstraint")
		glandWeld.Part0 = torso
		glandWeld.Part1 = gland
		glandWeld.Parent = torso
		local spitJaw = Instance.new("Part")
		spitJaw.Name = "SpitterJawGlow"
		spitJaw.Size = Vector3.new(1.2, 0.26, 0.52)
		spitJaw.Material = Enum.Material.Neon
		spitJaw.Color = Color3.fromRGB(152, 255, 194)
		spitJaw.Transparency = 0.08
		spitJaw.CFrame = head.CFrame * CFrame.new(0, -0.18, -(head.Size.Z * 0.42))
		spitJaw.Parent = zombie
		local spitJawWeld = Instance.new("WeldConstraint")
		spitJawWeld.Part0 = head
		spitJawWeld.Part1 = spitJaw
		spitJawWeld.Parent = head
	elseif isExploder then
		local aura = Instance.new("Highlight")
		aura.Name = "ExploderAura"
		aura.FillColor = Color3.fromRGB(255, 172, 92)
		aura.OutlineColor = Color3.fromRGB(255, 228, 176)
		aura.FillTransparency = 0.46
		aura.OutlineTransparency = 0
		aura.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		aura.Parent = zombie
		local canister = Instance.new("Part")
		canister.Name = "ExploderCanister"
		canister.Shape = Enum.PartType.Ball
		canister.Size = Vector3.new(1.1, 1.1, 1.1)
		canister.Material = Enum.Material.Neon
		canister.Color = Color3.fromRGB(255, 188, 112)
		canister.Transparency = 0.1
		canister.CFrame = torso.CFrame * CFrame.new(0, 0.15, -(torso.Size.Z * 0.5 + 0.28))
		canister.Parent = zombie
		local canisterWeld = Instance.new("WeldConstraint")
		canisterWeld.Part0 = torso
		canisterWeld.Part1 = canister
		canisterWeld.Parent = torso
		local exploderBackCanister = Instance.new("Part")
		exploderBackCanister.Name = "ExploderBackCanister"
		exploderBackCanister.Shape = Enum.PartType.Ball
		exploderBackCanister.Size = Vector3.new(0.92, 0.92, 0.92)
		exploderBackCanister.Material = Enum.Material.Neon
		exploderBackCanister.Color = Color3.fromRGB(255, 210, 132)
		exploderBackCanister.Transparency = 0.12
		exploderBackCanister.CFrame = torso.CFrame * CFrame.new(0, 0.28, torso.Size.Z * 0.52)
		exploderBackCanister.Parent = zombie
		local exploderBackCanisterWeld = Instance.new("WeldConstraint")
		exploderBackCanisterWeld.Part0 = torso
		exploderBackCanisterWeld.Part1 = exploderBackCanister
		exploderBackCanisterWeld.Parent = torso
	end

	local hitCooldowns = {}
	local bossSlamReadyAt = os.clock() + 2.5
	local bossSummonReadyAt = os.clock() + 4.5
	local runnerBurstReadyAt = os.clock() + 1.5
	local bruteImpactReadyAt = os.clock() + 2.8
	local bruiserChargeReadyAt = os.clock() + 1.8
	local screamerPulseReadyAt = os.clock() + 2.4
	local spitterVolleyReadyAt = os.clock() + 2.1
	local artilleryVolleyReadyAt = os.clock() + 2.6
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
			self:_emitPlayerHitEffect(character, isBoss and Color3.fromRGB(255, 98, 98) or (isArtillery and Color3.fromRGB(255, 194, 126) or (isElite and Color3.fromRGB(255, 112, 112) or (isBruiser and Color3.fromRGB(244, 184, 124) or (isBrute and Color3.fromRGB(236, 174, 118) or (isScreamer and Color3.fromRGB(214, 164, 255) or (isSpitter and Color3.fromRGB(156, 244, 186) or (isExploder and Color3.fromRGB(255, 206, 126) or (isRunner and Color3.fromRGB(196, 236, 124) or Color3.fromRGB(182, 214, 255))))))))))
		end
	end)

	local aiThread = task.spawn(function()
		while humanoid.Health > 0 and self._activeMission and self._activeMission.zombiesFolder == runtime do
			local currentMission = self._activeMission
			if not currentMission then
				break
			end
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
				local disruptRange = isBoss and 20 or (isBruiser and 17 or (isArtillery and 24 or (isShieldCarrier and 12 or (isBrute and 14 or (isScreamer and 20 or (isSpitter and 18 or (isExploder and 11 or (isRunner and 10 or 12))))))))
				if objectivePressure and (not nearestRoot or nearestDistance > disruptRange) then
					targetRoot = objective
					targetDistance = objectiveDistance
				elseif not nearestRoot then
					targetRoot = objective
					targetDistance = objectiveDistance
				end
			end
			local moveTargetPosition = targetRoot and targetRoot.Position or nil
			if laneFocusPosition and targetRoot and targetRoot ~= objective then
				local laneDistance = (laneFocusPosition - root.Position).Magnitude
				if laneRole == "Flank" and laneDistance > 8 and targetDistance > 14 then
					moveTargetPosition = laneFocusPosition
					targetDistance = laneDistance
				elseif laneRole == "Ranged" and laneDistance < targetDistance and targetDistance > 18 then
					moveTargetPosition = laneFocusPosition
					targetDistance = laneDistance
				elseif laneRole == "Objective" and objective and targetDistance > 12 then
					targetRoot = objective
					moveTargetPosition = objective.Position
					targetDistance = (objective.Position - root.Position).Magnitude
				end
			elseif laneFocusPosition and not targetRoot then
				moveTargetPosition = laneFocusPosition
				targetDistance = (laneFocusPosition - root.Position).Magnitude
			end

			if moveTargetPosition then
				local now = os.clock()
				local moveAlpha = math.clamp(humanoid.MoveDirection.Magnitude * 1.2, 0, 1)
				local gaitSpeed = isRunner and 10.8 or (isBoss and 5.8 or (isExploder and 7.8 or (isShieldCarrier and 4.9 or (isScreamer and 7.2 or (isSpitter and 6.8 or (isArtillery and 5.2 or 6.4))))))
				local gaitTime = now * gaitSpeed + stridePhase
				local gaitSwing = math.sin(gaitTime) * (isBoss and 0.38 or (isRunner and 0.64 or (isShieldCarrier and 0.26 or (isScreamer and 0.54 or (isBruiser and 0.42 or 0.48))))) * moveAlpha
				local sway = math.sin(gaitTime * 0.5) * ((isRunner or isScreamer) and 0.08 or (isShieldCarrier and 0.03 or 0.05)) * moveAlpha
				local torsoLean = math.clamp(targetDistance / 80, 0, 1) * (isBoss and 0.12 or ((isRunner or isScreamer) and 0.24 or (isShieldCarrier and 0.1 or 0.18)))
				local torsoYaw = math.sin(gaitTime * 0.5) * (isBoss and 0.04 or 0.08) * moveAlpha + postureBias
				local torsoBob = math.abs(math.sin(gaitTime)) * (isBoss and 0.18 or (isRunner and 0.24 or 0.12)) * moveAlpha
				local headTilt = math.sin(gaitTime * 0.75) * ((isRunner or isScreamer) and 0.12 or (isShieldCarrier and 0.05 or 0.08)) * moveAlpha
				local hipRoll = math.sin(gaitTime) * ((isRunner or isScreamer) and 0.12 or (isShieldCarrier and 0.04 or 0.08)) * moveAlpha
				local armLead = isBoss and -0.18 or (isArtillery and -0.1 or 0.08)
				local attackPoseAlpha = math.clamp(1 - (targetDistance / (isBoss and 24 or ((isRunner or isScreamer) and 12 or (isShieldCarrier and 14 or 16)))), 0, 1)
				local hitReactUntil = tonumber(zombie:GetAttribute("HitReactUntil")) or 0
				local hitReactAlpha = math.clamp((hitReactUntil - now) / 0.18, 0, 1)
				local hitPitch = (tonumber(zombie:GetAttribute("HitReactPitch")) or 0) * hitReactAlpha
				local hitYaw = (tonumber(zombie:GetAttribute("HitReactYaw")) or 0) * hitReactAlpha
				local hitRoll = (tonumber(zombie:GetAttribute("HitReactRoll")) or 0) * hitReactAlpha
				local attackLean = attackPoseAlpha * (isBoss and 0.18 or ((isRunner or isScreamer) and 0.16 or (isShieldCarrier and 0.08 or 0.12)))
				local shoulderReach = attackPoseAlpha * (isBoss and 0.42 or (isBruiser and 0.32 or 0.22))
				local neckSnap = attackPoseAlpha * (isRunner and 0.16 or 0.1)
				local typeLean = 0
				local typeYaw = 0
				local typeRoll = 0
				local shoulderBias = 0
				local hipBias = 0
				local headBias = 0
				local eyePulse = 0
				local spinePulse = 0
				if isRunner then
					typeLean -= 0.18 + attackPoseAlpha * 0.08
					typeYaw += math.sin(gaitTime * 0.9) * 0.06
					shoulderBias += 0.16 + math.abs(gaitSwing) * 0.12
					hipBias += math.sin(gaitTime) * 0.06
					headBias += math.sin(gaitTime * 1.8) * 0.08
					eyePulse = 0.12
				elseif isScreamer then
					local screamWindup = math.clamp(1 - (math.max(0, screamerPulseReadyAt - now) / 1.2), 0, 1)
					typeLean -= 0.12 + screamWindup * 0.16
					typeYaw += math.sin(gaitTime * 0.8) * 0.08
					shoulderBias -= 0.08 + screamWindup * 0.18
					headBias += math.sin(gaitTime * 1.9) * 0.1 + screamWindup * 0.14
					eyePulse = 0.1 + screamWindup * 0.22
					spinePulse = screamWindup * 0.2
				elseif isSpitter then
					local spitWindup = math.clamp(1 - (math.max(0, spitterVolleyReadyAt - now) / 1.1), 0, 1)
					typeLean -= 0.1 + spitWindup * 0.12
					typeYaw += math.sin(gaitTime * 0.42) * 0.05
					shoulderBias -= spitWindup * 0.12
					headBias += spitWindup * 0.1
					eyePulse = spitWindup * 0.16
					spinePulse = spitWindup * 0.12
				elseif isExploder then
					local prime = math.clamp(1 - (targetDistance / math.max(1, self._missionConfig.Mission.ExploderTriggerDistance * 1.6)), 0, 1)
					typeRoll += math.sin(gaitTime * 1.6) * (0.08 + prime * 0.1)
					typeYaw += math.sin(gaitTime * 1.15) * 0.08
					headBias += math.sin(gaitTime * 2.2) * 0.1
					eyePulse = 0.1 + prime * 0.18
					spinePulse = 0.1 + prime * 0.12
				elseif isShieldCarrier then
					typeLean -= 0.04
					typeYaw += math.sin(gaitTime * 0.28) * 0.03
					shoulderBias += 0.16
					hipBias += math.sin(gaitTime * 0.45) * 0.02
					spinePulse = math.abs(math.sin(gaitTime * 0.35)) * 0.05
				elseif isBrute then
					typeLean -= 0.08
					shoulderBias += 0.08
					hipBias += math.sin(gaitTime * 0.5) * 0.04
					spinePulse = math.abs(math.sin(gaitTime * 0.5)) * 0.08
				elseif isBruiser then
					local chargeWindup = math.clamp(1 - (math.max(0, bruiserChargeReadyAt - now) / 1.25), 0, 1)
					typeLean -= 0.12 + chargeWindup * 0.12
					shoulderBias += 0.12 + chargeWindup * 0.18
					headBias -= chargeWindup * 0.06
					eyePulse = chargeWindup * 0.14
					spinePulse = chargeWindup * 0.12
				elseif isArtillery then
					local artilleryWindup = math.clamp(1 - (math.max(0, artilleryVolleyReadyAt - now) / 1.5), 0, 1)
					typeLean -= 0.05
					typeYaw += math.sin(gaitTime * 0.35) * 0.04
					shoulderBias -= 0.08
					headBias += artilleryWindup * 0.1
					eyePulse = artilleryWindup * 0.18
					spinePulse = artilleryWindup * 0.16
				end
				torsoJoint.Transform = CFrame.new(0, torsoBob, 0) * CFrame.Angles(-(torsoLean + attackLean) + typeLean - hitPitch, torsoYaw + typeYaw + hitYaw, sway * 0.4 + typeRoll + hitRoll)
				neckJoint.Transform = CFrame.Angles(torsoLean * 0.42 + neckSnap + headBias + hitPitch * 0.5, -torsoYaw * 1.65 - typeYaw * 0.65 - hitYaw * 1.15, headTilt - hitRoll * 0.4 + typeRoll * 0.3)
				leftShoulder.Transform = CFrame.Angles(gaitSwing + armLead - shoulderReach - shoulderBias - hitPitch * 0.8, 0, sway * 1.2 + hitRoll + typeRoll * 0.5)
				rightShoulder.Transform = CFrame.Angles(-gaitSwing + armLead - shoulderReach - shoulderBias - hitPitch * 0.8, 0, -sway * 1.2 - hitRoll - typeRoll * 0.5)
				leftHip.Transform = CFrame.Angles(-gaitSwing * 0.82 + hitPitch * 0.22, 0, hipRoll + hipBias + hitRoll * 0.45)
				rightHip.Transform = CFrame.Angles(gaitSwing * 0.82 + hitPitch * 0.22, 0, -hipRoll - hipBias - hitRoll * 0.45)
				eyeGlow.Transparency = math.clamp((isBoss and 0.04 or 0.1) + (1 - moveAlpha) * 0.08 + math.abs(math.sin(now * (gaitSpeed * 0.5))) * 0.08 - eyePulse, 0.02, 0.28)
				spinePlate.Transparency = math.clamp(0.04 + math.abs(gaitSwing) * 0.18 - spinePulse, 0.02, 0.22)

				if isRunner and targetRoot ~= objective and targetDistance <= self._missionConfig.Mission.RunnerBurstDistance and now >= runnerBurstReadyAt then
					runnerBurstReadyAt = now + self._missionConfig.Mission.RunnerBurstCooldown
					local burstDirection = moveTargetPosition - root.Position
					if burstDirection.Magnitude > 0.01 then
						self:_emitPulse(root.CFrame, Vector3.new(1.6, 1.6, 1.6), Color3.fromRGB(212, 248, 148), 0.38, 0.08)
						root.AssemblyLinearVelocity = burstDirection.Unit * self._missionConfig.Mission.RunnerBurstSpeed + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
						self:_emitPulse(root.CFrame, Vector3.new(2.4, 2.4, 2.4), Color3.fromRGB(192, 236, 124), 0.45, 0.1)
					end
				end

				if isScreamer and targetDistance <= self._missionConfig.Mission.ScreamerPreferredDistance and now >= screamerPulseReadyAt then
					screamerPulseReadyAt = now + self._missionConfig.Mission.ScreamerScreamCooldown
					self:_screamerPulse(zombie, root)
				end

				if isBrute and targetDistance <= self._missionConfig.Mission.BruteImpactRadius and now >= bruteImpactReadyAt then
					bruteImpactReadyAt = now + self._missionConfig.Mission.BruteImpactCooldown
					self:_emitPulse(root.CFrame * CFrame.new(0, -1.2, 0), Vector3.new(3.2, 0.18, 3.2), Color3.fromRGB(224, 176, 112), 0.26, 0.12)
					self:_bruteImpact(zombie, root, scaledStats)
				end

				if isBruiser and targetRoot ~= objective and targetDistance <= self._missionConfig.Mission.BruiserChargeDistance and now >= bruiserChargeReadyAt then
					bruiserChargeReadyAt = now + self._missionConfig.Mission.BruiserChargeCooldown
					self:_bruiseCharge(zombie, root, targetRoot)
				end

				if isSpitter and targetRoot ~= objective and targetDistance <= self._missionConfig.Mission.SpitterPreferredDistance and now >= spitterVolleyReadyAt then
					spitterVolleyReadyAt = now + self._missionConfig.Mission.SpitterVolleyCooldown
					self:_spitterVolley(zombie, root, scaledStats)
				end

				if isArtillery and targetDistance <= self._missionConfig.Mission.ArtilleryPreferredDistance and now >= artilleryVolleyReadyAt then
					artilleryVolleyReadyAt = now + self._missionConfig.Mission.ArtilleryVolleyCooldown
					self:_artilleryBarrage(zombie, root, scaledStats)
				end

				if isExploder and targetDistance <= self._missionConfig.Mission.ExploderTriggerDistance then
					self:_exploderBurst(zombie, root, scaledStats)
					break
				end

				if isBoss then
					local healthRatio = humanoid.Health / math.max(1, humanoid.MaxHealth)
					local shouldEnrage = healthRatio <= (bossProfile and bossProfile.enrageThreshold or self._missionConfig.Mission.BossEnrageThreshold)
					if shouldEnrage ~= bossEnrageActive then
						bossEnrageActive = shouldEnrage
						self:_setBossEnrageState(zombie, bossEnrageActive)
						if bossEnrageActive and currentMission.party then
							self:_notifyParty(currentMission.party, ("%s is enraged."):format(bossProfile and bossProfile.notifyName or "Boss"))
							self:_fireMissionState(currentMission.party, ("%s enraged"):format(bossProfile and bossProfile.notifyName or "Boss"))
						end
					end

					local bossCooldownScale = bossEnrageActive and self._missionConfig.Mission.BossEnrageCooldownScale or 1
					local primaryCooldown = (bossProfile and bossProfile.primaryCooldown)
						or self._missionConfig.Mission.BossSlamCooldown
					local secondaryCooldown = (bossProfile and bossProfile.secondaryCooldown)
						or (bossProfile and bossProfile.summonCooldown)
						or self._missionConfig.Mission.BossSummonCooldown
					if now >= bossSlamReadyAt and self:_performBossPrimaryAbility(bossProfile, zombie, root, scaledStats, targetDistance) then
						bossSlamReadyAt = now + (primaryCooldown * bossCooldownScale)
					elseif now >= bossSummonReadyAt and self:_performBossSecondaryAbility(bossProfile, zombie, root, scaledStats) then
						bossSummonReadyAt = now + (secondaryCooldown * bossCooldownScale)
					end
				end

				humanoid:MoveTo(moveTargetPosition)
				if targetDistance < (isBoss and 20 or (isArtillery and 16 or (isShieldCarrier and 11 or (isScreamer and 14 or (isSpitter and 13 or (isExploder and 10 or 16)))))) then
					local lungeDirection = moveTargetPosition - root.Position
					if lungeDirection.Magnitude > 0.01 then
						local bossLungeScale = bossEnrageActive and self._missionConfig.Mission.BossEnrageSpeedScale or 1
						root.AssemblyLinearVelocity = lungeDirection.Unit * ((isBoss and 18 or (isRunner and 22 or (isArtillery and 12 or (isShieldCarrier and 9 or (isScreamer and 12 or (isSpitter and 11 or (isExploder and 14 or (isBruiser and self._missionConfig.Mission.BruiserChargeSpeed or (isBrute and 10 or (isElite and 16 or 13)))))))))) * bossLungeScale) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
					end
				end
			else
				local idleTime = os.clock() + stridePhase
				local hitReactUntil = tonumber(zombie:GetAttribute("HitReactUntil")) or 0
				local hitReactAlpha = math.clamp((hitReactUntil - os.clock()) / 0.18, 0, 1)
				local hitPitch = (tonumber(zombie:GetAttribute("HitReactPitch")) or 0) * hitReactAlpha
				local hitYaw = (tonumber(zombie:GetAttribute("HitReactYaw")) or 0) * hitReactAlpha
				local hitRoll = (tonumber(zombie:GetAttribute("HitReactRoll")) or 0) * hitReactAlpha
				local idleBreath = math.abs(math.sin(idleTime * 1.2)) * 0.05
				local idleHunch = (isBoss and 0.05 or ((isRunner or isScreamer) and 0.03 or (isShieldCarrier and 0.015 or 0.02))) + postureBias
				local idleTypeLean = 0
				local idleTypeYaw = 0
				local idleTypeRoll = 0
				local idleHeadBias = 0
				local idleShoulderBias = 0
				local idleGlowBias = 0
				if isRunner then
					idleTypeLean = -0.08
					idleHeadBias = math.sin(idleTime * 2.2) * 0.07
					idleGlowBias = 0.04
				elseif isScreamer then
					idleTypeLean = -0.1
					idleTypeYaw = math.sin(idleTime * 1.4) * 0.07
					idleHeadBias = math.sin(idleTime * 2.4) * 0.09
					idleGlowBias = math.abs(math.sin(idleTime * 1.9)) * 0.1
				elseif isSpitter then
					idleTypeLean = -0.06
					idleHeadBias = math.sin(idleTime * 1.6) * 0.06
					idleGlowBias = math.abs(math.sin(idleTime * 1.3)) * 0.08
				elseif isExploder then
					idleTypeRoll = math.sin(idleTime * 1.8) * 0.08
					idleTypeYaw = math.sin(idleTime * 1.05) * 0.06
					idleGlowBias = math.abs(math.sin(idleTime * 2.6)) * 0.12
				elseif isShieldCarrier then
					idleTypeLean = -0.03
					idleShoulderBias = 0.1
					idleGlowBias = math.abs(math.sin(idleTime * 0.7)) * 0.04
				elseif isBrute then
					idleTypeLean = -0.04
					idleShoulderBias = 0.04
				elseif isBruiser then
					idleTypeLean = -0.06
					idleShoulderBias = 0.08
					idleGlowBias = math.abs(math.sin(idleTime * 0.9)) * 0.08
				elseif isArtillery then
					idleTypeYaw = math.sin(idleTime * 0.55) * 0.05
					idleHeadBias = math.abs(math.sin(idleTime * 0.8)) * 0.06
					idleGlowBias = math.abs(math.sin(idleTime * 1.1)) * 0.1
				end
				torsoJoint.Transform = CFrame.new(0, idleBreath, 0) * CFrame.Angles(idleHunch + idleTypeLean - hitPitch, math.sin(idleTime * 0.75) * 0.03 + idleTypeYaw + hitYaw, idleTypeRoll + hitRoll)
				neckJoint.Transform = CFrame.Angles(math.sin(idleTime * 1.8) * 0.03 + idleHeadBias + hitPitch * 0.45, -idleTypeYaw * 0.75 - hitYaw * 0.9, math.sin(idleTime * 0.9) * 0.04 - hitRoll * 0.35 + idleTypeRoll * 0.4)
				leftShoulder.Transform = CFrame.Angles(math.sin(idleTime * 1.1) * 0.05 - idleShoulderBias - hitPitch * 0.4, 0, hitRoll * 0.8 + idleTypeRoll * 0.5)
				rightShoulder.Transform = CFrame.Angles(-math.sin(idleTime * 1.1) * 0.05 - idleShoulderBias - hitPitch * 0.4, 0, -hitRoll * 0.8 - idleTypeRoll * 0.5)
				leftHip.Transform = CFrame.Angles(hitPitch * 0.12, 0, 0.02 + hitRoll * 0.22 + idleTypeRoll * 0.2)
				rightHip.Transform = CFrame.Angles(hitPitch * 0.12, 0, -0.02 - hitRoll * 0.22 - idleTypeRoll * 0.2)
				eyeGlow.Transparency = math.clamp((isBoss and 0.08 or 0.14) - idleGlowBias, 0.02, 0.18)
				spinePlate.Transparency = math.clamp(0.08 - idleGlowBias * 0.6, 0.02, 0.08)
			end

			task.wait(isBoss and 0.36 or (isRunner and 0.22 or (isShieldCarrier and 0.4 or (isScreamer and 0.26 or (isArtillery and 0.38 or (isSpitter and 0.34 or (isExploder and 0.26 or (isBruiser and 0.44 or (isBrute and 0.48 or (isElite and 0.42 or 0.3))))))))))
		end
	end)

	local deathConnection
	deathConnection = humanoid.Died:Connect(function()
		touchConnection:Disconnect()
		if deathConnection then
			deathConnection:Disconnect()
		end

		if root and root.Parent then
			self:_emitZombieDeathEffect(root.Position, isBoss or isElite or isBruiser or isBrute or isExploder or isShieldCarrier or isScreamer, isRunner or isSpitter)
		end

		local mission = self._activeMission
		if mission then
			local contributors = self:_getZombieContributors(zombie)
			mission.remainingZombies = math.max(0, mission.remainingZombies - 1)
			local bossType = zombie:GetAttribute("BossType")
			local bossProfile = isBoss and self:_getBossProfile(mission, bossType) or nil
			local bossRewardTokens = bossProfile and (bossProfile.rewardTokens or 0) or 0
			local bossExperienceBonus = bossProfile and (bossProfile.experienceBonus or 0) or 0
			local bossDisplayName = bossProfile and bossProfile.displayName or nil
			if isBoss then
				for _, player in ipairs(mission.party) do
					if player and player.Parent then
						self:_awardLootDrops(player, "BossKill", bossProfile and bossProfile.lootChanceScale or 0.75)
						if self._dailyOpsService then
							self._dailyOpsService:IncrementProgress(player, "BossKill", 1)
						end
						self:_emitProgressionUpdate(player)
					end
				end
				if bossRewardTokens > 0 then
					local rewardReason = "boss_kill"
					if bossType == "warden_hulk" then
						rewardReason = "warden_boss_kill"
					elseif bossType == "relay_overseer" then
						rewardReason = "relay_boss_kill"
					end
					self:_rewardParty(bossRewardTokens, rewardReason)
				end
				local bossAmmoDropCount = math.max(0, math.floor(self._missionConfig.Mission.BossAmmoDropCount or 0))
				for dropIndex = 1, bossAmmoDropCount do
					if root and root.Parent then
						local offset = Vector3.new((dropIndex - 1.5) * 2.4, 0, ((dropIndex % 2 == 0) and 1 or -1) * 1.2)
						self:_createSupplyPickup(mission.runtime, "Ammo", root.Position + offset)
					end
				end
				self:_notifyParty(mission.party, ("%s neutralized. Reward cache secured."):format(bossProfile and bossProfile.notifyName or "Boss"))
				self:_fireMissionState(mission.party, ("%s down"):format(bossProfile and bossProfile.notifyName or "Boss"))
			end

			if root and root.Parent and mission.runtime then
				local ammoDropChance = (isBoss or isElite or isBruiser or isBrute or isShieldCarrier or isScreamer or isSpitter or isExploder or isArtillery)
					and (self._missionConfig.Mission.EliteAmmoDropChance or 0)
					or (self._missionConfig.Mission.EnemyAmmoDropChance or 0)
				if ammoDropChance > 0 and math.random() <= ammoDropChance then
					self:_createSupplyPickup(mission.runtime, "Ammo", root.Position + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2)))
				end
			end

			for _, player in ipairs(contributors) do
				if player and player.Parent then
					self._persistenceService:IncrementStat(player, "zombiesDefeated", 1)
					if self._dailyOpsService then
						self._dailyOpsService:IncrementProgress(player, "ZombieKill", 1)
						if isSpitter then
							self._dailyOpsService:IncrementProgress(player, "SpitterKill", 1)
						end
						if isScreamer then
							self._dailyOpsService:IncrementProgress(player, "SupportKill", 1)
						end
						if isShieldCarrier then
							self._dailyOpsService:IncrementProgress(player, "TankKill", 1)
						end
						if isBruiser then
							self._dailyOpsService:IncrementProgress(player, "BruiserKill", 1)
						end
						if isExploder then
							self._dailyOpsService:IncrementProgress(player, "ExploderKill", 1)
						end
						if isArtillery then
							self._dailyOpsService:IncrementProgress(player, "ArtilleryKill", 1)
						end
					end
					local runStats = self:_getRunStats(player)
					if runStats then
						runStats.kills += 1
						if isSpitter then
							runStats.specialKills.Spitter = (runStats.specialKills.Spitter or 0) + 1
						end
						if isScreamer then
							runStats.specialKills.Screamer = (runStats.specialKills.Screamer or 0) + 1
						end
						if isShieldCarrier then
							runStats.specialKills.ShieldCarrier = (runStats.specialKills.ShieldCarrier or 0) + 1
						end
						if isBruiser then
							runStats.specialKills.Bruiser = (runStats.specialKills.Bruiser or 0) + 1
						end
						if isExploder then
							runStats.specialKills.Exploder = (runStats.specialKills.Exploder or 0) + 1
						end
						if isArtillery then
							runStats.specialKills.Artillery = (runStats.specialKills.Artillery or 0) + 1
						end
						if isBoss then
							runStats.bossesDefeated += 1
							runStats.lastBossName = bossDisplayName
								or (bossType == "warden_hulk" and "Warden Hulk")
								or (bossType == "relay_overseer" and "Relay Overseer")
								or "Siege Tyrant"
							runStats.bossRewardTokens = math.max(runStats.bossRewardTokens or 0, bossRewardTokens)
							runStats.bossExperienceBonus = math.max(runStats.bossExperienceBonus or 0, bossExperienceBonus)
						end
					end
					local weaponXp = self._missionConfig.WeaponProgression.ZombieKillExperience or 0
					if isElite or isBruiser or isBrute or isShieldCarrier or isScreamer or isSpitter or isExploder then
						weaponXp += self._missionConfig.WeaponProgression.EliteKillBonus or 0
					end
					if isBoss then
						weaponXp += self._missionConfig.WeaponProgression.BossKillBonus or 0
						if zombie:GetAttribute("BossType") == "warden_hulk" then
							weaponXp += self._missionConfig.WeaponProgression.WardenBossKillBonus or 0
						end
						if bossExperienceBonus > 0 then
							self:_awardMissionExperience(player, "BossKill", bossExperienceBonus)
						end
					end
					local equippedWeaponId = self._inventoryService and self._inventoryService:GetEquippedWeaponId(player) or nil
					if equippedWeaponId and weaponXp > 0 then
						local previousWeaponExperience = self._persistenceService:GetWeaponExperience(player, equippedWeaponId)
						local previousWeaponLevel = self._missionConfig.getWeaponLevelFromExperience(previousWeaponExperience)
						self._persistenceService:AddWeaponExperience(player, equippedWeaponId, weaponXp)
						local nextWeaponExperience = self._persistenceService:GetWeaponExperience(player, equippedWeaponId)
						local nextWeaponLevel = self._missionConfig.getWeaponLevelFromExperience(nextWeaponExperience)
						self:_grantWeaponMasteryRewards(player, equippedWeaponId, previousWeaponLevel, nextWeaponLevel)
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
	if self:_isCommanderHuntScenario() then
		self:_spawnCommanderHuntObjective(runtime, core)
	elseif self:_isEvacEscortScenario() then
		self:_spawnEvacEscortObjective(runtime, core)
	elseif self:_isPowerRelayScenario() then
		self:_spawnPowerRelayObjective(runtime, core)
	elseif self:_isPowerCellScenario() then
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

	local variant = self:_getExtractionVariant(self._activeMission)
	local baseOffset = layout.ExtractionOffset or Vector3.new(0, -0.3, -26)
	local padOffsets = { baseOffset }
	if variant == "split" then
		padOffsets = {
			baseOffset + Vector3.new(-18, 0, 0),
			baseOffset + Vector3.new(18, 0, 0),
		}
	end

	local createdPads = {}
	for index, offset in ipairs(padOffsets) do
		local suffix = index == 1 and "" or string.char(64 + index)
		local padName = index == 1 and "ExtractionPad" or ("ExtractionPad" .. suffix)
		local ringName = index == 1 and "ExtractionRing" or ("ExtractionRing" .. suffix)
		local beaconName = index == 1 and "ExtractionBeacon" or ("ExtractionBeacon" .. suffix)
		local signName = index == 1 and "ExtractionSign" or ("ExtractionSign" .. suffix)
		local signText = variant == "split" and ("PAD " .. index) or "LOCKED"

		local pad = Instance.new("Part")
		pad.Name = padName
		pad.Size = variant == "split" and Vector3.new(20, 1, 20) or Vector3.new(28, 1, 28)
		pad.Anchored = true
		pad.CanCollide = true
		pad.Material = Enum.Material.Neon
		pad.Color = Color3.fromRGB(76, 112, 104)
		pad.Transparency = 0.34
		pad.CFrame = anchor * CFrame.new(offset)
		pad.Parent = runtime

		local ring = Instance.new("Part")
		ring.Name = ringName
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(96, 138, 130)
		ring.Transparency = 0.74
		ring.Size = variant == "split" and Vector3.new(26, 0.12, 26) or Vector3.new(36, 0.12, 36)
		ring.CFrame = pad.CFrame * CFrame.new(0, 0.1, 0)
		ring.Parent = runtime

		local beacon = Instance.new("Part")
		beacon.Name = beaconName
		beacon.Anchored = true
		beacon.CanCollide = false
		beacon.CanQuery = false
		beacon.Material = Enum.Material.Neon
		beacon.Color = Color3.fromRGB(112, 208, 176)
		beacon.Transparency = 0.72
		beacon.Size = Vector3.new(2.2, 16, 2.2)
		beacon.CFrame = pad.CFrame * CFrame.new(0, 8, 0)
		beacon.Parent = runtime

		local beaconLight = Instance.new("PointLight")
		beaconLight.Name = "ExtractionBeaconLight"
		beaconLight.Color = Color3.fromRGB(162, 255, 220)
		beaconLight.Range = 18
		beaconLight.Brightness = 0.8
		beaconLight.Parent = beacon

		local labelPart, _ = self:_createWorldMarker(runtime, signName, signText, Color3.fromRGB(172, 196, 188), Vector2.new(160, 36), 16)
		labelPart.CFrame = pad.CFrame * CFrame.new(0, 6, 0)
		local labelGui = labelPart:FindFirstChildOfClass("BillboardGui")
		if labelGui then
			labelGui.MaxDistance = 84
		end

		table.insert(createdPads, pad)
	end

	if self._activeMission then
		self._activeMission.extractionPadBaseOffsets = padOffsets
		self._activeMission.extractionVariant = variant
	end

	self:_setExtractionVisualState(0)

	return createdPads[1]
end

function MissionService:_setExtractionVisualState(progress)
	local pads = self:_getExtractionPads()
	if #pads == 0 then
		return
	end

	local clamped = math.clamp(progress or 0, 0, 1)
	local extractionOpen = self._activeMission and self._activeMission.phase == "Extraction"

	for index, pad in ipairs(pads) do
		local suffix = index == 1 and "" or string.char(64 + index)
		local runtime = pad.Parent
		local ring = runtime and runtime:FindFirstChild(index == 1 and "ExtractionRing" or ("ExtractionRing" .. suffix))
		local beacon = runtime and runtime:FindFirstChild(index == 1 and "ExtractionBeacon" or ("ExtractionBeacon" .. suffix))
		local sign = runtime and runtime:FindFirstChild(index == 1 and "ExtractionSign" or ("ExtractionSign" .. suffix))
		local label = sign and sign:FindFirstChildOfClass("BillboardGui")
		local frame = label and label:FindFirstChildOfClass("Frame")
		local text = frame and frame:FindFirstChild("Label")

		pad.Color = (extractionOpen and Color3.fromRGB(110, 223, 185) or Color3.fromRGB(76, 112, 104)):Lerp(Color3.fromRGB(210, 255, 233), clamped)
		pad.Transparency = (extractionOpen and 0.18 or 0.34) - (clamped * 0.08)

		if ring and ring:IsA("BasePart") then
			ring.Color = (extractionOpen and Color3.fromRGB(167, 248, 215) or Color3.fromRGB(96, 138, 130)):Lerp(Color3.fromRGB(228, 255, 240), clamped)
			ring.Transparency = (extractionOpen and 0.58 or 0.74) - (clamped * 0.22)
		end
		if beacon and beacon:IsA("BasePart") then
			beacon.Color = (extractionOpen and Color3.fromRGB(144, 255, 214) or Color3.fromRGB(112, 208, 176)):Lerp(Color3.fromRGB(232, 255, 246), clamped)
			beacon.Transparency = (extractionOpen and 0.3 or 0.72) - (clamped * 0.12)
			beacon.Size = Vector3.new(2.2 + (clamped * 0.9), extractionOpen and 22 or 16, 2.2 + (clamped * 0.9))
			local beaconLight = beacon:FindFirstChild("ExtractionBeaconLight")
			if beaconLight and beaconLight:IsA("PointLight") then
				beaconLight.Brightness = extractionOpen and (1.8 + clamped * 1.4) or 0.8
				beaconLight.Range = extractionOpen and 28 or 18
				beaconLight.Color = beacon.Color
			end
		end
		if text and text:IsA("TextLabel") then
			local variant = self._activeMission and self._activeMission.extractionVariant or "standard"
			if extractionOpen then
				if variant == "split" then
					text.Text = clamped > 0 and ("PAD %d %d%%"):format(index, math.floor(clamped * 100)) or ("PAD " .. index)
				else
					text.Text = clamped > 0 and ("EXTRACT %d%%"):format(math.floor(clamped * 100)) or "OPEN EXTRACT"
				end
			else
				text.Text = variant == "split" and ("PAD " .. index) or "LOCKED"
			end
		end
	end

	local pad = pads[1]
	if extractionOpen and clamped <= 0.01 and pad then
		local openPulse = self:_emitPulse(pad.CFrame * CFrame.new(0, 1.2, 0), Vector3.new(18, 0.2, 18), Color3.fromRGB(172, 255, 218), 0.48, 0.22)
		if openPulse then
			openPulse.Material = Enum.Material.ForceField
			openPulse.Parent = pad.Parent or Workspace
		end
		local beaconBurst = self:_emitPulse(pad.CFrame * CFrame.new(0, 7, 0), Vector3.new(6, 18, 6), Color3.fromRGB(164, 255, 224), 0.7, 0.18)
		if beaconBurst then
			beaconBurst.Material = Enum.Material.Neon
			beaconBurst.Parent = pad.Parent or Workspace
		end
	end
end

function MissionService:_updateExtractionVariantLayout(mission, progress)
	if not mission or mission.phase ~= "Extraction" then
		return
	end

	local variant = mission.extractionVariant or self:_getExtractionVariant(mission)
	if variant ~= "moving" then
		return
	end

	local pad = self:_getExtractionPad()
	local runtime = mission.runtime
	local ring = runtime and runtime:FindFirstChild("ExtractionRing")
	local beacon = runtime and runtime:FindFirstChild("ExtractionBeacon")
	local sign = runtime and runtime:FindFirstChild("ExtractionSign")
	local anchor = self:_getMissionAnchorCFrame()
	local offsets = mission.extractionPadBaseOffsets
	local baseOffset = offsets and offsets[1]
	if not pad or not anchor or typeof(baseOffset) ~= "Vector3" then
		return
	end

	local travel = Vector3.new(0, 0, 18)
	local movedCFrame = anchor * CFrame.new(baseOffset:Lerp(baseOffset + travel, math.clamp(progress or 0, 0, 1)))
	pad.CFrame = movedCFrame
	if ring and ring:IsA("BasePart") then
		ring.CFrame = movedCFrame * CFrame.new(0, 0.1, 0)
	end
	if beacon and beacon:IsA("BasePart") then
		beacon.CFrame = movedCFrame * CFrame.new(0, 8, 0)
	end
	if sign and sign:IsA("BasePart") then
		sign.CFrame = movedCFrame * CFrame.new(0, 6, 0)
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
	local shockRing = self:_emitPulse(objective.CFrame, Vector3.new(14, 0.2, 14), Color3.fromRGB(255, 148, 132), 0.46, 0.16)
	if shockRing then
		shockRing.Material = Enum.Material.Neon
		shockRing.Parent = runtime or Workspace
	end
	local warningBeam = self:_emitPulse(objective.CFrame * CFrame.new(0, 5.5, 0), Vector3.new(2.6, 13.5, 2.6), Color3.fromRGB(255, 132, 120), 0.72, 0.18)
	if warningBeam then
		warningBeam.Material = Enum.Material.ForceField
		warningBeam.Parent = runtime or Workspace
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
		if self:_isPowerRelayScenario(mission) then
			self:_failMission("The relay core collapsed.")
		else
			self:_failMission("The bunker core was destroyed.")
		end
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
	player:SetAttribute("MissionAmmoCrates", 0)
	player:SetAttribute("MissionSensorBeacons", 0)
	player:SetAttribute("MissionBarriers", 0)
	player:SetAttribute("MissionReviveStims", 0)
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
		local ammoCrateTool = backpack:FindFirstChild("MissionAmmoCrate")
		if ammoCrateTool then
			ammoCrateTool:Destroy()
		end
		local sensorBeaconTool = backpack:FindFirstChild("MissionSensorBeacon")
		if sensorBeaconTool then
			sensorBeaconTool:Destroy()
		end
		local barrierTool = backpack:FindFirstChild("MissionBarrier")
		if barrierTool then
			barrierTool:Destroy()
		end
		local reviveStimTool = backpack:FindFirstChild("MissionReviveStim")
		if reviveStimTool then
			reviveStimTool:Destroy()
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
		local ammoCrateEquipped = character:FindFirstChild("MissionAmmoCrate")
		if ammoCrateEquipped then
			ammoCrateEquipped:Destroy()
		end
		local sensorBeaconEquipped = character:FindFirstChild("MissionSensorBeacon")
		if sensorBeaconEquipped then
			sensorBeaconEquipped:Destroy()
		end
		local barrierEquipped = character:FindFirstChild("MissionBarrier")
		if barrierEquipped then
			barrierEquipped:Destroy()
		end
		local reviveStimEquipped = character:FindFirstChild("MissionReviveStim")
		if reviveStimEquipped then
			reviveStimEquipped:Destroy()
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

	local modifierTraits = self:_getModifierRuntimeTraits()
	local ammoPickupAmount = math.max(1, math.floor((self._missionConfig.Mission.AmmoPickupAmount or 0) * modifierTraits.AmmoPickupScale + 0.5))
	state.reserveAmmo += ammoPickupAmount
	if self._skillTreeService then
		state.reserveAmmo += math.max(0, self._skillTreeService:GetAmmoPickupAmount(player, self._missionConfig.Mission.AmmoPickupAmount) - self._missionConfig.Mission.AmmoPickupAmount)
	end
	self:_fireMissionState({ player }, "Ammo cache secured")
	return true
end

function MissionService:_createSupplyPickup(runtime, pickupType, position)
	local pickup = Instance.new("Part")
	pickup.Name = pickupType == "Ammo" and "AmmoCache" or (pickupType == "Medkit" and "MedkitBag" or "SalvageCrate")
	local pickupSize = pickupType == "Ammo" and Vector3.new(2.6, 1.8, 2.2)
		or (pickupType == "Medkit" and Vector3.new(2.2, 1.4, 2.2) or Vector3.new(2.8, 2.2, 2.8))
	pickup.Size = pickupSize
	pickup.Anchored = true
	pickup.CanCollide = true
	pickup.Material = pickupType == "Salvage" and Enum.Material.WoodPlanks or Enum.Material.Metal
	pickup.Color = pickupType == "Ammo" and Color3.fromRGB(88, 126, 168) or (pickupType == "Medkit" and Color3.fromRGB(118, 162, 124) or Color3.fromRGB(146, 112, 74))
	pickup.CFrame = CFrame.new(position + Vector3.new(0, (pickupSize.Y * 0.5) + 0.15, 0))
	pickup.Parent = runtime
	pickup.TopSurface = Enum.SurfaceType.Smooth
	pickup.BottomSurface = Enum.SurfaceType.Smooth

	local glow = Instance.new("Part")
	glow.Name = pickup.Name .. "Glow"
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanQuery = false
	glow.Material = Enum.Material.Neon
	glow.Color = pickup.Color
	glow.Transparency = 0.35
	glow.Size = Vector3.new(pickupSize.X + 1.4, 0.18, pickupSize.Z + 1.4)
	glow.CFrame = pickup.CFrame * CFrame.new(0, -((pickupSize.Y * 0.5) + 0.08), 0)
	glow.Parent = runtime

	local markerText = pickupType == "Ammo" and "AMMO" or (pickupType == "Medkit" and "MEDKIT" or "SALVAGE")
	local markerColor = pickupType == "Ammo" and Color3.fromRGB(184, 226, 255) or (pickupType == "Medkit" and Color3.fromRGB(196, 255, 210) or Color3.fromRGB(255, 222, 164))
	local marker, _ = self:_createWorldMarker(runtime, pickup.Name .. "Marker", markerText, markerColor, Vector2.new(120, 30), 14)
	marker.CFrame = pickup.CFrame * CFrame.new(0, pickupSize.Y + 2.1, 0)
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
			local modifierTraits = self:_getModifierRuntimeTraits()
			local salvageAmount = self._skillTreeService and self._skillTreeService:GetSalvagePickupAmount(player, self._missionConfig.Mission.TokenPickupAmount) or self._missionConfig.Mission.TokenPickupAmount
			local rewardAmount = salvageAmount + modifierTraits.SalvagePickupBonus
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

function MissionService:AbortMissionForPlayer(player, status)
	local mission = self._activeMission
	if not mission then
		return false, "no_active_mission"
	end
	if not player or not player.Parent then
		return false, "invalid_player"
	end

	for _, partyMember in ipairs(mission.party or {}) do
		if partyMember == player then
			return self:AbortActiveMission(status or "Returning to bunker.")
		end
	end

	return false, "not_in_mission"
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
	local runtime = mission.runtime
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
	mission.waveTargetHostiles = scaledStats.spawnCount
	mission.phaseTimerLabel = nil
	mission.phaseTimerDuration = nil
	mission.phaseTimerEndsAt = nil
	local runnerCount = 0
	local shieldCarrierCount = 0
	local screamerCount = 0
	local artilleryCount = 0
	local spitterCount = 0
	local exploderCount = 0
	local bruteCount = 0
	local bruiserCount = 0
	local bossCount = 0
	local modifierTraits = self:_getModifierRuntimeTraits()
	for index = 1, scaledStats.spawnCount do
		local willBeBoss = index == scaledStats.spawnCount and mission.wave >= self._missionConfig.Mission.WaveCount
		local willBeBruiser = not willBeBoss and mission.wave >= 4 and index % modifierTraits.BruiserStep == 0
		local willBeArtillery = not willBeBoss and not willBeBruiser and mission.wave >= 5 and index % modifierTraits.ArtilleryStep == 0
		local willBeShieldCarrier = not willBeBoss and not willBeBruiser and not willBeArtillery and mission.wave >= 3 and index % modifierTraits.ShieldCarrierStep == 0
		local willBeScreamer = not willBeBoss and not willBeBruiser and not willBeArtillery and not willBeShieldCarrier and mission.wave >= 3 and index % modifierTraits.ScreamerStep == 0
		local willBeSpitter = not willBeBoss and not willBeBruiser and not willBeArtillery and not willBeShieldCarrier and not willBeScreamer and mission.wave >= 3 and index % modifierTraits.SpitterStep == 0
		local willBeExploder = not willBeBoss and not willBeBruiser and not willBeArtillery and not willBeShieldCarrier and not willBeScreamer and not willBeSpitter and mission.wave >= 4 and index % modifierTraits.ExploderStep == 0
		local willBeBrute = not willBeBoss and not willBeBruiser and not willBeArtillery and not willBeShieldCarrier and not willBeScreamer and not willBeSpitter and not willBeExploder and mission.wave >= 3 and index % modifierTraits.BruteStep == 0
		local willBeRunner = not willBeBoss and not willBeBruiser and not willBeShieldCarrier and not willBeScreamer and not willBeSpitter and not willBeExploder and not willBeBrute and mission.wave >= 2 and index % modifierTraits.RunnerStep == 0
		if willBeBoss then
			bossCount += 1
		elseif willBeBruiser then
			bruiserCount += 1
		elseif willBeArtillery then
			artilleryCount += 1
		elseif willBeShieldCarrier then
			shieldCarrierCount += 1
		elseif willBeScreamer then
			screamerCount += 1
		elseif willBeSpitter then
			spitterCount += 1
		elseif willBeExploder then
			exploderCount += 1
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
	if spitterCount > 0 then
		table.insert(mixParts, ("%d spitters"):format(spitterCount))
	end
	if shieldCarrierCount > 0 then
		table.insert(mixParts, ("%d shield carriers"):format(shieldCarrierCount))
	end
	if screamerCount > 0 then
		table.insert(mixParts, ("%d screamers"):format(screamerCount))
	end
	if artilleryCount > 0 then
		table.insert(mixParts, ("%d artillery fiends"):format(artilleryCount))
	end
	if exploderCount > 0 then
		table.insert(mixParts, ("%d exploders"):format(exploderCount))
	end
	if bruteCount > 0 then
		table.insert(mixParts, ("%d brutes"):format(bruteCount))
	end
	if bruiserCount > 0 then
		table.insert(mixParts, ("%d bruisers"):format(bruiserCount))
	end
	if bossCount > 0 then
		table.insert(mixParts, ("%d boss"):format(bossCount))
	end

	local mixSummary = #mixParts > 0 and (" Mix: " .. table.concat(mixParts, ", ") .. ".") or ""
	local modifierSummary = modifier and modifier.DisplayName ~= "Standard Ops" and (" Condition: " .. modifier.DisplayName .. ".") or ""
	local spawnOffsets = layout and layout.SpawnOffsets or nil
	local selectedSpawnOffsets, laneNames = self:_buildSpawnPlan(spawnOffsets, scaledStats.spawnCount, mission.wave)
	local laneSummary = laneNames and #laneNames > 0 and (" Breaches: " .. table.concat(laneNames, ", ") .. ".") or ""
	self:_notifyParty(mission.party, ("%s: Wave %d incoming with %d infected.%s%s Surge profile: %s."):format(
		scenario.DisplayName,
		mission.wave,
		scaledStats.spawnCount,
		mixSummary,
		modifierSummary .. laneSummary,
		modifierTraits.WaveSurgeLabel
	))
	self:_fireMissionState(mission.party, ("Wave %d/%d"):format(mission.wave, self._missionConfig.Mission.WaveCount))
	if bossCount > 0 then
		local bossProfile = self:_getBossProfile(mission)
		self:_notifyParty(mission.party, ("Boss contact: %s detected."):format(bossProfile.notifyName))
		self:_fireMissionState(mission.party, ("Boss wave: %s"):format(bossProfile.notifyName))
	end

	if selectedSpawnOffsets and #selectedSpawnOffsets > 0 then
		for _, baseOffset in ipairs(selectedSpawnOffsets) do
			self:_telegraphSpawnLane(runtime, self:_getLayoutWorldPosition(baseOffset), self:_describeSpawnLane(baseOffset), Color3.fromRGB(214, 174, 118))
		end
	end

	task.spawn(function()
		for index = 1, scaledStats.spawnCount do
			if not self._activeMission or self._activeMission ~= mission or mission.phase ~= "Combat" then
				return
			end
			if selectedSpawnOffsets and #selectedSpawnOffsets > 0 then
				local baseOffset = selectedSpawnOffsets[((index - 1) % #selectedSpawnOffsets) + 1]
				local jitter = Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
				local spawnPosition = self:_getContainedSpawnPosition(self:_getLayoutWorldPosition(baseOffset + jitter), 8)
				self:_spawnZombie(spawnPosition, scaledStats, index, {
					laneOffset = baseOffset,
				})
			else
				local angle = (math.pi * 2 / scaledStats.spawnCount) * index
				local radius = self._missionConfig.Mission.ZombieSpawnRadius + math.random(-6, 6)
				local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
				local spawnPosition = self:_getContainedSpawnPosition(missionSpawn.Position + offset, 8)
				self:_spawnZombie(spawnPosition, scaledStats, index)
			end
			if index < scaledStats.spawnCount then
				task.wait(index % math.max(2, math.floor(scaledStats.spawnCount / 3)) == 0 and 0.22 or 0.08)
			end
		end
	end)

	self:_scheduleWaveSurge(mission, scaledStats)
	self:_scheduleObjectivePressure(mission, scaledStats)
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
		local runtime = mission.runtime
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
		mission.waveTargetHostiles = (mission.waveTargetHostiles or 0) + surgeCount

		self:_notifyParty(mission.party, ("%s: reinforcements inbound."):format(modifierTraits.WaveSurgeLabel))
		self:_fireMissionState(mission.party, modifierTraits.WaveSurgeLabel)
		local spawnOffsets = layout and layout.SpawnOffsets or nil
		local selectedSpawnOffsets = self:_buildSpawnPlan(spawnOffsets, surgeCount, mission.wave + 1)
		if selectedSpawnOffsets and #selectedSpawnOffsets > 0 then
			for _, baseOffset in ipairs(selectedSpawnOffsets) do
				self:_telegraphSpawnLane(runtime, self:_getLayoutWorldPosition(baseOffset), self:_describeSpawnLane(baseOffset), Color3.fromRGB(255, 188, 132))
			end
		end

		task.spawn(function()
			for index = 1, surgeCount do
				if not self._activeMission or self._activeMission ~= mission or mission.phase ~= "Combat" or mission.remainingZombies <= 0 then
					return
				end

				local spawnPosition
				if selectedSpawnOffsets and #selectedSpawnOffsets > 0 then
					local baseOffset = selectedSpawnOffsets[((index - 1) % #selectedSpawnOffsets) + 1]
					local jitter = Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
					spawnPosition = self:_getContainedSpawnPosition(self:_getLayoutWorldPosition(baseOffset + jitter), 8)
				else
					local angle = (math.pi * 2 / surgeCount) * index
					local radius = self._missionConfig.Mission.ZombieSpawnRadius + 8 + math.random(-4, 4)
					local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
					spawnPosition = self:_getContainedSpawnPosition(anchor.Position + offset, 8)
				end

				self:_spawnZombie(spawnPosition, surgeStats, scaledStats.spawnCount + index, selectedSpawnOffsets and #selectedSpawnOffsets > 0 and {
					laneOffset = selectedSpawnOffsets[((index - 1) % #selectedSpawnOffsets) + 1],
				} or nil)
				if index < surgeCount then
					task.wait(index % math.max(2, math.floor(surgeCount / 2)) == 0 and 0.18 or 0.07)
				end
			end
		end)
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
	mission.phaseTimerLabel = nil
	mission.phaseTimerDuration = nil
	mission.phaseTimerEndsAt = nil
	self:_setExtractionVisualState(0)
	local finalePlan = self:_getExtractionFinalePlan(mission)
	self:_notifyParty(mission.party, ("All waves cleared. %s"):format(finalePlan.notifyText or "Regroup on the extraction pad."))
	self:_fireMissionState(mission.party, finalePlan.stateText or "Objective: reach extraction")
	self:_startExtractionPressure(mission)

	task.spawn(function()
		while self._activeMission == mission and mission.phase == "Extraction" do
			local pads = self:_getExtractionPads()
			if #pads == 0 then
				task.wait(0.5)
				continue
			end
			self:_updateExtractionVariantLayout(mission, 0)

			local livePlayers = 0
			local insidePlayers = 0
			local padsOccupied = {}
			for _, player in ipairs(self:_getLivePartyMembers()) do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				if humanoid and humanoid.Health > 0 and rootPart and not self:_isCharacterDowned(character) then
					livePlayers += 1
					for padIndex, pad in ipairs(pads) do
						if self:_isCharacterInsideExtractionPad(rootPart, pad) then
							insidePlayers += 1
							padsOccupied[padIndex] = true
							break
						end
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
			local variant = mission.extractionVariant or self:_getExtractionVariant(mission)
			local allInside = insidePlayers >= requiredInside
			if variant == "split" and #pads >= 2 then
				allInside = allInside and padsOccupied[1] == true and padsOccupied[2] == true
			end

			if allInside then
				mission.extractionStartedAt = mission.extractionStartedAt or os.clock()
				local extractionHold = self:_getExtractionHoldDuration(mission.party)
				mission.phaseTimerLabel = "Extraction"
				mission.phaseTimerDuration = extractionHold
				mission.phaseTimerEndsAt = mission.extractionStartedAt + extractionHold
				local remaining = math.max(0, extractionHold - (os.clock() - mission.extractionStartedAt))
				local progress = 1 - (remaining / extractionHold)
				self:_updateExtractionVariantLayout(mission, progress)
				self:_setExtractionVisualState(progress)
				self:_fireMissionState(mission.party, ("Extracting in %ds"):format(math.ceil(remaining)))
				if remaining <= 0 then
					local activeSeasonalEvent, seasonalRewardBonus, seasonalExperienceBonus = self:_getActiveSeasonalMissionBonus()
					local rewardBonus = (mission.scenario and mission.scenario.RewardBonus or 0) + (mission.modifier and mission.modifier.RewardBonus or 0) + seasonalRewardBonus
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
								if self:_isPowerRelayScenario(mission) then
									self._dailyOpsService:IncrementProgress(player, "PowerRelayComplete", 1)
								elseif self:_isEvacEscortScenario(mission) then
									self._dailyOpsService:IncrementProgress(player, "EvacTunnelComplete", 1)
								elseif self:_isCommanderHuntScenario(mission) then
									self._dailyOpsService:IncrementProgress(player, "BlacksiteSweepComplete", 1)
								end
							end
							self:_awardMissionExperience(player, "MissionComplete", 40)
							if seasonalExperienceBonus > 0 then
								self:_awardMissionExperience(player, "SeasonalEvent", seasonalExperienceBonus)
							end
							self:_awardLootDrops(player, "MissionComplete", 1)
							self:_emitProgressionUpdate(player)
						end
					end
					local extractionSummary = "Extraction complete. Squad returned to bunker."
					if activeSeasonalEvent and (seasonalRewardBonus > 0 or seasonalExperienceBonus > 0) then
						extractionSummary ..= (" %s bonus applied."):format(activeSeasonalEvent.DisplayName)
					end
					local extractionNotify = "Extraction complete. Returning to the bunker."
					if activeSeasonalEvent and (seasonalRewardBonus > 0 or seasonalExperienceBonus > 0) then
						extractionNotify = ("%s %s bonus secured: +%dT and +%d XP."):format(
							extractionNotify,
							activeSeasonalEvent.DisplayName,
							seasonalRewardBonus,
							seasonalExperienceBonus
						)
					end
					self:_notifyResults(mission, true, extractionSummary, completionReward)
					self:_notifyParty(mission.party, extractionNotify)
					self:_fireMissionState(mission.party, "Extraction complete")
					self:_finishAndReturnToLobby(mission, "Back in the bunker.")
					return
				end
			else
				mission.extractionStartedAt = nil
				mission.phaseTimerLabel = nil
				mission.phaseTimerDuration = nil
				mission.phaseTimerEndsAt = nil
				self:_updateExtractionVariantLayout(mission, 0)
				self:_setExtractionVisualState(0)
				if variant == "split" and #pads >= 2 then
					local occupiedCount = 0
					for _, occupied in pairs(padsOccupied) do
						if occupied then
							occupiedCount += 1
						end
					end
					self:_fireMissionState(mission.party, ("Objective: hold both pads (%d/%d inside | %d/2 pads)"):format(insidePlayers, requiredInside, occupiedCount))
				else
					self:_fireMissionState(mission.party, ("Objective: regroup on extraction (%d/%d)"):format(insidePlayers, requiredInside))
				end
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
		if self:_isCommanderHuntScenario(mission) then
			local objective = self:_getMissionObjective()
			local eliminated = objective and objective:GetAttribute("CommanderEliminated") == true
			if not eliminated then
				self:_notifyParty(mission.party, "Waves cleared. Eliminate the blacksite commander to unlock extraction.")
				self:_fireMissionState(mission.party, "Objective: eliminate commander")
				return
			end
		elseif self:_isEvacEscortScenario(mission) then
			local objective = self:_getMissionObjective()
			local reached = objective and objective:GetAttribute("ReachedEvacCheckpoint") or 0
			local required = objective and objective:GetAttribute("RequiredEvacCheckpoints") or 3
			if reached < required then
				self:_notifyParty(mission.party, ("Waves cleared. Advance the convoy through the remaining checkpoints (%d/%d) to unlock extraction."):format(reached, required))
				self:_fireMissionState(mission.party, ("Objective: escort convoy %d/%d"):format(reached, required))
				return
			end
		elseif self:_isPowerRelayScenario(mission) then
			local objective = self:_getMissionObjective()
			local stabilized = objective and objective:GetAttribute("StabilizedRelayNodes") or 0
			local required = objective and objective:GetAttribute("RequiredRelayNodes") or 3
			if stabilized < required then
				self:_notifyParty(mission.party, ("Waves cleared. Stabilize the remaining relay nodes (%d/%d) to unlock extraction."):format(stabilized, required))
				self:_fireMissionState(mission.party, ("Objective: stabilize relay nodes %d/%d"):format(stabilized, required))
				return
			end
		elseif self:_isPowerCellScenario(mission) then
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

	local interWaveDelay = self._missionConfig.Mission.InterWaveDelay
	mission.phaseTimerLabel = "Next Wave"
	mission.phaseTimerDuration = interWaveDelay
	mission.phaseTimerEndsAt = os.clock() + interWaveDelay
	self:_notifyParty(mission.party, ("Wave %d cleared. Next wave in %ds."):format(mission.wave, interWaveDelay))
	self:_fireMissionState(mission.party, ("Wave %d cleared. Next wave in %ds."):format(mission.wave, interWaveDelay))
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
		warn("[MissionService] StartMission failed: missing_runtime")
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
		waveTargetHostiles = 0,
		phase = "Combat",
		phaseTimerLabel = nil,
		phaseTimerDuration = nil,
		phaseTimerEndsAt = nil,
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
	local activeSeasonalEvent, seasonalRewardBonus, seasonalExperienceBonus = self:_getActiveSeasonalMissionBonus()
	local seasonalMissionText = ""
	if activeSeasonalEvent and (seasonalRewardBonus > 0 or seasonalExperienceBonus > 0) then
		seasonalMissionText = (" %s live bonus: +%dT and +%d XP on full extraction."):format(activeSeasonalEvent.DisplayName, seasonalRewardBonus, seasonalExperienceBonus)
	end
	if self:_isCommanderHuntScenario(self._activeMission) then
		self:_notifyParty(request.party, ("Mission started in %s [%s]. Sweep the blacksite, survive the waves, and finish the commander target. %s%s"):format(self._activeMission.layout.DisplayName, modifierText, modifierDescription, seasonalMissionText))
		self:_fireMissionState(request.party, self:_getObjectiveStateText(self._activeMission))
	elseif self:_isEvacEscortScenario(self._activeMission) then
		self:_notifyParty(request.party, ("Mission started in %s [%s]. Advance the evac convoy through each checkpoint and survive the waves. %s%s"):format(self._activeMission.layout.DisplayName, modifierText, modifierDescription, seasonalMissionText))
		self:_fireMissionState(request.party, self:_getObjectiveStateText(self._activeMission))
	elseif self:_isPowerRelayScenario(self._activeMission) then
		self:_notifyParty(request.party, ("Mission started in %s [%s]. Stabilize the relay nodes, hold the chain together, and survive the waves. %s%s"):format(self._activeMission.layout.DisplayName, modifierText, modifierDescription, seasonalMissionText))
		self:_fireMissionState(request.party, self:_getObjectiveStateText(self._activeMission))
	elseif self:_isPowerCellScenario(self._activeMission) then
		self:_notifyParty(request.party, ("Mission started in %s [%s]. Defend the relay, recover power cells, and survive the waves. %s%s"):format(self._activeMission.layout.DisplayName, modifierText, modifierDescription, seasonalMissionText))
		self:_fireMissionState(request.party, self:_getObjectiveStateText(self._activeMission))
	elseif self:_isNestScenario(self._activeMission) then
		self:_notifyParty(request.party, ("Mission started in %s [%s]. Defend the relay, hunt infected nests, and survive the waves. %s%s"):format(self._activeMission.layout.DisplayName, modifierText, modifierDescription, seasonalMissionText))
		self:_fireMissionState(request.party, self:_getObjectiveStateText(self._activeMission))
	else
		self:_notifyParty(request.party, ("Mission started in %s [%s]. Defend the bunker core and survive the waves. %s%s"):format(self._activeMission.layout.DisplayName, modifierText, modifierDescription, seasonalMissionText))
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
