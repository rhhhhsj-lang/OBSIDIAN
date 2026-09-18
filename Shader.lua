-- ============================================================
-- OBSIDIAN REALISTIC SHADER v3
-- Pro GUI + Mobile Optimized
-- ============================================================

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

print("[SHADER] loading...")

-- Cleanup
for _, v in ipairs(Lighting:GetChildren()) do
    if v.Name:find("OBS_SHADER") then v:Destroy() end
end

-- ============================================================
-- STATE
-- ============================================================
local State = {
    enabled = { bloom = true, cc = true, dof = true, sun = true, atmos = true },
    values = {
        bloomIntensity = 0.85, bloomSize = 32, bloomThreshold = 1.05,
        ccBrightness = 0.02, ccContrast = 0.22, ccSaturation = 0.16,
        dofFar = 0.15, dofDistance = 35, dofRadius = 75,
        sunIntensity = 0.14, sunSpread = 0.88,
        atmosDensity = 0.38, atmosHaze = 2.2, atmosGlare = 0.45,
        brightness = 2.4, clockTime = 14.5, fogEnd = 2400, fogStart = 320,
    },
}

-- ============================================================
-- EFFECTS
-- ============================================================
local atmos = Instance.new("Atmosphere")
atmos.Name = "OBS_SHADER_ATMOS"
atmos.Density = State.values.atmosDensity
atmos.Offset = 0.15
atmos.Color = Color3.fromRGB(210, 220, 235)
atmos.Decay = Color3.fromRGB(95, 105, 125)
atmos.Glare = State.values.atmosGlare
atmos.Haze = State.values.atmosHaze
atmos.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Name = "OBS_SHADER_BLOOM"
bloom.Intensity = State.values.bloomIntensity
bloom.Size = State.values.bloomSize
bloom.Threshold = State.values.bloomThreshold
bloom.Parent = Lighting

local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "OBS_SHADER_CC"
cc.Brightness = State.values.ccBrightness
cc.Contrast = State.values.ccContrast
cc.Saturation = State.values.ccSaturation
cc.TintColor = Color3.fromRGB(255, 253, 248)
cc.Parent = Lighting

local sunRays = Instance.new("SunRaysEffect")
sunRays.Name = "OBS_SHADER_SUN"
sunRays.Intensity = State.values.sunIntensity
sunRays.Spread = State.values.sunSpread
sunRays.Parent = Lighting

local dof = Instance.new("DepthOfFieldEffect")
dof.Name = "OBS_SHADER_DOF"
dof.FarIntensity = State.values.dofFar
dof.FocusDistance = State.values.dofDistance
dof.InFocusRadius = State.values.dofRadius
dof.NearIntensity = 0.08
dof.Parent = Lighting

-- Sky
local oldSky = Lighting:FindFirstChildOfClass("Sky")
if oldSky then oldSky:Destroy() end

local sky = Instance.new("Sky")
sky.Name = "OBS_SHADER_SKY"
sky.SkyboxBk = "rbxassetid://159454299"
sky.SkyboxDn = "rbxassetid://159454296"
sky.SkyboxFt = "rbxassetid://159454293"
sky.SkyboxLf = "rbxassetid://159454286"
sky.SkyboxRt = "rbxassetid://159454300"
sky.SkyboxUp = "rbxassetid://159454288"
sky.SunAngularSize = 22
sky.MoonAngularSize = 14
sky.StarCount = 3000
sky.Parent = Lighting

-- Base Lighting
Lighting.Ambient = Color3.fromRGB(72, 76, 88)
Lighting.OutdoorAmbient = Color3.fromRGB(132, 138, 155)
Lighting.Brightness = State.values.brightness
Lighting.ClockTime = State.values.clockTime
Lighting.GeographicLatitude = 12
Lighting.ExposureCompensation = 0.15
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.32
Lighting.EnvironmentDiffuseScale = 0.55
Lighting.EnvironmentSpecularScale = 0.78
Lighting.FogEnd = State.values.fogEnd
Lighting.FogStart = State.values.fogStart
Lighting.FogColor = Color3.fromRGB(185, 195, 215)

-- ============================================================
-- APPLY FUNCTIONS
-- ============================================================
local function applyPreset(name)
    if name == "Bright Day" then
        Lighting.ClockTime = 14
        Lighting.Brightness = 2.5
        atmos.Density = 0.35
        atmos.Haze = 2
        atmos.Color = Color3.fromRGB(210, 220, 235)
        atmos.Decay = Color3.fromRGB(95, 105, 125)
        cc.TintColor = Color3.fromRGB(255, 252, 245)
        cc.Contrast = 0.2
        cc.Saturation = 0.14
    elseif name == "Golden Sunset" then
        Lighting.ClockTime = 18.2
        Lighting.Brightness = 2.1
        atmos.Color = Color3.fromRGB(255, 200, 150)
        atmos.Decay = Color3.fromRGB(180, 100, 60)
        cc.TintColor = Color3.fromRGB(255, 220, 180)
        cc.Saturation = 0.22
        cc.Contrast = 0.25
    elseif name == "Dusk" then
        Lighting.ClockTime = 19.5
        Lighting.Brightness = 1.6
        atmos.Color = Color3.fromRGB(120, 100, 160)
        atmos.Decay = Color3.fromRGB(60, 50, 90)
        cc.TintColor = Color3.fromRGB(180, 160, 220)
    elseif name == "Night" then
        Lighting.ClockTime = 23
        Lighting.Brightness = 1.3
        Lighting.FogEnd = 1600
        atmos.Color = Color3.fromRGB(60, 75, 110)
        atmos.Decay = Color3.fromRGB(25, 35, 55)
        cc.TintColor = Color3.fromRGB(170, 190, 230)
    elseif name == "Misty Morning" then
        Lighting.ClockTime = 6.8
        Lighting.Brightness = 1.9
        Lighting.FogEnd = 700
        Lighting.FogStart = 60
        atmos.Density = 0.55
        atmos.Haze = 3.5
        cc.TintColor = Color3.fromRGB(230, 240, 250)
    elseif name == "Cinematic" then
        cc.Contrast = 0.32
        cc.Saturation = 0.24
        cc.Brightness = -0.02
        dof.FarIntensity = 0.25
        dof.FocusDistance = 28
        bloom.Intensity = 1.1
        bloom.Size = 38
    elseif name == "Anime" then
        cc.Saturation = 0.45
        cc.Contrast = 0.18
        cc.Brightness = 0.05
        bloom.Intensity = 0.4
        bloom.Threshold = 1.3
        dof.FarIntensity = 0.05
    end
end

-- ============================================================
-- GUI - MOBILE OPTIMIZED
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OBS_SHADER"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local vp = Camera.ViewportSize
local FW = math.clamp(vp.X * 0.92, 300, 400)
local FH = math.clamp(vp.Y * 0.75, 450, 580)

-- Floating Icon
local Icon = Instance.new("ImageButton")
Icon.Size = UDim2.new(0, 48, 0, 48)
Icon.Position = UDim2.new(0, 15, 0, 100)
Icon.BackgroundColor3 = Color3.fromRGB(20, 28, 38)
Icon.BackgroundTransparency = 0.15
Icon.BorderSizePixel = 0
Icon.AutoButtonColor = false
Icon.Active = true
Icon.Parent = ScreenGui
local IC = Instance.new("UICorner") IC.CornerRadius = UDim.new(1, 0) IC.Parent = Icon
local IStr = Instance.new("UIStroke") IStr.Color = Color3.fromRGB(120, 200, 255) IStr.Thickness = 2 IStr.Parent = Icon
local ILbl = Instance.new("TextLabel")
ILbl.Size = UDim2.new(1, 0, 1, 0) ILbl.BackgroundTransparency = 1
ILbl.Text = "◆" ILbl.TextColor3 = Color3.fromRGB(255, 255, 255)
ILbl.Font = Enum.Font.GothamBlack ILbl.TextSize = 22 ILbl.Parent = Icon

local iconDrag = false
local iconStart, iconPos
Icon.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        iconDrag = false iconStart = input.Position iconPos = Icon.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if iconStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - iconStart
        if d.Magnitude > 8 then
            iconDrag = true
            Icon.Position = UDim2.new(0, iconPos.X.Offset + d.X, 0, iconPos.Y.Offset + d.Y)
        end
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then iconStart = nil end
end)

-- Main Frame
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 0, 0, FH)
Main.Position = UDim2.new(0.5, -FW/2, 0.5, -FH/2)
Main.BackgroundColor3 = Color3.fromRGB(14, 18, 24)
Main.BackgroundTransparency = 0.05
Main.BorderSizePixel = 0
Main.Active = true
Main.Visible = false
Main.ClipsDescendants = true
Main.Parent = ScreenGui
local MC = Instance.new("UICorner") MC.CornerRadius = UDim.new(0, 14) MC.Parent = Main
local MStr = Instance.new("UIStroke") MStr.Color = Color3.fromRGB(120, 200, 255) MStr.Thickness = 1.5 MStr.Transparency = 0.4 MStr.Parent = Main

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(20, 28, 40)
Header.BackgroundTransparency = 0.1
Header.BorderSizePixel = 0
Header.Parent = Main
local HC = Instance.new("UICorner") HC.CornerRadius = UDim.new(0, 14) HC.Parent = Header

local HText = Instance.new("TextLabel")
HText.Size = UDim2.new(1, -80, 1, 0)
HText.Position = UDim2.new(0, 14, 0, 0)
HText.BackgroundTransparency = 1
HText.Text = "◆ REALISTIC SHADER"
HText.TextColor3 = Color3.fromRGB(180, 220, 255)
HText.TextXAlignment = Enum.TextXAlignment.Left
HText.Font = Enum.Font.GothamBold
HText.TextSize = 13
HText.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -32, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(210, 55, 55)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Header
local CBC = Instance.new("UICorner") CBC.CornerRadius = UDim.new(0, 6) CBC.Parent = CloseBtn

-- Tab Bar
local TabBar = Instance.new("ScrollingFrame")
TabBar.Size = UDim2.new(1, -8, 0, 38)
TabBar.Position = UDim2.new(0, 4, 0, 44)
TabBar.BackgroundColor3 = Color3.fromRGB(20, 26, 36)
TabBar.BackgroundTransparency = 0.2
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 2
TabBar.ScrollBarImageColor3 = Color3.fromRGB(120, 200, 255)
TabBar.ScrollingDirection = Enum.ScrollingDirection.X
TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
TabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
TabBar.Parent = Main
local TBC = Instance.new("UICorner") TBC.CornerRadius = UDim.new(0, 8) TBC.Parent = TabBar

local TabLayout = Instance.new("UIListLayout")
TabLayout.Padding = UDim.new(0, 4)
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabLayout.Parent = TabBar
local TabPad = Instance.new("UIPadding")
TabPad.PaddingTop = UDim.new(0, 5)
TabPad.PaddingBottom = UDim.new(0, 5)
TabPad.PaddingLeft = UDim.new(0, 6)
TabPad.PaddingRight = UDim.new(0, 6)
TabPad.Parent = TabBar

-- Content
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -8, 1, -90)
ContentArea.Position = UDim2.new(0, 4, 0, 86)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = Main

local Pages = {}
local function makePage(name)
    local p = Instance.new("ScrollingFrame")
    p.Name = name
    p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.ScrollBarThickness = 3
    p.ScrollBarImageColor3 = Color3.fromRGB(120, 200, 255)
    p.CanvasSize = UDim2.new(0, 0, 0, 0)
    p.AutomaticCanvasSize = Enum.AutomaticSize.Y
    p.Visible = false
    p.Parent = ContentArea
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = p
    local pad = Instance.new("UIPadding")
    pad.PaddingRight = UDim.new(0, 6)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = p
    Pages[name] = p
    return p
end

local TabButtons = {}
local function showPage(name)
    for n, p in pairs(Pages) do p.Visible = (n == name) end
    for n, b in pairs(TabButtons) do
        if n == name then
            b.BackgroundColor3 = Color3.fromRGB(60, 100, 145)
            b.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            b.BackgroundColor3 = Color3.fromRGB(32, 42, 55)
            b.TextColor3 = Color3.fromRGB(160, 200, 240)
        end
    end
end

local function makeTab(label, pageName)
    local B = Instance.new("TextButton")
    B.Size = UDim2.new(0, 68, 0, 28)
    B.BackgroundColor3 = Color3.fromRGB(32, 42, 55)
    B.Text = label
    B.TextColor3 = Color3.fromRGB(160, 200, 240)
    B.Font = Enum.Font.GothamBold
    B.TextSize = 10
    B.BorderSizePixel = 0
    B.AutoButtonColor = false
    B.Parent = TabBar
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = B
    B.MouseButton1Click:Connect(function() showPage(pageName) end)
    TabButtons[pageName] = B
    return B
end

-- UI Helpers
local function makeHeader(parent, text)
    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(1, 0, 0, 24)
    L.BackgroundColor3 = Color3.fromRGB(28, 40, 55)
    L.BackgroundTransparency = 0.2
    L.BorderSizePixel = 0
    L.Text = "  " .. text
    L.TextColor3 = Color3.fromRGB(120, 200, 255)
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Font = Enum.Font.GothamBold
    L.TextSize = 11
    L.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 5) c.Parent = L
end

local function makeButton(parent, text, cb, col)
    local B = Instance.new("TextButton")
    B.Size = UDim2.new(1, 0, 0, 34)
    B.BackgroundColor3 = col or Color3.fromRGB(45, 65, 90)
    B.BackgroundTransparency = 0.1
    B.TextColor3 = Color3.fromRGB(255, 255, 255)
    B.Text = text
    B.Font = Enum.Font.GothamBold
    B.TextSize = 11
    B.TextWrapped = true
    B.BorderSizePixel = 0
    B.AutoButtonColor = false
    B.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 7) c.Parent = B
    local sc = col or Color3.fromRGB(45, 65, 90)
    B.MouseButton1Down:Connect(function() B.BackgroundColor3 = Color3.fromRGB(90, 140, 200) end)
    B.MouseButton1Up:Connect(function() B.BackgroundColor3 = sc end)
    B.MouseLeave:Connect(function() B.BackgroundColor3 = sc end)
    B.MouseButton1Click:Connect(function()
        local ok, err = pcall(cb)
        if not ok then print("[SHADER ERROR] " .. tostring(err)) end
    end)
    return B
end

local function makeToggle(parent, text, key, cb)
    local B = Instance.new("TextButton")
    B.Size = UDim2.new(1, 0, 0, 32)
    B.BackgroundColor3 = Color3.fromRGB(30, 40, 55)
    B.BackgroundTransparency = 0.15
    B.TextColor3 = Color3.fromRGB(200, 220, 240)
    B.Text = "  " .. text .. "  " .. (State.enabled[key] and "ON" or "OFF")
    B.TextXAlignment = Enum.TextXAlignment.Left
    B.Font = Enum.Font.Gotham
    B.TextSize = 11
    B.BorderSizePixel = 0
    B.AutoButtonColor = false
    B.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = B
    if State.enabled[key] then
        B.BackgroundColor3 = Color3.fromRGB(45, 85, 60)
    end
    B.MouseButton1Click:Connect(function()
        State.enabled[key] = not State.enabled[key]
        B.Text = "  " .. text .. "  " .. (State.enabled[key] and "ON" or "OFF")
        B.BackgroundColor3 = State.enabled[key] and Color3.fromRGB(45, 85, 60) or Color3.fromRGB(30, 40, 55)
        if cb then pcall(cb, State.enabled[key]) end
    end)
    return B
end

local function makeSlider(parent, text, key, mn, mx, df, cb)
    local F = Instance.new("Frame")
    F.Size = UDim2.new(1, 0, 0, 46)
    F.BackgroundColor3 = Color3.fromRGB(30, 40, 55)
    F.BackgroundTransparency = 0.15
    F.BorderSizePixel = 0
    F.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = F

    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(1, -14, 0, 18)
    L.Position = UDim2.new(0, 8, 0, 3)
    L.BackgroundTransparency = 1
    L.Text = text .. ": " .. df
    L.TextColor3 = Color3.fromRGB(200, 220, 240)
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Font = Enum.Font.Gotham
    L.TextSize = 11
    L.Parent = F

    local Bar = Instance.new("Frame")
    Bar.Size = UDim2.new(1, -20, 0, 10)
    Bar.Position = UDim2.new(0, 10, 0, 28)
    Bar.BackgroundColor3 = Color3.fromRGB(55, 70, 90)
    Bar.BorderSizePixel = 0
    Bar.Active = true
    Bar.Parent = F
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(1, 0) bc.Parent = Bar

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((df - mn) / (mx - mn), 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
    Fill.BorderSizePixel = 0
    Fill.Parent = Bar
    local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1, 0) fc.Parent = Fill

    local dragging = false
    Bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
            Fill.Size = UDim2.new(rel, 0, 1, 0)
            local v = mn + (mx - mn) * rel
            if mx - mn < 2 then v = math.floor(v * 100) / 100 else v = math.floor(v) end
            L.Text = text .. ": " .. v
            if cb then pcall(cb, v) end
        end
    end)
    return F
end

-- ============================================================
-- PAGES
-- ============================================================
makePage("presets")
makePage("effects")
makePage("tuning")

-- PRESETS
local pPresets = Pages["presets"]
makeHeader(pPresets, "TIME OF DAY")
makeButton(pPresets, "☀  Bright Day", function() applyPreset("Bright Day") end, Color3.fromRGB(60, 100, 140))
makeButton(pPresets, "🌅  Golden Sunset", function() applyPreset("Golden Sunset") end, Color3.fromRGB(150, 95, 55))
makeButton(pPresets, "🌆  Dusk / Twilight", function() applyPreset("Dusk") end, Color3.fromRGB(90, 70, 130))
makeButton(pPresets, "🌙  Night", function() applyPreset("Night") end, Color3.fromRGB(40, 50, 80))
makeButton(pPresets, "🌫  Misty Morning", function() applyPreset("Misty Morning") end, Color3.fromRGB(100, 115, 135))

makeHeader(pPresets, "STYLE")
makeButton(pPresets, "🎬  Cinematic", function() applyPreset("Cinematic") end, Color3.fromRGB(100, 65, 140))
makeButton(pPresets, "🎌  Anime Style", function() applyPreset("Anime") end, Color3.fromRGB(140, 90, 120))

-- EFFECTS
local pEffects = Pages["effects"]
makeHeader(pEffects, "EFFECT TOGGLES")

makeToggle(pEffects, "Atmosphere", "atmos", function(v)
    atmos.Enabled = v
end)

makeToggle(pEffects, "Bloom", "bloom", function(v)
    bloom.Enabled = v
end)

makeToggle(pEffects, "Color Correction", "cc", function(v)
    cc.Enabled = v
end)

makeToggle(pEffects, "Sun Rays", "sun", function(v)
    sunRays.Enabled = v
end)

makeToggle(pEffects, "Depth of Field", "dof", function(v)
    dof.Enabled = v
end)

makeHeader(pEffects, "CONTROL")
makeButton(pEffects, "↩  Reset All", function()
    for _, v in ipairs(Lighting:GetChildren()) do
        if v.Name:find("OBS_SHADER") then v:Destroy() end
    end
    print("[SHADER] Removed")
end, Color3.fromRGB(120, 60, 60))

-- TUNING
local pTuning = Pages["tuning"]
makeHeader(pTuning, "LIGHTING")

makeSlider(pTuning, "Brightness", "brightness", 0.5, 4, State.values.brightness, function(v)
    Lighting.Brightness = v
end)

makeSlider(pTuning, "Clock Time", "clockTime", 0, 24, State.values.clockTime, function(v)
    Lighting.ClockTime = v
end)

makeSlider(pTuning, "Fog End", "fogEnd", 500, 5000, State.values.fogEnd, function(v)
    Lighting.FogEnd = v
end)

makeHeader(pTuning, "BLOOM")
makeSlider(pTuning, "Bloom Intensity", "bloomIntensity", 0, 2, State.values.bloomIntensity, function(v)
    bloom.Intensity = v
end)
makeSlider(pTuning, "Bloom Size", "bloomSize", 8, 56, State.values.bloomSize, function(v)
    bloom.Size = v
end)
makeSlider(pTuning, "Bloom Threshold", "bloomThreshold", 0.5, 2, State.values.bloomThreshold, function(v)
    bloom.Threshold = v
end)

makeHeader(pTuning, "COLOR")
makeSlider(pTuning, "Contrast", "ccContrast", 0, 0.5, State.values.ccContrast, function(v)
    cc.Contrast = v
end)
makeSlider(pTuning, "Saturation", "ccSaturation", 0, 0.5, State.values.ccSaturation, function(v)
    cc.Saturation = v
end)
makeSlider(pTuning, "Brightness", "ccBrightness", -0.2, 0.2, State.values.ccBrightness, function(v)
    cc.Brightness = v
end)

makeHeader(pTuning, "ATMOSPHERE")
makeSlider(pTuning, "Density", "atmosDensity", 0, 1, State.values.atmosDensity, function(v)
    atmos.Density = v
end)
makeSlider(pTuning, "Haze", "atmosHaze", 0, 5, State.values.atmosHaze, function(v)
    atmos.Haze = v
end)
makeSlider(pTuning, "Glare", "atmosGlare", 0, 1, State.values.atmosGlare, function(v)
    atmos.Glare = v
end)

makeHeader(pTuning, "DEPTH OF FIELD")
makeSlider(pTuning, "Far Intensity", "dofFar", 0, 0.5, State.values.dofFar, function(v)
    dof.FarIntensity = v
end)
makeSlider(pTuning, "Focus Distance", "dofDistance", 5, 100, State.values.dofDistance, function(v)
    dof.FocusDistance = v
end)
makeSlider(pTuning, "In-Focus Radius", "dofRadius", 10, 200, State.values.dofRadius, function(v)
    dof.InFocusRadius = v
end)

-- Tabs
makeTab("Presets", "presets")
makeTab("Effects", "effects")
makeTab("Tuning", "tuning")

showPage("presets")

-- ============================================================
-- MENU CONTROL
-- ============================================================
local MenuOpen = false
local function openMenu()
    if MenuOpen then return end
    MenuOpen = true
    Main.Visible = true
    TweenService:Create(Main, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, FW, 0, FH)
    }):Play()
end
local function closeMenu()
    if not MenuOpen then return end
    MenuOpen = false
    local t = TweenService:Create(Main, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, FH)
    })
    t.Completed:Connect(function() Main.Visible = false end)
    t:Play()
end

Icon.MouseButton1Click:Connect(function()
    if iconDrag then return end
    if MenuOpen then closeMenu() else openMenu() end
end)
CloseBtn.MouseButton1Click:Connect(closeMenu)

print("[SHADER] v3 loaded. Click ◆ icon.")
