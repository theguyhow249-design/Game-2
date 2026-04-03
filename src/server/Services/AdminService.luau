local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local MODERATIONSTORE_NAME = "ZombieSurvivalModeration_v1"

local AdminService = {}
AdminService.__index = AdminService

local ROLE_WEIGHT = {
	none = 0,
	moderator = 1,
	admin = 2,
	owner = 3,
}

function AdminService.new(context)
	local self = setmetatable({}, AdminService)
	self._roleService = context.RoleService
	self._tokenService = context.TokenService
	self._skillTreeService = context.SkillTreeService
	self._flowService = context.FlowService
	self._missionService = context.MissionService
	self._inventoryService = context.InventoryService
	self._gamePassService = context.GamePassService
	self._subscriptionService = context.SubscriptionService
	self._tokenEconomy = context.TokenEconomy
	self._missionConfig = context.MissionConfig
	self._leaderstatsService = context.LeaderstatsService
	self._leaderboardService = context.LeaderboardService
	self._remotes = context.Remotes
	self._remoteNames = context.RemoteNames
	self._banCache = {}
	self._supportBotsByKey = {}
	self._autoSupportBotsByUserId = {}
	self._moderationStore = nil
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(MODERATIONSTORE_NAME)
	end)
	if ok then
		self._moderationStore = store
	end
	return self
end

function AdminService:_getBanStoreKey(userId)
	return ("ban_%d"):format(tonumber(userId) or 0)
end

function AdminService:_loadBanRecord(userId)
	local normalizedUserId = tonumber(userId) or 0
	if normalizedUserId <= 0 then
		return nil
	end
	if self._banCache[normalizedUserId] ~= nil then
		return self._banCache[normalizedUserId] or nil
	end
	if not self._moderationStore then
		self._banCache[normalizedUserId] = false
		return nil
	end

	local ok, data = pcall(function()
		return self._moderationStore:GetAsync(self:_getBanStoreKey(normalizedUserId))
	end)
	if ok and type(data) == "table" and data.banned == true then
		self._banCache[normalizedUserId] = data
	else
		self._banCache[normalizedUserId] = false
	end
	return self._banCache[normalizedUserId] or nil
end

function AdminService:_saveBanRecord(userId, payload)
	local normalizedUserId = tonumber(userId) or 0
	if normalizedUserId <= 0 then
		return false
	end
	self._banCache[normalizedUserId] = payload or false
	if self._moderationStore then
		pcall(function()
			if payload then
				self._moderationStore:SetAsync(self:_getBanStoreKey(normalizedUserId), payload)
			else
				self._moderationStore:RemoveAsync(self:_getBanStoreKey(normalizedUserId))
			end
		end)
	end
	return true
end

function AdminService:Start()
	local function handlePlayer(player)
		local banRecord = self:_loadBanRecord(player.UserId)
		if banRecord and banRecord.banned == true then
			task.defer(function()
				if player and player.Parent == Players then
					player:Kick(tostring(banRecord.reason or "Banned by owner"))
				end
			end)
		end
	end

	Players.PlayerAdded:Connect(handlePlayer)
	Players.PlayerRemoving:Connect(function(player)
		self._autoSupportBotsByUserId[player.UserId] = nil
		self:_clearSupportBotsForOwner(player.UserId)
		self:_clearSupportBotsForTarget(player.UserId)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		handlePlayer(player)
	end

	task.spawn(function()
		while true do
			self:_maintainSupportBots()
			task.wait(2)
		end
	end)
end

function AdminService:GetRoleKey(player)
	local identity = self._roleService and self._roleService:GetIdentity(player) or nil
	if not identity then
		return "none"
	end
	if identity.isOwner == true then
		return "owner"
	end
	if identity.isAdmin == true then
		return "admin"
	end
	if identity.isModerator == true then
		return "moderator"
	end
	return "none"
end

function AdminService:HasRole(player, requiredRole)
	local current = ROLE_WEIGHT[self:GetRoleKey(player)] or 0
	local required = ROLE_WEIGHT[tostring(requiredRole or "none")] or 0
	return current >= required
end

function AdminService:IsAuthorized(player)
	return self:HasRole(player, "moderator")
end

function AdminService:_getActiveParty(player)
	local mission = self._missionService and self._missionService._activeMission or nil
	if mission and type(mission.party) == "table" and #mission.party > 0 then
		return mission.party
	end
	return { player }
end

function AdminService:_getSupportBotKey(ownerUserId, targetUserId)
	return ("%d:%d"):format(tonumber(ownerUserId) or 0, tonumber(targetUserId) or 0)
end

function AdminService:_isPlayerInActiveParty(player)
	local mission = self._missionService and self._missionService._activeMission or nil
	if not mission or type(mission.party) ~= "table" then
		return false
	end
	for _, member in ipairs(mission.party) do
		if member == player then
			return true
		end
	end
	return false
end

function AdminService:_getMissionPartyForPlayer(player)
	local mission = self._missionService and self._missionService._activeMission or nil
	if not mission or type(mission.party) ~= "table" then
		return nil
	end
	for _, member in ipairs(mission.party) do
		if member == player then
			return mission.party
		end
	end
	return nil
end

function AdminService:_getSupportBotsFolder(mission)
	if not mission or not mission.runtime then
		return nil
	end
	local folder = mission.runtime:FindFirstChild("SupportBots")
	if folder and folder:IsA("Folder") then
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = "SupportBots"
	folder.Parent = mission.runtime
	return folder
end

function AdminService:_clearSupportBotByKey(key)
	local entry = key and self._supportBotsByKey[key]
	if not entry then
		return
	end
	entry.active = false
	self._supportBotsByKey[key] = nil
	if entry.model and entry.model.Parent then
		entry.model:Destroy()
	end
end

function AdminService:_clearSupportBotsForOwner(ownerUserId)
	for key, entry in pairs(self._supportBotsByKey) do
		if entry.ownerUserId == ownerUserId then
			self:_clearSupportBotByKey(key)
		end
	end
end

function AdminService:_clearSupportBotsForTarget(targetUserId)
	for key, entry in pairs(self._supportBotsByKey) do
		if entry.targetUserId == targetUserId then
			self:_clearSupportBotByKey(key)
		end
	end
end

function AdminService:_getNearestZombie(mission, position, maxDistance)
	if not mission or not mission.zombiesFolder or not position then
		return nil, math.huge
	end
	local nearest = nil
	local nearestDistance = maxDistance or 82
	for _, zombie in ipairs(mission.zombiesFolder:GetChildren()) do
		if zombie:IsA("Model") then
			local root = zombie.PrimaryPart or zombie:FindFirstChild("HumanoidRootPart")
			local humanoid = zombie:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				local distance = (root.Position - position).Magnitude
				if distance < nearestDistance then
					nearest = zombie
					nearestDistance = distance
				end
			end
		end
	end
	return nearest, nearestDistance
end

function AdminService:_runSupportBot(entry)
	local lastShotAt = 0
	while entry and entry.active do
		local mission = self._missionService and self._missionService._activeMission or nil
		local owner = Players:GetPlayerByUserId(entry.ownerUserId)
		local target = Players:GetPlayerByUserId(entry.targetUserId)
		local model = entry.model
		if mission ~= entry.mission or not owner or not target or not model or model.Parent == nil or not self:_isPlayerInActiveParty(target) then
			break
		end

		local character = target.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if rootPart and humanoid and humanoid.Health > 0 then
			local now = os.clock()
			local orbitDirection = (entry.targetUserId % 2 == 0) and 1 or -1
			local lateralOffset = 4.8 * orbitDirection
			local backOffset = -5.2 + math.sin(now + entry.phase) * 1.1
			local hoverOffset = 4.4 + math.sin((now * 2.2) + entry.phase) * 0.6
			local desiredPosition = rootPart.Position + (rootPart.CFrame.RightVector * lateralOffset) + (rootPart.CFrame.LookVector * backOffset) + Vector3.new(0, hoverOffset, 0)
			local zombie = self:_getNearestZombie(mission, desiredPosition, 84)
			local lookTarget = zombie and (zombie.PrimaryPart or zombie:FindFirstChild("HumanoidRootPart")) or rootPart
			model:PivotTo(CFrame.lookAt(desiredPosition, lookTarget.Position))

			if zombie and now - lastShotAt >= entry.fireCooldown then
				lastShotAt = now
				self._missionService:_damageZombie(zombie, entry.damage, owner)
				local zombieRoot = zombie.PrimaryPart or zombie:FindFirstChild("HumanoidRootPart")
				if zombieRoot and self._missionService._emitPulse then
					self._missionService:_emitPulse(CFrame.new(zombieRoot.Position), Vector3.new(1.6, 1.6, 1.6), Color3.fromRGB(132, 224, 255), 0.42, 0.12)
				end
				if rootPart and self._missionService._emitPulse then
					self._missionService:_emitPulse(CFrame.new(desiredPosition), Vector3.new(0.5, 0.5, 5.4), Color3.fromRGB(164, 236, 255), 0.62, 0.08)
				end
			end
		end

		task.wait(0.2)
	end

	self:_clearSupportBotByKey(entry and entry.key)
end

function AdminService:_spawnSupportBotFor(owner, target)
	if not owner or not target or not self._missionService then
		return false
	end
	local mission = self._missionService._activeMission
	if not mission or not self:_isPlayerInActiveParty(owner) or not self:_isPlayerInActiveParty(target) then
		return false
	end

	local key = self:_getSupportBotKey(owner.UserId, target.UserId)
	self:_clearSupportBotByKey(key)

	local folder = self:_getSupportBotsFolder(mission)
	if not folder then
		return false
	end

	local model = Instance.new("Model")
	model.Name = ("SupportBot_%s"):format(target.Name)
	model.Parent = folder

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(1.6, 1.1, 1.6)
	core.Anchored = true
	core.CanCollide = false
	core.CanTouch = false
	core.CanQuery = false
	core.Material = Enum.Material.Metal
	core.Color = Color3.fromRGB(82, 118, 154)
	core.Parent = model

	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Size = Vector3.new(2.8, 0.18, 2.8)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(164, 236, 255)
	ring.Parent = model

	local podLeft = Instance.new("Part")
	podLeft.Name = "PodLeft"
	podLeft.Size = Vector3.new(0.9, 0.5, 1.2)
	podLeft.Anchored = true
	podLeft.CanCollide = false
	podLeft.CanTouch = false
	podLeft.CanQuery = false
	podLeft.Material = Enum.Material.Metal
	podLeft.Color = Color3.fromRGB(64, 92, 124)
	podLeft.Parent = model

	local podRight = podLeft:Clone()
	podRight.Name = "PodRight"
	podRight.Parent = model

	local eye = Instance.new("Part")
	eye.Name = "Eye"
	eye.Size = Vector3.new(0.5, 0.5, 0.18)
	eye.Anchored = true
	eye.CanCollide = false
	eye.CanTouch = false
	eye.CanQuery = false
	eye.Material = Enum.Material.Neon
	eye.Color = Color3.fromRGB(194, 246, 255)
	eye.Parent = model

	local glow = Instance.new("PointLight")
	glow.Range = 12
	glow.Brightness = 0.9
	glow.Color = Color3.fromRGB(164, 236, 255)
	glow.Parent = core

	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(90, 176, 214)
	highlight.OutlineColor = Color3.fromRGB(214, 248, 255)
	highlight.FillTransparency = 0.75
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model

	local labelGui = Instance.new("BillboardGui")
	labelGui.Name = "Marker"
	labelGui.Size = UDim2.fromOffset(120, 24)
	labelGui.StudsOffset = Vector3.new(0, 2.4, 0)
	labelGui.AlwaysOnTop = false
	labelGui.MaxDistance = 60
	labelGui.Parent = core

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = "SUPPORT BOT"
	label.TextColor3 = Color3.fromRGB(214, 246, 255)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 13
	label.Parent = labelGui

	model.PrimaryPart = core

	local entry = {
		key = key,
		active = true,
		model = model,
		ownerUserId = owner.UserId,
		targetUserId = target.UserId,
		mission = mission,
		damage = 14,
		fireCooldown = 0.7,
		phase = (target.UserId % 9) * 0.4,
	}
	self._supportBotsByKey[key] = entry

	task.spawn(function()
		while entry.active and model.Parent do
			local yBob = math.sin(os.clock() * 2.8 + entry.phase) * 0.16
			ring.CFrame = core.CFrame * CFrame.new(0, -0.52 + yBob, 0) * CFrame.Angles(math.rad(90), 0, 0)
			podLeft.CFrame = core.CFrame * CFrame.new(-1.18, -0.04, 0)
			podRight.CFrame = core.CFrame * CFrame.new(1.18, -0.04, 0)
			eye.CFrame = core.CFrame * CFrame.new(0, 0, -0.82)
			task.wait(0.05)
		end
	end)

	task.spawn(function()
		self:_runSupportBot(entry)
	end)

	return true
end

function AdminService:_spawnSupportBotsForParty(owner)
	local party = self:_getMissionPartyForPlayer(owner)
	if not party then
		return 0
	end
	local count = 0
	for _, member in ipairs(party) do
		if member and member.Parent == Players and member:GetAttribute("InMission") == true then
			if self:_spawnSupportBotFor(owner, member) then
				count += 1
			end
		end
	end
	return count
end

function AdminService:_toggleAutoSupportBots(owner)
	local enabled = self._autoSupportBotsByUserId[owner.UserId] ~= true
	if enabled then
		self._autoSupportBotsByUserId[owner.UserId] = true
		owner:SetAttribute("AutoSupportBots", true)
		return true, self:_spawnSupportBotsForParty(owner)
	end
	self._autoSupportBotsByUserId[owner.UserId] = nil
	owner:SetAttribute("AutoSupportBots", false)
	self:_clearSupportBotsForOwner(owner.UserId)
	return false, 0
end

function AdminService:_maintainSupportBots()
	local mission = self._missionService and self._missionService._activeMission or nil
	for ownerUserId in pairs(self._autoSupportBotsByUserId) do
		local owner = Players:GetPlayerByUserId(ownerUserId)
		if not owner then
			self._autoSupportBotsByUserId[ownerUserId] = nil
			self:_clearSupportBotsForOwner(ownerUserId)
		elseif not mission or not self:_isPlayerInActiveParty(owner) then
			self:_clearSupportBotsForOwner(ownerUserId)
		else
			for _, member in ipairs(mission.party or {}) do
				if member and member.Parent == Players and member:GetAttribute("InMission") == true then
					local key = self:_getSupportBotKey(ownerUserId, member.UserId)
					if not self._supportBotsByKey[key] then
						self:_spawnSupportBotFor(owner, member)
					end
				end
			end
		end
	end

	for key, entry in pairs(self._supportBotsByKey) do
		local missionValid = mission and entry.mission == mission
		local owner = Players:GetPlayerByUserId(entry.ownerUserId)
		local target = Players:GetPlayerByUserId(entry.targetUserId)
		if not missionValid or not owner or not target or not entry.model or entry.model.Parent == nil then
			self:_clearSupportBotByKey(key)
		end
	end
end

function AdminService:_healPlayers(players)
	local healedCount = 0
	for _, target in ipairs(players) do
		local character = target and target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Parent then
			humanoid.Health = humanoid.MaxHealth
			healedCount += 1
		end
	end
	return healedCount
end

function AdminService:_revivePlayers(players)
	if not self._missionService or not self._missionService._activeMission then
		return 0
	end

	local revivedCount = 0
	for _, target in ipairs(players) do
		local mission = self._missionService._activeMission
		local state = mission and mission.downedStates and mission.downedStates[target.UserId]
		if state then
			self._missionService:_clearDownedState(target, true)
			revivedCount += 1
		else
			local character = target and target.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Parent and humanoid.Health <= 0 then
				humanoid.Health = humanoid.MaxHealth
				revivedCount += 1
			end
		end
	end
	return revivedCount
end

function AdminService:_refreshIdentity(player)
	if self._gamePassService then
		self._gamePassService:Refresh(player)
	end
	if self._subscriptionService then
		self._subscriptionService:RefreshState(player)
	end
	if self._roleService then
		self._roleService:Apply(player)
	end
	return self._inventoryService and self._inventoryService:BuildProgressionPayload(player) or nil
end

function AdminService:_resolveTarget(requester, request)
	if type(request) ~= "table" then
		return requester
	end
	local targetUserId = tonumber(request.targetUserId)
	if not targetUserId or targetUserId <= 0 then
		return requester
	end
	return Players:GetPlayerByUserId(targetUserId)
end

function AdminService:_notifyTarget(target, message)
	if not target or not self._remotes or not self._remoteNames then
		return
	end
	self._remotes:FireEventFor(target, self._remoteNames.Events.Notification, {
		userId = target.UserId,
		message = tostring(message or "Admin action applied."),
	})
end

function AdminService:_grantTokens(target, amount, sourceTag)
	if not target or not self._tokenService then
		return false
	end
	self._tokenService:AddTokens(target, amount, "AdminGrant", sourceTag or "owner_panel")
	return true
end

function AdminService:_grantExperience(target, amount)
	if not target or not self._skillTreeService then
		return false
	end
	self._skillTreeService:AwardExperience(target, amount, "AdminGrant")
	return true
end

function AdminService:_unlockCatalogCategory(target, categoryName)
	if not target or not self._inventoryService or not self._tokenEconomy then
		return 0
	end
	local unlockedCount = 0
	for _, item in ipairs(self._tokenEconomy.getCategoryItems(categoryName) or {}) do
		if item and item.Id then
			self._inventoryService:UnlockItem(target, item.Id)
			unlockedCount += 1
		end
	end
	return unlockedCount
end

function AdminService:_setSeasonalEvent(eventId)
	if not self._tokenEconomy or not self._tokenEconomy.setSeasonalEventOverride then
		return false
	end
	return self._tokenEconomy.setSeasonalEventOverride(eventId)
end

function AdminService:_getSeasonalEventState()
	local activeEvent = self._tokenEconomy and self._tokenEconomy.getActiveSeasonalEvent and self._tokenEconomy.getActiveSeasonalEvent() or nil
	local overrideId = self._tokenEconomy and self._tokenEconomy.getSeasonalEventOverrideId and self._tokenEconomy.getSeasonalEventOverrideId() or nil
	return {
		activeEventId = activeEvent and activeEvent.Id or nil,
		activeEventName = activeEvent and activeEvent.DisplayName or "No active event",
		overrideId = overrideId,
	}
end

function AdminService:_getPanelState(player, target)
	local panelState = self:_getSeasonalEventState()
	local mission = self._missionService and self._missionService._activeMission or nil
	local roleKey = self:GetRoleKey(player)
	panelState.roleKey = roleKey
	panelState.roleLabel = roleKey == "owner" and "Owner"
		or (roleKey == "admin" and "Admin" or (roleKey == "moderator" and "Moderator" or "Operator"))
	panelState.runState = "Lobby"
	panelState.runSummary = "No active run"
	if mission then
		panelState.runState = tostring(mission.phase or "Combat")
		panelState.runSummary = ("%s | Wave %d/%d | %d hostiles"):format(
			tostring(mission.scenario and mission.scenario.DisplayName or "Mission"),
			tonumber(mission.wave) or 0,
			tonumber(self._missionConfig and self._missionConfig.Mission and self._missionConfig.Mission.WaveCount) or 0,
			tonumber(mission.remainingZombies) or 0
		)
	end
	if target and target.Parent == Players then
		panelState.targetUserId = target.UserId
		panelState.targetName = target.DisplayName or target.Name
		panelState.targetRole = tostring(target:GetAttribute("PlayerTitle") or "Survivor")
		panelState.targetLevel = math.max(1, tonumber(target:GetAttribute("SkillTreeLevel")) or 1)
		panelState.targetTokens = math.max(0, tonumber(target:GetAttribute("DeployTokens")) or tonumber(target:GetAttribute("Tokens")) or 0)
		panelState.targetRuns = math.max(0, tonumber(target:GetAttribute("AllTimeMissionsCompleted")) or tonumber(target:GetAttribute("MissionsCompleted")) or 0)
		panelState.targetKills = math.max(0, tonumber(target:GetAttribute("AllTimeZombiesDefeated")) or tonumber(target:GetAttribute("ZombiesDefeated")) or 0)
	end
	return panelState
end

function AdminService:_makeResponse(status, extra)
	local payload = extra or {}
	payload.status = status
	return payload
end

function AdminService:_refillPartyAmmo(players)
	if not self._missionService then
		return 0
	end
	local refilled = 0
	for _, target in ipairs(players) do
		local state = self._missionService._weaponState and self._missionService._weaponState[target.UserId]
		local weaponId = state and state.weaponId
		local weapon = weaponId and self._missionConfig and self._missionConfig.getWeaponDefinition and self._missionConfig.getWeaponDefinition(weaponId) or nil
		if state and weapon and weapon.WeaponType ~= "Melee" and weapon.WeaponType ~= "Fists" then
			state.currentAmmo = weapon.MagazineSize or state.currentAmmo
			state.reserveAmmo = math.max(state.reserveAmmo or 0, weapon.ReserveAmmo or state.reserveAmmo or 0)
			refilled += 1
			if self._missionService._fireMissionState then
				self._missionService:_fireMissionState({ target }, "Ammo refilled by owner")
			end
		end
	end
	return refilled
end

function AdminService:_teleportPartyToObjective(players)
	if not self._missionService then
		return 0
	end
	local anchor = self._missionService:_getMissionObjective() or self._missionService:_getExtractionPad()
	if not anchor then
		return 0
	end
	local moved = 0
	for index, target in ipairs(players) do
		local character = target and target.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart and character then
			character:PivotTo(anchor.CFrame + Vector3.new((index - 1) * 3, 4, 0))
			moved += 1
		end
	end
	return moved
end

function AdminService:_restorePlayers(players)
	local revived = self:_revivePlayers(players)
	local healed = self:_healPlayers(players)
	local refilled = self:_refillPartyAmmo(players)
	return healed, revived, refilled
end

function AdminService:_refreshProgressViews(target)
	if self._leaderstatsService and self._leaderstatsService.RefreshPlayer then
		self._leaderstatsService:RefreshPlayer(target)
	end
	if self._roleService and self._roleService.Apply then
		self._roleService:Apply(target)
	end
	if self._leaderboardService and self._leaderboardService.RefreshWorldBoard then
		self._leaderboardService:RefreshWorldBoard("allTime")
	end
end

function AdminService:_setExactLevel(target, level)
	local nextLevel = math.max(1, math.floor(level or 1))
	local skillRanks = self._persistenceService:GetSkills(target)
	local spentPoints = 0
	for _, rank in pairs(skillRanks) do
		spentPoints += math.max(0, math.floor(tonumber(rank) or 0))
	end
	local totalSkillPoints = math.max(0, (nextLevel - 1) * (self._skillTreeConfig.SkillPointsPerLevel or 1))
	self._persistenceService:SetLevel(target, nextLevel)
	self._persistenceService:SetExperience(target, 0)
	self._persistenceService:SetSkillPoints(target, math.max(0, totalSkillPoints - spentPoints))
	if self._skillTreeService and self._skillTreeService._emitProgression then
		self._skillTreeService:_emitProgression(target)
	end
	target:SetAttribute("Level", nextLevel)
	target:SetAttribute("SkillTreeLevel", nextLevel)
	self:_refreshProgressViews(target)
	return nextLevel
end

function AdminService:_setExactStat(target, statName, value)
	local nextValue = math.max(0, math.floor(value or 0))
	self._persistenceService:SetStat(target, statName, nextValue, true)
	if statName == "zombiesDefeated" then
		target:SetAttribute("ZombiesDefeated", nextValue)
		target:SetAttribute("AllTimeZombiesDefeated", nextValue)
		target:SetAttribute("MonthlyZombiesDefeated", nextValue)
		target:SetAttribute("WeeklyZombiesDefeated", nextValue)
		target:SetAttribute("DailyZombiesDefeated", nextValue)
	elseif statName == "missionsCompleted" then
		target:SetAttribute("MissionsCompleted", nextValue)
		target:SetAttribute("AllTimeMissionsCompleted", nextValue)
		target:SetAttribute("MonthlyMissionsCompleted", nextValue)
		target:SetAttribute("WeeklyMissionsCompleted", nextValue)
		target:SetAttribute("DailyMissionsCompleted", nextValue)
	end
	self:_refreshProgressViews(target)
	return nextValue
end

function AdminService:_skipWave()
	if not self._missionService or not self._missionService._activeMission then
		return false, "no_active_mission"
	end
	local mission = self._missionService._activeMission
	if mission.phase ~= "Combat" then
		return false, "no_active_mission"
	end
	for _, zombie in ipairs(mission.zombiesFolder:GetChildren()) do
		zombie:Destroy()
	end
	mission.remainingZombies = 0
	self._missionService:_completeWave()
	return true
end

function AdminService:_forceBossWave()
	if not self._missionService or not self._missionService._activeMission then
		return false, "no_active_mission"
	end
	local mission = self._missionService._activeMission
	if mission.phase ~= "Combat" then
		return false, "no_active_mission"
	end
	for _, zombie in ipairs(mission.zombiesFolder:GetChildren()) do
		zombie:Destroy()
	end
	mission.remainingZombies = 0
	mission.wave = math.max(0, (self._missionConfig.Mission.WaveCount or 3) - 1)
	self._missionService:_spawnWave()
	return true
end

function AdminService:_spawnSpecialZombie(kind)
	if not self._missionService or not self._missionService._activeMission then
		return false, "no_active_mission"
	end
	local mission = self._missionService._activeMission
	local anchor = self._missionService:_getMissionObjective() or self._missionService:_getExtractionPad()
	if not anchor then
		return false, "no_active_mission"
	end

	local baseHealth = self._missionConfig.Mission.ZombieBaseHealth + math.max(0, ((mission.wave or 1) - 1) * 10)
	local baseDamage = self._missionConfig.Mission.ZombieBaseDamage + math.max(0, (mission.wave or 1) - 1)
	local scaledStats = {
		health = math.max(40, math.floor(baseHealth * 1.2)),
		damage = math.max(6, math.floor(baseDamage * 1.1)),
		spawnCount = (kind == "runner" and 3) or ((kind == "spitter" or kind == "bruiser" or kind == "exploder") and 6) or (kind == "artillery" and 8) or 4,
	}
	if kind == "warden_hulk" then
		scaledStats.health = math.max(120, math.floor(baseHealth * 2.6))
		scaledStats.damage = math.max(12, math.floor(baseDamage * 1.8))
		scaledStats.spawnCount = 1
		scaledStats.forceBoss = true
		scaledStats.bossProfileKey = "warden_hulk"
	end

	local index = (kind == "runner" and 3) or ((kind == "spitter" or kind == "bruiser" or kind == "exploder") and 6) or (kind == "artillery" and 8) or (kind == "warden_hulk" and 1) or 4
	local spawnOffset = kind == "runner" and Vector3.new(10, 0, 4) or (kind == "spitter" and Vector3.new(0, 0, 12) or (kind == "exploder" and Vector3.new(12, 0, 10) or (kind == "artillery" and Vector3.new(16, 0, -4)) or (kind == "bruiser" and Vector3.new(-14, 0, 2) or (kind == "warden_hulk" and Vector3.new(-6, 0, 14) or Vector3.new(-10, 0, 4)))))
	self._missionService._activeMission.remainingZombies += 1
	self._missionService:_spawnZombie(anchor.Position + spawnOffset, scaledStats, index)
	return true
end

function AdminService:_giveAllDrops(players)
	if not self._missionService then
		return 0
	end
	local total = 0
	for _, target in ipairs(players) do
		local drops = self._missionService:_awardLootDrops(target, "AdminDrop", 12)
		total += type(drops) == "table" and #drops or 0
	end
	return total
end

function AdminService:_forceMissionPreview(scenarioId, layoutId, modifierId)
	if not self._flowService or not self._flowService.ForceMissionPreview then
		return false, "missing_flow_service"
	end
	return self._flowService:ForceMissionPreview(scenarioId, layoutId, modifierId or "modifier_standard_ops")
end

function AdminService:_requireRole(player, role)
	if not self:HasRole(player, role) then
		return false, "unauthorized"
	end
	return true
end

function AdminService:Execute(player, request)
	if not self:IsAuthorized(player) then
		return false, "unauthorized"
	end

	local command = nil
	if type(request) == "table" then
		command = tostring(request.commandId or request.command or "")
	else
		command = tostring(request or "")
		request = {}
	end

	if command == "get_panel_state" then
		local target = self:_resolveTarget(player, request)
		local payload = self:_makeResponse("Owner console linked.")
		payload.panelState = self:_getPanelState(player, target)
		return true, payload
	end

	if command == "heal_self" then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return false, "missing_character"
		end
		humanoid.Health = humanoid.MaxHealth
		return true, self:_makeResponse("Restored health to maximum.")
	elseif command == "heal_squad" then
		local healedCount = self:_healPlayers(self:_getActiveParty(player))
		return true, self:_makeResponse(("Restored %d squad member%s to full health."):format(healedCount, healedCount == 1 and "" or "s"))
	elseif command == "revive_squad" then
		local revivedCount = self:_revivePlayers(self:_getActiveParty(player))
		if revivedCount <= 0 then
			return false, "no_downed_targets"
		end
		return true, self:_makeResponse(("Revived %d downed squad member%s."):format(revivedCount, revivedCount == 1 and "" or "s"))
	elseif command == "grant_tokens" then
		self:_grantTokens(player, 250, "owner_panel")
		return true, self:_makeResponse("Granted +250 deploy tokens.")
	elseif command == "grant_tokens_large" then
		self:_grantTokens(player, 1000, "owner_panel")
		return true, self:_makeResponse("Granted +1000 deploy tokens.")
	elseif command == "grant_xp" then
		self:_grantExperience(player, 250)
		return true, self:_makeResponse("Granted +250 bunker XP.")
	elseif command == "grant_xp_large" then
		self:_grantExperience(player, 1000)
		return true, self:_makeResponse("Granted +1000 bunker XP.")
	elseif command == "refresh_access" then
		local progression = self:_refreshIdentity(player)
		return true, self:_makeResponse("Refreshed identity, access, and entitlements.", {
			progression = progression,
			panelState = self:_getPanelState(player, player),
		})
	elseif command == "return_to_lobby" then
		if self._missionService and self._missionService:AbortActiveMission("Owner command: returning squad to bunker.") then
			return true, self:_makeResponse("Active run aborted. Squad returned to bunker.")
		end
		if self._flowService and self._flowService:AbortActiveDeployment("Owner command: deployment canceled.") then
			return true, self:_makeResponse("Active deployment canceled.")
		end
		return false, "no_active_run"
	elseif command == "restore_squad" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local healed, revived, refilled = self:_restorePlayers(self:_getActiveParty(player))
		return true, self:_makeResponse(("Squad restored. Healed %d, revived %d, refilled %d."):format(healed, revived, refilled), {
			panelState = self:_getPanelState(player, player),
		})
	end

	local target = self:_resolveTarget(player, request)
	if not target or target.Parent ~= Players then
		return false, "missing_target"
	end

	if command == "heal_target" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local healedCount = self:_healPlayers({ target })
		if healedCount <= 0 then
			return false, "missing_character"
		end
		self:_notifyTarget(target, "An admin restored your health.")
		return true, self:_makeResponse(("Healed %s."):format(target.DisplayName), {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "grant_tokens_target" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		self:_grantTokens(target, 1000, "owner_target")
		self:_notifyTarget(target, "Owner granted you +1000 deploy tokens.")
		return true, self:_makeResponse(("Granted +1000 deploy tokens to %s."):format(target.DisplayName), {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "grant_xp_target" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		self:_grantExperience(target, 1000)
		self:_notifyTarget(target, "Owner granted you +1000 bunker XP.")
		return true, self:_makeResponse(("Granted +1000 bunker XP to %s."):format(target.DisplayName), {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "set_target_level" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local value = tonumber(request.value)
		if value == nil then
			return false, "invalid_amount"
		end
		local nextLevel = self:_setExactLevel(target, value)
		self:_notifyTarget(target, ("Admin set your level to %d."):format(nextLevel))
		return true, self:_makeResponse(("Set %s to level %d."):format(target.DisplayName, nextLevel), {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "max_target_level" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local nextLevel = self:_setExactLevel(target, 1000)
		self:_notifyTarget(target, "Admin pushed your level to the cap preset.")
		return true, self:_makeResponse(("Set %s to level %d."):format(target.DisplayName, nextLevel), {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "set_target_kills" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local value = tonumber(request.value)
		if value == nil then
			return false, "invalid_amount"
		end
		local nextValue = self:_setExactStat(target, "zombiesDefeated", value)
		return true, self:_makeResponse(("Set %s kills to %d."):format(target.DisplayName, nextValue), {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "set_target_runs" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local value = tonumber(request.value)
		if value == nil then
			return false, "invalid_amount"
		end
		local nextValue = self:_setExactStat(target, "missionsCompleted", value)
		return true, self:_makeResponse(("Set %s runs to %d."):format(target.DisplayName, nextValue), {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "set_target_tokens" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local value = tonumber(request.value)
		if value == nil then
			return false, "invalid_amount"
		end
		local nextValue = self._tokenService:SetBalance(target, value, "AdminSet", "owner_panel_exact")
		return true, self:_makeResponse(("Set %s tokens to %d."):format(target.DisplayName, nextValue), {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "unlock_all_weapons_target" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local count = self:_unlockCatalogCategory(target, self._tokenEconomy.ShopCategories.Weapons)
		self:_notifyTarget(target, "Owner granted your full weapon catalog.")
		return true, self:_makeResponse(("Granted %d weapon unlocks to %s."):format(count, target.DisplayName), {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "unlock_all_cosmetics_target" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local count = self:_unlockCatalogCategory(target, self._tokenEconomy.ShopCategories.Cosmetics)
		self:_notifyTarget(target, "Owner granted your cosmetic catalog.")
		return true, self:_makeResponse(("Granted %d cosmetic unlocks to %s."):format(count, target.DisplayName), {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "grant_target_bundle" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		self:_grantTokens(target, 1000, "owner_target_bundle")
		self:_grantExperience(target, 1000)
		local weaponCount = self:_unlockCatalogCategory(target, self._tokenEconomy.ShopCategories.Weapons)
		local cosmeticCount = self:_unlockCatalogCategory(target, self._tokenEconomy.ShopCategories.Cosmetics)
		self:_notifyTarget(target, "Owner granted your recovery bundle, progression boost, and full catalog.")
		return true, self:_makeResponse(("Granted bundle to %s: +1000T, +1000 XP, %d weapons, %d cosmetics."):format(target.DisplayName, weaponCount, cosmeticCount), {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "restore_target" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local healed, revived, refilled = self:_restorePlayers({ target })
		if healed <= 0 and revived <= 0 and refilled <= 0 then
			return false, "missing_character"
		end
		self:_notifyTarget(target, "An admin restored your combat state.")
		return true, self:_makeResponse(("Restored %s. Healed %d, revived %d, refilled %d."):format(target.DisplayName, healed, revived, refilled), {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "terminate_player" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local displayName = target.DisplayName
		task.defer(function()
			if target and target.Parent == Players then
				target:Kick("Removed by owner panel.")
			end
		end)
		return true, self:_makeResponse(("Terminated %s from this server."):format(displayName))
	elseif command == "promote_moderator" then
		local okay, code = self:_requireRole(player, "owner")
		if not okay then
			return false, code
		end
		self._roleService:SetGrant(target.UserId, "moderator", player.UserId)
		self:_notifyTarget(target, "You were granted moderator access.")
		return true, self:_makeResponse(("Granted moderator access to %s."):format(target.DisplayName), {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "promote_admin" then
		local okay, code = self:_requireRole(player, "owner")
		if not okay then
			return false, code
		end
		self._roleService:SetGrant(target.UserId, "admin", player.UserId)
		self:_notifyTarget(target, "You were granted admin access.")
		return true, self:_makeResponse(("Granted admin access to %s."):format(target.DisplayName), {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "clear_access" then
		local okay, code = self:_requireRole(player, "owner")
		if not okay then
			return false, code
		end
		self._roleService:ClearGrant(target.UserId)
		self:_notifyTarget(target, "Your elevated access was cleared.")
		return true, self:_makeResponse(("Cleared elevated access for %s."):format(target.DisplayName), {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "ban_player" then
		local okay, code = self:_requireRole(player, "owner")
		if not okay then
			return false, code
		end
		local payload = {
			banned = true,
			reason = "Banned by owner panel.",
			bannedBy = player.UserId,
			updatedAt = os.time(),
		}
		self:_saveBanRecord(target.UserId, payload)
		local displayName = target.DisplayName
		task.defer(function()
			if target and target.Parent == Players then
				target:Kick(payload.reason)
			end
		end)
		return true, self:_makeResponse(("Banned %s from the game."):format(displayName), {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "unban_player" then
		local okay, code = self:_requireRole(player, "owner")
		if not okay then
			return false, code
		end
		self:_saveBanRecord(target.UserId, nil)
		self:_notifyTarget(target, "Your ban record was cleared by the owner.")
		return true, self:_makeResponse(("Cleared ban record for %s."):format(target.DisplayName), {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "event_auto" then
		local okay, code = self:_requireRole(player, "owner")
		if not okay then
			return false, code
		end
		self:_setSeasonalEvent("auto")
		return true, self:_makeResponse("Seasonal events returned to automatic rotation.", {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "event_none" then
		local okay, code = self:_requireRole(player, "owner")
		if not okay then
			return false, code
		end
		self:_setSeasonalEvent("none")
		return true, self:_makeResponse("Seasonal event drops are stopped for this server.", {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "event_spring" then
		local okay, code = self:_requireRole(player, "owner")
		if not okay then
			return false, code
		end
		self:_setSeasonalEvent("spring_surge")
		return true, self:_makeResponse("Forced Spring Surge for this server.", {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "event_harvest" then
		local okay, code = self:_requireRole(player, "owner")
		if not okay then
			return false, code
		end
		self:_setSeasonalEvent("harvest_hunt")
		return true, self:_makeResponse("Forced Harvest Hunt for this server.", {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "event_winter" then
		local okay, code = self:_requireRole(player, "owner")
		if not okay then
			return false, code
		end
		self:_setSeasonalEvent("winter_siege")
		return true, self:_makeResponse("Forced Winter Siege for this server.", {
			panelState = self:_getPanelState(player, target),
		})
	elseif command == "skip_wave" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local success, reason = self:_skipWave()
		if not success then
			return false, reason
		end
		return true, self:_makeResponse("Skipped the current wave.")
	elseif command == "force_boss" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local success, reason = self:_forceBossWave()
		if not success then
			return false, reason
		end
		return true, self:_makeResponse("Forced a boss wave.")
	elseif command == "refill_ammo" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local refilled = self:_refillPartyAmmo(self:_getActiveParty(player))
		if refilled <= 0 then
			return false, "no_active_mission"
		end
		return true, self:_makeResponse(("Refilled ammo for %d squad member%s."):format(refilled, refilled == 1 and "" or "s"))
	elseif command == "teleport_squad" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local moved = self:_teleportPartyToObjective(self:_getActiveParty(player))
		if moved <= 0 then
			return false, "no_active_mission"
		end
		return true, self:_makeResponse(("Teleported %d squad member%s to the mission objective."):format(moved, moved == 1 and "" or "s"))
	elseif command == "spawn_support_bots" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local spawned = self:_spawnSupportBotsForParty(player)
		if spawned <= 0 then
			return false, "no_active_mission"
		end
		return true, self:_makeResponse(("Deployed %d support bot%s for the active squad."):format(spawned, spawned == 1 and "" or "s"))
	elseif command == "toggle_support_bots_auto" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local enabled, spawned = self:_toggleAutoSupportBots(player)
		if enabled then
			return true, self:_makeResponse(("Support bot auto-run enabled. %d bot%s staged."):format(spawned, spawned == 1 and "" or "s"))
		end
		return true, self:_makeResponse("Support bot auto-run disabled.")
	elseif command == "spawn_brute" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local success, reason = self:_spawnSpecialZombie("brute")
		if not success then
			return false, reason
		end
		return true, self:_makeResponse("Spawned a brute near the mission objective.")
	elseif command == "spawn_bruiser" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local success, reason = self:_spawnSpecialZombie("bruiser")
		if not success then
			return false, reason
		end
		return true, self:_makeResponse("Spawned a bruiser near the mission objective.")
	elseif command == "spawn_runner" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local success, reason = self:_spawnSpecialZombie("runner")
		if not success then
			return false, reason
		end
		return true, self:_makeResponse("Spawned a runner near the mission objective.")
	elseif command == "spawn_spitter" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local success, reason = self:_spawnSpecialZombie("spitter")
		if not success then
			return false, reason
		end
		return true, self:_makeResponse("Spawned a spitter near the mission objective.")
	elseif command == "spawn_exploder" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local success, reason = self:_spawnSpecialZombie("exploder")
		if not success then
			return false, reason
		end
		return true, self:_makeResponse("Spawned an exploder near the mission objective.")
	elseif command == "spawn_artillery" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local success, reason = self:_spawnSpecialZombie("artillery")
		if not success then
			return false, reason
		end
		return true, self:_makeResponse("Spawned an artillery fiend near the mission objective.")
	elseif command == "spawn_warden_hulk" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local success, reason = self:_spawnSpecialZombie("warden_hulk")
		if not success then
			return false, reason
		end
		return true, self:_makeResponse("Spawned Warden Hulk near the mission objective.")
	elseif command == "give_all_drops" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local unlocked = self:_giveAllDrops(self:_getActiveParty(player))
		return true, self:_makeResponse(("Forced %d loot unlock%s across the active squad."):format(unlocked, unlocked == 1 and "" or "s"))
	elseif command == "force_power_relay" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local success, reason = self:_forceMissionPreview("directive_power_relay", "arena_power_relay", "modifier_standard_ops")
		if not success then
			return false, reason
		end
		return true, self:_makeResponse("Queued Power Relay as the next deploy route.")
	elseif command == "force_evac_tunnel" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local success, reason = self:_forceMissionPreview("directive_evac_tunnel", "arena_evac_tunnel", "modifier_standard_ops")
		if not success then
			return false, reason
		end
		return true, self:_makeResponse("Queued Evac Tunnel as the next deploy route.")
	elseif command == "force_blacksite_sweep" then
		local okay, code = self:_requireRole(player, "admin")
		if not okay then
			return false, code
		end
		local success, reason = self:_forceMissionPreview("directive_commander_hunt", "arena_blacksite_sweep", "modifier_standard_ops")
		if not success then
			return false, reason
		end
		return true, self:_makeResponse("Queued Blacksite Sweep as the next deploy route.")
	end

	return false, "unknown_command"
end

return AdminService
