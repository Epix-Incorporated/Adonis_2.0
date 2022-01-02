--[[

	Description:
	Author:
	Date:

--]]


local Root, Utilities, Service, Package;

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		--// Do init
		Root.Core:DeclarePlayerPreLoadProcess("BanHandler", function(p: Player)

			if p.Parent and Root.Permissions:HasPermission(p, "Banned") then
				local data = Root.Core:GetPlayerData(p)
				local userEntries = Root.Users:GetUserEntries(p)
				local banMessage = Root.Settings.BanMessage

				if data.BanReason then
					banMessage = data.BanReason
				else
					for i,user in ipairs(userEntries) do
						if user.BanReason then
							banMessage = user.BanReason
							break;
						end
					end
				end

				p:Kick(banMessage)
				Utilities.Events.PlayerKicked:Fire(p, "Banned", "\n:: ".. Root.AppName .." ::\n".. banMessage)
			end
		end)
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
	end;
}
