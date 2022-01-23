--// Package Metadata
return {
	Name = "System.Admin";
	Version = 1.0;
	Description = [[ Responsible for administrative functionality. ]];
	Author = "Sceleratis";
	Package = script.Parent;

	Dependencies = {
		"System.Core",
		"System.Utilities",
		"System.Data",
		"System.UI"
	};

	Settings = {
		["Roles"] = {
			DefaultValue = {},
			Description = "System Roles",
			Package = script.Parent,
			ClientAllowed = false
		},

		["Users"] = {
			DefaultValue = {},
			Description = "System Users",
			Package = script.Parent,
			ClientAllowed = false
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
		},

		["BanMessage"] = {
			DefaultValue = "Banned",
			Description = "Ban message",
		},

		["BanList"] = {
			DefaultValue = {},
			Description = "Ban list",
		}
	}
}
