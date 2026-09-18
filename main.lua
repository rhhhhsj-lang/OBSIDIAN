-- ============================================================
-- OBSIDIAN INJECTOR v9 | Server-Override Engine
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

print("[OBSIDIAN] v9 loading...")

-- ============================================================
-- CORE STATE
-- ============================================================
local State = {
    AvatarUserId = nil,
    AvatarDesc = nil,
    OverheadText = "",
    OverheadEnabled = false,
    OverheadRGB = true,
    OverheadGui = nil,
}

-- ============================================================
-- CAPABILITY DETECTION
-- ============================================================
local Cap = {}
Cap.hookmetamethod = type(rawget(_G, "hookmetamethod")) == "function"
Cap.getrawmetatable = type(rawget(_G, "getrawmetatable")) == "function"
Cap.setreadonly = type(rawget(_G, "setreadonly")) == "function"
Cap.getconnections = type(rawget(_G, "getconnections")) == "function"
Cap.newcclosure = type(rawget(_G, "newcclosure")) == "function"
Cap.getnamecallmethod = type(rawget(_G, "getnamecallmethod")) == "function"
Cap.checkcaller = type(rawget(_G, "checkcaller")) == "function"
Cap.iscclosure = type(rawget(_G, "iscclosure")) == "function"
Cap.firetouchinterest = type(rawget(_G, "firetouchinterest")) == "function"

print("[OBSIDIAN] Capabilities:")
for k, v in pairs(Cap) do
    if v then print("  [OK] " .. k) end
end

-- ============================================================
-- AVATAR INJECTION ENGINE
-- ============================================================
local Avatar = {}

-- Step 1: fetch description
function Avatar.fetch(userId)
    local ok, desc = pcall(function()
        return Players:GetHumanoidDescriptionFromUserId(userId)
    end)
    if ok and desc then
        State.AvatarDesc = desc
        State.AvatarUserId = userId
        return desc
    end
    return nil
end

-- Step 2: apply description repeatedly
function Avatar.apply()
    if not State.AvatarDesc then return false end
    local c = LocalPlayer.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return false end
    local ok1 = pcall(function()
        h:ApplyDescriptionReset(State.AvatarDesc)
    end)
    if ok1 then return true end
    local ok2 = pcall(function()
        h:ApplyDescription(State.AvatarDesc)
    end)
    return ok2
end

-- Step 3: block server from reverting via namecall hook
local originalApplyDesc = nil
function Avatar.protect()
    if not Cap.hookmetamethod then return false end
    local mt = getrawmetatable(game)
    if not mt then return false end

    local oldNC = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        -- Block any ApplyDescription attempts targeting our humanoid
        -- that come from OUTSIDE our script
        if method == "ApplyDescriptionReset" or method == "ApplyDescription" then
            if Cap.checkcaller and not checkcaller() then
                -- server trying to reset us
                local c = LocalPlayer.Character
                if c and self == c:FindFirstChildOfClass("Humanoid") then
                    if State.AvatarDesc then
                        -- silently re-apply ours later
                        task.spawn(function()
                            task.wait(0.1)
                            Avatar.apply()
                        end)
                        -- still allow the call, we override after
                    end
                end
            end
        end

        -- Block Character property reset
        if method == "LoadCharacter" or method == "LoadCharacterWithHumanoidDescription" then
            if Cap.checkcaller and not checkcaller() then
                if State.AvatarDesc then
                    task.spawn(function()
                        task.wait(0.5)
                        Avatar.apply()
                    end)
                end
            end
        end

        return oldNC(self, ...)
    end)
    setreadonly(mt, true)
    return true
end

-- Step 4: fire avatar-related remotes with payloads
function Avatar.push()
    if not State.AvatarUserId then return 0 end
    local c = LocalPlayer.Character
    if not c then return 0 end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return 0 end

    local fired = 0
    local patterns = {
        "avatar", "appearance", "description", "character",
        "reset", "load", "set", "apply", "outfit", "wear",
        "suit", "humanoid", "setavatar", "setcharacter",
    }

    local payloads = {
        {State.AvatarUserId},
        {State.AvatarDesc},
        {h, State.AvatarDesc},
        {c, State.AvatarDesc},
        {"Apply", State.AvatarDesc},
        {"SetAvatar", State.AvatarUserId},
        {"ChangeAppearance", State.AvatarUserId},
        {"LoadAvatar", State.AvatarUserId},
        {LocalPlayer, State.AvatarUserId},
        {LocalPlayer.UserId, State.AvatarUserId},
    }

    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local n = obj.Name:lower()
            for _, pat in ipairs(patterns) do
                if n:find(pat) then
                    for _, payload in ipairs(payloads) do
                        pcall(function()
                            obj:FireServer(table.unpack(payload))
                        end)
                    end
                    fired = fired + 1
                    break
                end
            end
        end
    end

    return fired
end

-- Step 5: continuous enforcement loop
function Avatar.startLoop()
    if Avatar._loop then return end
    Avatar._loop = task.spawn(function()
        while Avatar._running ~= false do
            if State.AvatarDesc then
                pcall(function() Avatar.apply() end)
                task.wait(0.15)
            else
                task.wait(0.5)
            end
        end
    end)
end

function Avatar.stopLoop()
    Avatar._running = false
    Avatar._loop = nil
end

-- Step 6: full pipeline
function Avatar.copy(username)
    if username == "" then return false, "empty username" end
    local uid
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == username:lower() then
            uid = p.UserId
            break
        end
    end
    if not uid then
        local ok, res = pcall(function()
            return Players:GetUserIdFromNameAsync(username)
        end)
        if ok and res then uid = res end
    end
    if not uid then return false, "user not found" end

    local desc = Avatar.fetch(uid)
    if not desc then return false, "no description" end

    Avatar._running = true
    Avatar.apply()
    Avatar.protect()
    local fired = Avatar.push()
    Avatar.startLoop()

    return true, "uid=" .. uid .. " remotes=" .. fired
end

-- ============================================================
-- NAMETAG INJECTION ENGINE
-- ============================================================
local Nametag = {}

function Nametag.setDisplayName(text)
    local c = LocalPlayer.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return false end
    local ok = pcall(function()
        h.DisplayName = text
    end)
    return ok
end

function Nametag.attachBillboard(text)
    local c = LocalPlayer.Character
    if not c then return false end
    local head = c:FindFirstChild("Head")
    if not head then return false end

    local old = head:FindFirstChild("__OB_TAG")
    if old then old:Destroy() end

    local bb = Instance.new("BillboardGui")
    bb.Name = "__OB_TAG"
    bb.Size = UDim2.new(0, 300, 0, 60)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 5000
    bb.Parent = head

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    lbl.Parent = bb

    State.OverheadGui = bb
    return true
end

function Nametag.attachOverheadName(text)
    local c = LocalPlayer.Character
    if not c then return false end

    -- Some games use a custom overhead name plate
    -- Try to find and override it
    for _, obj in ipairs(c:GetDescendants()) do
        if obj:IsA("BillboardGui") and obj.Name ~= "__OB_TAG" then
            local lbl = obj:FindFirstChildOfClass("TextLabel")
            if lbl and lbl.Name:lower():find("name") then
                pcall(function() lbl.Text = text end)
            end
        end
    end
    return true
end

function Nametag.fireRemotes(text)
    local patterns = {
        "setname", "displayname", "nametag", "rename",
        "updatename", "setdisplayname", "customname",
        "prefix", "suffix", "title", "overhead", "label",
        "settitle", "nameplate", "showname", "changeshow",
    }

    local payloads = {
        {text},
        {"SetName", text},
        {"SetText", text},
        {"UpdateName", text},
        {"SetDisplayName", text},
        {"ChangeName", text},
        {"SetTitle", text},
        {"SetNametag", text},
        {LocalPlayer, text},
        {LocalPlayer.UserId, text},
        {LocalPlayer.Name, text},
        {"All", text},
        {text, "All"},
        {text, 1},
        {1, text},
        {text, Color3.fromRGB(255, 255, 255)},
        {"SetColor", Color3.fromRGB(255, 255, 255), text},
    }

    local fired = 0
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local n = obj.Name:lower()
            for _, pat in ipairs(patterns) do
                if n:find(pat) then
                    for _, payload in ipairs(payloads) do
                        pcall(function()
                            obj:FireServer(table.unpack(payload))
                        end)
                    end
                    fired = fired + 1
                    break
                end
            end
        end
    end
    return fired
end

function Nametag.protectDisplayName()
    if not Cap.hookmetamethod then return false end
    local mt = getrawmetatable(game)
    if not mt then return false end
    local oldNI = mt.__newindex
    if not oldNI then return false end

    setreadonly(mt, false)
    mt.__newindex = newcclosure(function(self, key, value)
        if Cap.checkcaller and not checkcaller() then
            if typeof(self) == "Instance" and self:IsA("Humanoid") then
                local c = LocalPlayer.Character
                if c and self == c:FindFirstChildOfClass("Humanoid") then
                    if key == "DisplayName" and State.OverheadEnabled then
                        -- Block server from overwriting our DisplayName
                        return nil
                    end
                end
            end
        end
        return oldNI(self, key, value)
    end)
    setreadonly(mt, true)
    return true
end

function Nametag.startLoop()
    if Nametag._loop then return end
    Nametag._loop = task.spawn(function()
        while Nametag._running ~= false do
            if State.OverheadEnabled and State.OverheadText ~= "" then
                pcall(function() Nametag.setDisplayName(State.OverheadText) end)
                pcall(function() Nametag.attachBillboard(State.OverheadText) end)
                pcall(function() Nametag.attachOverheadName(State.OverheadText) end)
                pcall(function() Nametag.fireRemotes(State.OverheadText) end)
            end
            task.wait(0.3)
        end
    end)
end

function Nametag.stopLoop()
    Nametag._running = false
    Nametag._loop = nil
    -- Remove billboard
    local c = LocalPlayer.Character
    if c then
        local head = c:FindFirstChild("Head")
        if head then
            local tag = head:FindFirstChild("__OB_TAG")
            if tag then tag:Destroy() end
        end
    end
end

function Nametag.activate(text)
    if text == "" then return false, "empty text" end
    State.OverheadText = text
    State.OverheadEnabled = true
    Nametag._running = true
    Nametag.protectDisplayName()
    local fired = Nametag.fireRemotes(text)
    Nametag.setDisplayName(text)
    Nametag.attachBillboard(text)
    Nametag.startLoop()
    return true, "remotes=" .. fired
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
local FH = math.clamp(vp.Y * 0.78, 460, 580)

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
HText.Text = "OBSIDIAN  v9  INJECTOR"
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

local Container = Instance.new("ScrollingFrame")
Container.Size = UDim2.new(1, -16, 1, -52)
Container.Position = UDim2.new(0, 8, 0, 44)
Container.BackgroundTransparency = 1
Container.BorderSizePixel = 0
Container.ScrollBarThickness = 3
Container.ScrollBarImageColor3 = Color3.fromRGB(90, 140, 220)
Container.CanvasSize = UDim2.new(0, 0, 0, 0)
Container.AutomaticCanvasSize = Enum.AutomaticSize.Y
Container.Parent = Main
local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 6)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Container
local LP = Instance.new("UIPadding")
LP.PaddingRight = UDim.new(0, 6)
LP.Parent = Container

local function makeHeader(text, color)
    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(1, 0, 0, 24)
    L.BackgroundColor3 = color or Color3.fromRGB(36, 36, 50)
    L.BorderSizePixel = 0
    L.Text = "  " .. text
    L.TextColor3 = Color3.fromRGB(90, 160, 240)
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Font = Enum.Font.GothamBold
    L.TextSize = 11
    L.Parent = Container
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 4) c.Parent = L
end

local function makeButton(text, callback, color)
    local B = Instance.new("TextButton")
    B.Size = UDim2.new(1, 0, 0, 34)
    B.BackgroundColor3 = color or Color3.fromRGB(60, 100, 165)
    B.TextColor3 = Color3.fromRGB(255, 255, 255)
    B.Text = text
    B.Font = Enum.Font.GothamBold
    B.TextSize = 12
    B.TextWrapped = true
    B.BorderSizePixel = 0
    B.AutoButtonColor = false
    B.Active = true
    B.Parent = Container
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = B
    B.MouseButton1Down:Connect(function() B.BackgroundColor3 = Color3.fromRGB(80, 130, 200) end)
    B.MouseButton1Up:Connect(function() B.BackgroundColor3 = color or Color3.fromRGB(60, 100, 165) end)
    B.MouseLeave:Connect(function() B.BackgroundColor3 = color or Color3.fromRGB(60, 100, 165) end)
    B.MouseButton1Click:Connect(function()
        local ok, err = pcall(callback)
        if not ok then print("[BTN ERROR] " .. tostring(err)) end
    end)
    return B
end

local function makeInput(label, callback, placeholder)
    local F = Instance.new("Frame")
    F.Size = UDim2.new(1, 0, 0, 50)
    F.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    F.BorderSizePixel = 0
    F.Parent = Container
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = F
    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(1, -12, 0, 18)
    L.Position = UDim2.new(0, 6, 0, 2)
    L.BackgroundTransparency = 1
    L.Text = label
    L.TextColor3 = Color3.fromRGB(215, 215, 220)
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Font = Enum.Font.Gotham
    L.TextSize = 11
    L.Parent = F
    local B = Instance.new("TextBox")
    B.Size = UDim2.new(1, -12, 0, 24)
    B.Position = UDim2.new(0, 6, 0, 20)
    B.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    B.BorderSizePixel = 0
    B.PlaceholderText = placeholder or ""
    B.PlaceholderColor3 = Color3.fromRGB(110, 110, 125)
    B.TextColor3 = Color3.fromRGB(220, 220, 220)
    B.Font = Enum.Font.Gotham
    B.TextSize = 12
    B.ClearTextOnFocus = false
    B.Parent = F
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 4) bc.Parent = B
    B.FocusLost:Connect(function()
        if callback then pcall(callback, B.Text) end
    end)
    return B
end

local function makeToggle(text, callback)
    local state = false
    local B = Instance.new("TextButton")
    B.Size = UDim2.new(1, 0, 0, 34)
    B.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    B.TextColor3 = Color3.fromRGB(215, 215, 220)
    B.Text = "  " .. text .. "  |  OFF"
    B.TextXAlignment = Enum.TextXAlignment.Left
    B.Font = Enum.Font.Gotham
    B.TextSize = 12
    B.BorderSizePixel = 0
    B.AutoButtonColor = false
    B.Active = true
    B.Parent = Container
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = B
    B.MouseButton1Click:Connect(function()
        state = not state
        B.Text = "  " .. text .. "  |  " .. (state and "ON" or "OFF")
        B.BackgroundColor3 = state and Color3.fromRGB(45, 85, 55) or Color3.fromRGB(30, 30, 40)
        if callback then pcall(callback, state) end
    end)
    return B
end

-- ============================================================
-- BUILD UI
-- ============================================================
makeHeader("AVATAR INJECTION", Color3.fromRGB(80, 40, 40))

local avatarUser = ""
makeInput("Username", function(t) avatarUser = t end, "Enter player name")

makeButton("COPY AVATAR (full pipeline)", function()
    if avatarUser == "" then
        print("[OBSIDIAN] Enter username first")
        return
    end
    print("[OBSIDIAN] Copying avatar from: " .. avatarUser)
    local ok, msg = Avatar.copy(avatarUser)
    print("[OBSIDIAN] Avatar result: " .. tostring(ok) .. " | " .. tostring(msg))
end, Color3.fromRGB(60, 150, 85))

makeButton("Push Avatar via Remotes", function()
    local n = Avatar.push()
    print("[OBSIDIAN] Fired " .. n .. " avatar remotes")
end, Color3.fromRGB(100, 80, 60))

makeButton("Stop Avatar Loop", function()
    Avatar.stopLoop()
    print("[OBSIDIAN] Avatar loop stopped")
end, Color3.fromRGB(120, 70, 70))

makeHeader("NAMETAG INJECTION", Color3.fromRGB(80, 40, 40))

local tagText = ""
makeInput("Display Text", function(t) tagText = t end, "Enter text")

makeButton("ACTIVATE NAMETAG (all methods)", function()
    if tagText == "" then
        print("[OBSIDIAN] Enter text first")
        return
    end
    print("[OBSIDIAN] Activating nametag: " .. tagText)
    local ok, msg = Nametag.activate(tagText)
    print("[OBSIDIAN] Nametag result: " .. tostring(ok) .. " | " .. tostring(msg))
end, Color3.fromRGB(60, 150, 85))

makeButton("Fire Nametag Remotes Only", function()
    local n = Nametag.fireRemotes(tagText)
    print("[OBSIDIAN] Fired " .. n .. " nametag remotes")
end, Color3.fromRGB(100, 80, 60))

makeButton("Set DisplayName Only", function()
    Nametag.setDisplayName(tagText)
    print("[OBSIDIAN] DisplayName set to: " .. tagText)
end, Color3.fromRGB(70, 110, 180))

makeButton("Attach Billboard Only", function()
    Nametag.attachBillboard(tagText)
    print("[OBSIDIAN] Billboard attached")
end, Color3.fromRGB(70, 110, 180))

makeButton("Stop Nametag Loop", function()
    Nametag.stopLoop()
    State.OverheadEnabled = false
    print("[OBSIDIAN] Nametag loop stopped")
end, Color3.fromRGB(120, 70, 70))

makeHeader("DIAGNOSTICS", Color3.fromRGB(40, 40, 80))

makeButton("Print Capabilities", function()
    print("=== CAPABILITIES ===")
    for k, v in pairs(Cap) do
        print("  " .. k .. ": " .. tostring(v))
    end
end, Color3.fromRGB(70, 110, 170))

makeButton("Test DisplayName (simple)", function()
    local c = LocalPlayer.Character
    if not c then print("No character"); return end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then print("No humanoid"); return end
    h.DisplayName = "TEST_" .. tick()
    print("[OBSIDIAN] DisplayName set to TEST. Check your head.")
end, Color3.fromRGB(70, 110, 170))

makeButton("Print Character Info", function()
    local c = LocalPlayer.Character
    if not c then print("No character"); return end
    local h = c:FindFirstChildOfClass("Humanoid")
    print("Humanoid:", h)
    print("DisplayName:", h and h.DisplayName)
    print("Head:", c:FindFirstChild("Head"))
    print("DisplayName prop settable:", pcall(function() h.DisplayName = h.DisplayName end))
end, Color3.fromRGB(70, 110, 170))

makeButton("Scan Avatar Remotes", function()
    local pats = {"avatar", "appearance", "description", "character", "outfit"}
    local found = 0
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local n = obj.Name:lower()
            for _, p in ipairs(pats) do
                if n:find(p) then
                    print("  " .. obj:GetFullName())
                    found = found + 1
                    break
                end
            end
        end
    end
    print("Total avatar remotes: " .. found)
end, Color3.fromRGB(70, 110, 170))

makeButton("Scan Nametag Remotes", function()
    local pats = {"nametag", "displayname", "setname", "rename", "prefix", "title"}
    local found = 0
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local n = obj.Name:lower()
            for _, p in ipairs(pats) do
                if n:find(p) then
                    print("  " .. obj:GetFullName())
                    found = found + 1
                    break
                end
            end
        end
    end
    print("Total nametag remotes: " .. found)
end, Color3.fromRGB(70, 110, 170))

-- ============================================================
-- MENU CONTROL
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
-- RGB ANIMATION
-- ============================================================
RunService.RenderStepped:Connect(function()
    if State.OverheadGui then
        local lbl = State.OverheadGui:FindFirstChildOfClass("TextLabel")
        if lbl and State.OverheadRGB then
            lbl.TextColor3 = Color3.fromHSV(tick() % 1, 1, 1)
        end
    end
end)

-- Reattach on respawn
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if State.AvatarDesc then
        Avatar.apply()
        Avatar.push()
    end
    if State.OverheadEnabled then
        Nametag.setDisplayName(State.OverheadText)
        Nametag.attachBillboard(State.OverheadText)
    end
end)

print("[OBSIDIAN] v9 loaded. Open menu with V icon.")
