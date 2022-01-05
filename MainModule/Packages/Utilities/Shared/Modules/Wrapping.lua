--[[

	Description: Wrapping utilities
	Author: Sceleratis
	Date: 12/04/2021

--]]

local Root, Utilities

local CreatedItems = setmetatable({}, {__mode = "v"})
local Wrappers = setmetatable({}, {__mode = "kv"})
local ObjectMethods = {

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
	},
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

return table.freeze {
	Init = function(cRoot, cUtilities)
		Root = cRoot
		Utilities = cUtilities
		Utilities.Wrapping = Wrapping
	end;
}
