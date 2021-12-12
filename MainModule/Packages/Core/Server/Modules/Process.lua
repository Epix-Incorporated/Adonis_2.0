--[[
	
	Description: Responsible for the firing of Core events.
	Author: Sceleratis
	Date: 12/11/2021

--]]


local util;
local service;
local server;

local EventConnections = {}

local Process = {
	EventConnections = EventConnections;
	
	PlayerAdded = function(self, p: Player)
		p.CharacterAdded:Connect(function()
			self:CharacterAdded(p, p.Character);
		end)
		
		p.CharacterRemoving:Connect(function()
			self:CharacterRemoving(p, p.Character);
		end)
		
		util.Events.PlayerAdded:Fire(p);
	end,
	
	PlayerReady = function(self, p)
		util.Events.PlayerReady:Fire(p);
	end,
	
	PlayerRemoving = function(self, p)
		util.Events.PlayerRemoving:Fire(p);
	end,
	
	PlayerRemoved = function(self, p)
		util.Events.PlayerRemoved:Fire(p);
	end,
	
	CharacterAdded = function(self, p, c)
		util.Events.CharacterAdded:Fire(p, c);
	end,
	
	CharacterRemoving = function(self, p, c)
		util.Events.CharacterRemoving:Fire(p, c);
	end,
	
	NetworkAdded = function(self, cli)
		util.Events.NetworkAdded:Fire(cli);
	end,
	
	NetworkRemoved = function(self, cli)
		util.Events.NetworkRemoved:Fire(cli);
	end,
}

local function PlayerAdded(p)
	Process:PlayerAdded(p);
end

local function PlayerRemoving(p)
	Process:PlayerRemoving(p);
end

local function PlayerRemoved(p)
	if p and p:IsA("Player") then
		Process:PlayerRemoved(p);
	end
end

local function NetworkAdded(cli)
	Process:NetworkAdded(cli);
end

local function NetworkRemoved(cli)
	Process:NetworkRemoved(cli);
end

return {
	Init = function(Root, Package)
		server = Root
		util = Root.Utilities
		service = Root.Utilities.Services
		
		Root.Process = Process;
	end;

	AfterInit = function(Root, Package)
		--// Event hookups
		EventConnections.PlayerAdded = service.Players.PlayerAdded:Connect(PlayerAdded);
		EventConnections.PlayerRemoving = service.Players.PlayerRemoving:Connect(PlayerRemoving);
		EventConnections.PlayerRemoved = service.Players.ChildRemoved:Connect(PlayerRemoved);
		
		if service.NetworkServer then
			EventConnections.NetworkAdded = service.NetworkServer.ChildAdded:Connect(NetworkAdded);
			EventConnections.NetworkRemoving = service.NetworkServer.ChildRemoved:Connect(NetworkRemoved);
		end
	end;
}