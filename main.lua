-- OBSIDIAN HUB v6 | Auto-Inject + Visual Log
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Config = {
    Aimbot = false, AimbotSmooth = 8, AimbotFOV = 140, AimbotPart = "Head",
    AimbotMaxDist = 600, AimbotLock = false, AimbotHumanize = true, AimbotVisibleCheck = true,
    ESP = false, Tracers = true,
    TeamCheck = true, FriendCheck = true,
    Fly = false, FlySpeed = 55,
    SpeedOn = false, SpeedValue = 40,
    JumpOn = false, JumpValue = 90, InfJump = false,
    BroadcastText = "OBSIDIAN", BroadcastSpam = false, BroadcastInterval = 3,
    AvatarUsername = "", TargetUsername = "",
}
local LockedTarget = nil

-- ============================================================
-- INJECTOR WITH LOG
-- ============================================================
local INJECTOR = { Capabilities = {}, ActiveHooks = {}, Log = {} }

local function log(msg, ok)
    table.insert(INJECTOR.Log, {msg = msg, ok = ok})
    print((ok and "[OK] " or "[FAIL] ") .. msg)
end

local function getRawMT(obj)
    if getrawmetatable then
        local ok, mt = pcall(getrawmetatable, obj)
        if ok and mt then return mt end
    end
    if debug and debug.getmetatable then
        local ok, mt = pcall(debug.getmetatable, obj)
        if ok and mt then return mt end
    end
    return nil
end

local function makeClosure(fn)
    if newcclosure then
        local ok, c = pcall(newcclosure, fn)
        if ok and c then return c end
    end
    return fn
end

local function hookMethod(mt, name, handler)
    if not mt then return false end
    local old = rawget(mt, name)
    if not old then return false end
    if setreadonly then pcall(setreadonly, mt, false) end
    local wrapped = makeClosure(function(...)
        local ok, result = pcall(handler, old, ...)
        if not ok then return old(...) end
        if result == nil then return old(...) end
        return result
    end)
    rawset(mt, name, wrapped)
    if setreadonly then pcall(setreadonly, mt, true) end
    table.insert(INJECTOR.ActiveHooks, {mt=mt, method=name, old=old})
    return true
end

function INJECTOR.installNamecall()
    local mt = getRawMT(game)
    if not mt then return false end
    return hookMethod(mt, "__namecall", function(old, self, ...)
        if getnamecallmethod then
            local m = getnamecallmethod()
            if m == "Kick" then return nil end
        end
        return nil
    end)
end

function INJECTOR.installIndex()
    local mt = getRawMT(game)
    if not mt then return false end
    return hookMethod(mt, "__index", function(old, self, key)
        if key == "WalkSpeed" or key == "JumpPower" then
            if typeof(self) == "Instance" and self:IsA("Humanoid") then
                if LocalPlayer.Character and self == LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                    return 16
                end
            end
        end
        return nil
    end)
end

function INJECTOR.killMonitors()
    if not getconnections then return 0 end
    local c = LocalPlayer.Character
    if not c then return 0 end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return 0 end
    local n = 0
    for _, prop in ipairs({"WalkSpeed","JumpPower","Health"}) do
        pcall(function()
            for _, conn in ipairs(getconnections(h:GetPropertyChangedSignal(prop))) do
                if conn.Disable then conn:Disable() n = n + 1 end
            end
        end)
    end
    return n
end

function INJECTOR.boot()
    INJECTOR.Log = {}
    INJECTOR.ActiveHooks = {}

    -- Capability check
    local c = INJECTOR.Capabilities
    c.hookmetamethod = type(rawget(_G,"hookmetamethod")) == "function"
    c.getrawmetatable = type(rawget(_G,"getrawmetatable")) == "function"
    c.setreadonly = type(rawget(_G,"setreadonly")) == "function"
    c.getconnections = type(rawget(_G,"getconnections")) == "function"
    c.newcclosure = type(rawget(_G,"newcclosure")) == "function"
    c.getnamecallmethod = type(rawget(_G,"getnamecallmethod")) == "function"
    c.firetouchinterest = type(rawget(_G,"firetouchinterest")) == "function"

    log("Namecall Hook", INJECTOR.installNamecall())
    log("WalkSpeed Spoof", INJECTOR.installIndex())
    local n = INJECTOR.killMonitors()
    log("Monitors Killed: " .. n, n > 0)
    log("Capabilities: " .. (c.hookmetamethod and "Hook" or "") .. (c.getconnections and " Conn" or "") .. (c.firetouchinterest and " Touch" or ""), true)
end

-- ============================================================
-- BROADCAST
-- ============================================================
local Broadcast = { LocalGui = nil, LocalLabel = nil, SpamThread = nil, KnownRemotes = {} }

local function sendChatBubble(text)
    pcall(function()
        local ev = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if ev then
            local say = ev:FindFirstChild("SayMessageRequest")
            if say then say:FireServer(text, "All") end
        end
    end)
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local ch = TextChatService:FindFirstChild("TextChannels")
            if ch then
                local g = ch:FindFirstChild("RBXGeneral") or ch:FindFirstChild("General")
                if g then g:SendAsync(text) end
            end
        end
    end)
end

local function setDisplayName(text)
    local char = LocalPlayer.Character
    if not char then return end
    local h = char:FindFirstChildOfClass("Humanoid")
    if h then pcall(function() h.DisplayName = text end) end
end

local function scanRemotes()
    Broadcast.KnownRemotes = {}
    local pats = {"nametag","nameplate","overhead","displayname","setname","rename","tag","title","chat","say","bubble"}
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local n = obj.Name:lower()
            for _, p in ipairs(pats) do
                if n:find(p) then table.insert(Broadcast.KnownRemotes, obj) break end
            end
        end
    end
    return #Broadcast.KnownRemotes
end

local function fireRemotes(text)
    if #Broadcast.KnownRemotes == 0 then scanRemotes() end
    local argsets = {{text},{"SetName",text},{"SetText",text},{"UpdateName",text},{LocalPlayer,text},{"nametag",text}}
    for _, r in ipairs(Broadcast.KnownRemotes) do
        for _, args in ipairs(argsets) do
            pcall(function() r:FireServer(table.unpack(args)) end)
        end
    end
end

local function attachLocalBillboard(text)
    local char = LocalPlayer.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    if Broadcast.LocalGui then Broadcast.LocalGui:Destroy() end
    local bb = Instance.new("BillboardGui")
    bb.Name = "__OBSIDIAN_TAG"
    bb.Size = UDim2.new(0, 220, 0, 40)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = head
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(255,255,255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true
    lbl.TextStrokeTransparency = 0.2
    lbl.Parent = bb
    Broadcast.LocalGui = bb
    Broadcast.LocalLabel = lbl
end

function Broadcast.trigger(text)
    setDisplayName(text)
    sendChatBubble(text)
    fireRemotes(text)
end

function Broadcast.startSpam()
    if Broadcast.SpamThread then return end
    Broadcast.SpamThread = task.spawn(function()
        while Config.BroadcastSpam do
            Broadcast.trigger(Config.BroadcastText)
            task.wait(Config.BroadcastInterval)
        end
    end)
end

function Broadcast.stopSpam()
    Config.BroadcastSpam = false
    Broadcast.SpamThread = nil
end

-- ============================================================
-- AVATAR
-- ============================================================
local function applyAvatar(username)
    if username == "" then return false end
    local uid
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == username:lower() then uid = p.UserId break end
    end
    if not uid then
        local ok, res = pcall(Players.GetUserIdFromNameAsync, Players, username)
        if ok then uid = res end
    end
    if not uid then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    local h = char:FindFirstChildOfClass("Humanoid")
    if not h then return false end
    local ok, desc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, uid)
    if not ok or not desc then return false end
    pcall(function() h:ApplyDescriptionReset(desc) end)
    return true
end

-- ============================================================
-- GUI
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OBSIDIAN"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local vp = Camera.ViewportSize
local FW = math.clamp(vp.X * 0.92, 320, 420)
local FH = math.clamp(vp.Y * 0.75, 450, 560)

-- Floating Icon
local Icon = Instance.new("ImageButton")
Icon.Size = UDim2.new(0, 52, 0, 52)
Icon.Position = UDim2.new(0, 15, 0, 100)
Icon.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
Icon.BorderSizePixel = 0
Icon.AutoButtonColor = false
Icon.Active = true
Icon.Parent = ScreenGui
local IC = Instance.new("UICorner") IC.CornerRadius = UDim.new(1,0) IC.Parent = Icon
local IStr = Instance.new("UIStroke") IStr.Color = Color3.fromRGB(90,140,220) IStr.Thickness = 2 IStr.Parent = Icon
local ILbl = Instance.new("TextLabel")
ILbl.Size = UDim2.new(1,0,1,0) ILbl.BackgroundTransparency = 1
ILbl.Text = "V" ILbl.TextColor3 = Color3.fromRGB(255,255,255)
ILbl.Font = Enum.Font.GothamBlack ILbl.TextSize = 26 ILbl.Parent = Icon

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

-- Main
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 0, 0, FH)
Main.Position = UDim2.new(0.5, -FW/2, 0.5, -FH/2)
Main.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.Visible = false
Main.ClipsDescendants = true
Main.Parent = ScreenGui
local MC = Instance.new("UICorner") MC.CornerRadius = UDim.new(0,12) MC.Parent = Main
local MStr = Instance.new("UIStroke") MStr.Color = Color3.fromRGB(90,140,220) MStr.Thickness = 1.5 MStr.Transparency = 0.4 MStr.Parent = Main

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1,0,0,42) Header.BackgroundColor3 = Color3.fromRGB(26,26,36)
Header.BorderSizePixel = 0 Header.Parent = Main
local HC = Instance.new("UICorner") HC.CornerRadius = UDim.new(0,12) HC.Parent = Header

local HText = Instance.new("TextLabel")
HText.Size = UDim2.new(1,-80,1,0) HText.Position = UDim2.new(0,12,0,0)
HText.BackgroundTransparency = 1 HText.Text = "OBSIDIAN  •  HUB v6"
HText.TextColor3 = Color3.fromRGB(255,255,255)
HText.TextXAlignment = Enum.TextXAlignment.Left
HText.Font = Enum.Font.GothamBold HText.TextSize = 13 HText.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0,28,0,28) CloseBtn.Position = UDim2.new(1,-34,0,7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(210,55,55) CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255,255,255) CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13 CloseBtn.BorderSizePixel = 0 CloseBtn.Parent = Header
local CBC = Instance.new("UICorner") CBC.CornerRadius = UDim.new(0,7) CBC.Parent = CloseBtn

-- ============== TAB STRIP (ScrollingFrame) ==============
local TabStrip = Instance.new("ScrollingFrame")
TabStrip.Name = "TabStrip"
TabStrip.Size = UDim2.new(0, 68, 1, -52)
TabStrip.Position = UDim2.new(0, 6, 0, 48)
TabStrip.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
TabStrip.BorderSizePixel = 0
TabStrip.ScrollBarThickness = 2
TabStrip.ScrollBarImageColor3 = Color3.fromRGB(90,140,220)
TabStrip.ScrollingDirection = Enum.ScrollingDirection.Y
TabStrip.CanvasSize = UDim2.new(0,0,0,0)
TabStrip.AutomaticCanvasSize = Enum.AutomaticSize.Y
TabStrip.Parent = Main
local TSC = Instance.new("UICorner") TSC.CornerRadius = UDim.new(0,8) TSC.Parent = TabStrip

local TabLayout = Instance.new("UIListLayout")
TabLayout.Padding = UDim.new(0,5)
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabLayout.Parent = TabStrip
local TabPad = Instance.new("UIPadding")
TabPad.PaddingTop = UDim.new(0,6)
TabPad.PaddingBottom = UDim.new(0,6)
TabPad.Parent = TabStrip

-- Content
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -80, 1, -52)
ContentArea.Position = UDim2.new(0, 76, 0, 48)
ContentArea.BackgroundTransparency = 1 ContentArea.Parent = Main

local Pages = {}
local function makePage(name)
    local p = Instance.new("ScrollingFrame")
    p.Name = name
    p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.ScrollBarThickness = 3
    p.ScrollBarImageColor3 = Color3.fromRGB(90,140,220)
    p.CanvasSize = UDim2.new(0,0,0,0)
    p.AutomaticCanvasSize = Enum.AutomaticSize.Y
    p.Visible = false
    p.Parent = ContentArea
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0,6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = p
    local pad = Instance.new("UIPadding")
    pad.PaddingRight = UDim.new(0, 6)
    pad.Parent = p
    Pages[name] = p
    return p
end

local TabButtons = {}
local function showPage(name)
    for n, p in pairs(Pages) do p.Visible = (n == name) end
    for n, b in pairs(TabButtons) do
        if n == name then
            b.BackgroundColor3 = Color3.fromRGB(60,90,140)
            b.TextColor3 = Color3.fromRGB(255,255,255)
        else
            b.BackgroundColor3 = Color3.fromRGB(32,32,44)
            b.TextColor3 = Color3.fromRGB(200,200,210)
        end
    end
end

local function makeTab(label, pageName)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 58, 0, 58)
    Btn.BackgroundColor3 = Color3.fromRGB(32,32,44)
    Btn.Text = label
    Btn.TextColor3 = Color3.fromRGB(200,200,210)
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 11
    Btn.TextWrapped = true
    Btn.BorderSizePixel = 0
    Btn.AutoButtonColor = false
    Btn.Active = true
    Btn.Parent = TabStrip
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0,8) c.Parent = Btn
    Btn.MouseButton1Click:Connect(function() showPage(pageName) end)
    TabButtons[pageName] = Btn
    return Btn
end

-- Helpers
local function makeHeader(parent, text)
    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(1,0,0,22)
    L.BackgroundColor3 = Color3.fromRGB(36,36,50)
    L.BorderSizePixel = 0
    L.Text = "  " .. text
    L.TextColor3 = Color3.fromRGB(90,160,240)
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Font = Enum.Font.GothamBold
    L.TextSize = 11
    L.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0,4) c.Parent = L
end

local function makeToggle(parent, text, key, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1,0,0,32)
    Btn.BackgroundColor3 = Color3.fromRGB(30,30,40)
    Btn.TextColor3 = Color3.fromRGB(215,215,220)
    Btn.Text = "  " .. text .. "  |  OFF"
    Btn.TextXAlignment = Enum.TextXAlignment.Left
    Btn.Font = Enum.Font.Gotham
    Btn.TextSize = 11
    Btn.BorderSizePixel = 0
    Btn.AutoButtonColor = false
    Btn.Active = true
    Btn.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0,6) c.Parent = Btn
    Btn.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        Btn.Text = "  " .. text .. "  |  " .. (Config[key] and "ON" or "OFF")
        Btn.BackgroundColor3 = Config[key] and Color3.fromRGB(45,85,55) or Color3.fromRGB(30,30,40)
        if callback then pcall(callback, Config[key]) end
    end)
    return Btn
end

local function makeSlider(parent, text, key, min, max, default)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1,0,0,42)
    Frame.BackgroundColor3 = Color3.fromRGB(30,30,40)
    Frame.BorderSizePixel = 0 Frame.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0,6) c.Parent = Frame

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1,-12,0,18)
    Lbl.Position = UDim2.new(0,6,0,2)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = text .. ": " .. default
    Lbl.TextColor3 = Color3.fromRGB(215,215,220)
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Font = Enum.Font.Gotham Lbl.TextSize = 11 Lbl.Parent = Frame

    local Bar = Instance.new("Frame")
    Bar.Size = UDim2.new(1,-20,0,8)
    Bar.Position = UDim2.new(0,10,0,28)
    Bar.BackgroundColor3 = Color3.fromRGB(55,55,70)
    Bar.BorderSizePixel = 0 Bar.Parent = Frame
    Bar.Active = true
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(1,0) bc.Parent = Bar

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(90,140,220)
    Fill.BorderSizePixel = 0 Fill.Parent = Bar
    local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1,0) fc.Parent = Fill

    local dragging = false
    Bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
            Fill.Size = UDim2.new(rel,0,1,0)
            local val = math.floor(min + (max - min) * rel)
            Lbl.Text = text .. ": " .. val
            Config[key] = val
        end
    end)
end

local function makeButton(parent, text, callback, color)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1,0,0,32)
    Btn.BackgroundColor3 = color or Color3.fromRGB(60,100,165)
    Btn.TextColor3 = Color3.fromRGB(255,255,255)
    Btn.Text = text
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 11
    Btn.TextWrapped = true
    Btn.BorderSizePixel = 0
    Btn.AutoButtonColor = false
    Btn.Active = true
    Btn.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0,6) c.Parent = Btn
    local startColor = color or Color3.fromRGB(60,100,165)
    Btn.MouseButton1Down:Connect(function()
        Btn.BackgroundColor3 = Color3.fromRGB(80,130,200)
    end)
    Btn.MouseButton1Up:Connect(function()
        Btn.BackgroundColor3 = startColor
    end)
    Btn.MouseLeave:Connect(function()
        Btn.BackgroundColor3 = startColor
    end)
    Btn.MouseButton1Click:Connect(function()
        pcall(callback)
    end)
    return Btn
end

local function makeInput(parent, label, key, placeholder)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1,0,0,46)
    Frame.BackgroundColor3 = Color3.fromRGB(30,30,40)
    Frame.BorderSizePixel = 0 Frame.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0,6) c.Parent = Frame

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1,-12,0,16)
    Lbl.Position = UDim2.new(0,6,0,2)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = label
    Lbl.TextColor3 = Color3.fromRGB(215,215,220)
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Font = Enum.Font.Gotham Lbl.TextSize = 10 Lbl.Parent = Frame

    local Box = Instance.new("TextBox")
    Box.Size = UDim2.new(1,-12,0,22)
    Box.Position = UDim2.new(0,6,0,18)
    Box.BackgroundColor3 = Color3.fromRGB(20,20,28)
    Box.BorderSizePixel = 0
    Box.PlaceholderText = placeholder or ""
    Box.PlaceholderColor3 = Color3.fromRGB(110,110,125)
    Box.TextColor3 = Color3.fromRGB(220,220,220)
    Box.Font = Enum.Font.Gotham
    Box.TextSize = 11
    Box.ClearTextOnFocus = false
    Box.Parent = Frame
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0,4) bc.Parent = Box
    Box.FocusLost:Connect(function() Config[key] = Box.Text end)
    return Box
end

-- ============================================================
-- PAGES
-- ============================================================
makePage("combat"); makePage("move"); makePage("broadcast")
makePage("char"); makePage("players"); makePage("injector"); makePage("tools")

-- COMBAT
local combat = Pages["combat"]
makeHeader(combat, "التصويب")
makeToggle(combat, "التصويب التلقائي", "Aimbot")
makeToggle(combat, "قفل الهدف", "AimbotLock")
makeToggle(combat, "تجاهل الفريق", "TeamCheck")
makeToggle(combat, "تجاهل الأصدقاء", "FriendCheck")
makeToggle(combat, "فحص الرؤية", "AimbotVisibleCheck")
makeToggle(combat, "محاكاة بشرية", "AimbotHumanize")
makeSlider(combat, "نطاق التصويب", "AimbotFOV", 30, 400, 140)
makeSlider(combat, "نعومة التصويب", "AimbotSmooth", 2, 30, 8)
makeSlider(combat, "أقصى مسافة", "AimbotMaxDist", 50, 1500, 600)
makeHeader(combat, "كشف اللاعبين")
makeToggle(combat, "تفعيل ESP", "ESP")
makeToggle(combat, "خطوط التتبع", "Tracers")

-- MOVE
local move = Pages["move"]
makeHeader(move, "الطيران")
makeToggle(move, "الطيران", "Fly")
makeSlider(move, "سرعة الطيران", "FlySpeed", 20, 150, 55)
makeHeader(move, "الركض والقفز")
makeToggle(move, "ركض سريع", "SpeedOn")
makeSlider(move, "سرعة الركض", "SpeedValue", 16, 100, 40)
makeToggle(move, "قفز عالي", "JumpOn")
makeSlider(move, "قوة القفز", "JumpValue", 50, 200, 90)
makeToggle(move, "قفز لا محدود", "InfJump")

-- BROADCAST
local bc = Pages["broadcast"]
makeHeader(bc, "الرسالة فوق الرأس")
makeInput(bc, "نص الرسالة", "BroadcastText", "اكتب رسالتك")
makeButton(bc, "بث للجميع (3 طرق)", function()
    Broadcast.trigger(Config.BroadcastText)
end, Color3.fromRGB(60,150,85))
makeButton(bc, "تثبيت محلي (لك فقط)", function()
    attachLocalBillboard(Config.BroadcastText)
end, Color3.fromRGB(80,80,130))
makeHeader(bc, "خيارات")
makeToggle(bc, "تكرار تلقائي", "BroadcastSpam", function(v)
    if v then Broadcast.startSpam() else Broadcast.stopSpam() end
end)
makeSlider(bc, "الفاصل الزمني", "BroadcastInterval", 1, 10, 3)
makeButton(bc, "فحص Remotes", function()
    local n = scanRemotes()
    print("Found " .. n .. " remotes")
end, Color3.fromRGB(70,110,170))

-- CHAR
local charPage = Pages["char"]
makeHeader(charPage, "نسخ أفاتار")
makeInput(charPage, "اسم اللاعب", "AvatarUsername", "اكتب الاسم")
makeButton(charPage, "نسخ الأفاتار", function()
    print("Avatar:", applyAvatar(Config.AvatarUsername))
end, Color3.fromRGB(60,140,85))
makeHeader(charPage, "أدوات")
makeButton(charPage, "إزالة الملحقات", function()
    local c = LocalPlayer.Character
    if not c then return end
    for _, v in ipairs(c:GetChildren()) do
        if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants") then v:Destroy() end
    end
end, Color3.fromRGB(140,60,60))
makeButton(charPage, "لون عشوائي", function()
    local c = LocalPlayer.Character
    if not c then return end
    for _, v in ipairs(c:GetChildren()) do
        if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then v.BrickColor = BrickColor.random() end
    end
end, Color3.fromRGB(140,100,55))

-- PLAYERS
local plyPage = Pages["players"]
makeHeader(plyPage, "استهداف لاعب")
makeInput(plyPage, "اسم اللاعب", "TargetUsername", "اكتب الاسم")
makeButton(plyPage, "الانتقال إليه", function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == Config.TargetUsername:lower() and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local my = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp and my then my.CFrame = hrp.CFrame * CFrame.new(0,0,3) end
            return
        end
    end
end, Color3.fromRGB(60,140,85))
makeButton(plyPage, "قذفه (5 طرق)", function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == Config.TargetUsername:lower() and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            pcall(function() hrp:SetNetworkOwner(LocalPlayer) end)
            pcall(function()
                local bv = Instance.new("BodyVelocity")
                bv.Velocity = Vector3.new(0, 9999, 0)
                bv.MaxForce = Vector3.new(math.huge,math.huge,math.huge)
                bv.Parent = hrp
                game:GetService("Debris"):AddItem(bv, 0.2)
            end)
            for _, r in ipairs(game:GetDescendants()) do
                if r:IsA("RemoteEvent") then
                    local n = r.Name:lower()
                    if n:find("launch") or n:find("push") or n:find("fling") or n:find("ragdoll") then
                        pcall(function() r:FireServer(p, Vector3.new(0,9999,0)) end)
                    end
                end
            end
            return
        end
    end
end, Color3.fromRGB(180,70,70))

-- INJECTOR
local inj = Pages["injector"]
makeHeader(inj, "نظام الحقن")
makeButton(inj, "إعادة تشغيل الحقن", function() INJECTOR.boot() showPage("injector") end, Color3.fromRGB(200,50,50))

-- Success log panel
makeHeader(inj, "سجل النتائج")
local logFrame = Instance.new("Frame")
logFrame.Size = UDim2.new(1,0,0,200)
logFrame.BackgroundColor3 = Color3.fromRGB(20,20,28)
logFrame.BorderSizePixel = 0
logFrame.Parent = inj
local lfc = Instance.new("UICorner") lfc.CornerRadius = UDim.new(0,6) lfc.Parent = logFrame
local logLayout = Instance.new("UIListLayout")
logLayout.Padding = UDim.new(0,3)
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
logLayout.Parent = logFrame
local logPad = Instance.new("UIPadding")
logPad.PaddingTop = UDim.new(0,6)
logPad.PaddingLeft = UDim.new(0,8)
logPad.PaddingRight = UDim.new(0,8)
logPad.Parent = logFrame

local function refreshLog()
    for _, c in ipairs(logFrame:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    if #INJECTOR.Log == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1,0,0,20)
        empty.BackgroundTransparency = 1
        empty.Text = "لا توجد نتائج بعد"
        empty.TextColor3 = Color3.fromRGB(120,120,140)
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 11
        empty.TextXAlignment = Enum.TextXAlignment.Left
        empty.Parent = logFrame
        return
    end
    for _, entry in ipairs(INJECTOR.Log) do
        local line = Instance.new("TextLabel")
        line.Size = UDim2.new(1,0,0,20)
        line.BackgroundTransparency = 1
        line.Text = (entry.ok and "✓ " or "✗ ") .. entry.msg
        line.TextColor3 = entry.ok and Color3.fromRGB(80,200,120) or Color3.fromRGB(220,80,80)
        line.Font = Enum.Font.Gotham
        line.TextSize = 11
        line.TextXAlignment = Enum.TextXAlignment.Left
        line.Parent = logFrame
    end
end

makeButton(inj, "تحديث السجل", function() refreshLog() end, Color3.fromRGB(70,110,170))
makeButton(inj, "مسح السجل", function() INJECTOR.Log = {} refreshLog() end, Color3.fromRGB(90,90,130))

makeHeader(inj, "معلومات النظام")
makeButton(inj, "طباعة القدرات", function()
    for k, v in pairs(INJECTOR.Capabilities) do
        if v == true then print("  [OK] " .. k) end
    end
end, Color3.fromRGB(70,110,170))

-- TOOLS
local tools = Pages["tools"]
makeHeader(tools, "أدوات")
makeButton(tools, "إعادة الشخصية", function()
    local c = LocalPlayer.Character
    if c then c:BreakJoints() end
end, Color3.fromRGB(80,80,90))
makeButton(tools, "معلومات اللعبة", function()
    print("PlaceId:", game.PlaceId)
    print("Players:", #Players:GetPlayers())
end, Color3.fromRGB(70,110,170))

-- Tabs
makeTab("قتال","combat")
makeTab("حركة","move")
makeTab("بث","broadcast")
makeTab("شخصية","char")
makeTab("لاعبين","players")
makeTab("حقن","injector")
makeTab("أدوات","tools")

showPage("broadcast")

-- ============================================================
-- AUTO-BOOT INJECTOR (silent + visible log)
-- ============================================================
task.spawn(function()
    task.wait(1.5)
    INJECTOR.boot()
    task.wait(0.2)
    refreshLog()
end)

-- Auto-scan remotes
task.spawn(function()
    task.wait(2)
    scanRemotes()
end)

-- ============================================================
-- MENU TOGGLE
-- ============================================================
local MenuOpen = false
local function openMenu()
    if MenuOpen then return end
    MenuOpen = true
    Main.Visible = true
    TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, FW, 0, FH)
    }):Play()
end
local function closeMenu()
    if not MenuOpen then return end
    MenuOpen = false
    local t = TweenService:Create(Main, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
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

-- ============================================================
-- LOGIC (aimbot/esp/movement - unchanged)
-- ============================================================
local Drawing = Drawing or (getgenv and getgenv().Drawing)
local espObjects = {}

local function isAlive(p)
    local c = p.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end
local function isTeammate(p)
    if not Config.TeamCheck then return false end
    if not LocalPlayer.Team then return false end
    return p.Team == LocalPlayer.Team
end
local function isFriend(p)
    if not Config.FriendCheck then return false end
    local ok, r = pcall(function() return LocalPlayer:IsFriendsWith(p.UserId) end)
    return ok and r
end
local function isExcluded(p)
    if p == LocalPlayer then return true end
    if not isAlive(p) then return true end
    if isTeammate(p) then return true end
    if isFriend(p) then return true end
    return false
end
local function isVisible(part)
    if not Config.AimbotVisibleCheck then return true end
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, part.Parent }
    local result = Workspace:Raycast(origin, dir, params)
    return result == nil or (result.Position - origin).Magnitude >= dir.Magnitude - 1
end

local function createESP(p)
    if espObjects[p] or not Drawing then return end
    local box = Drawing.new("Square") box.Visible = false box.Thickness = 1 box.Filled = false
    local name = Drawing.new("Text") name.Visible = false name.Size = 13 name.Center = true name.Outline = true name.Color = Color3.fromRGB(255,255,255)
    local dist = Drawing.new("Text") dist.Visible = false dist.Size = 11 dist.Center = true dist.Outline = true dist.Color = Color3.fromRGB(255,220,100)
    local tracer = Drawing.new("Line") tracer.Visible = false tracer.Thickness = 1 tracer.Color = Color3.fromRGB(255,80,80)
    espObjects[p] = {box=box, name=name, dist=dist, tracer=tracer}
end
local function removeESP(p)
    local o = espObjects[p]
    if o then for _, v in pairs(o) do pcall(function() v:Remove() end) end espObjects[p] = nil end
end

local FlyBV, FlyBG

RunService.RenderStepped:Connect(function(dt)
    if Config.Aimbot then
        local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local target, bestDist = nil, Config.AimbotFOV

        if Config.AimbotLock and LockedTarget then
            local p = LockedTarget
            if p.Parent and isAlive(p) and not isExcluded(p) then
                local part = p.Character and p.Character:FindFirstChild(Config.AimbotPart)
                if part and isVisible(part) then
                    local sp, on = Camera:WorldToViewportPoint(part.Position)
                    if on and sp.Z > 0 then
                        local d = (Vector2.new(sp.X,sp.Y) - center).Magnitude
                        if d < Config.AimbotFOV then target = part end
                    end
                end
            end
            if not target then LockedTarget = nil end
        end

        if not target then
            for _, p in ipairs(Players:GetPlayers()) do
                if not isExcluded(p) then
                    local part = p.Character and p.Character:FindFirstChild(Config.AimbotPart)
                    if part and isVisible(part) then
                        local sp, on = Camera:WorldToViewportPoint(part.Position)
                        if on and sp.Z > 0 then
                            local d = (Vector2.new(sp.X,sp.Y) - center).Magnitude
                            local wd = (Camera.CFrame.Position - part.Position).Magnitude
                            if d < bestDist and wd <= Config.AimbotMaxDist then bestDist = d target = part LockedTarget = p end
                        end
                    end
                end
            end
        end

        if target then
            local cur = Camera.CFrame
            local tgt = CFrame.new(cur.Position, target.Position)
            local maxAngle = math.rad(2.2)
            local dot = math.clamp(cur.LookVector:Dot(tgt.LookVector), -1, 1)
            local angle = math.acos(dot)
            if angle > maxAngle then
                local t = maxAngle / angle
                local newLook = cur.LookVector:Lerp(tgt.LookVector, t).Unit
                tgt = CFrame.new(cur.Position, cur.Position + newLook)
            end
            if Config.AimbotHumanize then
                local j = Vector3.new((math.random()-0.5)*0.15,(math.random()-0.5)*0.15,(math.random()-0.5)*0.15)
                tgt = tgt * CFrame.new(j)
            end
            Camera.CFrame = cur:Lerp(tgt, Config.AimbotSmooth / 100)
        end
    else
        LockedTarget = nil
    end

    if Config.Fly then
        local c = LocalPlayer.Character
        if c then
            local hrp = c:FindFirstChild("HumanoidRootPart")
            local h = c:FindFirstChildOfClass("Humanoid")
            if hrp and h then
                if not FlyBV or not FlyBV.Parent then
                    FlyBV = Instance.new("BodyVelocity") FlyBV.MaxForce = Vector3.new(1e5,1e5,1e5) FlyBV.Parent = hrp
                    FlyBG = Instance.new("BodyGyro") FlyBG.MaxTorque = Vector3.new(1e5,1e5,1e5) FlyBG.P = 3000 FlyBG.D = 500 FlyBG.Parent = hrp
                end
                local md = h.MoveDirection
                local camLook = Camera.CFrame.LookVector
                local flat = Vector3.new(camLook.X, 0, camLook.Z)
                if flat.Magnitude > 0.01 then flat = flat.Unit end
                local right = flat:Cross(Vector3.new(0,1,0))
                FlyBV.Velocity = flat * md.Z * Config.FlySpeed + right * md.X * Config.FlySpeed
                FlyBG.CFrame = Camera.CFrame
            end
        end
    else
        if FlyBV then FlyBV:Destroy() FlyBV = nil end
        if FlyBG then FlyBG:Destroy() FlyBG = nil end
    end

    local c = LocalPlayer.Character
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then
            if Config.SpeedOn then h.WalkSpeed = Config.SpeedValue
            elseif h.WalkSpeed > 16 then h.WalkSpeed = 16 end
            if Config.JumpOn then h.UseJumpPower = true h.JumpPower = Config.JumpValue end
        end
    end

    if Broadcast.LocalLabel then
        Broadcast.LocalLabel.TextColor3 = Color3.fromHSV(tick() % 1, 1, 1)
    end

    if not Drawing then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if not isExcluded(p) and Config.ESP then
            if not espObjects[p] then createESP(p) end
            local o = espObjects[p]
            if o then
                local ch = p.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                local head = ch and ch:FindFirstChild("Head")
                if hrp and head then
                    local top = head.Position + Vector3.new(0,0.5,0)
                    local bot = hrp.Position - Vector3.new(0,3,0)
                    local ts, ton = Camera:WorldToViewportPoint(top)
                    local bs, bon = Camera:WorldToViewportPoint(bot)
                    if ton and bon and ts.Z > 0 and bs.Z > 0 then
                        local hh = math.abs(ts.Y - bs.Y)
                        local ww = hh * 0.6
                        o.box.Size = Vector2.new(ww, hh)
                        o.box.Position = Vector2.new(ts.X - ww/2, ts.Y)
                        o.box.Visible = true
                        o.name.Text = p.Name
                        o.name.Position = Vector2.new(ts.X, ts.Y - 18)
                        o.name.Visible = true
                        local d = (Camera.CFrame.Position - hrp.Position).Magnitude
                        o.dist.Text = string.format("%d m", math.floor(d))
                        o.dist.Position = Vector2.new(ts.X, ts.Y - 4)
                        o.dist.Visible = true
                        if Config.Tracers then
                            o.tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                            o.tracer.To = Vector2.new(bs.X, bs.Y)
                            o.tracer.Visible = true
                        else
                            o.tracer.Visible = false
                        end
                    else
                        o.box.Visible = false o.name.Visible = false o.dist.Visible = false o.tracer.Visible = false
                    end
                end
            end
        else
            removeESP(p)
        end
    end
end)

UIS.JumpRequest:Connect(function()
    if Config.InfJump then
        local c = LocalPlayer.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    LockedTarget = nil
    FlyBV, FlyBG = nil, nil
    task.wait(0.5)
    if Broadcast.LocalGui then
        Broadcast.LocalGui:Destroy()
        attachLocalBillboard(Config.BroadcastText)
    end
end)

Players.PlayerRemoving:Connect(removeESP)

print("[OBSIDIAN] v6 loaded. Auto-inject running.")
