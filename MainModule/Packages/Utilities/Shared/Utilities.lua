--[[

	Description: Various utility items and methods used by both the client and server.
	Author: Sceleratis
	Date: 12/04/2021
	
--]]

local Root = {}
local EventObjects = {}
local TrackedTasks = {}
local TaskSchedulers = {}

local function RandomString()
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
	
	CreateInstance = function(self, ClassName, Properties)
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
	
	IsServer = function(self)
		return self.Services.RunService:IsServer();
	end,
	
	GetTime = function(self)
		return os.time();
	end,

	GetFormattedTime = function(self, optTime, withDate)
		local formatString = withDate and "L LT" or "LT"
		local tim = DateTime.fromUnixTimestamp(optTime or self.GetTime())
		
		if self:IsServer() then
			return tim:FormatUniversalTime(formatString, "en-gb") -- Always show UTC in 24 hour format
		else
			local locale = self.Services.Players.LocalPlayer.LocaleId
			local succes,err = pcall(function()
				return tim:FormatLocalTime(formatString, locale) -- Show in player's local timezone and format
			end)
			
			if err then
				return tim:FormatLocalTime(formatString, "en-gb") -- show UTC in 24 hour format because player's local timezone is not available in DateTimeLocaleConfigs
			end
		end
	end,
	
	AddRange = function(self, tab, ...)
		table.foreachi(table.pack(...), function(i,t)
			table.foreachi(t, function(k,v)
				table.insert(tab, v)
			end)
		end)
		
		return tab;
	end,
	
	MergeTables = function(self, tab, ...)
		table.foreachi(table.pack(...), function(i,t)
			table.foreachi(t, function(k,v)
				tab[k] = v
			end)
		end)

		return tab;
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