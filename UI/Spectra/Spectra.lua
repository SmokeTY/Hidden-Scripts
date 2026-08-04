--[[
    Spectra UI Library v1.0
    HUD / module-list style library for Roblox executors (Vape/Impact-like)

    Not a single window: Spectra is a HUD system.
      - Watermark pill (top-left) with rainbow edge bar, clock + fps
      - Module list (top-right): enabled toggles, sorted by text width,
        rainbow accent bars with per-index hue cascade
      - Click GUI: ToggleKey (default RightShift) shows/hides floating
        draggable category panels (one per Tab)

    Usage:
        local Spectra = loadstring(readfile("UI/Spectra/Spectra.lua"))()
        local Window = Spectra:CreateWindow({ Name = "title", ToggleKey = Enum.KeyCode.RightShift })
        local Tab = Window:CreateTab("Combat")
        Tab:CreateToggle({ Name = "Killaura", Default = false, Flag = "KA", Callback = function(v) end, Bind = Enum.KeyCode.R })

    Elements: Section, Label, Button, Toggle, Slider, Dropdown (click-to-cycle),
              Input, Keybind
    Extras:   Spectra:Notify, Spectra.Flags, Spectra:SaveConfig / LoadConfig,
              Spectra:SetWatermarkVisible / SetModuleListVisible,
              Spectra.RainbowSpeed (seconds per hue cycle), Spectra:Destroy
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer

local Spectra = {
    Flags = {},
    ToggleKey = Enum.KeyCode.RightShift,
    ConfigFolder = "SpectraUI",
    RainbowSpeed = 8, -- seconds per full hue cycle
    Destroyed = false,
}

-- // Theme ------------------------------------------------------------------
local Theme = {
    Background     = Color3.fromRGB(12, 12, 14),
    BgTransparency = 0.15,
    Element        = Color3.fromRGB(24, 24, 29),
    Text           = Color3.fromRGB(240, 240, 245),
    Dim            = Color3.fromRGB(140, 140, 150),
    Stroke         = Color3.fromRGB(44, 44, 52),
    Font           = Enum.Font.Gotham,
    FontMed        = Enum.Font.GothamMedium,
    FontBold       = Enum.Font.GothamBold,
}
Spectra.Theme = Theme

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
    return New("UICorner", { CornerRadius = UDim.new(0, radius or 4), Parent = inst })
end

local function Stroke(inst, color)
    return New("UIStroke", {
        Color = color or Theme.Stroke,
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

local function KeyName(keyCode)
    if not keyCode then return "NONE" end
    return keyCode.Name:upper()
end

-- central connection registry so Destroy can drop everything
local Connections = {}
local function Connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Connections, c)
    return c
end

-- // Root gui ---------------------------------------------------------------
local RootGui = New("ScreenGui", {
    Name = "SpectraUI_" .. HttpService:GenerateGUID(false):sub(1, 8),
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    -- IgnoreGuiInset stays false (shared coordinate space with input positions)
})
ProtectGui(RootGui)

-- layer that holds the floating category panels; ToggleKey hides only this
local PanelLayer = New("Frame", {
    Name = "Panels",
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0),
    Visible = true,
    Parent = RootGui,
})

-- // Rainbow engine ---------------------------------------------------------
-- RainbowBars : set of frames tinted with the base hue every frame
-- ActiveFills : set of toggle fill frames tinted with a dark rainbow
-- SortedEntries : module-list entries; each bar hue offset by its index
local RainbowBars = {}
local ActiveFills = {}
local SortedEntries = {}

-- // Watermark --------------------------------------------------------------
local WatermarkTitle = "SPECTRA"

local Watermark = New("Frame", {
    Name = "Watermark",
    Position = UDim2.new(0, 14, 0, 14),
    Size = UDim2.new(0, 0, 0, 26),
    AutomaticSize = Enum.AutomaticSize.X,
    BackgroundColor3 = Theme.Background,
    BackgroundTransparency = Theme.BgTransparency,
    BorderSizePixel = 0,
    Parent = RootGui,
})
Round(Watermark, 6)
Stroke(Watermark)

local WatermarkBar = New("Frame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(0, 3, 1, 0),
    BackgroundColor3 = Color3.fromHSV(0, 0.75, 1),
    BorderSizePixel = 0,
    Parent = Watermark,
})
Round(WatermarkBar, 6)
RainbowBars[WatermarkBar] = true

local WatermarkLabel = New("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 13, 0, 0),
    Size = UDim2.new(0, 0, 1, 0),
    AutomaticSize = Enum.AutomaticSize.X,
    Font = Theme.FontBold,
    RichText = true,
    Text = "<b>SPECTRA</b>",
    TextColor3 = Theme.Text,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = Watermark,
})
New("UIPadding", { PaddingRight = UDim.new(0, 12), Parent = Watermark })

-- // Module list (signature HUD) --------------------------------------------
local ModuleListHolder = New("Frame", {
    Name = "ModuleList",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -8, 0, 8),
    Size = UDim2.new(0, 280, 1, -16),
    BackgroundTransparency = 1,
    Parent = RootGui,
}, {
    New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        Padding = UDim.new(0, 3),
    }),
})

local ModuleEntries = {} -- name -> { Name, Width, Frame, Bar, Label }

local function ResortModules()
    SortedEntries = {}
    for _, entry in pairs(ModuleEntries) do
        table.insert(SortedEntries, entry)
    end
    table.sort(SortedEntries, function(a, b)
        if a.Width ~= b.Width then return a.Width > b.Width end -- longest first
        return a.Name < b.Name
    end)
    for i, entry in ipairs(SortedEntries) do
        entry.Frame.LayoutOrder = i
    end
end

local function AddModule(name)
    if ModuleEntries[name] then return end
    -- GetTextSize is safe even for labels not yet in the tree (unlike TextBounds)
    local width = math.floor(TextService:GetTextSize(name, 13, Theme.FontBold, Vector2.new(1000, 20)).X + 0.5) + 2

    local frame = New("Frame", {
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = Theme.BgTransparency,
        Size = UDim2.new(0, 0, 0, 20),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = ModuleListHolder,
    })
    Round(frame, 3)

    local label = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 7, 0, 0),
        Size = UDim2.new(1, -13, 1, 0),
        Font = Theme.FontBold,
        Text = name,
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = frame,
    })
    local bar = New("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 2, 1, 0),
        BackgroundColor3 = Color3.fromHSV(0, 0.75, 1),
        BorderSizePixel = 0,
        Parent = frame,
    })

    ModuleEntries[name] = { Name = name, Width = width, Frame = frame, Bar = bar, Label = label }
    ResortModules()
    Tween(frame, { Size = UDim2.new(0, width + 16, 0, 20) }, 0.22)
    Tween(label, { TextTransparency = 0 }, 0.22)
end

local function RemoveModule(name)
    local entry = ModuleEntries[name]
    if not entry then return end
    ModuleEntries[name] = nil
    ResortModules()
    local frame, label = entry.Frame, entry.Label
    Tween(frame, { Size = UDim2.new(0, 0, 0, 20) }, 0.18)
    Tween(label, { TextTransparency = 1 }, 0.14)
    task.delay(0.2, function()
        if frame.Parent then frame:Destroy() end
    end)
end

-- // Notifications (bottom-right, rainbow bar) -------------------------------
local NotifHolder = New("Frame", {
    Name = "Notifications",
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -14, 1, -14),
    Size = UDim2.new(0, 270, 0, 500),
    BackgroundTransparency = 1,
    Parent = RootGui,
}, {
    New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, 6),
    }),
})

function Spectra:Notify(cfg)
    cfg = cfg or {}
    local duration = cfg.Duration or 4

    local frame = New("Frame", {
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Parent = NotifHolder,
    })
    Round(frame, 5)
    Stroke(frame)

    local bar = New("Frame", {
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = Color3.fromHSV(0, 0.75, 1),
        BorderSizePixel = 0,
        Parent = frame,
    })
    Round(bar, 5)
    RainbowBars[bar] = true

    local title = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 13, 0, 7),
        Size = UDim2.new(1, -21, 0, 16),
        Font = Theme.FontBold,
        Text = cfg.Title or "Spectra",
        TextColor3 = Theme.Text,
        TextSize = 13,
        TextTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = frame,
    })
    local body = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 13, 0, 24),
        Size = UDim2.new(1, -21, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Theme.Font,
        Text = cfg.Content or "",
        TextColor3 = Theme.Dim,
        TextSize = 12,
        TextTransparency = 1,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = frame,
    })
    New("UIPadding", { PaddingBottom = UDim.new(0, 9), Parent = frame })

    Tween(frame, { BackgroundTransparency = Theme.BgTransparency }, 0.22)
    Tween(title, { TextTransparency = 0 }, 0.22)
    Tween(body, { TextTransparency = 0.1 }, 0.22)

    task.delay(duration, function()
        if not frame.Parent then
            RainbowBars[bar] = nil
            return
        end
        Tween(frame, { BackgroundTransparency = 1 }, 0.25)
        Tween(title, { TextTransparency = 1 }, 0.25)
        Tween(body, { TextTransparency = 1 }, 0.25)
        Tween(bar, { BackgroundTransparency = 1 }, 0.25)
        task.wait(0.28)
        RainbowBars[bar] = nil
        frame:Destroy()
    end)
end

-- // Rainbow / fps / clock update loop ---------------------------------------
local fps = 60
local wmAccum = 1 -- force immediate first watermark refresh

local RainbowConn
RainbowConn = RunService.Heartbeat:Connect(function(dt)
    if dt > 0 then
        fps = fps + (1 / dt - fps) * math.clamp(dt * 4, 0, 1) -- smoothed
    end

    local speed = Spectra.RainbowSpeed
    if typeof(speed) ~= "number" or speed <= 0 then speed = 8 end
    local hue = (os.clock() % speed) / speed
    local base = Color3.fromHSV(hue, 0.75, 1)

    for barFrame in pairs(RainbowBars) do
        barFrame.BackgroundColor3 = base
    end
    for fillFrame in pairs(ActiveFills) do
        fillFrame.BackgroundColor3 = Color3.fromHSV(hue, 0.65, 0.45)
    end
    for i, entry in ipairs(SortedEntries) do -- cascade: hue offset per index
        entry.Bar.BackgroundColor3 = Color3.fromHSV((hue + i * 0.05) % 1, 0.75, 1)
    end

    wmAccum = wmAccum + dt
    if wmAccum >= 0.2 then
        wmAccum = 0
        WatermarkLabel.Text = string.format(
            '<b>%s</b>  <font color="#9AA0AC">%d fps  •  %s</font>',
            WatermarkTitle, math.floor(fps + 0.5), os.date("%H:%M:%S")
        )
    end
end)

-- // Visibility API ----------------------------------------------------------
function Spectra:SetWatermarkVisible(visible)
    Watermark.Visible = visible and true or false
end

function Spectra:SetModuleListVisible(visible)
    ModuleListHolder.Visible = visible and true or false
end

-- // Drag helper (with click-vs-drag detection for header collapse) ----------
local function MakeDraggable(handle, target, onClick)
    local dragging = false
    local dragInput, dragStart, startPos
    local moved = 0

    Connect(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = 0
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if moved < 5 and onClick then -- click without drag
                        task.spawn(onClick)
                    end
                end
            end)
        end
    end)
    Connect(handle.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    Connect(UserInputService.InputChanged, function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            moved = math.max(moved, delta.Magnitude)
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- // ToggleKey: show/hide the click gui (panels only; HUD stays) -------------
Connect(UserInputService.InputBegan, function(input, gameProcessed)
    if gameProcessed then return end
    if UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Spectra.ToggleKey then
        PanelLayer.Visible = not PanelLayer.Visible
    end
end)

-- // Window -----------------------------------------------------------------
function Spectra:CreateWindow(cfg)
    cfg = cfg or {}
    if cfg.ToggleKey then Spectra.ToggleKey = cfg.ToggleKey end
    if cfg.Name then WatermarkTitle = tostring(cfg.Name):upper() end

    local Window = { Tabs = {}, Gui = RootGui }

    -- // Tab = floating category panel ---------------------------------------
    function Window:CreateTab(tabName)
        tabName = tabName or "Category"
        local index = #Window.Tabs

        local Panel = New("Frame", {
            Name = "Category_" .. tabName,
            Position = UDim2.new(0, 16 + index * 192, 0, 56),
            Size = UDim2.new(0, 180, 0, 27),
            BackgroundColor3 = Theme.Background,
            BackgroundTransparency = Theme.BgTransparency,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Parent = PanelLayer,
        })
        Round(Panel, 5)
        Stroke(Panel)

        local Header = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 26),
            Parent = Panel,
        })
        New("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 9, 0, 0),
            Size = UDim2.new(1, -30, 1, 0),
            Font = Theme.FontBold,
            Text = tabName,
            TextColor3 = Theme.Text,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Header,
        })
        local Arrow = New("TextLabel", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -8, 0, 0),
            Size = UDim2.new(0, 14, 1, 0),
            BackgroundTransparency = 1,
            Font = Theme.FontBold,
            Text = "▾",
            TextColor3 = Theme.Dim,
            TextSize = 12,
            Parent = Header,
        })
        local HeaderLine = New("Frame", { -- rainbow underline
            Position = UDim2.new(0, 0, 0, 26),
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Color3.fromHSV(0, 0.75, 1),
            BorderSizePixel = 0,
            Parent = Panel,
        })
        RainbowBars[HeaderLine] = true

        local Body = New("ScrollingFrame", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 27),
            Size = UDim2.new(1, 0, 0, 0),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.Stroke,
            BorderSizePixel = 0,
            Parent = Panel,
        }, {
            New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 6),
                PaddingRight = UDim.new(0, 6),
                PaddingTop = UDim.new(0, 6),
                PaddingBottom = UDim.new(0, 8),
            }),
        })
        local BodyLayout = Body:FindFirstChildOfClass("UIListLayout")

        local collapsed = false
        local MAX_BODY = 340

        local function UpdatePanelSize(animate)
            local content = BodyLayout.AbsoluteContentSize.Y + 14 -- + top/bottom padding
            local bodyH = math.min(content, MAX_BODY)
            Body.Size = UDim2.new(1, 0, 0, bodyH)
            local target = UDim2.new(0, 180, 0, collapsed and 27 or (27 + bodyH))
            if animate then
                Tween(Panel, { Size = target }, 0.2)
            else
                Panel.Size = target
            end
        end
        Connect(BodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
            if not collapsed then UpdatePanelSize(false) end
        end)

        -- header drags the panel; a click (< 5px movement) collapses/expands
        MakeDraggable(Header, Panel, function()
            collapsed = not collapsed
            Body.Visible = not collapsed
            Tween(Arrow, { Rotation = collapsed and -90 or 0 }, 0.18)
            UpdatePanelSize(true)
        end)

        local Tab = { Name = tabName, Panel = Panel, Body = Body }
        table.insert(Window.Tabs, Tab)

        -- // shared element base (compact 24px rows) ---------------------------
        local function ElementBase(height)
            local frame = New("Frame", {
                BackgroundColor3 = Theme.Element,
                BackgroundTransparency = 0.25,
                Size = UDim2.new(1, 0, 0, height),
                BorderSizePixel = 0,
                Parent = Body,
            })
            Round(frame, 4)
            return frame
        end

        local function HoverFX(frame)
            frame.MouseEnter:Connect(function() Tween(frame, { BackgroundTransparency = 0.05 }) end)
            frame.MouseLeave:Connect(function() Tween(frame, { BackgroundTransparency = 0.25 }) end)
        end

        -- // Section (small dim header row)
        function Tab:CreateSection(text)
            local lbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 16),
                Font = Theme.FontBold,
                Text = tostring(text):upper(),
                TextColor3 = Theme.Dim,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = Body,
            })
            local obj = {}
            function obj:Set(t) lbl.Text = tostring(t):upper() end
            return obj
        end

        -- // Label
        function Tab:CreateLabel(text)
            local lbl = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                Font = Theme.Font,
                Text = tostring(text),
                TextColor3 = Theme.Dim,
                TextSize = 12,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = Body,
            })
            local obj = {}
            function obj:Set(t) lbl.Text = tostring(t) end
            return obj
        end

        -- // Button
        function Tab:CreateButton(cfg2)
            cfg2 = cfg2 or {}
            local frame = ElementBase(24)
            HoverFX(frame)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 0),
                Size = UDim2.new(1, -28, 1, 0),
                Font = Theme.FontMed,
                Text = cfg2.Name or "Button",
                TextColor3 = Theme.Text,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            New("TextLabel", {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -8, 0, 0),
                Size = UDim2.new(0, 12, 1, 0),
                BackgroundTransparency = 1,
                Font = Theme.FontBold,
                Text = "»",
                TextColor3 = Theme.Dim,
                TextSize = 12,
                Parent = frame,
            })
            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                ZIndex = 3,
                Parent = frame,
            })
            click.MouseButton1Click:Connect(function()
                Tween(frame, { BackgroundColor3 = Theme.Stroke }, 0.06)
                task.delay(0.09, function()
                    Tween(frame, { BackgroundColor3 = Theme.Element }, 0.18)
                end)
                if cfg2.Callback then task.spawn(cfg2.Callback) end
            end)
            return { Frame = frame }
        end

        -- // Toggle (row fills with dark rainbow when on; feeds the module list)
        function Tab:CreateToggle(cfg2)
            cfg2 = cfg2 or {}
            local name = cfg2.Name or "Toggle"
            local state = false

            local frame = ElementBase(24)
            local fill = New("Frame", {
                BackgroundColor3 = Color3.fromHSV(0, 0.65, 0.45),
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                BorderSizePixel = 0,
                Parent = frame,
            })
            Round(fill, 4)
            local label = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 0),
                Size = UDim2.new(1, -58, 1, 0),
                Font = Theme.FontMed,
                Text = name,
                TextColor3 = Theme.Dim,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2,
                Parent = frame,
            })
            if cfg2.Bind then
                New("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, -6, 0, 0),
                    Size = UDim2.new(0, 46, 1, 0),
                    BackgroundTransparency = 1,
                    Font = Theme.Font,
                    Text = "[" .. KeyName(cfg2.Bind) .. "]",
                    TextColor3 = Theme.Dim,
                    TextSize = 10,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 2,
                    Parent = frame,
                })
            end

            local obj = {}
            local function render()
                if state then
                    ActiveFills[fill] = true
                    Tween(fill, { BackgroundTransparency = 0.25 }, 0.15)
                    Tween(label, { TextColor3 = Theme.Text }, 0.15)
                    AddModule(name)
                else
                    ActiveFills[fill] = nil
                    Tween(fill, { BackgroundTransparency = 1 }, 0.15)
                    Tween(label, { TextColor3 = Theme.Dim }, 0.15)
                    RemoveModule(name)
                end
            end
            function obj:Set(v)
                v = v and true or false
                if v == state then return end
                state = v
                render()
                if cfg2.Callback then task.spawn(cfg2.Callback, state) end
            end
            function obj:Get() return state end

            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                ZIndex = 3,
                Parent = frame,
            })
            click.MouseButton1Click:Connect(function() obj:Set(not state) end)

            -- optional global keybind: toggles even while the click gui is closed
            if cfg2.Bind then
                Connect(UserInputService.InputBegan, function(input, gameProcessed)
                    if gameProcessed then return end
                    if UserInputService:GetFocusedTextBox() then return end
                    if input.KeyCode == cfg2.Bind then
                        obj:Set(not state)
                    end
                end)
            end

            if cfg2.Flag then Spectra.Flags[cfg2.Flag] = obj end
            if cfg2.Default then obj:Set(true) end
            return obj
        end

        -- // Slider (thin bar under the row label)
        function Tab:CreateSlider(cfg2)
            cfg2 = cfg2 or {}
            local min = cfg2.Min or 0
            local max = cfg2.Max or 100
            local increment = cfg2.Increment or 1
            local suffix = cfg2.Suffix or ""
            local value = math.clamp(cfg2.Default or min, min, max)

            local frame = ElementBase(34)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 3),
                Size = UDim2.new(1, -86, 0, 14),
                Font = Theme.FontMed,
                Text = cfg2.Name or "Slider",
                TextColor3 = Theme.Text,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local valueLabel = New("TextLabel", {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -8, 0, 3),
                Size = UDim2.new(0, 74, 0, 14),
                BackgroundTransparency = 1,
                Font = Theme.Font,
                Text = "",
                TextColor3 = Theme.Dim,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = frame,
            })
            local bar = New("Frame", {
                Position = UDim2.new(0, 8, 1, -10),
                Size = UDim2.new(1, -16, 0, 4),
                BackgroundColor3 = Theme.Stroke,
                BorderSizePixel = 0,
                Parent = frame,
            })
            Round(bar, 2)
            local fill = New("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = Color3.fromHSV(0, 0.75, 1),
                BorderSizePixel = 0,
                Parent = bar,
            })
            Round(fill, 2)
            RainbowBars[fill] = true

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
            frame.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    updateFromInput(input)
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
            if cfg2.Flag then Spectra.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Dropdown (click-to-cycle: "< value >")
        function Tab:CreateDropdown(cfg2)
            cfg2 = cfg2 or {}
            local options = cfg2.Options or {}
            local idx = 1
            if cfg2.Default then
                for i, opt in ipairs(options) do
                    if opt == cfg2.Default then idx = i break end
                end
            end

            local frame = ElementBase(24)
            HoverFX(frame)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 0),
                Size = UDim2.new(0.45, -8, 1, 0),
                Font = Theme.FontMed,
                Text = cfg2.Name or "Dropdown",
                TextColor3 = Theme.Text,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local valueLabel = New("TextLabel", {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -8, 0, 0),
                Size = UDim2.new(0.55, -8, 1, 0),
                BackgroundTransparency = 1,
                Font = Theme.Font,
                Text = "",
                TextColor3 = Theme.Dim,
                TextSize = 11,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = frame,
            })

            local obj = {}
            local function render()
                local current = options[idx]
                valueLabel.Text = current ~= nil and ("<  " .. tostring(current) .. "  >") or "<  none  >"
            end
            function obj:Set(opt)
                for i, o in ipairs(options) do
                    if o == opt then
                        local changed = (i ~= idx)
                        idx = i
                        render()
                        if changed and cfg2.Callback then task.spawn(cfg2.Callback, o) end
                        return
                    end
                end
            end
            function obj:Get() return options[idx] end
            function obj:Refresh(newOptions, keepSelection)
                local current = options[idx]
                options = newOptions or {}
                idx = 1
                if keepSelection then
                    for i, o in ipairs(options) do
                        if o == current then idx = i break end
                    end
                end
                render()
            end

            local click = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                ZIndex = 3,
                Parent = frame,
            })
            click.MouseButton1Click:Connect(function() -- click = next option
                if #options == 0 then return end
                idx = idx % #options + 1
                render()
                if cfg2.Callback then task.spawn(cfg2.Callback, options[idx]) end
            end)

            render()
            if cfg2.Flag then Spectra.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Input (compact textbox row)
        function Tab:CreateInput(cfg2)
            cfg2 = cfg2 or {}
            local frame = ElementBase(24)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 0),
                Size = UDim2.new(0.45, -8, 1, 0),
                Font = Theme.FontMed,
                Text = cfg2.Name or "Input",
                TextColor3 = Theme.Text,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local boxHolder = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -5, 0.5, 0),
                Size = UDim2.new(0.55, -8, 0, 18),
                BackgroundColor3 = Theme.Background,
                BackgroundTransparency = 0.1,
                BorderSizePixel = 0,
                Parent = frame,
            })
            Round(boxHolder, 3)
            Stroke(boxHolder)
            local box = New("TextBox", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 5, 0, 0),
                Size = UDim2.new(1, -10, 1, 0),
                Font = Theme.Font,
                Text = cfg2.Default or "",
                PlaceholderText = cfg2.Placeholder or "…",
                PlaceholderColor3 = Theme.Dim,
                TextColor3 = Theme.Text,
                TextSize = 11,
                ClearTextOnFocus = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = boxHolder,
            })
            box.FocusLost:Connect(function(enterPressed)
                if cfg2.Callback then task.spawn(cfg2.Callback, box.Text, enterPressed) end
            end)
            local obj = {}
            function obj:Set(t)
                box.Text = tostring(t)
                if cfg2.Callback then task.spawn(cfg2.Callback, box.Text, false) end
            end
            function obj:Get() return box.Text end
            if cfg2.Flag then Spectra.Flags[cfg2.Flag] = obj end
            return obj
        end

        -- // Keybind (right-aligned [KEY]; fires callback globally)
        function Tab:CreateKeybind(cfg2)
            cfg2 = cfg2 or {}
            local key = cfg2.Default -- Enum.KeyCode or nil
            local listening = false

            local frame = ElementBase(24)
            HoverFX(frame)
            New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 0),
                Size = UDim2.new(1, -74, 1, 0),
                Font = Theme.FontMed,
                Text = cfg2.Name or "Keybind",
                TextColor3 = Theme.Text,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local keyBtn = New("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -5, 0.5, 0),
                Size = UDim2.new(0, 60, 0, 18),
                BackgroundColor3 = Theme.Background,
                BackgroundTransparency = 0.1,
                Font = Theme.Font,
                Text = "[" .. KeyName(key) .. "]",
                TextColor3 = Theme.Dim,
                TextSize = 10,
                AutoButtonColor = false,
                ZIndex = 3,
                Parent = frame,
            })
            Round(keyBtn, 3)
            Stroke(keyBtn)

            local obj = {}
            function obj:Set(newKey)
                key = newKey
                keyBtn.Text = "[" .. KeyName(key) .. "]"
            end
            function obj:Get() return key end

            keyBtn.MouseButton1Click:Connect(function()
                listening = true
                keyBtn.Text = "[...]"
                keyBtn.TextColor3 = Theme.Text
            end)

            Connect(UserInputService.InputBegan, function(input, gameProcessed)
                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    listening = false
                    keyBtn.TextColor3 = Theme.Dim
                    if input.KeyCode == Enum.KeyCode.Escape then
                        obj:Set(nil)
                    else
                        obj:Set(input.KeyCode)
                    end
                    return
                end
                if gameProcessed then return end
                if UserInputService:GetFocusedTextBox() then return end
                if key and input.KeyCode == key then
                    if cfg2.Callback then task.spawn(cfg2.Callback, key) end
                end
            end)

            if cfg2.Flag then Spectra.Flags[cfg2.Flag] = obj end
            return obj
        end

        UpdatePanelSize(false)
        return Tab
    end

    function Window:Destroy()
        Spectra:Destroy()
    end

    return Window
end

-- // Config saving ------------------------------------------------------------
local function CanUseFiles()
    return typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"
end

function Spectra:SaveConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local data = {}
    for flag, obj in pairs(Spectra.Flags) do
        local v = obj:Get()
        if typeof(v) == "EnumItem" then
            data[flag] = { __keycode = v.Name }
        elseif typeof(v) == "Color3" then
            data[flag] = { __color = { v.R, v.G, v.B } }
        elseif typeof(v) == "boolean" or typeof(v) == "number" or typeof(v) == "string" then
            data[flag] = v
        end
    end
    if typeof(isfolder) == "function" and typeof(makefolder) == "function" and not isfolder(Spectra.ConfigFolder) then
        makefolder(Spectra.ConfigFolder)
    end
    writefile(Spectra.ConfigFolder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    return true
end

function Spectra:LoadConfig(name)
    if not CanUseFiles() then return false, "executor has no file API" end
    name = name or "default"
    local path = Spectra.ConfigFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false, "no config file" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok then return false, "corrupt config" end
    for flag, v in pairs(data) do
        local obj = Spectra.Flags[flag]
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

-- // Destroy -------------------------------------------------------------------
function Spectra:Destroy()
    if Spectra.Destroyed then return end
    Spectra.Destroyed = true
    if RainbowConn then
        RainbowConn:Disconnect() -- stop the rainbow/fps loop
        RainbowConn = nil
    end
    for _, c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(Connections)
    table.clear(RainbowBars)
    table.clear(ActiveFills)
    table.clear(SortedEntries)
    RootGui:Destroy()
end

return Spectra
