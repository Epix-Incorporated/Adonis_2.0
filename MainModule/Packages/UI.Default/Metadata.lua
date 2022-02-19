--// Package Metadata
return {
	Name = "UI.Default";
	Version = 1.0;
	Description = [[ Provides default UI theme. ]];
	Author = "Sceleratis";
	Package = script.Parent;

	PrefabGroup = "Default"; 	--// The group we're adding prefabs to
	ModuleGroup = "Default";	--// The group we're adding UI modules to

	PrefabFallback = nil;	--// Fallback group for prefabs (if we can't find an element, fallback to searching this group, then Default)
	ModuleFallback = nil;	--// Fallback group for UI modules

	Dependencies = {
		"System.Core",
		"System.Utilities",
		"System.UI"
	};
}
