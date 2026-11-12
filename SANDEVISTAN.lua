local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local ContextActionService = game:GetService("ContextActionService")
local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Character, HRP, Humanoid
local ContentProvider = game:GetService("ContentProvider")

-- Forward declarations (evita chamar funcao nil antes da definicao)
local pararMusica
local ExecCyberpsychosis

local SANDI_TEXTURES = {
    "rbxassetid://118003464090928", "rbxassetid://100849825361179", "rbxassetid://96105818070338",
    "rbxassetid://110826337725055", "rbxassetid://139215133344337", "rbxassetid://98416340638203",
    "rbxassetid://114952882072808", "rbxassetid://87959360506687", "rbxassetid://99027028936189",
    "rbxassetid://126972351917677"
}

task.spawn(function()
    local instancesToLoad = {}
    for _, id in ipairs(SANDI_TEXTURES) do
        local img = Instance.new("ImageLabel")
        img.Image = id
        table.insert(instancesToLoad, img)
    end
    ContentProvider:PreloadAsync(instancesToLoad)
end)

local HttpService = game:GetService("HttpService")
local CONFIG_FILE = "CyberRebuilt_2077_Config.json"

local DefaultConfig = {
        UIPositions = {
        EnergyBar = {ScaleX = 0, OffsetX = 28, ScaleY = 0.5, OffsetY = -155},
        DashBtn = {ScaleX = 0.93, OffsetX = 0, ScaleY = 0.25, OffsetY = 0},
        SandiBtn = {ScaleX = 0.93, OffsetX = 0, ScaleY = 0.35, OffsetY = 0},
        KiroshiBtn = {ScaleX = 0.93, OffsetX = 0, ScaleY = 0.45, OffsetY = 0},
        OpticalBtn = {ScaleX = 0.93, OffsetX = 0, ScaleY = 0.55, OffsetY = 0},
        DodgeBtn = {ScaleX = 0.93, OffsetX = 0, ScaleY = 0.65, OffsetY = 0}
    },
    EnabledAbilities = {
        Dash = true,
        Sandi = true,
        Kiroshi = true,
        Optical = true,
        Dodge = true
    },
    Keybinds = {
        Dash = "Q",
        Sandi = "E",
        Kiroshi = "K",
        Optical = "O",
        Dodge = "N"
    },
    Settings = {
        DodgeMode = "Counter",  
        LiteMode = false,        
        CurrentSet = 1,          
        CloneColorIndex = 34
    }
}

type Cooldowns = {
    SANDI: number,
    DASH: number,
    DODGE: number,
    KIROSHI: number,
    OPTICAL: number
}

local IsDodging = false

type SystemState = {
    Energy: number,
    IsSandiActive: boolean,
    IsKiroshiActive: boolean,
    IsOpticalActive: boolean,
    IsDodgeReady: boolean,
    Cooldowns: Cooldowns,
    EditMode: boolean,
    LastVelocityY: number,
    LastHealth: number,
    NoRegenUntil: number,
    MusicSound: Sound?,
LastSandiActivation: number,
}

local Constants = {
    MAX_ENERGY = 100,
    SANDI_SPEED = 67,
    DASH_FORCE = 100,
    MOVING_THRESHOLD = 1,
    OPTICAL_DURATION = 2,
    SLOW_FACTOR = 0.8,
    COOLDOWNS = {
        SANDI = 10,
        DASH = 3.5,
        DODGE = 5,
        KIROSHI = 3.5,
        OPTICAL = 10
    },
    HOLOGRAM_CLONE = {
        SANDI = {DELAY = 0.075, DURATION = 3, END_TRANSPARENCY = 1},
        DASH = {DELAY = 0.07, DURATION = 0.35, END_TRANSPARENCY = 0.9},
        DODGE = {DELAY = 0.2, DURATION = 0.5, END_TRANSPARENCY = 0.9}
    },
    ENERGY_COSTS = {
        SANDI_ACTIVATE = 30,
        SANDI_DRAIN = 2.5,
        DASH = 8,
        DODGE = 5,
        KIROSHI = 10,
        OPTICAL = 15
    },
    REGEN_RATE = 15,
    REGEN_DELAY_ZERO = 10,
    REGEN_DELAY_USE = 5,
    DODGE_CONFIG = {
        VARIANT_THRESHOLD = 5.5,
        VARIANT_DURATION = 0.35,
        VARIANT_CLONE_INTERVAL = 0.05,
        NORMAL_DISTANCE_NO_ENEMY = 12,
        NORMAL_DISTANCE_ENEMY = 6
    },
    SANDEVISTAN_FAILURE_CHANCE = 0.2,
    CYBERPSYCHOSIS = {
        Duration = 6,
        PopupRate = 0.08,
        Radius = 7,
        ShakeIntensity = 0.6,
        WindowLifeTime = 0.5
    },
        ERROR_TEXTS = {
        "SYSTEM FAILURE", "CRITICAL ERROR", "NEURAL OVERLOAD",
        "CONNECTION LOST", "0xFF0029A CORRUPT", "PSYCHOSIS DETECTED",
        "FATAL EXCEPTION", "REBOOTING...", "NO SIGNAL"
    },
    BASE_WALKSPEED = 16,
    SANDI_WALKSPEED = 100,
    CLONE_INTERVAL = 0.05,
    
    HIGHLIGHT_CONFIG = {
        ENABLED = true,
        INITIAL_FILL_TRANS = 0.7,
        INITIAL_OUTLINE_TRANS = 1,
        FADEIN_FILL_TRANS = 0.3,
        FADEIN_OUTLINE_TRANS = 1,
        FADEIN_DURATION = 0.2,
        FADEOUT_START_FACTOR = 0.7,
        FADEOUT_DURATION_FACTOR = 0.3,
        COLORS = {
            sandi = { outline = "RAINBOW", fill = "RAINBOW" },
            dash = { outline = Color3.fromRGB(255, 40, 40), fill = Color3.fromRGB(255, 130, 30) },
            dodge = { outline = Color3.fromRGB(0, 255, 90), fill = Color3.fromRGB(80, 255, 170) },
            glitch = { outline = Color3.fromRGB(255, 0, 255), fill = Color3.fromRGB(200, 0, 200) }
        },
        ENABLE_COLOR_CYCLE = true,
    },
}

local Configurations = {
    SLOW_GRAVITY_MULTIPLIER = Constants.SLOW_FACTOR ^ 2,
    HOLOGRAM_MATERIAL = Enum.Material.Glass,
    HOLOGRAM_PRESERVE = {
        ACCESSORIES = true,
        HAIR = true,
        FACE = false
    }
}

local Colors = {
    SANDI_TINT = Color3.fromRGB(175, 255, 190),
    LIGHT_GREEN = Color3.fromRGB(105, 255, 140),
    DASH_GREEN = Color3.fromRGB(105, 255, 140),
    KIROSHI_RED = Color3.fromRGB(200, 50, 70),
    DODGE_LIME = Color3.fromRGB(200, 255, 200),
    RAINBOW_SEQUENCE = {
        Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 8, 0), Color3.fromRGB(255, 15, 0), Color3.fromRGB(255, 23, 0), Color3.fromRGB(255, 31, 0),
        Color3.fromRGB(255, 38, 0), Color3.fromRGB(255, 46, 0), Color3.fromRGB(255, 54, 0), Color3.fromRGB(255, 61, 0), Color3.fromRGB(255, 69, 0),
        Color3.fromRGB(255, 77, 0), Color3.fromRGB(255, 84, 0), Color3.fromRGB(255, 92, 0), Color3.fromRGB(255, 99, 0), Color3.fromRGB(255, 107, 0),
        Color3.fromRGB(255, 115, 0), Color3.fromRGB(255, 122, 0), Color3.fromRGB(255, 130, 0), Color3.fromRGB(255, 138, 0), Color3.fromRGB(255, 145, 0),
        Color3.fromRGB(255, 153, 0), Color3.fromRGB(255, 161, 0), Color3.fromRGB(255, 168, 0), Color3.fromRGB(255, 176, 0), Color3.fromRGB(255, 184, 0),
        Color3.fromRGB(255, 191, 0), Color3.fromRGB(255, 199, 0), Color3.fromRGB(255, 207, 0), Color3.fromRGB(255, 214, 0), Color3.fromRGB(255, 222, 0),
        Color3.fromRGB(255, 230, 0), Color3.fromRGB(255, 237, 0), Color3.fromRGB(255, 245, 0), Color3.fromRGB(255, 252, 0), Color3.fromRGB(250, 255, 0),
        Color3.fromRGB(242, 255, 0), Color3.fromRGB(235, 255, 0), Color3.fromRGB(227, 255, 0), Color3.fromRGB(219, 255, 0), Color3.fromRGB(212, 255, 0),
        Color3.fromRGB(204, 255, 0), Color3.fromRGB(196, 255, 0), Color3.fromRGB(189, 255, 0), Color3.fromRGB(181, 255, 0), Color3.fromRGB(173, 255, 0),
        Color3.fromRGB(166, 255, 0), Color3.fromRGB(158, 255, 0), Color3.fromRGB(150, 255, 0), Color3.fromRGB(143, 255, 0), Color3.fromRGB(135, 255, 0),
        Color3.fromRGB(128, 255, 0), Color3.fromRGB(120, 255, 0), Color3.fromRGB(112, 255, 0), Color3.fromRGB(105, 255, 0), Color3.fromRGB(97, 255, 0),
        Color3.fromRGB(89, 255, 0), Color3.fromRGB(82, 255, 0), Color3.fromRGB(74, 255, 0), Color3.fromRGB(66, 255, 0), Color3.fromRGB(59, 255, 0),
        Color3.fromRGB(51, 255, 0), Color3.fromRGB(43, 255, 0), Color3.fromRGB(36, 255, 0), Color3.fromRGB(28, 255, 0), Color3.fromRGB(20, 255, 0),
        Color3.fromRGB(13, 255, 0), Color3.fromRGB(5, 255, 0), Color3.fromRGB(0, 255, 3), Color3.fromRGB(0, 255, 10), Color3.fromRGB(0, 255, 18),
        Color3.fromRGB(0, 255, 25), Color3.fromRGB(0, 255, 33), Color3.fromRGB(0, 255, 41), Color3.fromRGB(0, 255, 48), Color3.fromRGB(0, 255, 56),
        Color3.fromRGB(0, 255, 64), Color3.fromRGB(0, 255, 71), Color3.fromRGB(0, 255, 79), Color3.fromRGB(0, 255, 87), Color3.fromRGB(0, 255, 94),
        Color3.fromRGB(0, 255, 102), Color3.fromRGB(0, 255, 110), Color3.fromRGB(0, 255, 117), Color3.fromRGB(0, 255, 125), Color3.fromRGB(0, 255, 133),
        Color3.fromRGB(0, 255, 140), Color3.fromRGB(0, 255, 148), Color3.fromRGB(0, 255, 156), Color3.fromRGB(0, 255, 163), Color3.fromRGB(0, 255, 171),
        Color3.fromRGB(0, 255, 179), Color3.fromRGB(0, 255, 186), Color3.fromRGB(0, 255, 194), Color3.fromRGB(0, 255, 201), Color3.fromRGB(0, 255, 209),
        Color3.fromRGB(0, 255, 217), Color3.fromRGB(0, 255, 224), Color3.fromRGB(0, 255, 232), Color3.fromRGB(0, 255, 240), Color3.fromRGB(0, 255, 247),
        Color3.fromRGB(0, 255, 255), Color3.fromRGB(0, 247, 255), Color3.fromRGB(0, 240, 255), Color3.fromRGB(0, 232, 255), Color3.fromRGB(0, 224, 255),
        Color3.fromRGB(0, 217, 255), Color3.fromRGB(0, 209, 255), Color3.fromRGB(0, 201, 255), Color3.fromRGB(0, 194, 255), Color3.fromRGB(0, 186, 255),
        Color3.fromRGB(0, 179, 255), Color3.fromRGB(0, 171, 255), Color3.fromRGB(0, 163, 255), Color3.fromRGB(0, 156, 255), Color3.fromRGB(0, 148, 255),
        Color3.fromRGB(0, 140, 255), Color3.fromRGB(0, 133, 255), Color3.fromRGB(0, 125, 255), Color3.fromRGB(0, 117, 255), Color3.fromRGB(0, 110, 255),
        Color3.fromRGB(0, 102, 255), Color3.fromRGB(0, 94, 255), Color3.fromRGB(0, 87, 255), Color3.fromRGB(0, 79, 255), Color3.fromRGB(0, 71, 255),
        Color3.fromRGB(0, 64, 255), Color3.fromRGB(0, 56, 255), Color3.fromRGB(0, 48, 255), Color3.fromRGB(0, 41, 255), Color3.fromRGB(0, 33, 255),
        Color3.fromRGB(0, 25, 255), Color3.fromRGB(0, 18, 255), Color3.fromRGB(0, 10, 255), Color3.fromRGB(0, 3, 255), Color3.fromRGB(5, 0, 255),
        Color3.fromRGB(13, 0, 255), Color3.fromRGB(20, 0, 255), Color3.fromRGB(28, 0, 255), Color3.fromRGB(36, 0, 255), Color3.fromRGB(43, 0, 255),
        Color3.fromRGB(51, 0, 255), Color3.fromRGB(59, 0, 255), Color3.fromRGB(66, 0, 255), Color3.fromRGB(74, 0, 255), Color3.fromRGB(82, 0, 255),
        Color3.fromRGB(89, 0, 255), Color3.fromRGB(97, 0, 255), Color3.fromRGB(105, 0, 255), Color3.fromRGB(112, 0, 255), Color3.fromRGB(120, 0, 255),
        Color3.fromRGB(128, 0, 255), Color3.fromRGB(135, 0, 255), Color3.fromRGB(143, 0, 255), Color3.fromRGB(150, 0, 255), Color3.fromRGB(158, 0, 255),
        Color3.fromRGB(166, 0, 255), Color3.fromRGB(173, 0, 255), Color3.fromRGB(181, 0, 255), Color3.fromRGB(189, 0, 255), Color3.fromRGB(196, 0, 255),
        Color3.fromRGB(204, 0, 255), Color3.fromRGB(212, 0, 255), Color3.fromRGB(219, 0, 255), Color3.fromRGB(227, 0, 255), Color3.fromRGB(235, 0, 255),
        Color3.fromRGB(242, 0, 255), Color3.fromRGB(250, 0, 255), Color3.fromRGB(255, 0, 252), Color3.fromRGB(255, 0, 245), Color3.fromRGB(255, 0, 237),
        Color3.fromRGB(255, 0, 230), Color3.fromRGB(255, 0, 222), Color3.fromRGB(255, 0, 214), Color3.fromRGB(255, 0, 207), Color3.fromRGB(255, 0, 199),
        Color3.fromRGB(255, 0, 191), Color3.fromRGB(255, 0, 184), Color3.fromRGB(255, 0, 176), Color3.fromRGB(255, 0, 168), Color3.fromRGB(255, 0, 161),
        Color3.fromRGB(255, 0, 153), Color3.fromRGB(255, 0, 145), Color3.fromRGB(255, 0, 138), Color3.fromRGB(255, 0, 130), Color3.fromRGB(255, 0, 122),
        Color3.fromRGB(255, 0, 115), Color3.fromRGB(255, 0, 107), Color3.fromRGB(255, 0, 99), Color3.fromRGB(255, 0, 92), Color3.fromRGB(255, 0, 84),
        Color3.fromRGB(255, 0, 77), Color3.fromRGB(255, 0, 69), Color3.fromRGB(255, 0, 61), Color3.fromRGB(255, 0, 54), Color3.fromRGB(255, 0, 46),
        Color3.fromRGB(255, 0, 38), Color3.fromRGB(255, 0, 31), Color3.fromRGB(255, 0, 23), Color3.fromRGB(255, 0, 15), Color3.fromRGB(255, 0, 8)
    },
    DODGE_START = Color3.fromRGB(160, 0, 255),
    DODGE_END = Color3.fromRGB(255, 0, 130),
    EDIT_MODE = Color3.fromRGB(0, 255, 255),
    UI_BG = Color3.fromRGB(6, 6, 10),
    UI_ACCENT = Color3.fromRGB(18, 18, 24),
    UI_NEON = Color3.fromRGB(0, 255, 200),
    UI_GLOW = Color3.fromRGB(255, 255, 255),
    UI_DARK = Color3.fromRGB(3, 3, 7),
    KIROSHI_TINT = Color3.fromRGB(200, 50, 70),
    KIROSHI = Color3.fromRGB(200, 50, 70),
    OPTICAL = Color3.fromRGB(210, 220, 235), -- Prateado / Chrome
    ENERGY_FULL = Color3.fromRGB(105, 255, 140),
    ENERGY_MEDIUM = Color3.fromRGB(255, 215, 0),
    ENERGY_LOW = Color3.fromRGB(255, 40, 40),
    CYBER_CHROME = Color3.fromRGB(180, 190, 210),
    CYBER_ORANGE = Color3.fromRGB(255, 130, 40)
}

local ButtonConfigs = {
    LockBtn = {Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(0, 8, 0.5, -210), BackgroundColor3 = Colors.UI_DARK, TextColor3 = Colors.UI_NEON, Font = Enum.Font.SciFi, TextSize = 22, Text = ""},
    DashBtn = {Key = "D", Color = Color3.fromRGB(255, 80, 0), Position = UDim2.new(0.93, 0, 0.25, 0)},
    SandiBtn = {Key = "S", Color = Color3.new(1,1,1), Position = UDim2.new(0.93, 0, 0.35, 0)},
    KiroshiBtn = {Key = "Ko", Color = Colors.KIROSHI, Position = UDim2.new(0.93, 0, 0.45, 0)},
    OpticalBtn = {Key = "Ph", Color = Colors.OPTICAL, Position = UDim2.new(0.93, 0, 0.55, 0)},
    DodgeBtn = {Key = "N", Color = Color3.fromRGB(0, 255, 140), Position = UDim2.new(0.93, 0, 0.65, 0)}
}

local EnabledAbilities = {
    Dash = true,
    Sandi = true,
    Kiroshi = true,
    Optical = true,
    Dodge = true
}

local AbilityMap = {
    Dash = "DashBtn",
    Sandi = "SandiBtn",
    Kiroshi = "KiroshiBtn",
    Optical = "OpticalBtn",
    Dodge = "DodgeBtn"
}

local SkillContainers = {}

local SET_1 = {120005268911290}
local SET_2 = {84715312484929, 120005268911290, 129989646284308}  
local SET_3 = {76673357358456, 101607241306335, 79690388560983}

local setColors = {
    [1] = Color3.fromRGB(45, 45, 45),      
    [2] = Color3.fromRGB(0, 120, 215),     
    [3] = Color3.fromRGB(200, 50, 50)       
}

local AbilityActions = {Dash = "CyberDash", Sandi = "CyberSandi", Kiroshi = "CyberKiroshi", Optical = "CyberOptical", Dodge = "CyberDodge"}
local CurrentKeybinds = {Dash = Enum.KeyCode.Q, Sandi = Enum.KeyCode.E, Kiroshi = Enum.KeyCode.K, Optical = Enum.KeyCode.O, Dodge = Enum.KeyCode.N}
local RebindingAbility = nil
local KeybindCurrentTexts = {}

local Sounds = {
    DODGE_NORMAL = {id = "rbxassetid://104594227753486", volume = 1.5, pitch = 1, looped = false},
    DODGE_VARIANT = {id = "rbxassetid://136915991425056", volume = 1.5, pitch = 1, looped = false},
    DASH = {id = "rbxassetid://103247005619946", volume = 1.5, pitch = 1, looped = false},
    DASH_BACK = {id = "rbxassetid://93442668796353", volume = 1.5, pitch = 1, looped = false},
    SANDI_ON = {id = "rbxassetid://123844681344865", volume = 1.5, pitch = 1, looped = false},
    SANDI_OFF = {id = "rbxassetid://118534165523355", volume = 1.5, pitch = 1, looped = false},
    SANDI_LOOP = {id = "rbxassetid://74707394872868", volume = 1.5, pitch = 1, looped = true},
    PSYCHOSIS = {id = "rbxassetid://87597277352254", volume = 2, pitch = 1, looped = false},
    PSYCHOSIS2 = {id = "rbxassetid://116079585368153", volume = 2, pitch = 1, looped = false},
    OPTICAL_CAMO = {id = "rbxassetid://115981406751041", volume = 1, pitch = 1, looped = false},
    SANDI_FAILURE = {id = "rbxassetid://132281440773764", volume = 5, pitch = 1, looped = false},
    COLLISION_IMPACT = {id = "rbxassetid://86227700557194", volume = 1.7, pitch = 1, looped = false},
    SPAWN = {id = "rbxassetid://138566469626743", volume = 1.5, pitch = 1, looped = false},
    KIROSHI_ON = {id = "rbxassetid://101563346734882", volume = 2.2, pitch = 1.05, looped = false},
    KIROSHI_OFF = {id = "rbxassetid://79307196411649", volume = 1.8, pitch = 0.95, looped = false}
}

local NOME_ARQUIVO = "I Really Want to Stay at Your House.mp3"
local GITHUB_URL = "https://github.com/Loader-Tester/Test-Sound/raw/refs/heads/main/I%20Really%20Want%20to%20Stay%20at%20Your%20House.mp3"

local VOLUME = 0.9
local LOOP = false

local function detectarExecutor()
    if KRNL_LOADED then return "KRNL", getcustomasset
    elseif syn then return "Synapse X", syn.getcustomasset
    elseif fluxus then return "Fluxus", fluxus.getcustomasset
    elseif getcustomasset then return "Executor Genérico", getcustomasset
    else return nil, nil end
end

local function verificarEBaixarMusica()
    if writefile and readfile then
        local sucesso, existe = pcall(function()
            return readfile(NOME_ARQUIVO)
        end)
        
        if not sucesso or not existe then
            
            local downloadSucesso, conteudo = pcall(function()
                return game:HttpGet(GITHUB_URL)
            end)
            
            if downloadSucesso and conteudo then
                pcall(function()
                    writefile(NOME_ARQUIVO, conteudo)
                end)
            else
            end
        else
        end
    else
    end
end

local function encontrarMusica()
    local executor, getasset = detectarExecutor()
    if not executor then return nil end
    
    verificarEBaixarMusica()
    
    local possibilidades = {NOME_ARQUIVO, "musica.mp3", "musica.ogg", "musica.wav"}
    if getasset then
        for _, nome in ipairs(possibilidades) do
            local sucesso, resultado = pcall(function() return getasset(nome) end)
            if sucesso and resultado then return resultado end
        end
    end
    return nil
end

local VOLUME_MAXIMO = 0.9 
local FADE_DURATION = 2.5 

local function tocarMusica()
    local musicaId = encontrarMusica()
    if not musicaId then return end
    
    local somAntigo = SoundService:FindFirstChild("MinhaMusicaLocal")
    if somAntigo then
        pararMusica(somAntigo)
    end
    
    local som = Instance.new("Sound")
    som.Name = "MinhaMusicaLocal"
    som.SoundId = musicaId
    som.Volume = 0 
    som.Looped = LOOP
    som.RollOffMode = Enum.RollOffMode.Linear
    som.RollOffMaxDistance = 1000
    som.Parent = SoundService
    
    local fadeIniciado = false
    local function iniciarFadeIn()
        if fadeIniciado or not som.Parent then return end
        fadeIniciado = true
        som:Play()
        TweenService:Create(
            som,
            TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Volume = VOLUME_MAXIMO}
        ):Play()
    end

    if som.IsLoaded then
        iniciarFadeIn()
    else
        som.Loaded:Connect(iniciarFadeIn)
    end
    
    task.delay(2, function()
        if som and som.Parent and not som.IsPlaying then
            iniciarFadeIn()
        end
    end)
    
    return som
end

function pararMusica(som)
    local somParaRemover = som or SoundService:FindFirstChild("MinhaMusicaLocal")
    
    if somParaRemover then
        somParaRemover.Name = "MusicaSaindo" 
        
        local fadeOut = TweenService:Create(
            somParaRemover,
            TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Volume = 0}
        )
        
        fadeOut:Play()
        
        fadeOut.Completed:Connect(function()
            somParaRemover:Stop()
            somParaRemover:Destroy()
        end)
    end
end

local State: SystemState = {
    Energy = Constants.MAX_ENERGY,
    IsSandiActive = false,
    IsKiroshiActive = false,
    IsOpticalActive = false,
    IsDodgeReady = false,
    Cooldowns = {SANDI = 0, DASH = 0, DODGE = 0, KIROSHI = 0, OPTICAL = 0},
    EditMode = false,
    LastVelocityY = 0,
    LastHealth = 100,
    NoRegenUntil = 0,
    MusicSound = nil,
    LastSandiActivation = 0 
}

local UI_Elements = {}
local ActiveCooldownFrames = {}
local sandiLoopSound: Sound? = nil
local lastSandiClone = 0
local savedPositions = {}
local activeHighlights = {}
local originalGravity: number?
local originalPlayerJumpPower: number?
local originalWalkSpeeds: {[Humanoid]: number} = {}
local originalJumpPowers: {[Humanoid]: number} = {}
local originalAnimationSpeeds: {[AnimationTrack]: number} = {}
local originalSoundSpeeds: {[Sound]: number} = {}
local originalVelocityInstances: {[Instance]: Vector3} = {}
local animationConnections: {RBXScriptConnection} = {}
local opticalToken = 0
local energyFill: Frame
local energyPercentLabel: TextLabel
local settingsMenu = nil 
local DodgeMode = DefaultConfig.Settings.DodgeMode
local LiteMode = DefaultConfig.Settings.LiteMode
local Noclip = false
local noclipConnection
local lineEnabled = false  
local lineObject = nil
local currentSet = DefaultConfig.Settings.CurrentSet
local cloneColorIndex = DefaultConfig.Settings.CloneColorIndex
local originalClockTime = nil  
local SandiLockTime = 0 local LastSandiActivationTime = 0

local function Create(className: string, properties: {[string]: any})
    local instance = Instance.new(className)
    for prop, value in properties do instance[prop] = value end
    return instance
end

local function PlaySFX(soundConfig: {id: string, volume: number?, pitch: number?})
    local sound = Create("Sound", {SoundId = soundConfig.id, Volume = soundConfig.volume or 1, PlaybackSpeed = soundConfig.pitch or 1, Parent = HRP or Camera})
    sound:Play()
    Debris:AddItem(sound, 10)
    return sound
end

local function CamShake(intensity: number, duration: number)
    if LiteMode then return end
    task.spawn(function()
        local startTime = os.clock()
        while os.clock() - startTime < duration do
            if Humanoid then
                Humanoid.CameraOffset = Vector3.new(math.random(-10,10)/10, math.random(-10,10)/10, math.random(-10,10)/10) * intensity
            end
            RunService.RenderStepped:Wait()
        end
        if Humanoid then Humanoid.CameraOffset = Vector3.zero end
    end)
end

local function ScreenFade(durationIn: number, hold: number, durationOut: number, tint: Color3, sat: number?, cont: number?)
    if LiteMode then return end
    local cc = Create("ColorCorrectionEffect", {Name = "CyberFade", TintColor = Color3.new(1,1,1), Saturation = 0, Contrast = 0, Parent = Lighting})
    TweenService:Create(cc, TweenInfo.new(durationIn, Enum.EasingStyle.Quad), {TintColor = tint, Saturation = sat or 0.6, Contrast = cont or 0.25}):Play()
    task.delay(durationIn + hold, function()
        TweenService:Create(cc, TweenInfo.new(durationOut, Enum.EasingStyle.Quad), {TintColor = Color3.new(1,1,1), Saturation = 0, Contrast = 0}):Play()
        task.delay(durationOut + 0.1, function() cc:Destroy() end)
    end)
end


-- ============================================================
-- SISTEMA DE FALAS (1 unico TXT sobre a cabeca do personagem)
-- Tamanho fixo em PIXELS: nao muda com o zoom da camera.
-- ============================================================
local TextService = game:GetService("TextService")

local FALAS_ATIVAS = true
local FALA_TAMANHO_BASE = 14      -- tamanho da letra (pequeno)
local FALA_LARGURA_MAX = 240      -- largura maxima antes de quebrar linha
local FALA_ALTURA_CABECA = 1.9    -- studs acima do centro da cabeca

-- Nome usado nas falas (troca o "David" pelo nome da sua conta)
local function NomeNaFala()
    local n = Player.DisplayName
    if not n or n == "" then n = Player.Name end
    return n
end

-- Emocoes: cor, velocidade de digitacao, tremor, pulso e extras
local EMOCOES = {
    calmo   = {cor = Color3.fromRGB(190, 255, 210), vel = 0.040, tremor = 0,   pulso = 0.00},
    focado  = {cor = Color3.fromRGB(110, 255, 160), vel = 0.032, tremor = 0,   pulso = 0.03},
    raiva   = {cor = Color3.fromRGB(255, 70, 60),   vel = 0.022, tremor = 1.4, pulso = 0.07},
    euforia = {cor = Color3.fromRGB(255, 225, 70),  vel = 0.018, tremor = 0.5, pulso = 0.10, pulo = true},
    dor     = {cor = Color3.fromRGB(255, 150, 150), vel = 0.045, tremor = 1.0, pulso = 0.04},
    medo    = {cor = Color3.fromRGB(190, 205, 255), vel = 0.030, tremor = 1.8, pulso = 0.03},
    frio    = {cor = Color3.fromRGB(150, 230, 255), vel = 0.050, tremor = 0,   pulso = 0.00, sussurro = true},
    glitch  = {cor = Color3.fromRGB(255, 60, 255),  vel = 0.020, tremor = 1.2, pulso = 0.05, glitch = true},
}

-- Eventos: prio (maior interrompe menor), chance, recarga (s) e as falas
-- Cada fala: {texto, emocao}  (so a emocao glitch usa intensidade 1-3 como 3o valor).  {nome} vira o seu nome.
local EVENTOS = {
    boot = {prio = 2, chance = 1, recarga = 5, falas = {
        {"Sistema ligado. Bora ver até onde esse corpo aguenta.", "focado"},
        {"Neuroenlace estável. {nome} na área.", "calmo"},
        {"Mais um dia, mais uma chance de não morrer.", "calmo"},
        {"Acordei. O chrome também. Vamos nessa.", "euforia"},
        {"Se é pra cair, que seja correndo.", "focado"},
        {"{nome} online. Quem vai ser o azarado de hoje?", "euforia"},
    }},
    sandi_on = {prio = 3, chance = 1, recarga = 4, falas = {
        {"Agora o mundo anda em câmera lenta!", "euforia"},
        {"Me segura se for capaz!", "euforia"},
        {"Tudo devagar... menos eu.", "focado"},
        {"Aceleração total. Sem freio!", "raiva"},
        {"Sinto meu coração querendo sair pela boca!", "euforia"},
        {"Vai, {nome}, vai, vai, vai!", "euforia"},
        {"Só eu estou na velocidade certa aqui.", "frio"},
    }},
    sandi_off = {prio = 2, chance = 0.7, recarga = 4, falas = {
        {"Ufa... o corpo cobrou a conta.", "dor"},
        {"Voltando ao ritmo dos mortais.", "calmo"},
        {"Isso foi rápido demais até pra mim.", "euforia"},
        {"Respira, {nome}. Respira.", "calmo"},
        {"Sistema esfriando. Deu pra sentir cada osso.", "dor"},
    }},
    sandi_falha = {prio = 4, chance = 1, recarga = 3, falas = {
        {"Não, não, não! Pega, maldito implante!", "raiva"},
        {"Falhou?! Justo agora?!", "raiva"},
        {"Meu crânio tá fritando...", "dor"},
        {"Sobrecarga! Calma, {nome}, calma!", "medo"},
        {"Esse chip quer me matar, só pode.", "raiva"},
    }},
    sandi_zerou = {prio = 4, chance = 1, recarga = 6, falas = {
        {"Sem energia... eu fui longe demais.", "dor"},
        {"Tá apagando... tudo apagando...", "medo"},
        {"Passei do limite. De novo.", "dor"},
        {"Aguenta, {nome}... só mais um pouco...", "dor"},
    }},
    dash = {prio = 1, chance = 0.4, recarga = 4, falas = {
        {"Pra cima deles!", "euforia"},
        {"Muito lento!", "euforia"},
        {"Piscou, perdeu.", "focado"},
        {"Chega mais!", "raiva"},
        {"Hup!", "euforia"},
        {"Nem vi você passar... ah, fui eu.", "euforia"},
    }},
    dodge = {prio = 3, chance = 0.8, recarga = 3, falas = {
        {"Quase! Quase mesmo!", "medo"},
        {"Errou, otário!", "euforia"},
        {"Meus reflexos agradecem o upgrade.", "focado"},
        {"Ei, isso ia doer!", "medo"},
        {"Devagar demais pra mim.", "frio"},
        {"Passou raspando!", "medo"},
    }},
    kiroshi = {prio = 2, chance = 0.8, recarga = 4, falas = {
        {"Olhos ligados. Eu te vejo.", "frio"},
        {"Escaneando... ninguém se esconde de mim.", "focado"},
        {"Cada detalhe vermelho na minha frente.", "focado"},
        {"Visão aprimorada. Agora a caça começa.", "raiva"},
        {"Vejo tudo, {nome} vê tudo.", "frio"},
    }},
    optical_on = {prio = 2, chance = 0.8, recarga = 4, falas = {
        {"Paredes? Que paredes?", "frio"},
        {"Fase desalinhada. Atravessando.", "focado"},
        {"Nada me segura.", "euforia"},
        {"Sem barreiras. Sem limites.", "frio"},
        {"{nome} vira fantasma.", "frio"},
    }},
    optical_off = {prio = 1, chance = 0.5, recarga = 4, falas = {
        {"Corpo estabilizado.", "calmo"},
        {"Voltei ao mundo sólido.", "calmo"},
        {"Phase shift encerrado.", "focado"},
        {"Tá, voltei.", "calmo"},
    }},
    psicose = {prio = 5, chance = 1, recarga = 8, falas = {
        {"A-a-algo errado... minha cabeça...", "glitch", 3},
        {"Vozes... tem alguém aqui dentro!", "glitch", 3},
        {"ERRO. ERRO. ERRO. SOU EU O ERRO?", "glitch", 3},
        {"Para de rir! Quem tá rindo?!", "glitch", 3},
        {"Não sou eu... não sou eu...", "glitch", 3},
        {"Tá tudo quebrando... ajuda...", "glitch", 2},
        {"{nome}? Quem é {nome}?", "glitch", 3},
    }},
    dano = {prio = 2, chance = 0.55, recarga = 3, falas = {
        {"Ai!", "dor"},
        {"Isso doeu!", "dor"},
        {"Tá, me acertaram.", "raiva"},
        {"Nada mal... pra um iniciante.", "raiva"},
        {"Sentiu o gosto de sangue? Eu senti.", "dor"},
        {"Vai pagar por isso!", "raiva"},
    }},
    dano_pesado = {prio = 3, chance = 1, recarga = 4, falas = {
        {"Argh! Isso foi pesado!", "dor"},
        {"Minhas costelas... aguenta, corpo!", "dor"},
        {"Cara... eu vi estrelas.", "dor"},
        {"Esse doeu até no chrome!", "dor"},
        {"{nome}, levanta! Levanta!", "raiva"},
    }},
    vida_baixa = {prio = 3, chance = 1, recarga = 20, falas = {
        {"Tô quase no chão... preciso sair daqui.", "medo"},
        {"Não posso cair aqui. Ainda não.", "medo"},
        {"Cada respiração dói...", "dor"},
        {"Se eu apagar agora, quem lembra de mim?", "medo"},
        {"Segura, {nome}... só mais um minuto.", "dor"},
    }},
    morte = {prio = 6, chance = 1, recarga = 0, falas = {
        {"Foi... um bom corre...", "dor"},
        {"Dizem que no fim a gente vê a lua...", "frio"},
        {"Droga... eu queria mais um pouco.", "dor"},
        {"Apaga a luz... quando eu sair...", "frio"},
        {"Pelo menos fui rápido.", "dor"},
    }},
    queda = {prio = 2, chance = 0.7, recarga = 4, falas = {
        {"Pousei! Mais ou menos.", "euforia"},
        {"Minhas pernas... ainda estão aqui?", "dor"},
        {"Cair é fácil. Difícil é o chão.", "dor"},
        {"Isso devia ter doído mais!", "euforia"},
    }},
    energia_baixa = {prio = 2, chance = 1, recarga = 25, falas = {
        {"Bateria no fim. Preciso respirar.", "dor"},
        {"Energia acabando... sem loucuras por agora.", "focado"},
        {"Meu corpo tá pedindo arrego.", "dor"},
        {"Tanque vazio, {nome}. Segura a onda.", "calmo"},
    }},
    ocioso = {prio = 1, chance = 1, recarga = 40, falas = {
        {"Tá quieto demais...", "frio"},
        {"Se eu parar, o implante esfria. Se esfriar, eu penso.", "calmo"},
        {"Algum dia eu chego onde eu quero. Algum dia.", "calmo"},
        {"Ei, {nome}. Você ainda tá aí?", "calmo"},
        {"Silêncio bom. Dura pouco.", "frio"},
        {"Um café agora cairia bem.", "calmo"},
    }},
}

local fala = {gui = nil, label = nil, escala = nil, token = 0, prio = 0, fim = 0, gapAte = 0}
local falaMisturas = {}
local falaUltimoUso = {}
local falaUltimoTexto = nil

local function falaTexto(def, evento)
    local bag = falaMisturas[evento]
    if not bag or #bag == 0 then
        bag = {}
        for i = 1, #def.falas do bag[i] = i end
        for i = #bag, 2, -1 do
            local j = math.random(1, i)
            bag[i], bag[j] = bag[j], bag[i]
        end
        falaMisturas[evento] = bag
    end
    local idx = table.remove(bag)
    if def.falas[idx][1] == falaUltimoTexto and #def.falas > 1 then
        idx = (idx % #def.falas) + 1
    end
    return def.falas[idx]
end

local function falaGarantirGui()
    local head = Character and Character:FindFirstChild("Head")
    if not head then return nil end
    if fala.gui and fala.gui.Parent then
        if fala.gui.Adornee ~= head then fala.gui.Adornee = head end
        return fala.gui
    end
    local gui = Create("BillboardGui", {
        Name = "CyberFalas",
        Adornee = head,
        AlwaysOnTop = true,
        LightInfluence = 0,
        ResetOnSpawn = false,
        Active = false,
        Size = UDim2.fromOffset(40, 24), -- OFFSET = pixels, ignora zoom/distancia
        StudsOffsetWorldSpace = Vector3.new(0, FALA_ALTURA_CABECA, 0),
        Parent = Player:WaitForChild("PlayerGui"),
    })
    -- Container unico: as letras (1 TextLabel por letra) ficam dentro dele
    local caixa = Create("Frame", {
        Name = "Fala",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(40, 20),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = gui,
    })
    fala.gui, fala.label = gui, caixa
    return gui
end

local SIMBOLOS_GLITCH = {"#", "@", "%", "&", "$", "0", "X", "/", "?"}

local function falaMostrar(texto, emo, inten, prio)
    local gui = falaGarantirGui()
    if not gui then return end
    local caixa = fala.label
    local e = EMOCOES[emo] or EMOCOES.calmo
    if emo == "glitch" then
        inten = math.clamp(inten or 2, 1, 3)
    else
        inten = 1
    end

    fala.token += 1
    local meuToken = fala.token
    local tam = FALA_TAMANHO_BASE + (inten - 1) * 1.5
    local altLinha = tam + 4

    caixa:ClearAllChildren()

    -- 1) Mede cada letra e quebra em linhas (a fala inteira sempre cabe)
    local function larguraChar(ch)
        if ch == " " then return tam * 0.32 end
        local ok, v = pcall(function()
            return TextService:GetTextSize(ch, tam, Enum.Font.GothamBold, Vector2.new(1000, 1000))
        end)
        return (ok and v) and v.X or tam * 0.6
    end

    local palavras = {}
    for palavra in texto:gmatch("%S+") do
        local chars, larg = {}, 0
        for _, cp in utf8.codes(palavra) do
            local ch = utf8.char(cp)
            local lw = larguraChar(ch)
            table.insert(chars, {ch = ch, w = lw})
            larg += lw
        end
        table.insert(palavras, {chars = chars, w = larg})
    end

    local espaco = larguraChar(" ")
    local linhas, atual, atualW = {}, {}, 0
    for _, p in ipairs(palavras) do
        local extra = (#atual > 0) and espaco or 0
        if #atual > 0 and atualW + extra + p.w > FALA_LARGURA_MAX then
            table.insert(linhas, {palavras = atual, w = atualW})
            atual, atualW, extra = {}, 0, 0
        end
        table.insert(atual, p)
        atualW += extra + p.w
    end
    if #atual > 0 then table.insert(linhas, {palavras = atual, w = atualW}) end

    local larguraTotal = 0
    for _, l in ipairs(linhas) do larguraTotal = math.max(larguraTotal, l.w) end
    local alturaTotal = #linhas * altLinha

    -- 2) Cria 1 TextLabel por letra, centralizado por linha
    local letras = {}
    for li, l in ipairs(linhas) do
        local x = (larguraTotal - l.w) / 2
        local y = (li - 1) * altLinha
        for pi, p in ipairs(l.palavras) do
            for _, c in ipairs(p.chars) do
                local lbl = Create("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(c.w + 4, altLinha),
                    Position = UDim2.fromOffset(x - 2, y),
                    Font = Enum.Font.GothamBold,
                    Text = c.ch,
                    TextSize = tam,
                    TextColor3 = e.cor,
                    TextTransparency = 1,
                    TextStrokeTransparency = 1,
                    TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
                    Parent = caixa,
                })
                table.insert(letras, {lbl = lbl, ch = c.ch, bx = x - 2, by = y, dx = 0, dy = 0, fase = math.random() * 6.28})
                x += c.w
            end
            if pi < #l.palavras then x += espaco end
        end
    end

    local margem = 20 + e.tremor * inten * 2
    gui.Size = UDim2.fromOffset(larguraTotal + margem * 2, alturaTotal + margem * 2)
    caixa.Size = UDim2.fromOffset(larguraTotal, alturaTotal)
    caixa.Position = UDim2.fromScale(0.5, 0.5)
    caixa.Visible = true

    local total = #letras
    local vel = e.vel / (0.75 + 0.25 * inten)
    local tDigitar = total * vel
    local tLer = 1.1 + total * 0.045
    local tFade = 0.4
    local tFim = tDigitar + tLer + tFade
    local baseTrans = e.sussurro and 0.25 or 0
    local amp = e.tremor * inten * 0.8   -- tremor de CADA letra

    fala.prio = prio
    fala.fim = os.clock() + tFim
    fala.gapAte = fala.fim + 0.5
    falaUltimoTexto = texto

    task.spawn(function()
        local t0 = os.clock()
        local proxTremor = 0
        while fala.token == meuToken do
            local t = os.clock() - t0
            if t >= tFim then break end

            local sorteia = t >= proxTremor
            if sorteia then proxTremor = t + 0.04 end

            local tFadeIni = tDigitar + tLer
            local fadeK = (t > tFadeIni) and math.clamp((t - tFadeIni) / tFade, 0, 1) or 0

            for i, L in ipairs(letras) do
                local lbl = L.lbl
                local tLetra = t - (i - 1) * vel
                if tLetra < 0 then
                    lbl.TextTransparency = 1
                    lbl.TextStrokeTransparency = 1
                else
                    -- tremor independente por letra
                    if sorteia and amp > 0 then
                        L.dx = (math.random() * 2 - 1) * amp
                        L.dy = (math.random() * 2 - 1) * amp
                    end
                    local dx, dy = L.dx, L.dy

                    -- euforia: onda pulando letra por letra
                    if e.pulo then dy -= math.abs(math.sin(t * 9 + i * 0.55)) * 2.2 * inten end
                    -- dor: letras "pesadas" caindo de leve
                    if emo == "dor" then dy += math.sin(t * 5 + L.fase) * 0.8 * inten end

                    -- aparece com um pulinho (cada letra entra de baixo)
                    local entra = math.clamp(tLetra / 0.1, 0, 1)
                    dy += (1 - entra) * 5

                    lbl.Position = UDim2.fromOffset(L.bx + dx, L.by + dy)

                    -- pulso de tamanho por letra
                    local pulso = e.pulso * inten * math.sin(t * 11 + L.fase)
                    lbl.TextSize = tam * (1 + pulso) * (0.8 + 0.2 * entra)

                    -- cor / glitch por letra
                    if e.glitch and sorteia then
                        local c = math.random()
                        if c < 0.18 then lbl.TextColor3 = Color3.fromRGB(0, 255, 255)
                        elseif c < 0.3 then lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                        else lbl.TextColor3 = e.cor end
                        if L.ch ~= " " and math.random() < 0.06 * inten then
                            lbl.Text = SIMBOLOS_GLITCH[math.random(1, #SIMBOLOS_GLITCH)]
                        else
                            lbl.Text = L.ch
                        end
                    end

                    local trans = baseTrans + (1 - baseTrans) * fadeK
                    lbl.TextTransparency = trans * 1 + (1 - entra) * (1 - trans)
                    lbl.TextStrokeTransparency = 0.35 + 0.65 * lbl.TextTransparency
                end
            end

            RunService.RenderStepped:Wait()
        end
        if fala.token == meuToken then
            caixa.Visible = false
            caixa:ClearAllChildren()
            fala.prio = 0
            fala.fim = 0
        end
    end)
end

local function Falar(evento, forcar)
    if not FALAS_ATIVAS then return end
    local def = EVENTOS[evento]
    if not def then return end
    local agora = os.clock()
    if not forcar and math.random() > (def.chance or 1) then return end
    if agora - (falaUltimoUso[evento] or -999) < (def.recarga or 0) and def.prio < 5 then return end
    if agora < fala.fim then
        if def.prio <= fala.prio then return end        -- so interrompe se for mais importante
    elseif agora < fala.gapAte and def.prio < 4 then
        return                                          -- pequeno intervalo entre falas
    end
    local f = falaTexto(def, evento)
    falaUltimoUso[evento] = agora
    local texto = f[1]:gsub("{nome}", function() return NomeNaFala() end)
    falaMostrar(texto, f[2], f[3], def.prio)
end

-- Reacao a dano (chamada no loop de vida)
local function FalasDano(dano)
    if not Humanoid then return end
    if Humanoid.Health > 0 and Humanoid.Health / math.max(1, Humanoid.MaxHealth) < 0.25 then
        Falar("vida_baixa")
    end
    if dano >= 30 then Falar("dano_pesado") else Falar("dano") end
end

-- Falas automaticas: energia baixa e ocioso
task.spawn(function()
    local ultimaAtividade = os.clock()
    while true do
        task.wait(0.5)
        if FALAS_ATIVAS and Humanoid and Humanoid.Health > 0 then
            if State.IsSandiActive or (HRP and HRP.Velocity.Magnitude > 2) then
                ultimaAtividade = os.clock()
            end
            if not State.IsSandiActive and State.Energy < 15 then
                Falar("energia_baixa")
            end
            if os.clock() - ultimaAtividade > 45 and os.clock() > fala.gapAte then
                ultimaAtividade = os.clock() - 20
                Falar("ocioso")
            end
        end
    end
end)

local function ShowCooldownText(name: string, duration: number, color: Color3)
    task.spawn(function()
        local gui = Player.PlayerGui:FindFirstChild("CyberRebuilt")
        if not gui then return end
        
        local container = Create("Frame", {
            Size = UDim2.new(0, 220, 0, 42), 
            Position = UDim2.new(0.5, -110, 0.85, 0),
            BackgroundColor3 = Color3.fromRGB(8, 8, 12), 
            BackgroundTransparency = 0.05, 
            BorderSizePixel = 0, 
            Parent = gui
        })
        Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = container})
        
        local stroke = Create("UIStroke", {Color = color, Thickness = 2, Transparency = 0.2, Parent = container})
        
        local label = Create("TextLabel", {
            Size = UDim2.new(1, -20, 0.55, 0), 
            Position = UDim2.new(0, 10, 0, 4), 
            BackgroundTransparency = 1, 
            TextColor3 = color, 
            Font = Enum.Font.SciFi, 
            TextSize = 16, 
            TextXAlignment = Enum.TextXAlignment.Left, 
            Text = name:upper(), 
            Parent = container
        })
        
        local progressBar = Create("Frame", {
            Size = UDim2.new(1, -20, 0, 6), 
            Position = UDim2.new(0, 10, 1, -12), 
            BackgroundColor3 = Color3.fromRGB(20, 20, 25), 
            BorderSizePixel = 0, 
            Parent = container
        })
        Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = progressBar})
        
        local fillBar = Create("Frame", {
            Size = UDim2.new(1, 0, 1, 0), 
            BackgroundColor3 = color, 
            BorderSizePixel = 0, 
            Parent = progressBar
        })
        Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = fillBar})
        
        local timer = Create("TextLabel", {
            Size = UDim2.new(0, 50, 1, 0), 
            Position = UDim2.new(1, -55, 0, 0), 
            BackgroundTransparency = 1, 
            TextColor3 = Colors.UI_NEON, 
            Font = Enum.Font.Code, 
            TextSize = 16, 
            TextXAlignment = Enum.TextXAlignment.Right, 
            Text = string.format("%.1fs", duration), 
            Parent = container
        })
        
        table.insert(ActiveCooldownFrames, container)
        
        local myIndex = 0
        for i, v in ipairs(ActiveCooldownFrames) do 
            if v == container then 
                myIndex = i 
                break 
            end 
        end
        
        local targetPos = UDim2.new(0.5, -110, 0.72, -(myIndex - 1) * 50)
        
        TweenService:Create(container, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = targetPos
        }):Play()
        
        local startTime = os.clock()
        while os.clock() - startTime < duration do
            local remaining = math.max(0, duration - (os.clock() - startTime))
            local progress = remaining / duration
            timer.Text = string.format("%.1fs", remaining)
            fillBar.Size = UDim2.new(1 - progress, 0, 1, 0)
            
            local currentIndex = 0
            for i, v in ipairs(ActiveCooldownFrames) do 
                if v == container then 
                    currentIndex = i 
                    break 
                end 
            end
            if currentIndex > 0 then
                local newTarget = UDim2.new(0.5, -110, 0.72, -(currentIndex - 1) * 50)
                container.Position = container.Position:Lerp(newTarget, 0.3)
            end
            
            RunService.RenderStepped:Wait()
        end
        
        TweenService:Create(container, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -110, 0.85, 0),
            BackgroundTransparency = 1
        }):Play()
        
        TweenService:Create(label, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        TweenService:Create(timer, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        TweenService:Create(progressBar, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        TweenService:Create(fillBar, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
        
        task.wait(0.4)
        
        local index = 0
        for i, v in ipairs(ActiveCooldownFrames) do 
            if v == container then 
                index = i 
                break 
            end 
        end
        if index > 0 then 
            table.remove(ActiveCooldownFrames, index) 
        end
        
        container:Destroy()
    end)
end

local function CreateHologramClone(delay: number, duration: number, endTransparency: number, offsetX: number, offsetY: number, offsetZ: number, cloneType: string, customCFrame: CFrame?)
    if LiteMode then return end
    
    if not Character or not Character.Parent then return end
    if not HRP or not HRP.Parent then return end
    
    local sourceChar = Character
    
    local cloneColor
    if cloneType == "sandi" then
        cloneColor = Colors.RAINBOW_SEQUENCE[cloneColorIndex]
        cloneColorIndex = (cloneColorIndex % #Colors.RAINBOW_SEQUENCE) + 1
    elseif cloneType == "dash" then
        cloneColor = Color3.fromRGB(255, 80, 0)
    elseif cloneType == "dodge" then
        cloneColor = Colors.DODGE_START
    else
        cloneColor = Color3.new(1, 1, 1)
    end
    
    local hologramChar = nil
    local cloneSuccess = false
    
    task.spawn(function()
        local success, err = pcall(function()
            sourceChar.Archivable = true
            hologramChar = sourceChar:Clone()
            sourceChar.Archivable = false
        end)
        
        if not success or not hologramChar then
            pcall(function()
                hologramChar = Instance.new("Model")
                hologramChar.Name = "HologramClone_Fallback"
                local part = Instance.new("Part")
                part.Size = Vector3.new(2, 5.5, 1)
                part.Anchored = true
                part.CanCollide = false
                part.Transparency = 0.4
                part.Color = cloneColor
                part.Material = Configurations.HOLOGRAM_MATERIAL
                part.CastShadow = false
                part.Parent = hologramChar
                hologramChar.PrimaryPart = part
            end)
        end
        
        cloneSuccess = true
    end)
    
    local waitStart = tick()
    while not cloneSuccess and tick() - waitStart < 2.0 do
        task.wait(0.05)
    end
    
    if not hologramChar then return end
    
    local function safeDestroy(obj)
        pcall(function()
            if obj and obj.Parent then obj:Destroy() end
        end)
    end
    
    for _, obj in pairs(hologramChar:GetDescendants()) do
        pcall(function()
            if obj:IsA("LuaSourceContainer") or obj:IsA("Sound") then
                safeDestroy(obj)
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                safeDestroy(obj)
            elseif obj:IsA("BasePart") then
                obj.CanCollide = false
                obj.Anchored = true
                obj.CastShadow = false
                if obj.Name == "HumanoidRootPart" then
                    obj.Transparency = 1
                else
                    obj.Transparency = 0.30
                    obj.Color = cloneColor
                    obj.Material = Configurations.HOLOGRAM_MATERIAL
                    if obj:IsA("MeshPart") then obj.TextureID = "" end
                end
            end
        end)
    end
    
    for _, accessory in pairs(hologramChar:GetChildren()) do
        pcall(function()
            if accessory:IsA("Accessory") then
                local handle = accessory:FindFirstChild("Handle")
                if handle then
                    handle.CanCollide = false
                    handle.Anchored = true
                    handle.CastShadow = false
                    handle.Transparency = 0.30
                    handle.Color = cloneColor
                    handle.Material = Configurations.HOLOGRAM_MATERIAL
                    if handle:IsA("MeshPart") then handle.TextureID = "" end
                end
                for _, part in pairs(accessory:GetDescendants()) do
                    if part:IsA("BasePart") and part ~= handle then
                        part.CanCollide = false
                        part.Anchored = true
                        part.CastShadow = false
                        part.Transparency = 0.30
                        part.Color = cloneColor
                        part.Material = Configurations.HOLOGRAM_MATERIAL
                        if part:IsA("MeshPart") then part.TextureID = "" end
                    elseif part:IsA("Decal") or part:IsA("Texture") then
                        safeDestroy(part)
                    end
                end
            end
        end)
    end
    
    local humanoid = hologramChar:FindFirstChildOfClass("Humanoid")
    if humanoid then safeDestroy(humanoid) end
    local animateFolder = hologramChar:FindFirstChild("Animate")
    if animateFolder then safeDestroy(animateFolder) end
    for _, obj in ipairs(hologramChar:GetChildren()) do
        pcall(function()
            if obj:IsA("Script") or obj:IsA("localScript") or obj:IsA("ModuleScript") or 
               obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or 
               obj:IsA("BindableEvent") or obj:IsA("BindableFunction") or 
               obj:IsA("Animator") then
                safeDestroy(obj)
            end
        end)
    end
    
    local hologramRoot = hologramChar:FindFirstChild("HumanoidRootPart")
    if not hologramRoot then
        hologramRoot = hologramChar.PrimaryPart
        if not hologramRoot then
            local tempRoot = Instance.new("Part")
            tempRoot.Name = "FakeRoot"
            tempRoot.Size = Vector3.new(1, 1, 1)
            tempRoot.Transparency = 1
            tempRoot.CanCollide = false
            tempRoot.Anchored = true
            tempRoot.Parent = hologramChar
            hologramRoot = tempRoot
            hologramChar.PrimaryPart = hologramRoot
        end
    end
    
    if hologramRoot and HRP then
        pcall(function()
            if customCFrame and typeof(customCFrame) == "CFrame" then
                hologramRoot.CFrame = customCFrame
            else
                hologramRoot.CFrame = HRP.CFrame * CFrame.new(offsetX or 0, offsetY or 0, offsetZ or 0)
            end
            hologramChar.PrimaryPart = hologramRoot
        end)
    end
    
    if cloneType == "sandi" then
        hologramChar.Name = "HologramClone"
        local tag = Instance.new("BoolValue")
        tag.Name = "IsSandiClone"
        tag.Value = true
        tag.Parent = hologramChar
    end
    
    -- ==========================================
    -- 🔥 HIGHLIGHT CONFIGURÁVEL VIA CONSTANTS
    -- ==========================================
    if cloneType ~= "glitch" and Constants.HIGHLIGHT_CONFIG.ENABLED then
        pcall(function()
            local highlight = Instance.new("Highlight")
            
            -- Aplica transparências iniciais
            highlight.FillTransparency = Constants.HIGHLIGHT_CONFIG.INITIAL_FILL_TRANS
            highlight.OutlineTransparency = Constants.HIGHLIGHT_CONFIG.INITIAL_OUTLINE_TRANS
            highlight.DepthMode = Enum.HighlightDepthMode.Occluded
            
            -- Define cores baseadas no tipo
            local colorConfig = Constants.HIGHLIGHT_CONFIG.COLORS[cloneType]
            if colorConfig then
                if cloneType == "sandi" and colorConfig.outline == "RAINBOW" then
                    local c = Colors.RAINBOW_SEQUENCE[cloneColorIndex]
                    highlight.OutlineColor = c
                    highlight.FillColor = c
                    cloneColorIndex = (cloneColorIndex % #Colors.RAINBOW_SEQUENCE) + 1
                else
                    highlight.OutlineColor = colorConfig.outline
                    highlight.FillColor = colorConfig.fill
                end
            end
            
            highlight.Parent = hologramChar
            highlight.Adornee = hologramChar
            
            -- Fade-in
            TweenService:Create(highlight, TweenInfo.new(Constants.HIGHLIGHT_CONFIG.FADEIN_DURATION), {
                FillTransparency = Constants.HIGHLIGHT_CONFIG.FADEIN_FILL_TRANS,
                OutlineTransparency = Constants.HIGHLIGHT_CONFIG.FADEIN_OUTLINE_TRANS
            }):Play()
            
            -- Coleta partes do corpo (exceto HRP)
            local bodyParts = {}
            for _, p in pairs(hologramChar:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                    table.insert(bodyParts, p)
                end
            end
            
            -- Fade-out programado
            task.spawn(function()
                local waitTime = duration * Constants.HIGHLIGHT_CONFIG.FADEOUT_START_FACTOR
                task.wait(waitTime)
                
                if not hologramChar or not hologramChar.Parent then return end
                if not highlight or not highlight.Parent then return end
                
                local fadeOutTime = duration * Constants.HIGHLIGHT_CONFIG.FADEOUT_DURATION_FACTOR
                
                local hlFadeOut = TweenService:Create(highlight, TweenInfo.new(fadeOutTime), {
                    FillTransparency = 1,
                    OutlineTransparency = 1
                })
                hlFadeOut:Play()
                
                -- Fade das partes
                for _, part in ipairs(bodyParts) do
                    pcall(function()
                        TweenService:Create(part, TweenInfo.new(fadeOutTime), { Transparency = 1 }):Play()
                    end)
                end
                
                hlFadeOut.Completed:Connect(function()
                    pcall(function() if hologramChar and hologramChar.Parent then hologramChar:Destroy() end end)
                end)
            end)
            
            -- Ciclo de cores para dash/dodge (se ativado)
            if Constants.HIGHLIGHT_CONFIG.ENABLE_COLOR_CYCLE and (cloneType == "dash" or cloneType == "dodge") then
                task.spawn(function()
                    local palette
                    if cloneType == "dash" then
                        palette = {
                            Color3.fromRGB(255, 40, 40), 
                            Color3.fromRGB(255, 130, 30), 
                            Color3.fromRGB(255, 215, 40)
                        }
                    else
                        palette = {
                            Color3.fromRGB(0, 255, 90), 
                            Color3.fromRGB(80, 255, 170), 
                            Color3.fromRGB(0, 230, 255)
                        }
                    end
                    
                    local startTime = tick()
                    local lastUpdate = 0
                    
                    while highlight.Parent and tick() - startTime < duration do
                        local currentTime = tick()
                        if currentTime - lastUpdate > 0.08 then
                            local progress = (currentTime - startTime) / duration
                            local idx = math.floor(progress * (#palette - 1)) + 1
                            local nextIdx = math.min(idx + 1, #palette)
                            local frac = (progress * (#palette - 1)) % 1
                            local current = palette[idx]:Lerp(palette[nextIdx], frac)
                            pcall(function()
                                highlight.OutlineColor = current
                            end)
                            lastUpdate = currentTime
                        end
                        RunService.Heartbeat:Wait()
                    end
                end)
            end
        end)
    end
    
    -- Colocar no workspace
    pcall(function()
        hologramChar.Parent = Workspace
    end)
end

local function TriggerSandevistanFailure()
    PlaySFX(Sounds.SANDI_FAILURE)
    Falar("sandi_falha", true)
    local gui = Player.PlayerGui:FindFirstChild("CyberRebuilt") or Instance.new("ScreenGui", Player.PlayerGui)
    gui.Name = "CyberRebuilt"
    local errorFrame = Create("Frame", {Size = UDim2.new(0, 400, 0, 120), Position = UDim2.new(0.5, -200, 0.28, 0), BackgroundColor3 = Color3.fromRGB(25, 8, 0), BorderSizePixel = 0, Parent = gui})
    Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = errorFrame})
    local stroke = Create("UIStroke", {Color = Color3.fromRGB(255, 160, 30), Thickness = 4, Parent = errorFrame})
    local title = Create("TextLabel", {Size = UDim2.new(1,0,0.55,0), BackgroundTransparency = 1, Text = "SANDEVISTAN", TextColor3 = Color3.fromRGB(255, 200, 50), Font = Enum.Font.SciFi, TextSize = 42, TextStrokeTransparency = 0.3, Parent = errorFrame})
    local subtitle = Create("TextLabel", {Size = UDim2.new(1,0,0.45,0), Position = UDim2.new(0,0,0.55,0), BackgroundTransparency = 1, Text = "OVERLOAD - CALIBRATION REQUIRED", TextColor3 = Color3.fromRGB(255, 180, 60), Font = Enum.Font.Code, TextSize = 18, Parent = errorFrame})
    task.spawn(function()
        for i = 1, 8 do
            title.TextTransparency = i % 2 == 0 and 0.7 or 0
            task.wait(0.05)
        end
    end)
    task.delay(0.8, function() errorFrame:Destroy() end)
    if math.random() < 0.15 then 
    task.wait(0.2) 
    pcall(function() ExecCyberpsychosis() end)
end
    State.Cooldowns.SANDI = os.clock() + 9
    State.NoRegenUntil = os.clock() + 9.5
    ShowCooldownText("SANDEVISTAN OVERLOAD", 9, Color3.fromRGB(255, 160, 30))
end

local function ApplyGlitchEffect()
    if LiteMode then return end
    task.spawn(function()
        local start = os.clock()
        local cc = Instance.new("ColorCorrectionEffect", Lighting)
        local blur = Instance.new("BlurEffect", Lighting)
        blur.Size = 0
        while os.clock() - start < 2.2 do
            CreateHologramClone(0, 0.08, 0.95, math.random(-3,3), math.random(-1,1), math.random(-3,3), "glitch")
            CamShake(0.65, 0.1)
            cc.Saturation = math.random(-2, 0.8)
            cc.Contrast = math.random(-1.5, 2)
            cc.TintColor = Color3.fromHSV(math.random(), 0.9, 1)
            blur.Size = math.random(12, 24)
            task.wait(0.055)
        end
        TweenService:Create(cc, TweenInfo.new(0.6), {Saturation = 0, Contrast = 0}):Play()
        TweenService:Create(blur, TweenInfo.new(0.6), {Size = 0}):Play()
        task.delay(0.7, function() cc:Destroy() blur:Destroy() end)
    end)
end

local function lineEffect(gui)
    if lineObject and lineObject.Parent then
        lineObject:Destroy()
    end
    
    if not lineEnabled then return end
    
    lineObject = Create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = gui
    })
    
    local line = Create("Frame", {
        Size = UDim2.new(1, -80, 0, 1.5),
        Position = UDim2.new(0, 40, -0.02, 0),
        BackgroundColor3 = Color3.fromRGB(0, 255, 200),
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        ZIndex = 10,
        Parent = lineObject
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = line})
    
    local glow = Create("Frame", {
        Size = UDim2.new(1, -60, 0, 5),
        Position = UDim2.new(0, 30, -0.02, -1.5),
        BackgroundColor3 = Color3.fromRGB(0, 255, 200),
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        ZIndex = 9,
        Parent = lineObject
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = glow})
    
    for i = 1, 4 do
        local decorLine = Create("Frame", {
            Size = UDim2.new(1, math.random(-20, 20), 0, 0.5),
            Position = UDim2.new(0, math.random(10, 30), 0, math.random(10, 90) / 100),
            BackgroundColor3 = Color3.fromRGB(0, 255, 200),
            BackgroundTransparency = 0.9,
            BorderSizePixel = 0,
            ZIndex = 4,
            Parent = lineObject
        })
        Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = decorLine})
        
        task.spawn(function()
            while decorLine and decorLine.Parent do
                task.wait(math.random(4, 10))
                TweenService:Create(decorLine, TweenInfo.new(0.08), {
                    BackgroundTransparency = 0.5
                }):Play()
                task.wait(0.08)
                TweenService:Create(decorLine, TweenInfo.new(0.25), {
                    BackgroundTransparency = 0.9
                }):Play()
            end
        end)
    end
    
    task.spawn(function()
        while lineObject and lineObject.Parent do
            if math.random() < 0.25 then
                local particle = Create("Frame", {
                    Size = UDim2.new(0, 1.5, 0, 1.5),
                    Position = UDim2.new(0, math.random(30, 90) / 100 * Camera.ViewportSize.X, 0, math.random(0, 100) / 100 * Camera.ViewportSize.Y),
                    BackgroundColor3 = Color3.fromRGB(0, 255, 200),
                    BackgroundTransparency = 0.5,
                    BorderSizePixel = 0,
                    ZIndex = 5,
                    Parent = lineObject
                })
                Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = particle})
                
                TweenService:Create(particle, TweenInfo.new(0.7), {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, particle.Position.X.Offset + math.random(-15, 15), 0, particle.Position.Y.Offset + 25)
                }):Play()
                
                task.delay(0.8, function() particle:Destroy() end)
            end
            task.wait(0.06)
        end
    end)
    
    task.spawn(function()
        while line and line.Parent do
            line.Position = UDim2.new(0, 40, -0.02, 0)
            glow.Position = UDim2.new(0, 30, -0.02, -1.5)
            
            local duration = 5
            
            TweenService:Create(line, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
                Position = UDim2.new(0, 40, 1.02, 0)
            }):Play()
            
            TweenService:Create(glow, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
                Position = UDim2.new(0, 30, 1.02, -1.5)
            }):Play()
            
            task.spawn(function()
                for i = 1, 30 do
                    if not line.Parent then break end
                    local pulse = math.sin(i * 0.25) * 0.1
                    line.BackgroundTransparency = 0.4 + pulse
                    glow.BackgroundTransparency = 0.82 + pulse
                    task.wait(0.17)
                end
            end)
            
            task.wait(duration + 0.2)
        end
    end)
end

local function Toggleline()
    lineEnabled = not lineEnabled
    local gui = Player.PlayerGui:FindFirstChild("CyberRebuilt")
    if not gui then return end
    if lineEnabled then
        lineEffect(gui)
    else
        if lineObject and lineObject.Parent then
            lineObject:Destroy()
            lineObject = nil
        end
    end
end

local function PulseAnimation(object)
    task.spawn(function()
        while object.Parent do
            TweenService:Create(object, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Size = UDim2.new(1.05, 0, 1.05, 0)
            }):Play()
            task.wait(0.8)
            TweenService:Create(object, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Size = UDim2.new(1, 0, 1, 0)
            }):Play()
            task.wait(0.8)
        end
    end)
end

local function createLightingEffects()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "PsychoCC"
	cc.TintColor = Color3.fromRGB(255, 80, 80)
	cc.Contrast = 0.6
	cc.Saturation = 1.3
	cc.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Name = "PsychoBlur"
	blur.Size = 0
	blur.Parent = Lighting
	return cc, blur
end

local function spawnPopup()
    if not HRP then return end
    
    local angleHorizontal = math.random() * math.pi * 2
    local angleVertical = math.random(-0.6, 0.6) * math.pi
local radius = math.random(5.5, 8)
local heightOffset = math.random(-1, 3)
    
    local orbitX = math.cos(angleHorizontal) * math.cos(angleVertical) * radius
    local orbitY = math.sin(angleVertical) * radius + heightOffset
    local orbitZ = math.sin(angleHorizontal) * math.cos(angleVertical) * radius
    
    local targetWidth = math.random(3.2, 5.5)
local targetHeight = math.random(2.0, 4.0)
    local finalSize = Vector3.new(targetWidth, targetHeight, 0.07)
    
    local part = Instance.new("Part")
    part.Name = "GlitchWindow"
    part.Size = Vector3.new(0, 0, 0)
    part.Color = Color3.fromRGB(9, 0, 2)
    part.Material = Enum.Material.Neon
    part.Transparency = 0.02
    part.CanCollide = false
    part.Anchored = true
    part.CastShadow = false
    
    part.Position = HRP.Position + Vector3.new(orbitX, orbitY, orbitZ)
    
    local look = CFrame.lookAt(part.Position, HRP.Position)
    part.CFrame = look * CFrame.Angles(math.rad(math.random(-15, 15)), math.rad(math.random(-20, 20)), 0)
    part.Parent = Workspace
    
    local sgui = Instance.new("SurfaceGui")
    sgui.Face = Enum.NormalId.Front
    sgui.LightInfluence = 0
    sgui.PixelsPerStud = 50
    sgui.Parent = part
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,0,1,0)
    frame.BackgroundColor3 = Color3.fromRGB(6,0,1)
    frame.BackgroundTransparency = 1
    frame.Parent = sgui
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 25, 60)
    stroke.Thickness = 4
    stroke.Transparency = 1
    stroke.Parent = frame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,-16,0.72,0)
    label.Position = UDim2.new(0,8,0,5)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 50, 80)
    label.TextScaled = true
    label.Font = Enum.Font.SciFi
    label.Text = Constants.ERROR_TEXTS[math.random(1, #Constants.ERROR_TEXTS)]
    label.TextStrokeTransparency = 0.4
    label.TextStrokeColor3 = Color3.fromRGB(255,0,25)
    label.TextTransparency = 1
    label.Parent = frame
    
    local sublabel = Instance.new("TextLabel")
    sublabel.Size = UDim2.new(1,-16,0.28,-8)
    sublabel.Position = UDim2.new(0,8,0.72,4)
    sublabel.BackgroundTransparency = 1
    sublabel.TextColor3 = Color3.fromRGB(255, 125, 140)
    sublabel.Font = Enum.Font.Code
    sublabel.TextScaled = true
    sublabel.Text = "0x"..string.format("%X", math.random(0x8000,0xFFFF)) .. "_NEURAL_CRITICAL"
    sublabel.TextTransparency = 1
    sublabel.Parent = frame
    
    TweenService:Create(part, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = finalSize
    }):Play()
    
    TweenService:Create(frame, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0
    }):Play()
    
    TweenService:Create(stroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 0
    }):Play()
    
    task.spawn(function()
        for i = 1, 6 do
            label.TextTransparency = i % 2 == 0 and 0.7 or 0.1
            task.wait(0.025)
        end
        TweenService:Create(label, TweenInfo.new(0.08), {
            TextTransparency = 0
        }):Play()
    end)
    
    task.delay(0.08, function()
        TweenService:Create(sublabel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            TextTransparency = 0
        }):Play()
    end)
    
    task.delay(Constants.CYBERPSYCHOSIS.WindowLifeTime - 0.3, function()
        if not part.Parent then return end
        
        TweenService:Create(label, TweenInfo.new(0.15), {TextTransparency = 1}):Play()
        TweenService:Create(sublabel, TweenInfo.new(0.15), {TextTransparency = 1}):Play()
        TweenService:Create(frame, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency = 1}):Play()
        
        local closeTween = TweenService:Create(part, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = Vector3.new(0, 0, 0)
        })
        closeTween:Play()
        closeTween.Completed:Connect(function()
            part:Destroy()
        end)
    end)
end

local function shakeCamera()
	if not Humanoid then return end
	local intensity = Constants.CYBERPSYCHOSIS.ShakeIntensity
	Humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * intensity, (math.random() - 0.5) * intensity, (math.random() - 0.5) * intensity)
end

local function SystemRestorePopup()
    if not HRP then return end
    
    local restoreSound = Instance.new("Sound")
    restoreSound.SoundId = "rbxassetid://97097078816969"
    restoreSound.Volume = 2
    restoreSound.PlaybackSpeed = 1
    restoreSound.Parent = HRP or Camera
    restoreSound:Play()
    Debris:AddItem(restoreSound, 5)
    
    local part = Instance.new("Part")
    part.Name = "SystemRestoreWindow"
    part.Size = Vector3.new(0, 0, 0.08)
    part.Color = Color3.fromRGB(0, 40, 0)
    part.Material = Enum.Material.Neon
    part.Transparency = 0.03
    part.CanCollide = false
    part.Anchored = true
    part.CastShadow = false
    
    local frontOffset = HRP.CFrame.LookVector * 7 + Vector3.new(0, 1.5, 0)
    part.CFrame = CFrame.lookAt(HRP.Position + frontOffset, HRP.Position)
    part.Parent = Workspace
    
    local sgui = Instance.new("SurfaceGui", part)
    sgui.Face = Enum.NormalId.Front
    sgui.LightInfluence = 0
    sgui.PixelsPerStud = 65
    
    local frame = Instance.new("Frame", sgui)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(0, 12, 0)
    frame.BackgroundTransparency = 1
    
    local frameCorner = Instance.new("UICorner", frame)
    frameCorner.CornerRadius = UDim.new(0, 8)
    
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(0, 220, 0)
    stroke.Thickness = 5
    stroke.Transparency = 1
    
    local titleBar = Instance.new("Frame", frame)
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.BackgroundColor3 = Color3.fromRGB(0, 50, 0)
    titleBar.BackgroundTransparency = 1
    titleBar.BorderSizePixel = 0
    
    local titleCorner = Instance.new("UICorner", titleBar)
    titleCorner.CornerRadius = UDim.new(0, 6)
    
    local icon = Instance.new("TextLabel", titleBar)
    icon.Size = UDim2.new(0, 26, 0, 26)
    icon.Position = UDim2.new(0, 10, 0, 4)
    icon.BackgroundTransparency = 1
    icon.Text = ""
    icon.TextColor3 = Color3.fromRGB(0, 255, 0)
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 20
    icon.TextTransparency = 1
    
    local titleText = Instance.new("TextLabel", titleBar)
    titleText.Size = UDim2.new(1, -80, 1, 0)
    titleText.Position = UDim2.new(0, 40, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "SYSTEM RESTORE"
    titleText.TextColor3 = Color3.fromRGB(0, 255, 0)
    titleText.Font = Enum.Font.SciFi
    titleText.TextSize = 17
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.TextTransparency = 1
    
    local closeBtn = Instance.new("TextButton", titleBar)
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -32, 0, 4)
    closeBtn.BackgroundColor3 = Color3.fromRGB(0, 70, 0)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = ""
    closeBtn.TextColor3 = Color3.fromRGB(0, 255, 0)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextTransparency = 1
    
    local closeCorner = Instance.new("UICorner", closeBtn)
    closeCorner.CornerRadius = UDim.new(0, 4)
    
    local message = Instance.new("TextLabel", frame)
    message.Size = UDim2.new(1, -30, 0, 55)
    message.Position = UDim2.new(0, 15, 0, 55)
    message.BackgroundTransparency = 1
    message.Text = "SUCESSO AO\nRESTABELECER\nO SYSTEMA"
    message.TextColor3 = Color3.fromRGB(0, 255, 0)
    message.Font = Enum.Font.SciFi
    message.TextSize = 42
    message.TextTransparency = 1
    message.TextStrokeTransparency = 0.4
    message.TextStrokeColor3 = Color3.fromRGB(0, 100, 0)
    
    local details = Instance.new("TextLabel", frame)
    details.Size = UDim2.new(1, -30, 0, 30)
    details.Position = UDim2.new(0, 15, 0, 130)
    details.BackgroundTransparency = 1
    details.Text = "NEURAL INTERFACE RESTORED\nALL SYSTEMS OPERATIONAL"
    details.TextColor3 = Color3.fromRGB(100, 255, 100)
    details.Font = Enum.Font.Code
    details.TextSize = 18
    details.TextTransparency = 1
    
    local progressBg = Instance.new("Frame", frame)
    progressBg.Size = UDim2.new(0.85, 0, 0, 10)
    progressBg.Position = UDim2.new(0.075, 0, 0, 175)
    progressBg.BackgroundColor3 = Color3.fromRGB(0, 15, 0)
    progressBg.BackgroundTransparency = 1
    progressBg.BorderSizePixel = 0
    
    local progressCorner = Instance.new("UICorner", progressBg)
    progressCorner.CornerRadius = UDim.new(0, 5)
    
    local progressFill = Instance.new("Frame", progressBg)
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    progressFill.BackgroundTransparency = 1
    progressFill.BorderSizePixel = 0
    
    local fillCorner = Instance.new("UICorner", progressFill)
    fillCorner.CornerRadius = UDim.new(0, 5)
    
    local percentText = Instance.new("TextLabel", frame)
    percentText.Size = UDim2.new(1, 0, 0, 22)
    percentText.Position = UDim2.new(0, 0, 0, 190)
    percentText.BackgroundTransparency = 1
    percentText.Text = "0%"
    percentText.TextColor3 = Color3.fromRGB(0, 255, 0)
    percentText.Font = Enum.Font.Code
    percentText.TextSize = 16
    percentText.TextTransparency = 1
    
    local scanline = Instance.new("Frame", frame)
    scanline.Size = UDim2.new(1, 0, 0, 2)
    scanline.Position = UDim2.new(0, 0, -1, 0)
    scanline.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    scanline.BackgroundTransparency = 0.6
    scanline.BorderSizePixel = 0
    
    local function updatePosition()
        if HRP and part.Parent then
            local frontOffset = HRP.CFrame.LookVector * 7 + Vector3.new(0, 1.5, 0)
            part.CFrame = CFrame.lookAt(HRP.Position + frontOffset, HRP.Position)
        end
    end
    updatePosition()
    
    TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = Vector3.new(5.5, 3.2, 0.08)
    }):Play()
    
    task.delay(0.15, function()
        TweenService:Create(frame, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.3), {Transparency = 0}):Play()
        TweenService:Create(titleBar, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
        TweenService:Create(icon, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
        TweenService:Create(titleText, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
        TweenService:Create(closeBtn, TweenInfo.new(0.3), {BackgroundTransparency = 0, TextTransparency = 0}):Play()
        TweenService:Create(message, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
        TweenService:Create(details, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
        TweenService:Create(progressBg, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
        TweenService:Create(progressFill, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
        TweenService:Create(percentText, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
    end)
    
    local followConn = RunService.Heartbeat:Connect(updatePosition)
    
    task.delay(0.6, function()
        TweenService:Create(progressFill, TweenInfo.new(2, Enum.EasingStyle.Linear), {
            Size = UDim2.new(1, 0, 1, 0)
        }):Play()
        
        for i = 0, 100, 2 do
            task.wait(0.04)
            if percentText and percentText.Parent then
                percentText.Text = i .. "%"
            end
        end
    end)
    
    task.spawn(function()
        while scanline.Parent do
            TweenService:Create(scanline, TweenInfo.new(1.5, Enum.EasingStyle.Linear), {
                Position = UDim2.new(0, 0, 1, 0)
            }):Play()
            task.wait(1.5)
            scanline.Position = UDim2.new(0, 0, -1, 0)
        end
    end)
    
    task.spawn(function()
        task.wait(1.5)
        
        if Humanoid then
            TweenService:Create(Humanoid, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Health = Humanoid.MaxHealth
            }):Play()
        end
        
        local targetEnergy = math.min(Constants.MAX_ENERGY, State.Energy + 50)
        local startEnergy = State.Energy
        local duration = 1.5
        local startTime = tick()
        
        task.spawn(function()
            while tick() - startTime < duration do
                local alpha = (tick() - startTime) / duration
                State.Energy = startEnergy + (targetEnergy - startEnergy) * alpha
                RunService.Heartbeat:Wait()
            end
            State.Energy = targetEnergy
        end)
        
        ScreenFade(0.2, 0, 0.5, Color3.fromRGB(0, 255, 0), 0.4, 0.2)
    end)
    
    local function closeWindow()
        if followConn then followConn:Disconnect() end
        if part and part.Parent then
            TweenService:Create(part, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Size = Vector3.new(0.1, 0.1, 0.08)
            }):Play()
            TweenService:Create(frame, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
            task.delay(0.5, function()
                part:Destroy()
            end)
        end
    end
    
    task.delay(4, function()
        if part and part.Parent then
            closeWindow()
        end
    end)
end

function ExecCyberpsychosis()
    Falar("psicose", true)
    PlaySFX(Sounds.PSYCHOSIS)
    PlaySFX(Sounds.PSYCHOSIS2)
    
task.spawn(function()
    spawnPopup()
    task.wait(0.30)
    
    spawnPopup()
    task.wait(0.25)
    
    spawnPopup()
    spawnPopup()
    task.wait(0.25)
    
    spawnPopup()
    task.wait(0.25)
    
    spawnPopup()
    task.wait(0.20)
    
    for i = 1, 7 do
        spawnPopup()
        task.wait(0.06)
    end
    task.wait(0.30)
    
    for i = 1, 3 do
        spawnPopup()
        task.wait(0.15)
    end
    task.wait(0.30)
    
    spawnPopup()
    spawnPopup()
    task.wait(0.35)
    
    spawnPopup()
    spawnPopup()
    task.wait(0.40)
    
    for i = 1, 5 do
        spawnPopup()
        task.wait(0.08)
    end
    task.wait(0.35)
    
    for i = 1, 14 do
        spawnPopup()
        task.wait(0.04)
    end
end)

    if Humanoid then Humanoid.WalkSpeed = 0 Humanoid.JumpPower = 0 end
    
    if Lighting:FindFirstChild("SandiEffect") then Lighting.SandiEffect:Destroy() end
    local cc, blur = createLightingEffects()
    local startTime = tick()
    local connection
    
    local gui = Player.PlayerGui:FindFirstChild("CyberRebuilt") or Create("ScreenGui", {Name = "CyberRebuilt", Parent = Player.PlayerGui, IgnoreGuiInset = true})

local psychoImage = Instance.new("ImageLabel")
psychoImage.Name = "PsychoImage"
psychoImage.Size = UDim2.new(0, 200, 0, 200)
psychoImage.Position = UDim2.new(1, -220, 0, 10)
psychoImage.BackgroundTransparency = 1
psychoImage.Image = "rbxassetid://138778899925146"
psychoImage.ImageTransparency = 1
psychoImage.ZIndex = 10
psychoImage.Parent = gui

psychoImage.Position = UDim2.new(1.2, 0, 0, 10)
TweenService:Create(psychoImage, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Position = UDim2.new(1, -220, 0, 10),
    ImageTransparency = 0
}):Play()

task.spawn(function()
    task.wait(0.5)
    local piscaStart = tick()
    while psychoImage.Parent and tick() - piscaStart < Constants.CYBERPSYCHOSIS.Duration - 0.7 do
        local targetTransparency = math.random(20, 55) / 100
        TweenService:Create(psychoImage, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            ImageTransparency = targetTransparency
        }):Play()
        task.wait(0.35)
    end
end)

task.delay(Constants.CYBERPSYCHOSIS.Duration - 0.6, function()
    if psychoImage and psychoImage.Parent then
        TweenService:Create(psychoImage, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(1.2, 0, 0, 10),
            ImageTransparency = 1
        }):Play()
        task.delay(0.6, function()
            psychoImage:Destroy()
        end)
    end
end)

    local vignette = Create("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 0.5, BackgroundColor3 = Color3.new(0, 0, 0), Parent = gui})
    local vignetteGradient = Create("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.5), NumberSequenceKeypoint.new(1, 1)}), Rotation = 0, Parent = vignette})
    task.spawn(function()
        while vignette.Parent do
            TweenService:Create(vignette, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0.3}):Play()
            task.wait(0.5)
            TweenService:Create(vignette, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0.7}):Play()
            task.wait(0.5)
        end
    end)
    local psychosisText = Create("TextLabel", {Size = UDim2.new(1, 0, 0.2, 0), Position = UDim2.new(0, 0, 0.4, 0), BackgroundTransparency = 1, Text = "CYBERPSYCHOSIS", TextColor3 = Color3.fromRGB(255, 0, 0), Font = Enum.Font.SciFi, TextSize = 80, TextTransparency = 0.5, Parent = gui})
    task.spawn(function()
        while psychosisText.Parent do
            TweenService:Create(psychosisText, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
            task.wait(0.2)
            TweenService:Create(psychosisText, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
            task.wait(0.2)
        end
    end)
    
    local redOverlay = Create("ImageLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ImageColor3 = Color3.fromRGB(255, 0, 0), ImageTransparency = 0.8, Parent = gui})
    local blueOverlay = Create("ImageLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ImageColor3 = Color3.fromRGB(0, 0, 255), ImageTransparency = 0.8, Parent = gui})
    task.spawn(function()
        while redOverlay.Parent do
            redOverlay.Position = UDim2.new(0, math.random(-2, 2), 0, math.random(-2, 2))
            blueOverlay.Position = UDim2.new(0, math.random(-2, 2), 0, math.random(-2, 2))
            task.wait(0.05)
        end
    end)
    
    local phaseDuration = Constants.CYBERPSYCHOSIS.Duration / 3
    local currentPhase = 1
    local syncTimesDistortion = {0.3, 1.4, 2.7, 3.55, 4.05, 4.55, 5.1}
    for _, t in ipairs(syncTimesDistortion) do
        task.delay(t, function()
            TweenService:Create(vignette, TweenInfo.new(0.1), {BackgroundTransparency = 0}):Play()
            TweenService:Create(psychosisText, TweenInfo.new(0.1), {TextTransparency = 0}):Play()
            task.wait(0.1)
            TweenService:Create(vignette, TweenInfo.new(0.1), {BackgroundTransparency = 0.5}):Play()
            TweenService:Create(psychosisText, TweenInfo.new(0.1), {TextTransparency = 0.5}):Play()
        end)
    end
    
    
        connection = RunService.RenderStepped:Connect(function(dt)
        local elapsed = tick() - startTime
    
    local fadeStartTime = 5.5
    
    if elapsed > fadeStartTime then
        local fadeProgress = (elapsed - fadeStartTime) / 0.5
        fadeProgress = math.clamp(fadeProgress, 0, 1)
        
        if blur then
            blur.Size = math.random(4, 12) * (1 - fadeProgress)
        end
        
        Constants.CYBERPSYCHOSIS.ShakeIntensity = 1.0 * (1 - fadeProgress)
        
        if cc then
            local normalColor = Color3.fromRGB(255, 80, 80):Lerp(Color3.new(1, 1, 1), fadeProgress)
            cc.TintColor = normalColor
            cc.Saturation = 1.3 * (1 - fadeProgress)
            cc.Contrast = 0.6 * (1 - fadeProgress)
        end
        
        if vignette and vignette.Parent then
            vignette.BackgroundTransparency = 0.5 + (fadeProgress * 0.5)
        end
        
        if psychosisText and psychosisText.Parent then
            psychosisText.TextTransparency = fadeProgress
        end
        
        if redOverlay and redOverlay.Parent then
            redOverlay.ImageTransparency = 0.8 + (fadeProgress * 0.2)
        end
        if blueOverlay and blueOverlay.Parent then
            blueOverlay.ImageTransparency = 0.8 + (fadeProgress * 0.2)
        end
    end
    
    if elapsed > Constants.CYBERPSYCHOSIS.Duration then
            if Humanoid then Humanoid.WalkSpeed = 16 Humanoid.JumpPower = 50 Humanoid.CameraOffset = Vector3.zero end
            TweenService:Create(cc, TweenInfo.new(0.5), {TintColor = Color3.new(1,1,1), Saturation = 0}):Play()
            TweenService:Create(blur, TweenInfo.new(0.5), {Size = 0}):Play()
            Debris:AddItem(cc, 0.5)
            Debris:AddItem(blur, 0.5)
            connection:Disconnect()
            
            if math.random(1, 100) <= 30 then
                task.delay(0.5, function()
                    SystemRestorePopup()
                end)
            end
            
            vignette:Destroy()
            psychosisText:Destroy()
            redOverlay:Destroy()
            blueOverlay:Destroy()
            return
        end
        
        if Humanoid and Humanoid.Health > 0 then
            local drainRate = 0
            
            if elapsed < phaseDuration then
                currentPhase = 1
                drainRate = Humanoid.MaxHealth * 0.05 * dt
                Constants.CYBERPSYCHOSIS.ShakeIntensity = 0.2
                Constants.CYBERPSYCHOSIS.PopupRate = 0.05
                blur.Size = math.random(2, 6)
                
            elseif elapsed < phaseDuration * 2 then
                currentPhase = 2
                drainRate = Humanoid.MaxHealth * 0.08 * dt
                Constants.CYBERPSYCHOSIS.ShakeIntensity = 0.6
                Constants.CYBERPSYCHOSIS.PopupRate = 0.1
                blur.Size = math.random(8, 16)
                
            else
                currentPhase = 3
                drainRate = Humanoid.MaxHealth * 0.12 * dt
                Constants.CYBERPSYCHOSIS.ShakeIntensity = 1.0
                Constants.CYBERPSYCHOSIS.PopupRate = 0.15
                blur.Size = math.random(12, 20)
                
                if Humanoid then
                    Humanoid.WalkSpeed = 50
                end
            end
            
            local newHealth = math.max(1, Humanoid.Health - drainRate)
            Humanoid.Health = newHealth
        end
        
        blur.Size = math.random(4, 12)
        shakeCamera()
        if math.random() < Constants.CYBERPSYCHOSIS.PopupRate then spawnPopup() end
        
        if math.random() < 0.10 then
            cc.TintColor = Color3.fromRGB(
                math.random(200, 255),
                math.random(0, 60),
                math.random(0, 60)
            )
            task.delay(0.08, function()
                if cc and cc.Parent then
                    cc.TintColor = Color3.fromRGB(255, 80, 80)
                end
            end)
        end
        
    end)
end

local function ToggleNoclip()
    Noclip = not Noclip
    if Noclip then
        noclipConnection = RunService.Stepped:Connect(function()
            if Character then
                for _, v in ipairs(Character:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.CanCollide = false
                    end
                end
            end
        end)
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
        if Character then
            for _, v in ipairs(Character:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = true
                end
            end
        end
    end
end

local function CleanupSandiSounds()
    if sandiLoopSound then sandiLoopSound:Stop() sandiLoopSound:Destroy() sandiLoopSound = nil end
end

local function ExecDodge(enemyPart: BasePart?)
    State.IsDodgeReady = false
    IsDodging = true
    Falar("dodge")
    
    -- ========== VIEWPORTFRAME DO DODGE ==========
    if _G.DodgeViewport then
        if _G.DodgeViewport.syncConn then _G.DodgeViewport.syncConn:Disconnect() end
        if _G.DodgeViewport.gui then _G.DodgeViewport.gui:Destroy() end
    end
    
    Character.Archivable = true
    local charClone = Character:Clone()
    
    for _, v in pairs(charClone:GetDescendants()) do
        if v:IsA("Script") or v:IsA("LocalScript") then v:Destroy() end
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DodgeBypassGui"
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = Player:WaitForChild("PlayerGui")
    
    local vpf = Instance.new("ViewportFrame")
    vpf.Size = UDim2.new(1, 0, 1, 0)
    vpf.BackgroundTransparency = 1
    vpf.CurrentCamera = workspace.CurrentCamera
    vpf.Parent = screenGui
    charClone.Parent = vpf
    
    local cloneParts = {}
    local function indexCloneParts(instance, path)
        for _, child in pairs(instance:GetChildren()) do
            local newPath = path .. "." .. child.Name
            if child:IsA("BasePart") then
                cloneParts[newPath] = child
            end
            indexCloneParts(child, newPath)
        end
    end
    indexCloneParts(charClone, "")
    
    local syncConn = RunService.RenderStepped:Connect(function()
        if not Character or not Character.Parent then return end
        
        local realParts = {}
        local function indexRealParts(instance, path)
            for _, child in pairs(instance:GetChildren()) do
                local newPath = path .. "." .. child.Name
                if child:IsA("BasePart") then
                    realParts[newPath] = child
                end
                indexRealParts(child, newPath)
            end
        end
        indexRealParts(Character, "")
        
        for path, clonePart in pairs(cloneParts) do
            local realPart = realParts[path]
            if realPart then
                clonePart.CFrame = realPart.CFrame
            end
        end
    end)
    
    _G.DodgeViewport = {
        gui = screenGui,
        syncConn = syncConn,
        charClone = charClone
    }
    -- ========== FIM DO VIEWPORTFRAME ==========
    
    -- Função de limpeza
    local function cleanupDodgeViewport()
        if _G.DodgeViewport then
            if _G.DodgeViewport.syncConn then _G.DodgeViewport.syncConn:Disconnect() end
            if _G.DodgeViewport.gui then _G.DodgeViewport.gui:Destroy() end
            if _G.DodgeViewport.charClone then _G.DodgeViewport.charClone:Destroy() end
            _G.DodgeViewport = nil
        end
    end
    
    -- Efeitos visuais comuns
    ScreenFade(0.08, 0, 0.25, Colors.LIGHT_GREEN, 0.8, 0.4)
    local dodgeCC = Create("ColorCorrectionEffect", {Name = "DodgeEffect", TintColor = Color3.new(1,1,1), Saturation = 0, Contrast = 0, Parent = Lighting})
    TweenService:Create(dodgeCC, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TintColor = Colors.LIGHT_GREEN, Saturation = 0.45, Contrast = 0.25}):Play()
    
    local startCFrame = HRP.CFrame
    local distance = enemyPart and (HRP.Position - enemyPart.Position).Magnitude or 0
    
    -- VARIANTE COM INIMIGO PRÓXIMO
    if enemyPart and distance <= Constants.DODGE_CONFIG.VARIANT_THRESHOLD then
        PlaySFX(Sounds.DODGE_VARIANT)
        task.spawn(function()
            local duration = Constants.DODGE_CONFIG.VARIANT_DURATION
            local startTime = tick()
            local relative = HRP.Position - enemyPart.Position
            local lastCloneTime = 0
            local direction = math.random(1,2) == 1 and 1 or -1
            
            while tick() - startTime < duration do
                local alpha = (tick() - startTime) / duration
                local angle = alpha * math.pi * direction
                local rotated = CFrame.Angles(0, angle, 0) * relative
                local newPos = enemyPart.Position + rotated
                HRP.CFrame = CFrame.lookAt(newPos, enemyPart.Position)
                
                if tick() - lastCloneTime >= Constants.DODGE_CONFIG.VARIANT_CLONE_INTERVAL then
                    CreateHologramClone(0, Constants.HOLOGRAM_CLONE.DODGE.DURATION, Constants.HOLOGRAM_CLONE.DODGE.END_TRANSPARENCY, 0, 0, 0, "dodge", HRP.CFrame)
                    lastCloneTime = tick()
                end
                RunService.Heartbeat:Wait()
            end
            
            local finalAngle = math.pi * direction
            local finalRelative = CFrame.Angles(0, finalAngle, 0) * relative
            local finalPos = enemyPart.Position + finalRelative
            HRP.CFrame = CFrame.lookAt(finalPos, enemyPart.Position)
            
            State.Cooldowns.DODGE = os.clock() + Constants.COOLDOWNS.DODGE
            ShowCooldownText("Neural Dodge", Constants.COOLDOWNS.DODGE, Colors.DODGE_END)
            IsDodging = false
            
            -- Limpeza do viewport
            cleanupDodgeViewport()
            
            local fadeOut = TweenService:Create(dodgeCC, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TintColor = Color3.new(1,1,1), Saturation = 0, Contrast = 0})
            fadeOut:Play()
            fadeOut.Completed:Connect(function() dodgeCC:Destroy() end)
        end)
    
    -- VARIANTE NORMAL
    else
        PlaySFX(Sounds.DODGE_NORMAL)
        local endCFrame
        if enemyPart then
            endCFrame = CFrame.lookAt((enemyPart.CFrame * CFrame.new(0, 0, Constants.DODGE_CONFIG.NORMAL_DISTANCE_ENEMY)).Position, enemyPart.Position)
        else
            endCFrame = HRP.CFrame * CFrame.new(0, 0, -Constants.DODGE_CONFIG.NORMAL_DISTANCE_NO_ENEMY)
        end
        
        CreateHologramClone(0, 1, 1, 0, 0, 0, "dodge", startCFrame)
        HRP.CFrame = endCFrame
        
        task.delay(0.22, function()
            State.Cooldowns.DODGE = os.clock() + Constants.COOLDOWNS.DODGE
            ShowCooldownText("Neural Dodge", Constants.COOLDOWNS.DODGE, Colors.DODGE_END)
            IsDodging = false
            
            -- Limpeza do viewport
            cleanupDodgeViewport()
        end)
        
        CamShake(0.5, 0.2)
        task.delay(0.22, function()
            local fadeOut = TweenService:Create(dodgeCC, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TintColor = Color3.new(1,1,1), Saturation = 0, Contrast = 0})
            fadeOut:Play()
            fadeOut.Completed:Connect(function() dodgeCC:Destroy() end)
            ScreenFade(0.1, 0, 0.3, Colors.LIGHT_GREEN, 0.3, 0.15)
        end)
    end
    
    local dodgeSignal = Instance.new("StringValue")
    dodgeSignal.Name = "CYBER_DODGE"
    dodgeSignal.Value = tostring(HRP.CFrame)
    dodgeSignal.Parent = Character
    Debris:AddItem(dodgeSignal, 0.6)
end

local function ActivateDodgeReady()
    if not EnabledAbilities.Dodge then return end
    if IsDodging then return end
    if os.clock() < State.Cooldowns.DODGE then return end
    if State.IsDodgeReady then return end
    
    if DodgeMode == "Counter" then
        if State.Energy < Constants.ENERGY_COSTS.DODGE then return end
        State.Energy -= Constants.ENERGY_COSTS.DODGE
        State.Energy = math.max(0, State.Energy)
        State.NoRegenUntil = os.clock() + Constants.REGEN_DELAY_USE
        
        State.IsDodgeReady = true
        
        task.spawn(function()
            local myDodgeReady = true
            task.wait(2)
            
            if State.IsDodgeReady and myDodgeReady then
                State.IsDodgeReady = false
                State.Cooldowns.DODGE = os.clock() + Constants.COOLDOWNS.DODGE
                ShowCooldownText("Neural Dodge", Constants.COOLDOWNS.DODGE, Colors.DODGE_END)
            end
        end)
    else
        State.Cooldowns.DODGE = os.clock() + Constants.COOLDOWNS.DODGE
        State.IsDodgeReady = true
    end
end

local function UpdateDashButton()
    local gui = Player.PlayerGui:FindFirstChild("CyberRebuilt")
    if not gui then return end
    local dashBtn = gui:FindFirstChild("DashBtn")
    if not dashBtn then return end
    dashBtn.TextColor3 = State.IsSandiActive and Color3.new(0.5, 0.5, 0.5) or Colors.DASH_GREEN
end

local function UpdateKiroshiButton()
    local gui = Player.PlayerGui:FindFirstChild("CyberRebuilt")
    if not gui then return end
    local kiroshiBtn = gui:FindFirstChild("KiroshiBtn")
    if not kiroshiBtn then return end
    kiroshiBtn.TextColor3 = State.IsSandiActive and Color3.new(0.5, 0.5, 0.5) or Colors.KIROSHI
end

local function UpdateOpticalButton()
    local gui = Player.PlayerGui:FindFirstChild("CyberRebuilt")
    if not gui then return end
    local opticalBtn = gui:FindFirstChild("OpticalBtn")
    if not opticalBtn then return end
    local col = State.IsSandiActive and Color3.new(0.5, 0.5, 0.5) or Colors.OPTICAL
    opticalBtn.TextColor3 = col
    for _, s in ipairs(opticalBtn:GetChildren()) do
        if s:IsA("UIStroke") and s.ApplyStrokeMode ~= Enum.ApplyStrokeMode.Border then
            s.Color = col
        end
    end
    local grad = opticalBtn:FindFirstChildOfClass("UIGradient")
    if grad then
        grad.Color = ColorSequence.new(Colors.UI_DARK, col:Lerp(Colors.UI_NEON, 0.45))
    end
end

local function ResetSandi()
    if os.clock() < SandiLockTime then return end
    if not State.IsSandiActive then return end

    -- Remove marcador
    if Character then
        local marker = Character:FindFirstChild("CYBER_SANDI_ACTIVE")
        if marker then marker:Destroy() end
    end

    -- Destroi clones holográficos
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj.Name == "HologramClone" and obj:FindFirstChild("IsSandiClone") then
            obj:Destroy()
        end
    end

    State.IsSandiActive = false
    PlaySFX(Sounds.SANDI_OFF)
    Falar("sandi_off")
    State.Cooldowns.SANDI = os.clock() + Constants.COOLDOWNS.SANDI
    State.NoRegenUntil = os.clock() + Constants.REGEN_DELAY_USE
    ShowCooldownText("Sandevistan", Constants.COOLDOWNS.SANDI, Colors.RAINBOW_SEQUENCE[1])

    -- Remove o efeito de cor (verde)
    local sandiEffect = Lighting:FindFirstChild("SandiEffect")
    if sandiEffect then
        TweenService:Create(sandiEffect, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            TintColor = Color3.new(1,1,1),
            Contrast = 0,
            Saturation = 0
        }):Play()
        task.delay(0.5, function() sandiEffect:Destroy() end)
    end

    -- Restaura walk speed e pulo
    if Humanoid then
        Humanoid.WalkSpeed = 16
        if originalPlayerJumpPower then
            Humanoid.UseJumpPower = true
            Humanoid.JumpPower = originalPlayerJumpPower
            originalPlayerJumpPower = nil
        end
    end

    -- Restaura FOV da câmera
    TweenService:Create(Camera, TweenInfo.new(0.6), {FieldOfView = 70}):Play()

    -- Para o som de loop
    CleanupSandiSounds()

    -- Restaura gravidade
    if originalGravity then
        Workspace.Gravity = originalGravity
        originalGravity = nil
    end

    -- Restaura velocidades de outros humanos
    for hum, speed in pairs(originalWalkSpeeds) do
        if hum and hum.Parent then hum.WalkSpeed = speed end
    end
    for hum, power in pairs(originalJumpPowers) do
        if hum and hum.Parent then hum.JumpPower = power end
    end

    -- Restaura animações e sons
    for track, speed in pairs(originalAnimationSpeeds) do
        if track then track:AdjustSpeed(speed) end
    end
    for sound, speed in pairs(originalSoundSpeeds) do
        if sound and sound.Parent then sound.PlaybackSpeed = speed end
    end

    -- Restaura BodyVelocity/LinearVelocity
    for velInst, vel in pairs(originalVelocityInstances) do
        if velInst and velInst.Parent then
            if velInst:IsA("BodyVelocity") then
                velInst.Velocity = vel
            elseif velInst:IsA("LinearVelocity") then
                velInst.VectorVelocity = vel
            end
        end
    end

    -- Desconecta eventos temporários
    for _, conn in ipairs(animationConnections) do
        conn:Disconnect()
    end
    originalWalkSpeeds = {}
    originalJumpPowers = {}
    originalAnimationSpeeds = {}
    originalSoundSpeeds = {}
    originalVelocityInstances = {}
    animationConnections = {}

    UpdateDashButton()
    UpdateKiroshiButton()
    UpdateOpticalButton()

    -- Para e destrói a música ambiente
    if State.MusicSound then
        State.MusicSound:Stop()
        State.MusicSound:Destroy()
        State.MusicSound = nil
    end

    -- Restaura horário do dia (se alterado)
    if originalClockTime then
        task.spawn(function()
            local targetTime = originalClockTime
            local startTime = Lighting.ClockTime
            local duration = 3.0
            local startTick = tick()
            while tick() - startTick < duration do
                local alpha = math.min(1, (tick() - startTick) / duration)
                local eased = 1 - (1 - alpha) ^ 3
                Lighting.ClockTime = startTime + (targetTime - startTime) * eased
                RunService.Heartbeat:Wait()
            end
            Lighting.ClockTime = targetTime
        end)
    end

-- Limpeza do ViewportFrame (CORRIGIDO)
if _G.SandiViewport then
    if _G.SandiViewport.syncConn then
        _G.SandiViewport.syncConn:Disconnect()
    end
    if _G.SandiViewport.gui then
        _G.SandiViewport.gui:Destroy()
    end
    if _G.SandiViewport.charClone then
        _G.SandiViewport.charClone:Destroy()
    end
    _G.SandiViewport = nil
end
end

local function PlayActivationSequence()
    local gui = Player.PlayerGui:FindFirstChild("CyberRebuilt")
    if not gui then return end
    
    local overlay = Create("ImageLabel", {
        Name = "SandiTextureOverlay", 
        Size = UDim2.new(1, 0, 1, 0), 
        Position = UDim2.new(0, 0, 0, 0), 
        BackgroundTransparency = 1, 
        ImageTransparency = 0.10, 
        ZIndex = 100, 
        Parent = gui
    })
    
    local totalFrames = #SANDI_TEXTURES
    local frameDuration = 0.08
    local totalDuration = totalFrames * frameDuration
    
    local tempoInicial = os.clock()
    local frameAtual = 1
    overlay.Image = SANDI_TEXTURES[1]
    
    local conexaoIntro
    conexaoIntro = RunService.RenderStepped:Connect(function()
        if not overlay or not overlay.Parent then
            conexaoIntro:Disconnect()
            return
        end
        
        local tempoDecorrido = os.clock() - tempoInicial
        local progresso = math.clamp(tempoDecorrido / totalDuration, 0, 1)
        local proximoFrame = math.floor(progresso * (totalFrames - 1)) + 1
        
        if proximoFrame ~= frameAtual then
            frameAtual = proximoFrame
            overlay.Image = SANDI_TEXTURES[frameAtual]
        end
        
        if progresso >= 1 then
            conexaoIntro:Disconnect()
            
            local fade = TweenService:Create(overlay, TweenInfo.new(0.2), {ImageTransparency = 1})
            fade:Play()
            fade.Completed:Connect(function()
                overlay:Destroy()
            end)
        end
    end)
end

local function ExecSandi()
    if os.clock() < State.Cooldowns.SANDI and not State.IsSandiActive then return end
    if State.IsSandiActive then ResetSandi() return end
    if State.Energy < Constants.ENERGY_COSTS.SANDI_ACTIVATE then return end
    if math.random() < Constants.SANDEVISTAN_FAILURE_CHANCE then TriggerSandevistanFailure() return end
    
    SandiLockTime = os.clock() + 3
    LastSandiActivationTime = os.clock()
    
    State.Energy -= Constants.ENERGY_COSTS.SANDI_ACTIVATE
    State.Energy = math.max(0, State.Energy)
    State.NoRegenUntil = os.clock() + Constants.REGEN_DELAY_USE
    State.IsSandiActive = true
    Falar("sandi_on")
    
    -- Áudio e shake
    task.spawn(function() pcall(PlaySFX, Sounds.SANDI_ON) end)
    task.spawn(function() pcall(CamShake, 1.5, 0.4) end)
    
    -- FOV e efeito de cor
    TweenService:Create(Camera, TweenInfo.new(0.4), {FieldOfView = 115}):Play()
    
    local sandiEffect = Create("ColorCorrectionEffect", {
        Name = "SandiEffect",
        TintColor = Color3.new(1,1,1),
        Contrast = 0,
        Saturation = 0,
        Parent = Lighting
    })
    TweenService:Create(sandiEffect, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TintColor = Colors.LIGHT_GREEN,
        Contrast = 0.15,
        Saturation = 0.3
    }):Play()
    
    -- ========== ANIMAÇÃO DE ATIVAÇÃO (TEXTURAS) ==========
    -- Primeiro toca a animação
    PlayActivationSequence()
    ScreenFade(0.25, 0.1, 0.4, Colors.LIGHT_GREEN, 0.7, 0.3)
    
    -- ========== VIEWPORTFRAME SÓ DEPOIS DA ANIMAÇÃO ==========
    -- Aguarda a animação terminar (PlayActivationSequence dura cerca de 0.6~0.8 segundos)
    task.delay(0.65, function()
        -- Verifica se o Sandevistan ainda está ativo (pode ter sido desativado durante a espera)
        if not State.IsSandiActive then return end
        
        -- Destroi clone anterior se existir
        if _G.SandiViewport then
            if _G.SandiViewport.syncConn then _G.SandiViewport.syncConn:Disconnect() end
            if _G.SandiViewport.gui then _G.SandiViewport.gui:Destroy() end
        end
        
        -- Cria o clone do personagem
        Character.Archivable = true
        local charClone = Character:Clone()
        
        -- Remove scripts da cópia
        for _, v in pairs(charClone:GetDescendants()) do
            if v:IsA("Script") or v:IsA("LocalScript") then v:Destroy() end
        end
        
        -- Cria a GUI
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "SandiBypassGui"
        screenGui.IgnoreGuiInset = true
        screenGui.Parent = Player:WaitForChild("PlayerGui")
        
        -- Cria o ViewportFrame
        local vpf = Instance.new("ViewportFrame")
        vpf.Size = UDim2.new(1, 0, 1, 0)
        vpf.BackgroundTransparency = 1
        vpf.CurrentCamera = workspace.CurrentCamera
        vpf.Parent = screenGui
        charClone.Parent = vpf
        
        -- Mapeia TODAS as partes do clone
        local cloneParts = {}
        local function indexCloneParts(instance, path)
            for _, child in pairs(instance:GetChildren()) do
                local newPath = path .. "." .. child.Name
                if child:IsA("BasePart") then
                    cloneParts[newPath] = child
                end
                indexCloneParts(child, newPath)
            end
        end
        indexCloneParts(charClone, "")
        
        -- Sincroniza a cada frame
        local syncConn = RunService.RenderStepped:Connect(function()
            if not Character or not Character.Parent or not State.IsSandiActive then
                return
            end
            
            -- Mapeia as partes reais
            local realParts = {}
            local function indexRealParts(instance, path)
                for _, child in pairs(instance:GetChildren()) do
                    local newPath = path .. "." .. child.Name
                    if child:IsA("BasePart") then
                        realParts[newPath] = child
                    end
                    indexRealParts(child, newPath)
                end
            end
            indexRealParts(Character, "")
            
            -- Atualiza cada parte do clone
            for path, clonePart in pairs(cloneParts) do
                local realPart = realParts[path]
                if realPart then
                    clonePart.CFrame = realPart.CFrame
                end
            end
        end)
        
        _G.SandiViewport = {
            gui = screenGui,
            syncConn = syncConn,
            charClone = charClone
        }
    end)
    -- ========== FIM DO VIEWPORTFRAME COM ATRASO ==========
    
    -- Marcador
    local sandiMarker = Instance.new("BoolValue")
    sandiMarker.Name = "CYBER_SANDI_ACTIVE"
    sandiMarker.Parent = Character
    
    -- Gravidade reduzida
    originalGravity = Workspace.Gravity
    Workspace.Gravity = originalGravity * Configurations.SLOW_GRAVITY_MULTIPLIER
    
    -- Loop de drenagem de energia e clones holográficos
    lastSandiClone = 0
    sandiLoopSound = Create("Sound", {
        SoundId = Sounds.SANDI_LOOP.id,
        Volume = Sounds.SANDI_LOOP.volume,
        PlaybackSpeed = Sounds.SANDI_LOOP.pitch,
        Looped = true,
        Parent = HRP
    })
    sandiLoopSound:Play()
    
    -- Ajustes de walk speed e outros efeitos lentos
    for _, hum in pairs(workspace:GetDescendants()) do
        if hum:IsA("Humanoid") and hum ~= Humanoid then
            originalWalkSpeeds[hum] = hum.WalkSpeed
            hum.WalkSpeed = hum.WalkSpeed * Constants.SLOW_FACTOR
        end
    end
    
    UpdateDashButton()
    UpdateKiroshiButton()
    UpdateOpticalButton()
    State.MusicSound = tocarMusica()
    originalClockTime = Lighting.ClockTime
    Lighting.ClockTime = 17.7
end

local function ExecDash()
    if State.IsSandiActive then return end
    if State.Energy < Constants.ENERGY_COSTS.DASH or os.clock() < State.Cooldowns.DASH then return end
    
    State.Energy -= Constants.ENERGY_COSTS.DASH
    State.Energy = math.max(0, State.Energy)
    State.NoRegenUntil = os.clock() + Constants.REGEN_DELAY_USE
    State.Cooldowns.DASH = os.clock() + Constants.COOLDOWNS.DASH
    
    -- Efeitos sonoros e visuais
    -- Detecta dash pra trás (no chão, movendo contra a direção que o personagem olha)
    local isBackDash = Humanoid.FloorMaterial ~= Enum.Material.Air
        and Humanoid.MoveDirection.Magnitude > 0
        and Humanoid.MoveDirection:Dot(HRP.CFrame.LookVector) < 0
    PlaySFX(isBackDash and Sounds.DASH_BACK or Sounds.DASH)
    Falar("dash")
    ShowCooldownText("Dash Impulse", Constants.COOLDOWNS.DASH, Colors.DASH_GREEN)
    ScreenFade(0.15, 0, 0.35, Colors.DASH_GREEN, 0.5, 0.2)
    
    local dashEffect = Create("ColorCorrectionEffect", {Name = "DashEffect", TintColor = Color3.new(1,1,1), Contrast = 0, Saturation = 0, Parent = Lighting})
    TweenService:Create(dashEffect, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TintColor = Colors.DASH_GREEN, Contrast = 0.1, Saturation = -0.1}):Play()
    TweenService:Create(Camera, TweenInfo.new(0.25), {FieldOfView = 125}):Play()
    
    -- ========== VIEWPORTFRAME DO DASH ==========
    if _G.DashViewport then
        if _G.DashViewport.syncConn then _G.DashViewport.syncConn:Disconnect() end
        if _G.DashViewport.gui then _G.DashViewport.gui:Destroy() end
    end
    
    Character.Archivable = true
    local charClone = Character:Clone()
    
    for _, v in pairs(charClone:GetDescendants()) do
        if v:IsA("Script") or v:IsA("LocalScript") then v:Destroy() end
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DashBypassGui"
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = Player:WaitForChild("PlayerGui")
    
    local vpf = Instance.new("ViewportFrame")
    vpf.Size = UDim2.new(1, 0, 1, 0)
    vpf.BackgroundTransparency = 1
    vpf.CurrentCamera = workspace.CurrentCamera
    vpf.Parent = screenGui
    charClone.Parent = vpf
    
    local cloneParts = {}
    local function indexCloneParts(instance, path)
        for _, child in pairs(instance:GetChildren()) do
            local newPath = path .. "." .. child.Name
            if child:IsA("BasePart") then
                cloneParts[newPath] = child
            end
            indexCloneParts(child, newPath)
        end
    end
    indexCloneParts(charClone, "")
    
    local syncConn = RunService.RenderStepped:Connect(function()
        if not Character or not Character.Parent then return end
        
        local realParts = {}
        local function indexRealParts(instance, path)
            for _, child in pairs(instance:GetChildren()) do
                local newPath = path .. "." .. child.Name
                if child:IsA("BasePart") then
                    realParts[newPath] = child
                end
                indexRealParts(child, newPath)
            end
        end
        indexRealParts(Character, "")
        
        for path, clonePart in pairs(cloneParts) do
            local realPart = realParts[path]
            if realPart then
                clonePart.CFrame = realPart.CFrame
            end
        end
    end)
    
    _G.DashViewport = {
        gui = screenGui,
        syncConn = syncConn,
        charClone = charClone
    }
    -- ========== FIM DO VIEWPORTFRAME ==========
    
    -- Direção do dash
    local direction
    if Humanoid.FloorMaterial ~= Enum.Material.Air then
        local lookVector = HRP.CFrame.LookVector
        local moveDir = Humanoid.MoveDirection
        direction = moveDir:Dot(lookVector) < 0 and -lookVector or lookVector
    else
        direction = Camera.CFrame.LookVector
    end
    
    local bv = Create("BodyVelocity", {MaxForce = Vector3.new(1e6, 1e6, 1e6), Velocity = direction * Constants.DASH_FORCE, Parent = HRP})
    local collisionConn
    collisionConn = HRP.Touched:Connect(function(hit)
        local hitParent = hit.Parent
        if hitParent then
            local otherHum = hitParent:FindFirstChildOfClass("Humanoid")
            if otherHum and otherHum ~= Humanoid and otherHum.Health > 0 then
                if bv and bv.Parent then bv:Destroy() end
                HRP.Velocity = Vector3.new(0, HRP.Velocity.Y, 0)
                PlaySFX(Sounds.COLLISION_IMPACT)
                if collisionConn then collisionConn:Disconnect() end
            end
        end
    end)
    Debris:AddItem(bv, 0.25)
    
    -- Hologramas durante o dash
    task.spawn(function()
        local start = os.clock()
        while os.clock() - start < 0.25 do
            if not LiteMode then
                CreateHologramClone(Constants.HOLOGRAM_CLONE.DASH.DELAY, Constants.HOLOGRAM_CLONE.DASH.DURATION, Constants.HOLOGRAM_CLONE.DASH.END_TRANSPARENCY, 0, 0, 0, "dash")
            end
            RunService.Heartbeat:Wait()
        end
        if collisionConn then collisionConn:Disconnect() end
        
        -- Limpeza do efeito visual
        TweenService:Create(dashEffect, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TintColor = Color3.new(1,1,1), Contrast = 0, Saturation = 0}):Play()
        TweenService:Create(Camera, TweenInfo.new(0.4), {FieldOfView = 70}):Play()
        Debris:AddItem(dashEffect, 0.45)
        
        -- ========== LIMPEZA DO VIEWPORTFRAME DO DASH ==========
        if _G.DashViewport then
            if _G.DashViewport.syncConn then _G.DashViewport.syncConn:Disconnect() end
            if _G.DashViewport.gui then _G.DashViewport.gui:Destroy() end
            if _G.DashViewport.charClone then _G.DashViewport.charClone:Destroy() end
            _G.DashViewport = nil
        end
        -- ========== FIM DA LIMPEZA ==========
    end)
    
    local dashSignal = Instance.new("StringValue")
    dashSignal.Name = "CYBER_DASH"
    dashSignal.Value = tostring(HRP.CFrame)
    dashSignal.Parent = Character
    Debris:AddItem(dashSignal, 0.4)
end

local KIROSHI_FADE_IN = 0.35
local KIROSHI_FADE_OUT = 0.6
local KIROSHI_HL_FILL = 0.85

-- Fade suave para Highlight e para os BillboardGui (via CanvasGroup "Root")
local function FadeKiroshiItem(item, visible, duration)
    if not item or not item.Parent then return end
    local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    if item:IsA("Highlight") then
        TweenService:Create(item, info, {
            FillTransparency = visible and KIROSHI_HL_FILL or 1,
            OutlineTransparency = visible and 0 or 1
        }):Play()
    elseif item:IsA("BillboardGui") then
        local root = item:FindFirstChild("Root")
        if root then
            TweenService:Create(root, info, {GroupTransparency = visible and 0 or 1}):Play()
        end
    end
end

local function KiroshiHealthColor(pct)
    local red = Color3.fromRGB(255, 40, 70)
    local yellow = Color3.fromRGB(252, 238, 10)
    local cyan = Color3.fromRGB(0, 240, 255)
    if pct >= 0.5 then
        return yellow:Lerp(cyan, (pct - 0.5) / 0.5)
    end
    return red:Lerp(yellow, pct / 0.5)
end

-- Barra de vida vertical (em pe), do tamanho do boneco, na esquerda do player
local function CreateKiroshiHealthBar(char, hum, hrp)
    local bbCF, bbSize = char:GetBoundingBox()
    local h = math.clamp(bbSize.Y, 3, 12)
    local textH = 0.9
    local totalH = h + textH
    local barCenterY = bbCF.Position.Y - hrp.Position.Y

    local billboard = Create("BillboardGui", {
        Name = "KiroshiHealth",
        Adornee = hrp,
        Size = UDim2.new(1.8, 0, totalH, 0),
        StudsOffset = Vector3.new(-2.3, barCenterY + textH / 2, 0),
        AlwaysOnTop = true,
        LightInfluence = 0,
        ResetOnSpawn = false,
        Parent = char
    })

    local root = Create("CanvasGroup", {
        Name = "Root",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        GroupTransparency = 1, -- comeca invisivel (fade-in)
        Parent = billboard
    })

    local textFrac = textH / totalH
    local barFrac = h / totalH

    local pctLabel = Create("TextLabel", {
        Name = "Pct",
        Size = UDim2.new(1, 0, textFrac, 0),
        BackgroundTransparency = 1,
        Text = "100%",
        Font = Enum.Font.Code,
        TextScaled = true,
        TextColor3 = Color3.fromRGB(0, 240, 255),
        TextStrokeTransparency = 0.3,
        TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
        Parent = root
    })

    local bar = Create("Frame", {
        Name = "Bar",
        Position = UDim2.new(0.3, 0, textFrac, 0),
        Size = UDim2.new(0.4, 0, barFrac, 0),
        BackgroundColor3 = Color3.fromRGB(10, 6, 14),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Parent = root
    })
    Create("UIStroke", {
        Color = Colors.KIROSHI_RED,
        Thickness = 1.5,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = bar
    })

    local inner = Create("Frame", {
        Name = "Inner",
        Position = UDim2.new(0.12, 0, 0.012, 0),
        Size = UDim2.new(0.76, 0, 0.976, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = bar
    })

    local fill = Create("Frame", {
        Name = "Fill",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(0, 240, 255),
        BorderSizePixel = 0,
        Parent = inner
    })
    Create("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 0.45)
        }),
        Parent = fill
    })

    -- segmentos (linhas escuras a cada 10%) estilo HUD cyberpunk
    for i = 1, 9 do
        Create("Frame", {
            Size = UDim2.new(1, 0, 0.012, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, i / 10, 0),
            BackgroundColor3 = Color3.fromRGB(5, 3, 8),
            BorderSizePixel = 0,
            ZIndex = 3,
            Parent = inner
        })
    end

    -- marcacoes laterais (0 / 50 / 100%) na cor do Kiroshi
    for _, f in ipairs({0, 0.5, 1}) do
        Create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(0.3, 0, textFrac + barFrac * f, 0),
            Size = UDim2.new(0.18, 0, 0.006, 0),
            BackgroundColor3 = Colors.KIROSHI_RED,
            BorderSizePixel = 0,
            Parent = root
        })
    end

    -- atualizacao suave da barra e do %
    task.spawn(function()
        local shown = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
        while State.IsKiroshiActive and billboard.Parent and hum.Parent do
            local target = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
            shown += (target - shown) * 0.25
            local color = KiroshiHealthColor(shown)
            fill.Size = UDim2.new(1, 0, math.max(shown, 0.001), 0)
            fill.BackgroundColor3 = color
            pctLabel.TextColor3 = color
            pctLabel.Text = math.floor(target * 100 + 0.5) .. "%"
            RunService.Heartbeat:Wait()
        end
    end)

    return billboard
end

local function ExecKiroshi()
    if State.IsSandiActive then return end
    if State.Energy < Constants.ENERGY_COSTS.KIROSHI or os.clock() < State.Cooldowns.KIROSHI or State.IsKiroshiActive then return end
    State.Energy -= Constants.ENERGY_COSTS.KIROSHI
    State.Energy = math.max(0, State.Energy)
    State.NoRegenUntil = os.clock() + Constants.REGEN_DELAY_USE
    State.IsKiroshiActive = true
    PlaySFX(Sounds.KIROSHI_ON)
    Falar("kiroshi")
    ScreenFade(0.3, 0.2, 0.6, Colors.KIROSHI_RED, 0.7, 0.25)
    local kiroshiCC = Create("ColorCorrectionEffect", {Name = "KiroshiCC", TintColor = Colors.KIROSHI_RED, Saturation = 0.5, Contrast = 0.2, Parent = Lighting})
    
    for _, p in Players:GetPlayers() do
        if p ~= Player then
            local char = p.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if char and hum and hrp then
                -- Highlight (comeca invisivel e faz fade-in)
                local highlight = Create("Highlight", {
                    OutlineColor = Colors.KIROSHI_RED,
                    FillColor = Colors.KIROSHI_RED,
                    FillTransparency = 1,
                    OutlineTransparency = 1,
                    Parent = char
                })
                table.insert(activeHighlights, highlight)
                FadeKiroshiItem(highlight, true, KIROSHI_FADE_IN)

                -- Barra de vida (esquerda do player)
                local healthGui = CreateKiroshiHealthBar(char, hum, hrp)
                table.insert(activeHighlights, healthGui)
                FadeKiroshiItem(healthGui, true, KIROSHI_FADE_IN)
                
                -- HotBar (mesmo estilo do Sharingan): 5 slots com as tools do jogador
                local billboard = Create("BillboardGui", {
                    Name = "KiroshiHotbar",
                    Size = UDim2.new(5.5, 0, 1.1, 0),
                    StudsOffset = Vector3.new(0, -3.2, 0),
                    AlwaysOnTop = true,
                    Parent = char
                })

                local root = Create("CanvasGroup", {
                    Name = "Root",
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    GroupTransparency = 1, -- fade-in
                    Parent = billboard
                })

                local mainFrame = Create("Frame", {
                    Name = "MainFrame",
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundColor3 = Color3.fromRGB(15, 15, 15),
                    BackgroundTransparency = 0.5,
                    Parent = root
                })
                Create("UICorner", {CornerRadius = UDim.new(0.2, 0), Parent = mainFrame})
                Create("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding = UDim.new(0.04, 0),
                    Parent = mainFrame
                })

                table.insert(activeHighlights, billboard)
                FadeKiroshiItem(billboard, true, KIROSHI_FADE_IN)

                task.spawn(function()
                    local ultimaChave = nil
                    while State.IsKiroshiActive and char.Parent do
                        local items = {}
                        local backpack = p:FindFirstChild("Backpack")
                        if backpack then
                            for _, t in ipairs(backpack:GetChildren()) do
                                if t:IsA("Tool") then table.insert(items, t) end
                            end
                        end
                        local equipped = char:FindFirstChildOfClass("Tool")
                        if equipped then table.insert(items, equipped) end

                        -- so reconstroi os slots quando as tools mudam (evita piscar)
                        local chave = ""
                        for i = 1, 5 do
                            local t = items[i]
                            chave ..= (t and (t.Name .. "|" .. t.TextureId) or "-") .. ";"
                        end

                        if chave ~= ultimaChave then
                            ultimaChave = chave
                            for _, child in ipairs(mainFrame:GetChildren()) do
                                if child:IsA("Frame") then child:Destroy() end
                            end

                            for i = 1, 5 do
                                local slot = Create("Frame", {
                                    Size = UDim2.new(0.16, 0, 0.8, 0),
                                    BackgroundColor3 = Color3.fromRGB(30, 30, 30),
                                    BackgroundTransparency = 0.2,
                                    BorderSizePixel = 1,
                                    BorderColor3 = Color3.fromRGB(55, 55, 55),
                                    LayoutOrder = i,
                                    Parent = mainFrame
                                })
                                Create("UICorner", {CornerRadius = UDim.new(0.15, 0), Parent = slot})

                                local tool = items[i]
                                if tool then
                                    slot.BorderColor3 = Color3.fromRGB(255, 70, 70)
                                    if tool.TextureId ~= "" then
                                        Create("ImageLabel", {
                                            Size = UDim2.new(0.85, 0, 0.85, 0),
                                            Position = UDim2.new(0.075, 0, 0.075, 0),
                                            Image = tool.TextureId,
                                            BackgroundTransparency = 1,
                                            Parent = slot
                                        })
                                    else
                                        Create("TextLabel", {
                                            Size = UDim2.new(0.85, 0, 0.85, 0),
                                            Position = UDim2.new(0.075, 0, 0.075, 0),
                                            Text = string.sub(tool.Name, 1, 3),
                                            TextScaled = true,
                                            BackgroundTransparency = 1,
                                            TextColor3 = Color3.new(1, 1, 1),
                                            Font = Enum.Font.SourceSansBold,
                                            Parent = slot
                                        })
                                    end
                                end
                            end
                        end

                        task.wait(0.3)
                    end
                end)
            end
        end
    end
    
    task.spawn(function()
        task.wait(5)
        if not State.IsKiroshiActive then return end
        PlaySFX(Sounds.KIROSHI_OFF)
        ScreenFade(0.4, 0, 0.6, Colors.KIROSHI_RED, 0.3, 0.1)
        State.IsKiroshiActive = false
        State.Cooldowns.KIROSHI = os.clock() + Constants.COOLDOWNS.KIROSHI
        ShowCooldownText("KIROSHI OPTICS", Constants.COOLDOWNS.KIROSHI, Colors.KIROSHI)
        if kiroshiCC then 
            TweenService:Create(kiroshiCC, TweenInfo.new(0.6), {Saturation = 0, Contrast = 0}):Play() 
            task.delay(0.7, function() kiroshiCC:Destroy() end) 
        end

        -- Fade-out suave (acompanha o fade do Kiroshi) e so depois destroi
        local toDestroy = activeHighlights
        activeHighlights = {}
        for _, h in ipairs(toDestroy) do
            FadeKiroshiItem(h, false, KIROSHI_FADE_OUT)
        end
        task.delay(KIROSHI_FADE_OUT + 0.1, function()
            for _, h in ipairs(toDestroy) do
                if h then h:Destroy() end
            end
        end)
    end)
end

-- ==========================================
-- PHASE SHIFT (noclip atravessa paredes) - antigo Optical Camo
-- ==========================================
local phaseChar = nil
local phaseParts = {}          -- [BasePart] = CanCollide original
local phaseConns = {}
local phaseForce = nil
local phaseHighlight = nil
local phaseSafeCF = nil
local phaseEndingSince = nil
local phasePrevShake = 0
local phaseStart = 0
local PHASE_EXIT_GRACE = 1.5
local PhaseGhost = {
    Extra = 0,          -- 0 = clone 100% igual ao boneco (suba p/ 0.2~0.4 se quiser translucido)
    EmergeTime = 0.35,  -- tempo dos clones saindo do corpo ao ativar
    RetractTime = 0.2,  -- tempo dos clones voltando pro corpo ao acabar
    -- 5 clones: {lado (-1 esquerda, 1 direita, 0 = atravessa o corpo indo de um lado ao outro), distancia maxima}
    Layout = {
        {-1, 3.4}, {1, 3.4}, {-1, 2.2}, {1, 2.2}, {0, 2.6},
    },
    List = {},
    Conn = nil,
}

local PHASE_JUNK = {"Script", "LocalScript", "ModuleScript", "Sound", "ParticleEmitter", "Trail", "Beam", "Highlight", "BillboardGui", "ForceField", "Fire", "Smoke", "Sparkles", "PointLight", "SpotLight", "SurfaceLight", "BodyMover", "VectorForce", "Animator"}

function PhaseGhost.Stop()
    if PhaseGhost.Conn then
        PhaseGhost.Conn:Disconnect()
        PhaseGhost.Conn = nil
    end
end

-- remove os clones na hora (eles nao ficam no mapa)
function PhaseGhost.Clear()
    for _, g in ipairs(PhaseGhost.List) do
        if g.model then pcall(function() g.model:Destroy() end) end
    end
    PhaseGhost.List = {}
    PhaseGhost.Stop()
end

-- clones voltam pra dentro do corpo e somem
function PhaseGhost.Retract()
    local now = os.clock()
    for _, g in ipairs(PhaseGhost.List) do
        if not g.dying then g.dying = now end
    end
end

-- cria 1 clone EXATO do boneco (mesmas cores, roupas, acessorios) no Workspace
-- Tamanho 1:1 garantido + Humanoid seguro (sem conflito de física)
function PhaseGhost.Create(index: number)
    local src = Character
    if not src or not src.Parent then return end
    local layout = PhaseGhost.Layout[index]

    local wasArchivable = src.Archivable
    src.Archivable = true
    local ok, ghost = pcall(function() return src:Clone() end)
    src.Archivable = wasArchivable
    if not ok or not ghost then return end

    -- pareia cada parte do clone com a parte original pelo caminho (nome/pai/...)
    local function keyed(root: Instance)
        local map, used = {}, {}
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("BasePart") then
                local names, o = {}, d
                while o and o ~= root do
                    table.insert(names, 1, o.Name)
                    o = o.Parent
                end
                local key = table.concat(names, "/")
                used[key] = (used[key] or 0) + 1
                if used[key] > 1 then key = key .. "#" .. used[key] end
                map[key] = d
            end
        end
        return map
    end

    local srcMap, ghostMap = keyed(src), keyed(ghost)
    local pairsList = {}
    for key, g in pairs(ghostMap) do
        local o = srcMap[key]
        if o then table.insert(pairsList, {g, o}) end
    end
    if #pairsList == 0 then ghost:Destroy() return end

    -- limpa scripts, sons, efeitos (Humanoid é mantido e configurado abaixo)
    for _, obj in ipairs(ghost:GetDescendants()) do
        local junk = obj.Name == "PhaseAtt"
        if not junk then
            for _, cls in ipairs(PHASE_JUNK) do
                if obj:IsA(cls) then junk = true break end
            end
        end
        if junk then obj:Destroy() end
    end

    for _, pr in ipairs(pairsList) do
        local part = pr[1]
        if part.Parent then
            part.Anchored = true
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.CastShadow = false
            part.Massless = true
            pr[4] = part.Name == "HumanoidRootPart"
            if not pr[4] and PhaseGhost.Extra > 0 then
                part.Transparency = math.clamp(part.Transparency + PhaseGhost.Extra, 0, 1)
            end
            pr[3] = part.Transparency  -- transparencia original (usada no fade-in)
            if not pr[4] then part.Transparency = 1 end
        end
    end

    -- Mantém o Humanoid no clone (desativado de forma segura)
    -- Anchored + CanCollide=false + PlatformStand = zero conflito com o boneco real
    local hum = ghost:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum.PlatformStand = true
            hum.Sit = true
            hum.AutoRotate = false
            hum.WalkSpeed = 0
            hum.JumpPower = 0
            hum.JumpHeight = 0
            hum.RequiresNeck = false
            hum.BreakJointsOnDeath = false
            hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
            hum.NameDisplayDistance = 0
            hum.HealthDisplayDistance = 0
            hum:ChangeState(Enum.HumanoidStateType.Physics)
        end)
    end

    ghost.Name = "PhaseGhost"
    ghost.Parent = Workspace   -- Workspace = tamanho 1:1 idêntico ao boneco

    table.insert(PhaseGhost.List, {
        model = ghost,
        pairs = pairsList,
        side = layout[1],
        dist = layout[2],
        phase = index * 1.7,
        freq = 34 + index * 3.5,   -- velocidade da vibracao
        born = os.clock(),
        dying = nil,
        settled = false,
    })
end

function PhaseGhost.Update()
    local list = PhaseGhost.List
    if #list == 0 then PhaseGhost.Stop() return end
    if not HRP or not HRP.Parent then PhaseGhost.Clear() return end

    local now = os.clock()
    local right = HRP.CFrame.RightVector

    for i = #list, 1, -1 do
        local g = list[i]
        local emerge = math.clamp((now - g.born) / PhaseGhost.EmergeTime, 0, 1)
        emerge = 1 - (1 - emerge) ^ 3            -- saem do corpo desacelerando
        if g.dying then
            local k = math.clamp((now - g.dying) / PhaseGhost.RetractTime, 0, 1)
            if k >= 1 then
                pcall(function() g.model:Destroy() end)
                table.remove(list, i)
                continue
            end
            emerge = emerge * (1 - k)            -- voltam pro corpo
        end

        -- vibracao: entra e sai do corpo rapidinho
        local wave = math.sin(now * g.freq + g.phase)
        local dist
        if g.side == 0 then
            dist = g.dist * wave
        else
            dist = g.side * g.dist * (0.5 + 0.5 * wave)
        end
        local shift = right * (dist * emerge)

        local fade = emerge < 1 or g.dying ~= nil
        local setTransparency = fade or not g.settled
        g.settled = not fade

        for _, pr in ipairs(g.pairs) do
            local gp, op = pr[1], pr[2]
            if gp.Parent and op.Parent then
                gp.CFrame = op.CFrame + shift
                if setTransparency and not pr[4] then
                    gp.Transparency = 1 - (1 - pr[3]) * emerge
                end
            end
        end
    end

    if #list == 0 then PhaseGhost.Stop() end
end

-- 5 clones saindo do corpo que ficam vibrando enquanto a habilidade dura
-- Workspace = tamanho exatamente igual ao do seu boneco
function PhaseGhost.Spawn()
    if LiteMode then return end
    PhaseGhost.Clear()
    for i = 1, #PhaseGhost.Layout do
        PhaseGhost.Create(i)
    end
    if #PhaseGhost.List > 0 then
        PhaseGhost.Conn = RunService.RenderStepped:Connect(PhaseGhost.Update)
    end
end

-- true se o boneco esta dentro de alguma parede/chao solido
local function PhaseIsInsideGeometry()
    if not phaseChar or not phaseChar.Parent then return false end
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {phaseChar}
    local cf, size = phaseChar:GetBoundingBox()
    local found = Workspace:GetPartBoundsInBox(cf, size * 0.8, params)
    for _, p in ipairs(found) do
        if p.CanCollide and p.Name ~= "PhaseGhost" then
            local model = p:FindFirstAncestorOfClass("Model")
            local isCharacter = model and model:FindFirstChildOfClass("Humanoid")
            if not isCharacter then return true end
        end
    end
    return false
end

-- desfaz tudo: colisao, forca anti-gravidade, highlight, conexoes
local function FinalizePhase()
    if Character and Character == phaseChar then PhaseGhost.Retract() else PhaseGhost.Clear() end
    for _, c in ipairs(phaseConns) do pcall(function() c:Disconnect() end) end
    phaseConns = {}
    if phasePrevShake ~= 0 and HRP and HRP.Parent and Character == phaseChar then
        pcall(function() HRP.CFrame = HRP.CFrame - HRP.CFrame.RightVector * phasePrevShake end)
    end
    phasePrevShake = 0
    for part, original in pairs(phaseParts) do
        if part and part.Parent then pcall(function() part.CanCollide = original end) end
    end
    phaseParts = {}
    if phaseForce then
        local att = phaseForce.Attachment0
        phaseForce:Destroy()
        if att then att:Destroy() end
        phaseForce = nil
    end
    if phaseHighlight then
        local hl = phaseHighlight
        phaseHighlight = nil
        TweenService:Create(hl, TweenInfo.new(0.3), {FillTransparency = 1, OutlineTransparency = 1}):Play()
        Debris:AddItem(hl, 0.35)
    end
    phaseEndingSince = nil
    phaseChar = nil
    phaseSafeCF = nil
end

local function ResetOptical()
    if not State.IsOpticalActive then return end
    opticalToken += 1
    State.IsOpticalActive = false
    PhaseGhost.Retract()
    Falar("optical_off")
    State.Cooldowns.OPTICAL = os.clock() + Constants.COOLDOWNS.OPTICAL
    State.NoRegenUntil = os.clock() + Constants.REGEN_DELAY_USE
    ShowCooldownText("PHASE SHIFT", Constants.COOLDOWNS.OPTICAL, Colors.OPTICAL)
    -- se ainda estiver dentro de uma parede, continua sem colisao ate sair
    -- (ver o loop do Stepped); se o personagem mudou (respawn), finaliza na hora
    if phaseChar and phaseChar == Character and PhaseIsInsideGeometry() then
        phaseEndingSince = os.clock()
    else
        FinalizePhase()
    end
end

local function ExecOptical()
    if State.IsSandiActive then return end
    if State.IsOpticalActive or phaseChar then return end
    if os.clock() < State.Cooldowns.OPTICAL then return end
    if State.Energy < Constants.ENERGY_COSTS.OPTICAL then return end
    if not Character or not HRP or not Humanoid or Humanoid.Health <= 0 then return end

    State.Energy -= Constants.ENERGY_COSTS.OPTICAL
    State.Energy = math.max(0, State.Energy)
    State.NoRegenUntil = os.clock() + Constants.REGEN_DELAY_USE
    State.IsOpticalActive = true
    Falar("optical_on")
    PlaySFX(Sounds.OPTICAL_CAMO)
    ScreenFade(0.1, 0.05, 0.3, Colors.OPTICAL, 0.3, 0.2)

    phaseChar = Character
    phaseStart = os.clock()
    phaseSafeCF = HRP.CFrame
    phaseEndingSince = nil
    phasePrevShake = 0
    opticalToken += 1
    local myToken = opticalToken
    local char = Character
    local root = HRP
    local hum = Humanoid

    -- guarda a colisao original de cada parte
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then phaseParts[v] = v.CanCollide end
    end

    -- anti-gravidade (senao o boneco cai pelo chao ao perder colisao)
    local att = Create("Attachment", {Name = "PhaseAtt", Parent = root})
    phaseForce = Create("VectorForce", {
        Name = "PhaseAntiGravity",
        Attachment0 = att,
        RelativeTo = Enum.ActuatorRelativeTo.World,
        ApplyAtCenterOfMass = true,
        Force = Vector3.new(0, root.AssemblyMass * Workspace.Gravity, 0),
        Parent = root
    })

    -- noclip + controle vertical (Espaco sobe / Shift desce) + seguranca ao sair
    table.insert(phaseConns, RunService.Stepped:Connect(function()
        if Character ~= char or not char.Parent or not root.Parent then
            FinalizePhase()
            return
        end
        for part in pairs(phaseParts) do
            if part.Parent then part.CanCollide = false end
        end
        local v = root.AssemblyLinearVelocity
        local up = 0
        if State.IsOpticalActive then
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) or hum.Jump then up = 28 end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then up = -28 end
        end
        root.AssemblyLinearVelocity = Vector3.new(v.X, up, v.Z)

        if phaseEndingSince then
            -- terminou a habilidade: so devolve a colisao quando estiver fora de paredes
            if not PhaseIsInsideGeometry() then
                FinalizePhase()
            elseif os.clock() - phaseEndingSince > PHASE_EXIT_GRACE then
                if phaseSafeCF then root.CFrame = phaseSafeCF end
                root.AssemblyLinearVelocity = Vector3.zero
                FinalizePhase()
            end
        elseif not PhaseIsInsideGeometry() then
            phaseSafeCF = root.CFrame
        end
    end))

    -- vibracao esquerda/direita (forte no inicio, tremor leve depois)
    table.insert(phaseConns, RunService.RenderStepped:Connect(function()
        if Character ~= char or not root.Parent then return end
        local t = os.clock() - phaseStart
        local amp
        if not State.IsOpticalActive then
            amp = 0
        else
            amp = 0.45 - math.clamp(t / 0.6, 0, 1) * 0.33 -- 0.45 -> 0.12
        end
        local shake = math.sin(t * 120) * amp
        local delta = shake - phasePrevShake
        phasePrevShake = shake
        root.CFrame = root.CFrame + root.CFrame.RightVector * delta
    end))

    -- clones exatos do boneco: so esquerda e direita, acompanham o personagem
    PhaseGhost.Spawn()

    task.delay(Constants.OPTICAL_DURATION, function()
        if myToken == opticalToken then ResetOptical() end
    end)
end

local function SpawnRebootWindow()
    if not HRP then return end
    local part = Instance.new("Part")
    part.Name = "RebootSystemWindow"
    part.Size = Vector3.new(0, 0, 0.08)
    part.Color = Color3.fromRGB(0, 195, 255)
    part.Material = Enum.Material.Neon
    part.Transparency = 0.03
    part.CanCollide = false
    part.Anchored = true
    part.CastShadow = false
    part.Parent = Workspace
    local sgui = Instance.new("SurfaceGui", part)
    sgui.Face = Enum.NormalId.Front
    sgui.PixelsPerStud = 65
    local frame = Instance.new("Frame", sgui)
    frame.Size = UDim2.new(1,0,1,0)
    frame.BackgroundColor3 = Color3.fromRGB(0, 12, 28)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(80, 220, 255)
    stroke.Thickness = 6
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1,-20,0.65,0)
    title.Position = UDim2.new(0,10,0,8)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(80, 255, 220)
    title.Font = Enum.Font.SciFi
    title.TextSize = 52
    title.TextStrokeTransparency = 0.4
    title.Text = "REBOOT SYSTEM"
    local subtitle = Instance.new("TextLabel", frame)
    subtitle.Size = UDim2.new(1,-20,0.28,0)
    subtitle.Position = UDim2.new(0,10,0.68,0)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "NEURAL INTERFACE RESTORED"
    subtitle.TextColor3 = Color3.fromRGB(180, 255, 240)
    subtitle.Font = Enum.Font.Code
    subtitle.TextSize = 22
    local function updatePosition()
        if HRP and part.Parent then
            local frontOffset = HRP.CFrame.LookVector * 7 + Vector3.new(0, 1.5, 0)
            part.CFrame = CFrame.lookAt(HRP.Position + frontOffset, HRP.Position)
        end
    end
    updatePosition()
    TweenService:Create(part, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = Vector3.new(5.2, 3.1, 0.08)}):Play()
    local followConn = RunService.Heartbeat:Connect(updatePosition)
    task.delay(3, function()
        if followConn then followConn:Disconnect() end
        if part and part.Parent then
            TweenService:Create(part, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {Size = Vector3.new(0.1, 0.1, 0.08)}):Play()
            task.delay(0.5, function() part:Destroy() end)
        end
    end)
end

local function SpawnAnimation()
    local spawnSound = Instance.new("Sound")
    spawnSound.SoundId = "rbxassetid://121480304779842"
    spawnSound.Volume = 2.0
    spawnSound.PlaybackSpeed = 1
    spawnSound.Parent = Camera
    spawnSound:Play()
    task.delay(3, function()
        if spawnSound and spawnSound.Parent then
            spawnSound:Stop()
            spawnSound:Destroy()
        end
    end)
    if not HRP then return end
    local gui = Player.PlayerGui:FindFirstChild("CyberRebuilt") or Instance.new("ScreenGui", Player.PlayerGui)
    local rebootText = Instance.new("TextLabel")
    rebootText.Size = UDim2.new(1,0,0.14,0)
    rebootText.Position = UDim2.new(0,0,-0.2,0)
    rebootText.BackgroundTransparency = 1
    rebootText.TextColor3 = Color3.fromRGB(0, 255, 220)
    rebootText.Font = Enum.Font.SciFi
    rebootText.TextSize = 92
    rebootText.TextTransparency = 1
    rebootText.TextStrokeTransparency = 0.6
    rebootText.Parent = gui
    TweenService:Create(rebootText, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0,0,0.08,0), TextTransparency = 0}):Play()
    task.spawn(function()
        local baseText = "REBOOT SEQUENCE"
        local dotsCycle = {".", "..", "..."}
        local idx = 1
        local startTimeText = os.clock()
        while os.clock() - startTimeText < 3 do
            rebootText.Text = baseText .. dotsCycle[idx]
            idx = idx % 3 + 1
            task.wait(0.35)
        end
    end)
    task.delay(3, function()
        TweenService:Create(rebootText, TweenInfo.new(0.8), {TextTransparency = 1, Position = UDim2.new(0,0,-0.1,0)}):Play()
        task.delay(1, function() rebootText:Destroy() end)
    end)
    SpawnRebootWindow()
end

local function UpdateKeybind(ability)
    ContextActionService:UnbindAction(AbilityActions[ability])
    ContextActionService:BindAction(AbilityActions[ability], function(_, inputState)
        if inputState == Enum.UserInputState.Begin then
            if ability == "Dash" then ExecDash()
            elseif ability == "Sandi" then ExecSandi()
            elseif ability == "Kiroshi" then ExecKiroshi()
            elseif ability == "Optical" then ExecOptical()
            elseif ability == "Dodge" then ActivateDodgeReady() end
        end
        return Enum.ContextActionResult.Sink
    end, false, CurrentKeybinds[ability])
end

local function BindAllKeybinds()
    for ab in pairs(CurrentKeybinds) do UpdateKeybind(ab) end
end

local function LimparAcessorios()
    local char = Player.Character
    if char then
        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("Accessory") and (v.Name:find("SetItem_") or v:FindFirstChild("AutoWeldTag")) then v:Destroy() end
        end
    end
end

local function AplicarSet(listaIds)
    local character = Player.Character or Player.CharacterAdded:Wait()
    LimparAcessorios()
    for _, id in pairs(listaIds) do
        task.spawn(function()
            local sucesso, objects = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
            if sucesso and objects and objects[1] then
                local asset = objects[1]:Clone()
                asset.Name = "SetItem_" .. id
                local tag = Instance.new("BoolValue")
                tag.Name = "AutoWeldTag"
                tag.Parent = asset
                local handle = asset:IsA("BasePart") and asset or asset:FindFirstChild("Handle", true)
                if handle then
                    for _, v in pairs(asset:GetDescendants()) do if v:IsA("LuaSourceContainer") then v:Destroy() end end
                    handle.CanCollide = false
                    handle.Massless = true
                    asset.Parent = character
                    local attachmentItem = handle:FindFirstChildWhichIsA("Attachment")
                    local partAlvo = nil
                    local attachmentCorpo = nil
                    if attachmentItem then
                        for _, parte in pairs(character:GetChildren()) do
                            if parte:IsA("BasePart") then
                                local found = parte:FindFirstChild(attachmentItem.Name)
                                if found then partAlvo = parte attachmentCorpo = found break end
                            end
                        end
                    end
                    if not partAlvo then partAlvo = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart") end
                    if partAlvo then
                        local weld = Instance.new("Weld")
                        weld.Part0 = partAlvo
                        weld.Part1 = handle
                        if attachmentItem and attachmentCorpo then
                            weld.C0 = attachmentCorpo.CFrame
                            weld.C1 = attachmentItem.CFrame
                        else
                            weld.C0 = CFrame.new(0, 0, 0.6) * CFrame.Angles(0, math.rad(180), 0)
                        end
                        weld.Parent = handle
                    end
                end
                objects[1]:Destroy()
            end
        end)
    end
end

local function MakeDraggable(movable: Frame, hit: GuiObject)
    hit = hit or movable
    local dragging = false
    local dragStart, startPos
    local stroke = Create("UIStroke", {Color = Colors.UI_NEON, Thickness = 2, Transparency = 0.5, Enabled = false, Parent = movable})
    table.insert(UI_Elements, {Frame = movable, Stroke = stroke})
    hit.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and State.EditMode then
            dragging = true
            dragStart = input.Position
            startPos = movable.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging and State.EditMode then
            local delta = input.Position - dragStart
            movable.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local function CreateEnergyBar(gui)
    local container = Create("Frame", {
        Name = "EnergyBar",
        Size = UDim2.new(0, 32, 0, 310),
        Position = UDim2.new(0, 28, 0.5, -155),
        BackgroundColor3 = Color3.fromRGB(4, 4, 9),
        BorderSizePixel = 0,
        Parent = gui
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 18), Parent = container})

    Create("UIStroke", {Color = Colors.CYBER_CHROME, Thickness = 7, Transparency = 0.05, Parent = container})
    Create("UIStroke", {Color = Colors.UI_NEON, Thickness = 3.5, Transparency = 0.45, Parent = container})

    local innerGlow = Create("UIStroke", {Color = Colors.CYBER_ORANGE, Thickness = 12, Transparency = 0.75, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = container})

    local inner = Create("Frame", {Size = UDim2.new(1, -10, 1, -10), Position = UDim2.new(0, 5, 0, 5), BackgroundColor3 = Color3.fromRGB(2, 2, 7), BorderSizePixel = 0, Parent = container})
    Create("UICorner", {CornerRadius = UDim.new(0, 14), Parent = inner})

    energyFill = Create("Frame", {
    Name = "Fill",
    Size = UDim2.new(1, -12, 1, -12),
    Position = UDim2.new(0, 6, 1, -6),
    AnchorPoint = Vector2.new(0, 1),
    ClipsDescendants = true,
        BackgroundColor3 = Colors.LIGHT_GREEN,
        BorderSizePixel = 0,
        Parent = inner
    })
    local fillGradient = Create("UIGradient", {Color = ColorSequence.new(Colors.LIGHT_GREEN, Colors.CYBER_ORANGE), Rotation = 90, Parent = energyFill})
    Create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = energyFill})

    local scanline = Create("Frame", {Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Color3.fromRGB(255,255,255), BackgroundTransparency = 0.7, Parent = energyFill})
    Create("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(0.5,0), NumberSequenceKeypoint.new(1,1)}), Parent = scanline})
    task.spawn(function()
        while energyFill.Parent do
            scanline.Position = UDim2.new(0, 0, math.random(), 0)
            TweenService:Create(scanline, TweenInfo.new(0.6, Enum.EasingStyle.Linear), {Position = UDim2.new(0,0,1,0)}):Play()
            task.wait(0.6)
        end
    end)

    local coreLabel = Create("TextLabel", {
        Size = UDim2.new(0, 34, 0, 160),
        Position = UDim2.new(1, 14, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Text = "NEURAL\nCORE",
        TextColor3 = Colors.CYBER_ORANGE,
        Font = Enum.Font.SciFi,
        TextSize = 16,
        TextStrokeTransparency = 0.35,
        Rotation = -90,
        Parent = container
    })

    energyPercentLabel = Create("TextLabel", {
        Size = UDim2.new(0, 50, 0, 22),
        Position = UDim2.new(0.5, 0, 1, 12),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        Text = "100%",
        TextColor3 = Colors.UI_NEON,
        Font = Enum.Font.Code,
        TextSize = 18,
        TextStrokeTransparency = 0.25,
        Parent = container
    })

    local circuitTop = Create("Frame", {Size = UDim2.new(1, -14, 0, 2), Position = UDim2.new(0, 7, 0, 9), BackgroundColor3 = Colors.UI_NEON, BorderSizePixel = 0, Parent = container})
    Create("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255,255,255), Colors.UI_NEON), Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(0.4,0), NumberSequenceKeypoint.new(1,1)}), Parent = circuitTop})

    local circuitBottom = Create("Frame", {Size = UDim2.new(1, -14, 0, 2), Position = UDim2.new(0, 7, 1, -11), BackgroundColor3 = Colors.UI_NEON, BorderSizePixel = 0, Parent = container})
    Create("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255,255,255), Colors.UI_NEON), Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(0.4,0), NumberSequenceKeypoint.new(1,1)}), Parent = circuitBottom})

    return container
end

local function LoadConfig()
    local success, result = pcall(function()
        if isfile(CONFIG_FILE) then
            local content = readfile(CONFIG_FILE)
            return HttpService:JSONDecode(content)
        else
            local json = HttpService:JSONEncode(DefaultConfig)
            writefile(CONFIG_FILE, json)
            return DefaultConfig
        end
    end)
    
    if success and result then
        return result
    else
        return DefaultConfig
    end
end

local function SaveConfig()
    local config = {
        UIPositions = {},
        EnabledAbilities = EnabledAbilities,
        Keybinds = {},
        Settings = {
            DodgeMode = DodgeMode,
            LiteMode = LiteMode,
            CurrentSet = currentSet,
            CloneColorIndex = cloneColorIndex
        }
    }
    
    for name, pos in pairs(savedPositions) do
        config.UIPositions[name] = {
            ScaleX = pos.X.Scale,
            OffsetX = pos.X.Offset,
            ScaleY = pos.Y.Scale,
            OffsetY = pos.Y.Offset
        }
    end
    
    if next(config.UIPositions) == nil then
        config.UIPositions = DefaultConfig.UIPositions
    end
    
    for ab, key in pairs(CurrentKeybinds) do
        config.Keybinds[ab] = key.Name
    end
    
    local success, err = pcall(function()
        local json = HttpService:JSONEncode(config)
        writefile(CONFIG_FILE, json)
    end)
    
    if not success then
    end
end

local function ApplyConfig(config)
    if not config then return end
    
    if config.UIPositions then
        for name, posData in pairs(config.UIPositions) do
            savedPositions[name] = UDim2.new(posData.ScaleX, posData.OffsetX, posData.ScaleY, posData.OffsetY)
        end
    end
    
    if config.EnabledAbilities then
        for ab, state in pairs(config.EnabledAbilities) do
            if EnabledAbilities[ab] ~= nil then
                EnabledAbilities[ab] = state
            end
        end
    end
    
    if config.Keybinds then
        for ab, keyName in pairs(config.Keybinds) do
            local success, keycode = pcall(function()
                return Enum.KeyCode[keyName]
            end)
            if success and keycode and CurrentKeybinds[ab] ~= nil then
                CurrentKeybinds[ab] = keycode
            end
        end
    end
    
    if config.Settings then
        if config.Settings.DodgeMode then
            DodgeMode = config.Settings.DodgeMode
        end
        if config.Settings.LiteMode ~= nil then
            LiteMode = config.Settings.LiteMode
        end
        if config.Settings.CurrentSet then
            currentSet = config.Settings.CurrentSet
        end
        if config.Settings.CloneColorIndex then
            cloneColorIndex = config.Settings.CloneColorIndex
        end
    end
end

local function BuildUI()
    if Player.PlayerGui:FindFirstChild("CyberRebuilt") then Player.PlayerGui.CyberRebuilt:Destroy() end
    local gui = Create("ScreenGui", {Name = "CyberRebuilt", Parent = Player.PlayerGui, IgnoreGuiInset = true})

    local hudOverlay = Create("Frame", {Size = UDim2.new(1,0,1,0), BackgroundColor3 = Color3.fromRGB(0,0,0), BackgroundTransparency = 0.92, Parent = gui})
    Create("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(10,10,15), Color3.fromRGB(0,0,0)), Rotation = 90, Parent = hudOverlay})

    CreateEnergyBar(gui)
    KeybindCurrentTexts = {}

    local lockBtn = Create("TextButton", {Name = "LockBtn", Size = ButtonConfigs.LockBtn.Size, Position = ButtonConfigs.LockBtn.Position, Text = ButtonConfigs.LockBtn.Text, BackgroundColor3 = ButtonConfigs.LockBtn.BackgroundColor3, TextColor3 = ButtonConfigs.LockBtn.TextColor3, Font = ButtonConfigs.LockBtn.Font, TextSize = ButtonConfigs.LockBtn.TextSize, Parent = gui})
    Create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = lockBtn})
    local lockStroke1 = Create("UIStroke", {Color = Colors.CYBER_CHROME, Thickness = 3, Transparency = 0.3, Parent = lockBtn})
    local lockStroke2 = Create("UIStroke", {Color = Colors.UI_NEON, Thickness = 1.5, Transparency = 0.6, Parent = lockBtn})
    local lockGradient = Create("UIGradient", {Color = ColorSequence.new(Colors.UI_DARK, Colors.CYBER_ORANGE), Rotation = 45, Parent = lockBtn})

    local function CreateSkillBtn(key, color, pos, name, func)
        local btnContainer = Create("Frame", {Name = name .. "Container", Size = UDim2.new(0, 54, 0, 54), Position = savedPositions[name] or pos, BackgroundTransparency = 1, Parent = gui})

        local btn = Create("TextButton", {Name = name, Size = UDim2.new(1, 0, 1, 0), Text = key, BackgroundColor3 = Colors.UI_DARK, TextColor3 = color, Font = Enum.Font.SciFi, TextSize = 21, AutoButtonColor = false, Parent = btnContainer})

        local strokeOuter = Create("UIStroke", {Color = color, Thickness = 3.5, Transparency = 0.25, Parent = btn})
        local strokeInner = Create("UIStroke", {Color = Colors.CYBER_CHROME, Thickness = 1.2, Transparency = 0.5, Parent = btn})

        Create("UICorner", {CornerRadius = UDim.new(0, 14), Parent = btn})

        local gradient = Create("UIGradient", {Color = ColorSequence.new(Colors.UI_DARK, color:Lerp(Colors.UI_NEON, 0.45)), Rotation = 35, Parent = btn})

        local glow = Create("UIStroke", {Color = Colors.UI_GLOW, Thickness = 4.5, Transparency = 0.78, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = btn})

        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = color:Lerp(Colors.CYBER_ORANGE, 0.3)}):Play()
            TweenService:Create(glow, TweenInfo.new(0.15), {Transparency = 0.35}):Play()
            TweenService:Create(strokeOuter, TweenInfo.new(0.15), {Thickness = 4.2}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = Colors.UI_DARK}):Play()
            TweenService:Create(glow, TweenInfo.new(0.2), {Transparency = 0.78}):Play()
            TweenService:Create(strokeOuter, TweenInfo.new(0.2), {Thickness = 3.5}):Play()
        end)

        btn.MouseButton1Down:Connect(function()
            if not State.EditMode then
                TweenService:Create(btn, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0.9, 0, 0.9, 0), BackgroundColor3 = color}):Play()
                func()
            end
        end)
        btn.MouseButton1Up:Connect(function()
            if not State.EditMode then
                TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Colors.UI_DARK}):Play()
            end
        end)

        TweenService:Create(btn, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Rotation = 2.8}):Play()

        MakeDraggable(btnContainer, btn)
        SkillContainers[name] = btnContainer

        if name == "SandiBtn" then
            task.spawn(function()
                while btn.Parent do
                    local hue = (os.clock() % 4.5) / 4.5
                    local rainbowColor = Color3.fromHSV(hue, 1, 1)
                    btn.TextColor3 = rainbowColor
                    strokeOuter.Color = rainbowColor
                    gradient.Color = ColorSequence.new(Colors.UI_DARK, rainbowColor)
                    task.wait()
                end
            end)
        end
        return btn
    end

    CreateSkillBtn(ButtonConfigs.DashBtn.Key, ButtonConfigs.DashBtn.Color, ButtonConfigs.DashBtn.Position, "DashBtn", ExecDash)
    CreateSkillBtn(ButtonConfigs.SandiBtn.Key, ButtonConfigs.SandiBtn.Color, ButtonConfigs.SandiBtn.Position, "SandiBtn", ExecSandi)
    CreateSkillBtn(ButtonConfigs.KiroshiBtn.Key, ButtonConfigs.KiroshiBtn.Color, ButtonConfigs.KiroshiBtn.Position, "KiroshiBtn", ExecKiroshi)
    CreateSkillBtn(ButtonConfigs.OpticalBtn.Key, ButtonConfigs.OpticalBtn.Color, ButtonConfigs.OpticalBtn.Position, "OpticalBtn", ExecOptical)
    CreateSkillBtn(ButtonConfigs.DodgeBtn.Key, ButtonConfigs.DodgeBtn.Color, ButtonConfigs.DodgeBtn.Position, "DodgeBtn", ActivateDodgeReady)

    for abilityKey, isEnabled in pairs(EnabledAbilities) do
        local btnName = AbilityMap[abilityKey]
        if btnName and SkillContainers[btnName] then
            local visible = isEnabled
            if btnName == "DodgeBtn" then visible = visible and (DodgeMode == "Counter") end
            SkillContainers[btnName].Visible = visible
        end
    end

    local settingsMenu = Create("Frame", {
    Name = "SettingsMenu", 
    Size = UDim2.new(0, 0, 0, 0),
    Position = UDim2.new(0, 78, 0, 28), 
    BackgroundColor3 = Color3.fromRGB(4,4,8), 
    Visible = false,
    BorderSizePixel = 0, 
    Parent = gui
})
    Create("UICorner", {CornerRadius = UDim.new(0, 16), Parent = settingsMenu})
    local menuStroke1 = Create("UIStroke", {Color = Colors.CYBER_CHROME, Thickness = 4, Transparency = 0.2, Parent = settingsMenu})
    local menuStroke2 = Create("UIStroke", {Color = Colors.UI_NEON, Thickness = 1.5, Transparency = 0.55, Parent = settingsMenu})

    local title = Create("TextLabel", {Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1, Text = "NEURAL INTERFACE\nCYBER REBUILT 2077", TextColor3 = Colors.CYBER_ORANGE, Font = Enum.Font.SciFi, TextSize = 19, TextStrokeTransparency = 0.5, Parent = settingsMenu})

    local scroll = Create("ScrollingFrame", {Name = "AbilitiesScroll", Size = UDim2.new(1, -24, 1, -148), Position = UDim2.new(0, 12, 0, 66), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = Colors.UI_NEON, Parent = settingsMenu})
    Create("UIListLayout", {Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll})

    local abilitiesList = {
        {display = "DASH IMPULSE", key = "Dash", color = Colors.DASH_GREEN},
        {display = "SANDEVISTAN", key = "Sandi", color = Colors.SANDI_TINT},
        {display = "KIROSHI OPTICS", key = "Kiroshi", color = Colors.KIROSHI},
        {display = "PHASE SHIFT", key = "Optical", color = Colors.OPTICAL},
        {display = "NEURAL DODGE", key = "Dodge", color = Colors.DODGE_START}
    }
    for _, ab in ipairs(abilitiesList) do
        local row = Create("Frame", {Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = Colors.UI_BG, BorderSizePixel = 0, Parent = scroll})
        Create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = row})
        Create("TextLabel", {Size = UDim2.new(0.64, 0, 1, 0), BackgroundTransparency = 1, Text = "  " .. ab.display, TextColor3 = ab.color, Font = Enum.Font.SciFi, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Parent = row})

        local tog = Create("TextButton", {Size = UDim2.new(0.29, 0, 0.78, 0), Position = UDim2.new(0.68, 0, 0.11, 0), Text = EnabledAbilities[ab.key] and "ON" or "OFF", BackgroundColor3 = EnabledAbilities[ab.key] and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(200, 40, 40), TextColor3 = Color3.new(1,1,1), Font = Enum.Font.SciFi, TextSize = 17, Parent = row})
        Create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = tog})

        tog.MouseButton1Click:Connect(function()
    EnabledAbilities[ab.key] = not EnabledAbilities[ab.key]
    tog.Text = EnabledAbilities[ab.key] and "ON" or "OFF"
    tog.BackgroundColor3 = EnabledAbilities[ab.key] and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(200, 40, 40)
    if ab.key == "Dodge" and not EnabledAbilities.Dodge then State.IsDodgeReady = false end
    local btnName = AbilityMap[ab.key]
    if btnName and SkillContainers[btnName] then
        local visible = EnabledAbilities[ab.key]
        if btnName == "DodgeBtn" then visible = visible and DodgeMode == "Counter" end
        SkillContainers[btnName].Visible = visible
    end
    SaveConfig()
end)
    end

    local modeRow = Create("Frame", {Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = Colors.UI_BG, BorderSizePixel = 0, Parent = scroll})
    Create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = modeRow})
    Create("TextLabel", {Size = UDim2.new(0.64, 0, 1, 0), BackgroundTransparency = 1, Text = "  DODGE MODE", TextColor3 = Colors.DODGE_START, Font = Enum.Font.SciFi, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Parent = modeRow})
    local modeToggle = Create("TextButton", {Size = UDim2.new(0.29, 0, 0.78, 0), Position = UDim2.new(0.68, 0, 0.11, 0), Text = DodgeMode == "Counter" and "COUNTER" or "AUTO", BackgroundColor3 = DodgeMode == "Counter" and Color3.fromRGB(255, 165, 0) or Color3.fromRGB(0, 255, 255), TextColor3 = Color3.new(1,1,1), Font = Enum.Font.SciFi, TextSize = 17, Parent = modeRow})
    Create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = modeToggle})
    modeToggle.MouseButton1Click:Connect(function()
    if DodgeMode == "Counter" then
        DodgeMode = "Auto"
        modeToggle.Text = "AUTO"
        modeToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    else
        DodgeMode = "Counter"
        modeToggle.Text = "COUNTER"
        modeToggle.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
    end
    if SkillContainers["DodgeBtn"] then SkillContainers["DodgeBtn"].Visible = (EnabledAbilities.Dodge and DodgeMode == "Counter") end
    SaveConfig()
end)

    local liteRow = Create("Frame", {Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = Colors.UI_BG, BorderSizePixel = 0, Parent = scroll})
    Create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = liteRow})
    Create("TextLabel", {Size = UDim2.new(0.65, 0, 1, 0), BackgroundTransparency = 1, Text = "  MODO LITE", TextColor3 = Colors.UI_NEON, Font = Enum.Font.SciFi, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Parent = liteRow})
    local liteToggle = Create("TextButton", {Size = UDim2.new(0.28, 0, 0.75, 0), Position = UDim2.new(0.69, 0, 0.125, 0), Text = LiteMode and "ON" or "OFF", BackgroundColor3 = LiteMode and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(200, 40, 40), TextColor3 = Color3.new(1,1,1), Font = Enum.Font.SciFi, TextSize = 17, Parent = liteRow})
    Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = liteToggle})
    liteToggle.MouseButton1Click:Connect(function()
    LiteMode = not LiteMode
    liteToggle.Text = LiteMode and "ON" or "OFF"
    liteToggle.BackgroundColor3 = LiteMode and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(200, 40, 40)
    SaveConfig()
end)

    local noclipRow = Create("Frame", {Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = Colors.UI_BG, BorderSizePixel = 0, Parent = scroll})
    Create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = noclipRow})
    Create("TextLabel", {Size = UDim2.new(0.65, 0, 1, 0), BackgroundTransparency = 1, Text = "  NOCLIP", TextColor3 = Colors.UI_NEON, Font = Enum.Font.SciFi, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Parent = noclipRow})
    local noclipToggle = Create("TextButton", {Size = UDim2.new(0.28, 0, 0.75, 0), Position = UDim2.new(0.69, 0, 0.125, 0), Text = Noclip and "ON" or "OFF", BackgroundColor3 = Noclip and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(200, 40, 40), TextColor3 = Color3.new(1,1,1), Font = Enum.Font.SciFi, TextSize = 17, Parent = noclipRow})
    Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = noclipToggle})
    noclipToggle.MouseButton1Click:Connect(function()
        ToggleNoclip()
        noclipToggle.Text = Noclip and "ON" or "OFF"
        noclipToggle.BackgroundColor3 = Noclip and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(200, 40, 40)
    end)

local lineRow = Create("Frame", {Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = Colors.UI_BG, BorderSizePixel = 0, Parent = scroll})
Create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = lineRow})
Create("TextLabel", {Size = UDim2.new(0.65, 0, 1, 0), BackgroundTransparency = 1, Text = "  LINE", TextColor3 = Colors.UI_NEON, Font = Enum.Font.SciFi, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Parent = lineRow})
local lineToggle = Create("TextButton", {Size = UDim2.new(0.28, 0, 0.75, 0), Position = UDim2.new(0.69, 0, 0.125, 0), Text = lineEnabled and "ON" or "OFF", BackgroundColor3 = lineEnabled and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(200, 40, 40), TextColor3 = Color3.new(1,1,1), Font = Enum.Font.SciFi, TextSize = 17, Parent = lineRow})
Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = lineToggle})
lineToggle.MouseButton1Click:Connect(function()
    Toggleline()
    lineToggle.Text = lineEnabled and "ON" or "OFF"
    lineToggle.BackgroundColor3 = lineEnabled and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(200, 40, 40)
end)

    local keybindsHeader = Create("TextLabel", {Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Text = "  CUSTOM KEYBINDS", TextColor3 = Colors.UI_NEON, Font = Enum.Font.SciFi, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, Parent = scroll})

    local keybindList = {
        {name = "DASH IMPULSE", ab = "Dash", color = Colors.DASH_GREEN},
        {name = "SANDEVISTAN", ab = "Sandi", color = Colors.SANDI_TINT},
        {name = "KIROSHI OPTICS", ab = "Kiroshi", color = Colors.KIROSHI},
        {name = "PHASE SHIFT", ab = "Optical", color = Colors.OPTICAL},
        {name = "NEURAL DODGE", ab = "Dodge", color = Colors.DODGE_START}
    }
    for _, kb in ipairs(keybindList) do
        local row = Create("Frame", {Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = Colors.UI_BG, BorderSizePixel = 0, Parent = scroll})
        Create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = row})
        Create("TextLabel", {Size = UDim2.new(0.48, 0, 1, 0), BackgroundTransparency = 1, Text = "  " .. kb.name, TextColor3 = kb.color, Font = Enum.Font.SciFi, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Parent = row})
        local currentKeyText = Create("TextLabel", {Size = UDim2.new(0.26, 0, 1, 0), Position = UDim2.new(0.48, 0, 0, 0), BackgroundTransparency = 1, Text = CurrentKeybinds[kb.ab].Name, TextColor3 = Colors.UI_NEON, Font = Enum.Font.Code, TextSize = 21, Parent = row})
        KeybindCurrentTexts[kb.ab] = currentKeyText
        local rebindButton = Create("TextButton", {Size = UDim2.new(0.22, 0, 0.78, 0), Position = UDim2.new(0.76, 0, 0.11, 0), Text = "REBIND", BackgroundColor3 = Colors.UI_ACCENT, TextColor3 = Colors.UI_NEON, Font = Enum.Font.SciFi, TextSize = 16, Parent = row})
        Create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = rebindButton})
        rebindButton.MouseButton1Click:Connect(function() RebindingAbility = kb.ab end)
    end

    local setsRow = Create("Frame", {Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, Parent = scroll})
    local setsBtn = Create("TextButton", {Size = UDim2.new(0.9, 0, 0, 50), Position = UDim2.new(0.05, 0, 0, 6), Text = " TROCA SET", BackgroundColor3 = setColors[currentSet], TextColor3 = Colors.UI_NEON, Font = Enum.Font.SciFi, TextSize = 21, Parent = setsRow})
    Create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = setsBtn})
    Create("UIStroke", {Color = Colors.UI_NEON, Thickness = 2.5, Parent = setsBtn})
        setsBtn.MouseButton1Click:Connect(function()
    if currentSet == 1 then
        currentSet = 2
        setsBtn.BackgroundColor3 = setColors[2]
        AplicarSet(SET_2)
    elseif currentSet == 2 then
        currentSet = 3
        setsBtn.BackgroundColor3 = setColors[3]
        AplicarSet(SET_3)
    else
        currentSet = 1
        setsBtn.BackgroundColor3 = setColors[1]
        AplicarSet(SET_1)
    end
    SaveConfig()
end)

    scroll.CanvasSize = UDim2.new(0, 0, 0, scroll.UIListLayout.AbsoluteContentSize.Y + 160)

    MakeDraggable(gui:FindFirstChild("EnergyBar"), gui:FindFirstChild("EnergyBar"))
    lockBtn.MouseButton1Click:Connect(function()
    State.EditMode = not State.EditMode
    lockBtn.BackgroundColor3 = State.EditMode and Colors.EDIT_MODE or Colors.UI_DARK
    lockBtn.TextColor3 = State.EditMode and Colors.UI_DARK or Colors.UI_NEON
    for _, item in ipairs(UI_Elements) do item.Stroke.Enabled = State.EditMode end
    
    if not State.EditMode then
        savedPositions["EnergyBar"] = gui:FindFirstChild("EnergyBar") and gui:FindFirstChild("EnergyBar").Position or savedPositions["EnergyBar"]
        savedPositions["DashBtn"] = gui:FindFirstChild("DashBtnContainer") and gui:FindFirstChild("DashBtnContainer").Position or savedPositions["DashBtn"]
        savedPositions["SandiBtn"] = gui:FindFirstChild("SandiBtnContainer") and gui:FindFirstChild("SandiBtnContainer").Position or savedPositions["SandiBtn"]
        savedPositions["KiroshiBtn"] = gui:FindFirstChild("KiroshiBtnContainer") and gui:FindFirstChild("KiroshiBtnContainer").Position or savedPositions["KiroshiBtn"]
        savedPositions["OpticalBtn"] = gui:FindFirstChild("OpticalBtnContainer") and gui:FindFirstChild("OpticalBtnContainer").Position or savedPositions["OpticalBtn"]
        savedPositions["DodgeBtn"] = gui:FindFirstChild("DodgeBtnContainer") and gui:FindFirstChild("DodgeBtnContainer").Position or savedPositions["DodgeBtn"]
        
        SaveConfig()
    end
end)

    UpdateDashButton()
    UpdateKiroshiButton()
    UpdateOpticalButton()
    if SkillContainers["DodgeBtn"] then SkillContainers["DodgeBtn"].Visible = (EnabledAbilities.Dodge and DodgeMode == "Counter") end
    
    task.spawn(function()
        while gui.Parent do
            task.wait(30)
        end
    end)
    
    for _, btnName in pairs({"DashBtn", "SandiBtn", "KiroshiBtn", "OpticalBtn", "DodgeBtn"}) do
        local container = gui:FindFirstChild(btnName .. "Container")
        if container then
            local btn = container:FindFirstChild(btnName)
            if btn then
                PulseAnimation(btn)
            end
        end
    end
end

local walkConn: RBXScriptConnection? = nil
local function InitWalkEffect()
    if walkConn then walkConn:Disconnect() walkConn = nil end
    if LiteMode then return end
    walkConn = RunService.RenderStepped:Connect(function()
        if not Humanoid or not Humanoid.Parent then return end
        local CT = tick()
        if Humanoid.MoveDirection.Magnitude > 0 then
            local BobbleX = math.cos(CT*5)*0.25
            local BobbleY = math.abs(math.sin(CT*5))*0.25
            local Bobble = Vector3.new(BobbleX,BobbleY,0)
            Humanoid.CameraOffset = Humanoid.CameraOffset:lerp(Bobble, 0.25)
        else
            Humanoid.CameraOffset = Humanoid.CameraOffset * 0.75
        end
    end)
end

local Joints = {}
local JointsC0 = {}
local JointTilts = {}
local DefaultLerpAlpha = 0.145
local dotThreshold = 0.9
local lastTime = 0
local tickRate = 1 / 60

local function LerpJoints(moveDirection, angles)
    JointTilts.RootJointTilt = JointTilts.RootJointTilt:Lerp(CFrame.Angles(unpack(angles.RootJoint)), DefaultLerpAlpha)
    Joints.RootJoint.C0 = JointsC0.RootJointC0 * JointTilts.RootJointTilt
    JointTilts.NeckTilt = JointTilts.NeckTilt:Lerp(CFrame.Angles(unpack(angles.Neck)), DefaultLerpAlpha)
    Joints.Neck.C0 = JointsC0.NeckC0 * JointTilts.NeckTilt
    JointTilts.RightShoulderTilt = JointTilts.RightShoulderTilt:Lerp(CFrame.Angles(unpack(angles.RightShoulder)), DefaultLerpAlpha)
    Joints.RightShoulder.C0 = JointsC0.RightShoulderC0 * JointTilts.RightShoulderTilt
    JointTilts.LeftShoulderTilt = JointTilts.LeftShoulderTilt:Lerp(CFrame.Angles(unpack(angles.LeftShoulder)), DefaultLerpAlpha)
    Joints.LeftShoulder.C0 = JointsC0.LeftShoulderC0 * JointTilts.LeftShoulderTilt
    JointTilts.RightHipTilt = JointTilts.RightHipTilt:Lerp(CFrame.Angles(unpack(angles.RightHip)), DefaultLerpAlpha)
    Joints.RightHip.C0 = JointsC0.RightHipC0 * JointTilts.RightHipTilt
    JointTilts.LeftHipTilt = JointTilts.LeftHipTilt:Lerp(CFrame.Angles(unpack(angles.LeftHip)), DefaultLerpAlpha)
    Joints.LeftHip.C0 = JointsC0.LeftHipC0 * JointTilts.LeftHipTilt
end

local function UpdateDirectionalMovement()
    local now = workspace:GetServerTimeNow()
    if now - lastTime >= tickRate then
        lastTime = now
        local moveDirection = HRP.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
        if moveDirection:Dot(Vector3.new(1,0,-1).Unit) > dotThreshold then
            LerpJoints(moveDirection, {RootJoint = {math.rad(-moveDirection.Z) * 5, 0, math.rad(-moveDirection.X) * 25}, Neck = {math.rad(moveDirection.Z) * 5, 0, math.rad(moveDirection.X) * 15}, RightShoulder = {0, math.rad(-moveDirection.X) * 10, 0}, LeftShoulder = {0, math.rad(-moveDirection.X) * 10, 0}, RightHip = {0, math.rad(-moveDirection.X) * 10, 0}, LeftHip = {0, math.rad(-moveDirection.X) * 10, 0}})
        elseif moveDirection:Dot(Vector3.new(1,0,1).Unit) > dotThreshold then
            LerpJoints(moveDirection, {RootJoint = {math.rad(-moveDirection.Z) * 5, 0, math.rad(moveDirection.X) * 25}, Neck = {math.rad(moveDirection.Z) * 5, 0, math.rad(-moveDirection.X) * 25}, RightShoulder = {0, math.rad(moveDirection.X) * 10, 0}, LeftShoulder = {0, math.rad(moveDirection.X) * 10, 0}, RightHip = {0, math.rad(moveDirection.X) * 10, 0}, LeftHip = {0, math.rad(moveDirection.X) * 10, 0}})
        elseif moveDirection:Dot(Vector3.new(-1,0,1).Unit) > dotThreshold then
            LerpJoints(moveDirection, {RootJoint = {math.rad(-moveDirection.Z) * 5, 0, math.rad(moveDirection.X) * 25}, Neck = {math.rad(moveDirection.Z) * 5, 0, math.rad(-moveDirection.X) * 25}, RightShoulder = {0, math.rad(moveDirection.X) * 10, 0}, LeftShoulder = {0, math.rad(moveDirection.X) * 10, 0}, RightHip = {0, math.rad(moveDirection.X) * 10, 0}, LeftHip = {0, math.rad(moveDirection.X) * 10, 0}})
        elseif moveDirection:Dot(Vector3.new(-1,0,-1).Unit) > dotThreshold then
            LerpJoints(moveDirection, {RootJoint = {math.rad(-moveDirection.Z) * 5, 0, math.rad(-moveDirection.X) * 25}, Neck = {math.rad(moveDirection.Z) * 5, 0, math.rad(moveDirection.X) * 15}, RightShoulder = {0, math.rad(-moveDirection.X) * 10, 0}, LeftShoulder = {0, math.rad(-moveDirection.X) * 10, 0}, RightHip = {0, math.rad(-moveDirection.X) * 10, 0}, LeftHip = {0, math.rad(-moveDirection.X) * 10, 0}})
        elseif moveDirection:Dot(Vector3.new(0,0,-1).Unit) > dotThreshold then
            LerpJoints(moveDirection, {RootJoint = {math.rad(-moveDirection.Z) * 10, 0, 0}, Neck = {math.rad(moveDirection.Z) * 10, 0, 0}, RightShoulder = {0, 0, 0}, LeftShoulder = {0, 0, 0}, RightHip = {0, 0, 0}, LeftHip = {0, 0, 0}})
        elseif moveDirection:Dot(Vector3.new(1,0,0).Unit) > dotThreshold then
            LerpJoints(moveDirection, {RootJoint = {0, 0, math.rad(-moveDirection.X) * 35}, Neck = {0, 0, math.rad(moveDirection.X) * 35}, RightShoulder = {0, math.rad(-moveDirection.X) * 15, 0}, LeftShoulder = {0, math.rad(-moveDirection.X) * 15, 0}, RightHip = {0, math.rad(-moveDirection.X) * 15, 0}, LeftHip = {0, math.rad(-moveDirection.X) * 15, 0}})
        elseif moveDirection:Dot(Vector3.new(0,0,1).Unit) > dotThreshold then
            LerpJoints(moveDirection, {RootJoint = {math.rad(-moveDirection.Z) * 10, 0, 0}, Neck = {math.rad(moveDirection.Z) * 10, 0, 0}, RightShoulder = {0, 0, 0}, LeftShoulder = {0, 0, 0}, RightHip = {0, 0, 0}, LeftHip = {0, 0, 0}})
        elseif moveDirection:Dot(Vector3.new(-1,0,0).Unit) > dotThreshold then
            LerpJoints(moveDirection, {RootJoint = {0, 0, math.rad(-moveDirection.X) * 35}, Neck = {0, 0, math.rad(moveDirection.X) * 35}, RightShoulder = {0, math.rad(-moveDirection.X) * 15, 0}, LeftShoulder = {0, math.rad(-moveDirection.X) * 15, 0}, RightHip = {0, math.rad(-moveDirection.X) * 15, 0}, LeftHip = {0, math.rad(-moveDirection.X) * 15, 0}})
        else
            LerpJoints(moveDirection, {RootJoint = {0, 0, 0}, Neck = {0, 0, 0}, RightShoulder = {0, 0, 0}, LeftShoulder = {0, 0, 0}, RightHip = {0, 0, 0}, LeftHip = {0, 0, 0}})
        end
    end
end

local dirConn: RBXScriptConnection? = nil
local function InitDirectionalMovement()
    if dirConn then dirConn:Disconnect() dirConn = nil end
    if LiteMode then return end
    local torso = Character:FindFirstChild("UpperTorso") or Character:FindFirstChild("Torso")
    if not torso then return end
    
    local isR15 = (torso:FindFirstChild("Neck") ~= nil)
    
    if isR15 then
        local rootJoint = HRP:FindFirstChild("RootJoint")
        local neck = torso:FindFirstChild("Neck")
        local rightShoulder = torso:FindFirstChild("Right Shoulder")
        local leftShoulder = torso:FindFirstChild("Left Shoulder")
        local rightHip = torso:FindFirstChild("Right Hip")
        local leftHip = torso:FindFirstChild("Left Hip")
        
        if not rootJoint or not neck or not rightShoulder or not leftShoulder or not rightHip or not leftHip then
            return
        end
        
        Joints = {
            RootJoint = rootJoint,
            Neck = neck,
            RightShoulder = rightShoulder,
            LeftShoulder = leftShoulder,
            RightHip = rightHip,
            LeftHip = leftHip
        }
        
        JointsC0 = {
            RootJointC0 = rootJoint.C0,
            NeckC0 = neck.C0,
            RightShoulderC0 = rightShoulder.C0,
            LeftShoulderC0 = leftShoulder.C0,
            RightHipC0 = rightHip.C0,
            LeftHipC0 = leftHip.C0
        }
        
        JointTilts = {
            RootJointTilt = CFrame.new(),
            NeckTilt = CFrame.new(),
            RightShoulderTilt = CFrame.new(),
            LeftShoulderTilt = CFrame.new(),
            RightHipTilt = CFrame.new(),
            LeftHipTilt = CFrame.new()
        }
        
        dirConn = RunService.Heartbeat:Connect(UpdateDirectionalMovement)
    end
end

RunService.Heartbeat:Connect(function(dt)
    if not HRP or not Humanoid then return end
    if Humanoid.Health < State.LastHealth then
    local dmgDealt = State.LastHealth - Humanoid.Health
    if dmgDealt > 1 then FalasDano(dmgDealt) end
    if dmgDealt > 1 and State.IsDodgeReady and EnabledAbilities.Dodge and not IsDodging then
        local ca = nil
        local ld = 25
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {Character}
        for _, p in ipairs(Workspace:GetPartBoundsInRadius(HRP.Position, 25, params)) do
            local model = p:FindFirstAncestorOfClass("Model")
            if model and model ~= Character and model:FindFirstChildOfClass("Humanoid") then
                local r = model:FindFirstChild("HumanoidRootPart")
                if r then
                    local d = (HRP.Position - r.Position).Magnitude
                    if d < ld then ld = d ca = r end
                end
            end
        end
        ExecDodge(ca)
        if DodgeMode == "Auto" then
            if State.Energy >= Constants.ENERGY_COSTS.DODGE then
                State.Energy -= Constants.ENERGY_COSTS.DODGE
                State.Energy = math.max(0, State.Energy)
                State.NoRegenUntil = os.clock() + Constants.REGEN_DELAY_USE
            end
        end
    end
end
    State.LastHealth = Humanoid.Health
    State.LastVelocityY = HRP.Velocity.Y
    local isMoving = HRP.Velocity.Magnitude > Constants.MOVING_THRESHOLD
    if State.IsSandiActive then
        State.Energy -= Constants.ENERGY_COSTS.SANDI_DRAIN * dt
        State.Energy = math.max(0, State.Energy)
        Humanoid.WalkSpeed = Constants.SANDI_SPEED
        if isMoving then
            if os.clock() - lastSandiClone > Constants.HOLOGRAM_CLONE.SANDI.DELAY then
                CreateHologramClone(Constants.HOLOGRAM_CLONE.SANDI.DELAY, Constants.HOLOGRAM_CLONE.SANDI.DURATION, Constants.HOLOGRAM_CLONE.SANDI.END_TRANSPARENCY, 0, 0, 0, "sandi")
                lastSandiClone = os.clock()
            end
            if sandiLoopSound and not sandiLoopSound.Playing then sandiLoopSound:Play()
            elseif not sandiLoopSound then
                sandiLoopSound = Create("Sound", {SoundId = Sounds.SANDI_LOOP.id, Volume = Sounds.SANDI_LOOP.volume, PlaybackSpeed = Sounds.SANDI_LOOP.pitch, Looped = Sounds.SANDI_LOOP.looped, Parent = HRP})
                sandiLoopSound:Play()
            end
        else
            if sandiLoopSound and sandiLoopSound.Playing then sandiLoopSound:Stop() end
        end
        if State.Energy <= 0 then
            State.NoRegenUntil = os.clock() + Constants.REGEN_DELAY_ZERO
            Falar("sandi_zerou")
            local luck = math.random(1, 100)
            if luck <= 30 then ExecCyberpsychosis() end
            ResetSandi()
        end
    else
        if os.clock() > State.NoRegenUntil then
            State.Energy = math.min(Constants.MAX_ENERGY, State.Energy + (Constants.REGEN_RATE * dt))
        end
    end
    if DodgeMode == "Auto" and os.clock() >= State.Cooldowns.DODGE and not State.IsDodgeReady and not IsDodging and State.Energy >= Constants.ENERGY_COSTS.DODGE and EnabledAbilities.Dodge then
        ActivateDodgeReady()
    end
    if energyFill and energyPercentLabel then
        local percent = State.Energy / Constants.MAX_ENERGY
        local safePercent = math.max(0.02, percent)
energyFill.Size = UDim2.new(1, -10, safePercent, -10)
        energyPercentLabel.Text = string.format("%d%%", math.floor(State.Energy))
        local barColor
        if percent > 0.6 then
            barColor = Colors.LIGHT_GREEN
        elseif percent > 0.3 then
            barColor = Colors.ENERGY_MEDIUM
        else
            barColor = Colors.ENERGY_LOW
        end
        energyFill.BackgroundColor3 = barColor
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if RebindingAbility then
        if input.KeyCode ~= Enum.KeyCode.Unknown then
            CurrentKeybinds[RebindingAbility] = input.KeyCode
            UpdateKeybind(RebindingAbility)
            if KeybindCurrentTexts[RebindingAbility] then 
                KeybindCurrentTexts[RebindingAbility].Text = input.KeyCode.Name 
            end
            RebindingAbility = nil
            SaveConfig()
        end
        return
    end
end)
      
local function SetupCharacter(character)
    ResetSandi()
    ResetOptical()
    CleanupSandiSounds()
    Character = character
    HRP = character:WaitForChild("HumanoidRootPart")
    Humanoid = character:WaitForChild("Humanoid")
    State.LastHealth = Humanoid.Health
    Humanoid.Died:Connect(function() Falar("morte", true) end)
    Humanoid.StateChanged:Connect(function(_, novo)
        if novo == Enum.HumanoidStateType.Landed and State.LastVelocityY < -55 then
            Falar("queda")
        end
    end)
    task.delay(1.5, function() Falar("boot") end)
    BuildUI()
    BindAllKeybinds()
    InitWalkEffect()
    InitDirectionalMovement()
    
    task.delay(2, function()
        if Character and Character.Parent then
            if currentSet == 1 then
                AplicarSet(SET_1)
            elseif currentSet == 2 then
                AplicarSet(SET_2)
            else
                AplicarSet(SET_3)
            end
        end
    end)
end

local function HandleChat(message)
    local msg = message:lower():gsub("%s+", "")
    if msg == "-settings" then
        local gui = Player.PlayerGui:FindFirstChild("CyberRebuilt")
        if gui then
            local menu = gui:FindFirstChild("SettingsMenu")
            if menu then
                local newState = not menu.Visible
                
                if newState then
                    menu.Visible = true
                    menu.Size = UDim2.new(0, 0, 0, 0)
                    menu.BackgroundTransparency = 1
                    TweenService:Create(menu, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                        Size = UDim2.new(0, 340, 0, 480),
                        BackgroundTransparency = 0
                    }):Play()
                    
                else
                    local closeTween = TweenService:Create(menu, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                        Size = UDim2.new(0, 0, 0, 0),
                        BackgroundTransparency = 1
                    })
                    closeTween:Play()
                    
                    closeTween.Completed:Connect(function()
                        menu.Visible = false
                    end)
                end
            end
        end
    end
end

local ultimoChatTexto, ultimoChatTempo = "", 0
local function OnChat(message)
    if type(message) ~= "string" then return end
    local agora = os.clock()
    -- evita rodar 2x quando Chatted e TextChatService disparam juntos
    if message == ultimoChatTexto and agora - ultimoChatTempo < 0.6 then return end
    ultimoChatTexto, ultimoChatTempo = message, agora
    HandleChat(message)
end

Player.Chatted:Connect(OnChat)
pcall(function()
    local TextChatService = game:GetService("TextChatService")
    TextChatService.SendingMessage:Connect(function(m)
        OnChat(m.Text)
    end)
    TextChatService.MessageReceived:Connect(function(m)
        if m.TextSource and m.TextSource.UserId == Player.UserId then
            OnChat(m.Text)
        end
    end)
end)

local function CyberSendNotification(title: string, text: string, duration: number?, imageId: string?)
    duration = duration or 4.8
    
    local gui = Player.PlayerGui:FindFirstChild("CyberRebuilt")
    if not gui then 
        gui = Create("ScreenGui", {Name = "CyberRebuilt", Parent = Player.PlayerGui, IgnoreGuiInset = true})
    end

    local notif = Create("Frame", {
        Name = "CyberNotification",
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(1, -340, 0, 70),
        BackgroundColor3 = Color3.fromRGB(6, 6, 12),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 999,
        Parent = gui
    })

    Create("UICorner", {CornerRadius = UDim.new(0, 16), Parent = notif})

    local strokeOuter = Create("UIStroke", {Color = Colors.SANDI_TINT, Thickness = 4, Transparency = 1, Parent = notif})
    local strokeInner = Create("UIStroke", {Color = Colors.UI_NEON, Thickness = 2, Transparency = 1, Parent = notif})
    
    local glow = Create("UIStroke", {
        Color = Colors.LIGHT_GREEN,
        Thickness = 12,
        Transparency = 0.8,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = notif
    })

    local image = Create("ImageLabel", {
        Size = UDim2.new(0, 78, 0, 78),
        Position = UDim2.new(0, 16, 0.5, -39),
        BackgroundTransparency = 1,
        Image = imageId or "rbxassetid://11540569225",
        ImageTransparency = 1,
        ZIndex = 1000,
        Parent = notif
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 14), Parent = image})

    local titleLabel = Create("TextLabel", {
        Size = UDim2.new(1, -110, 0, 32),
        Position = UDim2.new(0, 106, 0, 18),
        BackgroundTransparency = 1,
        Text = title:upper(),
        TextColor3 = Colors.SANDI_TINT,
        Font = Enum.Font.SciFi,
        TextSize = 23,
        TextStrokeTransparency = 0.4,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        ZIndex = 1000,
        Parent = notif
    })

    local descLabel = Create("TextLabel", {
        Size = UDim2.new(1, -110, 0, 44),
        Position = UDim2.new(0, 106, 0, 48),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Color3.fromRGB(180, 255, 205),
        Font = Enum.Font.Code,
        TextSize = 15.5,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
        ZIndex = 1000,
        Parent = notif
    })

    local creditLabel = Create("TextLabel", {
        Size = UDim2.new(1, -110, 0, 18),
        Position = UDim2.new(0, 106, 1, -24),
        BackgroundTransparency = 1,
        Text = "Script By Mini discord.gg/86Mmpe94cH",
        TextColor3 = Color3.fromRGB(100, 255, 180),
        Font = Enum.Font.Code,
        TextSize = 13,
        TextTransparency = 1,
        TextStrokeTransparency = 0.7,
        ZIndex = 1000,
        Parent = notif
    })

    task.spawn(function()
        TweenService:Create(notif, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 325, 0, 128),
            BackgroundTransparency = 0.08
        }):Play()

        TweenService:Create(strokeOuter, TweenInfo.new(0.5), {Transparency = 0.25}):Play()
        TweenService:Create(strokeInner, TweenInfo.new(0.55), {Transparency = 0.6}):Play()

        task.spawn(function()
            while notif.Parent do
                TweenService:Create(glow, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.55}):Play()
                task.wait(1.3)
                TweenService:Create(glow, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.82}):Play()
                task.wait(1.3)
            end
        end)

        task.wait(0.18)
        TweenService:Create(image, TweenInfo.new(0.45), {ImageTransparency = 0.08}):Play()
        TweenService:Create(titleLabel, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
        TweenService:Create(descLabel, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
        TweenService:Create(creditLabel, TweenInfo.new(0.6), {TextTransparency = 0.3}):Play()
    end)

    task.delay(duration, function()
        if not notif or not notif.Parent then return end

        TweenService:Create(notif, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 60, 0, 70),
            BackgroundTransparency = 1
        }):Play()

        TweenService:Create(glow, TweenInfo.new(0.4), {Transparency = 1}):Play()
        TweenService:Create(image, TweenInfo.new(0.4), {ImageTransparency = 1}):Play()
        TweenService:Create(titleLabel, TweenInfo.new(0.35), {TextTransparency = 1}):Play()
        TweenService:Create(descLabel, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
        TweenService:Create(creditLabel, TweenInfo.new(0.4), {TextTransparency = 1}):Play()

        task.delay(0.65, function()
            if notif and notif.Parent then notif:Destroy() end
        end)
    end)
end

local function Init()
    local savedConfig = LoadConfig()
    ApplyConfig(savedConfig)
    
    if Player.Character then 
        SetupCharacter(Player.Character)
        task.delay(0.3, SpawnAnimation)
        
        if currentSet == 1 then
            AplicarSet(SET_1)
        elseif currentSet == 2 then
            AplicarSet(SET_2)
        else
            AplicarSet(SET_3)
        end
    end
    
    Player.CharacterAdded:Connect(SetupCharacter)
end

task.delay(1.2, function()
    CyberSendNotification(
        "CYBER REBUILT 2077", 
        "NEURAL INTERFACE ONLINE\nSANDEVISTAN SYSTEM LOADED",
        5.5
    )
end)

Init()
