--[[

	Description: Responsible for basic client-server communication and player handling
	Author: Sceleratis
	Date: 12/11/2021

--]]


local Package, Utilities, Root

local Service

local MakingEvent = false;

--// Remote (client-to-server) commands
local RemoteCommands = setmetatable({
	GetKeys = function(p, ...)
		local data = Root.Core:GetPlayerData(p)
		if data then
			if not data.ObtainedKeys then
				data.ObtainedKeys = true
				data.RemoteKey = Utilities:RandomString()
				Root.DebugWarn("Player Obtained Keys", p)
				return data.RemoteKey
			else
				Utilities.Events.PlayerError:Fire(p, "Player attempted to re-obtain keys")
			end
		else
			Utilities.Events.PlayerError:Fire(p, "GetKeys failed (no player data found)")
		end
	end,

	VerifyRemote = function(p: Player, t, ...)
		return {
			Value = Utilities:Encrypt(Root.Remote.SharedKey .. t, Root.Remote.SharedKey);
			Event = Root.Remote.CurrentEvent.RemoteEvent;
		}
	end,

	ClientReady = function(p, ...)
		local data = Root.Core:GetPlayerData(p);
		if data then
			if not data.ClientReady then
				data.ClientReady = true;
				Utilities.Events.PlayerReady:Fire(p, data);
				Root.DebugWarn("Player Finished Loading", p, ...);

				return true;
			end
		else
			Utilities.Events.PlayerError:Fire(p, "GetKeys failed (no player data found)")
		end
	end,

	SessionData = function(p: Player, sessionKey, ...)
		local session = if sessionKey then Root.Remote:GetSession(sessionKey) else nil

		if session and session.Users[p] then
			session:FireEvent(p, ...)
		end
	end;

	Setting = function(p: Player, setting: string)
		local declared = Root.Core.DeclaredSettings[string]
		if declared and declared.ClientAllowed then
			return Root.Settings[setting]
		end
	end;

	SetUserSettings = function(p: Player, settings)
		local data = Root.Core:GetPlayerData(p)
		local userSettings = data.UserSettings

		for setting,value in pairs(settings) do
			userSettings[setting] = value
		end
	end;
},{
	__newindex = function(self, ind, value)
		if self[ind] ~= nil then
			Root.Warn("RemoteCommand index already declared. Overwriting...", ind)
		end

		rawset(self, ind, value)

		Utilities.Events.RemoteCommandDeclared:Fire(ind, value)
	end
})

--// Methods
local Methods = {
	Session = {
		AddUser = function(self, p: Player, defaultData)
			assert(not self.Ended, "Cannot add user to session: Session Ended")
			if not self.Users[p] then
				self.Users[p] = defaultData or {}
				self.NumUsers += 1
			end
		end;

		RemoveUser = function(self, p: Player)
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
		end;

		SetActiveUser = function(self, p: Player)
			if not self.ActiveUsers[p] then
				self.NumActiveUsers += 1
				self.ActiveUsers[p] = true
			end
		end,

		RemoveActiveUser = function(self, p: Player)
			if self.ActiveUsers[p] then
				self.NumActiveUsers -= 1
				self.ActiveUsers[p] = nil

				if self.NumActiveUsers == 0 then
					self:FireEvent(nil, "LastUserLeft")
				end
			end
		end,

		SendToUsers = function(self, ...)
			if not self.Ended then
				for p in pairs(self.ActiveUsers) do
					self:SendToUser(p, ...)
				end
			end
		end;

		SendToAllUsers = function(self, ...)
			if not self.Ended then
				for p in pairs(self.Users) do
					self:SendToUser(p, ...);
				end
			end
		end;

		SendToUser = function(self, p: Player, ...)
			if not self.Ended and self.Users[p] then
				Root.Remote:Send(p, "SessionData", self.SessionKey, ...)
			end
		end;

		FireEvent = function(self, ...)
			if not self.Ended then
				self.SessionEvent:Fire(...)
			end
		end;

		End = function(self)
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
		end;

		ConnectEvent = function(self, func)
			assert(not self.Ended, "Cannot connect session event: Session Ended")

			local connection = self.SessionEvent.Event:Connect(func)
			table.insert(self.Events, connection)

			return connection
		end;
	}
}

--// Remote
local Remote = {
	SharedKey = "";
	EventObjectsName = "";
	Commands = RemoteCommands;
	Sessions = {};

	--// Player-related methods
	Send = function(self, p, cmd, ...)
		if p:IsA("Player") and not Utilities.Wrapping:IsWrapped(p) then
			local curEvent = self:WaitForEvent();
			if curEvent then
				local data = Root.Core:GetPlayerData(p)
				local cmd = Utilities:Encrypt(cmd, data.RemoteKey or self.SharedKey);

				Root.DebugWarn("SENDING", p, cmd, ...)
				curEvent.RemoteEvent:FireClient(p, cmd, table.pack(...));
			end
		end
	end,

	Get = function(self, p: Player, cmd, ...)
		if p:IsA("Player") and not Utilities.Wrapping:IsWrapped(p) then
			local curEvent = self:WaitForEvent();
			if curEvent then
				local data = Root.Core:GetPlayerData(p)
				local cmd = Utilities:Encrypt(cmd, data.RemoteKey or self.SharedKey);

				Root.DebugWarn("GETTING", p, cmd, ...)
				return table.unpack(curEvent.RemoteFunction:InvokeClient(p, cmd, table.pack(...)));
			end
		end
	end,

	LoadCode = function(self, p, code, ...)
		local bytecode = Root.Bytecode:GetBytecode(code)
		self:Send(p, "RunBytecode", bytecode, ...)
	end;

	LoadCodeWithReturn = function(self, p, code, ...)
		local bytecode = Root.Bytecode:GetBytecode(code)
		return self:Get(p, "RunBytecode", bytecode, ...)
	end;

	SendError = function(self, player: Player, data: {})
		self:Send(player, "ErrorMessage", data)
	end,

	GetSession = function(self, sessionKey)
		return self.Sessions:GetData(sessionKey);
	end,

	NewSession = function(self, users)
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
	end;

	--// Process remote commands
	ProcessRemoteCommand = function(self, p: Player, cmd, args)
		local data = Root.Core:GetPlayerData(p)
		local cmd = Utilities:Decrypt(cmd, data.RemoteKey or self.SharedKey)
		local command = self.Commands[cmd]

		if type(args) ~= "table" then
			args = {args}
		end

		Root.DebugWarn("Remote command received", p, cmd, args)

		Utilities.Events.ReceivedRemoteCommand:Fire(p, cmd, if type(args) == "table" then table.unpack(args) else args)

		if command then
			return table.pack(command(p, table.unpack(args)))
		end
	end,

	--// Handle player client setup
	WaitForEvent = function(self)
		while not self.CurrentEvent or not self.CurrentEvent.RemoteEvent or not self.CurrentEvent.RemoteFunction or MakingEvent do
			Utilities.Services.RunService.Heartbeat:Wait()
		end

		return self.CurrentEvent
	end,

	SetupClient = function(self, p: Player)
		local handler = Package.Handlers.ClientHandler:Clone()
		local packageHandler = Root.PackageHandlerModule:Clone()
		local clientPackages = Root.PackageHandler.GetClientPackages(Root.Packages)
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

		Root.DebugWarn("CLIENT PACKAGES:", clientPackages, cliPackageFolder)
		Root.DebugWarn("STRIPPED:", strippedPackages)

		packageHandler.Parent = handler;

		repeat
			local parentTo = p:FindFirstChildOfClass("PlayerScripts") or p:FindFirstChildOfClass("PlayerGui")
			if parentTo then
				handler.Parent = parentTo
			end
		until handler.Parent ~= nil or not task.wait(0.15)

		handler.Disabled = false
	end,

	--// Event setup
	EventChangeDetected = function(self, c)
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
	end,

	SetupRemote = function(self)
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
						end,

						Changed = function(...)
							self:EventChangeDetected(...);
						end,
					}
				});

				RemoteFunction = Utilities:CreateInstance("RemoteFunction", {
					Name = self.EventObjectsName;
					Parent = Service.ReplicatedStorage;

					OnServerInvoke = function(...)
						return self:ProcessRemoteCommand(...)
					end,

					Events = {
						Changed = function(...)
							self:EventChangeDetected(...);
						end,
					}
				})
			}

			MakingEvent = false
		end
	end,
}

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
