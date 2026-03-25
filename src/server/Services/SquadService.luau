local Players = game:GetService("Players")

local SquadService = {}
SquadService.__index = SquadService

function SquadService.new(context)
	local self = setmetatable({}, SquadService)
	self._squadConfig = context.SquadConfig
	self._contracts = context.Contracts
	self._roleService = context.RoleService
	self._remoteNames = context.RemoteNames
	self._remotes = context.Remotes
	self._squads = {}
	self._playerToSquadId = {}
	self._pendingInvites = {}
	self.SquadChanged = context.Signal.new()
	self.SquadRemoved = context.Signal.new()
	return self
end

function SquadService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:EnsureSoloSquad(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:RemovePlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:EnsureSoloSquad(player)
	end

	task.spawn(function()
		while true do
			task.wait(10)
			self:_cleanupExpiredInvites()
		end
	end)
end

function SquadService:_createSquadId(leaderUserId)
	return ("squad_%d_%d"):format(leaderUserId, math.floor(os.clock() * 1000))
end

function SquadService:_getSquad(player)
	local squadId = self._playerToSquadId[player.UserId]
	return squadId and self._squads[squadId] or nil
end

function SquadService:_cleanupExpiredInvites()
	local now = os.time()
	for userId, invite in pairs(self._pendingInvites) do
		if type(invite) ~= "table" or (invite.expiresAt or 0) <= now then
			self._pendingInvites[userId] = nil
		end
	end
end

function SquadService:_getPendingInvite(player)
	self:_cleanupExpiredInvites()
	return player and self._pendingInvites[player.UserId] or nil
end

function SquadService:_toSnapshot(squad)
	local members = {}
	for _, member in pairs(squad.members) do
		if member and member.Parent then
			local displayName = self._roleService and self._roleService:GetDecoratedDisplayName(member) or member.DisplayName
			table.insert(
				members,
				self._contracts.makeSquadMember(
					member.UserId,
					displayName,
					member.UserId == squad.leaderUserId,
					squad.ready[member.UserId] == true
				)
			)
		end
	end

	table.sort(members, function(a, b)
		return a.userId < b.userId
	end)

	return self._contracts.makeSquadSnapshot(squad.id, squad.leaderUserId, members, self._squadConfig.MaximumPlayers)
end

function SquadService:_setPlayerSquad(player, squadId)
	self._playerToSquadId[player.UserId] = squadId
	player:SetAttribute("SquadId", squadId)
end

function SquadService:_emitChange(squad)
	local snapshot = self:_toSnapshot(squad)
	self.SquadChanged:Fire(snapshot)
	if self._remotes then
		self._remotes:FireEventForMany(self:GetMembersInSquad(squad.id), self._remoteNames.Events.SquadUpdated, snapshot)
	end
end

function SquadService:GetPlayerSquad(player)
	return self:_getSquad(player)
end

function SquadService:GetActiveSquadCount()
	local count = 0
	for _ in pairs(self._squads) do
		count += 1
	end

	return count
end

function SquadService:GetMembersInSquad(squadId)
	local squad = self._squads[squadId]
	if not squad then
		return {}
	end

	local members = {}
	for _, member in pairs(squad.members) do
		if member and member.Parent then
			table.insert(members, member)
		end
	end

	return members
end

function SquadService:GetSquadSnapshot(player)
	local squad = self:_getSquad(player)
	if not squad then
		local displayName = self._roleService and self._roleService:GetDecoratedDisplayName(player) or player.DisplayName
		return self._contracts.makeSquadSnapshot(
			("solo_%d"):format(player.UserId),
			player.UserId,
			{ self._contracts.makeSquadMember(player.UserId, displayName, true, false) },
			self._squadConfig.MaximumPlayers
		)
	end

	return self:_toSnapshot(squad)
end

function SquadService:GetPartyMembers(player)
	local squad = self:_getSquad(player)
	if not squad then
		return { player }
	end

	return self:GetMembersInSquad(squad.id)
end

function SquadService:GetPartySize(player)
	return #self:GetPartyMembers(player)
end

function SquadService:IsLocked(player)
	local squad = self:_getSquad(player)
	return squad and squad.locked or false
end

function SquadService:CreateSquad(leader)
	local squad = {
		id = self:_createSquadId(leader.UserId),
		leaderUserId = leader.UserId,
		leaderName = self._roleService and self._roleService:GetDecoratedDisplayName(leader) or leader.DisplayName,
		members = {},
		ready = {},
		locked = false,
		state = "Lobby",
	}

	self._squads[squad.id] = squad
	self:_addMemberToSquad(leader, squad)
	return true, squad.id, self:_toSnapshot(squad)
end

function SquadService:_addMemberToSquad(player, squad)
	self:_setPlayerSquad(player, squad.id)
	squad.members[player.UserId] = player
	squad.ready[player.UserId] = false
	player:SetAttribute("SquadLeaderUserId", squad.leaderUserId)
	player:SetAttribute("SquadLocked", squad.locked)
	self:_emitChange(squad)
end

function SquadService:EnsureSoloSquad(player)
	if self._playerToSquadId[player.UserId] then
		return self:_getSquad(player)
	end

	local _, squadId = self:CreateSquad(player)
	return self._squads[squadId]
end

function SquadService:CreateOrJoinSquad(player, squadId)
	if squadId and self._squads[squadId] then
		return self:JoinSquad(player, squadId)
	end

	return self:CreateSquad(player)
end

function SquadService:JoinSquad(player, squadId)
	local squad = self._squads[squadId]
	if not squad then
		return false, "missing_squad"
	end

	if squad.locked then
		return false, "locked"
	end

	if self._playerToSquadId[player.UserId] then
		self:LeaveSquad(player, true)
	end

	if #self:GetMembersInSquad(squadId) >= self._squadConfig.MaximumPlayers then
		return false, "full"
	end

	self:_addMemberToSquad(player, squad)
	return true, squad.id, self:_toSnapshot(squad)
end

function SquadService:LeaveSquad(player, skipSoloRequeue)
	local squad = self:_getSquad(player)
	if not squad then
		return false, "missing_squad"
	end

	local shouldRequeueSolo = player.Parent == Players and not skipSoloRequeue

	squad.members[player.UserId] = nil
	squad.ready[player.UserId] = nil
	self._playerToSquadId[player.UserId] = nil
	player:SetAttribute("SquadId", nil)
	player:SetAttribute("SquadLeaderUserId", nil)
	player:SetAttribute("SquadLocked", nil)
	self._pendingInvites[player.UserId] = nil

	local remaining = self:GetMembersInSquad(squad.id)
	if #remaining == 0 then
		self._squads[squad.id] = nil
		self.SquadRemoved:Fire(squad.id)
		if shouldRequeueSolo then
			local _, soloSquadId, soloSnapshot = self:CreateSquad(player)
			return true, soloSquadId, soloSnapshot
		end
		return true, "disbanded"
	end

	if squad.leaderUserId == player.UserId then
		local newLeader = remaining[1]
		squad.leaderUserId = newLeader.UserId
		squad.leaderName = self._roleService and self._roleService:GetDecoratedDisplayName(newLeader) or newLeader.DisplayName
	end

	self:_emitChange(squad)
	if shouldRequeueSolo then
		local _, soloSquadId, soloSnapshot = self:CreateSquad(player)
		return true, soloSquadId, soloSnapshot
	end
	return true, squad.id, self:_toSnapshot(squad)
end

function SquadService:RemovePlayer(player)
	self._pendingInvites[player.UserId] = nil
	self:LeaveSquad(player, true)
end

function SquadService:_makeInvitePayload(invite)
	return {
		kind = "Invite",
		fromSquadId = invite.fromSquadId,
		fromLeaderUserId = invite.fromLeaderUserId,
		fromLeaderName = invite.fromLeaderName,
		expiresAt = invite.expiresAt,
		message = ("%s invited you to join their fireteam."):format(invite.fromLeaderName),
	}
end

function SquadService:GetInviteablePlayers(requestingPlayer)
	local currentSquad = requestingPlayer and self:_getSquad(requestingPlayer) or nil
	local entries = {}

	for _, target in ipairs(Players:GetPlayers()) do
		if target ~= requestingPlayer then
			local targetSquad = self:_getSquad(target)
			local isSameSquad = currentSquad and targetSquad and currentSquad.id == targetSquad.id
			table.insert(entries, {
				userId = target.UserId,
				displayName = self._roleService and self._roleService:GetDecoratedDisplayName(target) or target.DisplayName,
				squadId = targetSquad and targetSquad.id or nil,
				canInvite = not isSameSquad,
				isSameSquad = isSameSquad == true,
			})
		end
	end

	table.sort(entries, function(a, b)
		if a.canInvite ~= b.canInvite then
			return a.canInvite
		end
		return a.displayName < b.displayName
	end)

	return entries
end

function SquadService:SendInvite(player, targetUserId)
	local squad = self:_getSquad(player)
	if not squad then
		return false, "missing_squad"
	end

	if squad.leaderUserId ~= player.UserId then
		return false, "not_leader"
	end

	if squad.locked then
		return false, "locked"
	end

	if #self:GetMembersInSquad(squad.id) >= self._squadConfig.MaximumPlayers then
		return false, "full"
	end

	local target = Players:GetPlayerByUserId(tonumber(targetUserId) or 0)
	if not target or target == player then
		return false, "missing_player"
	end

	local targetSquad = self:_getSquad(target)
	if targetSquad and targetSquad.id == squad.id then
		return false, "same_squad"
	end

	local invite = {
		fromSquadId = squad.id,
		fromLeaderUserId = player.UserId,
		fromLeaderName = self._roleService and self._roleService:GetDecoratedDisplayName(player) or player.DisplayName,
		expiresAt = os.time() + 45,
	}
	self._pendingInvites[target.UserId] = invite

	if self._remotes then
		self._remotes:FireEventFor(target, self._remoteNames.Events.Notification, self:_makeInvitePayload(invite))
		self._remotes:FireEventFor(player, self._remoteNames.Events.Notification, {
			kind = "Status",
			message = ("Invite sent to %s."):format(target.DisplayName),
		})
	end

	return true, invite
end

function SquadService:RespondToInvite(player, fromSquadId, acceptInvite)
	local invite = self:_getPendingInvite(player)
	if not invite or invite.fromSquadId ~= fromSquadId then
		return false, "missing_invite"
	end

	self._pendingInvites[player.UserId] = nil

	if not acceptInvite then
		local leader = Players:GetPlayerByUserId(invite.fromLeaderUserId)
		if self._remotes and leader then
			self._remotes:FireEventFor(leader, self._remoteNames.Events.Notification, {
				kind = "Status",
				message = ("%s declined the squad invite."):format(player.DisplayName),
			})
		end
		return true, "declined"
	end

	local success, resultOrCode, snapshot = self:JoinSquad(player, invite.fromSquadId)
	local leader = Players:GetPlayerByUserId(invite.fromLeaderUserId)
	if self._remotes and leader then
		if success then
			self._remotes:FireEventFor(leader, self._remoteNames.Events.Notification, {
				kind = "Status",
				message = ("%s joined your fireteam."):format(player.DisplayName),
			})
		else
			self._remotes:FireEventFor(leader, self._remoteNames.Events.Notification, {
				kind = "Status",
				message = ("%s could not join the fireteam."):format(player.DisplayName),
			})
		end
	end

	return success, resultOrCode, snapshot
end

function SquadService:SetPrivacyForLeader(player, isPrivate)
	local squad = self:_getSquad(player)
	if not squad then
		return false, "missing_squad"
	end

	if squad.leaderUserId ~= player.UserId then
		return false, "not_leader"
	end

	return self:SetLocked(squad.id, isPrivate)
end

function SquadService:SetReady(player, isReady)
	local squad = self:_getSquad(player)
	if not squad then
		return false, "missing_squad"
	end

	squad.ready[player.UserId] = isReady and true or false
	self:_emitChange(squad)
	return true, squad.ready[player.UserId]
end

function SquadService:SetLocked(squadId, locked)
	local squad = self._squads[squadId]
	if not squad then
		return false, "missing_squad"
	end

	squad.locked = locked and true or false
	for _, member in pairs(squad.members) do
		if member and member.Parent then
			member:SetAttribute("SquadLocked", squad.locked)
		end
	end

	self:_emitChange(squad)
	return true, squad.locked
end

function SquadService:GetSquadProfile(player)
	local squad = self:_getSquad(player)
	if not squad then
		return nil
	end

	return {
		id = squad.id,
		leaderUserId = squad.leaderUserId,
		leaderName = squad.leaderName,
		locked = squad.locked,
		state = squad.state,
		members = self:GetMembersInSquad(squad.id),
	}
end

function SquadService:GetPublicSquadDirectory(requestingPlayer)
	local currentSquad = requestingPlayer and self:_getSquad(requestingPlayer) or nil
	local entries = {}

	for squadId, squad in pairs(self._squads) do
		local members = self:GetMembersInSquad(squadId)
		if #members > 0 then
			local memberNames = {}
			for _, member in ipairs(members) do
				table.insert(memberNames, member.DisplayName)
			end

			table.sort(memberNames)

			local isCurrentSquad = currentSquad ~= nil and currentSquad.id == squadId
			local isJoinable = not squad.locked and #members < self._squadConfig.MaximumPlayers and not isCurrentSquad

			table.insert(entries, {
				squadId = squadId,
				leaderUserId = squad.leaderUserId,
				leaderName = squad.leaderName,
				memberCount = #members,
				maxPlayers = self._squadConfig.MaximumPlayers,
				locked = squad.locked,
				state = squad.state,
				memberNames = memberNames,
				isCurrentSquad = isCurrentSquad,
				canJoin = isJoinable,
			})
		end
	end

	table.sort(entries, function(a, b)
		if a.canJoin ~= b.canJoin then
			return a.canJoin
		end

		if a.isCurrentSquad ~= b.isCurrentSquad then
			return a.isCurrentSquad
		end

		if a.memberCount ~= b.memberCount then
			return a.memberCount > b.memberCount
		end

		return a.squadId < b.squadId
	end)

	return entries
end

return SquadService
