--[[

	Description: Responsible for initializing the client portion of the 'Core' package.
	Author: Sceleratis
	Date: 12/05/2021

--]]

--// Package data
local PackageFolder = script.Parent.Parent
local Package = {
	Package = PackageFolder;
	Metadata = require(PackageFolder.Metadata);

	Client = PackageFolder.Client;
	Shared = PackageFolder.Shared;
	SharedAssets = PackageFolder.Shared.Assets;

	Modules = PackageFolder.Client.Modules;
}

--// Misc loading variables
local RootTable;
local Verbose = false;
local InitFunctions = {}

--// Output
local oWarn = warn;

local function warn(...)
	oWarn(":: Adonis Client ::", ...)

	if RootTable and RootTable.Utilities then
		RootTable.Utilities.Events.Warning:Fire(...)
	end
end

local function debug(...)
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
		debug("INIT " .. Package.Metadata.Name .. " PACKAGE")

		--// Init
		RootTable = Root
		Verbose = if Root.Verbose ~= nil then Root.Verbose else Verbose
		Root.DebugWarn = debug
		Root.Warn = warn

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

		debug("INIT " .. Package.Metadata.Name .. " PACKAGE FINISHED")
	end;

	AfterInit = function(Root, Packages)
		debug("AFTERINIT " .. Package.Metadata.Name .. " PACKAGE")

		--// Run AfterInit methods
		for i,t in ipairs(InitFunctions) do
			if t.AfterInit then
				RunFunction(t.AfterInit, Root, Package)
			end
		end

		debug("AFTERINIT " .. Package.Metadata.Name .. " PACKAGE FINISHED")
	end;
}
