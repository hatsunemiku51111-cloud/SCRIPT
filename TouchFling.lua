--==================================================
-- TOUCH FLING + ANTI FALL DAMAGE
-- Fling: o MEU boneco carrega a velocidade, so quando encosta/atravessa alguem
-- Anti Fall: automatico desde o boot, todo respawn
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

local burstFrames        = 0
local antiFallConnection = nil
local touchConns         = {}

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
-- ANTI FALL + FLING (mesmo loop, para um nao brigar com o outro)
-- Sem contato: o servidor ve velocidade zero (anti queda).
-- Com contato: o servidor ve a velocidade enorme (fling).
-- A fisica local sempre recebe a velocidade real de volta.
--==================================================

local function startAntiFall(char)
    if not char then return end

    local root = char:FindFirstChild("HumanoidRootPart")
        or char:WaitForChild("HumanoidRootPart", 5)
    if not root then return end

    if antiFallConnection then
        antiFallConnection:Disconnect()
        antiFallConnection = nil
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

        local vel    = root.AssemblyLinearVelocity
        local angVel = root.AssemblyAngularVelocity

        if burstFrames > 0 then
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

    antiFallConnection = con
end

--==================================================
-- BOOT / RESPAWN
--==================================================

local function onCharacter(char)
    burstFrames = 0
    hookCharacter(char)
    startAntiFall(char)
end

if player.Character then
    onCharacter(player.Character)
end

player.CharacterAdded:Connect(onCharacter)
