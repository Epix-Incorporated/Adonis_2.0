--[[

	Description:
	Author:
	Date:

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
	Command = {
		SendClientSide = function(self, player: Player, ...)
			DebugWarn("SEND CLIENT SIDE", self)
			if self.CommandData and self.CommandIndex and self.CommandData.ClientSide then
				Root.Remote:Send(player, "RunClientSideCommand", self.CommandIndex, ...)
			end
		end,

		GetClientSide = function(self, player: Player, ...)
			DebugWarn("GET CLIENT SIDE", self)
			if self.CommandData and self.CommandIndex and self.CommandData.ClientSide then
				Root.Remote:Get(player, "RunClientSideCommand", self.CommandIndex, ...)
			end
		end,
	}
}

local Commands = {
	Methods = Methods,
	DeclaredCommands = {},
	SharedSettings = {},
	ArgumentParsers = {
		Players = function(data, cmdArgData, argText)

		end
	},

	ParseArguments = function(self, data: {}, cmdArgs: {})
		local result = {}
		local textArgs = data.Arguments
		for i,cmdArgData in ipairs(cmdArgs) do
			local textArg = textArgs[i]
			if textArg then
				if type(cmdArgData) == "table" then
					local parser = self.ArgumentParsers[cmdArgData.Type]
					if parser then
						local parseResult = parser(data, cmdArgData, textArg)
						result[i] = if parseResult ~= nil then parseResult else textArg
					end
				else
					result[i] = textArg
				end
			end
		end

		return result
	end,

	PlayerCanRunCommand = function(self, player: Player, command: {})
		local checkRoles = command.Roles and #command.Roles > 0 and command.Roles
		local checkPerms = command.Permissions and #command.Permissions > 0 and command.Permissions

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
	end,

	FindCommand = function(self, str: string)
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
						if data.Prefix .. string.lower(alias) == string.lower(str) then
							DebugWarn("RETURNING ALIAS MATCH")
							local result = { Index = index, Data = data, Alias = alias }
							self.CommandCache:SetData(str, result)
							return result
						end
					end
				end
			end
		end
	end,

	ExtractCommandStrings = function(self, message: string)
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
	end,

	RunCommand = function(self, command: {}, data: {}, ...)
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
				newData.ParsedArguments = self:ParseArguments(data, data.CommandData.Arguments)
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
				Data = data,
				Player = player,
				Arguments = args
			})
		end
	end,

	RunCommandFromMessage = function(self, player: Player, message: string, additionalData: {})
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
	end,

	UpdateSettingProxies = function(self, data)
		for i,v in pairs(data) do
			if type(v) == "table" and v.__SETTING_PROXY then
				local setting = Root.Settings[v.Index]
				if setting then
					data[i] = Root.Settings[v.Index]
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

		self:UpdateSettingProxies(data)
		self.DeclaredCommands[CommandIndex] = data

		Utilities.Events.CommandDeclared:Fire(CommandIndex, data)
	end
}

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

		--// Declare command-related settings
		Root.Core:DeclareSetting("Prefix", {
			DefaultValue = ":",
			Description = "Character that must appear at the start of a message to indicate it is a command",
			Package = Package,
			ShareWithClient = true
		})

		Root.Core:DeclareSetting("SplitChar", {
			DefaultValue = " ",
			Description = "Character used when splitting command strings into arguments.",
			Package = Package,
			ShareWithClient = true
		})

		Root.Core:DeclareSetting("BatchChar", {
			DefaultValue = "~|~",
			Description = "Character used to break up command strings into multiple command strings.",
			Package = Package,
			ShareWithClient = true
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
