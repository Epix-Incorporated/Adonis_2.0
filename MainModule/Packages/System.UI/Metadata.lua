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
				Primary = Color3.fromRGB(33, 118, 208),
				Secondary = Color3.fromRGB(48, 48, 48),
				Tertiary = Color3.fromRGB(245, 245, 245),
				Icon = Color3.fromRGB(245, 245, 245),
				Text = Color3.fromRGB(245, 245, 245),
			},

			Description = "Theme Colors. Must be supported by the currently selected theme.",
			Package = script.Parent,
			ClientAllowed = true,
		}
	};
}
