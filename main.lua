-- OBSIDIAN HUB | Billboard Broadcast Edition
-- Message above head visible to all players via chat replication

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

print("[OBSIDIAN] Billboard Broadcast loaded")

-- ============================================================
-- BILLBOARD BROADCAST SYSTEM
-- ============================================================
local Broadcast = {
    Text = "OBSIDIAN",
    RGB = true,
    Spam = false,
    SpamInterval = 3,
    Loop = false,
    LocalBillboard = nil,
    LocalLabel = nil,
}

-- ===== Method 1: Local billboard (only you see it, always works) =====
function Broadcast.attachLocal()
    local char = LocalPlayer.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    if Broadcast.LocalBillboard then Broadcast.LocalBillboard:Destroy() end

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
    lbl.Text = Broadcast.Text
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true
    lbl.TextStrokeTransparency = 0.3
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.Parent = bb

    Broadcast.LocalBillboard = bb
    Broadcast.LocalLabel = lbl
end

function Broadcast.detachLocal()
    if Broadcast.LocalBillboard then
        Broadcast.LocalBillboard:Destroy()
        Broadcast.LocalBillboard = nil
        Broadcast.LocalLabel = nil
    end
end

-- ===== Method 2: Chat bubble broadcast (replicates to ALL players) =====
-- This uses the legacy chat system - works in most games including Brookhaven
function Broadcast.sendChat(message)
    if not message or message == "" then return false end

    -- Method A: Legacy SayMessageRequest
    local ok1 = pcall(function()
        local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if chatEvents then
            local say = chatEvents:FindFirstChild("SayMessageRequest")
            if say then
                say:FireServer(message, "All")
                return true
            end
        end
        return false
    end)

    -- Method B: TextChatService (newer)
    local ok2 = pcall(function()
        if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local channels = TextChatService:FindFirstChild("TextChannels")
            if channels then
                local general = channels:FindFirstChild("RBXGeneral") or channels:FindFirstChild("General")
                if general then
                    general:SendAsync(message)
                end
            end
        end
    end)

    -- Method C: Fire any remote with "say" or "chat" in name
    local ok3 = pcall(function()
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                local n = obj.Name:lower()
                if n:find("say") or n:find("chat") or n:find("message") or n:find("bubble") then
                    pcall(function() obj:FireServer(message, "All") end)
                    pcall(function() obj:FireServer(message) end)
                    pcall(function() obj:FireServer("All", message) end)
                end
            end
        end
    end)

    return ok1 or ok2 or ok3
end

-- ===== Method 3: Try to hijack game nametag system =====
function Broadcast.tryGameNametag(message, color)
    local found = 0
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local n = obj.Name:lower()
            if n:find("nametag") or n:find("nameplate") or n:find("billboard") or n:find("tag") or n:find("overhead") then
                pcall(function() obj:FireServer(message) end)
                pcall(function() obj:FireServer(LocalPlayer, message) end)
                pcall(function() obj:FireServer("SetText", message) end)
                pcall(function() obj:FireServer("SetName", message) end)
                if color then
                    pcall(function() obj:FireServer("SetColor", color) end)
                end
                found = found + 1
            end
        end
    end
    print("[OBSIDIAN] Tried " .. found .. " nametag remotes")
    return found
end

-- ===== Loop =====
local spamThread = nil

function Broadcast.startSpam()
    if spamThread then return end
    Broadcast.Spam = true
    spamThread = task.spawn(function()
        while Broadcast.Spam do
            if Broadcast.Loop then
                -- alternate between chat bubble and game nametag
                Broadcast.sendChat(Broadcast.Text)
                Broadcast.tryGameNametag(Broadcast.Text, Color3.fromRGB(255, 100, 100))
            else
                Broadcast.sendChat(Broadcast.Text)
            end
            task.wait(Broadcast.SpamInterval)
        end
    end)
end

function Broadcast.stopSpam()
    Broadcast.Spam = false
    spamThread = nil
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
local FW = math.clamp(vp.X * 0.9, 300, 380)
local FH = math.clamp(vp.Y * 0.6, 380, 460)

-- Icon
local Icon = Instance.new("ImageButton")
Icon.Size = UDim2.new(0, 52, 0, 52)
Icon.Position = UDim2.new(0, 15, 0, 100)
Icon.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
Icon.BorderSizePixel = 0
Icon.AutoButtonColor = false
Icon.Active = true
Icon.Parent = ScreenGui
local IC = Instance.new("UICorner") IC.CornerRadius = UDim.new(1, 0) IC.Parent = Icon
local IStr = Instance.new("UIStroke")
IStr.Color = Color3.fromRGB(90, 140, 220)
IStr.Thickness = 2
IStr.Parent = Icon
local ILbl = Instance.new("TextLabel")
ILbl.Size = UDim2.new(1, 0, 1, 0)
ILbl.BackgroundTransparency = 1
ILbl.Text = "V"
ILbl.TextColor3 = Color3.fromRGB(255, 255, 255)
ILbl.Font = Enum.Font.GothamBlack
ILbl.TextSize = 26
ILbl.Parent = Icon

local iconDrag = false
local iconStart, iconPos
Icon.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        iconDrag = false
        iconStart = input.Position
        iconPos = Icon.Position
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
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        iconStart = nil
    end
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
local MStr = Instance.new("UIStroke")
MStr.Color = Color3.fromRGB(90, 140, 220)
MStr.Thickness = 1.5
MStr.Transparency = 0.4
MStr.Parent = Main

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
Header.BorderSizePixel = 0
Header.Parent = Main
local HC = Instance.new("UICorner") HC.CornerRadius = UDim.new(0, 12) HC.Parent = Header

local HText = Instance.new("TextLabel")
HText.Size = UDim2.new(1, -80, 1, 0)
HText.Position = UDim2.new(0, 12, 0, 0)
HText.BackgroundTransparency = 1
HText.Text = "OBSIDIAN  •  BROADCAST"
HText.TextColor3 = Color3.fromRGB(255, 255, 255)
HText.TextXAlignment = Enum.TextXAlignment.Left
HText.Font = Enum.Font.GothamBold
HText.TextSize = 13
HText.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(210, 55, 55)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Header
local CBC = Instance.new("UICorner") CBC.CornerRadius = UDim.new(0, 7) CBC.Parent = CloseBtn

-- Content
local Container = Instance.new("ScrollingFrame")
Container.Size = UDim2.new(1, -16, 1, -52)
Container.Position = UDim2.new(0, 8, 0, 44)
Container.BackgroundTransparency = 1
Container.BorderSizePixel = 0
Container.ScrollBarThickness = 3
Container.ScrollBarImageColor3 = Color3.fromRGB(90, 140, 220)
Container.CanvasSize = UDim2.new(0, 0, 0, 0)
Container.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 6)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Container
Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Container.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + 8)
end)

local function makeHeader(text)
    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(1, 0, 0, 22)
    L.BackgroundColor3 = Color3.fromRGB(36, 36, 50)
    L.BorderSizePixel = 0
    L.Text = "  " .. text
    L.TextColor3 = Color3.fromRGB(90, 160, 240)
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Font = Enum.Font.GothamBold
    L.TextSize = 12
    L.Parent = Container
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 4) c.Parent = L
end

local function makeToggle(text, default, callback)
    local state = default or false
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 32)
    Btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    Btn.TextColor3 = Color3.fromRGB(215, 215, 220)
    Btn.Text = "  " .. text .. "  |  OFF"
    Btn.TextXAlignment = Enum.TextXAlignment.Left
    Btn.Font = Enum.Font.Gotham
    Btn.TextSize = 12
    Btn.BorderSizePixel = 0
    Btn.AutoButtonColor = false
    Btn.Parent = Container
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = Btn
    Btn.MouseButton1Click:Connect(function()
        state = not state
        Btn.Text = "  " .. text .. "  |  " .. (state and "ON" or "OFF")
        Btn.BackgroundColor3 = state and Color3.fromRGB(45, 85, 55) or Color3.fromRGB(30, 30, 40)
        if callback then callback(state) end
    end)
    return function() return state end
end

local function makeButton(text, callback, color)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 32)
    Btn.BackgroundColor3 = color or Color3.fromRGB(60, 100, 165)
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.Text = text
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 12
    Btn.TextWrapped = true
    Btn.BorderSizePixel = 0
    Btn.Parent = Container
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = Btn
    Btn.MouseButton1Click:Connect(callback)
    return Btn
end

local function makeInput(label, callback, placeholder)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 48)
    Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    Frame.BorderSizePixel = 0
    Frame.Parent = Container
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = Frame

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -12, 0, 16)
    Lbl.Position = UDim2.new(0, 6, 0, 2)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = label
    Lbl.TextColor3 = Color3.fromRGB(215, 215, 220)
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Font = Enum.Font.Gotham
    Lbl.TextSize = 11
    Lbl.Parent = Frame

    local Box = Instance.new("TextBox")
    Box.Size = UDim2.new(1, -12, 0, 24)
    Box.Position = UDim2.new(0, 6, 0, 20)
    Box.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    Box.BorderSizePixel = 0
    Box.PlaceholderText = placeholder or ""
    Box.PlaceholderColor3 = Color3.fromRGB(110, 110, 125)
    Box.TextColor3 = Color3.fromRGB(220, 220, 220)
    Box.Font = Enum.Font.Gotham
    Box.TextSize = 12
    Box.ClearTextOnFocus = false
    Box.Parent = Frame
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 4) bc.Parent = Box
    Box.FocusLost:Connect(function() if callback then callback(Box.Text) end end)
    return Box
end

-- ============ BUILD UI ============
makeHeader("نص الرسالة")
makeInput("الرسالة العائمة", function(text)
    Broadcast.Text = text
    if Broadcast.LocalLabel then Broadcast.LocalLabel.Text = text end
end, "اكتب رسالتك هنا")

makeHeader("الطريقة")
makeButton("الرسالة المحلية (أنا فقط)", function()
    Broadcast.attachLocal()
    print("[OBSIDIAN] Local billboard attached")
end, Color3.fromRGB(70, 110, 180))

makeButton("بث للجميع (Chat Bubble)", function()
    Broadcast.sendChat(Broadcast.Text)
    print("[OBSIDIAN] Broadcast: " .. Broadcast.Text)
end, Color3.fromRGB(60, 140, 85))

makeButton("محاولة via Remotes اللعبة", function()
    Broadcast.tryGameNametag(Broadcast.Text, Color3.fromRGB(255, 100, 100))
end, Color3.fromRGB(140, 100, 60))

makeHeader("خيارات متقدمة")
local rgbGetter = makeToggle("ألوان RGB للرسالة", true, function(v) Broadcast.RGB = v end)
local spamGetter = makeToggle("تكرار تلقائي", false, function(v)
    if v then Broadcast.startSpam() else Broadcast.stopSpam() end
end)
local loopGetter = makeToggle("بث مزدوج (chat + remote)", false, function(v) Broadcast.Loop = v end)

makeHeader("تحكم")
makeButton("إزالة الرسالة المحلية", function()
    Broadcast.detachLocal()
    print("[OBSIDIAN] Removed local billboard")
end, Color3.fromRGB(140, 60, 60))

makeButton("إيقاف كل شي", function()
    Broadcast.stopSpam()
    Broadcast.detachLocal()
    print("[OBSIDIAN] Stopped everything")
end, Color3.fromRGB(150, 50, 50))

makeHeader("معلومات")
local infoLbl = Instance.new("TextLabel")
infoLbl.Size = UDim2.new(1, 0, 0, 120)
infoLbl.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
infoLbl.BorderSizePixel = 0
infoLbl.Text = "  Chat Bubble: يعمل عبر السيرفر\n  يظهر للجميع كفقاعة شات\n\n  Local Billboard: تراه أنت فقط\n  Remotes: يعتمد على اللعبة"
infoLbl.TextColor3 = Color3.fromRGB(180, 180, 190)
infoLbl.TextXAlignment = Enum.TextXAlignment.Left
infoLbl.TextYAlignment = Enum.TextYAlignment.Top
infoLbl.TextWrapped = true
infoLbl.Font = Enum.Font.Gotham
infoLbl.TextSize = 11
infoLbl.Parent = Container
local iC = Instance.new("UICorner") iC.CornerRadius = UDim.new(0, 6) iC.Parent = infoLbl

-- Menu
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
-- CORE LOOP
-- ============================================================
RunService.RenderStepped:Connect(function()
    -- RGB color animation
    if Broadcast.RGB and Broadcast.LocalLabel then
        Broadcast.LocalLabel.TextColor3 = Color3.fromHSV(tick() % 1, 1, 1)
    end

    -- Auto-reattach local billboard if character respawned
    if Broadcast.Text and Broadcast.Text ~= "" then
        local char = LocalPlayer.Character
        if char then
            local head = char:FindFirstChild("Head")
            if head and not head:FindFirstChild("__OBSIDIAN_TAG") and Broadcast.LocalBillboard then
                Broadcast.attachLocal()
            end
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if Broadcast.Text and Broadcast.Text ~= "" then
        Broadcast.attachLocal()
    end
end)

print("[OBSIDIAN] Billboard Broadcast ready. Open menu -> write message -> send.")
