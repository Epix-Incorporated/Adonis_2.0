--[[
	
	Description: Responsible for initializing client-side packages
	Author: Sceleratis
	Date: 12/05/2021
	
--]]

--// Precursory variables/functions
local oWarn = warn

local function warn(...)
	oWarn(":: Adonis Client ::", ...)
end

local function addRange(tab, ...)
	table.foreachi(table.pack(...), function(i,t)
		table.foreachi(t, function(k,v)
			table.insert(tab, v)
		end)
	end)
end

--// Table shared with all packages which acts as the root table for all others
local Root = {
	Verbose = true;
	Packages = {};
	PackageHandlerModule = script.PackageHandler;
	
	Utilities = {
		Warn = warn;
		AddRange = addRange;
	};
}

--// Client Loading Process
do
	--// Set variables
	local start = os.clock()
	
	--// Set parent
	repeat task.wait(0.01); script.Parent = nil; until script.Parent == nil
	
	--// Begin loading
	warn("Loading packages...")

	--// Get all packages
	addRange(Root.Packages, script.Packages:GetChildren())

	--// Get PackageHandler
	local PackageHandler = require(Root.PackageHandlerModule)
	
	--// Set root variables
	Root.PackageHandler = PackageHandler

	--// Get server packages
	local Packages = PackageHandler.GetClientPackages(Root.Packages)

	--// Load server packages
	PackageHandler.LoadPackages(Packages, "Client", Root, Packages)

	--// Loading complete
	warn("Loading complete; Elapsed:", os.clock() - start)

end
