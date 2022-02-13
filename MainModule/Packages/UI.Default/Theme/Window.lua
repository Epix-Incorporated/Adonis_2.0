--[[

	Description: List window.
	Author: Sceleratis
	Date: 2/12/2022

--]]

return {
	OnLoad = function(Root, gTable, data, ...)
        local window = Root.UI:GetPrefab("Window")
		local contentFrame = window:GetContentFrame()
		local children = data.Children;
		local title = data.Title;
		local maxSize = data.MaxSize;
		local minSize = data.MinSize;

		window.

        print("WINDOW", tostring(window))
	end,
}
