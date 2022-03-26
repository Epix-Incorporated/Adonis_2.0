--[[

	Description: Data management and persistence.
	Author: Sceleratis
	Date: 1/9/2022

--]]


local Root, Utilities, Service, Package;

local Data = {
	--// How many times we should reattempt a datastore operation before giving up
	GetDataRetryCount = 5,
	SetDataRetryCount = 5,
	UpdateDataRetryCount = 5,

	--// Retry interval
	GetDataRetryInterval = 1,
	SetDataRetryInterval = 1,
	UpdateDataRetryInterval = 1,

	--// Update Intervals
	SystemDataUpdateInterval = 30, --// Every 30 seconds, if there's pending saves, do save
	PlayerDataUpdateInterval = 10, --// 0 = Update as soon as there's a save request

	--// Pending changes holder
	PendingSystemSaves = {},
	PendingPlayerSaves = {},

	SystemSaves = {},
	PlayerSaves = {},

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

	GetSavedPlayerData = function(self, p)
		return Root.Data:GetData(self.PlayerDataStore, tostring(p.UserId))
	end,

	GetSavedSystemData = function(self, key)
		return Root.Data:GetData(self.SystemDataStore, key)
	end,

	SetSavedPlayerData = function(self, p, data)
		return Root.Data:SetData(self.PlayerDataStore, tostring(p.UserId), data)
	end,

	SetSavedSystemData = function(self, key, data)
		return Root.Data:SetData(self.SystemDataStore, key, data)
	end,

	UpdateSavedPlayerData = function(self, p, callback)
		return Root.Data:UpdateData(self.PlayerDataStore, tostring(p.UserId), callback)
	end,

	UpdateSavedSystemData = function(self, key, callback)
		return Root.Data:UpdateData(self.SystemDataStore, key, callback)
	end,

	--// Datastore handlers
	SetData = function(self, datastore, key, data)
		Utilities.Events.DatastoreSetData:Fire(datastore, key, data)

		return Utilities:Queue("DS_SetData", function()
			local retryCount = 0
			repeat
				local ran,ret = pcall(datastore.SetAsync, datastore, key, data)

				if ran then
					return true
				else
					Root.Warn("SetData Attempt Failed. Retrying...", ret)
					Utilities.Events.DatastoreSetDataFailed:Fire(datastore, key, data, retryCount)
					task.wait(self.SetDataRetryInterval)
				end

				retryCount += 1
			until retryCount == self.SetDataRetryCount
		end)
	end,

	GetData = function(self, datastore, key)
		Utilities.Events.DatastoreGetDataAttempt:Fire(datastore, key)

		return Utilities:Queue("DS_GetData", function()
			local retryCount = 0
			repeat
				local ran,ret = pcall(datastore.GetAsync, datastore, key)

				if ran then
					Utilities.Events.DatastoreGetData:Fire(datastore, key, ret)
					return ret
				else
					Root.Warn("GetData Attempt Failed. Retrying...", ret)
					Utilities.Events.DatastoreGetDataFailed:Fire(datastore, key, retryCount)
					task.wait(self.GetDataRetryInterval)
				end

				retryCount += 1
			until retryCount == self.GetDataRetryCount
		end)
	end,

	UpdateData = function(self, datastore, key, callback)
		Utilities.Events.DatastoreUpdateData:Fire(datastore, key, callback)

		return Utilities:Queue("DS_UpdateData", function()
			local retryCount = 0
			repeat
				local ran,ret = pcall(datastore.UpdateAsync, datastore, key, callback)

				if ran then
					return true
				else
					Root.Warn("UpdateData Attempt Failed. Retrying...", ret)
					Utilities.Events.DatastoreUpdateDataFailed:Fire(datastore, key, callback, retryCount)
					task.wait(self.UpdateDataRetryInterval)
				end

				retryCount += 1
			until retryCount == self.UpdateDataRetryCount
		end)
	end,

	PerformSystemDataUpdate = function(self, datastore, pendingChanges: {})
		for path,value in pairs(self.PendingSystemSaves) do
		end
	end,

	PerformPlayerDataUpdate = function(self, datastore, pendingChanges: {})
		for userid, data in pairs(self.PendingPlayerSaves) do
			local playerData = data.PlayerData
			local lastUpdate = playerData.LastDataUpdate
			if not lastUpdate or (lastUpdate and os.time() - lastUpdate >= self.PlayerDataUpdateInterval) then
				playerData.LastDataUpdate = os.time()

				self:SetData(self.PlayerDataStore, tostring(userid), data)
			end
		end
	end,

	SetupDatastore = function(self)
		local dataStoreService = if Utilities:IsStudio() then Root.Libraries.MockDataStoreService else Service.DataStoreService
		local systemStore = dataStoreService:GetDataStore(Root.Settings.DataStoreName .."_System")
		local playerStore = dataStoreService:GetDataStore(Root.Settings.DataStoreName .."_PlayerData")

		self.SystemDataStore = systemStore
		self.PlayerDataStore = playerStore
	end,

	PersistentPlayerDataUpdated = function(self, p, playerData, persistentData, index, value)
		self.PendingPlayerSaves[p.UserId] = {
			LastChange = os.time(),
			PlayerData = playerData,
			PersistentData = playerData.PersistentData
		}
	end
}

local function PersistentPlayerDataUpdated(...)
	Data:PersistentPlayerDataUpdated(...)
end

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		--// Do init
		Root.Data = Data

		Data:SetupDatastore()

		local persistentData = Utilities:MemoryCache({
			Timeout = Data.PersistentDataTimeout
		})

		Root.PersistentData = setmetatable({}, {
			__index = function(self, ind)
				local gotData = persistentData:GetData(ind)

			end,

			__newindex = function(self, ind, value)
				--// Save?
			end
		})

		Root.Core:DeclareDefaultPlayerData("PersistentData", function(p, newData)
			local dataTable = Root.Data:GetSavedPlayerData(p) or {}
			return setmetatable({}, {
				__index = function(self, ind)
					return dataTable[ind]
				end,

				__newindex = function(self, ind, val)
					dataTable[ind] = val
					Utilities.Events.PersistentPlayerDataUpdated:Fire(p, newData, dataTable, ind, val)
				end,
			})
		end)
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
		Data.SystemDataSaveUpdateLoop = Utilities.Tasks:NewTask("Thread: DatastoreUpdate_System", function()
			while task.wait(Data.SystemDataUpdateInterval) do
				Root.Data:PerformDataUpdate()
			end
		end)

		Data.PlayerDataSaveUpdateLoop = Utilities.Tasks:NewTask("Thread: DatastoreUpdate_Players", function()
			while task.wait(Data.SystemDataUpdateInterval) do
				Root.Data:PerformDataUpdate()
			end
		end)

		Utilities.Events.PersistentPlayerDataUpdated:Connect(PersistentPlayerDataUpdated)
	end;
}
