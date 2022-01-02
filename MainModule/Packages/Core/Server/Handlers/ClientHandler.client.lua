--[[

	Description: Responsible for initializing client-side packages
	Author: Sceleratis
	Date: 12/05/2021

--]]

--// Precursory variables/functions
local AppName = "Adonis Client"
local oWarn = warn

local function warn(...)
	oWarn(":: ".. AppName .." ::", ...)
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
	AppName = AppName;
	Verbose = false;
	Packages = {};
	Globals = {};
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
	if Root.Verbose then warn("Loading packages...") end

	--// Get all packages
	addRange(Root.Packages, Root.PackagesFolder:GetChildren())

	--// Get PackageHandler
	local PackageHandler = require(Root.PackageHandlerModule)

	--// Set root variables
	Root.PackageHandler = PackageHandler

	--// Get server packages
	local Packages = PackageHandler.GetClientPackages(Root.Packages)

	--// Load server packages
	PackageHandler.LoadPackages(Packages, "Client", Root, Packages)

	--// Loading complete
	warn("Loading complete :: Elapsed:", os.clock() - start)

end
