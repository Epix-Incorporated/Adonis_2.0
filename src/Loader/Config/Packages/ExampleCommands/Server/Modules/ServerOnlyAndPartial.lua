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
	--// An example of a command with it's server portion defined in a way that the client cannot see, while still providing the a client-side portion
	--// For the clientside portion of SplitDefinitionExample, refer to PackageFolder > Client > Modules > ClientPartials.lua
	SplitDefinitionExample = {
		Prefix = Settings.Prefix,
		Aliases = { "splitdefinitionexample" },
		Arguments = { "players", "testarg2", "testarg3", "someNumber"},
		Parsers = {
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
						Error = "PARSING ERROR HERE"
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
			local parsed = data.ParsedArguments

			warn("This is server only! The client cannot see any of this or the command's definition, other than the clientside portion defined in a client module.", {
				Player = plr,
				Args = args,
				Parsed = parsed,
				Data = data
			})
		end,
	};

	--// An example of a command declared with no client partial in a way that only the server can see (so the client can't see this command or its code at all locally)
	ServerOnlyExample = {
		Prefix = Settings.Prefix,
		Aliases = { "serveronlyexample" },
		Arguments = { "players", "testarg2", "testarg3", "someNumber"},
		Parsers = {
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
						Error = "PARSING ERROR HERE"
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
			local parsed = data.ParsedArguments

			warn("This is server only! Client can never see this code or any command details unless explicitly requested via Remote.", {
				Player = plr,
				Args = args,
				Parsed = parsed,
				Data = data
			})
		end,
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
