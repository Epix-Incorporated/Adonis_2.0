--[[

	Description: Contains bytecode/loadstring-related functionality
	Author: Sceleratis
	Date: 12/11/2021
	
--]]

local Root, Package, Utilities, Service;

local Bytecode = {

	--// Get loadstring function
	GetLoadstring = function(self)
		local module = Package.Assets.Loadstring:Clone() :: ModuleScript
		local vEnvModule = Package.SharedAssets.VirtualEnv:Clone() :: ModuleScript
		local fiOne = Package.SharedAssets.FiOne:Clone() :: ModuleScript

		fiOne.Parent = module
		vEnvModule.Parent = module

		return require(module)
	end,

	--// Get bytecode for str
	GetBytecode = function(self, str: string)
		local loadstring = self.Loadstring or self:GetLoadstring()
		local f, buff = loadstring(str)
		
		return buff
	end,

	-- // Gets a virtual env instead of a function env to not disable optimisations
	GetVirtualEnv = function(self, returnInstance)
		local vEnvModule = Package.SharedAssets.VirtualEnv:Clone() :: ModuleScript
		return returnInstance == true and vEnvModule or returnInstance == false and require(vEnvModule)()
	end

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
		Bytecode.Loadstring = Bytecode:GetLoadstring()
	end;
}
