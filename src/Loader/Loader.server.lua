--[[

	Description: Responsible for loading Hermes's MainModule
	Author: Sceleratis
	Date: 12/05/2021

	--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!--
	--																			--
	-- Non-developers should only edit the contents of the 'Config' folder. 	--
	-- Making changes here can break things and may prevent successful loading. --
	-- If you break something, it's on you to debug it. 						--
	-- Do NOT submit issues or demand help for problems you created! 			--
	-- Continuing means you accept any risk that comes with this.				--
	-- Proceed with caution. 													--
	--																			--
	--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!--

--]]

--// Whether or not to load a local MainModule in the Loader's parent directory. If false, will load the MainModule by it's AssetID
local LocalMode = true;

--// Loader
local Loader = {

	--// MainModule
	MainModule = if LocalMode then script.Parent.Parent.Hermes else 0;

	--// Get settings
	Settings = require(script.Parent.Config.Settings);

	--// Loader object references
	LoaderModel = script.Parent;
	ConfigFolder = script.Parent.Config;
	Packages = script.Parent.Config.Packages;

	--// Method which handles MainModule loading
	LoadMainModule = function(self)
		local moduleFunc = require(self.MainModule);
		local response = moduleFunc(self, self.Settings, self.Packages);

		if not response then
			warn(":: Hermes Loader :: Something went wrong while loading.");
		end
	end;
}

--// Load Server
Loader:LoadMainModule();
