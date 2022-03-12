--[[

	Description: Responsible for basic client-server communication
	Author: Sceleratis
	Date: 12/11/2021

--]]

local Package, Utilities, Service, Root

local GettingEvent = false
local PlayerData = {}
local Sessions = {}
local Methods = {}

--- Remote (server-to-client) commands.
--- These should be executed using Root.Remote:Send(COMMAND, DATA) or Root.Remote:Get(COMMAND, DATA)
--- @class Client.Remote.Commands
--- @client
--- @tag Remote Commands
--- @tag Package: System.Core

local RemoteCommands = setmetatable({},{
	__newindex = function(self, ind, value)
		if self[ind] ~= nil and Root then
			Root.Warn("RemoteCommand index already declared. Overwriting...", ind)
		end

		rawset(self, ind, value)

		if Utilities then
			Utilities.Events.RemoteCommandDeclared:Fire(ind, value)
		end
	end
})

--- Responsible for basic client-server communication.
--- @class Client.Remote
--- @client
--- @tag Core
--- @tag Package: System.Core

local Remote = {
	SharedKey = "";
	EventObjectsName = "";
	Commands = RemoteCommands;
	Sessions = Sessions;
}


-- #region Misc Class Methods

--- Responsible for handling temporary client-server communication channels.
--- @class ClientSession
--- @client
--- @tag Core
--- @tag Package: System.Core

--- Session event connections that will be cleaned up on session end.
--- @prop Events {}
--- @within ClientSession

--- Session key.
--- @prop SessionKey string
--- @within ClientSession

--- Session event object.
--- @prop SessionEvent BindableEvent
--- @within ClientSession

Methods.Session = {}


--- Send data to the server
--- @within ClientSession
--- @param self table
--- @param ... any
function Methods.Session.SendToServer(self, ...)
	if not self.Ended then
		Root.Remote:Send("SessionData", ...)
	end
end

--- Fire session event
--- @within ClientSession
--- @param self table
--- @param ... any
function Methods.Session.FireEvent(self, ...)
	if not self.Ended then
		self.SessionEvent:Fire(...)
	end
end

--- Connect session event
--- @within ClientSession
--- @param self table
--- @param func function -- Function to connect
function Methods.Session.ConnectEvent(self, func)
	assert(not self.Ended, "Cannot connect session event: Session Ended")

	local connection = self.SessionEvent.Event:Connect(func)
	table.insert(self.Events, connection)
	return connection
end

--- End session
--- @within ClientSession
--- @param self table
function Methods.Session.End(self)
	if not self.Ended then
		for t, event in pairs(self.Events) do
			event:Disconnect()
			self.Events[t] = nil
		end

		self:SendToServer("LeftSession")
		self.SessionEvent:Destroy()
		self.Ended = true

		Sessions[self.SessionKey] = nil
	end
end


-- #region Remote Methods
--- Sends a remote command to the server
--- @method Send
--- @within Client.Remote
--- @param cmd string -- Remote command
--- @param ... any -- Arguments
function Remote.Send(self, cmd, ...)
	local curEvent = self:WaitForEvent()
	if curEvent then
		local cmd = Utilities:Encrypt(cmd, self.RemoteKey)

		Root.DebugWarn("SENDING", cmd, ...)
		curEvent.RemoteEvent:FireServer(cmd, table.pack(...))
	end
end

--- Sends a remote command to the server and returns the result
--- @method Get
--- @within Client.Remote
--- @yields
--- @param cmd string -- Remote command
--- @param ... any -- Arguments
--- @return result
function Remote.Get(self, cmd, ...)
	local curEvent = self:WaitForEvent()
	if curEvent then
		local cmd = Utilities:Encrypt(cmd, self.RemoteKey);

		Root.DebugWarn("GETTING", cmd, ...)
		return table.unpack(curEvent.RemoteFunction:InvokeServer(cmd, table.pack(...)))
	end
end

--- Gets a session handler for the supplied session key (if session exists)
--- @method GetSession
--- @within Client.Remote
--- @param sessionKey string -- Session key
--- @return ClientSession
function Remote.GetSession(self, sessionKey)
	if not Sessions[sessionKey] then
		local session = {
			SessionKey = sessionKey;
			SessionEvent = Instance.new("BindableEvent");
			Events = {};

			SendToServer = Methods.Session.SendToServer;
			FireEvent = Methods.Session.FireEvent;
			Connect = Methods.Session.ConnectEvent;
			End = Methods.Session.End;
		}

		session:Connect(function(cmd, ...)
			if not session.Ended then
				if cmd == "SessionEnded" then
					session:End()
				end
			end
		end)

		session:SendToServer("JoinedSession")

		Sessions[sessionKey] = session
	end

	return Sessions[sessionKey]
end

--- Responsible for handling of received remote commands
--- @method ProcessRemoteCommand
--- @within Client.Remote
--- @param cmd string -- Remote command to run
--- @param args table -- Arguments table
--- @return any -- Returns whatever the triggered remote command returns (if anything)
function Remote.ProcessRemoteCommand(self, cmd, args)
	local cmd = Utilities:Decrypt(cmd, self.RemoteKey)
	local command = self.Commands[cmd]

	if type(args) ~= "table" then
		args = {args}
	end

	Utilities.Events.ReceivedRemoteCommand:Fire(cmd, if type(args) == "table" then table.unpack(args) else args)

	Root.DebugWarn("GOT", cmd, args)
	if command then
		return table.pack(command(table.unpack(args)))
	end
end

--- Responsible for yielding until the system's RemoteEvent and RemoteFunction objects are found.
--- @method WaitForEvent
--- @within Client.Remote
--- @yields
function Remote.WaitForEvent(self)
	while not self.CurrentEvent or not self.CurrentEvent.RemoteEvent or not self.CurrentEvent.RemoteFunction or GettingEvent do
		Service.RunService.Heartbeat:Wait()
	end

	return self.CurrentEvent
end

--- Remote object OnChange event handler
--- @method EventChangeDetected
--- @within Client.Remote
--- @param c string -- Property changed
function Remote.EventChangeDetected(self, c)
	local curEvent = self.CurrentEvent
	if curEvent and not GettingEvent then
		local rEvent = curEvent.RemoteEvent
		local rFunction = curEvent.RemoteFunction

		if c == "OnClientInvoke" or (rEvent.Parent ~= Service.ReplicatedStorage or rFunction.Parent ~= Service.ReplicatedStorage) then
			self:SetupRemote()
		elseif rEvent.Name ~= self.EventObjectsName or rFunction.Name ~= self.EventObjectsName then
			rEvent.Name = self.EventObjectsName
			rFunction.Name = self.EventObjectsName
		end
	end
end

--- Responsible for finding and connecting to system communication objects.
--- @method SetupRemote
--- @within Client.Remote
--- @yields
function Remote.SetupRemote(self)
	if not GettingEvent then
		GettingEvent = true

		local foundEvents = false
		local objBlacklist = {}

		self.CurrentEvent = {}

		--// Find remote event and function
		repeat

			--// Scan for our RemoteEvent and RemoteFunction
			for i, child in ipairs(Service.ReplicatedStorage:GetChildren()) do
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
				local rawValue = Utilities:RandomString()
				local encValue = Utilities:Encrypt(self.RemoteKey .. rawValue, self.RemoteKey)
				local cmd = Utilities:Encrypt("VerifyRemote", self.RemoteKey)
				local returnedData = nil

				--// Run it in a pcall, if it errors, it's probably no good
				local ran, returnedData = pcall(function()
					return table.unpack(self.CurrentEvent.RemoteFunction:InvokeServer(cmd, {rawValue}))
				end)

				--// If the function returns an event and the event is the event we found then we're good
				if ran and returnedData and type(returnedData) == "table" and returnedData.Value == encValue and returnedData.Event then
					local returnedEvent = returnedData.Event;
					if returnedEvent == self.CurrentEvent.RemoteEvent then
						foundEvents = true

						--// If the function returns an event and it's not the one we found, blacklist the one we found for the next scan
					else
						objBlacklist[self.CurrentEvent.RemoteEvent] = true
					end

					--// If the function did not return an event, then blacklist it as it's probably fake (Malicious server script?)
				else
					objBlacklist[self.CurrentEvent.RemoteFunction] = true
				end
			end

		until (foundEvents and self.CurrentEvent.RemoteEvent and self.CurrentEvent.RemoteFunction) or not task.wait(0.15)

		self.CurrentEvent.RemoteEvent.OnClientEvent:Connect(function(...)
			self:ProcessRemoteCommand(...)
		end)

		self.CurrentEvent.RemoteFunction.OnClientInvoke = function(...)
			return self:ProcessRemoteCommand(...)
		end

		self.CurrentEvent.RemoteEvent.Changed:Connect(function(...)
			self:EventChangeDetected(...)
		end)

		self.CurrentEvent.RemoteFunction.Changed:Connect(function(...)
			self:EventChangeDetected(...)
		end)

		Root.DebugWarn("Found Remotes")

		GettingEvent = false
	end
end

--- Obtains remote key from the server if it hasn't already been obtained.
--- @method UpdateRemoteKey
--- @within Client.Remote
--- @yields
function Remote.UpdateRemoteKey(self)
	if not self.ObtainedKeys then
		self.RemoteKey = self:Get("GetKeys")
		self.ObtainedKeys = true
	end
end


-- #region Remote Commands

--- Sends data to an active session (if any)
--- @function SessionData
--- @within Client.Remote.Commands
--- @param sessionKey string -- Session key
--- @param ... any -- Arguments
--- @tag Remote Command
function RemoteCommands.SessionData(sessionKey, ...)
	if sessionKey then
		if Sessions[sessionKey] then
			local session = Root.Remote:GetSession(sessionKey)
			if session then
				session:FireEvent(...)
			end
		end
	end
end


--- Gives a server error to the client.
--- @function ErrorMessages
--- @within Client.Remote.Commands
--- @param data table -- Error data
--- @tag Remote Command
function RemoteCommands.ErrorMessage(data)
	Utilities.Events.ServerError:Fire(data)
end


--- Declares settings and their values to the client
--- @function DeclareSettings
--- @within Client.Remote.Commands
--- @param settings table -- Table of settings in the format of [setting] = value
--- @tag Remote Command
function RemoteCommands.DeclareSettings(settings)
	if Root.Settings then
		for setting,value in pairs(settings) do
			rawset(Root.Settings, setting, value)
		end
		Utilities.Events.SettingsDeclared:Fire(settings)
	end
end


--- Updates a specific setting
--- @function UpdateSetting
--- @within Client.Remote.Commands
--- @param setting string -- Setting
--- @param value any -- Value
--- @tag Remote Command
function RemoteCommands.UpdateSetting(setting, value)
	rawset(Root.Settings, setting, value)
end


return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Utilities.Services

		Root.Remote = Remote
	end;

	AfterInit = function(Root, Package)
		local objNameValue = Package.Shared:WaitForChild("EventObjectName")
		local sharedKeyValue = Package.Shared:WaitForChild("SharedKey")

		Remote.EventObjectsName = objNameValue.Value
		Remote.RemoteKey = sharedKeyValue.Value

		Remote:SetupRemote()
		Remote:UpdateRemoteKey()
		Remote:Send("ClientReady")

		Utilities.Events.ClientReady:Fire()
	end;
}
