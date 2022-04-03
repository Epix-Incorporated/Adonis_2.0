--[[

	Description: Data management and persistence.
	Author: Sceleratis
	Date: 1/9/2022

--]]


local Root, Utilities, Service, Package;

--[=[
	Responsible for data storage and retrieval.
	@class Server.Data
	@tag System.Data
	@server
]=]

--[=[
	Datastore GetAsync operation retry limit.
	@prop GetDataRetryCount number
	@within Server.Data
]=]

--[=[
	Datastore SetAsync operation retry limit.
	@prop SetDataRetryCount number
	@within Server.Data
]=]

--[=[
	Datastore UpdateAsync operation retry limit.
	@prop UpdateDataRetryCount number
	@within Server.Data
]=]

--[=[
	Datastore GetAsync operation retry interval.
	@prop GetDataRetryInterval number
	@within Server.Data
]=]

--[=[
	Datastore SetAsync operation retry interval.
	@prop SetDataRetryInterval number
	@within Server.Data
]=]

--[=[
	System data update interval.
	@prop SystemDataUpdateInterval number
	@within Server.Data
]=]

--[=[
	Player data update interval.
	@prop PlayerDataUpdateInterval number
	@within Server.Data
]=]

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
	SavedSettings = {}
}

--[=[
	Responsible for setting saving functionality.
	@method SaveSetting
	@within Server.Data
	@param index string
	@param value any
]=]
function Data.SaveSetting(self, index: string, value: any)
	if self.Datastore then
	end
end

--[=[
	Responsible for setting data reset functionality.
	@method ResetSetting
	@within Server.Data
	@param index string
]=]
function Data.ResetSetting(self, index: string)
	if self.Datastore then
	end
end

--[=[
	Returns saved data for the provided player.
	@method GetSavedPlayerData
	@within Server.Data
	@param p Player
	@return {[string]: any}
]=]
function Data.GetSavedPlayerData(self, p: Player): {[string]: any}
	return Root.Data:GetData(self.PlayerDataStore, tostring(p.UserId))
end

--[=[
	Returns saved system data.
	@method GetSavedSystemData
	@within Server.Data
	@param key string
	@return any
]=]
function Data.GetSavedSystemData(self, key: string): any
	return Root.Data:GetData(self.SystemDataStore, key)
end

--[=[
	Set saved data for provided player.
	@method SetSavedPlayerData
	@within Server.Data
	@param p Player
	@param data {[string]: any}
]=]
function Data.SetSavedPlayerData(self, p: Player, data: {[string]: any})
	return Root.Data:SetData(self.PlayerDataStore, tostring(p.UserId), data)
end

--[=[
	Set saved system data.
	@method SetSavedSystemData
	@within Server.Data
	@param key string
	@param data any
]=]
function Data.SetSavedSystemData(self, key: string, data: any)
	return Root.Data:SetData(self.SystemDataStore, key, data)
end

--[=[
	Updates data for the provided player.
	@method UpdateSavedPlayerData
	@within Server.Data
	@param p Player
	@param callback (any)
]=]
function Data.UpdateSavedPlayerData(self, p: Player, callback: (any))
	return Root.Data:UpdateData(self.PlayerDataStore, tostring(p.UserId), callback)
end

--[=[
	Update saved system data.
	@method UpdateSavedSystemData
	@within Server.Data
	@param key string
	@param callback (any)
]=]
function Data.UpdateSavedSystemData(self, key: string, callback: (any))
	return Root.Data:UpdateData(self.SystemDataStore, key, callback)
end

--// Datastore handlers

--[=[
	Handles DataStore SetAsync operations.
	@method SetData
	@within Server.Data
	@param datastore DataStore
	@param key string
	@param data any
]=]
function Data.SetData(self, datastore: DataStore, key: string, data: any)
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
end

--[=[
	Handles DataStore GetAsync operations.
	@method GetData
	@within Server.Data
	@param datastore DataStore
	@param key string
	@return any
]=]
function Data.GetData(self, datastore: DataStore, key: string): any
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
end

--[=[
	Handles DataStore UpdateAsync operations.
	@method UpdateData
	@within Server.Data
	@param datastore DataStore
	@param key string
	@param callback (any)
]=]
function Data.UpdateData(self, datastore: DataStore, key: string, callback: (any))
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
end

--[=[
	(WIP) Performs system data update operation.
	@method PerformSystemDataUpdate
	@within Server.Data
	@param datastore DataStore
	@param pendingChanges {}
]=]
function Data.PerformSystemDataUpdate(self, datastore: DataStore, pendingChanges: {})
	for path,value in pairs(self.PendingSystemSaves) do
	end
end

--[=[
	Performs player data update operation for all players.
	@method PerformPlayerDataUpdate
	@within Server.Data
	@param datastore DataStore
	@param pendingChanges {}?
]=]
function Data.PerformPlayerDataUpdate(self, datastore: DataStore, pendingChanges: {}?)
	for userid, data in pairs(pendingChanges or self.PendingPlayerSaves) do
		local playerData = data.PlayerData
		local lastUpdate = playerData.LastDataUpdate
		if not lastUpdate or (lastUpdate and os.time() - lastUpdate >= self.PlayerDataUpdateInterval) then
			playerData.LastDataUpdate = os.time()

			self:SetData(self.PlayerDataStore, tostring(userid), data)
		end
	end
end

--[=[
	Handles DataStore setup and variable assignment.
	@method SetupDatastore
	@within Server.Data
]=]
function Data.SetupDatastore(self)
	local dataStoreService = if Utilities:IsStudio() then Root.Libraries.MockDataStoreService else Service.DataStoreService
	local systemStore = dataStoreService:GetDataStore(Root.Settings.DataStoreName .."_System")
	local playerStore = dataStoreService:GetDataStore(Root.Settings.DataStoreName .."_PlayerData")

	self.SystemDataStore = systemStore
	self.PlayerDataStore = playerStore
end

--[=[
	(WIP) Marks pending player data for saving when updated.
	@method PersistentPlayerDataUpdated
	@within Server.Data
	@param p Player
	@param playerData {[string]: any}
	@param persistentData {[string]: any}
	@param index string
	@param value any
]=]
function Data.PersistentPlayerDataUpdated(self, p: Player, playerData: {[string]: any}, persistentData: {[string]: any}, index: string, value: any)
	self.PendingPlayerSaves[p.UserId] = {
		LastChange = os.time(),
		PlayerData = playerData,
		PersistentData = playerData.PersistentData
	}
end


--// Helpers
local function PersistentPlayerDataUpdated(...)
	Data:PersistentPlayerDataUpdated(...)
end


--// Return initializer
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
