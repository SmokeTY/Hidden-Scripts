--[[
    Glacier UI Library v1.0
    Glassmorphism / frosted-glass theme for Roblox executors

    Usage:
        local Glacier = loadstring(readfile("UI/Glacier/Glacier.lua"))()
        local Window = Glacier:CreateWindow({ Name = "Glacier Hub", ToggleKey = Enum.KeyCode.RightShift })
        local Tab = Window:CreateTab("Main")
        Tab:CreateToggle({ Name = "Auto Farm", Flag = "AutoFarm", Callback = function(v) end })

    Elements: Section, Label, Button, Toggle, Slider, Dropdown, Input, Keybind
    Extras:   Glacier:Notify, Glacier.Flags, Glacier:SaveConfig / LoadConfig, Glacier:Destroy
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local Glacier = {
    Flags = {},
    Windows = {},
    ToggleKey = Enum.KeyCode.RightShift,
    ConfigFolder = "GlacierUI",
}

-- // Theme ------------------------------------------------------------------
-- Frosted dark glass: layered semi-transparent panes + thin white strokes.
local Theme = {
    GlassColor        = Color3.fromRGB(20, 24, 34),    -- window pane
    GlassTransparency = 0.25,

    PaneColor         = Color3.fromRGB(255, 255, 255), -- element panes
    PaneTransparency  = 0.92,
    PaneHoverDelta    = 0.06,                          -- hover "condensation": more opaque

    SidebarColor         = Color3.fromRGB(255, 255, 255),
    SidebarTransparency  = 0.95,

    StrokeColor        = Color3.fromRGB(255, 255, 255),
    StrokeTransparency = 0.75,
    StrokeHoverDelta   = 0.2,

    Accent      = Color3.fromRGB(120, 190, 255),       -- ice blue
    AccentDeep  = Color3.fromRGB(80, 150, 230),

    Text    = Color3.fromRGB(240, 245, 255),
    SubText = Color3.fromRGB(170, 180, 200),

    Font     = Enum.Font.GothamMedium,
    FontBold = Enum.Font.GothamBold,
    FontBody = Enum.Font.Gotham,

    WindowCorner  = 14,
    ElementCorner = 10,
}
Glacier.Theme = Theme

local TWEEN_TIME = 0.25
local TWEEN_STYLE = Enum.EasingStyle.Quart

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
    local t = TweenService:Create(inst, TweenInfo.new(time or TWEEN_TIME, TWEEN_STYLE, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function Round(inst, radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius or Theme.ElementCorner), Parent = inst })
end

local function FrostStroke(inst, transparency, color)
    return New("UIStroke", {
        Color = color or Theme.StrokeColor,
        Transparency = transparency or Theme.StrokeTransparency,
        Thickness = 1,
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

-- Hover "condensation": pane fogs up (more opaque) while hovered.
-- Base transparencies are captured once here — no magic numbers duplicated.
local function HoverFrost(frame, stroke)
    local baseBg = frame.BackgroundTransparency
    local baseStroke = stroke and stroke.Transparency or nil
    frame.MouseEnter:Connect(function()
        Tween(frame, { BackgroundTransparency = math.max(0, baseBg - Theme.PaneHoverDelta) })
        if stroke then
            Tween(stroke, { Transparency = math.max(0, baseStroke - Theme.StrokeHoverDelta) })
        end
    end)
    frame.MouseLeave:Connect(function()
        Tween(frame, { BackgroundTransparency = baseBg })
        if stroke then
            Tween(stroke, { Transparency = baseStroke })
        end
    end)
end

-- // Root gui ---------------------------------------------------------------
local RootGui = New("ScreenGui", {
    Name = "GlacierUI_" .. HttpService:GenerateGUID(false):sub(1, 8),
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    -- IgnoreGuiInset intentionally left false
})
ProtectGui(RootGui)

-- // Notifications (glass toasts, bottom-right, slide up) ---------------------
local NotifHolder = New("Frame", {
    Name = "Notifications",
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -16, 1, -16),
    Size = UDim2.new(0, 300, 1, -32),
    BackgroundTransparency = 1,
    Parent = RootGui,
}, {
    New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, 10),
    }),
})

function Glacier:Notify(cfg)
    cfg = cfg or {}
    local duration = cfg.Duration or 4

    -- transparent shell keeps its slot in the list; inner pane slides up into it
    local shell = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = NotifHolder,
    })

    local pane = New("Frame", {
        BackgroundColor3 = Theme.GlassColor,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 26),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Parent = shell,
    })
    Round(pane, Theme.ElementCorner)
    local stroke = FrostStroke(pane, 1)

    New("Frame", { -- ice accent sliver
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.2,
        Position = UDim2.new(0, 10, 0, 12),
        Size = UDim2.new(0, 3, 1, -24),
        BorderSizePixel = 0,
        Parent = pane,
    }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })

    local title = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 24, 0, 10),
        Size = UDim2.new(1, -36, 0, 18),
        Font = Theme.FontBold,
        Text = cfg.Title or "Notification",
        TextColor3 = Theme.Text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        Parent = pane,
    })
    local body = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 24, 0, 30),
        Size = UDim2.new(1, -36, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Theme.FontBody,
        Text = cfg.Content or "",
        TextColor3 = Theme.SubText,
        TextSize = 13,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextTransparency = 1,
        Parent = pane,
    })
    New("UIPadding", { PaddingBottom = UDim.new(0, 12), Parent = pane })

    -- slide up + frost in
    Tween(pane, { Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = Theme.GlassTransparency })
    Tween(stroke, { Transparency = Theme.StrokeTransparency })
    Tween(title, { TextTransparency = 0 })
    Tween(body, { TextTransparency = 0.1 })

    task.delay(duration, function()
        if not shell.Parent then return end
        Tween(pane, { Position = UDim2.new(0, 0, 0, 18), BackgroundTransparency = 1 })
        Tween(stroke, { Transparency = 1 })
        Tween(title, { TextTransparency = 1 })
        Tween(body, { TextTransparency = 1 })
        task.wait(TWEEN_TIME + 0.05)
        shell:Destroy()
    end)
end

-- // Config saving ------------------------------------------------------------
local function CanUseFiles()
    return typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"
end

function Glacier:SaveConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local data = {}
    for flag, obj in pairs(Glacier.Flags) do
        local v = obj:Get()
        if typeof(v) == "EnumItem" then
            data[flag] = { __keycode = v.Name }
        elseif typeof(v) == "Color3" then
            data[flag] = { __color = { v.R, v.G, v.B } }
        elseif typeof(v) == "boolean" or typeof(v) == "number" or typeof(v) == "string" or typeof(v) == "table" then
            data[flag] = v
        end
    end
    if typeof(isfolder) == "function" and typeof(makefolder) == "function" and not isfolder(Glacier.ConfigFolder) then
        makefolder(Glacier.ConfigFolder)
    end
    writefile(Glacier.ConfigFolder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    return true
end

function Glacier:LoadConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local path = Glacier.ConfigFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false, "no config file" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok then return false, "corrupt config" end
    for flag, v in pairs(data) do
        local obj = Glacier.Flags[flag]
        if obj then
            if typeof(v) == "table" and v.__keycode then
                local okKey, keyCode = pcall(function() return Enum.KeyCode[v.__keycode] end)
                if okKey then obj:Set(keyCode) end
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
function Glacier:CreateWindow(cfg)
    cfg = cfg or {}
    local windowName = cfg.Name or "Glacier"
    if cfg.ToggleKey then Glacier.ToggleKey = cfg.ToggleKey end

    local Main = New("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = cfg.Size or UDim2.new(0, 580, 0, 400),
        BackgroundColor3 = Theme.GlassColor,
        BackgroundTransparency = Theme.GlassTransparency,
        BorderSizePixel = 0,
        Parent = RootGui,
    })
    Round(Main, Theme.WindowCorner)
    FrostStroke(Main)

    -- faint top sheen so the pane reads as glass
    New("Frame", {
        Name = "Sheen",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.96,
        Size = UDim2.new(1, 0, 0, 60),
        BorderSizePixel = 0,
        Parent = Main,
    }, { New("UICorner", { CornerRadius = UDim.new(0, Theme.WindowCorner) }) })

    -- // Sidebar (frosted pane)
    local Sidebar = New("Frame", {
        Name = "Sidebar",
        Position = UDim2.new(0, 10, 0, 10),
        Size = UDim2.new(0, 148, 1, -20),
        BackgroundColor3 = Theme.SidebarColor,
        BackgroundTransparency = Theme.SidebarTransparency,
        BorderSizePixel = 0,
        Parent = Main,
    })
    Round(Sidebar, 12)
    FrostStroke(Sidebar)

    local TitleLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(1, -24, 0, 48),
        Font = Theme.FontBold,
        Text = windowName,
        TextColor3 = Theme.Text,
        TextSize = 17,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Sidebar,
    })

    New("Frame", { -- frosted divider
        BackgroundColor3 = Theme.StrokeColor,
        BackgroundTransparency = 0.85,
        Position = UDim2.new(0, 12, 0, 48),
        Size = UDim2.new(1, -24, 0, 1),
        BorderSizePixel = 0,
        Parent = Sidebar,
    })

    local TabHolder = New("ScrollingFrame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 56),
        Size = UDim2.new(1, 0, 1, -80),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
        BorderSizePixel = 0,
        Parent = Sidebar,
    }, {
        New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
        New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
    })

    New("TextLabel", { -- footer hint
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 14, 1, -8),
        Size = UDim2.new(1, -24, 0, 14),
        Font = Theme.FontBody,
        Text = KeyName(Glacier.ToggleKey) .. " to hide",
        TextColor3 = Theme.SubText,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Sidebar,
    })

    -- // Top bar (drag region + tab title + window buttons)
    local TopBar = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 168, 0, 10),
        Size = UDim2.new(1, -178, 0, 42),
        Parent = Main,
    })
    local CurrentTabLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(1, -100, 1, 0),
        Font = Theme.Font,
        Text = "",
        TextColor3 = Theme.Text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TopBar,
    })

    local function WindowButton(text, xOffset)
        local btn = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, xOffset, 0.5, 0),
            Size = UDim2.new(0, 26, 0, 26),
            BackgroundColor3 = Theme.PaneColor,
            BackgroundTransparency = Theme.PaneTransparency,
            Font = Theme.FontBold,
            Text = text,
            TextColor3 = Theme.SubText,
            TextSize = 14,
            AutoButtonColor = false,
            Parent = TopBar,
        })
        New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = btn })
        local stroke = FrostStroke(btn)
        HoverFrost(btn, stroke)
        return btn
    end
    local CloseBtn = WindowButton("×", -4)
    local HideBtn = WindowButton("—", -36)
    HideBtn.TextSize = 11

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
        if input.KeyCode == Glacier.ToggleKey then
            Main.Visible = not Main.Visible
        end
    end)

    local Content = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 168, 0, 52),
        Size = UDim2.new(1, -178, 1, -62),
        Parent = Main,
    })

    local Window = { Tabs = {}, Main = Main, Gui = RootGui }
    local firstTab = true

    -- // Tab ---------------------------------------------------------------
    function Window:CreateTab(tabName)
        -- glass pill tab button
        local TabButton = New("TextButton", {
            BackgroundColor3 = Theme.PaneColor,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 32),
            Font = Theme.Font,
            Text = tabName,
            TextColor3 = Theme.SubText,
            TextSize = 13,
            AutoButtonColor = false,
            Parent = TabHolder,
        })
        New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = TabButton }) -- full pill
        local TabStroke = FrostStroke(TabButton, 1)

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
            New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 12),
                PaddingRight = UDim.new(0, 12),
                PaddingTop = UDim.new(0, 2),
                PaddingBottom = UDim.new(0, 12),
            }),
        })

        local Tab = { Button = TabButton, Page = Page, Name = tabName }

        local function Select()
            for _, other in ipairs(Window.Tabs) do
                other.Page.Visible = false
                Tween(other.Button, { BackgroundTransparency = 1, TextColor3 = Theme.SubText })
                Tween(other.Stroke, { Transparency = 1 })
            end
            Page.Visible = true
            CurrentTabLabel.Text = tabName
            -- brighter glass pill tinted ice-blue
            Tween(TabButton, {
                BackgroundColor3 = Theme.Accent,
                BackgroundTransparency = 0.8,
                TextColor3 = Theme.Text,
            })
            Tween(TabStroke, { Transparency = 0.5 })
        end
        Tab.Stroke = TabStroke
        TabButton.MouseButton1Click:Connect(Select)
        table.insert(Window.Tabs, Tab)
        if firstTab then firstTab = false; Select() end

        -- shared frosted pane base
        local function ElementBase(height)
            local frame = New("Frame", {
                BackgroundColor3 = Theme.PaneColor,
                BackgroundTransparency = Theme.PaneTransparency,
                Size = UDim2.new(1, 0, 0, height),
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Parent = Page,
            })
            Round(frame, Theme.ElementCorner)
            local stroke = FrostStroke(frame)
            return frame, stroke
        end

        -- // Section
        function Tab:CreateSection(text)
            local row = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 24),
                Parent = Page,
            })
            local lbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 2, 0, 0),
                Size = UDim2.new(1, -4, 1, 0),
                Font = Theme.FontBold,
                Text = string.upper(text or ""),
                TextColor3 = Theme.Accent,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })
            New("Frame", { -- frosted rule after the text
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -2, 0.5, 4),
                Size = UDim2.new(0.45, 0, 0, 1),
                BackgroundColor3 = Theme.StrokeColor,
                BackgroundTransparency = 0.85,
                BorderSizePixel = 0,
                Parent = row,
            })
            local obj = {}
            function obj:Set(t) lbl.Text = string.upper(t or "") end
            return obj
        end

        -- // Label
        function Tab:CreateLabel(text)
            local frame = ElementBase(30)
            local lbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -24, 1, 0),
                Font = Theme.FontBody,
                Text = text or "",
                TextColor3 = Theme.SubText,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                Parent = frame,
            })
            local obj = {}
            function obj:Set(t) lbl.Text = t end
            return obj
        end

        -- // Button
        function Tab:CreateButton(cfg2)
            cfg2 = cfg2 or {}
            local frame, stroke = ElementBase(34)
            HoverFrost(frame, stroke)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -44, 1, 0),
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
                Size = UDim2.new(0, 20, 0, 20),
                Font = Theme.FontBold,
                Text = "❯",
                TextColor3 = Theme.Accent,
                TextSize = 12,
                Parent = frame,
            })
            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                Parent = frame,
            })
            click.MouseButton1Click:Connect(function()
                -- icy flash on press
                Tween(frame, { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.75 }, 0.08)
                task.delay(0.1, function()
                    Tween(frame, { BackgroundColor3 = Theme.PaneColor, BackgroundTransparency = Theme.PaneTransparency })
                end)
                if cfg2.Callback then task.spawn(cfg2.Callback) end
            end)
            return { Frame = frame }
        end

        -- // Toggle (circular knob sliding in a glass track)
        function Tab:CreateToggle(cfg2)
            cfg2 = cfg2 or {}
            local state = cfg2.Default or false
            local frame, stroke = ElementBase(34)
            HoverFrost(frame, stroke)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -76, 1, 0),
                Font = Theme.Font,
                Text = cfg2.Name or "Toggle",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local track = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -12, 0.5, 0),
                Size = UDim2.new(0, 42, 0, 20),
                BackgroundColor3 = Theme.PaneColor,
                BackgroundTransparency = 0.88,
                BorderSizePixel = 0,
                Parent = frame,
            })
            New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
            local trackStroke = FrostStroke(track)
            local knob = New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 3, 0.5, 0),
                Size = UDim2.new(0, 14, 0, 14),
                BackgroundColor3 = Color3.fromRGB(215, 225, 240),
                BorderSizePixel = 0,
                Parent = track,
            })
            New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

            local obj = {}
            local function render()
                if state then
                    Tween(track, { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.45 })
                    Tween(trackStroke, { Color = Theme.Accent, Transparency = 0.35 })
                    Tween(knob, { Position = UDim2.new(0, 25, 0.5, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255) })
                else
                    Tween(track, { BackgroundColor3 = Theme.PaneColor, BackgroundTransparency = 0.88 })
                    Tween(trackStroke, { Color = Theme.StrokeColor, Transparency = Theme.StrokeTransparency })
                    Tween(knob, { Position = UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = Color3.fromRGB(215, 225, 240) })
                end
            end
            function obj:Set(v)
                v = v and true or false
                if v == state then render() return end
                state = v
                render()
                if cfg2.Callback then task.spawn(cfg2.Callback, state) end
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
            if state and cfg2.Callback then task.spawn(cfg2.Callback, state) end
            if cfg2.Flag then Glacier.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Slider (thin track, round knob)
        function Tab:CreateSlider(cfg2)
            cfg2 = cfg2 or {}
            local min = cfg2.Min or 0
            local max = cfg2.Max or 100
            local increment = cfg2.Increment or 1
            local suffix = cfg2.Suffix or ""
            local value = math.clamp(cfg2.Default or min, min, max)

            local frame = ElementBase(48)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 7),
                Size = UDim2.new(1, -120, 0, 16),
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
                Position = UDim2.new(1, -12, 0, 7),
                Size = UDim2.new(0, 100, 0, 16),
                Font = Theme.Font,
                Text = "",
                TextColor3 = Theme.Accent,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = frame,
            })
            local bar = New("Frame", { -- thin glass track
                Position = UDim2.new(0, 14, 0, 34),
                Size = UDim2.new(1, -28, 0, 4),
                BackgroundColor3 = Theme.PaneColor,
                BackgroundTransparency = 0.85,
                BorderSizePixel = 0,
                Parent = frame,
            })
            New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })
            local fill = New("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = Theme.Accent,
                BackgroundTransparency = 0.25,
                BorderSizePixel = 0,
                Parent = bar,
            })
            New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
            local knob = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(0, 12, 0, 12),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                ZIndex = 2,
                Parent = bar,
            })
            New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })
            FrostStroke(knob, 0.5, Theme.Accent)

            local decimals = math.max(0, math.ceil(-math.log10(increment)))
            local obj = {}
            local function render(instant)
                local alpha = (max == min) and 0 or (value - min) / (max - min)
                if instant then
                    fill.Size = UDim2.new(alpha, 0, 1, 0)
                    knob.Position = UDim2.new(alpha, 0, 0.5, 0)
                else
                    Tween(fill, { Size = UDim2.new(alpha, 0, 1, 0) }, 0.1)
                    Tween(knob, { Position = UDim2.new(alpha, 0, 0.5, 0) }, 0.1)
                end
                valueLabel.Text = string.format("%." .. decimals .. "f", value) .. (suffix ~= "" and (" " .. suffix) or "")
            end
            function obj:Set(v)
                v = math.clamp(math.floor(v / increment + 0.5) * increment, min, max)
                if v == value then render() return end
                value = v
                render()
                if cfg2.Callback then task.spawn(cfg2.Callback, value) end
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

            render(true)
            if cfg2.Flag then Glacier.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Dropdown (pane expands, frosted option pills)
        function Tab:CreateDropdown(cfg2)
            cfg2 = cfg2 or {}
            local options = cfg2.Options or {}
            local selected = cfg2.Default
            local open = false

            local frame = ElementBase(34)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(0.5, -12, 0, 34),
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
                Position = UDim2.new(1, -34, 0, 0),
                Size = UDim2.new(0.5, -40, 0, 34),
                Font = Theme.FontBody,
                Text = "",
                TextColor3 = Theme.SubText,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = frame,
            })
            local arrow = New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -12, 0, 0),
                Size = UDim2.new(0, 16, 0, 34),
                Font = Theme.FontBold,
                Text = "▾",
                TextColor3 = Theme.Accent,
                TextSize = 13,
                Parent = frame,
            })
            local optionHolder = New("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, 38),
                Size = UDim2.new(1, -20, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = frame,
            }, {
                New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
            })

            local obj = {}
            local optionButtons = {}

            local function closedHeight() return 34 end
            local function openHeight() return 34 + 8 + #options * 26 + math.max(0, #options - 1) * 4 + 8 end

            local function setOpen(v)
                open = v
                Tween(arrow, { Rotation = open and 180 or 0 })
                Tween(frame, { Size = UDim2.new(1, 0, 0, open and openHeight() or closedHeight()) })
            end

            local function renderSelection()
                selectedLabel.Text = selected ~= nil and tostring(selected) or "Select…"
                for opt, btn in pairs(optionButtons) do
                    if opt == selected then
                        btn.TextColor3 = Theme.Text
                        btn.BackgroundColor3 = Theme.Accent
                        btn.BackgroundTransparency = 0.8
                    else
                        btn.TextColor3 = Theme.SubText
                        btn.BackgroundColor3 = Theme.PaneColor
                        btn.BackgroundTransparency = 0.94
                    end
                end
            end

            local function buildOptions()
                for _, btn in pairs(optionButtons) do btn:Destroy() end
                optionButtons = {}
                for _, opt in ipairs(options) do
                    local btn = New("TextButton", {
                        BackgroundColor3 = Theme.PaneColor,
                        BackgroundTransparency = 0.94,
                        Size = UDim2.new(1, 0, 0, 26),
                        Font = Theme.FontBody,
                        Text = "  " .. tostring(opt),
                        TextColor3 = Theme.SubText,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        AutoButtonColor = false,
                        Parent = optionHolder,
                    })
                    Round(btn, 8)
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
                if cfg2.Callback then task.spawn(cfg2.Callback, selected) end
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
            if cfg2.Flag then Glacier.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Input
        function Tab:CreateInput(cfg2)
            cfg2 = cfg2 or {}
            local frame, stroke = ElementBase(34)
            HoverFrost(frame, stroke)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(0.45, -12, 1, 0),
                Font = Theme.Font,
                Text = cfg2.Name or "Input",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local boxHolder = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.new(0, 160, 0, 24),
                BackgroundColor3 = Theme.GlassColor,
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
                Parent = frame,
            })
            Round(boxHolder, 8)
            local boxStroke = FrostStroke(boxHolder)
            local box = New("TextBox", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 0),
                Size = UDim2.new(1, -16, 1, 0),
                Font = Theme.FontBody,
                Text = cfg2.Default or "",
                PlaceholderText = cfg2.Placeholder or "…",
                PlaceholderColor3 = Theme.SubText,
                TextColor3 = Theme.Text,
                TextSize = 12,
                ClearTextOnFocus = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = boxHolder,
            })
            box.Focused:Connect(function()
                Tween(boxStroke, { Color = Theme.Accent, Transparency = 0.35 })
            end)
            box.FocusLost:Connect(function(enterPressed)
                Tween(boxStroke, { Color = Theme.StrokeColor, Transparency = Theme.StrokeTransparency })
                if cfg2.Callback then task.spawn(cfg2.Callback, box.Text, enterPressed) end
            end)
            local obj = {}
            function obj:Set(t)
                box.Text = tostring(t)
                if cfg2.Callback then task.spawn(cfg2.Callback, box.Text, false) end
            end
            function obj:Get() return box.Text end
            if cfg2.Flag then Glacier.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Keybind
        function Tab:CreateKeybind(cfg2)
            cfg2 = cfg2 or {}
            local key = cfg2.Default -- Enum.KeyCode or nil
            local listening = false

            local frame, stroke = ElementBase(34)
            HoverFrost(frame, stroke)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
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
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.new(0, 88, 0, 22),
                BackgroundColor3 = Theme.GlassColor,
                BackgroundTransparency = 0.5,
                Font = Theme.FontBody,
                Text = KeyName(key),
                TextColor3 = Theme.SubText,
                TextSize = 12,
                AutoButtonColor = false,
                Parent = frame,
            })
            Round(keyBtn, 8)
            local keyStroke = FrostStroke(keyBtn)

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
                Tween(keyStroke, { Color = Theme.Accent, Transparency = 0.35 })
            end)

            UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    listening = false
                    keyBtn.TextColor3 = Theme.SubText
                    Tween(keyStroke, { Color = Theme.StrokeColor, Transparency = Theme.StrokeTransparency })
                    if input.KeyCode == Enum.KeyCode.Escape then
                        obj:Set(nil)
                    else
                        obj:Set(input.KeyCode)
                    end
                    return
                end
                if not gameProcessed and key and input.KeyCode == key then
                    if cfg2.Callback then task.spawn(cfg2.Callback, key) end
                end
            end)

            if cfg2.Flag then Glacier.Flags[cfg2.Flag] = obj end
            return obj
        end

        return Tab
    end

    function Window:Destroy()
        RootGui:Destroy()
    end

    table.insert(Glacier.Windows, Window)
    return Window
end

function Glacier:Destroy()
    RootGui:Destroy()
end

return Glacier
