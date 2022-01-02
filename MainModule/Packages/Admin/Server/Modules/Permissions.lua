--[[

	Description: Handles permissions & roles.
	Author: Sceleratis
	Date: 12/24/2021

--]]


local Root, Utilities, Service, Package;

--// Output
local Verbose = false
local function DebugWarn(...)
	if Verbose and Root and Root.Warn then
		Root.Warn(...)
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

local RemoteCommands = {
	GetPermissions = function(p: Player)
		local data = Root.Core:GetPlayerData(p)
		if not Utilities:RateLimit("GetPermissions", { Cache = data.RateLimitCache, Timeout = Root.Timeouts.Remote_GetPermissions }) then
			return Root.Permissions:GetPermissions(p)
		end
	end
}

local Users = setmetatable({
	GetUserEntries = function(self, player: Player)
		local userEntries = {}
		for i,user in pairs(Root.Settings.Users) do
			DebugWarn("Player UserCheck", user, player)
			local userCheck = self.UserChecks[user.Type or "User"]
			if userCheck then
				if userCheck(self, player, user) then
					table.insert(userEntries, user)
				end
			else
				Root.Warn("Check for RoleType not found", user.Type)
			end
		end
		return userEntries
	end,

	UpdateUserOverrides = function(self, player: Player, userEntries: {})
		local userEntries = userEntries or self:GetUserEntries(player)
		local data = Root.Core:GetPlayerData(player)
		local highestLevel = 0

		DebugWarn("Updating user overrides", player, userEntries)

		for i, user in ipairs(userEntries) do
			if user.Permissions then
				for i,perm in ipairs(user.Permissions) do
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
	end,
}, {
	__index = function(self, p)
		if typeof(p) == "Instance" and p:IsA("Player") then
			return self:GetUserEntries(p)
		end
	end
})

local Roles = setmetatable({
	--// Functions used to check whether or not player matches a certain criteria, such as being in a specific group or having a certain UserId for Role assignments.
	UserChecks = {
		--// Default means it applies to everyone applies to everyone
		Default = function(self, player: Player, data: {})
			DebugWarn("Default usertype, return true", player, data)
			return true
		end,

		User = function(self, player: Player, data: {})
			DebugWarn("User check", player, data)
			if data.UserId and data.UserId == player.UserId then
				return true
			elseif data.Username and data.Username == player.Name then
				return true
			elseif data.DisplayName and data.DisplayName == player.DisplayName then --// ... Don't use this for anything important.
				return true
			end
			return false
		end,

		Group = function(self, player: Player, data: {})
			DebugWarn("Group check", player, data)
			local groupId = data.GroupId
			local groupName = data.GroupName
			if groupId or groupName then
				local groupData = self:GetPlayerGroups(player)
				if groupData then
					for i,group in ipairs(groupData) do
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
				Root.Warn("Missing GroupId or GroupName for group-assigned role. Skipping...")
			end

			return false
		end,

		GamePass = function(self, player: Player, data: {})
			DebugWarn("GamePass Check", player, data)
			local passId = data.GamePassId or data.GamepassId or data.AssetId or data.Id or data.ID
			if passId then
				return Service.MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end
		end,

		Asset = function(self, player: Player, data: {})
			DebugWarn("Asset check", player, data)
			local passId = data.AssetId or data.Id or data.ID
			if passId and player and typeof(player) == "Instance" and player:IsA("Player") then
				return Service.MarketplaceService:PlayerOwnsAsset(player, passId)
			end
		end,
	},

	GetPlayerGroups = function(self, player: Player)
		local data = Root.Core:GetPlayerData(player)
		local cached = data.Cache:GetData("GroupData")
		if cached then
			DebugWarn("Found cached grroup info", player)
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
	end,

	HasRole = function(self, player: Player, role: string)
		local playerRoles = self:GetRoles(player)
		DebugWarn("Found player roles", player, playerRoles)
		if playerRoles then
			return playerRoles[role]
		else
			return false
		end
	end,

	HasRoles = function(self, player: Player, roles: {})
		local hasRoles = false
		for i,role in ipairs(roles) do
			if self:PlayerHasRole(player, role) then
				hasRoles = true
			else
				return false
			end
		end
		return hasRoles
	end,

	GetRoles = function(self, player: Player)
		local data = Root.Core:GetPlayerData(player)
		local cached = data.Cache:GetData("Roles")

		if cached then
			return cached
		else
			local foundRoles = {}
			local highestLevel = 0
			local userEntries = Root.Users:GetUserEntries(player)

			Root.Users:UpdateUserOverrides(player, userEntries)

			for i,user in ipairs(userEntries) do
				for i,role in ipairs(user.Roles) do
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
	end,

	GetLevel = function(self, player: Player)
		local roles = self:GetRoles(player)
		local data = Root.Core:GetPlayerData(player)
		return data.Level or 0
	end,

	CompareLevels = function(self, player1: Player, player2: Player)
		return self:GetLevel(player1) > self:GetLevel(player2)
	end,
}, {
	__index = function(self, p)
		if typeof(p) == "Instance" and p:IsA("Player") then
			return self:GetRoles(p)
		end
	end
})

local Permissions = setmetatable({
	--// List of known system permissions.
	--// Only used to track permissions. Not actually required for any checks.
	KnownPermissions = {},

	--// Get all permissions for a player
	GetPermissions = function(self, player: Player)
		local data = Root.Core:GetPlayerData(player)
		local cached = data.Cache:GetData("Permissions")
		local foundPerms = cached or {}

		if not cached then
			DebugWarn("No cached permissions found for player", player)

			local roles = Root.Roles:GetRoles(player)

			for role,data in pairs(roles) do
				for i,perm in ipairs(data.Permissions) do
					foundPerms[perm] = true
				end
			end

			data.Cache:SetData("Permissions", foundPerms, {
				Timeout = math.random(Root.Timeouts.GetPlayerPermissions, Root.Timeouts.GetPlayerPermissions + 10)
			})
		end

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
	end,

	--// Check if player has specified permission
	HasPermission = function(self, player: Player, perm: string)
		local perms = self:GetPermissions(player)
		return if perms.PermissionOverride then true elseif perms.DenyPermissions then false else perms[perm]
	end,

	--// Check if player has specified permissions
	HasPermissions = function(self, player: Player, perms: {})
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
			for i,perm in ipairs(perms) do
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
	end,

	--// Declares a permission used by the system.
	--// This has no functional use, other than keeping track of permissions that exist.
	DeclarePermission = function(self, permName: string)
		self.KnownPermissions[permName] = true
	end,
}, {
	__index = function(self, p)
		if typeof(p) == "Instance" and p:IsA("Player") then
			return self:GetPermissions(p)
		end
	end
})



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

		for i,perm in ipairs({
			"ProtectedAccess",
			"Administrator",
			"ModifySettings",
			"DebugCommands"
		}) do
			Permissions:DeclarePermission(perm)
		end
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
	end;
}
