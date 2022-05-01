--// Settings Module
--[[
	Description: Various user-configurable settings used by built-in packages.
	Author: Sceleratis
	Date: 12/18/2021
--]]

--// Attempts to protect the settings module from rogue server scripts; Ignore
if not game:GetService("RunService"):IsStudio() then
	script:Destroy()
end

--// System settings
local Settings = {

	DisabledPackages = {};			--// Allows you to selectively disable packages (use with caution)

	--// End Of Settings
}

return Settings
