--[[

	Description: Contains various variables & methods required for core functionality
	Author: Sceleratis
	Date: 12/05/2021

--]]

local Root, Package, Utilities, Service

local Core = {
	PlayerData = {};
	DeclaredSettings = {};
	DeclaredDefaultPlayerData = {};
	DefaultPlayerDataTable = {};

	DeclareDefaultPlayerData = function(self, ind, defaultValue)
		if self.DeclaredDefaultPlayerData[ind] then
			Root.Warn("DefaultPlayerData \"".. ind .."\" already delcared. Overwriting.")
		end

		self.DeclaredDefaultPlayerData[ind] = defaultValue
	end,

	DefaultPlayerData = function(self, p)
		local newData = {}

		--// Merge default data table into new data table
		Utilities:MergeTables(newData, self.DefaultPlayerDataTable)

		for ind, value in pairs(self.DeclaredDefaultPlayerData) do
			if type(value) == "function" then
				Utilities:RunFunction(value, p, newData)
			else
				newData[ind] = value
			end
		end

		--// Fire an event letting all modules know that we are getting default player data so they can add anything they need
		Utilities.Events.SetDefaultPlayerData:Fire(p, newData)

		return newData
	end,

	GetPlayerData = function(self, p)
		if not self.PlayerData[p.UserId] then
			self.PlayerData[p.UserId] = self:DefaultPlayerData(p)
		end

		return self.PlayerData[p.UserId]
	end,

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

local function PlayerAdded(p)
	local data = Core:GetPlayerData(p)
	Root.Logging:AddLog("Connections", "%s joined", p.Name)
end

local function PlayerRemoved(p)
	wait(0.5);
	Core.PlayerData[p.UserId] = nil;
	Root.Logging:AddLog("Connections", "%s left", p.Name);
end

local function PlayerError(p: Player, msg, ...)
	Root.Logging:AddLog("Error", "PlayerError: %s :: %s", p.Name, msg);
end

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

		Core:DeclareDefaultPlayerData("Leaving", false)
		Core:DeclareDefaultPlayerData("ClientReady", false)
		Core:DeclareDefaultPlayerData("ObtainedKeys", false)
		Core:DeclareDefaultPlayerData("EncryptionKey", function(p, newData)
			newData.EncryptionKey = Utilities:RandomString();
		end);
	end;

	AfterInit = function(Root, Package)
		Utilities.Events.PlayerAdded:Connect(PlayerAdded)
		Utilities.Events.PlayerRemoved:Connect(PlayerRemoved)
		Utilities.Events.PlayerError:Connect(PlayerError)
	end;
}
