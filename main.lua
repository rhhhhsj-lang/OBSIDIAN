local LocalPlayer = game:GetService("Players").LocalPlayer
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ResetOnSpawn = false

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 380, 0, 200)
frame.Position = UDim2.new(0, 10, 0, 80)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
frame.BorderSizePixel = 0
frame.Parent = ScreenGui
local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 10) fc.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 30)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text = "OBSIDIAN - BIO CAPTURE"
title.TextColor3 = Color3.fromRGB(150, 200, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 20)
status.Position = UDim2.new(0, 10, 0, 38)
status.BackgroundTransparency = 1
status.Text = "Waiting for bio change..."
status.TextColor3 = Color3.fromRGB(255, 200, 100)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

local logFrame = Instance.new("ScrollingFrame")
logFrame.Size = UDim2.new(1, -20, 0, 120)
logFrame.Position = UDim2.new(0, 10, 0, 64)
logFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
logFrame.BorderSizePixel = 0
logFrame.ScrollBarThickness = 3
logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
logFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
logFrame.Parent = frame
local lfc = Instance.new("UICorner") lfc.CornerRadius = UDim.new(0, 6) lfc.Parent = logFrame
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 2)
layout.Parent = logFrame
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 6)
pad.PaddingLeft = UDim.new(0, 8)
pad.Parent = logFrame

local function addLog(text, color)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 14)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color or Color3.fromRGB(200, 200, 200)
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Parent = logFrame
    print("[CAPTURE] " .. text)
end

if getrawmetatable and setreadonly and newcclosure and getnamecallmethod then
    local mt = getrawmetatable(game)
    local oldNC = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" or method == "InvokeServer" then
            if typeof(self) == "Instance" and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
                if not checkcaller or not checkcaller() then
                    local args = {...}
                    for i, a in ipairs(args) do
                        if type(a) == "string" and #a > 2 and #a < 200 then
                            local lower = a:lower()
                            local hasLetters = lower:match("%a")
                            if hasLetters then
                                addLog("REMOTE: " .. self.Name, Color3.fromRGB(100, 200, 255))
                                addLog("  TEXT[" .. i .. "]: " .. a:sub(1, 40), Color3.fromRGB(100, 255, 150))
                                status.Text = "CAPTURED: " .. self.Name
                                status.TextColor3 = Color3.fromRGB(100, 255, 150)
                                break
                            end
                        end
                    end
                end
            end
        end
        return oldNC(self, ...)
    end)
    setreadonly(mt, true)
    addLog("Hook installed", Color3.fromRGB(100, 255, 150))
else
    addLog("Executor cannot hook", Color3.fromRGB(255, 100, 100))
end

game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
    if not gp then return end
    if input.KeyCode == Enum.KeyCode.X then
        frame.Visible = not frame.Visible
    end
end)
