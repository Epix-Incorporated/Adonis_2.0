--[[

	Description:
	Author:
	Date:

--]]


local Root, Utilities, Service, Package;

local Data = {
	--// Settings handlers
	SavedSettings = {},

	SaveSetting = function(self, index: string, value)
		if self.Datastore then
		end
	end,

	ResetSetting = function(self, index: string)
		if self.Datastore then
		end
	end,

	--// Player handlers
	SavePlayerData = function(self, p: Player)
		if self.Datastore then
		end
	end,

	SaveAllPlayerData = function(self)
		if self.Datastore then
		end
	end,

	GetPlayerData = function(self, p: Player)
		if self.Datastore then

		end
	end,

	--// Datastore handlers
	SetData = function(self, key, data)
	end,

	GetData = function(self, key, data)
	end,

	UpdateData = function(self, key, callback)
	end,

	SetupDatastore = function(self)
		local systemStore = Service.DataStoreService:GetDataStore(Root.Settings.DataStoreName .."_System")
		local playerStore = Service.DataStoreService:GetDataStore(Root.Settings.DataStoreName .."_PlayerData")

		self.SystemStore = systemStore
		self.PlayerStore = playerStore
	end,
}

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		--// Do init
		Root.Data = Data

		local oSettings = Root.Settings
		Root.Settings = setmetatable({}, {
			__index = function(self, ind)
				local saved = Data.SavedSettings[ind]
				if saved then
					return saved.Value
				else
					return oSettings[ind]
				end
			end,

			__newindex = function(self, ind, value)
				--// Save?
			end
		})

		Root.Core:DeclareDefaultPlayerData("SaveData", function(p, newData)
			local dataTable = {}
			return setmetatable({}, {
				__index = function(self, ind)
					return dataTable[ind]
				end,

				__newindex = function(self, ind, val)
					dataTable[ind] = val
					Utilities.Events.SavedPlayerDataUpdated:Fire(p, ind, val)
				end,
			})
		end)
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
	end;
}
