--[[

	Description: Responsible for the translation of Roblox events to system events.
	Author: Sceleratis
	Date: 12/11/2021

--]]


local Root, Utilities, Package, Service, Events

local SetupComplete = false
local ExistingPlayers = {}

--- Responsible for the handling of various events.
--- @class Server.Process
--- @server
--- @tag Core
--- @tag Package: System.Core
local Process = {
	EventConnections = {}
}


--- PlayerAdded event handler
--- @method PlayerAdded
--- @within Server.Process
--- @param p Player
function Process.PlayerAdded(self, p: Player)
	if Root.Core:HandlePlayerPreLoadingProcesses(p) then
		p.CharacterAdded:Connect(function(...)
			self:CharacterAdded(p, ...)
		end)

		p.CharacterRemoving:Connect(function(...)
			self:CharacterRemoving(p, ...)
		end)

		p.Chatted:Connect(function(...)
			self:PlayerChatted(p, ...)
		end)

		Events.PlayerAdded:Fire(p)
	end
end


--- PlayerChatted event handler
--- @method PlayerChatted
--- @within Server.Process
--- @param p Player
function Process.PlayerChatted(self, p: Player, ...)
	Events.PlayerChatted:Fire(p, ...)
end


--- PleaseReady event handler
--- @method PlayerReady
--- @within Server.Process
--- @param p Player
function Process.PlayerReady(self, p: Player)
	Events.PlayerReady:Fire(p)
end


--- PlayerRemoving event handler
--- @method PlayerRemoving
--- @within Server.Process
--- @param p Player
function Process.PlayerRemoving(self, p: Player, ...)
	Events.PlayerRemoving:Fire(p, ...)
end


--- PlayerRemoved event handler
--- @method PlayerRemoved
--- @within Server.Process
--- @param p Player?
function Process.PlayerRemoved(self, p: Player?)
	if p and p:IsA("Player") then
		Events.PlayerRemoved:Fire(p)
	end
end


--- CharacterAdded event handler
--- @method CharacterAdded
--- @within Server.Process
--- @param p Player
function Process.CharacterAdded(self, p: Player, ...)
	Events.CharacterAdded:Fire(p, ...)
end


--- CharacterRemoving event handler
--- @method CharacterRemoving
--- @within Server.Process
--- @param p Player
--- @param ... any
function Process.CharacterRemoving(self, p: Player, ...)
	Events.CharacterRemoving:Fire(p, ...)
end


--- NetworkAdded event handler
--- @method NetworkAdded
--- @within Server.Process
--- @param ... any
function Process.NetworkAdded(self, ...)
	Events.NetworkAdded:Fire(...)
end


--- NetworkRemoved event handler
--- @method NetworkRemoved
--- @within Server.Process
--- @param ... any
function Process.NetworkRemoved(self, ...)
	Events.NetworkRemoved:Fire(...)
end


--- MessageOut event handler
--- @method LogMessage
--- @within Server.Process
--- @param msg string
--- @param msgType MessageType
--- @param ... any -- Additional data passed to Events.AdonisLogMessage or Events.LogMessage
function Process.LogMessage(self, msg, msgType, ...)
	if string.find(msg, "Adonis") then
		Events.AdonisLogMessage:Fire(msg, msgType, ...)
	else
		Events.LogMessage:Fire(msg, msgType, ...)
	end
end


--// Events
local function PlayerAdded(p, ...)
	--// Check ExistingPlayers so we don't accidentally (somehow) fire twice for this player during setup
	if SetupComplete or (not SetupComplete and not ExistingPlayers[p]) then
		Process:PlayerAdded(p, ...)
	end
end

local function PlayerRemoving(...)
	Process:PlayerRemoving(...)
end

local function PlayerRemoved(...)
	Process:PlayerRemoved(...)
end

local function NetworkAdded(...)
	Process:NetworkAdded(...)
end

local function NetworkRemoved(...)
	Process:NetworkRemoved(...)
end

local function LogMessage(...)
	Process:LogMessage(...)
end

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Services
		Events = Root.Events

		Root.Process = Process
	end;

	AfterInit = function(Root, Package)
		--// Grab all players present before we hooked up the PlayerAdded event so we can fire it for them when setup is finished
		for i,player in ipairs(Service.Players:GetPlayers()) do
			ExistingPlayers[player] = true
		end

		--// Event hookups
		Process.EventConnections.PlayerAdded = Service.Players.PlayerAdded:Connect(PlayerAdded)
		Process.EventConnections.PlayerRemoving = Service.Players.PlayerRemoving:Connect(PlayerRemoving)
		Process.EventConnections.PlayerRemoved = Service.Players.ChildRemoved:Connect(PlayerRemoved)
		Process.EventConnections.LogMessage = Service.LogService.MessageOut:Connect(LogMessage)

		if Service.NetworkServer then
			Process.EventConnections.NetworkAdded = Service.NetworkServer.ChildAdded:Connect(NetworkAdded)
			Process.EventConnections.NetworkRemoving = Service.NetworkServer.ChildRemoved:Connect(NetworkRemoved)
		end
	end;

	DelayedAfterSetup = function(Root, Package)
		--// Handle players present before we hooked up PlayerAdded so they aren't just ignored
		for player in pairs(ExistingPlayers) do
			if player and player.Parent == Service.Players then
				pcall(Process.PlayerAdded, Process, player, true)
			end

			ExistingPlayers[player] = nil
		end

		SetupComplete = true
	end;
}
