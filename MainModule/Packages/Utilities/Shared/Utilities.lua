--[[

	Description: Various utility items and methods used by both the client and server.
	Author: Sceleratis
	Date: 12/04/2021

--]]

local Root = {}
local EventObjects = {}
local TrackedTasks = {}
local TaskSchedulers = {}
local CreatedItems = setmetatable({}, {__mode = "v"})
local Wrappers = setmetatable({}, {__mode = "kv"})
local ParentTester = Instance.new("Folder")

local function RandomString(): string
	return string.char(math.random(65, 90)) .. math.random(100000000, 999999999)
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
	},

	--// Task methods
	Task = {
		Trigger = function(self, ...)
			self.Event:Fire(...)
		end;

		Delete = function(self)
			if not self.Properties.Temporary then
				TaskSchedulers[self.Name] = nil
			end

			self.Running = false
			self.Event:Disconnect()
		end;
	},

	--// Instance wrapper methods
	Wrapper = {
		GetMetatable = function(self)
			return self.__NewMeta
		end;

		AddToCache = function(self)
			Wrappers[self.__Object] = self.__Proxy;
		end;

		RemoveFromCache = function(self)
			Wrappers[self.__Object] = nil
		end;

		GetObject = function(self)
			return self.__Object
		end;

		Clone = function(self, raw)
			local new = self.__Object:Clone()
			return
				if raw or not Root or not Root.Utilities or not Root.Utilities.Wrapping then
					new
				else
					Root.Utilities.Wrapping:Wrap(new)
		end;
	}
}


--// Tasks
local Tasks = table.freeze{
	TrackTask = function(self, name, func, ...)
		local index = RandomString()
		local isThread = string.sub(name, 1, 7) == "Thread:"

		local data = {
			Name = name;
			Status = "Waiting";
			Function = func;
			isThread = isThread;
			Created = os.time();
			Index = index;
		}

		local function taskFunc(...)
			TrackedTasks[index] = data
			data.Status = "Running"
			data.Returns = {pcall(func, ...)}

			if not data.Returns[1] then
				data.Status = "Errored"
			else
				data.Status = "Finished"
			end

			TrackedTasks[index] = nil
			return unpack(data.Returns)
		end

		if isThread then
			data.Thread = coroutine.create(taskFunc)
			return coroutine.resume(data.Thread, ...) --select(2, coroutine.resume(data.Thread, ...))
		else
			return taskFunc(...)
		end
	end;

	EventTask = function(self, name, func)
		local newTask = self.TrackTask
		return function(...)
			return newTask(name, func, ...)
		end
	end;

	GetTasks = function()
		return TrackedTasks
	end;

	TaskScheduler = function(self, taskName, props)
		local props = props or {}
		if not props.Temporary and TaskSchedulers[taskName] then return TaskSchedulers[taskName] end

		local new = {
			Name = taskName;
			Running = true;
			Properties = props;
			LinkedTasks = {};
			RunnerEvent = Instance.new("BindableEvent");
			Trigger = ObjectMethods.Task.Trigger;
			Delete = ObjectMethods.Task.Delete;
		}

		new.Event = new.RunnerEvent.Event:Connect(function(...)
			for i, v in pairs(new.LinkedTasks) do
				if select(2, pcall(v)) then
					table.remove(new.LinkedTasks, i);
				end
			end
		end)

		if props.Interval then
			while wait(props.Interval) and new.Running do
				new:Trigger(os.time())
			end
		end

		if not props.Temporary then
			TaskSchedulers[taskName] = new
		end

		return new
	end;
}


--// Wrapping
local Wrapping = {

	--// Determines equality between two objects with wrapper support
	RawEqual = function(self, obj1, obj2)
		return self:UnWrap(obj1) == self:UnWrap(obj2)
	end;

	--// Returns a metatable for the supplied table with __metatable set to "Ignore", indicating this should not be wrapped
	WrapIgnore = function(self, tab)
		return setmetatable(tab, {__metatable = "Ignore"})
	end;

	--// Returns true if the supplied object is a wrapper proxy object
	IsWrapped = function(self, object)
		return getmetatable(object) == "Adonis_Proxy"
	end;

	--// UnWraps the supplied object (if wrapped)
	UnWrap = function(self, object)
		local OBJ_Type = typeof(object)

		if OBJ_Type == "Instance" then
			return object
		elseif OBJ_Type == "table" then
			local UnWrap = self.UnWrap
			local tab = {}
			for i, v in pairs(object) do
				tab[i] = UnWrap(self, v)
			end
			return tab
		elseif self:IsWrapped(object) then
			return object:GetObject()
		else
			return object
		end
	end;

	--// Wraps the supplied object in a new proxy
	Wrap = function(self, object)
		if getmetatable(object) == "Ignore" or getmetatable(object) == "ReadOnly_Table" then
			return object
		elseif Wrappers[object] then
			return Wrappers[object]
		elseif type(object) == "table" then
			local Wrap = self.Wrap
			local tab = setmetatable({	}, {
				__eq = function(tab,val)
					return object
				end
			})

			for i,v in pairs(object) do
				tab[i] = Wrap(self, v)
			end

			return tab
		elseif (type(object) == "userdata") and not self:IsWrapped(object) then
			local newObj = newproxy(true)
			local newMeta = getmetatable(newObj)
			local custom; custom = {
				__NewMeta = newMeta,
				__Proxy = newObj,
				__Object = object,

				SetSpecial = function(self, name, val)
					custom[name] = val
					return self
				end;
			}

			for i,v in pairs(ObjectMethods.Wrapper) do
				custom[i] = v
			end

			newMeta.__index = function(tab, ind)
				local special = custom[ind]
				local target = if special then special else object[ind]

				if special then
					return special
				elseif type(target) == "function" then
					return function(self, ...)
						return target(self.__Object, ...)
					end
				else
					return target
				end
			end

			newMeta.__newindex = function(tab, ind, val)
				object[ind] = self:UnWrap(val)
			end

			newMeta.__eq = function(obj1, obj2) return self:RawEqual(obj1, obj2) end
			newMeta.__tostring = function() return custom.ToString or tostring(object) end
			newMeta.__metatable = "Adonis_Proxy"

			return newObj
		else
			return object
		end
	end;
}


--// Utilities
local Utilities = {
	Tasks = Tasks,
	Wrapping = Wrapping,
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

	CreateInstance = function(self, class: string, properties: {})
		local newObj = Instance.new(class)
		local connections = {}

		if properties then
			if typeof(properties) == "Instance" then
				newObj.Parent = properties
			elseif typeof(properties) == "table" then
				local parent = properties.Parent
				local events = properties.Events
				local children = properties.Children
				local attributes = properties.Attributes

				properties.Parent = nil
				properties.Events = nil
				properties.Children = nil
				properties.Attributes = nil

				self:EditInstance(newObj, properties)

				if children then
					for _, child in pairs(children) do
						child.Parent = newObj
					end
				end

				if attributes then
					for attrib, value in pairs(attributes) do
						newObj:SetAttribute(attrib, value)
					end
				end

				if parent then
					newObj.Parent = parent
				end

				if events then
					for event, func in pairs(events) do
						connections[event] = newObj[event]:Connect(func)
					end
				end
			end
		end

		return newObj, connections
	end,

	--// Modifies an Instance's properties according to the supplied dictionary
	EditInstance = function(self, object: Instance, properties: {[string]:any}?): Instance
		if properties then
			for prop, value in pairs(properties) do
				object[prop] = value
			end
		end
		return object
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
	--// Breaks if/when the callback returns truthy, returning that value
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
		xpcall(Function, function(err)
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
	end;
}
