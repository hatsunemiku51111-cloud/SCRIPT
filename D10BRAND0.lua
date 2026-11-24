local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hum = character:WaitForChild("Humanoid")

-- Check de rig: no R6 NENHUMA animação é aplicada no boneco (só a procedural das facas).
local function isPlayerR6()
    return hum ~= nil and hum.RigType == Enum.HumanoidRigType.R6
end

-- ============================================================
-- ANTI FALL DAMAGE (roda junto com o script; se falhar, não quebra o resto)
-- ============================================================
task.spawn(function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/hatsunemiku51111-cloud/SCRIPT/refs/heads/main/antifalldamagescripts.lua"))()
    end)
    if not ok then
        warn("⚠️ Falha ao carregar o Anti Fall Damage: " .. tostring(err))
    end
end)

local ACCESSORY_TAG = "DioAccessory"

local httpService = game:GetService("HttpService")

-- ============================================================
-- SISTEMA DE SALVAMENTO JSON MELHORADO (Corrigido)
-- ============================================================

local ARQUIVO_CONFIG = "dio_stand_config.json"

-- Função para salvar o ID (versão mais confiável)
local function salvarStandId(userId)
    userId = tonumber(userId) or 0
    
    local config = {
        lastUserId = userId,
        lastUsed = os.time()
    }
    
    local sucesso, erro = pcall(function()
        local jsonData = httpService:JSONEncode(config)
        writefile(ARQUIVO_CONFIG, jsonData)
    end)
    
    if sucesso then
        print("💾 ID do Stand salvo com sucesso: " .. tostring(userId))
        customStandUserId = userId > 0 and userId or nil
    else
        warn("❌ Erro ao salvar JSON: " .. tostring(erro))
        -- Tentativa de fallback
        pcall(function()
            writefile(ARQUIVO_CONFIG, '{"lastUserId":' .. userId .. ',"lastUsed":' .. os.time() .. '}')
        end)
    end
end

-- Função para carregar o ID
local function carregarStandId()
    if not isfile(ARQUIVO_CONFIG) then
        print("📄 Nenhum arquivo de configuração encontrado. Usando padrão.")
        return nil
    end
    
    local sucesso, conteudo = pcall(function()
        return readfile(ARQUIVO_CONFIG)
    end)
    
    if not sucesso or not conteudo then
        warn("⚠️ Erro ao ler o arquivo JSON")
        return nil
    end
    
    local sucesso2, config = pcall(function()
        return httpService:JSONDecode(conteudo)
    end)
    
    if sucesso2 and config and config.lastUserId ~= nil then
        print("📂 ID do Stand carregado: " .. tostring(config.lastUserId))
        return tonumber(config.lastUserId)
    else
        warn("⚠️ JSON inválido ou corrompido. Usando padrão.")
        return nil
    end
end

-- Função para deletar o arquivo (usada no RESET)
local function deletarArquivoConfig()
    if isfile(ARQUIVO_CONFIG) then
        local sucesso = pcall(function()
            delfile(ARQUIVO_CONFIG)
        end)
        if sucesso then
            print("🗑️ Arquivo de configuração deletado com sucesso!")
        else
            warn("⚠️ Não foi possível deletar o arquivo JSON")
        end
    end
end

-- =========================================================
-- SISTEMA DE ANIMAÇÕES CUSTOMIZADAS (CORRIGIDO E MELHORADO)
-- =========================================================

local CUSTOM_ANIMS = {
    Idle         = "rbxassetid://101516194765447",
    Walk         = "rbxassetid://89251806503217",
    Run          = "rbxassetid://101871663749983",
    JumpRunning  = "rbxassetid://131814798893284",
    JumpStanding = "rbxassetid://131814798893284",
    IdleVariant  = "rbxassetid://133201196209194",
    Fall         = "rbxassetid://122194794537519",
    SRun         = "rbxassetid://121350640829746",
}

local SETTINGS = {
    JumpPower          = 50,
    Enabled            = true,
    RunAnimSpeed       = 1.5,
    SRunAnimSpeed      = 3,
    SRunRestartInterval = 1.3
}

local originalIDs_anim = {}
local originalWalkSpeed_anim = 16
local jumpingConnection_anim = nil
local activeJumpTrack_anim = nil
local jumpStateConnection_anim = nil
local animLoopConnection_anim = nil
local idleVariantTrack_anim = nil
local idleTimer_anim = nil
local isIdle_anim = false
local sRunTrack_anim = nil
local lastSRunTime_anim = 0

local function loadCustomAnim(animationId)
    if not hum or not hum:FindFirstChild("Animator") then return nil end
    local anim = Instance.new("Animation")
    anim.AnimationId = animationId
    return hum.Animator:LoadAnimation(anim)
end

local function safeSetAnim(animate, path, id)
    local obj = animate
    for i, key in ipairs(path) do
        local child = obj:FindFirstChild(key)
        if not child then
            if i == #path then
                child = Instance.new("Animation")
                child.Name = key
            else
                child = Instance.new("Folder")
                child.Name = key
            end
            child.Parent = obj
        end
        obj = child
    end
    if obj:IsA("Animation") then
        obj.AnimationId = id
    end
end

-- =========================================================
-- SISTEMA IDLE VARIANT - SÓ TOCA SE O BONECO FICAR PARADO DE VERDADE
-- =========================================================
-- Regras:
--  • Só conta tempo se o boneco estiver 100% parado no chão
--    (sem andar, pular, cair, sentar, usar habilidade, ser empurrado...)
--  • Qualquer movimento zera o contador e interrompe a animação na hora
--  • Passou WaitTime segundos parado -> toca. Terminou -> agenda a próxima
--    (mais WaitTime segundos parado) e assim por diante.

local IDLE_VARIANT_SETTINGS = {
    AnimId = "rbxassetid://133201196209194",      -- Animação
    SoundId = "rbxassetid://119056579190272",     -- Som
    SpeechId = "107413276128350",                 -- Imagem do balão
    WaitTime = 10,                                -- Segundos parado para tocar
    AnimSpeed = 1.7,
    SoundVolume = 1.8,
    SpeechDuration = 3,
    SpeechSide = "right",
    MoveThreshold = 1.5,                          -- studs/s: acima disso conta como movimento
}

-- VARIÁVEIS INTERNAS
local idleVariant_Track = nil
local idleVariant_Timer = 0
local idleVariant_Playing = false
local idleVariant_LastPos = nil
local idleVariant_LastChar = nil
local idleVariant_Extras = {}   -- som e balão da fala atual

-- Estados em que o boneco pode ser considerado "parado"
local IDLE_ALLOWED_STATES = {
    [Enum.HumanoidStateType.Running] = true,
    [Enum.HumanoidStateType.RunningNoPhysics] = true,
    [Enum.HumanoidStateType.Landed] = true,
}

-- Se alguma animação de ação (ataque, barrage, etc.) estiver tocando, não é idle
local IDLE_BLOCKING_PRIORITIES = {
    [Enum.AnimationPriority.Action] = true,
    [Enum.AnimationPriority.Action2] = true,
    [Enum.AnimationPriority.Action3] = true,
    [Enum.AnimationPriority.Action4] = true,
}

local function isBaseLocomotionTrack(track)
    local id = track.Animation and track.Animation.AnimationId
    if not id then return false end
    return id == CUSTOM_ANIMS.Idle or id == CUSTOM_ANIMS.Walk or id == CUSTOM_ANIMS.Run
        or id == IDLE_VARIANT_SETTINGS.AnimId
        or id == originalIDs_anim.Idle or id == originalIDs_anim.Idle2
        or id == originalIDs_anim.Walk or id == originalIDs_anim.Run
end

-- ==================== LIMPEZA ====================
local function clearIdleVariantExtras()
    for _, obj in ipairs(idleVariant_Extras) do
        pcall(function()
            if obj:IsA("Sound") then obj:Stop() end
            obj:Destroy()
        end)
    end
    table.clear(idleVariant_Extras)
end

-- Para tudo (animação + som + balão) e zera o contador
local function resetIdleVariant(fadeTime)
    local track = idleVariant_Track
    idleVariant_Track = nil
    idleVariant_Playing = false
    idleVariant_Timer = 0
    if track then
        pcall(function() track:Stop(fadeTime or 0.2) end)
    end
    clearIdleVariantExtras()
end

-- ==================== TOCAR A ANIMAÇÃO ====================
local function playIdleVariant()
    local currentHum, currentChar = hum, character
    if not currentHum or not currentChar then return end

    resetIdleVariant(0)

    local anim = Instance.new("Animation")
    anim.AnimationId = IDLE_VARIANT_SETTINGS.AnimId
    local ok, track = pcall(function() return currentHum:LoadAnimation(anim) end)
    if not ok or not track then return end

    idleVariant_Track = track
    idleVariant_Playing = true
    idleVariant_Timer = 0

    track.Looped = false
    track.Priority = Enum.AnimationPriority.Idle
    track:Play(0.3)
    track:AdjustSpeed(IDLE_VARIANT_SETTINGS.AnimSpeed)

    -- Terminou sozinha: libera e agenda a próxima (mais WaitTime segundos parado)
    track.Stopped:Once(function()
        if idleVariant_Track == track then
            idleVariant_Track = nil
            idleVariant_Playing = false
            idleVariant_Timer = 0
        end
    end)

    -- 🔊 SOM
    local head = currentChar:FindFirstChild("Head")
    local sound = Instance.new("Sound")
    sound.SoundId = IDLE_VARIANT_SETTINGS.SoundId
    sound.Volume = IDLE_VARIANT_SETTINGS.SoundVolume
    sound.Parent = head or currentChar:FindFirstChild("HumanoidRootPart") or workspace
    sound:Play()
    Debris:AddItem(sound, 6)
    table.insert(idleVariant_Extras, sound)

    -- 💬 BALÃO DE FALA COM ANIMAÇÃO
    if head then
        local billboard = Instance.new("BillboardGui")
        billboard.Adornee = head
        billboard.Size = UDim2.new(3.5, 0, 3.5, 0)
        billboard.StudsOffset = Vector3.new(
            IDLE_VARIANT_SETTINGS.SpeechSide == "right" and 1.8 or -1.8,
            1.5,
            0
        )
        billboard.AlwaysOnTop = true
        billboard.LightInfluence = 0
        billboard.MaxDistance = 100
        billboard.Parent = head
        table.insert(idleVariant_Extras, billboard)

        local imageLabel = Instance.new("ImageLabel")
        imageLabel.BackgroundTransparency = 1
        imageLabel.Image = "rbxassetid://" .. IDLE_VARIANT_SETTINGS.SpeechId
        imageLabel.Size = UDim2.new(0.1, 0, 0.1, 0)
        imageLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
        imageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
        imageLabel.ImageTransparency = 1
        imageLabel.Rotation = -15
        imageLabel.Parent = billboard

        -- ENTRADA: cresce, aparece e endireita
        TweenService:Create(imageLabel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(1.1, 0, 1.1, 0),
            ImageTransparency = 0,
            Rotation = 0
        }):Play()

        -- "pop" de volta ao tamanho normal
        task.delay(0.4, function()
            if imageLabel.Parent then
                TweenService:Create(imageLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Size = UDim2.new(1, 0, 1, 0)
                }):Play()
            end
        end)

        -- Pulsa suave 3 vezes
        task.delay(0.6, function()
            for _ = 1, 3 do
                if not imageLabel.Parent then return end
                TweenService:Create(imageLabel, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                    Size = UDim2.new(1.05, 0, 1.05, 0)
                }):Play()
                task.wait(0.3)
                if not imageLabel.Parent then return end
                TweenService:Create(imageLabel, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                    Size = UDim2.new(1, 0, 1, 0)
                }):Play()
                task.wait(0.3)
            end
        end)

        -- SAÍDA: encolhe, some e gira
        task.delay(IDLE_VARIANT_SETTINGS.SpeechDuration - 0.4, function()
            if billboard.Parent and imageLabel.Parent then
                TweenService:Create(imageLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Size = UDim2.new(0.1, 0, 0.1, 0),
                    ImageTransparency = 1,
                    Rotation = 15
                }):Play()
                task.delay(0.4, function()
                    if billboard.Parent then billboard:Destroy() end
                end)
            end
        end)
    end
end

-- ==================== O BONECO ESTÁ PARADO DE VERDADE? ====================
local function isReallyStill(root, dt)
    -- Deslocamento real entre frames (pega movimento por CFrame/teleporte/empurrão também)
    local pos = root.Position
    local moved = false
    if idleVariant_LastPos and dt > 0 then
        moved = (pos - idleVariant_LastPos).Magnitude / dt > IDLE_VARIANT_SETTINGS.MoveThreshold
    end
    idleVariant_LastPos = pos
    if moved then return false end

    if not hum or hum.Health <= 0 then return false end
    if root.Anchored then return false end                                  -- congelado/habilidade
    if not IDLE_ALLOWED_STATES[hum:GetState()] then return false end       -- pulo, queda, sentado, etc.
    if hum.FloorMaterial == Enum.Material.Air then return false end        -- no ar
    if hum.MoveDirection.Magnitude > 0.05 then return false end            -- apertando andar
    if root.AssemblyLinearVelocity.Magnitude > IDLE_VARIANT_SETTINGS.MoveThreshold then return false end

    -- Alguma animação de ação (ataque, barrage...) tocando? então não está idle
    for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
        if t ~= idleVariant_Track and t.IsPlaying
            and IDLE_BLOCKING_PRIORITIES[t.Priority]
            and not isBaseLocomotionTrack(t) then
            return false
        end
    end

    return true
end

-- ==================== LOOP ====================
RunService.Heartbeat:Connect(function(dt)
    local char, h = character, hum
    if not char or not h or not h.Parent then return end

    if h.RigType == Enum.HumanoidRigType.R6 then return end -- RIG 6: sem Idle Variant

    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Personagem novo (respawn): começa do zero
    if idleVariant_LastChar ~= char then
        idleVariant_LastChar = char
        idleVariant_LastPos = nil
        resetIdleVariant(0)
    end

    if not isReallyStill(root, dt) then
        -- QUALQUER movimento/ação: zera o contador e interrompe a animação
        if idleVariant_Timer > 0 or idleVariant_Playing then
            resetIdleVariant(0.2)
        end
        return
    end

    -- Tocando agora: espera ela terminar (o timer só volta a contar depois)
    if idleVariant_Playing then return end

    idleVariant_Timer = idleVariant_Timer + dt
    if idleVariant_Timer >= IDLE_VARIANT_SETTINGS.WaitTime then
        playIdleVariant()
    end
end)

-- ==================== RESETAR AO MORRER/RESPAWNAR ====================
player.CharacterAdded:Connect(function()
    idleVariant_LastPos = nil
    resetIdleVariant(0)
end)


-- ====================== OUTRAS FUNÇÕES DE ANIMAÇÃO ======================

local function updateNormalRunSpeed_anim()
    if not hum or not SETTINGS.Enabled then return end
    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
        if track and track.Animation and track.Animation.AnimationId == CUSTOM_ANIMS.Run then
            pcall(function()
                track.Speed = SETTINGS.RunAnimSpeed
            end)
        end
    end
end

local function updateRunAnimation_anim()
    if not hum or not character or not SETTINGS.Enabled then
        if sRunTrack_anim then 
            pcall(function() sRunTrack_anim:Stop(0.2) end) 
            sRunTrack_anim = nil 
        end
        return
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local horizSpeed = Vector3.new(root.Velocity.X, 0, root.Velocity.Z).Magnitude

    if horizSpeed > 20 then
        if not sRunTrack_anim then
            sRunTrack_anim = loadCustomAnim(CUSTOM_ANIMS.SRun)
            if not sRunTrack_anim then return end
            sRunTrack_anim.Looped = false
            sRunTrack_anim.Priority = Enum.AnimationPriority.Movement
        end

        local now = os.clock()
        if (now - lastSRunTime_anim >= SETTINGS.SRunRestartInterval) or not sRunTrack_anim.IsPlaying then
            if sRunTrack_anim.IsPlaying then sRunTrack_anim:Stop(0) end
            sRunTrack_anim:Play(0.1, 1, SETTINGS.SRunAnimSpeed)
            lastSRunTime_anim = now
        end
    else
        if sRunTrack_anim then
            pcall(function() sRunTrack_anim:Stop(0.2) end)
            sRunTrack_anim = nil
        end
        lastSRunTime_anim = 0
    end
end

local function cleanupCustomAnims()
    -- Reseta o IdleVariant
    resetIdleVariant(0)

    if sRunTrack_anim then 
        pcall(function() sRunTrack_anim:Stop() end) 
        sRunTrack_anim = nil 
    end
    lastSRunTime_anim = 0

    if animLoopConnection_anim then animLoopConnection_anim:Disconnect() animLoopConnection_anim = nil end
    if jumpingConnection_anim then jumpingConnection_anim:Disconnect() jumpingConnection_anim = nil end
    if jumpStateConnection_anim then jumpStateConnection_anim:Disconnect() jumpStateConnection_anim = nil end

    if hum then hum.JumpPower = SETTINGS.JumpPower end
end

local function setCustomAnims()
    if not character then return end
    local animate = character:FindFirstChild("Animate")
    if not animate then return end

    local ids
    if not SETTINGS.Enabled then
        ids = originalIDs_anim
    else
        ids = {
            Idle = CUSTOM_ANIMS.Idle, 
            Idle2 = CUSTOM_ANIMS.Idle,
            Walk = CUSTOM_ANIMS.Walk, 
            Run = CUSTOM_ANIMS.Run,
            Fall = CUSTOM_ANIMS.Fall
        }
    end

    safeSetAnim(animate, {"idle", "Animation1"}, ids.Idle)
    safeSetAnim(animate, {"idle", "Animation2"}, ids.Idle2 or ids.Idle)
    safeSetAnim(animate, {"walk", "WalkAnim"}, ids.Walk)
    safeSetAnim(animate, {"run", "RunAnim"}, ids.Run)
    safeSetAnim(animate, {"fall", "FallAnim"}, ids.Fall)
    
    -- Refresh animations
    if character and hum then
        for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
            track:Stop(0)
        end
        local animate2 = character:FindFirstChild("Animate")
        if animate2 then
            animate2.Disabled = true
            task.wait(0.08)
            animate2.Disabled = false
        end
    end
    
    if hum then hum.WalkSpeed = originalWalkSpeed_anim end
end

local function onCharacterAddedCustomAnims(char)
    cleanupCustomAnims()
    character = char
    hum = char:WaitForChild("Humanoid")
    
    originalWalkSpeed_anim = hum.WalkSpeed

    -- RIG 6: não mexe em nenhuma animação do boneco (idle/walk/run/jump/fall)
    if isPlayerR6() then
        hum.JumpPower = SETTINGS.JumpPower
        return
    end

    local animate = char:FindFirstChild("Animate")
    if not animate then
        warn("[DioStand] Animate não encontrado no personagem!")
        return
    end
    
    -- Garante que as animações existem (cria se necessário)
    local function ensureAnimationFolder(parent, folderName, animName, defaultId)
        local folder = parent:FindFirstChild(folderName)
        if not folder then
            folder = Instance.new("Folder")
            folder.Name = folderName
            folder.Parent = parent
        end
        local anim = folder:FindFirstChild(animName)
        if not anim then
            anim = Instance.new("Animation")
            anim.Name = animName
            anim.AnimationId = defaultId or ""
            anim.Parent = folder
        end
        return anim
    end
    
    ensureAnimationFolder(animate, "idle", "Animation1", "rbxassetid://0")
    ensureAnimationFolder(animate, "idle", "Animation2", "rbxassetid://0")
    ensureAnimationFolder(animate, "walk", "WalkAnim", "rbxassetid://0")
    ensureAnimationFolder(animate, "run", "RunAnim", "rbxassetid://0")
    ensureAnimationFolder(animate, "fall", "FallAnim", "rbxassetid://0")
    
    local anim2Id = animate.idle.Animation1.AnimationId
    if animate.idle:FindFirstChild("Animation2") then 
        anim2Id = animate.idle.Animation2.AnimationId 
    end
    
    local fallId = ""
    if animate.fall and animate.fall:FindFirstChild("FallAnim") then 
        fallId = animate.fall.FallAnim.AnimationId 
    end
    
    originalIDs_anim = {
        Idle  = animate.idle.Animation1.AnimationId,
        Idle2 = anim2Id,
        Walk  = animate.walk.WalkAnim.AnimationId,
        Run   = animate.run.RunAnim.AnimationId,
        Fall  = fallId
    }

    hum.JumpPower = SETTINGS.JumpPower
    setCustomAnims()

    -- Conexões de Jumping
    if jumpingConnection_anim then jumpingConnection_anim:Disconnect() end
    jumpingConnection_anim = hum.Jumping:Connect(function()
        if not SETTINGS.Enabled then return end
        local root = character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local speed = Vector3.new(root.Velocity.X, 0, root.Velocity.Z).Magnitude
        local animId = speed >= 8 and CUSTOM_ANIMS.JumpRunning or CUSTOM_ANIMS.JumpStanding
        
        if activeJumpTrack_anim and activeJumpTrack_anim.IsPlaying then 
            activeJumpTrack_anim:Stop(0.2) 
        end
        
        activeJumpTrack_anim = loadCustomAnim(animId)
        if not activeJumpTrack_anim then return end
        activeJumpTrack_anim.Looped = false
        activeJumpTrack_anim.Priority = Enum.AnimationPriority.Movement
        activeJumpTrack_anim:Play(0.3)
        activeJumpTrack_anim.Stopped:Once(function() activeJumpTrack_anim = nil end)
    end)

    if jumpStateConnection_anim then jumpStateConnection_anim:Disconnect() end
    jumpStateConnection_anim = hum.StateChanged:Connect(function(oldState, newState)
        if activeJumpTrack_anim and activeJumpTrack_anim.IsPlaying then
            if newState ~= Enum.HumanoidStateType.Jumping and newState ~= Enum.HumanoidStateType.Freefall then
                activeJumpTrack_anim:Stop(0.15)
            end
        end
    end)

    -- Heartbeat das animações de corrida
    if animLoopConnection_anim then animLoopConnection_anim:Disconnect() end
    animLoopConnection_anim = RunService.Heartbeat:Connect(function()
        updateRunAnimation_anim()
        updateNormalRunSpeed_anim()
    end)
end

player.CharacterRemoving:Connect(cleanupCustomAnims)
player.CharacterAdded:Connect(onCharacterAddedCustomAnims)
if player.Character then onCharacterAddedCustomAnims(player.Character) end

-- Motion Blur e Vento
local Camera = workspace.CurrentCamera
local blurEffect = Instance.new("BlurEffect")
blurEffect.Name = "TzeMotionBlur"
blurEffect.Size = 0
blurEffect.Parent = Lighting

local windAttachment = nil
local windEmitter = nil

local function createWindParticles()
    if windEmitter then return end
    windAttachment = Instance.new("Attachment")
    windAttachment.Parent = Camera
    windEmitter = Instance.new("ParticleEmitter")
    windEmitter.Name = "TzeWindParticles"
    windEmitter.Texture = "rbxassetid://241650885"
    windEmitter.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255))
    windEmitter.LightEmission = 0.7
    windEmitter.Rate = 0
    windEmitter.Lifetime = NumberRange.new(0.45, 0.9)
    windEmitter.Speed = NumberRange.new(110, 160)
    windEmitter.SpreadAngle = Vector2.new(35, 35)
    windEmitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.4, 0.07), NumberSequenceKeypoint.new(1, 0.01)})
    windEmitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
    windEmitter.Rotation = NumberRange.new(-120, 120)
    windEmitter.Acceleration = Vector3.new(0, -12, 0)
    windEmitter.Parent = windAttachment
end

local isSRunning_wind = false
local lastCameraCFrame_wind = Camera.CFrame

RunService.RenderStepped:Connect(function(dt)
    if not Camera then return end
    local currentCFrame = Camera.CFrame
    local rotDiff = lastCameraCFrame_wind.Rotation:Inverse() * currentCFrame.Rotation
    local _, yaw, _ = rotDiff:ToEulerAnglesYXZ()
    local turnSpeed = math.abs(yaw) / dt
    if turnSpeed > 3.5 then
        blurEffect.Size = math.clamp(turnSpeed * 1.2, 0, 9)
    else
        blurEffect.Size = math.max(blurEffect.Size - 45 * dt, 0)
    end
    lastCameraCFrame_wind = currentCFrame

    local speed = 0
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root then
        local vel = root.Velocity
        speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
    end

    isSRunning_wind = (speed > 18.5 and SETTINGS.Enabled)

    if isSRunning_wind then
        if not windEmitter then createWindParticles() end
        windEmitter.Rate = 380
        local shakeIntensity = 0.045 + (speed - 20) * 0.0022
        local shakeX = math.sin(os.clock() * 28) * shakeIntensity
        local shakeY = math.sin(os.clock() * 19) * shakeIntensity * 0.7
        Camera.CFrame *= CFrame.new(shakeX, shakeY, 0)
    else
        if windEmitter then
            windEmitter.Rate = 0
        end
    end
end)

if character then
    createWindParticles()
end

local STAND_OFFSET = Vector3.new(-3, 1.4, 2.5)
local isTimeStopped = false
local isStandActive = false
local isAttacking = false
local currentStand = nil
local idleTrack = nil
local walkTrack = nil
local frozenParts = {}
local frozenKnives = {} -- Lista de facas congeladas
local mudaComboCount = 0
local comboDisplay = nil
local comboTweens = {}
local standChangerGui = nil    
local lastKillConfirmTime = 0
local KILL_CONFIRM_COOLDOWN = 1

-- ============================================================
local idSalvo = carregarStandId()
local customStandUserId = nil
if idSalvo and idSalvo > 0 then
    customStandUserId = idSalvo
    print("🎮 Stand carregado automaticamente do arquivo!")
else
    print("👤 Nenhum ID salvo. Usando stand padrão.")
end
-- ============================================================

local COLORS = {
    Yellow      = Color3.fromRGB(255, 215, 0),
    Gold        = Color3.fromRGB(255, 235, 100),
    Purple      = Color3.fromRGB(170, 0, 255),
    DeepPurple  = Color3.fromRGB(100, 0, 180),
    Black       = Color3.fromRGB(10, 10, 15),
    DarkGray    = Color3.fromRGB(25, 25, 35),
    BloodRed    = Color3.fromRGB(180, 0, 20),
    White       = Color3.fromRGB(255, 255, 255),
    Green       = Color3.fromRGB(0, 255, 100),  
}

local ASSETS = {
	TS_START_SFX = "rbxassetid://7514417921",
	TS_END_SFX = "rbxassetid://97139043906890",
	ANIM_DIO = "rbxassetid://97640991968989",
	ANIM_DIO_VARIANT = "rbxassetid://102345422749885",
	STAND_IDLE = "rbxassetid://127063604572089",
	MUDA_SOUND = "rbxassetid://616593932",
	KNIFE_HIT_SOUND = "rbxassetid://743521337",
	BARRAGE_ANIM = "rbxassetid://90073013818806",
	PLAYER_BARRAGE = "rbxassetid://105746954691593",
	TS_IMAGE = "rbxassetid://107526909795121",
	STAND_IMAGE = "rbxassetid://71063600838165",
	KNIFE_IMAGE = "rbxassetid://128478684091020",
	ROAD_ROLLER_MESH = "rbxassetid://123055050240257",
	ROAD_ROLLER_TEXTURE = "rbxassetid://70977204379919",
	ROAD_ROLLER_DA = "124648495201789",
	ROAD_ROLLER_SPAWN_SFX = "rbxassetid://6273171415",
	ROAD_ROLLER_IMPACT_SFX1 = "rbxassetid://122293342039104",
	ROAD_ROLLER_IMPACT_SFX2 = "rbxassetid://138680390593747",
	ROAD_ROLLER_RIDE_ANIM = "rbxassetid://140327538515031",
	STAND_WALK = "rbxassetid://123349905320515",
	KNIFE_THROW_DIO_SFX = "rbxassetid://4415007771", 
KNIFE_THROW_STAND_SFX = "rbxassetid://118093612783120"
}

-- ==================== FINISHER VARIABLES ====================
local FINISHER_HEALTH_THRESHOLD = 25
local FINISHER_DURATION = 1.5

local isFinisherActive = false
local finisherConnection = nil
local noclipFinisherConn = nil
local finisherTargetRoot = nil

-- ==================== TOUCH FLING (burst de velocidade, tecnica do XJ_Fling) ====================
-- Substitui o NaN Fling (patched). Tudo num so table para nao gastar locals do chunk.
-- Valores de POWER_MULT vem do XJ_Fling.txt do usuario; os marcados "nao calibrado" sao palpites.
local FF = {
	POWER_MULT = 20000000000,

	-- true: o root vai ao alvo so entre o Heartbeat e o RenderStepped e volta antes de desenhar.
	--       NAO verificado que o servidor recebe essa posicao.
	-- false: o corpo realmente fica no alvo durante o finisher (posicao replicada, tela pula).
	RESTORE_POSITION_EACH_FRAME = true,

	-- Fling so funcionava andando. Hipotese (nao verificada): parado, o root dorme e o burst
	-- nao e enviado. KEEP_AWAKE devolve velocidade minima e faz tremor minusculo de posicao.
	KEEP_AWAKE = true,
	AWAKE_SPEED_THRESHOLD = 1,   -- studs/s, nao calibrado
	WAKE_VELOCITY_Y = 0.1,       -- mesmo valor do "acordar" do codigo antigo do usuario
	WAKE_JITTER = 0.02,          -- studs, nao calibrado

	-- A camera segue um anchor invisivel que recebe a posicao "de casa" do root a cada frame:
	-- acompanha o corpo andando livre e ignora o pulo ate o alvo. O corpo (soldado ao root por
	-- Motor6D) continua indo e voltando; so a camera ignora.
	DECOUPLE_CAMERA = true,

	DEBUG = true,

	-- estado
	session = 0,
	bursts = 0,
	char = nil,
	root = nil,
	returnCFrame = nil,
	cameraAnchor = nil,
	origCameraSubject = nil,
	origCameraType = nil,
}

local endFinisher

local function startFinisher(targetRoot)
	if isFinisherActive or not targetRoot or not targetRoot.Parent then return end

	local myRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not myRoot or not hum or hum.Health <= 0 then return end

	isFinisherActive = true
	finisherTargetRoot = targetRoot

	FF.session += 1
	local session = FF.session
	FF.bursts = 0
	FF.char = character
	FF.root = myRoot
	FF.returnCFrame = myRoot.CFrame

	if FF.DEBUG then
		print(string.format("[FINISHER] inicio alvo=%s distancia=%.1f restaura_posicao=%s",
			tostring(targetRoot.Parent and targetRoot.Parent.Name),
			(targetRoot.Position - myRoot.Position).Magnitude,
			tostring(FF.RESTORE_POSITION_EACH_FRAME)))
	end

	-- CAMERA: anchor invisivel que segue a posicao "de casa" do root
	if FF.DECOUPLE_CAMERA then
		local cam = workspace.CurrentCamera
		if cam then
			FF.origCameraSubject = cam.CameraSubject
			FF.origCameraType = cam.CameraType

			local anchor = Instance.new("Part")
			anchor.Name = "FinisherCameraAnchor"
			anchor.Size = Vector3.new(1, 1, 1)
			anchor.Transparency = 1
			anchor.CanCollide = false
			anchor.Anchored = true
			anchor.CFrame = myRoot.CFrame
			anchor.Parent = workspace
			FF.cameraAnchor = anchor

			cam.CameraType = Enum.CameraType.Custom
			cam.CameraSubject = anchor
		end
	end

	-- NOCLIP NO SEU PERSONAGEM (atravessa tudo) e no alvo (igual ao codigo anterior)
	noclipFinisherConn = RunService.Stepped:Connect(function()
		if not character or not character.Parent then return end
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
		if finisherTargetRoot and finisherTargetRoot.Parent then
			for _, part in ipairs(finisherTargetRoot.Parent:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end
	end)

	-- BURST: o root vai ate o alvo, envia velocidade enorme e a velocidade real volta depois do RenderStepped
	local startTime = os.clock()
	local burstIndex = 0
	local con
	con = RunService.Heartbeat:Connect(function()
		if finisherConnection ~= con then
			con:Disconnect()
			return
		end

		local tRoot = finisherTargetRoot
		if os.clock() - startTime > FINISHER_DURATION
			or not myRoot.Parent
			or hum.Health <= 0
			or FF.char ~= character
			or not tRoot or not tRoot.Parent then
			endFinisher()
			return
		end

		local tHum = tRoot.Parent:FindFirstChildOfClass("Humanoid")
		if tHum and tHum.Health <= 0 then
			endFinisher()
			return
		end

		local homeCFrame = myRoot.CFrame
		if FF.cameraAnchor then
			FF.cameraAnchor.CFrame = homeCFrame
		end
		local vel    = myRoot.AssemblyLinearVelocity
		local angVel = myRoot.AssemblyAngularVelocity

		burstIndex += 1
		FF.bursts += 1
		local sign = burstIndex % 2 == 0 and 1 or -1
		local P = FF.POWER_MULT

		myRoot.CFrame = tRoot.CFrame
		myRoot.AssemblyLinearVelocity  = Vector3.new(P * sign, P, P * -sign)
		myRoot.AssemblyAngularVelocity = Vector3.new(P * -sign, P * sign, P)

		RunService.RenderStepped:Wait()

		if finisherConnection ~= con or not myRoot.Parent then return end

		local standingStill = FF.KEEP_AWAKE and vel.Magnitude < FF.AWAKE_SPEED_THRESHOLD
		myRoot.AssemblyLinearVelocity  = standingStill and Vector3.new(0, FF.WAKE_VELOCITY_Y, 0) or vel
		myRoot.AssemblyAngularVelocity = angVel
		if FF.RESTORE_POSITION_EACH_FRAME then
			local jitter = standingStill and FF.WAKE_JITTER * sign or 0
			myRoot.CFrame = homeCFrame * CFrame.new(jitter, 0, 0)
		end
	end)
	finisherConnection = con

	-- Limpeza apos a duracao (o session evita que um timer antigo encerre um finisher novo)
	task.delay(FINISHER_DURATION, function()
		if isFinisherActive and FF.session == session then
			endFinisher()
		end
	end)
end

function endFinisher()
	if FF.DEBUG and isFinisherActive then
		print("[FINISHER] fim | bursts enviados:", FF.bursts)
	end

	if finisherConnection then
		finisherConnection:Disconnect()
		finisherConnection = nil
	end
	if noclipFinisherConn then
		noclipFinisherConn:Disconnect()
		noclipFinisherConn = nil
	end

	isFinisherActive = false

	-- Camera de volta ao normal
	if FF.cameraAnchor then
		local cam = workspace.CurrentCamera
		if cam then
			pcall(function()
				cam.CameraSubject = FF.origCameraSubject
				if FF.origCameraType then
					cam.CameraType = FF.origCameraType
				end
			end)
		end
		FF.cameraAnchor:Destroy()
		FF.cameraAnchor = nil
		FF.origCameraSubject = nil
		FF.origCameraType = nil
	end

	local myRoot, returnCFrame = FF.root, FF.returnCFrame
	local sameCharacter = FF.char ~= nil and FF.char == character
	FF.char, FF.root, FF.returnCFrame = nil, nil, nil

	-- Se o corpo ficou de verdade no alvo, volta para a posicao original e zera a velocidade.
	-- No outro modo o jogador continua livre e nada e mexido.
	if myRoot and returnCFrame and sameCharacter and myRoot.Parent
		and not FF.RESTORE_POSITION_EACH_FRAME then
		pcall(function()
			myRoot.AssemblyLinearVelocity  = Vector3.zero
			myRoot.AssemblyAngularVelocity = Vector3.zero
			myRoot.CFrame = returnCFrame
		end)
	end

	-- Restaura colisao do seu personagem
	if character and character.Parent then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = true
			end
		end
	end

	-- Restaura colisao do alvo
	if finisherTargetRoot and finisherTargetRoot.Parent then
		for _, part in ipairs(finisherTargetRoot.Parent:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = true
			end
		end
	end

	finisherTargetRoot = nil
end

local screenGui = Instance.new("ScreenGui", player.PlayerGui)
screenGui.Name = "DioStandUniversal"
screenGui.ResetOnSpawn = false

local function showComboCounter()
	for _, tween in ipairs(comboTweens) do
		if tween then tween:Cancel() end
	end
	comboTweens = {}
	
	if comboDisplay then
		comboDisplay:Destroy()
	end
	
	comboDisplay = Instance.new("TextLabel")
	comboDisplay.Name = "MudaComboHUD"
	comboDisplay.Size = UDim2.new(0, 60, 0, 25)
	comboDisplay.Position = UDim2.new(0.6, -30, 0.68, 0)
	comboDisplay.AnchorPoint = Vector2.new(0.5, 1)
	comboDisplay.BackgroundTransparency = 1
	comboDisplay.Text = "x" .. mudaComboCount
	comboDisplay.TextColor3 = Color3.fromRGB(255, 215, 0)
	comboDisplay.TextStrokeTransparency = 0
	comboDisplay.TextStrokeColor3 = Color3.fromRGB(180, 0, 0)
	comboDisplay.Font = Enum.Font.Bangers
	comboDisplay.TextSize = 20
	comboDisplay.ZIndex = 100
	comboDisplay.Parent = screenGui
	
	comboDisplay.TextTransparency = 1
	local tweenIn = TweenService:Create(comboDisplay, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		TextSize = 26
	})
	tweenIn:Play()
	table.insert(comboTweens, tweenIn)
	
	task.delay(0.15, function()
		if comboDisplay and comboDisplay.Parent then
			local tweenBack = TweenService:Create(comboDisplay, TweenInfo.new(0.15), {
				TextSize = 20
			})
			tweenBack:Play()
		end
	end)
	
	task.delay(1.5, function()
		if comboDisplay and comboDisplay.Parent then
			local tweenOut = TweenService:Create(comboDisplay, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				TextTransparency = 1
			})
			tweenOut:Play()
			tweenOut.Completed:Connect(function()
				if comboDisplay and comboDisplay.Parent then
					comboDisplay:Destroy()
					comboDisplay = nil
				end
			end)
		end
	end)
end

local function cameraShake(duration, intensity)
	if not hum then return end
	local start = tick()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - start
		if elapsed < duration then
			local currentIntensity = intensity * (1 - (elapsed / duration))
			local rx = (math.random() - 0.5) * currentIntensity
			local ry = (math.random() - 0.5) * currentIntensity
			local rz = (math.random() - 0.5) * currentIntensity
			hum.CameraOffset = Vector3.new(rx, ry, rz)
		else
			hum.CameraOffset = Vector3.new(0, 0, 0)
			connection:Disconnect()
		end
	end)
end

local function cinematicZoom(duration, targetFOV)
	local camera = workspace.CurrentCamera
	if not camera then return end
	
	local originalFOV = camera.FieldOfView
	
	TweenService:Create(camera, TweenInfo.new(duration * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		FieldOfView = targetFOV
	}):Play()
	
	task.delay(duration * 0.6, function()
		TweenService:Create(camera, TweenInfo.new(duration * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FieldOfView = originalFOV
		}):Play()
	end)
end

local COOLDOWNS = {Barragem = 3.5, Knife = 1, TimeStop = 10, RoadRoller = 15}
local lastUsed = {Barragem = 0, Knife = 0, TimeStop = 0, RoadRoller = 0}

local function showSpeechBubble(imageId, side, duration, customHead)
	if not customHead then
		if not character or not character:FindFirstChild("Head") then return end
		customHead = character.Head
	end
	local head = customHead
	if not head or not head.Parent then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "JojoSpeechBubble"
	billboard.Adornee = head
	billboard.Size = UDim2.new(3.5, 0, 3.5, 0)
	billboard.StudsOffset = Vector3.new(side == "right" and 1.8 or -1.8, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 100
	billboard.Parent = head

	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = "BubbleImage"
	imageLabel.BackgroundTransparency = 1
	imageLabel.Image = "rbxassetid://" .. imageId
	imageLabel.ImageTransparency = 1
	
	imageLabel.Size = UDim2.new(0.2, 0, 0.2, 0)
	imageLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	imageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	
	imageLabel.Parent = billboard

	local tweenInfoIn = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tweenIn = TweenService:Create(imageLabel, tweenInfoIn, {
		Size = UDim2.new(1, 0, 1, 0),
		ImageTransparency = 0
	})
	tweenIn:Play()

	task.delay(duration, function()
		if billboard and billboard.Parent then
			local tweenInfoOut = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local tweenOut = TweenService:Create(imageLabel, tweenInfoOut, {
				Size = UDim2.new(0.2, 0, 0.2, 0),
				ImageTransparency = 1
			})
			
			tweenOut:Play()
			tweenOut.Completed:Connect(function(playbackState)
				if playbackState == Enum.PlaybackState.Completed then
					if billboard and billboard.Parent then
						billboard:Destroy()
					end
				end
			end)
		end
	end)
end

local TS_POS = UDim2.new(0.4, 0, 0.78, 0)
local ROAD_POS = UDim2.new(0.3, 0, 0.79, 0)
local ACTIVATE_POS = UDim2.new(0.5, 0, 0.75, 0)
local BARRAGEM_POS = UDim2.new(0.6, 0, 0.78, 0)
local KNIFE_POS_ON = UDim2.new(0.7, 0, 0.78, 0)
local KNIFE_POS_OFF = BARRAGEM_POS

local function createCircularButton(name, pos, text, color, imageId, sizeOffset)
	sizeOffset = sizeOffset or 70
	color = color or COLORS.Yellow
	local btn = Instance.new("TextButton", screenGui)
	btn.Name = name
	btn.Size = UDim2.fromOffset(sizeOffset, sizeOffset)
	btn.Position = pos
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	btn.Text = text
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.Bangers
	btn.TextSize = 14
	btn.TextStrokeTransparency = 0
	btn.TextStrokeColor3 = Color3.new(0, 0, 0)
	btn.AutoButtonColor = false
	Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke", btn)
	stroke.Color = color
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local icon = nil
	if imageId then
		icon = Instance.new("ImageLabel", btn)
		icon.Name = "Icon"
		icon.Size = UDim2.new(1, 0, 1, 0)
		icon.Position = UDim2.new(0.49, 0, 0.5, 0)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Image = imageId
		icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = 2
		Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)
	end
	return btn, stroke, icon
end

local tsBtn, tsStroke, tsIcon = createCircularButton("TimeStopBtn", TS_POS, "STOP", nil, ASSETS.TS_IMAGE, 80)
local roadBtn, roadStroke = createCircularButton("RoadRollerBtn", ROAD_POS, "ROAD", Color3.fromRGB(170, 0, 255), nil, 70)
local activateBtn, actStroke, standIcon = createCircularButton("ActivateBtn", ACTIVATE_POS, "STAND", nil, ASSETS.STAND_IMAGE, 95)
local barragemBtn, barragemStroke = createCircularButton("BarragemBtn", BARRAGEM_POS, "BARRAGEM", nil, nil, 80)
local knifeBtn, knifeStroke, knifeIcon = createCircularButton("KnifeBtn", KNIFE_POS_OFF, "KNIFE", nil, ASSETS.KNIFE_IMAGE, 80)

barragemBtn.Visible = false
barragemBtn.Position = ACTIVATE_POS
barragemBtn.Size = UDim2.fromOffset(0, 0)
knifeBtn.Visible = true
roadBtn.Visible = false
roadBtn.Position = TS_POS
roadBtn.Size = UDim2.fromOffset(0, 0)

local function updateIconState(icon, isActive)
	if not icon then return end
	icon.ImageColor3 = isActive and Color3.fromRGB(128, 128, 128) or Color3.fromRGB(255, 255, 255)
end

updateIconState(tsIcon, false)
updateIconState(standIcon, false)
updateIconState(knifeIcon, false)

local function updateKnifePosition(isActive)
	if isActive then
		TweenService:Create(knifeBtn, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.7, 0, 0.79, 0), 
			Size = UDim2.fromOffset(70, 70)
		}):Play()
	else
		TweenService:Create(knifeBtn, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		    Position = KNIFE_POS_OFF, 
			Size = UDim2.fromOffset(80, 80)
		}):Play()
	end
end

local function playAnim(target, animId, speed, looped, priority)
    if not target or not target.Parent then return end
    local a = Instance.new("Animation")
    a.AnimationId = animId
    local track = target:LoadAnimation(a)
    
    track.Looped = (looped == true)
    
    if priority then track.Priority = priority end
    
    track:Play()
    if speed then track:AdjustSpeed(speed) end
    
    return track
end

-- ============================================================
-- 🦴 STAND POSE — SISTEMA DE ANIMAÇÃO PROCEDURAL (portado do TheHand)
-- Anima as juntas do Stand (Motor6D ou AnimationConstraint) pelo C0, com
-- interpolação Hermite/Catmull-Rom, reaplicada em 3 pontos do frame, com
-- re-scan automático das juntas e parada dos tracks do Animator.
-- Ângulos em graus no eixo da peça-pai:
--   braço/perna X+ = para frente | tronco/cabeça X- = inclina pra frente
--   Y+ = gira para a esquerda    | braço direito Z+ = abre pro lado (esquerdo: Z-)
--   cotovelo X+ = dobra          | joelho X- = dobra
-- ============================================================
local V3d = Vector3.new
local ZERO3 = V3d()

local SP_KEYS = { "waist", "neck", "rsh", "rel", "rwr", "lsh", "lel", "lwr", "rh", "rk", "ra", "lh", "lk", "la" }

local STAND_POSE = {
    FadeIn     = 0.05,  -- tempo para entrar na pose
    FadeOut    = 0.14,  -- tempo para sair da pose
    Intensity  = 1.0,   -- multiplicador geral dos ângulos
    KillTracks = true,  -- para os tracks do Animator do Stand enquanto a pose roda
}

local function spSmooth(a) return a * a * (3 - 2 * a) end

-- Tangente de Catmull-Rom (não uniforme)
local function spTangent(frames, i, key)
    local f = frames[i]
    if f.hold or i == 1 or i == #frames then return nil end
    local p, n = frames[i - 1], frames[i + 1]
    local dt = n.t - p.t
    if key == "crouch" then
        return ((n.crouch or 0) - (p.crouch or 0)) / dt
    end
    return ((n[key] or ZERO3) - (p[key] or ZERO3)) / dt
end

-- Avalia uma lista de keyframes no tempo t (spline Hermite)
local function spEvalFrames(frames, t)
    local last = frames[#frames]
    local pose = { crouch = 0 }
    if t >= last.t then
        pose.crouch = last.crouch or 0
        for _, k in ipairs(SP_KEYS) do pose[k] = last[k] or ZERO3 end
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

    local m0 = spTangent(frames, ia, "crouch") or 0
    local m1 = spTangent(frames, ia + 1, "crouch") or 0
    pose.crouch = h00 * (a.crouch or 0) + h10 * dt * m0 + h01 * (b.crouch or 0) + h11 * dt * m1

    for _, k in ipairs(SP_KEYS) do
        local t0 = spTangent(frames, ia, k) or ZERO3
        local t1 = spTangent(frames, ia + 1, k) or ZERO3
        pose[k] = (a[k] or ZERO3) * h00 + t0 * (h10 * dt) + (b[k] or ZERO3) * h01 + t1 * (h11 * dt)
    end
    return pose
end

local function spLerpPose(a, b, w)
    local o = { crouch = (a.crouch or 0) + ((b.crouch or 0) - (a.crouch or 0)) * w }
    for _, k in ipairs(SP_KEYS) do
        o[k] = (a[k] or ZERO3):Lerp(b[k] or ZERO3, w)
    end
    return o
end

-- ===================== CORREÇÃO DE RIG: junções agnósticas ======================
-- Rigs novos (AnimationConstraint) não têm Part0/Part1/C0: usam Attachment0/Attachment1.
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

local SP_KIN = setmetatable({}, { __mode = "k" })      -- IsKinematic original
local SP_BASE_C0 = setmetatable({}, { __mode = "k" })  -- C0 original (guardado UMA vez)

local function spJoints(ch)
    local map = {
        root  = { "LowerTorso" },
        waist = { "UpperTorso" },
        neck  = { "Head" },
        rsh = { "RightUpperArm", "Right Arm" },
        rel = { "RightLowerArm" },
        rwr = { "RightHand" },
        lsh = { "LeftUpperArm", "Left Arm" },
        lel = { "LeftLowerArm" },
        lwr = { "LeftHand" },
        rh = { "RightUpperLeg", "Right Leg" },
        rk = { "RightLowerLeg" },
        ra = { "RightFoot" },
        lh = { "LeftUpperLeg", "Left Leg" },
        lk = { "LeftLowerLeg" },
        la = { "LeftFoot" },
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
                -- R6: o RootJoint liga HumanoidRootPart -> Torso
                if not J.root and p0.Name == "HumanoidRootPart" and p1.Name == "Torso" then
                    J.root = d
                end
            end
        end
    end
    -- AnimationConstraint: modo cinemático (move a peça direto, sem depender de física)
    for _, m in pairs(J) do
        if m:IsA("AnimationConstraint") and SP_KIN[m] == nil then
            pcall(function()
                SP_KIN[m] = m.IsKinematic
                m.IsKinematic = true
            end)
        end
    end
    return J
end

-- Conserta o rig do Stand: PrimaryPart, Humanoid, Animator, juntas ligadas e peças sem colisão/massa
local function spFixRig(model)
    if not model then return end
    local sHum = model:FindFirstChildOfClass("Humanoid")
    local sRoot = model:FindFirstChild("HumanoidRootPart")
    if sRoot and model.PrimaryPart ~= sRoot then
        pcall(function() model.PrimaryPart = sRoot end)
    end
    if sHum then
        sHum.PlatformStand = true
        sHum.AutoRotate = false
        sHum.HipHeight = 0
        pcall(function() sHum.BreakJointsOnDeath = false end)
        pcall(function() sHum.RequiresNeck = false end)
        if not sHum:FindFirstChildOfClass("Animator") then
            local an = Instance.new("Animator")
            an.Parent = sHum
        end
    end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("JointInstance") then
            pcall(function() d.Enabled = true end)
        elseif d:IsA("BasePart") then
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
            d.Massless = true
        end
    end
end

-- ===================== MOTOR DA POSE ======================
local StandPose = { J = nil, char = nil, t0 = 0, w = 0, fading = false, fadeTime = 0.3, bound = false,
                    evalFn = nil, lastClock = 0, lastScan = 0, conns = nil,
                    isPlayer = false, muted = nil }
local SP_BIND = "DioStandPose"

local function spApply(m, rotDeg, offset, w)
    local base = SP_BASE_C0[m]
    if not base then
        base = spGetC0(m)
        SP_BASE_C0[m] = base
    end
    local c0 = base - base.Position
    local A = CFrame.Angles(math.rad(rotDeg.X), math.rad(rotDeg.Y), math.rad(rotDeg.Z))
    if offset then A = CFrame.new(offset) * A end
    local T = c0:Inverse() * A * c0
    spSetC0(m, base * CFrame.new():Lerp(T, w))
end

local function spDisconnect()
    if StandPose.conns then
        for _, c in ipairs(StandPose.conns) do
            pcall(function() c:Disconnect() end)
        end
        StandPose.conns = nil
    end
end

-- Devolve o peso das animações do boneco que foram silenciadas durante a pose
local function spRestoreMuted(fade)
    local m = StandPose.muted
    StandPose.muted = nil
    if not m then return end
    for tr, w in pairs(m) do
        if w > 0.01 then
            pcall(function()
                if tr.IsPlaying then tr:AdjustWeight(w, fade or 0.15) end
            end)
        end
    end
end

function StandPose.reset()
    if StandPose.J then
        for _, m in pairs(StandPose.J) do
            if m.Parent then
                local base = SP_BASE_C0[m]
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
    StandPose.J, StandPose.char = nil, nil
end

function StandPose.stopNow()
    if StandPose.bound then
        pcall(function() RunService:UnbindFromRenderStep(SP_BIND) end)
        StandPose.bound = false
    end
    spDisconnect()
    StandPose.reset()
    spRestoreMuted(0.15)
    StandPose.isPlayer = false
    StandPose.fading = false
    StandPose.w = 0
end

function StandPose.stop(fade)
    if not StandPose.bound then return end
    StandPose.fading = true
    StandPose.fadeTime = math.max(fade or STAND_POSE.FadeOut, 0.01)
    spRestoreMuted(StandPose.fadeTime)
end

-- Um passo da pose (roda até 3x por frame; tempo/peso baseados em os.clock, então é seguro)
local function spStep(isMain)
    if not StandPose.bound then return end

    local char = StandPose.char
    if not char or not char.Parent then
        StandPose.stopNow()
        return
    end

    local now = os.clock()
    local dt = math.clamp(now - StandPose.lastClock, 0, 0.1)
    StandPose.lastClock = now

    local rate = StandPose.fading and (1 / StandPose.fadeTime) or (1 / math.max(STAND_POSE.FadeIn, 0.01))
    local goal = StandPose.fading and 0 or 1
    StandPose.w = StandPose.w + math.clamp(goal - StandPose.w, -rate * dt, rate * dt)
    if StandPose.fading and StandPose.w <= 0.001 then
        StandPose.stopNow()
        return
    end

    -- Animator do Stand brigando com a pose: para qualquer track enquanto ela roda
    if isMain and not StandPose.fading then
        local sh = char:FindFirstChildOfClass("Humanoid")
        local an = sh and sh:FindFirstChildOfClass("Animator")
        if an then
            if StandPose.isPlayer then
                -- Boneco: NÃO para as animações (o Animate/idle não reinicia sozinho);
                -- só zera o peso delas durante a pose e devolve no final.
                StandPose.muted = StandPose.muted or {}
                for _, tr in ipairs(an:GetPlayingAnimationTracks()) do
                    if StandPose.muted[tr] == nil then StandPose.muted[tr] = tr.WeightTarget end
                    pcall(function() tr:AdjustWeight(0, 0) end)
                end
            elseif STAND_POSE.KillTracks then
                for _, tr in ipairs(an:GetPlayingAnimationTracks()) do
                    pcall(function() tr:Stop(0) end)
                end
            end
        end
    end

    -- O jogo trocou/removeu alguma junta? Re-escaneia (no máx. 1x a cada 0.2s)
    local J = StandPose.J
    local broken = false
    for _, m in pairs(J) do
        if not spValid(m) then broken = true break end
    end
    if broken and now - StandPose.lastScan > 0.2 then
        StandPose.lastScan = now
        J = spJoints(char)
        StandPose.J = J
    end

    local ok, pose = pcall(StandPose.evalFn, now - StandPose.t0)
    if not ok or not pose then
        warn("[StandPose] erro no avaliador: " .. tostring(pose))
        StandPose.stopNow()
        return
    end

    local w = spSmooth(math.clamp(StandPose.w, 0, 1))
    local mul = STAND_POSE.Intensity

    for key, m in pairs(J) do
        if spValid(m) and key ~= "root" then
            local r = pose[key]
            if r then spApply(m, r * mul, nil, w) end
        end
    end

    -- agachada (e, no R6, a inclinação do tronco) pelo RootJoint
    local root = J.root
    if root and root.Parent then
        local rot = J.waist and V3d() or ((pose.waist or ZERO3) * mul)
        spApply(root, rot, V3d(0, -(pose.crouch or 0) * mul, 0), w)
    end
end

-- evalFn(t) -> tabela de pose (waist, neck, rsh, ... , crouch). Retorna true se iniciou.
function StandPose.start(char, evalFn, opts)
    StandPose.stopNow()
    if not char or not evalFn then return false end
    StandPose.isPlayer = (opts and opts.player) == true
    -- spFixRig mexe em CanCollide/PlatformStand/Massless: SÓ no Stand, nunca no boneco
    if not StandPose.isPlayer then spFixRig(char) end
    local J = spJoints(char)

    if not (J.root or J.waist or J.rsh) then
        warn("[StandPose] nenhuma junta encontrada no Stand (rig diferente?)")
        return false
    end

    StandPose.J, StandPose.char = J, char
    StandPose.evalFn = evalFn
    StandPose.t0 = os.clock()
    StandPose.lastClock = StandPose.t0
    StandPose.lastScan = 0
    StandPose.w = 0
    StandPose.fading = false
    StandPose.bound = true

    -- 3 pontos do frame: o ÚLTIMO a escrever antes do render é quem aparece na tela
    RunService:BindToRenderStep(SP_BIND, Enum.RenderPriority.Last.Value, function() spStep(true) end)
    StandPose.conns = {
        RunService.Stepped:Connect(function() spStep(false) end),
        RunService.Heartbeat:Connect(function() spStep(false) end),
    }
    return true
end

-- ============================================================
-- ⭐ POSE DO BARRAGE "MUDA MUDA" (The World) — procedural
-- Socos alternados em altíssima velocidade, tronco girando junto com cada soco,
-- alturas/aberturas aleatórias (determinísticas), postura baixa e firme.
-- ============================================================
local SP_BARRAGE = { Period = 0.13 }   -- segundos por soco de cada braço (os braços alternam)

local function spHash(n)
    local x = math.sin(n * 127.1 + 311.7) * 43758.5453
    return x - math.floor(x)
end

-- 0..1..0 : sai MUITO rápido, volta suave
local function spPunch(c)
    if c < 0.28 then
        local a = c / 0.28
        return 1 - (1 - a) ^ 3
    end
    return 1 - spSmooth((c - 0.28) / 0.72)
end

-- tornozelo compensa quadril+joelho para o pé ficar reto
local function spAnkle(h, k) return V3d(-(h.X + k.X), 0, 0) end

local function spBarragePose(t)
    local P = SP_BARRAGE.Period
    local amp = spSmooth(math.clamp(t / 0.16, 0, 1))
    local cR, cL = t / P, t / P + 0.5
    local iR, iL = math.floor(cR), math.floor(cL)
    local pR, pL = spPunch(cR - iR) * amp, spPunch(cL - iL) * amp
    local hR, hL = spHash(iR * 2 + 1) * 2 - 1, spHash(iL * 2 + 2) * 2 - 1   -- altura  (-1 baixo .. 1 alto)
    local sR, sL = spHash(iR * 3 + 7) * 2 - 1, spHash(iL * 3 + 9) * 2 - 1   -- abertura lateral
    local twist, both = pR - pL, pR + pL
    local sway = twist * 5

    local rh, rk = V3d(-18 + sway, 0, 9), V3d(-34, 0, 0)
    local lh, lk = V3d(32 - sway, 0, -9), V3d(-52, 0, 0)
    local bob = math.abs(math.sin(t * math.pi / P)) * 0.12 * amp

    return {
        crouch = 0.40 + bob + (1 - amp) * 0.12,
        waist = V3d(-22 - both * 7, twist * 26, -twist * 5),
        neck  = V3d(12 + math.sin(t * 13) * 4, -twist * 15, twist * 5),
        rsh = V3d(18 + (70 + hR * 30) * pR, pR * (14 + sR * 10), 10 + (sR * 14 - 6) * pR),
        rel = V3d(100 - 96 * pR, 0, 0),
        rwr = V3d(-5 - 13 * pR, 0, 0),
        lsh = V3d(18 + (70 + hL * 30) * pL, -pL * (14 + sL * 10), -10 - (sL * 14 - 6) * pL),
        lel = V3d(100 - 96 * pL, 0, 0),
        lwr = V3d(-5 - 13 * pL, 0, 0),
        rh = rh, rk = rk, ra = spAnkle(rh, rk),
        lh = lh, lk = lk, la = spAnkle(lh, lk),
    }
end

-- FINISHER: enrola o corpo (antecipação) e solta o soco final forte (hit em SP_FINISHER_HIT_T)
local SP_FINISHER_HIT_T = 0.40
local SP_FINISHER_FRAMES = {
    { t = 0.00, crouch = 0.45,
      waist = V3d(8, -30, 0),   neck = V3d(-6, 26, 0),
      rsh = V3d(-30, 0, 60),    rel = V3d(50, 0, 0),   rwr = V3d(-20, 0, 0),
      lsh = V3d(45, 0, -26),    lel = V3d(70, 0, 0),
      rh = V3d(-22, 0, 10),     rk = V3d(-36, 0, 0),
      lh = V3d(34, 0, -8),      lk = V3d(-54, 0, 0) },

    { t = 0.30, hold = true, crouch = 0.55,
      waist = V3d(14, -58, 0),  neck = V3d(-8, 48, 0),
      rsh = V3d(-70, 0, 82),    rel = V3d(40, 0, 0),   rwr = V3d(-25, 0, 0),
      lsh = V3d(35, 0, -32),    lel = V3d(55, 0, 0),
      rh = V3d(-26, 0, 12),     rk = V3d(-40, 0, 0),
      lh = V3d(38, 0, -8),      lk = V3d(-58, 0, 0) },

    { t = 0.40, crouch = 0.62,
      waist = V3d(-34, 60, 4),  neck = V3d(12, -50, 0),
      rsh = V3d(100, 0, -44),   rel = V3d(4, 0, 0),    rwr = V3d(-40, 0, 0),
      lsh = V3d(-36, 0, -52),   lel = V3d(30, 0, 0),   lwr = V3d(10, 0, 0),
      rh = V3d(-36, 0, 10),     rk = V3d(-12, 0, 0),
      lh = V3d(46, 0, -8),      lk = V3d(-56, 0, 0) },

    { t = 0.58, crouch = 0.55,
      waist = V3d(-40, 72, 6),  neck = V3d(14, -58, 0),
      rsh = V3d(86, 0, -76),    rel = V3d(5, 0, 0),    rwr = V3d(-48, 0, 0),
      lsh = V3d(-40, 0, -56),   lel = V3d(30, 0, 0),   lwr = V3d(10, 0, 0),
      rh = V3d(-32, 0, 10),     rk = V3d(-15, 0, 0),
      lh = V3d(44, 0, -8),      lk = V3d(-52, 0, 0) },

    { t = 1.00, hold = true, crouch = 0.42,
      waist = V3d(-28, 58, 0),  neck = V3d(10, -44, 0),
      rsh = V3d(78, 0, -70),    rel = V3d(5, 0, 0),    rwr = V3d(-44, 0, 0),
      lsh = V3d(-34, 0, -52),   lel = V3d(30, 0, 0),   lwr = V3d(10, 0, 0),
      rh = V3d(-30, 0, 10),     rk = V3d(-15, 0, 0),
      lh = V3d(40, 0, -8),      lk = V3d(-50, 0, 0) },
}
for _, f in ipairs(SP_FINISHER_FRAMES) do
    if f.rh and f.rk then f.ra = spAnkle(f.rh, f.rk) end
    if f.lh and f.lk then f.la = spAnkle(f.lh, f.lk) end
end

-- Avaliador do barrage: loop de socos; quando state.finishT0 existe, mistura para o finisher
local function spMakeBarrageEval(state)
    return function(t)
        local base = spBarragePose(t)
        local f0 = state.finishT0
        if not f0 then return base end
        local ft = math.max(t - f0, 0)
        local fp = spEvalFrames(SP_FINISHER_FRAMES, ft)
        return spLerpPose(base, fp, spSmooth(math.clamp(ft / 0.12, 0, 1)))
    end
end

-- ============================================================
-- 🔪 ANIMAÇÕES PROCEDURAIS DAS FACAS (sem ID de animação)
--   Player : arremesso único por cima do ombro (braço direito)
--   Stand  : duas facas alternadas, direita -> esquerda (variant do Stand)
-- release[] = momento (s) em que cada faca sai da mão | total = duração da pose
-- ============================================================
-- Convenção: waist X+ = tronco ARQUEIA pra trás | X- = inclina pra frente
-- DIO (boneco): costas arqueadas + braço aberto com a faca + mão esquerda no peito,
-- depois AFUNDO com varredura do braço, congela no impacto e termina na pose de pose.
local KNIFE_PLAYER_FRAMES = {
    -- guarda
    { t = 0.00, crouch = 0.04,
      waist = V3d(-2, -6, 0),   neck = V3d(0, 4, 0),
      rsh = V3d(15, 0, 12),     rel = V3d(30, 0, 0),
      lsh = V3d(15, 0, -12),    lel = V3d(20, 0, 0),
      rh = V3d(-6, 0, 3),       rk = V3d(-10, 0, 0),
      lh = V3d(10, 0, -3),      lk = V3d(-14, 0, 0) },
    -- ANTECIPAÇÃO: arqueia as costas, braço direito escancarado, cabeça inclinada
    { t = 0.22, hold = true, crouch = 0.10,
      waist = V3d(14, -26, -4), neck = V3d(-6, 22, -12),
      rsh = V3d(5, -10, 102),   rel = V3d(18, 0, 0),   rwr = V3d(-12, 0, 0),
      lsh = V3d(65, 10, -28),   lel = V3d(115, 0, 0),  lwr = V3d(10, 0, 0),
      rh = V3d(-14, 0, 14),     rk = V3d(-18, 0, 0),
      lh = V3d(22, 0, -12),     lk = V3d(-28, 0, 0) },
    -- SOLTURA: afundo, varredura do braço, esquerdo abre pra trás
    { t = 0.30, crouch = 0.30,
      waist = V3d(-32, 48, 6),  neck = V3d(10, -40, 0),
      rsh = V3d(105, 0, 28),    rel = V3d(0, 0, 0),    rwr = V3d(-50, 0, 0),
      lsh = V3d(-45, 0, -75),   lel = V3d(22, 0, 0),
      rh = V3d(-36, 0, 10),     rk = V3d(-6, 0, 0),
      lh = V3d(56, 0, -10),     lk = V3d(-72, 0, 0) },
    -- IMPACTO: quase congela (frame de anime)
    { t = 0.44, crouch = 0.32,
      waist = V3d(-36, 54, 6),  neck = V3d(12, -44, 0),
      rsh = V3d(98, 0, 24),     rel = V3d(2, 0, 0),    rwr = V3d(-46, 0, 0),
      lsh = V3d(-48, 0, -78),   lel = V3d(24, 0, 0),
      rh = V3d(-38, 0, 10),     rk = V3d(-6, 0, 0),
      lh = V3d(58, 0, -10),     lk = V3d(-74, 0, 0) },
    -- fecha na pose: tronco arqueado, braço apontando, mão esquerda cruzando o peito
    { t = 0.88, hold = true, crouch = 0.08,
      waist = V3d(6, 26, 0),    neck = V3d(-4, -14, 6),
      rsh = V3d(78, 0, -10),    rel = V3d(14, 0, 0),   rwr = V3d(-20, 0, 0),
      lsh = V3d(30, 0, -36),    lel = V3d(105, 0, 0),
      rh = V3d(-14, 0, 6),      rk = V3d(-16, 0, 0),
      lh = V3d(26, 0, -6),      lk = V3d(-30, 0, 0) },
}

-- STAND (The World): abre os dois braços em "V" com as facas, arqueado,
-- depois cruza e dispara direita -> esquerda em sequência, freeze e relaxa.
local KNIFE_STAND_FRAMES = {
    -- guarda
    { t = 0.00, crouch = 0.10,
      waist = V3d(-10, 0, 0),   neck = V3d(8, 0, 0),
      rsh = V3d(20, 0, 16),     rel = V3d(60, 0, 0),
      lsh = V3d(20, 0, -16),    lel = V3d(60, 0, 0),
      rh = V3d(-14, 0, 8),      rk = V3d(-22, 0, 0),
      lh = V3d(26, 0, -8),      lk = V3d(-36, 0, 0) },
    -- ANTECIPAÇÃO: braços escancarados, peito aberto, cabeça erguida
    { t = 0.22, hold = true, crouch = 0.06,
      waist = V3d(16, 0, 0),    neck = V3d(14, 0, 0),
      rsh = V3d(8, 0, 98),      rel = V3d(14, 0, 0),   rwr = V3d(-10, 0, 0),
      lsh = V3d(8, 0, -98),     lel = V3d(14, 0, 0),   lwr = V3d(-10, 0, 0),
      rh = V3d(-8, 0, 16),      rk = V3d(-12, 0, 0),
      lh = V3d(8, 0, -16),      lk = V3d(-12, 0, 0) },
    -- 1ª faca: direita varre pra frente
    { t = 0.30, crouch = 0.22,
      waist = V3d(-26, 38, 0),  neck = V3d(8, -30, 0),
      rsh = V3d(104, 0, -22),   rel = V3d(4, 0, 0),    rwr = V3d(-40, 0, 0),
      lsh = V3d(25, 0, -70),    lel = V3d(20, 0, 0),
      rh = V3d(-30, 0, 10),     rk = V3d(-10, 0, 0),
      lh = V3d(44, 0, -10),     lk = V3d(-56, 0, 0) },
    -- 2ª faca: tronco chicoteia pro outro lado, esquerda varre
    { t = 0.38, crouch = 0.22,
      waist = V3d(-26, -38, 0), neck = V3d(8, 30, 0),
      rsh = V3d(20, 0, 66),     rel = V3d(40, 0, 0),
      lsh = V3d(104, 0, 22),    lel = V3d(4, 0, 0),    lwr = V3d(-40, 0, 0),
      rh = V3d(-30, 0, 10),     rk = V3d(-10, 0, 0),
      lh = V3d(44, 0, -10),     lk = V3d(-56, 0, 0) },
    -- IMPACTO: congela
    { t = 0.52, crouch = 0.24,
      waist = V3d(-30, -42, 0), neck = V3d(10, 34, 0),
      rsh = V3d(16, 0, 70),     rel = V3d(44, 0, 0),
      lsh = V3d(98, 0, 20),     lel = V3d(6, 0, 0),    lwr = V3d(-36, 0, 0),
      rh = V3d(-32, 0, 10),     rk = V3d(-10, 0, 0),
      lh = V3d(46, 0, -10),     lk = V3d(-58, 0, 0) },
    -- relaxa com os braços levemente abertos
    { t = 0.95, hold = true, crouch = 0.08,
      waist = V3d(4, 0, 0),     neck = V3d(-4, 0, 0),
      rsh = V3d(25, 0, 30),     rel = V3d(30, 0, 0),
      lsh = V3d(25, 0, -30),    lel = V3d(30, 0, 0),
      rh = V3d(-10, 0, 6),      rk = V3d(-16, 0, 0),
      lh = V3d(16, 0, -6),      lk = V3d(-24, 0, 0) },
}
for _, set in ipairs({ KNIFE_PLAYER_FRAMES, KNIFE_STAND_FRAMES }) do
    for _, f in ipairs(set) do
        if f.rh and f.rk then f.ra = spAnkle(f.rh, f.rk) end
        if f.lh and f.lk then f.la = spAnkle(f.lh, f.lk) end
    end
end

-- Espelha uma pose (troca direita <-> esquerda e inverte giro/abertura)
local function mirrorKnifeFrames(frames)
    local swap = {
        rsh = "lsh", rel = "lel", rwr = "lwr", lsh = "rsh", lel = "rel", lwr = "rwr",
        rh = "lh", rk = "lk", ra = "la", lh = "rh", lk = "rk", la = "ra",
    }
    local out = {}
    for i, f in ipairs(frames) do
        local n = { t = f.t, hold = f.hold, crouch = f.crouch }
        for _, k in ipairs({ "waist", "neck" }) do
            if f[k] then n[k] = V3d(f[k].X, -f[k].Y, -f[k].Z) end
        end
        for from, to in pairs(swap) do
            if f[from] then n[to] = V3d(f[from].X, -f[from].Y, -f[from].Z) end
        end
        out[i] = n
    end
    return out
end

local KNIFE_STAND_FRAMES_L = mirrorKnifeFrames(KNIFE_STAND_FRAMES)

local KNIFE_ANIM = {
    Player = { frames = KNIFE_PLAYER_FRAMES,  release = { 0.28 },       total = 0.88 },
    -- Variant A: direita -> esquerda
    Stand  = { frames = KNIFE_STAND_FRAMES,   release = { 0.29, 0.37 }, total = 0.95, leftFirst = false },
    -- Variant B: esquerda -> direita (espelhada)
    StandL = { frames = KNIFE_STAND_FRAMES_L, release = { 0.29, 0.37 }, total = 0.95, leftFirst = true },
}

-- Qual variant do Stand usar: "alternate" (A, B, A, B...) | "right" (sempre A) | "left" (sempre B)
local STAND_KNIFE_MODE = "alternate"
local standKnifeNextLeft = false

-- mão de onde a faca sai (ímpar = direita, par = esquerda); R15 e R6
local function getKnifeHand(model, index, leftFirst)
    local isRight = (index % 2 == 1)
    if leftFirst then isRight = not isRight end
    local names = isRight and { "RightHand", "Right Arm" } or { "LeftHand", "Left Arm" }
    for _, n in ipairs(names) do
        local part = model:FindFirstChild(n)
        if part and part:IsA("BasePart") then return part end
    end
    return nil
end

-- ==================== NOVA FUNÇÃO GET STAND MODEL (IGNORA APENAS ACESSÓRIOS DO SCRIPT) ====================
local ACCESSORY_TAG = "DioAccessory"  -- Mesma tag do script de acessórios

local function getStandModel()
    local targetUserId = customStandUserId or player.UserId

    local success, model = pcall(function()
        local description = Players:GetHumanoidDescriptionFromUserId(targetUserId)
        local standModel = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
        return standModel
    end)

    if not success or not model then
        warn("❌ Falha ao criar Stand R15 para UserId: " .. targetUserId .. " | Usando fallback...")
        customStandUserId = nil
        return getStandModel()
    end

    model.Name = "Stand"
    model.Archivable = true

    -- 🚫 REMOVE APENAS OS ACESSÓRIOS COM A TAG "DioAccessory"
    -- (Remove do MODELO antes de remover scripts)
    for _, child in ipairs(model:GetChildren()) do
        if child:GetAttribute(ACCESSORY_TAG) then
            child:Destroy()
        end
    end
    
    -- 🚫 Remove também acessórios que estão DENTRO de partes do corpo
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:GetAttribute(ACCESSORY_TAG) then
            obj:Destroy()
        end
    end

    -- Agora remove scripts, colisão e sombras do RESTO do modelo
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.CanCollide = false
            obj.CastShadow = false
            if obj.Name ~= "HumanoidRootPart" then
                obj.Transparency = 1
            else
                obj.Transparency = 1
            end
        elseif obj:IsA("Decal") then
            obj.Transparency = 1
        elseif obj:IsA("LocalScript") or obj:IsA("Script") or obj:IsA("ModuleScript") then
            obj:Destroy()
        end
    end

    -- Configurações do Humanoid
    local sHum = model:FindFirstChildOfClass("Humanoid")
    if sHum then
        sHum.RigType = Enum.HumanoidRigType.R15
        sHum.PlatformStand = true
        sHum.AutoRotate = false
        sHum.HipHeight = 0
    end

    spFixRig(model)  -- correção de rig (juntas, Animator, massa/colisão)

    return model
end

-- ============================================================
-- 🔴 SUBSTITUA TODA A FUNÇÃO createStandChangerGui POR ISSO:
-- ============================================================
local function createStandChangerGui()
    if standChangerGui and standChangerGui.Parent then
        standChangerGui:Destroy()
        standChangerGui = nil
        return
    end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "StandChangerGUI"
    gui.ResetOnSpawn = false
    gui.Parent = player.PlayerGui
    
    -- Container principal
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.fromOffset(400, 320)  -- Aumentado para caber o botão SALVAR
    mainFrame.Position = UDim2.fromScale(0.5, 0.45)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = gui
    
    -- Borda dourada
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 215, 0)
    stroke.Thickness = 4
    stroke.Parent = mainFrame
    
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 16)
    
    -- Título
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 50)
    title.BackgroundTransparency = 1
    title.Text = "🌟 STAND CHANGER 🌟"
    title.TextColor3 = Color3.fromRGB(255, 215, 0)
    title.Font = Enum.Font.Bangers
    title.TextSize = 28
    title.TextStrokeTransparency = 0
    title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    title.Parent = mainFrame
    
    -- 🔴 NOVO: Status do ID salvo
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.85, 0, 0, 25)
    statusLabel.Position = UDim2.new(0.075, 0, 0.2, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = customStandUserId and "⚡ Stand Customizado Ativo" or "👤 Stand Padrão"
    statusLabel.TextColor3 = customStandUserId and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(150, 150, 150)
    statusLabel.Font = Enum.Font.SourceSansBold
    statusLabel.TextSize = 16
    statusLabel.Parent = mainFrame
    
    -- Caixa de ID
    local idBox = Instance.new("TextBox")
    idBox.Size = UDim2.new(0.85, 0, 0, 45)
    idBox.Position = UDim2.new(0.075, 0, 0.33, 0)
    idBox.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    idBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    idBox.PlaceholderText = "Cole o User ID aqui..."
    idBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 160)
    idBox.Text = customStandUserId and tostring(customStandUserId) or ""
    idBox.Font = Enum.Font.SourceSans
    idBox.TextSize = 18
    idBox.Parent = mainFrame
    Instance.new("UICorner", idBox).CornerRadius = UDim.new(0, 10)
    
    local idStroke = Instance.new("UIStroke")
    idStroke.Color = Color3.fromRGB(255, 215, 0)
    idStroke.Thickness = 2
    idStroke.Parent = idBox
    
    -- Botão ADD
    local addBtn = Instance.new("TextButton")
    addBtn.Size = UDim2.new(0.4, 0, 0, 50)
    addBtn.Position = UDim2.new(0.075, 0, 0.6, 0)
    addBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
    addBtn.Text = "ADD STAND"
    addBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
    addBtn.Font = Enum.Font.Bangers
    addBtn.TextSize = 22
    addBtn.Parent = mainFrame
    Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 10)
    
    -- Botão RESET
    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(0.4, 0, 0, 50)
    resetBtn.Position = UDim2.new(0.525, 0, 0.6, 0)
    resetBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    resetBtn.Text = "RESET"
    resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    resetBtn.Font = Enum.Font.Bangers
    resetBtn.TextSize = 22
    resetBtn.Parent = mainFrame
    Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 10)
    
    -- 🔴 NOVO: Botão SALVAR
    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(0.85, 0, 0, 35)
    saveBtn.Position = UDim2.new(0.075, 0, 0.78, 0)
    saveBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
    saveBtn.Text = "💾 SALVAR ID ATUAL"
    saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    saveBtn.Font = Enum.Font.Bangers
    saveBtn.TextSize = 18
    saveBtn.Parent = mainFrame
    Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 10)
    
    -- Hover effects
    addBtn.MouseEnter:Connect(function()
        TweenService:Create(addBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 230, 80)}):Play()
    end)
    addBtn.MouseLeave:Connect(function()
        TweenService:Create(addBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 180, 0)}):Play()
    end)
    
    resetBtn.MouseEnter:Connect(function()
        TweenService:Create(resetBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 60, 60)}):Play()
    end)
    resetBtn.MouseLeave:Connect(function()
        TweenService:Create(resetBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(200, 40, 40)}):Play()
    end)
    
    saveBtn.MouseEnter:Connect(function()
        TweenService:Create(saveBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(70, 220, 110)}):Play()
    end)
    saveBtn.MouseLeave:Connect(function()
        TweenService:Create(saveBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 180, 80)}):Play()
    end)
    
    addBtn.MouseButton1Click:Connect(function()
    local input = idBox.Text:match("%d+")
    local inputId = tonumber(input)
    
    if inputId and inputId > 0 then
        customStandUserId = inputId
        print("✅ Stand alterado para UserId: " .. inputId)
        
        statusLabel.Text = "⚡ Stand Customizado Ativo"
        statusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
        
        -- Salva o ID
        salvarStandId(inputId)
        
        if isStandActive then
            toggleStand()
            task.wait(0.25)
            toggleStand()
        end
        
        gui:Destroy()
        standChangerGui = nil
    else
        idBox.Text = ""
        idBox.PlaceholderText = "ID inválido! Use apenas números."
    end
end)
    
    -- Dentro da função createStandChangerGui(), substitua o botão RESET por isso:
resetBtn.MouseButton1Click:Connect(function()
    customStandUserId = nil
    print("✅ Stand resetado para o padrão!")
    
    statusLabel.Text = "👤 Stand Padrão"
    statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    
    -- Deleta o arquivo físico
    deletarArquivoConfig()
    
    if isStandActive then
        toggleStand()
        task.wait(0.3)
        toggleStand()
    end
    
    gui:Destroy()
    standChangerGui = nil
end)
    
    -- 🔴 NOVO: Função do botão SALVAR
    saveBtn.MouseButton1Click:Connect(function()
        if customStandUserId then
            salvarStandId(customStandUserId)
            saveBtn.Text = "✅ SALVO!"
            saveBtn.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
            task.delay(1.5, function()
                if saveBtn and saveBtn.Parent then
                    saveBtn.Text = "💾 SALVAR ID ATUAL"
                    saveBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
                end
            end)
        else
            salvarStandId(player.UserId)
            saveBtn.Text = "✅ PADRÃO SALVO!"
            saveBtn.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
            task.delay(1.5, function()
                if saveBtn and saveBtn.Parent then
                    saveBtn.Text = "💾 SALVAR ID ATUAL"
                    saveBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
                end
            end)
        end
    end)
    
    -- ==================== FECHAR AO CLICAR FORA (CORRIGIDO) ====================
local userInputService = game:GetService("UserInputService")

local function onInputBegan(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    
    if not gui or not gui.Parent then
        userInputService.InputBegan:Disconnect(onInputBegan)
        return
    end
    
    if not mainFrame or not mainFrame.Parent then return end
    
    local mousePos = userInputService:GetMouseLocation()
    local framePos = mainFrame.AbsolutePosition
    local frameSize = mainFrame.AbsoluteSize
    
    local isInsideX = mousePos.X >= framePos.X and mousePos.X <= framePos.X + frameSize.X
    local isInsideY = mousePos.Y >= framePos.Y and mousePos.Y <= framePos.Y + frameSize.Y
    
    if not (isInsideX and isInsideY) then
        userInputService.InputBegan:Disconnect(onInputBegan)
        gui:Destroy()
        standChangerGui = nil
    end
end

-- Aguarda um frame para não detectar o clique que abriu a GUI
task.delay(0.2, function()
    if gui and gui.Parent then
        userInputService.InputBegan:Connect(onInputBegan)
    end
end)
    
    standChangerGui = gui
end

local function toggleStand()
	if isStandActive then
		-- === DESATIVAR STAND ===
		isStandActive = false
		isAttacking = false
		activateBtn.Text = "STAND"

		if idleTrack then idleTrack:Stop(0.1) end
		if walkTrack then walkTrack:Stop(0.1) end

		if currentStand then
			local root = currentStand:FindFirstChild("HumanoidRootPart")
			if root then
				root.Anchored = false
				TweenService:Create(root, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {CFrame = character.HumanoidRootPart.CFrame}):Play()
			end
			for _, p in ipairs(currentStand:GetDescendants()) do
				if p:IsA("BasePart") then
					TweenService:Create(p, TweenInfo.new(0.4), {Transparency = 1}):Play()
				end
			end
			Debris:AddItem(currentStand, 0.6)
			currentStand = nil
		end

		-- Animação do botão Barragem saindo
		TweenService:Create(barragemBtn, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = ACTIVATE_POS,
			Size = UDim2.fromOffset(0, 0)
		}):Play()
		task.delay(0.3, function() barragemBtn.Visible = false end)

		updateKnifePosition(false)
		updateIconState(standIcon, false)

	else
		-- === ATIVAR STAND (otimizado) ===
		isStandActive = true
		activateBtn.Text = "OFF"

		-- Som e speech bubble primeiro (não bloqueia nada)
		showSpeechBubble(81663476180868, "right", 2.5)
		local standActivateSound = Instance.new("Sound", workspace)
		standActivateSound.SoundId = "rbxassetid://136125935634681"
		standActivateSound.Volume = 2
		standActivateSound:Play()
		Debris:AddItem(standActivateSound, 5)

		-- Animação dos botões (Barragem e Knife) em paralelo
		barragemBtn.Visible = true
		TweenService:Create(barragemBtn, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = BARRAGEM_POS,
			Size = UDim2.fromOffset(80, 80)
		}):Play()

		updateKnifePosition(true)
		updateIconState(standIcon, true)

		-- Cria o Stand com task.spawn para NÃO travar o clique
		task.spawn(function()
			currentStand = getStandModel()
			if not currentStand then return end

			currentStand.Parent = workspace

			local sHum = currentStand:FindFirstChildOfClass("Humanoid")
			local sRoot = currentStand:FindFirstChild("HumanoidRootPart")

			if sHum then
				sHum.PlatformStand = true
				sHum.AutoRotate = false
				sHum.HipHeight = 0
			end
			if sRoot then
				sRoot.Anchored = true
				sRoot.CFrame = character.HumanoidRootPart.CFrame * CFrame.new(STAND_OFFSET)
			end

			-- === REVELA O STAND MANTENDO AS CORES ORIGINAIS ===
			for _, p in ipairs(currentStand:GetDescendants()) do
				if p:IsA("BasePart") then
					-- NÃO força branco! Mantém a cor original do avatar
					if p.Name == "HumanoidRootPart" then
						p.Transparency = 1
						p.CastShadow = false
					else
						p.Transparency = 1  -- Começa invisível
						-- Tween suave para aparecer mantendo cor original
						TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							Transparency = 0
						}):Play()
					end
				elseif p:IsA("Decal") then
					p.Transparency = 1
					TweenService:Create(p, TweenInfo.new(0.45), {Transparency = 0}):Play()
				end
			end

			-- Idle animation
			if sHum then
				idleTrack = playAnim(sHum, ASSETS.STAND_IDLE, 1, true, Enum.AnimationPriority.Idle)
			end
		end)
	end
end

-- ==================== VFX SYSTEM ====================
local function createParticle(parent, props)
	local emitter = Instance.new("ParticleEmitter")
	for property, value in pairs(props) do
		emitter[property] = value
	end
	emitter.Parent = parent
	return emitter
end

local function EmitTimeStopVFX()
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then return end

	local vfxAttachment = Instance.new("Attachment")
	vfxAttachment.Parent = torso
	vfxAttachment.Position = Vector3.new(0, 0, 0)

	-- Emissor 1
	local emitter1 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://17391818367",
		Color = ColorSequence.new(Color3.fromRGB(255, 215, 0)),
		Lifetime = NumberRange.new(0.1, 0.3),
		Rate = 0,
		Rotation = NumberRange.new(0),
		RotSpeed = NumberRange.new(0),
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(8),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 6),
			NumberSequenceKeypoint.new(0.2, 6.5),
			NumberSequenceKeypoint.new(0.75, 2.5),
			NumberSequenceKeypoint.new(1, 0)
		}),
		LightEmission = 1,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		SpreadAngle = Vector2.new(360, 360),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		Brightness = 5,
		ZOffset = 0.05,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.95, 0),
			NumberSequenceKeypoint.new(1, 1)
		}),
		VelocityInheritance = 0,
		LockedToPart = false,
		Enabled = false
	})
	emitter1:Emit(10)

	-- Emissor 2
	local emitter2 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://16511964424",
		Color = ColorSequence.new(Color3.fromRGB(255, 215, 0)),
		Lifetime = NumberRange.new(0.1, 0.3),
		Rate = 0,
		Rotation = NumberRange.new(0),
		RotSpeed = NumberRange.new(0),
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(8),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 6),
			NumberSequenceKeypoint.new(0.2, 6.5),
			NumberSequenceKeypoint.new(0.75, 2.5),
			NumberSequenceKeypoint.new(1, 0)
		}),
		LightEmission = 1,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		SpreadAngle = Vector2.new(360, 360),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		Brightness = 5,
		ZOffset = 0.05,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.95, 0),
			NumberSequenceKeypoint.new(1, 1)
		}),
		VelocityInheritance = 0,
		LockedToPart = false,
		Enabled = false
	})
	emitter2:Emit(10)

	task.wait(0.25)

	-- Emissor 3 (explosÃ£o dourada)
	local emitter3 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://13161986324",
		Color = ColorSequence.new(Color3.fromRGB(255, 215, 0)),
		Lifetime = NumberRange.new(0.5, 1.5),
		Rate = 0,
		Speed = NumberRange.new(30, 50),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 5),
			NumberSequenceKeypoint.new(0.1, 6),
			NumberSequenceKeypoint.new(0.3, 3),
			NumberSequenceKeypoint.new(1, 0)
		}),
		LightEmission = 1,
		SpreadAngle = Vector2.new(360, 360),
		Shape = Enum.ParticleEmitterShape.Box,
		Brightness = 10,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.5, 0.5),
			NumberSequenceKeypoint.new(1, 1)
		}),
		VelocityInheritance = 0,
		Enabled = false
	})
	emitter3:Emit(60)

	-- Emissor 4 (raio de luz subindo)
	local emitter4 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://10335418884",
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 0)),
		Lifetime = NumberRange.new(0.8, 2),
		Rate = 0,
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(20, 35),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 4),
			NumberSequenceKeypoint.new(0.08, 5),
			NumberSequenceKeypoint.new(0.1, 3),
			NumberSequenceKeypoint.new(0.75, 2),
			NumberSequenceKeypoint.new(1, 0)
		}),
		LightEmission = 0.9,
		SpreadAngle = Vector2.new(360, 360),
		Shape = Enum.ParticleEmitterShape.Box,
		Brightness = 15,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(0.5, 0.5),
			NumberSequenceKeypoint.new(1, 1)
		}),
		VelocityInheritance = 0,
		Enabled = false
	})
	emitter4:Emit(80)

	-- Emissor 5 (brilho final)
	local emitter5 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://13161986324",
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 50)),
		Lifetime = NumberRange.new(0.3, 1),
		Rate = 0,
		Speed = NumberRange.new(25, 45),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.1, 5),
			NumberSequenceKeypoint.new(0.35, 4),
			NumberSequenceKeypoint.new(0.75, 3),
			NumberSequenceKeypoint.new(1, 0)
		}),
		LightEmission = 0.9,
		SpreadAngle = Vector2.new(360, 360),
		Shape = Enum.ParticleEmitterShape.Box,
		Brightness = 15,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 0)
		}),
		VelocityInheritance = 0,
		Enabled = false
	})
	emitter5:Emit(40)

	task.delay(2, function()
		if vfxAttachment then vfxAttachment:Destroy() end
	end)
end

-- ==================== VFX COMPLETO DE SANGUE NO ALVO (18 EMISSORES - COMPLETO) ====================
local function EmitBloodVFX(character)
	if not character then return end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then return end

	local vfxAttachment = Instance.new("Attachment")
	vfxAttachment.Parent = torso
	vfxAttachment.Position = Vector3.new(0, 0, 0)

	local emitter1 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://72464786650138", Color = ColorSequence.new(Color3.fromRGB(116, 0, 0)),
		Lifetime = NumberRange.new(0.5, 1), Rate = 0, Rotation = NumberRange.new(90), RotSpeed = NumberRange.new(0),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(12),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.819672), NumberSequenceKeypoint.new(1, 0)}),
		LightEmission = 0, Orientation = Enum.ParticleOrientation.VelocityParallel,
		SpreadAngle = Vector2.new(90, 90), Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 1, ZOffset = 0,
		Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		VelocityInheritance = 0, LockedToPart = false, Enabled = false
	})
	emitter1:Emit(3)

	local emitter2 = createParticle(vfxAttachment, {
		Texture = "http://www.roblox.com/asset/?id=13975880803", Color = ColorSequence.new(Color3.fromRGB(116, 0, 0)),
		Lifetime = NumberRange.new(0.5, 1), Rate = 0, Rotation = NumberRange.new(90), RotSpeed = NumberRange.new(0),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(12),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.819672), NumberSequenceKeypoint.new(1, 0)}),
		LightEmission = 0, Orientation = Enum.ParticleOrientation.VelocityParallel,
		SpreadAngle = Vector2.new(90, 90), Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 1, ZOffset = 0,
		Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		VelocityInheritance = 0, LockedToPart = false, Enabled = false
	})
	emitter2:Emit(3)

	local emitter3 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://11362424823", Color = ColorSequence.new(Color3.fromRGB(116, 0, 0)),
		Lifetime = NumberRange.new(0.5, 1), Rate = 0, Rotation = NumberRange.new(90), RotSpeed = NumberRange.new(0),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(12),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.819672), NumberSequenceKeypoint.new(1, 0)}),
		LightEmission = -1, Orientation = Enum.ParticleOrientation.VelocityParallel,
		SpreadAngle = Vector2.new(90, 90), Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 1, ZOffset = 0,
		Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		VelocityInheritance = 0, LockedToPart = false, Enabled = false
	})
	emitter3:Emit(3)

	local emitter4 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://75151371642650", Color = ColorSequence.new(Color3.fromRGB(116, 0, 0)),
		Lifetime = NumberRange.new(1, 2), Rate = 0, Rotation = NumberRange.new(0), RotSpeed = NumberRange.new(0),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(3, 5),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2.45902), NumberSequenceKeypoint.new(1, 2.73224)}),
		LightEmission = 0, Orientation = Enum.ParticleOrientation.VelocityParallel,
		SpreadAngle = Vector2.new(90, 90), Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 2, ZOffset = 0,
		Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.192383, 0.448087), NumberSequenceKeypoint.new(1, 1)}),
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		VelocityInheritance = 0, LockedToPart = false, Enabled = false
	})
	emitter4:Emit(3)

	local emitter5 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://16924746286", Color = ColorSequence.new(Color3.fromRGB(116, 0, 0)),
		Lifetime = NumberRange.new(1, 2), Rate = 0, Rotation = NumberRange.new(-360, 360), RotSpeed = NumberRange.new(0),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(1, 3),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2.45902), NumberSequenceKeypoint.new(1, 2.73224)}),
		LightEmission = 0, Orientation = Enum.ParticleOrientation.FacingCamera,
		SpreadAngle = Vector2.new(90, 90), Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 2, ZOffset = 0,
		Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.192383, 0.448087), NumberSequenceKeypoint.new(1, 1)}),
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		VelocityInheritance = 0, LockedToPart = false, Enabled = false
	})
	emitter5:Emit(3)

	local emitter6 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://132510741799481", Color = ColorSequence.new(Color3.fromRGB(116, 0, 0)),
		Lifetime = NumberRange.new(1, 2), Rate = 0, Rotation = NumberRange.new(-360, 360), RotSpeed = NumberRange.new(0),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(3, 6),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2.45902), NumberSequenceKeypoint.new(1, 2.73224)}),
		LightEmission = -1, Orientation = Enum.ParticleOrientation.FacingCamera,
		SpreadAngle = Vector2.new(90, 90), Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 2, ZOffset = 0,
		Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.192383, 0.448087), NumberSequenceKeypoint.new(1, 1)}),
		FlipbookLayout = Enum.ParticleFlipbookLayout.None, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		VelocityInheritance = 0, LockedToPart = false, Enabled = false
	})
	emitter6:Emit(3)

	local emitter7 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://18707464177", Color = ColorSequence.new(Color3.fromRGB(85, 0, 0)),
		Lifetime = NumberRange.new(0.5), Rate = 0, Rotation = NumberRange.new(-360, 360), RotSpeed = NumberRange.new(0),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2.89617), NumberSequenceKeypoint.new(1, 4.37158)}),
		LightEmission = 0, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		SpreadAngle = Vector2.new(1000, -1000), Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 2, ZOffset = 0,
		Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		VelocityInheritance = 0, LockedToPart = false, Enabled = false
	})
	emitter7:Emit(3)

	local emitter8 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://15694384576", Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		Lifetime = NumberRange.new(0.25), Rate = 0, Rotation = NumberRange.new(-360, 360), RotSpeed = NumberRange.new(0),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2.51366), NumberSequenceKeypoint.new(1, 6.72131)}),
		LightEmission = -2, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		SpreadAngle = Vector2.new(1000, -1000), Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 0, ZOffset = -2,
		Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
		FlipbookLayout = Enum.ParticleFlipbookLayout.None, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		VelocityInheritance = 0, LockedToPart = false, Enabled = false
	})
	emitter8:Emit(3)

	local emitter9 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://16892272385", Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		Lifetime = NumberRange.new(0.25), Rate = 0, Rotation = NumberRange.new(-360, 360), RotSpeed = NumberRange.new(0),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2.51366), NumberSequenceKeypoint.new(1, 6.72131)}),
		LightEmission = -2, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		SpreadAngle = Vector2.new(1000, -1000), Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 0, ZOffset = -2,
		Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
		FlipbookLayout = Enum.ParticleFlipbookLayout.None, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		VelocityInheritance = 0, LockedToPart = false, Enabled = false
	})
	emitter9:Emit(3)

	local emitter10 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://15694384576", Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		Lifetime = NumberRange.new(0.25), Rate = 0, Rotation = NumberRange.new(-360, 360), RotSpeed = NumberRange.new(0),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2.51366), NumberSequenceKeypoint.new(1, 6.72131)}),
		LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		SpreadAngle = Vector2.new(1000, -1000), Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 1, ZOffset = -2,
		Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
		FlipbookLayout = Enum.ParticleFlipbookLayout.None, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		VelocityInheritance = 0, LockedToPart = false, Enabled = false
	})
	emitter10:Emit(3)

	local emitter11 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://16892272385", Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		Lifetime = NumberRange.new(0.25), Rate = 0, Rotation = NumberRange.new(-360, 360), RotSpeed = NumberRange.new(0),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2.51366), NumberSequenceKeypoint.new(1, 6.72131)}),
		LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		SpreadAngle = Vector2.new(1000, -1000), Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 1, ZOffset = -2,
		Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
		FlipbookLayout = Enum.ParticleFlipbookLayout.None, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		VelocityInheritance = 0, LockedToPart = false, Enabled = false
	})
	emitter11:Emit(3)

	local emitter12 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://14850595833", Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		Lifetime = NumberRange.new(0.25, 2), Rate = 0, Rotation = NumberRange.new(-360, 360), RotSpeed = NumberRange.new(25),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4.42623), NumberSequenceKeypoint.new(1, 5.68306)}),
		LightEmission = 0, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		SpreadAngle = Vector2.new(1000, -1000), Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 1, ZOffset = 0,
		Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.304005, 0.661202), NumberSequenceKeypoint.new(1, 1)}),
		FlipbookLayout = Enum.ParticleFlipbookLayout.None, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		VelocityInheritance = 0, LockedToPart = false, Enabled = false
	})
	emitter12:Emit(3)

	local emitter13 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://16034294138", Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		Lifetime = NumberRange.new(1, 2), Rate = 0, Rotation = NumberRange.new(-360, 360), RotSpeed = NumberRange.new(25),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4.42623), NumberSequenceKeypoint.new(1, 5.68306)}),
		LightEmission = 0, Orientation = Enum.ParticleOrientation.VelocityParallel,
		SpreadAngle = Vector2.new(1000, -1000), Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 1, ZOffset = 0,
		Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.301379, 0.863388), NumberSequenceKeypoint.new(1, 1)}),
		FlipbookLayout = Enum.ParticleFlipbookLayout.None, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		VelocityInheritance = 0, LockedToPart = false, Enabled = false
	})
	emitter13:Emit(3)

	local emitter14 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://14850595833", Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		Lifetime = NumberRange.new(0.25, 2), Rate = 0, Rotation = NumberRange.new(-360, 360), RotSpeed = NumberRange.new(25),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4.42623), NumberSequenceKeypoint.new(1, 5.68306)}),
		LightEmission = 0, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		SpreadAngle = Vector2.new(1000, -1000), Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 0, ZOffset = 0,
		Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.304005, 0.661202), NumberSequenceKeypoint.new(1, 1)}),
		FlipbookLayout = Enum.ParticleFlipbookLayout.None, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		VelocityInheritance = 0, LockedToPart = false, Enabled = false
	})
	emitter14:Emit(3)

	local emitter15 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://108577877866926", Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		Lifetime = NumberRange.new(2.25, 3), Rate = 0, Rotation = NumberRange.new(-360, 360), RotSpeed = NumberRange.new(25),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4.42623), NumberSequenceKeypoint.new(1, 5.68306)}),
		LightEmission = 0, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		SpreadAngle = Vector2.new(1000, -1000), Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 0, ZOffset = 0,
		Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.302035, 0.814208), NumberSequenceKeypoint.new(1, 1)}),
		FlipbookLayout = Enum.ParticleFlipbookLayout.None, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		VelocityInheritance = 0, LockedToPart = false, Enabled = false
	})
	emitter15:Emit(3)

	local emitter16 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://108577877866926", Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		Lifetime = NumberRange.new(2.25, 3), Rate = 0, Rotation = NumberRange.new(-360, 360), RotSpeed = NumberRange.new(25),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4.42623), NumberSequenceKeypoint.new(1, 5.68306)}),
		LightEmission = 0, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		SpreadAngle = Vector2.new(1000, -1000), Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 1, ZOffset = 0,
		Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.302035, 0.814208), NumberSequenceKeypoint.new(1, 1)}),
		FlipbookLayout = Enum.ParticleFlipbookLayout.None, FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		VelocityInheritance = 0, LockedToPart = false, Enabled = false
	})
	emitter16:Emit(3)

	local emitter17 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://14550142746", Color = ColorSequence.new(Color3.fromRGB(116, 0, 0)),
		Lifetime = NumberRange.new(0.5, 1), Rate = 0, Rotation = NumberRange.new(-360, 360), RotSpeed = NumberRange.new(0),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(3, 6),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2.45902), NumberSequenceKeypoint.new(1, 2.73224)}),
		LightEmission = -2, Orientation = Enum.ParticleOrientation.FacingCamera,
		SpreadAngle = Vector2.new(90, 90), Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 3, ZOffset = 0,
		Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.192383, 0.448087), NumberSequenceKeypoint.new(1, 1)}),
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		VelocityInheritance = 0, LockedToPart = false, Enabled = false
	})
	emitter17:Emit(3)

	local emitter18 = createParticle(vfxAttachment, {
		Texture = "rbxassetid://135489336329641", Color = ColorSequence.new(Color3.fromRGB(116, 0, 0)),
		Lifetime = NumberRange.new(1, 2), Rate = 0, Rotation = NumberRange.new(-360, 360), RotSpeed = NumberRange.new(0),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(1, 3),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2.45902), NumberSequenceKeypoint.new(1, 2.73224)}),
		LightEmission = 0, Orientation = Enum.ParticleOrientation.FacingCamera,
		SpreadAngle = Vector2.new(90, 90), Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Brightness = 2, ZOffset = 0,
		Squash = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.192383, 0.448087), NumberSequenceKeypoint.new(1, 1)}),
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		VelocityInheritance = 0, LockedToPart = false, Enabled = false
	})
	emitter18:Emit(3)

	task.delay(2, function()
		if vfxAttachment then vfxAttachment:Destroy() end
	end)
end

-- ==================== MESH DA FACA (ORIGINAL) ====================
local KNIFE_MESH_ID = "rbxassetid://15945983658"
local KNIFE_TEXTURE_ID = "rbxassetid://15946012483"
local KNIFE_MESH_SCALE = Vector3.new(1.25, 1.25, 1.85)

-- Rotação original da faca: em voo/cravada (target = frente) e na mão (target = dedos)
local function knifeAlign(target)
    if target.Y < -0.5 then
        return CFrame.Angles(math.rad(90), 0, 0)             -- na mão
    end
    return CFrame.Angles(math.rad(12), math.rad(-175), 0)    -- em voo / cravada
end

local function applyKnifeMesh(part)
    local m = Instance.new("SpecialMesh")
    m.MeshType = Enum.MeshType.FileMesh
    m.MeshId = KNIFE_MESH_ID
    m.TextureId = KNIFE_TEXTURE_ID
    m.Scale = KNIFE_MESH_SCALE
    m.Parent = part
    return m
end

-- ==================== PROCESSAMENTO DE MOVIMENTO DA FACA (ANTI-DUPLICADO FORTE) ====================
local function processKnifeMovement(knife, shootDir)
    if not knife or not knife.Parent then return end
    
    local lastPosition = knife.Position
    local movementConnection
    movementConnection = RunService.RenderStepped:Connect(function()
        if not knife or not knife.Parent then
            if movementConnection then movementConnection:Disconnect() end
            return
        end
        
        if knife.Anchored then
            lastPosition = knife.Position
            return
        end
        
        local currentPosition = knife.Position
        local direction = (currentPosition - lastPosition)
        local distance = direction.Magnitude
        
        if distance > 0.05 then
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {character, currentStand or {}}
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            
            local steps = math.ceil(distance / 0.5)
            local stepDirection = direction.Unit * (distance / steps)
            
            for step = 1, steps do
                local rayOrigin = lastPosition + (stepDirection * (step - 1))
                local rayResult = workspace:Raycast(rayOrigin, stepDirection, raycastParams)
                
                if rayResult then
                    local hitPart = rayResult.Instance
                    local hitHum = hitPart.Parent:FindFirstChildOfClass("Humanoid")
                    
                    if hitHum and hitHum.Parent ~= character and hitHum.Parent ~= currentStand then
                        hitHum:TakeDamage(18)
                        
                        -- Som normal de acerto
                        local hitSound = Instance.new("Sound", workspace)
                        hitSound.SoundId = ASSETS.KNIFE_HIT_SOUND
                        hitSound.Volume = 1.0
                        hitSound:Play()
                        Debris:AddItem(hitSound, 2)

                        -- Faca cravada
                        local stuckKnife = Instance.new("Part", workspace)
                        stuckKnife.Name = "StuckKnife"
                        stuckKnife.Size = Vector3.new(1, 1, 1)
                        stuckKnife.CanCollide = false
                        stuckKnife.Anchored = true
                        stuckKnife.CFrame = CFrame.lookAt(rayResult.Position, rayResult.Position + direction.Unit) * knifeAlign(Vector3.new(0, 0, -1))
                        stuckKnife.Transparency = 0
                        stuckKnife.Color = Color3.fromRGB(255, 255, 255)
                        
                        applyKnifeMesh(stuckKnife)
                        
                        local stickWeld = Instance.new("WeldConstraint", stuckKnife)
                        stickWeld.Part0 = stuckKnife
                        stickWeld.Part1 = hitPart
                        
                        Debris:AddItem(stuckKnife, 3.5)
                        
                        -- ====================== KILL CONFIRM ANTI-DUPLICADO ======================
                        local now = tick()
                        if hitHum.Health <= 0 and (now - lastKillConfirmTime) > KILL_CONFIRM_COOLDOWN then
                            lastKillConfirmTime = now
                            
                            showSpeechBubble("92536008979873", "right", 3, character.Head)
                            
                            local dioKillSound = Instance.new("Sound", workspace)
                            dioKillSound.SoundId = "rbxassetid://110578259527952"
                            dioKillSound.Volume = 1.6
                            dioKillSound:Play()
                            Debris:AddItem(dioKillSound, 4)
                            
                            cameraShake(0.6, 2.5)
                        end
                        -- =========================================================================
                        
                        EmitBloodVFX(hitPart.Parent)
                        
                        if movementConnection then movementConnection:Disconnect() end
                        knife:Destroy()
                        return
                    end
                end
            end
        end
        
        lastPosition = currentPosition
    end)
end

-- ==================== SISTEMA DE COOLDOWN VISUAL JOJO ====================
local cooldownBars = {}

local function createCooldownBar(button, abilityName, duration)
	-- Container principal da barra
	local barContainer = Instance.new("Frame")
	barContainer.Name = abilityName .. "_Cooldown"
	barContainer.Size = UDim2.new(1.1, 0, 0, 10)
	barContainer.Position = UDim2.new(-0.05, 0, -0.15, 0)
	barContainer.AnchorPoint = Vector2.new(0, 1)
	barContainer.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	barContainer.BackgroundTransparency = 1
	barContainer.ZIndex = 10
	barContainer.Parent = button
	
	-- Borda dourada fina
	local border = Instance.new("UIStroke")
	border.Color = Color3.fromRGB(255, 215, 0)
	border.Thickness = 1.5
	border.Transparency = 0.3
	border.Parent = barContainer
	
	-- Fundo escuro da barra
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.Position = UDim2.new(0, 0, 0, 0)
	background.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	background.BorderSizePixel = 0
	background.ZIndex = 10
	background.Parent = barContainer
	Instance.new("UICorner", background).CornerRadius = UDim.new(0, 3)
	
	-- Barra de preenchimento (dourada)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.Position = UDim2.new(0, 0, 0, 0)
	fill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	fill.BorderSizePixel = 0
	fill.ZIndex = 11
	fill.Parent = barContainer
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)
	
	-- Gradiente dourado
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 180, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 0))
	}
	gradient.Parent = fill
	
	-- Texto de contagem
	local countText = Instance.new("TextLabel")
	countText.Name = "Count"
	countText.Size = UDim2.new(1, 0, 1, 0)
	countText.Position = UDim2.new(0, 0, 0, 0)
	countText.BackgroundTransparency = 1
	countText.Text = string.format("%.1f", duration)
	countText.TextColor3 = Color3.fromRGB(255, 255, 255)
	countText.TextStrokeTransparency = 0
	countText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	countText.Font = Enum.Font.Bangers
	countText.TextSize = 8
	countText.ZIndex = 12
	countText.Parent = barContainer
	
	-- Animações de entrada
	barContainer.Size = UDim2.new(1.1, 0, 0, 0)
	barContainer.BackgroundTransparency = 1
	
	TweenService:Create(barContainer, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(1.1, 0, 0, 10),
		BackgroundTransparency = 0
	}):Play()
	
	-- Brilho pulsante na borda
	spawn(function()
		while barContainer and barContainer.Parent do
			TweenService:Create(border, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0.6
			}):Play()
			task.wait(0.5)
			TweenService:Create(border, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0.2
			}):Play()
			task.wait(0.5)
		end
	end)
	
	return barContainer, fill, countText, gradient
end

local function showCooldownOnButton(button, abilityName)
	-- Remove barra antiga se existir
	if cooldownBars[abilityName] and cooldownBars[abilityName].Parent then
		cooldownBars[abilityName]:Destroy()
	end
	
	local duration = COOLDOWNS[abilityName]
	local barContainer, fill, countText, gradient = createCooldownBar(button, abilityName, duration)
	cooldownBars[abilityName] = barContainer
	
	local startTime = tick()
	local endTime = startTime + duration
	
	local updateConnection
	updateConnection = RunService.RenderStepped:Connect(function()
		if not barContainer or not barContainer.Parent then
			updateConnection:Disconnect()
			return
		end
		
		local remaining = endTime - tick()
		if remaining <= 0 then
			-- Anima saída
			TweenService:Create(barContainer, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = UDim2.new(1.1, 0, 0, 1),
				BackgroundTransparency = 1
			}):Play()
			
			task.delay(0.2, function()
				if barContainer and barContainer.Parent then
					barContainer:Destroy()
				end
			end)
			
			updateConnection:Disconnect()
			return
		end
		
		local progress = remaining / duration
		fill.Size = UDim2.new(progress, 0, 1, 0)
		countText.Text = string.format("%.1f", remaining)
		
		-- Muda cor da barra baseado no tempo restante
		if progress < 0.3 then
			gradient.Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 50)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 30, 30))
			}
			countText.TextColor3 = Color3.fromRGB(255, 100, 100)
		end
	end)
	
	-- Empilha as barras se já existir alguma
	local existingBars = 0
	for _, child in ipairs(button:GetChildren()) do
		if child:IsA("Frame") and child.Name:find("_Cooldown") and child ~= barContainer then
			existingBars = existingBars + 1
		end
	end
	
	barContainer.Position = UDim2.new(-0.05, 0, -0.15 - (existingBars * 0.12), 0)
end

-- ==================== SISTEMA ANTI-SPAM (BLOQUEIO IMEDIATO) ====================
local isAbilityLocked = {
    Barragem = false,
    Knife = false,
    TimeStop = false,
    RoadRoller = false
}

-- Função que bloqueia imediatamente e libera após cooldown
local function lockAbility(abilityName)
    if isAbilityLocked[abilityName] then return false end
    
    -- Bloqueia IMEDIATAMENTE
    isAbilityLocked[abilityName] = true
    
    -- Agenda liberação após o cooldown
    task.delay(COOLDOWNS[abilityName], function()
        isAbilityLocked[abilityName] = false
    end)
    
    return true
end

-- Função de verificação aprimorada
local function canUseStrict(abilityName)
    -- Verifica se a habilidade está bloqueada
    if isAbilityLocked[abilityName] then
        return false
    end
    
    -- Verifica cooldown normal
    local currentTime = tick()
    if currentTime - lastUsed[abilityName] < COOLDOWNS[abilityName] then
        return false
    end
    
    return true
end

-- ============================================================
-- ⏱️ CONGELAMENTO DO TIME STOP (portado do Sandevistan)
-- Ao ativar: tudo no mundo para (peças soltas, outros jogadores/NPCs, animações,
-- partículas, rastros, beams, vídeos, sons, imagens/decals/luzes/GUIs no mundo).
-- Ao desativar: o mundo volta aos poucos, em lotes por frame (sem pico de FPS).
-- NÃO congela: seu boneco, seu Stand, facas, Road Roller e o que o próprio script
-- cria (efeitos, sons, balões). Tudo local (só na sua tela).
-- Tudo fica dentro da tabela TimeFreeze (não cria locals novos no topo do script).
-- ============================================================
local TimeFreeze = {
    Active = false,
    Radius = math.huge,      -- raio (studs) do congelamento; math.huge = mundo inteiro
    FreezeNew = false,       -- congelar também o que NASCE depois (desligado: efeitos/facas do script nascem livres)
    PriorityRadii = {60, 150, 320}, -- congela PRIMEIRO o que está perto de você (no mesmo frame)
    PriorityBudget = 0.012,
    PriorityMaxParts = 4000,
    FastScanFrames = 12,
    FastScanBudget = 0.008,
    ScanBudget = 0.003,
    ReleaseBudget = 0.0015,
    Parts = {}, Anims = {}, Emitters = {}, Trails = {}, Beams = {},
    Kinds = {ParticleEmitter = "emitter", Fire = "emitter", Smoke = "emitter", Sparkles = "emitter", Trail = "trail", Beam = "beam", Animator = "animator", Sound = "sound"},
    TrailFrozenLifetime = 3600,
    Videos = {},
    Props = {},
    PropEnforce = {},
    PropIndex = 1,
    PropConn = nil,
    PropBudget = 0.002,
    PropPartMax = 6000,
    PropPartCount = 0,
    PropList = {},
    PartProps = {"Transparency", "Color", "Size"},
    -- nomes de coisas criadas por este script (e seus filhos) que nunca congelam
    IgnoreNames = {DioKnife = true, DioKnifeProp = true, RoadRoller = true, JojoSpeechBubble = true, TzeWindParticles = true, TS_Effect = true, TS_Bloom = true},
    Created = setmetatable({}, {__mode = "k"}), -- tudo que nasceu entre o clique e o congelamento (efeitos/sons do script)
    PreConn = nil,
    Sounds = {},
    AnimatorConns = {},
    Conns = {},
    ScanConn = nil, ReleaseConn = nil, EnforceConn = nil, AddedConn = nil,
    Locks = {},
    LockCount = 0,
    LockMax = 4000,
    LockRadii = {80, 200, 400},
    Debug = false,
    EnforceBudget = 0.0015,
    Enforce = {},
    EnforceIndex = 1,
    Queue = nil,
    QueueIndex = 1,
}

function TimeFreeze.Root()
    return character and character:FindFirstChild("HumanoidRootPart")
end

function TimeFreeze.IsMine(inst)
    if character and inst:IsDescendantOf(character) then return true end
    if currentStand and inst:IsDescendantOf(currentStand) then return true end
    return false
end

function TimeFreeze.IsIgnored(inst)
    if TimeFreeze.Created[inst] or TimeFreeze.IsMine(inst) then return true end
    local p = inst.Parent
    while p and p ~= workspace do
        if TimeFreeze.Created[p] or TimeFreeze.IgnoreNames[p.Name] then return true end
        p = p.Parent
    end
    if TimeFreeze.IgnoreNames[inst.Name] then return true end
    return false
end

-- começa a anotar o que o PRÓPRIO script cria entre o clique e o congelamento (som, balão, efeitos)
function TimeFreeze.Begin()
    if TimeFreeze.PreConn then TimeFreeze.PreConn:Disconnect() end
    TimeFreeze.Created = setmetatable({}, {__mode = "k"})
    TimeFreeze.PreConn = workspace.DescendantAdded:Connect(function(inst)
        TimeFreeze.Created[inst] = true
    end)
end

-- Trava o CFrame: peças ancoradas movidas pelo servidor voltam pra posição de quando o tempo parou
function TimeFreeze.Lock(part)
    if TimeFreeze.Locks[part] or TimeFreeze.LockCount >= TimeFreeze.LockMax then return end
    local saved = part.CFrame
    TimeFreeze.LockCount += 1
    TimeFreeze.Locks[part] = part:GetPropertyChangedSignal("CFrame"):Connect(function()
        if TimeFreeze.Active and part.CFrame ~= saved then
            part.CFrame = saved
        end
    end)
end

function TimeFreeze.FreezePart(part)
    if part.Anchored or part:IsA("Terrain") then return end
    if TimeFreeze.IsIgnored(part) then return end
    local root = TimeFreeze.Root()
    local myRoot = root and root.AssemblyRootPart
    if myRoot and part.AssemblyRootPart == myRoot then return end
    if TimeFreeze.Radius < math.huge and root and (part.Position - root.Position).Magnitude > TimeFreeze.Radius then return end
    TimeFreeze.Parts[part] = true
    part.Anchored = true
    table.insert(TimeFreeze.Enforce, {"part", part})
    TimeFreeze.Lock(part)
end

function TimeFreeze.FreezeTrack(track)
    if TimeFreeze.Anims[track] == nil then
        TimeFreeze.Anims[track] = track.Speed
        table.insert(TimeFreeze.Enforce, {"anim", track})
    end
    track:AdjustSpeed(0)
end

function TimeFreeze.FreezeAnimator(animator)
    if TimeFreeze.IsIgnored(animator) then return end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        pcall(TimeFreeze.FreezeTrack, track)
    end
    if not TimeFreeze.AnimatorConns[animator] then
        TimeFreeze.AnimatorConns[animator] = animator.AnimationPlayed:Connect(function(track)
            if TimeFreeze.Active then pcall(TimeFreeze.FreezeTrack, track) end
        end)
    end
end

function TimeFreeze.FreezeEmitter(emitter)
    if TimeFreeze.IsIgnored(emitter) then return end
    if TimeFreeze.Emitters[emitter] == nil then
        TimeFreeze.Emitters[emitter] = emitter.TimeScale
        emitter.TimeScale = 0
        table.insert(TimeFreeze.Enforce, {"emitter", emitter})
    end
end

-- Trail: sem peça se mexendo não nasce segmento novo; Lifetime enorme impede os existentes de sumir
function TimeFreeze.FreezeTrail(trail)
    if TimeFreeze.IsIgnored(trail) then return end
    if TimeFreeze.Trails[trail] == nil then
        TimeFreeze.Trails[trail] = trail.Lifetime
        trail.Lifetime = TimeFreeze.TrailFrozenLifetime
        table.insert(TimeFreeze.Enforce, {"trail", trail})
    end
end

-- Beam: a textura que rola (TextureSpeed) para
function TimeFreeze.FreezeBeam(beam)
    if TimeFreeze.IsIgnored(beam) then return end
    if TimeFreeze.Beams[beam] == nil then
        TimeFreeze.Beams[beam] = beam.TextureSpeed
        beam.TextureSpeed = 0
        table.insert(TimeFreeze.Enforce, {"beam", beam})
    end
end

-- VÍDEO (VideoFrame em SurfaceGui): pausa
function TimeFreeze.FreezeVideo(video)
    if TimeFreeze.Videos[video] == nil then
        TimeFreeze.Videos[video] = video.Playing
        video:Pause()
        table.insert(TimeFreeze.Enforce, {"video", video})
    end
end

-- PROPRIEDADES TRAVADAS: imagens, decals, texturas, luzes, highlights, GUIs no mundo e VFX feito de peça.
function TimeFreeze.FreezeProps(inst, list)
    if TimeFreeze.Props[inst] or not list then return end
    local orig = {}
    for _, prop in ipairs(list) do
        local o = inst
        local ok, v = pcall(function() return o[prop] end)
        if ok then orig[prop] = v end
    end
    TimeFreeze.Props[inst] = {orig = orig, want = {}}
    table.insert(TimeFreeze.PropEnforce, inst)
end

function TimeFreeze.FreezePartProps(part)
    if TimeFreeze.Props[part] or TimeFreeze.PropPartCount >= TimeFreeze.PropPartMax then return end
    if part.CanCollide or part.Transparency >= 1 or part:IsA("Terrain") then return end
    if TimeFreeze.IsIgnored(part) then return end
    TimeFreeze.PropPartCount += 1
    TimeFreeze.FreezeProps(part, TimeFreeze.PartProps)
end

function TimeFreeze.EnforceProps(inst, rec)
    local o = inst
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
function TimeFreeze.FreezeSound(snd, watch)
    if TimeFreeze.IsIgnored(snd) then return end
    if snd.IsPlaying then
        if not TimeFreeze.Sounds[snd] then
            TimeFreeze.Sounds[snd] = true
            snd:Pause()
            table.insert(TimeFreeze.Enforce, {"sound", snd})
        end
    elseif watch then
        table.insert(TimeFreeze.Conns, snd.Played:Connect(function()
            if TimeFreeze.Active and not TimeFreeze.IsIgnored(snd) then
                pcall(TimeFreeze.FreezeSound, snd)
            end
        end))
    end
end

function TimeFreeze.Process(inst)
    if inst:IsA("BasePart") then
        TimeFreeze.FreezePart(inst)
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
        TimeFreeze.FreezeEmitter(inst)
    elseif k == "trail" then
        TimeFreeze.FreezeTrail(inst)
    elseif k == "beam" then
        TimeFreeze.FreezeBeam(inst)
    elseif k == "animator" then
        TimeFreeze.FreezeAnimator(inst)
    elseif k == "sound" then
        TimeFreeze.FreezeSound(inst)
    end
end

-- aplica a restauração de 1 item da fila
function TimeFreeze.RestoreEntry(e)
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
            local o = inst
            for prop, v in pairs(value) do pcall(function() o[prop] = v end) end
        end
    elseif kind == "part" then
        if inst.Parent then inst.Anchored = false end
    end
end

-- termina na hora o que ainda estiver sendo solto (usado se o Time Stop reativar)
function TimeFreeze.FlushRelease()
    if TimeFreeze.ReleaseConn then
        TimeFreeze.ReleaseConn:Disconnect()
        TimeFreeze.ReleaseConn = nil
    end
    local q = TimeFreeze.Queue
    if q then
        for i = TimeFreeze.QueueIndex, #q do
            if q[i] then pcall(TimeFreeze.RestoreEntry, q[i]) end
        end
    end
    TimeFreeze.Queue = nil
    TimeFreeze.QueueIndex = 1
end

-- partículas/sons pendurados numa peça (direto nela ou dentro de um Attachment)
function TimeFreeze.FreezeChildren(part)
    for _, c in ipairs(part:GetChildren()) do
        if c:IsA("Attachment") then
            for _, cc in ipairs(c:GetChildren()) do
                pcall(TimeFreeze.Process, cc)
            end
        elseif c:IsA("LayerCollector") then
            pcall(TimeFreeze.Process, c)
            for _, d in ipairs(c:GetDescendants()) do
                pcall(TimeFreeze.Process, d)
            end
        else
            pcall(TimeFreeze.Process, c)
        end
    end
end

-- PASSADA INSTANTÂNEA: congela primeiro tudo que está perto de você, em anéis de raio crescente
function TimeFreeze.PriorityPass()
    local root = TimeFreeze.Root()
    local origin = root and root.Position or workspace.CurrentCamera.CFrame.Position
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local filter = {character}
    if currentStand then table.insert(filter, currentStand) end
    params.FilterDescendantsInstances = filter
    params.MaxParts = TimeFreeze.PriorityMaxParts
    local seenModels = {}
    local t0 = os.clock()
    for _, radius in ipairs(TimeFreeze.PriorityRadii) do
        for _, part in ipairs(workspace:GetPartBoundsInRadius(origin, radius, params)) do
            pcall(TimeFreeze.FreezePart, part)
            pcall(TimeFreeze.FreezePartProps, part)
            pcall(TimeFreeze.FreezeChildren, part)
            local model = part:FindFirstAncestorOfClass("Model")
            if model and not seenModels[model] then
                seenModels[model] = true
                if model:FindFirstChildWhichIsA("Humanoid") or model:FindFirstChildWhichIsA("AnimationController") then
                    local animator = model:FindFirstChildWhichIsA("Animator", true)
                    if animator then pcall(TimeFreeze.FreezeAnimator, animator) end
                end
            end
            if os.clock() - t0 > TimeFreeze.PriorityBudget then return end
        end
    end
end

function TimeFreeze.LockNearbyAnchored()
    local root = TimeFreeze.Root()
    if not root then return end
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local filter = {character}
    if currentStand then table.insert(filter, currentStand) end
    params.FilterDescendantsInstances = filter
    params.MaxParts = TimeFreeze.LockMax
    local myRoot = root.AssemblyRootPart
    for _, radius in ipairs(TimeFreeze.LockRadii) do
        if TimeFreeze.LockCount >= TimeFreeze.LockMax then break end
        for _, part in ipairs(workspace:GetPartBoundsInRadius(root.Position, radius, params)) do
            if part.Anchored and not part:IsA("Terrain") and part.AssemblyRootPart ~= myRoot and not TimeFreeze.IsIgnored(part) then
                TimeFreeze.Lock(part)
            end
        end
    end
end

function TimeFreeze.Start()
    if TimeFreeze.Active then return end
    TimeFreeze.FlushRelease()
    TimeFreeze.Active = true
    -- a partir daqui o que nasce é do script (facas, roller, efeitos): não precisa mais anotar
    if TimeFreeze.PreConn then TimeFreeze.PreConn:Disconnect() TimeFreeze.PreConn = nil end

    -- 1) outros jogadores primeiro (o que mais aparece na tela)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            for _, d in ipairs(plr.Character:GetDescendants()) do
                pcall(TimeFreeze.Process, d)
            end
        end
    end

    -- 1.5) tudo que está perto de você, instantâneo
    pcall(TimeFreeze.PriorityPass)

    -- 2) sons do jogo (SoundService)
    for _, d in ipairs(game:GetService("SoundService"):GetDescendants()) do
        if d:IsA("Sound") then pcall(TimeFreeze.FreezeSound, d) end
    end

    -- 2.5) peças ANCORADAS próximas: trava o CFrame (movimentos feitos pelo servidor)
    pcall(TimeFreeze.LockNearbyAnchored)

    -- 3) resto do mundo, em fatias de tempo (sem travar a ativação)
    local list = workspace:GetDescendants()
    local idx, n, frame = 1, #list, 0
    TimeFreeze.ScanConn = RunService.Heartbeat:Connect(function()
        frame += 1
        local budget = (frame <= TimeFreeze.FastScanFrames) and TimeFreeze.FastScanBudget or TimeFreeze.ScanBudget
        local t0 = os.clock()
        while idx <= n do
            local inst = list[idx]
            idx += 1
            if inst.Parent then pcall(TimeFreeze.Process, inst) end
            if idx % 64 == 0 and os.clock() - t0 > budget then return end
        end
        if TimeFreeze.ScanConn then
            TimeFreeze.ScanConn:Disconnect()
            TimeFreeze.ScanConn = nil
        end
        if TimeFreeze.Debug then
            local function count(t) local c = 0 for _ in pairs(t) do c += 1 end return c end
            print(string.format("[TimeStop] varridas %d instâncias em %d frames | peças: %d | CFrame travado: %d | animações: %d | partículas: %d | rastros: %d | beams: %d | props: %d | sons: %d",
                n, frame, count(TimeFreeze.Parts), TimeFreeze.LockCount, count(TimeFreeze.Anims), count(TimeFreeze.Emitters), count(TimeFreeze.Trails), count(TimeFreeze.Beams), count(TimeFreeze.Props), count(TimeFreeze.Sounds)))
        end
    end)

    -- 3.5) (opcional) o que NASCE depois também congela
    if TimeFreeze.FreezeNew then
        TimeFreeze.AddedConn = workspace.DescendantAdded:Connect(function(inst)
            task.defer(function()
                if not TimeFreeze.Active or not inst.Parent then return end
                if TimeFreeze.IsIgnored(inst) then return end
                if inst:IsA("Sound") then
                    pcall(TimeFreeze.FreezeSound, inst, true)
                else
                    pcall(TimeFreeze.Process, inst)
                end
            end)
        end)
    end

    -- 3.8) VFX/imagens/decals/luzes/GUIs: desfaz qualquer mudança vinda de script/tween do jogo
    TimeFreeze.PropIndex = 1
    TimeFreeze.PropConn = RunService.RenderStepped:Connect(function()
        local list2 = TimeFreeze.PropEnforce
        local cnt = #list2
        if cnt == 0 then return end
        local t0 = os.clock()
        local checked = 0
        local i = TimeFreeze.PropIndex
        while checked < cnt do
            if i > cnt then i = 1 end
            local inst = list2[i]
            local rec = TimeFreeze.Props[inst]
            if rec and inst.Parent then pcall(TimeFreeze.EnforceProps, inst, rec) end
            i += 1
            checked += 1
            if checked % 32 == 0 and os.clock() - t0 > TimeFreeze.PropBudget then break end
        end
        TimeFreeze.PropIndex = i
    end)

    -- 4) o que entrou NÃO sai: ronda circular religa o congelamento de qualquer coisa que o jogo tente soltar
    TimeFreeze.EnforceIndex = 1
    TimeFreeze.EnforceConn = RunService.Heartbeat:Connect(function()
        local list3 = TimeFreeze.Enforce
        local cnt = #list3
        if cnt == 0 then return end
        local t0 = os.clock()
        local checked = 0
        local i = TimeFreeze.EnforceIndex
        while checked < cnt do
            if i > cnt then i = 1 end
            local e = list3[i]
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
    if TimeFreeze.PreConn then TimeFreeze.PreConn:Disconnect() TimeFreeze.PreConn = nil end
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
    TimeFreeze.Created = setmetatable({}, {__mode = "k"})

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

    local root = TimeFreeze.Root()
    local origin = root and root.Position or Vector3.zero
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
            pcall(TimeFreeze.RestoreEntry, q[i])
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


-- ==================== VARIÁVEL DE BLOQUEIO DO TIME STOP (adicione no topo com as outras) ====================
local isTimeStopLocked = false  -- Bloqueio durante animação inicial

local function toggleTime()
    -- ========== BLOQUEIO TOTAL DURANTE ANIMAÇÃO INICIAL ==========
    if isTimeStopLocked then
        return  -- Ignora qualquer clique durante a animação
    end
    
    if isTimeStopped then
        -- ========== DESATIVAR TIME STOP ==========
        isTimeStopped = false
        tsBtn.Text = "STOP"
        TimeFreeze.Stop() -- solta o mundo em lotes (antes de liberar as facas)
        
lastUsed["TimeStop"] = tick()
lockAbility("TimeStop")
showCooldownOnButton(tsBtn, "TimeStop")

        -- Descongela as facas e restaura movimento
        for knife, data in pairs(frozenKnives) do
            if knife and knife.Parent then
                knife.Anchored = false
                
                if data.velocity then
                    -- Verifica se o LinearVelocity ainda existe
                    if data.velocity.Parent then
                        data.velocity.Enabled = true
                        data.velocity.VectorVelocity = data.direction * 295
                    else
                        -- Recria o LinearVelocity se foi destruído
                        local newAttachment = data.attachment
                        if not newAttachment or not newAttachment.Parent then
                            newAttachment = Instance.new("Attachment", knife)
                        end
                        local newVel = Instance.new("LinearVelocity", knife)
                        newVel.Attachment0 = newAttachment
                        newVel.MaxForce = math.huge
                        newVel.VectorVelocity = data.direction * 295
                        newVel.Parent = knife
                    end
                end
                
                -- INICIA O PROCESSAMENTO DE HIT DA FACA DESCONGELADA
                processKnifeMovement(knife, data.direction)
                
                -- Define tempo de vida após descongelar
                Debris:AddItem(knife, 4)
            end
        end
        frozenKnives = {}
                
        local bloom = Lighting:FindFirstChild("TS_Bloom")
        if bloom then
            TweenService:Create(bloom, TweenInfo.new(0.5), {Intensity = 0}):Play()
            task.delay(0.5, function() if bloom then bloom:Destroy() end end)
        end
                
        TweenService:Create(roadBtn, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = TS_POS,
            Size = UDim2.fromOffset(0, 0)
        }):Play()
        task.delay(0.3, function() roadBtn.Visible = false end)
        
        local s = Instance.new("Sound", workspace) s.SoundId = ASSETS.TS_END_SFX s:Play() Debris:AddItem(s, 3)
        frozenParts = {}
        local cc = Lighting:FindFirstChild("TS_Effect")
        if cc then
            TweenService:Create(cc, TweenInfo.new(0.4), {TintColor = Color3.fromRGB(170, 0, 255), Saturation = -1.0, Contrast = 0.7}):Play()
            task.delay(0.3, function() if not isTimeStopped then TweenService:Create(cc, TweenInfo.new(0.4), {TintColor = Color3.fromRGB(0, 180, 255), Saturation = -0.5, Contrast = 0.6}):Play() end end)
            task.delay(0.6, function() if not isTimeStopped then TweenService:Create(cc, TweenInfo.new(0.4), {TintColor = Color3.fromRGB(255, 140, 0), Saturation = 1.2, Contrast = 0.8, Brightness = 0.3}):Play() end end)
            task.delay(0.9, function() if not isTimeStopped then TweenService:Create(cc, TweenInfo.new(0.6), {Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.fromRGB(255,255,255)}):Play() Debris:AddItem(cc, 0.7) end end)
        end
        updateIconState(tsIcon, false)
        
    else
        -- ========== ATIVAR TIME STOP ==========
        if not canUseStrict("TimeStop") then return end
        
        isTimeStopped = true
        tsBtn.Text = "RESUME"
        TimeFreeze.Begin() -- anota o que o próprio script cria até o congelamento
        
        -- ========== BLOQUEIA CANCELAMENTO DURANTE 1.5 SEGUNDOS ==========
        isTimeStopLocked = true
        
        -- Congela todas as facas existentes no mapa
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Part") and obj.Name == "DioKnife" and not obj.Anchored then
                local lv = obj:FindFirstChild("LinearVelocity")
                local att = obj:FindFirstChild("Attachment")
                if lv then
                    lv.Enabled = false
                end
                obj.Anchored = true
                frozenKnives[obj] = {
                    velocity = lv, 
                    direction = obj:GetAttribute("ShootDir") or Vector3.new(0,0,0),
                    attachment = att
                }
            end
        end
        
        roadBtn.Visible = true
        TweenService:Create(roadBtn, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = ROAD_POS,
            Size = UDim2.fromOffset(70, 70)
        }):Play()
        
        local root = character:FindFirstChild("HumanoidRootPart")
        local s = Instance.new("Sound", workspace) s.SoundId = ASSETS.TS_START_SFX s.Volume = 2 s:Play() Debris:AddItem(s, 5)
        
        local tsAnimId = (math.random(1, 2) == 1) and ASSETS.ANIM_DIO or ASSETS.ANIM_DIO_VARIANT -- 50% normal / 50% Variant
        local tsTrack = nil
        if not isPlayerR6() then -- RIG 6: sem animação no Time Stop
            tsTrack = playAnim(hum, tsAnimId, 2, false, Enum.AnimationPriority.Action)
        end
        
        if root then root.Anchored = true end
        showSpeechBubble(106366607174396, "right", 4)
        
        -- ========== APÓS 1.5 SEGUNDOS, LIBERA O CANCELAMENTO ==========
        task.delay(1.5, function()
            if not isTimeStopped then 
                isTimeStopLocked = false
                return 
            end
            
            -- Libera o bloqueio para permitir cancelamento futuro
            isTimeStopLocked = false
            
            TimeFreeze.Start() -- congelamento do Sandevistan
            
            EmitTimeStopVFX()
            
            cinematicZoom(1, 40)
            
            task.delay(0.1, function()
                cameraShake(2, 3.0)
            end)
            
            if root then root.Anchored = false end
            
            local cc = Lighting:FindFirstChild("TS_Effect") or Instance.new("ColorCorrectionEffect", Lighting)
            cc.Name = "TS_Effect"
            cc.Saturation = 0 cc.Contrast = 0 cc.Brightness = 0 cc.TintColor = Color3.fromRGB(255, 140, 0)
            TweenService:Create(cc, TweenInfo.new(0.4), {Saturation = 1.5, Contrast = 0.8, Brightness = 0.2}):Play()
            task.delay(0.1, function() if isTimeStopped then TweenService:Create(cc, TweenInfo.new(0.4), {TintColor = Color3.fromRGB(0, 180, 255), Saturation = -0.8, Contrast = 0.6, Brightness = 0}):Play() end end)
            task.delay(0.2, function() if isTimeStopped then TweenService:Create(cc, TweenInfo.new(0.4), {TintColor = Color3.fromRGB(170, 0, 255), Saturation = -1.1, Contrast = 0.7}):Play() end end)
            task.delay(0.3, function() if isTimeStopped then TweenService:Create(cc, TweenInfo.new(0.5), {Saturation = -1.2, Contrast = 0.5, Brightness = 0, TintColor = Color3.fromRGB(180, 200, 255)}):Play() end end)
            
        end)
        
       updateIconState(tsIcon, true)
    end
end

local function getClosestTarget(maxDist)
	local closest, minDist = nil, maxDist
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Humanoid") and obj ~= hum and (not currentStand or obj.Parent ~= currentStand) then
			local targetRoot = obj.Parent:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				local dist = (targetRoot.Position - root.Position).Magnitude
				if dist < minDist then
					minDist = dist
					closest = targetRoot
				end
			end
		end
	end
	return closest
end

local function createExplosion(position)
	local explosionPart = Instance.new("Part")
	explosionPart.Transparency = 1
	explosionPart.Anchored = true
	explosionPart.CanCollide = false
	explosionPart.Position = position
	explosionPart.Size = Vector3.new(1,1,1)
	explosionPart.Parent = workspace

	local fire = Instance.new("ParticleEmitter", explosionPart)
	fire.Texture = "rbxassetid://241650899"
	fire.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 0, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 0, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 150))
	}
	fire.Lifetime = NumberRange.new(1.8, 2.5)
	fire.Rate = 350
	fire.Speed = NumberRange.new(15, 35)
	fire.Size = NumberSequence.new{NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 0)}
	fire.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)}
	fire.Acceleration = Vector3.new(0, -25, 0)
	fire.SpreadAngle = Vector2.new(30, 30)

	local dust = Instance.new("ParticleEmitter", explosionPart)
	dust.Texture = "rbxassetid://241650899"
	dust.Color = ColorSequence.new(Color3.fromRGB(170, 170, 170))
	dust.Lifetime = NumberRange.new(2, 3.5)
	dust.Rate = 180
	dust.Speed = NumberRange.new(8, 18)
	dust.Size = NumberSequence.new{NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 2)}
	dust.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1)}
	dust.Acceleration = Vector3.new(0, -10, 0)

	Debris:AddItem(explosionPart, 4)
end

local function createRoadRoller()
	local model = Instance.new("Model")
	model.Name = "RoadRoller"

	local mainPart = Instance.new("Part")
	mainPart.Name = "Body"
	mainPart.Size = Vector3.new(1, 1, 1)
	mainPart.Transparency = 0
	mainPart.Color = Color3.fromRGB(80, 80, 80)
	mainPart.Anchored = true
	mainPart.CanCollide = false
	mainPart.Parent = model

	local mesh = Instance.new("SpecialMesh", mainPart)
	mesh.MeshId = ASSETS.ROAD_ROLLER_MESH
	mesh.TextureId = ASSETS.ROAD_ROLLER_TEXTURE
	mesh.Scale = Vector3.new(1.3, 1.7, 1.3)

	model.PrimaryPart = mainPart
	return model
end

local function createGroundCracks(position)
	for i = 1, 8 do
		local crack = Instance.new("Part")
		crack.Size = Vector3.new(0.15, 0.01, math.random(3, 8))
		crack.Anchored = true
		crack.CanCollide = false
		crack.Color = Color3.fromRGB(25, 25, 25)
		crack.Material = Enum.Material.CrackedLava
		crack.Transparency = 0.2
		
		local angle = math.rad(math.random(0, 360))
		local distance = math.random(1, 6)
		local offset = Vector3.new(math.cos(angle) * distance, 0.01, math.sin(angle) * distance)
		crack.CFrame = CFrame.new(position + offset) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
		crack.Parent = workspace
		
		crack.Transparency = 0.8
		TweenService:Create(crack, TweenInfo.new(0.3), {Transparency = 0.2}):Play()
		
		Debris:AddItem(crack, 8)
	end
	
	local centerCrater = Instance.new("Part")
	centerCrater.Size = Vector3.new(4, 0.02, 4)
	centerCrater.Anchored = true
	centerCrater.CanCollide = false
	centerCrater.Color = Color3.fromRGB(30, 30, 30)
	centerCrater.Material = Enum.Material.CrackedLava
	centerCrater.Transparency = 0.4
	centerCrater.CFrame = CFrame.new(position + Vector3.new(0, 0.005, 0))
	centerCrater.Parent = workspace
	
	local decal = Instance.new("Decal", centerCrater)
	decal.Texture = "rbxassetid://154292235"
	decal.Face = Enum.NormalId.Top
	decal.Transparency = 0.3
	
	Debris:AddItem(centerCrater, 8)
end

local function performRoadRoller()
	if not isTimeStopped then
		showSpeechBubble(102362181377695, "right", 2.5)
		return
	end
	if not canUseStrict("RoadRoller") then return end
lockAbility("RoadRoller")  -- Bloqueia imediatamente
	
local activationFlash = Instance.new("Frame")
activationFlash.Name = "RoadRollerActivationFlash"
activationFlash.Size = UDim2.fromScale(2, 2)
activationFlash.Position = UDim2.fromScale(-0.5, -0.5)
activationFlash.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
activationFlash.BackgroundTransparency = 1
activationFlash.ZIndex = 100
activationFlash.Parent = screenGui

TweenService:Create(activationFlash, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
	BackgroundTransparency = 0
}):Play()

task.delay(0.1, function()
	if activationFlash.Parent then
		TweenService:Create(activationFlash, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1
		}):Play()
		task.delay(0.15, function() 
			if activationFlash.Parent then 
				activationFlash:Destroy() 
			end 
		end)
	end
end)

	local targetRoot = getClosestTarget(100)
	if not targetRoot then return end

	showSpeechBubble(ASSETS.ROAD_ROLLER_DA, "right", 2.5)
	cameraShake(4.5, 2.5)

	local rollerModel = createRoadRoller()
	local rollerRoot = rollerModel.PrimaryPart

	local startHeight = 500
	local startPos = targetRoot.Position + Vector3.new(0, startHeight, 0)
	rollerRoot.CFrame = CFrame.new(startPos) * CFrame.Angles(math.rad(85), 0, 90)
	rollerRoot.Anchored = false
	rollerModel.Parent = workspace

	for _, part in ipairs(rollerModel:GetDescendants()) do
		if part:IsA("BasePart") then
			frozenParts[part] = nil
			part.Anchored = false
		end
	end

	local spawnSound = Instance.new("Sound")
	spawnSound.SoundId = ASSETS.ROAD_ROLLER_SPAWN_SFX
	spawnSound.Volume = 2.5
	spawnSound.Parent = rollerRoot
	spawnSound:Play()
	Debris:AddItem(spawnSound, 5)

local charRoot = character:FindFirstChild("HumanoidRootPart")
local rideTrack = nil
local weld = nil

if charRoot then
	charRoot.Anchored = false
	frozenParts[charRoot] = nil
	
	charRoot.CFrame = rollerRoot.CFrame * CFrame.new(0, -2.5, -17)
	
	charRoot.CFrame = CFrame.lookAt(charRoot.Position, targetRoot.Position) * CFrame.Angles(math.rad(90), 0, 0)
	
	if hum and ASSETS.ROAD_ROLLER_RIDE_ANIM ~= "" then
		if not isPlayerR6() then -- RIG 6: sem animação (o weld continua)
			rideTrack = playAnim(hum, ASSETS.ROAD_ROLLER_RIDE_ANIM, 1.5, true, Enum.AnimationPriority.Action)
		end
		
		weld = Instance.new("WeldConstraint")
		weld.Part0 = charRoot
		weld.Part1 = rollerRoot
		weld.Parent = charRoot
	end
end

	local bodyVel = Instance.new("BodyVelocity")
	bodyVel.Velocity = Vector3.new(0, -450, 0)
	bodyVel.MaxForce = Vector3.new(1, 1, 1) * math.huge
	bodyVel.Parent = rollerRoot
	
	local bodyForce = Instance.new("BodyForce")
	bodyForce.Force = Vector3.new(0, -rollerRoot:GetMass() * 500, 0)
	bodyForce.Parent = rollerRoot
	
	local impactTriggered = false
	local checkConnection
	checkConnection = RunService.RenderStepped:Connect(function()
		if not rollerRoot or not rollerRoot.Parent then
			checkConnection:Disconnect()
			return
		end
		
		local currentY = rollerRoot.Position.Y
		local groundY = targetRoot.Position.Y - 3
		
		if currentY <= groundY + 5 and not impactTriggered then
			impactTriggered = true
			checkConnection:Disconnect()
			
			bodyVel:Destroy()
			bodyForce:Destroy()
			
			rollerRoot.Anchored = true
			rollerRoot.CFrame = CFrame.new(targetRoot.Position + Vector3.new(0, -3, 0)) * CFrame.Angles(math.rad(-80), math.rad(180), 0)
			
			local impactSound1 = Instance.new("Sound")
			impactSound1.SoundId = ASSETS.ROAD_ROLLER_IMPACT_SFX1
			impactSound1.Volume = 3
			impactSound1.Parent = rollerRoot
			impactSound1:Play()
			Debris:AddItem(impactSound1, 5)
			
			task.delay(0.15, function()
				local impactSound2 = Instance.new("Sound")
				impactSound2.SoundId = ASSETS.ROAD_ROLLER_IMPACT_SFX2
				impactSound2.Volume = 3
				impactSound2.Parent = rollerRoot
				impactSound2:Play()
				Debris:AddItem(impactSound2, 5)
			end)
			
			lastUsed["RoadRoller"] = tick()
showCooldownOnButton(roadBtn, "RoadRoller")

cameraShake(1.5, 5.0)
			
			if charRoot and charRoot.Parent then
				if weld then weld:Destroy() end
				if rideTrack then rideTrack:Stop() end
				
				charRoot.Anchored = false
				
				local exitPos = rollerRoot.CFrame * CFrame.new(8, 6, 0)
				TweenService:Create(charRoot, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CFrame = exitPos
				}):Play()
				
				task.delay(0.5, function()
					if charRoot and charRoot.Parent then
						local exitVel = Instance.new("BodyVelocity")
						exitVel.Velocity = Vector3.new(20, 30, 0)
						exitVel.MaxForce = Vector3.new(1, 1, 1) * 100000
						exitVel.Parent = charRoot
						Debris:AddItem(exitVel, 0.5)
					end
				end)
			end
			
			local targetHum = targetRoot.Parent:FindFirstChildOfClass("Humanoid")
			if targetHum then
				targetHum:TakeDamage(95)
			end

			createGroundCracks(targetRoot.Position)

			createExplosion(targetRoot.Position)

			if targetRoot and targetRoot.Parent then
				local knockbackDir = (targetRoot.Position - character.HumanoidRootPart.Position).Unit
				targetRoot:ApplyImpulse(Vector3.new(0, 80000, 0) + knockbackDir * 50000)
			end

			local disintegrationDelay = COOLDOWNS.RoadRoller - 4
			
			task.delay(disintegrationDelay, function()
				if rollerModel and rollerModel.Parent then
					local disintegratePart = Instance.new("Part")
					disintegratePart.Transparency = 1
					disintegratePart.Anchored = true
					disintegratePart.CanCollide = false
					disintegratePart.Position = rollerRoot.Position
					disintegratePart.Size = Vector3.new(1,1,1)
					disintegratePart.Parent = workspace
					
					local particles = Instance.new("ParticleEmitter", disintegratePart)
					particles.Texture = "rbxassetid://241650899"
					particles.Color = ColorSequence.new{
						ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 0, 255)),
						ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 0, 200)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 0, 150))
					}
					particles.Lifetime = NumberRange.new(1, 2)
					particles.Rate = 200
					particles.Speed = NumberRange.new(3, 8)
					particles.Size = NumberSequence.new{NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 0)}
					particles.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)}
					particles.Acceleration = Vector3.new(0, 2, 0)
					particles.SpreadAngle = Vector2.new(360, 360)
					
					Debris:AddItem(disintegratePart, 3)
					
					for _, part in ipairs(rollerModel:GetDescendants()) do
						if part:IsA("BasePart") and part ~= rollerRoot then
							TweenService:Create(part, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
								Transparency = 1
							}):Play()
						end
					end
					
					TweenService:Create(rollerRoot, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Transparency = 1
					}):Play()
					
					Debris:AddItem(rollerModel, 2.7)
				end
			end)
			
			Debris:AddItem(rollerModel, COOLDOWNS.RoadRoller)
		end
	end)
end

-- ============================================================
-- 🌟 THE WORLD BARRAGE — VFX (fiel ao anime: punhos fantasma, trilhas, "ムダ", ondas, flash)
-- ============================================================
local WORLD_GOLD     = Color3.fromRGB(255, 214, 60)
local WORLD_GOLD_HOT = Color3.fromRGB(255, 244, 170)
local WORLD_DARK     = Color3.fromRGB(70, 30, 0)

-- ============================================================
-- 💪 BARRAGEM — CONFIG + SINCRONIA COM O SOM + MUITOS BRAÇOS (estilo anime The World)
-- Tudo dentro de UMA tabela (BARRAGEM) pra não gastar locals do chunk (limite 200).
-- ============================================================
local BARRAGEM = {
    -- ⏱️ SINCRONIA COM O SOM
    -- A barragem INTEIRA dura exatamente o tempo do áudio (lido em Sound.TimeLength):
    --   [ socos em loop ................ ][ soco final ][ follow-through ]
    --   |<------------- duração do som (Sound.TimeLength) ------------->|
    SoundId        = ASSETS.MUDA_SOUND,
    SoundVolume    = 1.2,
    FallbackLength = 3.9,    -- só usado se o som não carregar
    TickInterval   = 0.065,  -- intervalo entre cada "muda" (hit)
    TotalDamage    = 46,     -- dano TOTAL da barragem (igual ao original: 46 hits x 1)
    FollowThrough  = 0.55,   -- tempo reservado pro soco final antes do som acabar
    MinLoopTime    = 0.6,    -- barragem mínima se o som for muito curto
    FitPlayerAnim  = false,  -- true = a animação do Dio é esticada pra dar 1 passada na duração do som
    soundLength    = nil,    -- cache da duração (preenchido sozinho)

    -- 💪 BRAÇOS EXTRAS — arco de trás pra frente, igual ao anime
    -- Cada braço nasce ATRÁS do Stand, varre em curva até o alvo e some ao chegar.
    -- Um novo braço começa imediatamente, criando a ilusão de ondas contínuas.
    Arms = {
        Enabled       = true,
        Count         = 8,      -- quantos braços no total (metade de cada lado). 6, 8, 10, 12…
        PeriodMin     = 0.18,   -- duração de 1 arco completo (trás→frente) em segundos
        PeriodMax     = 0.28,
        FanYaw        = 30,     -- abertura lateral do leque de socos (graus)
        FanPitch      = 18,     -- abertura vertical do leque (graus)
        ForearmAngle  = 100,    -- dobramento do cotovelo durante o arco
        Reach         = 2.2,    -- distância total que o braço percorre (studs, trás→frente)
        ArcBack       = 1.4,    -- quanto o braço começa atrás do torso (studs no eixo Z negativo)
        ArcLift       = 0.5,    -- altura extra na metade do arco (efeito "gancho vindo de baixo")
        FadeIn        = 0.08,   -- fade in global da barragem (segundos)
        FadeOut       = 0.18,   -- fade out global ao terminar (segundos)
        -- Fade do braço INDIVIDUAL: aparece no início do arco, some ao chegar no alvo
        ArmFadeIn     = 0.25,   -- fração do arco em que o braço vai de 0→1 de opacidade (0.25 = 25%)
        ArmFadeOut    = 0.25,   -- fração final em que vai de 1→0 (some ao "acertar")
        TintColor     = nil,    -- nil = cor do Stand | Color3.fromRGB(255,214,60) = dourado neon
        Debug         = false,
    },
}

-- Lê a duração real do som (espera carregar; cai no FallbackLength se falhar)
function BARRAGEM.getSoundLength(snd)
    if BARRAGEM.soundLength and BARRAGEM.soundLength > 0 then
        return BARRAGEM.soundLength
    end
    if snd and not snd.IsLoaded then
        local got = false
        local con = snd.Loaded:Connect(function() got = true end)
        local waited = 0
        while not got and not snd.IsLoaded and waited < 2 do
            waited += task.wait()
        end
        con:Disconnect()
    end
    if snd and snd.TimeLength > 0 then
        BARRAGEM.soundLength = snd.TimeLength
        return snd.TimeLength
    end
    warn("[BARRAGEM] Não consegui ler a duração do som, usando " .. BARRAGEM.FallbackLength .. "s")
    return BARRAGEM.FallbackLength
end

-- Pré-carrega o som ao iniciar o script (o primeiro uso da barragem já sai sincronizado, sem espera)
task.spawn(function()
    local snd = Instance.new("Sound")
    snd.Name = "BarragemPreload"
    snd.SoundId = BARRAGEM.SoundId
    snd.Volume = 0
    snd.Parent = workspace
    BARRAGEM.getSoundLength(snd)
    snd:Destroy()
end)

-- Cria os BRAÇOS EXTRAS do Stand. Cada "rig" é um CLONE COMPLETO do seu Stand (pra manter roupa, pele e
-- cor exatamente iguais); só os braços ficam visíveis e eu os movo com as juntas REAIS do R15
-- (ombro/cotovelo/pulso), então o braço fica inteiro, sem quebrar. Devolve { stop = function }.
function BARRAGEM.createArms(stand, targetRoot)
    local cfg = BARRAGEM.Arms
    local ctrl = { stop = function() end }
    if not cfg.Enabled or not stand then return ctrl end

    local torso = stand:FindFirstChild("UpperTorso") or stand:FindFirstChild("Torso")
    if not torso then
        warn("[BARRAGEM] Stand sem UpperTorso, braços extras desativados")
        return ctrl
    end

    local folder = Instance.new("Folder")
    folder.Name = "BarrageExtraArms"
    folder.Parent = workspace

    local function notify(text)
        print("[BARRAGEM] " .. text)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", { Title = "BARRAGEM debug", Text = text, Duration = 5 })
        end)
    end

    local ARM_PARTS = {
        RightUpperArm = true, RightLowerArm = true, RightHand = true,
        LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
    }

    -- clone completo do Stand; tudo invisível e ancorado, menos os braços
    local function makeRig()
        local ok, rig = pcall(function() return stand:Clone() end)
        if not ok or not rig then return nil end
        rig.Name = "ExtraArmRig"
        for _, d in ipairs(rig:GetDescendants()) do
            if d:IsA("BasePart") then
                d.Anchored = true
                d.CanCollide = false
                d.CanQuery = false
                d.CanTouch = false
                d.CastShadow = false
                d.Massless = true
                d.Transparency = 1 -- braços são revelados pelo fade-in
                if cfg.TintColor and d.Parent == rig and ARM_PARTS[d.Name] then
                    d.Color = cfg.TintColor
                    d.Material = Enum.Material.Neon
                end
            elseif d:IsA("Decal") or d:IsA("Texture") then
                if not (d.Parent and ARM_PARTS[d.Parent.Name]) then d.Transparency = 1 end
            elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Light") then
                d.Enabled = false
            elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
                d.Enabled = false
            elseif d:IsA("Sound") then
                d.Volume = 0
            elseif d:IsA("Humanoid") then
                pcall(function()
                    d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                    d.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
                    d.PlatformStand = true
                end)
            end
        end
        rig.Parent = folder
        return rig
    end

    local function attPos(part, name, fallback)
        local a = part and part:FindFirstChild(name)
        return (a and a:IsA("Attachment")) and a.Position or fallback
    end

    -- monta os braços extras (2 por rig: direito e esquerdo)
    local rigs, arms = {}, {}
    for k = 1, cfg.Count do
        local side = (k % 2 == 1) and "Right" or "Left"
        local sign = side == "Right" and 1 or -1
        local row = math.floor((k - 1) / 2)
        local ri = math.ceil(k / 2)
        if rigs[ri] == nil then rigs[ri] = makeRig() or false end
        local rig = rigs[ri]
        if rig then
            local pu = rig:FindFirstChild(side .. "UpperArm")
            local pl = rig:FindFirstChild(side .. "LowerArm")
            local ph = rig:FindFirstChild(side .. "Hand")
            if pu and pl and ph and pu:IsA("BasePart") and pl:IsA("BasePart") and ph:IsA("BasePart") then
                local lenU, lenL, lenH = pu.Size.Y, pl.Size.Y, ph.Size.Y
                arms[#arms + 1] = {
                    pu = pu, pl = pl, ph = ph,
                    -- pontos de junta REAIS (espaço local de cada peça)
                    uS = attPos(pu, side .. "ShoulderRigAttachment", Vector3.new(0, lenU / 2, 0)),
                    uE = attPos(pu, side .. "ElbowRigAttachment", Vector3.new(0, -lenU / 2, 0)),
                    lE = attPos(pl, side .. "ElbowRigAttachment", Vector3.new(0, lenL / 2, 0)),
                    lW = attPos(pl, side .. "WristRigAttachment", Vector3.new(0, -lenL / 2, 0)),
                    hW = attPos(ph, side .. "WristRigAttachment", Vector3.new(0, lenH / 2, 0)),
                    -- origem no corpo (espaço do tronco): ombros, peito e costas
                    -- Ponto de âncora no torso: lateral + altura escalonada por fileira.
                    -- O eixo Z (frente/trás) é controlado dinamicamente no step() pelo arco.
                    offset = Vector3.new(sign * (0.9 + (row % 2) * 0.25), 0.7 - row * 0.4, 0),
                    period = cfg.PeriodMin + spHash(k * 5.3) * (cfg.PeriodMax - cfg.PeriodMin),
                    phase = spHash(k * 9.1),
                    seed = k * 13,
                }
            end
        end
    end
    if #arms == 0 then
        warn("[BARRAGEM] não consegui montar nenhum braço extra")
        folder:Destroy()
        return ctrl
    end

    local t0 = os.clock()
    local tStop = nil
    local bindName = "BarrageExtraArms"
    local bound = false
    local stepError = nil

    local function cleanup()
        if bound then
            pcall(function() RunService:UnbindFromRenderStep(bindName) end)
            bound = false
        end
        folder:Destroy()
    end

    local function step()
        if not torso.Parent or not folder.Parent then
            cleanup()
            return
        end
        local now = os.clock()
        local t = now - t0

        -- ── Fade GLOBAL da barragem (aparece/some o conjunto todo) ──────────
        local globalFade
        if tStop then
            globalFade = 1 - math.clamp((now - tStop) / cfg.FadeOut, 0, 1)
            if globalFade <= 0 then cleanup(); return end
        else
            globalFade = math.clamp(t / cfg.FadeIn, 0, 1)
        end

        local torsoCF = torso.CFrame
        local R       = torsoCF.Rotation
        local forearm = math.rad(cfg.ForearmAngle)

        for _, a in ipairs(arms) do
            -- e: 0 = início do arco (atrás) → 1 = fim do arco (frente/alvo)
            local c   = t / a.period + a.phase
            local idx = math.floor(c)
            local e   = spPunch(c - idx)   -- curva suave 0→1 por arco

            -- ── Fade INDIVIDUAL do braço: aparece saindo, some chegando ──────
            local armFade
            local fi = cfg.ArmFadeIn  or 0.25
            local fo = cfg.ArmFadeOut or 0.25
            if e < fi then
                armFade = e / fi
            elseif e > (1 - fo) then
                armFade = (1 - e) / fo
            else
                armFade = 1
            end
            local tr = 1 - (armFade * globalFade)

            -- ── Direção do soco (leque frontal, muda a cada batida) ──────────
            local yaw   = (spHash(idx * 7  + a.seed)     * 2 - 1) * cfg.FanYaw
            local pitch = (spHash(idx * 11 + a.seed + 3) * 2 - 1) * cfg.FanPitch
            local dir   = R:VectorToWorldSpace(
                CFrame.Angles(math.rad(pitch), math.rad(yaw), 0).LookVector
            )

            -- ── Posição da ORIGEM do braço: arco de trás → frente ────────────
            -- Z vai de -ArcBack (atrás do torso) até +Reach (frente/alvo)
            -- com um "levantamento" suave no meio (ArcLift) para o efeito de gancho
            local arcBack  = cfg.ArcBack  or 1.4
            local arcLift  = cfg.ArcLift  or 0.5
            local arcTotal = arcBack + cfg.Reach

            local zArc = -arcBack + e * arcTotal                 -- trás → frente
            local yArc = math.sin(e * math.pi) * arcLift        -- curva de altura

            local anchorLocal = Vector3.new(a.offset.X, a.offset.Y + yArc, zArc)
            local S = (torsoCF * CFrame.new(anchorLocal)).Position

            -- ── Cotovelo: dobrado no começo e no fim, estendido no impacto ───
            -- No meio do arco (e≈0.5) o braço fica mais reto; na saída/chegada dobra
            local extendCurve = math.sin(e * math.pi)           -- 0→1→0
            local elbow = forearm * (1 - extendCurve * 0.85)   -- dobrado→reto→dobrado

            local Rd   = CFrame.lookAt(Vector3.zero, dir)
            local U    = (Rd * CFrame.Angles(-elbow * 0.4, 0, 0)).LookVector
            local L    = (Rd * CFrame.Angles( elbow * 0.6, 0, 0)).LookVector

            local rotU = CFrame.lookAt(Vector3.zero, U) * CFrame.Angles(math.rad(90), 0, 0)
            local rotL = CFrame.lookAt(Vector3.zero, L) * CFrame.Angles(math.rad(90), 0, 0)

            -- ── Encadeia pelas juntas reais: ombro → cotovelo → pulso ────────
            local posU = S - rotU * a.uS
            local E_pt = posU + rotU * a.uE
            local posL = E_pt - rotL * a.lE
            local W    = posL + rotL * a.lW
            local posH = W - rotL * a.hW

            a.pu.CFrame = CFrame.new(posU) * rotU
            a.pl.CFrame = CFrame.new(posL) * rotL
            a.ph.CFrame = CFrame.new(posH) * rotL
            a.pu.Transparency = tr
            a.pl.Transparency = tr
            a.ph.Transparency = tr
        end
    end

    -- roda DEPOIS da pose do Stand (prioridade acima do Last), pra não ficar atrasado em relação ao corpo
    RunService:BindToRenderStep(bindName, Enum.RenderPriority.Last.Value + 1, function()
        local ok, err = pcall(step)
        if not ok and not stepError then
            stepError = tostring(err)
            notify("ERRO nos braços: " .. stepError)
        end
    end)
    bound = true

    if cfg.Debug then
        task.delay(0.6, function()
            if not stepError then notify("braços extras: " .. #arms .. " | rigs: " .. #rigs .. " | pasta existe: " .. tostring(folder.Parent ~= nil)) end
        end)
    end

    ctrl.stop = function() if not tStop then tStop = os.clock() end end
    task.delay(30, ctrl.stop) -- trava de segurança
    return ctrl
end

-- Trilhas douradas nos punhos
local function attachBarrageTrails(stand)
    local list = {}
    for _, name in ipairs({ "RightHand", "LeftHand" }) do
        local hand = stand and stand:FindFirstChild(name)
        if hand and hand:IsA("BasePart") then
            local a0 = Instance.new("Attachment")
            a0.Name = "BarrageTrailA0"
            a0.Position = Vector3.new(0, 0.3, 0)
            a0.Parent = hand
            local a1 = Instance.new("Attachment")
            a1.Name = "BarrageTrailA1"
            a1.Position = Vector3.new(0, -0.3, 0)
            a1.Parent = hand
            local tr = Instance.new("Trail")
            tr.Name = "BarrageTrail"
            tr.Attachment0 = a0
            tr.Attachment1 = a1
            tr.Lifetime = 0.22
            tr.MinLength = 0
            tr.FaceCamera = true
            tr.LightEmission = 1
            tr.LightInfluence = 0
            tr.Color = ColorSequence.new(WORLD_GOLD_HOT, Color3.fromRGB(255, 170, 0))
            tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
            tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
            tr.Parent = hand
            list[#list + 1] = { a0, a1, tr }
        end
    end
    return list
end

local function cleanupBarrageTrails(list)
    for _, e in ipairs(list or {}) do
        pcall(function() e[3].Enabled = false end)
        for _, inst in ipairs(e) do Debris:AddItem(inst, 0.5) end
    end
end

-- Emissor de faíscas no alvo
local function createBarrageSparks(targetRoot)
    if not targetRoot then return nil end
    local att = Instance.new("Attachment")
    att.Name = "BarrageSparkAtt"
    att.Parent = targetRoot
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.Color = ColorSequence.new(WORLD_GOLD_HOT, WORLD_GOLD)
    pe.LightEmission = 1
    pe.Lifetime = NumberRange.new(0.25, 0.5)
    pe.Speed = NumberRange.new(20, 42)
    pe.SpreadAngle = Vector2.new(180, 180)
    pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
    pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
    pe.Rate = 0
    pe.Parent = att
    return att, pe
end

-- Anel de onda de choque virado na direção do golpe
local BARRAGE_RING_IMAGE = "rbxassetid://111807562120064"   -- 02_shockwave_anel

local function barrageRing(pos, dir, size, color)
    -- Placa fina invisível que só serve de "tela" pra textura do anel
    local r = Instance.new("Part")
    r.Shape = Enum.PartType.Block
    r.Anchored = true
    r.CanCollide = false
    r.CanQuery = false
    r.CanTouch = false
    r.CastShadow = false
    r.Transparency = 1
    r.Size = Vector3.new(1, 1, 0.05)
    r.CFrame = CFrame.lookAt(pos, pos + dir)   -- face da frente aponta na direção do golpe
    r.Parent = workspace

    -- Textura nos dois lados (o anel é visto de frente e de trás), tingida de dourado
    local labels = {}
    for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
        local sg = Instance.new("SurfaceGui")
        sg.Face = face
        sg.LightInfluence = 0
        sg.Brightness = 2.5
        sg.AlwaysOnTop = false
        sg.Parent = r
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Size = UDim2.fromScale(1, 1)
        img.Image = BARRAGE_RING_IMAGE
        img.ImageColor3 = color or WORLD_GOLD
        img.ImageTransparency = 0.05
        img.Parent = sg
        table.insert(labels, img)
    end

    local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(r, info, { Size = Vector3.new(size, size, 0.05) }):Play()
    for _, img in ipairs(labels) do
        TweenService:Create(img, info, { ImageTransparency = 1 }):Play()
    end
    Debris:AddItem(r, 0.45)
end

-- Flash dourado na tela (impacto do soco final)
local function barrageScreenFlash()
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local g = Instance.new("ScreenGui")
    g.Name = "BarrageFlash"
    g.IgnoreGuiInset = true
    g.ResetOnSpawn = false
    g.DisplayOrder = 500
    local f = Instance.new("Frame")
    f.Size = UDim2.fromScale(1, 1)
    f.BackgroundColor3 = WORLD_GOLD_HOT
    f.BackgroundTransparency = 0.35
    f.BorderSizePixel = 0
    f.Parent = g
    g.Parent = pg
    TweenService:Create(f, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 1 }):Play()
    Debris:AddItem(g, 0.4)
end

-- ============================================================
-- 👊 BARRAGEM = BARRAGE "MUDA MUDA MUDA" DO THE WORLD
-- A barragem inteira dura EXATAMENTE o tempo do som (BARRAGEM.SoundId):
-- pose, braços, câmera, dano e soco final são todos calculados em cima disso.
-- ============================================================
local function performBarragem()
	if not canUseStrict("Barragem") then return end
lockAbility("Barragem")  -- Bloqueia imediatamente
	if not isStandActive or not currentStand or isAttacking then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local targetRoot = getClosestTarget(12)
	if not targetRoot then
		showSpeechBubble(102362181377695, "right", 2.5)
		return
	end

	local targetHum = targetRoot.Parent:FindFirstChildOfClass("Humanoid")
	if not targetHum then
		isAttacking = false
		return
	end

	isAttacking = true

	-- ══════════════════════════════════════════════════════════════════
	-- 🏃 ANIMAÇÃO DE IDA: Stand avança até o alvo antes de começar a barragem
	-- ══════════════════════════════════════════════════════════════════
	do
		local sRootNow = currentStand and currentStand:FindFirstChild("HumanoidRootPart")
		if sRootNow and sRootNow.Parent then
			local tp = targetRoot.Position
			local rp = root.Position
			local flat = Vector3.new(tp.X - rp.X, 0, tp.Z - rp.Z)
			if flat.Magnitude > 0.05 then flat = flat.Unit else flat = root.CFrame.LookVector end

			-- Posição final de chegada (mesma fórmula do followConn)
			local arrivePos = tp - flat * 3.4 + Vector3.new(0, 1.5, 0)
			local arriveCF  = CFrame.lookAt(arrivePos, Vector3.new(tp.X, tp.Y + 1.5, tp.Z))

			-- Distância: se já estiver perto, dash bem rápido; se longe, um pouco mais lento
			local dist = (sRootNow.CFrame.Position - arrivePos).Magnitude
			local dashTime = math.clamp(dist * 0.028, 0.10, 0.28)

			-- Dash com Back easing: o Stand "puxa" levemente para trás antes de avançar
			TweenService:Create(sRootNow, TweenInfo.new(
				dashTime,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			), { CFrame = arriveCF }):Play()

			task.wait(dashTime)
		end
	end
	-- ══════════════════════════════════════════════════════════════════

	-- 🔊 Carrega o som e lê a duração REAL (a barragem inteira dura isso)
	local mudaSound = Instance.new("Sound")
	mudaSound.Name = "BarragemSound"
	mudaSound.SoundId = BARRAGEM.SoundId
	mudaSound.Volume = BARRAGEM.SoundVolume
	mudaSound.Parent = workspace
	local totalTime = BARRAGEM.getSoundLength(mudaSound)
	Debris:AddItem(mudaSound, totalTime + 2)

	-- O Stand pode ter sumido enquanto o som carregava
	local stand = currentStand
	if not stand or not stand.Parent or not isStandActive then
		mudaSound:Destroy()
		isAttacking = false
		return
	end

	cameraShake(totalTime, 0.5)
	showSpeechBubble(82682258182370, "left", totalTime, stand:FindFirstChild("Head"))

	local sRoot = stand:FindFirstChild("HumanoidRootPart")
	local sHum = stand:FindFirstChildOfClass("Humanoid")

	-- Corrige o rig antes de animar
	spFixRig(stand)

	if idleTrack and idleTrack.IsPlaying then idleTrack:Stop() end

	-- Animação do Dio (jogador)
	local playerBarrageTrack
	if hum and not isPlayerR6() then -- RIG 6: sem animação do jogador na Barragem
		playerBarrageTrack = playAnim(hum, ASSETS.PLAYER_BARRAGE, 1, not BARRAGEM.FitPlayerAnim, Enum.AnimationPriority.Action)
	end
	-- (opcional) estica a animação do Dio pra dar 1 passada exata na duração do som
	if playerBarrageTrack and BARRAGEM.FitPlayerAnim then
		task.spawn(function()
			local waited = 0
			while playerBarrageTrack.Length <= 0 and waited < 2 do waited += task.wait() end
			if playerBarrageTrack.Length > 0 and playerBarrageTrack.IsPlaying then
				playerBarrageTrack:AdjustSpeed(playerBarrageTrack.Length / totalTime)
			end
		end)
	end

	-- Animação do Stand: pose procedural (fallback para a animação antiga se o rig não tiver juntas)
	local state = { finishT0 = nil }
	local poseOk = StandPose.start(stand, spMakeBarrageEval(state))
	local barrageTrack
	if not poseOk and sHum then
		barrageTrack = playAnim(sHum, ASSETS.BARRAGE_ANIM, 2.5, true, Enum.AnimationPriority.Action)
	end

	-- ▶️ Som e relógio da barragem começam JUNTOS
	mudaSound:Play()
	local tStart = os.clock()
	local tEnd = tStart + totalTime                                   -- fim do som = fim da barragem
	local windup = SP_FINISHER_HIT_T                                  -- enrolar o corpo antes do soco final
	local loopTime = math.max(totalTime - windup - BARRAGEM.FollowThrough, BARRAGEM.MinLoopTime)
	local tLoopEnd = tStart + loopTime
	local dmgPerHit = BARRAGEM.TotalDamage / math.max(1, math.floor(loopTime / BARRAGEM.TickInterval))

	-- Stand cola no alvo, de frente, tremendo de tanta velocidade
	-- standDist  = distância horizontal do Stand até o alvo (studs)
	-- standLift  = quanto o Stand sobe ACIMA do HumanoidRootPart do alvo
	--              (HRP fica na cintura; +1.5 coloca o Stand na altura do torso/pescoço)
	local standDist, standLift = 3.4, 1.5
	local followConn = RunService.RenderStepped:Connect(function(dt)
		if not (sRoot and sRoot.Parent and targetRoot and targetRoot.Parent and root.Parent) then return end
		local rp, tp = root.Position, targetRoot.Position
		local flat = Vector3.new(tp.X - rp.X, 0, tp.Z - rp.Z)
		if flat.Magnitude > 0.05 then
			flat = flat.Unit
		else
			local lv = root.CFrame.LookVector
			flat = Vector3.new(lv.X, 0, lv.Z).Unit
		end
		local shake = Vector3.new(math.random() - 0.5, (math.random() - 0.5) * 0.6, math.random() - 0.5) * 0.22
		-- ✅ Altura baseada no alvo + standLift → Stand fica no torso/pescoço, não na cintura
		local pos = tp - flat * standDist + Vector3.new(0, standLift, 0) + shake
		local aimY = tp.Y + standLift   -- olha para a mesma altura que está posicionado
		local goal = CFrame.lookAt(pos, Vector3.new(tp.X, aimY, tp.Z))
		sRoot.CFrame = sRoot.CFrame:Lerp(goal, 1 - math.exp(-dt * 22))
	end)

	-- VFX contínuos: trilhas, faíscas e MUITOS BRAÇOS
	local trails = attachBarrageTrails(stand)
	local sparkAtt, sparks = createBarrageSparks(targetRoot)
	local arms = BARRAGEM.createArms(stand, targetRoot)

	local finisherFired = false -- 1 finisher por barrage
	local interrupted = false   -- alvo sumiu no meio (o som é cortado no fim)
	local i = 0
	while os.clock() < tLoopEnd do
		if not (targetRoot and targetRoot.Parent and targetHum and targetHum.Parent) then
			interrupted = true
			break
		end
		i += 1

		targetHum:TakeDamage(dmgPerHit)

		-- ========== VFX DE SANGUE ==========
		if i % 3 == 0 then
			EmitBloodVFX(targetRoot.Parent)
		end

		-- ========== VFX DO BARRAGE ==========
		if sparks then sparks:Emit(5) end
		if i % 6 == 0 then
			local dv = targetRoot.Position - root.Position
			if dv.Magnitude > 0.01 then barrageRing(targetRoot.Position, dv.Unit, 9, WORLD_GOLD) end
		end

		mudaComboCount = mudaComboCount + 1
		if mudaComboCount % 5 == 0 then
			showComboCounter()
		end

		if targetHum.Health <= FINISHER_HEALTH_THRESHOLD and not isFinisherActive and not finisherFired then
			finisherFired = true
			startFinisher(targetRoot)
		end

		-- Dio vira de frente pro alvo
		if root and root.Parent then
			local dir = (targetRoot.Position - root.Position)
			local flatDir = Vector3.new(dir.X, 0, dir.Z)
			if flatDir.Magnitude > 0.1 then
				flatDir = flatDir.Unit
				local targetLookCF = CFrame.lookAt(root.Position, root.Position + flatDir)
				root.CFrame = root.CFrame:Lerp(targetLookCF, 0.25)
			end
		end

		task.wait(BARRAGEM.TickInterval)
	end

	-- ========== SOCO FINAL: enrola o corpo e solta o golpe forte ==========
	-- ✅ FIX: braços extras somem ANTES do soco final, igual ao anime —
	-- só o braço principal do Stand aparece no impacto final.
	if arms then arms.stop() end

	if targetRoot and targetRoot.Parent and root and root.Parent then
		if poseOk then state.finishT0 = os.clock() - StandPose.t0 end
		standDist = 2.8 -- avança um pouco no golpe final
		task.wait(windup)

		if targetRoot and targetRoot.Parent then
			local dv = targetRoot.Position - root.Position
			local hitDir = dv.Magnitude > 0.01 and dv.Unit or root.CFrame.LookVector

			barrageRing(targetRoot.Position, hitDir, 18, WORLD_GOLD_HOT)
			barrageRing(targetRoot.Position, hitDir, 11, WORLD_GOLD)
			if sparks then sparks:Emit(28) end
			barrageScreenFlash()
			cameraShake(0.4, 1.6)
			cinematicZoom(0.5, 60)

			local att = Instance.new("Attachment", targetRoot)
			local vel = Instance.new("LinearVelocity", att)
			vel.MaxForce = math.huge
			vel.VectorVelocity = hitDir * 650 + Vector3.new(0, 220, 0)
			local rot = Instance.new("AngularVelocity", att)
			rot.MaxTorque = math.huge
			rot.AngularVelocity = Vector3.new(800, 1200, 800)
			Debris:AddItem(att, 0.8)
		end

		-- follow-through: espera o RESTO do som (a barragem termina junto com o áudio)
		task.wait(math.max(tEnd - os.clock(), 0.15))
	end

	task.delay(3, function()
		if isFinisherActive then
			endFinisher()
		end
	end)

	-- ========== LIMPEZA ==========
	StandPose.stop(STAND_POSE.FadeOut)
	if followConn then followConn:Disconnect() end
	if arms then arms.stop() end
	cleanupBarrageTrails(trails)
	if sparks then sparks.Enabled = false end
	if sparkAtt then Debris:AddItem(sparkAtt, 1) end

	if barrageTrack then barrageTrack:Stop() end
	if playerBarrageTrack then playerBarrageTrack:Stop() end
	if interrupted and mudaSound.Parent then mudaSound:Stop() end
	if sHum then idleTrack = playAnim(sHum, ASSETS.STAND_IDLE, 1, true, Enum.AnimationPriority.Idle) end

mudaComboCount = 0
if comboDisplay then
	comboDisplay:Destroy()
	comboDisplay = nil
end

	task.delay(0.6, function()
		if currentStand then
			local sRoot2 = currentStand:FindFirstChild("HumanoidRootPart")
			local root2  = character:FindFirstChild("HumanoidRootPart")
			if sRoot2 and root2 then
				-- ══════════════════════════════════════════════════════════════
				-- 🔙 ANIMAÇÃO DE VOLTA: Stand recua em dois tempos
				--   1) Puxa levemente para trás/cima (antecipação, 0.08s)
				--   2) Dash de volta à posição de descanso com Elastic (0.45s)
				-- ══════════════════════════════════════════════════════════════
				local homeCF = root2.CFrame * CFrame.new(STAND_OFFSET)

				-- Passo 1: leve recuo (antecipação)
				local pullbackCF = sRoot2.CFrame * CFrame.new(0, 0.6, -0.8)
				TweenService:Create(sRoot2, TweenInfo.new(
					0.08,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				), { CFrame = pullbackCF }):Play()

				task.wait(0.08)

				-- Passo 2: dash de volta com Elastic (pequeno "bounce" ao chegar)
				TweenService:Create(sRoot2, TweenInfo.new(
					0.45,
					Enum.EasingStyle.Back,
					Enum.EasingDirection.Out
				), { CFrame = homeCF }):Play()
			end
		end
		lastUsed["Barragem"] = tick()
		showCooldownOnButton(barragemBtn, "Barragem")
		isAttacking = false
	end)
end

-- ==================== FUNÇÃO DE ARREMESSO DE FACA CORRIGIDA ====================
local function performKnifeThrow()
    if not canUseStrict("Knife") then return end
    
    if isAttacking then return end
    
    lockAbility("Knife") 
    
    local isStandAttacking = (isStandActive and currentStand ~= nil)
    local attackerModel = isStandAttacking and currentStand or character
    local attackerRoot = attackerModel:FindFirstChild("HumanoidRootPart")
    local attackerHum = attackerModel:FindFirstChildOfClass("Humanoid")
    local charRoot = character:FindFirstChild("HumanoidRootPart")
    local camera = workspace.CurrentCamera
    
    if not attackerRoot or not attackerHum or not charRoot then return end
    
    local target = nil
    if isStandAttacking then 
        target = getClosestTarget(50) 
        if not target then 
            showSpeechBubble(102362181377695, "right", 2.5) 
            return 
        end 
    end
    
    isAttacking = true
    
    -- Direção do tiro
    local shootDir = (isStandAttacking and target) and (target.Position - attackerRoot.Position).Unit or camera.CFrame.LookVector
    
    -- ==================== LOOK AT PARA O PLAYER (QUANDO SEM STAND) ====================
    if not isStandAttacking then
        -- Player olha na direção do tiro (usando câmera)
        local lookTarget = charRoot.Position + Vector3.new(shootDir.X, 0, shootDir.Z).Unit * 10
        local lookCF = CFrame.lookAt(charRoot.Position, lookTarget)
        TweenService:Create(charRoot, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            CFrame = lookCF
        }):Play()
    end
    
    -- ==================== LOOK AT PARA O STAND (QUANDO COM STAND) ====================
    if isStandAttacking then
        local goalCF
        if target then
            local basePos = charRoot.Position + (target.Position - charRoot.Position).Unit * 3.8
            goalCF = CFrame.lookAt(basePos, target.Position)
        else
            goalCF = charRoot.CFrame * CFrame.new(0, 0, -3.8)
        end
        
        local tweenLook = TweenService:Create(attackerRoot, 
            TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), 
            {CFrame = goalCF}
        )
        tweenLook:Play()
        tweenLook.Completed:Wait()
    end
    
    -- ==================== ANIMAÇÃO PROCEDURAL (SEM ID) ====================
    -- Player = arremesso único | Stand = duas facas alternadas (variant do Stand)
    local cfg = KNIFE_ANIM.Player
    if isStandAttacking then
        local useLeft
        if STAND_KNIFE_MODE == "left" then
            useLeft = true
        elseif STAND_KNIFE_MODE == "right" then
            useLeft = false
        else
            useLeft = standKnifeNextLeft
            standKnifeNextLeft = not standKnifeNextLeft
        end
        cfg = useLeft and KNIFE_ANIM.StandL or KNIFE_ANIM.Stand
    end
    if isStandAttacking and idleTrack and idleTrack.IsPlaying then
        idleTrack:Stop(0.1)
    end
    local poseOk = StandPose.start(attackerModel, function(t)
        return spEvalFrames(cfg.frames, t)
    end, { player = not isStandAttacking })
    local poseStart = os.clock()

    -- facas visíveis na mão durante a preparação (somem na hora da soltura)
    local props = {}
    for i = 1, #cfg.release do
        local hand = getKnifeHand(attackerModel, i, cfg.leftFirst)
        if hand then
            local prop = Instance.new("Part")
            prop.Name = "DioKnifeProp"
            prop.Size = Vector3.new(1, 1, 1)
            prop.CanCollide = false
            prop.CanQuery = false
            prop.CanTouch = false
            prop.Massless = true
            prop.CFrame = hand.CFrame * CFrame.new(0, -0.45, 0) * knifeAlign(Vector3.new(0, -1, 0))
            prop.Parent = workspace
            applyKnifeMesh(prop)
            local pw = Instance.new("WeldConstraint")
            pw.Part0 = hand
            pw.Part1 = prop
            pw.Parent = prop
            Debris:AddItem(prop, 4)
            props[i] = prop
        end
    end

    local soundPlayed = false
    for i = 1, #cfg.release do
        -- espera o instante exato da soltura de cada faca
        local waitT = cfg.release[i] - (os.clock() - poseStart)
        if waitT > 0 then task.wait(waitT) end
        if not attackerModel.Parent then break end

        if props[i] then props[i]:Destroy() props[i] = nil end
        if i == 1 then pcall(cameraShake, 0.18, isStandAttacking and 0.8 or 0.55) end

        if not soundPlayed then
            soundPlayed = true
            local throwSoundId = isStandAttacking and ASSETS.KNIFE_THROW_STAND_SFX or ASSETS.KNIFE_THROW_DIO_SFX
            local throwSound = Instance.new("Sound", workspace)
            throwSound.SoundId = throwSoundId
            throwSound.Volume = isStandAttacking and 1.6 or 1.1
            throwSound:Play()
            Debris:AddItem(throwSound, 3)
        end

        if isStandAttacking and target and target.Parent and attackerRoot then
            shootDir = (target.Position - attackerRoot.Position).Unit
        end

        local knife = Instance.new("Part")
        knife.Name = "DioKnife"
        knife.Size = Vector3.new(1, 1, 1)
        knife.CanCollide = false
        knife.Parent = workspace

        -- a faca nasce na mão que está arremessando
        local hand = getKnifeHand(attackerModel, i, cfg.leftFirst)
        local origin = (hand and hand.Position or (attackerRoot.Position + Vector3.new(0, 0.6, 0))) + shootDir * 1.4
        local baseCFrame = CFrame.lookAt(origin, origin + shootDir)
        knife.CFrame = baseCFrame * knifeAlign(Vector3.new(0, 0, -1))

        applyKnifeMesh(knife)

        knife:SetAttribute("ShootDir", shootDir)

        -- Sistema de velocidade
        local velAttachment = Instance.new("Attachment", knife)
        local linearVel = Instance.new("LinearVelocity", knife)
        linearVel.Attachment0 = velAttachment
        linearVel.MaxForce = math.huge
        linearVel.VectorVelocity = shootDir * 295

        -- Se estiver em Time Stop, congela a faca
        if isTimeStopped then
            linearVel.Enabled = false
            knife.Anchored = true
            frozenKnives[knife] = {
                velocity = linearVel,
                direction = shootDir,
                attachment = velAttachment
            }
        else
            processKnifeMovement(knife, shootDir)
            Debris:AddItem(knife, 4.2)
        end
    end

    for _, pr in pairs(props) do if pr and pr.Parent then pr:Destroy() end end

    -- Finalização: deixa a pose terminar e volta pro estado normal
    local remaining = cfg.total - (os.clock() - poseStart)
    if remaining > 0 then task.wait(remaining) end
    if poseOk then StandPose.stop(STAND_POSE.FadeOut) end

    if isStandAttacking and attackerHum and attackerHum.Parent then
        idleTrack = playAnim(attackerHum, ASSETS.STAND_IDLE, 1, true, Enum.AnimationPriority.Idle)
    end

    lastUsed["Knife"] = tick()
    showCooldownOnButton(knifeBtn, "Knife")
    isAttacking = false
end

local function freezeCharacterOnSpawn(plr, char)
	if not isTimeStopped or plr == player then return end
	task.delay(0.2, function()
		if not char or not char.Parent or not isTimeStopped then return end
		for _, d in ipairs(char:GetDescendants()) do
			pcall(TimeFreeze.Process, d)
		end
	end)
end

for _, plr in ipairs(Players:GetPlayers()) do
	if plr ~= player then
		if plr.Character then freezeCharacterOnSpawn(plr, plr.Character) end
		plr.CharacterAdded:Connect(function(char) freezeCharacterOnSpawn(plr, char) end)
	end
end
Players.PlayerAdded:Connect(function(plr)
	if plr ~= player then plr.CharacterAdded:Connect(function(char) freezeCharacterOnSpawn(plr, char) end) end
end)

-- ==================== SISTEMA DE ANIMAÇÃO DO STAND (CORRIGIDO E ROBUSTO) ====================
local lastStandState = "Idle"  -- "Idle" ou "Walk"

RunService.RenderStepped:Connect(function()
	if not isStandActive or not currentStand or isAttacking then 
		return 
	end
	
	local root = character:FindFirstChild("HumanoidRootPart")
	local sRoot = currentStand:FindFirstChild("HumanoidRootPart")
	local sHum = currentStand:FindFirstChildOfClass("Humanoid")
	
	if not root or not sRoot or not sHum then return end
	
	-- Posicionamento suave do Stand
	local targetPos = root.CFrame * CFrame.new(STAND_OFFSET)
	sRoot.CFrame = sRoot.CFrame:Lerp(targetPos, 0.12)
	
	-- ====================== DETECÇÃO DE MOVIMENTO MELHORADA ======================
	local velocity = root.Velocity
	local horizSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	
	local shouldWalk = horizSpeed > 3.5   -- Threshold mais confiável
	
	if isAttacking then
		-- Durante ataque, força idle (ou deixa a animação de ataque assumir)
		if walkTrack and walkTrack.IsPlaying then
			walkTrack:Stop(0.2)
		end
		if (not idleTrack or not idleTrack.IsPlaying) and sHum then
			idleTrack = playAnim(sHum, ASSETS.STAND_IDLE, 1, true, Enum.AnimationPriority.Idle)
		end
		lastStandState = "Idle"
		return
	end
	
	-- ====================== CONTROLE DE ANIMAÇÕES ======================
	if shouldWalk then
		if lastStandState ~= "Walk" then
			lastStandState = "Walk"
			
			if idleTrack and idleTrack.IsPlaying then
				idleTrack:Stop(0.15)
			end
			
			if walkTrack then walkTrack:Stop(0) end
			walkTrack = playAnim(sHum, ASSETS.STAND_WALK, 1.5, true, Enum.AnimationPriority.Movement)
		end
	else
		-- Parado
		if lastStandState ~= "Idle" then
			lastStandState = "Idle"
			
			if walkTrack and walkTrack.IsPlaying then
				walkTrack:Stop(0.2)
			end
			
			if idleTrack then idleTrack:Stop(0) end
			idleTrack = playAnim(sHum, ASSETS.STAND_IDLE, 1, true, Enum.AnimationPriority.Idle)
		end
	end
end)

tsBtn.MouseButton1Click:Connect(toggleTime)
activateBtn.MouseButton1Click:Connect(toggleStand)
barragemBtn.MouseButton1Click:Connect(performBarragem)
knifeBtn.MouseButton1Click:Connect(performKnifeThrow)
roadBtn.MouseButton1Click:Connect(performRoadRoller)

-- ==================== COMANDOS DO CHAT ====================
player.Chatted:Connect(function(message)
    local msg = message:lower()
    
    if msg == "-changer" then
        -- Se já estiver aberto, FECHA
        if standChangerGui and standChangerGui.Parent then
            standChangerGui:Destroy()
            standChangerGui = nil
            print("🔒 Stand Changer fechado!")
        else
            -- Se não estiver aberto, ABRE
            createStandChangerGui()
            print("🔓 Stand Changer aberto!")
        end
    end
end)

task.spawn(function()
	local sequence = {COLORS.Yellow, COLORS.Black, COLORS.Green, COLORS.Black, COLORS.Purple, COLORS.Black}
	local i = 1
	while true do
		TweenService:Create(tsStroke, TweenInfo.new(0.7), {Color = sequence[i]}):Play()
		i = i % #sequence + 1 
		task.wait(0.7)
	end
end)

-- ==================== EFEITO VISUAL DE BLOQUEIO NOS BOTÕES ====================
local function applyClickEffect(b, baseSize, abilityName)
    b.MouseButton1Down:Connect(function()
        if abilityName and isAbilityLocked[abilityName] then
            -- Se bloqueado, treme o botão e não diminui
            TweenService:Create(b, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = b.Position + UDim2.new(0.02, 0, 0, 0)
            }):Play()
            task.wait(0.05)
            TweenService:Create(b, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = b.Position - UDim2.new(0.02, 0, 0, 0)
            }):Play()
            return
        end
        
        TweenService:Create(b, TweenInfo.new(0.1), {
            Size = UDim2.fromOffset(baseSize - 8, baseSize - 8)
        }):Play()
    end)
    
    b.MouseButton1Up:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.1), {
            Size = UDim2.fromOffset(baseSize, baseSize)
        }):Play()
    end)
end

applyClickEffect(tsBtn, 80, "TimeStop")
applyClickEffect(roadBtn, 70, "RoadRoller")
applyClickEffect(activateBtn, 95, nil)  -- Activate não tem cooldown
applyClickEffect(barragemBtn, 80, "Barragem")
knifeBtn.MouseButton1Down:Connect(function()
    if isAbilityLocked["Knife"] then
        -- Treme se bloqueado
        TweenService:Create(knifeBtn, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = knifeBtn.Position + UDim2.new(0.02, 0, 0, 0)
        }):Play()
        task.wait(0.05)
        TweenService:Create(knifeBtn, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = knifeBtn.Position - UDim2.new(0.02, 0, 0, 0)
        }):Play()
        return
    end
    
    local currentSize = knifeBtn.Size.X.Offset
    TweenService:Create(knifeBtn, TweenInfo.new(0.1), {
        Size = UDim2.fromOffset(currentSize - 8, currentSize - 8)
    }):Play()
end)

knifeBtn.MouseButton1Up:Connect(function()
    local isActive = isStandActive
    local targetSize = isActive and 70 or 80
    TweenService:Create(knifeBtn, TweenInfo.new(0.1), {
        Size = UDim2.fromOffset(targetSize, targetSize)
    }):Play()
end)

updateKnifePosition(false)

player.CharacterAdded:Connect(function(newChar) 
	character = newChar 
	hum = newChar:WaitForChild("Humanoid") 
	if isFinisherActive then
		endFinisher()
	end
end)

-- ═══════════════════════════════════════════
-- 🎒 SISTEMA DE ACESSÓRIOS (AQUI! ⬅️)
-- ═══════════════════════════════════════════
local IDS_CATALOGO = {
    113152323622992, 98776148420540, 14908061685,
}

local function AnexarTudo()
    local character = player.Character or player.CharacterAdded:Wait()
    
    -- Limpa os itens antigos que o script colocou
    for _, child in ipairs(character:GetChildren()) do
        if child:GetAttribute(ACCESSORY_TAG) then
            child:Destroy()
        end
    end
    
    for _, id in pairs(IDS_CATALOGO) do
        task.spawn(function()
            local sucesso, objects = pcall(function()
                return game:GetObjects("rbxassetid://" .. id)
            end)

            if sucesso and objects and objects[1] then
                local asset = objects[1]:Clone()
                
                -- Limpa scripts maliciosos do asset
                for _, v in pairs(asset:GetDescendants()) do
                    if v:IsA("LuaSourceContainer") then v:Destroy() end
                end

                asset:SetAttribute(ACCESSORY_TAG, true)

                -- 👕 SE FOR ROUPA (Shirt, Pants, T-Shirt)
                if asset:IsA("Shirt") or asset:IsA("Pants") or asset:IsA("ShirtGraphic") then
                    -- Remove a roupa padrão do personagem para a nova aparecer
                    for _, oldCloth in ipairs(character:GetChildren()) do
                        if oldCloth.ClassName == asset.ClassName then
                            oldCloth:Destroy()
                        end
                    end
                    -- Aplica a roupa nova no personagem
                    asset.Parent = character

                -- 🎒 SE FOR ACESSÓRIO (Chapéus, espadas, etc)
                else
                    local handle = asset:IsA("BasePart") and asset or asset:FindFirstChild("Handle", true)

                    if handle then
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
                                    if found then
                                        partAlvo = parte
                                        attachmentCorpo = found
                                        break
                                    end
                                end
                            end
                        end

                        if not partAlvo then
                            partAlvo = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
                        end

                        if partAlvo then
                            local weld = Instance.new("Weld")
                            weld.Name = "AutoWeld_" .. id
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
                end
                
                objects[1]:Destroy()
            end
        end)
    end
end

AnexarTudo()

player.CharacterAdded:Connect(function()
    task.wait(2) 
    AnexarTudo()
end)

 -- ==================== NOTIFICAÇÃO DE BOAS-VINDAS (SEM OVERLAY) ====================
if not hasShownNotification then
    hasShownNotification = true
    
    -- Container principal da notificação (fixo no centro, sem overlay)
    local notifFrame = Instance.new("Frame")
    notifFrame.Name = "NotifBox"
    notifFrame.Size = UDim2.fromOffset(400, 220)
    notifFrame.Position = UDim2.fromScale(0.5, 0.5)
    notifFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    notifFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    notifFrame.BorderSizePixel = 0
    notifFrame.ZIndex = 201
    notifFrame.ClipsDescendants = true
    notifFrame.Parent = screenGui  -- ⬅️ Direto no screenGui, sem overlay
    
    -- Gradiente de fundo (efeito de profundidade)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 35)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 15, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 15))
    }
    gradient.Rotation = 45
    gradient.Parent = notifFrame
    
    -- Borda dourada com brilho
    local border = Instance.new("UIStroke")
    border.Color = Color3.fromRGB(255, 215, 0)
    border.Thickness = 3
    border.Parent = notifFrame
    
    -- Brilho pulsante na borda
    local glowStroke = Instance.new("UIStroke")
    glowStroke.Color = Color3.fromRGB(255, 240, 150)
    glowStroke.Thickness = 1
    glowStroke.Transparency = 0.5
    glowStroke.Parent = notifFrame
    
    -- Cabeçalho decorativo
    local headerBar = Instance.new("Frame")
    headerBar.Size = UDim2.new(1, 0, 0, 40)
    headerBar.Position = UDim2.new(0, 0, 0, 0)
    headerBar.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    headerBar.BackgroundTransparency = 0.8
    headerBar.BorderSizePixel = 0
    headerBar.ZIndex = 202
    headerBar.Parent = notifFrame
    
    -- Linha dourada no topo
    local topLine = Instance.new("Frame")
    topLine.Size = UDim2.new(0.8, 0, 0, 2)
    topLine.Position = UDim2.new(0.1, 0, 0, 38)
    topLine.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    topLine.BorderSizePixel = 0
    topLine.ZIndex = 203
    topLine.Parent = notifFrame
    
    -- Ícone/Imagem com efeito de rotação na entrada
    local imageContainer = Instance.new("Frame")
    imageContainer.Size = UDim2.fromOffset(70, 70)
    imageContainer.Position = UDim2.new(0.5, -35, 0, 55)
    imageContainer.BackgroundTransparency = 1
    imageContainer.ZIndex = 202
    imageContainer.Parent = notifFrame
    
    local imageLabel = Instance.new("ImageLabel")
    imageLabel.Size = UDim2.fromScale(1, 1)
    imageLabel.Position = UDim2.fromScale(0, 0)
    imageLabel.BackgroundTransparency = 1
    imageLabel.Image = "rbxassetid://107647236597557"
    imageLabel.ScaleType = Enum.ScaleType.Fit
    imageLabel.ZIndex = 203
    imageLabel.Parent = imageContainer
    
    -- Título com efeito de brilho
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.85, 0, 0, 25)
    titleLabel.Position = UDim2.new(0.075, 0, 0, 120)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "⭐ SCRIPT DIO BRANDO ⭐"
    titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    titleLabel.Font = Enum.Font.Bangers
    titleLabel.TextSize = 20
    titleLabel.TextStrokeTransparency = 0
    titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    titleLabel.ZIndex = 202
    titleLabel.Parent = notifFrame
    
    -- Mensagem
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(0.85, 0, 0, 60)
    messageLabel.Position = UDim2.new(0.075, 0, 0, 155)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = "By mynameis909 👑 • Mahoawaga VFX 🌟✨ • eusouoamendobobo ⭐ https://discord.gg/K66SwwY98h • https://discord.gg/tfujC5pTp "
    messageLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    messageLabel.Font = Enum.Font.SourceSans
    messageLabel.TextSize = 16
    messageLabel.TextWrapped = true
    messageLabel.ZIndex = 202
    messageLabel.Parent = notifFrame
    
    -- Partículas decorativas de fundo (efeito premium)
    for i = 1, 8 do
        local particle = Instance.new("Frame")
        particle.Size = UDim2.fromOffset(math.random(4, 8), math.random(4, 8))
        particle.Position = UDim2.fromScale(math.random(), math.random())
        particle.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
        particle.BackgroundTransparency = 0.7
        particle.BorderSizePixel = 0
        particle.ZIndex = 201
        particle.Parent = notifFrame
        
        spawn(function()
            while particle and particle.Parent do
                TweenService:Create(particle, TweenInfo.new(math.random(2, 4)), {
                    Position = UDim2.fromScale(math.random(), math.random()),
                    BackgroundTransparency = 0.9
                }):Play()
                task.wait(math.random(2, 4))
            end
        end)
    end
    
    -- ===== ANIMAÇÃO DE ENTRADA (EXPANSÃO ÉPICA) =====
    
    -- Frame começa esmagado (achatado verticalmente)
    notifFrame.Size = UDim2.fromOffset(450, 0.01)
    notifFrame.BackgroundTransparency = 1
    
    -- Expansão espetacular
    local entrySequence = function()
        -- Fade-in rápido do background
        TweenService:Create(notifFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0
        }):Play()
        
        -- Expansão vertical com overshoot (efeito elástico)
        TweenService:Create(notifFrame, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(400, 220)
        }):Play()
        
        -- Rotação do ícone na entrada
        imageContainer.Rotation = -180
        TweenService:Create(imageContainer, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Rotation = 0
        }):Play()
        
        -- Título aparece com delay (stagger effect)
        titleLabel.TextTransparency = 1
        task.delay(0.15, function()
            TweenService:Create(titleLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                TextTransparency = 0
            }):Play()
        end)
        
        -- Mensagem aparece com mais delay
        messageLabel.TextTransparency = 1
        task.delay(0.3, function()
            TweenService:Create(messageLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                TextTransparency = 0
            }):Play()
        end)
        
        -- Brilho pulsante contínuo
        spawn(function()
            while notifFrame and notifFrame.Parent do
                TweenService:Create(glowStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                    Transparency = 0.8
                }):Play()
                task.wait(1.5)
                TweenService:Create(glowStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                    Transparency = 0.2
                }):Play()
                task.wait(1.5)
            end
        end)
    end
    
    entrySequence()
    
    -- ===== ANIMAÇÃO DE SAÍDA (ESMAGAMENTO) =====
    
    task.delay(4, function()
        if not notifFrame or not notifFrame.Parent then return end
        
        -- Efeito de "sugar" tudo antes de esmagar
        local suckEffect = function()
            -- Título e mensagem desaparecem primeiro
            TweenService:Create(titleLabel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                TextTransparency = 1
            }):Play()
            
            TweenService:Create(messageLabel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                TextTransparency = 1
            }):Play()
            
            -- Ícone encolhe e gira
            task.delay(0.1, function()
                TweenService:Create(imageContainer, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Size = UDim2.fromOffset(0, 0),
                    Rotation = 180
                }):Play()
            end)
            
            -- Header e linha dourada desaparecem
            TweenService:Create(headerBar, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                BackgroundTransparency = 1
            }):Play()
            
            TweenService:Create(topLine, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 0, 0, 2),
                BackgroundTransparency = 1
            }):Play()
        end
        
        suckEffect()
        
        -- ESMAGAMENTO: frame colapsa verticalmente (efeito de prensa)
        task.delay(0.2, function()
            -- Borda perde a cor
            TweenService:Create(border, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Color = Color3.fromRGB(100, 50, 0),
                Thickness = 0
            }):Play()
            
            TweenService:Create(glowStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Transparency = 1,
                Thickness = 0
            }):Play()
            
            -- Esmagamento brutal: altura vai a zero, largura aumenta levemente
            TweenService:Create(notifFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                Size = UDim2.fromOffset(600, 0.01),
                BackgroundTransparency = 0.5
            }):Play()
        end)
        
        -- Destruição final após animação completa
        task.delay(0.7, function()
            if notifFrame and notifFrame.Parent then
                notifFrame:Destroy()
            end
        end)
    end)
end

-- ============================================================

player.CharacterRemoving:Connect(function()
    if customStandUserId then
        salvarStandId(customStandUserId)
        print("💾 ID do Stand salvo ao remover personagem!")
    end
end)

-- Salvamento extra quando o script é destruído
script.AncestryChanged:Connect(function()
    if not script.Parent then
        if customStandUserId then
            salvarStandId(customStandUserId)
            print("💾 Backup de emergência: ID salvo!")
        end
    end
end)
