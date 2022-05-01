--[[

	Description: Contains various variables & methods required for core functionality
	Author: Sceleratis
	Date: 12/05/2021

--]]

local Root, Package, Utilities, Service

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


--- Responsible for core functionality.
--- @class Client.Core
--- @client
--- @tag Core
--- @tag Package: System.Core
local Core = {
	SettingsOverrides = {},
	DeclaredSettings = {}
}


--- Declare new settings, their default value, and their description
--- @method DeclareSetting
--- @within Client.Core
--- @param setting string -- Setting to declare
--- @param data table -- Setting information table
function Core.DeclareSetting(self, setting: string, data: {[string]: any})
	if self.DeclaredSettings[setting] then
		warn("Setting \"".. setting .."\" already delcared. Overwriting.")
	end

	if data.Package and type(data.Package) == "table" then
		local realPackage = data.Package.Package or data.Package.Folder
		if realPackage then
			data.Package = realPackage
		end
	end

	self.DeclaredSettings[setting] = data
	Utilities.Events.SettingDeclared:Fire(setting, data)
end


--[=[
	If a setting is not found, this is responsible for returning a value for it (or possibly, also setting it)
	@method SettingDefault
	@within Client.Core
	@param tab table
	@param ind string -- Setting
	@return DefaultSettingValue
]=]
function Core.SettingDefault(self, ind: string): any
	local found = self.DeclaredSettings[ind]

	DebugWarn("FOUND SETTING DEFAULT:", ind, found, self.DeclaredSettings)
	
	if found then
		return found.DefaultValue
	end
end


--[=[ 
	Responsible for returning the value of a setting if there is no override.
	@method SettingsIndex
	@within Client.Core
	@param tab table
	@param ind string -- Setting
	@return any
]=]
function Core.SettingsIndex(self, ind: string): any
	local override = Root.Core.SettingsOverrides[ind]
	local user = if override == nil then Root.Core.UserSettings[ind] else nil
	local default = if user == nil and override == nil then self:SettingDefault(ind) else nil
	local found = if override ~= nil then override elseif user ~= nil then user else default

	DebugWarn("SETTING | OVERRIDE", ind, override)
	DebugWarn("SETTING | USER", ind, user)
	DebugWarn("SETTING | DEFAULT", ind, default)
	DebugWarn("SETTING | FOUND", ind, found)
	
	if found then
		return found
	else
		warn("Unknown setting requested:", ind)
	end
end


--- Returns all currently known settings
--- @method GetAllSettings
--- @within Client.Core
--- @return table -- All settings in the format [setting] = value
function Core.GetAllSettings(self): {[any]: any}
	return Utilities:MergeTables({}, self.UserSettings, self.SettingsOverrides)
end


--- Updates the specified setting to the new value
--- @method UpdateSetting
--- @within Client.Core
--- @param setting string -- Setting
--- @param value any -- Value
function Core.UpdateSetting(self, setting: string, value: any)
	Root.Core.SettingsOverrides[setting] = value
	Utilities.Events.SettingChanged:Fire(setting, value)
end


--// Return initializer
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
				return Core:SettingsIndex(ind);
			end,

			__newindex = function(self, ind, val)
				Root.Core:UpdateSetting(ind, val)
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
