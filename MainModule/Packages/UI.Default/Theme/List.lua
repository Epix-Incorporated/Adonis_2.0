--[[

	Description: List window.
	Author: Sceleratis
	Date: 2/12/2022

--]]

return {
	OnLoad = function(self, Root, gTable, data, ...)
		--// Window
		local window = Root.UI:GetPrefab("Window")
		local contentFrame = window:GetContentFrame()
		local session, sessionEvent
		local windowProperties = {
			Title = data.Title or "List",
			MinSize = data.MinSize or { 300, 200 },
			MaxSize = data.MaxSize or { 1000, 10000 },
		}

		--// Paged list
		local pagedList = Root.UI:GetPrefab("PagedList")

		local function Generate()
			for i,entry in ipairs(data.List) do
				if type(entry) == "table" then
					local main = entry.Text
					local sub = entry.Expanded
					
				else
					local val = tostring(entry)
				end
			end
		end

		if data.Refresh then
			if type(data.Refresh) == "string" then
				session = Root.Remote:GetSession(data.Refresh)
				sessionEvent = session:Connect(function(cmd, data)
					if cmd == "Refresh" then
						warn("DO REFRESH???", data)
					end
				end)

				windowProperties.RefreshHandler = function()
					session:SendToServer("Refresh")
				end
			elseif type(data.Refresh) == "function" then
				windowProperties.RefreshHandler = function()
					local listData = data.Refresh()
					warn("DO REFRESH???", listData)
				end
			end
		end

		window:Init()
		window:SetProperties(windowProperties)
		window:HookEvent("Closed", function()
			if session then
				session:End()
			end

			if sessionEvent then
				sessionEvent:Disconnect()
			end
		end)

		Generate()
		window.Prefab.Parent = Root.Services

        print("WINDOW", tostring(window))
	end,
}
