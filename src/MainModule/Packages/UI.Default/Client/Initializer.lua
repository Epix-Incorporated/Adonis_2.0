--[[

	Description: Theme initializer
	Author: Sceleratis
	Date: 12/18/2021

--]]


--// Package data
local PackageFolder = script.Parent.Parent
local Package = {
	Package = PackageFolder;
	Metadata = require(PackageFolder.Metadata);

	Client = PackageFolder.Client;
	Modules = PackageFolder:FindFirstChild("Modules");
	Prefabs = PackageFolder:FindFirstChild("Prefabs");
}


--// Misc loading variables
local RootTable;

--// Output
local Verbose = false;
local oWarn = warn;

local function warn(...)
	if RootTable and RootTable.Warn then
		RootTable.Warn(...)
	else
		oWarn(":: ".. script.Name .." ::", ...)
	end
end

local function DebugWarn(...)
	if Verbose then
		warn("Debug ::", ...)
	end
end


--// Initializer functions
return {
	Init = function(Root, Packages)
		DebugWarn("INIT " .. Package.Metadata.Name .. " PACKAGE")

		--// Init
		RootTable = Root
		Verbose = if Root.Verbose ~= nil then Root.Verbose else Verbose

		if Package.Metadata.ModuleGroup and not Root.UI.DeclaredModules[Package.Metadata.ModuleGroup] then
			Root.UI:DeclareModuleGroup({
				Name = Package.Metadata.ModuleGroup,
				Fallback = Package.Metadata.ModuleFallback
			})
		end

		if Package.Metadata.PrefabGroup and not Root.UI.DeclaredPrefabs[Package.Metadata.PrefabGroup] then
			Root.UI:DeclarePrefabGroup({
				Name = Package.Metadata.PrefabGroup,
				Fallback = Package.Metadata.PrefabFallback
			})
		end

		if Package.Modules then
			for i,child in ipairs(Package.Modules:GetChildren()) do
				if child:IsA("ModuleScript") then
					Root.UI:DeclareModule(Package.Metadata.ModuleGroup, child.Name, child)
				end
			end
		end

		if Package.Prefabs then
			for i,obj in ipairs(Package.Prefabs:GetChildren()) do
				Root.UI:DeclarePrefab(Package.Metadata.PrefabGroup, obj.Name, obj)
			end
		end

		DebugWarn("INIT " .. Package.Metadata.Name .. " PACKAGE FINISHED")
	end;

	AfterInit = function(Root, Packages)
		DebugWarn("AFTERINIT " .. Package.Metadata.Name .. " PACKAGE")

		DebugWarn("AFTERINIT " .. Package.Metadata.Name .. " PACKAGE FINISHED")
	end;
}
