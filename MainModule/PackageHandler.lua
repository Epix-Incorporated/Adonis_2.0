--[[

	Description: Responsible for resolving package dependency resolution and package initialization.
	Author: Sceleratis
	Date: 11/20/2021

--]]

local oWarn = warn;
local Verbose = false;

--// Warn
local function warn(...)
	oWarn(":: Adonis : PackageHandler ::", ...)
end

--// Warn, but for debugging situations (more verbose/spammy)
local function debug(...)
	if Verbose then
		warn("Debug ::", ...)
	end
end

--// Shorthand to debug() that just prints out a line so we can quickly/easily break up output for readability
local function debugLine()
	debug("=======================================================")
end

--// Formatted warn
local function FormatOut(...)
	warn(string.format(...))
end

--// Formatted error
local function FormatError(...)
	error(string.format(...))
end

--// Runs the given function and calls FormatError for any errors
local function RunFunction(Function, ...)
	--//xpcall(Function, function(err)
	--//	FormatError("Loading Error: %s", err)
	--//end, ...)
	local ran,err = pcall(Function, ...)

	if not ran then
		FormatError("Loading Error: %s", err)
	end
end

--// Returns the metadata for a given package
local function GetMetadata(Package: Folder)
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

--// For a given folder, returns a list of all packages within that folder which are intended to be ran by the server
--// Result table format: {[name .. "==" .. version] = package }
local function GetServerPackages(Packages: {})
	local found = {}

	debug("GET SERVER PACKAGES")

	for i,v in ipairs(Packages) do
		debug("CHECK PACKAGE FOR SERVER", v)

		if v:FindFirstChild("Server") then
			debug("IS SERVER PACKAGE", v)

			local metadata = GetMetadata(v)
			local pkgString = metadata.Name .. "==" .. metadata.Version

			debug("METADATA: ", metadata)
			debug("PKGSTRING: ", pkgString)

			if not found[pkgString] then
				found[pkgString] = v
			else
				FormatOut("Warning! Conflicting Name and Version for Package %s found!", pkgString)
			end
		end
	end
	return found
end

--// For a given folder, returns a list of all packages within that folder which are intended to be ran by the client
--// Result table format: {[name .. "==" .. version] = package }
local function GetClientPackages(Packages: {})
	local found = {}

	debug("GET CLIENT PACKAGES")

	for i,v in ipairs(Packages) do
		debug("FOUND PACKAGE", v)
		if v:FindFirstChild("Client") then
			local metadata = GetMetadata(v)
			local pkgString = metadata.Name .. "==" .. metadata.Version

			if not found[pkgString] then
				found[pkgString] = v
			else
				FormatOut("Warning! Conflicting Name and Version for Package %s found!", pkgString)
			end
		end
	end
	return found
end

--// Given a list of packages, this method will remove anything matching the provided "Remove" string and return a list of package clones without the removed object
--// This is primarily used to strip the "Server" folder from packages which are shared by the server and client before sending said packages to the client
local function StripPackages(Packages: {}, Remove: string)
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

--// Given a list of packages (Packages), a package name (DepedencyName), and a package version (DepdencyVersion)
--// Checks if any packages in the provided package list match the provided name and version
--// This is used during dependency resolution
local function FindDependency(Packages: {}, DependencyName: string, DependencyVersion)
	debug("FIND DEPENDENCY: ", Packages, DependencyName, DependencyVersion)

	for pkgString, pkg in pairs(Packages) do
		--debug("PKGSTRING", pkgString)
		--debug("PKG", pkg)

		local name = string.match(pkgString, "(.*)==")
		local version = string.match(pkgString, "==(.*)")

		--debug("NAME, VERSION", name, version)

		if name == DependencyName and (not DependencyVersion or DependencyVersion == version) then
			debug("RETURN; pkgString, pkg", pkgString, pkg)
			return pkgString, pkg
		end
	end
end

--// Given a list of packages (Packages) and a package (Package) checks if the package's depdencies are in the given package list
--// This is used when loading packages to check if a given package's dependencies were correctly resolved and loaded before attempting to load the package that needs them
local function CheckDependencies(Packages: {}, Package: Folder)
	local metadata = GetMetadata(Package)
	local dependencies = metadata.Dependencies

	debug("Checking package depdencies", Package)
	if dependencies then
		for i,depString in pairs(dependencies) do
			debugLine()

			local name = string.match(depString, "(.*)==") or depString
			local version = string.match(depString, "==(.*)")
			if not FindDependency(Packages, name, version) then
				debug("Dependency check failed")
				return false
			end
		end

		debug("Dependency check passed")
		return true
	else
		FormatError("Package %s is missing a dependencies list", metadata.Name)
	end
end

--// Given an ordered table of packages, checks if any packages match PackageName and PackageVersion
local function CheckResults(Ready: {}, PackageName: string, PackageVersion)
	for i,package in ipairs(Ready) do
		local metadata = GetMetadata(package)
		if metadata.Name == PackageName and (not PackageVersion or metadata.Version == PackageVersion) then
			return true
		end
	end
	return false
end

--// Recursively handles dependency resolution
local Resolve; Resolve = function(Packages: {}, ResultList: {}, Package: Folder, Chain)
	debug("RESOLVING: ", Package, Chain)

	local metadata = GetMetadata(Package)
	local pkgString = metadata.Name .. "==" .. metadata.Version
	local dependencies = metadata.Dependencies
	local chain = Chain or {}

	if chain[pkgString] then
		debug("PACKAGE ALREADY IN CHAIN")
		FormatError("Circular Dependency Error : One or more dependencies of %s is circular", pkgString)
		return nil
	else
		debug("NO CIRCULAR (CHAIN) CONFLICT")

		chain[pkgString] = true

		for i,depString in pairs(dependencies) do
			debugLine()
			debug("DEPENDENCY: ", depString)

			local name = string.match(depString, "(.*)==") or depString
			local version = string.match(depString, "==(.*)")
			local depPackageString, dep = FindDependency(Packages, name, version)

			if dep then
				debug("CHECK RESULTS")

				if not CheckResults(ResultList, name, version) then
					debug("RESOLVE DEP: ", dep, chain)
					Resolve(Packages, ResultList, dep, chain)
				end
			else
				FormatError("Could not resolve depedency %s for package %s", name .. "==" .. tostring(version), Package.Name)
			end
		end

		debug("CHECK RESULT", ResultList, pkgString)

		if not CheckResults(ResultList, metadata.Name, metadata.Version) then
			debug("ADD TO RESULTLIST", Package, ResultList)
			table.insert(ResultList, Package)
			debugLine()
		end
	end
end

--// Given a table of packages (Packages), Resolves package dependencies and produces an ordered list the places packages after all of their dependencies
--// The results of this method determine load order, based on depedency resolution
local function GetOrderedPackageList(Packages: {})
	local ResultList = {}

	debugLine()
	debug("GETTING ORDERED PACKAGE LIST", Packages)

	for i,v in pairs(Packages) do
		debug("RESOLVE PACKAGE: ", v)
		Resolve(Packages, ResultList, v)
		debugLine()
	end

	return ResultList
end

--// Given a package (Package) and a PackageType (Server, Client) this method will find and required the Initializer module for the given package and return the package's Init & AfterInit functions in a table
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
	end
end

--// Given a table of packages, performs dependency resolution and loads all packages provided matching PackageType in order.
local function LoadPackages(Packages: {}, PackageType: string, ...)
	local initFuncs = {}
	local loadedPackages = {}

	--// Organize packages according to their depdendencies
	local ordered = GetOrderedPackageList(Packages)

	debug("GOT ORDERED LIST", ordered)

	--// Load all packages
	for i, package in pairs(ordered) do
		if CheckDependencies(loadedPackages, package) then
			debug("LOAD PACKAGE", package)
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
		debug("INIT", v)
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
		debug("AFTERINIT", v)
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
	GetServerPackages = GetServerPackages;
	GetClientPackages = GetClientPackages;
	StripPackages = StripPackages;
	GetMetadata = GetMetadata;
	FindDependency = FindDependency;
	GetOrderedPackageList = GetOrderedPackageList;
	LoadPackages = LoadPackages;
}
