--[[

	Description: Shared command declaration. Should not be used for commands with sensitive/not public server-side code.
	Author: Sceleratis
	Date: 12/25/2021

--]]


local Root, Utilities, Service, Package;
local Settings = setmetatable({}, {
	__index = function(self, ind)
		return { __SETTING_PROXY = true, Index = ind }
	end
})

local DeclareCommands = {
	DebugTest = {
		Prefix = Settings.Prefix,
		Aliases = { "debugtest", "debugtest2" },
		Arguments = { "players", "testarg2", "testarg3" },
		Parsers = {
			testarg2 = function(data, cmdArg, text)
				Root.Warn("PARSE ARG", data, cmdArg, text)
			end
		},
		Description = "Test command",
		Permissions = { "Player" },
		Roles = {},
		ServerSide = function(data: {})
			local plr = data.Player
			local args = data.Arguments
			local parsed = data.ParsedArguments

			Root.Warn("Success!", {
				Player = plr,
				Args = args,
				Parsed = parsed,
				Data = data
			})

			data:SendToClientSide(plr, args)
			Root.Warn("ClientGet Test", data:GetFromClientSide(plr, args))
		end,

		ClientSide = function(...)
			Root.Warn("Client Success!", ...)

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
