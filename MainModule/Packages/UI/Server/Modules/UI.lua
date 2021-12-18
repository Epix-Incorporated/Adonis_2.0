--[[

	Description:
	Author:
	Date:

--]]


local Root, Utilities, Service, Package;


local UI = {
	SetDefaultPlayerData = function(self, player: Player, data)
		if data then
			--data.CurrentTheme = data.CurrentTheme or Root.Settings.Theme
		end
	end;

	GetTheme = function(self, player: Player)
		local data = Root.Core:GetPlayerData(player)
		return data.CurrentTheme or Root.Settings.Theme
	end;
}

local Remote = {
	MakeGui = function(self, p: Player, uiName, ...)
		local theme = UI:GetTheme(p)
		local themeData = {
			Theme = theme
		}

		Root.DebugWarn("SENDING: ", p, "GUI", uiName, themeData, ...)
		self:Send(p, "GUI", uiName, themeData, ...)
	end;

	GetGui = function(self, p: Player, uiName, ...)
		local data = Root.Core:GetPlayerData(p)
		local theme = UI:GetTheme(p)
		local themeData = {
			Theme = theme
		}

		return self:Get(p, "GUI", uiName, themeData, ...)
	end;
}

local function SetDefaultPlayerData(...)
	UI:SetDefaultPlayerData(...)
end

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		--// Do init
		Root.UI = UI
		Utilities:MergeTables(Root.Remote, Remote)

		--// Declare default playerdata (add a func to run on new playerdata grab)
		Root.Core:DeclareDefaultPlayerData("UI", SetDefaultPlayerData)
		Root.Core:DeclareSetting("Theme", "Default", "Default UI Theme");
	end;

	AfterInit = function(Root, Package)
		local function test(p)
			Root.DebugWarn("TESTING UI WINDOW CREATION")
			Root.Remote:MakeGui(p, "Window", {
				Title = "TESTING",
				Name = "TESTING_WINDOW",
				Ready = true
			})
		end
		Utilities.Events.PlayerReady:Connect(function(p)
			test(p)
			Utilities.Events.CharacterAdded:Connect(function(p)
				test(p)
			end)
		end)
	end;
}
