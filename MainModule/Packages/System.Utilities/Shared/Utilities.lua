--[[

	Description: Various utility objects and methods used by both the client and server.
	Author: Sceleratis
	Date: 12/04/2021

--]]

local Root = {}
local EventObjects = {}
local InitFunctions = {}
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

--// Utility Object Methods
local ObjectMethods = {

	--// Event methods
	Event = {
		Connect = function(self, func)
			local eventObject = EventObjects[self.EventName]

			if not eventObject then
				eventObject = Instance.new("BindableEvent")
				EventObjects[self.EventName] = eventObject
			end

			return eventObject.Event:Connect(func)
		end;

		Wait = function(self)
			local eventObject = EventObjects[self.EventName]

			if not eventObject then
				eventObject = Instance.new("BindableEvent")
				EventObjects[self.EventName] = eventObject
			end

			return eventObject.Event:Wait()
		end;

		Fire = function(self, ...)
			local eventObject = EventObjects[self.EventName]
			if eventObject then
				return eventObject:Fire(...)
			end
		end;

		Destroy = function(self, ...)
			local eventObject = EventObjects[self.EventName]
			if eventObject then
				EventObjects[self.EventName] = nil
				return eventObject:Destroy()
			end
		end
	},

	--// MemoryCache
	MemoryCache = {
		CleanCache = function(self)
			for ind,data in pairs(self.__Cache) do
				if os.time() - data.CacheTime > data.Timeout then
					self.__Cache[ind] = nil
				end
			end
		end,

		SetData = function(self, key: any, value: any?, data)
			self:CleanCache()
			self.__Cache[key] = if value ~= nil then {
				Value = value,
				Timeout = (data and data.Timeout) or self.__DefaultTimeout,
				AccessResetsTimer = if data and data.AccessResetsTimer ~= nil then data.AccessResetsTimer else self.__AccessResetsTimer,
				CacheTime = os.time()
			} else nil
		end,

		GetData = function(self, key: any)
			local found = self.__Cache[key]
			if found and os.time() - found.CacheTime <= found.Timeout then
				if found.AccessResetsTimer then
					found.CacheTime = os.time()
				end
				return found.Value
			elseif found then
				self.__Cache[key] = nil
			end
		end,

		__index = function(self, ind)
			return self:GetData(ind)
		end,

		__newindex = function(self, ind, value)
			self:SetData(ind, value)
		end
	},
}

--// Utilities
local Utilities = {
	Warn = warn,

	--// Caches and returns Roblox services retrieved via game:GetService()
	Services = table.freeze(setmetatable({}, {
		__index = function(self, ind)
			local cached = Cache.KnownServices[ind]
			local service = cached or game:GetService(ind)
			if not cached then
				Cache.KnownServices[ind] = service
			end
			return service
		end,
	})),

	--// Responsible for all non-Roblox system events
	Events = table.freeze(setmetatable({},{
		__index = function(self, EventName)
			local methods = ObjectMethods.Event
			return table.freeze({
				EventName = EventName;
				Fire = methods.Fire;
				Wait = methods.Wait;
				Connect = methods.Connect;
			})
		end
	})),

	--// Handles data caching
	MemoryCache = function(self, data)
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
	end,

	--// Runs the given function and outputs any errors
	RunFunction = function(self, func, ...)
		return xpcall(func, function(err)
			if self.Services.RunService:IsStudio() then
				warn("Error while running function; Expand for more info", {Error = tostring(err), Raw = err})
			else --// The in-game developer console does not support viewing of table contents.
				warn("Error while running function;", err)
			end
		end, ...)
	end,
}

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
