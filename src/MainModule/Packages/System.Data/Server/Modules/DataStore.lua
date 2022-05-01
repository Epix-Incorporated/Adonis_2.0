--[[

	Description: DataStore handling methods.
	Author: Sceleratis
	Date: 4/3/2022

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
	UpdateDataRetryInterval = 1
}

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
				warn("SetData Attempt Failed. Retrying...", ret)
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
				warn("GetData Attempt Failed. Retrying...", ret)
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
				warn("UpdateData Attempt Failed. Retrying...", ret)
				Utilities.Events.DatastoreUpdateDataFailed:Fire(datastore, key, callback, retryCount)
				task.wait(self.UpdateDataRetryInterval)
			end

			retryCount += 1
		until retryCount == self.UpdateDataRetryCount
	end)
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


--// Return initializer
return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		--// Do init
		if not Root.Data then
			Root.Data = Data
		else
			Utilities:MergeTables(Root.Data, Data)
		end

		Root.Data:SetupDatastore()
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
	end;
}
