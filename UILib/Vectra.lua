--[[
    Vectra UI Library v1.0
    Linoria-style two-column "cheat menu" library for Roblox executors

    Usage:
        local Vectra = loadstring(readfile("UILib/Vectra.lua"))()
        local Window = Vectra:CreateWindow({ Title = "vectra.gg" })
        local Tab = Window:AddTab("Combat")
        local Box = Tab:AddLeftGroupbox("Aim")
        Box:AddToggle("AimEnabled", { Text = "Enabled", Default = false, Callback = function(v) end })

        print(Vectra.Flags.AimEnabled.Value)
        Vectra.Flags.AimEnabled:OnChanged(function(v) end)
        Vectra.Flags.AimEnabled:Set(true)

    Groupbox elements: AddLabel, AddDivider, AddButton, AddToggle, AddSlider,
                       AddInput, AddDropdown, AddKeybind, AddColorPicker
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local Vectra = {
    Flags = {},
    ToggleKey = Enum.KeyCode.RightControl,
    Unloaded = false,
}

-- // Theme ------------------------------------------------------------------
local Theme = {
    Background = Color3.fromRGB(14, 14, 18),
    Panel      = Color3.fromRGB(19, 19, 25),
    Groupbox   = Color3.fromRGB(23, 23, 30),
    Element    = Color3.fromRGB(30, 30, 39),
    Outline    = Color3.fromRGB(40, 40, 52),
    Accent     = Color3.fromRGB(140, 90, 255),
    Text       = Color3.fromRGB(225, 225, 235),
    Dim        = Color3.fromRGB(130, 130, 148),
    Font       = Enum.Font.Code,
}
Vectra.Theme = Theme

-- // Helpers ----------------------------------------------------------------
local function New(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then inst[k] = v end
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end

local function Tween(inst, props, time)
    local t = TweenService:Create(inst, TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function Outline(inst, color)
    return New("UIStroke", {
        Color = color or Theme.Outline,
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = inst,
    })
end

local function Corner(inst, r)
    return New("UICorner", { CornerRadius = UDim.new(0, r or 3), Parent = inst })
end

local function ProtectGui(gui)
    if typeof(gethui) == "function" then
        gui.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(gui)
        gui.Parent = game:GetService("CoreGui")
    else
        local ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
        if not ok then
            gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end
    end
end

local function KeyName(keyCode)
    if not keyCode then return "NONE" end
    return keyCode.Name:upper()
end

-- // Flag object ------------------------------------------------------------
local function NewFlag(idx, initialValue, onSet)
    local flag = {
        Value = initialValue,
        _listeners = {},
        _onSet = onSet, -- updates visuals; receives value
    }
    function flag:Set(v)
        self.Value = v
        if self._onSet then self._onSet(v) end
        for _, fn in ipairs(self._listeners) do
            task.spawn(fn, v)
        end
    end
    function flag:OnChanged(fn)
        table.insert(self._listeners, fn)
    end
    function flag:_fire() -- internal: value already set by UI, notify listeners
        for _, fn in ipairs(self._listeners) do
            task.spawn(fn, self.Value)
        end
    end
    if idx then Vectra.Flags[idx] = flag end
    return flag
end

-- // Root gui ---------------------------------------------------------------
local RootGui = New("ScreenGui", {
    Name = "VectraUI_" .. HttpService:GenerateGUID(false):sub(1, 8),
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    -- IgnoreGuiInset stays false so popup positioning via AbsolutePosition
    -- shares the same coordinate space as every other element
})
ProtectGui(RootGui)

-- popup layer (color pickers, etc. render above everything)
local PopupLayer = New("Frame", {
    Name = "Popups",
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0),
    Parent = RootGui,
})
local ActivePopup = nil
local function ClosePopup()
    if ActivePopup then ActivePopup.Visible = false; ActivePopup = nil end
end
local function OpenPopup(popup)
    if ActivePopup == popup then ClosePopup() return end
    ClosePopup()
    popup.Visible = true
    ActivePopup = popup
end

-- // Notifications ----------------------------------------------------------
local NotifHolder = New("Frame", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 10, 0.5, 0),
    Size = UDim2.new(0, 260, 0.8, 0),
    BackgroundTransparency = 1,
    Parent = RootGui,
}, {
    New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
    }),
})

function Vectra:Notify(text, duration)
    duration = duration or 4
    local frame = New("Frame", {
        BackgroundColor3 = Theme.Panel,
        Size = UDim2.new(0, 0, 0, 26),
        AutomaticSize = Enum.AutomaticSize.X,
        Parent = NotifHolder,
    })
    Corner(frame, 3)
    Outline(frame)
    New("Frame", {
        BackgroundColor3 = Theme.Accent,
        Size = UDim2.new(0, 2, 1, 0),
        BorderSizePixel = 0,
        Parent = frame,
    })
    New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Font = Theme.Font,
        Text = tostring(text),
        TextColor3 = Theme.Text,
        TextSize = 13,
        Parent = frame,
    })
    New("UIPadding", { PaddingRight = UDim.new(0, 12), Parent = frame })
    task.delay(duration, function()
        if frame.Parent then frame:Destroy() end
    end)
end

-- // Window -----------------------------------------------------------------
function Vectra:CreateWindow(cfg)
    cfg = cfg or {}
    local title = cfg.Title or "vectra"
    if cfg.ToggleKey then Vectra.ToggleKey = cfg.ToggleKey end
    if cfg.Accent then Theme.Accent = cfg.Accent end

    local Main = New("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = cfg.Size or UDim2.new(0, 640, 0, 440),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = RootGui,
    })
    Corner(Main, 4)
    Outline(Main, Theme.Outline)

    -- Title bar
    local TitleBar = New("Frame", {
        BackgroundColor3 = Theme.Panel,
        Size = UDim2.new(1, 0, 0, 30),
        BorderSizePixel = 0,
        Parent = Main,
    })
    Corner(TitleBar, 4)
    New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(0.5, 0, 1, 0),
        Font = Theme.Font,
        Text = title,
        TextColor3 = Theme.Accent,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TitleBar,
    })
    New("Frame", { -- accent underline
        BackgroundColor3 = Theme.Accent,
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BorderSizePixel = 0,
        Parent = TitleBar,
    })

    -- Tab bar
    local TabBar = New("Frame", {
        BackgroundColor3 = Theme.Panel,
        Position = UDim2.new(0, 0, 0, 30),
        Size = UDim2.new(1, 0, 0, 30),
        BorderSizePixel = 0,
        Parent = Main,
    }, {
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 2),
        }),
        New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 4) }),
    })

    local Content = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 60),
        Size = UDim2.new(1, 0, 1, -60),
        Parent = Main,
    })

    -- Dragging
    do
        local dragging, dragInput, dragStart, startPos
        TitleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = Main.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        TitleBar.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Vectra.ToggleKey then
            Main.Visible = not Main.Visible
            if not Main.Visible then ClosePopup() end
        end
    end)

    local Window = { Tabs = {}, Main = Main, Gui = RootGui }
    local firstTab = true

    -- // Tab ------------------------------------------------------------------
    function Window:AddTab(tabName)
        local TabButton = New("TextButton", {
            BackgroundColor3 = Theme.Element,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 0, 24),
            AutomaticSize = Enum.AutomaticSize.X,
            Font = Theme.Font,
            Text = tabName,
            TextColor3 = Theme.Dim,
            TextSize = 13,
            AutoButtonColor = false,
            Parent = TabBar,
        })
        Corner(TabButton, 3)
        New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = TabButton })

        local Page = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Visible = false,
            Parent = Content,
        })
        local LeftCol = New("ScrollingFrame", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 8, 0, 4),
            Size = UDim2.new(0.5, -12, 1, -12),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.Outline,
            BorderSizePixel = 0,
            Parent = Page,
        }, {
            New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
            New("UIPadding", { PaddingBottom = UDim.new(0, 8), PaddingRight = UDim.new(0, 4) }),
        })
        local RightCol = New("ScrollingFrame", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, 4, 0, 4),
            Size = UDim2.new(0.5, -12, 1, -12),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.Outline,
            BorderSizePixel = 0,
            Parent = Page,
        }, {
            New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
            New("UIPadding", { PaddingBottom = UDim.new(0, 8), PaddingRight = UDim.new(0, 4) }),
        })

        local Tab = { Button = TabButton, Page = Page }

        local function Select()
            for _, other in ipairs(Window.Tabs) do
                other.Page.Visible = false
                Tween(other.Button, { BackgroundTransparency = 1, TextColor3 = Theme.Dim })
            end
            Page.Visible = true
            Tween(TabButton, { BackgroundTransparency = 0, TextColor3 = Theme.Text })
            ClosePopup()
        end
        TabButton.MouseButton1Click:Connect(Select)
        table.insert(Window.Tabs, Tab)
        if firstTab then firstTab = false; Select() end

        -- // Groupbox ------------------------------------------------------------
        local function MakeGroupbox(parentCol, name)
            local box = New("Frame", {
                BackgroundColor3 = Theme.Groupbox,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BorderSizePixel = 0,
                Parent = parentCol,
            })
            Corner(box, 4)
            Outline(box)

            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, 0),
                Size = UDim2.new(1, -20, 0, 26),
                Font = Theme.Font,
                Text = name,
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = box,
            })
            New("Frame", { -- accent line under title
                BackgroundColor3 = Theme.Accent,
                Position = UDim2.new(0, 10, 0, 26),
                Size = UDim2.new(0, 18, 0, 1),
                BorderSizePixel = 0,
                Parent = box,
            })

            local holder = New("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, 32),
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = box,
            }, {
                New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) }),
                New("UIPadding", {
                    PaddingLeft = UDim.new(0, 10),
                    PaddingRight = UDim.new(0, 10),
                    PaddingBottom = UDim.new(0, 10),
                }),
            })

            local Groupbox = { Frame = box, Holder = holder }

            -- // Label
            function Groupbox:AddLabel(text, wraps)
                local lbl = New("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, wraps and 0 or 16),
                    AutomaticSize = wraps and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
                    Font = Theme.Font,
                    Text = text,
                    TextColor3 = Theme.Dim,
                    TextSize = 12,
                    TextWrapped = wraps or false,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = holder,
                })
                local obj = { Label = lbl }
                function obj:Set(t) lbl.Text = t end
                function obj:AddColorPicker(idx, pcfg) return Groupbox:AddColorPicker(idx, pcfg, lbl) end
                function obj:AddKeybind(idx, pcfg) return Groupbox:AddKeybind(idx, pcfg, lbl) end
                return obj
            end

            -- // Divider
            function Groupbox:AddDivider()
                New("Frame", {
                    BackgroundColor3 = Theme.Outline,
                    Size = UDim2.new(1, 0, 0, 1),
                    BorderSizePixel = 0,
                    Parent = holder,
                })
            end

            -- // Button
            function Groupbox:AddButton(a, b)
                -- supports AddButton("Text", fn) and AddButton({Text=, Func=})
                local text, fn
                if typeof(a) == "table" then text, fn = a.Text, a.Func else text, fn = a, b end
                local btn = New("TextButton", {
                    BackgroundColor3 = Theme.Element,
                    Size = UDim2.new(1, 0, 0, 24),
                    Font = Theme.Font,
                    Text = text or "button",
                    TextColor3 = Theme.Text,
                    TextSize = 12,
                    AutoButtonColor = false,
                    Parent = holder,
                })
                Corner(btn, 3)
                Outline(btn)
                btn.MouseEnter:Connect(function() Tween(btn, { BackgroundColor3 = Theme.Outline }) end)
                btn.MouseLeave:Connect(function() Tween(btn, { BackgroundColor3 = Theme.Element }) end)
                btn.MouseButton1Click:Connect(function()
                    if fn then task.spawn(fn) end
                end)
                return { Button = btn }
            end

            -- // Toggle (checkbox style)
            function Groupbox:AddToggle(idx, tcfg)
                tcfg = tcfg or {}
                local row = New("TextButton", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 18),
                    Text = "",
                    Parent = holder,
                })
                local checkbox = New("Frame", {
                    Position = UDim2.new(0, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    Size = UDim2.new(0, 14, 0, 14),
                    BackgroundColor3 = Theme.Element,
                    BorderSizePixel = 0,
                    Parent = row,
                })
                Corner(checkbox, 2)
                Outline(checkbox)
                New("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 22, 0, 0),
                    Size = UDim2.new(1, -22, 1, 0),
                    Font = Theme.Font,
                    Text = tcfg.Text or idx,
                    TextColor3 = Theme.Text,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = row,
                })

                local flag
                flag = NewFlag(idx, tcfg.Default or false, function(v)
                    Tween(checkbox, { BackgroundColor3 = v and Theme.Accent or Theme.Element }, 0.1)
                end)
                if tcfg.Callback then flag:OnChanged(tcfg.Callback) end

                row.MouseButton1Click:Connect(function()
                    flag:Set(not flag.Value)
                end)

                flag._onSet(flag.Value)
                if flag.Value and tcfg.Callback then task.spawn(tcfg.Callback, true) end

                local obj = flag
                function obj:AddColorPicker(pIdx, pcfg) return Groupbox:AddColorPicker(pIdx, pcfg, row) end
                function obj:AddKeybind(pIdx, pcfg) return Groupbox:AddKeybind(pIdx, pcfg, row) end
                return flag
            end

            -- // Slider
            function Groupbox:AddSlider(idx, scfg)
                scfg = scfg or {}
                local min = scfg.Min or 0
                local max = scfg.Max or 100
                local rounding = scfg.Rounding or 0
                local suffix = scfg.Suffix or ""
                local default = math.clamp(scfg.Default or min, min, max)

                local row = New("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, scfg.Compact and 14 or 30),
                    Parent = holder,
                })
                if not scfg.Compact then
                    New("TextLabel", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 14),
                        Font = Theme.Font,
                        Text = scfg.Text or idx,
                        TextColor3 = Theme.Text,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = row,
                    })
                end
                local bar = New("Frame", {
                    Position = UDim2.new(0, 0, 1, -12),
                    Size = UDim2.new(1, 0, 0, 12),
                    BackgroundColor3 = Theme.Element,
                    BorderSizePixel = 0,
                    Parent = row,
                })
                Corner(bar, 2)
                Outline(bar)
                local fill = New("Frame", {
                    Size = UDim2.new(0, 0, 1, 0),
                    BackgroundColor3 = Theme.Accent,
                    BorderSizePixel = 0,
                    Parent = bar,
                })
                Corner(fill, 2)
                local valLabel = New("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Font = Theme.Font,
                    Text = "",
                    TextColor3 = Theme.Text,
                    TextSize = 11,
                    ZIndex = 2,
                    Parent = bar,
                })

                local flag
                flag = NewFlag(idx, default, function(v)
                    local alpha = (max == min) and 0 or (v - min) / (max - min)
                    fill.Size = UDim2.new(alpha, 0, 1, 0)
                    valLabel.Text = string.format("%." .. rounding .. "f", v) .. (suffix ~= "" and (" " .. suffix) or "") .. (scfg.HideMax and "" or ("/" .. string.format("%." .. rounding .. "f", max)))
                end)
                if scfg.Callback then flag:OnChanged(scfg.Callback) end

                local dragging = false
                local mult = 10 ^ rounding
                local function updateFromInput(input)
                    local alpha = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                    local raw = min + (max - min) * alpha
                    flag:Set(math.clamp(math.floor(raw * mult + 0.5) / mult, min, max))
                end
                bar.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        updateFromInput(input)
                    end
                end)
                UserInputService.InputChanged:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        updateFromInput(input)
                    end
                end)
                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                    end
                end)

                flag._onSet(flag.Value)
                return flag
            end

            -- // Input
            function Groupbox:AddInput(idx, icfg)
                icfg = icfg or {}
                local row = New("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, icfg.Text and 40 or 24),
                    Parent = holder,
                })
                if icfg.Text then
                    New("TextLabel", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 14),
                        Font = Theme.Font,
                        Text = icfg.Text,
                        TextColor3 = Theme.Text,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = row,
                    })
                end
                local boxHolder = New("Frame", {
                    Position = UDim2.new(0, 0, 1, -22),
                    Size = UDim2.new(1, 0, 0, 22),
                    BackgroundColor3 = Theme.Element,
                    BorderSizePixel = 0,
                    Parent = row,
                })
                Corner(boxHolder, 3)
                Outline(boxHolder)
                local box = New("TextBox", {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 8, 0, 0),
                    Size = UDim2.new(1, -16, 1, 0),
                    Font = Theme.Font,
                    Text = icfg.Default or "",
                    PlaceholderText = icfg.Placeholder or "",
                    PlaceholderColor3 = Theme.Dim,
                    TextColor3 = Theme.Text,
                    TextSize = 12,
                    ClearTextOnFocus = false,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = boxHolder,
                })

                local flag
                flag = NewFlag(idx, icfg.Default or "", function(v)
                    if box.Text ~= tostring(v) then box.Text = tostring(v) end
                end)
                if icfg.Callback then flag:OnChanged(icfg.Callback) end

                box.FocusLost:Connect(function(enterPressed)
                    if icfg.Finished and not enterPressed then return end
                    local text = box.Text
                    if icfg.Numeric then
                        local n = tonumber(text)
                        if not n then box.Text = tostring(flag.Value) return end
                        text = n
                    end
                    flag.Value = text
                    flag:_fire()
                end)
                return flag
            end

            -- // Dropdown
            function Groupbox:AddDropdown(idx, dcfg)
                dcfg = dcfg or {}
                local values = dcfg.Values or {}
                local default = dcfg.Default
                if typeof(default) == "number" then default = values[default] end

                local row = New("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, dcfg.Text and 40 or 24),
                    Parent = holder,
                })
                if dcfg.Text then
                    New("TextLabel", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 14),
                        Font = Theme.Font,
                        Text = dcfg.Text,
                        TextColor3 = Theme.Text,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = row,
                    })
                end
                local btn = New("TextButton", {
                    Position = UDim2.new(0, 0, 1, -22),
                    Size = UDim2.new(1, 0, 0, 22),
                    BackgroundColor3 = Theme.Element,
                    Font = Theme.Font,
                    Text = "",
                    AutoButtonColor = false,
                    Parent = row,
                })
                Corner(btn, 3)
                Outline(btn)
                local selLabel = New("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 8, 0, 0),
                    Size = UDim2.new(1, -30, 1, 0),
                    Font = Theme.Font,
                    Text = "",
                    TextColor3 = Theme.Text,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Parent = btn,
                })
                New("TextLabel", {
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, -8, 0, 0),
                    Size = UDim2.new(0, 12, 1, 0),
                    Font = Theme.Font,
                    Text = "v",
                    TextColor3 = Theme.Dim,
                    TextSize = 11,
                    Parent = btn,
                })

                -- popup option list (parented to popup layer to escape clipping)
                local popup = New("Frame", {
                    BackgroundColor3 = Theme.Panel,
                    Size = UDim2.new(0, 200, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Visible = false,
                    ZIndex = 50,
                    Parent = PopupLayer,
                })
                Corner(popup, 3)
                Outline(popup, Theme.Accent)
                local popupList = New("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    ZIndex = 50,
                    Parent = popup,
                }, {
                    New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) }),
                    New("UIPadding", {
                        PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3),
                        PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3),
                    }),
                })

                local multi = dcfg.Multi or false
                local initial
                if multi then
                    initial = {}
                    if typeof(dcfg.Default) == "table" then initial = dcfg.Default end
                else
                    initial = default
                end

                local flag
                local optionButtons = {}

                local function renderSelection()
                    if multi then
                        local names = {}
                        for _, v in ipairs(values) do
                            if flag.Value[v] then table.insert(names, tostring(v)) end
                        end
                        selLabel.Text = #names > 0 and table.concat(names, ", ") or "none"
                    else
                        selLabel.Text = flag.Value ~= nil and tostring(flag.Value) or "none"
                    end
                    for v, b in pairs(optionButtons) do
                        local active = multi and flag.Value[v] or (flag.Value == v)
                        b.TextColor3 = active and Theme.Accent or Theme.Dim
                    end
                end

                flag = NewFlag(idx, initial, function() renderSelection() end)
                if dcfg.Callback then flag:OnChanged(dcfg.Callback) end

                local function buildOptions()
                    for _, b in pairs(optionButtons) do b:Destroy() end
                    optionButtons = {}
                    for _, v in ipairs(values) do
                        local optBtn = New("TextButton", {
                            BackgroundColor3 = Theme.Element,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, 20),
                            Font = Theme.Font,
                            Text = "  " .. tostring(v),
                            TextColor3 = Theme.Dim,
                            TextSize = 12,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            AutoButtonColor = false,
                            ZIndex = 51,
                            Parent = popupList,
                        })
                        Corner(optBtn, 2)
                        optBtn.MouseEnter:Connect(function() optBtn.BackgroundTransparency = 0 end)
                        optBtn.MouseLeave:Connect(function() optBtn.BackgroundTransparency = 1 end)
                        optBtn.MouseButton1Click:Connect(function()
                            if multi then
                                local t = flag.Value
                                t[v] = not t[v] or nil
                                flag:Set(t)
                            else
                                flag:Set(v)
                                ClosePopup()
                            end
                        end)
                        optionButtons[v] = optBtn
                    end
                end

                function flag:Refresh(newValues, keepSelection)
                    values = newValues or {}
                    if not keepSelection then
                        flag.Value = multi and {} or nil
                    end
                    buildOptions()
                    renderSelection()
                end

                btn.MouseButton1Click:Connect(function()
                    popup.Position = UDim2.new(0, btn.AbsolutePosition.X, 0, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 2)
                    popup.Size = UDim2.new(0, btn.AbsoluteSize.X, 0, 0)
                    OpenPopup(popup)
                end)

                buildOptions()
                renderSelection()
                return flag
            end

            -- // Keybind
            function Groupbox:AddKeybind(idx, kcfg, attachTo)
                kcfg = kcfg or {}
                local host = attachTo
                if not host then
                    host = New("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 18),
                        Parent = holder,
                    })
                    New("TextLabel", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, -60, 1, 0),
                        Font = Theme.Font,
                        Text = kcfg.Text or idx,
                        TextColor3 = Theme.Text,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = host,
                    })
                end

                local default = kcfg.Default
                if typeof(default) == "string" then
                    default = Enum.KeyCode[default]
                end

                local keyBtn = New("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.new(0, 54, 0, 16),
                    BackgroundColor3 = Theme.Element,
                    Font = Theme.Font,
                    Text = "[" .. KeyName(default) .. "]",
                    TextColor3 = Theme.Dim,
                    TextSize = 11,
                    AutoButtonColor = false,
                    ZIndex = 5,
                    Parent = host,
                })
                Corner(keyBtn, 2)
                Outline(keyBtn)

                local listening = false
                local flag
                flag = NewFlag(idx, default, function(v)
                    keyBtn.Text = "[" .. KeyName(v) .. "]"
                end)
                if kcfg.ChangedCallback then flag:OnChanged(kcfg.ChangedCallback) end

                keyBtn.MouseButton1Click:Connect(function()
                    listening = true
                    keyBtn.Text = "[...]"
                    keyBtn.TextColor3 = Theme.Accent
                end)

                UserInputService.InputBegan:Connect(function(input, gameProcessed)
                    if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                        listening = false
                        keyBtn.TextColor3 = Theme.Dim
                        if input.KeyCode == Enum.KeyCode.Escape then
                            flag:Set(nil)
                        else
                            flag:Set(input.KeyCode)
                        end
                        return
                    end
                    if not gameProcessed and flag.Value and input.KeyCode == flag.Value then
                        if kcfg.Callback then task.spawn(kcfg.Callback, flag.Value) end
                    end
                end)

                function flag:GetState()
                    return flag.Value and UserInputService:IsKeyDown(flag.Value) or false
                end
                return flag
            end

            -- // ColorPicker
            function Groupbox:AddColorPicker(idx, ccfg, attachTo)
                ccfg = ccfg or {}
                local default = ccfg.Default or Color3.fromRGB(255, 255, 255)
                local h, s, v = default:ToHSV()

                local host = attachTo
                if not host then
                    host = New("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 18),
                        Parent = holder,
                    })
                    New("TextLabel", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, -40, 1, 0),
                        Font = Theme.Font,
                        Text = ccfg.Text or idx,
                        TextColor3 = Theme.Text,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = host,
                    })
                end

                local swatch = New("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, attachTo and -60 or 0, 0.5, 0),
                    Size = UDim2.new(0, 26, 0, 14),
                    BackgroundColor3 = default,
                    Text = "",
                    AutoButtonColor = false,
                    ZIndex = 5,
                    Parent = host,
                })
                Corner(swatch, 2)
                Outline(swatch)

                -- popup picker
                local popup = New("Frame", {
                    BackgroundColor3 = Theme.Panel,
                    Size = UDim2.new(0, 190, 0, 170),
                    Visible = false,
                    ZIndex = 60,
                    Parent = PopupLayer,
                })
                Corner(popup, 3)
                Outline(popup, Theme.Accent)

                -- SV square
                local svSquare = New("TextButton", {
                    Position = UDim2.new(0, 8, 0, 8),
                    Size = UDim2.new(0, 140, 0, 130),
                    BackgroundColor3 = Color3.fromHSV(h, 1, 1),
                    Text = "",
                    AutoButtonColor = false,
                    BorderSizePixel = 0,
                    ZIndex = 61,
                    Parent = popup,
                })
                local satOverlay = New("Frame", { -- white -> transparent (left to right)
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderSizePixel = 0,
                    ZIndex = 62,
                    Parent = svSquare,
                }, {
                    New("UIGradient", {
                        Transparency = NumberSequence.new({
                            NumberSequenceKeypoint.new(0, 0),
                            NumberSequenceKeypoint.new(1, 1),
                        }),
                    }),
                })
                local valOverlay = New("Frame", { -- transparent -> black (top to bottom)
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundColor3 = Color3.new(0, 0, 0),
                    BorderSizePixel = 0,
                    ZIndex = 63,
                    Parent = svSquare,
                }, {
                    New("UIGradient", {
                        Rotation = 90,
                        Transparency = NumberSequence.new({
                            NumberSequenceKeypoint.new(0, 1),
                            NumberSequenceKeypoint.new(1, 0),
                        }),
                    }),
                })
                local svCursor = New("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Size = UDim2.new(0, 6, 0, 6),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderSizePixel = 0,
                    ZIndex = 64,
                    Parent = svSquare,
                })
                Corner(svCursor, 3)
                Outline(svCursor, Color3.new(0, 0, 0))

                -- Hue bar
                local hueBar = New("TextButton", {
                    Position = UDim2.new(0, 156, 0, 8),
                    Size = UDim2.new(0, 16, 0, 130),
                    Text = "",
                    AutoButtonColor = false,
                    BorderSizePixel = 0,
                    ZIndex = 61,
                    Parent = popup,
                })
                local hueKeypoints = {}
                for i = 0, 6 do
                    table.insert(hueKeypoints, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
                end
                New("UIGradient", {
                    Rotation = 90,
                    Color = ColorSequence.new(hueKeypoints),
                    Parent = hueBar,
                })
                local hueCursor = New("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0.5, 0, 0, 0),
                    Size = UDim2.new(1, 2, 0, 3),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderSizePixel = 0,
                    ZIndex = 64,
                    Parent = hueBar,
                })

                -- hex readout
                local hexLabel = New("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 8, 1, -24),
                    Size = UDim2.new(0, 140, 0, 18),
                    Font = Theme.Font,
                    Text = "",
                    TextColor3 = Theme.Dim,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 61,
                    Parent = popup,
                })
                popup.Size = UDim2.new(0, 190, 0, 174)

                local flag
                local function currentColor() return Color3.fromHSV(h, s, v) end
                local function render()
                    local c = currentColor()
                    swatch.BackgroundColor3 = c
                    svSquare.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                    svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
                    hueCursor.Position = UDim2.new(0.5, 0, h, 0)
                    local r, g, b = math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
                    hexLabel.Text = string.format("#%02X%02X%02X  rgb(%d,%d,%d)", r, g, b, r, g, b)
                end

                flag = NewFlag(idx, default, function(c)
                    if typeof(c) == "Color3" then
                        h, s, v = c:ToHSV()
                        render()
                    end
                end)
                if ccfg.Callback then flag:OnChanged(ccfg.Callback) end

                local function push()
                    flag.Value = currentColor()
                    render()
                    flag:_fire()
                end

                local svDragging, hueDragging = false, false
                local function updateSV(input)
                    local rel = (Vector2.new(input.Position.X, input.Position.Y) - svSquare.AbsolutePosition)
                    s = math.clamp(rel.X / svSquare.AbsoluteSize.X, 0, 1)
                    v = 1 - math.clamp(rel.Y / svSquare.AbsoluteSize.Y, 0, 1)
                    push()
                end
                local function updateHue(input)
                    h = math.clamp((input.Position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)
                    push()
                end
                svSquare.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        svDragging = true
                        updateSV(input)
                    end
                end)
                hueBar.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        hueDragging = true
                        updateHue(input)
                    end
                end)
                UserInputService.InputChanged:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                        if svDragging then updateSV(input) end
                        if hueDragging then updateHue(input) end
                    end
                end)
                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        svDragging, hueDragging = false, false
                    end
                end)

                swatch.MouseButton1Click:Connect(function()
                    popup.Position = UDim2.new(0, swatch.AbsolutePosition.X - 190 + swatch.AbsoluteSize.X, 0, swatch.AbsolutePosition.Y + swatch.AbsoluteSize.Y + 4)
                    OpenPopup(popup)
                end)

                render()
                return flag
            end

            return Groupbox
        end

        function Tab:AddLeftGroupbox(name) return MakeGroupbox(LeftCol, name) end
        function Tab:AddRightGroupbox(name) return MakeGroupbox(RightCol, name) end

        return Tab
    end

    function Window:Destroy()
        Vectra.Unloaded = true
        RootGui:Destroy()
    end

    return Window
end

-- // Config saving ----------------------------------------------------------
local function CanUseFiles()
    return typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"
end

Vectra.ConfigFolder = "VectraUI"

function Vectra:SaveConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local data = {}
    for idx, flag in pairs(Vectra.Flags) do
        local val = flag.Value
        if typeof(val) == "EnumItem" then
            data[idx] = { __keycode = val.Name }
        elseif typeof(val) == "Color3" then
            data[idx] = { __color = { val.R, val.G, val.B } }
        elseif typeof(val) == "table" or typeof(val) == "boolean" or typeof(val) == "number" or typeof(val) == "string" then
            data[idx] = val
        end
    end
    if typeof(isfolder) == "function" and not isfolder(Vectra.ConfigFolder) then
        makefolder(Vectra.ConfigFolder)
    end
    writefile(Vectra.ConfigFolder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    return true
end

function Vectra:LoadConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local path = Vectra.ConfigFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false, "no config file" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok then return false, "corrupt config" end
    for idx, val in pairs(data) do
        local flag = Vectra.Flags[idx]
        if flag then
            if typeof(val) == "table" and val.__keycode then
                flag:Set(Enum.KeyCode[val.__keycode])
            elseif typeof(val) == "table" and val.__color then
                flag:Set(Color3.new(val.__color[1], val.__color[2], val.__color[3]))
            else
                flag:Set(val)
            end
        end
    end
    return true
end

function Vectra:Unload()
    Vectra.Unloaded = true
    RootGui:Destroy()
end

return Vectra
