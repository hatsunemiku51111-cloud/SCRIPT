local __ok, __err = xpcall(function()

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
if not Player then
    Player = Players.PlayerAdded:Wait()
end

local isfolder = isfolder or function() return false end
local makefolder = makefolder or function() end
local listfiles = listfiles or function() return {} end
local getcustomasset = getcustomasset or function() return "" end
local isfile = isfile or function() return false end
local writefile = writefile or function() end
local readfile = readfile or function() return "" end
local delfile = delfile or function() end

local function criarPastasPhone()
    pcall(function()
        if not isfolder("PHONE") then makefolder("PHONE") end
        if not isfolder("PHONE/Music") then makefolder("PHONE/Music") end
        if not isfolder("PHONE/Photos") then makefolder("PHONE/Photos") end
        if not isfolder("PHONE/Cache") then makefolder("PHONE/Cache") end
        if not isfolder("PHONE/Downloads") then makefolder("PHONE/Downloads") end
        if not isfolder("PHONE/Notes") then makefolder("PHONE/Notes") end
    end)
end
criarPastasPhone()

local HttpService = game:GetService("HttpService")
local SETTINGS_PATH = "PHONE/settings.json"

local defaultSettings = {
    fpsEnabled = true,
    statusBarMigrated = false,
    caseTheme = "titanio",
    gestureNav = false,
    flashlightEnabled = false,
    volume = 1,
    wallpaper = "rbxassetid://12506271392",
    phonePosition = {X = 1, Y = 0.5, XOffset = -300, YOffset = -220},
    hotbarPosition = {X = 0.5, Y = 0, XOffset = -24, YOffset = 12}
}

local phoneSettings = {}

local function loadSettings()
    local success, data = pcall(function()
        if isfile(SETTINGS_PATH) then
            return HttpService:JSONDecode(readfile(SETTINGS_PATH))
        end
        return nil
    end)
    if success and type(data) == "table" then
        for k, v in pairs(defaultSettings) do
            if data[k] == nil then data[k] = v end
        end
        phoneSettings = data
    else
        phoneSettings = table.clone(defaultSettings)
    end
end

local function saveSettings()
    pcall(function()
        writefile(SETTINGS_PATH, HttpService:JSONEncode(phoneSettings))
    end)
end

loadSettings()
if not phoneSettings.statusBarMigrated then
    phoneSettings.fpsEnabled = true
    phoneSettings.statusBarMigrated = true
    saveSettings()
end

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local GUI_PARENT = (function()
    local okH, h = pcall(function() return gethui and gethui() end)
    if okH and h then return h end
    local okC = pcall(function() return CoreGui:GetChildren() end)
    if okC then return CoreGui end
    return Player:WaitForChild("PlayerGui")
end)()

local function destroyOld(name)
    for _, p in ipairs({GUI_PARENT, CoreGui}) do
        pcall(function()
            local old = p:FindFirstChild(name)
            if old then old:Destroy() end
        end)
    end
end

local function httpGetBody(url)
    local req = request or http_request or (syn and syn.request)
    if type(req) == "function" then
        local response = req({Url = url, Method = "GET", Headers = {["User-Agent"] = "Mozilla/5.0"}})
        if type(response) == "table" and response.Body then return response.Body end
        error("Resposta HTTP vazia", 0)
    end
    if game.HttpGet then return game:HttpGet(url) end
    error("Seu ambiente não disponibiliza uma função HTTP GET", 0)
end

local isTouchDevice = UserInputService.TouchEnabled
local Character, Humanoid
local isPhoneOpen = false
local isMusicOpen = false
local currentApp = "home"
local phoneFlashlight = nil
local currentVolume = phoneSettings.volume or 1
-- FIX wallpaper: getcustomasset devolve um link "rbxasset://..." valido so nesta sessao; salvar esse link
-- fazia o wallpaper sumir ao reabrir. Agora guardamos o CAMINHO do arquivo (wallpaperFile) e geramos o
-- link de novo a cada execucao. IDs normais (rbxassetid://) continuam salvos em wallpaper.
local function resolveWallpaper()
    local f = phoneSettings.wallpaperFile
    if type(f) == "string" and f ~= "" then
        local okF, has = pcall(isfile, f)
        if okF and has then
            local okA, a = pcall(getcustomasset, f)
            if okA and type(a) == "string" and a ~= "" then return a end
        end
    end
    local w = phoneSettings.wallpaper
    if type(w) ~= "string" or w == "" or w:find("^rbxasset://") then w = nil end
    return w or defaultSettings.wallpaper
end
local currentWallpaper = resolveWallpaper()

local HotbarFrame, hotbarUIScale, phoneSlot, selectedFrame
local PhoneHome, homeBg
local MusicAppIcon, StopwatchAppIcon, ConfigAppIcon, GalleryAppIcon
local WebBrowserIcon
local MainFrame, refreshFiles, stopMusic, restoreMusic
local StopwatchFrame, resetStopwatch
local ConfigFrame, cfgGoBack, cfgReset
local GalleryFrame, refreshPhotos, exitPhotoViewer, closePhotoMenu
local isPhotoMenuOpen = false

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local WHITE = Color3.new(1, 1, 1)

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = radius
    c.Parent = obj
    return c
end

local Draw = {}

function Draw.box(parent, cx, cy, w, h, rot, color, z, radius)
    local f = Instance.new("Frame")
    f.BorderSizePixel = 0
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.new(0, cx, 0, cy)
    f.Size = UDim2.new(0, w, 0, h)
    f.Rotation = rot or 0
    f.BackgroundColor3 = color
    f.ZIndex = z or 1
    if radius then corner(f, radius) end
    f.Parent = parent
    return f
end

function Draw.line(parent, x1, y1, x2, y2, th, color, z)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy) + th
    return Draw.box(parent, (x1 + x2) / 2, (y1 + y2) / 2, len, th, math.deg(atan2(dy, dx)), color, z, UDim.new(1, 0))
end

function Draw.circle(parent, cx, cy, d, color, thickness, z)
    local size = thickness and (d - 2 * thickness) or d
    local f = Draw.box(parent, cx, cy, size, size, 0, color, z, UDim.new(1, 0))
    if thickness then
        f.BackgroundTransparency = 1
        local s = Instance.new("UIStroke")
        s.Color = color
        s.Thickness = thickness
        s.Parent = f
    end
    return f
end

function Draw.rrect(parent, cx, cy, w, h, r, color, thickness, z)
    local tw = thickness and (w - 2 * thickness) or w
    local th = thickness and (h - 2 * thickness) or h
    local f = Draw.box(parent, cx, cy, tw, th, 0, color, z, UDim.new(0, r))
    if thickness then
        f.BackgroundTransparency = 1
        local s = Instance.new("UIStroke")
        s.Color = color
        s.Thickness = thickness
        s.Parent = f
    end
    return f
end

function Draw.poly3(parent, p1, p2, p3, color, z)
    local pts = {p1, p2, p3}
    local minx, maxx = math.huge, -math.huge
    for _, p in ipairs(pts) do
        minx = math.min(minx, p[1])
        maxx = math.max(maxx, p[1])
    end
    local steps = math.clamp(math.ceil(maxx - minx), 6, 30)
    local w = (maxx - minx) / steps
    for i = 0, steps - 1 do
        local xm = minx + (i + 0.5) * w
        local lo, hi = math.huge, -math.huge
        for e = 1, 3 do
            local a, b = pts[e], pts[e % 3 + 1]
            if a[1] ~= b[1] and ((a[1] <= xm and xm <= b[1]) or (b[1] <= xm and xm <= a[1])) then
                local t = (xm - a[1]) / (b[1] - a[1])
                local y = a[2] + t * (b[2] - a[2])
                lo = math.min(lo, y)
                hi = math.max(hi, y)
            end
        end
        if hi > lo then
            Draw.box(parent, xm, (lo + hi) / 2, w + 0.7, hi - lo, 0, color, z)
        end
    end
end

function Draw.quad(parent, p1, p2, p3, p4, color, z)
    Draw.poly3(parent, p1, p2, p3, color, z)
    Draw.poly3(parent, p1, p3, p4, color, z)
end

function Draw.arc(parent, cx, cy, r, a0, a1, th, color, z)
    local n = math.max(4, math.ceil(math.abs(a1 - a0) / 18))
    local px, py
    for i = 0, n do
        local a = math.rad(a0 + (a1 - a0) * i / n)
        local x, y = cx + r * math.cos(a), cy + r * math.sin(a)
        if px then Draw.line(parent, px, py, x, y, th, color, z) end
        px, py = x, y
    end
end

function Draw.arrowHead(parent, tx, ty, dx, dy, size, th, color, z)
    local ang = atan2(dy, dx)
    for _, off in ipairs({150, -150}) do
        local a = ang + math.rad(off)
        Draw.line(parent, tx, ty, tx + size * math.cos(a), ty + size * math.sin(a), th, color, z)
    end
end

local Icons = {}

local function iconRoot(parent, S)
    local c = Instance.new("Frame")
    c.Name = "Icon"
    c.BackgroundTransparency = 1
    c.BorderSizePixel = 0
    c.Size = UDim2.new(0, S, 0, S)
    c.Parent = parent
    return c, S / 24
end

local function T(v, u) return math.max(1.2, v * u) end

function Icons.back(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.line(c, 15 * u, 5 * u, 8 * u, 12 * u, T(2.6, u), color, z)
    Draw.line(c, 8 * u, 12 * u, 15 * u, 19 * u, T(2.6, u), color, z)
    return c
end

function Icons.home(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.circle(c, 12 * u, 12 * u, 17 * u, color, T(2.4, u), z)
    return c
end

function Icons.recents(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.rrect(c, 12 * u, 12 * u, 15 * u, 15 * u, 3.5 * u, color, T(2.4, u), z)
    return c
end

function Icons.close(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.line(c, 6 * u, 6 * u, 18 * u, 18 * u, T(2.6, u), color, z)
    Draw.line(c, 18 * u, 6 * u, 6 * u, 18 * u, T(2.6, u), color, z)
    return c
end

function Icons.phone(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.rrect(c, 12 * u, 12 * u, 13 * u, 21 * u, 3.4 * u, color, T(2.2, u), z)
    Draw.line(c, 10 * u, 5.6 * u, 14 * u, 5.6 * u, T(1.6, u), color, z)
    Draw.circle(c, 12 * u, 18.4 * u, 2 * u, color, nil, z)
    return c
end

function Icons.music(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.circle(c, 8 * u, 18 * u, 5.4 * u, color, nil, z)
    Draw.circle(c, 17 * u, 16 * u, 5.4 * u, color, nil, z)
    Draw.line(c, 10.4 * u, 17.5 * u, 10.4 * u, 6.2 * u, T(1.9, u), color, z)
    Draw.line(c, 19.4 * u, 15.5 * u, 19.4 * u, 4.2 * u, T(1.9, u), color, z)
    Draw.line(c, 10.4 * u, 6.6 * u, 19.4 * u, 4.6 * u, T(2.8, u), color, z)
    return c
end

function Icons.stopwatch(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.circle(c, 12 * u, 13.5 * u, 17 * u, color, T(2.2, u), z)
    Draw.line(c, 10 * u, 2.6 * u, 14 * u, 2.6 * u, T(2.2, u), color, z)
    Draw.line(c, 18.4 * u, 6.2 * u, 19.8 * u, 4.8 * u, T(2.2, u), color, z)
    Draw.line(c, 12 * u, 13.5 * u, 15.4 * u, 10.1 * u, T(2.2, u), color, z)
    Draw.circle(c, 12 * u, 13.5 * u, 2.8 * u, color, nil, z)
    return c
end

function Icons.gear(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.circle(c, 12 * u, 12 * u, 14 * u, color, T(2.8, u), z)
    for k = 0, 7 do
        local a = k * 45
        local rad = math.rad(a)
        Draw.box(c, 12 * u + 8.2 * u * math.sin(rad), 12 * u - 8.2 * u * math.cos(rad),
            3.6 * u, 4.8 * u, a, color, z, UDim.new(0, math.max(1, 0.8 * u)))
    end
    return c
end

function Icons.gallery(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.rrect(c, 12 * u, 12 * u, 19 * u, 16 * u, 3.6 * u, color, T(2.2, u), z)
    Draw.circle(c, 8.6 * u, 9 * u, 3.2 * u, color, nil, z)
    local clip = Instance.new("Frame")
    clip.BackgroundTransparency = 1
    clip.BorderSizePixel = 0
    clip.ClipsDescendants = true
    clip.Position = UDim2.new(0, 5 * u, 0, 11 * u)
    clip.Size = UDim2.new(0, 14 * u, 0, 6.2 * u)
    clip.ZIndex = z or 1
    clip.Parent = c
    Draw.box(clip, 5 * u, 7 * u, 8 * u, 8 * u, 45, color, z)
    Draw.box(clip, 10.8 * u, 7.6 * u, 6.4 * u, 6.4 * u, 45, color, z)
    return c
end

function Icons.play(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.poly3(c, {7.5 * u, 4.5 * u}, {7.5 * u, 19.5 * u}, {19.5 * u, 12 * u}, color, z)
    return c
end

function Icons.pause(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.rrect(c, 8.2 * u, 12 * u, 4.6 * u, 15 * u, 1.4 * u, color, nil, z)
    Draw.rrect(c, 15.8 * u, 12 * u, 4.6 * u, 15 * u, 1.4 * u, color, nil, z)
    return c
end

function Icons.next(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.poly3(c, {4.5 * u, 5 * u}, {4.5 * u, 19 * u}, {15.5 * u, 12 * u}, color, z)
    Draw.rrect(c, 18.6 * u, 12 * u, 3 * u, 14 * u, 1.2 * u, color, nil, z)
    return c
end

function Icons.prev(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.poly3(c, {19.5 * u, 5 * u}, {19.5 * u, 19 * u}, {8.5 * u, 12 * u}, color, z)
    Draw.rrect(c, 5.4 * u, 12 * u, 3 * u, 14 * u, 1.2 * u, color, nil, z)
    return c
end

function Icons.chevronRight(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.line(c, 9 * u, 5 * u, 16 * u, 12 * u, T(2.6, u), color, z)
    Draw.line(c, 16 * u, 12 * u, 9 * u, 19 * u, T(2.6, u), color, z)
    return c
end

function Icons.arrowRight(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    local th = T(2.4, u)
    Draw.line(c, 4 * u, 12 * u, 18.5 * u, 12 * u, th, color, z)
    Draw.arrowHead(c, 20.5 * u, 12 * u, 1, 0, 6 * u, th, color, z)
    return c
end

function Icons.shuffle(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    local th = T(2.2, u)
    Draw.line(c, 3.5 * u, 7 * u, 8 * u, 7 * u, th, color, z)
    Draw.line(c, 8 * u, 7 * u, 15 * u, 17 * u, th, color, z)
    Draw.line(c, 15 * u, 17 * u, 19 * u, 17 * u, th, color, z)
    Draw.arrowHead(c, 21.5 * u, 17 * u, 1, 0, 4.6 * u, th, color, z)
    Draw.line(c, 3.5 * u, 17 * u, 8 * u, 17 * u, th, color, z)
    Draw.line(c, 8 * u, 17 * u, 15 * u, 7 * u, th, color, z)
    Draw.line(c, 15 * u, 7 * u, 19 * u, 7 * u, th, color, z)
    Draw.arrowHead(c, 21.5 * u, 7 * u, 1, 0, 4.6 * u, th, color, z)
    return c
end

local function repeatBase(c, u, color, z)
    local th = T(2.2, u)
    Draw.line(c, 5 * u, 11.5 * u, 5 * u, 8 * u, th, color, z)
    Draw.line(c, 5 * u, 8 * u, 18 * u, 8 * u, th, color, z)
    Draw.arrowHead(c, 20.5 * u, 8 * u, 1, 0, 4.6 * u, th, color, z)
    Draw.line(c, 19 * u, 12.5 * u, 19 * u, 16 * u, th, color, z)
    Draw.line(c, 19 * u, 16 * u, 6 * u, 16 * u, th, color, z)
    Draw.arrowHead(c, 3.5 * u, 16 * u, -1, 0, 4.6 * u, th, color, z)
end

function Icons.repeatAll(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    repeatBase(c, u, color, z)
    return c
end

function Icons.repeatOne(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    repeatBase(c, u, color, z)
    Draw.line(c, 12.4 * u, 10.2 * u, 12.4 * u, 14 * u, T(1.8, u), color, z)
    Draw.line(c, 10.8 * u, 11.4 * u, 12.4 * u, 10.2 * u, T(1.8, u), color, z)
    return c
end

local function speaker(c, u, color, z)
    Draw.rrect(c, 6 * u, 12 * u, 4.4 * u, 6.4 * u, 1.2 * u, color, nil, z)
    Draw.quad(c, {7 * u, 8.8 * u}, {13 * u, 4.5 * u}, {13 * u, 19.5 * u}, {7 * u, 15.2 * u}, color, z)
end

function Icons.volUp(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    speaker(c, u, color, z)
    Draw.arc(c, 13.5 * u, 12 * u, 4.6 * u, -48, 48, T(2.1, u), color, z)
    Draw.arc(c, 13.5 * u, 12 * u, 8.2 * u, -48, 48, T(2.1, u), color, z)
    return c
end

function Icons.volDown(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    speaker(c, u, color, z)
    Draw.arc(c, 13.5 * u, 12 * u, 4.6 * u, -48, 48, T(2.1, u), color, z)
    return c
end

function Icons.search(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.circle(c, 10.5 * u, 10.5 * u, 13 * u, color, T(2.2, u), z)
    Draw.line(c, 15.8 * u, 15.8 * u, 20.5 * u, 20.5 * u, T(2.6, u), color, z)
    return c
end

function Icons.folder(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.rrect(c, 12 * u, 14 * u, 19 * u, 13 * u, 2.6 * u, color, T(2.2, u), z)
    Draw.rrect(c, 7.6 * u, 6.6 * u, 7.6 * u, 4 * u, 1.6 * u, color, nil, z)
    return c
end

function Icons.note(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.circle(c, 8 * u, 17.5 * u, 6.4 * u, color, nil, z)
    Draw.line(c, 10.9 * u, 17 * u, 10.9 * u, 5.5 * u, T(2, u), color, z)
    Draw.line(c, 10.9 * u, 5.8 * u, 18 * u, 8.4 * u, T(2.6, u), color, z)
    return c
end

function Icons.heart(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.circle(c, 8.8 * u, 9.8 * u, 9 * u, color, nil, z)
    Draw.circle(c, 15.2 * u, 9.8 * u, 9 * u, color, nil, z)
    Draw.box(c, 12 * u, 13 * u, 9 * u, 9 * u, 45, color, z, UDim.new(0, 1 * u))
    return c
end

function Icons.reset(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    local th = T(2.4, u)
    Draw.arc(c, 12 * u, 12 * u, 7.2 * u, -135, 150, th, color, z)
    local ax = 12 * u + 7.2 * u * math.cos(math.rad(-135))
    local ay = 12 * u + 7.2 * u * math.sin(math.rad(-135))
    Draw.arrowHead(c, ax, ay, -0.707, 0.707, 5 * u, th, color, z)
    return c
end

function Icons.dotsV(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.circle(c, 12 * u, 5.5 * u, 3.4 * u, color, nil, z)
    Draw.circle(c, 12 * u, 12 * u, 3.4 * u, color, nil, z)
    Draw.circle(c, 12 * u, 18.5 * u, 3.4 * u, color, nil, z)
    return c
end

function Icons.info(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.circle(c, 12 * u, 6.2 * u, 3.4 * u, color, nil, z)
    Draw.line(c, 12 * u, 10.8 * u, 12 * u, 18.6 * u, T(2.8, u), color, z)
    return c
end

function Icons.wallpaper(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.rrect(c, 12 * u, 12 * u, 18 * u, 18 * u, 4 * u, color, T(2.2, u), z)
    Draw.rrect(c, 12 * u, 12 * u, 8 * u, 8 * u, 2 * u, color, nil, z)
    return c
end

function Icons.tower(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    local th = T(2, u)
    Draw.circle(c, 12 * u, 10 * u, 3.6 * u, color, nil, z)
    Draw.arc(c, 12 * u, 10 * u, 5.4 * u, -45, 45, th, color, z)
    Draw.arc(c, 12 * u, 10 * u, 9 * u, -45, 45, th, color, z)
    Draw.arc(c, 12 * u, 10 * u, 5.4 * u, 135, 225, th, color, z)
    Draw.arc(c, 12 * u, 10 * u, 9 * u, 135, 225, th, color, z)
    Draw.line(c, 12 * u, 12.4 * u, 8.2 * u, 21 * u, T(2.2, u), color, z)
    Draw.line(c, 12 * u, 12.4 * u, 15.8 * u, 21 * u, T(2.2, u), color, z)
    return c
end

function Icons.flag(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.line(c, 6 * u, 4.5 * u, 6 * u, 20.5 * u, T(2.2, u), color, z)
    Draw.poly3(c, {7 * u, 4.5 * u}, {19.5 * u, 9 * u}, {7 * u, 13.5 * u}, color, z)
    return c
end

function Icons.gps(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.circle(c, 12 * u, 9.5 * u, 13 * u, color, T(2.4, u), z)
    Draw.line(c, 6.4 * u, 13.2 * u, 12 * u, 21.5 * u, T(2.4, u), color, z)
    Draw.line(c, 17.6 * u, 13.2 * u, 12 * u, 21.5 * u, T(2.4, u), color, z)
    Draw.circle(c, 12 * u, 9.5 * u, 4.4 * u, color, nil, z)
    return c
end

function Icons.gauge(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.arc(c, 12 * u, 14 * u, 8.5 * u, 180, 360, T(2.2, u), color, z)
    Draw.line(c, 12 * u, 14 * u, 16.5 * u, 8.8 * u, T(2.2, u), color, z)
    Draw.circle(c, 12 * u, 14 * u, 4 * u, color, nil, z)
    return c
end

function Icons.torch(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    Draw.quad(c, {7.5 * u, 3 * u}, {16.5 * u, 3 * u}, {14 * u, 9 * u}, {10 * u, 9 * u}, color, z)
    Draw.rrect(c, 12 * u, 15.8 * u, 5 * u, 11 * u, 1.6 * u, color, nil, z)
    return c
end

function Icons.gesture(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    local th = T(2.4, u)
    Draw.rrect(c, 12 * u, 19.5 * u, 12 * u, 3 * u, 1.5 * u, color, nil, z)
    Draw.line(c, 12 * u, 14.5 * u, 12 * u, 6.5 * u, th, color, z)
    Draw.arrowHead(c, 12 * u, 4.5 * u, 0, -1, 5 * u, th, color, z)
    return c
end

function Icons.put(host, fn, S, color, z)
    local old = host:FindFirstChild("IconHolder")
    if old then old:Destroy() end
    if host:IsA("TextButton") or host:IsA("TextLabel") then host.Text = "" end
    local ic = fn(host, S, color or WHITE, z or ((host.ZIndex or 1) + 1))
    ic.Name = "IconHolder"
    ic.AnchorPoint = Vector2.new(0.5, 0.5)
    ic.Position = UDim2.new(0.5, 0, 0.5, 0)
    return ic
end

function Icons.text(host, o)
    local z = o.z or ((host.ZIndex or 1) + 1)
    local S = o.iconSize or 16
    local gap = o.gap or 6
    host.Text = ""

    local row = Instance.new("Frame")
    row.Name = "IconText"
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 1, 0)
    row.ZIndex = z
    row.Parent = host

    local slot = Instance.new("Frame")
    slot.Name = "Slot"
    slot.BackgroundTransparency = 1
    slot.BorderSizePixel = 0
    slot.Size = UDim2.new(0, S, 0, S)
    slot.ZIndex = z
    slot.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Name = "Label"
    lbl.BackgroundTransparency = 1
    lbl.BorderSizePixel = 0
    lbl.Font = o.font or host.Font
    lbl.TextSize = o.textSize or host.TextSize
    lbl.TextColor3 = o.textColor or host.TextColor3
    lbl.Text = o.text or ""
    lbl.ZIndex = z
    lbl.Parent = row

    if (o.align or "center") == "center" then
        local ll = Instance.new("UIListLayout")
        ll.FillDirection = Enum.FillDirection.Horizontal
        ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
        ll.VerticalAlignment = Enum.VerticalAlignment.Center
        ll.SortOrder = Enum.SortOrder.LayoutOrder
        ll.Padding = UDim.new(0, gap)
        ll.Parent = row
        slot.LayoutOrder = 1
        lbl.LayoutOrder = 2
        lbl.AutomaticSize = Enum.AutomaticSize.X
        lbl.Size = UDim2.new(0, 0, 1, 0)
    else
        local pad = o.pad or 10
        slot.AnchorPoint = Vector2.new(0, 0.5)
        slot.Position = UDim2.new(0, pad, 0.5, 0)
        lbl.Position = UDim2.new(0, pad + S + gap, 0, 0)
        lbl.Size = UDim2.new(1, -(pad + S + gap + pad), 1, 0)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
    end

    local ui = {label = lbl, slot = slot}
    function ui.set(fn, text, color)
        if fn then
            for _, ch in ipairs(slot:GetChildren()) do ch:Destroy() end
            fn(slot, S, color or o.color or WHITE, z)
        end
        if text then lbl.Text = text end
    end
    function ui.setColor(textColor, iconColor)
        lbl.TextColor3 = textColor
        Icons.setColor(slot, iconColor or textColor)
    end
    ui.set(o.icon, o.text, o.color)
    return ui
end

function Icons.empty(host, fn, S, color, z)
    z = z or ((host.ZIndex or 1) + 1)
    local txt = host.Text
    host.Text = ""
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 0, 0, S + 8)
    lbl.Size = UDim2.new(1, 0, 1, -(S + 8))
    lbl.Font = host.Font
    lbl.TextSize = host.TextSize
    lbl.TextColor3 = host.TextColor3
    lbl.TextWrapped = true
    lbl.Text = txt
    lbl.ZIndex = z
    lbl.Parent = host
    local ic = fn(host, S, color, z)
    ic.AnchorPoint = Vector2.new(0.5, 0)
    ic.Position = UDim2.new(0.5, 0, 0, 6)
    return ic
end

function Icons.searchField(box, S, left, color)
    local ic = Icons.search(box, S, color or Color3.fromRGB(150, 150, 170), (box.ZIndex or 1) + 1)
    ic.AnchorPoint = Vector2.new(0, 0.5)
    ic.Position = UDim2.new(0, left or 10, 0.5, 0)
    return ic
end

function Icons.setColor(root, color)
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("UIStroke") then
            d.Color = color
        elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
            d.BackgroundColor3 = color
        end
    end
end

local Nav = {home = function() end, back = function() end, recents = function() end, gps = {}}

-- ============================================================
--  GIF LOCAL: decodificador de GIF + cache de quadros (PNG)
--  Roblox nao anima .gif; aqui o GIF e decodificado em Lua,
--  cada quadro vira um PNG em PHONE/GifFrames/<chave>/ e a
--  Galeria/Navegador trocam os quadros para animar.
-- ============================================================
Nav.gif = (function()
    local Gif = {}
    local bit = bit32
    local floor = math.floor
    local unpack = table.unpack or unpack
    local tcreate = table.create or function(n, v)
        local t = {}
        for i = 1, n do t[i] = v end
        return t
    end
    local GIF_DIR = "PHONE/GifFrames"

    function Gif.hash(str)
        local h1, h2 = 5381, 52711
        for i = 1, #str do
            local c = str:byte(i)
            h1 = (h1 * 33 + c) % 4294967296
            h2 = (h2 * 31 + c) % 4294967291
        end
        return string.format("%08x%08x", h1, h2)
    end

    -- FIX (GIFs se misturando): a chave do cache NAO pode depender so do nome do arquivo.
    -- Dois GIFs com o mesmo nome (ou um GIF regravado) reaproveitavam quadros antigos.
    -- A impressao digital usa o tamanho + amostras espalhadas do conteudo.
    function Gif.fingerprint(data)
        local n = #data
        local h1, h2 = n % 4294967296, 7919
        local function feed(c)
            h1 = (h1 * 33 + c) % 4294967296
            h2 = (h2 * 31 + c) % 4294967291
        end
        for i = 1, math.min(n, 64) do feed(data:byte(i)) end
        local step = math.max(1, floor(n / 127))
        for i = 65, n, step do feed(data:byte(i)) end
        for i = math.max(1, n - 63), n do feed(data:byte(i)) end
        return n .. "_" .. string.format("%08x%08x", h1, h2)
    end

    function Gif.keyFor(name, data)
        return Gif.hash(tostring(name) .. "|" .. Gif.fingerprint(data))
    end

    ---------------------------------------------------------------- PNG
    local crcTable
    local function crc32(s)
        if not crcTable then
            crcTable = {}
            for n = 0, 255 do
                local c = n
                for _ = 1, 8 do
                    if bit.band(c, 1) == 1 then c = bit.bxor(0xEDB88320, bit.rshift(c, 1))
                    else c = bit.rshift(c, 1) end
                end
                crcTable[n + 1] = c
            end
        end
        local c = 0xFFFFFFFF
        local tb = crcTable
        for i = 1, #s do
            c = bit.bxor(tb[bit.band(bit.bxor(c, s:byte(i)), 255) + 1], bit.rshift(c, 8))
        end
        return bit.bxor(c, 0xFFFFFFFF)
    end

    local function be32(n)
        return string.char(floor(n / 16777216) % 256, floor(n / 65536) % 256, floor(n / 256) % 256, n % 256)
    end

    local function adler32(s)
        local a, b = 1, 0
        local len = #s
        local i = 1
        while i <= len do
            local j = math.min(i + 3799, len)
            for k = i, j do
                a = a + s:byte(k)
                b = b + a
            end
            a = a % 65521
            b = b % 65521
            i = j + 1
        end
        return b * 65536 + a
    end

    -- zlib "stored" (sem compressao): simples e 100% valido
    local function zlibStore(raw)
        local out = {"\120\1"}
        local len = #raw
        local pos = 1
        while pos <= len do
            local n = math.min(65535, len - pos + 1)
            local final = (pos + n > len) and 1 or 0
            local nn = 65535 - n
            out[#out + 1] = string.char(final, n % 256, floor(n / 256), nn % 256, floor(nn / 256))
            out[#out + 1] = raw:sub(pos, pos + n - 1)
            pos = pos + n
        end
        out[#out + 1] = be32(adler32(raw))
        return table.concat(out)
    end

    local function chunk(kind, body)
        return be32(#body) .. kind .. body .. be32(crc32(kind .. body))
    end

    -- canvas: array de inteiros r + g*256 + b*65536 (ou -1 = transparente)
    -- <=256 cores: PNG indexado (1 byte/pixel, ~4x menor). Senao: RGBA.
    local function encodePng(canvas, W, ow, oh, xmap, ymap)
        local map, plist, count, overflow = {}, {}, 0, false
        for oy = 1, oh do
            local base = ymap[oy] * W
            for ox = 1, ow do
                local v = canvas[base + xmap[ox]]
                if map[v] == nil then
                    count = count + 1
                    if count > 256 then overflow = true; break end
                    map[v] = count
                    plist[count] = v
                end
            end
            if overflow then break end
        end
        local rows = {}
        if not overflow then
            for oy = 1, oh do
                local t = {0}
                local base = ymap[oy] * W
                for ox = 1, ow do t[ox + 1] = map[canvas[base + xmap[ox]]] - 1 end
                rows[oy] = string.char(unpack(t))
            end
            local pl, tr = {}, {}
            for i = 1, count do
                local v = plist[i]
                if v < 0 then
                    pl[i] = "\0\0\0"; tr[i] = "\0"
                else
                    local r = v % 256
                    local v2 = (v - r) / 256
                    local g = v2 % 256
                    pl[i] = string.char(r, g, (v2 - g) / 256); tr[i] = "\255"
                end
            end
            local ihdr = be32(ow) .. be32(oh) .. "\8\3\0\0\0"
            return "\137PNG\13\10\26\10" .. chunk("IHDR", ihdr) .. chunk("PLTE", table.concat(pl)) .. chunk("tRNS", table.concat(tr)) .. chunk("IDAT", zlibStore(table.concat(rows))) .. chunk("IEND", "")
        end
        for oy = 1, oh do
            local t = {0}
            local n = 1
            local base = ymap[oy] * W
            for ox = 1, ow do
                local v = canvas[base + xmap[ox]]
                if v < 0 then
                    t[n + 1] = 0; t[n + 2] = 0; t[n + 3] = 0; t[n + 4] = 0
                else
                    local r = v % 256
                    local v2 = (v - r) / 256
                    local g = v2 % 256
                    t[n + 1] = r; t[n + 2] = g; t[n + 3] = (v2 - g) / 256; t[n + 4] = 255
                end
                n = n + 4
            end
            rows[oy] = string.char(unpack(t))
        end
        local ihdr = be32(ow) .. be32(oh) .. "\8\6\0\0\0"
        return "\137PNG\13\10\26\10" .. chunk("IHDR", ihdr) .. chunk("IDAT", zlibStore(table.concat(rows))) .. chunk("IEND", "")
    end

    ---------------------------------------------------------------- GIF
    local function u16(d, p) return d:byte(p) + d:byte(p + 1) * 256 end

    local function buildPal(data, off, count)
        local pal = {}
        for i = 0, count - 1 do
            local p = off + i * 3
            pal[i + 1] = data:byte(p) + data:byte(p + 1) * 256 + data:byte(p + 2) * 65536
        end
        return pal
    end

    local function scan(data)
        if #data < 14 or data:sub(1, 3) ~= "GIF" then return nil end
        local W, H = u16(data, 7), u16(data, 9)
        local flags = data:byte(11)
        local pos = 14
        local gpal
        if flags >= 128 then
            local cnt = bit.lshift(1, (flags % 8) + 1)
            gpal = buildPal(data, pos, cnt)
            pos = pos + 3 * cnt
        end
        local frames = {}
        local gce = {disposal = 0, delay = 10, trans = nil}
        local len = #data
        while pos <= len do
            local c = data:byte(pos)
            if c == 0x21 then
                if data:byte(pos + 1) == 0xF9 and data:byte(pos + 2) == 4 then
                    local pk = data:byte(pos + 3)
                    local dl = u16(data, pos + 4)
                    if dl <= 1 then dl = 10 end
                    gce = {disposal = bit.band(bit.rshift(pk, 2), 7), delay = dl, trans = (bit.band(pk, 1) == 1) and data:byte(pos + 6) or nil}
                end
                pos = pos + 2
                while pos <= len do
                    local sz = data:byte(pos)
                    if sz == 0 then pos = pos + 1; break end
                    pos = pos + 1 + sz
                end
            elseif c == 0x2C then
                local f = {x = u16(data, pos + 1), y = u16(data, pos + 3), w = u16(data, pos + 5), h = u16(data, pos + 7)}
                local pk = data:byte(pos + 9)
                pos = pos + 10
                f.interlaced = bit.band(pk, 64) ~= 0
                if pk >= 128 then
                    local cnt = bit.lshift(1, (pk % 8) + 1)
                    f.pal = buildPal(data, pos, cnt)
                    pos = pos + 3 * cnt
                end
                f.minCode = data:byte(pos)
                pos = pos + 1
                local parts = {}
                while pos <= len do
                    local sz = data:byte(pos)
                    if sz == nil or sz == 0 then pos = pos + 1; break end
                    parts[#parts + 1] = data:sub(pos + 1, pos + sz)
                    pos = pos + 1 + sz
                end
                f.parts = parts
                f.disposal, f.delay, f.trans = gce.disposal, gce.delay, gce.trans
                frames[#frames + 1] = f
                gce = {disposal = 0, delay = 10, trans = nil}
            else
                break
            end
        end
        if #frames < 1 then return nil end
        return {w = W, h = H, gpal = gpal, frames = frames}
    end

    local function lzw(parts, minCode, npix, yield)
        local data = table.concat(parts)
        local clear = bit.lshift(1, minCode)
        local eoi = clear + 1
        local codeSize = minCode + 1
        local mask = bit.lshift(1, codeSize) - 1
        local nextCode = eoi + 1
        local prefix, suffix = {}, {}
        local out = tcreate(npix, 0)
        local op = 0
        local bitbuf, bits, pos, dl = 0, 0, 1, #data
        local old, first = nil, 0
        local stack = {}
        local tick = 0
        while op < npix do
            while bits < codeSize and pos <= dl do
                bitbuf = bit.bor(bitbuf, bit.lshift(data:byte(pos), bits))
                pos = pos + 1
                bits = bits + 8
            end
            if bits < codeSize then break end
            local code = bit.band(bitbuf, mask)
            bitbuf = bit.rshift(bitbuf, codeSize)
            bits = bits - codeSize
            if code == clear then
                codeSize = minCode + 1
                mask = bit.lshift(1, codeSize) - 1
                nextCode = eoi + 1
                old = nil
            elseif code == eoi then
                break
            elseif old == nil then
                op = op + 1
                out[op] = code
                old = code
                first = code
            else
                local inCode = code
                local sp = 0
                if code >= nextCode then
                    sp = 1
                    stack[1] = first
                    code = old
                end
                while code >= clear do
                    sp = sp + 1
                    stack[sp] = suffix[code]
                    code = prefix[code]
                end
                first = code
                sp = sp + 1
                stack[sp] = first
                if nextCode < 4096 then
                    prefix[nextCode] = old
                    suffix[nextCode] = first
                    nextCode = nextCode + 1
                    if bit.band(nextCode, mask) == 0 and nextCode < 4096 then
                        codeSize = codeSize + 1
                        mask = bit.lshift(1, codeSize) - 1
                    end
                end
                while sp > 0 do
                    op = op + 1
                    out[op] = stack[sp]
                    sp = sp - 1
                end
                old = inCode
            end
            tick = tick + 1
            if tick >= 20000 then
                tick = 0
                if yield then yield() end
            end
        end
        return out
    end

    local function rowMap(h, interlaced)
        local map = {}
        if not interlaced then
            for i = 1, h do map[i] = i - 1 end
            return map
        end
        local r = 0
        local passes = {{0, 8}, {4, 8}, {2, 4}, {1, 2}}
        for _, p in ipairs(passes) do
            local y = p[1]
            while y < h do
                r = r + 1
                map[r] = y
                y = y + p[2]
            end
        end
        return map
    end

    local function copyCanvas(t, n)
        local c = tcreate(n, -1)
        for i = 1, n do c[i] = t[i] end
        return c
    end

    -- opts: maxFrames (0=todos), maxDim (480), yield, cancelled, onProg, firstOnly, budget (segundos)
    local function decodeInner(data, opts)
        local g = scan(data)
        if not g then error("GIF invalido", 0) end
        local W, H = g.w, g.h
        if W < 1 or H < 1 then error("GIF vazio", 0) end
        local n = #g.frames
        -- maxFrames = 0 significa "todos os quadros"; padrao passou a ser todos
        local maxFrames = opts.firstOnly and 1 or (opts.maxFrames or 0)
        if maxFrames <= 0 then maxFrames = n end   -- 0 = sem limite = todos os quadros
        local maxDim = opts.maxDim or 480
        local scale = math.min(1, maxDim / math.max(W, H))
        local ow, oh = math.max(1, floor(W * scale)), math.max(1, floor(H * scale))
        -- orcamento de memoria de video: reduz quadros so se necessario
        if opts.pixelBudget then
            maxFrames = math.max(2, math.min(maxFrames, floor(opts.pixelBudget / (ow * oh))))
        end
        -- step = 1 garante que nenhum quadro e pulado (a menos que pixelBudget force)
        local step = math.max(1, math.ceil(n / maxFrames))
        local xmap, ymap = {}, {}
        for x = 1, ow do xmap[x] = math.min(W, floor((x - 0.5) / scale) + 1) end
        for y = 1, oh do ymap[y] = math.min(H - 1, floor((y - 0.5) / scale)) end

        local total = W * H
        local canvas = tcreate(total, -1)
        local pending = nil
        local pngs, delays = {}, {}
        local acc = 0
        local t0 = os.clock()
        local budget = opts.budget or 240
        local yield = opts.yield
        for k = 1, n do
            if opts.cancelled and opts.cancelled() then error("cancelado", 0) end
            local f = g.frames[k]
            -- descarte do quadro anterior
            if pending then
                if pending.kind == 2 then
                    for y = pending.y, math.min(H, pending.y + pending.h) - 1 do
                        local base = y * W
                        for x = pending.x, math.min(W, pending.x + pending.w) - 1 do
                            canvas[base + x + 1] = -1
                        end
                    end
                elseif pending.kind == 3 and pending.snap then
                    canvas = pending.snap
                end
                pending = nil
            end
            local snap = nil
            if f.disposal == 3 then snap = copyCanvas(canvas, total) end

            local pal = f.pal or g.gpal or {}
            local out = lzw(f.parts, f.minCode, f.w * f.h, yield)
            local rows = rowMap(f.h, f.interlaced)
            local fw, trans = f.w, f.trans
            for sr = 1, f.h do
                local y = f.y + rows[sr]
                if y >= 0 and y < H then
                    local base = (sr - 1) * fw
                    local cb = y * W
                    for x = 0, fw - 1 do
                        local px = f.x + x
                        if px < W then
                            local idx = out[base + x + 1]
                            if idx ~= trans then
                                local v = pal[idx + 1]
                                if v then canvas[cb + px + 1] = v end
                            end
                        end
                    end
                end
            end
            pending = {kind = f.disposal, x = f.x, y = f.y, w = f.w, h = f.h, snap = snap}

            -- amostragem: um quadro a cada `step` (soma os atrasos do grupo)
            if (k - 1) % step == 0 then
                pngs[#pngs + 1] = encodePng(canvas, W, ow, oh, xmap, ymap)
                delays[#pngs] = 0
                acc = #pngs
            end
            if acc > 0 then delays[acc] = delays[acc] + f.delay / 100 end
            if opts.onProg then opts.onProg(k, n) end
            if opts.firstOnly and #pngs >= 1 then break end
            if yield then yield() end
            if os.clock() - t0 > budget and #pngs >= 2 then break end
        end
        return {frames = pngs, delays = delays, w = ow, h = oh, n = n, srcW = W, srcH = H}
    end

    function Gif.decode(data, opts)
        local ok, res = pcall(decodeInner, data, opts or {})
        if ok then return res end
        return nil, tostring(res)
    end

    ---------------------------------------------------------------- cache em disco
    local function ensureDir(sub)
        pcall(function()
            if not isfolder("PHONE") then makefolder("PHONE") end
            if not isfolder(GIF_DIR) then makefolder(GIF_DIR) end
            if sub and not isfolder(GIF_DIR .. "/" .. sub) then makefolder(GIF_DIR .. "/" .. sub) end
        end)
    end

    -- gifName: nome legivel do GIF (ex: "gato_dancando.gif") para pasta amigavel.
    -- A pasta real continua sendo GIF_DIR/key (hash) para evitar colisoes,
    -- mas salvamos o nome em meta.txt para exibicao.
    local assetMemo = {}
    local baking = {}

    local function bakeInner(key, data, opts, gifName)
        local res, err = Gif.decode(data, opts)
        if not res then return nil, err end
        ensureDir(key)
        local dir = GIF_DIR .. "/" .. key
        -- apaga o meta antigo: so existe meta quando TODOS os quadros foram gravados
        pcall(function()
            if isfile(dir .. "/meta.txt") then delfile(dir .. "/meta.txt") end
        end)
        local paths, ds = {}, {}
        for i, png in ipairs(res.frames) do
            local p = dir .. "/" .. key .. "_f" .. i .. ".png"
            assetMemo[p] = nil   -- nunca reutilizar asset antigo do mesmo caminho
            if not pcall(writefile, p, png) then return nil, "writefile indisponivel" end
            paths[i] = p
            ds[i] = string.format("%.3f", res.delays[i])
        end
        -- v5: inclui nome legivel do GIF na 1a linha do meta
        local nameLine = tostring(gifName or key):gsub("[%c\n]", "_")
        pcall(writefile, dir .. "/meta.txt",
            "v5 " .. #data .. " " .. #paths .. " " .. res.w .. " " .. res.h .. " " .. nameLine .. "\n" .. table.concat(ds, ","))
        return {key = key, name = nameLine, dir = dir, paths = paths, delays = res.delays, w = res.w, h = res.h, srcLen = #data}
    end

    -- FIX: trava por chave. Antes, Galeria + "salvar na galeria" podiam decodificar o MESMO
    -- GIF ao mesmo tempo, escrevendo nos mesmos arquivos (e decodificando de novo).
    function Gif.bake(key, data, opts, gifName)
        if baking[key] then
            local t0 = os.clock()
            while baking[key] and os.clock() - t0 < 90 do
                if opts and opts.cancelled and opts.cancelled() then return nil, "cancelado" end
                task.wait(0.1)
            end
            local info = Gif.load(key, #data)
            if info then return info end
            if baking[key] then return nil, "ocupado" end
        end
        baking[key] = true
        local ok, info, err = pcall(bakeInner, key, data, opts, gifName)
        baking[key] = nil
        if not ok then return nil, tostring(info) end
        return info, err
    end

    -- copia quadros ja prontos de outra chave (muito mais rapido que decodificar de novo)
    function Gif.clone(srcKey, dstKey, srcLen, gifName)
        local src = Gif.load(srcKey, srcLen)
        if not src then return nil end
        local already = Gif.load(dstKey, srcLen)
        if already then return already end
        if baking[dstKey] then return nil end
        baking[dstKey] = true
        local result
        local ok = pcall(function()
            ensureDir(dstKey)
            local dir = GIF_DIR .. "/" .. dstKey
            pcall(function()
                if isfile(dir .. "/meta.txt") then delfile(dir .. "/meta.txt") end
            end)
            local paths, ds = {}, {}
            for i, sp in ipairs(src.paths) do
                local okR, png = pcall(readfile, sp)
                if not okR or type(png) ~= "string" then error("ler quadro") end
                local p = dir .. "/" .. dstKey .. "_f" .. i .. ".png"
                assetMemo[p] = nil
                if not pcall(writefile, p, png) then error("gravar quadro") end
                paths[i] = p
                ds[i] = string.format("%.3f", src.delays[i] or 0.1)
                if i % 8 == 0 then task.wait() end
            end
            local nameLine = tostring(gifName or dstKey):gsub("[%c\n]", "_")
            writefile(dir .. "/meta.txt",
                "v5 " .. srcLen .. " " .. #paths .. " " .. src.w .. " " .. src.h .. " " .. nameLine .. "\n" .. table.concat(ds, ","))
            result = {key = dstKey, name = nameLine, dir = dir, paths = paths, delays = src.delays, w = src.w, h = src.h, srcLen = srcLen}
        end)
        baking[dstKey] = nil
        if ok then return result end
        return nil
    end

    function Gif.load(key, expectLen)
        local dir = GIF_DIR .. "/" .. key
        local mp = dir .. "/meta.txt"
        local okF, has = pcall(isfile, mp)
        if not (okF and has) then return nil end
        local okR, txt = pcall(readfile, mp)
        if not okR or type(txt) ~= "string" then return nil end
        -- suporta v4 (sem nome) e v5 (com nome)
        local len, n, w, h, namePart, ds
        len, n, w, h, namePart, ds = txt:match("^v5 (%d+) (%d+) (%d+) (%d+) ([^\n]+)\n(.*)$")
        if not len then
            -- fallback v4
            len, n, w, h, ds = txt:match("^v4 (%d+) (%d+) (%d+) (%d+)\n(.*)$")
            namePart = key
        end
        if not len then return nil end
        len, n = tonumber(len), tonumber(n)
        if expectLen and len ~= expectLen then return nil end
        local paths, delays = {}, {}
        for i = 1, n do paths[i] = dir .. "/" .. key .. "_f" .. i .. ".png" end
        for v in (ds or ""):gmatch("[%d%.]+") do delays[#delays + 1] = tonumber(v) end
        local okA, hasA = pcall(isfile, paths[n])
        if not (okA and hasA) then return nil end
        return {key = key, name = namePart or key, dir = dir, paths = paths, delays = delays, w = tonumber(w), h = tonumber(h), srcLen = len}
    end

    -- miniatura rapida (so o 1o quadro) para a grade da Galeria
    function Gif.thumbPath(key)
        local info = Gif.load(key)
        if info then return info.paths[1] end
        local p = GIF_DIR .. "/" .. key .. "/" .. key .. "_thumb.png"
        local okF, has = pcall(isfile, p)
        if okF and has then return p end
        return nil
    end

    function Gif.makeThumb(key, data, opts)
        opts = opts or {}
        opts.firstOnly = true
        local res = Gif.decode(data, opts)
        if not res or not res.frames[1] then return nil end
        ensureDir(key)
        local p = GIF_DIR .. "/" .. key .. "/" .. key .. "_thumb.png"
        if pcall(writefile, p, res.frames[1]) then return p end
        return nil
    end

    function Gif.asset(path)
        if assetMemo[path] then return assetMemo[path] end
        local ok, a = pcall(getcustomasset, path)
        if ok and type(a) == "string" and a ~= "" then assetMemo[path] = a; return a end
        return nil
    end

    function Gif.assets(info)
        local list = {}
        for i, p in ipairs(info.paths) do
            local a = Gif.asset(p)
            if not a then return nil end
            list[i] = a
        end
        return list
    end

    -- pre-carga com limite de tempo: PreloadAsync pode nunca retornar em alguns executores
    function Gif.preload(assets, timeout)
        local done = false
        task.spawn(function()
            pcall(function() game:GetService("ContentProvider"):PreloadAsync(assets) end)
            done = true
        end)
        local t0 = os.clock()
        while not done and os.clock() - t0 < (timeout or 1.5) do task.wait(0.05) end
    end

    -- Reproducao a 60 Hz (Heartbeat): relogio acumulado + mistura suave entre quadros.
    -- state = {playing = bool, smooth = bool}; `over` = ImageLabel por cima (filho do principal)
    -- FIX: checa cancelled() ANTES de qualquer escrita na imagem para evitar
    -- que um Heartbeat antigo pinte o ImageLabel com o GIF errado.
    -- FIX: so UMA reproducao por ImageLabel. Iniciar um GIF novo derruba o anterior na hora
    -- (antes o Heartbeat velho so morria no proximo frame e podia pintar/limpar o GIF novo).
    local playing = setmetatable({}, {__mode = "k"})
    function Gif.stop(img)
        local s = playing[img]
        if s then
            s.dead = true
            if s.conn then s.conn:Disconnect() end
            if s.cleanup then s.cleanup() end
            playing[img] = nil
        end
    end

    -- FIX (GIF piscando, v2): trocar o .Image de um ImageLabel VISIVEL faz o Roblox desenhar 1 quadro em
    -- branco ate a textura subir pra GPU (e o overlay invisivel nunca desenhava o quadro antes). Agora:
    -- 3 buffers (ImageLabel) por cima da imagem: [atual] [proximo] [seguinte]. Os dois proximos ficam
    -- DESENHADOS com 99% de transparencia (a textura ja esta na GPU) e a troca de quadro e so mudar
    -- transparencia/ZIndex - o .Image de um buffer visivel nunca muda. O modo 60 FPS mistura o atual
    -- com o proximo (fade). So avanca quando o proximo buffer informa IsLoaded (se o executor nao
    -- informar, o controle e desligado sozinho e nunca trava).
    function Gif.play(img, over, assets, delays, cancelled, state)
        local RS = game:GetService("RunService")
        local CP = game:GetService("ContentProvider")
        local n = #assets
        local idx, t = 1, 0
        Gif.stop(img)
        if over then Gif.stop(over); over.Visible = false; over.Image = "" end
        local session = {dead = false}
        playing[img] = session

        local PRE = 0.99
        local bz = img.ZIndex
        local scale = (over or img).ScaleType
        local function mk()
            local l = Instance.new("ImageLabel")
            l.Name = "GifBuf"
            l.BackgroundTransparency = 1
            l.BorderSizePixel = 0
            -- Cada quadro e uma camada absoluta dentro da imagem original.
            -- Assim os quadros nunca entram no fluxo/AutoLayout da pagina e
            -- acompanham exatamente a posicao e o tamanho do <img> original.
            l.AnchorPoint = Vector2.new(0, 0)
            l.Position = UDim2.new(0, 0, 0, 0)
            l.Size = UDim2.new(1, 0, 1, 0)
            l.AutomaticSize = Enum.AutomaticSize.None
            l.ScaleType = scale
            l.ImageTransparency = 1
            l.Image = ""
            l.Parent = img
            return l
        end
        local cur, nxt, nn = mk(), mk(), mk()
        local pool = {cur, nxt, nn}
        local function cleanup()
            for _, l in ipairs(pool) do pcall(function() l:Destroy() end) end
            pool = {}
        end
        session.cleanup = cleanup
        local function frameAt(k) return ((idx - 1 + k) % n) + 1 end
        local function layout()
            cur.ZIndex = bz + 1
            nxt.ZIndex = bz + 2
            nn.ZIndex = bz + 3
        end
        cur.Image = assets[1]
        cur.ImageTransparency = 0
        nxt.Image = assets[frameAt(1)]
        nxt.ImageTransparency = PRE
        nn.Image = assets[frameAt(2)]
        nn.ImageTransparency = PRE
        layout()

        -- aquece o cache em segundo plano (blocos de 6; PreloadAsync pode nunca voltar: limite de 1.2s)
        task.spawn(function()
            local i = 1
            while i <= n and not session.dead do
                local last = math.min(n, i + 5)
                local chunk = {}
                for j = i, last do chunk[#chunk + 1] = assets[j] end
                local done = false
                task.spawn(function()
                    pcall(function() CP:PreloadAsync(chunk) end)
                    done = true
                end)
                local t0 = os.clock()
                while not done and os.clock() - t0 < 1.2 and not session.dead do task.wait(0.03) end
                i = last + 1
            end
        end)

        local clock0 = os.clock()
        local cleared, gateKnown, gateOn, stall = false, false, true, 0
        local conn
        conn = RS.Heartbeat:Connect(function(dt)
            if session.dead then
                conn:Disconnect()
                return
            end
            if cancelled() then
                conn:Disconnect()
                if playing[img] == session then playing[img] = nil end
                cleanup()
                return
            end
            -- quando o buffer ja desenhou o 1o quadro, limpa a imagem base (evita aparecer por tras em GIF com transparencia)
            if not cleared and (cur.IsLoaded or os.clock() - clock0 > 0.5) then
                cleared = true
                img.Image = ""
            end
            -- descobre se este executor informa IsLoaded; se nao informar, nao usa como trava
            if not gateKnown then
                if cur.IsLoaded then
                    gateKnown = true
                elseif os.clock() - clock0 > 1.5 then
                    gateKnown, gateOn = true, false
                end
            end
            if not state.playing then return end
            if dt > 0.25 then dt = 0.25 end
            t = t + dt
            local d = delays[idx] or 0.1
            if d <= 0 then d = 0.1 end
            local changed, guard = false, 0
            while t >= d and guard < n do
                if gateOn and gateKnown and not nxt.IsLoaded then
                    stall = stall + dt
                    if stall < 0.7 then
                        t = d   -- segura o quadro atual ate o proximo estar na GPU (nada de tela em branco)
                        break
                    end
                end
                stall = 0
                t = t - d
                -- gira os buffers: o antigo "atual" vira o "seguinte" (recebe imagem nova ESCONDIDO)
                local old = cur
                cur, nxt, nn = nxt, nn, old
                idx = idx % n + 1
                old.ImageTransparency = 1
                old.Image = assets[frameAt(2)]
                old.ImageTransparency = PRE
                cur.ImageTransparency = 0
                changed = true
                d = delays[idx] or 0.1
                if d <= 0 then d = 0.1 end
                guard = guard + 1
            end
            if guard >= n then t = 0 end
            if session.dead then conn:Disconnect(); return end
            if cancelled() then
                conn:Disconnect()
                if playing[img] == session then playing[img] = nil end
                cleanup()
                return
            end
            if changed then layout() end
            if state.smooth and n > 1 then
                nxt.ImageTransparency = math.min(PRE, 1 - math.clamp(t / d, 0, 1))
            else
                nxt.ImageTransparency = PRE
            end
        end)
        session.conn = conn
        return session
    end

    function Gif.remove(key)
        local dir = GIF_DIR .. "/" .. key
        pcall(function()
            for _, f in ipairs(listfiles(dir)) do
                assetMemo[tostring(f):gsub("\\", "/")] = nil
                pcall(delfile, f)
            end
        end)
        pcall(function() if delfolder then delfolder(dir) end end)
    end

    function Gif.purge(prefix)
        pcall(function()
            for _, d in ipairs(listfiles(GIF_DIR)) do
                local name = tostring(d):gsub("\\", "/"):match("([^/]+)$") or ""
                if name:sub(1, #prefix) == prefix then Gif.remove(name) end
            end
        end)
    end

    return Gif
end)()

local navBars = {}

local function applyNavMode()
    for _, nb in ipairs(navBars) do
        nb.setMode(phoneSettings.gestureNav and "gesture" or "buttons")
    end
end

local function createNavBar(parent)
    local nb = {}

    local bar = Instance.new("Frame")
    bar.Name = "NavBar"
    bar.Size = UDim2.new(1, -20, 0, 30)
    bar.Position = UDim2.new(0, 10, 1, -38)
    bar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bar.BackgroundTransparency = 0.35
    bar.BorderSizePixel = 0
    bar.ZIndex = 20
    bar.Parent = parent
    corner(bar, UDim.new(0, 15))

    local barStroke = Instance.new("UIStroke")
    barStroke.Color = WHITE
    barStroke.Transparency = 0.88
    barStroke.Thickness = 1
    barStroke.Parent = bar

    local buttons = {}
    local function makeBtn(name, xScale, iconFn, action)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.BackgroundTransparency = 1
        btn.AnchorPoint = Vector2.new(0.5, 0.5)
        btn.Position = UDim2.new(xScale, 0, 0.5, 0)
        btn.Size = UDim2.new(0, 56, 0, 30)
        btn.ZIndex = 21
        btn.Parent = bar

        local ripple = Instance.new("Frame")
        ripple.Name = "Ripple"
        ripple.AnchorPoint = Vector2.new(0.5, 0.5)
        ripple.Position = UDim2.new(0.5, 0, 0.5, 0)
        ripple.Size = UDim2.new(0, 20, 0, 20)
        ripple.BackgroundColor3 = WHITE
        ripple.BackgroundTransparency = 1
        ripple.BorderSizePixel = 0
        ripple.ZIndex = 21
        ripple.Parent = btn
        corner(ripple, UDim.new(1, 0))

        local icon = iconFn(btn, 16, WHITE, 22)
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position = UDim2.new(0.5, 0, 0.5, 0)

        btn.MouseButton1Down:Connect(function()
            TweenService:Create(ripple, TweenInfo.new(0.1), {BackgroundTransparency = 0.82, Size = UDim2.new(0, 30, 0, 30)}):Play()
        end)
        local function release()
            TweenService:Create(ripple, TweenInfo.new(0.22), {BackgroundTransparency = 1, Size = UDim2.new(0, 20, 0, 20)}):Play()
        end
        btn.MouseButton1Up:Connect(release)
        btn.MouseLeave:Connect(release)
        btn.MouseButton1Click:Connect(function() action() end)

        table.insert(buttons, btn)
        return btn, icon
    end

    local _, backIcon = makeBtn("BackBtn", 0.2, Icons.back, function() Nav.back() end)
    makeBtn("HomeBtn", 0.5, Icons.home, function() Nav.home() end)
    makeBtn("RecentsBtn", 0.8, Icons.recents, function() Nav.recents() end)

    local pill = Instance.new("Frame")
    pill.Name = "GesturePill"
    pill.AnchorPoint = Vector2.new(0.5, 0.5)
    pill.Position = UDim2.new(0.5, 0, 0.5, 0)
    pill.Size = UDim2.new(0, 92, 0, 5)
    pill.BackgroundColor3 = WHITE
    pill.BackgroundTransparency = 0.1
    pill.BorderSizePixel = 0
    pill.ZIndex = 22
    pill.Visible = false
    pill.Parent = bar
    corner(pill, UDim.new(1, 0))

    local hit = Instance.new("TextButton")
    hit.Name = "GestureHit"
    hit.Text = ""
    hit.AutoButtonColor = false
    hit.BackgroundTransparency = 1
    hit.Size = UDim2.new(1, 0, 1, 0)
    hit.ZIndex = 23
    hit.Visible = false
    hit.Parent = bar

    local gActive, gStart, gLastMove = false, nil, 0
    local function isPress(i)
        return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
    end
    local function isMove(i)
        return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
    end

    hit.InputBegan:Connect(function(i)
        if isPress(i) then
            gActive = true
            gStart = i.Position
            gLastMove = os.clock()
        end
    end)
    hit.InputChanged:Connect(function(i)
        if gActive and isMove(i) then
            local dy = math.clamp(i.Position.Y - gStart.Y, -34, 0)
            pill.Position = UDim2.new(0.5, 0, 0.5, dy)
            gLastMove = os.clock()
        end
    end)
    hit.InputEnded:Connect(function(i)
        if gActive and isPress(i) then
            gActive = false
            TweenService:Create(pill, TweenInfo.new(0.15), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
            local dx, dy = i.Position.X - gStart.X, i.Position.Y - gStart.Y
            if dy < -26 and math.abs(dy) > math.abs(dx) then

                if os.clock() - gLastMove > 0.35 then Nav.recents() else Nav.home() end
            elseif math.abs(dx) > 36 and math.abs(dx) > math.abs(dy) then
                Nav.back()
            end
        end
    end)

    function nb.setMode(mode)
        local g = (mode == "gesture")
        bar.BackgroundTransparency = g and 1 or 0.35
        barStroke.Enabled = not g
        for _, b in ipairs(buttons) do b.Visible = not g end
        pill.Visible = g
        hit.Visible = g
    end

    function nb.setBackEnabled(on)
        Icons.setColor(backIcon, on and WHITE or Color3.fromRGB(110, 110, 120))
    end

    table.insert(navBars, nb)
    nb.setMode(phoneSettings.gestureNav and "gesture" or "buttons")
    nb.setBackEnabled(false)
    return nb
end

Nav.status = {bars = {}, fps = 0, t0 = os.clock(), running = false}

do
    local SB = Nav.status
    local C_OK, C_WARN, C_BAD = Color3.fromRGB(50, 205, 50), Color3.fromRGB(255, 170, 0), Color3.fromRGB(255, 85, 85)
    local C_OFF = Color3.fromRGB(90, 90, 104)
    local TI_FAST = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local function tween(obj, info, props)
        TweenService:Create(obj, info, props):Play()
    end

    local function fpsColor(n)
        if n >= 50 then return C_OK elseif n >= 30 then return C_WARN end
        return C_BAD
    end

    local function signalLevel()
        local ok, ping = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if not ok or type(ping) ~= "number" or ping <= 0 then return 4 end
        if ping < 100 then return 4 elseif ping < 180 then return 3 elseif ping < 300 then return 2 end
        return 1
    end

    local function batteryLevel()
        return math.max(5, 100 - math.floor((os.clock() - SB.t0) / 90))
    end

    local function txt(parent, name, pos, size, text, ts, align)
        local l = Instance.new("TextLabel")
        l.Name = name
        l.BackgroundTransparency = 1
        l.Position = pos
        l.Size = size
        l.Text = text
        l.TextColor3 = WHITE
        l.Font = Enum.Font.GothamBold
        l.TextSize = ts
        l.TextXAlignment = align
        l.ZIndex = 51
        l.Parent = parent
        return l
    end

    function SB.create(parent)
        local sb = {}

        local bar = Instance.new("Frame")
        bar.Name = "StatusBar"
        bar.Size = UDim2.new(1, 0, 0, 24)
        bar.Position = UDim2.new(0, 0, 0, 9)
        bar.BackgroundTransparency = 1
        bar.BorderSizePixel = 0
        bar.ZIndex = 50
        bar.Parent = parent
        sb.bar = bar

        local clock = txt(bar, "Clock", UDim2.new(0, 14, 0, 0), UDim2.new(0, 40, 1, 0), os.date("%H:%M"), 12, Enum.TextXAlignment.Left)

        local pill = Instance.new("Frame")
        pill.Name = "FPSPill"
        pill.Size = UDim2.new(0, 32, 0, 14)
        pill.Position = UDim2.new(0, 53, 0.5, -7)
        pill.BackgroundColor3 = Color3.new(0, 0, 0)
        pill.BackgroundTransparency = 0.35
        pill.BorderSizePixel = 0
        pill.ZIndex = 51
        pill.Visible = phoneSettings.fpsEnabled == true
        pill.Parent = bar
        corner(pill, UDim.new(1, 0))
        local pillStroke = Instance.new("UIStroke")
        pillStroke.Color = C_OK
        pillStroke.Thickness = 1
        pillStroke.Transparency = 0.25
        pillStroke.Parent = pill
        local fpsText = txt(pill, "FPSText", UDim2.new(0, 2, 0, 0), UDim2.new(1, -4, 1, 0), "--fps", 9, Enum.TextXAlignment.Center)
        fpsText.TextScaled = true
        fpsText.TextColor3 = C_OK
        fpsText.ZIndex = 52
        local tsc = Instance.new("UITextSizeConstraint")
        tsc.MaxTextSize = 9
        tsc.MinTextSize = 5
        tsc.Parent = fpsText

        local sig = Instance.new("Frame")
        sig.Name = "Signal"
        sig.Size = UDim2.new(0, 14, 0, 10)
        sig.Position = UDim2.new(1, -88, 0.5, -5)
        sig.BackgroundTransparency = 1
        sig.ZIndex = 51
        sig.Parent = bar
        local sigBars, heights = {}, {3, 5, 7, 10}
        for i, h in ipairs(heights) do
            local b = Instance.new("Frame")
            b.Name = "Bar" .. i
            b.Size = UDim2.new(0, 2, 0, h)
            b.Position = UDim2.new(0, (i - 1) * 4, 0, 10 - h)
            b.BackgroundColor3 = WHITE
            b.BorderSizePixel = 0
            b.ZIndex = 52
            b.Parent = sig
            corner(b, UDim.new(0, 1))
            sigBars[i] = b
        end

        local pct = txt(bar, "BatteryPct", UDim2.new(1, -68, 0, 0), UDim2.new(0, 26, 1, 0), "100", 10, Enum.TextXAlignment.Right)

        local bat = Instance.new("Frame")
        bat.Name = "Battery"
        bat.Size = UDim2.new(0, 24, 0, 10)
        bat.Position = UDim2.new(1, -38, 0.5, -5)
        bat.BackgroundTransparency = 1
        bat.ZIndex = 51
        bat.Parent = bar
        local body = Instance.new("Frame")
        body.Name = "Body"
        body.Size = UDim2.new(0, 20, 0, 10)
        body.BackgroundTransparency = 1
        body.BorderSizePixel = 0
        body.ZIndex = 51
        body.Parent = bat
        corner(body, UDim.new(0, 3))
        local bodyStroke = Instance.new("UIStroke")
        bodyStroke.Color = WHITE
        bodyStroke.Transparency = 0.45
        bodyStroke.Thickness = 1
        bodyStroke.Parent = body
        local cap = Instance.new("Frame")
        cap.Name = "Cap"
        cap.Size = UDim2.new(0, 2, 0, 4)
        cap.Position = UDim2.new(0, 21, 0, 3)
        cap.BackgroundColor3 = WHITE
        cap.BackgroundTransparency = 0.45
        cap.BorderSizePixel = 0
        cap.ZIndex = 51
        cap.Parent = bat
        corner(cap, UDim.new(0, 1))
        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.Size = UDim2.new(0, 16, 0, 6)
        fill.Position = UDim2.new(0, 2, 0, 2)
        fill.BackgroundColor3 = C_OK
        fill.BorderSizePixel = 0
        fill.ZIndex = 52
        fill.Parent = body
        corner(fill, UDim.new(0, 2))

        local lastSig, lastBat, blink = -1, -1, false
        function sb.refresh()
            clock.Text = os.date("%H:%M")

            local s = signalLevel()
            if s ~= lastSig then
                lastSig = s
                for i, b in ipairs(sigBars) do
                    tween(b, TI_FAST, {BackgroundColor3 = (i <= s) and (s == 1 and C_BAD or WHITE) or C_OFF})
                end
            end

            local lvl = batteryLevel()
            if lvl ~= lastBat then
                lastBat = lvl
                pct.Text = tostring(lvl)
                local col = lvl <= 15 and C_BAD or (lvl <= 30 and C_WARN or C_OK)
                tween(fill, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
                    Size = UDim2.new(0, math.max(1, math.floor(16 * lvl / 100 + 0.5)), 0, 6),
                    BackgroundColor3 = col,
                })
            end
            if lastBat <= 15 then
                blink = not blink
                tween(fill, TweenInfo.new(0.45), {BackgroundTransparency = blink and 0.65 or 0})
            elseif fill.BackgroundTransparency ~= 0 then
                fill.BackgroundTransparency = 0
            end
        end

        function sb.setFps(n)
            local on = phoneSettings.fpsEnabled == true
            pill.Visible = on
            if not on then return end
            fpsText.Text = (n > 0 and tostring(n) or "--") .. "fps"
            local col = fpsColor(n)
            tween(fpsText, TI_FAST, {TextColor3 = col})
            tween(pillStroke, TI_FAST, {Color = col})
        end

        parent:GetPropertyChangedSignal("Visible"):Connect(function()
            if parent.Visible then
                sb.refresh()
                bar.Position = UDim2.new(0, 0, 0, 2)
                clock.TextTransparency = 1
                pct.TextTransparency = 1
                tween(bar, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 9)})
                tween(clock, TI_FAST, {TextTransparency = 0})
                tween(pct, TI_FAST, {TextTransparency = 0})
            end
        end)

        table.insert(SB.bars, sb)
        sb.refresh()
        sb.setFps(SB.fps)

        if not SB.running then
            SB.running = true
            task.spawn(function()
                while #SB.bars > 0 do
                    for i = #SB.bars, 1, -1 do
                        local b = SB.bars[i]
                        if b.bar.Parent then b.refresh() else table.remove(SB.bars, i) end
                    end
                    task.wait(1)
                end
                SB.running = false
            end)
        end
        return sb
    end

    function SB.setFps(n)
        SB.fps = n
        for _, b in ipairs(SB.bars) do b.setFps(n) end
    end

    function SB.applyFps()
        SB.setFps(SB.fps)
    end
end

Nav.shell = {list = {}, order = {"titanio", "grafite", "prata", "azul", "verde"}}

do
    local SH = Nav.shell
    local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

    SH.themes = {
        titanio = {label = "Titânio", metal = {rgb(222, 217, 206), rgb(152, 147, 138), rgb(86, 83, 78)}},
        grafite = {label = "Grafite", metal = {rgb(120, 122, 130), rgb(58, 60, 66), rgb(24, 25, 29)}},
        prata   = {label = "Prata",   metal = {rgb(244, 244, 248), rgb(182, 184, 192), rgb(122, 124, 132)}},
        azul    = {label = "Azul",    metal = {rgb(138, 176, 230), rgb(70, 106, 170), rgb(32, 52, 98)}},
        verde   = {label = "Verde TZE", metal = {rgb(110, 240, 110), rgb(50, 205, 50), rgb(22, 105, 34)}},
    }
    SH.current = SH.themes[phoneSettings.caseTheme] and phoneSettings.caseTheme or "titanio"

    local function metalSeq(t)
        local l, m, d = t.metal[1], t.metal[2], t.metal[3]
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, l), ColorSequenceKeypoint.new(0.28, m),
            ColorSequenceKeypoint.new(0.5, d), ColorSequenceKeypoint.new(0.72, m),
            ColorSequenceKeypoint.new(1, l),
        })
    end

    function SH.create(frame)
        local s = {btnGrads = {}}

        local function ring(name, inset, shift, radius, thick, color, trans, z)
            local f = Instance.new("Frame")
            f.Name = name
            f.BackgroundTransparency = 1
            f.BorderSizePixel = 0
            f.Position = UDim2.new(0, -inset, 0, -inset + shift)
            f.Size = UDim2.new(1, inset * 2, 1, inset * 2)
            f.ZIndex = z
            f.Parent = frame
            corner(f, UDim.new(0, radius))
            local st = Instance.new("UIStroke")
            st.Color = color
            st.Thickness = thick
            st.Transparency = trans
            st.Parent = f
            return f, st
        end

        ring("Shadow1", 11, 6, 39, 6, Color3.new(0, 0, 0), 0.90, 0)
        ring("Shadow2", 17, 7, 45, 8, Color3.new(0, 0, 0), 0.94, 0)
        ring("Shadow3", 25, 8, 53, 10, Color3.new(0, 0, 0), 0.97, 0)

        ring("Bezel", 0, 0, 28, 6, rgb(6, 6, 8), 0, 1)

        local _, chassisStroke = ring("Chassis", 6, 0, 34, 4, WHITE, 0, 2)
        s.chassisGrad = Instance.new("UIGradient")
        s.chassisGrad.Rotation = 45
        s.chassisGrad.Parent = chassisStroke

        ring("EdgeLight", 10, 0, 38, 1, WHITE, 0.72, 3)

        local function sideButton(name, left, y, h, action, repeating)
            local hit = Instance.new("TextButton")
            hit.Name = name
            hit.Text = ""
            hit.AutoButtonColor = false
            hit.BackgroundTransparency = 1
            hit.BorderSizePixel = 0
            hit.Size = UDim2.new(0, 14, 0, h)
            hit.Position = left and UDim2.new(0, -24, 0, y) or UDim2.new(1, 10, 0, y)
            hit.ZIndex = 1
            hit.Parent = frame

            local restPos = left and UDim2.new(0, 10, 0, 0) or UDim2.new(0, 0, 0, 0)
            local downPos = left and UDim2.new(0, 12, 0, 0) or UDim2.new(0, -2, 0, 0)
            local piece = Instance.new("Frame")
            piece.Name = "Piece"
            piece.BackgroundColor3 = WHITE
            piece.BorderSizePixel = 0
            piece.Size = UDim2.new(0, 4, 1, 0)
            piece.Position = restPos
            piece.ZIndex = 1
            piece.Parent = hit
            corner(piece, UDim.new(0, 2))
            local g = Instance.new("UIGradient")
            g.Rotation = 0
            g.Parent = piece
            table.insert(s.btnGrads, g)

            local holdId = 0
            hit.MouseButton1Down:Connect(function()
                TweenService:Create(piece, TweenInfo.new(0.08), {Position = downPos}):Play()
                holdId = holdId + 1
                local my = holdId
                if action then action() end
                if repeating then
                    task.spawn(function()
                        task.wait(0.4)
                        while holdId == my do
                            action()
                            task.wait(0.12)
                        end
                    end)
                end
            end)
            local function release()
                holdId = holdId + 1
                TweenService:Create(piece, TweenInfo.new(0.18, Enum.EasingStyle.Back), {Position = restPos}):Play()
            end
            hit.MouseButton1Up:Connect(release)
            hit.MouseLeave:Connect(release)
        end
        sideButton("ActionButton", true, 78, 18)
        sideButton("VolUpButton", true, 118, 34, function() if SH.volumeUp then SH.volumeUp() end end, true)
        sideButton("VolDownButton", true, 160, 34, function() if SH.volumeDown then SH.volumeDown() end end, true)
        sideButton("PowerButton", false, 140, 56)

        local island = Instance.new("Frame")
        island.Name = "Island"
        island.AnchorPoint = Vector2.new(0.5, 0)
        island.Position = UDim2.new(0.5, 0, 0, 9)
        island.Size = UDim2.new(0, 82, 0, 24)
        island.BackgroundColor3 = Color3.new(0, 0, 0)
        island.BorderSizePixel = 0
        island.ZIndex = 55
        island.Parent = frame
        corner(island, UDim.new(1, 0))

        local function dot(name, x, size, color, strokeColor)
            local d = Instance.new("Frame")
            d.Name = name
            d.Size = UDim2.new(0, size, 0, size)
            d.Position = UDim2.new(0, x, 0.5, -size / 2)
            d.BackgroundColor3 = color
            d.BorderSizePixel = 0
            d.ZIndex = 56
            d.Parent = island
            corner(d, UDim.new(1, 0))
            if strokeColor then
                local st = Instance.new("UIStroke")
                st.Color = strokeColor
                st.Thickness = 1
                st.Parent = d
            end
            return d
        end
        dot("Sensor", 14, 5, rgb(22, 22, 28))
        local lens = dot("Lens", 62, 11, rgb(12, 16, 34), rgb(34, 44, 80))
        local inner = dot("LensCore", 3, 5, rgb(24, 40, 92))
        inner.Parent = lens
        inner.Position = UDim2.new(0.5, -2.5, 0.5, -2.5)
        local glint = dot("LensGlint", 2, 2, WHITE)
        glint.Parent = lens
        glint.Position = UDim2.new(0, 2, 0, 2)
        glint.BackgroundTransparency = 0.25

        local glare = Instance.new("Frame")
        glare.Name = "Glare"
        glare.Size = UDim2.new(1, 0, 1, 0)
        glare.BackgroundTransparency = 1
        glare.BorderSizePixel = 0
        glare.ClipsDescendants = true
        glare.ZIndex = 46
        glare.Parent = frame
        corner(glare, UDim.new(0, 28))
        local band = Instance.new("Frame")
        band.AnchorPoint = Vector2.new(0.5, 0.5)
        band.Size = UDim2.new(0, 64, 1.8, 0)
        band.Position = UDim2.new(-0.3, 0, 0.5, 0)
        band.Rotation = 18
        band.BackgroundColor3 = WHITE
        band.BorderSizePixel = 0
        band.ZIndex = 46
        band.Parent = glare
        local bg = Instance.new("UIGradient")
        bg.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.88), NumberSequenceKeypoint.new(1, 1),
        })
        bg.Parent = band

        local hudClip = Instance.new("Frame")
        hudClip.Name = "VolumeHUDClip"
        hudClip.Size = UDim2.new(1, 0, 1, 0)
        hudClip.BackgroundTransparency = 1
        hudClip.BorderSizePixel = 0
        hudClip.ClipsDescendants = true
        hudClip.ZIndex = 58
        hudClip.Parent = frame
        corner(hudClip, UDim.new(0, 28))

        local hud = Instance.new("Frame")
        hud.Name = "VolumeHUD"
        hud.Size = UDim2.new(0, 30, 0, 132)
        hud.Position = UDim2.new(0, -40, 0.5, -66)
        hud.BackgroundColor3 = rgb(22, 22, 26)
        hud.BackgroundTransparency = 0.12
        hud.BorderSizePixel = 0
        hud.Visible = false
        hud.ZIndex = 58
        hud.Parent = hudClip
        corner(hud, UDim.new(0, 15))
        local hudStroke = Instance.new("UIStroke")
        hudStroke.Color = WHITE
        hudStroke.Transparency = 0.85
        hudStroke.Thickness = 1
        hudStroke.Parent = hud

        local hudPct = Instance.new("TextLabel")
        hudPct.BackgroundTransparency = 1
        hudPct.Position = UDim2.new(0, 0, 0, 5)
        hudPct.Size = UDim2.new(1, 0, 0, 14)
        hudPct.Font = Enum.Font.GothamBold
        hudPct.TextSize = 10
        hudPct.TextColor3 = WHITE
        hudPct.Text = "100"
        hudPct.ZIndex = 59
        hudPct.Parent = hud

        local track = Instance.new("Frame")
        track.Position = UDim2.new(0, 6, 0, 24)
        track.Size = UDim2.new(1, -12, 0, 78)
        track.BackgroundColor3 = WHITE
        track.BackgroundTransparency = 0.85
        track.BorderSizePixel = 0
        track.ClipsDescendants = true
        track.ZIndex = 59
        track.Parent = hud
        corner(track, UDim.new(0, 9))
        local hudFill = Instance.new("Frame")
        hudFill.AnchorPoint = Vector2.new(0, 1)
        hudFill.Position = UDim2.new(0, 0, 1, 0)
        hudFill.Size = UDim2.new(1, 0, 1, 0)
        hudFill.BackgroundColor3 = WHITE
        hudFill.BorderSizePixel = 0
        hudFill.ZIndex = 60
        hudFill.Parent = track

        local hudIcon = Icons.volUp(hud, 18, WHITE, 60)
        hudIcon.Position = UDim2.new(0.5, -9, 0, 108)

        local hideId = 0
        function s.showVolume(v)
            hudPct.Text = tostring(math.floor(v * 100 + 0.5))
            TweenService:Create(hudFill, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Size = UDim2.new(1, 0, v, 0)}):Play()
            if not hud.Visible then
                hud.Position = UDim2.new(0, -40, 0.5, -66)
                hud.Visible = true
            end
            TweenService:Create(hud, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {Position = UDim2.new(0, 10, 0.5, -66)}):Play()
            hideId = hideId + 1
            local my = hideId
            task.delay(1.4, function()
                if hideId ~= my then return end
                TweenService:Create(hud, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                    {Position = UDim2.new(0, -40, 0.5, -66)}):Play()
                task.delay(0.27, function()
                    if hideId == my then hud.Visible = false end
                end)
            end)
        end

        function s.apply(name)
            local t = SH.themes[name]
            if not t then return end
            s.chassisGrad.Color = metalSeq(t)
            for _, g in ipairs(s.btnGrads) do
                g.Color = ColorSequence.new(t.metal[1], t.metal[3])
            end
        end
        s.apply(SH.current)

        frame:GetPropertyChangedSignal("Visible"):Connect(function()
            if not frame.Visible then return end
            island.Size = UDim2.new(0, 82, 0, 24)
            TweenService:Create(island, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {Size = UDim2.new(0, 102, 0, 27)}):Play()
            task.delay(0.55, function()
                TweenService:Create(island, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {Size = UDim2.new(0, 82, 0, 24)}):Play()
            end)
            band.Position = UDim2.new(-0.3, 0, 0.5, 0)
            TweenService:Create(band, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                {Position = UDim2.new(1.3, 0, 0.5, 0)}):Play()
        end)

        table.insert(SH.list, s)
        return s
    end

    function SH.showVolume(v)
        for _, s in ipairs(SH.list) do s.showVolume(v) end
    end

    function SH.label()
        return SH.themes[SH.current].label
    end

    function SH.setTheme(name)
        if not SH.themes[name] then return end
        SH.current = name
        phoneSettings.caseTheme = name
        saveSettings()
        for _, s in ipairs(SH.list) do s.apply(name) end
    end

    function SH.nextTheme()
        local idx = 1
        for i, n in ipairs(SH.order) do
            if n == SH.current then idx = i break end
        end
        SH.setTheme(SH.order[idx % #SH.order + 1])
        return SH.label()
    end
end

destroyOld("TzeCustomHotbar")

do

local HotbarGui = Instance.new("ScreenGui")
HotbarGui.Name = "TzeCustomHotbar"
HotbarGui.ResetOnSpawn = false
HotbarGui.IgnoreGuiInset = true
HotbarGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
HotbarGui.Parent = GUI_PARENT

HotbarFrame = Instance.new("Frame")
HotbarFrame.Name = "HotbarFrame"
HotbarFrame.Size = UDim2.new(0, 48, 0, 40)
local savedHotbar = phoneSettings.hotbarPosition or defaultSettings.hotbarPosition
HotbarFrame.Position = UDim2.new(savedHotbar.X, savedHotbar.XOffset, savedHotbar.Y, savedHotbar.YOffset)
HotbarFrame.BackgroundTransparency = 1
HotbarFrame.Parent = HotbarGui

hotbarUIScale = Instance.new("UIScale")
hotbarUIScale.Parent = HotbarFrame
local function updateHotbarScale()
    local cam = Workspace.CurrentCamera
    if cam then
        local size = cam.ViewportSize
        local baseScale = math.clamp(math.min(size.X / 800, size.Y / 500), 0.75, 1.35)
        if isTouchDevice then
            baseScale = math.clamp(baseScale * 1.25, 0.9, 1.6)
        end
        hotbarUIScale.Scale = baseScale
    end
end
updateHotbarScale()
if Workspace.CurrentCamera then
    Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateHotbarScale)
end

phoneSlot = Instance.new("TextButton")
phoneSlot.Name = "Slot_Phone"
phoneSlot.Size = UDim2.new(0, 36, 0, 36)
phoneSlot.Position = UDim2.new(0, 6, 0, 2)
phoneSlot.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
phoneSlot.BorderSizePixel = 0
phoneSlot.Text = ""
phoneSlot.AutoButtonColor = false
phoneSlot.Parent = HotbarFrame
Instance.new("UICorner", phoneSlot).CornerRadius = UDim.new(0, 10)

local slotStroke = Instance.new("UIStroke")
slotStroke.Color = Color3.fromRGB(50, 205, 50)
slotStroke.Thickness = 2.5
slotStroke.Parent = phoneSlot

local slotIcon = Icons.phone(phoneSlot, 22, Color3.new(1, 1, 1), 3)
slotIcon.AnchorPoint = Vector2.new(0.5, 0.5)
slotIcon.Position = UDim2.new(0.5, 0, 0.5, 0)

selectedFrame = Instance.new("Frame")
selectedFrame.Name = "Selected"
selectedFrame.Size = UDim2.new(1, 0, 1, 0)
selectedFrame.BackgroundTransparency = 1
selectedFrame.Visible = false
selectedFrame.Parent = phoneSlot
local selStroke = Instance.new("UIStroke")
selStroke.Color = Color3.fromRGB(50, 205, 50)
selStroke.Thickness = 1.5
selStroke.Parent = selectedFrame
Instance.new("UICorner", selectedFrame).CornerRadius = UDim.new(0, 10)
end

destroyOld("TzeMusicSystem")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TzeMusicSystem"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = GUI_PARENT

local phoneUIScale = Instance.new("UIScale")
phoneUIScale.Parent = ScreenGui
local function updatePhoneScale()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local size = cam.ViewportSize
    local scale = math.clamp(math.min(size.X / 380, size.Y / 620), 0.55, 1.25)
    if isTouchDevice then
        scale = math.clamp(scale * 1.05, 0.6, 1.35)
    end
    phoneUIScale.Scale = scale
end
updatePhoneScale()
if Workspace.CurrentCamera then
    Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updatePhoneScale)
end

local currentSound = nil
local isPaused = false
local currentMode = "File"
local mp3List = {}
local filteredList = {}
local currentTrackIndex = 0
local shuffleMode = false
local repeatMode = false
local isInPhotoViewer = false
local currentPhotoIndex = 0
local photoList = {}
local filteredPhotoList = {}

do
PhoneHome = Instance.new("Frame")
PhoneHome.Name = "PhoneHome"
PhoneHome.Size = UDim2.new(0, 280, 0, 440)
local savedPos = phoneSettings.phonePosition
PhoneHome.Position = UDim2.new(savedPos.X, savedPos.XOffset, savedPos.Y, savedPos.YOffset)
PhoneHome.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
PhoneHome.BorderSizePixel = 0
PhoneHome.Visible = false
PhoneHome.Active = true
PhoneHome.Draggable = false
PhoneHome.Parent = ScreenGui
Instance.new("UICorner", PhoneHome).CornerRadius = UDim.new(0, 28)

homeBg = Instance.new("ImageLabel")
homeBg.Name = "Wallpaper"
homeBg.Size = UDim2.new(1, 0, 1, 0)
homeBg.BackgroundTransparency = 1
homeBg.Image = currentWallpaper
homeBg.ScaleType = Enum.ScaleType.Crop
homeBg.ZIndex = 1
homeBg.Parent = PhoneHome
Instance.new("UICorner", homeBg).CornerRadius = UDim.new(0, 28)

local homeOverlay = Instance.new("Frame")
homeOverlay.Size = UDim2.new(1, 0, 1, 0)
homeOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
homeOverlay.BackgroundTransparency = 0.62
homeOverlay.BorderSizePixel = 0
homeOverlay.ZIndex = 2
homeOverlay.Parent = PhoneHome
Instance.new("UICorner", homeOverlay).CornerRadius = UDim.new(0, 28)

Nav.shell.create(PhoneHome)

Nav.status.create(PhoneHome)

local pagerClip = Instance.new("Frame")
pagerClip.Name = "PagerClip"
pagerClip.Size = UDim2.new(1, 0, 1, 0)
pagerClip.BackgroundTransparency = 1
pagerClip.ClipsDescendants = true
pagerClip.ZIndex = 5
pagerClip.Parent = PhoneHome
local pager = Instance.new("Frame")
pager.Name = "Pager"
pager.Size = UDim2.new(2, 0, 1, 0)
pager.BackgroundTransparency = 1
pager.ZIndex = 5
pager.Parent = pagerClip
local homePage1 = Instance.new("Frame")
homePage1.Name = "Page1"
homePage1.Size = UDim2.new(0.5, 0, 1, 0)
homePage1.BackgroundTransparency = 1
homePage1.ZIndex = 5
homePage1.Parent = pager
local homePage2 = Instance.new("Frame")
homePage2.Name = "Page2"
homePage2.Position = UDim2.new(0.5, 0, 0, 0)
homePage2.Size = UDim2.new(0.5, 0, 1, 0)
homePage2.BackgroundTransparency = 1
homePage2.ZIndex = 5
homePage2.Parent = pager

local homeW = Instance.new("Frame")
homeW.Name = "HomeWidget"
homeW.Size = UDim2.new(1, -24, 0, 100)
homeW.Position = UDim2.new(0, 12, 0, 44)
homeW.BackgroundColor3 = Color3.new(1, 1, 1)
homeW.BackgroundTransparency = 0.8
homeW.BorderSizePixel = 0
homeW.ZIndex = 5
homeW.Parent = homePage1
Instance.new("UICorner", homeW).CornerRadius = UDim.new(0, 22)
do
    local st = Instance.new("UIStroke", homeW)
    st.Color = Color3.new(1, 1, 1)
    st.Transparency = 0.8
    st.Thickness = 1
end

local function homeLabel(pos, size, txt, ts, font, col)
    local l = Instance.new("TextLabel")
    l.Position = pos
    l.Size = size
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = col
    l.Font = font
    l.TextSize = ts
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 6
    l.Parent = homeW
    return l
end
local hwTime = homeLabel(UDim2.new(0, 16, 0, 8), UDim2.new(1, -32, 0, 52), "00:00", 46, Enum.Font.GothamBold, Color3.new(1, 1, 1))
local hwDay = homeLabel(UDim2.new(0, 18, 0, 62), UDim2.new(1, -32, 0, 14), "", 11, Enum.Font.GothamBold, Color3.fromRGB(255, 130, 120))
local hwDate = homeLabel(UDim2.new(0, 18, 0, 77), UDim2.new(1, -32, 0, 16), "", 12, Enum.Font.Gotham, Color3.fromRGB(235, 235, 240))

do
    local WD = {"domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"}
    local MO = {"janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"}
    local function updateHomeClock()
        local t = os.date("*t")
        hwTime.Text = string.format("%02d:%02d", t.hour, t.min)
        hwDay.Text = WD[t.wday]
        hwDate.Text = t.day .. " de " .. MO[t.month] .. " de " .. t.year
    end
    pcall(updateHomeClock)
    task.spawn(function()
        while PhoneHome.Parent do
            task.wait(5)
            pcall(updateHomeClock)
        end
    end)
end

local appsContainer = Instance.new("Frame")
appsContainer.Name = "AppGrid"
appsContainer.Size = UDim2.new(1, 0, 1, 0)
appsContainer.BorderSizePixel = 0
appsContainer.Position = UDim2.new(0, 0, 0, 0)
appsContainer.BackgroundTransparency = 1
appsContainer.ZIndex = 5
appsContainer.Parent = homePage1

local dockFrame = Instance.new("Frame")
dockFrame.Name = "Dock"
dockFrame.Size = UDim2.new(1, -20, 0, 66)
dockFrame.Position = UDim2.new(0, 10, 0, 328)
dockFrame.BackgroundColor3 = Color3.new(1, 1, 1)
dockFrame.BackgroundTransparency = 0.78
dockFrame.BorderSizePixel = 0
dockFrame.ZIndex = 5
dockFrame.Parent = PhoneHome
Instance.new("UICorner", dockFrame).CornerRadius = UDim.new(0, 24)
do
    local st = Instance.new("UIStroke", dockFrame)
    st.Color = Color3.new(1, 1, 1)
    st.Transparency = 0.8
    st.Thickness = 1
end

Nav.homeSlot = function(i)
    local col = (i - 1) % 4
    local row = math.floor((i - 1) / 4)
    return UDim2.new(0, 12 + col * 64, 0, 160 + row * 84)
end
Nav.dockSlot = function(i)
    return UDim2.new(0, 2 + (i - 1) * 64, 0, 6)
end

local function createAppIcon(name, drawIcon, color, pos, parent, noLabel)
    local icon = Instance.new("TextButton")
    icon.Size = UDim2.new(0, 64, 0, noLabel and 54 or 76)
    icon.Position = pos
    icon.BackgroundTransparency = 1
    icon.Text = ""
    icon.AutoButtonColor = false
    icon.ZIndex = 6
    icon.Parent = parent or appsContainer

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 54, 0, 54)
    bg.Position = UDim2.new(0.5, -27, 0, 0)
    bg.BackgroundColor3 = color
    bg.BorderSizePixel = 0
    bg.ZIndex = 6
    bg.Parent = icon
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 13)

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.28), color:Lerp(Color3.new(0, 0, 0), 0.12))
    grad.Rotation = 90
    grad.Parent = bg
    local ic = drawIcon(bg, 32, Color3.new(1, 1, 1), 8)
    ic.Position = UDim2.new(0.5, -16, 0.5, -16)

    if not noLabel then
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0, 14)
        nameLabel.Position = UDim2.new(0, 0, 0, 58)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = name
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextSize = 10
        nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        nameLabel.TextStrokeTransparency = 0.8
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.ZIndex = 7
        nameLabel.Parent = icon
    end

    icon.MouseButton1Down:Connect(function()
        TweenService:Create(bg, TweenInfo.new(0.1), {Size = UDim2.new(0, 48, 0, 48), Position = UDim2.new(0.5, -24, 0, 3)}):Play()
    end)
    local function release()
        TweenService:Create(bg, TweenInfo.new(0.18, Enum.EasingStyle.Back), {Size = UDim2.new(0, 54, 0, 54), Position = UDim2.new(0.5, -27, 0, 0)}):Play()
    end
    icon.MouseButton1Up:Connect(release)
    icon.MouseLeave:Connect(release)

    return icon
end

WebBrowserIcon = createAppIcon("Navegador", Icons.search, Color3.fromRGB(35, 145, 205), Nav.dockSlot(1), dockFrame, true)
MusicAppIcon = createAppIcon("Música", Icons.music, Color3.fromRGB(250, 60, 90), Nav.dockSlot(2), dockFrame, true)
GalleryAppIcon = createAppIcon("Galeria", Icons.gallery, Color3.fromRGB(180, 80, 220), Nav.dockSlot(3), dockFrame, true)
ConfigAppIcon = createAppIcon("Config", Icons.gear, Color3.fromRGB(120, 120, 130), Nav.dockSlot(4), dockFrame, true)
StopwatchAppIcon = createAppIcon("Cronômetro", Icons.stopwatch, Color3.fromRGB(255, 140, 30), Nav.homeSlot(4))
Nav.gps.icon = createAppIcon("GPS", Icons.gps, Color3.fromRGB(46, 190, 120), UDim2.new(0, 12, 0, 232), homePage2)

Nav.__mkIconFn = createAppIcon

do
    local PAGE_W, curPage = 280, 1
    local dotsFrame = Instance.new("Frame")
    dotsFrame.Name = "PageDots"
    dotsFrame.AnchorPoint = Vector2.new(0.5, 0)
    dotsFrame.Position = UDim2.new(0.5, 0, 0, 312)
    dotsFrame.Size = UDim2.new(0, 28, 0, 6)
    dotsFrame.BackgroundTransparency = 1
    dotsFrame.ZIndex = 6
    dotsFrame.Parent = PhoneHome
    local dots = {}
    for k = 1, 2 do
        local d = Instance.new("Frame")
        d.Size = UDim2.new(0, 6, 0, 6)
        d.Position = UDim2.new(0, (k - 1) * 14 + 4, 0, 0)
        d.BackgroundColor3 = Color3.new(1, 1, 1)
        d.BackgroundTransparency = k == 1 and 0.05 or 0.6
        d.BorderSizePixel = 0
        d.ZIndex = 7
        d.Parent = dotsFrame
        Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
        dots[k] = d
    end

    local cal = Instance.new("Frame")
    cal.Name = "CalendarWidget"
    cal.Position = UDim2.new(0, 12, 0, 44)
    cal.Size = UDim2.new(0, 256, 0, 172)
    cal.BackgroundColor3 = Color3.new(1, 1, 1)
    cal.BackgroundTransparency = 0.8
    cal.BorderSizePixel = 0
    cal.ZIndex = 5
    cal.Parent = homePage2
    Instance.new("UICorner", cal).CornerRadius = UDim.new(0, 22)
    do
        local st = Instance.new("UIStroke", cal)
        st.Color = Color3.new(1, 1, 1)
        st.Transparency = 0.8
        st.Thickness = 1
    end
    local function calLabel(x, y, w, h, txt, ts, font, col, align)
        local l = Instance.new("TextLabel")
        l.Position = UDim2.new(0, x, 0, y)
        l.Size = UDim2.new(0, w, 0, h)
        l.BackgroundTransparency = 1
        l.Text = txt
        l.TextColor3 = col
        l.Font = font
        l.TextSize = ts
        l.TextXAlignment = align or Enum.TextXAlignment.Center
        l.ZIndex = 7
        l.Parent = cal
        return l
    end
    local MO = {"janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"}
    local function buildCalendar()
        for _, c in ipairs(cal:GetChildren()) do
            if c:IsA("TextLabel") or c.Name == "Today" then c:Destroy() end
        end
        local t = os.date("*t")
        calLabel(16, 8, 224, 22, MO[t.month] .. " " .. t.year, 14, Enum.Font.GothamBold, Color3.fromRGB(255, 130, 120), Enum.TextXAlignment.Left)
        local colW = 256 / 7
        local initials = {"D", "S", "T", "Q", "Q", "S", "S"}
        for k = 1, 7 do
            calLabel((k - 1) * colW, 34, colW, 16, initials[k], 10, Enum.Font.GothamBold, Color3.fromRGB(200, 200, 210))
        end
        local first = os.date("*t", os.time({year = t.year, month = t.month, day = 1, hour = 12})).wday
        local nDays = os.date("*t", os.time({year = t.year, month = t.month + 1, day = 0, hour = 12})).day
        for day = 1, nDays do
            local idx = first - 1 + day - 1
            local col, row = idx % 7, math.floor(idx / 7)
            local x, y = col * colW, 54 + row * 19
            if day == t.day then
                local dot = Instance.new("Frame")
                dot.Name = "Today"
                dot.Position = UDim2.new(0, x + colW / 2 - 9, 0, y)
                dot.Size = UDim2.new(0, 18, 0, 18)
                dot.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
                dot.BorderSizePixel = 0
                dot.ZIndex = 6
                dot.Parent = cal
                Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
            end
            calLabel(x, y, colW, 18, tostring(day), 10, day == t.day and Enum.Font.GothamBold or Enum.Font.Gotham, Color3.new(1, 1, 1))
        end
    end
    pcall(buildCalendar)
    task.spawn(function()
        local lastDay = os.date("*t").day
        while PhoneHome.Parent do
            task.wait(30)
            local d = os.date("*t").day
            if d ~= lastDay then
                lastDay = d
                pcall(buildCalendar)
            end
        end
    end)

    local pageTween
    local function setPage(n, instant)
        n = math.clamp(n, 1, 2)
        curPage = n
        local goal = UDim2.new(0, -(n - 1) * PAGE_W, 0, 0)
        if pageTween then
            pageTween:Cancel()
            pageTween = nil
        end
        if instant then
            pager.Position = goal
        else
            pageTween = TweenService:Create(pager, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = goal})
            pageTween:Play()
        end
        for k, d in ipairs(dots) do
            TweenService:Create(d, TweenInfo.new(0.2), {BackgroundTransparency = k == n and 0.05 or 0.6}):Play()
        end
    end
    Nav.homeSetPage = setPage

    -- tocar num pontinho tambem troca de pagina
    for k, d in ipairs(dots) do
        local hit = Instance.new("TextButton")
        hit.Name = "DotHit" .. k
        hit.Text = ""
        hit.AutoButtonColor = false
        hit.BackgroundTransparency = 1
        hit.Size = UDim2.new(0, 20, 0, 20)
        hit.Position = UDim2.new(0, d.Position.X.Offset - 7, 0, -7)
        hit.ZIndex = 8
        hit.Parent = dotsFrame
        hit.MouseButton1Click:Connect(function() setPage(k) end)
    end

    -- swipe lateral (mouse e touch)
    local MOUSE_MOVE = Enum.UserInputType.MouseMovement
    local MOUSE_BTN = Enum.UserInputType.MouseButton1
    local TOUCH = Enum.UserInputType.Touch
    local drag = nil

    local function isPress(i)
        return i.UserInputType == MOUSE_BTN or i.UserInputType == TOUCH
    end

    local function insidePhone(pos)
        local ap, as = PhoneHome.AbsolutePosition, PhoneHome.AbsoluteSize
        return pos.X >= ap.X and pos.X <= ap.X + as.X and pos.Y >= ap.Y - 40 and pos.Y <= ap.Y + as.Y + 40
    end

    local function scaleNow()
        local s = phoneUIScale.Scale
        if s <= 0 then s = 1 end
        return s
    end

    local function rubber(x)
        if x > 0 then return x * 0.35 end
        if x < -PAGE_W then return -PAGE_W + (x + PAGE_W) * 0.35 end
        return x
    end

    UserInputService.InputBegan:Connect(function(i)
        if not isPress(i) or not PhoneHome.Visible then return end
        if Nav.boot and Nav.boot.active then return end
        if not insidePhone(i.Position) then return end
        drag = {
            isTouch = i.UserInputType == TOUCH,
            x0 = i.Position.X, y0 = i.Position.Y,
            lastX = i.Position.X, lastT = os.clock(), vx = 0,
            moved = false,
        }
    end)

    UserInputService.InputChanged:Connect(function(i)
        if not drag then return end
        local t = i.UserInputType
        if not (t == MOUSE_MOVE or (t == TOUCH and drag.isTouch)) then return end
        if not drag.isTouch and not UserInputService:IsMouseButtonPressed(MOUSE_BTN) then
            drag = nil
            return
        end
        local sc = scaleNow()
        local dx = (i.Position.X - drag.x0) / sc
        local dy = (i.Position.Y - drag.y0) / sc
        if not drag.moved and math.abs(dx) > 8 and math.abs(dx) > math.abs(dy) then
            drag.moved = true
            Nav.homeSwiped = true
            if pageTween then
                pageTween:Cancel()
                pageTween = nil
            end
        end
        if drag.moved then
            local now = os.clock()
            local dt = now - drag.lastT
            if dt > 0 then
                drag.vx = drag.vx * 0.6 + ((i.Position.X - drag.lastX) / sc / dt) * 0.4
            end
            drag.lastX, drag.lastT = i.Position.X, now
            pager.Position = UDim2.new(0, rubber(-(curPage - 1) * PAGE_W + dx), 0, 0)
        end
    end)

    UserInputService.InputEnded:Connect(function(i)
        if not drag or not isPress(i) then return end
        if (i.UserInputType == TOUCH) ~= drag.isTouch then return end
        local d = drag
        drag = nil
        if not d.moved then return end
        local dx = (i.Position.X - d.x0) / scaleNow()
        if dx < -45 or d.vx < -450 then
            setPage(2)
        elseif dx > 45 or d.vx > 450 then
            setPage(1)
        else
            setPage(curPage)
        end
        task.delay(0.25, function() Nav.homeSwiped = false end)
    end)
end

createNavBar(PhoneHome)

local frameCount = 0
local lastFpsUpdate = os.clock()
local currentFps = 0
RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    local now = os.clock()
    if now - lastFpsUpdate >= 0.5 then
        currentFps = math.floor(frameCount / (now - lastFpsUpdate))
        frameCount = 0
        lastFpsUpdate = now
        Nav.status.setFps(currentFps)
    end
end)
end

do
    local function step(delta)
        currentVolume = math.clamp(math.floor((currentVolume + delta) * 10 + 0.5) / 10, 0, 1)
        phoneSettings.volume = currentVolume
        saveSettings()
        if currentSound then currentSound.Volume = currentVolume end
        Nav.shell.showVolume(currentVolume)
    end
    Nav.shell.volumeUp = function() step(0.1) end
    Nav.shell.volumeDown = function() step(-0.1) end
end

do
local GREEN = Color3.fromRGB(50, 205, 50)
local CARD = Color3.fromRGB(22, 22, 28)
local CARD2 = Color3.fromRGB(36, 36, 45)
local SUBC = Color3.fromRGB(140, 140, 155)
local MUTED = Color3.fromRGB(100, 100, 116)
local DARK = Color3.fromRGB(10, 10, 15)
local PINK = Color3.fromRGB(255, 82, 122)
local FONT, FONTB, FONTM, FONTC = Enum.Font.Gotham, Enum.Font.GothamBold, Enum.Font.GothamMedium, Enum.Font.Code
local LEFT, RIGHT = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right
local MarketplaceService = game:GetService("MarketplaceService")

local function mk(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function mkBtn(parent, size, pos, z)
    return mk("TextButton", {Size = size, Position = pos, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = z or 2, BorderSizePixel = 0}, parent)
end

local function fmt(s)
    s = math.max(0, tonumber(s) or 0)
    return string.format("%02d:%02d", math.floor(s / 60), math.floor(s % 60))
end

local function isPointer(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local function isMove(i)
    return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

function Icons.hash(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    local th = T(2.2, u)
    Draw.line(c, 9 * u, 4.5 * u, 7.5 * u, 19.5 * u, th, color, z)
    Draw.line(c, 16.5 * u, 4.5 * u, 15 * u, 19.5 * u, th, color, z)
    Draw.line(c, 4.5 * u, 9 * u, 19.5 * u, 9 * u, th, color, z)
    Draw.line(c, 4 * u, 15 * u, 19 * u, 15 * u, th, color, z)
    return c
end

if type(phoneSettings.musicFavs) ~= "table" then phoneSettings.musicFavs = {} end
do
    local fixed = {}
    if type(phoneSettings.musicIds) == "table" then
        for _, e in ipairs(phoneSettings.musicIds) do
            if type(e) == "string" or type(e) == "number" then e = {id = tostring(e)} end
            if type(e) == "table" and e.id then
                table.insert(fixed, {id = tostring(e.id), name = type(e.name) == "string" and e.name or nil})
            end
        end
    end
    phoneSettings.musicIds = fixed
end

shuffleMode = phoneSettings.musicShuffle == true
local repeatState = math.clamp(tonumber(phoneSettings.musicRepeat) or 0, 0, 2)
local sortAsc = phoneSettings.musicSortDesc ~= true
local onlyFavs = false
local activeTab = "library"
local status = "idle"
local currentItem = nil
local pendingResume = nil
local queue, queueIdx = {}, 0
local shuffleStack = {}
local playToken = 0
local atEnd = false
local seeking, seekAlpha = false, 0
local miniVisible = false
local rowEq = nil
local vizActive = false
local glowSmooth = 0
local UI = {}

local setTab, updateMini, layoutLists, updateList, updateHistory, updateTrackUI, refreshToggles
local onEnded, playItem, stepTrack, togglePlay

local accentCur, accentTar = GREEN, GREEN
local accentTargets = {}

local function trackAccent(inst, prop)
    table.insert(accentTargets, {inst, prop})
    inst[prop] = accentCur
end

local function applyAccent(c)
    for _, t in ipairs(accentTargets) do
        t[1][t[2]] = c
    end
end

local function accentFor(key)
    local h = 7
    for i = 1, #key do h = (h * 33 + key:byte(i)) % 3600 end
    return Color3.fromHSV(h / 3600, 0.6, 0.96)
end

local function setAccent(c)
    accentTar = c
    refreshToggles()
end

local function isFav(name)
    return phoneSettings.musicFavs[name] == true
end

local function toggleFav(name)
    if phoneSettings.musicFavs[name] then
        phoneSettings.musicFavs[name] = nil
    else
        phoneSettings.musicFavs[name] = true
    end
    saveSettings()
end

MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 280, 0, 440)
MainFrame.Position = PhoneHome.Position
MainFrame.BackgroundColor3 = Color3.new(1, 1, 1)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = false
MainFrame.Visible = false
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 28)
mk("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(19, 19, 26), Color3.fromRGB(9, 9, 12)), Rotation = 90}, MainFrame)

UI.tint = mk("Frame", {Size = UDim2.new(1, 0, 0, 250), BackgroundColor3 = GREEN, BorderSizePixel = 0, ZIndex = 1}, MainFrame)
corner(UI.tint, UDim.new(0, 28))
mk("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1)}), Rotation = 90}, UI.tint)
trackAccent(UI.tint, "BackgroundColor3")

Nav.shell.create(MainFrame)
Nav.status.create(MainFrame)

local TopBar = mk("Frame", {Size = UDim2.new(1, 0, 0, 38), Position = UDim2.new(0, 0, 0, 40), BackgroundTransparency = 1}, MainFrame)
local logo = mk("Frame", {Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(0, 14, 0.5, -14), BorderSizePixel = 0}, TopBar)
corner(logo, UDim.new(0, 9))
trackAccent(logo, "BackgroundColor3")
Icons.put(logo, Icons.music, 18, WHITE, 3)
mk("TextLabel", {Size = UDim2.new(0, 110, 0, 28), Position = UDim2.new(0, 50, 0.5, -14), BackgroundTransparency = 1, Text = "Música", TextColor3 = WHITE, Font = FONTB, TextSize = 19, TextXAlignment = LEFT}, TopBar)
UI.count = mk("TextLabel", {Size = UDim2.new(0, 84, 0, 22), Position = UDim2.new(1, -98, 0.5, -11), BackgroundColor3 = CARD, BorderSizePixel = 0, Text = "0 faixas", TextColor3 = SUBC, Font = FONTM, TextSize = 11}, TopBar)
corner(UI.count, UDim.new(1, 0))

local TabBar = mk("Frame", {Size = UDim2.new(1, -24, 0, 32), Position = UDim2.new(0, 12, 0, 82), BackgroundColor3 = CARD, BorderSizePixel = 0}, MainFrame)
corner(TabBar, UDim.new(0, 12))
UI.indicator = mk("Frame", {Size = UDim2.new(1 / 3, -4, 1, -4), Position = UDim2.new(0, 2, 0, 2), BorderSizePixel = 0, ZIndex = 2}, TabBar)
corner(UI.indicator, UDim.new(0, 10))
trackAccent(UI.indicator, "BackgroundColor3")

local tabDefs = {
    {id = "library", text = "Biblioteca", icon = Icons.folder},
    {id = "player", text = "Tocando", icon = Icons.music},
    {id = "id", text = "Sound ID", icon = Icons.hash},
}
UI.tabs = {}
for i, td in ipairs(tabDefs) do
    local b = mk("TextButton", {Size = UDim2.new(1 / 3, 0, 1, 0), Position = UDim2.new((i - 1) / 3, 0, 0, 0), BackgroundTransparency = 1, Text = "", Font = FONTB, TextSize = 11, TextColor3 = SUBC, AutoButtonColor = false, ZIndex = 3}, TabBar)
    local ui = Icons.text(b, {icon = td.icon, iconSize = 14, color = SUBC, text = td.text, textColor = SUBC, gap = 5, z = 4})
    UI.tabs[td.id] = {btn = b, ui = ui, index = i}
    b.MouseButton1Click:Connect(function() setTab(td.id) end)
end

local function mkView()
    return mk("Frame", {Size = UDim2.new(1, 0, 0, 282), Position = UDim2.new(0, 0, 0, 120), BackgroundTransparency = 1, Visible = false}, MainFrame)
end
UI.views = {library = mkView(), player = mkView(), id = mkView()}

do
    local V = UI.views.library
    local wrap = mk("Frame", {Size = UDim2.new(1, -56, 0, 30), Position = UDim2.new(0, 12, 0, 0), BackgroundColor3 = CARD, BorderSizePixel = 0}, V)
    corner(wrap, UDim.new(0, 10))
    Icons.searchField(wrap, 15, 10)
    UI.search = mk("TextBox", {Size = UDim2.new(1, -62, 1, 0), Position = UDim2.new(0, 32, 0, 0), BackgroundTransparency = 1, PlaceholderText = "Pesquisar música...", PlaceholderColor3 = MUTED, Text = "", TextColor3 = WHITE, Font = FONT, TextSize = 13, TextXAlignment = LEFT, ClearTextOnFocus = false, ClipsDescendants = true, TextWrapped = false}, wrap)
    UI.clear = mkBtn(wrap, UDim2.new(0, 24, 0, 24), UDim2.new(1, -28, 0.5, -12), 3)
    UI.clear.Visible = false
    Icons.put(UI.clear, Icons.close, 12, SUBC, 4)

    UI.favFilter = mk("TextButton", {Size = UDim2.new(0, 32, 0, 30), Position = UDim2.new(1, -44, 0, 0), BackgroundColor3 = CARD, BorderSizePixel = 0, Text = "", AutoButtonColor = false}, V)
    corner(UI.favFilter, UDim.new(0, 10))

    UI.info = mk("TextLabel", {Size = UDim2.new(1, -120, 0, 16), Position = UDim2.new(0, 14, 0, 36), BackgroundTransparency = 1, Text = "", TextColor3 = SUBC, Font = FONTM, TextSize = 11, TextXAlignment = LEFT}, V)
    UI.sort = mk("TextButton", {Size = UDim2.new(0, 90, 0, 16), Position = UDim2.new(1, -102, 0, 36), BackgroundTransparency = 1, Text = "Ordem A-Z", Font = FONTB, TextSize = 11, TextXAlignment = RIGHT, AutoButtonColor = false}, V)
    trackAccent(UI.sort, "TextColor3")

    UI.list = mk("ScrollingFrame", {Size = UDim2.new(1, -24, 0, 162), Position = UDim2.new(0, 12, 0, 56), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y}, V)
    trackAccent(UI.list, "ScrollBarImageColor3")
    mk("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, UI.list)
end

do
    local V = UI.views.player

    local glow = mk("Frame", {Size = UDim2.new(0, 106, 0, 106), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 52), BackgroundTransparency = 1}, V)
    corner(glow, UDim.new(1, 0))
    UI.glow = mk("UIStroke", {Thickness = 2, Transparency = 0.7}, glow)
    trackAccent(UI.glow, "Color")

    UI.disc = mk("Frame", {Size = UDim2.new(0, 92, 0, 92), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 52), BackgroundColor3 = Color3.fromRGB(16, 16, 20), BorderSizePixel = 0}, V)
    corner(UI.disc, UDim.new(1, 0))
    mk("UIStroke", {Color = Color3.fromRGB(48, 48, 60), Thickness = 1.5}, UI.disc)
    for _, d in ipairs({80, 68, 56}) do
        local g = mk("Frame", {Size = UDim2.new(0, d, 0, d), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 1}, UI.disc)
        corner(g, UDim.new(1, 0))
        mk("UIStroke", {Color = Color3.fromRGB(38, 38, 48), Thickness = 1}, g)
    end
    local label = mk("Frame", {Size = UDim2.new(0, 38, 0, 38), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), BorderSizePixel = 0}, UI.disc)
    corner(label, UDim.new(1, 0))
    trackAccent(label, "BackgroundColor3")
    Icons.put(label, Icons.note, 22, WHITE, 3)
    local shine = mk("Frame", {Size = UDim2.new(0, 7, 0, 7), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 8), BackgroundColor3 = WHITE, BackgroundTransparency = 0.65, BorderSizePixel = 0}, UI.disc)
    corner(shine, UDim.new(1, 0))

    UI.ptitle = mk("TextLabel", {Size = UDim2.new(1, -84, 0, 22), Position = UDim2.new(0, 42, 0, 104), BackgroundTransparency = 1, Text = "Nenhuma música", TextColor3 = WHITE, Font = FONTB, TextSize = 16, TextTruncate = Enum.TextTruncate.AtEnd}, V)
    UI.psub = mk("TextLabel", {Size = UDim2.new(1, -40, 0, 16), Position = UDim2.new(0, 20, 0, 126), BackgroundTransparency = 1, Text = "", TextColor3 = SUBC, Font = FONT, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd}, V)
    UI.pheart = mkBtn(V, UDim2.new(0, 28, 0, 28), UDim2.new(1, -40, 0, 101), 3)

    local viz = mk("Frame", {Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 12, 0, 148), BackgroundTransparency = 1}, V)
    UI.bars, UI.barVals = {}, {}
    for i = 1, 32 do
        local b = mk("Frame", {Size = UDim2.new(0, 5, 0, 3), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 1 + (i - 1) * 8, 0.5, 0), BorderSizePixel = 0}, viz)
        corner(b, UDim.new(1, 0))
        trackAccent(b, "BackgroundColor3")
        UI.bars[i] = b
        UI.barVals[i] = 3
    end

    UI.seekHit = mk("TextButton", {Size = UDim2.new(1, -24, 0, 22), Position = UDim2.new(0, 12, 0, 184), BackgroundTransparency = 1, Text = "", AutoButtonColor = false}, V)
    local track = mk("Frame", {Size = UDim2.new(1, 0, 0, 4), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = CARD2, BorderSizePixel = 0}, UI.seekHit)
    corner(track, UDim.new(1, 0))
    UI.fill = mk("Frame", {Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0}, track)
    corner(UI.fill, UDim.new(1, 0))
    trackAccent(UI.fill, "BackgroundColor3")
    UI.knob = mk("Frame", {Size = UDim2.new(0, 12, 0, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 3}, track)
    corner(UI.knob, UDim.new(1, 0))

    UI.timeL = mk("TextLabel", {Size = UDim2.new(0.5, -14, 0, 12), Position = UDim2.new(0, 14, 0, 208), BackgroundTransparency = 1, Text = "00:00", TextColor3 = SUBC, Font = FONTC, TextSize = 10, TextXAlignment = LEFT}, V)
    UI.timeR = mk("TextLabel", {Size = UDim2.new(0.5, -14, 0, 12), Position = UDim2.new(0.5, 0, 0, 208), BackgroundTransparency = 1, Text = "00:00", TextColor3 = SUBC, Font = FONTC, TextSize = 10, TextXAlignment = RIGHT}, V)

    local ctrls = mk("Frame", {Size = UDim2.new(1, -24, 0, 54), Position = UDim2.new(0, 12, 0, 224), BackgroundTransparency = 1}, V)
    local function ctl(frac, w, h, bg)
        local b = mk("TextButton", {Size = UDim2.new(0, w, 0, h), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(frac, 0, 0.5, 0), BackgroundColor3 = bg or CARD, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 2}, ctrls)
        corner(b, UDim.new(1, 0))
        return b
    end
    UI.shuffle = ctl(0.07, 36, 36)
    UI.prev = ctl(0.27, 44, 44)
    UI.play = ctl(0.5, 54, 54)
    trackAccent(UI.play, "BackgroundColor3")
    UI.next = ctl(0.73, 44, 44)
    UI.rep = ctl(0.93, 36, 36)
    Icons.put(UI.prev, Icons.prev, 20, WHITE, 3)
    Icons.put(UI.next, Icons.next, 20, WHITE, 3)
end

do
    UI.mini = mk("Frame", {Size = UDim2.new(1, -24, 0, 52), Position = UDim2.new(0, 12, 0, 342), BackgroundColor3 = CARD, BorderSizePixel = 0, Visible = false, ZIndex = 10}, MainFrame)
    corner(UI.mini, UDim.new(0, 16))
    local ms = mk("UIStroke", {Thickness = 1.2, Transparency = 0.55}, UI.mini)
    trackAccent(ms, "Color")
    local art = mk("Frame", {Size = UDim2.new(0, 36, 0, 36), Position = UDim2.new(0, 8, 0.5, -18), BorderSizePixel = 0, ZIndex = 11}, UI.mini)
    corner(art, UDim.new(0, 10))
    trackAccent(art, "BackgroundColor3")
    Icons.put(art, Icons.note, 20, WHITE, 12)
    UI.mtitle = mk("TextLabel", {Size = UDim2.new(1, -140, 0, 18), Position = UDim2.new(0, 52, 0, 9), BackgroundTransparency = 1, Text = "", TextColor3 = WHITE, Font = FONTB, TextSize = 13, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 11}, UI.mini)
    UI.msub = mk("TextLabel", {Size = UDim2.new(1, -140, 0, 14), Position = UDim2.new(0, 52, 0, 27), BackgroundTransparency = 1, Text = "", TextColor3 = SUBC, Font = FONT, TextSize = 11, TextXAlignment = LEFT, ZIndex = 11}, UI.mini)
    UI.mopen = mkBtn(UI.mini, UDim2.new(1, -90, 1, 0), UDim2.new(0, 0, 0, 0), 12)
    UI.mplay = mk("TextButton", {Size = UDim2.new(0, 34, 0, 34), Position = UDim2.new(1, -78, 0.5, -17), BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 13}, UI.mini)
    corner(UI.mplay, UDim.new(1, 0))
    trackAccent(UI.mplay, "BackgroundColor3")
    UI.mnext = mk("TextButton", {Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -40, 0.5, -15), BackgroundColor3 = CARD2, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 13}, UI.mini)
    corner(UI.mnext, UDim.new(1, 0))
    Icons.put(UI.mnext, Icons.next, 16, WHITE, 14)
    local mbar = mk("Frame", {Size = UDim2.new(1, -28, 0, 2), Position = UDim2.new(0, 14, 1, -4), BackgroundColor3 = CARD2, BorderSizePixel = 0, ZIndex = 11}, UI.mini)
    corner(mbar, UDim.new(1, 0))
    UI.mfill = mk("Frame", {Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, ZIndex = 12}, mbar)
    corner(UI.mfill, UDim.new(1, 0))
    trackAccent(UI.mfill, "BackgroundColor3")
end

do
    local V = UI.views.id
    mk("TextLabel", {Size = UDim2.new(1, -24, 0, 14), Position = UDim2.new(0, 14, 0, 0), BackgroundTransparency = 1, Text = "SOUND ID DO ROBLOX", TextColor3 = SUBC, Font = FONTB, TextSize = 10, TextXAlignment = LEFT}, V)
    UI.idInput = mk("TextBox", {Size = UDim2.new(1, -98, 0, 34), Position = UDim2.new(0, 12, 0, 18), BackgroundColor3 = CARD, BorderSizePixel = 0, PlaceholderText = "Ex: 1837879082", PlaceholderColor3 = MUTED, Text = "", TextColor3 = WHITE, Font = FONT, TextSize = 13, TextXAlignment = LEFT, ClearTextOnFocus = false}, V)
    corner(UI.idInput, UDim.new(0, 10))
    mk("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 6)}, UI.idInput)
    UI.idPlay = mk("TextButton", {Size = UDim2.new(0, 70, 0, 34), Position = UDim2.new(1, -82, 0, 18), BorderSizePixel = 0, Text = "Tocar", TextColor3 = DARK, Font = FONTB, TextSize = 13, AutoButtonColor = false}, V)
    corner(UI.idPlay, UDim.new(0, 10))
    trackAccent(UI.idPlay, "BackgroundColor3")

    mk("TextLabel", {Size = UDim2.new(1, -24, 0, 14), Position = UDim2.new(0, 14, 0, 58), BackgroundTransparency = 1, Text = "LINK DE ÁUDIO (MP3/OGG)", TextColor3 = SUBC, Font = FONTB, TextSize = 10, TextXAlignment = LEFT}, V)
    UI.urlInput = mk("TextBox", {Size = UDim2.new(1, -98, 0, 34), Position = UDim2.new(0, 12, 0, 74), BackgroundColor3 = CARD, BorderSizePixel = 0, PlaceholderText = "https://site.com/musica.mp3", PlaceholderColor3 = MUTED, Text = "", TextColor3 = WHITE, Font = FONT, TextSize = 12, TextXAlignment = LEFT, ClearTextOnFocus = false, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, ClipsDescendants = true}, V)
    corner(UI.urlInput, UDim.new(0, 10))
    mk("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 6)}, UI.urlInput)
    UI.urlPlay = mk("TextButton", {Size = UDim2.new(0, 70, 0, 34), Position = UDim2.new(1, -82, 0, 74), BorderSizePixel = 0, Text = "Baixar", TextColor3 = DARK, Font = FONTB, TextSize = 13, AutoButtonColor = false}, V)
    corner(UI.urlPlay, UDim.new(0, 10))
    trackAccent(UI.urlPlay, "BackgroundColor3")

    mk("TextLabel", {Size = UDim2.new(0.5, -14, 0, 14), Position = UDim2.new(0, 14, 0, 116), BackgroundTransparency = 1, Text = "RECENTES", TextColor3 = SUBC, Font = FONTB, TextSize = 10, TextXAlignment = LEFT}, V)
    UI.clearHist = mk("TextButton", {Size = UDim2.new(0, 60, 0, 14), Position = UDim2.new(1, -72, 0, 116), BackgroundTransparency = 1, Text = "Limpar", Font = FONTB, TextSize = 11, TextXAlignment = RIGHT, AutoButtonColor = false}, V)
    trackAccent(UI.clearHist, "TextColor3")

    UI.idList = mk("ScrollingFrame", {Size = UDim2.new(1, -24, 0, 84), Position = UDim2.new(0, 12, 0, 134), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y}, V)
    trackAccent(UI.idList, "ScrollBarImageColor3")
    mk("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, UI.idList)
end

createNavBar(MainFrame)

local function emptyBox(parent, text, iconFn)
    local f = mk("Frame", {Size = UDim2.new(1, -6, 0, 78), BackgroundColor3 = CARD, BorderSizePixel = 0}, parent)
    corner(f, UDim.new(0, 12))
    local l = mk("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = text, TextColor3 = SUBC, Font = FONT, TextSize = 12, TextWrapped = true}, f)
    Icons.empty(l, iconFn, 20, MUTED, 3)
    return f
end

local function setPlayIcon(playing)
    Icons.put(UI.play, playing and Icons.pause or Icons.play, 26, DARK, 3)
    Icons.put(UI.mplay, playing and Icons.pause or Icons.play, 18, DARK, 14)
end

local function subText()
    if status == "idle" then return "Escolha uma faixa na biblioteca" end
    if status == "loading" then return "Carregando..." end
    if status == "failed" then return "Não foi possível carregar" end
    local base = (currentItem and currentItem.kind == "id") and "Sound ID" or "Arquivo local"
    local pos = ""
    if currentItem and currentItem.kind == "file" and #queue > 0 then
        pos = " · " .. queueIdx .. " de " .. #queue
    end
    return (status == "paused" and "Pausado · " or "Tocando · ") .. base .. pos
end

updateTrackUI = function()
    local name = currentItem and currentItem.name or "Nenhuma música"
    UI.ptitle.Text = name
    UI.psub.Text = subText()
    UI.mtitle.Text = name
    local short = {idle = "", loading = "Carregando...", failed = "Falha ao carregar", playing = "Tocando", paused = "Pausado"}
    UI.msub.Text = short[status] or ""
    local canFav = currentItem ~= nil and currentItem.kind == "file"
    UI.pheart.Visible = canFav
    if canFav then
        Icons.put(UI.pheart, Icons.heart, 18, isFav(currentItem.name) and PINK or MUTED, 4)
    end
    setPlayIcon(status == "playing" or status == "loading")
end

refreshToggles = function()
    UI.shuffle.BackgroundColor3 = shuffleMode and CARD2 or CARD
    Icons.put(UI.shuffle, Icons.shuffle, 18, shuffleMode and accentTar or MUTED, 3)
    UI.rep.BackgroundColor3 = repeatState > 0 and CARD2 or CARD
    Icons.put(UI.rep, repeatState == 2 and Icons.repeatOne or Icons.repeatAll, 18, repeatState > 0 and accentTar or MUTED, 3)
end

layoutLists = function()
    UI.list.Size = UDim2.new(1, -24, 0, miniVisible and 162 or 222)
    UI.idList.Size = UDim2.new(1, -24, 0, miniVisible and 136 or 196)
end

updateMini = function()
    miniVisible = currentItem ~= nil and activeTab ~= "player"
    UI.mini.Visible = miniVisible
    layoutLists()
end

setTab = function(id, instant)
    activeTab = id
    for vid, v in pairs(UI.views) do v.Visible = (vid == id) end
    for tid, d in pairs(UI.tabs) do
        local on = (tid == id)
        d.ui.setColor(on and DARK or SUBC, on and DARK or SUBC)
    end
    local pos = UDim2.new((UI.tabs[id].index - 1) / 3, 2, 0, 2)
    if instant then
        UI.indicator.Position = pos
    else
        TweenService:Create(UI.indicator, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = pos}):Play()
    end
    updateMini()
end

local listSig, listRows, listToken = nil, {}, 0

local function styleRow(ref)
    local isCur = currentItem ~= nil and currentItem.kind == "file" and currentItem.path == ref.m.path
    ref.row.BackgroundColor3 = isCur and CARD2 or CARD
    ref.slot.BackgroundColor3 = isCur and accentTar or CARD2
    ref.name.TextColor3 = isCur and accentTar or WHITE
    ref.name.Font = isCur and FONTB or FONTM
    ref.num.Visible = not isCur
    if isCur then
        if not ref.bars then
            ref.bars = {}
            for b = 1, 3 do
                local bar = mk("Frame", {Size = UDim2.new(0, 3, 0, 8), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, 8 + (b - 1) * 6, 1, -7), BackgroundColor3 = DARK, BorderSizePixel = 0}, ref.slot)
                corner(bar, UDim.new(1, 0))
                ref.bars[b] = bar
            end
        end
        rowEq = ref.bars
    elseif ref.bars then
        for _, bar in ipairs(ref.bars) do bar:Destroy() end
        ref.bars = nil
    end
end

updateList = function()
    local q = UI.search.Text:lower()
    filteredList = {}
    for _, m in ipairs(mp3List) do
        local okSearch = (q == "") or (m.name:lower():find(q, 1, true) ~= nil)
        local okFav = (not onlyFavs) or isFav(m.name)
        if okSearch and okFav then table.insert(filteredList, m) end
    end
    table.sort(filteredList, function(a, b)
        if sortAsc then return a.name:lower() < b.name:lower() end
        return a.name:lower() > b.name:lower()
    end)

    UI.count.Text = #mp3List .. (#mp3List == 1 and " faixa" or " faixas")
    UI.info.Text = (onlyFavs and "Favoritas · " or "Todas · ") .. #filteredList
    UI.sort.Text = sortAsc and "Ordem A-Z" or "Ordem Z-A"
    UI.favFilter.BackgroundColor3 = onlyFavs and Color3.fromRGB(62, 28, 42) or CARD
    Icons.put(UI.favFilter, Icons.heart, 15, onlyFavs and PINK or MUTED, 3)

    -- assinatura da lista: se nada mudou, so atualiza o destaque da faixa atual (sem recriar as linhas)
    local parts = {onlyFavs and "f" or "a", tostring(#mp3List), q}
    for _, m in ipairs(filteredList) do
        parts[#parts + 1] = m.path .. (isFav(m.name) and "*" or "")
    end
    local sig = table.concat(parts, "\n")
    if #filteredList > 0 and sig == listSig and #listRows == #filteredList then
        rowEq = nil
        for _, ref in ipairs(listRows) do
            if ref.row.Parent then styleRow(ref) end
        end
        return
    end
    listSig = (#filteredList > 0) and sig or nil
    listToken += 1
    local token = listToken
    for _, v in ipairs(UI.list:GetChildren()) do
        if v:IsA("GuiObject") then v:Destroy() end
    end
    rowEq = nil
    listRows = {}

    if #filteredList == 0 then
        if #mp3List == 0 then
            emptyBox(UI.list, "Coloque arquivos .mp3 ou .ogg na pasta PHONE/Music", Icons.folder)
        elseif onlyFavs and q == "" then
            emptyBox(UI.list, "Nenhuma favorita ainda. Toque no coração de uma música", Icons.heart)
        else
            emptyBox(UI.list, "Nenhuma música encontrada", Icons.search)
        end
        return
    end

    -- cria as linhas aos poucos (lotes por frame) pra nao travar o jogo
    local snapshot = filteredList
    task.spawn(function()
        for idx, m in ipairs(snapshot) do
            if token ~= listToken then return end
            local row = mk("Frame", {Size = UDim2.new(1, -6, 0, 40), BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = idx}, UI.list)
            corner(row, UDim.new(0, 12))
            local slot = mk("Frame", {Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(0, 8, 0.5, -14), BackgroundColor3 = CARD2, BorderSizePixel = 0}, row)
            corner(slot, UDim.new(0, 9))
            local num = mk("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = tostring(idx), TextColor3 = SUBC, Font = FONTC, TextSize = 11}, slot)
            local nameL = mk("TextLabel", {Size = UDim2.new(1, -86, 1, 0), Position = UDim2.new(0, 44, 0, 0), BackgroundTransparency = 1, Text = m.name, TextColor3 = WHITE, Font = FONTM, TextSize = 13, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd}, row)
            local hit = mkBtn(row, UDim2.new(1, -40, 1, 0), UDim2.new(0, 0, 0, 0), 3)
            local heart = mkBtn(row, UDim2.new(0, 30, 0, 30), UDim2.new(1, -36, 0.5, -15), 4)
            Icons.put(heart, Icons.heart, 15, isFav(m.name) and PINK or MUTED, 5)

            hit.MouseButton1Click:Connect(function()
                playItem(m, snapshot, idx)
            end)
            heart.MouseButton1Click:Connect(function()
                toggleFav(m.name)
                if onlyFavs then
                    updateList()
                else
                    Icons.put(heart, Icons.heart, 15, isFav(m.name) and PINK or MUTED, 5)
                    listSig = nil
                end
                updateTrackUI()
            end)
            local ref = {row = row, slot = slot, num = num, name = nameL, m = m}
            listRows[idx] = ref
            styleRow(ref)
            if idx % 8 == 0 then RunService.Heartbeat:Wait() end
        end
    end)
end

updateHistory = function()
    for _, v in ipairs(UI.idList:GetChildren()) do
        if v:IsA("GuiObject") then v:Destroy() end
    end
    local hist = phoneSettings.musicIds
    UI.clearHist.Visible = #hist > 0
    if #hist == 0 then
        emptyBox(UI.idList, "Nenhum ID tocado ainda. Digite um Sound ID acima", Icons.note)
        return
    end
    for i, e in ipairs(hist) do
        local isCur = currentItem ~= nil and currentItem.kind == "id" and currentItem.id == e.id
        local row = mk("Frame", {Size = UDim2.new(1, -6, 0, 40), BackgroundColor3 = isCur and CARD2 or CARD, BorderSizePixel = 0, LayoutOrder = i}, UI.idList)
        corner(row, UDim.new(0, 12))
        local slot = mk("Frame", {Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(0, 8, 0.5, -14), BackgroundColor3 = isCur and accentTar or CARD2, BorderSizePixel = 0}, row)
        corner(slot, UDim.new(0, 9))
        Icons.put(slot, Icons.note, 16, isCur and DARK or SUBC, 3)
        mk("TextLabel", {Size = UDim2.new(1, -84, 0, 17), Position = UDim2.new(0, 44, 0, 5), BackgroundTransparency = 1, Text = e.name or ("Sound ID " .. e.id), TextColor3 = isCur and accentTar or WHITE, Font = FONTM, TextSize = 12, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd}, row)
        mk("TextLabel", {Size = UDim2.new(1, -84, 0, 13), Position = UDim2.new(0, 44, 0, 22), BackgroundTransparency = 1, Text = e.id, TextColor3 = MUTED, Font = FONTC, TextSize = 10, TextXAlignment = LEFT}, row)
        local hit = mkBtn(row, UDim2.new(1, -36, 1, 0), UDim2.new(0, 0, 0, 0), 3)
        local del = mkBtn(row, UDim2.new(0, 28, 0, 28), UDim2.new(1, -32, 0.5, -14), 4)
        Icons.put(del, Icons.close, 12, MUTED, 5)
        hit.MouseButton1Click:Connect(function()
            UI.idInput.Text = e.id
            UI.playId(e.id)
        end)
        del.MouseButton1Click:Connect(function()
            for k, x in ipairs(phoneSettings.musicIds) do
                if x == e then table.remove(phoneSettings.musicIds, k) break end
            end
            saveSettings()
            updateHistory()
        end)
    end
end

local function stopSound()
    playToken += 1
    if currentSound then
        pcall(function()
            currentSound:Stop()
            currentSound:Destroy()
        end)
        currentSound = nil
    end
end

local function assetOf(item)
    if item.kind == "id" then return "rbxassetid://" .. item.id end
    local ok, a = pcall(getcustomasset, item.path)
    if ok and a and a ~= "" then return a end
    return nil
end

playItem = function(item, q, idx, startPos, keepPlaying)
    stopSound()
    pendingResume = nil
    queue = q or {item}
    queueIdx = idx or 1
    currentTrackIndex = queueIdx
    currentItem = item
    isPaused = false
    atEnd = false
    setAccent(accentFor(item.kind == "id" and ("id" .. item.id) or item.name))

    local asset = assetOf(item)
    if not asset then
        status = "failed"
        updateTrackUI(); updateMini(); updateList(); updateHistory()
        return
    end

    local token = playToken
    local snd = Instance.new("Sound")
    snd.Name = "TzeTrack"
    snd.SoundId = asset
    snd.Volume = startPos and 0 or currentVolume
    snd.Looped = (repeatState == 2)
    snd.Parent = MainFrame
    currentSound = snd
    status = "loading"
    if startPos and not keepPlaying then isPaused = true end
    snd:Play()
    updateTrackUI(); updateMini(); updateList(); updateHistory()

    snd.Ended:Connect(function()
        if token == playToken then onEnded() end
    end)

    task.spawn(function()
        local t0 = os.clock()
        while token == playToken and snd.TimeLength <= 0 and os.clock() - t0 < 10 do
            task.wait(0.1)
        end
        if token ~= playToken then return end
        if snd.TimeLength > 0 then
            if startPos then
                pcall(function()
                    snd.TimePosition = math.clamp(startPos, 0, math.max(snd.TimeLength - 0.5, 0))
                    if not keepPlaying then snd:Pause() end
                    snd.Volume = currentVolume
                end)
                isPaused = not keepPlaying
                status = keepPlaying and "playing" or "paused"
                updateTrackUI(); updateMini()
            elseif status == "loading" then
                status = isPaused and "paused" or "playing"
                updateTrackUI()
            end
        else
            status = "failed"
            updateTrackUI(); updateMini()
        end
    end)
end

stepTrack = function(dir)
    if #queue == 0 then
        togglePlay()
        return
    end
    if dir < 0 and currentSound and currentSound.TimePosition > 3 then
        currentSound.TimePosition = 0
        return
    end
    local n = #queue
    local target
    if shuffleMode and n > 1 then
        if dir < 0 and #shuffleStack > 0 then
            target = table.remove(shuffleStack)
        else
            if dir > 0 then
                table.insert(shuffleStack, queueIdx)
                if #shuffleStack > 30 then table.remove(shuffleStack, 1) end
            end
            repeat target = math.random(1, n) until target ~= queueIdx
        end
    else
        target = queueIdx + dir
        if target > n then target = 1 elseif target < 1 then target = n end
    end
    playItem(queue[target], queue, target)
end

onEnded = function()
    local n = #queue
    if n == 0 then return end
    if repeatState == 0 and not shuffleMode and queueIdx >= n then

        atEnd = true
        isPaused = true
        status = "paused"
        if currentSound then currentSound.TimePosition = 0 end
        updateTrackUI()
        return
    end
    stepTrack(1)
end

togglePlay = function()
    if pendingResume and currentItem then
        local pr = pendingResume
        playItem(currentItem, queue, queueIdx, pr.pos, true)
        return
    end
    if status == "failed" and currentItem then
        playItem(currentItem, queue, queueIdx)
        return
    end
    if not currentSound then
        local list = (#filteredList > 0) and filteredList or mp3List
        if #list == 0 then return end
        local idx = shuffleMode and math.random(1, #list) or 1
        playItem(list[idx], list, idx)
        return
    end
    if isPaused then
        if atEnd then
            atEnd = false
            currentSound.TimePosition = 0
            currentSound:Play()
        else
            currentSound:Resume()
        end
        isPaused = false
        status = (currentSound.TimeLength > 0) and "playing" or "loading"
    else
        currentSound:Pause()
        isPaused = true
        status = "paused"
    end
    updateTrackUI()
    updateMini()
end

local function saveResume()
    if not currentItem or not currentSound or status == "failed" or status == "idle" then return end
    local pos = atEnd and 0 or (currentSound.TimePosition or 0)
    local r = {kind = currentItem.kind, name = currentItem.name, pos = pos}
    if currentItem.kind == "id" then r.id = currentItem.id else r.path = currentItem.path end
    phoneSettings.musicResume = r
    task.defer(saveSettings)
end

task.spawn(function()
    local lastPos = -1
    while PhoneHome.Parent do
        task.wait(6)
        if currentItem and currentSound and status == "playing" then
            local p = currentSound.TimePosition or 0
            if math.abs(p - lastPos) >= 2 then
                lastPos = p
                pcall(saveResume)
            end
        end
    end
end)

function stopMusic()
    pcall(saveResume)
    pendingResume = nil
    stopSound()
    isPaused = false
    atEnd = false
    currentItem = nil
    queue, queueIdx, currentTrackIndex = {}, 0, 0
    shuffleStack = {}
    status = "idle"
    setAccent(GREEN)
    UI.disc.Rotation = 0
    UI.fill.Size = UDim2.new(0, 0, 1, 0)
    UI.knob.Position = UDim2.new(0, 0, 0.5, 0)
    UI.mfill.Size = UDim2.new(0, 0, 1, 0)
    UI.timeL.Text = "00:00"
    UI.timeR.Text = "00:00"
    updateTrackUI(); updateMini(); updateList(); updateHistory()
end

function refreshFiles()
    mp3List = {}
    local seen = {}
    local paths = {"PHONE/Music/", "PHONE/Music", "PHONE\\Music"}
    local success, files = false, nil
    for _, p in ipairs(paths) do
        success, files = pcall(function() return listfiles(p) end)
        if success and type(files) == "table" and #files > 0 then break end
    end
    if success and type(files) == "table" then
        for _, file in ipairs(files) do
            local f = tostring(file)
            local low = f:lower()
            if (low:match("%.mp3$") or low:match("%.ogg$")) and not seen[f] then
                seen[f] = true
                local name = f:match("([^/\\]+)$") or f
                name = (name:gsub("%.%w+$", ""))
                table.insert(mp3List, {kind = "file", name = name, path = f})
            end
        end
    end
    updateList()
end

-- mostra a ultima musica (pausada no tempo salvo) sem carregar o audio; ele so carrega ao apertar play
function restoreMusic()
    local r = phoneSettings.musicResume
    if currentItem or type(r) ~= "table" or not r.kind then return end
    local item, q, idx
    if r.kind == "id" and r.id then
        q = {}
        for i, e in ipairs(phoneSettings.musicIds or {}) do
            q[i] = {kind = "id", id = e.id, name = e.name or ("Sound ID " .. e.id)}
            if e.id == r.id then idx = i end
        end
        if not idx then
            q = {{kind = "id", id = r.id, name = r.name or ("Sound ID " .. r.id)}}
            idx = 1
        end
        item = q[idx]
    elseif r.kind == "file" then
        for _, list in ipairs({filteredList, mp3List}) do
            for i, m in ipairs(list) do
                if m.path == r.path or (r.name and m.name == r.name) then
                    q, idx, item = list, i, m
                    break
                end
            end
            if item then break end
        end
    end
    if not item then return end
    queue, queueIdx, currentTrackIndex = q, idx, idx
    currentItem = item
    isPaused, atEnd = true, false
    status = "paused"
    pendingResume = {pos = tonumber(r.pos) or 0}
    setAccent(accentFor(item.kind == "id" and ("id" .. item.id) or item.name))
    updateTrackUI(); updateMini(); updateList(); updateHistory()
end

function UI.playId(raw)
    local clean = tostring(raw or ""):gsub("%D", "")
    if clean == "" or #clean > 19 then
        UI.idInput.BackgroundColor3 = Color3.fromRGB(95, 32, 44)
        TweenService:Create(UI.idInput, TweenInfo.new(0.6), {BackgroundColor3 = CARD}):Play()
        return
    end
    local hist = phoneSettings.musicIds
    local entry
    for i, e in ipairs(hist) do
        if e.id == clean then
            entry = table.remove(hist, i)
            break
        end
    end
    entry = entry or {id = clean}
    table.insert(hist, 1, entry)
    while #hist > 12 do table.remove(hist) end
    saveSettings()

    local q = {}
    for i, e in ipairs(hist) do
        q[i] = {kind = "id", id = e.id, name = e.name or ("Sound ID " .. e.id)}
    end
    playItem(q[1], q, 1)

    if not entry.name then
        task.spawn(function()
            local ok, info = pcall(function()
                return MarketplaceService:GetProductInfo(tonumber(clean))
            end)
            if ok and type(info) == "table" and type(info.Name) == "string" and info.Name ~= "" then
                entry.name = info.Name
                saveSettings()
                for _, it in ipairs(queue) do
                    if it.kind == "id" and it.id == clean then it.name = info.Name end
                end
                updateTrackUI()
                updateHistory()
            end
        end)
    end
end

function UI.playUrl(raw)
    local url = tostring(raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local function flash()
        UI.urlInput.BackgroundColor3 = Color3.fromRGB(95, 32, 44)
        TweenService:Create(UI.urlInput, TweenInfo.new(0.6), {BackgroundColor3 = CARD}):Play()
    end
    if not url:match("^https?://") then flash() return end
    if UI.urlBusy then return end
    UI.urlBusy = true
    UI.urlPlay.Text = "..."
    task.spawn(function()
        local okG, body = pcall(httpGetBody, url)
        local ext
        if okG and type(body) == "string" and #body > 200 then
            if body:sub(1, 4) == "OggS" then
                ext = "ogg"
            elseif body:sub(1, 3) == "ID3" or (body:byte(1) == 255 and (body:byte(2) or 0) >= 224) then
                ext = "mp3"
            end
        end
        local fileName
        if ext then
            local base = url:match("^https?://[^?#]*/([^/?#]+)") or "audio"
            base = base:gsub("%.%w+$", "")
            base = base:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
            base = base:gsub("[^%w%-_ ]", "_")
            base = base:sub(1, 48)
            if base == "" then base = "audio" end
            pcall(function()
                if not isfolder("PHONE") then makefolder("PHONE") end
                if not isfolder("PHONE/Music") then makefolder("PHONE/Music") end
            end)
            fileName = base .. "." .. ext
            if not pcall(writefile, "PHONE/Music/" .. fileName, body) then fileName = nil end
        end
        UI.urlBusy = false
        UI.urlPlay.Text = "Baixar"
        if not fileName then flash() return end
        UI.urlInput.Text = ""
        refreshFiles()
        for i, it in ipairs(mp3List) do
            if (it.path or ""):match("([^/\\]+)$") == fileName then
                playItem(it, mp3List, i)
                break
            end
        end
    end)
end

UI.search:GetPropertyChangedSignal("Text"):Connect(function()
    UI.clear.Visible = UI.search.Text ~= ""
    updateList()
end)
UI.clear.MouseButton1Click:Connect(function() UI.search.Text = "" end)

UI.favFilter.MouseButton1Click:Connect(function()
    onlyFavs = not onlyFavs
    updateList()
end)

UI.sort.MouseButton1Click:Connect(function()
    sortAsc = not sortAsc
    phoneSettings.musicSortDesc = not sortAsc
    saveSettings()
    updateList()
end)

UI.pheart.MouseButton1Click:Connect(function()
    if currentItem and currentItem.kind == "file" then
        toggleFav(currentItem.name)
        updateTrackUI()
        updateList()
    end
end)

UI.play.MouseButton1Click:Connect(togglePlay)
UI.mplay.MouseButton1Click:Connect(togglePlay)
UI.next.MouseButton1Click:Connect(function() stepTrack(1) end)
UI.mnext.MouseButton1Click:Connect(function() stepTrack(1) end)
UI.prev.MouseButton1Click:Connect(function() stepTrack(-1) end)
UI.mopen.MouseButton1Click:Connect(function() setTab("player") end)

UI.shuffle.MouseButton1Click:Connect(function()
    shuffleMode = not shuffleMode
    phoneSettings.musicShuffle = shuffleMode
    shuffleStack = {}
    saveSettings()
    refreshToggles()
end)

UI.rep.MouseButton1Click:Connect(function()
    repeatState = (repeatState + 1) % 3
    phoneSettings.musicRepeat = repeatState
    saveSettings()
    if currentSound then currentSound.Looped = (repeatState == 2) end
    refreshToggles()
end)

UI.idInput:GetPropertyChangedSignal("Text"):Connect(function()
    local clean = UI.idInput.Text:gsub("%D", "")
    if clean ~= UI.idInput.Text then UI.idInput.Text = clean end
end)
UI.idInput.FocusLost:Connect(function(enter)
    if enter and UI.idInput.Text ~= "" then UI.playId(UI.idInput.Text) end
end)
UI.idPlay.MouseButton1Click:Connect(function() UI.playId(UI.idInput.Text) end)
UI.urlInput.Focused:Connect(function() UI.urlInput.TextTruncate = Enum.TextTruncate.None end)
UI.urlInput.FocusLost:Connect(function(enter)
    UI.urlInput.TextTruncate = Enum.TextTruncate.AtEnd
    if enter then UI.playUrl(UI.urlInput.Text) end
end)
UI.urlPlay.MouseButton1Click:Connect(function() UI.playUrl(UI.urlInput.Text) end)
UI.clearHist.MouseButton1Click:Connect(function()
    phoneSettings.musicIds = {}
    saveSettings()
    updateHistory()
end)

local function seekFromX(x)
    local w = math.max(UI.seekHit.AbsoluteSize.X, 1)
    seekAlpha = math.clamp((x - UI.seekHit.AbsolutePosition.X) / w, 0, 1)
end

UI.seekHit.InputBegan:Connect(function(input)
    if isPointer(input) and currentSound and currentSound.TimeLength > 0 then
        seeking = true
        seekFromX(input.Position.X)
        UI.knob.Size = UDim2.new(0, 16, 0, 16)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if seeking and isMove(input) then seekFromX(input.Position.X) end
end)
UserInputService.InputEnded:Connect(function(input)
    if seeking and isPointer(input) then
        seeking = false
        UI.knob.Size = UDim2.new(0, 12, 0, 12)
        if currentSound and currentSound.TimeLength > 0 then
            currentSound.TimePosition = seekAlpha * currentSound.TimeLength
        end
    end
end)

local clock = 0
RunService.RenderStepped:Connect(function(dt)

    if accentCur ~= accentTar then
        accentCur = accentCur:Lerp(accentTar, math.min(1, dt * 7))
        if math.abs(accentCur.R - accentTar.R) + math.abs(accentCur.G - accentTar.G) + math.abs(accentCur.B - accentTar.B) < 0.01 then
            accentCur = accentTar
        end
        applyAccent(accentCur)
    end

    if not MainFrame.Visible then return end
    clock += dt

    local snd = currentSound
    local len = snd and snd.TimeLength or 0
    local pos = snd and snd.TimePosition or (pendingResume and pendingResume.pos or 0)
    local playing = snd ~= nil and status == "playing" and snd.IsPlaying
    local alpha = seeking and seekAlpha or ((len > 0) and math.clamp(pos / len, 0, 1) or 0)

    if miniVisible then
        UI.mfill.Size = UDim2.new(alpha, 0, 1, 0)
    end

    if activeTab == "player" then
        UI.fill.Size = UDim2.new(alpha, 0, 1, 0)
        UI.knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        local shown = seeking and (seekAlpha * len) or pos
        UI.timeL.Text = fmt(shown)
        UI.timeR.Text = fmt(len)

        if playing then UI.disc.Rotation = (UI.disc.Rotation + dt * 38) % 360 end

        local loud = playing and math.clamp(snd.PlaybackLoudness / 400, 0, 1) or 0
        glowSmooth = glowSmooth + (loud - glowSmooth) * math.min(1, dt * 12)
        UI.glow.Thickness = 2 + glowSmooth * 5
        UI.glow.Transparency = 0.72 - glowSmooth * 0.45

        if playing or vizActive then
            vizActive = false
            for i = 1, 32 do
                local env = 0.35 + 0.65 * (1 - math.abs((i - 16.5) / 16)) ^ 0.8
                local wave = 0.5 + 0.5 * math.sin(clock * 8 + i * 1.3) * math.sin(clock * 3.3 + i * 0.5)
                local target = 3 + 25 * math.clamp(glowSmooth * 1.7 * env * (0.35 + 0.65 * wave), 0, 1)
                local v = UI.barVals[i]
                v = v + (target - v) * math.min(1, dt * 14)
                UI.barVals[i] = v
                if v > 3.3 then vizActive = true end
                UI.bars[i].Size = UDim2.new(0, 5, 0, math.floor(v + 0.5))
            end
        end
    elseif activeTab == "library" and rowEq then
        for b, bar in ipairs(rowEq) do
            local h = playing and (4 + 10 * math.abs(math.sin(clock * 6 + b * 1.9))) or 4
            bar.Size = UDim2.new(0, 3, 0, math.floor(h + 0.5))
        end
    end
end)

refreshToggles()
updateTrackUI()
updateHistory()
updateList()
setTab("library", true)
end

do
StopwatchFrame = Instance.new("Frame")
StopwatchFrame.Name = "StopwatchFrame"
StopwatchFrame.Size = UDim2.new(0, 280, 0, 440)
StopwatchFrame.Position = PhoneHome.Position
StopwatchFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
StopwatchFrame.BorderSizePixel = 0
StopwatchFrame.Visible = false
StopwatchFrame.Active = true
StopwatchFrame.Draggable = false
StopwatchFrame.Parent = ScreenGui
Instance.new("UICorner", StopwatchFrame).CornerRadius = UDim.new(0, 28)

Nav.shell.create(StopwatchFrame)
Nav.status.create(StopwatchFrame)

local swTitle = Instance.new("TextLabel")
swTitle.Size = UDim2.new(1, 0, 0, 30)
swTitle.Position = UDim2.new(0, 0, 0, 50)
swTitle.BackgroundTransparency = 1
swTitle.Text = "Cronômetro"
swTitle.TextColor3 = Color3.new(1, 1, 1)
swTitle.Font = Enum.Font.GothamBold
swTitle.TextSize = 20
swTitle.Parent = StopwatchFrame
Icons.text(swTitle, {icon = Icons.stopwatch, iconSize = 24, gap = 8, color = Color3.fromRGB(255, 140, 30), text = "Cronômetro"})

local C = {
    green = Color3.fromRGB(50, 205, 50), orange = Color3.fromRGB(255, 140, 30),
    red = Color3.fromRGB(255, 95, 95), gray = Color3.fromRGB(120, 120, 140),
    tick = Color3.fromRGB(58, 58, 70), btn = Color3.fromRGB(52, 52, 62),
    btnOff = Color3.fromRGB(28, 28, 34), panel = Color3.fromRGB(20, 20, 27),
    ring = Color3.fromRGB(38, 38, 48),
}
local W = {}

local function mkLabel(parent, text, size, font, color, pos, sz, z)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.BorderSizePixel = 0
    l.Text = text
    l.TextSize = size
    l.Font = font
    l.TextColor3 = color
    l.Position = pos
    l.Size = sz
    l.ZIndex = z or 1
    l.Parent = parent
    return l
end

W.dial = Instance.new("Frame")
W.dial.Name = "Dial"
W.dial.AnchorPoint = Vector2.new(0.5, 0.5)
W.dial.Position = UDim2.new(0, 140, 0, 158)
W.dial.Size = UDim2.new(0, 150, 0, 150)
W.dial.BackgroundColor3 = C.panel
W.dial.BorderSizePixel = 0
W.dial.Parent = StopwatchFrame
Instance.new("UICorner", W.dial).CornerRadius = UDim.new(1, 0)
W.ring = Instance.new("UIStroke")
W.ring.Color = C.ring
W.ring.Thickness = 3
W.ring.Parent = W.dial

W.ticks = {}
for i = 0, 59 do
    local long = i % 5 == 0
    local a = math.rad(i * 6)
    local tk = Instance.new("Frame")
    tk.AnchorPoint = Vector2.new(0.5, 0.5)
    tk.Size = UDim2.new(0, long and 2.4 or 1.6, 0, long and 9 or 5)
    tk.Position = UDim2.new(0, 75 + 64 * math.sin(a), 0, 75 - 64 * math.cos(a))
    tk.Rotation = i * 6
    tk.BackgroundColor3 = C.tick
    tk.BorderSizePixel = 0
    tk.ZIndex = 2
    tk.Parent = W.dial
    Instance.new("UICorner", tk).CornerRadius = UDim.new(1, 0)
    W.ticks[i] = tk
end

W.dot = Instance.new("Frame")
W.dot.AnchorPoint = Vector2.new(0.5, 0.5)
W.dot.Size = UDim2.new(0, 9, 0, 9)
W.dot.Position = UDim2.new(0, 75, 0, -1)
W.dot.BackgroundColor3 = C.gray
W.dot.BorderSizePixel = 0
W.dot.ZIndex = 5
W.dot.Parent = W.dial
Instance.new("UICorner", W.dot).CornerRadius = UDim.new(1, 0)

W.time = mkLabel(W.dial, "00:00", 34, Enum.Font.Code, Color3.new(1, 1, 1), UDim2.new(0, 75, 0, 62), UDim2.new(0, 124, 0, 40), 3)
W.time.AnchorPoint = Vector2.new(0.5, 0.5)
W.cs = mkLabel(W.dial, ".00", 16, Enum.Font.Code, C.gray, UDim2.new(0, 75, 0, 87), UDim2.new(0, 60, 0, 18), 3)
W.cs.AnchorPoint = Vector2.new(0.5, 0.5)
W.lap = mkLabel(W.dial, "", 10, Enum.Font.GothamMedium, C.gray, UDim2.new(0, 75, 0, 104), UDim2.new(0, 100, 0, 14), 3)
W.lap.AnchorPoint = Vector2.new(0.5, 0.5)

local function roundBtn2(cx, labelText)
    local b = Instance.new("TextButton")
    b.AnchorPoint = Vector2.new(0.5, 0.5)
    b.Position = UDim2.new(0, cx, 0, 270)
    b.Size = UDim2.new(0, 54, 0, 54)
    b.BackgroundColor3 = C.btn
    b.Text = ""
    b.AutoButtonColor = false
    b.Parent = StopwatchFrame
    corner(b, UDim.new(1, 0))
    local function up()
        TweenService:Create(b, TweenInfo.new(0.12, Enum.EasingStyle.Back), {Size = UDim2.new(0, 54, 0, 54)}):Play()
    end
    b.MouseButton1Down:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.08), {Size = UDim2.new(0, 48, 0, 48)}):Play()
    end)
    b.MouseButton1Up:Connect(up)
    b.MouseLeave:Connect(up)
    local l = mkLabel(StopwatchFrame, labelText, 11, Enum.Font.GothamMedium, C.gray, UDim2.new(0, cx - 40, 0, 301), UDim2.new(0, 80, 0, 14), 1)
    return b, l
end
W.left, W.leftLbl = roundBtn2(90, "Volta")
W.right, W.rightLbl = roundBtn2(190, "Iniciar")

W.list = Instance.new("ScrollingFrame")
W.list.Position = UDim2.new(0, 14, 0, 320)
W.list.Size = UDim2.new(1, -28, 0, 74)
W.list.BackgroundColor3 = C.panel
W.list.BorderSizePixel = 0
W.list.ScrollBarThickness = 3
W.list.ScrollBarImageColor3 = C.green
W.list.CanvasSize = UDim2.new(0, 0, 0, 0)
W.list.AutomaticCanvasSize = Enum.AutomaticSize.Y
W.list.Parent = StopwatchFrame
corner(W.list, UDim.new(0, 12))
local lapLayout = Instance.new("UIListLayout")
lapLayout.SortOrder = Enum.SortOrder.LayoutOrder
lapLayout.Parent = W.list
local lapPad = Instance.new("UIPadding")
lapPad.PaddingTop = UDim.new(0, 3)
lapPad.PaddingLeft = UDim.new(0, 10)
lapPad.PaddingRight = UDim.new(0, 10)
lapPad.Parent = W.list

W.empty = mkLabel(StopwatchFrame, "Nenhuma volta ainda\nToque na bandeira para marcar", 10, Enum.Font.Gotham, Color3.fromRGB(110, 110, 130), UDim2.new(0, 14, 0, 320), UDim2.new(1, -28, 0, 74), 3)
W.empty.TextWrapped = true
Icons.empty(W.empty, Icons.flag, 16, Color3.fromRGB(110, 110, 130), 4)

createNavBar(StopwatchFrame)

local swRunning = false
local swStartTime = 0
local swElapsed = 0
local swConnection = nil
local laps, lastLapAt = {}, 0
local accent = C.gray
local lastSec = -1

local function curElapsed()
    if swRunning then return swElapsed + (os.clock() - swStartTime) end
    return swElapsed
end

local function fmtMain(t)
    local total = math.floor(t)
    local h = math.floor(total / 3600)
    local m = math.floor((total % 3600) / 60)
    local s = total % 60
    if h >= 24 then
        return string.format("%dd %02d:%02d:%02d", math.floor(h / 24), h % 24, m, s), 18
    elseif h > 0 then
        return string.format("%d:%02d:%02d", h, m, s), 26
    end
    return string.format("%02d:%02d", m, s), 34
end

local function fmtCs(t) return string.format(".%02d", math.floor((t % 1) * 100)) end

local function fmtLap(t)
    return string.format("%02d:%02d.%02d", math.floor(t / 60), math.floor(t % 60), math.floor((t % 1) * 100))
end

local function paint(t)
    local txt, ts = fmtMain(t)
    W.time.Text = txt
    W.time.TextSize = ts
    W.cs.Text = fmtCs(t)
    local sec = math.floor(t) % 60
    if sec ~= lastSec then
        lastSec = sec
        for i = 0, 59 do
            W.ticks[i].BackgroundColor3 = (t > 0 and i <= sec) and accent or C.tick
        end
    end
    local a = math.rad((t % 60) * 6)
    W.dot.Position = UDim2.new(0, 75 + 76 * math.sin(a), 0, 75 - 76 * math.cos(a))
    if #laps > 0 and t > 0 then
        W.lap.Text = string.format("Volta %d  %s", #laps + 1, fmtLap(t - lastLapAt))
    else
        W.lap.Text = ""
    end
end

local function applyState()
    accent = swRunning and C.green or (swElapsed > 0 and C.orange or C.gray)
    W.dot.BackgroundColor3 = accent
    W.cs.TextColor3 = accent
    W.ring.Color = swRunning and Color3.fromRGB(36, 80, 36) or C.ring

    if swRunning then
        W.right.BackgroundColor3 = C.orange
        Icons.put(W.right, Icons.pause, 24, Color3.fromRGB(25, 12, 0), 2)
        W.rightLbl.Text = "Pausar"
        W.left.BackgroundColor3 = C.btn
        Icons.put(W.left, Icons.flag, 22, WHITE, 2)
        W.leftLbl.Text = "Volta"
    else
        W.right.BackgroundColor3 = C.green
        Icons.put(W.right, Icons.play, 24, Color3.new(0, 0, 0), 2)
        W.rightLbl.Text = swElapsed > 0 and "Continuar" or "Iniciar"
        if swElapsed > 0 then
            W.left.BackgroundColor3 = C.btn
            Icons.put(W.left, Icons.reset, 22, WHITE, 2)
            W.leftLbl.Text = "Reset"
        else
            W.left.BackgroundColor3 = C.btnOff
            Icons.put(W.left, Icons.flag, 22, Color3.fromRGB(85, 85, 100), 2)
            W.leftLbl.Text = "Volta"
        end
    end
    lastSec = -1
    paint(curElapsed())
end

local function addLapRow(order, idx, delta, total, col)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = W.list
    local c1 = mkLabel(row, "Volta " .. idx, 11, Enum.Font.GothamMedium, C.gray, UDim2.new(0, 0, 0, 0), UDim2.new(0.28, 0, 1, 0), 2)
    c1.TextXAlignment = Enum.TextXAlignment.Left
    mkLabel(row, "+" .. fmtLap(delta), 13, Enum.Font.Code, col, UDim2.new(0.28, 0, 0, 0), UDim2.new(0.38, 0, 1, 0), 2)
    local c3 = mkLabel(row, fmtLap(total), 12, Enum.Font.Code, C.gray, UDim2.new(0.66, 0, 0, 0), UDim2.new(0.34, 0, 1, 0), 2)
    c3.TextXAlignment = Enum.TextXAlignment.Right
    local line = Instance.new("Frame")
    line.AnchorPoint = Vector2.new(0, 1)
    line.Position = UDim2.new(0, 0, 1, 0)
    line.Size = UDim2.new(1, 0, 0, 1)
    line.BackgroundColor3 = Color3.new(1, 1, 1)
    line.BackgroundTransparency = 0.92
    line.BorderSizePixel = 0
    line.Parent = row
end

local function renderLaps()
    for _, ch in ipairs(W.list:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end
    W.empty.Visible = #laps == 0
    local best, worst
    if #laps >= 2 then
        for i, l in ipairs(laps) do
            if not best or l.delta < laps[best].delta then best = i end
            if not worst or l.delta > laps[worst].delta then worst = i end
        end
    end
    for i, l in ipairs(laps) do
        local col = Color3.new(1, 1, 1)
        if i == best then col = C.green elseif i == worst then col = C.red end
        addLapRow(-i, i, l.delta, l.total, col)
    end
    W.list.CanvasPosition = Vector2.new(0, 0)
end

W.right.MouseButton1Click:Connect(function()
    if swRunning then
        swElapsed = swElapsed + (os.clock() - swStartTime)
        swRunning = false
        if swConnection then swConnection:Disconnect() swConnection = nil end
    else
        swStartTime = os.clock()
        swRunning = true
        if swConnection then swConnection:Disconnect() end
        swConnection = RunService.RenderStepped:Connect(function() paint(curElapsed()) end)
    end
    applyState()
end)

function resetStopwatch()
    swRunning = false
    swElapsed = 0
    swStartTime = 0
    lastLapAt = 0
    laps = {}
    if swConnection then swConnection:Disconnect() swConnection = nil end
    renderLaps()
    applyState()
end

W.left.MouseButton1Click:Connect(function()
    if swRunning then
        local t = curElapsed()
        table.insert(laps, {delta = t - lastLapAt, total = t})
        lastLapAt = t
        renderLaps()
        W.dot.Size = UDim2.new(0, 17, 0, 17)
        TweenService:Create(W.dot, TweenInfo.new(0.3), {Size = UDim2.new(0, 9, 0, 9)}):Play()
    elseif swElapsed > 0 then
        resetStopwatch()
    end
end)

renderLaps()
applyState()
end

do
ConfigFrame = Instance.new("Frame")
ConfigFrame.Name = "ConfigFrame"
ConfigFrame.Size = UDim2.new(0, 280, 0, 440)
ConfigFrame.Position = PhoneHome.Position
ConfigFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
ConfigFrame.BorderSizePixel = 0
ConfigFrame.Visible = false
ConfigFrame.Active = true
ConfigFrame.Draggable = false
ConfigFrame.Parent = ScreenGui
Instance.new("UICorner", ConfigFrame).CornerRadius = UDim.new(0, 28)

Nav.shell.create(ConfigFrame)
Nav.status.create(ConfigFrame)

local cfgTitle = Instance.new("TextLabel")
cfgTitle.Size = UDim2.new(1, 0, 0, 35)
cfgTitle.Position = UDim2.new(0, 0, 0, 45)
cfgTitle.BackgroundTransparency = 1
cfgTitle.Text = "Configurações"
cfgTitle.TextColor3 = Color3.new(1,1,1)
cfgTitle.Font = Enum.Font.GothamBold
cfgTitle.TextSize = 20
cfgTitle.Parent = ConfigFrame
Icons.text(cfgTitle, {icon = Icons.gear, iconSize = 22, gap = 8, color = Color3.fromRGB(170, 170, 185), text = "Configurações"})

local K = {
    card = Color3.fromRGB(30, 30, 36), sub = Color3.fromRGB(150, 150, 165),
    green = Color3.fromRGB(50, 205, 50), off = Color3.fromRGB(62, 62, 70),
    gray = Color3.fromRGB(120, 120, 140),
}

local cfgArea = Instance.new("Frame")
cfgArea.Name = "CfgArea"
cfgArea.BackgroundTransparency = 1
cfgArea.ClipsDescendants = true
cfgArea.Position = UDim2.new(0, 12, 0, 84)
cfgArea.Size = UDim2.new(1, -24, 0, 314)
cfgArea.Parent = ConfigFrame

local function cl(parent, text, size, font, color, pos, sz, xAlign)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.BorderSizePixel = 0
    l.Text = text
    l.TextSize = size
    l.Font = font
    l.TextColor3 = color
    l.Position = pos
    l.Size = sz
    l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd
    l.Parent = parent
    return l
end

local subHeader = Instance.new("Frame")
subHeader.BackgroundTransparency = 1
subHeader.Position = UDim2.new(0, 0, 0, 45)
subHeader.Size = UDim2.new(1, 0, 0, 35)
subHeader.Visible = false
subHeader.Parent = ConfigFrame

local subTitle = Instance.new("TextLabel")
subTitle.BackgroundTransparency = 1
subTitle.Size = UDim2.new(1, 0, 1, 0)
subTitle.Text = ""
subTitle.TextColor3 = WHITE
subTitle.Font = Enum.Font.GothamBold
subTitle.TextSize = 15
subTitle.Parent = subHeader
local subTitleUI = Icons.text(subTitle, {icon = Icons.gear, iconSize = 16, gap = 6, color = K.gray, text = ""})

local backBtn = Instance.new("TextButton")
backBtn.BackgroundTransparency = 1
backBtn.Position = UDim2.new(0, 10, 0, 2)
backBtn.Size = UDim2.new(0, 62, 0, 30)
backBtn.Text = ""
backBtn.Font = Enum.Font.GothamMedium
backBtn.TextSize = 13
backBtn.TextColor3 = K.green
backBtn.ZIndex = 3
backBtn.Parent = subHeader
Icons.text(backBtn, {icon = Icons.back, iconSize = 16, gap = 2, pad = 0, align = "left", color = K.green, text = "Voltar"})

local function newPage()
    local pg = Instance.new("ScrollingFrame")
    pg.Size = UDim2.new(1, 0, 1, 0)
    pg.BackgroundTransparency = 1
    pg.BorderSizePixel = 0
    pg.ScrollBarThickness = 3
    pg.ScrollBarImageColor3 = K.green
    pg.CanvasSize = UDim2.new(0, 0, 0, 0)
    pg.AutomaticCanvasSize = Enum.AutomaticSize.Y
    pg.ScrollingDirection = Enum.ScrollingDirection.Y
    pg.Parent = cfgArea
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = pg
    local pad = Instance.new("UIPadding")
    pad.PaddingBottom = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 5)
    pad.Parent = pg
    return pg
end
local mainPage, wpPage, srvPage = newPage(), newPage(), newPage()

local function sectionLabel(page, text, order)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size = UDim2.new(1, 0, 0, 16)
    l.Text = text
    l.TextColor3 = K.gray
    l.Font = Enum.Font.GothamBold
    l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order
    l.Parent = page
    local pd = Instance.new("UIPadding")
    pd.PaddingLeft = UDim.new(0, 6)
    pd.Parent = l
end

local function newGroup(page, order)
    local g = Instance.new("Frame")
    g.Size = UDim2.new(1, 0, 0, 0)
    g.AutomaticSize = Enum.AutomaticSize.Y
    g.BackgroundColor3 = K.card
    g.BorderSizePixel = 0
    g.LayoutOrder = order
    g.Parent = page
    corner(g, UDim.new(0, 12))
    local l = Instance.new("UIListLayout")
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = g
    return {frame = g, count = 0, order = 0}
end

local function addDivider(g, indent)
    g.order = g.order + 1
    local w = Instance.new("Frame")
    w.BackgroundTransparency = 1
    w.Size = UDim2.new(1, 0, 0, 1)
    w.LayoutOrder = g.order
    w.Parent = g.frame
    local d = Instance.new("Frame")
    d.Position = UDim2.new(0, indent, 0, 0)
    d.Size = UDim2.new(1, -indent, 1, 0)
    d.BackgroundColor3 = WHITE
    d.BackgroundTransparency = 0.91
    d.BorderSizePixel = 0
    d.Parent = w
end

local function makeSwitch(row, default, cb)
    local track = Instance.new("TextButton")
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, -12, 0.5, 0)
    track.Size = UDim2.new(0, 42, 0, 24)
    track.Text = ""
    track.AutoButtonColor = false
    track.BorderSizePixel = 0
    track.Parent = row
    corner(track, UDim.new(1, 0))
    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.BackgroundColor3 = WHITE
    knob.BorderSizePixel = 0
    knob.ZIndex = 2
    knob.Parent = track
    corner(knob, UDim.new(1, 0))
    local state = default and true or false
    local function paintSwitch(animate)
        local col = state and K.green or K.off
        local pos = state and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        if animate then
            TweenService:Create(track, TweenInfo.new(0.15), {BackgroundColor3 = col}):Play()
            TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Position = pos}):Play()
        else
            track.BackgroundColor3 = col
            knob.Position = pos
        end
    end
    paintSwitch(false)
    track.MouseButton1Click:Connect(function()
        state = not state
        paintSwitch(true)
        cb(state)
        saveSettings()
    end)
end

local function addRow(g, o)
    if g.count > 0 then addDivider(g, o.tile and 52 or 14) end
    g.count = g.count + 1
    g.order = g.order + 1
    local h = o.sub and 54 or (o.kind == "value" and 40 or 44)
    local row
    if o.onClick then
        row = Instance.new("TextButton")
        row.Text = ""
        row.AutoButtonColor = false
    else
        row = Instance.new("Frame")
    end
    row.Size = UDim2.new(1, 0, 0, h)
    row.BackgroundColor3 = WHITE
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.LayoutOrder = g.order
    row.Parent = g.frame
    corner(row, UDim.new(0, 10))

    if o.onClick then
        row.MouseButton1Down:Connect(function() TweenService:Create(row, TweenInfo.new(0.08), {BackgroundTransparency = 0.9}):Play() end)
        local function up() TweenService:Create(row, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play() end
        row.MouseButton1Up:Connect(up)
        row.MouseLeave:Connect(up)
        row.MouseButton1Click:Connect(o.onClick)
    end

    local tx = 14
    if o.tile then
        local tile = Instance.new("Frame")
        tile.Position = UDim2.new(0, 12, 0.5, -14)
        tile.Size = UDim2.new(0, 28, 0, 28)
        tile.BackgroundColor3 = o.tile
        tile.BorderSizePixel = 0
        tile.Parent = row
        corner(tile, UDim.new(0, 7))
        Icons.put(tile, o.icon, 17, WHITE)
        tx = 52
    end

    local rightPad = (o.kind == "switch") and 64 or ((o.kind == "chevron") and 32 or 12)
    local ui = {row = row}
    if o.kind == "value" then
        cl(row, o.title, 13, Enum.Font.GothamMedium, WHITE, UDim2.new(0, tx, 0, 0), UDim2.new(0.5, -tx, 1, 0))
        ui.value = cl(row, o.value or "", 12, Enum.Font.Code, WHITE, UDim2.new(0.5, 0, 0, 0), UDim2.new(0.5, -12, 1, 0), Enum.TextXAlignment.Right)
    else
        local tl = cl(row, o.title, 13, Enum.Font.GothamMedium, WHITE, UDim2.new(0, tx, 0, o.sub and 8 or 0), UDim2.new(1, -(tx + rightPad), 0, o.sub and 18 or h))
        ui.title = tl
        if o.sub then
            local sl = cl(row, o.sub, 10, Enum.Font.Gotham, K.sub, UDim2.new(0, tx, 0, 26), UDim2.new(1, -(tx + rightPad), 0, 24))
            sl.TextWrapped = true
            sl.TextYAlignment = Enum.TextYAlignment.Top
        end
    end

    if o.kind == "switch" then
        makeSwitch(row, o.state, o.onToggle)
    elseif o.kind == "chevron" then
        local ic = Icons.chevronRight(row, 16, K.gray, 2)
        ic.AnchorPoint = Vector2.new(1, 0.5)
        ic.Position = UDim2.new(1, -10, 0.5, 0)
    end
    return ui
end

local pages = {main = mainPage, wallpaper = wpPage, server = srvPage}
local pageState = {}
local currentPage = "main"

local function setPageState(pg, state, animate)
    local pos = state == "active" and UDim2.new(0, 0, 0, 0)
        or (state == "left" and UDim2.new(-0.3, 0, 0, 0) or UDim2.new(1, 0, 0, 0))
    if state == "active" then pg.Visible = true end
    if animate then
        local tw = TweenService:Create(pg, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = pos})
        tw:Play()
        if state ~= "active" then
            tw.Completed:Once(function()
                if pageState[pg] == state then pg.Visible = false end
            end)
        end
    else
        pg.Position = pos
        pg.Visible = state == "active"
    end
end

local updateServer
local wpPreview

local function showPage(name, animate)
    currentPage = name
    for n, pg in pairs(pages) do
        local st = (n == name) and "active" or ((n == "main") and "left" or "right")
        pageState[pg] = st
        setPageState(pg, st, animate)
    end
    cfgTitle.Visible = name == "main"
    subHeader.Visible = name ~= "main"
    if name == "wallpaper" then
        subTitleUI.set(Icons.gallery, "Wallpaper", Color3.fromRGB(180, 80, 220))
        wpPreview.Image = currentWallpaper
    elseif name == "server" then
        subTitleUI.set(Icons.tower, "Servidor", Color3.fromRGB(0, 180, 255))
        updateServer()
    end
end

function cfgGoBack()
    if currentPage ~= "main" then
        showPage("main", true)
        return true
    end
    return false
end

function cfgReset()
    showPage("main", false)
    mainPage.CanvasPosition = Vector2.new(0, 0)
end

backBtn.MouseButton1Click:Connect(function() cfgGoBack() end)

local prof = Instance.new("Frame")
prof.Size = UDim2.new(1, 0, 0, 62)
prof.BackgroundColor3 = K.card
prof.BorderSizePixel = 0
prof.LayoutOrder = 1
prof.Parent = mainPage
corner(prof, UDim.new(0, 12))
local avatar = Instance.new("Frame")
avatar.Position = UDim2.new(0, 12, 0.5, -20)
avatar.Size = UDim2.new(0, 40, 0, 40)
avatar.BackgroundColor3 = K.green
avatar.BorderSizePixel = 0
avatar.Parent = prof
corner(avatar, UDim.new(1, 0))
local av = cl(avatar, string.upper(string.sub(Player.DisplayName ~= "" and Player.DisplayName or Player.Name, 1, 1)), 20, Enum.Font.GothamBold, Color3.new(0, 0, 0), UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), Enum.TextXAlignment.Center)
cl(prof, Player.DisplayName ~= "" and Player.DisplayName or Player.Name, 15, Enum.Font.GothamBold, WHITE, UDim2.new(0, 62, 0, 12), UDim2.new(1, -74, 0, 20))
cl(prof, "@" .. Player.Name, 11, Enum.Font.Gotham, K.sub, UDim2.new(0, 62, 0, 33), UDim2.new(1, -74, 0, 16))

sectionLabel(mainPage, "GERAL", 2)
local gGeral = newGroup(mainPage, 3)
addRow(gGeral, {icon = Icons.gauge, tile = Color3.fromRGB(50, 205, 50), title = "FPS Counter", sub = "Mostra o FPS na barra de status",
    kind = "switch", state = phoneSettings.fpsEnabled, onToggle = function(on)
        phoneSettings.fpsEnabled = on
        Nav.status.applyFps()
    end})
addRow(gGeral, {icon = Icons.torch, tile = Color3.fromRGB(255, 170, 0), title = "Lanterna", sub = "Luz fraca na frente do personagem",
    kind = "switch", state = phoneSettings.flashlightEnabled, onToggle = function(on)
        phoneSettings.flashlightEnabled = on
        if on then
            if phoneFlashlight then phoneFlashlight:Destroy() end
            local root = Character and Character:FindFirstChild("HumanoidRootPart")
            if root then
                phoneFlashlight = Instance.new("SpotLight")
                phoneFlashlight.Name = "PhoneFlashlight"
                phoneFlashlight.Brightness = 2.5
                phoneFlashlight.Range = 35
                phoneFlashlight.Angle = 50
                phoneFlashlight.Face = Enum.NormalId.Front
                phoneFlashlight.Parent = root
            end
        else
            if phoneFlashlight then
                phoneFlashlight:Destroy()
                phoneFlashlight = nil
            end
        end
    end})
addRow(gGeral, {icon = Icons.gesture, tile = Color3.fromRGB(60, 130, 255), title = "Navegação por gestos", sub = "Barra de gestos no lugar dos 3 botões",
    kind = "switch", state = phoneSettings.gestureNav, onToggle = function(on)
        phoneSettings.gestureNav = on
        applyNavMode()
    end})

sectionLabel(mainPage, "PERSONALIZAÇÃO", 4)
local gPers = newGroup(mainPage, 5)
addRow(gPers, {icon = Icons.gallery, tile = Color3.fromRGB(180, 80, 220), title = "Wallpaper", kind = "chevron",
    onClick = function() showPage("wallpaper", true) end})
local caseRow
caseRow = addRow(gPers, {icon = Icons.phone, tile = Color3.fromRGB(235, 140, 60), title = "Cor da carcaça", kind = "value",
    value = Nav.shell.label(), onClick = function()
        caseRow.value.Text = Nav.shell.nextTheme()
    end})

sectionLabel(mainPage, "SISTEMA", 6)
local gSys = newGroup(mainPage, 7)
addRow(gSys, {icon = Icons.tower, tile = Color3.fromRGB(0, 170, 210), title = "Info do Servidor", kind = "chevron",
    onClick = function() showPage("server", true) end})

local wpPrevCard = Instance.new("Frame")
wpPrevCard.Size = UDim2.new(1, 0, 0, 150)
wpPrevCard.BackgroundColor3 = K.card
wpPrevCard.BorderSizePixel = 0
wpPrevCard.LayoutOrder = 1
wpPrevCard.Parent = wpPage
corner(wpPrevCard, UDim.new(0, 14))
wpPreview = Instance.new("ImageLabel")
wpPreview.Position = UDim2.new(0, 6, 0, 6)
wpPreview.Size = UDim2.new(1, -12, 1, -12)
wpPreview.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
wpPreview.BorderSizePixel = 0
wpPreview.Image = currentWallpaper
wpPreview.ScaleType = Enum.ScaleType.Crop
wpPreview.Parent = wpPrevCard
corner(wpPreview, UDim.new(0, 10))

local wpCard = Instance.new("Frame")
wpCard.Size = UDim2.new(1, 0, 0, 98)
wpCard.BackgroundColor3 = K.card
wpCard.BorderSizePixel = 0
wpCard.LayoutOrder = 2
wpCard.Parent = wpPage
corner(wpCard, UDim.new(0, 12))

local wpInput = Instance.new("TextBox")
wpInput.Position = UDim2.new(0, 12, 0, 12)
wpInput.Size = UDim2.new(1, -24, 0, 34)
wpInput.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
wpInput.PlaceholderText = "rbxassetid:// ou ID numérico"
wpInput.PlaceholderColor3 = Color3.fromRGB(110, 110, 130)
wpInput.Text = ""
wpInput.TextColor3 = WHITE
wpInput.Font = Enum.Font.Gotham
wpInput.TextSize = 12
wpInput.ClearTextOnFocus = false
wpInput.Parent = wpCard
corner(wpInput, UDim.new(0, 8))

local function wpButton(text, xScale, xOff, bg, fg)
    local b = Instance.new("TextButton")
    b.Position = UDim2.new(xScale, xOff, 0, 54)
    b.Size = UDim2.new(0.5, -18, 0, 34)
    b.BackgroundColor3 = bg
    b.Text = text
    b.TextColor3 = fg
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.Parent = wpCard
    corner(b, UDim.new(0, 8))
    return b
end
local wpApplyBtn = wpButton("Aplicar", 0, 12, K.green, Color3.new(0, 0, 0))
local wpResetBtn = wpButton("Padrão", 0.5, 6, Color3.fromRGB(60, 60, 70), WHITE)

local wpHint = cl(wpPage, "Cole o ID de uma imagem (decal) do Roblox e toque em Aplicar.", 10, Enum.Font.Gotham, K.gray, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 28))
wpHint.TextWrapped = true
wpHint.TextYAlignment = Enum.TextYAlignment.Top
wpHint.LayoutOrder = 3
local wpHintPad = Instance.new("UIPadding")
wpHintPad.PaddingLeft = UDim.new(0, 6)
wpHintPad.Parent = wpHint

local function applyWallpaper(id)
    if not id or id == "" then return end
    if not id:find("rbxassetid://") then
        id = "rbxassetid://" .. id:gsub("%D", "")
    end
    currentWallpaper = id
    phoneSettings.wallpaper = id
    phoneSettings.wallpaperFile = nil
    homeBg.Image = id
    wpPreview.Image = id
    saveSettings()
end
wpApplyBtn.MouseButton1Click:Connect(function() applyWallpaper(wpInput.Text) end)
wpResetBtn.MouseButton1Click:Connect(function()
    applyWallpaper(defaultSettings.wallpaper)
    wpInput.Text = ""
end)

local gSrv = newGroup(srvPage, 1)
local srv = {
    players = addRow(gSrv, {title = "Jogadores", kind = "value", value = "-"}),
    time = addRow(gSrv, {title = "Tempo online", kind = "value", value = "-"}),
    ping = addRow(gSrv, {title = "Ping", kind = "value", value = "-"}),
    job = addRow(gSrv, {title = "ID do servidor", kind = "value", value = "-"}),
    place = addRow(gSrv, {title = "ID do lugar", kind = "value", value = "-"}),
}

local sessionStart = os.clock()
local function fmtOnline(sec)
    sec = math.floor(sec)
    local h, m, s = math.floor(sec / 3600), math.floor((sec % 3600) / 60), sec % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%02d:%02d", m, s)
end

function updateServer()
    local ping = 0
    pcall(function()
        ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
    end)
    srv.players.value.Text = string.format("%d / %d", #Players:GetPlayers(), Players.MaxPlayers)
    srv.time.value.Text = fmtOnline(os.clock() - sessionStart)
    srv.ping.value.Text = ping .. " ms"
    srv.ping.value.TextColor3 = ping <= 80 and K.green or (ping <= 150 and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(255, 95, 95))
    local jid = game.JobId
    srv.job.value.Text = jid ~= "" and string.sub(jid, 1, 8) or "local"
    srv.place.value.Text = tostring(game.PlaceId)
end

task.spawn(function()
    while true do
        task.wait(1)
        if ConfigFrame.Visible and currentPage == "server" then
            pcall(updateServer)
        end
    end
end)

showPage("main", false)
createNavBar(ConfigFrame)
end

do

local ACC = Color3.fromRGB(180, 80, 220)
local DARK = Color3.fromRGB(22, 22, 28)
local STAGE_W, STAGE_H = 264, 268

phoneSettings.favorites = type(phoneSettings.favorites) == "table" and phoneSettings.favorites or {}
local favs = phoneSettings.favorites

local tabMode = "all"
local gridToken = 0
local zoom, panX, panY = 1, 0, 0
local assetCache = {}
local lastTap = 0

local function uiScale() return (phoneUIScale and phoneUIScale.Scale) or 1 end

-- Fotos "virtuais" (ViewportFrame) vindas da Câmera: renderiza a cena congelada dentro de 'parent'
local PhotoDisplay
local function removeVF(entry)
    local list = _G.TZE_GalleryVF
    if not list then return end
    for i, e in ipairs(list) do
        if e == entry then
            table.remove(list, i)
            if e.photo and e.photo.vf then pcall(function() e.photo.vf:Destroy() end) end
            break
        end
    end
end

local function clearVFDisplay()
    local h = PhotoDisplay and PhotoDisplay:FindFirstChild("VFHolder")
    if h then h:Destroy() end
end

local function getAsset(path)
    if tostring(path):sub(1, 5) == "vf://" then return nil end
    if assetCache[path] then return assetCache[path] end
    -- arquivos .camphoto são criados pelo app Câmera e contêm o rbxassetid direto
    if tostring(path):match("%.camphoto$") then
        local okR, data = pcall(readfile, path)
        if okR and data and data ~= "" then
            local id = data:match("^%s*(.-)%s*$") -- trim
            if id ~= "" then assetCache[path] = id return id end
        end
        return nil
    end
    local ok, a = pcall(getcustomasset, path)
    if ok and a and a ~= "" then assetCache[path] = a return a end
    return nil
end

-- GIF: Roblox nao anima .gif, entao os quadros sao decodificados em PNG (Nav.gif)
local Gif = Nav.gif
local gifToken = 0
local gifState = {playing = true, smooth = true}

-- 1o quadro do GIF (miniatura / papel de parede); gera na hora se ainda nao existir
-- FIX: a chave do cache vem do NOME + CONTEUDO do arquivo (nao so do nome), memorizada por caminho.
-- Assim GIFs diferentes com o mesmo nome nunca dividem a mesma pasta de quadros.
local gifKeyMemo = {}
local function gifKeyFor(photo, data)
    local m = gifKeyMemo[photo.path]
    if m then return m end
    if type(data) ~= "string" then
        local okR, d = pcall(readfile, photo.path)
        if not okR or type(d) ~= "string" then return nil end
        data = d
    end
    local key = Gif.keyFor(photo.file, data)
    gifKeyMemo[photo.path] = key
    return key
end

local function gifThumbAsset(photo)
    local key = gifKeyFor(photo)
    if not key then return nil end
    local p = Gif.thumbPath(key)
    if not p then
        local okR, data = pcall(readfile, photo.path)
        if okR and type(data) == "string" and #data > 20 then
            p = Gif.makeThumb(key, data, {maxDim = 160, yield = task.wait})
        end
    end
    return p and Gif.asset(p) or nil
end

GalleryFrame = Instance.new("Frame")
GalleryFrame.Name = "GalleryFrame"
GalleryFrame.Size = UDim2.new(0, 280, 0, 440)
GalleryFrame.Position = PhoneHome.Position
GalleryFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
GalleryFrame.BorderSizePixel = 0
GalleryFrame.Visible = false
GalleryFrame.Active = true
GalleryFrame.Parent = ScreenGui
corner(GalleryFrame, UDim.new(0, 28))

Nav.shell.create(GalleryFrame)
Nav.status.create(GalleryFrame)

local galTitle = Instance.new("TextLabel")
galTitle.Size = UDim2.new(0.6, 0, 0, 28)
galTitle.Position = UDim2.new(0, 16, 0, 40)
galTitle.BackgroundTransparency = 1
galTitle.Text = "Galeria"
galTitle.TextColor3 = Color3.new(1, 1, 1)
galTitle.Font = Enum.Font.GothamBold
galTitle.TextSize = 22
galTitle.TextXAlignment = Enum.TextXAlignment.Left
galTitle.Parent = GalleryFrame

local countLabel = Instance.new("TextLabel")
countLabel.Size = UDim2.new(0.4, -16, 0, 28)
countLabel.Position = UDim2.new(0.6, 0, 0, 40)
countLabel.BackgroundTransparency = 1
countLabel.Text = ""
countLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
countLabel.Font = Enum.Font.Gotham
countLabel.TextSize = 12
countLabel.TextXAlignment = Enum.TextXAlignment.Right
countLabel.Parent = GalleryFrame

local tabs = Instance.new("Frame")
tabs.Size = UDim2.new(1, -24, 0, 30)
tabs.Position = UDim2.new(0, 12, 0, 74)
tabs.BackgroundColor3 = DARK
tabs.BorderSizePixel = 0
tabs.Parent = GalleryFrame
corner(tabs, UDim.new(0, 15))

local function makeTab(text, x)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.5, -4, 1, -6)
    b.Position = UDim2.new(x, x == 0 and 3 or 1, 0, 3)
    b.BackgroundColor3 = ACC
    b.BackgroundTransparency = 1
    b.Text = text
    b.TextColor3 = Color3.fromRGB(150, 150, 170)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.AutoButtonColor = false
    b.Parent = tabs
    corner(b, UDim.new(1, 0))
    return b
end
local tabAll = makeTab("Todas", 0)
local tabFav = makeTab("Favoritas", 0.5)
local tabFavUI = Icons.text(tabFav, {icon = Icons.heart, iconSize = 14, gap = 5, color = Color3.fromRGB(150, 150, 170), text = "Favoritas"})

local PhotoSearchBox = Instance.new("TextBox")
PhotoSearchBox.Size = UDim2.new(1, -24, 0, 30)
PhotoSearchBox.Position = UDim2.new(0, 12, 0, 110)
PhotoSearchBox.BackgroundColor3 = DARK
PhotoSearchBox.PlaceholderText = "Pesquisar..."
PhotoSearchBox.Text = ""
PhotoSearchBox.TextColor3 = Color3.new(1, 1, 1)
PhotoSearchBox.PlaceholderColor3 = Color3.fromRGB(110, 110, 130)
PhotoSearchBox.Font = Enum.Font.Gotham
PhotoSearchBox.TextSize = 12
PhotoSearchBox.ClearTextOnFocus = false
PhotoSearchBox.TextXAlignment = Enum.TextXAlignment.Left
PhotoSearchBox.TextWrapped = false
PhotoSearchBox.ClipsDescendants = true
do
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 34)
    pad.PaddingRight = UDim.new(0, 14)
    pad.Parent = PhotoSearchBox
end
PhotoSearchBox.Parent = GalleryFrame
corner(PhotoSearchBox, UDim.new(1, 0))
do
    local lupa = Icons.searchField(PhotoSearchBox, 14, 12)
    lupa.Position = UDim2.new(0, 12 - 34, 0.5, 0)
end

local PhotoScrollList = Instance.new("ScrollingFrame")
PhotoScrollList.Size = UDim2.new(1, -16, 0, 252)
PhotoScrollList.Position = UDim2.new(0, 8, 0, 148)
PhotoScrollList.BackgroundTransparency = 1
PhotoScrollList.BorderSizePixel = 0
PhotoScrollList.ScrollBarThickness = 3
PhotoScrollList.ScrollBarImageColor3 = ACC
PhotoScrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
PhotoScrollList.Parent = GalleryFrame

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0, 80, 0, 80)
grid.CellPadding = UDim2.new(0, 5, 0, 5)
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = PhotoScrollList

local PhotoViewerView = Instance.new("Frame")
PhotoViewerView.Name = "PhotoViewerView"
PhotoViewerView.Size = UDim2.new(1, 0, 1, 0)
PhotoViewerView.BackgroundColor3 = Color3.new(0, 0, 0)
PhotoViewerView.BorderSizePixel = 0
PhotoViewerView.Visible = false
PhotoViewerView.Parent = GalleryFrame
corner(PhotoViewerView, UDim.new(0, 28))

local function roundBtn(text, pos, size, parent, z)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = pos
    b.BackgroundColor3 = Color3.fromRGB(36, 36, 46)
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.AutoButtonColor = true
    b.ZIndex = z or 1
    b.Parent = parent
    corner(b, UDim.new(0, 12))
    return b
end

local viewBack = roundBtn("", UDim2.new(0, 12, 0, 38), UDim2.new(0, 32, 0, 32), PhotoViewerView)
local PhotoMenuBtn = roundBtn("", UDim2.new(1, -44, 0, 38), UDim2.new(0, 32, 0, 32), PhotoViewerView, 25)
PhotoMenuBtn.TextSize = 18
Icons.put(viewBack, Icons.back, 18, WHITE)
Icons.put(PhotoMenuBtn, Icons.dotsV, 20, WHITE)

local PhotoNameLabel = Instance.new("TextLabel")
PhotoNameLabel.Size = UDim2.new(1, -100, 0, 32)
PhotoNameLabel.Position = UDim2.new(0, 50, 0, 38)
PhotoNameLabel.BackgroundTransparency = 1
PhotoNameLabel.Text = ""
PhotoNameLabel.TextColor3 = Color3.new(1, 1, 1)
PhotoNameLabel.Font = Enum.Font.GothamBold
PhotoNameLabel.TextSize = 13
PhotoNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
PhotoNameLabel.Parent = PhotoViewerView

local stage = Instance.new("Frame")
stage.Size = UDim2.new(0, STAGE_W, 0, STAGE_H)
stage.Position = UDim2.new(0.5, -STAGE_W / 2, 0, 76)
stage.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
stage.BorderSizePixel = 0
stage.ClipsDescendants = true
stage.Parent = PhotoViewerView
corner(stage, UDim.new(0, 12))

PhotoDisplay = Instance.new("ImageLabel")
PhotoDisplay.Name = "PhotoDisplay"
PhotoDisplay.AnchorPoint = Vector2.new(0.5, 0.5)
PhotoDisplay.Position = UDim2.new(0.5, 0, 0.5, 0)
PhotoDisplay.Size = UDim2.new(0, STAGE_W, 0, STAGE_H)
PhotoDisplay.BackgroundTransparency = 1
PhotoDisplay.ScaleType = Enum.ScaleType.Fit
PhotoDisplay.Parent = stage

local gifBadge = Instance.new("TextButton")
gifBadge.Name = "GifBadge"
gifBadge.AnchorPoint = Vector2.new(1, 0)
gifBadge.Position = UDim2.new(1, -8, 0, 8)
gifBadge.Size = UDim2.new(0, 0, 0, 22)
gifBadge.AutomaticSize = Enum.AutomaticSize.X
gifBadge.BackgroundColor3 = Color3.new(0, 0, 0)
gifBadge.BackgroundTransparency = 0.3
gifBadge.BorderSizePixel = 0
gifBadge.Text = "GIF"
gifBadge.TextColor3 = Color3.new(1, 1, 1)
gifBadge.Font = Enum.Font.GothamBold
gifBadge.TextSize = 10
gifBadge.AutoButtonColor = false
gifBadge.Visible = false
gifBadge.ZIndex = 8
gifBadge.Parent = stage
corner(gifBadge, UDim.new(0, 11))
do
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 9)
    pad.PaddingRight = UDim.new(0, 9)
    pad.Parent = gifBadge
end

local PhotoDisplay2 = Instance.new("ImageLabel")
PhotoDisplay2.Name = "PhotoDisplay2"
PhotoDisplay2.Size = UDim2.new(1, 0, 1, 0)
PhotoDisplay2.BackgroundTransparency = 1
PhotoDisplay2.ScaleType = Enum.ScaleType.Fit
PhotoDisplay2.ImageTransparency = 1
PhotoDisplay2.Visible = false
PhotoDisplay2.ZIndex = 2
PhotoDisplay2.Parent = PhotoDisplay

local gifSmooth = Instance.new("TextButton")
gifSmooth.Name = "GifSmooth"
gifSmooth.AnchorPoint = Vector2.new(1, 0)
gifSmooth.Position = UDim2.new(1, -8, 0, 34)
gifSmooth.Size = UDim2.new(0, 0, 0, 22)
gifSmooth.AutomaticSize = Enum.AutomaticSize.X
gifSmooth.BackgroundColor3 = Color3.new(0, 0, 0)
gifSmooth.BackgroundTransparency = 0.3
gifSmooth.BorderSizePixel = 0
gifSmooth.Text = "60 FPS"
gifSmooth.TextColor3 = Color3.fromRGB(120, 255, 160)
gifSmooth.Font = Enum.Font.GothamBold
gifSmooth.TextSize = 10
gifSmooth.AutoButtonColor = false
gifSmooth.Visible = false
gifSmooth.ZIndex = 8
gifSmooth.Parent = stage
corner(gifSmooth, UDim.new(0, 11))
do
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 9)
    pad.PaddingRight = UDim.new(0, 9)
    pad.Parent = gifSmooth
end

local function hideGifUI()
    gifBadge.Visible = false
    gifSmooth.Visible = false
    PhotoDisplay2.Visible = false
    PhotoDisplay2.Image = ""
end

local touchArea = Instance.new("TextButton")
touchArea.Size = UDim2.new(1, 0, 1, 0)
touchArea.BackgroundTransparency = 1
touchArea.Text = ""
touchArea.ZIndex = 5
touchArea.Parent = stage

local counter = Instance.new("TextLabel")
counter.Size = UDim2.new(1, 0, 0, 16)
counter.Position = UDim2.new(0, 0, 0, 350)
counter.BackgroundTransparency = 1
counter.Text = ""
counter.TextColor3 = Color3.fromRGB(150, 150, 170)
counter.Font = Enum.Font.Gotham
counter.TextSize = 11
counter.Parent = PhotoViewerView

local ctrlRow = Instance.new("Frame")
ctrlRow.Size = UDim2.new(1, -24, 0, 34)
ctrlRow.Position = UDim2.new(0, 12, 0, 366)
ctrlRow.BackgroundTransparency = 1
ctrlRow.Parent = PhotoViewerView
local ctrlLayout = Instance.new("UIListLayout")
ctrlLayout.FillDirection = Enum.FillDirection.Horizontal
ctrlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ctrlLayout.Padding = UDim.new(0, 10)
ctrlLayout.Parent = ctrlRow

local prevPhotoBtn = roundBtn("", UDim2.new(), UDim2.new(0, 54, 0, 34), ctrlRow)
local favBtn = roundBtn("", UDim2.new(), UDim2.new(0, 54, 0, 34), ctrlRow)
local nextPhotoBtn = roundBtn("", UDim2.new(), UDim2.new(0, 54, 0, 34), ctrlRow)
for i, b in ipairs({prevPhotoBtn, favBtn, nextPhotoBtn}) do b.LayoutOrder = i; b.Size = UDim2.new(0, 70, 0, 34) end
Icons.put(prevPhotoBtn, Icons.back, 18, WHITE)
Icons.put(favBtn, Icons.heart, 18, Color3.fromRGB(140, 140, 160))
Icons.put(nextPhotoBtn, Icons.chevronRight, 18, WHITE)

local menuBackdrop = Instance.new("TextButton")
menuBackdrop.Size = UDim2.new(1, 0, 1, 0)
menuBackdrop.BackgroundColor3 = Color3.new(0, 0, 0)
menuBackdrop.BackgroundTransparency = 1
menuBackdrop.Text = ""
menuBackdrop.AutoButtonColor = false
menuBackdrop.Visible = false
menuBackdrop.ZIndex = 28
menuBackdrop.Parent = PhotoViewerView
corner(menuBackdrop, UDim.new(0, 28))

local PhotoMenuFrame = Instance.new("Frame")
PhotoMenuFrame.Size = UDim2.new(0, 214, 0, 0)
PhotoMenuFrame.AutomaticSize = Enum.AutomaticSize.Y
PhotoMenuFrame.AnchorPoint = Vector2.new(1, 0)
PhotoMenuFrame.Position = UDim2.new(1, -12, 0, 76)
PhotoMenuFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
PhotoMenuFrame.BorderSizePixel = 0
PhotoMenuFrame.Visible = false
PhotoMenuFrame.ZIndex = 30
PhotoMenuFrame.Parent = PhotoViewerView
corner(PhotoMenuFrame, UDim.new(0, 16))
local menuStroke = Instance.new("UIStroke")
menuStroke.Color = Color3.new(1, 1, 1)
menuStroke.Transparency = 0.85
menuStroke.Thickness = 1.2
menuStroke.Parent = PhotoMenuFrame
local menuPad = Instance.new("UIPadding")
menuPad.PaddingTop = UDim.new(0, 8)
menuPad.PaddingBottom = UDim.new(0, 8)
menuPad.PaddingLeft = UDim.new(0, 8)
menuPad.PaddingRight = UDim.new(0, 8)
menuPad.Parent = PhotoMenuFrame
local menuList = Instance.new("UIListLayout")
menuList.Padding = UDim.new(0, 3)
menuList.SortOrder = Enum.SortOrder.LayoutOrder
menuList.Parent = PhotoMenuFrame

local menuName = Instance.new("TextLabel")
menuName.Size = UDim2.new(1, 0, 0, 18)
menuName.BackgroundTransparency = 1
menuName.TextColor3 = Color3.new(1, 1, 1)
menuName.Font = Enum.Font.GothamBold
menuName.TextSize = 13
menuName.TextXAlignment = Enum.TextXAlignment.Left
menuName.TextTruncate = Enum.TextTruncate.AtEnd
menuName.ZIndex = 32
menuName.LayoutOrder = 1
menuName.Parent = PhotoMenuFrame

local menuSub = menuName:Clone()
menuSub.Size = UDim2.new(1, 0, 0, 14)
menuSub.Font = Enum.Font.Gotham
menuSub.TextSize = 10
menuSub.TextColor3 = Color3.fromRGB(140, 140, 160)
menuSub.LayoutOrder = 2
menuSub.Parent = PhotoMenuFrame

local menuDivider = Instance.new("Frame")
menuDivider.Size = UDim2.new(1, 0, 0, 1)
menuDivider.BackgroundColor3 = Color3.new(1, 1, 1)
menuDivider.BackgroundTransparency = 0.88
menuDivider.BorderSizePixel = 0
menuDivider.ZIndex = 32
menuDivider.LayoutOrder = 3
menuDivider.Parent = PhotoMenuFrame

local function menuRow(glyph, text, order, tileColor, textColor)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = false
    row.ZIndex = 32
    row.LayoutOrder = order
    row.Parent = PhotoMenuFrame
    corner(row, UDim.new(0, 10))
    local tile = Instance.new("TextLabel")
    tile.Size = UDim2.new(0, 26, 0, 26)
    tile.Position = UDim2.new(0, 6, 0.5, -13)
    tile.BackgroundColor3 = tileColor
    tile.Text = ""
    tile.TextColor3 = Color3.new(1, 1, 1)
    tile.Font = Enum.Font.GothamBold
    tile.TextSize = 13
    tile.ZIndex = 33
    tile.Parent = row
    corner(tile, UDim.new(0, 8))
    Icons.put(tile, glyph, 15, Color3.new(1, 1, 1), 34)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -44, 1, 0)
    lbl.Position = UDim2.new(0, 40, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = textColor or Color3.new(1, 1, 1)
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 33
    lbl.Parent = row
    row.MouseButton1Down:Connect(function() TweenService:Create(row, TweenInfo.new(0.08), {BackgroundTransparency = 0.9}):Play() end)
    local function up() TweenService:Create(row, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play() end
    row.MouseButton1Up:Connect(up)
    row.MouseLeave:Connect(up)
    return row, lbl, tile
end

local favMenuBtn, favMenuLbl = menuRow(Icons.heart, "Adicionar aos favoritos", 4, Color3.fromRGB(255, 70, 100))
local setWallpaperMenuBtn = menuRow(Icons.wallpaper, "Definir como wallpaper", 5, Color3.fromRGB(90, 120, 255))
local infoMenuBtn = menuRow(Icons.info, "Informações", 6, Color3.fromRGB(0, 170, 200))
local deletePhotoMenuBtn, deleteLbl = menuRow(Icons.close, "Excluir foto", 8, Color3.fromRGB(210, 50, 60), Color3.fromRGB(255, 110, 120))

local infoText = Instance.new("TextLabel")
infoText.Size = UDim2.new(1, 0, 0, 0)
infoText.AutomaticSize = Enum.AutomaticSize.Y
infoText.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
infoText.Text = ""
infoText.TextColor3 = Color3.fromRGB(170, 170, 190)
infoText.Font = Enum.Font.Gotham
infoText.TextSize = 10
infoText.TextWrapped = true
infoText.TextXAlignment = Enum.TextXAlignment.Left
infoText.Visible = false
infoText.ZIndex = 32
infoText.LayoutOrder = 7
infoText.Parent = PhotoMenuFrame
corner(infoText, UDim.new(0, 8))
local infoPad = Instance.new("UIPadding")
infoPad.PaddingTop = UDim.new(0, 6)
infoPad.PaddingBottom = UDim.new(0, 6)
infoPad.PaddingLeft = UDim.new(0, 8)
infoPad.PaddingRight = UDim.new(0, 8)
infoPad.Parent = infoText

local confirmRow = Instance.new("Frame")
confirmRow.Size = UDim2.new(1, 0, 0, 38)
confirmRow.BackgroundTransparency = 1
confirmRow.Visible = false
confirmRow.ZIndex = 32
confirmRow.LayoutOrder = 9
confirmRow.Parent = PhotoMenuFrame
local cancelDelBtn = Instance.new("TextButton")
cancelDelBtn.Size = UDim2.new(0.5, -3, 1, 0)
cancelDelBtn.BackgroundColor3 = Color3.fromRGB(44, 44, 56)
cancelDelBtn.Text = "Cancelar"
cancelDelBtn.TextColor3 = Color3.new(1, 1, 1)
cancelDelBtn.Font = Enum.Font.GothamBold
cancelDelBtn.TextSize = 12
cancelDelBtn.ZIndex = 33
cancelDelBtn.Parent = confirmRow
corner(cancelDelBtn, UDim.new(0, 10))
local confirmDelBtn = cancelDelBtn:Clone()
confirmDelBtn.Position = UDim2.new(0.5, 3, 0, 0)
confirmDelBtn.BackgroundColor3 = Color3.fromRGB(200, 45, 55)
confirmDelBtn.Text = "Excluir"
confirmDelBtn.Parent = confirmRow

local function refreshMenu()
    local p = filteredPhotoList[currentPhotoIndex]
    if not p then return end
    menuName.Text = p.name
    local ext = (p.file:match("%.(%w+)$") or "?"):upper()
    menuSub.Text = ext .. "  •  " .. currentPhotoIndex .. " de " .. #filteredPhotoList
    favMenuLbl.Text = favs[p.file] and "Remover dos favoritos" or "Adicionar aos favoritos"
    infoText.Text = "Arquivo: " .. p.file .. "\nPasta: " .. tostring(p.path):gsub("\\", "/"):gsub("[^/]+$", "")
end

function closePhotoMenu()
    isPhotoMenuOpen = false
    PhotoMenuFrame.Visible = false
    menuBackdrop.Visible = false
    infoText.Visible = false
    confirmRow.Visible = false
    deletePhotoMenuBtn.Visible = true
end

local function openPhotoMenu()
    refreshMenu()
    isPhotoMenuOpen = true
    menuBackdrop.BackgroundTransparency = 1
    menuBackdrop.Visible = true
    PhotoMenuFrame.Position = UDim2.new(1, -12, 0, 66)
    PhotoMenuFrame.Visible = true
    TweenService:Create(menuBackdrop, TweenInfo.new(0.18), {BackgroundTransparency = 0.45}):Play()
    TweenService:Create(PhotoMenuFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = UDim2.new(1, -12, 0, 76)}):Play()
end

PhotoMenuBtn.MouseButton1Click:Connect(function()
    if isPhotoMenuOpen then closePhotoMenu() else openPhotoMenu() end
end)
menuBackdrop.MouseButton1Click:Connect(closePhotoMenu)
infoMenuBtn.MouseButton1Click:Connect(function() infoText.Visible = not infoText.Visible end)
deletePhotoMenuBtn.MouseButton1Click:Connect(function()
    deletePhotoMenuBtn.Visible = false
    confirmRow.Visible = true
end)
cancelDelBtn.MouseButton1Click:Connect(function()
    confirmRow.Visible = false
    deletePhotoMenuBtn.Visible = true
end)

local function applyTransform()
    local maxX = (zoom - 1) * STAGE_W / 2
    local maxY = (zoom - 1) * STAGE_H / 2
    panX = math.clamp(panX, -maxX, maxX)
    panY = math.clamp(panY, -maxY, maxY)
    PhotoDisplay.Size = UDim2.new(0, STAGE_W * zoom, 0, STAGE_H * zoom)
    PhotoDisplay.Position = UDim2.new(0.5, panX, 0.5, panY)
end
local function resetZoom()
    zoom, panX, panY = 1, 0, 0
    applyTransform()
end

local function keyOf(photo) return photo.file end
local function refreshFavBtn()
    local p = filteredPhotoList[currentPhotoIndex]
    local on = p and favs[keyOf(p)]
    local favCol = on and Color3.fromRGB(255, 70, 100) or Color3.fromRGB(140, 140, 160)
    favBtn.TextColor3 = favCol
    local favIc = favBtn:FindFirstChild("IconHolder")
    if favIc then Icons.setColor(favIc, favCol) end
end

local updatePhotoList
local openPhotoByIndex

function exitPhotoViewer()
    gifToken = gifToken + 1
    Gif.stop(PhotoDisplay)
    hideGifUI()
    isInPhotoViewer = false
    closePhotoMenu()
    PhotoViewerView.Visible = false
    PhotoScrollList.Visible = true
    PhotoDisplay.Image = ""
    clearVFDisplay()
    currentPhotoIndex = 0
    resetZoom()
end

local function startGif(photo, tk)
    -- FIX: limpa imediatamente o display e o overlay antes de spawnar,
    -- garantindo que o Heartbeat do GIF anterior nao escreva mais nada visivel.
    PhotoDisplay.Image = ""
    PhotoDisplay.ImageTransparency = 1
    PhotoDisplay2.Visible = false
    PhotoDisplay2.Image = ""
    gifBadge.Visible = true
    gifBadge.Text = "GIF · lendo…"
    task.spawn(function()
        local function cancelled() return tk ~= gifToken or not PhotoViewerView.Visible end
        local okR, data = pcall(readfile, photo.path)
        if cancelled() then return end
        if not okR or type(data) ~= "string" or #data < 20 then gifBadge.Text = "GIF · erro"; return end
        gifKeyMemo[photo.path] = nil   -- recalcula com o conteudo que acabou de ser lido
        local key = gifKeyFor(photo, data)
        -- mostra o 1o quadro enquanto prepara a animacao
        local tp = Gif.thumbPath(key)
        local ta = tp and Gif.asset(tp)
        if ta and not cancelled() then PhotoDisplay.ImageTransparency = 0; PhotoDisplay.Image = ta end
        local info, bakeErr = Gif.load(key, #data)
        if not info then
            -- maxFrames = 0 = todos os quadros; maxDim = 480
            info, bakeErr = Gif.bake(key, data, {
                maxFrames = 0, maxDim = 480, pixelBudget = 48000000, yield = task.wait, cancelled = cancelled,
                onProg = function(d, t) if not cancelled() then gifBadge.Text = "GIF · " .. d .. "/" .. t end end,
            }, photo.file)   -- passa nome do arquivo para pasta legivel
        end
        if cancelled() then return end
        if not info then gifBadge.Text = "GIF · erro: " .. tostring(bakeErr or "?"):sub(1, 40); return end
        local assets = Gif.assets(info)
        if not assets then gifBadge.Text = "GIF · sem getcustomasset"; return end
        if #assets < 2 then gifBadge.Text = "GIF"; PhotoDisplay.ImageTransparency = 0; PhotoDisplay.Image = assets[1]; return end
        Gif.preload(assets, 1.5)
        if cancelled() then return end
        -- mostra 1o quadro antes de conectar o Heartbeat (sem flash)
        PhotoDisplay.ImageTransparency = 0
        PhotoDisplay.Image = assets[1]
        gifState.playing = true
        gifBadge.Text = "GIF"
        gifSmooth.Text = gifState.smooth and "60 FPS" or "ORIGINAL"
        gifSmooth.TextColor3 = gifState.smooth and Color3.fromRGB(120, 255, 160) or Color3.fromRGB(190, 190, 200)
        gifSmooth.Visible = true
        Gif.play(PhotoDisplay, PhotoDisplay2, assets, info.delays, cancelled, gifState)
    end)
end

gifBadge.MouseButton1Click:Connect(function()
    if gifBadge.Text ~= "GIF" and gifBadge.Text ~= "GIF · pausado" then return end
    gifState.playing = not gifState.playing
    gifBadge.Text = gifState.playing and "GIF" or "GIF · pausado"
end)

gifSmooth.MouseButton1Click:Connect(function()
    gifState.smooth = not gifState.smooth
    gifSmooth.Text = gifState.smooth and "60 FPS" or "ORIGINAL"
    gifSmooth.TextColor3 = gifState.smooth and Color3.fromRGB(120, 255, 160) or Color3.fromRGB(190, 190, 200)
end)

function openPhotoByIndex(idx)
    if #filteredPhotoList == 0 then return end
    if idx < 1 then idx = #filteredPhotoList end
    if idx > #filteredPhotoList then idx = 1 end
    currentPhotoIndex = idx
    local photo = filteredPhotoList[idx]
    isInPhotoViewer = true
    closePhotoMenu()
    PhotoViewerView.Visible = true
    PhotoNameLabel.Text = photo.name
    counter.Text = idx .. " / " .. #filteredPhotoList
    resetZoom()
    refreshFavBtn()
    gifToken = gifToken + 1
    -- FIX: incrementa token ANTES de limpar/spawnar para garantir que
    -- qualquer Heartbeat antigo veja o token novo e pare imediatamente.
    Gif.stop(PhotoDisplay)
    PhotoDisplay.Image = ""
    PhotoDisplay.ImageTransparency = 1
    PhotoDisplay2.Visible = false
    PhotoDisplay2.Image = ""
    hideGifUI()
    clearVFDisplay()
    if photo.isVF then
        local fill = _G.TZE_CameraFillPhoto
        local holder = Instance.new("Frame")
        holder.Name = "VFHolder"
        holder.AnchorPoint = Vector2.new(0.5, 0.5)
        holder.Position = UDim2.new(0.5, 0, 0.5, 0)
        holder.Size = UDim2.new(1, 0, 1, 0)
        holder.BackgroundTransparency = 1
        holder.Parent = PhotoDisplay
        local ar = Instance.new("UIAspectRatioConstraint")
        ar.AspectRatio = math.max(photo.photo.aspect or 1, 0.1)
        ar.AspectType = Enum.AspectType.FitWithinMaxSize
        ar.Parent = holder
        local inner = Instance.new("Frame")
        inner.Size = UDim2.new(1, 0, 1, 0)
        inner.BackgroundColor3 = Color3.new(0, 0, 0)
        inner.BorderSizePixel = 0
        inner.ClipsDescendants = true
        inner.Parent = holder
        if fill then pcall(fill, photo.photo, inner) end
        return
    end
    if photo.isGif then
        startGif(photo, gifToken)
        return
    end
    local a = getAsset(photo.path)
    if a then
        PhotoDisplay.ImageTransparency = 1
        PhotoDisplay.Image = a
        TweenService:Create(PhotoDisplay, TweenInfo.new(0.2), {ImageTransparency = 0}):Play()
    else
        PhotoDisplay.Image = ""
        PhotoNameLabel.Text = "Erro ao carregar foto"
    end
end

viewBack.MouseButton1Click:Connect(function() exitPhotoViewer() end)
prevPhotoBtn.MouseButton1Click:Connect(function() openPhotoByIndex(currentPhotoIndex - 1) end)
nextPhotoBtn.MouseButton1Click:Connect(function() openPhotoByIndex(currentPhotoIndex + 1) end)

favBtn.MouseButton1Click:Connect(function()
    local p = filteredPhotoList[currentPhotoIndex]
    if not p then return end
    local k = keyOf(p)
    if favs[k] then favs[k] = nil else favs[k] = true end
    saveSettings()
    refreshFavBtn()
    refreshMenu()
end)

confirmDelBtn.MouseButton1Click:Connect(function()
    local photo = filteredPhotoList[currentPhotoIndex]
    if not photo then return end
    if photo.isVF then removeVF(photo) else pcall(delfile, photo.path) end
    if photo.isGif then
        local k = gifKeyMemo[photo.path]
        if k then Gif.remove(k) end
        gifKeyMemo[photo.path] = nil
    end
    favs[keyOf(photo)] = nil
    saveSettings()
    for i, p in ipairs(photoList) do
        if p.path == photo.path then table.remove(photoList, i) break end
    end
    exitPhotoViewer()
    updatePhotoList()
end)

favMenuBtn.MouseButton1Click:Connect(function()
    local p = filteredPhotoList[currentPhotoIndex]
    if not p then return end
    local k = keyOf(p)
    if favs[k] then favs[k] = nil else favs[k] = true end
    saveSettings()
    refreshFavBtn()
    refreshMenu()
end)

setWallpaperMenuBtn.MouseButton1Click:Connect(function()
    local photo = filteredPhotoList[currentPhotoIndex]
    if not photo then return end
    local a
    if photo.isGif then a = gifThumbAsset(photo) else a = getAsset(photo.path) end
    if a then
        local file = nil
        if photo.isGif then
            local okK, key = pcall(gifKeyFor, photo)
            if okK and key then file = Gif.thumbPath(key) end
        elseif not tostring(photo.path):match("%.camphoto$") and tostring(photo.path):sub(1, 5) ~= "vf://" then
            file = photo.path
        end
        currentWallpaper = a
        phoneSettings.wallpaper = a
        phoneSettings.wallpaperFile = file
        homeBg.Image = a
        saveSettings()
        closePhotoMenu()
    end
end)

local drag = nil
local pinching, pinchStart = false, 1
local function isPress(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end
local function viewerActive() return isInPhotoViewer and PhotoViewerView.Visible and GalleryFrame.Visible end

touchArea.InputBegan:Connect(function(i)
    if isPress(i) and not pinching then
        if isPhotoMenuOpen then closePhotoMenu() end
        drag = {input = i, start = i.Position, last = i.Position, t = os.clock(), moved = 0}
    end
end)

UserInputService.InputChanged:Connect(function(i)
    if not viewerActive() then return end
    if drag and not pinching and (i.UserInputType == Enum.UserInputType.MouseMovement or (i.UserInputType == Enum.UserInputType.Touch and i == drag.input)) then
        local d = (i.Position - drag.last) / uiScale()
        drag.last = i.Position
        drag.moved += d.Magnitude
        if zoom > 1.02 then
            panX += d.X
            panY += d.Y
            applyTransform()
        end
    end
end)

touchArea.InputChanged:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseWheel then
        zoom = math.clamp(zoom * (1 + 0.15 * i.Position.Z), 1, 5)
        if zoom < 1.05 then zoom, panX, panY = 1, 0, 0 end
        applyTransform()
    end
end)

UserInputService.InputEnded:Connect(function(i)
    if not drag or not isPress(i) then return end
    if i.UserInputType == Enum.UserInputType.Touch and i ~= drag.input then return end
    local d = drag
    drag = nil
    if not viewerActive() or pinching then return end
    local total = (i.Position - d.start) / uiScale()
    if zoom <= 1.05 and math.abs(total.X) > 50 and math.abs(total.X) > math.abs(total.Y) * 1.3 then
        openPhotoByIndex(currentPhotoIndex + (total.X < 0 and 1 or -1))
    elseif d.moved < 8 and os.clock() - d.t < 0.3 then
        if os.clock() - lastTap < 0.3 then
            lastTap = 0
            if zoom > 1.05 then resetZoom() else zoom = 2.5 panX, panY = 0, 0 applyTransform() end
        else
            lastTap = os.clock()
        end
    end
end)

UserInputService.TouchPinch:Connect(function(_, scale, _, state)
    if not viewerActive() then return end
    if state == Enum.UserInputState.Begin then
        pinching = true
        pinchStart = zoom
        drag = nil
    elseif state == Enum.UserInputState.Change then
        zoom = math.clamp(pinchStart * scale, 1, 5)
        applyTransform()
    else
        pinching = false
        if zoom < 1.05 then resetZoom() end
    end
end)

local function setTab(mode)
    tabMode = mode
    tabAll.BackgroundTransparency = mode == "all" and 0 or 1
    tabAll.TextColor3 = mode == "all" and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 170)
    tabFav.BackgroundTransparency = mode == "favs" and 0 or 1
    tabFav.TextColor3 = mode == "favs" and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 170)
    tabFavUI.setColor(tabFav.TextColor3, mode == "favs" and Color3.fromRGB(255, 90, 115) or Color3.fromRGB(150, 150, 170))
end
setTab("all")

function updatePhotoList()
    gridToken += 1
    local token = gridToken
    for _, v in ipairs(PhotoScrollList:GetChildren()) do
        if v:IsA("GuiObject") then v:Destroy() end
    end
    local q = PhotoSearchBox.Text:lower()
    filteredPhotoList = {}
    for _, p in ipairs(photoList) do
        if (q == "" or p.name:lower():find(q, 1, true)) and (tabMode == "all" or favs[keyOf(p)]) then
            table.insert(filteredPhotoList, p)
        end
    end
    countLabel.Text = #filteredPhotoList .. (#filteredPhotoList == 1 and " foto" or " fotos")

    if #filteredPhotoList == 0 then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0, 252, 0, 70)
        lbl.BackgroundColor3 = DARK
        lbl.TextColor3 = Color3.fromRGB(130, 130, 150)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextWrapped = true
        local emptyFn
        if q ~= "" then lbl.Text = "Nenhuma foto encontrada"; emptyFn = Icons.search
        elseif tabMode == "favs" then lbl.Text = "Nenhuma favorita ainda\nAbra uma foto e toque no coração"; emptyFn = Icons.heart
        else lbl.Text = "Coloque fotos em\nPHONE/Photos"; emptyFn = Icons.folder end
        lbl.Parent = PhotoScrollList
        corner(lbl, UDim.new(0, 12))
        Icons.empty(lbl, emptyFn, 20, Color3.fromRGB(130, 130, 150), 2)
        PhotoScrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
        return
    end

    local cells = {}
    for idx, photo in ipairs(filteredPhotoList) do
        local cell = Instance.new("ImageButton")
        cell.LayoutOrder = idx
        cell.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
        cell.BorderSizePixel = 0
        cell.ScaleType = Enum.ScaleType.Crop
        cell.ImageTransparency = 1
        cell.AutoButtonColor = false
        cell.Parent = PhotoScrollList
        corner(cell, UDim.new(0, 12))
        if favs[keyOf(photo)] then
            local shadow = Icons.heart(cell, 18, Color3.new(0, 0, 0), 3)
            shadow.Position = UDim2.new(1, -26, 1, -26)
            for _, d in ipairs(shadow:GetDescendants()) do
                if d:IsA("Frame") then d.BackgroundTransparency = 0.55 end
            end
            local heart = Icons.heart(cell, 14, Color3.fromRGB(255, 70, 100), 4)
            heart.Position = UDim2.new(1, -24, 1, -24)
        end
        if photo.isGif then
            local gb = Instance.new("TextLabel")
            gb.Size = UDim2.new(0, 28, 0, 14)
            gb.Position = UDim2.new(0, 5, 0, 5)
            gb.BackgroundColor3 = Color3.new(0, 0, 0)
            gb.BackgroundTransparency = 0.25
            gb.BorderSizePixel = 0
            gb.Text = "GIF"
            gb.TextColor3 = Color3.new(1, 1, 1)
            gb.Font = Enum.Font.GothamBold
            gb.TextSize = 9
            gb.ZIndex = 3
            gb.Parent = cell
            corner(gb, UDim.new(0, 7))
        end
        if photo.isVF then
            cell.ClipsDescendants = true
            local fill = _G.TZE_CameraFillPhoto
            local a = math.max(photo.photo.aspect or 1, 0.1)
            local w = Instance.new("Frame")
            w.BackgroundTransparency = 1
            w.AnchorPoint = Vector2.new(0.5, 0.5)
            w.Position = UDim2.new(0.5, 0, 0.5, 0)
            w.Size = UDim2.new(math.max(1, a), 0, math.max(1, 1 / a), 0)
            w.ZIndex = 1
            w.Parent = cell
            if fill then pcall(fill, photo.photo, w) end
        end
        cell.MouseButton1Click:Connect(function() openPhotoByIndex(idx) end)
        cells[idx] = cell
    end
    task.wait()
    PhotoScrollList.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 8)

    task.spawn(function()
        for idx, cell in ipairs(cells) do
            if token ~= gridToken then return end
            local ph = filteredPhotoList[idx]
            local a
            if ph.isVF then a = nil
            elseif ph.isGif then a = gifThumbAsset(ph) else a = getAsset(ph.path) end
            if a and cell.Parent then
                cell.Image = a
                TweenService:Create(cell, TweenInfo.new(0.25), {ImageTransparency = 0}):Play()
            end
            if idx % 4 == 0 then task.wait() end
        end
    end)
end

function refreshPhotos()
    photoList = {}
    local seen = {}
    for _, dir in ipairs({"PHONE/Photos", "PHONE\\Photos", "Photos"}) do
        local okF, isDir = pcall(isfolder, dir)
        if okF and isDir then
            local ok, files = pcall(listfiles, dir)
            if ok and type(files) == "table" then
                for _, file in ipairs(files) do
                    local str = tostring(file)
                    local norm = str:gsub("\\", "/")
                    local ext = (norm:match("%.(%w+)$") or ""):lower()
                    if (ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "webp" or ext == "bmp" or ext == "gif" or ext == "camphoto") and not seen[norm:lower()] then
                        seen[norm:lower()] = true
                        local fileName = norm:match("([^/]+)$") or norm
                        local name = fileName:gsub("%.%w+$", "")
                        table.insert(photoList, {name = name, file = fileName, path = file, isGif = (ext == "gif"), isCamPhoto = (ext == "camphoto")})
                    end
                end
            end
        end
    end
    -- fotos da Câmera em modo ViewportFrame (só existem nesta sessão)
    for _, e in ipairs(_G.TZE_GalleryVF or {}) do table.insert(photoList, e) end
    table.sort(photoList, function(a, b) return a.name:lower() < b.name:lower() end)
    updatePhotoList()
end

tabAll.MouseButton1Click:Connect(function() setTab("all") updatePhotoList() end)
tabFav.MouseButton1Click:Connect(function() setTab("favs") updatePhotoList() end)
PhotoSearchBox:GetPropertyChangedSignal("Text"):Connect(updatePhotoList)

createNavBar(GalleryFrame)
end

do
local function buildGPS()
    local GPS = Nav.gps
    local Players = game:GetService("Players")

    local MAP_W, MAP_H = 260, 220
    local PAD = 16
    local FOV = 16
    local TAN_HALF = math.tan(math.rad(FOV / 2))
    local SPANS = {60, 100, 160, 260, 420, 700, 1100}
    local MAX_PARTS = 5000
    local ACC = Color3.fromRGB(46, 190, 120)
    local ME = Color3.fromRGB(10, 132, 255)
    local CARD = Color3.fromRGB(26, 26, 32)
    local SUB = Color3.fromRGB(150, 150, 165)
    local BTN = Color3.fromRGB(24, 24, 30)

    local S = {
        spanIdx = 3, span = SPANS[3], targetSpan = SPANS[3],
        center = Vector3.new(0, 0, 0), panCenter = Vector3.new(0, 0, 0),
        up = Vector3.new(0, 0, -1), right = Vector3.new(1, 0, 0),
        headingUp = phoneSettings.gpsHeading == true,
        night = phoneSettings.gpsNight == true,
        free = false, followPlr = nil, selected = nil,
        snap = true, building = false, built = false, token = 0,
        myPos = nil, myLook = Vector3.new(0, 0, -1),
    }
    local entries = {}
    local selectPlayer

    local function txt(parent, text, size, font, color, pos, sz, align, z)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.BorderSizePixel = 0
        l.Text = text
        l.TextSize = size
        l.Font = font
        l.TextColor3 = color
        l.Position = pos
        l.Size = sz
        l.TextXAlignment = align or Enum.TextXAlignment.Left
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.ZIndex = z or 3
        l.Parent = parent
        return l
    end

    local function roundBtn(parent, pos, d, z)
        local b = Instance.new("TextButton")
        b.Text = ""
        b.AutoButtonColor = false
        b.Size = UDim2.new(0, d, 0, d)
        b.Position = pos
        b.BackgroundColor3 = BTN
        b.BackgroundTransparency = 0.1
        b.BorderSizePixel = 0
        b.ZIndex = z
        b.Parent = parent
        corner(b, UDim.new(1, 0))
        local st = Instance.new("UIStroke")
        st.Color = WHITE
        st.Transparency = 0.86
        st.Thickness = 1
        st.Parent = b
        b.MouseButton1Down:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.08), {BackgroundTransparency = 0.45}):Play()
        end)
        local function release()
            TweenService:Create(b, TweenInfo.new(0.18), {BackgroundTransparency = 0.1}):Play()
        end
        b.MouseButton1Up:Connect(release)
        b.MouseLeave:Connect(release)
        return b, st
    end

    local function rootOf(plr)
        local ch = plr.Character
        return ch and ch:FindFirstChild("HumanoidRootPart")
    end

    local function fmtTime(sec)
        if sec < 60 then return math.ceil(sec) .. " s" end
        return math.floor(sec / 60) .. " min " .. math.floor(sec % 60) .. " s"
    end

    local GPSFrame = Instance.new("Frame")
    GPSFrame.Name = "GPSFrame"
    GPSFrame.Size = UDim2.new(0, 280, 0, 440)
    GPSFrame.Position = PhoneHome.Position
    GPSFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
    GPSFrame.BorderSizePixel = 0
    GPSFrame.Visible = false
    GPSFrame.Active = true
    GPSFrame.Parent = ScreenGui
    corner(GPSFrame, UDim.new(0, 28))
    Nav.shell.create(GPSFrame)
    Nav.status.create(GPSFrame)
    createNavBar(GPSFrame)
    GPS.frame = GPSFrame

    local gIcon = Icons.gps(GPSFrame, 22, ACC, 3)
    gIcon.Position = UDim2.new(0, 14, 0, 40)
    txt(GPSFrame, "GPS", 20, Enum.Font.GothamBold, WHITE, UDim2.new(0, 42, 0, 38), UDim2.new(0, 70, 0, 26), nil, 3)

    local countChip = txt(GPSFrame, "1 jogador", 10, Enum.Font.GothamMedium, SUB, UDim2.new(1, -118, 0, 40), UDim2.new(0, 80, 0, 22), Enum.TextXAlignment.Center, 3)
    countChip.BackgroundTransparency = 0
    countChip.BackgroundColor3 = CARD
    corner(countChip, UDim.new(1, 0))

    local refreshBtn = roundBtn(GPSFrame, UDim2.new(1, -34, 0, 39), 24, 4)
    local refreshIcon = Icons.reset(refreshBtn, 14, WHITE, 5)
    refreshIcon.Position = UDim2.new(0.5, -7, 0.5, -7)

    local holder = Instance.new("Frame")
    holder.Name = "MapHolder"
    holder.Position = UDim2.new(0, 10, 0, 68)
    holder.Size = UDim2.new(0, MAP_W, 0, MAP_H)
    holder.BackgroundColor3 = Color3.fromRGB(22, 26, 34)
    holder.BorderSizePixel = 0
    holder.ClipsDescendants = true
    holder.ZIndex = 2
    holder.Parent = GPSFrame
    corner(holder, UDim.new(0, 18))
    local holderStroke = Instance.new("UIStroke")
    holderStroke.Color = WHITE
    holderStroke.Transparency = 0.88
    holderStroke.Thickness = 1
    holderStroke.Parent = holder

    local vp = Instance.new("ViewportFrame")
    vp.Name = "MapViewport"
    vp.Size = UDim2.new(1, 0, 1, 0)
    vp.BackgroundColor3 = Color3.fromRGB(22, 26, 34)
    vp.BorderSizePixel = 0
    vp.LightDirection = Vector3.new(-0.35, -1, -0.25)
    vp.ZIndex = 1
    vp.Parent = holder
    corner(vp, UDim.new(0, 18))

    local cam = Instance.new("Camera")
    cam.FieldOfView = FOV
    cam.Parent = vp
    vp.CurrentCamera = cam

    local mapModel = Instance.new("Model")
    mapModel.Name = "MapClone"
    mapModel.Parent = vp

    local tint = Instance.new("Frame")
    tint.Size = UDim2.new(1, 0, 1, 0)
    tint.BackgroundColor3 = Color3.fromRGB(4, 10, 34)
    tint.BackgroundTransparency = 1
    tint.BorderSizePixel = 0
    tint.ZIndex = 2
    tint.Parent = holder

    local dragBtn = Instance.new("TextButton")
    dragBtn.Name = "Drag"
    dragBtn.Text = ""
    dragBtn.AutoButtonColor = false
    dragBtn.BackgroundTransparency = 1
    dragBtn.Size = UDim2.new(1, 0, 1, 0)
    dragBtn.ZIndex = 3
    dragBtn.Parent = holder

    local markerLayer = Instance.new("Frame")
    markerLayer.Name = "Markers"
    markerLayer.Size = UDim2.new(1, 0, 1, 0)
    markerLayer.BackgroundTransparency = 1
    markerLayer.ClipsDescendants = true
    markerLayer.ZIndex = 5
    markerLayer.Parent = holder

    local routeLine = Instance.new("Frame")
    routeLine.Name = "RouteLine"
    routeLine.AnchorPoint = Vector2.new(0.5, 0.5)
    routeLine.Size = UDim2.new(0, 10, 0, 3)
    routeLine.BackgroundColor3 = ME
    routeLine.BackgroundTransparency = 0.15
    routeLine.BorderSizePixel = 0
    routeLine.Visible = false
    routeLine.ZIndex = 2
    routeLine.Parent = markerLayer
    corner(routeLine, UDim.new(1, 0))
    local routeChip = Instance.new("TextLabel")
    routeChip.Name = "RouteChip"
    routeChip.AnchorPoint = Vector2.new(0.5, 0.5)
    routeChip.AutomaticSize = Enum.AutomaticSize.X
    routeChip.Size = UDim2.new(0, 0, 0, 17)
    routeChip.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
    routeChip.BackgroundTransparency = 0.12
    routeChip.BorderSizePixel = 0
    routeChip.Font = Enum.Font.GothamBold
    routeChip.TextSize = 10
    routeChip.TextColor3 = WHITE
    routeChip.Text = ""
    routeChip.Visible = false
    routeChip.ZIndex = 3
    routeChip.Parent = markerLayer
    corner(routeChip, UDim.new(1, 0))
    local chipPad = Instance.new("UIPadding")
    chipPad.PaddingLeft = UDim.new(0, 8)
    chipPad.PaddingRight = UDim.new(0, 8)
    chipPad.Parent = routeChip

    local compassBtn, compassStroke = roundBtn(holder, UDim2.new(0, 8, 0, 8), 30, 10)
    local compassRot = Instance.new("Frame")
    compassRot.AnchorPoint = Vector2.new(0.5, 0.5)
    compassRot.Position = UDim2.new(0.5, 0, 0.5, 0)
    compassRot.Size = UDim2.new(0, 30, 0, 30)
    compassRot.BackgroundTransparency = 1
    compassRot.ZIndex = 11
    compassRot.Parent = compassBtn
    Draw.poly3(compassRot, {15, 5}, {10.5, 15}, {19.5, 15}, Color3.fromRGB(255, 80, 80), 12)
    Draw.poly3(compassRot, {10.5, 15}, {19.5, 15}, {15, 25}, Color3.fromRGB(230, 230, 240), 12)

    local styleBtn = roundBtn(holder, UDim2.new(0, 8, 0, 42), 30, 10)
    local styleIcon = Instance.new("Frame")
    styleIcon.Size = UDim2.new(0, 30, 0, 30)
    styleIcon.BackgroundTransparency = 1
    styleIcon.ZIndex = 11
    styleIcon.Parent = styleBtn

    local zoomIn = roundBtn(holder, UDim2.new(1, -38, 0, 8), 30, 10)
    Draw.box(zoomIn, 15, 15, 12, 2.4, 0, WHITE, 12, UDim.new(1, 0))
    Draw.box(zoomIn, 15, 15, 2.4, 12, 0, WHITE, 12, UDim.new(1, 0))
    local zoomOut = roundBtn(holder, UDim2.new(1, -38, 0, 42), 30, 10)
    Draw.box(zoomOut, 15, 15, 12, 2.4, 0, WHITE, 12, UDim.new(1, 0))
    local recenter = roundBtn(holder, UDim2.new(1, -38, 0, 76), 30, 10)
    Draw.circle(recenter, 15, 15, 15, WHITE, 2, 12)
    Draw.circle(recenter, 15, 15, 5, WHITE, nil, 12)

    local modeChip = Instance.new("TextLabel")
    modeChip.AnchorPoint = Vector2.new(0.5, 0)
    modeChip.AutomaticSize = Enum.AutomaticSize.X
    modeChip.Position = UDim2.new(0.5, 0, 0, 10)
    modeChip.Size = UDim2.new(0, 0, 0, 20)
    modeChip.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
    modeChip.BackgroundTransparency = 0.15
    modeChip.BorderSizePixel = 0
    modeChip.Font = Enum.Font.GothamBold
    modeChip.TextSize = 10
    modeChip.TextColor3 = WHITE
    modeChip.Text = "Você"
    modeChip.ZIndex = 10
    modeChip.Parent = holder
    corner(modeChip, UDim.new(1, 0))
    local modePad = Instance.new("UIPadding")
    modePad.PaddingLeft = UDim.new(0, 10)
    modePad.PaddingRight = UDim.new(0, 10)
    modePad.Parent = modeChip

    local scaleText = txt(holder, "100 studs", 9, Enum.Font.GothamBold, WHITE, UDim2.new(0, 12, 1, -34), UDim2.new(0, 90, 0, 12), nil, 10)
    scaleText.TextStrokeTransparency = 0.45
    local scaleBar = Instance.new("Frame")
    scaleBar.Position = UDim2.new(0, 12, 1, -20)
    scaleBar.Size = UDim2.new(0, 50, 0, 2)
    scaleBar.BackgroundColor3 = WHITE
    scaleBar.BorderSizePixel = 0
    scaleBar.ZIndex = 10
    scaleBar.Parent = holder
    for _, xo in ipairs({0, 1}) do
        local tick = Instance.new("Frame")
        tick.AnchorPoint = Vector2.new(xo, 1)
        tick.Position = UDim2.new(xo, 0, 1, 0)
        tick.Size = UDim2.new(0, 2, 0, 6)
        tick.BackgroundColor3 = WHITE
        tick.BorderSizePixel = 0
        tick.ZIndex = 10
        tick.Parent = scaleBar
    end
    local coordText = txt(holder, "X 0  Y 0  Z 0", 9, Enum.Font.GothamMedium, WHITE, UDim2.new(1, -142, 1, -22), UDim2.new(0, 130, 0, 12), Enum.TextXAlignment.Right, 10)
    coordText.TextStrokeTransparency = 0.45

    local gridLayer = Instance.new("Frame")
    gridLayer.Name = "Grid"
    gridLayer.Size = UDim2.new(1, 0, 1, 0)
    gridLayer.BackgroundTransparency = 1
    gridLayer.BorderSizePixel = 0
    gridLayer.ZIndex = 4
    gridLayer.Parent = holder
    for i = 1, 3 do
        local v = Instance.new("Frame")
        v.Size = UDim2.new(0, 1, 1, 0)
        v.Position = UDim2.new(i * 0.25, 0, 0, 0)
        v.BackgroundColor3 = WHITE
        v.BackgroundTransparency = 0.9
        v.BorderSizePixel = 0
        v.ZIndex = 4
        v.Parent = gridLayer
        local h = Instance.new("Frame")
        h.Size = UDim2.new(1, 0, 0, 1)
        h.Position = UDim2.new(0, 0, i * 0.25, 0)
        h.BackgroundColor3 = WHITE
        h.BackgroundTransparency = 0.9
        h.BorderSizePixel = 0
        h.ZIndex = 4
        h.Parent = gridLayer
    end

    local pingChip = txt(holder, "-- ms", 9, Enum.Font.GothamBold, ACC, UDim2.new(0, 8, 0, 10), UDim2.new(0, 50, 0, 20), Enum.TextXAlignment.Center, 10)
    pingChip.BackgroundTransparency = 0.2
    pingChip.BackgroundColor3 = CARD
    corner(pingChip, UDim.new(1, 0))
    local function updatePing()
        local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        if not ok or type(v) ~= "number" then pingChip.Text = "-- ms" return end
        pingChip.Text = math.floor(v) .. " ms"
        pingChip.TextColor3 = v < 80 and ACC or (v < 160 and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(255, 80, 80))
    end

    local emptyNote = txt(holder, "Sem estruturas para mostrar", 11, Enum.Font.GothamMedium, SUB, UDim2.new(0, 0, 0.5, 30), UDim2.new(1, 0, 0, 18), Enum.TextXAlignment.Center, 4)
    emptyNote.Visible = false

    local loading = Instance.new("CanvasGroup")
    loading.Name = "Loading"
    loading.Size = UDim2.new(1, 0, 1, 0)
    loading.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
    loading.BorderSizePixel = 0
    loading.ZIndex = 14
    loading.Parent = holder
    corner(loading, UDim.new(0, 18))
    local pin = Icons.gps(loading, 34, ACC, 15)
    pin.AnchorPoint = Vector2.new(0.5, 0.5)
    pin.Position = UDim2.new(0.5, 0, 0.5, -26)
    TweenService:Create(pin, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Position = UDim2.new(0.5, 0, 0.5, -34)}):Play()
    local loadTxt = txt(loading, "Mapeando...", 12, Enum.Font.GothamBold, WHITE, UDim2.new(0, 0, 0.5, 2), UDim2.new(1, 0, 0, 18), Enum.TextXAlignment.Center, 15)
    local barBg = Instance.new("Frame")
    barBg.AnchorPoint = Vector2.new(0.5, 0)
    barBg.Position = UDim2.new(0.5, 0, 0.5, 28)
    barBg.Size = UDim2.new(0, 140, 0, 4)
    barBg.BackgroundColor3 = Color3.fromRGB(46, 48, 58)
    barBg.BorderSizePixel = 0
    barBg.ZIndex = 15
    barBg.Parent = loading
    corner(barBg, UDim.new(1, 0))
    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = ACC
    barFill.BorderSizePixel = 0
    barFill.ZIndex = 16
    barFill.Parent = barBg
    corner(barFill, UDim.new(1, 0))
    local loadPct = txt(loading, "0%", 10, Enum.Font.GothamMedium, SUB, UDim2.new(0, 0, 0.5, 38), UDim2.new(1, 0, 0, 14), Enum.TextXAlignment.Center, 15)

    local function setProgress(p, text)
        barFill.Size = UDim2.new(math.clamp(p, 0, 1), 0, 1, 0)
        loadPct.Text = math.floor(math.clamp(p, 0, 1) * 100) .. "%"
        if text then loadTxt.Text = text end
    end

    local listFrame = Instance.new("ScrollingFrame")
    listFrame.Name = "PlayerList"
    listFrame.Position = UDim2.new(0, 10, 0, 294)
    listFrame.Size = UDim2.new(0, MAP_W, 0, 104)
    listFrame.BackgroundTransparency = 1
    listFrame.BorderSizePixel = 0
    listFrame.ScrollBarThickness = 0
    listFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    listFrame.ZIndex = 3
    listFrame.Parent = GPSFrame
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 5)
    listLayout.Parent = listFrame

    local function drawStyleIcon()
        styleIcon:ClearAllChildren()
        if S.night then
            Draw.circle(styleIcon, 15, 15, 14, WHITE, nil, 12)
            Draw.circle(styleIcon, 19.5, 11.5, 12, BTN, nil, 13)
        else
            local sun = Color3.fromRGB(255, 200, 60)
            Draw.circle(styleIcon, 15, 15, 8, sun, nil, 12)
            for i = 0, 7 do
                local a = math.rad(i * 45)
                Draw.line(styleIcon, 15 + math.cos(a) * 6.5, 15 + math.sin(a) * 6.5, 15 + math.cos(a) * 9.5, 15 + math.sin(a) * 9.5, 1.6, sun, 12)
            end
        end
    end
    local function applyStyle()
        if S.night then
            vp.Ambient = Color3.fromRGB(105, 118, 150)
            vp.LightColor = Color3.fromRGB(150, 170, 230)
        else
            vp.Ambient = Color3.fromRGB(180, 184, 192)
            vp.LightColor = Color3.fromRGB(255, 248, 235)
        end
        TweenService:Create(tint, TweenInfo.new(0.35), {BackgroundTransparency = S.night and 0.58 or 1}):Play()
        drawStyleIcon()
    end
    applyStyle()

    local function applyCompassState()
        compassStroke.Color = S.headingUp and ACC or WHITE
        compassStroke.Transparency = S.headingUp and 0.1 or 0.86
        compassStroke.Thickness = S.headingUp and 1.6 or 1
    end
    applyCompassState()

    local function makeMarker(plr)
        local isMe = plr == Player
        local accent = isMe and ME or Color3.fromHSV((plr.UserId % 360) / 360, 0.62, 1)
        local m = {isMe = isMe, accent = accent}

        local root = Instance.new("TextButton")
        root.Name = "Marker_" .. plr.Name
        root.AnchorPoint = Vector2.new(0.5, 0.5)
        root.Size = UDim2.new(0, 26, 0, 26)
        root.BackgroundTransparency = 1
        root.Text = ""
        root.AutoButtonColor = false
        root.Visible = false
        root.ZIndex = isMe and 9 or 7
        root.Parent = markerLayer
        m.root = root

        if isMe then
            local pulse = Instance.new("Frame")
            pulse.AnchorPoint = Vector2.new(0.5, 0.5)
            pulse.Position = UDim2.new(0.5, 0, 0.5, 0)
            pulse.Size = UDim2.new(0, 26, 0, 26)
            pulse.BackgroundTransparency = 1
            pulse.ZIndex = 1
            pulse.Parent = root
            corner(pulse, UDim.new(1, 0))
            local ps = Instance.new("UIStroke")
            ps.Color = accent
            ps.Thickness = 2
            ps.Parent = pulse
            m.pulse, m.pulseStroke = pulse, ps
        end

        local nose = Instance.new("Frame")
        nose.AnchorPoint = Vector2.new(0.5, 0.5)
        nose.Size = UDim2.new(0, 8, 0, 8)
        nose.Rotation = 45
        nose.BackgroundColor3 = accent
        nose.BorderSizePixel = 0
        nose.Visible = false
        nose.ZIndex = 2
        nose.Parent = root
        local nst = Instance.new("UIStroke")
        nst.Color = WHITE
        nst.Thickness = 1
        nst.Parent = nose
        m.nose = nose

        local disc = Instance.new("Frame")
        disc.Size = UDim2.new(1, 0, 1, 0)
        disc.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
        disc.BorderSizePixel = 0
        disc.ZIndex = 3
        disc.Parent = root
        corner(disc, UDim.new(1, 0))
        local ds = Instance.new("UIStroke")
        ds.Color = accent
        ds.Thickness = isMe and 3 or 2.5
        ds.Parent = disc
        m.discStroke = ds

        local ini = Instance.new("TextLabel")
        ini.BackgroundTransparency = 1
        ini.Size = UDim2.new(1, 0, 1, 0)
        ini.Text = string.upper(string.sub(plr.DisplayName ~= "" and plr.DisplayName or plr.Name, 1, 1))
        ini.Font = Enum.Font.GothamBold
        ini.TextSize = 11
        ini.TextColor3 = WHITE
        ini.ZIndex = 4
        ini.Parent = disc
        local av = Instance.new("ImageLabel")
        av.Position = UDim2.new(0, 2, 0, 2)
        av.Size = UDim2.new(1, -4, 1, -4)
        av.BackgroundTransparency = 1
        av.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", plr.UserId)
        av.ZIndex = 5
        av.Parent = disc
        corner(av, UDim.new(1, 0))

        local name = Instance.new("TextLabel")
        name.AnchorPoint = Vector2.new(0.5, 0)
        name.AutomaticSize = Enum.AutomaticSize.X
        name.Position = UDim2.new(0.5, 0, 1, 4)
        name.Size = UDim2.new(0, 0, 0, 13)
        name.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        name.BackgroundTransparency = 0.3
        name.BorderSizePixel = 0
        name.Font = Enum.Font.GothamBold
        name.TextSize = 9
        name.TextColor3 = WHITE
        name.Text = plr.DisplayName ~= "" and plr.DisplayName or plr.Name
        name.Visible = false
        name.ZIndex = 6
        name.Parent = root
        corner(name, UDim.new(1, 0))
        local np = Instance.new("UIPadding")
        np.PaddingLeft = UDim.new(0, 5)
        np.PaddingRight = UDim.new(0, 5)
        np.Parent = name
        m.name = name

        root.MouseButton1Click:Connect(function() selectPlayer(plr) end)
        return m
    end

    local function makeRow(plr, m)
        local row = Instance.new("TextButton")
        row.Name = "Row_" .. plr.Name
        row.Size = UDim2.new(1, 0, 0, 38)
        row.BackgroundColor3 = CARD
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = false
        row.ZIndex = 3
        row.Parent = listFrame
        corner(row, UDim.new(0, 12))
        local st = Instance.new("UIStroke")
        st.Color = m.accent
        st.Thickness = 1.5
        st.Transparency = 1
        st.Parent = row

        local avBg = Instance.new("Frame")
        avBg.Position = UDim2.new(0, 7, 0.5, -14)
        avBg.Size = UDim2.new(0, 28, 0, 28)
        avBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        avBg.BorderSizePixel = 0
        avBg.ZIndex = 4
        avBg.Parent = row
        corner(avBg, UDim.new(1, 0))
        local avStroke = Instance.new("UIStroke")
        avStroke.Color = m.accent
        avStroke.Thickness = 2
        avStroke.Parent = avBg
        local av = Instance.new("ImageLabel")
        av.Size = UDim2.new(1, 0, 1, 0)
        av.BackgroundTransparency = 1
        av.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", plr.UserId)
        av.ZIndex = 5
        av.Parent = avBg
        corner(av, UDim.new(1, 0))

        local nm = txt(row, plr.DisplayName ~= "" and plr.DisplayName or plr.Name, 12, Enum.Font.GothamBold, WHITE,
            UDim2.new(0, 44, 0, 4), UDim2.new(1, -96, 0, 16), nil, 4)
        local sub = txt(row, "", 10, Enum.Font.Gotham, SUB, UDim2.new(0, 44, 0, 20), UDim2.new(1, -96, 0, 14), nil, 4)
        local tag = txt(row, plr == Player and "VOCÊ" or "", 9, Enum.Font.GothamBold, ME, UDim2.new(1, -52, 0, 0), UDim2.new(0, 44, 1, 0), Enum.TextXAlignment.Right, 4)

        row.MouseButton1Down:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(38, 38, 46)}):Play()
        end)
        local function up() TweenService:Create(row, TweenInfo.new(0.15), {BackgroundColor3 = CARD}):Play() end
        row.MouseButton1Up:Connect(up)
        row.MouseLeave:Connect(up)
        row.MouseButton1Click:Connect(function() selectPlayer(plr) end)
        return {row = row, stroke = st, sub = sub, tag = tag}
    end

    local function addPlayer(plr)
        if entries[plr] then return end
        local m = makeMarker(plr)
        local r = makeRow(plr, m)
        entries[plr] = {marker = m, row = r.row, rowStroke = r.stroke, sub = r.sub, tag = r.tag}
    end

    local function refreshSelection()
        for plr, e in pairs(entries) do
            local on = (plr == S.selected) or (plr == Player and S.selected == nil and not S.free and S.followPlr == nil)
            TweenService:Create(e.rowStroke, TweenInfo.new(0.2), {Transparency = on and 0.1 or 1}):Play()
        end
        if S.free then
            modeChip.Text = "Mapa livre"
        elseif S.followPlr then
            modeChip.Text = "Seguindo " .. (S.followPlr.DisplayName ~= "" and S.followPlr.DisplayName or S.followPlr.Name)
        else
            modeChip.Text = "Você"
        end
    end

    local function removePlayer(plr)
        local e = entries[plr]
        if not e then return end
        e.marker.root:Destroy()
        e.row:Destroy()
        entries[plr] = nil
        if S.selected == plr then S.selected = nil end
        if S.followPlr == plr then S.followPlr = nil end
        refreshSelection()
    end

    function selectPlayer(plr)
        if plr == Player or S.selected == plr then
            S.selected, S.followPlr, S.free = nil, nil, false
        else
            S.selected, S.followPlr, S.free = plr, plr, false
        end
        refreshSelection()
    end

    local function updateCount()
        local n = #Players:GetPlayers()
        countChip.Text = n .. (n == 1 and " jogador" or " jogadores")
    end

    local function buildTerrain(my)
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if not terrain then return end
        local c = S.myPos or Vector3.new(0, 0, 0)
        local R = 1200
        local minX, maxX, minZ, maxZ = c.X - R, c.X + R, c.Z - R, c.Z + R
        local minY, maxY = c.Y - 400, c.Y + 400
        local okExt, ext = pcall(function() return terrain.MaxExtents end)
        if okExt and ext then
            local mn, mx = ext.Min, ext.Max
            local ex0, ex1 = mn.X * 4, (mx.X + 1) * 4
            local ez0, ez1 = mn.Z * 4, (mx.Z + 1) * 4
            if ex1 - ex0 <= 4 or ez1 - ez0 <= 4 then return end
            minX, maxX = math.max(minX, ex0), math.min(maxX, ex1)
            minZ, maxZ = math.max(minZ, ez0), math.min(maxZ, ez1)
            minY, maxY = mn.Y * 4, (mx.Y + 1) * 4
            if minX >= maxX or minZ >= maxZ then return end
        end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = {terrain}
        params.IgnoreWater = false

        local step = math.max(8, math.ceil(math.max(maxX - minX, maxZ - minZ) / 52))
        local nx, nz = math.ceil((maxX - minX) / step), math.ceil((maxZ - minZ) / step)
        local total, done = nx * nz, 0
        local rayLen = (maxY - minY) + 60
        for ix = 0, nx - 1 do
            for iz = 0, nz - 1 do
                if S.token ~= my then return end
                local x, z = minX + (ix + 0.5) * step, minZ + (iz + 0.5) * step
                local res = Workspace:Raycast(Vector3.new(x, maxY + 20, z), Vector3.new(0, -rayLen, 0), params)
                if res then
                    local okC, col = pcall(function() return terrain:GetMaterialColor(res.Material) end)
                    local p = Instance.new("Part")
                    p.Anchored = true
                    p.CanCollide = false
                    p.Material = Enum.Material.SmoothPlastic
                    p.Color = okC and col or Color3.fromRGB(110, 130, 100)
                    p.Size = Vector3.new(step, 3, step)
                    p.CFrame = CFrame.new(x, res.Position.Y - 1.5, z)
                    p.Parent = mapModel
                end
                done = done + 1
                if done % 90 == 0 then
                    setProgress(0.3 + 0.2 * done / total, "Lendo o terreno...")
                    task.wait()
                end
            end
        end
    end

    local function buildMap()
        S.token = S.token + 1
        local my = S.token
        S.building, S.built = true, false
        mapModel:ClearAllChildren()
        emptyNote.Visible = false
        loading.Visible = true
        loading.GroupTransparency = 0
        setProgress(0, "Mapeando...")

        local cand = {}
        local desc = Workspace:GetDescendants()
        local total = #desc
        local camInst = Workspace.CurrentCamera
        for i = 1, total do
            if S.token ~= my then return end
            local inst = desc[i]
            if inst:IsA("BasePart") and not inst:IsA("Terrain") and inst.Transparency < 0.95 then
                local sz = inst.Size
                local ext = math.max(sz.X, sz.Z)
                if ext >= 1.5 and sz.Magnitude < 8000 and inst.Name ~= "HumanoidRootPart" then
                    local mdl = inst:FindFirstAncestorOfClass("Model")
                    if not (mdl and mdl:FindFirstChildOfClass("Humanoid")) and not (camInst and inst:IsDescendantOf(camInst)) then
                        cand[#cand + 1] = {inst, sz.X * sz.Z}
                    end
                end
            end
            if i % 1500 == 0 then
                setProgress(0.3 * i / total, "Lendo o mapa...")
                task.wait()
            end
        end
        table.sort(cand, function(a, b) return a[2] > b[2] end)

        setProgress(0.3, "Lendo o terreno...")
        buildTerrain(my)
        if S.token ~= my then return end

        local n = math.min(#cand, MAX_PARTS)
        for i = 1, n do
            if S.token ~= my then return end
            local p = cand[i][1]
            local ok, c = pcall(function() return p:Clone() end)
            if ok and c then
                for _, ch in ipairs(c:GetChildren()) do
                    if not ch:IsA("DataModelMesh") then ch:Destroy() end
                end
                c.Anchored = true
                c.CanCollide = false
                c.Parent = mapModel
            end
            if i % 120 == 0 then
                setProgress(0.5 + 0.5 * i / n, "Montando o mapa...")
                task.wait()
            end
        end

        S.building, S.built = false, true
        setProgress(1, "Pronto")
        emptyNote.Visible = (#mapModel:GetChildren() == 0)
        S.snap = true
        local tw = TweenService:Create(loading, TweenInfo.new(0.45, Enum.EasingStyle.Quad), {GroupTransparency = 1})
        tw.Completed:Once(function()
            if S.token == my then loading.Visible = false end
        end)
        tw:Play()
    end

    local lastInfo = 0
    local NICE = {5, 10, 20, 50, 100, 200, 500, 1000, 2000}

    local function updateInfo()
        local meE = entries[Player]
        local myPos = S.myPos
        local ws = 16
        local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed > 1 then ws = hum.WalkSpeed end
        for plr, e in pairs(entries) do
            local r = rootOf(plr)
            if plr == Player then
                e.row.LayoutOrder = 0
                e.sub.Text = r and string.format("X %d  Y %d  Z %d", r.Position.X, r.Position.Y, r.Position.Z) or "Sem personagem"
            elseif r and myPos then
                local d = (r.Position - myPos).Magnitude
                e.row.LayoutOrder = 1 + math.floor(d)
                e.sub.Text = string.format("%d studs  ·  %s", d, fmtTime(d / ws))
            else
                e.row.LayoutOrder = 99999
                e.sub.Text = "Sem personagem"
            end
        end
        updateCount()
    end

    local function step(dt)
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            S.myPos = hrp.Position
            local lv = hrp.CFrame.LookVector
            local flat = Vector3.new(lv.X, 0, lv.Z)
            if flat.Magnitude > 0.05 then S.myLook = flat.Unit end
        end
        if not S.myPos then return end

        local tPos = S.myPos
        if S.free then
            tPos = S.panCenter
        elseif S.followPlr then
            local fr = rootOf(S.followPlr)
            if fr then tPos = fr.Position end
        end
        local wantUp = S.headingUp and S.myLook or Vector3.new(0, 0, -1)
        if S.snap then
            S.center, S.span, S.up, S.snap = tPos, S.targetSpan, wantUp, false
        else
            S.center = S.center:Lerp(tPos, 1 - math.exp(-dt * 9))
            S.span = S.span + (S.targetSpan - S.span) * (1 - math.exp(-dt * 8))
            local u = S.up:Lerp(wantUp, 1 - math.exp(-dt * 8))
            if u.Magnitude < 0.05 then u = wantUp end
            S.up = u.Unit
        end

        local alt = (S.span / 2) / TAN_HALF
        local eye = Vector3.new(S.center.X, S.center.Y + alt, S.center.Z)
        local up = S.up
        local right = Vector3.new(0, -1, 0):Cross(up)
        S.right = right
        cam.CFrame = CFrame.lookAt(eye, eye + Vector3.new(0, -1, 0), up)

        local sel = S.selected
        local t = os.clock()
        for plr, e in pairs(entries) do
            local m = e.marker
            local r = rootOf(plr)
            if not r then
                m.root.Visible = false
                e.px = nil
            else
                local pos = r.Position
                local rel = pos - eye
                local depth = math.max(eye.Y - pos.Y, 8)
                local k = (MAP_H / 2) / (depth * TAN_HALF)
                local px = MAP_W / 2 + rel:Dot(right) * k
                local py = MAP_H / 2 - rel:Dot(up) * k
                e.px, e.py = px, py
                local inside = px >= PAD and px <= MAP_W - PAD and py >= PAD and py <= MAP_H - PAD
                local cx, cy = px, py
                local dx, dy = px - MAP_W / 2, py - MAP_H / 2
                if not inside then
                    local sc = math.min((MAP_W / 2 - PAD) / math.max(math.abs(dx), 0.001), (MAP_H / 2 - PAD) / math.max(math.abs(dy), 0.001))
                    cx, cy = MAP_W / 2 + dx * sc, MAP_H / 2 + dy * sc
                end
                local size = m.isMe and 28 or 26
                if plr == sel then size = 32 end
                if not inside then size = 18 end
                m.root.Visible = true
                m.root.Size = UDim2.new(0, size, 0, size)
                m.root.Position = UDim2.new(0, cx, 0, cy)
                m.name.Visible = inside and not m.isMe and (S.span <= 420 or plr == sel)

                local nx, ny
                if m.isMe and inside then
                    local f = r.CFrame.LookVector
                    nx, ny = f:Dot(right), -f:Dot(up)
                elseif not inside then
                    nx, ny = dx, dy
                end
                if nx then
                    local mag = math.sqrt(nx * nx + ny * ny)
                    if mag > 0.05 then
                        m.nose.Visible = true
                        m.nose.Position = UDim2.new(0.5, nx / mag * (size / 2 + 2), 0.5, ny / mag * (size / 2 + 2))
                    else
                        m.nose.Visible = false
                    end
                else
                    m.nose.Visible = false
                end

                if m.pulse then
                    local ph = (t * 0.8) % 1
                    local ps = 26 + 34 * ph
                    m.pulse.Size = UDim2.new(0, ps, 0, ps)
                    m.pulseStroke.Transparency = 0.3 + 0.7 * ph
                end
            end
        end

        local meE = entries[Player]
        local selE = sel and entries[sel]
        if selE and meE and selE.px and meE.px and sel ~= Player then
            local x1, y1, x2, y2 = meE.px, meE.py, selE.px, selE.py
            local ddx, ddy = x2 - x1, y2 - y1
            routeLine.Visible = true
            routeLine.Size = UDim2.new(0, math.sqrt(ddx * ddx + ddy * ddy), 0, 3)
            routeLine.Position = UDim2.new(0, (x1 + x2) / 2, 0, (y1 + y2) / 2)
            routeLine.Rotation = math.deg(math.atan2(ddy, ddx))
            local rs, rm = rootOf(sel), S.myPos
            if rs and rm then
                local d = (rs.Position - rm).Magnitude
                local ws = 16
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.WalkSpeed > 1 then ws = hum.WalkSpeed end
                routeChip.Text = string.format("%d studs · %s", d, fmtTime(d / ws))
            end
            routeChip.Visible = true
            routeChip.Position = UDim2.new(0, math.clamp((x1 + x2) / 2, 50, MAP_W - 50), 0, math.clamp((y1 + y2) / 2, 14, MAP_H - 14))
        else
            routeLine.Visible = false
            routeChip.Visible = false
        end

        local north = Vector3.new(0, 0, -1)
        compassRot.Rotation = math.deg(math.atan2(north:Dot(right), north:Dot(up)))
        local kg = MAP_H / S.span
        local len = NICE[#NICE]
        for _, v in ipairs(NICE) do
            if v * kg >= 36 then len = v break end
        end
        scaleBar.Size = UDim2.new(0, len * kg, 0, 2)
        scaleText.Text = len .. " studs"
        coordText.Text = string.format("X %d  Y %d  Z %d", S.myPos.X, S.myPos.Y, S.myPos.Z)

        lastInfo = lastInfo + dt
        if lastInfo >= 0.3 then
            lastInfo = 0
            updateInfo()
            updatePing()
        end
    end

    local function setZoom(i)
        S.spanIdx = math.clamp(i, 1, #SPANS)
        S.targetSpan = SPANS[S.spanIdx]
    end
    zoomIn.MouseButton1Click:Connect(function() setZoom(S.spanIdx - 1) end)
    zoomOut.MouseButton1Click:Connect(function() setZoom(S.spanIdx + 1) end)
    dragBtn.MouseWheelForward:Connect(function() setZoom(S.spanIdx - 1) end)
    dragBtn.MouseWheelBackward:Connect(function() setZoom(S.spanIdx + 1) end)
    recenter.MouseButton1Click:Connect(function()
        S.selected, S.followPlr, S.free = nil, nil, false
        refreshSelection()
    end)
    compassBtn.MouseButton1Click:Connect(function()
        S.headingUp = not S.headingUp
        phoneSettings.gpsHeading = S.headingUp
        saveSettings()
        applyCompassState()
    end)
    styleBtn.MouseButton1Click:Connect(function()
        S.night = not S.night
        phoneSettings.gpsNight = S.night
        saveSettings()
        applyStyle()
    end)
    refreshBtn.MouseButton1Click:Connect(function()
        TweenService:Create(refreshIcon, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {Rotation = refreshIcon.Rotation + 360}):Play()
        task.spawn(buildMap)
    end)

    local dragging, lastPos, moved = false, nil, 0
    local function isPress(i)
        return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
    end
    dragBtn.InputBegan:Connect(function(i)
        if isPress(i) then
            dragging, lastPos, moved = true, i.Position, 0
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            local d = i.Position - lastPos
            lastPos = i.Position
            moved = moved + math.abs(d.X) + math.abs(d.Y)
            if moved > 6 then
                if not S.free then
                    S.free, S.panCenter = true, S.center
                    S.followPlr = nil
                    refreshSelection()
                end
                local scale = vp.AbsoluteSize.X / MAP_W
                if scale <= 0 then scale = 1 end
                local k = MAP_H / S.span
                S.panCenter = S.panCenter - S.right * (d.X / scale / k) + S.up * (d.Y / scale / k)
                S.center = S.panCenter
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if isPress(i) then dragging = false end
    end)

    local conn
    GPSFrame:GetPropertyChangedSignal("Visible"):Connect(function()
        if GPSFrame.Visible then
            if not conn then conn = RunService.RenderStepped:Connect(step) end
        elseif conn then
            conn:Disconnect()
            conn = nil
        end
    end)

    Players.PlayerAdded:Connect(function(p) addPlayer(p) updateCount() refreshSelection() end)
    Players.PlayerRemoving:Connect(removePlayer)
    for _, p in ipairs(Players:GetPlayers()) do addPlayer(p) end
    updateCount()
    refreshSelection()

    function GPS.onOpen()
        S.snap = true
        updateInfo()
        if not S.built and not S.building then task.spawn(buildMap) end
    end
    function GPS.onClose()
        S.token = S.token + 1
        S.building, S.built = false, false
        mapModel:ClearAllChildren()
        S.selected, S.followPlr, S.free = nil, nil, false
        refreshSelection()
    end
    function GPS.goBack()
        if S.selected or S.followPlr or S.free then
            S.selected, S.followPlr, S.free = nil, nil, false
            refreshSelection()
            return true
        end
        return false
    end
end
buildGPS()
end

do

local screens = {}
local openApps = {}
local currentScreen = "home"
local prevScreen = "home"
local showScreen

local function phonePos()
    local p = phoneSettings.phonePosition
    return UDim2.new(p.X, p.XOffset, p.Y, p.YOffset)
end
local function offsetY(pos, dy)
    return UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset + dy)
end

local function updateNavState()
    for _, nb in ipairs(navBars) do
        nb.setBackEnabled(currentScreen ~= "home")
    end
end

local RecentsFrame = Instance.new("Frame")
RecentsFrame.Name = "RecentsFrame"
RecentsFrame.Size = UDim2.new(0, 280, 0, 440)
RecentsFrame.Position = PhoneHome.Position
RecentsFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
RecentsFrame.BorderSizePixel = 0
RecentsFrame.Visible = false
RecentsFrame.Active = true
RecentsFrame.Parent = ScreenGui
corner(RecentsFrame, UDim.new(0, 28))

local rcBg = Instance.new("ImageLabel")
rcBg.Size = UDim2.new(1, 0, 1, 0)
rcBg.BackgroundTransparency = 1
rcBg.Image = currentWallpaper
rcBg.ScaleType = Enum.ScaleType.Crop
rcBg.ZIndex = 1
rcBg.Parent = RecentsFrame
corner(rcBg, UDim.new(0, 28))

local rcShade = Instance.new("Frame")
rcShade.Size = UDim2.new(1, 0, 1, 0)
rcShade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
rcShade.BackgroundTransparency = 0.35
rcShade.BorderSizePixel = 0
rcShade.ZIndex = 2
rcShade.Parent = RecentsFrame
corner(rcShade, UDim.new(0, 28))

Nav.shell.create(RecentsFrame)
Nav.status.create(RecentsFrame)

local rcTitle = Instance.new("TextLabel")
rcTitle.Size = UDim2.new(1, 0, 0, 28)
rcTitle.Position = UDim2.new(0, 0, 0, 48)
rcTitle.BackgroundTransparency = 1
rcTitle.Text = "Apps recentes"
rcTitle.TextColor3 = Color3.new(1, 1, 1)
rcTitle.Font = Enum.Font.GothamBold
rcTitle.TextSize = 18
rcTitle.ZIndex = 5
rcTitle.Parent = RecentsFrame

local CARD_W, CARD_H, CARD_GAP = 150, 250, 14

local recentsScroll = Instance.new("ScrollingFrame")
recentsScroll.Name = "RecentsScroll"
recentsScroll.Size = UDim2.new(1, 0, 0, CARD_H + 12)
recentsScroll.Position = UDim2.new(0, 0, 0, 84)
recentsScroll.BackgroundTransparency = 1
recentsScroll.BorderSizePixel = 0
recentsScroll.ScrollBarThickness = 0
recentsScroll.ScrollingDirection = Enum.ScrollingDirection.X
recentsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
recentsScroll.ZIndex = 5
recentsScroll.Parent = RecentsFrame

local rcLayout = Instance.new("UIListLayout")
rcLayout.FillDirection = Enum.FillDirection.Horizontal
rcLayout.Padding = UDim.new(0, CARD_GAP)
rcLayout.SortOrder = Enum.SortOrder.LayoutOrder
rcLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rcLayout.Parent = recentsScroll

local rcPad = Instance.new("UIPadding")
rcPad.PaddingLeft = UDim.new(0, 65)
rcPad.PaddingRight = UDim.new(0, 65)
rcPad.Parent = recentsScroll

local rcEmpty = Instance.new("TextLabel")
rcEmpty.Size = UDim2.new(1, 0, 0, 30)
rcEmpty.Position = UDim2.new(0, 0, 0, 190)
rcEmpty.BackgroundTransparency = 1
rcEmpty.Text = "Nenhum app recente"
rcEmpty.TextColor3 = Color3.fromRGB(190, 190, 200)
rcEmpty.Font = Enum.Font.Gotham
rcEmpty.TextSize = 14
rcEmpty.ZIndex = 5
rcEmpty.Visible = false
rcEmpty.Parent = RecentsFrame

local rcClear = Instance.new("TextButton")
rcClear.Name = "ClearAll"
rcClear.Size = UDim2.new(0, 110, 0, 28)
rcClear.Position = UDim2.new(0.5, -55, 0, 362)
rcClear.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
rcClear.BackgroundTransparency = 0.85
rcClear.Text = "Limpar tudo"
rcClear.TextColor3 = Color3.new(1, 1, 1)
rcClear.Font = Enum.Font.GothamBold
rcClear.TextSize = 12
rcClear.AutoButtonColor = false
rcClear.ZIndex = 6
rcClear.Parent = RecentsFrame
corner(rcClear, UDim.new(1, 0))

createNavBar(RecentsFrame)

local function makeBrowserScreen()
    local function uiScale()
        local ok, v = pcall(function() return phoneUIScale.Scale end)
        return (ok and tonumber(v)) or 1
    end
    local C = {
        bg = Color3.fromRGB(32, 33, 36),
        toolbar = Color3.fromRGB(41, 42, 45),
        pill = Color3.fromRGB(60, 64, 67),
        card = Color3.fromRGB(48, 49, 52),
        text = Color3.fromRGB(232, 234, 237),
        sub = Color3.fromRGB(154, 160, 166),
        blue = Color3.fromRGB(138, 180, 248),
        accent = Color3.fromRGB(66, 133, 244),
        red = Color3.fromRGB(242, 139, 130),
    }
    local PAL = {
        Color3.fromRGB(66, 133, 244), Color3.fromRGB(234, 67, 53), Color3.fromRGB(251, 188, 5),
        Color3.fromRGB(52, 168, 83), Color3.fromRGB(171, 71, 188), Color3.fromRGB(0, 172, 193),
    }
    local DEFAULT_BOOKMARKS = {
        {name = "Wikipedia", url = "https://pt.wikipedia.org/"},
        {name = "Roblox", url = "https://www.roblox.com/"},
        {name = "GitHub", url = "https://github.com/"},
        {name = "Reddit", url = "https://old.reddit.com/"},
        {name = "YouTube", url = "https://www.youtube.com/"},
        {name = "DuckDuckGo", url = "https://html.duckduckgo.com/html/"},
        {name = "Hacker News", url = "https://news.ycombinator.com/"},
        {name = "Bing", url = "https://www.bing.com/"},
    }

    local function new(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props) do o[k] = v end
        if parent then o.Parent = parent end
        return o
    end

    local U = {}
    -- ===== MODO ESCURO DO NAVEGADOR =====
    -- Converte as cores das paginas (fundo, texto, borda) na hora de montar o layout.
    -- Fundos claros escurecem, textos escuros clareiam; o que ja e escuro/colorido fica como esta
    -- (assim sites que ja tem tema escuro nao sao invertidos de volta).
    U.dark = {on = (phoneSettings.browserDark == true)}
    function U.dk(c, kind)
        if not U.dark.on or not c then return c end
        local r, g, b = c.R, c.G, c.B
        local y = 0.2126 * r + 0.7152 * g + 0.0722 * b
        local mx, mn = math.max(r, g, b), math.min(r, g, b)
        local l = (mx + mn) / 2
        local d = mx - mn
        local sat = (d == 0) and 0 or d / (1 - math.abs(2 * l - 1))
        local h = 0
        if d > 0 then
            if mx == r then h = ((g - b) / d) % 6
            elseif mx == g then h = (b - r) / d + 2
            else h = (r - g) / d + 4 end
            h = h / 6
        end
        local nl, ns = l, sat
        if kind == "bg" then
            if y <= 0.5 then return c end
            nl = 0.07 + (1 - l) * 0.35
            ns = sat * 0.75
        elseif kind == "fg" then
            if y >= 0.5 then return c end
            nl = math.clamp(1 - l, 0.68, 0.93)
        else
            if y > 0.55 then
                nl = math.clamp(1 - l, 0.16, 0.32)
                ns = sat * 0.6
            elseif y < 0.2 then
                nl = 0.3
            else
                return c
            end
        end
        local v = nl + ns * math.min(nl, 1 - nl)
        local sv = (v == 0) and 0 or 2 * (1 - nl / v)
        return Color3.fromHSV(h, math.clamp(sv, 0, 1), math.clamp(v, 0, 1))
    end

    function U.httpGet(url)
        local req = request or http_request or (syn and syn.request)
        if type(req) == "function" then
            local headers = { ["User-Agent"] = U.SEARCH_UA or "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0 Safari/537.36", ["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8", ["Accept-Language"] = "pt-BR,pt;q=0.9,en;q=0.7" }
            if url:find("bing.com", 1, true) then headers["Cookie"] = "SRCHHPGUSR=ADLT=OFF" end   -- SafeSearch desligado
            local response = req({Url = url, Method = "GET", Headers = headers})
            if type(response) == "table" then
                local body = response.Body or response.body
                local code = tonumber(response.StatusCode or response.Status or response.status_code)
                if code and (code < 200 or code >= 400) then
                    error("HTTP " .. tostring(code) .. " ao carregar o recurso")
                end
                if type(body) == "string" and body ~= "" then return body end
            end
            error("Resposta HTTP vazia ou bloqueada pelo site")
        end
        if game.HttpGet then return game:HttpGet(url) end
        error("Seu ambiente não disponibiliza uma função HTTP GET")
    end
    -- Requisicao dedicada aos buscadores: User-Agent de navegador atual + idioma pt-BR (varios buscadores
    -- recusam o "Mozilla/5.0" puro). NAO altera U.httpGet, que continua servindo o resto do navegador.
    U.SEARCH_UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    function U.httpGetH(url, extra)
        local req = request or http_request or (syn and syn.request)
        if type(req) ~= "function" then return U.httpGet(url) end
        local headers = {
            ["User-Agent"] = U.SEARCH_UA,
            ["Accept"] = "text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8",
            ["Accept-Language"] = "pt-BR,pt;q=0.9,en;q=0.7",
        }
        for k, v in pairs(extra or {}) do headers[k] = v end
        local response = req({Url = url, Method = "GET", Headers = headers})
        if type(response) == "table" and type(response.Body) == "string" and response.Body ~= "" then return response.Body end
        error("Resposta HTTP vazia")
    end
    -- Divide o HTML em blocos que comecam em cada ocorrencia de "marker" (1 bloco por resultado)
    function U.chunks(html, marker)
        local starts, i = {}, 1
        while true do
            local a = html:find(marker, i, true)
            if not a then break end
            starts[#starts + 1] = a
            i = a + #marker
        end
        local out = {}
        for k, a in ipairs(starts) do
            local b = (starts[k + 1] or (#html + 1)) - 1
            if b - a > 7000 then b = a + 7000 end
            out[#out + 1] = html:sub(a, b)
        end
        return out
    end
    -- Primeiro padrao que render texto nao vazio (ja sem HTML)
    function U.pick(block, pats)
        for _, p in ipairs(pats) do
            local m = block:match(p)
            if m then
                local t = U.plain(m)
                if t ~= "" then return t end
            end
        end
        return ""
    end
    function U.decode(t)
        t = t:gsub("&nbsp;", " "):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&#39;", "'"):gsub("&amp;", "&")
        t = t:gsub("&#(%d+);", function(n) return utf8.char(tonumber(n)) end)
        return t
    end
    function U.plain(s)
        s = s:gsub("<[^>]->", " ")
        s = U.decode(s)
        s = s:gsub("%s+", " ")
        s = s:gsub("^%s+", ""):gsub("%s+$", "")
        return s
    end
    function U.urlDecode(s)
        return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
    end
    function U.esc(s)
        s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
        return s
    end
    function U.hostOf(url)
        local h = url:match("^https?://([^/%?#]+)") or url
        h = h:gsub("^www%.", "")
        return h
    end
    function U.looksLikeUrl(t)
        if t:match("^https?://") then return true end
        if t:find("%s") then return false end
        return t:match("^[%w%-%.]+%.%a%a+") ~= nil
    end
    function U.resolve(base, href)
        href = href:gsub("&amp;", "&"):gsub("^%s+", ""):gsub("%s+$", "")
        if href == "" or href:sub(1, 1) == "#" or href:match("^javascript:") or href:match("^mailto:") or href:match("^tel:") or href:match("^data:") then return nil end
        if href:match("^https?://") then return href end
        if href:sub(1, 2) == "//" then return "https:" .. href end
        local origin = base:match("^(https?://[^/%?#]+)")
        if not origin then return nil end
        if href:sub(1, 1) == "/" then return origin .. href end
        local dir = base:match("^(https?://[^%?#]*/)") or (origin .. "/")
        return dir .. href
    end
    function U.rich(html, limit)
        html = html:gsub("<!%-%-.-%-%->", " "):gsub("<head.-</head>", " "):gsub("<script.-</script>", " "):gsub("<style.-</style>", " "):gsub("<noscript.-</noscript>", " "):gsub("<svg.-</svg>", " ")
        html = html:gsub("<[hH][1-6][^>]*>", "\n\1"):gsub("</[hH][1-6]%s*>", "\2\n")
        html = html:gsub("<[lL][iI][^>]*>", "\n• "):gsub("<[bB][rR]%s*/?>", "\n"):gsub("</[pP]%s*>", "\n\n"):gsub("</[dD][iI][vV]%s*>", "\n"):gsub("</[tT][rR]%s*>", "\n")
        html = html:gsub("<[^>]->", " ")
        html = U.decode(html)
        html = html:gsub("[ \t\r]+", " "):gsub("\n +", "\n"):gsub("\n\n\n+", "\n\n"):gsub("^%s+", "")
        local lim = limit or 8000
        if #html > lim then
            html = html:sub(1, (utf8.offset(html, lim + 1) or (lim + 1)) - 1) .. "…"
        end
        if html == "" then html = "(Esta página não tem conteúdo de texto para exibir.)" end
        html = U.esc(html)
        html = html:gsub("\1", '<b><font color="#8ab4f8">'):gsub("\2", "</font></b>")
        return html
    end
    function U.hash(s)
        local n = 0
        for i = 1, #s do n = n + s:byte(i) end
        return n
    end

    local CACHE_DIR = "PHONE/Cache"
    local imgCache = {}
    local imgPath = {}
    local imgKind, gifMeta = {}, {}
    local hasAssetFn = true
    function U.hash2(str)
        local h1, h2 = 5381, 52711
        for i = 1, #str do
            local c = str:byte(i)
            h1 = (h1 * 33 + c) % 4294967296
            h2 = (h2 * 31 + c) % 4294967291
        end
        return string.format("%08x%08x", h1, h2)
    end
    local PROXIES = {"https://wsrv.nl/", "https://images.weserv.nl/"}
    -- Formatos de imagem encontrados na web. O Roblox nao decodifica todos eles
    -- diretamente: os formatos fora de PNG/JPEG passam por conversao para PNG.
    local IMG_EXT = {
        png = true, apng = true, jpg = true, jpeg = true, jpe = true, jfif = true,
        gif = true, webp = true, bmp = true, dib = true, avif = true, avis = true,
        svg = true, svgz = true, ico = true, cur = true, tif = true, tiff = true,
        heic = true, heif = true, jxl = true, qoi = true, psd = true, tga = true,
        dds = true, pcx = true, ppm = true, pgm = true, pbm = true, hdr = true,
    }
    function U.imgExt(b)
        if type(b) ~= "string" then return nil end
        if b:sub(1, 8) == "\137PNG\r\n\26\n" then return "png" end
        if b:sub(1, 3) == "\255\216\255" then return "jpg" end
        return nil
    end
    local HEIF = {avif = true, avis = true, heic = true, heix = true, hevc = true, hevx = true, mif1 = true, msf1 = true}
    function U.sniff(b)
        if type(b) ~= "string" or #b < 4 then return nil end
        local h = b:sub(1, 16)
        if h:sub(1, 8) == "\137PNG\r\n\26\n" then
            if b:find("acTL", 9, true) then return "apng" end
            return "png"
        end
        if h:sub(1, 3) == "\255\216\255" then return "jpg" end
        if h:sub(1, 3) == "GIF" then return "gif" end
        if h:sub(1, 4) == "RIFF" and h:sub(9, 12) == "WEBP" then return "webp" end
        if h:sub(1, 2) == "BM" then return "bmp" end
        if h:sub(5, 8) == "ftyp" and HEIF[h:sub(9, 12)] then
            local brand = h:sub(9, 12)
            return (brand == "avif" or brand == "avis") and "avif" or "heic"
        end
        if h:sub(1, 2) == "II" and h:byte(3) == 42 and h:byte(4) == 0 then return "tiff" end
        if h:sub(1, 2) == "MM" and h:byte(3) == 0 and h:byte(4) == 42 then return "tiff" end
        if h:sub(1, 4) == "\0\0\1\0" then return "ico" end
        if h:sub(1, 4) == "qoif" then return "qoi" end
        if h:sub(1, 4) == "8BPS" then return "psd" end
        if h:sub(1, 4) == "DDS " then return "dds" end
        if h:sub(1, 4) == "\0\0\0\12" and h:sub(5, 12) == "JXL \r\n\135\n" then return "jxl" end
        if h:sub(1, 2) == "\255\10" then return "jxl" end -- JPEG XL codestream
        if h:sub(1, 2) == "\10\5" or h:sub(1, 2) == "\10\2" then return "pcx" end
        local head = b:sub(1, 4096):gsub("^\239\187\191", ""):lower()
        if head:find("<svg", 1, true) or head:find("<!doctype svg", 1, true) then return "svg" end
        if head:match("^%s*<%?xml") and head:find("<svg", 1, true) then return "svg" end
        return nil
    end
    function U.parseGif(b)
        if #b < 20 or b:sub(1, 3) ~= "GIF" then return nil end
        local w = b:byte(7) + b:byte(8) * 256
        local h = b:byte(9) + b:byte(10) * 256
        local flags = b:byte(11)
        local pos = 14
        if flags >= 128 then pos = pos + 3 * math.floor(2 ^ ((flags % 8) + 1)) end
        local delays, n, pending, len = {}, 0, 10, #b
        while pos <= len do
            local c = b:byte(pos)
            if c == 0x21 then
                if b:byte(pos + 1) == 0xF9 and b:byte(pos + 2) == 4 then
                    pending = (b:byte(pos + 4) or 10) + (b:byte(pos + 5) or 0) * 256
                    if pending <= 1 then pending = 10 end
                end
                pos = pos + 2
                while pos <= len do
                    local sz = b:byte(pos)
                    if sz == 0 then pos = pos + 1; break end
                    pos = pos + 1 + sz
                end
            elseif c == 0x2C then
                local f = b:byte(pos + 9) or 0
                pos = pos + 10
                if f >= 128 then pos = pos + 3 * math.floor(2 ^ ((f % 8) + 1)) end
                pos = pos + 1
                while pos <= len do
                    local sz = b:byte(pos)
                    if sz == 0 then pos = pos + 1; break end
                    pos = pos + 1 + sz
                end
                n = n + 1
                delays[n] = pending
                pending = 10
            else
                break
            end
        end
        if n < 1 then return nil end
        return {w = w, h = h, n = n, delays = delays}
    end
    function U.proxy(url, extra, p)
        return (PROXIES[p or 1] or PROXIES[1]) .. "?url=" .. HttpService:UrlEncode(url) .. (extra or "")
    end
    function U.ensureCache()
        pcall(function()
            if not isfolder("PHONE") then makefolder("PHONE") end
            if not isfolder(CACHE_DIR) then makefolder(CACHE_DIR) end
        end)
    end
    function U.cachedAsset(key)
        for _, ext in ipairs({"jpg", "png"}) do
            local path = CACHE_DIR .. "/" .. key .. "." .. ext
            local okF, has = pcall(isfile, path)
            if okF and has then
                local okA, a = pcall(getcustomasset, path)
                if okA and type(a) == "string" and a ~= "" then return a, path end
            end
        end
        return nil
    end
    function U.storeBody(body, key)
        local ext = U.imgExt(body)
        if not ext then return nil end
        U.ensureCache()
        local path = CACHE_DIR .. "/" .. key .. "." .. ext
        if not pcall(writefile, path, body) then return nil end
        local okA, a = pcall(getcustomasset, path)
        if okA and type(a) == "string" and a ~= "" then return a, path end
        hasAssetFn = false
        return nil
    end
    function U.saveMeta(url, m)
        U.ensureCache()
        pcall(writefile, CACHE_DIR .. "/" .. U.hash2(url) .. ".gifmeta", m.w .. " " .. m.h .. " " .. m.n .. "\n" .. table.concat(m.delays, ","))
    end
    -- Requisicao propria para imagens: alguns CDNs (incluindo hosts de avatares e anexos)
    -- respondem diferente quando recebem Accept de documento HTML. Mantem UA de navegador,
    -- pede formatos de imagem e envia Referer quando conhecido.
    function U.httpGetImage(url, referer)
        local req = request or http_request or (syn and syn.request)
        if type(req) ~= "function" then return U.httpGet(url) end
        local headers = {
            ["User-Agent"] = U.SEARCH_UA or "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0 Safari/537.36",
            ["Accept"] = "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
            ["Accept-Language"] = "pt-BR,pt;q=0.9,en;q=0.7",
            ["Cache-Control"] = "max-age=0",
            ["Pragma"] = "no-cache",
        }
        if type(referer) == "string" and referer:match("^https?://") then headers["Referer"] = referer end
        local response = req({Url = url, Method = "GET", Headers = headers})
        if type(response) == "table" then
            local body = response.Body or response.body
            local code = tonumber(response.StatusCode or response.Status or response.status_code)
            if code and (code < 200 or code >= 400) then error("HTTP " .. tostring(code) .. " ao carregar imagem") end
            if type(body) == "string" and body ~= "" then return body end
        end
        error("Imagem bloqueada ou resposta vazia")
    end
    function U.cacheImage(url, maxBytes, referer)
        if type(url) ~= "string" or url == "" then return nil end
        if imgCache[url] then return imgCache[url] end
        U.ensureCache()
        local key = U.hash2(url)
        local a, path = U.cachedAsset(key)
        if a then imgCache[url] = a; imgPath[url] = path; return a end
        local limit = maxBytes or 4000000
        local okG, body = pcall(U.httpGetImage, url, referer)
        if okG and type(body) == "string" and #body >= 16 then
            local kind = U.sniff(body)
            imgKind[url] = kind or "unknown"
            if kind == "gif" then
                U.rememberGif(url, body)
                local m = U.parseGif(body)
                if m then gifMeta[url] = m; U.saveMeta(url, m) end
            end
            -- Somente formatos aceitos pelo getcustomasset sao gravados sem conversao.
            if (kind == "png" or kind == "jpg") and #body <= limit then
                a, path = U.storeBody(body, key)
                if a then imgCache[url] = a; imgPath[url] = path; return a end
            end
        end
        if not hasAssetFn then return nil end
        -- Conversao server-side para PNG: GIF (primeiro quadro), WebP, AVIF/HEIC,
        -- SVG/SVGZ, BMP, ICO/CUR, TIFF, JPEG XL, QOI e outros formatos reconhecidos
        -- pelo conversor. A resposta e validada por assinatura para nao salvar HTML de erro.
        local variants = {
            "&output=png&w=1800&h=1800&fit=inside&we",
            "&output=png&w=1200&h=1200&fit=contain",
            "&output=jpg&w=1200&h=1200&fit=inside",
            "&output=png&w=900&h=900&fit=inside",
        }
        for p = 1, #PROXIES do
            for _, extra in ipairs(variants) do
                local okP, pb = pcall(U.httpGet, U.proxy(url, extra, p))
                if okP and type(pb) == "string" and #pb >= 16 then
                    local convertedKind = U.sniff(pb)
                    if convertedKind == "png" or convertedKind == "jpg" then
                        a, path = U.storeBody(pb, key)
                        if a then
                            imgCache[url] = a
                            imgPath[url] = path
                            return a
                        end
                    end
                end
            end
        end
        return nil
    end
    function U.gifMeta(url)
        if gifMeta[url] then return gifMeta[url] end
        if gifMeta[url] == false then return nil end
        local mpath = CACHE_DIR .. "/" .. U.hash2(url) .. ".gifmeta"
        local okF, has = pcall(isfile, mpath)
        if okF and has then
            local okR, txt = pcall(readfile, mpath)
            if okR and type(txt) == "string" then
                local w, h, n, ds = txt:match("^(%d+) (%d+) (%d+)\n(.*)$")
                if w then
                    local d = {}
                    for v in ds:gmatch("%d+") do d[#d + 1] = tonumber(v) end
                    gifMeta[url] = {w = tonumber(w), h = tonumber(h), n = tonumber(n), delays = d}
                    return gifMeta[url]
                end
            end
        end
        local okG, body = pcall(U.httpGet, url)
        local m = okG and type(body) == "string" and U.parseGif(body) or nil
        if not m then gifMeta[url] = false; return nil end
        gifMeta[url] = m
        U.saveMeta(url, m)
        return m
    end
    function U.maybeGif(url)
        if gifMeta[url] == false then return false end
        if imgKind[url] == "gif" or gifMeta[url] then return true end
        if url:lower():match("%.gif") then return true end
        local okF, has = pcall(isfile, CACHE_DIR .. "/" .. U.hash2(url) .. ".gifmeta")
        return okF and has == true
    end
    -- cache em memoria dos ultimos GIFs baixados: ver, baixar e salvar na Galeria usam 1 download so
    local gifBodies, gifBodyOrder = {}, {}
    function U.rememberGif(url, body)
        if type(body) ~= "string" or body:sub(1, 3) ~= "GIF" then return end
        if not gifBodies[url] then
            gifBodyOrder[#gifBodyOrder + 1] = url
            if #gifBodyOrder > 4 then
                local old = table.remove(gifBodyOrder, 1)
                gifBodies[old] = nil
            end
        end
        gifBodies[url] = body
    end
    function U.gifBody(url, referer)
        local b = gifBodies[url]
        if b then return b end
        -- Usa o mesmo pedido de imagem (User-Agent, Accept e Referer) dos thumbnails.
        local okG, body = pcall(U.httpGetImage, url, referer)
        if okG and type(body) == "string" and body:sub(1, 3) == "GIF" then
            U.rememberGif(url, body)
            return body
        end
        return nil
    end
    -- Tenta converter APNG/WebP animado para GIF animado, formato que o
    -- decodificador interno consegue transformar em quadros PNG reproduziveis.
    -- A conversao e externa; se o proxy devolver apenas um quadro, nao inventamos animacao.
    function U.animatedImageAsGif(url, referer, body)
        if type(body) == "string" and body:sub(1, 3) == "GIF" then return body end
        local kind = U.sniff(body or "")
        local animated = false
        if kind == "apng" and body:find("acTL", 9, true) then
            animated = true
        elseif kind == "webp" and body:find("ANIM", 13, true) then
            animated = true
        end
        if not animated then return nil end
        local extras = {
            "&output=gif&w=900&h=900&fit=inside",
            "&output=gif&w=640&h=640&fit=inside",
        }
        for proxyIndex = 1, #PROXIES do
            for _, extra in ipairs(extras) do
                local ok, converted = pcall(U.httpGetImage, U.proxy(url, extra, proxyIndex), referer)
                if ok and type(converted) == "string" and converted:sub(1, 3) == "GIF" then
                    local meta = U.parseGif(converted)
                    if meta and meta.n > 1 then
                        U.rememberGif(url, converted)
                        return converted
                    end
                end
            end
        end
        return nil
    end
    -- baixa ate 24 quadros do GIF (um PNG por quadro, via proxy) e devolve {assets, delays}
    function U.gifFrames(url, meta, onProg, cancelled)
        local n, MAXF = meta.n, 24
        local step = math.max(1, math.ceil(n / MAXF))
        local idx, dl, i = {}, {}, 1
        while i <= n do
            local sum = 0
            for k = i, math.min(i + step - 1, n) do sum = sum + (meta.delays[k] or 10) end
            idx[#idx + 1] = i
            dl[#dl + 1] = sum
            i = i + step
        end
        local total, assets, done, nextJ = #idx, {}, 0, 0
        local key = U.hash2(url)
        local width = math.max(64, math.min(meta.w, 280))
        local function worker()
            while true do
                if cancelled() then return end
                nextJ = nextJ + 1
                local j = nextJ
                if j > total then return end
                local fkey = key .. "_f" .. idx[j]
                local a = U.cachedAsset(fkey)
                if not a then
                    for p = 1, #PROXIES do
                        local okP, pb = pcall(U.httpGet, U.proxy(url, "&page=" .. (idx[j] - 1) .. "&output=png&w=" .. width .. "&we", p))
                        if okP and type(pb) == "string" then
                            a = U.storeBody(pb, fkey)
                            if a then break end
                        end
                    end
                end
                assets[j] = a or false
                done = done + 1
                onProg(done, total)
            end
        end
        local running = 4
        for _ = 1, 4 do
            task.spawn(function() worker(); running = running - 1 end)
        end
        local t0 = os.clock()
        while running > 0 and os.clock() - t0 < 60 and not cancelled() do task.wait(0.1) end
        local out, delays, last = {}, {}, nil
        for j = 1, total do
            local a = assets[j] or last
            if a then
                out[#out + 1] = a
                delays[#delays + 1] = dl[j] / 100
                last = a
            end
        end
        if #out < 2 then return nil end
        return {assets = out, delays = delays}
    end

    local DL_DIR = "PHONE/Downloads"
    local DL_EXT = {mp3 = true, ogg = true, png = true, jpg = true, jpeg = true, txt = true, lua = true, json = true, zip = true, pdf = true, mp4 = true, rbxm = true, rbxl = true, csv = true}
    function U.ensureDl()
        pcall(function()
            if not isfolder("PHONE") then makefolder("PHONE") end
            if not isfolder(DL_DIR) then makefolder(DL_DIR) end
        end)
    end
    function U.fileExt(url)
        local path = url:match("^https?://[^/?#]+/([^?#]*)")
        if not path then return nil end
        local ext = path:match("([^/]+)$") and path:match("%.(%w+)$")
        return ext and ext:lower() or nil
    end
    function U.fileName(url, ext)
        local seg = url:match("^https?://[^?#]*/([^/?#]+)") or ("arquivo." .. ext)
        seg = (U.urlDecode(seg):gsub("[^%w%-%._ ]", "_"))
        seg = seg:sub(1, 60)
        if seg == "" then seg = "arquivo." .. ext end
        return seg
    end
    function U.humanSize(n)
        if n >= 1048576 then return string.format("%.1f MB", n / 1048576) end
        if n >= 1024 then return string.format("%.1f KB", n / 1024) end
        return n .. " B"
    end
    function U.download(url, ext)
        U.ensureDl()
        local body = U.httpGet(url)
        if type(body) ~= "string" or #body == 0 then error("Arquivo vazio") end
        local name = U.fileName(url, ext)
        local path = DL_DIR .. "/" .. name
        local okF, has = pcall(isfile, path)
        if okF and has then
            name = os.time() .. "_" .. name
            path = DL_DIR .. "/" .. name
        end
        if not pcall(writefile, path, body) then error("Não foi possível salvar (writefile indisponível)") end
        return {kind = "download", title = name, name = name, path = path, ext = ext, size = #body, preview = "Download: " .. name}
    end
    -- FIX: nunca sobrescreve um arquivo diferente com o mesmo nome (isso misturava GIFs/fotos).
    -- Se o destino ja tem EXATAMENTE o mesmo conteudo, nao copia de novo (retorna true).
    function U.sendTo(path, dir)
        local okR, data = pcall(readfile, path)
        if not okR or type(data) ~= "string" or data == "" then return false end
        pcall(function() if not isfolder(dir) then makefolder(dir) end end)
        local name = path:match("([^/\\]+)$") or "arquivo"
        local target = dir .. "/" .. name
        local okF, has = pcall(isfile, target)
        if okF and has then
            local okD, old = pcall(readfile, target)
            if okD and old == data then return true, target end
            local base, ext = name:match("^(.*)%.(%w+)$")
            if not base then base, ext = name, nil end
            local fp = Nav.gif.fingerprint(data):match("_(%x+)$") or tostring(os.time())
            name = base .. "_" .. fp:sub(1, 6) .. (ext and ("." .. ext) or "")
            target = dir .. "/" .. name
            local okF2, has2 = pcall(isfile, target)
            if okF2 and has2 then
                local okD2, old2 = pcall(readfile, target)
                if okD2 and old2 == data then return true, target end
            end
        end
        return (pcall(writefile, target, data)), target
    end
    function U.purgeCache()
        imgCache = {}
        gifMeta = {}
        pcall(Nav.gif.purge, "br_")
        local n = 0
        pcall(function()
            for _, f in ipairs(listfiles(CACHE_DIR)) do
                if pcall(delfile, f) then n = n + 1 end
            end
        end)
        return n
    end
    pcall(function()
        U.ensureCache()
        if #listfiles(CACHE_DIR) > 1500 then U.purgeCache() end
        -- quadros de GIF do navegador ocupam muito disco: limpa quando passar de 40 pastas
        local nBr = 0
        for _, d in ipairs(listfiles("PHONE/GifFrames")) do
            if (tostring(d):gsub("\\", "/"):match("([^/]+)$") or ""):sub(1, 3) == "br_" then nBr = nBr + 1 end
        end
        if nBr > 40 then pcall(Nav.gif.purge, "br_") end
    end)

    local tabs, cur = {}, 1
    local render, navigate, loadEntry, reload, showEntry, refreshSwitcher, closeOverlays, openPanel, toast
    local function newTab() return {hist = {{ntp = true, state = "done"}}, pos = 1} end
    tabs[1] = newTab()
    local function curEntry() local t = tabs[cur]; return t.hist[t.pos] end

    local function bookmarks()
        if type(phoneSettings.browserBookmarks) ~= "table" then
            phoneSettings.browserBookmarks = {}
            for _, b in ipairs(DEFAULT_BOOKMARKS) do table.insert(phoneSettings.browserBookmarks, {name = b.name, url = b.url}) end
            saveSettings()
        end
        return phoneSettings.browserBookmarks
    end
    local function history()
        if type(phoneSettings.browserHistory) ~= "table" then phoneSettings.browserHistory = {} end
        return phoneSettings.browserHistory
    end
    local function isBookmarked(url)
        if not url then return false end
        for i, b in ipairs(bookmarks()) do if b.url == url then return true, i end end
        return false
    end

    local function lockIcon(parent, S, color, z)
        local c = new("Frame", {Size = UDim2.new(0, S, 0, S), BackgroundTransparency = 1, ZIndex = z}, parent)
        local sh = new("Frame", {Size = UDim2.new(0, S * 0.5, 0, S * 0.6), Position = UDim2.new(0.25, 0, 0.02, 0), BackgroundTransparency = 1, ZIndex = z}, c)
        corner(sh, UDim.new(0.5, 0))
        new("UIStroke", {Color = color, Thickness = 1.5}, sh)
        local body = new("Frame", {Size = UDim2.new(0, S * 0.8, 0, S * 0.5), Position = UDim2.new(0.1, 0, 0.46, 0), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z}, c)
        corner(body, UDim.new(0, 2))
        return c
    end
    local function favicon(parent, label, size, z)
        local clean = label:gsub("^https?://", "")
        clean = clean:gsub("^www%.", "")
        local letter = (clean:match("%a") or clean:match("%w") or "?"):upper()
        local f = new("Frame", {Size = UDim2.new(0, size, 0, size), BackgroundColor3 = PAL[(U.hash(clean) % #PAL) + 1], BorderSizePixel = 0, ZIndex = z}, parent)
        corner(f, UDim.new(1, 0))
        new("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = letter, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = math.max(8, math.floor(size * 0.5)), ZIndex = z + 1}, f)
        return f
    end
    local function iconButton(parent, fn, S, color, pos, size, z)
        local b = new("TextButton", {Position = pos, Size = size, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = z}, parent)
        Icons.put(b, fn, S, color, z + 1)
        return b
    end

    local frame = new("Frame", {
        Name = "WebBrowserFrame", Size = UDim2.new(0, 280, 0, 440), Position = PhoneHome.Position,
        BackgroundColor3 = C.bg, BorderSizePixel = 0, Visible = false, Active = true,
    }, ScreenGui)
    corner(frame, UDim.new(0, 28))
    Nav.shell.create(frame)
    Nav.status.create(frame)

    local tbTop = new("Frame", {Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = C.toolbar, BorderSizePixel = 0, ZIndex = 3}, frame)
    corner(tbTop, UDim.new(0, 28))
    new("Frame", {Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.toolbar, BorderSizePixel = 0, ZIndex = 3}, frame)

    local pill = new("Frame", {Position = UDim2.new(0, 8, 0, 40), Size = UDim2.new(0, 192, 0, 34), BackgroundColor3 = C.pill, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 6}, frame)
    corner(pill, UDim.new(0, 17))
    local siteBtn = new("TextButton", {Position = UDim2.new(0, 6, 0, 5), Size = UDim2.new(0, 24, 0, 24), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 7}, pill)
    local address = new("TextBox", {
        Name = "AddressOrSearch", Position = UDim2.new(0, 32, 0, 0), Size = UDim2.new(1, -62, 1, 0), BackgroundTransparency = 1,
        Text = "", PlaceholderText = "Pesquisar ou URL", PlaceholderColor3 = C.sub, TextColor3 = C.text,
        ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd,
        ClipsDescendants = true, ZIndex = 7,
    }, pill)
    local reloadBtn = new("TextButton", {Position = UDim2.new(1, -30, 0, 3), Size = UDim2.new(0, 28, 0, 28), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 7}, pill)

    local tabBtn = iconButton(frame, Icons.recents, 22, C.text, UDim2.new(0, 204, 0, 40), UDim2.new(0, 34, 0, 34), 6)
    local tabCount = new("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "1", TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 10, ZIndex = 9}, tabBtn)
    local menuBtn = iconButton(frame, Icons.dotsV, 18, C.text, UDim2.new(0, 240, 0, 40), UDim2.new(0, 32, 0, 34), 6)

    local progress = new("Frame", {Position = UDim2.new(0, 0, 0, 82), Size = UDim2.new(0, 0, 0, 2), BackgroundColor3 = C.accent, BorderSizePixel = 0, Visible = false, ZIndex = 12}, frame)
    local progToken = 0
    local function progStart()
        progToken = progToken + 1
        progress.Visible = true
        progress.Size = UDim2.new(0, 0, 0, 2)
        TweenService:Create(progress, TweenInfo.new(6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0.85, 0, 0, 2)}):Play()
    end
    local function progDone()
        progToken = progToken + 1
        local t = progToken
        progress.Visible = true
        TweenService:Create(progress, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 2)}):Play()
        task.delay(0.35, function() if t == progToken then progress.Visible = false end end)
    end

    local area = new("Frame", {Position = UDim2.new(0, 0, 0, 84), Size = UDim2.new(1, 0, 1, -122), BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 3}, frame)
    local ntpView = new("ScrollingFrame", {ClipsDescendants = true, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 300), ZIndex = 4}, area)
    local pageView = new("ScrollingFrame", {Name = "WebContent", ClipsDescendants = true, ScrollingDirection = Enum.ScrollingDirection.Y, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 4}, area)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)}, pageView)
    new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, pageView)

    local toastLbl = new("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -46), Size = UDim2.new(0, 0, 0, 26), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Color3.fromRGB(60, 64, 67), Text = "", TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 11, Visible = false, ZIndex = 40,
        TextTruncate = Enum.TextTruncate.AtEnd, ClipsDescendants = true,
    }, frame)
    corner(toastLbl, UDim.new(0, 13))
    new("UISizeConstraint", {MaxSize = Vector2.new(244, 26)}, toastLbl)
    new("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)}, toastLbl)
    local toastId = 0
    toast = function(msg)
        toastId = toastId + 1
        local id = toastId
        toastLbl.Text = msg
        toastLbl.Visible = true
        task.delay(1.6, function() if id == toastId then toastLbl.Visible = false end end)
    end

    local viewer = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Visible = false, ZIndex = 15}, area)
    local WHITE = Color3.new(1, 1, 1)
    local viewerClip = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 16}, viewer)
    local viewerImg = new("ImageLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Image = "", ZIndex = 16}, viewerClip)
    local viewerImg2 = new("ImageLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ImageTransparency = 1, Visible = false, ZIndex = 17}, viewerImg)
    local viewerMsg = new("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "Carregando…", TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true, ZIndex = 17}, viewer)
    local viewerTap = new("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 18}, viewer)

    local vTop = new("Frame", {Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 20}, viewer)
    local viewerBack = iconButton(vTop, Icons.back, 16, WHITE, UDim2.new(0, 6, 0, 5), UDim2.new(0, 34, 0, 34), 21)
    local viewerTitle = new("TextLabel", {Position = UDim2.new(0, 46, 0, 0), Size = UDim2.new(1, -140, 1, 0), BackgroundTransparency = 1, Text = "", TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 21}, vTop)
    local viewerCount = new("TextLabel", {Position = UDim2.new(1, -90, 0, 0), Size = UDim2.new(0, 50, 1, 0), BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(200, 200, 205), Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 21}, vTop)
    local viewerMore = new("TextButton", {Position = UDim2.new(1, -38, 0, 5), Size = UDim2.new(0, 34, 0, 34), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 21}, vTop)
    for k = 0, 2 do
        local dot = new("Frame", {Position = UDim2.new(0.5, -2, 0.5, -11 + k * 9), Size = UDim2.new(0, 4, 0, 4), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 22}, viewerMore)
        corner(dot, UDim.new(1, 0))
    end

    local vBot = new("Frame", {Position = UDim2.new(0, 0, 1, -54), Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 20}, viewer)
    local vBotLbl = new("TextLabel", {Position = UDim2.new(0, 12, 0, 2), Size = UDim2.new(1, -100, 1, -4), BackgroundTransparency = 1, Text = "", RichText = true, TextColor3 = WHITE, Font = Enum.Font.Gotham, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 21}, vBot)
    local viewerVisit = new("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 78, 0, 30), BackgroundColor3 = C.accent, BorderSizePixel = 0, Text = "Visitar", TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 21}, vBot)
    corner(viewerVisit, UDim.new(0, 15))

    local viewerSmooth = new("TextButton", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 76), Size = UDim2.new(0, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "60 FPS", TextColor3 = Color3.fromRGB(120, 255, 160), Font = Enum.Font.GothamBold, TextSize = 10, Visible = false, AutoButtonColor = false, ZIndex = 21}, viewer)
    corner(viewerSmooth, UDim.new(0, 10))
    new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, viewerSmooth)
    local viewerBadge = new("TextButton", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 50), Size = UDim2.new(0, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "GIF", TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 10, Visible = false, AutoButtonColor = false, ZIndex = 21}, viewer)
    corner(viewerBadge, UDim.new(0, 10))
    new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, viewerBadge)

    local barsOn = true
    local function setBars(on)
        barsOn = on
        vTop.Visible = on
        vBot.Visible = on
    end
    local vMenuLayer = new("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 23}, viewer)
    local vMenu = new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 42), Size = UDim2.new(0, 190, 0, 152), BackgroundColor3 = C.toolbar, BorderSizePixel = 0, ZIndex = 24}, vMenuLayer)
    corner(vMenu, UDim.new(0, 12))
    new("UIStroke", {Color = Color3.fromRGB(70, 72, 76), Thickness = 1}, vMenu)
    local function vItem(i, text)
        local b = new("TextButton", {Position = UDim2.new(0, 0, 0, 6 + (i - 1) * 35), Size = UDim2.new(1, 0, 0, 35), BackgroundTransparency = 1, Text = text, TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = true, ZIndex = 25}, vMenu)
        new("UIPadding", {PaddingLeft = UDim.new(0, 16)}, b)
        b.MouseButton1Click:Connect(function() vMenuLayer.Visible = false end)
        return b
    end
    local viewerDl = vItem(1, "Baixar imagem")
    local viewerGal = vItem(2, "Salvar na Galeria")
    local viewerCopy = vItem(3, "Copiar link da imagem")
    local viewerSim = vItem(4, "Pesquisar imagem")
    vMenuLayer.MouseButton1Click:Connect(function() vMenuLayer.Visible = false end)
    viewerMore.MouseButton1Click:Connect(function() vMenuLayer.Visible = true end)
    local viewerItem, viewerToken = nil, 0
    local gifReady = false
    local gifState = {playing = true, smooth = true}

    local function toggleGif()
        if not gifReady then return end
        gifState.playing = not gifState.playing
        viewerBadge.Text = gifState.playing and "GIF" or "GIF · pausado"
    end
    local vZoom, vPanX, vPanY = 1, 0, 0
    local function applyVZoom()
        if vZoom <= 1.02 then vZoom, vPanX, vPanY = 1, 0, 0 end
        local sz = viewerClip.AbsoluteSize / uiScale()
        local mx = sz.X * (vZoom - 1) / 2
        local my = sz.Y * (vZoom - 1) / 2
        vPanX = math.clamp(vPanX, -mx, mx)
        vPanY = math.clamp(vPanY, -my, my)
        viewerImg.Size = UDim2.new(vZoom, 0, vZoom, 0)
        viewerImg.Position = UDim2.new(0.5, vPanX, 0.5, vPanY)
    end
    local viewerList, viewerIdx = nil, 0
    viewerBadge.MouseButton1Click:Connect(toggleGif)
    viewerSmooth.MouseButton1Click:Connect(function()
        gifState.smooth = not gifState.smooth
        viewerSmooth.Text = gifState.smooth and "60 FPS" or "ORIGINAL"
        viewerSmooth.TextColor3 = gifState.smooth and Color3.fromRGB(120, 255, 160) or Color3.fromRGB(190, 190, 200)
    end)

    local function playGif(item, tk)
        local url = item.url
        local function cancelled() return tk ~= viewerToken or not viewer.Visible end
        -- FIX: limpa overlay imediatamente antes de qualquer await
        viewerImg2.Visible = false
        viewerImg2.Image = ""
        viewerBadge.Visible = true
        viewerBadge.Text = "GIF · lendo…"
        local fr
        -- 1) decodificador local (nao depende de proxy)
        -- cache por URL: se os quadros ja foram gerados antes, toca direto (sem baixar o GIF de novo)
        local key = "br_" .. U.hash2(url)
        local info = Nav.gif.load(key)
        local body
        if not info then
            body = U.gifBody(url)   -- reaproveita o download ja feito (nao baixa de novo)
            if cancelled() then return end
        end
        if info or body then
            if not info then
                -- maxFrames = 0 = todos os quadros
                info = Nav.gif.bake(key, body, {
                    maxFrames = 0, maxDim = 480, pixelBudget = 48000000, yield = task.wait, cancelled = cancelled,
                    onProg = function(d, t) if not cancelled() then viewerBadge.Text = "GIF · " .. d .. "/" .. t end end,
                }, url:match("([^/]+%.gif)") or key)
            end
            if cancelled() then return end
            if info and #info.paths >= 2 then
                local assets = Nav.gif.assets(info)
                if assets then fr = {assets = assets, delays = info.delays} end
            end
        end
        -- 2) reserva: quadros via proxy
        if not fr then
            local meta = U.gifMeta(url)
            if cancelled() then return end
            if not meta or meta.n < 2 then viewerBadge.Visible = false; return end
            viewerBadge.Text = "GIF · 0/" .. math.min(meta.n, 24)
            fr = U.gifFrames(url, meta, function(done, total)
                if not cancelled() then viewerBadge.Text = "GIF · " .. done .. "/" .. total end
            end, cancelled)
            if cancelled() then return end
        end
        if not fr then viewerBadge.Text = "GIF · sem animação"; return end
        Nav.gif.preload(fr.assets, 1.5)
        if cancelled() then return end
        gifReady = true
        gifState.playing = true
        viewerBadge.Text = "GIF"
        viewerMsg.Visible = false
        viewerSmooth.Text = gifState.smooth and "60 FPS" or "ORIGINAL"
        viewerSmooth.TextColor3 = gifState.smooth and Color3.fromRGB(120, 255, 160) or Color3.fromRGB(190, 190, 200)
        viewerSmooth.Visible = true
        Nav.gif.play(viewerImg, viewerImg2, fr.assets, fr.delays, cancelled, gifState)
    end

    local function openViewer(item, list, idx)
        viewerToken = viewerToken + 1
        local tk = viewerToken
        Nav.gif.stop(viewerImg)
        viewerItem = item
        viewerList, viewerIdx = list, idx or 0
        if list and not idx then
            for i, v in ipairs(list) do
                if v == item then viewerIdx = i break end
            end
        end
        vZoom, vPanX, vPanY = 1, 0, 0
        applyVZoom()
        gifReady = false
        gifState.playing = true
        viewer.Visible = true
        viewerBadge.Visible = false
        viewerSmooth.Visible = false
        viewerImg2.Visible = false
        local host = U.hostOf(item.page or item.url)
        local ttl = (item.title ~= "" and item.title) or host
        viewerTitle.Text = host
        viewerCount.Text = (list and viewerIdx > 0) and (viewerIdx .. "/" .. #list) or ""
        vBotLbl.Text = "<b>" .. U.esc(ttl) .. '</b>\n<font color="#9aa0a6" size="10">' .. U.esc(host) .. "</font>"
        vBotLbl.Size = UDim2.new(1, item.page ~= nil and -100 or -20, 1, -4)
        local thumb = imgCache[item.thumb]
        viewerImg.Image = thumb or ""
        viewerMsg.Visible = thumb == nil
        viewerMsg.Text = "Carregando…"
        viewerVisit.Visible = item.page ~= nil
        vMenuLayer.Visible = false
        setBars(true)
        task.spawn(function()
            local a = U.cacheImage(item.url, 8000000)
            if tk ~= viewerToken or not viewer.Visible then return end
            if a then
                viewerImg.Image = a
                viewerMsg.Visible = false
                if U.maybeGif(item.url) then playGif(item, tk) end
            elseif not thumb then
                viewerMsg.Text = hasAssetFn and "Não foi possível carregar esta imagem." or "Seu executor não tem getcustomasset: não dá para exibir imagens."
            end
        end)
    end
    viewerBack.MouseButton1Click:Connect(function() vMenuLayer.Visible = false; viewer.Visible = false; viewerToken = viewerToken + 1 end)
    local vDrag, vPinch, vPinchStart, vLastTap = nil, false, 1, 0
    local function viewerStep(dir)
        if not viewerList then return end
        local ni = viewerIdx + dir
        local nx = viewerList[ni]
        if nx then openViewer(nx, viewerList, ni) else toast(dir > 0 and "Última imagem" or "Primeira imagem") end
    end
    local function vPress(i)
        return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
    end
    viewerTap.InputBegan:Connect(function(i)
        if vPress(i) and not vPinch then
            local d0 = {input = i, start = i.Position, last = i.Position, t = os.clock(), moved = 0}
            vDrag = d0
            task.delay(0.5, function()
                if vDrag == d0 and d0.moved < 8 and not vPinch and vZoom <= 1.05 then
                    d0.long = true
                    vMenuLayer.Visible = true
                end
            end)
        end
    end)
    viewerTap.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseWheel then
            vZoom = math.clamp(vZoom * (1 + 0.15 * i.Position.Z), 1, 5)
            applyVZoom()
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not viewer.Visible or not vDrag or vPinch then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement or (i.UserInputType == Enum.UserInputType.Touch and i == vDrag.input) then
            local d = (i.Position - vDrag.last) / uiScale()
            vDrag.last = i.Position
            vDrag.moved = vDrag.moved + d.Magnitude
            if vZoom > 1.02 then
                vPanX = vPanX + d.X
                vPanY = vPanY + d.Y
                applyVZoom()
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if not vDrag or not vPress(i) then return end
        if i.UserInputType == Enum.UserInputType.Touch and i ~= vDrag.input then return end
        local d = vDrag
        vDrag = nil
        if d.long or not viewer.Visible or vPinch then return end
        local total = (i.Position - d.start) / uiScale()
        if vZoom <= 1.05 and math.abs(total.X) > 50 and math.abs(total.X) > math.abs(total.Y) * 1.3 then
            viewerStep(total.X < 0 and 1 or -1)
        elseif d.moved < 8 and os.clock() - d.t < 0.3 then
            if os.clock() - vLastTap < 0.3 then
                vLastTap = 0
                if vZoom > 1.05 then vZoom, vPanX, vPanY = 1, 0, 0 else vZoom = 2.5 end
                applyVZoom()
            else
                vLastTap = os.clock()
                setBars(not barsOn)
            end
        end
    end)
    UserInputService.TouchPinch:Connect(function(_, scale, _, state)
        if not viewer.Visible then return end
        if state == Enum.UserInputState.Begin then
            vPinch = true
            vPinchStart = vZoom
            vDrag = nil
        elseif state == Enum.UserInputState.Change then
            vZoom = math.clamp(vPinchStart * scale, 1, 5)
            applyVZoom()
        else
            vPinch = false
            applyVZoom()
        end
    end)
    viewerSim.MouseButton1Click:Connect(function()
        local item = viewerItem
        if not item then return end
        local q = tostring(item.title or "")
        q = q:gsub("%.%w+$", "")
        q = q:gsub("[_%-]+", " ")
        q = q:gsub("%s+", " ")
        q = q:gsub("^%s+", ""):gsub("%s+$", "")
        if q == "" then toast("Imagem sem título para buscar") return end
        viewer.Visible = false
        viewerToken = viewerToken + 1
        navigate(tabs[cur], {q = q, mode = "images"})
    end)
    viewerVisit.MouseButton1Click:Connect(function()
        if viewerItem and viewerItem.page then
            viewer.Visible = false
            navigate(tabs[cur], {url = viewerItem.page})
        end
    end)
    local function itemBaseName(item)
        local base = ((item.title or ""):gsub("[^%w%-_ ]", "_")):sub(1, 40)
        if base:gsub("[_ ]", "") == "" then base = U.hash2(item.url) end
        return base
    end
    local function saveStaticToGallery(item)
        local path = imgPath[item.url] or imgPath[item.thumb]
        if not path then toast("Imagem ainda carregando") return end
        toast(U.sendTo(path, "PHONE/Photos") and "Salvo na Galeria" or "Falha ao copiar")
    end

    -- FIX (precisava baixar duas vezes): UM unico fluxo para GIF.
    -- Baixa 1x (cache em memoria), grava em Downloads E na Galeria com nome fixo por URL
    -- (tocar de novo nao duplica; GIFs diferentes com o mesmo titulo nao colidem) e deixa
    -- os quadros prontos, copiando do cache do navegador em vez de decodificar de novo.
    local savedGif, savingGif = {}, {}
    local function saveGifFlow(item)
        local url = item.url
        if savedGif[url] then toast("GIF já está na Galeria e em Downloads") return end
        if savingGif[url] then toast("Ainda salvando este GIF…") return end
        savingGif[url] = true
        toast("Salvando GIF…")
        task.spawn(function()
            local body = U.gifBody(url)
            if not body then
                savingGif[url] = nil
                saveStaticToGallery(item)   -- nao era GIF de verdade
                return
            end
            local fname = itemBaseName(item) .. "_" .. U.hash2(url):sub(1, 6) .. ".gif"
            pcall(function()
                if not isfolder("PHONE") then makefolder("PHONE") end
                if not isfolder("PHONE/Photos") then makefolder("PHONE/Photos") end
            end)
            U.ensureDl()
            local okP = pcall(writefile, "PHONE/Photos/" .. fname, body)
            local okD = pcall(writefile, DL_DIR .. "/" .. fname, body)
            if not okP then
                savingGif[url] = nil
                toast("Falha ao salvar o GIF")
                return
            end
            -- quadros prontos para a Galeria tocar na hora (mesma chave que a Galeria calcula)
            local gkey = Nav.gif.keyFor(fname, body)
            if not Nav.gif.load(gkey, #body) then
                local srcKey = "br_" .. U.hash2(url)
                local info = Nav.gif.clone(srcKey, gkey, #body, fname)
                if not info then
                    toast("Preparando quadros…")
                    Nav.gif.bake(gkey, body, {maxFrames = 0, maxDim = 480, pixelBudget = 48000000, yield = task.wait}, fname)
                end
            end
            savingGif[url] = nil
            savedGif[url] = fname
            toast(okD and "GIF salvo na Galeria e em Downloads" or "GIF salvo na Galeria")
        end)
    end

    viewerDl.MouseButton1Click:Connect(function()
        local item = viewerItem
        if not item then return end
        if U.maybeGif(item.url) then saveGifFlow(item) return end
        local path = imgPath[item.url] or imgPath[item.thumb]
        if not path then toast("Imagem ainda carregando") return end
        U.ensureDl()
        local ext = path:match("%.(%w+)$") or "jpg"
        local okR, data = pcall(readfile, path)
        local target = DL_DIR .. "/" .. itemBaseName(item) .. "." .. ext
        if okR and type(data) == "string" and pcall(writefile, target, data) then toast("Salvo em Downloads")
        else toast("Falha ao salvar") end
    end)
    viewerGal.MouseButton1Click:Connect(function()
        local item = viewerItem
        if not item then return end
        if not (U.maybeGif(item.url) or item.gif) then saveStaticToGallery(item) return end
        saveGifFlow(item)
    end)
    viewerCopy.MouseButton1Click:Connect(function()
        local clip = setclipboard or toclipboard
        if viewerItem and type(clip) == "function" then pcall(clip, viewerItem.url); toast("Link da imagem copiado")
        else toast("Clipboard indisponível") end
    end)

    local selItems, selCount, selMarks = {}, 0, {}
    local selBar = new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -20, 0, 38), BackgroundColor3 = C.pill, BorderSizePixel = 0, Visible = false, ZIndex = 12}, area)
    corner(selBar, UDim.new(0, 19))
    local selLbl = new("TextLabel", {Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -160, 1, 0), BackgroundTransparency = 1, Text = "", TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 13}, selBar)
    local selSave = new("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -78, 0.5, 0), Size = UDim2.new(0, 66, 0, 28), BackgroundColor3 = C.accent, BorderSizePixel = 0, Text = "SALVAR", TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 10, ZIndex = 13}, selBar)
    corner(selSave, UDim.new(0, 14))
    local selCancel = new("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.new(0, 66, 0, 28), BackgroundColor3 = C.card, BorderSizePixel = 0, Text = "CANCELAR", TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 9, ZIndex = 13}, selBar)
    corner(selCancel, UDim.new(0, 14))
    local function refreshSel()
        selBar.Visible = selCount > 0
        selLbl.Text = selCount .. (selCount == 1 and " selecionada" or " selecionadas")
    end
    local function setSel(it, on)
        if (selItems[it] == true) == on then return end
        selItems[it] = on or nil
        selCount = selCount + (on and 1 or -1)
        local m = selMarks[it]
        if m then m.Visible = on end
        refreshSel()
    end
    local function clearSel()
        for it in pairs(selItems) do
            local m = selMarks[it]
            if m then m.Visible = false end
        end
        selItems, selCount = {}, 0
        refreshSel()
    end
    selCancel.MouseButton1Click:Connect(clearSel)
    selSave.MouseButton1Click:Connect(function()
        if selCount == 0 then return end
        local list = {}
        for it in pairs(selItems) do list[#list + 1] = it end
        clearSel()
        toast("Salvando " .. #list .. "…")
        task.spawn(function()
            local ok = 0
            for _, it in ipairs(list) do
                if it.gif or U.maybeGif(it.url) then
                    saveGifFlow(it)
                    ok = ok + 1
                else
                    U.cacheImage(it.url, 8000000)
                    local path = imgPath[it.url] or imgPath[it.thumb]
                    if path and U.sendTo(path, "PHONE/Photos") then ok = ok + 1 end
                end
            end
            toast(ok .. " de " .. #list .. " salvas na Galeria")
        end)
    end)

    local heartBtn
    local function displayText(e)
        if e.ntp then return "" end
        if e.q then return e.q end
        return U.hostOf(e.url)
    end
    local function fullText(e)
        if e.ntp then return "" end
        return e.q or e.url
    end
    local function updateChrome()
        local e = curEntry()
        tabCount.Text = tostring(#tabs)
        if not address:IsFocused() then address.Text = displayText(e) end
        if e.url then
            Icons.put(siteBtn, lockIcon, 14, e.url:match("^https://") and C.sub or C.red, 8)
        else
            Icons.put(siteBtn, Icons.search, 14, C.sub, 8)
        end
        Icons.put(reloadBtn, e.state == "loading" and Icons.close or Icons.reset, 14, C.text, 8)
        reloadBtn.Visible = not e.ntp
        if e.state == "loading" then
            if not progress.Visible then progStart() end
        elseif progress.Visible and progress.Size.X.Scale < 1 then
            progress.Visible = false
        end
    end

    -- Buscadores disponiveis (escolha no menu de 3 pontinhos). "Auto" = tenta todos em ordem.
    U.ENGINES = {"Auto", "Brave", "DuckDuckGo", "Wikipedia"}

    -- Sem filtro manual de data/relevancia: o proprio buscador ordena por relevancia (como num navegador comum)
    function U.period() return "any" end
    function U.engine()
        local e = phoneSettings.searchEngine
        for _, n in ipairs(U.ENGINES) do if n == e then return e end end
        return "Auto"
    end

    -- Dimensoes (largura, altura) de PNG/JPEG lidas do proprio arquivo: usadas no layout em mosaico
    U.imgDims = {}
    function U.parseDims(b)
        if b:sub(1, 8) == "\137PNG\r\n\26\n" and #b >= 24 then
            local w = b:byte(17) * 16777216 + b:byte(18) * 65536 + b:byte(19) * 256 + b:byte(20)
            local h = b:byte(21) * 16777216 + b:byte(22) * 65536 + b:byte(23) * 256 + b:byte(24)
            return w, h
        end
        if b:byte(1) == 0xFF and b:byte(2) == 0xD8 then
            local i, n = 3, #b
            while i < n - 8 do
                if b:byte(i) ~= 0xFF then
                    i = i + 1
                else
                    local m = b:byte(i + 1)
                    if m == 0xFF then
                        i = i + 1
                    elseif m == 0xD8 or m == 0x01 or (m >= 0xD0 and m <= 0xD7) then
                        i = i + 2
                    else
                        local len = b:byte(i + 2) * 256 + b:byte(i + 3)
                        if m >= 0xC0 and m <= 0xCF and m ~= 0xC4 and m ~= 0xC8 and m ~= 0xCC then
                            return b:byte(i + 7) * 256 + b:byte(i + 8), b:byte(i + 5) * 256 + b:byte(i + 6)
                        end
                        i = i + 2 + len
                    end
                end
            end
        end
        return nil
    end
    function U.dimsFor(url)
        local d = U.imgDims[url]
        if d then return d[1], d[2] end
        local path = imgPath[url]
        if path then
            local okR, b = pcall(readfile, path)
            if okR and type(b) == "string" then
                local w, h = U.parseDims(b)
                if w and h and w > 0 and h > 0 then
                    U.imgDims[url] = {w, h}
                    return w, h
                end
            end
        end
        return nil
    end

    -- Busca de imagens: junta varias fontes (Bing + DuckDuckGo + Openverse), SafeSearch desligado,
    -- e mistura GIFs animados no meio das imagens (sem categoria separada).
    local function fetchImages(entry)
        local items, gifItems, seen = {}, {}, {}
        local enc = HttpService:UrlEncode(entry.q)
        local IMG_MAX, TARGET = 220, 120
        local fSize, fType = entry.fSize or "any", entry.fType or "any"
        local qftParts = {}
        if fSize ~= "any" then qftParts[#qftParts + 1] = "+filterui:imagesize-" .. fSize end
        if fType == "png" then qftParts[#qftParts + 1] = "+filterui:imagetype-png"
        elseif fType == "jpg" then qftParts[#qftParts + 1] = "+filterui:imagetype-jpeg" end
        local function qftFor(first)
            local parts = {}
            if first then parts[1] = first end
            for _, p in ipairs(qftParts) do parts[#parts + 1] = p end
            if #parts == 0 then return "&adlt=off" end
            return "&qft=" .. HttpService:UrlEncode(table.concat(parts)) .. "&adlt=off"
        end
        local function typeOk(u)
            if fType == "any" then return true end
            local p = tostring(u):lower():gsub("[%?#].*$", "")
            local ext = p:match("%.(%w+)$")
            if not ext then return true end
            if fType == "png" then return ext == "png" end
            return ext == "jpg" or ext == "jpeg"
        end
        local function add(list, url, thumb, title, page, isGif)
            thumb = thumb or url
            if type(thumb) ~= "string" or not thumb:match("^https?://") or seen[thumb] then return end
            if not isGif and not typeOk(url or thumb) then return end
            seen[thumb] = true
            title = U.plain(tostring(title or "")):gsub(utf8.char(0xE000), ""):gsub(utf8.char(0xE001), "")
            list[#list + 1] = {url = url or thumb, thumb = thumb, title = title:sub(1, 80), page = page, gif = isGif or nil}
        end

        local function bingPages(extra, pages, perPage, list, isGif, offset, maxN)
            offset = offset or 0
            maxN = maxN or IMG_MAX
            local htmls, pending = {}, pages
            for k = 1, pages do
                task.spawn(function()
                    local first = (k - 1 + offset) * perPage + 1
                    local url
                    if k == 1 and offset == 0 then
                        url = "https://www.bing.com/images/search?q=" .. enc .. "&form=HDRSC2&first=1&count=" .. perPage .. extra
                    else
                        url = "https://www.bing.com/images/async?q=" .. enc .. "&first=" .. first .. "&count=" .. perPage .. "&mmasync=1" .. extra
                    end
                    local h = ""
                    for _ = 1, 2 do
                        local ok, r = pcall(U.httpGet, url)
                        if ok and type(r) == "string" and #r > 500 then h = r break end
                    end
                    htmls[k] = h
                    pending = pending - 1
                end)
            end
            local t0 = os.clock()
            while pending > 0 and os.clock() - t0 < 25 do task.wait(0.05) end
            for k = 1, pages do
                for m in (htmls[k] or ""):gmatch('%sm="(.-)"') do
                    local j = U.decode(m)
                    local okJ, d = pcall(function() return HttpService:JSONDecode(j) end)
                    if okJ and type(d) == "table" then
                        add(list, d.murl, d.turl, d.t or d.desc, d.purl, isGif)
                    else
                        add(list, j:match('"murl":"(.-)"'), j:match('"turl":"(.-)"'), j:match('"t":"(.-)"'), j:match('"purl":"(.-)"'), isGif)
                    end
                    if #list >= maxN then break end
                end
            end
        end

        local function ddgImages()
            pcall(function()
                local page = U.httpGet("https://duckduckgo.com/?q=" .. enc .. "&iax=images&ia=images&kp=-2")
                local vqd = page:match('vqd="([^"]+)"') or page:match("vqd=([%d%-]+)&")
                if not vqd then return end
                for _, s in ipairs({0, 100, 200}) do
                    local okJ, js = pcall(U.httpGet, "https://duckduckgo.com/i.js?l=wt-wt&o=json&q=" .. enc .. "&vqd=" .. vqd .. "&f=,,,,,&p=-1&s=" .. s)
                    if okJ and type(js) == "string" then
                        local okD, d = pcall(function() return HttpService:JSONDecode(js) end)
                        if okD and type(d) == "table" then
                            for _, r in ipairs(d.results or {}) do
                                add(items, r.image, r.thumbnail, r.title, r.url)
                            end
                        end
                    end
                    if #items >= IMG_MAX then break end
                end
            end)
        end

        local function openverse()
            pcall(function()
                local js = U.httpGet("https://api.openverse.org/v1/images/?page_size=100&mature=true&q=" .. enc)
                local d = HttpService:JSONDecode(js)
                for _, r in ipairs(d.results or {}) do
                    add(items, r.url, r.thumbnail or r.url, r.title, r.foreign_landing_url)
                end
            end)
        end

        local gifDone = fType ~= "any"
        if not gifDone then
            task.spawn(function()
                pcall(bingPages, qftFor("+filterui:photo-animatedgif"), 2, 35, gifItems, true)
                gifDone = true
            end)
        end

        local pref = U.engine()
        local order = (pref == "DuckDuckGo") and {"ddg", "bing"} or {"bing", "ddg"}
        for _, src in ipairs(order) do
            if #items >= TARGET then break end
            if src == "bing" then pcall(bingPages, qftFor(), 8, 35, items) else ddgImages() end
        end
        if #items < TARGET then openverse() end

        local t0 = os.clock()
        while not gifDone and os.clock() - t0 < 25 do task.wait(0.05) end

        local out, gi = {}, 1
        for i, it in ipairs(items) do
            out[#out + 1] = it
            if i % 4 == 0 and gifItems[gi] then out[#out + 1] = gifItems[gi]; gi = gi + 1 end
        end
        while gifItems[gi] and #out < IMG_MAX + 30 do out[#out + 1] = gifItems[gi]; gi = gi + 1 end

        local bingOff, gifOff = 8, 2
        local function more()
            local fresh, freshGifs = {}, {}
            local gDone = fType ~= "any"
            if not gDone then
                task.spawn(function()
                    pcall(bingPages, qftFor("+filterui:photo-animatedgif"), 1, 35, freshGifs, true, gifOff, 35)
                    gDone = true
                end)
            end
            pcall(bingPages, qftFor(), 4, 35, fresh, false, bingOff, 140)
            bingOff = bingOff + 4
            gifOff = gifOff + 1
            local tm = os.clock()
            while not gDone and os.clock() - tm < 25 do task.wait(0.05) end
            local res, g2 = {}, 1
            for i, it in ipairs(fresh) do
                res[#res + 1] = it
                if i % 4 == 0 and freshGifs[g2] then res[#res + 1] = freshGifs[g2]; g2 = g2 + 1 end
            end
            while freshGifs[g2] do res[#res + 1] = freshGifs[g2]; g2 = g2 + 1 end
            return res
        end
        return {kind = "images", title = entry.q, items = out, preview = "Imagens: " .. entry.q, more = more}
    end

    -- Varios buscadores com fallback automatico: se um falhar/bloquear/vier vazio, tenta o proximo.
    local function b64dec(s)
        s = s:gsub("%-", "+"):gsub("_", "/")
        local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        local out, bits, n = {}, 0, 0
        for i = 1, #s do
            local v = chars:find(s:sub(i, i), 1, true)
            if v then
                bits = bits * 64 + (v - 1)
                n = n + 6
                if n >= 8 then
                    n = n - 8
                    local b = math.floor(bits / 2 ^ n)
                    bits = bits - b * 2 ^ n
                    out[#out + 1] = string.char(b)
                end
            end
        end
        return table.concat(out)
    end

    local function cleanLink(href)
        local link = U.decode(href)
        local real = link:match("uddg=([^&]+)")
        if real then return U.urlDecode(real) end
        if link:find("bing.com/ck/a", 1, true) then
            local u = link:match("[&?]u=a1([%w%-_]+)")
            if u then
                local d = b64dec(u)
                if d:match("^https?://") then return d end
            end
        end
        if link:sub(1, 2) == "//" then link = "https:" .. link end
        return link
    end

    local function collect(pairsList, snips)
        local items, seen = {}, {}
        local paired = snips and (#snips == #pairsList)
        for i, r in ipairs(pairsList) do
            local link = cleanLink(r[1])
            local name = U.plain(r[2])
            if name ~= "" and link:match("^https?://") and not link:find("duckduckgo.com/y.js", 1, true) and not seen[link] then
                seen[link] = true
                items[#items + 1] = {name = name:sub(1, 90), url = link, snippet = paired and snips[i] and snips[i]:sub(1, 130) or nil, full = paired and snips[i] or nil}
            end
        end
        return items
    end

    local SEARCH_ENGINES = {
        {name = "Brave", run = function(q, pg, off)
            local tf = ({d = "pd", w = "pw", m = "pm", y = "py"})[U.period()]
            local html = U.httpGetH("https://search.brave.com/search?source=web&q=" .. HttpService:UrlEncode(q) .. (tf and ("&tf=" .. tf) or "") .. (pg > 0 and ("&offset=" .. pg) or ""), {Cookie = "safesearch=off; country=br"})
            local raw, snips = {}, {}
            for _, ch in ipairs(U.chunks(html, 'data-type="web"')) do
                local href = ch:match('<a[^>]-href="(https?://[^"]+)"')
                if href and not href:find("search.brave.com", 1, true) then
                    local label = U.pick(ch, {'class="[^"]*title[^"]*"[^>]*>(.-)</div>', '<a[^>]-href="https?://[^"]+"[^>]*>(.-)</a>'})
                    local snip = U.pick(ch, {'class="[^"]*snippet%-description[^"]*"[^>]*>(.-)</div>', 'class="content[^"]*"[^>]*>(.-)</div>', 'class="generic%-snippet[^"]*"[^>]*>(.-)</div>'})
                    raw[#raw + 1] = {href, label}
                    snips[#snips + 1] = snip
                end
            end
            return collect(raw, snips)
        end},
        {name = "DuckDuckGo", run = function(q, pg, off)
            local df = ({d = "d", w = "w", m = "m", y = "y"})[U.period()]
            local html = U.httpGet("https://html.duckduckgo.com/html/?kp=-2&q=" .. HttpService:UrlEncode(q) .. (df and ("&df=" .. df) or "") .. (off > 0 and ("&s=" .. off .. "&dc=" .. (off + 1)) or ""))
            local raw, snips = {}, {}
            for href, label in html:gmatch('class="result__a" href="(.-)"[^>]*>(.-)</a>') do raw[#raw + 1] = {href, label} end
            for s in html:gmatch('class="result__snippet"[^>]*>(.-)</a>') do snips[#snips + 1] = U.plain(s) end
            return collect(raw, snips)
        end},
        {name = "Wikipedia", run = function(q, pg, off)
            local js = U.httpGet("https://pt.wikipedia.org/w/api.php?action=query&list=search&format=json&srlimit=50&sroffset=" .. off .. "&srsearch=" .. HttpService:UrlEncode(q))
            local d = HttpService:JSONDecode(js)
            local items = {}
            for _, r in ipairs(d.query and d.query.search or {}) do
                items[#items + 1] = {name = tostring(r.title), url = "https://pt.wikipedia.org/wiki/" .. tostring(r.title):gsub(" ", "_"), snippet = U.plain(tostring(r.snippet or "")):sub(1, 130), full = U.plain(tostring(r.snippet or ""))}
            end
            return items
        end},
    }

    -- Combina os resultados de todos os buscadores, removendo URLs repetidas.
    -- "Combinado" tambem identifica as paginas seguintes, para continuar consultando todos.
    local function fetchWebSearch(q, pg, off, only)
        pg, off = pg or 0, off or 0
        local lastErr, anyOk = nil, false
        local list = {}
        if only and only ~= "Combinado" then
            for _, e in ipairs(SEARCH_ENGINES) do
                if e.name == only then list[#list + 1] = e end
            end
        else
            for _, e in ipairs(SEARCH_ENGINES) do list[#list + 1] = e end
        end

        local merged, seen = {}, {}
        for _, eng in ipairs(list) do
            local ok, res = pcall(eng.run, q, pg, off)
            if ok then
                anyOk = true
                if type(res) == "table" then
                    for _, item in ipairs(res) do
                        local key = type(item.url) == "string" and item.url:lower() or nil
                        if key and key ~= "" and not seen[key] then
                            seen[key] = true
                            item.source = eng.name
                            merged[#merged + 1] = item
                        end
                    end
                end
            else
                lastErr = res
            end
        end

        if not anyOk and lastErr then error(lastErr, 0) end
        return merged, (#merged > 0 and "Combinado" or nil)
    end

    local function fetchEntry(entry)
        if entry.q and (entry.mode == "images") then return fetchImages(entry) end
        if entry.q then
            local items, used = fetchWebSearch(entry.q, 0, 0)
            local seen, st = {}, {pg = 0, off = #items, dead = false}
            -- tira repetidos e tudo que nao tem a ver com o que foi pesquisado
            local function keep(res)
                local out = {}
                for _, it in ipairs(res) do
                    if not seen[it.url] then
                        seen[it.url] = true
                        out[#out + 1] = it
                    end
                end
                return out
            end
            items = keep(items)
            -- proxima pagina do mesmo buscador; se ela vier so com coisa fora do assunto, ja pula pra seguinte
            local function nextPage()
                if not used or st.dead then return {} end
                for _ = 1, 10 do
                    st.pg = st.pg + 1
                    local okP, res = pcall(fetchWebSearch, entry.q, st.pg, st.off, used)
                    if not okP or type(res) ~= "table" or #res == 0 then
                        st.dead = true
                        return {}
                    end
                    st.off = st.off + #res
                    local unseen = 0
                    for _, it in ipairs(res) do if not seen[it.url] then unseen = unseen + 1 end end
                    if unseen == 0 then
                        st.dead = true   -- o buscador repetiu a mesma pagina: acabou
                        return {}
                    end
                    local fresh = keep(res)
                    if #fresh > 0 then return fresh end
                end
                return {}
            end
            -- primeira tela cheia: junta paginas ate ter pelo menos 20 resultados bons
            local tries = 0
            while used and #items < 20 and tries < 8 do
                tries = tries + 1
                local fresh = nextPage()
                if #fresh == 0 then break end
                for _, it in ipairs(fresh) do items[#items + 1] = it end
            end
            return {kind = "search", title = entry.q, items = items, more = used and nextPage or nil, preview = "Pesquisa: " .. entry.q .. (used and (" · " .. used) or "") }
        end
        local imgExt0 = U.fileExt(entry.url)
        if imgExt0 and IMG_EXT[imgExt0] then
            local nm = U.fileName(entry.url, imgExt0)
            return {kind = "image", title = nm, name = nm, url = entry.url, preview = "Imagem: " .. nm}
        end
        local vExt = U.fileExt(entry.url)
        if vExt and (vExt == "mp4" or vExt == "webm" or vExt == "m4v" or vExt == "mov" or vExt == "gifv") then
            local vurl = entry.url
            if vExt == "gifv" then
                vurl = entry.url:gsub("%.gifv", ".mp4")
                vExt = "mp4"
            end
            local vnm = U.fileName(vurl, vExt)
            return {kind = "video", title = vnm, name = vnm, url = vurl, ext = vExt, preview = "Vídeo: " .. vnm}
        end
        local dlExt = U.fileExt(entry.url)
        if dlExt and DL_EXT[dlExt] then return U.download(entry.url, dlExt) end
        local html = U.httpGet(entry.url)
        local title = html:match("<[tT][iI][tT][lL][eE][^>]*>(.-)</[tT][iI][tT][lL][eE]>")
        title = title and U.plain(title) or ""
        if title == "" then title = U.hostOf(entry.url) end
        local items, seen = {}, {}
        for href, label in html:gmatch('<a%s[^>]-href="(.-)"[^>]*>(.-)</a>') do
            local link = U.resolve(entry.url, href)
            if link and not seen[link] then
                local name = U.plain(label)
                if name ~= "" then
                    seen[link] = true
                    table.insert(items, {name = name:sub(1, 70), url = link})
                    if #items >= 30 then break end
                end
            end
        end
        local imgs, seenImg = {}, {}
        for tag in html:gmatch("<[iI][mM][gG][^>]->") do
            local s = tag:match('[%s"]data%-src="(.-)"') or tag:match('[%s"]data%-original="(.-)"') or tag:match('[%s"]src="(.-)"') or tag:match("[%s']src='(.-)'")
            if not s then
                local ss = tag:match('srcset="(.-)"')
                if ss then s = ss:match("^%s*(%S+)") end
            end
            if s then
                local link = U.resolve(entry.url, s)
                local low = link and link:lower() or ""
                if link and not seenImg[link] and not low:find("pixel", 1, true) and not low:find("spacer", 1, true) and not low:find("1x1", 1, true) and not low:match("%.ico") then
                    seenImg[link] = true
                    local alt = tag:match('alt="(.-)"') or ""
                    table.insert(imgs, {url = link, thumb = link, title = U.plain(alt):sub(1, 80), gif = low:match("%.gif") ~= nil or nil})
                    if #imgs >= 30 then break end
                end
            end
        end
        local rich = U.rich(html)
        local readRich = U.rich(html, 30000)
        return {kind = "page", html = (#html > 1000000 and html:sub(1, 1000000) or html), title = title:sub(1, 80), rich = rich, readRich = readRich, items = items, images = imgs, preview = (rich:gsub("<[^>]->", "")):sub(1, 110)}
    end

    loadEntry = function(tab, entry)
        entry.rid = (entry.rid or 0) + 1
        local id = entry.rid
        entry.state = "loading"
        entry.view, entry.err = nil, nil
        if tabs[cur] == tab and tab.hist[tab.pos] == entry then render() end
        task.spawn(function()
            local ok, res = pcall(fetchEntry, entry)
            if entry.rid ~= id then return end
            if ok then
                entry.view, entry.state, entry.title = res, "done", res.title
                if res.kind == "image" and tabs[cur] == tab and tab.hist[tab.pos] == entry then
                    task.defer(function() openViewer({url = res.url, thumb = res.url, title = res.title}) end)
                end
                if entry.url and res.kind == "page" then
                    local h = history()
                    if not (h[1] and h[1].url == entry.url) then
                        table.insert(h, 1, {title = res.title, url = entry.url})
                        while #h > 80 do table.remove(h) end
                        saveSettings()
                    end
                end
            else
                entry.state, entry.err = "error", tostring(res)
            end
            if tabs[cur] == tab and tab.hist[tab.pos] == entry then
                render()
                progDone()
            end
        end)
    end

    navigate = function(tab, entry)
        for i = #tab.hist, tab.pos + 1, -1 do table.remove(tab.hist, i) end
        table.insert(tab.hist, entry)
        tab.pos = #tab.hist
        loadEntry(tab, entry)
    end

    reload = function()
        local tab = tabs[cur]
        local e = curEntry()
        if e.ntp then render() else loadEntry(tab, e) end
    end

    local function stopLoad()
        local e = curEntry()
        e.rid = (e.rid or 0) + 1
        if e.state == "loading" then e.state = "stopped" end
        progress.Visible = false
        render()
    end

    showEntry = function(tab)
        local e = tab.hist[tab.pos]
        if e.ntp or e.state == "done" or e.state == "loading" then render() else loadEntry(tab, e) end
    end

    local function runInput(text)
        text = text:gsub("^%s+", ""):gsub("%s+$", "")
        if text == "" then return end
        if U.looksLikeUrl(text) then
            local url = text
            if not url:match("^https?://") then url = "https://" .. url end
            navigate(tabs[cur], {url = url})
        else
            navigate(tabs[cur], {q = text})
        end
    end

    local function buildNtp()
        for _, c in ipairs(ntpView:GetChildren()) do if c.Name == "Dyn" then c:Destroy() end end
        new("TextLabel", {
            Name = "Dyn", Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1, RichText = true,
            Text = '<font color="#4285F4">i</font><font color="#EA4335">D</font><font color="#FBBC05">r</font><font color="#4285F4">o</font><font color="#34A853">i</font><font color="#EA4335">d</font>',
            Font = Enum.Font.GothamBold, TextSize = 46, TextColor3 = C.text, ZIndex = 5,
        }, ntpView)
        local box = new("TextButton", {Name = "Dyn", Position = UDim2.new(0, 14, 0, 92), Size = UDim2.new(1, -28, 0, 40), BackgroundColor3 = C.pill, Text = "", AutoButtonColor = true, ZIndex = 5}, ntpView)
        corner(box, UDim.new(0, 20))
        local ic = new("Frame", {Position = UDim2.new(0, 12, 0.5, -9), Size = UDim2.new(0, 18, 0, 18), BackgroundTransparency = 1, ZIndex = 6}, box)
        Icons.put(ic, Icons.search, 16, C.sub, 7)
        new("TextLabel", {Position = UDim2.new(0, 38, 0, 0), Size = UDim2.new(1, -46, 1, 0), BackgroundTransparency = 1, Text = "Pesquisar ou digitar URL", TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6}, box)
        box.MouseButton1Click:Connect(function() address:CaptureFocus() end)

        local grid = new("Frame", {Name = "Dyn", Position = UDim2.new(0, 8, 0, 152), Size = UDim2.new(0, 264, 0, 150), BackgroundTransparency = 1, ZIndex = 5}, ntpView)
        new("UIGridLayout", {CellSize = UDim2.new(0, 62, 0, 68), CellPadding = UDim2.new(0, 4, 0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, grid)
        for i, b in ipairs(bookmarks()) do
            if i > 8 then break end
            local cell = new("TextButton", {Text = "", BackgroundTransparency = 1, AutoButtonColor = false, LayoutOrder = i, ZIndex = 5}, grid)
            local fav = favicon(cell, b.url, 40, 6)
            fav.Position = UDim2.new(0.5, -20, 0, 2)
            new("TextLabel", {Position = UDim2.new(0, 0, 0, 46), Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = b.name, TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6}, cell)
            cell.MouseButton1Click:Connect(function() navigate(tabs[cur], {url = b.url}) end)
        end
    end

    local richLbls = {}
    local function markRich(rich, q, cur)
        local eq = U.esc(q):lower()
        local out, n, pos, plainLen = {}, 0, {}, 0
        local i, total = 1, #rich
        while i <= total do
            local ts, te = rich:find("<[^>]*>", i)
            if ts == i then
                out[#out + 1] = rich:sub(ts, te)
                i = te + 1
            else
                local stop = ts and (ts - 1) or total
                local text = rich:sub(i, stop)
                i = stop + 1
                local low = text:lower()
                local p = 1
                while true do
                    local a, b = low:find(eq, p, true)
                    if not a then
                        out[#out + 1] = text:sub(p)
                        break
                    end
                    out[#out + 1] = text:sub(p, a - 1)
                    n = n + 1
                    pos[n] = plainLen + a
                    out[#out + 1] = '<mark color="' .. (n == cur and "#ff9800" or "#fdd835") .. '" transparency="0.35">' .. text:sub(a, b) .. "</mark>"
                    p = b + 1
                end
                plainLen = plainLen + #text
            end
        end
        return table.concat(out), n, pos, plainLen
    end
    local findBar = new("Frame", {Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.toolbar, BorderSizePixel = 0, Visible = false, ZIndex = 12}, area)
    local findBox = new("TextBox", {Position = UDim2.new(0, 8, 0, 4), Size = UDim2.new(1, -150, 0, 26), BackgroundColor3 = C.pill, BorderSizePixel = 0, Text = "", PlaceholderText = "Buscar nesta página", PlaceholderColor3 = C.sub, TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 11, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13}, findBar)
    corner(findBox, UDim.new(0, 13))
    new("UIPadding", {PaddingLeft = UDim.new(0, 10)}, findBox)
    local findCnt = new("TextLabel", {Position = UDim2.new(1, -140, 0, 4), Size = UDim2.new(0, 44, 0, 26), BackgroundTransparency = 1, Text = "0/0", TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 10, ZIndex = 13}, findBar)
    local function findBtn(x, w, txt)
        local b = new("TextButton", {Position = UDim2.new(1, x, 0, 4), Size = UDim2.new(0, w, 0, 26), BackgroundColor3 = C.card, BorderSizePixel = 0, Text = txt, TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 13}, findBar)
        corner(b, UDim.new(0, 13))
        return b
    end
    local findPrev, findNext, findX = findBtn(-94, 28, "<"), findBtn(-64, 28, ">"), findBtn(-34, 28, "X")
    local findQ, findIdx, findTotal = "", 0, 0
    local function paintFind(scroll)
        if findQ == "" then
            for _, r in ipairs(richLbls) do
                if r.lbl.Parent then r.lbl.Text = r.base end
            end
            findIdx, findTotal = 0, 0
            findCnt.Text = "0/0"
            return
        end
        local total = 0
        for _, r in ipairs(richLbls) do
            local _, n = markRich(r.base, findQ, 0)
            total = total + n
        end
        findTotal = total
        if total == 0 then findIdx = 0
        elseif findIdx < 1 or findIdx > total then findIdx = 1 end
        local prefix, target = 0, nil
        for _, r in ipairs(richLbls) do
            local cur = findIdx - prefix
            local txt, n, pos, plen = markRich(r.base, findQ, cur)
            if r.lbl.Parent then r.lbl.Text = txt end
            if cur >= 1 and cur <= n then target = {lbl = r.lbl, pos = pos[cur], plen = plen} end
            prefix = prefix + n
        end
        findCnt.Text = findIdx .. "/" .. total
        if scroll and target then
            task.defer(function()
                if not target.lbl.Parent then return end
                local y = (target.lbl.AbsolutePosition.Y - pageView.AbsolutePosition.Y) / uiScale() + pageView.CanvasPosition.Y + (target.pos / math.max(1, target.plen)) * (target.lbl.AbsoluteSize.Y / uiScale())
                pageView.CanvasPosition = Vector2.new(0, math.max(0, y - 50))
            end)
        end
    end
    local function openFind()
        if #richLbls == 0 then toast("Busca disponível em páginas de texto") return end
        if U.closeSite then U.closeSite() end
        findBar.Visible = true
        pageView.Position = UDim2.new(0, 0, 0, 34)
        pageView.Size = UDim2.new(1, 0, 1, -34)
        findBox:CaptureFocus()
    end
    local function closeFind()
        findBar.Visible = false
        pageView.Position = UDim2.new(0, 0, 0, 0)
        pageView.Size = UDim2.new(1, 0, 1, 0)
        findQ = ""
        findBox.Text = ""
        paintFind(false)
    end
    findBox:GetPropertyChangedSignal("Text"):Connect(function()
        findQ = findBox.Text
        findIdx = 0
        paintFind(true)
    end)
    findNext.MouseButton1Click:Connect(function()
        if findTotal == 0 then return end
        findIdx = findIdx + 1
        if findIdx > findTotal then findIdx = 1 end
        paintFind(true)
    end)
    findPrev.MouseButton1Click:Connect(function()
        if findTotal == 0 then return end
        findIdx = findIdx - 1
        if findIdx < 1 then findIdx = findTotal end
        paintFind(true)
    end)
    findBox.FocusLost:Connect(function(enter)
        if enter and findTotal > 0 then
            findIdx = findIdx + 1
            if findIdx > findTotal then findIdx = 1 end
            paintFind(true)
        end
    end)
    findX.MouseButton1Click:Connect(closeFind)

    ---------------------------------------------------------------- BUSCAR NESTE SITE
    -- Pesquisa DENTRO do site aberto (tipo a lupa/search do proprio site): usa o operador "site:dominio termo"
    -- nos buscadores do navegador (Brave / DuckDuckGo). Fica num do-block para nao gastar variaveis locais.
    do
        local siteBar = new("Frame", {Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.toolbar, BorderSizePixel = 0, Visible = false, ZIndex = 12}, area)
        local siteBox = new("TextBox", {Position = UDim2.new(0, 8, 0, 4), Size = UDim2.new(1, -84, 0, 26), BackgroundColor3 = C.pill, BorderSizePixel = 0, Text = "", PlaceholderText = "Buscar neste site", PlaceholderColor3 = C.sub, TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 11, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13}, siteBar)
        corner(siteBox, UDim.new(0, 13))
        new("UIPadding", {PaddingLeft = UDim.new(0, 10)}, siteBox)
        local function sBtn(x, w, txt, bg)
            local b = new("TextButton", {Position = UDim2.new(1, x, 0, 4), Size = UDim2.new(0, w, 0, 26), BackgroundColor3 = bg, BorderSizePixel = 0, Text = txt, TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 13}, siteBar)
            corner(b, UDim.new(0, 13))
            return b
        end
        local siteGo, siteX = sBtn(-72, 36, "Ir", C.accent or C.card), sBtn(-34, 28, "X", C.card)
        local siteHost

        local function currentHost()
            local e = curEntry()
            local u = e and e.url
            if type(u) ~= "string" then return nil end
            local h = u:match("^https?://([^/%?#]+)")
            if not h then return nil end
            h = h:gsub("^.*@", ""):gsub(":%d+$", ""):gsub("^www%.", "")
            return h
        end

        function U.closeSite()
            if not siteBar.Visible then return end
            siteBar.Visible = false
            siteBox.Text = ""
            if not findBar.Visible then
                pageView.Position = UDim2.new(0, 0, 0, 0)
                pageView.Size = UDim2.new(1, 0, 1, 0)
            end
        end

        function U.openSite()
            local h = currentHost()
            if not h then toast("Abra um site primeiro") return end
            siteHost = h
            if findBar.Visible then closeFind() end
            siteBox.PlaceholderText = "Buscar em " .. h
            siteBar.Visible = true
            pageView.Position = UDim2.new(0, 0, 0, 34)
            pageView.Size = UDim2.new(1, 0, 1, -34)
            siteBox:CaptureFocus()
        end

        local function submitSite()
            local text = siteBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
            if text == "" or not siteHost then return end
            local h = siteHost
            U.closeSite()
            navigate(tabs[cur], {q = "site:" .. h .. " " .. text})
        end
        siteGo.MouseButton1Click:Connect(submitSite)
        siteX.MouseButton1Click:Connect(function() U.closeSite() end)
        siteBox.FocusLost:Connect(function(enter) if enter then submitSite() end end)
    end


    ---------------------------------------------------------------- MODO LAYOUT
    -- Renderizador estático aprimorado: HTML + CSS + recursos de imagem em objetos Roblox.
    -- Não executa JavaScript; embeds externos são apresentados como cartões clicáveis.
;(function()
        local function tset(s) local t = {} for w in s:gmatch("%S+") do t[w] = true end return t end
        local VOID = tset("area base br col embed hr img input link meta param source track wbr")
        local SKIP = tset("head script style noscript svg template canvas object datalist map dialog audio video source")
        local BLOCKT = tset("div p h1 h2 h3 h4 h5 h6 ul ol li table tr td th thead tbody tfoot section article header footer nav main aside form blockquote pre hr figure figcaption picture dl dt dd center fieldset address details summary body html caption")
        local CLOSES = {
            li = tset("li"), dt = tset("dt dd"), dd = tset("dt dd"), option = tset("option"),
            tr = tset("tr td th"), td = tset("td th"), th = tset("td th"),
            thead = tset("thead tbody tfoot tr td th"), tbody = tset("thead tbody tfoot tr td th"), tfoot = tset("thead tbody tfoot tr td th"),
        }
        local NAMED = {
            white = {255, 255, 255}, black = {0, 0, 0}, red = {255, 0, 0}, blue = {0, 0, 255}, green = {0, 128, 0},
            gray = {128, 128, 128}, grey = {128, 128, 128}, silver = {192, 192, 192}, yellow = {255, 255, 0},
            orange = {255, 165, 0}, purple = {128, 0, 128}, pink = {255, 192, 203}, brown = {165, 42, 42},
            navy = {0, 0, 128}, teal = {0, 128, 128}, lime = {0, 255, 0}, maroon = {128, 0, 0}, aqua = {0, 255, 255},
            cyan = {0, 255, 255}, fuchsia = {255, 0, 255}, magenta = {255, 0, 255}, lightgray = {211, 211, 211},
            lightgrey = {211, 211, 211}, darkgray = {169, 169, 169}, darkgrey = {169, 169, 169}, whitesmoke = {245, 245, 245},
            gainsboro = {220, 220, 220}, beige = {245, 245, 220}, ivory = {255, 255, 240}, gold = {255, 215, 0},
            crimson = {220, 20, 60}, darkblue = {0, 0, 139}, darkred = {139, 0, 0}, darkgreen = {0, 100, 0},
            lightblue = {173, 216, 230}, skyblue = {135, 206, 235}, royalblue = {65, 105, 225}, dodgerblue = {30, 144, 255},
            tomato = {255, 99, 71}, coral = {255, 127, 80}, indigo = {75, 0, 130}, violet = {238, 130, 238},
            slategray = {112, 128, 144}, dimgray = {105, 105, 105}, lightyellow = {255, 255, 224}, aliceblue = {240, 248, 255},
            lavender = {230, 230, 250}, khaki = {240, 230, 140}, salmon = {250, 128, 114}, ghostwhite = {248, 248, 255},
        }
        local BASE = {color = Color3.fromRGB(0, 0, 0), size = 12, bold = false, italic = false, under = false, strike = false, align = "left", mono = false}

        local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

        local MEDIATAG = {img = true, picture = true, video = true}
        local function hasImgTag(node, depth)
            if depth > 5 then return false end
            for _, k in ipairs(node.kids or {}) do
                if k.tag then
                    if MEDIATAG[k.tag] then return true end
                    local sty = k.attrs and k.attrs.style
                    if sty and sty:find("url%(") then return true end
                    if hasImgTag(k, depth + 1) then return true end
                end
            end
            return false
        end

        local VARS, KF = {}, {}
        local VW = 360
        local AVAILW = 250

        local function subVars(v)
            for _ = 1, 4 do
                if not v:find("var%(") then break end
                v = (v:gsub("var%(%s*(%-%-[%w_%-]+)%s*,?%s*([^%)]*)%)", function(n, fb)
                    return VARS[n] or (fb ~= "" and fb) or ""
                end))
            end
            return v
        end

        local function parseColor(v)
            v = trim(v:lower())
            if v:find("var%(") then return nil end
            local hx = v:match("^#(%x+)$")
            if hx then
                local n = #hx
                local r, g, b, a
                if n == 3 or n == 4 then
                    r = tonumber(hx:sub(1, 1) .. hx:sub(1, 1), 16)
                    g = tonumber(hx:sub(2, 2) .. hx:sub(2, 2), 16)
                    b = tonumber(hx:sub(3, 3) .. hx:sub(3, 3), 16)
                    if n == 4 then a = tonumber(hx:sub(4, 4) .. hx:sub(4, 4), 16) / 255 end
                elseif n == 6 or n == 8 then
                    r = tonumber(hx:sub(1, 2), 16)
                    g = tonumber(hx:sub(3, 4), 16)
                    b = tonumber(hx:sub(5, 6), 16)
                    if n == 8 then a = tonumber(hx:sub(7, 8), 16) / 255 end
                else
                    return nil
                end
                if a and a < 0.05 then return nil end
                if a and a >= 0.98 then a = nil end
                return Color3.fromRGB(r, g, b), a
            end
            local ra, rb, rc, rd = v:match("^rgba?%(%s*([%d%.]+)%s*[,%s]%s*([%d%.]+)%s*[,%s]%s*([%d%.]+)%s*[,/%s]*%s*([%d%.]*)")
            if ra then
                local al = tonumber(rd)
                if al and al < 0.05 then return nil end
                if al and al >= 0.98 then al = nil end
                return Color3.fromRGB(math.clamp(tonumber(ra), 0, 255), math.clamp(tonumber(rb), 0, 255), math.clamp(tonumber(rc), 0, 255)), al
            end
            local hh, hs, hl, hd = v:match("^hsla?%(%s*([%d%.%-]+)[%a]*[%s,]+([%d%.]+)%%[%s,]+([%d%.]+)%%[%s,/]*([%d%.]*)")
            if hh then
                local s2, l2 = tonumber(hs) / 100, tonumber(hl) / 100
                local val = l2 + s2 * math.min(l2, 1 - l2)
                local sv = (val == 0) and 0 or 2 * (1 - l2 / val)
                local al = tonumber(hd)
                if al and al < 0.05 then return nil end
                if al and al >= 0.98 then al = nil end
                return Color3.fromHSV((tonumber(hh) % 360) / 360, math.clamp(sv, 0, 1), math.clamp(val, 0, 1)), al
            end
            local nm = NAMED[v]
            if nm then return Color3.fromRGB(nm[1], nm[2], nm[3]) end
            return nil
        end

        local function parseBg(v)
            v = v:lower()
            if v:find("var%(") or v:find("gradient") then return nil end
            local tok = v:match("#%x+") or v:match("rgba?%b()") or v:match("hsla?%b()")
            if tok then return parseColor(tok) end
            for w in v:gmatch("%a+") do
                if NAMED[w] then return parseColor(w) end
            end
            return nil
        end

        local function parseLen(v, fs)
            v = trim(v:lower())
            if v == "0" then return 0, nil end
            if v:find("^calc%(") then
                local inner = v:match("^calc%((.*)%)$")
                if not inner then return nil end
                local off, sc, sign = 0, 0, 1
                for tok in inner:gmatch("%S+") do
                    if tok == "+" then sign = 1
                    elseif tok == "-" then sign = -1
                    elseif tok == "*" or tok == "/" then return nil
                    else
                        local o2, s2 = parseLen(tok, fs)
                        if not o2 and not s2 then return nil end
                        off = off + sign * (o2 or 0)
                        sc = sc + sign * (s2 or 0)
                        sign = 1
                    end
                end
                return off, (sc ~= 0) and sc or nil
            end
            local fn, args = v:match("^(%a+)%((.*)%)$")
            if fn == "clamp" or fn == "min" or fn == "max" then
                local vals = {}
                for a in args:gmatch("[^,]+") do
                    local o2 = parseLen(a, fs)
                    if o2 then vals[#vals + 1] = o2 end
                end
                if #vals == 0 then return nil end
                if fn == "clamp" and #vals == 3 then return math.max(vals[1], math.min(vals[2], vals[3])) end
                if fn == "min" then return math.min(table.unpack(vals)) end
                if fn == "max" then return math.max(table.unpack(vals)) end
                return vals[2] or vals[1]
            end
            local n, u = v:match("^(%-?[%d%.]+)(%a*%%?)$")
            n = tonumber(n)
            if not n then return nil end
            if u == "px" or u == "" then return n * 0.75
            elseif u == "pt" then return n
            elseif u == "em" then return n * fs
            elseif u == "rem" then return n * 12
            elseif u == "vw" then return n * VW * 0.75 / 100
            elseif u == "vh" then return n * 640 * 0.75 / 100
            elseif u == "%" then return nil, n / 100 end
            return nil
        end

        local function parseEdges(val, fs, allowAuto)
            if val:find("calc%(") then return end
            local p = {}
            for tok in val:gmatch("%S+") do
                if tok == "auto" then
                    p[#p + 1] = allowAuto and "auto" or 0
                else
                    p[#p + 1] = (parseLen(tok, fs)) or 0
                end
                if #p == 4 then break end
            end
            local n = #p
            if n == 1 then return p[1], p[1], p[1], p[1]
            elseif n == 2 then return p[1], p[2], p[1], p[2]
            elseif n == 3 then return p[1], p[2], p[3], p[2]
            elseif n == 4 then return p[1], p[2], p[3], p[4] end
        end

        local function fontFor(v)
            local first = v:lower():match("^%s*['\"]?([^,'\"]+)") or ""
            if first:find("mono") or first:find("courier") or first:find("consolas") or first:find("menlo") or first:find("fira code") then return Enum.Font.Code end
            if first:find("georgia") or first:find("times") or first:find("garamond") or first:find("merriweather") or first:find("playfair") or first:find("lora") or first:find("cambria") then return Enum.Font.Merriweather end
            if first:find("oswald") or first:find("bebas") or first:find("anton") or first:find("impact") then return Enum.Font.Oswald end
            if first:find("nunito") or first:find("quicksand") then return Enum.Font.Nunito end
            if first:find("roboto") then return Enum.Font.Roboto end
            if first:find("arial") or first:find("helvetica") then return Enum.Font.Arial end
            if first:find("comic") or first:find("pacifico") or first:find("cursive") then return Enum.Font.Cartoon end
            if v:lower():find("monospace") and not first:find("sans") then return Enum.Font.Code end
            return nil
        end

        local function parseGradient(v)
            local kind, inner = v:match("([%a%-]*gradient)(%b())")
            if not kind then return nil end
            inner = inner:sub(2, -2)
            local rot = 90
            local parts, depth, cur = {}, 0, ""
            for ch in inner:gmatch(".") do
                if ch == "(" then depth = depth + 1 elseif ch == ")" then depth = depth - 1 end
                if ch == "," and depth == 0 then
                    parts[#parts + 1] = cur
                    cur = ""
                else
                    cur = cur .. ch
                end
            end
            parts[#parts + 1] = cur
            local cols = {}
            for i, p in ipairs(parts) do
                p = trim(p)
                local deg = p:match("^(%-?[%d%.]+)deg$")
                if i == 1 and (deg or p:find("^to ")) then
                    if deg then
                        rot = tonumber(deg) - 90
                    else
                        local x = p:find("right") and 1 or (p:find("left") and -1 or 0)
                        local y = p:find("bottom") and 1 or (p:find("top") and -1 or 0)
                        rot = math.deg(atan2(y, x))
                    end
                else
                    local c = parseColor((p:gsub("%s+%-?[%d%.]+%%$", ""):gsub("%s+%-?[%d%.]+px$", "")))
                    if c then cols[#cols + 1] = c end
                end
            end
            if #cols == 0 then return nil end
            if #cols == 1 then cols[2] = cols[1] end
            return {rot = rot, colors = cols}
        end

        local function applyGrad(inst, gr)
            local n = #gr.colors
            local kps = {}
            for i, c in ipairs(gr.colors) do
                kps[i] = ColorSequenceKeypoint.new((i - 1) / (n - 1), c)
            end
            local g = Instance.new("UIGradient")
            g.Color = ColorSequence.new(kps)
            g.Rotation = gr.rot
            g.Parent = inst
            inst.BackgroundColor3 = WHITE
            inst.BackgroundTransparency = 0
        end

        local function parseSize(v, ps)
            local vl0 = v:lower()
            if vl0:find("^%s*calc%(") or vl0:find("^%s*clamp%(") or vl0:find("^%s*min%(") or vl0:find("^%s*max%(") then
                local o0 = parseLen(v, ps)
                return o0
            end
            v = v:lower():gsub("%s", "")
            local n, u = v:match("^([%d%.]+)(%a*%%?)$")
            n = tonumber(n)
            if n then
                if u == "px" or u == "" then return n * 0.75
                elseif u == "pt" then return n
                elseif u == "em" then return ps * n
                elseif u == "rem" then return 12 * n
                elseif u == "%" then return ps * n / 100 end
            end
            local kw = {["x-small"] = 9, small = 10, medium = 12, large = 14, ["x-large"] = 17, ["xx-large"] = 21, smaller = ps * 0.85, larger = ps * 1.2}
            return kw[v]
        end

        local function parseDecls(body, isRoot)
            local t = {}
            for prop, val in body:gmatch("([%w%-]+)%s*:%s*([^;]+)") do
                val = trim((val:gsub("!important", "")))
                prop = prop:lower()
                if prop:sub(1, 2) == "--" then
                    if isRoot then VARS[prop] = val end
                else
                    t[#t + 1] = {prop, val}
                end
            end
            return t
        end

        -- grid-template-columns com tamanhos diferentes ("250px 1fr", "2fr 1fr", "20% 1fr 1fr"...):
        -- devolve a fracao (0..1) de cada coluna; nil quando for uniforme/auto-fit (usa o caminho antigo)
        local function trackFractions(lv, cols)
            if lv:find("subgrid") or lv:find("%[") then return nil end
            local autoCount = math.max(1, math.min(6, math.floor(AVAILW / 150)))
            lv = lv:gsub("repeat%(%s*auto%-fit%s*,%s*minmax%b()%s*%)", "repeat(" .. autoCount .. ", 1fr)")
            lv = lv:gsub("repeat%(%s*auto%-fill%s*,%s*minmax%b()%s*%)", "repeat(" .. autoCount .. ", 1fr)")
            local ex = lv:gsub("repeat%(%s*(%d+)%s*,%s*([^%(%)]-)%s*%)", function(n, body)
                local t = {}
                for _ = 1, math.min(tonumber(n) or 1, 12) do t[#t + 1] = body end
                return table.concat(t, " ")
            end)
            if ex:find("repeat%(") then return nil end
            ex = ex:gsub("minmax%b()", "1fr"):gsub("fit%-content%b()", "1fr")
            local toks = {}
            for tk in ex:gmatch("%S+") do toks[#toks + 1] = tk end
            if #toks < 2 or #toks ~= cols then return nil end
            local fixed, frSum, kinds = 0, 0, {}
            for i, tk in ipairs(toks) do
                local fr = tonumber(tk:match("^([%d%.]+)fr$"))
                local px = tonumber(tk:match("^([%d%.]+)px$"))
                local pc = tonumber(tk:match("^([%d%.]+)%%$"))
                local em = tonumber(tk:match("^([%d%.]+)r?em$"))
                if fr then
                    kinds[i] = {"fr", fr}; frSum = frSum + fr
                elseif px then
                    kinds[i] = {"fx", math.min(0.6, px / math.max(VW, 1))}; fixed = fixed + kinds[i][2]
                elseif em then
                    kinds[i] = {"fx", math.min(0.6, em * 16 / math.max(VW, 1))}; fixed = fixed + kinds[i][2]
                elseif pc then
                    kinds[i] = {"fx", pc / 100}; fixed = fixed + pc / 100
                else
                    kinds[i] = {"fr", 1}; frSum = frSum + 1
                end
            end
            local out = {}
            if frSum == 0 then
                for i, k in ipairs(kinds) do out[i] = k[2] / math.max(fixed, 0.0001) end
            else
                local fx = math.min(fixed, 0.7)
                local sc = fixed > 0 and (fx / fixed) or 1
                for i, k in ipairs(kinds) do
                    out[i] = (k[1] == "fr") and ((1 - fx) * k[2] / frSum) or (k[2] * sc)
                end
            end
            local uniform = true
            for i = 2, #out do if math.abs(out[i] - out[1]) > 0.002 then uniform = false end end
            if uniform then return nil end
            return out
        end

        local SIZEKEY = {width = "w", height = "h", ["min-height"] = "minh", ["max-width"] = "maxw", ["min-width"] = "minw", ["max-height"] = "maxh"}
        local BORDERKEY = {border = "b", ["border-top"] = "bt", ["border-bottom"] = "bb", ["border-left"] = "bl", ["border-right"] = "br"}

        local function applyDecl(st, prop, val, ps)
            if val:find("var%(") then val = subVars(val) end
            if val == "" then return end
            local lv = val:lower()
            if lv == "inherit" or lv == "initial" or lv == "unset" or lv == "revert" then return end
            local fs = st.size
            if prop == "color" then
                local c = parseColor(val)
                if c then st.color = U.dk(c, "fg") end
            elseif prop == "background-color" then
                st.bg, st.bga = parseBg(val)
                if st.bg then st.bg = U.dk(st.bg, "bg") end
            elseif prop == "background" or prop == "background-image" then
                if prop == "background" then st.bg = nil; st.bga = nil; st.grad = nil; st.bgimg = nil end
                local gr = parseGradient(lv)
                if gr then
                    if U.dark.on then for gi, gc in ipairs(gr.colors) do gr.colors[gi] = U.dk(gc, "bg") end end
                    st.grad = gr
                    if not st.bg then st.bg = gr.colors[1] end
                elseif lv == "none" then
                    st.grad = nil
                    st.bgimg = nil
                end
                local u = val:match("url%(%s*['\"]?([^'\")]-)['\"]?%s*%)")
                if u and u:sub(1, 5) ~= "data:" then st.bgimg = u end
                if prop == "background" then
                    local rest = lv:gsub("url%b()", ""):gsub("[%a%-]*gradient%b()", "")
                    local c, a = parseBg(rest)
                    if c then st.bg = U.dk(c, "bg"); st.bga = a end
                end
            elseif prop == "font-size" then
                local s = parseSize(val, ps.size)
                if s then st.size = math.clamp(s, 7, 54) end
            elseif prop == "font-weight" then
                local n = tonumber(lv)
                if lv == "bold" or lv == "bolder" or (n and n >= 600) then st.bold = true
                elseif lv == "normal" or (n and n < 600) then st.bold = false end
            elseif prop == "font-style" then
                st.italic = lv:find("italic") ~= nil or lv:find("oblique") ~= nil
            elseif prop == "text-decoration" or prop == "text-decoration-line" then
                if lv:find("none") then st.under = false; st.strike = false
                else
                    if lv:find("underline") then st.under = true end
                    if lv:find("line%-through") then st.strike = true end
                end
            elseif prop == "text-align" then
                if lv == "center" or lv == "right" then st.align = lv else st.align = "left" end
            elseif prop == "display" then
                st.display = lv:match("^%S+") or lv
            elseif prop == "visibility" then
                if lv == "hidden" then st.display = "none" end
            elseif prop == "flex-direction" then
                st.dir = lv:find("column") and "column" or "row"
                st.rev = lv:find("reverse") ~= nil
            elseif prop == "order" then
                st.order = tonumber(lv)
            elseif prop == "flex-basis" then
                local o, sc = parseLen(lv, fs)
                if (o and o > 0) or (sc and sc > 0) then st.fbasis = {o, sc} end
            elseif prop == "grid-column" or prop == "grid-column-end" then
                local sp = tonumber(lv:match("span%s+(%d+)"))
                if not sp then
                    local a, b = lv:match("^(%-?%d+)%s*/%s*(%-?%d+)")
                    a, b = tonumber(a), tonumber(b)
                    if a and b then
                        if b < 0 then sp = -1 elseif b > a then sp = b - a end
                    end
                end
                if sp then st.span = sp end
            elseif prop == "flex-flow" then
                st.dir = lv:find("column") and "column" or "row"
                st.rev = lv:find("reverse") ~= nil
                if lv:find("wrap") and not lv:find("nowrap") then st.wrap = true end
            elseif prop == "font-family" then
                st.font = fontFor(val)
                st.mono = st.font == Enum.Font.Code
            elseif prop == "border-radius" then
                local a = lv:match("^%S+")
                if a:find("%%") then
                    st.rs = math.min(0.5, (tonumber(a:match("[%d%.]+")) or 0) / 100)
                    st.radius = 0
                else
                    local o = parseLen(a, fs)
                    if o then st.radius = math.min(o, 500); st.rs = nil end
                end
            elseif prop == "padding" then
                local ptk = {}
                for tk in lv:gmatch("%S+") do ptk[#ptk + 1] = tk end
                local tpc = (ptk[1] or ""):match("^([%d%.]+)%%$")
                local bpc = (ptk[3] or ptk[1] or ""):match("^([%d%.]+)%%$")
                st.ptp = tonumber(tpc or bpc)
                local a, b, c, d = parseEdges(lv, fs, false)
                if a then st.pt, st.pr, st.pb, st.pl = a, b, c, d end
            elseif prop == "padding-top" or prop == "padding-right" or prop == "padding-bottom" or prop == "padding-left" then
                if prop == "padding-top" or prop == "padding-bottom" then
                    local pc = lv:match("^([%d%.]+)%%$")
                    if pc then st.ptp = tonumber(pc) end
                end
                local o = parseLen(lv, fs)
                if o then
                    local k = ({["padding-top"] = "pt", ["padding-right"] = "pr", ["padding-bottom"] = "pb", ["padding-left"] = "pl"})[prop]
                    st[k] = o
                end
            elseif prop == "margin" then
                local a, b, c, d = parseEdges(lv, fs, true)
                if a then st.mt, st.mr, st.mb, st.ml = a, b, c, d end
            elseif prop == "margin-top" or prop == "margin-right" or prop == "margin-bottom" or prop == "margin-left" then
                local k = ({["margin-top"] = "mt", ["margin-right"] = "mr", ["margin-bottom"] = "mb", ["margin-left"] = "ml"})[prop]
                if lv == "auto" then st[k] = "auto"
                else
                    local o = parseLen(lv, fs)
                    if o then st[k] = o end
                end
            elseif SIZEKEY[prop] then
                local key = SIZEKEY[prop]
                if lv == "auto" or lv == "none" or lv:find("content") then
                    st[key] = nil
                else
                    local o, sc = parseLen(lv, fs)
                    if o or sc then st[key] = {o, sc} end
                end
            elseif BORDERKEY[prop] or prop == "border" then
                local key = BORDERKEY[prop] or "b"
                if lv:find("none") or lv == "0" or lv:find("^0px") or lv:find("hidden") then
                    st[key] = nil
                else
                    local ct = lv:match("rgba?%b()") or lv:match("hsla?%b()") or lv:match("#%x+")
                    local col, al
                    if ct then col, al = parseColor(ct) end
                    if not col then
                        for w in lv:gmatch("%a+") do
                            if NAMED[w] then col = parseColor(w) break end
                        end
                    end
                    local wpx = tonumber(lv:match("([%d%.]+)px")) or (lv:find("thick") and 5) or (lv:find("medium") and 3) or 1
                    st[key] = {w = math.max(0.75, wpx * 0.75), c = col and U.dk(col, "bd") or st.color, a = al}
                end
            elseif prop == "gap" or prop == "column-gap" or prop == "row-gap" then
                local first, second = lv:match("^(%S+)%s+(%S+)$")
                local o = parseLen(first or lv:match("^%S+") or "", fs)
                if o then st.gap = o end
                if prop == "gap" and second then
                    local o2 = parseLen(second, fs)
                    if o2 then st.colgap = o2 end
                elseif prop == "column-gap" and o then
                    st.colgap = o
                elseif prop == "row-gap" and o then
                    st.rowgap = o
                end
            elseif prop == "justify-content" then
                st.jc = lv
            elseif prop == "align-items" then
                st.ai = lv
            elseif prop == "flex-wrap" then
                st.wrap = lv ~= "nowrap"
            elseif prop == "flex" or prop == "flex-grow" then
                local n = tonumber(lv:match("^[%d%.]+"))
                st.grow = (n and n > 0) or lv == "auto"
                if prop == "flex" then
                    local firstTok, lastTok = lv:match("^%S+"), nil
                    for tk in lv:gmatch("%S+") do lastTok = tk end
                    if lastTok and lastTok ~= firstTok and (lastTok:find("^[%d%.]+%a+$") or lastTok:find("^[%d%.]+%%$")) then
                        local o, sc = parseLen(lastTok, fs)
                        if (o and o > 0) or (sc and sc > 0) then st.fbasis = {o, sc} end
                    end
                end
            elseif prop == "grid-template-columns" then
                local n = lv:match("repeat%(%s*(%d+)")
                if n then
                    st.cols = tonumber(n)
                elseif lv:find("auto%-fit") or lv:find("auto%-fill") then
                    local mpx = tonumber(lv:match("minmax%(%s*([%d%.]+)px")) or tonumber(lv:match("([%d%.]+)px")) or 250
                    st.cols = math.max(1, math.floor(VW / mpx))
                else
                    local c = 0
                    for _ in lv:gsub("%b()", "x"):gmatch("%S+") do c = c + 1 end
                    st.cols = math.max(1, c)
                end
                st.tracks = st.cols and trackFractions(lv, st.cols) or nil
            elseif prop == "opacity" then
                st.opacity = tonumber(lv)
            elseif prop == "box-shadow" then
                if lv == "none" or lv:find("^inset") then
                    st.shadow = nil
                else
                    local nums = {}
                    for n in lv:gsub("rgba?%b()", ""):gsub("hsla?%b()", ""):gmatch("(%-?[%d%.]+)px") do nums[#nums + 1] = tonumber(n) end
                    local rg = lv:match("rgba?%b()")
                    local al = 0.25
                    if rg and (rg:find("^rgba") or rg:find("/")) then
                        local a4 = rg:match("[,/]%s*([%d%.]+)%s*%)$")
                        if a4 then al = tonumber(a4) or al end
                    end
                    st.shadow = {a = al, y = nums[2] or 0, blur = nums[3] or 8}
                end
            elseif prop == "object-fit" then
                if lv == "cover" or lv == "contain" or lv == "fill" or lv == "none" or lv == "scale-down" then st.objfit = lv end
            elseif prop == "object-position" then
                st.objpos = lv
            elseif prop == "background-size" then
                if lv:find("contain") then st.bgfit = "contain"
                elseif lv:find("cover") then st.bgfit = "cover"
                elseif lv:find("%d+px") then st.bgfit = "contain" end
            elseif prop == "background-repeat" then
                st.bgrepeat = lv
            elseif prop == "aspect-ratio" then
                local a1, b1 = lv:match("^([%d%.]+)%s*/%s*([%d%.]+)")
                if a1 then st.ar = tonumber(a1) / math.max(0.01, tonumber(b1)) else st.ar = tonumber(lv) end
            elseif prop == "white-space" then
                st.nowrap = lv:find("nowrap") ~= nil
            elseif prop == "text-overflow" then
                st.ell = lv:find("ellipsis") ~= nil
            elseif prop == "overflow" or prop == "overflow-x" or prop == "overflow-y" then
                st.clip = lv:find("hidden") ~= nil
            elseif prop == "line-height" then
                local n = tonumber(lv)
                if n then st.lh = n
                else
                    local px = tonumber(lv:match("^([%d%.]+)px"))
                    local pc = tonumber(lv:match("^([%d%.]+)%%"))
                    local em = tonumber(lv:match("^([%d%.]+)r?em"))
                    if px then st.lh = px * 0.75 / st.size
                    elseif pc then st.lh = pc / 100
                    elseif em then st.lh = em end
                end
            elseif prop == "text-transform" then
                st.tt = lv
            elseif prop == "position" then
                st.pos = lv
            elseif prop == "list-style" or prop == "list-style-type" then
                st.lsn = lv:find("none") ~= nil
            elseif prop == "animation" or prop == "animation-name" then
                local name, inf
                local times = {}
                for tok in lv:gmatch("%S+") do
                    local num, unit = tok:match("^([%d%.]+)(m?s)$")
                    if num then
                        times[#times + 1] = tonumber(num) * (unit == "ms" and 0.001 or 1)
                    elseif tok == "infinite" then
                        inf = true
                    elseif not name and tok:match("^[%a_][%w_%-]*$") and not ({ease = 1, linear = 1, ["ease-in"] = 1, ["ease-out"] = 1, ["ease-in-out"] = 1, forwards = 1, backwards = 1, both = 1, none = 1, normal = 1, reverse = 1, alternate = 1, running = 1, paused = 1})[tok] then
                        name = tok
                    end
                end
                if name then
                    st.anim = {name = name, dur = times[1] or 0.5, delay = times[2] or 0, inf = inf}
                else
                    st.anim = nil
                end
            elseif prop == "transition" then
                local ms = tonumber(lv:match("([%d%.]+)ms"))
                local sec = tonumber(lv:match("([%d%.]+)s"))
                st.trans = ms and ms / 1000 or sec or 0.2
            end
        end

        -- seletores: tag, .classe, #id e combinações; descendentes ("a b" / "a > b")
        local function parseCompound(tok)
            -- extrai seletores de atributo [a] [a=v] [a^=v] [a$=v] [a*=v] [a~=v] [a|=v], so fora de (..)
            -- (dentro de :not(..) eles pertencem ao composto interno)
            local atl, badAt = {}, false
            do
                local out, i, n, dP = {}, 1, #tok, 0
                while i <= n do
                    local ch = tok:sub(i, i)
                    if ch == "(" then
                        dP = dP + 1; out[#out + 1] = ch; i = i + 1
                    elseif ch == ")" then
                        dP = dP - 1; out[#out + 1] = ch; i = i + 1
                    elseif ch == "[" and dP == 0 then
                        local j, q = i + 1, nil
                        while j <= n do
                            local cj = tok:sub(j, j)
                            if q then
                                if cj == q then q = nil end
                            elseif cj == '"' or cj == "'" then q = cj
                            elseif cj == "]" then break end
                            j = j + 1
                        end
                        if j > n then return nil end
                        local inner = tok:sub(i + 1, j - 1)
                        local nm, op, val = inner:match("^%s*([%w_:%-]+)%s*([%^%$%*~|]?=)%s*(.-)%s*$")
                        if nm then
                            val = val:gsub("%s+[iIsS]$", "")
                            val = val:match('^"(.*)"$') or val:match("^'(.*)'$") or val
                            atl[#atl + 1] = {nm:lower(), op, val}
                        else
                            nm = inner:match("^%s*([%w_:%-]+)%s*$")
                            if nm then atl[#atl + 1] = {nm:lower()} else badAt = true end
                        end
                        i = j + 1
                    else
                        out[#out + 1] = ch; i = i + 1
                    end
                end
                tok = table.concat(out)
            end
            if badAt then return nil end
            local base, rest = tok:match("^([^:]*)(.*)$")
            if base:find("[^%w_%-#%.%*]") then return nil end
            local c = {tag = base:match("^([%a][%w%-]*)"), id = base:match("#([%w_%-]+)"), cls = {}, ps = {}, nots = {}, at = atl}
            for k in base:gmatch("%.([%w_%-]+)") do c.cls[#c.cls + 1] = k end
            local pos = 1
            while pos <= #rest do
                local nm, arg, e = rest:match("^:([%a%-]+)%(([^%)]*)%)()", pos)
                if not nm then
                    nm, e = rest:match("^:([%a%-]+)()", pos)
                    arg = nil
                end
                if not nm then return nil end
                if nm == "not" then
                    if not arg or arg:find(":") then return nil end
                    local inner = parseCompound(arg)
                    if not inner then return nil end
                    c.nots[#c.nots + 1] = inner
                elseif nm == "first-child" or nm == "last-child" or nm == "only-child" or nm == "first-of-type" or nm == "last-of-type" or nm == "nth-child" or nm == "nth-of-type" or nm == "nth-last-child" then
                    c.ps[#c.ps + 1] = {nm, arg}
                elseif nm == "empty" or nm == "checked" or nm == "disabled" or nm == "enabled" or nm == "required" or nm == "optional" then
                    c.ps[#c.ps + 1] = {nm, arg}
                elseif nm == "link" or nm == "any-link" or nm == "visited" or nm == "root" then
                else
                    return nil
                end
                pos = e
            end
            return c
        end

        -- tokeniza em compostos + combinadores (" " descendente, ">" filho, "+" irmao adjacente, "~" irmaos
        -- seguintes), respeitando [..], (..) e aspas. Cada composto guarda em .comb o combinador que o
        -- liga ao composto ANTERIOR.
        local function parseSelector(s)
            local parts, buf, comb = {}, {}, " "
            local dB, dP, q = 0, 0, nil
            local function flush()
                if #buf == 0 then return true end
                local c = parseCompound(table.concat(buf))
                buf = {}
                if not c then return false end
                c.comb = comb
                parts[#parts + 1] = c
                comb = " "
                return true
            end
            for i = 1, #s do
                local ch = s:sub(i, i)
                if q then
                    buf[#buf + 1] = ch
                    if ch == q then q = nil end
                elseif ch == '"' or ch == "'" then
                    q = ch
                    buf[#buf + 1] = ch
                elseif ch == "[" then dB = dB + 1; buf[#buf + 1] = ch
                elseif ch == "]" then dB = dB - 1; buf[#buf + 1] = ch
                elseif ch == "(" then dP = dP + 1; buf[#buf + 1] = ch
                elseif ch == ")" then dP = dP - 1; buf[#buf + 1] = ch
                elseif dB == 0 and dP == 0 and (ch == ">" or ch == "+" or ch == "~") then
                    if not flush() then return nil end
                    comb = ch
                elseif dB == 0 and dP == 0 and ch:find("%s") then
                    if not flush() then return nil end
                else
                    buf[#buf + 1] = ch
                end
            end
            if not flush() then return nil end
            if #parts == 0 then return nil end
            return parts
        end

        -- divide por virgulas so no nivel de topo (ignora (..), [..] e aspas)
        local function splitTop(str)
            local out, buf, dB, dP, q = {}, {}, 0, 0, nil
            for i = 1, #str do
                local ch = str:sub(i, i)
                if q then
                    buf[#buf + 1] = ch
                    if ch == q then q = nil end
                elseif ch == '"' or ch == "'" then q = ch; buf[#buf + 1] = ch
                elseif ch == "[" then dB = dB + 1; buf[#buf + 1] = ch
                elseif ch == "]" then dB = dB - 1; buf[#buf + 1] = ch
                elseif ch == "(" then dP = dP + 1; buf[#buf + 1] = ch
                elseif ch == ")" then dP = dP - 1; buf[#buf + 1] = ch
                elseif ch == "," and dB == 0 and dP == 0 then
                    out[#out + 1] = table.concat(buf); buf = {}
                else buf[#buf + 1] = ch end
            end
            out[#out + 1] = table.concat(buf)
            return out
        end

        -- "h1, :is(a, b) > c, x:not(.p, .q)"  ->  {"h1", "a > c", "b > c", "x:not(.p):not(.q)"}
        local function expandSel(sel, depth)
            depth = depth or 0
            local res = {}
            for _, one in ipairs(splitTop(sel)) do
                one = trim(one)
                if one ~= "" then
                    -- :not(:is(a, b)) = nao-a E nao-b (nao pode virar "ou")
                    for _, nm in ipairs({"is", "where"}) do
                        one = (one:gsub(":not%(:" .. nm .. "%(([^%(%)]*)%)%)", function(inner)
                            local t = {}
                            for _, x in ipairs(splitTop(inner)) do t[#t + 1] = ":not(" .. trim(x) .. ")" end
                            return table.concat(t)
                        end))
                    end
                    local a = one:find(":is%(") or one:find(":where%(") or one:find(":matches%(") or one:find(":%-webkit%-any%(")
                    local ps = a and one:find("(", a, true)
                    local grp = ps and one:match("^%b()", ps)
                    if grp and depth < 4 then
                        local pre, post = one:sub(1, a - 1), one:sub(ps + #grp)
                        for _, alt in ipairs(splitTop(grp:sub(2, -2))) do
                            for _, v in ipairs(expandSel(pre .. trim(alt) .. post, depth + 1)) do
                                if #res < 64 then res[#res + 1] = v end
                            end
                        end
                    else
                        one = (one:gsub(":not%(([^%(%)]*,[^%(%)]*)%)", function(inner)
                            local t = {}
                            for _, x in ipairs(splitTop(inner)) do t[#t + 1] = ":not(" .. trim(x) .. ")" end
                            return table.concat(t)
                        end))
                        if #res < 64 then res[#res + 1] = one end
                    end
                end
            end
            return res
        end

        local function classSet(node)
            if node.clsSet then return node.clsSet end
            local t = {}
            local c = node.attrs and node.attrs.class
            if c then for w in c:gmatch("%S+") do t[w] = true end end
            node.clsSet = t
            return t
        end

        local function sibInfo(node)
            if node.sibI then return node.sibI, node.sibN, node.sibTI, node.sibTN end
            local par = node.parent
            local i, n, ti, tn = 0, 0, 0, 0
            if par then
                for _, k in ipairs(par.kids or {}) do
                    if k.tag then
                        n = n + 1
                        if k == node then i = n end
                        if k.tag == node.tag then
                            tn = tn + 1
                            if k == node then ti = tn end
                        end
                    end
                end
            end
            node.sibI, node.sibN, node.sibTI, node.sibTN = i, n, ti, tn
            return i, n, ti, tn
        end

        local function nthOk(arg, idx)
            arg = arg:gsub("%s", "")
            if arg == "odd" then return idx % 2 == 1 end
            if arg == "even" then return idx % 2 == 0 end
            local num = tonumber(arg)
            if num then return idx == num end
            local a, b = arg:match("^([%+%-]?%d*)n([%+%-]%d+)$")
            if not a then
                a = arg:match("^([%+%-]?%d*)n$")
                b = "0"
            end
            if not a then return false end
            local an = (a == "" or a == "+") and 1 or ((a == "-") and -1 or tonumber(a))
            local bn = tonumber(b) or 0
            if an == 0 then return idx == bn end
            local k = (idx - bn) / an
            return k >= 0 and k == math.floor(k)
        end

        local function matchPseudo(node, nm, arg)
            local i, n, ti, tn = sibInfo(node)
            if nm == "first-child" then return i == 1
            elseif nm == "last-child" then return i == n
            elseif nm == "only-child" then return n == 1
            elseif nm == "first-of-type" then return ti == 1
            elseif nm == "last-of-type" then return ti == tn
            elseif nm == "nth-child" then return nthOk(arg or "", i)
            elseif nm == "nth-of-type" then return nthOk(arg or "", ti)
            elseif nm == "nth-last-child" then return nthOk(arg or "", n - i + 1)
            elseif nm == "empty" then
                for _, k in ipairs(node.kids or {}) do
                    if k.tag or (k.text and k.text:find("%S")) then return false end
                end
                return true
            elseif nm == "checked" then return node.attrs.checked ~= nil or node.attrs.selected ~= nil
            elseif nm == "disabled" then return node.attrs.disabled ~= nil
            elseif nm == "enabled" then return node.attrs.disabled == nil
            elseif nm == "required" then return node.attrs.required ~= nil
            elseif nm == "optional" then return node.attrs.required == nil end
            return true
        end

        local function matchCompound(node, c)
            if not node.tag then return false end
            if c.tag and node.tag ~= c.tag then return false end
            if c.id and node.attrs.id ~= c.id then return false end
            if #c.cls > 0 then
                local cs = classSet(node)
                for _, k in ipairs(c.cls) do if not cs[k] then return false end end
            end
            if c.at then
                for _, a in ipairs(c.at) do
                    local v = node.attrs[a[1]]
                    if v == nil or v == false then return false end
                    local op, want = a[2], a[3]
                    if op then
                        v = tostring(v)
                        if op == "=" then
                            if v ~= want then return false end
                        elseif op == "^=" then
                            if want == "" or v:sub(1, #want) ~= want then return false end
                        elseif op == "$=" then
                            if want == "" or v:sub(-#want) ~= want then return false end
                        elseif op == "*=" then
                            if want == "" or not v:find(want, 1, true) then return false end
                        elseif op == "~=" then
                            local hit = false
                            for w in v:gmatch("%S+") do if w == want then hit = true break end end
                            if not hit then return false end
                        elseif op == "|=" then
                            if v ~= want and v:sub(1, #want + 1) ~= want .. "-" then return false end
                        end
                    end
                end
            end
            for _, p in ipairs(c.ps) do
                if not matchPseudo(node, p[1], p[2]) then return false end
            end
            for _, nt in ipairs(c.nots) do
                if matchCompound(node, nt) then return false end
            end
            return true
        end

        local function prevElSibling(node)
            local par = node.parent
            if not par then return nil end
            local prev
            for _, k in ipairs(par.kids or {}) do
                if k == node then return prev end
                if k.tag then prev = k end
            end
            return nil
        end

        -- node ja casa parts[k]; confere os compostos anteriores respeitando cada combinador
        local function matchRuleAt(node, parts, k)
            if k <= 1 then return true end
            local comb, want = parts[k].comb, parts[k - 1]
            if comb == ">" then
                local par = node.parent
                return par ~= nil and matchCompound(par, want) and matchRuleAt(par, parts, k - 1)
            elseif comb == "+" then
                local sib = prevElSibling(node)
                return sib ~= nil and matchCompound(sib, want) and matchRuleAt(sib, parts, k - 1)
            elseif comb == "~" then
                local par = node.parent
                if not par then return false end
                local prevs = {}
                for _, kid in ipairs(par.kids or {}) do
                    if kid == node then break end
                    if kid.tag then prevs[#prevs + 1] = kid end
                end
                for i = #prevs, 1, -1 do
                    if matchCompound(prevs[i], want) and matchRuleAt(prevs[i], parts, k - 1) then return true end
                end
                return false
            end
            local anc = node.parent
            while anc do
                if matchCompound(anc, want) and matchRuleAt(anc, parts, k - 1) then return true end
                anc = anc.parent
            end
            return false
        end

        local function matchRule(node, parts)
            if not matchCompound(node, parts[#parts]) then return false end
            return matchRuleAt(node, parts, #parts)
        end

        -- ---------------------------------------------------------- parser HTML
        local function parseHtml(html)
            local root = {tag = "#root", attrs = {}, kids = {}}
            local stack = {root}
            local low = html:lower()
            local pos, n, count = 1, #html, 0
            local styles, sheets = {}, {}
            local function top() return stack[#stack] end
            local function addText(t)
                if t == "" then return end
                local p = top()
                p.kids[#p.kids + 1] = {text = U.decode(t), parent = p}
            end
            while pos <= n and count < 12000 do
                local lt = html:find("<", pos, true)
                if not lt then addText(html:sub(pos)) break end
                if lt > pos then addText(html:sub(pos, lt - 1)) end
                local nx = html:sub(lt + 1, lt + 1)
                if html:sub(lt, lt + 3) == "<!--" then
                    local e = html:find("-->", lt + 4, true)
                    pos = e and (e + 3) or (n + 1)
                elseif nx == "!" or nx == "?" then
                    local e = html:find(">", lt, true)
                    pos = e and (e + 1) or (n + 1)
                elseif nx == "/" then
                    local name, e = html:match("^</%s*([%w:%-]+)[^>]*>()", lt)
                    if name then
                        name = name:lower()
                        for i = #stack, 2, -1 do
                            if stack[i].tag == name then
                                for j = #stack, i, -1 do stack[j] = nil end
                                break
                            end
                        end
                        pos = e
                    else
                        addText("<")
                        pos = lt + 1
                    end
                else
                    local name = html:match("^<([%a][%w:%-]*)", lt)
                    if not name then
                        addText("<")
                        pos = lt + 1
                    else
                        count = count + 1
                        local i, q = lt + 1 + #name, nil
                        while i <= n do
                            local c = html:byte(i)
                            if q then
                                if c == q then q = nil end
                            elseif c == 34 or c == 39 then q = c
                            elseif c == 62 then break end
                            i = i + 1
                        end
                        local attrStr = html:sub(lt + 1 + #name, i - 1)
                        pos = i + 1
                        name = name:lower()
                        local attrs = {}
                        for k, v in attrStr:gmatch('([%w:_%-]+)%s*=%s*"(.-)"') do attrs[k:lower()] = U.decode(v) end
                        for k, v in attrStr:gmatch("([%w:_%-]+)%s*=%s*'(.-)'") do
                            if attrs[k:lower()] == nil then attrs[k:lower()] = U.decode(v) end
                        end
                        for k, v in attrStr:gmatch("([%w:_%-]+)=([^%s\"'>]+)") do
                            if attrs[k:lower()] == nil then attrs[k:lower()] = U.decode(v) end
                        end
                        if attrStr:find("%shidden%f[%W]") then attrs.hidden = "" end
                        local selfClose = attrStr:sub(-1) == "/"
                        local t0 = top()
                        if t0.tag == "p" and BLOCKT[name] then stack[#stack] = nil end
                        local cl = CLOSES[name]
                        if cl then
                            while #stack > 1 and cl[top().tag] do stack[#stack] = nil end
                        end
                        local par = top()
                        local node = {tag = name, attrs = attrs, kids = {}, parent = par}
                        par.kids[#par.kids + 1] = node
                        if name == "style" or name == "script" or name == "textarea" or name == "title" then
                            local e = low:find("</" .. name, pos, true)
                            local body = html:sub(pos, (e or (n + 1)) - 1)
                            if name == "style" then styles[#styles + 1] = body
                            elseif name ~= "script" then node.kids[1] = {text = U.decode(body), parent = node} end
                            local gt = e and html:find(">", e, true)
                            pos = gt and (gt + 1) or (n + 1)
                        elseif name == "link" then
                            if (attrs.rel or ""):lower():find("stylesheet") and attrs.href and (attrs.media or "") ~= "print" then
                                sheets[#sheets + 1] = attrs.href
                            end
                        elseif not VOID[name] and not selfClose and #stack < 120 then
                            stack[#stack + 1] = node
                        end
                    end
                end
            end
            return root, styles, sheets
        end

        local function hexOf(c)
            return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
        end

        -- ---------------------------------------------------------- construtor principal
        U.makeVideo = function(o)
            local function mk(cls, props, parent)
                local i = Instance.new(cls)
                for k, v in pairs(props) do i[k] = v end
                i.Parent = parent
                return i
            end
            local root = mk("Frame", {BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 5}, nil)
            local sw = o.sw
            if o.auto then root.Size = UDim2.new(0, math.min(240, AVAILW), 0, 0)
            elseif sw and (sw[2] or (sw[1] and sw[1] < AVAILW)) then root.Size = UDim2.new(sw[2] or 0, sw[1] or 0, 0, 0)
            else root.Size = UDim2.new(1, 0, 0, 0) end
            mk("UIAspectRatioConstraint", {AspectRatio = math.clamp(o.aspect or (16 / 9), 0.4, 3)}, root)
            local ro = o.rs and 0 or ((o.radius and o.radius > 0) and math.min(o.radius, 500) or 6)
            corner(root, UDim.new(o.rs or 0, ro))
            local poster = mk("ImageLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, ZIndex = 5}, root)
            if o.poster then
                task.spawn(function()
                    local ok, a = pcall(U.cacheImage, o.poster, 3000000)
                    if ok and a and poster.Parent then poster.Image = a end
                end)
            end
            local vf = mk("VideoFrame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5, Visible = false, Looped = o.loop and true or false}, root)
            local muted = o.muted and true or false
            vf.Volume = muted and 0 or (currentVolume or 1)
            local surface = mk("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 6}, root)
            local big = mk("TextButton", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 46, 0, 46), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Text = "▶", TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 18, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 9}, root)
            corner(big, UDim.new(1, 0))
            local badge = mk("TextLabel", {Position = UDim2.new(0, 5, 0, 5), Size = UDim2.new(0, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25, BorderSizePixel = 0, Text = "VÍDEO", TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 9, ZIndex = 10}, root)
            corner(badge, UDim.new(0, 7))
            mk("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, badge)
            local status = mk("TextLabel", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -32), Size = UDim2.new(0, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3, Text = "", TextColor3 = WHITE, Font = Enum.Font.Gotham, TextSize = 10, Visible = false, BorderSizePixel = 0, ZIndex = 10}, root)
            corner(status, UDim.new(0, 9))
            mk("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, status)
            local bar = mk("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 8}, root)
            local playBtn = mk("TextButton", {Position = UDim2.new(0, 2, 0, 1), Size = UDim2.new(0, 24, 0, 24), BackgroundTransparency = 1, Text = "▶", TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, ZIndex = 9}, bar)
            local hit = mk("TextButton", {Position = UDim2.new(0, 30, 0, 4), Size = UDim2.new(1, -124, 0, 18), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 9}, bar)
            local track = mk("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = Color3.fromRGB(110, 110, 114), BorderSizePixel = 0, ZIndex = 9}, hit)
            corner(track, UDim.new(1, 0))
            local fill = mk("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 70, 70), BorderSizePixel = 0, ZIndex = 10}, track)
            corner(fill, UDim.new(1, 0))
            local timeLbl = mk("TextLabel", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 0), Size = UDim2.new(0, 62, 1, 0), BackgroundTransparency = 1, Text = "0:00", TextColor3 = WHITE, Font = Enum.Font.Gotham, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 9}, bar)
            local muteBtn = mk("TextButton", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 1), Size = UDim2.new(0, 24, 0, 24), BackgroundTransparency = 1, Text = muted and "🔇" or "🔊", TextColor3 = WHITE, Font = Enum.Font.Gotham, TextSize = 12, AutoButtonColor = false, ZIndex = 9}, bar)
            local loaded, loading, failed, dlMode = false, false, false, false
            local function setStatus(t)
                status.Text = t
                status.Visible = t ~= ""
            end
            local function fmt(t)
                t = math.max(0, math.floor(t or 0))
                return string.format("%d:%02d", t // 60, t % 60)
            end
            local function ensure()
                if loaded then return true end
                if failed or loading then return false end
                if not o.url then
                    failed = true
                    setStatus("Fonte de vídeo não encontrada")
                    return false
                end
                loading = true
                big.Visible = false
                setStatus("baixando vídeo…")
                badge.Text = "VÍDEO · baixando…"
                local ok, asset = pcall(function()
                    U.ensureCache()
                    local key = "vid_" .. U.hash2(o.url)
                    local path
                    for _, ex in ipairs({"mp4", "webm"}) do
                        local p = CACHE_DIR .. "/" .. key .. "." .. ex
                        local okF, has = pcall(isfile, p)
                        if okF and has then path = p break end
                    end
                    if not path then
                        local body = U.httpGet(o.url)
                        if type(body) ~= "string" or #body < 1000 then error("Arquivo vazio", 0) end
                        if #body > 90000000 then error("Vídeo grande demais", 0) end
                        local ex
                        if body:sub(5, 8) == "ftyp" then ex = "mp4" elseif body:sub(1, 4) == "\26\69\223\163" then ex = "webm" end
                        if not ex then error("Formato não suportado (use MP4 ou WebM)", 0) end
                        path = CACHE_DIR .. "/" .. key .. "." .. ex
                        writefile(path, body)
                    end
                    return getcustomasset(path)
                end)
                if not ok or type(asset) ~= "string" or asset == "" then
                    loading = false
                    failed = true
                    dlMode = true
                    big.Text = "⬇"
                    badge.Text = "VÍDEO · erro"
                    big.Visible = true
                    setStatus(ok and "Seu executor não abre vídeo local · toque p/ baixar" or tostring(asset):sub(1, 60))
                    return false
                end
                setStatus("carregando…")
                vf.Video = asset
                local t0 = os.clock()
                while not vf.IsLoaded and os.clock() - t0 < 25 and root.Parent do task.wait(0.1) end
                loading = false
                if not root.Parent then return false end
                if not vf.IsLoaded then
                    failed = true
                    dlMode = true
                    big.Text = "⬇"
                    badge.Text = "VÍDEO · erro"
                    big.Visible = true
                    setStatus("Não foi possível tocar aqui · toque p/ baixar")
                    return false
                end
                loaded = true
                badge.Text = "VÍDEO"
                setStatus("")
                vf.Visible = true
                poster.Visible = false
                return true
            end
            local function toggle()
                if dlMode then
                    task.spawn(function()
                        local ok, r = pcall(U.download, o.url, (o.url:lower():match("%.(%w+)$") == "webm") and "webm" or "mp4")
                        if toast then toast(ok and type(r) == "table" and ("Salvo em " .. r.path) or "Falha ao baixar") end
                    end)
                    return
                end
                if loading then return end
                if not loaded then
                    task.spawn(function()
                        if ensure() then vf:Play() end
                    end)
                    return
                end
                if vf.Playing then vf:Pause() else vf:Play() end
            end
            big.MouseButton1Click:Connect(toggle)
            surface.MouseButton1Click:Connect(toggle)
            playBtn.MouseButton1Click:Connect(toggle)
            muteBtn.MouseButton1Click:Connect(function()
                muted = not muted
                vf.Volume = muted and 0 or (currentVolume or 1)
                muteBtn.Text = muted and "🔇" or "🔊"
            end)
            local dragging = false
            local function seek(x)
                if not loaded then return end
                local w = hit.AbsoluteSize.X
                if w <= 0 or vf.TimeLength <= 0 then return end
                vf.TimePosition = math.clamp((x - hit.AbsolutePosition.X) / w, 0, 1) * vf.TimeLength
            end
            local function isPress(i)
                return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
            end
            hit.InputBegan:Connect(function(i)
                if isPress(i) then
                    dragging = true
                    seek(i.Position.X)
                end
            end)
            local c1 = UserInputService.InputChanged:Connect(function(i)
                if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then seek(i.Position.X) end
            end)
            local c2 = UserInputService.InputEnded:Connect(function(i)
                if isPress(i) then dragging = false end
            end)
            local acc, conn = 0, nil
            conn = RunService.Heartbeat:Connect(function(dt)
                if not root.Parent then
                    conn:Disconnect()
                    c1:Disconnect()
                    c2:Disconnect()
                    pcall(function() vf:Pause() end)
                    return
                end
                acc = acc + dt
                if acc < 0.1 then return end
                acc = 0
                if not loaded then return end
                local playing = vf.Playing
                playBtn.Text = playing and "❚❚" or "▶"
                badge.Text = playing and "VÍDEO" or "VÍDEO · pausado"
                big.Visible = (not playing) and (not loading)
                local len = vf.TimeLength
                if len > 0 then
                    fill.Size = UDim2.new(math.clamp(vf.TimePosition / len, 0, 1), 0, 1, 0)
                    timeLbl.Text = fmt(vf.TimePosition) .. " / " .. fmt(len)
                end
            end)
            if o.autoplay then task.defer(toggle) end
            return root
        end

        local function fitUS()
            local okS, vS = pcall(function() return phoneUIScale.Scale end)
            return (okS and tonumber(vS)) or 1
        end

        -- moldura da pagina: altura acompanha o conteudo (mesmo quando encolhido) e corta qualquer excesso lateral
        U.fitSetup = function(holder, canvas)
            local function syncHeight()
                if not holder.Parent or not canvas.Parent then return end
                local h = canvas.AbsoluteSize.Y / fitUS()
                holder.Size = UDim2.new(1, 0, 0, math.max(1, math.ceil(h)))
            end
            canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncHeight)
            syncHeight()
        end

        -- "ajustada final": se algo ainda passar da largura da tela, encolhe a pagina inteira ate caber
        -- (igual aos navegadores de celular), com piso de 55%
        U.fitRun = function(holder, canvas, alive)
            local MINS = 0.55
            local sc = canvas:FindFirstChild("FitScale")
            if not sc then
                sc = Instance.new("UIScale")
                sc.Name = "FitScale"
                sc.Scale = 1
                sc.Parent = canvas
            end
            local function extentRatio()
                local left = canvas.AbsolutePosition.X
                local cw = math.max(canvas.AbsoluteSize.X, 1)
                local maxR = left + cw
                local cnt = 0
                for _, d in ipairs(canvas:GetDescendants()) do
                    cnt = cnt + 1
                    if cnt % 400 == 0 then
                        task.wait()
                        if not alive() then return 1 end
                    end
                    if d:IsA("GuiObject") and d.Visible and not (d:IsA("ImageLabel") and d.ScaleType == Enum.ScaleType.Slice) then
                        local hidden = false
                        local p = d.Parent
                        while p and p ~= canvas do
                            if p:IsA("GuiObject") and (p.ClipsDescendants or not p.Visible) then hidden = true break end
                            p = p.Parent
                        end
                        if not hidden then
                            local r = d.AbsolutePosition.X + d.AbsoluteSize.X
                            if r > maxR then maxR = r end
                        end
                    end
                end
                return (maxR - left) / cw
            end
            local function pass()
                if not alive() or not holder.Parent then return end
                local r = extentRatio()
                if not alive() then return end
                if r > 1.015 and sc.Scale > MINS + 0.001 then
                    local ns = math.max(MINS, sc.Scale / r)
                    sc.Scale = ns
                    canvas.Size = UDim2.new(1 / ns, 0, 0, 0)
                end
            end
            task.spawn(function()
                for _, d in ipairs({0.25, 0.9, 2, 4, 8}) do
                    task.wait(d)
                    if not alive() then return end
                    pass()
                end
            end)
        end

        U.layoutBuild = function(entry, canvas, html, alive, setStatus, openImg)
        BASE.color = U.dark.on and Color3.fromRGB(228, 230, 233) or Color3.fromRGB(0, 0, 0)
            local root, styleTexts, sheets = parseHtml(html)
            -- Discord e outros SPAs entregam um shell HTML e montam a interface via JavaScript.
            -- Guardamos o sinal para mostrar um aviso honesto quando a resposta nao tem conteudo renderizavel.
            local sourceLower = tostring(html or ""):lower()
            local isDiscordShell = entry.url and entry.url:lower():find("discord.com", 1, true) and
                (sourceLower:find("discordapp", 1, true) or sourceLower:find("webpack", 1, true) or sourceLower:find("__next", 1, true))
            entry.isDiscordShell = isDiscordShell and true or false
            -- Respeita <base href>, usado por muitos sites para resolver CSS, imagens e links.
            local docBase = entry.url
            local function findBase(n, depth)
                if depth > 40 then return nil end
                if n.tag == "base" and n.attrs and n.attrs.href and n.attrs.href ~= "" then return n.attrs.href end
                for _, child in ipairs(n.kids or {}) do
                    if child.tag then
                        local found = findBase(child, depth + 1)
                        if found then return found end
                    end
                end
                return nil
            end
            local baseHref = findBase(root, 0)
            if baseHref then docBase = U.resolve(entry.url, baseHref) or entry.url end
            entry.docBase = docBase
            local rules, idx, order = {}, {}, 0
            for k in pairs(VARS) do VARS[k] = nil end
            for k in pairs(KF) do KF[k] = nil end
            local function curUS()
                local okS, vS = pcall(function() return phoneUIScale.Scale end)
                return (okS and tonumber(vS)) or 1
            end
            local function totScale()
                local fs = canvas:FindFirstChild("FitScale")
                return curUS() * ((fs and fs:IsA("UIScale")) and fs.Scale or 1)
            end
            do
                local us = totScale()
                local w0 = canvas.AbsoluteSize.X
                if w0 < 40 then w0 = pageView.AbsoluteSize.X - 20 * us end
                local localW = (w0 > 40) and (w0 / us) or 268
                localW = math.clamp(localW, 160, 600)
                AVAILW = math.max(140, localW - 14)
                VW = math.max(280, math.floor(localW / 0.75))
            end
            local hidx = {}

            local function mediaOk(c)
                c = c:lower()
                if c:find("prefers%-color%-scheme:%s*dark") and not U.dark.on then return false end
                if c:find("prefers%-color%-scheme:%s*light") and U.dark.on then return false end
                if c:find("prefers%-reduced%-motion:%s*reduce") or c:find("print") or c:find("orientation:%s*landscape") then return false end
                for kind, num, unit in c:gmatch("(m[ai][xn])%-width%s*:%s*([%d%.]+)(%a*)") do
                    num = tonumber(num)
                    if unit == "em" or unit == "rem" then num = num * 16 end
                    if kind == "max" and not (VW <= num) then return false end
                    if kind == "min" and not (VW >= num) then return false end
                end
                return true
            end

            local function addCss(text)
                text = text:gsub("/%*.-%*/", "")
                text = text:gsub("@import[^;]*;", ""):gsub("@charset[^;]*;", "")
                local i, n = 1, #text
                while i <= n do
                    local ob = text:find("{", i, true)
                    if not ob then break end
                    local sel = trim(text:sub(i, ob - 1))
                    local depth, j = 1, ob + 1
                    while depth > 0 do
                        local k = text:find("[{}]", j)
                        if not k then j = n + 1 break end
                        if text:byte(k) == 123 then depth = depth + 1 else depth = depth - 1 end
                        j = k + 1
                    end
                    local body = text:sub(ob + 1, j - 2)
                    i = j
                    if sel:sub(1, 1) == "@" then
                        local kfn = sel:match("^@%-?w?e?b?k?i?t?%-?keyframes%s+([%w_%-]+)")
                        if kfn then
                            KF[kfn:lower()] = body
                        elseif sel:find("^@media") then
                            if mediaOk(sel) then addCss(body) end
                        elseif sel:find("^@supports") or sel:find("^@layer") then
                            addCss(body)
                        end
                    end
                    if sel:sub(1, 1) ~= "@" and #rules < 6000 then
                        local isRoot = sel:find(":root", 1, true) ~= nil or sel == "html" or sel == "body" or sel == "*" or sel == "html, body"
                        local decl = parseDecls(body, isRoot)
                        if #decl > 0 then
                            for _, s0 in ipairs(expandSel(sel)) do
                                local s = (trim(s0):gsub(":root", "html"))
                                -- pseudo-elemento ::before / ::after (ou :before / :after da sintaxe antiga)
                                local pe
                                do
                                    local sb, pn = s:match("^(.-)::?(before)$")
                                    if not sb then sb, pn = s:match("^(.-)::?(after)$") end
                                    if sb then
                                        pe = pn
                                        s = trim(sb)
                                        if s == "" then s = "*" end
                                    end
                                end
                                local hov = false
                                if s:find(":hover$") then
                                    hov = true
                                    s = trim((s:gsub(":hover$", "")))
                                end
                                local parts = (not (pe and hov)) and parseSelector(s) or nil
                                if parts then
                                    local last = parts[#parts]
                                    local key = last.id and ("#" .. last.id) or (last.cls[1] and ("." .. last.cls[1])) or last.tag or "*"
                                    if key then
                                        local spec = 0
                                        for _, p in ipairs(parts) do
                                            spec = spec + (p.id and 100 or 0) + #p.cls * 10 + #p.ps * 10 + #p.nots * 10 + #(p.at or {}) * 10 + (p.tag and 1 or 0)
                                        end
                                        order = order + 1
                                        local r = {parts = parts, decl = decl, spec = spec, order = order}
                                        if pe then
                                            r.pe = pe
                                            local pt = idx["@pe"]
                                            if not pt then pt = {}; idx["@pe"] = pt end
                                            if (pt["@n"] or 0) < 1500 then
                                                pt["@n"] = (pt["@n"] or 0) + 1
                                                pt[key] = pt[key] or {}
                                                table.insert(pt[key], r)
                                            end
                                        else
                                            local target = hov and hidx or idx
                                            target[key] = target[key] or {}
                                            table.insert(target[key], r)
                                            if not hov then rules[#rules + 1] = r end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            setStatus("baixando estilos…")
            -- Carrega CSS externo e @import em profundidade limitada. Isso melhora temas
            -- modernos sem permitir que uma página dispare downloads ilimitados.
            local cssSeen, cssCount = {}, 0
            local function loadCss(url, depth)
                if not url or depth > 2 or cssCount >= 10 or cssSeen[url] then return end
                cssSeen[url] = true
                cssCount = cssCount + 1
                local okG, body = pcall(U.httpGet, url)
                if not alive() then return end
                if not okG or type(body) ~= "string" or #body > 600000 then return end
                local imports = {}
                for u in body:gmatch("@import%s+url%(%s*['\"]?(.-)['\"]?%s*%)") do
                    if u ~= "" then imports[#imports + 1] = u end
                end
                for u in body:gmatch("@import%s+['\"](.-)['\"]") do
                    if u ~= "" then imports[#imports + 1] = u end
                end
                for _, imp in ipairs(imports) do
                    if cssCount >= 10 then break end
                    loadCss(U.resolve(url, imp), depth + 1)
                end
                addCss(body)
            end
            for i, href in ipairs(sheets) do
                if i > 6 then break end
                loadCss(U.resolve(docBase, href), 0)
                if not alive() then return end
            end
            for _, t in ipairs(styleTexts) do addCss(t) end
            if not alive() then return end

            local stopped = false
            local B = {el = 0, max = 3500, cut = false}
            local function tick()
                B.el = B.el + 1
                if B.el > B.max then stopped = true; B.cut = true return end
                if B.el % 25 == 0 then
                    task.wait()
                    if not alive() then stopped = true end
                end
            end

            local styleFor
            styleFor = function(node)
                if node.st then return node.st end
                local par = node.parent
                local ps = BASE
                if par and par.tag ~= "#root" then ps = par.st or styleFor(par) end
                local st = {color = ps.color, size = ps.size, bold = ps.bold, italic = ps.italic, under = ps.under, strike = ps.strike, align = ps.align, mono = ps.mono, lh = ps.lh, font = ps.font, tt = ps.tt, lsn = ps.lsn, nowrap = ps.nowrap}
                local tag = node.tag
                if tag:match("^h[1-6]$") then
                    local f = ({h1 = 2, h2 = 1.5, h3 = 1.17, h4 = 1, h5 = 0.83, h6 = 0.67})[tag]
                    local m = ({h1 = 0.67, h2 = 0.83, h3 = 1, h4 = 1.33, h5 = 1.67, h6 = 2.33})[tag]
                    st.size = math.min(54, ps.size * f)
                    st.bold = true
                    st.mt = st.size * m
                    st.mb = st.mt
                elseif tag == "b" or tag == "strong" or tag == "th" then st.bold = true
                elseif tag == "i" or tag == "em" or tag == "cite" or tag == "dfn" or tag == "var" then st.italic = true
                elseif tag == "u" or tag == "ins" then st.under = true
                elseif tag == "s" or tag == "strike" or tag == "del" then st.strike = true
                elseif tag == "small" then st.size = ps.size * 0.85
                elseif tag == "code" or tag == "kbd" or tag == "samp" or tag == "tt" or tag == "pre" then st.mono = true
                elseif tag == "a" then st.color = U.dk(Color3.fromRGB(0, 0, 238), "fg"); st.under = true
                elseif tag == "center" then st.align = "center"
                elseif tag == "blockquote" then st.mt = st.size; st.mb = st.size; st.pl = 30
                elseif tag == "p" or tag == "dl" or tag == "figure" or tag == "fieldset" then st.mt = st.size; st.mb = st.size
                elseif tag == "ul" or tag == "ol" then
                    local nested = node.parent and node.parent.tag == "li"
                    st.mt = nested and 0 or st.size
                    st.mb = st.mt
                    st.pl = 30
                elseif tag == "dd" then st.pl = 30
                elseif tag == "hr" then st.mt = st.size * 0.5; st.mb = st.mt
                elseif tag == "mark" then st.bg = U.dk(Color3.fromRGB(255, 240, 120), "bg")
                end
                local at = node.attrs
                -- Defaults semânticos leves para controles HTML sem CSS explícito.
                if tag == "button" or tag == "input" or tag == "select" then
                    st.radius = st.radius or 5
                    st.pt = st.pt or 6; st.pb = st.pb or 6
                    st.pl = st.pl or 8; st.pr = st.pr or 8
                    if not st.bg then st.bg = U.dk(Color3.fromRGB(242, 244, 247), "bg") end
                end
                if at.bgcolor then st.bg = U.dk(parseColor(at.bgcolor), "bg") end
                if at.color and tag == "font" then st.color = U.dk(parseColor(at.color), "fg") or st.color end
                if at.align == "center" or at.align == "right" then st.align = at.align end
                local cand = {}
                local function take(key)
                    local l = idx[key]
                    if l then
                        for _, r in ipairs(l) do
                            if matchRule(node, r.parts) then cand[#cand + 1] = r end
                        end
                    end
                end
                take(tag)
                take("*")
                if at.id then take("#" .. at.id) end
                for c in pairs(classSet(node)) do take("." .. c) end
                table.sort(cand, function(a, b)
                    if a.spec ~= b.spec then return a.spec < b.spec end
                    return a.order < b.order
                end)
                for _, r in ipairs(cand) do
                    for _, d in ipairs(r.decl) do applyDecl(st, d[1], d[2], ps) end
                end
                if at.style then
                    for _, d in ipairs(parseDecls(at.style)) do applyDecl(st, d[1], d[2], ps) end
                end
                if st.opacity == 0 and not st.anim and not hasImgTag(node, 0) and not st.bgimg then st.display = "none" end
                local hc = {}
                local function takeH(key)
                    local l = hidx[key]
                    if l then
                        for _, r in ipairs(l) do
                            if matchRule(node, r.parts) then hc[#hc + 1] = r end
                        end
                    end
                end
                takeH(tag)
                takeH("*")
                if at.id then takeH("#" .. at.id) end
                for c in pairs(classSet(node)) do takeH("." .. c) end
                if #hc > 0 then
                    table.sort(hc, function(a, b)
                        if a.spec ~= b.spec then return a.spec < b.spec end
                        return a.order < b.order
                    end)
                    local hs = {}
                    for k2, v2 in pairs(st) do hs[k2] = v2 end
                    for _, r in ipairs(hc) do
                        for _, d in ipairs(r.decl) do applyDecl(hs, d[1], d[2], st) end
                    end
                    node.hov = hs
                end
                node.st = st
                return st
            end

            -- utilitários de árvore
            local function textOf(node, cap)
                local out, len = {}, 0
                local function rec(n)
                    for _, k in ipairs(n.kids or {}) do
                        if len >= cap then return end
                        if k.text then
                            local t = k.text:gsub("%s+", " ")
                            out[#out + 1] = t
                            len = len + #t
                        elseif not SKIP[k.tag] then rec(k) end
                    end
                end
                rec(node)
                return trim(table.concat(out)):sub(1, cap)
            end
            local function textLen(node, cap)
                local len = 0
                local function rec(n)
                    for _, k in ipairs(n.kids or {}) do
                        if len >= cap then return end
                        if k.text then
                            if k.text:find("%S") then len = len + #(k.text:gsub("%s+", " ")) end
                        elseif not SKIP[k.tag] then rec(k) end
                    end
                end
                rec(node)
                return len
            end
            local function hasTag(node, tags, depth)
                if depth > 3 then return false end
                for _, k in ipairs(node.kids or {}) do
                    if k.tag and not SKIP[k.tag] then
                        if tags[k.tag] or hasTag(k, tags, depth + 1) then return true end
                    end
                end
                return false
            end
            local BLOCKONLY = tset("div p h1 h2 h3 h4 h5 h6 ul ol li table section article header footer nav main aside form blockquote pre")
            local IMGLIKE = tset("img table input button textarea ul ol")
            local function hasBlock(node) return hasTag(node, BLOCKONLY, 0) end
            local function hiddenClass(node)
                local c = node.attrs.class
                return c ~= nil and (c:find("sr%-only") or c:find("visually%-hidden") or c:find("screen%-reader") or c:find("d%-none")) ~= nil
            end
            local function resolveHref(h)
                if not h or h == "" then return nil end
                return U.resolve(docBase, h)
            end
            local function wrapRich(t, s, base)
                if t == "" then return t end
                if s.strike then t = "<s>" .. t .. "</s>" end
                if s.under then t = "<u>" .. t .. "</u>" end
                if s.italic then t = "<i>" .. t .. "</i>" end
                if s.bold then t = "<b>" .. t .. "</b>" end
                local sz = ""
                if math.abs(s.size - base) > 0.6 then sz = ' size="' .. math.floor(s.size + 0.5) .. '"' end
                return '<font color="' .. hexOf(s.color) .. '"' .. sz .. ">" .. t .. "</font>"
            end

            -- ::before / ::after: so texto (content: "..", attr(x), open-quote/close-quote, escapes \201C).
            -- Icon-fonts (area privada \E000-\F8FF) nao existem no Roblox: so alguns glifos comuns sao mapeados.
            local FAICON = {f054 = "\u{203A}", f105 = "\u{203A}", f053 = "\u{2039}", f104 = "\u{2039}", f101 = "\u{00BB}", f100 = "\u{00AB}", f067 = "+", f068 = "-", f111 = "\u{25CF}"}
            local function pseudoContent(val, node)
                local lv = trim(val):lower()
                if lv == "none" or lv == "normal" or lv == "" then return nil end
                local out, i, n = {}, 1, #val
                while i <= n do
                    local ch = val:sub(i, i)
                    if ch == '"' or ch == "'" then
                        local j, buf = i + 1, {}
                        while j <= n do
                            local cj = val:sub(j, j)
                            if cj == "\\" then
                                local hex = val:match("^%x%x?%x?%x?%x?%x?", j + 1)
                                if hex then
                                    local cp = tonumber(hex, 16)
                                    j = j + 1 + #hex
                                    if val:sub(j, j):match("%s") then j = j + 1 end
                                    local mapped = FAICON[hex:lower()]
                                    if mapped then
                                        buf[#buf + 1] = mapped
                                    elseif cp and cp > 0 and cp < 0x110000 and not (cp >= 0xD800 and cp <= 0xDFFF) and not (cp >= 0xE000 and cp <= 0xF8FF) then
                                        buf[#buf + 1] = utf8.char(cp)
                                    end
                                else
                                    buf[#buf + 1] = val:sub(j + 1, j + 1)
                                    j = j + 2
                                end
                            elseif cj == ch then
                                break
                            else
                                buf[#buf + 1] = cj
                                j = j + 1
                            end
                        end
                        out[#out + 1] = table.concat(buf)
                        i = j + 1
                    elseif ch:find("%s") then
                        i = i + 1
                    else
                        local fn, arg, e = val:match("^([%a%-]+)%((.-)%)()", i)
                        if fn then
                            if fn:lower() == "attr" then
                                out[#out + 1] = tostring(node.attrs[trim(arg):lower()] or "")
                            end
                            i = e
                        else
                            local w, e2 = val:match("^([%a%-]+)()", i)
                            if w then
                                w = w:lower()
                                if w == "open-quote" then out[#out + 1] = "\u{201C}"
                                elseif w == "close-quote" then out[#out + 1] = "\u{201D}" end
                                i = e2
                            else
                                i = i + 1
                            end
                        end
                    end
                end
                local txt = table.concat(out)
                if #txt > 240 then txt = txt:sub(1, 240) end
                if txt == "" then return nil end
                return txt
            end

            local function pseudoRich(node, which, ost, base)
                local pt = idx["@pe"]
                if not pt or not node.tag or not node.attrs then return nil end
                local cache = node.pseR
                if not cache then cache = {}; node.pseR = cache end
                local ck = cache[which]
                if ck ~= nil then return ck or nil end
                cache[which] = false
                local cand = {}
                local function take(key)
                    local l = pt[key]
                    if l then
                        for _, r in ipairs(l) do
                            if r.pe == which and matchRule(node, r.parts) then cand[#cand + 1] = r end
                        end
                    end
                end
                take(node.tag)
                take("*")
                if node.attrs.id then take("#" .. node.attrs.id) end
                for c in pairs(classSet(node)) do take("." .. c) end
                if #cand == 0 then return nil end
                table.sort(cand, function(a, b)
                    if a.spec ~= b.spec then return a.spec < b.spec end
                    return a.order < b.order
                end)
                local pst = {color = ost.color, size = ost.size, bold = ost.bold, italic = ost.italic, under = ost.under, strike = ost.strike, align = ost.align, mono = ost.mono, lh = ost.lh, font = ost.font, tt = ost.tt, lsn = ost.lsn, nowrap = ost.nowrap}
                local content
                for _, r in ipairs(cand) do
                    for _, d in ipairs(r.decl) do
                        if d[1] == "content" then content = d[2]
                        else applyDecl(pst, d[1], d[2], ost) end
                    end
                end
                if not content then return nil end
                if content:find("var%(") then content = subVars(content) end
                if pst.display == "none" or pst.pos == "absolute" or pst.pos == "fixed" then return nil end
                local txt = pseudoContent(content, node)
                if not txt then return nil end
                if pst.tt == "uppercase" then txt = txt:upper()
                elseif pst.tt == "lowercase" then txt = txt:lower() end
                local blk = pst.display == "block" or pst.display == "flex" or pst.display == "grid" or pst.display == "list-item"
                local res = {rich = wrapRich(U.esc(txt), pst, base), blk = blk, vis = txt:find("%S") ~= nil}
                cache[which] = res
                return res
            end

            local function place(ctx, inst)
                if ctx.gap and ctx.gap > 0.5 then
                    local sp = Instance.new("Frame")
                    sp.BackgroundTransparency = 1
                    sp.BorderSizePixel = 0
                    sp.Size = UDim2.new(1, 0, 0, ctx.gap)
                    sp.LayoutOrder = ctx.n + 1
                    sp.Parent = ctx.inst
                end
                ctx.gap = nil
                ctx.n = ctx.n + 2
                inst.LayoutOrder = ctx.n
                inst.Parent = ctx.inst
            end
            local function stroke(parent, color, th)
                local s = Instance.new("UIStroke")
                s.Color = color
                s.Thickness = th or 1
                s.Parent = parent
            end

            local TOG, idMap = {}, {}
            local function scanToggles(n, depth)
                if depth > 60 then return end
                local at = n.attrs
                if at then
                    local t = at["data-bs-target"] or at["data-target"] or at["aria-controls"]
                    if t then
                        for id in t:gmatch("[%w_%-]+") do TOG[id] = true end
                    end
                    local oc = at.onclick
                    if oc then
                        for id in oc:gmatch("getElementById%(%s*['\"]([%w_%-]+)") do TOG[id] = true end
                    end
                    local hf = at.href
                    if hf then
                        local id = hf:match("^#([%w_%-]+)$")
                        if id then TOG[id] = true end
                    end
                end
                for _, k in ipairs(n.kids or {}) do
                    if k.tag then scanToggles(k, depth + 1) end
                end
            end
            scanToggles(root, 0)

            local function scrollToInst(f)
                local sf = canvas:FindFirstAncestorOfClass("ScrollingFrame")
                if sf and f then
                    sf.CanvasPosition = Vector2.new(0, math.max(0, f.AbsolutePosition.Y - sf.AbsolutePosition.Y + sf.CanvasPosition.Y - 8))
                end
            end

            local function actionFor(node)
                local at = node.attrs
                if not at then return nil end
                local oc = at.onclick or ""
                local nav = oc:match("location[%.%w]*%s*=%s*['\"]([^'\"]+)['\"]") or oc:match("location%.assign%(%s*['\"]([^'\"]+)") or oc:match("window%.open%(%s*['\"]([^'\"]+)") or at["data-href"] or at["data-url"] or at.formaction
                local tid = at["data-bs-target"] or at["data-target"] or at["aria-controls"] or oc:match("getElementById%(%s*['\"]([%w_%-]+)") or (at.href and at.href:match("^#([%w_%-]+)$")) or ""
                tid = tid:match("([%w_%-]+)") or ""
                if nav then
                    local url = U.resolve(docBase, nav)
                    if url then return function() navigate(tabs[cur], {url = url}) end end
                end
                if tid ~= "" and TOG[tid] then
                    local isAnchor = node.tag == "a" and at.href and at.href:sub(1, 1) == "#"
                    return function()
                        local f = idMap[tid]
                        if not f then return end
                        if isAnchor and f.Visible then
                            scrollToInst(f)
                        else
                            f.Visible = not f.Visible
                            if f.Visible then scrollToInst(f) end
                        end
                    end
                end
                return nil
            end

            local renderChildren, renderBlock, makeBox, renderBlockInner, queueBgImage
            local alignOf = {left = Enum.TextXAlignment.Left, center = Enum.TextXAlignment.Center, right = Enum.TextXAlignment.Right}

            local function applyAnim(f, a, isGroup)
                local kf = KF[a.name]
                if not kf then return end
                local fade = kf:find("opacity") ~= nil
                local spin = kf:find("rotate") ~= nil
                if a.inf then
                    if spin then
                        TweenService:Create(f, TweenInfo.new(a.dur, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360}):Play()
                    elseif fade and isGroup then
                        TweenService:Create(f, TweenInfo.new(a.dur / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {GroupTransparency = 0.55}):Play()
                    end
                elseif fade and isGroup then
                    f.GroupTransparency = 1
                    task.delay(a.delay, function()
                        if f.Parent then
                            TweenService:Create(f, TweenInfo.new(a.dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
                        end
                    end)
                end
            end

            local function attachHover(f, st, hov)
                if not hov.bg then return end
                local ti = TweenInfo.new(st.trans or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                local baseC, baseT = f.BackgroundColor3, f.BackgroundTransparency
                f.MouseEnter:Connect(function()
                    TweenService:Create(f, ti, {BackgroundColor3 = hov.bg, BackgroundTransparency = 1 - (hov.bga or 1) * (hov.opacity or 1)}):Play()
                end)
                f.MouseLeave:Connect(function()
                    TweenService:Create(f, ti, {BackgroundColor3 = baseC, BackgroundTransparency = baseT}):Play()
                end)
            end

            local function pressFx(b)
                local sc = Instance.new("UIScale")
                sc.Parent = b
                b.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        TweenService:Create(sc, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.96}):Play()
                    end
                end)
                b.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
                    end
                end)
            end

            makeBox = function(ctx, st, opts)
                opts = opts or {}
                local auto = opts.auto or ctx.auto
                local kf = st.anim and KF[st.anim.name]
                local group = (kf and kf:find("opacity") and not kf:find("rotate") and not st.bgimg) and true or false
                local click = (opts.href or opts.act) and not group
                local f = Instance.new(st.bgimg and (click and "ImageButton" or "ImageLabel") or (group and "CanvasGroup" or (click and "TextButton" or "Frame")))
                if click then
                    f.AutoButtonColor = false
                    if f:IsA("TextButton") then f.Text = "" end
                    f.MouseButton1Click:Connect(function()
                        if opts.act then opts.act()
                        elseif opts.href then navigate(tabs[cur], {url = opts.href}) end
                    end)
                end
                local nid = opts.node and opts.node.attrs and opts.node.attrs.id
                if nid and TOG[nid] then idMap[nid] = f end
                if st._hide then f.Visible = false end
                f.BorderSizePixel = 0
                f.ZIndex = 4
                local barW = st.bl and math.max(1, st.bl.w) or 0
                local sx
                local wcap
                if opts.fill then
                    sx = UDim2.new(1 / math.max(1, opts.fillN or 2), -4, 0, 0)
                elseif opts.colW then
                    sx = opts.colW
                elseif auto then
                    sx = UDim2.new(0, 0, 0, 0)
                elseif st.w and st.w[2] then
                    sx = UDim2.new(st.w[2], st.w[1] or 0, 0, 0)
                elseif st.w and st.w[1] and st.w[1] < AVAILW then
                    sx = UDim2.new(1, 0, 0, 0)
                    wcap = st.w[1]
                else
                    sx = UDim2.new(1, 0, 0, 0)
                end
                f.Size = sx
                if opts.aspect and (opts.auto or ctx.auto) then sx = UDim2.new(0, 120, 0, 0) f.Size = sx end
                f.AutomaticSize = opts.aspect and Enum.AutomaticSize.None or (auto and Enum.AutomaticSize.XY or Enum.AutomaticSize.Y)
                if opts.aspect then
                    local arc = Instance.new("UIAspectRatioConstraint")
                    arc.AspectRatio = opts.aspect
                    arc.Parent = f
                end
                local minH = (st.h and st.h[1]) or (st.minh and st.minh[1])
                if st.h and st.h[1] and st.minh and st.minh[1] then minH = math.max(st.h[1], st.minh[1]) end
                if st.bgimg and not minH and not opts.aspect then minH = 110 end
                local maxW = st.maxw and st.maxw[1]
                if wcap then maxW = maxW and math.min(maxW, wcap) or wcap end
                if (minH and minH > 0) or (maxW and not auto) then
                    local sc = Instance.new("UISizeConstraint")
                    sc.MinSize = Vector2.new(0, minH or 0)
                    sc.MaxSize = Vector2.new((maxW and not auto) and maxW or math.huge, math.huge)
                    sc.Parent = f
                end
                if auto then
                    local sc1 = f:FindFirstChildOfClass("UISizeConstraint")
                    if not sc1 then
                        sc1 = Instance.new("UISizeConstraint")
                        sc1.Parent = f
                    end
                    sc1.MaxSize = Vector2.new(math.min(sc1.MaxSize.X, AVAILW), sc1.MaxSize.Y)
                end
                local centerAuto = st.ml == "auto" and (wcap or (st.maxw and st.maxw[1]) or (st.w and st.w[2] and st.w[2] < 1)) and true or false
                if st.bg then
                    f.BackgroundColor3 = st.bg
                    f.BackgroundTransparency = 1 - (st.bga or 1) * (st.opacity or 1)
                else
                    f.BackgroundTransparency = 1
                end
                if st.grad and st.bg then applyGrad(f, st.grad) end
                if st.bgimg then
                    f.ScaleType = (st.bgfit == "contain") and Enum.ScaleType.Fit or Enum.ScaleType.Crop
                    local url = U.resolve(docBase, st.bgimg)
                    if url and queueBgImage then queueBgImage(f, url) end
                end
                local lay = Instance.new("UIListLayout")
                lay.SortOrder = Enum.SortOrder.LayoutOrder
                local layoutGap = (opts.row and (st.colgap or st.gap)) or (st.rowgap or st.gap) or 0
                lay.Padding = UDim.new(0, layoutGap)
                local H, V = Enum.HorizontalAlignment, Enum.VerticalAlignment
                local function hz(v)
                    if v == "center" then return H.Center elseif v == "flex-end" or v == "end" or v == "right" then return H.Right end
                    return H.Left
                end
                local function vt(v)
                    if v == "center" then return V.Center elseif v == "flex-end" or v == "end" then return V.Bottom end
                    return V.Top
                end
                local flexy = st.display == "flex" or st.display == "inline-flex"
                local rowdir = flexy and st.dir ~= "column"
                if opts.row then
                    lay.FillDirection = Enum.FillDirection.Horizontal
                    lay.Wraps = opts.wraps ~= false
                    lay.HorizontalAlignment = hz(st.jc)
                    lay.VerticalAlignment = vt(st.ai)
                    if (st.jc == "space-between" or st.jc == "space-around" or st.jc == "space-evenly") and not lay.Wraps then
                        pcall(function()
                            lay.HorizontalFlex = (st.jc == "space-between") and Enum.UIFlexAlignment.SpaceBetween or ((st.jc == "space-around") and Enum.UIFlexAlignment.SpaceAround or Enum.UIFlexAlignment.SpaceEvenly)
                        end)
                    end
                elseif flexy and rowdir then
                    lay.HorizontalAlignment = hz(st.jc)
                    lay.VerticalAlignment = vt(st.ai)
                elseif flexy then
                    lay.HorizontalAlignment = hz(st.ai)
                    lay.VerticalAlignment = vt(st.jc)
                else
                    if st.align == "center" then lay.HorizontalAlignment = H.Center
                    elseif st.align == "right" then lay.HorizontalAlignment = H.Right end
                end
                if not opts.aspect then lay.Parent = f end
                local pt, pr, pb, pl = st.pt or 0, st.pr or 0, st.pb or 0, st.pl or 0
                if (pt > 0 or pr > 0 or pb > 0 or pl > 0) and not opts.aspect then
                    local pad = Instance.new("UIPadding")
                    pad.PaddingTop = UDim.new(0, pt)
                    pad.PaddingRight = UDim.new(0, pr)
                    pad.PaddingBottom = UDim.new(0, pb)
                    pad.PaddingLeft = UDim.new(0, pl)
                    pad.Parent = f
                end
                if st.radius or st.rs then
                    local r, rs2 = st.radius or 0, st.rs or 0
                    if r > 0 or rs2 > 0 then corner(f, UDim.new(rs2, math.min(r, 500))) end
                end
                if st.b then
                    local sk = Instance.new("UIStroke")
                    sk.Color = st.b.c
                    sk.Thickness = math.max(0.75, st.b.w)
                    sk.Transparency = 1 - (st.b.a or 1)
                    sk.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                    sk.Parent = f
                end
                if st.clip then f.ClipsDescendants = true end
                
                local function edgeLine(b)
                    local l = Instance.new("Frame")
                    l.Size = UDim2.new(1, 0, 0, math.max(1, b.w))
                    l.BackgroundColor3 = b.c
                    l.BackgroundTransparency = 1 - (b.a or 1)
                    l.BorderSizePixel = 0
                    l.ZIndex = 5
                    place(ctx, l)
                end
                if st.bt and not ctx.row then edgeLine(st.bt) end
                local needWrap = barW > 0 or (st.shadow and st.bg and true or false)
                local placed = f
                if needWrap then
                    local outer = Instance.new("Frame")
                    outer.BackgroundTransparency = 1
                    outer.BorderSizePixel = 0
                    outer.Size = sx
                    outer.AutomaticSize = auto and Enum.AutomaticSize.XY or Enum.AutomaticSize.Y
                    outer.ZIndex = 4
                    local sc0 = f:FindFirstChildOfClass("UISizeConstraint")
                    if sc0 and sc0.MaxSize.X < math.huge then
                        local oc = Instance.new("UISizeConstraint")
                        oc.MaxSize = Vector2.new(sc0.MaxSize.X, math.huge)
                        oc.Parent = outer
                    end
                    if st.shadow and st.bg then
                        local shd = st.shadow
                        local pad = math.max(5, (shd.blur or 8) * 0.75)
                        local img = Instance.new("ImageLabel")
                        img.BackgroundTransparency = 1
                        img.Image = "rbxassetid://1316045217"
                        img.ScaleType = Enum.ScaleType.Slice
                        img.SliceCenter = Rect.new(10, 10, 118, 118)
                        img.ImageColor3 = Color3.new(0, 0, 0)
                        img.ImageTransparency = math.clamp(1 - (shd.a or 0.25) * 1.6, 0.55, 0.96)
                        img.Position = UDim2.new(0, -pad, 0, -pad + (shd.y or 0) * 0.75)
                        img.Size = UDim2.new(1, pad * 2, 1, pad * 2)
                        img.ZIndex = 3
                        img.Parent = outer
                    end
                    if barW > 0 then
                        local bar = Instance.new("Frame")
                        bar.Size = UDim2.new(0, barW, 1, 0)
                        bar.BackgroundColor3 = st.bl.c
                        bar.BackgroundTransparency = 1 - (st.bl.a or 1)
                        bar.BorderSizePixel = 0
                        bar.ZIndex = 5
                        bar.Parent = outer
                    end
                    f.Position = UDim2.new(0, barW, 0, 0)
                    f.Size = auto and UDim2.new(0, 0, 0, 0) or UDim2.new(1, -barW, 0, 0)
                    f.Parent = outer
                    placed = outer
                end
                if opts.fill then
                    pcall(function()
                        local fi = Instance.new("UIFlexItem")
                        fi.FlexMode = Enum.UIFlexMode.Fill
                        fi.Parent = placed
                    end)
                end
                if centerAuto and not ctx.row and not opts.colW and not opts.fill then
                    local cwf = Instance.new("Frame")
                    cwf.BackgroundTransparency = 1
                    cwf.BorderSizePixel = 0
                    cwf.Size = UDim2.new(1, 0, 0, 0)
                    cwf.AutomaticSize = Enum.AutomaticSize.Y
                    cwf.ZIndex = 4
                    local cll = Instance.new("UIListLayout")
                    cll.SortOrder = Enum.SortOrder.LayoutOrder
                    cll.HorizontalAlignment = (st.mr == "auto") and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Right
                    cll.Parent = cwf
                    placed.Parent = cwf
                    placed = cwf
                end
                place(ctx, placed)
                if st.bb and not ctx.row then edgeLine(st.bb) end
                if opts.node and opts.node.hov and not st.grad then attachHover(f, st, opts.node.hov) end
                if click and (st.bg or st.b) then pressFx(f) end
                if st.anim then applyAnim(f, st.anim, group) end
                if opts.aspect then
                    local ov = Instance.new("Frame")
                    ov.BackgroundTransparency = 1
                    ov.BorderSizePixel = 0
                    ov.Size = UDim2.new(1, 0, 1, 0)
                    ov.ZIndex = 6
                    local ovl = Instance.new("UIListLayout")
                    ovl.SortOrder = Enum.SortOrder.LayoutOrder
                    ovl.Parent = ov
                    ov.Parent = f
                    return {inst = ov, n = 0, lay = ovl, fillTarget = f}
                end
                return {inst = f, n = 0, auto = auto or nil, lay = lay, row = opts.row}
            end

            local function makeText(ctx, buf, st)
                local nlinks = #buf.links
                local l = Instance.new(nlinks > 0 and "TextButton" or "TextLabel")
                l.BackgroundTransparency = 1
                l.BorderSizePixel = 0
                l.RichText = true
                l.Text = buf.rich
                l.TextSize = st.size
                l.TextColor3 = st.color
                l.Font = st.font or (st.mono and Enum.Font.Code or Enum.Font.Gotham)
                l.TextXAlignment = alignOf[st.align] or Enum.TextXAlignment.Left
                l.TextYAlignment = Enum.TextYAlignment.Top
                l.LineHeight = st.lh and math.clamp(st.lh, 1, 3) or 1.15
                l.ZIndex = 5
                if ctx.auto then
                    l.TextWrapped = not st.nowrap
                    l.Size = UDim2.new(0, 0, 0, 0)
                    l.AutomaticSize = Enum.AutomaticSize.XY
                    local tcap = Instance.new("UISizeConstraint")
                    tcap.MaxSize = Vector2.new(math.max(40, AVAILW - 2), math.huge)
                    tcap.Parent = l
                else
                    l.TextWrapped = true
                    l.Size = UDim2.new(1, 0, 0, 0)
                    l.AutomaticSize = Enum.AutomaticSize.Y
                    if st.nowrap then l.TextWrapped = false end
                    if st.ell then l.TextTruncate = Enum.TextTruncate.AtEnd end
                end
                place(ctx, l)
                if nlinks > 0 then
                    l.AutoButtonColor = false
                    local chooser
                    l.MouseButton1Click:Connect(function()
                        if nlinks == 1 then
                            local l1 = buf.links[1]
                            if l1.act then l1.act() else navigate(tabs[cur], {url = l1.href}) end
                            return
                        end
                        if chooser and chooser.Parent then chooser:Destroy() chooser = nil return end
                        chooser = Instance.new("Frame")
                        chooser.Size = UDim2.new(1, 0, 0, 0)
                        chooser.AutomaticSize = Enum.AutomaticSize.Y
                        chooser.BackgroundColor3 = U.dk(Color3.fromRGB(238, 241, 247), "bg")
                        chooser.BorderSizePixel = 0
                        chooser.ZIndex = 5
                        chooser.LayoutOrder = l.LayoutOrder + 1
                        corner(chooser, UDim.new(0, 8))
                        local cl = Instance.new("UIListLayout")
                        cl.SortOrder = Enum.SortOrder.LayoutOrder
                        cl.Padding = UDim.new(0, 2)
                        cl.Parent = chooser
                        local cp = Instance.new("UIPadding")
                        cp.PaddingTop = UDim.new(0, 4); cp.PaddingBottom = UDim.new(0, 4)
                        cp.PaddingLeft = UDim.new(0, 6); cp.PaddingRight = UDim.new(0, 6)
                        cp.Parent = chooser
                        for i, lk in ipairs(buf.links) do
                            if i > 10 then break end
                            local b = Instance.new("TextButton")
                            b.LayoutOrder = i
                            b.Size = UDim2.new(1, 0, 0, 22)
                            b.BackgroundTransparency = 1
                            b.Text = "→ " .. ((lk.label and lk.label ~= "") and lk.label or U.hostOf(lk.href))
                            b.TextColor3 = U.dk(Color3.fromRGB(26, 85, 204), "fg")
                            b.Font = Enum.Font.Gotham
                            b.TextSize = 11
                            b.TextXAlignment = Enum.TextXAlignment.Left
                            b.TextTruncate = Enum.TextTruncate.AtEnd
                            b.ZIndex = 6
                            b.Parent = chooser
                            b.MouseButton1Click:Connect(function() if lk.act then lk.act() else navigate(tabs[cur], {url = lk.href}) end end)
                        end
                        chooser.Parent = ctx.inst
                    end)
                end
            end
            -- imagens (fila com 3 downloads simultâneos)
            local imgQ, imgActive, imgTotal = {}, 0, 0
            -- Imagens responsivas: recalculadas quando o viewport/canvas muda,
            -- sem observar o tamanho do próprio cartão (evita ciclos de redução).
            local responsiveImageJobs = {}
            local responsiveRefreshQueued = false
            local function refreshResponsiveImages()
                if responsiveRefreshQueued then return end
                responsiveRefreshQueued = true
                task.defer(function()
                    responsiveRefreshQueued = false
                    if not alive() then return end
                    local scaleNow = math.max(0.1, totScale())
                    local canvasW = math.max(1, canvas.AbsoluteSize.X / scaleNow)
                    local localW = math.clamp(canvasW, 160, 600)
                    local availNow = math.max(140, localW - 14)
                    AVAILW = availNow
                    VW = math.max(280, math.floor(localW / 0.75))
                    for i = #responsiveImageJobs, 1, -1 do
                        local job = responsiveImageJobs[i]
                        local img = job.img
                        if not img or not img.Parent then
                            table.remove(responsiveImageJobs, i)
                        else
                            local target = math.min(job.intrinsicW or availNow, availNow * (job.layoutRatio or 1))
                            if job.cssWidthPct then
                                target = math.min(availNow * job.cssWidthPct + (job.cssWidthOffset or 0), availNow)
                            elseif job.cssWidthPx then
                                target = math.min(job.cssWidthPx, availNow)
                            end
                            -- Usa a proporção inicial do cartão em relação à página.
                            -- Não mede o pai novamente: isso evita realimentação de AutoSize
                            -- que fazia algumas imagens encolherem progressivamente.
                            target = math.max(8, target)
                            local height = job.fixedHeight or (job.fixedAspect and (target / job.fixedAspect)) or (target * (job.ratio or 0.6875))
                            if math.abs(img.Size.X.Offset - target) > 1 or math.abs(img.Size.Y.Offset - height) > 1 then
                                img.Size = UDim2.new(0, target, 0, height)
                            end
                        end
                    end
                end)
            end
            canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshResponsiveImages)
            local pumpImages
            pumpImages = function()
                while imgActive < 4 and #imgQ > 0 do
                    local job = table.remove(imgQ, 1)
                    imgActive = imgActive + 1
                    task.spawn(function()
                        local ok, a = pcall(U.cacheImage, job.url, 6000000, job.referer or entry.url)
                        imgActive = imgActive - 1
                        if alive() and job.img.Parent then
                            if job.bg or job.fill then
                                if ok and a then
                                    job.img.Image = a
                                    job.img.BackgroundTransparency = 1
                                    for _, child in ipairs(job.img:GetChildren()) do
                                        if child.Name == "ImageFallback" or child.Name == "ImageLoadingPlaceholder" then child:Destroy() end
                                    end
                                end
                            elseif ok and a then
 local w, h = U.dimsFor(job.url)
                                local aw, ah = job.aw, job.ah
                                if not w or not h then w, h = aw or 160, ah or 110 end
                                local availW = math.min(AVAILW, math.max(40, ((job.img.Parent.AbsoluteSize.X > 0 and job.img.Parent.AbsoluteSize.X or canvas.AbsoluteSize.X) / totScale()) - 4))
                                local dw = math.min(availW, math.max(8, (aw or w) * 0.75))
                                local sw, sh = job.sw, job.sh
                                if sw then
                                    if sw[2] then dw = availW * sw[2] + (sw[1] or 0) elseif sw[1] then dw = math.min(availW, sw[1]) end
                                end
                                local dh = math.min(900, dw * h / w)
                                if job.ar then
                                    dh = dw / job.ar
                                    job.img.ScaleType = Enum.ScaleType.Crop
                                end
                                if sh and sh[1] then dh = sh[1] end
                                if job.fit == "cover" then job.img.ScaleType = Enum.ScaleType.Crop
                                elseif job.fit == "fill" then job.img.ScaleType = Enum.ScaleType.Stretch
                                else job.img.ScaleType = Enum.ScaleType.Fit end
                                job.img.Size = UDim2.new(0, dw, 0, dh)
                                job.img.Image = a
                                -- A miniatura carregada não deve manter o fundo de preenchimento.
                                job.img.BackgroundTransparency = 1
                                for _, child in ipairs(job.img:GetChildren()) do
                                    if child.Name == "ImageFallback" or child.Name == "ImageLoadingPlaceholder" then child:Destroy() end
                                end
                                local imgRatio = dh / math.max(1, dw)
                                local intrinsicW = math.min(900, math.max(8, (aw or w) * 0.75))
                                local cssWidthPct, cssWidthOffset, cssWidthPx = nil, nil, nil
                                if sw then
                                    if sw[2] then
                                        cssWidthPct = sw[2]
                                        cssWidthOffset = sw[1] or 0
                                    elseif sw[1] then
                                        cssWidthPx = sw[1]
                                    end
                                end
                                responsiveImageJobs[#responsiveImageJobs + 1] = {
                                    img = job.img,
                                    ratio = imgRatio,
                                    intrinsicW = intrinsicW,
                                    layoutRatio = math.clamp(dw / math.max(1, AVAILW), 0.08, 1),
                                    cssWidthPct = cssWidthPct,
                                    cssWidthOffset = cssWidthOffset,
                                    cssWidthPx = cssWidthPx,
                                    fixedHeight = (sh and sh[1]) and sh[1] or nil,
                                    fixedAspect = job.ar or nil
                                }
                                task.defer(refreshResponsiveImages)
                            else
                                -- Falha silenciosa: não desenha cartão cinza nem texto sobre a página.
                                -- Preserva a geometria já reservada pelo layout para evitar deslocar
                                -- os elementos seguintes quando uma imagem não puder ser obtida.
                                job.img.Visible = true
                                job.img.Image = ""
                                job.img.BackgroundTransparency = 1
                                for _, child in ipairs(job.img:GetChildren()) do
                                    if child.Name == "ImageFallback" or child.Name == "ImageLoadingPlaceholder" then
                                        child:Destroy()
                                    end
                                end
                            end
                        end
                        pumpImages()
                    end)
                end
            end

            queueBgImage = function(inst, url)
                imgQ[#imgQ + 1] = {img = inst, url = url, bg = true, referer = entry.url}
                pumpImages()
            end

            local function renderImage(ctx, node, st, href)
                local at = node.attrs
                local src = at["data-src"] or at["data-original"] or at["data-lazy-src"] or at["data-lazy"] or at["data-original-src"] or at["data-image"] or at["data-img"] or at["data-image-src"] or at["data-full"] or at["data-hi-res-src"] or at["data-thumb"] or at["data-thumbnail"] or at["data-thumb-src"] or at["data-preview"] or at["data-src-hq"] or at["data-fallback-src"] or at["data-url"] or at.src
                local srcset = at["data-srcset"] or at["data-lazy-srcset"] or at["data-original-srcset"] or at["data-src-set"] or at["data-lazy-src-set"] or at.srcset
                -- <picture><source srcset=...><img ...></picture>: usa a fonte responsiva mais adequada.
                if node.parent and node.parent.tag == "picture" then
                    for _, sibling in ipairs(node.parent.kids or {}) do
                        if sibling.tag == "source" and sibling.attrs then
                            local media = (sibling.attrs.media or ""):lower()
                            local mediaOk = media == "" or (media:find("max%-width") and AVAILW <= (tonumber(media:match("([%d%.]+)px")) or AVAILW)) or (media:find("min%-width") and AVAILW >= (tonumber(media:match("([%d%.]+)px")) or AVAILW))
                            if mediaOk and (sibling.attrs.srcset or sibling.attrs["data-srcset"]) then
                                srcset = sibling.attrs["data-srcset"] or sibling.attrs.srcset
                                break
                            end
                        end
                    end
                end
                if srcset and srcset ~= "" then
                    -- srcset e <picture> tem prioridade sobre src de baixa resolucao,
                    -- como acontece em navegadores: escolhe a variante adequada ao celular.
                    local candidates, bestUrl, bestW, largestUrl, largestW = {}, nil, math.huge, nil, 0
                    for item in srcset:gmatch("[^,]+") do
                        local u, desc = item:match("^%s*(%S+)%s*(.-)%s*$")
                        local w = desc and tonumber(desc:match("([%d%.]+)w"))
                        local d = desc and tonumber(desc:match("([%d%.]+)x"))
                        local score = w or ((d or 1) * AVAILW)
                        if u and u ~= "" and u:sub(1, 5) ~= "data:" then
                            if score > largestW then largestW, largestUrl = score, u end
                            if score >= AVAILW and score < bestW then bestW, bestUrl = score, u end
                        end
                    end
                    src = bestUrl or largestUrl or srcset:match("^%s*(%S+)")
                end
                if not src or src == "" or src:sub(1, 5) == "data:" then return end
                local url = U.resolve(docBase, src)
                if not url then return end
                local aw = tonumber((at.width or ""):match("^%d+"))
                local ah = tonumber((at.height or ""):match("^%d+"))
                if aw and aw <= 2 then return end
                imgTotal = imgTotal + 1
                -- Sem limite fixo de quantidade: permite listar todas as imagens encontradas na pagina.
                local img = Instance.new("ImageButton")
                img.AutoButtonColor = false
                img.BackgroundColor3 = U.dk(Color3.fromRGB(232, 234, 238), "bg")
                -- Sem bloco cinza permanente: o fundo só é usado como fallback se falhar.
                img.BackgroundTransparency = 1
                img.BorderSizePixel = 0
                local fit = st.objfit or "contain"
                img.ScaleType = (fit == "cover") and Enum.ScaleType.Crop or ((fit == "fill") and Enum.ScaleType.Stretch or Enum.ScaleType.Fit)
                img.Size = UDim2.new(0, 60, 0, 40)
                img.ZIndex = 5
                if ctx.fillTarget then
                    img.Size = UDim2.new(1, 0, 1, 0)
                    img.Position = UDim2.new(0, 0, 0, 0)
                    img.ScaleType = Enum.ScaleType.Crop
                    img.ZIndex = 4
                    img.Parent = ctx.fillTarget
                else
                    place(ctx, img)
                end
                img.MouseButton1Click:Connect(function()
                    if href then navigate(tabs[cur], {url = href})
                    else openImg({url = url, thumb = url, title = at.alt or ""}) end
                end)
                imgQ[#imgQ + 1] = {img = img, url = url, aw = aw, ah = ah, sw = st.w, sh = st.h, ar = st.ar, fill = ctx.fillTarget ~= nil, fit = fit, alt = at.alt or at.title or "", referer = entry.url}
                if st.radius or st.rs then corner(img, UDim.new(st.rs or 0, math.min(st.radius or 0, 500))) end
                pumpImages()
                -- GIFs em paginas tambem podem animar: o Roblox nao reproduz GIF nativamente,
                -- entao decodificamos os quadros para PNG e alternamos duas ImageLabels.
                local lowUrl = url:lower()
                local gifCandidate = lowUrl:match("%.gif([%?#].*)?$") or lowUrl:find("format=gif", 1, true) or lowUrl:find("image/gif", 1, true) or (at.type or ""):lower() == "image/gif"
                if not ctx.fillTarget then
                    -- Muitos CDNs escondem o formato numa URL sem extensao (ex.: /media/abc).
                    -- Aguarda a requisicao normal identificar o MIME/conteudo antes de decidir.
                    task.spawn(function()
                        if not alive() or not img.Parent then return end
                        if not gifCandidate then
                            local waited = 0
                            while alive() and img.Parent and not imgKind[url] and waited < 30 do
                                task.wait(0.15)
                                waited = waited + 0.15
                            end
                            local kind = imgKind[url]
                            gifCandidate = kind == "gif" or kind == "apng" or kind == "webp" or U.gifMeta(url) ~= nil
                        end
                        if not gifCandidate or not alive() or not img.Parent then return end
                        local gifBody = U.gifBody(url, entry.url)
                        if not gifBody then
                            -- APNG/WebP animados: tenta conversao para GIF com mais de um quadro.
                            local okRaw, raw = pcall(U.httpGetImage, url, entry.url)
                            if okRaw and type(raw) == "string" then
                                gifBody = U.animatedImageAsGif(url, entry.url, raw)
                            end
                        end
                        if not gifBody or not alive() or not img.Parent then return end
                        local gifKey = "web_" .. U.hash2(url)
                        local info = Nav.gif.load(gifKey, #gifBody)
                        if not info then
                            info = Nav.gif.bake(gifKey, gifBody, {
                                maxFrames = 24, maxDim = 320, pixelBudget = 18000000,
                                yield = task.wait,
                                cancelled = function() return not alive() or not img.Parent end,
                            }, url:match("([^/]+%.gif)") or gifKey)
                        end
                        if not info or not alive() or not img.Parent or #info.paths < 2 then return end
                        local assets = Nav.gif.assets(info)
                        if not assets or #assets < 2 then return end
                        img.ClipsDescendants = true
                        local over = Instance.new("ImageLabel")
                        over.Name = "WebGifFrameOverlay"
                        over.BackgroundTransparency = 1
                        over.BorderSizePixel = 0
                        over.BorderSizePixel = 0
                        -- Overlay pertence ao proprio <img>: nao cria uma nova linha,
                        -- nao altera LayoutOrder e acompanha qualquer resize responsivo.
                        over.AnchorPoint = Vector2.new(0, 0)
                        over.Position = UDim2.new(0, 0, 0, 0)
                        over.Size = UDim2.new(1, 0, 1, 0)
                        over.AutomaticSize = Enum.AutomaticSize.None
                        over.ZIndex = img.ZIndex + 1
                        over.ScaleType = img.ScaleType
                        over.Parent = img
                        if st.radius or st.rs then corner(over, UDim.new(st.rs or 0, math.min(st.radius or 0, 500))) end
                        local gifPageState = {playing = true, smooth = true}
                        Nav.gif.play(img, over, assets, info.delays, function()
                            return not alive() or not img.Parent or not over.Parent
                        end, gifPageState)
                    end)
                end
            end

            -- formulários
            local function formOf(node)
                local p = node.parent
                while p do
                    if p.tag == "form" then
                        p.fs = p.fs or {inputs = {}}
                        return p
                    end
                    p = p.parent
                end
                return nil
            end
            local function submitForm(form, btn)
                if not form or form.dummy then return end
                local method = (form.attrs.method or "get"):lower()
                if method ~= "get" then toast("Formulário POST não é suportado") return end
                local action = form.attrs.action or ""
                local base = (action ~= "" and U.resolve(docBase, action)) or docBase
                base = base:gsub("#.*$", "")
                local q = {}
                for key, v in pairs(form.fs.inputs) do
                    local nm, val = key, nil
                    if type(v) == "table" then
                        nm = v.name or key
                        if v.get then val = v.get() else val = v.value end
                    else
                        val = v.Text
                    end
                    if val ~= nil then
                        q[#q + 1] = HttpService:UrlEncode(nm) .. "=" .. HttpService:UrlEncode(val)
                    end
                end
                if btn and btn.attrs.name and btn.attrs.name ~= "" then
                    q[#q + 1] = HttpService:UrlEncode(btn.attrs.name) .. "=" .. HttpService:UrlEncode(btn.attrs.value or "")
                end
                local sep = base:find("?", 1, true) and "&" or "?"
                navigate(tabs[cur], {url = base .. (#q > 0 and (sep .. table.concat(q, "&")) or "")})
            end

            local function renderControl(ctx, node, st, href)
                local tag, at = node.tag, node.attrs
                local ty = (at.type or "text"):lower()
                local form = formOf(node) or {dummy = true, attrs = {}, fs = {inputs = {}}}
                
                if tag == "input" and ty == "hidden" then
                    if form and at.name then form.fs.inputs[at.name] = {value = at.value or ""} end
                    return
                end
                if tag == "input" and (ty == "checkbox" or ty == "radio") then
                    local on = at.checked ~= nil
                    local box = Instance.new("TextButton")
                    box.Size = UDim2.new(0, 20, 0, 20)
                    box.BackgroundColor3 = U.dk(Color3.new(1, 1, 1), "bg")
                    box.BorderSizePixel = 0
                    box.Text = ""
                    box.AutoButtonColor = false
                    box.ZIndex = 5
                    corner(box, UDim.new(ty == "radio" and 0.5 or 0.2, 0))
                    stroke(box, Color3.fromRGB(150, 154, 162), 1)
                    local dot = Instance.new("Frame")
                    dot.AnchorPoint = Vector2.new(0.5, 0.5)
                    dot.Position = UDim2.new(0.5, 0, 0.5, 0)
                    dot.Size = UDim2.new(0, 12, 0, 12)
                    dot.BackgroundColor3 = Color3.fromRGB(66, 133, 244)
                    dot.BorderSizePixel = 0
                    dot.ZIndex = 6
                    corner(dot, UDim.new(ty == "radio" and 0.5 or 0.2, 0))
                    dot.Parent = box
                    local function paint() dot.Visible = on end
                    paint()
                    local val = at.value or "on"
                    form.fs.cnt = (form.fs.cnt or 0) + 1
                    local nm = at.name
                    local rec = {setOn = function(v) on = v; paint() end}
                    if ty == "radio" then
                        form.fs.radios = form.fs.radios or {}
                        local grp = form.fs.radios[nm or ""] or {}
                        form.fs.radios[nm or ""] = grp
                        grp[#grp + 1] = rec
                    end
                    if nm and nm ~= "" then
                        form.fs.inputs[nm .. "\0" .. form.fs.cnt] = {name = nm, get = function() if on then return val end return nil end}
                    end
                    box.MouseButton1Click:Connect(function()
                        if ty == "radio" then
                            for _, r in ipairs(form.fs.radios[nm or ""]) do r.setOn(false) end
                            on = true
                        else
                            on = not on
                        end
                        paint()
                    end)
                    place(ctx, box)
                    return
                end
                if tag == "select" then
                    local opts = {}
                    local function collectOpts(n)
                        for _, k in ipairs(n.kids or {}) do
                            if k.tag == "option" then
                                local lbl = textOf(k, 80)
                                opts[#opts + 1] = {value = k.attrs.value or lbl, label = (lbl ~= "" and lbl or (k.attrs.value or "")), sel = k.attrs.selected ~= nil}
                            elseif k.tag then
                                collectOpts(k)
                            end
                        end
                    end
                    collectOpts(node)
                    if #opts == 0 then return end
                    local curI = 1
                    for i, o in ipairs(opts) do if o.sel then curI = i end end
                    local holder = Instance.new("Frame")
                    holder.Size = (ctx.auto or ctx.row) and UDim2.new(0, 150, 0, 0) or UDim2.new(1, 0, 0, 0)
                    holder.AutomaticSize = Enum.AutomaticSize.Y
                    holder.BackgroundTransparency = 1
                    holder.ZIndex = 5
                    local hl = Instance.new("UIListLayout")
                    hl.SortOrder = Enum.SortOrder.LayoutOrder
                    hl.Padding = UDim.new(0, 2)
                    hl.Parent = holder
                    local main = Instance.new("TextButton")
                    main.LayoutOrder = 1
                    main.Size = UDim2.new(1, 0, 0, 26)
                    main.BackgroundColor3 = U.dk(Color3.fromRGB(246, 247, 250), "bg")
                    main.BorderSizePixel = 0
                    main.TextColor3 = U.dk(Color3.fromRGB(32, 33, 36), "fg")
                    main.Font = Enum.Font.Gotham
                    main.TextSize = 12
                    main.TextXAlignment = Enum.TextXAlignment.Left
                    main.TextTruncate = Enum.TextTruncate.AtEnd
                    main.AutoButtonColor = true
                    main.ZIndex = 5
                    corner(main, UDim.new(0, 6))
                    stroke(main, Color3.fromRGB(200, 204, 212), 1)
                    local mp = Instance.new("UIPadding")
                    mp.PaddingLeft = UDim.new(0, 8); mp.PaddingRight = UDim.new(0, 8)
                    mp.Parent = main
                    main.Parent = holder
                    local list = Instance.new("Frame")
                    list.LayoutOrder = 2
                    list.Size = UDim2.new(1, 0, 0, 0)
                    list.AutomaticSize = Enum.AutomaticSize.Y
                    list.BackgroundColor3 = U.dk(Color3.new(1, 1, 1), "bg")
                    list.BorderSizePixel = 0
                    list.Visible = false
                    list.ZIndex = 5
                    corner(list, UDim.new(0, 6))
                    stroke(list, Color3.fromRGB(200, 204, 212), 1)
                    local ll = Instance.new("UIListLayout")
                    ll.SortOrder = Enum.SortOrder.LayoutOrder
                    ll.Parent = list
                    list.Parent = holder
                    local function paintSel() main.Text = opts[curI].label .. "  v" end
                    paintSel()
                    for i, o in ipairs(opts) do
                        if i > 60 then break end
                        local ob = Instance.new("TextButton")
                        ob.LayoutOrder = i
                        ob.Size = UDim2.new(1, 0, 0, 26)
                        ob.BackgroundTransparency = 1
                        ob.Text = o.label
                        ob.TextColor3 = U.dk(Color3.fromRGB(32, 33, 36), "fg")
                        ob.Font = Enum.Font.Gotham
                        ob.TextSize = 12
                        ob.TextXAlignment = Enum.TextXAlignment.Left
                        ob.TextTruncate = Enum.TextTruncate.AtEnd
                        ob.ZIndex = 6
                        local op = Instance.new("UIPadding")
                        op.PaddingLeft = UDim.new(0, 8); op.PaddingRight = UDim.new(0, 8)
                        op.Parent = ob
                        ob.MouseButton1Click:Connect(function()
                            curI = i
                            paintSel()
                            list.Visible = false
                        end)
                        ob.Parent = list
                    end
                    main.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)
                    if at.name and at.name ~= "" then
                        form.fs.inputs[at.name] = {name = at.name, get = function() return opts[curI].value end}
                    end
                    place(ctx, holder)
                    return
                end
                if tag == "input" and (ty == "file" or ty == "range" or ty == "color") then return end
                if tag == "textarea" or (tag == "input" and ty ~= "submit" and ty ~= "button" and ty ~= "image" and ty ~= "reset") then
                    local tb = Instance.new("TextBox")
                    tb.Size = (ctx.auto or ctx.row) and UDim2.new(0, 150, 0, 26) or UDim2.new(1, 0, 0, tag == "textarea" and 60 or 26)
                    tb.BackgroundColor3 = st.bg or U.dk(Color3.fromRGB(246, 247, 250), "bg")
                    tb.BorderSizePixel = 0
                    tb.TextColor3 = U.dk(Color3.fromRGB(32, 33, 36), "fg")
                    tb.PlaceholderColor3 = Color3.fromRGB(130, 134, 142)
                    tb.PlaceholderText = at.placeholder or ""
                    tb.Text = tag == "textarea" and textOf(node, 2000) or (at.value or "")
                    tb.ClearTextOnFocus = false
                    tb.Font = Enum.Font.Gotham
                    tb.TextSize = math.clamp(st.size, 9, 18)
                    tb.TextXAlignment = Enum.TextXAlignment.Left
                    tb.TextYAlignment = tag == "textarea" and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
                    tb.MultiLine = tag == "textarea"
                    tb.ClipsDescendants = true
                    tb.ZIndex = 5
                    corner(tb, UDim.new(st.rs or 0, st.radius or 6))
                    stroke(tb, (st.b and st.b.c) or Color3.fromRGB(200, 204, 212), (st.b and st.b.w) or 1)
                    if st.w then
 if st.w[2] then tb.Size = UDim2.new(st.w[2], (st.w[1] or 0), 0, tb.Size.Y.Offset)
 elseif st.w[1] then tb.Size = UDim2.new(0, math.min(st.w[1], 255), 0, tb.Size.Y.Offset) end
 end
                    if st.h and st.h[1] then tb.Size = UDim2.new(tb.Size.X.Scale, tb.Size.X.Offset, 0, st.h[1]) end
                    local pad = Instance.new("UIPadding")
                    pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)
                    pad.Parent = tb
                    place(ctx, tb)
                    if form then form.fs.inputs[at.name or "q"] = tb end
                    if tag == "input" then
                        tb.FocusLost:Connect(function(enter)
                            if enter and form and not form.dummy then submitForm(form, nil) end
                        end)
                    end
                    return
                end
                -- botões (só os que enviam o formulário)
                local label = at.value or textOf(node, 40)
                if label == "" then
                    if tag == "button" and ty ~= "submit" then return end
                    label = "Enviar"
                end
                local full = st.w and st.w[2] and st.w[2] >= 0.99
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(full and 1 or 0, 0, 0, 0)
                b.AutomaticSize = full and Enum.AutomaticSize.Y or Enum.AutomaticSize.XY
                b.BackgroundColor3 = st.bg or U.dk(Color3.fromRGB(239, 239, 239), "bg")
                b.BackgroundTransparency = st.bg and (1 - (st.bga or 1)) or 0
                b.BorderSizePixel = 0
                b.Text = label
                b.TextColor3 = st.bg and st.color or U.dk(Color3.fromRGB(16, 16, 16), "fg")
                b.Font = st.font or (st.bold and Enum.Font.GothamBold or Enum.Font.Gotham)
                b.TextSize = st.size
                b.TextWrapped = false
                b.AutoButtonColor = false
                b.ZIndex = 5
                corner(b, UDim.new(st.rs or 0, st.radius or 2))
                if st.b then
                    stroke(b, st.b.c, math.max(0.75, st.b.w))
                elseif not st.bg then
                    stroke(b, Color3.fromRGB(118, 118, 118), 1)
                end
                local pad = Instance.new("UIPadding")
                pad.PaddingTop = UDim.new(0, st.pt or 1)
                pad.PaddingBottom = UDim.new(0, st.pb or 1)
                pad.PaddingLeft = UDim.new(0, st.pl or 5)
                pad.PaddingRight = UDim.new(0, st.pr or 5)
                pad.Parent = b
                if st.minh and st.minh[1] then
                    local mc = Instance.new("UISizeConstraint")
                    mc.MinSize = Vector2.new(0, st.minh[1])
                    mc.Parent = b
                end
                place(ctx, b)
                pressFx(b)
                if node.hov and node.hov.bg and not st.grad then attachHover(b, st, node.hov) end
                b.MouseButton1Click:Connect(function()
                    local act = actionFor(node)
                    if act then act() return end
                    if ty == "reset" then return end
                    if href then navigate(tabs[cur], {url = href}) return end
                    if form.dummy or ty == "button" then
                        toast("Esse botão depende de JavaScript do site (não suportado)")
                        return
                    end
                    submitForm(form, node)
                end)
            end

            local function renderPre(ctx, node, st)
                local parts = {}
                local len = 0
                local function rec(n)
                    for _, k in ipairs(n.kids or {}) do
                        if len > 4000 then return end
                        if k.text then parts[#parts + 1] = k.text; len = len + #k.text
                        elseif k.tag == "br" then parts[#parts + 1] = "\n"
                        elseif not SKIP[k.tag] then rec(k) end
                    end
                end
                rec(node)
                local box = makeBox(ctx, {bg = U.dk(Color3.fromRGB(240, 242, 246), "bg"), align = "left"}, {})
                local l = Instance.new("TextLabel")
                l.Size = UDim2.new(1, 0, 0, 0)
                l.AutomaticSize = Enum.AutomaticSize.Y
                l.BackgroundTransparency = 1
                l.Text = table.concat(parts):sub(1, 4000)
                l.TextColor3 = U.dk(Color3.fromRGB(40, 42, 48), "fg")
                l.Font = Enum.Font.Code
                l.TextSize = 10
                l.TextWrapped = true
                l.TextXAlignment = Enum.TextXAlignment.Left
                l.TextYAlignment = Enum.TextYAlignment.Top
                l.ZIndex = 5
                place(box, l)
            end

            local function renderTable(ctx, node, st)
                local rows = {}
                local function collect(n)
                    for _, k in ipairs(n.kids) do
                        if k.tag == "tr" then rows[#rows + 1] = k
                        elseif k.tag == "thead" or k.tag == "tbody" or k.tag == "tfoot" then collect(k) end
                    end
                end
                collect(node)
                if #rows == 0 or ctx.auto then renderChildren(ctx, node, st) return end
                local function cellsOf(tr)
                    local cs = {}
                    for _, k in ipairs(tr.kids) do
                        if k.tag == "td" or k.tag == "th" then cs[#cs + 1] = k end
                    end
                    return cs
                end
                local colW, ncols = {}, 0
                for _, tr in ipairs(rows) do
                    local ci = 1
                    for _, c in ipairs(cellsOf(tr)) do
                        local span = math.max(1, tonumber(c.attrs.colspan) or 1)
                        local w = math.clamp(textLen(c, 80), 4, 60) + (hasTag(c, tset("img"), 0) and 20 or 0)
                        colW[ci] = math.max(colW[ci] or 0, w / span)
                        ci = ci + span
                        if ci - 1 > ncols then ncols = ci - 1 end
                    end
                end
                local stacked = ncols > 5
                local total = 0
                for i = 1, ncols do total = total + (colW[i] or 4) end
                local tbl = makeBox(ctx, {align = "left"}, {})
                for _, tr in ipairs(rows) do
                    if stopped then return end
                    tick()
                    local rs = styleFor(tr)
                    if rs.display ~= "none" then
                        local cells = cellsOf(tr)
                        if #cells > 0 then
                            local rowF = Instance.new("Frame")
                            rowF.Size = UDim2.new(1, 0, 0, 0)
                            rowF.AutomaticSize = Enum.AutomaticSize.Y
                            rowF.BorderSizePixel = 0
                            rowF.ZIndex = 4
                            if rs.bg then rowF.BackgroundColor3 = rs.bg; rowF.BackgroundTransparency = 0 else rowF.BackgroundTransparency = 1 end
                            local rl = Instance.new("UIListLayout")
                            rl.SortOrder = Enum.SortOrder.LayoutOrder
                            rl.Padding = UDim.new(0, stacked and 3 or 2)
                            if not stacked then rl.FillDirection = Enum.FillDirection.Horizontal end
                            rl.Parent = rowF
                            place(tbl, rowF)
                            local ci = 1
                            for k, c in ipairs(cells) do
                                local cs = styleFor(c)
                                if cs.display ~= "none" then
                                    local span = math.max(1, tonumber(c.attrs.colspan) or 1)
                                    local wsum = 0
                                    for j = ci, ci + span - 1 do wsum = wsum + (colW[j] or 4) end
                                    ci = ci + span
                                    local cf = Instance.new("Frame")
                                    cf.BorderSizePixel = 0
                                    cf.ZIndex = 4
                                    cf.LayoutOrder = k
                                    cf.AutomaticSize = Enum.AutomaticSize.Y
                                    if stacked then cf.Size = UDim2.new(1, 0, 0, 0)
                                    else cf.Size = UDim2.new(math.max(0.04, wsum / total), -2, 0, 0) end
                                    if cs.bg then cf.BackgroundColor3 = cs.bg; cf.BackgroundTransparency = 0 else cf.BackgroundTransparency = 1 end
                                    local cl = Instance.new("UIListLayout")
                                    cl.SortOrder = Enum.SortOrder.LayoutOrder
                                    cl.Padding = UDim.new(0, 3)
                                    if cs.align == "center" then cl.HorizontalAlignment = Enum.HorizontalAlignment.Center end
                                    cl.Parent = cf
                                    cf.Parent = rowF
                                    local cpad = Instance.new("UIPadding")
                                    cpad.PaddingTop = UDim.new(0, cs.pt or 2)
                                    cpad.PaddingBottom = UDim.new(0, cs.pb or 2)
                                    cpad.PaddingLeft = UDim.new(0, cs.pl or 3)
                                    cpad.PaddingRight = UDim.new(0, cs.pr or 3)
                                    cpad.Parent = cf
                                    if cs.b then
                                        stroke(cf, cs.b.c, math.max(0.75, cs.b.w))
                                    elseif node.attrs.border and node.attrs.border ~= "0" then
                                        stroke(cf, Color3.fromRGB(128, 128, 128), 1)
                                    end
                                    renderChildren({inst = cf, n = 0}, c, cs)
                                end
                            end
                        end
                    end
                end
            end

            local function flexSmall(node)
                local n = 0
                for _, k in ipairs(node.kids) do
                    if k.tag and not SKIP[k.tag] then
                        n = n + 1
                        if textLen(k, 60) > 28 or hasTag(k, IMGLIKE, 0) or k.tag == "img" or k.tag == "table" then return false end
                    end
                end
                return n >= 2
            end

            local vidCount = 0
            local function renderVideo(ctx, node, st)
                vidCount = vidCount + 1
                if vidCount > 6 then return end
                local at = node.attrs
                local src = at.src
                if not src or src == "" then
                    for _, k in ipairs(node.kids) do
                        if k.tag == "source" and k.attrs.src then
                            local ty = (k.attrs.type or ""):lower()
                            local ex = U.fileExt(U.resolve(docBase, k.attrs.src) or "")
                            if ty:find("mp4") or ty:find("webm") or ex == "mp4" or ex == "webm" or ex == "m4v" then
                                src = k.attrs.src
                                break
                            end
                        end
                    end
                end
                local url = src and U.resolve(docBase, src)
                local poster = at.poster and U.resolve(docBase, at.poster)
                local aw = tonumber((at.width or ""):match("^%d+"))
                local ah = tonumber((at.height or ""):match("^%d+"))
                local fr = U.makeVideo({url = url, poster = poster, aspect = (aw and ah and ah > 0) and aw / ah or (16 / 9), loop = at.loop ~= nil, muted = at.muted ~= nil, autoplay = at.autoplay ~= nil and vidCount == 1, sw = st.w, radius = st.radius, rs = st.rs, auto = ctx.auto})
                place(ctx, fr)
            end

            local function plain(ks)
                local c = {}
                for kk, v in pairs(ks) do c[kk] = v end
                c.bg = nil; c.b = nil; c.bt = nil; c.bb = nil; c.bl = nil
                c.pl = nil; c.pr = nil; c.pt = nil; c.pb = nil; c.mt = nil; c.mb = nil
                c.grad = nil; c.bgimg = nil; c.w = nil; c.h = nil; c.minh = nil; c.maxw = nil
                c.anim = nil; c.shadow = nil; c.radius = nil; c.rs = nil
                return c
            end

            local function childContent(wb, k, ks, h)
                local kh = h
                local tag = k.tag
                if tag == "a" and k.attrs.href then kh = resolveHref(k.attrs.href) or h end
                if tag == "img" then renderImage(wb, k, ks, kh) elseif tag == "video" then renderVideo(wb, k, ks)
                elseif tag == "input" or tag == "button" or tag == "textarea" or tag == "select" then
                    renderControl(wb, k, ks, kh)
                elseif tag == "table" or tag == "pre" or tag == "hr" or tag == "ul" or tag == "ol" then
                    renderBlockInner(wb, k, plain(ks), kh)
                else
                    renderChildren(wb, k, ks, k.prefix, kh)
                end
            end

            renderBlockInner = function(ctx, node, st, href)
                if stopped then return end
                local tag = node.tag
                if tag == "hr" then
                    local f = Instance.new("Frame")
                    f.Size = UDim2.new(1, 0, 0, 1)
                    local hb = st.b or st.bt
                    f.BackgroundColor3 = (hb and hb.c) or Color3.fromRGB(200, 202, 208)
                    f.BorderSizePixel = 0
                    f.ZIndex = 5
                    place(ctx, f)
                    return
                elseif tag == "table" then renderTable(ctx, node, st) return
                elseif tag == "pre" then renderPre(ctx, node, st) return
                elseif tag == "iframe" then
                    local src = node.attrs.src and U.resolve(docBase, node.attrs.src)
                    local title = node.attrs.title or "Conteúdo incorporado"
                    local card = makeBox(ctx, {bg = U.dk(Color3.fromRGB(238, 241, 246), "bg"), radius = 8, pt = 12, pb = 12, pl = 12, pr = 12, minh = {72}}, {node = node, href = src})
                    local label = Instance.new("TextLabel")
                    label.BackgroundTransparency = 1
                    label.Size = UDim2.new(1, 0, 0, 34)
                    label.Text = "▣  " .. title .. "\nConteúdo externo"
                    label.TextWrapped = true
                    label.TextColor3 = U.dk(Color3.fromRGB(70, 75, 86), "fg")
                    label.Font = Enum.Font.Gotham
                    label.TextSize = 11
                    label.TextXAlignment = Enum.TextXAlignment.Left
                    label.ZIndex = 5
                    place(card, label)
                    return
                end
                if tag == "details" then
                    local dbox = makeBox(ctx, st, {node = node})
                    local restKids, sumNode = {}, nil
                    for _, k in ipairs(node.kids) do
                        if k.tag == "summary" and not sumNode then sumNode = k else restKids[#restKids + 1] = k end
                    end
                    local bodyBox
                    if sumNode then
                        local sst = styleFor(sumNode)
                        local sb = makeBox(dbox, sst, {node = sumNode, act = function()
                            if bodyBox then bodyBox.inst.Visible = not bodyBox.inst.Visible end
                        end})
                        renderChildren(sb, sumNode, sst, "▸ ")
                    end
                    local pseudo = {tag = "x-body", attrs = {}, kids = restKids, parent = node}
                    local pst = styleFor(pseudo)
                    bodyBox = makeBox(dbox, pst, {})
                    bodyBox.inst.Visible = node.attrs.open ~= nil
                    renderChildren(bodyBox, pseudo, pst)
                    return
                end
                if tag == "ul" or tag == "ol" then local i = 0
                    for _, k in ipairs(node.kids) do
                        if k.tag == "li" then
                            i = i + 1
                            local ks = styleFor(k)
                            if not (st.lsn or ks.lsn) then k.prefix = (tag == "ol") and (i .. ". ") or "• " else k.prefix = nil end
                        end
                    end
                end
                local disp = st.display
                local isGrid = (disp == "grid" or disp == "inline-grid") and (st.cols or 1) >= 2
                local isFlex = disp == "flex" or disp == "inline-flex"
                local isRow = isFlex and st.dir ~= "column"
                if isRow and st.jc == "center" then st.align = "center" end
                if isFlex and not isRow and st.ai == "center" then st.align = "center" end
                local kids = {}
                if isGrid or isRow then
                    for _, k in ipairs(node.kids) do
                        if k.tag and not SKIP[k.tag] and not k.attrs.hidden and not hiddenClass(k) then
                            local ks = styleFor(k)
                            if ks.display ~= "none" and not (ks.pos == "absolute" and textLen(k, 3) == 0 and not ks.bgimg and not hasImgTag(k, 0)) then kids[#kids + 1] = k end
                        end
                    end
                end
                if #kids >= 2 then
                    local anyOrder = false
                    for _, k in ipairs(kids) do
                        local o = styleFor(k).order
                        if o and o ~= 0 then anyOrder = true break end
                    end
                    if anyOrder then
                        local pos = {}
                        for i, k in ipairs(kids) do pos[k] = i end
                        table.sort(kids, function(a, b)
                            local oa, ob = styleFor(a).order or 0, styleFor(b).order or 0
                            if oa ~= ob then return oa < ob end
                            return pos[a] < pos[b]
                        end)
                    end
                    if st.rev and isRow then
                        local n = #kids
                        for i = 1, n // 2 do kids[i], kids[n - i + 1] = kids[n - i + 1], kids[i] end
                    end
                end
                local mode, cols = "stack", 1
                if isGrid and #kids >= 1 then
                    mode = "cols"
                    cols = st.cols
                elseif isRow and #kids >= 2 then
                    if st.wrap and not flexSmall(node) then
                        mode = "cols"
                        cols = (#kids <= 4) and #kids or 3
                    else
                        mode = "flex"
                    end
                end
                if mode == "stack" then
                    local ratio = st.ar or ((st.ptp and st.ptp >= 10) and (100 / st.ptp) or nil)
                    if ratio and tag ~= "img" and (st.bgimg or textLen(node, 3) == 0 or (st.ptp and hasImgTag(node, 0))) then
                        local abox = makeBox(ctx, st, {node = node, href = href, act = actionFor(node), aspect = math.clamp(ratio, 0.2, 6)})
                        renderChildren(abox, node, st, nil, href)
                        return
                    end
                    local box = makeBox(ctx, st, {node = node, href = href, act = actionFor(node)})
                    renderChildren(box, node, st, node.prefix, href)
                    return
                end
                local gap = st.gap or 0
                if mode == "cols" then
                    local box = makeBox(ctx, st, {row = true, wraps = true, node = node})
                    local tracks = (isGrid and st.tracks and #st.tracks == cols) and st.tracks or nil
                    local usedCols = 0
                    for _, k in ipairs(kids) do
                        local ks = styleFor(k)
                        local kw = ks.w or ((not ks.grow) and ks.fbasis) or nil
                        local cw
                        if kw and (kw[2] or (kw[1] and kw[1] < AVAILW)) then
                            cw = UDim2.new(kw[2] or 0, (kw[1] or 0) - 1, 0, 0)
                            if isGrid then usedCols = (usedCols + 1) % cols end
                        elseif isGrid and (tracks or (ks.span and ks.span ~= 1)) then
                            local span = (ks.span == -1) and cols or math.max(1, math.min(cols, ks.span or 1))
                            if usedCols + span > cols then usedCols = 0 end
                            local a = 0
                            for ci = usedCols + 1, usedCols + span do a = a + (tracks and tracks[ci] or (1 / cols)) end
                            usedCols = (usedCols + span) % cols
                            cw = UDim2.new(a, math.floor(gap * (span - 1 - a * (cols - 1))) - 1, 0, 0)
                        else
                            if isGrid then usedCols = (usedCols + 1) % cols end
                            cw = UDim2.new(1 / cols, -math.ceil(gap * (cols - 1) / cols) - 1, 0, 0)
                        end
                        local khr = (k.tag == "a" and k.attrs.href and resolveHref(k.attrs.href)) or href
                        local wb = makeBox(box, ks, {colW = cw, node = k, href = khr, act = actionFor(k)})
                        childContent(wb, k, ks, href)
                    end
                    return
                end
                local fills, anyFill = {}, false
                for i, k in ipairs(kids) do
                    local ks = styleFor(k)
                    local fl = (ks.grow or (not (ks.w or ks.fbasis) and k.tag ~= "img" and k.tag ~= "button" and (textLen(k, 60) > 28 or hasBlock(k)))) and true or false
                    fills[i] = fl
                    if fl then anyFill = true end
                end
                local sp = st.jc == "space-between" or st.jc == "space-around" or st.jc == "space-evenly"
                local est = 0
                for i, k in ipairs(kids) do
                    if not fills[i] then
                        local ks = styleFor(k)
                        local ew = (ks.w and ks.w[1]) or (textLen(k, 80) * ks.size * 0.58 + (ks.pl or 0) + (ks.pr or 0) + 8)
                        if hasImgTag(k, 0) then ew = ew + 28 end
                        est = est + ew + gap
                    end
                end
                local fitsRow = est <= (AVAILW - 4)
                local box = makeBox(ctx, st, {row = true, wraps = (not anyFill) and ((not sp) or (not fitsRow)), node = node})
                for i, k in ipairs(kids) do
                    local ks = styleFor(k)
                    local fixedW = nil
                    local kw = ks.w or ks.fbasis
                    if (not fills[i]) and kw then
                        fixedW = UDim2.new(kw[2] or 0, math.min(kw[1] or 0, AVAILW), 0, 0)
                    end
                    local khr = (k.tag == "a" and k.attrs.href and resolveHref(k.attrs.href)) or href
                    local wb = makeBox(box, ks, {auto = (not fills[i]) and not fixedW, colW = fixedW, fill = fills[i], fillN = #kids, node = k, href = khr, act = actionFor(k)})
                    childContent(wb, k, ks, href)
                end
            end

            renderBlock = function(ctx, node, st, href)
                local mt = type(st.mt) == "number" and st.mt or 0
                ctx.gap = math.max(ctx.gap or 0, mt)
                renderBlockInner(ctx, node, st, href)
                ctx.gap = type(st.mb) == "number" and st.mb or nil
            end

            renderChildren = function(ctx, node, st, prefix, href)
                local buf
                local function newCur()
                    return {rich = "", hasText = false, links = href and {{href = href, label = ""}} or {}}
                end
                buf = newCur()
                if prefix then buf.rich = prefix; buf.hasText = true end
                local curRow
            local function rowCtx()
                if ctx.fillTarget then return ctx end
                if not curRow then
                    local jc = (st.align == "center") and "center" or ((st.align == "right") and "flex-end" or nil)
                    curRow = makeBox(ctx, {jc = jc, gap = 4}, {row = true, wraps = true})
                end
                return curRow
            end
            local function flush()
                    if buf.hasText then
 makeText(ctx, buf, st)
 curRow = nil
 end
                    buf = newCur()
                end
                local walk
                walk = function(owner, ps, h)
                    local pb = owner.tag and pseudoRich(owner, "before", ps, st.size)
                    if pb then
                        if pb.blk and buf.hasText then buf.rich = buf.rich .. "\n" end
                        buf.rich = buf.rich .. pb.rich
                        if pb.vis then buf.hasText = true end
                        if pb.blk then buf.rich = buf.rich .. "\n" end
                    end
                    for _, c in ipairs(owner.kids) do
                        if stopped then return end
                        if c.text then
                            local t = c.text:gsub("%s+", " ")
                            if ps.tt == "uppercase" then t = t:upper()
                            elseif ps.tt == "lowercase" then t = t:lower()
                            elseif ps.tt == "capitalize" then t = t:gsub("(%a)([%w']*)", function(a1, b1) return a1:upper() .. b1 end) end
                            if not buf.hasText then t = t:gsub("^%s+", "") end
                            if t ~= "" then
                                if t:find("%S") then buf.hasText = true end
                                buf.rich = buf.rich .. wrapRich(U.esc(t), ps, st.size)
                            end
                        else
                            local tag = c.tag
                            if (tag == "video" or tag == "iframe" or not SKIP[tag]) and not c.attrs.hidden then
                                local cs = styleFor(c)
                                tick()
                                if cs.display == "none" and c.attrs.id and TOG[c.attrs.id] then
                                    local cp = {}
                                    for k2, v2 in pairs(cs) do cp[k2] = v2 end
                                    cp.display = "block"
                                    cp._hide = true
                                    cs = cp
                                end
                                if cs.display ~= "none" and not hiddenClass(c) and not (cs.pos == "absolute" and tag ~= "img" and textLen(c, 3) == 0 and not cs.bgimg and not hasImgTag(c, 0)) then
                                    if tag == "br" then
                                        if buf.hasText then buf.rich = buf.rich .. "\n" end
 curRow = nil
                                    elseif tag == "video" then
 flush()
 curRow = nil
 renderVideo(ctx, c, cs)
                                    elseif tag == "iframe" then
                                        flush()
                                        curRow = nil
                                        renderBlockInner(ctx, c, cs, h)
 elseif (cs.display == "inline-block" or cs.display == "inline-flex") and (cs.bg or cs.b) and tag ~= "img" and tag ~= "button" and textLen(c, 200) > 0 then
                                        flush()
                                        local nh = h
                                        if tag == "a" and c.attrs.href then nh = resolveHref(c.attrs.href) or h end
                                        local wb = makeBox(rowCtx(), cs, {auto = true, node = c, href = nh, act = actionFor(c)})
                                        renderChildren(wb, c, cs, nil, nh)
                                    elseif tag == "img" then
                                        flush()
 if cs.display == "block" then
 curRow = nil
 renderImage(ctx, c, cs, h)
 else
 renderImage(rowCtx(), c, cs, h)
 end
                                    elseif tag == "input" or tag == "button" or tag == "textarea" or tag == "select" then
                                        flush()
 renderControl(rowCtx(), c, cs, h)
                                    elseif tag == "a" and c.attrs.href and not (cs.display == "block" or hasBlock(c)) then
                                        local url = resolveHref(c.attrs.href)
                                        local dup = false
                                        if url then
                                            for _, lk in ipairs(buf.links) do if lk.href == url then dup = true end end
                                            if not dup then buf.links[#buf.links + 1] = {href = url, label = textOf(c, 40)} end
                                        end
                                        if not url then
                                            local lact = actionFor(c)
                                            if lact then buf.links[#buf.links + 1] = {act = lact, label = textOf(c, 40)} end
                                        end
                                        walk(c, cs, url or h)
                                    elseif BLOCKT[tag] or cs.display == "block" or cs.display == "flex" or cs.display == "grid" or cs.display == "list-item" or cs.display == "table" or (tag == "a" and c.attrs.href) then
                                        flush()
                                        local nh = h
                                        if tag == "a" and c.attrs.href then nh = resolveHref(c.attrs.href) or h end
                                        curRow = nil
 renderBlock(ctx, c, cs, nh)
                                    else
                                        walk(c, cs, h)
                                    end
                                end
                            end
                        end
                    end
                    local pa = owner.tag and not stopped and pseudoRich(owner, "after", ps, st.size)
                    if pa then
                        if pa.blk and buf.hasText then buf.rich = buf.rich .. "\n" end
                        buf.rich = buf.rich .. pa.rich
                        if pa.vis then buf.hasText = true end
                    end
                end
                walk(node, st, href)
                flush()
            end

            -- ---------------------------------------------------------- execução
            local function findTag(n, tag, depth)
                if depth > 6 then return nil end
                for _, k in ipairs(n.kids or {}) do
                    if k.tag == tag then return k end
                end
                for _, k in ipairs(n.kids or {}) do
                    if k.tag then
                        local r = findTag(k, tag, depth + 1)
                        if r then return r end
                    end
                end
                return nil
            end
            setStatus("montando layout…")
            local bodyN = findTag(root, "body", 0) or root
            local bst
            if bodyN == root then root.st = BASE; bst = BASE else bst = styleFor(bodyN) end
            local htmlN = findTag(root, "html", 0)
            local pageBg = bst.bg or (htmlN and styleFor(htmlN).bg)
            if pageBg and canvas.Parent then canvas.BackgroundColor3 = pageBg end
            local ctx = {inst = canvas, n = 0, lay = canvas:FindFirstChildOfClass("UIListLayout")}
            local cpad = canvas:FindFirstChildOfClass("UIPadding")
            if cpad then
                local function nz(v, d)
                    if type(v) == "number" then return v end
                    if v == "auto" then return 0 end
                    return d
                end
                cpad.PaddingTop = UDim.new(0, nz(bst.mt, 6) + (bst.pt or 0))
                cpad.PaddingBottom = UDim.new(0, nz(bst.mb, 6) + (bst.pb or 0))
                cpad.PaddingLeft = UDim.new(0, nz(bst.ml, 6) + (bst.pl or 0))
                cpad.PaddingRight = UDim.new(0, nz(bst.mr, 6) + (bst.pr or 0))
            end
            if bst.grad then applyGrad(canvas, bst.grad) end
            if ctx.lay and bst.align == "center" then ctx.lay.HorizontalAlignment = Enum.HorizontalAlignment.Center end
            renderChildren(ctx, bodyN, bst)
            if not alive() then return end
            if B.cut then
                local l = Instance.new("TextLabel")
                l.Size = UDim2.new(1, 0, 0, 20)
                l.BackgroundTransparency = 1
                l.Text = "… página muito grande, conteúdo cortado"
                l.TextColor3 = Color3.fromRGB(120, 124, 132)
                l.Font = Enum.Font.Gotham
                l.TextSize = 10
                l.ZIndex = 5
                place(ctx, l)
            end
            setStatus(B.el .. " elementos")
            return B.el
        end
    end)()

    local function buildPage(entry)
        if findBar.Visible then closeFind() end if U.closeSite then U.closeSite() end
        clearSel()
        selMarks = {}
        richLbls = {}
        local rd = entry.reader and entry.view and entry.view.kind == "page"
        pageView.BackgroundTransparency = rd and 0 or 1
        pageView.BackgroundColor3 = U.dark.on and Color3.fromRGB(30, 30, 33) or Color3.fromRGB(245, 238, 222)
        for _, c in ipairs(pageView:GetChildren()) do if c.Name == "Dyn" then c:Destroy() end end
        local order = 0
        local function add(inst)
            order = order + 1
            inst.LayoutOrder = order
            inst.Name = "Dyn"
            inst.Parent = pageView
            return inst
        end
        local function label(text, size, color, font, h)
            return add(new("TextLabel", {
                Size = UDim2.new(1, 0, 0, h or 0), AutomaticSize = h and Enum.AutomaticSize.None or Enum.AutomaticSize.Y, BackgroundTransparency = 1,
                Text = text, TextColor3 = color, Font = font or Enum.Font.Gotham, TextSize = size, TextWrapped = true, RichText = true,
                TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5,
            }))
        end
        local function card(rich, onClick)
            local b = add(new("TextButton", {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.card, BorderSizePixel = 0, AutoButtonColor = true,
                ClipsDescendants = true, RichText = true, Text = rich, TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 11, TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5,
            }))
            corner(b, UDim.new(0, 10))
            new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, b)
            b.MouseButton1Click:Connect(onClick)
            return b
        end
        local function button(text, onClick)
            local b = add(new("TextButton", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.accent, BorderSizePixel = 0, Text = text, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 5}))
            corner(b, UDim.new(0, 18))
            b.MouseButton1Click:Connect(onClick)
        end

        local favActive = 0
        local function loadFav(holder, url)
            local host = U.hostOf(url)
            local furl = "https://www.google.com/s2/favicons?domain=" .. host .. "&sz=64"
            task.spawn(function()
                while favActive >= 4 do task.wait(0.05) end
                if not holder.Parent then return end
                favActive = favActive + 1
                local a = U.cacheImage(furl, 200000)
                favActive = favActive - 1
                if a and holder.Parent then
                    for _, c in ipairs(holder:GetChildren()) do
                        if c:IsA("TextLabel") then c.Visible = false end
                    end
                    holder.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
                    -- o icone fica num quadrado inscrito na bolinha (centralizado), senao os cantos vazam pra fora do circulo
                    local img = new("ImageLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0.64, 0, 0.64, 0), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Image = a, ZIndex = holder.ZIndex + 2}, holder)
                    corner(img, UDim.new(0.18, 0))
                end
            end)
        end
        local function siteCard(rich, url, onClick)
            local b = card(rich, onClick)
            local pad = b:FindFirstChildOfClass("UIPadding")
            if pad then pad.PaddingLeft = UDim.new(0, 40) end
            local fav = favicon(b, url, 22, 6)
            fav.Position = UDim2.new(0, -30, 0, 0)
            loadFav(fav, url)
            return b
        end

        local function imageGrid(items)
            local grid = add(new("Frame", {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, ZIndex = 5}))
            local tiles = {}
            local NCOL, GAP = 4, 4
            local lastW, layoutPending = -1, false

            local function mkTile(it)
                local tile = new("TextButton", {LayoutOrder = #tiles + 1, BackgroundColor3 = C.card, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ClipsDescendants = true, ZIndex = 5}, grid)
                corner(tile, UDim.new(0, 6))
                local img = new("ImageLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, Image = "", ImageTransparency = 1, ZIndex = 6}, tile)
                corner(img, UDim.new(0, 6))
                new("TextLabel", {Name = "Ph", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "…", TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 14, ZIndex = 5}, tile)
                local cap = new("TextLabel", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, BorderSizePixel = 0, Text = it.title ~= "" and it.title or U.hostOf(it.page or it.url), TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.Gotham, TextSize = 7, TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8}, tile)
                new("UIPadding", {PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3)}, cap)
                if it.gif or (it.url or ""):lower():match("%.gif") then
                    local gb = new("TextLabel", {Position = UDim2.new(0, 3, 0, 3), Size = UDim2.new(0, 20, 0, 11), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25, BorderSizePixel = 0, Text = "GIF", TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 7, ZIndex = 8}, tile)
                    corner(gb, UDim.new(0, 5))
                end
                local mark = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = C.accent, BackgroundTransparency = 0.6, BorderSizePixel = 0, Visible = selItems[it] == true, ZIndex = 9}, tile)
                corner(mark, UDim.new(0, 6))
                new("UIStroke", {Color = C.blue, Thickness = 2}, mark)
                local ck = new("TextLabel", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 3), Size = UDim2.new(0, 16, 0, 16), BackgroundColor3 = C.accent, BorderSizePixel = 0, Text = "✓", TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 10, ZIndex = 10}, mark)
                corner(ck, UDim.new(1, 0))
                selMarks[it] = mark
                local holdId, justHeld, y0 = 0, false, 0
                tile.MouseButton1Down:Connect(function()
                    holdId = holdId + 1
                    justHeld = false
                    local id = holdId
                    y0 = pageView.CanvasPosition.Y
                    task.delay(0.45, function()
                        if id ~= holdId or not tile.Parent then return end
                        if math.abs(pageView.CanvasPosition.Y - y0) > 6 then return end
                        justHeld = true
                        setSel(it, not selItems[it])
                    end)
                end)
                tile.MouseButton1Up:Connect(function() holdId = holdId + 1 end)
                tile.MouseLeave:Connect(function() holdId = holdId + 1 end)
                tile.MouseButton1Click:Connect(function()
                    if justHeld then justHeld = false return end
                    if selCount > 0 then setSel(it, not selItems[it]) return end
                    openViewer(it, items)
                end)
                table.insert(tiles, {tile = tile, img = img, item = it})
            end

            local function relayout()
                local W = grid.AbsoluteSize.X
                if W <= 0 then W = 250 end
                lastW = grid.AbsoluteSize.X
                local colW = (W - (NCOL - 1) * GAP) / NCOL
                local hs = {}
                for c = 1, NCOL do hs[c] = 0 end
                for _, t in ipairs(tiles) do
                    local c = 1
                    for k = 2, NCOL do if hs[k] < hs[c] - 0.5 then c = k end end
                    local h = math.floor(colW * math.clamp(t.ar or 1, 0.55, 2))
                    t.tile.Position = UDim2.new((c - 1) / NCOL, (c - 1) * GAP / NCOL * 1, 0, hs[c])
                    t.tile.Size = UDim2.new(1 / NCOL, -(NCOL - 1) * GAP / NCOL, 0, h)
                    hs[c] = hs[c] + h + GAP
                end
                local tall = 0
                for c = 1, NCOL do if hs[c] > tall then tall = hs[c] end end
                grid.Size = UDim2.new(1, 0, 0, tall)
            end
            local function schedule()
                if layoutPending then return end
                layoutPending = true
                task.defer(function()
                    layoutPending = false
                    relayout()
                end)
            end
            grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                if grid.AbsoluteSize.X ~= lastW then schedule() end
            end)

            local nextI = 0
            local function worker()
                while true do
                    nextI = nextI + 1
                    local t = tiles[nextI]
                    if not t then nextI = nextI - 1 break end
                    if t.img.Parent then
                        local a = U.cacheImage(t.item.thumb)
                        if t.img.Parent then
                            local ph = t.tile:FindFirstChild("Ph")
                            if a then
                                t.img.Image = a
                                TweenService:Create(t.img, TweenInfo.new(0.2), {ImageTransparency = 0}):Play()
                                if ph then ph:Destroy() end
                                local iw, ih = U.dimsFor(t.item.thumb)
                                if iw and ih then t.ar = ih / iw; schedule() end
                            elseif ph then
                                ph.Text = hasAssetFn and "×" or "sem getcustomasset"
                                ph.TextSize = hasAssetFn and 14 or 8
                            end
                        end
                    end
                end
            end
            local function startWorkers()
                for _ = 1, 8 do task.spawn(worker) end
            end
            for _, it in ipairs(items) do mkTile(it) end
            relayout()
            startWorkers()
            return {
                append = function(newItems)
                    for _, it in ipairs(newItems) do mkTile(it) end
                    schedule()
                    startWorkers()
                end,
            }
        end
        if entry.q then
            local bar = add(new("Frame", {Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, ZIndex = 5}))
            new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, bar)
            for i, cat in ipairs({{"Tudo", nil}, {"Imagens", "images"}}) do
                local on = (entry.mode == cat[2])
                local chip = new("TextButton", {LayoutOrder = i, Size = UDim2.new(0, 76, 0, 26), BackgroundColor3 = on and C.accent or C.card, BorderSizePixel = 0, Text = cat[1], TextColor3 = on and Color3.new(1, 1, 1) or C.text, Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 6}, bar)
                corner(chip, UDim.new(0, 13))
                chip.MouseButton1Click:Connect(function()
                    if on then return end
                    navigate(tabs[cur], {q = entry.q, mode = cat[2]})
                end)
            end
        end
        if entry.state == "loading" then
            label("Carregando…\n" .. U.esc((entry.url or entry.q or ""):sub(1, 120)), 12, C.sub, Enum.Font.Gotham, 90)
            return
        end
        if entry.state ~= "done" then
            local title = entry.state == "stopped" and "Carregamento interrompido" or "Não foi possível acessar este site"
            label("<b>" .. title .. "</b>", 15, C.text, Enum.Font.Gotham)
            label(U.esc(entry.url and U.hostOf(entry.url) or (entry.q or "")), 11, C.blue, Enum.Font.Gotham)
            if entry.err then
                label("Verifique se o ambiente permite requisições HTTP e se o site aceita acesso externo.\n\n" .. U.esc(entry.err:sub(1, 160)), 10, C.sub, Enum.Font.Gotham)
            end
            button("TENTAR NOVAMENTE", reload)
            return
        end
        local view = entry.view
        if view.kind == "images" then
            if #view.items == 0 then
                label("Não encontrei imagens. Tente outra pesquisa.", 11, C.sub, Enum.Font.Gotham)
                return
            end
            local g = imageGrid(view.items)
            if view.more then
                local foot = label("Role para carregar mais…", 10, C.sub, Enum.Font.Gotham, 26)
                foot.TextXAlignment = Enum.TextXAlignment.Center
                local function check()
                    if view.loading or view.exhausted or not foot.Parent or not pageView.Visible then return end
                    if pageView.CanvasPosition.Y + pageView.AbsoluteSize.Y < pageView.AbsoluteCanvasSize.Y - 260 * uiScale() then return end
                    view.loading = true
                    foot.Text = "Carregando mais…"
                    task.spawn(function()
                        local okM, newItems = pcall(view.more)
                        view.loading = false
                        if okM and type(newItems) == "table" and #newItems > 0 then
                            for _, it in ipairs(newItems) do view.items[#view.items + 1] = it end
                            if foot.Parent then
                                g.append(newItems)
                                foot.Text = "Role para carregar mais…"
                                task.defer(check)
                            end
                        else
                            view.exhausted = true
                            if foot.Parent then foot.Text = "Fim dos resultados" end
                        end
                    end)
                end
                pageView:GetPropertyChangedSignal("CanvasPosition"):Connect(check)
                task.defer(check)
            end
        elseif view.kind == "image" then
            label("<b>Imagem</b>", 15, C.text, Enum.Font.Gotham)
            label(U.esc(view.name), 12, C.blue, Enum.Font.Gotham)
            button("ABRIR IMAGEM", function() openViewer({url = view.url, thumb = view.url, title = view.title}) end)
        elseif view.kind == "video" then
            label("<b>Vídeo</b>", 15, C.text, Enum.Font.Gotham)
            label(U.esc(view.name), 12, C.blue, Enum.Font.Gotham)
            add(U.makeVideo({url = view.url, aspect = 16 / 9, autoplay = true}))
            button("BAIXAR VÍDEO", function()
                task.spawn(function()
                    local okD, r = pcall(U.download, view.url, view.ext)
                    toast(okD and type(r) == "table" and ("Salvo em " .. r.path) or "Falha ao baixar")
                end)
            end)
        elseif view.kind == "download" then
            label("<b>Download concluído</b>", 15, C.text, Enum.Font.Gotham)
            label(U.esc(view.name), 12, C.blue, Enum.Font.Gotham)
            label("Tamanho: " .. U.humanSize(view.size) .. "\nSalvo em: " .. U.esc(view.path), 10, C.sub, Enum.Font.Gotham)
            if view.ext == "mp3" or view.ext == "ogg" then
                button("ENVIAR PARA MÚSICA", function() toast(U.sendTo(view.path, "PHONE/Music") and "Enviado para Música" or "Falha ao copiar") end)
            elseif view.ext == "png" or view.ext == "jpg" or view.ext == "jpeg" or view.ext == "gif" then
                button("SALVAR NA GALERIA", function() toast(U.sendTo(view.path, "PHONE/Photos") and "Salvo na Galeria" or "Falha ao copiar") end)
            end
            button("VER DOWNLOADS", function() openPanel("dl") end)
        elseif view.kind == "search" then
            label("Resultados para <b>" .. U.esc(entry.q) .. "</b>", 12, C.text, Enum.Font.Gotham)
            if #view.items == 0 then
                label("Não encontrei resultados. Tente outra pesquisa ou digite um endereço.", 11, C.sub, Enum.Font.Gotham)
            end
            local function addResult(it)
                local rich = '<font color="#8ab4f8"><b>' .. U.esc(it.name) .. '</b></font>\n<font color="#81c995" size="10">' .. U.esc(U.hostOf(it.url)) .. "</font>"
                if it.snippet and it.snippet ~= "" then rich = rich .. '\n<font color="#9aa0a6" size="10">' .. U.esc(it.snippet) .. "</font>" end
                siteCard(rich, it.url, function() navigate(tabs[cur], {url = it.url}) end)
            end
            for _, it in ipairs(view.items) do addResult(it) end
            if view.more and #view.items > 0 then
                local foot = label("Role para carregar mais…", 10, C.sub, Enum.Font.Gotham, 26)
                foot.TextXAlignment = Enum.TextXAlignment.Center
                foot.LayoutOrder = 1000000   -- rodape sempre por ultimo; novos resultados entram antes dele
                local function check()
                    if view.loading or view.exhausted or not foot.Parent or not pageView.Visible then return end
                    if pageView.CanvasPosition.Y + pageView.AbsoluteSize.Y < pageView.AbsoluteCanvasSize.Y - 260 * uiScale() then return end
                    view.loading = true
                    foot.Text = "Carregando mais…"
                    task.spawn(function()
                        local okM, newItems = pcall(view.more)
                        view.loading = false
                        if okM and type(newItems) == "table" and #newItems > 0 then
                            for _, it in ipairs(newItems) do
                                view.items[#view.items + 1] = it
                                if foot.Parent then addResult(it) end
                            end
                            if foot.Parent then
                                foot.Text = "Role para carregar mais…"
                                task.defer(check)
                            end
                        else
                            view.exhausted = true
                            if foot.Parent then foot.Text = "Fim dos resultados" end
                        end
                    end)
                end
                pageView:GetPropertyChangedSignal("CanvasPosition"):Connect(check)
                task.defer(check)
            end
        else
            if entry.reader then
                local rs = phoneSettings.readerSize or 14
                local ink = U.dark.on and Color3.fromRGB(222, 218, 210) or Color3.fromRGB(52, 44, 34)
                local rbar = add(new("Frame", {Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, ZIndex = 5}))
                new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, rbar)
                local function rbtn(i, txt, w, fn)
                    local b = new("TextButton", {LayoutOrder = i, Size = UDim2.new(0, w, 0, 26), BackgroundColor3 = U.dark.on and Color3.fromRGB(64, 62, 58) or Color3.fromRGB(226, 216, 194), BorderSizePixel = 0, Text = txt, TextColor3 = ink, Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 6}, rbar)
                    corner(b, UDim.new(0, 13))
                    b.MouseButton1Click:Connect(fn)
                end
                rbtn(1, "A-", 40, function() phoneSettings.readerSize = math.max(10, rs - 1); saveSettings(); render() end)
                rbtn(2, "A+", 40, function() phoneSettings.readerSize = math.min(24, rs + 1); saveSettings(); render() end)
                rbtn(3, "SAIR", 56, function() entry.reader = nil; render() end)
                label("<b>" .. U.esc(view.title) .. "</b>", rs + 5, ink, Enum.Font.GothamBold)
                local txt = (view.readRich or view.rich)
                if not U.dark.on then txt = txt:gsub("#8ab4f8", "#8a4b08") end
                local chunk, chunks = "", {}
                for para in (txt .. "\n\n"):gmatch("(.-)\n\n") do
                    if #chunk + #para > 2500 and chunk ~= "" then
                        chunks[#chunks + 1] = chunk
                        chunk = ""
                    end
                    chunk = chunk .. (chunk ~= "" and "\n\n" or "") .. para
                end
                if chunk ~= "" then chunks[#chunks + 1] = chunk end
                for _, ch in ipairs(chunks) do
                    local l = label(ch, rs, ink, Enum.Font.Gotham)
                    l.LineHeight = 1.2
                    richLbls[#richLbls + 1] = {lbl = l, base = ch}
                end
                return
            end
            if not entry.simple and view.html then
                local statusLbl = add(new("TextLabel", {Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = "montando página…", TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5}))
                local holder = add(new("Frame", {Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 4}))
                local canvas = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = U.dark.on and Color3.fromRGB(18, 18, 20) or Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4}, holder)
                U.fitSetup(holder, canvas)
                new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0)}, canvas)
                new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, canvas)
                corner(canvas, UDim.new(0, 0))
                local myRid = entry.rid
                local function alive()
                    return canvas.Parent ~= nil and entry.rid == myRid and not entry.simple and not entry.reader
                end
                task.spawn(function()
                    local okB, res = pcall(U.layoutBuild, entry, canvas, view.html, alive, function(t)
                        if statusLbl.Parent then statusLbl.Text = t end
                    end, openViewer)
                    if not alive() then return end
                    if not okB or (type(res) == "number" and res < 4) then
                        entry.simple = true
                        toast(okB and "Página sem conteúdo montável, abrindo em texto" or "Falha ao montar a página, abrindo em texto")
                        render()
                        return
                    end
                    statusLbl:Destroy()
                    U.fitRun(holder, canvas, alive)
                end)
                return
            end
            local head = add(new("Frame", {Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 5}))
            corner(head, UDim.new(0, 10))
            local fav = favicon(head, entry.url, 26, 6)
            fav.Position = UDim2.new(0, 9, 0.5, -13)
            loadFav(fav, entry.url)
            new("TextLabel", {Position = UDim2.new(0, 44, 0, 5), Size = UDim2.new(1, -52, 0, 18), BackgroundTransparency = 1, Text = view.title, TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6}, head)
            new("TextLabel", {Position = UDim2.new(0, 44, 0, 23), Size = UDim2.new(1, -52, 0, 16), BackgroundTransparency = 1, Text = U.hostOf(entry.url), TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6}, head)
            local rl = label(view.rich, 12, C.text, Enum.Font.Gotham)
            richLbls = {{lbl = rl, base = view.rich}}
            if view.images and #view.images > 0 then
                label("<b>IMAGENS DESTA PÁGINA (" .. #view.images .. ")</b>", 10, C.blue, Enum.Font.Gotham)
                imageGrid(view.images)
            end
            if #view.items > 0 then
                label("<b>LINKS DESTA PÁGINA (" .. #view.items .. ")</b>", 10, C.blue, Enum.Font.Gotham)
                for _, it in ipairs(view.items) do
                    siteCard("<b>" .. U.esc(it.name) .. '</b>\n<font color="#9aa0a6" size="10">' .. U.esc(U.hostOf(it.url)) .. "</font>", it.url, function() navigate(tabs[cur], {url = it.url}) end)
                end
            end
        end
    end

    render = function()
        local e = curEntry()
        updateChrome()
        if e.ntp then
            if findBar.Visible then closeFind() end if U.closeSite then U.closeSite() end
            pageView.Visible = false
            ntpView.Visible = true
            buildNtp()
        else
            ntpView.Visible = false
            pageView.Visible = true
            buildPage(e)
            pageView.CanvasPosition = Vector2.new(0, 0)
        end
        if refreshSwitcher then refreshSwitcher(true) end
    end

    local switcher = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = C.bg, BorderSizePixel = 0, Visible = false, ZIndex = 15}, area)
    new("TextLabel", {Name = "SwTitle", Position = UDim2.new(0, 14, 0, 6), Size = UDim2.new(0.5, 0, 0, 30), BackgroundTransparency = 1, Text = "1 guia", TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 16}, switcher)
    local swNew = new("TextButton", {Position = UDim2.new(1, -108, 0, 8), Size = UDim2.new(0, 98, 0, 26), BackgroundColor3 = C.accent, BorderSizePixel = 0, Text = "+ NOVA GUIA", TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 10, ZIndex = 16}, switcher)
    corner(swNew, UDim.new(0, 13))
    local swList = new("ScrollingFrame", {Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(1, 0, 1, -42), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 16}, switcher)
    new("UIGridLayout", {CellSize = UDim2.new(0, 122, 0, 116), CellPadding = UDim2.new(0, 8, 0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, swList)
    new("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10)}, swList)

    local function tabTitle(t)
        local e = t.hist[t.pos]
        if e.ntp then return "Nova guia" end
        return e.title or (e.q and ("Pesquisa: " .. e.q)) or U.hostOf(e.url)
    end
    local function switchTo(i)
        cur = i
        switcher.Visible = false
        showEntry(tabs[cur])
    end
    local function closeTab(i)
        table.remove(tabs, i)
        if #tabs == 0 then tabs[1] = newTab() end
        if i < cur then cur = cur - 1 end
        if cur > #tabs then cur = #tabs end
        if cur < 1 then cur = 1 end
        render()
        refreshSwitcher(true)
    end
    refreshSwitcher = function(onlyIfVisible)
        if onlyIfVisible and not switcher.Visible then return end
        for _, c in ipairs(swList:GetChildren()) do if c.Name == "TabCard" then c:Destroy() end end
        switcher:FindFirstChild("SwTitle").Text = #tabs .. (#tabs == 1 and " guia" or " guias")
        for i, t in ipairs(tabs) do
            local e = t.hist[t.pos]
            local card = new("TextButton", {Name = "TabCard", LayoutOrder = i, BackgroundColor3 = C.card, BorderSizePixel = 0, Text = "", AutoButtonColor = true, ZIndex = 17}, swList)
            corner(card, UDim.new(0, 12))
            if i == cur then new("UIStroke", {Color = C.accent, Thickness = 2}, card) end
            favicon(card, e.url or e.q or "Nova", 18, 18).Position = UDim2.new(0, 8, 0, 8)
            new("TextLabel", {Position = UDim2.new(0, 32, 0, 6), Size = UDim2.new(1, -62, 0, 22), BackgroundTransparency = 1, Text = tabTitle(t), TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 18}, card)
            local body = (e.view and e.view.preview) or (e.ntp and "iDroid\nPesquisar ou digitar URL" or (e.url or e.q or ""))
            new("TextLabel", {Position = UDim2.new(0, 8, 0, 34), Size = UDim2.new(1, -16, 1, -42), BackgroundTransparency = 1, Text = body, TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 9, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 18}, card)
            local x = iconButton(card, Icons.close, 12, C.text, UDim2.new(1, -28, 0, 5), UDim2.new(0, 24, 0, 24), 19)
            card.MouseButton1Click:Connect(function() switchTo(i) end)
            x.MouseButton1Click:Connect(function() closeTab(i) end)
        end
    end
    swNew.MouseButton1Click:Connect(function()
        table.insert(tabs, newTab())
        cur = #tabs
        switcher.Visible = false
        render()
    end)

    local panel = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = C.bg, BorderSizePixel = 0, Visible = false, ZIndex = 15}, area)
    local panelBack = iconButton(panel, Icons.back, 16, C.text, UDim2.new(0, 6, 0, 4), UDim2.new(0, 34, 0, 34), 16)
    local panelTitle = new("TextLabel", {Position = UDim2.new(0, 44, 0, 4), Size = UDim2.new(1, -140, 0, 34), BackgroundTransparency = 1, Text = "", TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 16}, panel)
    local panelClear = new("TextButton", {Position = UDim2.new(1, -82, 0, 8), Size = UDim2.new(0, 72, 0, 26), BackgroundColor3 = C.card, BorderSizePixel = 0, Text = "LIMPAR", TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 10, ZIndex = 16}, panel)
    corner(panelClear, UDim.new(0, 13))
    local panelList = new("ScrollingFrame", {Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(1, 0, 1, -42), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 16}, panel)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5)}, panelList)
    new("UIPadding", {PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, panelList)
    local panelKind = "fav"

    local function fillPanel()
        for _, c in ipairs(panelList:GetChildren()) do if c.Name == "Row" or c.Name == "Empty" then c:Destroy() end end
        if panelKind == "dl" then
            panelTitle.Text = "Downloads"
            panelClear.Visible = true
            local files = {}
            pcall(function()
                for _, f in ipairs(listfiles(DL_DIR)) do table.insert(files, tostring(f)) end
            end)
            if #files == 0 then
                new("TextLabel", {Name = "Empty", Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1, Text = "Nenhum download ainda.", TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 12, ZIndex = 17}, panelList)
                return
            end
            for i, f in ipairs(files) do
                local name = f:match("([^/\\]+)$") or f
                local ext = (name:match("%.(%w+)$") or ""):lower()
                local isAudio = ext == "mp3" or ext == "ogg"
                local isImg = ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "gif"
                local hint = isAudio and "Toque para enviar à Música" or (isImg and "Toque para salvar na Galeria" or "PHONE/Downloads")
                local row = new("TextButton", {
                    Name = "Row", LayoutOrder = i, Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.card, BorderSizePixel = 0, AutoButtonColor = true, RichText = true,
                    Text = "<b>" .. U.esc(name:sub(1, 30)) .. '</b>\n<font color="#9aa0a6" size="10">' .. U.esc(hint) .. "</font>",
                    TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 17,
                }, panelList)
                corner(row, UDim.new(0, 10))
                new("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 34)}, row)
                row.MouseButton1Click:Connect(function()
                    if isAudio then toast(U.sendTo(f, "PHONE/Music") and "Enviado para Música" or "Falha ao copiar")
                    elseif isImg then toast(U.sendTo(f, "PHONE/Photos") and "Salvo na Galeria" or "Falha ao copiar")
                    else toast(f) end
                end)
                local x = iconButton(row, Icons.close, 12, C.sub, UDim2.new(1, -62, 0.5, -12), UDim2.new(0, 24, 0, 24), 18)
                x.MouseButton1Click:Connect(function()
                    pcall(delfile, f)
                    fillPanel()
                end)
            end
            return
        end
        local data = panelKind == "fav" and bookmarks() or history()
        panelTitle.Text = panelKind == "fav" and "Favoritos" or "Histórico"
        panelClear.Visible = panelKind == "hist"
        if #data == 0 then
            new("TextLabel", {Name = "Empty", Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1, Text = panelKind == "fav" and "Nenhum favorito ainda." or "Histórico vazio.", TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 12, ZIndex = 17}, panelList)
            return
        end
        for i, it in ipairs(data) do
            local name = it.name or it.title or U.hostOf(it.url)
            local row = new("TextButton", {
                Name = "Row", LayoutOrder = i, Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.card, BorderSizePixel = 0, AutoButtonColor = true, RichText = true,
                Text = "<b>" .. U.esc(name:sub(1, 30)) .. '</b>\n<font color="#9aa0a6" size="10">' .. U.esc(U.hostOf(it.url):sub(1, 34)) .. "</font>",
                TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 17,
            }, panelList)
            corner(row, UDim.new(0, 10))
            new("UIPadding", {PaddingLeft = UDim.new(0, 44), PaddingRight = UDim.new(0, panelKind == "fav" and 34 or 8)}, row)
            favicon(row, it.url, 24, 18).Position = UDim2.new(0, -34, 0.5, -12)
            row.MouseButton1Click:Connect(function()
                closeOverlays()
                navigate(tabs[cur], {url = it.url})
            end)
            if panelKind == "fav" then
                local x = iconButton(row, Icons.close, 12, C.sub, UDim2.new(1, -62, 0.5, -12), UDim2.new(0, 24, 0, 24), 18)
                x.MouseButton1Click:Connect(function()
                    table.remove(bookmarks(), i)
                    saveSettings()
                    fillPanel()
                end)
            end
        end
    end
    openPanel = function(kind)
        panelKind = kind
        panel.Visible = true
        fillPanel()
    end
    panelBack.MouseButton1Click:Connect(function() panel.Visible = false end)
    panelClear.MouseButton1Click:Connect(function()
        if panelKind == "dl" then
            pcall(function()
                for _, f in ipairs(listfiles(DL_DIR)) do pcall(delfile, f) end
            end)
            fillPanel()
            toast("Downloads apagados")
            return
        end
        phoneSettings.browserHistory = {}
        saveSettings()
        fillPanel()
        toast("Histórico limpo")
    end)

    local menuLayer = new("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, BorderSizePixel = 0, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 28}, frame)
    corner(menuLayer, UDim.new(0, 28))
    local menu = new("Frame", {Position = UDim2.new(0, 72, 0, 36), Size = UDim2.new(0, 200, 0, 260), BackgroundColor3 = C.toolbar, BorderSizePixel = 0, ZIndex = 30}, menuLayer)
    corner(menu, UDim.new(0, 14))
    new("UIStroke", {Color = Color3.fromRGB(70, 72, 76), Thickness = 1}, menu)

    local backBtn = iconButton(menu, Icons.back, 18, C.text, UDim2.new(0, 0, 0, 2), UDim2.new(0, 50, 0, 38), 31)
    local fwdBtn = iconButton(menu, Icons.arrowRight, 18, C.text, UDim2.new(0, 50, 0, 2), UDim2.new(0, 50, 0, 38), 31)
    heartBtn = iconButton(menu, Icons.heart, 18, C.text, UDim2.new(0, 100, 0, 2), UDim2.new(0, 50, 0, 38), 31)
    local reBtn = iconButton(menu, Icons.reset, 18, C.text, UDim2.new(0, 150, 0, 2), UDim2.new(0, 50, 0, 38), 31)
    new("Frame", {Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(70, 72, 76), BorderSizePixel = 0, ZIndex = 31}, menu)
    local menuScroll = new("ScrollingFrame", {Position = UDim2.new(0, 0, 0, 46), Size = UDim2.new(1, 0, 1, -50), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.sub, CanvasSize = UDim2.new(0, 0, 0, 308), ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 31}, menu)
    menuScroll.ClipsDescendants = true

    local engBtn
    local function setMenu(open)
        menuLayer.Visible = open
        if open then
            address:ReleaseFocus()
            if U.darkBtn then U.darkBtn.Text = "Modo escuro: " .. (U.dark.on and "ligado" or "desligado") end
            local t = tabs[cur]
            local e = curEntry()
            Icons.put(fwdBtn, Icons.arrowRight, 18, t.pos < #t.hist and C.text or Color3.fromRGB(95, 99, 104), 32)
            Icons.put(heartBtn, Icons.heart, 18, isBookmarked(e.url) and C.red or C.text, 32)
        end
    end
    local function menuItem(text, y, fn)
        local b = new("TextButton", {Position = UDim2.new(0, 0, 0, y - 46), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = text, TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = true, ZIndex = 32}, menuScroll)
        new("UIPadding", {PaddingLeft = UDim.new(0, 16)}, b)
        b.MouseButton1Click:Connect(function() setMenu(false); fn() end)
        return b
    end
    menuItem("Nova guia", 46, function()
        table.insert(tabs, newTab())
        cur = #tabs
        render()
    end)
    menuItem("Favoritos", 74, function() openPanel("fav") end)
    menuItem("Histórico", 102, function() openPanel("hist") end)
    menuItem("Copiar URL", 130, function()
        local e = curEntry()
        local clip = setclipboard or toclipboard
        if not e.url then toast("Nenhuma URL para copiar")
        elseif type(clip) == "function" then pcall(clip, e.url); toast("Link copiado")
        else toast("Clipboard indisponível") end
    end)
    menuItem("Limpar histórico", 158, function()
        phoneSettings.browserHistory = {}
        saveSettings()
        toast("Histórico limpo")
    end)
    menuItem("Limpar cache de imagens", 186, function()
        toast("Cache limpo (" .. U.purgeCache() .. " arquivos)")
        if curEntry().view and curEntry().view.kind == "images" then render() end
    end)
    menuItem("Downloads", 214, function() openPanel("dl") end)
    menuItem("Modo: site / leitura / texto", 242, function()
        local e = curEntry()
        if not (e.view and e.view.kind == "page") then toast("Abra uma página primeiro") return end
        local nm
        if e.reader then e.reader = nil; e.simple = true; nm = "texto"
        elseif e.simple then e.simple = nil; nm = "site"
        else e.reader = true; nm = "leitura" end
        render()
        toast("Modo " .. nm)
    end)
    menuItem("Buscar neste site", 270, function()
        if U.openSite then U.openSite() else toast("Busca neste site indisponível") end
    end)
    U.darkBtn = menuItem("Modo escuro: " .. (U.dark.on and "ligado" or "desligado"), 298, function()
        U.dark.on = not U.dark.on
        phoneSettings.browserDark = U.dark.on
        saveSettings()
        toast(U.dark.on and "Modo escuro ligado" or "Modo escuro desligado")
        local e = curEntry()
        if e and e.view and e.view.kind == "page" then render() end
    end)

    backBtn.MouseButton1Click:Connect(function()
        setMenu(false)
        if Nav.web.goBack() == false then showScreen("home", true) end
    end)
    fwdBtn.MouseButton1Click:Connect(function()
        setMenu(false)
        local t = tabs[cur]
        if t.pos < #t.hist then t.pos = t.pos + 1; showEntry(t) end
    end)
    heartBtn.MouseButton1Click:Connect(function()
        setMenu(false)
        local e = curEntry()
        if not e.url then toast("Abra uma página para favoritar"); return end
        local yes, idx = isBookmarked(e.url)
        if yes then
            table.remove(bookmarks(), idx)
            toast("Favorito removido")
        else
            table.insert(bookmarks(), {name = (e.title or U.hostOf(e.url)):sub(1, 24), url = e.url})
            toast("Adicionado aos favoritos")
        end
        saveSettings()
        if curEntry().ntp then render() end
    end)
    reBtn.MouseButton1Click:Connect(function() setMenu(false); reload() end)
    menuLayer.MouseButton1Click:Connect(function() setMenu(false) end)
    menuBtn.MouseButton1Click:Connect(function() setMenu(not menuLayer.Visible) end)

    closeOverlays = function()
        menuLayer.Visible = false
        switcher.Visible = false
        panel.Visible = false
        viewer.Visible = false
        viewerToken = viewerToken + 1
    end

    tabBtn.MouseButton1Click:Connect(function()
        address:ReleaseFocus()
        if switcher.Visible then
            switcher.Visible = false
        else
            panel.Visible = false
            viewer.Visible = false
            switcher.Visible = true
            refreshSwitcher()
        end
    end)

    address.Focused:Connect(function()
        address.TextTruncate = Enum.TextTruncate.None
        address.Text = fullText(curEntry())
        task.defer(function()
            pcall(function()
                address.SelectionStart = 1
                address.CursorPosition = #address.Text + 1
            end)
        end)
    end)
    address.FocusLost:Connect(function(enter)
        address.TextTruncate = Enum.TextTruncate.AtEnd
        if enter then runInput(address.Text) end
        updateChrome()
    end)
    reloadBtn.MouseButton1Click:Connect(function()
        if curEntry().state == "loading" then stopLoad() else reload() end
    end)

    Nav.web = {}
    Nav.web.goBack = function()
        if viewer.Visible then viewer.Visible = false; viewerToken = viewerToken + 1; return true end
        if menuLayer.Visible or switcher.Visible or panel.Visible then closeOverlays(); return true end
        if address:IsFocused() then address:ReleaseFocus(); return true end
        local t = tabs[cur]
        if t.pos > 1 then t.pos = t.pos - 1; showEntry(t); return true end
        return false
    end
    -- fecha o app de verdade: descarta todas as guias e volta pra "Nova guia"
    Nav.web.reset = function()
        pcall(function() address:ReleaseFocus() end)
        viewer.Visible = false
        viewerToken = viewerToken + 1
        pcall(closeOverlays)
        for k in pairs(tabs) do tabs[k] = nil end
        tabs[1] = newTab()
        cur = 1
        pcall(render)
    end

    createNavBar(frame)
    render()
    return frame
end

local WebBrowserFrame = makeBrowserScreen()

do
    local BG = Color3.fromRGB(15, 15, 20)
    local CARDC = Color3.fromRGB(30, 30, 38)
    local SUBC = Color3.fromRGB(150, 150, 165)
    local TXT = Color3.fromRGB(235, 235, 242)

    local function nw(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props) do o[k] = v end
        if parent then o.Parent = parent end
        return o
    end

    local function makeApp(name)
        local f = nw("Frame", {Name = name .. "Frame", Size = UDim2.new(0, 280, 0, 440), Position = PhoneHome.Position, BackgroundColor3 = BG, BorderSizePixel = 0, Visible = false, Active = true}, ScreenGui)
        corner(f, UDim.new(0, 28))
        Nav.shell.create(f)
        Nav.status.create(f)
        return f
    end

    local function titleBar(frame, iconFn, color, text)
        local t = nw("TextLabel", {Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 46), BackgroundTransparency = 1, Text = text, TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 20, ZIndex = 5}, frame)
        Icons.text(t, {icon = iconFn, iconSize = 24, gap = 8, color = color, text = text})
        return t
    end

    local function mkToast(parent)
        local lbl = nw("TextLabel", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -46), Size = UDim2.new(0, 0, 0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.fromRGB(60, 64, 67), Text = "", TextColor3 = WHITE, Font = Enum.Font.Gotham, TextSize = 11, Visible = false, ZIndex = 40, TextTruncate = Enum.TextTruncate.AtEnd, ClipsDescendants = true}, parent)
        corner(lbl, UDim.new(0, 13))
        nw("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)}, lbl)
        nw("UISizeConstraint", {MaxSize = Vector2.new(244, 26)}, lbl)
        local id = 0
        return function(msg)
            id = id + 1
            local my = id
            lbl.Text = msg
            lbl.Visible = true
            task.delay(1.6, function() if my == id then lbl.Visible = false end end)
        end
    end

    function Icons.notepad(parent, S, color, z)
        local c, u = iconRoot(parent, S)
        Draw.rrect(c, 12 * u, 12 * u, 16 * u, 19 * u, 3 * u, color, T(2.2, u), z)
        Draw.line(c, 8 * u, 9 * u, 16 * u, 9 * u, T(1.8, u), color, z)
        Draw.line(c, 8 * u, 13 * u, 16 * u, 13 * u, T(1.8, u), color, z)
        Draw.line(c, 8 * u, 17 * u, 13 * u, 17 * u, T(1.8, u), color, z)
        return c
    end

    function Icons.plus(parent, S, color, z)
        local c, u = iconRoot(parent, S)
        Draw.line(c, 12 * u, 4.5 * u, 12 * u, 19.5 * u, T(2.8, u), color, z)
        Draw.line(c, 4.5 * u, 12 * u, 19.5 * u, 12 * u, T(2.8, u), color, z)
        return c
    end

    function Icons.trash(parent, S, color, z)
        local c, u = iconRoot(parent, S)
        Draw.rrect(c, 12 * u, 14 * u, 12 * u, 13 * u, 2.4 * u, color, T(2.1, u), z)
        Draw.line(c, 4.5 * u, 7 * u, 19.5 * u, 7 * u, T(2.2, u), color, z)
        Draw.line(c, 9.5 * u, 4 * u, 14.5 * u, 4 * u, T(2.2, u), color, z)
        return c
    end

    function Icons.copyDoc(parent, S, color, z)
        local c, u = iconRoot(parent, S)
        Draw.rrect(c, 10 * u, 10 * u, 11 * u, 13 * u, 2.4 * u, color, T(2.1, u), z)
        Draw.rrect(c, 14.5 * u, 14.5 * u, 11 * u, 13 * u, 2.4 * u, color, T(2.1, u), z)
        return c
    end

    function Icons.sun(parent, S, color, z)
        local c, u = iconRoot(parent, S)
        Draw.circle(c, 12 * u, 12 * u, 9 * u, color, nil, z)
        for k = 0, 7 do
            local rad = math.rad(k * 45)
            local sx, sy = math.sin(rad), -math.cos(rad)
            Draw.line(c, 12 * u + 7.2 * u * sx, 12 * u + 7.2 * u * sy, 12 * u + 10 * u * sx, 12 * u + 10 * u * sy, T(2, u), color, z)
        end
        return c
    end

    local function cloudShape(c, u, color, z, dx, dy, k)
        dx, dy, k = dx or 0, dy or 0, k or 1
        Draw.circle(c, (8.2 * k + dx) * u, (14 * k + dy) * u, 8 * k * u, color, nil, z)
        Draw.circle(c, (13.6 * k + dx) * u, (11.4 * k + dy) * u, 10 * k * u, color, nil, z)
        Draw.circle(c, (17.6 * k + dx) * u, (15 * k + dy) * u, 6.6 * k * u, color, nil, z)
        Draw.rrect(c, (12.4 * k + dx) * u, (16.6 * k + dy) * u, 14.6 * k * u, 6 * k * u, 3 * k * u, color, nil, z)
    end

    function Icons.cloud(parent, S, color, z)
        local c, u = iconRoot(parent, S)
        cloudShape(c, u, color, z, 0, 0, 1)
        return c
    end

    function Icons.weather(parent, S, color, z)
        local c, u = iconRoot(parent, S)
        Draw.circle(c, 8 * u, 8 * u, 8 * u, color, nil, z)
        for k = 0, 4 do
            local rad = math.rad(-90 + k * 45 - 45)
            local sx, sy = math.sin(rad + math.pi / 2), -math.cos(rad + math.pi / 2)
            Draw.line(c, 8 * u + 6 * u * sx, 8 * u + 6 * u * sy, 8 * u + 8.4 * u * sx, 8 * u + 8.4 * u * sy, T(1.8, u), color, z)
        end
        cloudShape(c, u, color, z, 2.2, 3, 0.86)
        return c
    end

    function Icons.rain(parent, S, color, z)
        local c, u = iconRoot(parent, S)
        cloudShape(c, u, color, z, 0, -3.4, 0.9)
        for _, x in ipairs({7, 12, 17}) do
            Draw.line(c, x * u, 17 * u, (x - 1.6) * u, 21 * u, T(1.9, u), color, z)
        end
        return c
    end

    function Icons.snow(parent, S, color, z)
        local c, u = iconRoot(parent, S)
        cloudShape(c, u, color, z, 0, -3.4, 0.9)
        for _, x in ipairs({7.5, 12, 16.5}) do
            Draw.circle(c, x * u, 19.5 * u, 2.4 * u, color, nil, z)
        end
        return c
    end

    function Icons.storm(parent, S, color, z)
        local c, u = iconRoot(parent, S)
        cloudShape(c, u, color, z, 0, -3.6, 0.9)
        Draw.line(c, 13 * u, 15 * u, 10 * u, 19 * u, T(2.2, u), color, z)
        Draw.line(c, 10 * u, 19 * u, 14 * u, 19 * u, T(2.2, u), color, z)
        Draw.line(c, 14 * u, 19 * u, 11 * u, 23 * u, T(2.2, u), color, z)
        return c
    end

    function Icons.fog(parent, S, color, z)
        local c, u = iconRoot(parent, S)
        Draw.line(c, 4 * u, 8 * u, 20 * u, 8 * u, T(2.4, u), color, z)
        Draw.line(c, 7 * u, 12.5 * u, 22 * u, 12.5 * u, T(2.4, u), color, z)
        Draw.line(c, 3 * u, 17 * u, 17 * u, 17 * u, T(2.4, u), color, z)
        return c
    end

    function Icons.calc(parent, S, color, z)
        local c, u = iconRoot(parent, S)
        Draw.rrect(c, 12 * u, 12 * u, 16 * u, 20 * u, 3 * u, color, T(2.2, u), z)
        Draw.rrect(c, 12 * u, 7.4 * u, 10 * u, 4 * u, 1 * u, color, nil, z)
        for _, x in ipairs({8.6, 15.4}) do
            for _, y in ipairs({13, 17.6}) do
                Draw.circle(c, x * u, y * u, 2.6 * u, color, nil, z)
            end
        end
        return c
    end

    local notesHooks = {}

    local function buildNotes()
        local f = makeApp("Notes")
        local toast = mkToast(f)
        local YEL = Color3.fromRGB(245, 190, 50)
        titleBar(f, Icons.notepad, YEL, "Notas")
        local NOTES_DIR = "PHONE/Notes"
        local notes = {}
        local current

        local listView = nw("Frame", {Position = UDim2.new(0, 0, 0, 84), Size = UDim2.new(1, 0, 0, 312), BackgroundTransparency = 1, ZIndex = 3}, f)
        local list = nw("ScrollingFrame", {Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -24, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = YEL, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 4}, listView)
        nw("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, list)

        local addBtn = nw("TextButton", {Position = UDim2.new(1, -46, 0, 44), Size = UDim2.new(0, 32, 0, 32), BackgroundColor3 = YEL, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 6}, f)
        corner(addBtn, UDim.new(1, 0))
        Icons.put(addBtn, Icons.plus, 18, Color3.fromRGB(30, 25, 5), 7)

        local editor = nw("Frame", {Position = UDim2.new(0, 0, 0, 84), Size = UDim2.new(1, 0, 0, 312), BackgroundColor3 = BG, BorderSizePixel = 0, Visible = false, ZIndex = 8}, f)
        local function edBtn(pos, fn)
            local b = nw("TextButton", {Position = pos, Size = UDim2.new(0, 34, 0, 32), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 9}, editor)
            Icons.put(b, fn, 18, TXT, 10)
            return b
        end
        local edBack = edBtn(UDim2.new(0, 8, 0, 0), Icons.back)
        local edTitle = nw("TextLabel", {Position = UDim2.new(0, 44, 0, 0), Size = UDim2.new(1, -130, 0, 32), BackgroundTransparency = 1, Text = "", TextColor3 = TXT, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 9}, editor)
        local edCopy = edBtn(UDim2.new(1, -78, 0, 0), Icons.copyDoc)
        local edDel = edBtn(UDim2.new(1, -42, 0, 0), Icons.trash)
        local box = nw("TextBox", {Position = UDim2.new(0, 12, 0, 38), Size = UDim2.new(1, -24, 1, -44), BackgroundColor3 = CARDC, BorderSizePixel = 0, Text = "", PlaceholderText = "Escreva sua nota...", PlaceholderColor3 = SUBC, TextColor3 = TXT, Font = Enum.Font.Gotham, TextSize = 13, TextWrapped = true, MultiLine = true, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ClipsDescendants = true, ZIndex = 9}, editor)
        corner(box, UDim.new(0, 12))
        nw("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)}, box)

        local function noteTitle(text)
            for line in text:gmatch("[^\r\n]+") do
                local t = line:gsub("^%s+", ""):gsub("%s+$", "")
                if t ~= "" then return t:sub(1, 40) end
            end
            return "Nota vazia"
        end

        local function loadNotes()
            local old = notes
            notes = {}
            local seen = {}
            local ok, files = pcall(listfiles, NOTES_DIR)
            if ok and type(files) == "table" then
                for _, p in ipairs(files) do
                    local name = tostring(p):match("([^/\\]+)$") or ""
                    local id = name:match("^(.+)%.txt$")
                    if id then
                        local okR, txt = pcall(readfile, p)
                        seen[id] = true
                        table.insert(notes, {id = id, text = (okR and type(txt) == "string") and txt or ""})
                    end
                end
            end
            for _, n in ipairs(old) do
                if n.memOnly and not seen[n.id] then table.insert(notes, n) end
            end
            table.sort(notes, function(a, b) return a.id > b.id end)
        end

        local function refreshList()
            for _, c in ipairs(list:GetChildren()) do
                if c.Name == "Row" or c.Name == "Empty" then c:Destroy() end
            end
            if #notes == 0 then
                nw("TextLabel", {Name = "Empty", Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1, Text = "Nenhuma nota ainda.\nToque no + para criar.", TextColor3 = SUBC, Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true, ZIndex = 5}, list)
                return
            end
            for i, n in ipairs(notes) do
                local row = nw("TextButton", {Name = "Row", LayoutOrder = i, Size = UDim2.new(1, -4, 0, 54), BackgroundColor3 = CARDC, BorderSizePixel = 0, Text = "", AutoButtonColor = true, ZIndex = 5}, list)
                corner(row, UDim.new(0, 12))
                nw("TextLabel", {Position = UDim2.new(0, 12, 0, 8), Size = UDim2.new(1, -24, 0, 18), BackgroundTransparency = 1, Text = noteTitle(n.text), TextColor3 = TXT, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6}, row)
                local when = tonumber(n.id:sub(1, 10))
                local stamp = when and os.date("%d/%m/%Y %H:%M", when) or ""
                nw("TextLabel", {Position = UDim2.new(0, 12, 0, 28), Size = UDim2.new(1, -24, 0, 16), BackgroundTransparency = 1, Text = stamp .. "  -  " .. #n.text .. " caracteres", TextColor3 = SUBC, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6}, row)
                row.MouseButton1Click:Connect(function()
                    current = n
                    box.Text = n.text
                    edTitle.Text = noteTitle(n.text)
                    listView.Visible = false
                    addBtn.Visible = false
                    editor.Visible = true
                end)
            end
        end

        local function removeNote(n)
            for i, x in ipairs(notes) do
                if x == n then table.remove(notes, i) break end
            end
            pcall(delfile, NOTES_DIR .. "/" .. n.id .. ".txt")
        end

        local function saveCurrent()
            if not current then return end
            local text = box.Text
            if not text:find("%S") then
                removeNote(current)
            else
                current.text = text
                local okW = pcall(writefile, NOTES_DIR .. "/" .. current.id .. ".txt", text)
                current.memOnly = not okW
            end
        end

        local function showList()
            saveCurrent()
            current = nil
            editor.Visible = false
            listView.Visible = true
            addBtn.Visible = true
            refreshList()
        end

        addBtn.MouseButton1Click:Connect(function()
            pcall(function()
                if not isfolder("PHONE") then makefolder("PHONE") end
                if not isfolder(NOTES_DIR) then makefolder(NOTES_DIR) end
            end)
            local n = {id = string.format("%010d%03d", os.time(), math.random(0, 999)), text = ""}
            table.insert(notes, 1, n)
            current = n
            box.Text = ""
            edTitle.Text = "Nova nota"
            listView.Visible = false
            addBtn.Visible = false
            editor.Visible = true
            box:CaptureFocus()
        end)
        box.FocusLost:Connect(function()
            edTitle.Text = noteTitle(box.Text)
            saveCurrent()
        end)
        edBack.MouseButton1Click:Connect(showList)
        edCopy.MouseButton1Click:Connect(function()
            local clip = setclipboard or toclipboard
            if type(clip) == "function" and box.Text ~= "" then
                pcall(clip, box.Text)
                toast("Texto copiado")
            else
                toast("Nada para copiar")
            end
        end)
        edDel.MouseButton1Click:Connect(function()
            if current then removeNote(current) end
            current = nil
            toast("Nota apagada")
            showList()
        end)

        notesHooks.goBack = function()
            if editor.Visible then showList() return true end
            return false
        end
        notesHooks.onOpen = function()
            loadNotes()
            current = nil
            editor.Visible = false
            listView.Visible = true
            addBtn.Visible = true
            refreshList()
        end
        notesHooks.onClose = saveCurrent
        return f
    end

    local weatherHooks = {}

    local function buildWeather()
        local f = makeApp("Weather")
        local toast = mkToast(f)
        local BLUE = Color3.fromRGB(60, 150, 235)
        titleBar(f, Icons.weather, BLUE, "Clima")

        local cityBox = nw("TextBox", {Position = UDim2.new(0, 12, 0, 84), Size = UDim2.new(1, -92, 0, 34), BackgroundColor3 = CARDC, BorderSizePixel = 0, Text = "", PlaceholderText = "Cidade (ex: São Paulo)", PlaceholderColor3 = SUBC, TextColor3 = TXT, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, ClearTextOnFocus = false, ClipsDescendants = true, ZIndex = 5}, f)
        corner(cityBox, UDim.new(0, 12))
        nw("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 8)}, cityBox)
        local goBtn = nw("TextButton", {Position = UDim2.new(1, -72, 0, 84), Size = UDim2.new(0, 60, 0, 34), BackgroundColor3 = BLUE, BorderSizePixel = 0, Text = "Buscar", TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = true, ZIndex = 5}, f)
        corner(goBtn, UDim.new(0, 12))

        local body = nw("ScrollingFrame", {Position = UDim2.new(0, 12, 0, 126), Size = UDim2.new(1, -24, 0, 270), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = BLUE, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 4}, f)
        nw("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, body)

        local DAYS = {"Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"}
        local function wmo(code)
            code = tonumber(code) or -1
            local SUN, CLOUD, WATER, ICE = Color3.fromRGB(255, 205, 70), Color3.fromRGB(205, 210, 225), Color3.fromRGB(110, 175, 255), Color3.fromRGB(225, 240, 255)
            if code == 0 then return "Céu limpo", Icons.sun, SUN end
            if code == 1 or code == 2 then return "Parcialmente nublado", Icons.weather, SUN end
            if code == 3 then return "Nublado", Icons.cloud, CLOUD end
            if code == 45 or code == 48 then return "Neblina", Icons.fog, CLOUD end
            if (code >= 51 and code <= 57) then return "Garoa", Icons.rain, WATER end
            if (code >= 61 and code <= 67) or (code >= 80 and code <= 82) then return "Chuva", Icons.rain, WATER end
            if (code >= 71 and code <= 77) or code == 85 or code == 86 then return "Neve", Icons.snow, ICE end
            if code >= 95 then return "Tempestade", Icons.storm, Color3.fromRGB(255, 220, 90) end
            return "Variável", Icons.cloud, CLOUD
        end

        local order = 0
        local function add(inst)
            order = order + 1
            inst.LayoutOrder = order
            inst.Name = "Dyn"
            inst.Parent = body
            return inst
        end
        local function clear()
            order = 0
            for _, c in ipairs(body:GetChildren()) do
                if c.Name == "Dyn" then c:Destroy() end
            end
        end
        local function message(text, color)
            clear()
            add(nw("TextLabel", {Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1, Text = text, TextColor3 = color or SUBC, Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true, ZIndex = 5}))
        end

        local function temp(v)
            if type(v) ~= "number" then return "--" end
            return string.format("%d°", math.floor(v + 0.5))
        end

        local function build(res)
            clear()
            local p, w = res.place, res.w
            local cur = w.current or {}
            local desc, iconFn, iconColor = wmo(cur.weather_code)

            local hero = add(nw("Frame", {Size = UDim2.new(1, 0, 0, 122), BackgroundColor3 = CARDC, BorderSizePixel = 0, ZIndex = 5}))
            corner(hero, UDim.new(0, 16))
            local place = p.name or ""
            if p.admin1 and p.admin1 ~= "" and p.admin1 ~= p.name then place = place .. ", " .. p.admin1 end
            nw("TextLabel", {Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -28, 0, 18), BackgroundTransparency = 1, Text = place, TextColor3 = TXT, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6}, hero)
            nw("TextLabel", {Position = UDim2.new(0, 14, 0, 28), Size = UDim2.new(1, -28, 0, 14), BackgroundTransparency = 1, Text = p.country or "", TextColor3 = SUBC, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6}, hero)
            local ic = iconFn(hero, 54, iconColor, 7)
            ic.Position = UDim2.new(0, 14, 0, 52)
            nw("TextLabel", {Position = UDim2.new(0, 78, 0, 44), Size = UDim2.new(0, 110, 0, 50), BackgroundTransparency = 1, Text = temp(cur.temperature_2m), TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 40, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6}, hero)
            nw("TextLabel", {Position = UDim2.new(0, 14, 1, -24), Size = UDim2.new(1, -28, 0, 18), BackgroundTransparency = 1, Text = desc, TextColor3 = SUBC, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6}, hero)

            local stats = add(nw("Frame", {Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, ZIndex = 5}))
            nw("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, stats)
            local items = {
                {"Sensação", temp(cur.apparent_temperature)},
                {"Umidade", type(cur.relative_humidity_2m) == "number" and (math.floor(cur.relative_humidity_2m + 0.5) .. "%") or "--"},
                {"Vento", type(cur.wind_speed_10m) == "number" and (math.floor(cur.wind_speed_10m + 0.5) .. " km/h") or "--"},
            }
            for i, it in ipairs(items) do
                local card = nw("Frame", {LayoutOrder = i, Size = UDim2.new(1 / 3, -4, 1, 0), BackgroundColor3 = CARDC, BorderSizePixel = 0, ZIndex = 5}, stats)
                corner(card, UDim.new(0, 12))
                nw("TextLabel", {Position = UDim2.new(0, 0, 0, 6), Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = it[1], TextColor3 = SUBC, Font = Enum.Font.Gotham, TextSize = 10, ZIndex = 6}, card)
                nw("TextLabel", {Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = it[2], TextColor3 = TXT, Font = Enum.Font.GothamBold, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6}, card)
            end

            add(nw("TextLabel", {Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = "PRÓXIMOS DIAS", TextColor3 = BLUE, Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5}))
            local d = w.daily or {}
            for i, day in ipairs(d.time or {}) do
                local y, m, dd = day:match("^(%d+)-(%d+)-(%d+)")
                local name = day
                if y then
                    local t = os.date("*t", os.time({year = tonumber(y), month = tonumber(m), day = tonumber(dd), hour = 12}))
                    name = DAYS[t.wday] or day
                end
                if i == 1 then name = "Hoje" end
                local _, dIcon, dColor = wmo(d.weather_code and d.weather_code[i])
                local row = add(nw("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = CARDC, BorderSizePixel = 0, ZIndex = 5}))
                corner(row, UDim.new(0, 12))
                nw("TextLabel", {Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0, 50, 1, 0), BackgroundTransparency = 1, Text = name, TextColor3 = TXT, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6}, row)
                local di = dIcon(row, 22, dColor, 7)
                di.Position = UDim2.new(0, 68, 0.5, -11)
                local mx = d.temperature_2m_max and d.temperature_2m_max[i]
                local mn = d.temperature_2m_min and d.temperature_2m_min[i]
                nw("TextLabel", {Position = UDim2.new(0, 100, 0, 0), Size = UDim2.new(0, 80, 1, 0), BackgroundTransparency = 1, Text = temp(mn) .. " / " .. temp(mx), TextColor3 = TXT, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6}, row)
                local rain = d.precipitation_probability_max and d.precipitation_probability_max[i]
                nw("TextLabel", {Position = UDim2.new(1, -62, 0, 0), Size = UDim2.new(0, 52, 1, 0), BackgroundTransparency = 1, Text = type(rain) == "number" and (math.floor(rain + 0.5) .. "% chuva") or "", TextColor3 = Color3.fromRGB(110, 175, 255), Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6}, row)
            end
        end

        local token = 0
        local lastLoad, lastCity = 0, nil
        local function load(city)
            city = tostring(city or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if city == "" then
                message("Digite o nome de uma cidade e toque em Buscar.")
                return
            end
            token = token + 1
            local my = token
            message("Buscando previsão...")
            task.spawn(function()
                local ok, res = pcall(function()
                    local g = HttpService:JSONDecode(httpGetBody("https://geocoding-api.open-meteo.com/v1/search?name=" .. HttpService:UrlEncode(city) .. "&count=1&language=pt&format=json"))
                    local p = g.results and g.results[1]
                    if not p then error("Cidade não encontrada.", 0) end
                    local url = "https://api.open-meteo.com/v1/forecast?latitude=" .. p.latitude .. "&longitude=" .. p.longitude
                        .. "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m"
                        .. "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=5"
                    return {place = p, w = HttpService:JSONDecode(httpGetBody(url))}
                end)
                if my ~= token then return end
                if ok then
                    phoneSettings.weatherCity = city
                    saveSettings()
                    lastLoad, lastCity = os.clock(), city
                    cityBox.Text = city
                    build(res)
                else
                    message(tostring(res):sub(1, 120), Color3.fromRGB(255, 120, 120))
                end
            end)
        end

        goBtn.MouseButton1Click:Connect(function()
            cityBox:ReleaseFocus()
            load(cityBox.Text)
        end)
        cityBox.Focused:Connect(function() cityBox.TextTruncate = Enum.TextTruncate.None end)
        cityBox.FocusLost:Connect(function(enter)
            cityBox.TextTruncate = Enum.TextTruncate.AtEnd
            if enter then load(cityBox.Text) end
        end)

        weatherHooks.onOpen = function()
            local saved = phoneSettings.weatherCity
            if type(saved) == "string" and saved ~= "" then
                if cityBox.Text == "" then cityBox.Text = saved end
                if lastCity ~= saved or os.clock() - lastLoad > 600 then load(saved) end
            elseif lastCity == nil then
                message("Digite o nome de uma cidade e toque em Buscar.")
            end
        end
        return f
    end

    local function buildCalc()
        local f = makeApp("Calc")
        local ORG = Color3.fromRGB(255, 140, 40)
        titleBar(f, Icons.calc, Color3.fromRGB(240, 100, 70), "Calculadora")

        local exprLbl = nw("TextLabel", {Position = UDim2.new(0, 14, 0, 82), Size = UDim2.new(1, -28, 0, 16), BackgroundTransparency = 1, Text = "", TextColor3 = SUBC, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5}, f)
        local dispLbl = nw("TextLabel", {Position = UDim2.new(0, 14, 0, 98), Size = UDim2.new(1, -28, 0, 48), BackgroundTransparency = 1, Text = "0", TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 40, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5}, f)
        nw("UITextSizeConstraint", {MaxTextSize = 40, MinTextSize = 14}, dispLbl)

        local cur, acc, op, fresh = "0", nil, nil, true

        local function fmt(n)
            if n ~= n or n == math.huge or n == -math.huge then return "Erro" end
            if n == 0 then return "0" end
            if n == math.floor(n) and math.abs(n) < 1e15 then return string.format("%.0f", n) end
            return string.format("%.10g", n)
        end
        local function compute(a, o, b)
            if o == "+" then return a + b end
            if o == "-" then return a - b end
            if o == "×" then return a * b end
            if o == "÷" then
                if b == 0 then return nil end
                return a / b
            end
            return b
        end
        local function refresh()
            dispLbl.Text = cur
            exprLbl.Text = (acc and op) and (fmt(acc) .. " " .. op) or ""
        end
        local function reset()
            cur, acc, op, fresh = "0", nil, nil, true
        end

        local function press(k)
            if cur == "Erro" and k ~= "C" then reset() end
            if k == "C" then
                reset()
            elseif k:match("^%d$") then
                if fresh then cur = k else cur = (cur == "0") and k or (cur .. k) end
                if #cur > 14 then cur = cur:sub(1, 14) end
                fresh = false
            elseif k == "." then
                if fresh then cur = "0." elseif not cur:find("%.") then cur = cur .. "." end
                fresh = false
            elseif k == "±" then
                if cur ~= "0" then cur = (cur:sub(1, 1) == "-") and cur:sub(2) or ("-" .. cur) end
            elseif k == "%" then
                cur = fmt((tonumber(cur) or 0) / 100)
                fresh = true
            elseif k == "=" then
                if op and acc then
                    local b = tonumber(cur) or 0
                    local r = compute(acc, op, b)
                    exprLbl.Text = fmt(acc) .. " " .. op .. " " .. fmt(b) .. " ="
                    cur = r and fmt(r) or "Erro"
                    acc, op, fresh = nil, nil, true
                    dispLbl.Text = cur
                    return
                end
            else
                local val = tonumber(cur) or 0
                if acc and op and not fresh then
                    local r = compute(acc, op, val)
                    if not r then
                        reset()
                        cur = "Erro"
                        refresh()
                        return
                    end
                    acc = r
                    cur = fmt(r)
                else
                    acc = val
                end
                op = k
                fresh = true
            end
            refresh()
        end

        local layout = {
            {{"C", "fn"}, {"±", "fn"}, {"%", "fn"}, {"÷", "op"}},
            {{"7"}, {"8"}, {"9"}, {"×", "op"}},
            {{"4"}, {"5"}, {"6"}, {"-", "op"}},
            {{"1"}, {"2"}, {"3"}, {"+", "op"}},
            {{"0", "num", 2}, {"."}, {"=", "op"}},
        }
        local KW, KH, GAP = 57, 42, 8
        for r, row in ipairs(layout) do
            local col = 0
            for _, def in ipairs(row) do
                local key, kind, span = def[1], def[2] or "num", def[3] or 1
                local w = KW * span + GAP * (span - 1)
                local bg = kind == "op" and ORG or (kind == "fn" and Color3.fromRGB(85, 85, 100) or Color3.fromRGB(48, 48, 60))
                local b = nw("TextButton", {Position = UDim2.new(0, 14 + col * (KW + GAP), 0, 152 + (r - 1) * (KH + 6)), Size = UDim2.new(0, w, 0, KH), BackgroundColor3 = bg, BorderSizePixel = 0, Text = key, TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 18, AutoButtonColor = true, ZIndex = 5}, f)
                corner(b, UDim.new(0, 14))
                b.MouseButton1Click:Connect(function() press(key) end)
                col = col + span
            end
        end
        Nav.calc = {reset = function() reset(); refresh() end}
        return f
    end

    function Icons.camera(parent, S, color, z)
        local c, u = iconRoot(parent, S)
        -- corpo principal da câmera (retângulo arredondado grande)
        Draw.rrect(c, 12 * u, 13.6 * u, 20 * u, 14.2 * u, 3.6 * u, color, T(2.2, u), z)
        -- saliência do visor (topo centro)
        Draw.rrect(c, 10.5 * u, 6.4 * u, 6.6 * u, 2.8 * u, 1.3 * u, color, nil, z)
        -- lente principal (anel externo)
        Draw.circle(c, 12 * u, 13.9 * u, 8.2 * u, color, T(2.0, u), z)
        -- lente interna (anel intermediário)
        Draw.circle(c, 12 * u, 13.9 * u, 5.2 * u, color, T(1.4, u), z)
        -- pupila da lente (círculo cheio)
        Draw.circle(c, 12 * u, 13.9 * u, 2.2 * u, color, nil, z)
        -- flash LED (canto superior direito do corpo)
        Draw.circle(c, 18.6 * u, 7.6 * u, 1.8 * u, color, nil, z)
        -- botão disparador (topo direita)
        Draw.rrect(c, 17.6 * u, 7.1 * u, 2.6 * u, 1.4 * u, 0.7 * u, color, nil, z)
        return c
    end

    Nav.camera = {}

    local function buildCamera()
        local f = makeApp("Camera")
        f.BackgroundTransparency = 1
        local toast = mkToast(f)
        local ACC = Color3.fromRGB(255, 204, 0)
        local ACC_TXT = Color3.fromRGB(30, 24, 0)
        local DARK = Color3.fromRGB(0, 0, 0)
        local Lighting = game:GetService("Lighting")

        local FILTERS = {
            {name = "Normal", sat = 0, con = 0, bri = 0, tint = Color3.fromRGB(255, 255, 255)},
            {name = "P&B", sat = -1, con = 0.1, bri = 0, tint = Color3.fromRGB(255, 255, 255), ov = Color3.fromRGB(120, 120, 120), ova = 0.45},
            {name = "Sépia", sat = -0.45, con = 0.1, bri = 0.02, tint = Color3.fromRGB(255, 224, 178), ov = Color3.fromRGB(190, 140, 80), ova = 0.65},
            {name = "Vívido", sat = 0.7, con = 0.18, bri = 0, tint = Color3.fromRGB(255, 255, 255)},
            {name = "Frio", sat = 0.1, con = 0.05, bri = 0, tint = Color3.fromRGB(196, 222, 255), ov = Color3.fromRGB(110, 160, 255), ova = 0.8},
            {name = "Quente", sat = 0.15, con = 0.05, bri = 0.02, tint = Color3.fromRGB(255, 222, 196), ov = Color3.fromRGB(255, 150, 60), ova = 0.8},
            {name = "Noir", sat = -1, con = 0.5, bri = -0.05, tint = Color3.fromRGB(255, 255, 255), ov = Color3.fromRGB(40, 40, 40), ova = 0.55},
            {name = "Vintage", sat = -0.25, con = -0.1, bri = 0.05, tint = Color3.fromRGB(255, 236, 205), ov = Color3.fromRGB(230, 190, 130), ova = 0.75},
        }
        local ZOOMS = {0.5, 1, 2, 3}
        local TIMERS = {0, 3, 10}
        local MAX_PHOTOS, RADIUS, MAX_OBJECTS = 12, 320, 240
        local SELFIE_DIST, SELFIE_FOV = 5.5, 70

        local S = {active = false, selfie = false, boneco = false, flash = false, grid = true, timerIdx = 1, zoom = 1, filter = 1,
            busy = false, counting = false, cancel = false, photos = {}, viewIdx = 0, origFov = 70, baseFov = 70}

        local function cam() return Workspace.CurrentCamera end

        local sfx = nw("Sound", {SoundId = "rbxasset://sounds/switch.wav", Volume = 0.4}, f)
        local function ping(speed)
            sfx.Volume = 0.4 * (currentVolume or 1)
            sfx.PlaybackSpeed = speed or 1
            sfx:Play()
        end

        local function press(btn)
            local sc = nw("UIScale", {Scale = 1}, btn)
            btn.MouseButton1Down:Connect(function() TweenService:Create(sc, TweenInfo.new(0.08), {Scale = 0.9}):Play() end)
            local function up() TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back), {Scale = 1}):Play() end
            btn.MouseButton1Up:Connect(up)
            btn.MouseLeave:Connect(up)
        end

        local function pill(text, parent, order)
            local b = nw("TextButton", {Size = UDim2.new(0, 0, 0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = DARK, BackgroundTransparency = 0.45, BorderSizePixel = 0, Text = text, TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false, ZIndex = 10, LayoutOrder = order or 0}, parent)
            corner(b, UDim.new(1, 0))
            nw("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, b)
            press(b)
            return b
        end

        local gridFrame = nw("Frame", {Size = UDim2.new(1, 0, 0, 262), BackgroundTransparency = 1, ZIndex = 3}, f)
        for i = 1, 2 do
            nw("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(i / 3, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.75, BorderSizePixel = 0, ZIndex = 3}, gridFrame)
            nw("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, i / 3, 0), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.75, BorderSizePixel = 0, ZIndex = 3}, gridFrame)
        end

        local topRow = nw("Frame", {Position = UDim2.new(0, 0, 0, 46), Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, ZIndex = 10}, f)
        nw("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, topRow)
        local btnFlash = pill("⚡ Off", topRow, 1)
        local btnTimer = pill("⏱ 0s", topRow, 2)
        local btnGrid = pill("▦ Grade", topRow, 3)
        local btnBoneco = pill("🧍 Boneco", topRow, 4)

        local panel = nw("Frame", {Position = UDim2.new(0, 0, 0, 262), Size = UDim2.new(1, 0, 0, 178), BackgroundColor3 = DARK, BorderSizePixel = 0, ZIndex = 6}, f)
        corner(panel, UDim.new(0, 28))
        nw("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 0.15)})}, panel)

        local zoomRow = nw("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.new(0, 0, 0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = DARK, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 8}, panel)
        corner(zoomRow, UDim.new(1, 0))
        nw("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center}, zoomRow)
        nw("UIPadding", {PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2)}, zoomRow)
        local zoomBtns = {}
        for i, z in ipairs(ZOOMS) do
            local b = nw("TextButton", {Size = UDim2.new(0, 34, 0, 18), BackgroundColor3 = ACC, BackgroundTransparency = 1, BorderSizePixel = 0, Text = (z == 0.5 and ".5" or tostring(z)) .. "x", TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 10, AutoButtonColor = false, ZIndex = 9}, zoomRow)
            corner(b, UDim.new(1, 0))
            zoomBtns[i] = b
        end

        local filterRow = nw("ScrollingFrame", {Position = UDim2.new(0, 8, 0, 34), Size = UDim2.new(1, -16, 0, 26), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X, ZIndex = 8}, panel)
        nw("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, filterRow)
        local chipBtns = {}
        for i, fl in ipairs(FILTERS) do
            local b = nw("TextButton", {Size = UDim2.new(0, 0, 0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = DARK, BackgroundTransparency = 0.45, BorderSizePixel = 0, Text = fl.name, TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 10, AutoButtonColor = false, LayoutOrder = i, ZIndex = 9}, filterRow)
            corner(b, UDim.new(1, 0))
            nw("UIPadding", {PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9)}, b)
            chipBtns[i] = b
        end

        local thumb = nw("TextButton", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 46, 0, 98), Size = UDim2.new(0, 38, 0, 38), BackgroundColor3 = CARDC, BorderSizePixel = 0, Text = "▣", TextColor3 = SUBC, Font = Enum.Font.GothamBold, TextSize = 16, AutoButtonColor = false, ClipsDescendants = true, ZIndex = 8}, panel)
        corner(thumb, UDim.new(0, 10))
        nw("UIStroke", {Color = WHITE, Thickness = 1.5, Transparency = 0.5}, thumb)
        press(thumb)

        local shutter = nw("TextButton", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 98), Size = UDim2.new(0, 54, 0, 54), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 8}, panel)
        local ring = nw("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 8}, shutter)
        corner(ring, UDim.new(1, 0))
        nw("UIStroke", {Color = WHITE, Thickness = 3}, ring)
        local core = nw("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 42, 0, 42), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 9}, shutter)
        corner(core, UDim.new(1, 0))
        shutter.MouseButton1Down:Connect(function() TweenService:Create(core, TweenInfo.new(0.08), {Size = UDim2.new(0, 35, 0, 35)}):Play() end)
        local function shutterUp() TweenService:Create(core, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Size = UDim2.new(0, 42, 0, 42)}):Play() end
        shutter.MouseButton1Up:Connect(shutterUp)
        shutter.MouseLeave:Connect(shutterUp)

        local btnFlip = nw("TextButton", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 234, 0, 98), Size = UDim2.new(0, 38, 0, 38), BackgroundColor3 = DARK, BackgroundTransparency = 0.45, BorderSizePixel = 0, Text = "⟲", TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 20, AutoButtonColor = false, ZIndex = 8}, panel)
        corner(btnFlip, UDim.new(1, 0))
        press(btnFlip)

        local cdLabel = nw("TextLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.new(0, 120, 0, 120), BackgroundTransparency = 1, Text = "", TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 90, TextStrokeTransparency = 0.5, Visible = false, ZIndex = 14}, f)
        local cdScale = nw("UIScale", {Scale = 1}, cdLabel)
        local flashFrame = nw("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, ZIndex = 15}, f)
        corner(flashFrame, UDim.new(0, 28))

        local roll = nw("Frame", {Position = UDim2.new(0, 0, 0, 44), Size = UDim2.new(1, 0, 0, 358), BackgroundColor3 = BG, BorderSizePixel = 0, Visible = false, Active = true, ZIndex = 9}, f)
        local rollTitle = nw("TextLabel", {Position = UDim2.new(0, 14, 0, 2), Size = UDim2.new(1, -28, 0, 28), BackgroundTransparency = 1, Text = "Fotos", TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 10}, roll)
        local rollScroll = nw("ScrollingFrame", {Position = UDim2.new(0, 11, 0, 34), Size = UDim2.new(1, -22, 0, 320), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = ACC, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 10}, roll)
        nw("UIGridLayout", {CellSize = UDim2.new(0, 82, 0, 82), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, rollScroll)
        local rollEmpty = nw("TextLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.45, 0), Size = UDim2.new(1, -40, 0, 50), BackgroundTransparency = 1, Text = "Nenhuma foto ainda.\nToque no botão branco para tirar.", TextColor3 = SUBC, Font = Enum.Font.Gotham, TextSize = 12, ZIndex = 10}, roll)

        local viewer = nw("Frame", {Position = UDim2.new(0, 0, 0, 44), Size = UDim2.new(1, 0, 0, 358), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, Visible = false, Active = true, ZIndex = 12}, f)
        local vwCounter = nw("TextLabel", {Position = UDim2.new(0, 14, 0, 2), Size = UDim2.new(1, -28, 0, 20), BackgroundTransparency = 1, Text = "", TextColor3 = SUBC, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 13}, viewer)
        local vwArea = nw("Frame", {Position = UDim2.new(0, 8, 0, 24), Size = UDim2.new(1, -16, 0, 248), BackgroundTransparency = 1, ZIndex = 13}, viewer)
        local vwHolder = nw("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 13}, vwArea)
        corner(vwHolder, UDim.new(0, 4))
        local vwRatio = nw("UIAspectRatioConstraint", {AspectRatio = 1.6, AspectType = Enum.AspectType.FitWithinMaxSize, DominantAxis = Enum.DominantAxis.Width}, vwHolder)
        nw("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4)}, vwHolder)
        local vwInner = nw("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 14}, vwHolder)
        local vwCaption = nw("TextLabel", {Position = UDim2.new(0, 10, 0, 276), Size = UDim2.new(1, -20, 0, 18), BackgroundTransparency = 1, Text = "", TextColor3 = SUBC, Font = Enum.Font.Gotham, TextSize = 11, ZIndex = 13}, viewer)
        local vwBar = nw("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 304), Size = UDim2.new(0, 0, 0, 36), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 13}, viewer)
        nw("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, vwBar)
        local function vwBtn(order, text)
            local b = nw("TextButton", {Size = UDim2.new(0, 36, 0, 36), BackgroundColor3 = CARDC, BorderSizePixel = 0, Text = text or "", TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 20, AutoButtonColor = false, LayoutOrder = order, ZIndex = 14}, vwBar)
            corner(b, UDim.new(1, 0))
            press(b)
            return b
        end
        local vwPrev = vwBtn(1, "‹")
        local vwSave = vwBtn(2, "⬇")
        local vwDel = vwBtn(3)
        Icons.put(vwDel, Icons.trash, 18, Color3.fromRGB(255, 92, 88), 15)
        local vwNext = vwBtn(4, "›")

        local ccEffect
        local function applyFilter(i, instant)
            S.filter = i
            local fl = FILTERS[i]
            if ccEffect then
                local props = {Saturation = fl.sat, Contrast = fl.con, Brightness = fl.bri, TintColor = fl.tint}
                if instant then
                    for k, v in pairs(props) do ccEffect[k] = v end
                else
                    TweenService:Create(ccEffect, TweenInfo.new(0.3), props):Play()
                end
            end
            for idx, b in ipairs(chipBtns) do
                local on = idx == i
                TweenService:Create(b, TweenInfo.new(0.2), {BackgroundColor3 = on and ACC or DARK, BackgroundTransparency = on and 0 or 0.45, TextColor3 = on and ACC_TXT or WHITE}):Play()
            end
        end

        local function setZoom(z, instant)
            S.zoom = z
            local c = cam()
            if c and S.active then
                local fov = math.clamp(S.baseFov / z, 15, 120)
                if instant then c.FieldOfView = fov else TweenService:Create(c, TweenInfo.new(0.3), {FieldOfView = fov}):Play() end
            end
            for i, b in ipairs(zoomBtns) do
                local on = ZOOMS[i] == z
                TweenService:Create(b, TweenInfo.new(0.18), {BackgroundTransparency = on and 0 or 1, TextColor3 = on and ACC_TXT or WHITE}):Play()
            end
        end

        local function refreshTop()
            btnFlash.Text = S.flash and "⚡ On" or "⚡ Off"
            btnFlash.TextColor3 = S.flash and ACC or WHITE
            local t = TIMERS[S.timerIdx]
            btnTimer.Text = "⏱ " .. t .. "s"
            btnTimer.TextColor3 = t > 0 and ACC or WHITE
            btnGrid.TextColor3 = S.grid and ACC or WHITE
            gridFrame.Visible = S.grid
            -- indicador visual do modo boneco
            btnBoneco.TextColor3 = S.boneco and ACC or WHITE
            btnBoneco.BackgroundTransparency = S.boneco and 0 or 0.45
            btnBoneco.BackgroundColor3 = S.boneco and ACC or DARK
        end

        -- Modo câmera: "normal" | "selfie" | "boneco"
        -- "boneco" = câmera recua e enquadra o corpo inteiro do personagem
        local BONECO_DIST = 9    -- distância atrás-e-acima do personagem
        local BONECO_FOV  = 55   -- FOV mais fechado para enquadrar bem

        local selfieConn, bonecoConn, prevCamType
        local function setSelfie(on)
            if on == S.selfie then return end
            S.selfie = on
            if on then
                prevCamType = cam().CameraType
                S.baseFov = SELFIE_FOV
                cam().CameraType = Enum.CameraType.Scriptable
                selfieConn = RunService.RenderStepped:Connect(function()
                    local ch = Player.Character
                    local head = ch and ch:FindFirstChild("Head")
                    local c = cam()
                    if head and c then
                        local focus = head.Position + Vector3.new(0, 0.3, 0)
                        local pos = (head.CFrame * CFrame.new(0.8, 0.4, -SELFIE_DIST)).Position
                        c.CFrame = c.CFrame:Lerp(CFrame.lookAt(pos, focus), 0.35)
                    end
                end)
            else
                if selfieConn then selfieConn:Disconnect() selfieConn = nil end
                if cam() then cam().CameraType = prevCamType or Enum.CameraType.Custom end
                S.baseFov = S.origFov
            end
            setZoom(S.zoom)
        end

        -- ── MODO BONECO: enquadra o corpo inteiro do personagem ────────────
        local function setBoneco(on)
            if on == S.boneco then return end
            S.boneco = on
            if on then
                prevCamType = cam().CameraType
                S.baseFov = BONECO_FOV
                cam().CameraType = Enum.CameraType.Scriptable
                bonecoConn = RunService.RenderStepped:Connect(function()
                    local ch = Player.Character
                    if not ch then return end
                    local root = ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Torso")
                    local head = ch:FindFirstChild("Head")
                    local c = cam()
                    if root and head and c then
                        -- ponto de foco = meio entre a cabeça e a raiz (centro do corpo)
                        local focus = (head.Position + root.Position) / 2 + Vector3.new(0, 0.5, 0)
                        -- câmera posicionada à frente e levemente acima do personagem
                        local fwd   = root.CFrame.LookVector
                        local pos   = root.Position + fwd * BONECO_DIST + Vector3.new(0, 2.5, 0)
                        c.CFrame = c.CFrame:Lerp(CFrame.lookAt(pos, focus), 0.28)
                    end
                end)
            else
                if bonecoConn then bonecoConn:Disconnect() bonecoConn = nil end
                if cam() then cam().CameraType = prevCamType or Enum.CameraType.Custom end
                S.baseFov = S.origFov
            end
            setZoom(S.zoom)
        end

        local function activate()
            if S.active then return end
            S.active = true
            S.origFov = cam().FieldOfView
            S.baseFov = S.selfie and SELFIE_FOV or S.origFov
            ccEffect = nw("ColorCorrectionEffect", {Name = "TZE_CameraFilter"}, Lighting)
            applyFilter(S.filter, true)
            setZoom(S.zoom, true)
            refreshTop()
        end

        local function deactivate()
            if not S.active then return end
            S.cancel = true
            -- desliga todos os modos de câmera
            if S.boneco then setBoneco(false) end
            if S.selfie  then setSelfie(false) end
            S.active = false
            if cam() then cam().FieldOfView = S.origFov end
            if ccEffect then ccEffect:Destroy() ccEffect = nil end
            -- libera fotos da sessão da câmera ao fechar
            for _, p in ipairs(S.photos) do pcall(releasePhoto, p) end
            S.photos = {}
        end

        local function skyColor()
            local ct = Lighting.ClockTime
            if ct < 5.5 or ct > 18.5 then return Color3.fromRGB(14, 18, 38), true end
            if ct < 7 or ct > 17 then return Color3.fromRGB(240, 160, 110), false end
            return Color3.fromRGB(135, 190, 235), false
        end

        local function makeVFPhoto()
            local c = cam()
            local sky, night = skyColor()
            local vf = nw("ViewportFrame", {BackgroundColor3 = sky, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0),
                Ambient = night and Color3.fromRGB(70, 75, 100) or Color3.fromRGB(190, 190, 190),
                LightColor = night and Color3.fromRGB(90, 100, 140) or Color3.fromRGB(150, 150, 150)})
            pcall(function() vf.LightDirection = -Lighting:GetSunDirection() end)
            local vc = nw("Camera", {CFrame = c.CFrame, FieldOfView = c.FieldOfView}, vf)
            vf.CurrentCamera = vc
            local origin = c.CFrame.Position
            local list = {}
            -- personagem local: clona o Model inteiro para preservar joints/Motor6D
            -- e o exclui do scan normal (evitar partes soltas/desmembradas no vf)
            local lchar = Player and Player.Character
            local function consider(inst, depth)
                if inst == c or inst:IsA("Terrain") then return end
                -- ignora instâncias que são descendentes do personagem local
                -- (serão clonados como Model completo abaixo)
                if lchar and (inst == lchar or inst:IsDescendantOf(lchar)) then return end
                if inst:IsA("BasePart") then
                    local d = (inst.Position - origin).Magnitude - inst.Size.Magnitude / 2
                    if d < RADIUS then table.insert(list, {inst, d}) end
                elseif inst:IsA("Model") then
                    local ok, size = pcall(inst.GetExtentsSize, inst)
                    if ok and size.Magnitude > 260 and depth < 5 then
                        for _, ch in ipairs(inst:GetChildren()) do consider(ch, depth + 1) end
                    else
                        local ok2, piv = pcall(inst.GetPivot, inst)
                        if ok2 then
                            local d = (piv.Position - origin).Magnitude - (ok and size.Magnitude / 2 or 0)
                            if d < RADIUS then table.insert(list, {inst, d}) end
                        end
                    end
                elseif inst:IsA("Folder") then
                    for _, ch in ipairs(inst:GetChildren()) do consider(ch, depth + 1) end
                end
            end
            for _, ch in ipairs(Workspace:GetChildren()) do consider(ch, 0) end
            table.sort(list, function(a, b) return a[2] < b[2] end)
            for i = 1, math.min(#list, MAX_OBJECTS) do
                local ok, clone = pcall(function() return list[i][1]:Clone() end)
                if ok and clone then
                    for _, d in ipairs(clone:GetDescendants()) do
                        if d:IsA("LuaSourceContainer") or d:IsA("Sound") then d:Destroy() end
                    end
                    clone.Parent = vf
                end
            end
            -- ── PERSONAGEM LOCAL NO VIEWPORT ─────────────────────────────────
            -- ViewportFrame NÃO renderiza o LocalPlayer.Character via clone normal.
            -- Solução: snapshot parte-por-parte com CFrame absoluto congelado.
            -- Inclui Humanoid (para BodyColors/aparência), roupas e acessórios.
            if lchar then
                local charHolder = Instance.new("Model")
                charHolder.Name = "CharSnapshot"

                -- tipos não-BasePart que afetam a aparência e precisam ser copiados
                local APPEARANCE_TYPES = {
                    "Humanoid", "HumanoidDescription",
                    "BodyColors",
                    "Shirt", "Pants", "ShirtGraphic",
                }
                local function isAppearance(inst)
                    for _, t in ipairs(APPEARANCE_TYPES) do
                        if inst:IsA(t) then return true end
                    end
                    return false
                end

                for _, inst in ipairs(lchar:GetDescendants()) do
                    if inst:IsA("BasePart") then
                        local okP, partClone = pcall(function() return inst:Clone() end)
                        if okP and partClone then
                            for _, d in ipairs(partClone:GetDescendants()) do
                                if d:IsA("LuaSourceContainer") or d:IsA("Sound")
                                    or d:IsA("Motor6D") or d:IsA("Weld")
                                    or d:IsA("WeldConstraint") then
                                    d:Destroy()
                                end
                            end
                            partClone.Anchored   = true
                            partClone.CanCollide = false
                            partClone.CFrame     = inst.CFrame  -- pose congelada
                            partClone.Parent     = charHolder
                        end
                    elseif isAppearance(inst) then
                        -- clona direto para o charHolder (sem reparenting condicional)
                        pcall(function()
                            local cl = inst:Clone()
                            cl.Parent = charHolder
                        end)
                    end
                end

                -- copia BodyColors do nível raiz do personagem também (R6 coloca lá)
                for _, inst in ipairs(lchar:GetChildren()) do
                    if isAppearance(inst) then
                        pcall(function()
                            local cl = inst:Clone()
                            cl.Parent = charHolder
                        end)
                    end
                end

                charHolder.Parent = vf
            end
            vf.Parent = nil
            return vf
        end

        local function tryCaptureService()
            local okCS, CS = pcall(function() return game:GetService("CaptureService") end)
            if not okCS or not CS then return nil end
            local result, finished = nil, false
            local started = pcall(function()
                CS:CaptureScreenshot(function(id)
                    result = id
                    finished = true
                end)
            end)
            if not started then return nil end
            local t0 = os.clock()
            while not finished and os.clock() - t0 < 2.5 do RunService.RenderStepped:Wait() end
            return result
        end

        local function capture()
            local vs = cam().ViewportSize
            local photo = {aspect = vs.X / math.max(vs.Y, 1), filter = FILTERS[S.filter], time = os.date("%d/%m/%Y  %H:%M")}

            -- Modo boneco ou selfie: câmera já está enquadrando o personagem.
            -- Usamos screenshot real (CaptureService) com a ScreenGui oculta.
            -- O engine renderiza o personagem com todas as texturas corretamente.
            -- NÃO usamos ViewportFrame aqui — ele não renderiza texturas de avatar.
            if S.boneco or S.selfie then
                -- aguarda a câmera do bonecoConn/selfieConn estabilizar na pose
                RunService.RenderStepped:Wait()
                RunService.RenderStepped:Wait()
                ScreenGui.Enabled = false
                RunService.RenderStepped:Wait()
                RunService.RenderStepped:Wait()
                local id = tryCaptureService()
                ScreenGui.Enabled = true
                if id then
                    local ed
                    pcall(function() ed = game:GetService("AssetService"):CreateEditableImageAsync(Content.fromUri(id)) end)
                    if ed then
                        photo.kind, photo.id, photo.ed = "capture", id, ed
                        return photo
                    end
                    photo.kind, photo.id = "capture", id
                    return photo
                end
                -- fallback: se CaptureService falhou, vf sem personagem é melhor que travar
                photo.kind = "vf"
                photo.vf = makeVFPhoto()
                return photo
            end

            -- Modo normal: fluxo original (tenta CaptureService, cai em VF)
            ScreenGui.Enabled = false
            RunService.RenderStepped:Wait()
            RunService.RenderStepped:Wait()
            local id = tryCaptureService()
            ScreenGui.Enabled = true
            if id then
                local ed
                pcall(function() ed = game:GetService("AssetService"):CreateEditableImageAsync(Content.fromUri(id)) end)
                if ed then
                    photo.kind, photo.id, photo.ed = "capture", id, ed
                    return photo
                end
                local probe = nw("ImageLabel", {Image = id, BackgroundTransparency = 1, ImageTransparency = 0.99, Size = UDim2.new(0, 2, 0, 2)}, f)
                local t0 = os.clock()
                while not probe.IsLoaded and os.clock() - t0 < 1.5 do RunService.RenderStepped:Wait() end
                local loaded = probe.IsLoaded
                probe:Destroy()
                if loaded then
                    photo.kind, photo.id = "capture", id
                    return photo
                end
            end
            photo.kind = "vf"
            photo.vf = makeVFPhoto()
            return photo
        end

        local function releasePhoto(p)
            if p.vf then p.vf:Destroy() end
            if p.ed then pcall(function() p.ed:Destroy() end) end
        end

        local function fillPhoto(photo, parent)
            local content
            if photo.kind == "vf" then
                content = photo.vf:Clone()
                content.Size = UDim2.new(1, 0, 1, 0)
                content.Position = UDim2.new(0, 0, 0, 0)
                local vc = content:FindFirstChildOfClass("Camera")
                if vc then content.CurrentCamera = vc end
                content.Parent = parent
            else
                content = nw("ImageLabel", {BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), ScaleType = Enum.ScaleType.Stretch}, parent)
                local okc = false
                if photo.ed then okc = pcall(function() content.ImageContent = Content.fromObject(photo.ed) end) end
                if not okc then content.Image = photo.id or "" end
            end
            local fl = photo.filter
            if fl and fl.ov and photo.kind == "vf" then
                nw("Frame", {BackgroundColor3 = fl.ov, BackgroundTransparency = fl.ova, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), ZIndex = content.ZIndex + 1}, parent)
            end
            return content
        end

        local function cropFill(photo, cell)
            local a = photo.aspect
            local w = nw("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(math.max(1, a), 0, math.max(1, 1 / a), 0), ZIndex = cell.ZIndex + 1}, cell)
            fillPhoto(photo, w)
        end

        local function refreshThumb()
            for _, ch in ipairs(thumb:GetChildren()) do
                if ch:IsA("Frame") then ch:Destroy() end
            end
            local last = S.photos[#S.photos]
            if last then
                thumb.Text = ""
                cropFill(last, thumb)
            else
                thumb.Text = "▣"
            end
        end

        local function flyPhoto(photo)
            local a = photo.aspect
            local bw, bh = 150, 150 / a
            if bh > 170 then bh = 170 bw = 170 * a end
            local frame = nw("Frame", {BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 140, 0, 150), Size = UDim2.new(0, bw + 8, 0, bh + 8), Rotation = -3, ZIndex = 16}, f)
            corner(frame, UDim.new(0, 3))
            local inner = nw("Frame", {BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ClipsDescendants = true, Position = UDim2.new(0, 4, 0, 4), Size = UDim2.new(1, -8, 1, -8), ZIndex = 17}, frame)
            fillPhoto(photo, inner)
            local sc = nw("UIScale", {Scale = 0.6}, frame)
            TweenService:Create(sc, TweenInfo.new(0.28, Enum.EasingStyle.Back), {Scale = 1}):Play()
            task.wait(0.7)
            local k = phoneUIScale.Scale
            local tp = (thumb.AbsolutePosition - f.AbsolutePosition + thumb.AbsoluteSize / 2) / math.max(k, 0.01)
            TweenService:Create(frame, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position = UDim2.new(0, tp.X, 0, tp.Y), Size = UDim2.new(0, 38, 0, 38), Rotation = 0}):Play()
            TweenService:Create(sc, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Scale = 0.9}):Play()
            task.wait(0.45)
            frame:Destroy()
        end

        -- ============================================================
        --  SALVAR NA GALERIA: toda foto tirada vai para PHONE/Photos
        --  1) .camphoto (instantâneo): guarda o id da captura -> aparece já na Galeria
        --  2) PNG real (em segundo plano): sobrevive a novas sessões; substitui o .camphoto
        -- ============================================================
        local galleryCounter = 0
        local function be32(n)
            return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
        end
        local crcT
        local function crc32(str)
            if not crcT then
                crcT = {}
                for n = 0, 255 do
                    local c = n
                    for _ = 1, 8 do
                        if bit32.band(c, 1) == 1 then c = bit32.bxor(0xEDB88320, bit32.rshift(c, 1)) else c = bit32.rshift(c, 1) end
                    end
                    crcT[n + 1] = c
                end
            end
            local c = 0xFFFFFFFF
            for i = 1, #str do
                c = bit32.bxor(crcT[bit32.band(bit32.bxor(c, str:byte(i)), 255) + 1], bit32.rshift(c, 8))
            end
            return bit32.bxor(c, 0xFFFFFFFF)
        end
        local function adler32(str)
            local a, b = 1, 0
            local len, i = #str, 1
            while i <= len do
                local j = math.min(i + 3799, len)
                for k = i, j do a = a + str:byte(k); b = b + a end
                a, b = a % 65521, b % 65521
                i = j + 1
            end
            return b * 65536 + a
        end
        local function pngChunk(kind, body) return be32(#body) .. kind .. body .. be32(crc32(kind .. body)) end
        local function zlibStore(raw)
            local out, len, pos = {"\120\1"}, #raw, 1
            while pos <= len do
                local n = math.min(65535, len - pos + 1)
                local final = (pos + n > len) and 1 or 0
                local nn = 65535 - n
                out[#out + 1] = string.char(final, n % 256, math.floor(n / 256), nn % 256, math.floor(nn / 256))
                out[#out + 1] = raw:sub(pos, pos + n - 1)
                pos = pos + n
            end
            out[#out + 1] = be32(adler32(raw))
            return table.concat(out)
        end

        -- EditableImage -> PNG (RGB, reduzido para no máx. 640px de largura)
        local function editableToPng(ed)
            local sz = ed.Size
            local W, H = math.floor(sz.X), math.floor(sz.Y)
            if W < 1 or H < 1 then return nil end
            local buf = ed:ReadPixelsBuffer(Vector2.new(0, 0), Vector2.new(W, H))
            local step = math.max(1, math.ceil(W / 640))
            local ow, oh = math.floor(W / step), math.floor(H / step)
            local rows = {}
            for oy = 0, oh - 1 do
                local t, n = {0}, 1
                local rowBase = (oy * step) * W
                for ox = 0, ow - 1 do
                    local off = (rowBase + ox * step) * 4
                    t[n + 1] = buffer.readu8(buf, off)
                    t[n + 2] = buffer.readu8(buf, off + 1)
                    t[n + 3] = buffer.readu8(buf, off + 2)
                    n = n + 3
                end
                rows[oy + 1] = string.char(table.unpack(t))
                if oy % 24 == 0 then RunService.Heartbeat:Wait() end
            end
            local ihdr = be32(ow) .. be32(oh) .. "\8\2\0\0\0"
            return "\137PNG\13\10\26\10" .. pngChunk("IHDR", ihdr) .. pngChunk("IDAT", zlibStore(table.concat(rows))) .. pngChunk("IEND", "")
        end

        local function saveToGallery(photo)
            if not photo or photo.saved or not photo.kind then return end
            -- FOTO VIEWPORTFRAME (sem imagem real): vira entrada virtual da Galeria.
            -- Guardamos um CLONE próprio da cena congelada, pois a Câmera libera o original ao fechar.
            if photo.kind == "vf" then
                if not photo.vf then return end
                photo.saved = true
                local okC, vfClone = pcall(function() return photo.vf:Clone() end)
                if not okC or not vfClone then toast("Não foi possível salvar na Galeria") return end
                _G.TZE_GalleryVF = _G.TZE_GalleryVF or {}
                local list = _G.TZE_GalleryVF
                galleryCounter = galleryCounter + 1
                local name = "Foto_" .. os.date("%Y%m%d_%H%M%S") .. "_" .. galleryCounter
                table.insert(list, {
                    name = name, file = name .. ".vf", path = "vf://" .. name, isVF = true,
                    photo = {kind = "vf", vf = vfClone, aspect = photo.aspect, filter = photo.filter, time = photo.time},
                })
                while #list > 30 do
                    local old = table.remove(list, 1)
                    if old and old.photo and old.photo.vf then pcall(function() old.photo.vf:Destroy() end) end
                end
                toast("Foto salva na Galeria")
                if refreshPhotos and GalleryFrame and GalleryFrame.Visible then pcall(refreshPhotos) end
                return
            end
            if photo.kind ~= "capture" or not photo.id then return end
            photo.saved = true
            pcall(function()
                if not isfolder("PHONE") then makefolder("PHONE") end
                if not isfolder("PHONE/Photos") then makefolder("PHONE/Photos") end
            end)
            galleryCounter = galleryCounter + 1
            local base = "Foto_" .. os.date("%Y%m%d_%H%M%S") .. "_" .. galleryCounter
            local camPath = "PHONE/Photos/" .. base .. ".camphoto"
            local okCam = pcall(writefile, camPath, tostring(photo.id))
            if okCam then
                photo.galleryPath = camPath
                toast("Foto salva na Galeria")
                if refreshPhotos and GalleryFrame and GalleryFrame.Visible then pcall(refreshPhotos) end
            else
                toast("Não foi possível salvar na Galeria")
            end
            -- upgrade para PNG permanente (o id temporário da captura some ao sair do jogo)
            if photo.ed then
                task.spawn(function()
                    local okP, png = pcall(editableToPng, photo.ed)
                    if okP and png then
                        local pngPath = "PHONE/Photos/" .. base .. ".png"
                        if pcall(writefile, pngPath, png) then
                            photo.galleryPath = pngPath
                            if okCam then pcall(delfile, camPath) end
                            if refreshPhotos and GalleryFrame and GalleryFrame.Visible then pcall(refreshPhotos) end
                        end
                    end
                end)
            end
        end

        local function addPhoto(photo)
            task.spawn(saveToGallery, photo)
            table.insert(S.photos, photo)
            while #S.photos > MAX_PHOTOS do releasePhoto(table.remove(S.photos, 1)) end
            -- expõe a lista para a Galeria via _G
            _G.TZE_CameraPhotos = S.photos
            _G.TZE_CameraFillPhoto = fillPhoto
        end

        local function shutterFx()
            ping(1.7)
            task.delay(0.07, function() ping(0.9) end)
            flashFrame.BackgroundTransparency = S.flash and 0 or 0.55
            TweenService:Create(flashFrame, TweenInfo.new(S.flash and 0.6 or 0.22), {BackgroundTransparency = 1}):Play()
            local t = TweenService:Create(ring, TweenInfo.new(0.1), {Size = UDim2.new(0.9, 0, 0.9, 0), Position = UDim2.new(0.05, 0, 0.05, 0)})
            t.Completed:Once(function()
                TweenService:Create(ring, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0)}):Play()
            end)
            t:Play()
        end

        local function countdown(n)
            S.counting = true
            S.cancel = false
            for i = n, 1, -1 do
                if S.cancel then break end
                cdLabel.Text = tostring(i)
                cdLabel.Visible = true
                cdLabel.TextTransparency = 0
                cdLabel.TextStrokeTransparency = 0.5
                cdScale.Scale = 1.7
                TweenService:Create(cdScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Scale = 1}):Play()
                TweenService:Create(cdLabel, TweenInfo.new(0.9), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
                ping(1 + (n - i) * 0.04)
                task.wait(1)
            end
            cdLabel.Visible = false
            S.counting = false
            return not S.cancel
        end

        local function shoot()
            if S.counting then
                S.cancel = true
                toast("Contagem cancelada")
                return
            end
            if S.busy or not S.active or roll.Visible or viewer.Visible then return end
            S.busy = true
            local t = TIMERS[S.timerIdx]
            if t > 0 and not countdown(t) then
                S.busy = false
                return
            end
            local ok, photo = pcall(capture)
            if not ok or not photo then
                ScreenGui.Enabled = true
                S.busy = false
                toast("Não deu pra tirar a foto")
                return
            end
            shutterFx()
            addPhoto(photo)
            S.busy = false
            task.spawn(function()
                pcall(flyPhoto, photo)
                refreshThumb()
                local sc = thumb:FindFirstChildOfClass("UIScale")
                if sc then
                    sc.Scale = 1.18
                    TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Scale = 1}):Play()
                end
            end)
        end

        local function showViewer()
            local cur = S.photos[S.viewIdx]
            if not cur then return end
            for _, ch in ipairs(vwInner:GetChildren()) do ch:Destroy() end
            vwRatio.AspectRatio = cur.aspect
            fillPhoto(cur, vwInner)
            vwCaption.Text = cur.time .. "   •   " .. cur.filter.name
            vwCounter.Text = S.viewIdx .. " / " .. #S.photos
            vwSave.Visible = cur.kind == "capture"
            viewer.Visible = true
        end

        local function refreshRoll()
            for _, ch in ipairs(rollScroll:GetChildren()) do
                if ch:IsA("TextButton") then ch:Destroy() end
            end
            local n = #S.photos
            rollEmpty.Visible = n == 0
            rollTitle.Text = n > 0 and ("Fotos  (" .. n .. ")") or "Fotos"
            for i = n, 1, -1 do
                local p = S.photos[i]
                local cell = nw("TextButton", {BackgroundColor3 = CARDC, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ClipsDescendants = true, LayoutOrder = n - i, ZIndex = 11}, rollScroll)
                corner(cell, UDim.new(0, 8))
                cropFill(p, cell)
                cell.MouseButton1Click:Connect(function()
                    ping(1.2)
                    S.viewIdx = i
                    showViewer()
                end)
            end
        end

        thumb.MouseButton1Click:Connect(function()
            if S.busy then return end
            ping(1.1)
            refreshRoll()
            roll.Visible = true
        end)

        local function stepViewer(d)
            local n = #S.photos
            if n == 0 then return end
            ping(1.3)
            S.viewIdx = ((S.viewIdx - 1 + d) % n) + 1
            showViewer()
        end
        vwPrev.MouseButton1Click:Connect(function() stepViewer(-1) end)
        vwNext.MouseButton1Click:Connect(function() stepViewer(1) end)
        vwDel.MouseButton1Click:Connect(function()
            local p = S.photos[S.viewIdx]
            if not p then return end
            ping(0.7)
            table.remove(S.photos, S.viewIdx)
            releasePhoto(p)
            refreshThumb()
            if #S.photos == 0 then
                viewer.Visible = false
                refreshRoll()
            else
                S.viewIdx = math.clamp(S.viewIdx, 1, #S.photos)
                showViewer()
                refreshRoll()
            end
            toast("Foto excluída")
        end)
        vwSave.MouseButton1Click:Connect(function()
            local p = S.photos[S.viewIdx]
            if not p or p.kind ~= "capture" then return end
            local ok = pcall(function()
                game:GetService("CaptureService"):PromptSaveCapturesToGallery({p.id}, function() end)
            end)
            toast(ok and "Enviada para a galeria do Roblox" or "Não foi possível salvar")
        end)

        shutter.MouseButton1Click:Connect(shoot)
        btnFlash.MouseButton1Click:Connect(function() ping(1.2) S.flash = not S.flash refreshTop() end)
        btnTimer.MouseButton1Click:Connect(function() ping(1.2) S.timerIdx = S.timerIdx % #TIMERS + 1 refreshTop() end)
        btnGrid.MouseButton1Click:Connect(function() ping(1.2) S.grid = not S.grid refreshTop() end)
        -- Modo Boneco: enquadra o personagem inteiro; exclusivo com selfie
        btnBoneco.MouseButton1Click:Connect(function()
            ping(1.2)
            local next = not S.boneco
            if next then
                -- desativa selfie se estiver ativo
                if S.selfie then setSelfie(false) end
                setBoneco(true)
            else
                setBoneco(false)
            end
            refreshTop()
        end)
        btnFlip.MouseButton1Click:Connect(function()
            ping(1.3)
            TweenService:Create(btnFlip, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Rotation = btnFlip.Rotation + 180}):Play()
            if cam() then
                local next = not S.selfie
                if next then
                    -- desativa boneco se estiver ativo
                    if S.boneco then setBoneco(false) end
                    setSelfie(true)
                else
                    setSelfie(false)
                end
                refreshTop()
            end
        end)
        for i, b in ipairs(zoomBtns) do
            b.MouseButton1Click:Connect(function() ping(1.2) setZoom(ZOOMS[i]) end)
        end
        for i, b in ipairs(chipBtns) do
            b.MouseButton1Click:Connect(function() ping(1.1) applyFilter(i) end)
        end

        f:GetPropertyChangedSignal("Visible"):Connect(function()
            if f.Visible then activate() else deactivate() end
        end)

        Nav.camera.goBack = function()
            if viewer.Visible then viewer.Visible = false refreshRoll() return true end
            if roll.Visible then roll.Visible = false return true end
            return false
        end
        Nav.camera.onOpen = function()
            roll.Visible = false
            viewer.Visible = false
            refreshTop()
            refreshThumb()
            applyFilter(S.filter, true)
            setZoom(S.zoom, true)
        end
        Nav.camera.onClose = function()
            -- fecha painéis internos
            roll.Visible = false
            viewer.Visible = false
            -- remove conteúdo do viewer para não manter ViewportFrames vivas
            for _, ch in ipairs(vwInner:GetChildren()) do ch:Destroy() end
            -- cancela contagem regressiva pendente
            S.cancel = true
            -- desativa câmera e libera todos os recursos (efeitos, fotos, conexões)
            deactivate()
        end

        applyFilter(1, true)
        setZoom(1, true)
        refreshTop()
        -- expõe lista de fotos e renderizador para o app Galeria
        _G.TZE_CameraPhotos    = S.photos
        _G.TZE_CameraFillPhoto = fillPhoto
        return f
    end

    local notesFrame = buildNotes()
    local weatherFrame = buildWeather()
    local calcFrame = buildCalc()
    createNavBar(notesFrame)
    createNavBar(weatherFrame)
    createNavBar(calcFrame)
    screens.camera = {frame = buildCamera(), app = true, name = "Câmera", color = Color3.fromRGB(62, 64, 74), icon = Icons.camera, onOpen = function() Nav.camera.onOpen() end, onClose = function() Nav.camera.onClose() end}
    createNavBar(screens.camera.frame)

    Nav.notes = notesHooks

    screens.notes = {frame = notesFrame, app = true, name = "Notas", color = Color3.fromRGB(245, 190, 50), icon = Icons.notepad, onOpen = function() notesHooks.onOpen() end, onClose = function() notesHooks.onClose() end}
    screens.weather = {frame = weatherFrame, app = true, name = "Clima", color = Color3.fromRGB(60, 150, 235), icon = Icons.weather, onOpen = function() weatherHooks.onOpen() end}
    screens.calc = {frame = calcFrame, app = true, name = "Calculadora", color = Color3.fromRGB(240, 100, 70), icon = Icons.calc, onClose = function() if Nav.calc then Nav.calc.reset() end end}

    local function safeAppIcon(label, drawFn, col, pos)
        local mk = Nav.__mkIconFn or createAppIcon
        if type(mk) ~= "function" then
            warn("[TZE PHONE] createAppIcon indisponivel (tipo: " .. typeof(mk) .. ")")
            return nil
        end
        if type(drawFn) ~= "function" then
            warn("[TZE PHONE] icone '" .. tostring(label) .. "' sem funcao de desenho (tipo: " .. typeof(drawFn) .. ")")
            return nil
        end
        local okIcon, icon = pcall(mk, label, drawFn, col, pos)
        if not okIcon then
            warn("[TZE PHONE] falha ao criar icone '" .. tostring(label) .. "': " .. tostring(icon))
            return nil
        end
        return icon
    end

    local notesIcon = safeAppIcon("Notas", Icons.notepad, Color3.fromRGB(245, 190, 50), Nav.homeSlot(2))
    local weatherIcon = safeAppIcon("Clima", Icons.weather, Color3.fromRGB(60, 150, 235), Nav.homeSlot(1))
    local calcIcon = safeAppIcon("Calculadora", Icons.calc, Color3.fromRGB(240, 100, 70), Nav.homeSlot(3))
    if notesIcon then notesIcon.MouseButton1Click:Connect(function() if Nav.homeSwiped then return end showScreen("notes", true) end) end
    if weatherIcon then weatherIcon.MouseButton1Click:Connect(function() if Nav.homeSwiped then return end showScreen("weather", true) end) end
    if calcIcon then calcIcon.MouseButton1Click:Connect(function() if Nav.homeSwiped then return end showScreen("calc", true) end) end
    do
        local cameraIcon = safeAppIcon("Câmera", Icons.camera, Color3.fromRGB(62, 64, 74), Nav.homeSlot(5))
        if cameraIcon then cameraIcon.MouseButton1Click:Connect(function() if Nav.homeSwiped then return end showScreen("camera", true) end) end
    end
end


screens.home      = {frame = PhoneHome}
screens.music     = {frame = MainFrame,      app = true, name = "Música",     color = Color3.fromRGB(0, 180, 255),  icon = Icons.music,     onOpen = function() refreshFiles(); if restoreMusic then restoreMusic() end end, onClose = function() stopMusic() end}
screens.stopwatch = {frame = StopwatchFrame, app = true, name = "Cronômetro", color = Color3.fromRGB(255, 140, 30), icon = Icons.stopwatch, onClose = function() resetStopwatch() end}
screens.config    = {frame = ConfigFrame,    app = true, name = "Config",     color = Color3.fromRGB(120, 120, 130), icon = Icons.gear, onOpen = function() if cfgReset then cfgReset() end end, onClose = function() if cfgReset then cfgReset() end end}
screens.gallery   = {frame = GalleryFrame,   app = true, name = "Galeria",    color = Color3.fromRGB(180, 80, 220), icon = Icons.gallery,   onOpen = function() refreshPhotos() end, onClose = function() exitPhotoViewer() end}
screens.gps       = {frame = Nav.gps.frame,  app = true, name = "GPS",       color = Color3.fromRGB(46, 190, 120), icon = Icons.gps, onOpen = function() Nav.gps.onOpen() end, onClose = function() Nav.gps.onClose() end}
screens.web       = {frame = WebBrowserFrame, app = true, name = "Navegador", color = Color3.fromRGB(35,145,205), icon = Icons.search, onClose = function() if Nav.web and Nav.web.reset then Nav.web.reset() end end}
screens.recents   = {frame = RecentsFrame,   onOpen = function() rcBg.Image = currentWallpaper end}

local function touchApp(id)
    for i, v in ipairs(openApps) do
        if v == id then table.remove(openApps, i) break end
    end
    table.insert(openApps, 1, id)
end

local function updateRecentsCanvas()
    local n = #openApps
    recentsScroll.CanvasSize = UDim2.new(0, 130 + n * CARD_W + math.max(n - 1, 0) * CARD_GAP, 0, 0)
    rcEmpty.Visible = (n == 0)
    rcClear.Visible = (n > 0)
end

local function closeApp(id)
    for i, v in ipairs(openApps) do
        if v == id then table.remove(openApps, i) break end
    end
    local s = screens[id]
    if s and s.onClose then pcall(s.onClose) end
    local card = recentsScroll:FindFirstChild("Card_" .. id)
    if card then
        local tw = TweenService:Create(card, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 0, 0, CARD_H)})
        tw.Completed:Once(function()
            card:Destroy()
            updateRecentsCanvas()
        end)
        tw:Play()
    else
        updateRecentsCanvas()
    end
end

local function buildCard(id)
    local s = screens[id]
    local card = Instance.new("TextButton")
    card.Name = "Card_" .. id
    card.Size = UDim2.new(0, CARD_W, 0, CARD_H)
    card.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    card.BorderSizePixel = 0
    card.Text = ""
    card.AutoButtonColor = false
    card.ClipsDescendants = true
    card.ZIndex = 6
    card.Parent = recentsScroll
    corner(card, UDim.new(0, 18))
    local cs = Instance.new("UIStroke")
    cs.Color = Color3.fromRGB(255, 255, 255)
    cs.Transparency = 0.8
    cs.Thickness = 1.2
    cs.Parent = card

    local tile = Instance.new("Frame")
    tile.Size = UDim2.new(0, 24, 0, 24)
    tile.Position = UDim2.new(0, 8, 0, 8)
    tile.BackgroundColor3 = s.color
    tile.BorderSizePixel = 0
    tile.ZIndex = 7
    tile.Parent = card
    corner(tile, UDim.new(0, 7))
    local mini = s.icon(tile, 16, WHITE, 8)
    mini.Position = UDim2.new(0.5, -8, 0.5, -8)

    local nm = Instance.new("TextLabel")
    nm.Size = UDim2.new(1, -76, 0, 24)
    nm.Position = UDim2.new(0, 38, 0, 8)
    nm.BackgroundTransparency = 1
    nm.Text = s.name
    nm.TextColor3 = Color3.new(1, 1, 1)
    nm.Font = Enum.Font.GothamBold
    nm.TextSize = 12
    nm.TextXAlignment = Enum.TextXAlignment.Left
    nm.ZIndex = 7
    nm.Parent = card

    local xBtn = Instance.new("TextButton")
    xBtn.Name = "CloseBtn"
    xBtn.Size = UDim2.new(0, 26, 0, 26)
    xBtn.Position = UDim2.new(1, -32, 0, 7)
    xBtn.BackgroundTransparency = 1
    xBtn.Text = ""
    xBtn.AutoButtonColor = false
    xBtn.ZIndex = 9
    xBtn.Parent = card
    local xi = Icons.close(xBtn, 12, Color3.fromRGB(210, 210, 220), 10)
    xi.Position = UDim2.new(0.5, -6, 0.5, -6)

    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, -16, 1, -48)
    body.Position = UDim2.new(0, 8, 0, 40)
    body.BackgroundColor3 = s.color
    body.BorderSizePixel = 0
    body.ZIndex = 7
    body.Parent = card
    corner(body, UDim.new(0, 12))
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new(s.color:Lerp(Color3.new(1, 1, 1), 0.25), s.color:Lerp(Color3.new(0, 0, 0), 0.45))
    grad.Rotation = 90
    grad.Parent = body
    local big = s.icon(body, 60, WHITE, 8)
    big.AnchorPoint = Vector2.new(0.5, 0.5)
    big.Position = UDim2.new(0.5, 0, 0.5, 0)

    local swipeStart, swipedAt = nil, -10
    local function isPress(i)
        return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
    end
    card.InputBegan:Connect(function(i)
        if isPress(i) then swipeStart = i.Position end
    end)
    card.InputEnded:Connect(function(i)
        if isPress(i) and swipeStart then
            if swipeStart.Y - i.Position.Y > 60 then
                swipedAt = os.clock()
                closeApp(id)
            end
            swipeStart = nil
        end
    end)
    card.MouseButton1Click:Connect(function()
        if os.clock() - swipedAt < 0.3 then return end
        showScreen(id, true)
    end)
    xBtn.MouseButton1Click:Connect(function() closeApp(id) end)
    return card
end

local function renderRecents()
    for _, c in ipairs(recentsScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for idx, id in ipairs(openApps) do
        buildCard(id).LayoutOrder = idx
    end
    updateRecentsCanvas()
end

rcClear.MouseButton1Click:Connect(function()
    local copy = {table.unpack(openApps)}
    for _, id in ipairs(copy) do closeApp(id) end
end)

function showScreen(id, animate)
    local target = screens[id]
    if not target then return end
    if id ~= "home" and Nav.boot and Nav.boot.active then return end
    exitPhotoViewer()
    local pos = phonePos()
    for sid, s in pairs(screens) do
        if sid ~= id then
            s.frame.Visible = false
            s.frame.Position = pos
        end
    end
    local f = target.frame
    if animate then
        f.Position = offsetY(pos, 40)
        f.Visible = true
        TweenService:Create(f, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = pos}):Play()
    else
        f.Position = pos
        f.Visible = true
    end
    currentScreen = id
    currentApp = id
    isMusicOpen = (id == "music")
    if target.app then touchApp(id) end
    if id == "recents" then renderRecents() end
    if target.onOpen then target.onOpen() end
    selectedFrame.Visible = true
    updateNavState()
end

function Nav.home()
    if currentScreen == "home" then return end
    showScreen("home", true)
end

function Nav.back()
    if currentScreen == "home" then return end
    if currentScreen == "recents" then
        local back = prevScreen
        local still = false
        for _, v in ipairs(openApps) do if v == back then still = true break end end
        if back == "recents" or not still then back = "home" end
        showScreen(back, true)
        return
    end
    if currentScreen == "config" and cfgGoBack and cfgGoBack() then return end
    if currentScreen == "gps" and Nav.gps.goBack and Nav.gps.goBack() then return end
    if currentScreen == "web" and Nav.web and Nav.web.goBack and Nav.web.goBack() then return end
    if currentScreen == "notes" and Nav.notes and Nav.notes.goBack and Nav.notes.goBack() then return end
    if currentScreen == "camera" and Nav.camera and Nav.camera.goBack and Nav.camera.goBack() then return end
    if currentScreen == "gallery" and isInPhotoViewer then
        if isPhotoMenuOpen then closePhotoMenu() else exitPhotoViewer() end
        return
    end
    showScreen("home", true)
end

function Nav.recents()
    if currentScreen == "recents" then
        local back = prevScreen
        local still = false
        for _, v in ipairs(openApps) do if v == back then still = true break end end
        if back == "recents" or not still then back = "home" end
        showScreen(back, true)
        return
    end
    prevScreen = currentScreen
    showScreen("recents", true)
end

MusicAppIcon.MouseButton1Click:Connect(function() if Nav.homeSwiped then return end showScreen("music", true) end)
StopwatchAppIcon.MouseButton1Click:Connect(function() if Nav.homeSwiped then return end showScreen("stopwatch", true) end)
ConfigAppIcon.MouseButton1Click:Connect(function() if Nav.homeSwiped then return end showScreen("config", true) end)
GalleryAppIcon.MouseButton1Click:Connect(function() if Nav.homeSwiped then return end showScreen("gallery", true) end)
Nav.gps.icon.MouseButton1Click:Connect(function() if Nav.homeSwiped then return end showScreen("gps", true) end)
WebBrowserIcon.MouseButton1Click:Connect(function() if Nav.homeSwiped then return end showScreen("web", true) end)

Nav.boot = {done = false, active = false}
function Nav.boot.play()
    local B = Nav.boot
    if B.done then return end
    B.done, B.active = true, true

    local ACCB = Color3.fromRGB(50, 205, 50)
    local ACCL = Color3.fromRGB(150, 255, 150)
    local DIM = Color3.fromRGB(44, 44, 52)
    local GREY = Color3.fromRGB(150, 150, 165)
    local CY = 0.42
    local NDOT, RING_R = 36, 86
    local t0 = os.clock()
    local finished = false
    local rnd = math.random

    local root = Instance.new("CanvasGroup")
    root.Name = "BootScreen"
    root.Size = UDim2.new(1, 0, 1, 0)
    root.BackgroundColor3 = Color3.new(0, 0, 0)
    root.BorderSizePixel = 0
    root.Active = true
    root.ZIndex = 100
    root.Parent = PhoneHome
    corner(root, UDim.new(0, 28))

    local content = Instance.new("Frame")
    content.AnchorPoint = Vector2.new(0.5, 0.5)
    content.Position = UDim2.new(0.5, 0, 0.5, 0)
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ZIndex = 101
    content.Parent = root
    local scale = Instance.new("UIScale")
    scale.Parent = content

    local function makeGlow(size0, size1, tr0, tr1, dur)
        local g = Instance.new("Frame")
        g.AnchorPoint = Vector2.new(0.5, 0.5)
        g.Position = UDim2.new(0.5, 0, CY, 0)
        g.Size = UDim2.new(0, size0, 0, size0)
        g.BackgroundColor3 = ACCB
        g.BackgroundTransparency = 1
        g.BorderSizePixel = 0
        g.ZIndex = 101
        g.Parent = content
        corner(g, UDim.new(1, 0))
        TweenService:Create(g, TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            {Size = UDim2.new(0, size1, 0, size1)}):Play()
        return g, tr0
    end
    local glowA, glowAt = makeGlow(110, 160, 0.93, 0.86, 1.3)
    local glowB, glowBt = makeGlow(170, 210, 0.97, 0.93, 1.9)
    glowA.BackgroundTransparency, glowB.BackgroundTransparency = 1, 1

    local scan = Instance.new("Frame")
    scan.Size = UDim2.new(1, 0, 0, 36)
    scan.Position = UDim2.new(0, 0, 0, -36)
    scan.BackgroundColor3 = ACCB
    scan.BackgroundTransparency = 0.9
    scan.BorderSizePixel = 0
    scan.ZIndex = 102
    scan.Parent = content
    local scanG = Instance.new("UIGradient")
    scanG.Rotation = 90
    scanG.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.35),
        NumberSequenceKeypoint.new(1, 1),
    })
    scanG.Parent = scan

    local ring = Instance.new("Frame")
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.new(0.5, 0, CY, 0)
    ring.Size = UDim2.new(0, RING_R * 2 + 16, 0, RING_R * 2 + 16)
    ring.BackgroundTransparency = 1
    ring.BorderSizePixel = 0
    ring.ZIndex = 102
    ring.Parent = content
    local dots = {}
    for i = 1, NDOT do
        local a = math.rad(-90 + (i - 1) * 360 / NDOT)
        local d = Instance.new("Frame")
        d.AnchorPoint = Vector2.new(0.5, 0.5)
        d.Position = UDim2.new(0.5, math.cos(a) * RING_R, 0.5, math.sin(a) * RING_R)
        d.Size = UDim2.new(0, 0, 0, 0)
        d.BackgroundColor3 = DIM
        d.BorderSizePixel = 0
        d.ZIndex = 102
        d.Parent = ring
        corner(d, UDim.new(1, 0))
        dots[i] = d
    end
    local function popDot(d)
        d.BackgroundColor3 = ACCL
        d.Size = UDim2.new(0, 9, 0, 9)
        TweenService:Create(d, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 5, 0, 5)}):Play()
        TweenService:Create(d, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundColor3 = ACCB}):Play()
    end

    local function wave(big)
        local c = Instance.new("Frame")
        c.AnchorPoint = Vector2.new(0.5, 0.5)
        c.Position = UDim2.new(0.5, 0, CY, 0)
        c.Size = UDim2.new(0, 60, 0, 60)
        c.BackgroundTransparency = 1
        c.BorderSizePixel = 0
        c.ZIndex = 102
        c.Parent = content
        corner(c, UDim.new(1, 0))
        local st = Instance.new("UIStroke")
        st.Color = ACCB
        st.Thickness = big and 2.5 or 1.5
        st.Transparency = big and 0.1 or 0.4
        st.Parent = c
        local info = TweenInfo.new(big and 1.1 or 2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
        TweenService:Create(st, info, {Transparency = 1}):Play()
        local tw = TweenService:Create(c, info, {Size = UDim2.new(0, big and 360 or 280, 0, big and 360 or 280)})
        tw.Completed:Once(function() c:Destroy() end)
        tw:Play()
    end

    local function spawnParticle()
        local p = Instance.new("Frame")
        local sz = rnd(2, 4)
        p.Size = UDim2.new(0, sz, 0, sz)
        p.Position = UDim2.new(rnd(5, 95) / 100, 0, 1, 6)
        p.BackgroundColor3 = ACCB
        p.BackgroundTransparency = 0.75
        p.BorderSizePixel = 0
        p.ZIndex = 101
        p.Parent = content
        corner(p, UDim.new(1, 0))
        local info = TweenInfo.new(rnd(30, 55) / 10, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
        TweenService:Create(p, info, {Position = UDim2.new(p.Position.X.Scale, rnd(-20, 20), 0.55, 0), BackgroundTransparency = 1}):Play()
        task.delay(6, function() p:Destroy() end)
    end

    local logo = Instance.new("Frame")
    logo.AnchorPoint = Vector2.new(0.5, 0.5)
    logo.Position = UDim2.new(0.5, 0, CY, 0)
    logo.Size = UDim2.new(0, 150, 0, 60)
    logo.BackgroundTransparency = 1
    logo.BorderSizePixel = 0
    logo.ZIndex = 103
    logo.Parent = content
    local ll = Instance.new("UIListLayout")
    ll.FillDirection = Enum.FillDirection.Horizontal
    ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
    ll.VerticalAlignment = Enum.VerticalAlignment.Center
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Padding = UDim.new(0, 3)
    ll.Parent = logo
    local letters, shines = {}, {}
    for i, ch in ipairs({"T", "Z", "E"}) do
        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(0, 38, 1, 0)
        holder.BackgroundTransparency = 1
        holder.BorderSizePixel = 0
        holder.LayoutOrder = i
        holder.ZIndex = 103
        holder.Parent = logo
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 1, 0)
        l.Position = UDim2.new(0, 0, 0, -26)
        l.BackgroundTransparency = 1
        l.Text = ch
        l.Font = Enum.Font.GothamBlack
        l.TextSize = 52
        l.TextColor3 = WHITE
        l.TextTransparency = 1
        l.ZIndex = 104
        l.Parent = holder

        local g = Instance.new("UIGradient")
        g.Rotation = 20
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, WHITE),
            ColorSequenceKeypoint.new(0.4, WHITE),
            ColorSequenceKeypoint.new(0.5, ACCL),
            ColorSequenceKeypoint.new(0.6, WHITE),
            ColorSequenceKeypoint.new(1, WHITE),
        })
        g.Offset = Vector2.new(-1, 0)
        g.Parent = l
        letters[i], shines[i] = l, g
    end

    local sub = Instance.new("TextLabel")
    sub.AnchorPoint = Vector2.new(0.5, 0)
    sub.Position = UDim2.new(0.5, 0, CY, 50)
    sub.Size = UDim2.new(1, 0, 0, 16)
    sub.BackgroundTransparency = 1
    sub.Text = "P   H   O   N   E"
    sub.Font = Enum.Font.GothamBold
    sub.TextSize = 11
    sub.TextColor3 = ACCB
    sub.TextTransparency = 1
    sub.ZIndex = 103
    sub.Parent = content

    local footer = Instance.new("TextLabel")
    footer.AnchorPoint = Vector2.new(0.5, 1)
    footer.Position = UDim2.new(0.5, 0, 1, -14)
    footer.Size = UDim2.new(1, 0, 0, 12)
    footer.BackgroundTransparency = 1
    footer.Text = "iDroid  •  V8"
    footer.Font = Enum.Font.Gotham
    footer.TextSize = 9
    footer.TextColor3 = GREY
    footer.TextTransparency = 1
    footer.ZIndex = 103
    footer.Parent = content

    local helloText = "Olá, " .. (Player.DisplayName ~= "" and Player.DisplayName or Player.Name)
    local hello = Instance.new("TextLabel")
    hello.Position = UDim2.new(0, 0, 0.7, 0)
    hello.Size = UDim2.new(1, 0, 0, 24)
    hello.BackgroundTransparency = 1
    hello.Text = helloText
    hello.Font = Enum.Font.GothamMedium
    hello.TextSize = 16
    hello.TextColor3 = WHITE
    hello.TextTruncate = Enum.TextTruncate.AtEnd
    hello.MaxVisibleGraphemes = 0
    hello.ZIndex = 103
    hello.Parent = content
    local helloLine = Instance.new("Frame")
    helloLine.AnchorPoint = Vector2.new(0.5, 0)
    helloLine.Position = UDim2.new(0.5, 0, 0.7, 28)
    helloLine.Size = UDim2.new(0, 0, 0, 2)
    helloLine.BackgroundColor3 = ACCB
    helloLine.BorderSizePixel = 0
    helloLine.ZIndex = 103
    helloLine.Parent = content
    corner(helloLine, UDim.new(1, 0))

    local loader = Instance.new("CanvasGroup")
    loader.Position = UDim2.new(0, 0, 0.68, 0)
    loader.Size = UDim2.new(1, 0, 0, 44)
    loader.BackgroundTransparency = 1
    loader.BorderSizePixel = 0
    loader.GroupTransparency = 1
    loader.ZIndex = 103
    loader.Parent = content
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 14)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.Font = Enum.Font.Gotham
    status.TextSize = 11
    status.TextColor3 = GREY
    status.ZIndex = 103
    status.Parent = loader
    local pct = Instance.new("TextLabel")
    pct.Position = UDim2.new(0, 0, 0, 16)
    pct.Size = UDim2.new(1, 0, 0, 18)
    pct.BackgroundTransparency = 1
    pct.Text = "0%"
    pct.Font = Enum.Font.GothamBold
    pct.TextSize = 15
    pct.TextColor3 = ACCB
    pct.ZIndex = 103
    pct.Parent = loader

    local prog = Instance.new("NumberValue")
    prog.Parent = root
    local lit = 0
    prog.Changed:Connect(function(v)
        pct.Text = math.floor(v * 100 + 0.5) .. "%"
        local n = math.min(NDOT, math.floor(v * NDOT + 0.0001))
        while lit < n do
            lit += 1
            popDot(dots[lit])
        end
    end)

    local function finish()
        if finished then return end
        finished = true
        local info = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        TweenService:Create(scale, info, {Scale = 1.18}):Play()
        local tw = TweenService:Create(root, info, {GroupTransparency = 1})
        tw:Play()
        tw.Completed:Wait()
        B.active = false
        root:Destroy()
    end

    local skipBtn = Instance.new("TextButton")
    skipBtn.Size = UDim2.new(1, 0, 1, 0)
    skipBtn.BackgroundTransparency = 1
    skipBtn.Text = ""
    skipBtn.ZIndex = 120
    skipBtn.Parent = root
    skipBtn.MouseButton1Click:Connect(function()
        if os.clock() - t0 > 1.5 then finish() end
    end)

    local function w(t) task.wait(t) return finished end
    local quint = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local back = TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    local function glitch()
        for _ = 1, 7 do
            if finished then return end
            logo.Position = UDim2.new(0.5, rnd(-5, 5), CY, rnd(-2, 2))
            for _, l in ipairs(letters) do
                l.TextColor3 = (rnd() > 0.5) and ACCL or WHITE
            end
            task.wait(0.035)
        end
        logo.Position = UDim2.new(0.5, 0, CY, 0)
        for _, l in ipairs(letters) do l.TextColor3 = WHITE end
    end

    task.spawn(function()
        if w(0.35) then return end

        local line = Instance.new("Frame")
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.Position = UDim2.new(0.5, 0, CY, 0)
        line.Size = UDim2.new(0, 0, 0, 2)
        line.BackgroundColor3 = ACCL
        line.BorderSizePixel = 0
        line.ZIndex = 110
        line.Parent = content
        TweenService:Create(line, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {Size = UDim2.new(1, 0, 0, 2)}):Play()
        if w(0.25) then return end
        local open = TweenService:Create(line, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(1, 0, 0, 200), BackgroundTransparency = 1})
        open.Completed:Once(function() line:Destroy() end)
        open:Play()
        TweenService:Create(glowA, TweenInfo.new(0.5), {BackgroundTransparency = glowAt}):Play()
        TweenService:Create(glowB, TweenInfo.new(0.5), {BackgroundTransparency = glowBt}):Play()

        task.spawn(function()
            while not finished do
                scan.Position = UDim2.new(0, 0, 0, -36)
                local t = TweenService:Create(scan, TweenInfo.new(2.4, Enum.EasingStyle.Linear), {Position = UDim2.new(0, 0, 1, 0)})
                t:Play()
                task.wait(2.8)
            end
        end)
        task.spawn(function()
            while not finished do
                spawnParticle()
                task.wait(0.22)
            end
        end)
        task.spawn(function()
            wave()
            while not finished do
                task.wait(0.9)
                if finished then break end
                wave()
            end
        end)

        task.spawn(function()
            for i = 1, NDOT do
                if finished then return end
                TweenService:Create(dots[i], TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                    {Size = UDim2.new(0, 3, 0, 3)}):Play()
                task.wait(0.014)
            end
        end)
        if w(0.2) then return end

        for _, l in ipairs(letters) do
            TweenService:Create(l, back, {TextTransparency = 0, Position = UDim2.new(0, 0, 0, 0)}):Play()
            if w(0.15) then return end
        end
        if w(0.3) then return end
        glitch()
        if finished then return end

        for i, g in ipairs(shines) do
            local sw = TweenService:Create(g, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                {Offset = Vector2.new(1, 0)})
            sw.Completed:Once(function() g.Enabled = false end)
            sw:Play()
            if w(0.11) then return end
        end
        TweenService:Create(sub, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {TextTransparency = 0}):Play()
        TweenService:Create(sub, quint, {Position = UDim2.new(0.5, 0, CY, 46)}):Play()
        TweenService:Create(footer, TweenInfo.new(0.6), {TextTransparency = 0.45}):Play()
        if w(0.55) then return end

        TweenService:Create(loader, TweenInfo.new(0.3), {GroupTransparency = 0}):Play()
        local steps = {
            {"Iniciando sistema", 0.5, 0.22},
            {"Carregando apps", 0.6, 0.5},
            {"Conectando ao servidor", 0.7, 0.78},
            {"Sincronizando GPS", 0.55, 0.95},
            {"Tudo pronto", 0.35, 1},
        }
        for _, st in ipairs(steps) do
            status.Text = st[1]
            status.TextTransparency = 1
            status.Position = UDim2.new(0, 0, 0, 5)
            TweenService:Create(status, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {TextTransparency = 0, Position = UDim2.new(0, 0, 0, 0)}):Play()
            TweenService:Create(prog, TweenInfo.new(st[2], Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Value = st[3]}):Play()
            if w(st[2]) then return end
        end

        wave(true)
        for _, d in ipairs(dots) do
            d.BackgroundColor3 = WHITE
            TweenService:Create(d, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {BackgroundColor3 = ACCB}):Play()
        end
        TweenService:Create(logo, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
            {Size = UDim2.new(0, 168, 0, 67)}):Play()
        if w(0.25) then return end

        TweenService:Create(loader, TweenInfo.new(0.25), {GroupTransparency = 1}):Play()
        local total = utf8.len(helloText) or #helloText
        for i = 1, total do
            hello.MaxVisibleGraphemes = i
            if w(0.05) then return end
        end
        TweenService:Create(helloLine, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 44, 0, 2)}):Play()
        if w(1.0) then return end
        finish()
    end)
end

local function closePhone()
    exitPhotoViewer()
    local target = UDim2.new(1, -300, 1, 80)
    for _, s in pairs(screens) do
        local f = s.frame
        if f.Visible then
            local tween = TweenService:Create(f, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position = target})
            tween.Completed:Once(function()
                if not isPhoneOpen then f.Visible = false end
            end)
            tween:Play()
        end
    end
    isPhoneOpen = false
    isMusicOpen = false
    currentScreen = "home"
    currentApp = "home"
    selectedFrame.Visible = false
    updateNavState()
end

local function openPhone()
    isPhoneOpen = true
    showScreen("home", false)
    PhoneHome.Position = UDim2.new(1, -300, 1, 80)
    TweenService:Create(PhoneHome, TweenInfo.new(0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = phonePos()}):Play()
    if not Nav.boot.done then Nav.boot.play() end
end

local function togglePhone()
    if isPhoneOpen then closePhone() else openPhone() end
end

local hold = false
local canDrag = false
local isDragging = false
local startPos = nil
local lastDragEnd = -10
local dragStart = nil

local function playHoldAnim(state)
    if not phoneSlot then return end
    local targetSize = state and UDim2.new(0, 42, 0, 42) or UDim2.new(0, 36, 0, 36)
    local targetColor = state and Color3.fromRGB(50, 205, 50) or Color3.fromRGB(28, 28, 36)
    TweenService:Create(phoneSlot, TweenInfo.new(state and 0.15 or 0.2, Enum.EasingStyle.Quad), {
        Size = targetSize,
        BackgroundColor3 = targetColor
    }):Play()
end

phoneSlot.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        hold = true
        canDrag = false
        isDragging = false
        startPos = HotbarFrame.Position
        dragStart = input.Position
        playHoldAnim(true)
        task.delay(0.45, function()
            if hold then
                canDrag = true
                isDragging = true
            end
        end)
    end
end)

phoneSlot.InputChanged:Connect(function(input)
    if canDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        HotbarFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

phoneSlot.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local wasDragging = canDrag or isDragging
        hold = false
        canDrag = false
        isDragging = false
        playHoldAnim(false)

        if wasDragging then
            lastDragEnd = os.clock()
            local pos = HotbarFrame.Position
            phoneSettings.hotbarPosition = {
                X = pos.X.Scale,
                Y = pos.Y.Scale,
                XOffset = pos.X.Offset,
                YOffset = pos.Y.Offset
            }
            saveSettings()
        end
    end
end)

phoneSlot.MouseButton1Click:Connect(function()
    if canDrag or isDragging or (os.clock() - lastDragEnd) < 0.3 then return end
    togglePhone()
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Zero or input.KeyCode == Enum.KeyCode.KeypadZero then
        togglePhone()
    end
end)
end

local function onCharacterAdded(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    phoneSettings.joinTime = os.clock()
    if phoneSettings.flashlightEnabled then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            if phoneFlashlight then phoneFlashlight:Destroy() end
            phoneFlashlight = Instance.new("SpotLight")
            phoneFlashlight.Name = "PhoneFlashlight"
            phoneFlashlight.Brightness = 2.5
            phoneFlashlight.Range = 35
            phoneFlashlight.Angle = 50
            phoneFlashlight.Face = Enum.NormalId.Front
            phoneFlashlight.Parent = root
        end
    end
end

Player.CharacterAdded:Connect(onCharacterAdded)
if Player.Character then onCharacterAdded(Player.Character) end

refreshFiles()

do
    local CFG = {
        ativo       = true,
        escala      = 0.8,
        balanco     = 0,

        ombro       = 53,
        cotovelo    = 68,
        punho       = -21,
        paraDentro  = 10,
        celularY    = -0.92,
        celularZ    = -0.09,

        ombroR6       = 78,
        paraDentroR6  = -6,
        r6Tilt        = 38,
        r6Y           = -1.08,
        r6X           = -0.36,
        r6Z           = -0.16,

        giroCelular    = {R15 = 33, R6 = 53},
        celularInclina = {R15 = 26, R6 = 47},
        celularRolagem = {R15 = -41, R6 = -1},
        bracoEsq       = {R15 = 27, R6 = 41},
        sinalGiro      = {R15 = 1,  R6 = -1},
    }

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local LP = Players.LocalPlayer

    local W, H, T, R = 0.90, 1.82, 0.10, 0.15
    local rad = math.rad

    local state = {model = nil, parts = {}, alpha = 0, tgt = 0, weld = nil, joints = nil,
                   metalParts = {}, backGlass = nil, screenGui = nil, flash = nil,
                   clock = nil, date = nil, wall = nil, lastWall = nil, lastTheme = nil, char = nil}

    local function newPart(name, size, cf, color, material, parent)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size
        p.CFrame = cf
        p.Color = color
        p.Material = material or Enum.Material.SmoothPlastic
        p.Anchored = false
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.Massless = true
        p.CastShadow = false
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Parent = parent
        table.insert(state.parts, p)
        return p
    end

    local function slab(name, w, h, t, r, cf, color, material, parent, tag)
        local made = {}
        local function add(n, size, off, isCyl)
            local c = cf * off
            if isCyl then c = c * CFrame.Angles(0, rad(90), 0) end
            local p = newPart(name .. n, size, c, color, material, parent)
            if isCyl then p.Shape = Enum.PartType.Cylinder end
            table.insert(made, p)
            return p
        end
        add("_c", Vector3.new(w - 2 * r, h, t), CFrame.new())
        add("_l", Vector3.new(r, h - 2 * r, t), CFrame.new(-(w - r) / 2, 0, 0))
        add("_r", Vector3.new(r, h - 2 * r, t), CFrame.new((w - r) / 2, 0, 0))
        for _, sx in ipairs({-1, 1}) do
            for _, sy in ipairs({-1, 1}) do
                add("_k", Vector3.new(t, 2 * r, 2 * r), CFrame.new(sx * (w / 2 - r), sy * (h / 2 - r), 0), true)
            end
        end
        if tag then for _, p in ipairs(made) do table.insert(tag, p) end end
        return made
    end

    local function cyl(name, d, len, cf, color, material, parent)
        local p = newPart(name, Vector3.new(len, d, d), cf * CFrame.Angles(0, rad(90), 0), color, material, parent)
        p.Shape = Enum.PartType.Cylinder
        return p
    end

    local function themeColors()
        local ok, c = pcall(function()
            local sh = Nav.shell
            local th = sh.themes[sh.current or phoneSettings.caseTheme or "titanio"]
            return th.metal
        end)
        if ok and c then return c, (Nav.shell.current) end
        return {Color3.fromRGB(222, 217, 206), Color3.fromRGB(152, 147, 138), Color3.fromRGB(86, 83, 78)}, "titanio"
    end

    local function buildScreenGui(display)
        local sg = Instance.new("SurfaceGui")
        sg.Name = "TZE_Screen"
        sg.Face = Enum.NormalId.Front
        sg.Adornee = display
        sg.CanvasSize = Vector2.new(470, 1000)
        sg.LightInfluence = 0
        sg.Brightness = 1.35
        sg.AlwaysOnTop = false
        sg.ClipsDescendants = true
        sg.Parent = display

        local root = Instance.new("Frame")
        root.Size = UDim2.fromScale(1, 1)
        root.BackgroundColor3 = Color3.new(0, 0, 0)
        root.BorderSizePixel = 0
        root.Parent = sg
        local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 56); rc.Parent = root

        local wall = Instance.new("ImageLabel")
        wall.Name = "Wallpaper"
        wall.Size = UDim2.fromScale(1, 1)
        wall.BackgroundColor3 = Color3.fromRGB(20, 24, 40)
        wall.BorderSizePixel = 0
        wall.ScaleType = Enum.ScaleType.Crop
        wall.Image = ""
        wall.Parent = root
        local wc = Instance.new("UICorner"); wc.CornerRadius = UDim.new(0, 56); wc.Parent = wall
        local grad = Instance.new("UIGradient")
        grad.Rotation = 90
        grad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)})
        grad.Parent = wall

        local shade = Instance.new("Frame")
        shade.Size = UDim2.fromScale(1, 1)
        shade.BackgroundColor3 = Color3.new(0, 0, 0)
        shade.BackgroundTransparency = 0.78
        shade.BorderSizePixel = 0
        shade.Parent = wall
        local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 56); sc.Parent = shade

        local isl = Instance.new("Frame")
        isl.AnchorPoint = Vector2.new(0.5, 0)
        isl.Position = UDim2.new(0.5, 0, 0, 22)
        isl.Size = UDim2.fromOffset(150, 42)
        isl.BackgroundColor3 = Color3.new(0, 0, 0)
        isl.BorderSizePixel = 0
        isl.Parent = root
        local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(1, 0); ic.Parent = isl
        local lens = Instance.new("Frame")
        lens.AnchorPoint = Vector2.new(0.5, 0.5)
        lens.Position = UDim2.new(1, -22, 0.5, 0)
        lens.Size = UDim2.fromOffset(16, 16)
        lens.BackgroundColor3 = Color3.fromRGB(24, 30, 60)
        lens.BorderSizePixel = 0
        lens.Parent = isl
        local lc = Instance.new("UICorner"); lc.CornerRadius = UDim.new(1, 0); lc.Parent = lens

        local clock = Instance.new("TextLabel")
        clock.BackgroundTransparency = 1
        clock.AnchorPoint = Vector2.new(0.5, 0)
        clock.Position = UDim2.new(0.5, 0, 0, 130)
        clock.Size = UDim2.new(1, 0, 0, 170)
        clock.Font = Enum.Font.GothamBold
        clock.Text = "00:00"
        clock.TextColor3 = Color3.new(1, 1, 1)
        clock.TextSize = 150
        clock.TextStrokeTransparency = 0.8
        clock.Parent = root

        local date = Instance.new("TextLabel")
        date.BackgroundTransparency = 1
        date.AnchorPoint = Vector2.new(0.5, 0)
        date.Position = UDim2.new(0.5, 0, 0, 108)
        date.Size = UDim2.new(1, 0, 0, 36)
        date.Font = Enum.Font.GothamMedium
        date.Text = ""
        date.TextColor3 = Color3.fromRGB(235, 235, 245)
        date.TextSize = 30
        date.Parent = root

        local cols = {Color3.fromRGB(255, 95, 109), Color3.fromRGB(88, 196, 255), Color3.fromRGB(120, 230, 140), Color3.fromRGB(255, 205, 90)}
        for i = 1, 4 do
            local b = Instance.new("Frame")
            b.AnchorPoint = Vector2.new(0.5, 1)
            b.Position = UDim2.new((i - 0.5) / 4, 0, 1, -50)
            b.Size = UDim2.fromOffset(78, 78)
            b.BackgroundColor3 = cols[i]
            b.BorderSizePixel = 0
            b.Parent = root
            local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 22); bc.Parent = b
            local bg = Instance.new("UIGradient")
            bg.Rotation = 90
            bg.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 200))
            bg.Transparency = NumberSequence.new(0.55, 0.15)
            bg.Parent = b
        end
        local bar = Instance.new("Frame")
        bar.AnchorPoint = Vector2.new(0.5, 1)
        bar.Position = UDim2.new(0.5, 0, 1, -16)
        bar.Size = UDim2.fromOffset(150, 7)
        bar.BackgroundColor3 = Color3.new(1, 1, 1)
        bar.BackgroundTransparency = 0.15
        bar.BorderSizePixel = 0
        bar.Parent = root
        local bcr = Instance.new("UICorner"); bcr.CornerRadius = UDim.new(1, 0); bcr.Parent = bar

        state.screenGui, state.wall, state.clock, state.date = sg, wall, clock, date
    end

    local V3d = Vector3.new
    local ZERO3 = V3d()
    local PK = {"rsh", "rel", "rwr"}
    local PP = {FadeIn = 0.14, FadeOut = 0.18, Intensity = 1.0}
    local PP_BIND = "TZE_PhonePose"

    local function spSmooth(a) return a * a * (3 - 2 * a) end

    local function spParts(m)
        if m:IsA("AnimationConstraint") then
            local a0, a1 = m.Attachment0, m.Attachment1
            return a0 and a0.Parent, a1 and a1.Parent
        end
        return m.Part0, m.Part1
    end
    local function spValid(m)
        if not m.Parent then return false end
        local p0, p1 = spParts(m)
        return p0 ~= nil and p1 ~= nil
    end
    local function spGetC0(m)
        if m:IsA("AnimationConstraint") then
            local a = m.Attachment0
            return a and a.CFrame or CFrame.new()
        end
        return m.C0
    end
    local function spSetC0(m, cf)
        if m:IsA("AnimationConstraint") then
            local a = m.Attachment0
            if a then a.CFrame = cf end
        else
            m.C0 = cf
        end
    end

    local SP_KIN = setmetatable({}, {__mode = "k"})
    local SP_BASE = setmetatable({}, {__mode = "k"})

    local function spJoints(ch)
        local map = {
            rsh = {"RightUpperArm", "Right Arm"},
            rel = {"RightLowerArm"},
            rwr = {"RightHand"},
        }
        local J = {}
        for _, d in ipairs(ch:GetDescendants()) do
            if d:IsA("JointInstance") or d:IsA("AnimationConstraint") then
                local p0, p1 = spParts(d)
                if p0 and p1 then
                    for key, names in pairs(map) do
                        if not J[key] then
                            for _, n in ipairs(names) do
                                if p1.Name == n then J[key] = d end
                            end
                        end
                    end
                end
            end
        end
        local rig
        if J.rsh then
            local _, p1 = spParts(J.rsh)
            rig = (p1 and p1.Name == "RightUpperArm") and "R15" or "R6"
        end
        for _, m in pairs(J) do
            if m:IsA("AnimationConstraint") and SP_KIN[m] == nil then
                pcall(function() SP_KIN[m] = m.IsKinematic; m.IsKinematic = true end)
            end
        end
        return J, rig
    end

    local function detectRig(ch, J)
        local forced = _G.TZE_ForceRig
        if forced == "R15" or forced == "R6" then return forced, "forçado por _G.TZE_ForceRig" end
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if hum then
            if hum.RigType == Enum.HumanoidRigType.R15 then return "R15", "Humanoid.RigType" end
            if hum.RigType == Enum.HumanoidRigType.R6 then return "R6", "Humanoid.RigType" end
        end
        if ch:FindFirstChild("RightUpperArm") then return "R15", "peça RightUpperArm" end
        if ch:FindFirstChild("Right Arm") then return "R6", "peça Right Arm" end
        if J and J.rsh then
            local _, p1 = spParts(J.rsh)
            if p1 and p1.Name == "RightUpperArm" then return "R15", "junta do ombro" end
            if p1 and p1.Name == "Right Arm" then return "R6", "junta do ombro" end
        end
        return nil, "rig não reconhecido"
    end

    local function spTangent(frames, i, key)
        local f = frames[i]
        if f.hold or i == 1 or i == #frames then return nil end
        local p, n = frames[i - 1], frames[i + 1]
        return ((n[key] or ZERO3) - (p[key] or ZERO3)) / (n.t - p.t)
    end
    local function spEvalFrames(frames, t)
        local last = frames[#frames]
        local pose = {}
        if t >= last.t then
            for _, k in ipairs(PK) do pose[k] = last[k] or ZERO3 end
            return pose
        end
        local ia = 1
        for i = 1, #frames - 1 do
            if t >= frames[i].t and t < frames[i + 1].t then ia = i break end
        end
        local a, b = frames[ia], frames[ia + 1]
        local dt = b.t - a.t
        local s = (t - a.t) / dt
        local s2, s3 = s * s, s * s * s
        local h00, h10, h01, h11 = 2 * s3 - 3 * s2 + 1, s3 - 2 * s2 + s, -2 * s3 + 3 * s2, s3 - s2
        for _, k in ipairs(PK) do
            local t0 = spTangent(frames, ia, k) or ZERO3
            local t1 = spTangent(frames, ia + 1, k) or ZERO3
            pose[k] = (a[k] or ZERO3) * h00 + t0 * (h10 * dt) + (b[k] or ZERO3) * h01 + t1 * (h11 * dt)
        end
        return pose
    end

    local function phoneFrames(rig)
        local tgt
        if rig == "R6" then

            tgt = {rsh = V3d(CFG.ombroR6, 0, CFG.paraDentroR6 - CFG.bracoEsq.R6), rel = ZERO3, rwr = ZERO3}
        else
            tgt = {rsh = V3d(CFG.ombro, 0, CFG.paraDentro - CFG.bracoEsq.R15), rel = V3d(CFG.cotovelo, 0, 0), rwr = V3d(0, CFG.punho, 0)}
        end
        return {
            {t = 0.00, rsh = ZERO3, rel = ZERO3, rwr = ZERO3},
            {t = 0.16, rsh = tgt.rsh * 1.12, rel = tgt.rel * 1.10, rwr = tgt.rwr * 0.9},
            {t = 0.34, hold = true, rsh = tgt.rsh, rel = tgt.rel, rwr = tgt.rwr},
        }
    end

    local SP = {J = nil, char = nil, t0 = 0, w = 0, fading = false, fadeTime = 0.2, bound = false,
                evalFn = nil, lastClock = 0, lastScan = 0, conns = nil}

    local function spApply(m, rotDeg, w)
        local base = SP_BASE[m]
        if not base then
            base = spGetC0(m)
            SP_BASE[m] = base
        end
        local c0 = base - base.Position
        local A = CFrame.Angles(rad(rotDeg.X), rad(rotDeg.Y), rad(rotDeg.Z))
        local tf = c0:Inverse() * A * c0
        spSetC0(m, base * CFrame.new():Lerp(tf, w))
    end

    local function spDisconnect()
        if SP.tconns then
            for _, c in ipairs(SP.tconns) do pcall(function() c:Disconnect() end) end
            SP.tconns = nil
        end
        if SP.conns then
            for _, c in ipairs(SP.conns) do pcall(function() c:Disconnect() end) end
            SP.conns = nil
        end
    end

    function SP.reset()
        if SP.J then
            for _, m in pairs(SP.J) do
                if m.Parent then
                    local base = SP_BASE[m]
                    if base then spSetC0(m, base) end
                    if m:IsA("Motor6D") or m:IsA("AnimationConstraint") then m.Transform = CFrame.new() end
                    if m:IsA("AnimationConstraint") and SP_KIN[m] ~= nil then
                        local k = SP_KIN[m]
                        SP_KIN[m] = nil
                        pcall(function() m.IsKinematic = k end)
                    end
                end
            end
        end
        SP.J, SP.char = nil, nil
    end

    function SP.stopNow()
        if SP.bound then
            pcall(function() RunService:UnbindFromRenderStep(PP_BIND) end)
            SP.bound = false
        end
        spDisconnect()
        SP.reset()
        SP.fading = false
        SP.w = 0
    end

    function SP.stop(fade)
        if not SP.bound then return end
        SP.fading = true
        SP.fadeTime = math.max(fade or PP.FadeOut, 0.01)
    end

    local function spStep(isMain)
        if not SP.bound then return end
        local char = SP.char
        if not char or not char.Parent then SP.stopNow() return end

        local now = os.clock()
        local dt = math.clamp(now - SP.lastClock, 0, 0.1)
        SP.lastClock = now
        local rate = SP.fading and (1 / SP.fadeTime) or (1 / math.max(PP.FadeIn, 0.01))
        local goal = SP.fading and 0 or 1
        SP.w = SP.w + math.clamp(goal - SP.w, -rate * dt, rate * dt)
        if SP.fading and SP.w <= 0.001 then SP.stopNow() return end

        local J = SP.J
        local broken = false
        for _, m in pairs(J) do
            if not spValid(m) then broken = true break end
        end
        if broken and now - SP.lastScan > 0.2 then
            SP.lastScan = now
            J = spJoints(char)
            SP.J = J
        end

        local ok, pose = pcall(SP.evalFn, now - SP.t0)
        if not ok or not pose then
            warn("[TZE PHONE 3D] erro no avaliador: " .. tostring(pose))
            SP.stopNow()
            return
        end

        local w = spSmooth(math.clamp(SP.w, 0, 1))
        for key, m in pairs(J) do
            if spValid(m) then
                local r = pose[key]
                if r then spApply(m, r * PP.Intensity, w) end

                if m:IsA("Motor6D") or m:IsA("AnimationConstraint") then
                    SP.lock = true
                    m.Transform = m.Transform:Lerp(CFrame.new(), w)
                    SP.lock = false
                end
            end
        end
    end

    function SP.start(char, evalFn)
        SP.stopNow()
        if not char or not evalFn then return false end
        local J, rig = spJoints(char)
        if not J.rsh then
            warn("[TZE PHONE 3D] nenhuma junta do braço direito encontrada (rig diferente?)")
            return false
        end
        SP.J, SP.char, SP.evalFn = J, char, evalFn
        SP.t0 = os.clock()
        SP.lastClock = SP.t0
        SP.lastScan = 0
        SP.w = 0
        SP.fading = false
        SP.bound = true

        SP.tconns = {}
        for _, m in pairs(J) do
            if m:IsA("Motor6D") or m:IsA("AnimationConstraint") then
                local ok, c = pcall(function()
                    return m:GetPropertyChangedSignal("Transform"):Connect(function()
                        if SP.lock or not SP.bound or SP.w < 0.999 or SP.fading then return end
                        SP.lock = true
                        m.Transform = CFrame.new()
                        SP.lock = false
                    end)
                end)
                if ok then table.insert(SP.tconns, c) end
            end
        end
        RunService:BindToRenderStep(PP_BIND, Enum.RenderPriority.Last.Value, function() spStep(true) end)
        SP.conns = {
            RunService.Stepped:Connect(function() spStep(false) end),
            RunService.Heartbeat:Connect(function() spStep(false) end),
        }
        return true
    end

    local function computeGrip(rig, hand)
        local s = CFG.escala
        if rig == "R15" then

            local x = -(hand.Size.X / 2 + (T * s) / 2 - 0.05)
            return CFrame.fromMatrix(Vector3.new(x, CFG.celularY * s, CFG.celularZ),
                Vector3.new(0, 0, -1), Vector3.new(0, -1, 0), Vector3.new(-1, 0, 0))
        else

            local z = -(hand.Size.Z / 2 + (T * s) / 2 - 0.05) + CFG.r6Z
            return CFrame.new(CFG.r6X, CFG.r6Y * s, z) * CFrame.Angles(rad(CFG.r6Tilt), 0, 0)
                * CFrame.fromMatrix(Vector3.new(), Vector3.new(1, 0, 0), Vector3.new(0, -1, 0), Vector3.new(0, 0, -1))
        end
    end

    local function build(char)
        local J = spJoints(char)
        local rig, why = detectRig(char, J)
        if not (J.rsh and rig) then
            warn("[TZE PHONE 3D] braço direito não encontrado (R15 ou R6 necessário). Checker: " .. tostring(why))
            return false
        end
        print("[TZE PHONE 3D] Rig detectado: " .. rig .. " (" .. why .. ")")
        local hand = (rig == "R15") and char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
        if not hand then return false end
        state.joints, state.rig = J, rig

        for _, o in ipairs(char:GetChildren()) do
            if o.Name == "TZE_Phone3D" then o:Destroy() end
        end
        state.parts, state.metalParts = {}, {}

        local model = Instance.new("Model")
        model.Name = "TZE_Phone3D"
        model.Parent = char
        state.model = model

        local metal = themeColors()
        local met, glass = metal[2], Color3.fromRGB(8, 8, 10)

        local body = slab("Corpo", W, H, T, R, CFrame.new(), met, Enum.Material.Metal, model, state.metalParts)
        local rootPart = body[1]
        model.PrimaryPart = rootPart

        slab("Traseira", W - 0.05, H - 0.05, 0.012, R - 0.02, CFrame.new(0, 0, -T / 2 - 0.002), metal[1], Enum.Material.SmoothPlastic, model, state.metalParts)

        slab("Vidro", W - 0.05, H - 0.05, 0.012, R - 0.02, CFrame.new(0, 0, T / 2 + 0.002), glass, Enum.Material.Glass, model)

        local display = newPart("Display", Vector3.new(W - 0.11, H - 0.11, 0.002), CFrame.new(0, 0, T / 2 + 0.0095), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, model)
        buildScreenGui(display)

        local cx, cy, cz = 0.14, 0.66, -T / 2 - 0.03
        slab("ModCam", 0.5, 0.5, 0.03, 0.11, CFrame.new(cx, cy, cz), metal[3], Enum.Material.SmoothPlastic, model, state.metalParts)
        local lensPos = {{cx + 0.12, cy + 0.12}, {cx - 0.12, cy + 0.12}, {cx + 0.12, cy - 0.12}}
        for i, lp in ipairs(lensPos) do
            cyl("AroLente" .. i, 0.21, 0.035, CFrame.new(lp[1], lp[2], cz - 0.025), Color3.fromRGB(55, 55, 60), Enum.Material.Metal, model)
            cyl("Lente" .. i, 0.15, 0.04, CFrame.new(lp[1], lp[2], cz - 0.03), Color3.fromRGB(10, 14, 28), Enum.Material.Glass, model)
            cyl("Brilho" .. i, 0.04, 0.042, CFrame.new(lp[1] + 0.03, lp[2] + 0.03, cz - 0.031), Color3.fromRGB(120, 150, 255), Enum.Material.Neon, model)
        end
        local flash = cyl("Flash", 0.07, 0.03, CFrame.new(cx - 0.12, cy - 0.12, cz - 0.02), Color3.fromRGB(255, 244, 200), Enum.Material.Neon, model)
        state.flash = flash
        local pl = Instance.new("PointLight")
        pl.Range = 0; pl.Brightness = 0; pl.Color = Color3.fromRGB(255, 244, 210); pl.Parent = flash

        local logo = cyl("Logo", 0.2, 0.01, CFrame.new(0, -0.15, -T / 2 - 0.009), Color3.fromRGB(240, 240, 245), Enum.Material.SmoothPlastic, model)
        logo.Transparency = 0.5

        local function btn(n, x, y, h) newPart(n, Vector3.new(0.03, h, 0.05), CFrame.new(x, y, 0), met, Enum.Material.Metal, model) ; table.insert(state.metalParts, state.parts[#state.parts]) end
        btn("Power", W / 2 + 0.008, 0.25, 0.30)
        btn("VolCima", -W / 2 - 0.008, 0.30, 0.20)
        btn("VolBaixo", -W / 2 - 0.008, 0.05, 0.20)
        btn("Acao", -W / 2 - 0.008, 0.55, 0.10)

        if CFG.escala ~= 1 then
            for _, p in ipairs(state.parts) do
                p.Size = p.Size * CFG.escala
                p.CFrame = rootPart.CFrame * ((rootPart.CFrame:Inverse() * p.CFrame).Rotation + (rootPart.CFrame:Inverse() * p.CFrame).Position * CFG.escala)
            end
        end

        for _, p in ipairs(state.parts) do
            if p ~= rootPart then
                local wc = Instance.new("WeldConstraint")
                wc.Part0 = rootPart
                wc.Part1 = p
                wc.Parent = p
            end
        end

        local c0 = computeGrip(rig, hand)
        state.hand = hand
        local weld = Instance.new("Weld")
        weld.Name = "TZE_PhoneGrip"
        weld.Part0 = hand
        weld.Part1 = rootPart
        weld.C0 = c0
        weld.Parent = rootPart
        state.weld = weld
        state.baseC0 = c0
        state.lastGiro = nil
        state.char = char
        state.lastTheme, state.lastWall = nil, nil
        return true
    end

    local function setLTM(v)
        for _, p in ipairs(state.parts) do
            if p.Parent then p.LocalTransparencyModifier = v end
        end
    end

    local lastLTM = -1
    local function refreshVisual(t)

        local metal, name = themeColors()
        if state.lastTheme ~= name then
            state.lastTheme = name
            for _, p in ipairs(state.metalParts) do
                if p.Name:sub(1, 8) == "Traseira" then p.Color = metal[1]
                elseif p.Name:sub(1, 6) == "ModCam" then p.Color = metal[3]
                else p.Color = metal[2] end
            end
        end

        local wp = currentWallpaper
        if state.wall and wp and state.lastWall ~= wp then
            state.lastWall = wp
            pcall(function() state.wall.Image = wp end)
        end

        if state.clock then
            local tm = os.date("%H:%M")
            if state.clock.Text ~= tm then state.clock.Text = tm end
            local dt = os.date("%d/%m")
            if state.date and state.date.Text ~= dt then state.date.Text = dt end
        end

        if state.flash and state.flash.Parent then
            local on = phoneSettings.flashlightEnabled and true or false
            local pl = state.flash:FindFirstChildOfClass("PointLight")
            if pl then pl.Range = on and 14 or 0; pl.Brightness = on and 2 or 0 end
            state.flash.Material = on and Enum.Material.Neon or Enum.Material.Glass
        end
    end

    local function makeEval(rig)
        local frames, ver = phoneFrames(rig), state.poseVer
        return function(t)
            if ver ~= state.poseVer then frames, ver = phoneFrames(rig), state.poseVer end
            local pose = spEvalFrames(frames, t)
            if CFG.balanco > 0 then
                local sw = math.sin(os.clock() * 1.6) * CFG.balanco
                pose.rsh = pose.rsh + V3d(sw, 0, 0)
                if rig == "R15" then pose.rel = pose.rel - V3d(sw * 1.5, 0, 0) end
            end
            return pose
        end
    end

    local function holsterC0(rig, waist)
        local s = CFG.escala

        local offX =  (waist.Size.X / 2) + (W * s) / 2 - 0.05
        local offY = -0.10
        local offZ = -0.10

        return CFrame.new(offX, offY, offZ)
            * CFrame.fromMatrix(Vector3.new(),
                Vector3.new(0,  1,  0),
                Vector3.new(0,  0, -1),
                Vector3.new(-1, 0,  0))
            * CFrame.Angles(0, 0, rad(-12))
    end

    local function reweld(newPart0, newC0)
        if not state.weld or not state.weld.Parent then return end
        state.weld.Part0 = newPart0
        state.weld.C0    = newC0
        state.lastGiro   = nil
    end

    local holsterAttached = false

    local function onStep(dt)
        local char = LP.Character
        if not char then return end
        if state.rebuildAt and os.clock() >= state.rebuildAt then
            state.rebuildAt = nil
            if state.model then state.model:Destroy(); state.model = nil end
            lastLTM = -1
            holsterAttached = false
        end
        if state.char ~= char or not state.model or not state.model.Parent then
            SP.stopNow()
            if not build(char) then return end
            holsterAttached = false
        end
        local want = (CFG.ativo and _G.TZE_Phone3D ~= false and isPhoneOpen) and 1 or 0
        state.alpha = state.alpha + (want - state.alpha) * math.clamp(dt * 9, 0, 1)
        if math.abs(state.alpha - want) < 0.005 then state.alpha = want end
        local a = state.alpha

        if state.weld and state.rig and state.hand then
            if want == 1 then

                if holsterAttached then
                    reweld(state.hand, state.baseC0)
                    holsterAttached = false
                end

                local g = tonumber(_G.TZE_PhoneGiro) or CFG.giroCelular[state.rig] or 0
                g = g * (CFG.sinalGiro[state.rig] or 1)
                local inc, rol = CFG.celularInclina[state.rig] or 0, CFG.celularRolagem[state.rig] or 0
                local key = g .. "|" .. inc .. "|" .. rol
                if state.lastGiro ~= key then
                    state.lastGiro = key
                    state.weld.C0 = state.baseC0 * CFrame.Angles(rad(inc), rad(g), rad(rol))
                end
            else

                if not holsterAttached then
                    local waistName = (state.rig == "R15") and "LowerTorso" or "Torso"
                    local waist = char:FindFirstChild(waistName)
                    if waist then
                        reweld(waist, holsterC0(state.rig, waist))
                        holsterAttached = true
                    end
                end
            end
        end

        local ltm
        if want == 0 and holsterAttached then
            ltm = 0
        else
            ltm = 1 - a
        end
        if math.abs(ltm - lastLTM) > 0.004 then lastLTM = ltm; setLTM(ltm) end
        if state.screenGui then state.screenGui.Enabled = (want == 1 and a > 0.35) end

        if want == 1 then
            if SP.bound and SP.char == char then
                SP.fading = false
            else
                SP.start(char, makeEval(state.rig))
            end
        elseif SP.bound and not SP.fading then
            SP.stop(PP.FadeOut)
        end

        if a <= 0 and not holsterAttached then return end
        if a > 0.5 or holsterAttached then refreshVisual(os.clock()) end
    end

    local function applyLive(kind)
        if kind == "pose" then
            state.poseVer = (state.poseVer or 0) + 1
        elseif kind == "grip" then
            if state.rig and state.hand then
                state.baseC0 = computeGrip(state.rig, state.hand)
                state.lastGiro = nil
            end
        elseif kind == "giro" then
            state.lastGiro = nil
        elseif kind == "scale" then
            state.rebuildAt = os.clock() + 0.3
        end
    end

    local function createEditor()
        pcall(function() destroyOld("TzePhoneEditor") end)
        if _G.TZE_PhoneEditorConns then
            for _, c in ipairs(_G.TZE_PhoneEditorConns) do pcall(function() c:Disconnect() end) end
        end
        local conns = {}
        _G.TZE_PhoneEditorConns = conns

        local ACC = Color3.fromRGB(90, 140, 255)
        local BG = Color3.fromRGB(22, 22, 28)
        local BG2 = Color3.fromRGB(38, 38, 50)
        local TXT = Color3.fromRGB(235, 235, 245)
        local SUB = Color3.fromRGB(150, 150, 172)

        local function mk(class, props, parent)
            local o = Instance.new(class)
            for k, v in pairs(props) do o[k] = v end
            o.Parent = parent
            return o
        end
        local function corner(o, r) mk("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o) end
        local function fmt(v) return tostring(math.floor(v * 100 + 0.5) / 100) end
        local function deepCopy(t)
            local c = {}
            for k, v in pairs(t) do c[k] = type(v) == "table" and deepCopy(v) or v end
            return c
        end
        local DEFAULT = deepCopy(CFG)

        local function F(key, label, mn, mx, st, live)
            return {label = label, min = mn, max = mx, step = st, live = live,
                get = function() return CFG[key] end, set = function(v) CFG[key] = v end}
        end
        local function N(tbl, rig, label, mn, mx, st, live)
            return {label = label, min = mn, max = mx, step = st, live = live,
                get = function() return CFG[tbl][rig] end, set = function(v) CFG[tbl][rig] = v end}
        end
        local SPECS = {
            R15 = {
                N("giroCelular", "R15", "Giro do celular (+ = direita)", -180, 180, 1, "giro"),
                N("celularInclina", "R15", "Inclinar celular (frente/trás)", -90, 90, 1, "giro"),
                N("celularRolagem", "R15", "Rolar celular (tela no plano)", -90, 90, 1, "giro"),
                N("bracoEsq", "R15", "Braço p/ esquerda (+ = esq)", -60, 60, 1, "pose"),
                F("ombro", "Ombro (levantar)", 0, 150, 1, "pose"),
                F("cotovelo", "Cotovelo (dobra)", 0, 150, 1, "pose"),
                F("punho", "Punho (vira a palma)", -180, 180, 1, "pose"),
                F("paraDentro", "Braço Z (+ fora / − dentro)", -45, 45, 1, "pose"),
                F("celularY", "Posição na mão (Y)", -2, 2, 0.01, "grip"),
                F("celularZ", "Posição lateral (Z)", -1.5, 1.5, 0.01, "grip"),
                F("escala", "Tamanho do celular", 0.5, 2, 0.05, "scale"),
                F("balanco", "Balanço do braço (0 = parado)", 0, 5, 0.1, nil),
            },
            R6 = {
                N("giroCelular", "R6", "Giro do celular (+ = direita)", -180, 180, 1, "giro"),
                N("celularInclina", "R6", "Inclinar celular (frente/trás)", -90, 90, 1, "giro"),
                N("celularRolagem", "R6", "Rolar celular (tela no plano)", -90, 90, 1, "giro"),
                N("bracoEsq", "R6", "Braço p/ esquerda (+ = esq)", -60, 60, 1, "pose"),
                F("ombroR6", "Ombro (levantar)", 0, 150, 1, "pose"),
                F("paraDentroR6", "Braço Z base (− = dentro)", -60, 60, 1, "pose"),
                F("r6Tilt", "Inclinação da tela p/ rosto", -90, 90, 1, "grip"),
                F("r6Y", "Posição no braço (Y)", -3, 3, 0.01, "grip"),
                F("r6X", "Deslocamento lateral (X)", -2, 2, 0.01, "grip"),
                F("r6Z", "Afasta/aproxima (Z)", -2, 2, 0.01, "grip"),
                F("escala", "Tamanho do celular", 0.5, 2, 0.05, "scale"),
                F("balanco", "Balanço do braço (0 = parado)", 0, 5, 0.1, nil),
            },
        }

        local gui = mk("ScreenGui", {Name = "TzePhoneEditor", ResetOnSpawn = false, IgnoreGuiInset = true,
            DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, GUI_PARENT)

        local fab = mk("TextButton", {Text = "🛠", TextSize = 20, Font = Enum.Font.GothamBold, TextColor3 = TXT,
            BackgroundColor3 = BG, Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 8, 0.5, -20)}, gui)
        corner(fab, 20)
        mk("UIStroke", {Color = ACC, Thickness = 1.5}, fab)

        local panel = mk("Frame", {Visible = false, BackgroundColor3 = BG, Size = UDim2.fromOffset(320, 460),
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Active = true}, gui)
        corner(panel, 12)
        mk("UIStroke", {Color = ACC, Thickness = 1.5}, panel)
        local pscale = mk("UIScale", {}, panel)
        local function fit()
            local cam = Workspace.CurrentCamera
            if cam then
                local v = cam.ViewportSize
                pscale.Scale = math.clamp(math.min(v.X / 340, v.Y / 480), 0.5, 1)
            end
        end
        fit()

        local title = mk("Frame", {BackgroundColor3 = BG2, Size = UDim2.new(1, 0, 0, 36), Active = true}, panel)
        corner(title, 12)
        mk("TextLabel", {BackgroundTransparency = 1, Text = "🛠 Editor do Celular 3D", Font = Enum.Font.GothamBold,
            TextSize = 14, TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0, 170, 1, 0)}, title)
        local rigLbl = mk("TextLabel", {BackgroundTransparency = 1, Text = "Rig: —", Font = Enum.Font.GothamMedium,
            TextSize = 12, TextColor3 = ACC, TextXAlignment = Enum.TextXAlignment.Right,
            Position = UDim2.new(1, -112, 0, 0), Size = UDim2.new(0, 80, 1, 0)}, title)
        local closeB = mk("TextButton", {Text = "✕", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = TXT,
            BackgroundTransparency = 1, Position = UDim2.new(1, -30, 0, 0), Size = UDim2.fromOffset(30, 36)}, title)

        local tabs, curTab = {}, "R15"
        for i, r in ipairs({"R15", "R6"}) do
            tabs[r] = mk("TextButton", {Text = r, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = TXT,
                BackgroundColor3 = BG2, Size = UDim2.new(0.5, -11, 0, 28),
                Position = UDim2.new((i - 1) * 0.5, i == 1 and 8 or 3, 0, 42)}, panel)
            corner(tabs[r], 8)
        end

        local scroll = mk("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0,
            Position = UDim2.new(0, 8, 0, 76), Size = UDim2.new(1, -16, 0, 332), ScrollBarThickness = 4,
            CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y}, panel)
        mk("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)

        local bExport = mk("TextButton", {Text = "📤 Exportar configurações", Font = Enum.Font.GothamBold, TextSize = 13,
            TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = ACC, Position = UDim2.new(0, 8, 1, -44),
            Size = UDim2.new(1, -108, 0, 36)}, panel)
        corner(bExport, 8)
        local bReset = mk("TextButton", {Text = "↺ Padrão", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = TXT,
            BackgroundColor3 = BG2, Position = UDim2.new(1, -92, 1, -44), Size = UDim2.fromOffset(84, 36)}, panel)
        corner(bReset, 8)

        local active
        local refreshers = {}

        local function makeRow(spec)
            local row = mk("Frame", {BackgroundColor3 = BG2, Size = UDim2.new(1, -6, 0, 50)}, scroll)
            corner(row, 8)
            mk("TextLabel", {BackgroundTransparency = 1, Text = spec.label, Font = Enum.Font.GothamMedium, TextSize = 11,
                TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 10, 0, 4),
                Size = UDim2.new(1, -90, 0, 16)}, row)
            local box = mk("TextBox", {Text = "", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = TXT,
                BackgroundColor3 = BG, ClearTextOnFocus = false, Position = UDim2.new(1, -72, 0, 4),
                Size = UDim2.fromOffset(64, 20)}, row)
            corner(box, 5)
            local hit = mk("TextButton", {Text = "", BackgroundTransparency = 1, AutoButtonColor = false,
                Position = UDim2.new(0, 10, 0, 26), Size = UDim2.new(1, -20, 0, 20)}, row)
            local track = mk("Frame", {BackgroundColor3 = BG, Position = UDim2.new(0, 0, 0.5, -3), Size = UDim2.new(1, 0, 0, 6)}, hit)
            corner(track, 3)
            local fill = mk("Frame", {BackgroundColor3 = ACC, Size = UDim2.new(0, 0, 1, 0)}, track)
            corner(fill, 3)
            local knob = mk("Frame", {BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(14, 14),
                Position = UDim2.new(0, -7, 0.5, -7)}, track)
            corner(knob, 7)

            local function refresh()
                local v = spec.get()
                local a = math.clamp((v - spec.min) / (spec.max - spec.min), 0, 1)
                fill.Size = UDim2.new(a, 0, 1, 0)
                knob.Position = UDim2.new(a, -7, 0.5, -7)
                if not box:IsFocused() then box.Text = fmt(v) end
            end
            local function commit(v)
                spec.set(v)
                refresh()
                applyLive(spec.live)
            end
            local function fromX(x)
                local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
                local v = spec.min + a * (spec.max - spec.min)
                commit(math.floor(v / spec.step + 0.5) * spec.step)
            end
            hit.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    active = fromX
                    scroll.ScrollingEnabled = false
                    fromX(i.Position.X)
                end
            end)
            box.FocusLost:Connect(function()
                local n = tonumber(box.Text)
                if n then commit(n) else refresh() end
            end)
            refresh()
            table.insert(refreshers, refresh)
        end

        local signBtn
        local function refreshSign()
            if signBtn then
                local sg = CFG.sinalGiro[curTab] or 1
                signBtn.Text = "⇄ Inverter sentido do giro (atual: " .. (sg >= 0 and "normal" or "invertido") .. ")"
            end
        end

        local function showTab(rig)
            curTab = rig
            for r, b in pairs(tabs) do b.BackgroundColor3 = (r == rig) and ACC or BG2 end
            for _, c in ipairs(scroll:GetChildren()) do
                if c:IsA("GuiObject") then c:Destroy() end
            end
            refreshers = {}
            signBtn = mk("TextButton", {Text = "", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = TXT,
                BackgroundColor3 = BG2, Size = UDim2.new(1, -6, 0, 32)}, scroll)
            corner(signBtn, 8)
            signBtn.MouseButton1Click:Connect(function()
                CFG.sinalGiro[curTab] = -(CFG.sinalGiro[curTab] or 1)
                applyLive("giro")
                refreshSign()
            end)
            refreshSign()
            for _, spec in ipairs(SPECS[rig]) do makeRow(spec) end
        end
        for r, b in pairs(tabs) do b.MouseButton1Click:Connect(function() showTab(r) end) end

        local ov = mk("Frame", {Visible = false, BackgroundColor3 = BG, Position = UDim2.new(0, 0, 0, 40),
            Size = UDim2.new(1, 0, 1, -40), ZIndex = 20}, panel)
        mk("TextLabel", {BackgroundTransparency = 1, ZIndex = 21, Font = Enum.Font.GothamMedium, TextSize = 11,
            TextColor3 = SUB, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
            Text = "Copie o texto abaixo (segure o dedo / Ctrl+A, Ctrl+C) e me envie:",
            Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -20, 0, 30)}, ov)
        local expBox = mk("TextBox", {ZIndex = 21, MultiLine = true, TextEditable = true, ClearTextOnFocus = false,
            TextWrapped = false, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
            Font = Enum.Font.Code, TextSize = 11, TextColor3 = TXT, BackgroundColor3 = BG2, Text = "",
            Position = UDim2.new(0, 8, 0, 36), Size = UDim2.new(1, -16, 1, -88)}, ov)
        corner(expBox, 8)
        local bCopy = mk("TextButton", {ZIndex = 21, Text = "📋 Copiar", Font = Enum.Font.GothamBold, TextSize = 13,
            TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = ACC, Position = UDim2.new(0, 8, 1, -44),
            Size = UDim2.new(0.5, -12, 0, 36)}, ov)
        corner(bCopy, 8)
        local bBack = mk("TextButton", {ZIndex = 21, Text = "← Voltar", Font = Enum.Font.GothamBold, TextSize = 13,
            TextColor3 = TXT, BackgroundColor3 = BG2, Position = UDim2.new(0.5, 4, 1, -44),
            Size = UDim2.new(0.5, -12, 0, 36)}, ov)
        corner(bBack, 8)

        local function buildExport()
            local function n(v) return fmt(v) end
            local function pair(t) return "{R15 = " .. n(t.R15) .. ", R6 = " .. n(t.R6) .. "}" end
            local L = {
                "-- TZE Phone 3D | config exportada | rig detectado: " .. tostring(state.rig),
                "local CFG = {",
                "    ativo = " .. tostring(CFG.ativo) .. ",",
                "    escala = " .. n(CFG.escala) .. ",",
                "    balanco = " .. n(CFG.balanco) .. ",",
                "    -- R15",
                "    ombro = " .. n(CFG.ombro) .. ",",
                "    cotovelo = " .. n(CFG.cotovelo) .. ",",
                "    punho = " .. n(CFG.punho) .. ",",
                "    paraDentro = " .. n(CFG.paraDentro) .. ",",
                "    celularY = " .. n(CFG.celularY) .. ",",
                "    celularZ = " .. n(CFG.celularZ) .. ",",
                "    -- R6",
                "    ombroR6 = " .. n(CFG.ombroR6) .. ",",
                "    paraDentroR6 = " .. n(CFG.paraDentroR6) .. ",",
                "    r6Tilt = " .. n(CFG.r6Tilt) .. ",",
                "    r6Y = " .. n(CFG.r6Y) .. ",",
                "    r6X = " .. n(CFG.r6X) .. ",",
                "    r6Z = " .. n(CFG.r6Z) .. ",",
                "    -- por rig",
                "    giroCelular = " .. pair(CFG.giroCelular) .. ",",
                "    celularInclina = " .. pair(CFG.celularInclina) .. ",",
                "    celularRolagem = " .. pair(CFG.celularRolagem) .. ",",
                "    bracoEsq = " .. pair(CFG.bracoEsq) .. ",",
                "    sinalGiro = " .. pair(CFG.sinalGiro) .. ",",
                "}",
            }
            return table.concat(L, "\n")
        end

        bExport.MouseButton1Click:Connect(function()
            local txt = buildExport()
            expBox.Text = txt
            ov.Visible = true
            local ok = pcall(function() (setclipboard or toclipboard)(txt) end)
            bCopy.Text = ok and "✅ Copiado!" or "📋 Copiar"
            print("[TZE PHONE 3D] ---- CONFIG EXPORTADA ----\n" .. txt)
        end)
        bCopy.MouseButton1Click:Connect(function()
            local ok = pcall(function() (setclipboard or toclipboard)(expBox.Text) end)
            bCopy.Text = ok and "✅ Copiado!" or "Selecione o texto e copie"
        end)
        bBack.MouseButton1Click:Connect(function() ov.Visible = false; bCopy.Text = "📋 Copiar" end)

        bReset.MouseButton1Click:Connect(function()
            for k, v in pairs(DEFAULT) do CFG[k] = type(v) == "table" and deepCopy(v) or v end
            applyLive("pose"); applyLive("grip"); applyLive("giro"); applyLive("scale")
            showTab(curTab)
        end)

        local function toggle() panel.Visible = not panel.Visible; fit() end
        fab.MouseButton1Click:Connect(toggle)
        closeB.MouseButton1Click:Connect(function() panel.Visible = false end)
        _G.TZE_PhoneEditor = toggle

        local dragP
        title.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragP = {m = i.Position, p = panel.Position}
            end
        end)
        table.insert(conns, UserInputService.InputChanged:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
            if active then active(i.Position.X) end
            if dragP then
                local s = math.max(pscale.Scale, 0.01)
                local d = i.Position - dragP.m
                panel.Position = UDim2.new(dragP.p.X.Scale, dragP.p.X.Offset + d.X / s, dragP.p.Y.Scale, dragP.p.Y.Offset + d.Y / s)
            end
        end))
        table.insert(conns, UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                active, dragP = nil, nil
                scroll.ScrollingEnabled = true
            end
        end))

        showTab("R15")
        task.spawn(function()
            local synced = false
            while gui.Parent do
                rigLbl.Text = "Rig: " .. tostring(state.rig or "—")
                if state.rig and not synced then synced = true; showTab(state.rig) end
                if not state.rig then synced = false end
                task.wait(0.4)
            end
        end)
    end
    createEditor()

    pcall(function() RunService:UnbindFromRenderStep("TZE_Phone3D") end)
    RunService:BindToRenderStep("TZE_Phone3D", Enum.RenderPriority.Character.Value + 5, onStep)

    LP.CharacterAdded:Connect(function() SP.stopNow(); state.char = nil; state.alpha = 0; lastLTM = -1 end)
    print("[TZE PHONE] Celular 3D carregado (R15 + R6, motor de pose do Stand). Ajuste os valores em CFG se a posição na mão ficar torta.")
end

end, function(e) return debug.traceback(tostring(e), 2) end)

if not __ok then
    warn("[TZE PHONE] Erro ao iniciar: " .. tostring(__err))
end
