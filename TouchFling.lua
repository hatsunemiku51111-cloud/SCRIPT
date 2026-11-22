--==================================================
-- TOUCH FLING + ANTI FALL DAMAGE (com menu SIM/NAO)
-- Fling: o MEU boneco carrega a velocidade, so quando encosta/atravessa alguem
-- Anti Fall: ligado pelo menu, todo respawn (so no PlaceId configurado)
-- Platform: Roblox | LocalScript
--==================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")

local player = Players.LocalPlayer

local POWER_MULT       = 20000000000
local HIT_FRAMES       = 6      -- frames de fling depois do ultimo contato
local USE_OVERLAP_POLL = true   -- detecta atravessar/overlap mesmo sem evento Touched
local OVERLAP_MARGIN   = 0.5    -- studs de antecipacao: o fling ja esta ligado quando o corpo encosta (0 = so no contato exato)

local ANTI_FALL_PLACE_ID = 189707 -- Natural Disaster Survival (do script original). nil = anti fall em qualquer jogo

local burstFrames        = 0
local antiFallEnabled    = false
local velocityConnection = nil
local touchConns         = {}

local function antiFallActive()
    return antiFallEnabled
        and (ANTI_FALL_PLACE_ID == nil or game.PlaceId == ANTI_FALL_PLACE_ID)
end

--==================================================
-- DETECCAO
--==================================================

local function isOtherPlayerPart(part)
    local model = part:FindFirstAncestorOfClass("Model")
    if not model then return false end
    local p = Players:GetPlayerFromCharacter(model)
    return p ~= nil and p ~= player
end

local function triggerBurst()
    burstFrames = math.max(burstFrames, HIT_FRAMES)
end

-- 1) Touched: encostar / atravessar em movimento
local function onTouched(other)
    if isOtherPlayerPart(other) then
        triggerBurst()
    end
end

local function hookCharacter(char)
    for _, c in ipairs(touchConns) do
        c:Disconnect()
    end
    table.clear(touchConns)

    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then
            table.insert(touchConns, d.Touched:Connect(onTouched))
        end
    end

    table.insert(touchConns, char.DescendantAdded:Connect(function(d)
        if d:IsA("BasePart") then
            table.insert(touchConns, d.Touched:Connect(onTouched))
        end
    end))
end

-- 2) Overlap com margem: roda DENTRO do loop de velocidade (mesmo frame),
--    entao o fling liga antes do contato, sem esperar o proximo frame
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

local function isTouchingOthers(char)
    local others = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            table.insert(others, p.Character)
        end
    end
    if #others == 0 then return false end

    overlapParams.FilterDescendantsInstances = others
    local pad = Vector3.one * (OVERLAP_MARGIN * 2)

    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then
            if #Workspace:GetPartBoundsInBox(part.CFrame, part.Size + pad, overlapParams) > 0 then
                return true
            end
        end
    end
    return false
end

--==================================================
-- LOOP DE VELOCIDADE (fling + anti fall no mesmo loop)
-- Com contato: o servidor ve a velocidade enorme (fling) - sempre ativo.
-- Sem contato + anti fall ligado: o servidor ve velocidade zero.
-- Sem contato + anti fall desligado: nao mexe em nada.
-- A fisica local sempre recebe a velocidade real de volta.
--==================================================

local function startVelocityLoop(char)
    if not char then return end

    local root = char:FindFirstChild("HumanoidRootPart")
        or char:WaitForChild("HumanoidRootPart", 5)
    if not root then return end

    if velocityConnection then
        velocityConnection:Disconnect()
        velocityConnection = nil
    end

    local zero = Vector3.zero
    local con
    con = RunService.Heartbeat:Connect(function()
        if not root or not root.Parent then
            con:Disconnect()
            return
        end

        if USE_OVERLAP_POLL and isTouchingOthers(char) then
            triggerBurst()
        end

        local bursting = burstFrames > 0
        if not bursting and not antiFallActive() then
            return
        end

        local vel    = root.AssemblyLinearVelocity
        local angVel = root.AssemblyAngularVelocity

        if bursting then
            local sign = burstFrames % 2 == 0 and 1 or -1
            root.AssemblyLinearVelocity = Vector3.new(
                POWER_MULT * sign,
                POWER_MULT,
                POWER_MULT * -sign
            )
            root.AssemblyAngularVelocity = Vector3.new(
                POWER_MULT * -sign,
                POWER_MULT * sign,
                POWER_MULT
            )
            burstFrames -= 1
        else
            root.AssemblyLinearVelocity = zero
        end

        RunService.RenderStepped:Wait()
        root.AssemblyLinearVelocity  = vel
        root.AssemblyAngularVelocity = angVel
    end)

    velocityConnection = con
end

--==================================================
-- BOOT / RESPAWN (o fling funciona desde o inicio, antes do menu)
--==================================================

local function onCharacter(char)
    burstFrames = 0
    hookCharacter(char)
    startVelocityLoop(char)
end

if player.Character then
    onCharacter(player.Character)
end

player.CharacterAdded:Connect(onCharacter)

--==================================================
-- MENU DE ATIVACAO DO ANTI FALL
--==================================================

task.spawn(function()
    local antiFallMenu = Instance.new("ScreenGui")
    antiFallMenu.Name = "AntiFallChoiceMenu"
    antiFallMenu.ResetOnSpawn = false
    antiFallMenu.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    antiFallMenu.Parent = player:WaitForChild("PlayerGui")

    local menuFrame = Instance.new("Frame")
    menuFrame.Size = UDim2.new(0, 300, 0, 180)
    menuFrame.Position = UDim2.new(0.5, -150, 0.5, -90)
    menuFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    menuFrame.BorderSizePixel = 0
    menuFrame.Parent = antiFallMenu

    local menuCorner = Instance.new("UICorner")
    menuCorner.CornerRadius = UDim.new(0, 12)
    menuCorner.Parent = menuFrame

    local menuStroke = Instance.new("UIStroke")
    menuStroke.Color = Color3.fromRGB(50, 150, 255)
    menuStroke.Thickness = 2
    menuStroke.Parent = menuFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 40)
    title.Position = UDim2.new(0, 10, 0, 15)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "Ativar Anti Fall Damage?"
    title.Parent = menuFrame

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -20, 0, 40)
    desc.Position = UDim2.new(0, 10, 0, 55)
    desc.BackgroundTransparency = 1
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 13
    desc.TextColor3 = Color3.fromRGB(180, 180, 180)
    desc.Text = "Se ativado, protege de fall damage\nem todo respawn (apenas NDS)"
    desc.TextWrapped = true
    desc.Parent = menuFrame

    local btnSim = Instance.new("TextButton")
    btnSim.Size = UDim2.new(0, 120, 0, 40)
    btnSim.Position = UDim2.new(0, 20, 1, -55)
    btnSim.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
    btnSim.Font = Enum.Font.GothamBold
    btnSim.TextSize = 16
    btnSim.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnSim.Text = "SIM"
    btnSim.Parent = menuFrame

    local simCorner = Instance.new("UICorner")
    simCorner.CornerRadius = UDim.new(0, 8)
    simCorner.Parent = btnSim

    local btnNao = Instance.new("TextButton")
    btnNao.Size = UDim2.new(0, 120, 0, 40)
    btnNao.Position = UDim2.new(1, -140, 1, -55)
    btnNao.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
    btnNao.Font = Enum.Font.GothamBold
    btnNao.TextSize = 16
    btnNao.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnNao.Text = "NÃO"
    btnNao.Parent = menuFrame

    local naoCorner = Instance.new("UICorner")
    naoCorner.CornerRadius = UDim.new(0, 8)
    naoCorner.Parent = btnNao

    btnSim.MouseButton1Click:Connect(function()
        antiFallEnabled = true
        antiFallMenu:Destroy()
    end)

    btnNao.MouseButton1Click:Connect(function()
        antiFallEnabled = false
        antiFallMenu:Destroy()
    end)
end)
