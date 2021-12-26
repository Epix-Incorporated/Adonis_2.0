--// Package Metadata
return {
	Name = "UI";
	Version = 1.0;
	Description = [[ Responsible for UI functionality. ]];
	Author = "Sceleratis";
	Package = script.Parent;

	Dependencies = {
		"Core",
		"Utilities",
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
