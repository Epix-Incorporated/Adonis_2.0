--[[

	Description: Various utility items and methods used by both the client and server.
	Author: Sceleratis
	Date: 12/04/2021

--]]

local Root = {}
local EventObjects = {}
local TrackedTasks = {}
local TaskSchedulers = {}

local function RandomString(): string
	return string.char(math.random(65, 90)) .. math.random(100000000, 999999999)
end

--// Cache
local Cache = {
	KnownServices = {},
	Encrypt = {},
	Decrypt = {},
}

--// Methods
local ObjectMethods = {
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

	Task = {
		Trigger = function(self, ...)
			self.Event:Fire(...)
		end;

		Delete = function(self)
			if not self.Properties.Temporary then
				TaskSchedulers[self.Name] = nil;
			end

			self.Running = false;
			self.Event:Disconnect();
		end;
	}
}


--// Tasks
local Tasks = table.freeze{
	TrackTask = function(self, name, func, ...)
		local index = RandomString();
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
		local props = props or {};
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
			for i,v in pairs(new.LinkedTasks) do
				local ran,result = pcall(v);
				if result then
					table.remove(new.LinkedTasks, i);
				end
			end
		end)

		if props.Interval then
			while wait(props.Interval) and new.Running do
				new:Trigger(os.time());
			end
		end

		if not props.Temporary then
			TaskSchedulers[taskName] = new;
		end

		return new;
	end;
}


--// Utilities
local Utilities = {
	Tasks = Tasks,
	RandomString = RandomString,

	Services = table.freeze(setmetatable({}, {
		__index = function(self, ind)
			return Cache.KnownServices[ind] or game:GetService(ind);
		end,
	})),

	Events = table.freeze(setmetatable({},{
		__index = function(self, EventName)
			local methods = ObjectMethods.Event;
			return table.freeze {
				EventName = EventName;
				Fire = methods.Fire;
				Wait = methods.Wait;
				Connect = methods.Connect;
			}
		end
	})),

	CreateInstance = function(self, ClassName: string, Properties: Instance|{[string]:any}): Instance
		local newObj = Instance.new(ClassName);

		if Properties then
			if typeof(Properties) == "Instance" then
				newObj.Parent = Properties;
			elseif typeof(Properties) == "table" then
				local parent = Properties.Parent;
				local events = Properties.Events;
				local children = Properties.Children;

				Properties.Parent = nil;
				Properties.Events = nil;
				Properties.Children = nil;

				for prop,value in pairs(Properties) do
					newObj[prop] = value
				end

				if children then
					for i,child in pairs(children) do
						child.Parent = newObj;
					end
				end

				if parent then
					newObj.Parent = parent;
				end

				if events then
					for name,func in pairs(events) do
						newObj[name]:Connect(func);
					end
				end
			end
		end

		return newObj;
	end,

	IsServer = function(self): boolean
		return self.Services.RunService:IsServer();
	end,

	IsClient = function(self): boolean
		return self.Services.RunService:IsClient();
	end,

	GetTime = function(self): number
		return os.time();
	end,

	GetFormattedTime = function(self, optTime: number?, withDate: boolean?)
		local formatString = withDate and "L LT" or "LT"
		local tim = DateTime.fromUnixTimestamp(optTime or self.GetTime())

		if self:IsServer() then
			return tim:FormatUniversalTime(formatString, "en-gb") -- Always show UTC in 24 hour format
		else
			local locale = self.Services.Players.LocalPlayer.LocaleId
			local success, res = xpcall(function()
				return tim:FormatLocalTime(formatString, locale) -- Show in player's local timezone and format
			end, function()
				return tim:FormatLocalTime(formatString, "en-gb") -- show UTC in 24 hour format because player's local timezone is not available in DateTimeLocaleConfigs
			end)
			return res
		end
	end,

	AddRange = function(self, tab, ...)
		for i,t in ipairs(table.pack(...)) do
			for k,v in ipairs(t) do
				table.insert(tab, v)
			end
		end

		return tab;
	end,

	MergeTables = function(self, tab, ...)
		for i,t in ipairs(table.pack(...)) do
			for k,v in pairs(t) do
				tab[k] = v
			end
		end

		return tab;
	end,

	CountTable = function(tab: {}, excludeNumIndices: boolean?): number
		local n = 0
		for i, v in pairs(tab) do
			if (not excludeNumIndices) or type(i) ~= "number" then
				n += 1
			end
		end
		return n
	end,

	ReverseTable = function(array: {[number]:any}): {[number]:any}
		local len: number = #array
		local reversed = {}
		for i = 1, len do
			reversed[len-i] = array[i]
		end
		return reversed
	end,

	Encrypt = function(self, str, key, cache)
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

	Decrypt = function(self, str, key, cache)
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

	Attempt = function(self, tries: number?, func: (number)->any, errAction: (any)->any, sucessAction: (any)->any, timeBeforeRetry: number?): (boolean, any)
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
}


return table.freeze {
	Init = function(Root, Package)
		if Root.Utilities then
			for ind, val in pairs(Utilities) do
				Root.Utilities[ind] = val
			end
		else
			Root.Utilities = Utilities;
		end

		Root.Events = Utilities.Events;
		Root.Services = Utilities.Services;
	end;
}
