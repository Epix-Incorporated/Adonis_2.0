--[[

	Description:
	Author:
	Date:

--]]


local Root, Utilities, Service, Package;


local Roles = setmetatable({
	UserChecks = {
		User = function(self, player: Player, data: {})
			if data.UserId and data.UserId == player.UserId then
				return true
			elseif data.Username and data.Username == player.Username then
				return true
			end
		end,

		Group = function(self, player: Player, data: {})
			local groupId = data.GroupId
			local groupRank = data.GroupRank

			if groupId then
				local groupData = {} --// get group data
				if groupRank then
				end
			else
				Root.Warn("Missing GroupId for group role. Skipping...")
			end
		end,

		GamePass = function(self, player: Player, data: {})
		end,

		Item = function(self, player: Player, data: {})
		end,
	},

	GetPlayerGroups = function(self, player: Player)
		local data = Root.Core:GetPlayerData(player)
		local cached = data.Cache:GetData("GroupData")

		if cached then
			return cached
		else
			local info = Service.GroupService:GetGroupsAsync(player.UserId)
			if info then
				data.Cache:SetData("GroupData", { Timeout = 60 })
				return info
			end
		end
	end,

	PlayerHasRole = function(self, player: Player, role: Table)
	end,

	GetRoles = function(self, player: Player)
		local foundRoles = {}

		for i,user in pairs(Root.Settings.Users) do
			local userCheck = UserChecks[user.Type or "User"]
			if userCheck then
				if userCheck(player, user) then
					for i,role in ipairs(user.Roles) do
						foundRoles[role] = Settings.Roles[role]
					end
				end
			else
				Root.Warn("Check for RoleType not found", user.Type)
			end
		end

		return foundRoles
	end,

	HasRoles = function(self, player, Player, roles: {})
	end
}, {
	__index = function(self, p)
		if typeof(p) == "Instance" and p:IsA("Player") then
			return self:GetRoles(p)
		end
	end
})

local Permissions = setmetatable({
	PermissionList = {
		"FullAccess",
		"Admin",
		"ModifySettings",
		"DebugCommands",
	},

	GetPermissions = function(self, player: Player)
	end,

	HasPermissions = function(self, player: Player, perms: {})
	end,
}, {
	__index = function(self, p)
		if typeof(p) == "Instance" and p:IsA("Player") then
			local perms = self:GetPermissions(p)
			if perms then
				local ret = {}
				for i,perm in pairs(perms) do
					ret[perm] = true
				end
				return ret
			end
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
		Root.Permission = Permissions
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
		for i,v in pairs(Root.Settings.NewPermissions) do
			table.insert(Permissions.PermissionList, v)
		end
	end;
}
