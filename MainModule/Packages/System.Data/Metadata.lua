--// Package Metadata
return {
	Name = "System.Data";
	Version = 1.0;
	Description = [[ Responsible for data handling/saving functionality. ]];
	Author = "Sceleratis";
	Package = script.Parent;

	Dependencies = {
		"System.Core",
		"System.Utilities",
	};

	Settings = {
		["DataStoreName"] = {
			DefaultValue = "Adonis2.0_1",
			Description = "Datastore name prefix."
		},
		["DataStoreKey"] = {
			DefaultValue = "CHANGE_ME",
			Description = "Key used to encrypt saved system data to attempt to prevent tampering.",
		},
		["SavingEnabled"] = {
			DefaultValue = true,
			Description = "Whether or not the system will save changes made in-game."
		},
	}
}
