--[[

	Description: Various uncategorized utility methods.
	Author: Sceleratis
	Date: 1/8/2022

--]]

local Root
local Queues = {}
local Utilities = {}
local RateLimits = {}
local ParentTester = Instance.new("Folder")
local __RANDOM_CHARSET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

local function PropertyCheck(obj, prop): any
	return obj[prop]
end

--// Cache
local Cache = {
	KnownServices = {},
	Encrypt = {},
	Decrypt = {},
}


--// Misc Helper Methods

--- Generates a random string
--- @method RandomString
--- @within Utilities
--- @param len int -- String length
--- @param charset string -- Character set to use for random generation
--- @return string
function Utilities.RandomString(self, len: number, charset: string): string
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

--- Uses a bindable event to yield execution until the event is fired/released.
--- @class Waiter
--- @server
--- @client
--- @tag Utilities
--- @tag Package: System.Utilities

--- BindableEvent used by Waiter
--- @prop Event BindableEvent
--- @within Waiter

--- Releases any threads yielded using this Waiter object.
--- @method Release
--- @within Waiter
--- @param ... any

--- Yields execution until Waiter:Release() is called.
--- @method Wait
--- @within Waiter
--- @param ... any
--- @yields
--- @return any -- Data passed via :Release(...)

--- Destroys the underlying BindableEvent
--- @method Destroy
--- @within Waiter


--- Uses a BindableEvent to yield/release a calling thread
--- @method Waiter
--- @within Utilities
--- @return Waiter
function Utilities.Waiter(self)
	return {
		Event = Instance.new("BindableEvent");
		Release = function(self, ...) self.Event:Fire(...) end;
		Wait = function(self, ...) return self.Event.Event:Wait(...) end;
		Destroy = function(self) self.Event:Destroy() end;
	}
end


--- Removes the first element from a table and returns it.
--- @method Pop
--- @within Utilities
--- @param tab {}
--- @return any
function Utilities.Pop(self, tab)
	return table.remove(tab, 1)
end


--- Queues up a function to run
--- @method Queue
--- @within Utilities
--- @param key string
--- @param func function -- Function to queue
--- @param noYield bool -- If this is true, this will not yield until queued function execution is complete
--- @return any -- Function results
--- @yields
function Utilities.Queue(self, key: string, func, noYield)
	if not Queues[key] then
		Queues[key] = {
			Processing = false;
			Active = {};
		}
	end

	local queue = Queues[key]
	local tab = {
		Time = os.time();
		Running = false;
		Finished = false;
		Function = func;
		Waiter = noYield ~= true and self:Waiter();
	}

	table.insert(queue.Active, tab);

	if not queue.Processing then
		self.Tasks:NewTask("Thread: QueueProcessor_"..tostring(key), self.ProcessQueue, self, queue, key);
	end

	if not noYield and not tab.Finished then
		return select(2, tab.Waiter:Wait());
	end
end


--- Handles per-queue processing when a new function is added to a queue.
--- @method ProcessQueue
--- @within Utilities
--- @param queue {} -- Queue table
--- @param key string -- Queue key
function Utilities.ProcessQueue(self, queue: {}, key: string)
	if queue then
		if queue.Processing then
			return "Processing"
		else
			queue.Processing = true

			local funcs = queue.Active;
			while funcs[1] ~= nil do
				local func = self:Pop(funcs);
				func.Running = true;

				local r,e = pcall(func.Function);

				if not r then
					func.Error = e;
					Utilities.Warn("Queue Error: ".. tostring(key) .. ": ".. tostring(e))
				end

				func.Running = false;
				func.Finished = true

				if func.Waiter then
					func.Waiter:Release(r, e)
				end
			end

			if key then
				Queues[key] = nil;
			end

			queue.Processing = false;
		end
	end
end


--- RateLimit Options
--- @interface RateLimitOptions
--- @within Utilities
--- @field Cache {} -- Optional table to use for rate limit caching
--- @field Timeout int -- Rate limit timeout value (how much time should there be between calls?)

--- Provided a key, tracks the last time this method was called with that key and will return true on a subsequent call if the time between now and the last call tick is less than the specified timeout value.
--- @method RateLimit
--- @within Utilities
--- @param key string -- Rate limit key
--- @param data RateLimitOptions
--- @return bool
function Utilities.RateLimit(self, key: string, data: {})
	local cache = data.Cache or RateLimits
	local found = cache[key]

	if found then
		if tick() - found.Tick < (data.Timeout or found.Timeout) then
			return true
		else
			found.Tick = tick()
			return false
		end
	else
		cache[key] = {
			Tick = tick(),
			Timeout = data.Timeout or 0
		}

		return false
	end
end


--- Modifies an Instance's properties & other data according to the supplied dictionary.
--- Supports the following special entries in the provided properties table:
--- Events {} (EventName = FunctionToConnect),
--- Children {} (Property tables describing children to generate),
--- Attributes {} (AttributeName = AttributeValue)
--- @method EditInstance
--- @within Utilities
--- @param object Instance
--- @param properties {[string]:any}?): (Instance, {[string]:RBXScriptConnection}
--- @return Instance
function Utilities.EditInstance(self, object: Instance, properties: {[string]:any}?): (Instance, {[string]:RBXScriptConnection})
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
end


--- Creates a new instance and calls Utilities:EditInstance on it with the provided properties table.
--- @method CreateInstance
--- @within Utilities
--- @param class string -- Instance ClassName
--- @param properties {} -- Instance properties
--- @return Instance
function Utilities.CreateInstance(self, class: string, properties: {})
	return self:EditInstance(Instance.new(class), properties)
end


--- Returns true if this is running on the server.
--- @method IsServer
--- @within Utilities
--- @return boolean
function Utilities.IsServer(self): boolean
	return self.Services.RunService:IsServer()
end


--- Returns true if this is running on the client.
--- @method IsClient
--- @within Utilities
--- @return boolean
function Utilities.IsClient(self): boolean
	return self.Services.RunService:IsClient()
end


--- Returns true if this is running in studio.
--- @method IsStudio
--- @within Utilities
--- @return boolean
function Utilities.IsStudio(self): boolean
	return self.Services.RunService:IsStudio()
end


--- Returns os.time()
--- @method GetTime
--- @within Utilities
--- @return number
function Utilities.GetTime(self): number
	return os.time()
end


--- Returns a formatted time or datetime string.
--- @method GetFormattedTime
--- @within Utilities
--- @param optTime number -- Optional seconds since epoch
--- @param withDate boolean -- If true, output string includes date
--- @return string
function Utilities.GetFormattedTime(self, optTime: number?, withDate: boolean?): string
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
end


--- Returns a formatted string of the provided number; Ex: 1000000.124 -> "1,000,000.124"
--- @method FormatNumber
--- @within Utilities
--- @param num number
--- @param string separator -- Optional; defaults to ","
--- @return string
function Utilities.FormatNumber(self, num: number?, separator: string?): string
	num = tonumber(num)
	if not num then return "NaN" end
	if num >= 1e150 then return "Inf" end

	local int, dec = unpack(tostring(num):split("."))

	int = int:reverse()
	local new = ""
	local counter = 1
	separator = separator or ","
	for i = 1, #int do
		if counter > 3 then
			new ..= separator
			counter = 1
		end
		new ..= int:sub(i, i)
		counter += 1
	end

	return new:reverse() .. if dec then "."..dec else ""
end


--- Formats a Player's name as such: 'Username (@DisplayName)' or '@UserEqualsDisplayName'.
--- Optionally appends the player's UserId in square brackets.
--- @method FormatPlayer
--- @within Utilities
--- @param plr Player
--- @param withUserId boolean
--- @return string
function Utilities.FormatPlayer(self, plr: Player, withUserId: boolean?): string
	local str = if plr.DisplayName == plr.Name then "@"..plr.Name else string.format("%s (@%s)", plr.DisplayName, plr.Name)
	if withUserId then str ..= string.format(" [%d]", plr.UserId) end
	return str
end


--- Escapes RichText tags in the provided string.
--- @method FormatStringForRichText
--- @within Utilities
--- @param str string -- Input string
--- @return string
function Utilities.FormatStringForRichText(self, str: string): string
	return str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\"", "&quot;"):gsub("'", "&apos;")
end


--- Inserts elements from supplied ordered tables into the first table.
--- @method AddRange
--- @within Utilities
--- @param tab {} -- Table to insert subsequent table contents into
--- @param ... {} -- Ordered tables whos contents will be inserted into the first table
--- @return tab
function Utilities.AddRange(self, tab, ...)
	for i,t in ipairs(table.pack(...)) do
		for k,v in ipairs(t) do
			table.insert(tab, v)
		end
	end

	return tab
end


--- Given an ordered table, returns a subset of that table.
--- @method TableSub
--- @within Utilities
--- @param tab {}
--- @param startPos number
--- @param endPos number -- Optional
--- @return subset
function Utilities.TableSub(self, tab: {}, startPos: number, endPos: number?)
	return table.pack(table.unpack(tab, startPos, endPos))
end


--- Removes excess whitespace from strings.
--- @method Trim
--- @within Utilities
--- @param str string
--- @return string
function Utilities.Trim(self, str: string)
	return string.match(str, "^%s*(.-)%s*$")
end


--- Splits a string into multiple sub-strings, splitting at SplitChar; Ignores split characters surrounded by double or single quotes.
--- @method ReplaceCharacters
--- @within Utilities
--- @param str string
--- @param chars {}
--- @param replaceWith string
--- @return string
function Utilities.ReplaceCharacters(self, str: string, chars: {}, replaceWith: string?)
	for i, char in ipairs(chars) do
		str = string.gsub(str, char, replaceWith or "")
	end
	return str
end


--- Removes quotations surrounding text.
--- @method RemoveQuotes
--- @within Utilities
--- @param str string
--- @return string
function Utilities.RemoveQuotes(self, str: string)
	return self:ReplaceCharacters(str, {'^"(.+)"$', "^'(.+)'$"}, "%1")
end


--- Splits the provided string while respecting content within quotations.
--- @method SplitString
--- @within Utilities
--- @param str string -- Input string
--- @param splitChar string -- Split character
--- @param removeQuotes boolean -- If true, substrings surrounded by quotes will have their quotation marks removed in the output string
--- @return string
function Utilities.SplitString(self, str: string, splitChar: string, removeQuotes: boolean)
	local segments = {}
	local sentinel = string.char(0)
	local function doSplitSentinelCheck(x: string) return string.gsub(x, splitChar, sentinel) end
	local quoteSafe = self:ReplaceCharacters(str, {'%b""', "%b''"}, doSplitSentinelCheck)
	for segment in string.gmatch(quoteSafe, "([^".. splitChar .."]+)") do
		local result = self:Trim(string.gsub(segment, sentinel, splitChar))
		if removeQuotes then
			result = self:RemoveQuotes(result)
		end
		table.insert(segments, result)
	end
	return segments
end


--- Joins strings together using the join character provided.
--- @method JoinStrings
--- @within Utilities
--- @param joiner string -- String inserted between joined strings
--- @param ... string[] -- Strings to join
--- @return string
function Utilities.JoinStrings(self, joiner: string?, ...)
	local result = nil
	local strList = table.pack(...)
	for i, str in ipairs(strList) do
		if not result then
			result = str
		else
			result ..= joiner .. str
		end
	end
	return result or ""
end


--- Merges tables into the first table.
--- Each subsequent table will overwrite keys in/from the tables that came before it.
--- @method MergeTables
--- @within Utilities
--- @param tab {} -- Table to merge subsequent tables into
--- @param ... {} -- Tables to merge into the first table; Each subsequent table overwrites keys set by previous tables
--- @return tab
function Utilities.MergeTables(self, tab, ...)
	for i,t in ipairs(table.pack(...)) do
		for k,v in pairs(t) do
			tab[k] = v
		end
	end
	return tab
end


--- Same as MergeTables, but also calls itself when overriting one table with another.
--- @method MergeTablesRecursive
--- @within Utilities
--- @param tab {} -- Table to merge into
--- @param ... {} -- Tables to merge from
--- @return tab
function Utilities.MergeTablesRecursive(self, tab, ...)
	for _, t in ipairs(table.pack(...)) do
		for k,v in pairs(t) do
			if tab[k] ~= nil and type(v) == "table" and type(tab[k]) == "table" then
				tab[k] = self:MergeTablesRecursive(tab[k], v)
			else
				tab[k] = v
			end
		end
	end
	return tab
end


--- Returns the number of elements in a given table.
--- @method CountTable
--- @within Utilities
--- @param tab {[any]:any}
--- @param excludeNumIndices boolean -- Exclude non-string indeces
--- @return number
function Utilities.CountTable(tab: {[any]:any}, excludeNumIndices: boolean?): number
	local n = 0
	for i, v in pairs(tab) do
		if not excludeNumIndices or type(i) ~= "number" then
			n += 1
		end
	end
	return n
end


--- Reverses the supplied ordered table.
--- @method ReverseTable
--- @within Utilities
--- @param array {[number]:any})
--- @return {[number]:any}
function Utilities.ReverseTable(array: {[number]:any}): {[number]:any}
	local len: number = #array
	local reversed = {}
	for i = 1, len do
		reversed[len-i] = array[i]
	end
	return reversed
end


--- Weak encryption used mainly for basic trust checks and remote event communication. Should not be relied on to secure sensitive data.
--- @method Encrypt
--- @within Utilities
--- @param str string -- Input string
--- @param key string -- Key
--- @param cache {}? -- Optional cache table used to speed up future calls by storing inputs used to generate outputs
--- @return string
function Utilities.Encrypt(self, str: string, key: string, cache: {}?): string
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
end


--- Decrypts a string encrypted with Utilities:Encrypt(...)
--- @method Decrypt
--- @within Utilities
--- @param str string
--- @param key string
--- @param cache {}?
--- @return string
function Utilities.Decrypt(self, str: string, key: string, cache: {}?): string
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
end


--- Returns true if either (and only either) A or B is truthy
--- @method Xor
--- @within Utilities
--- @param a boolean
--- @param b boolean
--- @return boolean
function Utilities.Xor(self, a, b): boolean
	return (a and not b) or (b and not a)
end


--- Advanced alternative to xpcall with multiple retry logic.
--- @method Attempt
--- @within Utilities
--- @param tries number
--- @param timeBeforeRetry number
--- @param func function
--- @param errAction function(result string)
--- @return boolean, any
function Utilities.Attempt(self, tries: number?, timeBeforeRetry: number?, func: (number)->any, errAction: (string)->any): (boolean, any)
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
	end
	return success, result
end


--- Creates a new loop with a specified delay between executions.
--- The loop is broken if and when the function being executed returns truthy.
--- @method MakeLoop
--- @within Utilities
--- @param exeDelay number?
--- @param func function
--- @param dontStart boolean?
function Utilities.MakeLoop(self, exeDelay: number?, func: (number)->(), dontStart: boolean?)
	local loop = coroutine.wrap(function()
		local run = 0
		while task.wait(exeDelay or 0) do
			run += 1
			if func(run) then break end
		end
	end)
	if not dontStart then loop() end
	return loop
end


--- Given an ordered list of items and a desired batch size, breaks the given list into smaller batches of size.
--- @method Batchify
--- @within Utilities
--- @param tab {} -- Input table
--- @param size int -- Batch size
--- @return {int: {}}
function Utilities.Batchify(self, tab, size)
	local batches = {}
	for b = 1, table.getn(tab), size do
		local batch = {}
		for i = b, b + size-1 do
			local item = tab[i]
			if item then
				table.insert(batch, item)
			else
				break
			end
		end
		table.insert(batches, batch)
	end
	return batches
end


--- Iterates through a table or an Instance's children, passing value-key pairs to the callback function.
--- Breaks if/when the callback returns, returning that value.
--- If third argument is true, the iteration will include all the table's subtables/Instance's descendants.
--- @method Iterate
--- @within Utilities
--- @param tab {any}|Instance
--- @param func (any, number)->any
--- @param deep boolean?
--- @return any?
function Utilities.Iterate(self, tab: {any}|Instance, func: (any, number)->any, deep: boolean?): any?
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
end


--- Safely checks if a given object has the given property.
--- @method CheckProperty
--- @within Utilities
--- @param obj Instance
--- @param prop string
--- @return (boolean, any)
function Utilities.CheckProperty(self, obj: Instance, prop: string): (boolean, any)
	return pcall(PropertyCheck, obj, prop)
end;


--- Checks if the given object has been destroyed by looking for an error when attempting to change the object's parent.
--- Only suitable for instances with a parent property that can be changed.
--- @method IsDestroyed
--- @within Utilities
--- @param object Instance
--- @return boolean
function Utilities.IsDestroyed(self, object)
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
end


--- Creates a newproxy object with the provided metatable.
--- @method NewProxy
--- @within Utilities
--- @param meta {}
--- @return proxy
function Utilities.NewProxy(self, meta: {})
	local newProxy = newproxy(true)
	local metatable = getmetatable(newProxy)
	metatable.__metatable = false
	for i,v in pairs(meta) do metatable[i] = v end
	return newProxy
end


--- Wraps a function in a NewProxy metatable. This allows it to act like a function however cannot be used as an argument to env manipulation functions.
--- @method FunctionProxy
--- @within Utilities
--- @param func function
--- @return proxy
function Utilities.FunctionProxy(self, func)
	return self:NewProxy({
		__call = function(tab, ...)
			return func(...)
		end
	})
end


--- Creates a new fake player object which can be used as a stand-in for most player-related needs.
--- @method FakePlayer
--- @within Utilities
--- @param plrData {} -- FakePlayer properties
--- @return object
function Utilities.FakePlayer(self, plrData: {})
	local fakePlayer = self.Wrapping:Wrap(self:CreateInstance("Folder", {
		Name = plrData.Name
	}))

	for prop, val in pairs({
		DisplayName = plrData.DisplayName or plrData.Name; --// note: UserService:GetUserInfosByUserIdsAsync() exists
		ToString = plrData.Name;
		ClassName = "Player";
		AccountAge = 0;
		CharacterAppearanceId = plrData.UserId or -1;
		UserId = plrData.UserId or -1;
		userId = plrData.UserId or -1;
		Parent = self.Services.Players;
		Character = Instance.new("Model");
		Backpack = Instance.new("Folder");
		PlayerGui = Instance.new("Folder");
		PlayerScripts = Instance.new("Folder");
		Kick = function() fakePlayer:Destroy() fakePlayer:SetSpecial("Parent", nil) end;
		IsA = function(ignore, arg) if arg == "Player" then return true end end;
	}) do fakePlayer:SetSpecial(prop, val) end

	return fakePlayer
end

--- Returned by Utilities:GetTableValueByPath(...)
--- @interface TablePathReturn
--- @within Utilities
--- @field Table {} -- Destination value nested parent table (Settings in Root.Settings.UI_Colors)
--- @field Index string -- Destination index in nested parent table
--- @field Value any -- Destination value

--- Given a table, a path string, and an optional ancestry split character, nagivates through the table to the location specified by the provided path string.
--- @method GetTableValueByPath
--- @within Utilities
--- @param table {}
--- @param tableAncestry string -- Path string (For example, "Settings.UI_Colors" with Root as the table will navigate to Root.Settings.UI_Colors)
--- @param splitChara string --- Path split character (Defaults to '.')
--- @return TablePathReturn
function Utilities.GetTableValueByPath(self, table: {[any]:any}, tableAncestry: string, splitChar: string): {[string]: any}
	local indexNames = self:SplitString(tableAncestry, splitChar or '.', true)
	local curTable = table

	for i,index in ipairs(indexNames) do
		local val = curTable[index]
		if i == #indexNames then
			return {
				Table = curTable,
				Index = index,
				Value = val,
			}
		elseif type(val) == "table" then
			curTable = val
		else
			Root.Warn("Invalid path:", tableAncestry)
		end
	end
end


--- Compares two tables for equality.
--- @method CheckTableEquality
--- @within Utilities
--- @param tab1 {}
--- @param tab2 {}
--- @param noRecursive boolean -- If true, recursively checks all nested tables for equality
--- @return boolean
function Utilities.CheckTableEquality(self, tab1: {[any]:any}, tab2: {[any]:any}, noRecursive: boolean): boolean
	if type(tab1) == "table" and type(tab2) == "table" and #tab1 == #tab2 then
		for index, value in pairs(tab1) do
			local target = tab2[index]
			if target and typeof(value) == typeof(target) then
				if type(value) == "table" then
					if not noRecursive and not self:CheckTableEquality(value, target, noRecursive) then
						return false
					end
				elseif type(value) ~= "function" then
					if value ~= target then
						return false
					end
				end
			else
				return false
			end
		end
		return true
	else
		return false
	end
end


--- JSON encodes provided data.
--- @method JSONEncode
--- @within Utilities
--- @param data any
--- @return string
function Utilities.JSONEncode(self, data: any): string
	return self.Services.HttpService:JSONEncode(data)
end


--- JSON decodes provided string.
--- @method JSONDecode
--- @within Utilities
--- @param data string
--- @return any
function Utilities.JSONDecode(self, data: string): any
	return self.Services.HttpService:JSONDecode(data)
end



--// Init
return {
	Init = function(cRoot, cUtilities)
		Root = cRoot

		--// Merge helper methods Utilities table into the main Utilities table (cUtilities variable here)
		Utilities:MergeTables(cUtilities, Utilities)

		--// Overwrite helper methods Utilities table with the actual Utilities table
		Utilities = cUtilities
	end;
}
