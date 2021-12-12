--[[

	Description:
	Author:
	Date:

--]]


local Root, Utilities, Service, Package;

local UI = {
	DeclaredThemes = {};
	ActiveObjects = {};

	DeclareTheme = function(self, themeName, themeFolder)
		if self.DeclaredThemes[themeName] then
			Root.Warn("Theme already declared. Overwriting. ThemeName: ", themeName);
			Utilities.Events.UIWarning:Fire("Overwriting existing theme", themeName, themeFolder);
		end

		self.DeclaredThemes[themeName] = themeFolder;
		Utilities.Events.DeclaredTheme:Fire(themeName, themeFolder);
	end;

	GetElement = function(self, uiName, themeInfo, ...)
		local themeName = themeInfo.Theme;
		local theme = self.DeclaredThemes[themeName]

		if theme then
			local baseTheme = theme:FindFirstChild("BaseTheme");
			local targObj = theme:FindFirstChild(uiName) or (if baseTheme then self:GetUIElement(uiName, Utilities.MergeTables({}, themeInfo, {Theme = baseTheme.Value}), ...) else nil);
			if targObj then
				return targObj;
			else
				Root.Warn("Theme object not found:", uiName);
			end
		else
			Root.Warn("Theme not found:", themeName);
		end
	end;

	NewElement = function(self, uiName, themeInfo, ...)
		local obj = self:GetElement(uiName, themeInfo, ...);
		if obj then
			if obj:IsA("ModuleScript") then
				local func = require(obj);
				if func then
					return func(Root, themeInfo, self:GetHandler(obj), ...);
				end
			elseif obj:IsA("Folder") then
				local configMod = obj:FindFirstChild("Config")
				if configMod and configMod:IsA("ModuleScript") then
					local config = require(configMod);
					if config and type(config) == "table" then
					end
				else
					Root.Warn("Config not found for:", uiName);
				end
			end
		end
	end;

	GetHandler = function(self, obj)
	end;
}

return {
	Init = function(cRoot, cPackage)
		Root = cRoot
		Utilities = Root.Utilities
		Package = cPackage
		Service = Root.Utilities.Services

		--// Do init
		Root.UI = UI
	end;

	AfterInit = function(Root, Package)
		--// Do after-init
	end;
}
