--[[

	Description: Contains various variables & methods required for core functionality
	Author: Sceleratis
	Date: 12/05/2021

--]]

local Root, Package, Utilities, Service

local Core = {
	SettingsOverrides = {},
	DeclaredSettings = {},

	--// Declare new settings, their default value, and their description
	DeclareSetting = function(self, setting, data)
		if self.DeclaredSettings[setting] then
			Root.Warn("Setting \"".. setting .."\" already delcared. Overwriting.")
		end

		if data.Package and type(data.Package) == "table" then
			local realPackage = data.Package.Package or data.Package.Folder
			if realPackage then
				data.Package = realPackage
			end
		end

		self.DeclaredSettings[setting] = data
		Utilities.Events.SettingDeclared:Fire(setting, data)
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

	GetAllSettings = function(self)
		return Utilities:MergeTables({}, self.UserSettings, self.SettingsOverrides)
	end,
}

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		--// Do init
		Root.Core = Core
		Root.Timeouts = {}
		Root.Cache = Utilities:MemoryCache({ Timeout = 0 })

		Root.Core.UserSettings = {}
		Root.Settings = setmetatable({}, {
			__index = function(self, ind)
				if Root.Core.SettingsOverrides[ind] ~= nil then
					return Root.Core.SettingsOverrides[ind]
				elseif Root.Core.UserSettings[ind] ~= nil then
					return Root.Core.UserSettings[ind]
				else
					return Core:SettingsIndex(self, ind);
				end
			end,

			__newindex = function(self, ind, val)
				Root.Core.SettingsOverrides[ind] = val
				Utilities.Events.SettingChanged:Fire(ind, val)
			end,
		});

		--// Declare settings
		if Package.Metadata.Settings then
			for setting,data in pairs(Package.Metadata.Settings) do
				Root.Core:DeclareSetting(setting, data)
			end
		end
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
	end;
}
