local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- نافذة
local sg = Instance.new("ScreenGui")
sg.Parent = game:GetService("CoreGui")
sg.ResetOnSpawn = false

local F = Instance.new("Frame")
F.Size = UDim2.new(0, 320, 0, 180)
F.Position = UDim2.new(0.5, -160, 0, 80)
F.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
F.BorderSizePixel = 0
F.Parent = sg
local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 10) fc.Parent = F

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 26)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text = "Brookhaven Bio Attacker"
title.TextColor3 = Color3.fromRGB(150, 200, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = F

local T = Instance.new("TextBox")
T.Size = UDim2.new(1, -20, 0, 32)
T.Position = UDim2.new(0, 10, 0, 36)
T.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
T.Text = ""
T.PlaceholderText = "اكتب النص هنا..."
T.PlaceholderColor3 = Color3.fromRGB(120, 120, 140)
T.TextColor3 = Color3.fromRGB(255, 255, 255)
T.Font = Enum.Font.Gotham
T.TextSize = 13
T.BorderSizePixel = 0
T.Parent = F
Instance.new("UICorner", T).CornerRadius = UDim.new(0, 6)

local B = Instance.new("TextButton")
B.Size = UDim2.new(1, -20, 0, 32)
B.Position = UDim2.new(0, 10, 0, 74)
B.BackgroundColor3 = Color3.fromRGB(50, 140, 90)
B.Text = "APPLY (30+ payloads)"
B.TextColor3 = Color3.fromRGB(255, 255, 255)
B.Font = Enum.Font.GothamBold
B.TextSize = 13
B.BorderSizePixel = 0
B.Parent = F
Instance.new("UICorner", B).CornerRadius = UDim.new(0, 6)

local S = Instance.new("TextLabel")
S.Size = UDim2.new(1, -20, 0, 60)
S.Position = UDim2.new(0, 10, 0, 112)
S.BackgroundTransparency = 1
S.Text = "Ready"
S.TextColor3 = Color3.fromRGB(150, 200, 255)
S.Font = Enum.Font.Gotham
S.TextSize = 10
S.TextXAlignment = Enum.TextXAlignment.Left
S.TextYAlignment = Enum.TextYAlignment.Top
S.TextWrapped = true
S.Parent = F

-- ابحث عن remotes
local function find(name)
    local found = {}
    for _, obj in ipairs(game:GetDescendants()) do
        if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) and obj.Name:lower():find(name:lower()) then
            table.insert(found, obj)
        end
    end
    return found
end

local remotes = {}
table.insert(remotes, {"UpdatePlayerProfileSettings", find("UpdatePlayerProfileSettings")})
table.insert(remotes, {"SendPlayerProfileSettings", find("SendPlayerProfileSettings")})
table.insert(remotes, {"SetText", find("^SetText$")})
table.insert(remotes, {"ChangeText", find("^ChangeText$")})
table.insert(remotes, {"SetTextColor", find("^SetTextColor$")})

local function buildPayloads(text)
    local uid = LocalPlayer.UserId
    local nm = LocalPlayer.Name
    return {
        -- نصوص بسيطة
        {text},
        {text, uid},
        {uid, text},
        {text, nm},
        {nm, text},

        -- tables بحقول مختلفة (الأكثر احتمالاً للنجاح)
        {{Bio = text}},
        {{bio = text}},
        {{Description = text}},
        {{description = text}},
        {{About = text}},
        {{about = text}},
        {{Status = text}},
        {{status = text}},
        {{Text = text}},
        {{text = text}},
        {{Profile = text}},
        {{profile = text}},
        {{ProfileName = text}},
        {{Name = text}},
        {{name = text}},

        -- tables مختلطة
        {{Bio = text, Name = nm}},
        {{Description = text, UserId = uid}},
        {{About = text, UserId = uid, Name = nm}},
        {{Status = text, UserId = uid}},
        {{Text = text, UserId = uid}},
        {{Name = nm, Bio = text}},
        {{Name = nm, Description = text}},
        {{Name = nm, About = text, Age = 18, Gender = "N/A"}},
        {{UserId = uid, Name = nm, Description = text}},

        -- keys إضافية محتملة
        {{SetBio = text}},
        {{setBio = text}},
        {{SetStatus = text}},
        {{SetDescription = text}},

        -- payload مع أمر
        {"SetBio", text},
        {"SetDescription", text},
        {"SetStatus", text},
        {"SetText", text},
        {"Update", text},
        {"Set", text, uid},

        -- double
        {text, text},
        {text, {Bio = text}},
    }
end

local function attack(text)
    local payloads = buildPayloads(text)
    local total = 0
    local hit = 0
    for _, entry in ipairs(remotes) do
        local label = entry[1]
        for _, r in ipairs(entry[2]) do
            if r and r.Parent then
                for _, payload in ipairs(payloads) do
                    pcall(function()
                        if r:IsA("RemoteEvent") then
                            r:FireServer(table.unpack(payload))
                        else
                            r:InvokeServer(table.unpack(payload))
                        end
                    end)
                    total = total + 1
                    task.wait(0.04)
                end
                hit = hit + 1
                S.Text = "Fired on " .. r.Name .. " (" .. #payloads .. " payloads)"
            end
        end
    end
    S.Text = "Done! " .. total .. " sends across " .. hit .. " remotes"
    print("[BIO] " .. total .. " payloads fired")
end

B.MouseButton1Click:Connect(function()
    local text = T.Text
    if text == "" then S.Text = "اكتب نص أول"; return end
    S.Text = "Attacking..."
    task.spawn(function()
        attack(text)
    end)
end)

-- تشخيص
print("=== BIO REMOTES FOUND ===")
for _, entry in ipairs(remotes) do
    for _, r in ipairs(entry[2]) do
        print("  " .. r:GetFullName())
    end
end
print("[OBSIDIAN] Ready. Open panel, type text, hit Apply.")
