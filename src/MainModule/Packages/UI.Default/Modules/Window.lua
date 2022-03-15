return function(Root)
	return {
		Members = {
			Position = {
				Type = "UDim2",
				Path = function(real)
					return real.Main, "Position"
				end,
			},
			MainFrame = {
				Read = function(real, window)
					return Root.UI:Wrap(real.Main)
				end,
			},
			Title = {
				Type = "string",
				Default = "Window",
				Path = function(real)
					return real.Main.Topbar.Title, "Text"
				end,
			},
			Icon = {
				Type = "string",
				Default = "rbxassetid://7510994359",
				Path = function(real)
					return real.Main.Topbar.Icon, "Image"
				end,
			},
			NoClose = {
				Type = "boolean",
				Default = false,
				Read = function(real, window)
					return if real.Main.Topbar.Buttons:FindFirstChild("Close") then false else true
				end,
				Update = function(real, window, val)
					window._data.CloseButton.Parent = if val then nil else real.Main.Topbar.Buttons
				end,
			},
			NoHide = {
				Type = "boolean",
				Default = false,
				Read = function(real, window)
					return if real.Main.Topbar.Buttons:FindFirstChild("Hide") then false else true
				end,
				Update = function(real, window, val)
					window._data.HideButton.Parent = if val then nil else real.Main.Topbar.Buttons
				end,
			},
			AddTitleButton = function(window, buttonData, dontMount)
				buttonData.Class = {
					ClassName = "WindowTitleButton",
					--Prefabricated = script.TitleButton
				}
				buttonData.Children = buttonData.Children or {{Class = "Shadow"}}
				if buttonData.Text then
					table.insert(buttonData.Children, {
						Class = "TextLabel",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0, 0),
						ZIndex = 3,
						Font = buttonData.Font or Enum.Font.Arial,
						LineHeight = 1.15,
						Text = buttonData.Text or "",
						TextColor3 = buttonData.TextColor3 or Color3.fromRGB(243, 243, 243),
						TextSize = buttonData.TextSize or 24,
						TextTransparency = 0.24
					})
					buttonData.Text, buttonData.TextColor3, buttonData.TextSize, buttonData.Font = nil, nil, nil, nil
				end
				if not dontMount then buttonData.Parent = window._objectRef.Main.Topbar.Buttons end
				return window._AdonisUI:Construct(buttonData)
			end,
			Close = function(window)
				if window._data.windowClosed then return end
				window._data.windowClosed = true
				window.Closing:Fire()
				window.MainFrame.ClipsDescendants = true
				window.MainFrame:TweenSize(UDim2.fromScale(0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.25)
				window.MainFrame:TweenTransparency(0.4, TweenInfo.new(0.3))
				task.wait(0.3)
				window.Closed:Fire()
				window:Destroy()
				
			end,
			IsClosed = {
				Read = function(real, window)
					return window._data.windowClosed
				end,
			},
			IsMinimized = {
				Read = function(real, window)
					return window._data.windowHidden
				end,
			},
			Hide = function(window)
				if not window._data.windowHidden then
					window.Minimizing:Fire()
					window._data.windowHidden = true
					window._data.originalSizeY = window.MainFrame.Size.Y.Offset
					window.MainFrame:TweenSize(
						UDim2.fromOffset(window.MainFrame.Size.X.Offset, window._objectRef.Main.Topbar.Size.Y.Offset),
						Enum.EasingDirection.Out,
						Enum.EasingStyle.Quint,
						0.3,
						true,
						function()
							window.Minimized:Fire()
							window._containerRef.Visible = false
							window._data.hideDebounce = nil
						end
					)
				end
			end,
			Show = function(window)
				if window._data.windowHidden then
					window.Maximizing:Fire()
					window._data.windowHidden = false
					window._containerRef.Visible = true
					window.MainFrame:TweenSize(
						UDim2.fromOffset(window.MainFrame.Size.X.Offset, window._data.originalSizeY),
						Enum.EasingDirection.Out,
						Enum.EasingStyle.Quart,
						0.3,
						true,
						function()
							window.Maximized:Fire()
							window._data.hideDebounce = nil
						end
					)
					window._data.originalSizeY = nil
				end
			end,
			ToggleHidden = function(window)
				if window.IsMinimized then window:Show() else window:Hide() end
			end,
		},

		Events = {
			"Closing", "Closed",
			"Minimizing", "Minimized",
			"Maximizing", "Maximized",
			"Resizing", "Resized",
			"DragStarted", "DragEnded"
		},

		Initialize = function(window, real)		
			local UserInputService: UserInputService = Root.Utilities.Services.UserInputService

			local data = window._data

			local topbar = real.Main.Topbar

			local function IsInFrame(window, x, y)
				local absPos = window.AbsolutePosition
				local absSize = window.AbsoluteSize
				return (x >= absPos.X and x <= absPos.X + absSize.X) and (y >= absPos.Y and y <= absPos.Y + absSize.Y)
			end
			local function IsInWindow(x, y)
				if real.Enabled and IsInFrame(real.Main, x, y) then
					for _, w in ipairs(Root.UI:GetInterfacesByClass("Window", true)) do
						if w.Enabled and IsInFrame(w.MainFrame, x, y) and w.DisplayOrder > real.DisplayOrder then
							return false
						end
					end
					return true
				end
				return false
			end

			data.CloseButton = window:AddTitleButton({
				Name = "Close",
				BackgroundColor3 = Color3.fromRGB(154, 67, 67),
				BackgroundTransparency = 0.2,
				LayoutOrder = 1,
				Text = "x",
				MouseButton1Click = function()
					window:Close()
				end,
			}, true)
			data.HideButton = window:AddTitleButton({
				Name = "Hide",
				LayoutOrder = 0,
				Text = "–",
				MouseButton1Click = function()
					if data.hideDebounce then return end
					data.hideDebounce = true
					window:ToggleHidden()
				end,
			}, true)

			window:AssociateEvent(UserInputService.InputBegan, function(input, gameHandled)
				if not gameHandled and real.Enabled and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
					local x, y = input.Position.X, input.Position.Y
					if IsInFrame(topbar, x, y) then
						window.DragStarted:Fire(x, y)
					end
				end
			end)
		end,

		ContainerPath = function(real)
			return real.Main.Content
		end,
	}

end
