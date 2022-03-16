return function(Root)
	local WINDOW_SIZE_TYPE = "UDim2 | table"
	return {
		Members = {
			Position = {
				Type = "UDim2",
				Path = function(real)
					return real.Main, "Position"
				end,
			},
			Size = {
				Type = WINDOW_SIZE_TYPE,
				Default = UDim2.fromOffset(300, 200),
				Read = function(real, window)
					return real.Main.Size
				end,
				Update = function(real, window, val)
					real.Main.Size = if typeof(val) == "UDim2" then val else UDim2.fromOffset(unpack(val))
				end,
			},
			MinSize = {
				Type = WINDOW_SIZE_TYPE,
				Default = UDim2.fromOffset(200, 100)
			},
			MaxSize = {
				Type = WINDOW_SIZE_TYPE,
				Default = UDim2.fromOffset(1000, 1000)
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
			Minimize = function(window)
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
			Maximize = function(window)
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
				if window.IsMinimized then window:Maximize() else window:Minimize() end
			end,
		},

		Events = {
			"Closing", "Closed",
			"Minimizing", "Minimized",
			"Maximizing", "Maximized",
			"Resizing", "Resized",
			"DragStarted", "DragEnded"
		},

		Initialize = function(window, real: ScreenGui)		
			local UserInputService: UserInputService = Root.Utilities.Services.UserInputService
			local Mouse: Mouse = Root.Utilities.Services.Players.LocalPlayer:GetMouse()

			local MOUSE_ICONS = {
				Horizontal = "rbxassetid://1243146213",
				Vertical = "rbxassetid://1243145985",
				LowerLeft = "rbxassetid://1243145459",
				LowerRight = "rbxassetid://1243145350",
				UpperRight = "rbxassetid://1243145459",
				UpperLeft = "rbxassetid://1243145350"
			}
			local originalMouseIcon = nil

			local data = window._data
			local miscData = {}
			local dragging = false
			local resizing = false
			local originalDisplayOrder = real.DisplayOrder

			local mainFrame = real.Main
			local topbar = mainFrame.Topbar

			local function IsInFrame(frame, x, y)
				local absPos = frame.AbsolutePosition
				local absSize = frame.AbsoluteSize
				return (x >= absPos.X and x <= absPos.X + absSize.X) and (y >= absPos.Y and y <= absPos.Y + absSize.Y)
			end
			local function IsInWindow(x, y)
				if real.Enabled and IsInFrame(real.Main, x, y) then
					for _, w in ipairs(Root.UI:GetInterfacesByClass("Window", true)) do
						if w ~= window and w.Enabled and IsInFrame(w.MainFrame, x, y) and w.DisplayOrder > real.DisplayOrder then
							return false
						end
					end
					return true
				end
				return false
			end

			data.resizeZones = {}
			for _, obj in pairs(mainFrame:GetChildren()) do
				data.resizeZones[obj] = obj.Name:match("Resize_(.*)")
			end
			local function IsResizeRequest(x, y)
				for zone, zoneName in pairs(data.resizeZones) do
					if IsInFrame(zone, x, y) then
						return zoneName
					end
				end
			end

			local function BringToFront()
				local maxOrder = originalDisplayOrder
				for _, v in ipairs(Root.UI:GetInterfacesByClass("Window", true)) do
					if not v:GetAttribute("WindowFocus_OriginalDisplayOrder") then
						v:SetAttribute("WindowFocus_OriginalDisplayOrder", v.DisplayOrder)
					end
					local origOrder = v:GetAttribute("WindowFocus_OriginalDisplayOrder")
					v.DisplayOrder = origOrder - 1
					if v.DisplayOrder > maxOrder then
						maxOrder = v.DisplayOrder
					end
				end
				real.DisplayOrder = maxOrder + 1
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
					if IsInWindow(x, y) then
						BringToFront()
						resizing = not data.windowHidden and IsResizeRequest(x, y)
						if resizing then
							originalMouseIcon = Mouse.Icon

							miscData.FramePosX = mainFrame.AbsolutePosition.X
							miscData.FramePosY = mainFrame.AbsolutePosition.Y

							miscData.FrameSizeX = mainFrame.AbsoluteSize.X
							miscData.FrameSizeY = mainFrame.AbsoluteSize.Y

							miscData.FrameDragStartX = x - mainFrame.AbsolutePosition.X
							miscData.FrameDragStartY = y - mainFrame.AbsolutePosition.Y
						elseif IsInFrame(topbar, x, y) then
							miscData.FrameDragStartX = x - mainFrame.AbsolutePosition.X
							miscData.FrameDragStartY = y - mainFrame.AbsolutePosition.Y
							dragging = true
							window.DragStarted:Fire(x, y)
						end
					end
				end
			end)

			window:AssociateEvent(UserInputService.InputChanged, function(input, gameHandled)
				if real.Enabled and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					local x, y = input.Position.X, input.Position.Y
					if dragging then
						mainFrame.Position = UDim2.fromOffset(x - miscData.FrameDragStartX, y - miscData.FrameDragStartY)
					elseif resizing then
						Mouse.Icon = MOUSE_ICONS[
						if resizing == "Left" or resizing == "Right" then "Horizontal"
							elseif resizing == "Top" or resizing == "Bottom" then "Vertical"
							else resizing
						]

						local newPos = UDim2.new(0, mainFrame.AbsolutePosition.X, 0, mainFrame.AbsolutePosition.Y)
						local sizeX = miscData.FrameSizeX
						local sizeY = miscData.FrameSizeY
						local posX = miscData.FramePosX
						local posY = miscData.FramePosY

						local moveX = false
						local moveY = false

						if resizing == "UpperRight" then
							sizeX = x - posX + 3
							sizeY = posY - y + sizeY - 1
							moveY = true
						elseif resizing == "UpperLeft" then
							sizeX = posX - x + sizeX -1
							sizeY = posY - y + sizeY -1
							moveY = true
							moveX = true
						elseif resizing == "Right" then
							sizeX = x - posX + 3
							sizeY = sizeY
						elseif resizing == "Left" then
							sizeX = posX - x + sizeX + 3
							moveX = true
						elseif resizing == "LowerRight" then
							sizeX = x - posX + 3
							sizeY = y - posY + 3
						elseif resizing == "LowerLeft" then
							sizeX = posX - x + sizeX + 3
							sizeY = y - posY + 3
							moveX = true
						elseif resizing == "Top" then
							sizeY = posY - y + sizeY - 1
							moveY = true
						elseif resizing == "Bottom" then
							sizeX = sizeX
							sizeY = y - posY + 3
						end

						local minSize, maxSize = data.__MinSize, data.__MaxSize
						sizeX = math.clamp(sizeX, minSize.X.Offset, maxSize.X.Offset)
						sizeY = math.clamp(sizeY, minSize.Y.Offset, maxSize.Y.Offset)

						if moveX then
							newPos = UDim2.new(0, (posX + miscData.FrameSizeX) - sizeX, 0, newPos.Y.Offset)
						end

						if moveY then
							newPos  = UDim2.new(0, newPos.X.Offset, 0, (posY + miscData.FrameSizeY) - sizeY)
						end

						mainFrame.Position = newPos
						mainFrame.Size = UDim2.new(0, sizeX, 0, sizeY)
					end
				end
			end)

			window:AssociateEvent(UserInputService.InputEnded, function(input, gameHandled)
				if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
					if resizing and originalMouseIcon then
						Mouse.Icon = originalMouseIcon
					end
					dragging = false
					resizing = false
				end
			end)
		end,

		ContainerPath = function(real)
			return real.Main.Content
		end,
	}

end
