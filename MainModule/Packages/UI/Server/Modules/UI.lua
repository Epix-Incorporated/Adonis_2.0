--[[

	Description:
	Author:
	Date:

--]]


local Root, Utilities, Service, Package;

local Remote = {
	--// TODO: Server-side UI things for Remote
}

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		--// Do init
		Utilities:MergeTables(Root.Remote, Remote);
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
	end;
}
