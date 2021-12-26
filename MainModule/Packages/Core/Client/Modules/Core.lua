--[[

	Description: Contains various variables & methods required for core functionality
	Author: Sceleratis
	Date: 12/05/2021

--]]

local Root, Package, Utilities, Service

local Core = {

}

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		--// Do init
		Root.Core = Core
		Root.Timeouts = {}
		Root.Settings = {}
		Root.Cache = Utilities:MemoryCache({ Timeout = 0 })
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
	end;
}
