--[[
    Onyx UI Library v1.0
    Discord-inspired three-column UI library for Roblox executors

    Layout:
        [ RAIL ]  [ SIDEBAR ]  [ CONTENT ]
        tabs as    sections as   scrolling
        circles    "# channels"  elements

    Usage:
        local Onyx = loadstring(readfile("UI/Onyx/Onyx.lua"))()
        local Window = Onyx:CreateWindow({ Name = "My Hub", ToggleKey = Enum.KeyCode.RightShift })
        local Tab = Window:CreateTab("Main")
        Tab:CreateSection("general")
        Tab:CreateToggle({ Name = "Auto Farm", Flag = "AutoFarm", Callback = function(v) end })

    Elements: Section, Label, Button, Toggle, Slider, Dropdown, Input, Keybind
    Extras:   Onyx:Notify, Onyx.Flags, Onyx:SaveConfig / LoadConfig, Onyx:Destroy
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local Onyx = {
    Flags = {},
    Windows = {},
    ToggleKey = Enum.KeyCode.RightShift,
    ConfigFolder = "OnyxUI",
    _connections = {},
}

-- // Theme (Discord dark) -----------------------------------------------------
local Theme = {
    Rail         = Color3.fromRGB(30, 31, 34),   -- far-left server rail
    Sidebar      = Color3.fromRGB(43, 45, 49),   -- channel column
    Content      = Color3.fromRGB(49, 51, 56),   -- chat/content column
    Element      = Color3.fromRGB(56, 58, 64),   -- element background
    ElementHover = Color3.fromRGB(64, 66, 73),
    Accent       = Color3.fromRGB(88, 101, 242), -- blurple
    AccentDim    = Color3.fromRGB(71, 82, 196),
    Green        = Color3.fromRGB(35, 165, 90),  -- on-toggle green
    OffGray      = Color3.fromRGB(110, 116, 128),-- off-toggle gray
    Text         = Color3.fromRGB(242, 243, 245),
    Muted        = Color3.fromRGB(148, 155, 164),
    Divider      = Color3.fromRGB(35, 36, 40),
    White        = Color3.fromRGB(255, 255, 255),
}
Onyx.Theme = Theme

-- // Helpers ------------------------------------------------------------------
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

local function Round(inst, radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius or 6), Parent = inst })
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

local function Connect(signal, fn)
    local conn = signal:Connect(fn)
    table.insert(Onyx._connections, conn)
    return conn
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
    Connect(UserInputService.InputChanged, function(input)
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

-- first 1-2 letters for the rail circle ("Auto Farm" -> "AF", "Main" -> "MA")
local function TabInitials(name)
    name = tostring(name or "?")
    local words = {}
    for w in name:gmatch("%S+") do
        table.insert(words, w)
    end
    if #words >= 2 then
        return (words[1]:sub(1, 1) .. words[2]:sub(1, 1)):upper()
    end
    local single = words[1] or "?"
    return single:sub(1, 2):upper()
end

-- // Root gui -------------------------------------------------------------
local RootGui = New("ScreenGui", {
    Name = "OnyxUI_" .. HttpService:GenerateGUID(false):sub(1, 8),
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    -- IgnoreGuiInset intentionally left false
})
ProtectGui(RootGui)

-- // Notifications (Discord message-toast, bottom-right) --------------------
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
        Padding = UDim.new(0, 8),
    }),
})

function Onyx:Notify(cfg)
    cfg = cfg or {}
    local duration = cfg.Duration or 4
    local dotColor = cfg.Color or Theme.Accent

    local frame = New("Frame", {
        BackgroundColor3 = Theme.Sidebar,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        Parent = NotifHolder,
    })
    Round(frame, 8)
    New("UIStroke", { Color = Theme.Divider, Thickness = 1, Parent = frame })

    -- colored presence dot (the "avatar")
    local dot = New("Frame", {
        BackgroundColor3 = dotColor,
        Position = UDim2.new(0, 12, 0, 13),
        Size = UDim2.new(0, 10, 0, 10),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Parent = frame,
    })
    Round(dot, 5)

    local title = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 30, 0, 8),
        Size = UDim2.new(1, -42, 0, 18),
        Font = Enum.Font.GothamBold,
        Text = cfg.Title or "Onyx",
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        Parent = frame,
    })
    local body = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 30, 0, 26),
        Size = UDim2.new(1, -42, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Enum.Font.Gotham,
        Text = cfg.Content or "",
        TextColor3 = Theme.Muted,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextTransparency = 1,
        Parent = frame,
    })
    New("UIPadding", { PaddingBottom = UDim.new(0, 10), Parent = frame })

    -- pop in like a message toast
    Tween(frame, { BackgroundTransparency = 0 }, 0.25, Enum.EasingStyle.Back)
    Tween(dot, { BackgroundTransparency = 0 }, 0.25)
    Tween(title, { TextTransparency = 0 }, 0.25)
    Tween(body, { TextTransparency = 0.1 }, 0.25)

    task.delay(duration, function()
        if not frame.Parent then return end
        Tween(frame, { BackgroundTransparency = 1 }, 0.3)
        Tween(dot, { BackgroundTransparency = 1 }, 0.3)
        Tween(title, { TextTransparency = 1 }, 0.3)
        Tween(body, { TextTransparency = 1 }, 0.3)
        task.wait(0.32)
        if frame.Parent then frame:Destroy() end
    end)
end

-- // Config saving ------------------------------------------------------------
local function CanUseFiles()
    return typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"
end

function Onyx:SaveConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local data = {}
    for flag, obj in pairs(Onyx.Flags) do
        local v = obj:Get()
        if typeof(v) == "EnumItem" then
            data[flag] = { __keycode = v.Name }
        elseif typeof(v) == "Color3" then
            data[flag] = { __color = { v.R, v.G, v.B } }
        else
            data[flag] = v
        end
    end
    if typeof(isfolder) == "function" and typeof(makefolder) == "function" and not isfolder(Onyx.ConfigFolder) then
        makefolder(Onyx.ConfigFolder)
    end
    writefile(Onyx.ConfigFolder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    return true
end

function Onyx:LoadConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local path = Onyx.ConfigFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false, "no config file" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok then return false, "corrupt config" end
    for flag, v in pairs(data) do
        local obj = Onyx.Flags[flag]
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

-- // Window ---------------------------------------------------------------
function Onyx:CreateWindow(cfg)
    cfg = cfg or {}
    local windowName = cfg.Name or "Onyx"
    if cfg.ToggleKey then Onyx.ToggleKey = cfg.ToggleKey end

    local RAIL_W = 56
    local SIDE_W = 150

    local Main = New("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = cfg.Size or UDim2.new(0, 640, 0, 420),
        BackgroundColor3 = Theme.Content,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = RootGui,
    })
    Round(Main, 10)
    New("UIStroke", { Color = Theme.Divider, Thickness = 1, Parent = Main })

    -- // Column 1: RAIL ------------------------------------------------------
    local Rail = New("Frame", {
        Name = "Rail",
        Size = UDim2.new(0, RAIL_W, 1, 0),
        BackgroundColor3 = Theme.Rail,
        BorderSizePixel = 0,
        Parent = Main,
    })
    Round(Rail, 10)
    New("Frame", { -- square off the right edge of the rail
        BackgroundColor3 = Theme.Rail,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -10, 0, 0),
        Size = UDim2.new(0, 10, 1, 0),
        Parent = Rail,
    })

    local RailTabs = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 10),
        Size = UDim2.new(1, 0, 1, -64),
        Parent = Rail,
    }, {
        New("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            Padding = UDim.new(0, 8),
        }),
    })

    -- destroy circle at bottom of rail
    New("Frame", { -- divider above destroy button
        BackgroundColor3 = Theme.Divider,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -50),
        Size = UDim2.new(0, 28, 0, 2),
        Parent = Rail,
    })
    local DestroyBtn = New("TextButton", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -8),
        Size = UDim2.new(0, 36, 0, 36),
        BackgroundColor3 = Theme.Sidebar,
        Font = Enum.Font.GothamBold,
        Text = "\xC3\x97", -- ×
        TextColor3 = Theme.Muted,
        TextSize = 18,
        AutoButtonColor = false,
        Parent = Rail,
    })
    Round(DestroyBtn, 18)
    DestroyBtn.MouseEnter:Connect(function()
        Tween(DestroyBtn, { BackgroundColor3 = Color3.fromRGB(218, 55, 60), TextColor3 = Theme.White })
        Tween(DestroyBtn:FindFirstChildOfClass("UICorner"), { CornerRadius = UDim.new(0, 12) })
    end)
    DestroyBtn.MouseLeave:Connect(function()
        Tween(DestroyBtn, { BackgroundColor3 = Theme.Sidebar, TextColor3 = Theme.Muted })
        Tween(DestroyBtn:FindFirstChildOfClass("UICorner"), { CornerRadius = UDim.new(0, 18) })
    end)
    DestroyBtn.MouseButton1Click:Connect(function()
        Onyx:Destroy()
    end)

    -- // Column 2: SIDEBAR ---------------------------------------------------
    local Sidebar = New("Frame", {
        Name = "Sidebar",
        Position = UDim2.new(0, RAIL_W, 0, 0),
        Size = UDim2.new(0, SIDE_W, 1, 0),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
        Parent = Main,
    })

    -- "server name" header (also the drag handle)
    local TitleBar = New("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 44),
        Font = Enum.Font.GothamBold,
        Text = "",
        AutoButtonColor = false,
        Parent = Sidebar,
    })
    New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(1, -24, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = windowName,
        TextColor3 = Theme.Text,
        TextSize = 14,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TitleBar,
    })
    New("Frame", { -- bottom divider under the "server name"
        BackgroundColor3 = Theme.Divider,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        Parent = TitleBar,
    })
    MakeDraggable(TitleBar, Main)

    -- holder for per-tab channel lists
    local ChannelArea = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 48),
        Size = UDim2.new(1, 0, 1, -70),
        Parent = Sidebar,
    })

    New("TextLabel", { -- footer hint
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 14, 1, -6),
        Size = UDim2.new(1, -24, 0, 14),
        Font = Enum.Font.Gotham,
        Text = KeyName(Onyx.ToggleKey) .. " to hide",
        TextColor3 = Theme.Muted,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Sidebar,
    })

    -- // Column 3: CONTENT ---------------------------------------------------
    local Content = New("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, RAIL_W + SIDE_W, 0, 0),
        Size = UDim2.new(1, -(RAIL_W + SIDE_W), 1, 0),
        Parent = Main,
    })

    -- toggle visibility key
    Connect(UserInputService.InputBegan, function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Onyx.ToggleKey then
            Main.Visible = not Main.Visible
        end
    end)

    local Window = { Tabs = {}, Main = Main, Gui = RootGui }
    local firstTab = true

    -- // Tab -------------------------------------------------------------------
    function Window:CreateTab(tabName)
        tabName = tostring(tabName or "Tab")

        -- rail circle
        local TabButton = New("TextButton", {
            Size = UDim2.new(0, 40, 0, 40),
            BackgroundColor3 = Theme.Sidebar,
            Font = Enum.Font.GothamBold,
            Text = TabInitials(tabName),
            TextColor3 = Theme.Muted,
            TextSize = 14,
            AutoButtonColor = false,
            Parent = RailTabs,
        })
        local TabCorner = Round(TabButton, 20) -- full circle

        -- white pill indicator on the rail's left edge
        local Pill = New("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, -8, 0.5, 0),
            Size = UDim2.new(0, 4, 0, 0),
            BackgroundColor3 = Theme.White,
            BorderSizePixel = 0,
            Parent = TabButton,
        })
        Round(Pill, 2)

        -- channel list for this tab's sections
        local Channels = New("ScrollingFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 0,
            BorderSizePixel = 0,
            Visible = false,
            Parent = ChannelArea,
        }, {
            New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 8),
                PaddingRight = UDim.new(0, 8),
                PaddingTop = UDim.new(0, 6),
            }),
        })
        New("TextLabel", { -- category label like Discord's "TEXT CHANNELS"
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Font = Enum.Font.GothamBold,
            Text = tabName:upper(),
            TextColor3 = Theme.Muted,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = -1,
            Parent = Channels,
        })

        -- content page
        local Page = New("ScrollingFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = Theme.Rail,
            BorderSizePixel = 0,
            Visible = false,
            Parent = Content,
        }, {
            New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 16),
                PaddingRight = UDim.new(0, 16),
                PaddingTop = UDim.new(0, 12),
                PaddingBottom = UDim.new(0, 16),
            }),
        })

        local Tab = {
            Button = TabButton,
            Page = Page,
            Channels = Channels,
            Name = tabName,
            Corner = TabCorner,
            Pill = Pill,
        }

        local function Select()
            for _, other in ipairs(Window.Tabs) do
                if other ~= Tab then
                    other.Page.Visible = false
                    other.Channels.Visible = false
                    Tween(other.Button, { BackgroundColor3 = Theme.Sidebar, TextColor3 = Theme.Muted })
                    Tween(other.Corner, { CornerRadius = UDim.new(0, 20) })
                    Tween(other.Pill, { Size = UDim2.new(0, 4, 0, 0) })
                end
            end
            Page.Visible = true
            Channels.Visible = true
            -- circle -> squircle morph + blurple fill + white pill
            Tween(TabButton, { BackgroundColor3 = Theme.Accent, TextColor3 = Theme.White })
            Tween(TabCorner, { CornerRadius = UDim.new(0, 12) })
            Tween(Pill, { Size = UDim2.new(0, 4, 0, 22) }, 0.22, Enum.EasingStyle.Back)
        end

        TabButton.MouseButton1Click:Connect(Select)
        TabButton.MouseEnter:Connect(function()
            if not Page.Visible then
                Tween(TabButton, { BackgroundColor3 = Theme.Element })
                Tween(TabCorner, { CornerRadius = UDim.new(0, 14) })
                Tween(Pill, { Size = UDim2.new(0, 4, 0, 10) })
            end
        end)
        TabButton.MouseLeave:Connect(function()
            if not Page.Visible then
                Tween(TabButton, { BackgroundColor3 = Theme.Sidebar })
                Tween(TabCorner, { CornerRadius = UDim.new(0, 20) })
                Tween(Pill, { Size = UDim2.new(0, 4, 0, 0) })
            end
        end)

        table.insert(Window.Tabs, Tab)
        if firstTab then firstTab = false; Select() end

        -- shared element base --------------------------------------------------
        local function ElementBase(height)
            local frame = New("Frame", {
                BackgroundColor3 = Theme.Element,
                Size = UDim2.new(1, 0, 0, height),
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Parent = Page,
            })
            Round(frame, 6)
            return frame
        end

        local function HoverFX(frame)
            frame.MouseEnter:Connect(function() Tween(frame, { BackgroundColor3 = Theme.ElementHover }) end)
            frame.MouseLeave:Connect(function() Tween(frame, { BackgroundColor3 = Theme.Element }) end)
        end

        -- // Section (channel row in sidebar + "# name" divider in content) ----
        function Tab:CreateSection(text)
            text = tostring(text or "section")

            -- content header: "# name"
            local header = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 30),
                Parent = Page,
            })
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, 6),
                Size = UDim2.new(0, 16, 0, 20),
                Font = Enum.Font.GothamBold,
                Text = "#",
                TextColor3 = Theme.Muted,
                TextSize = 16,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = header,
            })
            local nameLbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 18, 0, 6),
                Size = UDim2.new(1, -18, 0, 20),
                Font = Enum.Font.GothamBold,
                Text = text,
                TextColor3 = Theme.Text,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = header,
            })
            New("Frame", { -- underline divider
                BackgroundColor3 = Theme.Divider,
                BorderSizePixel = 0,
                Position = UDim2.new(0, 0, 1, -1),
                Size = UDim2.new(1, 0, 0, 1),
                Parent = header,
            })

            -- sidebar channel row: "# section-name"
            local row = New("TextButton", {
                BackgroundColor3 = Theme.Element,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 26),
                Font = Enum.Font.GothamMedium,
                Text = "",
                AutoButtonColor = false,
                Parent = Channels,
            })
            Round(row, 4)
            local rowLbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 0),
                Size = UDim2.new(1, -12, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = "#  " .. text,
                TextColor3 = Theme.Muted,
                TextSize = 12,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })

            row.MouseEnter:Connect(function()
                Tween(row, { BackgroundTransparency = 0.5 })
                Tween(rowLbl, { TextColor3 = Theme.Text })
            end)
            row.MouseLeave:Connect(function()
                Tween(row, { BackgroundTransparency = 1 })
                Tween(rowLbl, { TextColor3 = Theme.Muted })
            end)

            row.MouseButton1Click:Connect(function()
                -- scroll the content page so this section header is at the top
                local target = Page.CanvasPosition.Y + (header.AbsolutePosition.Y - Page.AbsolutePosition.Y) - 6
                local maxScroll = math.max(0, Page.AbsoluteCanvasSize.Y - Page.AbsoluteWindowSize.Y)
                target = math.clamp(target, 0, maxScroll)
                Tween(Page, { CanvasPosition = Vector2.new(0, target) }, 0.3)
                -- flash the row like a selected channel
                Tween(row, { BackgroundTransparency = 0 })
                task.delay(0.4, function()
                    if row.Parent then Tween(row, { BackgroundTransparency = 1 }, 0.4) end
                end)
            end)

            local obj = { Frame = header }
            function obj:Set(t)
                t = tostring(t)
                nameLbl.Text = t
                rowLbl.Text = "#  " .. t
            end
            return obj
        end

        -- // Label -------------------------------------------------------------
        function Tab:CreateLabel(text)
            local frame = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 22),
                Parent = Page,
            })
            local lbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 2, 0, 0),
                Size = UDim2.new(1, -4, 1, 0),
                Font = Enum.Font.Gotham,
                Text = tostring(text or ""),
                TextColor3 = Theme.Muted,
                TextSize = 13,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local obj = { Frame = frame }
            function obj:Set(t) lbl.Text = tostring(t) end
            return obj
        end

        -- // Button ------------------------------------------------------------
        function Tab:CreateButton(cfg2)
            cfg2 = cfg2 or {}
            local frame = ElementBase(36)
            HoverFX(frame)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -60, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Name or "Button",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local chip = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.new(0, 46, 0, 22),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                Parent = frame,
            })
            Round(chip, 4)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Font = Enum.Font.GothamBold,
                Text = "RUN",
                TextColor3 = Theme.White,
                TextSize = 10,
                Parent = chip,
            })
            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                Parent = frame,
            })
            click.MouseButton1Click:Connect(function()
                Tween(chip, { BackgroundColor3 = Theme.AccentDim }, 0.08)
                task.delay(0.12, function()
                    if chip.Parent then Tween(chip, { BackgroundColor3 = Theme.Accent }, 0.2) end
                end)
                if cfg2.Callback then task.spawn(cfg2.Callback) end
            end)
            return { Frame = frame }
        end

        -- // Toggle (Discord pill switch) ----------------------------------------
        function Tab:CreateToggle(cfg2)
            cfg2 = cfg2 or {}
            local state = cfg2.Default and true or false

            local frame = ElementBase(36)
            HoverFX(frame)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -70, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Name or "Toggle",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local pill = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.new(0, 40, 0, 22),
                BackgroundColor3 = Theme.OffGray,
                BorderSizePixel = 0,
                Parent = frame,
            })
            Round(pill, 11)
            local knob = New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 2, 0.5, 0),
                Size = UDim2.new(0, 18, 0, 18),
                BackgroundColor3 = Theme.White,
                BorderSizePixel = 0,
                Parent = pill,
            })
            Round(knob, 9)
            local check = New("TextLabel", { -- tiny check inside the knob
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Font = Enum.Font.GothamBold,
                Text = "\xE2\x9C\x93", -- ✓
                TextColor3 = Theme.Green,
                TextSize = 11,
                TextTransparency = 1,
                Parent = knob,
            })

            local obj = {}
            local function render(animate)
                local dur = animate and 0.18 or 0
                Tween(pill, { BackgroundColor3 = state and Theme.Green or Theme.OffGray }, dur)
                Tween(knob, { Position = state and UDim2.new(0, 20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) }, dur, Enum.EasingStyle.Back)
                Tween(check, { TextTransparency = state and 0 or 1 }, dur)
            end
            function obj:Set(v)
                v = v and true or false
                if v == state then render(false) return end
                state = v
                render(true)
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

            render(false)
            if state and cfg2.Callback then task.spawn(cfg2.Callback, state) end
            if cfg2.Flag then Onyx.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Slider (blurple fill + round grabber) -------------------------------
        function Tab:CreateSlider(cfg2)
            cfg2 = cfg2 or {}
            local min = cfg2.Min or 0
            local max = cfg2.Max or 100
            local increment = cfg2.Increment or 1
            local suffix = cfg2.Suffix or ""
            local value = math.clamp(cfg2.Default or min, min, max)

            local frame = ElementBase(50)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 6),
                Size = UDim2.new(1, -120, 0, 16),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Name or "Slider",
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
                TextColor3 = Theme.Muted,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = frame,
            })
            local bar = New("Frame", {
                Position = UDim2.new(0, 12, 0, 34),
                Size = UDim2.new(1, -24, 0, 6),
                BackgroundColor3 = Theme.Rail,
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
            local grabber = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(0, 14, 0, 14),
                BackgroundColor3 = Theme.White,
                BorderSizePixel = 0,
                ZIndex = 2,
                Parent = bar,
            })
            Round(grabber, 7)

            local decimals = math.max(0, math.ceil(-math.log10(increment)))
            local obj = {}
            local function render()
                local alpha = (max == min) and 0 or (value - min) / (max - min)
                fill.Size = UDim2.new(alpha, 0, 1, 0)
                grabber.Position = UDim2.new(alpha, 0, 0.5, 0)
                valueLabel.Text = string.format("%." .. math.floor(decimals) .. "f", value)
                    .. (suffix ~= "" and (" " .. suffix) or "")
            end
            function obj:Set(v)
                v = tonumber(v) or min
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
            frame.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    -- only start dragging from the lower half (bar area)
                    if input.Position.Y >= bar.AbsolutePosition.Y - 8 then
                        dragging = true
                        updateFromInput(input)
                    end
                end
            end)
            Connect(UserInputService.InputChanged, function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    updateFromInput(input)
                end
            end)
            Connect(UserInputService.InputEnded, function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)

            render()
            if cfg2.Flag then Onyx.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Dropdown ------------------------------------------------------------
        function Tab:CreateDropdown(cfg2)
            cfg2 = cfg2 or {}
            local options = cfg2.Options or {}
            local selected = cfg2.Default
            local open = false

            local frame = ElementBase(36)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(0.45, -12, 0, 36),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Name or "Dropdown",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local selectedLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -32, 0, 0),
                Size = UDim2.new(0.55, -44, 0, 36),
                Font = Enum.Font.Gotham,
                Text = "",
                TextColor3 = Theme.Muted,
                TextSize = 12,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = frame,
            })
            local arrow = New("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -12, 0, 0),
                Size = UDim2.new(0, 14, 0, 36),
                Font = Enum.Font.GothamBold,
                Text = "\xE2\x96\xBE", -- ▾
                TextColor3 = Theme.Muted,
                TextSize = 12,
                Parent = frame,
            })
            local optionHolder = New("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 38),
                Size = UDim2.new(1, -16, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = frame,
            }, {
                New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
            })

            local obj = {}
            local optionButtons = {}

            local function openHeight() return 38 + #options * 26 + 8 end

            local function setOpen(v)
                open = v
                Tween(arrow, { Rotation = open and 180 or 0 })
                Tween(frame, { Size = UDim2.new(1, 0, 0, open and openHeight() or 36) }, 0.22)
            end

            local function renderSelection()
                selectedLabel.Text = selected ~= nil and tostring(selected) or "Select..."
                for opt, btn in pairs(optionButtons) do
                    btn.TextColor3 = (opt == selected) and Theme.Text or Theme.Muted
                    btn.BackgroundColor3 = (opt == selected) and Theme.Accent or Theme.Content
                    btn.BackgroundTransparency = (opt == selected) and 0.35 or 0
                end
            end

            local function buildOptions()
                for _, btn in pairs(optionButtons) do btn:Destroy() end
                optionButtons = {}
                for _, opt in ipairs(options) do
                    local btn = New("TextButton", {
                        BackgroundColor3 = Theme.Content,
                        Size = UDim2.new(1, 0, 0, 24),
                        Font = Enum.Font.Gotham,
                        Text = "  " .. tostring(opt),
                        TextColor3 = Theme.Muted,
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
                Size = UDim2.new(1, 0, 0, 36),
                Text = "",
                Parent = frame,
            })
            click.MouseButton1Click:Connect(function() setOpen(not open) end)

            buildOptions()
            renderSelection()
            if cfg2.Flag then Onyx.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Input ---------------------------------------------------------------
        function Tab:CreateInput(cfg2)
            cfg2 = cfg2 or {}
            local frame = ElementBase(36)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(0.45, -12, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Name or "Input",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local boxHolder = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.new(0, 160, 0, 26),
                BackgroundColor3 = Theme.Rail,
                BorderSizePixel = 0,
                Parent = frame,
            })
            Round(boxHolder, 5)
            local box = New("TextBox", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 0),
                Size = UDim2.new(1, -16, 1, 0),
                Font = Enum.Font.Gotham,
                Text = cfg2.Default or "",
                PlaceholderText = cfg2.Placeholder or "Message...",
                PlaceholderColor3 = Theme.Muted,
                TextColor3 = Theme.Text,
                TextSize = 12,
                ClearTextOnFocus = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = boxHolder,
            })
            box.Focused:Connect(function()
                Tween(boxHolder, { BackgroundColor3 = Theme.Rail })
                New("UIStroke", { Name = "FocusStroke", Color = Theme.Accent, Thickness = 1, Parent = boxHolder })
            end)
            box.FocusLost:Connect(function(enterPressed)
                local s = boxHolder:FindFirstChild("FocusStroke")
                if s then s:Destroy() end
                if cfg2.Callback then task.spawn(cfg2.Callback, box.Text, enterPressed) end
            end)
            local obj = {}
            function obj:Set(t)
                box.Text = tostring(t)
                if cfg2.Callback then task.spawn(cfg2.Callback, box.Text, false) end
            end
            function obj:Get() return box.Text end
            if cfg2.Flag then Onyx.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Keybind (keycap chip) -------------------------------------------------
        function Tab:CreateKeybind(cfg2)
            cfg2 = cfg2 or {}
            local key = cfg2.Default -- Enum.KeyCode or nil
            local listening = false

            local frame = ElementBase(36)
            HoverFX(frame)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -110, 1, 0),
                Font = Enum.Font.GothamMedium,
                Text = cfg2.Name or "Keybind",
                TextColor3 = Theme.Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            -- keycap chip: raised cap with darker base edge
            local capBase = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.new(0, 84, 0, 24),
                BackgroundColor3 = Theme.Rail,
                BorderSizePixel = 0,
                Parent = frame,
            })
            Round(capBase, 5)
            local cap = New("TextButton", {
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(1, 0, 1, -3),
                BackgroundColor3 = Theme.ElementHover,
                Font = Enum.Font.GothamBold,
                Text = KeyName(key),
                TextColor3 = Theme.Text,
                TextSize = 11,
                AutoButtonColor = false,
                Parent = capBase,
            })
            Round(cap, 5)
            New("UIStroke", { Color = Theme.Divider, Thickness = 1, Parent = cap })

            local obj = {}
            function obj:Set(newKey)
                key = newKey
                cap.Text = KeyName(key)
                cap.TextColor3 = Theme.Text
            end
            function obj:Get() return key end

            cap.MouseButton1Click:Connect(function()
                listening = true
                cap.Text = "..."
                cap.TextColor3 = Theme.Accent
            end)

            Connect(UserInputService.InputBegan, function(input, gameProcessed)
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
                    if cfg2.Callback then task.spawn(cfg2.Callback, key) end
                end
            end)

            if cfg2.Flag then Onyx.Flags[cfg2.Flag] = obj end
            return obj
        end

        return Tab
    end

    function Window:Destroy()
        Onyx:Destroy()
    end

    table.insert(Onyx.Windows, Window)
    return Window
end

function Onyx:Destroy()
    for _, conn in ipairs(Onyx._connections) do
        pcall(function() conn:Disconnect() end)
    end
    Onyx._connections = {}
    if RootGui then RootGui:Destroy() end
end

return Onyx
