-- Elma / Linoria-Style Left-Tab UI Library (Mobile Friendly)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Library = {
	Flags = {},
	Options = {},
	Signals = {},
	Theme = {
		MainColor = Color3.fromRGB(16, 16, 18),
		SecondaryColor = Color3.fromRGB(24, 24, 27),
		GroupColor = Color3.fromRGB(20, 20, 23),
		OutlineDark = Color3.fromRGB(8, 8, 10),
		OutlineGrey = Color3.fromRGB(58, 58, 64),
		AccentColor = Color3.fromRGB(196, 38, 38), -- Classic Non-Neon Red
		FontColor = Color3.fromRGB(235, 235, 240),
		MutedColor = Color3.fromRGB(145, 145, 155),
		Font = Enum.Font.Code
	},
	ToggleKey = Enum.KeyCode.RightShift,
	Visible = true,
	ActiveTab = nil,
	ScreenGui = nil
}

local function AddConnection(signal, callback)
	local conn = signal:Connect(callback)
	table.insert(Library.Signals, conn)
	return conn
end

local function Create(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	return inst
end

-- Classic Linoria Multi-Layer Border (Outer Dark -> Mid Grey -> Inner Dark)
local function ApplyLinoriaBorder(parent, accentTop)
	local outer = Create("UIStroke", {
		Color = Library.Theme.OutlineDark,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent
	})

	local innerFrame = Create("Frame", {
		Name = "LinoriaBorderFrame",
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.new(0, 1, 0, 1),
		BackgroundTransparency = 1,
		ZIndex = parent.ZIndex + 1,
		Parent = parent
	})

	Create("UIStroke", {
		Color = Library.Theme.OutlineGrey,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = innerFrame
	})

	if accentTop then
		local accentBar = Create("Frame", {
			Name = "AccentLine",
			Size = UDim2.new(1, 0, 0, 2),
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundColor3 = Library.Theme.AccentColor,
			BorderSizePixel = 0,
			ZIndex = parent.ZIndex + 3,
			Parent = parent
		})
		Library.Options["__AccentBars"] = Library.Options["__AccentBars"] or {}
		table.insert(Library.Options["__AccentBars"], accentBar)
	end

	Library.Options["__OuterBorders"] = Library.Options["__OuterBorders"] or {}
	Library.Options["__GreyBorders"] = Library.Options["__GreyBorders"] or {}
	table.insert(Library.Options["__OuterBorders"], outer)
	table.insert(Library.Options["__GreyBorders"], innerFrame:FindFirstChildOfClass("UIStroke"))

	return innerFrame
end

local function MakeDraggable(dragHandle, targetFrame)
	local dragging = false
	local dragInput, dragStart, startPos

	AddConnection(dragHandle.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = targetFrame.Position

			local endConn
			endConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					if endConn then endConn:Disconnect() end
				end
			end)
		end
	end)

	AddConnection(dragHandle.InputChanged, function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	AddConnection(UserInputService.InputChanged, function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			targetFrame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)
end

function Library:SetWatermark(text)
	if not self.WatermarkLabel then return end
	self.WatermarkLabel.Text = "  " .. tostring(text)
	local bounds = self.WatermarkLabel.TextBounds.X + 24
	self.WatermarkFrame.Size = UDim2.new(0, math.max(150, bounds), 0, 24)
end

function Library:ToggleVisibility(state)
	if state ~= nil then
		self.Visible = state
	else
		self.Visible = not self.Visible
	end
	if self.MainFrame then
		self.MainFrame.Visible = self.Visible
	end
end

function Library:UpdateTheme(customTheme)
	for k, v in pairs(customTheme or {}) do
		self.Theme[k] = v
	end

	if self.MainFrame then
		self.MainFrame.BackgroundColor3 = self.Theme.MainColor
	end
	if self.TopBar then
		self.TopBar.BackgroundColor3 = self.Theme.SecondaryColor
	end
	if self.LeftTabPanel then
		self.LeftTabPanel.BackgroundColor3 = self.Theme.SecondaryColor
	end
	if self.ContentHolder then
		self.ContentHolder.BackgroundColor3 = self.Theme.MainColor
	end
	if self.WatermarkFrame then
		self.WatermarkFrame.BackgroundColor3 = self.Theme.SecondaryColor
	end
	if self.MobileToggleBtn then
		self.MobileToggleBtn.BackgroundColor3 = self.Theme.SecondaryColor
		self.MobileToggleBtn.TextColor3 = self.Theme.FontColor
	end

	for _, stroke in ipairs(self.Options["__OuterBorders"] or {}) do
		if stroke then stroke.Color = self.Theme.OutlineDark end
	end
	for _, stroke in ipairs(self.Options["__GreyBorders"] or {}) do
		if stroke then stroke.Color = self.Theme.OutlineGrey end
	end
	for _, bar in ipairs(self.Options["__AccentBars"] or {}) do
		if bar then bar.BackgroundColor3 = self.Theme.AccentColor end
	end
	for _, fn in ipairs(self.Options["__ThemeCallbacks"] or {}) do
		pcall(fn, self.Theme)
	end
end

function Library:CreateWindow(config)
	config = config or {}
	local titleText = config.Title or "ELMA HUB | LINORIA LEFT"
	local subText = config.SubTitle or "v1.0"
	local size = config.Size or UDim2.new(0, 450, 0, 450)
	local tabWidth = config.TabWidth or 116

	if self.ScreenGui then
		self.ScreenGui:Destroy()
	end

	self.ScreenGui = Create("ScreenGui", {
		Name = "LinoriaLeftUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
		Parent = PlayerGui
	})

	-- Mobile / Quick Toggle Button (Top-Left floating)
	self.MobileToggleBtn = Create("TextButton", {
		Name = "MobileToggle",
		Size = UDim2.new(0, 74, 0, 26),
		Position = UDim2.new(0, 12, 0, 12),
		BackgroundColor3 = self.Theme.SecondaryColor,
		TextColor3 = self.Theme.FontColor,
		Font = self.Theme.Font,
		TextSize = 12,
		Text = "[ UI ]",
		BorderSizePixel = 0,
		ZIndex = 100,
		Parent = self.ScreenGui
	})
	ApplyLinoriaBorder(self.MobileToggleBtn, true)
	MakeDraggable(self.MobileToggleBtn, self.MobileToggleBtn)

	AddConnection(self.MobileToggleBtn.MouseButton1Click, function()
		self:ToggleVisibility()
	end)

	-- Watermark (Top-Right)
	self.WatermarkFrame = Create("Frame", {
		Name = "Watermark",
		Size = UDim2.new(0, 210, 0, 24),
		Position = UDim2.new(1, -222, 0, 12),
		BackgroundColor3 = self.Theme.SecondaryColor,
		BorderSizePixel = 0,
		ZIndex = 90,
		Parent = self.ScreenGui
	})
	ApplyLinoriaBorder(self.WatermarkFrame, true)

	self.WatermarkLabel = Create("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		TextColor3 = self.Theme.FontColor,
		Font = self.Theme.Font,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "  " .. titleText .. " | " .. subText,
		ZIndex = 92,
		Parent = self.WatermarkFrame
	})

	-- Main Window (Compact 450x450 default for mobile/desktop)
	self.MainFrame = Create("Frame", {
		Name = "MainWindow",
		Size = size,
		Position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2),
		BackgroundColor3 = self.Theme.MainColor,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 10,
		Parent = self.ScreenGui
	})
	ApplyLinoriaBorder(self.MainFrame, true)

	-- Top Header Bar
	self.TopBar = Create("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, -2, 0, 28),
		Position = UDim2.new(0, 1, 0, 2),
		BackgroundColor3 = self.Theme.SecondaryColor,
		BorderSizePixel = 0,
		ZIndex = 12,
		Parent = self.MainFrame
	})
	MakeDraggable(self.TopBar, self.MainFrame)

	local titleLabel = Create("TextLabel", {
		Size = UDim2.new(1, -80, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1,
		TextColor3 = self.Theme.FontColor,
		Font = self.Theme.Font,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = titleText,
		ZIndex = 14,
		Parent = self.TopBar
	})

	local subLabel = Create("TextLabel", {
		Size = UDim2.new(0, 70, 1, 0),
		Position = UDim2.new(1, -76, 0, 0),
		BackgroundTransparency = 1,
		TextColor3 = self.Theme.MutedColor,
		Font = self.Theme.Font,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = subText,
		ZIndex = 14,
		Parent = self.TopBar
	})

	-- Divider line under TopBar
	local topDivider = Create("Frame", {
		Size = UDim2.new(1, -2, 0, 1),
		Position = UDim2.new(0, 1, 0, 30),
		BackgroundColor3 = self.Theme.OutlineGrey,
		BorderSizePixel = 0,
		ZIndex = 15,
		Parent = self.MainFrame
	})
	Library.Options["__GreyBorders"] = Library.Options["__GreyBorders"] or {}
	table.insert(Library.Options["__GreyBorders"], topDivider)

	-- Left Tab Panel (Vertical Tabs on Left!)
	self.LeftTabPanel = Create("Frame", {
		Name = "LeftTabPanel",
		Size = UDim2.new(0, tabWidth, 1, -33),
		Position = UDim2.new(0, 1, 0, 31),
		BackgroundColor3 = self.Theme.SecondaryColor,
		BorderSizePixel = 0,
		ZIndex = 12,
		Parent = self.MainFrame
	})

	local tabListLayout = Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = self.LeftTabPanel
	})

	Create("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		Parent = self.LeftTabPanel
	})

	-- Vertical Divider between Left Tabs and Content Area
	local vertDivider = Create("Frame", {
		Name = "VertDivider",
		Size = UDim2.new(0, 1, 1, -33),
		Position = UDim2.new(0, tabWidth + 1, 0, 31),
		BackgroundColor3 = self.Theme.OutlineGrey,
		BorderSizePixel = 0,
		ZIndex = 15,
		Parent = self.MainFrame
	})
	table.insert(Library.Options["__GreyBorders"], vertDivider)

	-- Content Holder (Right side)
	self.ContentHolder = Create("Frame", {
		Name = "ContentHolder",
		Size = UDim2.new(1, -(tabWidth + 4), 1, -34),
		Position = UDim2.new(0, tabWidth + 2, 0, 31),
		BackgroundColor3 = self.Theme.MainColor,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 12,
		Parent = self.MainFrame
	})

	AddConnection(UserInputService.InputBegan, function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == self.ToggleKey then
			self:ToggleVisibility()
		end
	end)

	local WindowObj = {}
	local tabCounter = 0

	function WindowObj:AddTab(tabName)
		tabCounter += 1
		local isFirst = (tabCounter == 1)

		local tabButton = Create("TextButton", {
			Name = "Tab_" .. tabName,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = isFirst and Library.Theme.GroupColor or Library.Theme.MainColor,
			TextColor3 = isFirst and Library.Theme.FontColor or Library.Theme.MutedColor,
			Font = Library.Theme.Font,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "  " .. tabName,
			BorderSizePixel = 0,
			LayoutOrder = tabCounter,
			ZIndex = 14,
			Parent = Library.LeftTabPanel
		})

		local tabStroke = Create("UIStroke", {
			Color = isFirst and Library.Theme.AccentColor or Library.Theme.OutlineGrey,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = tabButton
		})

		local indicator = Create("Frame", {
			Name = "ActiveBar",
			Size = UDim2.new(0, 2, 1, -4),
			Position = UDim2.new(0, 2, 0, 2),
			BackgroundColor3 = Library.Theme.AccentColor,
			BorderSizePixel = 0,
			Visible = isFirst,
			ZIndex = 15,
			Parent = tabButton
		})
		Library.Options["__AccentBars"] = Library.Options["__AccentBars"] or {}
		table.insert(Library.Options["__AccentBars"], indicator)

		-- Scrollable Tab Page
		local tabPage = Create("ScrollingFrame", {
			Name = "Page_" .. tabName,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Library.Theme.AccentColor,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = isFirst,
			ZIndex = 13,
			Parent = Library.ContentHolder
		})

		Create("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 10),
			Parent = tabPage
		})

		local pageLayout = Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			Parent = tabPage
		})

		local TabData = {
			Button = tabButton,
			Stroke = tabStroke,
			Indicator = indicator,
			Page = tabPage
		}

		local function SelectTab()
			if Library.ActiveTab == TabData then return end

			if Library.ActiveTab then
				Library.ActiveTab.Page.Visible = false
				Library.ActiveTab.Indicator.Visible = false
				Library.ActiveTab.Button.BackgroundColor3 = Library.Theme.MainColor
				Library.ActiveTab.Button.TextColor3 = Library.Theme.MutedColor
				Library.ActiveTab.Stroke.Color = Library.Theme.OutlineGrey
			end

			Library.ActiveTab = TabData
			tabPage.Visible = true
			indicator.Visible = true
			tabButton.BackgroundColor3 = Library.Theme.GroupColor
			tabButton.TextColor3 = Library.Theme.FontColor
			tabStroke.Color = Library.Theme.AccentColor
		end

		if isFirst then
			Library.ActiveTab = TabData
		end

		AddConnection(tabButton.MouseButton1Click, SelectTab)

		Library.Options["__ThemeCallbacks"] = Library.Options["__ThemeCallbacks"] or {}
		table.insert(Library.Options["__ThemeCallbacks"], function(theme)
			local isSelected = (Library.ActiveTab == TabData)
			tabButton.Font = theme.Font
			tabButton.BackgroundColor3 = isSelected and theme.GroupColor or theme.MainColor
			tabButton.TextColor3 = isSelected and theme.FontColor or theme.MutedColor
			tabStroke.Color = isSelected and theme.AccentColor or theme.OutlineGrey
		end)

		local TabObj = {}

		function TabObj:AddGroupbox(groupTitle)
			local groupFrame = Create("Frame", {
				Name = "Group_" .. groupTitle,
				Size = UDim2.new(1, 0, 0, 36),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Library.Theme.GroupColor,
				BorderSizePixel = 0,
				ZIndex = 14,
				Parent = tabPage
			})
			ApplyLinoriaBorder(groupFrame, false)

			-- Groupbox Header Label (Linoria style)
			local headerLabel = Create("TextLabel", {
				Size = UDim2.new(1, -12, 0, 20),
				Position = UDim2.new(0, 8, 0, 2),
				BackgroundTransparency = 1,
				TextColor3 = Library.Theme.FontColor,
				Font = Library.Theme.Font,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = groupTitle,
				ZIndex = 16,
				Parent = groupFrame
			})

			local headerLine = Create("Frame", {
				Size = UDim2.new(1, -12, 0, 1),
				Position = UDim2.new(0, 6, 0, 22),
				BackgroundColor3 = Library.Theme.OutlineGrey,
				BorderSizePixel = 0,
				ZIndex = 16,
				Parent = groupFrame
			})
			table.insert(Library.Options["__GreyBorders"], headerLine)

			local itemContainer = Create("Frame", {
				Name = "Items",
				Size = UDim2.new(1, -12, 0, 0),
				Position = UDim2.new(0, 6, 0, 26),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				ZIndex = 15,
				Parent = groupFrame
			})

			Create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
				Parent = itemContainer
			})

			Create("UIPadding", {
				PaddingBottom = UDim.new(0, 8),
				Parent = itemContainer
			})

			table.insert(Library.Options["__ThemeCallbacks"], function(theme)
				groupFrame.BackgroundColor3 = theme.GroupColor
				headerLabel.Font = theme.Font
				headerLabel.TextColor3 = theme.FontColor
			end)

			local GroupObj = {}

			function GroupObj:AddLabel(text)
				local lbl = Create("TextLabel", {
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
					TextColor3 = Library.Theme.MutedColor,
					Font = Library.Theme.Font,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = text,
					ZIndex = 16,
					Parent = itemContainer
				})

				table.insert(Library.Options["__ThemeCallbacks"], function(theme)
					lbl.Font = theme.Font
					lbl.TextColor3 = theme.MutedColor
				end)

				return {
					SetText = function(_, newText)
						lbl.Text = tostring(newText)
					end
				}
			end

			function GroupObj:AddButton(btnText, callback)
				local btn = Create("TextButton", {
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundColor3 = Library.Theme.SecondaryColor,
					TextColor3 = Library.Theme.FontColor,
					Font = Library.Theme.Font,
					TextSize = 12,
					Text = btnText,
					BorderSizePixel = 0,
					ZIndex = 16,
					Parent = itemContainer
				})
				ApplyLinoriaBorder(btn, false)

				AddConnection(btn.MouseButton1Click, function()
					btn.BackgroundColor3 = Library.Theme.AccentColor
					task.delay(0.1, function()
						if btn then
							btn.BackgroundColor3 = Library.Theme.SecondaryColor
						end
					end)
					if callback then
						task.spawn(callback)
					end
				end)

				table.insert(Library.Options["__ThemeCallbacks"], function(theme)
					btn.Font = theme.Font
					btn.BackgroundColor3 = theme.SecondaryColor
					btn.TextColor3 = theme.FontColor
				end)

				return btn
			end

			function GroupObj:AddToggle(flag, opts)
				opts = opts or {}
				local text = opts.Text or flag
				local defaultVal = (opts.Default == true)

				local holder = Create("Frame", {
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					ZIndex = 16,
					Parent = itemContainer
				})

				local box = Create("TextButton", {
					Size = UDim2.new(0, 16, 0, 16),
					Position = UDim2.new(0, 0, 0.5, -8),
					BackgroundColor3 = defaultVal and Library.Theme.AccentColor or Library.Theme.SecondaryColor,
					Text = "",
					BorderSizePixel = 0,
					ZIndex = 17,
					Parent = holder
				})
				ApplyLinoriaBorder(box, false)

				local labelBtn = Create("TextButton", {
					Size = UDim2.new(1, -24, 1, 0),
					Position = UDim2.new(0, 24, 0, 0),
					BackgroundTransparency = 1,
					TextColor3 = Library.Theme.FontColor,
					Font = Library.Theme.Font,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = text,
					ZIndex = 17,
					Parent = holder
				})

				local ToggleObj = {
					Value = defaultVal,
					Type = "Toggle"
				}

				function ToggleObj:SetValue(val)
					self.Value = (val == true)
					Library.Flags[flag] = self.Value
					box.BackgroundColor3 = self.Value and Library.Theme.AccentColor or Library.Theme.SecondaryColor
					if opts.Callback then
						task.spawn(opts.Callback, self.Value)
					end
				end

				local function flip()
					ToggleObj:SetValue(not ToggleObj.Value)
				end

				AddConnection(box.MouseButton1Click, flip)
				AddConnection(labelBtn.MouseButton1Click, flip)

				table.insert(Library.Options["__ThemeCallbacks"], function(theme)
					labelBtn.Font = theme.Font
					labelBtn.TextColor3 = theme.FontColor
					box.BackgroundColor3 = ToggleObj.Value and theme.AccentColor or theme.SecondaryColor
				end)

				Library.Flags[flag] = defaultVal
				Library.Options[flag] = ToggleObj
				if opts.Callback then
					task.spawn(opts.Callback, defaultVal)
				end

				return ToggleObj
			end

			function GroupObj:AddSlider(flag, opts)
				opts = opts or {}
				local text = opts.Text or flag
				local minVal = opts.Min or 0
				local maxVal = opts.Max or 100
				local rounding = opts.Rounding or 0
				local defaultVal = math.clamp(opts.Default or minVal, minVal, maxVal)

				local function roundNum(n)
					if rounding <= 0 then
						return math.floor(n + 0.5)
					end
					local mult = 10 ^ rounding
					return math.floor(n * mult + 0.5) / mult
				end

				local holder = Create("Frame", {
					Size = UDim2.new(1, 0, 0, 34),
					BackgroundTransparency = 1,
					ZIndex = 16,
					Parent = itemContainer
				})

				local topLbl = Create("TextLabel", {
					Size = UDim2.new(1, 0, 0, 15),
					BackgroundTransparency = 1,
					TextColor3 = Library.Theme.FontColor,
					Font = Library.Theme.Font,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = text .. ": " .. tostring(defaultVal),
					ZIndex = 17,
					Parent = holder
				})

				local barBg = Create("TextButton", {
					Size = UDim2.new(1, 0, 0, 14),
					Position = UDim2.new(0, 0, 0, 18),
					BackgroundColor3 = Library.Theme.SecondaryColor,
					Text = "",
					BorderSizePixel = 0,
					ZIndex = 17,
					Parent = holder
				})
				ApplyLinoriaBorder(barBg, false)

				local initRatio = (maxVal - minVal) == 0 and 0 or ((defaultVal - minVal) / (maxVal - minVal))
				local fill = Create("Frame", {
					Size = UDim2.new(initRatio, 0, 1, 0),
					BackgroundColor3 = Library.Theme.AccentColor,
					BorderSizePixel = 0,
					ZIndex = 18,
					Parent = barBg
				})

				local SliderObj = {
					Value = defaultVal,
					Type = "Slider"
				}

				function SliderObj:SetValue(val)
					local clamped = math.clamp(roundNum(val), minVal, maxVal)
					self.Value = clamped
					Library.Flags[flag] = clamped
					local ratio = (maxVal - minVal) == 0 and 0 or ((clamped - minVal) / (maxVal - minVal))
					fill.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
					topLbl.Text = text .. ": " .. tostring(clamped)
					if opts.Callback then
						task.spawn(opts.Callback, clamped)
					end
				end

				local sliding = false
				local function updateFromInput(inputPos)
					local absPos = barBg.AbsolutePosition.X
					local absSize = math.max(1, barBg.AbsoluteSize.X)
					local alpha = math.clamp((inputPos.X - absPos) / absSize, 0, 1)
					SliderObj:SetValue(minVal + (maxVal - minVal) * alpha)
				end

				AddConnection(barBg.InputBegan, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						sliding = true
						updateFromInput(input.Position)
					end
				end)

				AddConnection(UserInputService.InputChanged, function(input)
					if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
						updateFromInput(input.Position)
					end
				end)

				AddConnection(UserInputService.InputEnded, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						sliding = false
					end
				end)

				table.insert(Library.Options["__ThemeCallbacks"], function(theme)
					topLbl.Font = theme.Font
					topLbl.TextColor3 = theme.FontColor
					barBg.BackgroundColor3 = theme.SecondaryColor
					fill.BackgroundColor3 = theme.AccentColor
				end)

				Library.Flags[flag] = defaultVal
				Library.Options[flag] = SliderObj
				return SliderObj
			end

			function GroupObj:AddDropdown(flag, opts)
				opts = opts or {}
				local text = opts.Text or flag
				local values = opts.Values or {}
				local defaultVal = opts.Default or values[1] or ""

				local holder = Create("Frame", {
					Size = UDim2.new(1, 0, 0, 38),
					BackgroundTransparency = 1,
					ZIndex = 16,
					Parent = itemContainer
				})

				local lbl = Create("TextLabel", {
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					TextColor3 = Library.Theme.FontColor,
					Font = Library.Theme.Font,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = text,
					ZIndex = 17,
					Parent = holder
				})

				local dropBtn = Create("TextButton", {
					Size = UDim2.new(1, 0, 0, 22),
					Position = UDim2.new(0, 0, 0, 15),
					BackgroundColor3 = Library.Theme.SecondaryColor,
					TextColor3 = Library.Theme.FontColor,
					Font = Library.Theme.Font,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = "  " .. tostring(defaultVal) .. "  [v]",
					BorderSizePixel = 0,
					ZIndex = 17,
					Parent = holder
				})
				ApplyLinoriaBorder(dropBtn, false)

				local listFrame = Create("Frame", {
					Size = UDim2.new(1, 0, 0, math.min(#values, 5) * 20 + 4),
					Position = UDim2.new(0, 0, 0, 39),
					BackgroundColor3 = Library.Theme.MainColor,
					BorderSizePixel = 0,
					Visible = false,
					ZIndex = 50,
					Parent = holder
				})
				ApplyLinoriaBorder(listFrame, true)

				local scrollList = Create("ScrollingFrame", {
					Size = UDim2.new(1, -4, 1, -4),
					Position = UDim2.new(0, 2, 0, 2),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 2,
					CanvasSize = UDim2.new(0, 0, 0, #values * 20),
					ZIndex = 51,
					Parent = listFrame
				})

				Create("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Parent = scrollList
				})

				local DropObj = {
					Value = defaultVal,
					Values = values,
					Type = "Dropdown"
				}

				local function rebuildList()
					for _, child in ipairs(scrollList:GetChildren()) do
						if child:IsA("TextButton") then
							child:Destroy()
						end
					end
					scrollList.CanvasSize = UDim2.new(0, 0, 0, #DropObj.Values * 20)
					listFrame.Size = UDim2.new(1, 0, 0, math.min(math.max(#DropObj.Values, 1), 5) * 20 + 4)

					for idx, item in ipairs(DropObj.Values) do
						local optBtn = Create("TextButton", {
							Size = UDim2.new(1, 0, 0, 20),
							BackgroundColor3 = (item == DropObj.Value) and Library.Theme.AccentColor or Library.Theme.SecondaryColor,
							TextColor3 = Library.Theme.FontColor,
							Font = Library.Theme.Font,
							TextSize = 11,
							TextXAlignment = Enum.TextXAlignment.Left,
							Text = "  " .. tostring(item),
							BorderSizePixel = 0,
							LayoutOrder = idx,
							ZIndex = 52,
							Parent = scrollList
						})

						AddConnection(optBtn.MouseButton1Click, function()
							DropObj:SetValue(item)
							listFrame.Visible = false
							holder.Size = UDim2.new(1, 0, 0, 38)
						end)
					end
				end

				function DropObj:SetValue(val)
					self.Value = val
					Library.Flags[flag] = val
					dropBtn.Text = "  " .. tostring(val) .. "  [v]"
					rebuildList()
					if opts.Callback then
						task.spawn(opts.Callback, val)
					end
				end

				function DropObj:Refresh(newValues, newDefault)
					self.Values = newValues or {}
					if newDefault ~= nil then
						self:SetValue(newDefault)
					else
						rebuildList()
					end
				end

				AddConnection(dropBtn.MouseButton1Click, function()
					listFrame.Visible = not listFrame.Visible
					if listFrame.Visible then
						holder.Size = UDim2.new(1, 0, 0, 38 + listFrame.Size.Y.Offset + 2)
					else
						holder.Size = UDim2.new(1, 0, 0, 38)
					end
				end)

				table.insert(Library.Options["__ThemeCallbacks"], function(theme)
					lbl.Font = theme.Font
					lbl.TextColor3 = theme.FontColor
					dropBtn.Font = theme.Font
					dropBtn.BackgroundColor3 = theme.SecondaryColor
					dropBtn.TextColor3 = theme.FontColor
					listFrame.BackgroundColor3 = theme.MainColor
					rebuildList()
				end)

				rebuildList()
				Library.Flags[flag] = defaultVal
				Library.Options[flag] = DropObj
				return DropObj
			end

			function GroupObj:AddInput(flag, opts)
				opts = opts or {}
				local text = opts.Text or flag
				local placeholder = opts.Placeholder or "Enter value..."
				local defaultVal = opts.Default or ""

				local holder = Create("Frame", {
					Size = UDim2.new(1, 0, 0, 38),
					BackgroundTransparency = 1,
					ZIndex = 16,
					Parent = itemContainer
				})

				local lbl = Create("TextLabel", {
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					TextColor3 = Library.Theme.FontColor,
					Font = Library.Theme.Font,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = text,
					ZIndex = 17,
					Parent = holder
				})

				local box = Create("TextBox", {
					Size = UDim2.new(1, 0, 0, 22),
					Position = UDim2.new(0, 0, 0, 15),
					BackgroundColor3 = Library.Theme.SecondaryColor,
					TextColor3 = Library.Theme.FontColor,
					PlaceholderColor3 = Library.Theme.MutedColor,
					PlaceholderText = placeholder,
					Font = Library.Theme.Font,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = tostring(defaultVal),
					ClearTextOnFocus = false,
					BorderSizePixel = 0,
					ZIndex = 17,
					Parent = holder
				})
				ApplyLinoriaBorder(box, false)

				local InputObj = {
					Value = tostring(defaultVal),
					Type = "Input"
				}

				function InputObj:SetValue(val)
					self.Value = tostring(val)
					Library.Flags[flag] = self.Value
					box.Text = self.Value
					if opts.Callback then
						task.spawn(opts.Callback, self.Value)
					end
				end

				AddConnection(box.FocusLost, function(enterPressed)
					InputObj:SetValue(box.Text)
				end)

				table.insert(Library.Options["__ThemeCallbacks"], function(theme)
					lbl.Font = theme.Font
					lbl.TextColor3 = theme.FontColor
					box.Font = theme.Font
					box.BackgroundColor3 = theme.SecondaryColor
					box.TextColor3 = theme.FontColor
				end)

				Library.Flags[flag] = InputObj.Value
				Library.Options[flag] = InputObj
				return InputObj
			end

			return GroupObj
		end

		return TabObj
	end

	return WindowObj
end

function Library:Unload()
	for _, conn in ipairs(self.Signals) do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(self.Signals)
	if self.ScreenGui then
		self.ScreenGui:Destroy()
		self.ScreenGui = nil
	end
end

return Library
