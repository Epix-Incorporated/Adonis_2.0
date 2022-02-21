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

local DeclareCommands = {
	--// ClientSide for SplitDefinitionExample
	SplitDefinitionExample = {
		ClientSide = function(...)
			Root.Warn("Split Definition!", ...)

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
