-- ============================================================
-- OBSIDIAN LOADER v2.0 | God Route
-- 6 fetch methods + integrity check + auto-retry + cache
-- ============================================================

local LOADER = {
    Version = "2.0",
    URLs = {
        "https://raw.githubusercontent.com/rhhhhsj-lang/OBSIDIAN/refs/heads/main/main.lua",
        "https://cdn.jsdelivr.net/gh/rhhhhsj-lang/OBSIDIAN@main/main.lua",
        "https://rawcdn.githack.com/rhhhhsj-lang/OBSIDIAN/main/main.lua",
        "https://raw.githack.com/rhhhhsj-lang/OBSIDIAN/main/main.lua",
        "https://gitcdn.link/repo/rhhhhsj-lang/OBSIDIAN/main/main.lua",
        "https://ghproxy.com/https://raw.githubusercontent.com/rhhhhsj-lang/OBSIDIAN/main/main.lua",
    },
    MaxRetries = 3,
    MinCodeLength = 500,
    CacheKey = "OBSIDIAN_CACHED_MAIN",
}

-- ============================================================
-- SAFE WRAPPER
-- ============================================================
local function S(fn, ...)
    local args = table.pack(...)
    local ok, res = pcall(function()
        return fn(table.unpack(args, 1, args.n))
    end)
    return ok, res
end

-- ============================================================
-- 6 FETCH METHODS with fallback chain
-- ============================================================
local function fetchMethod1(url) -- game:HttpGet
    local ok, res = pcall(function() return game:HttpGet(url, true) end)
    if ok and res and type(res) == "string" and #res > LOADER.MinCodeLength then
        return res
    end
    return nil
end

local function fetchMethod2(url) -- request
    if not request then return nil end
    local ok, res = pcall(function()
        local r = request({Url = url, Method = "GET", Headers = {["User-Agent"] = "Roblox/WinInet"}})
        return r and r.Body
    end)
    if ok and res and type(res) == "string" and #res > LOADER.MinCodeLength then
        return res
    end
    return nil
end

local function fetchMethod3(url) -- http_request
    if not http_request then return nil end
    local ok, res = pcall(function()
        local r = http_request({Url = url, Method = "GET"})
        return r and r.Body
    end)
    if ok and res and type(res) == "string" and #res > LOADER.MinCodeLength then
        return res
    end
    return nil
end

local function fetchMethod4(url) -- syn.request
    if not (syn and syn.request) then return nil end
    local ok, res = pcall(function()
        local r = syn.request({Url = url, Method = "GET"})
        return r and r.Body
    end)
    if ok and res and type(res) == "string" and #res > LOADER.MinCodeLength then
        return res
    end
    return nil
end

local function fetchMethod5(url) -- http.get (Hydrogen/Fluxus)
    if not (http and http.get) then return nil end
    local ok, res = pcall(function()
        local r = http.get(url)
        return r and (r.body or r.Body)
    end)
    if ok and res and type(res) == "string" and #res > LOADER.MinCodeLength then
        return res
    end
    return nil
end

local function fetchMethod6(url) -- httpget (generic)
    if not httpget then return nil end
    local ok, res = pcall(httpget, url)
    if ok and res and type(res) == "string" and #res > LOADER.MinCodeLength then
        return res
    end
    return nil
end

local fetchMethods = {
    {"HttpGet", fetchMethod1},
    {"request", fetchMethod2},
    {"http_request", fetchMethod3},
    {"syn.request", fetchMethod4},
    {"http.get", fetchMethod5},
    {"httpget", fetchMethod6},
}

-- ============================================================
-- CACHE
-- ============================================================
local function saveCache(source)
    S(function()
        if writefile and isfolder and isfolder("OBSIDIAN") then
            writefile("OBSIDIAN/main.lua", source)
        elseif writefile then
            writefile("OBSIDIAN_main.lua", source)
        end
    end)
end

local function loadCache()
    S(function()
        if readfile and isfile and isfile("OBSIDIAN/main.lua") then
            return readfile("OBSIDIAN/main.lua")
        elseif readfile and isfile and isfile("OBSIDIAN_main.lua") then
            return readfile("OBSIDIAN_main.lua")
        end
    end)
    return nil
end

-- ============================================================
-- VALIDATION - ensures code is legit
-- ============================================================
local function validateCode(source)
    if not source or type(source) ~= "string" then return false end
    if #source < LOADER.MinCodeLength then return false end
    -- Must contain key signatures
    if not source:find("OBSIDIAN") then return false end
    if not source:find("Players") then return false end
    -- Try compiling
    local fn, err = loadstring(source)
    if not fn then return false, tostring(err) end
    return true, fn
end

-- ============================================================
-- LOADING SCREEN (advanced)
-- ============================================================
local function showUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "OBSIDIAN_LOADER"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 99999
    S(function() gui.Parent = game:GetService("CoreGui") end)
    if not gui.Parent then
        S(function() gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end)
    end

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 280, 0, 120)
    bg.Position = UDim2.new(0.5, -140, 0.5, -60)
    bg.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    bg.BorderSizePixel = 0
    bg.Parent = gui
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 14) bc.Parent = bg
    local bs = Instance.new("UIStroke")
    bs.Color = Color3.fromRGB(90, 140, 220)
    bs.Thickness = 1.5
    bs.Transparency = 0.3
    bs.Parent = bg

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 34)
    title.Position = UDim2.new(0, 0, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = "OBSIDIAN"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 24
    title.Parent = bg

    local version = Instance.new("TextLabel")
    version.Size = UDim2.new(1, 0, 0, 14)
    version.Position = UDim2.new(0, 0, 0, 44)
    version.BackgroundTransparency = 1
    version.Text = "LOADER v" .. LOADER.Version
    version.TextColor3 = Color3.fromRGB(90, 140, 220)
    version.Font = Enum.Font.GothamBold
    version.TextSize = 10
    version.Parent = bg

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -20, 0, 20)
    status.Position = UDim2.new(0, 10, 0, 62)
    status.BackgroundTransparency = 1
    status.Text = "Initializing..."
    status.TextColor3 = Color3.fromRGB(180, 180, 195)
    status.Font = Enum.Font.Gotham
    status.TextSize = 11
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = bg

    local detail = Instance.new("TextLabel")
    detail.Size = UDim2.new(1, -20, 0, 14)
    detail.Position = UDim2.new(0, 10, 0, 80)
    detail.BackgroundTransparency = 1
    detail.Text = ""
    detail.TextColor3 = Color3.fromRGB(120, 120, 140)
    detail.Font = Enum.Font.Gotham
    detail.TextSize = 9
    detail.TextXAlignment = Enum.TextXAlignment.Left
    detail.Parent = bg

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -40, 0, 6)
    barBg.Position = UDim2.new(0, 20, 0, 100)
    barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    barBg.BorderSizePixel = 0
    barBg.Parent = bg
    local bbc = Instance.new("UICorner") bbc.CornerRadius = UDim.new(1, 0) bbc.Parent = barBg

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(90, 140, 220)
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg
    local bfc = Instance.new("UICorner") bfc.CornerRadius = UDim.new(1, 0) bfc.Parent = barFill

    return {
        gui = gui,
        setStatus = function(t) S(function() status.Text = t end) end,
        setDetail = function(t) S(function() detail.Text = t end) end,
        setProgress = function(p)
            S(function()
                game:GetService("TweenService"):Create(barFill, TweenInfo.new(0.15), {
                    Size = UDim2.new(math.clamp(p, 0, 1), 0, 1, 0)
                }):Play()
            end)
        end,
        destroy = function() S(function() gui:Destroy() end) end,
    }
end

-- ============================================================
-- TRY ALL URLS x ALL METHODS
-- ============================================================
local function attemptFetch(ui)
    local totalURLs = #LOADER.URLs
    local totalMethods = #fetchMethods
    local attempts = {}

    for urlIdx, url in ipairs(LOADER.URLs) do
        ui.setStatus("Testing URL " .. urlIdx .. "/" .. totalURLs .. "...")
        ui.setProgress(0.1 + (urlIdx / totalURLs) * 0.5)

        -- Detect URL source
        local src = url:match("raw%.githubusercontent") and "GitHub Raw"
            or url:match("jsdelivr") and "jsDelivr CDN"
            or url:match("githack") and "GitHack"
            or url:match("gitcdn") and "GitCDN"
            or url:match("ghproxy") and "GHProxy"
            or "Unknown"

        ui.setDetail(src)

        for mIdx, method in ipairs(fetchMethods) do
            local name = method[1]
            local fn = method[2]
            ui.setStatus("[" .. src .. "] " .. name .. "...")

            local source = fn(url)
            if source then
                local valid, compiled = validateCode(source)
                if valid then
                    ui.setDetail("Success via " .. name)
                    return compiled, source, src .. " / " .. name
                else
                    ui.setDetail("Invalid code from " .. name)
                end
            end

            task.wait(0.05)
        end
    end

    return nil, nil, "all failed"
end

-- ============================================================
-- BOOT SEQUENCE
-- ============================================================
local function boot()
    local ui = showUI()
    ui.setStatus("Pre-flight check...")
    ui.setProgress(0.05)
    task.wait(0.2)

    -- Check loadstring
    if not loadstring then
        ui.setStatus("ERROR: loadstring not supported")
        ui.setDetail("Executor may be outdated")
        task.wait(3)
        ui.destroy()
        return
    end

    -- Try cache first (fast)
    ui.setStatus("Checking local cache...")
    ui.setProgress(0.08)
    local cached = loadCache()
    if cached then
        local valid, compiled = validateCode(cached)
        if valid then
            ui.setStatus("Loading from cache...")
            ui.setDetail("Local cache hit")
            ui.setProgress(0.9)
            local ok = pcall(compiled)
            if ok then
                ui.setProgress(1)
                ui.setStatus("Ready (cached)")
                task.wait(0.3)
                ui.destroy()
                return
            end
        end
    end

    -- Fetch fresh
    ui.setStatus("Fetching from remote...")
    local compiled, source, srcDesc = attemptFetch(ui)

    if compiled then
        ui.setStatus("Compiling...")
        ui.setDetail(srcDesc)
        ui.setProgress(0.9)

        -- Save cache for next time
        if source then saveCache(source) end

        local ok, err = pcall(compiled)
        if ok then
            ui.setProgress(1)
            ui.setStatus("Ready!")
            print("[LOADER] Loaded via " .. srcDesc)
            task.wait(0.3)
            ui.destroy()
        else
            ui.setStatus("Runtime error: " .. tostring(err):sub(1, 40))
            ui.setDetail("Check console for details")
            print("[LOADER] Runtime error: " .. tostring(err))
            task.wait(3)
            ui.destroy()
        end
    else
        ui.setStatus("All sources failed")
        ui.setDetail("Check network / executor")
        ui.setProgress(1)
        print("[LOADER] Fetch failed across " .. (#LOADER.URLs * #fetchMethods) .. " combinations")
        task.wait(3)
        ui.destroy()
    end
end

-- ============================================================
-- EXPOSE GLOBAL CONTROLS
-- ============================================================
if getgenv then
    S(function()
        getgenv().OBSIDIAN = {
            Reload = boot,
            ClearCache = function()
                S(function()
                    if delfile and isfile("OBSIDIAN/main.lua") then delfile("OBSIDIAN/main.lua") end
                    if delfile and isfile("OBSIDIAN_main.lua") then delfile("OBSIDIAN_main.lua") end
                end)
                print("[LOADER] Cache cleared")
            end,
            Version = LOADER.Version,
            URLs = LOADER.URLs,
        }
    end)
end

-- ============================================================
-- RUN
-- ============================================================
task.spawn(boot)
