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
		["UI_ModuleGroup"] = {
			DefaultValue = "Default",
			Description = "Default UI module group",
			Package = script.Parent,
			ClientAllowed = true,
		},

		["UI_PrefabGroup"] = {
			DefaultValue = "Default",
			Description = "Default UI prefab group.",
			Package = script.Parent,
			ClientAllowed = true,
		},

		["UI_ThemeSettings"] = {
			DefaultValue = {
				PrimaryColor = Color3.fromRGB(0, 59, 255),
			    SecondaryColor = Color3.fromRGB(227, 73, 67),
			    TertiaryColor = Color3.fromRGB(255, 255, 255),
			    QuaternaryColor = Color3.fromRGB(56, 0, 79),
			    TextColor = Color3.fromRGB(255, 255, 255),
			    IconColor = Color3.fromRGB(255, 255, 255),
				Font = "Gotham",
			},

			Description = "UI Colors. Must be supported by the currently selected prefab or module group.",
			Package = script.Parent,
			ClientAllowed = true,
		}
	};
}
