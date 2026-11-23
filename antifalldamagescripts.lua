local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local antiFallEnabled = false
local antiFallConnection = nil

local function protect(char)
	if not antiFallEnabled then return end
	if game.PlaceId ~= 189707 then return end -- Só funciona no Natural Disaster Survival
	if not char then return end

	local root = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5)
	if not root then return end

	if antiFallConnection then
		antiFallConnection:Disconnect()
		antiFallConnection = nil
	end

	local hb = RunService.Heartbeat
	local rsd = RunService.RenderStepped
	local zero = Vector3.zero

	local con
	con = hb:Connect(function()
		if not antiFallEnabled or not root or not root.Parent then
			if con then con:Disconnect() end
			return
		end

		local vel = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = zero
		rsd:Wait()
		root.AssemblyLinearVelocity = vel
	end)

	antiFallConnection = con
end

-- Menu de ativação
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
	protect(player.Character)
	if antiFallMenu then antiFallMenu:Destroy() end
end)

btnNao.MouseButton1Click:Connect(function()
	antiFallEnabled = false
	if antiFallConnection then
		antiFallConnection:Disconnect()
		antiFallConnection = nil
	end
	if antiFallMenu then antiFallMenu:Destroy() end
end)

-- Aplica no personagem atual e em todos os respawns
if player.Character then
	protect(player.Character)
end

player.CharacterAdded:Connect(function(char)
	if antiFallEnabled then
		protect(char)
	end
end)
