--[[

	Description: Various utility objects and methods used by both the client and server.
	Author: Sceleratis
	Date: 12/04/2021

--]]

local Root = {}
local EventObjects = {}
local InitFunctions = {}
local ParentTester = Instance.new("Folder")
local __RANDOM_CHARSET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

local function RandomString(self, len: number, charset: string): string
	len = len or 9
	charset = charset or __RANDOM_CHARSET

	local charSetLen = string.len(charset)
	local newStr = ""

	for i = 1, len do
		local rand = math.random(1, charSetLen)
		newStr = newStr .. string.sub(charset, rand, rand)
	end

	return newStr
end

local function PropertyCheck(obj, prop): any
	return obj[prop]
end

local oWarn = warn
local function warn(...)
	if Root and Root.Warn then
		Root.Warn(...)
	else
		oWarn(":: Adonis ::", ...)
	end
end

--// Cache
local Cache = {
	KnownServices = {},
	Encrypt = {},
	Decrypt = {},
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

		SetData = function(self, key, value, data)
			self:CleanCache()
			self.__Cache[key] = if value ~= nil then {
				Value = value,
				Timeout = (data and data.Timeout) or self.__DefaultTimeout,
				AccessResetsTimer = if data and data.AccessResetsTimer ~= nil then data.AccessResetsTimer else self.__AccessResetsTimer,
				CacheTime = os.time()
			} else nil
		end,

		GetData = function(self, key)
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
	}
}

--// Utilities
local Utilities = {
	RandomString = RandomString,

	--// Caches and returns Roblox services retrieved via game:GetService()
	Services = table.freeze(setmetatable({}, {
		__index = function(self, ind)
			return Cache.KnownServices[ind] or game:GetService(ind)
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

	--// Modifies an Instance's properties according to the supplied dictionary
	EditInstance = function(self, object: Instance, properties: {[string]:any}?): Instance
		local connections = {}

		if self.Wrapping:IsWrapped(object) then
			object = self.Wrapping:UnWrap(object)
		end

		if properties then
			if typeof(properties) == "Instance" then
				object.Parent = properties
			elseif typeof(properties) == "table" then
				local parent = properties.Parent
				local events = properties.Events
				local children = properties.Children
				local attributes = properties.Attributes

				properties.Parent = nil
				properties.Events = nil
				properties.Children = nil
				properties.Attributes = nil

				for prop, val in pairs(properties) do
					object[prop] = val
				end

				if children then
					for _, child in pairs(children) do
						child.Parent = object
					end
				end

				if attributes then
					for attrib, value in pairs(attributes) do
						object:SetAttribute(attrib, value)
					end
				end

				if parent then
					object.Parent = parent
				end

				if events then
					for event, func in pairs(events) do
						connections[event] = object[event]:Connect(func)
					end
				end
			end
		end

		return object, connections
	end,

	--// Instance creation
	CreateInstance = function(self, class: string, properties: {})
		return self:EditInstance(Instance.new(class), properties)
	end,

	--// Returns true if this is running on the server
	IsServer = function(self): boolean
		return self.Services.RunService:IsServer()
	end,

	--// Returns true if this is running on the client
	IsClient = function(self): boolean
		return self.Services.RunService:IsClient()
	end,

	--// Returns os.time()
	GetTime = function(self): number
		return os.time()
	end,

	GetFormattedTime = function(self, optTime: number?, withDate: boolean?): string
		local formatString = withDate and "L LT" or "LT"
		local tim = DateTime.fromUnixTimestamp(optTime or self:GetTime())

		if self:IsServer() then
			return tim:FormatUniversalTime(formatString, "en-gb") --// Always show UTC in 24 hour format
		else
			local locale = self.Services.Players.LocalPlayer.LocaleId
			return select(2, xpcall(function()
				return tim:FormatLocalTime(formatString, locale) --// Show in player's local timezone and format
			end, function()
				return tim:FormatLocalTime(formatString, "en-gb") --// Show UTC in 24 hour format because player's local timezone is not available in DateTimeLocaleConfigs
			end))
		end
	end,

	--// Ex: 100000 -> "100,000"
	FormatNumber = function(self, num: number): string
		if not num then return "NaN" end
		num = tostring(num):reverse()
		local new = ""
		local counter = 1
		for i = 1, #num do
			if counter > 3 then
				new ..= ","
				counter = 1
			end
			new ..= num:sub(i, i)
			counter += 1
		end
		return new:reverse()
	end,

	--// Formats a Player's name as such: 'Username (@DisplayName)' or '@UserEqualsDisplayName'
	--// Optionally appends the player's UserId in square brackets
	FormatPlayer = function(self, plr: Player, withUserId: boolean?): string
		local str = if plr.DisplayName == plr.Name then "@"..plr.Name else string.format("%s (@%s)", plr.DisplayName, plr.Name)
		if withUserId then str ..= string.format(" [%d]", plr.UserId) end
		return str
	end,

	--// Formats a string for use with RichText
	FormatStringForRichText = function(self, str: string): string
		return str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\"", "&quot;"):gsub("'", "&apos;")
	end,

	--// Inserts elements from supplied ordered tables into the first table
	AddRange = function(self, tab, ...)
		for i,t in ipairs(table.pack(...)) do
			for k,v in ipairs(t) do
				table.insert(tab, v)
			end
		end

		return tab
	end,

	--// Merges tables into the first table
	--// Each subsequent table will overwrite keys in/from the tables that came before it
	MergeTables = function(self, tab, ...)
		for i,t in ipairs(table.pack(...)) do
			for k,v in pairs(t) do
				tab[k] = v
			end
		end

		return tab
	end,

	--// Returns the number of elements in a given table
	CountTable = function(tab: {[any]:any}, excludeNumIndices: boolean?): number
		local n = 0
		for i, v in pairs(tab) do
			if not excludeNumIndices or type(i) ~= "number" then
				n += 1
			end
		end
		return n
	end,

	--// Reverses the supplied table
	ReverseTable = function(array: {[number]:any}): {[number]:any}
		local len: number = #array
		local reversed = {}
		for i = 1, len do
			reversed[len-i] = array[i]
		end
		return reversed
	end,

	--// Weak encryption used mainly for trust checks
	Encrypt = function(self, str: string, key: string, cache: {}?): string
		cache = cache or Cache.Encrypt

		if not key or not str then
			return str
		elseif cache[key] and cache[key][str] then
			return cache[key][str]
		else
			local byte = string.byte
			local sub = string.sub
			local char = string.char

			local keyCache = cache[key] or {}
			local endStr = {}

			for i = 1, #str do
				local keyPos = (i % #key) + 1
				endStr[i] = char(((byte(sub(str, i, i)) + byte(sub(key, keyPos, keyPos)))%126) + 1)
			end

			endStr = table.concat(endStr)
			cache[key] = keyCache
			keyCache[str] = endStr

			return endStr
		end
	end;

	--// Decrypts a string encrypted with Utilities.Encrypt
	Decrypt = function(self, str: string, key: string, cache: {}?): string
		cache = cache or Cache.Decrypt

		if not key or not str then
			return str
		elseif cache[key] and cache[key][str] then
			return cache[key][str]
		else
			local keyCache = cache[key] or {}
			local byte = string.byte
			local sub = string.sub
			local char = string.char
			local endStr = {}

			for i = 1, #str do
				local keyPos = (i % #key)+1
				endStr[i] = char(((byte(sub(str, i, i)) - byte(sub(key, keyPos, keyPos)))%126) - 1)
			end

			endStr = table.concat(endStr)
			cache[key] = keyCache
			keyCache[str] = endStr

			return endStr
		end
	end;

	--// Advanced alternative to xpcall with multiple retry logic & post-success result processing
	Attempt = function(self, tries: number?, timeBeforeRetry: number?, func: (number)->any, errAction: (string)->any, sucessAction: (any)->any): (boolean, any)
		tries = tries or 3
		local triesMade = 0
		local success, result
		repeat
			triesMade += 1
			success, result = pcall(func, triesMade)
			if not success then task.wait(timeBeforeRetry or 0) end
		until success or triesMade >= tries
		if not success and errAction then
			result = errAction(result)
		elseif success and sucessAction then
			result = sucessAction(result)
		end
		return success, result
	end;

	--// Creates a new loop with specified delay.
	MakeLoop = function(self, exeDelay: number?, func: (number)->(), dontStart: boolean?)
		local loop = coroutine.wrap(function()
			local run = 0
			while task.wait(exeDelay or 0) do
				run += 1
				if func(run) then break end
			end
		end)
		if not dontStart then loop() end
		return loop
	end;

	--// Iterates through a table or an Instance's children, passing value-key pairs to the callback function
	--// Breaks if/when the callback returns, returning that value
	--// If third argument is true, the iteration will include all the table's subtables/Instance's descendants
	Iterate = function(self, tab: {any}|Instance, func: (any, number)->any, deep: boolean?): any?
		if deep and type(tab) == "table" then
			local function iterate(subtable)
				for ind, val in ipairs(subtable) do
					if type(val) == "table" then
						iterate(val)
					else
						local res = func(val, ind)
						if res then return res end
					end
				end
			end
			return iterate(tab)
		else
			for i, v in ipairs(if type(tab) == "table" then tab elseif deep then tab:GetDescendants() else tab:GetChildren()) do
				local res = func(v, i)
				if res then return res end
			end
		end
		return nil
	end;

	--// Runs the given function and outputs any errors
	RunFunction = function(self, Function, ...)
		return xpcall(Function, function(err)
			warn("Error while running function; Expand for more info", {Error = tostring(err), Raw = err})
		end, ...)
	end;

	--// Checks if a given object has the given property
	CheckProperty = function(self, obj: Instance, prop: string): (boolean, any)
		return pcall(PropertyCheck, obj, prop)
	end;

	--// Checks if the given object has been destroyed by looking for an error when attempting to change the object's parent
	--// Only suitable for instances with a parent property that can be changed
	IsDestroyed = function(self, object)
		if type(object) == "userdata" and self:CheckProperty(object, "Parent") then
			if object.Parent == nil then
				local ran,err = pcall(function() object.Parent = ParentTester object.Parent = nil end)
				if not ran then
					if err and string.match(err, "^The Parent property of .* is locked") then
						return true
					end
				end
			end
		end
		return false
	end;
}

--// Requires a given ModuleScript; If a function is returned immediately, run it
--// If a table is returned, assume deferred execution
local function LoadModule(Module: ModuleScript, ...)
	local ran,func = pcall(require, Module)
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
