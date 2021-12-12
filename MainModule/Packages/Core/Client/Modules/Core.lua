--[[

	Description: Contains various variables & methods required for core functionality
	Author: Sceleratis
	Date: 12/05/2021
	
--]]

local Root;
local Package;
local Utilities;
local Service;

local Core = {

}

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		Root.Core = Core
	end;

	AfterInit = function(Root, Package)

	end;
}