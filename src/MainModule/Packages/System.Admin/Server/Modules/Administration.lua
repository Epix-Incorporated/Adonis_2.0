--[[

	Description:
	Author:
	Date:

--]]


local Root, Utilities, Service, Package;


--- Responsible for administrative functionality.
--- @class Server.Admin
--- @server
--- @tag Package: System.Admin


--- Ordered table containing PlayerFinder definitions in order of match priority.
--- @interface PlayerFinders
--- @within Server.Admin


--- Used by Server.Admin.GetPlayers to find players based on parsed message contents.
--- @interface PlayerFinder
--- @within Server.Admin
--- @field Name string -- Player finder name
--- @field Regex string -- Regex patterns used for message parsing. Once successful, subsequent players finders will not be checked.
--- @field Safe boolean -- Boolean determining if this player finder is usable when "Safe" is set to true in the data table passed to Server.Admin.GetPlayers
--- @field Finder function -- Function called when Regex match is found. Data passed to GetPlayers and the matching string are passed. Returns found players.


--- Server.Admin.GetPlayers Settings
--- @interface GetPlayersSettings
--- @within Server.Admin
--- @field Safe boolean -- Intructs GetPlayers to only check PlayerFinder objects with Safe set to true.



local Admin = {
	PlayerFinders = {
		--// "me"
		{
			Name = "Me",
			Regex = "me",
			Safe = true,
			Finder = function(data, text)
				return { data.Player }
			end
		},

		--// "@username"
		{
			Name = "Username",
			Regex = "@(.+)",
			Finder = function(data, text, matched)
				local player = Service.Players:FindFirstChild(matched)

				if not player and data.SpoofPlayers then
					--// Spoof player
				end

				return { player }
			end
		},

		{
			Name = "UserId",
			Regex = "userid%-(%d+)",
			Finder = function(data, text, matched)
				local found = {}
				local userId = tonumber(matched)

				if userId then
					for i,player in ipairs(Service.Players:GetPlayers()) do
						if player.UserId == userId then
							table.insert(found, player)
							break;
						end
					end
				end

				if #found == 0 and data.SpoofPlayers then
					--// Spoof player
				end

				return found
			end
		},

		--// After all previous finders have failed
		{
			Name = "Players",
			Regex = "(.+)",
			Finder = function(data, text)
				local found = {}

				--// Usernames first
				for i,player in ipairs(Service.Players:GetPlayers()) do
					if string.sub(string.lower(player.Name), 1, #text) == string.lower(text) then
						table.insert(found, player)
					end
				end

				--// If no username matches, then displaynames
				if #found == 0 then
					for i,player in ipairs(Service.Players:GetPlayers()) do
						if string.sub(string.lower(player.DisplayName), 1, #text) == string.lower(text) then
							table.insert(found, player)
						end
					end
				end

				return found
			end
		}
	}
}



--//// Server.Admin methods

--- Performs regex matching on provided string and returns players found by associated PlayerFinder objects.
--- @method GetPlayers
--- @within Server.Admin
--- @param data GetPlayersSettings -- GetPlayers settings
--- @param text string -- Text to parse
function Admin.GetPlayers(self, data: {}, text: string)
	if not text then
		return { data and data.Player }
	else
		local foundPlayers = {}
		local subArgs = Utilities:SplitString(text, ',', true)
		for i,matchThis in ipairs(subArgs) do
			for ind, finderData in pairs(self.PlayerFinders) do
				if (not data.Safe or (data.Safe and finderData.Safe)) then
					local matched = string.match(matchThis, finderData.Regex)
					if matched then
						Utilities:AddRange(foundPlayers, finderData.Finder(data, text, matched))
					end
				end
			end
		end
		return foundPlayers
	end
end


--- Creates and returns a new wrapped folder to use as a "spoof" object when needed.
--- @method NewSpoofObject
--- @within Server.Admin
--- @param data {} -- Data table containing properties/methods to automatically add to the new spoof object
function Admin.NewSpoofObject(self, data: {})
	local spoofObject = Instance.new("Folder", data and data.Properties)
	local wrapped = Utilities:Wrap(spoofObject)

	if data and data.Special then
		for ind,val in pairs(data.Special) do
			wrapped:SetSpecial(ind, val)
		end
	end

	return wrapped
end



--//// Return initializer
return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		--// Do init
		Root.Admin = Admin
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
	end;
}
