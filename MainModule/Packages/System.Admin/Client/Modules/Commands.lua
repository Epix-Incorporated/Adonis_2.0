--[[

	Description: ClientSide command handler.
	Author: Sceleratis
	Date: 12/25/2021

--]]


local Root, Utilities, Service, Package;

--// Output
local Verbose = false
local function DebugWarn(...)
	if Verbose and Root and Root.Warn then
		Root.Warn(...)
	end
end

local RemoteCommands = {
	RunClientSideCommand = function(cmdIndex: string, ...)
		DebugWarn("DO CLIENT SIDE COMMAND", cmdIndex, ...)
		local foundCommand = Root.Commands.DeclaredCommands[cmdIndex]
		if foundCommand and foundCommand.ClientSide then
			DebugWarn("FOUND CLIENT SIDE COMMAND, RUNNING", foundCommand)
			return foundCommand.ClientSide(...)
		end
	end,

	FinishCommandDeclarations = function(settings)
		DebugWarn("FINISH DECLARATION", settings)
		if settings then
			Utilities:MergeTables(Root.Settings, settings)
		end

		for ind,data in pairs(Root.Commands.DeclaredCommands) do
			Root.Commands:UpdateSettingProxies(data)
		end
	end
}

local Commands = {
	DeclaredCommands = {},

	UpdateSettingProxies = function(self, data)
		DebugWarn("UPDATING COMMAND SETTING PROXIES", data)

		for i,v in pairs(data) do
			if type(v) == "table" and v.__ROOT_PROXY then
				local dest = Utilities:GetTableValueByPath(Root, v.Path)
				local setting = dest and dest.Value and dest.Value[v.Index]
				if setting then
					data[i] = setting
				else
					Root.Warn("Cannot update setting definition: Setting not found :: ", v.Index)
				end
			elseif type(v) == "table" then
				self:UpdateSettingProxies(v)
			end
		end
	end,

	DeclareCommand = function(self, CommandIndex: string, data: {})
		if self.DeclaredCommands[CommandIndex] then
			Root.Warn("CommandIndex \"".. CommandIndex .."\" already delcared. Overwriting.")
		end

		self.DeclaredCommands[CommandIndex] = data

		Utilities.Events.CommandDeclared:Fire(CommandIndex, data)

		DebugWarn("DECLARED NEW COMMAND", CommandIndex, data)
	end,
}

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		--// Do init
		Root.Commands = Commands

		Utilities:MergeTables(Root.Remote.Commands, RemoteCommands)
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
	end;
}
