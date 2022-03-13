--[[

	Description: Wrapping methods and handlers.
	Author: Sceleratis
	Date: 12/04/2021

--]]

local Root, Utilities

local CreatedItems = setmetatable({}, {__mode = "v"})
local Wrappers = setmetatable({}, {__mode = "kv"})
local ObjectMethods = { Wrapper = {	} }
local Wrapping = { }


--//// Class definitions

--- Wrapped object proxy.
--- @class Wrapper
--- @server
--- @client
--- @tag Utilities
--- @tag Package: System.Utilities

--- Proxy metatable
--- @prop __NewMeta metatable
--- @within Wrapper

--- Proxy object.
--- @prop __Proxy userdata
--- @within Wrapper

--- Original object.
--- @prop __Object userdata
--- @within Wrapper


--- Creates/sets special methods and properties for the wrapped object.
--- @method SetSpecial
--- @within Wrapper
--- @param name string -- Property/method name.
--- @param val any -- Property/method value.


--- Responsible for userdata wrapping functionality.
--- @class Utilities.Wrapping
--- @server
--- @client
--- @tag Utilities
--- @tag Package: System.Utilities


--//// Wrapper methods


--- Returns Wrapper's metatable
--- @method GetMetatable
--- @within Wrapper
--- @return metatable
function ObjectMethods.Wrapper.GetMetatable(self)
	return self.__NewMeta
end


--- Caches the wrapper and object so subsequent wraps for the same object will return the same wrapper.
--- @method AddToCache
--- @within Wrapper
function ObjectMethods.Wrapper.AddToCache(self)
	Wrappers[self.__Object] = self.__Proxy;
end


--- Removes the wrapper and object from the wrapping cache. Subsequent wraps on the same object will return a new wrapper.
--- @method RemoveFromCache
--- @within Wrapper
function ObjectMethods.Wrapper.RemoveFromCache(self)
	Wrappers[self.__Object] = nil
end



--- Returns the original object associated with this Wrapper.
--- @method GetObject
--- @within Wrapper
--- @return userdata
function ObjectMethods.Wrapper.GetObject(self)
	return self.__Object
end


--- Clones the wrapped object and returns a wrapped version of the clone.
--- @method Clone
--- @within Wrapper
--- @param raw boolean -- If true, returns an unwrapped clone.
--- @return Wrapper|userdata
function ObjectMethods.Wrapper.Clone(self, raw)
	local new = self.__Object:Clone()
	return if raw or not Root or not Root.Utilities or not Root.Utilities.Wrapping then new else Root.Utilities.Wrapping:Wrap(new)
end


--//// Utilities.Wrapping methods

--- Determines equality between two objects with wrapper support.
--- @method RawEqual
--- @within Utilities.Wrapping
--- @param obj1 userdata -- Comparison Object A
--- @param obj2 userdata -- Comparison Object B
--- @return boolean
function Wrapping.RawEqual(self, obj1, obj2)
	return self:UnWrap(obj1) == self:UnWrap(obj2)
end


--- Returns a metatable for the supplied table with __metatable set to "Ignore", indicating this should not be wrapped.
--- @method WrapIgnore
--- @within Utilities.Wrapping
--- @param tab {} -- Table to ignore wrapping for.
--- @return {}
function Wrapping.WrapIgnore(self, tab)
	return setmetatable(tab, {__metatable = "Ignore"})
end


--- Returns true if the supplied object is a wrapper proxy object.
--- @method IsWrapped
--- @within Utilities.Wrapping
--- @param object userdata -- Object to check for wrapping
--- @return boolean
function Wrapping.IsWrapped(self, object)
	return getmetatable(object) == "Adonis_Proxy"
end


--- If the supplied object or table is wrapped, returns the original object the wrapper was created for. If the object is not wrapped it will be returned unchanged.
--- @method UnWrap
--- @within Utilities.Wrapping
--- @param object userdata -- Object or table to unwrap.
--- @return userdata
function Wrapping.UnWrap(self, object)
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
end


--- Wraps the supplied object in a new proxy.
--- @method Wrap
--- @within Utilities.Wrapping
--- @param object userdata -- Object or table to wrap.
--- @return Wrapper
function Wrapping.Wrap(self, object)
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
end



--//// Return initializer.
return table.freeze {
	Init = function(cRoot, cUtilities)
		Root = cRoot
		Utilities = cUtilities
		Utilities.Wrapping = Wrapping
	end;
}
