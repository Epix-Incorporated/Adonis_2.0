--[[

	Description: Contains bytecode/loadstring-related functionality
	Author: Sceleratis
	Date: 12/11/2021
	
--]]

local Root, Package, Utilities, Service

local Bytecode = {
	
	--// Load bytecode
	LoadBytecode = function(self, bytecode: string, envData: {})
		local fiOneMod = Package.SharedAssets.FiOne:Clone()
		local fiOne = require(fiOneMod)

		return fiOne(bytecode, envData)
	end,
	
}

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services
		
		Root.Bytecode = Bytecode
	end;

	AfterInit = function(Root, Package)
		
	end;
}
