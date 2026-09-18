-- OBSIDIAN HUB | Mobile GUI
-- Fixed: GUI loads even without Drawing

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

print("[OBSIDIAN] loading...")

local State = {
    AimbotEnabled = false,
    ESPEnabled = false,
    TeamCheck = true,
    AimbotFOV = 200,
    AimbotSmoothness = 25,
    MaxDistance = 1000,
    TargetPart = "Head",
    BoxColor = Color3.fromRGB(255, 60, 60),
    TracerEnabled = true,
}

-- GUI Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OBSIDIAN"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 260, 0, 340)
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

local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -16, 1, -50)
Container.Position = UDim2.new(0, 8, 0, 42)
Container.BackgroundTransparency = 1
Container.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 8)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Container

local function makeToggle(text, key, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 34)
    Btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    Btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    Btn.Text = "  " .. text .. ": OFF"
    Btn.TextXAlignment = Enum.TextXAlignment.Left
    Btn.Font = Enum.Font.Gotham
    Btn.TextSize = 13
    Btn.BorderSizePixel = 0
    Btn.Parent = Container
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = Btn
    Btn.MouseButton1Click:Connect(function()
        State[key] = not State[key]
        Btn.Text = "  " .. text .. ": " .. (State[key] and "ON" or "OFF")
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

makeToggle("Aimbot", "AimbotEnabled")
makeToggle("ESP", "ESPEnabled")
makeToggle("Team Check", "TeamCheck")
makeToggle("Tracers", "TracerEnabled")
makeSlider("FOV", "AimbotFOV", 50, 500, 200)
makeSlider("Smoothness", "AimbotSmoothness", 5, 100, 25)
makeSlider("Max Distance", "MaxDistance", 100, 2000, 1000)

print("[OBSIDIAN] GUI created")

local minimized = false
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Container.Visible = not minimized
    Main.Size = minimized and UDim2.new(0, 260, 0, 36) or UDim2.new(0, 260, 0, 340)
end)

-- ESP (only if Drawing available)
local Drawing = Drawing or getgenv() and getgenv().Drawing
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

local function getClosest()
    local closest, shortest = nil, State.AimbotFOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) and not isTeammate(p) then
            local part = p.Character and p.Character:FindFirstChild(State.TargetPart)
            if part then
                local sp, on = Camera:WorldToViewportPoint(part.Position)
                if on and sp.Z > 0 then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    local wd = (Camera.CFrame.Position - part.Position).Magnitude
                    if d < shortest and wd <= State.MaxDistance then
                        shortest = d
                        closest = part
                    end
                end
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    if State.AimbotEnabled then
        local t = getClosest()
        if t then
            local aim = CFrame.new(Camera.CFrame.Position, t.Position)
            Camera.CFrame = Camera.CFrame:Lerp(aim, State.AimbotSmoothness / 100)
        end
    end

    if not Drawing then return end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) and not isTeammate(p) and State.ESPEnabled then
            if not espObjects[p] then createESP(p) end
            local o = espObjects[p]
            if not o then continue end
            local char = p.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")
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

print("[OBSIDIAN] loaded. If no GUI, check CoreGui permission.")
