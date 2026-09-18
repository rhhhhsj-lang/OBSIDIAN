local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local InsertService = game:GetService("InsertService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Config = {
    Aimbot = false, AimbotSmooth = 8, AimbotFOV = 140,
    AimbotMaxDist = 600, AimbotLock = false, AimbotHumanize = true,
    ESP = false, Tracers = true, TeamCheck = true, FriendCheck = true,
    Fly = false, FlySpeed = 55,
    SpeedOn = false, SpeedValue = 40,
    JumpOn = false, JumpValue = 90, InfJump = false,
    BioText = "",
    AutoLearn = true,
}

local LockedTarget = nil
local FlyBV, FlyFG
local LogMessages = {}
local TEST_TEXT = "OBSIDIAN_TEST_" .. math.random(10000, 99999)

local function log(msg, color)
    table.insert(LogMessages, {msg = tostring(msg), color = color or Color3.fromRGB(200, 200, 210)})
    if #LogMessages > 100 then table.remove(LogMessages, 1) end
    print("[OBSIDIAN] " .. tostring(msg))
end

local refreshConsole = function() end

-- ============================================================
-- BIO ENGINE
-- ============================================================
local bioKeywords = {
    "bio", "status", "about", "description", "profile",
    "aboutme", "setbio", "setstatus", "setdesc", "setprofile",
    "updatebio", "updatestatus", "abouttext", "signature",
    "setabout", "setmessage", "tagline", "subtitle", "customstatus",
    "changestatus", "changebio", "customtext", "playertag",
    "setnote", "roleplaydesc", "rpdesc",
}

local function matchesBio(name)
    local n = name:lower()
    for _, k in ipairs(bioKeywords) do
        if n:find(k) then return k end
    end
    return nil
end

local Bio = {
    Remotes = {},
    Hooked = false,
    WinningRemote = nil,
    WinningPayload = nil,
    Learned = false,
}

function Bio.scan()
    Bio.Remotes = {}
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local k = matchesBio(obj.Name)
            if k then
                table.insert(Bio.Remotes, {obj = obj, name = obj.Name, path = obj:GetFullName(), keyword = k})
            end
        end
    end
    log("Bio scan: " .. #Bio.Remotes .. " remotes", Color3.fromRGB(100, 200, 255))
    return #Bio.Remotes
end

function Bio.installHook()
    if Bio.Hooked then return true end
    if not getrawmetatable or not setreadonly or not newcclosure or not getnamecallmethod then
        log("Hook not supported", Color3.fromRGB(255, 100, 100))
        return false
    end
    local mt = getrawmetatable(game)
    if not mt then return false end
    local oldNC = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" or method == "InvokeServer" then
            if typeof(self) == "Instance" and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
                local k = matchesBio(self.Name)
                if k then
                    local args = {...}
                    -- Detect if user manually changed bio (matches no test text)
                    local hasText = false
                    for _, a in ipairs(args) do
                        if type(a) == "string" and #a > 2 and not a:find("OBSIDIAN_TEST") then
                            hasText = true
                            break
                        end
                    end
                    if hasText and not checkcaller() then
                        -- This is a user-triggered change - LEARN IT
                        Bio.WinningRemote = self
                        Bio.WinningPayload = args
                        Bio.Learned = true
                        log("LEARNED from your manual change: " .. self.Name, Color3.fromRGB(100, 255, 150))
                        log("Payload structure saved", Color3.fromRGB(100, 255, 150))
                    end
                    -- Ensure it's in the list
                    local exists = false
                    for _, r in ipairs(Bio.Remotes) do
                        if r.obj == self then exists = true break end
                    end
                    if not exists then
                        table.insert(Bio.Remotes, {obj = self, name = self.Name, path = self:GetFullName(), keyword = k})
                    end
                end
            end
        end
        return oldNC(self, ...)
    end)
    setreadonly(mt, true)
    Bio.Hooked = true
    log("Bio learning hook installed", Color3.fromRGB(100, 255, 150))
    return true
end

-- Detect bio display in LocalPlayer (looking for our test text)
local function findBioDisplay(textToFind)
    local c = LocalPlayer.Character
    if c then
        for _, obj in ipairs(c:GetDescendants()) do
            if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
                for _, lbl in ipairs(obj:GetDescendants()) do
                    if lbl:IsA("TextLabel") and lbl.Text:find(textToFind, 1, true) then
                        return obj
                    end
                end
            end
        end
    end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, obj in ipairs(pg:GetDescendants()) do
            if obj:IsA("TextLabel") and obj.Text:find(textToFind, 1, true) then
                return obj
            end
        end
    end
    return nil
end

-- Probe: try all payloads on one remote with test text
local function probeRemote(remote, testText)
    local lp = LocalPlayer
    local payloads = {
        {testText}, {lp, testText}, {testText, lp},
        {lp.UserId, testText}, {testText, lp.UserId},
        {lp.Name, testText}, {testText, lp.Name},
        {"SetBio", testText}, {"SetStatus", testText},
        {"SetAbout", testText}, {"UpdateBio", testText},
        {"Bio", testText}, {"bio", testText}, {"Set", testText},
        {lp.Character, testText}, {testText, lp.Character},
        {testText, true}, {testText, 1},
    }
    for _, payload in ipairs(payloads) do
        pcall(function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer(table.unpack(payload))
            else
                remote:InvokeServer(table.unpack(payload))
            end
        end)
        task.wait(0.08)
    end
end

-- Auto-learn: write test text, look for changes
function Bio.autoLearn()
    log("=== AUTO-LEARN MODE ===", Color3.fromRGB(255, 200, 100))
    log("Writing test text: " .. TEST_TEXT, Color3.fromRGB(255, 200, 100))

    if #Bio.Remotes == 0 then Bio.scan() end
    if #Bio.Remotes == 0 then
        log("No bio remotes found", Color3.fromRGB(255, 100, 100))
        return false
    end

    local foundWinners = {}
    for _, r in ipairs(Bio.Remotes) do
        if r.obj.Parent then
            probeRemote(r.obj, TEST_TEXT)
            task.wait(0.2)
            -- Check if the display changed
            if findBioDisplay(TEST_TEXT) then
                table.insert(foundWinners, r)
                log("HIT! Remote responded: " .. r.path, Color3.fromRGB(100, 255, 150))
            end
        end
    end

    if #foundWinners > 0 then
        Bio.WinningRemote = foundWinners[1].obj
        Bio.Learned = true
        log("Winner: " .. foundWinners[1].path, Color3.fromRGB(100, 255, 150))
        return true
    end

    log("No visible response. Change your bio manually once to teach.", Color3.fromRGB(255, 200, 100))
    return false
end

-- Apply custom text on learned remote
function Bio.apply(text)
    if text == "" then
        log("Enter bio text first", Color3.fromRGB(255, 200, 100))
        return
    end

    if not Bio.Learned or not Bio.WinningRemote or not Bio.WinningRemote.Parent then
        log("Not learned yet. Run Auto-Learn or change bio manually once.", Color3.fromRGB(255, 200, 100))
        return
    end

    local r = Bio.WinningRemote
    local lp = LocalPlayer
    local payloads = {
        {text}, {lp, text}, {text, lp},
        {lp.UserId, text}, {text, lp.UserId},
        {lp.Name, text}, {text, lp.Name},
        {"SetBio", text}, {"SetStatus", text},
        {"SetAbout", text}, {"UpdateBio", text},
        {"Bio", text}, {"bio", text}, {"Set", text},
        {lp.Character, text}, {text, lp.Character},
        {text, true}, {text, 1},
    }

    for _, payload in ipairs(payloads) do
        pcall(function()
            if r:IsA("RemoteEvent") then
                r:FireServer(table.unpack(payload))
            else
                r:InvokeServer(table.unpack(payload))
            end
        end)
        task.wait(0.1)
    end
    log("Bio applied: " .. text, Color3.fromRGB(100, 255, 150))
end

-- ============================================================
-- SKINS
-- ============================================================
local function clearAccessories()
    local c = LocalPlayer.Character
    if not c then return end
    for _, v in ipairs(c:GetChildren()) do
        if v:IsA("Accessory") or v:IsA("Hat") then v:Destroy() end
    end
end

local function wearAccessory(assetId)
    local c = LocalPlayer.Character
    if not c then return false end
    local ok, model = pcall(function() return InsertService:LoadAsset(assetId) end)
    if not ok or not model then
        log("Failed to load: " .. tostring(assetId), Color3.fromRGB(255, 100, 100))
        return false
    end
    local worn = false
    for _, v in ipairs(model:GetChildren()) do
        if v:IsA("Accessory") or v:IsA("Hat") then
            local clone = v:Clone()
            clone.Parent = c
            worn = true
        end
    end
    model:Destroy()
    return worn
end

local function applySkin(ids)
    clearAccessories()
    local count = 0
    for _, id in ipairs(ids) do
        if wearAccessory(id) then count = count + 1 end
    end
    log("Skin applied: " .. count .. "/" .. #ids, Color3.fromRGB(100, 255, 150))
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
local FW = math.clamp(vp.X * 0.95, 340, 450)
local FH = math.clamp(vp.Y * 0.85, 500, 620)

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
local MStr = Instance.new("UIStroke") MStr.Color = Color3.fromRGB(90, 140, 220) MStr.Thickness = 1.5 MStr.Transparency = 0.4 MStr.Parent = Main

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
Header.BorderSizePixel = 0 Header.Parent = Main
local HC = Instance.new("UICorner") HC.CornerRadius = UDim.new(0, 12) HC.Parent = Header

local HText = Instance.new("TextLabel")
HText.Size = UDim2.new(1, -80, 1, 0) HText.Position = UDim2.new(0, 12, 0, 0)
HText.BackgroundTransparency = 1 HText.Text = "OBSIDIAN  HUB"
HText.TextColor3 = Color3.fromRGB(255, 255, 255)
HText.TextXAlignment = Enum.TextXAlignment.Left
HText.Font = Enum.Font.GothamBold HText.TextSize = 13 HText.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28) CloseBtn.Position = UDim2.new(1, -34, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(210, 55, 55) CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255) CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13 CloseBtn.BorderSizePixel = 0 CloseBtn.Parent = Header
local CBC = Instance.new("UICorner") CBC.CornerRadius = UDim.new(0, 7) CBC.Parent = CloseBtn

local TabBar = Instance.new("ScrollingFrame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, -16, 0, 44)
TabBar.Position = UDim2.new(0, 8, 0, 46)
TabBar.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 3
TabBar.ScrollBarImageColor3 = Color3.fromRGB(90, 140, 220)
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
TabPad.PaddingLeft = UDim.new(0, 6)
TabPad.PaddingRight = UDim.new(0, 6)
TabPad.Parent = TabBar

local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -16, 1, -100)
ContentArea.Position = UDim2.new(0, 8, 0, 96)
ContentArea.BackgroundTransparency = 1 ContentArea.Parent = Main

local Pages = {}
local function makePage(name)
    local p = Instance.new("ScrollingFrame")
    p.Name = name p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1 p.BorderSizePixel = 0
    p.ScrollBarThickness = 3
    p.ScrollBarImageColor3 = Color3.fromRGB(90, 140, 220)
    p.CanvasSize = UDim2.new(0, 0, 0, 0)
    p.AutomaticCanvasSize = Enum.AutomaticSize.Y
    p.Visible = false p.Parent = ContentArea
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
    B.Size = UDim2.new(0, 70, 0, 34)
    B.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
    B.Text = label B.TextColor3 = Color3.fromRGB(200, 200, 210)
    B.Font = Enum.Font.GothamBold B.TextSize = 11 B.TextWrapped = false
    B.BorderSizePixel = 0 B.AutoButtonColor = false B.Active = true
    B.Parent = TabBar
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = B
    B.MouseButton1Click:Connect(function() showPage(pageName) end)
    TabButtons[pageName] = B
    return B
end

local function makeHeader(parent, text)
    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(1, 0, 0, 22)
    L.BackgroundColor3 = Color3.fromRGB(36, 36, 50)
    L.BorderSizePixel = 0 L.Text = "  " .. text
    L.TextColor3 = Color3.fromRGB(90, 160, 240)
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Font = Enum.Font.GothamBold L.TextSize = 11 L.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 4) c.Parent = L
end

local function makeToggle(parent, text, key, cb)
    local B = Instance.new("TextButton")
    B.Size = UDim2.new(1, 0, 0, 34)
    B.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    B.TextColor3 = Color3.fromRGB(215, 215, 220)
    B.Text = "  " .. text .. "  |  OFF"
    B.TextXAlignment = Enum.TextXAlignment.Left
    B.Font = Enum.Font.Gotham B.TextSize = 11
    B.BorderSizePixel = 0 B.AutoButtonColor = false B.Active = true
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
    F.Size = UDim2.new(1, 0, 0, 44)
    F.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    F.BorderSizePixel = 0 F.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = F
    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(1, -12, 0, 18) L.Position = UDim2.new(0, 6, 0, 2)
    L.BackgroundTransparency = 1 L.Text = text .. ": " .. df
    L.TextColor3 = Color3.fromRGB(215, 215, 220)
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Font = Enum.Font.Gotham L.TextSize = 11 L.Parent = F
    local Bar = Instance.new("Frame")
    Bar.Size = UDim2.new(1, -20, 0, 10) Bar.Position = UDim2.new(0, 10, 0, 28)
    Bar.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    Bar.BorderSizePixel = 0 Bar.Parent = F Bar.Active = true
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(1, 0) bc.Parent = Bar
    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((df - mn) / (mx - mn), 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(90, 140, 220)
    Fill.BorderSizePixel = 0 Fill.Parent = Bar
    local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1, 0) fc.Parent = Fill
    local drg = false
    Bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then drg = true end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then drg = false end
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
    B.Size = UDim2.new(1, 0, 0, 38)
    B.BackgroundColor3 = col or Color3.fromRGB(60, 100, 165)
    B.TextColor3 = Color3.fromRGB(255, 255, 255)
    B.Text = text
    B.Font = Enum.Font.GothamBold B.TextSize = 11 B.TextWrapped = true
    B.BorderSizePixel = 0 B.AutoButtonColor = false B.Active = true
    B.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = B
    local sc = col or Color3.fromRGB(60, 100, 165)
    B.MouseButton1Down:Connect(function() B.BackgroundColor3 = Color3.fromRGB(90, 140, 200) end)
    B.MouseButton1Up:Connect(function() B.BackgroundColor3 = sc end)
    B.MouseLeave:Connect(function() B.BackgroundColor3 = sc end)
    B.MouseButton1Click:Connect(function()
        local ok, err = pcall(cb)
        if not ok then log("Error: " .. tostring(err), Color3.fromRGB(255, 100, 100)) end
    end)
    return B
end

local function makeInput(parent, label, key, ph)
    local F = Instance.new("Frame")
    F.Size = UDim2.new(1, 0, 0, 56)
    F.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    F.BorderSizePixel = 0 F.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = F
    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(1, -12, 0, 16) L.Position = UDim2.new(0, 6, 0, 2)
    L.BackgroundTransparency = 1 L.Text = label
    L.TextColor3 = Color3.fromRGB(215, 215, 220)
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Font = Enum.Font.Gotham L.TextSize = 10 L.Parent = F
    local B = Instance.new("TextBox")
    B.Size = UDim2.new(1, -12, 0, 30) B.Position = UDim2.new(0, 6, 0, 20)
    B.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    B.BorderSizePixel = 0 B.PlaceholderText = ph or ""
    B.PlaceholderColor3 = Color3.fromRGB(110, 110, 125)
    B.TextColor3 = Color3.fromRGB(220, 220, 220)
    B.Font = Enum.Font.Gotham B.TextSize = 12 B.ClearTextOnFocus = false
    B.Parent = F
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 4) bc.Parent = B
    B.FocusLost:Connect(function() Config[key] = B.Text end)
    return B
end

-- Pages
makePage("bio")
makePage("skins")
makePage("move")
makePage("combat")
makePage("console")
makePage("tools")

-- BIO
local bio = Pages["bio"]
makeHeader(bio, "STATUS")
local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, 0, 0, 24)
statusLbl.BackgroundColor3 = Color3.fromRGB(40, 30, 30)
statusLbl.BorderSizePixel = 0
statusLbl.Text = "  Learning: NOT STARTED"
statusLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Font = Enum.Font.GothamBold
statusLbl.TextSize = 11
statusLbl.Parent = bio
local SLC = Instance.new("UICorner") SLC.CornerRadius = UDim.new(0, 4) SLC.Parent = statusLbl

local function updateStatus()
    if Bio.Learned then
        statusLbl.Text = "  ✓ LEARNED: " .. Bio.WinningRemote.Name
        statusLbl.TextColor3 = Color3.fromRGB(100, 255, 150)
        statusLbl.BackgroundColor3 = Color3.fromRGB(30, 50, 35)
    else
        statusLbl.Text = "  Learning: NOT STARTED"
        statusLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
        statusLbl.BackgroundColor3 = Color3.fromRGB(40, 30, 30)
    end
end

makeHeader(bio, "AUTO-LEARN (test first)")
makeButton(bio, "1. WRITE TEST TEXT + LEARN", function()
    if Bio.autoLearn() then
        updateStatus()
    end
    refreshConsole()
end, Color3.fromRGB(50, 130, 100))

makeHeader(bio, "APPLY CUSTOM")
makeInput(bio, "Your Bio Text", "BioText", "Type your bio")
makeButton(bio, "2. APPLY MY TEXT", function()
    Bio.apply(Config.BioText)
    refreshConsole()
end, Color3.fromRGB(60, 120, 180))

makeHeader(bio, "MANUAL LEARN (fallback)")
makeButton(bio, "Install Hook (for manual teach)", function()
    Bio.installHook()
    refreshConsole()
end, Color3.fromRGB(80, 80, 120))
makeButton(bio, "Scan Bio Remotes", function()
    Bio.scan()
    refreshConsole()
end, Color3.fromRGB(80, 80, 120))
makeButton(bio, "Print All Remotes", function()
    log("=== BIO REMOTES (" .. #Bio.Remotes .. ") ===")
    for i, r in ipairs(Bio.Remotes) do
        log(i .. ". [" .. r.keyword .. "] " .. r.path)
    end
    refreshConsole()
end, Color3.fromRGB(80, 80, 120))

-- SKINS
local skins = Pages["skins"]
makeHeader(skins, "SKINS")
makeButton(skins, "Bucket of Doom", function()
    applySkin({135609592452959})
    refreshConsole()
end, Color3.fromRGB(70, 90, 130))
makeButton(skins, "Red Overseer Hood", function()
    applySkin({101531172994670})
    refreshConsole()
end, Color3.fromRGB(70, 90, 130))
makeButton(skins, "Wear Both", function()
    applySkin({135609592452959, 101531172994670})
    refreshConsole()
end, Color3.fromRGB(70, 110, 90))
makeButton(skins, "Remove All Accessories", function()
    clearAccessories()
    log("Accessories removed")
    refreshConsole()
end, Color3.fromRGB(140, 60, 60))
makeHeader(skins, "TOOLS")
makeButton(skins, "Random Body Color", function()
    local c = LocalPlayer.Character
    if not c then return end
    for _, v in ipairs(c:GetChildren()) do
        if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
            v.BrickColor = BrickColor.random()
        end
    end
end, Color3.fromRGB(120, 100, 60))

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

-- COMBAT
local combat = Pages["combat"]
makeHeader(combat, "AIMBOT")
makeToggle(combat, "Auto Aimbot", "Aimbot")
makeToggle(combat, "Target Lock", "AimbotLock")
makeToggle(combat, "Team Check", "TeamCheck")
makeToggle(combat, "Friend Check", "FriendCheck")
makeToggle(combat, "Humanize", "AimbotHumanize")
makeSlider(combat, "FOV", "AimbotFOV", 30, 400, 140)
makeSlider(combat, "Smooth", "AimbotSmooth", 2, 30, 8)
makeHeader(combat, "ESP")
makeToggle(combat, "ESP", "ESP")
makeToggle(combat, "Tracers", "Tracers")

-- CONSOLE
local consolePage = Pages["console"]
makeHeader(consolePage, "CONSOLE")
local consoleFrame = Instance.new("Frame")
consoleFrame.Size = UDim2.new(1, 0, 0, 400)
consoleFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
consoleFrame.BorderSizePixel = 0
consoleFrame.Parent = consolePage
local CFC = Instance.new("UICorner") CFC.CornerRadius = UDim.new(0, 6) CFC.Parent = consoleFrame
local consoleLayout = Instance.new("UIListLayout")
consoleLayout.Padding = UDim.new(0, 2)
consoleLayout.SortOrder = Enum.SortOrder.LayoutOrder
consoleLayout.Parent = consoleFrame
local consolePad = Instance.new("UIPadding")
consolePad.PaddingTop = UDim.new(0, 6)
consolePad.PaddingLeft = UDim.new(0, 8)
consolePad.PaddingRight = UDim.new(0, 8)
consolePad.Parent = consoleFrame

refreshConsole = function()
    for _, c in ipairs(consoleFrame:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    if #LogMessages == 0 then
        local e = Instance.new("TextLabel")
        e.Size = UDim2.new(1, 0, 0, 20)
        e.BackgroundTransparency = 1
        e.Text = "No messages yet"
        e.TextColor3 = Color3.fromRGB(100, 100, 120)
        e.Font = Enum.Font.Code
        e.TextSize = 10
        e.TextXAlignment = Enum.TextXAlignment.Left
        e.Parent = consoleFrame
        return
    end
    local startIdx = math.max(1, #LogMessages - 30)
    for i = startIdx, #LogMessages do
        local entry = LogMessages[i]
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 16)
        lbl.BackgroundTransparency = 1
        lbl.Text = entry.msg
        lbl.TextColor3 = entry.color
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Parent = consoleFrame
    end
end

makeButton(consolePage, "Refresh Console", function() refreshConsole() end, Color3.fromRGB(70, 110, 170))
makeButton(consolePage, "Clear Console", function()
    LogMessages = {}
    refreshConsole()
end, Color3.fromRGB(120, 70, 70))

-- TOOLS
local tools = Pages["tools"]
makeHeader(tools, "TOOLS")
makeButton(tools, "Reset Character", function()
    local c = LocalPlayer.Character
    if c then c:BreakJoints() end
end, Color3.fromRGB(90, 90, 90))
makeButton(tools, "Game Info", function()
    log("PlaceId: " .. game.PlaceId)
    log("Players: " .. #Players:GetPlayers())
    log("Drawing: " .. tostring(Drawing ~= nil))
    log("Hook: " .. tostring(hookmetamethod ~= nil))
    refreshConsole()
end, Color3.fromRGB(70, 110, 170))
makeButton(tools, "Check Bio Display (look for test text)", function()
    local found = findBioDisplay(TEST_TEXT)
    if found then
        log("Bio display found: " .. found:GetFullName(), Color3.fromRGB(100, 255, 150))
    else
        log("No bio display detected with test text")
    end
    refreshConsole()
end, Color3.fromRGB(70, 110, 170))

-- Tabs
makeTab("Bio", "bio")
makeTab("Skins", "skins")
makeTab("Move", "move")
makeTab("Combat", "combat")
makeTab("Console", "console")
makeTab("Tools", "tools")

showPage("bio")

-- Menu control
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

-- Logic
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
    if Config.Aimbot then
        local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        local target, bestDist = nil, Config.AimbotFOV
        if Config.AimbotLock and LockedTarget then
            local p = LockedTarget
            if p.Parent and isAlive(p) and not isExcluded(p) then
                local part = p.Character and p.Character:FindFirstChild("Head")
                if part then
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
                    local part = p.Character and p.Character:FindFirstChild("Head")
                    if part then
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
                local j = Vector3.new((math.random()-0.5)*0.15, (math.random()-0.5)*0.15, (math.random()-0.5)*0.15)
                tgt = tgt * CFrame.new(j)
            end
            Camera.CFrame = cur:Lerp(tgt, Config.AimbotSmooth/100)
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
                    FlyFG = Instance.new("BodyGyro") FlyFG.MaxTorque = Vector3.new(1e5,1e5,1e5) FlyFG.P = 3000 FlyFG.D = 500 FlyFG.Parent = hrp
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

    local c = LocalPlayer.Character
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then
            if Config.SpeedOn then h.WalkSpeed = Config.SpeedValue
            elseif h.WalkSpeed > 16 then h.WalkSpeed = 16 end
            if Config.JumpOn then h.UseJumpPower = true h.JumpPower = Config.JumpValue end
        end
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
    FlyBV, FlyFG = nil, nil
end)

Players.PlayerRemoving:Connect(removeESP)

-- Auto-init
task.spawn(function()
    task.wait(1)
    Bio.installHook()
    task.wait(0.5)
    Bio.scan()
    updateStatus()
    refreshConsole()
    -- Auto-learn on load
    task.wait(1)
    log("Starting auto-learn...", Color3.fromRGB(255, 200, 100))
    if Bio.autoLearn() then
        updateStatus()
    end
    refreshConsole()
end)

log("OBSIDIAN v7 loaded", Color3.fromRGB(150, 200, 255))
