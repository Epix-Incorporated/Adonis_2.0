--[[

	Description: Responsible for the firing of Core events.
	Author: Sceleratis
	Date: 12/11/2021

--]]


local Root, Utilities, Package, Service, Events;

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

		Events.PlayerAdded:Fire(p);
	end,

	PlayerRemoving = function(self, p)
		Events.PlayerRemoving:Fire(p);
	end,

	PlayerRemoved = function(self, p)
		Events.PlayerRemoved:Fire(p);
	end,

	CharacterAdded = function(self, p, c)
		Events.CharacterAdded:Fire(p, c);
	end,

	CharacterRemoving = function(self, p, c)
		Events.CharacterRemoving:Fire(p, c);
	end,

	LogMessage = function(self, msg, msgType, ...)
		if string.find(msg, "Adonis") then
			Events.AdonisLogMessage:Fire(msg, msgType, ...);
		else
			Events.LogMessage:Fire(msg, msgType, ...);
		end
	end,
}

local function PlayerAdded(...)
	Process:PlayerAdded(...);
end

local function PlayerRemoving(...)
	Process:PlayerRemoving(...);
end

local function PlayerRemoved(...)
	if p and p:IsA("Player") then
		Process:PlayerRemoved(...);
	end
end

local function LogMessage(...)
	Process:LogMessage(...);
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
		EventConnections.PlayerAdded = Service.Players.PlayerAdded:Connect(PlayerAdded);
		EventConnections.PlayerRemoving = Service.Players.PlayerRemoving:Connect(PlayerRemoving);
		EventConnections.PlayerRemoved = Service.Players.ChildRemoved:Connect(PlayerRemoved);
		EventConnections.LogMessage = Service.LogService.MessageOut:Connect(LogMessage);
	end;
}
