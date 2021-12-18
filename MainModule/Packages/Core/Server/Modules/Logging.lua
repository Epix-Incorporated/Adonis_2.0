--[[

	Description: Responsible for logging
	Author: Sceleratis
	Date: 12/11/2021

--]]

local Root, Package, Utilities, Service

local Logging = {
	Logs = {};

	AddLog = function(self, Type: string, Log: {}, ...)
		local logTab = self.Logs[Type];

		if not logTab then
			self.Logs[Type] = {}
			logTab = self.Logs[Type]
		end

		if logTab and type(logTab) == "table" then
			local newLog = Log;
			local format = table.pack(...);

			if type(newLog) == "string" then
				newLog = {
					Text = Log;
					Desc = Log;
				}
			end

			if #format > 0 then
				newLog.Text = string.format(newLog.Text, table.unpack(format))
			end

			if not newLog.Time and not newLog.NoTime then
				newLog.Time = Utilities:GetTime()
			end

			if Type == "Error" then
				warn("[Error Log] ", newLog.Text)
			end

			table.insert(logTab, newLog);
		else
			Root.Warn("Invalid LogType Supplied", Type)
		end
	end;

	GetLogs = function(self, Type: string)
		local logTab = self.Logs[Type];
		if logTab and type(logTab) == "table" then
			return logTab
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
