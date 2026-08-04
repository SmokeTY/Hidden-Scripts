--[[
    Zenith UI Library v1.0
    Mobile-first / touch-first UI library for Roblox executors

    Portrait phone-shaped window (~420x520), bottom tab bar with dot
    indicators, chunky thumb-friendly elements, and a signature floating
    bubble: minimize collapses the window into a draggable 52x52 circle,
    tap the bubble to restore.

    Usage:
        local Zenith = loadstring(readfile("UI/Zenith/Zenith.lua"))()
        local Window = Zenith:CreateWindow({ Name = "My Hub", ToggleKey = Enum.KeyCode.RightShift })
        local Tab = Window:CreateTab("Main")
        Tab:CreateToggle({ Name = "Auto Farm", Flag = "AutoFarm", Callback = function(v) end })

    Elements: Section, Label, Button, Toggle, Slider, Dropdown, Input, Keybind
    Extras:   Zenith:Notify (bottom snackbar), Zenith.Flags,
              Zenith:SaveConfig / LoadConfig, ToggleKey hides/shows
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local Zenith = {
    Flags = {},
    Windows = {},
    ToggleKey = Enum.KeyCode.RightShift,
    ConfigFolder = "ZenithUI",
}

-- // Theme ------------------------------------------------------------------
local Theme = {
    Background   = Color3.fromRGB(13, 17, 28),
    Surface      = Color3.fromRGB(21, 27, 43),
    Element      = Color3.fromRGB(30, 38, 58),
    ElementHover = Color3.fromRGB(38, 48, 72),
    Accent       = Color3.fromRGB(52, 224, 161),
    AccentDark   = Color3.fromRGB(34, 150, 108),
    Text         = Color3.fromRGB(236, 240, 248),
    Muted        = Color3.fromRGB(140, 152, 175),
    Stroke       = Color3.fromRGB(44, 54, 80),
    Knob         = Color3.fromRGB(220, 226, 238),
}
Zenith.Theme = Theme

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
    return New("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = inst })
end

local function Circle(inst)
    return New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = inst })
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

-- // Root gui ---------------------------------------------------------------
local RootGui = New("ScreenGui", {
    Name = "ZenithUI_" .. HttpService:GenerateGUID(false):sub(1, 8),
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
ProtectGui(RootGui)

-- // Snackbar notifications (bottom-center, slides up above the tab bar) ----
local ActiveSnack = nil

function Zenith:Notify(cfg)
    cfg = cfg or {}
    local duration = cfg.Duration or 3
    local text
    if cfg.Title and cfg.Content and cfg.Content ~= "" then
        text = tostring(cfg.Title) .. "  ·  " .. tostring(cfg.Content)
    else
        text = tostring(cfg.Title or cfg.Content or "Notification")
    end

    -- only one snackbar at a time; replace the old one
    if ActiveSnack then
        local old = ActiveSnack
        ActiveSnack = nil
        Tween(old, { Position = UDim2.new(0.5, 0, 1, 60) }, 0.15)
        task.delay(0.16, function()
            if old.Parent then old:Destroy() end
        end)
    end

    local snack = New("Frame", {
        Name = "Snackbar",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, 60), -- start below the screen edge
        Size = UDim2.new(0, 0, 0, 44),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        ZIndex = 100,
        Parent = RootGui,
    })
    Round(snack, 12)
    Stroke(snack, Theme.Stroke)

    New("Frame", { -- mint accent dot
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 14, 0.5, 0),
        Size = UDim2.new(0, 8, 0, 8),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 101,
        Parent = snack,
    }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })

    New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 32, 0, 0),
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextColor3 = Theme.Text,
        TextSize = 14,
        ZIndex = 101,
        Parent = snack,
    })
    New("UIPadding", { PaddingRight = UDim.new(0, 16), Parent = snack })

    ActiveSnack = snack
    -- slide up above the bottom tab bar zone
    Tween(snack, { Position = UDim2.new(0.5, 0, 1, -88) }, 0.25)

    task.delay(duration, function()
        if snack.Parent and ActiveSnack == snack then
            ActiveSnack = nil
            Tween(snack, { Position = UDim2.new(0.5, 0, 1, 60) }, 0.25)
            task.wait(0.27)
            if snack.Parent then snack:Destroy() end
        end
    end)
end

-- // Config saving ----------------------------------------------------------
local function CanUseFiles()
    return typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"
end

function Zenith:SaveConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local data = {}
    for flag, obj in pairs(Zenith.Flags) do
        local v = obj:Get()
        if typeof(v) == "EnumItem" then
            data[flag] = { __keycode = v.Name }
        elseif typeof(v) == "Color3" then
            data[flag] = { __color = { v.R, v.G, v.B } }
        elseif typeof(v) == "boolean" or typeof(v) == "number" or typeof(v) == "string" or typeof(v) == "table" then
            data[flag] = v
        end
    end
    if typeof(isfolder) == "function" and typeof(makefolder) == "function" and not isfolder(Zenith.ConfigFolder) then
        makefolder(Zenith.ConfigFolder)
    end
    writefile(Zenith.ConfigFolder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    return true
end

function Zenith:LoadConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local path = Zenith.ConfigFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false, "no config file" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok then return false, "corrupt config" end
    for flag, v in pairs(data) do
        local obj = Zenith.Flags[flag]
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
function Zenith:CreateWindow(cfg)
    cfg = cfg or {}
    local windowName = cfg.Name or "Zenith"
    if cfg.ToggleKey then Zenith.ToggleKey = cfg.ToggleKey end

    -- size the portrait window, clamped so it fits small phone viewports
    local winW, winH = 420, 520
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then
            local vp = cam.ViewportSize
            winW = math.min(winW, math.floor(vp.X - 16))
            winH = math.min(winH, math.floor(vp.Y - 16))
        end
    end)

    local HEADER_H = 56
    local TABBAR_H = 62

    local Main = New("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = cfg.Size or UDim2.new(0, winW, 0, winH),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = RootGui,
    })
    Round(Main, 16)
    Stroke(Main)

    -- // Header ---------------------------------------------------------------
    local Header = New("Frame", {
        Name = "Header",
        BackgroundColor3 = Theme.Surface,
        Size = UDim2.new(1, 0, 0, HEADER_H),
        BorderSizePixel = 0,
        Parent = Main,
    })
    Round(Header, 16)
    New("Frame", { -- square off bottom edge of header
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -16),
        Size = UDim2.new(1, 0, 0, 16),
        Parent = Header,
    })

    New("Frame", { -- accent tick next to title
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 16, 0.5, 0),
        Size = UDim2.new(0, 4, 0, 22),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = Header,
    }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })

    New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 30, 0, 0),
        Size = UDim2.new(1, -130, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = windowName,
        TextColor3 = Theme.Text,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Header,
    })

    local CloseBtn = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0, 38, 0, 38),
        BackgroundColor3 = Theme.Element,
        Font = Enum.Font.GothamBold,
        Text = "×",
        TextColor3 = Theme.Muted,
        TextSize = 20,
        AutoButtonColor = false,
        Parent = Header,
    })
    Circle(CloseBtn)

    local MinBtn = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -56, 0.5, 0),
        Size = UDim2.new(0, 38, 0, 38),
        BackgroundColor3 = Theme.Element,
        Font = Enum.Font.GothamBold,
        Text = "—",
        TextColor3 = Theme.Accent,
        TextSize = 14,
        AutoButtonColor = false,
        Parent = Header,
    })
    Circle(MinBtn)

    MakeDraggable(Header, Main)

    -- // Bottom tab bar -------------------------------------------------------
    local TabBar = New("Frame", {
        Name = "TabBar",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, TABBAR_H),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = Main,
    })
    Round(TabBar, 16)
    New("Frame", { -- square off top edge of tab bar
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 16),
        Parent = TabBar,
    })

    local TabButtonHolder = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = TabBar,
    }, {
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
        }),
    })

    -- // Content --------------------------------------------------------------
    local Content = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, HEADER_H),
        Size = UDim2.new(1, 0, 1, -(HEADER_H + TABBAR_H)),
        ClipsDescendants = true,
        Parent = Main,
    })

    -- // Bubble (signature minimize) -------------------------------------------
    local Bubble = New("TextButton", {
        Name = "Bubble",
        Size = UDim2.new(0, 52, 0, 52),
        Position = UDim2.new(0, 24, 0.4, 0),
        BackgroundColor3 = Theme.Surface,
        Font = Enum.Font.GothamBold,
        Text = "Z",
        TextColor3 = Theme.Accent,
        TextSize = 22,
        AutoButtonColor = false,
        Visible = false,
        ZIndex = 90,
        Parent = RootGui,
    })
    Circle(Bubble)
    Stroke(Bubble, Theme.Accent, 2)

    local minimized = false
    local savedPos = nil

    local function Minimize()
        if minimized then return end
        minimized = true
        savedPos = Main.Position
        -- park the bubble roughly where the header's minimize button was
        local bx = Main.AbsolutePosition.X + Main.AbsoluteSize.X - 60
        local by = Main.AbsolutePosition.Y + 8
        Bubble.Position = UDim2.new(0, math.floor(bx), 0, math.floor(by))
        Main.Visible = false
        Bubble.Visible = true
        Bubble.Size = UDim2.new(0, 0, 0, 0)
        Tween(Bubble, { Size = UDim2.new(0, 52, 0, 52) }, 0.18)
    end

    local function Restore()
        if not minimized then return end
        minimized = false
        Bubble.Visible = false
        if savedPos then Main.Position = savedPos end
        Main.Visible = true
    end

    MinBtn.MouseButton1Click:Connect(Minimize)
    CloseBtn.MouseButton1Click:Connect(function()
        RootGui:Destroy()
    end)

    -- bubble drag + tap-to-restore: only restore when total movement < 6 px
    do
        local dragging = false
        local dragInput = nil
        local dragStart = nil
        local startPos = nil
        local maxDist = 0

        Bubble.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = Bubble.Position
                maxDist = 0
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        if maxDist < 6 then
                            Restore()
                        end
                    end
                end)
            end
        end)
        Bubble.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                local dist = math.sqrt(delta.X * delta.X + delta.Y * delta.Y)
                if dist > maxDist then maxDist = dist end
                Bubble.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end

    -- toggle key still hides/shows for PC users (hides window or bubble)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Zenith.ToggleKey then
            if minimized then
                Bubble.Visible = not Bubble.Visible
            else
                Main.Visible = not Main.Visible
            end
        end
    end)

    local Window = { Tabs = {}, Main = Main, Bubble = Bubble, Gui = RootGui }
    local firstTab = true

    local function RelayoutTabs()
        local n = #Window.Tabs
        if n == 0 then return end
        for _, tab in ipairs(Window.Tabs) do
            tab.Button.Size = UDim2.new(1 / n, 0, 1, 0)
        end
    end

    -- // Tab -----------------------------------------------------------------
    function Window:CreateTab(tabName)
        local TabButton = New("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Text = "",
            AutoButtonColor = false,
            Parent = TabButtonHolder,
        })

        local Dot = New("Frame", { -- indicator dot above the active tab label
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 9),
            Size = UDim2.new(0, 6, 0, 6),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = TabButton,
        })
        Circle(Dot)

        local TabLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 14),
            Size = UDim2.new(1, 0, 1, -14),
            Font = Enum.Font.GothamMedium,
            Text = tabName,
            TextColor3 = Theme.Muted,
            TextSize = 14,
            Parent = TabButton,
        })

        local Page = New("ScrollingFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Stroke,
            BorderSizePixel = 0,
            Visible = false,
            Parent = Content,
        }, {
            New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 14),
                PaddingRight = UDim.new(0, 14),
                PaddingTop = UDim.new(0, 10),
                PaddingBottom = UDim.new(0, 14),
            }),
        })

        local Tab = { Button = TabButton, Page = Page, Name = tabName, Dot = Dot, Label = TabLabel }

        local function Select()
            for _, other in ipairs(Window.Tabs) do
                other.Page.Visible = false
                Tween(other.Dot, { BackgroundTransparency = 1 })
                Tween(other.Label, { TextColor3 = Theme.Muted })
            end
            Page.Visible = true
            Tween(Dot, { BackgroundTransparency = 0 })
            Tween(TabLabel, { TextColor3 = Theme.Accent })
        end
        TabButton.MouseButton1Click:Connect(Select)
        table.insert(Window.Tabs, Tab)
        RelayoutTabs()
        if firstTab then firstTab = false; Select() end

        -- shared element base: chunky rounded row
        local function ElementBase(height)
            local frame = New("Frame", {
                BackgroundColor3 = Theme.Element,
                Size = UDim2.new(1, 0, 0, height),
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Parent = Page,
            })
            Round(frame, 12)
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
                Size = UDim2.new(1, 0, 0, 30),
                Font = Enum.Font.GothamBold,
                Text = text,
                TextColor3 = Theme.Muted,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Bottom,
                Parent = Page,
            }, {
                New("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
            })
            local obj = {}
            function obj:Set(t) lbl.Text = t end
            return obj
        end

        -- // Label
        function Tab:CreateLabel(text)
            local frame = ElementBase(46)
            local lbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 16, 0, 0),
                Size = UDim2.new(1, -32, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = text,
                TextColor3 = Theme.Text,
                TextSize = 14,
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
            local frame = ElementBase(48)
            HoverFX(frame)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 16, 0, 0),
                Size = UDim2.new(1, -56, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Name or "Button",
                TextColor3 = Theme.Text,
                TextSize = 15,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -16, 0.5, 0),
                Size = UDim2.new(0, 22, 0, 22),
                Font = Enum.Font.GothamBold,
                Text = "›",
                TextColor3 = Theme.Accent,
                TextSize = 18,
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
                if cfg2.Callback then task.spawn(cfg2.Callback) end
            end)
            return { Frame = frame }
        end

        -- // Toggle (big 48x26 pill)
        function Tab:CreateToggle(cfg2)
            cfg2 = cfg2 or {}
            local state = cfg2.Default or false
            local frame = ElementBase(48)
            HoverFX(frame)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 16, 0, 0),
                Size = UDim2.new(1, -84, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Name or "Toggle",
                TextColor3 = Theme.Text,
                TextSize = 15,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local pill = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -14, 0.5, 0),
                Size = UDim2.new(0, 48, 0, 26),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Parent = frame,
            })
            Circle(pill)
            local knob = New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 3, 0.5, 0),
                Size = UDim2.new(0, 20, 0, 20),
                BackgroundColor3 = Theme.Knob,
                BorderSizePixel = 0,
                Parent = pill,
            })
            Circle(knob)

            local obj = {}
            local function render()
                Tween(pill, { BackgroundColor3 = state and Theme.Accent or Theme.Background })
                Tween(knob, {
                    Position = state and UDim2.new(0, 25, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
                    BackgroundColor3 = state and Theme.Background or Theme.Knob,
                })
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
            if cfg2.Flag then Zenith.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Slider (60px row, fat 22px round knob)
        function Tab:CreateSlider(cfg2)
            cfg2 = cfg2 or {}
            local min = cfg2.Min or 0
            local max = cfg2.Max or 100
            local increment = cfg2.Increment or 1
            local suffix = cfg2.Suffix or ""
            local value = math.clamp(cfg2.Default or min, min, max)

            local frame = ElementBase(60)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 16, 0, 8),
                Size = UDim2.new(1, -130, 0, 18),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Name or "Slider",
                TextColor3 = Theme.Text,
                TextSize = 15,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local valueLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -16, 0, 8),
                Size = UDim2.new(0, 110, 0, 18),
                Font = Enum.Font.GothamBold,
                Text = "",
                TextColor3 = Theme.Accent,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = frame,
            })
            local bar = New("Frame", {
                Position = UDim2.new(0, 16, 0, 38),
                Size = UDim2.new(1, -32, 0, 8),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Parent = frame,
            })
            Circle(bar)
            local fill = New("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                Parent = bar,
            })
            Circle(fill)
            local knob = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(0, 22, 0, 22),
                BackgroundColor3 = Theme.Knob,
                BorderSizePixel = 0,
                ZIndex = 2,
                Parent = bar,
            })
            Circle(knob)
            Stroke(knob, Theme.Accent, 2)

            local decimals = math.max(0, math.ceil(-math.log10(increment)))
            local obj = {}
            local function render()
                local alpha = (max == min) and 0 or (value - min) / (max - min)
                fill.Size = UDim2.new(alpha, 0, 1, 0)
                knob.Position = UDim2.new(alpha, 0, 0.5, 0)
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

            render()
            if cfg2.Flag then Zenith.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Dropdown (expands inline with big 40px option rows)
        function Tab:CreateDropdown(cfg2)
            cfg2 = cfg2 or {}
            local options = cfg2.Options or {}
            local selected = cfg2.Default
            local open = false

            local CLOSED_H = 48
            local OPTION_H = 40

            local frame = ElementBase(CLOSED_H)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 16, 0, 0),
                Size = UDim2.new(0.45, -16, 0, CLOSED_H),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Name or "Dropdown",
                TextColor3 = Theme.Text,
                TextSize = 15,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local selectedLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -42, 0, 0),
                Size = UDim2.new(0.55, -50, 0, CLOSED_H),
                Font = Enum.Font.GothamMedium,
                Text = "",
                TextColor3 = Theme.Muted,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = frame,
            })
            local arrow = New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -14, 0, 0),
                Size = UDim2.new(0, 20, 0, CLOSED_H),
                Font = Enum.Font.GothamBold,
                Text = "▾",
                TextColor3 = Theme.Accent,
                TextSize = 15,
                Parent = frame,
            })
            local optionHolder = New("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, CLOSED_H + 2),
                Size = UDim2.new(1, -20, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = frame,
            }, {
                New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
            })

            local obj = {}
            local optionButtons = {}

            local function openHeight() return CLOSED_H + 2 + #options * (OPTION_H + 4) + 8 end

            local function setOpen(v)
                open = v
                Tween(arrow, { Rotation = open and 180 or 0 })
                Tween(frame, { Size = UDim2.new(1, 0, 0, open and openHeight() or CLOSED_H) }, 0.22)
            end

            local function renderSelection()
                selectedLabel.Text = selected ~= nil and tostring(selected) or "Select…"
                for opt, btn in pairs(optionButtons) do
                    btn.TextColor3 = (opt == selected) and Theme.Accent or Theme.Muted
                    btn.BackgroundColor3 = (opt == selected) and Theme.Surface or Theme.Background
                end
            end

            local function buildOptions()
                for _, btn in pairs(optionButtons) do btn:Destroy() end
                optionButtons = {}
                for _, opt in ipairs(options) do
                    local btn = New("TextButton", {
                        BackgroundColor3 = Theme.Background,
                        Size = UDim2.new(1, 0, 0, OPTION_H),
                        Font = Enum.Font.GothamMedium,
                        Text = tostring(opt),
                        TextColor3 = Theme.Muted,
                        TextSize = 14,
                        AutoButtonColor = false,
                        Parent = optionHolder,
                    })
                    Round(btn, 10)
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
                Size = UDim2.new(1, 0, 0, CLOSED_H),
                Text = "",
                Parent = frame,
            })
            click.MouseButton1Click:Connect(function() setOpen(not open) end)

            buildOptions()
            renderSelection()
            if cfg2.Flag then Zenith.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Input
        function Tab:CreateInput(cfg2)
            cfg2 = cfg2 or {}
            local frame = ElementBase(52)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 16, 0, 0),
                Size = UDim2.new(0.42, -16, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Name or "Input",
                TextColor3 = Theme.Text,
                TextSize = 15,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local boxHolder = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -12, 0.5, 0),
                Size = UDim2.new(0.55, -12, 0, 34),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Parent = frame,
            })
            Round(boxHolder, 10)
            Stroke(boxHolder)
            local box = New("TextBox", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, 0),
                Size = UDim2.new(1, -20, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Default or "",
                PlaceholderText = cfg2.Placeholder or "…",
                PlaceholderColor3 = Theme.Muted,
                TextColor3 = Theme.Text,
                TextSize = 14,
                ClearTextOnFocus = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = boxHolder,
            })
            box.Focused:Connect(function()
                Tween(boxHolder.UIStroke, { Color = Theme.Accent })
            end)
            box.FocusLost:Connect(function(enterPressed)
                Tween(boxHolder.UIStroke, { Color = Theme.Stroke })
                if cfg2.Callback then task.spawn(cfg2.Callback, box.Text, enterPressed) end
            end)
            local obj = {}
            function obj:Set(t)
                box.Text = tostring(t)
                if cfg2.Callback then task.spawn(cfg2.Callback, box.Text, false) end
            end
            function obj:Get() return box.Text end
            if cfg2.Flag then Zenith.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Keybind (PC feature; renders fine on mobile)
        function Tab:CreateKeybind(cfg2)
            cfg2 = cfg2 or {}
            local key = cfg2.Default -- Enum.KeyCode or nil
            local listening = false

            local frame = ElementBase(48)
            HoverFX(frame)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 16, 0, 0),
                Size = UDim2.new(1, -130, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Name or "Keybind",
                TextColor3 = Theme.Text,
                TextSize = 15,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local keyBtn = New("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -12, 0.5, 0),
                Size = UDim2.new(0, 96, 0, 32),
                BackgroundColor3 = Theme.Background,
                Font = Enum.Font.GothamMedium,
                Text = KeyName(key),
                TextColor3 = Theme.Muted,
                TextSize = 13,
                AutoButtonColor = false,
                Parent = frame,
            })
            Round(keyBtn, 10)
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
                    keyBtn.TextColor3 = Theme.Muted
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

            if cfg2.Flag then Zenith.Flags[cfg2.Flag] = obj end
            return obj
        end

        return Tab
    end

    function Window:Minimize() Minimize() end
    function Window:Restore() Restore() end
    function Window:Destroy()
        RootGui:Destroy()
    end

    table.insert(Zenith.Windows, Window)
    return Window
end

function Zenith:Destroy()
    RootGui:Destroy()
end

return Zenith
