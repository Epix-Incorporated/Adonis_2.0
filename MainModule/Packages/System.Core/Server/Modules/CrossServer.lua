--[[

	Description: Contains various variables & methods required for crossserver communication
	Author: Sceleratis
	Date: 12/05/2021

--]]

local Root, Package, Utilities, Service

local lastTick;
local counter = 0;
local ServerId = game.JobId;

local CrossServerCommands = {
	Ping = function(jobId, data)
		Utilities.Events.ServerPingReceived:Fire(jobId, data)
		Root.CrossServer:SendMessage("Pong", {
			JobId = game.JobId,
			NumPlayers = #Service.Players:GetPlayers()
		})
	end;

	Pong = function(jobId, data)
		Utilities.Events.ServerPingReplyReceived:Fire(jobId, data)
	end;
}

local CrossServer = {
	CrossServerKey = "AdonisCrossServerMessaging";
	CrossServerCommands = CrossServerCommands;

	--// Handlers
	SendMessage = function(self, ...)
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
	end,

	ProcessCrossServerMessage = function(self, msg)
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
}

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

		CrossServer.SubscribedEvent = Service.MessagingService:SubscribeAsync(CrossServer.CrossServerKey, CrossServerReceived)
	end;

	AfterInit = function(Root, Package)

	end;
}
