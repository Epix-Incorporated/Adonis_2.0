--[[

	Description: Responsible for package dependency resolution and package initialization.
	Author: Sceleratis
	Date: 11/20/2021

--]]

--- @class PackageHandler
--- Responsible for package dependency resolution and package initialization.
--- @client
--- @server
--- @tag Core

local oWarn = warn
local Verbose = false

--// Warn
local function warn(...)
	oWarn(":: PackageHandler ::", ...)
end

--// Warn, but for debugging situations (more verbose/spammy)
local function DebugWarn(...)
	if Verbose then
		warn("Debug ::", ...)
	end
end

--// Shorthand to DebugWarn() that just prints out a line so we can quickly/easily break up output for readability
local function debugLine()
	DebugWarn("=======================================================")
end

--// Formatted warn
local function FormatOut(...)
	warn(string.format(...))
end

--// Formatted error
local function FormatError(...)
	error(string.format(...), 2)
end

--- Runs the given function and calls FormatError for any errors.
--- @function RunFunction
--- @within PackageHandler
--- @param func function -- The function to run
--- @param ... any -- Package arguments
local function RunFunction(func: ()->(), ...)
	--//xpcall(Function, function(err)
	--//	FormatError("Loading Error: %s", err)
	--//end, ...)
	local ran, err = pcall(func, ...)

	if not ran then
		FormatError("Loading Error: %s", err)
	end
end

--- Returns the metadata for a given package.
--- @function GetMetadata
--- @within PackageHandler
--- @param Package Folder -- The package folder we're getting metadata from.
--- @return {[string]:any} --  Metadata table
local function GetMetadata(Package: Folder): {[string]:any}
	local metaMod = Package:FindFirstChild("Metadata")
	if metaMod and metaMod:IsA("ModuleScript") then
		local metaData = require(metaMod)
		if metaData and type(metaData) == "table" then
			return metaData
		else
			FormatError("Cannot load package %s : Invalid Metadata", Package.Name)
		end
	else
		FormatError("Cannot load package %s : Missing Metadata", Package.Name)
	end
end

--- Given a list of objects, finds all packages and returns a table in the format {[Name==Version]: PackageFolder}
--- Result table format: {[name .. "==" .. version] = package }
--- @function GetPackages
--- @within PackageHandler
--- @param Packages {Folder} -- Table containing packages to extract client packages from.
--- @param FindName string -- Optional bame of object to find as a filter, excluding any packages without this in them.
--- @return {[string]: Folder} -- Table containing found client packages.
local function GetPackages(Packages: {Folder}, FindName: string?): {[string]: Folder}
	local found = {}

	DebugWarn("GET PACKAGES CONTAINING", FindName)

	for i, v in ipairs(Packages) do
		DebugWarn("CHECK PACKAGE", v)

		if v:IsA("Folder") and v:FindFirstChild("Metadata") and ((not FindName) or v:FindFirstChild(FindName)) then
			DebugWarn("HAS FINDNAME", v)

			local metadata = GetMetadata(v)
			local pkgString = metadata.Name .. "==" .. metadata.Version

			DebugWarn("METADATA: ", metadata)
			DebugWarn("PKGSTRING: ", pkgString)

			if not found[pkgString] then
				found[pkgString] = v
			else
				FormatOut("Warning! Conflicting Name and Version for Package %s found!", pkgString)
			end
		end
	end
	return found
end

--- Given a list of packages, this method will remove anything matching the provided "Remove" string and return a list of package clones without the removed object
--- This is primarily used to strip the "Server" folder from packages which are shared by the server and client before sending said packages to the client
--- @function StripPackages
--- @within PackageHandler
--- @param Packages {Folder} -- Table containing packages.
--- @param Remove string -- Name of children to remove.
--- @return table -- Packages that were stripped.
local function StripPackages(Packages: {Folder}, Remove: string)
	local found = {}
	for i,v in pairs(Packages) do
		local metadata = GetMetadata(v)
		local pkgString = metadata.Name .. "==" .. metadata.Version

		local new = v:Clone()
		local remove = new:FindFirstChild(Remove)
		if remove then
			remove:Destroy()
		end

		if not found[pkgString] then
			found[pkgString] = new
		else
			FormatOut("Warning! Conflicting Name and Version for Package %s found!", pkgString)
		end
	end
	return found
end

--- Given a list of packages (Packages), a package name (DepedencyName), and a package version (DepdencyVersion.)
--- Checks if any packages in the provided package list match the provided name and version.
--- This is used during dependency resolution.
--- @function FindDependency
--- @within PackageHandler
--- @param Packages table -- Table of packages.
--- @param DependencyName string -- Searches for this dependency name.
--- @param DependencyVersion number -- Searches for this depdendency version (optional.)
--- @return string, package -- Returns the found package string (name==version) and the package itself.
local function FindDependency(Packages: {[string]: Folder}, DependencyName: string, DependencyVersion)
	DebugWarn("FIND DEPENDENCY: ", Packages, DependencyName, DependencyVersion)

	for pkgString, pkg in pairs(Packages) do
		DebugWarn("PKGSTRING", pkgString)
		DebugWarn("PKG", pkg)

		local name = string.match(pkgString, "(.*)==")
		local version = string.match(pkgString, "==(.*)")

		DebugWarn("NAME, VERSION", name, version)

		if name == DependencyName and (not DependencyVersion or DependencyVersion == version) then
			DebugWarn("RETURN; pkgString, pkg", pkgString, pkg)
			return pkgString, pkg
		end
	end
end

--- Given a list of packages (Packages) and a package (Package) checks if the package's depdencies are in the given package list
--- This is used when loading packages to check if a given package's dependencies were correctly resolved and loaded before attempting to load the package that needs them
--- @function CheckDependencies
--- @within PackageHandler
--- @param Packages table -- Table of packages
--- @param Package Folder -- Package
--- return bool -- Returns true if package passes dependency check and returns false if it fails.
local function CheckDependencies(Packages: {[string]: Folder}, Package: Folder)
	local metadata = GetMetadata(Package)
	local dependencies = metadata.Dependencies

	DebugWarn("Checking package depdencies", Package)
	if dependencies then
		for i,depString in pairs(dependencies) do
			debugLine()

			local name = string.match(depString, "(.*)==") or depString
			local version = string.match(depString, "==(.*)")
			if not FindDependency(Packages, name, version) then
				DebugWarn("Dependency check failed")
				return false
			end
		end

		DebugWarn("Dependency check passed")
		return true
	else
		FormatError("Package %s is missing a dependencies list", metadata.Name)
	end
end

--// Given an ordered table of packages, checks if any packages match PackageName and PackageVersion
local function CheckResults(ResultList: {Folder}, PackageName: string, PackageVersion)
	for i,package in ipairs(ResultList) do
		local metadata = GetMetadata(package)
		if metadata.Name == PackageName and (not PackageVersion or metadata.Version == PackageVersion) then
			return true
		end
	end
	return false
end

--// Recursively handles dependency resolution
local Resolve; Resolve = function(Packages: {[string]: Folder}, ResultList: {Folder}, Package: Folder, Chain)
	DebugWarn("RESOLVING: ", Package, Chain)

	local metadata = GetMetadata(Package)
	local pkgString = metadata.Name .. "==" .. metadata.Version
	local dependencies = metadata.Dependencies
	local chain = Chain or {}

	if chain[pkgString] then
		DebugWarn("PACKAGE ALREADY IN CHAIN")
		FormatError("Circular Dependency Error : One or more dependencies of %s is circular", pkgString)
		return nil
	else
		DebugWarn("NO CIRCULAR (CHAIN) CONFLICT")

		chain[pkgString] = true

		for i,depString in pairs(dependencies) do
			debugLine()
			DebugWarn("DEPENDENCY: ", depString)

			local name = string.match(depString, "(.*)==") or depString
			local version = string.match(depString, "==(.*)")
			local depPackageString, dep = FindDependency(Packages, name, version)

			if dep then
				DebugWarn("CHECK RESULTS")

				if not CheckResults(ResultList, name, version) then
					DebugWarn("RESOLVE DEP: ", dep, chain)
					Resolve(Packages, ResultList, dep, chain)
				end
			else
				FormatError("Could not resolve depedency %s for package %s", name .. "==" .. tostring(version), Package.Name)
			end
		end

		DebugWarn("CHECK RESULT", ResultList, pkgString)

		if not CheckResults(ResultList, metadata.Name, metadata.Version) then
			DebugWarn("ADD TO RESULTLIST", Package, ResultList)
			table.insert(ResultList, Package)
			debugLine()
		end
	end
end

--- Given a table of packages (Packages), Resolves package dependencies and produces an ordered list the places packages after all of their dependencies.
--- The results of this method determine load order, based on depedency resolution.
--- @function GetOrderedPackageList
--- @within PackageHandler
--- @param Packages table -- Table of packages
--- @return {Folder} -- Ordered table of packages based on depdency resolution.
local function GetOrderedPackageList(Packages: {[string]: Folder}): {Folder}
	local ResultList = {}

	debugLine()
	DebugWarn("GETTING ORDERED PACKAGE LIST", Packages)

	for i,v in pairs(Packages) do
		DebugWarn("RESOLVE PACKAGE: ", v)
		Resolve(Packages, ResultList, v)
		debugLine()
	end

	return ResultList
end

--- Given a package (Package) and a PackageType (Server, Client) this method will find and required the Initializer module for the given package and return the package's Init & AfterInit functions in a table.
--- @function InitPackage
--- @within PackageHandler
--- @param Package Folder -- Package to initialize
--- @param PackageType string -- Package type (Client or Server)
--- @param ... any -- Package arguments
--- return table -- Returned package init table
local function InitPackage(Package: Folder, PackageType: string, ...)
	local targetFolder = Package:FindFirstChild(PackageType)
	if targetFolder then
		local initMod = targetFolder:FindFirstChild("Initializer")
		if initMod and initMod:IsA("ModuleScript") then
			local res = require(initMod)
			if res and type(res) == "function" then
				return {
					Init = res;
					AfterInit = nil;
				}
			elseif res and type(res) == "table" then
				return res
			else
				FormatOut("Cannot load package %s : Initializer did not return a function", Package.Name)
			end
		else
			FormatOut("Cannot load package %s : Initializer is nil or not a ModuleScript", Package.Name)
		end
	else
		FormatError("Package %s does not contain PackageType %s", Package.Name, PackageType)
		--DebugWarn("Package", Package.Name, "does not contain PackageType folder", PackageType)
	end
end

--- Given a table of packages, performs dependency resolution and loads all packages provided matching PackageType in order.
--- @function LoadPackages
--- @within PackageHandler
--- @param Packages {Folder} -- Table of packages
--- @param PackageType string -- Package type (Server, Client)
--- @param ... any -- Package arguments
local function LoadPackages(Packages: {[string]: Folder}, PackageType: string, ...)
	local initFuncs = {}
	local loadedPackages = {}

	--// Organize packages according to their depdendencies
	local ordered = GetOrderedPackageList(Packages)

	DebugWarn("GOT ORDERED LIST", ordered)

	--// Load all packages
	for i, package in pairs(ordered) do
		if CheckDependencies(loadedPackages, package) then
			DebugWarn("LOAD PACKAGE", package)
			local ran, res = pcall(InitPackage, package, PackageType, ...)
			if not ran then
				warn("Error encountered while running InitPackage; Expand for details:", {
					Package = package;
					PackageType = PackageType;
					Error = tostring(res);
				})
			elseif res and type(res) == "table" then
				local metadata = GetMetadata(package)
				local pkgString = metadata.Name .. "==" .. metadata.Version

				loadedPackages[pkgString] = package

				table.insert(initFuncs, {
					Package = package;
					Init = res.Init;
					AfterInit = res.AfterInit;
				})
			end
		else
			warn("Package dependency check failed", package)
		end
	end

	--// Initialize packages
	for i,v in ipairs(initFuncs) do
		DebugWarn("INIT", v)
		local ran, err = pcall(RunFunction, v.Init, ...)
		if not ran then
			warn("Error encountered while running Init function for package; Expand for details:", {
				Package = v.Package;
				PackageType = PackageType;
				Index = i;
				Error = tostring(err);
			})
		end
	end

	--// After all packages are initialized
	for i,v in ipairs(initFuncs) do
		DebugWarn("AFTERINIT", v)
		if v.AfterInit then
			local ran, err = pcall(RunFunction, v.AfterInit, ...)
			if not ran then
				warn("Error encountered while running AfterInit function for package; Expand for details:", {
					Package = v.Package;
					PackageType = PackageType;
					Index = i;
					Error = tostring(err);
				})
			end
		end
	end
end

return table.freeze {
	InitPackage = InitPackage;
	GetPackages = GetPackages;
	StripPackages = StripPackages;
	GetMetadata = GetMetadata;
	FindDependency = FindDependency;
	CheckDependencies = CheckDependencies;
	GetOrderedPackageList = GetOrderedPackageList;
	LoadPackages = LoadPackages;
}
