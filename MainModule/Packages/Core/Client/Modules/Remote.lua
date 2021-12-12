--[[
	
	Description: Responsible for basic client-server communication
	Author: Sceleratis
	Date: 12/11/2021

--]]


local Package;
local Utilities;
local Root; 

local service;

local GettingEvent = false;
local PlayerData = {};
local Sessions = {};

--// Remote (server-to-client) commands
local RemoteCommands = {
	SessionData = function(sessionKey, ...)
		if sessionKey then
			if Sessions[sessionKey] then 
				local session = Root.Remote:GetSession(sessionKey);
				if session then
					session:FireEvent(...);
				end
			end
		end
	end;
	
	LoadCode = function(str, ...)
		return Root.Bytecode:LoadBytecode(str, nil)(...);
	end,

}

--// Methods
local Methods = {
	Session = {
		SendToServer = function(self, ...)
			if not self.Ended then
				Root.Remote:Send("SessionData", ...);
			end
		end,
		
		FireEvent = function(self, ...)
			if not self.Ended then
				self.SessionEvent:Fire(...);
			end
		end;

		ConnectEvent = function(self, ...)
			if not self.Ended then
				return self.SessionEvent.Event:Connect(...);
			end
		end,
		
		End = function(self)
			if not self.Ended then
				for t,event in next,self.Events do
					event:Disconnect();
					self.Events[t] = nil;
				end

				self:SendToServer("LeftSession");
				self.SessionEvent:Destroy();
				self.Ended = true;
				
				Sessions[self.SessionKey] = nil;
			end
		end;
	}
}

--// Remote
local Remote = {
	SharedKey = "";
	EventObjectsName = "";
	Commands = RemoteCommands;
	Sessions = Sessions;

	--// Server-related methods
	Send = function(self, cmd, ...)
		local curEvent = self:WaitForEvent();
		if curEvent then
			local cmd = Utilities:Encrypt(cmd, self.SharedKey);

			curEvent.RemoteEvent:FireServer(cmd, table.pack(...));
		end
	end,

	Get = function(self, cmd, ...)
		local curEvent = self:WaitForEvent();
		if curEvent then
			local cmd = Utilities:Encrypt(cmd, self.SharedKey);

			return table.unpack(curEvent.RemoteFuncton:InvokeServer(cmd, table.pack(...)));
		end
	end,
	
	GetSession = function(self, sessionKey)
		if not Sessions[sessionKey] then
			local session = {
				SessionKey = sessionKey;
				SessionEvent = Instance.new("BindableEvent");
				
				SendToServer = Methods.Session.SendToServer;
				FireEvent = Methods.Session.FireEvent;
				Connect = Methods.Session.ConnectEvent;
				End = Methods.Session.End;
			}
			
			session:Connect(function(cmd, ...)
				if not session.Ended then
					if cmd == "SessionEnded" then
						session:End();
					end
				end
			end)
			
			session:SendToServer("JoinedSession");
			
			Sessions[sessionKey] = session;
		end
		
		return Sessions[sessionKey];
	end,

	--// Process remote commands
	ProcessRemoteCommand = function(self, cmd, args)
		local cmd = Utilities:Decrypt(cmd, self.SharedKey);
		local command = self.Commands[cmd];
		
		Utilities.Events.ReceivedRemoteCommand:Fire(cmd, if type(args) == "table" then table.unpack(args) else args)

		if command then
			return table.pack(command(if type(args) == "table" then table.unpack(args) else args));
		end
	end,

	--// Event setup
	WaitForEvent = function(self)
		while not self.CurrentEvent or not self.CurrentEvent.RemoteEvent or not self.CurrentEvent.RemoteFunction or GettingEvent do
			wait(0.15);
		end

		return self.CurrentEvent;
	end,
	
	EventChangeDetected = function(self, c)
		local curEvent = self.CurrentEvent;
		if curEvent and not GettingEvent then
			local rEvent = curEvent.RemoteEvent;
			local rFunction = curEvent.RemoteFunction;

			if c == "OnClientInvoke" or (rEvent.Parent ~= service.ReplicatedStorage or rFunction.Parent ~= service.ReplicatedStorage) then
				self:SetupRemote();
			elseif rEvent.Name ~= self.EventObjectsName or rFunction.Name ~= self.EventObjectsName then
				rEvent.Name = self.EventObjectsName;
				rFunction.Name = self.EventObjectsName;
			end
		end
	end,

	SetupRemote = function(self)
		if not GettingEvent then
			GettingEvent = true;
			
			local foundEvents = false
			local objBlacklist = {}
			
			self.CurrentEvent = {}
			
			--// Find remote event and function
			repeat
				
				--// Scan for our RemoteEvent and RemoteFunction
				for i,child in ipairs(service.ReplicatedStorage:GetChildren()) do
					if child.Name == self.EventObjectsName and not objBlacklist[child] then
						if child:IsA("RemoteEvent") then
							self.CurrentEvent.RemoteEvent = child
						elseif child:IsA("RemoteFunction") then
							self.CurrentEvent.RemoteFunction = child
						end
					end
				end
				
				--// Verify that we found the correct event and function (very basic and not-infallible trust checking)
				if self.CurrentEvent.RemoteFunction and self.CurrentEvent.RemoteEvent then
					local rawValue = Utilities:RandomString();
					local encValue = Utilities:Encrypt(rawValue, self.SharedKey);
					local cmd = Utilities:Encrypt("VerifyRemote", self.SharedKey);
					local returnedData = nil;
					
					--// Run it in a pcall, if it errors, it's probably no good
					local ran,returnedRawData = pcall(function()
						return self.CurrentEvent.RemoteFunction:InvokeServer(cmd, {rawValue})
					end)
					
					if ran and returnedRawData and type(returnedRawData) == "table" then
						returnedData = table.unpack(returnedRawData);
					end
					
					--// If the function returns an event and the event is the event we found then we're good
					if ran and returnedData and type(returnedData) == "table" and returnedData.Value == encValue and returnedData.Event then
						local returnedEvent = returnedData.Event;
						if returnedEvent == self.CurrentEvent.RemoteEvent then
							foundEvents = true;
							
						--// If the function returns an event and it's not the one we found, blacklist the one we found for the next scan
						else
							objBlacklist[self.CurrentEvent.RemoteEvent] = true;
						end
					
					--// If the function did not return an event, then blacklist it as it's probably fake (Malicious server script?)
					else
						objBlacklist[self.CurrentEvent.RemoteFunction] = true;
					end
				end
				
			until (foundEvents and self.CurrentEvent.RemoteEvent and self.CurrentEvent.RemoteFunction) or not wait(0.15);
			
			self.CurrentEvent.RemoteEvent.OnClientEvent:Connect(function(...)
				self:ProcessRemoteCommand(...);
			end)
			
			self.CurrentEvent.RemoteFunction.OnClientInvoke = function(...)
				return self:ProcessRemoteCommand(...);
			end
			
			self.CurrentEvent.RemoteEvent.Changed:Connect(function(...)
				self:EventChangeDetected(...);
			end)
			
			self.CurrentEvent.RemoteFunction.Changed:Connect(function(...)
				self:EventChangeDetected(...);
			end)
			
			Root.DebugWarn("Found Remotes")
			
			GettingEvent = false;
		end
	end,
}

return {
	Init = function(cRoot, cPackage)

		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities

		service = Utilities.Services

		Root.Remote = Remote;
	end;

	AfterInit = function(Root, Package)
		local objNameValue = Package.Shared:WaitForChild("EventObjectName");
		local sharedKeyValue = Package.Shared:WaitForChild("SharedKey");

		Remote.EventObjectsName = objNameValue.Value;
		Remote.SharedKey = sharedKeyValue.Value;
		Remote:SetupRemote();
		
		Remote:Send("ClientReady");
		
		Utilities.Events.ClientReady:Fire();
	end;
}