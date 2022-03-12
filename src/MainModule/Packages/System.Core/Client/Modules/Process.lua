--[[

	Description: Responsible for the firing of Core events.
	Author: Sceleratis
	Date: 12/11/2021

--]]


local Root, Utilities, Package, Service, Events

local EventConnections = {}

--- Responsible for handling various Roblox events and passing them off to Utilities.Events equivilents
--- @class Client.Process
--- @client
--- @tag Core
--- @tag Package: System.Core
local Process = {
	EventConnections = EventConnections
}


--- PlayerAdded event handler
--- @method PlayerAdded
--- @within Client.Process
--- @param p Player -- Player
function Process.PlayerAdded(self, p: Player)
	p.CharacterAdded:Connect(function()
		self:CharacterAdded(p, p.Character)
	end)

	p.CharacterRemoving:Connect(function()
		self:CharacterRemoving(p, p.Character)
	end)

	Events.PlayerAdded:Fire(p)
end


--- PlayerRemoving event handler
--- @method PlayerRemoving
--- @within Client.Process
--- @param p Player -- Player
function Process.PlayerRemoving(self, p: Player)
	Events.PlayerRemoving:Fire(p)
end


--- PlayerRemoved event handler
--- @method PlayerRemoved
--- @within Client.Process
--- @param p Player -- Player
function Process.PlayerRemoved(self, p: Player)
	Events.PlayerRemoved:Fire(p)
end


--- CharacterAdded event handler
--- @method CharacterAdded
--- @within Client.Process
--- @param p Player -- Player
--- @param c Character -- Character
function Process.CharacterAdded(self, p: Player, c)
	Events.CharacterAdded:Fire(p, c)
end


--- CharacterRemoving event handler
--- @method CharacterRemoving
--- @within Client.Process
--- @param p Player
--- @param c Character
function Process.CharacterRemoving(self, p: Player, c)
	Events.CharacterRemoving:Fire(p, c)
end


--- MessageOut event handler
--- @method LogMessage
--- @within Client.Process
--- @param msg string -- Message string
--- @param msgType Enum -- MessageType
--- @param ... any
function Process.LogMessage(self, msg, msgType, ...)
	if string.find(msg, "Adonis") then
		Events.AdonisLogMessage:Fire(msg, msgType, ...)
	else
		Events.LogMessage:Fire(msg, msgType, ...)
	end
end


local function PlayerAdded(...)
	Process:PlayerAdded(...)
end

local function PlayerRemoving(...)
	Process:PlayerRemoving(...)
end

local function PlayerRemoved(p, ...)
	if p and p:IsA("Player") then
		Process:PlayerRemoved(...)
	end
end

local function LogMessage(...)
	Process:LogMessage(...)
end

return {
	Init = function(cRoot, cPackage)
		Root = cRoot;
		Package = cPackage;
		Utilities = Root.Utilities;
		Service = Root.Services;
		Events = Root.Events;

		Root.Process = Process;
	end;

	AfterInit = function(Root, Package)
		--// Event hookups
		EventConnections.PlayerAdded = Service.Players.PlayerAdded:Connect(PlayerAdded)
		EventConnections.PlayerRemoving = Service.Players.PlayerRemoving:Connect(PlayerRemoving)
		EventConnections.PlayerRemoved = Service.Players.ChildRemoved:Connect(PlayerRemoved)
		EventConnections.LogMessage = Service.LogService.MessageOut:Connect(LogMessage)
	end;
}
