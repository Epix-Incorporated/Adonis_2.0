--[[

	Description:
	Author:
	Date:

--]]


local Root, Utilities, Service, Package;

local Commands = {
}

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		--// Do init
		Root.Commands = Commands
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
	end;
}
