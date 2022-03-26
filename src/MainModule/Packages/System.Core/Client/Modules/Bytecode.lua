--[[

	Description: Contains bytecode/loadstring-related functionality
	Author: Sceleratis
	Date: 12/11/2021

--]]

local Root, Package, Utilities, Service


--- Bytecode-related functionality.
--- @class Client.Bytecode
--- @tag Core
--- @tag Package: System.Core
--- @client

local Bytecode = {}
local RemoteCommands = {}


--// Bytecode Methods

--- Gets a virtual env instead of a function env to not disable optimisations
--- @method GetVirtualEnv
--- @within Client.Bytecode
--- @param returnInstance Instance
function Bytecode.GetVirtualEnv(self, returnInstance: boolean): Instance
	local vEnvModule = Package.SharedAssets.VirtualEnv:Clone() :: ModuleScript
	return returnInstance == true and vEnvModule or returnInstance == false and require(vEnvModule)()
end

--- Load bytecode
--- @method LoadBytecode
--- @within Client.Bytecode
function Bytecode.LoadBytecode(self, bytecode: string, envData: {}): ()
	local fiOneMod = Package.SharedAssets.FiOne:Clone()
	local fiOne = require(fiOneMod)
	return fiOne(bytecode, envData)
end


--// Remote Commands
--- Run bytecode
--- @function RunBytecode
--- @within Client.Remote.Commands
--- @tag System.Core
--- @param str string -- Bytecode to execute
--- @param ... any -- Additional arguments
--- @return any -- Anything returned by executed bytecode
RemoteCommands.RunBytecode = function(str: string, ...: any): any
	Utilities.Events.RunningBytecode:Fire(str, ...)
	return Root.Bytecode:LoadBytecode(str, Utilities:MergeTables(Root.ByteCode:GetVirtualEnv(false), {
		Root = Root,
		script = Instance.new("LocalScript"),
		Data = table.pack(...)
	}))()
end

--// Return initializer
return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		Root.Bytecode = Bytecode
	end;

	AfterInit = function(Root, Package)
		Utilities:MergeTables(Root.Remote.Commands, RemoteCommands)
	end;
}
