--[[

	Description: Responsible for UI
	Author: Sceleratis
	Date: 12/18/2021

--]]


local Root, Utilities, Service, Package;

local RemoteCommands = {
	GUI = function(uiName, theme, data, ...)
		Root.DebugWarn("CREATE UI ELEMENT", uiName, theme, data, ...)
		return Root.UI:NewElement(uiName, theme, data, ...);
	end;
}

local Methods = {
}

local UI = {
	DeclaredThemes = {};
	DeclaredPrefabs = { Default = {} };
	ActiveObjects = {};

	DeclarePrefab = function(self, groupName, name, prefab)
		if not self.DeclaredPrefabs[groupName] then
			self.DeclaredPrefabs[groupName] = {}
		end

		if self.DeclaredPrefabs[groupName][name] then
			Root.Warn("Prefab for group already declared. Overwriting. Prefab Name:", themeName, "| Group Name:", groupName);
			Utilities.Events.UIWarning:Fire("Overwriting existing prefab", name, groupName);
		end

		self.DeclaredPrefabs[groupName][name] = prefab
		Utilities.Events.DeclaredPrefab:Fire(groupName, name, prefab)
	end;

	DeclareTheme = function(self, themeName, themeFolder)
		if self.DeclaredThemes[themeName] then
			Root.Warn("Theme already declared. Overwriting. ThemeName: ", themeName);
			Utilities.Events.UIWarning:Fire("Overwriting existing theme", themeName, themeFolder);
		end

		self.DeclaredThemes[themeName] = themeFolder;
		Utilities.Events.DeclaredTheme:Fire(themeName, themeFolder);
	end;

	GetTheme = function(self)
		local theme = Root.Globals.ThemeOverride or self.CachedTheme or Remote:Get("ThemeInfo")

		if theme then
			self.CachedTheme = theme
		end

		return theme or "Default"
	end;

	GetPrefab = function(self, prefabName, prefabGroup)
		local prefabGroup = self.DeclaredPrefabs[prefabGroup] or self.DeclaredPrefabs.Default
		if prefabGroup then
			local found = prefabGroup[prefabName]
			if found then
				local prefab = found:Clone()
				local controller = prefab:FindFirstChild("Controller")
				local interface = if controller then controller:FindFirstChild("Interface") else nil
				return {
					Prefab = prefab,
					Controller = controller,
					Interface = if interface then require(interface) else nil
				}
			end
		end
	end;

	Colorize = function(self, colors, obj)
		local objs = obj:GetDescendants()
		for color,value in pairs(colors) do
			local colorAttributeName = "Use".. color .."Color"
			for i,b in ipairs(objs) do
				local attr = b:GetAttribute(colorAttributeName)
				if attr then
					b[attr] = value
				end
			end
		end
	end;

	GetThemeElement = function(self, uiName, theme, ...)
		local theme = self.DeclaredThemes[theme] or self.DeclaredThemes.Default

		Root.DebugWarn("UI THEME FOUND", theme, "FOR", uiName)

		if theme then
			if theme:IsA("ModuleScript") then
				Root.DebugWarn("THEME IS MODULESCRIPT")
				return require(theme)(uiName, theme, ...)
			else
				local baseThemeObj = theme:FindFirstChild("BaseTheme");
				local baseTheme = if baseThemeObj then baseThemeObj.Value else "Default"
				local targObj = theme:FindFirstChild(uiName) or (if baseTheme and baseTheme ~= theme then self:GetUIElement(uiName, Utilities:MergeTables({}, theme, baseTheme), ...) else nil);
				if targObj then
					Root.DebugWarn("Return Element", targObj)
					return targObj;
				else
					Root.Warn("Theme object not found:", uiName)
				end
			end
		else
			Root.Warn("Theme not found:", theme);
		end
	end;

	LoadElement = function(self, obj, uiName, theme, ...)
		Root.DebugWarn("LOADING ELEMENT", obj, uiName, theme, ...)

		if obj:IsA("ModuleScript") then
			Root.DebugWarn("IS MODULESCRIPT", obj)

			return self:LoadModule(obj, obj, theme, ...)
		else
			Root.DebugWarn("IS NOT MODULESCRIPT", obj)

			local configMod = obj:FindFirstChild("Config")
			if configMod and configMod:IsA("ModuleScript") then
				Root.DebugWarn("CONFIGMOD IS MODULESCRIPT, LOADMODULE", configMod)
				return self:LoadModule(obj, configMod, theme, ...)
			else
				Root.Warn("Config module not found for:", uiName)
			end
		end
	end;

	NewElement = function(self, uiName, theme, ...)
		local obj = self:GetThemeElement(uiName, theme, ...)
		if obj and type(obj) == "function" then
			Root.DebugWarn("GUI Object is function, return after call");
			return obj(Root, uiName, theme, ...)
		elseif obj then
			Root.DebugWarn("LoadElement", obj)
			return self:LoadElement(obj, uiName, theme, ...)
		end
	end;

	GetElement = function(self, uiNameOrObj, ignore, returnOne)
		local found = {}
		for ind,gTable in pairs(self.ActiveObjects) do
			if (gTable.Name == uiNameOrObj or gTable.Object == uiNameOrObj) and gTable.Name ~= ignore and gTable.Object ~= ignore then
				if returnOne then
					return gTable
				else
					table.insert(found, gTable)
				end
			end
		end
		return found
	end;

	LoadModule = function(self, gui, configMod, theme, ...)
		local config = require(configMod);

		Root.DebugWarn("GOT CONFIG", config)
		if config and type(config) == "table" then
			local func = config.OnLoad;
			local gTable = self:GetHandler(gui, config, theme, ...);

			Root.DebugWarn("GOT GUI HANDLER:", gTable)
			if func then
				Root.DebugWarn("LOADMODULE RUN FUNC", Root, gTable, ...)
				return func(Root, gTable, ...)
			else
				Root.Warn("OnLoad method not found for: ", tostring(gui))
			end
		end
	end;

	GetPlayerGui = function(self)
		return Service.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	end;

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

	GetHandler = function(self, gui, config, theme, ...)
		local gIndex = Utilities:RandomString()
		local gTable = {
			Object = gui,
			Config = config,
			Theme = theme,
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
