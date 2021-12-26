--// Package Metadata
return {
	Name = "Admin";
	Version = 1.0;
	Description = [[ Responsible for administrative functionality. ]];
	Author = "Sceleratis";
	Package = script.Parent;

	Dependencies = {
		"Core",
		"Utilities",
		"UI"
	};

	Settings = {
		["Roles"] = {
			DefaultValue = {},
			Description = "System Roles"
		},

		["Users"] = {
			DefaultValue = {},
			Description = "System Users"
		},

		["Prefix"] = {
			DefaultValue = ":",
			Description = "Character that must appear at the start of a message to indicate it is a command",
			Package = script.Parent,
			ClientAllowed = true
		},

		["SplitChar"] = {
			DefaultValue = " ",
			Description = "Character used when splitting command strings into arguments.",
			Package = script.Parent,
			ClientAllowed = true
		},

		["BatchChar"] = {
			DefaultValue = "~|~",
			Description = "Character used to break up command strings into multiple command strings.",
			Package = script.Parent,
			ClientAllowed = true
		}
	}
}
