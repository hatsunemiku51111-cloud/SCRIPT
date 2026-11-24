--[[
    TZE PHONE V8 - versão reestruturada + navegação estilo celular + app de Música refeito
    * V8: ANIMAÇÃO DE BOOT (rework: power-on, anel de progresso, glitch + brilho, saudação digitada) na 1ª abertura -> Nav.boot.play() (teste: Nav.boot.done = false)
    * V8: app GPS (ViewportFrame visto de cima + players em tempo real) -> bloco GPS (+ grade, X/Y/Z e ping real do GPS_APP)
    * V8: CARCAÇA estilo iOS (sem orelhas) -> Nav.shell.create(frame) | cor em Config > Cor da carcaça
    * V8: BARRA DE STATUS (relógio, FPS, sinal, bateria) em TODOS os apps -> Nav.status.create(frame)
    * Cada app fica dentro de um bloco  do ... end  (evita o limite de 200 locals do Luau)
    * Tudo roda dentro de xpcall: se algo falhar, o erro aparece no console com "[TZE PHONE]"
    * TODOS os ícones são desenhados com formas de UI (tabela Icons) - nenhum emoji/símbolo de texto | Navegação: Voltar / Início / Recentes ou Gestos
    * Para ADICIONAR algo novo: coloque dentro de um bloco  do ... end  (veja o final do arquivo)
]]
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

-- =========================================================
-- CRIA PASTAS
-- =========================================================
local function criarPastasPhone()
    pcall(function()
        if not isfolder("PHONE") then makefolder("PHONE") end
        if not isfolder("PHONE/Music") then makefolder("PHONE/Music") end
        if not isfolder("PHONE/Photos") then makefolder("PHONE/Photos") end
    end)
end
criarPastasPhone()

-- =========================================================
-- SETTINGS PERSISTENTES
-- =========================================================
local HttpService = game:GetService("HttpService")
local SETTINGS_PATH = "PHONE/settings.json"

local defaultSettings = {
    fpsEnabled = true,
    statusBarMigrated = false,
    caseTheme = "titanio",
    gestureNav = false,
    flashlightEnabled = false,
    volume = 1,
    wallpaper = "rbxassetid://12506271392", -- padrão
    phonePosition = {X = 1, Y = 0.5, XOffset = -300, YOffset = -220},
    hotbarPosition = {X = 0.5, Y = 0, XOffset = -24, YOffset = 12} -- CENTRO SUPERIOR
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
if not phoneSettings.statusBarMigrated then -- V8: liga o FPS na barra uma vez
    phoneSettings.fpsEnabled = true
    phoneSettings.statusBarMigrated = true
    saveSettings()
end

-- =========================================================
-- SERVIÇOS E VARIÁVEIS
-- =========================================================
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

-- Onde colocar as GUIs: gethui() > CoreGui > PlayerGui (o que funcionar no seu executor)
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

local isTouchDevice = UserInputService.TouchEnabled
local Character, Humanoid
local isPhoneOpen = false
local isMusicOpen = false
local currentApp = "home"
local phoneFlashlight = nil
local currentVolume = phoneSettings.volume or 1
local currentWallpaper = phoneSettings.wallpaper or defaultSettings.wallpaper

-- =========================================================
-- VARIÁVEIS COMPARTILHADAS ENTRE OS BLOCOS (forward declarations)
-- Cada app roda dentro de um bloco do ... end, então os locals dele
-- somem no final do bloco e NÃO estouram o limite de 200 locals.
-- Só o que precisa ser visto por outros blocos é declarado aqui.
-- =========================================================
local HotbarFrame, hotbarUIScale, phoneSlot, selectedFrame
local PhoneHome, homeBg
local MusicAppIcon, StopwatchAppIcon, ConfigAppIcon, GalleryAppIcon
local WebBrowserIcon
local MainFrame, refreshFiles, stopMusic
local StopwatchFrame, resetStopwatch
local ConfigFrame, cfgGoBack, cfgReset
local GalleryFrame, refreshPhotos, exitPhotoViewer, closePhotoMenu
local isPhotoMenuOpen = false


-- =========================================================
-- BIBLIOTECA DE ÍCONES DESENHADOS (só formas de UI: sem emoji, sem imagem)
-- Draw  = primitivas (linha, círculo, anel, retângulo arredondado)
-- Icons = ícones prontos (back, home, recents, close, phone, music, stopwatch, gear, gallery,
--         play, pause, next, prev, shuffle, repeatAll, repeatOne, arrowRight, volUp, volDown,
--         search, folder, note, heart, reset, dotsV, info, wallpaper, tower, chevronRight, flag, gauge, torch, gesture)
-- Helpers: Icons.put (ícone dentro de botão) | Icons.text (ícone + texto) | Icons.empty (estado vazio) | Icons.searchField
-- Para criar um ícone novo: copie um modelo de Icons.xxx e desenhe numa grade 24x24.
-- =========================================================
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

-- d = diâmetro visual total. thickness = nil -> preenchido; com valor -> só o anel
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

-- triângulo preenchido (fatias verticais finas)
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

-- quadrilátero preenchido (2 triângulos): p1..p4 em ordem em volta
function Draw.quad(parent, p1, p2, p3, p4, color, z)
    Draw.poly3(parent, p1, p2, p3, color, z)
    Draw.poly3(parent, p1, p3, p4, color, z)
end

-- arco (ângulos em graus; 0 = direita, 90 = baixo, -90 = cima)
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

-- ponta de seta: (tx,ty) = ponta, (dx,dy) = direção para onde aponta
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

local function T(v, u) return math.max(1.2, v * u) end -- espessura mínima

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

-- ícone centralizado dentro de um botão/label (zera o Text do host)
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

-- ícone + texto dentro de um botão/label.
-- o = {icon, iconSize, color, text, textColor, font, textSize, gap, align = "center"|"left", pad}
-- retorna ui com ui.set(fn, texto, cor) e ui.setColor(corTexto, corIcone)
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

-- estado vazio: ícone no topo + texto embaixo (host = TextLabel com Text já definido)
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

-- lupa à esquerda de uma caixa de pesquisa
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

-- =========================================================
-- BARRA DE NAVEGAÇÃO (3 botões OU gestos)
--   Nav.back / Nav.home / Nav.recents são definidos no bloco de navegação
-- =========================================================
local Nav = {home = function() end, back = function() end, recents = function() end, gps = {}}
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

    -- modo gestos: pílula + área de toque
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
                -- deslizar pra cima e SEGURAR = recentes; só deslizar = início
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

-- =========================================================
-- BARRA DE STATUS  (relógio · FPS ........ sinal · bateria)
--   Nav.status.create(frame)  -> coloca a barra no topo de QUALQUER tela do celular
--   Nav.status.setFps(n)      -> atualiza o FPS em todas as barras
--   Nav.status.applyFps()     -> reaplica a visibilidade do FPS (switch em Config)
--   * Sinal  = ping real do servidor (4 barras)
--   * Bateria = SIMULADA (o Roblox não expõe a bateria do aparelho) - troque batteryLevel() se tiver fonte real
-- =========================================================
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
        return math.max(5, 100 - math.floor((os.clock() - SB.t0) / 90)) -- -1% a cada 90 s
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

        -- ESQUERDA: relógio + FPS
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

        -- DIREITA: sinal (4 barras)
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

        -- DIREITA: % + bateria
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

        -- atualização (relógio, sinal, bateria)
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
            if lastBat <= 15 then -- bateria fraca: pisca
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

        -- animação de entrada: sempre que a tela abre, a barra desce suave
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

-- =========================================================
-- CARCAÇA DO CELULAR (estilo iOS)
--   Nav.shell.create(frame)  -> vira o corpo do celular: vidro preto, moldura metálica com brilho,
--                               botões laterais, Dynamic Island com lente, reflexo de vidro e sombra
--   Nav.shell.setTheme(nome) -> titanio | grafite | prata | azul | verde  (salvo em settings.json)
--   Nav.shell.nextTheme()    -> troca para a próxima cor e devolve o nome (usado em Config)
--   Nav.shell.volumeUp/volumeDown -> botões laterais da carcaça (definidos no bloco VOLUME)
-- Tudo desenhado com formas de UI (sem imagens), então nenhuma "orelha"/asset externo.
-- =========================================================
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

        -- anel (só contorno) que cresce para fora da tela: base de sombra, vidro e moldura
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

        -- sombra suave (3 camadas, deslocada para baixo)
        ring("Shadow1", 11, 6, 39, 6, Color3.new(0, 0, 0), 0.90, 0)
        ring("Shadow2", 17, 7, 45, 8, Color3.new(0, 0, 0), 0.94, 0)
        ring("Shadow3", 25, 8, 53, 10, Color3.new(0, 0, 0), 0.97, 0)

        -- borda de vidro preto ao redor da tela
        ring("Bezel", 0, 0, 28, 6, rgb(6, 6, 8), 0, 1)

        -- moldura metálica com brilho diagonal
        local _, chassisStroke = ring("Chassis", 6, 0, 34, 4, WHITE, 0, 2)
        s.chassisGrad = Instance.new("UIGradient")
        s.chassisGrad.Rotation = 45
        s.chassisGrad.Parent = chassisStroke

        -- fio de luz na aresta externa
        ring("EdgeLight", 10, 0, 38, 1, WHITE, 0.72, 3)

        -- botões laterais: área de toque larga + peça metálica fina; segurar repete a ação
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

        -- Dynamic Island com lente da câmera e sensor
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

        -- reflexo de vidro (faixa de luz que cruza a tela quando o app abre)
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

        -- indicador de volume estilo iOS (pílula vertical na esquerda da tela)
        -- recorte do tamanho da tela: o indicador entra e sai por dentro da borda, nunca fica fora da carcaça
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

        -- animação ao abrir: a ilha "respira" e o reflexo atravessa a tela
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





-- =========================================================
-- HOTBAR SÓ DO PHONE (CENTRO SUPERIOR)
-- =========================================================
destroyOld("TzeCustomHotbar")


-- ###################### HOTBAR ######################
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


-- =========================================================
-- PHONE SYSTEM
-- =========================================================
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

-- ###################### HOME ######################
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
PhoneHome.Draggable = false -- FIXO
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
homeOverlay.BackgroundTransparency = 0.45
homeOverlay.BorderSizePixel = 0
homeOverlay.ZIndex = 2
homeOverlay.Parent = PhoneHome
Instance.new("UICorner", homeOverlay).CornerRadius = UDim.new(0, 28)

Nav.shell.create(PhoneHome)

Nav.status.create(PhoneHome)

local homeTitle = Instance.new("TextLabel")
homeTitle.Size = UDim2.new(1, 0, 0, 30)
homeTitle.Position = UDim2.new(0, 0, 0, 70)
homeTitle.BackgroundTransparency = 1
homeTitle.Text = "Apps"
homeTitle.TextColor3 = Color3.new(1, 1, 1)
homeTitle.Font = Enum.Font.GothamBold
homeTitle.TextSize = 22
homeTitle.ZIndex = 5
homeTitle.Parent = PhoneHome

local appsContainer = Instance.new("Frame")
appsContainer.Size = UDim2.new(1, -40, 0, 280)
appsContainer.Position = UDim2.new(0, 20, 0, 110)
appsContainer.BackgroundTransparency = 1
appsContainer.ZIndex = 5
appsContainer.Parent = PhoneHome

local function createAppIcon(name, drawIcon, color, pos)
    local icon = Instance.new("TextButton")
    icon.Size = UDim2.new(0, 70, 0, 90)
    icon.Position = pos
    icon.BackgroundTransparency = 1
    icon.Text = ""
    icon.ZIndex = 6
    icon.Parent = appsContainer

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 64, 0, 64)
    bg.Position = UDim2.new(0.5, -32, 0, 0)
    bg.BackgroundColor3 = color
    bg.BorderSizePixel = 0
    bg.ZIndex = 6
    bg.Parent = icon
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 16)

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.22), color:Lerp(Color3.new(0, 0, 0), 0.25))
    grad.Rotation = 90
    grad.Parent = bg
    local ic = drawIcon(bg, 38, Color3.new(1, 1, 1), 8)
    ic.Position = UDim2.new(0.5, -19, 0.5, -19)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.Position = UDim2.new(0, 0, 1, -22)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextSize = 11
    nameLabel.ZIndex = 7
    nameLabel.Parent = icon

    -- animação de toque (afunda e volta, igual celular)
    icon.MouseButton1Down:Connect(function()
        TweenService:Create(bg, TweenInfo.new(0.1), {Size = UDim2.new(0, 58, 0, 58), Position = UDim2.new(0.5, -29, 0, 3)}):Play()
    end)
    local function release()
        TweenService:Create(bg, TweenInfo.new(0.18, Enum.EasingStyle.Back), {Size = UDim2.new(0, 64, 0, 64), Position = UDim2.new(0.5, -32, 0, 0)}):Play()
    end
    icon.MouseButton1Up:Connect(release)
    icon.MouseLeave:Connect(release)

    return icon
end

MusicAppIcon = createAppIcon("Música", Icons.music, Color3.fromRGB(0, 180, 255), UDim2.new(0, 5, 0, 0))
StopwatchAppIcon = createAppIcon("Cronômetro", Icons.stopwatch, Color3.fromRGB(255, 140, 30), UDim2.new(0, 85, 0, 0))
ConfigAppIcon = createAppIcon("Config", Icons.gear, Color3.fromRGB(120, 120, 130), UDim2.new(0, 165, 0, 0))
GalleryAppIcon = createAppIcon("Galeria", Icons.gallery, Color3.fromRGB(180, 80, 220), UDim2.new(0, 5, 0, 100))
Nav.gps.icon = createAppIcon("GPS", Icons.gps, Color3.fromRGB(46, 190, 120), UDim2.new(0, 85, 0, 100))
WebBrowserIcon = createAppIcon("Navegador", Icons.search, Color3.fromRGB(35, 145, 205), UDim2.new(0, 5, 0, 200))

createNavBar(PhoneHome)

-- FPS (relógio, sinal e bateria são atualizados pela própria barra de status)

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


-- ###################### VOLUME ######################
-- Controlado pelos botões FÍSICOS da carcaça (lado esquerdo): segurar repete, passo de 10%.
-- Mostra o indicador de volume na tela e aplica na música tocando.
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


-- ###################### MÚSICA (rework V7) ######################
-- App de música refeito do zero:
--   * 3 abas: Biblioteca | Tocando | Sound ID (com indicador deslizante)
--   * Cor de destaque automática por faixa (muda suave a cada música)
--   * Aba "Tocando": disco girando + brilho que pulsa + visualizador de 32 barras,
--     barra de progresso com seek (clique/arraste), play/pause grande, anterior/próxima,
--     shuffle (com pilha de voltar) e repeat em 3 modos (off / todas / uma)
--   * Biblioteca: busca com botão limpar, filtro de favoritas, ordenação A-Z / Z-A,
--     equalizador animado na faixa atual, coração para favoritar (salvo no settings.json)
--   * Sound ID: histórico dos últimos IDs (salvo), nome do áudio buscado automaticamente
--   * Mini player nas abas Biblioteca/Sound ID para controlar sem sair da lista
--   * Suporta .mp3 e .ogg em PHONE/Music
-- API externa mantida: MainFrame, refreshFiles(), stopMusic(), currentSound
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

-- ---------- helpers ----------
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

-- ícone # (aba Sound ID), desenhado igual aos outros
function Icons.hash(parent, S, color, z)
    local c, u = iconRoot(parent, S)
    local th = T(2.2, u)
    Draw.line(c, 9 * u, 4.5 * u, 7.5 * u, 19.5 * u, th, color, z)
    Draw.line(c, 16.5 * u, 4.5 * u, 15 * u, 19.5 * u, th, color, z)
    Draw.line(c, 4.5 * u, 9 * u, 19.5 * u, 9 * u, th, color, z)
    Draw.line(c, 4 * u, 15 * u, 19 * u, 15 * u, th, color, z)
    return c
end

-- ---------- dados salvos ----------
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

-- ---------- estado ----------
shuffleMode = phoneSettings.musicShuffle == true
local repeatState = math.clamp(tonumber(phoneSettings.musicRepeat) or 0, 0, 2) -- 0 off | 1 todas | 2 uma
local sortAsc = phoneSettings.musicSortDesc ~= true
local onlyFavs = false
local activeTab = "library"
local status = "idle" -- idle | loading | playing | paused | failed
local currentItem = nil
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

-- ---------- cor de destaque (suave) ----------
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

-- ---------- favoritos ----------
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

-- =========================================================
-- INTERFACE
-- =========================================================
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


-- brilho colorido no topo (segue a cor da faixa)
UI.tint = mk("Frame", {Size = UDim2.new(1, 0, 0, 250), BackgroundColor3 = GREEN, BorderSizePixel = 0, ZIndex = 1}, MainFrame)
corner(UI.tint, UDim.new(0, 28))
mk("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1)}), Rotation = 90}, UI.tint)
trackAccent(UI.tint, "BackgroundColor3")

Nav.shell.create(MainFrame)
Nav.status.create(MainFrame)

-- ---------- cabeçalho ----------
local TopBar = mk("Frame", {Size = UDim2.new(1, 0, 0, 38), Position = UDim2.new(0, 0, 0, 40), BackgroundTransparency = 1}, MainFrame)
local logo = mk("Frame", {Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(0, 14, 0.5, -14), BorderSizePixel = 0}, TopBar)
corner(logo, UDim.new(0, 9))
trackAccent(logo, "BackgroundColor3")
Icons.put(logo, Icons.music, 18, WHITE, 3)
mk("TextLabel", {Size = UDim2.new(0, 110, 0, 28), Position = UDim2.new(0, 50, 0.5, -14), BackgroundTransparency = 1, Text = "Música", TextColor3 = WHITE, Font = FONTB, TextSize = 19, TextXAlignment = LEFT}, TopBar)
UI.count = mk("TextLabel", {Size = UDim2.new(0, 84, 0, 22), Position = UDim2.new(1, -98, 0.5, -11), BackgroundColor3 = CARD, BorderSizePixel = 0, Text = "0 faixas", TextColor3 = SUBC, Font = FONTM, TextSize = 11}, TopBar)
corner(UI.count, UDim.new(1, 0))

-- ---------- abas ----------
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

-- ---------- telas (views) ----------
local function mkView()
    return mk("Frame", {Size = UDim2.new(1, 0, 0, 282), Position = UDim2.new(0, 0, 0, 120), BackgroundTransparency = 1, Visible = false}, MainFrame)
end
UI.views = {library = mkView(), player = mkView(), id = mkView()}

-- =========================================================
-- ABA: BIBLIOTECA
-- =========================================================
do
    local V = UI.views.library
    local wrap = mk("Frame", {Size = UDim2.new(1, -56, 0, 30), Position = UDim2.new(0, 12, 0, 0), BackgroundColor3 = CARD, BorderSizePixel = 0}, V)
    corner(wrap, UDim.new(0, 10))
    Icons.searchField(wrap, 15, 10)
    UI.search = mk("TextBox", {Size = UDim2.new(1, -62, 1, 0), Position = UDim2.new(0, 32, 0, 0), BackgroundTransparency = 1, PlaceholderText = "Pesquisar música...", PlaceholderColor3 = MUTED, Text = "", TextColor3 = WHITE, Font = FONT, TextSize = 13, TextXAlignment = LEFT, ClearTextOnFocus = false}, wrap)
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

-- =========================================================
-- ABA: TOCANDO
-- =========================================================
do
    local V = UI.views.player

    -- brilho (pulsa com o volume da música)
    local glow = mk("Frame", {Size = UDim2.new(0, 106, 0, 106), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 52), BackgroundTransparency = 1}, V)
    corner(glow, UDim.new(1, 0))
    UI.glow = mk("UIStroke", {Thickness = 2, Transparency = 0.7}, glow)
    trackAccent(UI.glow, "Color")

    -- disco
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

    -- título / subtítulo / coração
    UI.ptitle = mk("TextLabel", {Size = UDim2.new(1, -84, 0, 22), Position = UDim2.new(0, 42, 0, 104), BackgroundTransparency = 1, Text = "Nenhuma música", TextColor3 = WHITE, Font = FONTB, TextSize = 16, TextTruncate = Enum.TextTruncate.AtEnd}, V)
    UI.psub = mk("TextLabel", {Size = UDim2.new(1, -40, 0, 16), Position = UDim2.new(0, 20, 0, 126), BackgroundTransparency = 1, Text = "", TextColor3 = SUBC, Font = FONT, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd}, V)
    UI.pheart = mkBtn(V, UDim2.new(0, 28, 0, 28), UDim2.new(1, -40, 0, 101), 3)

    -- visualizador (32 barras)
    local viz = mk("Frame", {Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 12, 0, 148), BackgroundTransparency = 1}, V)
    UI.bars, UI.barVals = {}, {}
    for i = 1, 32 do
        local b = mk("Frame", {Size = UDim2.new(0, 5, 0, 3), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 1 + (i - 1) * 8, 0.5, 0), BorderSizePixel = 0}, viz)
        corner(b, UDim.new(1, 0))
        trackAccent(b, "BackgroundColor3")
        UI.bars[i] = b
        UI.barVals[i] = 3
    end

    -- barra de progresso (seek)
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

    -- controles
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

-- =========================================================
-- MINI PLAYER (aparece nas abas Biblioteca / Sound ID)
-- =========================================================
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

-- =========================================================
-- ABA: SOUND ID
-- =========================================================
do
    local V = UI.views.id
    mk("TextLabel", {Size = UDim2.new(1, -24, 0, 14), Position = UDim2.new(0, 14, 0, 0), BackgroundTransparency = 1, Text = "SOUND ID DO ROBLOX", TextColor3 = SUBC, Font = FONTB, TextSize = 10, TextXAlignment = LEFT}, V)
    UI.idInput = mk("TextBox", {Size = UDim2.new(1, -98, 0, 34), Position = UDim2.new(0, 12, 0, 18), BackgroundColor3 = CARD, BorderSizePixel = 0, PlaceholderText = "Ex: 1837879082", PlaceholderColor3 = MUTED, Text = "", TextColor3 = WHITE, Font = FONT, TextSize = 13, TextXAlignment = LEFT, ClearTextOnFocus = false}, V)
    corner(UI.idInput, UDim.new(0, 10))
    mk("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 6)}, UI.idInput)
    UI.idPlay = mk("TextButton", {Size = UDim2.new(0, 70, 0, 34), Position = UDim2.new(1, -82, 0, 18), BorderSizePixel = 0, Text = "Tocar", TextColor3 = DARK, Font = FONTB, TextSize = 13, AutoButtonColor = false}, V)
    corner(UI.idPlay, UDim.new(0, 10))
    trackAccent(UI.idPlay, "BackgroundColor3")

    mk("TextLabel", {Size = UDim2.new(0.5, -14, 0, 14), Position = UDim2.new(0, 14, 0, 62), BackgroundTransparency = 1, Text = "RECENTES", TextColor3 = SUBC, Font = FONTB, TextSize = 10, TextXAlignment = LEFT}, V)
    UI.clearHist = mk("TextButton", {Size = UDim2.new(0, 60, 0, 14), Position = UDim2.new(1, -72, 0, 62), BackgroundTransparency = 1, Text = "Limpar", Font = FONTB, TextSize = 11, TextXAlignment = RIGHT, AutoButtonColor = false}, V)
    trackAccent(UI.clearHist, "TextColor3")

    UI.idList = mk("ScrollingFrame", {Size = UDim2.new(1, -24, 0, 136), Position = UDim2.new(0, 12, 0, 82), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y}, V)
    trackAccent(UI.idList, "ScrollBarImageColor3")
    mk("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, UI.idList)
end

createNavBar(MainFrame)

-- =========================================================
-- LÓGICA: textos / ícones de estado
-- =========================================================
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

-- =========================================================
-- LÓGICA: lista da biblioteca
-- =========================================================
updateList = function()
    for _, v in ipairs(UI.list:GetChildren()) do
        if v:IsA("GuiObject") then v:Destroy() end
    end
    rowEq = nil

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

    for idx, m in ipairs(filteredList) do
        local isCur = currentItem ~= nil and currentItem.kind == "file" and currentItem.path == m.path
        local row = mk("Frame", {Size = UDim2.new(1, -6, 0, 40), BackgroundColor3 = isCur and CARD2 or CARD, BorderSizePixel = 0, LayoutOrder = idx}, UI.list)
        corner(row, UDim.new(0, 12))
        local slot = mk("Frame", {Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(0, 8, 0.5, -14), BackgroundColor3 = isCur and accentTar or CARD2, BorderSizePixel = 0}, row)
        corner(slot, UDim.new(0, 9))
        if isCur then
            rowEq = {}
            for b = 1, 3 do
                local bar = mk("Frame", {Size = UDim2.new(0, 3, 0, 8), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, 8 + (b - 1) * 6, 1, -7), BackgroundColor3 = DARK, BorderSizePixel = 0}, slot)
                corner(bar, UDim.new(1, 0))
                rowEq[b] = bar
            end
        else
            mk("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = tostring(idx), TextColor3 = SUBC, Font = FONTC, TextSize = 11}, slot)
        end
        mk("TextLabel", {Size = UDim2.new(1, -86, 1, 0), Position = UDim2.new(0, 44, 0, 0), BackgroundTransparency = 1, Text = m.name, TextColor3 = isCur and accentTar or WHITE, Font = isCur and FONTB or FONTM, TextSize = 13, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd}, row)
        local hit = mkBtn(row, UDim2.new(1, -40, 1, 0), UDim2.new(0, 0, 0, 0), 3)
        local heart = mkBtn(row, UDim2.new(0, 30, 0, 30), UDim2.new(1, -36, 0.5, -15), 4)
        Icons.put(heart, Icons.heart, 15, isFav(m.name) and PINK or MUTED, 5)

        hit.MouseButton1Click:Connect(function()
            playItem(m, filteredList, idx)
        end)
        heart.MouseButton1Click:Connect(function()
            toggleFav(m.name)
            if onlyFavs then
                updateList()
            else
                Icons.put(heart, Icons.heart, 15, isFav(m.name) and PINK or MUTED, 5)
            end
            updateTrackUI()
        end)
    end
end

-- =========================================================
-- LÓGICA: histórico de Sound IDs
-- =========================================================
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

-- =========================================================
-- LÓGICA: reprodução
-- =========================================================
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

playItem = function(item, q, idx)
    stopSound()
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
    snd.Volume = currentVolume
    snd.Looped = (repeatState == 2)
    snd.Parent = MainFrame
    currentSound = snd
    status = "loading"
    snd:Play()
    updateTrackUI(); updateMini(); updateList(); updateHistory()

    snd.Ended:Connect(function()
        if token == playToken then onEnded() end
    end)

    -- espera carregar (até 10s); se não carregar, mostra falha
    task.spawn(function()
        local t0 = os.clock()
        while token == playToken and snd.TimeLength <= 0 and os.clock() - t0 < 10 do
            task.wait(0.1)
        end
        if token ~= playToken then return end
        if snd.TimeLength > 0 then
            if status == "loading" then
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
        -- fim da fila: fica parado no início, pronto para tocar de novo
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

-- usado pelo "fechar app" nos Recentes
function stopMusic()
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

-- toca um Sound ID (valida, guarda no histórico, busca o nome do áudio)
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

-- =========================================================
-- EVENTOS
-- =========================================================
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

-- Sound ID
UI.idInput:GetPropertyChangedSignal("Text"):Connect(function()
    local clean = UI.idInput.Text:gsub("%D", "")
    if clean ~= UI.idInput.Text then UI.idInput.Text = clean end
end)
UI.idInput.FocusLost:Connect(function(enter)
    if enter and UI.idInput.Text ~= "" then UI.playId(UI.idInput.Text) end
end)
UI.idPlay.MouseButton1Click:Connect(function() UI.playId(UI.idInput.Text) end)
UI.clearHist.MouseButton1Click:Connect(function()
    phoneSettings.musicIds = {}
    saveSettings()
    updateHistory()
end)

-- seek (clique e arraste na barra)
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

-- =========================================================
-- ANIMAÇÃO (um único loop; só trabalha com a tela de música visível)
-- =========================================================
local clock = 0
RunService.RenderStepped:Connect(function(dt)
    -- transição suave da cor de destaque
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
    local pos = snd and snd.TimePosition or 0
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

-- ---------- início ----------
refreshToggles()
updateTrackUI()
updateHistory()
updateList()
setTab("library", true)
end


-- ###################### CRONÔMETRO ######################
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

-- ================= CRONÔMETRO (rework) =================
-- mostrador circular com 60 marcas (acendem a cada segundo) + ponto orbitando o anel,
-- botões redondos Volta/Reset e Iniciar/Pausar, lista de voltas (melhor = verde, pior = vermelho)
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

-- ---------- mostrador ----------
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

-- ---------- botões redondos ----------
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

-- ---------- lista de voltas ----------
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

-- ---------- estado ----------
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

-- texto grande (MM:SS, H:MM:SS ou Dd HH:MM:SS) e o tamanho da fonte
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

-- ---------- voltas ----------
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

-- ---------- ações ----------
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


-- ###################### CONFIG ######################
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

-- ================= CONFIG (rework: estilo "Ajustes" de celular) =================
-- página principal com perfil + grupos (Geral / Personalização / Sistema),
-- subpáginas Wallpaper e Servidor (botão Voltar do app e da barra de navegação)
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

-- ---------- cabeçalho das subpáginas ----------
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

-- ---------- páginas ----------
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

-- ---------- grupos e linhas ----------
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

-- o = {icon, tile, title, sub, kind = "switch"|"chevron"|"value", state, onToggle, onClick, value}
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

-- ---------- navegação entre páginas ----------
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

-- =================== PÁGINA PRINCIPAL ===================
-- cartão de perfil
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

-- GERAL
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

-- PERSONALIZAÇÃO
sectionLabel(mainPage, "PERSONALIZAÇÃO", 4)
local gPers = newGroup(mainPage, 5)
addRow(gPers, {icon = Icons.gallery, tile = Color3.fromRGB(180, 80, 220), title = "Wallpaper", kind = "chevron",
    onClick = function() showPage("wallpaper", true) end})
local caseRow
caseRow = addRow(gPers, {icon = Icons.phone, tile = Color3.fromRGB(235, 140, 60), title = "Cor da carcaça", kind = "value",
    value = Nav.shell.label(), onClick = function()
        caseRow.value.Text = Nav.shell.nextTheme()
    end})

-- SISTEMA
sectionLabel(mainPage, "SISTEMA", 6)
local gSys = newGroup(mainPage, 7)
addRow(gSys, {icon = Icons.tower, tile = Color3.fromRGB(0, 170, 210), title = "Info do Servidor", kind = "chevron",
    onClick = function() showPage("server", true) end})

-- =================== PÁGINA WALLPAPER ===================
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
    homeBg.Image = id
    wpPreview.Image = id
    saveSettings()
end
wpApplyBtn.MouseButton1Click:Connect(function() applyWallpaper(wpInput.Text) end)
wpResetBtn.MouseButton1Click:Connect(function()
    applyWallpaper(defaultSettings.wallpaper)
    wpInput.Text = ""
end)

-- =================== PÁGINA SERVIDOR ===================
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

-- OBS: NÃO usa game.PrivateServerId (no cliente isso enche o console de avisos)
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


-- ###################### GALERIA (rework V3) ######################
do
-- Galeria V2: grade 3 colunas, favoritos, zoom (pinça / toque duplo / roda), arrastar, deslizar pra trocar, slideshow
local ACC = Color3.fromRGB(180, 80, 220)
local DARK = Color3.fromRGB(22, 22, 28)
local STAGE_W, STAGE_H = 264, 268

phoneSettings.favorites = type(phoneSettings.favorites) == "table" and phoneSettings.favorites or {}
local favs = phoneSettings.favorites

local tabMode = "all"        -- "all" | "favs"
local gridToken = 0
local zoom, panX, panY = 1, 0, 0
local assetCache = {}
local lastTap = 0

local function uiScale() return (phoneUIScale and phoneUIScale.Scale) or 1 end

local function getAsset(path)
    if assetCache[path] then return assetCache[path] end
    local ok, a = pcall(getcustomasset, path)
    if ok and a and a ~= "" then assetCache[path] = a return a end
    return nil
end

-- ---------- janela ----------
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

-- ---------- cabeçalho ----------
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
PhotoSearchBox.Parent = GalleryFrame
corner(PhotoSearchBox, UDim.new(1, 0))
Icons.searchField(PhotoSearchBox, 14, 12)

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

-- ---------- visualizador ----------
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

local PhotoDisplay = Instance.new("ImageLabel")
PhotoDisplay.Name = "PhotoDisplay"
PhotoDisplay.AnchorPoint = Vector2.new(0.5, 0.5)
PhotoDisplay.Position = UDim2.new(0.5, 0, 0.5, 0)
PhotoDisplay.Size = UDim2.new(0, STAGE_W, 0, STAGE_H)
PhotoDisplay.BackgroundTransparency = 1
PhotoDisplay.ScaleType = Enum.ScaleType.Fit
PhotoDisplay.Parent = stage

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

-- ---------- menu ⋮ (cartão moderno com fundo escurecido) ----------
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

-- confirmação de exclusão (aparece no lugar do botão)
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

-- ---------- zoom / pan ----------
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

-- ---------- favoritos ----------
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
    isInPhotoViewer = false
    closePhotoMenu()
    PhotoViewerView.Visible = false
    PhotoScrollList.Visible = true
    PhotoDisplay.Image = ""
    currentPhotoIndex = 0
    resetZoom()
end

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
    pcall(delfile, photo.path)
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
    local a = getAsset(photo.path)
    if a then
        currentWallpaper = a
        phoneSettings.wallpaper = a
        homeBg.Image = a
        saveSettings()
        closePhotoMenu()
    end
end)

-- ---------- gestos no visualizador ----------
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

-- ---------- grade ----------
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
        cell.MouseButton1Click:Connect(function() openPhotoByIndex(idx) end)
        cells[idx] = cell
    end
    task.wait()
    PhotoScrollList.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 8)

    -- miniaturas carregam aos poucos (sem travar com muitas fotos)
    task.spawn(function()
        for idx, cell in ipairs(cells) do
            if token ~= gridToken then return end
            local a = getAsset(filteredPhotoList[idx].path)
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
                    if (ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "webp" or ext == "bmp" or ext == "gif") and not seen[norm:lower()] then
                        seen[norm:lower()] = true
                        local fileName = norm:match("([^/]+)$") or norm
                        local name = fileName:gsub("%.%w+$", "")
                        table.insert(photoList, {name = name, file = fileName, path = file})
                    end
                end
            end
        end
    end
    table.sort(photoList, function(a, b) return a.name:lower() < b.name:lower() end)
    updatePhotoList()
end

tabAll.MouseButton1Click:Connect(function() setTab("all") updatePhotoList() end)
tabFav.MouseButton1Click:Connect(function() setTab("favs") updatePhotoList() end)
PhotoSearchBox:GetPropertyChangedSignal("Text"):Connect(updatePhotoList)

createNavBar(GalleryFrame)
end


-- ###################### GPS ######################
-- Mapa visto de CIMA dentro de um ViewportFrame + todos os players do jogo em tempo real.
--   * Mapa: cópia leve das peças do Workspace (até 5000, as maiores primeiro) + terreno amostrado por raycast
--           (o ViewportFrame não renderiza Terrain, então ele vira uma grade de blocos coloridos)
--   * Câmera quase ortográfica (FOV 16) olhando reto para baixo, centrada em você / no player seguido / no arrasto
--   * Marcadores com foto do avatar, nome, seta de direção (você) e setas na borda para quem está fora da tela
--   * Lista de players com distância; tocar seleciona, segue e desenha a linha de rota com distância e tempo
--   * Controles: zoom +/-, recentralizar, bússola (Norte fixo <-> direção do personagem), modo dia/noite, recarregar mapa
-- Tudo está dentro de uma função para não gastar locals do limite de 200 do arquivo.
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
    local selectPlayer -- declarada antes; definida mais abaixo

    -- ---------- helpers ----------
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

    -- ---------- janela ----------
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

    -- ---------- cabeçalho ----------
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

    -- ---------- mapa (ViewportFrame) ----------
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

    -- linha de rota até o player selecionado
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

    -- ---------- controles sobre o mapa ----------
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

    -- chip de modo (Você / Seguindo / Livre)
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

    -- escala + coordenadas
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

    -- grade de referência (do GPS_APP): 3 linhas verticais + 3 horizontais, por baixo dos marcadores
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

    -- chip de ping real (Stats > Data Ping), canto superior esquerdo do mapa
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

    -- aviso de mapa vazio
    local emptyNote = txt(holder, "Sem estruturas para mostrar", 11, Enum.Font.GothamMedium, SUB, UDim2.new(0, 0, 0.5, 30), UDim2.new(1, 0, 0, 18), Enum.TextXAlignment.Center, 4)
    emptyNote.Visible = false

    -- ---------- tela de carregamento do mapa ----------
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

    -- ---------- lista de players ----------
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

    -- ---------- estilo dia / noite ----------
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

    -- ---------- jogadores: marcadores + linhas da lista ----------
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

    -- ---------- construção do mapa ----------
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
            if ex1 - ex0 <= 4 or ez1 - ez0 <= 4 then return end -- sem terreno
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

        -- 1) coleta as peças candidatas
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

        -- 2) terreno (grade de blocos por raycast)
        setProgress(0.3, "Lendo o terreno...")
        buildTerrain(my)
        if S.token ~= my then return end

        -- 3) clona as peças (sem filhos pesados)
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

    -- ---------- atualização por frame ----------
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

        -- alvo da câmera
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

        -- câmera olhando reto para baixo (quase ortográfica)
        local alt = (S.span / 2) / TAN_HALF
        local eye = Vector3.new(S.center.X, S.center.Y + alt, S.center.Z)
        local up = S.up
        local right = Vector3.new(0, -1, 0):Cross(up)
        S.right = right
        cam.CFrame = CFrame.lookAt(eye, eye + Vector3.new(0, -1, 0), up)

        -- marcadores
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

                -- seta: direção do personagem (você) ou direção do player fora da tela
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

        -- linha de rota até o selecionado
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

        -- bússola, escala e coordenadas
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

    -- ---------- interação ----------
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

    -- arrastar para mover o mapa (vira "Mapa livre")
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

    -- só gasta processamento enquanto a tela do GPS está visível
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

    -- ---------- API usada pela navegação ----------
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
    function GPS.goBack() -- botão Voltar: sai de "seguindo/livre" antes de fechar o app
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


-- ###################### NAVEGAÇÃO / RECENTES / ABRIR-FECHAR / ARRASTAR ######################
do
-- =========================================================
-- SISTEMA DE NAVEGAÇÃO (estilo celular de verdade)
--   Voltar   : fecha menu da foto -> fecha foto -> volta pro início
--   Início   : vai pra tela inicial (apps continuam abertos em segundo plano)
--   Recentes : seletor de apps (toque abre | X ou deslizar pra cima fecha)
-- =========================================================
local screens = {}
local openApps = {}          -- ids, mais recente primeiro
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

-- ---------- TELA DE RECENTES ----------
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

-- ---------- NAVEGADOR (estilo Chrome) ----------
-- Abas, barra de endereço com pílula, menu ⋮, seletor de abas, favoritos, histórico,
-- página Nova Guia com atalhos, barra de progresso e página de erro.
-- Tocar em qualquer link (resultado, link da página, favorito) abre direto no Web Direto da aba atual.
-- Limitação: Roblox não possui WebView; o conteúdo é exibido como texto formatado (sem JS/CSS).
local function makeBrowserScreen()
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

    -- ---------- utilitários de texto / rede ----------
    local U = {}
    function U.httpGet(url)
        local req = request or http_request or (syn and syn.request)
        if type(req) == "function" then
            local response = req({Url = url, Method = "GET", Headers = { ["User-Agent"] = "Mozilla/5.0" }})
            if type(response) == "table" and response.Body then return response.Body end
            error("Resposta HTTP vazia")
        end
        if game.HttpGet then return game:HttpGet(url) end
        error("Seu ambiente não disponibiliza uma função HTTP GET")
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
    function U.rich(html)
        html = html:gsub("<!%-%-.-%-%->", " "):gsub("<head.-</head>", " "):gsub("<script.-</script>", " "):gsub("<style.-</style>", " "):gsub("<noscript.-</noscript>", " "):gsub("<svg.-</svg>", " ")
        html = html:gsub("<[hH][1-6][^>]*>", "\n\1"):gsub("</[hH][1-6]%s*>", "\2\n")
        html = html:gsub("<[lL][iI][^>]*>", "\n• "):gsub("<[bB][rR]%s*/?>", "\n"):gsub("</[pP]%s*>", "\n\n"):gsub("</[dD][iI][vV]%s*>", "\n"):gsub("</[tT][rR]%s*>", "\n")
        html = html:gsub("<[^>]->", " ")
        html = U.decode(html)
        html = html:gsub("[ \t\r]+", " "):gsub("\n +", "\n"):gsub("\n\n\n+", "\n\n"):gsub("^%s+", "")
        if #html > 8000 then
            html = html:sub(1, (utf8.offset(html, 8001) or 8001) - 1) .. "…"
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

    -- ---------- estado ----------
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

    -- ---------- ícones próprios ----------
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

    -- ---------- moldura e barra superior ----------
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

    -- ---------- área de conteúdo ----------
    local area = new("Frame", {Position = UDim2.new(0, 0, 0, 84), Size = UDim2.new(1, 0, 1, -122), BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 3}, frame)
    local ntpView = new("ScrollingFrame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 300), ZIndex = 4}, area)
    local pageView = new("ScrollingFrame", {Name = "WebContent", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 4}, area)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)}, pageView)
    new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, pageView)

    local toastLbl = new("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -46), Size = UDim2.new(0, 0, 0, 26), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Color3.fromRGB(60, 64, 67), Text = "", TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 11, Visible = false, ZIndex = 40,
    }, frame)
    corner(toastLbl, UDim.new(0, 13))
    new("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)}, toastLbl)
    local toastId = 0
    toast = function(msg)
        toastId = toastId + 1
        local id = toastId
        toastLbl.Text = msg
        toastLbl.Visible = true
        task.delay(1.6, function() if id == toastId then toastLbl.Visible = false end end)
    end

    -- ---------- barra: estado visual ----------
    local heartBtn -- definido no menu
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

    -- ---------- carregamento ----------
    local function fetchEntry(entry)
        if entry.q then
            local html = U.httpGet("https://html.duckduckgo.com/html/?q=" .. HttpService:UrlEncode(entry.q))
            local raw, snips, items, seen = {}, {}, {}, {}
            for href, label in html:gmatch('class="result__a" href="(.-)"[^>]*>(.-)</a>') do
                table.insert(raw, {href, label})
            end
            for s in html:gmatch('class="result__snippet"[^>]*>(.-)</a>') do table.insert(snips, U.plain(s)) end
            local paired = (#snips == #raw)
            for i, r in ipairs(raw) do
                local link = r[1]:gsub("&amp;", "&")
                local real = link:match("uddg=([^&]+)")
                if real then link = U.urlDecode(real) elseif link:sub(1, 2) == "//" then link = "https:" .. link end
                local name = U.plain(r[2])
                if name ~= "" and link:match("^https?://") and not link:find("duckduckgo.com/y.js", 1, true) and not seen[link] then
                    seen[link] = true
                    table.insert(items, {name = name:sub(1, 90), url = link, snippet = paired and snips[i]:sub(1, 130) or nil})
                    if #items >= 10 then break end
                end
            end
            return {kind = "search", title = entry.q, items = items, preview = "Pesquisa: " .. entry.q}
        end
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
        local rich = U.rich(html)
        return {kind = "page", title = title:sub(1, 80), rich = rich, items = items, preview = (rich:gsub("<[^>]->", "")):sub(1, 110)}
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

    -- ---------- Nova Guia ----------
    local function buildNtp()
        for _, c in ipairs(ntpView:GetChildren()) do if c.Name == "Dyn" then c:Destroy() end end
        new("TextLabel", {
            Name = "Dyn", Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1, RichText = true,
            Text = '<font color="#4285F4">T</font><font color="#EA4335">Z</font><font color="#FBBC05">E</font>',
            Font = Enum.Font.GothamBold, TextSize = 46, TextColor3 = C.text, ZIndex = 5,
        }, ntpView)
        local box = new("TextButton", {Name = "Dyn", Position = UDim2.new(0, 14, 0, 92), Size = UDim2.new(1, -28, 0, 40), BackgroundColor3 = C.pill, Text = "", AutoButtonColor = true, ZIndex = 5}, ntpView)
        corner(box, UDim.new(0, 20))
        local ic = new("Frame", {Position = UDim2.new(0, 12, 0.5, -9), Size = UDim2.new(0, 18, 0, 18), BackgroundTransparency = 1, ZIndex = 6}, box)
        Icons.put(ic, Icons.search, 16, C.sub, 7)
        new("TextLabel", {Position = UDim2.new(0, 38, 0, 0), Size = UDim2.new(1, -46, 1, 0), BackgroundTransparency = 1, Text = "Pesquisar ou digitar URL", TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6}, box)
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

    -- ---------- página / resultados ----------
    local function buildPage(entry)
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
                RichText = true, Text = rich, TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 11, TextWrapped = true,
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

        if entry.state == "loading" then
            label("Carregando…\n" .. (entry.url or entry.q or ""), 12, C.sub, Enum.Font.Gotham, 90)
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
        if view.kind == "search" then
            label("Resultados para <b>" .. U.esc(entry.q) .. "</b>", 12, C.text, Enum.Font.Gotham)
            if #view.items == 0 then
                label("Não encontrei resultados. Tente outra pesquisa ou digite um endereço.", 11, C.sub, Enum.Font.Gotham)
            end
            for _, it in ipairs(view.items) do
                local rich = '<font color="#8ab4f8"><b>' .. U.esc(it.name) .. '</b></font>\n<font color="#81c995" size="10">' .. U.esc(U.hostOf(it.url)) .. "</font>"
                if it.snippet and it.snippet ~= "" then rich = rich .. '\n<font color="#9aa0a6" size="10">' .. U.esc(it.snippet) .. "</font>" end
                card(rich, function() navigate(tabs[cur], {url = it.url}) end)
            end
        else
            local head = add(new("Frame", {Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 5}))
            corner(head, UDim.new(0, 10))
            local fav = favicon(head, entry.url, 26, 6)
            fav.Position = UDim2.new(0, 9, 0.5, -13)
            new("TextLabel", {Position = UDim2.new(0, 44, 0, 5), Size = UDim2.new(1, -52, 0, 18), BackgroundTransparency = 1, Text = view.title, TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6}, head)
            new("TextLabel", {Position = UDim2.new(0, 44, 0, 23), Size = UDim2.new(1, -52, 0, 16), BackgroundTransparency = 1, Text = U.hostOf(entry.url), TextColor3 = C.sub, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6}, head)
            label(view.rich, 12, C.text, Enum.Font.Gotham)
            if #view.items > 0 then
                label("<b>LINKS DESTA PÁGINA (" .. #view.items .. ")</b>", 10, C.blue, Enum.Font.Gotham)
                for _, it in ipairs(view.items) do
                    card("<b>" .. U.esc(it.name) .. '</b>\n<font color="#9aa0a6" size="10">' .. U.esc(U.hostOf(it.url)) .. "</font>", function() navigate(tabs[cur], {url = it.url}) end)
                end
            end
        end
    end

    render = function()
        local e = curEntry()
        updateChrome()
        if e.ntp then
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

    -- ---------- seletor de abas ----------
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
            local body = (e.view and e.view.preview) or (e.ntp and "TZE\nPesquisar ou digitar URL" or (e.url or e.q or ""))
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

    -- ---------- favoritos / histórico (painel) ----------
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
        phoneSettings.browserHistory = {}
        saveSettings()
        fillPanel()
        toast("Histórico limpo")
    end)

    -- ---------- menu ⋮ ----------
    local menuLayer = new("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, BorderSizePixel = 0, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 28}, frame)
    corner(menuLayer, UDim.new(0, 28))
    local menu = new("Frame", {Position = UDim2.new(0, 72, 0, 78), Size = UDim2.new(0, 200, 0, 216), BackgroundColor3 = C.toolbar, BorderSizePixel = 0, ZIndex = 30}, menuLayer)
    corner(menu, UDim.new(0, 14))
    new("UIStroke", {Color = Color3.fromRGB(70, 72, 76), Thickness = 1}, menu)

    local backBtn = iconButton(menu, Icons.back, 18, C.text, UDim2.new(0, 0, 0, 2), UDim2.new(0, 50, 0, 38), 31)
    local fwdBtn = iconButton(menu, Icons.arrowRight, 18, C.text, UDim2.new(0, 50, 0, 2), UDim2.new(0, 50, 0, 38), 31)
    heartBtn = iconButton(menu, Icons.heart, 18, C.text, UDim2.new(0, 100, 0, 2), UDim2.new(0, 50, 0, 38), 31)
    local reBtn = iconButton(menu, Icons.reset, 18, C.text, UDim2.new(0, 150, 0, 2), UDim2.new(0, 50, 0, 38), 31)
    new("Frame", {Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(70, 72, 76), BorderSizePixel = 0, ZIndex = 31}, menu)

    local function setMenu(open)
        menuLayer.Visible = open
        if open then
            address:ReleaseFocus()
            local t = tabs[cur]
            local e = curEntry()
            Icons.put(fwdBtn, Icons.arrowRight, 18, t.pos < #t.hist and C.text or Color3.fromRGB(95, 99, 104), 32)
            Icons.put(heartBtn, Icons.heart, 18, isBookmarked(e.url) and C.red or C.text, 32)
        end
    end
    local function menuItem(text, y, fn)
        local b = new("TextButton", {Position = UDim2.new(0, 0, 0, y), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = text, TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = true, ZIndex = 31}, menu)
        new("UIPadding", {PaddingLeft = UDim.new(0, 16)}, b)
        b.MouseButton1Click:Connect(function() setMenu(false); fn() end)
    end
    menuItem("Nova guia", 46, function()
        table.insert(tabs, newTab())
        cur = #tabs
        render()
    end)
    menuItem("Favoritos", 80, function() openPanel("fav") end)
    menuItem("Histórico", 114, function() openPanel("hist") end)
    menuItem("Copiar URL", 148, function()
        local e = curEntry()
        local clip = setclipboard or toclipboard
        if not e.url then toast("Nenhuma URL para copiar")
        elseif type(clip) == "function" then pcall(clip, e.url); toast("Link copiado")
        else toast("Clipboard indisponível") end
    end)
    menuItem("Limpar histórico", 182, function()
        phoneSettings.browserHistory = {}
        saveSettings()
        toast("Histórico limpo")
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
    end

    tabBtn.MouseButton1Click:Connect(function()
        address:ReleaseFocus()
        if switcher.Visible then
            switcher.Visible = false
        else
            panel.Visible = false
            switcher.Visible = true
            refreshSwitcher()
        end
    end)

    -- ---------- endereço ----------
    address.Focused:Connect(function()
        address.Text = fullText(curEntry())
        task.defer(function()
            pcall(function()
                address.SelectionStart = 1
                address.CursorPosition = #address.Text + 1
            end)
        end)
    end)
    address.FocusLost:Connect(function(enter)
        if enter then runInput(address.Text) end
        updateChrome()
    end)
    reloadBtn.MouseButton1Click:Connect(function()
        if curEntry().state == "loading" then stopLoad() else reload() end
    end)

    -- voltar do sistema: fecha painéis / volta no histórico; false = sair para a tela inicial
    Nav.web = {}
    Nav.web.goBack = function()
        if menuLayer.Visible or switcher.Visible or panel.Visible then closeOverlays(); return true end
        if address:IsFocused() then address:ReleaseFocus(); return true end
        local t = tabs[cur]
        if t.pos > 1 then t.pos = t.pos - 1; showEntry(t); return true end
        return false
    end

    createNavBar(frame)
    render()
    return frame
end

local WebBrowserFrame = makeBrowserScreen()

-- ---------- registro das telas ----------
screens.home      = {frame = PhoneHome}
screens.music     = {frame = MainFrame,      app = true, name = "Música",     color = Color3.fromRGB(0, 180, 255),  icon = Icons.music,     onOpen = function() refreshFiles() end, onClose = function() stopMusic() end}
screens.stopwatch = {frame = StopwatchFrame, app = true, name = "Cronômetro", color = Color3.fromRGB(255, 140, 30), icon = Icons.stopwatch, onClose = function() resetStopwatch() end}
screens.config    = {frame = ConfigFrame,    app = true, name = "Config",     color = Color3.fromRGB(120, 120, 130), icon = Icons.gear, onOpen = function() if cfgReset then cfgReset() end end}
screens.gallery   = {frame = GalleryFrame,   app = true, name = "Galeria",    color = Color3.fromRGB(180, 80, 220), icon = Icons.gallery,   onOpen = function() refreshPhotos() end}
screens.gps       = {frame = Nav.gps.frame,  app = true, name = "GPS",       color = Color3.fromRGB(46, 190, 120), icon = Icons.gps, onOpen = function() Nav.gps.onOpen() end, onClose = function() Nav.gps.onClose() end}
screens.web       = {frame = WebBrowserFrame, app = true, name = "Navegador", color = Color3.fromRGB(35,145,205), icon = Icons.search}
screens.recents   = {frame = RecentsFrame,   onOpen = function() rcBg.Image = currentWallpaper end}

-- ---------- apps abertos ----------
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

    -- cabeçalho: mini ícone + nome + X
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

    -- "print" do app: bloco colorido com o ícone grande
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

    -- interações: tocar abre | deslizar pra cima fecha | X fecha
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

-- ---------- trocar de tela (com animação de subida) ----------
function showScreen(id, animate)
    local target = screens[id]
    if not target then return end
    if id ~= "home" and Nav.boot and Nav.boot.active then return end -- boot tocando: apps bloqueados
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

-- ---------- botões do sistema ----------
function Nav.home()
    if currentScreen == "home" then return end
    showScreen("home", true)
end

function Nav.back()
    if currentScreen == "home" then return end
    if currentScreen == "recents" then
        showScreen(prevScreen ~= "recents" and prevScreen or "home", true)
        return
    end
    if currentScreen == "config" and cfgGoBack and cfgGoBack() then return end
    if currentScreen == "gps" and Nav.gps.goBack and Nav.gps.goBack() then return end
    if currentScreen == "web" and Nav.web and Nav.web.goBack and Nav.web.goBack() then return end
    if currentScreen == "gallery" and isInPhotoViewer then
        if isPhotoMenuOpen then closePhotoMenu() else exitPhotoViewer() end
        return
    end
    showScreen("home", true)
end

function Nav.recents()
    if currentScreen == "recents" then
        showScreen(prevScreen ~= "recents" and prevScreen or "home", true)
        return
    end
    prevScreen = currentScreen
    showScreen("recents", true)
end

MusicAppIcon.MouseButton1Click:Connect(function() showScreen("music", true) end)
StopwatchAppIcon.MouseButton1Click:Connect(function() showScreen("stopwatch", true) end)
ConfigAppIcon.MouseButton1Click:Connect(function() showScreen("config", true) end)
GalleryAppIcon.MouseButton1Click:Connect(function() showScreen("gallery", true) end)
Nav.gps.icon.MouseButton1Click:Connect(function() showScreen("gps", true) end)
WebBrowserIcon.MouseButton1Click:Connect(function() showScreen("web", true) end)

-- ###################### ANIMAÇÃO DE BOOT (REWORK) ######################
-- Toca UMA vez por servidor: na primeira vez que o celular é aberto depois de entrar.
-- Sequência: power-on (linha de luz) -> anel de pontos surge -> letras T Z E caem com glitch + brilho verde
--            -> "P H O N E" -> anel vira o indicador de progresso (pontos acendem + % + etapas)
--            -> flash do anel -> "Olá, nome" digitado -> some com zoom.
-- Toque na tela depois de 1,5 s para pular. Enquanto toca, os apps ficam bloqueados.
-- Para tocar de novo em testes:  Nav.boot.done = false
-- Tudo dentro de uma função (zero locals novos no escopo do arquivo = sem risco do limite de 200).
Nav.boot = {done = false, active = false}
function Nav.boot.play()
    local B = Nav.boot
    if B.done then return end
    B.done, B.active = true, true

    local ACCB = Color3.fromRGB(50, 205, 50)
    local ACCL = Color3.fromRGB(150, 255, 150)
    local DIM = Color3.fromRGB(44, 44, 52)
    local GREY = Color3.fromRGB(150, 150, 165)
    local CY = 0.42 -- altura do centro da logo
    local NDOT, RING_R = 36, 86
    local t0 = os.clock()
    local finished = false
    local rnd = math.random

    -- raiz: CanvasGroup (dá pra apagar tudo de uma vez com GroupTransparency)
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

    -- brilhos pulsando atrás da logo (2 camadas, ritmos diferentes)
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
    glowA.BackgroundTransparency, glowB.BackgroundTransparency = 1, 1 -- entram depois do power-on

    -- linha de varredura (scanline) descendo devagar
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

    -- anel de pontos (vira o indicador de progresso)
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

    -- ondas (anéis que se expandem)
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

    -- partículas subindo (fundo)
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

    -- logo: letras T Z E
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
        -- brilho verde que passa por cima da letra
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
    footer.Text = "TZE PHONE  •  V8"
    footer.Font = Enum.Font.Gotham
    footer.TextSize = 9
    footer.TextColor3 = GREY
    footer.TextTransparency = 1
    footer.ZIndex = 103
    footer.Parent = content

    -- saudação (digitada)
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

    -- etapas + porcentagem
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

    -- progresso suave: acende os pontos do anel conforme o valor sobe
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

    -- saída: some com um leve zoom
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

    -- toque pula (depois de 1,5 s)
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

    -- tremida rápida (glitch) na logo
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
        if w(0.35) then return end -- espera o celular terminar de subir

        -- 1) POWER-ON: linha de luz abre a tela
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

        -- loops de fundo (só rodam enquanto não terminou)
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

        -- 2) anel de pontos surge em cascata
        task.spawn(function()
            for i = 1, NDOT do
                if finished then return end
                TweenService:Create(dots[i], TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                    {Size = UDim2.new(0, 3, 0, 3)}):Play()
                task.wait(0.014)
            end
        end)
        if w(0.2) then return end

        -- 3) letras caem em sequência (com quique)
        for _, l in ipairs(letters) do
            TweenService:Create(l, back, {TextTransparency = 0, Position = UDim2.new(0, 0, 0, 0)}):Play()
            if w(0.15) then return end
        end
        if w(0.3) then return end
        glitch()
        if finished then return end

        -- brilho verde varrendo cada letra
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

        -- 4) carregamento por etapas (o anel acende)
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

        -- 5) flash: anel inteiro brilha + onda grande
        wave(true)
        for _, d in ipairs(dots) do
            d.BackgroundColor3 = WHITE
            TweenService:Create(d, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {BackgroundColor3 = ACCB}):Play()
        end
        TweenService:Create(logo, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
            {Size = UDim2.new(0, 168, 0, 67)}):Play()
        if w(0.25) then return end

        -- 6) saudação digitada
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

-- ========== ABRIR / FECHAR O CELULAR ==========
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
    if not Nav.boot.done then Nav.boot.play() end -- animação de boot (1ª vez no servidor)
end

local function togglePhone()
    if isPhoneOpen then closePhone() else openPhone() end
end


-- ========== HOLD 0.45s PARA ARRASTAR SÓ O BOTÃO (sistema do LOCK) ==========
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

-- Tecla 0 (PC)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Zero or input.KeyCode == Enum.KeyCode.KeypadZero then
        togglePhone()
    end
end)
end


-- Character
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


-- ###################### CELULAR 3D NA MÃO (R15 + R6) ######################
-- Modelo 3D do celular (carcaça metálica, vidro, tela com papel de parede + relógio, câmeras, botões)
-- Aparece na mão direita (R15) / no antebraço direito (R6) quando o celular está ABERTO e some quando fecha.
-- V13: braço animado pelo MOTOR DE POSE DO STAND (D10BRAND0) com correção de rig R15/R6.
-- Usa: isPhoneOpen, currentWallpaper, phoneSettings, Nav.shell (cor da carcaça) do script principal.
do
    local CFG = {
        ativo       = true,          -- _G.TZE_Phone3D = false desliga em tempo real
        escala      = 0.8,           -- tamanho do celular
        balanco     = 0,             -- V14: braço 100% parado (0 = parado | >0 = balanço sutil)
        -- R15
        ombro       = 53,            -- graus: braço levantado pra frente
        cotovelo    = 68,            -- graus: dobra do antebraço (maior = tela mais virada pro rosto)
        punho       = -21,           -- graus: vira a palma pra cima
        paraDentro  = 10,            -- graus: braço levemente pra dentro (frente do peito)
        celularY    = -0.92,         -- posição do celular na mão (negativo = em direção aos dedos)
        celularZ    = -0.09,         -- deslocamento lateral na mão
        -- R6 (sem cotovelo/punho): braço reto levantado, celular deitado em cima do antebraço
        ombroR6       = 78,          -- graus: braço levantado pra frente (R6)
        paraDentroR6  = -6,          -- graus: Z negativo = braço pra dentro (frente do peito)
        r6Tilt        = 38,          -- graus: inclinação da tela pro rosto
        r6Y           = -1.44,       -- posição ao longo do braço (negativo = em direção à ponta)
        r6X           = -0.22,       -- deslocamento lateral
        r6Z           = -0.16,       -- afasta/aproxima do braço
        -- V15: perfis por rig (o Checker de Rig escolhe R15 ou R6 sozinho)
        giroCelular    = {R15 = 33, R6 = 64},  -- graus que SÓ O CELULAR gira pra DIREITA (negativo = esquerda)
        celularInclina = {R15 = 26, R6 = 47},  -- V16: inclina o celular (frente/trás)
        celularRolagem = {R15 = -41, R6 = -1}, -- V16: rola o celular (tela girando no plano)
        bracoEsq       = {R15 = 27, R6 = 41},  -- graus que o BRAÇO vai pra ESQUERDA
        sinalGiro      = {R15 = 1,  R6 = -1},  -- corrige o sentido do eixo de cada rig (se girar errado, troque 1 <-> -1)
    }

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local LP = Players.LocalPlayer

    local W, H, T, R = 0.90, 1.82, 0.10, 0.15     -- largura, altura, espessura, raio dos cantos (studs)
    local rad = math.rad

    local state = {model = nil, parts = {}, alpha = 0, tgt = 0, weld = nil, joints = nil,
                   metalParts = {}, backGlass = nil, screenGui = nil, flash = nil,
                   clock = nil, date = nil, wall = nil, lastWall = nil, lastTheme = nil, char = nil}

    -- ---------- construção ----------
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

    -- placa com cantos arredondados (3 blocos + 4 cilindros), centrada em cf; espessura no eixo Z
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

        -- escurece levemente o topo/baixo para o texto ler bem
        local shade = Instance.new("Frame")
        shade.Size = UDim2.fromScale(1, 1)
        shade.BackgroundColor3 = Color3.new(0, 0, 0)
        shade.BackgroundTransparency = 0.78
        shade.BorderSizePixel = 0
        shade.Parent = wall
        local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 56); sc.Parent = shade

        -- ilha dinâmica
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

        -- ícones de apps (quatro bolhas) + dock
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

    -- ============================================================
    -- 🦴 MOTOR DE POSE DO STAND (portado do D10BRAND0) + CORREÇÃO DE RIG R15 / R6
    -- Anima as juntas do braço direito pelo C0 com interpolação Hermite/Catmull-Rom,
    -- reaplicada em 3 pontos do frame (RenderStep Last + Stepped + Heartbeat),
    -- com re-scan automático das juntas e suporte a Motor6D e AnimationConstraint.
    -- Ângulos em graus no eixo da peça-pai: braço X+ = para frente | Z+ = abre pro lado
    -- ============================================================
    local V3d = Vector3.new
    local ZERO3 = V3d()
    local PK = {"rsh", "rel", "rwr"}
    local PP = {FadeIn = 0.14, FadeOut = 0.18, Intensity = 1.0}
    local PP_BIND = "TZE_PhonePose"

    local function spSmooth(a) return a * a * (3 - 2 * a) end

    -- junções agnósticas: AnimationConstraint usa Attachment0/1, Motor6D usa Part0/Part1
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

    local SP_KIN = setmetatable({}, {__mode = "k"})   -- IsKinematic original
    local SP_BASE = setmetatable({}, {__mode = "k"})  -- C0 original (guardado UMA vez)

    -- acha as juntas do braço direito em R15 (Ombro/Cotovelo/Punho) ou R6 (Right Shoulder)
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

    -- ============================================================
    -- 🔍 CHECKER DE RIG: descobre se o personagem é R15 ou R6
    -- 1) _G.TZE_ForceRig = "R15"/"R6" (força manual)  2) Humanoid.RigType  3) peças do corpo  4) juntas
    -- ============================================================
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

    -- keyframes Hermite (só as 3 chaves do braço)
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

    -- pose-alvo "segurando o celular" por rig
    local function phoneFrames(rig)
        local tgt
        if rig == "R6" then
            -- R6: sem cotovelo/punho -> braço reto levantado, celular deitado em cima do antebraço
            tgt = {rsh = V3d(CFG.ombroR6, 0, CFG.paraDentroR6 - CFG.bracoEsq.R6), rel = ZERO3, rwr = ZERO3}
        else
            tgt = {rsh = V3d(CFG.ombro, 0, CFG.paraDentro - CFG.bracoEsq.R15), rel = V3d(CFG.cotovelo, 0, 0), rwr = V3d(0, CFG.punho, 0)}
        end
        return {
            {t = 0.00, rsh = ZERO3, rel = ZERO3, rwr = ZERO3},
            {t = 0.16, rsh = tgt.rsh * 1.12, rel = tgt.rel * 1.10, rwr = tgt.rwr * 0.9},   -- levanta com leve overshoot
            {t = 0.34, hold = true, rsh = tgt.rsh, rel = tgt.rel, rwr = tgt.rwr},          -- assenta
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
        local tf = c0:Inverse() * A * c0     -- rotação no eixo da peça-pai (vale p/ R15 e R6)
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

        -- o jogo trocou/removeu alguma junta? re-escaneia (no máx. 1x a cada 0.2s)
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
                -- V14: a animação do bundle/jogo NÃO mexe mais no braço (zera o Transform em todo ponto do frame)
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
        -- V14: no instante em que o bundle escreve o Transform do braço, já zera de volta
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

    -- ---------- posição do celular na mão por rig (recalculável ao vivo pelo editor) ----------
    local function computeGrip(rig, hand)
        local s = CFG.escala
        if rig == "R15" then
            -- palma da mão direita: frente da tela -> -X da mão, topo -> dedos (-Y)
            local x = -(hand.Size.X / 2 + (T * s) / 2 - 0.05)
            return CFrame.fromMatrix(Vector3.new(x, CFG.celularY * s, CFG.celularZ),
                Vector3.new(0, 0, -1), Vector3.new(0, -1, 0), Vector3.new(-1, 0, 0))
        else
            -- R6: celular deitado sobre o "Right Arm": tela -> -Z do braço, topo -> ponta do braço (-Y)
            local z = -(hand.Size.Z / 2 + (T * s) / 2 - 0.05) + CFG.r6Z
            return CFrame.new(CFG.r6X, CFG.r6Y * s, z) * CFrame.Angles(rad(CFG.r6Tilt), 0, 0)
                * CFrame.fromMatrix(Vector3.new(), Vector3.new(1, 0, 0), Vector3.new(0, -1, 0), Vector3.new(0, 0, -1))
        end
    end

    -- ---------- construção do celular + grip por rig ----------
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

        -- corpo (moldura metálica)
        local body = slab("Corpo", W, H, T, R, CFrame.new(), met, Enum.Material.Metal, model, state.metalParts)
        local rootPart = body[1]
        model.PrimaryPart = rootPart
        -- vidro traseiro (cor da carcaça, mais claro)
        slab("Traseira", W - 0.05, H - 0.05, 0.012, R - 0.02, CFrame.new(0, 0, -T / 2 - 0.002), metal[1], Enum.Material.SmoothPlastic, model, state.metalParts)
        -- vidro frontal preto
        slab("Vidro", W - 0.05, H - 0.05, 0.012, R - 0.02, CFrame.new(0, 0, T / 2 + 0.002), glass, Enum.Material.Glass, model)
        -- display
        local display = newPart("Display", Vector3.new(W - 0.11, H - 0.11, 0.002), CFrame.new(0, 0, T / 2 + 0.0095), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, model)
        buildScreenGui(display)

        -- módulo de câmeras (traseira = -Z; visto de trás, canto superior esquerdo = +X)
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

        -- logo na traseira
        local logo = cyl("Logo", 0.2, 0.01, CFrame.new(0, -0.15, -T / 2 - 0.009), Color3.fromRGB(240, 240, 245), Enum.Material.SmoothPlastic, model)
        logo.Transparency = 0.5

        -- botões laterais
        local function btn(n, x, y, h) newPart(n, Vector3.new(0.03, h, 0.05), CFrame.new(x, y, 0), met, Enum.Material.Metal, model) ; table.insert(state.metalParts, state.parts[#state.parts]) end
        btn("Power", W / 2 + 0.008, 0.25, 0.30)
        btn("VolCima", -W / 2 - 0.008, 0.30, 0.20)
        btn("VolBaixo", -W / 2 - 0.008, 0.05, 0.20)
        btn("Acao", -W / 2 - 0.008, 0.55, 0.10)

        -- escala
        if CFG.escala ~= 1 then
            for _, p in ipairs(state.parts) do
                p.Size = p.Size * CFG.escala
                p.CFrame = rootPart.CFrame * ((rootPart.CFrame:Inverse() * p.CFrame).Rotation + (rootPart.CFrame:Inverse() * p.CFrame).Position * CFG.escala)
            end
        end

        -- solda tudo no corpo
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
        state.baseC0 = c0          -- V15: posição base na mão (sem giro) — o giro é aplicado por cima, só no celular
        state.lastGiro = nil
        state.char = char
        state.lastTheme, state.lastWall = nil, nil
        return true
    end

    -- ---------- atualização ----------
    local function setLTM(v)
        for _, p in ipairs(state.parts) do
            if p.Parent then p.LocalTransparencyModifier = v end
        end
    end

    local lastLTM = -1
    local function refreshVisual(t)
        -- cor da carcaça (segue Config > Cor da carcaça)
        local metal, name = themeColors()
        if state.lastTheme ~= name then
            state.lastTheme = name
            for _, p in ipairs(state.metalParts) do
                if p.Name:sub(1, 8) == "Traseira" then p.Color = metal[1]
                elseif p.Name:sub(1, 6) == "ModCam" then p.Color = metal[3]
                else p.Color = metal[2] end
            end
        end
        -- papel de parede
        local wp = currentWallpaper
        if state.wall and wp and state.lastWall ~= wp then
            state.lastWall = wp
            pcall(function() state.wall.Image = wp end)
        end
        -- relógio
        if state.clock then
            local tm = os.date("%H:%M")
            if state.clock.Text ~= tm then state.clock.Text = tm end
            local dt = os.date("%d/%m")
            if state.date and state.date.Text ~= dt then state.date.Text = dt end
        end
        -- lanterna na traseira
        if state.flash and state.flash.Parent then
            local on = phoneSettings.flashlightEnabled and true or false
            local pl = state.flash:FindFirstChildOfClass("PointLight")
            if pl then pl.Range = on and 14 or 0; pl.Brightness = on and 2 or 0 end
            state.flash.Material = on and Enum.Material.Neon or Enum.Material.Glass
        end
    end

    -- avaliador da pose: keyframes Hermite + balanço sutil (balanço só vale p/ R15; no R6 vira só ombro)
    local function makeEval(rig)
        local frames, ver = phoneFrames(rig), state.poseVer
        return function(t)
            if ver ~= state.poseVer then frames, ver = phoneFrames(rig), state.poseVer end   -- V16: editor ao vivo
            local pose = spEvalFrames(frames, t)
            if CFG.balanco > 0 then
                local sw = math.sin(os.clock() * 1.6) * CFG.balanco
                pose.rsh = pose.rsh + V3d(sw, 0, 0)
                if rig == "R15" then pose.rel = pose.rel - V3d(sw * 1.5, 0, 0) end
            end
            return pose
        end
    end

    -- ---------- toolbelt (cintura) ----------
    -- CFrame do celular preso na lateral direita do quadril, tela virada pra fora
    local function holsterC0(rig, waist)
        local s = CFG.escala
        -- lateral direita: +X do torso, ligeiramente pra frente e abaixo do centro
        local offX =  (waist.Size.X / 2) + (W * s) / 2 - 0.05   -- encostar na lateral
        local offY = -0.10                                          -- abaixo do centro da cintura
        local offZ = -0.10                                          -- levemente pra frente
        -- tela virada pra fora (+X do torso), topo do celular pra cima (+Y do torso)
        return CFrame.new(offX, offY, offZ)
            * CFrame.fromMatrix(Vector3.new(),
                Vector3.new(0,  1,  0),   -- topo do celular = +Y do torso
                Vector3.new(0,  0, -1),   -- frente da tela  = -Z do torso (pra fora)
                Vector3.new(-1, 0,  0))   -- espessura        = -X
            * CFrame.Angles(0, 0, rad(-12))  -- leve inclinação pra ficar natural
    end

    -- troca o Part0 do weld e ajusta C0; chama só quando o alvo realmente muda
    local function reweld(newPart0, newC0)
        if not state.weld or not state.weld.Parent then return end
        state.weld.Part0 = newPart0
        state.weld.C0    = newC0
        state.lastGiro   = nil   -- força reapply do giro na próxima frame (só vale quando na mão)
    end

    local holsterAttached = false   -- rastreia onde o weld está atualmente

    local function onStep(dt)
        local char = LP.Character
        if not char then return end
        if state.rebuildAt and os.clock() >= state.rebuildAt then   -- V16: tamanho mudou no editor
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

        -- V17: toolbelt — celular na cintura quando guardado, na mão quando aberto
        if state.weld and state.rig and state.hand then
            if want == 1 then
                -- celular aberto → solda na mão
                if holsterAttached then
                    reweld(state.hand, state.baseC0)
                    holsterAttached = false
                end
                -- V15: giro do celular (SÓ o celular, via Weld; não mexe no braço)
                local g = tonumber(_G.TZE_PhoneGiro) or CFG.giroCelular[state.rig] or 0
                g = g * (CFG.sinalGiro[state.rig] or 1)
                local inc, rol = CFG.celularInclina[state.rig] or 0, CFG.celularRolagem[state.rig] or 0
                local key = g .. "|" .. inc .. "|" .. rol
                if state.lastGiro ~= key then
                    state.lastGiro = key
                    state.weld.C0 = state.baseC0 * CFrame.Angles(rad(inc), rad(g), rad(rol))
                end
            else
                -- celular guardado → solda na cintura (toolbelt)
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

        -- visibilidade: guardado = sempre visível (alpha fixo 1); aberto = fade normal
        local ltm
        if want == 0 and holsterAttached then
            ltm = 0   -- cintura: sempre visível
        else
            ltm = 1 - a
        end
        if math.abs(ltm - lastLTM) > 0.004 then lastLTM = ltm; setLTM(ltm) end
        if state.screenGui then state.screenGui.Enabled = (want == 1 and a > 0.35) end

        -- pose do braço (motor do Stand): entra ao abrir, sai ao fechar
        if want == 1 then
            if SP.bound and SP.char == char then
                SP.fading = false                       -- reabriu durante o fade-out: retoma
            else
                SP.start(char, makeEval(state.rig))
            end
        elseif SP.bound and not SP.fading then
            SP.stop(PP.FadeOut)
        end

        if a <= 0 and not holsterAttached then return end
        if a > 0.5 or holsterAttached then refreshVisual(os.clock()) end
    end

    -- ============================================================
    -- 🛠 EDITOR EM TEMPO REAL (V16)
    -- Botão 🛠 na lateral esquerda abre o painel. Tudo que você mexe aparece NA HORA no personagem.
    -- "Exportar" gera o texto com todas as configurações (R15 + R6) pra você me mandar.
    -- Atalhos: _G.TZE_PhoneEditor() abre/fecha o painel.
    -- ============================================================
    local function applyLive(kind)
        if kind == "pose" then
            state.poseVer = (state.poseVer or 0) + 1       -- makeEval recria os keyframes
        elseif kind == "grip" then
            if state.rig and state.hand then
                state.baseC0 = computeGrip(state.rig, state.hand)
                state.lastGiro = nil
            end
        elseif kind == "giro" then
            state.lastGiro = nil
        elseif kind == "scale" then
            state.rebuildAt = os.clock() + 0.3             -- reconstrói o modelo (debounce)
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

        -- ---------- especificações dos sliders ----------
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

        -- ---------- janela ----------
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

        -- barra de título (arrasta o painel)
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

        -- abas
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

        -- ---------- sliders ----------
        local active          -- slider sendo arrastado
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

        -- ---------- exportar ----------
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

        -- ---------- abrir/fechar, arrastar, drag global ----------
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

        -- mostra o rig detectado e abre a aba certa na primeira detecção
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


-- ###################### SEUS ADDONS AQUI ######################
-- Copie o modelo abaixo para criar qualquer coisa nova sem estourar o limite de locals:
--[[
do
    local meuTexto = Instance.new("TextLabel")
    meuTexto.Text = "Olá!"
    meuTexto.Parent = PhoneHome     -- PhoneHome, MainFrame, ConfigFrame, etc. já estão disponíveis
    -- ícone desenhado:  local ic = Icons.gear(PhoneHome, 24, Color3.new(1,1,1), 10)
end
]]

end, function(e) return debug.traceback(tostring(e), 2) end)

if not __ok then
    warn("[TZE PHONE] Erro ao iniciar: " .. tostring(__err))
end
