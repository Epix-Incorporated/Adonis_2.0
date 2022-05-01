--[[

	Description: Responsible for initializing the server portion of the 'Core' package.
	Author: Sceleratis
	Date: 11/20/2021

--]]

--// Package data
local PackageFolder = script.Parent.Parent
local Metadata = require(PackageFolder.Metadata)
local Package = {
	Folder = PackageFolder;
	Metadata = Metadata;
	Name = Metadata.Name;

	Server = PackageFolder.Server;
	Client = PackageFolder.Client;
	Shared = PackageFolder.Shared;
	Assets = PackageFolder.Server.Assets;
	SharedAssets = PackageFolder.Shared.Assets;

	Modules = PackageFolder.Server.Modules;
	Handlers = PackageFolder.Server.Handlers;
}

--// Misc loading variables
local RootTable;
local InitFunctions = {}

--// Output
local Verbose = false
local oWarn = warn;

local function warn(...)
	if RootTable and RootTable.Warn then
		RootTable.Warn(...)
	else
		oWarn(":: ".. script.Name .." ::", ...)
	end

	if RootTable and RootTable.Utilities then
		RootTable.Utilities.Events.Warning:Fire(...)
	end
end

local function DebugWarn(...)
	if Verbose then
		warn("Debug ::", ...)
	end
end 


--// Runs the given function and outputs any errors
local function RunFunction(Function, ...)
	xpcall(Function, function(err)
		warn("Error while running function; Expand for more info", {Error = tostring(err), Raw = err})
	end, ...)
end

--// Requires a given ModuleScript; If a function is returned immediately, run it
--// If a table is returned, assume deferred execution
local function LoadModule(Module: ModuleScript, ...)
	local ran,func = pcall(require, Module)

	if ran then
		if type(func) == "function" then
			RunFunction(func, ...)
		elseif type(func) == "table" then
			table.insert(InitFunctions, func)
		end
	else
		warn("Encountered error while loading module:", {Module = Module, Error = tostring(func)})
	end
end

--// Initializer functions
return {
	Init = function(Root, Packages)
		DebugWarn("INIT " .. Package.Metadata.Name .. " PACKAGE")

		--// Init
		RootTable = Root
		Verbose = if Root.Verbose ~= nil then Root.Verbose else Verbose

		--// Load modules
		for i,module in ipairs(Package.Modules:GetChildren()) do
			if module:IsA("ModuleScript") then
				LoadModule(module, Root, Package)
			end
		end

		--// Load shared modules
		for i,module in ipairs(Package.Shared:GetChildren()) do
			if module:IsA("ModuleScript") then
				LoadModule(module, Root, Package)
			end
		end

		--// Run init methods
		for i,t in ipairs(InitFunctions) do
			if t.Init then
				RunFunction(t.Init, Root, Package)
			end
		end

		DebugWarn("INIT " .. Package.Metadata.Name .. " PACKAGE FINISHED")
	end;

	AfterInit = function(Root, Packages)
		DebugWarn("AFTERINIT " .. Package.Metadata.Name .. " PACKAGE")

		--// Run AfterInit methods
		for i,t in ipairs(InitFunctions) do
			if t.AfterInit then
				RunFunction(t.AfterInit, Root, Package)
			end
		end

		--// Run DelayedAfterSetup methods
		for i,t in ipairs(InitFunctions) do
			if t.DelayedAfterSetup then
				RunFunction(t.DelayedAfterSetup, Root, Package)
			end
		end

		Root.Logging:AddLog("Script", "Core Loaded")
		DebugWarn("AFTERINIT " .. Package.Metadata.Name .. " PACKAGE FINISHED")
	end;
}
