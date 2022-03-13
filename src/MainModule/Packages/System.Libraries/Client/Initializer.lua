--[[

	Description: Library Indexer
	Author: Sceleratis
	Date: 1/22/2022

--]]


--// Package data
local PackageFolder = script.Parent.Parent
local Package = {
	Package = PackageFolder;
	Metadata = require(PackageFolder.Metadata);

	Shared = PackageFolder.Shared;
	Client = PackageFolder.Client;
	Libraries = PackageFolder.Client.Libraries;
	SharedLibraries = PackageFolder.Shared.Libraries;
}


--// Misc loading variables
local RootTable;
local Verbose = false;
local InitFunctions = {}

--// Output
local oWarn = warn;

local function warn(...)
	if RootTable and RootTable.Warn then
		RootTable.Warn(...)
	else
		oWarn(":: Adonis Client ::", ...)
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

	  	if not Root.Libraries then
			debug("INIT Root.Libraries")
			Root.Libraries = {}
			Root.LibraryObjects = {}
		end

		--// Add libraries
		for i,lib in ipairs(Package.Libraries:GetChildren()) do
			debug("INDEX LIBRARY", lib.Name)
			Root.LibraryObjects[lib.Name] = lib
			if lib:IsA("ModuleScript") then
				Root.Libraries[lib.Name] = require(lib)
			else
				Root.Libraries[lib.Name] = lib
			end
		end

		debug("INIT " .. Package.Metadata.Name .. " PACKAGE FINISHED")
	end;

	AfterInit = function(Root, Packages)
		debug("AFTERINIT " .. Package.Metadata.Name .. " PACKAGE")

		debug("AFTERINIT " .. Package.Metadata.Name .. " PACKAGE FINISHED")
	end;
}
