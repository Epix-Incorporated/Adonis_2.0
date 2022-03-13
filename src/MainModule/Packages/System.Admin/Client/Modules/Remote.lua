--[[

	Description: Remote additions
	Author: Sceleratis
	Date: 12/24/2021

--]]


local Root, Utilities, Service, Package;
local RemoteCommands = {}
local Remote = {}


--//// Command-related Client.Remote methods.

--- Retrieves current user permissions from the server. Caches for duration determined by Root.Timeouts.GetPermissions
--- @method GetPermissions
--- @within Client.Remote
--- @return {}
function Remote.GetPermissions(self)
	local cached = Root.Cache:GetData("Permissions")
	if cached then
		return cached
	else
		local perms = self:Get("Permissions")
		if perms then
			Root.Cache:SetData("GetPermissions", perms, {
				Timeout = Root.Timeouts.GetPermissions
			})
			return perms
		end
	end
end


--//// Return initializer
return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Utilities = Root.Utilities
		Package = cPackage
		Service = Root.Utilities.Services

		--// Do init
		Root.Timeouts.GetPermissions = 5
		Utilities:MergeTables(Root.Remote, Remote)
		Utilities:MergeTables(Root.Remote.Commands, RemoteCommands)
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
	end;
}
