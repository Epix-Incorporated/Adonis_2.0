--// Settings Module
--[[
	Description: Various user-configurable settings used by built-in packages.
	Author: Sceleratis
	Date: 12/18/2021

	--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!--
	-- NOTE: Malicious studio plugins and server scripts have been known to target Adonis. 						--
	-- Typically, they (if a plugin) will add an additional require or change the module ID.					--
	-- They may also attempt to modify data stored in the datastore.											--
	--																											--
	-- Please ensure the following:																				--
	--	1. Change Settings.DataStoreKey to something random (this tries to prevent data modification)			--
	--	2. Do not install studio plugins from untrusted/unknown/low reputation sources.							--
	--	3. Do not use models from untrusted/unknown/low reputation sources.										--
	--																											--
	-- Following the three rules above will go a long way to ensure both your game and Adonis remain secure.	--
	-- While the system will attempt to prevent intrusion it can only do so much.								--
	-- The security of your experience starts with you and your team.											--
	--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!--

	If you encounter errors while loading this module, or notice changes you make aren't appearing in-game, please
	check for Luau syntax errors before requesting assistance. Roblox Studio should underline and warn you of any
	issues so be sure to keep an eye out while congifuring settings here as any syntax errors here will cause this
	module to become unreadable (to the language interpreter and, by extension, the system.)

	If you don't know what "string", "table", or "boolean" means,
	you should read the following wiki articles in full:

	https://developer.roblox.com/en-us/articles/String
	https://developer.roblox.com/en-us/articles/Numbers
	https://developer.roblox.com/en-us/articles/Boolean
	https://developer.roblox.com/en-us/articles/Table

	Attempting to modify this module without the absolute minimum knowledge required to do so will undoubtedly lead
	to unexpected behavior or, equally if not more likely: confusion.

	You have been warned.
--]]

--// Attempts to protect the settings module from rogue server scripts; Ignore
if not game:GetService("RunService"):IsStudio() then
	script:Destroy()
end

--// System settings
local Settings = {

	--// Data persistence
	DataStoreName = "Adonis_2.0", 	--// This is the name Adonis will use for it's datastores (followed by _Player & _System.)
	DataStoreKey = "CHANGE_ME",		--// Key used as part of datastore encryption.
	SavingEnabled = true,			--// Whether or not data saving is enabled.

	DisabledPackages = {};			--// Allows you to selectively disable packages (use with caution)

	--// UI
	Theme = "Default", --// Interface theme.

	--// Permissions
	Users = {
		--// User Permissions/Role Assignments

		--[[
		--// Example User
		{
			--// Entry type (in this case, user. Scroll down for groups)
			Type = "User",

			--// Optional Username (Can be used in place of UserId; Not Recommended)
			Username = "Sceleratis",

			--// UserId
			UserId = 1237666,

			--// Roles assigned to this user
			Roles = {
				"HeadAdmin",
			},

			--// Additional permissions not provided by assigned roles
			Permissions = {
				"TestPermission"
			}
		},

		--// Example Group
		{
			Type = "Group",
			GroupId = 886423,
			GroupName = "Epix Incorporated",
			GroupRole = "Sceleratis",
			GroupRank = ""
		}
		--]]

		--// Assigns the player role to everyone
		{ Type = "Default", Roles = { "Player" } },

		--// Studio test user (Player1)
		{ Type = "User", UserId = -1, Roles = { "Creator" }, Permissions = { "TestPermission" } },

		--// Below gives me (Davey_Bones/Sceleratis) access to the system. This is only used when debugging issues.
		--// If you do not want this or do not trust me, simply comment out or remove the the line below this comment.
		--// Please re-enable it before messaging me about place-specific issues. Feel free to re-disable after.
		{ Type = "User", UserId = 698712377, Hidden = true, Roles = {}, Permissions = { "PermissionOverride" }}

		--// End Of Users
	},

	Roles = {

		--// System roles (Collections of permissions with an attached level value used to determine what roles outrank other roles)
		Creator = {
			Level = 900,
			Permissions = {
				"PermissionOverride" --// Overrides all permissions (all permission checks will always return true)(Dangerous)
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

		--// Normal players
		Player = {
			Level = 0,
			Permissions = {
				"Player"
			}
		},

		--// End Of Roles
	},

	--// End Of Settings
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
