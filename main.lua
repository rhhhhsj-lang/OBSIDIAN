-- OBSIDIAN HUB | Arabic Edition + Skins Library
-- Aimbot + ESP + Full Skin Library

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local InsertService = game:GetService("InsertService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

print("[OBSIDIAN] loading...")

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
}

local LockedTarget = nil

-- =================== SKIN LIBRARY ===================
local Skins = {
    { name = "تانجيرو",       shirt = 6515253048,  pants = 6515254752,  acc = {12343277278, 13251512354} },
    { name = "نيزوكو",        shirt = 9804978856,  pants = 9805010066,  acc = {7673862955, 9545193225} },
    { name = "زورو",          shirt = 12295738661, pants = 12295742105, acc = {4915220823, 4915222232} },
    { name = "ايتاتشي",       shirt = 8066819004,  pants = 8066817283,  acc = {11709129852, 1246059416, 6483283962} },
    { name = "جو جو",         shirt = 9520240192,  pants = 9520257885,  acc = {6377316738} },
    { name = "جوتارو",        shirt = 6515015386,  pants = 5668090917,  acc = {12937076228, 12771595862, 12352402533} },
    { name = "سبايدرمان",     shirt = 129458426,   pants = 526902282,   acc = {6165977721, 6865771446, 7794095061} },
    { name = "سبايدرمان 2099",shirt = 11887545693, pants = 11887548888, acc = {13762838703, 13784046335, 13840004313} },
    { name = "بطل خارق عام",  shirt = 900212231,   pants = 900707705,   acc = {} },
    { name = "اوبتيموس",      shirt = 9196822163,  pants = 0,           acc = {13727270846, 13742206124} },
    { name = "افاتار ازرق",   shirt = 11433403132, pants = 12281980047, acc = {12335726023, 12802274732, 12342602214} },
    { name = "نيتيري",        shirt = 12509519635, pants = 12460887461, acc = {8760841633, 12802274732, 12342602214} },
    { name = "وينزداي",       shirt = 11404725793, pants = 0,           acc = {9449907677, 11779891462} },
    { name = "انيد",          shirt = 11674896530, pants = 0,           acc = {11747023279} },
    { name = "جندي عسكري",    shirt = 5562009157,  pants = 0,           acc = {12335726023, 13528955944} },
    { name = "شرطي",          shirt = 6446704889,  pants = 10084548738, acc = {9398276821, 13528955944} },
    { name = "رجل اعمال",     shirt = 12287097136, pants = 12287093892, acc = {} },
    { name = "ايمو جيرل",     shirt = 52659587,    pants = 0,           acc = {7896456068, 7757505440, 13203144005} },
    { name = "ايمو بوي",      shirt = 1619234893,  pants = 4964922124,  acc = {6377800673, 12593536528} },
    { name = "ساحرة وردية",   shirt = 5263297279,  pants = 0,           acc = {5511283469, 11928798968, 13253018587} },
    { name = "اجنحة ملائكية", shirt = 0,           pants = 0,           acc = {4776070792} },
    { name = "اجنحة شيطان",   shirt = 0,           pants = 0,           acc = {13533260454} },
    { name = "قناع ارنب",     shirt = 0,           pants = 0,           acc = {6385026234} },
    { name = "قناع سايبر",    shirt = 0,           pants = 0,           acc = {8143603941, 6099285852} },
    { name = "قناع جمجمة",    shirt = 0,           pants = 0,           acc = {7902367682, 6112685632} },
    { name = "هالة ملائكية",  shirt = 0,           pants = 0,           acc = {4026550685} },
    { name = "قرون مشتعلة",   shirt = 0,           pants = 0,           acc = {233705354} },
    { name = "كابيبارا",      shirt = 10752043553, pants = 10752046038, acc = {11497550117} },
    { name = "تمساح",         shirt = 7659573278,  pants = 7659574862,  acc = {11496231310} },
    { name = "قطة",           shirt = 7500275208,  pants = 7189083561,  acc = {11557345216, 12728097835, 134824163} },
    { name = "ديناصور",       shirt = 5063549346,  pants = 0,           acc = {} },
}

-- =================== SKIN APPLIERS ===================
local function clearSkin()
    local char = LocalPlayer.Character
    if not char then return end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Shirt") or v:IsA("Pants") or v:IsA("Accessory") or v:IsA("Hat") then
            v:Destroy()
        end
    end
end

local function applyAccessory(id)
    local char = LocalPlayer.Character
    if not char then return end
    local ok, model = pcall(function()
        return InsertService:LoadAsset(id)
    end)
    if ok and model then
        for _, v in ipairs(model:GetChildren()) do
            if v:IsA("Accessory") or v:IsA("Hat") then
                local clone = v:Clone()
                clone.Parent = char
                model:Destroy()
            end
        end
    end
end

local function applySkin(skin)
    local char = LocalPlayer.Character
    if not char then
        print("[OBSIDIAN] No character loaded")
        return
    end

    if skin.shirt and skin.shirt > 0 then
        local s = char:FindFirstChildOfClass("Shirt") or Instance.new("Shirt", char)
        s.ShirtTemplate = "rbxassetid://" .. tostring(skin.shirt)
    end

    if skin.pants and skin.pants > 0 then
        local p = char:FindFirstChildOfClass("Pants") or Instance.new("Pants", char)
        p.PantsTemplate = "rbxassetid://" .. tostring(skin.pants)
    end

    if skin.acc then
        for _, id in ipairs(skin.acc) do
            applyAccessory(id)
        end
    end

    print("[OBSIDIAN] Applied skin: " .. skin.name)
end

-- =================== GUI ===================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OBSIDIAN"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 300, 0, 400)
Main.Position = UDim2.new(0, 20, 0, 80)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui
local UC = Instance.new("UICorner") UC.CornerRadius = UDim.new(0, 10) UC.Parent = Main
local Stroke = Instance.new("UIStroke") Stroke.Color = Color3.fromRGB(80, 80, 100) Stroke.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 36)
Title.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
Title.BorderSizePixel = 0
Title.Text = "  OBSIDIAN HUB"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.Parent = Main
local TC = Instance.new("UICorner") TC.CornerRadius = UDim.new(0, 10) TC.Parent = Title

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -33, 0, 3)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Title
local CC = Instance.new("UICorner") CC.CornerRadius = UDim.new(0, 6) CC.Parent = CloseBtn

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -66, 0, 3)
MinBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 16
MinBtn.BorderSizePixel = 0
MinBtn.Parent = Title
local MC = Instance.new("UICorner") MC.CornerRadius = UDim.new(0, 6) MC.Parent = MinBtn

local Container = Instance.new("ScrollingFrame")
Container.Size = UDim2.new(1, -16, 1, -50)
Container.Position = UDim2.new(0, 8, 0, 42)
Container.BackgroundTransparency = 1
Container.BorderSizePixel = 0
Container.ScrollBarThickness = 4
Container.ScrollBarImageColor3 = Color3.fromRGB(90, 140, 220)
Container.CanvasSize = UDim2.new(0, 0, 0, 0)
Container.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 8)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Container

Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Container.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + 10)
end)

local function makeHeader(text)
    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(1, 0, 0, 24)
    L.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    L.BorderSizePixel = 0
    L.Text = "  " .. text
    L.TextColor3 = Color3.fromRGB(150, 200, 255)
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Font = Enum.Font.GothamBold
    L.TextSize = 13
    L.Parent = Container
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 5) c.Parent = L
end

local function makeToggle(text, key, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 34)
    Btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    Btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    Btn.Text = "  " .. text .. ": معطل"
    Btn.TextXAlignment = Enum.TextXAlignment.Left
    Btn.Font = Enum.Font.Gotham
    Btn.TextSize = 13
    Btn.BorderSizePixel = 0
    Btn.Parent = Container
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = Btn

    Btn.MouseButton1Click:Connect(function()
        State[key] = not State[key]
        Btn.Text = "  " .. text .. ": " .. (State[key] and "مفعل" or "معطل")
        Btn.BackgroundColor3 = State[key] and Color3.fromRGB(50, 90, 60) or Color3.fromRGB(35, 35, 45)
        if callback then callback(State[key]) end
    end)
    return Btn
end

local function makeSlider(text, key, min, max, default)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 46)
    Frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
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
    Bar.Size = UDim2.new(1, -20, 0, 8)
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
    Btn.Parent = Container
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = Btn
    Btn.MouseButton1Click:Connect(callback)
    return Btn
end

-- Build UI
makeHeader("التصويب")
makeToggle("التصويب التلقائي", "AimbotEnabled")
makeToggle("تثبيت الهدف", "TargetLock")
makeToggle("تجاهل الفريق", "TeamCheck")
makeToggle("تجاهل الاصدقاء", "FriendCheck")
makeSlider("نطاق التصويب", "AimbotFOV", 50, 500, 200)
makeSlider("نعومة التصويب", "AimbotSmoothness", 5, 100, 25)
makeSlider("اقصى مسافة", "MaxDistance", 100, 2000, 1000)

makeHeader("كشف اللاعبين")
makeToggle("تفعيل الكشف", "ESPEnabled")
makeToggle("خطوط التتبع", "TracerEnabled")

makeHeader("مكتبة السكنات")
for _, skin in ipairs(Skins) do
    makeButton(skin.name, function()
        applySkin(skin)
    end, Color3.fromRGB(60, 90, 140))
end

makeHeader("ادوات")
makeButton("ازالة السكن الحالي", function()
    clearSkin()
    print("[OBSIDIAN] Skin cleared")
end, Color3.fromRGB(150, 70, 70))

makeButton("لون الجسم عشوائي", function()
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.BrickColor = BrickColor.random()
        end
    end
end, Color3.fromRGB(150, 110, 60))

makeButton("اعادة الشخصية", function()
    local char = LocalPlayer.Character
    if char then char:BreakJoints() end
end, Color3.fromRGB(90, 90, 90))

print("[OBSIDIAN] GUI created")

local minimized = false
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Container.Visible = not minimized
    Main.Size = minimized and UDim2.new(0, 300, 0, 36) or UDim2.new(0, 300, 0, 400)
end)

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

print("[OBSIDIAN] loaded.")
