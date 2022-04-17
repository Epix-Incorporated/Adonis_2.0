--[[

	Description: Contains various variables & methods required for crossserver communication
	Author: Sceleratis
	Date: 12/05/2021

--]]

local Root, Package, Utilities, Service

local lastTick;
local counter = 0;
local ServerId = game.JobId;


--- Cross-server commands.
--- @class Server.CrossServer.Commands
--- @server
--- @tag Core
--- @tag Package: System.Core
--- @tag Cross-Server Commands
local CrossServerCommands = {}


--- Responsible for cross-server functionality.
--- @class Server.CrossServer
--- @server
--- @tag Core
--- @tag Package: System.Core
local CrossServer = {
	CrossServerKey = "AdonisCrossServerMessaging";
	CrossServerCommands = CrossServerCommands;
}


--- Send cross-server message
--- @method SendMessage
--- @within Server.CrossServer
--- @param ... any
function CrossServer.SendMessage(self, ...)
	local data = {ServerId, ...};

	Utilities:Queue("CrossServerMessageQueue", function()
		--// Rate limiting
		counter = counter+1;

		if not lastTick then lastTick = os.time() end
		if counter >= 150 + 60 * #Service.Players:GetPlayers()  then
			repeat task.wait() until os.time()-lastTick > 60;
		end

		if os.time()-lastTick > 60 then
			lastTick = os.time();
			counter = 1;
		end

		--// Publish
		Service.MessagingService:PublishAsync(self.CrossServerKey, data)
		Utilities.Events.CrossServerMessageSent:Fire(data)
	end)

	return true;
end


--- Handles cross-server messages
--- @method ProcessCrossServerMessage
--- @within Server.CrossServer
--- @param msg string -- Message
function CrossServer.ProcessCrossServerMessage(self, msg)
	local data = msg.Data;
	if not data or type(data) ~= "table" then error("CrossServer: Invalid Data Type ".. type(data)); end
	local command = data[2];

	table.remove(data, 2);

	Root.Logging:AddLog("Script", "Cross-Server Message received: ".. tostring(data and data[2] or "nil data[2]"));
	Utilities.Events.CrossServerMessageReceived:Fire(msg)

	if self.CrossServerCommands[command] then
		self.CrossServerCommands[command](unpack(data));
	end
end


--// Cross-Server Commands
--- Runs when a "Ping" command is received, announcing this server's presence to other servers.
--- @function Ping
--- @within Server.CrossServer.Commands
--- @tag Cross-Server Command
--- @param jobId string -- Origin server's JobID
--- @param data any -- Data sent by the origin server
function CrossServerCommands.Ping(jobId, data)
	Utilities.Events.ServerPingReceived:Fire(jobId, data)
	Root.CrossServer:SendMessage("Pong", {
		JobId = game.JobId,
		NumPlayers = #Service.Players:GetPlayers()
	})
end


--- Response to "Ping" from other servers
--- @function Pong
--- @within Server.CrossServer.Commands
--- @tag Cross-Server Command
--- @param jobId string -- Origin server JobID
--- @param data any -- Data sent by the origin server
function CrossServerCommands.Pong(jobId, data)
	Utilities.Events.ServerPingReplyReceived:Fire(jobId, data)
end


--// Events
local function CrossServerReceived(...)
	Root.CrossServer:CrossServerMessage(...)
end

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		Root.CrossServer = CrossServer

		Root.CrossServer.SubscribedEvent = Service.MessagingService:SubscribeAsync(CrossServer.CrossServerKey, CrossServerReceived)
	end;

	AfterInit = function(Root, Package)

	end;
}
