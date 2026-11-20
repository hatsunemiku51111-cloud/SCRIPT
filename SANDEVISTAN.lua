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

do
    local Env = (getgenv and getgenv()) or _G
    local Plrs = game:GetService("Players")
    local WS = game:GetService("Workspace")
    local LP = Plrs.LocalPlayer
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    params.RespectCanCollide = false

    local function blocked(origin, target)
        local dir = target - origin
        local dist = dir.Magnitude - 0.4
        if dist < 1 then return false end
        dir = dir.Unit * dist
        local ignore = {LP.Character, WS.CurrentCamera}
        for _ = 1, 8 do
            params.FilterDescendantsInstances = ignore
            local r = WS:Raycast(origin, dir, params)
            if not r then return false end
            local inst = r.Instance
            if inst:IsA("BasePart") and inst.Transparency < 0.6 and inst.CanQuery then
                return true
            end
            table.insert(ignore, inst)
        end
        return false
    end

    Env.SandiVPOccluded = function(points)
        local cam = WS.CurrentCamera
        if not cam or not points then return false end
        local origin = cam.CFrame.Position
        for _, pt in ipairs(points) do
            if not blocked(origin, pt) then return false end
        end
        return #points > 0
    end

    Env.SandiVPBodyPoints = function(root, spread)
        if not root or not root.Parent then return nil end
        local pos = root.Position
        local pts = {pos + Vector3.new(0, 2.2, 0), pos, pos - Vector3.new(0, 2.2, 0)}
        if spread then
            local r = root.CFrame.RightVector * spread
            table.insert(pts, pos + r)
            table.insert(pts, pos - r)
        end
        return pts
    end
end

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
        EnergyBar = {ScaleX = 0, OffsetX = 28, ScaleY = 0.5, OffsetY = -140},
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
    Psychosis: number,
    PsychosisIdleSince: number,
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
        Duration = 12,
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
    KIROSHI_RED = Color3.fromRGB(90, 215, 255),
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
    KIROSHI_TINT = Color3.fromRGB(90, 215, 255),
    KIROSHI = Color3.fromRGB(90, 215, 255),
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
    SANDI_FAILURE = {id = "rbxassetid://132281440773764", volume = 5, pitch = 1, looped = false},
    PSYCHOSIS = {id = "rbxassetid://113922641197855", volume = 2, pitch = 1, looped = false},  -- David crash out part 1 (5s)
    PSYCHOSIS2 = {id = "rbxassetid://89548438635345", volume = 2, pitch = 1, looped = false}, -- David crash out part 2 (4s)
    PSYCHOSIS3 = {id = "rbxassetid://92219907157626", volume = 2.2, pitch = 1, looped = false}, -- "Fucking dead!" (2s)
    OPTICAL_CAMO = {id = "rbxassetid://134007213357026", volume = 1, pitch = 1, looped = false},
    COLLISION_IMPACT = {id = "rbxassetid://86227700557194", volume = 1.7, pitch = 1, looped = false},
    SPAWN = {id = "rbxassetid://138566469626743", volume = 1.5, pitch = 1, looped = false},
    KIROSHI_ON = {id = "rbxassetid://101563346734882", volume = 2.2, pitch = 1.05, looped = false},
    KIROSHI_OFF = {id = "rbxassetid://79307196411649", volume = 1.8, pitch = 0.95, looped = false}
}

-- PRÉ-CARREGAMENTO: sons e imagens baixam em segundo plano ao carregar o script, então a
-- primeira ativação/dash/esquiva não engasga esperando o asset chegar do servidor.
task.spawn(function()
    local PRELOAD_DEBUG = false -- true = imprime no output o que falhou ao carregar
    local extraSounds = {
        "rbxassetid://97097078816969",  -- SystemRestore
        "rbxassetid://121480304779842", -- spawn
    }
    local extraImages = {
        "rbxassetid://138778899925146", -- ícone da psicose
        "rbxassetid://11540569225",     -- ícone da notificação
    }

    local list = {}
    for _, cfg in pairs(Sounds) do
        local snd = Instance.new("Sound")
        snd.SoundId = cfg.id
        table.insert(list, snd)
    end
    for _, id in ipairs(extraSounds) do
        local snd = Instance.new("Sound")
        snd.SoundId = id
        table.insert(list, snd)
    end
    for _, id in ipairs(extraImages) do
        local img = Instance.new("ImageLabel")
        img.Image = id
        table.insert(list, img)
    end

    -- em lotes pequenos (não trava o carregamento do jogo)
    local BATCH = 8
    for i = 1, #list, BATCH do
        local batch = table.move(list, i, math.min(i + BATCH - 1, #list), 1, {})
        pcall(function()
            ContentProvider:PreloadAsync(batch, function(assetId, status)
                if PRELOAD_DEBUG and status ~= Enum.AssetFetchStatus.Success then
                    warn("[Preload] falhou:", assetId, status)
                end
            end)
        end)
    end

    for _, inst in ipairs(list) do inst:Destroy() end
end)

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

-- Sons criados por ESTE script (não são pausados quando o tempo congela)
local ScriptSounds = setmetatable({}, {__mode = "k"})

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
    ScriptSounds[som] = true
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
    LastSandiActivation = 0,
    Psychosis = 0,
    PsychosisIdleSince = 0
}

-- ========== BARRA DE CYBERPSYCHOSIS (0 a 100%) ==========
-- Sobe enquanto o Sandevistan está ativo e a cada uso/falha; desce sozinha quando você
-- fica um tempo sem usar. Passou de 50% = zona de perigo (vermelho pulsando).
-- Chegou em 100% = dispara a Cyberpsychosis e a barra reseta.
local PsyBar = {
    MAX = 100,
    -- ganhos (bem mais baixos que antes) --
    GAIN_SANDI = 1.1,     -- % por segundo com o Sandevistan ligado
    GAIN_ACTIVATE = 4,    -- % ao ativar o Sandevistan
    GAIN_FAILURE = 6,    -- % quando o Sandevistan falha (overload)
    GAIN_ZERO = 5,       -- % quando a energia zera com o Sandevistan ligado
    -- resistencia: quanto mais perto dos 100%, menos cada ganho rende (0.75 = ganho cai ate 25%)
    RESISTANCE = 0.75,
    -- queda (mais rapida, e ainda mais rapida acima de 50%)
    DECAY_DELAY = 4,      -- segundos sem usar NENHUMA habilidade antes de comecar a cair
    DECAY_STEP = 1,       -- % que cai por tick
    DECAY_INTERVAL = 3,   -- segundos entre cada tick de queda
    -- spam: usar habilidades em sequencia (janela abaixo) aumenta ganho e chance de falha
    SPAM_WINDOW = 8,
    SPAM_GAIN_STEP = 0.2,   -- +20% de ganho por uso recente (maximo 5 usos)
    SPAM_FAIL_STEP = 0.02,  -- +2% de chance de falha por uso recente
    -- chance de Cyberpsychosis direta (sem esperar a barra) agora depende da barra
    DIRECT_FAIL_BASE = 0.03, DIRECT_FAIL_SCALE = 0.12,   -- quando o Sandevistan falha
    DIRECT_ZERO_BASE = 0.05, DIRECT_ZERO_SCALE = 0.25,   -- quando a energia zera no Sandi
    RESET_TO = 0,         -- valor da barra depois da Cyberpsychosis
    Busy = false,         -- true enquanto a Cyberpsychosis da barra esta rolando
    Recent = {},          -- timestamps dos usos recentes (anti-spam)
    -- Quanto mais forte/roubada a habilidade, mais cara em psicose e mais arriscada:
    --  gain      = % de psicose por uso
    --  failBase  = chance de falha com a barra "limpa" (a partir de failStart)
    --  failMax   = chance de falha com a barra em 100%
    --  failStart = % da barra a partir da qual o risco comeca a subir
    --  surcharge = energia extra gasta com a barra em 100% (proporcional)
    --  extraCd   = segundos a mais de cooldown quando a habilidade da glitch
    ABILITY = {
        Dash    = {gain = 1,  failBase = 0,    failMax = 0.12, failStart = 40, surcharge = 2,  extraCd = 1.5, label = "DASH MISFIRE"},
        Kiroshi = {gain = 2,  failBase = 0,    failMax = 0.18, failStart = 30, surcharge = 4,  extraCd = 3,   label = "KIROSHI GLITCH"},
        Dodge   = {gain = 3,  failBase = 0,    failMax = 0.22, failStart = 30, surcharge = 3,  extraCd = 4,   label = "DODGE LAG"},
        Optical = {gain = 6,  failBase = 0.05, failMax = 0.40, failStart = 0,  surcharge = 10, extraCd = 6,   label = "PHASE MALFUNCTION"},
        Sandi   = {gain = 4,  failBase = 0.20, failMax = 0.50, failStart = 0,  surcharge = 0,  extraCd = 0,   label = "SANDEVISTAN OVERLOAD"},
    },
    -- cores: vermelho e preto
    COLOR_LOW = Color3.fromRGB(95, 0, 10),
    COLOR_MID = Color3.fromRGB(200, 0, 15),
    COLOR_HIGH = Color3.fromRGB(255, 25, 25),
}

-- adiciona psicose com resistencia (quanto mais cheia a barra, menos o ganho rende)
function PsyBar.Add(amount: number)
    if amount <= 0 or PsyBar.Busy then return end
    local frac = math.clamp(State.Psychosis / PsyBar.MAX, 0, 1)
    local resist = 1 - PsyBar.RESISTANCE * (frac ^ 1.5)
    State.Psychosis = math.min(PsyBar.MAX, State.Psychosis + amount * resist)
    State.PsychosisIdleSince = os.clock()
end

-- quantos usos de habilidade aconteceram na janela anti-spam
function PsyBar.RecentUses(): number
    local now = os.clock()
    local n = 0
    for i = #PsyBar.Recent, 1, -1 do
        if now - PsyBar.Recent[i] > PsyBar.SPAM_WINDOW then
            table.remove(PsyBar.Recent, i)
        else
            n += 1
        end
    end
    return n
end

-- chance atual de a habilidade dar glitch (depende da barra + spam)
function PsyBar.FailChance(key: string): number
    local cfg = PsyBar.ABILITY[key]
    if not cfg then return 0 end
    local span = math.max(1, PsyBar.MAX - cfg.failStart)
    local t = math.clamp((State.Psychosis - cfg.failStart) / span, 0, 1)
    local chance = cfg.failBase + (cfg.failMax - cfg.failBase) * t
    chance += PsyBar.SPAM_FAIL_STEP * math.min(PsyBar.RecentUses(), 5)
    return math.clamp(chance, 0, 0.85)
end


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
local psyFill: Frame
local psyPercentLabel: TextLabel
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
    ScriptSounds[instance] = true -- (nome antigo: vale p/ qualquer instância criada pelo script)
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
-- SISTEMA DE FALAS = LEGENDAS (estilo CyberPsychosis)
-- Cada fala aparece como legenda de tela (nome do falante + texto com
-- camadas ciano/magenta e glitch), no mesmo visual da cena da Cyberpsychosis.
-- ============================================================
local TextService = game:GetService("TextService")

local FALAS_ATIVAS = true
local LEGENDA_NOME = nil              -- nil = nome da sua conta | ou fixe, ex.: "DAVID"
local LEGENDA_POS_Y = 0.72            -- altura da legenda na tela (0 = topo, 1 = base)
local LEGENDA_COR_NOME = Color3.fromRGB(0, 240, 255)
local LEGENDA_CIANO = Color3.fromRGB(0, 240, 255)
local LEGENDA_MAGENTA = Color3.fromRGB(255, 0, 140)
local LEGENDA_BRANCO = Color3.new(1, 1, 1)

-- Nome usado nas falas (troca o "David" pelo nome da sua conta)
local function NomeNaFala()
    local n = Player.DisplayName
    if not n or n == "" then n = Player.Name end
    return n
end

-- Emocoes: tremor/glitch/sussurro/pulo definem o estilo da legenda (cor e vel nao sao mais usados)
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

local fala = {gui = nil, raiz = nil, nome = nil, ciano = nil, magenta = nil, principal = nil, token = 0, prio = 0, fim = 0, gapAte = 0}
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

-- ---------- LEGENDA (estilo CyberPsychosis) ----------
-- Tela inteira, canto inferior: nome do falante em cima, texto branco com
-- camadas ciano (esquerda) e magenta (direita) tremendo por cima, estouros de
-- glitch (letras viram simbolos) e fade no fim. A emocao muda a intensidade.
local SIMBOLOS_GLITCH = {"#", "@", "%", "&", "?", "!", "/", "|", "0", "1", "<", ">", "X"}

local function falaEmbaralhar(texto, quantidade)
    local out = {}
    for _, cp in utf8.codes(texto) do
        if cp ~= 32 and math.random() < quantidade then
            table.insert(out, SIMBOLOS_GLITCH[math.random(1, #SIMBOLOS_GLITCH)])
        else
            table.insert(out, utf8.char(cp))
        end
    end
    return table.concat(out)
end

-- true enquanto a Cyberpsychosis esta rodando (ela tem a propria legenda no mesmo lugar)
local function falaPsicoseAtiva()
    local ok, ativa = pcall(function()
        local m = ((getgenv and getgenv()) or _G).CyberPsychosis
        return m ~= nil and m.IsActive ~= nil and m.IsActive() == true
    end)
    return ok and ativa
end

local function falaGarantirGui()
    if fala.gui and fala.gui.Parent then return fala end
    local gui = Create("ScreenGui", {
        Name = "CyberFalas",
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        DisplayOrder = 850,
        Parent = Player:WaitForChild("PlayerGui"),
    })
    pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None end)

    local raiz = Create("Frame", {
        Name = "Legenda",
        Size = UDim2.new(0.84, 0, 0, 84),
        Position = UDim2.new(0.08, 0, LEGENDA_POS_Y, 0),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 17,
        Parent = gui,
    })
    local nome = Create("TextLabel", {
        Name = "Nome",
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = LEGENDA_COR_NOME,
        Font = Enum.Font.Code,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 19,
        Parent = raiz,
    })
    local function camada(cor, z)
        local l = Create("TextLabel", {
            Size = UDim2.new(1, 0, 1, -20),
            Position = UDim2.new(0, 0, 0, 20),
            BackgroundTransparency = 1,
            Text = "",
            TextColor3 = cor,
            Font = Enum.Font.Code,
            TextScaled = true,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = z,
            Parent = raiz,
        })
        Create("UITextSizeConstraint", {MaxTextSize = 26, MinTextSize = 10, Parent = l})
        return l
    end
    fala.gui, fala.raiz, fala.nome = gui, raiz, nome
    fala.ciano = camada(LEGENDA_CIANO, 17)
    fala.magenta = camada(LEGENDA_MAGENTA, 17)
    fala.principal = camada(LEGENDA_BRANCO, 18)
    return fala
end

local function falaMostrar(texto, emo, inten, prio)
    local ui = falaGarantirGui()
    if not ui then return end
    local e = EMOCOES[emo] or EMOCOES.calmo
    if emo == "glitch" then
        inten = math.clamp(inten or 2, 1, 3)
    else
        inten = 1
    end

    fala.token += 1
    local meuToken = fala.token
    local quem = tostring(LEGENDA_NOME or NomeNaFala()):upper()

    -- tempos: entrada rapida com glitch, leitura proporcional ao tamanho, fade
    local nChars = utf8.len(texto) or #texto
    local tEntrada = 0.18
    local tLer = 1.3 + nChars * 0.05
    local tFade = 0.4
    local tFim = tLer + tFade
    local baseTrans = e.sussurro and 0.25 or 0
    local jitBase = 1 + math.floor(e.tremor * inten)
    local chanceKick = e.glitch and (1.2 * inten) or (e.tremor * 0.25)   -- estouros por segundo

    fala.prio = prio
    fala.fim = os.clock() + tFim
    fala.gapAte = fala.fim + 0.5
    falaUltimoTexto = texto

    ui.nome.Text = quem
    ui.nome.TextColor3 = LEGENDA_COR_NOME
    ui.principal.Text, ui.ciano.Text, ui.magenta.Text = texto, texto, texto
    ui.raiz.Visible = true

    task.spawn(function()
        local t0 = os.clock()
        local ultimo = t0
        local kick = 1   -- estouro de glitch na entrada
        while fala.token == meuToken do
            local agora = os.clock()
            local dt = agora - ultimo
            ultimo = agora
            local t = agora - t0
            if t >= tFim or falaPsicoseAtiva() then break end

            kick = math.max(0, kick - dt * 5)
            if chanceKick > 0 and math.random() < chanceKick * dt then kick = 1 end

            local fadeK = (t > tLer) and math.clamp((t - tLer) / tFade, 0, 1) or 0
            local entra = math.clamp(t / tEntrada, 0, 1)
            local trans = baseTrans + (1 - baseTrans) * fadeK
            trans = 1 - (1 - trans) * entra
            local transCamada = 1 - (1 - 0.35) * (1 - trans)

            -- camadas ciano/magenta tremem para lados opostos
            local jit = jitBase + math.floor(kick * 8) + ((t < tEntrada) and 4 or 0)
            ui.ciano.Position = UDim2.new(0, -math.random(0, jit), 0, 20 + math.random(-1, 1))
            ui.magenta.Position = UDim2.new(0, math.random(0, jit), 0, 20 + math.random(-1, 1))

            -- letras viram simbolos nos estouros (e levemente o tempo todo na emocao glitch)
            local scr = (kick > 0.4) and (0.12 * kick) or 0
            if e.glitch then scr = math.max(scr, 0.04 * inten) end
            if t < tEntrada then scr = math.max(scr, 0.25) end
            local novo = (scr > 0) and falaEmbaralhar(texto, scr) or texto
            if ui.principal.Text ~= novo then ui.principal.Text = novo end

            ui.principal.TextTransparency = trans
            ui.nome.TextTransparency = trans
            ui.ciano.TextTransparency = transCamada
            ui.magenta.TextTransparency = transCamada

            -- extras por emocao: euforia pula, dor balanca devagar
            local dy = 0
            if e.pulo then dy = -math.abs(math.sin(t * 9)) * 3 end
            if emo == "dor" then dy = math.sin(t * 3) * 1.5 end
            ui.raiz.Position = UDim2.new(0.08, 0, LEGENDA_POS_Y, dy)

            RunService.RenderStepped:Wait()
        end
        if fala.token == meuToken then
            ui.raiz.Visible = false
            fala.prio = 0
            fala.fim = 0
        end
    end)
end

local function Falar(evento, forcar)
    if not FALAS_ATIVAS then return end
    if falaPsicoseAtiva() then return end   -- a Cyberpsychosis tem a propria legenda
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

-- Chamada por Dash/Kiroshi/Optical/Dodge DEPOIS de gastar a energia.
-- Soma psicose (mais com spam), cobra energia extra com a barra alta e rola a chance de glitch.
-- Retorna true se a habilidade deu glitch (quem chamou deve abortar a habilidade).
function PsyBar.Use(key: string): boolean
    local cfg = PsyBar.ABILITY[key]
    if not cfg then return false end
    local uses = PsyBar.RecentUses()
    local frac = math.clamp(State.Psychosis / PsyBar.MAX, 0, 1)

    -- surcharge: com a barra alta, a habilidade drena energia extra
    if cfg.surcharge > 0 then
        State.Energy = math.max(0, State.Energy - cfg.surcharge * frac)
    end

    local failed = math.random() < PsyBar.FailChance(key)
    table.insert(PsyBar.Recent, os.clock())

    local gain = cfg.gain * (1 + PsyBar.SPAM_GAIN_STEP * math.min(uses, 5))
    if failed then gain *= 1.5 end
    PsyBar.Add(gain)

    if failed then
        local upper = string.upper(key)
        local cd = (Constants.COOLDOWNS[upper] or 3) + cfg.extraCd
        State.Cooldowns[upper] = os.clock() + cd
        State.NoRegenUntil = os.clock() + Constants.REGEN_DELAY_USE
        PlaySFX({id = Sounds.SANDI_FAILURE.id, volume = 1.5, pitch = 1.35, looped = false})
        ScreenFade(0.12, 0, 0.4, Color3.fromRGB(255, 20, 20), 0.5, 0.3)
        ShowCooldownText(cfg.label, cd, Color3.fromRGB(255, 30, 30))
        return true
    end
    return false
end

local function TriggerSandevistanFailure()
    PsyBar.Add(PsyBar.GAIN_FAILURE)
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
    if math.random() < (PsyBar.DIRECT_FAIL_BASE + PsyBar.DIRECT_FAIL_SCALE * (State.Psychosis / PsyBar.MAX)) then 
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

local PsiModule
local PsiCtx = {
        Player = Player,
        Constants = Constants,
        Sounds = Sounds,
        State = State,
        Create = Create,
        Falar = Falar,
        PlaySFX = PlaySFX,
        ScreenFade = ScreenFade,
        ScriptSounds = ScriptSounds,
        GetRefs = function() return HRP, Humanoid end,
}
ExecCyberpsychosis = function()
    if PsiModule and PsiModule.Exec then return PsiModule.Exec() end
end
task.spawn(function()
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

-- Recarregar o script limpa a versão anterior
if env.CyberPsychosis and env.CyberPsychosis.Destroy then
    pcall(env.CyberPsychosis.Destroy)
end

local Module = {
    Config = {
        AutoTrigger = true,          -- true = SANDEVISTAN.lua ainda pode disparar sozinho
        Keybind = Enum.KeyCode.P,    -- atalho do botão (nil = sem atalho)
        Cooldown = 3,                -- segundos de espera depois do efeito acabar

        -- Rework: ligue/desligue cada parte (desligue Camera se ficar pesado no celular)
        FX = {
            Camera = true,           -- inclinação + zoom no batimento do coração
            TearBars = true,         -- rasgos horizontais de glitch na tela
            FreezeBody = true,       -- boneco 100% imóvel durante toda a ciberpsicose (ancora + congela animação)
            BodyAnim = true,
            BodyAnimIntensity = 1,
            BodyTimeline = true,     -- animação roteirizada do David sincronizada com a fala (false = poses aleatórias antigas)
            ViewportGlitch = true,   -- glitch do boneco em ViewportFrame (fatias deslocadas + RGB split). Precisa de FreezeBody
            ColorSplit = true,       -- camadas ciano (esquerda) e roxa (direita) sobre o boneco
            SplitPixels = 1,         -- deslocamento base das camadas em PIXELS (nos estouros do glitch aumenta sozinho)
            GlitchSlices = 4,        -- nº de fatias horizontais deslocadas (menos = mais leve no celular; 0 = sem fatias)
            GlitchIntensity = 1,     -- 1 = normal | 2 = deslocamentos dobrados
            PartGlitch = true,       -- glitch POR PEÇA (cabeça, braços, pernas, torso e cada acessório) no método PhaseShift. Precisa de ViewportGlitch
            PartGlitchRate = 1,      -- frequência dos glitches por peça (2 = o dobro, 0.5 = metade)
            PartTint = true,         -- a peça pisca em neon (ciano/magenta/vermelho/branco) durante o glitch
            HideOriginal = true,     -- esconde a peça REAL enquanto a cópia glitchada dela se desloca (LocalTransparencyModifier)
        },

        -- Janelas de erro que orbitam o boneco
        Windows = {
            Style = "DAVID",         -- "DAVID" = HUD estilo Edgerunners | "ORIGINAL" = janela antiga
            LifeMult = 1.6,          -- multiplica o tempo de vida da janela (1 = igual ao original)
            MaxAlive = 16,           -- máximo de janelas ao mesmo tempo (baixe no celular)
            FaceCamera = false,      -- true = janelas sempre viradas pra câmera (segue a câmera) | false = ficam no espaço ao redor do boneco
            FollowCharacter = true,  -- o anel de janelas acompanha o boneco quando ele anda
            OrbitSpeed = 0.3,        -- velocidade da órbita em rad/s (0 = janelas paradas no ar)
            Japanese = true,         -- textos em japonês (se aparecer quadradinho no seu executor, ponha false)
        },

        -- Opcional: som de batimento cardíaco em loop. Ex.:
        -- HeartbeatSound = {id = "rbxassetid://SEU_ID", volume = 1.5, pitch = 1}
        HeartbeatSound = nil,

        -- ====================================================
        -- FALA SINCRONIZADA (efeitos seguem as falas, tipo a cena do David)
        -- Enabled = true: a duração do efeito vira a duração da fala, a legenda
        -- aparece com glitch e cada linha dispara um estouro de glitch + janelas.
        -- Tempos (t) em segundos desde o início do efeito. Ajuste Offset se o
        -- áudio atrasar/adiantar em relação aos efeitos.
        -- ====================================================
        Speech = {
            Enabled = true,
            SoundId = nil,              -- sons em sequência (1→2→3) no Exec; não usa SoundId único
            Volume = 2,
            Offset = 0,                 -- soma em todos os tempos (use negativo se os efeitos estão atrasados)
            Duration = 12,              -- 5s + 4s + 2s + 1s fade = 12s
            Tail = 1.0,                 -- 1s de desligamento suave no final
            Subtitles = true,
            MuteOriginalSounds = true,  -- sons originais substituídos pela sequência com crossfade
            Lines = {
                -- Part 1 (0–5s): "I'm gonna rip out his spine! / I'll kill him! / I'll kill him."
                -- Part 2 (5–9s): "You're dead. / Dead. / Dead."
                -- Part 3 (9–11s): "Fucking dead!" + 1s fade-out
                {t = 0.15, hold = 1.8, who = "DAVID", text = "I'm gonna rip out his spine!", power = 1.5, windows = 5},
                {t = 2.20, hold = 1.0, who = "DAVID", text = "I'll kill him!",               power = 1.6, windows = 4},
                {t = 3.40, hold = 1.3, who = "DAVID", text = "I'll kill him.",               power = 0.9, windows = 2},
                {t = 5.15, hold = 1.0, who = "DAVID", text = "You're dead.",                 power = 1.3, windows = 4},
                {t = 6.40, hold = 0.8, who = "DAVID", text = "Dead.",                        power = 1.7, windows = 6},
                {t = 7.40, hold = 1.0, who = "DAVID", text = "Dead.",                        power = 1.8, windows = 8, final = true},
                {t = 9.15, hold = 1.6, who = "DAVID", text = "Fucking dead!",                power = 2,   windows = 16, chance = 0.1},
            },
            Hits = {
                {t = 1.20, power = 1.9, windows = 2},   -- "spine!" gritado
                {t = 7.70, power = 1.8, windows = 2},   -- segundo "Dead."
                {t = 9.40, power = 2,   windows = 4, chance = 0.1},   -- "Fucking dead!" (10%)
            },
        },
    },
}

-- ============================================================
-- DEPENDÊNCIAS (as mesmas variáveis que o código original usava)
-- ============================================================
local Camera = Workspace.CurrentCamera
local HRP, Humanoid
local Constants, Sounds, State, Create, PlaySFX, ScreenFade

local Fallback = {
    Constants = {
        MAX_ENERGY = 100,
        CYBERPSYCHOSIS = {
            Duration = 12,
            PopupRate = 0.08,
            Radius = 7,
            ShakeIntensity = 0.6,
            WindowLifeTime = 0.5,
        },
        ERROR_TEXTS = {
            "SYSTEM FAILURE", "CRITICAL ERROR", "NEURAL OVERLOAD",
            "CONNECTION LOST", "0xFF0029A CORRUPT", "PSYCHOSIS DETECTED",
            "FATAL EXCEPTION", "REBOOTING...", "NO SIGNAL",
        },
    },
    Sounds = {
        PSYCHOSIS  = {id = "rbxassetid://113922641197855",  volume = 2, pitch = 1, looped = false},
        PSYCHOSIS2 = {id = "rbxassetid://89548438635345", volume = 2, pitch = 1, looped = false},
        PSYCHOSIS3 = {id = "rbxassetid://92219907157626", volume = 2.2, pitch = 1, looped = false},
    },
    State = {Energy = 100},
}

local function FallbackCreate(className, properties)
    local instance = Instance.new(className)
    for prop, value in properties do instance[prop] = value end
    return instance
end

local function FallbackPlaySFX(soundConfig)
    local sound = FallbackCreate("Sound", {SoundId = soundConfig.id, Volume = soundConfig.volume or 1, PlaybackSpeed = soundConfig.pitch or 1, Parent = HRP or Camera})
    sound:Play()
    Debris:AddItem(sound, 10)
    return sound
end

local function FallbackScreenFade(durationIn, hold, durationOut, tint, sat, cont)
    local cc = FallbackCreate("ColorCorrectionEffect", {Name = "CyberFade", TintColor = Color3.new(1,1,1), Saturation = 0, Contrast = 0, Parent = Lighting})
    TweenService:Create(cc, TweenInfo.new(durationIn, Enum.EasingStyle.Quad), {TintColor = tint, Saturation = sat or 0.6, Contrast = cont or 0.25}):Play()
    task.delay(durationIn + hold, function()
        TweenService:Create(cc, TweenInfo.new(durationOut, Enum.EasingStyle.Quad), {TintColor = Color3.new(1,1,1), Saturation = 0, Contrast = 0}):Play()
        task.delay(durationOut + 0.1, function() cc:Destroy() end)
    end)
end

local function Sync()
    local c = PsiCtx
    Camera = Workspace.CurrentCamera
    if c then
        Constants   = c.Constants   or Fallback.Constants
        Sounds      = c.Sounds      or Fallback.Sounds
        State       = c.State       or Fallback.State
        Create      = c.Create      or FallbackCreate
        PlaySFX     = c.PlaySFX     or FallbackPlaySFX
        ScreenFade  = c.ScreenFade  or FallbackScreenFade
        if c.GetRefs then
            HRP, Humanoid = c.GetRefs()
            return
        end
    else
        Constants, Sounds, State = Fallback.Constants, Fallback.Sounds, Fallback.State
        Create, PlaySFX, ScreenFade = FallbackCreate, FallbackPlaySFX, FallbackScreenFade
    end
    local char = Player.Character
    HRP = char and char:FindFirstChild("HumanoidRootPart")
    Humanoid = char and char:FindFirstChildOfClass("Humanoid")
end

Sync()
local syncConn = RunService.Heartbeat:Connect(Sync)

local ExecCyberpsychosis

-- ============================================================
-- ======================  CÓDIGO ORIGINAL  ===================
-- ===== (cópia exata: createLightingEffects, spawnPopup, ======
-- =====  shakeCamera, SystemRestorePopup)                 ======
-- ============================================================

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

local function spawnPopupOriginal()
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

-- ============================================================
-- REWORK DAS JANELAS: HUD do Sandevistan (David Martinez / Edgerunners)
-- 6 modelos: ALERT (losango de aviso), BIOMONITOR (batimento/EKG), CORE DUMP (hex),
-- SYS STATUS (barras), FATAL EXCEPTION (diálogo) e KANJI (警告 com separação RGB).
-- Todas ligam como tela de CRT (linha -> abre), tremem, rasgam e desligam colapsando.
-- Canvas de tamanho FIXO: o conteúdo estica junto com a peça durante a animação.
-- ============================================================
local WIN = {
    RED = Color3.fromRGB(255, 25, 60), DARK = Color3.fromRGB(12, 0, 3), HOT = Color3.fromRGB(255, 110, 125),
    YELLOW = Color3.fromRGB(255, 214, 0), WHITE = Color3.new(1, 1, 1), BLACK = Color3.new(0, 0, 0),
    CYAN = Color3.fromRGB(0, 240, 255), MAGENTA = Color3.fromRGB(255, 0, 140),
}
local winAlive = 0
local CUT = 8 -- tamanho (px) do corte das pontas das janelas

-- desenha o corpo da janela com as 4 pontas cortadas em 45 graus (preenchimento + borda)
-- devolve setFill(cor) e setBorder(cor)
local function wshape(shell, Rw, Rh)
    local c, th = CUT, 2
    local fills, borders = {}, {}
    local layer = Instance.new("Frame")
    layer.Name = "Shape"
    layer.Size = UDim2.new(1, 0, 1, 0)
    layer.BackgroundTransparency = 1
    layer.BorderSizePixel = 0
    layer.ZIndex = 0
    layer.Parent = shell
    local function fill(x, y, w, h)
        table.insert(fills, Instance.new("Frame"))
        local f = fills[#fills]
        f.Position = UDim2.new(0, x, 0, y)
        f.Size = UDim2.new(0, w, 0, h)
        f.BackgroundColor3 = WIN.DARK
        f.BorderSizePixel = 0
        f.Parent = layer
    end
    local function border(x, y, w, h, rot)
        local f = Instance.new("Frame")
        f.BackgroundColor3 = WIN.RED
        f.BorderSizePixel = 0
        if rot then
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.Position = UDim2.new(0, x, 0, y)
            f.Rotation = rot
        else
            f.Position = UDim2.new(0, x, 0, y)
        end
        f.Size = UDim2.new(0, w, 0, h)
        f.Parent = layer
        table.insert(borders, f)
    end
    fill(0, c, Rw, Rh - 2 * c)
    for i = 0, c - 1 do
        fill(c - i, i, Rw - 2 * (c - i), 1)
        fill(c - i, Rh - 1 - i, Rw - 2 * (c - i), 1)
    end
    border(c, 0, Rw - 2 * c, th)
    border(c, Rh - th, Rw - 2 * c, th)
    border(0, c, th, Rh - 2 * c)
    border(Rw - th, c, th, Rh - 2 * c)
    local L, d = c * 1.4142 + th, th * 0.35
    border(c / 2 + d, c / 2 + d, L, th, -45)
    border(Rw - c / 2 - d, c / 2 + d, L, th, 45)
    border(c / 2 + d, Rh - c / 2 - d, L, th, 45)
    border(Rw - c / 2 - d, Rh - c / 2 - d, L, th, -45)
    return function(col) for _, f in ipairs(fills) do f.BackgroundColor3 = col end end,
           function(col) for _, f in ipairs(borders) do f.BackgroundColor3 = col end end
end

local function wnew(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end

local function wlabel(parent, props)
    props.BackgroundTransparency = 1
    props.Font = props.Font or Enum.Font.Code
    props.TextSize = props.TextSize or 12
    props.TextColor3 = props.TextColor3 or WIN.WHITE
    return wnew("TextLabel", props, parent)
end

local function hex4() return string.format("%04X", math.random(0, 0xFFFF)) end

-- faixa de listras diagonais (aviso de perigo)
local function whazard(parent, y, h, colorA)
    local f = wnew("Frame", {Size = UDim2.new(1, -2 * CUT, 0, h), Position = UDim2.new(0, CUT, 0, y), BackgroundColor3 = colorA, BorderSizePixel = 0}, parent)
    local kps = {}
    for i = 0, 4 do
        local a = i * 0.2
        table.insert(kps, ColorSequenceKeypoint.new(a, colorA))
        table.insert(kps, ColorSequenceKeypoint.new(a + 0.0999, colorA))
        table.insert(kps, ColorSequenceKeypoint.new(a + 0.1, WIN.BLACK))
        table.insert(kps, ColorSequenceKeypoint.new(i == 4 and 1 or a + 0.1999, WIN.BLACK))
    end
    wnew("UIGradient", {Color = ColorSequence.new(kps), Rotation = 45}, f)
    return f
end

local function wtitle(root, text, withX)
    local bar = wnew("Frame", {Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, BorderSizePixel = 0}, root)
    wnew("Frame", {Size = UDim2.new(1, 0, 0, 20 - CUT), Position = UDim2.new(0, 0, 0, CUT), BackgroundColor3 = WIN.RED, BorderSizePixel = 0}, bar)
    for i = 0, CUT - 1 do
        wnew("Frame", {Size = UDim2.new(1, -2 * (CUT - i), 0, 1), Position = UDim2.new(0, CUT - i, 0, i), BackgroundColor3 = WIN.RED, BorderSizePixel = 0}, bar)
    end
    wlabel(bar, {Size = UDim2.new(1, -28, 1, 0), Position = UDim2.new(0, 6, 0, 0), Text = text, TextColor3 = WIN.BLACK, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left})
    if withX ~= false then
        wlabel(bar, {Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -22, 0, 0), Text = "X", TextColor3 = WIN.BLACK, Font = Enum.Font.GothamBold, TextSize = 12})
    end
    return bar
end

local WIN_SIZE = {
    ALERT = {240, 170}, BIO = {240, 150}, HEX = {240, 170},
    GAUGE = {230, 160}, DIALOG = {220, 130}, KANJI = {250, 120},
}
local WIN_KINDS = {{"ALERT", 22}, {"BIO", 18}, {"HEX", 18}, {"GAUGE", 16}, {"DIALOG", 14}, {"KANJI", 12}}

local function pickWinKind()
    local total = 0
    for _, e in ipairs(WIN_KINDS) do total += e[2] end
    local r = math.random() * total
    for _, e in ipairs(WIN_KINDS) do
        r -= e[2]
        if r <= 0 then return e[1] end
    end
    return "ALERT"
end

-- cada builder devolve uma função tick(t, life) chamada a ~20x por segundo
local WIN_BUILD = {}

WIN_BUILD.ALERT = function(root, W, H)
    wtitle(root, "ALERT_" .. hex4())
    local dia = wnew("Frame", {Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(0, 24, 0, 54), BackgroundTransparency = 1, Rotation = 45}, root)
    local diaStroke = wnew("UIStroke", {Color = WIN.RED, Thickness = 4}, dia)
    wlabel(root, {Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(0, 24, 0, 54), Text = "!", Font = Enum.Font.SciFi, TextSize = 40, TextColor3 = WIN.RED})
    local warn = wlabel(root, {Size = UDim2.new(0, 132, 0, 34), Position = UDim2.new(0, 98, 0, 50), Text = "WARNING", Font = Enum.Font.SciFi, TextSize = 26, TextColor3 = WIN.RED, TextXAlignment = Enum.TextXAlignment.Left})
    wlabel(root, {Size = UDim2.new(0, 132, 0, 30), Position = UDim2.new(0, 98, 0, 88), Text = "NEURAL INTEGRITY\n0x" .. hex4() .. " CRITICAL", TextSize = 11, TextColor3 = WIN.HOT, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top})
    local psy = wlabel(root, {Size = UDim2.new(1, -20, 0, 16), Position = UDim2.new(0, 10, 1, -40), Text = "PSYCHOSIS DETECTED", TextSize = 12})
    whazard(root, H - 16, 12, WIN.RED)
    return function(t)
        local on = math.floor(t * 10) % 2 == 0
        warn.TextColor3 = on and WIN.RED or WIN.WHITE
        psy.TextTransparency = on and 0 or 0.6
        diaStroke.Color = math.random() < 0.2 and WIN.WHITE or WIN.RED
    end
end

WIN_BUILD.BIO = function(root, W, H)
    wtitle(root, "BIOMONITOR_" .. hex4())
    local N, mid = 28, 62
    local bars, buf = {}, {}
    for i = 1, N do
        buf[i] = 0
        bars[i] = wnew("Frame", {Size = UDim2.new(0, 6, 0, 2), Position = UDim2.new(0, 8 + (i - 1) * 8, 0, mid), BackgroundColor3 = WIN.RED, BorderSizePixel = 0}, root)
    end
    wnew("Frame", {Size = UDim2.new(1, -16, 0, 1), Position = UDim2.new(0, 8, 0, mid), BackgroundColor3 = WIN.DARK, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 0}, root)
    local bpm = wlabel(root, {Size = UDim2.new(0, 130, 0, 30), Position = UDim2.new(0, 8, 1, -42), Text = "187 BPM", Font = Enum.Font.SciFi, TextSize = 24, TextColor3 = WIN.RED, TextXAlignment = Enum.TextXAlignment.Left})
    local arr = wlabel(root, {Size = UDim2.new(0, 90, 0, 14), Position = UDim2.new(1, -98, 1, -30), Text = "ARRHYTHMIA", TextSize = 11, TextColor3 = WIN.HOT, TextXAlignment = Enum.TextXAlignment.Right})
    local pattern = {0, 0, 0.08, 0.16, 0.08, 0, -0.12, 1, -0.55, 0.05, 0, 0, 0.18, 0.3, 0.18, 0, 0, 0, 0}
    local pi = 0
    return function(t)
        for _ = 1, 2 do
            table.remove(buf, 1)
            pi = pi % #pattern + 1
            local v = pattern[pi]
            if math.random() < 0.15 then v += (math.random() - 0.5) * 0.7 end
            table.insert(buf, v)
        end
        for i = 1, N do
            local v = buf[i]
            local hpx = math.max(2, math.floor(math.abs(v) * 34))
            local b = bars[i]
            b.Size = UDim2.new(0, 6, 0, hpx)
            b.Position = UDim2.new(0, 8 + (i - 1) * 8, 0, v >= 0 and mid - hpx or mid)
            b.BackgroundColor3 = (i > N - 3) and WIN.WHITE or WIN.RED
        end
        bpm.Text = math.random(150, 245) .. " BPM"
        arr.TextTransparency = (math.floor(t * 8) % 2 == 0) and 0 or 0.7
    end
end

WIN_BUILD.HEX = function(root, W, H)
    wtitle(root, "CORE_DUMP_" .. hex4())
    local body = wlabel(root, {Size = UDim2.new(1, -16, 0, 96), Position = UDim2.new(0, 8, 0, 26), Text = "", TextSize = 11, TextColor3 = WIN.HOT, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top})
    local lbl = wlabel(root, {Size = UDim2.new(1, -16, 0, 14), Position = UDim2.new(0, 8, 0, 126), Text = "OVERWRITE 0%", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left})
    local bg = wnew("Frame", {Size = UDim2.new(1, -16, 0, 8), Position = UDim2.new(0, 8, 0, 144), BackgroundColor3 = WIN.DARK, BorderSizePixel = 0}, root)
    wnew("UIStroke", {Color = WIN.RED, Thickness = 1}, bg)
    local fill = wnew("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = WIN.RED, BorderSizePixel = 0}, bg)
    return function(t, life)
        local lines = {}
        for i = 1, 7 do
            lines[i] = string.format("%s  %s %s %s %s", hex4(), hex4(), hex4(), hex4(), hex4())
        end
        lines[math.random(1, 7)] = "FFFF  ERR  ERR  ERR  ERR"
        body.Text = table.concat(lines, "\n")
        local a = math.clamp(t / life, 0, 1)
        fill.Size = UDim2.new(a, 0, 1, 0)
        lbl.Text = "OVERWRITE " .. math.floor(a * 100) .. "%"
    end
end

WIN_BUILD.GAUGE = function(root, W, H)
    wtitle(root, "SYS_STATUS_" .. hex4())
    local rows = {
        {"NEURAL LOAD", 88}, {"CHROME REJECTION", 94}, {"SANDEVISTAN OC", 76}, {"HUMANITY", 18},
    }
    local fills, pcts = {}, {}
    for i, r in ipairs(rows) do
        local y = 28 + (i - 1) * 32
        wlabel(root, {Size = UDim2.new(1, -16, 0, 12), Position = UDim2.new(0, 8, 0, y), Text = r[1], TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left})
        local bg = wnew("Frame", {Size = UDim2.new(1, -62, 0, 8), Position = UDim2.new(0, 8, 0, y + 16), BackgroundColor3 = WIN.DARK, BorderSizePixel = 0}, root)
        wnew("UIStroke", {Color = WIN.RED, Thickness = 1}, bg)
        fills[i] = wnew("Frame", {Size = UDim2.new(r[2] / 100, 0, 1, 0), BackgroundColor3 = (i == 4) and WIN.WHITE or WIN.RED, BorderSizePixel = 0}, bg)
        pcts[i] = wlabel(root, {Size = UDim2.new(0, 44, 0, 12), Position = UDim2.new(1, -50, 0, y + 14), Text = r[2] .. "%", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right})
    end
    return function(t, life)
        for i, r in ipairs(rows) do
            local v = r[2] + (math.random() - 0.5) * 14
            if i == 4 then v = r[2] * (1 - t / life) + (math.random() - 0.5) * 6 end
            v = math.clamp(v, 0, 100)
            fills[i].Size = UDim2.new(v / 100, 0, 1, 0)
            pcts[i].Text = math.floor(v) .. "%"
        end
    end
end

WIN_BUILD.DIALOG = function(root, W, H)
    wtitle(root, "FATAL_EXCEPTION")
    local texts = Constants.ERROR_TEXTS
    wlabel(root, {Size = UDim2.new(1, -20, 0, 40), Position = UDim2.new(0, 10, 0, 28), Text = texts[math.random(1, #texts)], Font = Enum.Font.SciFi, TextSize = 18, TextColor3 = WIN.RED, TextWrapped = true})
    wlabel(root, {Size = UDim2.new(1, -20, 0, 14), Position = UDim2.new(0, 10, 0, 72), Text = "0x" .. hex4() .. "_NEURAL_CRITICAL", TextSize = 10, TextColor3 = WIN.HOT})
    local btns = {}
    for i, name in ipairs({"RETRY", "ABORT"}) do
        local b = wnew("Frame", {Size = UDim2.new(0, 80, 0, 22), Position = UDim2.new(0, 22 + (i - 1) * 100, 1, -32), BackgroundColor3 = WIN.RED, BackgroundTransparency = 0.7, BorderSizePixel = 0}, root)
        wnew("UIStroke", {Color = WIN.RED, Thickness = 1}, b)
        wlabel(b, {Size = UDim2.new(1, 0, 1, 0), Text = name, TextSize = 12})
        btns[i] = b
    end
    return function(t)
        local hot = math.random(1, 2)
        btns[hot].BackgroundTransparency = 0.1
        btns[3 - hot].BackgroundTransparency = 0.7
    end
end

WIN_BUILD.KANJI = function(root, W, H)
    local jp = Module.Config.Windows.Japanese ~= false
    whazard(root, 0, 8, WIN.YELLOW)
    whazard(root, H - 8, 8, WIN.YELLOW)
    local function big(color, x)
        return wlabel(root, {Size = UDim2.new(1, 0, 0, 66), Position = UDim2.new(0, x, 0, 12), Text = jp and "警告" or "ERROR", Font = Enum.Font.GothamBlack, TextSize = jp and 58 or 44, TextColor3 = color})
    end
    local c, m = big(WIN.CYAN, -3), big(WIN.MAGENTA, 3)
    local main = big(WIN.RED, 0)
    wlabel(root, {Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 80), Text = jp and "サイバーサイコシス" or "SYSTEM OVERLOAD", Font = jp and Enum.Font.GothamBold or Enum.Font.Code, TextSize = 14})
    wlabel(root, {Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 0, 98), Text = "// CYBERPSYCHOSIS //", TextSize = 10, TextColor3 = WIN.RED})
    return function(t)
        local j = math.random(2, 7)
        c.Position = UDim2.new(0, -j, 0, 12 + math.random(-2, 2))
        m.Position = UDim2.new(0, j, 0, 12 + math.random(-2, 2))
        main.TextTransparency = (math.random() < 0.15) and 0.6 or 0
    end
end

local function spawnPopupDavid()
    if not HRP then return end
    local WC = Module.Config.Windows
    if winAlive >= (WC.MaxAlive or 16) then return end

    -- posição: ao redor do BONECO (não da câmera). Cada janela orbita devagar,
    -- flutua e nasce "saindo" do boneco. Só gira pra mostrar a frente pra câmera.
    local cam = Workspace.CurrentCamera
    local ang0 = math.random() * math.pi * 2
    local angV = (math.random() - 0.5) * 1.1
    local radius = 5.5 + math.random() * 2.5
    local height = -1 + math.random() * 4
    local orbitSpeed = (math.random() < 0.5 and -1 or 1) * (WC.OrbitSpeed or 0.3) * (0.5 + math.random())
    local bobPhase = math.random() * math.pi * 2
    local tilt = CFrame.Angles(math.rad(math.random(-8, 8)), math.rad(math.random(-12, 12)), math.rad(math.random(-6, 6)))
    local center = HRP.Position
    local born = os.clock()

    local kind = pickWinKind()
    local W, H = WIN_SIZE[kind][1], WIN_SIZE[kind][2]
    local sc = 0.85 + math.random() * 0.4
    local fw, fh = W / 52 * sc, H / 52 * sc

    local part = Instance.new("Part")
    part.Name = "GlitchWindow"
    part.Size = Vector3.new(0.05, 0.04, 0.07)
    part.Color = Color3.fromRGB(9, 0, 2)
    part.Material = Enum.Material.Neon
    part.Transparency = 1 -- invisível: o formato (pontas cortadas) é desenhado pela UI
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Anchored = true
    part.CastShadow = false

    -- atualiza posição/rotação a cada frame (órbita + flutuação + saída do boneco)
    local function place(dt, first)
        local t = os.clock() - born
        if WC.FollowCharacter ~= false and HRP then
            center = center:Lerp(HRP.Position, first and 1 or (1 - math.exp(-8 * dt)))
        end
        local g = math.min(t / 0.35, 1)
        local r = radius * (0.3 + 0.7 * (1 - (1 - g) ^ 3)) -- voa do boneco até a órbita
        local a = ang0 + orbitSpeed * t
        local bob = math.sin(t * 1.6 + bobPhase) * 0.25
        local off = Vector3.new(
            math.cos(a) * math.cos(angV) * r,
            math.sin(angV) * r + height + bob,
            math.sin(a) * math.cos(angV) * r)
        local pos = center + off

        local cf
        local camPos = cam and cam.CFrame.Position
        if WC.FaceCamera == true and camPos then
            cf = CFrame.lookAt(pos, camPos)
        else
            -- orientação presa ao boneco: frente da janela aponta pra fora do anel.
            -- Não depende da câmera (o verso também tem a UI, então vê de qualquer lado).
            cf = CFrame.lookAt(pos, pos + Vector3.new(off.X, 0, off.Z))
        end
        part.CFrame = cf * tilt
    end
    place(0, true)

    -- duas faces (frente e verso) pra a janela aparecer de qualquer lado sem precisar virar
    local faces = {}
    for _, nf in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
        local sgui = Instance.new("SurfaceGui")
        sgui.Face = nf
        sgui.LightInfluence = 0
        sgui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
        sgui.CanvasSize = Vector2.new(W, H)
        sgui.Parent = part

        local root = wnew("Frame", {Size = UDim2.new(1, -4, 1, -4), Position = UDim2.new(0, 2, 0, 2), BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true}, sgui)
        local setFill, setBorder = wshape(root, W - 4, H - 4)
        local okB, tickFn = pcall(WIN_BUILD[kind], root, W, H)
        if not okB then part:Destroy() return end
        local tear = wnew("Frame", {Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = WIN.WHITE, BackgroundTransparency = 0.55, BorderSizePixel = 0, Visible = false, ZIndex = 50}, root)
        table.insert(faces, {root = root, setFill = setFill, setBorder = setBorder, tear = tear, tick = tickFn})
    end

    part.Parent = Workspace
    winAlive += 1

    local moveConn
    moveConn = RunService.RenderStepped:Connect(function(dt)
        if not part.Parent then moveConn:Disconnect() return end
        cam = Workspace.CurrentCamera
        place(dt, false)
    end)

    -- liga como CRT: linha -> abre
    TweenService:Create(part, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(fw, 0.04, 0.07)}):Play()
    task.delay(0.05, function()
        if part.Parent then
            TweenService:Create(part, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = Vector3.new(fw, fh, 0.07)}):Play()
        end
    end)

    local life = Constants.CYBERPSYCHOSIS.WindowLifeTime * (WC.LifeMult or 1.6) * (0.8 + math.random() * 0.6)
    task.spawn(function()
        while part.Parent do
            local t = os.clock() - born
            if t >= life then break end
            local shake = math.random() < 0.2
            local sx, sy, sc = math.random(-6, 6), math.random(-3, 3), math.random() < 0.5
            local tearOn = math.random() < 0.25
            local tearH = math.random(2, 10)
            local tearY = (CUT + math.random() * math.max(1, H - 4 - 2 * CUT - tearH)) / (H - 4)
            for _, f in ipairs(faces) do
                if shake then
                    f.root.Position = UDim2.new(0, 2 + sx, 0, 2 + sy)
                    f.setBorder(sc and WIN.WHITE or WIN.RED)
                else
                    f.root.Position = UDim2.new(0, 2, 0, 2)
                    f.setBorder(WIN.RED)
                end
                f.tear.Visible = tearOn
                if tearOn then
                    f.tear.Position = UDim2.new(0, 0, tearY, 0)
                    f.tear.Size = UDim2.new(1, 0, 0, tearH)
                end
                if f.tick then pcall(f.tick, t, life) end
            end
            task.wait(0.05)
        end
        if part.Parent then
            -- glitch final e desliga colapsando (CRT off)
            for i = 1, 3 do
                for _, f in ipairs(faces) do
                    f.setFill((i % 2 == 0) and WIN.DARK or WIN.RED)
                end
                task.wait(0.025)
            end
            TweenService:Create(part, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = Vector3.new(fw, 0.04, 0.07)}):Play()
            task.wait(0.1)
            TweenService:Create(part, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = Vector3.new(0.02, 0.04, 0.07)}):Play()
            task.wait(0.08)
        end
        winAlive = math.max(0, winAlive - 1)
        moveConn:Disconnect()
        part:Destroy()
    end)
end

local function spawnPopup()
    if Module.Config.Windows.Style == "ORIGINAL" then
        return spawnPopupOriginal()
    end
    return spawnPopupDavid()
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



-- ============================================================
-- ==============  REWORK: estilo David Martinez  =============
-- Mantém a mecânica do original (paralisia -> drenagem de vida -> overdrive
-- na fase 3 -> 30% de chance do SYSTEM RESTORE) e a coreografia de janelas
-- sincronizada com o áudio. Por cima adiciona: visão de túnel vermelha
-- pulsando no ritmo do coração, alerta WARNING, título com separação RGB,
-- rasgos de tela, scanlines, terminal de falhas, contador de HUMANITY,
-- câmera inclinando/zoom no batimento, boneco imóvel e GLITCH EM VIEWPORTFRAME
-- (clones 2D do boneco: camadas ciano/roxa + fatias horizontais deslocadas).
-- ============================================================
local function SpeechActive()
    local S = Module.Config.Speech
    return S and S.Enabled and S.Lines and #S.Lines > 0
end

-- duração total do efeito: a da fala (se ligada) ou a original
local function EffectiveDuration()
    if SpeechActive() then
        local S = Module.Config.Speech
        if S.Duration then return S.Duration end
        local last = 0
        for _, l in ipairs(S.Lines) do
            last = math.max(last, (l.t or 0) + (l.hold or 1.5))
        end
        return last + (S.Offset or 0) + (S.Tail or 1.2)
    end
    return Constants.CYBERPSYCHOSIS.Duration
end

local SPEAKER_COLORS = {
    FARADAY = Color3.fromRGB(255, 200, 60),
    DAVID = Color3.fromRGB(0, 240, 255),
    REBECCA = Color3.fromRGB(255, 0, 140),
    LUCY = Color3.fromRGB(190, 120, 255),
}
local SCRAMBLE_CHARS = {"#", "@", "%", "&", "?", "!", "/", "|", "0", "1", "<", ">", "X"}

local function ScrambleText(text, amount)
    local out = {}
    for _, cp in utf8.codes(text) do
        if cp ~= 32 and math.random() < amount then
            table.insert(out, SCRAMBLE_CHARS[math.random(1, #SCRAMBLE_CHARS)])
        else
            table.insert(out, utf8.char(cp))
        end
    end
    return table.concat(out)
end

function ExecCyberpsychosis()
    Sync()
    local FX = Module.Config.FX
    local CFG = Constants.CYBERPSYCHOSIS
    local DURATION = EffectiveDuration()
    local phaseDuration = DURATION / 3
    local S = Module.Config.Speech
    local speechOn = SpeechActive() and true or false
    -- "Fucking dead!" (fala + som 3) só em 10% das vezes
    local playFuckingDead = math.random() < 0.1

    -- Sons de crashing out do David (parte 1: 5s → parte 2: 4s → parte 3: 2s "Fucking dead!") + 1s fade
    local speechSound
    do
        local vol = (S and S.Volume) or 2
        local vol3 = (Sounds.PSYCHOSIS3 and Sounds.PSYCHOSIS3.volume) or 2.2
        local parent = HRP or Camera
        local s1 = Instance.new("Sound")
        s1.SoundId = Sounds.PSYCHOSIS.id
        s1.Volume = vol
        s1.PlaybackSpeed = Sounds.PSYCHOSIS.pitch or 1
        s1.Parent = parent
        s1:Play()
        Debris:AddItem(s1, 7)

        local s2 = Instance.new("Sound")
        s2.SoundId = Sounds.PSYCHOSIS2.id
        s2.Volume = 0
        s2.PlaybackSpeed = Sounds.PSYCHOSIS2.pitch or 1
        s2.Parent = parent

        local playPart3 = playFuckingDead
        local s3 = nil
        if playPart3 then
            s3 = Instance.new("Sound")
            s3.SoundId = (Sounds.PSYCHOSIS3 and Sounds.PSYCHOSIS3.id) or "rbxassetid://92219907157626"
            s3.Volume = 0
            s3.PlaybackSpeed = (Sounds.PSYCHOSIS3 and Sounds.PSYCHOSIS3.pitch) or 1
            s3.Parent = parent
        end

        -- Crossfade 1→2 em ~4.4s
        task.delay(4.4, function()
            if s1 and s1.Parent then
                TweenService:Create(s1, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Volume = 0}):Play()
            end
            if s2 and s2.Parent then
                s2:Play()
                TweenService:Create(s2, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Volume = vol}):Play()
            end
        end)

        if playPart3 and s3 then
            -- Crossfade 2→3 em ~8.7s ("Fucking dead!" 2s)
            task.delay(8.7, function()
                if s2 and s2.Parent then
                    TweenService:Create(s2, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Volume = 0}):Play()
                end
                if s3 and s3.Parent then
                    s3:Play()
                    TweenService:Create(s3, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Volume = vol3}):Play()
                end
            end)
            -- Fade-out final do s3 no último 1s (não corta seco)
            task.delay(10.8, function()
                if s3 and s3.Parent then
                    TweenService:Create(s3, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Volume = 0}):Play()
                end
            end)
            Debris:AddItem(s3, 14)
        else
            -- sem parte 3: fade-out do s2 no final
            task.delay(10.8, function()
                if s2 and s2.Parent then
                    TweenService:Create(s2, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Volume = 0}):Play()
                end
            end)
        end

        Debris:AddItem(s2, 12)
        speechSound = s1
    end

    if speechOn and S.SoundId and S.SoundId ~= "" then
        local extra = Instance.new("Sound")
        extra.SoundId = S.SoundId
        extra.Volume = S.Volume or 2
        extra.Parent = HRP or Camera
        extra:Play()
        Debris:AddItem(extra, DURATION + 3)
    end

    local hbSound
    if Module.Config.HeartbeatSound then
        hbSound = PlaySFX(Module.Config.HeartbeatSound)
        hbSound.Looped = true
    end

    -- Tom ambiente (Creator Store) tocando os 9s inteiros, pitch variando
    local toneSound
    do
        local parent = HRP or Camera
        toneSound = Instance.new("Sound")
        toneSound.Name = "CyberPsychosisTone"
        toneSound.SoundId = "rbxassetid://117921005109261"
        toneSound.Volume = 1.6
        toneSound.Looped = true
        toneSound.PlaybackSpeed = 0.85
        toneSound.Parent = parent
        toneSound:Play()
        Debris:AddItem(toneSound, DURATION + 2)

        -- tonalidades diferentes ao longo dos 9s (grave → agudo → distorcido)
        task.spawn(function()
            local t0 = os.clock()
            while toneSound and toneSound.Parent and (os.clock() - t0) < DURATION do
                local p = math.clamp((os.clock() - t0) / DURATION, 0, 1)
                -- curva: começa grave, sobe, oscila no meio, sobe no final
                local base = 0.75 + p * 0.55
                local wobble = math.sin(os.clock() * (2.2 + p * 4)) * (0.08 + p * 0.18)
                local glitch = (math.random() < 0.12 + p * 0.2) and (math.random() * 0.35 - 0.1) or 0
                toneSound.PlaybackSpeed = math.clamp(base + wobble + glitch, 0.55, 1.85)
                task.wait(0.08)
            end
            if toneSound and toneSound.Parent then
                TweenService:Create(toneSound, TweenInfo.new(0.4), {Volume = 0}):Play()
            end
        end)
    end

    -- coreografia das janelas (ORIGINAL, sincronizada com o áudio)
    -- com Speech ligado, as janelas vêm das falas (veja "events" mais abaixo)
    if not speechOn then task.spawn(function()
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
    end) end

    if Humanoid then Humanoid.WalkSpeed = 0 Humanoid.JumpPower = 0 end
    if Lighting:FindFirstChild("SandiEffect") then Lighting.SandiEffect:Destroy() end
    if Lighting:FindFirstChild("SandiEffect2") then Lighting.SandiEffect2:Destroy() end
    local cc, blur = createLightingEffects()
    local startTime = tick()
    local connection

    local RED = Color3.fromRGB(255, 25, 60)
    local DARKRED = Color3.fromRGB(130, 0, 18)
    local CYAN = Color3.fromRGB(0, 240, 255)
    local MAGENTA = Color3.fromRGB(255, 0, 140)
    local WHITE = Color3.new(1, 1, 1)
    local TEAR_COLORS = {RED, CYAN, MAGENTA, WHITE}

    local sg = Create("ScreenGui", {Name = "CyberPsychosisFX", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 900, Parent = Player.PlayerGui})
    pcall(function() sg.ScreenInsets = Enum.ScreenInsets.None end)   -- tela cheia: ignora notch/bordas do celular

    -- estado dos efeitos (declarado antes das funções que usam)
    local hitKick, beatKick, rollKick = 0, 0, 0
    local camRoll, fovDelta, fovApplied = 0, 0, 0

    -- ---------- visão de túnel (bordas vermelhas que pulsam) ----------
    local edges = {}
    local function makeEdge(pos, size, rot, anchor)
        local f = Create("Frame", {Position = pos, Size = size, AnchorPoint = anchor, BackgroundColor3 = DARKRED, BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 1, Parent = sg})
        Create("UIGradient", {Rotation = rot, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}), Parent = f})
        table.insert(edges, f)
    end
    makeEdge(UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0.3, 0), 90, Vector2.new(0, 0))
    makeEdge(UDim2.new(0, 0, 1, 0), UDim2.new(1, 0, 0.3, 0), -90, Vector2.new(0, 1))
    makeEdge(UDim2.new(0, 0, 0, 0), UDim2.new(0.22, 0, 1, 0), 0, Vector2.new(0, 0))
    makeEdge(UDim2.new(1, 0, 0, 0), UDim2.new(0.22, 0, 1, 0), 180, Vector2.new(1, 0))

    -- ---------- scanlines ----------
    for i = 1, 3 do
        local sl = Create("Frame", {Size = UDim2.new(1, 0, 0, 2 + i), Position = UDim2.new(0, 0, -0.05, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 11, Parent = sg})
        TweenService:Create(sl, TweenInfo.new(1.1 + i * 0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {Position = UDim2.new(0, 0, 1.05, 0)}):Play()
    end

    -- ---------- rasgos horizontais de glitch ----------
    local bars, barIndex = {}, 0
    for i = 1, 6 do
        bars[i] = Create("Frame", {Size = UDim2.new(1, 0, 0, 10), BorderSizePixel = 0, Visible = false, ZIndex = 12, Parent = sg})
    end
    local function Tear(count)
        if not FX.TearBars then return end
        for _ = 1, count do
            barIndex = barIndex % #bars + 1
            local b = bars[barIndex]
            b.Size = UDim2.new(1, 0, 0, math.random(3, 36))
            b.Position = UDim2.new(0, math.random(-40, 40), math.random(), 0)
            b.BackgroundColor3 = TEAR_COLORS[math.random(1, #TEAR_COLORS)]
            b.BackgroundTransparency = math.random(45, 85) / 100
            b.Visible = true
            task.delay(math.random(3, 9) / 100, function() b.Visible = false end)
        end
    end

    -- ---------- flash de tela ----------
    local flash = Create("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 20, Parent = sg})
    local function Flash(color, trans, t)
        flash.BackgroundColor3 = color
        flash.BackgroundTransparency = trans
        TweenService:Create(flash, TweenInfo.new(t or 0.15), {BackgroundTransparency = 1}):Play()
    end

    -- ---------- título com separação RGB ----------
    local function mkTitle(color, z)
        local l = Create("TextLabel", {Size = UDim2.new(1, 0, 0.2, 0), Position = UDim2.new(0, 0, 0.4, 0), BackgroundTransparency = 1, Text = "CYBERPSYCHOSIS", TextColor3 = color, Font = Enum.Font.SciFi, TextScaled = true, TextTransparency = 1, ZIndex = z, Parent = sg})
        Create("UITextSizeConstraint", {MaxTextSize = 80, Parent = l})
        return l
    end
    local titleC = mkTitle(CYAN, 13)
    local titleM = mkTitle(MAGENTA, 13)
    local titleMain = mkTitle(Color3.fromRGB(255, 0, 0), 14)

    -- ---------- faixa de WARNING ----------
    local banner = Create("Frame", {Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, -0.1, 0), BackgroundColor3 = Color3.fromRGB(20, 0, 4), BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 15, Parent = sg})
    Create("UIStroke", {Color = RED, Thickness = 2, Parent = banner})
    local bannerText = Create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "!! WARNING !!   NEURAL INTEGRITY CRITICAL   !! WARNING !!", TextColor3 = RED, Font = Enum.Font.Code, TextSize = 16, ZIndex = 16, Parent = banner})
    TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0.1, 0)}):Play()

    -- ---------- HUMANITY + terminal de falhas ----------
    local humLabel = Create("TextLabel", {Size = UDim2.new(0.6, 0, 0, 26), Position = UDim2.new(0.02, 0, 0.2, 0), BackgroundTransparency = 1, Text = "HUMANITY 100%", TextColor3 = RED, Font = Enum.Font.SciFi, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15, Parent = sg})
    local terminal = Create("TextLabel", {Size = UDim2.new(0.6, 0, 0, 170), Position = UDim2.new(0.02, 0, 0.2, 30), BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(255, 90, 110), Font = Enum.Font.Code, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 15, Parent = sg})
    local logLines = {}
    local function Log(txt)
        table.insert(logLines, txt)
        if #logLines > 9 then table.remove(logLines, 1) end
        terminal.Text = table.concat(logLines, "\n")
    end
    local logSchedule = {
        {0.1, "> BIOMONITOR ........ ERROR"},
        {0.7, "> SANDEVISTAN ....... 187% OVERCLOCK"},
        {1.4, "> NEURAL LINK ....... UNSTABLE"},
        {2.2, "> CHROME REJECTION .. 94%"},
        {3.0, "> MOTOR CONTROL ..... LOST"},
        {3.8, "> SAFETY LIMITERS ... OFFLINE"},
        {4.6, "> HUMANITY .......... CRITICAL"},
        {5.2, "> FLATLINE .......... IMMINENT"},
    }
    for _, e in ipairs(logSchedule) do
        task.delay(e[1] * DURATION / 6, function() if sg.Parent then Log(e[2]) end end)
    end

    -- ---------- LEGENDA GLITCHADA SINCRONIZADA COM A FALA ----------
    local subRoot = Create("Frame", {Size = UDim2.new(0.84, 0, 0, 84), Position = UDim2.new(0.08, 0, 0.78, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 17, Parent = sg})
    local subName = Create("TextLabel", {Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "", TextColor3 = WHITE, Font = Enum.Font.Code, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 19, Parent = subRoot})
    local function mkSub(color, z)
        local l = Create("TextLabel", {Size = UDim2.new(1, 0, 1, -20), Position = UDim2.new(0, 0, 0, 20), BackgroundTransparency = 1, Text = "", TextColor3 = color, Font = Enum.Font.Code, TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = z, Parent = subRoot})
        Create("UITextSizeConstraint", {MaxTextSize = 26, MinTextSize = 10, Parent = l})
        return l
    end
    local subC = mkSub(CYAN, 17)
    local subM = mkSub(MAGENTA, 17)
    local subMain = mkSub(WHITE, 18)
    subC.TextTransparency = 0.35
    subM.TextTransparency = 0.35
    local subText, subHideAt = "", 0
    local function ShowLine(line)
        if S.Subtitles == false or not line.text then return end
        local who = line.who and tostring(line.who):upper() or ""
        subText = tostring(line.text)
        subName.Text = who
        subName.TextColor3 = SPEAKER_COLORS[who] or WHITE
        subMain.Text, subC.Text, subM.Text = subText, subText, subText
        subHideAt = tick() + (line.hold or 1.5)
        subRoot.Visible = true
    end

    -- ---------- ícone da psicose (ORIGINAL) ----------
    local psychoImage = Instance.new("ImageLabel")
    psychoImage.Name = "PsychoImage"
    psychoImage.Size = UDim2.new(0, 200, 0, 200)
    psychoImage.BackgroundTransparency = 1
    psychoImage.Image = "rbxassetid://138778899925146"
    psychoImage.ImageTransparency = 1
    psychoImage.ZIndex = 10
    psychoImage.Position = UDim2.new(1.2, 0, 0, 10)
    psychoImage.Parent = sg
    TweenService:Create(psychoImage, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -220, 0, 10),
        ImageTransparency = 0
    }):Play()
    task.spawn(function()
        task.wait(0.5)
        local piscaStart = tick()
        while psychoImage.Parent and tick() - piscaStart < DURATION - 0.7 do
            TweenService:Create(psychoImage, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                ImageTransparency = math.random(20, 55) / 100
            }):Play()
            task.wait(0.35)
        end
    end)
    task.delay(DURATION - 0.6, function()
        if psychoImage and psychoImage.Parent then
            TweenService:Create(psychoImage, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(1.2, 0, 0, 10),
                ImageTransparency = 1
            }):Play()
        end
    end)

    -- ---------- boneco completamente imóvel ----------
    local frozenHRP
    local frozenTracks = {}
    local function FreezeBody()
        if not FX.FreezeBody then return end
        if HRP and HRP ~= frozenHRP then
            if frozenHRP then frozenHRP.Anchored = false end
            frozenHRP = HRP
            HRP.AssemblyLinearVelocity = Vector3.zero
            HRP.AssemblyAngularVelocity = Vector3.zero
            HRP.Anchored = true
        end
        if Humanoid then
            Humanoid.WalkSpeed = 0
            Humanoid.JumpPower = 0
            local animator = Humanoid:FindFirstChildOfClass("Animator")
            if animator then
                for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
                    if FX.BodyAnim ~= false then
                        frozenTracks[tr] = true
                        tr:Stop(0)
                    elseif tr.Speed ~= 0 then
                        frozenTracks[tr] = true
                        tr:AdjustSpeed(0)
                    end
                end
            end
        end
    end
    local function UnfreezeBody()
        if frozenHRP then
            pcall(function()
                frozenHRP.Anchored = false
                frozenHRP.AssemblyLinearVelocity = Vector3.zero
                frozenHRP.AssemblyAngularVelocity = Vector3.zero
            end)
            frozenHRP = nil
        end
        for tr in pairs(frozenTracks) do
            pcall(function()
                if tr and tr.Parent then
                    tr:AdjustSpeed(1)
                    if FX.BodyAnim ~= false and tr.Looped and not tr.IsPlaying then
                        tr:Play(0.15)
                    end
                end
            end)
        end
        frozenTracks = {}
        if Humanoid and Humanoid.Parent then
            pcall(function()
                Humanoid.PlatformStand = false
                Humanoid.Sit = false
                Humanoid.AutoRotate = true
                local st = Humanoid:GetState()
                if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.PlatformStanding then
                    Humanoid:ChangeState(Enum.HumanoidStateType.Running)
                end
            end)
        end
    end

    local BA = {char = nil, J = {}, cur = {}, spasm = {}, out = {}, conns = {}, animate = nil, animateWas = nil, nextSpasm = 0, poseIdx = 1, nextPose = 0, seed = math.random() * 100}
    local V3 = Vector3.new
    local BA_MAP = {
        waist = {"UpperTorso", "Torso"},
        neck = {"Head"},
        rs = {"RightUpperArm", "Right Arm"},
        ls = {"LeftUpperArm", "Left Arm"},
        re = {"RightLowerArm"},
        le = {"LeftLowerArm"},
        rw = {"RightHand"},
        lw = {"LeftHand"},
        rh = {"RightUpperLeg", "Right Leg"},
        lh = {"LeftUpperLeg", "Left Leg"},
        rk = {"RightLowerLeg"},
        lk = {"LeftLowerLeg"},
    }
    local BA_KEYS = {"waist", "neck", "rs", "ls", "re", "le", "rw", "lw", "rh", "lh", "rk", "lk"}
    local BA_SHAKE = {waist = 2, neck = 4, rs = 3, ls = 3, re = 4, le = 4, rw = 9, lw = 9, rh = 2, lh = 2, rk = 3, lk = 3}
    local BA_SPASM = {waist = 12, neck = 30, rs = 26, ls = 26, re = 22, le = 22, rw = 32, lw = 32, rh = 11, lh = 11, rk = 13, lk = 13}
    local BA_POSES = {
        {waist = V3(-24, 0, 0), neck = V3(-16, 0, 0), rs = V3(125, 0, 14), ls = V3(125, 0, -14), re = V3(115, 0, 0), le = V3(115, 0, 0),
         rw = V3(0, 0, 0), lw = V3(0, 0, 0), rh = V3(14, 0, 5), lh = V3(14, 0, -5), rk = V3(-28, 0, 0), lk = V3(-28, 0, 0)},
        {waist = V3(14, 0, 0), neck = V3(38, 0, 0), rs = V3(25, 0, 100), ls = V3(25, 0, -100), re = V3(30, 0, 0), le = V3(30, 0, 0),
         rw = V3(0, 0, 25), lw = V3(0, 0, -25), rh = V3(6, 0, 10), lh = V3(6, 0, -10), rk = V3(-12, 0, 0), lk = V3(-12, 0, 0)},
        {waist = V3(-10, 25, 0), neck = V3(-5, -30, 8), rs = V3(135, 0, 10), ls = V3(10, 0, -70), re = V3(120, 0, 0), le = V3(40, 0, 0),
         rw = V3(0, 0, 0), lw = V3(0, 0, 0), rh = V3(10, 0, 4), lh = V3(-8, 0, -4), rk = V3(-20, 0, 0), lk = V3(-10, 0, 0)},
        {waist = V3(-34, -18, 6), neck = V3(10, 28, -12), rs = V3(60, 0, 40), ls = V3(150, 0, -8), re = V3(90, 0, 0), le = V3(100, 0, 0),
         rw = V3(0, 0, 0), lw = V3(0, 0, 0), rh = V3(20, 0, 6), lh = V3(4, 0, -6), rk = V3(-34, 0, 0), lk = V3(-16, 0, 0)},
    }
    for _, pose in ipairs(BA_POSES) do
        for _, key in ipairs(BA_KEYS) do pose[key] = pose[key] or V3(0, 0, 0) end
    end


    -- ============================================================
    -- ANIMAÇÃO DO DAVID: timeline de poses sincronizada com a fala (ângulos em graus)
    -- t = segundos desde o início da fala | fast = entra com snap (ease-out)
    -- ============================================================
    local function TP(t) for _, k in ipairs(BA_KEYS) do t[k] = t[k] or V3(0, 0, 0) end return t end
    local BA_TL = {
        -- agachado, cabeça baixa, respirando fundo
        {t = 0.00, p = TP{waist = V3(22,0,0), neck = V3(28,0,0), rs = V3(8,0,12), ls = V3(8,0,-12), re = V3(25,0,0), le = V3(25,0,0), rh = V3(-6,0,6), lh = V3(-6,0,-6), rk = V3(-18,0,0), lk = V3(-18,0,0)}},
        -- "I'm gonna rip out his spine!" -> prepara o braço
        {t = 0.55, p = TP{waist = V3(-14,28,0), neck = V3(-10,-20,0), rs = V3(-35,0,25), ls = V3(70,0,-30), re = V3(100,0,0), le = V3(60,0,0), rh = V3(12,0,4), lh = V3(-10,0,-4), rk = V3(-30,0,0), lk = V3(-10,0,0)}},
        -- "spine!" -> bote com a mão em garra
        {t = 1.20, fast = true, p = TP{waist = V3(32,-30,0), neck = V3(12,15,0), rs = V3(105,0,8), ls = V3(-25,0,-20), re = V3(8,0,0), le = V3(70,0,0), rw = V3(0,0,-35), rh = V3(-24,0,4), lh = V3(22,0,-4), rk = V3(-8,0,0), lk = V3(-40,0,0)}},
        -- "I'll kill him!" -> grito, cabeça pra trás, braços abertos
        {t = 2.20, fast = true, p = TP{waist = V3(-26,0,0), neck = V3(-32,0,0), rs = V3(25,0,85), ls = V3(25,0,-85), re = V3(35,0,0), le = V3(35,0,0), rw = V3(0,0,30), lw = V3(0,0,-30), rh = V3(8,0,10), lh = V3(8,0,-10), rk = V3(-18,0,0), lk = V3(-18,0,0)}},
        -- cambaleia pra frente
        {t = 3.00, p = TP{waist = V3(30,-12,6), neck = V3(34,10,-10), rs = V3(40,0,30), ls = V3(40,0,-30), re = V3(60,0,0), le = V3(60,0,0), rh = V3(10,0,5), lh = V3(-8,0,-5), rk = V3(-20,0,0), lk = V3(-10,0,0)}},
        -- "I'll kill him." -> baixo, tremendo, punhos no peito
        {t = 3.70, p = TP{waist = V3(24,0,0), neck = V3(36,0,0), rs = V3(18,0,8), ls = V3(18,0,-8), re = V3(105,0,0), le = V3(105,0,0), rh = V3(6,0,5), lh = V3(6,0,-5), rk = V3(-22,0,0), lk = V3(-22,0,0)}},
        -- "You're dead." -> cabeça levanta e aponta
        {t = 5.15, p = TP{waist = V3(-8,10,0), neck = V3(-18,-14,10), rs = V3(92,0,6), ls = V3(8,0,-14), le = V3(30,0,0), rh = V3(8,0,4), lh = V3(-6,0,-4), rk = V3(-14,0,0), lk = V3(-6,0,0)}},
        -- "Dead." -> dedo cravado
        {t = 6.40, fast = true, p = TP{waist = V3(18,12,0), neck = V3(8,10,0), rs = V3(110,0,4), ls = V3(-30,0,-20), le = V3(60,0,0), rh = V3(-20,0,4), lh = V3(16,0,-4), rk = V3(-6,0,0), lk = V3(-30,0,0)}},
        -- "Dead." final -> braços pro alto, convulsão
        {t = 7.40, fast = true, p = TP{waist = V3(-30,0,0), neck = V3(-38,0,0), rs = V3(150,0,35), ls = V3(150,0,-35), re = V3(20,0,0), le = V3(20,0,0), rw = V3(0,0,30), lw = V3(0,0,-30), rh = V3(10,0,12), lh = V3(10,0,-12), rk = V3(-30,0,0), lk = V3(-30,0,0)}},
        -- desaba no fim
        {t = 8.60, p = TP{waist = V3(32,0,0), neck = V3(40,0,0), rs = V3(6,0,10), ls = V3(6,0,-10), re = V3(20,0,0), le = V3(20,0,0), rh = V3(-4,0,5), lh = V3(-4,0,-5), rk = V3(-24,0,0), lk = V3(-24,0,0)}},
    }
    local function BA_TLPose(t)
        local n = #BA_TL
        if t <= BA_TL[1].t then return BA_TL[1].p end
        if t >= BA_TL[n].t then return BA_TL[n].p end
        for i = 1, n - 1 do
            local a, b = BA_TL[i], BA_TL[i + 1]
            if t >= a.t and t < b.t then
                local x = (t - a.t) / (b.t - a.t)
                x = b.fast and (1 - (1 - x) ^ 3) or x * x * (3 - 2 * x)
                local out = {}
                for _, k in ipairs(BA_KEYS) do out[k] = a.p[k]:Lerp(b.p[k], x) end
                return out
            end
        end
        return BA_TL[n].p
    end

    local function BodyAnimApply()
        for key, T in pairs(BA.out) do
            local m = BA.J[key]
            if m and m.Parent then m.Transform = T end
        end
    end

    local function BA_Find(char)
        BA.char = char
        BA.J = {}
        BA.cur = {}
        BA.spasm = {}
        BA.out = {}
        local an = char:FindFirstChild("Animate")
        if an and an:IsA("LocalScript") then
            BA.animate = an
            if BA.animateWas == nil then BA.animateWas = an.Enabled end
            an.Enabled = false
        end
        if #BA.conns == 0 then
            table.insert(BA.conns, RunService.Stepped:Connect(BodyAnimApply))
            table.insert(BA.conns, RunService.Heartbeat:Connect(BodyAnimApply))
            table.insert(BA.conns, RunService.PreSimulation:Connect(BodyAnimApply))
        end
        for _, d in ipairs(char:GetDescendants()) do
            if (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) and d.Part0 and d.Part1 then
                for key, names in pairs(BA_MAP) do
                    if not BA.J[key] then
                        for _, n in ipairs(names) do
                            if d.Part1.Name == n then BA.J[key] = d end
                        end
                    end
                end
            end
        end
    end

    local function BodyAnimKick(power)
        for _, key in ipairs(BA_KEYS) do
            if math.random() < 0.75 then
                BA.spasm[key] = V3(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1) * BA_SPASM[key] * (power or 1)
            end
        end
        BA.nextPose = 0
    end

    local function BodyAnimRelease()
        for _, c in ipairs(BA.conns) do pcall(function() c:Disconnect() end) end
        BA.conns = {}
        BA.out = {}
        for _, m in pairs(BA.J) do
            pcall(function()
                if m and m.Parent then m.Transform = CFrame.new() end
            end)
        end
        local animateScript = BA.animate
        local wasEnabled = BA.animateWas
        BA.animate, BA.animateWas = nil, nil
        BA.J, BA.cur, BA.spasm, BA.char = {}, {}, {}, nil
        if animateScript and animateScript.Parent then
            pcall(function()
                animateScript.Enabled = false
                task.defer(function()
                    if animateScript and animateScript.Parent then
                        animateScript.Enabled = (wasEnabled ~= false)
                    end
                end)
            end)
        else
            local char = Player.Character
            if char then
                local an = char:FindFirstChild("Animate")
                if an and an:IsA("LocalScript") then
                    pcall(function()
                        an.Enabled = false
                        task.defer(function()
                            if an and an.Parent then an.Enabled = true end
                        end)
                    end)
                end
            end
        end
    end

    local function BodyAnimStep(dt, elapsed, k, phase)
        if FX.BodyAnim == false then return end
        local char = Player.Character
        if not char then return end
        if BA.char ~= char or not BA.J.waist or not BA.J.waist.Parent then BA_Find(char) end
        local tl = FX.BodyTimeline ~= false and speechOn
        local I = (FX.BodyAnimIntensity or 1) * (0.7 + 0.45 * phase) * (tl and 0.6 or 1)
        local t = elapsed

        if not tl and t >= BA.nextPose then
            local n
            repeat n = math.random(1, #BA_POSES) until n ~= BA.poseIdx
            BA.poseIdx = n
            BA.nextPose = t + (0.45 + math.random() * 0.9) / (0.6 + 0.4 * phase)
        end
        if t >= BA.nextSpasm then
            local count = math.random(1, 3 + phase)
            for _ = 1, count do
                local key = BA_KEYS[math.random(1, #BA_KEYS)]
                BA.spasm[key] = V3(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1) * BA_SPASM[key] * I * (0.5 + math.random() * 0.8)
            end
            BA.nextSpasm = t + (0.05 + math.random() * 0.22) / (0.7 + 0.4 * phase)
        end

        local pose = BA_POSES[BA.poseIdx]
        local blend = math.min(1, dt * (7 + 4 * phase))
        if tl then pose = BA_TLPose(t - (S.Offset or 0)); blend = math.min(1, dt * 28) end
        local decay = math.exp(-dt * 14)
        local w = math.min(1, t * 3) * k
        local freq = 9 + 6 * phase

        for i, key in ipairs(BA_KEYS) do
            local m = BA.J[key]
            if m and m.Parent and m.Part0 and m.Part1 then
                BA.cur[key] = (BA.cur[key] or pose[key]):Lerp(pose[key], blend)
                local sp = BA.spasm[key]
                if sp then
                    sp = sp * decay
                    BA.spasm[key] = sp
                end
                local sa = BA_SHAKE[key] * I
                local nx = math.noise(t * freq + BA.seed + i * 7.3, i * 1.7, 0) * 2
                local ny = math.noise(t * freq + BA.seed + i * 3.1, i * 2.9, 5.5) * 2
                local nz = math.noise(t * freq + BA.seed + i * 5.7, i * 4.3, 9.1) * 2
                local a = BA.cur[key] * w * I ^ 0.35 + V3(nx, ny, nz) * sa * w + (sp or V3(0, 0, 0)) * w
                local c0 = m.C0 - m.C0.Position
                local T = c0:Inverse() * CFrame.Angles(math.rad(a.X), math.rad(a.Y), math.rad(a.Z)) * c0
                BA.out[key] = T
                m.Transform = T
            end
        end
    end

    -- ============================================================
    -- GLITCH EM VIEWPORTFRAME  (+ PHASESHIFT POR PEÇA: corpo e acessórios)
    -- O boneco (parado) é clonado para dentro de ViewportFrames que usam a MESMA
    -- câmera do jogo => alinhados 1:1 com o corpo real. Em cima dele:
    --   * 2 camadas de tela cheia (ciano/roxa) com deslocamento em PIXELS (RGB split)
    --   * fatias horizontais do corpo que saltam de lado (o "datamosh" do glitch)
    -- ============================================================
    local GLITCH = FX.ViewportGlitch and FX.FreezeBody
    local SPLIT_CYAN = Color3.fromRGB(0, 240, 255)
    local SPLIT_PURPLE = Color3.fromRGB(160, 50, 255)
    local SLICE_TINTS = {WHITE, WHITE, CYAN, MAGENTA, RED}
    local VP_JUNK = {"Script", "LocalScript", "ModuleScript", "Sound", "ParticleEmitter", "Trail", "Beam", "Highlight", "BillboardGui", "ForceField", "Fire", "Smoke", "Sparkles", "PointLight", "SpotLight", "SurfaceLight", "BodyMover", "VectorForce", "Animator", "JointInstance", "Constraint"}
    local PART_TINTS = {CYAN, MAGENTA, RED, WHITE}
    local PART_KINDS = {"jump", "jump", "rot", "blink", "tint"}

    local vpRoot = Create("Frame", {Name = "GlitchLayer", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 5, Parent = sg})
    local layers, slices, glitchQueue = {}, {}, {}

    -- ---------- PHASESHIFT POR PEÇA ----------
    -- Cada peça do boneco (e cada acessório inteiro) vira um "grupo". O clone no
    -- ViewportFrame é pareado com o boneco real pelo caminho (igual ao PhaseGhost do
    -- SANDEVISTAN) e segue ele todo frame. Quando um grupo glitcha, só a cópia dele
    -- sai do lugar / gira / pisca / vira neon, e a peça real some por um instante.
    local groupList, groupOf, srcMap, srcGroup, prevLTM = {}, {}, nil, {}, {}

    local function KeyedParts(root)
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

    local function EnsureSource()
        if srcMap then return srcMap end
        local char = Player.Character
        if not char then return nil end
        srcMap = KeyedParts(char)
        for _, op in pairs(srcMap) do
            if op.Name ~= "HumanoidRootPart" and op.Transparency < 0.99 then
                local acc = op:FindFirstAncestorOfClass("Accessory")
                local keyObj = (acc and acc:IsDescendantOf(char)) and acc or op
                local g = groupOf[keyObj]
                if not g then
                    g = {parts = {}, active = false, life = 0, jit = 0, power = 1, kind = "jump",
                         off = Vector3.zero, world = Vector3.zero, rot = CFrame.new(),
                         show = false, hidden = false, hideOrig = false, tint = nil}
                    groupOf[keyObj] = g
                    table.insert(groupList, g)
                end
                table.insert(g.parts, op)
                srcGroup[op] = g
            end
        end
        return srcMap
    end

    local function RandSign() return math.random() < 0.5 and -1 or 1 end

    -- esconde/mostra a peça REAL (só no seu cliente)
    local function SetHidden(g, on)
        if g.hidden == on then return end
        g.hidden = on
        for _, op in ipairs(g.parts) do
            if op.Parent then
                if on then
                    if prevLTM[op] == nil then prevLTM[op] = op.LocalTransparencyModifier end
                    op.LocalTransparencyModifier = 1
                else
                    op.LocalTransparencyModifier = prevLTM[op] or 0
                end
            end
        end
    end

    -- sorteia o deslocamento da peça (em espaço da câmera: x = direita, y = cima)
    local function RollGroup(g)
        local s = (FX.GlitchIntensity or 1) * g.power
        local kind = g.kind
        g.off = Vector3.zero
        g.rot = CFrame.new()
        if kind == "jump" then
            g.off = Vector3.new(RandSign() * (0.4 + math.random() * 1.4), (math.random() - 0.5) * 0.9, 0) * s
            g.show = true
        elseif kind == "rot" then
            g.off = Vector3.new((math.random() - 0.5) * 1.2, (math.random() - 0.5) * 0.6, 0) * s
            g.rot = CFrame.Angles(
                math.rad((math.random() - 0.5) * 50 * s),
                math.rad((math.random() - 0.5) * 80 * s),
                math.rad((math.random() - 0.5) * 90 * s))
            g.show = true
        elseif kind == "blink" then
            g.show = not g.show                      -- a cópia pisca ligando/desligando
            g.off = Vector3.new(RandSign() * math.random() * 0.3 * s, 0, 0)
        else
            g.show = true                            -- "tint": overlay neon sem deslocar
        end
        g.tint = nil
        if FX.PartTint ~= false and (kind == "tint" or math.random() < 0.3) then
            g.tint = PART_TINTS[math.random(1, #PART_TINTS)]
        end
    end

    local function StartGroup(g, power)
        local kind = PART_KINDS[math.random(1, #PART_KINDS)]
        if kind == "tint" and FX.PartTint == false then kind = "jump" end
        g.kind = kind
        g.power = power
        g.life = (0.05 + math.random() * 0.12) * (power > 1 and 1.3 or 1)
        g.jit = 0.03
        g.show = true
        g.active = true
        g.hideOrig = kind ~= "tint" and FX.HideOriginal ~= false and math.random() > 0.3
        SetHidden(g, g.hideOrig)
        RollGroup(g)
    end

    local function EndGroup(g)
        g.active = false
        g.show = false
        g.tint = nil
        g.off = Vector3.zero
        g.world = Vector3.zero
        g.rot = CFrame.new()
        SetHidden(g, false)
    end

    local function GlitchCF(cf, g)
        return CFrame.new(cf.Position + g.world) * g.rot * cf.Rotation
    end

    -- lista {ghostPart, originalPart} -> pares com o estado de cada peça do clone
    local function MakePairs(list, main)
        local out = {}
        for _, e in ipairs(list) do
            local gp = e.gp
            table.insert(out, {gp = gp, op = e.op, g = srcGroup[e.op], t = gp.Transparency, color = gp.Color, mat = gp.Material, vis = not main, tinted = false, cf = nil})
            if main then gp.Transparency = 1 end   -- a camada principal só mostra peças em glitch
        end
        return out
    end

    -- copia a pose do boneco real pro clone (+ deslocamento do glitch)
    local function SyncLayer(L)
        local main = L.main
        for _, pr in ipairs(L.pairs) do
            local gp, op, g = pr.gp, pr.op, pr.g
            if gp.Parent and op.Parent then
                local active = g ~= nil and g.active
                local cf = op.CFrame
                if active then cf = GlitchCF(cf, g) end
                if main then
                    local show = active and g.show
                    local want = (show and g.tint) or false
                    if want ~= pr.tinted then
                        if want then
                            gp.Color = want
                            gp.Material = Enum.Material.Neon
                        else
                            gp.Color = pr.color
                            gp.Material = pr.mat
                        end
                        pr.tinted = want
                    end
                    if show then
                        if pr.cf ~= cf then gp.CFrame = cf pr.cf = cf end
                        if not pr.vis then gp.Transparency = pr.t pr.vis = true end
                    elseif pr.vis then
                        gp.Transparency = 1
                        pr.vis = false
                    end
                elseif pr.cf ~= cf then
                    gp.CFrame = cf
                    pr.cf = cf
                end
            end
        end
    end

    -- clone EXATO do boneco (cores, roupas, acessórios) para dentro de um ViewportFrame
    local function CloneForViewport()
        local char = Player.Character
        if not char or not char.Parent then return nil end
        local ghost
        local prevArch = char.Archivable
        pcall(function()
            char.Archivable = true
            ghost = char:Clone()
        end)
        pcall(function() char.Archivable = prevArch end)
        if not ghost then return nil end

        for _, obj in ipairs(ghost:GetDescendants()) do
            local junk = false
            for _, cls in ipairs(VP_JUNK) do
                if obj:IsA(cls) then junk = true break end
            end
            if junk then
                pcall(function() obj:Destroy() end)
            elseif obj:IsA("BasePart") then
                obj.Anchored = true
                obj.CanCollide = false
                obj.CanQuery = false
                obj.CanTouch = false
                obj.CastShadow = false
            end
        end
        local hum = ghost:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function()
                hum.PlatformStand = true
                hum.AutoRotate = false
                hum.RequiresNeck = false
                hum.BreakJointsOnDeath = false
                hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
            end)
        end
        ghost.Name = "PsychoGlitchBody"

        -- pareia cada peça do clone com a peça real (mesmo caminho/nome)
        local list = {}
        local map = EnsureSource()
        if map then
            for key, gp in pairs(KeyedParts(ghost)) do
                local op = map[key]
                if op then table.insert(list, {gp = gp, op = op}) end
            end
        end
        return ghost, list
    end

    local function MakeViewport(parent, tint, imgTransparency)
        return Create("ViewportFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Ambient = Color3.fromRGB(200, 200, 200),   -- padrão do ViewportFrame (cores fiéis)
            LightColor = Color3.fromRGB(140, 140, 140),
            ImageColor3 = tint,
            ImageTransparency = imgTransparency,
            CurrentCamera = Workspace.CurrentCamera,
            Parent = parent,
        })
    end

    if GLITCH then
        -- fila: 1 clone por frame (clonar tudo de uma vez trava o celular)
        pcall(EnsureSource)
        -- camada principal: cores reais, só mostra as peças que estão em glitch
        if FX.PartGlitch ~= false then
            table.insert(glitchQueue, function()
                local body, list = CloneForViewport()
                if not body then return end
                local vpf = MakeViewport(vpRoot, WHITE, 0)
                vpf.ZIndex = 2
                body.Parent = vpf
                table.insert(layers, {vpf = vpf, main = true, pairs = MakePairs(list, true)})
            end)
        end
        if FX.ColorSplit then
            for _, def in ipairs({{SPLIT_CYAN, -1}, {SPLIT_PURPLE, 1}}) do
                table.insert(glitchQueue, function()
                    local body, list = CloneForViewport()
                    if not body then return end
                    local vpf = MakeViewport(vpRoot, def[1], 0.45)
                    vpf.ZIndex = 1
                    body.Parent = vpf
                    table.insert(layers, {vpf = vpf, main = false, side = def[2], base = 0.45, pairs = MakePairs(list, false)})
                end)
            end
        end
        for _ = 1, (FX.GlitchSlices or 0) do
            table.insert(glitchQueue, function()
                local body = CloneForViewport()
                if not body then return end
                -- moldura que recorta a fatia + viewport de tela cheia lá dentro (deslocado p/ cima)
                local clip = Create("Frame", {BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.new(1, 0, 0, 20), Visible = false, ZIndex = 3, Parent = vpRoot})
                local vpf = MakeViewport(clip, WHITE, 0)
                vpf.Size = UDim2.new(1, 0, 0, math.max(1, sg.AbsoluteSize.Y))
                body.Parent = vpf
                table.insert(slices, {clip = clip, vpf = vpf, life = 0, jit = 0, y = 0, dx = 0})
            end)
        end
    end

    -- faixa vertical (em pixels) que o boneco ocupa na tela
    local function BodyScreenRange()
        local cam = Workspace.CurrentCamera
        local root = frozenHRP or HRP
        if not cam or not root then return nil end
        local a = cam:WorldToViewportPoint(root.Position + Vector3.new(0, 3.2, 0))
        local b = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3.2, 0))
        return math.min(a.Y, b.Y), math.max(a.Y, b.Y)
    end

    -- dispara uma fatia: um pedaço horizontal do corpo salta de lado por alguns frames
    local function ActivateSlice(sl, power)
        local top, bot = BodyScreenRange()
        if not top then return end
        local bodyH = math.max(40, bot - top)
        local h = math.max(4, math.floor(bodyH * (0.04 + math.random() * 0.16)))
        local y = math.floor(top + math.random() * math.max(1, bodyH - h))
        local maxDx = (30 + bodyH * 0.35) * (FX.GlitchIntensity or 1) * power
        sl.y = y
        sl.dx = (math.random() < 0.5 and -1 or 1) * (0.25 + math.random() * 0.75) * maxDx
        sl.life = 0.05 + math.random() * 0.08
        sl.jit = 0
        sl.clip.Size = UDim2.new(1, 0, 0, h)
        sl.clip.Position = UDim2.new(0, sl.dx, 0, y)
        sl.vpf.Position = UDim2.new(0, 0, 0, -y)
        sl.vpf.ImageColor3 = SLICE_TINTS[math.random(1, #SLICE_TINTS)]
        sl.clip.Visible = true
    end

    local function UpdateGlitch(dt, phase, fadeProgress)
        if not GLITCH then return end
        local k = 1 - fadeProgress
        do
            local __o = (getgenv and getgenv()) or _G
            vpRoot.Visible = not (__o.SandiVPOccluded and __o.SandiVPOccluded(__o.SandiVPBodyPoints(frozenHRP or HRP)))
        end

        local make = table.remove(glitchQueue, 1)
        if make then pcall(make) end

        -- glitch por peça: sorteia/atualiza cada grupo e copia a pose do boneco pros clones
        if FX.PartGlitch ~= false then
            local cam = Workspace.CurrentCamera
            local camCF = cam and cam.CFrame or CFrame.new()
            local chance = ({0.003, 0.009, 0.022})[phase] * k * (FX.PartGlitchRate or 1)
            for _, g in ipairs(groupList) do
                if g.active then
                    g.life -= dt
                    g.jit -= dt
                    if g.jit <= 0 then
                        g.jit = 0.03
                        RollGroup(g)
                    end
                    if g.life <= 0 or fadeProgress >= 1 then EndGroup(g) end
                elseif math.random() < chance then
                    StartGroup(g, 1)
                end
                if g.active then
                    g.world = camCF:VectorToWorldSpace(g.off * k)
                    if g.hidden then   -- reafirma (o script de câmera do jogo pode mexer no LTM)
                        for _, op in ipairs(g.parts) do
                            if op.Parent then op.LocalTransparencyModifier = 1 end
                        end
                    end
                end
            end
            for _, L in ipairs(layers) do SyncLayer(L) end
        end

        -- RGB split: base em pixels + estouro nas batidas + micro-estouros aleatórios
        local px = FX.SplitPixels + hitKick * 14 * (FX.GlitchIntensity or 1)
        if math.random() < ({0.03, 0.08, 0.16})[phase] then px += math.random(3, 10) end
        px = math.floor(px * k + 0.5)
        for _, L in ipairs(layers) do
            if not L.main then
                L.vpf.Position = UDim2.new(0, px * L.side, 0, 0)
                L.vpf.ImageTransparency = 1 - (1 - L.base) * k
            end
        end

        -- fatias deslocadas (gaguejam o deslocamento enquanto vivas)
        local chance = ({0.01, 0.025, 0.05})[phase] * k
        for _, sl in ipairs(slices) do
            if sl.clip.Visible then
                sl.life -= dt
                sl.jit -= dt
                if sl.jit <= 0 then
                    sl.jit = 0.03
                    sl.dx = sl.dx * (0.6 + math.random() * 0.8)
                    sl.clip.Position = UDim2.new(0, sl.dx, 0, sl.y)
                end
                if sl.life <= 0 or fadeProgress >= 1 then sl.clip.Visible = false end
            elseif math.random() < chance then
                ActivateSlice(sl, 1)
            end
        end
    end

    -- ---------- câmera: inclinação + zoom (somados, sem brigar com os outros FOV do script) ----------
    local CAM_NAME = "CyberPsychosisCam"
    if FX.Camera then
        RunService:BindToRenderStep(CAM_NAME, Enum.RenderPriority.Camera.Value + 1, function()
            local cam = Workspace.CurrentCamera
            if not cam then return end
            if camRoll ~= 0 then cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, math.rad(camRoll)) end
            cam.FieldOfView = cam.FieldOfView + (fovDelta - fovApplied)
            fovApplied = fovDelta
        end)
    end

    local function Cleanup()
        if connection then connection:Disconnect() connection = nil end
        if FX.Camera then
            pcall(function() RunService:UnbindFromRenderStep(CAM_NAME) end)
            local cam = Workspace.CurrentCamera
            if cam then cam.FieldOfView = cam.FieldOfView - fovApplied end
            fovApplied = 0
        end
        if hbSound then hbSound:Destroy() end
        if speechSound then speechSound:Destroy() end
        if toneSound then
            pcall(function()
                toneSound:Stop()
                toneSound:Destroy()
            end)
            toneSound = nil
        end
        for _, g in ipairs(groupList) do pcall(SetHidden, g, false) end   -- devolve as peças reais
        if Module.ActiveCleanup == Cleanup then Module.ActiveCleanup = nil end
        BodyAnimRelease()
        UnfreezeBody()
        if sg then sg:Destroy() end
    end

    -- ---------- batidas sincronizadas com o áudio (ORIGINAL: syncTimesDistortion) ----------
    Module.ActiveCleanup = Cleanup
    local syncHits = speechOn and {} or {0.3, 1.4, 2.7, 3.55, 4.05, 4.55, 5.1}
    local hitIndex = 1
    local function Hit(power)
        power = math.clamp(power or 1, 0.4, 2)
        hitKick = power
        BodyAnimKick(power)
        rollKick = (math.random() < 0.5 and -1 or 1) * (3 + math.random() * 3) * power
        Flash(RED, math.clamp(0.5 - (power - 1) * 0.3, 0.1, 0.85), 0.18)
        Tear(math.random(3, 5) + math.floor(math.max(0, power - 1) * 4))
        for _, sl in ipairs(slices) do ActivateSlice(sl, 1.4 * power) end
        if GLITCH and FX.PartGlitch ~= false then
            for _, g in ipairs(groupList) do
                if math.random() < math.min(0.95, 0.65 * power) then StartGroup(g, 1.6 * power) end
            end
        end
    end

    -- eventos da fala: cada linha (e cada Hit extra) vira um estouro no tempo certo
    local events = {}
    if speechOn then
        local off = S.Offset or 0
        for _, l in ipairs(S.Lines) do
            -- chance: se a linha tem .chance, usa o mesmo roll de playFuckingDead (10%)
            local ok = true
            if l.chance ~= nil then
                ok = playFuckingDead
            end
            if ok then
                table.insert(events, {t = (l.t or 0) + off, line = l, hit = l.hit ~= false, power = l.power or 1, windows = l.windows or 3, final = l.final})
            end
        end
        for _, h in ipairs(S.Hits or {}) do
            local ok = true
            if h.chance ~= nil then
                ok = playFuckingDead
            end
            if ok then
                table.insert(events, {t = (h.t or 0) + off, hit = true, power = h.power or 1, windows = h.windows or 0, final = h.final})
            end
        end
        table.sort(events, function(a, b) return a.t < b.t end)
    end
    local eventIndex = 1

    local BPM = {90, 125, 170}
    local nextBeat, nextDub = 0, nil

    FreezeBody()

    connection = RunService.RenderStepped:Connect(function(dt)
        FreezeBody()   -- mantém tudo parado (pega animação nova que o jogo tentar tocar)
        local elapsed = tick() - startTime
        local fadeStart = DURATION - 1.0  -- 1s de desligamento suave (não corta seco)
        local fadeProgress = elapsed > fadeStart and math.clamp((elapsed - fadeStart) / 1.0, 0, 1) or 0
        local k = 1 - fadeProgress
        local phase = elapsed < phaseDuration and 1 or (elapsed < phaseDuration * 2 and 2 or 3)
        local okBA, errBA = pcall(BodyAnimStep, dt, elapsed, k, phase)
        if not okBA then warn(errBA) end

        -- fade-out final (ORIGINAL)
        if fadeProgress > 0 and cc then
            cc.TintColor = Color3.fromRGB(255, 80, 80):Lerp(WHITE, fadeProgress)
            cc.Saturation = 1.3 * k
            cc.Contrast = 0.6 * k
        end

        -- fim (ORIGINAL)
        if elapsed > DURATION then
            if Humanoid and Humanoid.Parent then
                pcall(function()
                    Humanoid.WalkSpeed = Constants.BASE_WALKSPEED or 16
                    Humanoid.JumpPower = 50
                    if Humanoid.UseJumpPower == false then
                        Humanoid.JumpHeight = 7.2
                    end
                    Humanoid.PlatformStand = false
                    Humanoid.Sit = false
                    Humanoid.AutoRotate = true
                    Humanoid.CameraOffset = Vector3.zero
                    local st = Humanoid:GetState()
                    if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.PlatformStanding or st == Enum.HumanoidStateType.Seated then
                        Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                    end
                end)
            end
            TweenService:Create(cc, TweenInfo.new(0.5), {TintColor = WHITE, Saturation = 0}):Play()
            TweenService:Create(blur, TweenInfo.new(0.5), {Size = 0}):Play()
            Debris:AddItem(cc, 0.5)
            Debris:AddItem(blur, 0.5)
            Cleanup()
            if math.random(1, 100) <= 30 then
                task.delay(0.5, function() SystemRestorePopup() end)
            end
            return
        end

        -- mecânica por fase (ORIGINAL)
        if Humanoid and Humanoid.Health > 0 then
            local drainRate = 0
            if phase == 1 then
                drainRate = Humanoid.MaxHealth * 0.05 * dt
                CFG.ShakeIntensity = 0.2
                CFG.PopupRate = 0.05
            elseif phase == 2 then
                drainRate = Humanoid.MaxHealth * 0.08 * dt
                CFG.ShakeIntensity = 0.6
                CFG.PopupRate = 0.1
            else
                drainRate = Humanoid.MaxHealth * 0.12 * dt
                CFG.ShakeIntensity = 1.0
                CFG.PopupRate = 0.15
                if not FX.FreezeBody then Humanoid.WalkSpeed = 50 end
            end
            Humanoid.Health = math.max(1, Humanoid.Health - drainRate)
        end

        CFG.ShakeIntensity = CFG.ShakeIntensity * k
        blur.Size = math.random(4, 12) * k
        shakeCamera()
        if math.random() < CFG.PopupRate then spawnPopup() end

        if math.random() < 0.10 then
            cc.TintColor = Color3.fromRGB(math.random(200, 255), math.random(0, 60), math.random(0, 60))
            task.delay(0.08, function() if cc and cc.Parent then cc.TintColor = Color3.fromRGB(255, 80, 80) end end)
        elseif phase >= 2 and math.random() < 0.05 then
            cc.TintColor = Color3.fromRGB(90, 200, 255)   -- aberração cromática (ciano)
            task.delay(0.06, function() if cc and cc.Parent then cc.TintColor = Color3.fromRGB(255, 80, 80) end end)
        end

        -- ================= REWORK =================
        -- batimento cardíaco (lub-dub), cada fase mais rápido
        if elapsed >= nextBeat then
            nextBeat = elapsed + 60 / BPM[phase]
            nextDub = elapsed + (60 / BPM[phase]) * 0.28
            beatKick = 1
        end
        if nextDub and elapsed >= nextDub then
            nextDub = nil
            beatKick = math.max(beatKick, 0.6)
        end
        beatKick = math.max(0, beatKick - dt * 6)
        hitKick = math.max(0, hitKick - dt * 5)
        rollKick = rollKick * math.max(0, 1 - dt * 8)

        while hitIndex <= #syncHits and elapsed >= syncHits[hitIndex] do
            hitIndex += 1
            Hit()
        end

        -- fala: legenda + estouro de glitch + janelas no tempo de cada linha
        while eventIndex <= #events and elapsed >= events[eventIndex].t do
            local ev = events[eventIndex]
            eventIndex += 1
            if ev.line then ShowLine(ev.line) end
            if ev.hit then Hit(ev.power) end
            if ev.final then
                Flash(WHITE, 0.05, 0.5)
                Tear(8)
            end
            for i = 1, (ev.windows or 0) do
                task.delay((i - 1) * 0.05, spawnPopup)
            end
        end
        if subRoot.Visible then
            if tick() > subHideAt then
                subRoot.Visible = false
            else
                local jit = 1 + math.floor(hitKick * 8)
                subC.Position = UDim2.new(0, -math.random(0, jit), 0, 20 + math.random(-1, 1))
                subM.Position = UDim2.new(0, math.random(0, jit), 0, 20 + math.random(-1, 1))
                subMain.Text = hitKick > 0.4 and ScrambleText(subText, 0.12 * hitKick) or subText
                local fade = fadeProgress
                subMain.TextTransparency, subName.TextTransparency = fade, fade
            end
        end

        -- visão de túnel
        local edgeT = math.clamp(0.78 - 0.14 * (phase - 1) - 0.5 * beatKick - 0.2 * hitKick, 0.04, 1)
        local edgeFinal = 1 - (1 - edgeT) * k
        for _, e in ipairs(edges) do e.BackgroundTransparency = edgeFinal end

        -- título RGB
        local titleT = ((elapsed % 0.4) < 0.2) and 0.1 or 0.85
        if hitKick > 0.4 then titleT = 0 end
        titleT = 1 - (1 - titleT) * k
        local j = math.floor(2 + phase * 3 + hitKick * 8)
        local jy = math.max(1, math.floor(j / 2))
        titleMain.TextTransparency = titleT
        titleM.TextTransparency = math.clamp(titleT + 0.25, 0, 1)
        titleC.TextTransparency = math.clamp(titleT + 0.25, 0, 1)
        titleM.Position = UDim2.new(0, math.random(0, j), 0.4, math.random(-jy, jy))
        titleC.Position = UDim2.new(0, -math.random(0, j), 0.4, math.random(-jy, jy))

        -- banner piscando
        bannerText.TextTransparency = 1 - (1 - (((elapsed % 0.3) < 0.15) and 0 or 0.6)) * k
        banner.BackgroundTransparency = 1 - (1 - 0.25) * k

        -- HUMANITY caindo
        local shown = math.floor(math.max(0, 100 * (1 - elapsed / (DURATION * 0.92))))
        if phase == 3 and math.random() < 0.3 then shown = math.random(0, 99) end
        humLabel.Text = "HUMANITY " .. shown .. "%"
        humLabel.TextTransparency = fadeProgress
        terminal.TextTransparency = fadeProgress

        -- rasgos de tela
        if math.random() < ({0.05, 0.14, 0.3})[phase] * k then Tear(1) end

        -- glitch em ViewportFrame
        UpdateGlitch(dt, phase, fadeProgress)

        -- câmera
        local rollAmp = ({0.6, 1.4, 2.6})[phase]
        camRoll = (math.sin(elapsed * 6.3) * rollAmp + rollKick) * k
        fovDelta = (({0, 4, 12})[phase] - 5 * beatKick + 10 * hitKick) * k
    end)
end

-- ============================================================
-- API + BOTÃO
-- ============================================================
local Active = false
local CooldownUntil = 0
local endsAt = 0

local function Run()
    if Active or os.clock() < CooldownUntil then return false end
    Sync()
    Active = true
    local dur = EffectiveDuration()
    endsAt = os.clock() + dur
    task.delay(dur + 0.15, function()
        Active = false
        CooldownUntil = os.clock() + Module.Config.Cooldown
    end)
    ExecCyberpsychosis()
    return true
end

function Module.Activate()   -- botão / atalho
    return Run()
end

function Module.Exec()       -- chamado pelo SANDEVISTAN.lua (automático)
    if not Module.Config.AutoTrigger then return false end
    return Run()
end

function Module.IsActive()
    return Active
end

function Module.Destroy()
    if Module.ActiveCleanup then pcall(Module.ActiveCleanup) end
    if syncConn then syncConn:Disconnect() end
    if env.CyberPsychosis == Module then env.CyberPsychosis = nil end
end

env.CyberPsychosis = Module
PsiModule = Module

end)


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
        local __o = (getgenv and getgenv() or _G); vpf.Visible = not (__o.SandiVPOccluded and __o.SandiVPOccluded(__o.SandiVPBodyPoints(Character:FindFirstChild("HumanoidRootPart"))))
        
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
        if PsyBar.Use("Dodge") then return end
        
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
        if PsyBar.Use("Dodge") then return end
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

-- ============================================================
-- CONGELAR O TEMPO (Sandevistan)
-- Ao ativar: tudo no mundo para (peças soltas, outros jogadores/NPCs, animações,
-- partículas e sons do jogo). Sons e efeitos DESTE script continuam normais.
-- Ao desativar: o mundo volta aos poucos (em lotes por frame) pra não dar pico de FPS.
-- Obs.: é tudo local (só na sua tela); o servidor continua rodando normalmente.
-- ============================================================
local TimeFreeze = {
    Active = false,
    Radius = math.huge,      -- raio (studs) do congelamento; math.huge = mundo inteiro
    FreezeNew = true,        -- congela também o que NASCE depois de ativar (projéteis, jogadores que entram, efeitos do jogo)
    PriorityRadii = {60, 150, 320}, -- congela PRIMEIRO o que está perto de você (no mesmo frame da ativação)
    PriorityBudget = 0.012,  -- seg gastos (no máx.) nessa passada instantânea
    PriorityMaxParts = 4000,
    FastScanFrames = 12,     -- nos primeiros frames a varredura do mundo usa um orçamento maior
    FastScanBudget = 0.008,
    ScanBudget = 0.003,      -- seg/frame gastos varrendo o resto do mundo ao ATIVAR
    ReleaseBudget = 0.0015,  -- seg/frame gastos soltando as coisas ao DESATIVAR
    Parts = {},              -- [BasePart] = true (as que EU ancorei)
    Anims = {},              -- [AnimationTrack] = velocidade original
    Emitters = {},           -- [ParticleEmitter/Fire/Smoke/Sparkles] = TimeScale original
    Trails = {},             -- [Trail] = Lifetime original (Lifetime enorme = rastro não some enquanto congelado)
    Beams = {},              -- [Beam] = TextureSpeed original
    Kinds = {ParticleEmitter = "emitter", Fire = "emitter", Smoke = "emitter", Sparkles = "emitter", Trail = "trail", Beam = "beam", Animator = "animator", Sound = "sound"},
    TrailFrozenLifetime = 3600,
    Videos = {},             -- [VideoFrame] = estava tocando?
    Props = {},              -- [inst] = {orig = {prop=valor}, want = {prop=último valor que o jogo tentou pôr}}
    PropEnforce = {},        -- lista (ronda circular) de quem tem propriedades travadas
    PropIndex = 1,
    PropConn = nil,
    PropBudget = 0.002,      -- seg/frame gastos desfazendo mudanças de VFX/imagens/decals/luzes
    PropPartMax = 6000,      -- máx. de peças (VFX feito de parte: tween de tamanho/cor/transparência) com propriedades travadas
    PropPartCount = 0,
    PropList = {},           -- [ClassName] = {propriedades} (preenchido em InitProps)
    PartProps = {"Transparency", "Color", "Size"},
    IgnoreNames = {PhaseGhost = true, GlitchWindow = true, SystemRestoreWindow = true, RebootSystemWindow = true},
    Sounds = {},             -- [Sound] = true (os que EU pausei)
    AnimatorConns = {},
    Conns = {},
    ScanConn = nil,
    ReleaseConn = nil,
    EnforceConn = nil,
    AddedConn = nil,
    Locks = {},              -- [BasePart] = conexão que trava o CFrame (movimento vindo do servidor)
    LockCount = 0,
    LockMax = 4000,          -- máx. de peças com CFrame travado
    LockRadii = {80, 200, 400}, -- as mais próximas de você ganham o travamento primeiro
    Debug = true,            -- imprime no output quanto foi congelado ao ativar
    EnforceBudget = 0.0015,  -- seg/frame gastos garantindo que o que congelou continue congelado
    Enforce = {},            -- {{tipo, instância}, ...} (ronda circular)
    EnforceIndex = 1,
    Queue = nil,
    QueueIndex = 1,
}

local function tfIsMine(inst: Instance): boolean
    return Character ~= nil and inst:IsDescendantOf(Character)
end

-- coisas criadas pelo próprio script (clones holográficos, fantasma de fase, janelas, GUIs do Kiroshi) nunca congelam
function TimeFreeze.IsIgnored(inst: Instance): boolean
    if ScriptSounds[inst] or tfIsMine(inst) then return true end
    local p = inst.Parent
    while p and p ~= Workspace do
        if ScriptSounds[p] or TimeFreeze.IgnoreNames[p.Name] or string.sub(p.Name, 1, 13) == "HologramClone" then return true end
        p = p.Parent
    end
    if TimeFreeze.IgnoreNames[inst.Name] then return true end
    return false
end

-- Trava o CFrame: peças ancoradas movidas pelo servidor (portas, plataformas, tweens,
-- NPCs por script) voltam na hora pra posição de quando o tempo congelou.
local function tfLock(part: BasePart)
    if TimeFreeze.Locks[part] or TimeFreeze.LockCount >= TimeFreeze.LockMax then return end
    local saved = part.CFrame
    TimeFreeze.LockCount += 1
    TimeFreeze.Locks[part] = part:GetPropertyChangedSignal("CFrame"):Connect(function()
        if TimeFreeze.Active and part.CFrame ~= saved then
            part.CFrame = saved
        end
    end)
end

local function tfFreezePart(part: BasePart)
    if part.Anchored or part:IsA("Terrain") then return end
    if tfIsMine(part) then return end
    -- não congela o que está preso a mim (veículo, assento, ferramentas)
    local myRoot = HRP and HRP.AssemblyRootPart
    if myRoot and part.AssemblyRootPart == myRoot then return end
    if TimeFreeze.Radius < math.huge and HRP and (part.Position - HRP.Position).Magnitude > TimeFreeze.Radius then return end
    TimeFreeze.Parts[part] = true
    part.Anchored = true
    table.insert(TimeFreeze.Enforce, {"part", part})
    tfLock(part)
end

local function tfFreezeTrack(track: AnimationTrack)
    if TimeFreeze.Anims[track] == nil then
        TimeFreeze.Anims[track] = track.Speed
        table.insert(TimeFreeze.Enforce, {"anim", track})
    end
    track:AdjustSpeed(0)
end

local function tfFreezeAnimator(animator: Animator)
    if tfIsMine(animator) then return end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        pcall(tfFreezeTrack, track)
    end
    if not TimeFreeze.AnimatorConns[animator] then
        TimeFreeze.AnimatorConns[animator] = animator.AnimationPlayed:Connect(function(track)
            if TimeFreeze.Active then pcall(tfFreezeTrack, track) end
        end)
    end
end

local function tfFreezeEmitter(emitter: Instance)
    if TimeFreeze.Emitters[emitter] == nil then
        TimeFreeze.Emitters[emitter] = emitter.TimeScale
        emitter.TimeScale = 0
        table.insert(TimeFreeze.Enforce, {"emitter", emitter})
    end
end

-- Trail: sem peça se mexendo não nasce segmento novo; Lifetime enorme impede os existentes de sumir
function TimeFreeze.FreezeTrail(trail: Trail)
    if TimeFreeze.Trails[trail] == nil then
        TimeFreeze.Trails[trail] = trail.Lifetime
        trail.Lifetime = TimeFreeze.TrailFrozenLifetime
        table.insert(TimeFreeze.Enforce, {"trail", trail})
    end
end

-- Beam: a textura que rola (TextureSpeed) para; as pontas já param junto com as peças
function TimeFreeze.FreezeBeam(beam: Beam)
    if TimeFreeze.Beams[beam] == nil then
        TimeFreeze.Beams[beam] = beam.TextureSpeed
        beam.TextureSpeed = 0
        table.insert(TimeFreeze.Enforce, {"beam", beam})
    end
end

-- VÍDEO (VideoFrame em SurfaceGui): pausa
function TimeFreeze.FreezeVideo(video: VideoFrame)
    if TimeFreeze.Videos[video] == nil then
        TimeFreeze.Videos[video] = video.Playing
        video:Pause()
        table.insert(TimeFreeze.Enforce, {"video", video})
    end
end

-- PROPRIEDADES TRAVADAS: imagens, decals, texturas, luzes, highlights, GUIs no mundo e VFX feito de peça.
-- Não dá pra pausar script/tween do jogo, então guardo o valor de agora e desfaço qualquer mudança
-- a cada frame (RenderStepped). O último valor que o jogo tentou pôr é aplicado ao descongelar.
function TimeFreeze.FreezeProps(inst: Instance, list)
    if TimeFreeze.Props[inst] or not list then return end
    local orig = {}
    for _, prop in ipairs(list) do
        local o: any = inst
        local ok, v = pcall(function() return o[prop] end)
        if ok then orig[prop] = v end
    end
    TimeFreeze.Props[inst] = {orig = orig, want = {}}
    table.insert(TimeFreeze.PropEnforce, inst)
end

function TimeFreeze.FreezePartProps(part: BasePart)
    if TimeFreeze.Props[part] or TimeFreeze.PropPartCount >= TimeFreeze.PropPartMax then return end
    if part.CanCollide or part.Transparency >= 1 or part:IsA("Terrain") then return end
    if TimeFreeze.IsIgnored(part) then return end
    TimeFreeze.PropPartCount += 1
    TimeFreeze.FreezeProps(part, TimeFreeze.PartProps)
end

function TimeFreeze.EnforceProps(inst: Instance, rec)
    local o: any = inst
    for prop, v in pairs(rec.orig) do
        local cur = o[prop]
        if cur ~= v then
            rec.want[prop] = cur
            o[prop] = v
        end
    end
end

function TimeFreeze.InitProps()
    local L = TimeFreeze.PropList
    local gui = {"Visible", "Position", "Size", "Rotation", "BackgroundTransparency", "BackgroundColor3"}
    local function with(extra)
        local t = table.clone(gui)
        for _, p in ipairs(extra) do table.insert(t, p) end
        return t
    end
    L.Frame, L.ScrollingFrame, L.CanvasGroup = gui, gui, gui
    L.ImageLabel = with({"Image", "ImageTransparency", "ImageColor3", "ImageRectOffset", "ImageRectSize"})
    L.ImageButton = L.ImageLabel
    L.TextLabel = with({"Text", "TextTransparency", "TextColor3", "TextStrokeTransparency"})
    L.TextButton = L.TextLabel
    L.UIGradient = {"Enabled", "Offset", "Rotation", "Transparency", "Color"}
    L.UIStroke = {"Transparency", "Color", "Thickness"}
    L.Decal = {"Texture", "Transparency", "Color3"}
    L.Texture = {"Texture", "Transparency", "Color3", "OffsetStudsU", "OffsetStudsV", "StudsPerTileU", "StudsPerTileV"}
    L.PointLight = {"Enabled", "Brightness", "Range", "Color"}
    L.SpotLight = {"Enabled", "Brightness", "Range", "Angle", "Color"}
    L.SurfaceLight = L.SpotLight
    L.Highlight = {"Enabled", "FillTransparency", "OutlineTransparency", "FillColor", "OutlineColor"}
    L.SurfaceGui = {"Enabled"}
    L.BillboardGui = {"Enabled", "Size", "StudsOffset"}
    for cn in pairs(L) do TimeFreeze.Kinds[cn] = "props" end
    TimeFreeze.Kinds.VideoFrame = "video"
end
TimeFreeze.InitProps()

-- watch = true: se o som ainda não está tocando (acabou de nascer), pausa assim que começar
local function tfFreezeSound(snd: Sound, watch: boolean?)
    if ScriptSounds[snd] or tfIsMine(snd) then return end
    if snd.IsPlaying then
        if not TimeFreeze.Sounds[snd] then
            TimeFreeze.Sounds[snd] = true
            snd:Pause()
            table.insert(TimeFreeze.Enforce, {"sound", snd})
        end
    elseif watch then
        table.insert(TimeFreeze.Conns, snd.Played:Connect(function()
            if TimeFreeze.Active and not ScriptSounds[snd] then
                pcall(tfFreezeSound, snd)
            end
        end))
    end
end

local function tfProcess(inst: Instance)
    if inst:IsA("BasePart") then
        tfFreezePart(inst)
        TimeFreeze.FreezePartProps(inst)
        return
    end
    local k = TimeFreeze.Kinds[inst.ClassName]
    if k == "props" then
        if not TimeFreeze.IsIgnored(inst) then
            TimeFreeze.FreezeProps(inst, TimeFreeze.PropList[inst.ClassName])
        end
    elseif k == "video" then
        TimeFreeze.FreezeVideo(inst)
    elseif k == "emitter" then
        tfFreezeEmitter(inst)
    elseif k == "trail" then
        TimeFreeze.FreezeTrail(inst)
    elseif k == "beam" then
        TimeFreeze.FreezeBeam(inst)
    elseif k == "animator" then
        tfFreezeAnimator(inst)
    elseif k == "sound" then
        tfFreezeSound(inst)
    end
end

-- aplica a restauração de 1 item da fila
local function tfRestoreEntry(e)
    local kind, inst, value = e[1], e[2], e[3]
    if kind == "sound" then
        if inst.Parent then inst:Resume() end
    elseif kind == "anim" then
        if inst.IsPlaying then inst:AdjustSpeed(value) end
    elseif kind == "emitter" then
        if inst.Parent then inst.TimeScale = value end
    elseif kind == "trail" then
        if inst.Parent then inst.Lifetime = value end
    elseif kind == "beam" then
        if inst.Parent then inst.TextureSpeed = value end
    elseif kind == "video" then
        if inst.Parent and value then inst:Play() end
    elseif kind == "props" then
        if inst.Parent then
            local o: any = inst
            for prop, v in pairs(value) do pcall(function() o[prop] = v end) end
        end
    elseif kind == "part" then
        if inst.Parent then inst.Anchored = false end
    end
end

-- termina na hora o que ainda estiver sendo solto (usado se o Sandevistan reativar)
local function tfFlushRelease()
    if TimeFreeze.ReleaseConn then
        TimeFreeze.ReleaseConn:Disconnect()
        TimeFreeze.ReleaseConn = nil
    end
    local q = TimeFreeze.Queue
    if q then
        for i = TimeFreeze.QueueIndex, #q do
            if q[i] then pcall(tfRestoreEntry, q[i]) end
        end
    end
    TimeFreeze.Queue = nil
    TimeFreeze.QueueIndex = 1
end

-- partículas/sons pendurados numa peça (direto nela ou dentro de um Attachment)
function TimeFreeze.FreezeChildren(part: BasePart)
    for _, c in ipairs(part:GetChildren()) do
        if c:IsA("Attachment") then
            for _, cc in ipairs(c:GetChildren()) do
                pcall(tfProcess, cc)
            end
        elseif c:IsA("LayerCollector") then
            pcall(tfProcess, c)
            for _, d in ipairs(c:GetDescendants()) do
                pcall(tfProcess, d)
            end
        else
            pcall(tfProcess, c)
        end
    end
end

-- PASSADA INSTANTÂNEA: congela primeiro tudo que está perto de você (o que aparece na tela),
-- em anéis de raio crescente, no mesmo frame da ativação. O resto vem pela varredura.
function TimeFreeze.PriorityPass()
    local origin = HRP and HRP.Position or Camera.CFrame.Position
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Character}
    params.MaxParts = TimeFreeze.PriorityMaxParts
    local seenModels = {}
    local t0 = os.clock()
    for _, radius in ipairs(TimeFreeze.PriorityRadii) do
        for _, part in ipairs(Workspace:GetPartBoundsInRadius(origin, radius, params)) do
            pcall(tfFreezePart, part)
            pcall(TimeFreeze.FreezePartProps, part)
            pcall(TimeFreeze.FreezeChildren, part)
            local model = part:FindFirstAncestorOfClass("Model")
            if model and not seenModels[model] then
                seenModels[model] = true
                if model:FindFirstChildWhichIsA("Humanoid") or model:FindFirstChildWhichIsA("AnimationController") then
                    local animator = model:FindFirstChildWhichIsA("Animator", true)
                    if animator then pcall(tfFreezeAnimator, animator) end
                end
            end
            if os.clock() - t0 > TimeFreeze.PriorityBudget then return end
        end
    end
end

local function tfLockNearbyAnchored()
    if not HRP then return end
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Character}
    params.MaxParts = TimeFreeze.LockMax
    local myRoot = HRP.AssemblyRootPart
    for _, radius in ipairs(TimeFreeze.LockRadii) do
        if TimeFreeze.LockCount >= TimeFreeze.LockMax then break end
        for _, part in ipairs(Workspace:GetPartBoundsInRadius(HRP.Position, radius, params)) do
            if part.Anchored and not part:IsA("Terrain") and part.AssemblyRootPart ~= myRoot then
                tfLock(part)
            end
        end
    end
end

function TimeFreeze.Start()
    if TimeFreeze.Active then return end
    tfFlushRelease()
    TimeFreeze.Active = true

    -- 1) outros jogadores primeiro (o que mais aparece na tela)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Player and plr.Character then
            for _, d in ipairs(plr.Character:GetDescendants()) do
                pcall(tfProcess, d)
            end
        end
    end

    -- 1.5) tudo que está perto de você, instantâneo (anéis de raio crescente)
    pcall(TimeFreeze.PriorityPass)

    -- 2) sons do jogo (SoundService)
    for _, d in ipairs(SoundService:GetDescendants()) do
        if d:IsA("Sound") then pcall(tfFreezeSound, d) end
    end

    -- 2.5) peças ANCORADAS próximas: trava o CFrame (movimentos feitos pelo servidor)
    pcall(tfLockNearbyAnchored)

    -- 3) resto do mundo, em fatias de tempo (sem travar a ativação).
    --    Nos primeiros frames o orçamento é maior, então o mundo inteiro para quase de imediato.
    local list = Workspace:GetDescendants()
    local idx, n, frame = 1, #list, 0
    TimeFreeze.ScanConn = RunService.Heartbeat:Connect(function()
        frame += 1
        local budget = (frame <= TimeFreeze.FastScanFrames) and TimeFreeze.FastScanBudget or TimeFreeze.ScanBudget
        local t0 = os.clock()
        while idx <= n do
            local inst = list[idx]
            idx += 1
            if inst.Parent then pcall(tfProcess, inst) end
            if idx % 64 == 0 and os.clock() - t0 > budget then return end
        end
        if TimeFreeze.ScanConn then
            TimeFreeze.ScanConn:Disconnect()
            TimeFreeze.ScanConn = nil
        end
        if TimeFreeze.Debug then
            local function count(t) local c = 0 for _ in pairs(t) do c += 1 end return c end
            print(string.format("[TimeFreeze] varridas %d instâncias em %d frames | peças soltas ancoradas: %d | CFrame travado: %d | animações: %d | partículas: %d | rastros: %d | beams: %d | props travadas: %d | sons pausados: %d",
                n, frame, count(TimeFreeze.Parts), TimeFreeze.LockCount, count(TimeFreeze.Anims), count(TimeFreeze.Emitters), count(TimeFreeze.Trails), count(TimeFreeze.Beams), count(TimeFreeze.Props), count(TimeFreeze.Sounds)))
        end
    end)

    -- 3.5) o que NASCE depois de ativar também congela (projéteis, jogadores que entram,
    --      sons novos, efeitos do jogo). Clones/efeitos deste script são ignorados.
    if TimeFreeze.FreezeNew then
        TimeFreeze.AddedConn = Workspace.DescendantAdded:Connect(function(inst)
            task.defer(function()
                if not TimeFreeze.Active or not inst.Parent then return end
                if TimeFreeze.IsIgnored(inst) then return end
                if inst:IsA("Sound") then
                    pcall(tfFreezeSound, inst, true)
                else
                    pcall(tfProcess, inst)
                end
            end)
        end)
    end

    -- 3.8) VFX/imagens/decals/luzes/GUIs: desfaz qualquer mudança vinda de script/tween do jogo
    TimeFreeze.PropIndex = 1
    TimeFreeze.PropConn = RunService.RenderStepped:Connect(function()
        local list = TimeFreeze.PropEnforce
        local n = #list
        if n == 0 then return end
        local t0 = os.clock()
        local checked = 0
        local i = TimeFreeze.PropIndex
        while checked < n do
            if i > n then i = 1 end
            local inst = list[i]
            local rec = TimeFreeze.Props[inst]
            if rec and inst.Parent then pcall(TimeFreeze.EnforceProps, inst, rec) end
            i += 1
            checked += 1
            if checked % 32 == 0 and os.clock() - t0 > TimeFreeze.PropBudget then break end
        end
        TimeFreeze.PropIndex = i
    end)

    -- 4) o que entrou NÃO sai: uma ronda circular religa o congelamento de qualquer
    --    peça/animação/partícula/som que o jogo tente soltar.
    TimeFreeze.EnforceIndex = 1
    TimeFreeze.EnforceConn = RunService.Heartbeat:Connect(function()
        local list = TimeFreeze.Enforce
        local n = #list
        if n == 0 then return end
        local t0 = os.clock()
        local checked = 0
        local i = TimeFreeze.EnforceIndex
        while checked < n do
            if i > n then i = 1 end
            local e = list[i]
            local kind, inst = e[1], e[2]
            if kind == "part" then
                if inst.Parent and not inst.Anchored then inst.Anchored = true end
            elseif kind == "emitter" then
                if inst.Parent and inst.TimeScale ~= 0 then inst.TimeScale = 0 end
            elseif kind == "sound" then
                if inst.Parent and inst.IsPlaying then inst:Pause() end
            elseif kind == "trail" then
                if inst.Parent and inst.Lifetime < TimeFreeze.TrailFrozenLifetime then inst.Lifetime = TimeFreeze.TrailFrozenLifetime end
            elseif kind == "beam" then
                if inst.Parent and inst.TextureSpeed ~= 0 then inst.TextureSpeed = 0 end
            elseif kind == "video" then
                if inst.Parent and inst.Playing then inst:Pause() end
            elseif kind == "anim" then
                if inst.IsPlaying and inst.Speed ~= 0 then inst:AdjustSpeed(0) end
            end
            i += 1
            checked += 1
            if checked % 32 == 0 and os.clock() - t0 > TimeFreeze.EnforceBudget then break end
        end
        TimeFreeze.EnforceIndex = i
    end)
end

function TimeFreeze.Stop()
    if not TimeFreeze.Active then return end
    TimeFreeze.Active = false

    if TimeFreeze.ScanConn then TimeFreeze.ScanConn:Disconnect() TimeFreeze.ScanConn = nil end
    if TimeFreeze.EnforceConn then TimeFreeze.EnforceConn:Disconnect() TimeFreeze.EnforceConn = nil end
    if TimeFreeze.AddedConn then TimeFreeze.AddedConn:Disconnect() TimeFreeze.AddedConn = nil end
    if TimeFreeze.PropConn then TimeFreeze.PropConn:Disconnect() TimeFreeze.PropConn = nil end
    TimeFreeze.Enforce = {}
    TimeFreeze.EnforceIndex = 1
    for _, c in pairs(TimeFreeze.Locks) do c:Disconnect() end
    TimeFreeze.Locks = {}
    TimeFreeze.LockCount = 0
    for _, c in ipairs(TimeFreeze.Conns) do c:Disconnect() end
    TimeFreeze.Conns = {}
    for _, c in pairs(TimeFreeze.AnimatorConns) do c:Disconnect() end
    TimeFreeze.AnimatorConns = {}

    -- monta a fila de restauração: sons -> animações -> partículas -> peças (perto de mim primeiro)
    local queue = {}
    for snd in pairs(TimeFreeze.Sounds) do table.insert(queue, {"sound", snd}) end
    for track, speed in pairs(TimeFreeze.Anims) do table.insert(queue, {"anim", track, speed}) end
    for em, ts in pairs(TimeFreeze.Emitters) do table.insert(queue, {"emitter", em, ts}) end
    for tr, lt in pairs(TimeFreeze.Trails) do table.insert(queue, {"trail", tr, lt}) end
    for bm, sp in pairs(TimeFreeze.Beams) do table.insert(queue, {"beam", bm, sp}) end
    for vd, was in pairs(TimeFreeze.Videos) do table.insert(queue, {"video", vd, was}) end
    for inst, rec in pairs(TimeFreeze.Props) do
        if next(rec.want) ~= nil then table.insert(queue, {"props", inst, rec.want}) end
    end

    local origin = HRP and HRP.Position or Vector3.zero
    local partList = {}
    for part in pairs(TimeFreeze.Parts) do
        if part.Parent then
            table.insert(partList, {"part", part, (part.Position - origin).Magnitude})
        end
    end
    table.sort(partList, function(a, b) return a[3] < b[3] end)
    for _, e in ipairs(partList) do table.insert(queue, e) end

    TimeFreeze.Sounds, TimeFreeze.Anims, TimeFreeze.Emitters, TimeFreeze.Parts = {}, {}, {}, {}
    TimeFreeze.Trails, TimeFreeze.Beams, TimeFreeze.Videos = {}, {}, {}
    TimeFreeze.Props, TimeFreeze.PropEnforce, TimeFreeze.PropIndex, TimeFreeze.PropPartCount = {}, {}, 1, 0
    TimeFreeze.Queue = queue
    TimeFreeze.QueueIndex = 1

    -- solta em lotes: nunca gasta mais que ReleaseBudget por frame
    TimeFreeze.ReleaseConn = RunService.Heartbeat:Connect(function()
        local q = TimeFreeze.Queue
        if not q then return end
        local t0 = os.clock()
        local total = #q
        local i = TimeFreeze.QueueIndex
        while i <= total do
            pcall(tfRestoreEntry, q[i])
            q[i] = false
            i += 1
            if i % 16 == 0 and os.clock() - t0 > TimeFreeze.ReleaseBudget then break end
        end
        TimeFreeze.QueueIndex = i
        if i > total then
            TimeFreeze.ReleaseConn:Disconnect()
            TimeFreeze.ReleaseConn = nil
            TimeFreeze.Queue = nil
            TimeFreeze.QueueIndex = 1
        end
    end)
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
    TimeFreeze.Stop()
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

    -- Remove a segunda camada do filtro
    local sandiEffect2 = Lighting:FindFirstChild("SandiEffect2")
    if sandiEffect2 then
        TweenService:Create(sandiEffect2, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            TintColor = Color3.new(1,1,1),
            Contrast = 0,
            Saturation = 0,
            Brightness = 0
        }):Play()
        task.delay(0.5, function() sandiEffect2:Destroy() end)
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
    if math.random() < PsyBar.FailChance("Sandi") then TriggerSandevistanFailure() return end
    
    SandiLockTime = os.clock() + 3
    LastSandiActivationTime = os.clock()
    
    State.Energy -= Constants.ENERGY_COSTS.SANDI_ACTIVATE
    State.Energy = math.max(0, State.Energy)
    State.NoRegenUntil = os.clock() + Constants.REGEN_DELAY_USE
    State.IsSandiActive = true
    PsyBar.Add(PsyBar.GAIN_ACTIVATE * (1 + PsyBar.SPAM_GAIN_STEP * math.min(PsyBar.RecentUses(), 5)))
    table.insert(PsyBar.Recent, os.clock())
    Falar("sandi_on")
    TimeFreeze.Start()
    
    -- Áudio
    task.spawn(function() pcall(PlaySFX, Sounds.SANDI_ON) end)
    
    -- MICRO-PAUSA DRAMÁTICA: o mundo já congelou; a câmera "aperta" (FOV fecha) e um flash
    -- branco curto marca o instante. Só depois a câmera estoura pro FOV 115, o shake bate
    -- e o filtro verde entra. Não mexe em nenhum relógio/velocidade do jogo.
    local MICRO_PAUSE = 0.12
    local baseFov = Camera.FieldOfView
    TweenService:Create(Camera, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        FieldOfView = baseFov - 10
    }):Play()
    
    local sandiEffect = Create("ColorCorrectionEffect", {
        Name = "SandiEffect",
        TintColor = Color3.new(1,1,1),
        Contrast = 0,
        Saturation = -0.4,
        Brightness = 0.3,
        Parent = Lighting
    })
    TweenService:Create(sandiEffect, TweenInfo.new(MICRO_PAUSE), {Brightness = 0}):Play()

    -- SEGUNDA CAMADA do filtro: empilha sobre o verde principal, escurece levemente
    -- e puxa pro ciano/verde-água, dando profundidade (vinheta de cor + contraste extra).
    local old2 = Lighting:FindFirstChild("SandiEffect2")
    if old2 then old2:Destroy() end
    local sandiEffect2 = Create("ColorCorrectionEffect", {
        Name = "SandiEffect2",
        TintColor = Color3.new(1,1,1),
        Contrast = 0,
        Saturation = 0,
        Brightness = 0,
        Parent = Lighting
    })

    task.delay(MICRO_PAUSE, function()
        if not State.IsSandiActive then return end
        task.spawn(function() pcall(CamShake, 1.5, 0.4) end)
        TweenService:Create(Camera, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            FieldOfView = 115
        }):Play()
        if sandiEffect.Parent then
            TweenService:Create(sandiEffect, TweenInfo.new(0.4), {
                TintColor = Color3.fromRGB(85, 255, 127),
                Contrast = 0.5,
                Saturation = 0.25
            }):Play()
        end
        if sandiEffect2.Parent then
            TweenService:Create(sandiEffect2, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                TintColor = Color3.fromRGB(170, 255, 235),
                Contrast = 0.2,
                Saturation = 0.15,
                Brightness = -0.06
            }):Play()
        end
    end)
    
    -- ========== ANIMAÇÃO DE ATIVAÇÃO (TEXTURAS) ==========
    -- Primeiro toca a animação
    PlayActivationSequence()
    -- (ScreenFade verde removido: o filtro agora é igual ao do script mobile)
    
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
            local __o = (getgenv and getgenv() or _G); vpf.Visible = not (__o.SandiVPOccluded and __o.SandiVPOccluded(__o.SandiVPBodyPoints(Character:FindFirstChild("HumanoidRootPart"))))
            
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
        if hum:IsA("Humanoid") and hum ~= Humanoid and not (hum.Parent and hum.Parent.Name == "PhaseGhost") then
            originalWalkSpeeds[hum] = hum.WalkSpeed
            hum.WalkSpeed = hum.WalkSpeed * Constants.SLOW_FACTOR
        end
    end
    
    UpdateDashButton()
    UpdateKiroshiButton()
    UpdateOpticalButton()
    State.MusicSound = tocarMusica()
    -- (mudança de ClockTime removida: o script mobile não altera o horário)
end

-- ========== ANIMAÇÕES DO DASH (estilo Battlegrounds) ==========
-- Procedural: mexe nos Motor6D (C0), então funciona em R6 e R15 sem precisar de asset de animação.
-- Poses: Front (dash pra frente), Back (dash pra trás), Air (dash no ar).
-- Valores em graus {X, Y, Z} no espaço da Part0 do joint. X+ = balança pra frente, X- = pra trás.
local DASH_ANIM = {
    IN_TIME = 0.06,    -- tempo pra entrar na pose
    HOLD_TIME = 0.14,  -- tempo segurando a pose
    OUT_TIME = 0.16,   -- tempo voltando ao normal
}

local DASH_POSES = {
    Front = {
        Root = {-18, 0, 0}, Waist = {-6, 4, 0}, Neck = {10, 0, 0},
        LArm = {70, 0, -6},  RArm = {25, 0, 10},
        LElbow = {55, 0, 0}, RElbow = {75, 0, 0},
        LLeg = {38, 0, 0},   RLeg = {-34, 0, 0},
        LKnee = {-12, 0, 0}, RKnee = {-65, 0, 0},
    },
    Back = {
        Root = {24, 0, 0}, Waist = {6, 0, 0}, Neck = {-16, 0, 0},
        LArm = {55, 0, -22}, RArm = {55, 0, 22},
        LLeg = {26, 0, 0},   RLeg = {-12, 0, 0},
        LKnee = {-4, 0, 0},  RKnee = {-40, 0, 0},
    },
    Air = {
        Root = {-80, 0, 0}, Waist = {-6, 0, 0}, Neck = {55, 0, 0},
        LArm = {150, 0, -10}, RArm = {150, 0, 10},
        LLeg = {-10, 0, -4},  RLeg = {-18, 0, 4},
        LKnee = {-30, 0, 0},  RKnee = {-45, 0, 0},
    },
}

local function dashGetJoints()
    local j = {}
    if not Character or not Humanoid then return j end
    local function J(partName, jointName)
        local p = Character:FindFirstChild(partName)
        return p and p:FindFirstChild(jointName)
    end
    if Humanoid.RigType == Enum.HumanoidRigType.R15 then
        j.Root  = J("LowerTorso", "Root")
        j.Waist = J("UpperTorso", "Waist")
        j.Neck  = J("Head", "Neck")
        j.LArm  = J("LeftUpperArm", "LeftShoulder")
        j.RArm  = J("RightUpperArm", "RightShoulder")
        j.LLeg  = J("LeftUpperLeg", "LeftHip")
        j.RLeg  = J("RightUpperLeg", "RightHip")
        j.LElbow = J("LeftLowerArm", "LeftElbow")
        j.RElbow = J("RightLowerArm", "RightElbow")
        j.LKnee = J("LeftLowerLeg", "LeftKnee")
        j.RKnee = J("RightLowerLeg", "RightKnee")
    else
        j.Root = HRP and HRP:FindFirstChild("RootJoint")
        j.Neck = J("Torso", "Neck")
        j.LArm = J("Torso", "Left Shoulder")
        j.RArm = J("Torso", "Right Shoulder")
        j.LLeg = J("Torso", "Left Hip")
        j.RLeg = J("Torso", "Right Hip")
    end
    for name, joint in pairs(j) do
        if not (joint and joint:IsA("Motor6D")) then j[name] = nil end
    end
    return j
end

local function dashApplyPose(joints, base, pose, alpha)
    for name, joint in pairs(joints) do
        local c0 = base[name]
        local r = pose and pose[name]
        if r then
            local rot = CFrame.Angles(math.rad(r[1] * alpha), math.rad(r[2] * alpha), math.rad(r[3] * alpha))
            -- gira em volta do pivô do joint (mantém a posição, só rotaciona)
            joint.C0 = CFrame.new(c0.Position) * rot * (c0 - c0.Position)
        else
            joint.C0 = c0
        end
    end
end

local DashAnimState = {Token = 0, Joints = nil, Base = nil, AutoRotate = nil}

local function dashRestore()
    if DashAnimState.Joints and DashAnimState.Base then
        for name, joint in pairs(DashAnimState.Joints) do
            if joint and joint.Parent and DashAnimState.Base[name] then
                joint.C0 = DashAnimState.Base[name]
            end
        end
    end
    if DashAnimState.AutoRotate ~= nil and Humanoid and Humanoid.Parent then
        Humanoid.AutoRotate = DashAnimState.AutoRotate
    end
    DashAnimState.Joints, DashAnimState.Base, DashAnimState.AutoRotate = nil, nil, nil
end

-- kind: "Front" | "Back" | "Air"; direction: Vector3 unitário do dash
local function PlayDashAnim(kind, direction)
    if not Character or not Humanoid or not HRP then return end
    dashRestore() -- cancela animação anterior, se tiver

    local joints = dashGetJoints()
    if not joints.Root then return end

    DashAnimState.Token += 1
    local token = DashAnimState.Token

    local base = {}
    for name, joint in pairs(joints) do base[name] = joint.C0 end
    DashAnimState.Joints, DashAnimState.Base = joints, base

    -- copia a pose pra poder ajustar a inclinação conforme a direção (dash no ar)
    local pose = {}
    for k, v in pairs(DASH_POSES[kind]) do pose[k] = {v[1], v[2], v[3]} end

    DashAnimState.AutoRotate = Humanoid.AutoRotate
    Humanoid.AutoRotate = false -- evita o boneco girar sozinho durante o dash

    if kind == "Air" then
        local flat = Vector3.new(direction.X, 0, direction.Z)
        if flat.Magnitude > 0.05 then
            HRP.CFrame = CFrame.lookAt(HRP.Position, HRP.Position + flat)
        end
        -- cabeça aponta na direção do dash (subindo ou descendo)
        local elev = math.deg(math.asin(math.clamp(direction.Y, -1, 1)))
        pose.Root[1] = -math.clamp(80 - elev, 25, 110)
    end

    -- reduz o peso das animações normais (andar/cair) pra não brigar com a pose
    local dimmed = {}
    local animator = Humanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() tr:AdjustWeight(0.05, 0.05) end)
            table.insert(dimmed, tr)
        end
    end

    task.spawn(function()
        local t0 = os.clock()
        local total = DASH_ANIM.IN_TIME + DASH_ANIM.HOLD_TIME + DASH_ANIM.OUT_TIME
        while true do
            if DashAnimState.Token ~= token then return end -- outro dash assumiu
            local t = os.clock() - t0
            if t >= total or not Character or not Character.Parent then break end

            local alpha
            if t < DASH_ANIM.IN_TIME then
                local x = t / DASH_ANIM.IN_TIME
                alpha = 1 - (1 - x) ^ 3                              -- ease-out
            elseif t < DASH_ANIM.IN_TIME + DASH_ANIM.HOLD_TIME then
                alpha = 1
            else
                local x = (t - DASH_ANIM.IN_TIME - DASH_ANIM.HOLD_TIME) / DASH_ANIM.OUT_TIME
                alpha = 1 - x * x                                     -- ease-in
            end
            dashApplyPose(joints, base, pose, alpha)
            RunService.RenderStepped:Wait()
        end

        if DashAnimState.Token == token then
            dashRestore()
            for _, tr in ipairs(dimmed) do
                pcall(function() if tr.IsPlaying then tr:AdjustWeight(1, 0.1) end end)
            end
        end
    end)
end
-- ========== FIM DAS ANIMAÇÕES DO DASH ==========

-- ========== ANIMAÇÕES DO DASH POR KEYFRAMES (Swavi Dash System) + DASH ESQUERDA/DIREITA ==========
-- Os keyframes (Dash1 / Dash2 / BackDash / DashLeft / DashRight) estão EMBUTIDOS aqui:
-- não precisa publicar animação nem ter arquivo extra. Roda 100% no cliente, movendo os
-- Motor6D (Transform) do seu personagem R6 a cada frame. Em R15 (ou se algo falhar) cai
-- automaticamente na animação procedural antiga.
local GetGroundDashKind

do
local DashClips = {
    Enabled = true,
    Speed = 1.4,      -- 1 = velocidade original da animação (0.5s); maior = mais rápida
    FadeIn = 0.04,
    FadeOut = 0.1,
    NextFront = 1,    -- alterna Dash1 / Dash2 no dash pra frente
    Built = nil,
    Playing = {},
    Motors = {},
    MotorChar = nil,
    AutoRotateSaved = nil,
    Conn = nil,
    Warned = false,
    -- As animações são baixadas do GitHub (1x) e salvas na pasta "workspace" do executor.
    -- Se o download falhar, usa os keyframes embutidos abaixo como reserva.
    UseGithub = true,
    GithubUrl = "https://github.com/hatsunemiku51111-cloud/SCRIPT/raw/refs/heads/main/dash_system_probably_working__1_.rbxm",
    FileName = "dash_system_probably_working__1_.rbxm",
}

local DASH_CLIP_DATA = {
	Dash1 = {len = 0.5, parts = {
		Head = {0,0,0,0,0,0,0,1,0.017,0,0,0,-0.02589,0.00078,0.00536,0.99965,0.033,0,0,0,-0.09562,0.00244,0.02011,0.99521,0.05,0,0,0,-0.19632,0.00385,0.04204,0.97963,0.067,0,0,0,-0.31131,0.00383,0.06816,0.94785,0.083,0,0,0,-0.42177,0.00124,0.09495,0.90172,0.1,0,0,0,-0.51221,-0.00483,0.11948,0.8505,0.117,0,0,0,-0.5758,-0.01487,0.14068,0.80526,0.133,0,0,0,-0.61684,-0.02811,0.15972,0.7702,0.15,0,0,0,-0.64022,-0.04366,0.17799,0.74601,0.167,0,0,0,-0.64906,-0.06079,0.19657,0.73239,0.183,0,0,0,-0.64501,-0.07872,0.21632,0.72868,0.2,0,0,0,-0.62874,-0.09659,0.23788,0.73401,0.217,0,0,0,-0.60029,-0.11324,0.26163,0.74725,0.233,0,0,0,-0.5595,-0.12724,0.28761,0.76684,0.25,0,0,0,-0.50914,-0.13733,0.31419,0.78943,0.267,0,0,0,-0.46396,-0.14433,0.33455,0.80746,0.283,0,0,0,-0.44337,-0.15017,0.34178,0.8149,0.3,0,0,0,-0.44189,-0.15689,0.3387,0.81572,0.317,0,0,0,-0.44112,-0.16482,0.33282,0.81699,0.333,0,0,0,-0.44093,-0.17351,0.32484,0.81851,0.35,0,0,0,-0.44123,-0.18249,0.31544,0.82007,0.367,0,0,0,-0.44195,-0.19132,0.30535,0.82149,0.383,0,0,0,-0.44301,-0.19952,0.29529,0.82264,0.4,0,0,0,-0.44439,-0.20664,0.28602,0.82341,0.417,0,0,0,-0.44606,-0.21222,0.27833,0.82373,0.433,0,0,0,-0.44799,-0.21578,0.273,0.82353,0.45,0,0,0,-0.45018,-0.21688,0.27082,0.82277,0.467,0,0,0,-0.45299,-0.21587,0.2706,0.82157,0.483,0,0,0,-0.45671,-0.21355,0.27061,0.82011,0.5,0,0,0,-0.46116,-0.21011,0.27082,0.81844},
		["Left Arm"] = {0,0,0,0,0,0,0,1,0.017,-0.0387,0.009,-0.0015,-0.00025,0.00442,-0.06604,0.99781,0.033,-0.1397,0.0581,-0.003,-0.00308,0.01605,-0.24459,0.96949,0.05,-0.2528,0.1842,-0.0005,-0.01172,0.03102,-0.48546,0.87363,0.067,-0.3071,0.3622,0.0036,-0.02804,0.04308,-0.70005,0.71224,0.083,-0.302,0.5188,0.0038,-0.05284,0.04847,-0.83434,0.54657,0.1,-0.2877,0.6282,0.0005,-0.08862,0.04767,-0.90156,0.42078,0.117,-0.2871,0.7093,-0.0022,-0.13608,0.04255,-0.93366,0.32856,0.133,-0.3032,0.7757,-0.0002,-0.19551,0.03383,-0.94579,0.25712,0.15,-0.3332,0.8338,0.0108,-0.26594,0.02167,-0.9431,0.1984,0.167,-0.3704,0.8873,0.0325,-0.34263,0.00652,-0.92767,0.1483,0.183,-0.4049,0.9381,0.0605,-0.41491,-0.01007,-0.90359,0.10616,0.2,-0.4285,0.986,0.0834,-0.46971,-0.02549,-0.87936,0.07385,0.217,-0.4426,1.027,0.0959,-0.50474,-0.03829,-0.86078,0.05324,0.233,-0.4508,1.0578,0.0988,-0.52324,-0.04804,-0.84969,0.04394,0.25,-0.456,1.0766,0.0949,-0.5295,-0.05487,-0.84538,0.04418,0.267,-0.4597,1.0821,0.0879,-0.52753,-0.05913,-0.84589,0.05191,0.283,-0.4632,1.0739,0.0809,-0.52075,-0.06125,-0.84901,0.06526,0.3,-0.4672,1.054,0.0761,-0.512,-0.06169,-0.85281,0.08225,0.317,-0.4722,1.0248,0.0754,-0.50402,-0.06089,-0.85561,0.10089,0.333,-0.4793,0.9888,0.0806,-0.49963,-0.05926,-0.85594,0.11925,0.35,-0.4894,0.9481,0.0939,-0.50172,-0.05719,-0.85246,0.13532,0.367,-0.5024,0.905,0.1162,-0.51198,-0.05504,-0.84444,0.14755,0.383,-0.5164,0.8611,0.1445,-0.52747,-0.05302,-0.83339,0.15626,0.4,-0.5292,0.8183,0.1743,-0.54429,-0.05128,-0.82145,0.16229,0.417,-0.5393,0.7782,0.2008,-0.55876,-0.04998,-0.81091,0.16651,0.433,-0.5459,0.7425,0.2194,-0.5675,-0.04931,-0.80416,0.16983,0.45,-0.5487,0.7125,0.2266,-0.56812,-0.04937,-0.80304,0.17298,0.467,-0.548,0.6881,0.2236,-0.56163,-0.05011,-0.80691,0.17595,0.483,-0.5443,0.6689,0.2128,-0.54971,-0.05139,-0.81443,0.17853,0.5,-0.5379,0.6545,0.1965,-0.53401,-0.05309,-0.82428,0.18049},
		["Left Leg"] = {0,0.0179,-0.0121,-0.0005,0.01382,0.01668,0.09776,0.99497,0.017,0.0225,-0.0347,0.0037,0.01332,0.02032,0.09717,0.99497,0.033,0.0347,-0.0941,0.0149,0.01194,0.03021,0.09561,0.99489,0.05,0.0521,-0.1781,0.0309,0.00989,0.0448,0.09339,0.99457,0.067,0.0723,-0.2744,0.0494,0.00736,0.06254,0.09081,0.99388,0.083,0.093,-0.3705,0.0685,0.00456,0.08187,0.08819,0.99272,0.1,0.1117,-0.4541,0.0863,0.00169,0.10123,0.08584,0.99115,0.117,0.1266,-0.5152,0.1014,-0.00108,0.11934,0.08403,0.98929,0.133,0.1375,-0.5532,0.114,-0.00372,0.13601,0.0828,0.98724,0.15,0.1449,-0.5702,0.1241,-0.00623,0.15128,0.08207,0.98506,0.167,0.1491,-0.5682,0.1321,-0.0086,0.16523,0.08181,0.98282,0.183,0.1504,-0.5489,0.1381,-0.01084,0.17791,0.08197,0.98057,0.2,0.1493,-0.5146,0.1423,-0.01294,0.18938,0.08249,0.97835,0.217,0.1461,-0.467,0.145,-0.0149,0.19972,0.08333,0.97619,0.233,0.1413,-0.4083,0.1463,-0.01673,0.20897,0.08443,0.97413,0.25,0.1351,-0.3403,0.1463,-0.01842,0.21719,0.08575,0.97218,0.267,0.128,-0.2651,0.1452,-0.01998,0.22444,0.08723,0.97037,0.283,0.1204,-0.1847,0.1431,-0.02139,0.23077,0.08882,0.96871,0.3,0.1125,-0.101,0.1402,-0.02266,0.23623,0.09047,0.96721,0.317,0.1048,-0.0161,0.1366,-0.02379,0.24087,0.09212,0.96588,0.333,0.0977,0.0681,0.1324,-0.02478,0.24474,0.09373,0.96473,0.35,0.0914,0.1495,0.1277,-0.02562,0.24789,0.09525,0.96375,0.367,0.0864,0.2262,0.1226,-0.02632,0.25036,0.0966,0.96296,0.383,0.0829,0.2962,0.1173,-0.02686,0.25221,0.09775,0.96235,0.4,0.0815,0.3574,0.1119,-0.02725,0.25347,0.09864,0.96191,0.417,0.0823,0.4079,0.1063,-0.02749,0.25419,0.09922,0.96166,0.433,0.0858,0.4456,0.1009,-0.02757,0.25443,0.09942,0.96157,0.45,0.0923,0.4694,0.0954,-0.02757,0.25443,0.09942,0.96157,0.467,0.1018,0.4804,0.09,-0.02757,0.25443,0.09942,0.96157,0.483,0.1137,0.48,0.0845,-0.02757,0.25443,0.09942,0.96157,0.5,0.1276,0.4699,0.0791,-0.02757,0.25443,0.09942,0.96157},
		["Right Arm"] = {0,0,0,0,0,0,0,1,0.017,-0.0041,-0.0255,0.0061,-0.00582,-0.02751,-0.01267,0.99952,0.033,-0.0155,-0.0943,0.0278,-0.02086,-0.10023,-0.04526,0.99372,0.05,-0.0367,-0.1948,0.0717,-0.04111,-0.20173,-0.08889,0.97453,0.067,-0.0726,-0.3113,0.1375,-0.06178,-0.31187,-0.13304,0.93873,0.083,-0.1219,-0.4239,0.213,-0.07828,-0.41082,-0.16756,0.89276,0.1,-0.1726,-0.5163,0.2826,-0.08799,-0.48734,-0.1867,0.84847,0.117,-0.2164,-0.5873,0.3416,-0.0919,-0.54446,-0.19288,0.81112,0.133,-0.2493,-0.6393,0.3901,-0.09148,-0.58699,-0.18954,0.78176,0.15,-0.2699,-0.675,0.4291,-0.08781,-0.61839,-0.17933,0.76008,0.167,-0.2787,-0.6965,0.4593,-0.08177,-0.64099,-0.16442,0.74526,0.183,-0.2767,-0.7062,0.4812,-0.07411,-0.65635,-0.14676,0.73632,0.2,-0.266,-0.7063,0.4954,-0.0656,-0.66561,-0.12835,0.73225,0.217,-0.2488,-0.6998,0.5022,-0.05705,-0.66967,-0.11134,0.73205,0.233,-0.2277,-0.6895,0.5021,-0.04937,-0.66942,-0.09809,0.73472,0.25,-0.205,-0.6784,0.4958,-0.04337,-0.66569,-0.09063,0.73943,0.267,-0.1818,-0.6675,0.4841,-0.03917,-0.65887,-0.08883,0.74597,0.283,-0.1588,-0.6571,0.4675,-0.03669,-0.64914,-0.09192,0.75421,0.3,-0.1371,-0.6473,0.447,-0.03579,-0.63667,-0.09904,0.76392,0.317,-0.1176,-0.638,0.4233,-0.03632,-0.6216,-0.10929,0.77482,0.333,-0.1015,-0.6293,0.3973,-0.03813,-0.60411,-0.12174,0.78663,0.35,-0.0896,-0.6212,0.3701,-0.04104,-0.58436,-0.13544,0.79906,0.367,-0.0827,-0.6137,0.3423,-0.04487,-0.56255,-0.14947,0.8119,0.383,-0.0815,-0.6073,0.315,-0.04945,-0.53892,-0.16292,0.82497,0.4,-0.0869,-0.6023,0.289,-0.05463,-0.51369,-0.17494,0.83817,0.417,-0.0992,-0.5994,0.2648,-0.06024,-0.48708,-0.18472,0.85147,0.433,-0.1191,-0.5992,0.243,-0.06615,-0.45929,-0.19147,0.86488,0.45,-0.1427,-0.6002,0.2238,-0.07221,-0.43063,-0.19466,0.87832,0.467,-0.1653,-0.6005,0.2071,-0.07818,-0.40204,-0.1947,0.89126,0.483,-0.1861,-0.6002,0.1932,-0.0838,-0.37474,-0.19224,0.9031,0.5,-0.2042,-0.5998,0.1823,-0.08882,-0.34998,-0.18793,0.9134},
		["Right Leg"] = {0,0,0,0,0,0,0,1,0.017,0.014,0.0505,-0.0142,-0.00912,-0.00448,0.00896,0.99991,0.033,0.0511,0.1855,-0.0533,-0.03338,-0.01645,0.03311,0.99876,0.05,0.1033,0.3793,-0.1123,-0.068,-0.0337,0.06828,0.99478,0.067,0.1635,0.606,-0.1857,-0.10788,-0.05381,0.10993,0.9866,0.083,0.2261,0.84,-0.2661,-0.14762,-0.07426,0.15326,0.97427,0.1,0.2865,1.0571,-0.3444,-0.18207,-0.09259,0.19362,0.95958,0.117,0.3416,1.2396,-0.4118,-0.20751,-0.10705,0.22768,0.94533,0.133,0.3914,1.3872,-0.466,-0.22421,-0.11772,0.25548,0.93306,0.15,0.4363,1.5038,-0.5072,-0.23328,-0.12506,0.27782,0.92345,0.167,0.4768,1.5924,-0.536,-0.23573,-0.1295,0.2954,0.91674,0.183,0.513,1.656,-0.5535,-0.23236,-0.13138,0.30879,0.9129,0.2,0.5451,1.6969,-0.5608,-0.2239,-0.13097,0.31847,0.91175,0.217,0.5736,1.7173,-0.5591,-0.21096,-0.12852,0.32478,0.91296,0.233,0.5986,1.7193,-0.5497,-0.19409,-0.12423,0.32802,0.91613,0.25,0.6204,1.705,-0.5339,-0.17384,-0.11829,0.32843,0.92083,0.267,0.6391,1.6762,-0.5131,-0.15078,-0.11088,0.32622,0.92658,0.283,0.6551,1.6351,-0.4885,-0.1255,-0.10222,0.32161,0.93293,0.3,0.6683,1.5839,-0.4614,-0.09867,-0.09252,0.31485,0.93945,0.317,0.6788,1.5247,-0.433,-0.071,-0.08203,0.30623,0.94576,0.333,0.6866,1.46,-0.4041,-0.04325,-0.07103,0.29607,0.95154,0.35,0.6918,1.3921,-0.3755,-0.01622,-0.0598,0.28475,0.9566,0.367,0.6944,1.3236,-0.3477,0.00928,-0.04866,0.27271,0.96082,0.383,0.6946,1.2572,-0.3212,0.03244,-0.03792,0.2604,0.96421,0.4,0.6926,1.1952,-0.2962,0.05249,-0.02789,0.24828,0.96686,0.417,0.6888,1.1404,-0.2729,0.0687,-0.01885,0.23686,0.96893,0.433,0.6835,1.0952,-0.2513,0.08034,-0.01111,0.22658,0.97061,0.45,0.6772,1.0616,-0.2315,0.08697,-0.00485,0.21783,0.97209,0.467,0.6703,1.0389,-0.2134,0.08895,-0.00001,0.21058,0.97352,0.483,0.6629,1.0261,-0.1968,0.0869,0.00356,0.20471,0.97495,0.5,0.6553,1.0219,-0.1817,0.08139,0.00601,0.20009,0.97637},
		Torso = {0,-0.0032,-0.6038,-0.2029,0.31846,-0.00416,0.00732,0.9479,0.017,-0.0049,-0.6693,-0.2336,0.341,-0.00348,0.00234,0.94005,0.033,-0.0111,-0.8334,-0.3221,0.39893,-0.00129,-0.0112,0.91691,0.05,-0.0245,-1.0426,-0.4623,0.47658,0.00264,-0.03107,0.87858,0.067,-0.046,-1.2459,-0.6347,0.55722,0.00844,-0.05451,0.82853,0.083,-0.0724,-1.4094,-0.8044,0.62603,0.01614,-0.07867,0.77565,0.1,-0.0981,-1.5252,-0.9394,0.67484,0.02574,-0.10161,0.73048,0.117,-0.1207,-1.6073,-1.0356,0.70642,0.03699,-0.12321,0.69601,0.133,-0.1394,-1.6677,-1.0982,0.72481,0.04965,-0.14373,0.67196,0.15,-0.1533,-1.7128,-1.1327,0.73295,0.06351,-0.16333,0.65732,0.167,-0.1619,-1.7462,-1.1441,0.73293,0.07836,-0.18206,0.65079,0.183,-0.1647,-1.769,-1.1367,0.72629,0.09397,-0.19984,0.65095,0.2,-0.1613,-1.7816,-1.1143,0.7143,0.11004,-0.21645,0.65636,0.217,-0.1518,-1.7838,-1.0807,0.69818,0.12618,-0.23158,0.66558,0.233,-0.1367,-1.7756,-1.0399,0.67924,0.14197,-0.24483,0.67715,0.25,-0.1172,-1.7573,-0.9958,0.65902,0.15691,-0.2558,0.68967,0.267,-0.0951,-1.7299,-0.9525,0.63929,0.1705,-0.26411,0.70177,0.283,-0.0724,-1.6951,-0.9134,0.62171,0.18232,-0.2695,0.71247,0.3,-0.0503,-1.6548,-0.8788,0.60666,0.19232,-0.27223,0.72171,0.317,-0.0295,-1.6104,-0.8484,0.5941,0.20058,-0.27269,0.7297,0.333,-0.0105,-1.5634,-0.8218,0.58391,0.20718,-0.27124,0.73658,0.35,0.0065,-1.5153,-0.7986,0.57593,0.2122,-0.26827,0.7425,0.367,0.021,-1.4671,-0.7786,0.56995,0.21572,-0.26412,0.74757,0.383,0.0331,-1.4202,-0.7613,0.56574,0.21785,-0.25917,0.75187,0.4,0.0426,-1.3757,-0.7465,0.56305,0.21865,-0.25376,0.75549,0.417,0.0495,-1.3346,-0.734,0.56162,0.21822,-0.24822,0.75852,0.433,0.0537,-1.2981,-0.7237,0.56119,0.21664,-0.2429,0.76101,0.45,0.0552,-1.267,-0.7154,0.56153,0.21399,-0.23806,0.76303,0.467,0.0544,-1.2411,-0.709,0.56251,0.21041,-0.23373,0.76464,0.483,0.0514,-1.2199,-0.7042,0.56405,0.20607,-0.22988,0.76586,0.5,0.0467,-1.2031,-0.701,0.56603,0.20109,-0.22648,0.76673},
	}},
	Dash2 = {len = 0.5, parts = {
		Head = {0,0,0,0,0,0,0,1,0.017,0,0,0,-0.02589,-0.00078,-0.00536,0.99965,0.033,0,0,0,-0.09562,-0.00244,-0.02011,0.99521,0.05,0,0,0,-0.19632,-0.00385,-0.04204,0.97963,0.067,0,0,0,-0.31131,-0.00383,-0.06816,0.94785,0.083,0,0,0,-0.42177,-0.00124,-0.09495,0.90172,0.1,0,0,0,-0.51221,0.00483,-0.11948,0.8505,0.117,0,0,0,-0.5758,0.01487,-0.14068,0.80526,0.133,0,0,0,-0.61684,0.02811,-0.15972,0.7702,0.15,0,0,0,-0.64022,0.04366,-0.17799,0.74601,0.167,0,0,0,-0.64906,0.06079,-0.19657,0.73239,0.183,0,0,0,-0.64501,0.07872,-0.21632,0.72868,0.2,0,0,0,-0.62874,0.09659,-0.23788,0.73401,0.217,0,0,0,-0.60029,0.11324,-0.26163,0.74725,0.233,0,0,0,-0.5595,0.12724,-0.28761,0.76684,0.25,0,0,0,-0.50914,0.13733,-0.31419,0.78943,0.267,0,0,0,-0.46396,0.14433,-0.33455,0.80746,0.283,0,0,0,-0.44337,0.15017,-0.34178,0.8149,0.3,0,0,0,-0.44189,0.15689,-0.3387,0.81572,0.317,0,0,0,-0.44112,0.16482,-0.33282,0.81699,0.333,0,0,0,-0.44093,0.17351,-0.32484,0.81851,0.35,0,0,0,-0.44123,0.18249,-0.31544,0.82007,0.367,0,0,0,-0.44195,0.19132,-0.30535,0.82149,0.383,0,0,0,-0.44301,0.19952,-0.29529,0.82264,0.4,0,0,0,-0.44439,0.20664,-0.28602,0.82341,0.417,0,0,0,-0.44606,0.21222,-0.27833,0.82373,0.433,0,0,0,-0.44799,0.21578,-0.273,0.82353,0.45,0,0,0,-0.45018,0.21688,-0.27082,0.82277,0.467,0,0,0,-0.45299,0.21587,-0.2706,0.82157,0.483,0,0,0,-0.45671,0.21355,-0.27061,0.82011,0.5,0,0,0,-0.46116,0.21011,-0.27082,0.81844},
		["Left Arm"] = {0,0,0,0,0,0,0,1,0.017,0.0041,-0.0255,0.0061,-0.00582,0.02751,0.01267,0.99952,0.033,0.0155,-0.0943,0.0278,-0.02086,0.10023,0.04526,0.99372,0.05,0.0367,-0.1948,0.0717,-0.04111,0.20173,0.08889,0.97453,0.067,0.0726,-0.3113,0.1375,-0.06178,0.31187,0.13304,0.93873,0.083,0.1219,-0.4239,0.213,-0.07828,0.41082,0.16756,0.89276,0.1,0.1726,-0.5163,0.2826,-0.08799,0.48734,0.1867,0.84847,0.117,0.2164,-0.5873,0.3416,-0.0919,0.54446,0.19288,0.81112,0.133,0.2493,-0.6393,0.3901,-0.09148,0.58699,0.18954,0.78176,0.15,0.2699,-0.675,0.4291,-0.08781,0.61839,0.17933,0.76008,0.167,0.2787,-0.6965,0.4593,-0.08177,0.64099,0.16442,0.74526,0.183,0.2767,-0.7062,0.4812,-0.07411,0.65635,0.14676,0.73632,0.2,0.266,-0.7063,0.4954,-0.0656,0.66561,0.12835,0.73225,0.217,0.2488,-0.6998,0.5022,-0.05705,0.66967,0.11134,0.73205,0.233,0.2277,-0.6895,0.5021,-0.04937,0.66942,0.09809,0.73472,0.25,0.205,-0.6784,0.4958,-0.04337,0.66569,0.09063,0.73943,0.267,0.1818,-0.6675,0.4841,-0.03917,0.65887,0.08883,0.74597,0.283,0.1588,-0.6571,0.4675,-0.03669,0.64914,0.09192,0.75421,0.3,0.1371,-0.6473,0.447,-0.03579,0.63667,0.09904,0.76392,0.317,0.1176,-0.638,0.4233,-0.03632,0.6216,0.10929,0.77482,0.333,0.1015,-0.6293,0.3973,-0.03813,0.60411,0.12174,0.78663,0.35,0.0896,-0.6212,0.3701,-0.04104,0.58436,0.13544,0.79906,0.367,0.0827,-0.6137,0.3423,-0.04487,0.56255,0.14947,0.8119,0.383,0.0815,-0.6073,0.315,-0.04945,0.53892,0.16292,0.82497,0.4,0.0869,-0.6023,0.289,-0.05463,0.51369,0.17494,0.83817,0.417,0.0992,-0.5994,0.2648,-0.06024,0.48708,0.18472,0.85147,0.433,0.1191,-0.5992,0.243,-0.06615,0.45929,0.19147,0.86488,0.45,0.1427,-0.6002,0.2238,-0.07221,0.43063,0.19466,0.87832,0.467,0.1653,-0.6005,0.2071,-0.07818,0.40204,0.1947,0.89126,0.483,0.1861,-0.6002,0.1932,-0.0838,0.37474,0.19224,0.9031,0.5,0.2042,-0.5998,0.1823,-0.08882,0.34998,0.18793,0.9134},
		["Left Leg"] = {0,0,0,0,0,0,0,1,0.017,-0.014,0.0505,-0.0142,-0.00912,0.00448,-0.00896,0.99991,0.033,-0.0511,0.1855,-0.0533,-0.03338,0.01645,-0.03311,0.99876,0.05,-0.1033,0.3793,-0.1123,-0.068,0.0337,-0.06828,0.99478,0.067,-0.1635,0.606,-0.1857,-0.10788,0.05381,-0.10993,0.9866,0.083,-0.2261,0.84,-0.2661,-0.14762,0.07426,-0.15326,0.97427,0.1,-0.2865,1.0571,-0.3444,-0.18207,0.09259,-0.19362,0.95958,0.117,-0.3416,1.2396,-0.4118,-0.20751,0.10705,-0.22768,0.94533,0.133,-0.3914,1.3872,-0.466,-0.22421,0.11772,-0.25548,0.93306,0.15,-0.4363,1.5038,-0.5072,-0.23328,0.12506,-0.27782,0.92345,0.167,-0.4768,1.5924,-0.536,-0.23573,0.1295,-0.2954,0.91674,0.183,-0.513,1.656,-0.5535,-0.23236,0.13138,-0.30879,0.9129,0.2,-0.5452,1.6969,-0.5608,-0.2239,0.13097,-0.31847,0.91175,0.217,-0.5736,1.7173,-0.5591,-0.21096,0.12852,-0.32478,0.91296,0.233,-0.5986,1.7193,-0.5497,-0.19409,0.12423,-0.32802,0.91613,0.25,-0.6204,1.7049,-0.5339,-0.17384,0.11829,-0.32843,0.92083,0.267,-0.6392,1.6762,-0.5131,-0.15078,0.11088,-0.32622,0.92658,0.283,-0.6551,1.6351,-0.4885,-0.1255,0.10222,-0.32161,0.93293,0.3,-0.6683,1.5839,-0.4614,-0.09867,0.09252,-0.31485,0.93945,0.317,-0.6788,1.5247,-0.433,-0.071,0.08203,-0.30623,0.94576,0.333,-0.6866,1.4599,-0.4041,-0.04325,0.07103,-0.29607,0.95154,0.35,-0.6918,1.3921,-0.3755,-0.01622,0.0598,-0.28475,0.9566,0.367,-0.6944,1.3236,-0.3477,0.00928,0.04866,-0.27271,0.96082,0.383,-0.6946,1.2571,-0.3212,0.03244,0.03792,-0.2604,0.96421,0.4,-0.6926,1.1952,-0.2963,0.05249,0.02789,-0.24828,0.96686,0.417,-0.6888,1.1404,-0.2729,0.0687,0.01885,-0.23686,0.96893,0.433,-0.6835,1.0952,-0.2513,0.08034,0.01111,-0.22658,0.97061,0.45,-0.6772,1.0616,-0.2315,0.08697,0.00485,-0.21783,0.97209,0.467,-0.6703,1.0389,-0.2134,0.08895,0.00001,-0.21058,0.97352,0.483,-0.6629,1.0261,-0.1968,0.0869,-0.00356,-0.20471,0.97495,0.5,-0.6553,1.0219,-0.1817,0.08139,-0.00601,-0.20009,0.97637},
		["Right Arm"] = {0,0,0,0,0,0,0,1,0.017,0.0387,0.009,-0.0015,-0.00025,-0.00442,0.06604,0.99781,0.033,0.1397,0.0581,-0.003,-0.00308,-0.01605,0.24459,0.96949,0.05,0.2528,0.1842,-0.0005,-0.01172,-0.03102,0.48546,0.87363,0.067,0.3071,0.3622,0.0036,-0.02804,-0.04308,0.70005,0.71224,0.083,0.302,0.5188,0.0038,-0.05284,-0.04847,0.83434,0.54657,0.1,0.2877,0.6282,0.0005,-0.08862,-0.04767,0.90156,0.42078,0.117,0.2871,0.7093,-0.0022,-0.13608,-0.04255,0.93366,0.32856,0.133,0.3032,0.7757,-0.0002,-0.19551,-0.03383,0.94579,0.25712,0.15,0.3332,0.8338,0.0108,-0.26594,-0.02167,0.9431,0.1984,0.167,0.3704,0.8873,0.0325,-0.34263,-0.00652,0.92767,0.1483,0.183,0.4049,0.9381,0.0605,-0.41491,0.01007,0.90359,0.10616,0.2,0.4285,0.986,0.0834,-0.46971,0.02549,0.87936,0.07385,0.217,0.4426,1.027,0.0959,-0.50474,0.03829,0.86078,0.05324,0.233,0.4508,1.0578,0.0988,-0.52324,0.04804,0.84969,0.04394,0.25,0.456,1.0766,0.0949,-0.5295,0.05487,0.84538,0.04418,0.267,0.4597,1.0821,0.0879,-0.52753,0.05913,0.84589,0.05191,0.283,0.4632,1.0739,0.0809,-0.52075,0.06125,0.84901,0.06526,0.3,0.4672,1.054,0.0761,-0.512,0.06169,0.85281,0.08225,0.317,0.4722,1.0248,0.0754,-0.50402,0.06089,0.85561,0.10089,0.333,0.4793,0.9888,0.0806,-0.49963,0.05926,0.85594,0.11925,0.35,0.4894,0.9481,0.0939,-0.50172,0.05719,0.85246,0.13532,0.367,0.5024,0.905,0.1162,-0.51198,0.05504,0.84444,0.14755,0.383,0.5164,0.8611,0.1445,-0.52747,0.05302,0.83339,0.15626,0.4,0.5292,0.8183,0.1743,-0.54429,0.05128,0.82145,0.16229,0.417,0.5393,0.7782,0.2008,-0.55876,0.04998,0.81091,0.16651,0.433,0.5459,0.7425,0.2194,-0.5675,0.04931,0.80416,0.16983,0.45,0.5487,0.7125,0.2266,-0.56812,0.04937,0.80304,0.17298,0.467,0.548,0.6881,0.2236,-0.56163,0.05011,0.80691,0.17595,0.483,0.5443,0.6689,0.2128,-0.54971,0.05139,0.81443,0.17853,0.5,0.5379,0.6545,0.1965,-0.53401,0.05309,0.82428,0.18049},
		["Right Leg"] = {0,-0.0179,-0.0121,-0.0005,0.01382,-0.01668,-0.09776,0.99497,0.017,-0.0225,-0.0347,0.0037,0.01332,-0.02032,-0.09717,0.99497,0.033,-0.0347,-0.0941,0.0149,0.01194,-0.03021,-0.09561,0.99489,0.05,-0.0521,-0.1781,0.0309,0.00989,-0.0448,-0.09339,0.99457,0.067,-0.0723,-0.2744,0.0494,0.00736,-0.06254,-0.09081,0.99388,0.083,-0.093,-0.3705,0.0685,0.00456,-0.08187,-0.08819,0.99272,0.1,-0.1117,-0.4541,0.0863,0.00169,-0.10123,-0.08584,0.99115,0.117,-0.1266,-0.5152,0.1014,-0.00108,-0.11934,-0.08403,0.98929,0.133,-0.1376,-0.5532,0.114,-0.00372,-0.13601,-0.0828,0.98724,0.15,-0.1449,-0.5702,0.1241,-0.00623,-0.15128,-0.08207,0.98506,0.167,-0.1491,-0.5682,0.1321,-0.0086,-0.16523,-0.08181,0.98282,0.183,-0.1504,-0.5489,0.1381,-0.01084,-0.17791,-0.08197,0.98057,0.2,-0.1493,-0.5146,0.1423,-0.01294,-0.18938,-0.08249,0.97835,0.217,-0.1461,-0.467,0.145,-0.0149,-0.19972,-0.08333,0.97619,0.233,-0.1413,-0.4083,0.1463,-0.01673,-0.20897,-0.08443,0.97413,0.25,-0.1351,-0.3403,0.1463,-0.01842,-0.21719,-0.08575,0.97218,0.267,-0.128,-0.2651,0.1452,-0.01998,-0.22444,-0.08723,0.97037,0.283,-0.1204,-0.1847,0.1431,-0.02139,-0.23077,-0.08882,0.96871,0.3,-0.1125,-0.101,0.1402,-0.02266,-0.23623,-0.09047,0.96721,0.317,-0.1048,-0.0161,0.1366,-0.02379,-0.24087,-0.09212,0.96588,0.333,-0.0977,0.0681,0.1324,-0.02478,-0.24474,-0.09373,0.96473,0.35,-0.0914,0.1495,0.1277,-0.02562,-0.24789,-0.09525,0.96375,0.367,-0.0864,0.2262,0.1226,-0.02632,-0.25036,-0.0966,0.96296,0.383,-0.0829,0.2962,0.1173,-0.02686,-0.25221,-0.09775,0.96235,0.4,-0.0815,0.3574,0.1119,-0.02725,-0.25347,-0.09864,0.96191,0.417,-0.0823,0.4079,0.1064,-0.02749,-0.25419,-0.09922,0.96166,0.433,-0.0858,0.4456,0.1009,-0.02757,-0.25443,-0.09942,0.96157,0.45,-0.0923,0.4694,0.0954,-0.02757,-0.25443,-0.09942,0.96157,0.467,-0.1018,0.4804,0.09,-0.02757,-0.25443,-0.09942,0.96157,0.483,-0.1137,0.48,0.0845,-0.02757,-0.25443,-0.09942,0.96157,0.5,-0.1276,0.4699,0.0791,-0.02757,-0.25443,-0.09942,0.96157},
		Torso = {0,0.0032,-0.6038,-0.2029,0.31846,0.00416,-0.00732,0.9479,0.017,0.0049,-0.6693,-0.2336,0.341,0.00348,-0.00234,0.94005,0.033,0.0111,-0.8334,-0.3221,0.39893,0.00129,0.0112,0.91691,0.05,0.0245,-1.0426,-0.4623,0.47658,-0.00264,0.03107,0.87858,0.067,0.046,-1.2459,-0.6347,0.55722,-0.00844,0.05451,0.82853,0.083,0.0724,-1.4094,-0.8044,0.62603,-0.01614,0.07867,0.77565,0.1,0.0981,-1.5252,-0.9394,0.67484,-0.02574,0.10161,0.73048,0.117,0.1207,-1.6073,-1.0356,0.70642,-0.03699,0.12321,0.69601,0.133,0.1394,-1.6677,-1.0982,0.72481,-0.04965,0.14373,0.67196,0.15,0.1533,-1.7128,-1.1327,0.73295,-0.06351,0.16333,0.65732,0.167,0.1619,-1.7462,-1.1441,0.73293,-0.07836,0.18206,0.65079,0.183,0.1647,-1.769,-1.1367,0.72629,-0.09397,0.19984,0.65095,0.2,0.1613,-1.7816,-1.1143,0.7143,-0.11004,0.21645,0.65636,0.217,0.1518,-1.7838,-1.0807,0.69818,-0.12618,0.23158,0.66558,0.233,0.1367,-1.7756,-1.0399,0.67924,-0.14197,0.24483,0.67715,0.25,0.1172,-1.7573,-0.9958,0.65902,-0.15691,0.2558,0.68967,0.267,0.0951,-1.7299,-0.9525,0.63929,-0.1705,0.26411,0.70177,0.283,0.0724,-1.6951,-0.9134,0.62171,-0.18232,0.2695,0.71247,0.3,0.0503,-1.6548,-0.8788,0.60666,-0.19232,0.27223,0.72171,0.317,0.0295,-1.6104,-0.8484,0.5941,-0.20058,0.27269,0.7297,0.333,0.0105,-1.5634,-0.8218,0.58391,-0.20718,0.27124,0.73658,0.35,-0.0065,-1.5153,-0.7986,0.57593,-0.2122,0.26827,0.7425,0.367,-0.021,-1.4671,-0.7786,0.56995,-0.21572,0.26412,0.74757,0.383,-0.0331,-1.4202,-0.7613,0.56574,-0.21785,0.25917,0.75187,0.4,-0.0426,-1.3757,-0.7465,0.56305,-0.21865,0.25376,0.75549,0.417,-0.0495,-1.3346,-0.734,0.56162,-0.21822,0.24822,0.75852,0.433,-0.0537,-1.2981,-0.7237,0.56119,-0.21664,0.2429,0.76101,0.45,-0.0552,-1.267,-0.7154,0.56153,-0.21399,0.23806,0.76303,0.467,-0.0544,-1.2411,-0.709,0.56251,-0.21041,0.23373,0.76464,0.483,-0.0514,-1.2199,-0.7042,0.56405,-0.20607,0.22988,0.76586,0.5,-0.0467,-1.2031,-0.701,0.56603,-0.20109,0.22648,0.76673},
	}},
	BackDash = {len = 0.7, parts = {
		Head = {0,0,0,0,0.62585,-0.00756,-0.00944,0.77985,0.017,0,0,0,0.61834,-0.00739,-0.00933,0.78582,0.033,0,0,0,0.5979,-0.00694,-0.00903,0.80149,0.05,0,0,0,0.56756,-0.00628,-0.00858,0.82327,0.067,0,0,0,0.53056,-0.00549,-0.00803,0.84759,0.083,0,0,0,0.49067,-0.00464,-0.00743,0.8713,0.1,0,0,0,0.45209,-0.00384,-0.00686,0.89194,0.117,0,0,0,0.41929,-0.00316,-0.00637,0.90782,0.133,0,0,0,0.39675,-0.0027,-0.00603,0.9179,0.15,0,0,0,0.38154,-0.00239,-0.00581,0.92433,0.167,0,0,0,0.36774,-0.00211,-0.0056,0.92991,0.183,0,0,0,0.35531,-0.00186,-0.00542,0.93473,0.2,0,0,0,0.34421,-0.00164,-0.00525,0.93888,0.217,0,0,0,0.33437,-0.00144,-0.0051,0.94243,0.233,0,0,0,0.32573,-0.00127,-0.00498,0.94545,0.25,0,0,0,0.31821,-0.00112,-0.00486,0.94801,0.267,0,0,0,0.31176,-0.00099,-0.00477,0.95015,0.283,0,0,0,0.30629,-0.00088,-0.00469,0.95193,0.3,0,0,0,0.30172,-0.00079,-0.00462,0.95338,0.317,0,0,0,0.29798,-0.00072,-0.00456,0.95456,0.333,0,0,0,0.29498,-0.00066,-0.00452,0.95549,0.35,0,0,0,0.29264,-0.00061,-0.00448,0.95621,0.367,0,0,0,0.29088,-0.00058,-0.00446,0.95675,0.383,0,0,0,0.28962,-0.00055,-0.00444,0.95713,0.4,0,0,0,0.28878,-0.00053,-0.00442,0.95739,0.417,0,0,0,0.28827,-0.00052,-0.00442,0.95754,0.433,0,0,0,0.288,-0.00052,-0.00441,0.95762,0.45,0,0,0,0.28791,-0.00052,-0.00441,0.95765,0.467,0,0,0,0.28789,-0.00052,-0.00441,0.95765,0.483,0,0,0,0.28789,-0.00052,-0.00441,0.95765,0.5,0,0,0,0.28789,-0.00052,-0.00441,0.95765,0.517,0,0,0,0.28789,-0.00052,-0.00441,0.95765,0.533,0,0,0,0.28789,-0.00052,-0.00441,0.95765,0.55,0,0,0,0.28789,-0.00052,-0.00441,0.95765,0.567,0,0,0,0.28789,-0.00052,-0.00441,0.95765,0.583,0,0,0,0.28789,-0.00052,-0.00441,0.95765,0.6,0,0,0,0.28789,-0.00052,-0.00441,0.95765,0.617,0,0,0,0.28789,-0.00052,-0.00441,0.95765,0.633,0,0,0,0.28789,-0.00052,-0.00441,0.95765,0.65,0,0,0,0.28789,-0.00052,-0.00441,0.95765,0.667,0,0,0,0.28789,-0.00052,-0.00441,0.95765,0.683,0,0,0,0.28789,-0.00052,-0.00441,0.95765,0.7,0,0,0,0.28789,-0.00052,-0.00441,0.95765},
		["Left Arm"] = {0,0.3076,-0.0035,-0.2366,-0.12168,-0.45334,-0.32127,0.82247,0.017,0.1705,-0.1838,-0.2138,-0.09248,-0.46849,-0.34067,0.80988,0.033,-0.1009,-0.5171,-0.172,-0.04598,-0.4906,-0.38345,0.78113,0.05,-0.3358,-0.7502,-0.1522,-0.03231,-0.49553,-0.43057,0.75367,0.067,-0.5029,-0.8549,-0.1544,-0.05094,-0.48848,-0.47058,0.73303,0.083,-0.6034,-0.8622,-0.1624,-0.08919,-0.48042,-0.49347,0.71953,0.1,-0.6565,-0.8088,-0.1609,-0.14571,-0.47694,-0.50316,0.70578,0.117,-0.6859,-0.7243,-0.1404,-0.21788,-0.47668,-0.50661,0.68458,0.133,-0.698,-0.6364,-0.0956,-0.29304,-0.48107,-0.49971,0.65802,0.15,-0.6987,-0.5709,-0.0299,-0.3597,-0.48977,-0.48241,0.63089,0.167,-0.6873,-0.5274,0.0249,-0.40142,-0.49144,-0.46714,0.61573,0.183,-0.6751,-0.5022,0.0472,-0.4189,-0.46751,-0.46551,0.6239,0.2,-0.6527,-0.4992,0.066,-0.4246,-0.44482,-0.46324,0.63816,0.217,-0.61,-0.5188,0.1012,-0.42839,-0.44416,-0.44943,0.64592,0.233,-0.5586,-0.5493,0.1471,-0.43841,-0.44741,-0.42735,0.65191,0.25,-0.4947,-0.5831,0.1974,-0.45253,-0.45347,-0.39768,0.65684,0.267,-0.4145,-0.6122,0.2455,-0.46856,-0.46122,-0.36107,0.66132,0.283,-0.3174,-0.6301,0.2845,-0.48444,-0.46921,-0.32008,0.66537,0.3,-0.2146,-0.6356,0.308,-0.49869,-0.47482,-0.28505,0.66678,0.317,-0.1218,-0.6317,0.3106,-0.51058,-0.47578,-0.26897,0.66377,0.333,-0.04,-0.6206,0.2976,-0.52292,-0.47017,-0.26787,0.65859,0.35,0.0392,-0.6029,0.2784,-0.53803,-0.45819,-0.26883,0.65445,0.367,0.1148,-0.5795,0.2545,-0.55464,-0.44091,-0.27136,0.65141,0.383,0.1858,-0.5514,0.2273,-0.57147,-0.41937,-0.275,0.64956,0.4,0.2511,-0.5197,0.1981,-0.58726,-0.39468,-0.27934,0.64909,0.417,0.3093,-0.486,0.168,-0.6008,-0.36806,-0.284,0.65031,0.433,0.3591,-0.4518,0.1381,-0.61095,-0.34084,-0.28865,0.65365,0.45,0.399,-0.419,0.1089,-0.6166,-0.31443,-0.29296,0.65962,0.467,0.4274,-0.3894,0.0812,-0.61674,-0.29031,-0.29667,0.66883,0.483,0.4428,-0.3647,0.0553,-0.61032,-0.26999,-0.29948,0.68185,0.5,0.4442,-0.3458,0.0313,-0.59666,-0.25453,-0.30113,0.69895,0.517,0.4332,-0.3312,0.009,-0.57662,-0.2434,-0.30148,0.71929,0.533,0.4122,-0.3194,-0.0115,-0.55147,-0.23562,-0.30042,0.74169,0.55,0.3832,-0.3087,-0.0301,-0.5225,-0.23023,-0.29788,0.76502,0.567,0.3484,-0.2978,-0.0465,-0.49109,-0.22626,-0.29379,0.78824,0.583,0.3096,-0.2861,-0.0602,-0.4587,-0.22282,-0.28819,0.81049,0.6,0.2688,-0.2734,-0.0709,-0.42686,-0.21905,-0.28114,0.83113,0.617,0.231,-0.2607,-0.0783,-0.39622,-0.21834,-0.27207,0.8493,0.633,0.2007,-0.2488,-0.0827,-0.36745,-0.22303,-0.26128,0.86427,0.65,0.1777,-0.238,-0.0844,-0.34214,-0.23073,-0.25024,0.87583,0.667,0.1618,-0.229,-0.0843,-0.32196,-0.23909,-0.24044,0.88395,0.683,0.1525,-0.2228,-0.0834,-0.30862,-0.24579,-0.23344,0.88873,0.7,0.1495,-0.2206,-0.0828,-0.3038,-0.24854,-0.23077,0.89032},
		["Left Leg"] = {0,-0.0759,0.3549,-0.0579,0.00158,0.00171,0.08601,0.99629,0.017,-0.0886,0.3371,-0.0587,0.00157,0.00769,0.07206,0.99737,0.033,-0.1213,0.289,-0.0608,0.00151,0.02376,0.03414,0.99913,0.05,-0.1662,0.2185,-0.0646,0.0014,0.04704,-0.02182,0.99865,0.067,-0.216,0.1333,-0.0699,0.0012,0.07434,-0.08911,0.99324,0.083,-0.2639,0.0429,-0.076,0.0009,0.10218,-0.16014,0.98179,0.1,-0.3028,-0.042,-0.0817,0.00049,0.12713,-0.22725,0.9655,0.117,-0.3245,-0.1089,-0.0851,-0.00004,0.14627,-0.28368,0.9477,0.133,-0.3218,-0.148,-0.0846,-0.0007,0.15785,-0.32538,0.93231,0.15,-0.2976,-0.1614,-0.0803,-0.00144,0.16269,-0.35404,0.92097,0.167,-0.2576,-0.1551,-0.0729,-0.00223,0.16196,-0.3722,0.91391,0.183,-0.208,-0.1349,-0.0635,-0.00304,0.15662,-0.38197,0.9108,0.2,-0.1554,-0.1072,-0.0529,-0.00382,0.14746,-0.38509,0.91102,0.217,-0.1064,-0.0783,-0.0421,-0.00452,0.13525,-0.38313,0.91373,0.233,-0.0677,-0.0544,-0.0322,-0.0051,0.12076,-0.37763,0.91803,0.25,-0.0443,-0.0407,-0.0239,-0.00551,0.10479,-0.36993,0.92312,0.267,-0.0351,-0.0365,-0.0174,-0.00577,0.08789,-0.36044,0.92862,0.283,-0.0375,-0.0399,-0.0126,-0.00588,0.07056,-0.3494,0.9343,0.3,-0.0489,-0.049,-0.0094,-0.00588,0.05329,-0.33704,0.93996,0.317,-0.0664,-0.0618,-0.0076,-0.00578,0.03658,-0.32362,0.94546,0.333,-0.0874,-0.0763,-0.0069,-0.00561,0.0209,-0.30941,0.95068,0.35,-0.1093,-0.0902,-0.0071,-0.00538,0.00671,-0.29466,0.95556,0.367,-0.1293,-0.1015,-0.0076,-0.00513,-0.00556,-0.27964,0.96007,0.383,-0.1452,-0.1084,-0.0083,-0.00487,-0.0156,-0.26457,0.96423,0.4,-0.1569,-0.1108,-0.009,-0.00461,-0.0235,-0.24955,0.96807,0.417,-0.1648,-0.1091,-0.0095,-0.00435,-0.02944,-0.23466,0.97162,0.433,-0.1692,-0.1037,-0.0098,-0.00409,-0.03361,-0.21996,0.97492,0.45,-0.1705,-0.095,-0.0099,-0.00383,-0.0362,-0.20553,0.97797,0.467,-0.169,-0.0834,-0.0099,-0.00357,-0.03737,-0.19144,0.98079,0.483,-0.1652,-0.0694,-0.0096,-0.00332,-0.0373,-0.17776,0.98336,0.5,-0.1592,-0.0533,-0.0093,-0.00308,-0.03616,-0.16457,0.9857,0.517,-0.1516,-0.0356,-0.0088,-0.00284,-0.03412,-0.15193,0.9878,0.533,-0.1427,-0.0168,-0.0082,-0.00262,-0.03135,-0.13994,0.98966,0.55,-0.1328,0.0026,-0.0076,-0.00241,-0.02802,-0.12868,0.99129,0.567,-0.1224,0.0221,-0.007,-0.00221,-0.02431,-0.11822,0.99269,0.583,-0.1118,0.0413,-0.0064,-0.00203,-0.02039,-0.10866,0.99387,0.6,-0.1013,0.0596,-0.0058,-0.00186,-0.01642,-0.10008,0.99484,0.617,-0.0915,0.0765,-0.0053,-0.00172,-0.01258,-0.09257,0.99562,0.633,-0.0825,0.0916,-0.0049,-0.0016,-0.00905,-0.08623,0.99623,0.65,-0.0749,0.1042,-0.0045,-0.0015,-0.006,-0.08114,0.99668,0.667,-0.069,0.1138,-0.0043,-0.00142,-0.0036,-0.0774,0.99699,0.683,-0.0652,0.12,-0.0041,-0.00138,-0.00204,-0.07509,0.99717,0.7,-0.0639,0.1222,-0.0041,-0.00136,-0.00148,-0.07429,0.99723},
		["Right Arm"] = {0,-0.3076,-0.0035,-0.2366,-0.12168,0.45334,0.32127,0.82247,0.017,-0.1704,-0.1838,-0.2139,-0.09248,0.46846,0.34083,0.80983,0.033,0.1009,-0.5171,-0.172,-0.04598,0.4906,0.38345,0.78113,0.05,0.3353,-0.7503,-0.1517,-0.03242,0.49571,0.42963,0.75408,0.067,0.5021,-0.8553,-0.1537,-0.05118,0.48877,0.46921,0.73371,0.083,0.6034,-0.8622,-0.1624,-0.08919,0.48042,0.49347,0.71953,0.1,0.6569,-0.8083,-0.1616,-0.14513,0.47698,0.50442,0.70497,0.117,0.6857,-0.724,-0.1409,-0.21723,0.47715,0.50732,0.68393,0.133,0.698,-0.6364,-0.0956,-0.29304,0.48107,0.49971,0.65802,0.15,0.7,-0.5706,-0.0302,-0.36051,0.48813,0.48266,0.63151,0.167,0.6873,-0.5274,0.0249,-0.40142,0.49144,0.46714,0.61573,0.183,0.6739,-0.5026,0.0475,-0.41836,0.4687,0.46501,0.62375,0.2,0.6527,-0.4992,0.066,-0.4246,0.44482,0.46324,0.63816,0.217,0.6104,-0.5187,0.1012,-0.42847,0.44452,0.44993,0.64527,0.233,0.5591,-0.5492,0.1472,-0.43847,0.44778,0.4279,0.65126,0.25,0.4949,-0.583,0.1975,-0.45255,0.45366,0.39799,0.65651,0.267,0.4145,-0.6122,0.2455,-0.46856,0.46122,0.36107,0.66132,0.283,0.3173,-0.6301,0.2845,-0.48443,0.46915,0.31998,0.66546,0.3,0.2146,-0.6356,0.308,-0.49869,0.47479,0.28499,0.66683,0.317,0.1218,-0.6317,0.3106,-0.51058,0.47578,0.26897,0.66377,0.333,0.04,-0.6206,0.2976,-0.52292,0.47011,0.26785,0.65864,0.35,-0.0392,-0.603,0.2783,-0.53803,0.45797,0.26875,0.65465,0.367,-0.1149,-0.5796,0.2543,-0.55459,0.4405,0.27119,0.6518,0.383,-0.1861,-0.5515,0.2269,-0.57134,0.4188,0.27474,0.65015,0.4,-0.2515,-0.5199,0.1976,-0.58703,0.39402,0.27899,0.64986,0.417,-0.3098,-0.4863,0.1675,-0.60046,0.36741,0.28357,0.65119,0.433,-0.3597,-0.4521,0.1375,-0.61053,0.34028,0.28818,0.65453,0.45,-0.3996,-0.4193,0.1084,-0.61621,0.31404,0.29254,0.66037,0.467,-0.4278,-0.3897,0.0809,-0.61648,0.29012,0.29639,0.66928,0.483,-0.4428,-0.3647,0.0553,-0.61032,0.26999,0.29948,0.68185,0.5,-0.4436,-0.3455,0.0317,-0.59703,0.25468,0.30156,0.6984,0.517,-0.432,-0.3307,0.0098,-0.57736,0.24364,0.30241,0.71823,0.533,-0.4105,-0.3188,-0.0105,-0.55244,0.2359,0.3018,0.74032,0.55,-0.3813,-0.3081,-0.0292,-0.52349,0.23051,0.29951,0.76362,0.567,-0.3467,-0.2974,-0.0458,-0.49188,0.2265,0.29536,0.78709,0.583,-0.3086,-0.2859,-0.0598,-0.45912,0.22297,0.28924,0.80984,0.6,-0.2688,-0.2734,-0.0709,-0.42686,0.21905,0.28114,0.83113,0.617,-0.232,-0.2608,-0.0786,-0.39585,0.21826,0.27108,0.84981,0.633,-0.202,-0.2488,-0.0831,-0.36686,0.22298,0.25995,0.86494,0.65,-0.1789,-0.2379,-0.0849,-0.34156,0.23073,0.24906,0.87639,0.667,-0.1625,-0.2289,-0.0846,-0.32159,0.23911,0.23972,0.88427,0.683,-0.1527,-0.2228,-0.0835,-0.3085,0.2458,0.23321,0.88883,0.7,-0.1495,-0.2206,-0.0828,-0.3038,0.24854,0.23077,0.89032},
		["Right Leg"] = {0,0.0759,0.3549,-0.0579,0.00158,-0.00171,-0.08601,0.99629,0.017,0.0887,0.3371,-0.0587,0.00157,-0.0076,-0.07229,0.99735,0.033,0.1216,0.289,-0.0608,0.00152,-0.02346,-0.0349,0.99911,0.05,0.1667,0.2185,-0.0645,0.00141,-0.04655,0.02054,0.9987,0.067,0.2165,0.1335,-0.0698,0.00121,-0.07379,0.08761,0.99342,0.083,0.2643,0.043,-0.0759,0.00091,-0.10173,0.15887,0.98204,0.1,0.303,-0.0418,-0.0817,0.0005,-0.1269,0.22656,0.96569,0.117,0.3245,-0.1089,-0.0851,-0.00004,-0.14627,0.28368,0.9477,0.133,0.3217,-0.1481,-0.0846,-0.0007,-0.15798,0.32591,0.93211,0.15,0.2975,-0.1616,-0.0803,-0.00146,-0.16285,0.35482,0.92064,0.167,0.2575,-0.1552,-0.073,-0.00225,-0.16208,0.37301,0.91356,0.183,0.208,-0.135,-0.0635,-0.00306,-0.15666,0.38263,0.91052,0.2,0.1554,-0.1073,-0.0529,-0.00383,-0.14744,0.38551,0.91084,0.217,0.1064,-0.0783,-0.0421,-0.00453,-0.13521,0.38332,0.91365,0.233,0.0677,-0.0544,-0.0322,-0.0051,-0.12076,0.37763,0.91803,0.25,0.0442,-0.0407,-0.0239,-0.00551,-0.10487,0.36982,0.92315,0.267,0.035,-0.0365,-0.0174,-0.00576,-0.08805,0.36031,0.92865,0.283,0.0373,-0.04,-0.0126,-0.00587,-0.0708,0.34929,0.93432,0.3,0.0486,-0.0491,-0.0094,-0.00587,-0.05357,0.33697,0.93997,0.317,0.0661,-0.0619,-0.0076,-0.00577,-0.03685,0.3236,0.94546,0.333,0.0872,-0.0763,-0.007,-0.0056,-0.02111,0.30942,0.95067,0.35,0.1092,-0.0903,-0.0071,-0.00538,-0.00683,0.29468,0.95556,0.367,0.1293,-0.1015,-0.0076,-0.00513,0.00556,0.27964,0.96007,0.383,0.1453,-0.1084,-0.0083,-0.00488,0.01571,0.26453,0.96424,0.4,0.1571,-0.1108,-0.009,-0.00462,0.02371,0.24945,0.96809,0.417,0.1651,-0.1091,-0.0095,-0.00435,0.02973,0.23448,0.97166,0.433,0.1696,-0.1037,-0.0098,-0.00409,0.03396,0.21972,0.97496,0.45,0.1709,-0.095,-0.0099,-0.00383,0.03658,0.20522,0.97802,0.467,0.1694,-0.0834,-0.0099,-0.00357,0.03776,0.19108,0.98084,0.483,0.1655,-0.0693,-0.0097,-0.00332,0.03769,0.17736,0.98342,0.5,0.1596,-0.0532,-0.0093,-0.00308,0.03653,0.16413,0.98576,0.517,0.152,-0.0356,-0.0088,-0.00284,0.03446,0.15149,0.98785,0.533,0.143,-0.0168,-0.0082,-0.00262,0.03166,0.13951,0.98971,0.55,0.1331,0.0026,-0.0076,-0.00241,0.02829,0.12827,0.99133,0.567,0.1226,0.0221,-0.007,-0.00221,0.02453,0.11785,0.99273,0.583,0.112,0.0413,-0.0064,-0.00202,0.02056,0.10833,0.9939,0.6,0.1015,0.0596,-0.0058,-0.00186,0.01655,0.09981,0.99487,0.617,0.0916,0.0765,-0.0053,-0.00172,0.01268,0.09237,0.99564,0.633,0.0826,0.0916,-0.0049,-0.00159,0.00911,0.08609,0.99624,0.65,0.075,0.1042,-0.0045,-0.0015,0.00604,0.08106,0.99669,0.667,0.069,0.1138,-0.0043,-0.00142,0.00362,0.07736,0.997,0.683,0.0652,0.12,-0.0041,-0.00138,0.00204,0.07507,0.99717,0.7,0.0639,0.1222,-0.0041,-0.00136,0.00148,0.07429,0.99723},
		Torso = {0,-0.0544,1.4373,-0.6727,-0.42812,-0.00506,0.01255,0.90362,0.017,-0.0525,1.4531,-0.6678,-0.42338,-0.00512,0.01252,0.90585,0.033,-0.0474,1.496,-0.6552,-0.41037,-0.0053,0.01245,0.91182,0.05,-0.0396,1.559,-0.6375,-0.39082,-0.00556,0.01233,0.92037,0.067,-0.0299,1.6349,-0.6179,-0.36649,-0.00589,0.01218,0.93032,0.083,-0.019,1.7172,-0.5992,-0.33924,-0.00624,0.012,0.9406,0.1,-0.0074,1.8001,-0.5836,-0.31102,-0.00659,0.01181,0.95031,0.117,0.0042,1.8783,-0.5728,-0.28387,-0.00693,0.01162,0.95877,0.133,0.015,1.947,-0.5673,-0.25985,-0.00722,0.01144,0.96555,0.15,0.0245,2.0025,-0.5668,-0.24054,-0.00744,0.0113,0.97054,0.167,0.0327,2.0444,-0.5699,-0.22562,-0.00761,0.01118,0.97412,0.183,0.0397,2.073,-0.5749,-0.2143,-0.00774,0.01109,0.97667,0.2,0.0455,2.0883,-0.5807,-0.20575,-0.00784,0.01102,0.97851,0.217,0.0501,2.0907,-0.5864,-0.1993,-0.00791,0.01097,0.97985,0.233,0.0537,2.0811,-0.5916,-0.19471,-0.00796,0.01093,0.98077,0.25,0.0563,2.0608,-0.5961,-0.19185,-0.008,0.01091,0.98133,0.267,0.0579,2.0311,-0.5997,-0.19062,-0.00801,0.0109,0.98157,0.283,0.0587,1.993,-0.6022,-0.19087,-0.00801,0.0109,0.98152,0.3,0.0586,1.9479,-0.6034,-0.19249,-0.00799,0.01092,0.98121,0.317,0.0578,1.8969,-0.6034,-0.19534,-0.00796,0.01094,0.98064,0.333,0.0564,1.8411,-0.6019,-0.19929,-0.00791,0.01097,0.97985,0.35,0.0543,1.7818,-0.5989,-0.20421,-0.00786,0.01101,0.97883,0.367,0.0516,1.7201,-0.5943,-0.20998,-0.00779,0.01106,0.97761,0.383,0.0485,1.6572,-0.588,-0.21645,-0.00772,0.01111,0.9762,0.4,0.0449,1.5943,-0.5799,-0.22351,-0.00764,0.01116,0.97461,0.417,0.0409,1.5324,-0.5706,-0.23101,-0.00755,0.01122,0.97286,0.433,0.0367,1.4729,-0.5606,-0.23884,-0.00746,0.01128,0.97097,0.45,0.0322,1.4169,-0.5504,-0.24686,-0.00737,0.01134,0.96896,0.467,0.0276,1.3656,-0.5404,-0.25494,-0.00727,0.0114,0.96686,0.483,0.0228,1.3202,-0.5313,-0.26296,-0.00718,0.01147,0.96471,0.5,0.018,1.2816,-0.5233,-0.27081,-0.00708,0.01152,0.96254,0.517,0.0132,1.2495,-0.5166,-0.27841,-0.00699,0.01158,0.96037,0.533,0.0085,1.2233,-0.5109,-0.2857,-0.00691,0.01163,0.95822,0.55,0.004,1.2024,-0.5063,-0.2926,-0.00682,0.01168,0.95614,0.567,-0.0004,1.1862,-0.5026,-0.29905,-0.00674,0.01173,0.95414,0.583,-0.0045,1.1741,-0.4997,-0.30499,-0.00667,0.01177,0.95226,0.6,-0.0082,1.1656,-0.4975,-0.31035,-0.0066,0.01181,0.95053,0.617,-0.0116,1.1599,-0.4959,-0.31506,-0.00654,0.01184,0.94897,0.633,-0.0144,1.1567,-0.4949,-0.31907,-0.00649,0.01187,0.94763,0.65,-0.0168,1.1551,-0.4942,-0.3223,-0.00645,0.01189,0.94654,0.667,-0.0185,1.1548,-0.4939,-0.32469,-0.00642,0.0119,0.94572,0.683,-0.0196,1.155,-0.4937,-0.32617,-0.0064,0.01191,0.94521,0.7,-0.02,1.1552,-0.4937,-0.32668,-0.0064,0.01192,0.94504},
	}},
	DashLeft = {len = 0.517, parts = {
		Head = {0,0,0,0,0,0,0,1,0.017,0,0,0,0.01925,-0.03594,0.05625,0.99758,0.033,0,0,0,0.04195,-0.08179,0.12338,0.98809,0.05,0,0,0,0.06502,-0.13237,0.19238,0.97018,0.067,0,0,0,0.08522,-0.18197,0.25356,0.94622,0.083,0,0,0,0.09967,-0.22548,0.29841,0.92205,0.1,0,0,0,0.10684,-0.25998,0.32222,0.90398,0.117,0,0,0,0.10826,-0.28684,0.32887,0.89322,0.133,0,0,0,0.10594,-0.30802,0.32355,0.88838,0.15,0,0,0,0.10171,-0.32512,0.31091,0.88729,0.167,0,0,0,0.09732,-0.33958,0.29538,0.88767,0.183,0,0,0,0.0942,-0.35255,0.28063,0.88774,0.2,0,0,0,0.09249,-0.36434,0.26735,0.88726,0.217,0,0,0,0.09201,-0.37498,0.25551,0.88636,0.233,0,0,0,0.09261,-0.38454,0.24504,0.88516,0.25,0,0,0,0.0941,-0.39305,0.23591,0.88374,0.267,0,0,0,0.09633,-0.40054,0.22808,0.8822,0.283,0,0,0,0.09913,-0.40702,0.22149,0.8806,0.3,0,0,0,0.10234,-0.41252,0.21611,0.87901,0.317,0,0,0,0.10579,-0.41703,0.21191,0.87749,0.333,0,0,0,0.10931,-0.42057,0.20885,0.8761,0.35,0,0,0,0.11274,-0.42313,0.20688,0.8749,0.367,0,0,0,0.11591,-0.4247,0.20599,0.87394,0.383,0,0,0,0.11864,-0.42528,0.20614,0.87325,0.4,0,0,0,0.12076,-0.42486,0.20728,0.8729,0.417,0,0,0,0.12212,-0.42344,0.20938,0.87289,0.433,0,0,0,0.12277,-0.42111,0.21234,0.87322,0.45,0,0,0,0.12277,-0.41798,0.21604,0.87381,0.467,0,0,0,0.12219,-0.41415,0.22036,0.87464,0.483,0,0,0,0.12111,-0.40972,0.22521,0.87564,0.5,0,0,0,0.11959,-0.40482,0.23045,0.87676,0.517,0,0,0,0.1177,-0.39954,0.23598,0.87797},
		["Left Arm"] = {0,0,0,0,0,0,0,1,0.017,-0.0045,-0.0025,0.0595,-0.05898,0.00434,-0.03631,0.99759,0.033,-0.0046,-0.0029,0.139,-0.14393,-0.00049,-0.07961,0.98638,0.05,0.0002,0.0054,0.2314,-0.25243,-0.018,-0.12422,0.95944,0.067,0.0104,0.027,0.3255,-0.37746,-0.04973,-0.16293,0.91022,0.083,0.0263,0.06,0.408,-0.50652,-0.09322,-0.18835,0.83623,0.1,0.0476,0.0952,0.4695,-0.62488,-0.14139,-0.19583,0.74242,0.117,0.0734,0.1221,0.5094,-0.72189,-0.18473,-0.18559,0.64056,0.133,0.1028,0.1349,0.5336,-0.79492,-0.21466,-0.16205,0.54383,0.15,0.1345,0.1345,0.5482,-0.84773,-0.22594,-0.13124,0.46161,0.167,0.1668,0.1246,0.5559,-0.88557,-0.21811,-0.0989,0.39802,0.183,0.1983,0.1085,0.5569,-0.91287,-0.19283,-0.06816,0.35332,0.2,0.2287,0.0884,0.5514,-0.9327,-0.15318,-0.03983,0.32407,0.217,0.258,0.0648,0.5393,-0.94618,-0.10213,-0.01382,0.30681,0.233,0.2859,0.0375,0.5209,-0.95328,-0.04244,0.01026,0.29892,0.25,0.3117,0.0062,0.4965,-0.95357,0.0231,0.03281,0.2985,0.267,0.3343,-0.0293,0.4667,-0.94668,0.09155,0.05411,0.30414,0.283,0.3526,-0.0684,0.4326,-0.93264,0.15987,0.07424,0.31481,0.3,0.3657,-0.1099,0.3952,-0.91211,0.22503,0.09304,0.3298,0.317,0.373,-0.152,0.3563,-0.88637,0.28413,0.11001,0.34859,0.333,0.3745,-0.1927,0.3177,-0.85737,0.33455,0.12432,0.37085,0.35,0.3709,-0.2299,0.2819,-0.82757,0.37404,0.13474,0.39632,0.367,0.3632,-0.2619,0.2514,-0.79948,0.40109,0.13989,0.42473,0.383,0.3529,-0.288,0.2279,-0.77467,0.41608,0.139,0.45546,0.4,0.3416,-0.308,0.2129,-0.75423,0.41957,0.13153,0.48765,0.417,0.33,-0.3216,0.2076,-0.73898,0.41177,0.11704,0.52024,0.433,0.3184,-0.3288,0.2123,-0.72918,0.39288,0.0954,0.55212,0.45,0.3062,-0.3305,0.2254,-0.72347,0.36423,0.06741,0.58257,0.467,0.2931,-0.3279,0.2443,-0.72002,0.32743,0.03433,0.61088,0.483,0.2789,-0.3222,0.2664,-0.71714,0.28415,-0.00222,0.63637,0.5,0.2643,-0.3143,0.2894,-0.7134,0.23629,-0.04025,0.65849,0.517,0.2505,-0.3054,0.3115,-0.7079,0.18602,-0.07744,0.67696},
		["Left Leg"] = {0,0.0179,-0.0121,-0.0005,0.01382,0.01668,0.09776,0.99497,0.017,-0.0559,-0.1161,-0.0373,0.12039,-0.00319,-0.00225,0.99272,0.033,-0.1704,-0.2071,-0.1037,0.23459,-0.02786,-0.11643,0.96469,0.05,-0.3117,-0.2554,-0.1869,0.33169,-0.05408,-0.22162,0.91539,0.067,-0.4537,-0.2546,-0.2615,0.39401,-0.07923,-0.29903,0.86548,0.083,-0.5783,-0.2195,-0.3094,0.41732,-0.10279,-0.34246,0.83546,0.1,-0.6842,-0.1673,-0.3321,0.41152,-0.12521,-0.35966,0.82802,0.117,-0.7743,-0.1059,-0.3358,0.38518,-0.14638,-0.35761,0.83805,0.133,-0.8506,-0.0385,-0.3264,0.34471,-0.16544,-0.34105,0.85877,0.15,-0.9144,0.0311,-0.3096,0.2968,-0.18108,-0.31455,0.88328,0.167,-0.9664,0.0974,-0.2894,0.24954,-0.19201,-0.28368,0.90575,0.183,-1.0067,0.1535,-0.2676,0.2105,-0.19763,-0.25405,0.92309,0.2,-1.0357,0.1985,-0.2434,0.18079,-0.19868,-0.2273,0.93604,0.217,-1.0541,0.2335,-0.2165,0.15946,-0.19618,-0.20367,0.94584,0.233,-1.0629,0.2597,-0.1871,0.1453,-0.19104,-0.18314,0.95334,0.25,-1.0629,0.2789,-0.1558,0.137,-0.18409,-0.16552,0.95914,0.267,-1.0552,0.2926,-0.1235,0.13326,-0.17607,-0.15059,0.96362,0.283,-1.041,0.3024,-0.0911,0.13281,-0.16764,-0.13805,0.96706,0.3,-1.0215,0.3099,-0.0599,0.13447,-0.15941,-0.12762,0.96965,0.317,-0.9979,0.3166,-0.0307,0.13707,-0.15196,-0.11903,0.97157,0.333,-0.9717,0.324,-0.0047,0.13955,-0.14585,-0.11203,0.97299,0.35,-0.9441,0.3334,0.0171,0.14081,-0.14162,-0.10636,0.97407,0.367,-0.9162,0.346,0.034,0.14008,-0.13965,-0.10184,0.97494,0.383,-0.8883,0.3615,0.0462,0.13752,-0.13965,-0.09849,0.97565,0.4,-0.8604,0.3792,0.0541,0.13354,-0.14117,-0.0964,0.97619,0.417,-0.8323,0.3987,0.058,0.12854,-0.14376,-0.09566,0.97655,0.433,-0.804,0.4194,0.0585,0.12293,-0.14699,-0.0964,0.97672,0.45,-0.7756,0.4407,0.0558,0.11709,-0.15042,-0.09875,0.97668,0.467,-0.7469,0.4621,0.0505,0.11146,-0.1536,-0.10286,0.97642,0.483,-0.7179,0.4829,0.0431,0.10646,-0.15605,-0.10887,0.97594,0.5,-0.6884,0.5026,0.034,0.10256,-0.1573,-0.11696,0.97522,0.517,-0.6584,0.5204,0.0237,0.10025,-0.15682,-0.12729,0.97425},
		["Right Arm"] = {0,0,0,0,0,0,0,1,0.017,-0.0095,-0.004,0.0696,-0.06731,0.0507,0.02292,0.99618,0.033,-0.0171,-0.0086,0.1434,-0.14093,0.11595,0.05119,0.98187,0.05,-0.0234,-0.013,0.2161,-0.21522,0.19373,0.07966,0.95384,0.067,-0.0295,-0.018,0.2834,-0.28447,0.27907,0.10311,0.91135,0.083,-0.0373,-0.0253,0.3433,-0.34457,0.36481,0.11734,0.85698,0.1,-0.0478,-0.0361,0.3962,-0.39432,0.44335,0.12007,0.79595,0.117,-0.061,-0.05,0.4436,-0.43564,0.5083,0.11102,0.73452,0.133,-0.076,-0.0652,0.4867,-0.47269,0.55512,0.09133,0.67828,0.15,-0.0913,-0.079,0.5256,-0.50996,0.58117,0.06304,0.63104,0.167,-0.1059,-0.0894,0.5583,-0.54964,0.5863,0.0296,0.59436,0.183,-0.1197,-0.0955,0.5823,-0.59213,0.57122,-0.00644,0.56837,0.2,-0.1342,-0.0976,0.5968,-0.63618,0.53797,-0.04379,0.55131,0.217,-0.1512,-0.0973,0.601,-0.67944,0.48869,-0.08162,0.54118,0.233,-0.1717,-0.0965,0.5947,-0.71907,0.42555,-0.11925,0.5363,0.25,-0.1959,-0.0979,0.5778,-0.75218,0.35122,-0.15597,0.5353,0.267,-0.2228,-0.1037,0.5505,-0.77624,0.26902,-0.19099,0.53721,0.283,-0.2505,-0.1158,0.5143,-0.78959,0.1829,-0.22346,0.54144,0.3,-0.2765,-0.1345,0.471,-0.79163,0.09718,-0.25247,0.54784,0.317,-0.2984,-0.1594,0.4235,-0.78299,0.01618,-0.27716,0.55664,0.333,-0.3147,-0.1887,0.375,-0.76534,-0.05609,-0.29663,0.56843,0.35,-0.3247,-0.2205,0.329,-0.74113,-0.11622,-0.30996,0.58408,0.367,-0.3288,-0.2527,0.2889,-0.71296,-0.16191,-0.31637,0.60447,0.383,-0.3285,-0.2839,0.2564,-0.68262,-0.1929,-0.3162,0.62995,0.4,-0.3252,-0.3133,0.2329,-0.65095,-0.20933,-0.30993,0.6606,0.417,-0.3202,-0.3407,0.2191,-0.61784,-0.21095,-0.29787,0.69645,0.433,-0.3138,-0.3665,0.2146,-0.58243,-0.1976,-0.28009,0.73708,0.45,-0.306,-0.3915,0.2169,-0.54381,-0.17108,-0.25627,0.78059,0.467,-0.2963,-0.4156,0.2228,-0.50148,-0.13358,-0.22627,0.8243,0.483,-0.2851,-0.4382,0.2296,-0.45573,-0.08726,-0.19052,0.8651,0.5,-0.2729,-0.4577,0.235,-0.40799,-0.0344,-0.15011,0.8999,0.517,-0.2612,-0.4722,0.2386,-0.361,0.02256,-0.10685,0.92615},
		["Right Leg"] = {0,0,0,0,0,0,0,1,0.017,-0.0077,0.2227,-0.0641,-0.01458,-0.0067,0.01731,0.99972,0.033,-0.0009,0.4807,-0.134,-0.03067,-0.01419,0.03639,0.99877,0.05,0.0217,0.7524,-0.204,-0.04768,-0.02207,0.05605,0.99704,0.067,0.0616,1.0162,-0.2683,-0.06501,-0.02994,0.07509,0.9946,0.083,0.1204,1.2505,-0.321,-0.08208,-0.0374,0.09231,0.99164,0.1,0.1997,1.434,-0.3562,-0.0983,-0.04407,0.10655,0.98845,0.117,0.3012,1.5453,-0.3677,-0.11312,-0.04955,0.11668,0.98546,0.133,0.4238,1.5711,-0.352,-0.12612,-0.0536,0.12191,0.98304,0.15,0.5547,1.5301,-0.3156,-0.13727,-0.05628,0.12266,0.9813,0.167,0.678,1.4486,-0.2677,-0.14662,-0.05777,0.11963,0.98023,0.183,0.778,1.3531,-0.2174,-0.1542,-0.05825,0.11353,0.97977,0.2,0.8423,1.2653,-0.1724,-0.16007,-0.05788,0.10503,0.97979,0.217,0.8736,1.188,-0.134,-0.16424,-0.05682,0.09483,0.98021,0.233,0.8781,1.1194,-0.1019,-0.16675,-0.05523,0.08359,0.9809,0.25,0.862,1.0578,-0.0759,-0.16764,-0.05328,0.07199,0.98177,0.267,0.8317,1.0014,-0.0556,-0.16693,-0.05113,0.06071,0.98277,0.283,0.7933,0.9484,-0.041,-0.16466,-0.04894,0.05043,0.98384,0.3,0.7531,0.8971,-0.0317,-0.16087,-0.04688,0.04182,0.98497,0.317,0.7162,0.8461,-0.0275,-0.15564,-0.04508,0.0354,0.98615,0.333,0.6837,0.7957,-0.0277,-0.14918,-0.04354,0.03107,0.98736,0.35,0.6553,0.7463,-0.0318,-0.14175,-0.04226,0.02857,0.98859,0.367,0.6311,0.6985,-0.0389,-0.13358,-0.04119,0.02765,0.98979,0.383,0.6109,0.6529,-0.0483,-0.12495,-0.04033,0.02803,0.99095,0.4,0.5947,0.61,-0.0593,-0.1161,-0.03965,0.02948,0.99201,0.417,0.5822,0.5704,-0.0711,-0.10729,-0.03912,0.03173,0.99295,0.433,0.5735,0.5346,-0.083,-0.09878,-0.03873,0.03453,0.99375,0.45,0.5683,0.5032,-0.0942,-0.09085,-0.03846,0.03761,0.99441,0.467,0.5665,0.4768,-0.1039,-0.08375,-0.03828,0.04072,0.99492,0.483,0.5679,0.4559,-0.1112,-0.07776,-0.03818,0.04359,0.99529,0.5,0.5724,0.4412,-0.1153,-0.07315,-0.03813,0.04597,0.99553,0.517,0.5798,0.4331,-0.1155,-0.07019,-0.03812,0.04758,0.99567},
		Torso = {0,0.2184,-0.1253,-0.0322,0.06146,0.11105,-0.01525,0.9918,0.017,0.7133,-0.1617,-0.0016,0.04562,0.13477,-0.07653,0.98686,0.033,1.2754,-0.208,0.0288,0.02679,0.16399,-0.14631,0.97518,0.05,1.8367,-0.2611,0.0527,0.00693,0.19511,-0.21488,0.95693,0.067,2.3294,-0.3135,0.0656,-0.01192,0.22499,-0.27298,0.93526,0.083,2.7009,-0.3565,0.0652,-0.02824,0.25176,-0.31458,0.9148,0.1,2.9555,-0.3874,0.0532,-0.04206,0.27575,-0.34125,0.89763,0.117,3.1112,-0.4064,0.0317,-0.05374,0.29757,-0.35596,0.88423,0.133,3.1857,-0.4143,0.0031,-0.06359,0.31763,-0.36123,0.8744,0.15,3.1964,-0.4126,-0.0305,-0.07188,0.33615,-0.35927,0.86762,0.167,3.1605,-0.4034,-0.0669,-0.07879,0.3532,-0.35211,0.86317,0.183,3.0948,-0.3891,-0.1037,-0.08449,0.36875,-0.34173,0.8603,0.2,3.0161,-0.3725,-0.1386,-0.0891,0.38272,-0.33015,0.85825,0.217,2.9384,-0.3564,-0.1695,-0.09274,0.39503,-0.31915,0.85644,0.233,2.8647,-0.3413,-0.1962,-0.09546,0.40573,-0.30909,0.85483,0.25,2.795,-0.3275,-0.2185,-0.09732,0.41488,-0.29999,0.85347,0.267,2.7292,-0.3149,-0.2366,-0.09836,0.42258,-0.29184,0.8524,0.283,2.6674,-0.3037,-0.2506,-0.09864,0.42892,-0.28462,0.85164,0.3,2.6095,-0.2938,-0.2608,-0.0982,0.43396,-0.27832,0.85122,0.317,2.5555,-0.2853,-0.2672,-0.09712,0.43781,-0.27289,0.85113,0.333,2.5053,-0.278,-0.2701,-0.09544,0.44055,-0.2683,0.85136,0.35,2.4589,-0.2721,-0.2699,-0.09322,0.44226,-0.2645,0.85191,0.367,2.416,-0.2674,-0.2667,-0.09052,0.44302,-0.26145,0.85275,0.383,2.3765,-0.2639,-0.2609,-0.08738,0.44291,-0.25909,0.85385,0.4,2.3403,-0.2615,-0.2528,-0.08388,0.44202,-0.25737,0.85519,0.417,2.3072,-0.26,-0.2425,-0.08006,0.44043,-0.25624,0.85671,0.433,2.2771,-0.2595,-0.2305,-0.07598,0.4382,-0.25564,0.8584,0.45,2.2498,-0.2598,-0.2171,-0.07169,0.43544,-0.25552,0.86021,0.467,2.2251,-0.2609,-0.2025,-0.06725,0.43221,-0.25581,0.86211,0.483,2.2029,-0.2625,-0.187,-0.06272,0.42859,-0.25646,0.86406,0.5,2.183,-0.2647,-0.1709,-0.05815,0.42467,-0.25742,0.86603,0.517,2.1654,-0.2673,-0.1544,-0.05359,0.42053,-0.25862,0.86799},
	}},
	DashRight = {len = 0.5, parts = {
		Head = {0,0,0,0,0,0,0,1,0.017,0,0,0,0.01925,0.03594,-0.05625,0.99758,0.033,0,0,0,0.04195,0.08179,-0.12338,0.98809,0.05,0,0,0,0.06502,0.13237,-0.19238,0.97018,0.067,0,0,0,0.08522,0.18197,-0.25356,0.94622,0.083,0,0,0,0.09967,0.22548,-0.29841,0.92205,0.1,0,0,0,0.10684,0.25998,-0.32222,0.90398,0.117,0,0,0,0.10826,0.28684,-0.32887,0.89322,0.133,0,0,0,0.10594,0.30802,-0.32355,0.88838,0.15,0,0,0,0.10171,0.32512,-0.31091,0.88729,0.167,0,0,0,0.09732,0.33958,-0.29538,0.88767,0.183,0,0,0,0.0942,0.35255,-0.28063,0.88774,0.2,0,0,0,0.09249,0.36434,-0.26735,0.88726,0.217,0,0,0,0.09201,0.37498,-0.25551,0.88636,0.233,0,0,0,0.09261,0.38454,-0.24504,0.88516,0.25,0,0,0,0.0941,0.39305,-0.23591,0.88374,0.267,0,0,0,0.09633,0.40054,-0.22808,0.8822,0.283,0,0,0,0.09913,0.40702,-0.22149,0.8806,0.3,0,0,0,0.10234,0.41252,-0.21611,0.87901,0.317,0,0,0,0.10579,0.41703,-0.21191,0.87749,0.333,0,0,0,0.10931,0.42057,-0.20885,0.8761,0.35,0,0,0,0.11274,0.42313,-0.20688,0.8749,0.367,0,0,0,0.11591,0.4247,-0.20599,0.87394,0.383,0,0,0,0.11864,0.42528,-0.20614,0.87325,0.4,0,0,0,0.12076,0.42486,-0.20728,0.8729,0.417,0,0,0,0.12212,0.42344,-0.20938,0.87289,0.433,0,0,0,0.12277,0.42111,-0.21234,0.87322,0.45,0,0,0,0.12277,0.41798,-0.21604,0.87381,0.467,0,0,0,0.12219,0.41415,-0.22036,0.87464,0.483,0,0,0,0.12111,0.40972,-0.22521,0.87564,0.5,0,0,0,0.11959,0.40482,-0.23045,0.87676},
		["Left Arm"] = {0,0,0,0,0,0,0,1,0.017,0.0095,-0.004,0.0696,-0.06731,-0.0507,-0.02292,0.99618,0.033,0.0171,-0.0086,0.1434,-0.14093,-0.11595,-0.05119,0.98187,0.05,0.0234,-0.013,0.2161,-0.21522,-0.19373,-0.07966,0.95384,0.067,0.0295,-0.018,0.2834,-0.28447,-0.27907,-0.10311,0.91135,0.083,0.0373,-0.0253,0.3433,-0.34457,-0.36481,-0.11734,0.85698,0.1,0.0478,-0.0361,0.3962,-0.39432,-0.44335,-0.12007,0.79595,0.117,0.061,-0.05,0.4436,-0.43564,-0.5083,-0.11102,0.73452,0.133,0.076,-0.0652,0.4867,-0.47269,-0.55512,-0.09133,0.67828,0.15,0.0913,-0.079,0.5256,-0.50996,-0.58117,-0.06304,0.63104,0.167,0.1059,-0.0894,0.5583,-0.54964,-0.5863,-0.0296,0.59436,0.183,0.1197,-0.0955,0.5823,-0.59213,-0.57122,0.00644,0.56837,0.2,0.1342,-0.0976,0.5968,-0.63618,-0.53797,0.04379,0.55131,0.217,0.1512,-0.0973,0.601,-0.67944,-0.48869,0.08162,0.54118,0.233,0.1717,-0.0965,0.5947,-0.71907,-0.42555,0.11925,0.5363,0.25,0.1959,-0.0979,0.5778,-0.75218,-0.35122,0.15597,0.5353,0.267,0.2228,-0.1037,0.5505,-0.77624,-0.26902,0.19099,0.53721,0.283,0.2505,-0.1158,0.5143,-0.78959,-0.1829,0.22346,0.54144,0.3,0.2765,-0.1345,0.471,-0.79163,-0.09718,0.25247,0.54784,0.317,0.2984,-0.1594,0.4235,-0.78299,-0.01618,0.27716,0.55664,0.333,0.3147,-0.1887,0.375,-0.76534,0.05609,0.29663,0.56843,0.35,0.3247,-0.2205,0.329,-0.74113,0.11622,0.30996,0.58408,0.367,0.3288,-0.2527,0.2889,-0.71296,0.16191,0.31637,0.60447,0.383,0.3285,-0.2839,0.2564,-0.68262,0.1929,0.3162,0.62995,0.4,0.3252,-0.3133,0.2329,-0.65095,0.20933,0.30993,0.6606,0.417,0.3202,-0.3407,0.2191,-0.61784,0.21095,0.29787,0.69645,0.433,0.3138,-0.3665,0.2146,-0.58243,0.1976,0.28009,0.73708,0.45,0.306,-0.3915,0.2169,-0.54381,0.17108,0.25627,0.78059,0.467,0.2963,-0.4156,0.2228,-0.50148,0.13358,0.22627,0.8243,0.483,0.2851,-0.4382,0.2296,-0.45573,0.08726,0.19052,0.8651,0.5,0.2729,-0.4577,0.235,-0.40799,0.0344,0.15011,0.8999},
		["Left Leg"] = {0,0,0,0,0,0,0,1,0.017,0.0077,0.2227,-0.0641,-0.01458,0.0067,-0.01731,0.99972,0.033,0.0009,0.4807,-0.134,-0.03067,0.01419,-0.03639,0.99877,0.05,-0.0217,0.7524,-0.204,-0.04768,0.02207,-0.05605,0.99704,0.067,-0.0616,1.0162,-0.2683,-0.06501,0.02994,-0.07509,0.9946,0.083,-0.1204,1.2505,-0.321,-0.08208,0.0374,-0.09231,0.99164,0.1,-0.1997,1.434,-0.3562,-0.0983,0.04407,-0.10655,0.98845,0.117,-0.3012,1.5453,-0.3677,-0.11312,0.04955,-0.11668,0.98546,0.133,-0.4238,1.5711,-0.352,-0.12612,0.0536,-0.12191,0.98304,0.15,-0.5547,1.5301,-0.3156,-0.13727,0.05628,-0.12266,0.9813,0.167,-0.678,1.4486,-0.2677,-0.14662,0.05777,-0.11963,0.98023,0.183,-0.778,1.3531,-0.2174,-0.1542,0.05825,-0.11353,0.97977,0.2,-0.8423,1.2653,-0.1724,-0.16007,0.05788,-0.10503,0.97979,0.217,-0.8736,1.188,-0.134,-0.16424,0.05682,-0.09483,0.98021,0.233,-0.8781,1.1194,-0.1019,-0.16675,0.05523,-0.08359,0.9809,0.25,-0.862,1.0578,-0.0759,-0.16764,0.05328,-0.07199,0.98177,0.267,-0.8317,1.0014,-0.0556,-0.16693,0.05113,-0.06071,0.98277,0.283,-0.7933,0.9484,-0.041,-0.16466,0.04894,-0.05043,0.98384,0.3,-0.7531,0.8971,-0.0317,-0.16087,0.04688,-0.04182,0.98497,0.317,-0.7162,0.8461,-0.0275,-0.15564,0.04508,-0.0354,0.98615,0.333,-0.6837,0.7957,-0.0277,-0.14918,0.04354,-0.03107,0.98736,0.35,-0.6553,0.7463,-0.0318,-0.14175,0.04226,-0.02857,0.98859,0.367,-0.6311,0.6985,-0.0389,-0.13358,0.04119,-0.02765,0.98979,0.383,-0.6109,0.6529,-0.0483,-0.12495,0.04033,-0.02803,0.99095,0.4,-0.5947,0.61,-0.0593,-0.1161,0.03965,-0.02948,0.99201,0.417,-0.5822,0.5704,-0.0711,-0.10729,0.03912,-0.03173,0.99295,0.433,-0.5735,0.5346,-0.083,-0.09878,0.03873,-0.03453,0.99375,0.45,-0.5683,0.5032,-0.0942,-0.09085,0.03846,-0.03761,0.99441,0.467,-0.5665,0.4768,-0.1039,-0.08375,0.03828,-0.04072,0.99492,0.483,-0.5679,0.4559,-0.1112,-0.07776,0.03818,-0.04359,0.99529,0.5,-0.5724,0.4412,-0.1153,-0.07315,0.03813,-0.04597,0.99553},
		["Right Arm"] = {0,0,0,0,0,0,0,1,0.017,0.0045,-0.0025,0.0595,-0.05898,-0.00434,0.03631,0.99759,0.033,0.0046,-0.0029,0.139,-0.14393,0.00049,0.07961,0.98638,0.05,-0.0002,0.0054,0.2314,-0.25243,0.018,0.12422,0.95944,0.067,-0.0104,0.027,0.3255,-0.37746,0.04973,0.16293,0.91022,0.083,-0.0263,0.06,0.408,-0.50652,0.09322,0.18835,0.83623,0.1,-0.0476,0.0952,0.4695,-0.62488,0.14139,0.19583,0.74242,0.117,-0.0734,0.1221,0.5094,-0.72189,0.18473,0.18559,0.64056,0.133,-0.1028,0.1349,0.5336,-0.79492,0.21466,0.16205,0.54383,0.15,-0.1345,0.1345,0.5482,-0.84773,0.22594,0.13124,0.46161,0.167,-0.1668,0.1246,0.5559,-0.88557,0.21811,0.0989,0.39802,0.183,-0.1983,0.1085,0.5569,-0.91287,0.19283,0.06816,0.35332,0.2,-0.2287,0.0884,0.5514,-0.9327,0.15318,0.03983,0.32407,0.217,-0.258,0.0648,0.5393,-0.94618,0.10213,0.01382,0.30681,0.233,-0.2859,0.0375,0.5209,-0.95328,0.04244,-0.01026,0.29892,0.25,-0.3117,0.0062,0.4965,-0.95357,-0.0231,-0.03281,0.2985,0.267,-0.3343,-0.0293,0.4667,-0.94668,-0.09155,-0.05411,0.30414,0.283,-0.3526,-0.0684,0.4326,-0.93264,-0.15987,-0.07424,0.31481,0.3,-0.3657,-0.1099,0.3952,-0.91211,-0.22503,-0.09304,0.3298,0.317,-0.373,-0.152,0.3563,-0.88637,-0.28413,-0.11001,0.34859,0.333,-0.3745,-0.1927,0.3177,-0.85737,-0.33455,-0.12432,0.37085,0.35,-0.3709,-0.2299,0.2819,-0.82757,-0.37404,-0.13474,0.39632,0.367,-0.3632,-0.2619,0.2514,-0.79948,-0.40109,-0.13989,0.42473,0.383,-0.3529,-0.288,0.2279,-0.77467,-0.41608,-0.139,0.45546,0.4,-0.3416,-0.308,0.2129,-0.75423,-0.41957,-0.13153,0.48765,0.417,-0.33,-0.3216,0.2076,-0.73898,-0.41177,-0.11704,0.52024,0.433,-0.3184,-0.3288,0.2123,-0.72918,-0.39288,-0.0954,0.55212,0.45,-0.3062,-0.3305,0.2254,-0.72347,-0.36423,-0.06741,0.58257,0.467,-0.2931,-0.3279,0.2443,-0.72002,-0.32743,-0.03433,0.61088,0.483,-0.2789,-0.3222,0.2664,-0.71714,-0.28415,0.00222,0.63637,0.5,-0.2643,-0.3143,0.2894,-0.7134,-0.23629,0.04025,0.65849},
		["Right Leg"] = {0,-0.0179,-0.0121,-0.0005,0.01382,-0.01668,-0.09776,0.99497,0.017,0.0559,-0.1161,-0.0373,0.12039,0.00319,0.00225,0.99272,0.033,0.1704,-0.2071,-0.1037,0.23459,0.02786,0.11643,0.96469,0.05,0.3117,-0.2554,-0.1869,0.33169,0.05408,0.22162,0.91539,0.067,0.4537,-0.2546,-0.2615,0.39401,0.07923,0.29903,0.86548,0.083,0.5783,-0.2195,-0.3094,0.41732,0.10279,0.34246,0.83546,0.1,0.6843,-0.1673,-0.3321,0.41152,0.12521,0.35966,0.82802,0.117,0.7744,-0.1059,-0.3358,0.38518,0.14638,0.35761,0.83805,0.133,0.8506,-0.0385,-0.3264,0.34471,0.16544,0.34105,0.85877,0.15,0.9144,0.0311,-0.3096,0.2968,0.18108,0.31455,0.88328,0.167,0.9665,0.0974,-0.2894,0.24954,0.19201,0.28368,0.90575,0.183,1.0067,0.1535,-0.2675,0.2105,0.19763,0.25405,0.92309,0.2,1.0357,0.1985,-0.2434,0.18079,0.19868,0.2273,0.93604,0.217,1.0541,0.2334,-0.2165,0.15946,0.19618,0.20367,0.94584,0.233,1.0629,0.2597,-0.1871,0.1453,0.19104,0.18314,0.95334,0.25,1.0629,0.2789,-0.1558,0.137,0.18409,0.16552,0.95914,0.267,1.0552,0.2926,-0.1235,0.13326,0.17607,0.15059,0.96362,0.283,1.041,0.3024,-0.0911,0.13281,0.16764,0.13805,0.96706,0.3,1.0215,0.3099,-0.0599,0.13447,0.15941,0.12762,0.96965,0.317,0.9979,0.3166,-0.0307,0.13707,0.15196,0.11903,0.97157,0.333,0.9717,0.3239,-0.0047,0.13955,0.14585,0.11203,0.97299,0.35,0.9441,0.3334,0.0171,0.14081,0.14162,0.10636,0.97407,0.367,0.9162,0.346,0.034,0.14008,0.13965,0.10184,0.97494,0.383,0.8883,0.3615,0.0462,0.13752,0.13965,0.09849,0.97565,0.4,0.8604,0.3792,0.0541,0.13354,0.14117,0.0964,0.97619,0.417,0.8323,0.3987,0.058,0.12854,0.14376,0.09566,0.97655,0.433,0.8041,0.4194,0.0585,0.12293,0.14699,0.0964,0.97672,0.45,0.7756,0.4407,0.0558,0.11709,0.15042,0.09875,0.97668,0.467,0.7469,0.4621,0.0505,0.11146,0.1536,0.10286,0.97642,0.483,0.7179,0.4829,0.0431,0.10646,0.15605,0.10887,0.97594,0.5,0.6884,0.5026,0.034,0.10256,0.1573,0.11696,0.97522},
		Torso = {0,-0.2184,-0.1253,-0.0322,0.06146,-0.11105,0.01525,0.9918,0.017,-0.7133,-0.1617,-0.0016,0.04562,-0.13477,0.07653,0.98686,0.033,-1.2754,-0.208,0.0288,0.02679,-0.16399,0.14631,0.97518,0.05,-1.8367,-0.2611,0.0527,0.00693,-0.19511,0.21488,0.95693,0.067,-2.3294,-0.3135,0.0656,-0.01192,-0.22499,0.27298,0.93526,0.083,-2.7009,-0.3565,0.0652,-0.02824,-0.25176,0.31458,0.9148,0.1,-2.9555,-0.3874,0.0532,-0.04206,-0.27575,0.34125,0.89763,0.117,-3.1112,-0.4064,0.0317,-0.05374,-0.29757,0.35596,0.88423,0.133,-3.1857,-0.4143,0.0031,-0.06359,-0.31763,0.36123,0.8744,0.15,-3.1964,-0.4126,-0.0305,-0.07188,-0.33615,0.35927,0.86762,0.167,-3.1605,-0.4034,-0.0669,-0.07879,-0.3532,0.35211,0.86317,0.183,-3.0948,-0.3891,-0.1037,-0.08449,-0.36875,0.34173,0.8603,0.2,-3.0161,-0.3725,-0.1386,-0.0891,-0.38272,0.33015,0.85825,0.217,-2.9384,-0.3564,-0.1695,-0.09274,-0.39503,0.31915,0.85644,0.233,-2.8647,-0.3413,-0.1962,-0.09546,-0.40573,0.30909,0.85483,0.25,-2.795,-0.3275,-0.2185,-0.09732,-0.41488,0.29999,0.85347,0.267,-2.7292,-0.3149,-0.2366,-0.09836,-0.42258,0.29184,0.8524,0.283,-2.6674,-0.3037,-0.2506,-0.09864,-0.42892,0.28462,0.85164,0.3,-2.6095,-0.2938,-0.2608,-0.0982,-0.43396,0.27832,0.85122,0.317,-2.5555,-0.2853,-0.2672,-0.09712,-0.43781,0.27289,0.85113,0.333,-2.5053,-0.278,-0.2701,-0.09544,-0.44055,0.2683,0.85136,0.35,-2.4589,-0.2721,-0.2699,-0.09322,-0.44226,0.2645,0.85191,0.367,-2.416,-0.2674,-0.2667,-0.09052,-0.44302,0.26145,0.85275,0.383,-2.3765,-0.2639,-0.2609,-0.08738,-0.44291,0.25909,0.85385,0.4,-2.3403,-0.2615,-0.2528,-0.08388,-0.44202,0.25737,0.85519,0.417,-2.3072,-0.26,-0.2425,-0.08006,-0.44043,0.25624,0.85671,0.433,-2.2771,-0.2595,-0.2305,-0.07598,-0.4382,0.25564,0.8584,0.45,-2.2498,-0.2598,-0.2171,-0.07169,-0.43544,0.25552,0.86021,0.467,-2.2251,-0.2609,-0.2025,-0.06725,-0.43221,0.25581,0.86211,0.483,-2.2029,-0.2625,-0.187,-0.06272,-0.42859,0.25646,0.86406,0.5,-2.183,-0.2647,-0.1709,-0.05815,-0.42467,0.25742,0.86603},
	}},
	-- Idle (locomoção embutida, extraída do mesmo .rbxm do dash)
	idle = {len = 1.8833, parts = {
		Head = {0,0,0,0.01666,0.01413,-0.00045,0.00474,0.99989,0.0167,0,0,0.01666,0.01455,-0.00045,0.00474,0.99988,0.0333,0,0,0.01666,0.01498,-0.00045,0.00474,0.99988,0.05,0,0,0.01666,0.01542,-0.00045,0.00474,0.99987,0.0667,0,0,0.01666,0.01587,-0.00046,0.00474,0.99986,0.0833,0,0,0.01666,0.01633,-0.00046,0.00474,0.99986,0.1,0,0,0.01666,0.01679,-0.00046,0.00474,0.99985,0.1167,0,0,0.01666,0.01726,-0.00046,0.00474,0.99984,0.1333,0,0,0.01666,0.01774,-0.00046,0.00474,0.99983,0.15,0,0,0.01666,0.01821,-0.00047,0.00474,0.99982,0.1667,0,0,0.01666,0.01869,-0.00047,0.00474,0.99981,0.1833,0,0,0.01666,0.01916,-0.00047,0.00474,0.99981,0.2,0,0,0.01666,0.01964,-0.00047,0.00474,0.9998,0.2167,0,0,0.01666,0.02011,-0.00048,0.00474,0.99979,0.2333,0,0,0.01666,0.02058,-0.00048,0.00474,0.99978,0.25,0,0,0.01666,0.02104,-0.00048,0.00474,0.99977,0.2667,0,0,0.01666,0.02149,-0.00048,0.00474,0.99976,0.2833,0,0,0.01666,0.02194,-0.00048,0.00474,0.99975,0.3,0,0,0.01666,0.02237,-0.00049,0.00474,0.99974,0.3167,0,0,0.01666,0.0228,-0.00049,0.00474,0.99973,0.3333,0,0,0.01666,0.02321,-0.00049,0.00474,0.99972,0.35,0,0,0.01666,0.02361,-0.00049,0.00474,0.99971,0.3667,0,0,0.01666,0.02399,-0.00049,0.00474,0.9997,0.3833,0,0,0.01666,0.02436,-0.0005,0.00474,0.99969,0.4,0,0,0.01666,0.02471,-0.0005,0.00474,0.99968,0.4167,0,0,0.01666,0.02503,-0.0005,0.00474,0.99968,0.4333,0,0,0.01666,0.02534,-0.0005,0.00474,0.99967,0.45,0,0,0.01666,0.02563,-0.0005,0.00474,0.99966,0.4667,0,0,0.01666,0.02589,-0.0005,0.00474,0.99965,0.4833,0,0,0.01666,0.02613,-0.0005,0.00474,0.99965,0.5,0,0,0.01666,0.02635,-0.0005,0.00474,0.99964,0.5167,0,0,0.01666,0.02653,-0.00051,0.00474,0.99964,0.5333,0,0,0.01666,0.02669,-0.00051,0.00474,0.99963,0.55,0,0,0.01666,0.02682,-0.00051,0.00474,0.99963,0.5667,0,0,0.01666,0.02692,-0.00051,0.00474,0.99963,0.5833,0,0,0.01666,0.02698,-0.00051,0.00474,0.99962,0.6,0,0,0.01666,0.02701,-0.00051,0.00474,0.99962,0.6167,0,0,0.01666,0.02701,-0.00051,0.00474,0.99962,0.6333,0,0,0.01666,0.02696,-0.00051,0.00474,0.99963,0.65,0,0,0.01666,0.02688,-0.00051,0.00474,0.99963,0.6667,0,0,0.01666,0.02677,-0.00051,0.00474,0.99963,0.6833,0,0,0.01666,0.02661,-0.00051,0.00474,0.99963,0.7,0,0,0.01666,0.02641,-0.00051,0.00474,0.99964,0.7167,0,0,0.01666,0.02618,-0.0005,0.00474,0.99965,0.7333,0,0,0.01666,0.02591,-0.0005,0.00474,0.99965,0.75,0,0,0.01666,0.02561,-0.0005,0.00474,0.99966,0.7667,0,0,0.01666,0.02527,-0.0005,0.00474,0.99967,0.7833,0,0,0.01666,0.02491,-0.0005,0.00474,0.99968,0.8,0,0,0.01666,0.02453,-0.0005,0.00474,0.99969,0.8167,0,0,0.01666,0.02412,-0.00049,0.00474,0.9997,0.8333,0,0,0.01666,0.02368,-0.00049,0.00474,0.99971,0.85,0,0,0.01666,0.02323,-0.00049,0.00474,0.99972,0.8667,0,0,0.01666,0.02275,-0.00049,0.00474,0.99973,0.8833,0,0,0.01666,0.02226,-0.00049,0.00474,0.99974,0.9,0,0,0.01666,0.02176,-0.00048,0.00474,0.99975,0.9167,0,0,0.01666,0.02124,-0.00048,0.00474,0.99976,0.9333,0,0,0.01666,0.02072,-0.00048,0.00474,0.99977,0.95,0,0,0.01666,0.02018,-0.00048,0.00474,0.99979,0.9667,0,0,0.01666,0.01964,-0.00047,0.00474,0.9998,0.9833,0,0,0.01666,0.01909,-0.00047,0.00474,0.99981,1,0,0,0.01666,0.01854,-0.00047,0.00474,0.99982,1.0167,0,0,0.01666,0.01799,-0.00047,0.00474,0.99983,1.0333,0,0,0.01666,0.01744,-0.00046,0.00474,0.99984,1.05,0,0,0.01666,0.0169,-0.00046,0.00474,0.99985,1.0667,0,0,0.01666,0.01636,-0.00046,0.00474,0.99985,1.0833,0,0,0.01666,0.01583,-0.00045,0.00474,0.99986,1.1,0,0,0.01666,0.01531,-0.00045,0.00474,0.99987,1.1167,0,0,0.01666,0.0148,-0.00045,0.00474,0.99988,1.1333,0,0,0.01666,0.0143,-0.00045,0.00474,0.99989,1.15,0,0,0.01666,0.01382,-0.00045,0.00474,0.99989,1.1667,0,0,0.01666,0.01336,-0.00044,0.00474,0.9999,1.1833,0,0,0.01666,0.01291,-0.00044,0.00474,0.99991,1.2,0,0,0.01666,0.01249,-0.00044,0.00474,0.99991,1.2167,0,0,0.01666,0.01209,-0.00044,0.00474,0.99992,1.2333,0,0,0.01666,0.01172,-0.00044,0.00474,0.99992,1.25,0,0,0.01666,0.01137,-0.00043,0.00474,0.99992,1.2667,0,0,0.01666,0.01104,-0.00043,0.00474,0.99993,1.2833,0,0,0.01666,0.01075,-0.00043,0.00474,0.99993,1.3,0,0,0.01666,0.01047,-0.00043,0.00474,0.99993,1.3167,0,0,0.01666,0.01022,-0.00043,0.00474,0.99994,1.3333,0,0,0.01666,0.01,-0.00043,0.00474,0.99994,1.35,0,0,0.01666,0.00979,-0.00043,0.00474,0.99994,1.3667,0,0,0.01666,0.00962,-0.00043,0.00474,0.99994,1.3833,0,0,0.01666,0.00946,-0.00042,0.00474,0.99994,1.4,0,0,0.01666,0.00933,-0.00042,0.00474,0.99995,1.4167,0,0,0.01666,0.00922,-0.00042,0.00474,0.99995,1.4333,0,0,0.01666,0.00913,-0.00042,0.00474,0.99995,1.45,0,0,0.01666,0.00906,-0.00042,0.00474,0.99995,1.4667,0,0,0.01666,0.00902,-0.00042,0.00474,0.99995,1.4833,0,0,0.01666,0.00899,-0.00042,0.00474,0.99995,1.5,0,0,0.01666,0.00899,-0.00042,0.00474,0.99995,1.5167,0,0,0.01666,0.00901,-0.00042,0.00474,0.99995,1.5333,0,0,0.01666,0.00905,-0.00042,0.00474,0.99995,1.55,0,0,0.01666,0.00911,-0.00042,0.00474,0.99995,1.5667,0,0,0.01666,0.00919,-0.00042,0.00474,0.99995,1.5833,0,0,0.01666,0.00929,-0.00042,0.00474,0.99995,1.6,0,0,0.01666,0.00941,-0.00042,0.00474,0.99994,1.6167,0,0,0.01666,0.00955,-0.00043,0.00474,0.99994,1.6333,0,0,0.01666,0.0097,-0.00043,0.00474,0.99994,1.65,0,0,0.01666,0.00988,-0.00043,0.00474,0.99994,1.6667,0,0,0.01666,0.01007,-0.00043,0.00474,0.99994,1.6833,0,0,0.01666,0.01028,-0.00043,0.00474,0.99994,1.7,0,0,0.01666,0.01051,-0.00043,0.00474,0.99993,1.7167,0,0,0.01666,0.01076,-0.00043,0.00474,0.99993,1.7333,0,0,0.01666,0.01102,-0.00043,0.00474,0.99993,1.75,0,0,0.01666,0.01131,-0.00043,0.00474,0.99992,1.7667,0,0,0.01666,0.0116,-0.00043,0.00474,0.99992,1.7833,0,0,0.01666,0.01192,-0.00044,0.00474,0.99992,1.8,0,0,0.01666,0.01225,-0.00044,0.00474,0.99991,1.8167,0,0,0.01666,0.01259,-0.00044,0.00474,0.99991,1.8333,0,0,0.01666,0.01295,-0.00044,0.00474,0.9999,1.85,0,0,0.01666,0.01333,-0.00044,0.00474,0.9999,1.8667,0,0,0.01666,0.01372,-0.00044,0.00474,0.99989,1.8833,0,0,0.01666,0.01413,-0.00045,0.00474,0.99989},
		["Left Arm"] = {0,0.08223,-0.0731,-0.03837,-0.02045,0.06007,0.00043,0.99798,0.0167,0.08222,-0.07411,-0.03873,-0.02044,0.05996,0.00029,0.99799,0.0333,0.08222,-0.07515,-0.03909,-0.02044,0.05976,0.00016,0.998,0.05,0.08221,-0.07621,-0.03944,-0.02044,0.05947,0.00003,0.99802,0.0667,0.0822,-0.07731,-0.03979,-0.02044,0.05908,-0.0001,0.99804,0.0833,0.0822,-0.07842,-0.04014,-0.02044,0.05861,-0.00022,0.99807,0.1,0.08219,-0.07955,-0.04048,-0.02044,0.05807,-0.00033,0.9981,0.1167,0.08219,-0.0807,-0.04081,-0.02045,0.05744,-0.00044,0.99814,0.1333,0.08218,-0.08186,-0.04113,-0.02045,0.05674,-0.00055,0.99818,0.15,0.08218,-0.08303,-0.04145,-0.02046,0.05598,-0.00065,0.99822,0.1667,0.08217,-0.08421,-0.04175,-0.02047,0.05515,-0.00074,0.99827,0.1833,0.08217,-0.08538,-0.04205,-0.02048,0.05426,-0.00083,0.99832,0.2,0.08217,-0.08656,-0.04234,-0.02049,0.05331,-0.00091,0.99837,0.2167,0.08217,-0.08773,-0.04261,-0.02051,0.05231,-0.00099,0.99842,0.2333,0.08216,-0.08889,-0.04288,-0.02052,0.05126,-0.00106,0.99847,0.25,0.08216,-0.09004,-0.04313,-0.02054,0.05017,-0.00112,0.99853,0.2667,0.08216,-0.09118,-0.04337,-0.02055,0.04904,-0.00118,0.99858,0.2833,0.08216,-0.0923,-0.0436,-0.02057,0.04787,-0.00123,0.99864,0.3,0.08216,-0.09339,-0.04381,-0.02059,0.04667,-0.00128,0.9987,0.3167,0.08216,-0.09446,-0.04401,-0.02061,0.04544,-0.00132,0.99875,0.3333,0.08217,-0.09551,-0.04419,-0.02063,0.04418,-0.00135,0.99881,0.35,0.08217,-0.09652,-0.04436,-0.02065,0.04291,-0.00137,0.99886,0.3667,0.08217,-0.09749,-0.04451,-0.02067,0.04161,-0.00139,0.99892,0.3833,0.08217,-0.09843,-0.04465,-0.02069,0.04031,-0.0014,0.99897,0.4,0.08218,-0.09932,-0.04477,-0.02071,0.039,-0.00141,0.99902,0.4167,0.08218,-0.10017,-0.04487,-0.02073,0.03768,-0.00141,0.99907,0.4333,0.08218,-0.10097,-0.04495,-0.02076,0.03636,-0.0014,0.99912,0.45,0.08219,-0.10172,-0.04501,-0.02078,0.03505,-0.00138,0.99917,0.4667,0.08219,-0.10241,-0.04505,-0.0208,0.03374,-0.00135,0.99921,0.4833,0.0822,-0.10304,-0.04507,-0.02083,0.03245,-0.00132,0.99926,0.5,0.08221,-0.10361,-0.04507,-0.02085,0.03117,-0.00128,0.9993,0.5167,0.08221,-0.10412,-0.04505,-0.02087,0.02991,-0.00123,0.99933,0.5333,0.08222,-0.10455,-0.04501,-0.0209,0.02867,-0.00118,0.99937,0.55,0.08223,-0.10492,-0.04494,-0.02092,0.02747,-0.00111,0.9994,0.5667,0.08224,-0.1052,-0.04485,-0.02094,0.02629,-0.00104,0.99943,0.5833,0.08224,-0.10541,-0.04474,-0.02097,0.02515,-0.00096,0.99946,0.6,0.08225,-0.10554,-0.0446,-0.02099,0.02405,-0.00087,0.99949,0.6167,0.08226,-0.10558,-0.04444,-0.02101,0.02299,-0.00077,0.99951,0.6333,0.08227,-0.10553,-0.04425,-0.02104,0.02198,-0.00066,0.99954,0.65,0.08228,-0.10538,-0.04403,-0.02106,0.02102,-0.00055,0.99956,0.6667,0.08229,-0.10514,-0.04379,-0.02108,0.02012,-0.00042,0.99958,0.6833,0.0823,-0.1048,-0.04352,-0.0211,0.01928,-0.00029,0.99959,0.7,0.08231,-0.10437,-0.04322,-0.02112,0.01849,-0.00015,0.99961,0.7167,0.08233,-0.10385,-0.0429,-0.02114,0.01777,0,0.99962,0.7333,0.08234,-0.10324,-0.04256,-0.02116,0.0171,0.00016,0.99963,0.75,0.08235,-0.10255,-0.04219,-0.02118,0.01649,0.00032,0.99964,0.7667,0.08236,-0.10179,-0.04181,-0.0212,0.01594,0.00049,0.99965,0.7833,0.08237,-0.10095,-0.04141,-0.02121,0.01545,0.00066,0.99966,0.8,0.08239,-0.10005,-0.041,-0.02123,0.01502,0.00084,0.99966,0.8167,0.0824,-0.09909,-0.04057,-0.02125,0.01464,0.00102,0.99967,0.8333,0.08241,-0.09807,-0.04013,-0.02126,0.01433,0.0012,0.99967,0.85,0.08242,-0.097,-0.03968,-0.02127,0.01406,0.00139,0.99967,0.8667,0.08243,-0.09588,-0.03922,-0.02129,0.01386,0.00158,0.99968,0.8833,0.08245,-0.09472,-0.03875,-0.0213,0.01371,0.00176,0.99968,0.9,0.08246,-0.09353,-0.03828,-0.02131,0.01362,0.00195,0.99968,0.9167,0.08247,-0.0923,-0.03781,-0.02132,0.01358,0.00214,0.99968,0.9333,0.08248,-0.09104,-0.03734,-0.02133,0.0136,0.00232,0.99968,0.95,0.08249,-0.08976,-0.03687,-0.02134,0.01367,0.00251,0.99968,0.9667,0.0825,-0.08846,-0.03639,-0.02135,0.0138,0.00269,0.99967,0.9833,0.08252,-0.08715,-0.03593,-0.02135,0.01399,0.00287,0.99967,1,0.08253,-0.08583,-0.03547,-0.02136,0.01422,0.00304,0.99967,1.0167,0.08254,-0.08451,-0.03502,-0.02136,0.01452,0.00321,0.99966,1.0333,0.08254,-0.08319,-0.03457,-0.02137,0.01486,0.00337,0.99966,1.05,0.08255,-0.08187,-0.03414,-0.02137,0.01526,0.00353,0.99965,1.0667,0.08256,-0.08056,-0.03372,-0.02137,0.01571,0.00368,0.99964,1.0833,0.08257,-0.07927,-0.03332,-0.02137,0.01622,0.00382,0.99963,1.1,0.08258,-0.078,-0.03293,-0.02136,0.01678,0.00396,0.99962,1.1167,0.08258,-0.07676,-0.03256,-0.02136,0.01739,0.00408,0.99961,1.1333,0.08259,-0.07554,-0.03221,-0.02136,0.01805,0.0042,0.9996,1.15,0.08259,-0.07436,-0.03188,-0.02135,0.01877,0.00431,0.99959,1.1667,0.0826,-0.07322,-0.03158,-0.02134,0.01954,0.0044,0.99957,1.1833,0.0826,-0.07212,-0.0313,-0.02133,0.02036,0.00449,0.99956,1.2,0.0826,-0.07107,-0.03105,-0.02132,0.02123,0.00456,0.99954,1.2167,0.0826,-0.07008,-0.03083,-0.02131,0.02215,0.00462,0.99952,1.2333,0.0826,-0.06914,-0.03064,-0.0213,0.02312,0.00466,0.9995,1.25,0.0826,-0.06826,-0.03048,-0.02128,0.02413,0.00469,0.99947,1.2667,0.0826,-0.06744,-0.03034,-0.02127,0.0252,0.00471,0.99945,1.2833,0.0826,-0.06668,-0.03024,-0.02125,0.02629,0.00472,0.99942,1.3,0.08259,-0.06597,-0.03016,-0.02123,0.02743,0.00471,0.99939,1.3167,0.08259,-0.06532,-0.03011,-0.02121,0.0286,0.00469,0.99936,1.3333,0.08258,-0.06472,-0.03009,-0.02119,0.02979,0.00466,0.99932,1.35,0.08258,-0.06418,-0.03009,-0.02116,0.03101,0.00463,0.99928,1.3667,0.08257,-0.0637,-0.03011,-0.02114,0.03225,0.00458,0.99925,1.3833,0.08256,-0.06327,-0.03016,-0.02112,0.0335,0.00452,0.99921,1.4,0.08255,-0.06289,-0.03023,-0.02109,0.03477,0.00445,0.99916,1.4167,0.08255,-0.06256,-0.03032,-0.02107,0.03605,0.00437,0.99912,1.4333,0.08254,-0.06229,-0.03043,-0.02104,0.03733,0.00429,0.99907,1.45,0.08253,-0.06207,-0.03056,-0.02101,0.03861,0.00419,0.99902,1.4667,0.08252,-0.0619,-0.03072,-0.02099,0.0399,0.00409,0.99898,1.4833,0.08251,-0.06179,-0.03089,-0.02096,0.04117,0.00398,0.99892,1.5,0.0825,-0.06172,-0.03107,-0.02093,0.04244,0.00387,0.99887,1.5167,0.08249,-0.06171,-0.03128,-0.0209,0.04369,0.00375,0.99882,1.5333,0.08247,-0.06174,-0.0315,-0.02088,0.04492,0.00362,0.99877,1.55,0.08246,-0.06182,-0.03174,-0.02085,0.04613,0.00349,0.99871,1.5667,0.08245,-0.06196,-0.03199,-0.02082,0.04732,0.00335,0.99866,1.5833,0.08244,-0.06214,-0.03225,-0.02079,0.04848,0.00321,0.9986,1.6,0.08243,-0.06237,-0.03253,-0.02077,0.0496,0.00307,0.99855,1.6167,0.08241,-0.06264,-0.03281,-0.02074,0.05069,0.00292,0.99849,1.6333,0.0824,-0.06296,-0.03311,-0.02071,0.05174,0.00277,0.99844,1.65,0.08239,-0.06333,-0.03342,-0.02069,0.05274,0.00261,0.99839,1.6667,0.08238,-0.06375,-0.03374,-0.02066,0.0537,0.00246,0.99834,1.6833,0.08236,-0.06421,-0.03407,-0.02064,0.0546,0.0023,0.99829,1.7,0.08235,-0.06471,-0.0344,-0.02062,0.05545,0.00214,0.99825,1.7167,0.08234,-0.06527,-0.03474,-0.02059,0.05624,0.00198,0.9982,1.7333,0.08233,-0.06586,-0.03509,-0.02057,0.05697,0.00182,0.99816,1.75,0.08232,-0.0665,-0.03545,-0.02055,0.05763,0.00166,0.99812,1.7667,0.08231,-0.06718,-0.0358,-0.02053,0.05822,0.0015,0.99809,1.7833,0.08229,-0.0679,-0.03617,-0.02052,0.05874,0.00134,0.99806,1.8,0.08228,-0.06867,-0.03653,-0.0205,0.05918,0.00118,0.99804,1.8167,0.08227,-0.06947,-0.0369,-0.02049,0.05954,0.00103,0.99802,1.8333,0.08226,-0.07032,-0.03726,-0.02047,0.05981,0.00088,0.998,1.85,0.08225,-0.07121,-0.03763,-0.02046,0.05999,0.00072,0.99799,1.8667,0.08224,-0.07214,-0.038,-0.02045,0.06008,0.00058,0.99798,1.8833,0.08223,-0.0731,-0.03837,-0.02045,0.06007,0.00043,0.99798},
		["Left Leg"] = {0,-0.23928,0.04477,0.00948,-0.02781,0.03643,0.06385,0.99691,0.0167,-0.24199,0.04503,0.00965,-0.0278,0.03645,0.06467,0.99685,0.0333,-0.24483,0.04532,0.00982,-0.02779,0.03647,0.06549,0.9968,0.05,-0.24777,0.04564,0.01001,-0.02777,0.03649,0.06633,0.99674,0.0667,-0.2508,0.04597,0.01019,-0.02776,0.03651,0.06717,0.99669,0.0833,-0.25391,0.04633,0.01039,-0.02774,0.03654,0.06801,0.99663,0.1,-0.25709,0.04671,0.01058,-0.02772,0.03656,0.06885,0.99657,0.1167,-0.26031,0.0471,0.01078,-0.02771,0.03659,0.06969,0.99651,0.1333,-0.26372,0.04753,0.01099,-0.02769,0.03661,0.07056,0.99645,0.15,-0.26702,0.04796,0.0112,-0.02767,0.03664,0.07138,0.99639,0.1667,-0.27033,0.0484,0.0114,-0.02765,0.03666,0.0722,0.99633,0.1833,-0.27363,0.04886,0.0116,-0.02763,0.03669,0.07299,0.99627,0.2,-0.27692,0.04933,0.01181,-0.02761,0.03672,0.07377,0.99622,0.2167,-0.2802,0.04981,0.01201,-0.02759,0.03674,0.07453,0.99616,0.2333,-0.28345,0.0503,0.01221,-0.02757,0.03677,0.07527,0.9961,0.25,-0.28666,0.0508,0.0124,-0.02754,0.03679,0.07599,0.99605,0.2667,-0.28984,0.0513,0.01259,-0.02752,0.03682,0.07669,0.99599,0.2833,-0.2931,0.05183,0.01279,-0.0275,0.03685,0.0774,0.99594,0.3,-0.29617,0.05234,0.01298,-0.02748,0.03687,0.07805,0.99589,0.3167,-0.29917,0.05286,0.01316,-0.02746,0.0369,0.07867,0.99584,0.3333,-0.3021,0.05338,0.01334,-0.02744,0.03692,0.07926,0.99579,0.35,-0.30493,0.0539,0.01351,-0.02742,0.03694,0.07982,0.99575,0.3667,-0.30766,0.05441,0.01367,-0.0274,0.03697,0.08034,0.99571,0.3833,-0.31029,0.05492,0.01383,-0.02738,0.03699,0.08083,0.99567,0.4,-0.31282,0.05542,0.01398,-0.02736,0.03701,0.08128,0.99563,0.4167,-0.31524,0.05592,0.01412,-0.02734,0.03703,0.0817,0.99559,0.4333,-0.31754,0.0564,0.01426,-0.02732,0.03705,0.08208,0.99556,0.45,-0.31972,0.05688,0.01439,-0.0273,0.03707,0.08242,0.99553,0.4667,-0.32177,0.05734,0.01451,-0.02728,0.03709,0.08272,0.99551,0.4833,-0.32382,0.05781,0.01463,-0.02726,0.03711,0.08302,0.99548,0.5,-0.3256,0.05825,0.01474,-0.02724,0.03713,0.08324,0.99546,0.5167,-0.32722,0.05866,0.01484,-0.02723,0.03714,0.08342,0.99545,0.5333,-0.32869,0.05906,0.01492,-0.02721,0.03715,0.08356,0.99544,0.55,-0.33,0.05943,0.015,-0.0272,0.03717,0.08365,0.99543,0.5667,-0.33114,0.05978,0.01507,-0.02718,0.03718,0.08369,0.99543,0.5833,-0.3321,0.0601,0.01512,-0.02717,0.03719,0.08369,0.99543,0.6,-0.33288,0.06039,0.01517,-0.02715,0.0372,0.08364,0.99543,0.6167,-0.33346,0.06065,0.0152,-0.02714,0.0372,0.08353,0.99544,0.6333,-0.33385,0.06088,0.01522,-0.02713,0.03721,0.08338,0.99545,0.65,-0.33403,0.06108,0.01523,-0.02712,0.03721,0.08317,0.99547,0.6667,-0.334,0.06124,0.01523,-0.02711,0.03722,0.08291,0.99549,0.6833,-0.33375,0.06136,0.01521,-0.0271,0.03722,0.08259,0.99552,0.7,-0.33328,0.06144,0.01518,-0.02709,0.03721,0.08221,0.99555,0.7167,-0.33262,0.06148,0.01514,-0.02709,0.03721,0.08179,0.99559,0.7333,-0.33175,0.06149,0.01509,-0.02708,0.03721,0.08132,0.99563,0.75,-0.3307,0.06146,0.01503,-0.02708,0.0372,0.0808,0.99567,0.7667,-0.32947,0.0614,0.01495,-0.02708,0.03719,0.08024,0.99571,0.7833,-0.32806,0.06131,0.01487,-0.02707,0.03719,0.07964,0.99576,0.8,-0.32649,0.06118,0.01477,-0.02707,0.03718,0.079,0.99581,0.8167,-0.32476,0.06102,0.01467,-0.02707,0.03716,0.07833,0.99587,0.8333,-0.32275,0.06081,0.01455,-0.02707,0.03715,0.07759,0.99593,0.85,-0.32074,0.0606,0.01443,-0.02708,0.03714,0.07685,0.99598,0.8667,-0.31859,0.06036,0.0143,-0.02708,0.03712,0.07609,0.99604,0.8833,-0.31632,0.06009,0.01416,-0.02708,0.03711,0.07531,0.9961,0.9,-0.31392,0.0598,0.01402,-0.02709,0.03709,0.0745,0.99616,0.9167,-0.31142,0.05948,0.01386,-0.02709,0.03707,0.07367,0.99622,0.9333,-0.30881,0.05914,0.01371,-0.0271,0.03705,0.07283,0.99629,0.95,-0.3061,0.05878,0.01354,-0.02711,0.03703,0.07197,0.99635,0.9667,-0.3033,0.0584,0.01337,-0.02712,0.03701,0.07109,0.99641,0.9833,-0.30041,0.058,0.0132,-0.02713,0.03699,0.07021,0.99648,1,-0.29744,0.05759,0.01302,-0.02714,0.03697,0.06932,0.99654,1.0167,-0.2944,0.05716,0.01283,-0.02715,0.03695,0.06842,0.9966,1.0333,-0.29131,0.05671,0.01265,-0.02716,0.03693,0.06752,0.99666,1.05,-0.28803,0.05623,0.01245,-0.02717,0.0369,0.06659,0.99673,1.0667,-0.28487,0.05577,0.01225,-0.02719,0.03688,0.0657,0.99679,1.0833,-0.28167,0.0553,0.01206,-0.0272,0.03685,0.06482,0.99685,1.1,-0.27846,0.05482,0.01186,-0.02722,0.03683,0.06395,0.9969,1.1167,-0.27524,0.05433,0.01167,-0.02724,0.03681,0.06309,0.99696,1.1333,-0.27203,0.05384,0.01147,-0.02725,0.03678,0.06225,0.99701,1.15,-0.26883,0.05335,0.01127,-0.02727,0.03676,0.06144,0.99706,1.1667,-0.26564,0.05286,0.01108,-0.02729,0.03673,0.06065,0.99711,1.1833,-0.26249,0.05237,0.01089,-0.02731,0.03671,0.05988,0.99716,1.2,-0.25926,0.05186,0.01069,-0.02733,0.03668,0.05911,0.9972,1.2167,-0.25624,0.05139,0.0105,-0.02735,0.03666,0.05842,0.99724,1.2333,-0.2533,0.05091,0.01032,-0.02737,0.03663,0.05777,0.99728,1.25,-0.25044,0.05045,0.01014,-0.02739,0.03661,0.05716,0.99732,1.2667,-0.24768,0.05,0.00997,-0.02742,0.03659,0.05659,0.99735,1.2833,-0.24501,0.04955,0.00981,-0.02744,0.03657,0.05607,0.99738,1.3,-0.24243,0.04912,0.00965,-0.02746,0.03655,0.05558,0.99741,1.3167,-0.23996,0.0487,0.00949,-0.02748,0.03652,0.05514,0.99743,1.3333,-0.23759,0.04829,0.00935,-0.0275,0.0365,0.05474,0.99745,1.35,-0.23532,0.04789,0.00921,-0.02753,0.03649,0.05438,0.99747,1.3667,-0.23303,0.04749,0.00906,-0.02755,0.03647,0.05403,0.99749,1.3833,-0.23099,0.04712,0.00894,-0.02757,0.03645,0.05375,0.99751,1.4,-0.22907,0.04677,0.00882,-0.02759,0.03643,0.05352,0.99752,1.4167,-0.22728,0.04643,0.00871,-0.02761,0.03641,0.05333,0.99753,1.4333,-0.22562,0.04611,0.0086,-0.02763,0.0364,0.05318,0.99754,1.45,-0.2241,0.04581,0.00851,-0.02765,0.03638,0.05307,0.99754,1.4667,-0.22271,0.04552,0.00842,-0.02767,0.03637,0.053,0.99755,1.4833,-0.22146,0.04525,0.00835,-0.02769,0.03636,0.05298,0.99755,1.5,-0.22036,0.045,0.00828,-0.02771,0.03635,0.053,0.99755,1.5167,-0.2194,0.04477,0.00822,-0.02773,0.03634,0.05306,0.99754,1.5333,-0.2186,0.04455,0.00817,-0.02774,0.03633,0.05316,0.99754,1.55,-0.21795,0.04435,0.00813,-0.02776,0.03632,0.05331,0.99753,1.5667,-0.21745,0.04418,0.0081,-0.02777,0.03631,0.05349,0.99752,1.5833,-0.21712,0.04402,0.00808,-0.02779,0.0363,0.05372,0.99751,1.6,-0.21694,0.04388,0.00807,-0.0278,0.0363,0.05399,0.99749,1.6167,-0.21693,0.04376,0.00807,-0.02781,0.0363,0.05429,0.99748,1.6333,-0.21708,0.04366,0.00808,-0.02782,0.03629,0.05464,0.99746,1.65,-0.2174,0.04358,0.0081,-0.02783,0.03629,0.05502,0.99744,1.6667,-0.21789,0.04352,0.00813,-0.02784,0.03629,0.05544,0.99741,1.6833,-0.21854,0.04348,0.00817,-0.02784,0.0363,0.0559,0.99739,1.7,-0.21936,0.04346,0.00822,-0.02785,0.0363,0.05639,0.99736,1.7167,-0.22034,0.04347,0.00828,-0.02785,0.0363,0.05692,0.99733,1.7333,-0.2215,0.04349,0.00836,-0.02785,0.03631,0.05748,0.9973,1.75,-0.22282,0.04354,0.00844,-0.02786,0.03632,0.05808,0.99726,1.7667,-0.2243,0.04361,0.00854,-0.02786,0.03633,0.0587,0.99723,1.7833,-0.22594,0.0437,0.00864,-0.02785,0.03634,0.05936,0.99719,1.8,-0.22775,0.04381,0.00875,-0.02785,0.03635,0.06004,0.99715,1.8167,-0.22972,0.04395,0.00888,-0.02785,0.03636,0.06075,0.9971,1.8333,-0.23185,0.04411,0.00901,-0.02784,0.03638,0.06148,0.99706,1.85,-0.23413,0.0443,0.00915,-0.02783,0.03639,0.06224,0.99701,1.8667,-0.2367,0.04453,0.00932,-0.02782,0.03641,0.06306,0.99696,1.8833,-0.23928,0.04477,0.00948,-0.02781,0.03643,0.06385,0.99691},
		["Right Arm"] = {0,-0.08223,-0.0731,-0.03837,-0.02045,-0.06007,-0.00043,0.99798,0.0167,-0.08222,-0.07354,-0.03858,-0.02047,-0.0596,-0.00062,0.99801,0.0333,-0.0822,-0.07398,-0.0388,-0.02049,-0.0591,-0.00083,0.99804,0.05,-0.08218,-0.07442,-0.03903,-0.02052,-0.05855,-0.00107,0.99807,0.0667,-0.08217,-0.07487,-0.03925,-0.02054,-0.05796,-0.00133,0.99811,0.0833,-0.08215,-0.07532,-0.03948,-0.02057,-0.05735,-0.00162,0.99814,0.1,-0.08213,-0.07577,-0.03971,-0.0206,-0.0567,-0.00193,0.99818,0.1167,-0.0821,-0.07623,-0.03994,-0.02064,-0.05602,-0.00226,0.99821,0.1333,-0.08208,-0.07668,-0.04016,-0.02067,-0.05532,-0.00261,0.99825,0.15,-0.08206,-0.07713,-0.04039,-0.02071,-0.0546,-0.00297,0.99829,0.1667,-0.08204,-0.07757,-0.04061,-0.02074,-0.05385,-0.00336,0.99833,0.1833,-0.08201,-0.07802,-0.04084,-0.02078,-0.05308,-0.00375,0.99837,0.2,-0.08199,-0.07845,-0.04106,-0.02082,-0.0523,-0.00416,0.99841,0.2167,-0.08196,-0.07888,-0.04128,-0.02086,-0.05151,-0.00458,0.99844,0.2333,-0.08194,-0.07931,-0.04149,-0.0209,-0.05071,-0.00501,0.99848,0.25,-0.08191,-0.07972,-0.0417,-0.02094,-0.0499,-0.00545,0.99852,0.2667,-0.08189,-0.08012,-0.0419,-0.02098,-0.04908,-0.00589,0.99856,0.2833,-0.08186,-0.08052,-0.0421,-0.02102,-0.04826,-0.00635,0.99859,0.3,-0.08183,-0.0809,-0.04229,-0.02107,-0.04745,-0.0068,0.99863,0.3167,-0.08181,-0.08126,-0.04248,-0.02111,-0.04663,-0.00726,0.99866,0.3333,-0.08178,-0.08162,-0.04266,-0.02115,-0.04582,-0.00772,0.9987,0.35,-0.08176,-0.08195,-0.04283,-0.02119,-0.04502,-0.00818,0.99873,0.3667,-0.08173,-0.08227,-0.04299,-0.02123,-0.04423,-0.00863,0.99876,0.3833,-0.08171,-0.08257,-0.04314,-0.02127,-0.04345,-0.00909,0.99879,0.4,-0.08168,-0.08286,-0.04328,-0.02131,-0.04269,-0.00954,0.99882,0.4167,-0.08166,-0.08312,-0.04342,-0.02135,-0.04195,-0.00998,0.99884,0.4333,-0.08164,-0.08336,-0.04354,-0.02139,-0.04123,-0.01041,0.99887,0.45,-0.08161,-0.08358,-0.04365,-0.02142,-0.04053,-0.01084,0.99889,0.4667,-0.08159,-0.08377,-0.04375,-0.02146,-0.03986,-0.01125,0.99891,0.4833,-0.08157,-0.08394,-0.04383,-0.02149,-0.03921,-0.01166,0.99893,0.5,-0.08155,-0.08408,-0.04391,-0.02153,-0.0386,-0.01205,0.99895,0.5167,-0.08154,-0.0842,-0.04397,-0.02156,-0.03802,-0.01242,0.99897,0.5333,-0.08152,-0.08428,-0.04401,-0.02159,-0.03748,-0.01278,0.99898,0.55,-0.0815,-0.08434,-0.04404,-0.02161,-0.03698,-0.01312,0.999,0.5667,-0.08149,-0.08437,-0.04406,-0.02164,-0.03652,-0.01344,0.99901,0.5833,-0.08147,-0.08436,-0.04405,-0.02166,-0.03611,-0.01374,0.99902,0.6,-0.08146,-0.08433,-0.04404,-0.02168,-0.03574,-0.01401,0.99903,0.6167,-0.08145,-0.08425,-0.044,-0.0217,-0.03542,-0.01427,0.99903,0.6333,-0.08144,-0.08415,-0.04395,-0.02172,-0.03516,-0.01449,0.99904,0.65,-0.08144,-0.084,-0.04388,-0.02173,-0.03495,-0.01469,0.99904,0.6667,-0.08143,-0.08382,-0.04379,-0.02174,-0.0348,-0.01487,0.99905,0.6833,-0.08143,-0.0836,-0.04368,-0.02175,-0.0347,-0.01501,0.99905,0.7,-0.08143,-0.08334,-0.04355,-0.02176,-0.03467,-0.01512,0.99905,0.7167,-0.08143,-0.08305,-0.0434,-0.02176,-0.03469,-0.01521,0.99905,0.7333,-0.08143,-0.08273,-0.04324,-0.02176,-0.03476,-0.01527,0.99904,0.75,-0.08144,-0.08237,-0.04306,-0.02176,-0.03489,-0.0153,0.99904,0.7667,-0.08144,-0.08199,-0.04287,-0.02175,-0.03507,-0.0153,0.99903,0.7833,-0.08145,-0.08158,-0.04266,-0.02174,-0.03529,-0.01529,0.99902,0.8,-0.08146,-0.08115,-0.04245,-0.02173,-0.03556,-0.01524,0.99901,0.8167,-0.08147,-0.08069,-0.04222,-0.02172,-0.03587,-0.01518,0.99901,0.8333,-0.08148,-0.08022,-0.04198,-0.02171,-0.03622,-0.01509,0.99899,0.85,-0.08149,-0.07972,-0.04173,-0.02169,-0.03661,-0.01498,0.99898,0.8667,-0.0815,-0.07921,-0.04147,-0.02168,-0.03704,-0.01485,0.99897,0.8833,-0.08152,-0.07869,-0.04121,-0.02166,-0.0375,-0.0147,0.99895,0.9,-0.08153,-0.07815,-0.04094,-0.02163,-0.038,-0.01453,0.99894,0.9167,-0.08155,-0.07761,-0.04067,-0.02161,-0.03852,-0.01434,0.99892,0.9333,-0.08157,-0.07706,-0.04039,-0.02159,-0.03907,-0.01414,0.9989,0.95,-0.08158,-0.0765,-0.04011,-0.02156,-0.03965,-0.01391,0.99888,0.9667,-0.0816,-0.07594,-0.03983,-0.02154,-0.04025,-0.01368,0.99886,0.9833,-0.08162,-0.07538,-0.03954,-0.02151,-0.04088,-0.01342,0.99884,1,-0.08164,-0.07482,-0.03926,-0.02148,-0.04152,-0.01316,0.99882,1.0167,-0.08166,-0.07426,-0.03898,-0.02145,-0.04218,-0.01288,0.9988,1.0333,-0.08168,-0.07371,-0.0387,-0.02142,-0.04285,-0.01259,0.99877,1.05,-0.08171,-0.07316,-0.03843,-0.02138,-0.04353,-0.01228,0.99875,1.0667,-0.08173,-0.07262,-0.03816,-0.02135,-0.04423,-0.01197,0.99872,1.0833,-0.08175,-0.0721,-0.03789,-0.02132,-0.04494,-0.01165,0.99869,1.1,-0.08177,-0.07159,-0.03763,-0.02128,-0.04565,-0.01131,0.99867,1.1167,-0.08179,-0.07109,-0.03738,-0.02125,-0.04636,-0.01097,0.99864,1.1333,-0.08182,-0.07061,-0.03714,-0.02122,-0.04708,-0.01062,0.99861,1.15,-0.08184,-0.07015,-0.03691,-0.02118,-0.0478,-0.01027,0.99858,1.1667,-0.08186,-0.06971,-0.03669,-0.02115,-0.04851,-0.00991,0.99855,1.1833,-0.08189,-0.0693,-0.03648,-0.02111,-0.04922,-0.00954,0.99852,1.2,-0.08191,-0.06891,-0.03628,-0.02108,-0.04992,-0.00917,0.99849,1.2167,-0.08193,-0.06855,-0.0361,-0.02104,-0.05062,-0.0088,0.99846,1.2333,-0.08195,-0.06822,-0.03594,-0.02101,-0.0513,-0.00842,0.99843,1.25,-0.08197,-0.06792,-0.03578,-0.02097,-0.05197,-0.00804,0.9984,1.2667,-0.08199,-0.06765,-0.03565,-0.02094,-0.05263,-0.00766,0.99837,1.2833,-0.08201,-0.06741,-0.03552,-0.02091,-0.05327,-0.00729,0.99833,1.3,-0.08203,-0.06719,-0.03541,-0.02087,-0.0539,-0.00691,0.9983,1.3167,-0.08205,-0.067,-0.03532,-0.02084,-0.05452,-0.00653,0.99827,1.3333,-0.08207,-0.06684,-0.03524,-0.02081,-0.05511,-0.00616,0.99824,1.35,-0.08209,-0.06671,-0.03517,-0.02078,-0.05569,-0.00579,0.99821,1.3667,-0.08211,-0.0666,-0.03511,-0.02075,-0.05626,-0.00542,0.99819,1.3833,-0.08213,-0.06651,-0.03507,-0.02072,-0.0568,-0.00506,0.99816,1.4,-0.08214,-0.06646,-0.03504,-0.02069,-0.05732,-0.0047,0.99813,1.4167,-0.08216,-0.06642,-0.03502,-0.02066,-0.05783,-0.00435,0.9981,1.4333,-0.08217,-0.06641,-0.03502,-0.02063,-0.05831,-0.00401,0.99808,1.45,-0.08219,-0.06642,-0.03502,-0.0206,-0.05877,-0.00368,0.99805,1.4667,-0.0822,-0.06646,-0.03504,-0.02058,-0.05921,-0.00335,0.99803,1.4833,-0.08222,-0.06651,-0.03507,-0.02055,-0.05962,-0.00304,0.998,1.5,-0.08223,-0.06659,-0.0351,-0.02053,-0.06001,-0.00273,0.99798,1.5167,-0.08224,-0.06669,-0.03515,-0.02051,-0.06037,-0.00244,0.99796,1.5333,-0.08225,-0.06681,-0.03521,-0.02049,-0.0607,-0.00215,0.99794,1.55,-0.08226,-0.06695,-0.03528,-0.02047,-0.06101,-0.00189,0.99793,1.5667,-0.08227,-0.06711,-0.03536,-0.02045,-0.06129,-0.00163,0.99791,1.5833,-0.08228,-0.06729,-0.03545,-0.02044,-0.06154,-0.00139,0.99789,1.6,-0.08228,-0.06749,-0.03555,-0.02042,-0.06176,-0.00116,0.99788,1.6167,-0.08229,-0.0677,-0.03565,-0.02041,-0.06195,-0.00095,0.99787,1.6333,-0.0823,-0.06793,-0.03577,-0.0204,-0.06211,-0.00076,0.99786,1.65,-0.0823,-0.06818,-0.03589,-0.02038,-0.06223,-0.00058,0.99785,1.6667,-0.0823,-0.06844,-0.03603,-0.02038,-0.06232,-0.00043,0.99785,1.6833,-0.0823,-0.06872,-0.03617,-0.02037,-0.06238,-0.00029,0.99784,1.7,-0.08231,-0.06902,-0.03631,-0.02036,-0.0624,-0.00017,0.99784,1.7167,-0.08231,-0.06933,-0.03647,-0.02036,-0.06239,-0.00008,0.99784,1.7333,-0.0823,-0.06965,-0.03663,-0.02036,-0.06234,0,0.99785,1.75,-0.0823,-0.06999,-0.0368,-0.02036,-0.06225,0.00005,0.99785,1.7667,-0.0823,-0.07034,-0.03698,-0.02036,-0.06212,0.00008,0.99786,1.7833,-0.08229,-0.0707,-0.03716,-0.02037,-0.06195,0.00009,0.99787,1.8,-0.08229,-0.07107,-0.03735,-0.02038,-0.06174,0.00007,0.99788,1.8167,-0.08228,-0.07146,-0.03754,-0.02039,-0.0615,0.00002,0.9979,1.8333,-0.08227,-0.07186,-0.03774,-0.0204,-0.0612,-0.00005,0.99792,1.85,-0.08226,-0.07226,-0.03794,-0.02041,-0.06087,-0.00015,0.99794,1.8667,-0.08225,-0.07268,-0.03815,-0.02043,-0.06049,-0.00028,0.99796,1.8833,-0.08223,-0.0731,-0.03837,-0.02045,-0.06007,-0.00043,0.99798},
		["Right Leg"] = {0,0.24132,0.04728,0.00709,-0.03101,-0.0319,-0.06318,0.99701,0.0167,0.24407,0.04754,0.00724,-0.03101,-0.03192,-0.064,0.99696,0.0333,0.24693,0.04783,0.00739,-0.031,-0.03194,-0.06483,0.9969,0.05,0.2499,0.04815,0.00754,-0.03099,-0.03197,-0.06567,0.99685,0.0667,0.25297,0.04848,0.0077,-0.03098,-0.03199,-0.06652,0.99679,0.0833,0.25611,0.04884,0.00787,-0.03096,-0.03202,-0.06737,0.99673,0.1,0.25931,0.04922,0.00803,-0.03095,-0.03205,-0.06822,0.99668,0.1167,0.26257,0.04961,0.0082,-0.03094,-0.03207,-0.06906,0.99662,0.1333,0.26586,0.05003,0.00837,-0.03092,-0.0321,-0.0699,0.99656,0.15,0.26933,0.05047,0.00855,-0.03091,-0.03213,-0.07077,0.9965,0.1667,0.27268,0.05092,0.00872,-0.0309,-0.03216,-0.07159,0.99644,0.1833,0.27601,0.05138,0.00889,-0.03088,-0.03219,-0.0724,0.99638,0.2,0.27933,0.05185,0.00906,-0.03087,-0.03222,-0.07318,0.99632,0.2167,0.28263,0.05233,0.00923,-0.03085,-0.03225,-0.07395,0.99626,0.2333,0.28591,0.05282,0.0094,-0.03084,-0.03228,-0.0747,0.99621,0.25,0.28915,0.05331,0.00956,-0.03082,-0.03231,-0.07543,0.99615,0.2667,0.29235,0.05382,0.00973,-0.0308,-0.03234,-0.07613,0.9961,0.2833,0.29563,0.05435,0.00989,-0.03079,-0.03237,-0.07684,0.99604,0.3,0.29872,0.05486,0.01005,-0.03077,-0.0324,-0.0775,0.99599,0.3167,0.30174,0.05538,0.0102,-0.03076,-0.03243,-0.07812,0.99594,0.3333,0.30469,0.0559,0.01035,-0.03074,-0.03245,-0.07872,0.99589,0.35,0.30755,0.05642,0.01049,-0.03073,-0.03248,-0.07928,0.99585,0.3667,0.3103,0.05694,0.01062,-0.03071,-0.03251,-0.07981,0.99581,0.3833,0.31295,0.05745,0.01076,-0.0307,-0.03253,-0.0803,0.99577,0.4,0.3155,0.05795,0.01088,-0.03068,-0.03256,-0.08076,0.99573,0.4167,0.31793,0.05845,0.011,-0.03067,-0.03258,-0.08118,0.99569,0.4333,0.32025,0.05894,0.01112,-0.03065,-0.0326,-0.08156,0.99566,0.45,0.32244,0.05942,0.01122,-0.03064,-0.03263,-0.08191,0.99563,0.4667,0.32451,0.05988,0.01132,-0.03063,-0.03265,-0.08222,0.99561,0.4833,0.32643,0.06033,0.01142,-0.03061,-0.03267,-0.08248,0.99559,0.5,0.32821,0.06077,0.0115,-0.0306,-0.03269,-0.08271,0.99557,0.5167,0.32998,0.0612,0.01159,-0.03058,-0.0327,-0.08292,0.99555,0.5333,0.33146,0.0616,0.01166,-0.03057,-0.03272,-0.08306,0.99554,0.55,0.33277,0.06197,0.01172,-0.03056,-0.03273,-0.08315,0.99553,0.5667,0.33392,0.06232,0.01178,-0.03055,-0.03275,-0.0832,0.99553,0.5833,0.33488,0.06265,0.01182,-0.03054,-0.03276,-0.0832,0.99553,0.6,0.33567,0.06294,0.01186,-0.03053,-0.03277,-0.08315,0.99553,0.6167,0.33625,0.06321,0.01189,-0.03052,-0.03278,-0.08304,0.99554,0.6333,0.33664,0.06344,0.01191,-0.03051,-0.03278,-0.08289,0.99555,0.65,0.33683,0.06363,0.01191,-0.0305,-0.03279,-0.08268,0.99557,0.6667,0.33679,0.06379,0.01191,-0.03049,-0.03279,-0.08242,0.99559,0.6833,0.33654,0.06391,0.01189,-0.03048,-0.03279,-0.0821,0.99562,0.7,0.33607,0.064,0.01187,-0.03048,-0.03279,-0.08172,0.99565,0.7167,0.3354,0.06404,0.01184,-0.03047,-0.03279,-0.0813,0.99568,0.7333,0.33453,0.06405,0.01179,-0.03046,-0.03278,-0.08082,0.99572,0.75,0.33347,0.06403,0.01174,-0.03046,-0.03277,-0.08031,0.99577,0.7667,0.33223,0.06397,0.01167,-0.03046,-0.03277,-0.07974,0.99581,0.7833,0.33081,0.06387,0.0116,-0.03045,-0.03276,-0.07914,0.99586,0.8,0.32923,0.06375,0.01152,-0.03045,-0.03274,-0.0785,0.99591,0.8167,0.32736,0.06357,0.01143,-0.03045,-0.03273,-0.07779,0.99597,0.8333,0.32548,0.06338,0.01134,-0.03045,-0.03272,-0.07708,0.99602,0.85,0.32345,0.06317,0.01123,-0.03045,-0.0327,-0.07635,0.99608,0.8667,0.32129,0.06293,0.01113,-0.03045,-0.03268,-0.07558,0.99614,0.8833,0.319,0.06266,0.01101,-0.03045,-0.03267,-0.07479,0.9962,0.9,0.31659,0.06237,0.01089,-0.03045,-0.03265,-0.07398,0.99626,0.9167,0.31407,0.06205,0.01076,-0.03045,-0.03263,-0.07315,0.99632,0.9333,0.31144,0.06171,0.01063,-0.03045,-0.03261,-0.0723,0.99638,0.95,0.30871,0.06135,0.01049,-0.03046,-0.03258,-0.07144,0.99645,0.9667,0.30589,0.06097,0.01035,-0.03046,-0.03256,-0.07056,0.99651,0.9833,0.30297,0.06057,0.0102,-0.03047,-0.03254,-0.06966,0.99657,1,0.29997,0.06015,0.01005,-0.03048,-0.03251,-0.06877,0.99664,1.0167,0.29691,0.05972,0.0099,-0.03048,-0.03249,-0.06786,0.9967,1.0333,0.29366,0.05926,0.00974,-0.03049,-0.03246,-0.06692,0.99676,1.05,0.29051,0.0588,0.00958,-0.0305,-0.03243,-0.06602,0.99682,1.0667,0.28732,0.05834,0.00941,-0.03051,-0.03241,-0.06513,0.99688,1.0833,0.2841,0.05786,0.00925,-0.03052,-0.03238,-0.06424,0.99694,1.1,0.28086,0.05738,0.00909,-0.03053,-0.03235,-0.06336,0.997,1.1167,0.27761,0.05689,0.00892,-0.03054,-0.03232,-0.0625,0.99705,1.1333,0.27437,0.05641,0.00875,-0.03055,-0.0323,-0.06166,0.99711,1.15,0.27113,0.05591,0.00859,-0.03057,-0.03227,-0.06083,0.99716,1.1667,0.26791,0.05542,0.00842,-0.03058,-0.03224,-0.06003,0.99721,1.1833,0.2646,0.05491,0.00826,-0.0306,-0.03221,-0.05922,0.99726,1.2,0.26148,0.05442,0.0081,-0.03061,-0.03218,-0.05849,0.9973,1.2167,0.25843,0.05394,0.00794,-0.03063,-0.03216,-0.05779,0.99734,1.2333,0.25547,0.05347,0.00779,-0.03064,-0.03213,-0.05713,0.99738,1.25,0.25258,0.053,0.00764,-0.03066,-0.0321,-0.05651,0.99741,1.2667,0.24979,0.05255,0.00749,-0.03068,-0.03208,-0.05594,0.99745,1.2833,0.24709,0.0521,0.00735,-0.03069,-0.03205,-0.05541,0.99748,1.3,0.24449,0.05167,0.00722,-0.03071,-0.03203,-0.05492,0.9975,1.3167,0.24199,0.05124,0.00709,-0.03073,-0.03201,-0.05447,0.99753,1.3333,0.23959,0.05083,0.00697,-0.03074,-0.03198,-0.05406,0.99755,1.35,0.23716,0.05042,0.00684,-0.03076,-0.03196,-0.05366,0.99757,1.3667,0.23498,0.05003,0.00673,-0.03078,-0.03194,-0.05333,0.99759,1.3833,0.23292,0.04966,0.00662,-0.0308,-0.03192,-0.05305,0.99761,1.4,0.23098,0.04931,0.00652,-0.03081,-0.0319,-0.05281,0.99762,1.4167,0.22918,0.04897,0.00643,-0.03083,-0.03188,-0.05262,0.99763,1.4333,0.2275,0.04865,0.00634,-0.03085,-0.03186,-0.05246,0.99764,1.45,0.22595,0.04834,0.00626,-0.03086,-0.03185,-0.05235,0.99764,1.4667,0.22455,0.04806,0.00619,-0.03088,-0.03183,-0.05228,0.99765,1.4833,0.22329,0.04778,0.00612,-0.03089,-0.03182,-0.05225,0.99765,1.5,0.22217,0.04753,0.00606,-0.03091,-0.0318,-0.05227,0.99765,1.5167,0.22121,0.0473,0.00601,-0.03092,-0.03179,-0.05233,0.99764,1.5333,0.22039,0.04708,0.00597,-0.03094,-0.03178,-0.05243,0.99764,1.55,0.21973,0.04688,0.00594,-0.03095,-0.03177,-0.05257,0.99763,1.5667,0.21923,0.0467,0.00591,-0.03096,-0.03176,-0.05275,0.99762,1.5833,0.2189,0.04654,0.0059,-0.03097,-0.03176,-0.05298,0.99761,1.6,0.21872,0.0464,0.00589,-0.03098,-0.03175,-0.05325,0.9976,1.6167,0.21871,0.04628,0.00589,-0.03099,-0.03175,-0.05355,0.99758,1.6333,0.21886,0.04618,0.0059,-0.031,-0.03175,-0.0539,0.99756,1.65,0.21919,0.0461,0.00592,-0.03101,-0.03174,-0.05428,0.99754,1.6667,0.21968,0.04604,0.00594,-0.03102,-0.03175,-0.0547,0.99752,1.6833,0.22034,0.046,0.00598,-0.03103,-0.03175,-0.05516,0.99749,1.7,0.22117,0.04598,0.00602,-0.03103,-0.03175,-0.05566,0.99746,1.7167,0.22217,0.04598,0.00608,-0.03103,-0.03176,-0.05619,0.99743,1.7333,0.22333,0.04601,0.00614,-0.03104,-0.03176,-0.05675,0.9974,1.75,0.22467,0.04605,0.00621,-0.03104,-0.03177,-0.05735,0.99737,1.7667,0.22617,0.04612,0.00629,-0.03104,-0.03178,-0.05798,0.99733,1.7833,0.22784,0.04621,0.00638,-0.03104,-0.03179,-0.05864,0.99729,1.8,0.22967,0.04632,0.00648,-0.03104,-0.03181,-0.05933,0.99725,1.8167,0.23166,0.04646,0.00658,-0.03104,-0.03182,-0.06004,0.99721,1.8333,0.23381,0.04662,0.0067,-0.03103,-0.03184,-0.06078,0.99716,1.85,0.23611,0.04681,0.00682,-0.03103,-0.03186,-0.06155,0.99711,1.8667,0.23857,0.04702,0.00695,-0.03102,-0.03187,-0.06233,0.99706,1.8833,0.24132,0.04728,0.00709,-0.03101,-0.0319,-0.06318,0.99701},
		Torso = {0,-0.03448,-0.00578,-0.03692,0.00351,0,0,0.99999,0.0167,-0.03448,-0.00575,-0.03761,0.00344,0,0,0.99999,0.0333,-0.03448,-0.00574,-0.03833,0.00339,0,0,0.99999,0.05,-0.03448,-0.00573,-0.03909,0.00335,0,0,0.99999,0.0667,-0.03448,-0.00572,-0.03988,0.00333,0,0,0.99999,0.0833,-0.03448,-0.00572,-0.0407,0.00332,0,0,0.99999,0.1,-0.03448,-0.00572,-0.04154,0.00332,0,0,0.99999,0.1167,-0.03448,-0.00573,-0.04241,0.00333,0,0,0.99999,0.1333,-0.03448,-0.00575,-0.04329,0.00336,0,0,0.99999,0.15,-0.03448,-0.00576,-0.04419,0.0034,0,0,0.99999,0.1667,-0.03448,-0.00579,-0.04511,0.00344,0,0,0.99999,0.1833,-0.03448,-0.00581,-0.04604,0.0035,0,0,0.99999,0.2,-0.03448,-0.00584,-0.04697,0.00357,0,0,0.99999,0.2167,-0.03448,-0.00588,-0.04791,0.00365,0,0,0.99999,0.2333,-0.03448,-0.00591,-0.04885,0.00374,0,0,0.99999,0.25,-0.03448,-0.00595,-0.0498,0.00383,0,0,0.99999,0.2667,-0.03448,-0.006,-0.05073,0.00394,0,0,0.99999,0.2833,-0.03448,-0.00604,-0.05166,0.00405,0,0,0.99999,0.3,-0.03448,-0.00609,-0.05259,0.00417,0,0,0.99999,0.3167,-0.03448,-0.00614,-0.0535,0.0043,0,0,0.99999,0.3333,-0.03448,-0.0062,-0.05439,0.00444,0,0,0.99999,0.35,-0.03448,-0.00625,-0.05527,0.00458,0,0,0.99999,0.3667,-0.03448,-0.00631,-0.05613,0.00473,0,0,0.99999,0.3833,-0.03448,-0.00637,-0.05696,0.00488,0,0,0.99999,0.4,-0.03448,-0.00643,-0.05776,0.00504,0,0,0.99999,0.4167,-0.03448,-0.00649,-0.05854,0.0052,0,0,0.99999,0.4333,-0.03448,-0.00655,-0.05929,0.00537,0,0,0.99999,0.45,-0.03448,-0.00662,-0.05999,0.00554,0,0,0.99998,0.4667,-0.03448,-0.00668,-0.06066,0.00571,0,0,0.99998,0.4833,-0.03448,-0.00675,-0.06129,0.00589,0,0,0.99998,0.5,-0.03448,-0.00682,-0.06188,0.00607,0,0,0.99998,0.5167,-0.03448,-0.00688,-0.06242,0.00625,0,0,0.99998,0.5333,-0.03448,-0.00695,-0.06291,0.00644,0,0,0.99998,0.55,-0.03448,-0.00702,-0.06334,0.00662,0,0,0.99998,0.5667,-0.03448,-0.00708,-0.06373,0.00681,0,0,0.99998,0.5833,-0.03448,-0.00715,-0.06405,0.00699,0,0,0.99998,0.6,-0.03448,-0.00722,-0.06431,0.00718,0,0,0.99997,0.6167,-0.03448,-0.00728,-0.06451,0.00736,0,0,0.99997,0.6333,-0.03448,-0.00734,-0.06463,0.00755,0,0,0.99997,0.65,-0.03448,-0.00741,-0.06469,0.00773,0,0,0.99997,0.6667,-0.03448,-0.00747,-0.06468,0.00791,0,0,0.99997,0.6833,-0.03448,-0.00753,-0.06459,0.00809,0,0,0.99997,0.7,-0.03448,-0.00759,-0.06443,0.00827,0,0,0.99997,0.7167,-0.03448,-0.00764,-0.0642,0.00845,0,0,0.99996,0.7333,-0.03448,-0.0077,-0.06391,0.00862,0,0,0.99996,0.75,-0.03448,-0.00775,-0.06355,0.00878,0,0,0.99996,0.7667,-0.03448,-0.0078,-0.06313,0.00895,0,0,0.99996,0.7833,-0.03448,-0.00785,-0.06265,0.00911,0,0,0.99996,0.8,-0.03448,-0.00789,-0.06212,0.00926,0,0,0.99996,0.8167,-0.03448,-0.00794,-0.06154,0.00941,0,0,0.99996,0.8333,-0.03448,-0.00798,-0.06092,0.00955,0,0,0.99995,0.85,-0.03448,-0.00802,-0.06025,0.00969,0,0,0.99995,0.8667,-0.03448,-0.00805,-0.05954,0.00982,0,0,0.99995,0.8833,-0.03448,-0.00809,-0.05879,0.00995,0,0,0.99995,0.9,-0.03448,-0.00812,-0.05801,0.01007,0,0,0.99995,0.9167,-0.03448,-0.00815,-0.0572,0.01018,0,0,0.99995,0.9333,-0.03448,-0.00818,-0.05636,0.01029,0,0,0.99995,0.95,-0.03448,-0.0082,-0.0555,0.01038,0,0,0.99995,0.9667,-0.03448,-0.00822,-0.05461,0.01047,0,0,0.99995,0.9833,-0.03448,-0.00824,-0.05371,0.01055,0,0,0.99994,1,-0.03448,-0.00825,-0.0528,0.01062,0,0,0.99994,1.0167,-0.03448,-0.00826,-0.05187,0.01068,0,0,0.99994,1.0333,-0.03448,-0.00827,-0.05093,0.01073,0,0,0.99994,1.05,-0.03448,-0.00828,-0.04999,0.01077,0,0,0.99994,1.0667,-0.03448,-0.00828,-0.04905,0.0108,0,0,0.99994,1.0833,-0.03448,-0.00828,-0.04811,0.01082,0,0,0.99994,1.1,-0.03448,-0.00827,-0.04717,0.01083,0,0,0.99994,1.1167,-0.03448,-0.00826,-0.04625,0.01083,0,0,0.99994,1.1333,-0.03448,-0.00825,-0.04533,0.01081,0,0,0.99994,1.15,-0.03448,-0.00823,-0.04443,0.01079,0,0,0.99994,1.1667,-0.03448,-0.00821,-0.04354,0.01075,0,0,0.99994,1.1833,-0.03448,-0.00819,-0.04268,0.0107,0,0,0.99994,1.2,-0.03448,-0.00816,-0.04184,0.01063,0,0,0.99994,1.2167,-0.03448,-0.00813,-0.04103,0.01055,0,0,0.99994,1.2333,-0.03448,-0.00809,-0.04025,0.01046,0,0,0.99995,1.25,-0.03448,-0.00805,-0.0395,0.01035,0,0,0.99995,1.2667,-0.03448,-0.00801,-0.03878,0.01023,0,0,0.99995,1.2833,-0.03448,-0.00796,-0.03809,0.0101,0,0,0.99995,1.3,-0.03448,-0.00791,-0.03743,0.00996,0,0,0.99995,1.3167,-0.03448,-0.00786,-0.03681,0.0098,0,0,0.99995,1.3333,-0.03448,-0.0078,-0.03622,0.00964,0,0,0.99995,1.35,-0.03448,-0.00774,-0.03566,0.00947,0,0,0.99996,1.3667,-0.03448,-0.00768,-0.03514,0.00929,0,0,0.99996,1.3833,-0.03448,-0.00762,-0.03465,0.0091,0,0,0.99996,1.4,-0.03448,-0.00755,-0.03419,0.00891,0,0,0.99996,1.4167,-0.03448,-0.00748,-0.03377,0.00871,0,0,0.99996,1.4333,-0.03448,-0.00742,-0.03338,0.0085,0,0,0.99996,1.45,-0.03448,-0.00735,-0.03302,0.00829,0,0,0.99997,1.4667,-0.03448,-0.00727,-0.0327,0.00808,0,0,0.99997,1.4833,-0.03448,-0.0072,-0.03242,0.00786,0,0,0.99997,1.5,-0.03448,-0.00713,-0.03217,0.00764,0,0,0.99997,1.5167,-0.03448,-0.00706,-0.03196,0.00742,0,0,0.99997,1.5333,-0.03448,-0.00698,-0.03178,0.00719,0,0,0.99997,1.55,-0.03448,-0.00691,-0.03164,0.00697,0,0,0.99998,1.5667,-0.03448,-0.00684,-0.03154,0.00675,0,0,0.99998,1.5833,-0.03448,-0.00676,-0.03147,0.00652,0,0,0.99998,1.6,-0.03448,-0.00669,-0.03144,0.0063,0,0,0.99998,1.6167,-0.03448,-0.00662,-0.03145,0.00609,0,0,0.99998,1.6333,-0.03448,-0.00655,-0.0315,0.00587,0,0,0.99998,1.65,-0.03448,-0.00648,-0.03158,0.00566,0,0,0.99998,1.6667,-0.03448,-0.00641,-0.03171,0.00545,0,0,0.99999,1.6833,-0.03448,-0.00635,-0.03187,0.00525,0,0,0.99999,1.7,-0.03448,-0.00628,-0.03207,0.00506,0,0,0.99999,1.7167,-0.03448,-0.00622,-0.03231,0.00487,0,0,0.99999,1.7333,-0.03448,-0.00616,-0.03259,0.00469,0,0,0.99999,1.75,-0.03448,-0.00611,-0.03291,0.00451,0,0,0.99999,1.7667,-0.03448,-0.00605,-0.03327,0.00435,0,0,0.99999,1.7833,-0.03448,-0.006,-0.03366,0.00419,0,0,0.99999,1.8,-0.03448,-0.00596,-0.0341,0.00405,0,0,0.99999,1.8167,-0.03448,-0.00591,-0.03459,0.00392,0,0,0.99999,1.8333,-0.03448,-0.00587,-0.03511,0.0038,0,0,0.99999,1.85,-0.03448,-0.00584,-0.03567,0.00369,0,0,0.99999,1.8667,-0.03448,-0.0058,-0.03628,0.00359,0,0,0.99999,1.8833,-0.03448,-0.00578,-0.03692,0.00351,0,0,0.99999},
	}},
}

local function dcBuildEmbedded()
    local built = {}
    for clipName, d in pairs(DASH_CLIP_DATA) do
        local poses = {}
        for partName, arr in pairs(d.parts) do
            local list = {}
            for i = 1, #arr, 8 do
                list[#list + 1] = {
                    t = arr[i],
                    cf = CFrame.new(arr[i + 1], arr[i + 2], arr[i + 3], arr[i + 4], arr[i + 5], arr[i + 6], arr[i + 7]),
                }
            end
            poses[partName] = list
        end
        built[clipName] = {len = d.len, poses = poses}
    end
    return built
end

local function dcBuild()
    if not DashClips.Built then DashClips.Built = dcBuildEmbedded() end
    return DashClips.Built
end

local DC_WANTED = {"Dash1", "Dash2", "BackDash", "DashLeft", "DashRight", "idle"}

local function dcIsRbxm(content)
    return type(content) == "string" and string.sub(content, 1, 8) == "<roblox!"
end

-- baixa o .rbxm do GitHub (se ainda não estiver salvo), lê as KeyframeSequences
-- e devolve {clip = {len, poses}} ou false + motivo
local function dcLoadFromFile()
    if not (isfile and readfile and writefile and getcustomasset) then
        return false, "executor sem isfile/readfile/writefile/getcustomasset"
    end
    local file = DashClips.FileName

    local okR, content = pcall(function()
        if isfile(file) then return readfile(file) end
        return nil
    end)
    if not (okR and dcIsRbxm(content)) then
        local okH, body = pcall(function() return game:HttpGet(DashClips.GithubUrl) end)
        if not okH or not dcIsRbxm(body) then
            return false, "não consegui baixar o arquivo do GitHub"
        end
        local okW = pcall(function() writefile(file, body) end)
        if not okW then return false, "não consegui salvar o arquivo (writefile)" end
    end

    local okO, objs = pcall(function() return game:GetObjects(getcustomasset(file)) end)
    if not okO or not objs or not objs[1] then return false, "falha ao ler o .rbxm" end
    local model = objs[1]

    local seqs = {}
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("KeyframeSequence") then seqs[d.Name] = d end
    end

    local result, count = {}, 0
    for _, clipName in ipairs(DC_WANTED) do
        local ks = seqs[clipName]
        if ks then
            local kfs = {}
            for _, c in ipairs(ks:GetChildren()) do
                if c:IsA("Keyframe") then kfs[#kfs + 1] = c end
            end
            table.sort(kfs, function(a, b) return a.Time < b.Time end)

            local poses, len = {}, 0
            local function walk(parent, t)
                for _, pose in ipairs(parent:GetChildren()) do
                    if pose:IsA("Pose") then
                        if pose.Weight > 0 and pose.Name ~= "HumanoidRootPart" then
                            local list = poses[pose.Name]
                            if not list then list = {}; poses[pose.Name] = list end
                            list[#list + 1] = {t = t, cf = pose.CFrame}
                        end
                        walk(pose, t)
                    end
                end
            end
            for _, kf in ipairs(kfs) do
                len = math.max(len, kf.Time)
                walk(kf, kf.Time)
            end
            if next(poses) then
                result[clipName] = {len = len, poses = poses}
                count += 1
            end
        end
    end
    pcall(function() model:Destroy() end) -- só usei como fonte de dados

    if count == 0 then return false, "nenhuma animação encontrada no arquivo" end
    return result
end

-- roda em segundo plano ao carregar o script (o primeiro dash não precisa esperar o download)
local function dcLoadAsync()
    if not DashClips.UseGithub then return end
    local ok, res, msg = pcall(dcLoadFromFile)
    if ok and type(res) == "table" then
        local built = dcBuild()
        for name, clip in pairs(res) do built[name] = clip end
        DashClips.Source = "github"
        print("[Dash] animações carregadas do arquivo do GitHub")
    else
        warn("[Dash] usando animações embutidas (" .. tostring(ok and msg or res) .. ")")
    end
end

local function dcMotors()
    if not Character or not Character.Parent then return false end
    local torso = DashClips.Motors["Torso"]
    if DashClips.MotorChar == Character and torso and torso.Parent then return true end
    local m = {}
    for _, d in ipairs(Character:GetDescendants()) do
        if d:IsA("Motor6D") and d.Part1 then m[d.Part1.Name] = d end
    end
    DashClips.Motors = m
    DashClips.MotorChar = Character
    return m["Torso"] ~= nil
end

local function dcSample(list, t)
    local n = #list
    if t <= list[1].t then return list[1].cf end
    if t >= list[n].t then return list[n].cf end
    for i = 1, n - 1 do
        local a, b = list[i], list[i + 1]
        if t <= b.t then
            local span = b.t - a.t
            if span <= 0 then return b.cf end
            return a.cf:Lerp(b.cf, (t - a.t) / span)
        end
    end
    return list[n].cf
end

local function dcRestoreAutoRotate()
    if DashClips.AutoRotateSaved ~= nil then
        if Humanoid and Humanoid.Parent then Humanoid.AutoRotate = DashClips.AutoRotateSaved end
        DashClips.AutoRotateSaved = nil
    end
end

local function dcStep(dt)
    local playing = DashClips.Playing
    if next(playing) == nil then
        dcRestoreAutoRotate()
        return
    end
    if DashClips.MotorChar ~= Character then -- respawn: descarta o que estava tocando
        table.clear(playing)
        DashClips.AutoRotateSaved = nil
        return
    end

    local active = {}
    for tr in pairs(playing) do
        tr.t += dt * DashClips.Speed
        if not tr.stopping and tr.t >= tr.clip.len then
            tr.stopping = true
            tr.fade = DashClips.FadeOut
        end
        if tr.stopping then
            tr.w -= dt / tr.fade
        else
            tr.w = math.min(1, tr.w + dt / DashClips.FadeIn)
        end
        if tr.stopping and tr.w <= 0 then
            playing[tr] = nil
        else
            active[#active + 1] = tr
        end
    end

    for partName, motor in pairs(DashClips.Motors) do
        if motor.Parent then
            local result
            for _, tr in ipairs(active) do
                local list = tr.clip.poses[partName]
                if list then
                    local cf = dcSample(list, math.min(tr.t, tr.clip.len))
                    local base = result or motor.Transform
                    result = base:Lerp(cf, math.clamp(tr.w, 0, 1))
                end
            end
            if result then motor.Transform = result end
        end
    end

    if next(playing) == nil then dcRestoreAutoRotate() end
end

local function dcEnsureConn()
    if DashClips.Conn then return end
    DashClips.Conn = RunService.PreSimulation:Connect(function(dt)
        local ok, err = pcall(dcStep, dt)
        if not ok and not DashClips.Warned then
            DashClips.Warned = true
            warn("[Dash] erro na animação por keyframes:", err)
        end
    end)
end

local function dcStopAll(fade)
    for tr in pairs(DashClips.Playing) do
        tr.stopping = true
        tr.fade = math.max(fade or 0.05, 0.001)
    end
end

local function dcPlay(kind)
    if not DashClips.Enabled or not Character or not Humanoid or not HRP then return false end
    local built = dcBuild()
    if not dcMotors() then return false end

    local name
    if kind == "Front" then
        name = DashClips.NextFront == 1 and "Dash1" or "Dash2"
        DashClips.NextFront = 3 - DashClips.NextFront
    elseif kind == "Back" then
        name = "BackDash"
    elseif kind == "Left" then
        name = "DashLeft"
    elseif kind == "Right" then
        name = "DashRight"
    end
    local clip = name and built[name]
    if not clip then return false end

    dcStopAll(0.04)
    DashClips.Playing[{clip = clip, t = 0, w = 0, stopping = false, fade = DashClips.FadeOut}] = true

    -- o boneco não gira sozinho durante o dash (volta ao normal quando a animação acaba)
    if DashClips.AutoRotateSaved == nil then DashClips.AutoRotateSaved = Humanoid.AutoRotate end
    Humanoid.AutoRotate = false

    dcEnsureConn()
    return true
end

-- Escolhe o tipo de dash NO CHÃO pela direção em que você está andando, relativa ao boneco:
-- parado ou andando pra frente = Front | pra trás = Back | pro lado = Right / Left.
-- (Com shift lock / câmera travada o boneco encara a câmera, então andar pro lado = dash pro lado.)
GetGroundDashKind = function()
    local look = HRP.CFrame.LookVector
    local right = HRP.CFrame.RightVector
    local move = Humanoid.MoveDirection
    if move.Magnitude < 0.1 then return "Front", look end
    local f, r = move:Dot(look), move:Dot(right)
    if math.abs(f) >= math.abs(r) then
        if f >= 0 then return "Front", look end
        return "Back", -look
    end
    if r >= 0 then return "Right", right end
    return "Left", -right
end

local procedural = PlayDashAnim
PlayDashAnim = function(kind, direction)
    if kind ~= "Air" and DashClips.Enabled then
        dashRestore()                -- cancela a animação procedural, se estiver rodando
        DashAnimState.Token += 1
        local ok, played = pcall(dcPlay, kind)
        if ok and played then return end
    end
    dcStopAll(0.05)
    -- sem keyframes (R15, falha...): Left/Right usam a pose procedural de Front
    procedural((kind == "Left" or kind == "Right") and "Front" or kind, direction)
end

    -- ========== LOCOMOÇÃO POR KEYFRAMES: IDLE ==========
    -- Usa os mesmos keyframe embutido (idle) e o mesmo sistema de Motor6D do dash.
    -- A velocidade é lida do próprio boneco (HumanoidRootPart), então se adapta a qualquer jogo,
    -- não importa qual seja o WalkSpeed dele:
    --   parado (< IdleBelow)         -> Idle
    --   andando (>= IdleBelow)       -> sem animação do script (volta a do jogo)
    -- No ar, sentado, escalando, nadando, morto ou durante o dash, ela sai de cena sozinha.
    local Loco = {
        Enabled = true,
        IdleBelow = 1,       -- studs/s: abaixo disso = parado (Idle)
        IdleRate = 1,        -- velocidade do Idle
        Fade = 0.15,         -- tempo de transição entre animações (s)
        Smooth = 14,         -- suavização da leitura de velocidade (maior = mais rápido)
        Speed = 0,
        Moving = false,
        Tracks = {},         -- [nome] = {name, t, w}
        Order = {},          -- do mais antigo pro mais novo
        Char = nil,
        Conn = nil,
        Warned = false,
    }

    local LOCO_BLOCKED = {
        [Enum.HumanoidStateType.Seated] = true,
        [Enum.HumanoidStateType.Climbing] = true,
        [Enum.HumanoidStateType.Swimming] = true,
        [Enum.HumanoidStateType.PlatformStanding] = true,
        [Enum.HumanoidStateType.Physics] = true,
        [Enum.HumanoidStateType.Ragdoll] = true,
        [Enum.HumanoidStateType.FallingDown] = true,
        [Enum.HumanoidStateType.Dead] = true,
        [Enum.HumanoidStateType.Flying] = true,
    }

    local function locoClear()
        table.clear(Loco.Tracks)
        table.clear(Loco.Order)
    end

    local function locoRemove(tr)
        Loco.Tracks[tr.name] = nil
        local i = table.find(Loco.Order, tr)
        if i then table.remove(Loco.Order, i) end
    end

    -- true = pode tocar | false = fade-out | nil = parar na hora (dash assumiu)
    local function locoCanPlay()
        if not Loco.Enabled or not Character or not Character.Parent or not Humanoid or not Humanoid.Parent or not HRP then
            return false
        end
        if next(DashClips.Playing) ~= nil or DashAnimState.Joints ~= nil then return nil end
        if Humanoid.Health <= 0 or Humanoid.Sit or Humanoid.PlatformStand then return false end
        if LOCO_BLOCKED[Humanoid:GetState()] then return false end
        if Humanoid.FloorMaterial == Enum.Material.Air then return false end
        return true
    end

    local function locoStep(dt)
        if Loco.Char ~= Character then -- respawn: recomeça do zero
            Loco.Char = Character
            locoClear()
            Loco.Speed, Loco.Moving = 0, false
        end

        local can = locoCanPlay()
        if can == nil then locoClear() return end
        if can and not dcMotors() then can = false end

        -- velocidade horizontal real do boneco (suavizada)
        local desired
        if can then
            local v = HRP.AssemblyLinearVelocity
            local sp = Vector3.new(v.X, 0, v.Z).Magnitude
            Loco.Speed += (sp - Loco.Speed) * (1 - math.exp(-dt * Loco.Smooth))
            local s = Loco.Speed

            if Loco.Moving then
                if s < Loco.IdleBelow * 0.6 then Loco.Moving = false end
            elseif s >= Loco.IdleBelow then
                Loco.Moving = true
            end

            if not Loco.Moving then desired = "idle" end
        end

        local built = dcBuild()
        local tracks, order = Loco.Tracks, Loco.Order

        if desired and built[desired] then
            local tr = tracks[desired]
            if not tr then
                tr = {name = desired, t = 0, w = 0}
                tracks[desired] = tr
                order[#order + 1] = tr
            elseif order[#order] ~= tr then
                table.remove(order, table.find(order, tr))
                order[#order + 1] = tr
            end
            tr.w = math.min(1, tr.w + dt / Loco.Fade)
            if tr.w >= 1 then -- a nova cobriu tudo, descarta as antigas
                for i = #order - 1, 1, -1 do
                    tracks[order[i].name] = nil
                    table.remove(order, i)
                end
            end
        else
            for i = #order, 1, -1 do
                local tr = order[i]
                tr.w -= dt / Loco.Fade
                if tr.w <= 0 then locoRemove(tr) end
            end
        end

        if #order == 0 then return end

        -- avança o tempo da animação (loop)
        for _, tr in ipairs(order) do
            local clip = built[tr.name]
            if clip and clip.len > 0 then
                tr.t = (tr.t + dt * Loco.IdleRate) % clip.len
            end
        end

        for partName, motor in pairs(DashClips.Motors) do
            if motor.Parent then
                local result
                for _, tr in ipairs(order) do
                    local clip = built[tr.name]
                    local list = clip and clip.poses[partName]
                    if list then
                        local cf = dcSample(list, tr.t)
                        result = (result or motor.Transform):Lerp(cf, math.clamp(tr.w, 0, 1))
                    end
                end
                if result then motor.Transform = result end
            end
        end
    end

    local function locoEnsureConn()
        if Loco.Conn then return end
        Loco.Conn = RunService.PreSimulation:Connect(function(dt)
            local ok, err = pcall(locoStep, dt)
            if not ok and not Loco.Warned then
                Loco.Warned = true
                warn("[Loco] erro na animação de idle:", err)
            end
        end)
    end
    locoEnsureConn()
    -- ========== FIM DA LOCOMOÇÃO ==========


task.spawn(dcLoadAsync)
end


local function ExecDash()
    if State.IsSandiActive then return end
    if State.Energy < Constants.ENERGY_COSTS.DASH or os.clock() < State.Cooldowns.DASH then return end
    
    State.Energy -= Constants.ENERGY_COSTS.DASH
    State.Energy = math.max(0, State.Energy)
    State.NoRegenUntil = os.clock() + Constants.REGEN_DELAY_USE
    State.Cooldowns.DASH = os.clock() + Constants.COOLDOWNS.DASH
    if PsyBar.Use("Dash") then return end
    
    -- Efeitos sonoros e visuais
    -- Tipo do dash: Air (no ar) | Front | Back | Left | Right (no chão, pela direção em que você anda)
    local isAirDash = Humanoid.FloorMaterial == Enum.Material.Air
    local dashKind, groundDirection = "Air", nil
    if not isAirDash then dashKind, groundDirection = GetGroundDashKind() end
    local isBackDash = dashKind == "Back"
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
        local __o = (getgenv and getgenv() or _G); vpf.Visible = not (__o.SandiVPOccluded and __o.SandiVPOccluded(__o.SandiVPBodyPoints(Character:FindFirstChild("HumanoidRootPart"))))
        
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
    local direction = groundDirection or Camera.CFrame.LookVector
    
    local bv = Create("BodyVelocity", {MaxForce = Vector3.new(1e6, 1e6, 1e6), Velocity = direction * Constants.DASH_FORCE, Parent = HRP})

    -- Animação do dash (frente / trás / ar)
    PlayDashAnim(dashKind, direction)

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
        StudsOffset = Vector3.new(3.8, barCenterY + textH / 2, -1.5),
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
        Color = Color3.fromRGB(200, 50, 70),
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
            BackgroundColor3 = Color3.fromRGB(200, 50, 70),
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

do
local JUNK = {"Script", "LocalScript", "ModuleScript", "Sound", "ParticleEmitter", "Trail", "Beam", "Highlight", "BillboardGui", "ForceField", "Fire", "Smoke", "Sparkles", "PointLight", "SpotLight", "SurfaceLight", "BodyMover", "VectorForce", "Animator"}
local gui, vpf, pairsList = nil, nil, {}
local BIND = "KiroshiSelfViewport"
local KiroshiVP = {}

local function keyed(root)
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

function KiroshiVP.Off()
    pcall(function() RunService:UnbindFromRenderStep(BIND) end)
    pairsList = {}
    if gui then pcall(function() gui:Destroy() end) gui = nil end
    vpf = nil
end

function KiroshiVP.On()
    KiroshiVP.Off()
    local src = Character
    if not src or not src.Parent or not HRP then return end

    local wasArchivable = src.Archivable
    src.Archivable = true
    local ok, ghost = pcall(function() return src:Clone() end)
    src.Archivable = wasArchivable
    if not ok or not ghost then return end

    local srcMap, ghostMap = keyed(src), keyed(ghost)
    pairsList = {}
    for key, g in pairs(ghostMap) do
        local o = srcMap[key]
        if o then table.insert(pairsList, {g, o}) end
    end
    if #pairsList == 0 then ghost:Destroy() return end

    for _, obj in ipairs(ghost:GetDescendants()) do
        for _, cls in ipairs(JUNK) do
            if obj:IsA(cls) then obj:Destroy() break end
        end
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
        end
    end

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

    gui = Instance.new("ScreenGui")
    gui.Name = "KiroshiSelfViewportGui"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = -1
    gui.Parent = Player:WaitForChild("PlayerGui")

    vpf = Instance.new("ViewportFrame")
    vpf.Name = "KiroshiSelfViewport"
    vpf.Size = UDim2.new(1, 0, 1, 0)
    vpf.BackgroundTransparency = 1
    vpf.Ambient = Color3.fromRGB(200, 200, 200)
    vpf.LightColor = Color3.fromRGB(140, 140, 140)
    vpf.CurrentCamera = Workspace.CurrentCamera
    vpf.Parent = gui

    ghost.Name = "KiroshiGhost"
    ghost.Parent = vpf

    RunService:BindToRenderStep(BIND, Enum.RenderPriority.Last.Value, function()
        if not src.Parent or not HRP or not HRP.Parent or not vpf then
            KiroshiVP.Off()
            return
        end
        local cam = Workspace.CurrentCamera
        vpf.CurrentCamera = cam
        local __o = (getgenv and getgenv()) or _G
        vpf.Visible = (cam.CFrame.Position - HRP.Position).Magnitude >= 1.6
            and not (__o.SandiVPOccluded and __o.SandiVPOccluded(__o.SandiVPBodyPoints(HRP)))
        for _, pr in ipairs(pairsList) do
            local copy, real = pr[1], pr[2]
            if real.Parent and copy.Parent then
                copy.CFrame = real.CFrame
                copy.Transparency = real.Transparency
            end
        end
    end)
end
Constants.KiroshiVP = KiroshiVP
end

local function ExecKiroshi()
    if State.IsKiroshiActive then
        if Constants.KiroshiStop and os.clock() - (Constants.KiroshiStartT or 0) > 0.4 then Constants.KiroshiStop() end
        return
    end
    if State.IsSandiActive then return end
    if State.Energy < Constants.ENERGY_COSTS.KIROSHI or os.clock() < State.Cooldowns.KIROSHI or State.IsKiroshiActive then return end
    State.Energy -= Constants.ENERGY_COSTS.KIROSHI
    State.Energy = math.max(0, State.Energy)
    State.NoRegenUntil = os.clock() + Constants.REGEN_DELAY_USE
    if PsyBar.Use("Kiroshi") then return end
    State.IsKiroshiActive = true
    Constants.KiroshiStartT = os.clock()
    pcall(Constants.KiroshiVP.On)
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
                                    slot.BorderColor3 = Color3.fromRGB(90, 215, 255)
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
    
    local kiroshiStopped = false
    local function stopKiroshi()
        if kiroshiStopped or not State.IsKiroshiActive then return end
        kiroshiStopped = true
        pcall(Constants.KiroshiVP.Off)
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
    end
    Constants.KiroshiStop = stopKiroshi
    task.spawn(function()
        task.wait(5)
        stopKiroshi()
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
    if PhaseGhost.Gui then
        pcall(function() PhaseGhost.Gui:Destroy() end)
        PhaseGhost.Gui = nil
        PhaseGhost.Viewport = nil
    end
end

-- ViewportFrame unico que guarda todos os clones (fora do Workspace = zero conflito
-- com fisica, Humanoids, deteccao de inimigos, etc). Usa a mesma camera do jogo,
-- entao os clones aparecem 1:1 no tamanho/posicao do seu boneco (R6 e R15).
function PhaseGhost.GetViewport()
    if PhaseGhost.Viewport and PhaseGhost.Viewport.Parent then return PhaseGhost.Viewport end
    local gui = Instance.new("ScreenGui")
    gui.Name = "PhaseGhostGui"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = -1
    gui.Parent = Player:WaitForChild("PlayerGui")

    local vpf = Instance.new("ViewportFrame")
    vpf.Name = "PhaseGhostViewport"
    vpf.Size = UDim2.new(1, 0, 1, 0)
    vpf.BackgroundTransparency = 1
    vpf.Ambient = Color3.fromRGB(200, 200, 200)    -- padrao do ViewportFrame (cores fieis)
    vpf.LightColor = Color3.fromRGB(140, 140, 140)
    vpf.CurrentCamera = Workspace.CurrentCamera
    vpf.Parent = gui

    PhaseGhost.Gui = gui
    PhaseGhost.Viewport = vpf
    return vpf
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
    ghost.Parent = PhaseGhost.GetViewport()   -- ViewportFrame: 1:1 com o boneco e sem conflito

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

    do
        local __o = (getgenv and getgenv()) or _G
        local vp = PhaseGhost.Viewport
        if vp and vp.Parent then
            vp.Visible = not (__o.SandiVPOccluded and __o.SandiVPOccluded(__o.SandiVPBodyPoints(HRP, 3.4)))
        end
    end

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

-- ============================================================
-- ANIMAÇÃO DE TELA DO PHASE SHIFT
-- Entrada: desfoque de dissolução (dessatura + blur + FOV abre)
-- Saída:   rebobinar (flash branco + FOV "puxa" e volta + filtro neutro)
-- ============================================================
local phaseFxCC, phaseFxBlur = nil, nil
local phaseBaseFOV = nil
local phaseFxToken = 0
local PHASE_FOV_OUT = 10   -- quanto o FOV abre na entrada

local function PhaseFxClear()
    if phaseFxCC then pcall(function() phaseFxCC:Destroy() end) phaseFxCC = nil end
    if phaseFxBlur then pcall(function() phaseFxBlur:Destroy() end) phaseFxBlur = nil end
end

local function PhaseScreenIn()
    if LiteMode then return end
    phaseFxToken += 1
    PhaseFxClear()
    phaseBaseFOV = Camera.FieldOfView

    phaseFxCC = Create("ColorCorrectionEffect", {Name = "PhaseDissolveCC", TintColor = Color3.new(1,1,1), Saturation = 0, Contrast = 0, Brightness = 0, Parent = Lighting})
    phaseFxBlur = Create("BlurEffect", {Name = "PhaseDissolveBlur", Size = 0, Parent = Lighting})

    -- dessatura e esfria a cor (corpo virando fantasma)
    TweenService:Create(phaseFxCC, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Saturation = -0.85,
        Contrast = 0.12,
        TintColor = Color3.fromRGB(205, 235, 255),
    }):Play()

    -- blur de dissolução: sobe rápido e some
    local up = TweenService:Create(phaseFxBlur, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 16})
    up:Play()
    local blur = phaseFxBlur
    up.Completed:Connect(function()
        if blur and blur.Parent then
            TweenService:Create(blur, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = 0}):Play()
        end
    end)

    -- FOV abre
    TweenService:Create(Camera, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = phaseBaseFOV + PHASE_FOV_OUT}):Play()
end

local function PhaseScreenOut()
    if LiteMode then return end
    phaseFxToken += 1
    local myFx = phaseFxToken
    local cc, blur = phaseFxCC, phaseFxBlur
    local baseFOV = phaseBaseFOV
    phaseFxCC, phaseFxBlur = nil, nil
    if not cc or not cc.Parent then
        cc = Create("ColorCorrectionEffect", {Name = "PhaseDissolveCC", TintColor = Color3.new(1,1,1), Saturation = 0, Contrast = 0, Brightness = 0, Parent = Lighting})
    end
    if not blur or not blur.Parent then
        blur = Create("BlurEffect", {Name = "PhaseDissolveBlur", Size = 0, Parent = Lighting})
    end

    -- rebobinar: flash branco + filtro volta ao neutro
    local flash = TweenService:Create(cc, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Brightness = 0.55, Saturation = -0.3, Contrast = 0.1, TintColor = Color3.new(1,1,1),
    })
    flash:Play()
    flash.Completed:Connect(function()
        if cc.Parent then
            TweenService:Create(cc, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Brightness = 0, Saturation = 0, Contrast = 0, TintColor = Color3.new(1,1,1),
            }):Play()
        end
    end)

    -- blur curto de "fita rebobinando"
    TweenService:Create(blur, TweenInfo.new(0.08), {Size = 10}):Play()
    task.delay(0.08, function()
        if blur.Parent then
            TweenService:Create(blur, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = 0}):Play()
        end
    end)

    -- FOV é puxado pra dentro e volta ao normal (se o Sandevistan não estiver usando)
    if baseFOV and not State.IsSandiActive then
        local pull = TweenService:Create(Camera, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = baseFOV - 8})
        pull:Play()
        pull.Completed:Connect(function()
            if not State.IsSandiActive then
                TweenService:Create(Camera, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = baseFOV}):Play()
            end
        end)
    end

    task.delay(0.6, function()
        pcall(function() cc:Destroy() end)
        pcall(function() blur:Destroy() end)
    end)
end

local function ResetOptical()
    if not State.IsOpticalActive then return end
    opticalToken += 1
    State.IsOpticalActive = false
    PhaseGhost.Retract()
    PhaseScreenOut()
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
    if PsyBar.Use("Optical") then return end
    State.IsOpticalActive = true
    Falar("optical_on")
    PlaySFX(Sounds.OPTICAL_CAMO)
    PhaseScreenIn()

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

    task.delay(Constants.OPTICAL_DURATION * (1 - 0.4 * math.clamp(State.Psychosis / PsyBar.MAX, 0, 1)), function()
        if myToken == opticalToken then ResetOptical() end
    end)
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
        Size = UDim2.new(0, 32, 0, 190),
        Position = UDim2.new(0, 28, 0.5, -140),
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

    -- ========== BARRA PEQUENA DE CYBERPSYCHOSIS (0–100%) ==========
    -- Filha do container da energia: anda junto quando a barra é arrastada no modo de edição.
    local psyBar = Create("Frame", {
        Name = "PsychosisBar",
        Size = UDim2.new(0, 14, 0, 110),
        Position = UDim2.new(1, 12, 1, 0),
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        Parent = container
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = psyBar})
    Create("UIStroke", {Color = Color3.fromRGB(80, 0, 8), Thickness = 3, Transparency = 0.05, Parent = psyBar})
    Create("UIStroke", {Color = PsyBar.COLOR_MID, Thickness = 1.5, Transparency = 0.5, Parent = psyBar})

    local psyInner = Create("Frame", {
        Size = UDim2.new(1, -6, 1, -6),
        Position = UDim2.new(0, 3, 0, 3),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = psyBar
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = psyInner})

    psyFill = Create("Frame", {
        Name = "PsyFill",
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 1, 0),
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = PsyBar.COLOR_LOW,
        BorderSizePixel = 0,
        Parent = psyInner
    })
    -- degrade preto (base) -> vermelho (ponta)
    Create("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(18, 18, 18)),
        Rotation = 90,
        Parent = psyFill
    })

    -- Marca dos 50% (metade da barra): daqui pra cima é zona de perigo
    Create("Frame", {
        Name = "Mark50",
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 0.5, -1),
        BackgroundColor3 = Color3.fromRGB(255, 60, 60),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = psyInner
    })

    psyPercentLabel = Create("TextLabel", {
        Name = "PsyPercent",
        Size = UDim2.new(0, 44, 0, 14),
        Position = UDim2.new(0.5, 0, 1, 3),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        Text = "0%",
        TextColor3 = PsyBar.COLOR_MID,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextStrokeTransparency = 0.25,
        Parent = psyBar
    })

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

do
local PsyGlitch = {
    START = 22.5, STEP = 5, Active = {}, NextAt = 0,
    VIEWPORT_START = 60,       -- % da barra: daqui pra cima entra o glitch de ViewportFrame
    STOP_OLD_GLITCH = false,   -- true = o glitch antigo (tremer/piscar a peça real) PARA em 60% | false = só trava no nível de 60% e continua junto com o do ViewportFrame
    VIEWPORT_MAX = 75,         -- % da barra onde o glitch de ViewportFrame chega no máximo (sobe de VIEWPORT_START até aqui)
    CLONE_START = 85,          -- % da barra: daqui pra cima aparecem CLONES do corpo inteiro (ecos) no ViewportFrame
    ECHO_MIN = 1,              -- quantidade de clones ao mesmo tempo em CLONE_START (sobe até ECHO_MAX em 100%)
    ECHO_MAX = 4,              -- máximo de clones ao mesmo tempo
    ECHO_TINT = false,         -- false = clones com a MESMA cor do seu boneco | true = piscam em neon (ciano/magenta/vermelho)
    VP = {gui = nil, vp = nil, recs = {}, used = {}, map = {}, clone = nil, char = nil, nextAt = 0, conn = nil, echoes = {}, echoNextAt = 0},
}

function PsyGlitch.Level()
    local v = State.Psychosis
    if v < PsyGlitch.START then return 0 end
    return math.floor((v - PsyGlitch.START) / PsyGlitch.STEP) + 1
end

local function psyRestore(rec)
    if rec.part and rec.part.Parent then rec.part.LocalTransparencyModifier = 0 end
    if rec.motor and rec.motor.Parent then rec.motor.Transform = rec.lastBase or CFrame.identity end
    if rec.weld and rec.weld.Parent then rec.weld.C0 = rec.baseC0 end
end

function PsyGlitch.Clear()
    for key, rec in pairs(PsyGlitch.Active) do
        psyRestore(rec)
        PsyGlitch.Active[key] = nil
    end
end

local function psyJitter(mag, rot)
    local function r() return (math.random() * 2 - 1) end
    return CFrame.new(r() * mag, r() * mag, r() * mag)
        * CFrame.Angles(math.rad(r() * rot), math.rad(r() * rot), math.rad(r() * rot))
end


-- ============================================================
-- GLITCH DE VIEWPORTFRAME (a partir de VIEWPORT_START %)
-- Cópia FIEL (mesma cor, textura e malha, sem neon) das peças e acessórios do boneco, na MESMA
-- câmera do jogo. A peça real continua visível e a cópia pula/gira/pisca por cima (duplicação).
-- ============================================================
-- O ViewportFrame recebe um CLONE do personagem INTEIRO (com Humanoid, roupas e cor do corpo, que só
-- renderizam certo dentro de um Model com Humanoid). O clone fica ancorado e escondido; só as peças
-- sorteadas aparecem, seguindo a peça real com deslocamento.
local function vpIsJunk(d)
    return d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
        or d:IsA("Highlight") or d:IsA("BillboardGui") or d:IsA("ForceField") or d:IsA("Fire") or d:IsA("Smoke")
        or d:IsA("Sparkles") or d:IsA("Light") or d:IsA("JointInstance") or d:IsA("WeldConstraint")
        or d:IsA("Constraint") or d:IsA("BodyMover")
end

local function vpEndRec(r)
    if r.g and r.g.Parent then r.g.Transparency = 1 end
    if r.src and r.src.Parent then r.src.LocalTransparencyModifier = 0 end
    PsyGlitch.VP.used[r.src] = nil
end

-- ECOS: clones do corpo INTEIRO (a partir de CLONE_START %), congelados na pose do momento,
-- deslocados pro lado, piscando por pouco tempo. O corpo real continua visível.
local function vpClearEchoes()
    local V = PsyGlitch.VP
    for _, e in ipairs(V.echoes) do
        if e.model then pcall(function() e.model:Destroy() end) end
    end
    V.echoes = {}
end

local function vpBuildClone(char)
    local V = PsyGlitch.VP
    vpClearEchoes()
    for _, r in ipairs(V.recs) do pcall(vpEndRec, r) end
    V.recs, V.used, V.map = {}, {}, {}
    if V.clone then V.clone:Destroy() V.clone = nil end
    V.char = char
    -- marca cada peça real com um id; o clone herda o id e o mapa real->cópia nasce por id
    -- (não depende mais da ordem/quantidade de descendentes, que quebrava com objetos não-clonáveis)
    local byId, n = {}, 0
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then
            n += 1
            byId[n] = d
            d:SetAttribute("PsyVpId", n)
        end
    end
    local was = char.Archivable
    char.Archivable = true
    local ok, clone = pcall(function() return char:Clone() end)
    char.Archivable = was
    for _, d in ipairs(byId) do
        if d.Parent then d:SetAttribute("PsyVpId", nil) end
    end
    if not ok or not clone then
        warn("[Sandevistan] glitch ViewportFrame: não consegui clonar o personagem")
        return false
    end
    for _, c in ipairs(clone:GetDescendants()) do
        if c:IsA("BasePart") then
            local i = c:GetAttribute("PsyVpId")
            if i and byId[i] then V.map[byId[i]] = c end
        end
    end
    for _, c in ipairs(clone:GetDescendants()) do
        if c:IsA("BasePart") then
            c.Anchored = true
            c.CanCollide = false
            c.CanQuery = false
            c.CanTouch = false
            c.CastShadow = false
            c.Transparency = 1   -- escondido até a peça ser sorteada
        elseif vpIsJunk(c) then
            c:Destroy()
        end
    end
    local hum = clone:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    end
    clone.Parent = V.vp
    V.clone = clone
    return next(V.map) ~= nil
end

local function vpSpawnEcho(p2)
    local V = PsyGlitch.VP
    if not V.vp or not V.clone or not V.clone.Parent or not HRP or not HRP.Parent then return end
    local was = V.clone.Archivable
    V.clone.Archivable = true
    local ok, model = pcall(function() return V.clone:Clone() end)
    V.clone.Archivable = was
    if not ok or not model then return end
    local ghostById = {}
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            local i = d:GetAttribute("PsyVpId")
            if i then ghostById[i] = d end
        end
    end
    local parts, reals, bases, pj = {}, {}, {}, {}
    for real, g in pairs(V.map) do
        local gp = ghostById[g:GetAttribute("PsyVpId")]
        if gp then
            if real.Parent and real ~= HRP and real.Name ~= "HumanoidRootPart" and real.Transparency < 0.95 then
                gp.CFrame = real.CFrame
                gp.Transparency = real.Transparency   -- opaco (sem semi-transparência)
                table.insert(parts, gp)
                table.insert(reals, real)
                table.insert(bases, real.Transparency)
                table.insert(pj, Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1))
            else
                gp.Transparency = 1
            end
        end
    end
    if PsyGlitch.ECHO_TINT and math.random() < 0.45 then
        local tints = {Color3.fromRGB(0, 240, 255), Color3.fromRGB(255, 0, 140), Color3.fromRGB(255, 30, 30), Color3.new(1, 1, 1)}
        local tint = tints[math.random(#tints)]
        for _, gp in ipairs(parts) do
            gp.Color = tint
            gp.Material = Enum.Material.Neon
        end
    end
    model.Parent = V.vp
    local now = os.clock()
    table.insert(V.echoes, {
        model = model, parts = parts, reals = reals, bases = bases, partJit = pj,
        born = now, life = 0.3 + math.random() * 0.5,
        side = (math.random() < 0.5 and -1 or 1) * (1.4 + math.random() * 3 + p2 * 2.5),
        lift = (math.random() * 2 - 1) * 1.2,
        rotY = (math.random() * 2 - 1) * (14 + 30 * p2), rotZ = (math.random() * 2 - 1) * (6 + 16 * p2),
        jx = 0, jy = 0, jmag = 0.5 + 0.8 * p2,
        nextRoll = 0, blink = false,
    })
end

-- cada eco SAI do corpo (deslocamento sobe de 0), buga (pulos, giros, piscadas) e VOLTA pro corpo (0),
-- seguindo o boneco real em todo frame, nunca fica solto no mapa
local function vpEchoStep(now)
    local V = PsyGlitch.VP
    local cam = Workspace.CurrentCamera
    for i = #V.echoes, 1, -1 do
        local e = V.echoes[i]
        local u = (now - e.born) / e.life
        if u >= 1 or not e.model.Parent or not cam or not HRP or not HRP.Parent then
            pcall(function() e.model:Destroy() end)
            table.remove(V.echoes, i)
        else
            if now >= e.nextRoll then
                e.nextRoll = now + 0.03 + math.random() * 0.04
                e.blink = math.random() < 0.3
                if math.random() < 0.4 then
                    e.jx, e.jy = (math.random() * 2 - 1) * e.jmag * 3, (math.random() * 2 - 1) * e.jmag * 1.5   -- pulo brusco
                else
                    e.jx, e.jy = (math.random() * 2 - 1) * e.jmag, (math.random() * 2 - 1) * e.jmag * 0.5
                end
            end
            local env = math.sin(math.pi * u)            -- 0 -> 1 -> 0
            env = math.floor(env * 6 + 0.5) / 6          -- degraus: movimento travado/glitchado
            local right, up = cam.CFrame.RightVector, cam.CFrame.UpVector
            local offset = right * (e.side * env + e.jx * env) + up * (e.lift * env + e.jy * env)
            local pivot = HRP.CFrame
            local rot = CFrame.Angles(0, math.rad(e.rotY * env), math.rad(e.rotZ * env))
            local base = pivot * rot * pivot:Inverse()
            for k, gp in ipairs(e.parts) do
                local real = e.reals[k]
                if real.Parent then
                    gp.CFrame = base * real.CFrame + offset + e.partJit[k] * (0.35 * env)
                    gp.Transparency = e.blink and 1 or e.bases[k]
                else
                    gp.Transparency = 1
                end
            end
        end
    end
end

local function vpFollow()
    local V = PsyGlitch.VP
    local cam = Workspace.CurrentCamera
    if not cam or not V.vp then return end
    if V.vp.CurrentCamera ~= cam then V.vp.CurrentCamera = cam end
    local now = os.clock()
    vpEchoStep(now)
    for i = #V.recs, 1, -1 do
        local r = V.recs[i]
        if now >= r.untilT or not r.src.Parent or not r.g.Parent then
            vpEndRec(r)
            table.remove(V.recs, i)
        else
            if now >= r.reroll then
                r.reroll = now + 0.03 + math.random() * 0.04
                r.dx = (math.random() * 2 - 1) * r.mag
                r.dy = (math.random() * 2 - 1) * r.mag * 0.4
                r.rot = CFrame.Angles(math.rad((math.random() * 2 - 1) * r.rotDeg), math.rad((math.random() * 2 - 1) * r.rotDeg), math.rad((math.random() * 2 - 1) * r.rotDeg))
                r.blink = math.random() < 0.1
            end
            local right, up = cam.CFrame.RightVector, cam.CFrame.UpVector
            r.g.CFrame = (r.src.CFrame * r.rot) + right * r.dx + up * r.dy
            r.g.Transparency = r.blink and 1 or r.src.Transparency
            -- a peça real continua VISÍVEL: a cópia glitchada aparece por cima como uma duplicação
        end
    end
end

local function vpEnsure()
    local V = PsyGlitch.VP
    if V.gui and V.gui.Parent and V.vp then return true end
    local pg = Player:FindFirstChildOfClass("PlayerGui")
    if not pg then return false end
    local g = Instance.new("ScreenGui")
    g.Name = "PsyViewportGlitch"
    g.IgnoreGuiInset = true
    g.ResetOnSpawn = false
    g.DisplayOrder = 850
    g.Parent = pg
    local vp = Instance.new("ViewportFrame")
    vp.Size = UDim2.fromScale(1, 1)
    vp.BackgroundTransparency = 1
    vp.Ambient = Color3.fromRGB(170, 170, 170)
    vp.LightColor = Color3.new(1, 1, 1)
    pcall(function() vp.LightDirection = -Lighting:GetSunDirection() end)
    vp.CurrentCamera = Workspace.CurrentCamera
    vp.ZIndex = 5
    vp.Parent = g
    V.gui, V.vp, V.clone, V.char = g, vp, nil, nil
    if V.conn then V.conn:Disconnect() end
    V.conn = RunService.RenderStepped:Connect(vpFollow)
    return true
end

function PsyGlitch.ClearViewport()
    local V = PsyGlitch.VP
    if not V.gui and not V.conn and #V.recs == 0 then return end
    for _, r in ipairs(V.recs) do pcall(vpEndRec, r) end
    vpClearEchoes()
    V.recs, V.used, V.map = {}, {}, {}
    if V.conn then V.conn:Disconnect() V.conn = nil end
    if V.gui then V.gui:Destroy() end
    V.gui, V.vp, V.clone, V.char = nil, nil, nil, nil
end

function PsyGlitch.UpdateViewport(dt)
    local V = PsyGlitch.VP
    if not vpEnsure() then return end
    if V.char ~= Character or not V.clone or not V.clone.Parent then
        if os.clock() < (V.buildRetry or 0) then return end
        if not vpBuildClone(Character) then
            V.buildRetry = os.clock() + 2
            return
        end
    end
    local p = math.clamp((State.Psychosis - PsyGlitch.VIEWPORT_START) / math.max(1, PsyGlitch.VIEWPORT_MAX - PsyGlitch.VIEWPORT_START), 0, 1)
    if State.Psychosis >= PsyGlitch.CLONE_START then
        local p2 = math.clamp((State.Psychosis - PsyGlitch.CLONE_START) / math.max(1, PsyBar.MAX - PsyGlitch.CLONE_START), 0, 1)
        local t = os.clock()
        local maxE = PsyGlitch.ECHO_MIN + math.floor(p2 * (PsyGlitch.ECHO_MAX - PsyGlitch.ECHO_MIN) + 0.5)
        if t >= V.echoNextAt and #V.echoes < maxE then
            V.echoNextAt = t + (0.14 - 0.09 * p2) * (0.5 + math.random())
            for _ = 1, math.min(maxE - #V.echoes, 1 + math.floor(p2 * 2)) do
                vpSpawnEcho(p2)
            end
        end
    elseif #V.echoes > 0 then
        vpClearEchoes()
    end
    local now = os.clock()
    if now < V.nextAt then return end
    V.nextAt = now + (0.55 - 0.25 * p) * (0.5 + math.random())
    local room = 1 + math.floor(p * 3) - #V.recs
    if room <= 0 then return end
    local cand = {}
    for real, g in pairs(V.map) do
        if real.Parent and real ~= HRP and real.Name ~= "HumanoidRootPart" and real.Transparency < 0.95 and not V.used[real] then
            table.insert(cand, real)
        end
    end
    local n = math.min(#cand, room, 1 + math.floor(p * 1.5))
    for _ = 1, n do
        local src = table.remove(cand, math.random(#cand))
        local g = V.map[src]
        if g and g.Parent then
            V.used[src] = true
            table.insert(V.recs, {
                src = src, g = g,
                untilT = now + 0.06 + math.random() * 0.12 + p * 0.06,
                reroll = 0, dx = 0, dy = 0, rot = CFrame.identity, blink = false,
                mag = 0.12 + 0.5 * p, rotDeg = 3 + 8 * p,
            })
        end
    end
end

function PsyGlitch.Update(dt)
    local level = PsyGlitch.Level()
    if level == 0 or PsyBar.Busy or not Character or not Character.Parent then
        if next(PsyGlitch.Active) then PsyGlitch.Clear() end
        PsyGlitch.ClearViewport()
        return
    end
    if State.Psychosis >= PsyGlitch.VIEWPORT_START then
        PsyGlitch.UpdateViewport(dt)
        if PsyGlitch.STOP_OLD_GLITCH then
            if next(PsyGlitch.Active) then PsyGlitch.Clear() end   -- o glitch antigo para aqui
            return
        end
        level = math.floor((PsyGlitch.VIEWPORT_START - PsyGlitch.START) / PsyGlitch.STEP) + 1   -- só trava no nível de 60%
    else
        PsyGlitch.ClearViewport()
    end
    local now = os.clock()
    local mag = 0.05 + level * 0.04
    local rot = level * 2.5

    for key, rec in pairs(PsyGlitch.Active) do
        if now >= rec.untilT or not rec.part.Parent then
            psyRestore(rec)
            PsyGlitch.Active[key] = nil
        else
            rec.part.LocalTransparencyModifier = (math.random() < 0.5) and rec.alpha or 0
            if rec.motor then
                local cur = rec.motor.Transform
                if cur ~= rec.applied then rec.lastBase = cur end
                rec.applied = (rec.lastBase or cur) * psyJitter(mag, rot)
                rec.motor.Transform = rec.applied
            elseif rec.weld then
                rec.weld.C0 = rec.baseC0 * psyJitter(mag, rot)
            end
        end
    end

    if now >= PsyGlitch.NextAt then
        PsyGlitch.NextAt = now + math.max(0.08, 1.2 - level * 0.07) * (0.5 + math.random())
        local candidates = {}
        for _, d in ipairs(Character:GetDescendants()) do
            if d:IsA("BasePart") and d ~= HRP and d.Name ~= "HumanoidRootPart" and not PsyGlitch.Active[d] then
                table.insert(candidates, d)
            end
        end
        local count = math.min(#candidates, 1 + math.floor(level / 3))
        for _ = 1, count do
            local idx = math.random(#candidates)
            local part = table.remove(candidates, idx)
            local rec = {
                part = part,
                untilT = now + 0.06 + math.random() * 0.12 + level * 0.01,
                alpha = math.clamp(0.4 + level * 0.04 + math.random() * 0.2, 0.4, 1),
            }
            local acc = part:FindFirstAncestorOfClass("Accessory")
            if acc then
                local w = part:FindFirstChildWhichIsA("Weld")
                if w and w:IsA("Weld") then rec.weld = w rec.baseC0 = w.C0 end
            else
                for _, m in ipairs(Character:GetDescendants()) do
                    if m:IsA("Motor6D") and m.Part1 == part then rec.motor = m break end
                end
            end
            PsyGlitch.Active[part] = rec
        end
    end
end

PsyBar.Glitch = PsyGlitch
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
            if model and model ~= Character and model.Name ~= "PhaseGhost" and model.Name ~= "HologramClone" and model:FindFirstChildOfClass("Humanoid") then
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
            PsyBar.Add(PsyBar.GAIN_ZERO)
            if math.random() < (PsyBar.DIRECT_ZERO_BASE + PsyBar.DIRECT_ZERO_SCALE * (State.Psychosis / PsyBar.MAX)) then
                ExecCyberpsychosis()
                if not PsyBar.Busy then State.Psychosis = PsyBar.RESET_TO end
            end
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
    -- ========== BARRA DE CYBERPSYCHOSIS: ganho, queda e gatilho em 100% ==========
    do
        local now = os.clock()
        if State.IsSandiActive then
            State.PsychosisIdleSince = now
            PsyBar.Add(PsyBar.GAIN_SANDI * dt)
        elseif not PsyBar.Busy and now - State.PsychosisIdleSince > PsyBar.DECAY_DELAY then
            if State.Psychosis > 0 then
                PsyBar.DecayAcc = (PsyBar.DecayAcc or 0) + dt
                while PsyBar.DecayAcc >= PsyBar.DECAY_INTERVAL do
                    PsyBar.DecayAcc -= PsyBar.DECAY_INTERVAL
                    State.Psychosis = math.max(0, State.Psychosis - PsyBar.DECAY_STEP)
                end
            end
        else
            PsyBar.DecayAcc = 0
        end
        local okG, errG = pcall(PsyBar.Glitch.Update, dt)
        if not okG and not PsyBar.GlitchErrWarned then
            PsyBar.GlitchErrWarned = true
            warn("[Sandevistan] erro no glitch da psicose: " .. tostring(errG))
        end

        if State.Psychosis >= PsyBar.MAX and not PsyBar.Busy then
            PsyBar.Busy = true
            task.spawn(function()
                pcall(ExecCyberpsychosis)
                -- ResetSandi ignora chamadas dentro da janela de trava logo após ativar
                local wait_t = SandiLockTime - os.clock()
                if wait_t > 0 then task.wait(wait_t) end
                pcall(ResetSandi)
                task.wait(Constants.CYBERPSYCHOSIS.Duration)
                State.Psychosis = PsyBar.RESET_TO
                State.PsychosisIdleSince = os.clock()
                PsyBar.Busy = false
            end)
        end
    end
    if psyFill and psyPercentLabel and psyFill.Parent then
        local v = State.Psychosis
        local col
        if v < 50 then
            col = PsyBar.COLOR_LOW:Lerp(PsyBar.COLOR_MID, v / 50)
        else
            col = PsyBar.COLOR_MID:Lerp(PsyBar.COLOR_HIGH, (v - 50) / 50)
        end
        psyFill.Size = UDim2.new(1, 0, math.clamp(v / PsyBar.MAX, 0, 1), 0)
        psyFill.BackgroundColor3 = col
        -- zona de perigo (>50%): pulsa, cada vez mais rápido
        psyPercentLabel.Text = string.format("%d%%", math.floor(v))
        psyPercentLabel.TextColor3 = col
        psyFill.BackgroundTransparency = v > 50 and (0.1 + 0.3 * math.abs(math.sin(os.clock() * (4 + (v - 50) / 6)))) or 0
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
