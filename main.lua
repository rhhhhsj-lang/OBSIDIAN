-- OBSIDIAN HUB v4 | Full Suite + Broadcast
-- Aimbot + ESP + Movement + Avatar + Nametag Broadcast

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
    NametagOn = false, NametagText = "OBSIDIAN", NametagRGB = true,
    BroadcastText = "OBSIDIAN",
    BroadcastSpam = false, BroadcastInterval = 3,
    AvatarUsername = "", TargetUsername = "",
}

local LockedTarget, LockedTargetTime = nil, 0

-- ============================================================
-- NAMETAG BROADCAST SYSTEM
-- ============================================================
local Broadcast = {
    LocalGui = nil, LocalLabel = nil,
    SpamThread = nil,
    KnownRemotes = {},
}

-- Method 1: Humanoid.DisplayName (Brookhaven and RP games read this)
local function setHumanoidDisplayName(text)
    local char = LocalPlayer.Character
    if not char then return false end
    local h = char:FindFirstChildOfClass("Humanoid")
    if not h then return false end
    pcall(function() h.DisplayName = text end)
    return true
end

-- Method 2: Chat bubble (replicates via server)
local function sendChatBubble(text)
    if not text or text == "" then return false end
    local fired = false

    -- Legacy chat
    local ok1 = pcall(function()
        local ev = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if ev then
            local say = ev:FindFirstChild("SayMessageRequest")
            if say then say:FireServer(text, "All") fired = true end
        end
    end)

    -- TextChatService (newer)
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local ch = TextChatService:FindFirstChild("TextChannels")
            if ch then
                local g = ch:FindFirstChild("RBXGeneral") or ch:FindFirstChild("General")
                if g then g:SendAsync(text) fired = true end
            end
        end
    end)

    return fired
end

-- Method 3: Scan ALL remotes and attempt to set nametag via them
local function scanNametagRemotes()
    Broadcast.KnownRemotes = {}
    local patterns = {
        "nametag", "nameplate", "name_tag", "name_plate",
        "overhead", "tag", "title", "displayname", "display_name",
        "setname", "set_name", "changedname", "rename",
        "billboard", "label", "chat", "say", "message", "bubble",
        "nametagupdate", "updatename", "customname", "prefix", "suffix",
    }

    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
            local n = obj.Name:lower()
            for _, pat in ipairs(patterns) do
                if n:find(pat) then
                    table.insert(Broadcast.KnownRemotes, obj)
                    break
                end
            end
        end
    end
    print("[OBSIDIAN] Found " .. #Broadcast.KnownRemotes .. " nametag-related remotes")
    return #Broadcast.KnownRemotes
end

-- Method 4: Fire all nameplate remotes with many arg variations
local function fireNametagRemotes(text)
    if #Broadcast.KnownRemotes == 0 then scanNametagRemotes() end
    local char = LocalPlayer.Character
    local head = char and char:FindFirstChild("Head")

    local argsets = {
        {text},
        {"SetName", text},
        {"SetText", text},
        {"Set", text},
        {LocalPlayer, text},
        {char, text},
        {head, text},
        {LocalPlayer.UserId, text},
        {text, Color3.fromRGB(255, 255, 255)},
        {"UpdateName", text},
        {"ChangeName", text},
        {"SetDisplayName", text},
        {"nametag", text},
        {"chatbubble", text},
        {text, "All"},
        {"All", text},
        {text, 1},
        {1, text},
    }

    local count = 0
    for _, r in ipairs(Broadcast.KnownRemotes) do
        for _, args in ipairs(argsets) do
            pcall(function() r:FireServer(table.unpack(args)) end)
        end
        count = count + 1
    end
    print("[OBSIDIAN] Fired " .. count .. " remotes x " .. #argsets .. " arg sets")
end

-- Method 5: Local billboard (fallback, you only)
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
    bb.MaxDistance = 1000
    bb.Parent = head

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true
    lbl.TextStrokeTransparency = 0.2
    lbl.Parent = bb

    Broadcast.LocalGui = bb
    Broadcast.LocalLabel = lbl
end

local function detachLocalBillboard()
    if Broadcast.LocalGui then
        Broadcast.LocalGui:Destroy()
        Broadcast.LocalGui = nil
        Broadcast.LocalLabel = nil
    end
end

-- ===== The full broadcast trigger =====
function Broadcast.trigger(text)
    if not text or text == "" then return end
    -- Best-effort: all methods together
    setHumanoidDisplayName(text)
    sendChatBubble(text)
    fireNametagRemotes(text)
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
local function applyAvatarFromUserId(userId)
    local char = LocalPlayer.Character
    if not char then return false end
    local h = char:FindFirstChildOfClass("Humanoid")
    if not h then return false end
    local ok, desc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, userId)
    if not ok or not desc then return false end
    local ok2 = pcall(function() h:ApplyDescriptionReset(desc) end)
    if ok2 then return true end
    local ok3 = pcall(function() h:ApplyDescription(desc) end)
    return ok3
end

local function applyAvatarFromUsername(username)
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
    return applyAvatarFromUserId(uid)
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
local FW = math.clamp(vp.X * 0.9, 310, 400)
local FH = math.clamp(vp.Y * 0.72, 420, 540)

-- Floating Icon
local Icon = Instance.new("ImageButton")
Icon.Size = UDim2.new(0, 52, 0, 52)
Icon.Position = UDim2.new(0, 15, 0, 100)
Icon.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
Icon.BorderSizePixel = 0
Icon.AutoButtonColor = false
Icon.Active = true
Icon.Parent = ScreenGui
local IC = Instance.new("UICorner") IC.CornerRadius = UDim.new(1, 0) IC.Parent = Icon
local IStr = Instance.new("UIStroke") IStr.Color = Color3.fromRGB(90, 140, 220) IStr.Thickness = 2 IStr.Parent = Icon
local ILbl = Instance.new("TextLabel")
ILbl.Size = UDim2.new(1, 0, 1, 0) ILbl.BackgroundTransparency = 1
ILbl.Text = "V" ILbl.TextColor3 = Color3.fromRGB(255, 255, 255)
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
Main.Size = UDim2.new(0, 0, 0, FH)
Main.Position = UDim2.new(0.5, -FW/2, 0.5, -FH/2)
Main.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.Visible = false
Main.ClipsDescendants = true
Main.Parent = ScreenGui
local MC = Instance.new("UICorner") MC.CornerRadius = UDim.new(0, 12) MC.Parent = Main
local MStr = Instance.new("UIStroke") MStr.Color = Color3.fromRGB(90, 140, 220) MStr.Thickness = 1.5 MStr.Transparency = 0.4 MStr.Parent = Main

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 42) Header.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
Header.BorderSizePixel = 0 Header.Parent = Main
local HC = Instance.new("UICorner") HC.CornerRadius = UDim.new(0, 12) HC.Parent = Header

local HText = Instance.new("TextLabel")
HText.Size = UDim2.new(1, -80, 1, 0) HText.Position = UDim2.new(0, 12, 0, 0)
HText.BackgroundTransparency = 1 HText.Text = "OBSIDIAN  •  HUB"
HText.TextColor3 = Color3.fromRGB(255, 255, 255)
HText.TextXAlignment = Enum.TextXAlignment.Left
HText.Font = Enum.Font.GothamBold HText.TextSize = 13 HText.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28) CloseBtn.Position = UDim2.new(1, -34, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(210, 55, 55) CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255) CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13 CloseBtn.BorderSizePixel = 0 CloseBtn.Parent = Header
local CBC = Instance.new("UICorner") CBC.CornerRadius = UDim.new(0, 7) CBC.Parent = CloseBtn

-- Left Tab Strip
local TabStrip = Instance.new("Frame")
TabStrip.Size = UDim2.new(0, 68, 1, -52)
TabStrip.Position = UDim2.new(0, 6, 0, 48)
TabStrip.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
TabStrip.BorderSizePixel = 0 TabStrip.Parent = Main
local TSC = Instance.new("UICorner") TSC.CornerRadius = UDim.new(0, 8) TSC.Parent = TabStrip

local TabLayout = Instance.new("UIListLayout")
TabLayout.Padding = UDim.new(0, 5)
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabLayout.Parent = TabStrip
local TabPad = Instance.new("UIPadding") TabPad.PaddingTop = UDim.new(0, 6) TabPad.Parent = TabStrip

-- Content
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -80, 1, -52)
ContentArea.Position = UDim2.new(0, 76, 0, 48)
ContentArea.BackgroundTransparency = 1 ContentArea.Parent = Main

local Pages = {}
local function makePage(name)
    local p = Instance.new("ScrollingFrame")
    p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1 p.BorderSizePixel = 0
    p.ScrollBarThickness = 3
    p.ScrollBarImageColor3 = Color3.fromRGB(90, 140, 220)
    p.ScrollBarImageTransparency = 0.3
    p.Visible = false p.Parent = ContentArea
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = p
    l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        p.CanvasSize = UDim2.new(0, 0, 0, l.AbsoluteContentSize.Y + 8)
    end)
    Pages[name] = p
    return p
end

local TabButtons = {}
local function showPage(name)
    for n, p in pairs(Pages) do p.Visible = (n == name) end
    for n, b in pairs(TabButtons) do
        if n == name then
            b.BackgroundColor3 = Color3.fromRGB(60, 90, 140)
            b.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            b.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
            b.TextColor3 = Color3.fromRGB(200, 200, 210)
        end
    end
end

local function makeTab(label, pageName)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 58, 0, 58)
    Btn.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
    Btn.Text = label
    Btn.TextColor3 = Color3.fromRGB(200, 200, 210)
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 11
    Btn.TextWrapped = true
    Btn.BorderSizePixel = 0
    Btn.AutoButtonColor = false
    Btn.Parent = TabStrip
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = Btn
    Btn.MouseButton1Click:Connect(function() showPage(pageName) end)
    TabButtons[pageName] = Btn
    return Btn
end

local function makeHeader(parent, text)
    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(1, 0, 0, 22)
    L.BackgroundColor3 = Color3.fromRGB(36, 36, 50)
    L.BorderSizePixel = 0
    L.Text = "  " .. text
    L.TextColor3 = Color3.fromRGB(90, 160, 240)
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Font = Enum.Font.GothamBold
    L.TextSize = 11
    L.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 4) c.Parent = L
end

local function makeToggle(parent, text, key, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 32)
    Btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    Btn.TextColor3 = Color3.fromRGB(215, 215, 220)
    Btn.Text = "  " .. text .. "  |  OFF"
    Btn.TextXAlignment = Enum.TextXAlignment.Left
    Btn.Font = Enum.Font.Gotham
    Btn.TextSize = 11
    Btn.BorderSizePixel = 0
    Btn.AutoButtonColor = false
    Btn.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = Btn
    Btn.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        Btn.Text = "  " .. text .. "  |  " .. (Config[key] and "ON" or "OFF")
        Btn.BackgroundColor3 = Config[key] and Color3.fromRGB(45, 85, 55) or Color3.fromRGB(30, 30, 40)
        if callback then callback(Config[key]) end
    end)
    return Btn
end

local function makeSlider(parent, text, key, min, max, default)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 42)
    Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    Frame.BorderSizePixel = 0 Frame.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = Frame

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -12, 0, 18)
    Lbl.Position = UDim2.new(0, 6, 0, 2)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = text .. ": " .. default
    Lbl.TextColor3 = Color3.fromRGB(215, 215, 220)
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Font = Enum.Font.Gotham Lbl.TextSize = 11 Lbl.Parent = Frame

    local Bar = Instance.new("Frame")
    Bar.Size = UDim2.new(1, -20, 0, 6)
    Bar.Position = UDim2.new(0, 10, 0, 28)
    Bar.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    Bar.BorderSizePixel = 0 Bar.Parent = Frame
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(1, 0) bc.Parent = Bar

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(90, 140, 220)
    Fill.BorderSizePixel = 0 Fill.Parent = Bar
    local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1, 0) fc.Parent = Fill

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
            Fill.Size = UDim2.new(rel, 0, 1, 0)
            local val = math.floor(min + (max - min) * rel)
            Lbl.Text = text .. ": " .. val
            Config[key] = val
        end
    end)
end

local function makeButton(parent, text, callback, color)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 30)
    Btn.BackgroundColor3 = color or Color3.fromRGB(60, 100, 165)
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.Text = text
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 11
    Btn.TextWrapped = true
    Btn.BorderSizePixel = 0
    Btn.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = Btn
    Btn.MouseButton1Click:Connect(callback)
    return Btn
end

local function makeInput(parent, label, key, placeholder)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 46)
    Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    Frame.BorderSizePixel = 0 Frame.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = Frame

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -12, 0, 16)
    Lbl.Position = UDim2.new(0, 6, 0, 2)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = label
    Lbl.TextColor3 = Color3.fromRGB(215, 215, 220)
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Font = Enum.Font.Gotham Lbl.TextSize = 10 Lbl.Parent = Frame

    local Box = Instance.new("TextBox")
    Box.Size = UDim2.new(1, -12, 0, 22)
    Box.Position = UDim2.new(0, 6, 0, 18)
    Box.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    Box.BorderSizePixel = 0
    Box.PlaceholderText = placeholder or ""
    Box.PlaceholderColor3 = Color3.fromRGB(110, 110, 125)
    Box.TextColor3 = Color3.fromRGB(220, 220, 220)
    Box.Font = Enum.Font.Gotham
    Box.TextSize = 11
    Box.ClearTextOnFocus = false
    Box.Parent = Frame
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 4) bc.Parent = Box
    Box.FocusLost:Connect(function() Config[key] = Box.Text end)
    return Box
end

-- ============================================================
-- PAGES
-- ============================================================
makePage("combat")
makePage("move")
makePage("broadcast")
makePage("char")
makePage("players")
makePage("tools")

-- ===== COMBAT =====
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

-- ===== MOVE =====
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

-- ===== BROADCAST =====
local bc = Pages["broadcast"]
makeHeader(bc, "الرسالة فوق الرأس")
makeInput(bc, "نص الرسالة", "BroadcastText", "اكتب رسالتك")

makeButton(bc, "بث للجميع (3 طرق معاً)", function()
    Broadcast.trigger(Config.BroadcastText)
    print("[OBSIDIAN] Full broadcast triggered: " .. Config.BroadcastText)
end, Color3.fromRGB(60, 150, 85))

makeButton(bc, "طريقة 1: Humanoid DisplayName", function()
    setHumanoidDisplayName(Config.BroadcastText)
    print("[OBSIDIAN] DisplayName set (Brookhaven reads this)")
end, Color3.fromRGB(70, 110, 180))

makeButton(bc, "طريقة 2: Chat Bubble", function()
    sendChatBubble(Config.BroadcastText)
    print("[OBSIDIAN] Chat bubble sent")
end, Color3.fromRGB(70, 110, 180))

makeButton(bc, "طريقة 3: فحص وفتح Remotes", function()
    scanNametagRemotes()
    fireNametagRemotes(Config.BroadcastText)
end, Color3.fromRGB(140, 100, 60))

makeHeader(bc, "خيارات")
makeToggle(bc, "تكرار تلقائي", "BroadcastSpam", function(v)
    if v then Broadcast.startSpam() else Broadcast.stopSpam() end
end)
makeSlider(bc, "الفاصل الزمني", "BroadcastInterval", 1, 10, 3)

makeButton(bc, "تثبيت محلي (لك فقط)", function()
    attachLocalBillboard(Config.BroadcastText)
end, Color3.fromRGB(80, 80, 130))

makeButton(bc, "إزالة المحلي", function()
    detachLocalBillboard()
end, Color3.fromRGB(120, 70, 70))

-- ===== CHAR =====
local charPage = Pages["char"]
makeHeader(charPage, "نسخ أفاتار")
makeInput(charPage, "اسم اللاعب", "AvatarUsername", "اكتب الاسم")
makeButton(charPage, "نسخ الأفاتار", function()
    if Config.AvatarUsername == "" then return end
    local ok = applyAvatarFromUsername(Config.AvatarUsername)
    print("[OBSIDIAN] Avatar copy: " .. tostring(ok))
end, Color3.fromRGB(60, 140, 85))

makeHeader(charPage, "أدوات")
makeButton(charPage, "إزالة الملحقات", function()
    local c = LocalPlayer.Character
    if not c then return end
    for _, v in ipairs(c:GetChildren()) do
        if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants") or v:IsA("Hat") then v:Destroy() end
    end
end, Color3.fromRGB(140, 60, 60))

makeButton(charPage, "لون عشوائي", function()
    local c = LocalPlayer.Character
    if not c then return end
    for _, v in ipairs(c:GetChildren()) do
        if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then v.BrickColor = BrickColor.random() end
    end
end, Color3.fromRGB(140, 100, 55))

-- ===== PLAYERS =====
local plyPage = Pages["players"]
makeHeader(plyPage, "استهداف لاعب")
makeInput(plyPage, "اسم اللاعب", "TargetUsername", "اكتب الاسم")

makeButton(plyPage, "الانتقال إليه", function()
    if Config.TargetUsername == "" then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == Config.TargetUsername:lower() and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp and myHrp then myHrp.CFrame = hrp.CFrame * CFrame.new(0, 0, 3) end
            return
        end
    end
end, Color3.fromRGB(60, 140, 85))

makeButton(plyPage, "محاولة قذفه (Remotes)", function()
    if Config.TargetUsername == "" then return end
    local target
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == Config.TargetUsername:lower() then target = p break end
    end
    if not target or not target.Character then return end
    local hrp = target.Character:FindFirstChild("HumanoidRootPart")

    local fired = 0
    for _, r in ipairs(game:GetDescendants()) do
        if r:IsA("RemoteEvent") then
            local n = r.Name:lower()
            if n:find("launch") or n:find("push") or n:find("fling") or n:find("velocity") or n:find("jump") or n:find("ragdoll") or n:find("hit") then
                pcall(function() r:FireServer(target, Vector3.new(0, 800, 0)) end)
                pcall(function() r:FireServer(target, 500) end)
                pcall(function() r:FireServer(hrp, Vector3.new(0, 800, 0)) end)
                fired = fired + 1
            end
        end
    end
    print("[OBSIDIAN] Fired " .. fired .. " launch remotes")
end, Color3.fromRGB(180, 70, 70))

-- ===== TOOLS =====
local tools = Pages["tools"]
makeHeader(tools, "أدوات عامة")
makeButton(tools, "إعادة الشخصية", function()
    local c = LocalPlayer.Character
    if c then c:BreakJoints() end
end, Color3.fromRGB(80, 80, 90))

makeButton(tools, "طباعة معلومات", function()
    print("PlaceId:", game.PlaceId)
    print("FilteringEnabled:", Workspace.FilteringEnabled)
    print("StreamingEnabled:", Workspace.StreamingEnabled)
    print("Players:", #Players:GetPlayers())
    print("Drawing:", tostring(Drawing ~= nil))
    print("hookmetamethod:", tostring(hookmetamethod ~= nil))
end, Color3.fromRGB(70, 110, 170))

makeButton(tools, "فحص Remotes", function()
    local n = scanNametagRemotes()
    print("[OBSIDIAN] Found " .. n .. " nametag remotes")
end, Color3.fromRGB(70, 110, 170))

-- Tabs
makeTab("قتال", "combat")
makeTab("حركة", "move")
makeTab("بث", "broadcast")
makeTab("شخصية", "char")
makeTab("لاعبين", "players")
makeTab("أدوات", "tools")

showPage("broadcast")

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
-- LOGIC
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
    -- Aimbot
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
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        local wd = (Camera.CFrame.Position - part.Position).Magnitude
                        if d < Config.AimbotFOV and wd <= Config.AimbotMaxDist then target = part end
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
                            local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
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
                local j = Vector3.new((math.random()-0.5)*0.15, (math.random()-0.5)*0.15, (math.random()-0.5)*0.15)
                tgt = tgt * CFrame.new(j)
            end
            Camera.CFrame = cur:Lerp(tgt, Config.AimbotSmooth / 100)
        end
    else
        LockedTarget = nil
    end

    -- Fly
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

    -- Speed / Jump
    local c = LocalPlayer.Character
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then
            if Config.SpeedOn then h.WalkSpeed = Config.SpeedValue
            elseif h.WalkSpeed > 16 then h.WalkSpeed = 16 end
            if Config.JumpOn then h.UseJumpPower = true h.JumpPower = Config.JumpValue end
        end
    end

    -- Local billboard RGB + reattach
    if Broadcast.LocalLabel and Config.NametagRGB then
        Broadcast.LocalLabel.TextColor3 = Color3.fromHSV(tick() % 1, 1, 1)
    end

    -- ESP
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
                    local top = head.Position + Vector3.new(0, 0.5, 0)
                    local bot = hrp.Position - Vector3.new(0, 3, 0)
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
    if Broadcast.LocalGui then detachLocalBillboard() attachLocalBillboard(Config.BroadcastText) end
end)

Players.PlayerRemoving:Connect(removeESP)

-- Auto scan remotes on start
task.spawn(function()
    task.wait(2)
    scanNametagRemotes()
end)

print("[OBSIDIAN] v4 Full Suite loaded.")
