--[[

	Description: Command declaration.
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
	TestCommand = {
		Prefix = Settings.Prefix,
		Aliases = { "testcommand", "example" },
		Arguments = {
			"testarg1", "testarg2", "testarg3" --// Need to figure out how to best handle these
		},
		Description = "Test command",
		Permissions = { "Player" },
		Roles = {},
		ServerSide = function(data: {})
			local plr = data.Player
			local args = data.Arguments
			
			Root.Warn("Success!", {
				Player = plr,
				Args = args,
				Data = data
			})

			data:SendClientSide(plr, args)
		end,

		ClientSide = function(...)
			Root.Warn("Client Success!", ...)
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
