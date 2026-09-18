local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

print("[OBSIDIAN] loading...")

local Config = {
    Aimbot = false, AimbotSmooth = 8, AimbotFOV = 140, AimbotPart = "Head",
    AimbotMaxDist = 600, AimbotLock = false, AimbotHumanize = true, AimbotVisibleCheck = true,
    ESP = false, Tracers = true,
    TeamCheck = true, FriendCheck = true,
    Fly = false, FlySpeed = 55,
    SpeedOn = false, SpeedValue = 40,
    JumpOn = false, JumpValue = 90, InfJump = false,
    BioText = "",
}
local LockedTarget = nil
local FlyBV, FlyFG

-- ============================================================
-- BIO INJECTOR
-- ============================================================
local Bio = {
    KnownRemotes = {},
    Captured = {},
    Hooked = false,
}

local bioKeywords = {
    "bio", "status", "about", "description", "profile",
    "aboutme", "about_me", "setstatus", "setbio", "setdesc",
    "setdescription", "setprofile", "custombio", "biochange",
    "updatebio", "updatestatus", "abouttext", "signature",
    "setabout", "setinfo", "setmessage", "tagline", "subtitle",
    "settag", "customstatus", "changestatus", "changebio",
    "customtext", "playertag", "playernameplate", "setnote",
    "note", "rpdesc", "rpinfo", "roleplaydesc",
}

local function matchesBio(name)
    local n = name:lower()
    for _, k in ipairs(bioKeywords) do
        if n:find(k) then return k end
    end
    return nil
end

function Bio.scan()
    Bio.KnownRemotes = {}
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local k = matchesBio(obj.Name)
            if k then
                table.insert(Bio.KnownRemotes, {
                    obj = obj, name = obj.Name,
                    path = obj:GetFullName(), keyword = k,
                })
            end
        end
    end
    print("[BIO] Found " .. #Bio.KnownRemotes .. " bio remotes")
    for _, r in ipairs(Bio.KnownRemotes) do
        print("  [" .. r.keyword .. "] " .. r.path)
    end
    return #Bio.KnownRemotes
end

function Bio.installHook()
    if Bio.Hooked then return true end
    if not getrawmetatable or not setreadonly or not newcclosure or not getnamecallmethod then
        return false
    end
    local mt = getrawmetatable(game)
    if not mt then return false end
    local oldNC = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" or method == "InvokeServer" then
            if typeof(self) == "Instance" and
               (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
                local k = matchesBio(self.Name)
                if k then
                    local exists = false
                    for _, r in ipairs(Bio.KnownRemotes) do
                        if r.obj == self then exists = true break end
                    end
                    if not exists then
                        table.insert(Bio.KnownRemotes, {
                            obj = self, name = self.Name,
                            path = self:GetFullName(), keyword = k,
                        })
                        print("[BIO] Learned: " .. self.Name)
                    end
                end
            end
        end
        return oldNC(self, ...)
    end)
    setreadonly(mt, true)
    Bio.Hooked = true
    return true
end

local function generateBioPayloads(text)
    local lp = LocalPlayer
    local uid = lp.UserId
    local name = lp.Name
    local char = lp.Character
    return {
        {text}, {lp, text}, {text, lp},
        {uid, text}, {text, uid},
        {name, text}, {text, name},
        {"SetBio", text}, {"SetStatus", text}, {"SetDescription", text},
        {"SetAbout", text}, {"UpdateBio", text}, {"ChangeBio", text},
        {"Bio", text}, {"bio", text}, {"Set", text},
        {char, text}, {text, char},
        {text, true}, {true, text},
        {text, 1}, {1, text},
        {text, "All"}, {"All", text},
    }
end

function Bio.attemptAll(text, delay)
    delay = delay or 0.15
    if #Bio.KnownRemotes == 0 then Bio.scan() end
    if #Bio.KnownRemotes == 0 then
        print("[BIO] No remotes found")
        return 0
    end
    local payloads = generateBioPayloads(text)
    local total = 0
    for _, r in ipairs(Bio.KnownRemotes) do
        if r.obj.Parent then
            for _, payload in ipairs(payloads) do
                if r.obj.Parent then
                    pcall(function()
                        if r.obj:IsA("RemoteEvent") then
                            r.obj:FireServer(table.unpack(payload))
                        else
                            r.obj:InvokeServer(table.unpack(payload))
                        end
                    end)
                    total = total + 1
                end
                task.wait(delay)
            end
        end
    end
    print("[BIO] Fired " .. total .. " payloads")
    return total
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
local FW = math.clamp(vp.X * 0.94, 340, 450)
local FH = math.clamp(vp.Y * 0.82, 480, 620)

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
HText.Text = "OBSIDIAN HUB"
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

local TabStrip = Instance.new("ScrollingFrame")
TabStrip.Name = "TabStrip"
TabStrip.Size = UDim2.new(0, 68, 1, -52)
TabStrip.Position = UDim2.new(0, 6, 0, 48)
TabStrip.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
TabStrip.BorderSizePixel = 0
TabStrip.ScrollBarThickness = 2
TabStrip.ScrollBarImageColor3 = Color3.fromRGB(90, 140, 220)
TabStrip.CanvasSize = UDim2.new(0, 0, 0, 0)
TabStrip.AutomaticCanvasSize = Enum.AutomaticSize.Y
TabStrip.Parent = Main
local TSC = Instance.new("UICorner") TSC.CornerRadius = UDim.new(0, 8) TSC.Parent = TabStrip

local TabLayout = Instance.new("UIListLayout")
TabLayout.Padding = UDim.new(0, 5)
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabLayout.Parent = TabStrip
local TabPad = Instance.new("UIPadding")
TabPad.PaddingTop = UDim.new(0, 6)
TabPad.PaddingBottom = UDim.new(0, 6)
TabPad.Parent = TabStrip

local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -80, 1, -52)
ContentArea.Position = UDim2.new(0, 76, 0, 48)
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
    p.ScrollBarImageColor3 = Color3.fromRGB(90, 140, 220)
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
    pad.Parent = p
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
    local B = Instance.new("TextButton")
    B.Size = UDim2.new(0, 58, 0, 58)
    B.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
    B.Text = label
    B.TextColor3 = Color3.fromRGB(200, 200, 210)
    B.Font = Enum.Font.GothamBold
    B.TextSize = 11
    B.TextWrapped = true
    B.BorderSizePixel = 0
    B.AutoButtonColor = false
    B.Active = true
    B.Parent = TabStrip
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = B
    B.MouseButton1Click:Connect(function() showPage(pageName) end)
    TabButtons[pageName] = B
    return B
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

local function makeToggle(parent, text, key, cb)
    local B = Instance.new("TextButton")
    B.Size = UDim2.new(1, 0, 0, 32)
    B.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    B.TextColor3 = Color3.fromRGB(215, 215, 220)
    B.Text = "  " .. text .. "  |  OFF"
    B.TextXAlignment = Enum.TextXAlignment.Left
    B.Font = Enum.Font.Gotham
    B.TextSize = 11
    B.BorderSizePixel = 0
    B.AutoButtonColor = false
    B.Active = true
    B.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = B
    B.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        B.Text = "  " .. text .. "  |  " .. (Config[key] and "ON" or "OFF")
        B.BackgroundColor3 = Config[key] and Color3.fromRGB(45, 85, 55) or Color3.fromRGB(30, 30, 40)
        if cb then pcall(cb, Config[key]) end
    end)
    return B
end

local function makeSlider(parent, text, key, mn, mx, df)
    local F = Instance.new("Frame")
    F.Size = UDim2.new(1, 0, 0, 42)
    F.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    F.BorderSizePixel = 0
    F.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = F

    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(1, -12, 0, 18)
    L.Position = UDim2.new(0, 6, 0, 2)
    L.BackgroundTransparency = 1
    L.Text = text .. ": " .. df
    L.TextColor3 = Color3.fromRGB(215, 215, 220)
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Font = Enum.Font.Gotham
    L.TextSize = 11
    L.Parent = F

    local Bar = Instance.new("Frame")
    Bar.Size = UDim2.new(1, -20, 0, 8)
    Bar.Position = UDim2.new(0, 10, 0, 28)
    Bar.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    Bar.BorderSizePixel = 0
    Bar.Parent = F
    Bar.Active = true
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(1, 0) bc.Parent = Bar

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((df - mn) / (mx - mn), 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(90, 140, 220)
    Fill.BorderSizePixel = 0
    Fill.Parent = Bar
    local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1, 0) fc.Parent = Fill

    local drg = false
    Bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drg = true
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drg = false
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if drg and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
            Fill.Size = UDim2.new(rel, 0, 1, 0)
            local v = math.floor(mn + (mx - mn) * rel)
            L.Text = text .. ": " .. v
            Config[key] = v
        end
    end)
end

local function makeButton(parent, text, cb, col)
    local B = Instance.new("TextButton")
    B.Size = UDim2.new(1, 0, 0, 34)
    B.BackgroundColor3 = col or Color3.fromRGB(60, 100, 165)
    B.TextColor3 = Color3.fromRGB(255, 255, 255)
    B.Text = text
    B.Font = Enum.Font.GothamBold
    B.TextSize = 11
    B.TextWrapped = true
    B.BorderSizePixel = 0
    B.AutoButtonColor = false
    B.Active = true
    B.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = B
    local sc = col or Color3.fromRGB(60, 100, 165)
    B.MouseButton1Down:Connect(function() B.BackgroundColor3 = Color3.fromRGB(90, 140, 200) end)
    B.MouseButton1Up:Connect(function() B.BackgroundColor3 = sc end)
    B.MouseLeave:Connect(function() B.BackgroundColor3 = sc end)
    B.MouseButton1Click:Connect(function()
        local ok, err = pcall(cb)
        if not ok then print("[ERR] " .. tostring(err)) end
    end)
    return B
end

local function makeInput(parent, label, key, ph)
    local F = Instance.new("Frame")
    F.Size = UDim2.new(1, 0, 0, 52)
    F.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    F.BorderSizePixel = 0
    F.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = F

    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(1, -12, 0, 16)
    L.Position = UDim2.new(0, 6, 0, 2)
    L.BackgroundTransparency = 1
    L.Text = label
    L.TextColor3 = Color3.fromRGB(215, 215, 220)
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Font = Enum.Font.Gotham
    L.TextSize = 10
    L.Parent = F

    local B = Instance.new("TextBox")
    B.Size = UDim2.new(1, -12, 0, 26)
    B.Position = UDim2.new(0, 6, 0, 20)
    B.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    B.BorderSizePixel = 0
    B.PlaceholderText = ph or ""
    B.PlaceholderColor3 = Color3.fromRGB(110, 110, 125)
    B.TextColor3 = Color3.fromRGB(220, 220, 220)
    B.Font = Enum.Font.Gotham
    B.TextSize = 11
    B.ClearTextOnFocus = false
    B.Parent = F
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 4) bc.Parent = B
    B.FocusLost:Connect(function() Config[key] = B.Text end)
    return B
end

-- Pages
makePage("combat")
makePage("move")
makePage("bio")
makePage("tools")

-- COMBAT
local combat = Pages["combat"]
makeHeader(combat, "AIMBOT")
makeToggle(combat, "Auto Aimbot", "Aimbot")
makeToggle(combat, "Target Lock", "AimbotLock")
makeToggle(combat, "Team Check", "TeamCheck")
makeToggle(combat, "Friend Check", "FriendCheck")
makeToggle(combat, "Visible Check", "AimbotVisibleCheck")
makeToggle(combat, "Humanize", "AimbotHumanize")
makeSlider(combat, "FOV", "AimbotFOV", 30, 400, 140)
makeSlider(combat, "Smooth", "AimbotSmooth", 2, 30, 8)
makeSlider(combat, "Max Dist", "AimbotMaxDist", 50, 1500, 600)
makeHeader(combat, "ESP")
makeToggle(combat, "ESP", "ESP")
makeToggle(combat, "Tracers", "Tracers")

-- MOVE
local move = Pages["move"]
makeHeader(move, "FLY")
makeToggle(move, "Fly", "Fly")
makeSlider(move, "Fly Speed", "FlySpeed", 20, 150, 55)
makeHeader(move, "SPEED & JUMP")
makeToggle(move, "Speed", "SpeedOn")
makeSlider(move, "Speed Value", "SpeedValue", 16, 100, 40)
makeToggle(move, "High Jump", "JumpOn")
makeSlider(move, "Jump Power", "JumpValue", 50, 200, 90)
makeToggle(move, "Inf Jump", "InfJump")

-- BIO
local bio = Pages["bio"]
makeHeader(bio, "BIO TEXT")
makeInput(bio, "Your Bio", "BioText", "Type bio here")
makeButton(bio, "Apply Bio (auto - all remotes)", function()
    if Config.BioText == "" then print("[BIO] Enter text first") return end
    Bio.attemptAll(Config.BioText, 0.15)
end, Color3.fromRGB(50, 130, 100))
makeButton(bio, "Fast Apply (first remote only)", function()
    if Config.BioText == "" then print("[BIO] Enter text first") return end
    if #Bio.KnownRemotes == 0 then Bio.scan() end
    local payloads = generateBioPayloads(Config.BioText)
    local r = Bio.KnownRemotes[1]
    if not r then print("[BIO] No remotes") return end
    for _, payload in ipairs(payloads) do
        if r.obj.Parent then
            pcall(function()
                if r.obj:IsA("RemoteEvent") then
                    r.obj:FireServer(table.unpack(payload))
                else
                    r.obj:InvokeServer(table.unpack(payload))
                end
            end)
        end
        task.wait(0.2)
    end
    print("[BIO] Fast attempt done")
end, Color3.fromRGB(60, 100, 140))
makeHeader(bio, "DIAGNOSTICS")
makeButton(bio, "Scan Bio Remotes", function()
    Bio.scan()
end, Color3.fromRGB(80, 80, 120))
makeButton(bio, "Print Known Remotes", function()
    print("=== KNOWN BIO REMOTES (" .. #Bio.KnownRemotes .. ") ===")
    for i, r in ipairs(Bio.KnownRemotes) do
        print(i .. ". [" .. r.keyword .. "] " .. r.path)
    end
end, Color3.fromRGB(80, 80, 120))

-- TOOLS
local tools = Pages["tools"]
makeHeader(tools, "TOOLS")
makeButton(tools, "Reset Character", function()
    local c = LocalPlayer.Character
    if c then c:BreakJoints() end
end, Color3.fromRGB(90, 90, 90))
makeButton(tools, "Random Body Color", function()
    local c = LocalPlayer.Character
    if not c then return end
    for _, v in ipairs(c:GetChildren()) do
        if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
            v.BrickColor = BrickColor.random()
        end
    end
end, Color3.fromRGB(140, 100, 55))
makeButton(tools, "Game Info", function()
    print("PlaceId:", game.PlaceId)
    print("Players:", #Players:GetPlayers())
    print("Drawing:", tostring(Drawing ~= nil))
    print("hookmetamethod:", tostring(hookmetamethod ~= nil))
end, Color3.fromRGB(70, 110, 170))

-- Tabs
makeTab("Combat", "combat")
makeTab("Move", "move")
makeTab("Bio", "bio")
makeTab("Tools", "tools")

showPage("bio")

-- ============================================================
-- MENU
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
    local o = Camera.CFrame.Position
    local d = (part.Position - o)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, part.Parent}
    local r = Workspace:Raycast(o, d, params)
    return r == nil or (r.Position - o).Magnitude >= d.Magnitude - 1
end

local function createESP(p)
    if espObjects[p] or not Drawing then return end
    local b = Drawing.new("Square") b.Visible = false b.Thickness = 1 b.Filled = false
    local n = Drawing.new("Text") n.Visible = false n.Size = 13 n.Center = true n.Outline = true n.Color = Color3.fromRGB(255,255,255)
    local d = Drawing.new("Text") d.Visible = false d.Size = 11 d.Center = true d.Outline = true d.Color = Color3.fromRGB(255,220,100)
    local tr = Drawing.new("Line") tr.Visible = false tr.Thickness = 1 tr.Color = Color3.fromRGB(255,80,80)
    espObjects[p] = {box=b, name=n, dist=d, tracer=tr}
end
local function removeESP(p)
    local o = espObjects[p]
    if o then for _, v in pairs(o) do pcall(function() v:Remove() end) end espObjects[p] = nil end
end

RunService.RenderStepped:Connect(function(dt)
    -- Aimbot
    if Config.Aimbot then
        local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        local target, bestDist = nil, Config.AimbotFOV

        if Config.AimbotLock and LockedTarget then
            local p = LockedTarget
            if p.Parent and isAlive(p) and not isExcluded(p) then
                local part = p.Character and p.Character:FindFirstChild(Config.AimbotPart)
                if part and isVisible(part) then
                    local sp, on = Camera:WorldToViewportPoint(part.Position)
                    if on and sp.Z > 0 then
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
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
                            local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                            local wd = (Camera.CFrame.Position - part.Position).Magnitude
                            if d < bestDist and wd <= Config.AimbotMaxDist then
                                bestDist = d target = part LockedTarget = p
                            end
                        end
                    end
                end
            end
        end

        if target then
            local cur = Camera.CFrame
            local tgt = CFrame.new(cur.Position, target.Position)
            local maxA = math.rad(2.2)
            local dot = math.clamp(cur.LookVector:Dot(tgt.LookVector), -1, 1)
            local ang = math.acos(dot)
            if ang > maxA then
                local t = maxA / ang
                local nl = cur.LookVector:Lerp(tgt.LookVector, t).Unit
                tgt = CFrame.new(cur.Position, cur.Position + nl)
            end
            if Config.AimbotHumanize then
                local j = Vector3.new(
                    (math.random()-0.5)*0.15,
                    (math.random()-0.5)*0.15,
                    (math.random()-0.5)*0.15
                )
                tgt = tgt * CFrame.new(j)
            end
            Camera.CFrame = cur:Lerp(tgt, Config.AimbotSmooth/100)
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
                    FlyBV = Instance.new("BodyVelocity")
                    FlyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                    FlyBV.Parent = hrp
                    FlyFG = Instance.new("BodyGyro")
                    FlyFG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
                    FlyFG.P = 3000
                    FlyFG.D = 500
                    FlyFG.Parent = hrp
                end
                local md = h.MoveDirection
                local cl = Camera.CFrame.LookVector
                local fl = Vector3.new(cl.X, 0, cl.Z)
                if fl.Magnitude > 0.01 then fl = fl.Unit end
                local rt = fl:Cross(Vector3.new(0, 1, 0))
                FlyBV.Velocity = fl * md.Z * Config.FlySpeed + rt * md.X * Config.FlySpeed
                FlyFG.CFrame = Camera.CFrame
            end
        end
    else
        if FlyBV then FlyBV:Destroy() FlyBV = nil end
        if FlyFG then FlyFG:Destroy() FlyFG = nil end
    end

    -- Speed / Jump
    local c = LocalPlayer.Character
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then
            if Config.SpeedOn then h.WalkSpeed = Config.SpeedValue
            elseif h.WalkSpeed > 16 then h.WalkSpeed = 16 end
            if Config.JumpOn then
                h.UseJumpPower = true
                h.JumpPower = Config.JumpValue
            end
        end
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
                        o.box.Visible = false
                        o.name.Visible = false
                        o.dist.Visible = false
                        o.tracer.Visible = false
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
    FlyBV, FlyFG = nil, nil
end)

Players.PlayerRemoving:Connect(removeESP)

-- Auto-init
task.spawn(function()
    task.wait(1)
    Bio.installHook()
    print("[BIO] Learning hook active")
    task.wait(0.5)
    Bio.scan()
end)

print("[OBSIDIAN] loaded. Click V icon.")
