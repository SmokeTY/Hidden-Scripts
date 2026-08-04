--[[
    Pulse UI Library v1.0
    Cyberpunk neon UI library for Roblox executors

    Usage:
        local Pulse = loadstring(readfile("UI/Pulse/Pulse.lua"))()
        local Window = Pulse:CreateWindow({ Name = "Pulse Hub", ToggleKey = Enum.KeyCode.RightShift })
        local Tab = Window:CreateTab("Main")
        Tab:CreateToggle({ Name = "Auto Farm", Flag = "AutoFarm", Callback = function(v) end })

    Elements: Section, Label, Button, Toggle, Slider, Dropdown, Input, Keybind
    Extras:   Pulse:Notify, Pulse.Flags, Pulse:SaveConfig / LoadConfig, Pulse:Destroy
    Signature: animated accent underline that slides beneath the active tab
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local Pulse = {
    Flags = {},
    Windows = {},
    ToggleKey = Enum.KeyCode.RightShift,
    ConfigFolder = "PulseUI",
}

-- // Theme ------------------------------------------------------------------
local Theme = {
    Background = Color3.fromRGB(10, 10, 15),
    Panel      = Color3.fromRGB(18, 18, 26),
    Element    = Color3.fromRGB(26, 26, 38),
    Accent     = Color3.fromRGB(0, 229, 255),   -- neon cyan
    Accent2    = Color3.fromRGB(255, 45, 120),  -- neon magenta
    Text       = Color3.fromRGB(230, 240, 245),
    Dim        = Color3.fromRGB(120, 130, 150),
    Stroke     = Color3.fromRGB(42, 46, 62),
    Font       = Enum.Font.Gotham,
    FontBold   = Enum.Font.GothamBold,
    FontMono   = Enum.Font.Code,
}
Pulse.Theme = Theme

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

local function Tween(inst, props, time, style)
    local t = TweenService:Create(
        inst,
        TweenInfo.new(time or 0.18, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        props
    )
    t:Play()
    return t
end

local function Corner(inst, r)
    return New("UICorner", { CornerRadius = UDim.new(0, r or 2), Parent = inst })
end

local function Stroke(inst, color, transparency)
    return New("UIStroke", {
        Color = color or Theme.Stroke,
        Thickness = 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = inst,
    })
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

local function MakeDraggable(handle, target)
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function KeyName(keyCode)
    if not keyCode then return "NONE" end
    return keyCode.Name:upper()
end

local function SafeCall(fn, ...)
    if typeof(fn) == "function" then
        task.spawn(fn, ...)
    end
end

-- glow pulse: flash a UIStroke to the accent then relax
local function GlowPulse(stroke, color)
    stroke.Color = color or Theme.Accent
    stroke.Transparency = 0
    Tween(stroke, { Transparency = 0.55 }, 0.45)
end

-- // Root gui ---------------------------------------------------------------
local RootGui = New("ScreenGui", {
    Name = "PulseUI_" .. HttpService:GenerateGUID(false):sub(1, 8),
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    -- IgnoreGuiInset intentionally left false (AbsolutePosition math stays consistent)
})
ProtectGui(RootGui)

-- // Notifications (flicker in, top-right) -----------------------------------
local NotifHolder = New("Frame", {
    Name = "Notifications",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -14, 0, 14),
    Size = UDim2.new(0, 280, 1, -28),
    BackgroundTransparency = 1,
    Parent = RootGui,
}, {
    New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 8),
    }),
})

function Pulse:Notify(cfg)
    cfg = cfg or {}
    local duration = cfg.Duration or 4

    local frame = New("Frame", {
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Parent = NotifHolder,
    })
    Corner(frame, 3)
    local stroke = Stroke(frame, Theme.Accent, 1)

    local bar = New("Frame", {
        BackgroundColor3 = Theme.Accent2,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(0, 2, 1, 0),
        BorderSizePixel = 0,
        Parent = frame,
    })

    local title = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 8),
        Size = UDim2.new(1, -22, 0, 16),
        Font = Theme.FontBold,
        Text = cfg.Title or "PULSE",
        TextColor3 = Theme.Accent,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        Parent = frame,
    })
    local body = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 26),
        Size = UDim2.new(1, -22, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Theme.Font,
        Text = cfg.Content or "",
        TextColor3 = Theme.Text,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextTransparency = 1,
        Parent = frame,
    })
    New("UIPadding", { PaddingBottom = UDim.new(0, 10), Parent = frame })

    -- neon flicker-in: rapid transparency stutter, then settle
    task.spawn(function()
        local flicker = { 0.35, 0.9, 0.15, 0.75 }
        for _, alpha in ipairs(flicker) do
            frame.BackgroundTransparency = alpha
            stroke.Transparency = alpha
            bar.BackgroundTransparency = alpha
            title.TextTransparency = alpha
            body.TextTransparency = alpha
            task.wait(0.04)
        end
        Tween(frame, { BackgroundTransparency = 0.05 }, 0.12)
        Tween(stroke, { Transparency = 0.25 }, 0.12)
        Tween(bar, { BackgroundTransparency = 0 }, 0.12)
        Tween(title, { TextTransparency = 0 }, 0.12)
        Tween(body, { TextTransparency = 0.05 }, 0.12)
    end)

    task.delay(duration, function()
        if not frame.Parent then return end
        Tween(frame, { BackgroundTransparency = 1 }, 0.25)
        Tween(stroke, { Transparency = 1 }, 0.25)
        Tween(bar, { BackgroundTransparency = 1 }, 0.25)
        Tween(title, { TextTransparency = 1 }, 0.25)
        Tween(body, { TextTransparency = 1 }, 0.25)
        task.wait(0.28)
        frame:Destroy()
    end)
end

-- // Config saving ------------------------------------------------------------
local function CanUseFiles()
    return typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"
end

function Pulse:SaveConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local data = {}
    for flag, obj in pairs(Pulse.Flags) do
        local v = obj:Get()
        if typeof(v) == "EnumItem" then
            data[flag] = { __keycode = v.Name }
        elseif typeof(v) == "Color3" then
            data[flag] = { __color = { v.R, v.G, v.B } }
        elseif v ~= nil then
            data[flag] = v
        end
    end
    if typeof(isfolder) == "function" and typeof(makefolder) == "function" and not isfolder(Pulse.ConfigFolder) then
        makefolder(Pulse.ConfigFolder)
    end
    writefile(Pulse.ConfigFolder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    return true
end

function Pulse:LoadConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local path = Pulse.ConfigFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false, "no config file" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok then return false, "corrupt config" end
    for flag, v in pairs(data) do
        local obj = Pulse.Flags[flag]
        if obj then
            if typeof(v) == "table" and v.__keycode then
                local okKey, key = pcall(function() return Enum.KeyCode[v.__keycode] end)
                if okKey then obj:Set(key) end
            elseif typeof(v) == "table" and v.__color then
                obj:Set(Color3.new(v.__color[1], v.__color[2], v.__color[3]))
            else
                obj:Set(v)
            end
        end
    end
    return true
end

-- // Window -------------------------------------------------------------------
function Pulse:CreateWindow(cfg)
    cfg = cfg or {}
    local windowName = cfg.Name or "PULSE"
    if cfg.ToggleKey then Pulse.ToggleKey = cfg.ToggleKey end

    local Main = New("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = cfg.Size or UDim2.new(0, 600, 0, 400),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = RootGui,
    })
    Corner(Main, 3)
    Stroke(Main, Theme.Stroke)

    -- // Title bar
    local TitleBar = New("Frame", {
        BackgroundColor3 = Theme.Panel,
        Size = UDim2.new(1, 0, 0, 34),
        BorderSizePixel = 0,
        Parent = Main,
    })
    Corner(TitleBar, 3)

    New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(0.6, 0, 1, 0),
        Font = Theme.FontBold,
        Text = windowName,
        TextColor3 = Theme.Accent,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TitleBar,
    })

    -- cyan -> magenta hairline across the bottom of the title bar
    New("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BorderSizePixel = 0,
        Parent = TitleBar,
    }, {
        New("UIGradient", {
            Color = ColorSequence.new(Theme.Accent, Theme.Accent2),
        }),
    })

    local CloseBtn = New("TextButton", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0, 24, 0, 24),
        Font = Theme.FontBold,
        Text = "×",
        TextColor3 = Theme.Dim,
        TextSize = 18,
        AutoButtonColor = false,
        Parent = TitleBar,
    })
    local HideBtn = New("TextButton", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -34, 0.5, 0),
        Size = UDim2.new(0, 24, 0, 24),
        Font = Theme.FontBold,
        Text = "—",
        TextColor3 = Theme.Dim,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = TitleBar,
    })
    CloseBtn.MouseEnter:Connect(function() Tween(CloseBtn, { TextColor3 = Theme.Accent2 }) end)
    CloseBtn.MouseLeave:Connect(function() Tween(CloseBtn, { TextColor3 = Theme.Dim }) end)
    HideBtn.MouseEnter:Connect(function() Tween(HideBtn, { TextColor3 = Theme.Accent }) end)
    HideBtn.MouseLeave:Connect(function() Tween(HideBtn, { TextColor3 = Theme.Dim }) end)

    MakeDraggable(TitleBar, Main)

    -- // Tab row + animated underline (signature)
    local TabBar = New("Frame", {
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 0.35,
        Position = UDim2.new(0, 0, 0, 34),
        Size = UDim2.new(1, 0, 0, 32),
        BorderSizePixel = 0,
        Parent = Main,
    })

    -- buttons live in their own holder so the underline is not part of the list layout
    local TabButtons = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = TabBar,
    }, {
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 4),
        }),
        New("UIPadding", { PaddingLeft = UDim.new(0, 8) }),
    })

    local Underline = New("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        Position = UDim2.new(0, 8, 1, -2),
        Size = UDim2.new(0, 0, 0, 2),
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = TabBar,
    }, {
        New("UIGradient", {
            Color = ColorSequence.new(Theme.Accent, Theme.Accent2),
        }),
    })

    New("Frame", { -- faint divider under the tab row
        BackgroundColor3 = Theme.Stroke,
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BorderSizePixel = 0,
        Parent = TabBar,
    })

    local function SlideUnderlineTo(button)
        -- defer one step so AbsolutePosition/AbsoluteSize reflect the layout
        task.defer(function()
            if not button.Parent then return end
            local x = button.AbsolutePosition.X - TabBar.AbsolutePosition.X
            local w = button.AbsoluteSize.X
            Tween(Underline, {
                Position = UDim2.new(0, x, 1, -2),
                Size = UDim2.new(0, w, 0, 2),
            }, 0.25, Enum.EasingStyle.Quart)
        end)
    end

    -- // Content area
    local Content = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 66),
        Size = UDim2.new(1, 0, 1, -66),
        Parent = Main,
    })

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Pulse.ToggleKey then
            Main.Visible = not Main.Visible
        end
    end)

    CloseBtn.MouseButton1Click:Connect(function()
        RootGui:Destroy()
    end)
    HideBtn.MouseButton1Click:Connect(function()
        Main.Visible = false
    end)

    local Window = { Tabs = {}, Main = Main, Gui = RootGui }
    local firstTab = true

    -- // Tab -------------------------------------------------------------------
    function Window:CreateTab(tabName)
        local TabButton = New("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Font = Theme.FontBold,
            Text = tabName,
            TextColor3 = Theme.Dim,
            TextSize = 13,
            AutoButtonColor = false,
            Parent = TabButtons,
        })
        New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = TabButton })

        local Page = New("ScrollingFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Accent,
            ScrollBarImageTransparency = 0.6,
            BorderSizePixel = 0,
            Visible = false,
            Parent = Content,
        }, {
            New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 14),
                PaddingRight = UDim.new(0, 14),
                PaddingTop = UDim.new(0, 10),
                PaddingBottom = UDim.new(0, 14),
            }),
        })

        local Tab = { Button = TabButton, Page = Page, Name = tabName }

        local function Select()
            for _, other in ipairs(Window.Tabs) do
                other.Page.Visible = false
                Tween(other.Button, { TextColor3 = Theme.Dim })
            end
            Page.Visible = true
            Tween(TabButton, { TextColor3 = Theme.Accent })
            SlideUnderlineTo(TabButton)
        end
        TabButton.MouseButton1Click:Connect(Select)
        TabButton.MouseEnter:Connect(function()
            if not Page.Visible then Tween(TabButton, { TextColor3 = Theme.Text }) end
        end)
        TabButton.MouseLeave:Connect(function()
            if not Page.Visible then Tween(TabButton, { TextColor3 = Theme.Dim }) end
        end)
        table.insert(Window.Tabs, Tab)
        if firstTab then firstTab = false; Select() end

        -- shared element base: dark card + stroke that glows on hover
        local function ElementBase(height, noGlow)
            local frame = New("Frame", {
                BackgroundColor3 = Theme.Element,
                Size = UDim2.new(1, 0, 0, height),
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Parent = Page,
            })
            Corner(frame, 2)
            local stroke = Stroke(frame, Theme.Stroke)
            if not noGlow then
                frame.MouseEnter:Connect(function()
                    Tween(stroke, { Color = Theme.Accent, Transparency = 0.35 }, 0.12)
                end)
                frame.MouseLeave:Connect(function()
                    Tween(stroke, { Color = Theme.Stroke, Transparency = 0 }, 0.25)
                end)
            end
            return frame, stroke
        end

        -- // Section
        function Tab:CreateSection(text)
            local holder = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 24),
                Parent = Page,
            })
            New("Frame", {
                BackgroundColor3 = Theme.Accent2,
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 0, 0.5, 1),
                Size = UDim2.new(0, 3, 0, 12),
                BorderSizePixel = 0,
                Parent = holder,
            })
            local lbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, 0),
                Size = UDim2.new(1, -10, 1, 0),
                Font = Theme.FontBold,
                Text = string.upper(text or "SECTION"),
                TextColor3 = Theme.Dim,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = holder,
            })
            local obj = {}
            function obj:Set(t) lbl.Text = string.upper(tostring(t)) end
            return obj
        end

        -- // Label
        function Tab:CreateLabel(text)
            local frame = ElementBase(28, true)
            local lbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, 0),
                Size = UDim2.new(1, -20, 1, 0),
                Font = Theme.Font,
                Text = tostring(text),
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local obj = { Frame = frame }
            function obj:Set(t) lbl.Text = tostring(t) end
            return obj
        end

        -- // Button
        function Tab:CreateButton(cfg2)
            cfg2 = cfg2 or {}
            local frame, stroke = ElementBase(32)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, 0),
                Size = UDim2.new(1, -40, 1, 0),
                Font = Theme.Font,
                Text = cfg2.Name or "Button",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -12, 0.5, 0),
                Size = UDim2.new(0, 16, 0, 16),
                Font = Theme.FontMono,
                Text = ">",
                TextColor3 = Theme.Accent,
                TextSize = 13,
                Parent = frame,
            })
            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                Parent = frame,
            })
            click.MouseButton1Click:Connect(function()
                GlowPulse(stroke, Theme.Accent)
                Tween(frame, { BackgroundColor3 = Color3.fromRGB(0, 60, 70) }, 0.06)
                task.delay(0.08, function()
                    Tween(frame, { BackgroundColor3 = Theme.Element }, 0.25)
                end)
                SafeCall(cfg2.Callback)
            end)
            return { Frame = frame }
        end

        -- // Toggle (neon switch, lights cyan when on)
        function Tab:CreateToggle(cfg2)
            cfg2 = cfg2 or {}
            local state = cfg2.Default and true or false
            local frame, stroke = ElementBase(32)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, 0),
                Size = UDim2.new(1, -70, 1, 0),
                Font = Theme.Font,
                Text = cfg2.Name or "Toggle",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local rail = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.new(0, 36, 0, 16),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Parent = frame,
            })
            Corner(rail, 2)
            local railStroke = Stroke(rail, Theme.Stroke)
            local knob = New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 2, 0.5, 0),
                Size = UDim2.new(0, 12, 0, 12),
                BackgroundColor3 = Theme.Dim,
                BorderSizePixel = 0,
                Parent = rail,
            })
            Corner(knob, 2)

            local obj = {}
            local function render(pulse)
                if state then
                    Tween(knob, {
                        Position = UDim2.new(0, 22, 0.5, 0),
                        BackgroundColor3 = Theme.Accent,
                    }, 0.16)
                    Tween(rail, { BackgroundColor3 = Color3.fromRGB(0, 45, 55) }, 0.16)
                    Tween(railStroke, { Color = Theme.Accent, Transparency = 0.25 }, 0.16)
                    if pulse then GlowPulse(stroke, Theme.Accent) end
                else
                    Tween(knob, {
                        Position = UDim2.new(0, 2, 0.5, 0),
                        BackgroundColor3 = Theme.Dim,
                    }, 0.16)
                    Tween(rail, { BackgroundColor3 = Theme.Background }, 0.16)
                    Tween(railStroke, { Color = Theme.Stroke, Transparency = 0 }, 0.16)
                end
            end
            function obj:Set(v)
                v = v and true or false
                if v == state then render(false) return end
                state = v
                render(true)
                SafeCall(cfg2.Callback, state)
            end
            function obj:Get() return state end

            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                Parent = frame,
            })
            click.MouseButton1Click:Connect(function() obj:Set(not state) end)

            render(false)
            if state then SafeCall(cfg2.Callback, state) end
            if cfg2.Flag then Pulse.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Slider (cyan fill, magenta value text)
        function Tab:CreateSlider(cfg2)
            cfg2 = cfg2 or {}
            local min = cfg2.Min or 0
            local max = cfg2.Max or 100
            local increment = cfg2.Increment or 1
            local suffix = cfg2.Suffix or ""
            local value = math.clamp(cfg2.Default or min, min, max)

            local frame = ElementBase(46)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, 6),
                Size = UDim2.new(1, -120, 0, 15),
                Font = Theme.Font,
                Text = cfg2.Name or "Slider",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local valueLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -10, 0, 6),
                Size = UDim2.new(0, 105, 0, 15),
                Font = Theme.FontMono,
                Text = "",
                TextColor3 = Theme.Accent2,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = frame,
            })
            local bar = New("Frame", {
                Position = UDim2.new(0, 10, 0, 30),
                Size = UDim2.new(1, -20, 0, 6),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Parent = frame,
            })
            Corner(bar, 2)
            Stroke(bar, Theme.Stroke)
            local fill = New("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                Parent = bar,
            })
            Corner(fill, 2)

            local decimals = math.max(0, math.ceil(-math.log10(increment)))
            local obj = {}
            local function render()
                local alpha = (max == min) and 0 or (value - min) / (max - min)
                fill.Size = UDim2.new(alpha, 0, 1, 0)
                valueLabel.Text = string.format("%." .. decimals .. "f", value)
                    .. (suffix ~= "" and (" " .. suffix) or "")
            end
            function obj:Set(v)
                v = tonumber(v)
                if not v then return end
                v = math.clamp(math.floor(v / increment + 0.5) * increment, min, max)
                if v == value then render() return end
                value = v
                render()
                SafeCall(cfg2.Callback, value)
            end
            function obj:Get() return value end

            local dragging = false
            local function updateFromInput(input)
                local alpha = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                obj:Set(min + (max - min) * alpha)
            end
            frame.InputBegan:Connect(function(input)
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

            render()
            if cfg2.Flag then Pulse.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Dropdown (expands inline via height tween + ClipsDescendants)
        function Tab:CreateDropdown(cfg2)
            cfg2 = cfg2 or {}
            local options = cfg2.Options or {}
            local selected = cfg2.Default
            local open = false

            local frame, stroke = ElementBase(32)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, 0),
                Size = UDim2.new(0.45, -10, 0, 32),
                Font = Theme.Font,
                Text = cfg2.Name or "Dropdown",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local selectedLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -30, 0, 0),
                Size = UDim2.new(0.5, -36, 0, 32),
                Font = Theme.FontMono,
                Text = "",
                TextColor3 = Theme.Dim,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = frame,
            })
            local arrow = New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -10, 0, 0),
                Size = UDim2.new(0, 14, 0, 32),
                Font = Theme.FontMono,
                Text = "v",
                TextColor3 = Theme.Accent2,
                TextSize = 12,
                Parent = frame,
            })
            local optionHolder = New("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 34),
                Size = UDim2.new(1, -16, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = frame,
            }, {
                New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
            })

            local obj = {}
            local optionButtons = {}

            local function openHeight()
                return 34 + (#options * 24) + 8
            end

            local function setOpen(v)
                open = v
                Tween(arrow, { Rotation = open and 180 or 0 }, 0.2)
                Tween(frame, { Size = UDim2.new(1, 0, 0, open and openHeight() or 32) }, 0.22, Enum.EasingStyle.Quart)
                if open then
                    Tween(stroke, { Color = Theme.Accent, Transparency = 0.25 }, 0.15)
                else
                    Tween(stroke, { Color = Theme.Stroke, Transparency = 0 }, 0.25)
                end
            end

            local function renderSelection()
                selectedLabel.Text = selected ~= nil and tostring(selected) or "none"
                for opt, btn in pairs(optionButtons) do
                    btn.TextColor3 = (opt == selected) and Theme.Accent or Theme.Dim
                end
            end

            local function buildOptions()
                for _, btn in pairs(optionButtons) do btn:Destroy() end
                optionButtons = {}
                for _, opt in ipairs(options) do
                    local btn = New("TextButton", {
                        BackgroundColor3 = Theme.Background,
                        Size = UDim2.new(1, 0, 0, 22),
                        Font = Theme.FontMono,
                        Text = "  " .. tostring(opt),
                        TextColor3 = Theme.Dim,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        AutoButtonColor = false,
                        Parent = optionHolder,
                    })
                    Corner(btn, 2)
                    btn.MouseEnter:Connect(function()
                        if opt ~= selected then Tween(btn, { TextColor3 = Theme.Text }, 0.1) end
                    end)
                    btn.MouseLeave:Connect(function()
                        if opt ~= selected then Tween(btn, { TextColor3 = Theme.Dim }, 0.15) end
                    end)
                    btn.MouseButton1Click:Connect(function()
                        obj:Set(opt)
                        setOpen(false)
                    end)
                    optionButtons[opt] = btn
                end
            end

            function obj:Set(opt)
                if selected == opt then renderSelection() return end
                selected = opt
                renderSelection()
                SafeCall(cfg2.Callback, selected)
            end
            function obj:Get() return selected end
            function obj:Refresh(newOptions, keepSelection)
                options = newOptions or {}
                if not keepSelection then selected = nil end
                buildOptions()
                renderSelection()
                if open then
                    Tween(frame, { Size = UDim2.new(1, 0, 0, openHeight()) }, 0.15)
                end
            end

            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 32),
                Text = "",
                Parent = frame,
            })
            click.MouseButton1Click:Connect(function() setOpen(not open) end)

            buildOptions()
            renderSelection()
            if cfg2.Flag then Pulse.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Input
        function Tab:CreateInput(cfg2)
            cfg2 = cfg2 or {}
            local frame = ElementBase(32)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, 0),
                Size = UDim2.new(0.45, -10, 1, 0),
                Font = Theme.Font,
                Text = cfg2.Name or "Input",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local boxHolder = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.new(0, 160, 0, 22),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Parent = frame,
            })
            Corner(boxHolder, 2)
            local boxStroke = Stroke(boxHolder, Theme.Stroke)
            local box = New("TextBox", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 7, 0, 0),
                Size = UDim2.new(1, -14, 1, 0),
                Font = Theme.FontMono,
                Text = cfg2.Default or "",
                PlaceholderText = cfg2.Placeholder or "...",
                PlaceholderColor3 = Theme.Dim,
                TextColor3 = Theme.Text,
                TextSize = 12,
                ClearTextOnFocus = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = boxHolder,
            })
            box.Focused:Connect(function()
                Tween(boxStroke, { Color = Theme.Accent, Transparency = 0 }, 0.12)
            end)
            box.FocusLost:Connect(function(enterPressed)
                Tween(boxStroke, { Color = Theme.Stroke, Transparency = 0 }, 0.2)
                SafeCall(cfg2.Callback, box.Text, enterPressed)
            end)
            local obj = {}
            function obj:Set(t)
                box.Text = tostring(t)
                SafeCall(cfg2.Callback, box.Text, false)
            end
            function obj:Get() return box.Text end
            if cfg2.Flag then Pulse.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Keybind ([KEY] in monospace; Escape clears while listening)
        function Tab:CreateKeybind(cfg2)
            cfg2 = cfg2 or {}
            local key = cfg2.Default -- Enum.KeyCode or nil
            local listening = false

            local frame = ElementBase(32)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, 0),
                Size = UDim2.new(1, -110, 1, 0),
                Font = Theme.Font,
                Text = cfg2.Name or "Keybind",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local keyBtn = New("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.new(0, 88, 0, 22),
                BackgroundColor3 = Theme.Background,
                Font = Theme.FontMono,
                Text = "[" .. KeyName(key) .. "]",
                TextColor3 = Theme.Dim,
                TextSize = 12,
                AutoButtonColor = false,
                Parent = frame,
            })
            Corner(keyBtn, 2)
            local keyStroke = Stroke(keyBtn, Theme.Stroke)

            local obj = {}
            function obj:Set(newKey)
                key = newKey
                keyBtn.Text = "[" .. KeyName(key) .. "]"
            end
            function obj:Get() return key end

            keyBtn.MouseButton1Click:Connect(function()
                listening = true
                keyBtn.Text = "[...]"
                keyBtn.TextColor3 = Theme.Accent2
                Tween(keyStroke, { Color = Theme.Accent2, Transparency = 0 }, 0.12)
            end)

            UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    listening = false
                    keyBtn.TextColor3 = Theme.Dim
                    Tween(keyStroke, { Color = Theme.Stroke, Transparency = 0 }, 0.2)
                    if input.KeyCode == Enum.KeyCode.Escape then
                        obj:Set(nil)
                    else
                        obj:Set(input.KeyCode)
                    end
                    return
                end
                if not gameProcessed and key and input.KeyCode == key then
                    SafeCall(cfg2.Callback, key)
                end
            end)

            if cfg2.Flag then Pulse.Flags[cfg2.Flag] = obj end
            return obj
        end

        return Tab
    end

    function Window:Destroy()
        RootGui:Destroy()
    end

    table.insert(Pulse.Windows, Window)
    return Window
end

function Pulse:Destroy()
    RootGui:Destroy()
end

return Pulse
