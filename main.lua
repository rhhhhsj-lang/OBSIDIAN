local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
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
}

local LockedTarget = nil
local FlyBV, FlyFG
local LogMessages = {}

local function log(msg, color)
    table.insert(LogMessages, {msg = tostring(msg), color = color or Color3.fromRGB(200, 200, 210)})
    if #LogMessages > 100 then table.remove(LogMessages, 1) end
    print("[OBSIDIAN] " .. tostring(msg))
end

local refreshConsole = function() end

-- ============================================================
-- BIO ENGINE (manual learn only - reliable)
-- ============================================================
local Bio = {
    LearnedRemote = nil,
    LearnedArgs = nil,
    LastStringIndex = nil,
    Hooked = false,
}

local function installBioHook()
    if Bio.Hooked then return true end
    if not getrawmetatable or not setreadonly or not newcclosure or not getnamecallmethod then
        log("Executor cannot hook", Color3.fromRGB(255, 100, 100))
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
                local n = self.Name:lower()
                -- Look for bio-ish remotes AND find a string argument with real content
                if (n:find("bio") or n:find("status") or n:find("about") or
                    n:find("desc") or n:find("profile") or n:find("message") or
                    n:find("info") or n:find("text") or n:find("tag") or
                    n:find("note") or n:find("sign") or n:find("custom")) then
                    -- Only from user (not from us)
                    if checkcaller and not checkcaller() then
                        local args = {...}
                        local stringIdx = nil
                        local stringVal = nil
                        for i, a in ipairs(args) do
                            if type(a) == "string" and #a > 1 then
                                stringIdx = i
                                stringVal = a
                                break
                            end
                        end
                        if stringIdx then
                            Bio.LearnedRemote = self
                            Bio.LearnedArgs = args
                            Bio.LastStringIndex = stringIdx
                            log("LEARNED: " .. self.Name, Color3.fromRGB(100, 255, 150))
                            log("Text captured: " .. stringVal, Color3.fromRGB(100, 255, 150))
                            log("Payload has " .. #args .. " args (string at #" .. stringIdx .. ")", Color3.fromRGB(100, 255, 150))
                        end
                    end
                end
            end
        end
        return oldNC(self, ...)
    end)
    setreadonly(mt, true)
    Bio.Hooked = true
    log("Bio hook installed. Change your bio manually ONCE.", Color3.fromRGB(100, 255, 150))
    return true
end

function Bio.apply(text)
    if not Bio.LearnedRemote or not Bio.LearnedArgs then
        log("Not learned. Change bio manually in-game first.", Color3.fromRGB(255, 200, 100))
        return false
    end
    if not Bio.LearnedRemote.Parent then
        log("Learned remote was destroyed. Re-learn required.", Color3.fromRGB(255, 100, 100))
        return false
    end

    local newArgs = {}
    for i, a in ipairs(Bio.LearnedArgs) do
        if i == Bio.LastStringIndex then
            newArgs[i] = text
        else
            newArgs[i] = a
        end
    end

    local ok = pcall(function()
        if Bio.LearnedRemote:IsA("RemoteEvent") then
            Bio.LearnedRemote:FireServer(table.unpack(newArgs))
        else
            Bio.LearnedRemote:InvokeServer(table.unpack(newArgs))
        end
    end)
    if ok then
        log("Bio sent: " .. text, Color3.fromRGB(100, 255, 150))
    else
        log("Send failed", Color3.fromRGB(255, 100, 100))
    end
    return ok
end

-- ============================================================
-- SKINS - FIXED with HumanoidDescription:AddAccessory
-- ============================================================
local function clearAccessories()
    local c = LocalPlayer.Character
    if not c then return end
    for _, v in ipairs(c:GetChildren()) do
        if v:IsA("Accessory") or v:IsA("Hat") then v:Destroy() end
    end
end

local function applyAccessoryViaDescription(assetId)
    local c = LocalPlayer.Character
    if not c then return false, "no character" end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return false, "no humanoid" end

    -- Get current description and add accessory
    local ok, desc = pcall(function() return h:GetAppliedDescription() end)
    if not ok or not desc then return false, "no description" end

    -- Add accessory (this fetches the asset server-side)
    local addOk = pcall(function() desc:AddAccessory(assetId) end)
    if not addOk then return false, "addAccessory failed" end

    -- Apply
    local ok1 = pcall(function() h:ApplyDescriptionReset(desc) end)
    if ok1 then return true, "applied reset" end
    local ok2 = pcall(function() h:ApplyDescription(desc) end)
    if ok2 then return true, "applied" end
    return false, "apply failed"
end

local function applySkin(assetIds)
    clearAccessories()
    local results = {}
    for _, id in ipairs(assetIds) do
        local ok, msg = applyAccessoryViaDescription(id)
        if ok then
            table.insert(results, "OK:" .. id)
        else
            table.insert(results, "FAIL:" .. id .. " (" .. tostring(msg) .. ")")
        end
    end
    log("Skin result: " .. table.concat(results, " | "), Color3.fromRGB(100, 255, 150))
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
    B.Font = Enum.Font.GothamBold B.TextSize = 11
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
        refreshConsole()
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
statusLbl.Size = UDim2.new(1, 0, 0, 26)
statusLbl.BackgroundColor3 = Color3.fromRGB(40, 30, 30)
statusLbl.BorderSizePixel = 0
statusLbl.Text = "  Not learned yet"
statusLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Font = Enum.Font.GothamBold
statusLbl.TextSize = 11
statusLbl.Parent = bio
local SLC = Instance.new("UICorner") SLC.CornerRadius = UDim.new(0, 4) SLC.Parent = statusLbl

local function updateStatus()
    if Bio.LearnedRemote then
        statusLbl.Text = "  ✓ Learned: " .. Bio.LearnedRemote.Name
        statusLbl.TextColor3 = Color3.fromRGB(100, 255, 150)
        statusLbl.BackgroundColor3 = Color3.fromRGB(30, 50, 35)
    else
        statusLbl.Text = "  Not learned yet"
        statusLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
        statusLbl.BackgroundColor3 = Color3.fromRGB(40, 30, 30)
    end
end

makeHeader(bio, "STEP 1: TEACH")
makeButton(bio, "Install Hook (required)", function()
    installBioHook()
    updateStatus()
end, Color3.fromRGB(50, 130, 100))

makeHeader(bio, "STEP 2: ENTER TEXT")
makeInput(bio, "Your Bio Text", "BioText", "Type your bio")

makeHeader(bio, "STEP 3: APPLY")
makeButton(bio, "APPLY MY TEXT", function()
    Bio.apply(Config.BioText)
end, Color3.fromRGB(60, 120, 180))

makeButton(bio, "Show Learned Info", function()
    if Bio.LearnedRemote then
        log("Remote: " .. Bio.LearnedRemote:GetFullName())
        log("Args count: " .. #Bio.LearnedArgs)
        log("String index: " .. tostring(Bio.LastStringIndex))
    else
        log("Nothing learned yet")
    end
end, Color3.fromRGB(80, 80, 120))

-- SKINS
local skins = Pages["skins"]
makeHeader(skins, "SKINS (FIXED)")
makeButton(skins, "Bucket of Doom", function()
    applySkin({135609592452959})
end, Color3.fromRGB(70, 90, 130))
makeButton(skins, "Red Overseer Hood", function()
    applySkin({101531172994670})
end, Color3.fromRGB(70, 90, 130))
makeButton(skins, "Wear Both", function()
    applySkin({135609592452959, 101531172994670})
end, Color3.fromRGB(70, 110, 90))
makeButton(skins, "Remove All Accessories", function()
    clearAccessories()
    log("Accessories removed")
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
    task.wait(1.5)
    installBioHook()
    updateStatus()
    refreshConsole()
end)

log("OBSIDIAN v8 loaded", Color3.fromRGB(150, 200, 255))
