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

		["UI_Colors"] = {
			DefaultValue = {
				Primary = Color3.fromRGB(0, 59, 255),
			    Secondary = Color3.fromRGB(227, 73, 67),
			    Tertiary = Color3.fromRGB(255, 255, 255),
			    Quaternary = Color3.fromRGB(56, 0, 79),
			    Text = Color3.fromRGB(255, 255, 255),
			    Icon = Color3.fromRGB(255, 255, 255),
			},

			Description = "UI Colors. Must be supported by the currently selected prefab or module group.",
			Package = script.Parent,
			ClientAllowed = true,
		}
	};
}
