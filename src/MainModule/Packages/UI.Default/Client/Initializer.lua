--[[

	Description: Theme initializer
	Author: Sceleratis/Expertcoderz
	Date: 03/15/2022

--]]


--// Package data
local PackageFolder = script.Parent.Parent
local Package = {
	Package = PackageFolder;
	Metadata = require(PackageFolder.Metadata);

	Client = PackageFolder.Client;
	Modules = PackageFolder:FindFirstChild("Modules");
	Prefabs = PackageFolder:FindFirstChild("Prefabs");
	Modifiers = PackageFolder:FindFirstChild("Modifiers");
}


--// Misc loading variables
local RootTable;
local Verbose = false;

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

--// Initializer functions
return {
	Init = function(Root, Packages)
		debug("INIT " .. Package.Metadata.Name .. " PACKAGE")

		--// Init
		RootTable = Root
		Verbose = if Root.Verbose ~= nil then Root.Verbose else Verbose

		local ClassInfoTable = {}

		if Package.Modules then
			for _, source in ipairs(Package.Modules:GetChildren()) do
				if source:IsA("ModuleScript") then
					local classInfo = require(source)
					if type(classInfo) == "function" then
						classInfo = classInfo(Root)
					end
					if type(classInfo) == "table" then
						classInfo.ClassName = classInfo.ClassName or source.Name
						ClassInfoTable[classInfo.ClassName] = classInfo 
					else
						Root.Warn("Invalid class information provided by module", source.Name)
					end
				end
			end
		end

		if Package.Prefabs then
			for _, prefab in ipairs(Package.Prefabs:GetChildren()) do
				if ClassInfoTable[prefab.Name] then
					ClassInfoTable[prefab.Name].Prefabricated = prefab
				else
					ClassInfoTable[prefab.Name] = {ClassName = prefab.Name, Prefabricated = prefab}
				end
			end
		end

		if Package.Modifiers then
			for _, module in ipairs(Package.Modifiers:GetChildren()) do
				if module:IsA("ModuleScript") then
					if ClassInfoTable[module.Name] then
						require(module)(ClassInfoTable[module.Name], Root)
					else
						Root.Warn("Class does not already exist for modifier", module.Name)
					end
				end
			end
		end

		Root.UI:RegisterTheme(Package.Metadata.Name, ClassInfoTable)

		debug("INIT " .. Package.Metadata.Name .. " PACKAGE FINISHED")
	end;

	AfterInit = function(Root, Packages)
		debug("AFTERINIT " .. Package.Metadata.Name .. " PACKAGE")

		debug("AFTERINIT " .. Package.Metadata.Name .. " PACKAGE FINISHED")
	end;
}
