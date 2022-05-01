--[[

	Description: ClientSide command handler.
	Author: Sceleratis
	Date: 12/25/2021

--]]


local Root, Utilities, Service, Package;
local RemoteCommands = {}
local Commands = { DeclaredCommands = { } }


--// Output
local Verbose = false
local oWarn = warn;

local function warn(...)
	if Root and Root.Warn then
		Root.Warn(...)
	else
		oWarn(":: ".. script.Name .." ::", ...)
	end
end

local function DebugWarn(...)
	if Verbose then
		warn("Debug ::", ...)
	end
end



--- Responsible for client-side command handling.
--- @class Client.Commands
--- @client
--- @tag Package: System.Admin


--//// Remote commands

--- Launches the client-side portion of commands.
--- @function RunClientSideCommand
--- @within Client.Remote.Commands
--- @param cmdIndex string -- Command index
--- @param ... any -- Command function parameters
--- @return result
--- @tag System.Admin
function RemoteCommands.RunClientSideCommand(cmdIndex: string, ...)
	DebugWarn("DO CLIENT SIDE COMMAND", cmdIndex, ...)
	local foundCommand = Root.Commands.DeclaredCommands[cmdIndex]
	if foundCommand and foundCommand.ClientSide then
		DebugWarn("FOUND CLIENT SIDE COMMAND, RUNNING", foundCommand)
		return foundCommand.ClientSide(...)
	end
end


--- Declares settings to the client and updates command declaration setting proxies to correct values.
--- @function FinishCommandDeclarations
--- @within Client.Remote.Commands
--- @param settings table -- Table containing settings sent by the server.
--- @tag System.Admin
function RemoteCommands.FinishCommandDeclarations(settings)
	DebugWarn("FINISH DECLARATION", settings)
	if settings then
		Utilities:MergeTables(Root.Settings, settings)
	end

	for ind,data in pairs(Root.Commands.DeclaredCommands) do
		Root.Commands:UpdateSettingProxies(data)
	end
end



--//// Commands methods

--- Used by commands as a stand-in during definition for settings such as the command prefix. Navigates to a specified path, starting from Root.
--- @interface SettingProxy
--- @within Client.Commands
--- @field __ROOT_PROXY boolean -- Identifies that this is a proxy object.
--- @field Path string -- Path string (eg: "Settings"  will resolve to Root.Settings)
--- @field Index string -- When the destination table is reached, as indicated by path, said table will be indexed using Index as its key.

--- Updates command settings proxies to their associated values in Root.Settings
--- @method UpdateSettingsProxies
--- @within Client.Commands
--- @param data table -- SettingProxy
function Commands.UpdateSettingProxies(self, data)
	DebugWarn("UPDATING COMMAND SETTING PROXIES", data)

	for i,v in pairs(data) do
		if type(v) == "table" and v.__ROOT_PROXY then
			local dest = Utilities:GetTableValueByPath(Root, v.Path)
			local setting = dest and dest.Value and dest.Value[v.Index]
			if setting then
				data[i] = setting
			else
				warn("Cannot update setting definition: Setting not found :: ", v.Index)
			end
		elseif type(v) == "table" then
			self:UpdateSettingProxies(v)
		end
	end
end


--- Declares a command or overwrites an existing declaration for the same CommandIndex.
--- @method DeclareCommand
--- @within Client.Commands
--- @param CommandIndex string -- Command index.
--- @param data {} -- Command data table
function Commands.DeclareCommand(self, CommandIndex: string, data: {})
	if self.DeclaredCommands[CommandIndex] then
		warn("CommandIndex \"".. CommandIndex .."\" already delcared. Overwriting.")
	end

	self.DeclaredCommands[CommandIndex] = data

	Utilities.Events.CommandDeclared:Fire(CommandIndex, data)

	DebugWarn("DECLARED NEW COMMAND", CommandIndex, data)
end



--//// Return initializer
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
