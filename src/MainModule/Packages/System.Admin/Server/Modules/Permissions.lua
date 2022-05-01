--[[

	Description: Handles permissions & roles.
	Author: Sceleratis
	Date: 12/24/2021

--]]


local Root, Utilities, Service, Package;

local RemoteCommands = {}


--// Output
local Verbose = false
local oWarn = warn;

local function warn(...)
	if Root and Root.Warn then
		Root.Warn(...)
	else
		oWarn(":: ".. script.Name .." ::", ...)
	end
end

local function DebugWarn(...)
	if Verbose then
		warn("Debug ::", ...)
	end
end

--// Misc
local function numBasedRankCheck(numBased, rank)
	if numBased and numBased < 0 and rank >= math.abs(numBased) then
		return true
	elseif numBased and numBased > 0 and rank == numBased then
		return true
	end
end


--// Remote commands
--[=[
	Responsible for returning user permissions to the requesting client.
	@function GetPermissions
	@within Server.Remote.Commands
	@tag Package: System.Admin
]=]
function RemoteCommands.GetPermissions(p: Player)
	local data = Root.Core:GetPlayerData(p)
	if not Utilities:RateLimit("GetPermissions", { Cache = data.RateLimitCache, Timeout = Root.Timeouts.Remote_GetPermissions }) then
		return Root.Permissions:GetPermissions(p)
	end
end

--// Users
--[=[
	Responsible for checking if user permissions/criteria checking methods.
	@class Server.Users
	@tag System.Admin
	@server
]=]
--[=[
	Responsible for specific user checking methods used during permissions checks.
	@class Server.Users.UserChecks
	@tag System.Admin
	@server
]=]
local Users = setmetatable({ UserChecks = {} }, {
	__index = function(self, p)
		if typeof(p) == "Instance" and p:IsA("Player") then
			return self:GetUserEntries(p)
		end
	end
})

--// UserChecks methods
--[=[ 
	Applies to all users. 
	@method Default
	@within Server.Users.UserChecks
	@param player Player
	@param data {[string]: any}
	@return boolean
]=]
function Users.UserChecks.Default(self, player: Player, data: {[string]: any}): boolean
	DebugWarn("Default usertype, return true", player, data)
	return true
end

--[=[
	Checks if player's UserId, Username, or DisplayName exactly matches data.UserId, data.Username, or data.DisplayName.
	@method User
	@within Server.Users.UserChecks
	@param player Player
	@param data {[string]: any} -- Can contain: UserId: number; Username: string; DisplayName: string
	@return boolean
]=]
function Users.UserChecks.User(self, player: Player, data: {[string]: any}): boolean
	DebugWarn("User check", player, data)
	if data.UserId and data.UserId == player.UserId then
		return true
	elseif data.Username and data.Username == player.Name then
		return true
	elseif data.DisplayName and data.DisplayName == player.DisplayName then --// ... Don't use this for anything important.
		return true
	end
	return false
end

--[=[
	Checks if a user is in a group using data.GroupId, (optional)data.GroupName, data.GroupRank, data.GroupRole.
	data.GroupRank supports the following modifiers when supplied as a string: Rank- Rank< Rank+ Rank> (Ex. 143> or 143+ for 143 and up; 143< or 143- for 143 and under.
	Can accept a comma separate list of ranks.
	@method Group
	@within Server.Users.UserChecks
	@param player Player
	@param data {[string]: any} -- Can contain: data.GroupId, data.GroupName, data.GroupRank, data.GroupRole
	@return boolean
]=]
function Users.UserChecks.Group(self, player: Player, data: {[string]: any}): boolean
	DebugWarn("Group check", player, data)
	local groupId = data.GroupId
	local groupName = data.GroupName
	if groupId or groupName then
		local groupData = self:GetPlayerGroups(player)
		if groupData then
			for i, group in ipairs(groupData) do
				if (groupId and group.Id == groupId) or (groupName and group.Name == groupName) then
					if not data.GroupRank and not data.GroupRole then
						return true
					end

					if data.GroupRole and group.Role == data.GroupRole then
						return true
					end

					if data.GroupRank then
						local groupRank = group.Rank
						local dataRank = data.GroupRank
						if type(dataRank) == "string" or type(dataRank) == "number" then
							local numBased = tonumber(dataRank)
							if numBased and numBasedRankCheck(numBased, groupRank) then
								return true
							else
								for rank in string.gmatch(dataRank, "([^%s,]+)") do
									local sign = string.match(rank, "[.+.-.>.<]")
									local num = tonumber((sign and string.match(rank, "(.+)[.+.-.<.>]")) or rank)
									if num then
										if sign then
											if (sign == "-" or sign == "<") and groupRank > 0 and groupRank <= num then
												return true
											elseif (sign == "+" or sign == ">") and groupRank >= num then
												return true
											end
										elseif numBasedRankCheck(num, rank) then
											return true
										end
									end
								end
							end
						end
					end
				end
			end
		end
	else
		warn("Missing GroupId or GroupName for group-assigned role. Skipping...")
	end

	return false
end

--[=[
	Checks if player owns the gamepass specified by the supplied ID (refer to data param description.)
	@method GamePass
	@within Server.Users.UserChecks
	@param player Player
	@param data {[string]: any} -- Can contain ONE of the following: data.GamePassId, data.GamepassId, data.AssetId, data.Id, data.ID
	@return boolean
]=]
function Users.UserChecks.GamePass(self, player: Player, data: {[string]: any}): boolean
	DebugWarn("GamePass Check", player, data)
	local passId = data.GamePassId or data.GamepassId or data.AssetId or data.Id or data.ID
	if passId then
		return Service.MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end
end

--[=[
	Checks is player owns the asset specified (refer to data param description.)
	@method Asset
	@within Server.Users.UserChecks
	@param player Player
	@param data {[string]: any} -- Can ONE of the following: data.AssetId, data.Id, data.ID
	@return boolean
]=]
function Users.UserChecks.Asset(self, player: Player, data: {[string]: any}): boolean
	DebugWarn("Asset check", player, data)
	local passId = data.AssetId or data.Id or data.ID
	if passId and player and typeof(player) == "Instance" and player:IsA("Player") then
		return Service.MarketplaceService:PlayerOwnsAsset(player, passId)
	end
end


--// User methods
--[=[
	Get all user entries in Root.Settings.Users that match the provided player.
	@method GetUserEntries
	@within Server.Users
	@param player Player
	@return {}
]=]
function Users.GetUserEntries(self, player: Player): {}
	DebugWarn("Getting user entries for", player)
	DebugWarn("Root.Settings.Users:", Root.Settings.Users)

	local userEntries = {}
	for i,user in pairs(Root.Settings.Users) do
		DebugWarn("Player UserCheck", user, player)

		local userCheck = self.UserChecks[user.Type or "User"]
		if userCheck then
			if userCheck(self, player, user) then
				table.insert(userEntries, user)
			end
		else
			warn("Check for RoleType not found", user.Type)
		end
	end
	return userEntries
end

--[=[
	Updates a player's user overrides and level, giving the player any permissions associated with the provided UserEntries.
	@method UpdateUserOverrides
	@within Server.Users
	@param player Player
	@param userEntries {}
]=]
function Users.UpdateUserOverrides(self, player: Player, userEntries: {})
	local userEntries = userEntries or self:GetUserEntries(player)
	local data = Root.Core:GetPlayerData(player)
	local highestLevel = 0

	DebugWarn("Updating user overrides", player, userEntries)

	for i, user in ipairs(userEntries) do
		if user.Permissions then
			for i, perm in ipairs(user.Permissions) do
				if data.Overrides.Permissions[perm] == nil then
					data.Overrides.Permissions[perm] = true
				end
			end
		end

		if user.Level and user.Level > highestLevel then
			highestLevel = user.Level
		end
	end

	data.Level = data.Overrides.Level or highestLevel
end

--// Roles methods
--[=[
	Responsible for role handling methods.
	@class Server.Roles
	@server
	@tag System.Admin
]=]
local Roles = setmetatable({}, {
	__index = function(self, p)
		if typeof(p) == "Instance" and p:IsA("Player") then
			return self:GetRoles(p)
		end
	end
})

--[=[
	Returns data retrieved via GroupService:GetGroupsAsync(player.UserId);
	Caches using a random offset between Root.Timeouts.GetPlayerGroups and Root.Timeouts.GetPlayerGroups + 10.
	https://developer.roblox.com/en-us/api-reference/function/GroupService/GetGroupsAsync
	@method GetPlayerGroups
	@within Server.Roles
	@param player Player
	@return {GroupInfo}
]=]
function Roles.GetPlayerGroups(self, player: Player): {}
	local data = Root.Core:GetPlayerData(player)
	local cached = data.Cache:GetData("GroupData")
	if cached then
		DebugWarn("Found cached group info", player)
		return cached
	else
		local info = Service.GroupService:GetGroupsAsync(player.UserId)
		if info then
			DebugWarn("Found player group info", info, player)
			data.Cache:SetData("GroupData", info, { Timeout = math.random(Root.Timeouts.GetPlayerGroups, Root.Timeouts.GetPlayerGroups + 10) }) --// Attempt to slightly desync group grabbing intervals as much as possible
			return info
		end

		DebugWarn("Missing player group info!", player)
	end
end

--[=[
	Checks if player has specified role.
	@method HasRole
	@within Server.Roles
	@param player Player
	@param role string
	@return boolean
]=]
function Roles.HasRole(self, player: Player, role: string): any
	local playerRoles = self:GetRoles(player)
	DebugWarn("Found player roles", player, playerRoles)
	if playerRoles then
		return playerRoles[role]
	else
		return false
	end
end

--[=[
	Checks if the player has any of the specified roles.
	@method HasRoles
	@within Server.Roles
	@param player Player
	@param roles {string}
	@return boolean
]=]
function Roles.HasRoles(self, player: Player, roles: {string}): boolean
	local hasRoles = false
	for i, role in ipairs(roles) do
		if self:PlayerHasRole(player, role) then
			hasRoles = true
		else
			return false
		end
	end
	return hasRoles
end

--[=[
	Gets all roles for the provided player.
	@method GetRoles
	@within Server.Roles
	@param player Player
	@return {[string]: {[string]: any}}
]=]
function Roles.GetRoles(self, player: Player): {[string]: {[string]: any}}
	local data = Root.Core:GetPlayerData(player)
	local cached = data.Cache:GetData("Roles")

	if cached then
		return cached
	else
		local foundRoles = {}
		local highestLevel = 0
		local userEntries = Root.Users:GetUserEntries(player)

		Root.Users:UpdateUserOverrides(player, userEntries)

		for i, user in ipairs(userEntries) do
			for i, role in ipairs(user.Roles) do
				foundRoles[role] = Root.Settings.Roles[role]
				if role.Level and role.Level > highestLevel then
					highestLevel = role.Level
				end
			end
		end

		data.Cache:SetData("Roles", foundRoles, {
			Timeout = math.random(Root.Timeouts.GetPlayerRoles, Root.Timeouts.GetPlayerRoles + 10) --// Intentional desync
		})

		for role, val in pairs(data.Overrides.Roles) do
			if val then
				local newRole = Root.Settings.Roles[role]
				foundRoles[role] = newRole
				if newRole.Level and newRole.Level > highestLevel then
					highestLevel = newRole.Level
				end
			else
				foundRoles[role] = nil
			end
		end

		data.Level = data.Overrides.Level or highestLevel

		return foundRoles
	end
end

--[=[
	Returns the provided player's highest role level.
	@method GetLevel
	@within Server.Roles
	@param player Player
	@return number
]=]
function Roles.GetLevel(self, player: Player): number
	local roles = self:GetRoles(player)
	local data = Root.Core:GetPlayerData(player)
	return data.Level or 0
end

--[=[
	Performs level comparison between provided users. Returns true if user1 is a higher level than user2, otherwise false.
	@method CompareLevels
	@within Server.Roles
	@param user1 Player
	@param user2 Player
	@return boolean
]=]
function Roles.CompareLevels(self, user1: Player, user2: Player): boolean
	return self:GetLevel(user1) > self:GetLevel(user2)
end


--// Permissions
--[=[
	Responsible for user permission handling methods.
	@class Server.Permissions
	@tag System.Admin
	@server
]=]
local Permissions = setmetatable({
	--// List of known system permissions.
	--// Only used to track permissions. Not actually required for any checks.
	KnownPermissions = {},
}, {
	__index = function(self, p)
		if typeof(p) == "Instance" and p:IsA("Player") then
			return self:GetPermissions(p)
		end
	end
})

--[=[
	Returns permissions for the provided user. 
	@method GetPermissions
	@within Server.Permissions
	@param player Player
	@return {[string]: boolean}
]=]
function Permissions.GetPermissions(self, player: Player): {[string]: boolean}
	local data = Root.Core:GetPlayerData(player)
	local cached = data.Cache:GetData("Permissions")
	local foundPerms = cached or {}

	if not cached then
		DebugWarn("No cached permissions found for player", player)

		local roles = Root.Roles:GetRoles(player)
		local userEntries = Root.Users:GetUserEntries(player)

		DebugWarn("GOT ROLES FOR PLAYER:", roles)
		DebugWarn("GOT USER ENTRIES FOR PLAYER:", userEntries)

		for i, data in ipairs(userEntries) do
			if data.Permissions then
				for i, perm in ipairs(data.Permissions) do
					foundPerms[perm] = true
				end
			end
		end

		for role, data in pairs(roles) do
			for i, perm in ipairs(data.Permissions) do
				DebugWarn("FOUND ROLE PERM:", perm)
				foundPerms[perm] = true
			end
		end

		data.Cache:SetData("Permissions", foundPerms, {
			Timeout = math.random(Root.Timeouts.GetPlayerPermissions, Root.Timeouts.GetPlayerPermissions + 10)
		})
	end

	DebugWarn("PLAYER PERMISSION OVERRIDES:", data.Overrides.Permissions)
	for perm,val in pairs(data.Overrides.Permissions) do
		DebugWarn("Setting permission override", perm, val, player)
		if val then
			foundPerms[perm] = true
		else
			foundPerms[perm] = nil
		end
	end

	DebugWarn("Returning player permissions", foundPerms, player)

	return foundPerms
end

--[=[
	Check if user has specified permission.
	@method HasPermissions
	@within Server.Permissions
	@param player Player
	@param perm string
	@param ignoreOverride boolean?
	@return boolean
]=]
function Permissions.HasPermission(self, player: Player, perm: string, ignoreOverride: boolean?): boolean
	local perms = self:GetPermissions(player)
	return if perms.PermissionOverride and not ignoreOverride then true elseif perms.DenyPermissions then false else perms[perm]
end

--[=[
	Check if user has specified permissions.
	@method HasPermissions
	@within Server.Permissions
	@param player Player
	@param perms {string}
	@return boolean
]=]
function Permissions.HasPermissions(self, player: Player, perms: {string}): boolean
	local playerPerms = self:GetPermissions(player)
	if playerPerms.PermissionOverride then
		DebugWarn("Player has permission override", player)
		return true
	elseif playerPerms.DenyPermissions then
		DebugWarn("Player is denied permissions", player)
		return false
	else
		local hasPerms = false
		DebugWarn("Checking permissions", perms, player)
		for i, perm in ipairs(perms) do
			if playerPerms[perm] then
				DebugWarn("Player has permission", perm, player)
				hasPerms = true
			else
				DebugWarn("Player does not have permission, return false", perm, player)
				return false
			end
		end
		DebugWarn("Returning player permissions", hasPerms, perms)
		return hasPerms
	end
end

--[=[ 
	Declares a permission used by the system.
	Only used to track permissions that exist.
	Not required to create new permissions (just use them.)
	@method DeclarePermission
	@within Server.Permissions
	@param permName string
	@param remove boolean -- Indicates we should remove this permission from the known permissions table.
]=]
function Permissions.DeclarePermission(self, permName: string, remove: boolean)
	self.KnownPermissions[permName] = if remove then nil else true
end


--// Return initializer.
return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		--// Do init
		Root.Users = Users
		Root.Roles = Roles
		Root.Permissions = Permissions

		Root.Timeouts.GetPlayerGroups = 20
		Root.Timeouts.GetPlayerRoles = 40
		Root.Timeouts.GetPlayerPermissions = 40
		Root.Timeouts.Remote_GetPermissions = 2.5

		Utilities.MergeTables(Root.Remote.Commands, RemoteCommands)

		Root.Core:DeclareDefaultPlayerData("RateLimitCache", function()
			return {}
		end)

		Root.Core:DeclareDefaultPlayerData("Overrides", function()
			return {
				Permissions = {},
				Roles = {}
			}
		end)

		for i, perm in ipairs({
			"ProtectedAccess",
			"Administrator",
			"ModifySettings",
			"DebugCommands"
		}) do
			Root.Permissions:DeclarePermission(perm)
		end
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
	end;
}
