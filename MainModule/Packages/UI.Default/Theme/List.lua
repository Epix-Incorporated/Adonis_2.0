--[[

	Description: List window.
	Author: Sceleratis
	Date: 2/12/2022

--]]

return {
	OnLoad = function(Root, gTable, ...)
        local window = Root.UI:GetPrefab("Window")

        print("WINDOW", tostring(window))
	end,
}
