--# selene: allow(incorrect_standard_library_use)
--[[

	Description: Responsible for initializing client-side packages
	Author: Sceleratis
	Date: 12/05/2021

--]]

--// Precursory variables/functions
local AppName = "Adonis Client"
local Verbose = false
local oWarn = warn
local oError = error
local oPrint = print

local function warn(...)
	oWarn(":: ".. AppName .." ::", ...)
end

local function error(reason: any?, level: number?)
	if level ~= nil and type(level) ~= "number" then
		oError(string.format(":: %s :: bad argument #2 to 'error' (number expected, got %s)", AppName, type(level)), 2)
	end

	oError(":: PackageHandler :: "..tostring(reason), (level or 1) + 1)
end

local function print(...)
	oPrint(":: ".. AppName .." ::", ...)
end

local function DebugWarn(...)
	if Verbose then
		warn("Debug ::", ...)
	end
end

local function addRange(tab, ...)
	for i,t in ipairs(table.pack(...)) do
		for k,v in ipairs(t) do
			table.insert(tab, v)
		end
	end
	return tab
end

--// Table shared with all packages which acts as the root table for all others
local Root = {
	Warn = warn;
	Error = error;
	Print = print;
	DebugWarn = DebugWarn;
	AppName = AppName;
	Verbose = Verbose;
	Globals = {};
	Packages = {};
	Libraries = {};
	LibraryObjects = {};
	PackageHandlerModule = script:WaitForChild("PackageHandler");
	PackagesFolder = script:WaitForChild("Packages");
}

--// Client Loading Process
do
	--// Set variables
	local start = os.clock()

	--// Set parent
	repeat task.wait(0.01); script.Parent = nil; until script.Parent == nil

	--// Begin loading
	DebugWarn("Loading packages...")

	--// Get all packages
	addRange(Root.Packages, Root.PackagesFolder:GetChildren())

	--// Get PackageHandler
	local PackageHandler = require(Root.PackageHandlerModule)

	--// Set root variables
	Root.PackageHandler = PackageHandler

	--// Get client packages
	local Packages = PackageHandler.GetPackages(Root.Packages)

	--// Load client packages
	PackageHandler.LoadPackages(Packages, "Client", Root, Packages)

	--// Loading complete
	print("Loading complete :: Elapsed:", os.clock() - start)
end
