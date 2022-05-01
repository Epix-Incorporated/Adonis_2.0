--[[

	Description:
	Author:
	Date:

--]]


local Root, Utilities, Service, Package;

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

--[=[
	Responsible for server-side UI handling.
	@class Server.UI
	@tag System.UI
]=]
local UI = {}
local Remote = {}

--[=[
	Sets UI-related default player data for new players.
	@method SetDefaultPlayerData
	@within Server.UI
	@param player Player
	@param data {[string]: any}
]=]
function UI.SetDefaultPlayerData(self, player: Player, data: {[string]: any})
	if data then
		--data.CurrentTheme = data.CurrentTheme or Root.Settings.Theme
	end
end

--// Remote methods
--[=[
	Instructs the target player's client to load the UI module matching the provided module name, with the provided data.
	@method MakeUI
	@within Server.Remote
	@param p Player
	@param moduleName string
	@param ... any
	@tag System.UI
]=]
function Remote.MakeUI(self, p: Player, moduleName: string, ...: any)
	DebugWarn("SENDING: ", p, "GUI", moduleName, ...)
	self:Send(p, "UI_LoadModule", {
		Name = moduleName
	}, ...)
end

--[=[
	Instructs the target player's client to load the UI module matching the provided module name, with the provided data and retrieves whatever is returned.
	@method MakeUI_Return
	@within Server.Remote
	@param p Player
	@param moduleName string
	@param ... any
	@return any
	@yields
	@tag System.UI
]=]
function Remote.MakeUI_Return(self, p: Player, moduleName: string, ...: any)
	DebugWarn("SENDING: ", p, "UI_LoadModule", moduleName, ...)
	return self:Get(p, "UI_LoadModule", {
		Name = moduleName
	}, ...)
end


--// Helper functions
local function SetDefaultPlayerData(...)
	UI:SetDefaultPlayerData(...)
end


--// Return initializer
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
			DebugWarn("TESTING UI BYTECODE RUNNING")
			DebugWarn("TESTING LOADCODE", Root.Remote:LoadCodeWithReturn(p, "return 'THIS WORKED!'.. tostring(Root)..tostring(Data and Data[1])", "TestDataStuff"))
		end
		Utilities.Events.PlayerReady:Connect(function(p)
			test(p)
			Utilities.Events.CharacterAdded:Connect(function(p)
				test(p)
			end)
		end)--]]
	end;
}
