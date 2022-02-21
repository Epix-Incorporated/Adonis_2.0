--[[
	
	Description: 
	Author:
	Date:

--]]


local Root, Utilities, Service, Package;



return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Utilities = Root.Utilities
		Package = cPackage
		Service = Root.Utilities.Services

		--// Do init
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
	end;
}