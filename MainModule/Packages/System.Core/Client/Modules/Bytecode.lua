--[[

	Description: Contains bytecode/loadstring-related functionality
	Author: Sceleratis
	Date: 12/11/2021

--]]

local Root, Package, Utilities, Service

local RemoteCommands = {
	RunBytecode = function(str, ...)
		Utilities.Events.RunningBytecode:Fire(str, ...)
		return Root.Bytecode:LoadBytecode(str, Utilities:MergeTables(Root.ByteCode:GetVirtualEnv(false), {
			Root = Root,
			script = Instance.new("LocalScript"),
			Data = table.pack(...)
		}))()
	end,
}
local Bytecode = {

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
		Utilities:MergeTables(Root.Remote.Commands, RemoteCommands)
	end;
}
