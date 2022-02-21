--[[

	Description: Responsible for logging
	Author: Sceleratis
	Date: 12/11/2021

--]]

local Root, Package, Utilities, Service

local Logging = {
	Logs = {};

	AddLog = function(self, logType: string, logEntry: {Text: string?, Description: string?, Time: number?, NoTime: boolean?}|string, ...)
		local logTable = self.Logs[logType]

		if not logTable then
			self.Logs[logType] = {}
			logTable = self.Logs[logType]
		end

		if logTable and type(logTable) == "table" then
			local format = table.pack(...)

			if type(logEntry) == "string" then
				logEntry = {
					Text = logEntry;
					Description = logEntry;
				}
			end

			if #format > 0 then
				logEntry.Text = string.format(logEntry.Text, table.unpack(format))
			end

			if not logEntry.Time and not logEntry.NoTime then
				logEntry.Time = Utilities:GetTime()
			end

			if logType == "Error" then
				warn("[Error Log] ", logEntry.Text)
			end

			table.insert(logTable, logEntry)

			Utilities.Events.LogAdded:Fire(logType, logEntry)
		else
			Root.Warn("Invalid LogType Supplied:", logType)
		end
	end;

	GetLogs = function(self, Type: string)
		local logTable = self.Logs[Type]
		if logTable and type(logTable) == "table" then
			return logTable
		else
			return {}
		end
	end;
}

return {
	Init = function(cRoot: {}, cPackage: Folder)
		Root = cRoot
		Package = cPackage
		Utilities = Root.Utilities
		Service = Root.Utilities.Services

		Root.Logging = Logging
	end;

	AfterInit = function(Root, Package)
		Logging:AddLog("Script", "[%s] Logging module loaded", Package.Name)
	end;
}
