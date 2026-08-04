# UI — custom Roblox executor UI libraries

Ten original, single-file UI libraries for Roblox executors. Inspired by the API families in
[Eazvy/UILibs](https://github.com/Eazvy/UILibs) but written from scratch — every library is
self-contained, dependency-free, and executor-safe (`gethui` → `syn.protect_gui` → `CoreGui` → `PlayerGui` fallback).

## The collection

| Library | Style | Signature |
|---|---|---|
| [Nova](Nova) | Modern dark hub (Rayfield-like) | Indigo sidebar tabs, animated pill toggles, toast notifications |
| [Vectra](Vectra) | Cheat menu (Linoria-like) | Left/right groupboxes, global flag registry, HSV color picker |
| [Pulse](Pulse) | Cyberpunk neon | Cyan/magenta glow pulses, animated underline that slides between tabs |
| [Glacier](Glacier) | Frosted glassmorphism | Translucent glass panes, pill tabs, hover "condensation" |
| [Phosphor](Phosphor) | Retro CRT terminal | Green phosphor, ASCII sliders, `[ON]/[OFF]` toggles, number-key tab switching, boot sequence |
| [Solstice](Solstice) | Light paper | White cards with coral left-edge accents — a light theme in a sea of dark ones |
| [Onyx](Onyx) | Discord-style | Icon rail tabs, `#` channel sections with scroll-to-section |
| [Ember](Ember) | Warm dashboard | Two-column tile grid; tiles glow ember-orange when enabled |
| [Zenith](Zenith) | Mobile-first portrait | Bottom tab bar, big touch targets, collapses into a draggable bubble |
| [Spectra](Spectra) | HUD module list (Vape-like) | Watermark + rainbow enabled-modules list + floating category panels |

Each folder contains:
- `<Name>.lua` — the library (loadstring-able, returns the library table)
- `Example.lua` — demos every element
- `Demo.lua` — **paste-and-run bundle** (library + demo in one file, no `readfile` needed)

## Quick start

Easiest — paste-and-run: open any `Demo.lua`, copy the whole file into your executor, execute.

From your executor's workspace folder:

```lua
local Nova = loadstring(readfile("UI/Nova/Nova.lua"))()
```

From GitHub raw:

```lua
local Nova = loadstring(game:HttpGet("https://raw.githubusercontent.com/SmokeTY/UI/main/UI/Nova/Nova.lua"))()
```

## Shared API

All ten libraries share the same core API shape (Vectra keeps its Linoria-style groupbox variant):

```lua
local Lib = loadstring(readfile("UI/<Name>/<Name>.lua"))()

local Window = Lib:CreateWindow({ Name = "My Hub", ToggleKey = Enum.KeyCode.RightShift })
local Tab = Window:CreateTab("Main")

Tab:CreateSection("FARMING")
Tab:CreateLabel("text")                                                    -- :Set(text)
Tab:CreateButton({ Name = "...", Callback = function() end })
Tab:CreateToggle({ Name = "...", Default = false, Flag = "X", Callback = function(v) end })
Tab:CreateSlider({ Name = "...", Min = 0, Max = 100, Increment = 1, Suffix = "", Default = 0, Flag = "Y", Callback = function(v) end })
Tab:CreateDropdown({ Name = "...", Options = {...}, Default = "...", Flag = "Z", Callback = function(opt) end })  -- :Refresh(opts)
Tab:CreateInput({ Name = "...", Placeholder = "...", Callback = function(text, enter) end })
Tab:CreateKeybind({ Name = "...", Default = Enum.KeyCode.F, Callback = function() end })   -- Escape clears

Lib:Notify({ Title = "...", Content = "...", Duration = 4 })
Lib.Flags.X:Get()  /  Lib.Flags.X:Set(v)
Lib:SaveConfig("name")  /  Lib:LoadConfig("name")   -- JSON, needs executor file API
Lib:Destroy()
```

Because the API is shared, you can reskin a script by swapping which library you load.

## Notes

- All files are syntax-checked with `luau-compile`; in-game behavior should be tested in your executor.
- Windows are draggable, mobile/touch input is supported on drags and sliders (Zenith is fully touch-first).
- Config saving needs `writefile`/`readfile`/`isfile` (most modern executors have them); it silently no-ops otherwise.
