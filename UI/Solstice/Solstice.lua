--[[
    Solstice UI Library v1.0
    Clean light "paper" theme UI library for Roblox executors.
    Almost every executor UI is dark — Solstice is warm paper + ink + coral.

    Usage:
        local Solstice = loadstring(readfile("UI/Solstice/Solstice.lua"))()
        local Window = Solstice:CreateWindow({ Name = "My Hub", ToggleKey = Enum.KeyCode.RightShift })
        local Tab = Window:CreateTab("Main")
        Tab:CreateSection("Farming")
        Tab:CreateToggle({ Name = "Auto Farm", Flag = "AutoFarm", Callback = function(v) end })

    Elements: Section (card), Label, Button, Toggle, Slider, Dropdown, Input, Keybind
    Extras:   Solstice:Notify, Solstice.Flags, Solstice:SaveConfig / LoadConfig, Solstice:Destroy
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer

local Solstice = {
    Flags = {},
    Windows = {},
    ToggleKey = Enum.KeyCode.RightShift,
    ConfigFolder = "SolsticeUI",
}

-- // Theme ------------------------------------------------------------------
local Theme = {
    Paper      = Color3.fromRGB(245, 244, 239), -- window background
    Card       = Color3.fromRGB(255, 255, 255), -- section cards / header
    Ink        = Color3.fromRGB(28, 28, 26),    -- primary text
    Muted      = Color3.fromRGB(120, 118, 110), -- secondary text
    Hairline   = Color3.fromRGB(225, 223, 215), -- borders
    Accent     = Color3.fromRGB(216, 90, 48),   -- warm coral
    AccentSoft = Color3.fromRGB(250, 236, 231), -- coral tint fill
    TrackOff   = Color3.fromRGB(219, 217, 209), -- toggle pill off / slider track
    HoverTint  = Color3.fromRGB(249, 248, 244), -- row hover
}
Solstice.Theme = Theme

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
    local t = TweenService:Create(inst, TweenInfo.new(time or 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function Round(inst, radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius or 6), Parent = inst })
end

local function Hairline(inst, color, thickness)
    return New("UIStroke", {
        Color = color or Theme.Hairline,
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
    Name = "SolsticeUI_" .. HttpService:GenerateGUID(false):sub(1, 8),
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    -- IgnoreGuiInset intentionally left false
})
ProtectGui(RootGui)

-- // Notifications (white toasts, top-center, sliding down) ------------------
local NotifHolder = New("Frame", {
    Name = "Notifications",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 10),
    Size = UDim2.new(0, 320, 1, -20),
    BackgroundTransparency = 1,
    Parent = RootGui,
}, {
    New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        Padding = UDim.new(0, 8),
    }),
})

local notifOrder = 0

function Solstice:Notify(cfg)
    cfg = cfg or {}
    local duration = cfg.Duration or 4
    local titleText = cfg.Title or "Notification"
    local bodyText = cfg.Content or ""

    local innerWidth = 320 - 32 -- toast width minus horizontal padding
    local bodyHeight = 0
    if bodyText ~= "" then
        local ok, size = pcall(function()
            return TextService:GetTextSize(bodyText, 13, Enum.Font.Gotham, Vector2.new(innerWidth, 1000))
        end)
        bodyHeight = (ok and size.Y or 16) + 4
    end
    local toastHeight = 12 + 18 + bodyHeight + 12

    notifOrder += 1
    -- wrapper reserves space in the stack; inner card slides down into it
    local wrapper = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, toastHeight),
        ClipsDescendants = true,
        LayoutOrder = notifOrder,
        Parent = NotifHolder,
    })
    local card = New("Frame", {
        BackgroundColor3 = Theme.Card,
        Position = UDim2.new(0, 0, 0, -(toastHeight + 4)),
        Size = UDim2.new(1, 0, 0, toastHeight),
        BorderSizePixel = 0,
        Parent = wrapper,
    })
    Round(card, 8)
    Hairline(card)

    New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 10),
        Size = UDim2.new(1, -32, 0, 18),
        Font = Enum.Font.GothamBold,
        Text = titleText,
        TextColor3 = Theme.Accent,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })
    if bodyText ~= "" then
        New("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 16, 0, 32),
            Size = UDim2.new(1, -32, 0, bodyHeight - 4),
            Font = Enum.Font.Gotham,
            Text = bodyText,
            TextColor3 = Theme.Muted,
            TextSize = 13,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Parent = card,
        })
    end

    Tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.28)

    task.delay(duration, function()
        if not wrapper.Parent then return end
        Tween(card, { Position = UDim2.new(0, 0, 0, -(toastHeight + 4)) }, 0.24)
        task.wait(0.26)
        wrapper:Destroy()
    end)
end

-- // Config saving ------------------------------------------------------------
local function CanUseFiles()
    return typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"
end

function Solstice:SaveConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local data = {}
    for flag, obj in pairs(Solstice.Flags) do
        local v = obj:Get()
        if typeof(v) == "EnumItem" then
            data[flag] = { __keycode = v.Name }
        elseif typeof(v) == "Color3" then
            data[flag] = { __color = { v.R, v.G, v.B } }
        elseif v ~= nil then
            data[flag] = v
        end
    end
    if typeof(isfolder) == "function" and typeof(makefolder) == "function" and not isfolder(Solstice.ConfigFolder) then
        makefolder(Solstice.ConfigFolder)
    end
    writefile(Solstice.ConfigFolder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    return true
end

function Solstice:LoadConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local path = Solstice.ConfigFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false, "no config file" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok then return false, "corrupt config" end
    for flag, v in pairs(data) do
        local obj = Solstice.Flags[flag]
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

-- // Window -------------------------------------------------------------------
function Solstice:CreateWindow(cfg)
    cfg = cfg or {}
    local windowName = cfg.Name or "Solstice"
    if cfg.ToggleKey then Solstice.ToggleKey = cfg.ToggleKey end

    local Main = New("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = cfg.Size or UDim2.new(0, 600, 0, 400),
        BackgroundColor3 = Theme.Paper,
        BorderSizePixel = 0,
        Parent = RootGui,
    })
    Round(Main, 8)
    Hairline(Main)

    -- Header bar (white): title + tab pills, doubles as drag handle
    local Header = New("Frame", {
        Name = "Header",
        BackgroundColor3 = Theme.Card,
        Size = UDim2.new(1, 0, 0, 52),
        BorderSizePixel = 0,
        Parent = Main,
    })
    Round(Header, 8)
    New("Frame", { -- square off bottom corners of header
        BackgroundColor3 = Theme.Card,
        Position = UDim2.new(0, 0, 1, -8),
        Size = UDim2.new(1, 0, 0, 8),
        BorderSizePixel = 0,
        Parent = Header,
    })
    New("Frame", { -- hairline under header
        BackgroundColor3 = Theme.Hairline,
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 1),
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = Header,
    })

    local TitleLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 18, 0, 0),
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Font = Enum.Font.GothamBold,
        Text = windowName,
        TextColor3 = Theme.Ink,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Header,
    })

    -- close button
    local CloseBtn = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.new(0, 26, 0, 26),
        BackgroundColor3 = Theme.Paper,
        Font = Enum.Font.GothamBold,
        Text = "×",
        TextColor3 = Theme.Muted,
        TextSize = 16,
        AutoButtonColor = false,
        Parent = Header,
    })
    Round(CloseBtn, 13)
    Hairline(CloseBtn)
    CloseBtn.MouseEnter:Connect(function()
        Tween(CloseBtn, { BackgroundColor3 = Theme.AccentSoft, TextColor3 = Theme.Accent })
    end)
    CloseBtn.MouseLeave:Connect(function()
        Tween(CloseBtn, { BackgroundColor3 = Theme.Paper, TextColor3 = Theme.Muted })
    end)
    CloseBtn.MouseButton1Click:Connect(function()
        RootGui:Destroy()
    end)

    -- tab pill row (in the header, after the title)
    local PillRow = New("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -50, 0, 0),
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Parent = Header,
    }, {
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 6),
        }),
    })

    MakeDraggable(Header, Main)
    MakeDraggable(TitleLabel, Main)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Solstice.ToggleKey then
            Main.Visible = not Main.Visible
        end
    end)

    local Content = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 53),
        Size = UDim2.new(1, 0, 1, -53),
        Parent = Main,
    })

    local Window = { Tabs = {}, Main = Main, Gui = RootGui }
    local firstTab = true

    -- // Tab -------------------------------------------------------------------
    function Window:CreateTab(tabName)
        local Pill = New("TextButton", {
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 0, 28),
            AutomaticSize = Enum.AutomaticSize.X,
            Font = Enum.Font.GothamMedium,
            Text = tabName,
            TextColor3 = Theme.Muted,
            TextSize = 13,
            AutoButtonColor = false,
            Parent = PillRow,
        })
        Round(Pill, 14)
        New("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = Pill })

        local Page = New("ScrollingFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Hairline,
            BorderSizePixel = 0,
            Visible = false,
            Parent = Content,
        }, {
            New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 14),
                PaddingRight = UDim.new(0, 14),
                PaddingTop = UDim.new(0, 12),
                PaddingBottom = UDim.new(0, 14),
            }),
        })

        local Tab = { Button = Pill, Page = Page, Name = tabName }

        local function Select()
            for _, other in ipairs(Window.Tabs) do
                other.Page.Visible = false
                Tween(other.Button, { BackgroundTransparency = 1, TextColor3 = Theme.Muted })
            end
            Page.Visible = true
            Tween(Pill, { BackgroundTransparency = 0, TextColor3 = Color3.fromRGB(255, 255, 255) })
        end
        Pill.MouseButton1Click:Connect(Select)
        table.insert(Window.Tabs, Tab)
        if firstTab then firstTab = false; Select() end

        -- // Card system (SIGNATURE) -------------------------------------------
        -- CreateSection makes a white card with a coral left-edge accent bar;
        -- elements created afterwards nest inside the current card.
        local currentHolder = nil -- the element holder frame of the active card

        local function MakeCard(sectionTitle)
            local card = New("Frame", {
                BackgroundColor3 = Theme.Card,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BorderSizePixel = 0,
                Parent = Page,
            })
            Round(card, 6)
            Hairline(card)

            -- coral left-edge accent bar (inset past the rounded corners)
            local accent = New("Frame", {
                BackgroundColor3 = Theme.Accent,
                Position = UDim2.new(0, 0, 0, 8),
                Size = UDim2.new(0, 3, 1, -16),
                BorderSizePixel = 0,
                Parent = card,
            })
            Round(accent, 2)

            local holder = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = card,
            }, {
                New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
                New("UIPadding", {
                    PaddingLeft = UDim.new(0, 16),
                    PaddingRight = UDim.new(0, 12),
                    PaddingTop = UDim.new(0, 12),
                    PaddingBottom = UDim.new(0, 12),
                }),
            })

            local titleLabel = nil
            if sectionTitle then
                titleLabel = New("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 18),
                    Font = Enum.Font.GothamBold,
                    Text = sectionTitle,
                    TextColor3 = Theme.Ink,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    LayoutOrder = 0,
                    Parent = holder,
                })
            end
            return holder, titleLabel
        end

        -- elements created before any section land in an implicit default card
        local function EnsureHolder()
            if not currentHolder then
                currentHolder = MakeCard(nil)
            end
            return currentHolder
        end

        -- transparent element row inside the current card
        local function Row(height, hover)
            local row = New("Frame", {
                BackgroundColor3 = Theme.HoverTint,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, height),
                Parent = EnsureHolder(),
            })
            Round(row, 6)
            if hover then
                row.MouseEnter:Connect(function() Tween(row, { BackgroundTransparency = 0 }) end)
                row.MouseLeave:Connect(function() Tween(row, { BackgroundTransparency = 1 }) end)
            end
            return row
        end

        -- // Section
        function Tab:CreateSection(text)
            local holder, titleLabel = MakeCard(text or "Section")
            currentHolder = holder
            local obj = {}
            function obj:Set(t)
                if titleLabel then titleLabel.Text = t end
            end
            return obj
        end

        -- // Label
        function Tab:CreateLabel(text)
            local row = Row(18, false)
            local lbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Font = Enum.Font.Gotham,
                Text = text or "",
                TextColor3 = Theme.Muted,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })
            local obj = {}
            function obj:Set(t) lbl.Text = t end
            return obj
        end

        -- // Button
        function Tab:CreateButton(cfg2)
            cfg2 = cfg2 or {}
            local row = Row(32, false)
            row.BackgroundColor3 = Theme.Paper
            row.BackgroundTransparency = 0
            Hairline(row)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -40, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Name or "Button",
                TextColor3 = Theme.Ink,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })
            New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -12, 0, 0),
                Size = UDim2.new(0, 16, 1, 0),
                Font = Enum.Font.GothamBold,
                Text = "→",
                TextColor3 = Theme.Accent,
                TextSize = 13,
                Parent = row,
            })
            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                Parent = row,
            })
            click.MouseEnter:Connect(function() Tween(row, { BackgroundColor3 = Theme.AccentSoft }) end)
            click.MouseLeave:Connect(function() Tween(row, { BackgroundColor3 = Theme.Paper }) end)
            click.MouseButton1Click:Connect(function()
                Tween(row, { BackgroundColor3 = Theme.Accent }, 0.06)
                task.delay(0.09, function() Tween(row, { BackgroundColor3 = Theme.Paper }, 0.2) end)
                if cfg2.Callback then task.spawn(cfg2.Callback) end
            end)
            return { Frame = row }
        end

        -- // Toggle (iOS-style pill: gray -> coral)
        function Tab:CreateToggle(cfg2)
            cfg2 = cfg2 or {}
            local state = cfg2.Default or false
            local row = Row(28, true)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 6, 0, 0),
                Size = UDim2.new(1, -66, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Name or "Toggle",
                TextColor3 = Theme.Ink,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })
            local pill = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -6, 0.5, 0),
                Size = UDim2.new(0, 42, 0, 24),
                BackgroundColor3 = Theme.TrackOff,
                BorderSizePixel = 0,
                Parent = row,
            })
            Round(pill, 12)
            local knob = New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 3, 0.5, 0),
                Size = UDim2.new(0, 18, 0, 18),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                Parent = pill,
            })
            Round(knob, 9)
            Hairline(knob, Theme.Hairline)

            local obj = {}
            local function render()
                Tween(pill, { BackgroundColor3 = state and Theme.Accent or Theme.TrackOff })
                Tween(knob, { Position = state and UDim2.new(0, 21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
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
                Parent = row,
            })
            click.MouseButton1Click:Connect(function() obj:Set(not state) end)

            render()
            if state and cfg2.Callback then task.spawn(cfg2.Callback, state) end
            if cfg2.Flag then Solstice.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Slider (coral fill, value chip on the right)
        function Tab:CreateSlider(cfg2)
            cfg2 = cfg2 or {}
            local min = cfg2.Min or 0
            local max = cfg2.Max or 100
            local increment = cfg2.Increment or 1
            local suffix = cfg2.Suffix or ""
            local value = math.clamp(cfg2.Default or min, min, max)

            local row = Row(46, false)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 6, 0, 2),
                Size = UDim2.new(1, -100, 0, 18),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Name or "Slider",
                TextColor3 = Theme.Ink,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })
            local chip = New("Frame", {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -6, 0, 1),
                Size = UDim2.new(0, 0, 0, 20),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = Theme.AccentSoft,
                BorderSizePixel = 0,
                Parent = row,
            })
            Round(chip, 10)
            local chipLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 0, 1, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                Font = Enum.Font.GothamMedium,
                Text = "",
                TextColor3 = Theme.Accent,
                TextSize = 11,
                Parent = chip,
            })
            New("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), Parent = chipLabel })

            local bar = New("Frame", {
                Position = UDim2.new(0, 6, 0, 32),
                Size = UDim2.new(1, -12, 0, 6),
                BackgroundColor3 = Theme.TrackOff,
                BorderSizePixel = 0,
                Parent = row,
            })
            Round(bar, 3)
            local fill = New("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                Parent = bar,
            })
            Round(fill, 3)
            local knob = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(0, 14, 0, 14),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                ZIndex = 2,
                Parent = bar,
            })
            Round(knob, 7)
            Hairline(knob, Theme.Accent, 1)

            local decimals = math.max(0, math.ceil(-math.log10(increment)))
            local obj = {}
            local function render()
                local alpha = (max == min) and 0 or (value - min) / (max - min)
                fill.Size = UDim2.new(alpha, 0, 1, 0)
                knob.Position = UDim2.new(alpha, 0, 0.5, 0)
                chipLabel.Text = string.format("%." .. decimals .. "f", value) .. (suffix ~= "" and (" " .. suffix) or "")
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
            bar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    updateFromInput(input)
                end
            end)
            row.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    -- allow grabbing slightly off the thin bar
                    if math.abs(input.Position.Y - (bar.AbsolutePosition.Y + bar.AbsoluteSize.Y / 2)) <= 12 then
                        dragging = true
                        updateFromInput(input)
                    end
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
            if cfg2.Flag then Solstice.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Dropdown (expands inside the card)
        function Tab:CreateDropdown(cfg2)
            cfg2 = cfg2 or {}
            local options = cfg2.Options or {}
            local selected = cfg2.Default
            local open = false

            local CLOSED = 32
            local row = Row(CLOSED, false)
            row.ClipsDescendants = true
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 6, 0, 0),
                Size = UDim2.new(0.5, -6, 0, CLOSED),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Name or "Dropdown",
                TextColor3 = Theme.Ink,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })
            local chip = New("Frame", {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -6, 0, 4),
                Size = UDim2.new(0, 0, 0, 24),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = Theme.Paper,
                BorderSizePixel = 0,
                Parent = row,
            })
            Round(chip, 5)
            Hairline(chip)
            local selectedLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 0, 1, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                Font = Enum.Font.Gotham,
                Text = "",
                TextColor3 = Theme.Muted,
                TextSize = 12,
                Parent = chip,
            })
            New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 24), Parent = selectedLabel })
            local arrow = New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -7, 0, 0),
                Size = UDim2.new(0, 12, 1, 0),
                Font = Enum.Font.GothamBold,
                Text = "▾",
                TextColor3 = Theme.Accent,
                TextSize = 12,
                Parent = chip,
            })
            local optionHolder = New("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, CLOSED + 4),
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = row,
            }, {
                New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }),
            })

            local obj = {}
            local optionButtons = {}

            local function openHeight()
                return CLOSED + 4 + #options * 26 + math.max(0, #options - 1) * 3 + 6
            end
            local function setOpen(v)
                open = v
                Tween(arrow, { Rotation = open and 180 or 0 })
                Tween(row, { Size = UDim2.new(1, 0, 0, open and openHeight() or CLOSED) }, 0.2)
            end

            local function renderSelection()
                selectedLabel.Text = selected ~= nil and tostring(selected) or "Select…"
                for opt, btn in pairs(optionButtons) do
                    local active = (opt == selected)
                    btn.TextColor3 = active and Theme.Accent or Theme.Muted
                    btn.BackgroundColor3 = active and Theme.AccentSoft or Theme.Paper
                end
            end

            local function buildOptions()
                for _, btn in pairs(optionButtons) do btn:Destroy() end
                optionButtons = {}
                for _, opt in ipairs(options) do
                    local btn = New("TextButton", {
                        BackgroundColor3 = Theme.Paper,
                        Size = UDim2.new(1, 0, 0, 26),
                        Font = Enum.Font.Gotham,
                        Text = "  " .. tostring(opt),
                        TextColor3 = Theme.Muted,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        AutoButtonColor = false,
                        Parent = optionHolder,
                    })
                    Round(btn, 5)
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
            function obj:Refresh(newOptions)
                options = newOptions or {}
                local stillThere = false
                for _, opt in ipairs(options) do
                    if opt == selected then stillThere = true break end
                end
                if not stillThere then selected = nil end
                buildOptions()
                renderSelection()
                if open then setOpen(true) end
            end

            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, CLOSED),
                Text = "",
                Parent = row,
            })
            click.MouseButton1Click:Connect(function() setOpen(not open) end)

            buildOptions()
            renderSelection()
            if cfg2.Flag then Solstice.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Input
        function Tab:CreateInput(cfg2)
            cfg2 = cfg2 or {}
            local row = Row(32, false)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 6, 0, 0),
                Size = UDim2.new(0.5, -6, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Name or "Input",
                TextColor3 = Theme.Ink,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })
            local boxHolder = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -6, 0.5, 0),
                Size = UDim2.new(0, 170, 0, 26),
                BackgroundColor3 = Theme.Paper,
                BorderSizePixel = 0,
                Parent = row,
            })
            Round(boxHolder, 5)
            local holderStroke = Hairline(boxHolder)
            local box = New("TextBox", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 9, 0, 0),
                Size = UDim2.new(1, -18, 1, 0),
                Font = Enum.Font.Gotham,
                Text = cfg2.Default or "",
                PlaceholderText = cfg2.Placeholder or "…",
                PlaceholderColor3 = Theme.Muted,
                TextColor3 = Theme.Ink,
                TextSize = 12,
                ClearTextOnFocus = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = boxHolder,
            })
            box.Focused:Connect(function()
                Tween(holderStroke, { Color = Theme.Accent })
            end)
            box.FocusLost:Connect(function(enterPressed)
                Tween(holderStroke, { Color = Theme.Hairline })
                if cfg2.Callback then task.spawn(cfg2.Callback, box.Text, enterPressed) end
            end)
            local obj = {}
            function obj:Set(t)
                box.Text = tostring(t)
                if cfg2.Callback then task.spawn(cfg2.Callback, box.Text, false) end
            end
            function obj:Get() return box.Text end
            if cfg2.Flag then Solstice.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Keybind (bordered key-cap chip; Escape clears while listening)
        function Tab:CreateKeybind(cfg2)
            cfg2 = cfg2 or {}
            local key = cfg2.Default -- Enum.KeyCode or nil
            local listening = false

            local row = Row(30, true)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 6, 0, 0),
                Size = UDim2.new(1, -110, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Name or "Keybind",
                TextColor3 = Theme.Ink,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })
            local keyCap = New("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -6, 0.5, 0),
                Size = UDim2.new(0, 0, 0, 24),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                Font = Enum.Font.GothamMedium,
                Text = KeyName(key),
                TextColor3 = Theme.Ink,
                TextSize = 12,
                AutoButtonColor = false,
                Parent = row,
            })
            Round(keyCap, 5)
            local capStroke = Hairline(keyCap)
            New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = keyCap })
            New("Frame", { -- key-cap bottom edge
                BackgroundColor3 = Theme.Hairline,
                Position = UDim2.new(0, 3, 1, -2),
                Size = UDim2.new(1, -6, 0, 2),
                BorderSizePixel = 0,
                Parent = keyCap,
            })

            local obj = {}
            function obj:Set(newKey)
                key = newKey
                keyCap.Text = KeyName(key)
            end
            function obj:Get() return key end

            keyCap.MouseButton1Click:Connect(function()
                listening = true
                keyCap.Text = "…"
                keyCap.TextColor3 = Theme.Accent
                Tween(capStroke, { Color = Theme.Accent })
            end)

            UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    listening = false
                    keyCap.TextColor3 = Theme.Ink
                    Tween(capStroke, { Color = Theme.Hairline })
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

            if cfg2.Flag then Solstice.Flags[cfg2.Flag] = obj end
            return obj
        end

        return Tab
    end

    function Window:Destroy()
        RootGui:Destroy()
    end

    table.insert(Solstice.Windows, Window)
    return Window
end

function Solstice:Destroy()
    RootGui:Destroy()
end

return Solstice
