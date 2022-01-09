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

local Core = {
	PlayerData = {};
	PlayerDataCache = {};
	DeclaredSettings = {};
	SettingsOverrides = {};
	DeclaredDefaultPlayerData = {};
	DeclaredPlayerPreLoadingHandlers = {};
	DeclaredPlayerDataHandlers = {};
	DefaultPlayerDataTable = {};

	DeclareDefaultPlayerData = function(self, ind, defaultValue)
		if self.DeclaredDefaultPlayerData[ind] then
			Root.Warn("DefaultPlayerData \"".. ind .."\" already delcared. Overwriting.")
		end

		self.DeclaredDefaultPlayerData[ind] = defaultValue

		Utilities.Events.DefaultPlayerDataDeclared:Fire(ind, defaultValue)
	end,

	DeclarePlayerPreLoadProcess = function(self, ind, func)
		if self.DeclaredPlayerPreLoadingHandlers[ind] then
			Root.Warn("Player Pre-Loading Process \"".. ind .."\" already declared. Overwriting.")
		end

		self.DeclaredPlayerPreLoadingHandlers[ind] = func

		Utilities.Events.PlayerPreLoadingHandlerDeclared:Fire(ind, func)
	end,

	DeclarePlayerDataHandler = function(self, ind, func)
		if self.DeclaredPlayerDataHandlers[ind] then
			Root.Warn("PlayerDataHandler \"".. ind .."\" already delcared. Overwriting.")
		end

		self.DeclaredPlayerDataHandlers[ind] = func

		Utilities.Events.PlayerDataHandlerDeclared:Fire(ind, func)
	end,

	HandlePlayerPreLoadingProcesses = function(self, p)
		for ind, handler in pairs(self.DeclaredPlayerPreLoadingHandlers) do
			local waiting = true
			task.delay(10, function() delayedTimeoutMessage(waiting, ind, 10) end)
			Utilities:RunFunction(handler, p)
			waiting = false
		end

		if p.Parent then
			return true
		end
	end,

	DefaultPlayerData = function(self, p)
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
	end,

	GetPlayerData = function(self, p)
		local cached = self.PlayerData:GetData(p.UserId)

		if cached then
			return cached
		else
			local defaultData = self:DefaultPlayerData(p)
			self.PlayerData:SetData(p.UserId, defaultData)
			return defaultData
		end
	end,

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

		Root.Logging:AddLog("Script", {
			Text = "Declared setting: ".. tostring(setting),
			Description = data.Description
		})

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

	GetSharedSettings = function(self, p: Player)
		local result = {}
		for ind, data in pairs(self.DeclaredSettings) do
			if data.ClientAllowed then
				result[ind] = Root.Settings[ind]
			end
		end
		return result
	end
}

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
				elseif Root.Core.UserSettings[ind] ~= nil then
					return Root.Core.UserSettings[ind]
				else
					return Core:SettingsIndex(self, ind);
				end
			end,

			__newindex = function(self, ind, val)
				Root.Core.SettingsOverrides[ind] = val
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

		--// Declare settings
		if Package.Metadata.Settings then
			for setting,data in pairs(Package.Metadata.Settings) do
				Core:DeclareSetting(setting, data)
			end
		end
	end;

	AfterInit = function(Root, Package)
		Utilities.Events.PlayerAdded:Connect(PlayerAdded)
		Utilities.Events.PlayerRemoved:Connect(PlayerRemoved)
		Utilities.Events.PlayerError:Connect(PlayerError)
		Utilities.Events.PlayerReady:Connect(PlayerReady)
	end;
}
