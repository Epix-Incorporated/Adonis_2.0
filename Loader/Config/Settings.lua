--// Settings Module
--[[
	Description: Various user-configurable settings used by built-in packages.
	Author: Sceleratis
	Date: 12/18/2021
--]]

return {
	Theme = "Default",
	NewPermissions = {},
	Roles = {
		Creator = {
			Level = 900,
			Permissions = {
				"FullAccess",
				"ProtectedAccess",
				"Administrator"
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

	Users = {
		{
			Type = "User",
			Username = "Player1",
			UserId = -1,
			Roles = {
				"Creator",
			}
		}
	}
}
