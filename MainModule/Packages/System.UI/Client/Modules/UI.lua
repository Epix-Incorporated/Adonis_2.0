--[[

	Description: Responsible for UI
	Author: Sceleratis
	Date: 12/18/2021

--]]


local Root, Utilities, Service, Package;

local RemoteCommands = {
	UI_LoadModule = function(data, ...)
		Root.DebugWarn("LOAD UI MODULE", data, ...)
		return Root.UI:LoadModule(data, ...);
	end;
}

local Methods = {
}

local UI = {
	DeclaredModules = {};
	DeclaredPrefabs = {};

	DeclarePrefabGroup = function(self, groupData)
		local groupName = groupData.Name;

		if self.DeclaredPrefabs[groupName] then
			Root.Warn("Prefab group already declared. Overwriting group:", groupName);
			Utilities.Events.UIWarning:Fire("Overwriting existing prefab group", groupName);
		end

		self.DeclaredPrefabs[groupName] = {
			Name = groupName,
			Fallback = groupData.Fallback,
			GroupData = groupData,
			Prefabs = {}
		}

		Utilities.Events.UI_DeclaredPrefabGroup:Fire(groupData)
	end,

	DeclareModuleGroup = function(self, groupData)
		local groupName = groupData.Name;

		if self.DeclaredModules[groupName] then
			Root.Warn("Prefab group already declared. Overwriting group:", groupName);
			Utilities.Events.UIWarning:Fire("Overwriting existing prefab group", groupName);
		end

		self.DeclaredModules[groupName] = {
			Name = groupName,
			Fallback = groupData.Fallback,
			GroupData = groupData,
			Modules = {}
		}

		Utilities.Events.UI_DeclaredModuleGroup:Fire(groupData)
	end,

	DeclarePrefab = function(self, groupName, name, prefab)
		if not self.DeclaredPrefabs[groupName] then
			self.DeclaredPrefabs[groupName] = {
				Name = groupName,
				Prefabs = {}
			}
		end

		if self.DeclaredPrefabs[groupName].Prefabs[name] then
			Root.Warn("Prefab for group already declared. Overwriting. Prefab Name:", name, "| Group Name:", groupName);
			Utilities.Events.UIWarning:Fire("Overwriting existing prefab", name, groupName);
		end

		self.DeclaredPrefabs[groupName].Prefabs[name] = prefab

		Utilities.Events.UI_DeclaredPrefab:Fire(groupName, name, prefab)
	end;

	DeclareModule = function(self, groupName, name, module)
		if not self.DeclaredModules[groupName] then
			self.DeclaredModules[groupName] = {
				Name = groupName,
				Modules = {}
			}
		end

		if self.DeclaredModules[groupName].Modules[name] then
			Root.Warn("UI module for group already declared. Overwriting. Module Name:", name, "| Group Name:", groupName);
			Utilities.Events.UIWarning:Fire("Overwriting existing UI module", name, groupName);
		end

		self.DeclaredModules[groupName].Modules[name] = module

		Utilities.Events.UI_DeclaredModule:Fire(groupName, name, module)
	end;

	GetPrefab = function(self, prefabName, groupName)
		local defaultGroup = self.DecalredPrefabs.Default
		local prefabGroupName = groupName or Root.Globals.UI_PrefabGroupOverride or self.CachedPrefabGroup or Root.Settings.UI_PrefabGroup
		local prefabGroup = self.DeclaredPrefabs[groupName] or defaultGroup
		local fallbackGroupName = prefabGroup.Fallback
		local fallbackGroup = if fallbackGroupName then self.DeclaredPrefabs[fallbackGroupName] else nil

		Root.DebugWarn("GETTING PREFAB", prefabName, groupName)

		if prefabGroup then
			local found = prefabGroup.Prefabs[prefabName] or (fallbackGroup and fallbackGroup.Prefabs[prefabName]) or (defaultGroup and defaultGroup.Prefabs[prefabName])

			if found then
				local prefab = found:Clone()
				local controller = prefab:FindFirstChild("Controller")
				local interface = if controller then controller:FindFirstChild("Interface") else nil

				if prefab:IsA("ScreenGui") then
					self:Tag(prefab)
				end

				return (interface and require(interface)) or {
					Prefab = prefab,
					Controller = controller
				}
			else
				Root.Warn("UI prefab not found! prefab:", prefabName, " | Group:", groupName);
				Utilities.Events.UIWarning:Fire("Prefab not found", prefabName, groupName);
			end
		else
			Root.Warn("No UI prefab group found! Prefab:", prefabName, " | Group:", groupName);
			Utilities.Events.UIWarning:Fire("Prefab group not found", prefabName, groupName);
		end
	end;

	GetModule = function(self, moduleName, groupName)
		local defaultGroup = self.DeclaredModules.Default
		local moduleGroupName = groupName or Root.Globals.UI_ModuleGroupOverride or self.CachedModuleGroup or Root.Settings.UI_ModuleGroup
		local moduleGroup = self.DeclaredModules[groupName] or defaultGroup
		local fallbackGroupName = moduleGroup.Fallback
		local fallbackGroup = if fallbackGroupName then self.DeclaredModules[fallbackGroupName] else nil

		Root.DebugWarn("GETTING UI MODULE", moduleName, groupName)

		if moduleGroup then
			local found = moduleGroup.Modules[moduleName] or (fallbackGroup and fallbackGroup.Modules[moduleName]) or (defaultGroup and defaultGroup.Modules[moduleName])

			if found then
				return found
			else
				Root.Warn("UI module not found! Module:", moduleName, " | Group:", groupName);
				Utilities.Events.UIWarning:Fire("Module not found", moduleName, groupName);
			end
		else
			Root.Warn("No UI module group found! Module:", moduleName, " | Group:", groupName);
			Utilities.Events.UIWarning:Fire("Module group not found", moduleName, groupName);
		end
	end;

	LoadModule = function(self, moduleData, ...)
		local module = self:GetModule(moduleData.Name, moduleData.Group)
		if module then
			Root.DebugWarn("REQUIRING UI MODULE", moduleData)
			local handler = require(module)
			if handler and type(handler) == "table" and handler.LoadModule then
				Root.DebugWarn("LOADING UI MODULE", moduleData)
				Utilities.Events.UI_LoadingModule:Fire(moduleData, module, ...)
				return handler:LoadModule(Root, moduleData, ...)
			end
		end
	end;

	--// Finds any objects in PlayerGui that have the UI attribute tag
	FindElements = function(self, name, ignore, returnOne)
		local found = {}
		for i, child in ipairs(self:GetPlayerGui():GetDescendants()) do
			if child ~= ignore and child.Name ~= ignore then
				local attribute = child:GetAttribute("ADONIS_UI")
				if attribute and (child.Name == name or attribute == name) then
					if returnOne then
						return child
					else
						found[attribute or child.Name] = child
					end
				end
			end
		end
		return found
	end;

	--// Adds an attribute to the specified object indicating that this is an Adonis UI object
	Tag = function(self, obj, name)
		obj:SetAttribute("ADONIS_UI", name or obj.Name)
	end;

	Colorize = function(self, obj, colors)
	    local objs = obj:GetDescendants()
	    for i,b in ipairs(objs) do
	        local attributes = b:GetAttributes()
	        for name,value in pairs(attributes) do
	            local color = string.match(name, "Use(.+)Color")
	            if color then
	                local colorVal = colors[color]
	                if colorVal then
	                    b[value] = colorVal
	                end
	            end
	        end
	    end
	end;

	--// Returns LocalPlayer's PlayerGui
	GetPlayerGui = function(self)
		return Service.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	end;

	--// Given an object, determine and return appropriate parent
	GetParent = function(self, obj)
		local playerGui = Service.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			if obj and (obj:IsA("ScreenGui") or obj:IsA("GuiMain")) then
				return playerGui
			else
				if self.Holder and self.Holder.Parent == playerGui then
					return self.Holder
				else
					pcall(function() if self.Holder then self.Holder:Destroy() end end)
					local new = Utilities:CreateInstance("ScreenGui", {
						Name = Utilities:RandomString(),
						Parent = playerGui,
					});

					self.Holder = new

					return new
				end
			end
		else
			Root.Warn("PlayerGui not found")
		end
	end;

	--// Currently unused
	GetHandler = function(self, gui, config, ...)
		local gIndex = Utilities:RandomString()
		local gTable = {
			Object = gui,
			Config = config,
			Data = table.pack(...),
			Name = config.Name or gui.Name,
			Class = config.ClassName or gui.ClassName,
			Index = gIndex,
			Active = true,
			Events = {},
			Parent = self:GetParent(gui)
		}

		for i,v in pairs(Methods.gTable) do
			gTable[i] = v
		end

		gui.Name = "[Adonis] ".. gIndex
		gTable:Register(gui)

		return gTable,gIndex
	end;
}

Methods.gTable = {
	Ready = function(self)
		Root.DebugWarn("SETTING GUI READY")

		local ran,err = pcall(function()
			local obj = self.Object;
			if obj and (obj:IsA("ScreenGui") or obj:IsA("GuiMain")) then
				if obj.DisplayOrder == 0 then
					obj.DisplayOrder = 90000
				end

				obj.Enabled = true
			end

			obj.Parent = self.Parent
		end);

		if ran then
			self.Active = true
		else
			Root.Warn("Something happened while trying to set the parent of "..tostring(self.Object.Name), tostring(err))
			self:Destroy()
		end
	end,

	BindEvent = function(self, event, func)
		Root.DebugWarn("BINDING EVENT", event)

		local signal = event:Connect(func)
		local origDisc = signal.Disconnect
		local Events = self.Events
		local disc = function()
			origDisc(signal)
			for i,v in ipairs(Events) do
				if v.Signal == signal then
					table.remove(Events, i)
				end
			end
		end

		table.insert(Events, {
			Signal = signal,
			Remove = disc
		})

		return {
			Disconnect = disc,
			Wait = if Utilities:CheckProperty(signal, "Wait") then signal.Wait else event.Wait
		}, signal
	end,

	ClearEvents = function(self)
		Root.DebugWarn("CLEAR EVENTS")

		for i,v in pairs(self.Events) do
			pcall(function() v.Signal:Disconnect() end)
			self.Events[i] = nil
		end
	end,

	Destroy = function(self)
		Root.DebugWarn("DESTROY GUI")

		pcall(function()
			if self.CustomDestroy then
				self:CustomDestroy()
			else
				Utilities.Wrapping:UnWrap(self.Object):Destroy()
			end
		end)

		if self.Config.OnDestroy then
			pcall(self.Config.OnDestroy, self)
		end

		self.Destroyed = true
		self.Active = false
		self:UnRegister()
		self:ClearEvents()
	end,

	UnRegister = function(self)
		Root.DebugWarn("UNREGISTER GUI")

		if UI.ActiveObjects[self.Index] then
			UI.ActiveObjects[self.Index] = nil

			if self.OnUnRegister then
				pcall(self.OnUnRegister, self)
			end
		end

		if self.AncestryEvent then
			self.AncestryEvent:Disconnect()
		end
	end,

	Register = function(self, gui)
		Root.DebugWarn("REGISTER GUI", gui)

		local checking = false

		if self.AncestryEvent then
			self.AncestryEvent:Disconnect()
		end

		self.AncestryEvent = gui.AncestryChanged:Connect(function(c, parent)
			if not checking then
				checking = true
				local isDestroyed = Utilities:IsDestroyed(self.Object)
				if UI.ActiveObjects[self.Index] and not isDestroyed then
					local playerGui = UI:GetPlayerGui()
					if rawequal(c, self.Object) and parent == playerGui and self.Parent ~= playerGui then
						wait()
						self.Object.Parent = self.Parent
					elseif rawequal(c, self.Object) and parent == nil and not self.Config.KeepAlive then
						self:Destroy()
					elseif rawequal(c, self.Object) and parent ~= nil then
						self.Active = true
						UI.ActiveObjects[self.Index] = self
					end
				elseif isDestroyed then
					self.Destroyed = true
					self.Active = false
					self:UnRegister()
				end
				checking = false
			end
		end)

		UI.ActiveObjects[self.Index] = self
	end
}

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Utilities = Root.Utilities
		Package = cPackage
		Service = Root.Utilities.Services

		--// Do init
		Root.UI = UI
		Utilities:MergeTables(Root.Remote.Commands, RemoteCommands)
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
	end;
}
