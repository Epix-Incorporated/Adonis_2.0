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
}

local Remote = {
	MakeUI = function(self, p: Player, moduleName, ...)
		Root.DebugWarn("SENDING: ", p, "GUI", moduleName, ...)
		self:Send(p, "UI_LoadModule", {
			Name = moduleName
		}, ...)
	end;

	MakeUI_Return = function(self, p: Player, moduleName, ...)
		Root.DebugWarn("SENDING: ", p, "UI_LoadModule", moduleName, ...)
		return self:Get(p, "UI_LoadModule", {
			Name = moduleName
		}, ...)
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
	end;

	AfterInit = function(Root, Package)
		--[[local function test(p)
			Root.DebugWarn("TESTING UI BYTECODE RUNNING")
			Root.DebugWarn("TESTING LOADCODE", Root.Remote:LoadCodeWithReturn(p, "return 'THIS WORKED!'.. tostring(Root)..tostring(Data and Data[1])", "TestDataStuff"))
		end
		Utilities.Events.PlayerReady:Connect(function(p)
			test(p)
			Utilities.Events.CharacterAdded:Connect(function(p)
				test(p)
			end)
		end)--]]
	end;
}
