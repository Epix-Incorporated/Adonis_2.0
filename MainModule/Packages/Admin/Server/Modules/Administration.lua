--[[

	Description:
	Author:
	Date:

--]]


local Root, Utilities, Service, Package;

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
			Regex = ".+",
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
	},

	NewSpoofObject = function(self, data: {})
		local spoofObject = Instance.new("Folder", data and data.Properties)
		local wrapped = Utilities:Wrap(spoofObject)

		if data and data.Special then
			for ind,val in pairs(data.Special) do
				wrapped:SetSpecial(ind, val)
			end
		end

		return wrapped
	end,

	GetPlayers = function(self, data: {}, text: string)
		if not text then
			return { data.Player }
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
}

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
