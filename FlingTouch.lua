--==================================================
-- AUTO PROXIMITY FLING + ANTI FALL DAMAGE
-- Detecção: posição visual (RenderStepped) + Touched
-- Platform: Roblox | LocalScript
--==================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local DETECT_RADIUS     = 5
local POWER_MULT        = 20000000000
local HIT_FRAMES        = 6
local FLING_COOLDOWN    = 1.5   -- segundos entre flings no mesmo alvo

local activeFlings  = {}
local lastFlingTime = {}

local antiFallConnection = nil

--==================================================
-- ANTI FALL DAMAGE
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
        local vel = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = zero
        RunService.RenderStepped:Wait()
        root.AssemblyLinearVelocity = vel
    end)

    antiFallConnection = con
end

if player.Character then
    startAntiFall(player.Character)
end

player.CharacterAdded:Connect(function(char)
    startAntiFall(char)
end)

--==================================================
-- FLING
--==================================================

local function doFling(targetPlayer)
    local char       = player.Character
    local targetChar = targetPlayer.Character
    if not char or not targetChar then return end

    local hrp       = char:FindFirstChild("HumanoidRootPart")
    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
    local hum       = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not targetHrp or not hum then return end

    -- cooldown por alvo
    local now = tick()
    if lastFlingTime[targetPlayer] and (now - lastFlingTime[targetPlayer]) < FLING_COOLDOWN then
        return
    end
    lastFlingTime[targetPlayer] = now

    activeFlings[targetPlayer] = true
    local originCFrame = hrp.CFrame

    local savedSpeed    = hum.WalkSpeed
    local savedJump     = hum.JumpPower
    local savedAutoJump = hum.AutoJumpEnabled

    local savedCollision = {}
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then
            savedCollision[part] = part.CanCollide
            part.CanCollide = false
        end
    end
    hrp.CanCollide = true

    local frame = 0
    local conn
    conn = RunService.PostSimulation:Connect(function()
        local hrpOk  = hrp and hrp.Parent
        local tHrpOk = targetHrp and targetHrp.Parent

        if not hrpOk or not tHrpOk then
            conn:Disconnect()
            activeFlings[targetPlayer] = nil
            return
        end

        if frame < HIT_FRAMES then
            local nudge = frame % 2 == 0 and 0.01 or -0.01
            hrp.CFrame = CFrame.new(
                targetHrp.Position + Vector3.new(nudge, 0, nudge)
            )

            local sign = frame % 2 == 0 and 1 or -1
            targetHrp.AssemblyLinearVelocity = Vector3.new(
                POWER_MULT * sign,
                POWER_MULT,
                POWER_MULT * -sign
            )
            targetHrp.AssemblyAngularVelocity = Vector3.new(
                POWER_MULT * -sign,
                POWER_MULT * sign,
                POWER_MULT
            )
            frame += 1
        else
            conn:Disconnect()

            hrp.CFrame = originCFrame
            task.wait()
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero

            for part, col in pairs(savedCollision) do
                if part and part.Parent then
                    part.CanCollide = col
                end
            end

            hum.WalkSpeed       = savedSpeed
            hum.JumpPower       = savedJump
            hum.AutoJumpEnabled = savedAutoJump
            hum:ChangeState(Enum.HumanoidStateType.Running)

            task.delay(FLING_COOLDOWN, function()
                activeFlings[targetPlayer] = nil
            end)
        end
    end)
end

--==================================================
-- DETECTOR VISUAL (RenderStepped = posição renderizada)
--==================================================

RunService.RenderStepped:Connect(function()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, p in ipairs(Players:GetPlayers()) do
        if p == player then continue end
        if activeFlings[p] then continue end

        local tChar = p.Character
        if not tChar then continue end
        local tHrp = tChar:FindFirstChild("HumanoidRootPart")
        if not tHrp then continue end

        -- posição visual do alvo (client-side interpolated)
        local dist = (hrp.Position - tHrp.Position).Magnitude
        if dist <= DETECT_RADIUS then
            doFling(p)
        end
    end
end)

--==================================================
-- DETECTOR POR TOQUE FÍSICO (Touched — backup)
-- dispara quando qualquer parte do seu char toca
-- qualquer parte do char remoto visualmente
--==================================================

local function hookTouched(char)
    for _, part in ipairs(char:GetDescendants()) do
        if not part:IsA("BasePart") then continue end
        part.Touched:Connect(function(hit)
            if not hit or not hit.Parent then return end
            local targetChar = hit.Parent
            local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
            if not targetPlayer or targetPlayer == player then return end
            if activeFlings[targetPlayer] then return end
            doFling(targetPlayer)
        end)
    end
end

if player.Character then
    hookTouched(player.Character)
end

player.CharacterAdded:Connect(function(char)
    char:WaitForChild("HumanoidRootPart")
    hookTouched(char)
end)
