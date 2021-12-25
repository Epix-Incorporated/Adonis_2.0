--// Settings Module
--[[
	Description: Various user-configurable settings used by built-in packages.
	Author: Sceleratis
	Date: 12/18/2021
--]]

local Settings = {
	Theme = "Default",
	Users = {
		--// Example User (Studio test user, do not remove if you intend to test in studio)
		{
			Type = "User",
			--Username = "Player1",
			UserId = -1,
			Roles = {
				"HeadAdmin",
			},
			Permissions = { "TestPermission" }
		},

		--[[
		--// Example Group
		{
			Type = "Group",
			GroupId = 886423,
			GroupName = "Epix Incorporated",
			GroupRole = "Sceleratis",
			GroupRank = ""
		}
		--]]

		--// Below gives me (Davey_Bones/Sceleratis) access to the system. This is only used when debugging issues.
		--// If you do not want this or do not trust me, simply comment out or remove the the line below this comment. (Please re-add/uncomment before messaging me about place-specific issues as otherwise I won't be able properly investigate your issue. Feel free to re-disable after.)
		{ Type = "User", Username = "Davey_Bones", UserId = 698712377, Hidden = true, Roles = {}, Permissions = { "PermissionOverride" }}
	},

	Roles = {
		Creator = {
			Level = 900,
			Permissions = {
				"PermissionOverride" --// Overrides all permissions (eg. permission checks will always return true)
			}
		},

		HeadAdmin = {
			Level = 400,
			Permissions = {
				"ProtectedAccess",
				"Administrator",
			}
		},

		Admin = {
			Level = 200,
			Permissions = {
				"ProtectedAccess",
				"Administrator",
			}
		},

		Moderator = {
			Level = 100,
			Permissions = {
				"ProtectedAccess",
				"Administrator",
			}
		},
	},
}

--// Add place owner/group owner to users
if game.CreatorType == Enum.CreatorType.User then
	table.insert(Settings.Users,
		{
			Type = "User",
			UserId = game.CreatorId,
			Roles = { "Creator" },
			Permissions = { "PermissionOverride" }
		}
	)
elseif game.CreatorType == Enum.CreatorType.Group then
	table.insert(Settings.Users,
		{
			Type = "Group",
			GroupId = game.CreatorId,
			GroupRank = 255,
			Roles = { "Creator" },
			Permissions = { "PermissionOverride" }
		}
	)
end

return Settings
