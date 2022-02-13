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
		},

		["Colors"] = {
			DefaultValue = {
				Primary = Color3.fromRGB(0, 59, 255),
			    Secondary = Color3.fromRGB(227, 73, 67),
			    Tertiary = Color3.fromRGB(255, 255, 255),
			    Quaternary = Color3.fromRGB(56, 0, 79),
			    Text = Color3.fromRGB(255, 255, 255),
			    Icon = Color3.fromRGB(255, 255, 255),
			},

			Description = "Theme Colors. Must be supported by the currently selected theme.",
			Package = script.Parent,
			ClientAllowed = true,
		}
	};
}
