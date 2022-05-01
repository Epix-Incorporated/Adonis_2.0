--[[

	Description: Responsible for basic client-server communication and player handling
	Author: Sceleratis
	Date: 12/11/2021

--]]


local Package, Utilities, Root, Service
local MakingEvent = false
local Methods = {}

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


--// Class definitions
--- Remote (client-to-server) commands
--- @class Server.Remote.Commands
--- @server
--- @tag System.Core
--- @tag Package: System.Core
local RemoteCommands = setmetatable({},{
	__newindex = function(self, ind, value)
		if self[ind] ~= nil and Root then
			warn("RemoteCommand index already declared. Overwriting...", ind)
		end

		rawset(self, ind, value)

		if Utilities then
			Utilities.Events.RemoteCommandDeclared:Fire(ind, value)
		end
	end
})


--- Responsible for server-side remote functionality.
--- @class Server.Remote
--- @server
--- @tag Core
--- @tag Package: System.Core
local Remote = {
	SharedKey = "";
	EventObjectsName = "";
	Commands = RemoteCommands;
	Sessions = {};
}


-- #region Remote Commands

--- Returns remote communication keys to the client if not already retrieved.
--- @function GetKeys
--- @within Server.Remote.Commands
--- @tag System.Core
--- @param p Player
function RemoteCommands.GetKeys(p: Player)
	local data = Root.Core:GetPlayerData(p)
	if data then
		if not data.ObtainedKeys then
			data.ObtainedKeys = true
			data.RemoteKey = Utilities:RandomString()
			DebugWarn("Player Obtained Keys", p)
			return data.RemoteKey
		else
			Utilities.Events.PlayerError:Fire(p, "Player attempted to re-obtain keys")
		end
	else
		Utilities.Events.PlayerError:Fire(p, "GetKeys failed (no player data found)")
	end
end


--- Allows the client to verify integrity of the remote event
--- @function VerifyRemote
--- @within Server.Remote.Commands
--- @tag System.Core
--- @param p Player -- Player
--- @param t string -- Test value
function RemoteCommands.VerifyRemote(p: Player, t)
	return {
		Value = Utilities:Encrypt(Root.Remote.SharedKey .. t, Root.Remote.SharedKey);
		Event = Root.Remote.CurrentEvent.RemoteEvent;
	}
end


--- Triggered by clients when they are finished their setup process and are ready for normal communication.
--- @function ClientReady
--- @within Server.Remote.Commands
--- @param p Player
function RemoteCommands.ClientReady(p: Player)
	local data = Root.Core:GetPlayerData(p);
	if data then
		if not data.ClientReady then
			data.ClientReady = true;
			Utilities.Events.PlayerReady:Fire(p, data);
			DebugWarn("Player Finished Loading", p);

			return true;
		end
	else
		Utilities.Events.PlayerError:Fire(p, "GetKeys failed (no player data found)")
	end
end


--- Allows the client to send data to a session their player is a member of. Handled by ServerSession.
--- @function SessionData
--- @within Server.Remote.Commands
--- @param p Player
--- @param sessionKey string -- Session key
--- @param ... any -- Data to be passed
function RemoteCommands.SessionData(p: Player, sessionKey, ...)
	local session = if sessionKey then Root.Remote:GetSession(sessionKey) else nil

	if session and session.Users[p] then
		session:FireEvent(p, ...)
	end
end


--- Returns a setting if that setting has ClientAllowed set to true in its declaration data.
--- @function Setting
--- @within Server.Remote.Commands
--- @param p Player
--- @param setting string
--- @return setting value
function RemoteCommands.Setting(p: Player, setting: string)
	local declared = Root.Core.DeclaredSettings[string]
	if declared and declared.ClientAllowed then
		return Root.Settings[setting]
	end
end


--- Updates UserSettings using data within the provided settings table in the format of [setting] = value
--- @function SetUserSettings
--- @within Server.Remote.Commands
--- @param p Player
--- @param settings table
function RemoteCommands.SetUserSettings(p: Player, settings)
	local data = Root.Core:GetPlayerData(p)
	local userSettings = data.UserSettings

	for setting,value in pairs(settings) do
		userSettings[setting] = value
	end
end



-- #region Misc Methods

--- Server-side session handler
--- @class ServerSession
--- @server
--- @tag Core
--- @tag Package: System.Core

--- Indicates whether this session has ended.
--- @prop Ended bool
--- @within ServerSession

--- Number of users that are members of this session.
--- @prop NumUsers int
--- @within ServerSession

--- Number of active users in this session.
--- @prop NumActiveUsers int
--- @within ServerSession

--- Table that can be used to store session-specific data.
--- @prop Data {}
--- @within ServerSession

--- Session users.
--- @prop Users {}
--- @within ServerSession

--- Session event connections that will be cleaned up on session end.
--- @prop Events {}
--- @within ServerSession

--- Active users.
--- @prop ActiveUsers {}
--- @within ServerSession

--- Session key.
--- @prop SessionKey string
--- @within ServerSession

--- Session event object.
--- @prop SessionEvent BindableEvent
--- @within ServerSession
Methods.Session = {}


--- Adds a user to the session
--- @method AddUser
--- @within ServerSession
--- @param p Player
--- @param defaultData table -- Optional table of default session data for the user
function Methods.Session.AddUser(self, p: Player, defaultData)
	assert(not self.Ended, "Cannot add user to session: Session Ended")
	if not self.Users[p] then
		self.Users[p] = defaultData or {}
		self.NumUsers += 1
	end
end


--- Removes a user from the session
--- @method RemoveUser
--- @within ServerSession
--- @param p Player
function Methods.Session.RemoveUser(self, p: Player)
	assert(not self.Ended, "Cannot remove user from session: Session Ended")
	if self.Users[p] then
		self.Users[p] = nil
		self.NumUsers -= 1

		self:RemoveActiveUser(p)
		self:SendToUser(p, "RemovedFromSession")

		if self.NumUsers == 0 then
			self:FireEvent(nil, "LastUserRemoved")
		else
			self:FireEvent(p, "RemovedFromSession")
		end
	end
end


--- Sets session user as active
--- @method SetActiveUser
--- @within ServerSession
--- @param p Player
function Methods.Session.SetActiveUser(self, p: Player)
	if not self.ActiveUsers[p] then
		self.NumActiveUsers += 1
		self.ActiveUsers[p] = true
	end
end


--- Sets session user as inactive
--- @method RemoveActiveUser
--- @within ServerSession
--- @param p Player
function Methods.Session.RemoveActiveUser(self, p: Player)
	if self.ActiveUsers[p] then
		self.NumActiveUsers -= 1
		self.ActiveUsers[p] = nil

		if self.NumActiveUsers == 0 then
			self:FireEvent(nil, "LastUserLeft")
		end
	end
end


--- Sends data to all active users in the session
--- @method SendToUsers
--- @within ServerSession
--- @param ... any -- Data to send to users
function Methods.Session.SendToUsers(self, ...)
	if not self.Ended then
		for p in pairs(self.ActiveUsers) do
			self:SendToUser(p, ...)
		end
	end
end


--- Sends data to all users in a session, regardless of whether or not they are marked as active
--- @method SendToAllUsers
--- @within ServerSession
--- @param ... any -- Data to send to users
function Methods.Session.SendToAllUsers(self, ...)
	if not self.Ended then
		for p in pairs(self.Users) do
			self:SendToUser(p, ...);
		end
	end
end


--- Sends data to a specific user if they are a session member
--- @method SendToUser
--- @within ServerSession
--- @param p Player
--- @param ... any -- Data to send to use
function Methods.Session.SendToUser(self, p: Player, ...)
	if not self.Ended and self.Users[p] then
		Root.Remote:Send(p, "SessionData", self.SessionKey, ...)
	end
end


--- Fires the session event
--- @method FireEvent
--- @within ServerSession
--- @param ... any -- Session data
function Methods.Session.FireEvent(self, ...)
	if not self.Ended then
		self.SessionEvent:Fire(...)
	end
end


--- Ends the session
--- @method End
--- @within ServerSession
function Methods.Session.End(self)
	if not self.Ended then
		for t, event in pairs(self.Events) do
			event:Disconnect()
			self.Events[t] = nil
		end

		self:SendToUsers("SessionEnded")

		self.NumUsers = 0
		self.NumActiveUsers = 0

		self.Users = {}
		self.ActiveUsers = {}
		self.SessionEvent:Destroy()

		self.Ended = true

		Root.Remote.Sessions:SetData(self.SessionKey, nil)
	end
end


--- Connects a function to the session event
--- @method ConnectEvent
--- @within ServerSession
--- @param func function -- Function
function Methods.Session.ConnectEvent(self, func)
	assert(not self.Ended, "Cannot connect session event: Session Ended")

	local connection = self.SessionEvent.Event:Connect(func)
	table.insert(self.Events, connection)

	return connection
end



-- #region Remote Methods

--- Triggers a remote command on the target player's client with the data specified
--- @method Send
--- @within Server.Remote
--- @param p Player
--- @param cmd string -- Remote command
--- @param ... any -- Data
function Remote.Send(self, p: Player, cmd: string, ...)
	if p:IsA("Player") and not Utilities.Wrapping:IsWrapped(p) then
		local curEvent = self:WaitForEvent();
		if curEvent then
			local data = Root.Core:GetPlayerData(p)
			local cmd = Utilities:Encrypt(cmd, data.RemoteKey or self.SharedKey);

			DebugWarn("SENDING", p, cmd, ...)
			curEvent.RemoteEvent:FireClient(p, cmd, table.pack(...));
		end
	end
end


--- Triggers a remote command on the target player's client with the data specified and returns the result (if any)
--- @method Get
--- @within Server.Remote
--- @param p Player
--- @param cmd string -- Remote command
--- @param ... any -- Data
--- @yields
function Remote.Get(self, p: Player, cmd: string, ...)
	if p:IsA("Player") and not Utilities.Wrapping:IsWrapped(p) then
		local curEvent = self:WaitForEvent();
		if curEvent then
			local data = Root.Core:GetPlayerData(p)
			local cmd = Utilities:Encrypt(cmd, data.RemoteKey or self.SharedKey);

			DebugWarn("GETTING", p, cmd, ...)
			return table.unpack(curEvent.RemoteFunction:InvokeClient(p, cmd, table.pack(...)));
		end
	end
end


--- Instructs the target client to run Lua code provided
--- @method LoadCode
--- @within Server.Remote
--- @param p Player
--- @param code string -- Lua code
--- @param ... any -- Additional data
function Remote.LoadCode(self, p, code, ...)
	local bytecode = Root.Bytecode:GetBytecode(code)
	self:Send(p, "RunBytecode", bytecode, ...)
end


--- Instructs the target client to run Lua code provided and returns the result
--- @method LoadCodeWithReturn
--- @within Server.Remote
--- @param p Player
--- @param code string -- Lua code
--- @param ... any -- Additional data
--- @yields
function Remote.LoadCodeWithReturn(self, p, code, ...)
	local bytecode = Root.Bytecode:GetBytecode(code)
	return self:Get(p, "RunBytecode", bytecode, ...)
end


--- Sends error data to the client
--- @method SendError
--- @within Server.Remote
--- @param player Player
--- @param data table -- Error data
function Remote.SendError(self, player: Player, data: {})
	self:Send(player, "ErrorMessage", data)
end


--- Returns the session associated with sessionKey if it exists
--- @method GetSession
--- @within Server.Remote
--- @param sessionKey string -- Session key
--- @return ServerSession
function Remote.GetSession(self, sessionKey: string)
	return self.Sessions:GetData(sessionKey);
end

--- Session Object

--- Creates a new session and returns its handler
--- @method NewSession
--- @within Server.Remote
--- @param users table -- Optional table of users to add to the session on creation
--- @return ServerSession
function Remote.NewSession(self, users)
	local session = {
		Ended = false;
		NumUsers = 0;
		NumActiveUsers = 0;

		Data = {};
		Users = {};
		Events = {};

		ActiveUsers = {};

		SessionKey = Utilities:RandomString();
		SessionEvent = Instance.new("BindableEvent");

		End = Methods.Session.End;
		AddUser = Methods.Session.AddUser;
		Connect = Methods.Session.ConnectEvent;
		FireEvent = Methods.Session.FireEvent;
		RemoveUser = Methods.Session.RemoveUser;
		SendToUser = Methods.Session.SendToUser;
		SendToUsers = Methods.Session.SendToUsers;
		SendToAllUsers = Methods.Session.SendToAllUsers;
		RemoveActiveUser = Methods.Session.RemoveActiveUser;
		SetActiveUser = Methods.Session.SetActiveUser;
	};

	session.Events.PlayerRemoving = Utilities.Events.PlayerRemoving:Connect(function(p: Player)
		session:RemoveActiveUser(p)
	end)

	session:Connect(function(p, cmd, ...)
		if not session.Ended then
			if cmd == "LeftSession" then
				session:RemoveActiveUser(p)
			elseif session.Users[p] and cmd == "JoinedSession" then
				session:SetActiveUser(p)
			end
		end
	end)

	if users then
		for i,p in ipairs(users) do
			session:AddUser(p)
		end
	end

	Root.Remote.Sessions:SetData(session.SessionKey, session)

	return session
end


--- Handles processing of received remote commands from clients
--- @method ProcessRemoteCommand
--- @within Server.Remote
--- @param p Player -- Origin player
--- @param cmd string -- Remote command recieved
--- @param args any -- Additional remote command arguments
--- @return any
function Remote.ProcessRemoteCommand(self, p: Player, cmd: string, args)
	local data = Root.Core:GetPlayerData(p)
	local cmd = Utilities:Decrypt(cmd, data.RemoteKey or self.SharedKey)
	local command = self.Commands[cmd]

	if type(args) ~= "table" then
		args = {args}
	end

	DebugWarn("Remote command received", p, cmd, args)

	Utilities.Events.ReceivedRemoteCommand:Fire(p, cmd, if type(args) == "table" then table.unpack(args) else args)

	if command then
		return table.pack(command(p, table.unpack(args)))
	end
end


--- Yields the current thread until the RemoteEvent and RemoteFunction objects exist and are ready for usage
--- @method WaitForEvent
--- @within Server.Remote
function Remote.WaitForEvent(self)
	while not self.CurrentEvent or not self.CurrentEvent.RemoteEvent or not self.CurrentEvent.RemoteFunction or MakingEvent do
		Utilities.Services.RunService.Heartbeat:Wait()
	end

	return self.CurrentEvent
end


--- Handles client setup process for player specified
--- @method SetupClient
--- @within Server.Remote
--- @param p Player
--- @yields
function Remote.SetupClient(self, p: Player)
	local handler = Package.Handlers.ClientHandler:Clone()
	local packageHandler = Root.PackageHandlerModule:Clone()
	local clientPackages = Root.PackageHandler.GetPackages(Root.Packages, "Client")
	local strippedPackages = Root.PackageHandler.StripPackages(
		clientPackages,
		"Server"
	);

	local cliPackageFolder = Utilities:CreateInstance("Folder", {
		Parent = handler;
		Name = "Packages";

		--// Get all client packages, then return a table of clones all with the 'Server' folder removed
		Children  = strippedPackages
	})

	DebugWarn("CLIENT PACKAGES:", clientPackages, cliPackageFolder)
	DebugWarn("STRIPPED:", strippedPackages)

	packageHandler.Parent = handler;

	repeat
		local parentTo = p:FindFirstChildOfClass("PlayerScripts") or p:FindFirstChildOfClass("PlayerGui")
		if parentTo then
			handler.Parent = parentTo
		end
	until handler.Parent ~= nil or not task.wait(0.15)

	handler.Disabled = false
end


--- Remote communication object OnChange event handler
--- @method RemoteChangeDetected
--- @within Server.Remote
--- @param c PropertyName
function Remote.EventChangeDetected(self, c)
	local curEvent = self.CurrentEvent
	if curEvent and not MakingEvent then
		local rEvent = curEvent.RemoteEvent
		local rFunction = curEvent.RemoteFunction

		if c == "OnServerInvoke" or (rEvent.Parent ~= Service.ReplicatedStorage or rFunction.Parent ~= Service.ReplicatedStorage) then
			self:SetupRemote()
		elseif rEvent.Name ~= self.EventObjectsName or rFunction.Name ~= self.EventObjectsName then
			rEvent.Name = self.EventObjectsName
			rFunction.Name = self.EventObjectsName
		end
	end
end


--- Handles remote communication object setup process
--- @method SetupRemote
--- @within Server.Remote
--- @yields
function Remote.SetupRemote(self)
	if not MakingEvent then
		MakingEvent = true

		if self.CurrentEvent then
			self.CurrentEvent.RemoteEvent:Destroy()
			self.CurrentEvent.RemoteFunction:Destroy()
			self.CurrentEvent = nil
		end

		self.CurrentEvent = {
			RemoteEvent = Utilities:CreateInstance("RemoteEvent", {
				Name = self.EventObjectsName;
				Parent = Service.ReplicatedStorage;

				Events = {
					OnServerEvent = function(...)
						self:ProcessRemoteCommand(...);
					end;

					Changed = function(...)
						self:EventChangeDetected(...);
					end;
				}
			});

			RemoteFunction = Utilities:CreateInstance("RemoteFunction", {
				Name = self.EventObjectsName;
				Parent = Service.ReplicatedStorage;

				OnServerInvoke = function(...)
					return self:ProcessRemoteCommand(...)
				end;

				Events = {
					Changed = function(...)
						self:EventChangeDetected(...);
					end;
				}
			})
		}

		MakingEvent = false
	end
end


--// Events
local function PlayerAdded(p)
	Remote:SetupClient(p)
	Root.Logging:AddLog("Script", "Setup client for %s", p.Name)
end

return {
	Init = function(cRoot, cPackage)

		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Utilities.Services

		Root.Remote = Remote;

		--// EventObjName & SharedKey Init
		local objNameValue = Package.Shared.EventObjectName
		local sharedKeyValue = Package.Shared.SharedKey

		objNameValue.Value = Utilities:RandomString()
		sharedKeyValue.Value = Utilities:RandomString()

		Remote.EventObjectsName = objNameValue.Value
		Remote.SharedKey = sharedKeyValue.Value
		Remote.Sessions = Utilities:MemoryCache({
			AccessResetsTimer = true,	--// Reset timeout timer on session access
			Timeout = 60 * 60 			--// If a session is unused for an hour, assume it's dead... no session should be lasting this long without usage
		})

		Root.Core:DeclareDefaultPlayerData("RemoteKey", function()
			return Remote.SharedKey
		end)
	end;

	AfterInit = function(Root, Package)
		Remote:SetupRemote();
		Utilities.Events.PlayerAdded:Connect(PlayerAdded)
	end;
}
