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
    fpsEnabled = false,
    flashlightEnabled = false,
    volume = 1,
    battery = 100,
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

-- =========================================================
-- SERVIÇOS E VARIÁVEIS
-- =========================================================
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local isTouchDevice = UserInputService.TouchEnabled
local Character, Humanoid
local isPhoneOpen = false
local isMusicOpen = false
local currentApp = "home"
local fpsLabel = nil
local phoneFlashlight = nil
local currentVolume = phoneSettings.volume or 1
local currentWallpaper = phoneSettings.wallpaper or defaultSettings.wallpaper
local batteryDead = false

-- =========================================================
-- HOTBAR SÓ DO PHONE (CENTRO SUPERIOR)
-- =========================================================
if CoreGui:FindFirstChild("TzeCustomHotbar") then
    CoreGui.TzeCustomHotbar:Destroy()
end

local HotbarGui = Instance.new("ScreenGui")
HotbarGui.Name = "TzeCustomHotbar"
HotbarGui.ResetOnSpawn = false
HotbarGui.IgnoreGuiInset = true
HotbarGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
HotbarGui.Parent = CoreGui

local HotbarFrame = Instance.new("Frame")
HotbarFrame.Name = "HotbarFrame"
HotbarFrame.Size = UDim2.new(0, 48, 0, 40)
local savedHotbar = phoneSettings.hotbarPosition or defaultSettings.hotbarPosition
HotbarFrame.Position = UDim2.new(savedHotbar.X, savedHotbar.XOffset, savedHotbar.Y, savedHotbar.YOffset)
HotbarFrame.BackgroundTransparency = 1
HotbarFrame.Parent = HotbarGui

local hotbarUIScale = Instance.new("UIScale")
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

local phoneSlot = Instance.new("TextButton")
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

local slotEmoji = Instance.new("TextLabel")
slotEmoji.Size = UDim2.new(1, 0, 1, 0)
slotEmoji.BackgroundTransparency = 1
slotEmoji.Text = "📱"
slotEmoji.TextSize = 20
slotEmoji.Parent = phoneSlot

local selectedFrame = Instance.new("Frame")
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

-- =========================================================
-- PHONE SYSTEM
-- =========================================================
if CoreGui:FindFirstChild("TzeMusicSystem") then
    CoreGui.TzeMusicSystem:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TzeMusicSystem"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

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

-- Função de navegação
local function createNavBar(parent)
    local navBar = Instance.new("Frame")
    navBar.Name = "NavBar"
    navBar.Size = UDim2.new(1, -20, 0, 30)
    navBar.Position = UDim2.new(0, 10, 1, -38)
    navBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    navBar.BackgroundTransparency = 0.4
    navBar.BorderSizePixel = 0
    navBar.ZIndex = 20
    navBar.Parent = parent
    Instance.new("UICorner", navBar).CornerRadius = UDim.new(0, 14)

    local backBtn = Instance.new("TextButton")
    backBtn.Name = "BackBtn"
    backBtn.Size = UDim2.new(0, 28, 0, 28)
    backBtn.Position = UDim2.new(0, 22, 0.5, -14)
    backBtn.BackgroundTransparency = 1
    backBtn.Text = "◀"
    backBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    backBtn.TextSize = 20
    backBtn.Font = Enum.Font.GothamBold
    backBtn.ZIndex = 21
    backBtn.Parent = navBar

    local homeBtn = Instance.new("TextButton")
    homeBtn.Name = "HomeCircle"
    homeBtn.Size = UDim2.new(0, 28, 0, 28)
    homeBtn.Position = UDim2.new(0.5, -14, 0.5, -14)
    homeBtn.BackgroundTransparency = 1
    homeBtn.Text = "◯"
    homeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    homeBtn.TextSize = 22
    homeBtn.Font = Enum.Font.GothamBold
    homeBtn.ZIndex = 21
    homeBtn.Parent = navBar

    local function addClickAnim(btn)
        btn.MouseButton1Down:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.08), {TextSize = btn.TextSize - 4}):Play()
        end)
        btn.MouseButton1Up:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Back), {TextSize = (btn.Name == "BackBtn") and 20 or 22}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {TextSize = (btn.Name == "BackBtn") and 20 or 22}):Play()
        end)
    end
    addClickAnim(backBtn)
    addClickAnim(homeBtn)

    return homeBtn, backBtn
end

-- ========== PHONE HOME (FIXO - NÃO ARRASTÁVEL) ==========
local PhoneHome = Instance.new("Frame")
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

local homeBezel = Instance.new("UIStroke")
homeBezel.Color = Color3.fromRGB(50, 205, 50)
homeBezel.Thickness = 6
homeBezel.Parent = PhoneHome

local homeBg = Instance.new("ImageLabel")
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

local homeEars = Instance.new("ImageLabel")
homeEars.Name = "EarsDecoration"
homeEars.Size = UDim2.new(0, 340, 0, 95)
homeEars.Position = UDim2.new(0.5, -170, 0, -48)
homeEars.BackgroundTransparency = 1
homeEars.Image = "rbxassetid://108135642658853"
homeEars.ImageColor3 = Color3.fromRGB(50, 205, 50)
homeEars.ZIndex = 10
homeEars.Parent = PhoneHome

local homeNotch = Instance.new("Frame")
homeNotch.Size = UDim2.new(0, 82, 0, 24)
homeNotch.Position = UDim2.new(0.5, -41, 0, 9)
homeNotch.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
homeNotch.BorderSizePixel = 0
homeNotch.ZIndex = 5
homeNotch.Parent = PhoneHome
Instance.new("UICorner", homeNotch).CornerRadius = UDim.new(1, 0)

local homeCamDot = Instance.new("Frame")
homeCamDot.Size = UDim2.new(0, 10, 0, 10)
homeCamDot.Position = UDim2.new(0.5, -55, 0, 13)
homeCamDot.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
homeCamDot.BorderSizePixel = 0
homeCamDot.ZIndex = 6
homeCamDot.Parent = PhoneHome
Instance.new("UICorner", homeCamDot).CornerRadius = UDim.new(1, 0)

local homeStatus = Instance.new("TextLabel")
homeStatus.Name = "StatusClock"
homeStatus.Size = UDim2.new(0.5, -10, 0, 22)
homeStatus.Position = UDim2.new(0, 20, 0, 40)
homeStatus.BackgroundTransparency = 1
homeStatus.Text = os.date("%H:%M")
homeStatus.TextColor3 = Color3.fromRGB(255, 255, 255)
homeStatus.Font = Enum.Font.GothamBold
homeStatus.TextSize = 14
homeStatus.TextXAlignment = Enum.TextXAlignment.Left
homeStatus.ZIndex = 5
homeStatus.Parent = PhoneHome

fpsLabel = Instance.new("TextLabel")
fpsLabel.Name = "FPSLabel"
fpsLabel.Size = UDim2.new(0.5, -10, 0, 22)
fpsLabel.Position = UDim2.new(0.5, 0, 0, 40)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Text = "FPS: --"
fpsLabel.TextColor3 = Color3.fromRGB(50, 205, 50)
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.TextSize = 13
fpsLabel.TextXAlignment = Enum.TextXAlignment.Right
fpsLabel.Visible = phoneSettings.fpsEnabled
fpsLabel.ZIndex = 5
fpsLabel.Parent = PhoneHome

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

local function createAppIcon(name, emoji, color, pos)
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

    local emojiLabel = Instance.new("TextLabel")
    emojiLabel.Size = UDim2.new(1, 0, 1, 0)
    emojiLabel.BackgroundTransparency = 1
    emojiLabel.Text = emoji
    emojiLabel.TextSize = 28
    emojiLabel.ZIndex = 7
    emojiLabel.Parent = bg

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

    return icon
end

local MusicAppIcon = createAppIcon("Música", "🎵", Color3.fromRGB(0, 180, 255), UDim2.new(0, 5, 0, 0))
local StopwatchAppIcon = createAppIcon("Cronômetro", "⏱️", Color3.fromRGB(255, 140, 30), UDim2.new(0, 85, 0, 0))
local ConfigAppIcon = createAppIcon("Config", "⚙️", Color3.fromRGB(120, 120, 130), UDim2.new(0, 165, 0, 0))
local GalleryAppIcon = createAppIcon("Galeria", "🖼️", Color3.fromRGB(180, 80, 220), UDim2.new(0, 5, 0, 100))
local MapAppIcon = createAppIcon("Mapa", "🗺️", Color3.fromRGB(40, 170, 90), UDim2.new(0, 85, 0, 100))

local homeNavBtn, homeBackBtn = createNavBar(PhoneHome)

-- Clock + FPS
task.spawn(function()
    while true do
        if homeStatus and homeStatus.Parent then
            homeStatus.Text = os.date("%H:%M")
        end
        task.wait(1)
    end
end)

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
        if fpsLabel and phoneSettings.fpsEnabled then
            fpsLabel.Text = "FPS: " .. currentFps
            fpsLabel.Visible = true
        elseif fpsLabel then
            fpsLabel.Visible = false
        end
    end
end)

-- ========== VOLUME ==========
local VolumeFrame = Instance.new("Frame")
VolumeFrame.Name = "VolumeFrame"
VolumeFrame.Size = UDim2.new(0, 16, 0, 96)
VolumeFrame.Position = UDim2.new(0, -22, 0.5, -130)
VolumeFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
VolumeFrame.BackgroundTransparency = 0.15
VolumeFrame.BorderSizePixel = 0
VolumeFrame.ZIndex = 30
VolumeFrame.Visible = false
VolumeFrame.Parent = ScreenGui
Instance.new("UICorner", VolumeFrame).CornerRadius = UDim.new(0, 8)
local volFrameStroke = Instance.new("UIStroke")
volFrameStroke.Color = Color3.fromRGB(50, 205, 50)
volFrameStroke.Thickness = 1.2
volFrameStroke.Parent = VolumeFrame

local VolUpBtn = Instance.new("TextButton")
VolUpBtn.Name = "VolUp"
VolUpBtn.Size = UDim2.new(1, -4, 0, 42)
VolUpBtn.Position = UDim2.new(0, 2, 0, 3)
VolUpBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
VolUpBtn.Text = "🔊"
VolUpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
VolUpBtn.Font = Enum.Font.GothamBold
VolUpBtn.TextSize = 13
VolUpBtn.ZIndex = 31
VolUpBtn.Parent = VolumeFrame
Instance.new("UICorner", VolUpBtn).CornerRadius = UDim.new(0, 6)

local VolDownBtn = Instance.new("TextButton")
VolDownBtn.Name = "VolDown"
VolDownBtn.Size = UDim2.new(1, -4, 0, 42)
VolDownBtn.Position = UDim2.new(0, 2, 0, 51)
VolDownBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
VolDownBtn.Text = "🔉"
VolDownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
VolDownBtn.Font = Enum.Font.GothamBold
VolDownBtn.TextSize = 13
VolDownBtn.ZIndex = 31
VolDownBtn.Parent = VolumeFrame
Instance.new("UICorner", VolDownBtn).CornerRadius = UDim.new(0, 6)

VolUpBtn.MouseButton1Click:Connect(function()
    currentVolume = math.clamp(currentVolume + 0.1, 0, 1)
    phoneSettings.volume = currentVolume
    saveSettings()
    if currentSound then currentSound.Volume = currentVolume end
end)

VolDownBtn.MouseButton1Click:Connect(function()
    currentVolume = math.clamp(currentVolume - 0.1, 0, 1)
    phoneSettings.volume = currentVolume
    saveSettings()
    if currentSound then currentSound.Volume = currentVolume end
end)

local function attachVolumeTo(frame)
    if not frame then return end
    VolumeFrame.Parent = frame
    VolumeFrame.Position = UDim2.new(0, -22, 0.5, -130)
    VolumeFrame.Visible = true
end

-- ========== MUSIC PLAYER ==========
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 280, 0, 440)
MainFrame.Position = PhoneHome.Position
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = false
MainFrame.Visible = false
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 28)

local bezelStroke = Instance.new("UIStroke")
bezelStroke.Color = Color3.fromRGB(50, 205, 50)
bezelStroke.Thickness = 6
bezelStroke.Parent = MainFrame

local earsImage = Instance.new("ImageLabel")
earsImage.Size = UDim2.new(0, 340, 0, 95)
earsImage.Position = UDim2.new(0.5, -170, 0, -48)
earsImage.BackgroundTransparency = 1
earsImage.Image = "rbxassetid://108135642658853"
earsImage.ImageColor3 = Color3.fromRGB(50, 205, 50)
earsImage.ZIndex = MainFrame.ZIndex + 2
earsImage.Parent = MainFrame

local notch = Instance.new("Frame")
notch.Size = UDim2.new(0, 82, 0, 24)
notch.Position = UDim2.new(0.5, -41, 0, 9)
notch.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
notch.BorderSizePixel = 0
notch.Parent = MainFrame
Instance.new("UICorner", notch).CornerRadius = UDim.new(1, 0)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.Position = UDim2.new(0, 0, 0, 38)
TopBar.BackgroundTransparency = 1
TopBar.Parent = MainFrame

local ModeBtn = Instance.new("TextButton")
ModeBtn.Size = UDim2.new(0, 110, 0, 28)
ModeBtn.Position = UDim2.new(1, -122, 0.5, -14)
ModeBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
ModeBtn.Text = "Arquivo"
ModeBtn.TextColor3 = Color3.fromRGB(50, 205, 50)
ModeBtn.Font = Enum.Font.GothamBold
ModeBtn.TextSize = 12
ModeBtn.Parent = TopBar
Instance.new("UICorner", ModeBtn).CornerRadius = UDim.new(0, 10)

local MusicTitle = Instance.new("TextLabel")
MusicTitle.Size = UDim2.new(0, 120, 0, 28)
MusicTitle.Position = UDim2.new(0, 16, 0.5, -14)
MusicTitle.BackgroundTransparency = 1
MusicTitle.Text = "Música"
MusicTitle.TextColor3 = Color3.new(1, 1, 1)
MusicTitle.Font = Enum.Font.GothamBold
MusicTitle.TextSize = 18
MusicTitle.TextXAlignment = Enum.TextXAlignment.Left
MusicTitle.Parent = TopBar

local NowPlayingCard = Instance.new("Frame")
NowPlayingCard.Size = UDim2.new(1, -24, 0, 118)
NowPlayingCard.Position = UDim2.new(0, 12, 0, 88)
NowPlayingCard.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
NowPlayingCard.BorderSizePixel = 0
NowPlayingCard.Parent = MainFrame
Instance.new("UICorner", NowPlayingCard).CornerRadius = UDim.new(0, 16)

local AlbumArt = Instance.new("Frame")
AlbumArt.Size = UDim2.new(0, 56, 0, 56)
AlbumArt.Position = UDim2.new(0, 14, 0.5, -28)
AlbumArt.BackgroundColor3 = Color3.fromRGB(50, 205, 50)
AlbumArt.BorderSizePixel = 0
AlbumArt.Parent = NowPlayingCard
Instance.new("UICorner", AlbumArt).CornerRadius = UDim.new(0, 12)

local AlbumIcon = Instance.new("TextLabel")
AlbumIcon.Size = UDim2.new(1, 0, 1, 0)
AlbumIcon.BackgroundTransparency = 1
AlbumIcon.Text = "🎵"
AlbumIcon.TextSize = 28
AlbumIcon.Parent = AlbumArt

local TrackName = Instance.new("TextLabel")
TrackName.Size = UDim2.new(1, -90, 0, 24)
TrackName.Position = UDim2.new(0, 82, 0, 18)
TrackName.BackgroundTransparency = 1
TrackName.Text = "Nenhuma música"
TrackName.TextColor3 = Color3.new(1, 1, 1)
TrackName.Font = Enum.Font.GothamBold
TrackName.TextSize = 15
TrackName.TextXAlignment = Enum.TextXAlignment.Left
TrackName.TextTruncate = Enum.TextTruncate.AtEnd
TrackName.Parent = NowPlayingCard

local TrackSub = Instance.new("TextLabel")
TrackSub.Size = UDim2.new(1, -90, 0, 18)
TrackSub.Position = UDim2.new(0, 82, 0, 42)
TrackSub.BackgroundTransparency = 1
TrackSub.Text = "Toque para ouvir"
TrackSub.TextColor3 = Color3.fromRGB(140, 140, 155)
TrackSub.Font = Enum.Font.Gotham
TrackSub.TextSize = 12
TrackSub.TextXAlignment = Enum.TextXAlignment.Left
TrackSub.Parent = NowPlayingCard

local TimeBarBG = Instance.new("Frame")
TimeBarBG.Size = UDim2.new(1, -28, 0, 4)
TimeBarBG.Position = UDim2.new(0, 14, 1, -28)
TimeBarBG.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
TimeBarBG.BorderSizePixel = 0
TimeBarBG.Parent = NowPlayingCard
Instance.new("UICorner", TimeBarBG).CornerRadius = UDim.new(1, 0)

local TimeBarFill = Instance.new("Frame")
TimeBarFill.Size = UDim2.new(0, 0, 1, 0)
TimeBarFill.BackgroundColor3 = Color3.fromRGB(50, 205, 50)
TimeBarFill.BorderSizePixel = 0
TimeBarFill.Parent = TimeBarBG
Instance.new("UICorner", TimeBarFill).CornerRadius = UDim.new(1, 0)

local TimeLabel = Instance.new("TextLabel")
TimeLabel.Size = UDim2.new(1, -28, 0, 14)
TimeLabel.Position = UDim2.new(0, 14, 1, -18)
TimeLabel.BackgroundTransparency = 1
TimeLabel.Text = "00:00 / 00:00"
TimeLabel.TextColor3 = Color3.fromRGB(130, 130, 145)
TimeLabel.Font = Enum.Font.Code
TimeLabel.TextSize = 10
TimeLabel.TextXAlignment = Enum.TextXAlignment.Right
TimeLabel.Parent = NowPlayingCard

local Controls = Instance.new("Frame")
Controls.Size = UDim2.new(1, -24, 0, 52)
Controls.Position = UDim2.new(0, 12, 0, 218)
Controls.BackgroundTransparency = 1
Controls.Parent = MainFrame

local function createBtn(text, pos, size)
    local btn = Instance.new("TextButton")
    btn.Size = size
    btn.Position = pos
    btn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    btn.Text = text
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 18
    btn.Parent = Controls
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
    return btn
end

local ShuffleBtn = createBtn("🔀", UDim2.new(0, 0, 0.5, -18), UDim2.new(0, 42, 0, 36))
local PrevBtn = createBtn("⏮", UDim2.new(0.22, -8, 0.5, -18), UDim2.new(0, 46, 0, 36))
local PlayBtn = createBtn("▶", UDim2.new(0.5, -24, 0.5, -22), UDim2.new(0, 48, 0, 44))
PlayBtn.BackgroundColor3 = Color3.fromRGB(50, 205, 50)
PlayBtn.TextColor3 = Color3.fromRGB(10, 10, 15)
local NextBtn = createBtn("⏭", UDim2.new(0.78, -38, 0.5, -18), UDim2.new(0, 46, 0, 36))
local RepeatBtn = createBtn("🔁", UDim2.new(1, -42, 0.5, -18), UDim2.new(0, 42, 0, 36))

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, -24, 0, 32)
SearchBox.Position = UDim2.new(0, 12, 0, 278)
SearchBox.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
SearchBox.PlaceholderText = "🔍 Pesquisar música..."
SearchBox.Text = ""
SearchBox.TextColor3 = Color3.new(1, 1, 1)
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 13
SearchBox.Parent = MainFrame
Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0, 10)

local ScrollList = Instance.new("ScrollingFrame")
ScrollList.Size = UDim2.new(1, -24, 0, 90)
ScrollList.Position = UDim2.new(0, 12, 0, 318)
ScrollList.BackgroundTransparency = 1
ScrollList.ScrollBarThickness = 3
ScrollList.ScrollBarImageColor3 = Color3.fromRGB(50, 205, 50)
ScrollList.Parent = MainFrame
local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout.Parent = ScrollList

local IDInput = Instance.new("TextBox")
IDInput.Size = UDim2.new(1, -24, 0, 34)
IDInput.Position = UDim2.new(0, 12, 0, 318)
IDInput.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
IDInput.PlaceholderText = "Digite o Sound ID do Roblox..."
IDInput.Text = ""
IDInput.TextColor3 = Color3.new(1, 1, 1)
IDInput.Visible = false
IDInput.Parent = MainFrame
Instance.new("UICorner", IDInput).CornerRadius = UDim.new(0, 10)

local musicNavBtn, musicBackBtn = createNavBar(MainFrame)

local function formatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d", mins, secs)
end

local function stopSound()
    if currentSound then
        currentSound:Stop()
        currentSound:Destroy()
        currentSound = nil
    end
end

local function play(id, name, index)
    stopSound()
    currentTrackIndex = index or 0
    currentSound = Instance.new("Sound", MainFrame)
    currentSound.SoundId = id
    currentSound.Volume = currentVolume
    currentSound:Play()
    TrackName.Text = name
    TrackSub.Text = "Tocando agora"
    PlayBtn.Text = "⏸"
    isPaused = false

    currentSound.Ended:Connect(function()
        if not currentSound then return end
        if repeatMode then
            currentSound.TimePosition = 0
            currentSound:Play()
        elseif currentMode == "File" and #mp3List > 0 then
            local nextIdx = shuffleMode and math.random(1, #mp3List) or ((currentTrackIndex % #mp3List) + 1)
            if nextIdx < 1 then nextIdx = #mp3List end
            if nextIdx > #mp3List then nextIdx = 1 end
            play(getcustomasset(mp3List[nextIdx].path), mp3List[nextIdx].name, nextIdx)
        end
    end)
end

local function updateMusicList()
    for _, v in pairs(ScrollList:GetChildren()) do
        if v:IsA("Frame") then v:Destroy() end
    end
    local searchText = SearchBox.Text:lower()
    filteredList = {}
    for _, music in ipairs(mp3List) do
        if searchText == "" or music.name:lower():match(searchText) then
            table.insert(filteredList, music)
        end
    end
    if #filteredList == 0 then
        local emptyFrame = Instance.new("Frame")
        emptyFrame.Size = UDim2.new(1, 0, 0, 50)
        emptyFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        emptyFrame.Parent = ScrollList
        Instance.new("UICorner", emptyFrame).CornerRadius = UDim.new(0, 10)
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Size = UDim2.new(1, 0, 1, 0)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Text = searchText == "" and "📁 Coloque .mp3 em PHONE/Music" or "🔍 Nenhuma música encontrada"
        emptyLabel.TextColor3 = Color3.fromRGB(130, 130, 150)
        emptyLabel.TextSize = 12
        emptyLabel.Parent = emptyFrame
    else
        for idx, music in ipairs(filteredList) do
            local btnFrame = Instance.new("Frame")
            btnFrame.Size = UDim2.new(1, 0, 0, 36)
            btnFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
            btnFrame.Parent = ScrollList
            Instance.new("UICorner", btnFrame).CornerRadius = UDim.new(0, 10)
            local t = Instance.new("TextButton")
            t.Size = UDim2.new(1, 0, 1, 0)
            t.BackgroundTransparency = 1
            t.Text = "  🎵  " .. music.name
            t.TextColor3 = Color3.new(1,1,1)
            t.TextXAlignment = Enum.TextXAlignment.Left
            t.TextSize = 13
            t.Font = Enum.Font.Gotham
            t.Parent = btnFrame
            t.MouseButton1Click:Connect(function()
                play(getcustomasset(music.path), music.name, idx)
            end)
        end
    end
    ScrollList.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 8)
end

local function refreshFiles()
    mp3List = {}
    local paths = {"PHONE/Music/", "PHONE/Music", "PHONE\\Music"}
    local success, files = false, nil
    for _, p in ipairs(paths) do
        success, files = pcall(function() return listfiles(p) end)
        if success and type(files) == "table" and #files > 0 then break end
    end
    if success and type(files) == "table" then
        for _, file in ipairs(files) do
            if tostring(file):lower():match("%.mp3$") then
                local name = tostring(file):match("([^/\\]+)$") or tostring(file)
                name = name:gsub("%.mp3$", "")
                table.insert(mp3List, {name = name, path = file})
            end
        end
    end
    updateMusicList()
end

-- ========== CRONÔMETRO ==========
local StopwatchFrame = Instance.new("Frame")
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

local swBezel = Instance.new("UIStroke")
swBezel.Color = Color3.fromRGB(50, 205, 50)
swBezel.Thickness = 6
swBezel.Parent = StopwatchFrame

local swEars = Instance.new("ImageLabel")
swEars.Size = UDim2.new(0, 340, 0, 95)
swEars.Position = UDim2.new(0.5, -170, 0, -48)
swEars.BackgroundTransparency = 1
swEars.Image = "rbxassetid://108135642658853"
swEars.ImageColor3 = Color3.fromRGB(50, 205, 50)
swEars.ZIndex = StopwatchFrame.ZIndex + 2
swEars.Parent = StopwatchFrame

local swNotch = Instance.new("Frame")
swNotch.Size = UDim2.new(0, 82, 0, 24)
swNotch.Position = UDim2.new(0.5, -41, 0, 9)
swNotch.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
swNotch.BorderSizePixel = 0
swNotch.Parent = StopwatchFrame
Instance.new("UICorner", swNotch).CornerRadius = UDim.new(1, 0)

local swTitle = Instance.new("TextLabel")
swTitle.Size = UDim2.new(1, 0, 0, 30)
swTitle.Position = UDim2.new(0, 0, 0, 50)
swTitle.BackgroundTransparency = 1
swTitle.Text = "⏱️ Cronômetro"
swTitle.TextColor3 = Color3.new(1, 1, 1)
swTitle.Font = Enum.Font.GothamBold
swTitle.TextSize = 20
swTitle.Parent = StopwatchFrame

local swTimeLabel = Instance.new("TextLabel")
swTimeLabel.Size = UDim2.new(1, -40, 0, 80)
swTimeLabel.Position = UDim2.new(0, 20, 0, 120)
swTimeLabel.BackgroundTransparency = 1
swTimeLabel.Text = "0:00:00:00.<font size=\"18\">00</font>"
swTimeLabel.TextColor3 = Color3.fromRGB(50, 205, 50)
swTimeLabel.Font = Enum.Font.Code
swTimeLabel.TextSize = 32
swTimeLabel.RichText = true
swTimeLabel.Parent = StopwatchFrame

local swStartBtn = Instance.new("TextButton")
swStartBtn.Size = UDim2.new(0, 100, 0, 50)
swStartBtn.Position = UDim2.new(0.5, -110, 0, 230)
swStartBtn.BackgroundColor3 = Color3.fromRGB(50, 205, 50)
swStartBtn.Text = "▶ Iniciar"
swStartBtn.TextColor3 = Color3.new(0, 0, 0)
swStartBtn.Font = Enum.Font.GothamBold
swStartBtn.TextSize = 16
swStartBtn.Parent = StopwatchFrame
Instance.new("UICorner", swStartBtn).CornerRadius = UDim.new(0, 14)

local swResetBtn = Instance.new("TextButton")
swResetBtn.Size = UDim2.new(0, 100, 0, 50)
swResetBtn.Position = UDim2.new(0.5, 10, 0, 230)
swResetBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
swResetBtn.Text = "↺ Reset"
swResetBtn.TextColor3 = Color3.new(1, 1, 1)
swResetBtn.Font = Enum.Font.GothamBold
swResetBtn.TextSize = 16
swResetBtn.Parent = StopwatchFrame
Instance.new("UICorner", swResetBtn).CornerRadius = UDim.new(0, 14)

local swNavBtn, swBackBtn = createNavBar(StopwatchFrame)

local swRunning = false
local swStartTime = 0
local swElapsed = 0
local swConnection = nil

local function formatStopwatch(t)
    local days = math.floor(t / 86400)
    local hours = math.floor((t % 86400) / 3600)
    local mins = math.floor((t % 3600) / 60)
    local secs = math.floor(t % 60)
    local ms = math.floor((t % 1) * 100)
    return string.format("%d:%02d:%02d:%02d.<font size=\"18\">%02d</font>", days, hours, mins, secs, ms)
end

local function updateStopwatchDisplay()
    if swRunning then
        local now = os.clock()
        swTimeLabel.Text = formatStopwatch(swElapsed + (now - swStartTime))
    else
        swTimeLabel.Text = formatStopwatch(swElapsed)
    end
end

swStartBtn.MouseButton1Click:Connect(function()
    if swRunning then
        swElapsed = swElapsed + (os.clock() - swStartTime)
        swRunning = false
        swStartBtn.Text = "▶ Iniciar"
        swStartBtn.BackgroundColor3 = Color3.fromRGB(50, 205, 50)
        if swConnection then swConnection:Disconnect() swConnection = nil end
    else
        swStartTime = os.clock()
        swRunning = true
        swStartBtn.Text = "⏸ Pausar"
        swStartBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 30)
        if swConnection then swConnection:Disconnect() end
        swConnection = RunService.RenderStepped:Connect(updateStopwatchDisplay)
    end
end)

swResetBtn.MouseButton1Click:Connect(function()
    swRunning = false
    swElapsed = 0
    swStartTime = 0
    swTimeLabel.Text = "0:00:00:00.<font size=\"18\">00</font>"
    swStartBtn.Text = "▶ Iniciar"
    swStartBtn.BackgroundColor3 = Color3.fromRGB(50, 205, 50)
    if swConnection then swConnection:Disconnect() swConnection = nil end
end)

-- ========== CONFIG ==========
local ConfigFrame = Instance.new("Frame")
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

local cfgBezel = Instance.new("UIStroke")
cfgBezel.Color = Color3.fromRGB(50, 205, 50)
cfgBezel.Thickness = 6
cfgBezel.Parent = ConfigFrame

local cfgEars = Instance.new("ImageLabel")
cfgEars.Size = UDim2.new(0, 340, 0, 95)
cfgEars.Position = UDim2.new(0.5, -170, 0, -48)
cfgEars.BackgroundTransparency = 1
cfgEars.Image = "rbxassetid://108135642658853"
cfgEars.ImageColor3 = Color3.fromRGB(50, 205, 50)
cfgEars.ZIndex = 10
cfgEars.Parent = ConfigFrame

local cfgTitle = Instance.new("TextLabel")
cfgTitle.Size = UDim2.new(1, 0, 0, 35)
cfgTitle.Position = UDim2.new(0, 0, 0, 45)
cfgTitle.BackgroundTransparency = 1
cfgTitle.Text = "⚙️ Configurações"
cfgTitle.TextColor3 = Color3.new(1,1,1)
cfgTitle.Font = Enum.Font.GothamBold
cfgTitle.TextSize = 20
cfgTitle.Parent = ConfigFrame

local cfgScroll = Instance.new("ScrollingFrame")
cfgScroll.Size = UDim2.new(1, -20, 1, -100)
cfgScroll.Position = UDim2.new(0, 10, 0, 85)
cfgScroll.BackgroundTransparency = 1
cfgScroll.ScrollBarThickness = 4
cfgScroll.Parent = ConfigFrame

local cfgLayout = Instance.new("UIListLayout")
cfgLayout.Padding = UDim.new(0, 10)
cfgLayout.Parent = cfgScroll

local function createConfigToggle(title, desc, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 70)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    frame.Parent = cfgScroll
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local titleL = Instance.new("TextLabel")
    titleL.Size = UDim2.new(1, -70, 0, 25)
    titleL.Position = UDim2.new(0, 12, 0, 8)
    titleL.BackgroundTransparency = 1
    titleL.Text = title
    titleL.TextColor3 = Color3.new(1,1,1)
    titleL.Font = Enum.Font.GothamBold
    titleL.TextSize = 14
    titleL.TextXAlignment = Enum.TextXAlignment.Left
    titleL.Parent = frame

    local descL = Instance.new("TextLabel")
    descL.Size = UDim2.new(1, -70, 0, 30)
    descL.Position = UDim2.new(0, 12, 0, 32)
    descL.BackgroundTransparency = 1
    descL.Text = desc
    descL.TextColor3 = Color3.fromRGB(160, 160, 170)
    descL.Font = Enum.Font.Gotham
    descL.TextSize = 11
    descL.TextXAlignment = Enum.TextXAlignment.Left
    descL.TextWrapped = true
    descL.Parent = frame

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 50, 0, 28)
    toggle.Position = UDim2.new(1, -60, 0.5, -14)
    toggle.BackgroundColor3 = default and Color3.fromRGB(50, 205, 50) or Color3.fromRGB(60, 60, 65)
    toggle.Text = default and "ON" or "OFF"
    toggle.TextColor3 = Color3.new(1,1,1)
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 12
    toggle.Parent = frame
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 14)

    local state = default
    toggle.MouseButton1Click:Connect(function()
        state = not state
        toggle.BackgroundColor3 = state and Color3.fromRGB(50, 205, 50) or Color3.fromRGB(60, 60, 65)
        toggle.Text = state and "ON" or "OFF"
        callback(state)
        saveSettings()
    end)
    return frame
end

createConfigToggle("FPS Counter", "Mostra o FPS na tela inicial do celular", phoneSettings.fpsEnabled, function(on)
    phoneSettings.fpsEnabled = on
    if fpsLabel then fpsLabel.Visible = on end
end)

createConfigToggle("Lanterna do Celular", "Liga uma luz fraca na frente do personagem", phoneSettings.flashlightEnabled, function(on)
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
end)

-- Wallpaper
local wallpaperFrame = Instance.new("Frame")
wallpaperFrame.Size = UDim2.new(1, 0, 0, 140)
wallpaperFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
wallpaperFrame.Parent = cfgScroll
Instance.new("UICorner", wallpaperFrame).CornerRadius = UDim.new(0, 12)

local wpTitle = Instance.new("TextLabel")
wpTitle.Size = UDim2.new(1, -20, 0, 25)
wpTitle.Position = UDim2.new(0, 12, 0, 8)
wpTitle.BackgroundTransparency = 1
wpTitle.Text = "🖼️ Wallpaper"
wpTitle.TextColor3 = Color3.new(1,1,1)
wpTitle.Font = Enum.Font.GothamBold
wpTitle.TextSize = 14
wpTitle.TextXAlignment = Enum.TextXAlignment.Left
wpTitle.Parent = wallpaperFrame

local wpInput = Instance.new("TextBox")
wpInput.Size = UDim2.new(1, -24, 0, 32)
wpInput.Position = UDim2.new(0, 12, 0, 40)
wpInput.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
wpInput.PlaceholderText = "rbxassetid:// ou ID numérico"
wpInput.Text = ""
wpInput.TextColor3 = Color3.new(1,1,1)
wpInput.Font = Enum.Font.Gotham
wpInput.TextSize = 12
wpInput.Parent = wallpaperFrame
Instance.new("UICorner", wpInput).CornerRadius = UDim.new(0, 8)

local wpApplyBtn = Instance.new("TextButton")
wpApplyBtn.Size = UDim2.new(0.48, -8, 0, 36)
wpApplyBtn.Position = UDim2.new(0, 12, 0, 82)
wpApplyBtn.BackgroundColor3 = Color3.fromRGB(50, 205, 50)
wpApplyBtn.Text = "Aplicar ID"
wpApplyBtn.TextColor3 = Color3.new(0,0,0)
wpApplyBtn.Font = Enum.Font.GothamBold
wpApplyBtn.TextSize = 13
wpApplyBtn.Parent = wallpaperFrame
Instance.new("UICorner", wpApplyBtn).CornerRadius = UDim.new(0, 8)

local wpResetBtn = Instance.new("TextButton")
wpResetBtn.Size = UDim2.new(0.48, -8, 0, 36)
wpResetBtn.Position = UDim2.new(0.52, 0, 0, 82)
wpResetBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
wpResetBtn.Text = "Padrão"
wpResetBtn.TextColor3 = Color3.new(1,1,1)
wpResetBtn.Font = Enum.Font.GothamBold
wpResetBtn.TextSize = 13
wpResetBtn.Parent = wallpaperFrame
Instance.new("UICorner", wpResetBtn).CornerRadius = UDim.new(0, 8)

local function applyWallpaper(id)
    if not id or id == "" then return end
    if not id:find("rbxassetid://") then
        id = "rbxassetid://" .. id:gsub("%D", "")
    end
    currentWallpaper = id
    phoneSettings.wallpaper = id
    homeBg.Image = id
    saveSettings()
end

wpApplyBtn.MouseButton1Click:Connect(function()
    applyWallpaper(wpInput.Text)
end)

wpResetBtn.MouseButton1Click:Connect(function()
    applyWallpaper(defaultSettings.wallpaper)
    wpInput.Text = ""
end)

-- Server Info
local serverInfoFrame = Instance.new("Frame")
serverInfoFrame.Size = UDim2.new(1, 0, 0, 110)
serverInfoFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
serverInfoFrame.Parent = cfgScroll
Instance.new("UICorner", serverInfoFrame).CornerRadius = UDim.new(0, 12)

local serverTitle = Instance.new("TextLabel")
serverTitle.Size = UDim2.new(1, -20, 0, 25)
serverTitle.Position = UDim2.new(0, 12, 0, 8)
serverTitle.BackgroundTransparency = 1
serverTitle.Text = "📡 Info do Servidor"
serverTitle.TextColor3 = Color3.new(1,1,1)
serverTitle.Font = Enum.Font.GothamBold
serverTitle.TextSize = 14
serverTitle.TextXAlignment = Enum.TextXAlignment.Left
serverTitle.Parent = serverInfoFrame

local serverInfoLabel = Instance.new("TextLabel")
serverInfoLabel.Size = UDim2.new(1, -24, 0, 70)
serverInfoLabel.Position = UDim2.new(0, 12, 0, 35)
serverInfoLabel.BackgroundTransparency = 1
serverInfoLabel.Text = "Carregando..."
serverInfoLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
serverInfoLabel.Font = Enum.Font.Code
serverInfoLabel.TextSize = 13
serverInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
serverInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
serverInfoLabel.TextWrapped = true
serverInfoLabel.Parent = serverInfoFrame

task.spawn(function()
    while true do
        local playersCount = #Players:GetPlayers()
        local maxPlayers = Players.MaxPlayers
        local onlineTime = os.clock() - (phoneSettings.joinTime or os.clock())
        local mins = math.floor(onlineTime / 60)
        local secs = math.floor(onlineTime % 60)
        local ping = 0
        pcall(function()
            ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        local serverType = (game.JobId ~= "" and game.PrivateServerId ~= "") and "Privado" or "Público"
        serverInfoLabel.Text = string.format(
            "Players: %d / %d\nTempo Online: %02d:%02d\nPing: %d ms\nServer: %s",
            playersCount, maxPlayers, mins, secs, ping, serverType
        )
        task.wait(2)
    end
end)

cfgScroll.CanvasSize = UDim2.new(0, 0, 0, cfgLayout.AbsoluteContentSize.Y + 20)
cfgLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    cfgScroll.CanvasSize = UDim2.new(0, 0, 0, cfgLayout.AbsoluteContentSize.Y + 20)
end)

local cfgNavBtn, cfgBackBtn = createNavBar(ConfigFrame)

-- ========== GALERIA ==========
local GalleryFrame = Instance.new("Frame")
GalleryFrame.Name = "GalleryFrame"
GalleryFrame.Size = UDim2.new(0, 280, 0, 440)
GalleryFrame.Position = PhoneHome.Position
GalleryFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
GalleryFrame.BorderSizePixel = 0
GalleryFrame.Visible = false
GalleryFrame.Active = true
GalleryFrame.Draggable = false
GalleryFrame.Parent = ScreenGui
Instance.new("UICorner", GalleryFrame).CornerRadius = UDim.new(0, 28)

local galBezel = Instance.new("UIStroke")
galBezel.Color = Color3.fromRGB(50, 205, 50)
galBezel.Thickness = 6
galBezel.Parent = GalleryFrame

local galEars = Instance.new("ImageLabel")
galEars.Size = UDim2.new(0, 340, 0, 95)
galEars.Position = UDim2.new(0.5, -170, 0, -48)
galEars.BackgroundTransparency = 1
galEars.Image = "rbxassetid://108135642658853"
galEars.ImageColor3 = Color3.fromRGB(50, 205, 50)
galEars.ZIndex = GalleryFrame.ZIndex + 2
galEars.Parent = GalleryFrame

local galNotch = Instance.new("Frame")
galNotch.Size = UDim2.new(0, 82, 0, 24)
galNotch.Position = UDim2.new(0.5, -41, 0, 9)
galNotch.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
galNotch.BorderSizePixel = 0
galNotch.Parent = GalleryFrame
Instance.new("UICorner", galNotch).CornerRadius = UDim.new(1, 0)

local galTitle = Instance.new("TextLabel")
galTitle.Size = UDim2.new(1, 0, 0, 30)
galTitle.Position = UDim2.new(0, 0, 0, 42)
galTitle.BackgroundTransparency = 1
galTitle.Text = "🖼️ Galeria"
galTitle.TextColor3 = Color3.new(1, 1, 1)
galTitle.Font = Enum.Font.GothamBold
galTitle.TextSize = 20
galTitle.Parent = GalleryFrame

local PhotoSearchBox = Instance.new("TextBox")
PhotoSearchBox.Size = UDim2.new(1, -24, 0, 32)
PhotoSearchBox.Position = UDim2.new(0, 12, 0, 80)
PhotoSearchBox.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
PhotoSearchBox.PlaceholderText = "🔍 Pesquisar foto..."
PhotoSearchBox.Text = ""
PhotoSearchBox.TextColor3 = Color3.new(1, 1, 1)
PhotoSearchBox.Font = Enum.Font.Gotham
PhotoSearchBox.TextSize = 13
PhotoSearchBox.Parent = GalleryFrame
Instance.new("UICorner", PhotoSearchBox).CornerRadius = UDim.new(0, 10)

local PhotoScrollList = Instance.new("ScrollingFrame")
PhotoScrollList.Size = UDim2.new(1, -24, 0, 280)
PhotoScrollList.Position = UDim2.new(0, 12, 0, 120)
PhotoScrollList.BackgroundTransparency = 1
PhotoScrollList.ScrollBarThickness = 3
PhotoScrollList.ScrollBarImageColor3 = Color3.fromRGB(50, 205, 50)
PhotoScrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
PhotoScrollList.Parent = GalleryFrame

local PhotoUIGridLayout = Instance.new("UIGridLayout")
PhotoUIGridLayout.CellSize = UDim2.new(0, 58, 0, 58)
PhotoUIGridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
PhotoUIGridLayout.FillDirection = Enum.FillDirection.Horizontal
PhotoUIGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
PhotoUIGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
PhotoUIGridLayout.Parent = PhotoScrollList

local PhotoViewerView = Instance.new("Frame")
PhotoViewerView.Name = "PhotoViewerView"
PhotoViewerView.Size = UDim2.new(1, 0, 1, 0)
PhotoViewerView.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
PhotoViewerView.BorderSizePixel = 0
PhotoViewerView.Visible = false
PhotoViewerView.Parent = GalleryFrame
Instance.new("UICorner", PhotoViewerView).CornerRadius = UDim.new(0, 28)

local PhotoDisplay = Instance.new("ImageLabel")
PhotoDisplay.Name = "PhotoDisplay"
PhotoDisplay.Size = UDim2.new(1, -16, 1, -100)
PhotoDisplay.Position = UDim2.new(0, 8, 0, 40)
PhotoDisplay.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
PhotoDisplay.BackgroundTransparency = 0.3
PhotoDisplay.BorderSizePixel = 0
PhotoDisplay.ScaleType = Enum.ScaleType.Fit
PhotoDisplay.Parent = PhotoViewerView
Instance.new("UICorner", PhotoDisplay).CornerRadius = UDim.new(0, 12)

-- Zoom com pinça (mobile)
local currentZoom = 1
local pinchStartDist = nil
UserInputService.TouchStarted:Connect(function(input, processed)
    if not isInPhotoViewer or not PhotoViewerView.Visible then return end
end)

UserInputService.TouchMoved:Connect(function(input, processed)
    if not isInPhotoViewer or not PhotoViewerView.Visible then return end
    local touches = UserInputService:GetTouches()
    if #touches >= 2 then
        local t1, t2 = touches[1], touches[2]
        local dist = (t1.Position - t2.Position).Magnitude
        if not pinchStartDist then
            pinchStartDist = dist
        else
            local scale = dist / pinchStartDist
            currentZoom = math.clamp(currentZoom * (scale > 1 and 1.02 or 0.98), 0.5, 3)
            PhotoDisplay.Size = UDim2.new(currentZoom, -16, currentZoom, -100)
            PhotoDisplay.Position = UDim2.new(0.5 - currentZoom/2, 8, 0.5 - currentZoom/2, 40)
        end
    end
end)

UserInputService.TouchEnded:Connect(function()
    pinchStartDist = nil
end)

-- Botão clássico 3 pontinhos (menu)
local isPhotoMenuOpen = false

local PhotoMenuBtn = Instance.new("TextButton")
PhotoMenuBtn.Name = "PhotoMenuBtn"
PhotoMenuBtn.Size = UDim2.new(0, 36, 0, 36)
PhotoMenuBtn.Position = UDim2.new(1, -48, 0, 42)
PhotoMenuBtn.BackgroundTransparency = 1
PhotoMenuBtn.Text = "┇"
PhotoMenuBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
PhotoMenuBtn.Font = Enum.Font.GothamBold
PhotoMenuBtn.TextSize = 22
PhotoMenuBtn.ZIndex = 25
PhotoMenuBtn.Parent = PhotoViewerView

-- Menu (branco sujo + detalhes pretos) com scroll
local PhotoMenuFrame = Instance.new("Frame")
PhotoMenuFrame.Name = "PhotoMenuFrame"
PhotoMenuFrame.Size = UDim2.new(0, 200, 0, 170)
PhotoMenuFrame.Position = UDim2.new(1, -215, 0, 82)
PhotoMenuFrame.BackgroundColor3 = Color3.fromRGB(245, 243, 236) -- branco sujo
PhotoMenuFrame.BorderSizePixel = 0
PhotoMenuFrame.Visible = false
PhotoMenuFrame.ZIndex = 30
PhotoMenuFrame.Parent = PhotoViewerView
Instance.new("UICorner", PhotoMenuFrame).CornerRadius = UDim.new(0, 12)

local photoMenuStroke = Instance.new("UIStroke")
photoMenuStroke.Color = Color3.fromRGB(20, 20, 20)
photoMenuStroke.Thickness = 1.5
photoMenuStroke.Parent = PhotoMenuFrame

local PhotoMenuScroll = Instance.new("ScrollingFrame")
PhotoMenuScroll.Name = "PhotoMenuScroll"
PhotoMenuScroll.Size = UDim2.new(1, -10, 1, -10)
PhotoMenuScroll.Position = UDim2.new(0, 5, 0, 5)
PhotoMenuScroll.BackgroundTransparency = 1
PhotoMenuScroll.BorderSizePixel = 0
PhotoMenuScroll.ScrollBarThickness = 4
PhotoMenuScroll.ScrollBarImageColor3 = Color3.fromRGB(20, 20, 20)
PhotoMenuScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
PhotoMenuScroll.ZIndex = 31
PhotoMenuScroll.Parent = PhotoMenuFrame

local PhotoMenuLayout = Instance.new("UIListLayout")
PhotoMenuLayout.Padding = UDim.new(0, 6)
PhotoMenuLayout.SortOrder = Enum.SortOrder.LayoutOrder
PhotoMenuLayout.Parent = PhotoMenuScroll

-- Nome da foto (dentro do menu)
local PhotoMenuNameLabel = Instance.new("TextLabel")
PhotoMenuNameLabel.Name = "PhotoMenuName"
PhotoMenuNameLabel.Size = UDim2.new(1, 0, 0, 40)
PhotoMenuNameLabel.BackgroundColor3 = Color3.fromRGB(235, 232, 224)
PhotoMenuNameLabel.BorderSizePixel = 0
PhotoMenuNameLabel.Text = ""
PhotoMenuNameLabel.TextColor3 = Color3.fromRGB(15, 15, 15)
PhotoMenuNameLabel.Font = Enum.Font.GothamBold
PhotoMenuNameLabel.TextSize = 13
PhotoMenuNameLabel.TextWrapped = true
PhotoMenuNameLabel.TextXAlignment = Enum.TextXAlignment.Center
PhotoMenuNameLabel.TextYAlignment = Enum.TextYAlignment.Center
PhotoMenuNameLabel.ZIndex = 32
PhotoMenuNameLabel.LayoutOrder = 1
PhotoMenuNameLabel.Parent = PhotoMenuScroll
Instance.new("UICorner", PhotoMenuNameLabel).CornerRadius = UDim.new(0, 8)

local function createMenuOption(text, order, bgColor, textColor)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = bgColor
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = textColor
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.ZIndex = 32
    btn.LayoutOrder = order
    btn.Parent = PhotoMenuScroll
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    return btn
end

local setWallpaperMenuBtn = createMenuOption("🖼️ Definir como Wallpaper", 2, Color3.fromRGB(30, 30, 30), Color3.fromRGB(245, 243, 236))
local deletePhotoMenuBtn = createMenuOption("🗑️ Excluir foto", 3, Color3.fromRGB(160, 30, 30), Color3.fromRGB(255, 255, 255))

PhotoMenuLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    PhotoMenuScroll.CanvasSize = UDim2.new(0, 0, 0, PhotoMenuLayout.AbsoluteContentSize.Y + 8)
end)

local function closePhotoMenu()
    isPhotoMenuOpen = false
    PhotoMenuFrame.Visible = false
end

local function togglePhotoMenu()
    isPhotoMenuOpen = not isPhotoMenuOpen
    PhotoMenuFrame.Visible = isPhotoMenuOpen
end

PhotoMenuBtn.MouseButton1Click:Connect(function()
    togglePhotoMenu()
end)

local prevPhotoBtn = Instance.new("TextButton")
prevPhotoBtn.Size = UDim2.new(0, 70, 0, 36)
prevPhotoBtn.Position = UDim2.new(0, 20, 1, -55)
prevPhotoBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
prevPhotoBtn.Text = "◀ Anterior"
prevPhotoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
prevPhotoBtn.Font = Enum.Font.GothamBold
prevPhotoBtn.TextSize = 13
prevPhotoBtn.Parent = PhotoViewerView
Instance.new("UICorner", prevPhotoBtn).CornerRadius = UDim.new(0, 10)

local nextPhotoBtn = Instance.new("TextButton")
nextPhotoBtn.Size = UDim2.new(0, 70, 0, 36)
nextPhotoBtn.Position = UDim2.new(1, -90, 1, -55)
nextPhotoBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
nextPhotoBtn.Text = "Próxima ▶"
nextPhotoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
nextPhotoBtn.Font = Enum.Font.GothamBold
nextPhotoBtn.TextSize = 13
nextPhotoBtn.Parent = PhotoViewerView
Instance.new("UICorner", nextPhotoBtn).CornerRadius = UDim.new(0, 10)

local galNavBtn, galBackBtn = createNavBar(GalleryFrame)

local function exitPhotoViewer()
    isInPhotoViewer = false
    closePhotoMenu()
    PhotoViewerView.Visible = false
    PhotoScrollList.Visible = true
    PhotoSearchBox.Visible = true
    galTitle.Visible = true
    PhotoDisplay.Image = ""
    PhotoMenuNameLabel.Text = ""
    currentPhotoIndex = 0
    currentZoom = 1
    PhotoDisplay.Size = UDim2.new(1, -16, 1, -100)
    PhotoDisplay.Position = UDim2.new(0, 8, 0, 40)
end

local function openPhotoByIndex(idx)
    if #filteredPhotoList == 0 then return end
    if idx < 1 then idx = #filteredPhotoList end
    if idx > #filteredPhotoList then idx = 1 end
    currentPhotoIndex = idx
    local photo = filteredPhotoList[idx]
    isInPhotoViewer = true
    closePhotoMenu()
    PhotoViewerView.Visible = true
    PhotoScrollList.Visible = false
    PhotoSearchBox.Visible = false
    galTitle.Visible = false
    PhotoMenuNameLabel.Text = (photo.name or "Foto") .. "\n(" .. idx .. "/" .. #filteredPhotoList .. ")"
    currentZoom = 1
    PhotoDisplay.Size = UDim2.new(1, -16, 1, -100)
    PhotoDisplay.Position = UDim2.new(0, 8, 0, 40)

    local success, asset = pcall(function()
        return getcustomasset(photo.path)
    end)
    if success and asset and asset ~= "" then
        PhotoDisplay.Image = asset
    else
        PhotoMenuNameLabel.Text = "Erro ao carregar foto"
        PhotoDisplay.Image = ""
    end
end

prevPhotoBtn.MouseButton1Click:Connect(function()
    if #filteredPhotoList > 0 then openPhotoByIndex(currentPhotoIndex - 1) end
end)
nextPhotoBtn.MouseButton1Click:Connect(function()
    if #filteredPhotoList > 0 then openPhotoByIndex(currentPhotoIndex + 1) end
end)

-- Excluir foto (do menu)
deletePhotoMenuBtn.MouseButton1Click:Connect(function()
    if #filteredPhotoList == 0 or currentPhotoIndex < 1 then return end
    local photo = filteredPhotoList[currentPhotoIndex]
    pcall(function()
        delfile(photo.path)
    end)
    for i, p in ipairs(photoList) do
        if p.path == photo.path then
            table.remove(photoList, i)
            break
        end
    end
    closePhotoMenu()
    exitPhotoViewer()
    task.wait(0.1)
    updatePhotoList()
end)

-- Definir foto atual como wallpaper
setWallpaperMenuBtn.MouseButton1Click:Connect(function()
    if #filteredPhotoList == 0 or currentPhotoIndex < 1 then return end
    local photo = filteredPhotoList[currentPhotoIndex]
    local success, asset = pcall(function()
        return getcustomasset(photo.path)
    end)
    if success and asset and asset ~= "" then
        currentWallpaper = asset
        phoneSettings.wallpaper = asset
        homeBg.Image = asset
        saveSettings()
        closePhotoMenu()
    end
end)

local function updatePhotoList()
    for _, v in pairs(PhotoScrollList:GetChildren()) do
        if v:IsA("Frame") or v:IsA("ImageButton") then v:Destroy() end
    end
    local searchText = PhotoSearchBox.Text:lower()
    filteredPhotoList = {}
    for _, photo in ipairs(photoList) do
        if searchText == "" or photo.name:lower():match(searchText) then
            table.insert(filteredPhotoList, photo)
        end
    end
    if #filteredPhotoList == 0 then
        local emptyFrame = Instance.new("Frame")
        emptyFrame.Size = UDim2.new(1, 0, 0, 50)
        emptyFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        emptyFrame.Parent = PhotoScrollList
        Instance.new("UICorner", emptyFrame).CornerRadius = UDim.new(0, 10)
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Size = UDim2.new(1, 0, 1, 0)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Text = searchText == "" and "📁 Coloque fotos em PHONE/Photos" or "🔍 Nenhuma foto encontrada"
        emptyLabel.TextColor3 = Color3.fromRGB(130, 130, 150)
        emptyLabel.TextSize = 12
        emptyLabel.Parent = emptyFrame
    else
        for idx, photo in ipairs(filteredPhotoList) do
            local thumbBtn = Instance.new("ImageButton")
            thumbBtn.Size = UDim2.new(0, 58, 0, 58)
            thumbBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
            thumbBtn.BorderSizePixel = 0
            thumbBtn.ScaleType = Enum.ScaleType.Crop
            thumbBtn.AutoButtonColor = false
            thumbBtn.Parent = PhotoScrollList
            Instance.new("UICorner", thumbBtn).CornerRadius = UDim.new(0, 10)
            pcall(function()
                local asset = getcustomasset(photo.path)
                if asset then thumbBtn.Image = asset end
            end)
            thumbBtn.MouseButton1Click:Connect(function()
                openPhotoByIndex(idx)
            end)
        end
    end
    task.wait()
    PhotoScrollList.CanvasSize = UDim2.new(0, 0, 0, PhotoUIGridLayout.AbsoluteContentSize.Y + 10)
end

local function refreshPhotos()
    photoList = {}
    local paths = {"PHONE/Photos/", "PHONE/Photos", "PHONE\\Photos", "Photos/", "Photos"}
    local files = nil
    local success = false
    for _, p in ipairs(paths) do
        success, files = pcall(function() return listfiles(p) end)
        if success and type(files) == "table" and #files > 0 then break end
    end
    if success and type(files) == "table" then
        for _, file in ipairs(files) do
            local str = tostring(file)
            local lower = str:lower()
            if lower:match("%.png$") or lower:match("%.jpg$") or lower:match("%.jpeg$") or lower:match("%.webp$") or lower:match("%.bmp$") or lower:match("%.gif$") then
                local name = str:match("([^/\\]+)$") or str
                name = name:gsub("%.%w+$", "")
                table.insert(photoList, {name = name, path = file})
            end
        end
    end
    updatePhotoList()
end

PhotoSearchBox.Changed:Connect(function(prop)
    if prop == "Text" then updatePhotoList() end
end)


-- ========== MAPA / GPS ==========
local GuiService = game:GetService("GuiService")
local MAP_SIZE = 230
local MAP_CENTER = MAP_SIZE / 2
local mapRanges = {50, 100, 200, 400, 800}
local mapRangeIdx = 3
local mapWaypoint = nil
local mapArrivedUntil = 0

local MapFrame = Instance.new("Frame")
MapFrame.Name = "MapFrame"
MapFrame.Size = UDim2.new(0, 280, 0, 440)
MapFrame.Position = PhoneHome.Position
MapFrame.BackgroundColor3 = Color3.fromRGB(14, 16, 15)
MapFrame.BorderSizePixel = 0
MapFrame.Visible = false
MapFrame.Active = true
MapFrame.Draggable = false
MapFrame.Parent = ScreenGui
Instance.new("UICorner", MapFrame).CornerRadius = UDim.new(0, 28)

local mapBezel = Instance.new("UIStroke")
mapBezel.Color = Color3.fromRGB(50, 205, 50)
mapBezel.Thickness = 6
mapBezel.Parent = MapFrame

local mapEars = Instance.new("ImageLabel")
mapEars.Size = UDim2.new(0, 340, 0, 95)
mapEars.Position = UDim2.new(0.5, -170, 0, -48)
mapEars.BackgroundTransparency = 1
mapEars.Image = "rbxassetid://108135642658853"
mapEars.ImageColor3 = Color3.fromRGB(50, 205, 50)
mapEars.ZIndex = MapFrame.ZIndex + 2
mapEars.Parent = MapFrame

local mapNotch = Instance.new("Frame")
mapNotch.Size = UDim2.new(0, 82, 0, 24)
mapNotch.Position = UDim2.new(0.5, -41, 0, 9)
mapNotch.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
mapNotch.BorderSizePixel = 0
mapNotch.Parent = MapFrame
Instance.new("UICorner", mapNotch).CornerRadius = UDim.new(1, 0)

local mapTitle = Instance.new("TextLabel")
mapTitle.Size = UDim2.new(1, 0, 0, 26)
mapTitle.Position = UDim2.new(0, 0, 0, 46)
mapTitle.BackgroundTransparency = 1
mapTitle.Text = "🗺️ GPS"
mapTitle.TextColor3 = Color3.new(1, 1, 1)
mapTitle.Font = Enum.Font.GothamBold
mapTitle.TextSize = 20
mapTitle.Parent = MapFrame

local mapCoords = Instance.new("TextLabel")
mapCoords.Size = UDim2.new(1, -20, 0, 18)
mapCoords.Position = UDim2.new(0, 10, 0, 76)
mapCoords.BackgroundTransparency = 1
mapCoords.Text = "X 0  Y 0  Z 0"
mapCoords.TextColor3 = Color3.fromRGB(50, 205, 50)
mapCoords.Font = Enum.Font.Code
mapCoords.TextSize = 12
mapCoords.Parent = MapFrame

local MapArea = Instance.new("Frame")
MapArea.Name = "MapArea"
MapArea.Size = UDim2.new(0, MAP_SIZE, 0, MAP_SIZE)
MapArea.Position = UDim2.new(0.5, -MAP_CENTER, 0, 100)
MapArea.BackgroundColor3 = Color3.fromRGB(18, 27, 21)
MapArea.BorderSizePixel = 0
MapArea.ClipsDescendants = true
MapArea.Active = true
MapArea.Parent = MapFrame
Instance.new("UICorner", MapArea).CornerRadius = UDim.new(0, 18)
local mapAreaStroke = Instance.new("UIStroke")
mapAreaStroke.Color = Color3.fromRGB(50, 205, 50)
mapAreaStroke.Thickness = 2
mapAreaStroke.Parent = MapArea

local gridV, gridH = {}, {}
for i = 1, 12 do
    local v = Instance.new("Frame")
    v.Size = UDim2.new(0, 1, 1, 0)
    v.BackgroundColor3 = Color3.new(1, 1, 1)
    v.BackgroundTransparency = 0.9
    v.BorderSizePixel = 0
    v.Visible = false
    v.ZIndex = 2
    v.Parent = MapArea
    gridV[i] = v

    local h = Instance.new("Frame")
    h.Size = UDim2.new(1, 0, 0, 1)
    h.BackgroundColor3 = Color3.new(1, 1, 1)
    h.BackgroundTransparency = 0.9
    h.BorderSizePixel = 0
    h.Visible = false
    h.ZIndex = 2
    h.Parent = MapArea
    gridH[i] = h
end

local mapRing = Instance.new("Frame")
mapRing.AnchorPoint = Vector2.new(0.5, 0.5)
mapRing.Position = UDim2.new(0, MAP_CENTER, 0, MAP_CENTER)
mapRing.Size = UDim2.new(0, MAP_SIZE / 2, 0, MAP_SIZE / 2)
mapRing.BackgroundTransparency = 1
mapRing.ZIndex = 3
mapRing.Parent = MapArea
Instance.new("UICorner", mapRing).CornerRadius = UDim.new(1, 0)
local mapRingStroke = Instance.new("UIStroke")
mapRingStroke.Color = Color3.new(1, 1, 1)
mapRingStroke.Transparency = 0.75
mapRingStroke.Thickness = 1
mapRingStroke.Parent = mapRing

local mapNorth = Instance.new("TextLabel")
mapNorth.Size = UDim2.new(0, 20, 0, 16)
mapNorth.Position = UDim2.new(0.5, -10, 0, 3)
mapNorth.BackgroundTransparency = 1
mapNorth.Text = "N"
mapNorth.TextColor3 = Color3.fromRGB(255, 90, 90)
mapNorth.Font = Enum.Font.GothamBold
mapNorth.TextSize = 13
mapNorth.ZIndex = 9
mapNorth.Parent = MapArea

local mapRangeLabel = Instance.new("TextLabel")
mapRangeLabel.Size = UDim2.new(0, 90, 0, 14)
mapRangeLabel.Position = UDim2.new(0, 6, 1, -17)
mapRangeLabel.BackgroundTransparency = 1
mapRangeLabel.Text = "Raio: 200 studs"
mapRangeLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
mapRangeLabel.Font = Enum.Font.Gotham
mapRangeLabel.TextSize = 10
mapRangeLabel.TextXAlignment = Enum.TextXAlignment.Left
mapRangeLabel.ZIndex = 9
mapRangeLabel.Parent = MapArea

local wpLine = Instance.new("Frame")
wpLine.AnchorPoint = Vector2.new(0, 0.5)
wpLine.Position = UDim2.new(0, MAP_CENTER, 0, MAP_CENTER)
wpLine.Size = UDim2.new(0, 0, 0, 2)
wpLine.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
wpLine.BackgroundTransparency = 0.2
wpLine.BorderSizePixel = 0
wpLine.Visible = false
wpLine.ZIndex = 4
wpLine.Parent = MapArea

local wpMarker = Instance.new("TextLabel")
wpMarker.AnchorPoint = Vector2.new(0.5, 1)
wpMarker.Size = UDim2.new(0, 24, 0, 24)
wpMarker.BackgroundTransparency = 1
wpMarker.Text = "📍"
wpMarker.TextSize = 20
wpMarker.Visible = false
wpMarker.ZIndex = 8
wpMarker.Parent = MapArea

local meArrow = Instance.new("TextLabel")
meArrow.AnchorPoint = Vector2.new(0.5, 0.5)
meArrow.Position = UDim2.new(0, MAP_CENTER, 0, MAP_CENTER)
meArrow.Size = UDim2.new(0, 22, 0, 22)
meArrow.BackgroundTransparency = 1
meArrow.Text = "▲"
meArrow.TextColor3 = Color3.fromRGB(50, 205, 50)
meArrow.Font = Enum.Font.GothamBold
meArrow.TextSize = 20
meArrow.TextStrokeTransparency = 0.3
meArrow.ZIndex = 10
meArrow.Parent = MapArea

local wpInfo = Instance.new("TextLabel")
wpInfo.Size = UDim2.new(1, -20, 0, 20)
wpInfo.Position = UDim2.new(0, 10, 0, 334)
wpInfo.BackgroundTransparency = 1
wpInfo.Text = "Toque no mapa para marcar um destino"
wpInfo.TextColor3 = Color3.fromRGB(220, 220, 220)
wpInfo.Font = Enum.Font.GothamMedium
wpInfo.TextSize = 12
wpInfo.Parent = MapFrame

local function createMapButton(text, x, w, bg, fg)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 32)
    b.Position = UDim2.new(0, x, 0, 358)
    b.BackgroundColor3 = bg
    b.Text = text
    b.TextColor3 = fg
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.Parent = MapFrame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
    return b
end

local mapZoomOut = createMapButton("−", 20, 60, Color3.fromRGB(40, 40, 45), Color3.new(1, 1, 1))
local mapZoomIn = createMapButton("+", 90, 60, Color3.fromRGB(40, 40, 45), Color3.new(1, 1, 1))
local mapClearBtn = createMapButton("✖ Limpar", 160, 100, Color3.fromRGB(50, 205, 50), Color3.new(0, 0, 0))
mapClearBtn.TextSize = 14

local mapNavBtn, mapBackBtn = createNavBar(MapFrame)

-- bolinhas dos outros jogadores
local mapDots = {}
local function getMapDot(plr)
    local d = mapDots[plr]
    if d then return d end
    local dot = Instance.new("Frame")
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Size = UDim2.new(0, 9, 0, 9)
    dot.BackgroundColor3 = Color3.new(1, 1, 1)
    dot.BorderSizePixel = 0
    dot.ZIndex = 6
    dot.Parent = MapArea
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.AnchorPoint = Vector2.new(0.5, 0)
    nameLbl.Size = UDim2.new(0, 70, 0, 12)
    nameLbl.Position = UDim2.new(0.5, 0, 1, 1)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = plr.DisplayName
    nameLbl.TextColor3 = Color3.new(1, 1, 1)
    nameLbl.TextStrokeTransparency = 0.4
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 9
    nameLbl.ZIndex = 7
    nameLbl.Parent = dot

    d = {dot = dot, name = nameLbl}
    mapDots[plr] = d
    return d
end

local function formatEta(sec)
    sec = math.floor(sec + 0.5)
    if sec < 60 then return sec .. "s" end
    return string.format("%dm %02ds", math.floor(sec / 60), sec % 60)
end

local function updateMap()
    local root = Character and Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local range = mapRanges[mapRangeIdx]
    local pps = MAP_CENTER / range
    local me = root.Position

    mapCoords.Text = string.format("X %d   Y %d   Z %d", math.floor(me.X + 0.5), math.floor(me.Y + 0.5), math.floor(me.Z + 0.5))
    mapRangeLabel.Text = "Raio: " .. range .. " studs"

    local look = root.CFrame.LookVector
    meArrow.Rotation = math.deg(math.atan2(look.X, -look.Z))

    -- grade que "anda" com o personagem
    local grid = range / 4
    local startX = math.floor((me.X - range) / grid)
    local startZ = math.floor((me.Z - range) / grid)
    for i = 1, #gridV do
        local px = MAP_CENTER + ((startX + i - 1) * grid - me.X) * pps
        local pz = MAP_CENTER + ((startZ + i - 1) * grid - me.Z) * pps
        local v, h = gridV[i], gridH[i]
        if px >= 0 and px <= MAP_SIZE then
            v.Position = UDim2.new(0, px, 0, 0)
            v.Visible = true
        else
            v.Visible = false
        end
        if pz >= 0 and pz <= MAP_SIZE then
            h.Position = UDim2.new(0, 0, 0, pz)
            h.Visible = true
        else
            h.Visible = false
        end
    end

    -- outros jogadores
    local seen = {}
    local maxR = MAP_CENTER - 6
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player then
            local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if r then
                seen[plr] = true
                local d = getMapDot(plr)
                local dx = (r.Position.X - me.X) * pps
                local dz = (r.Position.Z - me.Z) * pps
                local dist = math.sqrt(dx * dx + dz * dz)
                local outside = dist > maxR
                if outside then
                    dx, dz = dx / dist * maxR, dz / dist * maxR
                end
                d.dot.Position = UDim2.new(0, MAP_CENTER + dx, 0, MAP_CENTER + dz)
                d.dot.BackgroundTransparency = outside and 0.65 or 0
                d.dot.BackgroundColor3 = plr.Team and plr.TeamColor.Color or Color3.new(1, 1, 1)
                d.name.Visible = not outside
                d.dot.Visible = true
            end
        end
    end
    for plr, d in pairs(mapDots) do
        if not seen[plr] then
            d.dot:Destroy()
            mapDots[plr] = nil
        end
    end

    -- waypoint
    if mapWaypoint then
        local dx = mapWaypoint.X - me.X
        local dz = mapWaypoint.Z - me.Z
        local studs = math.sqrt(dx * dx + dz * dz)
        local px, pz = dx * pps, dz * pps
        local pd = math.sqrt(px * px + pz * pz)
        local edge = MAP_CENTER - 8
        local cx, cz = px, pz
        if pd > edge then
            cx, cz = px / pd * edge, pz / pd * edge
        end
        wpMarker.Position = UDim2.new(0, MAP_CENTER + cx, 0, MAP_CENTER + cz)
        wpMarker.Visible = true
        wpLine.Size = UDim2.new(0, math.min(pd, edge), 0, 2)
        wpLine.Rotation = math.deg(math.atan2(pz, px))
        wpLine.Visible = pd > 4
        local speed = (Humanoid and Humanoid.WalkSpeed) or 16
        wpInfo.Text = string.format("📍 %d studs  •  ~%s", math.floor(studs + 0.5), formatEta(studs / math.max(speed, 1)))
        if studs < 5 then
            mapWaypoint = nil
            mapArrivedUntil = os.clock() + 3
        end
    else
        wpMarker.Visible = false
        wpLine.Visible = false
        if os.clock() < mapArrivedUntil then
            wpInfo.Text = "Você chegou ao destino! 🎉"
        else
            wpInfo.Text = "Toque no mapa para marcar um destino"
        end
    end
end

RunService.RenderStepped:Connect(function()
    if MapFrame.Visible then
        pcall(updateMap)
    end
end)

MapArea.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local root = Character and Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local inset = GuiService:GetGuiInset()
    local abs = Vector2.new(input.Position.X + inset.X, input.Position.Y + inset.Y)
    local frac = (abs - MapArea.AbsolutePosition) / MapArea.AbsoluteSize
    local range = mapRanges[mapRangeIdx]
    local pps = MAP_CENTER / range
    local ox = (frac.X * MAP_SIZE - MAP_CENTER) / pps
    local oz = (frac.Y * MAP_SIZE - MAP_CENTER) / pps
    mapWaypoint = Vector3.new(root.Position.X + ox, root.Position.Y, root.Position.Z + oz)
end)

mapZoomIn.MouseButton1Click:Connect(function()
    mapRangeIdx = math.max(1, mapRangeIdx - 1)
end)
mapZoomOut.MouseButton1Click:Connect(function()
    mapRangeIdx = math.min(#mapRanges, mapRangeIdx + 1)
end)
mapClearBtn.MouseButton1Click:Connect(function()
    mapWaypoint = nil
end)

-- ========== NAVEGAÇÃO ==========
local function openHomeScreen()
    isInPhotoViewer = false
    exitPhotoViewer()
    currentApp = "home"
    local pos = PhoneHome.Position
    PhoneHome.Position = pos
    MainFrame.Position = pos
    StopwatchFrame.Position = pos
    ConfigFrame.Position = pos
    GalleryFrame.Position = pos
    MapFrame.Position = pos

    PhoneHome.Visible = true
    MainFrame.Visible = false
    StopwatchFrame.Visible = false
    ConfigFrame.Visible = false
    GalleryFrame.Visible = false
    MapFrame.Visible = false
    isMusicOpen = false
    attachVolumeTo(PhoneHome)
    selectedFrame.Visible = true
end

local function openMusicApp()
    if batteryDead then return end
    isInPhotoViewer = false
    exitPhotoViewer()
    currentApp = "music"
    local pos = PhoneHome.Position
    MainFrame.Position = pos
    PhoneHome.Visible = false
    MainFrame.Visible = true
    StopwatchFrame.Visible = false
    ConfigFrame.Visible = false
    GalleryFrame.Visible = false
    MapFrame.Visible = false
    isMusicOpen = true
    refreshFiles()
    attachVolumeTo(MainFrame)
end

local function openStopwatchApp()
    if batteryDead then return end
    isInPhotoViewer = false
    exitPhotoViewer()
    currentApp = "stopwatch"
    local pos = PhoneHome.Position
    StopwatchFrame.Position = pos
    PhoneHome.Visible = false
    MainFrame.Visible = false
    StopwatchFrame.Visible = true
    ConfigFrame.Visible = false
    GalleryFrame.Visible = false
    MapFrame.Visible = false
    isMusicOpen = false
    attachVolumeTo(StopwatchFrame)
end

local function openConfigApp()
    if batteryDead then return end
    isInPhotoViewer = false
    exitPhotoViewer()
    currentApp = "config"
    local pos = PhoneHome.Position
    ConfigFrame.Position = pos
    PhoneHome.Visible = false
    MainFrame.Visible = false
    StopwatchFrame.Visible = false
    ConfigFrame.Visible = true
    GalleryFrame.Visible = false
    MapFrame.Visible = false
    isMusicOpen = false
    attachVolumeTo(ConfigFrame)
end

local function openGalleryApp()
    if batteryDead then return end
    isInPhotoViewer = false
    exitPhotoViewer()
    currentApp = "gallery"
    local pos = PhoneHome.Position
    GalleryFrame.Position = pos
    PhoneHome.Visible = false
    MainFrame.Visible = false
    StopwatchFrame.Visible = false
    ConfigFrame.Visible = false
    GalleryFrame.Visible = true
    isMusicOpen = false
    refreshPhotos()
    attachVolumeTo(GalleryFrame)
end

local function openMapApp()
    if batteryDead then return end
    isInPhotoViewer = false
    exitPhotoViewer()
    currentApp = "map"
    local pos = PhoneHome.Position
    MapFrame.Position = pos
    PhoneHome.Visible = false
    MainFrame.Visible = false
    StopwatchFrame.Visible = false
    ConfigFrame.Visible = false
    GalleryFrame.Visible = false
    MapFrame.Visible = true
    isMusicOpen = false
    attachVolumeTo(MapFrame)
end

local function goHome()
    if currentApp == "home" then return end
    openHomeScreen()
end

local function handleBack()
    if currentApp == "gallery" and isInPhotoViewer then
        if isPhotoMenuOpen then
            closePhotoMenu()
        else
            exitPhotoViewer()
        end
    end
end

homeNavBtn.MouseButton1Click:Connect(goHome)
musicNavBtn.MouseButton1Click:Connect(goHome)
swNavBtn.MouseButton1Click:Connect(goHome)
cfgNavBtn.MouseButton1Click:Connect(goHome)
galNavBtn.MouseButton1Click:Connect(goHome)
mapNavBtn.MouseButton1Click:Connect(goHome)

homeBackBtn.MouseButton1Click:Connect(handleBack)
musicBackBtn.MouseButton1Click:Connect(handleBack)
swBackBtn.MouseButton1Click:Connect(handleBack)
cfgBackBtn.MouseButton1Click:Connect(handleBack)
galBackBtn.MouseButton1Click:Connect(handleBack)
mapBackBtn.MouseButton1Click:Connect(handleBack)

MusicAppIcon.MouseButton1Click:Connect(openMusicApp)
StopwatchAppIcon.MouseButton1Click:Connect(openStopwatchApp)
ConfigAppIcon.MouseButton1Click:Connect(openConfigApp)
GalleryAppIcon.MouseButton1Click:Connect(openGalleryApp)
MapAppIcon.MouseButton1Click:Connect(openMapApp)

-- ========== OPEN / CLOSE PHONE ==========
local function closePhone()
    isInPhotoViewer = false
    exitPhotoViewer()
    local target = UDim2.new(1, -300, 1, 80)
    local frames = {PhoneHome, MainFrame, StopwatchFrame, ConfigFrame, GalleryFrame, MapFrame}
    for _, f in ipairs(frames) do
        if f.Visible then
            local tween = TweenService:Create(f, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Position = target})
            tween:Play()
            tween.Completed:Once(function()
                f.Visible = false
            end)
        end
    end
    isPhoneOpen = false
    isMusicOpen = false
    currentApp = "home"
    selectedFrame.Visible = false
end

local function openPhone()
    isPhoneOpen = true
    openHomeScreen()
    PhoneHome.Position = UDim2.new(1, -300, 1, 80)
    PhoneHome.Visible = true
    local target = UDim2.new(phoneSettings.phonePosition.X, phoneSettings.phonePosition.XOffset, phoneSettings.phonePosition.Y, phoneSettings.phonePosition.YOffset)
    local tween = TweenService:Create(PhoneHome, TweenInfo.new(0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = target})
    tween:Play()
    attachVolumeTo(PhoneHome)
    selectedFrame.Visible = true
end

local function togglePhone()
    if isPhoneOpen then
        closePhone()
    else
        openPhone()
    end
end

-- ========== BATERIA FAKE ==========
local batteryLevel = math.clamp(tonumber(phoneSettings.battery) or 100, 0, 100)
local batteryCharging = false
local batteryWidgets = {}
local lastSavedBattery = math.floor(batteryLevel)

local function createBatteryWidget(parent)
    local btn = Instance.new("TextButton")
    btn.Name = "BatteryWidget"
    btn.Size = UDim2.new(0, 60, 0, 16)
    btn.Position = UDim2.new(1, -72, 0, 13)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 12
    btn.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 32, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "100%"
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 10
    label.TextXAlignment = Enum.TextXAlignment.Right
    label.ZIndex = 12
    label.Parent = btn

    local body = Instance.new("Frame")
    body.Position = UDim2.new(0, 36, 0, 2)
    body.Size = UDim2.new(0, 20, 0, 12)
    body.BackgroundTransparency = 1
    body.ZIndex = 12
    body.Parent = btn
    Instance.new("UICorner", body).CornerRadius = UDim.new(0, 3)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Thickness = 1
    stroke.Parent = body

    local fill = Instance.new("Frame")
    fill.Position = UDim2.new(0, 1, 0, 1)
    fill.Size = UDim2.new(0, 18, 1, -2)
    fill.BorderSizePixel = 0
    fill.ZIndex = 13
    fill.Parent = body
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 2)

    local tip = Instance.new("Frame")
    tip.Position = UDim2.new(0, 57, 0, 5)
    tip.Size = UDim2.new(0, 2, 0, 6)
    tip.BackgroundColor3 = Color3.new(1, 1, 1)
    tip.BorderSizePixel = 0
    tip.ZIndex = 12
    tip.Parent = btn

    table.insert(batteryWidgets, {label = label, fill = fill, stroke = stroke, tip = tip, btn = btn})
    return btn
end

-- tela de "celular desligado"
local DeadScreen = Instance.new("Frame")
DeadScreen.Name = "DeadScreen"
DeadScreen.Size = UDim2.new(1, 0, 1, 0)
DeadScreen.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
DeadScreen.BorderSizePixel = 0
DeadScreen.Active = true
DeadScreen.Visible = false
DeadScreen.ZIndex = 50
DeadScreen.Parent = PhoneHome
Instance.new("UICorner", DeadScreen).CornerRadius = UDim.new(0, 28)

local deadIcon = Instance.new("TextLabel")
deadIcon.Size = UDim2.new(1, 0, 0, 60)
deadIcon.Position = UDim2.new(0, 0, 0.5, -110)
deadIcon.BackgroundTransparency = 1
deadIcon.Text = "🪫"
deadIcon.TextSize = 48
deadIcon.ZIndex = 51
deadIcon.Parent = DeadScreen

local deadText = Instance.new("TextLabel")
deadText.Size = UDim2.new(1, -20, 0, 26)
deadText.Position = UDim2.new(0, 10, 0.5, -45)
deadText.BackgroundTransparency = 1
deadText.Text = "Bateria descarregada"
deadText.TextColor3 = Color3.new(1, 1, 1)
deadText.Font = Enum.Font.GothamBold
deadText.TextSize = 18
deadText.ZIndex = 51
deadText.Parent = DeadScreen

local deadSub = Instance.new("TextLabel")
deadSub.Size = UDim2.new(1, -20, 0, 20)
deadSub.Position = UDim2.new(0, 10, 0.5, -16)
deadSub.BackgroundTransparency = 1
deadSub.Text = "Conecte o carregador para ligar"
deadSub.TextColor3 = Color3.fromRGB(170, 170, 170)
deadSub.Font = Enum.Font.Gotham
deadSub.TextSize = 12
deadSub.ZIndex = 51
deadSub.Parent = DeadScreen

local deadBtn = Instance.new("TextButton")
deadBtn.Size = UDim2.new(0, 150, 0, 42)
deadBtn.Position = UDim2.new(0.5, -75, 0.5, 20)
deadBtn.BackgroundColor3 = Color3.fromRGB(50, 205, 50)
deadBtn.Text = "⚡ Carregar"
deadBtn.TextColor3 = Color3.new(0, 0, 0)
deadBtn.Font = Enum.Font.GothamBold
deadBtn.TextSize = 15
deadBtn.ZIndex = 51
deadBtn.Parent = DeadScreen
Instance.new("UICorner", deadBtn).CornerRadius = UDim.new(0, 14)

local function updateBatteryVisuals()
    local pct = math.floor(batteryLevel)
    local color
    if batteryCharging then
        color = Color3.fromRGB(80, 220, 255)
    elseif pct <= 10 then
        color = Color3.fromRGB(255, 70, 70)
    elseif pct <= 20 then
        color = Color3.fromRGB(255, 170, 40)
    else
        color = Color3.fromRGB(50, 205, 50)
    end
    local w = math.max(0, math.floor(18 * (batteryLevel / 100) + 0.5))
    for _, bw in ipairs(batteryWidgets) do
        bw.label.Text = (batteryCharging and "⚡" or "") .. pct .. "%"
        bw.fill.BackgroundColor3 = color
        bw.fill.Size = UDim2.new(0, w, 1, -2)
        bw.label.TextColor3 = (pct <= 20 and not batteryCharging) and color or Color3.new(1, 1, 1)
    end
    deadBtn.Text = batteryCharging and "⚡ Carregando..." or "⚡ Carregar"
    deadSub.Text = batteryCharging and ("Carregando... " .. pct .. "%") or "Conecte o carregador para ligar"
end

local function setBatteryDead(state)
    batteryDead = state
    DeadScreen.Visible = state
    if state then
        if currentSound and currentSound.IsPlaying then
            currentSound:Pause()
            isPaused = true
            PlayBtn.Text = "▶"
        end
        if phoneFlashlight then
            phoneFlashlight:Destroy()
            phoneFlashlight = nil
        end
        if isPhoneOpen and currentApp ~= "home" then
            openHomeScreen()
        end
    else
        if phoneSettings.flashlightEnabled then
            local root = Character and Character:FindFirstChild("HumanoidRootPart")
            if root and not phoneFlashlight then
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
end

local function toggleCharging()
    if batteryLevel >= 100 and not batteryCharging then return end
    batteryCharging = not batteryCharging
    updateBatteryVisuals()
end

deadBtn.MouseButton1Click:Connect(toggleCharging)

for _, f in ipairs({PhoneHome, MainFrame, StopwatchFrame, ConfigFrame, GalleryFrame, MapFrame}) do
    local w = createBatteryWidget(f)
    w.MouseButton1Click:Connect(toggleCharging)
end

updateBatteryVisuals()
if batteryLevel <= 0 then setBatteryDead(true) end

task.spawn(function()
    while true do
        task.wait(1)
        if batteryCharging then
            batteryLevel = math.min(100, batteryLevel + 0.5) -- +1% a cada 2s
            if batteryDead and batteryLevel >= 3 then setBatteryDead(false) end
            if batteryLevel >= 100 then batteryCharging = false end
        elseif not batteryDead then
            local rate = 1 / 45 -- 1% a cada 45s com o celular aberto
            if not isPhoneOpen then rate = rate * 0.3 end
            if phoneSettings.flashlightEnabled then rate = rate * 1.8 end
            if currentApp == "map" and isPhoneOpen then rate = rate * 1.4 end
            if currentSound and currentSound.IsPlaying then rate = rate * 1.3 end
            batteryLevel = math.max(0, batteryLevel - rate)
            if batteryLevel <= 0 then setBatteryDead(true) end
        end
        updateBatteryVisuals()

        local fl = math.floor(batteryLevel)
        if fl ~= lastSavedBattery and ((not batteryCharging) or fl % 5 == 0 or fl >= 100) then
            lastSavedBattery = fl
            phoneSettings.battery = batteryLevel
            saveSettings()
        end
    end
end)

-- ========== HOLD 0.45s PARA ARRASTAR SÓ O BOTÃO (sistema do LOCK) ==========
local hold = false
local canDrag = false
local isDragging = false
local startPos = nil
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
    if canDrag or isDragging then return end
    togglePhone()
end)

-- Tecla 0 (PC)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Zero or input.KeyCode == Enum.KeyCode.KeypadZero then
        togglePhone()
    end
end)

-- Music controls
SearchBox.Changed:Connect(function(prop)
    if prop == "Text" then updateMusicList() end
end)

ModeBtn.MouseButton1Click:Connect(function()
    if currentMode == "File" then
        currentMode = "ID"
        ModeBtn.Text = "Sound ID"
        ScrollList.Visible = false
        SearchBox.Visible = false
        IDInput.Visible = true
    else
        currentMode = "File"
        ModeBtn.Text = "Arquivo"
        ScrollList.Visible = true
        SearchBox.Visible = true
        IDInput.Visible = false
        refreshFiles()
    end
end)

IDInput.FocusLost:Connect(function(enter)
    if enter and IDInput.Text ~= "" then
        local id = "rbxassetid://" .. IDInput.Text:gsub("%D", "")
        play(id, "ID: " .. IDInput.Text, 0)
    end
end)

PlayBtn.MouseButton1Click:Connect(function()
    if not currentSound then return end
    if isPaused then
        currentSound:Resume()
        PlayBtn.Text = "⏸"
    else
        currentSound:Pause()
        PlayBtn.Text = "▶"
    end
    isPaused = not isPaused
end)

NextBtn.MouseButton1Click:Connect(function()
    if currentMode == "File" and #mp3List > 0 then
        local nextIdx = shuffleMode and math.random(1, #mp3List) or ((currentTrackIndex % #mp3List) + 1)
        if nextIdx < 1 then nextIdx = #mp3List end
        if nextIdx > #mp3List then nextIdx = 1 end
        play(getcustomasset(mp3List[nextIdx].path), mp3List[nextIdx].name, nextIdx)
    end
end)

PrevBtn.MouseButton1Click:Connect(function()
    if currentMode == "File" and #mp3List > 0 then
        local prevIdx = shuffleMode and math.random(1, #mp3List) or (currentTrackIndex - 1)
        if prevIdx < 1 then prevIdx = #mp3List end
        play(getcustomasset(mp3List[prevIdx].path), mp3List[prevIdx].name, prevIdx)
    end
end)

ShuffleBtn.MouseButton1Click:Connect(function()
    shuffleMode = not shuffleMode
    ShuffleBtn.Text = shuffleMode and "🔀" or "➡️"
    ShuffleBtn.BackgroundColor3 = shuffleMode and Color3.fromRGB(50, 205, 50) or Color3.fromRGB(28, 28, 34)
end)

RepeatBtn.MouseButton1Click:Connect(function()
    repeatMode = not repeatMode
    RepeatBtn.Text = repeatMode and "🔁" or "🔂"
    RepeatBtn.BackgroundColor3 = repeatMode and Color3.fromRGB(50, 205, 50) or Color3.fromRGB(28, 28, 34)
end)

RunService.RenderStepped:Connect(function()
    if currentSound and (currentSound.IsPlaying or isPaused) then
        local duration = currentSound.TimeLength
        local current = currentSound.TimePosition
        if duration > 0 then
            local progress = current / duration
            TimeBarFill.Size = UDim2.new(progress, 0, 1, 0)
            TimeLabel.Text = formatTime(current) .. " / " .. formatTime(duration)
        end
    end
end)

-- Character
local function onCharacterAdded(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    phoneSettings.joinTime = os.clock()
    if phoneSettings.flashlightEnabled and not batteryDead then
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
refreshPhotos()
