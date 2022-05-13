--[[

	Description: Various utility objects and methods used by both the client and server.
	Author: Sceleratis
	Date: 12/04/2021

--]]

local Root = {}
local EventObjects = {}
local InitFunctions = {}
local ObjectMethods = {}
local oWarn = warn

local function warn(...)
	if Root and Root.Warn then
		Root.Warn(...)
	else
		oWarn(":: Adonis Utilities ::", ...)
	end
end

--// Cache
local Cache = {
	KnownServices = {}
}

--- Responsible for temporary memory storage.
--- @class MemoryCache
--- @server
--- @client
--- @tag Utilities
--- @tag Package: System.Utilities

--- Responsible for configuration of individual cache entries.
--- @interface CacheEntryData
--- @within MemoryCache
--- @field Value any -- Cache entry value
--- @field Timeout int -- Optional timeout for this specific cache entry
--- @field AccessResetsTimer bool -- If true, this entry's timeout timer will be reset whenever data is accessed
--- @field CacheTime int -- os.time() when the cache was last updated (or accessed)

--- MemoryCache default data
--- @interface DefaultCacheData
--- @within Utilities
--- @field Cache {} -- Optional table to use for caching
--- @field Timeout int -- Optional default timeout for cache items; Defaults to infinite if no timeout is provided
--- @field AccessResetsTimer bool -- Bool indicated whether or not cache timers should be reset on data access

ObjectMethods.MemoryCache = {
	__index = function(self, ind)
		return self:GetData(ind)
	end,

	__newindex = function(self, ind, value)
		self:SetData(ind, value)
	end
}


--- Clears any expired cache entries. This is called automatically when data is set.
--- @method CleanCache
--- @within MemoryCache
function ObjectMethods.MemoryCache.CleanCache(self)
	for ind,data in pairs(self.__Cache) do
		if os.time() - data.CacheTime > data.Timeout then
			self.__Cache[ind] = nil
		end
	end
end


--- Sets the given index in the cache to the value provided.
--- @method SetData
--- @within MemoryCache
--- @param key any -- Cache key used to update and retrieve stored values
--- @param value any -- Value to store
--- @param data CacheEntryData -- Optional table describing how to handle stored data
function ObjectMethods.MemoryCache.SetData(self, key: any, value: any?, data)
	self:CleanCache()
	self.__Cache[key] = if value ~= nil then {
		Value = value,
		Timeout = (data and data.Timeout) or self.__DefaultTimeout,
		AccessResetsTimer = if data and data.AccessResetsTimer ~= nil then data.AccessResetsTimer else self.__AccessResetsTimer,
		CacheTime = os.time()
	} else nil
end


--- Returns the value associated with the provided key.
--- @method GetData
--- @within MemoryCache
--- @param key any
--- @return any
function ObjectMethods.MemoryCache.GetData(self, key: any)
	local found = self.__Cache[key]
	if found ~= nil and os.time() - found.CacheTime <= found.Timeout then
		if found.AccessResetsTimer then
			found.CacheTime = os.time()
		end
		return found.Value
	elseif found ~= nil then
		self.__Cache[key] = nil
	end
end


--[=[
	Gets an item associated with the specified key from the cache, or sets it if expired or not found.
	@method GetOrSet
	@within MemoryCache
	@param key any -- Cache key used to update and retrieve stored values
	@param value any -- Value to store
	@param data CacheEntryData -- Optional table describing how to handle stored data
]=]
function ObjectMethods.MemoryCache.GetOrSet(self, key: any, value: any?, data: {[string]: any}?)
	local found = self:GetData(key)
	if found ~= nil then
		return found
	else
		local newVal = if type(value) == "function" then value() else value
		self:SetData(key, newVal, data)
		return newVal
	end
end


--- Event object returned by Utilities.Events
--- @class Event
--- @server
--- @client
--- @tag Utilities
--- @tag Package: System.Utilities

ObjectMethods.Event = {}

--- Event name
--- @prop EventName string
--- @within Event

--- Connect event
--- @method Connect
--- @within Event
--- @param func function -- Function to connect
function ObjectMethods.Event.Connect(self, func)
	local eventObject = EventObjects[self.EventName]

	if not eventObject then
		eventObject = Instance.new("BindableEvent")
		EventObjects[self.EventName] = eventObject
	end

	return eventObject.Event:Connect(func)
end


--- Waits for the event to fire
--- @method Wait
--- @within Event
--- @yields
function ObjectMethods.Event.Wait(self)
	local eventObject = EventObjects[self.EventName]

	if not eventObject then
		eventObject = Instance.new("BindableEvent")
		EventObjects[self.EventName] = eventObject
	end

	return eventObject.Event:Wait()
end


--- Fires the event, triggering and sending data to any connected function.
--- @method Fire
--- @within Event
--- @param ... any
function ObjectMethods.Event.Fire(self, ...)
	local eventObject = EventObjects[self.EventName]
	if eventObject then
		return eventObject:Fire(...)
	end
end


--- Destroys all connections for the event.
--- @method Destroy
--- @within Event
function ObjectMethods.Event.Destroy(self)
	local eventObject = EventObjects[self.EventName]
	if eventObject then
		EventObjects[self.EventName] = nil
		return eventObject:Destroy()
	end
end


--- Responsible for various utility methods and objects used throughout the system.
--- @class Utilities
--- @server
--- @client
--- @tag Utilities
--- @tag Package: System.Utilities

--- Console warnings
--- @function Warn
--- @within Utilities
--- @param ... any

local Utilities = { Warn = warn }

--- Caches and returns Roblox services retrieved via game:GetService()
--- @interface Services
--- @within Utilities
--- @field index string -- Table index corresponding to the requested service

Utilities.Services = table.freeze(setmetatable({}, {
	__index = function(self, ind)
		local cached = Cache.KnownServices[ind]
		local service = cached or game:GetService(ind)
		if not cached then
			Cache.KnownServices[ind] = service
		end
		return service
	end
}))


--- Responsible for all non-Roblox system events; Returns Event
--- @interface Events
--- @within Utilities
--- @field index string -- Index corresponding to requested event

Utilities.Events = table.freeze(setmetatable({},{
	__index = function(self, EventName)
		local methods = ObjectMethods.Event
		return table.freeze({
			EventName = EventName;
			Fire = methods.Fire;
			Wait = methods.Wait;
			Connect = methods.Connect;
		})
	end
}))


--- Returns a new MemoryCache object.
--- @method MemoryCache
--- @within Utilities
--- @param data DefaultCacheData
--- @return MemoryCache
function Utilities.MemoryCache(self, data)
	return setmetatable({
		__Cache = (data and data.Cache) or {},
		__DefaultTimeout = (data and data.Timeout) or 0,
		__AccessResetsTimer = if data and data.AccessResetsTimer ~= nil then data.AccessResetsTimer else false,

		CleanCache = ObjectMethods.MemoryCache.CleanCache,
		SetData = ObjectMethods.MemoryCache.SetData,
		GetData = ObjectMethods.MemoryCache.GetData
	}, {
		__index = ObjectMethods.MemoryCache.__index,
		__newindex = ObjectMethods.MemoryCache.__newindex
	})
end


--- Runs the given function and outputs any errors.
--- @method RunFunction
--- @within Utilities
--- @param func function -- Function to run
--- @param ... any -- Data to pass to ran function
--- @yields
function Utilities.RunFunction(self, func, ...)
	return xpcall(func, function(err)
		if self.Services.RunService:IsStudio() then
			warn("Error while running function; Expand for more info", {Error = tostring(err), Raw = err})
		else --// The in-game developer console does not support viewing of table contents.
			warn("Error while running function;", err)
		end
	end, ...)
end


--// Requires a given ModuleScript; If a function is returned immediately, run it
--// If a table is returned, assume deferred execution
local function LoadModule(Module: ModuleScript, ...)
	local ran, func = pcall(require, Module)
	if ran then
		if type(func) == "function" then
			Utilities:RunFunction(func, ...)
		elseif type(func) == "table" then
			table.insert(InitFunctions, func)
		end
	else
		warn("Encountered error while loading module:", {Module = Module, Error = tostring(func)})
	end
end

return table.freeze {
	Init = function(Root, Package)
		if Root.Utilities then
			for ind, val in pairs(Utilities) do
				Root.Utilities[ind] = val
			end
		else
			Root.Utilities = Utilities
		end

		Root.Events = Utilities.Events
		Root.Services = Utilities.Services

		for i,module in ipairs(Package.Shared.Modules:GetChildren()) do
			if module:IsA("ModuleScript") then
				LoadModule(module, Root, Package)
			end
		end

		--// Run init methods
		for i,t in ipairs(InitFunctions) do
			if t.Init then
				Utilities:RunFunction(t.Init, Root, Utilities)
			end
		end
	end;

	AfterInit = function(Root, Package)
		--// Run afterinit methods
		for i,t in ipairs(InitFunctions) do
			if t.AfterInit then
				Utilities:RunFunction(t.AfterInit, Root, Utilities)
			end
		end
	end;
}
