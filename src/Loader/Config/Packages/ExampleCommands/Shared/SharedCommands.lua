--[[

	Description: Command declaration.
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
	--// Since this is in a shared module, everything in this module will be seen to both the server and the client.
	--// This allows us to define code intended for the client alongside code intended for the server.
	--// This method of command definition should not be used for any commands that contain sensitive code/information and should not be seen by normal players.
	--// Everything in this module (and any client module) should be treated as public information.
	--// Assume that any non-admin user will be able to see this regardless of whether or not they have edit access to the game.
	--// This is a non-issue for open source commands (such as those built-in) which are publicly viewable anyway.
	--// If you wish to hide the server portion of your definition, please refer to PackageFolder > Server > Modules > ServerOnlyAndPartial.lua
	--// There you will find commands that demonstrate both a server-only definition as well as a split partial definition.
	TestCommand = {
		Prefix = Settings.Prefix,
		Aliases = { "testcommand", "example" },
		Arguments = { "players", "testarg2", "testarg3", "someNumber"},
		Parsers = {
			--// Parsers are command-author-defined argument parsers/validators
			--// If a parser is not defined for an arg, the raw argument text supplied by the player will be used instead
			["testarg2"] = function(data, cmdArg, text)
				warn("PARSE ARG", data, cmdArg, text)
				return {
					Success = true,
					Result = "PARSING RESULT HERE"
				}
				--[[
					If Errored:
					return {
						Success = false,
						Error = "PARSING ERROR HERE" -- Aborts the entire command before it runs if parsing fails
					}
				--]]
			end,

			["players"] = function(...)
				return Root.Commands.ArgumentParsers.players(...)
			end,

			["someNumber"] = function(...)
				return Root.Commands.ArgumentParsers.number(...)
			end,
		},
		Description = "Test command",
		Permissions = { "Player" },
		Roles = {},
		Hidden = true,
		ServerSide = function(data: {})
			local plr = data.Player
			local args = data.Arguments

			for i,v in pairs(args) do
				warn("Got Argument", i, "of type", type(v), ":", v)
			end 

			warn("Success!", {
				Player = plr,
				Args = args,
				Data = data
			})

			warn("SEND TO CLIENT SIDE TEST")
			data:SendToClientSide(plr, args)
			warn("GET FROM CLIENT SIDE TEST")
			warn("ClientGet Test", data:GetFromClientSide(plr, args))
		end,

		ClientSide = function(...)
			warn("Client Success!", ...)

			return "WE GOT THIS FROM THE CLIENT!"
		end
	};
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
