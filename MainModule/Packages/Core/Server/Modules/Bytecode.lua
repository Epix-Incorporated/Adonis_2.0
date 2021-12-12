--[[

	Description: Contains bytecode/loadstring-related functionality
	Author: Sceleratis
	Date: 12/11/2021
	
--]]

local Root;
local Package;
local Utilities;
local Service;

local Bytecode = {
	
	--// Get loadstring function
	GetLoadstring = function(self)
		local module = Package.Assets.Loadstring:Clone();
		local fiOne = Package.SharedAssets.FiOne:Clone();
		
		fiOne.Parent = module;
		
		return require(module);
	end,
	
	--// Get bytecode for str
	GetBytecode = function(self, str: string)
		local loadstring = self.Loadstring or self:GetLoadstring();
		local f, buff = loadstring(str);
		
		return buff;
	end,
	
	--// Load bytecode
	LoadBytecode = function(self, bytecode: string, envData: table)
		local fiOneMod = Package.SharedAssets.FiOne:Clone();
		local fiOne = require(fiOneMod);
		
		return fiOne(bytecode, envData);
	end,
	
}

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services
		
		Root.Bytecode = Bytecode;
	end;
	
	AfterInit = function(Root, Package)
		Bytecode.Loadstring = Bytecode:GetLoadstring();
	end;
}