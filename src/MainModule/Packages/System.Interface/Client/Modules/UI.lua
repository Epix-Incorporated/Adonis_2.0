--[[

	Description: Responsible for UI
	Author: Sceleratis
	Date: 12/18/2021

--]]


local Root, Utilities, Service, Package;

local RemoteCommands = {}
local Methods = {}

--// Output
local Verbose = false
local oWarn = warn;

local function warn(...)
	if Root and Root.Warn then
		Root.Warn(...)
	else
		oWarn(":: ".. script.Name .." ::", ...)
	end
end

local function DebugWarn(...)
	if Verbose then
		warn("Debug ::", ...)
	end
end


--[=[
	Responsible for client-side UI management.
	@class Client.UI
	@client
	@tag Interface
]=]
local UI = {
	DeclaredModules = {};
	DeclaredPrefabs = {};
	DeclaredLaunchers = {};
}

--// Remote Commands
--[=[
	Command from the server instruction the client to run the specified UI module.
	@method UI_LoadModule
	@within Client.Remote.Commands
	@tag System.UI
]=]
function RemoteCommands.UI_LoadModule(data: {[string]: any}, ...: any)
	DebugWarn("LOAD UI MODULE", data, ...)
	return Root.UI:LoadModule(data, ...);
end

--// UI
--[=[
	Declares a new launcher
	@method DeclareLauncher
	@within Client.UI
	@param name string -- Launcher Name
	@param data {} -- Launcher data
]=]
function UI.DeclareLauncher(self, name: string, data: {[string]: any})
	if self.DeclaredLaunchers[name] then
		warn("Prefab group already declared. Overwriting launcher:", name);
		Utilities.Events.UIWarning:Fire("Overwriting existing launcher", name);
	end

	self.DeclaredLaunchers[name] = data

	Utilities.Events.UI_DeclaredLauncher:Fire(name, data)
end

--[=[
	Declares a UI prefab group.
	@method DeclarePrefabGroup
	@within Client.UI
]=]
function UI.DeclarePrefabGroup(self, groupData: {[string]: any})
	local groupName = groupData.Name;

	if self.DeclaredPrefabs[groupName] then
		warn("Prefab group already declared. Overwriting group:", groupName);
		Utilities.Events.UIWarning:Fire("Overwriting existing prefab group", groupName);
	end

	self.DeclaredPrefabs[groupName] = {
		Name = groupName,
		Fallback = groupData.Fallback,
		GroupData = groupData,
		Prefabs = {}
	}

	Utilities.Events.UI_DeclaredPrefabGroup:Fire(groupData)
end

--[=[
	Declares a UI module group.
	@method DeclareModuleGroup
	@within Client.UI
]=]
function UI.DeclareModuleGroup(self, groupData: {[string]: any})
	local groupName = groupData.Name;

	if self.DeclaredModules[groupName] then
		warn("Prefab group already declared. Overwriting group:", groupName);
		Utilities.Events.UIWarning:Fire("Overwriting existing prefab group", groupName);
	end

	self.DeclaredModules[groupName] = {
		Name = groupName,
		Fallback = groupData.Fallback,
		GroupData = groupData,
		Modules = {}
	}

	Utilities.Events.UI_DeclaredModuleGroup:Fire(groupData)
end

--[=[
	Declares a UI prefab.
	@method DeclarePrefab
	@within Client.UI
]=]
function UI.DeclarePrefab(self, groupName: string, name: string, prefab: Instance)
	if not self.DeclaredPrefabs[groupName] then
		self.DeclaredPrefabs[groupName] = {
			Name = groupName,
			Prefabs = {}
		}
	end

	if self.DeclaredPrefabs[groupName].Prefabs[name] then
		warn("Prefab for group already declared. Overwriting. Prefab Name:", name, "| Group Name:", groupName);
		Utilities.Events.UIWarning:Fire("Overwriting existing prefab", name, groupName);
	end

	self.DeclaredPrefabs[groupName].Prefabs[name] = prefab

	Utilities.Events.UI_DeclaredPrefab:Fire(groupName, name, prefab)
end

--[=[
	Declares a UI module.
	@method DeclareModule
	@within Client.UI
]=]
function UI.DeclareModule(self, groupName: string, name: string, module: ModuleScript)
	if not self.DeclaredModules[groupName] then
		self.DeclaredModules[groupName] = {
			Name = groupName,
			Modules = {}
		}
	end

	if self.DeclaredModules[groupName].Modules[name] then
		warn("UI module for group already declared. Overwriting. Module Name:", name, "| Group Name:", groupName);
		Utilities.Events.UIWarning:Fire("Overwriting existing UI module", name, groupName);
	end

	self.DeclaredModules[groupName].Modules[name] = module

	Utilities.Events.UI_DeclaredModule:Fire(groupName, name, module)
end

--[=[
	Returns a UI prefab matching the provided name from the group matching the provided group name.
	@method GetPrefab
	@within Client.UI
]=]
function UI.GetPrefab(self, prefabName: string, groupName: string): Instance
	local defaultGroup = self.DecalredPrefabs.Default
	local prefabGroupName = groupName or Root.Globals.UI_PrefabGroupOverride or self.CachedPrefabGroup or Root.Settings.UI_PrefabGroup
	local prefabGroup = self.DeclaredPrefabs[groupName] or defaultGroup
	local fallbackGroupName = prefabGroup.Fallback
	local fallbackGroup = if fallbackGroupName then self.DeclaredPrefabs[fallbackGroupName] else nil

	DebugWarn("GETTING PREFAB", prefabName, groupName)

	if prefabGroup then
		local found = prefabGroup.Prefabs[prefabName] or (fallbackGroup and fallbackGroup.Prefabs[prefabName]) or (defaultGroup and defaultGroup.Prefabs[prefabName])

		if found then
			local prefab = found:Clone()
			local controller = prefab:FindFirstChild("Controller")
			local interface = if controller then controller:FindFirstChild("Interface") else nil

			if prefab:IsA("ScreenGui") then
				self:Tag(prefab, "ADONIS_UI", prefab.Name)
			end

			return (interface and require(interface)) or {
				Prefab = prefab,
				Controller = controller
			}
		else
			warn("UI prefab not found! prefab:", prefabName, " | Group:", groupName);
			Utilities.Events.UIWarning:Fire("Prefab not found", prefabName, groupName);
		end
	else
		warn("No UI prefab group found! Prefab:", prefabName, " | Group:", groupName);
		Utilities.Events.UIWarning:Fire("Prefab group not found", prefabName, groupName);
	end
end

--[=[
	Finds and returns a UI module.
	@method GetModule
	@within Client.UI
	@param moduleName string
	@param groupName string
	@return ModuleScript
]=]
function UI.GetModule(self, moduleName: string, groupName: string): ModuleScript
	local defaultGroup = self.DeclaredModules.Default
	local moduleGroupName = groupName or Root.Globals.UI_ModuleGroupOverride or self.CachedModuleGroup or Root.Settings.UI_ModuleGroup
	local moduleGroup = self.DeclaredModules[groupName] or defaultGroup
	local fallbackGroupName = moduleGroup.Fallback
	local fallbackGroup = if fallbackGroupName then self.DeclaredModules[fallbackGroupName] else nil

	DebugWarn("GETTING UI MODULE", moduleName, groupName)

	if moduleGroup then
		local found = moduleGroup.Modules[moduleName] or (fallbackGroup and fallbackGroup.Modules[moduleName]) or (defaultGroup and defaultGroup.Modules[moduleName])

		if found then
			return found
		else
			warn("UI module not found! Module:", moduleName, " | Group:", groupName);
			Utilities.Events.UIWarning:Fire("Module not found", moduleName, groupName);
		end
	else
		warn("No UI module group found! Module:", moduleName, " | Group:", groupName);
		Utilities.Events.UIWarning:Fire("Module group not found", moduleName, groupName);
	end
end

--[=[
	Loads a given UI module.
	@method LoadModule
	@within Client.UI
	@param moduleData {} -- Module data
	@param ... tuple -- Params passed to module.
	@return any
]=]
function UI.LoadModule(self, moduleData: {[any]: any}, ...: any): any
	local module = self:GetModule(moduleData.Name, moduleData.Group)
	if module then
		DebugWarn("REQUIRING UI MODULE", moduleData)
		local handler = require(module)
		if handler and type(handler) == "table" and handler.LoadModule then
			DebugWarn("LOADING UI MODULE", moduleData)
			Utilities.Events.UI_LoadingModule:Fire(moduleData, module, ...)
			return handler:LoadModule(Root, moduleData, ...)
		end
	end
end

--[=[
	Finds any objects in PlayerGui that have the UI attribute tag.
	@method FindElements
	@within Client.UI
	@param name string
	@param ignore (string|Instance)?
	@param returnOne bool -- Return first found if true, otherwise return list of all found.
	@return ({[string]: Instance})
]=]
function UI.FindElements(self, name: string, ignore: (string|Instance)?, returnOne): ({[string]: Instance})
	local found = {}
	for i, child in ipairs(self:GetPlayerGui():GetDescendants()) do
		if child ~= ignore and child.Name ~= ignore then
			local attribute = self:GetTag("ADONIS_UI")
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
end

--[=[
	Adds an attribute to the specified object ; Uses special UI methods in-case the way this is handled ever changes.
	@method Tag
	@within Client.UI
	@param obj Instance
	@param tagName string
	@param tagValue any
]=]
function UI.Tag(self, obj: Instance, tagName: string, tagValue: any)
	obj:SetAttribute(tagName, tagValue)
end

--[=[
	Returns the specified attribute.
	@method GetTag
	@within Client.UI
	@param obj Instance
	@param tagName string
	@return Attribute
]=]
function UI.GetTag(self, obj: Instance, tagName: string): any
	return obj:GetAttribute(tagName)
end

--[=[
	Get attributes for the specified object.
	@method GetTags
	@within Client.UI
	@param obj Instance
	@return Attributes
]=]
function UI.GetTags(self, obj: Instance): {[string]: any}
	return obj:GetAttributes()
end

--[=[
	Given an object and theming information such as colors and font, applies desired font and colors to object and it's descendants based on attribute tags.
	@method ApplyThemeSettings
	@within Client.UI
	@param obj Instance -- Object
	@param data ThemeSettings -- Table containing themeing properties to apply
]=]
function UI.ApplyThemeSettings(self, obj: Instance, data: {[string]: any})
	local data = data or Root.Settings.UI_ThemeSettings
	local objs = obj:GetDescendants()
	for i,b in ipairs(objs) do
		local attributes = b:GetAttributes()
		for name,value in pairs(attributes) do
			local color = string.match(name, "^Use(.+)")
			if color then
				local colorVal = data[color]
				if colorVal then
					b[value] = colorVal
				end
			end
		end
	end
end

--[=[
	Returns LocalPlayer's PlayerGui.
	@method GetPlayerGui
	@within Client.UI
	@return PlayerGui
]=]
function UI.GetPlayerGui(self): PlayerGui
	return Service.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
end

--[=[
	Given an object, determine and return appropriate parent.
	@method GetParent
	@within Client.UI
	@param obj Instance -- Object
	@return Instance
]=]
function UI.GetParent(self, obj: Instance): Instance
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
		warn("PlayerGui not found")
	end
end

--[=[
	Sets the object's parent to the appropriate destination ; May do more in the future and should be used instead of setting ScreenGui parent to PlayerGui manually.
	@method SetParent
	@within Client.UI
	@param obj Instance -- Object to reparent
]=]
function UI.SetParent(self, obj: Instance)
	obj.Parent = self:GetParent(obj)
end


--// Return initializer
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
