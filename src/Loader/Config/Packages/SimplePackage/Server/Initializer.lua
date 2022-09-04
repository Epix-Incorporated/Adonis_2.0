--[[

	Description: 
	Author: 
	Date: 

--]]


--// Initializer functions
return {
	{
		--// RunOrder determines the order in which initialization functions run. 
		--// All functions from all packages with the same RunOrder will run before all packages in all packages of the next RunOrder. (Eg. All RunOrder 1 run, then all RunOrder 2, etc.)
		--// Functions in a group will run in the order they are added. Two functions in the same init module with the same RunOrder will run in the order they appear.
		RunOrder = 1;
		Function = function(Root, Packages)
			--// Do client-side init stuff
			--// print("Hello World! We're in the client init!")
		end;
	};
	{
		RunOrder = 2;
		Function = function(Root, Packages)
			--// Do client-side stuff after init
			--// print("Hello World! We're in the client after init!")
		end;
	}
}