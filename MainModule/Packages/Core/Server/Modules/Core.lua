--[[

	Description: Contains various variables & methods required for core functionality
	Author: Sceleratis
	Date: 12/05/2021

--]]

local Root, Package, Utilities, Service

local Core = {
	DeclaredSettings = {},

	--// Declare new settings, their default value, and their description
	DeclareSetting = function(self, setting, defaultValue, description)
		if self.DeclaredSettings[setting] then
			Root.Warn("Setting \"".. setting .."\" already delcared. Overwriting.")
		end

		self.DeclaredSettings[setting] = {
			DefaultValue = defaultValue;
			Description = description;
		}
	end,

	--// If a setting is not found, this is responsible for returning a value for it (or possibly, also setting it)
	SettingsIndex = function(self, tab, ind)
		local found = self.DeclaredSettings[ind]
		if found then
			return found.DefaultValue
		else
			Root.Warn("Unknown setting requested:", ind)
		end
	end,
}

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		local settings = Root.Settings;
		Root.Settings = setmetatable(settings, {
			__index = function(self, ind)
				return Core:SettingsIndex(self, ind);
			end,
		});

		Root.Core = Core
	end;

	AfterInit = function(Root, Package)

	end;
}
