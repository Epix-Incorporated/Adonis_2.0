--// Package Metadata
return {
	Name = "System.UI";
	Version = 1.0;
	Description = [[ Responsible for UI functionality. ]];
	Author = "Sceleratis";
	Package = script.Parent;

	Dependencies = {
		"System.Core",
		"System.Utilities",
		"System.Libraries"
	};

	Settings = {
		["Theme"] = {
			DefaultValue = "Default",
			Description = "Default UI theme",
			Package = script.Parent,
			ClientAllowed = true,
		}
	};
}
