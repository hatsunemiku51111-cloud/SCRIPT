local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

if not game:IsLoaded() then game.Loaded:Wait() end

local player = Players.LocalPlayer
while not player do
	task.wait()
	player = Players.LocalPlayer
end

-- =========================================================
-- UNIVERSAL: compatibilidade com qualquer jogo / executor
-- =========================================================
local UNIVERSAL = {
	-- true  = GUI fora do PlayerGui (gethui/CoreGui): sobrevive a jogos que limpam/escondem a UI
	-- false = GUI no PlayerGui normal (use se os botoes nao responderem no seu executor)
	UseHiddenGui = true,
}

local scriptAlive = true
local PGState = { rebuilds = 0, cur = nil, cleanup = nil }
local rootConns = {}
local antiFallMenuRef = nil
local safeSetup = nil -- definido no final do arquivo

local function warnPG(...)
	pcall(warn, "[PortalGun]", ...)
end

local function trackRoot(c)
	rootConns[#rootConns + 1] = c
	return c
end

-- instancia unica: reexecutar o script limpa a versao anterior
local genv = _G
do
	local okG, e = pcall(function() return getgenv() end)
	if okG and type(e) == "table" then genv = e end
end
if type(genv.__PortalGunCleanup) == "function" then
	pcall(genv.__PortalGunCleanup)
end

local function getGuiParent()
	if UNIVERSAL.UseHiddenGui then
		local okH, hui = pcall(function() return gethui and gethui() end)
		if okH and typeof(hui) == "Instance" then return hui end
		local okC, core = pcall(function() return game:GetService("CoreGui") end)
		if okC and core then
			local probe = Instance.new("Folder")
			local okP = pcall(function() probe.Parent = core end)
			pcall(function() probe:Destroy() end)
			if okP then return core end
		end
	end
	return player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 15)
end

local function parentGui(g)
	local p = getGuiParent()
	if p then pcall(function() g.Parent = p end) end
	if not g.Parent then
		local pg = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 15)
		if pg then pcall(function() g.Parent = pg end) end
	end
	return g.Parent ~= nil
end

-- lista de ignorados sem buracos (um nil no meio de {a, nil, b} cortava o resto do filtro)
local function buildIgnore(...)
	local t = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if typeof(v) == "Instance" then t[#t + 1] = v end
	end
	return t
end

-- raycast que atravessa partes invisiveis (zonas, hitboxes, barreiras) e ignora agua
local function castSolid(origin, direction, ignoreList)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local ignore = {}
	for i, v in ipairs(ignoreList) do ignore[i] = v end
	params.FilterDescendantsInstances = ignore
	for _ = 1, 10 do
		local result = workspace:Raycast(origin, direction, params)
		if not result then return nil end
		local inst = result.Instance
		if inst and inst.ClassName ~= "Terrain" and inst:IsA("BasePart") and inst.Transparency >= 0.95 then
			ignore[#ignore + 1] = inst
			params.FilterDescendantsInstances = ignore
		else
			return result
		end
	end
	return nil
end

local function isFiniteVec3(v)
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and math.abs(v.X) < 1e7 and math.abs(v.Y) < 1e7 and math.abs(v.Z) < 1e7
end

local function loadTrack(animator, anim)
	if not animator or not animator.Parent then return nil end
	local okT, track = pcall(function() return animator:LoadAnimation(anim) end)
	if okT then return track end
	return nil
end

-- =========================================================
-- UI THEME / HELPERS (visual redesign)
-- =========================================================
local Theme = {
	Bg = Color3.fromRGB(10, 13, 20),
	BgTop = Color3.fromRGB(26, 33, 49),
	Text = Color3.fromRGB(232, 238, 248),
	Muted = Color3.fromRGB(120, 134, 158),
}

-- Borda com gradiente girando (efeito "tech"). Chamar de novo só troca a cor.
local function tintStroke(stroke, color, animate)
	local g = stroke:FindFirstChildOfClass("UIGradient")
	if not g then
		g = Instance.new("UIGradient")
		g.Parent = stroke
		if animate then
			TweenService:Create(g, TweenInfo.new(3.2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {Rotation = 360}):Play()
		end
	end
	local dim = color:Lerp(Color3.new(0, 0, 0), 0.8)
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(0.5, dim),
		ColorSequenceKeypoint.new(1, color),
	})
	stroke.Color = color
end

local function glassGradient(parent)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Theme.BgTop, Theme.Bg)
	g.Rotation = 90
	g.Parent = parent
	return g
end

-- Variáveis globais para limpar GUIs ao respawnar
local currentPortalGunGui = nil
local currentHotbarGui = nil

-- =========================================================
-- ANTI FALL DAMAGE (APENAS NATURAL DISASTER SURVIVAL)
-- =========================================================
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


-- Menu de ativação do Anti Fall (UI redesenhada) - só aparece no Natural Disaster Survival
if game.PlaceId == 189707 then
local antiFallMenu = Instance.new("ScreenGui")
antiFallMenu.Name = "AntiFallChoiceMenu"
antiFallMenu.ResetOnSpawn = false
antiFallMenu.IgnoreGuiInset = true
antiFallMenu.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
parentGui(antiFallMenu)
antiFallMenuRef = antiFallMenu

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 1
backdrop.BorderSizePixel = 0
backdrop.Parent = antiFallMenu

local menuFrame = Instance.new("CanvasGroup")
menuFrame.AnchorPoint = Vector2.new(0.5, 0.5)
menuFrame.Size = UDim2.fromOffset(340, 210)
menuFrame.Position = UDim2.fromScale(0.5, 0.5)
menuFrame.BackgroundColor3 = Color3.new(1, 1, 1)
menuFrame.BorderSizePixel = 0
menuFrame.GroupTransparency = 1
menuFrame.Parent = backdrop
glassGradient(menuFrame)
Instance.new("UICorner", menuFrame).CornerRadius = UDim.new(0, 16)

local menuScale = Instance.new("UIScale")
menuScale.Scale = 0.88
menuScale.Parent = menuFrame

local menuStroke = Instance.new("UIStroke")
menuStroke.Thickness = 2
menuStroke.Parent = menuFrame
tintStroke(menuStroke, Color3.fromRGB(50, 150, 255), true)

local function makeLabel(parent, text, font, size, color, pos, sz, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.Position = pos
	l.Size = sz
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	l.Parent = parent
	return l
end

makeLabel(menuFrame, "// ANTI-FALL MODULE", Enum.Font.Code, 11, Color3.fromRGB(80, 170, 255), UDim2.fromOffset(22, 18), UDim2.new(1, -60, 0, 14))
makeLabel(menuFrame, "Anti Fall Damage", Enum.Font.GothamBlack, 22, Theme.Text, UDim2.fromOffset(22, 38), UDim2.new(1, -44, 0, 28))
makeLabel(menuFrame, "Protege você do dano de queda a cada respawn.\nDisponível apenas no Natural Disaster Survival.", Enum.Font.Gotham, 12, Theme.Muted, UDim2.fromOffset(22, 72), UDim2.new(1, -44, 0, 34))

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.fromOffset(8, 8)
statusDot.Position = UDim2.new(1, -30, 0, 21)
statusDot.BackgroundColor3 = Color3.fromRGB(0, 220, 150)
statusDot.BorderSizePixel = 0
statusDot.Parent = menuFrame
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)
TweenService:Create(statusDot, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.7}):Play()

local divider = Instance.new("Frame")
divider.Position = UDim2.fromOffset(22, 122)
divider.Size = UDim2.new(1, -44, 0, 1)
divider.BackgroundColor3 = Color3.new(1, 1, 1)
divider.BackgroundTransparency = 0.88
divider.BorderSizePixel = 0
divider.Parent = menuFrame

local function makeMenuButton(text, pos, bg, bgHover, strokeColor)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.5, -28, 0, 44)
	b.Position = pos
	b.BackgroundColor3 = bg
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Text = text
	b.Parent = menuFrame
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	local s = Instance.new("UIStroke")
	s.Thickness = 1.5
	s.Color = strokeColor
	s.Transparency = 0.2
	s.Parent = b
	local sc = Instance.new("UIScale")
	sc.Parent = b
	b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = bgHover}):Play() end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = bg}):Play()
		TweenService:Create(sc, TweenInfo.new(0.15), {Scale = 1}):Play()
	end)
	b.MouseButton1Down:Connect(function() TweenService:Create(sc, TweenInfo.new(0.08), {Scale = 0.95}):Play() end)
	b.MouseButton1Up:Connect(function() TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play() end)
	return b
end

local btnSim = makeMenuButton("ATIVAR", UDim2.new(0, 22, 1, -64), Color3.fromRGB(0, 160, 120), Color3.fromRGB(0, 195, 145), Color3.fromRGB(80, 255, 200))
local btnNao = makeMenuButton("AGORA NÃO", UDim2.new(0.5, 6, 1, -64), Color3.fromRGB(24, 30, 44), Color3.fromRGB(38, 46, 66), Color3.fromRGB(70, 84, 110))
btnNao.TextColor3 = Theme.Muted

-- animação de entrada
TweenService:Create(menuFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
TweenService:Create(menuScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
TweenService:Create(backdrop, TweenInfo.new(0.3), {BackgroundTransparency = 0.55}):Play()

local menuClosing = false
local function closeMenu()
	if menuClosing then return end
	menuClosing = true
	local ti = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(menuFrame, ti, {GroupTransparency = 1}):Play()
	TweenService:Create(menuScale, ti, {Scale = 0.92}):Play()
	TweenService:Create(backdrop, ti, {BackgroundTransparency = 1}):Play()
	task.delay(0.25, function()
		if antiFallMenu then antiFallMenu:Destroy() end
	end)
end

btnSim.MouseButton1Click:Connect(function()
	antiFallEnabled = true
	protect(player.Character)
	closeMenu()
end)

btnNao.MouseButton1Click:Connect(function()
	antiFallEnabled = false
	if antiFallConnection then
		antiFallConnection:Disconnect()
		antiFallConnection = nil
	end
	closeMenu()
end)
end -- fim do menu Anti Fall (só NDS)

-- Aplica no personagem atual e em todos os respawns (se ativado)
if player.Character then
	protect(player.Character)
end

trackRoot(player.CharacterAdded:Connect(function(char)
	if antiFallEnabled then
		protect(char)
	end
end))

-- =========================================================
-- PORTAL GUN + GRAVITY GUN
-- =========================================================

local function setupPortalGun(character)
	if not scriptAlive then return end

	local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 15)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 15)
	if not humanoid then
		warnPG("Humanoid não encontrado neste personagem; Portal Gun não carregada.")
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
		or character:WaitForChild("HumanoidRootPart", 10)
		or character.PrimaryPart
		or character:FindFirstChildWhichIsA("BasePart")
	if not rootPart then
		warnPG("Parte raiz do personagem não encontrada; Portal Gun não carregada.")
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
	if not backpack then
		backpack = Instance.new("Backpack")
		pcall(function() backpack.Parent = player end)
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local okA, a = pcall(function() return Instance.new("Animator", humanoid) end)
		animator = okA and a or nil
	end
	local camera = workspace.CurrentCamera or workspace:WaitForChild("Camera", 10)
	if not camera then
		warnPG("Câmera não encontrada; Portal Gun não carregada.")
		return
	end

	-- spawn mais novo / script reexecutado / personagem removido enquanto esperávamos
	if not scriptAlive or not character.Parent or (player.Character and player.Character ~= character) then return end

	-- encerra a instância anterior (respawn / reexecução / rebuild)
	if PGState.cleanup then
		local prevCleanup = PGState.cleanup
		PGState.cleanup = nil
		pcall(prevCleanup)
	end

	local Z = { alive = true, conns = {}, frozen = false, idleTry = 0, extra = nil }
	local function track(c)
		Z.conns[#Z.conns + 1] = c
		return c
	end
	PGState.cur = Z
	PGState.cleanup = function()
		Z.alive = false
		for _, c in ipairs(Z.conns) do
			pcall(function() c:Disconnect() end)
		end
		Z.conns = {}
		if Z.extra then
			local f = Z.extra
			Z.extra = nil
			pcall(f)
		end
	end

	-- o jogo pode recriar a câmera: mantém a referência atualizada
	track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if workspace.CurrentCamera then camera = workspace.CurrentCamera end
	end))

	-- Limpeza de GUIs, Tools e Conexões antigas
	if currentPortalGunGui then currentPortalGunGui:Destroy() end
	if currentHotbarGui then currentHotbarGui:Destroy() end
	
	for _, v in pairs(backpack:GetChildren()) do
		if v.Name == "Portal Gun" then
			v:Destroy()
		end
	end
	if character:FindFirstChild("Portal Gun") then
		character["Portal Gun"]:Destroy()
	end

	--------------------------- CONFIGURAÇÕES ---------------------------
	local Config = {
		Scale = Vector3.new(0.16, 0.16, 0.09),
		Position = Vector3.new(0, 0, 0),
		Rotation = Vector3.new(0, 0, 0),
		GripPos = Vector3.new(0, -0.3, 0.3),

		MeshId = "rbxassetid://10017565642",
		TextureId = "rbxassetid://10017566144",
		ToolIcon = "rbxassetid://116946514625364",

		IdleAnimId = "rbxassetid://124938319488741",
		EquipAnimId = "rbxassetid://130630299166448",
		ShootAnimId = "rbxassetid://124938319488741", -- Animação de atirar portal (somente R15)

		PortalSize = Vector3.new(6.5, 9.5, 0.2),
		PortalOffset = 0.12,
		MaxDistance = 400,
		PortalDuration = 30,
		MinPortalDistance = 6,
		PortalCooldown = 0.50, -- Cooldown entre cada portal
		ShootFreezeTime = 0.3, -- Tempo imovel ao atirar

		BlueColor = Color3.fromRGB(30, 155, 255),
		OrangeColor = Color3.fromRGB(255, 145, 25),

		SoundBlueOpen = "rbxassetid://7229703765",
		SoundOrangeOpen = "rbxassetid://7229704786",
		SoundEquip = "rbxassetid://129589685201945",
		SoundShoot = "rbxassetid://124704595914789",
		SoundInvalid = "rbxassetid://132281440773764",
		SoundGravityHold = "rbxassetid://137184310399054",
		SoundGravityRelease = "rbxassetid://8717291893",

		GravityMaxDistance = 120,          -- ← aumentado para suportar 100m
		GravityHoldDistance = 14,
		GravityLineColor = Color3.fromRGB(255, 210, 40),
		LineSegments = 32,
		TeleportCooldown = 0.7,
		CamSlide = true,        -- câmera desliza suavemente ao atravessar o portal
		CamSlideDuration = 0.55, -- duração do deslize (segundos); maior = mais suave
		CamSlideStyle = Enum.EasingStyle.Cubic,        -- Sine/Cubic/Quad (mais macio) ou Quint (mais brusco)
		CamSlideDirection = Enum.EasingDirection.Out,   -- Out = responde rápido e assenta suave (sem sensação de travada)

		HolsterOffset = CFrame.new(0, -1, 1) * CFrame.Angles(math.rad(15), math.rad(90), math.rad(0)),

		CrosshairImage = "rbxassetid://99374899228173",
		CrosshairYOffset = -65,
		ParticleSpark = "rbxassetid://241594419",
		ParticleSpark2 = "rbxassetid://243660364",
	}

	--------------------------- TOOL CREATION ---------------------------
	local crosshair = nil
	local holsteredGun = nil
	local portalsLinked = false

	-- Forward declarations (evita o erro de nil)
	local updateCrosshair
	local crosshairGravity = false
	local updateToggleButton

	local function playSound(id, volume, parent)
		local okS, sound = pcall(function()
			local s = Instance.new("Sound")
			s.SoundId = id
			s.Volume = volume or 1
			s.Parent = (parent and parent.Parent) and parent or SoundService
			s:Play()
			Debris:AddItem(s, 5)
			return s
		end)
		return okS and sound or nil
	end

	local tool = Instance.new("Tool")
	tool.Name = "Portal Gun"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(Config.GripPos)
	tool.TextureId = Config.ToolIcon
	pcall(function() tool.Parent = backpack end)

	local handle = Instance.new("MeshPart")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 2)
	handle.CanCollide = false
	handle.Massless = true
	handle.CastShadow = true

	-- MeshId pode ser bloqueado em alguns executores/jogos: tenta direto, depois InsertService, depois um bloco simples
	local meshOk = pcall(function()
		handle.MeshId = Config.MeshId
	end)
	if not meshOk then
		handle:Destroy()
		local okI, mp = pcall(function()
			return game:GetService("InsertService"):CreateMeshPartAsync(
				Config.MeshId, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic)
		end)
		if okI and mp then
			handle = mp
		else
			warnPG("Não foi possível carregar a malha da arma; usando modelo simples.")
			handle = Instance.new("Part")
			handle.Color = Config.BlueColor
			handle.Material = Enum.Material.SmoothPlastic
		end
		handle.Name = "Handle"
		handle.CanCollide = false
		handle.Massless = true
		handle.CastShadow = true
	end
	handle.Parent = tool
	pcall(function() handle.TextureID = Config.TextureId end)
	if handle:IsA("MeshPart") then
		handle.Size = Vector3.new(1, 1, 2) * Config.Scale
	else
		handle.Size = Vector3.new(0.35, 0.45, 1.2)
	end
	handle.CFrame = handle.CFrame * CFrame.new(Config.Position) * CFrame.Angles(
		math.rad(Config.Rotation.X),
		math.rad(Config.Rotation.Y),
		math.rad(Config.Rotation.Z)
	)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(0, 170, 255)
	light.Brightness = 1.8
	light.Range = 9
	light.Parent = handle

	task.wait(0.1)
	pcall(function() handle.TextureID = Config.TextureId end)

	local defaultGrip = CFrame.new(Config.GripPos)
	local isRecoiling = false

	local function playRecoil()
		if isRecoiling then return end
		isRecoiling = true

		local recoilGrip = defaultGrip
			* CFrame.new(0, 0.06, 0.18)
			* CFrame.Angles(math.rad(-8), math.rad(2), math.rad(1))

		local kickInfo = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local recoverInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		local kick = TweenService:Create(tool, kickInfo, {Grip = recoilGrip})
		kick:Play()
		kick.Completed:Wait()

		local recover = TweenService:Create(tool, recoverInfo, {Grip = defaultGrip})
		recover:Play()
		recover.Completed:Wait()

		tool.Grip = defaultGrip
		isRecoiling = false
	end

	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = Config.IdleAnimId

	local equipAnim = Instance.new("Animation")
	equipAnim.AnimationId = Config.EquipAnimId

	local shootAnim = Instance.new("Animation")
	shootAnim.AnimationId = Config.ShootAnimId

	-- Detecta se o personagem é R15 ou R6
	local isR15 = (humanoid.RigType == Enum.HumanoidRigType.R15)

	local idleTrack = nil
	local equipTrack = nil
	local shootTrack = nil
	local isEquipped = false
	local isEquipping = false
	local isShootingPortal = false
	local lastPortalShot = 0
	local updateConnection = nil
	local savedWalkSpeed = 16
	local savedJumpPower = 50
	local savedJumpHeight = 7.2

	local function isStandingStill()
		local state = humanoid:GetState()
		local moving = humanoid.MoveDirection.Magnitude > 0.05
		local air = state == Enum.HumanoidStateType.Jumping
			or state == Enum.HumanoidStateType.Freefall
			or state == Enum.HumanoidStateType.Flying
		return (not moving) and (not air)
	end

	local function playIdle()
		if idleTrack and idleTrack.IsPlaying then return end
		if idleTrack then
			-- animação que não toca (asset sem permissão neste jogo): não recarrega a cada frame
			if os.clock() - Z.idleTry < 1 then return end
			pcall(function()
				idleTrack:Stop()
				idleTrack:Destroy()
			end)
			idleTrack = nil
		end
		Z.idleTry = os.clock()
		idleTrack = loadTrack(animator, idleAnim)
		if not idleTrack then return end
		pcall(function()
			idleTrack.Priority = Enum.AnimationPriority.Idle
			idleTrack.Looped = true
			idleTrack:Play(0.2)
		end)
	end

	local function stopIdle()
		if idleTrack then
			idleTrack:Stop(0.15)
			idleTrack:Destroy()
			idleTrack = nil
		end
	end

	local function stopEquipAnim()
		if equipTrack then
			equipTrack:Stop(0.1)
			equipTrack:Destroy()
			equipTrack = nil
		end
	end

	local function playEquipAnim()
		stopEquipAnim()
		stopIdle()

		equipTrack = loadTrack(animator, equipAnim)
		if equipTrack then
			pcall(function()
				equipTrack.Priority = Enum.AnimationPriority.Action
				equipTrack.Looped = false
				equipTrack:Play(0.05)
			end)
		end

		task.delay(0.3, function()
			stopEquipAnim()
		end)
	end

	local function stopShootAnim()
		if shootTrack then
			shootTrack:Stop(0.1)
			shootTrack:Destroy()
			shootTrack = nil
		end
	end

	local function playShootAnim()
		-- Só toca animação R15 se o personagem for R15
		if not isR15 then return end
		stopShootAnim()
		stopIdle()

		shootTrack = loadTrack(animator, shootAnim)
		if shootTrack then
			pcall(function()
				shootTrack.Priority = Enum.AnimationPriority.Action
				shootTrack.Looped = false
				shootTrack:Play(0.05)
			end)
		end

		task.delay(Config.ShootFreezeTime + 0.1, function()
			stopShootAnim()
		end)
	end

	local function freezeCharacter()
		if not humanoid or Z.frozen then return end
		Z.frozen = true
		pcall(function()
			savedWalkSpeed = humanoid.WalkSpeed
			savedJumpPower = humanoid.JumpPower
			savedJumpHeight = humanoid.JumpHeight
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0
		end)
	end

	local function unfreezeCharacter()
		if not humanoid or not Z.frozen then return end
		Z.frozen = false
		pcall(function()
			humanoid.WalkSpeed = savedWalkSpeed
			humanoid.JumpPower = savedJumpPower
			humanoid.JumpHeight = savedJumpHeight
		end)
	end

	local function updateIdle()
		if not isEquipped or isEquipping or isShootingPortal then
			stopIdle()
			return
		end
		if isStandingStill() then
			playIdle()
		else
			stopIdle()
		end
	end

	local function getBackAttachment()
		local upperTorso = character:FindFirstChild("UpperTorso")
		if upperTorso then return upperTorso end
		local torso = character:FindFirstChild("Torso")
		if torso then return torso end
		return rootPart
	end

	local function createHolster()
		if holsteredGun then
			holsteredGun:Destroy()
			holsteredGun = nil
		end

		local backPart = getBackAttachment()
		if not backPart then return end

		holsteredGun = handle:Clone()
		if not holsteredGun then return end
		holsteredGun.Name = "HolsteredPortalGun"
		holsteredGun.CanCollide = false
		holsteredGun.Massless = true
		holsteredGun.Anchored = false
		holsteredGun.Parent = character

		for _, child in ipairs(holsteredGun:GetDescendants()) do
			if child:IsA("PointLight") or child:IsA("ParticleEmitter") then
				child:Destroy()
			end
		end

		local weld = Instance.new("Weld")
		weld.Name = "HolsterWeld"
		weld.Part0 = backPart
		weld.Part1 = holsteredGun
		weld.C0 = Config.HolsterOffset
		weld.Parent = holsteredGun
	end

	local function removeHolster()
		if holsteredGun then
			holsteredGun:Destroy()
			holsteredGun = nil
		end
	end

	-- =========================================================
	-- CUSTOM HOTBAR (SLOT) NA MESMA POSIÇÃO DO SPRAY DO 4ITENS
	-- =========================================================
	local HotbarGui = Instance.new("ScreenGui")
	HotbarGui.Name = "PortalGunHotbar"
	HotbarGui.ResetOnSpawn = false
	HotbarGui.IgnoreGuiInset = true
	HotbarGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	parentGui(HotbarGui)
	currentHotbarGui = HotbarGui

	local HotbarFrame = Instance.new("Frame")
	HotbarFrame.Name = "HotbarFrame"
	HotbarFrame.Size = UDim2.new(0, 38, 0, 40)
	HotbarFrame.Position = UDim2.new(1, -58, 1, -72)
	HotbarFrame.BackgroundTransparency = 1
	HotbarFrame.Parent = HotbarGui

	local slotBtn = Instance.new("TextButton")
	slotBtn.Name = "Slot_PortalGun"
	slotBtn.Size = UDim2.new(0, 32, 0, 32)
	slotBtn.Position = UDim2.new(0, 4, 0, 4)
	slotBtn.BackgroundColor3 = Color3.fromRGB(12, 15, 24)
	slotBtn.BorderSizePixel = 0
	slotBtn.Text = ""
	slotBtn.AutoButtonColor = false
	slotBtn.Parent = HotbarFrame

	Instance.new("UICorner", slotBtn).CornerRadius = UDim.new(0, 10)

	local slotStroke = Instance.new("UIStroke")
	slotStroke.Color = Config.BlueColor
	slotStroke.Thickness = 2
	slotStroke.Parent = slotBtn
	tintStroke(slotStroke, Config.BlueColor, true)

	local shadow = Instance.new("Frame")
	shadow.Size = UDim2.new(1, 4, 1, 4)
	shadow.Position = UDim2.new(0, 2, 0, 2)
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 0.55
	shadow.ZIndex = slotBtn.ZIndex - 1
	shadow.Parent = slotBtn
	Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, 10)

	local emoji = Instance.new("TextLabel")
	emoji.Size = UDim2.new(1, 0, 1, 0)
	emoji.BackgroundTransparency = 1
	emoji.Text = "🌀"
	emoji.TextSize = 18
	emoji.Parent = slotBtn

	local selectedFrame = Instance.new("Frame")
	selectedFrame.Name = "Selected"
	selectedFrame.Size = UDim2.new(1, 0, 1, 0)
	selectedFrame.BackgroundTransparency = 1
	selectedFrame.Visible = false
	selectedFrame.Parent = slotBtn

	local selStroke = Instance.new("UIStroke")
	selStroke.Color = Color3.fromRGB(255, 255, 255)
	selStroke.Thickness = 2.5
	selStroke.Parent = selectedFrame
	Instance.new("UICorner", selectedFrame).CornerRadius = UDim.new(0, 10)

	slotBtn.MouseEnter:Connect(function()
		TweenService:Create(slotBtn, TweenInfo.new(0.12), {
			BackgroundColor3 = Color3.fromRGB(26, 32, 48),
			Size = UDim2.new(0, 34, 0, 34)
		}):Play()
	end)

	slotBtn.MouseLeave:Connect(function()
		TweenService:Create(slotBtn, TweenInfo.new(0.12), {
			BackgroundColor3 = Color3.fromRGB(12, 15, 24),
			Size = UDim2.new(0, 32, 0, 32)
		}):Play()
	end)

	slotBtn.MouseButton1Click:Connect(function()
		local t = backpack:FindFirstChild("Portal Gun") or character:FindFirstChild("Portal Gun")
		if t and t:IsA("Tool") then
			pcall(function()
				if t.Parent == character then
					humanoid:UnequipTools()
				else
					humanoid:EquipTool(t)
				end
			end)
		end
	end)

	task.spawn(function()
		while Z.alive and character and character.Parent do
			local t = character:FindFirstChild("Portal Gun")
			selectedFrame.Visible = (t ~= nil)
			task.wait(0.3)
		end
	end)
	-- =========================================================

	local bluePortal = nil
	local orangePortal = nil
	local blueToken = 0
	local orangeToken = 0
	local nextIsBlue = true
	local lastTeleport = 0
	local isTeleporting = false

	-- Host parts para portais em partes móveis
	local blueHostPart = nil
	local blueRelativeCF = nil
	local orangeHostPart = nil
	local orangeRelativeCF = nil

	local function getPortalCoreColor(color)
		return Color3.new(
			math.clamp(color.R * 0.55, 0, 1),
			math.clamp(color.G * 0.55, 0, 1),
			math.clamp(color.B * 0.55, 0, 1)
		)
	end

	local function setPortalCoresLinked(linked)
		local function fadeCore(portalModel, targetColor)
			if not portalModel or not portalModel.Parent then return end
			local core = portalModel:FindFirstChild("PortalCore")
			if core then
				TweenService:Create(core, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Color = targetColor
				}):Play()
			end
		end

		if linked then
			fadeCore(bluePortal, Color3.new(0, 0, 0))
			fadeCore(orangePortal, Color3.new(0, 0, 0))
		else
			if bluePortal and bluePortal.Parent then
				fadeCore(bluePortal, getPortalCoreColor(Config.BlueColor))
			end
			if orangePortal and orangePortal.Parent then
				fadeCore(orangePortal, getPortalCoreColor(Config.OrangeColor))
			end
		end

		portalsLinked = linked
	end

	local function updatePortalLinkState()
		local bothActive = bluePortal and bluePortal.Parent and orangePortal and orangePortal.Parent
		setPortalCoresLinked(bothActive)
	end

	local function updatePortalsPosition()
		-- Atualiza portal azul se estiver preso a uma part móvel
		if bluePortal and bluePortal.Parent and blueHostPart and blueHostPart.Parent then
			local outer = bluePortal:FindFirstChild("OuterRing")
			local core = bluePortal:FindFirstChild("PortalCore")
			local portalPart = bluePortal:FindFirstChild("Portal")
			local detector = bluePortal:FindFirstChild("Detector")
			if outer and blueRelativeCF then
				local newCF = blueHostPart.CFrame * blueRelativeCF
				outer.CFrame = newCF
				if core then
					core.CFrame = newCF * CFrame.new(0, 0, -0.04)
				end
				if portalPart then
					portalPart.CFrame = newCF
				end
				if detector then
					detector.CFrame = newCF * CFrame.new(0, 0, -1.4)
				end
			end
		elseif blueHostPart and (not blueHostPart.Parent) then
			blueHostPart = nil
			blueRelativeCF = nil
		end

		-- Atualiza portal laranja se estiver preso a uma part móvel
		if orangePortal and orangePortal.Parent and orangeHostPart and orangeHostPart.Parent then
			local outer = orangePortal:FindFirstChild("OuterRing")
			local core = orangePortal:FindFirstChild("PortalCore")
			local portalPart = orangePortal:FindFirstChild("Portal")
			local detector = orangePortal:FindFirstChild("Detector")
			if outer and orangeRelativeCF then
				local newCF = orangeHostPart.CFrame * orangeRelativeCF
				outer.CFrame = newCF
				if core then
					core.CFrame = newCF * CFrame.new(0, 0, -0.04)
				end
				if portalPart then
					portalPart.CFrame = newCF
				end
				if detector then
					detector.CFrame = newCF * CFrame.new(0, 0, -1.4)
				end
			end
		elseif orangeHostPart and (not orangeHostPart.Parent) then
			orangeHostPart = nil
			orangeRelativeCF = nil
		end
	end

	local function createPortalVisual(color, position, normal, isOpening, isBlue)
		local model = Instance.new("Model")
		model.Name = "PortalModel"

		local lookPos = position + normal * 5
		local cf
		if math.abs(normal.Y) > 0.95 then
			local camFwd = camera.CFrame.LookVector
			local flatFwd = Vector3.new(camFwd.X, 0, camFwd.Z)
			if flatFwd.Magnitude < 0.01 then
				local rl = rootPart.CFrame.LookVector
				flatFwd = Vector3.new(rl.X, 0, rl.Z)
				if flatFwd.Magnitude < 0.01 then flatFwd = Vector3.new(0, 0, -1) end
			end
			local topDir = flatFwd.Unit
			if normal.Y < 0 then topDir = -topDir end
			cf = CFrame.lookAt(position + normal * Config.PortalOffset, lookPos, topDir)
		else
			cf = CFrame.lookAt(position + normal * Config.PortalOffset, lookPos, Vector3.new(0, 1, 0))
		end

		-- Brilho externo (halo neon fino)
		local outer = Instance.new("Part")
		outer.Name = "OuterRing"
		outer.Anchored = true
		outer.CanCollide = false
		outer.Size = Config.PortalSize
		outer.Material = Enum.Material.Neon
		outer.Color = color
		outer.Transparency = 0.35
		outer.CastShadow = false
		outer.CFrame = cf
		outer.Parent = model

		local outerMesh = Instance.new("SpecialMesh")
		outerMesh.MeshType = Enum.MeshType.Sphere
		outerMesh.Scale = Vector3.new(1, 1, 0.12)
		outerMesh.Parent = outer

		-- Fundo escuro (muda de cor quando os dois portais estão linkados)
		local core = Instance.new("Part")
		core.Name = "PortalCore"
		core.Anchored = true
		core.CanCollide = false
		core.Size = Config.PortalSize * Vector3.new(0.88, 0.88, 0.55)
		core.Material = Enum.Material.SmoothPlastic
		core.Color = getPortalCoreColor(color)
		core.Transparency = 0.1
		core.CastShadow = false
		core.CFrame = cf * CFrame.new(0, 0, -0.04)
		core.Parent = model

		local coreMesh = Instance.new("SpecialMesh")
		coreMesh.MeshType = Enum.MeshType.Sphere
		coreMesh.Scale = Vector3.new(1, 1, 0.12)
		coreMesh.Parent = core

		-- Part invisível que carrega o SurfaceGui (aro giratório + vórtice)
		local portal = Instance.new("Part")
		portal.Name = "Portal"
		portal.Anchored = true
		portal.CanCollide = false
		portal.Size = Config.PortalSize * Vector3.new(0.88, 0.88, 0.5)
		portal.Transparency = 1
		portal.CanQuery = false
		portal.CFrame = cf
		portal.Parent = model

		local sg = Instance.new("SurfaceGui")
		sg.Name = "PortalSwirl"
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sg.CanvasSize = Vector2.new(512, 512) -- canvas quadrado: o UICorner vira uma elipse perfeita ao esticar no portal
				sg.LightInfluence = 0
		sg.AlwaysOnTop = false
		sg.Parent = portal

		local root = Instance.new("Frame")
		root.Name = "Root"
		root.AnchorPoint = Vector2.new(0.5, 0.5)
		root.Position = UDim2.fromScale(0.5, 0.5)
		root.Size = UDim2.fromScale(1, 1)
		root.BackgroundTransparency = 1
		root.Parent = sg

		local function ellipse(name, scale, alpha)
			local f = Instance.new("Frame")
			f.Name = name
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(0.5, 0.5)
			f.Size = UDim2.fromScale(scale, scale)
			f.BackgroundColor3 = color
			f.BackgroundTransparency = alpha
			f.BorderSizePixel = 0
			f.Parent = root
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(1, 0)
			c.Parent = f
			return f
		end

		local function spin(gradient, seconds, dir)
			TweenService:Create(
				gradient,
				TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
				{Rotation = 360 * dir}
			):Play()
		end

		local function swirlGradient(parent, alphaPeak)
			local g = Instance.new("UIGradient")
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, alphaPeak),
				NumberSequenceKeypoint.new(0.3, 1),
				NumberSequenceKeypoint.new(0.55, alphaPeak),
				NumberSequenceKeypoint.new(0.8, 1),
				NumberSequenceKeypoint.new(1, alphaPeak),
			})
			g.Parent = parent
			return g
		end

		-- Vórtice interno: duas camadas girando em sentidos opostos
		local swirlA = ellipse("SwirlA", 0.9, 0)
		spin(swirlGradient(swirlA, 0.45), 2.6, 1)
		local swirlB = ellipse("SwirlB", 0.72, 0)
		spin(swirlGradient(swirlB, 0.6), 1.8, -1)

		-- Buraco escuro no centro
		local hole = ellipse("Hole", 0.5, 0.2)
		hole.BackgroundColor3 = Color3.new(0, 0, 0)
		local holeGrad = Instance.new("UIGradient")
		holeGrad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		holeGrad.Parent = hole

		-- Aro com brilho giratório
		local rim = Instance.new("Frame")
		rim.Name = "Rim"
		rim.AnchorPoint = Vector2.new(0.5, 0.5)
		rim.Position = UDim2.fromScale(0.5, 0.5)
		rim.Size = UDim2.fromScale(0.98, 0.98)
		rim.BackgroundTransparency = 1
		rim.Parent = root
		local rimCorner = Instance.new("UICorner")
		rimCorner.CornerRadius = UDim.new(1, 0)
		rimCorner.Parent = rim
		local rimStroke = Instance.new("UIStroke")
		rimStroke.Thickness = 10
		rimStroke.Color = Color3.new(1, 1, 1)
		rimStroke.Parent = rim
		local rimGrad = Instance.new("UIGradient")
		rimGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color),
			ColorSequenceKeypoint.new(0.2, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.4, color),
			ColorSequenceKeypoint.new(1, color),
		})
		rimGrad.Parent = rimStroke
		spin(rimGrad, 1.4, 1)

		-- Luz e faíscas
		local pointLight = Instance.new("PointLight")
		pointLight.Color = color
		pointLight.Brightness = 0
		pointLight.Range = 14
		pointLight.Parent = outer

		local edgeSparks = Instance.new("ParticleEmitter")
		edgeSparks.Name = "EdgeSparks"
		edgeSparks.Texture = Config.ParticleSpark
		edgeSparks.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
		edgeSparks.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.14),
			NumberSequenceKeypoint.new(1, 0),
		})
		edgeSparks.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		edgeSparks.Lifetime = NumberRange.new(0.3, 0.6)
		edgeSparks.Rate = 14
		edgeSparks.Speed = NumberRange.new(1.5, 3.5)
		edgeSparks.SpreadAngle = Vector2.new(20, 20)
		edgeSparks.EmissionDirection = Enum.NormalId.Front
		edgeSparks.LightEmission = 1
		edgeSparks.LightInfluence = 0
		edgeSparks.LockedToPart = true
		edgeSparks.Parent = outer

		local detector = Instance.new("Part")
		detector.Name = "Detector"
		detector.Anchored = true
		detector.CanCollide = false
		detector.Transparency = 1
		detector.Size = Vector3.new(Config.PortalSize.X * 0.88, Config.PortalSize.Y * 0.88, 2.8)
		detector.CFrame = cf * CFrame.new(0, 0, -1.4)
		detector.Parent = model

		model.Parent = workspace

		if isOpening then
			outer.Size = Vector3.new(0.1, 0.1, 0.1)
			core.Size = Vector3.new(0.1, 0.1, 0.1)
			root.Size = UDim2.fromScale(0, 0)
			edgeSparks.Enabled = false

			local ti = TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			TweenService:Create(outer, ti, {Size = Config.PortalSize}):Play()
			TweenService:Create(core, ti, {Size = Config.PortalSize * Vector3.new(0.88, 0.88, 0.55)}):Play()
			TweenService:Create(root, ti, {Size = UDim2.fromScale(1, 1)}):Play()
			TweenService:Create(pointLight, TweenInfo.new(0.3), {Brightness = 2.5}):Play()

			task.delay(0.25, function()
				if model and model.Parent then
					edgeSparks.Enabled = true
				end
			end)

			playSound(isBlue and Config.SoundBlueOpen or Config.SoundOrangeOpen, 1.2, outer)
		else
			pointLight.Brightness = 2.5
		end

		return model
	end

	local function closePortal(model)
		if not model or not model.Parent then return end

		local outer = model:FindFirstChild("OuterRing")
		local core = model:FindFirstChild("PortalCore")
		local light = outer and outer:FindFirstChildOfClass("PointLight")

		for _, desc in ipairs(model:GetDescendants()) do
			if desc:IsA("ParticleEmitter") then
				desc.Enabled = false
			end
		end

		local ti = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)

		if outer then
			TweenService:Create(outer, ti, {Size = Vector3.new(0.05, 0.05, 0.05), Transparency = 1}):Play()
		end
		if core then
			TweenService:Create(core, ti, {Size = Vector3.new(0.05, 0.05, 0.05), Transparency = 1}):Play()
		end
		if light then
			TweenService:Create(light, TweenInfo.new(0.2), {Brightness = 0}):Play()
		end

		local swirlGui = model:FindFirstChild("Portal") and model.Portal:FindFirstChild("PortalSwirl")
		local swirlRoot = swirlGui and swirlGui:FindFirstChild("Root")
		if swirlRoot then
			TweenService:Create(swirlRoot, ti, {Size = UDim2.fromScale(0, 0)}):Play()
		end

		task.wait(0.32)
		if model and model.Parent then
			model:Destroy()
		end
	end

	local function isTooCloseToPortal(pos)
		if bluePortal and bluePortal.Parent then
			local p = bluePortal:FindFirstChild("Portal")
			if p and (p.Position - pos).Magnitude < Config.MinPortalDistance then
				return true
			end
		end
		if orangePortal and orangePortal.Parent then
			local p = orangePortal:FindFirstChild("Portal")
			if p and (p.Position - pos).Magnitude < Config.MinPortalDistance then
				return true
			end
		end
		return false
	end

	local function playMuzzleFlash(color)
		local tipCF = handle.CFrame * CFrame.new(0, 0, -1.18)

		local muzzle = Instance.new("Part")
		muzzle.Name = "MuzzleFlash"
		muzzle.Anchored = true
		muzzle.CanCollide = false
		muzzle.CanQuery = false
		muzzle.CastShadow = false
		muzzle.Material = Enum.Material.Neon
		muzzle.Color = color
		muzzle.Transparency = 0.08
		muzzle.Size = Vector3.new(0.28, 0.28, 0.28)
		muzzle.Shape = Enum.PartType.Ball
		muzzle.CFrame = tipCF
		muzzle.Parent = workspace

		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = 8
		light.Range = 12
		light.Parent = muzzle

		local burst = Instance.new("ParticleEmitter")
		burst.Texture = Config.ParticleSpark
		burst.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.35, color),
			ColorSequenceKeypoint.new(1, color)
		})
		burst.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.25, 0.85),
			NumberSequenceKeypoint.new(1, 0)
		})
		burst.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.4, 0.35),
			NumberSequenceKeypoint.new(1, 1)
		})
		burst.Lifetime = NumberRange.new(0.1, 0.2)
		burst.Rate = 0
		burst.Speed = NumberRange.new(5, 11)
		burst.SpreadAngle = Vector2.new(28, 28)
		burst.LightEmission = 1
		burst.LightInfluence = 0
		burst.Acceleration = tipCF.LookVector * -18
		burst.Parent = muzzle
		burst:Emit(22)

		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = Config.ParticleSpark2
		sparks.Color = ColorSequence.new(color)
		sparks.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.18),
			NumberSequenceKeypoint.new(0.5, 0.1),
			NumberSequenceKeypoint.new(1, 0)
		})
		sparks.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.4),
			NumberSequenceKeypoint.new(1, 1)
		})
		sparks.Lifetime = NumberRange.new(0.12, 0.28)
		sparks.Rate = 0
		sparks.Speed = NumberRange.new(8, 18)
		sparks.SpreadAngle = Vector2.new(42, 42)
		sparks.LightEmission = 1
		sparks.LightInfluence = 0
		sparks.Acceleration = Vector3.new(0, -6, 0)
		sparks.Parent = muzzle
		sparks:Emit(16)

		local glow = Instance.new("ParticleEmitter")
		glow.Texture = Config.ParticleSpark
		glow.Color = ColorSequence.new(color)
		glow.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.4, 0.9),
			NumberSequenceKeypoint.new(1, 1.3)
		})
		glow.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(0.5, 0.7),
			NumberSequenceKeypoint.new(1, 1)
		})
		glow.Lifetime = NumberRange.new(0.15, 0.25)
		glow.Rate = 0
		glow.Speed = NumberRange.new(0.5, 2)
		glow.SpreadAngle = Vector2.new(180, 180)
		glow.LightEmission = 0.8
		glow.LightInfluence = 0
		glow.Parent = muzzle
		glow:Emit(6)

		TweenService:Create(muzzle, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.85, 0.85, 0.85),
			Transparency = 0.55
		}):Play()
		TweenService:Create(light, TweenInfo.new(0.2), {Brightness = 0, Range = 3}):Play()

		task.delay(0.07, function()
			if muzzle and muzzle.Parent then
				TweenService:Create(muzzle, TweenInfo.new(0.14), {
					Size = Vector3.new(0.04, 0.04, 0.04),
					Transparency = 1
				}):Play()
			end
		end)

		Debris:AddItem(muzzle, 0.5)
	end

	-- Portal de parede nunca entra embaixo do chão: se a base ficaria abaixo do piso, sobe o portal
	local FLOOR_MARGIN = 0.05
	local function liftWallPortalAboveFloor(hitPos, normal)
		if math.abs(normal.Y) > 0.7 then return hitPos end -- só paredes (não chão/teto)

		local halfH = Config.PortalSize.Y / 2
		local halfW = Config.PortalSize.X / 2
		local right = normal:Cross(Vector3.yAxis)
		if right.Magnitude < 0.01 then return hitPos end
		right = right.Unit

		local params = RaycastParams.new()
		params.FilterDescendantsInstances = buildIgnore(character, bluePortal, orangePortal)
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = true

		-- varre a largura do portal, pra pegar o ponto mais alto do chão embaixo dele
		local highestFloor = nil
		for _, off in ipairs({-halfW, -halfW / 2, 0, halfW / 2, halfW}) do
			local origin = hitPos + right * off + normal * 0.6
			local res = workspace:Raycast(origin, Vector3.new(0, -(halfH + 0.5), 0), params)
			if res and res.Normal.Y > 0.7 then
				if not highestFloor or res.Position.Y > highestFloor then
					highestFloor = res.Position.Y
				end
			end
		end

		if highestFloor then
			local minY = highestFloor + halfH + FLOOR_MARGIN
			if hitPos.Y < minY then
				return Vector3.new(hitPos.X, minY, hitPos.Z)
			end
		end
		return hitPos
	end

	local function placePortal()
		-- Cooldown de 0.50s entre cada portal
		if tick() - lastPortalShot < Config.PortalCooldown then
			return
		end
		if isShootingPortal then return end

		local origin = camera.CFrame.Position
		local direction = camera.CFrame.LookVector * Config.MaxDistance

		local result = castSolid(origin, direction, buildIgnore(character, bluePortal, orangePortal))

		if not result or not result.Instance or not result.Instance:IsA("BasePart") then
			playSound(Config.SoundInvalid, 1.1, handle)
			return
		end

		local hitPos = result.Position
		local normal = result.Normal
		local hitPart = result.Instance

		hitPos = liftWallPortalAboveFloor(hitPos, normal)

		if isTooCloseToPortal(hitPos) then
			playSound(Config.SoundInvalid, 1.1, handle)
			return
		end

		lastPortalShot = tick()
		isShootingPortal = true

		-- Faz o personagem virar na direção do portal
		local lookDir = (hitPos - rootPart.Position)
		lookDir = Vector3.new(lookDir.X, 0, lookDir.Z)
		if lookDir.Magnitude > 0.1 and not humanoid.SeatPart then
			rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + lookDir.Unit)
		end

		-- Congela o personagem por 0.3s
		freezeCharacter()

		-- Toca animação de atirar SOMENTE se for R15
		if isR15 then
			playShootAnim()
		end

		task.delay(Config.ShootFreezeTime, function()
			if isEquipped then
				unfreezeCharacter()
			end
			isShootingPortal = false
		end)

		playSound(Config.SoundShoot, 0.9, handle)
		task.spawn(playRecoil)

		local flashColor = nextIsBlue and Config.BlueColor or Config.OrangeColor
		playMuzzleFlash(flashColor)

		if nextIsBlue then
			blueToken = blueToken + 1
			local myToken = blueToken

			if bluePortal then
				task.spawn(function()
					closePortal(bluePortal)
				end)
				bluePortal = nil
			end
			blueHostPart = nil
			blueRelativeCF = nil

			bluePortal = createPortalVisual(Config.BlueColor, hitPos, normal, true, true)
			bluePortal.Name = "BluePortal"

			-- Anexa o portal à part hit (funciona em parts móveis)
			local outer = bluePortal:FindFirstChild("OuterRing")
			if outer and hitPart and hitPart.Parent then
				blueHostPart = hitPart
				blueRelativeCF = hitPart.CFrame:ToObjectSpace(outer.CFrame)
			end

			task.delay(Config.PortalDuration, function()
				if myToken == blueToken and bluePortal and bluePortal.Parent then
					closePortal(bluePortal)
					if myToken == blueToken then
						bluePortal = nil
						blueHostPart = nil
						blueRelativeCF = nil
					end
					updatePortalLinkState()
				end
			end)
		else
			orangeToken = orangeToken + 1
			local myToken = orangeToken

			if orangePortal then
				task.spawn(function()
					closePortal(orangePortal)
				end)
				orangePortal = nil
			end
			orangeHostPart = nil
			orangeRelativeCF = nil

			orangePortal = createPortalVisual(Config.OrangeColor, hitPos, normal, true, false)
			orangePortal.Name = "OrangePortal"

			-- Anexa o portal à part hit (funciona em parts móveis)
			local outer = orangePortal:FindFirstChild("OuterRing")
			if outer and hitPart and hitPart.Parent then
				orangeHostPart = hitPart
				orangeRelativeCF = hitPart.CFrame:ToObjectSpace(outer.CFrame)
			end

			task.delay(Config.PortalDuration, function()
				if myToken == orangeToken and orangePortal and orangePortal.Parent then
					closePortal(orangePortal)
					if myToken == orangeToken then
						orangePortal = nil
						orangeHostPart = nil
						orangeRelativeCF = nil
					end
					updatePortalLinkState()
				end
			end)
		end

		nextIsBlue = not nextIsBlue
		if updateCrosshair then updateCrosshair() end
		if updateToggleButton then updateToggleButton() end
		updatePortalLinkState()
	end

	-- =========================================================
	-- ATRAVESSAR PORTAL CONTÍNUO (estilo Portal) + CLONE DO CORPO
	-- Substitui o antigo teleportThrough/checkPortalTouch.
	-- * a abertura do portal "abre" a parede só pra você (colisão local)
	-- * ao cruzar o plano do portal você sai do outro com a mesma
	--   posição/direção/velocidade relativa (sem puxão, sem FOV zoom)
	-- * metade do corpo que está dentro aparece saindo do outro portal
	--   (técnica do PhaseGhost do Sandevistan: clone anchored que copia
	--   o CFrame de cada parte a cada RenderStepped)
	-- =========================================================
	local FLIP = CFrame.Angles(0, math.pi, 0)

	local PortalWalk = {
		ZoneFront = 4.5,         -- quantos studs na frente do portal a parede já fica "aberta"
		ZoneBack = 1.5,          -- tolerância atrás do plano do portal
		CloneZoneMargin = 2.5,   -- margem pra o clone começar a aparecer
		CoreFadeTransparency = 0.85, -- transparência do núcleo do portal enquanto você atravessa
		FadeCoreOnApproach = false, -- true = núcleo some ao chegar perto (comportamento antigo)
		MinExitSpeed = 8,        -- velocidade mínima saindo do portal (evita ficar preso na boca)
		HideInsidePart = true,   -- esconde (só pra você) a parte do corpo que já passou do plano
		MaxStep = 40,            -- ignora travessia se o root andou mais que isso num frame (respawn etc)

		Clones = {},             -- [portalModel] = {model = Model, pairs = {...}}
		Disabled = {},           -- [BasePart] = true (partes com colisão desligada por nós)
		Hidden = {},             -- [BasePart] = true (partes do seu corpo escondidas por nós)
		PrevPos = nil,
		CharParts = {},
		CharPartsT = 0,
	}

	local PORTAL_CLONE_JUNK = {"Script", "LocalScript", "ModuleScript", "Sound", "ParticleEmitter", "Trail", "Beam", "Highlight", "BillboardGui", "ForceField", "Fire", "Smoke", "Sparkles", "PointLight", "SpotLight", "SurfaceLight", "BodyMover", "VectorForce", "Animator"}

	local function inOpening(lp, halfW, halfH, margin)
		local a = lp.X / (halfW + margin)
		local b = lp.Y / (halfH + margin)
		return a * a + b * b <= 1
	end

	-- cria um clone 1:1 do seu boneco (mesmo método do PhaseGhost.Create)
	local function createPortalClone()
		local wasArchivable = character.Archivable
		character.Archivable = true
		local ok, ghost = pcall(function() return character:Clone() end)
		character.Archivable = wasArchivable
		if not ok or not ghost then return nil end

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

		local srcMap, ghostMap = keyed(character), keyed(ghost)
		local list = {}
		for key, gp in pairs(ghostMap) do
			local op = srcMap[key]
			if op then table.insert(list, {gp = gp, op = op}) end
		end
		if #list == 0 then ghost:Destroy() return nil end

		for _, obj in ipairs(ghost:GetDescendants()) do
			for _, cls in ipairs(PORTAL_CLONE_JUNK) do
				if obj:IsA(cls) then obj:Destroy() break end
			end
		end

		for _, pr in ipairs(list) do
			local part = pr.gp
			if part.Parent then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
				part.Massless = true
				pr.trans = part.Transparency
				pr.decals = {}
				for _, d in ipairs(part:GetChildren()) do
					if d:IsA("Decal") or d:IsA("Texture") then
						table.insert(pr.decals, {d, d.Transparency})
					end
				end
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

		ghost.Name = "PortalClone"
		ghost.Parent = workspace
		return {model = ghost, pairs = list}
	end

	local function destroyPortalClone(portalModel)
		local c = PortalWalk.Clones[portalModel]
		if c then
			if c.model then pcall(function() c.model:Destroy() end) end
			PortalWalk.Clones[portalModel] = nil
		end
	end

	local function refreshCharParts()
		local now = os.clock()
		if now - PortalWalk.CharPartsT < 1 then return end
		PortalWalk.CharPartsT = now
		local t = {}
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("BasePart") then table.insert(t, d) end
		end
		PortalWalk.CharParts = t
	end

	local function unhideBody()
		for part in pairs(PortalWalk.Hidden) do
			if part and part.Parent then
				pcall(function() part.LocalTransparencyModifier = 0 end)
			end
		end
		PortalWalk.Hidden = {}
	end

	local function restoreCollisions(keep)
		for part in pairs(PortalWalk.Disabled) do
			if not (keep and keep[part]) then
				if part and part.Parent then
					pcall(function() part.CanCollide = true end)
				end
				PortalWalk.Disabled[part] = nil
			end
		end
	end

	local function setCoresFaded(model, faded)
		if not PortalWalk.FadeCoreOnApproach then faded = false end
		if not model or not model.Parent then return end
		local core = model:FindFirstChild("PortalCore")
		if not core then return end
		if core:GetAttribute("PWFaded") == faded then return end
		core:SetAttribute("PWFaded", faded)
		TweenService:Create(core, TweenInfo.new(0.15), {
			Transparency = faded and PortalWalk.CoreFadeTransparency or 0.1
		}):Play()
	end

	-- desfaz tudo (portal fechou / morreu / desequipou)
	local function releasePortalWalk()
		restoreCollisions(nil)
		unhideBody()
		for model in pairs(PortalWalk.Clones) do
			destroyPortalClone(model)
		end
		setCoresFaded(bluePortal, false)
		setCoresFaded(orangePortal, false)
		PortalWalk.PrevPos = nil
	end

	-- animação de deslizar + giro da câmera (versão fluida)
	-- Como funciona: a câmera "real" (a que o script padrão do Roblox calcula) nunca é
	-- contaminada pelo efeito. Antes do script da câmera rodar, restauramos o CFrame real;
	-- depois que ele roda, desenhamos a câmera "visual" = real + (deslocamento e giro) * k,
	-- onde k vai de 1 -> 0 com easing. Assim o mouse/touch continua funcionando normal,
	-- não há acúmulo de giro entre frames e o giro é feito em volta do personagem (sem tremer).
	local CAM_PRE_BIND = "PortalGunCamSlidePre"
	local CAM_POST_BIND = "PortalGunCamSlidePost"
	local camSlide = nil -- { real, posOff, yawOff, t0, dur, dirty }

	-- ângulo horizontal (yaw) de um CFrame; usa o UpVector quando está olhando reto pra cima/baixo
	local function camYaw(cf)
		local v = cf.LookVector
		if Vector3.new(v.X, 0, v.Z).Magnitude < 0.25 then
			v = cf.UpVector
		end
		return math.atan2(-v.X, -v.Z)
	end

	local function wrapAngle(a)
		return (a + math.pi) % (2 * math.pi) - math.pi
	end

	local function camEase(a)
		return TweenService:GetValue(
			a,
			Config.CamSlideStyle or Enum.EasingStyle.Cubic,
			Config.CamSlideDirection or Enum.EasingDirection.Out
		)
	end

	-- gira o CFrame em volta de um ponto (só no eixo Y)
	local function rotateAbout(cf, pivot, yaw)
		return CFrame.new(pivot) * CFrame.Angles(0, yaw, 0) * CFrame.new(-pivot) * cf
	end

	local function stopCamSlide()
		local s = camSlide
		camSlide = nil
		pcall(function() RunService:UnbindFromRenderStep(CAM_PRE_BIND) end)
		pcall(function() RunService:UnbindFromRenderStep(CAM_POST_BIND) end)
		-- devolve a câmera real pro script padrão (sem sobra do efeito)
		if s and s.dirty then
			local c = workspace.CurrentCamera
			if c then pcall(function() c.CFrame = s.real end) end
		end
	end

	local function startCamSlide(realNew, visualOld, pivot, dur)
		if not Config.CamSlide then return end
		dur = math.max(dur or Config.CamSlideDuration or 0.5, 0.05)

		pcall(function() RunService:UnbindFromRenderStep(CAM_PRE_BIND) end)
		pcall(function() RunService:UnbindFromRenderStep(CAM_POST_BIND) end)

		-- offsets calculados pra o primeiro frame ficar IDÊNTICO à câmera que você via (sem pulo)
		local yawOff = wrapAngle(camYaw(visualOld) - camYaw(realNew))
		local rotated = rotateAbout(realNew, pivot, yawOff)
		local posOff = visualOld.Position - rotated.Position

		local state = { real = realNew, posOff = posOff, yawOff = yawOff, t0 = os.clock(), dur = dur, dirty = true }
		camSlide = state

		-- ANTES da câmera padrão: devolve o CFrame real (ela lê o CFrame anterior pra continuar o giro do mouse)
		RunService:BindToRenderStep(CAM_PRE_BIND, Enum.RenderPriority.Camera.Value - 1, function()
			local c = workspace.CurrentCamera
			if camSlide == state and c and state.dirty then
				c.CFrame = state.real
			end
		end)

		-- DEPOIS da câmera padrão: guarda o CFrame real e aplica o efeito visual
		RunService:BindToRenderStep(CAM_POST_BIND, Enum.RenderPriority.Camera.Value + 1, function()
			if camSlide ~= state then return end
			local c = workspace.CurrentCamera
			if not c or not rootPart or not rootPart.Parent then
				stopCamSlide()
				return
			end

			local real = c.CFrame
			state.real = real

			local a = math.clamp((os.clock() - state.t0) / state.dur, 0, 1)
			local k = 1 - camEase(a)

			local visual = rotateAbout(real, rootPart.Position, state.yawOff * k)
			c.CFrame = visual + state.posOff * k
			state.dirty = true

			if a >= 1 then
				stopCamSlide()
			end
		end)
	end

	-- faz a travessia (teleporte contínuo, mantém posição/rotação/velocidade relativas)
	local function crossPortal(fromCF, toCF)
		local rootCF = rootPart.CFrame
		local newCF = toCF * (FLIP * fromCF:ToObjectSpace(rootCF))
		local newPos = newCF.Position

		-- deixa o boneco em pé (só mantém a direção horizontal)
		local look = newCF.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.3 then
			local up = newCF.UpVector
			flat = Vector3.new(up.X, 0, up.Z)
		end
		if flat.Magnitude < 0.1 then
			local old = rootCF.LookVector
			flat = Vector3.new(old.X, 0, old.Z)
		end
		if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, -1) end
		newCF = CFrame.lookAt(newPos, newPos + flat.Unit)

		-- velocidade atravessa junto
		local v = rootPart.AssemblyLinearVelocity
		local nv = toCF:VectorToWorldSpace(FLIP:VectorToWorldSpace(fromCF:VectorToObjectSpace(v)))
		local out = toCF.LookVector
		local along = nv:Dot(out)
		if along < PortalWalk.MinExitSpeed then
			nv = nv + out * (PortalWalk.MinExitSpeed - along)
		end

		-- câmera gira junto com você
		if not isFiniteVec3(newPos) or not isFiniteVec3(nv) then return end
		local T = toCF * FLIP * fromCF:Inverse()
		local visualOld = camera.CFrame                       -- o que você está vendo agora
		local realOld = camSlide and camSlide.real or visualOld -- câmera real (sem o efeito)
		local realNew = T * realOld
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CFrame = realNew
		end

		-- deslize + giro suaves: a câmera visual começa onde você estava vendo e flui até a real
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			pcall(startCamSlide, realNew, visualOld, newPos, Config.CamSlideDuration)
		end

		rootPart.CFrame = newCF
		rootPart.AssemblyLinearVelocity = nv
		PortalWalk.PrevPos = newPos
	end

	local function checkPortalTouch()
		if not rootPart or not rootPart.Parent then return end

		local rootPos = rootPart.Position
		local prevPos = PortalWalk.PrevPos or rootPos
		PortalWalk.PrevPos = rootPos

		local blueOk = bluePortal and bluePortal.Parent
		local orangeOk = orangePortal and orangePortal.Parent
		local bluePart = blueOk and bluePortal:FindFirstChild("Portal")
		local orangePart = orangeOk and orangePortal:FindFirstChild("Portal")
		if not (bluePart and orangePart) then
			releasePortalWalk()
			return
		end

		local links = {
			{model = bluePortal, part = bluePart, otherModel = orangePortal, otherPart = orangePart},
			{model = orangePortal, part = orangePart, otherModel = bluePortal, otherPart = bluePart},
		}

		-- 1) TRAVESSIA: o root cruzou o plano do portal dentro da abertura
		if (rootPos - prevPos).Magnitude < PortalWalk.MaxStep and not humanoid.SeatPart then
			for _, l in ipairs(links) do
				local fromCF = l.part.CFrame
				local zPrev = fromCF:PointToObjectSpace(prevPos).Z
				local zNow = fromCF:PointToObjectSpace(rootPos).Z
				if zPrev < 0 and zNow >= 0 then
					local t = zPrev / (zPrev - zNow)
					local hit = fromCF:PointToObjectSpace(prevPos:Lerp(rootPos, t))
					if inOpening(hit, l.part.Size.X / 2, l.part.Size.Y / 2, 0.5) then
						crossPortal(fromCF, l.otherPart.CFrame)
						rootPos = rootPart.Position
						break
					end
				end
			end
		end

		-- longe dos dois portais: nada de raycast/overlap por frame (só limpa o que sobrou)
		local nearAny = (rootPos - bluePart.Position).Magnitude < 22 or (rootPos - orangePart.Position).Magnitude < 22
		if not nearAny then
			if next(PortalWalk.Disabled) or next(PortalWalk.Clones) or next(PortalWalk.Hidden) then
				restoreCollisions(nil)
				unhideBody()
				for model in pairs(PortalWalk.Clones) do
					destroyPortalClone(model)
				end
				setCoresFaded(bluePortal, false)
				setCoresFaded(orangePortal, false)
			end
			return
		end

		-- 2) ZONAS: colisão aberta + clone do corpo no portal de saída
		local wantDisabled = {}
		local anyCloneZone = false
		local hideFrom = nil

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = {character}
		local standing = workspace:Raycast(rootPos, Vector3.new(0, -5, 0), rayParams)
		local standingPart = standing and standing.Instance

		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = {character, bluePortal, orangePortal}
		for _, c in pairs(PortalWalk.Clones) do
			table.insert(ignore, c.model)
		end
		overlap.FilterDescendantsInstances = ignore

		for _, l in ipairs(links) do
			local cf = l.part.CFrame
			local halfW, halfH = l.part.Size.X / 2, l.part.Size.Y / 2
			local lp = cf:PointToObjectSpace(rootPos)

			-- colisão: só abre quando seu root está dentro da abertura
			if lp.Z > -PortalWalk.ZoneFront and lp.Z < PortalWalk.ZoneBack and inOpening(lp, halfW, halfH, 0) then
				local isFloorOrCeil = math.abs(cf.LookVector.Y) > 0.7
				local boxCF = cf * CFrame.new(0, 0, 1)
				local boxSize = Vector3.new(halfW * 2 + 2, halfH * 2 + 2, 4)
				for _, p in ipairs(workspace:GetPartBoundsInBox(boxCF, boxSize, overlap)) do
					if p.CanCollide or PortalWalk.Disabled[p] then
						-- em portal de parede, não tira o chão em que você está pisando
						if isFloorOrCeil or p ~= standingPart then
							wantDisabled[p] = true
						end
					end
				end
			end

			-- clone: aparece quando o corpo está perto do plano do portal
			local inCloneZone = lp.Z > -3.5 and lp.Z < 3.5 and inOpening(lp, halfW, halfH, PortalWalk.CloneZoneMargin)
			if inCloneZone then
				anyCloneZone = true
				hideFrom = hideFrom or cf
				local c = PortalWalk.Clones[l.model]
				if not c then
					c = createPortalClone()
					PortalWalk.Clones[l.model] = c
				end
				if c then
					local toCF = l.otherPart.CFrame
					for _, pr in ipairs(c.pairs) do
						local gp, op = pr.gp, pr.op
						if gp.Parent and op.Parent then
							local rel = cf:ToObjectSpace(op.CFrame)
							gp.CFrame = toCF * FLIP * rel
							-- só mostra a parte do corpo que já passou do plano
							local visible = rel.Position.Z > -0.35
							gp.Transparency = visible and pr.trans or 1
							for _, d in ipairs(pr.decals) do
								d[1].Transparency = visible and d[2] or 1
							end
						end
					end
				end
			else
				destroyPortalClone(l.model)
			end
		end

		-- aplica/desfaz colisões
		for p in pairs(wantDisabled) do
			if not PortalWalk.Disabled[p] and p.Parent then
				PortalWalk.Disabled[p] = true
				p.CanCollide = false
			end
		end
		restoreCollisions(wantDisabled)

		-- núcleo do portal fica quase transparente enquanto você atravessa
		setCoresFaded(bluePortal, anyCloneZone)
		setCoresFaded(orangePortal, anyCloneZone)

		-- esconde (só pra você) a metade do corpo que está dentro da parede
		if PortalWalk.HideInsidePart and hideFrom then
			refreshCharParts()
			for _, part in ipairs(PortalWalk.CharParts) do
				if part.Parent and part.Name ~= "HumanoidRootPart" then
					local z = hideFrom:PointToObjectSpace(part.Position).Z
					if z > 0.35 then
						part.LocalTransparencyModifier = 1
						PortalWalk.Hidden[part] = true
					elseif PortalWalk.Hidden[part] then
						part.LocalTransparencyModifier = 0
						PortalWalk.Hidden[part] = nil
					end
				end
			end
		elseif next(PortalWalk.Hidden) then
			unhideBody()
		end
	end

	track(character.Destroying:Connect(releasePortalWalk))

	-- ==================== GRAVITY GUN (ESTÁVEL A QUALQUER DISTÂNCIA) ====================
	local isGravityMode = false
	local isGravityAnimating = false
	local heldPart = nil
	local energyBall = nil
	local energyWeld = nil
	local segmentParts = {}
	local segmentCores = {}
	local nodePositions = {}
	-- Sistema "Pegar": move o objeto direto por CFrame (sem força), então o peso não importa
	local gravityRoot = nil            -- AssemblyRootPart do objeto segurado
	local gravityRel = nil             -- offset do root em relação à parte mirada
	local gravityNoCol = nil           -- NoCollisionConstraints com o personagem
	local gravityStepConn = nil
	local gravityStartCF = nil
	local gravityGrabStart = 0
	local gravityVel = Vector3.zero    -- velocidade estimada (usada no arremesso ao soltar)
	local gravityLastPos = nil
	local gravityCurCF = nil           -- CFrame suavizado atual do objeto
	local gravityLastT = 0
	-- Suavidade: quanto MAIOR, mais rápido/seco segue. Quanto MENOR, mais macio/flutuante.
	local GRAVITY_POS_SMOOTH = 9
	local GRAVITY_ROT_SMOOTH = 6
	local gravityHoldSound = nil
	local gravityHighlight = nil
	local isHoldingFire = false
	local holdStartTime = 0
	local HOLD_THRESHOLD = 0.22
	local gravityExtendProgress = 0
	local gravityEndPos = Vector3.zero 

	local currentHoldDistance = Config.GravityHoldDistance
	local minHoldDistance = 10
	local maxHoldDistance = 100          -- ← agora até 100 metros
	local MIN_DISTANCE_FROM_CHARACTER = 10

	local distUpBtn = nil
	local distDownBtn = nil
	local distButtonsVisible = false
	local hideDistanceButtons -- forward declaration (era chamada antes de ser declarada)

	local function setCrosshairGravity(active)
		crosshairGravity = active
		if updateCrosshair then updateCrosshair() end
	end

	local function destroySegments()
		for _, p in ipairs(segmentParts) do
			if p then p:Destroy() end
		end
		for _, p in ipairs(segmentCores) do
			if p then p:Destroy() end
		end
		table.clear(segmentParts)
		table.clear(segmentCores)
		table.clear(nodePositions)
	end

	local function applyGravityHold(dt)
		if not gravityRoot or not gravityRoot.Parent or not heldPart or not heldPart.Parent then return end

		local cam = camera.CFrame
		local desired = cam.Position + cam.LookVector * currentHoldDistance

		-- LIMITE RÍGIDO: nunca mais perto que 10 metros do personagem
		local toChar = desired - rootPart.Position
		local distToChar = toChar.Magnitude
		if distToChar < MIN_DISTANCE_FROM_CHARACTER then
			if distToChar > 0.1 then
				desired = rootPart.Position + toChar.Unit * MIN_DISTANCE_FROM_CHARACTER
			else
				desired = rootPart.Position + cam.LookVector * MIN_DISTANCE_FROM_CHARACTER
			end
		end

		local targetRoot = (CFrame.new(desired) * cam.Rotation) * gravityRel

		-- suavização exponencial independente de FPS (chamada em Stepped e RenderStepped)
		local now = os.clock()
		local elapsed = math.clamp(now - gravityLastT, 0, 0.1)
		gravityLastT = now
		local aPos = 1 - math.exp(-GRAVITY_POS_SMOOTH * elapsed)
		local aRot = 1 - math.exp(-GRAVITY_ROT_SMOOTH * elapsed)

		local cur = gravityCurCF or gravityStartCF
		local newPos = cur.Position:Lerp(targetRoot.Position, aPos)
		local newRot = cur.Rotation:Lerp(targetRoot.Rotation, aRot)
		local newCF = CFrame.new(newPos) * newRot
		gravityCurCF = newCF

		gravityRoot.CFrame = newCF
		gravityRoot.AssemblyLinearVelocity = Vector3.zero
		gravityRoot.AssemblyAngularVelocity = Vector3.zero

		-- estima a velocidade (só no Stepped, onde temos dt) pra arremessar ao soltar
		if dt and dt > 0 then
			if gravityLastPos then
				local raw = (newCF.Position - gravityLastPos) / dt
				gravityVel = gravityVel:Lerp(raw, 0.5)
			end
			gravityLastPos = newCF.Position
		end
	end

	local function stopGravityHold(applyThrow)
		if gravityStepConn then
			gravityStepConn:Disconnect()
			gravityStepConn = nil
		end

		local root = gravityRoot
		if applyThrow and root and root.Parent and not root.Anchored then
			local v = gravityVel
			if v.Magnitude > 80 then v = v.Unit * 80 end
			root.AssemblyLinearVelocity = v
		end

		local cons = gravityNoCol
		gravityNoCol = nil
		if cons then
			-- mantém sem colisão por um instante pra não bater no player ao soltar
			task.delay(0.7, function()
				for _, c in ipairs(cons) do
					if c then c:Destroy() end
				end
			end)
		end

		gravityRoot = nil
		gravityRel = nil
		gravityStartCF = nil
		gravityCurCF = nil
		gravityLastPos = nil
		gravityVel = Vector3.zero
	end

	local function clearGravityInstant()
		destroySegments()

		if energyWeld then energyWeld:Destroy() energyWeld = nil end
		if energyBall then energyBall:Destroy() energyBall = nil end
		stopGravityHold(false)
		if gravityHoldSound then
			gravityHoldSound:Stop()
			gravityHoldSound:Destroy()
			gravityHoldSound = nil
		end
		if gravityHighlight then
			gravityHighlight:Destroy()
			gravityHighlight = nil
		end
		heldPart = nil
		isGravityMode = false
		isGravityAnimating = false
		gravityExtendProgress = 0
		currentHoldDistance = Config.GravityHoldDistance
		setCrosshairGravity(false)

		if distButtonsVisible then
			hideDistanceButtons()
		end
	end

	local function createSegment()
		local outer = Instance.new("Part")
		outer.Name = "EnergyCord"
		outer.Anchored = true
		outer.CanCollide = false
		outer.CanQuery = false
		outer.CastShadow = false
		outer.Material = Enum.Material.Neon
		outer.Color = Config.GravityLineColor
		outer.Transparency = 0.2
		outer.Size = Vector3.new(0.12, 0.12, 1)
		outer.Parent = workspace

		local core = Instance.new("Part")
		core.Name = "EnergyCordCore"
		core.Anchored = true
		core.CanCollide = false
		core.CanQuery = false
		core.CastShadow = false
		core.Material = Enum.Material.Neon
		core.Color = Color3.fromRGB(255, 240, 120)
		core.Transparency = 0.05
		core.Size = Vector3.new(0.05, 0.05, 1)
		core.Parent = workspace

		return outer, core
	end


	-- ==================== BOTÕES DE DISTÂNCIA ====================
	local function createDistanceButton(parentGui, name, text, accentColor)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(0, 72, 0, 72)
		btn.BackgroundColor3 = Color3.new(1, 1, 1)
		btn.BackgroundTransparency = 1
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Visible = false
		btn.Parent = parentGui
		glassGradient(btn)

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.8
		stroke.Transparency = 1
		stroke.Parent = btn
		tintStroke(stroke, accentColor, true)

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = Theme.Text
		label.TextSize = 30
		label.Font = Enum.Font.GothamBlack
		label.TextTransparency = 1
		label.Parent = btn

		local press = Instance.new("UIScale")
		press.Parent = btn
		btn.MouseButton1Down:Connect(function() TweenService:Create(press, TweenInfo.new(0.08), {Scale = 0.92}):Play() end)
		btn.MouseButton1Up:Connect(function() TweenService:Create(press, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play() end)

		return btn, stroke, label
	end

	local function showDistanceButtons()
		if distButtonsVisible then return end
		if not distUpBtn or not distDownBtn then return end
		distButtonsVisible = true

		local finalUp = UDim2.new(1, -98, 1, -365)
		local finalDown = UDim2.new(1, -98, 1, -455)

		distUpBtn.Position = UDim2.new(1, 40, 1, -365)
		distDownBtn.Position = UDim2.new(1, 40, 1, -455)
		distUpBtn.Visible = true
		distDownBtn.Visible = true

		local ti = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

		TweenService:Create(distUpBtn, ti, {
			Position = finalUp,
			BackgroundTransparency = 0.15
		}):Play()
		TweenService:Create(distDownBtn, ti, {
			Position = finalDown,
			BackgroundTransparency = 0.15
		}):Play()

		local upStroke = distUpBtn:FindFirstChildOfClass("UIStroke")
		local downStroke = distDownBtn:FindFirstChildOfClass("UIStroke")
		local upLabel = distUpBtn:FindFirstChild("Label")
		local downLabel = distDownBtn:FindFirstChild("Label")

		if upStroke then TweenService:Create(upStroke, ti, {Transparency = 0.15}):Play() end
		if downStroke then TweenService:Create(downStroke, ti, {Transparency = 0.15}):Play() end
		if upLabel then TweenService:Create(upLabel, ti, {TextTransparency = 0}):Play() end
		if downLabel then TweenService:Create(downLabel, ti, {TextTransparency = 0}):Play() end
	end

	function hideDistanceButtons()
		if not distButtonsVisible then return end
		distButtonsVisible = false

		if not distUpBtn or not distDownBtn then return end

		local ti = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

		TweenService:Create(distUpBtn, ti, {
			Position = UDim2.new(1, 40, 1, -365),
			BackgroundTransparency = 1
		}):Play()
		TweenService:Create(distDownBtn, ti, {
			Position = UDim2.new(1, 40, 1, -455),
			BackgroundTransparency = 1
		}):Play()

		local upStroke = distUpBtn:FindFirstChildOfClass("UIStroke")
		local downStroke = distDownBtn:FindFirstChildOfClass("UIStroke")
		local upLabel = distUpBtn:FindFirstChild("Label")
		local downLabel = distDownBtn:FindFirstChild("Label")

		if upStroke then TweenService:Create(upStroke, ti, {Transparency = 1}):Play() end
		if downStroke then TweenService:Create(downStroke, ti, {Transparency = 1}):Play() end
		if upLabel then TweenService:Create(upLabel, ti, {TextTransparency = 1}):Play() end
		if downLabel then TweenService:Create(downLabel, ti, {TextTransparency = 1}):Play() end

		task.delay(0.3, function()
			if not distButtonsVisible then
				if distUpBtn then distUpBtn.Visible = false end
				if distDownBtn then distDownBtn.Visible = false end
			end
		end)
	end

	local function tryGrabGravity()
		if heldPart or isGravityAnimating then return end

		local origin = camera.CFrame.Position
		local direction = camera.CFrame.LookVector * Config.GravityMaxDistance

		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = buildIgnore(character, bluePortal, orangePortal)
		rayParams.FilterType = Enum.RaycastFilterType.Exclude

		local result = workspace:Raycast(origin, direction, rayParams)
		if not result or not result.Instance or not result.Instance:IsA("BasePart") then
			return
		end

		local part = result.Instance
		if part.Anchored then return end
		if part:IsDescendantOf(character) then return end

		local mass = part.AssemblyMass or part.Mass
		if mass < 0.1 then return end

		-- Sem limite de peso: pega o assembly inteiro pelo root e move por CFrame
		local root = part.AssemblyRootPart
		if not root or root.Anchored or root:IsDescendantOf(character) then return end

		local conjunto, preso = {}, false
		for _, q in ipairs(root:GetConnectedParts(true)) do
			if q.AssemblyRootPart == root then
				conjunto[#conjunto + 1] = q
			elseif q.AssemblyRootPart and q.AssemblyRootPart.Anchored then
				preso = true
			end
		end
		if preso then return end

		isGravityAnimating = true
		heldPart = part
		isGravityMode = true
		gravityExtendProgress = 0
		gravityEndPos = result.Position

		minHoldDistance = 10
		currentHoldDistance = math.clamp(Config.GravityHoldDistance, minHoldDistance, maxHoldDistance)

		energyBall = Instance.new("Part")
		energyBall.Name = "GravityEnergyBall"
		energyBall.Shape = Enum.PartType.Ball
		energyBall.Size = Vector3.new(0.05, 0.05, 0.05)
		energyBall.Material = Enum.Material.Neon
		energyBall.Color = Config.GravityLineColor
		energyBall.Transparency = 0.15
		energyBall.CanCollide = false
		energyBall.CanQuery = false
		energyBall.CastShadow = false
		energyBall.Massless = true
		energyBall.CFrame = handle.CFrame * CFrame.new(0, -0.05, -2)
		energyBall.Parent = workspace

		local energySparks = Instance.new("ParticleEmitter")
		energySparks.Name = "EnergySparks"
		energySparks.Texture = Config.ParticleSpark
		energySparks.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.4, Config.GravityLineColor),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 120))
		})
		energySparks.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(0.5, 0.22),
			NumberSequenceKeypoint.new(1, 0)
		})
		energySparks.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.6, 0.5),
			NumberSequenceKeypoint.new(1, 1)
		})
		energySparks.Lifetime = NumberRange.new(0.25, 0.45)
		energySparks.Rate = 22
		energySparks.Speed = NumberRange.new(1.0, 2.8)
		energySparks.SpreadAngle = Vector2.new(180, 180)
		energySparks.LightEmission = 1
		energySparks.LightInfluence = 0
		energySparks.LockedToPart = true
		energySparks.Parent = energyBall

		local energyCore = Instance.new("ParticleEmitter")
		energyCore.Name = "EnergyCore"
		energyCore.Texture = Config.ParticleSpark
		energyCore.Color = ColorSequence.new(Color3.fromRGB(255, 245, 180))
		energyCore.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.28),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(1, 0.55)
		})
		energyCore.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.5, 0.6),
			NumberSequenceKeypoint.new(1, 1)
		})
		energyCore.Lifetime = NumberRange.new(0.3, 0.5)
		energyCore.Rate = 10
		energyCore.Speed = NumberRange.new(0.1, 0.5)
		energyCore.SpreadAngle = Vector2.new(180, 180)
		energyCore.LightEmission = 0.9
		energyCore.LightInfluence = 0
		energyCore.LockedToPart = true
		energyCore.Parent = energyBall

		energyWeld = Instance.new("WeldConstraint")
		energyWeld.Part0 = energyBall
		energyWeld.Part1 = handle
		energyWeld.Parent = energyBall

		setCrosshairGravity(true)
		playSound(Config.SoundShoot, 0.55, handle)
		task.spawn(playRecoil)
		playMuzzleFlash(Config.GravityLineColor)

		showDistanceButtons()

		local growTween = TweenService:Create(energyBall, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.62, 0.62, 0.62)
		})
		growTween:Play()
		growTween.Completed:Wait()

		if not isGravityMode or not heldPart or not heldPart.Parent then
			clearGravityInstant()
			return
		end

		local numNodes = Config.LineSegments - 1
		for i = 1, numNodes do
			table.insert(nodePositions, energyBall.Position)
		end

		for i = 1, Config.LineSegments do
			local outer, core = createSegment()
			table.insert(segmentParts, outer)
			table.insert(segmentCores, core)
		end

		local extendStart = tick()
		local extendDuration = 0.18

		while tick() - extendStart < extendDuration do
			if not isGravityMode then break end
			local alpha = math.clamp((tick() - extendStart) / extendDuration, 0, 1)
			gravityExtendProgress = 1 - (1 - alpha) * (1 - alpha)
			task.wait()
		end
		gravityExtendProgress = 1

		if not isGravityMode or not heldPart or not heldPart.Parent then
			clearGravityInstant()
			return
		end

		gravityHighlight = Instance.new("Highlight")
		gravityHighlight.Name = "GravityHighlight"
		gravityHighlight.Adornee = heldPart
		gravityHighlight.FillTransparency = 1
		gravityHighlight.OutlineTransparency = 1
		gravityHighlight.OutlineColor = Color3.fromRGB(255, 210, 40)
		gravityHighlight.FillColor = Color3.fromRGB(255, 210, 40)
		gravityHighlight.DepthMode = Enum.HighlightDepthMode.Occluded 
		gravityHighlight.Parent = heldPart

		TweenService:Create(gravityHighlight, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			OutlineTransparency = 0
		}):Play()

		-- o objeto pode ter sido destruído/ancorado durante a animação
		if not root.Parent or root.Anchored then
			clearGravityInstant()
			return
		end

		-- NoCollision com o personagem: objeto pesado não empurra o player
		gravityNoCol = {}
		local partesChar = {}
		for _, c in ipairs(character:GetChildren()) do
			if c:IsA("BasePart") then partesChar[#partesChar + 1] = c end
		end
		for i = 1, math.min(#conjunto, 30) do
			for _, c in ipairs(partesChar) do
				local n = Instance.new("NoCollisionConstraint")
				n.Part0, n.Part1 = conjunto[i], c
				n.Parent = root
				gravityNoCol[#gravityNoCol + 1] = n
			end
		end

		gravityRoot = root
		gravityRel = part.CFrame:ToObjectSpace(root.CFrame)
		gravityStartCF = root.CFrame
		gravityCurCF = root.CFrame
		gravityLastT = os.clock()
		gravityGrabStart = os.clock()
		gravityLastPos = nil
		gravityVel = Vector3.zero

		-- Stepped + RenderStepped (como no Pegar) pra ficar firme em qualquer peso
		gravityStepConn = RunService.Stepped:Connect(function(_, dt)
			if isGravityMode and not isGravityAnimating then
				applyGravityHold(dt)
			end
		end)

		gravityHoldSound = Instance.new("Sound")
		gravityHoldSound.Name = "GravityHoldSound"
		gravityHoldSound.SoundId = Config.SoundGravityHold
		gravityHoldSound.Volume = 2
		gravityHoldSound.Looped = true
		gravityHoldSound.Parent = handle
		gravityHoldSound:Play()

		isGravityAnimating = false
	end

	local function updateGravityLine()
		if not energyBall or not energyBall.Parent then return end
		if #segmentParts == 0 then return end
		if not heldPart or not heldPart.Parent then return end

		local startPos = energyBall.Position
		local endPos = heldPart.Position
		gravityEndPos = endPos

		local numNodes = #nodePositions
		local totalDist = (endPos - startPos).Magnitude * gravityExtendProgress
		local effectiveEnd = startPos:Lerp(endPos, gravityExtendProgress)

		local tNow = tick()

		local restLength = currentHoldDistance * 0.85
		local stretch = math.clamp((totalDist - restLength) / (Config.GravityMaxDistance * 0.6), 0, 1)
		local tension = 1 - stretch * 0.72

		local baseSag = math.clamp(totalDist * 0.058, 0.25, 2.8) * tension * gravityExtendProgress
		local wave1 = math.sin(tNow * 3.35) * 0.26 * tension
		local wave2 = math.sin(tNow * 5.9 + 0.7) * 0.16 * tension
		local wave3 = math.cos(tNow * 8.7 + 1.9) * 0.11 * tension
		local wave4 = math.sin(tNow * 12.1 + 0.35) * 0.07 * tension
		local wave5 = math.cos(tNow * 4.55 + 1.55) * 0.09 * tension
		local wave6 = math.sin(tNow * 15.8 + 2.4) * 0.045 * tension
		local wave7 = math.cos(tNow * 7.2 + 0.9) * 0.06 * tension

		for i = 1, numNodes do
			local t = i / (numNodes + 1)
			local ideal = startPos:Lerp(effectiveEnd, t)

			local sagCurve = math.sin(t * math.pi)
			local sagAmount = (baseSag + wave1) * sagCurve
			sagAmount = sagAmount + math.sin(t * math.pi * 2) * 0.14 * wave5
			sagAmount = sagAmount + math.sin(t * math.pi * 3) * 0.07 * wave7
			local sag = Vector3.new(0, -sagAmount, 0)

			local dir = (effectiveEnd - startPos)
			if dir.Magnitude > 0.1 then
				dir = dir.Unit
			else
				dir = Vector3.new(0, 0, -1)
			end
			local right = dir:Cross(Vector3.new(0, 1, 0))
			if right.Magnitude < 0.1 then
				right = dir:Cross(Vector3.new(1, 0, 0))
			end
			right = right.Unit
			local up = right:Cross(dir).Unit

			local foldA = math.sin(t * math.pi * 2.0 + tNow * 3.25) * wave2
			local foldB = math.sin(t * math.pi * 3.4 - tNow * 5.4) * wave3
			local foldC = math.sin(t * math.pi * 5.1 + tNow * 7.9) * wave4
			local foldD = math.cos(t * math.pi * 1.6 + tNow * 2.75) * wave5
			local foldE = math.sin(t * math.pi * 6.8 + tNow * 11.2) * wave6
			local foldF = math.cos(t * math.pi * 4.2 - tNow * 6.6) * wave7

			local lateral = right * (foldA * 0.62 + foldC * 0.32 + foldE * 0.22)
				+ up * (foldB * 0.48 + foldD * 0.28 + foldF * 0.18)

			ideal = ideal + sag + lateral
			nodePositions[i] = ideal
		end

		local points = {startPos}
		for i = 1, numNodes do
			table.insert(points, nodePositions[i])
		end
		table.insert(points, effectiveEnd)

		local pulse = 0.86 + math.sin(tNow * 11.2) * 0.14

		for i = 1, #points - 1 do
			local p0 = points[i]
			local p1 = points[i + 1]
			local dist = (p1 - p0).Magnitude

			local outer = segmentParts[i]
			local core = segmentCores[i]
			if outer and core then
				if dist < 0.02 then
					outer.Size = Vector3.new(0.01, 0.01, 0.01)
					core.Size = Vector3.new(0.01, 0.01, 0.01)
				else
					local cf = CFrame.lookAt(p0, p1) * CFrame.new(0, 0, -dist * 0.5)

					local tSeg = (i - 0.5) / (#points - 1)
					local thickMul = 1 + math.sin(tSeg * math.pi) * 0.28
					local thick = 0.165 * pulse * thickMul * gravityExtendProgress
					local cthick = 0.072 * pulse * thickMul * gravityExtendProgress

					outer.Size = Vector3.new(thick, thick, dist + 0.04)
					outer.CFrame = cf
					core.Size = Vector3.new(cthick, cthick, dist + 0.04)
					core.CFrame = cf
				end
			end
		end

		local ballPulse = 0.58 + math.sin(tNow * 8.6) * 0.10
		if energyBall and energyBall.Parent then
			energyBall.Size = Vector3.new(ballPulse, ballPulse, ballPulse)
		end
	end

	local releaseGravity

	local function updateGravity()
		if not isGravityMode then return end

		if energyBall and energyBall.Parent and heldPart and heldPart.Parent then
			updateGravityLine()
		end

		if isGravityAnimating then return end

		if not heldPart or not heldPart.Parent then
			clearGravityInstant()
			return
		end

		if not gravityRoot or not gravityRoot.Parent or gravityRoot.Anchored then
			clearGravityInstant()
			return
		end

		applyGravityHold()

		if (heldPart.Position - handle.Position).Magnitude > Config.GravityMaxDistance + 15 then
			releaseGravity()
		end
	end

	function releaseGravity()
		if not isGravityMode or isGravityAnimating then return end
		isGravityAnimating = true

		playSound(Config.SoundGravityRelease, 1.2, handle)

		stopGravityHold(true)
		if gravityHoldSound then
			gravityHoldSound:Stop()
			gravityHoldSound:Destroy()
			gravityHoldSound = nil
		end

		if gravityHighlight and gravityHighlight.Parent then
			local fadeOut = TweenService:Create(gravityHighlight, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				OutlineTransparency = 1
			})
			fadeOut:Play()
			fadeOut.Completed:Connect(function()
				if gravityHighlight then
					gravityHighlight:Destroy()
					gravityHighlight = nil
				end
			end)
		end

		hideDistanceButtons()

		local retractStart = tick()
		local retractDuration = 0.32

		while tick() - retractStart < retractDuration do
			local alpha = math.clamp((tick() - retractStart) / retractDuration, 0, 1)
			gravityExtendProgress = 1 - (alpha * alpha)
			task.wait()
		end
		gravityExtendProgress = 0

		destroySegments()

		if energyBall and energyBall.Parent then
			local shrink = TweenService:Create(energyBall, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Size = Vector3.new(0.02, 0.02, 0.02),
				Transparency = 1
			})
			shrink:Play()
			shrink.Completed:Wait()
		end

		if energyWeld then energyWeld:Destroy() energyWeld = nil end
		if energyBall then energyBall:Destroy() energyBall = nil end

		heldPart = nil
		isGravityMode = false
		isGravityAnimating = false
		gravityExtendProgress = 0
		currentHoldDistance = Config.GravityHoldDistance
		setCrosshairGravity(false)
	end

	-- ==================== GUIS DA PORTAL GUN ====================
	local gui = Instance.new("ScreenGui")
	gui.Name = "PortalGunGui"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	parentGui(gui)
	currentPortalGunGui = gui

	-- Crosshair feita só com UI (sem imagem): anel oval azul/laranja inclinado
	crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.Size = UDim2.new(0, 72, 0, 72)
	crosshair.Position = UDim2.new(0.5, -36, 0.5, Config.CrosshairYOffset)
	crosshair.BackgroundTransparency = 1
	crosshair.Visible = false
	crosshair.Parent = gui

	local CROSS_A, CROSS_B = 21, 31          -- semi-eixos da elipse (largura/altura)
	local CROSS_TILT = math.rad(8)           -- inclinação (graus, sentido horário)
	local CROSS_MAX = 6                      -- espessura máxima do arco
	local CROSS_SEGMENTS = 90                -- mais = mais liso
	local CROSS_GLOW_SEGMENTS = 40

	local function makeCrossGroup(name, z)
		local g = Instance.new("CanvasGroup")
		g.Name = name
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.new(0.5, 0, 0.5, 0)
		g.Size = UDim2.new(0, 84, 0, 84)
		g.BackgroundTransparency = 1
		g.BorderSizePixel = 0
		g.ZIndex = z
		g.Parent = crosshair
		return g
	end

	local function addCrossSegments(group, startDeg, endDeg, count, thickMul, thickAdd)
		local s, e = math.rad(startDeg), math.rad(endDeg)
		local dphi = (e - s) / count
		local c, sn = math.cos(CROSS_TILT), math.sin(CROSS_TILT)
		for i = 1, count do
			local phi = s + (i - 0.5) * dphi
			local x, y = CROSS_A * math.cos(phi), CROSS_B * math.sin(phi)
			local tx, ty = -CROSS_A * math.sin(phi), CROSS_B * math.cos(phi)
			local px, py = x * c - y * sn, x * sn + y * c
			local dx, dy = tx * c - ty * sn, tx * sn + ty * c
			local u = (i - 0.5) / count
			local thick = math.max(1.5, CROSS_MAX * math.sin(math.pi * u) ^ 0.7) * thickMul + thickAdd

			local seg = Instance.new("Frame")
			seg.AnchorPoint = Vector2.new(0.5, 0.5)
			seg.Position = UDim2.new(0.5, px, 0.5, py)
			seg.Size = UDim2.new(0, math.sqrt(dx * dx + dy * dy) * dphi + 1.5, 0, thick)
			seg.Rotation = math.deg(math.atan2(dy, dx))
			seg.BackgroundColor3 = Color3.new(1, 1, 1) -- a cor vem do GroupColor3
			seg.BorderSizePixel = 0
			seg.Parent = group
			Instance.new("UICorner", seg).CornerRadius = UDim.new(1, 0)
		end
	end

	local crossArcs = {}
	local function buildCrossArc(key, startDeg, endDeg)
		local glow = makeCrossGroup(key .. "Glow", 1)
		local core = makeCrossGroup(key, 2)
		addCrossSegments(glow, startDeg, endDeg, CROSS_GLOW_SEGMENTS, 1.8, 3)
		addCrossSegments(core, startDeg, endDeg, CROSS_SEGMENTS, 1, 0)
		crossArcs[key] = {core = core, glow = glow}
	end

	buildCrossArc("Blue", 145, 305)    -- arco azul (esquerda/cima)
	buildCrossArc("Orange", -35, 125)  -- arco laranja (direita/baixo)

	-- Destaca o arco do portal que será disparado agora; o outro fica escuro
	updateCrosshair = function()
		local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		for _, isBlue in ipairs({true, false}) do
			local arc = isBlue and crossArcs.Blue or crossArcs.Orange
			local base = isBlue and Config.BlueColor or Config.OrangeColor
			local coreColor, coreTrans, glowColor, glowTrans
			if crosshairGravity then
				coreColor, coreTrans = Config.GravityLineColor, 0
				glowColor, glowTrans = Config.GravityLineColor, 0.8
			elseif isBlue == nextIsBlue then
				coreColor, coreTrans = base:Lerp(Color3.new(1, 1, 1), 0.25), 0
				glowColor, glowTrans = base, 0.72
			else
				coreColor, coreTrans = base:Lerp(Color3.new(0, 0, 0), 0.62), 0.2
				glowColor, glowTrans = base, 1
			end
			TweenService:Create(arc.core, info, {GroupColor3 = coreColor, GroupTransparency = coreTrans}):Play()
			TweenService:Create(arc.glow, info, {GroupColor3 = glowColor, GroupTransparency = glowTrans}):Play()
		end
	end
	updateCrosshair()

	local function setTechAccent(btn, color)
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then tintStroke(stroke, color, true) end
		local glow = btn:FindFirstChild("Glow")
		if glow then TweenService:Create(glow, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play() end
		for _, n in ipairs({"Sub", "Tag"}) do
			local l = btn:FindFirstChild(n)
			if l then l.TextColor3 = color end
		end
	end

	local function createTechButton(name, text, position, accentColor, subText, tagText)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(0, 78, 0, 78)
		btn.Position = position
		btn.BackgroundColor3 = Color3.new(1, 1, 1)
		btn.BackgroundTransparency = 0.12
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Visible = false
		btn.Parent = gui
		glassGradient(btn)

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.8
		stroke.Transparency = 0.1
		stroke.Parent = btn
		tintStroke(stroke, accentColor, true)

		local press = Instance.new("UIScale")
		press.Parent = btn

		local function lbl(n, t, font, size, pos, sz, xAlign)
			local l = Instance.new("TextLabel")
			l.Name = n
			l.BackgroundTransparency = 1
			l.Text = t
			l.Font = font
			l.TextSize = size
			l.Position = pos
			l.Size = sz
			l.TextColor3 = Theme.Text
			l.TextXAlignment = xAlign or Enum.TextXAlignment.Center
			l.Parent = btn
			return l
		end
		local tag = lbl("Tag", tagText or "01", Enum.Font.Code, 10, UDim2.fromOffset(9, 6), UDim2.fromOffset(20, 12), Enum.TextXAlignment.Left)
		tag.TextColor3 = accentColor
		tag.TextTransparency = 0.25
		lbl("Label", text, Enum.Font.GothamBlack, 18, UDim2.new(0, 0, 0.3, 0), UDim2.new(1, 0, 0, 22))
		local sub = lbl("Sub", subText or "PORTAL", Enum.Font.Code, 9, UDim2.new(0, 0, 0.62, 0), UDim2.new(1, 0, 0, 12))
		sub.TextColor3 = accentColor

		local glow = Instance.new("Frame")
		glow.Name = "Glow"
		glow.AnchorPoint = Vector2.new(0.5, 1)
		glow.Position = UDim2.new(0.5, 0, 1, -8)
		glow.Size = UDim2.fromOffset(30, 3)
		glow.BackgroundColor3 = accentColor
		glow.BorderSizePixel = 0
		glow.Parent = btn
		Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)
		TweenService:Create(glow, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.65}):Play()

		btn.MouseButton1Down:Connect(function() TweenService:Create(press, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.92}):Play() end)
		btn.MouseButton1Up:Connect(function() TweenService:Create(press, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play() end)
		btn.MouseLeave:Connect(function() TweenService:Create(press, TweenInfo.new(0.15), {Scale = 1}):Play() end)

		return btn, stroke
	end

	local shootBtn, shootStroke = createTechButton("ShootButton", "FIRE", UDim2.new(1, -98, 1, -175), Config.BlueColor, "TAP · HOLD", "01")
	local toggleBtn, toggleStroke = createTechButton("ToggleButton", "SWAP", UDim2.new(1, -98, 1, -270), Config.OrangeColor, "CHANNEL", "02")

	-- Cria os botões de distância (agora com parent explícito)
	local upStroke, upLabel
	distUpBtn, upStroke, upLabel = createDistanceButton(gui, "DistUpButton", "+", Config.GravityLineColor)
	local downStroke, downLabel
	distDownBtn, downStroke, downLabel = createDistanceButton(gui, "DistDownButton", "−", Config.GravityLineColor)

	distUpBtn.MouseButton1Click:Connect(function()
		if not isGravityMode then return end
		currentHoldDistance = math.clamp(currentHoldDistance + 2.5, minHoldDistance, maxHoldDistance)
	end)

	distDownBtn.MouseButton1Click:Connect(function()
		if not isGravityMode then return end
		currentHoldDistance = math.clamp(currentHoldDistance - 2.5, minHoldDistance, maxHoldDistance)
	end)

	local function addDistHover(btn, stroke)
		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.05}):Play()
			if stroke then TweenService:Create(stroke, TweenInfo.new(0.15), {Thickness = 2.4}):Play() end
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.15}):Play()
			if stroke then TweenService:Create(stroke, TweenInfo.new(0.15), {Thickness = 1.8}):Play() end
		end)
	end
	addDistHover(distUpBtn, upStroke)
	addDistHover(distDownBtn, downStroke)

	local colorIndicator = Instance.new("Frame")
	colorIndicator.Size = UDim2.new(0, 14, 0, 14)
	colorIndicator.Position = UDim2.new(1, -20, 0, 8)
	colorIndicator.BackgroundColor3 = Config.BlueColor
	colorIndicator.BorderSizePixel = 0
	colorIndicator.Parent = toggleBtn

	local indCorner = Instance.new("UICorner")
	indCorner.CornerRadius = UDim.new(1, 0)
	indCorner.Parent = colorIndicator

	updateToggleButton = function()
		if nextIsBlue then
			colorIndicator.BackgroundColor3 = Config.BlueColor
			setTechAccent(toggleBtn, Config.BlueColor)
			setTechAccent(shootBtn, Config.BlueColor)
		else
			colorIndicator.BackgroundColor3 = Config.OrangeColor
			setTechAccent(toggleBtn, Config.OrangeColor)
			setTechAccent(shootBtn, Config.OrangeColor)
		end
	end

	local function onFirePressed()
		if not isEquipped or isEquipping then return end
		isHoldingFire = true
		holdStartTime = tick()
		if isGravityMode then
			releaseGravity()
			return
		end
	end

	local function onFireReleased()
		if not isEquipped or isEquipping then return end
		local heldTime = tick() - holdStartTime
		isHoldingFire = false
		if isGravityMode then
			releaseGravity()
			return
		end
		if heldTime < HOLD_THRESHOLD then
			placePortal()
		end
	end

	shootBtn.MouseButton1Down:Connect(function()
		onFirePressed()
	end)

	shootBtn.MouseButton1Up:Connect(function()
		onFireReleased()
	end)

	toggleBtn.MouseButton1Click:Connect(function()
		if isEquipping then return end
		nextIsBlue = not nextIsBlue
		if updateCrosshair then updateCrosshair() end
		if updateToggleButton then updateToggleButton() end
	end)

	local function addHover(btn, stroke)
		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.05}):Play()
			TweenService:Create(stroke, TweenInfo.new(0.15), {Thickness = 2.4}):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.15}):Play()
			TweenService:Create(stroke, TweenInfo.new(0.15), {Thickness = 1.8}):Play()
		end)
	end

	addHover(shootBtn, shootStroke)
	addHover(toggleBtn, toggleStroke)

	track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not isEquipped or isEquipping then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onFirePressed()
		end
	end))

	track(UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if not isEquipped or isEquipping then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onFireReleased()
		end
	end))

	track(UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if not isGravityMode or not isEquipped then return end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local delta = input.Position.Z
			currentHoldDistance = math.clamp(currentHoldDistance - delta * 1.8, minHoldDistance, maxHoldDistance)
		end
	end))

	track(tool.Equipped:Connect(function()
		isEquipped = true
		isEquipping = true
		removeHolster()
		if crosshair then crosshair.Visible = true end
		shootBtn.Visible = true
		toggleBtn.Visible = true
		if updateCrosshair then updateCrosshair() end
		if updateToggleButton then updateToggleButton() end
		playSound(Config.SoundEquip, 1, handle)

		freezeCharacter()
		playEquipAnim()

		task.delay(0.3, function()
			if isEquipped then
				unfreezeCharacter()
				isEquipping = false
			end
		end)

		if updateConnection then
			updateConnection:Disconnect()
		end

		updateConnection = RunService.RenderStepped:Connect(function()
			updateIdle()
			checkPortalTouch()
			updateGravity()
			updatePortalsPosition()
			if isHoldingFire and not isGravityMode and not isEquipping and not isGravityAnimating and (tick() - holdStartTime) >= HOLD_THRESHOLD then
				tryGrabGravity()
			end
		end)
	end))

	track(tool.Unequipped:Connect(function()
		isEquipped = false
		isEquipping = false
		isShootingPortal = false
		if crosshair then crosshair.Visible = false end
		shootBtn.Visible = false
		toggleBtn.Visible = false
		stopIdle()
		stopEquipAnim()
		stopShootAnim()
		unfreezeCharacter()
		clearGravityInstant()
		isHoldingFire = false
		createHolster()

		if updateConnection then
			updateConnection:Disconnect()
		end

		updateConnection = RunService.RenderStepped:Connect(function()
			checkPortalTouch()
			updatePortalsPosition()
		end)
	end))

	track(humanoid.Died:Connect(function()
		releasePortalWalk()
		if updateConnection then
			updateConnection:Disconnect()
			updateConnection = nil
		end
		
		isShootingPortal = false
		stopShootAnim()
		blueToken = blueToken + 1
		orangeToken = orangeToken + 1
		clearGravityInstant()
		removeHolster()
		portalsLinked = false

		blueHostPart = nil
		blueRelativeCF = nil
		orangeHostPart = nil
		orangeRelativeCF = nil

		if bluePortal then
			task.spawn(function()
				closePortal(bluePortal)
			end)
			bluePortal = nil
		end

		if orangePortal then
			task.spawn(function()
				closePortal(orangePortal)
			end)
			orangePortal = nil
		end
	end))

	-- Iniciação final
	if updateCrosshair then updateCrosshair() end
	if updateToggleButton then updateToggleButton() end
	createHolster()
	
	updateConnection = RunService.RenderStepped:Connect(function()
		checkPortalTouch()
		updatePortalsPosition()
	end)

	-- vigia: jogos que removem a tool / a UI -> recoloca ou reconstrói (no máximo 3x por spawn)
	task.spawn(function()
		while Z.alive and scriptAlive and character and character.Parent do
			task.wait(0.5)
			if not (Z.alive and scriptAlive and character.Parent) then break end
			local needRebuild = false

			if tool.Parent ~= backpack and tool.Parent ~= character then
				local okP = pcall(function() tool.Parent = backpack end)
				if not okP or tool.Parent ~= backpack then needRebuild = true end
			end

			if not needRebuild then
				for _, g in ipairs({gui, HotbarGui}) do
					if not g.Parent then parentGui(g) end
					if not g.Parent then needRebuild = true end
				end
			end

			if needRebuild then
				if PGState.rebuilds < 3 then
					PGState.rebuilds = PGState.rebuilds + 1
					task.defer(safeSetup, character)
				end
				break
			end
		end
	end)

	-- limpeza completa (respawn / reexecução / rebuild)
	Z.extra = function()
		pcall(releasePortalWalk)
		pcall(clearGravityInstant)
		pcall(unfreezeCharacter)
		pcall(stopIdle)
		pcall(stopEquipAnim)
		pcall(stopShootAnim)
		pcall(stopCamSlide)
		pcall(removeHolster)
		if updateConnection then
			pcall(function() updateConnection:Disconnect() end)
			updateConnection = nil
		end
		blueToken = blueToken + 1
		orangeToken = orangeToken + 1
		if bluePortal then
			pcall(function() bluePortal:Destroy() end)
			bluePortal = nil
		end
		if orangePortal then
			pcall(function() orangePortal:Destroy() end)
			orangePortal = nil
		end
		pcall(function() gui:Destroy() end)
		pcall(function() HotbarGui:Destroy() end)
		pcall(function() tool:Destroy() end)
	end
end

-- =========================================================
-- CONTROLE DE RESPAWN / PERSISTÊNCIA 
-- =========================================================
safeSetup = function(character)
	if not scriptAlive then return end
	local okS, err = pcall(setupPortalGun, character)
	if not okS then
		warnPG("erro ao montar a Portal Gun:", err)
	end
end

trackRoot(player.CharacterAdded:Connect(function(char)
	PGState.rebuilds = 0
	task.spawn(safeSetup, char)
end))

-- Caso já tenha spawnado quando executar
if player.Character then
	task.spawn(safeSetup, player.Character)
end

genv.__PortalGunCleanup = function()
	scriptAlive = false
	for _, c in ipairs(rootConns) do
		pcall(function() c:Disconnect() end)
	end
	if PGState.cleanup then
		local f = PGState.cleanup
		PGState.cleanup = nil
		pcall(f)
	end
	if antiFallConnection then
		pcall(function() antiFallConnection:Disconnect() end)
		antiFallConnection = nil
	end
	if antiFallMenuRef then
		pcall(function() antiFallMenuRef:Destroy() end)
		antiFallMenuRef = nil
	end
	if currentPortalGunGui then pcall(function() currentPortalGunGui:Destroy() end) end
	if currentHotbarGui then pcall(function() currentHotbarGui:Destroy() end) end
end
