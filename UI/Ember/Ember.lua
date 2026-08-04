--[[
    Ember UI Library v1.0
    Warm dashboard TILE-GRID library for Roblox executors.
    Every element is a card/tile laid out two per row.

    Usage:
        local Ember = loadstring(readfile("UI/Ember/Ember.lua"))()
        local Window = Ember:CreateWindow({ Name = "My Hub", ToggleKey = Enum.KeyCode.RightShift })
        local Tab = Window:CreateTab("Main")
        Tab:CreateToggle({ Name = "Auto Farm", Flag = "AutoFarm", Callback = function(v) end })

    Elements: Section, Label, Button, Toggle, Slider, Dropdown, Input, Keybind
    Extras:   Ember:Notify, Ember.Flags, Ember:SaveConfig / LoadConfig, Ember:Destroy
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local Ember = {
    Flags = {},
    Windows = {},
    ToggleKey = Enum.KeyCode.RightShift,
    ConfigFolder = "EmberUI",
}

-- // Theme ------------------------------------------------------------------
local Theme = {
    Background = Color3.fromRGB(22, 19, 15),   -- charcoal
    Card       = Color3.fromRGB(33, 29, 24),
    CardHover  = Color3.fromRGB(42, 37, 30),
    Accent     = Color3.fromRGB(255, 122, 26), -- ember orange
    AccentDark = Color3.fromRGB(180, 80, 15),  -- deep amber
    Text       = Color3.fromRGB(245, 238, 228),
    Muted      = Color3.fromRGB(160, 148, 132),
    Stroke     = Color3.fromRGB(52, 45, 36),
}
Ember.Theme = Theme

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
    local t = TweenService:Create(inst, TweenInfo.new(time or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function Round(inst, radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = inst })
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
    Name = "EmberUI_" .. HttpService:GenerateGUID(false):sub(1, 8),
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    -- IgnoreGuiInset intentionally NOT set: popup positioning relies on a
    -- consistent AbsolutePosition space shared with every other element
})
ProtectGui(RootGui)

-- shared popup layer: dropdown lists render here, above everything
local PopupLayer = New("Frame", {
    Name = "EmberPopups",
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0),
    ZIndex = 100,
    Parent = RootGui,
})
local ActivePopup = nil
local function ClosePopup()
    if ActivePopup then
        ActivePopup.Visible = false
        ActivePopup = nil
    end
end
local function OpenPopup(popup)
    if ActivePopup == popup then
        ClosePopup()
        return
    end
    ClosePopup()
    popup.Visible = true
    ActivePopup = popup
end

-- // Notifications ----------------------------------------------------------
local NotifHolder = New("Frame", {
    Name = "Notifications",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -16, 0, 16),
    Size = UDim2.new(0, 280, 1, -32),
    BackgroundTransparency = 1,
    ZIndex = 200,
    Parent = RootGui,
}, {
    New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        Padding = UDim.new(0, 8),
    }),
})

function Ember:Notify(cfg)
    cfg = cfg or {}
    local duration = cfg.Duration or 4

    local frame = New("Frame", {
        BackgroundColor3 = Theme.Card,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 201,
        Parent = NotifHolder,
    })
    Round(frame, 10)
    Stroke(frame)

    local emberBar = New("Frame", { -- signature ember bar down the left edge
        BackgroundColor3 = Theme.Accent,
        Position = UDim2.new(0, 8, 0, 8),
        Size = UDim2.new(0, 3, 1, -16),
        BorderSizePixel = 0,
        ZIndex = 202,
        Parent = frame,
    })
    Round(emberBar, 2)

    local title = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 22, 0, 10),
        Size = UDim2.new(1, -34, 0, 18),
        Font = Enum.Font.GothamBold,
        Text = cfg.Title or "Ember",
        TextColor3 = Theme.Text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        ZIndex = 202,
        Parent = frame,
    })
    local body = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 22, 0, 30),
        Size = UDim2.new(1, -34, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Enum.Font.GothamMedium,
        Text = cfg.Content or "",
        TextColor3 = Theme.Muted,
        TextSize = 13,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextTransparency = 1,
        ZIndex = 202,
        Parent = frame,
    })
    New("UIPadding", { PaddingBottom = UDim.new(0, 12), Parent = frame })

    Tween(frame, { BackgroundTransparency = 0.03 }, 0.25)
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

function Ember:SaveConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local data = {}
    for flag, obj in pairs(Ember.Flags) do
        local v = obj:Get()
        if typeof(v) == "EnumItem" then
            data[flag] = { __keycode = v.Name }
        elseif typeof(v) == "Color3" then
            data[flag] = { __color = { v.R, v.G, v.B } }
        elseif typeof(v) == "boolean" or typeof(v) == "number" or typeof(v) == "string" or typeof(v) == "table" then
            data[flag] = v
        end
    end
    if typeof(isfolder) == "function" and typeof(makefolder) == "function" and not isfolder(Ember.ConfigFolder) then
        makefolder(Ember.ConfigFolder)
    end
    writefile(Ember.ConfigFolder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    return true
end

function Ember:LoadConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local path = Ember.ConfigFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false, "no config file" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok then return false, "corrupt config" end
    for flag, v in pairs(data) do
        local obj = Ember.Flags[flag]
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
function Ember:CreateWindow(cfg)
    cfg = cfg or {}
    local windowName = cfg.Name or "Ember"
    if cfg.ToggleKey then Ember.ToggleKey = cfg.ToggleKey end

    local Main = New("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = cfg.Size or UDim2.new(0, 620, 0, 430),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = RootGui,
    })
    Round(Main, 12)
    Stroke(Main)

    -- Top bar: title + underlined tab buttons + window controls
    local TopBar = New("Frame", {
        Name = "TopBar",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 48),
        Parent = Main,
    })

    New("TextLabel", { -- ember diamond mark
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(0, 14, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = "◆",
        TextColor3 = Theme.Accent,
        TextSize = 13,
        Parent = TopBar,
    })
    New("TextLabel", { -- window title
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 34, 0, 0),
        Size = UDim2.new(0, 140, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = windowName,
        TextColor3 = Theme.Text,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TopBar,
    })

    local TabBar = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 182, 0, 0),
        Size = UDim2.new(1, -182 - 76, 1, 0),
        Parent = TopBar,
    }, {
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 4),
        }),
    })

    local CloseBtn = New("TextButton", {
        BackgroundColor3 = Theme.Card,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0, 26, 0, 26),
        Font = Enum.Font.GothamBold,
        Text = "×",
        TextColor3 = Theme.Muted,
        TextSize = 16,
        AutoButtonColor = false,
        Parent = TopBar,
    })
    Round(CloseBtn, 8)
    local HideBtn = New("TextButton", {
        BackgroundColor3 = Theme.Card,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -44, 0.5, 0),
        Size = UDim2.new(0, 26, 0, 26),
        Font = Enum.Font.GothamBold,
        Text = "—",
        TextColor3 = Theme.Muted,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = TopBar,
    })
    Round(HideBtn, 8)

    New("Frame", { -- divider under top bar
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 12, 0, 48),
        Size = UDim2.new(1, -24, 0, 1),
        Parent = Main,
    })

    MakeDraggable(TopBar, Main)

    CloseBtn.MouseEnter:Connect(function() Tween(CloseBtn, { TextColor3 = Theme.Accent }) end)
    CloseBtn.MouseLeave:Connect(function() Tween(CloseBtn, { TextColor3 = Theme.Muted }) end)
    HideBtn.MouseEnter:Connect(function() Tween(HideBtn, { TextColor3 = Theme.Accent }) end)
    HideBtn.MouseLeave:Connect(function() Tween(HideBtn, { TextColor3 = Theme.Muted }) end)

    CloseBtn.MouseButton1Click:Connect(function()
        ClosePopup()
        RootGui:Destroy()
    end)
    HideBtn.MouseButton1Click:Connect(function()
        ClosePopup()
        Main.Visible = false
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Ember.ToggleKey then
            Main.Visible = not Main.Visible
            if not Main.Visible then ClosePopup() end
        end
    end)

    local Content = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 49),
        Size = UDim2.new(1, 0, 1, -49),
        Parent = Main,
    })

    local Window = { Tabs = {}, Main = Main, Gui = RootGui }
    local firstTab = true

    -- // Tab -----------------------------------------------------------------
    function Window:CreateTab(tabName)
        local TabButton = New("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 0, 30),
            AutomaticSize = Enum.AutomaticSize.X,
            Font = Enum.Font.GothamMedium,
            Text = tabName,
            TextColor3 = Theme.Muted,
            TextSize = 14,
            AutoButtonColor = false,
            Parent = TabBar,
        })
        New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = TabButton })
        local Underline = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, 0),
            Size = UDim2.new(1, -10, 0, 2),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = TabButton,
        })
        Round(Underline, 1)

        local Page = New("ScrollingFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.AccentDark,
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

        local Tab = { Button = TabButton, Page = Page, Name = tabName }

        local function Select()
            for _, other in ipairs(Window.Tabs) do
                other.Page.Visible = false
                Tween(other.Button, { TextColor3 = Theme.Muted })
                Tween(other.Underline, { BackgroundTransparency = 1 })
            end
            Page.Visible = true
            Tween(TabButton, { TextColor3 = Theme.Accent })
            Tween(Underline, { BackgroundTransparency = 0 })
            ClosePopup()
        end
        Tab.Underline = Underline
        TabButton.MouseButton1Click:Connect(Select)
        table.insert(Window.Tabs, Tab)
        if firstTab then firstTab = false; Select() end

        -- // Tile-grid row manager -------------------------------------------
        -- The page is a UIListLayout of "rows". A row holds up to two tiles
        -- side by side; sections/labels are full-width rows and end pairing.
        local rowOrder = 0
        local pendingRow = nil -- { Frame = rowFrame } when the row has 1 tile

        local function NewRow(height)
            rowOrder = rowOrder + 1
            return New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, height),
                LayoutOrder = rowOrder,
                Parent = Page,
            })
        end

        local function AddTile(height)
            local tile
            if pendingRow then
                local rowFrame = pendingRow.Frame
                pendingRow = nil
                if height > rowFrame.Size.Y.Offset then
                    rowFrame.Size = UDim2.new(1, 0, 0, height)
                end
                tile = New("Frame", {
                    Position = UDim2.new(0.5, 5, 0, 0),
                    Size = UDim2.new(0.5, -5, 0, height),
                    BackgroundColor3 = Theme.Card,
                    BorderSizePixel = 0,
                    Parent = rowFrame,
                })
            else
                local rowFrame = NewRow(height)
                pendingRow = { Frame = rowFrame }
                tile = New("Frame", {
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(0.5, -5, 0, height),
                    BackgroundColor3 = Theme.Card,
                    BorderSizePixel = 0,
                    Parent = rowFrame,
                })
            end
            Round(tile, 10)
            return tile, Stroke(tile)
        end

        local function EndPairing()
            pendingRow = nil
        end

        local function HoverFX(tile)
            tile.MouseEnter:Connect(function() Tween(tile, { BackgroundColor3 = Theme.CardHover }) end)
            tile.MouseLeave:Connect(function() Tween(tile, { BackgroundColor3 = Theme.Card }) end)
        end

        local function TileName(tile, text)
            return New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 9),
                Size = UDim2.new(1, -24, 0, 16),
                Font = Enum.Font.GothamMedium,
                Text = text,
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = tile,
            })
        end

        -- // Section (full-width row) -----------------------------------------
        function Tab:CreateSection(text)
            EndPairing()
            local row = NewRow(22)
            New("Frame", { -- little ember tick
                BackgroundColor3 = Theme.Accent,
                Position = UDim2.new(0, 0, 0.5, -5),
                Size = UDim2.new(0, 3, 0, 10),
                BorderSizePixel = 0,
                Parent = row,
            })
            local lbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, 0),
                Size = UDim2.new(1, -10, 1, 0),
                Font = Enum.Font.GothamBold,
                Text = text,
                TextColor3 = Theme.Muted,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })
            EndPairing()
            local obj = {}
            function obj:Set(t) lbl.Text = t end
            return obj
        end

        -- // Label (full-width card row) --------------------------------------
        function Tab:CreateLabel(text)
            EndPairing()
            local row = NewRow(34)
            local card = New("Frame", {
                BackgroundColor3 = Theme.Card,
                Size = UDim2.new(1, 0, 1, 0),
                BorderSizePixel = 0,
                Parent = row,
            })
            Round(card, 10)
            Stroke(card)
            local lbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -24, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = text,
                TextColor3 = Theme.Muted,
                TextSize = 13,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = card,
            })
            EndPairing()
            local obj = {}
            function obj:Set(t) lbl.Text = t end
            return obj
        end

        -- // Button tile ------------------------------------------------------
        function Tab:CreateButton(cfg2)
            cfg2 = cfg2 or {}
            local tile = AddTile(64)
            HoverFX(tile)
            TileName(tile, cfg2.Name or "Button")

            local chip = New("Frame", { -- "RUN ›" chip bottom-right
                AnchorPoint = Vector2.new(1, 1),
                Position = UDim2.new(1, -10, 1, -10),
                Size = UDim2.new(0, 62, 0, 22),
                BackgroundColor3 = Theme.AccentDark,
                BorderSizePixel = 0,
                Parent = tile,
            })
            Round(chip, 6)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Font = Enum.Font.GothamBold,
                Text = "RUN ›",
                TextColor3 = Theme.Text,
                TextSize = 12,
                Parent = chip,
            })

            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                Parent = tile,
            })
            click.MouseButton1Click:Connect(function()
                Tween(tile, { BackgroundColor3 = Theme.AccentDark }, 0.07)
                Tween(chip, { BackgroundColor3 = Theme.Accent }, 0.07)
                task.delay(0.12, function()
                    Tween(tile, { BackgroundColor3 = Theme.Card }, 0.25)
                    Tween(chip, { BackgroundColor3 = Theme.AccentDark }, 0.25)
                end)
                if cfg2.Callback then task.spawn(cfg2.Callback) end
            end)
            return { Frame = tile }
        end

        -- // Toggle tile ------------------------------------------------------
        function Tab:CreateToggle(cfg2)
            cfg2 = cfg2 or {}
            local state = cfg2.Default or false
            local tile, tileStroke = AddTile(64)
            HoverFX(tile)
            TileName(tile, cfg2.Name or "Toggle")

            local stateLabel = New("TextLabel", { -- dim status line
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 1, -26),
                Size = UDim2.new(1, -70, 0, 16),
                Font = Enum.Font.GothamMedium,
                Text = "off",
                TextColor3 = Theme.Muted,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = tile,
            })

            local pill = New("Frame", { -- big pill switch bottom-right
                AnchorPoint = Vector2.new(1, 1),
                Position = UDim2.new(1, -10, 1, -10),
                Size = UDim2.new(0, 42, 0, 22),
                BackgroundColor3 = Theme.Stroke,
                BorderSizePixel = 0,
                Parent = tile,
            })
            Round(pill, 11)
            local knob = New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 3, 0.5, 0),
                Size = UDim2.new(0, 16, 0, 16),
                BackgroundColor3 = Theme.Text,
                BorderSizePixel = 0,
                Parent = pill,
            })
            Round(knob, 8)

            local obj = {}
            local function render()
                -- signature: whole tile border glows ember orange when ON
                Tween(tileStroke, {
                    Color = state and Theme.Accent or Theme.Stroke,
                    Transparency = state and 0.15 or 0,
                })
                Tween(pill, { BackgroundColor3 = state and Theme.Accent or Theme.Stroke })
                Tween(knob, { Position = state and UDim2.new(0, 23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
                stateLabel.Text = state and "on" or "off"
                stateLabel.TextColor3 = state and Theme.Accent or Theme.Muted
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
                Parent = tile,
            })
            click.MouseButton1Click:Connect(function() obj:Set(not state) end)

            render()
            if state and cfg2.Callback then task.spawn(cfg2.Callback, state) end
            if cfg2.Flag then Ember.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Slider tile ------------------------------------------------------
        function Tab:CreateSlider(cfg2)
            cfg2 = cfg2 or {}
            local min = cfg2.Min or 0
            local max = cfg2.Max or 100
            local increment = cfg2.Increment or 1
            local suffix = cfg2.Suffix or ""
            local value = math.clamp(cfg2.Default or min, min, max)

            local tile = AddTile(78)
            TileName(tile, cfg2.Name or "Slider")

            local valueLabel = New("TextLabel", { -- big orange value top-right
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -12, 0, 8),
                Size = UDim2.new(0, 110, 0, 20),
                Font = Enum.Font.GothamBold,
                Text = "",
                TextColor3 = Theme.Accent,
                TextSize = 17,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = tile,
            })

            local bar = New("Frame", { -- full-width bar along the bottom
                Position = UDim2.new(0, 12, 1, -22),
                Size = UDim2.new(1, -24, 0, 8),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Parent = tile,
            })
            Round(bar, 4)
            Stroke(bar)
            local fill = New("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                Parent = bar,
            })
            Round(fill, 4)

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
            if cfg2.Flag then Ember.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Dropdown tile (floating popup list) ------------------------------
        function Tab:CreateDropdown(cfg2)
            cfg2 = cfg2 or {}
            local options = cfg2.Options or {}
            local selected = cfg2.Default

            local tile = AddTile(64)
            HoverFX(tile)
            TileName(tile, cfg2.Name or "Dropdown")

            local chip = New("Frame", { -- selected-value chip along the bottom
                Position = UDim2.new(0, 10, 1, -32),
                Size = UDim2.new(1, -20, 0, 22),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Parent = tile,
            })
            Round(chip, 6)
            Stroke(chip)
            local selectedLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 0),
                Size = UDim2.new(1, -26, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = "",
                TextColor3 = Theme.Muted,
                TextSize = 12,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = chip,
            })
            New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -6, 0, 0),
                Size = UDim2.new(0, 14, 1, 0),
                Font = Enum.Font.GothamBold,
                Text = "▾",
                TextColor3 = Theme.Accent,
                TextSize = 12,
                Parent = chip,
            })

            -- floating popup list on the shared popup layer (NOT inline:
            -- tiles sit in a grid, expanding one would break the layout)
            local popup = New("Frame", {
                BackgroundColor3 = Theme.CardHover,
                Size = UDim2.new(0, 200, 0, 0),
                Visible = false,
                ZIndex = 110,
                Parent = PopupLayer,
            })
            Round(popup, 8)
            Stroke(popup, Theme.AccentDark)
            local popupScroll = New("ScrollingFrame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = Theme.AccentDark,
                BorderSizePixel = 0,
                ZIndex = 110,
                Parent = popup,
            }, {
                New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
                New("UIPadding", {
                    PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
                    PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
                }),
            })

            local obj = {}
            local optionButtons = {}

            local function renderSelection()
                selectedLabel.Text = selected ~= nil and tostring(selected) or "Select…"
                selectedLabel.TextColor3 = selected ~= nil and Theme.Text or Theme.Muted
                for opt, btn in pairs(optionButtons) do
                    btn.TextColor3 = (opt == selected) and Theme.Accent or Theme.Muted
                end
            end

            local function buildOptions()
                for _, btn in pairs(optionButtons) do btn:Destroy() end
                optionButtons = {}
                for _, opt in ipairs(options) do
                    local btn = New("TextButton", {
                        BackgroundColor3 = Theme.Card,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 22),
                        Font = Enum.Font.GothamMedium,
                        Text = "  " .. tostring(opt),
                        TextColor3 = Theme.Muted,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        AutoButtonColor = false,
                        ZIndex = 111,
                        Parent = popupScroll,
                    })
                    Round(btn, 5)
                    btn.MouseEnter:Connect(function() btn.BackgroundTransparency = 0 end)
                    btn.MouseLeave:Connect(function() btn.BackgroundTransparency = 1 end)
                    btn.MouseButton1Click:Connect(function()
                        obj:Set(opt)
                        ClosePopup()
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
            end

            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                Parent = tile,
            })
            click.MouseButton1Click:Connect(function()
                local listHeight = math.min(#options * 24 + 8, 170)
                popup.Position = UDim2.new(0, math.floor(chip.AbsolutePosition.X), 0, math.floor(chip.AbsolutePosition.Y + chip.AbsoluteSize.Y + 4))
                popup.Size = UDim2.new(0, math.floor(chip.AbsoluteSize.X), 0, listHeight)
                OpenPopup(popup)
            end)

            buildOptions()
            renderSelection()
            if cfg2.Flag then Ember.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Input tile -------------------------------------------------------
        function Tab:CreateInput(cfg2)
            cfg2 = cfg2 or {}
            local tile = AddTile(64)
            TileName(tile, cfg2.Name or "Input")

            local boxHolder = New("Frame", {
                Position = UDim2.new(0, 10, 1, -32),
                Size = UDim2.new(1, -20, 0, 22),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Parent = tile,
            })
            Round(boxHolder, 6)
            local boxStroke = Stroke(boxHolder)
            local box = New("TextBox", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 0),
                Size = UDim2.new(1, -16, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Default or "",
                PlaceholderText = cfg2.Placeholder or "…",
                PlaceholderColor3 = Theme.Muted,
                TextColor3 = Theme.Text,
                TextSize = 12,
                ClearTextOnFocus = false,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = boxHolder,
            })
            box.Focused:Connect(function()
                Tween(boxStroke, { Color = Theme.Accent })
            end)
            box.FocusLost:Connect(function(enterPressed)
                Tween(boxStroke, { Color = Theme.Stroke })
                if cfg2.Callback then task.spawn(cfg2.Callback, box.Text, enterPressed) end
            end)

            local obj = {}
            function obj:Set(t)
                box.Text = tostring(t)
                if cfg2.Callback then task.spawn(cfg2.Callback, box.Text, false) end
            end
            function obj:Get() return box.Text end
            if cfg2.Flag then Ember.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Keybind tile -----------------------------------------------------
        function Tab:CreateKeybind(cfg2)
            cfg2 = cfg2 or {}
            local key = cfg2.Default -- Enum.KeyCode or nil
            local listening = false

            local tile = AddTile(64)
            HoverFX(tile)
            TileName(tile, cfg2.Name or "Keybind")

            local keyBtn = New("TextButton", { -- keycap chip bottom-right
                AnchorPoint = Vector2.new(1, 1),
                Position = UDim2.new(1, -10, 1, -10),
                Size = UDim2.new(0, 88, 0, 22),
                BackgroundColor3 = Theme.Background,
                Font = Enum.Font.GothamBold,
                Text = KeyName(key),
                TextColor3 = Theme.Muted,
                TextSize = 11,
                AutoButtonColor = false,
                Parent = tile,
            })
            Round(keyBtn, 6)
            local keyStroke = Stroke(keyBtn)

            local obj = {}
            function obj:Set(newKey)
                key = newKey
                keyBtn.Text = KeyName(key)
            end
            function obj:Get() return key end

            keyBtn.MouseButton1Click:Connect(function()
                listening = true
                keyBtn.Text = "press key…"
                keyBtn.TextColor3 = Theme.Accent
                Tween(keyStroke, { Color = Theme.Accent })
            end)

            UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    listening = false
                    keyBtn.TextColor3 = Theme.Muted
                    Tween(keyStroke, { Color = Theme.Stroke })
                    if input.KeyCode == Enum.KeyCode.Escape then
                        obj:Set(nil) -- Escape clears the bind
                    else
                        obj:Set(input.KeyCode)
                    end
                    return
                end
                if not gameProcessed and key and input.KeyCode == key then
                    if cfg2.Callback then task.spawn(cfg2.Callback, key) end
                end
            end)

            if cfg2.Flag then Ember.Flags[cfg2.Flag] = obj end
            return obj
        end

        return Tab
    end

    function Window:Destroy()
        ClosePopup()
        RootGui:Destroy()
    end

    table.insert(Ember.Windows, Window)
    return Window
end

function Ember:Destroy()
    ClosePopup()
    RootGui:Destroy()
end

return Ember
