--[[

	Description: UI module.
	Author: Sceleratis
	Date: 2/12/2022

--]]

return {
	Name = "List";
	LoadModule = function(self, Root, moduleData, data, ...)
		local Utilities = Root.Utilities

		--// Window
		local window = Root.UI:GetPrefab("Window") ; window:Init()
		local pagedList = Root.UI:GetPrefab("PagedList") ; pagedList:Init()
		local contentFrame = window:GetContentFrame()
		local session, sessionEvent
		local windowProperties = {
			Title = data.Title or "List",
			MinSize = data.MinSize or { 300, 200 },
			MaxSize = data.MaxSize or { 1000, 10000 },
		}

		local labelBase = Utilities:CreateInstance("TextLabel", {
			Size = UDim2.new(1, -20, 1, -4),
			Position = UDim2.new(0, 5, 0, 2),
			BackgroundTransparency = 1,
			Font = "Gotham",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 14,
			TextXAlignment = "Left",
			TextYAlignment = "Center",
			TextWrapped = false,
			TextScaled = false,
			LineHeight = 1,
			MaxVisibleGraphemes = -1,
			TextTransparency = 0,
			TextStrokeTransparency = 1,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			RichText = data.RichText,

			Attributes = {
				UseFont = "Font",
				UseTextColor = "TextColor3",
				UseListTextSize = "TextSize",
				UseListTextXAlignment = "TextXAlignment",
				UseListTextYAlignment = "TextYAlignment",
				UseListTextWrapped = "TextWrapped",
				UseListTextScaled = "TextScaled",
				UseListMaxVisibleGraphemes = "MaxVisibleGraphemes",
				UseTextStrokeTransparency = "TextStrokeTransparency",
				UseTextStrokeColor = "TextStrokeColor3",
				UseTextTransparency = "TextTransparency",
				UseListLineHeight = "LineHeight",
			}
		})

		local function Generate()
			local generationList = {}
			for i,entry in ipairs(data.List) do
				local entryObj = Root.UI:GetPrefab("ExpandableEntry") ; entryObj:Init()
				local mainFrame = entryObj:GetMainFrame()
				local subFrame = entryObj:GetSubFrame()

				if type(entry) == "table" then
					local mainText = entry.Text
					local subText = entry.Expanded or mainText

					local mainLabel = Utilities:EditInstance(labelBase:Clone(), {
						Parent = mainFrame,
						Text = mainText,
					})

					local subLabel = Utilities:EditInstance(mainLabel:Clone(), {
						Parent = subFrame,
						Text = subText
					})

					local subSize = Utilities.Services.TextService:GetTextSize(subText, subLabel.TextSize, subLabel.Font, subLabel.AbsoluteSize)

					entryObj:SetProperties({
						ExpandEnabled = true;
						SubContentSize = UDim2.new(1, 0, 0, subSize.Y + 4)
					})
				else
					local val = tostring(entry)
					local mainLabel = Utilities:EditInstance(labelBase:Clone(), {
						Parent = mainFrame,
						Text = val,
					})

					entryObj:SetProperties({
						ExpandEnabled = false;
					})
				end

				table.insert(generationList, entryObj)
			end
			pagedList:SetContents(generationList)
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
					if session then
						session:SendToServer("Refresh")
					end
				end
			elseif type(data.Refresh) == "function" then
				windowProperties.RefreshHandler = function()
					local listData = data.Refresh()
					warn("DO REFRESH???", listData)
				end
			end
		end

		--// Init window prefab, set properties, and hook it's OnClose event
		window:SetProperties(windowProperties)
		window:HookEvent("Closed", function()
			if session then
				session:End()
			end

			if sessionEvent then
				sessionEvent:Disconnect()
			end
		end)

		pagedList.Prefab.Parent = contentFrame

		Root.UI:ApplyThemeSettings(labelBase)
		Generate()

		--// Tag ScreenGui as "List" and set theme-related properties
		Root.UI:Tag(window, "ADONIS_UI", "List")
		Root.UI:ApplyThemeSettings(window)

		--// Set parent
		Root.UI:SetParent(window.Prefab)

        print("LIST LOADED", tostring(window))
	end,
}
