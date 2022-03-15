return {
	Members = {
		Size = {
			Default = UDim2.fromOffset(22, 22),
			Path = function(real) return real, "Size" end
		},
		DynamicSize = {
			Type = "boolean",
			Default = true,
			Update = function(real, checkbox, val)
				if val then
					local TextService = game:GetService("TextService")
					local textLabel = real.TextLabel
					local function updateSize()
						real.Size = UDim2.fromOffset(
							if real.TextLabel.Text == "" then 22
								else 30 + TextService:GetTextSize(textLabel.Text, textLabel.TextSize, textLabel.Font, Vector2.new(999999999, 22)).X,
							real.Size.Y.Offset
						)
					end
					checkbox._data.dynamicSizeConnection = textLabel:GetPropertyChangedSignal("Text"):Connect(updateSize)
					updateSize()
				elseif checkbox._data.dynamicSizeConnection then
					checkbox._data.dynamicSizeConnection:Disconnect()
					checkbox._data.dynamicSizeConnection = nil
				end
			end,
		},
		Color3 = {
			Type = "Color3",
			Default = Color3.fromRGB(40, 40, 40),
			Path = function(real)
				return real.TextButton, "BackgroundColor3"
			end,
		},
		Transparency = {
			Type = "number",
			Default = 0.2,
			Path = function(real)
				return real.TextButton, "BackgroundTransparency"
			end,
		},
		IsChecked = {
			Type = "boolean",
			Default = false,
			Read = function(real, checkbox)
				return real.TextButton.Text == "X"
			end,
			Update = function(real, checkbox, val)
				if val then
					real.TextButton.Text = "X"
					checkbox.Checked:Fire()
				else
					real.TextButton.Text = ""
					checkbox.Unchecked:Fire()
				end
				checkbox.Toggled:Fire(val)
			end,
		},
		IsEnabled = {
			Type = "boolean",
			Default = true,
			Read = function(real, checkbox)
				return real.TextButton.Active
			end,
			Update = function(real, checkbox, val)
				real.TextButton.Active = val
				real.TextButton.AutoButtonColor = val
			end,
		},
		Text = {
			Type = "string",
			Default = "",
			Path = function(real)
				return real.TextLabel, "Text"
			end,
		}
	},

	Events = { "Toggled", "Checked", "Unchecked" },

	Structure = {
		Class = "Frame",
		BackgroundTransparency = 1,
		Children = {
			{
				Class = "TextButton",
				AutoButtonColor = false,
				BorderColor3 = Color3.fromRGB(200, 200, 200),
				BorderSizePixel = 1,
				Size = UDim2.fromOffset(22, 22),
				Font = Enum.Font.Roboto,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 14,

				MouseButton1Click = function(self)
					if self.Active then
						self.Parent.IsChecked = not self.Parent.IsChecked
					end
				end,
			},
			{
				Class = "TextLabel",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(30, 0),
				Size = UDim2.new(1, -30, 1, 0),
				Font = Enum.Font.Gotham,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 14,
				TextTransparency = 0.1,
				TextXAlignment = Enum.TextXAlignment.Left
			}
		}
	},
}
