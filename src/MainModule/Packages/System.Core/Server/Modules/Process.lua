--[[

	Description: Responsible for the translation of Roblox events to system events.
	Author: Sceleratis
	Date: 12/11/2021

--]]


local Root, Utilities, Package, Service, Events

local SetupComplete = false
local ExistingPlayers = {}

local Process = {
	EventConnections = {},

	PlayerAdded = function(self, p: Player)
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
	end,

	PlayerChatted = function(self, p: Player, ...)
		Events.PlayerChatted:Fire(p, ...)
	end,

	PlayerReady = function(self, p: Player)
		Events.PlayerReady:Fire(p)
	end,

	PlayerRemoving = function(self, p: Player, ...)
		Events.PlayerRemoving:Fire(p, ...)
	end,

	PlayerRemoved = function(self, p: Player?)
		if p and p:IsA("Player") then
			Events.PlayerRemoved:Fire(p)
		end
	end,

	CharacterAdded = function(self, p: Player, ...)
		Events.CharacterAdded:Fire(p, ...)
	end,

	CharacterRemoving = function(self, p: Player, ...)
		Events.CharacterRemoving:Fire(p, ...)
	end,

	NetworkAdded = function(self, ...)
		Events.NetworkAdded:Fire(...)
	end,

	NetworkRemoved = function(self, ...)
		Events.NetworkRemoved:Fire(...)
	end,

	LogMessage = function(self, msg, msgType, ...)
		if string.find(msg, "Adonis") then
			Events.AdonisLogMessage:Fire(msg, msgType, ...)
		else
			Events.LogMessage:Fire(msg, msgType, ...)
		end
	end,
}

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
