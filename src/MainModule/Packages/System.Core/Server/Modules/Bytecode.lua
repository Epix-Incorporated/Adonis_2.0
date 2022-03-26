--[[

	Description: Contains bytecode/loadstring-related functionality
	Author: Sceleratis
	Date: 12/11/2021

--]]

local Root, Package, Utilities, Service;

--- Bytecode-related functionality.
--- @class Server.Bytecode
--- @server
--- @tag Core
--- @tag Package: System.Core
local Bytecode = {}


--- Clones and requires the loadstring module, returning it's main function.
--- @method GetLoadstring
--- @within Server.Bytecode
--- @return function
function Bytecode.GetLoadstring(self)
	local module = Package.Assets.Loadstring:Clone() :: ModuleScript
	local vEnvModule = Root.Bytecode:GetVirtualEnv(true) :: ModuleScript
	local fiOne = Package.SharedAssets.FiOne:Clone() :: ModuleScript

	fiOne.Parent = module
	vEnvModule.Parent = module

	return require(module)
end


--- Given a string of lua code, returns bytecode.
--- @method GetBytecode
--- @within Server.Bytecode
--- @param str string -- Lua code to convert to bytecode equivalent
--- @return Bytecode
function Bytecode.GetBytecode(self, str: string)
	local loadstring = self.Loadstring or self:GetLoadstring()
	local f, buff = loadstring(str)

	return buff
end


--- Gets a virtual env instead of a function env to not disable optimisations
--- @method GetVirtualEnv
--- @within Server.Bytecode
--- @param returnInstance bool
--- return environment
function Bytecode.GetVirtualEnv(self, returnInstance)
	local vEnvModule = Package.SharedAssets.VirtualEnv:Clone() :: ModuleScript
	return returnInstance == true and vEnvModule or returnInstance == false and require(vEnvModule)()
end


--- Load bytecode
--- @method LoadBytecode
--- @within Server.Bytecode
--- @param bytecode string
--- @param envData table -- Environment
--- @return result
function Bytecode.LoadBytecode(self, bytecode: string, envData: {})
	local fiOneMod = Package.SharedAssets.FiOne:Clone()
	local fiOne = require(fiOneMod)

	return fiOne(bytecode, envData)
end


--//// Return initializer
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
