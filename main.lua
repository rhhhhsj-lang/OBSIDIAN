local LocalPlayer = game:GetService("Players").LocalPlayer

local sg = Instance.new("ScreenGui")
sg.Parent = game:GetService("CoreGui")
sg.ResetOnSpawn = false

local F = Instance.new("Frame")
F.Size = UDim2.new(0, 360, 0, 240)
F.Position = UDim2.new(0.5, -180, 0, 80)
F.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
F.BorderSizePixel = 0
F.Parent = sg
Instance.new("UICorner", F).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 24)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text = "Waiting for your bio change..."
title.TextColor3 = Color3.fromRGB(255, 200, 100)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = F

local logFrame = Instance.new("ScrollingFrame")
logFrame.Size = UDim2.new(1, -20, 0, 190)
logFrame.Position = UDim2.new(0, 10, 0, 36)
logFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
logFrame.BorderSizePixel = 0
logFrame.ScrollBarThickness = 3
logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
logFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
logFrame.Parent = F
Instance.new("UICorner", logFrame).CornerRadius = UDim.new(0, 6)
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 2)
layout.Parent = logFrame
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 4)
pad.PaddingLeft = UDim.new(0, 6)
pad.Parent = logFrame

local function addLine(text, color)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 13)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color or Color3.fromRGB(200, 200, 200)
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 9
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Parent = logFrame
    print("[CAP] " .. text)
end

if not (getrawmetatable and setreadonly and newcclosure and getnamecallmethod) then
    addLine("No hook support", Color3.fromRGB(255, 100, 100))
    return
end

local mt = getrawmetatable(game)
local oldNC = mt.__namecall
setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if method == "FireServer" or method == "InvokeServer" then
        if typeof(self) == "Instance" and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
            if not checkcaller or not checkcaller() then
                local n = self.Name:lower()
                if n:find("profile") or n:find("settings") or n:find("update") 
                   or n:find("bio") or n:find("desc") or n:find("about") then
                    local args = {...}
                    addLine("REMOTE: " .. self.Name, Color3.fromRGB(100, 200, 255))
                    for i, a in ipairs(args) do
                        local t = typeof(a)
                        if t == "table" then
                            addLine("  [" .. i .. "] table:", Color3.fromRGB(255, 220, 100))
                            for k, v in pairs(a) do
                                local vs = tostring(v)
                                if #vs > 35 then vs = vs:sub(1, 35) .. "..." end
                                addLine("    ." .. tostring(k) .. " = " .. vs, Color3.fromRGB(150, 255, 150))
                            end
                        elseif t == "string" then
                            local vs = a
                            if #vs > 50 then vs = vs:sub(1, 50) .. "..." end
                            addLine("  [" .. i .. "] str = \"" .. vs .. "\"", Color3.fromRGB(150, 255, 150))
                        else
                            addLine("  [" .. i .. "] " .. t .. " = " .. tostring(a), Color3.fromRGB(180, 180, 220))
                        end
                    end
                end
            end
        end
    end
    return oldNC(self, ...)
end)
setreadonly(mt, true)

addLine("Hook OK. Change bio in Brookhaven NOW.", Color3.fromRGB(100, 255, 150))
addLine("Wait for the rate limit to expire first (10s).", Color3.fromRGB(255, 200, 100))
