local AdminService = {}
AdminService.__index = AdminService

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
	return self
end

function AdminService:Start()
end

function AdminService:IsAuthorized(player)
	local identity = self._roleService and self._roleService:GetIdentity(player) or nil
	return identity ~= nil and identity.isAdmin == true
end

function AdminService:_getActiveParty(player)
	local mission = self._missionService and self._missionService._activeMission or nil
	if mission and type(mission.party) == "table" and #mission.party > 0 then
		return mission.party
	end
	return { player }
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

function AdminService:Execute(player, commandId)
	if not self:IsAuthorized(player) then
		return false, "unauthorized"
	end

	local command = tostring(commandId or "")
	if command == "heal_self" then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return false, "missing_character"
		end
		humanoid.Health = humanoid.MaxHealth
		return true, {
			status = "Restored health to maximum.",
		}
	elseif command == "heal_squad" then
		local healedCount = self:_healPlayers(self:_getActiveParty(player))
		return true, {
			status = ("Restored %d squad member%s to full health."):format(healedCount, healedCount == 1 and "" or "s"),
		}
	elseif command == "revive_squad" then
		local revivedCount = self:_revivePlayers(self:_getActiveParty(player))
		if revivedCount <= 0 then
			return false, "no_downed_targets"
		end
		return true, {
			status = ("Revived %d downed squad member%s."):format(revivedCount, revivedCount == 1 and "" or "s"),
		}
	elseif command == "grant_tokens" then
		self._tokenService:AddTokens(player, 250, "AdminGrant", "owner_panel")
		return true, {
			status = "Granted +250 deploy tokens.",
		}
	elseif command == "grant_tokens_large" then
		self._tokenService:AddTokens(player, 1000, "AdminGrant", "owner_panel")
		return true, {
			status = "Granted +1000 deploy tokens.",
		}
	elseif command == "grant_xp" then
		self._skillTreeService:AwardExperience(player, 250, "AdminGrant")
		return true, {
			status = "Granted +250 bunker XP.",
		}
	elseif command == "grant_xp_large" then
		self._skillTreeService:AwardExperience(player, 1000, "AdminGrant")
		return true, {
			status = "Granted +1000 bunker XP.",
		}
	elseif command == "refresh_access" then
		local progression = self:_refreshIdentity(player)
		return true, {
			status = "Refreshed identity, access, and entitlements.",
			progression = progression,
		}
	elseif command == "return_to_lobby" then
		if self._missionService and self._missionService:AbortActiveMission("Owner command: returning squad to bunker.") then
			return true, {
				status = "Active run aborted. Squad returned to bunker.",
			}
		end
		if self._flowService then
			local success = self._flowService:AbortActiveDeployment("Owner command: deployment canceled.")
			if success then
				return true, {
					status = "Active deployment canceled.",
				}
			end
		end
		return false, "no_active_run"
	end

	return false, "unknown_command"
end

return AdminService
