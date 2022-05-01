--[[

	Description: Shared command declaration. Should not be used for commands with sensitive/not public server-side code.
	Author: Sceleratis
	Date: 12/25/2021

--]]


local Root, Utilities, Service, Package;
local Settings = setmetatable({}, {
	__index = function(self, ind)
		return { __ROOT_PROXY = true, Path = "Settings", Index = ind }
	end
})

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


local DeclareCommands = {
	ViewCommands = {
		Prefix = Settings.Prefix,
		Aliases = { "cmds", "commands" },
		Arguments = {},
		Roles = {},
		Permissions = { "Player" },
		Description = "Displays all declared commands.",
		ServerSide = function(data: {})
			local plr = data.Player
			local args = data.Arguments
			local parsed = data.ParsedArguments
			local commands = Root.Commands.DeclaredCommands

			local function getCommandList()
				local resultList = {}
				for index,command in pairs(commands) do
					if Root.Commands:PlayerCanRunCommand(plr, command) then
						local mainText = (command.Prefix or '') .. command.Aliases[1]
						local roleString = ''
						local permString = ''
						local subText = nil

						if command.Arguments then
							for i,arg in ipairs(command.Arguments) do
								mainText = mainText .. Root.Settings.SplitChar .. "<" .. arg .. ">"
							end
						end

						if command.Permissions then
							for i,perm in ipairs(command.Permissions) do
								permString = permString ..'; '.. perm
							end
						end

						if command.Roles then
							for i,role in ipairs(command.Roles) do
								roleString = roleString ..';'.. role
							end
						end

						subText = [[
							Example: ]].. mainText .."\n"..[[
							Description: ]].. (command.Description or '') .."\n"..[[
							Roles: ]].. roleString .."\n"..[[
							Permissions: ]].. permString

						table.insert(resultList, {
							Text = mainText,
							Expanded = subText
						})
					end
				end
				return resultList
			end

			local session = Root.Remote:NewSession({plr})
			local sessionKey = session.SessionKey
			local sessionEvent; sessionEvent = session:Connect(function(p, cmd, data)
				warn("GOT DATA?", p, cmd, data)
				if cmd == "Refresh" then
					session:SendToUser(p, "Refresh", getCommandList())
				end
			end)

			data:SendClientSide(sessionKey, getCommandList())
		end,
		ClientSide = function(sessionKey, cmdData)
			Root.UI:LoadModule({
				Name = "List"
			}, {
				Title = "Commands",
				List = cmdData,
				Refresh = sessionKey
			})
		end,
	},

	DebugTest = {
		Prefix = Settings.Prefix,
		Aliases = { "debugtest", "debugtest2" },
		Arguments = { "players", "testarg2", "testarg3" },
		Parsers = {
			testarg2 = function(data, cmdArg, text)
				warn("PARSE ARG", data, cmdArg, text)
				return text
			end
		},
		Description = "Test command",
		Permissions = { "Player" },
		Roles = {},
		ServerSide = function(data: {})
			local plr = data.Player
			local args = data.Arguments
			local parsed = data.ParsedArguments

			warn("Success!", {
				Player = plr,
				Args = args,
				Parsed = parsed,
				Data = data
			})

			data:SendToClientSide(plr, args)
			warn("ClientGet Test", data:GetFromClientSide(plr, args))
		end,

		ClientSide = function(...)
			warn("Client Success!", ...)

			Root.UI:NewElement("Window", {Theme = "Default"}, {
				Title = "Test";
			});

			return "WE GOT THIS FROM THE CLIENT!"
		end
	}
}

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		for ind, data in pairs(DeclareCommands) do
			Root.Commands:DeclareCommand(ind, data)
		end
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
	end;
}
