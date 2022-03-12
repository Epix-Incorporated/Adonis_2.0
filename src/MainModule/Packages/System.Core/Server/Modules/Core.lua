--[[

	Description: Contains various variables & methods required for core functionality
	Author: Sceleratis
	Date: 12/05/2021

--]]

local Root, Package, Utilities, Service

local function delayedTimeoutMessage(stillWaiting: boolean, name: string, s: number)
	if stillWaiting then
		Root.Warn("Process taking too long to complete: >".. s .."s", name)
	end
end

--- Responsible for important core system fucntionality.
--- @class Server.Core
--- @server
--- @tag Core
--- @tag Package: System.Core
local Core = {
	PlayerData = {};
	PlayerDataCache = {};
	DeclaredSettings = {};
	SettingsOverrides = {};
	DeclaredDefaultPlayerData = {};
	DeclaredPlayerPreLoadingHandlers = {};
	DeclaredPlayerDataHandlers = {};
	DefaultPlayerDataTable = {};
}


--- Declares default player data
--- @method DeclareDefaultPlayerData
--- @within Server.Core
--- @param ind string -- PlayerData index
--- @param defaultValue any -- Default player data value (can be function which returns data (use for tables))
function Core.DeclareDefaultPlayerData(self, ind, defaultValue)
	if self.DeclaredDefaultPlayerData[ind] then
		Root.Warn("DefaultPlayerData \"".. ind .."\" already delcared. Overwriting.")
	end

	self.DeclaredDefaultPlayerData[ind] = defaultValue

	Utilities.Events.DefaultPlayerDataDeclared:Fire(ind, defaultValue)
end


--- Declares player pre-loading process functions
--- @method DeclarePlayerPreLoadProcess
--- @within Server.Core
--- @param ind string -- PreLoad function name
--- @param func function -- PreLoad function
function Core.DeclarePlayerPreLoadProcess(self, ind, func)
	if self.DeclaredPlayerPreLoadingHandlers[ind] then
		Root.Warn("Player Pre-Loading Process \"".. ind .."\" already declared. Overwriting.")
	end

	self.DeclaredPlayerPreLoadingHandlers[ind] = func

	Utilities.Events.PlayerPreLoadingHandlerDeclared:Fire(ind, func)
end

--- Declares player data handler functions
--- @method DeclarePlayerDataHandler
--- @within Server.Core
--- @param ind string -- Handler name
--- @param func function -- Handler function
function Core.DeclarePlayerDataHandler(self, ind, func)
	if self.DeclaredPlayerDataHandlers[ind] then
		Root.Warn("PlayerDataHandler \"".. ind .."\" already delcared. Overwriting.")
	end

	self.DeclaredPlayerDataHandlers[ind] = func

	Utilities.Events.PlayerDataHandlerDeclared:Fire(ind, func)
end


--- Handles player pre-loading processes
--- @method HandlePlayerPreLoadingProcesses
--- @within Server.Core
--- @param p Player -- Player to perform processes for
function Core.HandlePlayerPreLoadingProcesses(self, p)
	for ind, handler in pairs(self.DeclaredPlayerPreLoadingHandlers) do
		local waiting = true
		task.delay(10, function() delayedTimeoutMessage(waiting, ind, 10) end)
		Utilities:RunFunction(handler, p)
		waiting = false
	end

	if p.Parent then
		return true
	end
end


--- Generates and returns default player data for the provided Player
--- @method DefaultPlayerData
--- @within Server.Core
--- @param p Player
--- @return PlayerData
function Core.DefaultPlayerData(self, p: Player)
	local newData = {}

	--// Merge default data table into new data table
	Utilities:MergeTables(newData, self.DefaultPlayerDataTable)

	for ind, value in pairs(self.DeclaredDefaultPlayerData) do
		if type(value) == "function" then
			local r, val = Utilities:RunFunction(value, p, newData)
			if r then
				newData[ind] = val
			end
		else
			newData[ind] = value
		end
	end

	for ind, func in pairs(self.DeclaredPlayerDataHandlers) do
		Utilities:RunFunction(func, p, newData)
	end

	--// Fire an event letting all modules know that we are getting default player data so they can add anything they need
	Utilities.Events.SetDefaultPlayerData:Fire(p, newData)

	return newData
end


--- Returns data for the provided Player
--- @method GetPlayerData
--- @within Server.Core
--- @param p Player
--- @return PlayerData
function Core.GetPlayerData(self, p: Player)
	local cached = self.PlayerData:GetData(p.UserId)

	if cached then
		return cached
	else
		local defaultData = self:DefaultPlayerData(p)
		self.PlayerData:SetData(p.UserId, defaultData)
		return defaultData
	end
end


--- Declare new settings, their default value, and their description
--- @method DeclareSetting
--- @within Server.Core
--- @param setting string -- Setting
--- @param data table -- Setting data table
function Core.DeclareSetting(self, setting, data)
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

	Root.Logging:AddLog("Script", {
		Text = "Declared setting: ".. tostring(setting),
		Description = data.Description
	})

	Utilities.Events.SettingDeclared:Fire(setting, data)
end


--- If a setting is not found, this is responsible for returning a value for it (or possibly, also setting it)
--- @method SettingsIndex
--- @within Server.Core
--- @param tab table
--- @param ind string -- Setting
--- @return DefaultSettingValue
function Core.SettingsIndex(self, tab, ind)
	local found = self.DeclaredSettings[ind]
	if found then
		return found.DefaultValue
	else
		Root.Warn("Unknown setting requested:", ind)
	end
end


--- Returns all known settings
--- @method GetAllSettings
--- @within Server.Core
function Core.GetAllSetting(self)
	return Utilities:MergeTables({}, self.UserSettings, self.SettingsOverrides)
end


--- Get settings which should be shared with the client for the provided Player
--- @method GetSharedSettings
--- @within Server.Core
--- @param p Player
--- @return settings
function Core.GetSharedSettings(self, p: Player)
	local result = {}
	for ind, data in pairs(self.DeclaredSettings) do
		if data.ClientAllowed then
			result[ind] = Root.Settings[ind]
		end
	end
	return result
end


--- Update the specified setting to the provided value
--- @method UpdateSetting
--- @within Server.Core
--- @param setting string
--- @param value any
--- @param save bool -- Whether or not this should be saved; Only takes effect if System.Data package is loaded
function Core.UpdateSetting(self, setting, value, save)
	Root.Core.SettingsOverrides[setting] = value
	Utilities.Events.SettingChanged:Fire(setting, value, save)
end


--// Event functions
local function PlayerAdded(p)
	local data = Core:GetPlayerData(p)
	Root.Logging:AddLog("Connections", "%s joined", p.Name)
end

local function PlayerRemoved(p)
	local data = Core:GetPlayerData(p)
	Utilities.Events.RemovingPlayerData:Fire(p, data)
	wait(0.5);
	Core.PlayerData:SetData(p.UserId, nil)
	Root.Logging:AddLog("Connections", "%s left", p.Name);
end

local function PlayerError(p: Player, msg, ...)
	Root.Logging:AddLog("Error", "PlayerError: %s :: %s", p.Name, msg);
end

local function PlayerReady(p: Player)
	Root.Remote:Send(p, "DeclareSettings", Root.Core:GetSharedSettings(p))
end

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		Root.Core = Core
		Root.Timeouts = {
			PlayerDataCacheTimeout = 60*10
		}

		Root.Core.UserSettings = Root.Settings
		Root.Settings = setmetatable({}, {
			__index = function(self, ind)
				if Root.Core.SettingsOverrides[ind] ~= nil then
					return Root.Core.SettingsOverrides[ind]
				else
					return Core:SettingsIndex(self, ind);
				end
			end,

			__newindex = function(self, ind, val)
				Root.Core:UpdateSetting(ind, val)
			end,
		});

		Core.PlayerData = Utilities:MemoryCache({
			Core.PlayerDataCache,
			Timeout = Root.Timeouts.PlayerDataCacheTimeout,
			AccessResetsTimer = true
		})

		Core:DeclareDefaultPlayerData("Leaving", false)
		Core:DeclareDefaultPlayerData("ClientReady", false)
		Core:DeclareDefaultPlayerData("ObtainedKeys", false)

		Core:DeclareDefaultPlayerData("Cache", function(p, newData)
			return Utilities:MemoryCache({
				Cache = {},
				Timeout = 0,
				AccessResetsTimer = false
			})
		end)

		Core:DeclareDefaultPlayerData("EncryptionKey", function(p, newData)
			return Utilities:RandomString()
		end)

		Core:DeclareDefaultPlayerData("UserSettings", function(p, newData)
			return {}
		end)

		--// Declare settings
		if Package.Metadata.Settings then
			for setting,data in pairs(Package.Metadata.Settings) do
				Core:DeclareSetting(setting, data)
			end
		end
	end;

	AfterInit = function(Root, Package)
		Utilities.Events.SettingChanged:Connect(function(setting, val)
			local declared = Core.DeclaredSettings[setting]
			if declared and declared.ClientAllowed then
				for i,p in ipairs(Service.Players:GetPlayers()) do
					Root.Remote:Send(p, "UpdateSetting", setting, val)
				end
			end
		end)

		Utilities.Events.PlayerAdded:Connect(PlayerAdded)
		Utilities.Events.PlayerRemoved:Connect(PlayerRemoved)
		Utilities.Events.PlayerError:Connect(PlayerError)
		Utilities.Events.PlayerReady:Connect(PlayerReady)
	end;
}
