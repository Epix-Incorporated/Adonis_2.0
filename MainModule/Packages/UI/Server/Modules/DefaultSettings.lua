--[[

	Description: Package default settings declaration.
	Author: Sceleratis
	Date: 12/18/2021

--]]


local Root, Utilities, Service, Package;

local Settings = {
	Theme = "Default"
}

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		--// Do init
		for setting,data in pairs(Settings) do
			Root.Core:DeclareSetting(setting, data.DefaultValue, data.Description)
		end
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
	end;
}
