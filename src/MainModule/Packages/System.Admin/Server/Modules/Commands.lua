--[[

	Description: Command handling.
	Author: Sceleratis
	Date: 3/26/2022

--]]


local Root, Utilities, Service, Package;

--// Output
local Verbose = false
local function DebugWarn(...)
	if Verbose and Root and Root.Warn then
		Root.Warn(...)
	end
end

local Methods = {
	Command = {};
}

--[=[
	Command handler.
	@class Command
	@tag System.Admin
	@server
]=]

--[=[
	Sends data to the client-side handler for command.
	@method SendToClientSide
	@within Command
	@param player Player
	@param ... any?
]=]
function Methods.Command.SendToClientSide(self, player: Player, ...: any?)
	DebugWarn("SEND CLIENT SIDE", self)
	if self.CommandData and self.CommandIndex and self.CommandData.ClientSide then
		if typeof(player) == "Instance" and player:IsA("Player") then
			Root.Remote:Send(player, "RunClientSideCommand", self.CommandIndex, ...)
		elseif type(player) == "table" then
			for i,p in ipairs(player) do
				Root.Remote:Send(p, "RunClientSideCommand", self.CommandIndex, ...)
			end
		end
	end
end

--[=[
	Sends data to the client-side handler for command and gets a return.
	@method GetToClientSide
	@within Command
	@param player Player
	@param ... any?
]=]
function Methods.Command.GetFromClientSide(self, player: Player, ...: any?)
	DebugWarn("GET CLIENT SIDE", self)
	if self.CommandData and self.CommandIndex and self.CommandData.ClientSide then
		if typeof(player) == "Instance" and player:IsA("Player") then
			return Root.Remote:Get(player, "RunClientSideCommand", self.CommandIndex, ...)
		elseif type(player) == "table" then
			local results = {}
			for i,p in ipairs(player) do
				results[p] = { Root.Remote:Get(p, "RunClientSideCommand", self.CommandIndex, ...) }
			end
			return results
		end
	end
end

--[=[
	Responsible for administrative command handling.
	@class Server.Commands
	@server
	@tag System.Admin
]=]
local Commands = {
	Methods = Methods,
	DeclaredCommands = {},
	SharedSettings = {},
	ArgumentParsers = {
		["players"] = function(data, cmdArg, argText)
			return Root.Admin:GetPlayers(data, argText)
		end
	}
}

--[=[
	Responsible for command argument parsing.
	@method ParseArguments
	@within Server.Commands
	@param data {[string]: any} -- Command data
	@param cmdArgs {string} -- Table containing argument name strings
	@param argsText {string} -- Table containing player supplied argument text
	@return {[int]: any}
]=]
function Commands.ParseArguments(self, data: {[string]: any}, cmdArgs: {string}, argsText: {string}): {[int]: any}
	local result = {}
	for i,cmdArg in ipairs(cmdArgs) do
		local argText = argsText[i]
		if argText then
			local parser = (if data.CommandData and data.CommandData.Parsers then data.CommandData.Parsers[cmdArg] else nil) or self.ArgumentParsers[cmdArg]
			if parser then
				result[i] = parser(data, cmdArg, argText)
			end
		end
	end
	return result
end

--[=[
	Checks if the supplied player can run the supplied command.
	@method PlayerCanRunCommand
	@within Server.Commands
	@param player Player
	@param command CommandData
	@return boolean
]=]
function Commands.PlayerCanRunCommand(self, player: Player, command: {[string]: any}): boolean
	local checkRoles = if command.Roles and #command.Roles > 0 then command.Roles else nil
	local checkPerms = if command.Permissions and #command.Permissions > 0 then command.Permissions else nil

	DebugWarn("GOT ROLES", checkRoles)
	DebugWarn("GOT PERMS", checkPerms)

	if not checkPerms and not checkRoles then
		Root.Warn("Command missing roles or permissions definition", command)
	else
		DebugWarn("CHECKING PERMISSIONS")

		if Root.Permissions:HasPermission(player, "PermissionOverride") then
			DebugWarn("PERMISSION OVERRIDE")
			return true
		end

		if checkPerms and Root.Permissions:HasPermissions(player, checkPerms) then
			DebugWarn("HAS PERMS")
			return true
		end

		if checkRoles and Root.Roles:HasRoles(player, checkRoles) then
			DebugWarn("HAS ROLES")
			return true
		end
	end

	DebugWarn("MISSING PERMISSIONS")
	return false
end

--[=[
	Finds the command associated with the supplied string.
	@method FindCommand
	@within Server.Commands
	@param str string
	@return CommandData
]=]
function Commands.FindCommand(self, str: string): {[string]: any}
	local cached = self.CommandCache:GetData(str)
	if cached then
		DebugWarn("CACHED COMMAND FOUND; RETURNING")
		return cached
	else
		for index,data in pairs(self.DeclaredCommands) do
			DebugWarn("CHECKING COMMAND", index, data)
			if not data.Prefix or data.Prefix == "" or string.sub(str, 1, 1) == data.Prefix then
				DebugWarn("CHECKING ALIASES")
				for i,alias in ipairs(data.Aliases) do
					DebugWarn("CHECKING ALIAS MATCH")
					warn("DATA", data)
					if (data.Prefix or '') .. string.lower(alias) == string.lower(str) then
						DebugWarn("RETURNING ALIAS MATCH")
						local result = { Index = index, Data = data, Alias = alias }
						self.CommandCache:SetData(str, result)
						return result
					end
				end
			end
		end
	end
end

--[=[
	Given a message string, extracts the desired command and command arguments.
	@method ExtractCommandStrings
	@within Server.Commands
	@param message string
	@return {CommandData}
]=]
function Commands.ExtractCommandStrings(self, message: string): {[int]:{[string]: any}}
	local foundCommands = {}
	local cmdStrings = Utilities:SplitString(message, Root.Settings.BatchChar, true)
	for i,cmdString in ipairs(cmdStrings) do
		local msgArgs = Utilities:SplitString(cmdString, Root.Settings.SplitChar, true)
		local cmdSub = msgArgs[1]
		local cmdArgs = Utilities:TableSub(msgArgs, 2)

		table.insert(foundCommands, {
			Command = cmdSub,
			Arguments = cmdArgs,
			FullArgs = msgArgs
		})
	end
	return foundCommands
end

--[=[
	Runs the supplied command using the supplied data and additional parameters tuple.
	@method RunCommand
	@within Server.Commands
	@param command CommandData
	@param data AdditionalCommandData
	@param ... any
	@return any?
]=]
function Commands.RunCommand(self, command: {[string]: any}, data: {[string]: any}, ...: any): any?
	local serverFunc = command.Function or command.ServerSide
	DebugWarn("SERVER FUNC?", serverFunc)

	if serverFunc then
		local newData = Utilities:MergeTables({}, data, Methods.Command)

		Utilities.Events.CommandRan:Fire(command, data, ...)

		Root.Logging:AddLog("Command", {
			Text = tostring(data.Player or "Unknown").. ": " .. data.Message or "Unknown",
			Description = data.Message,
			Data = data
		})

		if data.Arguments and data.CommandData.Arguments then
			newData.ParsedArguments = self:ParseArguments(data, data.CommandData.Arguments, data.Arguments)
		end

		DebugWarn("GOT SERVER FUNC; RUNNING", serverFunc, newData)

		return xpcall(serverFunc, function(err)
			if data.Player then
				Root.Remote:SendError(data.Player, err)
			end

			Root.Logging:AddLog("Error", {
				Text = "Error encountered while running command at index ".. (data.CommandIndex or "Unknown"),
				Description = err,
				CommandData = data,
				ErrorMessage = err
			})
		end, newData, ...)
	else
		Root.Warn("Command missing 'Function'", {
			Command = command,
			Data = data
		})
	end
end

--[=[
	Responsible for the processing of player command messages.
	@method RunCommandFromMessage
	@within Server.Commands
	@param player Player
	@param message string
	@param additionalData {}
	@return any?
]=]
function Commands.RunCommandFromMessage(self, player: Player, message: string, additionalData: {}): any?
	DebugWarn("RUN COMMAND FROM MESSAGE", player, message, additionalData)

	local extractedCommands = self:ExtractCommandStrings(message)

	DebugWarn("EXTRACTED COMMANDS: ", extractedCommands)

	for _,cmdStrData in ipairs(extractedCommands) do
		DebugWarn("CHECKING EXTRACTED COMMAND STRING DATA", cmdStrData)

		local foundCommand = self:FindCommand(cmdStrData.Command)
		local command = if foundCommand then foundCommand.Data else nil
		if command and self:PlayerCanRunCommand(player, command) then
			DebugWarn("PLAYER CAN RUN COMMAND")

			local numArgs = #command.Arguments
			local args = if numArgs > 0 then Utilities:TableSub(cmdStrData.Arguments, 1, math.max(1, numArgs, numArgs-1)) else {}

			if #cmdStrData.Arguments > #args then
				table.insert(args, Utilities:JoinStrings(Root.Settings.SplitChar, table.unpack(cmdStrData.Arguments, numArgs)))
			end

			DebugWarn("GOT CMD DATA; DOING RUNCOMMAND", command, numArgs, args)

			return self:RunCommand(command, {
				Player = player,
				Message = message,
				Arguments = args,
				CommandIndex = foundCommand.Index,
				CommandData = command,
				FoundCommand = foundCommand,
				AdditionalData = additionalData,
				ExtractedCommands = extractedCommands,
				CommandStringData = cmdStrData
			}, args)
		end
	end
end

--[=[
	Updates settings proxies in the provided table to their runtime values.
	@method UpdateSettingProxies
	@within Server.Commands
	@param data {[any]: any}
]=]
function Commands.UpdateSettingProxies(self, data: {[any]: any})
	for i,v in pairs(data) do
		if type(v) == "table" and v.__ROOT_PROXY then
			local dest = Utilities:GetTableValueByPath(Root, v.Path)
			local setting = dest and dest.Value and dest.Value[v.Index]
			if setting ~= nil then
				data[i] = setting
			else
				Root.Warn("Cannot update setting definition: Setting not found :: ", v.Index)
			end
		elseif type(v) == "table" then
			self:UpdateSettingProxies(v)
		end
	end
end

--[=[
	Declares a command.
	@method DeclareCommand
	@within Server.Commands
	@param CommandIndex string -- Command table index
	@param data {[string]: any} -- Command data
]=]
function Commands.DeclareCommand(self, CommandIndex: string, data: {[string]: any})
	if self.DeclaredCommands[CommandIndex] then
		Root.Warn("CommandIndex \"".. CommandIndex .."\" already delcared. Overwriting.")
	end

	self:UpdateSettingProxies(data)
	self.DeclaredCommands[CommandIndex] = data

	Utilities.Events.CommandDeclared:Fire(CommandIndex, data)
end


--// Return initializer
return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		--// Do init
		Root.Commands = Commands

		Commands.CommandCache = Utilities:MemoryCache({
			Timeout = 30,
			AccessResetsTimer = false
		})
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
		--Utilities.Events.PlayerReady:Connect(function(p)
			--Root.Remote:Send(p, "FinishCommandDeclarations", Root.Core:GetSharedSettings(p))
		--end)
		Utilities.Events.PlayerChatted:Connect(function(p, message)
			Root.Commands:RunCommandFromMessage(p, message)
		end)
	end;
}
