--[[
    Phosphor UI Library v1.0
    Retro CRT terminal theme for Roblox executors

    Usage:
        local Phosphor = loadstring(readfile("UI/Phosphor/Phosphor.lua"))()
        local Window = Phosphor:CreateWindow({ Name = "title", ToggleKey = Enum.KeyCode.RightShift })
        local Tab = Window:CreateTab("Main")
        Tab:CreateToggle({ Name = "Auto Farm", Flag = "AutoFarm", Callback = function(v) end })

    Elements: Section, Label, Button, Toggle, Slider, Dropdown, Input, Keybind
    Extras:   Phosphor:Notify, Phosphor.Flags, Phosphor:SaveConfig / LoadConfig, Phosphor:Destroy
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer

local Phosphor = {
    Flags = {},
    Windows = {},
    ToggleKey = Enum.KeyCode.RightShift,
    ConfigFolder = "PhosphorUI",
}

-- // Theme ------------------------------------------------------------------
local Theme = {
    Background = Color3.fromRGB(5, 8, 5),      -- near-black CRT glass
    Green      = Color3.fromRGB(51, 255, 102), -- phosphor green
    Dim        = Color3.fromRGB(30, 140, 60),  -- dim green
    Bright     = Color3.fromRGB(160, 255, 180),-- bright highlight
    Amber      = Color3.fromRGB(255, 180, 60), -- warning amber
}
Phosphor.Theme = Theme

local FONT = Enum.Font.Code
local TEXT_SIZE = 14
local BAR_LEN = 20 -- ASCII slider bar segments

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
    local t = TweenService:Create(inst, TweenInfo.new(time or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function GreenStroke(inst, color)
    return New("UIStroke", {
        Color = color or Theme.Dim,
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
    if not keyCode then return "NONE" end
    return keyCode.Name:upper()
end

local function TextWidth(text)
    return TextService:GetTextSize(text, TEXT_SIZE, FONT, Vector2.new(10000, 100)).X
end

-- // Root gui ---------------------------------------------------------------
local RootGui = New("ScreenGui", {
    Name = "PhosphorUI_" .. HttpService:GenerateGUID(false):sub(1, 8),
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    -- IgnoreGuiInset intentionally left false
})
ProtectGui(RootGui)

-- // Notifications (stacked console lines, bottom-left) ----------------------
local NotifHolder = New("Frame", {
    Name = "Console",
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 12, 1, -12),
    Size = UDim2.new(0, 440, 0, 320),
    BackgroundTransparency = 1,
    Parent = RootGui,
}, {
    New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, 2),
    }),
})

local notifOrder = 0
function Phosphor:Notify(cfg)
    cfg = cfg or {}
    local duration = cfg.Duration or 4
    local stamp = os.date("[%H:%M:%S]")
    local body = cfg.Content or ""
    local text
    if cfg.Title and cfg.Title ~= "" and body ~= "" then
        text = string.format("%s %s :: %s", stamp, tostring(cfg.Title), tostring(body))
    elseif cfg.Title and cfg.Title ~= "" then
        text = string.format("%s %s", stamp, tostring(cfg.Title))
    else
        text = string.format("%s %s", stamp, tostring(body))
    end

    notifOrder = notifOrder + 1
    local line = New("TextLabel", {
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = FONT,
        Text = text,
        TextColor3 = Theme.Green,
        TextSize = TEXT_SIZE,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextTransparency = 1,
        LayoutOrder = notifOrder,
        Parent = NotifHolder,
    })
    New("UIPadding", {
        PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
        PaddingTop = UDim.new(0, 1), PaddingBottom = UDim.new(0, 1),
        Parent = line,
    })
    Tween(line, { TextTransparency = 0 }, 0.1)

    task.delay(duration, function()
        if not line.Parent then return end
        Tween(line, { TextTransparency = 1, BackgroundTransparency = 1 }, 0.25)
        task.wait(0.28)
        line:Destroy()
    end)
end

-- // Config saving ----------------------------------------------------------
local function CanUseFiles()
    return typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"
end

function Phosphor:SaveConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local data = {}
    for flag, obj in pairs(Phosphor.Flags) do
        local v = obj:Get()
        if typeof(v) == "EnumItem" then
            data[flag] = { __keycode = v.Name }
        elseif typeof(v) == "Color3" then
            data[flag] = { __color = { v.R, v.G, v.B } }
        elseif typeof(v) == "boolean" or typeof(v) == "number" or typeof(v) == "string" or typeof(v) == "table" then
            data[flag] = v
        end
    end
    if typeof(isfolder) == "function" and typeof(makefolder) == "function" and not isfolder(Phosphor.ConfigFolder) then
        makefolder(Phosphor.ConfigFolder)
    end
    writefile(Phosphor.ConfigFolder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    return true
end

function Phosphor:LoadConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local path = Phosphor.ConfigFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false, "no config file" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok then return false, "corrupt config" end
    for flag, v in pairs(data) do
        local obj = Phosphor.Flags[flag]
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
local NUMBER_KEYS = {
    Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
    Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six,
    Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
}

function Phosphor:CreateWindow(cfg)
    cfg = cfg or {}
    local windowName = (cfg.Name or "PHOSPHOR"):upper()
    if cfg.ToggleKey then Phosphor.ToggleKey = cfg.ToggleKey end

    local Main = New("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = cfg.Size or UDim2.new(0, 560, 0, 400),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = RootGui,
    })
    GreenStroke(Main, Theme.Green)

    -- Title bar: ┌─[ PHOSPHOR v1.0 ]──────────── [-][X]
    local TitleBar = New("Frame", {
        Name = "TitleBar",
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 26),
        Parent = Main,
    })
    New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0, 0),
        Size = UDim2.new(1, -80, 1, 0),
        Font = FONT,
        Text = "\u{250C}\u{2500}[ " .. windowName .. " v1.0 ]" .. string.rep("\u{2500}", 60),
        TextColor3 = Theme.Green,
        TextSize = TEXT_SIZE,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.None,
        ClipsDescendants = true,
        Parent = TitleBar,
    })
    local HideBtn = New("TextButton", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -36, 0, 0),
        Size = UDim2.new(0, 28, 1, 0),
        Font = FONT,
        Text = "[-]",
        TextColor3 = Theme.Dim,
        TextSize = TEXT_SIZE,
        AutoButtonColor = false,
        Parent = TitleBar,
    })
    local CloseBtn = New("TextButton", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -6, 0, 0),
        Size = UDim2.new(0, 28, 1, 0),
        Font = FONT,
        Text = "[X]",
        TextColor3 = Theme.Dim,
        TextSize = TEXT_SIZE,
        AutoButtonColor = false,
        Parent = TitleBar,
    })
    HideBtn.MouseEnter:Connect(function() HideBtn.TextColor3 = Theme.Bright end)
    HideBtn.MouseLeave:Connect(function() HideBtn.TextColor3 = Theme.Dim end)
    CloseBtn.MouseEnter:Connect(function() CloseBtn.TextColor3 = Theme.Amber end)
    CloseBtn.MouseLeave:Connect(function() CloseBtn.TextColor3 = Theme.Dim end)

    New("Frame", { -- divider under title bar
        BackgroundColor3 = Theme.Dim,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 1),
        Parent = TitleBar,
    })

    MakeDraggable(TitleBar, Main)

    -- Tab row: [1:MAIN] [2:PLAYER] [3:MISC]
    local TabBar = New("Frame", {
        Name = "TabBar",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 27),
        Size = UDim2.new(1, 0, 0, 24),
        Parent = Main,
    }, {
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 4),
        }),
        New("UIPadding", { PaddingLeft = UDim.new(0, 8) }),
    })
    New("Frame", { -- divider under tab row
        BackgroundColor3 = Theme.Dim,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 51),
        Size = UDim2.new(1, 0, 0, 1),
        Parent = Main,
    })

    -- Content region (tab pages live here)
    local Content = New("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 52),
        Size = UDim2.new(1, 0, 1, -52 - 20),
        Parent = Main,
    })

    -- Footer status line
    New("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 8, 1, -2),
        Size = UDim2.new(1, -16, 0, 16),
        Font = FONT,
        Text = "\u{2514}\u{2500} [" .. KeyName(Phosphor.ToggleKey) .. "] toggle \u{2500} [1-9] tabs " .. string.rep("\u{2500}", 40),
        TextColor3 = Theme.Dim,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClipsDescendants = true,
        Parent = Main,
    })

    CloseBtn.MouseButton1Click:Connect(function()
        RootGui:Destroy()
    end)
    HideBtn.MouseButton1Click:Connect(function()
        Main.Visible = false
    end)

    local Window = { Tabs = {}, Main = Main, Gui = RootGui }
    local firstTab = true

    -- Toggle key + number-key tab switching
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Phosphor.ToggleKey then
            Main.Visible = not Main.Visible
            return
        end
        if not Main.Visible then return end
        if UserInputService:GetFocusedTextBox() then return end
        for i, kc in ipairs(NUMBER_KEYS) do
            if input.KeyCode == kc then
                local tab = Window.Tabs[i]
                if tab then tab:_select() end
                return
            end
        end
    end)

    -- // Boot sequence overlay (fast typewriter, < 1s total) -----------------
    local BootOverlay = New("Frame", {
        Name = "Boot",
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        ZIndex = 20,
        Parent = Content,
    })
    local BootLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 6),
        Size = UDim2.new(1, -20, 1, -12),
        Font = FONT,
        Text = "",
        TextColor3 = Theme.Green,
        TextSize = TEXT_SIZE,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 21,
        Parent = BootOverlay,
    })
    task.spawn(function()
        local lines = {
            windowName .. " TERMINAL v1.0",
            "> init display ....... OK",
            "> loading modules .... OK",
            "> system ready.",
        }
        local shown = ""
        for _, lineText in ipairs(lines) do
            for i = 1, #lineText, 5 do -- 5 chars per frame: fast type-in
                if not RootGui.Parent then return end
                BootLabel.Text = shown .. lineText:sub(1, i + 4)
                task.wait()
            end
            shown = shown .. lineText .. "\n"
            BootLabel.Text = shown
        end
        task.wait(0.25)
        if BootOverlay.Parent then BootOverlay:Destroy() end
    end)

    -- // Tab ------------------------------------------------------------------
    function Window:CreateTab(tabName)
        local index = #Window.Tabs + 1
        local upperName = tostring(tabName):upper()

        local TabButton = New("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 0, 20),
            AutomaticSize = Enum.AutomaticSize.X,
            Font = FONT,
            Text = string.format("[%d:%s]", index, upperName),
            TextColor3 = Theme.Dim,
            TextSize = TEXT_SIZE,
            AutoButtonColor = false,
            Parent = TabBar,
        })

        local Page = New("ScrollingFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = Theme.Dim,
            BorderSizePixel = 0,
            Visible = false,
            Parent = Content,
        }, {
            New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 10),
                PaddingRight = UDim.new(0, 10),
                PaddingTop = UDim.new(0, 6),
                PaddingBottom = UDim.new(0, 10),
            }),
        })

        local Tab = { Button = TabButton, Page = Page, Name = tabName }

        function Tab:_select()
            for _, other in ipairs(Window.Tabs) do
                other.Page.Visible = false
                other.Button.TextColor3 = Theme.Dim
            end
            Page.Visible = true
            TabButton.TextColor3 = Theme.Bright
        end
        TabButton.MouseButton1Click:Connect(function() Tab:_select() end)
        table.insert(Window.Tabs, Tab)
        if firstTab then firstTab = false; Tab:_select() end

        -- console line base (transparent row)
        local function LineBase(height)
            return New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, height),
                Parent = Page,
            })
        end

        -- // Section: ──[ TEXT ]──────────
        function Tab:CreateSection(text)
            local lbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 20),
                Font = FONT,
                Text = "\u{2500}\u{2500}[ " .. tostring(text):upper() .. " ]" .. string.rep("\u{2500}", 50),
                TextColor3 = Theme.Dim,
                TextSize = TEXT_SIZE,
                TextXAlignment = Enum.TextXAlignment.Left,
                ClipsDescendants = true,
                Parent = Page,
            })
            local obj = {}
            function obj:Set(t)
                lbl.Text = "\u{2500}\u{2500}[ " .. tostring(t):upper() .. " ]" .. string.rep("\u{2500}", 50)
            end
            return obj
        end

        -- // Label: > text
        function Tab:CreateLabel(text)
            local lbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                Font = FONT,
                Text = "> " .. tostring(text),
                TextColor3 = Theme.Green,
                TextSize = TEXT_SIZE,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = Page,
            })
            local obj = {}
            function obj:Set(t) lbl.Text = "> " .. tostring(t) end
            return obj
        end

        -- // Button: > [ NAME ]
        function Tab:CreateButton(bcfg)
            bcfg = bcfg or {}
            local frame = LineBase(20)
            local lbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Font = FONT,
                Text = "> [ " .. tostring(bcfg.Name or "Button") .. " ]",
                TextColor3 = Theme.Green,
                TextSize = TEXT_SIZE,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                Parent = frame,
            })
            click.MouseEnter:Connect(function() lbl.TextColor3 = Theme.Bright end)
            click.MouseLeave:Connect(function() lbl.TextColor3 = Theme.Green end)
            click.MouseButton1Click:Connect(function()
                lbl.TextColor3 = Theme.Amber
                task.delay(0.12, function()
                    if lbl.Parent then lbl.TextColor3 = Theme.Green end
                end)
                if bcfg.Callback then task.spawn(bcfg.Callback) end
            end)
            local obj = {}
            function obj:Set(t) lbl.Text = "> [ " .. tostring(t) .. " ]" end
            return obj
        end

        -- // Toggle: > Name          [ON ] / [OFF]
        function Tab:CreateToggle(tcfg)
            tcfg = tcfg or {}
            local state = tcfg.Default or false

            local frame = LineBase(20)
            local nameLbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -60, 1, 0),
                Font = FONT,
                Text = "> " .. tostring(tcfg.Name or "Toggle"),
                TextColor3 = Theme.Green,
                TextSize = TEXT_SIZE,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = frame,
            })
            local stateLbl = New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, 0, 0, 0),
                Size = UDim2.new(0, 52, 1, 0),
                Font = FONT,
                Text = "[OFF]",
                TextColor3 = Theme.Dim,
                TextSize = TEXT_SIZE,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = frame,
            })

            local obj = {}
            local function render()
                if state then
                    stateLbl.Text = "[ON ]"
                    stateLbl.TextColor3 = Theme.Bright
                    nameLbl.TextColor3 = Theme.Green
                else
                    stateLbl.Text = "[OFF]"
                    stateLbl.TextColor3 = Theme.Dim
                    nameLbl.TextColor3 = Theme.Green
                end
            end
            function obj:Set(v)
                v = v and true or false
                if v == state then render() return end
                state = v
                render()
                if tcfg.Callback then task.spawn(tcfg.Callback, state) end
            end
            function obj:Get() return state end

            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                Parent = frame,
            })
            click.MouseEnter:Connect(function() nameLbl.TextColor3 = Theme.Bright end)
            click.MouseLeave:Connect(function() nameLbl.TextColor3 = Theme.Green end)
            click.MouseButton1Click:Connect(function() obj:Set(not state) end)

            render()
            if state and tcfg.Callback then task.spawn(tcfg.Callback, state) end
            if tcfg.Flag then Phosphor.Flags[tcfg.Flag] = obj end
            return obj
        end

        -- // Slider: > Name: 50 studs
        --            [##########----------]
        function Tab:CreateSlider(scfg)
            scfg = scfg or {}
            local min = scfg.Min or 0
            local max = scfg.Max or 100
            local increment = scfg.Increment or 1
            local suffix = scfg.Suffix or ""
            local value = math.clamp(scfg.Default or min, min, max)
            local decimals = math.max(0, math.ceil(-math.log10(increment)))

            local frame = LineBase(38)
            local nameLbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                Font = FONT,
                Text = "",
                TextColor3 = Theme.Green,
                TextSize = TEXT_SIZE,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = frame,
            })
            -- ASCII bar; the invisible hitbox frame is the real drag surface
            local barWidth = TextWidth("[" .. string.rep("#", BAR_LEN) .. "]")
            local hitbox = New("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 14, 0, 18),
                Size = UDim2.new(0, barWidth, 0, 20),
                Parent = frame,
            })
            local barLbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Font = FONT,
                Text = "",
                TextColor3 = Theme.Green,
                TextSize = TEXT_SIZE,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = hitbox,
            })

            local obj = {}
            local function render()
                local alpha = (max == min) and 0 or (value - min) / (max - min)
                local filled = math.floor(alpha * BAR_LEN + 0.5)
                barLbl.Text = "[" .. string.rep("#", filled) .. string.rep("-", BAR_LEN - filled) .. "]"
                local valText = string.format("%." .. decimals .. "f", value)
                nameLbl.Text = "> " .. tostring(scfg.Name or "Slider") .. ": " .. valText
                    .. (suffix ~= "" and (" " .. suffix) or "")
            end
            function obj:Set(v)
                v = math.clamp(math.floor(v / increment + 0.5) * increment, min, max)
                if v == value then render() return end
                value = v
                render()
                if scfg.Callback then task.spawn(scfg.Callback, value) end
            end
            function obj:Get() return value end

            local dragging = false
            local function updateFromInput(input)
                local alpha = math.clamp((input.Position.X - hitbox.AbsolutePosition.X) / hitbox.AbsoluteSize.X, 0, 1)
                obj:Set(min + (max - min) * alpha)
            end
            hitbox.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    barLbl.TextColor3 = Theme.Bright
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
                    if dragging then
                        dragging = false
                        barLbl.TextColor3 = Theme.Green
                    end
                end
            end)

            render()
            if scfg.Flag then Phosphor.Flags[scfg.Flag] = obj end
            return obj
        end

        -- // Dropdown: > Name: <selected v>   (options expand inline)
        function Tab:CreateDropdown(dcfg)
            dcfg = dcfg or {}
            local options = dcfg.Options or {}
            local selected = dcfg.Default
            local open = false

            local frame = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 20),
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = Page,
            })
            local headLbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 20),
                Font = FONT,
                Text = "",
                TextColor3 = Theme.Green,
                TextSize = TEXT_SIZE,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = frame,
            })
            local headClick = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 20),
                Text = "",
                Parent = frame,
            })
            local optionHolder = New("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, 20),
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Visible = false,
                Parent = frame,
            }, {
                New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
            })

            local obj = {}
            local optionButtons = {}

            local function renderHead()
                local arrow = open and "^" or "v"
                headLbl.Text = "> " .. tostring(dcfg.Name or "Dropdown") .. ": <"
                    .. (selected ~= nil and tostring(selected) or "none") .. " " .. arrow .. ">"
            end
            local function renderOptions()
                for opt, btn in pairs(optionButtons) do
                    if opt == selected then
                        btn.Text = "    [*] " .. tostring(opt)
                        btn.TextColor3 = Theme.Bright
                    else
                        btn.Text = "    [ ] " .. tostring(opt)
                        btn.TextColor3 = Theme.Dim
                    end
                end
            end
            local function setOpen(v)
                open = v
                optionHolder.Visible = open
                renderHead()
            end

            local function buildOptions()
                for _, btn in pairs(optionButtons) do btn:Destroy() end
                optionButtons = {}
                for _, opt in ipairs(options) do
                    local btn = New("TextButton", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 18),
                        Font = FONT,
                        Text = "    [ ] " .. tostring(opt),
                        TextColor3 = Theme.Dim,
                        TextSize = TEXT_SIZE,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        AutoButtonColor = false,
                        Parent = optionHolder,
                    })
                    btn.MouseEnter:Connect(function()
                        if opt ~= selected then btn.TextColor3 = Theme.Green end
                    end)
                    btn.MouseLeave:Connect(function()
                        if opt ~= selected then btn.TextColor3 = Theme.Dim end
                    end)
                    btn.MouseButton1Click:Connect(function()
                        obj:Set(opt)
                        setOpen(false)
                    end)
                    optionButtons[opt] = btn
                end
            end

            function obj:Set(opt)
                if selected == opt then renderHead() renderOptions() return end
                selected = opt
                renderHead()
                renderOptions()
                if dcfg.Callback then task.spawn(dcfg.Callback, selected) end
            end
            function obj:Get() return selected end
            function obj:Refresh(newOptions, keepSelection)
                options = newOptions or {}
                if not keepSelection then selected = nil end
                buildOptions()
                renderHead()
                renderOptions()
            end

            headClick.MouseEnter:Connect(function() headLbl.TextColor3 = Theme.Bright end)
            headClick.MouseLeave:Connect(function() headLbl.TextColor3 = Theme.Green end)
            headClick.MouseButton1Click:Connect(function() setOpen(not open) end)

            buildOptions()
            renderHead()
            renderOptions()
            if dcfg.Flag then Phosphor.Flags[dcfg.Flag] = obj end
            return obj
        end

        -- // Input: > Name: value_   (blinking cursor when not focused)
        function Tab:CreateInput(icfg)
            icfg = icfg or {}
            local frame = LineBase(20)
            local promptText = "> " .. tostring(icfg.Name or "Input") .. ": "
            local promptWidth = TextWidth(promptText)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(0, promptWidth, 1, 0),
                Font = FONT,
                Text = promptText,
                TextColor3 = Theme.Green,
                TextSize = TEXT_SIZE,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local boxHolder = New("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, promptWidth + 2, 0, 0),
                Size = UDim2.new(1, -(promptWidth + 4), 1, 0),
                Parent = frame,
            })
            local box = New("TextBox", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -10, 1, 0),
                Font = FONT,
                Text = icfg.Default or "",
                PlaceholderText = icfg.Placeholder or "",
                PlaceholderColor3 = Theme.Dim,
                TextColor3 = Theme.Bright,
                TextSize = TEXT_SIZE,
                ClearTextOnFocus = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = boxHolder,
            })
            local cursor = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(0, 10, 1, 0),
                Font = FONT,
                Text = "_",
                TextColor3 = Theme.Green,
                TextSize = TEXT_SIZE,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = boxHolder,
            })
            local function placeCursor()
                cursor.Position = UDim2.new(0, math.min(TextWidth(box.Text) + 1, boxHolder.AbsoluteSize.X - 10), 0, 0)
            end
            box:GetPropertyChangedSignal("Text"):Connect(placeCursor)
            task.defer(placeCursor)

            -- blinking cursor loop; terminates when the ScreenGui is destroyed
            task.spawn(function()
                local shown = true
                while RootGui.Parent and cursor.Parent do
                    if box:IsFocused() then
                        cursor.Visible = false
                    else
                        shown = not shown
                        cursor.Visible = shown
                    end
                    task.wait(0.5)
                end
            end)

            box.FocusLost:Connect(function(enterPressed)
                if icfg.Callback then task.spawn(icfg.Callback, box.Text, enterPressed) end
            end)

            local obj = {}
            function obj:Set(t)
                box.Text = tostring(t)
                if icfg.Callback then task.spawn(icfg.Callback, box.Text, false) end
            end
            function obj:Get() return box.Text end
            if icfg.Flag then Phosphor.Flags[icfg.Flag] = obj end
            return obj
        end

        -- // Keybind: > Name          [RSHIFT]
        function Tab:CreateKeybind(kcfg)
            kcfg = kcfg or {}
            local key = kcfg.Default -- Enum.KeyCode or nil
            local listening = false

            local frame = LineBase(20)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -110, 1, 0),
                Font = FONT,
                Text = "> " .. tostring(kcfg.Name or "Keybind"),
                TextColor3 = Theme.Green,
                TextSize = TEXT_SIZE,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = frame,
            })
            local keyBtn = New("TextButton", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, 0, 0, 0),
                Size = UDim2.new(0, 104, 1, 0),
                Font = FONT,
                Text = "[" .. KeyName(key) .. "]",
                TextColor3 = Theme.Dim,
                TextSize = TEXT_SIZE,
                TextXAlignment = Enum.TextXAlignment.Right,
                AutoButtonColor = false,
                Parent = frame,
            })

            local obj = {}
            function obj:Set(newKey)
                key = newKey
                keyBtn.Text = "[" .. KeyName(key) .. "]"
                keyBtn.TextColor3 = Theme.Dim
            end
            function obj:Get() return key end

            keyBtn.MouseButton1Click:Connect(function()
                listening = true
                keyBtn.Text = "[...]"
                keyBtn.TextColor3 = Theme.Amber
            end)

            UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    listening = false
                    if input.KeyCode == Enum.KeyCode.Escape then
                        obj:Set(nil)
                    else
                        obj:Set(input.KeyCode)
                    end
                    return
                end
                if not gameProcessed and key and input.KeyCode == key then
                    if kcfg.Callback then task.spawn(kcfg.Callback, key) end
                end
            end)

            if kcfg.Flag then Phosphor.Flags[kcfg.Flag] = obj end
            return obj
        end

        return Tab
    end

    function Window:Destroy()
        RootGui:Destroy()
    end

    table.insert(Phosphor.Windows, Window)
    return Window
end

function Phosphor:Destroy()
    RootGui:Destroy()
end

return Phosphor
