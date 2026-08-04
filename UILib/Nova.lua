--[[
    Nova UI Library v1.0
    Modern dark UI library for Roblox executors (Rayfield-style API)

    Usage:
        local Nova = loadstring(readfile("UILib/Nova.lua"))()
        local Window = Nova:CreateWindow({ Name = "My Hub" })
        local Tab = Window:CreateTab("Main")
        Tab:CreateToggle({ Name = "Auto Farm", Flag = "AutoFarm", Callback = function(v) end })

    Elements: Section, Label, Paragraph, Button, Toggle, Slider, Dropdown, Input, Keybind
    Extras:   Nova:Notify, Nova.Flags, Nova:SaveConfig / LoadConfig, RightShift toggles UI
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local Nova = {
    Flags = {},
    Windows = {},
    ToggleKey = Enum.KeyCode.RightShift,
    ConfigFolder = "NovaUI",
}

-- // Theme ------------------------------------------------------------------
local Theme = {
    Background   = Color3.fromRGB(17, 17, 24),
    Sidebar      = Color3.fromRGB(22, 22, 31),
    Element      = Color3.fromRGB(29, 29, 41),
    ElementHover = Color3.fromRGB(37, 37, 53),
    Accent       = Color3.fromRGB(99, 102, 241),
    AccentDark   = Color3.fromRGB(67, 70, 190),
    Text         = Color3.fromRGB(235, 235, 245),
    SubText      = Color3.fromRGB(145, 145, 165),
    Stroke       = Color3.fromRGB(46, 46, 62),
}
Nova.Theme = Theme

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
    local tween = TweenService:Create(inst, TweenInfo.new(time or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    tween:Play()
    return tween
end

local function Round(inst, radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius or 6), Parent = inst })
end

local function Stroke(inst, color, thickness)
    return New("UIStroke", {
        Color = color or Theme.Stroke,
        Thickness = thickness or 1,
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
    if not keyCode then return "None" end
    return keyCode.Name
end

-- // Notifications ----------------------------------------------------------
local RootGui = New("ScreenGui", {
    Name = "NovaUI_" .. HttpService:GenerateGUID(false):sub(1, 8),
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
ProtectGui(RootGui)

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
        Padding = UDim.new(0, 8),
    }),
})

function Nova:Notify(cfg)
    cfg = cfg or {}
    local duration = cfg.Duration or 4

    local frame = New("Frame", {
        BackgroundColor3 = Theme.Sidebar,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = NotifHolder,
    })
    Round(frame, 8)
    Stroke(frame)

    New("Frame", { -- accent bar
        BackgroundColor3 = Theme.Accent,
        Size = UDim2.new(0, 3, 1, -12),
        Position = UDim2.new(0, 6, 0, 6),
        BorderSizePixel = 0,
        Parent = frame,
    })

    local title = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 18, 0, 8),
        Size = UDim2.new(1, -26, 0, 18),
        Font = Enum.Font.GothamBold,
        Text = cfg.Title or "Notification",
        TextColor3 = Theme.Text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        Parent = frame,
    })
    local body = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 18, 0, 28),
        Size = UDim2.new(1, -26, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Enum.Font.Gotham,
        Text = cfg.Content or "",
        TextColor3 = Theme.SubText,
        TextSize = 13,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextTransparency = 1,
        Parent = frame,
    })
    New("UIPadding", { PaddingBottom = UDim.new(0, 10), Parent = frame })

    Tween(frame, { BackgroundTransparency = 0.05 }, 0.25)
    Tween(title, { TextTransparency = 0 }, 0.25)
    Tween(body, { TextTransparency = 0.1 }, 0.25)

    task.delay(duration, function()
        if not frame.Parent then return end
        Tween(frame, { BackgroundTransparency = 1 }, 0.3)
        Tween(title, { TextTransparency = 1 }, 0.3)
        Tween(body, { TextTransparency = 1 }, 0.3)
        task.wait(0.32)
        frame:Destroy()
    end)
end

-- // Config saving ----------------------------------------------------------
local function CanUseFiles()
    return typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"
end

function Nova:SaveConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local data = {}
    for flag, obj in pairs(Nova.Flags) do
        local v = obj:Get()
        if typeof(v) == "EnumItem" then
            data[flag] = { __keycode = v.Name }
        elseif typeof(v) == "Color3" then
            data[flag] = { __color = { v.R, v.G, v.B } }
        else
            data[flag] = v
        end
    end
    if typeof(isfolder) == "function" and not isfolder(Nova.ConfigFolder) then
        makefolder(Nova.ConfigFolder)
    end
    writefile(Nova.ConfigFolder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    return true
end

function Nova:LoadConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local path = Nova.ConfigFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false, "no config file" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok then return false, "corrupt config" end
    for flag, v in pairs(data) do
        local obj = Nova.Flags[flag]
        if obj then
            if typeof(v) == "table" and v.__keycode then
                obj:Set(Enum.KeyCode[v.__keycode])
            elseif typeof(v) == "table" and v.__color then
                obj:Set(Color3.new(v.__color[1], v.__color[2], v.__color[3]))
            else
                obj:Set(v)
            end
        end
    end
    return true
end

-- // Window -----------------------------------------------------------------
function Nova:CreateWindow(cfg)
    cfg = cfg or {}
    local windowName = cfg.Name or "Nova"
    if cfg.ToggleKey then Nova.ToggleKey = cfg.ToggleKey end

    local Main = New("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = cfg.Size or UDim2.new(0, 590, 0, 390),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = RootGui,
    })
    Round(Main, 10)
    Stroke(Main)

    -- Sidebar
    local Sidebar = New("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 150, 1, 0),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
        Parent = Main,
    })
    Round(Sidebar, 10)
    New("Frame", { -- square off right edge of sidebar
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -10, 0, 0),
        Size = UDim2.new(0, 10, 1, 0),
        Parent = Sidebar,
    })

    local TitleLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(1, -20, 0, 52),
        Font = Enum.Font.GothamBold,
        Text = windowName,
        TextColor3 = Theme.Text,
        TextSize = 17,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Sidebar,
    })

    New("Frame", { -- divider under title
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 10, 0, 52),
        Size = UDim2.new(1, -20, 0, 1),
        Parent = Sidebar,
    })

    local TabHolder = New("ScrollingFrame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 60),
        Size = UDim2.new(1, 0, 1, -84),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
        BorderSizePixel = 0,
        Parent = Sidebar,
    }, {
        New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
        New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
    })

    New("TextLabel", { -- footer
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 14, 1, -8),
        Size = UDim2.new(1, -20, 0, 14),
        Font = Enum.Font.Gotham,
        Text = "Nova UI  •  " .. KeyName(Nova.ToggleKey) .. " to hide",
        TextColor3 = Theme.SubText,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Sidebar,
    })

    -- Top bar (drag region + current tab title + window buttons)
    local TopBar = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 150, 0, 0),
        Size = UDim2.new(1, -150, 0, 46),
        Parent = Main,
    })
    local CurrentTabLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 18, 0, 0),
        Size = UDim2.new(1, -100, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = "",
        TextColor3 = Theme.Text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TopBar,
    })

    local CloseBtn = New("TextButton", {
        BackgroundColor3 = Theme.Element,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0, 26, 0, 26),
        Font = Enum.Font.GothamBold,
        Text = "×",
        TextColor3 = Theme.SubText,
        TextSize = 16,
        AutoButtonColor = false,
        Parent = TopBar,
    })
    Round(CloseBtn, 6)
    local HideBtn = New("TextButton", {
        BackgroundColor3 = Theme.Element,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -44, 0.5, 0),
        Size = UDim2.new(0, 26, 0, 26),
        Font = Enum.Font.GothamBold,
        Text = "—",
        TextColor3 = Theme.SubText,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = TopBar,
    })
    Round(HideBtn, 6)

    MakeDraggable(TopBar, Main)
    MakeDraggable(TitleLabel, Main)

    CloseBtn.MouseButton1Click:Connect(function()
        RootGui:Destroy()
    end)
    HideBtn.MouseButton1Click:Connect(function()
        Main.Visible = false
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Nova.ToggleKey then
            Main.Visible = not Main.Visible
        end
    end)

    local Content = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 150, 0, 46),
        Size = UDim2.new(1, -150, 1, -46),
        Parent = Main,
    })

    local Window = { Tabs = {}, Main = Main, Gui = RootGui }
    local firstTab = true

    -- // Tab -----------------------------------------------------------------
    function Window:CreateTab(tabName)
        local TabButton = New("TextButton", {
            BackgroundColor3 = Theme.Element,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 32),
            Font = Enum.Font.GothamMedium,
            Text = "  " .. tabName,
            TextColor3 = Theme.SubText,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
            Parent = TabHolder,
        })
        Round(TabButton, 6)

        local Page = New("ScrollingFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Stroke,
            BorderSizePixel = 0,
            Visible = false,
            Parent = Content,
        }, {
            New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 14),
                PaddingRight = UDim.new(0, 14),
                PaddingTop = UDim.new(0, 2),
                PaddingBottom = UDim.new(0, 14),
            }),
        })

        local Tab = { Button = TabButton, Page = Page, Name = tabName }

        local function Select()
            for _, other in ipairs(Window.Tabs) do
                other.Page.Visible = false
                Tween(other.Button, { BackgroundTransparency = 1, TextColor3 = Theme.SubText })
            end
            Page.Visible = true
            CurrentTabLabel.Text = tabName
            Tween(TabButton, { BackgroundTransparency = 0, BackgroundColor3 = Theme.Accent, TextColor3 = Theme.Text })
        end
        TabButton.MouseButton1Click:Connect(Select)
        table.insert(Window.Tabs, Tab)
        if firstTab then firstTab = false; Select() end

        -- shared element base
        local function ElementBase(height)
            local frame = New("Frame", {
                BackgroundColor3 = Theme.Element,
                Size = UDim2.new(1, 0, 0, height),
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Parent = Page,
            })
            Round(frame, 6)
            Stroke(frame)
            return frame
        end

        local function HoverFX(frame)
            frame.MouseEnter:Connect(function() Tween(frame, { BackgroundColor3 = Theme.ElementHover }) end)
            frame.MouseLeave:Connect(function() Tween(frame, { BackgroundColor3 = Theme.Element }) end)
        end

        -- // Section
        function Tab:CreateSection(text)
            local lbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 26),
                Font = Enum.Font.GothamBold,
                Text = text,
                TextColor3 = Theme.SubText,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = Page,
            })
            local obj = {}
            function obj:Set(t) lbl.Text = t end
            return obj
        end

        -- // Collapsible group header
        function Tab:CreateCollapsible(text, defaultOpen)
            local open = defaultOpen == true
            local frames = {}
            local header = New("TextButton", {
                BackgroundColor3 = Theme.Element,
                Size = UDim2.new(1, 0, 0, 28),
                Text = "",
                AutoButtonColor = false,
                Parent = Page,
            })
            Round(header, 6)
            Stroke(header)
            HoverFX(header)
            local title = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -40, 1, 0),
                Font = Enum.Font.GothamBold,
                Text = text,
                TextColor3 = Theme.SubText,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = header,
            })
            local arrow = New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -12, 0, 0),
                Size = UDim2.new(0, 16, 1, 0),
                Font = Enum.Font.GothamBold,
                Text = "▸",
                TextColor3 = Theme.SubText,
                TextSize = 12,
                Parent = header,
            })
            local function render()
                arrow.Text = open and "▾" or "▸"
                title.TextColor3 = open and Theme.Text or Theme.SubText
                for _, f in ipairs(frames) do f.Visible = open end
            end
            header.MouseButton1Click:Connect(function()
                open = not open
                render()
            end)
            local group = {}
            function group:Add(frame)
                table.insert(frames, frame)
                frame.Visible = open
            end
            function group:Set(t) title.Text = t end
            function group:SetOpen(v)
                open = v and true or false
                render()
            end
            render()
            return group
        end

        -- // Label
        function Tab:CreateLabel(text)
            local frame = ElementBase(30)
            local lbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -24, 1, 0),
                Font = Enum.Font.Gotham,
                Text = text,
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local obj = {}
            function obj:Set(t) lbl.Text = t end
            return obj
        end

        -- // Paragraph
        function Tab:CreateParagraph(cfg)
            cfg = cfg or {}
            local frame = New("Frame", {
                BackgroundColor3 = Theme.Element,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BorderSizePixel = 0,
                Parent = Page,
            })
            Round(frame, 6)
            Stroke(frame)
            local title = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 8),
                Size = UDim2.new(1, -24, 0, 16),
                Font = Enum.Font.GothamBold,
                Text = cfg.Title or "Paragraph",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local body = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 26),
                Size = UDim2.new(1, -24, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Font = Enum.Font.Gotham,
                Text = cfg.Content or "",
                TextColor3 = Theme.SubText,
                TextSize = 12,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                Parent = frame,
            })
            New("UIPadding", { PaddingBottom = UDim.new(0, 10), Parent = frame })
            local obj = {}
            function obj:Set(t, c)
                if t then title.Text = t end
                if c then body.Text = c end
            end
            return obj
        end

        -- // Button
        function Tab:CreateButton(cfg)
            cfg = cfg or {}
            local frame = ElementBase(34)
            HoverFX(frame)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -24, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg.Name or "Button",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -14, 0.5, 0),
                Size = UDim2.new(0, 20, 0, 20),
                Font = Enum.Font.GothamBold,
                Text = "➜",
                TextColor3 = Theme.SubText,
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
                Tween(frame, { BackgroundColor3 = Theme.AccentDark }, 0.08)
                task.delay(0.1, function() Tween(frame, { BackgroundColor3 = Theme.Element }, 0.2) end)
                if cfg.Callback then task.spawn(cfg.Callback) end
            end)
            return { Frame = frame }
        end

        -- // Toggle
        function Tab:CreateToggle(cfg)
            cfg = cfg or {}
            local state = cfg.Default or cfg.CurrentValue or false
            local frame = ElementBase(34)
            HoverFX(frame)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -70, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg.Name or "Toggle",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local pill = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -12, 0.5, 0),
                Size = UDim2.new(0, 38, 0, 18),
                BackgroundColor3 = Theme.Stroke,
                BorderSizePixel = 0,
                Parent = frame,
            })
            Round(pill, 9)
            local knob = New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 2, 0.5, 0),
                Size = UDim2.new(0, 14, 0, 14),
                BackgroundColor3 = Color3.fromRGB(200, 200, 210),
                BorderSizePixel = 0,
                Parent = pill,
            })
            Round(knob, 7)

            local obj = {}
            local function render()
                Tween(pill, { BackgroundColor3 = state and Theme.Accent or Theme.Stroke })
                Tween(knob, { Position = state and UDim2.new(0, 22, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) })
            end
            function obj:Set(v)
                v = v and true or false
                if v == state then render() return end
                state = v
                render()
                if cfg.Callback then task.spawn(cfg.Callback, state) end
            end
            function obj:Get() return state end

            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                Parent = frame,
            })
            click.MouseButton1Click:Connect(function() obj:Set(not state) end)

            render()
            if state and cfg.Callback then task.spawn(cfg.Callback, state) end
            if cfg.Flag then Nova.Flags[cfg.Flag] = obj end
            obj.Frame = frame
            return obj
        end

        -- // Slider
        function Tab:CreateSlider(cfg)
            cfg = cfg or {}
            local min = cfg.Min or (cfg.Range and cfg.Range[1]) or 0
            local max = cfg.Max or (cfg.Range and cfg.Range[2]) or 100
            local increment = cfg.Increment or 1
            local suffix = cfg.Suffix or ""
            local value = math.clamp(cfg.Default or cfg.CurrentValue or min, min, max)

            local frame = ElementBase(48)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 6),
                Size = UDim2.new(1, -120, 0, 16),
                Font = Enum.Font.GothamMedium,
                Text = cfg.Name or "Slider",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local valueLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -12, 0, 6),
                Size = UDim2.new(0, 100, 0, 16),
                Font = Enum.Font.GothamMedium,
                Text = "",
                TextColor3 = Theme.SubText,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = frame,
            })
            local bar = New("Frame", {
                Position = UDim2.new(0, 12, 0, 32),
                Size = UDim2.new(1, -24, 0, 6),
                BackgroundColor3 = Theme.Stroke,
                BorderSizePixel = 0,
                Parent = frame,
            })
            Round(bar, 3)
            local fill = New("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                Parent = bar,
            })
            Round(fill, 3)

            local decimals = math.max(0, math.ceil(-math.log10(increment)))
            local obj = {}
            local function render()
                local alpha = (max == min) and 0 or (value - min) / (max - min)
                fill.Size = UDim2.new(alpha, 0, 1, 0)
                valueLabel.Text = string.format("%." .. decimals .. "f", value) .. (suffix ~= "" and (" " .. suffix) or "")
            end
            function obj:Set(v)
                v = math.clamp(math.floor(v / increment + 0.5) * increment, min, max)
                if v == value then render() return end
                value = v
                render()
                if cfg.Callback then task.spawn(cfg.Callback, value) end
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
            if cfg.Flag then Nova.Flags[cfg.Flag] = obj end
            return obj
        end

        -- // Dropdown
        function Tab:CreateDropdown(cfg)
            cfg = cfg or {}
            local options = cfg.Options or {}
            local selected = cfg.Default or cfg.CurrentOption
            local open = false

            local frame = ElementBase(34)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(0.5, -12, 0, 34),
                Font = Enum.Font.GothamMedium,
                Text = cfg.Name or "Dropdown",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local selectedLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -34, 0, 0),
                Size = UDim2.new(0.5, -40, 0, 34),
                Font = Enum.Font.Gotham,
                Text = selected and tostring(selected) or "Select…",
                TextColor3 = Theme.SubText,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = frame,
            })
            local arrow = New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -12, 0, 0),
                Size = UDim2.new(0, 16, 0, 34),
                Font = Enum.Font.GothamBold,
                Text = "▾",
                TextColor3 = Theme.SubText,
                TextSize = 13,
                Parent = frame,
            })
            local optionHolder = New("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 36),
                Size = UDim2.new(1, -16, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = frame,
            }, {
                New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
            })

            local obj = {}
            local optionButtons = {}

            local function closedHeight() return 34 end
            local function openHeight() return 34 + 6 + #options * 26 + 6 end

            local function setOpen(v)
                open = v
                Tween(arrow, { Rotation = open and 180 or 0 })
                Tween(frame, { Size = UDim2.new(1, 0, 0, open and openHeight() or closedHeight()) }, 0.22)
            end

            local function renderSelection()
                selectedLabel.Text = selected and tostring(selected) or "Select…"
                for opt, btn in pairs(optionButtons) do
                    btn.TextColor3 = (opt == selected) and Theme.Accent or Theme.SubText
                end
            end

            local function buildOptions()
                for _, btn in pairs(optionButtons) do btn:Destroy() end
                optionButtons = {}
                for _, opt in ipairs(options) do
                    local btn = New("TextButton", {
                        BackgroundColor3 = Theme.Background,
                        Size = UDim2.new(1, 0, 0, 24),
                        Font = Enum.Font.Gotham,
                        Text = "  " .. tostring(opt),
                        TextColor3 = Theme.SubText,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        AutoButtonColor = false,
                        Parent = optionHolder,
                    })
                    Round(btn, 4)
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
                if cfg.Callback then task.spawn(cfg.Callback, selected) end
            end
            function obj:Get() return selected end
            function obj:Refresh(newOptions, keepSelection)
                options = newOptions or {}
                if not keepSelection then selected = nil end
                buildOptions()
                renderSelection()
                if open then setOpen(true) end
            end

            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 34),
                Text = "",
                Parent = frame,
            })
            click.MouseButton1Click:Connect(function() setOpen(not open) end)

            buildOptions()
            renderSelection()
            if cfg.Flag then Nova.Flags[cfg.Flag] = obj end
            return obj
        end

        -- // Input
        function Tab:CreateInput(cfg)
            cfg = cfg or {}
            local frame = ElementBase(34)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(0.5, -12, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg.Name or "Input",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local boxHolder = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.new(0, 150, 0, 24),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Parent = frame,
            })
            Round(boxHolder, 5)
            Stroke(boxHolder)
            local box = New("TextBox", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -12, 1, 0),
                Position = UDim2.new(0, 6, 0, 0),
                Font = Enum.Font.Gotham,
                Text = cfg.Default or "",
                PlaceholderText = cfg.Placeholder or cfg.PlaceholderText or "…",
                PlaceholderColor3 = Theme.SubText,
                TextColor3 = Theme.Text,
                TextSize = 12,
                ClearTextOnFocus = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = boxHolder,
            })
            box.FocusLost:Connect(function(enterPressed)
                if cfg.Callback then task.spawn(cfg.Callback, box.Text, enterPressed) end
                if cfg.RemoveTextAfterFocusLost then box.Text = "" end
            end)
            local obj = {}
            function obj:Set(t)
                box.Text = tostring(t)
                if cfg.Callback then task.spawn(cfg.Callback, box.Text, false) end
            end
            function obj:Get() return box.Text end
            if cfg.Flag then Nova.Flags[cfg.Flag] = obj end
            return obj
        end

        -- // Keybind
        function Tab:CreateKeybind(cfg)
            cfg = cfg or {}
            local key = cfg.Default -- Enum.KeyCode or nil
            local listening = false

            local frame = ElementBase(34)
            HoverFX(frame)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -110, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg.Name or "Keybind",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local keyBtn = New("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.new(0, 84, 0, 22),
                BackgroundColor3 = Theme.Background,
                Font = Enum.Font.Code,
                Text = KeyName(key),
                TextColor3 = Theme.SubText,
                TextSize = 12,
                AutoButtonColor = false,
                Parent = frame,
            })
            Round(keyBtn, 5)
            Stroke(keyBtn)

            local obj = {}
            function obj:Set(newKey)
                key = newKey
                keyBtn.Text = KeyName(key)
            end
            function obj:Get() return key end

            keyBtn.MouseButton1Click:Connect(function()
                listening = true
                keyBtn.Text = "…"
                keyBtn.TextColor3 = Theme.Accent
            end)

            UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    listening = false
                    keyBtn.TextColor3 = Theme.SubText
                    if input.KeyCode == Enum.KeyCode.Escape then
                        obj:Set(nil)
                    else
                        obj:Set(input.KeyCode)
                    end
                    return
                end
                if not gameProcessed and key and input.KeyCode == key then
                    if cfg.Callback then task.spawn(cfg.Callback, key) end
                end
            end)

            if cfg.Flag then Nova.Flags[cfg.Flag] = obj end
            return obj
        end

        return Tab
    end

    function Window:Destroy()
        RootGui:Destroy()
    end

    table.insert(Nova.Windows, Window)
    return Window
end

function Nova:Destroy()
    RootGui:Destroy()
end

return Nova
