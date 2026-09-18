-- OBSIDIAN HUB | Commercial Edition
-- Aimbot + ESP + Avatar System + Floating Icon

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local State = {
    AimbotEnabled = false,
    ESPEnabled = false,
    TeamCheck = true,
    FriendCheck = true,
    TargetLock = false,
    AimbotFOV = 200,
    AimbotSmoothness = 25,
    MaxDistance = 1000,
    TargetPart = "Head",
    BoxColor = Color3.fromRGB(255, 60, 60),
    TracerEnabled = true,
    TargetUsername = "",
}

local LockedTarget = nil
local MenuOpen = false

-- =================== AVATAR SYSTEM ===================
local function applyAvatarFromUserId(userId)
    local char = LocalPlayer.Character
    if not char then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    local ok, desc = pcall(function()
        return Players:GetHumanoidDescriptionFromUserId(userId)
    end)
    if not ok or not desc then return false end
    pcall(function() humanoid:ApplyDescriptionReset(desc) end)
    return true
end

local function applyAvatarFromUsername(username)
    if username == "" then return false end
    local userId = nil
    pcall(function() userId = Players:GetUserIdFromNameAsync(username) end)
    if not userId then
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower() == username:lower() then
                userId = p.UserId
                break
            end
        end
    end
    if userId then return applyAvatarFromUserId(userId) end
    return false
end

-- =================== GUI ===================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OBSIDIAN"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- ===== FLOATING ICON =====
local Icon = Instance.new("ImageButton")
Icon.Name = "FloatingIcon"
Icon.Size = UDim2.new(0, 54, 0, 54)
Icon.Position = UDim2.new(0, 20, 0, 120)
Icon.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
Icon.BorderSizePixel = 0
Icon.Image = ""
Icon.AutoButtonColor = false
Icon.Active = true
Icon.Draggable = false
Icon.Parent = ScreenGui

local IconCorner = Instance.new("UICorner")
IconCorner.CornerRadius = UDim.new(1, 0)
IconCorner.Parent = Icon

local IconStroke = Instance.new("UIStroke")
IconStroke.Color = Color3.fromRGB(90, 140, 220)
IconStroke.Thickness = 2
IconStroke.Transparency = 0
IconStroke.Parent = Icon

local IconLabel = Instance.new("TextLabel")
IconLabel.Size = UDim2.new(1, 0, 1, 0)
IconLabel.BackgroundTransparency = 1
IconLabel.Text = "V"
IconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
IconLabel.Font = Enum.Font.GothamBlack
IconLabel.TextSize = 26
IconLabel.Parent = Icon

-- Icon drag logic
local iconDragging = false
local iconDragStart, iconStartPos

Icon.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        iconDragging = false
        iconDragStart = input.Position
        iconStartPos = Icon.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if iconDragStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - iconDragStart
        if delta.Magnitude > 8 then
            iconDragging = true
            Icon.Position = UDim2.new(0, iconStartPos.X.Offset + delta.X, 0, iconStartPos.Y.Offset + delta.Y)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        iconDragStart = nil
    end
end)

-- ===== MAIN MENU =====
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 300, 0, 420)
Main.Position = UDim2.new(0, 20, 0, 190)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Visible = false
Main.Parent = ScreenGui

local UC = Instance.new("UICorner") UC.CornerRadius = UDim.new(0, 12) UC.Parent = Main
local Stroke = Instance.new("UIStroke") Stroke.Color = Color3.fromRGB(90, 140, 220) Stroke.Thickness = 1.5 Stroke.Transparency = 0.3 Stroke.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
Title.BorderSizePixel = 0
Title.Text = "   OBSIDIAN"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.Parent = Main
local TC = Instance.new("UICorner") TC.CornerRadius = UDim.new(0, 12) TC.Parent = Title

local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(1, -60, 0, 40)
SubTitle.Position = UDim2.new(0, 0, 0, 0)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "HUB"
SubTitle.TextColor3 = Color3.fromRGB(90, 140, 220)
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.Font = Enum.Font.GothamBold
SubTitle.TextSize = 16
SubTitle.Parent = Title

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Title
local CC = Instance.new("UICorner") CC.CornerRadius = UDim.new(0, 8) CC.Parent = CloseBtn

local Container = Instance.new("ScrollingFrame")
Container.Size = UDim2.new(1, -16, 1, -52)
Container.Position = UDim2.new(0, 8, 0, 44)
Container.BackgroundTransparency = 1
Container.BorderSizePixel = 0
Container.ScrollBarThickness = 3
Container.ScrollBarImageColor3 = Color3.fromRGB(90, 140, 220)
Container.CanvasSize = UDim2.new(0, 0, 0, 0)
Container.ScrollBarImageTransparency = 0.3
Container.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 6)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Container

Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Container.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + 8)
end)

-- ===== UI HELPERS =====
local function makeHeader(text)
    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(1, 0, 0, 22)
    L.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    L.BorderSizePixel = 0
    L.Text = "  " .. text
    L.TextColor3 = Color3.fromRGB(90, 140, 220)
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Font = Enum.Font.GothamBold
    L.TextSize = 12
    L.Parent = Container
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 4) c.Parent = L
end

local function makeToggle(text, key, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 32)
    Btn.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
    Btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    Btn.Text = "  " .. text .. "  OFF"
    Btn.TextXAlignment = Enum.TextXAlignment.Left
    Btn.Font = Enum.Font.Gotham
    Btn.TextSize = 13
    Btn.BorderSizePixel = 0
    Btn.AutoButtonColor = false
    Btn.Parent = Container
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = Btn

    Btn.MouseButton1Click:Connect(function()
        State[key] = not State[key]
        Btn.Text = "  " .. text .. "  " .. (State[key] and "ON" or "OFF")
        Btn.BackgroundColor3 = State[key] and Color3.fromRGB(50, 90, 60) or Color3.fromRGB(32, 32, 42)
        if callback then callback(State[key]) end
    end)
    return Btn
end

local function makeSlider(text, key, min, max, default)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 44)
    Frame.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
    Frame.BorderSizePixel = 0
    Frame.Parent = Container
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = Frame

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -12, 0, 20)
    Lbl.Position = UDim2.new(0, 6, 0, 2)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = text .. ": " .. default
    Lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Font = Enum.Font.Gotham
    Lbl.TextSize = 12
    Lbl.Parent = Frame

    local Bar = Instance.new("Frame")
    Bar.Size = UDim2.new(1, -20, 0, 6)
    Bar.Position = UDim2.new(0, 10, 0, 30)
    Bar.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    Bar.BorderSizePixel = 0
    Bar.Parent = Frame
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(1, 0) bc.Parent = Bar

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(90, 140, 220)
    Fill.BorderSizePixel = 0
    Fill.Parent = Bar
    local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1, 0) fc.Parent = Fill

    local dragging = false
    Bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
            Fill.Size = UDim2.new(rel, 0, 1, 0)
            local val = math.floor(min + (max - min) * rel)
            Lbl.Text = text .. ": " .. val
            State[key] = val
        end
    end)
end

local function makeButton(text, callback, color)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 32)
    Btn.BackgroundColor3 = color or Color3.fromRGB(70, 110, 180)
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.Text = text
    Btn.Font = Enum.Font.GothamBold
    Btn.TextSize = 13
    Btn.BorderSizePixel = 0
    Btn.AutoButtonColor = true
    Btn.Parent = Container
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = Btn
    Btn.MouseButton1Click:Connect(callback)
    return Btn
end

local function makeInput(text, key, placeholder)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 50)
    Frame.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
    Frame.BorderSizePixel = 0
    Frame.Parent = Container
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = Frame

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -12, 0, 18)
    Lbl.Position = UDim2.new(0, 6, 0, 2)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = text
    Lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Font = Enum.Font.Gotham
    Lbl.TextSize = 12
    Lbl.Parent = Frame

    local Box = Instance.new("TextBox")
    Box.Size = UDim2.new(1, -12, 0, 26)
    Box.Position = UDim2.new(0, 6, 0, 22)
    Box.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    Box.BorderSizePixel = 0
    Box.Text = ""
    Box.PlaceholderText = placeholder or ""
    Box.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
    Box.TextColor3 = Color3.fromRGB(220, 220, 220)
    Box.Font = Enum.Font.Gotham
    Box.TextSize = 12
    Box.ClearTextOnFocus = false
    Box.Parent = Frame
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 4) bc.Parent = Box

    Box.FocusLost:Connect(function()
        State[key] = Box.Text
    end)
    return Box
end

-- ============ UI BUILD ============
makeHeader("AIMBOT")
makeToggle("Aimbot", "AimbotEnabled")
makeToggle("Target Lock", "TargetLock")
makeToggle("Team Check", "TeamCheck")
makeToggle("Friend Check", "FriendCheck")
makeSlider("FOV", "AimbotFOV", 50, 500, 200)
makeSlider("Smoothness", "AimbotSmoothness", 5, 100, 25)
makeSlider("Max Distance", "MaxDistance", 100, 2000, 1000)

makeHeader("ESP")
makeToggle("ESP", "ESPEnabled")
makeToggle("Tracers", "TracerEnabled")

makeHeader("AVATAR COPY")
makeInput("Username", "TargetUsername", "Enter username")
makeButton("Copy Avatar", function()
    if State.TargetUsername ~= "" then applyAvatarFromUsername(State.TargetUsername) end
end, Color3.fromRGB(70, 150, 90))

makeHeader("TOOLS")
makeButton("Clear Accessories", function()
    local char = LocalPlayer.Character
    if not char then return end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Shirt") or v:IsA("Pants") or v:IsA("Accessory") or v:IsA("Hat") then
            v:Destroy()
        end
    end
end, Color3.fromRGB(150, 70, 70))

makeButton("Random Body Color", function()
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.BrickColor = BrickColor.random()
        end
    end
end, Color3.fromRGB(150, 110, 60))

makeButton("Reset Character", function()
    local char = LocalPlayer.Character
    if char then char:BreakJoints() end
end, Color3.fromRGB(90, 90, 90))

-- ============ MENU TOGGLE ============
local function openMenu()
    if MenuOpen then return end
    MenuOpen = true
    Main.Visible = true
    Main.Size = UDim2.new(0, 0, 0, 420)
    TweenService:Create(Main, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 300, 0, 420)
    }):Play()
end

local function closeMenu()
    if not MenuOpen then return end
    MenuOpen = false
    local tween = TweenService:Create(Main, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 420)
    })
    tween.Completed:Connect(function() Main.Visible = false end)
    tween:Play()
end

Icon.MouseButton1Click:Connect(function()
    if iconDragging then return end
    if MenuOpen then closeMenu() else openMenu() end
end)

CloseBtn.MouseButton1Click:Connect(closeMenu)

-- =================== LOGIC ===================
local Drawing = Drawing or (getgenv() and getgenv().Drawing)
local espObjects = {}

local function isAlive(player)
    local char = player.Character
    if not char then return false end
    local h = char:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function isTeammate(player)
    if not State.TeamCheck then return false end
    if not LocalPlayer.Team then return false end
    return player.Team == LocalPlayer.Team
end

local function isFriend(player)
    if not State.FriendCheck then return false end
    local ok, result = pcall(function() return LocalPlayer:IsFriendsWith(player.UserId) end)
    return ok and result
end

local function isExcluded(player)
    if player == LocalPlayer then return true end
    if not isAlive(player) then return true end
    if isTeammate(player) then return true end
    if isFriend(player) then return true end
    return false
end

local function createESP(player)
    if espObjects[player] or not Drawing then return end
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = State.BoxColor
    box.Thickness = 1
    box.Filled = false
    local name = Drawing.new("Text")
    name.Visible = false
    name.Color = Color3.fromRGB(255, 255, 255)
    name.Size = 14
    name.Center = true
    name.Outline = true
    local dist = Drawing.new("Text")
    dist.Visible = false
    dist.Color = Color3.fromRGB(255, 255, 0)
    dist.Size = 12
    dist.Center = true
    dist.Outline = true
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = State.BoxColor
    tracer.Thickness = 1
    espObjects[player] = {box=box, name=name, dist=dist, tracer=tracer}
end

local function removeESP(player)
    local o = espObjects[player]
    if o then
        for _, v in pairs(o) do pcall(function() v:Remove() end) end
        espObjects[player] = nil
    end
end

local function findTarget()
    local closest, shortest = nil, State.AimbotFOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    if State.TargetLock and LockedTarget then
        local p = LockedTarget
        if p.Parent and isAlive(p) and not isExcluded(p) then
            local part = p.Character and p.Character:FindFirstChild(State.TargetPart)
            if part then
                local sp, on = Camera:WorldToViewportPoint(part.Position)
                if on and sp.Z > 0 then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    local wd = (Camera.CFrame.Position - part.Position).Magnitude
                    if d < State.AimbotFOV and wd <= State.MaxDistance then
                        return part
                    end
                end
            end
        end
        LockedTarget = nil
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if not isExcluded(p) then
            local part = p.Character and p.Character:FindFirstChild(State.TargetPart)
            if part then
                local sp, on = Camera:WorldToViewportPoint(part.Position)
                if on and sp.Z > 0 then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    local wd = (Camera.CFrame.Position - part.Position).Magnitude
                    if d < shortest and wd <= State.MaxDistance then
                        shortest = d
                        closest = p
                    end
                end
            end
        end
    end

    if closest then
        LockedTarget = closest
        return closest.Character and closest.Character:FindFirstChild(State.TargetPart)
    end
    return nil
end

RunService.RenderStepped:Connect(function()
    if State.AimbotEnabled then
        local t = findTarget()
        if t then
            local aim = CFrame.new(Camera.CFrame.Position, t.Position)
            Camera.CFrame = Camera.CFrame:Lerp(aim, State.AimbotSmoothness / 100)
        end
    else
        LockedTarget = nil
    end

    if not Drawing then return end

    for _, p in ipairs(Players:GetPlayers()) do
        if not isExcluded(p) and State.ESPEnabled then
            if not espObjects[p] then createESP(p) end
            local o = espObjects[p]
            if not o then continue end
            local char = p.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            if hrp and head then
                local top = head.Position + Vector3.new(0, 0.5, 0)
                local bot = hrp.Position - Vector3.new(0, 3, 0)
                local ts, ton = Camera:WorldToViewportPoint(top)
                local bs, bon = Camera:WorldToViewportPoint(bot)
                if ton and bon and ts.Z > 0 and bs.Z > 0 then
                    local h = math.abs(ts.Y - bs.Y)
                    local w = h * 0.6
                    o.box.Size = Vector2.new(w, h)
                    o.box.Position = Vector2.new(ts.X - w/2, ts.Y)
                    o.box.Color = State.BoxColor
                    o.box.Visible = true
                    o.name.Text = p.Name
                    o.name.Position = Vector2.new(ts.X, ts.Y - 20)
                    o.name.Visible = true
                    local d = (Camera.CFrame.Position - hrp.Position).Magnitude
                    o.dist.Text = string.format("%d m", math.floor(d))
                    o.dist.Position = Vector2.new(ts.X, ts.Y - 5)
                    o.dist.Visible = true
                    if State.TracerEnabled then
                        o.tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                        o.tracer.To = Vector2.new(bs.X, bs.Y)
                        o.tracer.Color = State.BoxColor
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
        else
            removeESP(p)
        end
    end
end)

Players.PlayerRemoving:Connect(removeESP)
LocalPlayer.CharacterAdded:Connect(function() LockedTarget = nil end)
