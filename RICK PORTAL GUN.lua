local __ok, __err = xpcall(function()
if not task then
	task = {
		wait = wait,
		spawn = function(f, ...) local a = {...}; return coroutine.wrap(function() f(unpack(a)) end)() end,
		defer = function(f, ...) local a = {...}; return coroutine.wrap(function() f(unpack(a)) end)() end,
		delay = function(t, f, ...) local a = {...}; return delay(t, function() f(unpack(a)) end) end,
	}
end
do
	local okR, isClient = pcall(function() return game:GetService("RunService"):IsClient() end)
	if okR and not isClient then
		pcall(warn, "[RickPortalGun] precisa rodar como LocalScript/executor (cliente).")
		return
	end
end
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

local UNIVERSAL = {

	UseHiddenGui = true,
}

local CLEANUP_KEY = "__RickPortalGunCleanup"
local STEP_NAME = "RickPortalGunStep"

local scriptAlive = true
local State = { cleanup = nil, rebuilds = 0 }

State.morty = nil
State.mortyEvent = function(name, ...)
	local m = State.morty
	local f = m and m[name]
	if f then pcall(f, ...) end
end
local rootConns = {}
local safeSetup = nil

local function warnRG(...)
	pcall(warn, "[RickPortalGun]", ...)
end

local function trackRoot(c)
	rootConns[#rootConns + 1] = c
	return c
end

local genv = _G
do
	local okG, e = pcall(function() return getgenv() end)
	if okG and type(e) == "table" then genv = e end
end
if type(genv[CLEANUP_KEY]) == "function" then
	pcall(genv[CLEANUP_KEY])
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
	pcall(function()
		if syn and syn.protect_gui then syn.protect_gui(g)
		elseif protect_gui then protect_gui(g) end
	end)
	local p = getGuiParent()
	if p then pcall(function() g.Parent = p end) end
	if not g.Parent then
		local pg = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 15)
		if pg then pcall(function() g.Parent = pg end) end
	end
	return g.Parent ~= nil
end

local function buildIgnore(...)
	local t = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if typeof(v) == "Instance" then t[#t + 1] = v end
	end
	return t
end

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

local function inOpening(lp, halfW, halfH, margin)
	local a = lp.X / (halfW + margin)
	local b = lp.Y / (halfH + margin)
	return a * a + b * b <= 1
end

local Config = {
	ToolName = "Rick Portal Gun",

	PortalColor = Color3.fromRGB(70, 255, 60),
	PortalLight = Color3.fromRGB(205, 255, 150),
	PortalDark = Color3.fromRGB(8, 85, 14),

	PortalSize = Vector3.new(10, 10, 0.2),
	PortalOffset = 0.12,
	PortalDuration = 10,
	MaxDistance = 600,
	EntranceDistance = 8,
	BeamWidth = 0.2,
	BeamLength = 6,
	BeamSpeed = 320,
	BeamTexture = "",

	SeverEnabled = true,
	SeverDepth = 0.15,
	SeverPartialCross = true,
	SeverTipDepth = 0.3,
	SeverOpeningMargin = 1,
	SeverRigLog = true,
	SeverEjectSpeed = 8,
	SeverLimbLifetime = 16,
	SeverRegrow = true,
	SeverRegrowDelay = 1,
	SeverRegrowAnimTime = 7,
	SeverRegrowScaled = true,
	SeverRegrowBase = 3,
	SeverRegrowPerWeight = 6,
	SeverTwitch = true,
	SeverTwitchTime = 4.5,
	SeverSpurt = true,
	SeverSpurtTime = 6,
	SeverDecay = true,
	SeverFakeGhost = true,
	SeverFreezeAnimR6 = true,
	SeverRagdollArmsR15 = true,
	SeverRagdollGravity = 0.6,
	SeverRagdollDamping = 3,
	SeverRagdollMaxAngle = 110,
	SeverRagdollLength = 1.6,
	SeverRegrowFitJoints = true,
	SeverRegrowFitJointsR6 = false,
	BloodStains = true,
	BloodStainLifetime = 28,
	BloodMaxStains = 80,
	SeverHead = true,
	SeverHeadKills = true,
	SeverHeadKillDelay = 0.25,
	EntranceDelay = 0.8,

	MuzzleFlip = false,
	MuzzleCalibrate = false,
	MuzzleOffset = Vector3.new(0, -1.285, 0.8),

	ShotCooldown = 0.9,
	Variant2Cooldown = 0.45,
	NearPlayerDistance = 7,
	Variant15Gap = 14,
	Variant15Delay = 1.0,
	Variant15MaxThickness = 60,
	TeleportCooldown = 0.5,
	MinExitSpeed = 8,

	ZoneFront = 4.5,
	ZoneBack = 1.5,
	CloneZoneMargin = 2.5,
	HideInsidePart = true,
	MaxStep = 40,

	CamSlide = true,
	CamSlideDuration = 0.55,
	CamSlideStyle = Enum.EasingStyle.Cubic,
	CamSlideDirection = Enum.EasingDirection.Out,

	Elastic = true,
	ElasticPullTime = 0.09,
	ElasticPull = Vector3.new(0.55, 1.55, 0.55),
	ElasticExit = Vector3.new(0.4, 1.8, 0.4),
	ElasticReturnTime = 0.85,
	ElasticFOV = 24,
	ElasticBody = false,

	PortalBoing = true,
	PortalBoingDuration = 1.3,
	PortalBoingFrequency = 3.2,
	PortalBoingDamping = 2.6,
	PortalBoingJelly = 0.7,
	PortalBoingJellyFreq = 1.45,
	PortalBoingCascade = 0.06,
	PortalBoingEnter = -0.3,
	PortalBoingExit = 0.4,

	HideHoldAnim = true,
	ArmAim = true,
	ArmAimMaxAngle = 90,
	ArmAimSmooth = 22,

	HolsterOffset = CFrame.new(1.4, -1, -0.2) * CFrame.Angles(0.8, math.rad(0), math.rad(-35)),

	SoundOpen = "rbxassetid://7229703765",
	SoundTeleport = "rbxassetid://102568033872947",
	SoundClose = "rbxassetid://125119525819708",
	SoundEquip = "rbxassetid://129589685201945",
	SoundLand = "rbxassetid://9116546593",
	SoundShoot = "rbxassetid://74562584385247",
	SoundInvalid = "rbxassetid://132281440773764",
	SoundDial = "rbxassetid://6042053626",
	SoundKeyEquip = "rbxassetid://9113849492",
	SoundBoneGrow = "rbxassetid://84312631986360",
	SoundBoneGrowVolume = 0.5,

	ParticleSpark = "rbxassetid://241594419",
	ParticleSpark2 = "rbxassetid://243660364",

	PortalImageId = 81558332228414,
	PortalImageOffset = 45,

	GooDripRadius = 0.41,
	GooDrips = true,
	GooDripCount = 7,
	GooDrop3D = true,
	GooCloseBurst = true,
	GooCloseCount = 7,

	AccessoryId = 13382211511,
	AccessoryLength = 2.5,
	AccessoryGrip = Vector3.new(0, -0.6, -0.4),
	AccessoryExtraRotation = Vector3.new(-90, 180, 0),

	KeyToolName = "Chave da Nave",
	KeyAccessoryId = 71337506344769,
	KeyLength = 1.6,
	KeyGrip = Vector3.new(0, 0, 0),
	KeyRotation = Vector3.new(0, 0, 0),
	KeyCooldown = 0.9,
	KeySlotOffsetX = -142,
	KeyIcon = "🔑",

	ShipScale = 1,
	ShipSpeed = 95,
	ShipTurbo = 2.6,
	ShipAccel = 2.6,
	ShipTurnRate = 5,
	ShipPortalSize = Vector3.new(70, 70, 0.2),
	ShipPortalHeight = 130,
	ShipLandDistance = 26,
	ShipArriveStartSpeed = 240,
	ShipArriveEndSpeed = 44,
	ShipArriveDrive = 46,
	ShipArrivePortalSize = Vector3.new(46, 46, 0.2),
	ShipLeaveRollDist = 38,
	ShipLeaveRollSpeed = 85,
	ShipLeaveEndSpeed = 210,
	ShipLeavePortalSize = Vector3.new(46, 46, 0.2),
	ShipDescentTime = 4.2,
	ShipSeatHeight = 1.5,
	ShipBoardRadius = 8,
	ShipGroundSpeed = 45,
	ShipGroundTurbo = 2,
	ShipAutoBoard = false,
	ShipSpaceStartAlt = 700,
	ShipSpaceFullAlt = 1500,
	ShipSolid = true,

	ShipDriftGrip = { 2.4, 1.1, 0.45 },
	ShipDriftTurn = { 10, 13, 17 },
	ShipDriftDust = 2.2,
}

State.lastActivity = os.clock()
State.watchIdle = function(isValid, onExpire)
	State.lastActivity = os.clock()
	task.spawn(function()
		while true do
			if not isValid() then return end
			local remaining = Config.PortalDuration - (os.clock() - State.lastActivity)
			if remaining <= 0 then break end
			task.wait(remaining)
		end
		if isValid() then onExpire() end
	end)
end

local AccTemplate, AccAxis, AccHalf, AccTried = nil, nil, 0, false

local function fetchAccessoryModel(id)
	local lastErr = "desconhecido"
	for attempt = 1, 3 do
		local okG, objs = pcall(function()
			return game:GetObjects("rbxassetid://" .. tostring(id))
		end)
		if okG and type(objs) == "table" and objs[1] then return objs[1] end
		if not okG then lastErr = tostring(objs) end

		local okI, model = pcall(function()
			return game:GetService("InsertService"):LoadAsset(tonumber(id) or id)
		end)
		if okI and model then return model end
		if not okI then lastErr = tostring(model) end

		if attempt < 3 then task.wait(1) end
	end
	return nil, lastErr
end

local function makePlaceholderHandle()
	local c = Instance.new("Part")
	c.Name = "Handle"
	c.Size = Vector3.new(1, 1, Config.AccessoryLength)
	c.Transparency = 1
	c.Anchored = false
	c.CanCollide = false
	c.CanQuery = false
	c.CanTouch = false
	c.Massless = true
	c.CastShadow = false
	AccAxis, AccHalf = Vector3.zAxis, Config.AccessoryLength / 2
	AccTemplate = c
	return c
end

local function loadAccessoryTemplate()
	if AccTried then return AccTemplate end
	AccTried = true
	if not Config.AccessoryId then
		warnRG("AccessoryId vazio; usando handle invisível.")
		return makePlaceholderHandle()
	end
	local model, err = fetchAccessoryModel(Config.AccessoryId)
	if not model then
		warnRG("Não foi possível carregar o acessório " .. tostring(Config.AccessoryId) .. " (" .. tostring(err) .. "). Usando handle invisível: a arma funciona, mas fica sem visual.")
		return makePlaceholderHandle()
	end
	local h
	if model:IsA("BasePart") and model.Name == "Handle" then
		h = model
	else
		h = model:FindFirstChild("Handle", true) or model:FindFirstChildWhichIsA("BasePart", true)
	end
	if not h then
		pcall(function() model:Destroy() end)
		warnRG("Acessório sem parte Handle. Usando handle invisível.")
		return makePlaceholderHandle()
	end
	local c = h:Clone()
	pcall(function() model:Destroy() end)
	for _, d in ipairs(c:GetChildren()) do
		if d:IsA("Attachment") or d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Script")
			or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Motor6D") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	c.Name = "Handle"
	c.Anchored = false
	c.CanCollide = false
	c.CanQuery = false
	c.CanTouch = false
	c.Massless = true
	c.CastShadow = true

	local s = c.Size
	local longest = math.max(s.X, s.Y, s.Z)
	local f = Config.AccessoryLength / math.max(longest, 0.01)
	c.Size = s * f
	local sm = c:FindFirstChildOfClass("SpecialMesh")
	if sm then sm.Scale = sm.Scale * f end

	local ns = c.Size
	if ns.X >= ns.Y and ns.X >= ns.Z then
		AccAxis, AccHalf = Vector3.xAxis, ns.X / 2
	elseif ns.Y >= ns.Z then
		AccAxis, AccHalf = Vector3.yAxis, ns.Y / 2
	else
		AccAxis, AccHalf = Vector3.zAxis, ns.Z / 2
	end
	AccTemplate = c
	return c
end

local PortalImage, PortalImageTried = nil, false
local function resolvePortalImage()
	if PortalImageTried then return PortalImage end
	PortalImageTried = true
	local id = Config.PortalImageId
	if not id then return nil end
	local direct = "rbxassetid://" .. tostring(id)
	local found = nil
	local okG, objs = pcall(function()
		return game:GetObjects(direct)
	end)
	if okG and type(objs) == "table" then
		for _, o in ipairs(objs) do
			if not found then
				local src = nil
				if o:IsA("Decal") or o:IsA("Texture") then
					src = o
				else
					src = o:FindFirstChildWhichIsA("Decal", true) or o:FindFirstChildWhichIsA("Texture", true)
				end
				if src and src.Texture and src.Texture ~= "" then
					found = src.Texture
				end
			end
			pcall(function() o:Destroy() end)
		end
	end
	PortalImage = found or direct
	pcall(function()
		local probe = Instance.new("ImageLabel")
		probe.Image = PortalImage
		game:GetService("ContentProvider"):PreloadAsync({probe})
		probe:Destroy()
	end)
	return PortalImage
end

local FLIP = CFrame.Angles(0, math.pi, 0)

local Theme = {
	Bg = Color3.fromRGB(8, 16, 10),
	BgTop = Color3.fromRGB(24, 42, 28),
	Text = Color3.fromRGB(232, 248, 236),
	Muted = Color3.fromRGB(120, 158, 128),
}

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

local UIAnim = {}
do
	local BACK, QUAD = Enum.EasingStyle.Back, Enum.EasingStyle.Quad
	local OUT, IN = Enum.EasingDirection.Out, Enum.EasingDirection.In
	local running = setmetatable({}, { __mode = "k" })

	function UIAnim.getScale(o)
		local s = o:FindFirstChildOfClass("UIScale")
		if not s then
			s = Instance.new("UIScale")
			s.Name = "UIAnimScale"
			s.Parent = o
		end
		return s
	end

	function UIAnim.scaleTo(o, v, t, style, dir)
		local s = UIAnim.getScale(o)
		local old = running[s]
		if old then pcall(function() old:Cancel() end) end
		local tw = TweenService:Create(s, TweenInfo.new(t, style or BACK, dir or OUT), { Scale = v })
		running[s] = tw
		tw:Play()
		return tw
	end

	function UIAnim.pulse(o, amt)
		if not o or not o.Parent then return end
		UIAnim.scaleTo(o, amt or 1.12, 0.08, QUAD)
		task.delay(0.08, function()
			if o.Parent then UIAnim.scaleTo(o, 1, 0.35) end
		end)
	end

	function UIAnim.pop(o, from)
		if not o or not o.Parent then return end
		UIAnim.getScale(o).Scale = from or 0.8
		UIAnim.scaleTo(o, 1, 0.3)
		local bt = o.BackgroundTransparency
		if bt < 1 then
			o.BackgroundTransparency = 1
			TweenService:Create(o, TweenInfo.new(0.25, QUAD, OUT), { BackgroundTransparency = bt }):Play()
		end
	end

	function UIAnim.watchText(l)
		local last = l.Text
		l:GetPropertyChangedSignal("Text"):Connect(function()
			if l.Text ~= last then
				last = l.Text
				if l.Visible then UIAnim.pulse(l, 1.14) end
			end
		end)
	end

	local function hasOwnScale(o)
		for _, c in ipairs(o:GetChildren()) do
			if c:IsA("UIScale") and c.Name ~= "UIAnimScale" then return true end
		end
		return false
	end

	local function setup(o)
		if not o:IsA("GuiObject") then return end
		o:GetPropertyChangedSignal("Visible"):Connect(function()
			if o.Visible then UIAnim.pop(o) end
		end)
		if o:IsA("GuiButton") then
			if hasOwnScale(o) then return end
			o.MouseEnter:Connect(function() UIAnim.scaleTo(o, 1.06, 0.18) end)
			o.MouseLeave:Connect(function() UIAnim.scaleTo(o, 1, 0.15, QUAD) end)
			o.MouseButton1Down:Connect(function() UIAnim.scaleTo(o, 0.92, 0.07, QUAD) end)
			o.MouseButton1Up:Connect(function() UIAnim.scaleTo(o, 1.04, 0.25) end)
		elseif o:IsA("TextBox") then
			local st = o:FindFirstChildOfClass("UIStroke")
			local base = st and st.Thickness or 0
			if not st then
				st = Instance.new("UIStroke")
				st.Thickness = 0
				st.Color = Config.PortalColor
				st.Transparency = 0.1
				st.Parent = o
			end
			o.Focused:Connect(function()
				TweenService:Create(st, TweenInfo.new(0.2), { Thickness = base + 2 }):Play()
				UIAnim.scaleTo(o, 1.05, 0.25)
			end)
			o.FocusLost:Connect(function()
				TweenService:Create(st, TweenInfo.new(0.25), { Thickness = base }):Play()
				UIAnim.scaleTo(o, 1, 0.2, QUAD)
			end)
		end
	end

	function UIAnim.attach(root)
		if root.Name == "RickPortalGunFlash" then return end
		local function go(o)

			task.defer(function()
				if o.Parent then pcall(setup, o) end
			end)
		end
		for _, d in ipairs(root:GetDescendants()) do go(d) end
		root.DescendantAdded:Connect(go)
	end
end

local function buildGun(container, withLight)
	if not AccTemplate then return nil, {} end
	local ah = AccTemplate:Clone()
	ah.Parent = container
	if withLight then
		local light = Instance.new("PointLight")
		light.Color = Config.PortalColor
		light.Brightness = 2
		light.Range = 10
		light.Parent = ah
	end
	return ah, { Handle = ah, Custom = true }
end

State.makeDashScreens = function(S, partRed, partGreen, env)
	local GREEN = env.green
	local RED = Color3.fromRGB(255, 64, 56)
	local AMBER = Color3.fromRGB(255, 196, 64)
	local WHITE = Color3.new(1, 1, 1)
	local TL, TR, TC = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right, Enum.TextXAlignment.Center

	local function mkGui(part)
		local g = Instance.new("SurfaceGui")
		g.Name = "DashScreen"
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		g.CanvasSize = Vector2.new(380, 180)
		g.LightInfluence = 0
		g.Brightness = 1.5
		g.ClipsDescendants = true
		g.Adornee = part
		g.Parent = part
		return g
	end
	local function box(parent, color, x, y, w, h, transp)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transp or 0
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(w, h)
		f.Parent = parent
		return f
	end
	local function lbl(parent, text, size, color, x, y, w, h, xa)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.Code
		t.Text = text
		t.TextSize = size
		t.TextColor3 = color
		t.TextXAlignment = xa or TL
		t.TextYAlignment = Enum.TextYAlignment.Center
		t.Position = UDim2.fromOffset(x, y)
		t.Size = UDim2.fromOffset(w, h)
		t.Parent = parent
		return t
	end
	local function backdrop(g, col)
		local bg = box(g, col:Lerp(Color3.new(0, 0, 0), 0.92), 0, 0, 380, 180, 0)
		bg.Size = UDim2.fromScale(1, 1)
		local st = Instance.new("UIStroke")
		st.Color = col
		st.Thickness = 3
		st.Parent = bg
		return bg
	end

	local sp = backdrop(mkGui(partGreen), GREEN)
	lbl(sp, "VELOCIDADE", 14, GREEN, 10, 6, 150, 18, TL)
	local stLbl = lbl(sp, "PARADA", 14, GREEN, 190, 6, 180, 18, TR)
	local numLbl = lbl(sp, "000", 72, GREEN, 10, 28, 230, 84, TL)
	lbl(sp, "KM/H", 20, GREEN, 236, 80, 80, 24, TL)
	local modeLbl = lbl(sp, "MODO TERRA", 14, GREEN, 236, 34, 140, 18, TL)
	local pctLbl = lbl(sp, "POTENCIA 0%", 14, GREEN, 236, 54, 140, 18, TL)
	local NSEG = 26
	local segs = {}
	for i = 1, NSEG do
		segs[i] = box(sp, i > NSEG * 0.8 and AMBER or GREEN, 10 + (i - 1) * 14, 122, 11, 30, 0.88)
	end
	local peak = box(sp, WHITE, 10, 118, 3, 38, 0)
	lbl(sp, "0", 12, GREEN, 10, 156, 40, 16, TL)
	lbl(sp, "VMAX", 12, GREEN, 330, 156, 40, 16, TR)
	local sweep = box(sp, GREEN, -20, 0, 5, 180, 0.82)

	local dg = backdrop(mkGui(partRed), RED)
	local dot = box(dg, RED, 10, 9, 10, 10, 0)
	lbl(dg, "DIAGNOSTICO DA NAVE", 14, RED, 26, 6, 240, 18, TL)
	local sysLbl = lbl(dg, "SYS 100%", 14, RED, 270, 6, 100, 18, TR)
	local logF = Instance.new("Frame")
	logF.BackgroundTransparency = 1
	logF.Position = UDim2.fromOffset(8, 28)
	logF.Size = UDim2.fromOffset(252, 118)
	logF.ClipsDescendants = true
	logF.Parent = dg

	local SYSN = { "NUCLEO DE FUSAO", "PROPULSOR ESQ", "PROPULSOR DIR", "SUSPENSAO", "LINK PORTAL GUN",
		"TANQUE DE FLUIDO", "ESCUDO", "COMPUTADOR BORDO", "ANTENA", "RODAS 4X4", "FAROIS",
		"DOMO DE VIDRO", "PRESSAO CABINE", "GIROSCOPIO" }
	local STAT = { "OK", "OK", "OK", "NOMINAL", "ESTAVEL", "98%", "100%", "CALIBRANDO", "SINC OK" }
	local function newLine()
		local name = SYSN[math.random(#SYSN)]
		local warn = math.random() < 0.08
		local st = warn and "AVISO!" or STAT[math.random(#STAT)]
		local dots = string.rep(".", math.max(2, 27 - #name - #st))
		return "> " .. name .. " " .. dots .. " " .. st, warn and AMBER or RED
	end
	local LH, NL = 17, 8
	local lines = {}
	for i = 1, NL do
		local t, c = newLine()
		local l = lbl(logF, t, 13, c, 0, (i - 1) * LH, 252, LH, TL)
		l.TextTransparency = 0.65 * ((NL - i) / (NL - 1)) ^ 1.5
		lines[i] = l
	end
	local NB = 6
	local bars, bcur, btgt = {}, {}, {}
	for i = 1, NB do
		local b = box(dg, RED, 272 + (i - 1) * 17, 146, 12, 4, 0.1)
		b.AnchorPoint = Vector2.new(0, 1)
		bars[i], bcur[i], btgt[i] = b, 20, 20
	end
	box(dg, RED, 8, 154, 364, 14, 0.85)
	local scanFill = box(dg, RED, 8, 154, 0, 14, 0.15)
	local scanTxt = lbl(dg, "SCAN 0%", 11, WHITE, 8, 154, 364, 14, TC)

	local camera, SPEED, TURBO = env.camera, env.SPEED, env.TURBO
	local GSPEED, GTURBO = env.GROUND_SPEED, env.GROUND_TURBO
	local st = { t = 0, spd = 0, peak = 0, peakT = 0, scroll = 0, barT = 0, scan = 0,
		num = "", stat = "", pct = -1, sys = -1, scn = -1 }
	S.dashFx = function(_, dt)
		if dt <= 0 then return end
		dt = math.min(dt, 0.1)
		local pos = S.cf.Position
		if (camera.CFrame.Position - pos).Magnitude > 150 then st.lastPos = nil; return end
		st.t = st.t + dt
		local t = st.t

		local info = env.info
		local txt = (S.state == "flying" and info and info.Parent) and info.Text or nil
		local inst, turbo = 0, false
		if txt then
			inst = tonumber(txt:match("VEL%s+(%-?%d+)")) or 0
			turbo = txt:find("TURBO", 1, true) ~= nil
		elseif st.lastPos then
			inst = math.min((pos - st.lastPos).Magnitude / dt, 600)
		end
		st.lastPos = pos
		st.spd = st.spd + (inst - st.spd) * (1 - math.exp(-9 * dt))
		local fly = S.mode == "fly"
		local vmax = fly and (SPEED * TURBO) or (GSPEED * GTURBO)
		local frac = math.clamp(st.spd / vmax, 0, 1)

		local lit = frac * NSEG
		for i = 1, NSEG do
			segs[i].BackgroundTransparency = 0.88 * (1 - math.clamp(lit - (i - 1), 0, 1))
		end
		if frac > st.peak then
			st.peak, st.peakT = frac, t + 1.2
		elseif t > st.peakT then
			st.peak = math.max(frac, st.peak - dt * 0.5)
		end
		peak.Visible = st.peak > 0.03
		peak.Position = UDim2.fromOffset(10 + math.clamp(math.floor(st.peak * NSEG), 0, NSEG - 1) * 14 + 4, 118)
		local n = string.format("%03d", math.floor(st.spd + 0.5))
		if n ~= st.num then st.num = n; numLbl.Text = n end
		local stTxt = (S.state == "arriving" or S.state == "leaving") and "PILOTO AUTO"
			or (st.spd < 1.5 and "PARADA" or (turbo and "TURBO" or (fly and "VOO" or "TERRA")))
		if stTxt ~= st.stat then
			st.stat = stTxt
			stLbl.Text = stTxt
			modeLbl.Text = fly and "MODO VOO" or "MODO TERRA"
		end
		stLbl.TextTransparency = (turbo and math.floor(t * 5) % 2 == 1) and 0.7 or 0
		local pct = math.floor(frac * 100 + 0.5)
		if pct ~= st.pct then st.pct = pct; pctLbl.Text = "POTENCIA " .. pct .. "%" end
		sweep.Position = UDim2.fromOffset((t * 150) % 440 - 30, 0)

		st.scroll = st.scroll + dt * 22
		if st.scroll >= LH then
			st.scroll = st.scroll - LH
			for i = 1, NL - 1 do
				lines[i].Text = lines[i + 1].Text
				lines[i].TextColor3 = lines[i + 1].TextColor3
			end
			local txtN, colN = newLine()
			lines[NL].Text = txtN
			lines[NL].TextColor3 = colN
		end
		for i = 1, NL do
			lines[i].Position = UDim2.fromOffset(0, (i - 1) * LH - st.scroll)
		end
		dot.BackgroundTransparency = (math.floor(t * 2.5) % 2 == 0) and 0 or 0.75
		local sysv = math.floor(98.5 + 1.5 * math.sin(t * 0.7))
		if sysv ~= st.sys then st.sys = sysv; sysLbl.Text = "SYS " .. sysv .. "%" end
		st.barT = st.barT - dt
		if st.barT <= 0 then
			st.barT = 0.16
			for i = 1, NB do btgt[i] = math.random(10, 112) end
		end
		for i = 1, NB do
			bcur[i] = bcur[i] + (btgt[i] - bcur[i]) * (1 - math.exp(-12 * dt))
			bars[i].Size = UDim2.fromOffset(12, math.floor(bcur[i]))
		end
		st.scan = (st.scan + dt * 0.22) % 1
		scanFill.Size = UDim2.fromOffset(math.floor(364 * st.scan), 14)
		local sc = math.floor(st.scan * 100)
		if sc ~= st.scn then st.scn = sc; scanTxt.Text = "SCAN " .. sc .. "%" end
	end
end

State.buildTank = function(add, cylX, c)
	local TANK, DARK, MID, BLACK, GLOW = c.TANK, c.DARK, c.MID, c.BLACK, c.GLOW
	local METAL, SMOOTH = c.METAL, c.SMOOTH
	local CX, CY, CZ, R, HL = 0, 5.1, 4.6, 1.15, 3.1
	local STRAP = Color3.fromRGB(96, 104, 100)
	local RY = CFrame.Angles(0, 0, math.rad(90))

	add("Tank", cylX(HL * 2, R * 2), CFrame.new(CX, CY, CZ), TANK, METAL, 0, "cyl")
	for _, sx in ipairs({ -1, 1 }) do

		add("TankDome", Vector3.new(1.2, R * 2, R * 2), CFrame.new(sx * HL, CY, CZ), TANK, METAL, 0, "sphere")
		add("TankSeam", cylX(0.12, R * 2 + 0.1), CFrame.new(sx * (HL - 0.05), CY, CZ), STRAP, METAL, 0, "cyl")

		local x = sx * 2.0
		add("TankStrap", cylX(0.7, R * 2 + 0.14), CFrame.new(x, CY, CZ), STRAP, METAL, 0, "cyl")
		for _, e in ipairs({ -1, 1 }) do
			add("TankStrapRim", cylX(0.09, R * 2 + 0.24), CFrame.new(x + e * 0.31, CY, CZ), DARK, METAL, 0, "cyl")
		end

		for _, sz in ipairs({ -1, 1 }) do
			local a = sz * math.rad(135)
			local ny, nz = math.cos(a), math.sin(a)
			local r1, r2 = R + 0.16, R + 0.28
			local rot = CFrame.Angles(a, 0, 0)
			add("TankTab", Vector3.new(0.6, 0.16, 0.7), CFrame.new(x, CY + ny * r1, CZ + nz * r1) * rot, DARK, METAL)
			add("TankTabBolt", cylX(0.1, 0.22), CFrame.new(x, CY + ny * r2, CZ + nz * r2) * rot * RY, MID, METAL, 0, "cyl")
		end
	end

	local TOPY = CY + R
	add("TankPlate", Vector3.new(0.95, 0.1, 0.65), CFrame.new(CX, TOPY + 0.03, CZ), MID, METAL)
	add("TankPlateIn", Vector3.new(0.7, 0.04, 0.4), CFrame.new(CX, TOPY + 0.1, CZ), DARK, SMOOTH)
	local studY = CY + math.sqrt(R * R - 0.72 * 0.72) + 0.05
	for _, ix in ipairs({ -1, 1 }) do
		for _, iz in ipairs({ -1, 1 }) do
			local a = Vector3.new(CX + ix * 0.42, TOPY + 0.05, CZ + iz * 0.28)
			local b = Vector3.new(CX + ix * 1.05, studY, CZ + iz * 0.72)
			add("TankLeg", Vector3.new(0.1, 0.08, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), MID, METAL)
			add("TankStud", Vector3.new(0.26, 0.26, 0.26), CFrame.new(b), MID, METAL, 0, "sphere")
		end
	end

	add("TankValveBase", cylX(0.1, 0.55), CFrame.new(-2.85, TOPY + 0.02, CZ) * RY, DARK, METAL, 0, "cyl")
	add("TankValveStem", cylX(0.35, 0.22), CFrame.new(-2.85, TOPY + 0.22, CZ) * RY, MID, METAL, 0, "cyl")
	add("TankValve", Vector3.new(0.5, 0.5, 0.5), CFrame.new(-2.85, TOPY + 0.5, CZ), MID, METAL, 0, "sphere")

	add("TankGauge", cylX(0.12, 0.7), CFrame.new(3.68, CY, CZ), BLACK, SMOOTH, 0, "cyl")
	add("TankGaugeLed", Vector3.new(0.06, 0.2, 0.2), CFrame.new(3.76, CY, CZ), GLOW, SMOOTH)
end

State.buildDash = function(add, cylX, c, dashBase)
	local LIGHT, MID, DARK, BLACK, PLATE = c.LIGHT, c.MID, c.DARK, c.BLACK, c.PLATE
	local METAL, SMOOTH = c.METAL, c.SMOOTH
	local FACE = 1.175
	local RZ = CFrame.Angles(0, math.pi / 2, 0)
	local RY = CFrame.Angles(0, 0, math.pi / 2)
	local function D(deg, x, y, z)
		return dashBase(math.rad(deg)) * CFrame.new(x, y, z)
	end

	add("PillarBody", Vector3.new(1.4, 1.9, 0.5), D(0, 0, -0.05, FACE + 0.25), LIGHT, METAL)
	add("PillarArch", cylX(0.5, 1.4), D(0, 0, 0.9, FACE + 0.25) * RZ, LIGHT, METAL, 0, "cyl")
	add("PillarFoot", Vector3.new(1.55, 0.2, 0.62), D(0, 0, -0.92, FACE + 0.31), MID, METAL)

	local gz = FACE + 0.5
	local gauges = { { 0, 0.98, 0.58 }, { -0.34, 0.4, 0.42 }, { 0.34, 0.4, 0.42 }, { -0.34, -0.18, 0.42 }, { 0.34, -0.18, 0.42 } }
	for i, g in ipairs(gauges) do
		local gx, gy, gd = g[1], g[2], g[3]
		add("GaugeRing", cylX(0.05, gd + 0.12), D(0, gx, gy, gz + 0.025) * RZ, MID, METAL, 0, "cyl")
		add("GaugeFace", cylX(0.05, gd), D(0, gx, gy, gz + 0.05) * RZ, BLACK, SMOOTH, 0, "cyl")
		add("GaugeNeedle", Vector3.new(gd * 0.4, 0.035, 0.02),
			D(0, gx, gy, gz + 0.085) * CFrame.Angles(0, 0, math.rad(35 + i * 25)) * CFrame.new(gd * 0.17, 0, 0), PLATE, SMOOTH)
	end

	add("LeverBase", cylX(0.1, 0.34), D(0, 0, 1.62, FACE + 0.25) * RY, DARK, METAL, 0, "cyl")
	add("LeverStick", cylX(0.6, 0.09), D(0, 0, 1.95, FACE + 0.25) * RY, MID, METAL, 0, "cyl")
	add("LeverKnob", Vector3.new(0.2, 0.2, 0.2), D(0, 0, 2.28, FACE + 0.25), BLACK, SMOOTH, 0, "sphere")

	for _, sg in ipairs({ -1, 1 }) do
		local vr = sg * 31
		add("VentRim", cylX(0.05, 0.8), D(vr, 0, 0.35, FACE + 0.025) * RZ, MID, METAL, 0, "cyl")
		add("VentBody", cylX(0.05, 0.68), D(vr, 0, 0.35, FACE + 0.05) * RZ, DARK, METAL, 0, "cyl")
		for k = -1, 1 do
			add("VentSlat", Vector3.new(0.56, 0.05, 0.04), D(vr, 0, 0.35 + k * 0.15, FACE + 0.085), MID, METAL)
		end
	end

	local bd = 17.8
	add("DashBox", Vector3.new(0.8, 0.9, 0.35), D(bd, 0, -0.2, FACE + 0.175), LIGHT, METAL)
	add("DashBoxPlate", Vector3.new(0.6, 0.66, 0.04), D(bd, 0, -0.22, FACE + 0.36), MID, METAL)
	add("DashBoxWindow", Vector3.new(0.38, 0.22, 0.03), D(bd, 0, -0.42, FACE + 0.395), BLACK, SMOOTH)
	for _, ky in ipairs({ 0.03, -0.17 }) do
		add("DashBoxKnob", cylX(0.08, 0.13), D(bd, 0, ky, FACE + 0.42) * RZ, DARK, METAL, 0, "cyl")
	end
	for _, hx in ipairs({ -0.17, 0.17 }) do
		add("DashBoxPost", cylX(0.16, 0.07), D(bd, hx, 0.33, FACE + 0.15) * RY, MID, METAL, 0, "cyl")
	end
	add("DashBoxHandle", cylX(0.4, 0.08), D(bd, 0, 0.42, FACE + 0.15), MID, METAL, 0, "cyl")
	add("DashPipeV", cylX(0.3, 0.09), D(bd, 0, -0.8, FACE + 0.18) * RY, MID, METAL, 0, "cyl")
	add("DashPipeElbow", Vector3.new(0.14, 0.14, 0.14), D(bd, 0, -0.96, FACE + 0.18), MID, METAL, 0, "sphere")
	add("DashPipeH", cylX(0.3, 0.09), D(bd, 0.15, -0.96, FACE + 0.18), MID, METAL, 0, "cyl")
	add("DashPipeCap", cylX(0.16, 0.2), D(bd, 0.36, -0.96, FACE + 0.18), DARK, METAL, 0, "cyl")

	local pb = dashBase(math.rad(-17.8))
	local dir = Vector3.new(0.35, 0.85, 0.40).Unit
	local p0 = Vector3.new(0, -0.45, FACE + 0.15)
	local function rod(name, t0, t1, d, color)
		local a, b = p0 + dir * t0, p0 + dir * t1
		add(name, cylX(t1 - t0, d), pb * CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0), color, METAL, 0, "cyl")
	end
	add("PumpMount", Vector3.new(0.55, 0.3, 0.3), pb * CFrame.new(p0.X, p0.Y, FACE + 0.1), DARK, METAL)
	rod("PumpSleeve", 0, 0.8, 0.38, MID)
	rod("PumpCollar", 0.74, 0.86, 0.46, DARK)
	rod("PumpRod", 0.8, 1.4, 0.14, LIGHT)
	add("PumpBar", cylX(0.75, 0.12), pb * CFrame.new(p0 + dir * 1.4), DARK, METAL, 0, "cyl")
	print("[RickPortalGun] painel novo (pilar, bomba, caixa) carregado")
end

State.buildWheel = function(add, cylX, c, wc, wcPos)
	local MID, DARK, BLACK = c.MID, c.DARK, c.BLACK
	local METAL, SMOOTH, PLASTIC = c.METAL, c.SMOOTH, c.PLASTIC
	local RZ = CFrame.Angles(0, math.pi / 2, 0)
	local RY = CFrame.Angles(0, 0, math.pi / 2)
	local RW, nW = 0.95, 20

	for k = 0, nW - 1 do
		local a = 2 * math.pi * k / nW
		local seg = 2 * RW * math.tan(math.pi / nW) + 0.08
		add("WheelRim", cylX(seg, 0.26),
			wc * CFrame.new(RW * math.cos(a), RW * math.sin(a), 0) * CFrame.Angles(0, 0, a + math.pi / 2), BLACK, PLASTIC, 0, "cyl", "swheel")
	end
	for _, deg in ipairs({ 0, 180, 270 }) do
		add("WheelSpoke", Vector3.new(0.85, 0.2, 0.14), wc * CFrame.Angles(0, 0, math.rad(deg)) * CFrame.new(0.55, 0, 0), MID, METAL, 0, nil, "swheel")
	end
	add("WheelHubCap", cylX(0.22, 0.52), wc * CFrame.new(0, 0, 0.12) * RZ, MID, METAL, 0, "cyl", "swheel")
	add("WheelHubDisc", cylX(0.06, 0.3), wc * CFrame.new(0, 0, 0.25) * RZ, DARK, METAL, 0, "cyl", "swheel")
	add("WheelHub", Vector3.new(0.62, 0.62, 0.62), wc, MID, METAL, 0, "sphere", "swcol")

	local colLen = 3.4
	add("WheelColumn", cylX(colLen, 0.46), CFrame.new(wcPos.X, wcPos.Y - colLen / 2, wcPos.Z) * RY, MID, METAL, 0, "cyl", "swcol")
	add("WheelCollar", cylX(0.14, 0.62), CFrame.new(wcPos.X, wcPos.Y - 0.5, wcPos.Z) * RY, DARK, METAL, 0, "cyl", "swcol")
	add("WheelBase", cylX(0.1, 1.05), CFrame.new(wcPos.X, 3.95, wcPos.Z) * RY, DARK, METAL, 0, "cyl", "swbase")
	add("WheelBaseCone", cylX(0.3, 0.72), CFrame.new(wcPos.X, 4.1, wcPos.Z) * RY, MID, METAL, 0, "cyl", "swbase")

	for _, sx in ipairs({ -1, 1 }) do
		local px = wcPos.X + sx * 0.68
		local p1 = Vector3.new(px, 4.0, wcPos.Z - 1.5)
		local p2 = Vector3.new(px, 4.3, wcPos.Z - 0.65)
		add("PedalArm", cylX((p2 - p1).Magnitude, 0.09), CFrame.lookAt((p1 + p2) / 2, p2) * CFrame.Angles(0, math.pi / 2, 0), MID, METAL, 0, "cyl", "swbase")
		add("PedalPad", Vector3.new(0.42, 0.07, 0.34), CFrame.lookAt(p2, p2 + (p2 - p1)) * CFrame.Angles(math.rad(-30), 0, 0), DARK, METAL, 0, nil, "swbase")
		add("PedalPivot", Vector3.new(0.2, 0.2, 0.2), CFrame.new(p1), DARK, METAL, 0, "sphere", "swbase")
	end
	print("[RickPortalGun] volante novo (3 raios, coluna, pedais) carregado")
end

State.buildSeats = function(add, cylX, c)
	local SEATC, SEATC2, DARK, MID, GLOW = c.SEATC, c.SEATC2, c.DARK, c.MID, c.GLOW
	local PLASTIC, METAL, SMOOTH = c.PLASTIC, c.METAL, c.SMOOTH
	local RZ = CFrame.Angles(0, math.pi / 2, 0)
	local RY = CFrame.Angles(0, 0, math.pi / 2)
	local tilt = CFrame.Angles(math.rad(10), 0, 0)
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 2.3

		add("SeatSkid", Vector3.new(2.5, 0.1, 3.1), CFrame.new(x, 3.95, 0.45), MID, METAL)
		add("SeatSkidRoll", cylX(2.5, 0.16), CFrame.new(x, 3.97, -1.1), MID, METAL, 0, "cyl")
		add("SeatBase", Vector3.new(2.3, 0.5, 2.25), CFrame.new(x, 4.25, 0.525), SEATC, PLASTIC)
		add("SeatBaseLip", cylX(2.3, 0.5), CFrame.new(x, 4.25, -0.6), SEATC, PLASTIC, 0, "cyl")
		for _, sd in ipairs({ -1, 1 }) do
			add("SeatBolster", cylX(2.2, 0.5), CFrame.new(x + sd * 1.25, 4.7, 0.5) * RZ, SEATC2, PLASTIC, 0, "cyl")
		end

		local BK = CFrame.new(x, 6.1, 2.0) * tilt
		add("SeatBack", Vector3.new(1.9, 2.9, 0.5), BK, SEATC, PLASTIC)
		for _, sd in ipairs({ -1, 1 }) do
			add("SeatBackRoll", cylX(2.9, 0.55), BK * CFrame.new(sd * 1.0, 0, 0) * RY, SEATC, PLASTIC, 0, "cyl")
		end
		add("SeatBackTop", cylX(1.9, 0.55), BK * CFrame.new(0, 1.45, 0), SEATC, PLASTIC, 0, "cyl")
		add("SeatLumbar", Vector3.new(1.5, 0.55, 0.1), BK * CFrame.new(0, -0.5, -0.27), SEATC2, PLASTIC)

		add("SeatStrap", Vector3.new(0.5, 4.2, 0.1), BK * CFrame.new(0, 0.5, 0.3), MID, METAL)
		for _, hy in ipairs({ 1.55, 1.3, 1.05 }) do
			add("SeatStrapHole", cylX(0.04, 0.11), BK * CFrame.new(0, hy, 0.36) * RZ, DARK, SMOOTH, 0, "cyl")
		end

		local HD = BK * CFrame.new(0, 2.3, 0)
		add("SeatHead", Vector3.new(1.1, 0.9, 0.5), HD, SEATC2, PLASTIC)
		for _, sd in ipairs({ -1, 1 }) do
			add("SeatHeadRoll", cylX(0.9, 0.5), HD * CFrame.new(sd * 0.55, 0, 0) * RY, SEATC2, PLASTIC, 0, "cyl")
		end
		add("SeatHeadTop", cylX(1.1, 0.5), HD * CFrame.new(0, 0.45, 0), SEATC2, PLASTIC, 0, "cyl")
		add("SeatLed", Vector3.new(0.14, 0.14, 0.05), HD * CFrame.new(0.3, 0.15, 0.28), GLOW, SMOOTH)
	end
	print("[RickPortalGun] bancos novos carregados")
end

State.buildTunnel = function(add, cylX, c)
	local MID, DARK, BLACK, LIGHT = c.MID, c.DARK, c.BLACK, c.LIGHT
	local METAL, PLASTIC, SMOOTH = c.METAL, c.PLASTIC, c.SMOOTH
	local RZ = CFrame.Angles(0, math.pi / 2, 0)
	local RY = CFrame.Angles(0, 0, math.pi / 2)

	add("TunnelSkirt", Vector3.new(1.75, 0.12, 5.55), CFrame.new(0, 3.96, -1.075), DARK, METAL)

	add("TunnelFront", Vector3.new(1.5, 1.1, 3.35), CFrame.new(0, 4.45, -2.075), MID, PLASTIC)

	add("TunnelRear", Vector3.new(1.5, 0.8, 2.0), CFrame.new(0, 4.3, 0.6), MID, PLASTIC)
	for _, sd in ipairs({ -1, 1 }) do
		add("TunnelFrontRoll", cylX(3.35, 0.4), CFrame.new(sd * 0.55, 4.8, -2.075) * RZ, MID, PLASTIC, 0, "cyl")
		add("TunnelRearRoll", cylX(2.0, 0.4), CFrame.new(sd * 0.55, 4.5, 0.6) * RZ, MID, PLASTIC, 0, "cyl")
	end

	add("ShiftBezel", Vector3.new(0.44, 0.03, 2.5), CFrame.new(0, 5.015, -2.1), LIGHT, METAL)
	add("ShiftSlot", Vector3.new(0.24, 0.04, 2.3), CFrame.new(0, 5.03, -2.1), BLACK, SMOOTH)
	add("ShiftCollar", cylX(0.12, 0.32), CFrame.new(0, 5.07, -1.4) * RY, DARK, METAL, 0, "cyl", "shift")
	local s1 = Vector3.new(0, 5.1, -1.4)
	local s2 = Vector3.new(0, 6.0, -1.1)
	add("ShiftRod", cylX((s2 - s1).Magnitude, 0.14), CFrame.lookAt((s1 + s2) / 2, s2) * CFrame.Angles(0, math.pi / 2, 0), MID, METAL, 0, "cyl", "shift")
	add("ShiftKnob", Vector3.new(0.42, 0.42, 0.42), CFrame.new(s2 + (s2 - s1).Unit * 0.1), BLACK, PLASTIC, 0, "sphere", "shift")

	local bdir = Vector3.new(0, 0.7, 0.9).Unit
	local b1 = Vector3.new(0, 4.62, 0)
	local b2 = b1 + bdir * 1.22
	local SLOT_Z = 0.525
	add("BrakeBezel", Vector3.new(0.38, 0.03, 1.8), CFrame.new(0, 4.715, SLOT_Z), LIGHT, METAL)
	add("BrakeSlot", Vector3.new(0.18, 0.04, 1.55), CFrame.new(0, 4.73, SLOT_Z), BLACK, SMOOTH)

	for _, sd in ipairs({ -1, 1 }) do
		add("BrakeCheek", Vector3.new(0.1, 0.26, 1.7), CFrame.new(sd * 0.25, 4.83, SLOT_Z) * CFrame.Angles(math.rad(-5), 0, 0), MID, PLASTIC)
		add("BrakeCheekTop", Vector3.new(0.06, 0.03, 1.7), CFrame.new(sd * 0.25, 4.83 + 0.145, SLOT_Z) * CFrame.Angles(math.rad(-5), 0, 0), LIGHT, METAL)
	end

	add("BrakeLever", cylX((b2 - b1).Magnitude, 0.12), CFrame.lookAt((b1 + b2) / 2, b2) * CFrame.Angles(0, math.pi / 2, 0), MID, METAL, 0, "cyl", "brake")
	add("BrakeGrip", cylX(0.6, 0.17), CFrame.new(b2), DARK, PLASTIC, 0, "cyl", "brake")
	for _, sd in ipairs({ -1, 1 }) do
		add("BrakeGripCap", cylX(0.05, 0.21), CFrame.new(b2 + Vector3.new(sd * 0.3, 0, 0)), MID, METAL, 0, "cyl", "brake")
	end

	add("BrakePivot", Vector3.new(0.1, 0.1, 0.1), CFrame.new(b1), BLACK, PLASTIC, 1, "sphere")
	print("[RickPortalGun] tunel central novo carregado")
end

State.buildShipLevers = function(env)
	local C, ctx, held, api = env.C, env.ctx, env.held, env.api
	local SCALE, CANOPY_OPEN, getShip = env.SCALE, env.CANOPY_OPEN, env.getShip
	local LV = {}

	local SHIFT_DZ = { fly = -1.35, ground = -0.55, P = 0.25 }
	local SHIFT_MIN, SHIFT_MAX = -1.65, 0.28
	local SHIFT_SPAN = SHIFT_DZ.P - SHIFT_DZ.fly
	local BRAKE_INT_DROP = 1.3
	local BRAKE_PIV = Vector3.new(0, 4.62 - BRAKE_INT_DROP, 0)
	local BRAKE_A0, BRAKE_A1 = 0.21, -0.59
	local BRAKE_LEAN = 0.909
	local NOTCH_GAP = 0.14

	local function spring(S, key, goal, dt, k, zeta, lo, hi)
		local x = S[key]
		if x == nil then
			S[key] = goal
			S[key .. "V"] = 0
			return goal
		end
		local v = S[key .. "V"] or 0
		if math.abs(goal - x) < 1e-4 and math.abs(v) < 1e-3 then
			S[key], S[key .. "V"] = goal, 0
			return goal
		end
		local n = math.max(1, math.ceil(dt / 0.008))
		local h = dt / n
		local damp = 2 * zeta * math.sqrt(k)
		for _ = 1, n do
			v = v + (k * (goal - x) - damp * v) * h
			x = x + v * h
			if lo and x < lo then
				x = lo
				if v < 0 then v = -v * 0.3 end
			elseif hi and x > hi then
				x = hi
				if v > 0 then v = -v * 0.3 end
			end
		end
		S[key], S[key .. "V"] = x, v
		return x
	end

	function LV.fx(S, dt)
		if not (S.brakeParts and S.shiftParts and S.model and S.model.Parent) then return end
		dt = math.clamp(dt, 1 / 240, 0.1)
		local st = S.state
		local ground = (st == "flying" and S.mode == "ground")
		local canopy = math.clamp((S.canopyAng or 0) / CANOPY_OPEN, 0, 1)

		local follow = nil
		local want = 0
		if st == "landed" then
			want = 3
		elseif ground then
			want = (held.brake or held.brakeUi) and 3 or 0
		elseif st == "boarding" then
			follow = canopy
		end
		local notch = S.brakeNotch or 0
		if follow then
			notch = math.floor(follow * 3 + 0.5)
			S.brakeT = 0
		elseif want > notch then
			S.brakeT = (S.brakeT or 0) - dt
			if S.brakeT <= 0 then
				notch = notch + 1
				S.brakeT = NOTCH_GAP
				S.brakeKick = 1
				if C.SoundDial then ctx.playSound(C.SoundDial, 0.6) end
			end
		else
			notch = want
			S.brakeT = 0
		end
		S.brakeNotch = notch

		local target = follow or (notch / 3)
		local bp = S.bp
		if bp == nil then bp = target end
		local bv = S.bv or 0
		local btn = S.bBtn or 0
		local hold = S.bHold or 0
		if S.bLastNotch ~= nil and notch > S.bLastNotch and not follow then
			bv = bv + 1.0
		end
		S.bLastNotch = notch
		if follow then
			bp, bv, btn, hold = target, 0, 0, 0
		elseif target < bp - 1e-3 then

			btn = math.min(1, btn + dt * 16)
			hold = hold + dt
			if hold > 0.08 then
				local lim = math.clamp((bp - target) * 5 + 0.3, 0.3, 2.2)
				bv = math.max(bv - 3.2 * dt, -lim)
				bp = bp + bv * dt
				if bp <= target then
					bp = target
					bv = (bv < -0.6) and (-bv * 0.18) or 0
				end
			else
				bv = 0
			end
		else

			btn = math.max(0, btn - dt * 10)
			hold = 0
			local k = 420
			local damp = 2 * 0.45 * math.sqrt(k)
			local n = math.max(1, math.ceil(dt / 0.008))
			local h = dt / n
			for _ = 1, n do
				bv = bv + (k * (target - bp) - damp * bv) * h
				bp = bp + bv * h
			end
		end
		bp = math.clamp(bp, -0.06, 1.08)
		S.bp, S.bv, S.bBtn, S.bHold = bp, bv, btn, hold
		local vis = bp

		if math.abs(vis - (S.lastBrakePos or 9)) > 1e-4 or math.abs(btn - (S.lastBrakeBtn or 9)) > 1e-4 then
			S.lastBrakePos, S.lastBrakeBtn = vis, btn
			local th = BRAKE_A0 + (BRAKE_A1 - BRAKE_A0) * vis
			if not S.brakePivCF then

				for _, e in ipairs(S.parts) do
					if e.part.Name == "BrakePivot" then S.brakePivCF = CFrame.new(e.rel.Position) break end
				end
				S.brakePivCF = S.brakePivCF or CFrame.new(BRAKE_PIV * SCALE)
			end
			local piv = S.brakePivCF
			local rot = piv * CFrame.Angles(th, 0, 0) * piv:Inverse()
			for _, e in ipairs(S.brakeParts) do
				e.weld.C0 = rot * e.rel
			end
		end
		pos = math.clamp(vis, 0, 1)

		local mode = S.mode
		if st == "shifting" then mode = S.shiftTo or mode end
		local key = mode
		if st == "landed" then
			key = "P"
		elseif st == "boarding" and canopy > 0.5 then
			key = "P"
		elseif st == "landing" and canopy > 0.05 then
			key = "P"
		end

		local hands = (st == "flying" or st == "shifting")
		local nowT = os.clock()
		if key ~= S.keyWant then S.keyWant = key; S.keyWantT = nowT end
		if S.keyApplied == nil or not hands or nowT - (S.keyWantT or 0) >= 0.2 then S.keyApplied = key end
		local akey = S.keyApplied
		if S.lastKey ~= nil and S.lastKey ~= akey then
			if C.SoundDial then ctx.playSound(C.SoundDial, 0.7) end
			if hands then S.shiftChT = nowT end
		end
		S.lastKey = akey

		local goalZ = SHIFT_DZ[akey] or SHIFT_DZ.ground
		local z = spring(S, "shiftZ", goalZ, dt, 260, 0.55)
		local rt = S.refuseT and (os.clock() - S.refuseT) or 9

		if hands and (key ~= akey or nowT - (S.shiftChT or -9) < 0.55 or rt < 0.45) then
			S.shiftActT = nowT
		end
		if rt < 0.4 then
			z = z + math.sin(rt * 85) * 0.13 * (1 - rt / 0.4)
		end
		z = math.clamp(z, SHIFT_MIN, SHIFT_MAX)
		if math.abs(z - (S.lastShiftZ or 9)) > 1e-4 then
			S.lastShiftZ = z
			local m = CFrame.new(0, 0, z * SCALE)
			for _, e in ipairs(S.shiftParts) do
				e.weld.C0 = m * e.rel
			end
		end

		if LV.hudUpdate then
			LV.hudUpdate(math.clamp((z - SHIFT_DZ.fly) / SHIFT_SPAN, 0, 1), pos, notch, akey)
		end
	end

	function LV.buildHud(H)
		local hud, mk, frame, disc, ink, grad, text = H.hud, H.mk, H.frame, H.disc, H.ink, H.grad, H.text
		local ACC, INK, BLACK, WHITE, YELLOW, RED = H.ACC, H.INK, H.BLACK, H.WHITE, H.YELLOW, H.RED
		local DIM = Color3.fromRGB(26, 66, 34)
		local METAL0, METAL1 = Color3.fromRGB(176, 186, 196), Color3.fromRGB(70, 78, 88)
		local LEFT = Enum.TextXAlignment.Left

		local root = mk("Frame", { Name = "ShipShifter", BackgroundTransparency = 1, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -104, 0.5, 0),
			Size = UDim2.fromOffset(178, 188), Visible = false }, hud)
		H.addVP(root)
		LV.hudRoot = root

		local function label(str, x, y, w, size, col, xa)
			local t = text(root, str, size, col, x, y, w, size + 4, xa)
			t.ZIndex = 6
			t.TextStrokeTransparency = 0
			t.TextStrokeColor3 = BLACK
			return t
		end
		local function keyChip(str, x)
			if H.isTouchOnly then return end
			local k = frame(root, x, 6, 16, 14, WHITE, 0, 4)
			k.ZIndex = 6
			ink(k, 1.5)
			local t = text(k, str, 9, INK, 0, 0, 16, 14)
			t.ZIndex = 7
		end
		keyChip("R", 62)
		keyChip("B", 154)

		local bezel = frame(root, 12, 26, 40, 150, METAL0, 0, 20)
		bezel.ZIndex = 3
		grad(bezel, METAL0, METAL1, 90)
		ink(bezel, 2.5)
		local slot = frame(root, 19, 33, 26, 136, BLACK, 0, 13)
		slot.ZIndex = 4
		ink(slot, 2, Color3.fromRGB(24, 30, 36))
		local rail = frame(root, 30, 40, 4, 122, Color3.fromRGB(36, 44, 52), 0, 2)
		rail.ZIndex = 5

		local posY = { fly = 56, ground = 103, P = 150 }
		local names = { fly = "VOO", ground = "TERRA", P = "P" }
		local dots, labels = {}, {}
		for _, k in ipairs({ "fly", "ground", "P" }) do
			local d = disc(root, 61, posY[k], 7, DIM)
			d.ZIndex = 5
			ink(d, 1.5)
			dots[k] = d
			labels[k] = label(names[k], 68, posY[k] - 8, 34, 11, WHITE, LEFT)
		end

		local kn = mk("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(32, posY.ground), Size = UDim2.fromOffset(30, 30), ZIndex = 7 }, root)
		local sh = disc(kn, 16, 19, 26, BLACK, 0.5)
		sh.ZIndex = 7
		local collar = disc(kn, 15, 15, 24, WHITE)
		collar.ZIndex = 8
		grad(collar, METAL0, METAL1, 90)
		ink(collar, 2)
		local rod = frame(kn, 12, 14, 6, 10, Color3.fromRGB(110, 120, 130), 0, 3)
		rod.ZIndex = 9
		local ball = disc(kn, 15, 21, 20, Color3.fromRGB(18, 20, 24))
		ball.ZIndex = 10
		ink(ball, 2)
		local spec = disc(kn, 12, 17, 6, WHITE, 0.35)
		spec.ZIndex = 11

		local function zone(y, h, target)
			local b = mk("TextButton", { BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
				Text = "", Position = UDim2.fromOffset(8, y), Size = UDim2.fromOffset(94, h), ZIndex = 12 }, root)
			b.MouseButton1Click:Connect(function()
				local S = getShip()
				if S and S.state == "flying" and S.mode ~= target then api.toggleMode() end
			end)
		end
		zone(26, 54, "fly")
		zone(80, 48, "ground")

		local PX, PY, LEN, ARC = 120, 148, 44, 58
		local function leanAt(p) return BRAKE_LEAN + BRAKE_A0 + (BRAKE_A1 - BRAKE_A0) * p end

		local base = frame(root, PX - 20, PY + 4, 40, 12, WHITE, 0, 4)
		base.ZIndex = 6
		grad(base, METAL0, METAL1, 90)
		ink(base, 2)

		for n = 0, 12 do
			local a = leanAt(n / 12)
			local d = disc(root, PX + ARC * math.sin(a), PY - ARC * math.cos(a), 3, DIM)
			d.ZIndex = 5
		end

		local ticks = {}
		for k = 0, 3 do
			local a = leanAt(k / 3)
			local t = mk("Frame", { BorderSizePixel = 0, BackgroundColor3 = DIM, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(PX + ARC * math.sin(a), PY - ARC * math.cos(a)),
				Size = UDim2.fromOffset(5, 12), Rotation = math.deg(a), ZIndex = 6 }, root)
			mk("UICorner", { CornerRadius = UDim.new(0, 2) }, t)
			ink(t, 1.5)
			ticks[k] = t
		end

		local lever = mk("Frame", { BorderSizePixel = 0, BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(PX, PY - LEN / 2), Size = UDim2.fromOffset(7, LEN), ZIndex = 7 }, root)
		mk("UICorner", { CornerRadius = UDim.new(0, 3) }, lever)
		grad(lever, METAL0, METAL1, 0)
		ink(lever, 2)
		local grip = disc(root, PX, PY - LEN, 15, Color3.fromRGB(24, 28, 34))
		grip.ZIndex = 8
		ink(grip, 2)
		local gripShine = disc(grip, 5, 5, 4, WHITE, 0.4)
		gripShine.ZIndex = 9
		local hinge = disc(root, PX, PY, 12, WHITE)
		hinge.ZIndex = 9
		grad(hinge, METAL0, METAL1, 90)
		ink(hinge, 2)

		local lastPos = nil
		local function placeLever(p)
			local a = leanAt(p)
			local dx, dy = math.sin(a), -math.cos(a)
			lever.Rotation = math.deg(a)
			lever.Position = UDim2.fromOffset(PX + dx * LEN / 2, PY + dy * LEN / 2)
			grip.Position = UDim2.fromOffset(PX + dx * (LEN + 3), PY + dy * (LEN + 3))
		end
		placeLever(0)

		local hold = mk("TextButton", { BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
			Text = "", Position = UDim2.fromOffset(108, 50), Size = UDim2.fromOffset(68, 120), ZIndex = 12 }, root)
		local function isPress(i)
			return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
		end
		hold.InputBegan:Connect(function(i)
			if isPress(i) then held.brakeUi = true end
		end)
		hold.InputEnded:Connect(function(i)
			if isPress(i) then held.brakeUi = false end
		end)
		hold.MouseLeave:Connect(function() held.brakeUi = false end)

		local lastKey, lastNotch = nil, nil
		function LV.hudUpdate(t, pos, notch, key)
			if not root.Visible then return end
			kn.Position = UDim2.fromOffset(32, 56 + math.clamp(t, 0, 1) * 94)
			if lastPos == nil or math.abs(pos - lastPos) > 1e-4 then
				lastPos = pos
				placeLever(pos)
			end
			if key ~= lastKey then
				lastKey = key
				for k, d in pairs(dots) do
					d.BackgroundColor3 = (k == key) and ACC or DIM
					labels[k].TextColor3 = (k == key) and ACC or WHITE
				end
			end
			if notch ~= lastNotch then
				lastNotch = notch
				for k = 0, 3 do
					local lit = k >= 1 and k <= notch
					ticks[k].BackgroundColor3 = lit and ((k == 3) and RED or YELLOW) or DIM
				end
				grip.BackgroundColor3 = (notch >= 3) and RED or ((notch > 0) and YELLOW or Color3.fromRGB(24, 28, 34))
			end
		end
	end

	return LV
end

State.armRotFromDown = function(d)
	local down = Vector3.new(0, -1, 0)
	local axis = down:Cross(d)
	local dp = down:Dot(d)
	if axis.Magnitude < 1e-4 then
		return dp > 0 and CFrame.new() or CFrame.Angles(math.pi, 0, 0)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(dp, -1, 1)))
end

State.shipArmIK = function(S, jr, pw, held)
	local sh = jr and jr.shoulder
	if not (sh and sh.Parent and sh.Part0 and sh.Part1) then return end
	local now = os.clock()
	local dt = math.clamp(now - (S.hwClock or now), 0, 0.1)
	S.hwClock = now

	if S.hwScan == nil then
		S.hwScan = true
		for _, e in ipairs(S.parts) do
			local n = e.part.Name
			if n == "ShiftKnob" then S.hwKnob = e elseif n == "BrakeGrip" then S.hwGrip = e end
		end
	end
	local knobE, gripE = S.hwKnob, S.hwGrip

	local ground = S.state == "flying" and S.mode == "ground"
	local wantB = gripE ~= nil and ((ground and (held.brake or held.brakeUi)) or (S.bBtn or 0) > 0.05)
	local wantS = knobE ~= nil and not wantB and S.shiftActT ~= nil and (now - S.shiftActT) < 0.25
	local wb, ws = S.hwB or 0, S.hwS or 0
	if wantB then wb = math.min(1, wb + dt * 7) else wb = math.max(0, wb - dt * 5) end
	if wantS then ws = math.min(1, ws + dt * 7) else ws = math.max(0, ws - dt * 5) end
	S.hwB, S.hwS = wb, ws
	local w = math.max(wb, ws)

	local waist = S.hwWaist
	if waist == nil or (waist and not waist.Parent) then
		waist = false
		for _, d in ipairs(sh.Part0:GetChildren()) do
			if d:IsA("Motor6D") and d.Name == "Waist" and d.Part0 and d.Part1 then waist = d break end
		end
		S.hwWaist = waist
	end

	if w <= 0.001 then
		if (S.hwLean or 0) > 0 then
			S.hwLean = 0
			if waist and waist.Parent then waist.Transform = CFrame.new() end
		end
		return
	end
	local ez = w * w * (3 - 2 * w)

	local pk = knobE and (S.cf * knobE.weld.C0.Position) or nil
	local pg = gripE and (S.cf * gripE.weld.C0.Position) or nil
	local tgt
	if pk and pg then tgt = pk:Lerp(pg, wb / (wb + ws + 1e-6)) else tgt = pg or pk end
	if not tgt then return end

	local elbow, hand
	for _, m in ipairs(jr.extra) do
		local n = m.Part1 and m.Part1.Name
		if n == "RightLowerArm" then elbow = m elseif n == "RightHand" then hand = m end
	end
	local L1, L2
	if elbow and elbow.Part0 == sh.Part1 and elbow.Part1 then
		L1 = (elbow.C0.Position - sh.C1.Position).Magnitude
		L2 = elbow.Part1.Size.Y * 0.9
		if hand and hand.Part0 == elbow.Part1 and hand.Part1 then
			L2 = (hand.C0.Position - elbow.C1.Position).Magnitude + hand.Part1.Size.Y * 0.4
		end
	end

	local p0w = pw(sh.Part0)
	local p0n = p0w
	local lean = S.hwLean or 0
	if waist and waist.Parent and L1 and waist.Part0 then
		local lowerCF = pw(waist.Part0)
		local rotL = lowerCF.Rotation
		local Wp = lowerCF * waist.C0.Position
		local function spin(th)
			return CFrame.new(Wp) * rotL * CFrame.Angles(-th, 0, 0) * rotL:Inverse() * CFrame.new(-Wp)
		end
		local p0up = spin(lean):Inverse() * p0w
		local reach = (L1 + L2) * 0.97
		local need = 0
		for i = 0, 10 do
			local th = i * 0.05
			need = th
			if ((spin(th) * p0up) * sh.C0.Position - tgt).Magnitude <= reach then break end
		end
		lean = lean + (need * ez - lean) * math.min(1, dt * 10)
		if lean > 0.002 then waist.Transform = CFrame.Angles(-lean, 0, 0) end
		S.hwLean = lean
		p0n = spin(lean) * p0up
	end

	local P = p0n * sh.C0.Position
	local toT = tgt - P
	local dist = toT.Magnitude
	if dist < 0.05 then return end
	local dirT = toT / dist
	local uW, lW = dirT, nil
	if L1 then
		local d = math.min(dist, (L1 + L2) * 0.999)
		local a = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
		local h = math.sqrt(math.max(L1 * L1 - a * a, 0))
		local pole = p0n:VectorToWorldSpace(Vector3.new(0.45, -1, 0.2))
		pole = pole - dirT * pole:Dot(dirT)
		pole = pole.Magnitude > 1e-3 and pole.Unit or Vector3.new(0, -1, 0)
		local E = P + dirT * a + pole * h
		uW = (E - P).Unit
		local lv = (P + dirT * d) - E
		if lv.Magnitude > 1e-3 then lW = lv.Unit else lW = uW end
	end

	local base = sh.C0 - sh.C0.Position
	local B = sh.C0:Inverse() * CFrame.new(sh.C0.Position) * State.armRotFromDown(p0n:VectorToObjectSpace(uW)) * base
	sh.Transform = sh.Transform:Lerp(B, ez)

	if elbow and lW then
		local upperCF = p0n * sh.C0 * B * sh.C1:Inverse()
		local lLoc = upperCF:VectorToObjectSpace(lW)
		local eb = elbow.C0:Inverse() * CFrame.new(elbow.C0.Position) * State.armRotFromDown(lLoc) * (elbow.C0 - elbow.C0.Position)
		elbow.Transform = CFrame.new():Lerp(eb, ez)
	end
end

State.shipRearInit = function(S)
	if S.rg ~= nil then return S.rg end
	local rg = { arm = {}, door = {} }
	for _, e in ipairs(S.rdoorParts or {}) do
		rg.door[#rg.door + 1] = e
		if e.part.Name == "Plate" then rg.plate = e end
	end
	for _, e in ipairs(S.rarmParts or {}) do rg.arm[e.part.Name] = e end
	if not (rg.plate and rg.arm.RGBase and rg.arm.RGGlow) then S.rg = false; return false end
	rg.sc = rg.plate.part.Size.Z / 3.4
	rg.half = rg.plate.part.Size.Z / 2
	rg.H = rg.plate.rel * CFrame.new(0, 0, -rg.half)

	local freeL = Vector3.new(0, 0, 2 * rg.half)
	local d = (rg.H * CFrame.Angles(0.3, 0, 0)) * freeL - rg.H * freeL
	rg.sgn = (d:Dot(rg.plate.rel.UpVector) >= 0) and 1 or -1
	S.rg = rg
	return rg
end

State.shipRearDoor = function(S, ang)
	local rg = State.shipRearInit(S)
	if not rg then return end
	local m = rg.H * CFrame.Angles(rg.sgn * ang, 0, 0) * rg.H:Inverse()
	for _, e in ipairs(rg.door) do e.weld.C0 = m * e.rel end
end

State.buildRearArmDetail = function(add, cylX, c0, col)
	local METAL, SMOOTH, NEON = col.METAL, col.SMOOTH, col.NEON
	local GUN, STEEL = Color3.fromRGB(30, 36, 44), Color3.fromRGB(96, 108, 122)
	local LIGHT, WHITEP = Color3.fromRGB(200, 208, 216), Color3.fromRGB(228, 232, 235)
	local GREEND, GLOW, AMBER = Color3.fromRGB(26, 143, 37), col.GLOW, Color3.fromRGB(255, 176, 40)
	local one = Vector3.new(1, 1, 1)
	local spec = {}
	State.rearSpec = spec

	local function box(name, f, x, y, sx, sy, sz, color, mat, rot)
		local sp = { name = name, f = f, x = x, y = y, sx = sx, sy = sy, sz = sz, rot = rot }
		spec[#spec + 1] = sp
		add(name, one, c0, color, mat, 1, nil, "rarm")
		return sp
	end
	local function cylZ(name, f, x, y, len, dia, color, mat)
		local sp = { name = name, f = f, x = x, y = y, sx = len, sy = dia, sz = dia, rot = CFrame.Angles(0, math.rad(90), 0) }
		spec[#spec + 1] = sp
		add(name, cylX(1, 1), c0, color, mat, 1, "cyl", "rarm")
		return sp
	end
	local function dyn(name, color, mat, shape)
		add(name, shape == "cyl" and cylX(1, 1) or one, c0, color, mat, 1, shape, "rarm")
	end

	cylZ("RGCollar", 0.12, 0, 0, 0.16, 1.05, GUN, METAL)
	for i = 0, 5 do
		local th = math.rad(60 * i)
		cylZ("RGBolt" .. i, 0.21, -0.46 * math.sin(th), 0.46 * math.cos(th), 0.04, 0.11, LIGHT, METAL)
	end

	for i = 0, 7 do
		local th = math.rad(45 * i)
		box("RGHouseA" .. i, 0.45, -0.44 * math.sin(th), 0.44 * math.cos(th), 0.38, 0.1, 0.5, i % 2 == 0 and GUN or STEEL, METAL, CFrame.Angles(0, 0, th))
		box("RGHouseB" .. i, 0.975, -0.38 * math.sin(th), 0.38 * math.cos(th), 0.33, 0.1, 0.45, i % 2 == 0 and WHITEP or STEEL, METAL, CFrame.Angles(0, 0, th))
	end
	for i = 1, 4 do
		local th = math.rad(45 + 90 * (i - 1))
		box("RGStripA" .. i, 0.45, -0.505 * math.sin(th), 0.505 * math.cos(th), 0.12, 0.03, 0.4, GLOW, NEON, CFrame.Angles(0, 0, th))
	end

	for i = 1, 4 do
		box("RGFin" .. i, 0.28 + 0.1 * (i - 1), 0, 0.62, 0.5, 0.24, 0.05, STEEL, METAL)
	end

	for i, s in ipairs({ -1, 1 }) do
		cylZ("RGPipe" .. i, 0.72, s * 0.58, 0, 1.0, 0.12, GREEND, NEON)
		cylZ("RGClampA" .. i, 0.45, s * 0.58, 0, 0.07, 0.19, STEEL, METAL)
		cylZ("RGClampB" .. i, 0.95, s * 0.58, 0, 0.07, 0.19, STEEL, METAL)
	end

	cylZ("RGBatt", 0.75, 0, -0.62, 0.9, 0.38, GUN, METAL)
	cylZ("RGBand1", 0.5, 0, -0.62, 0.05, 0.4, GLOW, NEON)
	cylZ("RGBand2", 0.95, 0, -0.62, 0.05, 0.4, GLOW, NEON)

	box("RGCapBase", 0.97, 0, 0.45, 0.5, 0.08, 0.6, STEEL, METAL)
	cylZ("RGGlass", 0.97, 0, 0.78, 0.6, 0.55, Color3.fromRGB(176, 236, 214), Enum.Material.Glass).tr = 0.5
	cylZ("RGCapA", 0.65, 0, 0.78, 0.08, 0.62, STEEL, METAL)
	cylZ("RGCapB", 1.29, 0, 0.78, 0.08, 0.62, STEEL, METAL)

	cylZ("RGCol1", 1.75, 0, 0, 0.45, 0.7, STEEL, METAL)
	cylZ("RGCol2", 2.2, 0, 0, 0.3, 0.6, GUN, METAL)
	cylZ("RGCoilA", 2.45, 0, 0, 0.07, 0.66, GREEND, NEON)
	cylZ("RGCoilB", 2.6, 0, 0, 0.07, 0.66, GREEND, NEON)
	cylZ("RGMuz", 2.82, 0, 0, 0.22, 0.6, LIGHT, METAL)
	cylZ("RGLens1", 2.93, 0, 0, 0.05, 0.46, GUN, SMOOTH)
	cylZ("RGLens2", 2.955, 0, 0, 0.05, 0.32, GLOW, NEON)
	box("RGRail", 2.05, 0, 0.43, 0.06, 0.06, 1.3, STEEL, METAL)
	box("RGSight", 1.6, 0, 0.53, 0.05, 0.2, 0.4, GUN, METAL)

	dyn("RGCore", GLOW, NEON, "sphere")
	dyn("RGRingA", GLOW, NEON, "cyl")
	dyn("RGRingB", GREEND, NEON, "cyl")
	dyn("RGLamp", AMBER, NEON, nil)
	for i = 1, 6 do
		dyn("RGPetal" .. i, i % 2 == 0 and LIGHT or STEEL, METAL, nil)
		dyn("RGPetalG" .. i, GLOW, NEON, nil)
	end

	dyn("RGPistonU", STEEL, METAL, "cyl")
	dyn("RGPistonF", STEEL, METAL, "cyl")
	dyn("RGWristRing", GLOW, NEON, "cyl")
	dyn("RGColU1", GUN, METAL, "cyl")
	dyn("RGColU2", GUN, METAL, "cyl")
	dyn("RGColF1", STEEL, METAL, "cyl")
	dyn("RGColF2", STEEL, METAL, "cyl")
	dyn("RGHubL", GUN, METAL, "cyl")
	dyn("RGHubR", GUN, METAL, "cyl")
	dyn("RGHubCapL", GLOW, NEON, "cyl")
	dyn("RGHubCapR", GLOW, NEON, "cyl")
	dyn("RGCable", GREEND, NEON, "cyl")
	dyn("RGCable2", GUN, SMOOTH, "cyl")
end

State.shipRearArm = function(S, ext, g, aimShip, kick)
	local rg = State.shipRearInit(S)
	if not rg then return nil end
	kick = kick or 0
	local sc, A = rg.sc, rg.arm
	local vis = ext > 0.02
	local B = rg.plate.rel
	local n = B.UpVector
	local u = ext * ext * (3 - 2 * ext)
	local k = 0.12 + 0.88 * u
	local out = Vector3.new(B.Position.X, 0, B.Position.Z)
	out = out.Magnitude > 1e-3 and out.Unit or Vector3.new(0, 0, 1)
	local dirU = (Vector3.new(0, 0.95, 0) + out * 0.3).Unit
	local fwdUp = Vector3.new(0, 0.35, -1).Unit
	local dirF = (dirU * (1 - 0.7 * g) + fwdUp * (0.7 * g)).Unit
	local aim = (aimShip and aimShip.Magnitude > 1e-3) and aimShip.Unit or fwdUp
	local d3 = dirF * (1 - g) + aim * g
	d3 = d3.Magnitude > 1e-3 and d3.Unit or aim

	local S0 = B.Position + n * (0.15 * sc) - n * (0.8 * sc * (1 - u))
	local E = S0 + dirU * (4.4 * sc * k)
	local W = E + dirF * (3.6 * sc * k)
	local bodyEnd = W + d3 * (1.3 * sc * k)
	local tip = W + d3 * (3.0 * sc * k) - d3 * (kick * 0.35 * sc)

	local function seg(e, a, b, dia)
		local len = math.max((b - a).Magnitude, 0.02)
		local dir = (b - a)
		dir = dir.Magnitude > 1e-4 and dir.Unit or Vector3.new(0, 1, 0)
		local upv = math.abs(dir.Y) > 0.98 and Vector3.xAxis or Vector3.yAxis
		e.part.Size = Vector3.new(len, dia, dia)
		e.weld.C0 = CFrame.lookAt((a + b) / 2, (a + b) / 2 + dir, upv) * CFrame.Angles(0, math.pi / 2, 0)
		e.part.Transparency = vis and 0 or 1
	end
	local function ball(e, pos, dia, tr)
		e.part.Size = Vector3.new(dia, dia, dia)
		e.weld.C0 = CFrame.new(pos)
		e.part.Transparency = vis and (tr or 0) or 1
	end
	ball(A.RGBase, S0, 0.95 * sc)
	seg(A.RGUpper, S0, E, 0.55 * sc)
	ball(A.RGElbow, E, 0.78 * sc)
	seg(A.RGFore, E, W, 0.48 * sc)
	ball(A.RGWrist, W, 0.72 * sc)
	seg(A.RGBody, W, bodyEnd, 0.55 * sc)
	seg(A.RGBarrel, bodyEnd, tip, 0.42 * sc)
	seg(A.RGRing, bodyEnd + d3 * (0.05 * sc), bodyEnd + d3 * (0.25 * sc), 0.8 * sc)
	ball(A.RGGlow, tip, (0.3 + 0.22 * g + 0.2 * kick) * sc, 0.6 * (1 - g))

	local spec = State.rearSpec
	if spec and A.RGCore then
		local det = vis and ext > 0.25
		local q = sc * k
		local now = os.clock()
		local dt = math.min(now - (rg.t0 or now), 0.1)
		rg.t0 = now
		rg.ph = (rg.ph or 0) + dt * (2.2 + 7 * g + kick * 6)
		local ph = rg.ph
		local upv = math.abs(d3.Y) > 0.98 and Vector3.xAxis or Vector3.yAxis
		local HF = CFrame.lookAt(W, W + d3, upv)
		local function setp(e, sx, sy, sz, cf, tr)
			if not e then return end
			e.part.Size = Vector3.new(sx, sy, sz)
			e.weld.C0 = cf
			e.part.Transparency = det and (tr or 0) or 1
		end
		local function putd(name, f, x, y, sx, sy, sz, rot, tr)
			setp(A[name], sx * q, sy * q, sz * q, HF * CFrame.new(x * q, y * q, -f * q) * (rot or CFrame.new()), tr)
		end
		local function segd(e, a, b, dia)
			if not e then return end
			seg(e, a, b, dia)
			if not det then e.part.Transparency = 1 end
		end
		for i = 1, #spec do
			local sp = spec[i]
			setp(A[sp.name], sp.sx * q, sp.sy * q, sp.sz * q, HF * CFrame.new(sp.x * q, sp.y * q, -sp.f * q) * (sp.rot or CFrame.new()), sp.tr)
		end

		local bob = math.sin(now * 3) * 0.03
		local dc = 0.24 + 0.16 * g + 0.12 * kick
		putd("RGCore", 0.97, 0, 0.78 + bob, dc, dc, dc)
		putd("RGRingA", 0.97, 0, 0.78 + bob, 0.04, 0.46, 0.46, CFrame.Angles(0, ph, 0) * CFrame.Angles(math.rad(35), 0, math.rad(90)))
		putd("RGRingB", 0.97, 0, 0.78 + bob, 0.04, 0.36, 0.36, CFrame.Angles(0, -ph * 1.3, 0) * CFrame.Angles(math.rad(-40), 0, math.rad(90)))
		putd("RGLamp", 1.6, 0, 0.66, 0.09, 0.09, 0.09, nil, (math.sin(now * 8) > 0) and 0 or 0.7)

		local al = 0.06 + g * 0.6 + kick * 0.3
		for i = 1, 6 do
			local th = (i - 1) * math.pi / 3 + math.pi / 6
			local cf = HF * CFrame.new(0, 0, -2.55 * q) * CFrame.Angles(0, 0, th) * CFrame.new(0, 0.31 * q, 0) * CFrame.Angles(al, 0, 0) * CFrame.new(0, 0, -0.325 * q)
			setp(A["RGPetal" .. i], 0.26 * q, 0.04 * q, 0.65 * q, cf)
			setp(A["RGPetalG" .. i], 0.08 * q, 0.02 * q, 0.5 * q, cf * CFrame.new(0, -0.03 * q, 0))
		end

		local X = Vector3.xAxis
		local sideV = X * (0.5 * sc)
		local ud, fd = (E - S0), (W - E)
		ud = ud.Magnitude > 1e-4 and ud.Unit or Vector3.yAxis
		fd = fd.Magnitude > 1e-4 and fd.Unit or Vector3.yAxis
		segd(A.RGPistonU, S0:Lerp(E, 0.15) + sideV, S0:Lerp(E, 0.7) + sideV, 0.2 * sc)
		segd(A.RGPistonF, E:Lerp(W, 0.3) - sideV, E:Lerp(W, 0.85) - sideV, 0.2 * sc)
		segd(A.RGWristRing, W + d3 * (0.05 * sc), W + d3 * (0.19 * sc), 0.9 * sc)
		local p1, p2 = S0:Lerp(E, 0.35), S0:Lerp(E, 0.65)
		segd(A.RGColU1, p1 - ud * (0.06 * sc), p1 + ud * (0.06 * sc), 0.72 * sc)
		segd(A.RGColU2, p2 - ud * (0.06 * sc), p2 + ud * (0.06 * sc), 0.72 * sc)
		local p3, p4 = E:Lerp(W, 0.4), E:Lerp(W, 0.7)
		segd(A.RGColF1, p3 - fd * (0.06 * sc), p3 + fd * (0.06 * sc), 0.62 * sc)
		segd(A.RGColF2, p4 - fd * (0.06 * sc), p4 + fd * (0.06 * sc), 0.62 * sc)
		segd(A.RGHubL, E - X * (0.46 * sc), E - X * (0.36 * sc), 0.95 * sc)
		segd(A.RGHubR, E + X * (0.36 * sc), E + X * (0.46 * sc), 0.95 * sc)
		segd(A.RGHubCapL, E - X * (0.455 * sc), E - X * (0.53 * sc), 0.4 * sc)
		segd(A.RGHubCapR, E + X * (0.455 * sc), E + X * (0.53 * sc), 0.4 * sc)
		local pv = X:Cross(dirF)
		pv = pv.Magnitude > 1e-4 and pv.Unit or Vector3.zAxis
		segd(A.RGCable, E:Lerp(W, 0.1) + pv * (0.42 * sc), E:Lerp(W, 0.9) + pv * (0.42 * sc), 0.07 * sc)
		segd(A.RGCable2, E:Lerp(W, 0.1) + pv * (0.4 * sc) - X * (0.14 * sc), E:Lerp(W, 0.9) + pv * (0.4 * sc) - X * (0.14 * sc), 0.09 * sc)
	end

	if not rg.fxTried then
		rg.fxTried = true
		pcall(function()
			local function newLight(part, range)
				local pl = Instance.new("PointLight")
				pl.Color = Color3.fromRGB(70, 255, 60)
				pl.Range = range
				pl.Brightness = 1
				pl.Enabled = false
				pl.Parent = part
				return pl
			end
			if A.RGCore then rg.coreLight = newLight(A.RGCore.part, 10) end
			if A.RGGlow then rg.glowLight = newLight(A.RGGlow.part, 14) end
			local function newEmitter(parent)
				local pe = Instance.new("ParticleEmitter")
				pe.Enabled = false
				pe.Rate = 0
				pe.Texture = Config.ParticleSpark
				pe.LightEmission = 1
				pe.Color = ColorSequence.new(Color3.fromRGB(205, 255, 150), Color3.fromRGB(40, 200, 50))
				pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
				pe.Parent = parent
				return pe
			end
			if A.RGCore then
				local ce = newEmitter(A.RGCore.part)
				ce.Lifetime = NumberRange.new(0.4, 0.8)
				ce.Speed = NumberRange.new(0.5, 1.5)
				ce.SpreadAngle = Vector2.new(180, 180)
				ce.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14 * sc), NumberSequenceKeypoint.new(1, 0) })
				rg.coreEmit = ce
			end
			if A.RGBarrel then
				local att = Instance.new("Attachment")
				att.Name = "RGMuzzleAtt"
				att.Parent = A.RGBarrel.part
				local pe = newEmitter(att)
				pe.Lifetime = NumberRange.new(0.35, 0.7)
				pe.Speed = NumberRange.new(5, 12)
				pe.SpreadAngle = Vector2.new(22, 22)
				pe.EmissionDirection = Enum.NormalId.Right
				pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * sc), NumberSequenceKeypoint.new(1, 0) })
				rg.att, rg.emit = att, pe
			end
		end)
	end
	local lit = vis and ext > 0.25
	pcall(function()
		if rg.coreLight then rg.coreLight.Enabled = lit; rg.coreLight.Brightness = 1 + 2 * g + 2 * kick end
		if rg.glowLight then rg.glowLight.Enabled = vis; rg.glowLight.Brightness = 0.5 + 3 * g + 3 * kick end
		if rg.coreEmit then rg.coreEmit.Enabled = lit and g > 0.05; rg.coreEmit.Rate = 4 + 26 * g end
		if rg.att and A.RGBarrel then rg.att.Position = Vector3.new(A.RGBarrel.part.Size.X / 2, 0, 0) end
	end)
	if ext < 0.5 then rg.fired = false end
	if rg.emit and kick > 0.9 and not rg.fired then
		rg.fired = true
		pcall(function() rg.emit:Emit(18) end)
	end
	return tip
end

State.space = { k = 0, visible = false }
do
	local Sp = State.space
	local Lighting = game:GetService("Lighting")
	local TweenService = game:GetService("TweenService")
	local rng = Random.new(20)
	Sp.SPACE = Vector3.new(0, 60000, 0)

	Sp.TEX = {
		terra   = "rbxassetid://81971895872632",
		nuvens  = "rbxassetid://139409485801059",
		deserto = "rbxassetid://133215458029546",
		gelo    = "rbxassetid://94887538555701",
		neon    = "rbxassetid://103941792770202",
		lua     = "rbxassetid://124632665944074",

		k22planeta = "rbxassetid://135896229724567",
		k22nuvens  = "rbxassetid://98367817404331",
		k22aneis   = "rbxassetid://85037729318942",
		k22corona  = "rbxassetid://135679390547710",
		k22sol1    = "rbxassetid://115232626144669",
		k22sol2    = "rbxassetid://124809144154752",
		malha   = "",
	}
	Sp.MESH_DIAM = 2
	Sp.hasMesh = Sp.TEX.malha ~= nil and Sp.TEX.malha ~= ""

	Sp.FLIP = false
	Sp.meshBase = nil

	Sp.FLIPV = false
	if not Sp.hasMesh then
		local ok, res = pcall(function()
			local wf = writefile
			local gca = getcustomasset or getsynasset
			assert(wf and gca, "executor sem writefile/getcustomasset")
			local N, M = 48, 96
			local verts, faces = {}, {}
			for i = 0, N do
				local phi = math.pi * i / N
				local y, r = math.cos(phi), math.sin(phi)
				for j = 0, M do
					local th = -2 * math.pi * j / M
					local x, z = r * math.cos(th), r * math.sin(th)
					local v = i / N
					if Sp.FLIPV then v = 1 - v end
					verts[#verts + 1] = string.pack("<ffffffffBBBBBBBB", x, y, z, x, y, z, j / M, v, 0, 0, 127, 127, 255, 255, 255, 255)
				end
			end
			local function idx(i, j) return i * (M + 1) + j end
			local nf = 0
			local function tri(a, b, c)
				if Sp.FLIP then b, c = c, b end
				faces[#faces + 1] = string.pack("<III", a, b, c)
				nf += 1
			end
			for i = 0, N - 1 do
				for j = 0, M - 1 do
					local A, B, C, D = idx(i, j), idx(i, j + 1), idx(i + 1, j), idx(i + 1, j + 1)
					if i > 0 then tri(A, C, B) end
					if i < N - 1 then tri(B, C, D) end
				end
			end
			local data = "version 2.00\n" .. string.pack("<I2BBII", 12, 40, 12, #verts, nf) .. table.concat(verts) .. table.concat(faces)
			local fname = "RickSphere_v27.mesh"
			wf(fname, data)
			local asset = gca(fname)
			assert(asset and asset ~= "", "getcustomasset vazio")
			return asset
		end)
		if ok and res then
			Sp.TEX.malha, Sp.hasMesh = res, true
			print("[Rick] planetas: esfera criada com writefile/getcustomasset - tamanho original")
		else
			warn("[Rick] planetas: esfera por arquivo falhou (" .. tostring(res) .. "), tentando EditableMesh")
		end
	end
	if not Sp.hasMesh then
		local ok, res = pcall(function()
			local AssetService = game:GetService("AssetService")
			local em = AssetService:CreateEditableMesh()
			local N, M = 40, 80
			local V, UV, NR = {}, {}, {}
			for i = 0, N do
				local phi = math.pi * i / N
				local y, r = math.cos(phi), math.sin(phi)
				V[i], UV[i], NR[i] = {}, {}, {}
				for j = 0, M do
					local th = 2 * math.pi * j / M
					local pos = Vector3.new(r * math.cos(th), y, r * math.sin(th))
					V[i][j] = em:AddVertex(pos)
					UV[i][j] = em:AddUV(Vector2.new(j / M, i / N))
					NR[i][j] = em:AddNormal(pos)
				end
			end
			local function tri(a, b, c)
				if Sp.FLIP then b, c = c, b end
				local f = em:AddTriangle(V[a[1]][a[2]], V[b[1]][b[2]], V[c[1]][c[2]])
				em:SetFaceUVs(f, { UV[a[1]][a[2]], UV[b[1]][b[2]], UV[c[1]][c[2]] })
				em:SetFaceNormals(f, { NR[a[1]][a[2]], NR[b[1]][b[2]], NR[c[1]][c[2]] })
			end
			for i = 0, N - 1 do
				for j = 0, M - 1 do
					local A, B, C, D = { i, j }, { i, j + 1 }, { i + 1, j }, { i + 1, j + 1 }
					if i > 0 then tri(A, B, C) end
					if i < N - 1 then tri(B, D, C) end
				end
			end

			local base = AssetService:CreateMeshPartAsync(Content.fromObject(em))
			base.Anchored = true
			base.CanCollide, base.CanQuery, base.CanTouch, base.CastShadow = false, false, false, false
			pcall(function() base.CollisionFidelity = Enum.CollisionFidelity.Box end)
			return base
		end)
		if ok and res then
			Sp.meshBase, Sp.hasMesh = res, true
			print("[Rick] planetas: esfera gerada no jogo (EditableMesh) - texturas ativas")
		else
			warn("[Rick] planetas: nao deu pra gerar a esfera (" .. tostring(res) .. "). Ative 'Allow Mesh & Image APIs' (Permitir APIs de Mesh e Imagem) nas configuracoes do jogo, ou cole um MeshId em Sp.TEX.malha. Por enquanto: esferas lisas.")
		end
	end
	Sp.SCALE = Sp.meshBase and 1.05 or 3.2
	local MAT_SMOOTH, MAT_NEON, MAT_ICE = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Ice

	Sp.discBase, Sp.discMeshId, Sp.discReady = nil, nil, false
	local DISC_H = 0.01
	do
		local ok, res = pcall(function()
			local wf = writefile
			local gca = getcustomasset or getsynasset
			assert(wf and gca, "executor sem writefile/getcustomasset")
			local h = DISC_H
			local function vtx(x, y, z, ny, u, v)
				return string.pack("<ffffffffBBBBBBBB", x, y, z, 0, ny, 0, u, v, 0, 0, 127, 127, 255, 255, 255, 255)
			end
			local verts = {
				vtx(-1, h, -1, 1, 0, 0), vtx(1, h, -1, 1, 1, 0), vtx(-1, h, 1, 1, 0, 1), vtx(1, h, 1, 1, 1, 1),
				vtx(-1, -h, -1, -1, 0, 0), vtx(1, -h, -1, -1, 1, 0), vtx(-1, -h, 1, -1, 0, 1), vtx(1, -h, 1, -1, 1, 1),
			}
			local faces = {
				string.pack("<III", 0, 2, 1), string.pack("<III", 1, 2, 3),
				string.pack("<III", 4, 5, 6), string.pack("<III", 5, 7, 6),
			}
			local data = "version 2.00\n" .. string.pack("<I2BBII", 12, 40, 12, #verts, #faces) .. table.concat(verts) .. table.concat(faces)
			local fname = "RickDisc_v28.mesh"
			wf(fname, data)
			local asset = gca(fname)
			assert(asset and asset ~= "", "getcustomasset vazio")
			return asset
		end)
		if ok and res then
			Sp.discMeshId, Sp.discReady = res, true
		else
			local ok2, res2 = pcall(function()
				local AssetService = game:GetService("AssetService")
				local em = AssetService:CreateEditableMesh()
				local h = DISC_H
				local function V(x, y, z) return em:AddVertex(Vector3.new(x, y, z)) end
				local function UVp(u, v) return em:AddUV(Vector2.new(u, v)) end
				local tv = { V(-1, h, -1), V(1, h, -1), V(-1, h, 1), V(1, h, 1) }
				local bv = { V(-1, -h, -1), V(1, -h, -1), V(-1, -h, 1), V(1, -h, 1) }
				local uv = { UVp(0, 0), UVp(1, 0), UVp(0, 1), UVp(1, 1) }
				local nt, nb = em:AddNormal(Vector3.new(0, 1, 0)), em:AddNormal(Vector3.new(0, -1, 0))
				local function tri(a, b, c, ua, ub, uc, n)
					local f = em:AddTriangle(a, b, c)
					em:SetFaceUVs(f, { ua, ub, uc })
					em:SetFaceNormals(f, { n, n, n })
				end
				tri(tv[1], tv[3], tv[2], uv[1], uv[3], uv[2], nt)
				tri(tv[2], tv[3], tv[4], uv[2], uv[3], uv[4], nt)
				tri(bv[1], bv[2], bv[3], uv[1], uv[2], uv[3], nb)
				tri(bv[2], bv[4], bv[3], uv[2], uv[4], uv[3], nb)
				local base = AssetService:CreateMeshPartAsync(Content.fromObject(em))
				base.Anchored = true
				base.CanCollide, base.CanQuery, base.CanTouch, base.CastShadow = false, false, false, false
				pcall(function() base.CollisionFidelity = Enum.CollisionFidelity.Box end)
				return base
			end)
			if ok2 and res2 then
				Sp.discBase, Sp.discReady = res2, true
			else
				warn("[Rick] aneis do K-22: nao deu pra gerar o disco (" .. tostring(res2) .. "). Os aneis ficam no visual antigo.")
			end
		end
	end

	local function setupTexPart(p, cf, transp, mat, color)
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
		p.Color = color or Color3.new(1, 1, 1)
		p.Material = mat or MAT_SMOOTH
		p.Transparency = transp or 0
		p.CFrame = cf
	end

	Sp.alphaBase = Sp.meshBase
	if not Sp.alphaBase and Sp.hasMesh and type(Sp.TEX.malha) == "string" and Sp.TEX.malha ~= "" then
		local okA, mpA = pcall(function()
			local base = game:GetService("AssetService"):CreateMeshPartAsync(Content.fromUri(Sp.TEX.malha))
			base.Anchored = true
			base.CanCollide, base.CanQuery, base.CanTouch, base.CastShadow = false, false, false, false
			return base
		end)
		if okA and mpA then
			Sp.alphaBase = mpA
		else
			warn("[Rick] K-22: nao deu pra criar MeshPart com alpha (" .. tostring(mpA) .. "). As nuvens do K-22 ficam desligadas (sem elas o planeta aparece normal).")
		end
	end
	Sp.discImgs = {}

	function Sp.texBall(parent, cf, R, id, transp, mat, color, alpha)
		if not Sp.hasMesh or type(id) ~= "string" or id == "" then return nil end
		local d = math.min(2 * R, 2048)
		local p
		if alpha then
			if not Sp.alphaBase then return nil end
			p = Sp.alphaBase:Clone()
			p.Size = Vector3.new(d, d, d)
			p.TextureID = ""
			local sa = Instance.new("SurfaceAppearance")
			sa.ColorMap = id
			sa.AlphaMode = Enum.AlphaMode.Transparency
			sa.Parent = p
		elseif Sp.meshBase then
			p = Sp.meshBase:Clone()
			p.Size = Vector3.new(d, d, d)
			p.TextureID = id
		else
			p = Instance.new("Part")
			p.Size = Vector3.new(d, d, d)
			local m = Instance.new("SpecialMesh")
			m.MeshType = Enum.MeshType.FileMesh
			m.MeshId = Sp.TEX.malha
			m.TextureId = id
			m.Scale = Vector3.new(1, 1, 1) * (2 * R / (Sp.MESH_DIAM or 2))
			m.Parent = p
		end
		setupTexPart(p, cf, transp, mat, color)
		p.Parent = parent
		return p
	end

	function Sp.texDisc(parent, cf, R, id, transp, mat, color)
		if type(id) ~= "string" or id == "" then return nil end
		local p = Instance.new("Part")
		p.Size = Vector3.new(2 * R, 0.2, 2 * R)
		setupTexPart(p, cf, 1, MAT_SMOOTH, color)
		local imgs = {}
		for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Bottom }) do
			local g = Instance.new("SurfaceGui")
			g.Face = face
			g.Adornee = p
			g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
			g.CanvasSize = Vector2.new(1024, 1024)
			g.LightInfluence = 0
			g.Brightness = 1
			g.AlwaysOnTop = false
			g.ClipsDescendants = false
			local im = Instance.new("ImageLabel")
			im.BackgroundTransparency = 1
			im.BorderSizePixel = 0
			im.Size = UDim2.fromScale(1, 1)
			im.Image = id
			im.ImageTransparency = transp or 0
			im.Parent = g
			g.Parent = p
			imgs[#imgs + 1] = im
		end
		Sp.discImgs[p] = { imgs = imgs, base = transp or 0 }
		p.Parent = parent
		return p
	end

	local function newPlanet(name, center, tilt)
		local m = Instance.new("Model")
		m.Name = name
		return { model = m, list = {}, T = CFrame.new(center) * tilt, anims = {}, center = center }
	end

	local function mkPart(P, cf, size, color, mat, transp, ball)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		local cs = Vector3.new(math.clamp(size.X, 0.05, 2048), math.clamp(size.Y, 0.05, 2048), math.clamp(size.Z, 0.05, 2048))
		p.Size = cs
		p.Color = color
		p.Material = mat or MAT_SMOOTH
		p.Transparency = transp or 0
		if ball then
			local m = Instance.new("SpecialMesh")
			m.MeshType = Enum.MeshType.Sphere
			if size.X > 2048 or size.Y > 2048 or size.Z > 2048 then m.Scale = Vector3.new(size.X / cs.X, size.Y / cs.Y, size.Z / cs.Z) end
			m.Parent = p
		end
		p.CFrame = cf
		p.Parent = P.model
		P.list[#P.list + 1] = { part = p, base = p.Transparency }
		return p
	end

	local function newGroup(P)
		local r = mkPart(P, P.T, Vector3.new(1, 1, 1), Color3.new(), MAT_SMOOTH, 1, false)
		P.list[#P.list] = nil
		return r
	end

	local function put(P, g, lcf, size, color, mat, transp, ball)
		if not g then return mkPart(P, P.T * lcf, size, color, mat, transp, ball) end
		local p = mkPart(P, g.CFrame * lcf, size, color, mat, transp, ball)
		p.Anchored, p.Massless = false, true
		local w = Instance.new("Weld")
		w.Part0, w.Part1, w.C0 = g, p, lcf
		w.Parent = p
		return p
	end

	local function sphere(P, g, R, color, mat, transp)
		return put(P, g, CFrame.new(), Vector3.new(2 * R, 2 * R, 2 * R), color, mat, transp, true)
	end

	local function texMesh(p, R, id)
		local m = p:FindFirstChildOfClass("SpecialMesh")
		if not m then return end
		m.MeshType = Enum.MeshType.FileMesh
		m.MeshId = Sp.TEX.malha
		m.TextureId = id
		m.Scale = Vector3.new(1, 1, 1) * (2 * R / (Sp.MESH_DIAM or 2))
	end

	local function mkTexPart(P, g, lcf, R, id, transp, mat)
		local p = Sp.meshBase:Clone()
		local d = math.min(2 * R, 2048)
		p.Size = Vector3.new(d, d, d)
		p.Color = Color3.new(1, 1, 1)
		p.Material = mat or MAT_SMOOTH
		p.Transparency = transp or 0
		p.TextureID = id
		if g then
			p.CFrame = g.CFrame * lcf
			p.Anchored, p.Massless = false, true
			local w = Instance.new("Weld")
			w.Part0, w.Part1, w.C0 = g, p, lcf
			w.Parent = p
		else
			p.CFrame = P.T * lcf
		end
		p.Parent = P.model
		P.list[#P.list + 1] = { part = p, base = p.Transparency }
		return p
	end

	local function texSphere(P, R, id, transp, mat, spin)
		local p
		if Sp.meshBase then
			p = mkTexPart(P, nil, CFrame.new(), R, id, transp, mat)
		else
			p = put(P, nil, CFrame.new(), Vector3.new(2048, 2048, 2048), Color3.new(1, 1, 1), mat or MAT_SMOOTH, transp or 0, true)
			texMesh(p, R, id)
		end
		if spin then P.anims[#P.anims + 1] = function(t) p.CFrame = P.T * CFrame.Angles(0, t * spin, 0) end end
		return p
	end

	local function surf(dir, dist, yaw)
		local ref = math.abs(dir.Y) < 0.95 and Vector3.yAxis or Vector3.xAxis
		local right = ref:Cross(dir).Unit
		return CFrame.fromMatrix(dir * dist, right, dir) * CFrame.Angles(0, yaw or 0, 0)
	end

	local function randDir()
		local z = rng:NextNumber(-1, 1)
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(1 - z * z)
		return Vector3.new(r * math.cos(a), z, r * math.sin(a))
	end

	local function patch(P, g, R, dir, w, d, h, color, mat, transp, lift)
		return put(P, g, surf(dir, R - h / 2 + (lift or 0.012 * R), rng:NextNumber(0, math.pi * 2)), Vector3.new(w, h, d), color, mat, transp, true)
	end

	local function crater(P, g, R, dir, w, dark, light)
		patch(P, g, R, dir, w, w, 0.05 * R, light, MAT_SMOOTH, 0, 0.014 * R)
		patch(P, g, R, dir, w * 0.68, w * 0.68, 0.05 * R, dark, MAT_SMOOTH, 0, 0.02 * R)
	end

	local function ring(P, g, radius, band, thick, n, color, transp, mat)
		local chord = 2 * radius * math.tan(math.pi / n) * 1.05
		for i = 0, n - 1 do
			local a = 2 * math.pi * i / n
			put(P, g, CFrame.new(math.cos(a) * radius, 0, math.sin(a) * radius) * CFrame.Angles(0, -a - math.pi / 2, 0),
				Vector3.new(chord, thick, band), color, mat or MAT_NEON, transp, false)
		end
	end

	local function latRing(P, R, lat, thick, n, color)
		local rad, y = R * math.cos(lat) * 1.004, R * math.sin(lat) * 1.004
		local chord = 2 * rad * math.tan(math.pi / n) * 1.05
		for i = 0, n - 1 do
			local a = 2 * math.pi * i / n
			put(P, nil, CFrame.new(math.cos(a) * rad, y, math.sin(a) * rad) * CFrame.Angles(0, -a - math.pi / 2, 0),
				Vector3.new(chord, thick, thick * 2.2), color, MAT_NEON, 0.1, false)
		end
	end

	local function spinner(P, g, rate, around)
		P.anims[#P.anims + 1] = function(t)
			g.CFrame = P.T * CFrame.Angles(around == "x" and t * rate or 0, around ~= "x" and t * rate or 0, 0)
		end
	end

	local function fib(n)
		local pts, ga = {}, math.pi * (3 - math.sqrt(5))
		for i = 0, n - 1 do
			local y = 1 - 2 * (i + 0.5) / n
			local r = math.sqrt(1 - y * y)
			pts[#pts + 1] = Vector3.new(math.cos(ga * i) * r, y, math.sin(ga * i) * r)
		end
		return pts
	end

	local function fbm(v, seed, f)
		local x, y, z = v.X * f + seed * 3.1, v.Y * f + seed * 1.7, v.Z * f - seed * 2.3
		return math.clamp(0.5 + math.noise(x, y, z) * 0.95 + math.noise(x * 2.1, y * 2.1, z * 2.1) * 0.45 + math.noise(x * 4.3, y * 4.3, z * 4.3) * 0.2, 0, 1)
	end

	local DENS = (function()
		local ok, q = pcall(function() return settings().Rendering.QualityLevel.Value end)
		if not ok or q == 0 then q = 10 end
		return q <= 3 and 0.4 or (q <= 6 and 0.75 or (q <= 9 and 1.1 or 1.5))
	end)()

	local function mosaic(P, g, R, n, k, thick, fn)
		n = math.floor(n * DENS)
		local s = math.sqrt(4 * math.pi * R * R / n) * (k or 1.5)
		local h = (thick or 0.035) * R
		for _, dir in ipairs(fib(n)) do
			local color, lift, mat, tr = fn(dir)
			if color then
				put(P, g, surf(dir, R - h / 2 + (lift or 0) * R, rng:NextNumber(0, 6.28)), Vector3.new(s, h, s * rng:NextNumber(0.85, 1.1)), color, mat or MAT_SMOOTH, tr or 0, true)
			end
		end
	end

	local function lerpN(cols, t)
		local n = #cols - 1
		local x = math.clamp(t, 0, 0.9999) * n
		local i = math.floor(x)
		return cols[i + 1]:Lerp(cols[i + 2], x - i)
	end

	Sp.FB = { terra = Color3.fromRGB(40, 100, 200), deserto = Color3.fromRGB(214, 150, 86), gelo = Color3.fromRGB(200, 232, 255), neon = Color3.fromRGB(60, 20, 100), lua = Color3.fromRGB(170, 170, 180) }
	Sp.body = function(P, R, key, mat, spin)
		if Sp.hasMesh then return texSphere(P, R, Sp.TEX[key], 0, mat, spin) end
		return sphere(P, nil, R, Sp.FB[key], mat)
	end

	local function buildEarth(center, tilt)
		local R = 950 * Sp.SCALE
		local P = newPlanet("RickEarth", center, tilt)
		Sp.body(P, R, "terra", MAT_SMOOTH, 0.004)
		if Sp.hasMesh then texSphere(P, R * 1.012, Sp.TEX.nuvens, 0.02, MAT_SMOOTH, 0.022) end
		sphere(P, nil, R * 1.045, Color3.fromRGB(110, 170, 255), MAT_NEON, 0.9)
		return P
	end

	local function buildMoon(center, tilt, def)
		local R = 300 * Sp.SCALE
		local P = newPlanet("RickMoon", center, tilt)
		local g = newGroup(P)
		if Sp.meshBase then
			mkTexPart(P, g, CFrame.new(), R, Sp.TEX.lua, 0, MAT_SMOOTH)
		else
			local mp = put(P, g, CFrame.new(), Vector3.new(2 * R, 2 * R, 2 * R), Sp.hasMesh and Color3.new(1, 1, 1) or Sp.FB.lua, MAT_SMOOTH, 0, true)
			if Sp.hasMesh then texMesh(mp, R, Sp.TEX.lua) end
		end
		local orb = def.orbit
		P.anims[#P.anims + 1] = function(t)
			local a = t * 2 * math.pi / orb.period
			local pos = Sp.SPACE + orb.center + Vector3.new(math.cos(a) * orb.r, math.sin(a * 0.7) * orb.r * 0.12, math.sin(a) * orb.r)
			g.CFrame = CFrame.new(pos) * CFrame.Angles(0, -a, 0)
		end
		return P
	end

	local function buildDesert(center, tilt)
		local R = 800 * Sp.SCALE
		local P = newPlanet("RickDesert", center, tilt)
		Sp.body(P, R, "deserto", MAT_SMOOTH, 0.004)
		sphere(P, nil, R * 1.04, Color3.fromRGB(255, 190, 120), MAT_NEON, 0.93)

		local d = (center - Sp.SPACE).Unit
		local rgt = d:Cross(Vector3.yAxis).Unit
		local upv = rgt:Cross(d)
		local function wcf(woff, rot) return P.T:Inverse() * (CFrame.new(center + woff) * (rot or CFrame.new())) end
		local function cball(lcf, r, color, mat, transp)
			local p
			if Sp.meshBase then
				p = mkTexPart(P, nil, lcf, r, "", transp, mat)
			else
				p = put(P, nil, lcf, Vector3.new(2 * r, 2 * r, 2 * r), color, mat, transp, true)
				if Sp.hasMesh then texMesh(p, r, "") end
			end
			p.Color = color
			return p
		end
		local function sunAt(lcf, r, col, halo)
			cball(lcf, r, col, MAT_NEON, 0)
			for i = 1, 3 do cball(lcf, r * (1.3 + i * 0.45), halo, MAT_NEON, 0.9 + i * 0.03) end
		end

		local mRad, mOrb = R * 0.2, R * 2.3
		local dMoon = Sp.texBall(P.model, P.T, mRad, Sp.TEX.lua, 0, MAT_SMOOTH)
		if dMoon then
			P.list[#P.list + 1] = { part = dMoon, base = dMoon.Transparency }
			P.anims[#P.anims + 1] = function(t)
				local a = t * 0.04 + 0.8
				dMoon.CFrame = P.T * CFrame.Angles(0.22, 0, 0) * CFrame.new(math.cos(a) * mOrb, 0, math.sin(a) * mOrb) * CFrame.Angles(0, t * 0.012, 0)
			end
		else
			cball(CFrame.Angles(0.22, 0, 0) * CFrame.new(mOrb, 0, 0), mRad, Color3.fromRGB(205, 196, 190), MAT_SMOOTH, 0)
		end
		return P
	end

	local function buildIce(center, tilt)
		local R = 700 * Sp.SCALE
		local P = newPlanet("RickIce", center, tilt)
		Sp.body(P, R, "gelo", MAT_SMOOTH, 0.004)
		sphere(P, nil, R * 1.04, Color3.fromRGB(170, 230, 255), MAT_NEON, 0.92)
		return P
	end

	local function buildNeon(center, tilt)
		local R = 750 * Sp.SCALE
		local P = newPlanet("RickNeon", center, tilt)
		Sp.body(P, R, "neon", MAT_SMOOTH, 0.004)
		if Sp.hasMesh then

			texSphere(P, R * 1.006, Sp.TEX.neon, 0.5, MAT_SMOOTH, -0.014)
			local atm = texSphere(P, R * 1.035, "", 0.9, MAT_SMOOTH, nil)
			atm.Color = Color3.fromRGB(140, 90, 255)
		end
		local k = R / 480
		local tl = CFrame.Angles(math.rad(22), 0, math.rad(8))

		local function ringSeg(radius, band, thick, n, color, transp, dashEvery, spd)
			local g = newGroup(P)
			g.CFrame = P.T * tl
			local chord = 2 * radius * math.tan(math.pi / n) * 0.92
			for i = 0, n - 1 do
				if i % dashEvery ~= 0 then
					local a = 2 * math.pi * i / n
					put(P, g, CFrame.new(math.cos(a) * radius, 0, math.sin(a) * radius) * CFrame.Angles(0, -a - math.pi / 2, 0),
						Vector3.new(chord, thick, band), color, MAT_NEON, transp, false)
				end
			end
			P.anims[#P.anims + 1] = function(t) g.CFrame = P.T * tl * CFrame.Angles(0, t * spd, 0) end
		end
		ringSeg(1100 * k, 45 * k, 4 * k, 44, Color3.fromRGB(0, 255, 240), 0.2, 3, 0.05)
		ringSeg(980 * k, 28 * k, 3 * k, 44, Color3.fromRGB(255, 0, 200), 0.25, 4, -0.08)
		ringSeg(1230 * k, 14 * k, 2 * k, 48, Color3.fromRGB(160, 120, 255), 0.5, 2, 0.03)

		local function moonN(orbitR, mr, color, spd, ph, inc)
			local g = newGroup(P)
			sphere(P, g, mr, color, MAT_NEON)
			P.anims[#P.anims + 1] = function(t)
				g.CFrame = P.T * CFrame.Angles(inc, 0, 0) * CFrame.Angles(0, t * spd + ph, 0) * CFrame.new(orbitR, 0, 0)
			end
		end
		moonN(R * 2.75, R * 0.04, Color3.fromRGB(255, 0, 200), 0.03, 0, 0.35)
		moonN(R * 3.1, R * 0.028, Color3.fromRGB(0, 255, 240), 0.05, 2, -0.25)
		return P
	end

	local DEFS = {
		{ build = buildEarth,  off = Vector3.new(0, 0, 0),           tilt = CFrame.Angles(math.rad(23), 0, 0), earth = true, R = 950 * Sp.SCALE, name = "Terra" },
		{ build = buildMoon,   off = Vector3.new(9500, 0, 0),        tilt = CFrame.new(), orbit = { center = Vector3.zero, r = 9500, period = 360 } },
		{ build = buildDesert, off = Vector3.new(-24000, 3000, -14000), tilt = CFrame.Angles(math.rad(12), 0, math.rad(6)),  dim = "desert", R = 800 * Sp.SCALE, name = "K-22 Deserto" },
		{ build = buildIce,    off = Vector3.new(21000, 6000, -27000), tilt = CFrame.Angles(math.rad(-18), 0, 0),         dim = "ice",    R = 700 * Sp.SCALE, name = "G-7 Gelo" },
		{ build = buildNeon,   off = Vector3.new(6000, -4500, 30000), tilt = CFrame.Angles(0, 0, math.rad(10)),           dim = "neon",   R = 750 * Sp.SCALE, name = "C-35K Neon" },
	}

	local function ensurePlanets()
		if Sp.folder then return end
		local f = Instance.new("Folder")
		f.Name = "RickSpace"
		Sp.planets = {}
		for _, def in ipairs(DEFS) do
			local ok, P = pcall(def.build, Sp.SPACE + def.off, def.tilt, def)
			local root, list = P, nil
			if ok and P then
				root, list = P.model, P.list
				root.Parent = f
				Sp.planets[#Sp.planets + 1] = { root = root, list = list, def = def, P = P }
			else
				warn("[Rick] planeta falhou:", root)
			end
		end
		Sp.folder = f
	end

	local function fade(show)
		if not Sp.planets then return end
		for _, pl in ipairs(Sp.planets) do
			for _, e in ipairs(pl.list) do
				if e.part.Parent then
					TweenService:Create(e.part, TweenInfo.new(show and 2.2 or 1.2), { Transparency = show and e.base or 1 }):Play()
					local di = Sp.discImgs and Sp.discImgs[e.part]
					if di then
						for _, im in ipairs(di.imgs) do
							TweenService:Create(im, TweenInfo.new(show and 2.2 or 1.2), { ImageTransparency = show and di.base or 1 }):Play()
						end
					end
				end
			end
		end
	end

	local function showPlanets(camera)
		if Sp.visible then return end
		ensurePlanets()
		if not Sp.folder then return end
		Sp.visible = true
		Sp.shownAt = os.clock()
		Sp.hideToken = nil
		for _, pl in ipairs(Sp.planets) do
			for _, e in ipairs(pl.list) do
				e.part.Transparency = Sp.instant and e.base or 1
				local di = Sp.discImgs and Sp.discImgs[e.part]
				if di then for _, im in ipairs(di.imgs) do im.ImageTransparency = Sp.instant and di.base or 1 end end
			end
		end
		Sp.folder.Parent = workspace
		if Sp.instant then Sp.instant = false else fade(true) end
	end

	local function hidePlanets(instant)
		if not Sp.visible then return end
		Sp.visible = false
		if instant then
			if Sp.folder then Sp.folder.Parent = nil end
			return
		end
		fade(false)
		local token = {}
		Sp.hideToken = token
		task.delay(1.4, function()
			if Sp.hideToken == token and not Sp.visible and Sp.folder then Sp.folder.Parent = nil end
		end)
	end

	local function saveLighting()
		local L = Lighting
		local a = L:FindFirstChildOfClass("Atmosphere")
		Sp.saved = {
			Ambient = L.Ambient, OutdoorAmbient = L.OutdoorAmbient, FogEnd = L.FogEnd, FogStart = L.FogStart,
			atmo = a, aD = a and a.Density, aH = a and a.Haze, aG = a and a.Glare, skies = {},
		}
		Sp.saved.ct, Sp.saved.br = L.ClockTime, L.Brightness
		local cl = workspace.Terrain:FindFirstChildOfClass("Clouds")
		if cl then Sp.saved.clouds, Sp.saved.cE = cl, cl.Enabled end
		for _, c in ipairs(L:GetChildren()) do
			if c:IsA("Sky") then Sp.saved.skies[#Sp.saved.skies + 1] = c end
		end
		Sp.lastK = -1
	end

	local function setSpaceSky(on)
		if on == (Sp.spaceSky ~= nil) then return end
		if on then
			for _, s in ipairs(Sp.saved.skies) do s.Parent = nil end
			local at = Sp.saved.atmo
			if at and at.Parent then at.Parent = nil end
			local s = Instance.new("Sky")
			s.Name = "RickSpaceSky"
			for _, f in ipairs({ "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }) do s[f] = "rbxassetid://118061545763280" end
			s.StarCount = 5000
			s.CelestialBodiesShown = false
			s.Parent = Lighting
			Sp.spaceSky = s
			local a = Instance.new("Atmosphere")
			a.Name = "RickSpaceAtmo"
			a.Density, a.Offset, a.Glare, a.Haze = 0.02, 1, 0, 0
			a.Color, a.Decay = Color3.new(0, 0, 0), Color3.new(0, 0, 0)
			a.Parent = Lighting
			Sp.spaceAtmo = a
			Lighting.ClockTime, Lighting.Brightness = 16, 3
		else
			if Sp.spaceSky then Sp.spaceSky:Destroy() end
			if Sp.spaceAtmo then Sp.spaceAtmo:Destroy() end
			Sp.spaceSky, Sp.spaceAtmo = nil, nil
			local at = Sp.saved and Sp.saved.atmo
			if at then at.Parent = Lighting end
			if Sp.saved and Sp.saved.ct then Lighting.ClockTime, Lighting.Brightness = Sp.saved.ct, Sp.saved.br end
			for _, s in ipairs(Sp.saved.skies) do s.Parent = Lighting end
		end
	end

	local function restoreLighting()
		local sv = Sp.saved
		if not sv then return end
		setSpaceSky(false)
		if sv.clouds and sv.clouds.Parent then sv.clouds.Enabled = sv.cE end
		Lighting.Ambient, Lighting.OutdoorAmbient = sv.Ambient, sv.OutdoorAmbient
		Lighting.FogEnd, Lighting.FogStart = sv.FogEnd, sv.FogStart
		if sv.atmo and sv.atmo.Parent then
			sv.atmo.Density, sv.atmo.Haze, sv.atmo.Glare = sv.aD, sv.aH, sv.aG
		end
		Sp.saved = nil
	end

	local function applyLighting(k)
		local sv = Sp.saved
		if math.abs(k - (Sp.lastK or -1)) < 0.002 then return end
		Sp.lastK = k
		Lighting.Ambient = sv.Ambient:Lerp(Color3.fromRGB(45, 50, 80), k)
		Lighting.OutdoorAmbient = sv.OutdoorAmbient:Lerp(Color3.fromRGB(55, 60, 95), k)
		Lighting.FogEnd = sv.FogEnd + (1e6 - sv.FogEnd) * k
		Lighting.FogStart = sv.FogStart * (1 - k)
		if sv.atmo and sv.atmo.Parent then
			sv.atmo.Density = sv.aD * (1 - k)
			sv.atmo.Haze = sv.aH * (1 - k)
			sv.atmo.Glare = sv.aG * (1 - k)
		end
		if sv.clouds and sv.clouds.Parent then sv.clouds.Enabled = sv.cE and k < 0.2 end
		if Sp.inSpace and k >= 0.3 then setSpaceSky(true) elseif not Sp.inSpace then setSpaceSky(false) end
	end

	local Players = game:GetService("Players")

	local function whiteFlash(color, onPeak)
		local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		local g, f
		if pg then
			g = Instance.new("ScreenGui")
			g.Name, g.IgnoreGuiInset, g.ResetOnSpawn, g.DisplayOrder = "RickWarp", true, false, 1000
			f = Instance.new("Frame")
			f.Size, f.BorderSizePixel, f.BackgroundColor3, f.BackgroundTransparency = UDim2.fromScale(1, 1), 0, color, 1
			f.Parent = g
			g.Parent = pg
			local t1 = TweenService:Create(f, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0 })
			t1:Play()
			t1.Completed:Wait()
		end
		pcall(onPeak)
		task.wait(0.3)
		if f then
			local t2 = TweenService:Create(f, TweenInfo.new(1.2), { BackgroundTransparency = 1 })
			t2:Play()
			t2.Completed:Wait()
			g:Destroy()
		end
	end

	local function resetSpaceNow()
		Sp.k = 0
		if Sp.saved then restoreLighting() end
		hidePlanets(true)
	end

	local SPACE = Sp.SPACE
	local function inSpaceZone(S) return S and S.pos and S.pos.Y > 30000 end

	local function groundHome()
		local a = Sp.anchor or Vector3.zero
		local ay = Sp.anchorY or 50
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		local ch = Players.LocalPlayer and Players.LocalPlayer.Character
		rp.FilterDescendantsInstances = ch and { ch } or {}
		local hit = workspace:Raycast(Vector3.new(a.X, ay + 3, a.Z), Vector3.new(0, -6000, 0), rp)
		return CFrame.new(hit and (hit.Position + Vector3.new(0, 5, 0)) or Vector3.new(a.X, 10, a.Z))
	end

	local function findDim(id)
		local Dm = State.Dim
		if not Dm then return end
		for _, d in ipairs(Dm.list) do
			if d.id == id then return d end
		end
	end

	local function warp(color, onPeak)
		if Sp.warping then return end
		Sp.warping = true
		task.spawn(function()
			pcall(whiteFlash, color, onPeak)
			Sp.warping = false
		end)
	end

	local function toSpace(S)
		warp(Color3.new(1, 1, 1), function()
			Sp.noEnter = os.clock() + 6
			Sp.forceFull = true
			S.pos = SPACE + Vector3.new(0, 0, -(950 * Sp.SCALE + 2600))
			S.vel = Vector3.new(0, 0, 60)
			S.yaw = math.pi
		end)
	end

	local function toWorld(S)
		warp(Color3.new(1, 1, 1), function()
			local a = Sp.anchor or Vector3.zero
			Sp.noWarp = os.clock() + 10
			S.pos = Vector3.new(a.X, (Sp.anchorY or 700) + 300, a.Z)
			S.vel = Vector3.new(0, -80, 0)
		end)
	end

	local function enterPlanet(S, def)
		local Dm, dd = State.Dim, findDim(def.dim)
		if not dd or Sp.warping then return end
		local building = true
		task.spawn(function() pcall(Dm.ensure, dd); building = false end)
		warp(Color3.new(1, 1, 1), function()
			while building do task.wait() end
			Dm.home = groundHome()
			resetSpaceNow()
			Sp.hold = os.clock() + 2.2
			S.pos = Dm.arrivalCF(dd).Position + Vector3.new(0, 120, 0)
			S.vel = Vector3.zero
		end)
	end

	local function leaveDimension(S, dd)
		warp(Color3.new(1, 1, 1), function()
			for _, d in ipairs(DEFS) do
				if d.dim == dd.id then
					local away = (-d.off).Unit
					Sp.k = 0
					Sp.forceFull = true
					Sp.hold = os.clock() + 1.5
					Sp.noEnter = os.clock() + 6
					S.pos = SPACE + d.off + away * (d.R * 1.15 + 2600)
					S.vel = away * 120
					break
				end
			end
		end)
	end

	function Sp.step(S, dt, C, camera)
		local Dm = State.Dim
		local cur = Dm and Dm.current
		if os.clock() < (Sp.hold or 0) then return end
		if cur then
			if Sp.saved or Sp.k > 0 or Sp.visible then resetSpaceNow() end
			if S and S.pos and S.state == "flying" and not Sp.warping and S.pos.Y > cur.origin.Y + 450 then leaveDimension(S, cur) end
			return
		end
		local a0, a1 = C.ShipSpaceStartAlt or 700, C.ShipSpaceFullAlt or 1500
		local inSpace = inSpaceZone(S)
		if Sp.forceFull and inSpace then Sp.forceFull, Sp.k, Sp.instant, Sp.shownAt = false, 1, true, os.clock() - 5 end
		local target = 0
		if inSpace then
			target = 1
		elseif S and S.pos then
			target = math.clamp((S.pos.Y - a0) / math.max(a1 - a0, 1), 0, 1)
			if target == 0 then Sp.anchor, Sp.anchorY = Vector3.new(S.pos.X, 0, S.pos.Z), S.pos.Y end
			if S.pos.Y > a1 + 60 and S.state == "flying" and not Sp.warping and os.clock() > (Sp.noWarp or 0) then toSpace(S) end
		end
		Sp.k = Sp.k + (target - Sp.k) * (1 - math.exp(-2.5 * dt))
		if Sp.k < 0.004 and target == 0 then
			Sp.k = 0
			if Sp.saved then restoreLighting() end
			hidePlanets(false)
			return
		end
		if not Sp.anchor and S and S.pos then Sp.anchor, Sp.anchorY = Vector3.new(S.pos.X, 0, S.pos.Z), 50 end
		if not Sp.saved then saveLighting() end
		if Sp.inSpace ~= inSpace then Sp.inSpace = inSpace; Sp.lastK = -1 end
		applyLighting(Sp.k)
		if inSpace and Sp.k >= 0.65 then showPlanets(camera) elseif not inSpace or Sp.k < 0.5 then hidePlanets(false) end
		if Sp.visible and Sp.planets then
			local t = os.clock()
			local ready = t - (Sp.shownAt or 0) > 2.6
			local canEnter = inSpace and S.state == "flying" and not Sp.warping and t > (Sp.noEnter or 0) and Sp.k > 0.9
			for _, pl in ipairs(Sp.planets) do
				local d = pl.def
				local c = SPACE + d.off
				if pl.P then for _, fn in ipairs(pl.P.anims) do fn(t, ready) end end
				if canEnter and (d.dim or d.earth) and (S.pos - c).Magnitude < d.R * 0.95 then
					canEnter = false
					if d.earth then toWorld(S) else enterPlanet(S, d) end
				end
			end
		end
	end

	function State.spaceStop()
		pcall(function() game:GetService("RunService"):UnbindFromRenderStep("RickSpacePlanets") end)
		Sp.k = 0
		restoreLighting()
		hidePlanets(true)
		if Sp.folder then Sp.folder:Destroy() end
		Sp.folder, Sp.planets = nil, nil
	end
end

State.buildShipSystem = function(ctx)
	local Z = ctx.Z
	local character, humanoid, rootPart, camera = ctx.character, ctx.humanoid, ctx.rootPart, ctx.camera
	local ContextActionService = game:GetService("ContextActionService")
	local C = Config

	local SCALE = C.ShipScale or 1
	local SPEED = C.ShipSpeed or 95
	local TURBO = C.ShipTurbo or 2.6
	local ACCEL = C.ShipAccel or 2.6
	local TURN = C.ShipTurnRate or 5
	local PORTAL_SIZE = C.ShipPortalSize or Vector3.new(70, 70, 0.2)
	local PORTAL_H = C.ShipPortalHeight or 130
	local LAND_DIST = C.ShipLandDistance or 26
	local DESCENT = C.ShipDescentTime or 4.2
	local SEAT_H = C.ShipSeatHeight or 1.5
	local BOARD_R = (C.ShipBoardRadius or 8) * SCALE
	local AUTO_BOARD = C.ShipAutoBoard ~= false
	local LEG_H = 5.0 * SCALE
	local CANOPY_OPEN = 1
	local CANOPY_ANGLE = math.rad(105)
	local CANOPY_HINGE = Vector3.new(0, 3.8, 6.85) * SCALE
	local GEAR_TRAVEL = 3.0 * SCALE
	local SEAT_REL = CFrame.new(-2.3 * SCALE, (4.5 - 1.3) * SCALE + SEAT_H, 0.9 * SCALE)
	local STEP_ID = "RickShipStep"
	local GROUND_SPEED = C.ShipGroundSpeed or 45
	local GROUND_TURBO = C.ShipGroundTurbo or 2
	local GROUND_ACCEL = 3.2
	local STEP_UP = 3.5 * SCALE

	local SUSP_BUMP = 1.8 * SCALE
	local SUSP_DROOP = 1.3 * SCALE
	local SUSP_K = 145
	local SUSP_ZETA = 0.27
	local SUSP_LOAD = 0.9 * SCALE

	local api = {}
	local ship = nil
	local busy = false
	local destroyed = false
	local lastBoard = 0
	local skyPortals = {}
	local jobs = {}
	local held = { up = false, down = false, turbo = false, brake = false, brakeUi = false }
	local controls = nil
	local savedCollide = {}
	local savedJump = nil
	local savedAutoRotate = nil
	local baseFov = nil
	local savedZoom = nil
	local sinkBound = false

	State.shipLv = State.buildShipLevers({
		C = C, ctx = ctx, held = held, api = api, SCALE = SCALE, CANOPY_OPEN = CANOPY_OPEN,
		getShip = function() return ship end,
	})

	local pad, btnUp, btnDown, btnTurbo, boardBtn, infoLbl, toast
	do
	local hud = ctx.newGui("RickShipHud", 26)
	local ACC = C.PortalColor
	local TURBO_COL = Color3.fromRGB(255, 222, 70)
	local SLIME = Color3.fromRGB(128, 255, 86)
	local BLACK = Color3.fromRGB(8, 10, 12)
	local INK = Color3.fromRGB(16, 20, 30)
	local WHITE = Color3.new(1, 1, 1)
	local RED = Color3.fromRGB(255, 72, 72)
	local FONT = Enum.Font.FredokaOne
	local isTouchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	local function mk(class, props, parent)
		local o = Instance.new(class)
		for k, v in pairs(props) do o[k] = v end
		if parent then o.Parent = parent end
		return o
	end
	local function tw(o, t, props, style, dir)
		local tween = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
		tween:Play()
		return tween
	end
	local function frame(parent, x, y, w, h, col, tr, r)
		local f = mk("Frame", {
			BorderSizePixel = 0, BackgroundColor3 = col or WHITE, BackgroundTransparency = tr or 0,
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		}, parent)
		if r then mk("UICorner", { CornerRadius = UDim.new(0, r) }, f) end
		return f
	end
	local function disc(parent, cx, cy, d, col, tr)
		local f = mk("Frame", {
			BorderSizePixel = 0, BackgroundColor3 = col or WHITE, BackgroundTransparency = tr or 0,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(d, d),
		}, parent)
		mk("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
		return f
	end
	local function ink(o, th, col, tr)
		return mk("UIStroke", {
			Color = col or BLACK, Thickness = th, Transparency = tr or 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, o)
	end
	local function grad(o, c0, c1, rot)
		return mk("UIGradient", { Color = ColorSequence.new(c0, c1), Rotation = rot or 90 }, o)
	end
	local function text(parent, str, size, col, x, y, w, h, xa)
		return mk("TextLabel", {
			BackgroundTransparency = 1, Text = str, TextSize = size, TextColor3 = col or WHITE, Font = FONT,
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
			TextXAlignment = xa or Enum.TextXAlignment.Center, ZIndex = 6,
		}, parent)
	end

	local vpScales = {}
	local function vpFactor()
		local s = hud.AbsoluteSize
		if s.X <= 0 or s.Y <= 0 then return 1 end
		return math.clamp(math.min(s.X / 820, s.Y / 440), 0.62, 1.15)
	end
	local function addVP(f)
		UIAnim.getScale(f)
		local s = mk("UIScale", { Name = "VP", Scale = vpFactor() }, f)
		vpScales[#vpScales + 1] = s
	end

	local function ibar(parent, cx, cy, w, h, rot, col)
		local f = mk("Frame", {
			BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = col or INK,
			Position = UDim2.fromScale(cx / 28, cy / 28), Size = UDim2.fromScale(w / 28, h / 28), Rotation = rot or 0,
		}, parent)
		mk("UICorner", { CornerRadius = UDim.new(0.3, 0) }, f)
		return f
	end
	local function idot(parent, cx, cy, d, col)
		local f = mk("Frame", {
			BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = col or INK,
			Position = UDim2.fromScale(cx / 28, cy / 28), Size = UDim2.fromScale(d / 28, d / 28),
		}, parent)
		mk("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
		return f
	end
	local function subIcon(parent)
		return mk("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1) }, parent)
	end
	local function drawArrow(f, col)
		ibar(f, 14, 17, 5.5, 14, 0, col)
		ibar(f, 10.4, 8.8, 5.5, 11, 45, col)
		ibar(f, 17.6, 8.8, 5.5, 11, -45, col)
	end
	local function drawBolt(f, col)
		ibar(f, 15.5, 8.5, 5.5, 14.5, 33, col)
		ibar(f, 14, 14.2, 12, 4.6, 0, col)
		ibar(f, 11.5, 19.5, 5.5, 13, 27, col)
	end
	local function drawSaucer(f, col, hi)
		idot(f, 14, 11, 11, col)
		idot(f, 12, 9.5, 3.2, hi)
		local body = ibar(f, 14, 16.5, 26, 9, 0, col)
		body:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
		idot(f, 7, 17, 2.6, hi)
		idot(f, 14, 18.2, 2.6, hi)
		idot(f, 21, 17, 2.6, hi)
		ibar(f, 9, 23, 3, 4, 20, col)
		ibar(f, 19, 23, 3, 4, -20, col)
	end
	local function drawWheel(f, col, hi)
		idot(f, 14, 14, 25, col)
		idot(f, 14, 14, 15, hi)
		ibar(f, 14, 14, 3, 15, 0, col)
		ibar(f, 14, 14, 3, 15, 90, col)
		ibar(f, 14, 14, 3, 15, 45, col)
		ibar(f, 14, 14, 3, 15, -45, col)
		idot(f, 14, 14, 6, col)
	end
	local function drawExit(f, col)
		local door = mk("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(9 / 28, 14 / 28), Size = UDim2.fromScale(13 / 28, 20 / 28) }, f)
		mk("UIStroke", { Color = col, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, door)
		mk("UICorner", { CornerRadius = UDim.new(0.2, 0) }, door)
		ibar(f, 17.5, 14, 11, 4, 0, col)
		ibar(f, 22.2, 11.2, 4, 8, -45, col)
		ibar(f, 22.2, 16.8, 4, 8, 45, col)
	end

	local dialRoot = mk("Frame", { Name = "ShipDial", BackgroundTransparency = 1, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.085, 0, 0.4, 0), Size = UDim2.fromOffset(340, 190),
		Visible = false }, hud)
	addVP(dialRoot)

	local dial = frame(dialRoot, 102, 20, 136, 136, WHITE, 1)
	dial.Name = "Dial"
	dial.ZIndex = 4
	local ticks = {}
	local N = 36
	local needleBox, speedNum, turboGlow
	do
		turboGlow = disc(dial, 68, 68, 160, TURBO_COL, 0.6)
		turboGlow.Visible = false
		TweenService:Create(turboGlow, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ BackgroundTransparency = 0.8 }):Play()
		disc(dial, 68, 75, 136, BLACK, 0.55)
		local rim = disc(dial, 68, 68, 136, WHITE)
		grad(rim, Color3.fromRGB(150, 164, 180), Color3.fromRGB(52, 60, 72), 90)
		ink(rim, 4)
		local bevel = disc(dial, 68, 68, 124, Color3.fromRGB(22, 26, 32))
		ink(bevel, 2)
		local face = disc(dial, 68, 68, 114, WHITE)
		grad(face, Color3.fromRGB(26, 62, 34), Color3.fromRGB(6, 16, 10), 90)
		ink(face, 2, ACC, 0.55)

		local sw = disc(dial, 68, 93, 52, WHITE, 0.4)
		local swg = mk("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, ACC), ColorSequenceKeypoint.new(0.3, Color3.fromRGB(10, 40, 16)),
				ColorSequenceKeypoint.new(0.6, ACC), ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 40, 16)),
			}), Rotation = 0 }, sw)
		ink(sw, 2, ACC, 0.35)
		TweenService:Create(swg, TweenInfo.new(2.4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Rotation = 360 }):Play()

		for k = 0, N do
			local ang = -120 + 240 * k / N
			local rad = math.rad(ang)
			local major = (k % 6 == 0)
			local len = major and 11 or 6
			local wd = major and 4 or 3
			local cr = 55 - len / 2
			local t = mk("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(26, 66, 34),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(68 + cr * math.sin(rad), 68 - cr * math.cos(rad)),
				Size = UDim2.fromOffset(wd, len), Rotation = ang }, dial)
			mk("UICorner", { CornerRadius = UDim.new(0, 1) }, t)
			ticks[k] = t
		end

		needleBox = mk("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(68, 68), Size = UDim2.fromOffset(10, 108), Rotation = -120, ZIndex = 5 }, dial)
		local blade = frame(needleBox, 2.5, 8, 5, 62, RED, 0, 2)
		ink(blade, 1.5)
		local hub = disc(dial, 68, 68, 17, TURBO_COL)
		hub.ZIndex = 6
		ink(hub, 2.5)
		local hubDot = disc(dial, 68, 68, 5, INK)
		hubDot.ZIndex = 7

		speedNum = text(dial, "0", 26, WHITE, 28, 77, 80, 28)
		speedNum.TextStrokeTransparency = 0
		speedNum.TextStrokeColor3 = BLACK
		local unit = text(dial, "studs/s", 9, ACC, 28, 103, 80, 12)
		unit.Font = Enum.Font.GothamBold

		local shine = frame(dial, 20, 14, 70, 26, WHITE, 0.88, 13)
		shine.Rotation = -28
		shine.ZIndex = 8
	end

	local altCap = frame(hud, 12, 48, 84, 30, WHITE, 0, 15)
	altCap.Name = "AltCap"
	altCap.ZIndex = 2
	altCap.Visible = false
	addVP(altCap)
	grad(altCap, Color3.fromRGB(30, 58, 38), Color3.fromRGB(10, 22, 14), 90)
	ink(altCap, 3)
	local altChip = frame(altCap, 7, 8, 28, 14, ACC, 0, 7)
	text(altChip, "ALT", 10, INK, 0, 0, 28, 14)
	local altNum = text(altCap, "0", 17, WHITE, 36, 0, 40, 30)

	local modeCap = frame(hud, 0, 48, 92, 30, WHITE, 0, 15)
	modeCap.Name = "ModeCap"
	modeCap.AnchorPoint = Vector2.new(1, 0)
	modeCap.Position = UDim2.new(1, -12, 0, 48)
	modeCap.ZIndex = 2
	modeCap.Visible = false
	addVP(modeCap)
	grad(modeCap, Color3.fromRGB(30, 58, 38), Color3.fromRGB(10, 22, 14), 90)
	ink(modeCap, 3)
	local miniHolder = frame(modeCap, 28, 4, 22, 22, WHITE, 1)
	local miniSaucer = subIcon(miniHolder)
	drawSaucer(miniSaucer, ACC, Color3.fromRGB(10, 40, 16))
	local miniWheel = subIcon(miniHolder)
	drawWheel(miniWheel, ACC, Color3.fromRGB(10, 40, 16))
	miniWheel.Visible = false
	miniHolder.Position = UDim2.fromOffset(8, 4)
	local modeName = text(modeCap, "VOO", 15, WHITE, 34, 0, 54, 30)

	local sticker = frame(dialRoot, 118, 152, 104, 30, TURBO_COL, 0, 10)
	sticker.ZIndex = 9
	sticker.Rotation = -3
	sticker.Visible = false
	ink(sticker, 3)
	text(sticker, "TURBO!", 18, INK, 0, 0, 104, 30)

	local tickCache = -999
	local function paintTicks(a, fly, turbo)
		local level = (a > 0.015) and math.floor(a * N + 0.5) or -1
		local key = level * 4 + (fly and 2 or 0) + (turbo and 1 or 0)
		if key == tickCache then return end
		tickCache = key
		local thr = fly and (1 / TURBO) or (1 / GROUND_TURBO)
		for k = 0, N do
			local zone = (k / N) > thr
			local col
			if k <= level then
				col = zone and TURBO_COL or ACC
			else
				col = zone and Color3.fromRGB(86, 70, 22) or Color3.fromRGB(26, 66, 34)
			end
			ticks[k].BackgroundColor3 = col
		end
	end

	infoLbl = mk("TextLabel", { Name = "Info", BackgroundTransparency = 1, TextTransparency = 1,
		Size = UDim2.fromOffset(0, 0), Text = "", Visible = false }, hud)
	local function updateDial()
		local t = infoLbl.Text
		local mode = t:match("^(%a+)") or "VOO"
		local spd = tonumber(t:match("VEL%s+(%-?%d+)")) or 0
		local alt = tonumber(t:match("ALT%s+(%-?%d+)"))
		local turbo = t:find("TURBO", 1, true) ~= nil
		local fly = mode == "VOO"
		local top = fly and (SPEED * TURBO) or (GROUND_SPEED * GROUND_TURBO)
		local a = math.clamp(spd / math.max(top, 1), 0, 1)
		paintTicks(a, fly, turbo)
		tw(needleBox, 0.15, { Rotation = -120 + 240 * a })
		speedNum.Text = tostring(spd)
		speedNum.TextColor3 = turbo and TURBO_COL or WHITE
		altCap.Visible = alt ~= nil
		if alt then altNum.Text = tostring(alt) end
		modeName.Text = mode
		miniSaucer.Visible = fly
		miniWheel.Visible = not fly
		sticker.Visible = turbo
		turboGlow.Visible = turbo
	end
	infoLbl:GetPropertyChangedSignal("Text"):Connect(updateDial)
	paintTicks(0, true, false)

	pad = mk("Frame", { Name = "FlightPad", BackgroundTransparency = 1, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(70, 0),
		AutomaticSize = Enum.AutomaticSize.Y, Visible = false }, hud)
	addVP(pad)
	mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center }, pad)

	local function makeBtn(i, label, hint, col, draw, onText)
		local b = mk("TextButton", { Name = "Btn" .. i, LayoutOrder = i, Size = UDim2.fromOffset(60, 66),
			BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Text = label, TextTransparency = 1,
			TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 5 }, pad)
		local sc = mk("UIScale", { Name = "BtnScale" }, b)
		local glow = frame(b, -6, -6, 72, 78, col, 1, 20)
		glow.ZIndex = 1
		local lip = frame(b, 0, 6, 60, 60, col:Lerp(BLACK, 0.5), 0, 15)
		lip.ZIndex = 2
		ink(lip, 3)
		local face = frame(b, 0, 0, 60, 60, col, 0, 15)
		face.ZIndex = 3
		ink(face, 3)
		grad(face, WHITE, Color3.fromRGB(205, 205, 205), 90)
		frame(face, 8, 5, 44, 7, WHITE, 0.55, 4)
		local holder = frame(face, 15, 9, 30, 30, WHITE, 1)
		draw(holder)
		local lb = text(face, label, 12, INK, 0, 41, 60, 16)
		if not isTouchOnly then
			local hb = mk("TextLabel", { BackgroundColor3 = WHITE, BorderSizePixel = 0, Text = hint, TextSize = 8,
				TextColor3 = INK, Font = Enum.Font.GothamBold, AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 12), Position = UDim2.fromOffset(-4, -4), ZIndex = 8 }, face)
			mk("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }, hb)
			mk("UICorner", { CornerRadius = UDim.new(0, 4) }, hb)
			ink(hb, 1.5)
		end
		b:GetPropertyChangedSignal("Text"):Connect(function()
			lb.Text = b.Text
			if onText then onText(b.Text) end
		end)

		local on, hover, down = false, false, false
		local function render()
			local lift = (on or down) and 4 or 0
			tw(face, 0.07, { Position = UDim2.fromOffset(0, lift) })
			tw(face, 0.12, { BackgroundColor3 = on and col:Lerp(WHITE, 0.45) or col })
			tw(glow, 0.15, { BackgroundTransparency = on and 0.55 or 1 })
		end
		b.MouseEnter:Connect(function()
			hover = true
			tw(sc, 0.14, { Scale = 1.06 })
		end)
		b.MouseLeave:Connect(function()
			hover = false
			down = false
			tw(sc, 0.14, { Scale = 1 })
			render()
		end)
		b.MouseButton1Down:Connect(function()
			down = true
			tw(sc, 0.07, { Scale = 0.94 })
			render()
		end)
		b.MouseButton1Up:Connect(function()
			down = false
			tw(sc, 0.25, { Scale = hover and 1.06 or 1 }, Enum.EasingStyle.Back)
			render()
		end)
		return b, function(v)
			on = v
			render()
		end
	end

	local btnCanopy = makeBtn(0, "VIDRO", "G", Color3.fromRGB(150, 230, 200), function(f)
		local ic = subIcon(f)
		idot(ic, 14, 14, 24, INK)
		idot(ic, 14, 14, 18, Color3.fromRGB(190, 255, 230))
		idot(ic, 14, 20, 12, Color3.fromRGB(190, 255, 230))
	end)
	btnCanopy.Name = "BtnCanopy"
	api.canopyBtn = btnCanopy
	btnCanopy.Text = "ABRIR"
	btnCanopy.MouseButton1Click:Connect(function() api.toggleCanopy() end)
	local btnView = makeBtn(1, "VISTA", "V", Color3.fromRGB(96, 196, 255), function(f)
		local ic = subIcon(f)
		idot(ic, 14, 14, 24, INK)
		idot(ic, 14, 14, 17, WHITE)
		idot(ic, 14, 14, 9, INK)
	end)
	btnView.MouseButton1Click:Connect(function() api.toggleCloseView() end)
	local setUpOn, setDownOn, setTurboOn
	btnUp, setUpOn = makeBtn(2, "SOBE", "ESPAÇO", Color3.fromRGB(92, 255, 92), function(f)
		drawArrow(subIcon(f), INK)
	end)
	btnDown, setDownOn = makeBtn(3, "DESCE", "CTRL", Color3.fromRGB(255, 160, 60), function(f)
		local s = subIcon(f)
		s.Rotation = 180
		drawArrow(s, INK)
	end)
	btnTurbo, setTurboOn = makeBtn(4, "TURBO", "SHIFT", TURBO_COL, function(f)
		drawBolt(subIcon(f), INK)
	end)
	local btnExit = makeBtn(5, "SAIR", "F", Color3.fromRGB(255, 92, 100), function(f)
		drawExit(subIcon(f), INK)
	end)

	local function isPress(i)
		return i.UserInputType == Enum.UserInputType.MouseButton1
			or i.UserInputType == Enum.UserInputType.Touch
	end
	local function holdBtn(b, key, setOn)
		b.InputBegan:Connect(function(i)
			if isPress(i) then held[key] = true; setOn(true) end
		end)
		b.InputEnded:Connect(function(i)
			if isPress(i) then held[key] = false; setOn(false) end
		end)
	end
	holdBtn(btnUp, "up", setUpOn)
	holdBtn(btnDown, "down", setDownOn)
	btnTurbo.MouseButton1Click:Connect(function()
		held.turbo = not held.turbo
		btnTurbo.TextColor3 = held.turbo and ACC or Theme.Text
	end)

	btnTurbo:GetPropertyChangedSignal("TextColor3"):Connect(function()
		setTurboOn(btnTurbo.TextColor3 == ACC)
	end)
	btnExit.MouseButton1Click:Connect(function() api.exit() end)

	boardBtn = mk("TextButton", { Name = "BoardBtn", AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -118), Size = UDim2.fromOffset(262, 70), BackgroundTransparency = 1,
		BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 5, Visible = false }, hud)
	addVP(boardBtn)
	mk("UIScale", { Name = "Small", Scale = 0.7 }, boardBtn)
	do
		local lip = frame(boardBtn, 0, 6, 262, 64, Color3.fromRGB(30, 120, 34), 0, 18)
		lip.ZIndex = 2
		ink(lip, 3.5)
		local face = frame(boardBtn, 0, 0, 262, 64, ACC, 0, 18)
		face.ZIndex = 3
		ink(face, 3.5)
		grad(face, WHITE, Color3.fromRGB(200, 214, 200), 90)
		frame(face, 14, 5, 234, 8, WHITE, 0.55, 4)
		local ic = frame(face, 12, 10, 44, 44, WHITE, 1)
		drawSaucer(subIcon(ic), INK, Color3.fromRGB(190, 255, 180))
		local t1 = text(face, "FECHAR VIDRO", 22, INK, 64, 9, 150, 28, Enum.TextXAlignment.Left)
		api.canopyLbl = t1
		local t2 = text(face, isTouchOnly and "toque para abrir/fechar" or "aperte G ou clique", 11,
			Color3.fromRGB(24, 84, 28), 64, 37, 150, 16, Enum.TextXAlignment.Left)
		t2.Font = Enum.Font.GothamBold
		local key = frame(face, 218, 16, 32, 32, WHITE, 0, 8)
		ink(key, 3)
		if isTouchOnly then
			local s = subIcon(key)
			s.Size = UDim2.fromScale(0.7, 0.7)
			s.Rotation = 0
			drawArrow(s, INK)
		else
			text(key, "G", 20, INK, 0, 0, 32, 32)
		end
		TweenService:Create(face, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = UDim2.fromOffset(0, -3) }):Play()
	end
	boardBtn.MouseButton1Click:Connect(function() api.toggleCanopy() end)

	do
		local okLv, errLv = pcall(State.shipLv.buildHud, {
			hud = hud, mk = mk, frame = frame, disc = disc, ink = ink, grad = grad, text = text, addVP = addVP,
			ACC = ACC, INK = INK, BLACK = BLACK, WHITE = WHITE, YELLOW = TURBO_COL, RED = RED, isTouchOnly = isTouchOnly,
		})
		if not okLv then warnRG("painel do cambio:", errLv) end
	end

	infoLbl:GetPropertyChangedSignal("Visible"):Connect(function()
		dialRoot.Visible = infoLbl.Visible
		local lv = State.shipLv
		if lv and lv.hudRoot then lv.hudRoot.Visible = infoLbl.Visible end
		modeCap.Visible = infoLbl.Visible
		if not infoLbl.Visible then altCap.Visible = false end
	end)
	hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local f = vpFactor()
		for _, s in ipairs(vpScales) do s.Scale = f end
	end)
	toast = function() end
	api.toast = toast
	end

	local function animate(dur, fn, style, dir)
		if destroyed or not Z.alive then return false end
		local job = {
			t0 = os.clock(), dur = math.max(dur, 0.01), fn = fn,
			style = style or Enum.EasingStyle.Quad,
			dir = dir or Enum.EasingDirection.InOut,
			th = coroutine.running(), ok = false,
		}
		jobs[#jobs + 1] = job
		coroutine.yield()
		return job.ok
	end

	local function flushJobs()
		local list = jobs
		jobs = {}
		for _, j in ipairs(list) do
			j.ok = false
			task.spawn(j.th)
		end
	end

	local function wrapAng(a)
		return (a + math.pi) % (math.pi * 2) - math.pi
	end

	local function skyCF(pos, rightHint)
		local r = Vector3.new(rightHint.X, 0, rightHint.Z)
		if r.Magnitude < 0.01 then r = Vector3.xAxis end
		r = r.Unit
		local vz = Vector3.yAxis
		return CFrame.fromMatrix(pos, r, vz:Cross(r), vz)
	end

	local shipRayParams = RaycastParams.new()
	shipRayParams.FilterType = Enum.RaycastFilterType.Exclude
	shipRayParams.IgnoreWater = true
	local shipRayIgnore = {}

	local function rebuildShipIgnore()
		table.clear(shipRayIgnore)
		if character then shipRayIgnore[#shipRayIgnore + 1] = character end
		if ship and ship.model then shipRayIgnore[#shipRayIgnore + 1] = ship.model end
		for _, m in ipairs(skyPortals) do shipRayIgnore[#shipRayIgnore + 1] = m end
		shipRayParams.FilterDescendantsInstances = shipRayIgnore
	end

	local function castDir(origin, vec)
		rebuildShipIgnore()

		for _ = 1, 8 do
			local result = workspace:Raycast(origin, vec, shipRayParams)
			if not result then return nil end
			local inst = result.Instance
			if inst and inst.ClassName ~= "Terrain" and inst:IsA("BasePart") and inst.Transparency >= 0.95 then
				shipRayIgnore[#shipRayIgnore + 1] = inst
				shipRayParams.FilterDescendantsInstances = shipRayIgnore
			else
				return result
			end
		end
		return nil
	end

	local function groundAt(pos, fromAbove)
		local above = math.min(fromAbove or 6, 30)
		local down = above + 120
		local res = castDir(pos + Vector3.new(0, above, 0), Vector3.new(0, -down, 0))
		if res then return res.Position, res.Normal end
		return nil
	end

	local skyInfo = setmetatable({}, { __mode = "k" })

	local function openSky(cf, size)
		local oldSize, oldGoo = C.PortalSize, C.GooDrips
		C.PortalSize = size or PORTAL_SIZE
		C.GooDrips = false
		local ok, model = pcall(ctx.createPortalModel, cf)
		if ok and model then pcall(ctx.openRipple, cf) end
		C.PortalSize = oldSize
		C.GooDrips = oldGoo
		if ok and model then
			skyPortals[#skyPortals + 1] = model
			skyInfo[model] = { model = model, size = size or PORTAL_SIZE, opened = os.clock() }
			return model
		end
		return nil
	end

	local function closeSky(model)
		if model then task.spawn(ctx.closePortal, model) end
	end

	local function wobbleSky(model, isExit)
		local P = model and skyInfo[model]
		if not P or not model.Parent or not ctx.wobblePortal then return end
		if C.Elastic == false then return end
		pcall(ctx.wobblePortal, P, isExit)
	end

	local function dustAt(pos)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(1, 1, 1)
		p.Position = pos + Vector3.new(0, 0.5, 0)
		p.Parent = workspace
		local em = Instance.new("ParticleEmitter")
		em.Texture = "rbxasset://textures/particles/smoke_main.dds"
		em.Color = ColorSequence.new(Color3.fromRGB(190, 190, 185))
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 14) })
		em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
		em.Lifetime = NumberRange.new(1.2, 2.2)
		em.Speed = NumberRange.new(18, 34)
		em.SpreadAngle = Vector2.new(88, 88)
		em.EmissionDirection = Enum.NormalId.Top
		em.Drag = 3
		em.Rate = 0
		em.Parent = p
		em:Emit(36)
		Debris:AddItem(p, 3)
	end

	local function buildShip()
		local model = Instance.new("Model")
		model.Name = "RickShip"

		local root = Instance.new("Part")
		root.Name = "Root"
		root.Anchored = true
		root.CanCollide = false
		root.CanQuery = false
		root.CanTouch = false
		root.Transparency = 1
		root.Size = Vector3.new(1, 1, 1)
		root.Parent = model

		local S = {
			model = model, root = root,
			parts = {}, gearParts = {}, swParts = {}, swCol = {}, swBase = {}, canopyParts = {}, thrParts = {}, emitters = {},
			shiftParts = {}, brakeParts = {},
			rdoorParts = {}, rarmParts = {},
			brakeNotch = 0,
			wheelHubs = {},
			cf = CFrame.new(), pos = Vector3.zero, vel = Vector3.zero,
			yaw = 0, pitch = 0, roll = 0, yawRate = 0,
			gear = 1, canopyAng = 0, state = "arriving", infoT = 0, shaking = false,
			mode = "ground", vy = 0, spinDist = 0,
			wheels = {}, suspDirty = false, landImpact = nil, prevHv = nil,
			leanP = 0, leanPV = 0, leanR = 0, leanRV = 0, latN = 0, lonN = 0,
			steer = 0, lastSteer = 0,
			trails = {}, turbo = false, tk = 0,
			lamps = {},
			suspAcc = 0,
		}

		local RZ = CFrame.Angles(0, math.rad(90), 0)
		local RY = CFrame.Angles(0, 0, math.rad(90))
		local function cylX(len, diam) return Vector3.new(len, diam, diam) end
		local METAL, PLASTIC, SMOOTH, NEON = Enum.Material.Metal, Enum.Material.Plastic, Enum.Material.SmoothPlastic, Enum.Material.Neon

		local function add(name, size, rel, color, material, transp, shape, tag)
			local p = Instance.new("Part")
			p.Name = name
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Size = size * SCALE
			p.CastShadow = size.Magnitude > 3
			p.Color = color
			p.Material = material or METAL
			p.Transparency = transp or 0
			if shape == "sphere" then
				local m = Instance.new("SpecialMesh")
				m.MeshType = Enum.MeshType.Sphere
				m.Parent = p
			elseif shape == "cyl" then
				p.Shape = Enum.PartType.Cylinder
			end
			local relS = CFrame.new(rel.Position * SCALE) * rel.Rotation
			local w = Instance.new("Weld")
			w.Part0 = root
			w.Part1 = p
			w.C0 = relS
			w.Parent = p
			p.Parent = model
			local e = { part = p, weld = w, rel = relS, tag = tag, baseT = p.Transparency }
			S.parts[#S.parts + 1] = e
			if tag == "gear" then S.gearParts[#S.gearParts + 1] = e
			elseif tag == "swheel" then S.swParts[#S.swParts + 1] = e
			elseif tag == "swcol" then S.swCol[#S.swCol + 1] = e
			elseif tag == "swbase" then S.swBase[#S.swBase + 1] = e
			elseif tag == "canopy" then S.canopyParts[#S.canopyParts + 1] = e
			elseif tag == "shift" then S.shiftParts[#S.shiftParts + 1] = e
			elseif tag == "brake" then S.brakeParts[#S.brakeParts + 1] = e
			elseif tag == "rdoor" then S.rdoorParts[#S.rdoorParts + 1] = e
			elseif tag == "rarm" then S.rarmParts[#S.rarmParts + 1] = e
			elseif tag == "thr" then S.thrParts[#S.thrParts + 1] = e end
			return e
		end

		local HULL = Color3.fromRGB(205, 210, 214)
		local PLATE = Color3.fromRGB(224, 228, 231)
		local SEAM = Color3.fromRGB(96, 104, 112)
		local FLANGE = Color3.fromRGB(150, 160, 170)
		local BELLY = Color3.fromRGB(128, 136, 146)
		local DARK = Color3.fromRGB(44, 48, 54)
		local BLACK = Color3.fromRGB(18, 20, 24)
		local MID = Color3.fromRGB(112, 120, 128)
		local RIM = Color3.fromRGB(92, 100, 110)
		local THR = Color3.fromRGB(214, 220, 224)
		local THR_DARK = Color3.fromRGB(120, 128, 136)
		local HOSE = Color3.fromRGB(150, 158, 164)
		local TIRE = Color3.fromRGB(46, 50, 56)
		local GLASS = Color3.fromRGB(176, 236, 214)
		local SEATC = Color3.fromRGB(52, 58, 68)
		local SEATC2 = Color3.fromRGB(72, 80, 92)
		local TANK = Color3.fromRGB(134, 144, 138)
		local GLOW = C.PortalColor

		local N, R_BOT, R_TOP, BOT_Y, TOP_Y = 10, 11.0, 7.2, 0.35, 3.75
		for i = 1, N do
			local t = (i - 0.5) / N
			local r = R_BOT + (R_TOP - R_BOT) * t
			local y = BOT_Y + (TOP_Y - BOT_Y) * t
			local lh = (TOP_Y - BOT_Y) / N + 0.12
			if i < 7 then
				add("HullLayer" .. i, cylX(lh, r * 2), CFrame.new(0, y, 0) * RY, HULL, METAL, 0, "cyl")
			else

				local nSeg, rIn = 32, 6.6
				local thick = r - rIn + 0.1
				local rm = (r + rIn) / 2 - 0.05
				local chord = 2 * r * math.tan(math.pi / nSeg) + 0.05
				for k = 0, nSeg - 1 do
					local a = 2 * math.pi * k / nSeg
					add("HullRing" .. i, Vector3.new(chord, lh, thick), CFrame.Angles(0, a, 0) * CFrame.new(0, y, -rm), HULL, METAL)
				end
			end
		end

		do
			local nSeg, rW = 32, 6.56
			local chord = 2 * rW * math.tan(math.pi / nSeg) + 0.05
			for k = 0, nSeg - 1 do
				local a = 2 * math.pi * k / nSeg
				add("WellLining", Vector3.new(chord, 1.45, 0.1), CFrame.Angles(0, a, 0) * CFrame.new(0, 3.1, -rW), Color3.fromRGB(44, 48, 54), METAL)
			end
		end
		add("Flange", cylX(0.7, 23.6), CFrame.new(0, 0, 0) * RY, FLANGE, METAL, 0, "cyl")
		add("FlangeRim", cylX(0.25, 24.0), CFrame.new(0, -0.1, 0) * RY, MID, METAL, 0, "cyl")
		add("UnderPlate", cylX(0.4, 20), CFrame.new(0, -0.55, 0) * RY, BELLY, METAL, 0, "cyl")
		local belly = add("Belly", Vector3.new(15, 6, 15), CFrame.new(0, -0.7, 0), BELLY, METAL, 0, "sphere")

		do
			local dR, dY = R_BOT - R_TOP, TOP_Y - BOT_Y
			local L = math.sqrt(dR * dR + dY * dY)
			local slope = math.atan2(dY, dR)
			local nR, nY = dY / L, dR / L
			local rMid, yMid = (R_BOT + R_TOP) / 2, (BOT_Y + TOP_Y) / 2
			for k = 0, 7 do
				local aSeam = math.rad(22.5 + 45 * k)
				local sr, sy = rMid + 0.12 * nR, yMid + 0.12 * nY
				add("Seam", Vector3.new(0.26, 0.26, L), CFrame.Angles(0, aSeam, 0) * CFrame.new(0, sy, -sr) * CFrame.Angles(-slope, 0, 0), SEAM, METAL)

				local aPl = math.rad(45 * k)
				local pr, py = rMid + 0.07 * nR, yMid + 0.07 * nY
				local base = CFrame.Angles(0, aPl, 0) * CFrame.new(0, py, -pr) * CFrame.Angles(-slope, 0, 0)
				add("Plate", Vector3.new(4.2, 0.16, 3.4), base, PLATE, METAL, 0, nil, k == 4 and "rdoor" or nil)
				add("PlateHandle", Vector3.new(1.4, 0.2, 0.22), base * CFrame.new(0, 0.16, 1.05), DARK, METAL, 0, nil, k == 4 and "rdoor" or nil)
				if k == 4 then

					add("BayInner", Vector3.new(3.9, 0.04, 3.1), base * CFrame.new(0, -0.03, 0), BLACK, SMOOTH)
					local c0 = CFrame.new(base.Position)
					add("RGBase", Vector3.new(1, 1, 1), c0, DARK, METAL, 1, "sphere", "rarm")
					add("RGUpper", cylX(1, 0.55), c0, MID, METAL, 1, "cyl", "rarm")
					add("RGElbow", Vector3.new(1, 1, 1), c0, DARK, METAL, 1, "sphere", "rarm")
					add("RGFore", cylX(1, 0.48), c0, MID, METAL, 1, "cyl", "rarm")
					add("RGWrist", Vector3.new(1, 1, 1), c0, DARK, METAL, 1, "sphere", "rarm")
					add("RGBody", cylX(1, 0.9), c0, DARK, METAL, 1, "cyl", "rarm")
					add("RGBarrel", cylX(1, 0.5), c0, MID, METAL, 1, "cyl", "rarm")
					add("RGRing", cylX(0.2, 0.78), c0, GLOW, NEON, 1, "cyl", "rarm")
					add("RGGlow", Vector3.new(1, 1, 1), c0, GLOW, NEON, 1, "sphere", "rarm")
					if not pcall(State.buildRearArmDetail, add, cylX, c0, { METAL = METAL, SMOOTH = SMOOTH, NEON = NEON, GLOW = GLOW }) then warnRG("detalhes do canhao nao carregaram") end
				end
			end
		end

		do
			local nR, RR = 24, 7.0
			for k = 0, nR - 1 do
				local a = 2 * math.pi * k / nR
				local chord = 2 * RR * math.tan(math.pi / nR) + 0.06
				add("Rim", Vector3.new(chord, 0.55, 0.75), CFrame.Angles(0, a, 0) * CFrame.new(0, 4.0, -RR), RIM, METAL)
				if k % 2 == 0 then
					add("Bolt", cylX(0.28, 0.5), CFrame.Angles(0, a, 0) * CFrame.new(0, 4.4, -RR) * RY, MID, METAL, 0, "cyl")
				end
			end
		end

		do
			local ax, ay, az = 6.7, 5.95, 6.85
			local nLon, nLat = 20, 5
			local phiMax = math.rad(75)
			local function surf(th, ph)
				return Vector3.new(ax * math.cos(ph) * math.cos(th), ay * math.sin(ph), az * math.cos(ph) * math.sin(th))
			end
			for i = 0, nLat - 1 do
				local ph0, ph1 = phiMax * i / nLat, phiMax * (i + 1) / nLat
				local phm = (ph0 + ph1) / 2
				for j = 0, nLon - 1 do
					local th = 2 * math.pi * (j + 0.5) / nLon
					local p = surf(th, phm)
					local n = Vector3.new(p.X / (ax * ax), p.Y / (ay * ay), p.Z / (az * az)).Unit
					local w = 2 * math.pi * ((ax + az) / 2) * math.cos(phm) / nLon * 1.03
					local h = (surf(th, ph1) - surf(th, ph0)).Magnitude * 1.04
					local pos = Vector3.new(0, 3.8, 0) + p
					local e = add("DomePane", Vector3.new(w, h, 0.12), CFrame.lookAt(pos, pos + n), GLASS, Enum.Material.Glass, 0.55, nil, "canopy")
					e.part.Reflectance = 0.12
					e.part.CastShadow = false
				end
			end
			local capR = ax * math.cos(phiMax)
			local cap = add("DomeCap", cylX(0.14, capR * 2 + 0.2), CFrame.new(0, 3.8 + ay * math.sin(phiMax), 0) * RY, GLASS, Enum.Material.Glass, 0.55, "cyl", "canopy")
			cap.part.Reflectance = 0.12
			cap.part.CastShadow = false
		end
		do
			local segs = 14
			local function P(phi)
				return Vector3.new(0, 3.8 + 5.95 * math.sin(phi), -6.85 * math.cos(phi))
			end
			for k = 0, segs - 1 do
				local p0, p1 = P(math.pi * k / segs), P(math.pi * (k + 1) / segs)
				add("Hoop", Vector3.new(0.3, 0.3, (p1 - p0).Magnitude + 0.06), CFrame.lookAt((p0 + p1) / 2, p1), MID, METAL, 0, nil, "canopy")
			end
		end

		local DEP = 1.3
		local addOrig = add
		add = function(name, size, rel, ...)
			return addOrig(name, size, CFrame.new(0, -DEP, 0) * rel, ...)
		end
		add("Floor", cylX(0.12, 13.2), CFrame.new(0, 3.84, 0) * RY, DARK, SMOOTH, 0, "cyl")

		local okSeat, errSeat = pcall(State.buildSeats, add, cylX, { SEATC = SEATC, SEATC2 = SEATC2, DARK = DARK, MID = MID, GLOW = GLOW, PLASTIC = PLASTIC, METAL = METAL, SMOOTH = SMOOTH })
		if not okSeat then warnRG("bancos:", errSeat) end
		local okTun, errTun = pcall(State.buildTunnel, add, cylX, { MID = MID, DARK = DARK, BLACK = BLACK, LIGHT = FLANGE, METAL = METAL, PLASTIC = PLASTIC, SMOOTH = SMOOTH })
		if not okTun then warnRG("tunel:", errTun) end

		do
			local dashTilt = CFrame.Angles(math.rad(-14), 0, 0)
			local DR, DY, nD, span = 5.425, 4.25, 11, math.rad(116)

			local DH, DUP = 2.0, 0.64
			local TOP = DH / 2
			local da = span / (nD - 1)
			local chord = 2 * (DR + 1.2) * math.tan(da / 2) + 0.04
			local function dashBase(rad)
				return CFrame.new(0, DUP, 0) * CFrame.Angles(0, rad, 0) * CFrame.new(0, DY, -DR) * dashTilt
			end
			for k = 0, nD - 1 do
				local base = dashBase(-span / 2 + da * k)
				add("Dash", Vector3.new(chord, DH, 2.35), base, MID, METAL)
				add("DashTrim", cylX(2 * (DR - 1.1) * math.tan(da / 2) + 0.08, 0.2), base * CFrame.new(0, TOP - 0.02, 1.1), DARK, METAL, 0, "cyl")
			end

			local SCR = CFrame.Angles(0, math.pi, 0)
			local function screen(name, deg)
				return add(name, Vector3.new(1.9, 0.9, 0.06), dashBase(math.rad(deg)) * CFrame.new(0, 0.2, 1.175 + 0.1) * SCR, BLACK, SMOOTH).part
			end

			local partRed = screen("ScreenL", -50)
			local partGreen = screen("ScreenR", 50)
			local okS, errS = pcall(State.makeDashScreens, S, partRed, partGreen, {
				camera = camera, green = GLOW, info = infoLbl,
				SPEED = SPEED, TURBO = TURBO, GROUND_SPEED = GROUND_SPEED, GROUND_TURBO = GROUND_TURBO,
			})
			if not okS then warnRG("telas do painel:", errS) end
			local okD, errD = pcall(State.buildDash, add, cylX, { LIGHT = FLANGE, MID = MID, DARK = DARK, BLACK = BLACK, PLATE = PLATE, METAL = METAL, SMOOTH = SMOOTH }, dashBase)
			if not okD then warnRG("painel:", errD) end
		end

		do
			local wcPos = Vector3.new(-2.3, 6.7, -1.2)
			local wcRot = CFrame.Angles(math.rad(-35), 0, 0)
			S.wheelCF = CFrame.new((wcPos - Vector3.new(0, DEP, 0)) * SCALE) * wcRot
			S.wheelCF0 = S.wheelCF
			S.wheelR = 0.95 * SCALE
			local okW, errW = pcall(State.buildWheel, add, cylX, { MID = MID, DARK = DARK, BLACK = BLACK, METAL = METAL, SMOOTH = SMOOTH, PLASTIC = PLASTIC }, CFrame.new(wcPos) * wcRot, wcPos)
			if not okW then warnRG("volante:", errW) end
		end

		State.buildTank(add, cylX, { TANK = TANK, DARK = DARK, MID = MID, BLACK = BLACK, GLOW = GLOW, METAL = METAL, SMOOTH = SMOOTH })
		add = addOrig

		for _, sx in ipairs({ -1, 1 }) do

			local head = CFrame.new(sx * 3.9, 2.5, -8.5) * CFrame.Angles(0, -sx * math.rad(8), 0)
			add("LampMount", cylX(1.8, 1.2), head * CFrame.new(0, 0, 1.4) * RZ, DARK, METAL, 0, "cyl")
			add("LampHousing", cylX(1.3, 1.9), head * RZ, THR, METAL, 0, "cyl")
			add("LampBack", cylX(0.35, 1.5), head * CFrame.new(0, 0, 0.8) * RZ, DARK, METAL, 0, "cyl")
			add("LampBezel", cylX(0.28, 2.15), head * CFrame.new(0, 0, -0.62) * RZ, FLANGE, METAL, 0, "cyl")
			add("LampTopKnob", cylX(0.35, 0.6), head * CFrame.new(0, 1.0, 0.15) * RY, MID, METAL, 0, "cyl")
			local lens = add("LampLens", cylX(0.14, 1.55), head * CFrame.new(0, 0, -0.74) * RZ, Color3.fromRGB(255, 246, 200), NEON, 0, "cyl")
			local sl = Instance.new("SpotLight")
			sl.Face = Enum.NormalId.Right
			sl.Angle = 50
			sl.Range = 70
			sl.Brightness = 2.5
			sl.Color = Color3.fromRGB(255, 244, 214)
			sl.Parent = lens.part
			S.lamps[#S.lamps + 1] = { lens = lens, light = sl }
			add("Knob", cylX(0.9, 0.7), CFrame.new(sx * 2.03, 3.1, -8.15) * RY, MID, METAL, 0, "cyl")
		end
		add("AntBase", cylX(0.5, 0.7), CFrame.new(5.0, 4.35, 5.2) * RY, DARK, METAL, 0, "cyl")
		add("AntRod", cylX(3.2, 0.14), CFrame.new(5.0, 6.1, 5.2) * RY, MID, METAL, 0, "cyl")
		add("AntTip", Vector3.new(0.4, 0.4, 0.4), CFrame.new(5.0, 7.8, 5.2), Color3.fromRGB(255, 90, 70), NEON, 0, "sphere")

		local function addThruster(sx)
			local cf0 = CFrame.new(sx * 9.5, 2.9, 1.0) * CFrame.Angles(0, math.rad(8) * sx, 0)
			local function sub(z, extra) return cf0 * CFrame.new(0, 0, z) * (extra or CFrame.new()) end
			add("ThrBody", cylX(7, 4.2), sub(0, RZ), THR, METAL, 0, "cyl", "thr")
			for _, z in ipairs({ -2.3, 0, 2.3 }) do
				add("ThrBand", cylX(0.35, 4.5), sub(z, RZ), THR_DARK, METAL, 0, "cyl", "thr")
			end
			add("ThrCap", cylX(0.5, 4.4), sub(-3.6, RZ), THR_DARK, METAL, 0, "cyl", "thr")
			add("ThrLatch", Vector3.new(0.8, 0.5, 1.2), sub(-1.1, CFrame.new(0, 2.3, 0)), DARK, METAL, 0, nil, "thr")
			add("NozA", cylX(0.8, 3.6), sub(3.9, RZ), THR, METAL, 0, "cyl", "thr")
			add("NozB", cylX(0.7, 3.0), sub(4.55, RZ), THR_DARK, METAL, 0, "cyl", "thr")
			add("NozC", cylX(0.6, 2.5), sub(5.15, RZ), DARK, METAL, 0, "cyl", "thr")
			local g = add("NozGlow", cylX(0.15, 1.9), sub(5.5, RZ), GLOW, NEON, 0, "cyl", "thr")

			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 0.95 * SCALE, 0)
			a0.Parent = g.part
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -0.95 * SCALE, 0)
			a1.Parent = g.part
			local tr = Instance.new("Trail")
			tr.Attachment0 = a0
			tr.Attachment1 = a1
			tr.Color = ColorSequence.new(Color3.new(1, 1, 1), GLOW)
			tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
			tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
			tr.LightEmission = 1
			tr.LightInfluence = 0
			tr.FaceCamera = true
			tr.MinLength = 0.05
			tr.Lifetime = 0.3
			tr.Enabled = false
			tr.Parent = g.part
			S.trails[#S.trails + 1] = tr
		end

		local function addHose(sx)
			local A = Vector3.new(sx * 8.7, 2.6, -2.8)
			local B = Vector3.new(sx * 6.4, 4.4, -4.2)
			local n = 8
			local function P(t) return A:Lerp(B, t) + Vector3.new(0, math.sin(math.pi * t) * 0.5, 0) end
			for i = 0, n - 1 do
				local t = (i + 0.5) / n
				local pos = P(t)
				local dir = P(t + 0.01) - P(t - 0.01)
				add("Hose", cylX(0.34, (i % 2 == 0) and 1.25 or 0.95), CFrame.lookAt(pos, pos + dir) * RZ, HOSE, METAL, 0, "cyl")
			end
		end

		for _, sx in ipairs({ -1, 1 }) do
			addThruster(sx)
			addHose(sx)
		end

		for _, sx in ipairs({ -1, 1 }) do
			add("Vent", Vector3.new(2.6, 0.1, 3.2), CFrame.new(sx * 8.6, -0.78, 0), DARK, METAL)
			for _, z in ipairs({ -1.0, -0.35, 0.3, 0.95 }) do
				add("VentSlit", Vector3.new(2.2, 0.05, 0.12), CFrame.new(sx * 8.6, -0.82, z), MID, METAL)
			end
		end

		local CHROME = Color3.fromRGB(228, 234, 240)
		local CHROME_D = Color3.fromRGB(58, 62, 68)
		local TIRE_D = Color3.fromRGB(28, 30, 34)

		local function makeWheelHub(id, x, y, z, wr)
			local hubPart = Instance.new("Part")
			hubPart.Name = "WheelHub" .. id
			hubPart.Anchored = false
			hubPart.Massless = true
			hubPart.CanCollide = false
			hubPart.CanQuery = false
			hubPart.CanTouch = false
			hubPart.Transparency = 1
			hubPart.Size = Vector3.new(0.2, 0.2, 0.2)
			hubPart.CastShadow = false
			local hubRel = CFrame.new(x * SCALE, y * SCALE, z * SCALE)
			local w = Instance.new("Weld")
			w.Part0 = root
			w.Part1 = hubPart
			w.C0 = hubRel
			w.Parent = hubPart
			hubPart.Parent = model
			local e = { part = hubPart, weld = w, rel = hubRel, tag = "gear", baseT = 1, wr = wr, wid = id, isHub = true }
			S.parts[#S.parts + 1] = e
			S.gearParts[#S.gearParts + 1] = e
			S.wheelHubs[id] = e
			return e
		end

		local function addSpin(hubE, name, size, loc, color, material, shape, refl)
			local p = Instance.new("Part")
			p.Name = name
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Size = size * SCALE
			p.CastShadow = size.Magnitude > 3
			p.Color = color
			p.Material = material or METAL
			p.Transparency = 0
			if shape == "sphere" then
				local m = Instance.new("SpecialMesh")
				m.MeshType = Enum.MeshType.Sphere
				m.Parent = p
			elseif shape == "cyl" then
				p.Shape = Enum.PartType.Cylinder
			end
			local locS = CFrame.new(loc.Position * SCALE) * loc.Rotation
			local w = Instance.new("Weld")
			w.Part0 = hubE.part
			w.Part1 = p
			w.C0 = locS
			w.Parent = p
			p.Parent = model
			if refl then p.Reflectance = refl end

			local e = { part = p, weld = w, rel = locS, tag = nil, baseT = 0, parentHub = hubE }
			S.parts[#S.parts + 1] = e
			return e
		end

		local function monsterWheel(tag, id, side, x, y, z, len, diam)
			local wr = diam / 2 * SCALE
			S.wheels[id] = { rel = Vector3.new(x, y, z) * SCALE, r = wr, x = 0, v = 0, lastX = 0 }
			local hubE = makeWheelHub(id, x, y, z, wr)
			local function sp(name, size, loc, color, material, shape, refl)
				return addSpin(hubE, name, size, loc, color, material, shape, refl)
			end

			local lugH = diam * 0.12
			local coreD = diam - 2 * lugH
			sp("Tire" .. tag, cylX(len, coreD), CFrame.new(), TIRE, SMOOTH, "cyl")
			local LUGS = 11
			local R = coreD / 2 + lugH / 2 - 0.02
			for k = 0, LUGS - 1 do
				local a = 2 * math.pi * k / LUGS
				for _, h in ipairs({ -1, 1 }) do
					local loc = CFrame.Angles(a, 0, 0) * CFrame.new(h * len * 0.25, R + (h == 1 and 0.012 or 0), 0) * CFrame.Angles(0, h * math.rad(32), 0)
					sp("Lug" .. tag, Vector3.new(len * 0.52, lugH, diam * 0.17), loc, TIRE_D, SMOOTH)
				end
			end

			local sides = (side == 0) and { -1, 1 } or { side }
			local rimD = diam * 0.5
			if side == 0 then
				sp("Rim" .. tag, cylX(len + 0.22, rimD), CFrame.new(), CHROME, METAL, "cyl", 0.45)
			else
				sp("Rim" .. tag, cylX(len * 0.8, rimD), CFrame.new(side * (len * 0.1 + 0.11), 0, 0), CHROME, METAL, "cyl", 0.45)
			end
			for _, sd in ipairs(sides) do
				sp("Bead" .. tag, cylX(0.16, rimD * 1.18), CFrame.new(sd * (len * 0.5 + 0.015), 0, 0), CHROME_D, METAL, "cyl")
				for k = 0, 5 do
					local a = 2 * math.pi * k / 6 + 0.26
					sp("RimHole" .. tag, cylX(0.12, rimD * 0.17),
						CFrame.Angles(a, 0, 0) * CFrame.new(sd * (len * 0.5 + 0.14), rimD * 0.32, 0), BLACK, SMOOTH, "cyl")
				end
				sp("Cap" .. tag, cylX(0.35, rimD * 0.36), CFrame.new(sd * (len * 0.5 + 0.22), 0, 0), CHROME, METAL, "cyl", 0.5)
			end
		end

		monsterWheel("FL", 1, -1, -5.4, -2.7, -4.6, 2.0, 4.6)
		monsterWheel("FR", 2, 1, 5.4, -2.7, -4.6, 2.0, 4.6)
		monsterWheel("RC", 3, 0, 0, -2.6, 6.8, 2.4, 4.8)

		local ds = add("DustSrc", Vector3.new(9, 0.1, 6), CFrame.new(0, -4.6, 3), BLACK, SMOOTH, 1)
		local dust = Instance.new("ParticleEmitter")
		dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
		dust.Color = ColorSequence.new(Color3.fromRGB(196, 190, 178))
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) })
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		dust.Lifetime = NumberRange.new(0.7, 1.2)
		dust.Speed = NumberRange.new(3, 8)
		dust.SpreadAngle = Vector2.new(40, 40)
		dust.EmissionDirection = Enum.NormalId.Top
		dust.Rate = 0
		dust.Parent = ds.part
		S.dust = dust

		S.solidParts, S.domeSolid = {}, {}
		local SOLID_NAME = { WellLining = true, Floor = true, Flange = true, FlangeRim = true, UnderPlate = true, Rim = true,
			Dash = true, SeatBase = true, SeatBaseLip = true, SeatBack = true, SeatSkid = true, ThrBody = true }
		for _, e in ipairs(S.parts) do
			local nm = e.part.Name
			if e.parentHub then

			elseif nm == "DomePane" or nm == "DomeCap" then
				S.domeSolid[#S.domeSolid + 1] = e.part
			elseif SOLID_NAME[nm] or nm:sub(1, 9) == "HullLayer" or nm:sub(1, 8) == "HullRing" then
				S.solidParts[#S.solidParts + 1] = e.part
			end
		end

		do
			local hub = Instance.new("Part")
			hub.Name = "CanopyHub"
			hub.Anchored = false
			hub.Massless = true
			hub.CanCollide = false
			hub.CanQuery = false
			hub.CanTouch = false
			hub.Transparency = 1
			hub.CastShadow = false
			hub.Size = Vector3.new(0.2, 0.2, 0.2)
			local hw = Instance.new("Weld")
			hw.Part0 = root
			hw.Part1 = hub
			hw.C0 = CFrame.new()
			hw.Parent = hub
			hub.Parent = model
			for _, e in ipairs(S.canopyParts) do e.weld.Part0 = hub end
			S.canopyHub = { part = hub, weld = hw }
		end

		return S
	end

	local function armJoints()
		local J = { right = { extra = {} }, left = { extra = {} } }
		local names = { right = { "RightUpperArm", "Right Arm" }, left = { "LeftUpperArm", "Left Arm" } }
		local extraN = { right = { RightLowerArm = true, RightHand = true }, left = { LeftLowerArm = true, LeftHand = true } }
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("Motor6D") and d.Part0 and d.Part1 then
				local n = d.Part1.Name
				for side, list in pairs(names) do
					if n == list[1] or n == list[2] then
						J[side].shoulder = J[side].shoulder or d
					elseif extraN[side][n] then
						table.insert(J[side].extra, d)
					end
				end
			end
		end
		return J
	end

	local function releaseHands(S)
		if not S.handsOn then return end
		S.handsOn = false
		S.hwB, S.hwS = 0, 0
		if (S.hwLean or 0) > 0 then
			S.hwLean = 0
			if S.hwWaist and S.hwWaist.Parent then S.hwWaist.Transform = CFrame.new() end
		end
		S.wheelFit = false
		if S.wheelCF0 then S.wheelCF = S.wheelCF0 end
		local J = S.handJ
		S.handJ = nil
		if not J then return end
		for _, side in pairs(J) do
			if side.shoulder and side.shoulder.Parent then side.shoulder.Transform = CFrame.new() end
			for _, m in ipairs(side.extra) do
				if m.Parent then m.Transform = CFrame.new() end
			end
		end
	end

	local function rotFromDown(d)
		local down = Vector3.new(0, -1, 0)
		local axis = down:Cross(d)
		local dp = down:Dot(d)
		if axis.Magnitude < 1e-4 then
			return dp > 0 and CFrame.new() or CFrame.Angles(math.pi, 0, 0)
		end
		return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(dp, -1, 1)))
	end

	local function updateHands(S)
		if not S.wheelCF or humanoid.Health <= 0 then return end
		if not S.handJ or not S.handJ.right.shoulder or (S.handJ.right.shoulder.Parent == nil) then
			S.handJ = armJoints()
		end
		S.handsOn = true

		local seatW = S.cf * SEAT_REL
		local rootInv = rootPart.CFrame:Inverse()
		local function pw(part) return seatW * (rootInv * part.CFrame) end
		if not S.wheelFit then
			local jr, jl = S.handJ.right, S.handJ.left
			local function reachOf(j)
				local sh = j.shoulder
				if not (sh and sh.Part1) then return nil end
				local len = sh.Part1.Size.Y
				for _, m in ipairs(j.extra) do
					if m.Part1 then len = len + m.Part1.Size.Y * (m.Part1.Name:find("Hand") and 0.4 or 1) end
				end
				return len
			end
			local rl = reachOf(jr) or reachOf(jl)
			if rl and jr.shoulder and jr.shoulder.Part0 and jl.shoulder and jl.shoulder.Part0 then
				S.wheelFit = true
				local pr = pw(jr.shoulder.Part0) * jr.shoulder.C0.Position
				local pl = pw(jl.shoulder.Part0) * jl.shoulder.C0.Position
				local mid = S.cf:PointToObjectSpace((pr + pl) / 2)
				local reach = rl * 0.88
				local cy = math.clamp(mid.Y - 0.4, 5.0 * SCALE, 6.7 * SCALE)
				local dy = mid.Y - cy
				local dz = math.sqrt(math.max(reach * reach - dy * dy, 0.25))
				local p0 = S.wheelCF0.Position
				S.wheelCF = CFrame.new(p0.X, cy, mid.Z - dz) * (S.wheelCF0 - S.wheelCF0.Position)
			end
		end
		local wcw = S.cf * S.wheelCF * CFrame.Angles(0, 0, S.wheelAng or 0)
		local R = S.wheelR or 0.95

		local grips = {
			right = wcw * CFrame.new(R, 0, 0).Position,
			left = wcw * CFrame.new(-R, 0, 0).Position,
		}
		for side, j in pairs(S.handJ) do
			local sh = j.shoulder
			if sh and sh.Parent and sh.Part0 then
				local p0w = pw(sh.Part0)
				local pivot = p0w * sh.C0.Position
				local dirW = grips[side] - pivot
				if dirW.Magnitude > 0.05 then
					local cur = p0w:VectorToObjectSpace(dirW.Unit)
					local ref = sh.C0
					local base = ref - ref.Position
					sh.Transform = sh.C0:Inverse() * CFrame.new(ref.Position) * rotFromDown(cur) * base
					for _, m in ipairs(j.extra) do
						if m.Parent then m.Transform = CFrame.new() end
					end
				end
			end
		end

		State.shipArmIK(S, S.handJ.right, pw, held)
	end

	local function place(S)
		S.root.CFrame = S.cf
		S.wheelAng = (S.steer or 0) * 3.2
		if S.wheelCF and (S.lastWa ~= S.wheelAng or S.lastWcf ~= S.wheelCF) then
			S.lastWcf = S.wheelCF
			S.lastWa = S.wheelAng
			local rot = CFrame.Angles(0, 0, S.wheelAng)
			local inv = S.wheelCF0:Inverse()
			for _, e in ipairs(S.swParts) do
				e.weld.C0 = S.wheelCF * rot * (inv * e.rel)
			end
			for _, e in ipairs(S.swCol) do
				e.weld.C0 = S.wheelCF * (inv * e.rel)
			end
			local wpos, wpos0 = S.wheelCF.Position, S.wheelCF0.Position
			for _, e in ipairs(S.swBase) do
				e.weld.C0 = CFrame.new(wpos.X - wpos0.X, 0, wpos.Z - wpos0.Z) * e.rel
			end
		end
		if S.state == "flying" or S.state == "shifting" then
			pcall(updateHands, S)
		elseif S.handsOn then
			pcall(releaseHands, S)
		end
		if S.lastGear ~= S.gear or S.lastSpin ~= S.spinDist or S.suspDirty or S.lastSteer ~= S.steer then
			S.lastGear = S.gear
			S.lastSpin = S.spinDist
			S.lastSteer = S.steer
			S.suspDirty = false
			local gs = (1 - S.gear) * GEAR_TRAVEL
			for _, e in ipairs(S.gearParts) do
				if e.isHub then

					local off = (S.wheels[e.wid] and S.wheels[e.wid].x or 0) * S.gear
					local st = (e.wid == 1 or e.wid == 2) and (S.steer or 0) * S.gear or 0
					e.weld.C0 = CFrame.new(0, gs + off, 0) * e.rel * CFrame.Angles(0, st, 0) * CFrame.Angles(-S.spinDist / e.wr, 0, 0)
				else

					local c = CFrame.new(0, gs, 0) * e.rel
					if e.wr then c = c * CFrame.Angles(-S.spinDist / e.wr, 0, 0) end
					e.weld.C0 = c
				end
			end
		end
		if S.lastCa ~= S.canopyAng then
			S.lastCa = S.canopyAng
			local frac = math.clamp(S.canopyAng / CANOPY_OPEN, 0, 1)

			local hinge = CFrame.new(CANOPY_HINGE)
			local swing = hinge * CFrame.Angles(frac * CANOPY_ANGLE, 0, 0) * hinge:Inverse()
			if S.canopyHub then

				S.canopyHub.weld.C0 = swing
			else
				for _, e in ipairs(S.canopyParts) do
					e.weld.C0 = swing * e.rel
				end
			end
		end
	end

	local function snap(S)
		place(S)
		for _, e in ipairs(S.parts) do
			if e.parentHub then

				e.part.CFrame = e.parentHub.part.CFrame * e.weld.C0
			else
				e.part.CFrame = S.cf * e.weld.C0
			end
		end
	end

	local function shake(S, amp)
		if amp < 0.01 then
			if S.shaking then
				S.shaking = false
				for _, e in ipairs(S.thrParts) do e.weld.C0 = e.rel end
			end
			return
		end
		S.shaking = true
		for _, e in ipairs(S.thrParts) do
			e.weld.C0 = e.rel * CFrame.new((math.random() - 0.5) * amp, (math.random() - 0.5) * amp, 0)
		end
	end

	local function setThrust(S, t)
		local st = S.state
		local on = t > 0.02 and (S.mode == "fly" or st == "arriving" or st == "leaving" or st == "shifting")
		if not on then

			if S.tk and S.tk ~= 0 then S.tk = 0 end
			for _, tr in ipairs(S.trails) do
				if tr.Enabled then tr.Enabled = false end
			end
			if t <= 0.02 then shake(S, 0) end
			return
		end
		local now = os.clock()
		local dt = math.min(now - (S.trailClk or now), 0.1)
		S.trailClk = now
		local goal = S.turbo and 1 or 0
		local k = (S.tk or 0) + (goal - (S.tk or 0)) * (1 - math.exp(-7 * dt))
		S.tk = k
		local ti = math.clamp(t, 0, 1)
		local head = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 244, 205), k)
		local mid = C.PortalColor:Lerp(Color3.fromRGB(255, 150, 40), k)
		local tail = C.PortalColor:Lerp(Color3.fromRGB(220, 50, 20), k)
		local cs = ColorSequence.new({
			ColorSequenceKeypoint.new(0, head),
			ColorSequenceKeypoint.new(0.45, mid),
			ColorSequenceKeypoint.new(1, tail),
		})
		local ws = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 + 0.9 * k), NumberSequenceKeypoint.new(1, 0) })
		local life = (0.28 + 0.55 * k) * (0.55 + 0.45 * ti)
		for _, tr in ipairs(S.trails) do
			tr.Enabled = true
			tr.Color = cs
			tr.WidthScale = ws
			tr.Lifetime = life
		end
	end

	local handConn = RunService.Stepped:Connect(function(_, dt)
		local S = ship
		if S and not destroyed and (S.state == "flying" or S.state == "shifting") then
			local okH, eH = pcall(updateHands, S)
			if not okH and not S.handErr then S.handErr = true; warnRG("maos no volante:", eH) end
		end

		if S and not destroyed and State.shipLv then
			local okL, eL = pcall(State.shipLv.fx, S, dt)
			if not okL and not S.leverErr then S.leverErr = true; warnRG("alavancas da nave:", eL) end
		end

		if S and not destroyed and S.dashFx then
			local okD, eD = pcall(S.dashFx, S, dt)
			if not okD and not S.dashErr then S.dashErr = true; warnRG("telas do painel:", eD) end
		end
	end)

	local function removeShip()
		if ship then
			local m = ship.model
			pcall(releaseHands, ship)
			ship = nil
			pcall(function() m:Destroy() end)
		end
	end

	local function inShip()
		return ship ~= nil and (ship.state == "boarding" or ship.state == "flying" or ship.state == "landing" or ship.state == "shifting")
	end

	local function gone(S)
		return destroyed or not Z.alive or ship ~= S
	end

	local function holdChar(S)
		rootPart.CFrame = S.cf * SEAT_REL
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
		if not humanoid.Sit then humanoid.Sit = true end
		for p, _ in pairs(savedCollide) do
			if p.Parent and p.CanCollide then p.CanCollide = false end
		end
	end

	local function bindSink()
		if sinkBound then return end
		sinkBound = true
		pcall(function()
			ContextActionService:BindActionAtPriority(
				"RickShipSink",
				function() return Enum.ContextActionResult.Sink end,
				false,
				Enum.ContextActionPriority.High.Value,
				Enum.KeyCode.Space
			)
		end)
	end

	local function unbindSink()
		if not sinkBound then return end
		sinkBound = false
		pcall(function() ContextActionService:UnbindAction("RickShipSink") end)
	end

	local function restoreChar()
		if ship then pcall(releaseHands, ship) end
		for p, v in pairs(savedCollide) do
			if p.Parent then p.CanCollide = v end
		end
		savedCollide = {}
		if savedJump ~= nil then
			local v = savedJump
			savedJump = nil
			pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, v) end)
		end
		if savedAutoRotate ~= nil then
			local v = savedAutoRotate
			savedAutoRotate = nil
			pcall(function() humanoid.AutoRotate = v end)
		end
		unbindSink()
		if baseFov then
			local f = baseFov
			baseFov = nil
			pcall(function() camera.FieldOfView = f end)
		end
		if savedZoom then
			local z = savedZoom
			savedZoom = nil
			pcall(function()
				player.CameraMinZoomDistance = z[1]
				player.CameraMaxZoomDistance = z[2]
			end)
		end
		pad.Visible = false
		infoLbl.Visible = false
		held.up, held.down, held.turbo = false, false, false
		held.brake, held.brakeUi, held.closeView = false, false, false
		btnTurbo.TextColor3 = Theme.Text
	end

	local function getMove()
		if controls == nil then
			controls = false
			pcall(function()
				local ps = player:FindFirstChild("PlayerScripts")
				local pm = ps and ps:FindFirstChild("PlayerModule")
				if pm then controls = require(pm):GetControls() or false end
			end)
		end
		if controls then
			local ok, v = pcall(function() return controls:GetMoveVector() end)
			if ok and typeof(v) == "Vector3" then return v end
		end
		local x = (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
		local z = (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0)
		return Vector3.new(x, 0, z)
	end

	local function flightStep(S, dt)
		local typing = UserInputService:GetFocusedTextBox() ~= nil
		local mv = getMove()
		local dir = camera.CFrame:VectorToWorldSpace(Vector3.new(mv.X, 0, mv.Z))

		local vert = 0
		if not typing then
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vert = vert + 1 end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C) then vert = vert - 1 end
		end
		if held.up then vert = vert + 1 end
		if held.down then vert = vert - 1 end
		dir = dir + Vector3.new(0, vert, 0)
		if dir.Magnitude > 1 then dir = dir.Unit end

		local turbo = held.turbo or (not typing and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift))
		local top = SPEED * (turbo and TURBO or 1) * (1 + State.space.k * 3)
		S.vel = S.vel:Lerp(dir * top, 1 - math.exp(-ACCEL * dt))
		S.pos = S.pos + S.vel * dt

		local minY = workspace.FallenPartsDestroyHeight + 40
		if S.pos.Y < minY then
			S.pos = Vector3.new(S.pos.X, minY, S.pos.Z)
			S.vel = Vector3.new(S.vel.X, math.max(S.vel.Y, 0), S.vel.Z)
		end

		local hv = Vector3.new(S.vel.X, 0, S.vel.Z)
		if hv.Magnitude > 6 then
			local diff = wrapAng(math.atan2(-hv.X, -hv.Z) - S.yaw)
			local stepYaw = diff * (1 - math.exp(-TURN * dt))
			S.yaw = S.yaw + stepYaw
			S.yawRate = stepYaw / math.max(dt, 1e-3)
		else
			S.yawRate = S.yawRate * (1 - math.min(1, 8 * dt))
		end

		local tPitch = 0
		if S.vel.Magnitude > 6 then tPitch = math.clamp(math.atan2(S.vel.Y, hv.Magnitude), -1.45, 1.45) end
		local tRoll = math.clamp(S.yawRate * 0.18, -0.5, 0.5)
		S.pitch = S.pitch + (tPitch - S.pitch) * (1 - math.exp(-5 * dt))
		S.roll = S.roll + (tRoll - S.roll) * (1 - math.exp(-5 * dt))

		local spd = S.vel.Magnitude
		S.turbo = turbo and spd > SPEED * 1.2
		local bob = math.sin(os.clock() * 1.8) * 0.25 * SCALE * (1 - math.min(spd / top, 1))
		S.cf = CFrame.new(S.pos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, S.yaw, 0) * CFrame.Angles(S.pitch, 0, S.roll)
		place(S)
		setThrust(S, math.clamp(spd / (SPEED * 1.2), 0.15, 1))
		shake(S, math.clamp(spd / (SPEED * TURBO) - 0.35, 0, 1) * 0.18 * SCALE)
		holdChar(S)

		if baseFov then
			local tgt = baseFov + ((turbo and spd > SPEED * 1.2) and 16 or 0)
			camera.FieldOfView = camera.FieldOfView + (tgt - camera.FieldOfView) * (1 - math.exp(-6 * dt))
		end

		S.infoT = S.infoT + dt
		if S.infoT > 0.1 then
			S.infoT = 0
			infoLbl.Text = string.format("VOO   VEL %d   ALT %d%s",
				math.floor(spd + 0.5), math.floor(S.pos.Y + 0.5), turbo and "   TURBO" or "")
		end
	end

	function api.glide(S, dt)
		local typing = UserInputService:GetFocusedTextBox() ~= nil
		local mv = getMove()
		local d = camera.CFrame:VectorToWorldSpace(Vector3.new(mv.X, 0, mv.Z))
		d = Vector3.new(d.X, 0, d.Z)
		if d.Magnitude > 1 then d = d.Unit end
		local turbo = held.turbo or (not typing and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift))
		local top = SPEED * (turbo and TURBO or 1)
		local hv = Vector3.new(S.vel.X, 0, S.vel.Z):Lerp(d * top, 1 - math.exp(-ACCEL * dt))
		S.vel = hv
		S.pos = S.pos + hv * dt
		if hv.Magnitude > 6 then
			local diff = wrapAng(math.atan2(-hv.X, -hv.Z) - S.yaw)
			S.yaw = S.yaw + diff * (1 - math.exp(-TURN * dt))
		end
		S.turbo = turbo and hv.Magnitude > SPEED * 1.2
	end

	local function refreshHud(S)
		local fly = S.mode == "fly"
		btnUp.Visible = fly
		btnDown.Visible = fly
	end

	local function suspStep(S, dt, grounded, spd, top)
		local damp = 2 * SUSP_ZETA * math.sqrt(SUSP_K)
		local impact = S.landImpact
		S.landImpact = nil
		local rough = grounded and math.min(spd / top, 1) or 0
		local n = math.max(1, math.ceil(dt / 0.012))
		local h = dt / n
		for id, w in pairs(S.wheels) do
			local center = S.cf * CFrame.new(w.rel)
			local u = -SUSP_DROOP
			if grounded then
				local g = groundAt(center.Position, 6 * SCALE)
				if g then
					u = math.clamp(g.Y - (center.Position.Y - w.r), -SUSP_DROOP, SUSP_BUMP)
				end

				u = u + math.noise(S.spinDist * 0.4, id * 7.3) * 0.12 * SCALE * rough

				local sx = (w.rel.X > 0.1) and 1 or ((w.rel.X < -0.1) and -1 or 0)
				local sz = (w.rel.Z > 0) and 1 or -1
				u = u + (-sx * (S.latN or 0) + sz * (S.lonN or 0)) * SUSP_LOAD
				u = math.clamp(u, -SUSP_DROOP, SUSP_BUMP)
			end
			if impact then w.v = w.v + math.clamp(-impact * 0.35, 0, 18) end
			for _ = 1, n do
				w.v = w.v + (SUSP_K * (u - w.x) - damp * w.v) * h
				w.x = w.x + w.v * h
				if w.x > SUSP_BUMP then
					w.x = SUSP_BUMP
					if w.v > 0 then w.v = -w.v * 0.2 end
				elseif w.x < -SUSP_DROOP then
					w.x = -SUSP_DROOP
					if w.v < 0 then w.v = -w.v * 0.2 end
				end
			end
			if math.abs(w.x - w.lastX) > 0.001 then
				w.lastX = w.x
				S.suspDirty = true
			end
		end
	end

	local function groundStep(S, dt)
		local typing = UserInputService:GetFocusedTextBox() ~= nil
		local mv = getMove()
		local flatIn = Vector3.new(mv.X, 0, mv.Z)
		local look = camera.CFrame:VectorToWorldSpace(flatIn)
		local flat = Vector3.new(look.X, 0, look.Z)
		local dir = Vector3.zero
		if flat.Magnitude > 0.01 then dir = flat.Unit * math.min(flatIn.Magnitude, 1) end

		local turbo = held.turbo or (not typing and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift))
		local top = GROUND_SPEED * (turbo and GROUND_TURBO or 1)

		local dl = (S.state == "flying" and S.mode == "ground") and math.clamp(S.brakeNotch or 0, 0, 3) or 0
		local slip = 0
		local hv
		if dl > 0 then
			local cur = Vector3.new(S.vel.X, 0, S.vel.Z)
			local fwdD = Vector3.new(-math.sin(S.yaw), 0, -math.cos(S.yaw))
			local rgtD = Vector3.new(math.cos(S.yaw), 0, -math.sin(S.yaw))
			local vF, vR = cur:Dot(fwdD), cur:Dot(rgtD)
			local grip = (C.ShipDriftGrip or { 2.4, 1.1, 0.45 })[dl]
			local hasIn = dir.Magnitude > 0.05
			local tgtF = hasIn and top * math.min(dir.Magnitude, 1) or 0
			vF = vF + (tgtF - vF) * (1 - math.exp(-GROUND_ACCEL * (hasIn and 0.8 or 1.4) * dt))
			vR = vR * math.exp(-grip * dt)
			slip = math.abs(vR)
			hv = fwdD * vF + rgtD * vR
		else
			hv = Vector3.new(S.vel.X, 0, S.vel.Z):Lerp(dir * top, 1 - math.exp(-GROUND_ACCEL * dt))
		end

		if hv.Magnitude > 0.5 then
			local mDir = hv.Unit
			local lat = Vector3.new(-mDir.Z, 0, mDir.X)
			local reach = 11.5 * SCALE + hv.Magnitude * dt
			for _, off in ipairs({ 0, 7 * SCALE, -7 * SCALE }) do
				local w = castDir(S.pos + Vector3.new(0, 1.5 * SCALE, 0) + lat * off, mDir * reach)
				if w and math.abs(w.Normal.Y) < 0.6 then
					local n = Vector3.new(w.Normal.X, 0, w.Normal.Z)
					if n.Magnitude > 0.01 then
						n = n.Unit
						local into = hv:Dot(n)
						if into < 0 then hv = hv - n * into end
					end
					break
				end
			end
		end

		local posN = Vector3.new(S.pos.X + hv.X * dt, S.pos.Y, S.pos.Z + hv.Z * dt)
		local g, gn = groundAt(posN, 6 * SCALE)
		local targetY = nil
		if g then
			targetY = g.Y + LEG_H
			if targetY - S.pos.Y > STEP_UP then
				hv = Vector3.zero
				posN = S.pos
				g, gn = groundAt(S.pos, 6 * SCALE)
				targetY = g and (g.Y + LEG_H) or nil
			end
		end

		local y = posN.Y
		local grounded = false
		if targetY then
			if y > targetY + 0.15 then
				S.vy = S.vy - 160 * dt
				y = math.max(targetY, y + S.vy * dt)
				if y <= targetY then S.landImpact = S.vy; S.vy = 0 end
			else
				S.vy = 0
				y = y + (targetY - y) * (1 - math.exp(-18 * dt))
				grounded = true
			end
		else
			S.vy = S.vy - 160 * dt
			y = y + S.vy * dt
		end
		local minY = workspace.FallenPartsDestroyHeight + 40
		if y < minY then y = minY; S.vy = 0 end
		S.pos = Vector3.new(posN.X, y, posN.Z)
		S.vel = hv

		S.turbo = false

		local spd = hv.Magnitude
		if dl > 0 then
			if dir.Magnitude > 0.05 then
				local diff = wrapAng(math.atan2(-dir.X, -dir.Z) - S.yaw)
				local stepYaw = diff * (1 - math.exp(-(C.ShipDriftTurn or { 10, 13, 17 })[dl] * dt))
				S.yaw = S.yaw + stepYaw
				S.yawRate = stepYaw / math.max(dt, 1e-3)
			else
				S.yawRate = S.yawRate * (1 - math.min(1, 8 * dt))
			end
		elseif spd > 3 then
			local diff = wrapAng(math.atan2(-hv.X, -hv.Z) - S.yaw)
			local stepYaw = diff * (1 - math.exp(-8 * dt))
			S.yaw = S.yaw + stepYaw
			S.yawRate = stepYaw / math.max(dt, 1e-3)
		else
			S.yawRate = S.yawRate * (1 - math.min(1, 8 * dt))
		end

		do
			local ref = (spd > 3) and hv or dir
			local tgt = 0
			if ref.Magnitude > 0.01 then
				local d = wrapAng(math.atan2(-ref.X, -ref.Z) - S.yaw)
				tgt = math.clamp(d, -0.66, 0.66)
			end
			S.steer = (S.steer or 0) + (tgt - (S.steer or 0)) * (1 - math.exp(-12 * dt))
		end

		local tPitch, tRoll = 0, 0
		if grounded and gn then
			local f = Vector3.new(-math.sin(S.yaw), 0, -math.cos(S.yaw))
			local r = Vector3.new(math.cos(S.yaw), 0, -math.sin(S.yaw))
			tPitch = math.clamp(math.atan2(-gn:Dot(f), gn.Y), -0.5, 0.5)
			tRoll = math.clamp(math.atan2(-gn:Dot(r), gn.Y), -0.5, 0.5)
		end
		S.pitch = S.pitch + (tPitch - S.pitch) * (1 - math.exp(-6 * dt))
		S.roll = S.roll + (tRoll - S.roll) * (1 - math.exp(-6 * dt))

		local fwd = Vector3.new(-math.sin(S.yaw), 0, -math.cos(S.yaw))
		local rgt = Vector3.new(math.cos(S.yaw), 0, -math.sin(S.yaw))
		local acc = (hv - (S.prevHv or hv)) / math.max(dt, 1 / 120)
		S.prevHv = hv

		local latT = grounded and math.clamp(acc:Dot(rgt) / 150, -1, 1) or 0
		local lonT = grounded and math.clamp(acc:Dot(fwd) / 150, -1, 1) or 0
		S.latN = (S.latN or 0) + (latT - (S.latN or 0)) * (1 - math.exp(-10 * dt))
		S.lonN = (S.lonN or 0) + (lonT - (S.lonN or 0)) * (1 - math.exp(-10 * dt))
		local tLP = lonT * 0.07
		local tLR = latT * 0.12 * (1 + 0.5 * dl)
		if S.landImpact then S.leanPV = S.leanPV + math.clamp(S.landImpact * 0.008, -0.7, 0) end
		local LK, LC = 70, 2 * 0.36 * math.sqrt(70)
		S.leanPV = S.leanPV + (LK * (tLP - S.leanP) - LC * S.leanPV) * dt
		S.leanP = S.leanP + S.leanPV * dt
		S.leanRV = S.leanRV + (LK * (tLR - S.leanR) - LC * S.leanRV) * dt
		S.leanR = S.leanR + S.leanRV * dt

		S.cf = CFrame.new(S.pos) * CFrame.Angles(0, S.yaw, 0) * CFrame.Angles(S.pitch + S.leanP, 0, S.roll + S.leanR)

		S.suspAcc = (S.suspAcc or 0) + dt
		if S.suspAcc >= (1 / 30) then
			local sdt = S.suspAcc
			S.suspAcc = 0
			suspStep(S, sdt, grounded, spd, top)
		end

		S.spinDist = S.spinDist + hv:Dot(fwd) * dt
		place(S)

		setThrust(S, 0)
		if S.dust then
			local rate = (grounded and spd > 4) and math.clamp(spd * 0.6, 0, 40) or 0
			if dl > 0 and rate > 0 then

				rate = math.clamp(rate * (1 + 0.7 * dl) + slip * (C.ShipDriftDust or 2.2) * dl, 0, 140)
			end
			S.dust.Rate = rate
		end
		holdChar(S)

		if baseFov then
			local tgt = baseFov + ((turbo and spd > GROUND_SPEED * 1.2) and 10 or 0)
			camera.FieldOfView = camera.FieldOfView + (tgt - camera.FieldOfView) * (1 - math.exp(-6 * dt))
		end
		S.infoT = S.infoT + dt
		if S.infoT > 0.1 then
			S.infoT = 0
			infoLbl.Text = string.format("TERRA   VEL %d%s", math.floor(spd + 0.5), turbo and "   TURBO" or "")
		end
	end

	local function proximity(S)

		if busy or humanoid.Health <= 0 then
			api.nearShip = false
			return
		end
		local d = rootPart.Position - S.pos
		local flat = Vector3.new(d.X, 0, d.Z).Magnitude
		api.nearShip = flat < 30 * SCALE and math.abs(d.Y) < 16
		if os.clock() <= lastBoard or humanoid.SeatPart then return end
		local rel = S.cf:PointToObjectSpace(rootPart.Position)
		local onSeat = math.abs(rel.X + 2.3 * SCALE) < 1.0 * SCALE and math.abs(rel.Z - 0.525 * SCALE) < 1.0 * SCALE
			and rel.Y > (3.2 + 2.0) * SCALE and rel.Y < (3.2 + 5.0) * SCALE
		if S.needLeave then
			if not onSeat then S.needLeave = false end
			return
		end

		if math.abs(rel.X + 2.3 * SCALE) < 1.0 * SCALE and math.abs(rel.Z - 0.525 * SCALE) < 1.0 * SCALE
			and rel.Y > (3.2 + 2.0) * SCALE and rel.Y < (3.2 + 5.0) * SCALE then
			api.board(true)
		end
	end

	local function step(dt)
		if destroyed or not Z.alive then return end
		dt = math.min(dt, 0.1)

		for i = #jobs, 1, -1 do
			local j = jobs[i]
			if j then
				local a = math.clamp((os.clock() - j.t0) / j.dur, 0, 1)
				local okF, errF = pcall(j.fn, TweenService:GetValue(a, j.style, j.dir), a)
				if not okF then
					warnRG("erro na animacao da nave:", errF)
					table.remove(jobs, i)
					j.ok = false
					task.spawn(j.th)
				elseif a >= 1 then
					table.remove(jobs, i)
					j.ok = true
					task.spawn(j.th)
				end
			end
		end

		local S = ship
		if not S then
			boardBtn.Visible = false
			api.nearShip = false
			api.padSync(nil)
			pcall(State.space.step, nil, dt, C, camera)
			return
		end
		local okSp, errSp = pcall(State.space.step, S, dt, C, camera)
		if not okSp and not State.space.err then State.space.err = true; warnRG("espaco:", errSp) end
		api.syncSolid(S)
		if api.canopyBtn then
			local want = (S.canopyAng > CANOPY_OPEN * 0.5) and "FECHAR" or "ABRIR"
			if api.canopyBtn.Text ~= want then api.canopyBtn.Text = want end
		end
		if S.state == "flying" then
			if S.mode == "ground" then groundStep(S, dt) else flightStep(S, dt) end
		elseif S.state == "landed" then
			proximity(S)
		else
			api.nearShip = false
		end
		boardBtn.Visible = false
		api.padSync(S)
	end

	local function smooth01(x)
		x = math.clamp(x, 0, 1)
		return x * x * (3 - 2 * x)
	end

	local function buildPath(pts, perSeg)
		local n = #pts
		local function cr(i, u)
			local p0 = pts[math.max(i - 1, 1)]
			local p1 = pts[i]
			local p2 = pts[math.min(i + 1, n)]
			local p3 = pts[math.min(i + 2, n)]
			local u2, u3 = u * u, u * u * u
			return ((p1 * 2) + (p2 - p0) * u + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * u2 + (p1 * 3 - p0 - p2 * 3 + p3) * u3) * 0.5
		end
		local pos, len = {}, { 0 }
		for i = 1, n - 1 do
			for k = 0, perSeg - 1 do
				pos[#pos + 1] = cr(i, k / perSeg)
			end
		end
		pos[#pos + 1] = pts[n]
		local total = 0
		for i = 2, #pos do
			total = total + (pos[i] - pos[i - 1]).Magnitude
			len[i] = total
		end
		return pos, len, total
	end

	local function pathAt(pos, len, total, d)
		d = math.clamp(d, 0, total)
		local lo, hi = 1, #len
		while hi - lo > 1 do
			local mid = (lo + hi) // 2
			if len[mid] <= d then lo = mid else hi = mid end
		end
		local seg = len[hi] - len[lo]
		local f = seg > 1e-6 and (d - len[lo]) / seg or 0
		return pos[lo]:Lerp(pos[hi], f)
	end

	local function rollFrame(S, dt, newXZ, yawGoal)
		local old = S.pos
		local hv = Vector3.new(newXZ.X - old.X, 0, newXZ.Z - old.Z) / math.max(dt, 1 / 240)
		local g, gn = groundAt(Vector3.new(newXZ.X, old.Y, newXZ.Z), 6 * SCALE)
		local y = old.Y
		local grounded = false
		if g then
			y = y + (g.Y + LEG_H - y) * (1 - math.exp(-18 * dt))
			grounded = true
		end
		S.pos = Vector3.new(newXZ.X, y, newXZ.Z)
		S.vel = hv
		S.yaw = S.yaw + wrapAng(yawGoal - S.yaw) * (1 - math.exp(-8 * dt))
		S.steer = (S.steer or 0) * math.exp(-10 * dt)

		local tPitch, tRoll = 0, 0
		if grounded and gn then
			local f = Vector3.new(-math.sin(S.yaw), 0, -math.cos(S.yaw))
			local r = Vector3.new(math.cos(S.yaw), 0, -math.sin(S.yaw))
			tPitch = math.clamp(math.atan2(-gn:Dot(f), gn.Y), -0.5, 0.5)
			tRoll = math.clamp(math.atan2(-gn:Dot(r), gn.Y), -0.5, 0.5)
		end
		S.pitch = S.pitch + (tPitch - S.pitch) * (1 - math.exp(-6 * dt))
		S.roll = S.roll + (tRoll - S.roll) * (1 - math.exp(-6 * dt))

		local fwd = Vector3.new(-math.sin(S.yaw), 0, -math.cos(S.yaw))
		local acc = (hv - (S.prevHv or hv)) / math.max(dt, 1 / 120)
		S.prevHv = hv
		local lonT = math.clamp(acc:Dot(fwd) / 70, -1, 1)
		S.latN = 0
		S.lonN = (S.lonN or 0) + (lonT - (S.lonN or 0)) * (1 - math.exp(-10 * dt))
		local LK, LC = 70, 2 * 0.36 * math.sqrt(70)
		if S.landImpact then S.leanPV = S.leanPV + math.clamp(S.landImpact * 0.008, -0.7, 0) end
		S.leanPV = S.leanPV + (LK * (lonT * 0.09 - S.leanP) - LC * S.leanPV) * dt
		S.leanP = S.leanP + S.leanPV * dt
		S.leanRV = S.leanRV + (LK * (0 - S.leanR) - LC * S.leanRV) * dt
		S.leanR = S.leanR + S.leanRV * dt

		S.cf = CFrame.new(S.pos) * CFrame.Angles(0, S.yaw, 0) * CFrame.Angles(S.pitch + S.leanP, 0, S.roll + S.leanR)

		S.suspAcc = (S.suspAcc or 0) + dt
		if S.suspAcc >= (1 / 30) then
			local sdt = S.suspAcc
			S.suspAcc = 0
			suspStep(S, sdt, grounded, hv.Magnitude, GROUND_SPEED)
		end

		S.spinDist = S.spinDist + hv:Dot(fwd) * dt
		place(S)
		setThrust(S, 0)
		if S.dust then S.dust.Rate = (grounded and hv.Magnitude > 4) and math.clamp(hv.Magnitude * 0.7, 0, 46) or 0 end
	end

	local ROUTES = {
		{ nome = "volta larga" },
		{ nome = "volta ampla", k = 1.2, hs = 1.25 },
		{ nome = "volta fechada", k = 0.88, hs = 0.85 },
		{ nome = "volta alta", k = 1.0, hs = 1.4 },
	}

	local ROUTE_PORTAL = { -50, -70, 56 }
	local LOOP_R = 70
	local LOOP_H = { 64, 68, 72, 72, 68, 62, 54, 44, 34, 22 }
	local function loopMid(R, hs)
		local function Y(v) return 8 + (v - 8) * hs end

		local mid = {
			{ -50, -48 + (R + 48) / 3, Y(60) },
			{ -50, -48 + 2 * (R + 48) / 3, Y(62) },
		}
		for n = 0, 12 do
			local th = n * 22.5
			local idx = th / 30
			local lo = math.floor(idx)
			local hi = math.min(lo + 1, 9)
			local y = LOOP_H[lo + 1] + (LOOP_H[hi + 1] - LOOP_H[lo + 1]) * (idx - lo)
			local rad = math.rad(th)
			mid[#mid + 1] = { -50 - R + R * math.cos(rad), R + R * math.sin(rad), Y(y) }
		end
		mid[#mid + 1] = { -80, 0, Y(15) }
		return mid
	end

	local ENDINGS = {

		{ nome = "reta", w = 3, speedK = 1, driveK = 1 },
		{ nome = "derrapada leve", w = 2, speedK = 2.0, driveK = 1.7, ang = 0.38, rise = 0.18, pow = 1.6, dust = 30, kick = 0.9 },
		{ nome = "derrapada forte", w = 1, speedK = 2.6, driveK = 2.1, ang = 0.85, rise = 0.12, pow = 1.3, dust = 60, kick = 1.8, burst = true },
		{ nome = "pendulo", w = 1, speedK = 2.2, driveK = 1.9, ang = 0.6, swing = true, dust = 26, kick = 1.1 },
		{ nome = "freada brusca", w = 1, speedK = 2.4, driveK = 1.8, brake = 0.7, dust = 46 },
	}
	local lastRoute, lastEnding

	local function pickWeighted(list, last)
		local total = 0
		for i, it in ipairs(list) do
			if i ~= last then total = total + (it.w or 1) end
		end
		local r = math.random() * total
		for i, it in ipairs(list) do
			if i ~= last then
				r = r - (it.w or 1)
				if r <= 0 then return i end
			end
		end
		return (last == 1) and 2 or 1
	end

	local function endingYaw(ev, a)
		if ev.swing then return ev.ang * math.sin(a * math.pi * 2) * (1 - a) end
		if ev.ang then return ev.ang * smooth01(a / ev.rise) * (math.max(1 - a, 0) ^ ev.pow) end
		return 0
	end

	local function wheelDust(S)
		for _, w in pairs(S.wheels) do
			local c = S.cf * CFrame.new(w.rel)
			dustAt(c.Position - Vector3.new(0, w.r, 0))
		end
	end

	local LAMP_ON = Color3.fromRGB(255, 246, 200)
	local LAMP_OFF = Color3.fromRGB(110, 108, 96)
	local function lampsSet(S, on)
		for _, L in ipairs(S.lamps or {}) do
			if L.lens and L.lens.part then
				L.lens.part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
				L.lens.part.Color = on and LAMP_ON or LAMP_OFF
			end
			if L.light then L.light.Enabled = on end
		end
	end

	local function runSummon(plan)

		local h = Vector3.new(-math.sin(plan.yaw), 0, -math.cos(plan.yaw))
		local r = h:Cross(Vector3.yAxis)

		local endIdx = (C.ShipArriveEnding and ENDINGS[C.ShipArriveEnding]) and C.ShipArriveEnding or pickWeighted(ENDINGS, lastEnding)
		lastEnding = endIdx
		local ev = ENDINGS[endIdx]
		local drive = (C.ShipArriveDrive or 46) * (ev.driveK or 1)
		do
			local back = castDir(plan.landPos + Vector3.new(0, 1.5 * SCALE, 0), -h * (drive + 14 * SCALE))
			if back then
				drive = math.clamp((back.Position - plan.landPos).Magnitude - 14 * SCALE, 0, drive)
			end
		end
		local T = plan.landPos
		for _, d in ipairs({ drive, drive * 0.7, drive * 0.4, 0 }) do
			local xz = plan.landPos - h * d
			local g = groundAt(Vector3.new(xz.X, plan.landPos.Y + 4, xz.Z), 0)
			if g or d == 0 then
				drive = d
				T = g and Vector3.new(xz.X, g.Y + LEG_H, xz.Z) or xz
				break
			end
		end

		local sd = (math.random() < 0.5) and 1 or -1
		local function W(a, b, y)
			return T + h * (a * SCALE) + r * (b * sd * SCALE) + Vector3.yAxis * (y * SCALE)
		end

		local exitDir = r * sd
		local routeIdx = (C.ShipArriveRoute and ROUTES[C.ShipArriveRoute]) and C.ShipArriveRoute or pickWeighted(ROUTES, lastRoute)
		lastRoute = routeIdx
		local rt = ROUTES[routeIdx]
		local portalPos = W(ROUTE_PORTAL[1], ROUTE_PORTAL[2], ROUTE_PORTAL[3])
		local portalCF = CFrame.lookAt(portalPos, portalPos + exitDir)
		local portal = openSky(portalCF, C.ShipArrivePortalSize or Vector3.new(46, 46, 0.2))
		task.wait(1.1)
		if destroyed or not Z.alive then
			closeSky(portal)
			return
		end

		local function mkPts(r)
			local list = { W(ROUTE_PORTAL[1], ROUTE_PORTAL[2] - 14, ROUTE_PORTAL[3]), W(ROUTE_PORTAL[1], ROUTE_PORTAL[2] + 22, ROUTE_PORTAL[3] + 1) }
			for _, m in ipairs(loopMid(LOOP_R * (r.k or 1), r.hs or 1)) do
				list[#list + 1] = W(m[1], m[2], m[3])
			end
			list[#list + 1] = W(-48, 0, 8)
			list[#list + 1] = W(-16, 0, 1.2)
			list[#list + 1] = W(0, 0, 0)
			return list
		end
		local pos, len, total = buildPath(mkPts(rt), 28)
		local _, _, refTotal = buildPath(mkPts(ROUTES[1]), 28)
		local vS0 = (C.ShipArriveStartSpeed or 240) * SCALE
		local vE0 = (C.ShipArriveEndSpeed or 44) * SCALE
		local vE = vE0 * (ev.speedK or 1)

		local flightT = 2 * refTotal / (vS0 + vE0)
		local vS = math.max(2 * total / flightT - vE, vE * 1.3)
		flightT = 2 * total / (vS + vE)

		local S = buildShip()
		S.state = "arriving"
		S.gear = 0
		S.canopyAng = 0
		lampsSet(S, false)
		S.pos = pos[1]
		S.yaw = math.atan2(-exitDir.X, -exitDir.Z)
		S.pitch, S.roll = 0, 0
		S.cf = CFrame.new(S.pos) * CFrame.Angles(0, S.yaw, 0)
		snap(S)
		S.model.Parent = workspace
		ship = S

		local function tanAt(d, w)
			local t = pathAt(pos, len, total, d + w) - pathAt(pos, len, total, d - w)
			if t.Magnitude < 1e-3 then return S.cf.LookVector end
			return t.Unit
		end

		local lastClk = os.clock()
		local portalClosed, boomed = false, false
		animate(flightT, function(_, a)
			local now = os.clock()
			local dt = math.clamp(now - lastClk, 1 / 240, 0.1)
			lastClk = now

			local tau = a * flightT
			local dist = vS * tau + 0.5 * (vE - vS) / flightT * tau * tau
			local f = dist / total
			local speed = vS + (vE - vS) * a
			local p = pathAt(pos, len, total, dist)
			local win = 9 * SCALE + speed * 0.05
			local tan = tanAt(dist, win)

			local tanLead = tanAt(dist + speed * 0.1, win)
			local yawGoal = math.atan2(-tanLead.X, -tanLead.Z)
			S.yaw = S.yaw + wrapAng(yawGoal - S.yaw) * (1 - math.exp(-8 * dt))
			local flare = smooth01((f - 0.78) / 0.22)
			local hm = Vector3.new(tanLead.X, 0, tanLead.Z).Magnitude
			local pitchGoal = math.atan2(tanLead.Y, hm) + 0.17 * flare
			S.pitch = S.pitch + (pitchGoal - S.pitch) * (1 - math.exp(-5 * dt))

			local look = 22 * SCALE + speed * 0.12
			local tanFar = tanAt(dist + look, win)
			local yawFar = math.atan2(-tanFar.X, -tanFar.Z)
			local yawNear = math.atan2(-tan.X, -tan.Z)
			local turn = wrapAng(yawFar - yawNear) / look * speed
			local bank = math.clamp(turn * 0.38, -0.85, 0.85) * (1 - flare)
			S.roll = S.roll + (bank - S.roll) * (1 - math.exp(-4.5 * dt))
			local barrel = -sd * math.pi * 2 * smooth01((f - 0.16) / 0.15)
			local wob = math.sin(a * 9) * 0.025 * (1 - flare)
			S.pos = p + Vector3.new(0, math.sin(a * 7) * 0.4 * SCALE * (1 - flare), 0)
			S.cf = CFrame.new(S.pos) * CFrame.Angles(0, S.yaw, 0)
				* CFrame.Angles(S.pitch, 0, S.roll + barrel + wob)

			S.gear = smooth01((f - 0.62) / 0.2)
			S.turbo = speed > 130 * SCALE
			setThrust(S, math.clamp(speed / (160 * SCALE), 0.3, 1))
			shake(S, math.clamp((speed - 110 * SCALE) / 150, 0, 1) * 0.2 * SCALE)
			place(S)

			if not boomed and dist > 14 * SCALE then
				boomed = true
				ctx.flashAt(portalPos, 4)
				ctx.playSound(C.SoundTeleport, 1.1)
				wobbleSky(portal, true)
			end
			if not portalClosed and dist > 90 * SCALE then
				portalClosed = true
				closeSky(portal)
			end
			if S.dust then S.dust.Rate = (f > 0.93) and 24 or 0 end
		end, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
		if gone(S) then
			closeSky(portal)
			return
		end
		if not portalClosed then closeSky(portal) end
		shake(S, 0)
		S.turbo = false

		S.gear = 1
		S.pos = T
		S.yaw = math.atan2(-h.X, -h.Z)
		S.vel = h * vE
		S.prevHv = S.vel
		S.landImpact = -45
		setThrust(S, 0)
		for _, w in pairs(S.wheels) do
			local c = S.cf * CFrame.new(w.rel)
			dustAt(c.Position - Vector3.new(0, w.r, 0))
		end
		ctx.flashAt(T - Vector3.new(0, LEG_H - 1, 0), 2.2)
		ctx.playSound(C.SoundLand, 1.2)
		task.spawn(function()
			for _, on in ipairs({ true, false, true, false, true }) do
				if not (S.model and S.model.Parent) then return end
				pcall(lampsSet, S, on)
				task.wait(0.09)
			end
		end)

		local dsd = (math.random() < 0.5) and 1 or -1
		local brakeK = ev.brake and (ev.brake + 0.5 * (1 - ev.brake)) or 1
		local driveT
		if drive > 2 then
			driveT = ev.brake and (drive / (vE * brakeK)) or (2 * drive / vE)
		else
			driveT = 0.01
		end
		local function distFrac(a, e)
			if not ev.brake then return e end

			if a <= ev.brake then return a / brakeK end
			local u = a - ev.brake
			return (ev.brake + u - 0.5 * u * u / (1 - ev.brake)) / brakeK
		end
		local from = Vector3.new(T.X, 0, T.Z)
		local yawGoal = math.atan2(-h.X, -h.Z)
		local kick1, kick2, burst, braked = false, false, false, false
		lastClk = os.clock()
		animate(driveT, function(e, a)
			local now = os.clock()
			local dt = math.clamp(now - lastClk, 1 / 240, 0.1)
			lastClk = now
			local q = from + h * (drive * distFrac(a, e))
			rollFrame(S, dt, q, yawGoal + dsd * endingYaw(ev, a))

			if ev.kick then

				if not kick1 and a >= 0.05 then kick1 = true; S.leanRV = S.leanRV - dsd * ev.kick end
				if ev.swing and not kick2 and a >= 0.5 then kick2 = true; S.leanRV = S.leanRV + dsd * ev.kick * 2 end
			end
			if ev.burst and not burst and a >= 0.06 then burst = true; wheelDust(S) end
			if ev.brake and not braked and a >= ev.brake then
				braked = true
				S.leanPV = S.leanPV - 0.8
				wheelDust(S)
			end
			if S.dust and ev.dust then
				if ev.brake then
					if braked then S.dust.Rate = ev.dust * (1 - a) end
				else
					S.dust.Rate = math.max(S.dust.Rate, ev.dust * (1 - a))
				end
			end
		end, ev.brake and Enum.EasingStyle.Linear or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		if gone(S) then return end

		local stop = Vector3.new(S.pos.X, 0, S.pos.Z)
		lastClk = os.clock()
		animate(0.8, function()
			local now = os.clock()
			local dt = math.clamp(now - lastClk, 1 / 240, 0.1)
			lastClk = now
			rollFrame(S, dt, stop, yawGoal)
		end)
		if gone(S) then return end
		if S.dust then S.dust.Rate = 0 end

		task.wait(0.3)
		if gone(S) then return end
		animate(0.8, function(e)
			S.canopyAng = CANOPY_OPEN * e
			place(S)
		end)
		if gone(S) then return end
		S.state = "landed"
		toast("Nave pronta! Chegue perto (ou toque em PILOTAR) pra entrar.", 4)
	end

	local function runDismiss(S, plan)
		S.state = "leaving"
		local h = Vector3.new(-math.sin(S.yaw), 0, -math.cos(S.yaw))
		local up = Vector3.yAxis

		local ca0 = S.canopyAng
		animate(0.9, function(e)
			S.canopyAng = ca0 * (1 - e)
			place(S)
		end)
		if gone(S) then return end
		task.wait(0.15)
		if gone(S) then return end

		local P = S.pos
		local roll = 60
		do
			local hit = castDir(P + Vector3.new(0, 1.5 * SCALE, 0), h * (roll + 16 * SCALE))
			if hit then roll = math.clamp((hit.Position - P).Magnitude - 16 * SCALE, 6, roll) end
		end

		local earlyCF, earlyPortal
		do
			local pEnd = P + h * (roll + 215 * SCALE) + up * (84 * SCALE)
			local tn = (h * 35 + up * 14).Unit
			local cf0 = CFrame.lookAt(pEnd, pEnd + tn)
			local okRG, errRG = pcall(function()
				if not State.shipRearInit(S) then return end

				animate(0.55, function(e) State.shipRearDoor(S, 2.0 * e); place(S) end)
				if gone(S) then return end

				local muz = State.shipRearArm(S, 0, 0, nil, 0)
				animate(0.6, function(e) muz = State.shipRearArm(S, e, 0, nil, 0); place(S) end)
				if gone(S) then return end

				local aim = nil
				animate(0.45, function(e)
					aim = S.cf:VectorToObjectSpace((cf0.Position - S.cf * muz))
					muz = State.shipRearArm(S, 1, e, aim, 0)
					place(S)
				end)
				if gone(S) then return end

				local startW = S.cf * muz
				ctx.playSound(C.SoundShoot, 0.9)
				ctx.flashAt(startW, 1.6)
				local orb = Instance.new("Part")
				orb.Shape = Enum.PartType.Ball
				orb.Size = Vector3.one * (1.1 * SCALE)
				orb.Anchored, orb.CanCollide, orb.CanQuery, orb.CanTouch = true, false, false, false
				orb.Material, orb.Color = Enum.Material.Neon, C.PortalColor
				orb.Position = startW
				local pl = Instance.new("PointLight")
				pl.Color, pl.Range, pl.Brightness = C.PortalColor, 14, 3
				pl.Parent = orb
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Position, a1.Position = Vector3.new(0, 0.5 * SCALE, 0), Vector3.new(0, -0.5 * SCALE, 0)
				a0.Parent, a1.Parent = orb, orb
				local tr = Instance.new("Trail")
				tr.Attachment0, tr.Attachment1 = a0, a1
				tr.Lifetime = 0.35
				tr.LightEmission = 1
				tr.Color = ColorSequence.new(C.PortalColor)
				tr.Transparency = NumberSequence.new(0, 1)
				tr.Parent = orb
				orb.Parent = workspace
				animate(0.55, function(_, a)
					orb.Position = startW:Lerp(cf0.Position, a)
					State.shipRearArm(S, 1, 1, aim, math.max(0, 1 - a * 6))
					place(S)
				end, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
				orb:Destroy()
				if gone(S) then return end
				earlyPortal = openSky(cf0, C.ShipLeavePortalSize or Vector3.new(46, 46, 0.2))
				earlyCF = cf0
				ctx.flashAt(cf0.Position, 4)

				animate(0.5, function(e) State.shipRearArm(S, 1 - e, 1 - e, aim, 0); place(S) end)
				State.shipRearArm(S, 0, 0, nil, 0)
				if gone(S) then return end
				animate(0.5, function(e) State.shipRearDoor(S, 2.0 * (1 - e)); place(S) end)
				State.shipRearDoor(S, 0)
			end)
			if not okRG then
				warnRG("braco do canhao:", errRG)
				pcall(State.shipRearArm, S, 0, 0, nil, 0)
				pcall(State.shipRearDoor, S, 0)
			end
		end
		if gone(S) then
			closeSky(earlyPortal)
			return
		end

		local v1 = 105 * SCALE
		local rollT = 2 * roll / v1
		local from = Vector3.new(P.X, 0, P.Z)
		local lastClk = os.clock()
		S.prevHv = Vector3.zero
		animate(rollT, function(_, a)
			local now = os.clock()
			local dt = math.clamp(now - lastClk, 1 / 240, 0.1)
			lastClk = now
			rollFrame(S, dt, from + h * (roll * a * a), S.yaw)
			S.turbo = a > 0.7
			setThrust(S, 0.3 + 0.7 * a)
			shake(S, 0.14 * SCALE * a)
		end, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
		if gone(S) then return end

		local P2 = S.pos
		local function W(a, y) return P2 + h * (a * SCALE) + up * (y * SCALE) end
		local pts = { P2, W(10, 0.2), W(28, 2.5), W(55, 11), W(90, 28), W(135, 50), W(180, 70), W(215, 84) }
		if earlyCF then pts[#pts] = earlyCF.Position end
		local pos, len, total = buildPath(pts, 24)
		local vE = 200 * SCALE
		local flightT = 2 * total / (v1 + vE)
		local portalPos = pts[#pts]
		local endTan = (pts[#pts] - pts[#pts - 1]).Unit
		local portalCF = CFrame.lookAt(portalPos, portalPos + endTan)
		local portal = earlyPortal
		if S.dust then S.dust.Rate = 0 end

		lastClk = os.clock()
		animate(flightT, function(_, a)
			local now = os.clock()
			local dt = math.clamp(now - lastClk, 1 / 240, 0.1)
			lastClk = now

			local tau = a * flightT
			local dist = v1 * tau + 0.5 * (vE - v1) / flightT * tau * tau
			local f = math.clamp(dist / total, 0, 1)
			local speed = v1 + (vE - v1) * a
			local p = pathAt(pos, len, total, dist)
			local tan = pathAt(pos, len, total, dist + 4) - pathAt(pos, len, total, dist - 4)
			if tan.Magnitude < 1e-3 then tan = h end
			tan = tan.Unit

			local hm = Vector3.new(tan.X, 0, tan.Z).Magnitude
			S.pitch = S.pitch + (math.atan2(tan.Y, hm) - S.pitch) * (1 - math.exp(-7 * dt))
			local k = math.exp(-5 * dt)
			S.leanP, S.leanPV, S.roll = S.leanP * k, S.leanPV * k, S.roll * k
			S.leanR, S.leanRV = S.leanR * k, S.leanRV * k

			local g = groundAt(p, 6 * SCALE)
			if g then
				local minY = g.Y + LEG_H * (0.5 + 0.5 * S.gear)
				if p.Y < minY then p = Vector3.new(p.X, minY, p.Z) end
			end

			S.pos = p
			S.cf = CFrame.new(p) * CFrame.Angles(0, S.yaw, 0) * CFrame.Angles(S.pitch + S.leanP, 0, S.roll + S.leanR)
			S.gear = 1 - smooth01((f - 0.06) / 0.14)
			S.spinDist = S.spinDist + speed * dt
			S.vel = tan * speed
			S.turbo = speed > 130 * SCALE
			place(S)
			setThrust(S, math.clamp(0.7 + 0.3 * a, 0.3, 1))
			shake(S, math.clamp((speed - 100 * SCALE) / 150, 0, 1) * 0.2 * SCALE)

			if not portal and f >= 0.08 then
				portal = openSky(portalCF, C.ShipLeavePortalSize or Vector3.new(46, 46, 0.2))
			end
		end, Enum.EasingStyle.Linear, Enum.EasingDirection.In)

		shake(S, 0)
		S.turbo = false
		if gone(S) then
			closeSky(portal)
			return
		end

		ctx.playSound(C.SoundTeleport, 1.1)
		wobbleSky(portal, false)
		local passDist = 46 * SCALE
		animate(passDist / vE, function(_, a)
			local p = portalPos + endTan * (passDist * a)
			S.pos = p
			S.cf = CFrame.new(p) * CFrame.Angles(0, S.yaw, 0) * CFrame.Angles(S.pitch, 0, S.roll)
			S.gear = 0
			place(S)
			setThrust(S, 1)
		end, Enum.EasingStyle.Linear, Enum.EasingDirection.In)

		removeShip()
		pcall(ctx.flashAt, portalPos, 4)
		task.wait(0.25)
		closeSky(portal)
	end

	api.inShip = inShip

	local function mkPlan(t)
		t.started = false
		task.delay(8, function()
			if not t.started then busy = false end
		end)
		return t
	end

	function api.plan()
		if destroyed or busy or inShip() then return nil end
		if ship then
			if ship.state ~= "landed" then return nil end
			busy = true
			return mkPlan({
				mode = "dismiss",
				portalCF = skyCF(ship.pos + Vector3.new(0, PORTAL_H, 0), ship.cf.RightVector),
			})
		end

		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.05 then
			local rl = rootPart.CFrame.LookVector
			flat = Vector3.new(rl.X, 0, rl.Z)
		end
		if flat.Magnitude < 0.05 then flat = Vector3.new(0, 0, -1) end
		flat = flat.Unit

		local xz = rootPart.Position + flat * LAND_DIST
		local ground = groundAt(Vector3.new(xz.X, rootPart.Position.Y + 4, xz.Z), 0)
		local gy = ground and ground.Y or (rootPart.Position.Y - 3)
		local landPos = Vector3.new(xz.X, gy + LEG_H, xz.Z)
		busy = true
		return mkPlan({
			mode = "summon",
			landPos = landPos,
			yaw = math.atan2(flat.X, flat.Z),
			portalCF = skyCF(landPos + Vector3.new(0, PORTAL_H, 0), Vector3.new(-flat.Z, 0, flat.X)),
		})
	end

	function api.execute(plan)
		plan.started = true
		task.spawn(function()
			local ok, err = pcall(function()
				if plan.mode == "dismiss" then
					if ship then runDismiss(ship, plan) end
				else
					runSummon(plan)
				end
			end)
			if not ok then
				warnRG("erro na nave do Rick:", err)
				removeShip()
			end
			busy = false
		end)
	end

	function api.board(manual)
		local S = ship
		if destroyed or not S or busy or S.state ~= "landed" then return end
		if humanoid.Health <= 0 or humanoid.SeatPart then return end
		busy = true
		S.state = "boarding"
		boardBtn.Visible = false
		task.spawn(function()
			local ok, err = pcall(function()
				if ctx.hasPortals() then ctx.closeAllPortals() end
				pcall(function() humanoid:UnequipTools() end)

				savedCollide = {}
				for _, p in ipairs(character:GetDescendants()) do
					if p:IsA("BasePart") then
						savedCollide[p] = p.CanCollide
						p.CanCollide = false
					end
				end
				savedJump = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
				savedAutoRotate = humanoid.AutoRotate
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
				humanoid.AutoRotate = false
				humanoid.Sit = true

				local from = rootPart.CFrame
				animate(manual and 0.25 or 0.7, function(e)
					local to = S.cf * SEAT_REL
					local pos = from.Position:Lerp(to.Position, e) + Vector3.new(0, math.sin(e * math.pi) * (manual and 0.4 or 4), 0)
					rootPart.CFrame = CFrame.new(pos) * to.Rotation
					rootPart.AssemblyLinearVelocity = Vector3.zero
					if not humanoid.Sit then humanoid.Sit = true end
				end, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				if gone(S) then return end

				local ca0 = S.canopyAng
				animate(0.6, function(e)
					S.canopyAng = ca0 * (1 - e)
					place(S)
					holdChar(S)
				end)
				S.canopyAng = 0
				place(S)
				if gone(S) then return end

				S.vel = Vector3.zero
				S.vy = 0
				S.pos = S.cf.Position
				S.pitch, S.roll, S.yawRate = 0, 0, 0
				S.mode = S.mode or "ground"
				refreshHud(S)
				baseFov = camera.FieldOfView
				pcall(function()
					savedZoom = { player.CameraMinZoomDistance, player.CameraMaxZoomDistance }
					player.CameraMaxZoomDistance = math.max(player.CameraMaxZoomDistance, 60 * SCALE)
					player.CameraMinZoomDistance = 32 * SCALE
				end)
				bindSink()
				pad.Visible = true
				infoLbl.Visible = true
				S.state = "flying"
				toast("WASD/analógico dirigem · R troca TERRA/VOO · B freio de mão (drift) · ESPAÇO sobe · CTRL desce · SHIFT turbo · F sai", 6)
			end)
			if not ok then
				warnRG("erro ao embarcar na nave:", err)
				restoreChar()
				pcall(function() humanoid.Sit = false end)
				if ship == S then S.state = "landed" end
			end
			busy = false
		end)
	end

	local function descend(S, ground, keep)
		local startPos = S.pos
		local endPos = Vector3.new(startPos.X, ground.Y + LEG_H, startPos.Z)
		local p0, r0 = S.pitch, S.roll
		local dist = math.max(startPos.Y - endPos.Y, 0)
		local dur = math.clamp(0.9 + dist / 110, 0.9, 4.5)
		local lastT, tgtY = os.clock(), endPos.Y
		if not keep then S.vel = Vector3.zero; S.turbo = false end

		animate(dur, function(e, a)
			if keep then

				local now = os.clock()
				local dtg = math.min(now - lastT, 0.1)
				lastT = now
				api.glide(S, dtg)
				local g = groundAt(S.pos, 0)
				if g then tgtY = g.Y + LEG_H end
				S.pos = Vector3.new(S.pos.X, startPos.Y + (tgtY - startPos.Y) * e, S.pos.Z)
			else
				S.pos = startPos:Lerp(endPos, e)
			end
			S.pitch = p0 * (1 - e)
			S.roll = r0 * (1 - e)
			S.gear = math.clamp((a - 0.4) / 0.5, 0, 1)
			S.cf = CFrame.new(S.pos) * CFrame.Angles(0, S.yaw, 0) * CFrame.Angles(S.pitch, 0, S.roll)
			place(S)
			setThrust(S, 1 - e)
			holdChar(S)
		end, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		if gone(S) then return false end

		if keep then endPos = Vector3.new(S.pos.X, tgtY, S.pos.Z) end
		S.pos, S.pitch, S.roll, S.gear = endPos, 0, 0, 1
		S.cf = CFrame.new(S.pos) * CFrame.Angles(0, S.yaw, 0)
		place(S)
		setThrust(S, 0)
		local floorPos = endPos - Vector3.new(0, LEG_H, 0)
		dustAt(floorPos)
		ctx.flashAt(floorPos + Vector3.new(0, 1, 0), 1.6)
		return true
	end

	function api.toggleCloseView()
		if not (ship and ship.state == "flying") then return end
		held.closeView = not held.closeView
		pcall(function()
			if held.closeView then
				player.CameraMinZoomDistance = 0.6
				player.CameraMaxZoomDistance = 9 * SCALE
			else
				player.CameraMaxZoomDistance = math.max(player.CameraMaxZoomDistance, 60 * SCALE)
				player.CameraMinZoomDistance = 32 * SCALE
			end
		end)
	end

	function api.toggleMode()
		local S = ship
		if destroyed or not S or busy or S.state ~= "flying" then return end
		if S.mode == "ground" then
			if S.vy < -5 then S.refuseT = os.clock(); return end
			busy = true
			S.shiftTo = "fly"
			S.state = "shifting"
			task.spawn(function()
				local ok, err = pcall(function()
					local y0 = S.pos.Y
					local p0, r0 = S.pitch, S.roll
					local lastT = os.clock()
					if S.dust then S.dust.Rate = 0 end
					dustAt(S.pos - Vector3.new(0, LEG_H, 0))
					animate(1.1, function(e)
						S.gear = 1 - e
						local now = os.clock()
						local dtg = math.min(now - lastT, 0.1)
						lastT = now
						api.glide(S, dtg)
						S.pos = Vector3.new(S.pos.X, y0 + 7 * SCALE * e, S.pos.Z)
						S.pitch = p0 * (1 - e)
						S.roll = r0 * (1 - e)
						S.cf = CFrame.new(S.pos) * CFrame.Angles(0, S.yaw, 0) * CFrame.Angles(S.pitch, 0, S.roll)
						place(S)
						setThrust(S, 0.3 + 0.7 * e)
						holdChar(S)
					end, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
					if gone(S) then return end
					S.gear = 0
					S.mode = "fly"
					S.state = "flying"
					refreshHud(S)
					toast("MODO VOO", 2)
				end)
				if not ok then
					warnRG("erro ao trocar pro modo voo:", err)
					if ship == S then S.mode = "fly"; S.state = "flying"; refreshHud(S) end
				end
				busy = false
			end)
		else
			local ground = groundAt(S.pos, 0)
			if not ground then
				toast("Sem chão embaixo pra pousar. Voe até algum lugar com chão!", 3)
				S.refuseT = os.clock()
				return
			end
			busy = true
			S.shiftTo = "ground"
			S.state = "shifting"
			task.spawn(function()
				local ok, err = pcall(function()
					if not descend(S, ground, true) then return end
					S.mode = "ground"
					S.vy = 0
					S.state = "flying"
					refreshHud(S)
					toast("MODO TERRA", 2)
				end)
				if not ok then
					warnRG("erro ao trocar pro modo terra:", err)
					if ship == S then S.mode = "ground"; S.gear = 1; S.state = "flying"; refreshHud(S) end
				end
				busy = false
			end)
		end
	end

	function api.syncSolid(S)
		if C.ShipSolid == false or not S.solidParts then return end
		local on = S.state == "landed"
		if S.solidOn ~= on then
			S.solidOn = on
			for _, p in ipairs(S.solidParts) do
				if p.Parent then p.CanCollide = on; p.CanQuery = on end
			end
		end
		local domeOn = false
		if on and S.canopyAng <= 0.001 then
			local rel = S.cf:PointToObjectSpace(rootPart.Position)
			local inside = Vector3.new(rel.X, 0, rel.Z).Magnitude < 7.4 * SCALE and rel.Y > 1.5 * SCALE and rel.Y < 14 * SCALE
			domeOn = not inside
		end
		if S.domeOn ~= domeOn then
			S.domeOn = domeOn
			for _, p in ipairs(S.domeSolid) do
				if p.Parent then p.CanCollide = domeOn; p.CanQuery = domeOn end
			end
		end
	end

	function api.padSync(S)
		local flyingNow = S ~= nil and (S.state == "flying" or S.state == "shifting")
		local show = flyingNow or (S ~= nil and S.state == "landed" and api.nearShip == true)
		if pad.Visible ~= show then pad.Visible = show end
		if api.padFly ~= flyingNow then
			api.padFly = flyingNow
			for _, c in ipairs(pad:GetChildren()) do
				if c:IsA("TextButton") and c.Name ~= "BtnCanopy" then c.Visible = flyingNow end
			end
		end
	end

	function api.toggleCanopy()
		local S = ship
		if destroyed or not S or S.canopyBusy then return end
		if S.state ~= "landed" and S.state ~= "flying" then return end
		if S.state == "flying" and busy then return end
		local a0 = S.canopyAng
		local target = (a0 > CANOPY_OPEN * 0.5) and 0 or CANOPY_OPEN
		S.canopyBusy = true
		task.spawn(function()
			local ok, err = pcall(function()
				animate(0.7, function(e)
					S.canopyAng = a0 + (target - a0) * e
					place(S)
				end, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				if not gone(S) then S.canopyAng = target; place(S) end
			end)
			if not ok then warnRG("erro no vidro da nave:", err) end
			S.canopyBusy = false
		end)
	end

	function api.exit()
		local S = ship
		if destroyed or not S or busy or S.state ~= "flying" then return end
		local ground = groundAt(S.pos, 0)
		if S.mode == "fly" and not ground then
			toast("Sem chão embaixo pra pousar. Voe até algum lugar com chão!", 3)
			return
		end
		if S.mode == "ground" and S.vy < -5 then return end
		busy = true
		S.state = "landing"
		task.spawn(function()
			local ok, err = pcall(function()
				if S.mode == "fly" then
					if not descend(S, ground) then return end
					S.mode = "ground"
				else
					S.vel = Vector3.zero
					setThrust(S, 0)
					shake(S, 0)
					if S.dust then S.dust.Rate = 0 end
				end
				local gy = ground and ground.Y or (S.pos.Y - LEG_H)
				pad.Visible = false
				infoLbl.Visible = false
				if baseFov then camera.FieldOfView = baseFov end

				if gone(S) then return end
				local standCF = S.cf * CFrame.new(-2.3 * SCALE, 5.9 * SCALE, -1.8 * SCALE)
				restoreChar()
				rootPart.CFrame = standCF
				rootPart.AssemblyLinearVelocity = Vector3.zero
				humanoid.Sit = false
				pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
				S.needLeave = true
				lastBoard = os.clock() + 1.5
				S.state = "landed"
			end)
			if not ok then
				warnRG("erro ao pousar a nave:", err)
				restoreChar()
				pcall(function() humanoid.Sit = false end)
				if ship == S then S.state = "landed" end
			end
			busy = false
		end)
	end

	function api.onDeath()
		pcall(restoreChar)
		flushJobs()
		removeShip()
		busy = false
	end

	function api.destroy()
		destroyed = true
		pcall(State.spaceStop)
		pcall(function() handConn:Disconnect() end)
		pcall(function()
			if inShip() then humanoid.Sit = false end
		end)
		pcall(restoreChar)
		flushJobs()
		pcall(function() RunService:UnbindFromRenderStep(STEP_ID) end)
		removeShip()
		for _, m in ipairs(skyPortals) do
			pcall(function() m:Destroy() end)
		end
		skyPortals = {}
	end

	pcall(function() RunService:UnbindFromRenderStep(STEP_ID) end)
	RunService:BindToRenderStep(STEP_ID, Enum.RenderPriority.Camera.Value - 2, step)

	ctx.track(UserInputService.InputBegan:Connect(function(input)
		if UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.F then
			api.exit()
		elseif input.KeyCode == Enum.KeyCode.R then
			api.toggleMode()
		elseif input.KeyCode == Enum.KeyCode.G then
			api.toggleCanopy()
		elseif input.KeyCode == Enum.KeyCode.V then
			api.toggleCloseView()
		elseif input.KeyCode == Enum.KeyCode.B then
			held.brake = true
		end
	end))
	ctx.track(UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.B then held.brake = false end
	end))

	return api
end

State.keyTemplate, State.keyAxis, State.keyTried = nil, Vector3.zAxis, false

State.makeFallbackKey = function()
	local L = Config.KeyLength or 1.6
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = Vector3.new(0.22, 0.22, L)
	h.Material = Enum.Material.Neon
	h.Color = Config.PortalColor
	h.Anchored = false
	h.CanCollide = false
	h.CanQuery = false
	h.CanTouch = false
	h.Massless = true
	local function piece(size, off, shape)
		local p = Instance.new("Part")
		p.Size = size
		p.Shape = shape or Enum.PartType.Block
		p.Material = Enum.Material.Neon
		p.Color = Config.PortalColor
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CFrame = h.CFrame * CFrame.new(off)
		local w = Instance.new("WeldConstraint")
		w.Part0 = h
		w.Part1 = p
		w.Parent = p
		p.Parent = h
	end
	piece(Vector3.new(0.7, 0.7, 0.7), Vector3.new(0, 0, -L / 2), Enum.PartType.Ball)
	piece(Vector3.new(0.5, 0.2, 0.2), Vector3.new(0.3, 0, L / 2 - 0.1))
	piece(Vector3.new(0.4, 0.2, 0.2), Vector3.new(0.25, 0, L / 2 - 0.4))
	State.keyAxis = Vector3.zAxis
	return h
end

State.loadKeyTemplate = function()
	if State.keyTried then return State.keyTemplate end
	State.keyTried = true
	local id = Config.KeyAccessoryId
	if id then
		local model, err = fetchAccessoryModel(id)
		if model then
			local h
			if model:IsA("BasePart") then
				h = model
			else
				h = model:FindFirstChild("Handle", true) or model:FindFirstChildWhichIsA("BasePart", true)
			end
			if h then
				local c = h:Clone()
				pcall(function() model:Destroy() end)
				for _, d in ipairs(c:GetDescendants()) do
					if d:IsA("Attachment") or d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Script")
						or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Motor6D") or d:IsA("Sound")

						or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Fire") or d:IsA("Smoke")
						or d:IsA("Sparkles") or d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") or d:IsA("Highlight") then
						d:Destroy()
					end
				end
				c.Name = "Handle"
				c.Anchored = false
				c.CanCollide = false
				c.CanQuery = false
				c.CanTouch = false
				c.Massless = true
				c.CastShadow = true
				local s = c.Size
				local f = (Config.KeyLength or 1.6) / math.max(math.max(s.X, s.Y, s.Z), 0.01)
				c.Size = s * f
				local sm = c:FindFirstChildOfClass("SpecialMesh")
				if sm then sm.Scale = sm.Scale * f end
				local ns = c.Size
				if ns.X >= ns.Y and ns.X >= ns.Z then
					State.keyAxis = Vector3.xAxis
				elseif ns.Y >= ns.Z then
					State.keyAxis = Vector3.yAxis
				else
					State.keyAxis = Vector3.zAxis
				end
				State.keyTemplate = c
				return c
			end
			pcall(function() model:Destroy() end)
			warnRG("Acessorio da chave sem parte Handle. Usando chave simples.")
		else
			warnRG("Nao foi possivel carregar o acessorio da chave " .. tostring(id) .. " (" .. tostring(err) .. "). Usando chave simples.")
		end
	end
	State.keyTemplate = State.makeFallbackKey()
	return State.keyTemplate
end

State.buildKeySystem = function(ctx)
	local Z, humanoid, rootPart, backpack, character = ctx.Z, ctx.humanoid, ctx.rootPart, ctx.backpack, ctx.character
	local C = Config
	local NAME = C.KeyToolName or "Chave da Nave"
	local api = {}

	for _, v in ipairs(backpack:GetChildren()) do
		if v.Name == NAME then pcall(function() v:Destroy() end) end
	end
	local oldInChar = character:FindFirstChild(NAME)
	if oldInChar then pcall(function() oldInChar:Destroy() end) end

	local tpl = State.loadKeyTemplate()
	local tool = Instance.new("Tool")
	tool.Name = NAME
	tool.ToolTip = "Chama a nave do Rick"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	local handle = tpl:Clone()
	handle.Name = "Handle"
	handle.Parent = tool

	local rot = CFrame.new()
	if State.keyAxis == Vector3.xAxis then
		rot = CFrame.Angles(0, math.rad(90), 0)
	elseif State.keyAxis == Vector3.yAxis then
		rot = CFrame.Angles(math.rad(90), 0, 0)
	end
	local e = C.KeyRotation or Vector3.zero
	tool.Grip = CFrame.new(C.KeyGrip or Vector3.zero) * rot
		* CFrame.Angles(math.rad(e.X), math.rad(e.Y), math.rad(e.Z))
	pcall(function() tool.Parent = backpack end)

	local gui = ctx.newGui("RickKeyHotbar", 1)
	local frame = Instance.new("Frame")
	frame.Name = "KeySlotFrame"
	frame.Size = UDim2.fromOffset(38, 40)
	frame.Position = UDim2.new(1, C.KeySlotOffsetX or -142, 1, -72)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local slotBtn = Instance.new("TextButton")
	slotBtn.Name = "Slot_ChaveDaNave"
	slotBtn.Size = UDim2.fromOffset(32, 32)
	slotBtn.Position = UDim2.fromOffset(4, 4)
	slotBtn.BackgroundColor3 = Color3.fromRGB(12, 22, 14)
	slotBtn.BorderSizePixel = 0
	slotBtn.Text = ""
	slotBtn.AutoButtonColor = false
	slotBtn.Parent = frame
	Instance.new("UICorner", slotBtn).CornerRadius = UDim.new(0, 10)
	local slotStroke = Instance.new("UIStroke")
	slotStroke.Thickness = 2
	slotStroke.Parent = slotBtn
	tintStroke(slotStroke, C.PortalColor, true)

	local slotIcon = Instance.new("TextLabel")
	slotIcon.Size = UDim2.fromScale(1, 1)
	slotIcon.BackgroundTransparency = 1
	slotIcon.Text = C.KeyIcon or "🔑"
	slotIcon.TextSize = 18
	slotIcon.Parent = slotBtn

	if C.KeyAccessoryId then
		local img = Instance.new("ImageLabel")
		img.Name = "KeyThumb"
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.new(1, -6, 1, -6)
		img.ScaleType = Enum.ScaleType.Fit
		img.Visible = false
		img.Image = "rbxthumb://type=Asset&id=" .. tostring(C.KeyAccessoryId) .. "&w=150&h=150"
		img.Parent = slotBtn
		task.spawn(function()
			for _ = 1, 24 do
				if not (Z.alive and img.Parent) then return end
				if img.IsLoaded then
					img.Visible = true
					slotIcon.Visible = false
					return
				end
				task.wait(0.25)
			end
		end)
	end

	local selectedFrame = Instance.new("Frame")
	selectedFrame.Size = UDim2.fromScale(1, 1)
	selectedFrame.BackgroundTransparency = 1
	selectedFrame.Visible = false
	selectedFrame.Parent = slotBtn
	local selStroke = Instance.new("UIStroke")
	selStroke.Color = Color3.new(1, 1, 1)
	selStroke.Thickness = 2.5
	selStroke.Parent = selectedFrame
	Instance.new("UICorner", selectedFrame).CornerRadius = UDim.new(0, 10)

	slotBtn.MouseEnter:Connect(function()
		TweenService:Create(slotBtn, TweenInfo.new(0.12), {Size = UDim2.fromOffset(34, 34)}):Play()
	end)
	slotBtn.MouseLeave:Connect(function()
		TweenService:Create(slotBtn, TweenInfo.new(0.12), {Size = UDim2.fromOffset(32, 32)}):Play()
	end)
	slotBtn.MouseButton1Click:Connect(function()
		pcall(function()
			if tool.Parent == character then
				humanoid:UnequipTools()
			else
				humanoid:EquipTool(tool)
			end
		end)
	end)

	local lastUse = 0
	local function use()
		if not Z.alive or humanoid.Health <= 0 then return end
		local sh = State.ship
		if not sh then return end
		if sh.inShip() then
			sh.toast("Saia da nave (F ou botão SAIR) pra usar a chave.", 2.5)
			return
		end
		if os.clock() - lastUse < (C.KeyCooldown or 0.9) then return end
		local plan = sh.plan()
		if not plan then
			sh.toast("A nave está ocupada, espera um pouco.", 2)
			return
		end
		lastUse = os.clock()
		pcall(ctx.closePair)
		pcall(ctx.faceToward, plan.portalCF.Position)
		local from = (handle and handle.Parent) and handle.Position or rootPart.Position
		pcall(function() Z.fala.dizer("nave") end)
		State.mortyEvent("onShot", from)
		pcall(UIAnim.pulse, slotBtn, 1.2)
		ctx.playSound(C.SoundShoot, 0.9, handle)

		if not Z.alive then return end
		sh.execute(plan)
	end

	ctx.track(tool.Activated:Connect(use))
	ctx.track(tool.Equipped:Connect(function()
		selectedFrame.Visible = true
		ctx.playSound(C.SoundKeyEquip, 0.5, handle)
		local sh = State.ship
		if sh and not sh.inShip() then
			pcall(sh.toast, "Clique pra chamar a nave (de novo pra mandar embora).", 2.5)
		end
	end))
	ctx.track(tool.Unequipped:Connect(function()
		selectedFrame.Visible = false
	end))

	task.spawn(function()
		while Z.alive and character.Parent do
			task.wait(0.5)
			if not (Z.alive and character.Parent) then break end
			if tool.Parent ~= backpack and tool.Parent ~= character then
				pcall(function() tool.Parent = backpack end)
			end
		end
	end)

	api.tool = tool
	api.use = use
	function api.destroy()
		pcall(function() tool:Destroy() end)
	end
	return api
end

local function setupRickGun(character)
	if not scriptAlive then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 15)
	if not humanoid then
		warnRG("Humanoid não encontrado; Rick Portal Gun não carregada.")
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
		or character:WaitForChild("HumanoidRootPart", 10)
		or character.PrimaryPart
		or character:FindFirstChildWhichIsA("BasePart")
	if not rootPart then
		warnRG("Parte raiz não encontrada; Rick Portal Gun não carregada.")
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
		warnRG("Câmera não encontrada; Rick Portal Gun não carregada.")
		return
	end

	loadAccessoryTemplate()
	pcall(State.loadKeyTemplate)
	resolvePortalImage()

	if not scriptAlive or not character.Parent or (player.Character and player.Character ~= character) then return end

	if State.cleanup then
		local prev = State.cleanup
		State.cleanup = nil
		pcall(prev)
	end

	local Z = { alive = true, conns = {}, extra = nil }
	local function track(c)
		Z.conns[#Z.conns + 1] = c
		return c
	end
	local myGuis = {}
	local function newGui(name, order)
		local g = Instance.new("ScreenGui")
		g.Name = name
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.DisplayOrder = order or 0
		g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		parentGui(g)
		myGuis[#myGuis + 1] = g
		pcall(UIAnim.attach, g)
		return g
	end

	do
		local okF, F = pcall(function()
			local TextService = game:GetService("TextService")
			local ATIVO = Config.FalaAtiva ~= false
			local TAM_BASE, LARGURA_MAX, ALTURA_CABECA = 15, 240, 2.4

			local EMOCOES = {
				calmo = { cor = Color3.fromRGB(120, 255, 110), vel = 0.03,  tremor = 0,    pulso = 0 },
				burp  = { cor = Color3.fromRGB(205, 255, 120), vel = 0.028, tremor = 0.15, pulso = 0.02 },
				grito = { cor = Color3.fromRGB(235, 255, 225), vel = 0.024, tremor = 0.3,  pulso = 0.03 },
				erro  = { cor = Color3.fromRGB(255, 120, 110), vel = 0.03,  tremor = 0,    pulso = 0 },
				nervoso = { cor = Color3.fromRGB(255, 220, 80), vel = 0.028, tremor = 0.18, pulso = 0.015 },
				animado = { cor = Color3.fromRGB(110, 235, 255), vel = 0.026, tremor = 0.1, pulso = 0.02 },
			}

			local K = Config.FalaIntensidade or 1

			local FALAS = {
				equip = {
					{ "Wubba lubba dub dub!", "grito", 1 },
					{ "Eu sou o {nome}, o cientista mais esperto do multiverso.", "calmo", 1 },
					{ "*burp* Bora bagunçar a realidade!", "burp", 1 },
					{ "Ciência, baby! *burp*", "burp", 1 },
					{ "{nome} chegou. Escondam as leis da física.", "calmo", 1 },
				},
				tiro = {
					{ "Segura aí, Morty!", "grito", 1 },
					{ "Abre, portal! *burp*", "burp", 1 },
					{ "Ciência, baby!", "grito", 1 },
					{ "{nome} nunca erra... quase nunca.", "calmo", 1 },
					{ "Wubba lubba *burp* dub dub!", "grito", 1 },
					{ "Não olha pro portal, Morty!", "calmo", 1 },
				},
				dim = {
					{ "Próxima parada: {dim}!", "calmo", 1 },
					{ "Dizem que {dim} é lindo nessa época. *burp*", "burp", 1 },
					{ "Bora pra {dim}, e não toca em nada!", "grito", 1 },
					{ "{dim}? {nome} já esteve lá. Era melhor antes.", "calmo", 1 },
				},
				alvo = {
					{ "Visita surpresa pra {alvo}!", "grito", 1 },
					{ "{alvo}, prepara o coração! *burp*", "burp", 1 },
					{ "Ei, {alvo}! Cheguei sem avisar mesmo.", "calmo", 1 },
				},
				tp = {
					{ "Aaaah, que viagem!", "grito", 1 },
					{ "*burp* Sem enjoo, hein.", "burp", 1 },
					{ "Wubba lubba dub dub!", "grito", 1 },
					{ "Isso é ciência, não mágica!", "calmo", 1 },
					{ "{nome} passou, o universo agradece.", "calmo", 1 },
				},
				fechar = {
					{ "Fechando a loja.", "calmo", 1 },
					{ "Portal fechado. Sem devolução.", "calmo", 1 },
					{ "Tchau, realidade! *burp*", "burp", 1 },
					{ "{nome} abre, {nome} fecha.", "calmo", 1 },
				},
				nave = {
					{ "Táxi do {nome} chegando! *burp*", "grito", 1 },
					{ "Entra na nave, Morty! E não vomita no banco.", "grito", 1 },
					{ "Minha nave, minhas regras. Pra onde, {nome}?", "calmo", 1 },
					{ "Ciência não tem estacionamento, mas eu dou um jeito!", "burp", 1 },
				},
				corte = {
					{ "Ai! Meu membro!", "grito", 1 },
					{ "Isso... *burp* não estava nos planos.", "burp", 1 },
					{ "Eu volto já, Morty!", "grito", 1 },
					{ "Cientista de verdade regenera!", "grito", 1 },
				},
				erro = {
					{ "Hm, isso não vai dar certo.", "erro", 1 },
					{ "Até um gênio erra o alvo. *burp*", "erro", 1 },
					{ "Calma, {nome}. Respira. Tenta de novo.", "erro", 1 },
				},
			}

			local CHANCE = { equip = 1, tiro = 0.45, dim = 0.8, alvo = 1, tp = 0.35, fechar = 0.5, corte = 1, erro = 0.4, nave = 1 }

			local function criarFalante(getHead, FALAS, CHANCE, vivo, altura, maxDist)
			local S = { gui = nil, caixa = nil, token = 0, ultimo = {}, t = 0 }

			local function nomeBoneco()
				local n = Config.FalaNome
				if type(n) ~= "string" or n == "" then n = player.DisplayName end
				if not n or n == "" then n = player.Name end
				return n
			end

			local function garantirGui()
				local head = getHead()
				if not head then return nil end
				if S.gui and S.gui.Parent then
					if S.gui.Adornee ~= head then S.gui.Adornee = head end
					return S.gui
				end
				local gui = Instance.new("BillboardGui")
				gui.Name = "RickFalas"
				gui.Adornee = head
				gui.AlwaysOnTop = true
				gui.LightInfluence = 0
				gui.ResetOnSpawn = false
				gui.Active = false
				gui.Size = UDim2.fromOffset(40, 24)
				gui.StudsOffsetWorldSpace = Vector3.new(0, altura or ALTURA_CABECA, 0)
				if maxDist then gui.MaxDistance = maxDist end
				parentGui(gui)

				local caixa = Instance.new("Frame")
				caixa.Name = "Fala"
				caixa.AnchorPoint = Vector2.new(0.5, 0.5)
				caixa.Position = UDim2.fromScale(0.5, 0.5)
				caixa.Size = UDim2.fromOffset(40, 20)
				caixa.BackgroundTransparency = 1
				caixa.Visible = false
				caixa.Parent = gui

				S.gui, S.caixa = gui, caixa
				return gui
			end

			local function parar()
				S.token = S.token + 1
				if S.caixa then
					S.caixa.Visible = false
					S.caixa:ClearAllChildren()
				end
			end

			local function mostrar(texto, emo, inten, ler)
				if not ATIVO or not vivo() then return end
				local gui = garantirGui()
				if not gui then return end
				local caixa = S.caixa
				local e = EMOCOES[emo] or EMOCOES.calmo
				inten = math.clamp(inten or 1, 1, 3)

				S.token = S.token + 1
				local meuToken = S.token
				local tam = TAM_BASE + (inten - 1) * 4
				local altLinha = tam + 4

				caixa:ClearAllChildren()

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
						chars[#chars + 1] = { ch = ch, w = lw }
						larg = larg + lw
					end
					palavras[#palavras + 1] = { chars = chars, w = larg }
				end

				local espaco = larguraChar(" ")
				local linhas, atual, atualW = {}, {}, 0
				for _, pw in ipairs(palavras) do
					local extra = (#atual > 0) and espaco or 0
					if #atual > 0 and atualW + extra + pw.w > LARGURA_MAX then
						linhas[#linhas + 1] = { palavras = atual, w = atualW }
						atual, atualW, extra = {}, 0, 0
					end
					atual[#atual + 1] = pw
					atualW = atualW + extra + pw.w
				end
				if #atual > 0 then linhas[#linhas + 1] = { palavras = atual, w = atualW } end

				local larguraTotal = 0
				for _, l in ipairs(linhas) do larguraTotal = math.max(larguraTotal, l.w) end
				local alturaTotal = #linhas * altLinha

				local letras = {}
				for li, l in ipairs(linhas) do
					local x = (larguraTotal - l.w) / 2
					local y = (li - 1) * altLinha
					for pi, pw in ipairs(l.palavras) do
						for _, c in ipairs(pw.chars) do
							local lbl = Instance.new("TextLabel")
							lbl.BackgroundTransparency = 1
							lbl.Size = UDim2.fromOffset(c.w + 4, altLinha)
							lbl.Position = UDim2.fromOffset(x - 2, y)
							lbl.Font = Enum.Font.GothamBold
							lbl.Text = c.ch
							lbl.TextSize = tam
							lbl.TextColor3 = e.cor
							lbl.TextTransparency = 1
							lbl.TextStrokeTransparency = 1
							lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
							lbl.Parent = caixa
							letras[#letras + 1] = { lbl = lbl, bx = x - 2, by = y, dx = 0, dy = 0, fase = math.random() * 6.28 }
							x = x + c.w
						end
						if pi < #l.palavras then x = x + espaco end
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
				local tLer = ler or (1.1 + total * 0.045)
				local tFade = 0.3
				local tFim = tDigitar + tLer + tFade
				local amp = e.tremor * inten * 0.8 * K

				task.spawn(function()
					local t0 = os.clock()
					local proxTremor = 0
					while S.token == meuToken and vivo() do
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
								if sorteia and amp > 0 then
									L.dx = (math.random() * 2 - 1) * amp
									L.dy = (math.random() * 2 - 1) * amp
								end
								local dx, dy = L.dx, L.dy
								if e.pulo then dy = dy - math.abs(math.sin(t * 9 + i * 0.55)) * 2.2 * inten end

								local entra = math.clamp(tLetra / 0.1, 0, 1)
								dy = dy + (1 - entra) * 5

								lbl.Position = UDim2.fromOffset(L.bx + dx, L.by + dy)
								local pulso = e.pulso * inten * K * math.sin(t * 11 + L.fase)
								lbl.TextSize = tam * (1 + pulso) * (0.8 + 0.2 * entra)
								lbl.TextTransparency = fadeK + (1 - entra) * (1 - fadeK)
								lbl.TextStrokeTransparency = 0.35 + 0.65 * lbl.TextTransparency
							end
						end
						RunService.RenderStepped:Wait()
					end
					if S.token == meuToken and caixa.Parent then
						caixa.Visible = false
						caixa:ClearAllChildren()
					end
				end)
			end

			local function dizer(cat, vars)
				if not ATIVO or not vivo() then return end
				local lista = FALAS[cat]
				if not lista then return end
				if math.random() > (CHANCE[cat] or 1) then return end
				local agora = os.clock()
				if agora - S.t < 1.5 then return end
				S.t = agora

				local f = lista[math.random(1, #lista)]
				if f[1] == S.ultimo[cat] and #lista > 1 then
					f = lista[(table.find(lista, f) % #lista) + 1]
				end
				S.ultimo[cat] = f[1]

				local v = vars or {}
				v.nome = v.nome or nomeBoneco()
				local texto = f[1]:gsub("{(%w+)}", function(k) return v[k] end)
				mostrar(texto, f[2], f[3] or 1)
			end

			return {
				dizer = dizer, mostrar = mostrar, parar = parar,
				destruir = function()
					parar()
					if S.gui then S.gui:Destroy() S.gui, S.caixa = nil, nil end
				end,
			}
			end
			local fala = criarFalante(function() return character and character:FindFirstChild("Head") end, FALAS, CHANCE, function() return Z.alive end)
			fala.criar = criarFalante
			return fala
		end)
		if okF and F then
			Z.fala = F
		else
			warnRG("sistema de falas nao carregou:", F)
			Z.fala = { dizer = function() end, mostrar = function() end, parar = function() end, destruir = function() end }
		end
	end

	track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if workspace.CurrentCamera then camera = workspace.CurrentCamera end
	end))

	for _, v in ipairs(backpack:GetChildren()) do
		if v.Name == Config.ToolName then v:Destroy() end
	end
	if character:FindFirstChild(Config.ToolName) then
		character[Config.ToolName]:Destroy()
	end
	if character:FindFirstChild("HolsteredRickGun") then
		character.HolsteredRickGun:Destroy()
	end

	local function playSound(id, volume, parent)
		local okS, sound = pcall(function()
			local s = Instance.new("Sound")
			s.SoundId = id
			s.Volume = 0.5
			s.Parent = (parent and parent.Parent) and parent or SoundService
			s:Play()
			Debris:AddItem(s, 5)
			return s
		end)
		return okS and sound or nil
	end

	local tool = Instance.new("Tool")
	tool.Name = Config.ToolName
	tool.ToolTip = Config.ToolName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	local handle = buildGun(tool, true)

	local rot = CFrame.new()
	if AccAxis == Vector3.xAxis then
		rot = CFrame.Angles(0, math.rad(90), 0)
	elseif AccAxis == Vector3.yAxis then
		rot = CFrame.Angles(math.rad(90), 0, 0)
	end
	local e = Config.AccessoryExtraRotation
	tool.Grip = CFrame.new(Config.AccessoryGrip) * rot
		* CFrame.Angles(math.rad(e.X), math.rad(e.Y), math.rad(e.Z))
	pcall(function() tool.Parent = backpack end)

	local function getMuzzlePos()
		local axisLocal = AccAxis or Vector3.zAxis
		local half = AccHalf > 0 and AccHalf or 0.9
		local gripAlong = Config.AccessoryGrip:Dot(axisLocal)
		local sign
		if math.abs(gripAlong) > 0.05 then
			sign = (gripAlong < 0) and 1 or -1
		else
			local axisWorld = handle.CFrame:VectorToWorldSpace(axisLocal)
			sign = axisWorld:Dot(rootPart.CFrame.LookVector) >= 0 and 1 or -1
		end
		if Config.MuzzleFlip then sign = -sign end
		return handle.CFrame:PointToWorldSpace(axisLocal * sign * half + Config.MuzzleOffset)
	end

	local defaultGrip = tool.Grip
	local isRecoiling = false
	local function playRecoil()
		if isRecoiling then return end
		isRecoiling = true
		local recoilGrip = defaultGrip * CFrame.new(0, 0.06, 0.18) * CFrame.Angles(math.rad(-8), math.rad(2), math.rad(1))
		local kick = TweenService:Create(tool, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Grip = recoilGrip})
		kick:Play()
		kick.Completed:Wait()
		local recover = TweenService:Create(tool, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Grip = defaultGrip})
		recover:Play()
		recover.Completed:Wait()
		tool.Grip = defaultGrip
		isRecoiling = false
	end

	local holster = nil
	local function removeHolster()
		if holster then
			holster:Destroy()
			holster = nil
		end
	end
	local function createHolster()
		removeHolster()
		local back = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or rootPart
		if not back then return end
		holster = Instance.new("Model")
		holster.Name = "HolsteredRickGun"
		local hHandle = buildGun(holster, false)
		if not hHandle then
			holster:Destroy()
			holster = nil
			return
		end
		for _, d in ipairs(holster:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanTouch = false
			end
		end
		local weld = Instance.new("Weld")
		weld.Name = "HolsterWeld"
		weld.Part0 = back
		weld.Part1 = hHandle
		weld.C0 = Config.HolsterOffset
		weld.Parent = hHandle
		holster.Parent = character
	end

	local entrance = nil
	local exitP = nil
	local shotId = 0
	local lastShot = 0
	local lastTeleport = 0
	local disarmed = nil

	local variant = 1
	local nextSlot = 1
	local targetPlayer = nil
	local setStatus = function() end
	local severCheck = nil

	local function buildProceduralSwirl(sg)
		local rng = Random.new()
		local TAU = math.pi * 2
		local YEL = Color3.fromRGB(176, 220, 96)
		local LIGHT = Color3.fromRGB(158, 208, 84)
		local MIDG = Color3.fromRGB(92, 184, 74)
		local MIDD = Color3.fromRGB(58, 168, 78)
		local DARK = Color3.fromRGB(28, 144, 70)
		local WHITE = Color3.fromRGB(244, 255, 238)

		local root = Instance.new("Frame")
		root.Name = "Root"
		root.AnchorPoint = Vector2.new(0.5, 0.5)
		root.Position = UDim2.fromScale(0.5, 0.5)
		root.Size = UDim2.fromScale(1, 1)
		root.BackgroundTransparency = 1
		root.Parent = sg

		local function frame(parent, name, x, y, w, h, color, rot)
			local f = Instance.new("Frame")
			f.Name = name
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(x, y)
			f.Size = UDim2.fromScale(w, h)
			f.Rotation = rot or 0
			f.BackgroundColor3 = color
			f.BorderSizePixel = 0
			f.Parent = parent
			Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
			return f
		end

		local function holder(name)
			local f = Instance.new("Frame")
			f.Name = name
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(0.5, 0.5)
			f.Size = UDim2.fromScale(1, 1)
			f.BackgroundTransparency = 1
			f.Parent = root
			return f
		end

		local function spin(f, seconds, dir)
			TweenService:Create(f, TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {Rotation = 360 * dir}):Play()
		end

		local function boil(f, seconds, props)
			TweenService:Create(f, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), props):Play()
		end

		local function blob(parent, angle, radius, size, color)
			local f = frame(parent, "Blob", 0.5 + math.cos(angle) * radius, 0.5 + math.sin(angle) * radius, size, size, color, 0)
			local r2 = radius + (rng:NextNumber() * 2 - 1) * 0.025
			local s2 = size * (0.78 + rng:NextNumber() * 0.5)
			boil(f, 0.3 + rng:NextNumber() * 0.6, {
				Position = UDim2.fromScale(0.5 + math.cos(angle) * r2, 0.5 + math.sin(angle) * r2),
				Size = UDim2.fromScale(s2, s2),
			})
		end

		local edgeA = holder("EdgeA")
		local NA = 22
		for i = 1, NA do
			local a = (i + (rng:NextNumber() - 0.5) * 0.5) / NA * TAU
			blob(edgeA, a, 0.33 + (rng:NextNumber() - 0.5) * 0.03, 0.18 + rng:NextNumber() * 0.04, MIDG)
		end
		spin(edgeA, 34, 1)

		local edgeB = holder("EdgeB")
		local NB = 20
		for i = 1, NB do
			local a = (i + (rng:NextNumber() - 0.5) * 0.5) / NB * TAU
			blob(edgeB, a, 0.4 + (rng:NextNumber() - 0.5) * 0.02, 0.08 + rng:NextNumber() * 0.05, (i % 2 == 0) and LIGHT or YEL)
		end
		spin(edgeB, 26, -1)

		frame(root, "Base", 0.5, 0.5, 0.8, 0.8, MIDG, 0)
		frame(root, "Band1", 0.5, 0.5, 0.62, 0.62, MIDD, 0)
		frame(root, "Band2", 0.5, 0.5, 0.46, 0.46, DARK, 0)
		frame(root, "Band3", 0.5, 0.5, 0.34, 0.34, MIDG, 0)
		frame(root, "Band4", 0.5, 0.5, 0.24, 0.24, DARK, 0)

		local rings = {
			{0.37, 14, 0.15, 0.04, {YEL, LIGHT}, 30},
			{0.33, 13, 0.17, 0.06, {MIDG, LIGHT}, 24},
			{0.285, 12, 0.19, 0.075, {DARK, MIDD}, 19},
			{0.24, 11, 0.17, 0.07, {LIGHT, MIDG}, 15},
			{0.195, 10, 0.16, 0.07, {DARK, MIDD}, 12},
			{0.15, 8, 0.14, 0.06, {LIGHT, MIDG}, 9},
			{0.11, 7, 0.1, 0.05, {DARK, LIGHT}, 6.5},
			{0.06, 5, 0.07, 0.04, {DARK, MIDD}, 4.5},
		}
		for idx, spec in ipairs(rings) do
			local radius, n, len, th, colors, seconds = spec[1], spec[2], spec[3], spec[4], spec[5], spec[6]
			local h = holder("Strokes" .. idx)
			for i = 1, n do
				local a = (i + rng:NextNumber() * 0.6) / n * TAU
				local r = radius + (rng:NextNumber() - 0.5) * 0.03
				local l = len * (0.7 + rng:NextNumber() * 0.7)
				local t = th * (0.7 + rng:NextNumber() * 0.6)
				local rot = math.deg(a) + 90 + 22 + idx * 1.5 + (rng:NextNumber() - 0.5) * 14
				frame(h, "Stroke", 0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r, l, t, colors[rng:NextInteger(1, #colors)], rot)
			end
			spin(h, seconds, 1)
		end

		local center = frame(root, "Center", 0.5, 0.5, 0.13, 0.13, YEL, 0)
		boil(center, 0.7, {Size = UDim2.fromScale(0.17, 0.17)})

		local dots = holder("Speckles")
		for i = 1, 40 do
			local a = rng:NextNumber() * TAU
			local r = 0.27 + (rng:NextNumber() ^ 0.6) * 0.19
			local big = rng:NextNumber() < 0.3
			local w = big and (0.03 + rng:NextNumber() * 0.025) or (0.012 + rng:NextNumber() * 0.016)
			local h = (rng:NextNumber() < 0.35) and w * 0.5 or w
			local d = frame(dots, "Speck", 0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r, w, h, WHITE, rng:NextNumber() * 180)
			if i % 3 == 0 then
				boil(d, 0.4 + rng:NextNumber() * 0.8, {BackgroundTransparency = 0.8})
			end
		end
		spin(dots, 34, 1)

		return root
	end

	local function buildImageSwirl(sg)
		local root = Instance.new("Frame")
		root.Name = "Root"
		root.AnchorPoint = Vector2.new(0.5, 0.5)
		root.Position = UDim2.fromScale(0.5, 0.5)
		root.Size = UDim2.fromScale(1, 1)
		root.BackgroundTransparency = 1
		root.Parent = sg

		local function layer(name, tint, alpha, rot)
			local img = Instance.new("ImageLabel")
			img.Name = name
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Position = UDim2.fromScale(0.5, 0.5)
			img.Size = UDim2.fromScale(1, 1)
			img.BackgroundTransparency = 1
			img.BorderSizePixel = 0
			img.Image = PortalImage
			img.ScaleType = Enum.ScaleType.Fit
			img.ImageColor3 = tint
			img.ImageTransparency = alpha
			img.Rotation = rot
			img.Parent = root
			local ratio = Instance.new("UIAspectRatioConstraint")
			ratio.AspectRatio = 1
			ratio.AspectType = Enum.AspectType.FitWithinMaxSize
			ratio.DominantAxis = Enum.DominantAxis.Width
			ratio.Parent = img
			return img
		end

		local function spin(f, seconds, start, dir)
			TweenService:Create(f, TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {Rotation = start + 360 * dir}):Play()
		end

		local function pulse(f, seconds, props)
			TweenService:Create(f, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), props):Play()
		end

		local a = layer("ImageA", Color3.new(1, 1, 1), 0, 0)
		spin(a, 16, 0, 1)
		pulse(a, 1.1, {ImageColor3 = Color3.fromRGB(215, 255, 200)})

		local b = layer("ImageB", Color3.fromRGB(190, 255, 140), 0.4, Config.PortalImageOffset)
		spin(b, 16, Config.PortalImageOffset, 1)
		pulse(b, 0.9, {ImageTransparency = 0.65})

		local c = layer("ImageC", Color3.fromRGB(235, 255, 215), 0.5, Config.PortalImageOffset * 2)
		c.Size = UDim2.fromScale(0.82, 0.82)
		spin(c, 10, Config.PortalImageOffset * 2, -1)
		pulse(c, 1.3, {ImageTransparency = 0.78, ImageColor3 = Color3.fromRGB(150, 255, 110)})

		return root
	end

	local GOO_FILL = Color3.fromRGB(122, 214, 72)
	local GOO_DARK = Color3.fromRGB(34, 130, 58)
	local GOO_LIGHT = Color3.fromRGB(200, 246, 128)

	local function buildSwirl(sg)
		if PortalImage then
			return buildImageSwirl(sg)
		end
		return buildProceduralSwirl(sg)
	end

	local function spawnGooDrop(model, localPos, size)
		local portal = model:FindFirstChild("Portal")
		if not portal then return end
		local rng = Random.new()
		local pos = portal.CFrame:PointToWorldSpace(localPos)
		local d = Instance.new("Part")
		d.Name = "GooDrop"
		d.Shape = Enum.PartType.Ball
		d.Anchored = true
		d.CanCollide = false
		d.CanQuery = false
		d.CanTouch = false
		d.CastShadow = false
		d.Material = Enum.Material.SmoothPlastic
		d.Reflectance = 0.12
		d.Color = GOO_FILL
		d.Size = Vector3.new(size, size, size)
		d.Position = pos
		d.Parent = workspace
		Debris:AddItem(d, 4)

		local fd = 3 + rng:NextNumber() * 4
		local hit = castSolid(pos, Vector3.new(0, -fd, 0), buildIgnore(character, model))
		if hit then fd = math.max(hit.Distance - size * 0.5, 0.1) end
		local t = math.sqrt(2 * fd / 45)

		TweenService:Create(d, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = pos - Vector3.new(0, fd, 0),
			Size = Vector3.new(size * 0.7, size * 1.5, size * 0.7),
		}):Play()

		if hit and hit.Normal.Y > 0.7 then
			task.delay(t, function()
				if d then d.Transparency = 1 end
				local sp = Instance.new("Part")
				sp.Name = "GooSplat"
				sp.Shape = Enum.PartType.Cylinder
				sp.Anchored = true
				sp.CanCollide = false
				sp.CanQuery = false
				sp.CanTouch = false
				sp.CastShadow = false
				sp.Material = Enum.Material.SmoothPlastic
				sp.Color = GOO_FILL
				sp.Size = Vector3.new(0.04, 0.1, 0.1)
				sp.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.pi / 2)
				sp.Parent = workspace
				Debris:AddItem(sp, 3.4)
				local sz = 0.5 + rng:NextNumber() * 0.5
				TweenService:Create(sp, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(0.04, sz, sz)}):Play()
				TweenService:Create(sp, TweenInfo.new(1.6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 1.2), {Transparency = 1}):Play()
			end)
		else
			TweenService:Create(d, TweenInfo.new(t * 0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, t * 0.65), {Transparency = 1}):Play()
		end
	end

	local function startGooDrips(model, portal)
		if not Config.GooDrips then return end
		local n = math.max(Config.GooDripCount, 1)
		local R = Config.GooDripRadius - 0.01
		for i = 1, n do
			local a = math.rad(25 + 130 * (i - 0.5) / n)
			task.spawn(function()
				local rng = Random.new()
				task.wait(0.4 + rng:NextNumber() * 2.2)
				while model.Parent and portal.Parent and not model:GetAttribute("Closing") do
					local grow = 1.1 + rng:NextNumber() * 1.3
					local len = 24 + rng:NextNumber() * 16
					local bulb = 14 + rng:NextNumber() * 6
					local strands = {}
					for _, sg in ipairs(portal:GetChildren()) do
						local root = sg:IsA("SurfaceGui") and sg:FindFirstChild("Root")
						if root then
							local s = Instance.new("Frame")
							s.Name = "GooDrip"
							s.AnchorPoint = Vector2.new(0.5, 0)
							s.Position = UDim2.fromScale(0.5 + math.cos(a) * R, 0.5 + math.sin(a) * R)
							s.Size = UDim2.fromOffset(9, 2)
							s.BackgroundColor3 = GOO_FILL
							s.BorderSizePixel = 0
							s.ZIndex = 6
							Instance.new("UICorner", s).CornerRadius = UDim.new(0.5, 0)
							local b = Instance.new("Frame")
							b.Name = "Bulb"
							b.AnchorPoint = Vector2.new(0.5, 0.5)
							b.Position = UDim2.new(0.5, 0, 1, 0)
							b.Size = UDim2.fromOffset(6, 6)
							b.BackgroundColor3 = GOO_FILL
							b.BorderSizePixel = 0
							b.ZIndex = 6
							Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
							local hl = Instance.new("Frame")
							hl.AnchorPoint = Vector2.new(0.5, 0.5)
							hl.Position = UDim2.fromScale(0.35, 0.33)
							hl.Size = UDim2.fromScale(0.3, 0.3)
							hl.BackgroundColor3 = Color3.new(1, 1, 1)
							hl.BackgroundTransparency = 0.3
							hl.BorderSizePixel = 0
							hl.ZIndex = 7
							Instance.new("UICorner", hl).CornerRadius = UDim.new(1, 0)
							hl.Parent = b
							b.Parent = s
							s.Parent = root
							local gi = TweenInfo.new(grow, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
							TweenService:Create(s, gi, {Size = UDim2.fromOffset(9, len)}):Play()
							TweenService:Create(b, gi, {Size = UDim2.fromOffset(bulb, bulb)}):Play()
							strands[#strands + 1] = {s = s, b = b}
						end
					end

					task.wait(grow)
					if not (model.Parent and portal.Parent) then break end

					if Config.GooDrop3D and portal.CFrame.UpVector.Y > 0.6 then
						local gx = math.cos(a) * R
						local gy = math.sin(a) * R + (len + bulb * 0.5) / 512
						local lp = Vector3.new(gx * portal.Size.X, -gy * portal.Size.Y, -0.15)
						spawnGooDrop(model, lp, bulb / 512 * portal.Size.X * 0.9)
					end

					for _, st in ipairs(strands) do
						local ri = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
						TweenService:Create(st.s, ri, {Size = UDim2.fromOffset(9, 0), BackgroundTransparency = 1}):Play()
						TweenService:Create(st.b, ri, {BackgroundTransparency = 1}):Play()
						Debris:AddItem(st.s, 0.3)
					end
					task.wait(0.8 + rng:NextNumber() * 1.8)
				end
			end)
		end
	end

	local function createPortalModel(cf)
		local model = Instance.new("Model")
		model.Name = "RickPortalModel"

		local outer = Instance.new("Part")
		outer.Name = "OuterRing"
		outer.Anchored = true
		outer.CanCollide = false
		outer.CanQuery = false
		outer.Size = Config.PortalSize
		outer.Material = Enum.Material.SmoothPlastic
		outer.Color = Config.PortalColor
		outer.Transparency = 1
		outer.CastShadow = false
		outer.CFrame = cf
		outer.Parent = model
		local outerMesh = Instance.new("SpecialMesh")
		outerMesh.MeshType = Enum.MeshType.Sphere
		outerMesh.Scale = Vector3.new(1, 1, 0.12)
		outerMesh.Parent = outer

		local core = Instance.new("Part")
		core.Name = "PortalCore"
		core.Anchored = true
		core.CanCollide = false
		core.CanQuery = false
		core.Size = Config.PortalSize * Vector3.new(0.88, 0.88, 0.55)
		core.Material = Enum.Material.SmoothPlastic
		core.Color = Config.PortalDark
		core.Transparency = 1
		core.CastShadow = false
		core.CFrame = cf * CFrame.new(0, 0, -0.04)
		core.Parent = model
		local coreMesh = Instance.new("SpecialMesh")
		coreMesh.MeshType = Enum.MeshType.Sphere
		coreMesh.Scale = Vector3.new(1, 1, 0.12)
		coreMesh.Parent = core

		local portal = Instance.new("Part")
		portal.Name = "Portal"
		portal.Anchored = true
		portal.CanCollide = false
		portal.CanQuery = false
		portal.Size = Config.PortalSize * Vector3.new(0.88, 0.88, 0.5)
		portal.Transparency = 1
		portal.CFrame = cf
		portal.Parent = model

		for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
			local sg = Instance.new("SurfaceGui")
			sg.Name = "PortalSwirl"
			sg.Face = face
			sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
			sg.CanvasSize = Vector2.new(512, 512)
			sg.LightInfluence = 0
			sg.AlwaysOnTop = false
			sg.Parent = portal
			buildSwirl(sg)
		end

		local edgeSparks = Instance.new("ParticleEmitter")
		edgeSparks.Name = "EdgeSparks"
		edgeSparks.Texture = Config.ParticleSpark
		edgeSparks.Color = ColorSequence.new(Color3.new(1, 1, 1), Config.PortalColor)
		edgeSparks.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.16), NumberSequenceKeypoint.new(1, 0)})
		edgeSparks.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
		edgeSparks.Lifetime = NumberRange.new(0.3, 0.7)
		edgeSparks.Rate = 18
		edgeSparks.Speed = NumberRange.new(1.5, 4)
		edgeSparks.SpreadAngle = Vector2.new(25, 25)
		edgeSparks.EmissionDirection = Enum.NormalId.Front
		edgeSparks.LightEmission = 0
		edgeSparks.LightInfluence = 1
		edgeSparks.LockedToPart = true
		edgeSparks.Enabled = false
		edgeSparks.Parent = outer

		local mist = Instance.new("ParticleEmitter")
		mist.Name = "PortalMist"
		mist.Texture = Config.ParticleSpark2
		mist.Color = ColorSequence.new(Config.PortalLight, Config.PortalColor)
		mist.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)})
		mist.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1)})
		mist.Lifetime = NumberRange.new(0.8, 1.6)
		mist.Rate = 14
		mist.Speed = NumberRange.new(0.5, 1.5)
		mist.SpreadAngle = Vector2.new(180, 180)
		mist.Rotation = NumberRange.new(0, 360)
		mist.RotSpeed = NumberRange.new(-60, 60)
		mist.LightEmission = 0
		mist.LightInfluence = 1
		mist.Enabled = false
		mist.Parent = outer
		pcall(function()
			mist.Shape = Enum.ParticleEmitterShape.Disc
			mist.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		end)

		model.Parent = workspace

		outer.Size = Vector3.new(0.1, 0.1, 0.1)
		core.Size = Vector3.new(0.1, 0.1, 0.1)
		local roots = {}
		for _, sg in ipairs(portal:GetChildren()) do
			local r = sg:IsA("SurfaceGui") and sg:FindFirstChild("Root")
			if r then
				r.Size = UDim2.fromScale(0, 0)
				roots[#roots + 1] = r
			end
		end
		local ti = TweenInfo.new(0.75, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
		TweenService:Create(outer, ti, {Size = Config.PortalSize}):Play()
		TweenService:Create(core, ti, {Size = Config.PortalSize * Vector3.new(0.88, 0.88, 0.55)}):Play()
		for _, r in ipairs(roots) do
			TweenService:Create(r, ti, {Size = UDim2.fromScale(1, 1)}):Play()
		end
		startGooDrips(model, portal)
		task.delay(0.25, function()
			if model.Parent then edgeSparks.Enabled = true; mist.Enabled = true end
		end)
		playSound(Config.SoundOpen, 1.2, outer)

		return model
	end

	local function closeSound(cf)
		if not (Config.SoundClose and Config.SoundClose ~= "") then return end
		local sp = Instance.new("Part")
		sp.Name = "RickPortalCloseSnd"
		sp.Anchored = true
		sp.CanCollide = false
		sp.CanQuery = false
		sp.CanTouch = false
		sp.Transparency = 1
		sp.Size = Vector3.new(0.1, 0.1, 0.1)
		sp.CFrame = CFrame.new(cf.Position)
		sp.Parent = workspace
		Debris:AddItem(sp, 6)
		playSound(Config.SoundClose, 1.2, sp)
	end

	local function gooSplat(pos, normal, size)
		local sp = Instance.new("Part")
		sp.Name = "GooSplat"
		sp.Shape = Enum.PartType.Cylinder
		sp.Anchored = true
		sp.CanCollide = false
		sp.CanQuery = false
		sp.CanTouch = false
		sp.CastShadow = false
		sp.Material = Enum.Material.SmoothPlastic
		sp.Reflectance = 0.1
		sp.Color = GOO_FILL
		sp.Size = Vector3.new(0.04, 0.1, 0.1)
		sp.CFrame = CFrame.lookAt(pos + normal * 0.03, pos + normal) * CFrame.Angles(0, math.pi / 2, 0)
		sp.Parent = workspace
		Debris:AddItem(sp, 6)
		TweenService:Create(sp, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = Vector3.new(0.04, size, size)}):Play()
		TweenService:Create(sp, TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 3.2), {Transparency = 1}):Play()
	end

	local function gooCloseBurst(cf, model)
		if not Config.GooCloseBurst then return end
		local rng = Random.new()
		local origin = cf.Position
		local normal = cf.LookVector
		local right, up = cf.RightVector, cf.UpVector
		local ignore = buildIgnore(character, model)
		local drops = {}
		local GRAV = Vector3.new(0, -70, 0)
		for _ = 1, math.max(Config.GooCloseCount, 1) do
			local ang = rng:NextNumber() * math.pi * 2
			local rad = math.sqrt(rng:NextNumber()) * Config.PortalSize.X * 0.4
			local start = origin + (right * math.cos(ang) + up * math.sin(ang)) * rad + normal * 0.3
			local vel = normal * (4 + rng:NextNumber() * 10)
				+ (right * math.cos(ang) + up * math.sin(ang)) * (2 + rng:NextNumber() * 7)
				+ Vector3.new(0, 1 + rng:NextNumber() * 5, 0)
			local size = 0.25 + rng:NextNumber() ^ 2 * 0.55
			local d = Instance.new("Part")
			d.Name = "GooBurstDrop"
			d.Shape = Enum.PartType.Ball
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Material = Enum.Material.SmoothPlastic
			d.Reflectance = 0.12
			d.Color = GOO_FILL
			d.Size = Vector3.new(size, size, size)
			d.Position = start
			d.Parent = workspace
			Debris:AddItem(d, 4)
			drops[#drops + 1] = {part = d, pos = start, vel = vel, size = size}
		end

		task.spawn(function()
			local t0 = os.clock()
			while #drops > 0 and os.clock() - t0 < 2.5 do
				local dt = math.min(RunService.Heartbeat:Wait(), 0.05)
				for i = #drops, 1, -1 do
					local dr = drops[i]
					local np = dr.pos + dr.vel * dt
					local hit = castSolid(dr.pos, np - dr.pos, ignore)
					if hit then
						gooSplat(hit.Position, hit.Normal, dr.size * (2.2 + rng:NextNumber() * 2.2))
						dr.part:Destroy()
						table.remove(drops, i)
					else
						dr.pos = np
						dr.vel = dr.vel + GRAV * dt
						dr.part.Position = np
						local sp = dr.vel.Magnitude
						local st = math.clamp(1 + sp * 0.03, 1, 1.7)
						dr.part.Size = Vector3.new(dr.size, dr.size * st, dr.size)
					end
				end
			end
			for _, dr in ipairs(drops) do
				if dr.part then dr.part:Destroy() end
			end
		end)
	end

	local function closePortal(model)
		if not model or not model.Parent then return end
		local outer = model:FindFirstChild("OuterRing")
		local core = model:FindFirstChild("PortalCore")
		local portal = model:FindFirstChild("Portal")
		local light = outer and outer:FindFirstChildOfClass("PointLight")

		local soundCF = (portal and portal.CFrame) or (outer and outer.CFrame)
		if soundCF then task.spawn(closeSound, soundCF) end
		if soundCF then task.spawn(gooCloseBurst, soundCF, model) end

		model:SetAttribute("Closing", true)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("ParticleEmitter") then d.Enabled = false end
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
		if portal then
			for _, sg in ipairs(portal:GetChildren()) do
				local r = sg:IsA("SurfaceGui") and sg:FindFirstChild("Root")
				if r then
					TweenService:Create(r, ti, {Size = UDim2.fromScale(0, 0)}):Play()
				end
			end
		end

		task.wait(0.32)
		if model and model.Parent then model:Destroy() end
	end

	local function setPortalCF(model, cf)
		local outer = model:FindFirstChild("OuterRing")
		local core = model:FindFirstChild("PortalCore")
		local portal = model:FindFirstChild("Portal")
		if outer then outer.CFrame = cf end
		if core then core.CFrame = cf * CFrame.new(0, 0, -0.04) end
		if portal then portal.CFrame = cf end
	end

	local function newPortal(cf, hostPart)
		local P = { model = createPortalModel(cf), host = nil, rel = nil, opened = os.clock() }
		if hostPart and hostPart.Parent then
			P.host = hostPart
			P.rel = hostPart.CFrame:ToObjectSpace(cf)
		end
		State.mortyEvent("onPortal", cf.Position)
		return P
	end

	local function updatePortalsPosition()
		for _, P in ipairs({entrance, exitP}) do
			if P and P.model.Parent and P.host then
				if P.host.Parent then
					setPortalCF(P.model, P.host.CFrame * P.rel)
				else
					P.host = nil
					P.rel = nil
				end
			end
		end
	end

	local function closePair()
		if entrance and exitP and severCheck then
			local sa, sb = entrance, exitP
			pcall(severCheck, sa, sb)
			pcall(severCheck, sb, sa)
		end
		for _, P in ipairs({entrance, exitP}) do
			if P then
				P.boingId = (P.boingId or 0) + 1
				task.spawn(closePortal, P.model)
			end
		end
		entrance = nil
		exitP = nil
		disarmed = nil
	end

	local function closeAllPortals()
		if (entrance or exitP) and humanoid.Health > 0 then Z.fala.dizer("fechar") end
		shotId = shotId + 1
		nextSlot = 1
		closePair()
	end

	local function closeSlot(which)
		local P, other
		if which == 1 then
			P = entrance
			other = exitP
			entrance = nil
		else
			P = exitP
			other = entrance
			exitP = nil
		end
		if P and other and severCheck then pcall(severCheck, P, other) end
		if P then
			P.boingId = (P.boingId or 0) + 1
			if disarmed == P then disarmed = nil end
			task.spawn(closePortal, P.model)
		end
	end

	local FLOOR_MARGIN = 0.05
	local function liftWallPortalAboveFloor(hitPos, normal)
		if math.abs(normal.Y) > 0.7 then return hitPos end
		local halfH = Config.PortalSize.Y / 2
		local halfW = Config.PortalSize.X / 2
		local right = normal:Cross(Vector3.yAxis)
		if right.Magnitude < 0.01 then return hitPos end
		right = right.Unit

		local params = RaycastParams.new()
		params.FilterDescendantsInstances = buildIgnore(character, entrance and entrance.model, exitP and exitP.model)
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = true

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

	local function computeExitCF(hitPos, normal)
		local lookPos = hitPos + normal * 5
		local p = hitPos + normal * Config.PortalOffset
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
			return CFrame.lookAt(p, lookPos, topDir)
		end
		return CFrame.lookAt(p, lookPos, Vector3.new(0, 1, 0))
	end

	local function computeEntranceCF()
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.1 then
			local rl = rootPart.CFrame.LookVector
			flat = Vector3.new(rl.X, 0, rl.Z)
		end
		if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, -1) end
		flat = flat.Unit

		local rootPos = rootPart.Position
		local ignore = buildIgnore(character, entrance and entrance.model, exitP and exitP.model)

		local dist = Config.EntranceDistance
		local wall = castSolid(rootPos, flat * (dist + 1), ignore)
		if wall then
			dist = math.max(wall.Distance - 1.5, 3.6)
		end

		local base = rootPos + flat * dist
		local down = castSolid(base + Vector3.new(0, 2, 0), Vector3.new(0, -14, 0), ignore)
		local groundY = (down and down.Normal.Y > 0.5) and down.Position.Y or (rootPos.Y - 3)
		local center = Vector3.new(base.X, groundY + Config.PortalSize.Y / 2 + 0.05, base.Z)
		return CFrame.lookAt(center, center - flat)
	end

	local function computeNearPlayerCF(tRoot)
		local look = tRoot.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, -1) end
		flat = flat.Unit

		local ignore = buildIgnore(character, tRoot.Parent, entrance and entrance.model, exitP and exitP.model)
		local dist = Config.NearPlayerDistance
		local wall = castSolid(tRoot.Position, flat * (dist + 1), ignore)
		if wall then
			dist = math.max(wall.Distance - 1.5, 3.6)
		end
		local base = tRoot.Position + flat * dist
		local down = castSolid(base + Vector3.new(0, 2, 0), Vector3.new(0, -14, 0), ignore)
		local groundY = (down and down.Normal.Y > 0.5) and down.Position.Y or (tRoot.Position.Y - 3)
		local center = Vector3.new(base.X, groundY + Config.PortalSize.Y / 2 + 0.05, base.Z)
		return CFrame.lookAt(center, center - flat)
	end

	local function computeStandingPairCF()
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.1 then
			local rl = rootPart.CFrame.LookVector
			flat = Vector3.new(rl.X, 0, rl.Z)
		end
		if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, -1) end
		flat = flat.Unit

		local rootPos = rootPart.Position
		local ignore = buildIgnore(character, entrance and entrance.model, exitP and exitP.model)
		local d1 = Config.EntranceDistance
		local d2 = d1 + Config.Variant15Gap
		local wall = castSolid(rootPos, flat * (d2 + 5), ignore)
		if wall then
			d2 = math.max(math.min(d2, wall.Distance - 5.5), 7.6)
			d1 = math.max(math.min(d1, d2 - 4), 3.6)
		end

		local function standing(dist, faceDir)
			local base = rootPos + flat * dist
			local down = castSolid(base + Vector3.new(0, 2, 0), Vector3.new(0, -14, 0), ignore)
			local groundY = (down and down.Normal.Y > 0.5) and down.Position.Y or (rootPos.Y - 3)
			local center = Vector3.new(base.X, groundY + Config.PortalSize.Y / 2 + 0.05, base.Z)
			return CFrame.lookAt(center, center + faceDir)
		end

		return standing(d1, -flat), standing(d2, flat)
	end

	local function flashAt(position, scale)
		local color = Config.PortalColor
		local fx = Instance.new("Part")
		fx.Name = "RickPortalFlash"
		fx.Anchored = true
		fx.CanCollide = false
		fx.CanQuery = false
		fx.CanTouch = false
		fx.CastShadow = false
		fx.Material = Enum.Material.Neon
		fx.Color = color
		fx.Transparency = 0.1
		fx.Shape = Enum.PartType.Ball
		fx.Size = Vector3.new(0.3, 0.3, 0.3) * scale
		fx.CFrame = CFrame.new(position)
		fx.Parent = workspace

		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = 8
		light.Range = 12
		light.Parent = fx

		local burst = Instance.new("ParticleEmitter")
		burst.Texture = Config.ParticleSpark
		burst.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.35, color),
			ColorSequenceKeypoint.new(1, color),
		})
		burst.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5 * scale),
			NumberSequenceKeypoint.new(0.3, 0.9 * scale),
			NumberSequenceKeypoint.new(1, 0),
		})
		burst.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1)})
		burst.Lifetime = NumberRange.new(0.15, 0.35)
		burst.Rate = 0
		burst.Speed = NumberRange.new(6 * scale, 16 * scale)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.LightEmission = 1
		burst.LightInfluence = 0
		burst.Parent = fx
		burst:Emit(math.floor(20 * scale))

		TweenService:Create(fx, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(1, 1, 1) * scale, Transparency = 0.55
		}):Play()
		TweenService:Create(light, TweenInfo.new(0.25), {Brightness = 0, Range = 3}):Play()
		task.delay(0.1, function()
			if fx.Parent then
				TweenService:Create(fx, TweenInfo.new(0.2), {Size = Vector3.new(0.05, 0.05, 0.05), Transparency = 1}):Play()
			end
		end)
		Debris:AddItem(fx, 0.6)
	end

	local function openRipple(cf)
		local d = Config.PortalSize.X
		local ring = Instance.new("Part")
		ring.Name = "RickPortalRipple"
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Material = Enum.Material.Neon
		ring.Color = Config.PortalLight
		ring.Transparency = 0.35
		ring.Size = Vector3.new(0.1, 0.5, 0.5)
		ring.CFrame = cf * CFrame.Angles(0, math.rad(90), 0)
		ring.Parent = workspace
		TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.1, d * 1.35, d * 1.35), Transparency = 1
		}):Play()
		Debris:AddItem(ring, 0.7)
		flashAt(cf.Position, 1.4)
	end

	local function launchProjectile(fromPos, toPos, onArrive)
		local delta = toPos - fromPos
		local dist = delta.Magnitude
		if dist < 0.05 then
			if onArrive then pcall(onArrive) end
			return
		end

		local unit = delta.Unit
		local W = Config.BeamWidth
		local tLen = math.min(math.max(Config.BeamLength, 0.5), dist)
		local flight = math.clamp(dist / Config.BeamSpeed, 0.1, 0.8)
		local speed = dist / flight
		local catchUp = math.max(tLen / speed, 0.02)
		local tTotal = flight + catchUp

		local folder = Instance.new("Folder")
		folder.Name = "RickPortalBeam"
		folder.Parent = workspace
		Debris:AddItem(folder, tTotal + 1)

		local function mkAnchor(name, pos)
			local p = Instance.new("Part")
			p.Name = name
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Transparency = 1
			p.Size = Vector3.new(0.1, 0.1, 0.1)
			p.CFrame = CFrame.new(pos)
			p.Parent = folder
			local a = Instance.new("Attachment")
			a.Parent = p
			return p, a
		end

		local tailPart, a0 = mkAnchor("BeamTail", fromPos)
		local headPart, a1 = mkAnchor("BeamHead", fromPos)
		local linePart = mkAnchor("BeamLine", fromPos)

		local function mkBeam(color, widthMul, baseTransp)
			local b = Instance.new("Beam")
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.Color = ColorSequence.new(color)
			b.LightEmission = 1
			b.LightInfluence = 0
			b.FaceCamera = true
			b.Segments = 1
			b.Width0 = 0
			b.Width1 = W * widthMul
			b.Transparency = NumberSequence.new(baseTransp)
			b.Parent = folder

			local cap = Instance.new("Part")
			cap.Name = "BeamCap"
			cap.Shape = Enum.PartType.Ball
			cap.Material = Enum.Material.Neon
			cap.Color = color
			cap.Transparency = baseTransp
			cap.Size = Vector3.new(1, 1, 1) * (W * widthMul)
			cap.Anchored = true
			cap.CanCollide = false
			cap.CanQuery = false
			cap.CanTouch = false
			cap.CastShadow = false
			cap.CFrame = CFrame.new(fromPos)
			cap.Parent = folder
			return {beam = b, cap = cap, mul = widthMul, base = baseTransp}
		end

		local layers = {
			mkBeam(Config.PortalColor, 3.2, 0.6),
			mkBeam(Config.PortalLight, 1.5, 0.25),
			mkBeam(Color3.fromRGB(245, 255, 240), 0.55, 0),
		}
		if Config.BeamTexture and Config.BeamTexture ~= "" then
			local mid = layers[2].beam
			mid.Texture = Config.BeamTexture
			mid.TextureMode = Enum.TextureMode.Stretch
		end

		local light = Instance.new("PointLight")
		light.Color = Config.PortalColor
		light.Brightness = 3
		light.Range = 9
		light.Parent = headPart

		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = Config.ParticleSpark2
		sparks.Color = ColorSequence.new(Config.PortalLight, Config.PortalColor)
		sparks.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0)})
		sparks.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
		sparks.Lifetime = NumberRange.new(0.15, 0.35)
		sparks.Rate = 90
		sparks.Speed = NumberRange.new(1, 3)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.LightEmission = 1
		sparks.LightInfluence = 0
		sparks.Parent = linePart

		local elapsed = 0
		local arrived = false
		local conn
		local function cleanup()
			if conn then conn:Disconnect() conn = nil end
			if folder.Parent then folder:Destroy() end
		end

		conn = RunService.Heartbeat:Connect(function(dt)
			if not Z.alive then cleanup() return end
			elapsed = elapsed + dt

			local travel = math.min(elapsed * speed, dist + tLen)
			local headPos = fromPos + unit * math.min(travel, dist)
			local tailPos = fromPos + unit * math.max(travel - tLen, 0)

			local fade = 0
			if elapsed > flight then
				fade = math.min((elapsed - flight) / catchUp, 1)
			end
			local flicker = 1 + math.sin(elapsed * 90) * 0.1

			for _, l in ipairs(layers) do
				local w = W * l.mul * flicker
				l.beam.Width1 = w
				l.cap.Size = Vector3.new(w, w, w)
				l.cap.CFrame = CFrame.new(headPos)
				if fade > 0 then
					local t = l.base + (1 - l.base) * fade
					l.beam.Transparency = NumberSequence.new(t)
					l.cap.Transparency = t
				end
			end

			tailPart.CFrame = CFrame.new(tailPos)
			headPart.CFrame = CFrame.new(headPos)
			local len = (headPos - tailPos).Magnitude
			if len > 0.05 then
				linePart.Size = Vector3.new(W * 2, W * 2, len)
				linePart.CFrame = CFrame.lookAt(tailPos:Lerp(headPos, 0.5), headPos)
			end
			light.Brightness = 3 * (1 - fade)
			sparks.Enabled = elapsed < flight

			if not arrived and elapsed >= flight then
				arrived = true
				if onArrive then
					local ok, err = pcall(onArrive)
					if not ok then warnRG("erro ao abrir portal de saída:", err) end
				end
			end

			if elapsed >= tTotal then cleanup() end
		end)
	end

	local gui = newGui("RickPortalGunGui", 1)
	local hotbarGui = newGui("RickPortalGunHotbar", 1)
	local flashGui = newGui("RickPortalGunFlash", 50)

	local aimDot = Instance.new("Frame")
	aimDot.Name = "AimDot"
	aimDot.AnchorPoint = Vector2.new(0.5, 0.5)
	aimDot.Position = UDim2.fromScale(0.5, 0.5)
	aimDot.Size = UDim2.fromOffset(4, 4)
	aimDot.BackgroundColor3 = Config.PortalLight
	aimDot.BorderSizePixel = 0
	aimDot.Visible = false
	aimDot.Parent = gui
	Instance.new("UICorner", aimDot).CornerRadius = UDim.new(1, 0)
	do
		local st = Instance.new("UIStroke")
		st.Thickness = 1
		st.Color = Color3.new(0, 0, 0)
		st.Transparency = 0.4
		st.Parent = aimDot
	end

	local function makeButton(name, text, sub, pos)
		local accent = Config.PortalColor
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.fromOffset(78, 78)
		btn.Position = pos
		btn.BackgroundColor3 = Color3.new(1, 1, 1)
		btn.BackgroundTransparency = 0.12
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Visible = false
		btn.Parent = gui
		glassGradient(btn)
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 14)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.8
		stroke.Transparency = 0.1
		stroke.Parent = btn
		tintStroke(stroke, accent, true)
		local press = Instance.new("UIScale", btn)

		local function lbl(t, font, size, pos2, sz, color)
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Text = t
			l.Font = font
			l.TextSize = size
			l.Position = pos2
			l.Size = sz
			l.TextColor3 = color
			l.Parent = btn
			return l
		end
		lbl(text, Enum.Font.GothamBlack, 18, UDim2.new(0, 0, 0.3, 0), UDim2.new(1, 0, 0, 22), Theme.Text)
		lbl(sub, Enum.Font.Code, 9, UDim2.new(0, 0, 0.62, 0), UDim2.new(1, 0, 0, 12), accent)

		local glow = Instance.new("Frame")
		glow.AnchorPoint = Vector2.new(0.5, 1)
		glow.Position = UDim2.new(0.5, 0, 1, -8)
		glow.Size = UDim2.fromOffset(30, 3)
		glow.BackgroundColor3 = accent
		glow.BorderSizePixel = 0
		glow.Parent = btn
		Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)
		TweenService:Create(glow, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.65}):Play()

		btn.MouseButton1Down:Connect(function() TweenService:Create(press, TweenInfo.new(0.08), {Scale = 0.92}):Play() end)
		btn.MouseButton1Up:Connect(function() TweenService:Create(press, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play() end)
		btn.MouseLeave:Connect(function() TweenService:Create(press, TweenInfo.new(0.15), {Scale = 1}):Play() end)
		btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.05}):Play() end)
		btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.12}):Play() end)
		return btn
	end

	local fireBtn = makeButton("RickFireButton", "FIRE", "TAP", UDim2.new(1, -186, 1, -175))
	local closeBtn = makeButton("RickCloseButton", "CLOSE", "PORTALS", UDim2.new(1, -186, 1, -270))

	local function trim(s)
		return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
	end

	local function resolvePlayer(txt)
		local q = trim(txt):lower()
		if q == "" then return nil, "Digite o nome do player" end
		local exact, prefix, contains
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				local n, d = p.Name:lower(), p.DisplayName:lower()
				if n == q or d == q then
					exact = exact or p
				elseif n:sub(1, #q) == q or d:sub(1, #q) == q then
					prefix = prefix or p
				elseif n:find(q, 1, true) or d:find(q, 1, true) then
					contains = contains or p
				end
			end
		end
		local found = exact or prefix or contains
		if found then return found end
		if q == player.Name:lower() or q == player.DisplayName:lower() then
			return nil, "Escolha outro player (nao voce)"
		end
		return nil, "Player nao encontrado"
	end

	local Dim = { list = {}, current = nil, home = nil }
	State.Dim = Dim
	do
		local Lighting = game:GetService("Lighting")
		local TAU = math.pi * 2
		local FAR_Y = 15000
		local SPACING = 2500
		local LIGHT_PROPS = {
			"Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "FogColor", "FogStart", "FogEnd",
			"ColorShift_Top", "ColorShift_Bottom", "ExposureCompensation", "GlobalShadows",
		}
		local HIDE_CLASSES = {"Sky", "Atmosphere", "BloomEffect", "ColorCorrectionEffect", "SunRaysEffect", "BlurEffect", "DepthOfFieldEffect"}

		local folder = nil
		local saved = nil
		local fxList = {}

		local function C(r, g, b) return Color3.fromRGB(r, g, b) end
		local M = Enum.Material

		local function mk(model, size, cf, color, mat, o)
			o = o or {}
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = o.solid == true
			p.CanQuery = o.solid == true
			p.CanTouch = false
			p.CastShadow = o.shadow ~= false
			p.Size = size
			if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
			p.CFrame = cf
			p.Color = color
			p.Material = mat or M.SmoothPlastic
			p.Transparency = o.trans or 0
			p.Reflectance = o.refl or 0
			if o.ball then p.Shape = Enum.PartType.Ball end
			if o.cyl then p.Shape = Enum.PartType.Cylinder end
			if o.ellipsoid then
				local m = Instance.new("SpecialMesh")
				m.MeshType = Enum.MeshType.Sphere
				m.Parent = p
			end
			p.Parent = model
			return p
		end

		local function ball(model, d, pos, color, mat, o)
			o = o or {}
			o.ball = true
			return mk(model, Vector3.new(d, d, d), pos, color, mat, o)
		end

		local function column(model, h, d, pos, color, mat, o)
			o = o or {}
			o.cyl = true
			return mk(model, Vector3.new(h, d, d), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), color, mat, o)
		end

		local function glow(part, color, brightness, range)
			local l = Instance.new("PointLight")
			l.Color = color
			l.Brightness = brightness
			l.Range = range
			l.Parent = part
			return l
		end

		local function free(x, z) return x * x + (z + 30) * (z + 30) > 2500 end

		local function emitterBox(model, size, pos, props)
			local part = mk(model, size, pos, C(255, 255, 255), nil, {trans = 1, shadow = false})
			local e = Instance.new("ParticleEmitter")
			for k, v in pairs(props) do pcall(function() e[k] = v end) end
			e.Parent = part
			return part
		end

		local BAR_SONGS = {}

		local function buildNeon(model, O, r)
			local cos, sin, abs, floor, pi, sqrt, max, min = math.cos, math.sin, math.abs, math.floor, math.pi, math.sqrt, math.max, math.min
			local V3, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
			local function rnd(a, b) return r:NextNumber(a, b) end
			local MAG, CYA = C(255, 40, 200), C(40, 230, 255)
			local VIO, YEL, ORA = C(150, 70, 255), C(255, 225, 90), C(255, 110, 150)
			local DARK = C(14, 6, 34)
			local function pick2() return (r:NextInteger(0, 1) == 0) and MAG or CYA end
			local function winCol()
				local v = r:NextNumber()
				if v < 0.35 then return CYA elseif v < 0.65 then return MAG elseif v < 0.85 then return YEL end
				return VIO
			end
			local function neon(size, cf, col, o)
				o = o or {}
				o.shadow = false
				return mk(model, size, cf, col, M.Neon, o)
			end

			mk(model, V3(2400, 2, 2400), O + V3(0, -1, 0), DARK, M.SmoothPlastic, {solid = true, refl = 0.15})
			for i = -24, 24 do
				local o = i * 50
				neon(V3(2400, 0.12, 0.6), O + V3(0, 0.06, o), MAG)
				neon(V3(0.6, 0.12, 2400), O + V3(o, 0.06, 0), CYA)
			end
			mk(model, V3(52, 0.1, 1900), O + V3(0, 0.1, 350), C(20, 10, 44), M.SmoothPlastic, {shadow = false, refl = 0.2})
			neon(V3(0.8, 0.12, 1900), O + V3(-26, 0.17, 350), MAG)
			neon(V3(0.8, 0.12, 1900), O + V3(26, 0.17, 350), CYA)
			local dashes = {}
			for i = 0, 52 do
				dashes[#dashes + 1] = neon(V3(1, 0.12, 14), O + V3(0, 0.17, -560 + i * 35), CYA)
			end

			column(model, 0.2, 42, O + V3(0, 0.19, -30), MAG, M.Neon, {shadow = false})
			column(model, 0.24, 39, O + V3(0, 0.2, -30), DARK, M.SmoothPlastic, {shadow = false})
			local pad = column(model, 0.2, 36, O + V3(0, 0.25, -30), CYA, M.Neon, {shadow = false, trans = 0.5})
			glow(pad, CYA, 2, 40)

			for i = 0, 21 do
				local z = -330 + i * 65
				for _, s in ipairs({-1, 1}) do
					local sx = s * 31
					mk(model, V3(0.7, 16, 0.7), O + V3(sx, 8, z), C(25, 15, 55), M.SmoothPlastic, {shadow = false})
					local col = ((i + (s == 1 and 1 or 0)) % 2 == 0) and MAG or CYA
					local arm = neon(V3(6, 0.6, 0.6), O + V3(sx - s * 3, 16, z), col)
					if i % 3 == 0 then glow(arm, col, 1.6, 42) end
				end
			end

			local SR, SY, SZ = 330, 250, 1000
			local nBars = 40
			local full = 2 * SR / nBars
			for k = 0, nBars - 1 do
				local t = k / (nBars - 1)
				local th = full * ((t < 0.3) and 1 or (1 - (t - 0.3) / 0.7 * 0.88))
				local y = SY + SR - k * full - full / 2
				local dy = y - SY
				local chord = 2 * sqrt(max(SR * SR - dy * dy, 0))
				if chord > 1 and y > th / 2 then
					local col
					if t < 0.45 then col = C(255, 215, 70):Lerp(C(255, 120, 60), t / 0.45) else col = C(255, 120, 60):Lerp(C(255, 35, 170), (t - 0.45) / 0.55) end
					neon(V3(chord, th, 4), O + V3(0, y, SZ), col)
				end
			end
			ball(model, SR * 2.5, O + V3(0, SY, SZ + 20), ORA, M.Neon, {shadow = false, trans = 0.92})

			for _, mx in ipairs({-190, 170}) do
				local s = 380
				local h = s * 0.7071
				mk(model, V3(s, s, 30), CF(O + V3(mx, 0, 940)) * ANG(0, 0, pi / 4), C(16, 6, 38), M.SmoothPlastic, {shadow = false})
				local col = (mx < 0) and CYA or MAG
				neon(V3(s, 1.2, 1.2), CF(O + V3(mx + h / 2, h / 2, 923)) * ANG(0, 0, -pi / 4), col)
				neon(V3(s, 1.2, 1.2), CF(O + V3(mx - h / 2, h / 2, 923)) * ANG(0, 0, pi / 4), col)
			end

			for i = -6, 6 do
				local x = i * 165 + rnd(-40, 40)
				local s = rnd(140, 320)
				local h = s * 0.7071
				mk(model, V3(s, s, 30), CF(O + V3(x, 0, 930)) * ANG(0, 0, pi / 4), C(16, 6, 38), M.SmoothPlastic, {shadow = false})
				local col = (i % 2 == 0) and MAG or CYA
				neon(V3(s, 1.2, 1.2), CF(O + V3(x + h / 2, h / 2, 913)) * ANG(0, 0, -pi / 4), col)
				neon(V3(s, 1.2, 1.2), CF(O + V3(x - h / 2, h / 2, 913)) * ANG(0, 0, pi / 4), col)
			end

			for i = 1, 70 do
				local a = i / 70 * pi * 2 + rnd(-0.05, 0.05)
				local d = rnd(760, 1050)
				local x, z = cos(a) * d, sin(a) * d
				local h, w = rnd(60, 240), rnd(30, 70)
				mk(model, V3(w, h, w), O + V3(x, h / 2, z), C(10, 5, 26), M.SmoothPlastic, {shadow = false})
				neon(V3(w + 0.4, 1.2, w + 0.4), O + V3(x, h, z), pick2())
			end

			local beacons, beams, signs, nB = {}, {}, {}, 0
			local SIGN_TEXT = {"WUBBA LUBBA\nDUB DUB", "GET\nSCHWIFTY", "BAR DO\nRICK", "C-35K", "PORTAL\nZONE", "PICKLE\nRICK", "NEON\nCITY"}

			local function makeSign(x, w, z, d, h, side, text)
				local sw = min(30, d - 4)
				local sh = 13
				local y = max(22, h * rnd(0.45, 0.7))
				local px = x - side * (w / 2 + 0.5)
				local col = pick2()
				local p = mk(model, V3(0.8, sh, sw), O + V3(px, y, z), C(8, 4, 20), M.SmoothPlastic, {shadow = false})
				local fx = px - side * 0.2
				neon(V3(0.9, 0.5, sw + 1), O + V3(fx, y + sh / 2, z), col)
				neon(V3(0.9, 0.5, sw + 1), O + V3(fx, y - sh / 2, z), col)
				neon(V3(0.9, sh + 0.5, 0.5), O + V3(fx, y, z - sw / 2), col)
				neon(V3(0.9, sh + 0.5, 0.5), O + V3(fx, y, z + sw / 2), col)
				local gui = Instance.new("SurfaceGui")
				gui.Face = (side == 1) and Enum.NormalId.Left or Enum.NormalId.Right
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 24
				gui.LightInfluence = 0
				gui.Parent = p
				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.fromScale(1, 1)
				lbl.BackgroundTransparency = 1
				lbl.Text = text
				lbl.Font = Enum.Font.GothamBlack
				lbl.TextScaled = true
				lbl.TextColor3 = col
				lbl.TextStrokeColor3 = col
				lbl.TextStrokeTransparency = 0.6
				lbl.Parent = gui
				signs[#signs + 1] = {lbl = lbl, ph = rnd(0, 6.28), fl = rnd(0.6, 1.8)}
			end

			local function building(x, z, w, d, h, side, detail)
				local body = C(15 + floor(rnd(0, 8)), 7 + floor(rnd(0, 5)), 36 + floor(rnd(0, 20)))
				mk(model, V3(w, h, d), O + V3(x, h / 2, z), body, M.SmoothPlastic, {solid = true})
				local col = pick2()
				neon(V3(w + 0.8, 0.7, d + 0.8), O + V3(x, h + 0.35, z), col)
				local px = x - side * (w / 2 + 0.12)
				local pz = z - (d / 2 + 0.12)
				if detail > 0.9 then
					local col2 = (col == MAG) and CYA or MAG
					neon(V3(0.6, h, 0.6), O + V3(x - side * (w / 2), h / 2, z - d / 2), col2)
					neon(V3(0.6, h, 0.6), O + V3(x - side * (w / 2), h / 2, z + d / 2), col2)
				end
				if detail > 0.2 then
					local step = (detail > 0.9) and 10 or 16
					local prob = (detail > 0.9) and 0.6 or 0.35
					for k = 1, floor((h - 6) / step) do
						local y = 5 + k * step
						if r:NextNumber() < prob then
							local len = rnd(0.35, 0.9) * d
							neon(V3(0.3, 2.2, len), O + V3(px, y, z + rnd(-(d - len) / 2, (d - len) / 2)), winCol())
						end
						if r:NextNumber() < prob then
							local len = rnd(0.35, 0.9) * w
							neon(V3(len, 2.2, 0.3), O + V3(x + rnd(-(w - len) / 2, (w - len) / 2), y, pz), winCol())
						end
					end
				end
				return col
			end

			local rows = {
				{edge = 62, hmul = 1.0, detail = 1.0},
				{edge = 165, hmul = 1.6, detail = 0.5},
				{edge = 290, hmul = 2.2, detail = 0.1},
			}
			for ri, row in ipairs(rows) do
				for _, side in ipairs({-1, 1}) do
					local z = -400 + rnd(0, 20)
					while z < 760 do
						local d, w = rnd(26, 44), rnd(26, 46)
						local cz = z + d / 2
						local x = side * (row.edge + rnd(0, 8) + w / 2)
						local h = (rnd(45, 110) + max(0, cz) * 0.1) * row.hmul
						if r:NextNumber() < 0.15 then h = h + rnd(40, 110) end
						local reserved = (ri == 1 and side == 1 and cz + d / 2 > -5 and cz - d / 2 < 65)
						local col = reserved and MAG or building(x, cz, w, d, h, side, row.detail)

						if not reserved and ri <= 2 and r:NextNumber() < 0.3 then
							mk(model, V3(0.6, 14, 0.6), O + V3(x, h + 7, cz), C(30, 20, 60), M.SmoothPlastic, {shadow = false})
							local bc = (r:NextInteger(0, 1) == 0) and C(255, 50, 70) or MAG
							local b = ball(model, 2.6, O + V3(x, h + 14.5, cz), bc, M.Neon, {shadow = false})
							if #beacons < 8 then glow(b, bc, 1.5, 40) end
							beacons[#beacons + 1] = {p = b, ph = rnd(0, 6.28), per = rnd(1.2, 2.4)}
						end
						if not reserved and ri == 1 and #signs < 7 and d >= 32 and h > 70 and r:NextNumber() < 0.28 then
							makeSign(x, w, cz, d, h, side, SIGN_TEXT[#signs + 1])
						end
						if not reserved and ri == 2 and #beams < 7 and r:NextNumber() < 0.12 then
							local bm = neon(V3(2.6, 2.6, 520), CF(O), col, {trans = 0.82})
							beams[#beams + 1] = {part = bm, base = O + V3(x, h + 1, cz), ph = rnd(0, 6.28),
								sp = rnd(0.3, 0.7) * ((r:NextInteger(0, 1) == 0) and 1 or -1), tilt = rnd(0.25, 0.55)}
						end

						z = z + d + rnd((row.detail > 0.9) and 6 or 14, 22)
						nB = nB + 1
						if nB % 16 == 0 then task.wait() end
					end
				end
			end

			local function updBeam(b, t)
				local phi = t * b.sp + b.ph
				local dir = V3(sin(b.tilt) * cos(phi), cos(b.tilt), sin(b.tilt) * sin(phi))
				b.part.CFrame = CFrame.lookAt(b.base, b.base + dir) * CF(0, 0, -260)
			end
			for _, b in ipairs(beams) do updBeam(b, 0) end

			local rings = {}
			for ri2, rz in ipairs({250, 520}) do
				local segs = {}
				for i = 1, 28 do
					segs[i] = neon(V3(12, 2.4, 2.4), CF(O), (i % 2 == 0) and MAG or CYA)
				end
				rings[ri2] = {segs = segs, z = rz, sp = (ri2 == 1) and 0.5 or -0.35}
			end
			local function updRing(rg, t)
				local R = 52
				for i, p in ipairs(rg.segs) do
					local a = i / 28 * pi * 2 + t * rg.sp
					p.CFrame = CF(O + V3(cos(a) * R, 62 + sin(a) * R, rg.z)) * ANG(0, 0, a + pi / 2)
				end
			end
			for _, rg in ipairs(rings) do updRing(rg, 0) end

			local cars = {}
			local function attach(root, rel, size, col, mat, o)
				local p = mk(model, size, root.CFrame * rel, col, mat, o)
				local w = Instance.new("Weld")
				w.Part0, w.Part1, w.C0 = root, p, rel
				w.Parent = p
				p.Anchored = false
				p.Massless = true
				return p
			end
			local function carCF(c, t)
				local z = ((c.z0 + c.dir * c.sp * t) + 500) % 1400 - 500
				local y = c.y + sin(t * 1.3 + c.z0) * 0.8
				return z, CF(O + V3(c.x, y, z)) * ANG(0, (c.dir == 1) and 0 or pi, sin(t * 0.9 + c.z0) * 0.04)
			end
			for i = 1, 12 do
				local c = {dir = (i % 2 == 0) and 1 or -1, x = ((i % 4 < 2) and 1 or -1) * rnd(14, 42), y = rnd(26, 78),
					sp = rnd(40, 90), z0 = rnd(-500, 900), off = 0}
				local col = pick2()
				local col2 = (col == MAG) and CYA or MAG
				local paint = col:Lerp(C(8, 4, 20), 0.82)
				local glass = C(90, 170, 230)
				local z, cf = carCF(c, 0)
				local body = mk(model, V3(4.6, 0.9, 10.4), cf, paint, M.SmoothPlastic, {shadow = false, refl = 0.3})
				c.body, c.last = body, z
				local function P(rel, size, color, mat, o) return attach(body, rel, size, color, mat, o or {shadow = false}) end

				P(CF(0, 0.5, 4.9) * ANG(0.2, 0, 0), V3(4.4, 0.4, 3.2), paint, M.SmoothPlastic, {shadow = false, refl = 0.3})
				P(CF(0, 0.5, -4.2) * ANG(0.1, 0, 0), V3(4.4, 0.4, 2.6), paint, M.SmoothPlastic, {shadow = false, refl = 0.3})

				P(CF(0, 0.9, -0.6), V3(3.5, 0.8, 4.4), glass, M.Glass, {shadow = false, trans = 0.35})
				P(CF(0, 1.38, -0.8), V3(3.3, 0.14, 3.4), paint, M.SmoothPlastic, {shadow = false, refl = 0.4})
				P(CF(0, 0.95, 1.9) * ANG(0.65, 0, 0), V3(3.4, 0.12, 1.9), glass, M.Glass, {shadow = false, trans = 0.3})

				for _, sx in ipairs({-1, 1}) do
					P(CF(sx * 1.4, 0.8, -4.6), V3(0.22, 0.9, 0.3), paint, M.SmoothPlastic)
					P(CF(sx * 2.4, 1.3, -4.9), V3(0.14, 0.5, 1.4), paint, M.SmoothPlastic)
				end
				P(CF(0, 1.3, -4.9), V3(4.8, 0.16, 1.4), paint, M.SmoothPlastic, {shadow = false, refl = 0.3})
				P(CF(0, 1.3, -5.62), V3(4.8, 0.12, 0.12), col, M.Neon)

				for _, sx in ipairs({-1, 1}) do
					P(CF(sx * 2.34, -0.3, 0), V3(0.12, 0.16, 9.4), col, M.Neon)
					P(CF(sx * 2.34, 0.15, 0), V3(0.1, 0.1, 9.4), col2, M.Neon)
				end
				P(CF(0, -0.55, 0), V3(3.8, 0.12, 8.8), col, M.Neon, {shadow = false, trans = 0.35})

				for _, sx in ipairs({-1, 1}) do
					P(CF(sx * 1.55, 0.15, 5.22), V3(1.0, 0.26, 0.16), C(230, 250, 255), M.Neon)
				end
				P(CF(0, 0.05, 5.22), V3(3.0, 0.1, 0.14), col, M.Neon)
				P(CF(0, 0.3, -5.22), V3(4.2, 0.22, 0.14), C(255, 50, 70), M.Neon)

				for _, sx in ipairs({-1, 1}) do
					P(CF(sx * 1.2, 0, -5.5) * ANG(0, pi / 2, 0), V3(0.9, 1.1, 1.1), C(30, 20, 50), M.SmoothPlastic, {shadow = false, cyl = true})
					P(CF(sx * 1.2, 0, -6.05) * ANG(0, pi / 2, 0), V3(0.2, 0.9, 0.9), col2, M.Neon, {shadow = false, cyl = true})
					P(CF(sx * 1.2, 0, -6.4), V3(1.6, 1.6, 1.6), col2, M.Neon, {shadow = false, ball = true, trans = 0.7})
				end
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Position = V3(-1.2, 0, -6.4)
				a1.Position = V3(1.2, 0, -6.4)
				a0.Parent, a1.Parent = body, body
				local tr = Instance.new("Trail")
				tr.Attachment0, tr.Attachment1 = a0, a1
				tr.Lifetime = 0.9
				tr.Color = ColorSequence.new(col2)
				tr.Transparency = NumberSequence.new(0.3, 1)
				tr.LightEmission = 1
				tr.FaceCamera = true
				tr.Parent = body
				c.tr = tr
				cars[i] = c
			end
			local function updCar(c, t)
				local z, cf = carCF(c, t)
				if abs(z - c.last) > 100 then
					c.tr.Enabled = false
					c.off = 3
				elseif c.off > 0 then
					c.off = c.off - 1
					if c.off <= 0 then c.tr.Enabled = true end
				end
				c.last = z
				c.body.CFrame = cf
			end

			local party = {on = false, ang = 0}
			local updBar = (function()
				local GRN = C(110, 255, 120)
				local BX0, W, BZ0, D, H, T = 62, 44, 5, 50, 24, 1.5
				local BX1, BZ1 = BX0 + W, BZ0 + D
				local cz, mx = BZ0 + D / 2, BX0 + W / 2
				local WALL = C(26, 12, 58)
				local function wall(size, pos)
					return mk(model, size, O + pos, WALL, M.SmoothPlastic, {solid = true})
				end

				mk(model, V3(W, 0.25, D), O + V3(mx, 0.125, cz), C(34, 18, 46), M.SmoothPlastic, {solid = true, refl = 0.12})
				wall(V3(T, H, D), V3(BX1 - T / 2, H / 2, cz))
				wall(V3(W, H, T), V3(mx, H / 2, BZ0 + T / 2))
				wall(V3(W, H, T), V3(mx, H / 2, BZ1 - T / 2))
				wall(V3(W + 1, 1.5, D + 1), V3(mx, H + 0.75, cz))

				local fx = BX0 + T / 2
				local DOORW, DOORH = 9, 11
				local function frontPiece(za, zb)
					local len, zc = zb - za, (za + zb) / 2
					wall(V3(T, 3.5, len), V3(fx, 1.75, zc))
					wall(V3(T, H - 9, len), V3(fx, 9 + (H - 9) / 2, zc))
					wall(V3(T, 5.5, 4), V3(fx, 6.25, za + 2))
					wall(V3(T, 5.5, 4), V3(fx, 6.25, zb - 2))
					mk(model, V3(0.3, 5.5, len - 8), O + V3(fx, 6.25, zc), C(120, 210, 255), M.Glass, {solid = true, trans = 0.55, shadow = false})
					neon(V3(0.3, 0.3, len - 8), O + V3(BX0 - 0.1, 3.5, zc), GRN)
					neon(V3(0.3, 0.3, len - 8), O + V3(BX0 - 0.1, 9, zc), GRN)
				end
				frontPiece(BZ0 + T, cz - DOORW / 2)
				frontPiece(cz + DOORW / 2, BZ1 - T)
				wall(V3(T, H - DOORH, DOORW), V3(fx, DOORH + (H - DOORH) / 2, cz))

				neon(V3(0.4, DOORH, 0.4), O + V3(BX0 - 0.1, DOORH / 2, cz - DOORW / 2), GRN)
				neon(V3(0.4, DOORH, 0.4), O + V3(BX0 - 0.1, DOORH / 2, cz + DOORW / 2), GRN)
				neon(V3(0.4, 0.4, DOORW + 0.4), O + V3(BX0 - 0.1, DOORH + 0.2, cz), GRN)
				mk(model, V3(4.4, 10.6, 0.35), O + V3(BX0 + T + 2.4, 5.4, cz - DOORW / 2 + 0.4), C(120, 210, 255), M.Glass, {trans = 0.5, shadow = false})
				neon(V3(4.4, 0.2, 0.45), O + V3(BX0 + T + 2.4, 10.7, cz - DOORW / 2 + 0.4), GRN)

				for _, zz in ipairs({BZ0 - 0.1, BZ1 + 0.1}) do
					neon(V3(0.6, H, 0.6), O + V3(BX0 - 0.1, H / 2, zz), GRN)
					neon(V3(0.6, H, 0.6), O + V3(BX1 + 0.1, H / 2, zz), GRN)
					neon(V3(W + 1.4, 0.5, 0.5), O + V3(mx, H + 1.6, zz + (zz < cz and -0.4 or 0.4)), MAG)
				end
				for _, xx in ipairs({BX0 - 0.5, BX1 + 0.5}) do
					neon(V3(0.5, 0.5, D + 1.4), O + V3(xx, H + 1.6, cz), MAG)
				end

				local function signGui(part, face, text, color)
					local gui = Instance.new("SurfaceGui")
					gui.Face = face
					gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
					gui.PixelsPerStud = 24
					gui.LightInfluence = 0
					gui.Parent = part
					local lbl = Instance.new("TextLabel")
					lbl.Size = UDim2.fromScale(1, 1)
					lbl.BackgroundTransparency = 1
					lbl.Text = text
					lbl.Font = Enum.Font.GothamBlack
					lbl.TextScaled = true
					lbl.TextColor3 = color
					lbl.TextStrokeColor3 = color
					lbl.TextStrokeTransparency = 0.6
					lbl.Parent = gui
				end
				local sp = mk(model, V3(0.8, 9, 40), O + V3(BX0 - 0.6, 17.5, cz), C(8, 4, 20), M.SmoothPlastic, {shadow = false})
				neon(V3(0.9, 0.5, 41), O + V3(BX0 - 0.9, 22, cz), GRN)
				neon(V3(0.9, 0.5, 41), O + V3(BX0 - 0.9, 13, cz), GRN)
				neon(V3(0.9, 9.5, 0.5), O + V3(BX0 - 0.9, 17.5, cz - 20), MAG)
				neon(V3(0.9, 9.5, 0.5), O + V3(BX0 - 0.9, 17.5, cz + 20), MAG)
				signGui(sp, Enum.NormalId.Left, "BAR DO RICK", GRN)

				local PR, pcx, pcy = 9, BX0 + 12, H + 1.5 + 11
				mk(model, V3(0.5, PR * 2 - 2, PR * 2 - 2), CF(O + V3(pcx, pcy, cz)), GRN, M.Neon, {cyl = true, trans = 0.55, shadow = false})
				local psegs = {}
				for i = 1, 20 do
					psegs[i] = neon(V3(2.2, 2.2, 3.4), CF(O), (i % 2 == 0) and GRN or C(190, 255, 130))
				end
				local function updPortal(t)
					for i, p in ipairs(psegs) do
						local a = i / 20 * pi * 2 + t * 0.8
						p.CFrame = CF(O + V3(pcx, pcy + sin(a) * PR, cz + cos(a) * PR)) * ANG(-(a + pi / 2), 0, 0)
					end
				end
				updPortal(0)

				local sitting = false
				local function sittable(pos, face)
					local seat = mk(model, V3(2.2, 0.3, 2.2), CFrame.lookAt(O + pos, O + pos + face), DARK, M.SmoothPlastic, {trans = 1, shadow = false})
					pcall(function()
						local pp = Instance.new("ProximityPrompt")
						pp.ActionText = "Sentar"
						pp.ObjectText = "Banquinho"
						pp.HoldDuration = 0
						pp.MaxActivationDistance = 7
						pp.RequiresLineOfSight = false
						pp.Parent = seat
						pp.Triggered:Connect(function()
							if sitting then return end
							local char = player.Character
							local hum = char and char:FindFirstChildOfClass("Humanoid")
							local hrp = char and char:FindFirstChild("HumanoidRootPart")
							if not hum or not hrp or hum.Health <= 0 or hum.Sit then return end
							sitting = true
							pp.Enabled = false
							hum.Sit = true
							hrp.CFrame = seat.CFrame * CFrame.new(0, 1.35, 0)
							local weld = Instance.new("Weld")
							weld.Part0, weld.Part1 = seat, hrp
							weld.C0 = CFrame.new(0, 1.35, 0)
							weld.Parent = seat
							task.spawn(function()
								local t0 = os.clock()
								while weld.Parent and hum.Parent and hum.Health > 0 do
									if os.clock() - t0 > 0.6 and (hum.Jump or hum.MoveDirection.Magnitude > 0.2 or not hum.Sit) then break end
									RunService.Heartbeat:Wait()
								end
								pcall(function() weld:Destroy() end)
								hum.Sit = false
								if hrp.Parent then
									hrp.CFrame = CFrame.new(hrp.Position + face * 2.5 + V3(0, 1, 0))
								end
								sitting = false
								pp.Enabled = true
							end)
						end)
					end)
					return seat
				end

				local top = neon(V3(3.2, 0.3, 28.4), O + V3(97, 4.15, cz), GRN, {trans = 0.2})
				glow(top, GRN, 1.2, 28)
				mk(model, V3(3, 4, 28), O + V3(97, 2, cz), C(28, 14, 60), M.SmoothPlastic, {solid = true, refl = 0.2})
				neon(V3(0.3, 0.4, 28), O + V3(95.4, 2, cz), MAG)
				for i = 0, 5 do
					local sz = cz - 12.5 + i * 5
					column(model, 0.2, 2, O + V3(93.3, 0.35, sz), C(30, 20, 60), M.SmoothPlastic, {shadow = false})
					mk(model, V3(0.3, 2.2, 0.3), O + V3(93.3, 1.4, sz), C(30, 20, 60), M.SmoothPlastic, {shadow = false})
					column(model, 0.7, 2.6, O + V3(93.3, 2.6, sz), C(200, 30, 150), M.SmoothPlastic, {shadow = false})
					sittable(V3(93.3, 2.8, sz), V3(1, 0, 0))
				end

				neon(V3(0.2, 8, 26), O + V3(BX1 - T - 0.2, 8.4, cz), VIO, {trans = 0.55})
				local bottleCols = {GRN, MAG, CYA, YEL}
				local DKP = C(20, 10, 40)
				local function bottle(x, y, z, kind, col)
					local pos = O + V3(x, y, z)
					local gl = col:Lerp(C(255, 255, 255), 0.75)
					local function G(h, d, dy, c, mat, o) return column(model, h, d, pos + V3(0, dy, 0), c, mat, o or {shadow = false}) end
					if kind == 1 then
						G(2.6, 0.95, 1.3, gl, M.Glass, {shadow = false, trans = 0.55})
						G(2.0, 0.78, 1.05, col, M.Neon, {shadow = false, trans = 0.1})
						G(0.9, 0.42, 3.05, gl, M.Glass, {shadow = false, trans = 0.5})
						G(0.25, 0.55, 3.6, DKP, M.SmoothPlastic)
						G(0.8, 0.98, 1.3, DKP, M.SmoothPlastic)
						G(0.1, 1.0, 1.62, col, M.Neon)
						G(0.1, 1.0, 0.98, col, M.Neon)
					elseif kind == 2 then
						ball(model, 1.9, pos + V3(0, 0.95, 0), gl, M.Glass, {shadow = false, trans = 0.55})
						ball(model, 1.55, pos + V3(0, 0.8, 0), col, M.Neon, {shadow = false, trans = 0.1})
						G(1.1, 0.48, 2.3, gl, M.Glass, {shadow = false, trans = 0.5})
						G(0.1, 0.62, 2.55, col, M.Neon)
						G(0.3, 0.6, 3.0, DKP, M.SmoothPlastic)
					else
						mk(model, V3(1.5, 2.2, 0.7), CF(pos + V3(0, 1.1, 0)), gl, M.Glass, {shadow = false, trans = 0.55})
						mk(model, V3(1.25, 1.7, 0.5), CF(pos + V3(0, 0.95, 0)), col, M.Neon, {shadow = false, trans = 0.1})
						mk(model, V3(1.52, 0.25, 0.72), CF(pos + V3(0, 1.55, 0)), DKP, M.SmoothPlastic, {shadow = false})
						G(0.8, 0.5, 2.6, gl, M.Glass, {shadow = false, trans = 0.5})
						G(0.3, 0.62, 3.15, DKP, M.SmoothPlastic)
					end
				end
				for _, sy in ipairs({6.2, 10.6}) do
					mk(model, V3(1.4, 0.3, 26), O + V3(BX1 - T - 0.9, sy, cz), C(40, 20, 70), M.SmoothPlastic, {shadow = false})
					neon(V3(1.4, 0.1, 26), O + V3(BX1 - T - 0.9, sy - 0.2, cz), MAG)
					for i = 0, 11 do
						bottle(BX1 - T - 0.9, sy + 0.15, cz - 12 + i * 2.18, r:NextInteger(1, 3), bottleCols[r:NextInteger(1, #bottleCols)])
					end
				end

				local function cup(b, liq, dyn, par, sc)
					sc = sc or 1
					par = par or model
					local held = par ~= model
					local parts, info = {}, {groups = {ice = {}, straw = {}, lime = {}}}
					local root
					if dyn then
						root = mk(par, V3(0.2, 0.2, 0.2), CF(b), DARK, M.SmoothPlastic, {trans = 1, shadow = false})
						parts[1] = root
						info.root = root
					end
					local WHT = C(255, 255, 255)
					local function P(rel, size, col, mat, o, grp)
						o = o or {}
						if o.shadow == nil then o.shadow = false end
						rel = CFrame.new(rel.Position * sc) * rel.Rotation
						size = size * sc
						local p
						if dyn then
							p = attach(root, rel, size, col, mat, o)
							if held then p.Parent = par end
						else
							p = mk(par, size, CF(b) * rel, col, mat, o)
						end
						parts[#parts + 1] = p
						if dyn and grp then
							local w = p:FindFirstChildOfClass("Weld")
							local g = info.groups[grp]
							g[#g + 1] = {p = p, w = w, rest = w.C0, tr = p.Transparency}
						end
						return p
					end
					local function CY(y, h, d, col, mat, o, grp)
						o = o or {}
						o.cyl = true
						return P(CF(0, y, 0) * ANG(0, 0, pi / 2), V3(h, d, d), col, mat, o, grp)
					end
					local glassC = C(205, 235, 255)
					CY(0.05, 0.1, 0.9, glassC, M.Glass, {trans = 0.35})
					CY(0.95, 1.7, 1.3, glassC, M.Glass, {trans = 0.6})
					info.rim = CY(1.82, 0.05, 1.36, liq, M.Neon, {trans = 0.25})

					local Y0, HT = 0.12, 1.4
					info.Y0, info.HT = Y0, HT
					local layers, acc = {}, 0
					local frac = {0.38, 0.34, 0.28}
					local lcol = {liq:Lerp(DARK, 0.4), liq, liq:Lerp(WHT, 0.4)}
					for i = 1, 3 do
						local len = HT * frac[i]
						layers[i] = {p = CY(Y0 + acc + len / 2, len, 1.12, lcol[i], M.Neon, {trans = 0.12}), s = acc, len = len}
						acc = acc + len
					end
					local foam = CY(Y0 + HT + 0.04, 0.1, 1.12, liq:Lerp(WHT, 0.6), M.Neon, {trans = 0.3})

					P(CF(0.2, 1.0, 0.1) * ANG(0.5, 0.4, 0.2), V3(0.4, 0.4, 0.4), WHT, M.Glass, {trans = 0.4}, "ice")
					P(CF(-0.2, 0.8, -0.15) * ANG(0.2, 0.7, 0.5), V3(0.35, 0.35, 0.35), WHT, M.Glass, {trans = 0.4}, "ice")
					P(CF(0.05, 1.2, -0.25) * ANG(0.9, 0.1, 0.6), V3(0.32, 0.32, 0.32), WHT, M.Glass, {trans = 0.4}, "ice")

					local strawRel = CF(0.2, 1.3, 0) * ANG(0, 0, -0.2)
					P(strawRel, V3(0.1, 2.3, 0.1), WHT, M.SmoothPlastic, {}, "straw")
					for _, off in ipairs({-0.6, 0.1, 0.8}) do
						P(strawRel * CF(0, off, 0), V3(0.11, 0.28, 0.11), MAG, M.Neon, {}, "straw")
					end
					P(strawRel * CF(-0.1, 1.2, 0) * ANG(0, 0, 0.9), V3(0.1, 0.45, 0.1), WHT, M.SmoothPlastic, {}, "straw")

					P(CF(-0.58, 1.78, 0) * ANG(0, 0, 0.5), V3(0.1, 0.95, 0.95), C(130, 255, 90), M.Neon, {cyl = true, trans = 0.15}, "lime")
					P(CF(-0.58, 1.78, 0) * ANG(0, 0, 0.5), V3(0.12, 0.78, 0.78), C(235, 255, 160), M.Neon, {cyl = true, trans = 0.2}, "lime")

					if dyn then
						info.light = glow(root, liq, held and 0.6 or 1.0, held and 7 or 14)
						local function EM(part, props)
							local e = Instance.new("ParticleEmitter")
							e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
							e.Rate = 0
							e.LightEmission = 1
							e.Color = ColorSequence.new(liq:Lerp(WHT, 0.35), liq)
							e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.28 * sc), NumberSequenceKeypoint.new(1, 0)})
							e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
							for k, v in pairs(props) do pcall(function() e[k] = v end) end
							e.Parent = part
							return e
						end
						local bubP = P(CF(0, Y0, 0), V3(0.8, 0.1, 0.8), WHT, M.SmoothPlastic, {trans = 1})
						local bubW = bubP:FindFirstChildOfClass("Weld")
						info.bub = EM(bubP, {Lifetime = NumberRange.new(0.5, 1.0), Speed = NumberRange.new(1, 2.2), SpreadAngle = Vector2.new(20, 20), Acceleration = V3(0, -2, 0)})
						info.spark = EM(root, {Lifetime = NumberRange.new(0.5, 1.1), Speed = NumberRange.new(3, 7), SpreadAngle = Vector2.new(180, 180), Acceleration = V3(0, -6, 0)})
						local fw = foam:FindFirstChildOfClass("Weld")
						for _, L in ipairs(layers) do L.w = L.p:FindFirstChildOfClass("Weld") end

						info.fill = function(k)
							local h = HT * math.clamp(k, 0, 1)
							for _, L in ipairs(layers) do
								local hh = math.clamp(h - L.s, 0, L.len)
								if hh < 0.06 then
									L.p.Transparency = 1
								else
									L.p.Transparency = 0.12
									L.p.Size = V3(hh, 1.12, 1.12) * sc
									L.w.C0 = CF(0, (Y0 + L.s + hh / 2) * sc, 0) * ANG(0, 0, pi / 2)
								end
							end
							foam.Transparency = (h < 0.06) and 1 or 0.3
							fw.C0 = CF(0, (Y0 + h + 0.04) * sc, 0) * ANG(0, 0, pi / 2)
							bubW.C0 = CF(0, (Y0 + h) * sc, 0)
						end
						if held then

							info.fill(1)
							root.Anchored = false
							root.Name = "Handle"
							root.Massless = true
						else
							info.fill(0)
							for _, g in pairs(info.groups) do
								for _, e in ipairs(g) do e.p.Transparency = 1 end
							end
						end
					end
					return parts, info
				end
				for _, dz in ipairs({-11, -6.5, 3.5, 8, 12}) do
					cup(O + V3(97.8, 4.3, cz + dz), bottleCols[r:NextInteger(1, #bottleCols)])
				end

				local fl = mk(model, V3(20, 5, 0.5), O + V3(92, 15, BZ0 + T + 0.9), C(8, 4, 20), M.SmoothPlastic, {shadow = false})
				for _, px in ipairs({-8, 8}) do
					mk(model, V3(0.3, 0.3, 0.9), O + V3(92 + px, 15, BZ0 + T + 0.45), C(40, 20, 70), M.SmoothPlastic, {shadow = false})
				end
				neon(V3(20.4, 0.3, 0.4), O + V3(92, 17.6, BZ0 + T + 0.95), GRN)
				neon(V3(20.4, 0.3, 0.4), O + V3(92, 12.4, BZ0 + T + 0.95), GRN)
				neon(V3(0.3, 5.2, 0.4), O + V3(82, 15, BZ0 + T + 0.95), GRN)
				neon(V3(0.3, 5.2, 0.4), O + V3(102, 15, BZ0 + T + 0.95), GRN)
				signGui(fl, Enum.NormalId.Front, "PORTAL FLUID", GRN)
				signGui(fl, Enum.NormalId.Back, "PORTAL FLUID", GRN)

				for _, tb in ipairs({{68, 12}, {68, 48}, {86, 46}, {88, 14}}) do
					local tx, tz = tb[1], tb[2]
					column(model, 0.2, 2.4, O + V3(tx, 0.35, tz), C(30, 20, 60), M.SmoothPlastic, {shadow = false})
					mk(model, V3(0.6, 2.8, 0.6), O + V3(tx, 1.5, tz), C(30, 20, 60), M.SmoothPlastic, {shadow = false})
					column(model, 0.4, 4.2, O + V3(tx, 3.1, tz), C(24, 12, 52), M.SmoothPlastic, {shadow = false, refl = 0.2})
					column(model, 0.3, 4.5, O + V3(tx, 2.85, tz), pick2(), M.Neon, {shadow = false})
					cup(O + V3(tx + 0.7, 3.3, tz + 0.5), bottleCols[r:NextInteger(1, #bottleCols)])
					for _, sz in ipairs({-2.9, 2.9}) do
						column(model, 0.6, 1.8, O + V3(tx, 1.7, tz + sz), C(200, 30, 150), M.SmoothPlastic, {shadow = false})
						mk(model, V3(0.3, 1.4, 0.3), O + V3(tx, 0.9, tz + sz), C(30, 20, 60), M.SmoothPlastic, {shadow = false})
						sittable(V3(tx, 1.85, tz + sz), V3(0, 0, -sz / 2.9))
					end
				end

				local tiles = {}
				for i = 0, 3 do
					for j = 0, 4 do
						tiles[#tiles + 1] = {p = neon(V3(4, 0.12, 4), O + V3(68 + i * 4.4, 0.31, cz - 10 + j * 4.4), MAG), s = (i + j) * 0.8}
					end
				end

				local ceil = {}
				for i, cx in ipairs({70, 80, 90, 100}) do
					local p = neon(V3(0.8, 0.4, 40), O + V3(cx, H - 0.3, cz), MAG)
					ceil[i] = {p = p, l = glow(p, MAG, 0.9, 30)}
				end
				mk(model, V3(0.1, 4, 0.1), O + V3(74.6, H - 2, cz + 0.5), C(60, 60, 80), M.SmoothPlastic, {shadow = false})
				local discoBall = ball(model, 3.6, O + V3(74.6, H - 4.4, cz + 0.5), C(215, 215, 235), M.Metal, {shadow = false, refl = 0.6})
				local discoLight = glow(discoBall, CYA, 1.2, 35)

				local GREET = {
					"A-aw geez, bem-vindo ao Bar do Rick! Senta ai que eu preparo algo.",
					"Opa, cliente novo! O Rick disse pra eu nao deixar ninguem tocar no fluido de portal... mas toma um.",
					"Entra, entra! Aqui o multiverso inteiro toma uma, ah... geez.",
				}
				local IDLE = {
					"Aperte E aqui pra pedir um drink.",
					"Ja provou o Synthwave Sour? E, tipo, muito bom.",
					"Cuidado com o fluido de portal... ele e forte, Rick que disse.",
					"Aqui ninguem paga imposto interdimensional, eu acho.",
				}
				local FLAVORS = {
					{name = "Fluido de Portal", liquid = GRN, fx = "portal", desc = "Tela verde com ondas"},
					{name = "Synthwave Sour", liquid = MAG, fx = "synth", desc = "Neon rosa pulsando"},
					{name = "Cyan Dream", liquid = CYA, fx = "cyan", desc = "Câmera lenta"},
					{name = "Sol Neon", liquid = YEL, fx = "sol", desc = "Arco-íris ondulante"},
				}
				local BXp = V3(100.0, 0, cz - 3)
				local MS = 1.4
				local BASE = CF(O + BXp + V3(0, 3 * MS + 0.15, 0)) * ANG(0, pi / 2, 0)

				local MR = (function()
					local SKIN, MYEL, MBLU = C(250, 208, 160), C(255, 214, 52), C(44, 84, 168)
					local rig = Instance.new("Model")
					rig.Name = "Morty"
					rig.Parent = model

					local root = mk(rig, V3(2, 2, 1) * MS, BASE, DARK, M.SmoothPlastic, {trans = 1, shadow = false})
					root.Name = "HumanoidRootPart"
					local function MP(name, size, col)
						local p = mk(rig, size * MS, BASE, col, M.SmoothPlastic, {shadow = false})
						p.Name = name
						p.Anchored = false
						p.Massless = true
						return p
					end
					local torso = MP("Torso", V3(2, 2, 1), MYEL)
					local head = MP("Head", V3(2, 1, 1), SKIN)
					local lArm = MP("Left Arm", V3(1, 2, 1), SKIN)
					local rArm = MP("Right Arm", V3(1, 2, 1), SKIN)
					local lLeg = MP("Left Leg", V3(1, 2, 1), MBLU)
					local rLeg = MP("Right Leg", V3(1, 2, 1), MBLU)

					local hm = Instance.new("SpecialMesh")
					hm.MeshType = Enum.MeshType.Head
					hm.Scale = V3(1.25, 1.25, 1.25)
					hm.Parent = head
					local face = Instance.new("Decal")
					face.Name = "face"
					face.Texture = "rbxasset://textures/face.png"
					face.Face = Enum.NormalId.Front
					face.Parent = head

					local function joint(name, p0, p1, c0, c1)
						local m = Instance.new("Motor6D")
						m.Name = name
						m.Part0, m.Part1 = p0, p1
						m.C0, m.C1 = c0, c1
						m.Parent = p0
						return m
					end
					local RJ = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
					joint("RootJoint", root, torso, RJ, RJ)
					local neck = joint("Neck", torso,  head,
						CFrame.new(0, 1 * MS, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
						CFrame.new(0, -0.5 * MS, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
					local rShoulder = joint("Right Shoulder", torso, rArm,
						CFrame.new(1 * MS, 0.5 * MS, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
						CFrame.new(-0.5 * MS, 0.5 * MS, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
					local lShoulder = joint("Left Shoulder", torso, lArm,
						CFrame.new(-1 * MS, 0.5 * MS, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
						CFrame.new(0.5 * MS, 0.5 * MS, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
					local rHip = joint("Right Hip", torso, rLeg,
						CFrame.new(1 * MS, -1 * MS, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
						CFrame.new(0.5 * MS, 1 * MS, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
					local lHip = joint("Left Hip", torso, lLeg,
						CFrame.new(-1 * MS, -1 * MS, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
						CFrame.new(-0.5 * MS, 1 * MS, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))

					local rigAtt = {}
					local function AT(part, name, pos)
						local at = Instance.new("Attachment")
						at.Name = name
						at.Position = pos * MS
						at.Parent = part
						rigAtt[name] = at
					end
					AT(head, "FaceCenterAttachment", V3(0, 0, 0))
					AT(head, "FaceFrontAttachment", V3(0, 0, -0.6))
					AT(head, "HairAttachment", V3(0, 0.6, 0))
					AT(head, "HatAttachment", V3(0, 0.6, 0))
					AT(torso, "NeckAttachment", V3(0, 1, 0))
					AT(torso, "BodyFrontAttachment", V3(0, 0, -0.5))
					AT(torso, "BodyBackAttachment", V3(0, 0, 0.5))
					AT(torso, "LeftCollarAttachment", V3(-1, 1, 0))
					AT(torso, "RightCollarAttachment", V3(1, 1, 0))
					AT(torso, "WaistFrontAttachment", V3(0, -1, -0.5))
					AT(torso, "WaistCenterAttachment", V3(0, -1, 0))
					AT(torso, "WaistBackAttachment", V3(0, -1, 0.5))

					local hum = Instance.new("Humanoid")
					pcall(function() hum.RigType = Enum.HumanoidRigType.R6 end)
					pcall(function() hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
					pcall(function() hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff end)
					pcall(function() hum.EvaluateStateMachine = false end)
					hum.Parent = rig
					rig.PrimaryPart = root

					local rag = attach(lArm, CF(0, -1 * MS - 0.05, 0), V3(1.0, 0.3, 0.9), C(190, 205, 230), M.SmoothPlastic, {shadow = false, trans = 1})

					local shRel = CF(0, -1 * MS - 0.3, 0) * ANG(0, 0, pi / 2)
					local shk = attach(rArm, shRel, V3(1.5, 0.8, 0.8), C(190, 200, 220), M.Metal, {shadow = false, cyl = true})
					attach(rArm, shRel, V3(0.3, 0.9, 0.9), GRN, M.Neon, {shadow = false, cyl = true})
					local shEm = Instance.new("ParticleEmitter")
					shEm.Texture = "rbxasset://textures/particles/sparkles_main.dds"
					shEm.Rate = 0
					shEm.LightEmission = 1
					shEm.Lifetime = NumberRange.new(0.5, 0.9)
					shEm.Speed = NumberRange.new(2, 5)
					shEm.SpreadAngle = Vector2.new(60, 60)
					shEm.Acceleration = V3(0, -5, 0)
					shEm.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0)})
					shEm.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
					shEm.Parent = shk

					local function clothing(cls, prop, id)
						local obj = fetchAccessoryModel(id)
						local item
						if obj then
							item = obj:IsA(cls) and obj or obj:FindFirstChildWhichIsA(cls, true)
						end
						if not item then
							item = Instance.new(cls)
							pcall(function() item[prop] = "rbxassetid://" .. tostring(id) end)
						end
						if not rig.Parent then
							pcall(function() item:Destroy() end)
						else
							item.Parent = rig
						end
						if obj and obj ~= item then pcall(function() obj:Destroy() end) end
					end

					local function dress(id)
						local obj, err = fetchAccessoryModel(id)
						if not obj then
							warnRG("Morty: nao foi possivel carregar o acessorio " .. tostring(id) .. " (" .. tostring(err) .. ")")
							return
						end
						local acc = obj:IsA("Accessory") and obj or obj:FindFirstChildWhichIsA("Accessory", true)
						local src = acc and acc:FindFirstChild("Handle")
						if not src then
							src = (obj:IsA("BasePart") and obj) or obj:FindFirstChild("Handle", true)
						end
						if not (src and src:IsA("BasePart")) then
							pcall(function() obj:Destroy() end)
							warnRG("Morty: acessorio " .. tostring(id) .. " sem Handle")
							return
						end
						local h = src:Clone()
						local ap = acc and acc.AttachmentPoint or CFrame.new()
						pcall(function() obj:Destroy() end)
						if not rig.Parent then h:Destroy() return end
						for _, d in ipairs(h:GetDescendants()) do
							if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Sound")
								or d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then
								d:Destroy()
							end
						end
						h.Anchored, h.CanCollide, h.CanQuery, h.CanTouch, h.Massless = false, false, false, false, true
						h.CastShadow = false
						h.Size = h.Size * MS
						for _, d in ipairs(h:GetChildren()) do
							if d:IsA("SpecialMesh") then
								d.Scale = d.Scale * MS
							elseif d:IsA("Attachment") then
								d.Position = d.Position * MS
							end
						end
						local part0, c0, c1
						for _, d in ipairs(h:GetChildren()) do
							if d:IsA("Attachment") and rigAtt[d.Name] then
								part0, c0, c1 = rigAtt[d.Name].Parent, rigAtt[d.Name].CFrame, d.CFrame
								break
							end
						end
						if not part0 then
							part0 = head
							c0 = CFrame.new(0, 0.5 * MS, 0)
							c1 = CFrame.new(ap.Position * MS) * (ap - ap.Position)
						end
						h.CFrame = part0.CFrame * c0 * c1:Inverse()
						local w = Instance.new("Weld")
						w.Part0, w.Part1, w.C0, w.C1 = part0, h, c0, c1
						w.Parent = h
						h.Parent = rig
					end

					local function mkIK(joint, sx, len)
						local c1 = joint.C1
						local sL = V3(sx * MS, 0.5 * MS, 0)
						return function(want)
							local dl = root.CFrame:PointToObjectSpace(want) - sL
							if dl.Magnitude < 0.05 then return nil end
							local up = -dl.Unit
							local xa = V3(1, 0, 0) - up * up.X
							if xa.Magnitude < 0.05 then xa = V3(0, 0, 1) - up * up.Z end
							xa = xa.Unit
							local R = CFrame.fromMatrix(V3(0, 0, 0), xa, up)
							local A = CFrame.fromMatrix(sL - R:VectorToWorldSpace(c1.Position), xa, up)
							return A * c1
						end
					end
					task.spawn(clothing, "Shirt", "ShirtTemplate", "70540651523892")
					task.spawn(clothing, "Pants", "PantsTemplate", "88425125226234")
					task.spawn(dress, "78898300239369")
					task.spawn(dress, "139792469671352")

					return {
						root = root, torso = torso, head = head, neck = neck, rShoulder = rShoulder,
						neckC0 = neck.C0, shoulderC0 = rShoulder.C0,
						shaker = shk, shakeEm = shEm, armA = 0.12,
						lShoulder = lShoulder, lC0 = lShoulder.C0, lLen = 2.3, rBlend = 0,
						rHip = rHip, lHip = lHip, rHipC0 = rHip.C0, lHipC0 = lHip.C0, rag = rag,
						ikL = mkIK(lShoulder, -1, 2.3), ikR = mkIK(rShoulder, 1, 2.4),
					}
				end)()
				local torso, head = MR.torso, MR.head

				local DR = (function()
					local D = {}
					local WHT = C(255, 255, 255)
					local GLASS = C(205, 235, 255)
					local function ease(k) return k * k * (3 - 2 * k) end
					local function run(dur, fn, alive)
						alive = alive or function() return model.Parent ~= nil end
						local t0 = os.clock()
						while alive() do
							local k = (os.clock() - t0) / dur
							if k >= 1 then fn(1) return true end
							fn(k)
							RunService.Heartbeat:Wait()
						end
						return false
					end
					local function bez(a, c, b, u)
						local v = 1 - u
						return a * (v * v) + c * (2 * v * u) + b * (u * u)
					end
					local function ring(pos, col, d)
						local rg = column(model, 0.08, 0.5, pos, col, M.Neon, {shadow = false, trans = 0.2})
						task.spawn(function()
							run(0.55, function(k)
								local s = 0.5 + d * k
								rg.Size = V3(0.08, s, s)
								rg.Transparency = 0.2 + 0.8 * k
							end)
							pcall(function() rg:Destroy() end)
						end)
					end

					local function handPoint(d)
						return MR.root.CFrame:PointToWorldSpace(V3(-MS, 0.5 * MS, 0) + d * MR.lLen)
					end

					function D.shakeFx(on, col)
						local em = MR.shakeEm
						if on then
							em.Color = ColorSequence.new(col:Lerp(WHT, 0.35), col)
							em.Rate = 50
						else
							em.Rate = 0
						end
					end

					function D.make(liq)

						local sL = V3(-MS, 0.5 * MS, 0)
						local hy = (O.Y + 4.3 + 0.95) - BASE.Position.Y
						local dy = (hy - sL.Y) / MR.lLen
						local dx = (-0.45 * MS - sL.X) / MR.lLen
						local dz = -math.sqrt(math.max(0.01, 1 - dx * dx - dy * dy))
						local dP = V3(dx, dy, dz)
						local base = BASE:PointToWorldSpace(sL + dP * MR.lLen) - V3(0, 0.95, 0)

						local parts, info = cup(base + V3(0, -500, 0), liq, true)
						local root = info.root
						local extras = {}
						local cur = base
						local dk = {}
						local function place(p, y, yaw, tilt)
							root.CFrame = CF(p + V3(0, y or 0, 0)) * ANG(0, yaw or 0, tilt or 0)
						end
						place(base, -500, 0, 0)
						function dk.wipe()
							for _, p in ipairs(parts) do pcall(function() p:Destroy() end) end
							for _, p in ipairs(extras) do pcall(function() p:Destroy() end) end
						end

						function dk.fetch()
							local d0 = V3(0, -1, 0)
							local d1 = V3(-0.1, -0.78, 0.62).Unit
							run(0.5, function(k) MR.lWant = handPoint(d0:Lerp(d1, ease(k)).Unit) end)
							do
								local hp = handPoint(d1)
								MR.lWant = hp
								place(hp - V3(0, 0.95, 0), 0, 0, 0)
							end
							info.spark:Emit(10)
							run(0.15, function()
								local hp = handPoint(d1)
								MR.lWant = hp
								place(hp - V3(0, 0.95, 0), 0, 0, 0)
							end)
							run(0.8, function(k)
								local e = ease(k)
								local hp = handPoint((d1:Lerp(dP, e) + V3(0, 0.5 * sin(e * pi), 0)).Unit)
								MR.lWant = hp
								place(hp - V3(0, 0.95, 0), 0, 0, sin(e * pi * 2) * 0.08)
							end)
							place(base, 0, 0, 0)
							ring(base + V3(0, 0.1, 0), liq, 3)
							info.spark:Emit(8)
							run(0.4, function(k) MR.lWant = handPoint(dP:Lerp(d0, ease(k)).Unit) end)
							MR.lWant = nil
						end

						function dk.pour()
							MR.rWant = base + V3(0, 2.9, 0)
							run(0.45, function() end)
							local N = 16
							local beads = {}
							for i = 1, N do
								beads[i] = ball(model, 0.34, base, liq:Lerp(WHT, 0.25), M.Neon, {shadow = false, trans = 0.05})
								extras[#extras + 1] = beads[i]
							end
							info.bub.Rate = 30
							local t0 = os.clock()
							run(1.7, function(k)
								local kk = ease(k)
								info.fill(kk)
								local surf = base + V3(0, info.Y0 + info.HT * kk, 0)
								local a = MR.shaker and MR.shaker.Position or (base + V3(1.5, 2.5, 0))
								local c = V3(surf.X + (a.X - surf.X) * 0.35, a.Y + 0.5, surf.Z + (a.Z - surf.Z) * 0.35)
								local el = os.clock() - t0
								local ph = (el * 1.8) % 1
								local fade = (k > 0.9) and (1 - (k - 0.9) / 0.1) or 1
								for i, bd in ipairs(beads) do
									local u = ((i - 1) / N + ph) % 1
									bd.Position = bez(a, c, surf, u)
									local s = math.max(0.06, 0.34 * fade * (0.85 + 0.15 * sin(el * 14 + i)))
									bd.Size = V3(s, s, s)
								end
							end)
							info.fill(1)
							info.bub.Rate = 8
							for _, bd in ipairs(beads) do pcall(function() bd:Destroy() end) end
							MR.rWant = nil
						end

						function dk.garnish()
							local G = info.groups
							local d0 = V3(0, -1, 0)
							local dA = (dP + V3(0, 0.8, 0)).Unit
							local dc = d0
							local function center(list)
								local sum = V3(0, 0, 0)
								for _, e in ipairs(list) do sum = sum + e.rest.Position end
								return sum / #list
							end

							local function shift(list, ctr, off, spin)
								for _, e in ipairs(list) do
									e.p.Transparency = e.tr
									local c = CF(off - ctr) * e.rest
									e.w.C0 = spin and (c * ANG(spin, 0, 0)) or c
								end
							end
							local function carry(list, dropT, spin)
								local ctr = center(list)

								if dc ~= d0 then
									local from = dc
									run(0.2, function(k) MR.lWant = handPoint(from:Lerp(d0, ease(k)).Unit) end)
									dc = d0
								end

								MR.lWant = handPoint(d0)
								shift(list, ctr, handPoint(d0) - base)
								info.spark:Emit(6)

								run(0.35, function(k)
									local e = ease(k)
									local d = (d0:Lerp(dA, e) + V3(0, 0.4 * sin(e * pi), 0)).Unit
									local hp = handPoint(d)
									MR.lWant = hp
									shift(list, ctr, hp - base)
								end)
								dc = dA

								local from = handPoint(dA) - base
								run(dropT, function(k)
									MR.lWant = handPoint(dA)
									shift(list, ctr, from:Lerp(ctr, k * k), spin and (ease(k) * pi * 4) or nil)
								end)
								for _, e in ipairs(list) do
									e.p.Transparency = e.tr
									e.w.C0 = e.rest
								end
								info.spark:Emit(5)
								ring(base + V3(0, info.Y0 + info.HT, 0), liq, 1.4)
							end
							for _, e in ipairs(G.ice) do carry({e}, 0.18, nil) end
							carry(G.straw, 0.4, nil)
							carry(G.lime, 0.25, true)

							run(0.3, function(k) MR.lWant = handPoint(dA:Lerp(d0, ease(k)).Unit) end)
							MR.lWant = nil
							for _, g in pairs(G) do
								for _, e in ipairs(g) do
									e.p.Transparency = e.tr
									e.w.C0 = e.rest
								end
							end
							info.spark:Emit(14)
						end

						function dk.slide(zc)
							local to = O + V3(96.2, 4.3, zc)
							local dzs = to.Z - base.Z

							local rightHand = dzs > 0
							local side = rightHand and -1 or 1
							local hy = base.Y + 0.95
							local function contact(p) return V3(p.X, hy, p.Z + side * 0.85) end
							local function aim(pt)
								if rightHand then MR.rWant = pt else MR.lWant = pt end
							end
							local restPt = handPoint(V3(0, -1, 0))
							local W = contact(base) + V3(0, 0.4, side * 1.0)

							if rightHand then
								aim(W)
								run(0.5, function() end)
							else
								run(0.3, function(k) MR.lWant = restPt:Lerp(W, ease(k)) end)
							end

							local T = math.clamp(0.8 + math.abs(dzs) * 0.045, 0.9, 1.5)
							info.spark.Rate = 40
							local released, relK, lastHand = false, 0, W
							run(T, function(k)
								local e = 1 - (1 - k) ^ 3
								local p = base:Lerp(to, e)
								place(p, 0, e * pi * 2, sin(k * pi * 3) * 0.12 * (1 - k))
								if not released then
									if (p - base).Magnitude < 1.7 and k < 0.35 then
										lastHand = contact(p)
										aim(lastHand)
									else
										released, relK = true, k
										if rightHand then MR.rWant = nil end
									end
								elseif not rightHand then
									MR.lWant = lastHand:Lerp(restPt, ease(math.clamp((k - relK) / 0.3, 0, 1)))
								end
							end)
							info.spark.Rate = 0
							if rightHand then MR.rWant = nil else MR.lWant = nil end
							cur = to
							place(cur, 0, 0, 0)
							ring(cur + V3(0, 0.1, 0), liq, 4)
						end

						function dk.offer(timeout)
							local hit = attach(root, CF(0, 1.0, 0), V3(2.4, 3.4, 2.4), WHT, M.SmoothPlastic, {shadow = false, trans = 1})
							hit.CanQuery = true
							parts[#parts + 1] = hit
							local cd = Instance.new("ClickDetector")
							cd.MaxActivationDistance = 60
							cd.Parent = hit
							local bb = Instance.new("BillboardGui")
							bb.Adornee = root
							bb.Size = UDim2.fromOffset(210, 34)
							bb.StudsOffset = V3(0, 3.6, 0)
							bb.AlwaysOnTop = true
							bb.MaxDistance = 70
							bb.Parent = root
							local bf = Instance.new("Frame")
							bf.Size = UDim2.fromScale(1, 1)
							bf.BackgroundColor3 = C(12, 6, 30)
							bf.BackgroundTransparency = 0.15
							bf.Parent = bb
							Instance.new("UICorner", bf).CornerRadius = UDim.new(0, 10)
							local bs = Instance.new("UIStroke", bf)
							bs.Color, bs.Thickness = GRN, 2
							local bl = Instance.new("TextLabel")
							bl.Size = UDim2.fromScale(1, 1)
							bl.BackgroundTransparency = 1
							bl.Font = Enum.Font.GothamBold
							bl.TextSize = 15
							bl.TextColor3 = GRN
							bl.Text = "Clique no copo pra pegar"
							bl.Parent = bf
							local clicked = false
							local conn = cd.MouseClick:Connect(function(plr)
								if plr == player then clicked = true end
							end)
							info.spark.Rate = 6
							local t0 = os.clock()
							while model.Parent and not clicked and os.clock() - t0 < timeout do
								local t = os.clock() - t0
								local lift = 0.55 * ease(math.min(1, t / 0.45)) + 0.12 * sin(t * 3)
								place(cur, lift, t * 1.3, 0)
								local pl = 0.5 + 0.5 * sin(t * 6)
								info.rim.Color = liq:Lerp(WHT, pl * 0.6)
								info.light.Brightness = 1 + 1.2 * pl
								RunService.Heartbeat:Wait()
							end
							conn:Disconnect()
							pcall(function() bb:Destroy() end)
							pcall(function() hit:Destroy() end)
							info.spark.Rate = 0
							return clicked
						end

						function dk.take(hrp)
							local from = cur + V3(0, 0.6, 0)
							local to = hrp and (hrp.Position + V3(0, 1.4, 0)) or (from + V3(0, 3, 0))
							info.spark.Rate = 50
							run(0.5, function(k)
								place(from:Lerp(to, ease(k)) + V3(0, 1.6 * sin(k * pi), 0), 0, k * pi * 4, 0)
							end)
							info.spark.Rate = 0
							info.spark:Emit(35)
							ring(to, liq, 5)
							task.delay(0.8, dk.wipe)
						end

						function dk.expire()
							info.spark:Emit(30)
							ring(cur + V3(0, 0.5, 0), liq, 4)
							task.delay(0.6, dk.wipe)
						end
						return dk
					end

					function D.giveTool(fl, onDrink)
						local liq = fl.liquid
						local sc = 0.55
						local tool = Instance.new("Tool")
						tool.Name = fl.name
						tool.ToolTip = "Clique pra beber"
						tool.RequiresHandle = true
						tool.CanBeDropped = false
						local _, info = cup(V3(0, 0, 0), liq, true, tool, sc)
						local handle = info.root
						for _, g in pairs(info.groups) do
							for _, e in ipairs(g) do e.p.Transparency = e.tr end
						end
						local gripPos = CFrame.new(0, 0.95 * sc, 0)
						tool.Grip = gripPos
						local drinking = false
						tool.Activated:Connect(function()
							if drinking then return end
							drinking = true
							tool.Enabled = false
							local fired = false
							run(1.1, function(k)
								local e = ease(math.min(1, k / 0.8))

								tool.Grip = gripPos * ANG(-2.0 * e, 0, 0) * CFrame.new(0, -1.0 * e, -0.5 * e)
								info.fill(1 - math.clamp((k - 0.4) / 0.5, 0, 1))
								if k > 0.45 and not fired then
									fired = true
									if onDrink then task.spawn(onDrink) end
								end
							end, function() return tool.Parent ~= nil end)

							local pos = handle.Position
							local fxp = Instance.new("Part")
							fxp.Anchored, fxp.CanCollide, fxp.CanQuery, fxp.CanTouch = true, false, false, false
							fxp.Transparency = 1
							fxp.Size = V3(0.2, 0.2, 0.2)
							fxp.Position = pos
							fxp.Parent = workspace
							local em = Instance.new("ParticleEmitter")
							em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
							em.Rate = 0
							em.LightEmission = 1
							em.Color = ColorSequence.new(liq:Lerp(WHT, 0.4), liq)
							em.Lifetime = NumberRange.new(0.5, 1.1)
							em.Speed = NumberRange.new(4, 9)
							em.SpreadAngle = Vector2.new(180, 180)
							em.Acceleration = V3(0, -8, 0)
							em.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0)})
							em.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
							em.Parent = fxp
							em:Emit(40)
							Debris:AddItem(fxp, 1.6)
							for i = 1, 12 do
								local s = Instance.new("Part")
								s.Size = V3(0.12 + math.random() * 0.18, 0.06, 0.12 + math.random() * 0.18)
								s.Color = GLASS
								s.Material = Enum.Material.Glass
								s.Transparency = 0.35
								s.CanCollide = false
								s.CanQuery = false
								s.CanTouch = false
								s.CFrame = CFrame.new(pos + V3((math.random() - 0.5) * 0.6, math.random() * 0.4, (math.random() - 0.5) * 0.6))
									* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
								s.AssemblyLinearVelocity = V3((math.random() - 0.5) * 16, 4 + math.random() * 8, (math.random() - 0.5) * 16)
								s.AssemblyAngularVelocity = V3((math.random() - 0.5) * 20, (math.random() - 0.5) * 20, (math.random() - 0.5) * 20)
								s.Parent = workspace
								Debris:AddItem(s, 2.5)
								task.delay(0.25, function() s.CanCollide = true end)
							end
							for i = 1, 8 do
								local d = Instance.new("Part")
								d.Shape = Enum.PartType.Ball
								d.Size = V3(0.18, 0.18, 0.18)
								d.Color = liq
								d.Material = Enum.Material.Neon
								d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
								d.Position = pos
								d.AssemblyLinearVelocity = V3((math.random() - 0.5) * 10, 2 + math.random() * 6, (math.random() - 0.5) * 10)
								d.Parent = workspace
								Debris:AddItem(d, 0.9)
							end
							pcall(function() tool:Destroy() end)
						end)
						local bp = player:FindFirstChildOfClass("Backpack") or player:FindFirstChild("Backpack")
						tool.Parent = bp or player.Character
						return tool
					end
					return D
				end)()

				local bubble = Instance.new("BillboardGui")
				bubble.Adornee = head
				bubble.Size = UDim2.fromOffset(300, 64)
				bubble.StudsOffset = V3(0, 3.0, 0)
				bubble.AlwaysOnTop = true
				bubble.MaxDistance = 90
				bubble.Enabled = false
				bubble.Parent = head
				local bf = Instance.new("Frame")
				bf.Size = UDim2.fromScale(1, 1)
				bf.BackgroundColor3 = C(12, 6, 30)
				bf.BackgroundTransparency = 0.15
				bf.Parent = bubble
				Instance.new("UICorner", bf).CornerRadius = UDim.new(0, 10)
				local bs = Instance.new("UIStroke", bf)
				bs.Color, bs.Thickness = GRN, 2
				local bl = Instance.new("TextLabel")
				bl.Size = UDim2.new(1, -16, 1, -8)
				bl.Position = UDim2.fromOffset(8, 4)
				bl.BackgroundTransparency = 1
				bl.Font = Enum.Font.GothamBold
				bl.TextSize = 16
				bl.TextWrapped = true
				bl.TextColor3 = GRN
				bl.Parent = bf
				local token = 0
				local function say(txt, dur)
					token = token + 1
					local my = token
					bl.Text = txt
					bubble.Enabled = true
					task.delay(dur or 4, function()
						if token == my then bubble.Enabled = false end
					end)
				end

				local MFALAS = {
					greet = {
						{ "A-aw geez, bem-vindo ao Bar do Rick, {nome}! Senta aí que eu preparo algo.", "nervoso", 1 },
						{ "Opa, cliente novo! O Rick disse pra eu não deixar ninguém tocar no fluido de portal... mas toma um.", "nervoso", 1 },
						{ "Entra, entra! Aqui o multiverso inteiro toma uma, ah... geez.", "animado", 1 },
					},
					idle = {
						{ "Aperte E em mim pra pedir um drink.", "animado", 1 },
						{ "Já provou o Synthwave Sour? É, tipo, muito bom.", "animado", 1 },
						{ "Cuidado com o fluido de portal... ele é forte, o Rick que disse.", "nervoso", 1 },
						{ "Aqui ninguém paga imposto interdimensional, eu acho.", "nervoso", 1 },
					},
					javou = {
						{ "Já vou, geez!", "nervoso", 1 },
						{ "A-aqui, já tô indo!", "nervoso", 1 },
					},
					pedido = {
						{ "Um {drink} saindo!", "animado", 1 },
						{ "{drink}? Boa escolha, eu acho... geez.", "nervoso", 1 },
						{ "Já já fica pronto o seu {drink}!", "animado", 1 },
					},
					pronto = {
						{ "Aqui está, viajante! Clica no copo pra pegar.", "animado", 1 },
						{ "Pronto! É só clicar no copo.", "animado", 1 },
					},
					toma = {
						{ "Toma! Equipa e clica pra beber.", "animado", 1 },
						{ "Aproveita! Não conta pro Rick, tá?", "nervoso", 1 },
					},
					sentou = {
						{ "O que vai ser, viajante? Aperte E em mim pra pedir.", "animado", 1 },
						{ "Fica à vontade! É só apertar E em mim pra pedir.", "nervoso", 1 },
					},
					limpar = {
						{ "Esse balcão tá, tipo, nojento... geez.", "nervoso", 1 },
						{ "O Rick nunca limpa nada aqui.", "nervoso", 1 },
					},
					garrafas = {
						{ "O Rick me mata se uma garrafa cair...", "nervoso", 1 },
						{ "Essa garrafa é de outra dimensão, melhor ter cuidado.", "nervoso", 1 },
					},
					shaker = {
						{ "Ainda tá cheio... eu acho.", "nervoso", 1 },
						{ "Será que esse shaker tá, ah, funcionando?", "nervoso", 1 },
					},
					pergunta = {
						{ "O-o que vai ser, viajante? Escolhe aí, eu acho.", "nervoso", 1 },
						{ "Tenho quatro sabores... qual você quer? Geez.", "nervoso", 1 },
						{ "Escolhe um sabor! Mas sem pressão, tá?", "animado", 1 },
					},
					cancela = {
						{ "Ah, tá... sem problema, geez.", "nervoso", 1 },
						{ "Se mudar de ideia, é só me chamar!", "animado", 1 },
					},
					susto = {
						{ "AAAH! Um portal dentro do bar?! O Rick vai me matar!", "grito", 2 },
						{ "Geez! Avisa antes de abrir um portal aqui dentro!", "grito", 2 },
						{ "Ah geez, ah geez, ah geez! Isso é, tipo, proibido aqui!", "grito", 2 },
						{ "Tem um portal no meio do bar! Fecha isso, por favor!", "grito", 2 },
					},
					arma = {
						{ "Essa arma é igualzinha à do Rick... isso não é bom.", "nervoso", 1 },
						{ "Ei, cuidado com essa coisa, eu acho!", "nervoso", 1 },
						{ "Uau, uma arma de portal de verdade! Será que eu posso... ah, deixa.", "animado", 1 },
						{ "Por favor, não atira nada perto das garrafas...", "nervoso", 1 },
					},
					entrou = {
						{ "Ele simplesmente pulou no portal?! Geez.", "nervoso", 1 },
						{ "Viagem interdimensional... eu nunca tenho coragem.", "animado", 1 },
						{ "Volta logo, viajante! Seu drink vai esquentar!", "animado", 1 },
						{ "Isso nunca acaba bem... eu acho.", "nervoso", 1 },
					},
				}
				local MCHANCE = { greet = 1, idle = 1, javou = 1, pedido = 1, pronto = 1, toma = 1, sentou = 1, limpar = 0.6, garrafas = 0.6, shaker = 0.6, pergunta = 1, cancela = 1, susto = 1, arma = 0.8, entrou = 0.8 }
				local MF
				pcall(function()
					if Z.fala and Z.fala.criar then
						MF = Z.fala.criar(function() return head end, MFALAS, MCHANCE, function() return Z.alive end, 2.3, 90)
						model.Destroying:Connect(function() pcall(MF.destruir) end)
					end
				end)

				local function diz(cat, vars)
					if MF then MF.dizer(cat, vars) return end
					local lista = MFALAS[cat]
					if not lista then return end
					local f = lista[math.random(#lista)]
					local v = vars or {}
					local txt = (f[1]:gsub("{(%w+)}", function(k) return v[k] or player.DisplayName end))
					say(txt, 4)
				end

				local drinkEffect, askFlavor
				do
					local Lighting = game:GetService("Lighting")
					local NSK = NumberSequenceKeypoint.new
					local fxCur = nil
					State.drinkStop = function() if fxCur then fxCur.stop() end end

					local function bands(n, lo, hi)
						local pts = {}
						for i = 0, n * 2 do
							pts[#pts + 1] = NSK(i / (n * 2), (i % 2 == 0) and hi or lo)
						end
						return NumberSequence.new(pts)
					end

					drinkEffect = function(fl)
						if fxCur then pcall(fxCur.stop) end
						local cam = workspace.CurrentCamera
						local stopped, cleanups = false, {}
						local fx = {}
						local function onStop(f) cleanups[#cleanups + 1] = f end
						function fx.stop()
							if stopped then return end
							stopped = true
							for i = #cleanups, 1, -1 do pcall(cleanups[i]) end
							if fxCur == fx then fxCur = nil end
						end
						fxCur = fx

						local function new(class, parent, props)
							local inst = Instance.new(class)
							for k, v in pairs(props or {}) do inst[k] = v end
							inst.Parent = parent
							onStop(function() inst:Destroy() end)
							return inst
						end

						local overlay
						local function getOverlay()
							if overlay then return overlay end
							local g = Instance.new("ScreenGui")
							g.Name = "RickDrinkFx"
							g.ResetOnSpawn = false
							g.IgnoreGuiInset = true
							g.DisplayOrder = 8
							g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
							parentGui(g)
							onStop(function() g:Destroy() end)
							overlay = g
							return g
						end

						local function layer(rot, seq, color)
							local f = new("Frame", getOverlay(), {
								Size = UDim2.fromScale(1, 1),
								BackgroundColor3 = color,
								BackgroundTransparency = 1,
								BorderSizePixel = 0,
							})
							local gr = new("UIGradient", f, { Rotation = rot, Transparency = seq })
							return f, gr
						end

						local roll, rollBound = 0, false
						local function useRoll()
							if rollBound then return end
							rollBound = true
							local name = "RickDrinkRoll"
							pcall(function() RunService:UnbindFromRenderStep(name) end)
							RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 2, function()
								local c = workspace.CurrentCamera
								if c and roll ~= 0 and c.CameraType ~= Enum.CameraType.Scriptable then
									c.CFrame = c.CFrame * CFrame.Angles(0, 0, roll)
								end
							end)
							onStop(function() pcall(function() RunService:UnbindFromRenderStep(name) end) end)
						end

						local FX = {}

						FX.portal = function()
							local cc = new("ColorCorrectionEffect", Lighting)
							local bb = new("BlurEffect", Lighting, { Size = 0 })
							local fA, gA = layer(90, bands(4, 0.72, 1), C(60, 255, 90))
							local fB, gB = layer(20, bands(3, 0.8, 1), C(150, 255, 150))
							local rings, nextRing = {}, 0
							useRoll()
							return function(e, k)
								cc.TintColor = Color3.new(1, 1, 1):Lerp(C(110, 255, 125), 0.85 * k)
								cc.Saturation = 0.35 * k
								cc.Contrast = 0.12 * k
								bb.Size = 5 * k * (0.5 + 0.5 * sin(e * 2.4))
								fA.BackgroundTransparency = 1 - k
								fB.BackgroundTransparency = 1 - k
								gA.Offset = Vector2.new(0.25 * sin(e * 1.3), 0.35 * sin(e * 1.7))
								gA.Rotation = 90 + 12 * sin(e * 0.9)
								gB.Offset = Vector2.new(0.3 * cos(e * 1.1), 0.3 * sin(e * 2.1 + 1))
								gB.Rotation = 20 + 25 * sin(e * 0.7)
								roll = math.rad(2.5) * k * sin(e * 1.6)
								if e >= nextRing and k > 0.3 then
									nextRing = e + 1.0
									local ring = new("Frame", getOverlay(), {
										AnchorPoint = Vector2.new(0.5, 0.5),
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(0.1, 0.1),
										BackgroundTransparency = 1,
										BorderSizePixel = 0,
									})
									new("UICorner", ring, { CornerRadius = UDim.new(0.5, 0) })
									local st = new("UIStroke", ring, { Thickness = 5, Color = C(90, 255, 110), Transparency = 0.3 })
									rings[#rings + 1] = { f = ring, st = st, t0 = e }
								end
								for i = #rings, 1, -1 do
									local R = rings[i]
									local a = (e - R.t0) / 2.4
									if a >= 1 then
										R.f:Destroy()
										table.remove(rings, i)
									else
										local s = 0.1 + 1.5 * a
										R.f.Size = UDim2.fromScale(s, s)
										R.st.Transparency = 0.3 + 0.7 * a
									end
								end
							end, function(e, k) return 4 * k * sin(e * 1.6) end
						end

						FX.synth = function()
							local cc = new("ColorCorrectionEffect", Lighting)
							local bloom = new("BloomEffect", Lighting, { Intensity = 0, Size = 30, Threshold = 0.8 })
							local edge = NumberSequence.new({ NSK(0, 0.35), NSK(0.35, 1), NSK(0.65, 1), NSK(1, 0.35) })
							local fV = layer(90, edge, MAG)
							local fH = layer(0, edge, CYA)
							local fS = layer(90, bands(9, 0.9, 1), C(90, 0, 70))
							local beat = 0
							return function(e, k)
								beat = (0.5 + 0.5 * sin(e * 11.9)) ^ 3
								cc.TintColor = Color3.new(1, 1, 1):Lerp(C(255, 110, 215), 0.8 * k)
								cc.Saturation = 0.5 * k
								cc.Contrast = 0.22 * k
								bloom.Intensity = k * (0.9 + 1.1 * beat)
								fV.BackgroundTransparency = 1 - k * (0.6 + 0.4 * beat)
								fH.BackgroundTransparency = 1 - k * (0.5 + 0.5 * beat)
								fS.BackgroundTransparency = 1 - k
							end, function(e, k) return 3.5 * k * beat end
						end

						FX.cyan = function()
							local cc = new("ColorCorrectionEffect", Lighting)
							local bloom = new("BloomEffect", Lighting, { Intensity = 0, Size = 24, Threshold = 0.9 })
							local bb = new("BlurEffect", Lighting, { Size = 0 })
							local dof = new("DepthOfFieldEffect", Lighting, {
								FarIntensity = 0, NearIntensity = 0, FocusDistance = 30, InFocusRadius = 25,
							})
							local edge = NumberSequence.new({ NSK(0, 0.5), NSK(0.3, 1), NSK(0.7, 1), NSK(1, 0.5) })
							local vA = layer(0, edge, CYA)
							local vB = layer(90, edge, C(30, 120, 255))

							local ch = player.Character
							local hum = ch and ch:FindFirstChildOfClass("Humanoid")
							local g0 = workspace.Gravity
							local ws0, jp0, usePower
							if hum then ws0, jp0, usePower = hum.WalkSpeed, hum.JumpPower, hum.UseJumpPower end
							onStop(function()
								workspace.Gravity = g0
								if hum and hum.Parent and ws0 then
									hum.WalkSpeed = ws0
									if usePower then hum.JumpPower = jp0 end
								end
							end)

							local okP, pitch = pcall(function()
								return new("PitchShiftSoundEffect", SoundService, { Octave = 1 })
							end)

							local S = 0.4
							return function(e, k)
								local s = 1 - (1 - S) * k
								workspace.Gravity = g0 * s * s
								if hum and hum.Parent and ws0 then
									hum.WalkSpeed = ws0 * s
									if usePower then hum.JumpPower = jp0 * s end
								end
								if okP and pitch then pitch.Octave = 1 - 0.35 * k end
								cc.TintColor = Color3.new(1, 1, 1):Lerp(C(150, 235, 255), 0.7 * k)
								cc.Contrast = 0.1 * k
								bloom.Intensity = 0.9 * k
								bb.Size = 2 * k * (0.5 + 0.5 * sin(e * 0.9))
								dof.FarIntensity = 0.45 * k
								vA.BackgroundTransparency = 1 - k
								vB.BackgroundTransparency = 1 - k
							end, function(e, k) return 6 * k * sin(e * 0.8) end
						end

						FX.sol = function()
							local cc = new("ColorCorrectionEffect", Lighting)
							local bb = new("BlurEffect", Lighting, { Size = 0 })
							return function(e, k)
								cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromHSV((e * 0.35) % 1, 0.55, 1), k)
								cc.Saturation = 0.9 * k
								cc.Contrast = 0.25 * k
								bb.Size = 6 * k * (0.5 + 0.5 * sin(e * 2.2))
							end, function(e, k) return 10 * k * sin(e * 1.7) end
						end

						local name = fl and fl.fx or "sol"
						local DUR = ({ portal = 10, synth = 9, cyan = 11, sol = 9 })[name] or 9
						local okM, update, fovFn = pcall(FX[name] or FX.sol)
						if not okM then
							warnRG("efeito de bebida: " .. tostring(update))
							fx.stop()
							return
						end

						local fov0 = cam and cam.FieldOfView or 70
						onStop(function() if cam then cam.FieldOfView = fov0 end end)
						task.spawn(function()
							local t0 = os.clock()
							while not stopped and Z.alive do
								local e = os.clock() - t0
								if e >= DUR then break end
								local k = math.min(1, e / 1.2, (DUR - e) / 2)
								local okU, err = pcall(update, e, k)
								if not okU then
									warnRG("efeito de bebida: " .. tostring(err))
									break
								end
								if cam and fovFn then cam.FieldOfView = fov0 + fovFn(e, k) end
								RunService.RenderStepped:Wait()
							end
							fx.stop()
						end)
					end

					local menuGui, menuPick, menuFrame
					local menuItems = {}

					local function buildMenu()
						local g = newGui("RickMortyMenu", 30)
						g.Enabled = false
						menuItems = {}

						local frame = Instance.new("Frame")
						frame.Name = "Menu"
						frame.AnchorPoint = Vector2.new(0, 0.5)
						frame.Position = UDim2.new(0, 14, 0.5, 0)
						frame.Size = UDim2.new(0.4, 0, 0, 0)
						frame.AutomaticSize = Enum.AutomaticSize.Y
						frame.BackgroundTransparency = 1
						frame.BorderSizePixel = 0
						frame.Parent = g
						menuFrame = frame
						local sc = Instance.new("UISizeConstraint")
						sc.MinSize = Vector2.new(190, 0)
						sc.MaxSize = Vector2.new(270, 10000)
						sc.Parent = frame
						local lay = Instance.new("UIListLayout")
						lay.Padding = UDim.new(0, 6)
						lay.SortOrder = Enum.SortOrder.LayoutOrder
						lay.HorizontalAlignment = Enum.HorizontalAlignment.Left
						lay.Parent = frame

						local function label(parent, text, size, font, color, pos, sz)
							local l = Instance.new("TextLabel")
							l.BackgroundTransparency = 1
							l.Position = pos
							l.Size = sz
							l.Text = text
							l.TextSize = size
							l.Font = font
							l.TextColor3 = color
							l.TextXAlignment = Enum.TextXAlignment.Left
							l.TextStrokeColor3 = Color3.new(0, 0, 0)
							l.TextStrokeTransparency = 0.35
							l.Parent = parent
							return l
						end

						local q = label(frame, "Morty: o que vai ser, viajante?", 19, Enum.Font.GothamBlack, GRN,
							UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 0))
						q.TextWrapped = true
						q.AutomaticSize = Enum.AutomaticSize.Y
						q.LayoutOrder = 1

						local H3, DEPTH = 52, 7
						local function make3D(order, base, accent, onClick)
							local wrap = Instance.new("Frame")
							wrap.BackgroundTransparency = 1
							wrap.Size = UDim2.new(1, 0, 0, H3 + DEPTH + 4)
							wrap.LayoutOrder = order
							wrap.Parent = frame

							local sh = Instance.new("Frame")
							sh.Size = UDim2.new(1, 0, 0, H3)
							sh.Position = UDim2.new(0, 0, 0, DEPTH + 4)
							sh.BackgroundColor3 = base:Lerp(Color3.new(0, 0, 0), 0.65)
							sh.BorderSizePixel = 0
							sh.Parent = wrap
							Instance.new("UICorner", sh).CornerRadius = UDim.new(0, 12)

							local b = Instance.new("TextButton")
							b.Size = UDim2.new(1, 0, 0, H3)
							b.Position = UDim2.new(0, 0, 0, 0)
							b.BackgroundColor3 = base
							b.AutoButtonColor = false
							b.Text = ""
							b.BorderSizePixel = 0
							b.Parent = wrap
							Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
							local gr = Instance.new("UIGradient")
							gr.Rotation = 90
							gr.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.62, 0.62, 0.7))
							gr.Parent = b
							local st = Instance.new("UIStroke")
							st.Color = accent
							st.Thickness = 2
							st.Transparency = 0.2
							st.Parent = b

							local item = { b = b, sh = sh, ph = order * 0.9, down = false }
							b.MouseButton1Down:Connect(function() item.down = true end)
							b.MouseButton1Up:Connect(function() item.down = false end)
							b.MouseLeave:Connect(function() item.down = false end)
							b.Activated:Connect(onClick)
							menuItems[#menuItems + 1] = item
							return b
						end

						local order = 2
						for _, fl in ipairs(FLAVORS) do
							local b = make3D(order, C(48, 26, 92), fl.liquid, function() menuPick = fl end)
							menuItems[#menuItems].val = fl
							order = order + 1
							local sw = Instance.new("Frame")
							sw.Size = UDim2.new(0, 8, 1, -18)
							sw.Position = UDim2.new(0, 10, 0, 9)
							sw.BackgroundColor3 = fl.liquid
							sw.BorderSizePixel = 0
							sw.Parent = b
							Instance.new("UICorner", sw).CornerRadius = UDim.new(1, 0)
							label(b, fl.name, 16, Enum.Font.GothamBold, Color3.new(1, 1, 1),
								UDim2.new(0, 28, 0, 6), UDim2.new(1, -36, 0, 22))
							label(b, fl.desc or "", 12, Enum.Font.Gotham, fl.liquid,
								UDim2.new(0, 28, 0, 28), UDim2.new(1, -36, 0, 18))
						end

						local cb = make3D(order, C(80, 36, 84), C(255, 160, 210), function() menuPick = false end)
						menuItems[#menuItems].val = false
						local cl = label(cb, "Deixa pra lá", 15, Enum.Font.GothamBold, C(255, 205, 230),
							UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0))
						cl.TextXAlignment = Enum.TextXAlignment.Center

						menuGui = g
					end

					local function animMenu(t)
						for _, it in ipairs(menuItems) do
							local off = it.down and 5 or (2 + 3 * math.sin(t * 2 + it.ph))
							if it.down then off = 5 end
							it.b.Position = UDim2.new(0, 0, 0, off)
							it.sh.BackgroundTransparency = it.down and 0.3 or 0.1 + 0.1 * (0.5 + 0.5 * math.sin(t * 2 + it.ph))
						end
					end

					askFlavor = function()
						if not (menuGui and menuGui.Parent) then buildMenu() end
						if not menuGui then return nil end
						menuPick = nil

						if menuFrame then
							menuFrame.Position = UDim2.new(0, -320, 0.5, 0)
							TweenService:Create(menuFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 14, 0.5, 0)}):Play()
						end
						for i, it in ipairs(menuItems) do
							UIAnim.getScale(it.b).Scale = 0
							task.delay(0.05 + i * 0.07, function()
								if it.b.Parent then UIAnim.scaleTo(it.b, 1, 0.35) end
							end)
						end
						menuGui.Enabled = true
						local t0 = os.clock()
						while menuPick == nil and Z.alive and model.Parent and os.clock() - t0 < 45 do
							local ch = player.Character
							local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
							local hum = ch and ch:FindFirstChildOfClass("Humanoid")
							if not hrp or not hum or hum.Health <= 0 then break end
							if MR.root and (hrp.Position - MR.root.Position).Magnitude > 32 then break end
							pcall(animMenu, os.clock())
							RunService.Heartbeat:Wait()
						end
						local pick = menuPick
						menuPick = nil

						if menuGui then
							if menuFrame and Z.alive and menuGui.Parent then
								if pick ~= nil then
									for _, it in ipairs(menuItems) do
										if it.val == pick then pcall(UIAnim.pulse, it.b, 1.2) end
									end
									task.wait(0.2)
								end
								TweenService:Create(menuFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0, -320, 0.5, 0)}):Play()
								task.wait(0.3)
							end
							menuGui.Enabled = false
						end
						if pick == false then return nil end
						return pick
					end
				end

				local busy, shaking, pouring, pp = false, false, false, nil

				local BHV = {atPost = true, callPost = false, serving = false, nextTask = os.clock() + 5}
				local POST_X, POST_Z, POST_YAW = BASE.Position.X, BASE.Position.Z, pi / 2
				MR.px, MR.pz, MR.yaw, MR.walking, MR.speedF = POST_X, POST_Z, POST_YAW, false, 1
				do
					local function angDiff(a, b) return (a - b + pi) % (2 * pi) - pi end
					local function ez(k) return k * k * (3 - 2 * k) end

					local bornAt, seen = os.clock(), false
					local function alive()
						if model.Parent then seen = true return true end
						return (not seen) and os.clock() - bornAt < 120
					end
					local function interrupted()
						return (not alive()) or sitting or BHV.callPost or busy
					end
					local function relax()
						if not BHV.serving then
							MR.lWant, MR.rWant = nil, nil
							pcall(function() MR.rag.Transparency = 1 end)
						end
					end

					local function step(dur, fn)
						local t0 = os.clock()
						while true do
							if interrupted() then return false end
							local k = (os.clock() - t0) / dur
							if k >= 1 then fn(1) return true end
							fn(k)
							RunService.Heartbeat:Wait()
						end
					end
					local function turnTo(yaw)
						local guard = 0
						while alive() and math.abs(angDiff(yaw, MR.yaw)) > 0.04 and guard < 120 do
							guard = guard + 1
							local dt = RunService.Heartbeat:Wait()
							MR.yaw = MR.yaw + math.clamp(angDiff(yaw, MR.yaw), -7 * dt, 7 * dt)
						end
						MR.yaw = yaw
					end

					local function walkTo(x, z, speed, force)
						BHV.atPost = false
						MR.speedF = speed / 5.5
						local ok = true
						while alive() do
							if not force and interrupted() then ok = false break end
							local dx, dz = x - MR.px, z - MR.pz
							local d = math.sqrt(dx * dx + dz * dz)
							if d < 0.08 then break end
							MR.walking = true
							local dt = RunService.Heartbeat:Wait()
							local sd = math.min(d, speed * dt)
							MR.px = MR.px + dx / d * sd
							MR.pz = MR.pz + dz / d * sd
							local want = math.atan2(-dx, -dz)
							MR.yaw = MR.yaw + math.clamp(angDiff(want, MR.yaw), -8 * dt, 8 * dt)
						end
						MR.walking = false
						return ok
					end
					local function goPost(speed)
						if BHV.atPost then return end
						relax()
						walkTo(POST_X, POST_Z, speed or 6.5, true)
						turnTo(POST_YAW)
						MR.px, MR.pz = POST_X, POST_Z
						BHV.atPost = true
					end
					local function restPt()
						return MR.root.CFrame:PointToWorldSpace(V3(-MS, 0.5 * MS, 0) + V3(0, -1, 0) * MR.lLen)
					end

					local function tWipe()
						local z = O.Z + cz + (math.random() * 18 - 9)
						local ok = walkTo(POST_X, z, 5.2)
						if ok then
							turnTo(POST_YAW)
							diz("limpar")
							MR.rag.Transparency = 0
							local function pt(off) return V3(O.X + 97.75, O.Y + 4.42, MR.pz + MS + off) end
							ok = step(0.4, function(k) MR.lWant = restPt():Lerp(pt(0), ez(k)) end)
							ok = ok and step(3.4, function(k) MR.lWant = pt(1.2 * sin(k * pi * 3)) end)
							ok = ok and step(0.35, function(k) MR.lWant = pt(0):Lerp(restPt(), ez(k)) end)
						end
						relax()
						return ok
					end

					local bottleCache
					local function loadBottles()
						if bottleCache then return bottleCache end
						bottleCache = {}
						local x0 = O.X + BX1 - T - 0.9
						for _, d in ipairs(model:GetDescendants()) do
							if d:IsA("BasePart") and d.Anchored then
								local pp2, sz = d.Position, d.Size
								if math.abs(pp2.X - x0) < 1.3 and pp2.Y > O.Y + 6.3 and pp2.Y < O.Y + 10.4 and sz.Z < 3 and sz.X < 2.2 then
									local i = math.floor((pp2.Z - (O.Z + cz - 12)) / 2.18 + 0.5)
									if i >= 0 and i <= 11 then
										bottleCache[i] = bottleCache[i] or {}
										table.insert(bottleCache[i], {p = d, cf = d.CFrame})
									end
								end
							end
						end
						return bottleCache
					end
					local function tBottles()
						local cache = loadBottles()
						local x0 = O.X + BX1 - T - 0.9
						local i = math.random(1, 10)
						local touched = {}
						local function zOf(j) return O.Z + cz - 12 + j * 2.18 end
						local function pose(j, lift, ang)
							local recs = cache[j]
							if not recs then return end
							local piv = V3(x0, O.Y + 8, zOf(j))
							local TT = CF(0, lift, 0) * CF(piv) * ANG(0, ang, 0) * CF(-piv)
							for _, rc in ipairs(recs) do
								pcall(function() rc.p.CFrame = TT * rc.cf end)
							end
						end
						local ok = walkTo(O.X + 101.9, zOf(i) + MS, 5.2)
						if ok then
							turnTo(-pi / 2)
							diz("garrafas")
							local function hand(j, lift) return V3(x0 - 0.5, O.Y + 7.2 + lift * 0.3, zOf(j)) end
							ok = step(0.5, function(k) MR.lWant = restPt():Lerp(hand(i, 0), ez(k)) end)
							for _, j in ipairs({i, i + 1}) do
								if not ok then break end
								touched[#touched + 1] = j
								local from = MR.lWant
								ok = step(0.3, function(k) MR.lWant = from:Lerp(hand(j, 0), ez(k)) end)
								ok = ok and step(0.35, function(k) local l = 0.5 * ez(k) pose(j, l, 0) MR.lWant = hand(j, l) end)
								ok = ok and step(0.8, function(k) pose(j, 0.5, ez(k) * pi * 2) MR.lWant = hand(j, 0.5) end)
								ok = ok and step(0.35, function(k) local l = 0.5 * (1 - ez(k)) pose(j, l, 0) MR.lWant = hand(j, l) end)
								pose(j, 0, 0)
							end
							ok = ok and step(0.4, function(k) MR.lWant = hand(i + 1, 0):Lerp(restPt(), ez(k)) end)
						end
						for _, j in ipairs(touched) do
							for _, rc in ipairs(cache[j] or {}) do
								pcall(function() rc.p.CFrame = rc.cf end)
							end
						end
						relax()
						return ok
					end

					local function tShaker()
						local z = O.Z + cz + (math.random() * 14 - 7)
						local ok = walkTo(POST_X, z, 5.2)
						if ok then
							turnTo(POST_YAW)
							local function sp(j) return MR.root.CFrame:PointToWorldSpace(V3(0.4 * MS, 1.1 * MS + j, -1.5 * MS)) end
							ok = step(0.6, function() MR.rWant = sp(0) end)
							if ok then DR.shakeFx(true, GRN) end
							ok = ok and step(1.8, function(k) MR.rWant = sp(0.2 * sin(k * pi * 18)) end)
							if not BHV.serving then DR.shakeFx(false) end
							diz("shaker")
						end
						relax()
						return ok
					end

					task.spawn(function()
						local announced, waiting, lastPick = false, false, 0
						while alive() do
							RunService.Heartbeat:Wait()
							if BHV.serving then

							elseif BHV.callPost or sitting then
								if not BHV.atPost then goPost(BHV.callPost and 7.5 or 6.5) end
								if sitting and BHV.atPost and not busy then
									if not announced then
										announced = true
										diz("sentou")
									end
									waiting = true

									MR.lWant = V3(O.X + 97.75, O.Y + 4.42, MR.pz + MS + 0.25 * sin(os.clock() * 6))
								end
								BHV.nextTask = os.clock() + 6
							else
								announced = false
								if waiting then waiting = false relax() end
								if os.clock() >= BHV.nextTask and not busy then
									local pick = math.random(1, 3)
									if pick == lastPick then pick = pick % 3 + 1 end
									lastPick = pick
									if pick == 1 then tWipe() elseif pick == 2 then tBottles() else tShaker() end
									if not interrupted() then
										if math.random() < 0.4 then
											BHV.nextTask = os.clock() + 0.6
										else
											goPost(5)
											BHV.nextTask = os.clock() + math.random(6, 11)
										end
									end
								end
							end
						end
					end)
				end
				local function serve()
					if busy then return end
					busy = true
					if pp then pp.Enabled = false end
					task.spawn(function()

						BHV.callPost = true
						if not BHV.atPost then diz("javou") end
						local tw = os.clock()
						while not BHV.atPost and os.clock() - tw < 12 and model.Parent do
							RunService.Heartbeat:Wait()
						end
						if not BHV.atPost then
							MR.px, MR.pz, MR.yaw, MR.walking = POST_X, POST_Z, POST_YAW, false
							BHV.atPost = true
						end
						BHV.callPost = false
						BHV.serving = true
						MR.lWant, MR.rWant = nil, nil
						diz("pergunta")
						local fl = askFlavor()
						if not fl then
							diz("cancela")
							task.wait(0.6)
							BHV.serving = false
							BHV.nextTask = os.clock() + 6
							busy = false
							if pp then pp.Enabled = true end
							return
						end
						diz("pedido", {drink = fl.name})
						shaking = true
						DR.shakeFx(true, fl.liquid)
						local dk
						local ok, err = pcall(function()
							dk = DR.make(fl.liquid)
							dk.fetch()
							task.wait(0.4)
							shaking = false
							DR.shakeFx(false)
							pouring = true
							dk.pour()
							pouring = false
							dk.garnish()
							local char = player.Character
							local hrp = char and char:FindFirstChild("HumanoidRootPart")
							local zc = hrp and math.clamp(hrp.Position.Z - O.Z, cz - 12, cz + 12) or cz
							diz("pronto")
							dk.slide(zc)
							if dk.offer(40) then
								local ch2 = player.Character
								dk.take(ch2 and ch2:FindFirstChild("HumanoidRootPart"))
								DR.giveTool(fl, function() local okD, eD = pcall(drinkEffect, fl); if not okD then warnRG("efeito da bebida:", eD) end end)
								diz("toma")
							else
								dk.expire()
							end
						end)
						if not ok then
							warnRG("Morty drink: " .. tostring(err))
							shaking, pouring = false, false
							DR.shakeFx(false)
							MR.lWant, MR.rWant = nil, nil
							if dk then dk.wipe() end
						end
						task.wait(1)
						BHV.serving = false
						BHV.nextTask = os.clock() + 8
						busy = false
						if pp then pp.Enabled = true end
					end)
				end
				pcall(function()
					pp = Instance.new("ProximityPrompt")
					pp.ActionText = "Pedir drink"
					pp.ObjectText = "Morty"
					pp.HoldDuration = 0.2
					pp.MaxActivationDistance = 14
					pp.RequiresLineOfSight = false
					pp.Parent = torso
					pp.Triggered:Connect(serve)
				end)

				local headYaw, wasInside, greetT, nextIdle = 0, false, -100, 0
				local function updBarman(t, pos)
					local dt = math.clamp(t - (MR.lastT or t), 0, 0.1)
					MR.lastT = t
					MR.walkAmt = (MR.walkAmt or 0) + ((MR.walking and 1 or 0) - (MR.walkAmt or 0)) * math.min(1, dt * 10)
					MR.walkPh = (MR.walkPh or 0) + dt * 9 * (MR.speedF or 1) * MR.walkAmt
					local wa = MR.walkAmt
					local sw = sin(MR.walkPh) * 0.65 * wa
					local bob = sin(t * 1.6) * 0.06 * (1 - wa) + math.abs(sin(MR.walkPh)) * 0.12 * wa

					local su, suK, hop, shake = MR.startle, 0, 0, 0
					if su then
						local se = os.clock() - su.t0
						if se >= su.dur then
							MR.startle = nil
						else
							suK = math.clamp(math.min(se / 0.12, (su.dur - se) / 0.5), 0, 1) * su.amp
							hop = math.max(0, sin(math.min(se / 0.4, 1) * pi)) * 0.8 * su.amp
							shake = sin(se * 42) * 0.05 * suK
						end
					end
					MR.root.CFrame = CF(MR.px, BASE.Position.Y + bob + hop, MR.pz) * ANG(0, MR.yaw + shake, 0)
					MR.rHip.C0 = MR.rHipC0 * ANG(0, 0, sw)
					MR.lHip.C0 = MR.lHipC0 * ANG(0, 0, sw)
					local rel = 0
					if pos then
						local dx, dz = pos.X - MR.px, pos.Z - MR.pz
						if dx * dx + dz * dz < 2500 then
							rel = math.clamp((math.atan2(-dx, -dz) - MR.yaw + pi) % (2 * pi) - pi, -1.1, 1.1)
						end
					end
					headYaw = headYaw + (rel - headYaw) * 0.15
					MR.neck.C0 = MR.neckC0 * ANG(0, 0, headYaw + sin(os.clock() * 30) * 0.3 * suK)
					local target = pouring and (2.1 + 0.05 * sin(t * 5))
						or (shaking and (1.2 + 0.3 * sin(t * 16)) or (0.12 + 0.05 * sin(t * 1.6)))
					MR.armA = shaking and target or (MR.armA + (target - MR.armA) * 0.18)
					local rc0 = MR.shoulderC0 * ANG(0, 0, MR.armA - sw * 0.5)
					if MR.rWant then MR.rLast = MR.rWant end
					MR.rBlend = MR.rBlend + ((MR.rWant and 1 or 0) - MR.rBlend) * 0.15
					if MR.rBlend > 0.01 and MR.rLast then
						local ik = MR.ikR(MR.rLast)
						if ik then rc0 = rc0:Lerp(ik, MR.rBlend) end
					end
					local suArms = suK > 0.02 and not MR.rWant and not MR.lWant and MR.rBlend < 0.05
					local suTr = sin(os.clock() * 28) * 0.08 * suK
					if suArms then
						rc0 = MR.shoulderC0 * ANG(0, 0, 2.5 * suK + (MR.armA - sw * 0.5) * (1 - suK) + suTr)
					end
					MR.rShoulder.C0 = rc0
					local lc0 = MR.lWant and MR.ikL(MR.lWant) or nil
					if suArms then
						lc0 = MR.lC0 * ANG(0, 0, -2.5 * suK + (0.03 * sin(t * 1.3) - sw * 0.5) * (1 - suK) - suTr)
					end
					MR.lShoulder.C0 = lc0 or (MR.lC0 * ANG(0, 0, 0.03 * sin(t * 1.3) - sw * 0.5))
					if pos then
						local inside = pos.X > O.X + BX0 + 1 and pos.X < O.X + BX1 and pos.Z > O.Z + BZ0 and pos.Z < O.Z + BZ1 and pos.Y < O.Y + H
						if inside and not wasInside and t - greetT > 15 then
							greetT = t
							diz("greet")
							nextIdle = t + 30
						end
						if inside and t > nextIdle and not busy then
							diz("idle")
							nextIdle = t + math.random(25, 45)
						end
						wasInside = inside
					end
				end

				do
					local function insideBar(p)
						return p.X > O.X + BX0 + 1 and p.X < O.X + BX1 and p.Z > O.Z + BZ0 and p.Z < O.Z + BZ1 and p.Y < O.Y + H
					end
					local function nearMorty(p, d)
						local rp = MR.root and MR.root.Position
						return rp ~= nil and (p - rp).Magnitude <= d
					end

					local function dizAgora(cat)
						local lista = MFALAS[cat]
						if not lista or not MF then return end
						if math.random() > (MCHANCE[cat] or 1) then return end
						local f = lista[math.random(#lista)]
						local txt = (f[1]:gsub("{(%w+)}", function() return player.DisplayName end))
						pcall(MF.mostrar, txt, f[2], f[3] or 1)
					end

					local lastReact, lastScare = 0, 0
					local hooks = {}

					function hooks.onPortal(pos)
						if not Z.alive or not insideBar(pos) then return end
						local now = os.clock()
						if now - lastScare < 4 then return end
						lastScare, lastReact = now, now
						MR.startle = { t0 = now, dur = 1.7, amp = 1 }
						dizAgora("susto")
					end

					function hooks.onShot(pos)
						if not Z.alive then return end
						local now = os.clock()
						if now - lastReact < 7 then return end
						if not (insideBar(pos) or nearMorty(pos, 70)) then return end
						lastReact = now
						if not MR.startle then MR.startle = { t0 = now, dur = 0.7, amp = 0.35 } end
						dizAgora("arma")
					end

					function hooks.onTeleport(fromPos, toPos)
						if not Z.alive then return end
						local now = os.clock()
						if now - lastReact < 6 then return end
						if not (insideBar(fromPos) or insideBar(toPos) or nearMorty(fromPos, 60) or nearMorty(toPos, 60)) then return end
						lastReact = now
						dizAgora("entrou")
					end

					State.morty = hooks
					model.Destroying:Connect(function()
						if State.morty == hooks then State.morty = nil end
					end)
				end

				local jx, jz = 80, BZ0 + T + 1.6
				local jb = mk(model, V3(6, 9, 3), O + V3(jx, 4.5, jz), C(40, 14, 80), M.SmoothPlastic, {solid = true, refl = 0.3})
				mk(model, V3(3, 6, 6), CF(O + V3(jx, 9, jz)) * ANG(0, pi / 2, 0), C(40, 14, 80), M.SmoothPlastic, {cyl = true, shadow = false, refl = 0.3})
				mk(model, V3(0.3, 5, 5), CF(O + V3(jx, 9, jz + 1.55)) * ANG(0, pi / 2, 0), MAG, M.Neon, {cyl = true, shadow = false})
				mk(model, V3(0.35, 3.6, 3.6), CF(O + V3(jx, 9, jz + 1.6)) * ANG(0, pi / 2, 0), C(10, 5, 25), M.SmoothPlastic, {cyl = true, shadow = false})
				local rc = O + V3(jx, 9, jz + 1.85)
				local mk1 = neon(V3(3.2, 0.18, 0.1), CF(rc), CYA)
				local mk2 = neon(V3(3.2, 0.18, 0.1), CF(rc) * ANG(0, 0, pi / 2), CYA)
				mk(model, V3(0.4, 0.9, 0.9), CF(O + V3(jx, 9, jz + 1.95)) * ANG(0, pi / 2, 0), GRN, M.Neon, {cyl = true, shadow = false})
				neon(V3(0.5, 8, 0.4), O + V3(jx - 2.6, 4.5, jz + 1.55), CYA)
				neon(V3(0.5, 8, 0.4), O + V3(jx + 2.6, 4.5, jz + 1.55), MAG)
				neon(V3(3.2, 1.2, 0.15), O + V3(jx, 5.2, jz + 1.55), YEL, {trans = 0.2})
				mk(model, V3(4.4, 2.4, 0.15), O + V3(jx, 2.6, jz + 1.55), C(10, 5, 25), M.SmoothPlastic, {shadow = false})
				glow(mk(model, V3(0.2, 0.2, 0.2), O + V3(jx, 6, jz + 3), DARK, M.SmoothPlastic, {trans = 1, shadow = false}), MAG, 1.2, 22)

				local idx, snd = 0, nil
				pcall(function()
					local pp = Instance.new("ProximityPrompt")
					pp.ActionText = "Ligar jukebox"
					pp.ObjectText = "Jukebox do Rick"
					pp.HoldDuration = 0.15
					pp.MaxActivationDistance = 12
					pp.RequiresLineOfSight = false
					pp.Parent = jb
					pp.Triggered:Connect(function()
						local n = #BAR_SONGS
						idx = idx + 1
						if idx > math.max(n, 1) then idx = 0 end
						party.on = idx > 0
						if snd then pcall(function() snd:Stop() end) end
						if party.on and n > 0 then
							if not snd then
								snd = Instance.new("Sound")
								snd.Looped = true
								snd.Volume = 0.5
								snd.RollOffMinDistance = 12
								snd.RollOffMaxDistance = 100
								snd.Parent = jb
							end
							snd.SoundId = BAR_SONGS[idx]
							snd:Play()
						end
						pp.ActionText = party.on and "Trocar / desligar" or "Ligar jukebox"
					end)
				end)

				return function(t, pos)
					local on = party.on
					local sp = on and 5 or 0.8
					for i, c in ipairs(ceil) do
						local col = MAG:Lerp(CYA, 0.5 + 0.5 * sin(t * sp + i * 1.3))
						c.p.Color, c.l.Color = col, col
						c.l.Brightness = on and (1.2 + 1.2 * (0.5 + 0.5 * sin(t * 8 + i))) or 0.9
					end
					discoLight.Color = GRN:Lerp(CYA, 0.5 + 0.5 * sin(t * sp))
					for _, tl in ipairs(tiles) do
						tl.p.Color = MAG:Lerp(CYA, 0.5 + 0.5 * sin(t * sp + tl.s))
						tl.p.Transparency = on and (0.05 + 0.3 * (0.5 + 0.5 * sin(t * 8 + tl.s))) or 0.8
					end
					if on then party.ang = t * 4 end
					mk1.CFrame = CF(rc) * ANG(0, 0, party.ang)
					mk2.CFrame = CF(rc) * ANG(0, 0, party.ang + pi / 2)
					updPortal(t)
					updBarman(t, pos)
				end
			end)()

			local updTrain = (function()
				local BY, L0, L1 = 128, -750, 1150
				local mid = (L0 + L1) / 2
				mk(model, V3(3.2, 3, L1 - L0), O + V3(0, BY, mid), C(22, 12, 48), M.SmoothPlastic, {solid = true, refl = 0.2})
				neon(V3(0.35, 0.35, L1 - L0), O + V3(-1.7, BY - 1.3, mid), MAG)
				neon(V3(0.35, 0.35, L1 - L0), O + V3(1.7, BY - 1.3, mid), CYA)
				neon(V3(1, 0.25, L1 - L0), O + V3(0, BY + 1.6, mid), CYA, {trans = 0.3})
				for k = 0, 12 do
					local z = -720 + 150 * k
					local col = (k % 2 == 0) and MAG or CYA
					for _, s in ipairs({-1, 1}) do
						mk(model, V3(3, BY + 4.5, 3), O + V3(s * 10, (BY + 4.5) / 2, z), C(24, 12, 52), M.SmoothPlastic, {solid = true})
						for _, yy in ipairs({30, 60, 90, 120}) do
							neon(V3(3.4, 0.4, 3.4), O + V3(s * 10, yy, z), col)
						end
					end
					mk(model, V3(26, 3, 4), O + V3(0, BY + 3, z), C(24, 12, 52), M.SmoothPlastic, {solid = true})
					neon(V3(26.2, 0.3, 4.2), O + V3(0, BY + 4.6, z), (col == MAG) and CYA or MAG)
				end

				local root = mk(model, V3(1, 1, 1), CF(O + V3(0, 121, 0)), DARK, M.SmoothPlastic, {trans = 1, shadow = false})
				glow(root, CYA, 1.2, 50)
				local function T(rel, size, col, mat, o) return attach(root, rel, size, col, mat, o or {shadow = false}) end
				local PAINT, DK = C(34, 18, 70), C(14, 6, 34)
				for i = 0, 3 do
					local zc = (i - 1.5) * 19.5
					T(CF(0, 0, zc), V3(6.2, 4.6, 18), PAINT, M.SmoothPlastic, {shadow = false, refl = 0.25})
					T(CF(0, 2.5, zc), V3(5.4, 0.5, 17), C(48, 24, 96), M.SmoothPlastic)
					T(CF(0, -2.35, zc), V3(6.6, 1, 17.4), DK, M.SmoothPlastic)
					for _, sx in ipairs({-1, 1}) do
						for j = 0, 3 do
							T(CF(sx * 3.12, 0.6, zc - 6.3 + j * 4.2), V3(0.2, 1.6, 3), (j % 2 == 0) and CYA or C(255, 230, 150), M.Neon)
						end
						T(CF(sx * 3.12, -1.2, zc), V3(0.2, 0.35, 17.4), MAG, M.Neon)
					end
					T(CF(0, 3.9, zc - 5), V3(1, 3.4, 1.6), DK, M.SmoothPlastic)
					T(CF(0, 3.9, zc + 5), V3(1, 3.4, 1.6), DK, M.SmoothPlastic)
					if i < 3 then T(CF(0, 0.2, zc + 9.75), V3(3, 2.2, 1.6), DK, M.SmoothPlastic) end
				end
				for _, ez in ipairs({-1, 1}) do
					local zz = ez * (1.5 * 19.5 + 9.15)
					T(CF(0, 0.7, zz), V3(5.2, 2, 0.15), CYA, M.Neon, {shadow = false, trans = 0.3})
					T(CF(0, -1.0, zz), V3(4, 0.5, 0.2), C(230, 250, 255), M.Neon)
				end

				local LEN = (L1 - L0) - 160
				return function(t)
					local p = (t * 55) % (2 * LEN)
					local s = (p < LEN) and p or (2 * LEN - p)
					root.CFrame = CF(O + V3(0, 121, L0 + 80 + s))
				end
			end)()

			local cubes = {}
			for i = 1, 22 do
				local s = rnd(4, 10)
				local base = O + V3(rnd(-50, 50), rnd(30, 100), rnd(40, 700))
				local p = neon(V3(s, s, s), CF(base), (i % 2 == 0) and MAG or CYA)
				cubes[i] = {p = p, base = base, sp = rnd(0.3, 1), ph = rnd(0, 6.28)}
			end

			emitterBox(model, V3(300, 2, 900), O + V3(0, 3, 300), {
				Rate = 140, Lifetime = NumberRange.new(5, 9), Speed = NumberRange.new(2, 5),
				SpreadAngle = Vector2.new(30, 30), EmissionDirection = Enum.NormalId.Top,
				Size = NumberSequence.new(0.5), LightEmission = 1,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1),
				}),
				Color = ColorSequence.new(MAG, CYA),
				Acceleration = V3(0, 1.2, 0),
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
			})

			return function(t, pos)
				for _, c in ipairs(cubes) do
					c.p.CFrame = CF(c.base + V3(0, sin(t * c.sp + c.ph) * 4, 0)) * ANG(t * c.sp, t * c.sp * 0.7, 0)
				end
				for i, p in ipairs(dashes) do
					p.Transparency = 0.15 + 0.7 * (0.5 + 0.5 * sin(t * 6 - i * 0.6))
				end
				pad.Transparency = 0.4 + 0.25 * sin(t * 3)
				for _, rg in ipairs(rings) do updRing(rg, t) end
				for _, c in ipairs(cars) do updCar(c, t) end
				for _, b in ipairs(beams) do updBeam(b, t) end
				for _, b in ipairs(beacons) do
					b.p.Transparency = (((t + b.ph) % b.per) < b.per * 0.5) and 0 or 0.85
				end
				for _, s in ipairs(signs) do
					local v = sin(t * s.fl * 7 + s.ph) * sin(t * 2.3 + s.ph)
					s.lbl.TextTransparency = (v > 0.93) and 0.85 or 0
				end
				updBar(t, pos)
				updTrain(t)
			end
		end

		local function buildDesert(model, O, r)
			local cos, sin, abs, floor, pi, sqrt, max, min = math.cos, math.sin, math.abs, math.floor, math.pi, math.sqrt, math.max, math.min
			local V3, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
			local function rnd(a, b) return r:NextNumber(a, b) end
			local function pick(t) return t[r:NextInteger(1, #t)] end
			local function W(x, y, z) return O + V3(x, y, z) end
			local function clamp01(v) return max(0, min(1, v)) end
			local function lerp(a, b, k) return a + (b - a) * k end
			local function dist(lp, x, z)
				local dx, dz = lp.X - x, lp.Z - z
				return sqrt(dx * dx + dz * dz)
			end
			local function matOr(name, fb)
				local ok, v = pcall(function() return Enum.Material[name] end)
				if ok and v then return v end
				return fb
			end

			local SANDSTONE = matOr("Sandstone", M.Slate)
			local LIMESTONE = matOr("Limestone", M.Slate)
			local BASALT = matOr("Basalt", M.Slate)
			local MUDM = matOr("Mud", M.Sand)
			local SALTM = matOr("Salt", M.Sand)
			local WOOD = matOr("Wood", M.SmoothPlastic)
			local NEON, GLASS, SMOOTH, METAL = M.Neon, M.Glass, M.SmoothPlastic, M.Metal

			local SAND = C(228, 164, 92)
			local HAZE = C(238, 176, 120)
			local BONE = C(232, 222, 196)
			local STRATA = { C(196, 112, 66), C(220, 150, 88), C(172, 92, 58), C(232, 178, 112), C(150, 78, 52), C(206, 128, 74) }
			local function tint(c, f) return c:Lerp(HAZE, f) end

			local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
			local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

			local function new(class, props, parent)
				local i = Instance.new(class)
				for k, v in pairs(props) do pcall(function() i[k] = v end) end
				if parent then i.Parent = parent end
				return i
			end
			local function emit(parent, props) return new("ParticleEmitter", props, parent) end
			local function light(parent, col, br, range)
				return new("PointLight", {Color = col, Brightness = br, Range = range, Shadows = false}, parent)
			end

			local function between(parent, a, b, d, color, material, o)
				o = o or {}
				o.cyl = true
				local len = (b - a).Magnitude
				if len < 0.05 then len = 0.05 end
				return mk(parent, V3(len, d, d), CFrame.lookAt((a + b) / 2, b) * ANG(0, pi / 2, 0), color, material, o)
			end

			local function group(home)
				local g = Instance.new("Model")
				local anchor = mk(g, V3(0.2, 0.2, 0.2), home, C(0, 0, 0), SMOOTH, {trans = 1, shadow = false})
				g.PrimaryPart = anchor
				g.Parent = model
				local function part(size, rel, color, material, o)
					return mk(g, size, home * rel, color, material, o)
				end
				return g, part
			end

			local function hologram(part, text, color, w, h, off)
				local bb = new("BillboardGui", {
					Size = UDim2.fromOffset(w or 280, h or 70), StudsOffset = V3(0, off or 5, 0),
					LightInfluence = 0, MaxDistance = 150, AlwaysOnTop = false, Adornee = part,
				}, part)
				local tl = new("TextLabel", {
					BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.Code, TextScaled = true,
					TextColor3 = color, TextStrokeColor3 = C(0, 0, 0), TextStrokeTransparency = 0.45,
					TextTransparency = 1, Text = text,
				}, bb)
				return tl
			end

			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Include
			rp.FilterDescendantsInstances = {model}
			rp.IgnoreWater = true
			local function groundAt(x, z)
				local res = workspace:Raycast(O + V3(x, 60, z), V3(0, -140, 0), rp)
				if res then return res.Position.Y - O.Y, res.Normal, res.Instance end
				return 0, V3(0, 1, 0), nil
			end

			local reserved = {}
			local function reserve(x, z, rad) reserved[#reserved + 1] = {x, z, rad} end
			local function clear(x, z, rad)
				if x * x + (z + 30) * (z + 30) < 6400 then return false end
				for _, q in ipairs(reserved) do
					local dx, dz = x - q[1], z - q[2]
					local rr = q[3] + (rad or 0)
					if dx * dx + dz * dz < rr * rr then return false end
				end
				return true
			end
			reserve(150, 170, 60); reserve(105, 120, 40); reserve(-75, 100, 24); reserve(-22, 40, 18); reserve(32, 58, 18)
			reserve(-210, 260, 58); reserve(200, 280, 58); reserve(60, 440, 72); reserve(170, -30, 82); reserve(-150, -40, 68)
			reserve(-30, 330, 112); reserve(-190, 30, 28); reserve(90, 320, 30); reserve(120, -120, 30)

			local ups = {}
			local function onUpdate(f) ups[#ups + 1] = f end
			local function section(name, fn)
				local ok, e = pcall(fn)
				if not ok then warnRG("deserto/" .. name .. ":", e) end
			end
			local WIND = math.rad(24)
			local lastT = nil

			section("chao", function()
				mk(model, V3(2000, 2, 2000), W(0, -1, 0), SAND, M.Sand, {solid = true})
				local patches, tries = {}, 0
				while #patches < 28 and tries < 400 do
					tries = tries + 1
					local x, z, rad = rnd(-700, 700), rnd(-700, 700), rnd(24, 80)
					local ok = true
					for _, q in ipairs(patches) do
						local dx, dz = x - q[1], z - q[2]
						local rr = rad + q[3] + 3
						if dx * dx + dz * dz < rr * rr then ok = false end
					end
					if ok then
						patches[#patches + 1] = {x, z, rad}
						local col = SAND:Lerp(pick({C(250, 205, 140), C(196, 128, 74), C(212, 140, 84), C(240, 186, 118)}), rnd(0.35, 0.8))
						column(model, 0.12, rad * 2, W(x, 0.07, z), col, M.Sand, {shadow = false})
					end
				end
				local lx, lz = 170, -30
				column(model, 0.08, 150, W(lx, 0.04, lz), C(92, 62, 48), MUDM, {shadow = false})
				for i = -4, 4 do
					for j = -4, 4 do
						local x, z = lx + i * 16 + rnd(-1, 1), lz + j * 16 + rnd(-1, 1)
						if (x - lx) * (x - lx) + (z - lz) * (z - lz) < 4900 then
							local col = C(216, 192, 162):Lerp(C(176, 138, 108), rnd(0, 0.7))
							mk(model, V3(rnd(13.2, 14.8), rnd(0.25, 0.55), rnd(13.2, 14.8)),
								CF(W(x, 0.12, z)) * ANG(rnd(-0.04, 0.04), rnd(-0.2, 0.2), rnd(-0.04, 0.04)), col, SALTM, {shadow = false})
						end
					end
				end
			end)

			section("dunas", function()
				local function dune(x, z, yaw, L, Wd, th, col)
					local base = CF(W(x, 0, z)) * ANG(0, yaw, 0)
					local segs = { {0, 0.5, 1}, {0.4, 0.3, 0.62}, {-0.4, 0.3, 0.62}, {0.635, 0.17, 0.3}, {-0.635, 0.17, 0.3} }
					for _, sg in ipairs(segs) do
						local w = Wd * sg[3]
						local h = w * sin(th)
						for _, sd in ipairs({1, -1}) do
							local c = (sd > 0) and col or col:Lerp(C(130, 66, 42), 0.2)
							local cf = base * CF(0, h, sg[1] * L) * ANG(0, 0, -sd * th) * CF(sd * w / 2, -1, 0)
							mk(model, V3(w, 2, L * sg[2] + 1.5), cf, c, M.Sand, {solid = true, shadow = false})
						end
					end
				end
				local placed, tries = 0, 0
				while placed < 26 and tries < 600 do
					tries = tries + 1
					local a, d = rnd(0, TAU), rnd(60, 520)
					local x, z = cos(a) * d, sin(a) * d
					local L, Wd = rnd(70, 170), rnd(34, 62)
					if clear(x, z, L * 0.38) then
						placed = placed + 1
						dune(x, z, WIND + rnd(-0.28, 0.28), L, Wd, math.rad(rnd(7, 11)), SAND:Lerp(C(255, 214, 150), rnd(0.1, 0.5)))
						reserve(x, z, L * 0.38)
					end
				end
				for i = 1, 18 do
					local a = i / 18 * TAU + rnd(-0.12, 0.12)
					local d = rnd(560, 760)
					local h = rnd(14, 38)
					mk(model, V3(rnd(160, 300), h * 2, rnd(80, 150)), CF(W(cos(a) * d, 0, sin(a) * d)) * ANG(0, WIND + rnd(-0.3, 0.3), 0),
						SAND:Lerp(HAZE, 0.2), M.Sand, {ellipsoid = true, shadow = false})
				end
			end)

			section("mesas", function()
				local function stack(x, z, R0, Ht, layers, fogMix)
					column(model, 16, R0 * 2.5, W(x, 8, z), tint(C(206, 140, 84), fogMix), M.Sand, {solid = true, shadow = false})
					column(model, 8, R0 * 2.15, W(x, 20, z), tint(C(190, 118, 70), fogMix), SANDSTONE, {solid = true, shadow = false})
					local y, rad = 24, R0
					local each = (Ht - 24) / layers
					for k = 1, layers do
						local th = each * rnd(0.85, 1.2)
						column(model, th, rad * 2, W(x, y + th / 2, z), tint(pick(STRATA), fogMix), SANDSTONE, {solid = true, shadow = false})
						y = y + th
						rad = rad * rnd(0.86, 0.98)
						if k % 2 == 0 and rad > 14 then
							column(model, 1.2, rad * 2.14, W(x, y + 0.6, z), tint(C(224, 168, 106), fogMix), SANDSTONE, {solid = true, shadow = false})
							y = y + 1.2
						end
					end
					column(model, 2.5, rad * 1.85, W(x, y + 1.25, z), tint(C(238, 190, 128), fogMix), M.Sand, {shadow = false})
				end
				for i = 1, 38 do
					local a = i / 38 * TAU + rnd(-0.03, 0.03)
					local d = rnd(850, 900)
					stack(cos(a) * d, sin(a) * d, rnd(105, 150), rnd(70, 190), r:NextInteger(5, 8), 0.4)
				end
				local nb, tries = 0, 0
				while nb < 9 and tries < 300 do
					tries = tries + 1
					local a, d = rnd(0, TAU), rnd(470, 690)
					local x, z = cos(a) * d, sin(a) * d
					local dw = sqrt(x * x + (z - 150) * (z - 150))
					if dw > 460 and clear(x, z, 60) then
						nb = nb + 1
						reserve(x, z, 70)
						stack(x, z, rnd(26, 56), rnd(60, 140), r:NextInteger(4, 7), 0.12)
					end
				end
				local nh, t2 = 0, 0
				while nh < 16 and t2 < 300 do
					t2 = t2 + 1
					local a, d = rnd(0, TAU), rnd(100, 560)
					local x, z = cos(a) * d, sin(a) * d
					if clear(x, z, 16) then
						nh = nh + 1
						reserve(x, z, 16)
						local y, rad = 0, rnd(4.5, 8)
						for _ = 1, r:NextInteger(3, 5) do
							local th = rnd(5, 9)
							column(model, th, rad * 2, W(x + rnd(-0.4, 0.4), y + th / 2, z + rnd(-0.4, 0.4)), pick(STRATA), SANDSTONE, {solid = true, shadow = false})
							y = y + th
							rad = rad * rnd(0.78, 1.08)
						end
						local cap = rad * rnd(1.7, 2.4)
						mk(model, V3(rnd(3, 5), cap * 2, cap * 2), CF(W(x, y + 2, z)) * ANG(rnd(-0.08, 0.08), 0, pi / 2 + rnd(-0.1, 0.1)),
							tint(C(150, 80, 54), 0.1), SANDSTONE, {solid = true, cyl = true})
					end
				end
				local nr, t3 = 0, 0
				while nr < 70 and t3 < 400 do
					t3 = t3 + 1
					local a, d = rnd(0, TAU), rnd(70, 600)
					local x, z = cos(a) * d, sin(a) * d
					if clear(x, z, 4) then
						nr = nr + 1
						local s = rnd(1.5, 7)
						mk(model, V3(s * rnd(0.9, 1.6), s * rnd(0.6, 1), s * rnd(0.9, 1.6)),
							CF(W(x, s * 0.2, z)) * ANG(rnd(-0.4, 0.4), rnd(0, 6.28), rnd(-0.4, 0.4)), tint(pick(STRATA), 0.1), SANDSTONE, {solid = s > 3.2})
					end
				end
			end)

			section("arcos", function()
				local arches = {}
				local function arch(x, z, yaw, span, rise, thick)
					local base = CF(W(x, 0, z)) * ANG(0, yaw, 0)
					local R = span / 2
					local depth = thick * 1.5
					local N = 12
					local pts = {}
					for i = 0, N do
						local ph = pi * i / N
						pts[i] = V3(R * cos(ph), rise + R * 0.85 * sin(ph), 0)
					end
					for i = 0, N - 1 do
						local a, b = pts[i], pts[i + 1]
						local mid = (a + b) / 2
						local ang = math.atan2(b.Y - a.Y, b.X - a.X)
						local len = (b - a).Magnitude
						local k = sin(pi * (i + 0.5) / N)
						local th = thick * (1.25 - 0.45 * k)
						mk(model, V3(len + 2.2, th, depth), base * CF(mid.X, mid.Y, 0) * ANG(0, 0, ang), STRATA[(i % #STRATA) + 1], SANDSTONE, {solid = true})
					end
					for _, sd in ipairs({-1, 1}) do
						local y, i = 0, 0
						while y < rise do
							i = i + 1
							local h = min(rnd(5, 9), rise - y + 1)
							mk(model, V3(thick * rnd(1.2, 1.5), h, depth * rnd(0.9, 1.15)),
								base * CF(sd * R + rnd(-0.5, 0.5), y + h / 2, 0) * ANG(0, rnd(-0.06, 0.06), 0),
								STRATA[((i + (sd > 0 and 2 or 0)) % #STRATA) + 1], SANDSTONE, {solid = true})
							y = y + h
						end
						for _ = 1, 4 do
							local s = rnd(2, 5)
							mk(model, V3(s * 1.3, s * 0.7, s), base * CF(sd * R + rnd(-9, 9), s * 0.2, rnd(-9, 9)) * ANG(rnd(-0.4, 0.4), rnd(0, 6.28), rnd(-0.4, 0.4)),
								pick(STRATA), SANDSTONE, {solid = true})
						end
					end
					local runes = {}
					for _, i in ipairs({1, 3, 5, 7, 9, 11}) do
						local p = pts[i]
						local n = (V3(0, rise, 0) - p).Unit
						local pos = p + n * (thick * 0.55)
						local ang = math.atan2(pts[min(i + 1, N)].Y - pts[i - 1].Y, pts[min(i + 1, N)].X - pts[i - 1].X)
						for _, fs in ipairs({-1, 1}) do
							local zf = fs * (depth / 2 + 0.2)
							local b1 = mk(model, V3(0.55, thick * 0.8, 0.3), base * CF(pos.X, pos.Y, zf) * ANG(0, 0, ang + pi / 2), C(80, 255, 235), NEON, {shadow = false})
							local b2 = mk(model, V3(0.45, thick * 0.35, 0.3), base * CF(pos.X, pos.Y, zf) * ANG(0, 0, ang) * CF(0, 0, 0) * CF(thick * 0.35, thick * 0.3, 0), C(80, 255, 235), NEON, {shadow = false})
							runes[#runes + 1] = {b1, rnd(0, TAU)}
							runes[#runes + 1] = {b2, rnd(0, TAU)}
						end
					end
					local topY = rise + R * 0.85
					local ring = mk(model, V3(0.5, 6, 6), base * CF(0, topY, -depth / 2 - 0.3) * ANG(0, pi / 2, 0), C(255, 140, 240), NEON, {cyl = true, shadow = false})
					local ring2 = mk(model, V3(0.5, 6, 6), base * CF(0, topY, depth / 2 + 0.3) * ANG(0, pi / 2, 0), C(255, 140, 240), NEON, {cyl = true, shadow = false})
					local veil = mk(model, V3(R * 1.25, rise * 0.9, 0.3), base * CF(0, rise * 0.46, 0), C(120, 240, 255), NEON, {trans = 0.93, shadow = false})
					local lt = light(veil, C(120, 240, 255), 0.7, 45)
					local em = emit(veil, {
						Rate = 0, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(180, 180),
						Size = NumberSequence.new(0.5, 0), LightEmission = 1, Color = ColorSequence.new(C(130, 255, 240)),
						Transparency = NumberSequence.new(0.1, 1), Texture = SPARK, Acceleration = V3(0, 3, 0),
					})
					arches[#arches + 1] = {x = x, z = z, span = span, veil = veil, runes = runes, lt = lt, em = em, ring = ring, ring2 = ring2, lv = 0, ph = rnd(0, TAU)}
				end
				arch(-210, 260, 0.45, 64, 32, 9)
				arch(200, 280, -0.7, 48, 24, 7)
				arch(60, 440, 0.12, 84, 44, 11)
				onUpdate(function(t, dt, lp)
					for _, a in ipairs(arches) do
						local d = dist(lp, a.x, a.z)
						if d < 320 then
							local near = (d < a.span * 0.9) and 1 or 0
							a.lv = a.lv + (near - a.lv) * min(1, dt * 3)
							local pulse = 0.5 + 0.5 * sin(t * 2 + a.ph)
							a.veil.Transparency = clamp01(0.94 - 0.38 * a.lv - 0.04 * pulse)
							for _, ru in ipairs(a.runes) do
								ru[1].Transparency = clamp01(0.5 - 0.45 * a.lv + 0.22 * sin(t * 3 + ru[2]))
							end
							a.ring.Transparency = clamp01(0.3 - 0.3 * a.lv + 0.15 * pulse)
							a.ring2.Transparency = a.ring.Transparency
							a.lt.Brightness = 0.5 + 2.6 * a.lv + 0.3 * pulse
							a.em.Rate = 90 * a.lv
						end
					end
				end)
			end)

			section("ceu", function()
				local Sp = State.space
				local TX = Sp.TEX
				local suns = {}
				local skyAnim = {}

				local function sun(x, y, z, d, col, haloCol, tex, tint, sgn)
					local pos = W(x, y, z)
					local core = Sp.texBall(model, CF(pos), d / 2, tex, 0, NEON)
					local plasma = nil
					if core then
						plasma = Sp.texBall(model, CF(pos), d / 2 * 1.012, tex, 0.5, NEON)
					else
						core = ball(model, d, pos, col, NEON, {shadow = false})
					end
					local halos = {}
					for i = 1, 3 do
						halos[i] = ball(model, d * (1.3 + i * 0.45), pos, haloCol, NEON, {shadow = false, trans = 0.9 + i * 0.03})
					end

					local rays = nil
					if type(TX.k22corona) == "string" and TX.k22corona ~= "" then
						local anchor = mk(model, V3(1, 1, 1), CF(pos), C(255, 255, 255), SMOOTH, {trans = 1, shadow = false})
						local D1 = 6.2 * d
						local bb = new("BillboardGui", {
							Adornee = anchor, Size = UDim2.new(D1, 0, D1, 0), LightInfluence = 0, AlwaysOnTop = false, MaxDistance = 1e9,
						}, anchor)
						rays = {}
						for k, def in ipairs({ { 1, 0.62, 0.026 }, { 4.4 / 6.2, 0.42, -0.016 } }) do
							rays[k] = {
								a = def[2], spd = def[3],
								gui = new("ImageLabel", {
									BackgroundTransparency = 1, BorderSizePixel = 0, Image = TX.k22corona,
									AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
									Size = UDim2.fromScale(def[1], def[1]), ImageColor3 = tint,
									ImageTransparency = 1 - def[2], Rotation = 0,
								}, bb),
							}
						end
					end
					suns[#suns + 1] = {core = core, plasma = plasma, halos = halos, d = d, ph = rnd(0, TAU), pos = pos, rays = rays, sgn = sgn}
				end
				local FAR, BIG = 2.4, 1.8
				local mc, mr = W(470, 330, 480), 36
				local bigMoon = Sp.texBall(model, CF(mc), mr, TX.lua, 0, SMOOTH)
				if bigMoon then
					skyAnim[#skyAnim + 1] = function(t) bigMoon.CFrame = CF(mc) * ANG(0, t * 0.012, 0) end
				else
					ball(model, mr * 2, mc, C(205, 196, 190), SMOOTH, {shadow = false})
				end
				local toPl = (W(0, 5, -30) - mc).Unit
				local made = 0
				for _ = 1, 40 do
					if made >= 11 then break end
					local v = (toPl + V3(rnd(-0.9, 0.9), rnd(-0.9, 0.9), rnd(-0.9, 0.9))).Unit
					if v:Dot(toPl) > 0.4 then
						made = made + 1
						local cr = rnd(2.5, 7)
						local p = mc + v * (mr - 0.2)
						if not bigMoon then mk(model, V3(0.8, cr * 2, cr * 2), CFrame.lookAt(p, p + v) * ANG(0, pi / 2, 0), C(150, 142, 138), SMOOTH, {cyl = true, shadow = false}) end
					end
				end

				onUpdate(function(t, dt, lp)
					for _, s in ipairs(suns) do
						local p = 0.5 + 0.5 * sin(t * 0.6 + s.ph)
						for i, h in ipairs(s.halos) do
							local k = s.d * (1.3 + i * 0.45) * (1 + 0.04 * p * i)
							h.Size = V3(k, k, k)
							h.Transparency = clamp01(0.9 + i * 0.03 + 0.03 * (1 - p))
						end
						if s.plasma then
							s.core.CFrame = CF(s.pos) * ANG(0, t * 0.045 * s.sgn, 0)
							s.plasma.CFrame = CF(s.pos) * ANG(1.1, 0, 0) * ANG(0, -t * 0.07 * s.sgn, 0)
						end
						if s.rays then
							for _, rr in ipairs(s.rays) do
								rr.gui.Rotation = math.deg(s.sgn * t * rr.spd)
								rr.gui.ImageTransparency = clamp01(1 - rr.a * (0.8 + 0.2 * p))
							end
						end
					end
					for _, fn in ipairs(skyAnim) do fn(t) end
				end)
			end)

			section("ceu2", function()
				local saucers = {}
				for i = 1, 2 do
					local home = CF(W(0, -400, 0))
					local g, part = group(home)
					part(V3(22, 5, 22), CF(0, 0, 0), C(168, 176, 188), METAL, {ellipsoid = true, shadow = false})
					part(V3(10, 7, 10), CF(0, 2.6, 0), C(110, 230, 255), GLASS, {ellipsoid = true, trans = 0.35, shadow = false})
					local lamps = {}
					for k = 1, 8 do
						local a = k / 8 * TAU
						lamps[k] = part(V3(1.6, 1.6, 1.6), CF(cos(a) * 10.2, -0.4, sin(a) * 10.2), C(255, 220, 120), NEON, {ball = true, shadow = false})
					end
					local lt = light(lamps[1], C(255, 220, 120), 1.5, 40)
					saucers[i] = {g = g, lamps = lamps, spd = (i == 1) and 24 or 15, y = (i == 1) and 230 or 300, z = (i == 1) and 560 or 700, off = rnd(0, 1600), ph = rnd(0, TAU)}
				end
				local islets = {}
				for i = 1, 8 do
					local a, d = rnd(0, TAU), rnd(90, 430)
					local x, z = cos(a) * d, sin(a) * d
					local y = rnd(55, 120)
					local home = CF(W(x, y, z))
					local g, part = group(home)
					local D = rnd(14, 28)
					part(V3(3, D, D), CF(0, 0, 0) * ANG(0, 0, pi / 2), pick(STRATA), SANDSTONE, {cyl = true})
					part(V3(0.6, D * 0.96, D * 0.96), CF(0, 1.6, 0) * ANG(0, 0, pi / 2), SAND, M.Sand, {cyl = true, shadow = false})
					part(V3(5, D * 0.7, D * 0.7), CF(0, -4, 0) * ANG(0, 0, pi / 2), tint(pick(STRATA), 0.1), SANDSTONE, {cyl = true})
					part(V3(6, D * 0.42, D * 0.42), CF(0, -9.5, 0) * ANG(0, 0, pi / 2), tint(pick(STRATA), 0.1), SANDSTONE, {cyl = true})
					local cry = part(V3(1.6, 9, 1.6), CF(0, -17, 0) * ANG(0, 0, pi), C(90, 255, 230), NEON, {trans = 0.1, shadow = false})
					if i % 3 == 0 then light(cry, C(90, 255, 230), 1.2, 35) end
					for _ = 1, 3 do
						local s = rnd(1.5, 3)
						part(V3(s, s * 1.8, s), CF(rnd(-D * 0.3, D * 0.3), 2.4 + s * 0.8, rnd(-D * 0.3, D * 0.3)), pick({C(120, 255, 235), C(255, 130, 230)}), NEON, {trans = 0.2, shadow = false})
					end
					islets[i] = {g = g, home = home, ph = rnd(0, TAU), sp = rnd(0.25, 0.5), yaw = rnd(0.05, 0.14)}
				end
				local flyers = {}
				local BODYCOLS = { C(70, 44, 58), C(96, 56, 50), C(58, 50, 72) }
				local WINGCOLS = { C(214, 118, 84), C(232, 150, 96), C(190, 96, 110) }
				local FORM = { {0, 0, 0}, {-8, 0.6, 9}, {8, 0.6, 9}, {-16, 1.2, 18}, {16, 1.2, 18}, {0, 1, 20} }

				local function makePtero(s, bodyCol, wingCol)
					local g, part = group(CF(W(0, -400, 0)))
					local bone = C(70, 44, 58)
					part(V3(1.6 * s, 1.5 * s, 6 * s), CF(0, 0, 0), bodyCol, SMOOTH, {ellipsoid = true, shadow = false})
					part(V3(1 * s, 1 * s, 2.4 * s), CF(0, 0.5 * s, -3.3 * s) * ANG(-0.35, 0, 0), bodyCol, SMOOTH, {ellipsoid = true, shadow = false})
					part(V3(1.15 * s, 1 * s, 2.4 * s), CF(0, 1 * s, -4.9 * s), bodyCol:Lerp(BONE, 0.2), SMOOTH, {ellipsoid = true, shadow = false})
					part(V3(0.4 * s, 0.4 * s, 3.4 * s), CF(0, 0.85 * s, -7.2 * s) * ANG(0.06, 0, 0), BONE, SMOOTH, {shadow = false})
					part(V3(0.22 * s, 1.9 * s, 2.8 * s), CF(0, 1.9 * s, -4.4 * s) * ANG(0.55, 0, 0), wingCol, SMOOTH, {shadow = false})
					for _, sd in ipairs({-1, 1}) do
						part(V3(0.32 * s, 0.32 * s, 0.32 * s), CF(sd * 0.5 * s, 1.2 * s, -5.2 * s), C(255, 214, 90), NEON, {ball = true, shadow = false})
						part(V3(0.25 * s, 1.4 * s, 0.25 * s), CF(sd * 0.5 * s, -1.1 * s, 1.4 * s) * ANG(0.5, 0, 0), bodyCol, SMOOTH, {shadow = false})
					end
					part(V3(0.3 * s, 0.3 * s, 5 * s), CF(0, -0.1 * s, 5.2 * s), bodyCol, SMOOTH, {shadow = false})
					part(V3(1.7 * s, 0.16 * s, 1.9 * s), CF(0, -0.1 * s, 8 * s) * ANG(0, 0.785, 0), wingCol, SMOOTH, {shadow = false})

					local hide = CF(W(0, -400, 0))
					local wings = {}
					for k, sd in ipairs({-1, 1}) do
						wings[k] = {
							sd = sd,
							inM = mk(model, V3(5 * s, 0.14 * s, 3.4 * s), hide, wingCol, SMOOTH, {shadow = false, trans = 0.08}),
							inB = mk(model, V3(5 * s, 0.3 * s, 0.3 * s), hide, bone, SMOOTH, {cyl = true, shadow = false}),
							outM = mk(model, V3(6.2 * s, 0.12 * s, 2.4 * s), hide, wingCol, SMOOTH, {shadow = false, trans = 0.08}),
							outB = mk(model, V3(6.2 * s, 0.26 * s, 0.26 * s), hide, bone, SMOOTH, {cyl = true, shadow = false}),
							tip = mk(model, V3(2.6 * s, 0.1 * s, 1.2 * s), hide, wingCol, SMOOTH, {shadow = false, trans = 0.08}),
						}
					end

					local ph = rnd(0, TAU)
					local P = {}
					function P.pose(t)
						local amp = clamp01(0.55 + 0.9 * sin(t * 0.3 + ph * 1.7))
						local w = 3.1 + 0.4 * sin(ph)
						return 0.12 + 0.55 * amp * sin(t * w + ph), -0.05 + 0.5 * amp * sin(t * w + ph - 1)
					end
					function P.place(cf, a1, a2)
						g:PivotTo(cf)
						for _, w in ipairs(wings) do
							local sd = w.sd
							local sh = cf * CF(sd * 0.7 * s, 0.2 * s, -0.6 * s) * ANG(0, 0, sd * a1)
							w.inM.CFrame = sh * CF(sd * 2.5 * s, 0, 0.9 * s)
							w.inB.CFrame = sh * CF(sd * 2.5 * s, 0.02 * s, -0.8 * s)
							local el = sh * CF(sd * 5 * s, 0, 0) * ANG(0, -sd * 0.28, sd * a2)
							w.outM.CFrame = el * CF(sd * 3.1 * s, 0, 0.7 * s)
							w.outB.CFrame = el * CF(sd * 3.1 * s, 0.02 * s, -0.5 * s)
							w.tip.CFrame = el * CF(sd * 6.6 * s, 0, 0.35 * s) * ANG(0, -sd * 0.4, 0)
						end
					end
					return P
				end

				local function flock(cx, cz, R, y, w, n, s)
					local members = {}
					for i = 1, n do members[i] = makePtero(s * rnd(0.9, 1.15), pick(BODYCOLS), pick(WINGCOLS)) end
					local ph0 = rnd(0, TAU)
					local sgn = (w > 0) and 1 or -1
					flyers[#flyers + 1] = function(t)
						local a = t * w + ph0
						local pos = W(cx + cos(a) * R, y + sin(t * 0.4 + ph0) * 4, cz + sin(a) * R)
						local dir = V3(-sin(a) * sgn, 0, cos(a) * sgn)
						local look = CFrame.lookAt(pos, pos + dir)
						for i, m in ipairs(members) do
							local o = FORM[i]
							local bob = sin(t * 0.8 + i * 1.7) * 1.6
							local a1, a2 = m.pose(t)
							m.place(look * CF(o[1], o[2] + bob, o[3]) * ANG(0, 0, -0.32 * sgn), a1, a2)
						end
					end
				end
				flock(-60, 200, 130, 105, 0.16, 5, 1)
				flock(120, 330, 170, 150, -0.12, 4, 1.15)
				flock(-250, 90, 90, 85, 0.2, 3, 0.9)

				do
					local g, part = group(CF(W(0, -400, 0)))
					local dark, belly = C(62, 48, 72), C(120, 255, 235)
					part(V3(10, 5, 30), CF(0, 0, 0), dark, SMOOTH, {ellipsoid = true, shadow = false})
					for _, sd in ipairs({-1, 1}) do
						part(V3(3.2, 1.2, 7), CF(sd * 3.2, -0.6, -16) * ANG(0, sd * 0.25, 0), dark, SMOOTH, {ellipsoid = true, shadow = false})
					end
					part(V3(0.7, 0.7, 30), CF(0, -0.3, 27), dark, SMOOTH, {shadow = false})
					part(V3(3.4, 0.5, 20), CF(0, -2.35, 0), belly, NEON, {ellipsoid = true, shadow = false, trans = 0.35})
					local mw = {}
					local hide = CF(W(0, -400, 0))
					for k, sd in ipairs({-1, 1}) do
						local dots = {}
						for j = 1, 4 do
							dots[j] = mk(model, V3(1.4, 0.4, 1.4), hide, belly, NEON, {ellipsoid = true, shadow = false, trans = 0.2})
						end
						mw[k] = {sd = sd, wing = mk(model, V3(28, 1.3, 20), hide, dark, SMOOTH, {ellipsoid = true, shadow = false}), dots = dots}
					end
					local mph = rnd(0, TAU)
					flyers[#flyers + 1] = function(t)
						local a = t * 0.032 + mph
						local pos = W(cos(a) * 560, 360 + sin(t * 0.2) * 12, 250 + sin(a) * 560)
						local dir = V3(-sin(a), 0, cos(a))
						local cf = CFrame.lookAt(pos, pos + dir) * ANG(0, 0, -0.18)
						g:PivotTo(cf)
						local fl = 0.1 + 0.22 * sin(t * 0.9)
						for _, q in ipairs(mw) do
							local wf = cf * CF(q.sd * 4.5, 0.2, 2) * ANG(0, 0, q.sd * fl)
							q.wing.CFrame = wf * CF(q.sd * 12, 0, 0)
							for j, d in ipairs(q.dots) do
								d.CFrame = wf * CF(q.sd * (5 + j * 5), -0.75, (j % 2 == 0) and 2 or -2)
							end
						end
					end
				end

				local SKIN, SKIN2, MEMB, BEAK = C(86, 54, 62), C(118, 72, 74), C(214, 132, 98), C(214, 192, 160)
				local pteros = {}
				for i = 1, 6 do
					local g, part = group(CF(W(0, -400, 0)))
					local sc = rnd(0.9, 1.5)
					local function P(size, x, y, z, col, mat, o, rot)
						local rel = CF(x * sc, y * sc, z * sc)
						if rot then rel = rel * rot end
						return part(size * sc, rel, col, mat or SMOOTH, o or {shadow = false})
					end
					P(V3(1.7, 1.6, 6), 0, 0, 0, SKIN, SMOOTH, {ellipsoid = true, shadow = false})
					P(V3(1.2, 0.9, 4.6), 0, -0.5, 0.3, SKIN2, SMOOTH, {ellipsoid = true, shadow = false})
					P(V3(0.9, 0.9, 2.8), 0, 0.4, -3.4, SKIN, SMOOTH, {ellipsoid = true, shadow = false})
					P(V3(1.2, 1.1, 2.4), 0, 0.7, -5.0, SKIN2, SMOOTH, {ellipsoid = true, shadow = false})
					P(V3(0.5, 0.5, 4.2), 0, 0.45, -7.2, BEAK, SMOOTH, {ellipsoid = true, shadow = false})
					P(V3(0.3, 1.5, 3.4), 0, 1.4, -4.3, C(200, 70, 60), SMOOTH, {ellipsoid = true, shadow = false}, ANG(0.55, 0, 0))
					for _, sd in ipairs({-1, 1}) do
						P(V3(0.32, 0.32, 0.32), sd * 0.5, 0.95, -5.6, C(255, 170, 60), NEON, {ball = true, shadow = false})
					end
					P(V3(0.35, 0.35, 4.5), 0, -0.1, 5.4, SKIN, SMOOTH, {ellipsoid = true, shadow = false})
					P(V3(1.5, 0.12, 1.8), 0, -0.1, 7.8, MEMB, SMOOTH, {shadow = false, trans = 0.1})

					local wings = {}
					for k, sd in ipairs({-1, 1}) do
						local stash = CF(W(0, -400, 0))
						wings[k] = {
							sd = sd,
							armA = mk(model, V3(5.4 * sc, 0.4 * sc, 0.55 * sc), stash, SKIN, SMOOTH, {shadow = false}),
							memA = mk(model, V3(5.4 * sc, 0.1, 4.6 * sc), stash, MEMB, SMOOTH, {shadow = false, trans = 0.12}),
							armB = mk(model, V3(6 * sc, 0.32 * sc, 0.45 * sc), stash, SKIN, SMOOTH, {shadow = false}),
							memB = mk(model, V3(6 * sc, 0.1, 3.4 * sc), stash, MEMB, SMOOTH, {shadow = false, trans = 0.12}),
						}
					end
					pteros[i] = {g = g, wings = wings, sc = sc, cx = rnd(-250, 250), cz = rnd(60, 380), R = rnd(70, 160), y = rnd(165, 215), w = rnd(0.12, 0.22) * ((i % 2 == 0) and 1 or -1), ph = rnd(0, TAU)}
				end

				local swifts = {}
				for i = 1, 9 do
					local stash = CF(W(0, -400, 0))
					local row = floor(i / 2)
					local side = (i % 2 == 0) and -1 or 1
					swifts[i] = {
						b = mk(model, V3(0.7, 0.6, 2), stash, C(60, 40, 48), SMOOTH, {ellipsoid = true, shadow = false}),
						wl = mk(model, V3(2.2, 0.08, 0.9), stash, C(150, 100, 84), SMOOTH, {shadow = false}),
						wr = mk(model, V3(2.2, 0.08, 0.9), stash, C(150, 100, 84), SMOOTH, {shadow = false}),
						off = (i == 1) and V3(0, 0, 0) or V3(side * row * 2.6, rnd(-0.4, 0.4), row * 2.4),
						ph = rnd(0, TAU),
					}
				end

				local function updateFlyers(t)
					for _, gl in ipairs(pteros) do
						local sc = gl.sc
						local a = t * gl.w + gl.ph
						local k = 0.5 + 0.5 * sin(t * 0.4 + gl.ph * 2)
						local y = gl.y + sin(t * 0.5 + gl.ph) * 6 + k * 5
						local pos = W(gl.cx + cos(a) * gl.R, y, gl.cz + sin(a) * gl.R)
						local sgn = (gl.w > 0) and 1 or -1
						local dir = V3(-sin(a) * sgn, 0, cos(a) * sgn)
						local cf = CFrame.lookAt(pos, pos + dir) * ANG(-0.06 + 0.16 * k, 0, -0.38 * sgn)
						gl.g:PivotTo(cf)
						local amp = 0.1 + 0.55 * k * k
						local f1 = amp * sin(t * 4.2 + gl.ph) + 0.12
						local f2 = amp * 1.5 * sin(t * 4.2 + gl.ph - 0.9) + 0.1
						for _, wg in ipairs(gl.wings) do
							local sd = wg.sd
							local sh = cf * CF(sd * 0.7 * sc, 0.35 * sc, -1 * sc) * ANG(0, 0, sd * f1)
							wg.armA.CFrame = sh * CF(sd * 2.7 * sc, 0, 0)
							wg.memA.CFrame = sh * CF(sd * 2.7 * sc, 0, 1.9 * sc)
							local el = sh * CF(sd * 5.4 * sc, 0, 0) * ANG(0, -sd * 0.4, sd * f2)
							wg.armB.CFrame = el * CF(sd * 3 * sc, 0, 0)
							wg.memB.CFrame = el * CF(sd * 3 * sc, 0, 1.4 * sc)
						end
					end

					local fa = t * 0.07
					local lp = W(cos(fa) * 320, 255 + sin(t * 0.3) * 10, 150 + sin(fa) * 320)
					local lead = CFrame.lookAt(lp, lp + V3(-sin(fa), 0, cos(fa)))
					for _, s in ipairs(swifts) do
						local cf = lead * CF(s.off + V3(0, sin(t * 1.3 + s.ph) * 0.6, 0))
						s.b.CFrame = cf
						local f = 0.7 * sin(t * 11 + s.ph)
						s.wl.CFrame = cf * CF(-0.4, 0.1, 0) * ANG(0, 0, -f) * CF(-1.1, 0, 0)
						s.wr.CFrame = cf * CF(0.4, 0.1, 0) * ANG(0, 0, f) * CF(1.1, 0, 0)
					end
				end
				flyers[#flyers + 1] = updateFlyers
				updateFlyers(0)

				onUpdate(function(t, dt, lp)
					for _, s in ipairs(saucers) do
						local x = -850 + ((t * s.spd + s.off) % 1700)
						local y = s.y + sin(t * 0.7 + s.ph) * 6
						s.g:PivotTo(CF(W(x, y, s.z)) * ANG(0, t * 0.8, 0.06))
						for k, l in ipairs(s.lamps) do
							l.Transparency = (floor(t * 4 + k) % 2 == 0) and 0 or 0.7
						end
					end
					for _, it in ipairs(islets) do
						it.g:PivotTo(it.home * CF(0, sin(t * it.sp + it.ph) * 3, 0) * ANG(0, t * it.yaw, sin(t * 0.3 + it.ph) * 0.03))
					end
					for _, fn in ipairs(flyers) do fn(t) end
				end)
			end)

			section("placas", function()
				local sx, sz = -22, 40
				mk(model, V3(0.8, 15, 0.8), W(sx, 7.1, sz), C(112, 82, 52), WOOD, {})
				local boards = {
					{y = 13.2, yaw = 0.18, w = 13, txt = "CITADEL DOS RICKS  ->", col = C(206, 70, 62)},
					{y = 9.8, yaw = -0.22, w = 12, txt = "<-  DIMENSAO C-137", col = C(60, 130, 210)},
					{y = 6.4, yaw = 0.1, w = 11, txt = "SCHWIFTY SQUARE  ^", col = C(224, 190, 70)},
					{y = 3.2, yaw = -0.08, w = 9, txt = "VOCE ESTA AQUI", col = C(120, 90, 60)},
				}
				local swing = {}
				for i, b in ipairs(boards) do
					local cf = CF(W(sx, b.y, sz - 0.6)) * ANG(0, b.yaw, 0)
					local bp = mk(model, V3(b.w, 2.6, 0.5), cf, b.col, WOOD, {})
					local sg = new("SurfaceGui", {Face = Enum.NormalId.Front, LightInfluence = 0.2, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 26}, bp)
					new("TextLabel", {
						BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextScaled = true,
						TextColor3 = C(255, 248, 230), TextStrokeColor3 = C(40, 24, 10), TextStrokeTransparency = 0.3, Text = b.txt,
					}, sg)
					swing[i] = {bp, cf, rnd(0, TAU)}
				end

				local tx, tz = 32, 58
				local TVS = 0.5
				local gy = math.clamp(groundAt(tx, tz), -0.5, 3)
				local home = CF(W(tx, gy - 1.0, tz)) * ANG(0.12, -0.35, 0.18)
				local g, part = group(home)
				local function wp(x, y, z) return home:PointToWorldSpace(V3(x, y, z)) end
				part(V3(8, 6.4, 6), CF(0, 3, 0), C(120, 98, 72), WOOD, {})
				part(V3(2, 2, 4), CF(0, 6.8, 0.4), C(60, 52, 44), SMOOTH, {})
				local scr = part(V3(5.6, 4.4, 0.4), CF(-0.6, 3.1, -3.05), C(16, 26, 28), SMOOTH, {})
				part(V3(1.6, 4.4, 0.4), CF(3, 3.1, -3.05), C(60, 50, 40), WOOD, {})
				for _, yy in ipairs({4.3, 2.4}) do
					part(V3(0.5, 1.2, 1.2), CF(3, yy, -3.35) * ANG(0, 0, pi / 2), C(200, 190, 170), METAL, {cyl = true})
				end
				between(g, wp(0, 6.8, 0.4), wp(-3.5, 11.5, 1.5), 0.2, C(190, 190, 200), METAL, {})
				between(g, wp(0, 6.8, 0.4), wp(3.2, 11, -1), 0.2, C(190, 190, 200), METAL, {})
				pcall(function() g:ScaleTo(TVS) end)

				for k = 1, 9 do
					local a2 = k / 9 * TAU + rnd(-0.2, 0.2)
					local d2 = rnd(2.2, 4.4)
					local sz = rnd(2.4, 4.2)
					mk(model, V3(sz * 1.6, sz * 0.75, sz * 1.3), CF(W(tx + cos(a2) * d2, gy + 0.05, tz + sin(a2) * d2)) * ANG(rnd(-0.15, 0.15), rnd(0, 6.28), rnd(-0.15, 0.15)), SAND, M.Sand, {ellipsoid = true, shadow = false})
				end
				local fp = home:PointToWorldSpace(V3(0, 0, -2.4))
				mk(model, V3(7, 1.4, 4), CF(fp.X, O.Y + gy - 0.35, fp.Z) * ANG(0, -0.35, 0), SAND, M.Sand, {ellipsoid = true, shadow = false})
				local sgui = new("SurfaceGui", {Face = Enum.NormalId.Front, LightInfluence = 0, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40}, scr)
				local screen = new("TextLabel", {
					BackgroundColor3 = C(8, 22, 20), BackgroundTransparency = 0, Size = UDim2.fromScale(1, 1), Font = Enum.Font.Code,
					TextScaled = true, TextColor3 = C(120, 255, 200), Text = "...",
				}, sgui)
				local tvLt = light(scr, C(120, 255, 200), 0.8, 14)
				local chans = {"REAL FAKE DOORS", "TWO BROTHERS", "GAZORPAZORPFIELD", "PLUMBUS - COMERCIAL", "NOTICIAS DA C-137", "ESTATICA..."}
				local glyphs = "#%&@$*+=?/<>"
				local ci, nextCh, noiseUntil = 1, 0, 0
				onUpdate(function(t, dt, lp)
					for _, s in ipairs(swing) do
						s[1].CFrame = s[2] * ANG(0, sin(t * 1.3 + s[3]) * 0.045, 0)
					end
					local d = dist(lp, tx, tz)
					if t > nextCh then
						ci = ci % #chans + 1
						nextCh = t + ((d < 28) and 2.2 or 4.5)
						noiseUntil = t + 0.3
						tvLt.Color = Color3.fromHSV((ci * 0.17) % 1, 0.45, 1)
						screen.TextColor3 = tvLt.Color
					end
					if t < noiseUntil then
						local s = ""
						for _ = 1, 22 do
							local k = r:NextInteger(1, #glyphs)
							s = s .. string.sub(glyphs, k, k)
						end
						screen.Text = s .. "\n" .. s
						tvLt.Brightness = 1.4
					else
						screen.Text = "CH " .. ci .. "\n" .. chans[ci]
						tvLt.Brightness = 0.7 + 0.15 * sin(t * 30)
					end
				end)
			end)

			section("monolito", function()
				local mx, mz = 170, -30
				local scf = CFrame.lookAt(W(mx, 15, mz), W(0, 15, mz))
				mk(model, V3(7, 30, 2.2), scf, C(12, 12, 16), SMOOTH, {solid = true, refl = 0.18})
				column(model, 0.4, 24, W(mx, 0.3, mz), C(40, 34, 34), BASALT, {shadow = false})
				for i = 1, 7 do
					local a = i / 7 * TAU
					mk(model, V3(3, rnd(6, 10), 2), CF(W(mx + cos(a) * 15, 3.5, mz + sin(a) * 15)) * ANG(rnd(-0.1, 0.1), -a, rnd(-0.12, 0.12)), tint(C(150, 80, 54), 0.1), SANDSTONE, {solid = true})
				end
				local line = mk(model, V3(0.3, 26, 0.3), scf * CF(0, 0, -1.2), C(235, 245, 255), NEON, {trans = 1, shadow = false})
				local lt = light(line, C(235, 245, 255), 0, 60)
				local rings = {}
				for i = 1, 3 do
					rings[i] = mk(model, V3(0.25, 10, 10), CF(W(mx, 0.5, mz)) * ANG(0, 0, pi / 2), C(235, 245, 255), NEON, {cyl = true, trans = 1, shadow = false})
				end
				local motes = emit(line, {
					Rate = 0, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(1, 3), EmissionDirection = Enum.NormalId.Top,
					SpreadAngle = Vector2.new(25, 25), Size = NumberSequence.new(0.4), LightEmission = 1, Color = ColorSequence.new(C(235, 245, 255)),
					Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1)}),
					Acceleration = V3(0, 1.5, 0), Texture = SPARK,
				})
				onUpdate(function(t, dt, lp)
					local d = dist(lp, mx, mz)
					local near = clamp01((95 - d) / 55)
					line.Transparency = clamp01(1 - near * (0.75 + 0.25 * sin(t * 3)))
					lt.Brightness = near * 2.4
					motes.Rate = near * 40
					for i, rg in ipairs(rings) do
						local ph = (t * 0.35 + i / 3) % 1
						local dd = 10 + ph * 80
						rg.Size = V3(0.25, dd, dd)
						rg.Transparency = clamp01(1 - near * (1 - ph) * 0.7)
					end
				end)
			end)

			section("cristais", function()
				local clusters = {}
				local function cluster(x, z, c1, c2)
					local base = W(x, 0, z)
					local cores, bigLt = {}, nil
					local n = r:NextInteger(9, 13)
					for i = 1, n do
						local big = (i == 1)
						local h = big and rnd(18, 26) or rnd(5, 14)
						local w = big and rnd(3.2, 4.4) or rnd(1.2, 2.6)
						local a = rnd(0, TAU)
						local dd = big and 0 or rnd(2, 8)
						local tilt = big and rnd(-0.12, 0.12) or rnd(0.15, 0.55)
						local cf = CF(base + V3(cos(a) * dd, 0, sin(a) * dd)) * ANG(0, a, 0) * ANG(0, 0, tilt) * CF(0, h / 2 - 0.5, 0)
						mk(model, V3(w, h, w), cf, c1, GLASS, {trans = 0.3, refl = 0.15, shadow = false})
						if big then mk(model, V3(w, h, w), cf * ANG(0, pi / 4, 0), c1, GLASS, {trans = 0.3, refl = 0.15, shadow = false}) end
						local core = mk(model, V3(w * 0.45, h * 0.92, w * 0.45), cf, c2, NEON, {trans = 0.15, shadow = false})
						cores[#cores + 1] = {core, rnd(0, TAU)}
						if big then bigLt = light(core, c2, 1, 50) end
					end
					clusters[#clusters + 1] = {x = x, z = z, cores = cores, lt = bigLt}
				end
				cluster(-190, 30, C(150, 230, 255), C(80, 230, 255))
				cluster(90, 320, C(255, 170, 240), C(255, 90, 220))
				cluster(120, -120, C(210, 255, 160), C(170, 255, 90))
				onUpdate(function(t, dt, lp)
					for _, c in ipairs(clusters) do
						local d = dist(lp, c.x, c.z)
						if d < 240 then
							local near = clamp01((75 - d) / 45)
							local sp = 1.2 + 2.4 * near
							for _, co in ipairs(c.cores) do
								co[1].Transparency = clamp01(0.14 + 0.3 * (0.5 + 0.5 * sin(t * sp + co[2])) - 0.12 * near)
							end
							c.lt.Brightness = 0.8 + 2.6 * near + 0.5 * sin(t * sp)
						end
					end
				end)
			end)

			section("flora", function()
				local plants = {}
				local BULB = {C(120, 255, 240), C(255, 120, 230), C(190, 255, 110), C(255, 200, 90)}
				local BODY = {C(58, 172, 150), C(118, 84, 170), C(72, 156, 92)}
				local placed, tries = 0, 0
				while placed < 36 and tries < 500 do
					tries = tries + 1
					local a, d = rnd(0, TAU), rnd(70, 520)
					local x, z = cos(a) * d, sin(a) * d
					if clear(x, z, 8) then
						placed = placed + 1
						reserve(x, z, 8)
						local h = rnd(9, 24)
						local rad = rnd(1.0, 1.6)
						local body = pick(BODY)
						local bcol = pick(BULB)
						local base = W(x, 0, z)
						column(model, h, rad * 2, base + V3(0, h / 2, 0), body, SMOOTH, {})
						local dk = body:Lerp(C(10, 30, 30), 0.35)
						mk(model, V3(rad * 2.4, h * 0.94, 0.3), CF(base + V3(0, h / 2, 0)), dk, SMOOTH, {shadow = false})
						mk(model, V3(0.3, h * 0.94, rad * 2.4), CF(base + V3(0, h / 2, 0)), dk, SMOOTH, {shadow = false})
						local bulbs = {}
						local topB = ball(model, rad * 2.6, base + V3(0, h + 0.8, 0), bcol, NEON, {shadow = false, trans = 0.25})
						bulbs[1] = {topB, rad * 2.6, rnd(0, TAU)}
						local lt, em = nil, nil
						if placed % 4 == 0 then lt = light(topB, bcol, 0.8, 26) end
						if placed % 3 == 0 then
							em = emit(topB, {
								Rate = 3, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(1, 2), EmissionDirection = Enum.NormalId.Top,
								SpreadAngle = Vector2.new(70, 70), Size = NumberSequence.new(0.35), LightEmission = 1, Color = ColorSequence.new(bcol),
								Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1)}),
								Acceleration = V3(0.6, 0.6, 0), Texture = SPARK,
							})
						end
						for _ = 1, r:NextInteger(1, 3) do
							local ay = h * rnd(0.3, 0.62)
							local ang = rnd(0, TAU)
							local out = rnd(3.5, 6)
							local up = rnd(4, 8)
							local p0 = base + V3(0, ay, 0)
							local p1 = p0 + V3(cos(ang) * out, 0.4, sin(ang) * out)
							local p2 = p1 + V3(0, up, 0)
							between(model, p0, p1, rad * 1.1, body, SMOOTH, {})
							ball(model, rad * 1.1, p1, body, SMOOTH, {})
							between(model, p1, p2, rad * 1.1, body, SMOOTH, {})
							local bs = rad * 1.7
							local b = ball(model, bs, p2 + V3(0, 0.6, 0), bcol, NEON, {shadow = false, trans = 0.25})
							bulbs[#bulbs + 1] = {b, bs, rnd(0, TAU)}
						end
						plants[#plants + 1] = {x = x, z = z, bulbs = bulbs, lt = lt, em = em}
					end
				end
				onUpdate(function(t, dt, lp)
					for _, p in ipairs(plants) do
						local d = dist(lp, p.x, p.z)
						if d < 90 then
							local near = clamp01((45 - d) / 30)
							local shy = clamp01((9 - d) / 5)
							for _, b in ipairs(p.bulbs) do
								local s = b[2] * (1 - 0.55 * shy + 0.08 * sin(t * 1.5 + b[3]))
								b[1].Size = V3(s, s, s)
								b[1].Transparency = clamp01(0.3 - 0.28 * near + 0.1 * shy)
							end
							if p.lt then p.lt.Brightness = 0.6 + 2 * near end
							if p.em then p.em.Rate = 3 + 22 * near end
						end
					end
				end)
			end)

			section("oasis", function()
				local ox, oz = -30, 330
				local PR = 72
				column(model, 0.1, PR * 2 + 4, W(ox, 0.05, oz), C(8, 52, 62), MUDM, {shadow = false})
				column(model, 0.25, PR * 2, W(ox, 0.16, oz), C(30, 186, 200), GLASS, {trans = 0.28, refl = 0.3, shadow = false})
				column(model, 0.05, PR * 2, W(ox, 0.1, oz), C(40, 255, 220), NEON, {trans = 0.72, shadow = false})
				column(model, 0.05, PR * 1.1, W(ox, 0.11, oz), C(150, 255, 240), NEON, {trans = 0.78, shadow = false})
				column(model, 0.05, PR * 0.45, W(ox, 0.12, oz), C(220, 255, 250), NEON, {trans = 0.7, shadow = false})

				for k = 0, 6 do
					local a, d = (k - 1) / 6 * TAU, (k == 0) and 0 or PR * 0.6
					local lp0 = mk(model, V3(0.2, 0.2, 0.2), W(ox + cos(a) * d, 3, oz + sin(a) * d), C(255, 255, 255), SMOOTH, {trans = 1, shadow = false})
					light(lp0, C(60, 255, 225), 2.2, 60)
				end
				for i = 1, 56 do
					local a = i / 56 * TAU + rnd(-0.05, 0.05)
					local d = PR + rnd(0.5, 4)
					local s = rnd(2.5, 7)
					mk(model, V3(s * 1.4, s * 0.7, s * 1.2), CF(W(ox + cos(a) * d, s * 0.15, oz + sin(a) * d)) * ANG(rnd(-0.3, 0.3), rnd(0, 6.28), rnd(-0.3, 0.3)),
						tint(pick(STRATA), 0.1), SANDSTONE, {solid = s > 5.5})
				end
				local pads = {}
				for i = 1, 28 do
					local a, d = rnd(0, TAU), rnd(6, PR - 6)
					local x, z = ox + cos(a) * d, oz + sin(a) * d
					local dd = rnd(3, 6)
					local pad = column(model, 0.12, dd, W(x, 0.3, z), C(40, 150, 90), SMOOTH, {shadow = false})
					local fl = ball(model, 1.1, W(x, 0.6, z), pick({C(255, 120, 230), C(255, 220, 120)}), NEON, {shadow = false})
					pads[i] = {pad = pad, fl = fl, x = x, z = z, ph = rnd(0, TAU)}
				end
				local ripples = {}
				for i = 1, 3 do
					ripples[i] = {p = column(model, 0.06, 4, W(ox, 0.34, oz), C(180, 255, 245), NEON, {trans = 1, shadow = false}), x = ox, z = oz}
				end
				local palms = {}
				local function palm(px, pz, face, ht)
					local home = CF(W(px, 0, pz)) * ANG(0, face, 0)
					local g, part = group(home)
					local lean = rnd(5, 11)
					local prev = V3(0, 0, 0)
					for i = 1, 5 do
						local k = i / 5
						local p = V3(lean * k * k, ht * k, 0)
						between(g, home:PointToWorldSpace(prev), home:PointToWorldSpace(p), lerp(2.4, 1.3, k), (i % 2 == 0) and C(120, 84, 108) or C(148, 100, 126), SMOOTH, {})
						prev = p
					end
					local top = prev
					for k = 1, 8 do
						local yaw = k / 8 * TAU
						local tilt = 0.5 + rnd(0, 0.35)
						local fcol = (k % 2 == 0) and C(60, 190, 160) or C(90, 210, 130)
						part(V3(2.2, 0.18, 10), CF(top.X, top.Y, top.Z) * ANG(0, yaw, 0) * ANG(-tilt, 0, 0) * CF(0, 0, -5), fcol, SMOOTH, {shadow = false})
						part(V3(0.9, 0.9, 0.9), CF(top.X, top.Y, top.Z) * ANG(0, yaw, 0) * ANG(-tilt, 0, 0) * CF(0, 0, -10), C(130, 255, 235), NEON, {ball = true, shadow = false})
					end
					for k = 1, 3 do
						local a = k / 3 * TAU
						part(V3(1.6, 1.6, 1.6), CF(top.X + cos(a) * 1.4, top.Y - 1.2, top.Z + sin(a) * 1.4), C(255, 130, 220), NEON, {ball = true, shadow = false})
					end
					palms[#palms + 1] = {g = g, home = home, ph = rnd(0, TAU)}
				end
				for i = 1, 14 do
					local a = i / 14 * TAU + rnd(-0.12, 0.12)
					local d = PR + rnd(5, 14)
					palm(ox + cos(a) * d, oz + sin(a) * d, a + pi + rnd(-0.5, 0.5), rnd(18, 28))
				end
				local jellies = {}

				local JCOLS = { C(120, 255, 240), C(255, 140, 235), C(170, 150, 255), C(255, 220, 130), C(120, 255, 240) }
				local JT, JA, JTS, JAS = 6, 4, 6, 4
				local NJ = 9
				for i = 1, NJ do
					local big = (i == 1)
					local s = big and 0.9 or rnd(0.35, 0.6)
					local col = JCOLS[(i - 1) % #JCOLS + 1]
					local nT, nTS, nA, nAS, nB = JT, JTS, JA, JAS, 10
					if not big then nT, nTS, nA, nAS, nB = 4, 4, 3, 3, 6 end
					local hide = CF(W(0, -60, 0))
					local function nm(size, c, mat, o) return mk(model, size, hide, c, mat, o or {shadow = false}) end
					local R = big and 8 or rnd(14, PR - 12)
					local j = {
						s = s, col = col, ph = rnd(0, TAU), pt = rnd(0, 1), a = rnd(0, TAU),
						R = R, w = rnd(0.12, 0.25) * (18 / math.max(R, 18)) * ((i % 2 == 0) and 1 or -1) * (big and 0.5 or 1),
						y = big and 5 or rnd(3, 7), tent = {}, arms = {}, beads = {}, organs = {}, near = 0,
						nb = nB, tm = JTS / nTS, am = JAS / nAS,
					}
					j.dome = nm(V3(4.2 * s, 2.8 * s, 4.2 * s), col, NEON, {ellipsoid = true, trans = 0.4, shadow = false})
					j.skirt = nm(V3(4.8 * s, 1 * s, 4.8 * s), col, NEON, {ellipsoid = true, trans = 0.5, shadow = false})
					j.core = nm(V3(0.3, 0.3, 0.3), C(255, 255, 255), SMOOTH, {trans = 1, shadow = false})
					if i <= 5 then j.lt = light(j.core, col, 1, 18) end
					j.em = emit(j.core, {
						Rate = 5, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(0, 0.5), Acceleration = V3(0, -1.2, 0),
						Size = NumberSequence.new(0.25), LightEmission = 1, Color = ColorSequence.new(col), Texture = SPARK,
						Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)}),
					})
					for k = 1, 4 do
						j.organs[k] = nm(V3(0.9 * s, 0.5 * s, 1.8 * s), C(255, 255, 255):Lerp(col, 0.3), NEON, {ellipsoid = true, trans = 0.15, shadow = false})
					end
					for k = 1, nB do
						j.beads[k] = nm(V3(0.4 * s, 0.4 * s, 0.4 * s), col, NEON, {ball = true, trans = 0.1, shadow = false})
					end
					for k = 1, nT do
						local segs = {}
						for q = 1, nTS do
							local d = math.max(0.1, (0.22 - q * 0.025) * s)
							segs[q] = nm(V3(1, d, d), col, NEON, {ellipsoid = true, trans = 0.5, shadow = false})
						end
						j.tent[k] = {segs = segs, ang = k / nT * TAU, ph = rnd(0, TAU)}
					end
					for k = 1, nA do
						local segs = {}
						for q = 1, nAS do
							local d = math.max(0.14, (0.55 - q * 0.1) * s)
							segs[q] = nm(V3(1, d, d), col:Lerp(C(255, 255, 255), 0.4), NEON, {ellipsoid = true, trans = 0.35, shadow = false})
						end
						j.arms[k] = {segs = segs, ang = k / nA * TAU + 0.4, ph = rnd(0, TAU)}
					end
					jellies[i] = j
				end

				local function jchain(base, p0, segs, L, t, ph, amp)
					local p = p0
					local prevW = base:PointToWorldSpace(p)
					local up = base.RightVector
					for q, sg in ipairs(segs) do
						local np = p + V3(sin(t * 2.2 + ph - q * 0.8) * amp * L * 0.5, -L, cos(t * 1.9 + ph - q * 0.7) * amp * L * 0.5)
						local b = base:PointToWorldSpace(np)
						local len = (b - prevW).Magnitude
						sg.Size = V3(len * 1.25, sg.Size.Y, sg.Size.Z)
						sg.CFrame = CFrame.lookAt((prevW + b) / 2, b, up) * ANG(0, pi / 2, 0)
						p, prevW = np, b
					end
				end

				local function updJelly(j, t, dt, lp)
					local s = j.s

					local px0, pz0 = ox + cos(j.a) * j.R, oz + sin(j.a) * j.R
					local near = clamp01(1 - dist(lp, px0, pz0) / 24)
					j.near = j.near + (near - j.near) * min(1, dt * 3)
					near = j.near
					j.pt = (j.pt + dt * (0.5 + 0.6 * near)) % 1
					local p = j.pt
					local c = (p < 0.3) and sin(p / 0.3 * pi) or 0
					local rise = (p < 0.3) and (p / 0.3) or (1 - (p - 0.3) / 0.7)
					j.a = j.a + j.w * (0.4 + 1.2 * c) * dt
					local px, pz = ox + cos(j.a) * j.R, oz + sin(j.a) * j.R
					local y = j.y + (rise - 0.5) * 2.6 + sin(t * 0.35 + j.ph) * 0.8
					local base = CF(W(px, y, pz)) * ANG(sin(t * 0.8 + j.ph) * 0.08, 0, sin(t * 0.6 + j.ph) * 0.08)
					local hh, wd, sk = 1 + 0.22 * c, 1 - 0.18 * c, 1 - 0.3 * c

					j.dome.Size = V3(4.2 * s * wd, 2.8 * s * hh, 4.2 * s * wd)
					j.dome.CFrame = base * CF(0, 0.2 * s * hh, 0)
					j.dome.Transparency = 0.4 - 0.2 * near
					j.skirt.Size = V3(4.8 * s * sk, 1 * s, 4.8 * s * sk)
					j.skirt.CFrame = base * CF(0, -1.2 * s * hh, 0)
					j.skirt.Transparency = 0.5 - 0.2 * near
					j.core.CFrame = base * CF(0, 0, 0)
					j.em.Rate = 5 + near * 14
					if j.lt then j.lt.Brightness = 1 + near * 1.8 + c * 0.6 end
					for k, o in ipairs(j.organs) do
						local a = k / 4 * TAU + 0.4
						o.CFrame = base * CF(cos(a) * 0.8 * s * wd, 0.2 * s * hh, sin(a) * 0.8 * s * wd) * ANG(0, pi / 2 - a, 0)
					end
					for k, b in ipairs(j.beads) do
						local a = k / j.nb * TAU
						b.CFrame = base * CF(cos(a) * 2.35 * s * sk, -1.2 * s * hh, sin(a) * 2.35 * s * sk)
						b.Transparency = 0.05 + 0.5 * (0.5 + 0.5 * sin(t * 4 - k * 0.63 + j.ph)) - 0.1 * near
					end
					local amp = 0.9 + 0.8 * c
					for _, tn in ipairs(j.tent) do
						local root = V3(cos(tn.ang) * 2.0 * s * sk, -1.4 * s * hh, sin(tn.ang) * 2.0 * s * sk)
						jchain(base, root, tn.segs, 0.9 * s * j.tm, t, tn.ph, amp)
						for _, sg in ipairs(tn.segs) do sg.Transparency = 0.5 - 0.2 * near end
					end
					for _, ar in ipairs(j.arms) do
						local root = V3(cos(ar.ang) * 0.7 * s, -0.9 * s * hh, sin(ar.ang) * 0.7 * s)
						jchain(base, root, ar.segs, 1.0 * s * j.am, t, ar.ph, 1.2 + c)
					end
				end
				emitterBox(model, V3(PR * 2.2, 20, PR * 2.2), W(ox, 9, oz), {
					Rate = 60, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(0.5, 2), EmissionDirection = Enum.NormalId.Top,
					SpreadAngle = Vector2.new(60, 60), Size = NumberSequence.new(0.5), LightEmission = 1, Color = ColorSequence.new(C(120, 255, 230)),
					Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1)}),
					Acceleration = V3(0, 0.4, 0), Texture = SPARK,
				})
				onUpdate(function(t, dt, lp)
					if dist(lp, ox, oz) > 380 then return end
					for _, p in ipairs(pads) do
						local y = 0.3 + 0.06 * sin(t * 1.4 + p.ph)
						p.pad.Position = W(p.x, y, p.z)
						p.fl.Position = W(p.x, y + 0.35, p.z)
					end
					for i, rp2 in ipairs(ripples) do
						local ph = (t * 0.25 + i / 3) % 1
						if ph < 0.02 then
							local a, d = rnd(0, TAU), rnd(0, PR - 14)
							rp2.x, rp2.z = ox + cos(a) * d, oz + sin(a) * d
						end
						local dd = 2 + ph * 44
						rp2.p.Size = V3(0.06, dd, dd)
						rp2.p.Position = W(rp2.x, 0.34, rp2.z)
						rp2.p.Transparency = clamp01(0.35 + ph * 0.65)
					end
					for _, pm in ipairs(palms) do
						pm.g:PivotTo(pm.home * ANG(sin(t * 0.9 + pm.ph) * 0.018, 0, sin(t * 0.7 + pm.ph) * 0.02))
					end
					for _, j in ipairs(jellies) do updJelly(j, t, dt, lp) end
				end)
			end)

			section("esqueleto", function()
				local home = CF(W(-150, 0, -40)) * ANG(0, 0.5, 0)
				local g, part = group(home)
				local function wp(x, y, z) return home:PointToWorldSpace(V3(x, y, z)) end
				local function spineY(x) return 5 + 13 * sin(pi * (x + 32) / 64) end
				for i = 0, 24 do
					local x = -32 + i * (64 / 24)
					part(V3(3.2, 3.2, 3.2), CF(x, spineY(x) + 0.4, 0), BONE, LIMESTONE, {ball = true})
				end
				for j = 1, 9 do
					local x = -28 + (j - 1) * 6.4
					local ys = spineY(x)
					local Rr = 5 + 0.5 * ys
					local prev = nil
					for k = 0, 8 do
						local ph = pi * k / 8
						local p = wp(x, ys * sin(ph), Rr * cos(ph))
						if prev then between(g, prev, p, 1.5 - 0.6 * (k / 8), BONE, LIMESTONE, {}) end
						prev = p
					end
				end
				for i = 1, 9 do
					local x = -34 - i * 2.6
					local s = 2.6 * (1 - i / 11)
					part(V3(s, s, s), CF(x, 3.4 - i * 0.28, 0), BONE, LIMESTONE, {ball = true})
				end
				part(V3(18, 12, 13), CF(43, 5, 0) * ANG(0, 0, -0.22), BONE, LIMESTONE, {ellipsoid = true})
				part(V3(15, 4.5, 10), CF(45, 1.6, 0), BONE, LIMESTONE, {ellipsoid = true})
				for _, sd in ipairs({-1, 1}) do
					part(V3(3.4, 3.4, 3.4), CF(46.4, 6.6, sd * 3.8), C(26, 20, 18), SMOOTH, {ball = true})
					between(g, wp(41, 9, sd * 4), wp(37, 17, sd * 9), 1.8, BONE, LIMESTONE, {})
					between(g, wp(37, 17, sd * 9), wp(35, 23, sd * 13), 1.1, BONE, LIMESTONE, {})
				end
				for k = 0, 7 do
					part(V3(0.8, 2.2, 0.8), CF(52, 3.2, -4.2 + k * 1.2), BONE, LIMESTONE, {})
				end
			end)

			section("verme", function()
				local WC = V3(0, 0, 150)
				local WR, WN, WSP = 380, 30, 7.4
				local AMP, LAM, SPEED = 34, 330, 30
				local segs = {}
				for i = 1, WN do
					local k = (i - 1) / (WN - 1)
					local rad = 9.2 * (1 - 0.7 * k ^ 2.2)
					if i == 1 then rad = 11 end
					local col = (i % 2 == 0) and C(196, 142, 98) or C(170, 112, 78)
					local body = mk(model, V3(WSP + 2.4, rad * 2, rad * 2), CF(W(0, -80, 0)), col, SANDSTONE, {cyl = true})
					local ridge = mk(model, V3(1.2, rad * 2 + 2.6, rad * 2 + 2.6), CF(W(0, -80, 0)), C(112, 70, 52), BASALT, {cyl = true})
					local sp, em, hh = nil, nil, rad * 0.9
					if i > 2 then
						sp = mk(model, V3(1.8, hh, 1.8), CF(W(0, -80, 0)), C(96, 58, 44), BASALT, {ellipsoid = true, shadow = false})
						em = mk(model, V3(1.2, 1.2, 1.2), CF(W(0, -80, 0)), C(255, 150, 60), NEON, {ball = true, shadow = false})
					end
					segs[i] = {body = body, ridge = ridge, rad = rad, spike = sp, ember = em, h = hh}
				end
				local mouth = mk(model, V3(0.6, 20, 20), CF(W(0, -80, 0)), C(70, 10, 22), SMOOTH, {cyl = true, shadow = false})
				local mouthLight = light(mouth, C(255, 90, 60), 0, 45)
				local teeth = {}
				for k = 1, 14 do
					teeth[k] = {mk(model, V3(5.5, 1.5, 1.5), CF(W(0, -80, 0)), C(240, 230, 205), LIMESTONE, {}), k / 14 * TAU, 8.8}
				end
				for k = 1, 8 do
					teeth[#teeth + 1] = {mk(model, V3(4, 1.1, 1.1), CF(W(0, -80, 0)), C(240, 230, 205), LIMESTONE, {}), k / 8 * TAU + 0.2, 5}
				end
				local dustP = mk(model, V3(0.2, 0.2, 0.2), W(0, -80, 0), C(255, 255, 255), SMOOTH, {trans = 1, shadow = false})
				local dustEm = emit(dustP, {
					Rate = 0, Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(20, 45), SpreadAngle = Vector2.new(45, 45),
					EmissionDirection = Enum.NormalId.Top, Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 16)}),
					Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1)}),
					Color = ColorSequence.new(C(232, 190, 130)), Texture = SMOKE, Acceleration = V3(0, -8, 0), RotSpeed = NumberRange.new(-40, 40),
				})
				local trailEm = emit(segs[1].body, {
					Rate = 0, Lifetime = NumberRange.new(2, 3.5), Speed = NumberRange.new(4, 10), SpreadAngle = Vector2.new(180, 180),
					Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 12)}),
					Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1)}),
					Color = ColorSequence.new(C(232, 190, 130)), Texture = SMOKE,
				})
				local rockEm = emit(dustP, {
					Rate = 0, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(30, 70), SpreadAngle = Vector2.new(40, 40),
					EmissionDirection = Enum.NormalId.Top, Size = NumberSequence.new(1.2), Transparency = NumberSequence.new(0),
					Color = ColorSequence.new(C(120, 84, 60)), Acceleration = V3(0, -90, 0), RotSpeed = NumberRange.new(-300, 300),
				})
				local rings, ringI = {}, 0
				for k = 1, 3 do
					rings[k] = {p = mk(model, V3(0.6, 6, 6), CF(W(0, -80, 0)), C(232, 190, 130), M.Sand, {cyl = true, shadow = false, trans = 1}), t0 = -99, pos = V3(0, -80, 0)}
				end
				local function spawnRing(t, pos)
					ringI = ringI % 3 + 1
					rings[ringI].t0, rings[ringI].pos = t, pos
				end
				local function updRings(t)
					for _, r in ipairs(rings) do
						local age = t - r.t0
						if age >= 0 and age < 1.6 then
							local d = 6 + age * 80
							r.p.Size = V3(0.6, d, d)
							r.p.Transparency = 0.4 + 0.6 * (age / 1.6)
							r.p.CFrame = CF(r.pos) * ANG(0, 0, pi / 2)
						elseif r.p.Transparency < 1 then
							r.p.Transparency = 1
						end
					end
				end
				local function pathPos(s)
					local a = s / WR
					local rr = WR + 12 * sin(s * TAU / 540)
					local amp = AMP * (1 + 0.55 * max(0, sin(s * TAU / 1400)) ^ 2)
					return WC + V3(cos(a) * rr, amp * sin(s * TAU / LAM) - 4, sin(a) * rr)
				end
				local prevY = nil
				local chomp = 0
				onUpdate(function(t, dt, lp)
					chomp = max(0, chomp - dt * 2.5)
					local sh = t * SPEED
					local pts = {}
					for i = 1, WN + 1 do pts[i] = pathPos(sh - (i - 1) * WSP) end
					local hd = pts[1] - pts[2]
					local rise = clamp01(hd.Y / (WSP * 0.45))
					local lift = clamp01((pts[1].Y + 10) / 25)
					local openF = 0.85 + 0.1 * sin(t * 3) + 0.3 * rise * lift - 0.5 * chomp
					for i = 1, WN do
						local p = pts[i]
						local fwd = (i == 1) and (pts[1] - pts[2]) or (pts[i - 1] - pts[i + 1])
						local cf = CFrame.lookAt(O + p, O + p + fwd) * ANG(0, pi / 2, 0)
						segs[i].body.CFrame = cf
						local sg = segs[i]
						local br = 1 + 0.045 * sin(t * 2.2 - i * 0.5)
						sg.body.Size = V3(WSP + 2.4, sg.rad * 2 * br, sg.rad * 2 * br)
						if sg.spike then
							sg.spike.CFrame = cf * CF(0, sg.rad + sg.h * 0.3, 0)
							sg.ember.CFrame = cf * CF(0, sg.rad + sg.h * 0.85, 0)
							sg.ember.Transparency = 0.15 + 0.6 * (0.5 + 0.5 * sin(t * 3 - i * 0.6))
						end
						segs[i].ridge.CFrame = cf * CF(WSP * 0.3, 0, 0)
						if i == 1 then
							mouth.CFrame = cf * CF(WSP / 2 + 1.8, 0, 0)
							mouth.Size = V3(0.6, 20 * openF, 20 * openF)
							mouth.Color = C(70, 10, 22):Lerp(C(200, 60, 40), clamp01(0.25 + rise * lift))
							mouthLight.Brightness = 0.4 + 1.8 * rise * lift
							for ti, tt in ipairs(teeth) do
								local ang = tt[2] + ((ti > 14) and (t * 0.9) or 0)
								tt[1].CFrame = cf * CF(WSP / 2 + 3.5, cos(ang) * tt[3] * openF, sin(ang) * tt[3] * openF)
							end
						end
					end
					local yh = pts[1].Y
					if prevY and ((prevY < 0 and yh >= 0) or (prevY > 0 and yh <= 0)) then
						dustP.Position = O + V3(pts[1].X, 1, pts[1].Z)
						dustEm:Emit(70)
						rockEm:Emit(30)
						spawnRing(t, O + V3(pts[1].X, 0.4, pts[1].Z))
					end
					prevY = yh
					trailEm.Rate = (yh > -6) and 18 or 0
					updRings(t)
				end)

				local featherEm = emit(dustP, {
					Rate = 0, Lifetime = NumberRange.new(1.5, 2.8), Speed = NumberRange.new(12, 30), SpreadAngle = Vector2.new(180, 180),
					Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0.6)}),
					Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
					Color = ColorSequence.new(C(120, 82, 64)), Texture = SMOKE, Acceleration = V3(0, -6, 0), RotSpeed = NumberRange.new(-200, 200),
				})
				local VBODY, VHEAD, VWING, VWING2 = C(74, 52, 44), C(214, 150, 130), C(104, 70, 56), C(138, 92, 70)
				local PREY_N = 6
				local prey = {}
				for i = 1, PREY_N do
					local sc = rnd(1.3, 1.8)
					local g, part = group(CF(W(0, -400, 0)))
					local function P(size, x, y, z, col, mat, o, rot)
						local rel = CF(x * sc, y * sc, z * sc)
						if rot then rel = rel * rot end
						return part(size * sc, rel, col, mat or SMOOTH, o or {shadow = false})
					end
					P(V3(1.2, 1.1, 4), 0, 0, 0, VBODY, SMOOTH, {ellipsoid = true, shadow = false})
					P(V3(0.5, 0.5, 1.6), 0, 0.2, -2.1, VHEAD, SMOOTH, {ellipsoid = true, shadow = false})
					P(V3(0.8, 0.8, 1.1), 0, 0.5, -3, VHEAD, SMOOTH, {ellipsoid = true, shadow = false})
					P(V3(0.25, 0.25, 1.2), 0, 0.4, -3.8, BONE, SMOOTH, {shadow = false})
					P(V3(1.6, 0.1, 2), 0, -0.1, 2.9, VWING, SMOOTH, {shadow = false}, ANG(0, 0.785, 0))
					local wings = {}
					for k, sd in ipairs({-1, 1}) do
						local stash = CF(W(0, -400, 0))
						wings[k] = {
							sd = sd,
							inn = mk(model, V3(3.4 * sc, 0.12 * sc, 2.8 * sc), stash, VWING, SMOOTH, {shadow = false}),
							out = mk(model, V3(3.6 * sc, 0.1 * sc, 2.2 * sc), stash, VWING2, SMOOTH, {shadow = false}),
						}
					end
					prey[i] = {g = g, wings = wings, sc = sc, a0 = 0.5 + (i - 1) * 1.0, a = nil, off = rnd(-35, 35), ph = rnd(0, TAU), panic = 0, state = "fly", resp = 0, ct = 0}
				end

				local function placePrey(p, cf, a1, a2)
					local sc = p.sc
					p.g:PivotTo(cf)
					for _, w in ipairs(p.wings) do
						local sd = w.sd
						local sh = cf * CF(sd * 0.5 * sc, 0.2 * sc, -0.4 * sc) * ANG(0, 0, sd * a1)
						w.inn.CFrame = sh * CF(sd * 1.7 * sc, 0, 0.6 * sc)
						local el = sh * CF(sd * 3.4 * sc, 0, 0) * ANG(0, -sd * 0.25, sd * a2)
						w.out.CFrame = el * CF(sd * 1.8 * sc, 0, 0.5 * sc)
					end
				end

				local function hidePrey(p)
					local stash = CF(W(0, -400, 0))
					p.g:PivotTo(stash)
					for _, w in ipairs(p.wings) do
						w.inn.CFrame = stash
						w.out.CFrame = stash
					end
				end

				local function updatePrey(t, dt)
					local s = t * SPEED
					local aw = s / WR
					local H = pathPos(s)
					local hf = (H - pathPos(s - 4)).Unit
					for _, p in ipairs(prey) do
						if not p.a then p.a = aw + p.a0 end
						if p.state == "gone" and t >= p.resp then
							p.state = "fly"
							p.a = aw + rnd(1.6, 3.0)
							p.panic = 0
						end
						if p.state == "fly" then

							local gap = ((p.a - aw) * WR) % (TAU * WR)
							local target = (gap < 150) and 1 or 0
							p.panic = p.panic + (target - p.panic) * math.min(1, dt * 2)
							p.a = p.a + (18 + 10 * p.panic) / WR * dt
							local r = WR + p.off + 8 * sin(t * 0.6 + p.ph) + 14 * p.panic * sin(t * 3 + p.ph)
							local y = 24 + 7 * sin(t * 0.9 + p.ph) + 8 * p.panic
							local pos = WC + V3(cos(p.a) * r, y, sin(p.a) * r)
							local dir = V3(-sin(p.a), 0, cos(p.a))
							local cf = CFrame.lookAt(O + pos, O + pos + dir) * ANG(0.05, 0, -0.3)
							local amp = 0.35 + 0.5 * p.panic
							local fq = 5 + 4 * p.panic
							placePrey(p, cf, 0.15 + amp * sin(t * fq + p.ph), 0.1 + amp * 1.3 * sin(t * fq + p.ph - 0.8))
							if H.Y > 4 and (pos - H).Magnitude < 26 then
								p.state = "caught"
								p.ct = t
								chomp = 1
								dustP.Position = O + H
								featherEm:Emit(26)
								dustEm:Emit(14)
							end
						elseif p.state == "caught" then
							local M = H + hf * (WSP / 2 + 3)
							local cf = CFrame.lookAt(O + M, O + M + hf) * ANG(t * 12, 0, t * 9)
							placePrey(p, cf, 0.9, 1.2)
							if t - p.ct > 0.3 then
								hidePrey(p)
								p.state = "gone"
								p.resp = t + rnd(28, 50)
								featherEm:Emit(12)
							end
						end
					end
				end
				onUpdate(function(t, dt, lp) updatePrey(t, dt) end)
			end)

			section("vento", function()
				local devils = {}
				local defs = {}

				local NL = 24
				for i, df in ipairs(defs) do
					local sc = df[8]
					local step = 3.4 * sc
					local layers = {}
					for k = 1, NL do
						local f = k / NL
						local d = (5 + f ^ 1.6 * 54) * sc
						local lm = Instance.new("Model")
						local hide = CF(W(0, -60, 0))
						local anchor = mk(lm, V3(0.2, 0.2, 0.2), hide, C(0, 0, 0), SMOOTH, {trans = 1, shadow = false})
						lm.PrimaryPart = anchor
						local col = ((k % 2 == 0) and C(228, 186, 130) or C(204, 160, 110)):Lerp(C(120, 92, 70), f * 0.4)
						mk(lm, V3(step * 1.1, d, d), hide * ANG(0, 0, pi / 2), col, M.Sand, {cyl = true, trans = 0.46 + 0.34 * f, shadow = false})
						for c = 1, 2 do
							local ang = c / 2 * TAU + k * 0.9
							mk(lm, V3(d * 0.18, step * 0.8, d * 0.36), hide * CF(cos(ang) * d * 0.5, 0, sin(ang) * d * 0.5) * ANG(0, -ang, 0),
								col:Lerp(C(245, 214, 160), 0.35), M.Sand, {ellipsoid = true, trans = 0.3 + 0.35 * f, shadow = false})
						end
						lm.Parent = model
						layers[k] = {m = lm, y = k * step, f = f}
					end
					local H = NL * step
					local cloud = mk(model, V3(96 * sc, 16 * sc, 96 * sc), W(0, -60, 0), C(138, 102, 78), M.Sand, {ellipsoid = true, trans = 0.42, shadow = false})
					local cloud2 = mk(model, V3(64 * sc, 22 * sc, 64 * sc), W(0, -60, 0), C(104, 80, 64), M.Sand, {ellipsoid = true, trans = 0.3, shadow = false})
					local flash = light(cloud2, C(255, 224, 170), 0, 60)
					emit(cloud, {
						Rate = 22, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(3, 8), EmissionDirection = Enum.NormalId.Bottom,
						SpreadAngle = Vector2.new(60, 60), Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 4 * sc), NumberSequenceKeypoint.new(1, 10 * sc)}),
						Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1)}),
						Color = ColorSequence.new(C(150, 116, 88)), Texture = SMOKE, RotSpeed = NumberRange.new(-60, 60),
					})
					local ring = mk(model, V3(0.1, 30 * sc, 30 * sc), W(0, -60, 0), C(210, 168, 116), M.Sand, {cyl = true, trans = 0.6, shadow = false})
					local ep = mk(model, V3(0.2, 0.2, 0.2), W(df[1], 3, df[2]), C(255, 255, 255), SMOOTH, {trans = 1, shadow = false})
					emit(ep, {
						Rate = 70, Lifetime = NumberRange.new(2, 3.2), Speed = NumberRange.new(10, 22), SpreadAngle = Vector2.new(85, 85),
						Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 5 * sc), NumberSequenceKeypoint.new(1, 16 * sc)}),
						Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1)}),
						Color = ColorSequence.new(C(228, 186, 130)), Texture = SMOKE, Acceleration = V3(0, 6, 0), RotSpeed = NumberRange.new(-90, 90),
					})
					local debris = {}
					for q = 1, 10 do
						local sz = rnd(0.9, 2.2)
						local kind = q % 3
						local dp
						if kind == 0 then
							dp = mk(model, V3(sz * 2.4, sz * 0.3, sz * 0.7), W(0, -60, 0), C(126, 90, 56), WOOD, {shadow = false})
						elseif kind == 1 then
							dp = mk(model, V3(sz * 1.5, sz * 1.1, sz * 1.3), W(0, -60, 0), tint(pick(STRATA), 0.1), SANDSTONE, {shadow = false})
						else
							dp = mk(model, V3(sz, sz, sz), W(0, -60, 0), C(120, 84, 50), WOOD, {ball = true, shadow = false})
						end
						debris[q] = {p = dp, ph = rnd(0, 1), sp = rnd(0.12, 0.26), om = rnd(1.4, 2.6), rot = V3(rnd(-4, 4), rnd(-4, 4), rnd(-4, 4)), off = rnd(0.75, 1.05)}
					end
					devils[i] = {
						layers = layers, ep = ep, cloud = cloud, cloud2 = cloud2, ring = ring, flash = flash, debris = debris,
						cx = df[1], cz = df[2], ax = df[3], az = df[4], sx = df[5], sz = df[6], spin = df[7], sc = sc, H = H,
						rad = 44 * sc, fl = 0, ph = rnd(0, TAU),
					}
				end

				local weeds = {}

				local TWC = { C(142, 100, 58), C(168, 124, 72), C(120, 84, 48), C(184, 142, 84), C(96, 66, 40) }
				for i = 1, 9 do
					local s = rnd(0.85, 1.5)
					local home = CF(W(0, -60, 0))
					local g, part = group(home)
					part(V3(1.9 * s, 1.9 * s, 1.9 * s), CF(0, 0, 0), C(88, 60, 38), WOOD, {ball = true})
					local function twig(rmin, rmax, d, col)
						local v = V3(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1))
						if v.Magnitude < 0.2 then v = V3(1, 0.3, 0.2) end
						v = v.Unit
						local a, b = v * rmin * s, v * rmax * s
						between(g, home:PointToWorldSpace(a), home:PointToWorldSpace(b), d * s, col, WOOD, {shadow = false})
						return v, b
					end
					for _ = 1, 14 do twig(0.7, rnd(1.5, 1.9), 0.2, pick(TWC)) end
					for k = 1, 18 do
						local v, b = twig(1.2, rnd(2.4, 3.2), 0.13, pick(TWC))
						if k % 3 == 0 then
							part(V3(0.35 * s, 0.35 * s, 0.35 * s), CF(b), C(70, 48, 30), WOOD, {ball = true, shadow = false})
						end
					end
					for _ = 1, 2 do
						local v = V3(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1))
						if v.Magnitude < 0.2 then v = V3(0, 1, 0) end
						part(V3(0.6 * s, 0.6 * s, 0.6 * s), CF(v.Unit * rnd(1.6, 2.4) * s), C(232, 190, 90), SMOOTH, {ball = true, shadow = false})
					end
					local dustP2 = mk(model, V3(0.2, 0.2, 0.2), W(0, -60, 0), C(255, 255, 255), SMOOTH, {trans = 1, shadow = false})
					local dem = emit(dustP2, {
						Rate = 0, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(60, 60),
						Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2 * s), NumberSequenceKeypoint.new(1, 3.5 * s)}),
						Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1)}),
						Color = ColorSequence.new(C(236, 196, 140)), Texture = SMOKE, Acceleration = V3(0, 1, 0),
					})
					local a, d = rnd(0, TAU), rnd(100, 420)
					weeds[i] = {g = g, s = s, dust = dustP2, em = dem, x = cos(a) * d, z = sin(a) * d, vx = 8, vz = 4, h = 0, vy = 0, roll = rnd(0, TAU), ph = rnd(0, TAU)}
				end

				local wind = emitterBox(model, V3(180, 40, 180), W(0, 15, 0), {
					Rate = 70, Lifetime = NumberRange.new(5, 7), Speed = NumberRange.new(10, 18), EmissionDirection = Enum.NormalId.Right,
					SpreadAngle = Vector2.new(15, 15), Size = NumberSequence.new(0.5), Transparency = NumberSequence.new(0.55),
					Color = ColorSequence.new(C(240, 200, 140)),
				})
				onUpdate(function(t, dt, lp)
					wind.CFrame = CF(O.X + lp.X, O.Y + 15, O.Z + lp.Z) * ANG(0, -WIND, 0)
					for _, dv in ipairs(devils) do
						local sc = dv.sc
						local cph, sph = t * dv.sx + dv.ph, t * dv.sz + dv.ph
						local x = dv.cx + dv.ax * sin(cph)
						local z = dv.cz + dv.az * cos(sph)
						local vx = dv.ax * dv.sx * cos(cph)
						local vz = -dv.az * dv.sz * sin(sph)
						dv.x, dv.z = x, z
						if dist(lp, x, z) < 700 then
							local gy = groundAt(x, z)
							for k, L in ipairs(dv.layers) do
								local f = L.f
								local amp = (0.5 + 5 * f) * sc
								local lx = x + sin(t * 1.3 + k * 0.45 + dv.ph) * amp + vx * f * f * 2.5
								local lz = z + cos(t * 1.1 + k * 0.4 + dv.ph) * amp + vz * f * f * 2.5
								L.m:PivotTo(CF(W(lx, gy + L.y, lz)) * ANG(0, t * dv.spin * (1.5 - f) + k * 0.6, 0))
							end
							local tx2 = x + vx * 2.5 + sin(t * 1.3 + NL * 0.45 + dv.ph) * 5.5 * sc
							local tz2 = z + vz * 2.5 + cos(t * 1.1 + NL * 0.4 + dv.ph) * 5.5 * sc
							dv.cloud.CFrame = CF(W(tx2, gy + dv.H + 3 * sc, tz2)) * ANG(0, t * 0.3, 0)
							dv.cloud2.CFrame = CF(W(tx2, gy + dv.H + 8 * sc, tz2)) * ANG(0, -t * 0.4, 0)
							if rnd(0, 1) < dt * 0.7 then dv.fl = 1 end
							dv.fl = max(0, dv.fl - dt * 4.5)
							dv.flash.Brightness = dv.fl * 7
							dv.ring.CFrame = CF(W(x, gy + 0.3, z)) * ANG(0, 0, pi / 2)
							dv.ep.Position = W(x, gy + 3, z)
							for _, db in ipairs(dv.debris) do
								local f = (t * db.sp + db.ph) % 1
								local rr = ((5 + f ^ 1.6 * 54) * sc * 0.5 + 2) * db.off
								local ang = t * db.om * (1.6 - f) + db.ph * TAU
								local pos = W(x + vx * f * f * 2.5 + cos(ang) * rr, gy + f * dv.H * 0.95 + 1, z + vz * f * f * 2.5 + sin(ang) * rr)
								db.p.CFrame = CF(pos) * ANG(t * db.rot.X, t * db.rot.Y, t * db.rot.Z)
							end
						end
					end
					for _, w in ipairs(weeds) do
						local gust = 0.5 + 0.5 * sin(t * 0.4 + w.ph)
						local tx, tz = cos(WIND) * (9 + 7 * gust), sin(WIND) * (9 + 7 * gust)
						w.vx = w.vx + (tx - w.vx) * min(1, dt * 0.8)
						w.vz = w.vz + (tz - w.vz) * min(1, dt * 0.8)
						local dx, dz = w.x - lp.X, w.z - lp.Z
						local dd = sqrt(dx * dx + dz * dz)
						if dd < 16 and dd > 0.1 then
							local push = (16 - dd) * dt * 14
							w.vx = w.vx + dx / dd * push
							w.vz = w.vz + dz / dd * push
							if w.h <= 0.01 then w.vy = 9 end
						end

						local inDev = 0
						for _, dv in ipairs(devils) do
							if dv.x then
								local ex, ez = w.x - dv.x, w.z - dv.z
								local ed = sqrt(ex * ex + ez * ez)
								if ed < dv.rad and ed > 0.1 then
									local k = 1 - ed / dv.rad
									inDev = max(inDev, k)
									w.vx = w.vx + (-ex / ed * 18 * k - ez / ed * 26 * k) * dt
									w.vz = w.vz + (-ez / ed * 18 * k + ex / ed * 26 * k) * dt
								end
							end
						end
						local sp0 = sqrt(w.vx * w.vx + w.vz * w.vz)
						if sp0 > 40 then
							w.vx, w.vz = w.vx / sp0 * 40, w.vz / sp0 * 40
						end
						w.x = w.x + w.vx * dt
						w.z = w.z + w.vz * dt
						if w.x > 560 then w.x = -560 end
						if w.x < -560 then w.x = 560 end
						if w.z > 560 then w.z = -560 end
						if w.z < -560 then w.z = 560 end
						if inDev > 0.05 then
							local target = 34 * inDev + 3 * sin(t * 3 + w.ph)
							w.h = w.h + (target - w.h) * min(1, dt * 1.5)
							w.vy = 0
						else
							if w.h <= 0.01 and rnd(0, 1) < dt * 0.25 then w.vy = 7 end
							w.h = w.h + w.vy * dt
							w.vy = w.vy - 30 * dt
							if w.h < 0 then
								if w.vy < -9 then w.em:Emit(10) end
								w.h = 0
								w.vy = 0
							end
						end
						local gy = groundAt(w.x, w.z)
						local spd = sqrt(w.vx * w.vx + w.vz * w.vz)
						w.roll = w.roll + spd / (2.8 * w.s) * dt + inDev * 6 * dt
						local pos = W(w.x, gy + 2.8 * w.s + w.h, w.z)
						if spd > 0.1 then
							w.g:PivotTo(CFrame.lookAt(pos, pos + V3(w.vx, 0, w.vz)) * ANG(w.roll, 0, 0))
						else
							w.g:PivotTo(CF(pos))
						end
						w.dust.Position = W(w.x, gy + 0.4, w.z)
						w.em.Rate = (w.h < 0.4 and spd > 3) and spd * 1.1 or 0
					end
				end)
			end)

			section("pegadas", function()
				local pool, idx = {}, 0
				for i = 1, 36 do
					pool[i] = {p = mk(model, V3(0.9, 0.06, 1.6), W(0, -100, 0), C(168, 112, 66), M.Sand, {shadow = false, trans = 1}), born = -100}
				end
				local kickP = mk(model, V3(0.2, 0.2, 0.2), W(0, -100, 0), C(255, 255, 255), SMOOTH, {trans = 1, shadow = false})
				local kick = emit(kickP, {
					Rate = 0, Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(60, 60),
					EmissionDirection = Enum.NormalId.Top, Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3)}),
					Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1)}),
					Color = ColorSequence.new(C(236, 196, 140)), Texture = SMOKE,
				})
				local fparams = RaycastParams.new()
				fparams.FilterType = Enum.RaycastFilterType.Include
				fparams.FilterDescendantsInstances = {model}
				local last, side = nil, 1
				onUpdate(function(t, dt, lp)
					local wpos = O + lp
					if last then
						local mv = V3(wpos.X - last.X, 0, wpos.Z - last.Z)
						if mv.Magnitude > 3.6 and mv.Magnitude < 40 then
							local res = workspace:Raycast(wpos, V3(0, -9, 0), fparams)
							if res and res.Instance and res.Instance.Material == M.Sand then
								local up = res.Normal
								local dir = mv.Unit
								local right = dir:Cross(up)
								if right.Magnitude > 0.1 then
									right = right.Unit
									local back = right:Cross(up)
									side = -side
									local pos = res.Position + up * 0.05 + right * (0.9 * side)
									idx = idx % #pool + 1
									local fp = pool[idx]
									fp.p.CFrame = CFrame.fromMatrix(pos, right, up, back)
									fp.born = t
									kickP.Position = pos
									kick:Emit(3)
									last = wpos
								end
							end
						elseif mv.Magnitude >= 40 then
							last = wpos
						end
					else
						last = wpos
					end
					for _, f in ipairs(pool) do
						local age = t - f.born
						f.p.Transparency = (age > 14) and 1 or clamp01(0.15 + 0.85 * (age / 14) ^ 2)
					end
				end)
			end)

			return function(t, pos)
				local dt = lastT and min(t - lastT, 0.1) or 0.016
				lastT = t
				local lp = pos - O
				for i, f in ipairs(ups) do
					if f then
						local ok, e = pcall(f, t, dt, lp)
						if not ok then
							ups[i] = false
							warnRG("deserto/animacao:", e)
						end
					end
				end
			end
		end

		local function buildIce(model, O, r)
			local cos, sin, abs, floor, pi, sqrt, max, min = math.cos, math.sin, math.abs, math.floor, math.pi, math.sqrt, math.max, math.min
			local V3, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
			local function rnd(a, b) return r:NextNumber(a, b) end
			local function pick(t) return t[r:NextInteger(1, #t)] end
			local function W(x, y, z) return O + V3(x, y, z) end
			local function clamp01(v) return max(0, min(1, v)) end
			local function matOr(name, fb)
				local ok, v = pcall(function() return Enum.Material[name] end)
				if ok and v then return v end
				return fb
			end
			local ICE, GLACIER, SNOW = matOr("Ice", M.SmoothPlastic), matOr("Glacier", M.Ice), matOr("Snow", M.Sand)
			local NEON, GLASS, SMOOTH, METAL, SLATE = M.Neon, M.Glass, M.SmoothPlastic, M.Metal, M.Slate
			local WOOD = matOr("Wood", SMOOTH)
			local ROCK = matOr("Basalt", SLATE)
			local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
			local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

			local CYAN, AQUA, WHITE = C(90, 210, 255), C(150, 235, 255), C(245, 252, 255)
			local ICEBLUE = { C(150, 210, 255), C(170, 225, 255), C(130, 195, 245), C(190, 235, 255), C(120, 180, 240) }

			local function new(class, props, parent)
				local i = Instance.new(class)
				for k, v in pairs(props) do pcall(function() i[k] = v end) end
				if parent then i.Parent = parent end
				return i
			end
			local function emit(parent, props) return new("ParticleEmitter", props, parent) end
			local function light(parent, col, br, range)
				return new("PointLight", {Color = col, Brightness = br, Range = range, Shadows = false}, parent)
			end
			local function between(parent, a, b, d, color, material, o)
				o = o or {}
				o.cyl = true
				local len = (b - a).Magnitude
				if len < 0.05 then len = 0.05 end
				return mk(parent, V3(len, d, d), CFrame.lookAt((a + b) / 2, b) * ANG(0, pi / 2, 0), color, material, o)
			end
			local function hologram(part, text, color, w, h, off)
				local bb = new("BillboardGui", {
					Size = UDim2.fromOffset(w or 260, h or 56), StudsOffset = V3(0, off or 5, 0),
					LightInfluence = 0, MaxDistance = 140, AlwaysOnTop = false, Adornee = part,
				}, part)
				new("TextLabel", {
					BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.Code, TextScaled = true,
					TextColor3 = color, TextStrokeColor3 = C(0, 20, 40), TextStrokeTransparency = 0.4, Text = text,
				}, bb)
				return bb
			end

			local reserved = {}
			local function reserve(x, z, rad) reserved[#reserved + 1] = {x, z, rad} end
			local function clear(x, z, rad)
				if x * x + (z + 30) * (z + 30) < 6400 then return false end
				for _, q in ipairs(reserved) do
					local dx, dz = x - q[1], z - q[2]
					local rr = q[3] + (rad or 0)
					if dx * dx + dz * dz < rr * rr then return false end
				end
				return true
			end
			reserve(230, 160, 135); reserve(-200, 130, 55); reserve(-260, 320, 60); reserve(-130, 440, 80)
			reserve(310, 390, 55); reserve(0, 250, 75); reserve(130, -120, 25); reserve(-140, -150, 25); reserve(40, -260, 25)

			local ups = {}
			local function onUpdate(f) ups[#ups + 1] = f end
			local function section(name, fn)
				local ok, e = pcall(fn)
				if not ok then warnRG("gelo/" .. name .. ":", e) end
			end
			local pulsers = {}

			section("chao", function()
				mk(model, V3(2000, 2, 2000), W(0, -1, 0), C(176, 218, 246), ICE, {solid = true, refl = 0.28})
				local patches, tries = {}, 0
				while #patches < 46 and tries < 600 do
					tries = tries + 1
					local x, z, rad = rnd(-800, 800), rnd(-800, 800), rnd(22, 85)
					local ok = true
					for _, q in ipairs(patches) do
						local dx, dz = x - q[1], z - q[2]
						local rr = rad + q[3] + 2
						if dx * dx + dz * dz < rr * rr then ok = false break end
					end
					if ok then
						patches[#patches + 1] = {x, z, rad}
						local col = WHITE:Lerp(C(205, 228, 248), rnd(0, 0.6))
						column(model, 0.1 + #patches * 0.002, rad * 2, W(x, 0.06, z), col, SNOW, {shadow = false})
					end
				end
				for _ = 1, 38 do
					local x, z = rnd(-600, 600), rnd(-600, 600)
					if clear(x, z, 8) then
						local a = rnd(0, 2 * pi)
						local p = W(x, 0.14, z)
						local dir = V3(cos(a), 0, sin(a))
						for _ = 1, r:NextInteger(3, 6) do
							local len = rnd(8, 22)
							local nxt = p + dir * len
							between(model, p, nxt, 0.35, C(70, 120, 175), SMOOTH, {shadow = false, trans = 0.25})
							p = nxt
							dir = (CF(0, 0, 0) * ANG(0, rnd(-0.8, 0.8), 0)):VectorToWorldSpace(dir)
						end
					end
				end
				for _ = 1, 70 do
					local x, z = rnd(-700, 700), rnd(-700, 700)
					if clear(x, z, 10) then
						local w, h = rnd(14, 46), rnd(3, 9)
						mk(model, V3(w, h, w * rnd(0.6, 1.1)), CF(W(x, -h * 0.25, z)) * ANG(0, rnd(0, 2 * pi), 0),
							WHITE:Lerp(C(200, 224, 245), rnd(0, 0.4)), SNOW, {ellipsoid = true, shadow = false})
					end
				end
			end)

			section("chegada", function()
				local c = W(0, 0.12, -30)
				mk(model, V3(0.2, 34, 34), CF(c) * ANG(0, 0, pi / 2), C(160, 230, 255), NEON, {cyl = true, trans = 0.65, shadow = false})
				mk(model, V3(0.25, 46, 46), CF(c + V3(0, 0.02, 0)) * ANG(0, 0, pi / 2), C(40, 80, 130), SMOOTH, {cyl = true, trans = 0.55, shadow = false})
				local runes = {}
				for i = 1, 16 do
					local p = mk(model, V3(1.2, 0.3, 3.2), c, (i % 2 == 0) and AQUA or CYAN, NEON, {shadow = false, trans = 0.15})
					runes[i] = {p = p, a = i / 16 * 2 * pi}
				end
				local ring2 = {}
				for i = 1, 8 do
					local p = mk(model, V3(0.9, 0.3, 5), c, WHITE, NEON, {shadow = false, trans = 0.3})
					ring2[i] = {p = p, a = i / 8 * 2 * pi}
				end
				local padL = mk(model, V3(1, 1, 1), c + V3(0, 1, 0), WHITE, SMOOTH, {trans = 1, shadow = false})
				local pl = light(padL, AQUA, 1.5, 28)
				emit(padL, {
					Texture = SPARK, Rate = 16, Lifetime = NumberRange.new(2, 3.4), Speed = NumberRange.new(2, 5),
					EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(50, 50),
					Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)}),
					Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)}),
					Color = ColorSequence.new(AQUA), LightEmission = 1, Drag = 1.2,
				})
				onUpdate(function(t)
					for _, q in ipairs(runes) do
						local a = q.a + t * 0.35
						q.p.CFrame = CF(c) * ANG(0, -a, 0) * CF(0, 0, 19.5) * ANG(0, pi / 2, 0)
					end
					for _, q in ipairs(ring2) do
						local a = q.a - t * 0.6
						q.p.CFrame = CF(c) * ANG(0, -a, 0) * CF(0, 0, 14) * ANG(0, pi / 2, 0)
					end
					pl.Brightness = 1.3 + sin(t * 2.2) * 0.5
				end)
			end)

			section("espirais", function()
				local function spire(x, z, h, w, lit)
					local yaw = rnd(0, 2 * pi)
					local base = CF(W(x, -2, z)) * ANG(rnd(-0.1, 0.1), yaw, rnd(-0.1, 0.1))
					local col = pick(ICEBLUE)
					local y = 0
					local cw = w
					local n = 3
					for k = 1, n do
						local sh = h / n
						mk(model, V3(cw, sh + 1, cw), base * CF(0, y + sh / 2, 0) * ANG(0, k * 0.4, 0), col, ICE,
							{solid = true, trans = 0.12 + k * 0.05, refl = 0.2, shadow = (k == 1)})
						y = y + sh
						cw = cw * 0.62
					end
					mk(model, V3(cw * 1.1, cw * 1.6, cw * 1.1), base * CF(0, y + cw * 0.6, 0) * ANG(0.78, 0.78, 0), col, ICE,
						{trans = 0.1, refl = 0.25, shadow = false})
					if lit then
						local core = mk(model, V3(w * 0.28, h * 0.8, w * 0.28), base * CF(0, h * 0.42, 0), AQUA, NEON,
							{trans = 0.55, shadow = false})
						pulsers[#pulsers + 1] = {p = core, base = 0.55, l = (lit == 2) and light(core, AQUA, 1.4, 38) or nil, ph = rnd(0, 6.28), x = x, z = z}
					end
				end
				local placed, tries, lights = 0, 0, 0
				while placed < 78 and tries < 900 do
					tries = tries + 1
					local x, z = rnd(-640, 640), rnd(-640, 640)
					local w = rnd(5, 13)
					if clear(x, z, w) then
						local lit = (placed % 4 == 0) and ((lights < 12) and 2 or 1) or false
						if lit == 2 then lights = lights + 1 end
						spire(x, z, rnd(22, 95), w, lit)
						placed = placed + 1
					end
				end
			end)

			section("cristais", function()
				local cols = { C(80, 220, 255), C(120, 190, 255), C(170, 140, 255), C(90, 255, 220) }
				local function cluster(x, z, s)
					local col = pick(cols)
					local center = W(x, 0, z)
					local n = r:NextInteger(5, 8)
					local mainP
					for i = 1, n do
						local a = i / n * 2 * pi + rnd(-0.3, 0.3)
						local lean = (i == 1) and 0 or rnd(0.25, 0.7)
						local h = ((i == 1) and rnd(9, 15) or rnd(4, 9)) * s
						local w = rnd(1.4, 2.6) * s
						local cf = CF(center) * ANG(0, a, 0) * ANG(0, 0, lean) * CF(0, h / 2 - 0.5, 0) * ANG(0, 0.78, 0)
						local p = mk(model, V3(w, h, w), cf, col:Lerp(WHITE, rnd(0, 0.35)), GLASS, {trans = 0.2, refl = 0.15, shadow = false})
						local tip = mk(model, V3(w * 0.75, w * 1.3, w * 0.75), cf * CF(0, h / 2 + w * 0.4, 0) * ANG(0.78, 0, 0.78), p.Color, GLASS, {trans = 0.2, shadow = false})
						mainP = mainP or p
						if i <= 3 then
							local core = mk(model, V3(w * 0.4, h * 0.85, w * 0.4), cf, col, NEON, {trans = 0.45, shadow = false})
							pulsers[#pulsers + 1] = {p = core, base = 0.45, ph = rnd(0, 6.28), x = x, z = z}
						end
					end
					local l = light(mainP, col, 1.2, 28)
					pulsers[#pulsers + 1] = {l = l, lbase = 1.2, ph = rnd(0, 6.28), x = x, z = z}
				end
				local placed, tries = 0, 0
				while placed < 30 and tries < 500 do
					tries = tries + 1
					local x, z = rnd(-520, 520), rnd(-520, 520)
					if clear(x, z, 8) then
						cluster(x, z, rnd(0.8, 1.7))
						placed = placed + 1
					end
				end
			end)

			local heart, shards = nil, {}
			section("monumento", function()
				local c = W(0, 0, 250)
				column(model, 3, 96, c + V3(0, 1.4, 0), C(120, 170, 215), ICE, {solid = true, trans = 0.1, refl = 0.3})
				column(model, 0.2, 80, c + V3(0, 3, 0), AQUA, NEON, {trans = 0.7, shadow = false})
				for i = 1, 8 do
					local a = i / 8 * 2 * pi
					local px, pz = cos(a) * 42, sin(a) * 42
					local cf = CF(c + V3(px, 0, pz)) * ANG(0, -a, 0)
					mk(model, V3(7, 26, 4), cf * CF(0, 13, 0) * ANG(0.04 * ((i % 2 == 0) and 1 or -1), 0, 0), C(130, 190, 240), ICE,
						{solid = true, trans = 0.18, refl = 0.2})
					for k = 1, 3 do
						local rn = mk(model, V3(3.2 - k * 0.4, 0.5, 0.3), cf * CF(0, 5 + k * 5.5, -2.1), CYAN, NEON, {shadow = false})
						pulsers[#pulsers + 1] = {p = rn, base = 0.1, ph = i + k, x = c.X - O.X + px, z = c.Z - O.Z + pz}
					end
					if i % 2 == 0 then
						local a2 = (i + 1) / 8 * 2 * pi
						local p2 = c + V3(cos(a2) * 42, 27, sin(a2) * 42)
						between(model, c + V3(px, 27, pz), p2, 3, C(140, 200, 245), ICE, {trans = 0.2})
					end
				end
				heart = mk(model, V3(18, 40, 18), CF(c + V3(0, 34, 0)), AQUA, NEON, {trans = 0.25, shadow = false})
				local inner = mk(model, V3(9, 22, 9), CF(c + V3(0, 34, 0)), WHITE, NEON, {trans = 0.1, shadow = false})
				local hl = light(heart, AQUA, 4, 120)
				emit(heart, {
					Texture = SPARK, Rate = 30, Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(3, 9),
					SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0)}),
					Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
					Color = ColorSequence.new(AQUA), LightEmission = 1, Drag = 1,
				})
				for i = 1, 14 do
					local s = rnd(2.5, 6)
					local p = mk(model, V3(s * 0.6, s * 1.8, s * 0.6), CF(c), pick(ICEBLUE), GLASS, {trans = 0.18, shadow = false})
					shards[i] = {p = p, rad = rnd(16, 34), sp = rnd(0.25, 0.7) * ((i % 2 == 0) and 1 or -1), ph = rnd(0, 6.28), hh = rnd(18, 54), bob = rnd(0.5, 1.4)}
				end
				onUpdate(function(t)
					local pulse = 0.5 + 0.5 * sin(t * 1.4)
					heart.CFrame = CF(c + V3(0, 34 + sin(t * 0.8) * 2.5, 0)) * ANG(t * 0.35, t * 0.5, 0)
					inner.CFrame = heart.CFrame * ANG(0.5, 0.5, 0)
					heart.Transparency = 0.15 + pulse * 0.2
					hl.Brightness = 3 + pulse * 2.4
					for _, s in ipairs(shards) do
						local a = t * s.sp + s.ph
						local pos = c + V3(cos(a) * s.rad, s.hh + sin(t * s.bob + s.ph) * 3, sin(a) * s.rad)
						s.p.CFrame = CF(pos) * ANG(t * 0.6 + s.ph, a, t * 0.4)
					end
				end)
			end)

			onUpdate(function(t, dt, lp)
				for _, q in ipairs(pulsers) do
					local near = clamp01(1 - sqrt((lp.X - q.x) ^ 2 + (lp.Z - q.z) ^ 2) / 150)
					local wave = 0.5 + 0.5 * sin(t * 1.6 + q.ph)
					if q.p then
						q.p.Transparency = clamp01(q.base + (1 - wave) * 0.25 - near * 0.35)
					end
					if q.l then
						q.l.Brightness = (q.lbase or 1.4) * (0.6 + wave * 0.5 + near * 1.2)
					end
				end
			end)

			section("geleira", function()
				for i = -9, 9 do
					local x = i * 70 + rnd(-14, 14)
					local z = 700 + rnd(-30, 40)
					local h = rnd(90, 190)
					local w = rnd(60, 95)
					if abs(x + 130) > 80 or true then
						mk(model, V3(w, h, rnd(50, 90)), CF(W(x, h / 2 - 4, z)) * ANG(rnd(-0.05, 0.05), rnd(-0.4, 0.4), rnd(-0.06, 0.06)),
							pick({C(140, 200, 245), C(160, 215, 250), C(120, 180, 235)}), GLACIER, {solid = true, trans = 0.08, refl = 0.15})
					end
				end
				for _, side in ipairs({-1, 1}) do
					for i = 1, 7 do
						local z = -200 + i * 120
						local h = rnd(60, 130)
						mk(model, V3(rnd(60, 100), h, rnd(70, 110)), CF(W(side * rnd(780, 860), h / 2 - 4, z)) * ANG(0, rnd(-0.5, 0.5), 0),
							pick({C(140, 200, 245), C(160, 215, 250)}), GLACIER, {solid = true, trans = 0.1, refl = 0.12})
					end
				end

				local cc = W(-130, 0, 440)
				local faceYaw = CF(cc) * ANG(0, pi, 0)
				mk(model, V3(26, 70, 30), faceYaw * CF(-24, 35, 0), C(135, 195, 240), GLACIER, {solid = true, trans = 0.1, refl = 0.15})
				mk(model, V3(26, 70, 30), faceYaw * CF(24, 35, 0), C(135, 195, 240), GLACIER, {solid = true, trans = 0.1, refl = 0.15})
				mk(model, V3(74, 22, 30), faceYaw * CF(0, 66, 0) * ANG(0, 0, 0.02), C(150, 210, 250), GLACIER, {solid = true, trans = 0.1, refl = 0.15})
				mk(model, V3(80, 4, 90), faceYaw * CF(0, 1, -40), C(130, 190, 235), ICE, {solid = true, trans = 0.05, refl = 0.35})
				local glowWall = mk(model, V3(60, 52, 3), faceYaw * CF(0, 28, -78), C(40, 160, 255), NEON, {trans = 0.35, shadow = false})
				light(glowWall, C(80, 200, 255), 3.5, 90)
				local inner = mk(model, V3(1, 1, 1), faceYaw * CF(0, 20, -50), WHITE, SMOOTH, {trans = 1, shadow = false})
				emit(inner, {
					Texture = SPARK, Rate = 24, Lifetime = NumberRange.new(3, 6), Speed = NumberRange.new(1, 4),
					SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0)}),
					Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)}),
					Color = ColorSequence.new(AQUA), LightEmission = 1, Drag = 0.8,
				})
				for i = 1, 22 do
					local x = -34 + i * 3.1 + rnd(-0.8, 0.8)
					local len = rnd(5, 20)
					mk(model, V3(rnd(1.2, 2.6), len, rnd(1.2, 2.6)), faceYaw * CF(x, 55 - len / 2, -rnd(1, 12)) * ANG(0, rnd(0, 3), 0),
						C(190, 235, 255), ICE, {trans = 0.1, refl = 0.3, shadow = false})
				end

				local wf = W(120, 0, 560)
				mk(model, V3(90, 110, 40), CF(wf + V3(0, 55, 14)), C(140, 200, 245), GLACIER, {solid = true, trans = 0.08})
				for i = 1, 26 do
					local x = -38 + i * 3
					local top = rnd(70, 96)
					mk(model, V3(rnd(2, 3.6), top, rnd(2, 3.6)), CF(wf + V3(x, top / 2, -4 - rnd(0, 3))) * ANG(0, rnd(0, 3), 0),
						pick({C(180, 230, 255), C(150, 215, 255), C(200, 240, 255)}), ICE, {trans = 0.18, refl = 0.3, shadow = false})
				end
				mk(model, V3(100, 6, 24), CF(wf + V3(0, 2, -14)), C(220, 242, 255), SNOW, {ellipsoid = true, shadow = false})
				local wfl = mk(model, V3(1, 1, 1), CF(wf + V3(0, 40, -9)), WHITE, SMOOTH, {trans = 1, shadow = false})
				light(wfl, CYAN, 2, 60)
			end)

			local fishes = {}
			section("lago", function()
				local lc = W(230, 0, 160)
				column(model, 0.3, 270, lc + V3(0, 0.02, 0), C(8, 30, 70), SMOOTH, {shadow = false})
				column(model, 0.3, 262, lc + V3(0, -0.15, 0), C(20, 90, 170), NEON, {trans = 0.82, shadow = false})
				column(model, 0.3, 266, lc + V3(0, 0.25, 0), C(130, 200, 245), GLACIER, {trans = 0.38, refl = 0.45, shadow = false})
				column(model, 0.3, 270, lc + V3(0, 0.1, 0), C(235, 248, 255), ICE, {trans = 0.55, refl = 0.35, shadow = false})
				for i = 1, 14 do
					local a = rnd(0, 2 * pi)
					local p = lc + V3(0, 0.4, 0)
					local dir = V3(cos(a), 0, sin(a))
					local d = rnd(0, 40)
					p = p + dir * d
					for _ = 1, 4 do
						local len = rnd(14, 28)
						local nxt = p + dir * len
						if (nxt - lc).Magnitude < 128 then
							between(model, p, nxt, 0.4, C(235, 248, 255), SMOOTH, {shadow = false, trans = 0.35})
						end
						p = nxt
						dir = ANG(0, rnd(-0.6, 0.6), 0):VectorToWorldSpace(dir)
					end
				end
				for i = 1, 14 do
					local body = mk(model, V3(5, 1.6, 1.6), CF(lc), C(30, 70, 120), SMOOTH, {ellipsoid = true, shadow = false})
					local tail = mk(model, V3(0.4, 2.2, 1.6), CF(lc), C(40, 110, 170), NEON, {trans = 0.3, shadow = false})
					fishes[i] = {b = body, t = tail, rad = rnd(15, 95), sp = rnd(0.08, 0.2) * ((i % 2 == 0) and 1 or -1), ph = rnd(0, 6.28), dp = rnd(1.2, 4)}
				end
				for i = 1, 10 do
					local a = i / 10 * 2 * pi
					local px, pz = cos(a) * 140, sin(a) * 140
					local post = column(model, 14, 0.8, lc + V3(px, 7, pz), C(60, 70, 90), METAL)
					local lamp = ball(model, 2.4, lc + V3(px, 14.4, pz), C(200, 240, 255), NEON, {shadow = false})
					if i % 2 == 0 then light(lamp, AQUA, 1.6, 40) end
				end
				local sign = mk(model, V3(0.5, 8, 22), CF(lc + V3(-150, 8, 0)) * ANG(0, 0.1, 0), C(30, 40, 60), SMOOTH, {solid = true})
				onUpdate(function(t)
					for _, f in ipairs(fishes) do
						local a = t * f.sp + f.ph
						local pos = lc + V3(cos(a) * f.rad, -f.dp, sin(a) * f.rad)
						local dirv = V3(-sin(a), 0, cos(a)) * ((f.sp > 0) and 1 or -1)
						local cf = CFrame.lookAt(pos, pos + dirv) * ANG(0, pi / 2, 0)
						f.b.CFrame = cf
						f.t.CFrame = cf * CF(-3.1, 0, 0) * ANG(0, sin(t * 6 + f.ph) * 0.5, 0)
					end
				end)
			end)

			section("cabana", function()
				local hc = W(-200, 0, 130)
				local yaw = CF(hc) * ANG(0, 0.5, 0)
				local function part(size, rel, col, mat, o) return mk(model, size, yaw * rel, col, mat, o) end
				part(V3(30, 1, 24), CF(0, 0.5, 0), C(90, 70, 55), WOOD, {solid = true})
				part(V3(30, 12, 1.5), CF(0, 7, 11.5), C(120, 90, 65), WOOD, {solid = true})
				part(V3(1.5, 12, 24), CF(-14.5, 7, 0), C(110, 82, 60), WOOD, {solid = true})
				part(V3(1.5, 12, 24), CF(14.5, 7, 0), C(110, 82, 60), WOOD, {solid = true})
				part(V3(10, 12, 1.5), CF(-10, 7, -11.5), C(120, 90, 65), WOOD, {solid = true})
				part(V3(10, 12, 1.5), CF(10, 7, -11.5), C(120, 90, 65), WOOD, {solid = true})
				part(V3(10, 4, 1.5), CF(0, 11, -11.5), C(120, 90, 65), WOOD, {solid = true})
				for _, s in ipairs({-1, 1}) do
					part(V3(18, 1.2, 28), CF(s * 7.3, 15.4, 0) * ANG(0, 0, -s * 0.5), C(70, 55, 48), WOOD, {solid = true})
					part(V3(18, 1.6, 29), CF(s * 7.5, 16.4, 0) * ANG(0, 0, -s * 0.5), WHITE, SNOW, {shadow = false})
				end
				local win = part(V3(0.4, 5, 7), CF(14.2, 8, 3), C(255, 170, 70), NEON, {trans = 0.2, shadow = false})
				light(win, C(255, 170, 80), 2.5, 45)
				local inLamp = part(V3(2, 2, 2), CF(0, 10, 0), C(255, 190, 110), NEON, {ball = true, shadow = false})
				light(inLamp, C(255, 185, 100), 2.2, 30)
				part(V3(10, 0.8, 4), CF(-8, 4, -7), C(70, 70, 80), METAL, {solid = true})
				for _, dx in ipairs({-12, -4}) do part(V3(0.6, 4, 0.6), CF(dx, 2, -7), C(60, 60, 70), METAL) end
				part(V3(1.6, 2.6, 1.6), CF(-6, 5.6, -7), C(110, 255, 140), GLASS, {trans = 0.25})
				part(V3(1.1, 1.8, 1.1), CF(-9, 5.2, -7), C(255, 90, 200), GLASS, {trans = 0.25})
				part(V3(3, 8, 3), CF(-8, 19, -6), C(100, 100, 108), ROCK)
				local chim = part(V3(1, 1, 1), CF(-8, 24, -6), WHITE, SMOOTH, {trans = 1, shadow = false})
				emit(chim, {
					Texture = SMOKE, Rate = 7, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(3, 5),
					EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(12, 12), Acceleration = V3(3, 0, 1),
					Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 9)}),
					Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1)}),
					Color = ColorSequence.new(C(225, 232, 240)),
				})
				part(V3(0.6, 26, 0.6), CF(10, 28, 4), C(150, 155, 165), METAL)
				part(V3(7, 0.4, 0.4), CF(10, 36, 4), C(150, 155, 165), METAL)
				local beacon = part(V3(1.6, 1.6, 1.6), CF(10, 41.4, 4), C(255, 60, 60), NEON, {ball = true, shadow = false})
				local bl = light(beacon, C(255, 70, 70), 2, 40)
				onUpdate(function(t)
					local on = (t % 1.6) < 0.25
					beacon.Transparency = on and 0 or 0.85
					bl.Brightness = on and 3 or 0
				end)
				for _, c in ipairs({ {-22, 3, 14}, {-25, 3, 10}, {-23, 9, 12} }) do
					part(V3(5, 5, 5), CF(c[1], c[2], c[3]) * ANG(0, rnd(-0.3, 0.3), 0), C(150, 110, 70), WOOD, {solid = true})
				end
				local sg = part(V3(0.6, 5, 11), CF(20, 5, 14) * ANG(0, 0.4, 0), C(95, 70, 50), WOOD, {solid = true})

				local function snowman(x, z, s, kind)
					local p = W(x, 0, z)
					local function sb(d, y, col, mat, dx, dz)
						return ball(model, d * s, p + V3(dx or 0, y * s, dz or 0), col, mat or SNOW, {solid = true, shadow = false})
					end
					sb(6.4, 3, WHITE); sb(4.8, 7.8, WHITE); sb(3.6, 11.4, WHITE)
					local head = p + V3(0, 11.4 * s, 0)
					for _, ex in ipairs({-0.7, 0.7}) do
						ball(model, 0.8 * s, head + V3(ex * s, 0.5 * s, 1.5 * s), C(20, 20, 20), SMOOTH, {shadow = false})
					end
					mk(model, V3(0.4 * s, 0.4 * s, 2 * s), CF(head + V3(0, 0, 2.1 * s)), C(255, 130, 40), SMOOTH, {shadow = false})
					if kind == "rick" then
						for i = -3, 3 do
							mk(model, V3(0.8 * s, 3 * s, 0.8 * s), CF(head + V3(i * 0.55 * s, 2.2 * s, 0)) * ANG(0, 0, -i * 0.12), C(140, 200, 255), SMOOTH, {shadow = false})
						end
						mk(model, V3(1.6 * s, 0.35 * s, 0.4 * s), CF(head + V3(0, 1.3 * s, 1.6 * s)), C(30, 30, 30), SMOOTH, {shadow = false})
						mk(model, V3(0.5 * s, 0.9 * s, 0.4 * s), CF(head + V3(0.8 * s, -1.1 * s, 1.7 * s)), C(130, 255, 130), NEON, {shadow = false})
						local arm = mk(model, V3(0.5 * s, 0.5 * s, 8 * s), CF(p + V3(3.8 * s, 8.6 * s, 0.8 * s)) * ANG(0.2, 0.7, 0), WOOD)
						local gun = mk(model, V3(1.4 * s, 1.4 * s, 2.4 * s), CF(p + V3(6.4 * s, 9.3 * s, 3.7 * s)) * ANG(0.2, 0.7, 0), C(230, 235, 240), SMOOTH)
						ball(model, 0.8 * s, p + V3(7.2 * s, 9.5 * s, 4.9 * s), C(120, 255, 140), NEON, {shadow = false})
					else
						mk(model, V3(3.8 * s, 1.4 * s, 3.6 * s), CF(head + V3(0, 1.9 * s, -0.2 * s)), C(110, 70, 40), SMOOTH, {shadow = false})
						mk(model, V3(4.2 * s, 3.2 * s, 4.2 * s), CF(p + V3(0, 7.8 * s, 0)), C(255, 215, 60), SMOOTH, {ellipsoid = true, shadow = false, trans = 0.05})
						ball(model, 4.9 * s, p + V3(0, 7.7 * s, 0), WHITE, SNOW, {shadow = false, trans = 0.9})
					end
				end
				snowman(-170, 85, 1.5, "rick")
				snowman(-158, 80, 1.0, "morty")

				local pc = W(-232, 0, 80)
				mk(model, V3(10, 10, 10), CF(pc + V3(0, 5, 0)) * ANG(0, 0.3, 0), C(190, 235, 255), ICE, {solid = true, trans = 0.45, refl = 0.25})
				local pk = mk(model, V3(2.8, 6.4, 2.8), CF(pc + V3(0, 5.2, 0)) * ANG(0.2, 0, 0.4), C(80, 150, 40), SMOOTH, {ellipsoid = true, shadow = false})
				mk(model, V3(0.7, 0.7, 0.4), CF(pc + V3(-0.6, 6.5, 1.5)), WHITE, SMOOTH, {ball = true, shadow = false})
				mk(model, V3(0.7, 0.7, 0.4), CF(pc + V3(0.6, 6.5, 1.5)), WHITE, SMOOTH, {ball = true, shadow = false})
			end)

			section("mamute", function()

				local SC = 1.25
				local mc = W(310, 0, 390)
				local RW = 26
				local FUR, FUR2, FUR3 = C(112, 78, 52), C(88, 58, 40), C(138, 98, 64)
				local IVORY = C(240, 232, 205)
				local function v(x, y, z) return V3(x * SC, y * SC, z * SC) end
				local function sz(x, y, z) return V3(x * SC, y * SC, z * SC) end
				local home = CF(mc)

				local body = Instance.new("Model")
				body.Name = "Mamute"
				local anchor = mk(body, V3(0.2, 0.2, 0.2), home, C(0, 0, 0), SMOOTH, {trans = 1, shadow = false})
				body.PrimaryPart = anchor
				body.Parent = model
				local function bp(size, rel, col, o)
					o = o or {}
					if o.shadow == nil then o.shadow = false end
					return mk(body, size, home * rel, col, SMOOTH, o)
				end
				local function wp(x, y, z) return home:PointToWorldSpace(v(x, y, z)) end

				bp(sz(13, 12, 20), CF(v(0, 13.5, 1)), FUR, {ellipsoid = true, shadow = true})
				bp(sz(11, 9.5, 9), CF(v(0, 19, -5)), FUR2, {ellipsoid = true, shadow = true})
				bp(sz(12, 11, 10), CF(v(0, 14, 8.5)), FUR, {ellipsoid = true, shadow = true})
				bp(sz(8.2, 8.5, 9), CF(v(0, 16, -12.5)), FUR, {ellipsoid = true, shadow = true})
				bp(sz(6.6, 5.2, 6.4), CF(v(0, 20.6, -11.8)), FUR2, {ellipsoid = true})
				bp(sz(4, 3, 4), CF(v(0, 23.2, -11.6)), FUR3, {ellipsoid = true})

				for _, sd in ipairs({-1, 1}) do
					for zz = -8, 10, 1.9 do
						local h = rnd(3.5, 7)
						bp(sz(0.9, h, 2), CF(v(sd * (5.9 + rnd(-0.3, 0.3)), 11 - h / 2, zz)) * ANG(0, 0, sd * rnd(0.05, 0.18)), (r:NextInteger(0, 1) == 0) and FUR2 or FUR)
					end
				end
				for i = 1, 6 do
					local h = rnd(3.5, 5.5)
					bp(sz(0.9, h, 1.6), CF(v(rnd(-3.2, 3.2), 11 - h / 2, rnd(-12, -10))), FUR2)
				end
				for _, q in ipairs({ {23.4, -5}, {22.2, -2}, {20.4, 1}, {19.6, 4}, {19.6, 7}, {19.2, 10} }) do
					bp(sz(2, 3.2, 1.8), CF(v(0, q[1], q[2])) * ANG(0.3, 0, 0), FUR3)
				end

				for _, sd in ipairs({-1, 1}) do
					local P0, P1, P2 = V3(sd * 2.6, 14.2, -15.6), V3(sd * 6.6, 9, -22.5), V3(sd * 3.4, 13, -28)
					local function bez(u)
						local a, b, c = (1 - u) * (1 - u), 2 * (1 - u) * u, u * u
						return P0 * a + P1 * b + P2 * c
					end
					local prev = bez(0)
					for i = 1, 8 do
						local nx = bez(i / 8)
						local th = (1.5 - 1.2 * (i / 8)) * SC
						between(body, wp(prev.X, prev.Y, prev.Z), wp(nx.X, nx.Y, nx.Z), th, IVORY, SMOOTH, {shadow = false})
						prev = nx
					end
				end

				local eyes = {}
				for k, sd in ipairs({-1, 1}) do
					eyes[k] = bp(sz(0.95, 0.95, 0.95), CF(v(sd * 3.3, 17.2, -15.2)), C(20, 14, 12), {ellipsoid = true})
					bp(sz(0.3, 0.3, 0.3), CF(v(sd * 3.65, 17.5, -15.4)), WHITE, {ellipsoid = true})
				end

				local legs = {}
				local hips = { {-3.7, -6.2, 0}, {3.7, -6.2, pi}, {-3.9, 8.4, pi}, {3.9, 8.4, 0} }
				for i, h in ipairs(hips) do
					local L = {hip = CF(v(h[1], 9.6, h[2])), ph = h[3], parts = {}}
					local defs = {
						{sz(4.4, 7, 4.4), CF(0, -3.4 * SC, 0), FUR},
						{sz(3.4, 5, 3.4), CF(0, -6.6 * SC, 0), FUR2},
						{sz(4.6, 2.4, 4.6), CF(0, -8.2 * SC, 0), FUR3},
						{sz(4.4, 1.6, 5.2), CF(0, -8.8 * SC, 0.4 * SC), FUR2},
					}
					for _, d in ipairs(defs) do
						L.parts[#L.parts + 1] = {mk(model, d[1], home * L.hip * d[2], d[3], SMOOTH, {ellipsoid = true, shadow = false}), d[2]}
					end
					legs[i] = L
				end

				local ears = {}
				for k, sd in ipairs({-1, 1}) do
					ears[k] = {sd = sd, hinge = CF(v(sd * 4.2, 17.6, -10.4)),
						p = mk(model, sz(0.7, 5.6, 4.6), home, FUR2, SMOOTH, {ellipsoid = true, shadow = false})}
				end

				local TBASE = {0.05, 0.08, 0.12, 0.2, 0.28, 0.34, 0.4}
				local trunk = {}
				for i = 1, 7 do
					local th = (3.2 - (i - 1) * 0.28) * SC
					local L = 2.7 * SC
					trunk[i] = {p = mk(model, V3(L + 0.4, th, th), home, FUR2, SMOOTH, {cyl = true, shadow = false}), L = L, base = TBASE[i]}
				end
				local tipP = mk(model, V3(0.4, 0.4, 0.4), home, WHITE, SMOOTH, {trans = 1, shadow = false})
				local puff = emit(tipP, {
					Texture = SMOKE, Rate = 0, Lifetime = NumberRange.new(1.6, 2.6), Speed = NumberRange.new(5, 9),
					EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(25, 25), Acceleration = V3(0, 3, 0), Drag = 1,
					Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.5)}),
					Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1)}),
					Color = ColorSequence.new(C(235, 248, 255)),
				})

				local tail = {}
				for i = 1, 3 do
					local th = (1.1 - (i - 1) * 0.15) * SC
					local L = 2.6 * SC
					tail[i] = {p = mk(model, V3(L + 0.3, th, th), home, FUR2, SMOOTH, {cyl = true, shadow = false}), L = L}
				end
				local tuft = mk(model, sz(1.8, 1.8, 3.4), home, FUR3, SMOOTH, {ellipsoid = true, shadow = false})

				local walkS, ph, m = 0, 0, 1
				local firedCyc, nextBreath = -1, 3
				onUpdate(function(t, dt, lp)
					dt = dt or 0.016
					local cyc = t % 34
					m = m + (((cyc < 23) and 1 or 0) - m) * min(1, dt * 1.1)
					walkS = walkS + dt * 3.4 * m
					ph = ph + dt * 2.7 * m
					local a = walkS / RW
					local pos = mc + V3(cos(a) * RW, 0, sin(a) * RW)
					local tan = V3(-sin(a), 0, cos(a))
					local bob = abs(sin(ph)) * 0.3 * m + sin(t * 1.1) * 0.07
					local at = pos + V3(0, bob, 0)
					local base = CFrame.lookAt(at, at + tan) * ANG(0, 0, sin(ph) * 0.025 * m)
					body:PivotTo(base)

					local k = 0
					if cyc > 25.5 and cyc < 29 then k = sin((cyc - 25.5) / 3.5 * pi) end
					local cid = floor(t / 34)
					if cyc > 26.8 and firedCyc ~= cid then
						firedCyc = cid
						pcall(function() puff:Emit(40) end)
					end
					if t > nextBreath then
						nextBreath = t + rnd(3, 5)
						pcall(function() puff:Emit(5) end)
					end

					for _, L in ipairs(legs) do
						local fr = base * L.hip * ANG(sin(ph + L.ph) * 0.32 * m, 0, 0)
						for _, q in ipairs(L.parts) do q[1].CFrame = fr * q[2] end
					end

					local flap = 0.12 * sin(t * 1.6) + k * 0.3
					for _, e in ipairs(ears) do
						e.p.CFrame = base * e.hinge * ANG(0, e.sd * (0.45 + flap), e.sd * 0.15) * CF(0, -1.6 * SC, 1.6 * SC)
					end

					local f = base * CF(v(0, 13.2, -16.4)) * ANG(-pi / 2, 0, 0)
					for i, sg in ipairs(trunk) do
						local dphi = sg.base + 0.08 * sin(t * 0.9 - i * 0.45) + k * 0.18
						local dpsi = 0.09 * sin(t * 0.6 + i * 0.5)
						f = f * ANG(dphi, dpsi, 0)
						sg.p.CFrame = f * CF(0, 0, -sg.L / 2) * ANG(0, pi / 2, 0)
						f = f * CF(0, 0, -sg.L)
					end
					tipP.CFrame = f

					local tf = base * CF(v(0, 14.6, 13.4)) * ANG(-pi / 2 - 0.35, 0, 0)
					for i, sg in ipairs(tail) do
						tf = tf * ANG(0.12 + 0.15 * sin(t * 1.8 - i * 0.7), 0.2 * sin(t * 1.3 - i * 0.6), 0)
						sg.p.CFrame = tf * CF(0, 0, -sg.L / 2) * ANG(0, pi / 2, 0)
						tf = tf * CF(0, 0, -sg.L)
					end
					tuft.CFrame = tf * CF(0, 0, -1.6 * SC)

					local blink = (t % 5.3) < 0.15
					for _, e in ipairs(eyes) do
						e.Size = blink and sz(0.95, 0.12, 0.95) or sz(0.95, 0.95, 0.95)
					end
				end)
			end)

			local geysers = {}
			section("geiseres", function()
				local spots = { {130, -120}, {-140, -150}, {40, -260}, {-330, -40}, {420, -60} }
				for i, s in ipairs(spots) do
					local gp = W(s[1], 0, s[2])
					mk(model, V3(16, 4, 16), CF(gp + V3(0, 1, 0)), C(210, 238, 255), ICE, {solid = true, trans = 0.1, shadow = false})
					for k = 1, 6 do
						local a = k / 6 * 2 * pi
						mk(model, V3(2.4, rnd(3, 6), 2.4), CF(gp + V3(cos(a) * 8.5, 1.5, sin(a) * 8.5)) * ANG(rnd(-0.3, 0.3), rnd(0, 3), 0), C(190, 232, 255), ICE, {solid = true, shadow = false})
					end
					local ventP = mk(model, V3(1, 1, 1), CF(gp + V3(0, 3, 0)), WHITE, SMOOTH, {trans = 1, shadow = false})
					local vl = light(ventP, AQUA, 0, 40)
					local jet = emit(ventP, {
						Texture = SMOKE, Rate = 0, Lifetime = NumberRange.new(1.5, 2.6), Speed = NumberRange.new(40, 62),
						EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(6, 6), Acceleration = V3(5, -28, 2),
						Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 9)}),
						Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)}),
						Color = ColorSequence.new(C(220, 245, 255)), LightEmission = 0.5,
					})
					local ice = emit(ventP, {
						Texture = SPARK, Rate = 0, Lifetime = NumberRange.new(1.5, 2.8), Speed = NumberRange.new(30, 55),
						EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), Acceleration = V3(0, -50, 0),
						Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0.2)}),
						Color = ColorSequence.new(AQUA), LightEmission = 1,
					})
					local idle = emit(ventP, {
						Texture = SMOKE, Rate = 6, Lifetime = NumberRange.new(2, 3.5), Speed = NumberRange.new(2, 5),
						EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20),
						Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5)}),
						Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1)}),
						Color = ColorSequence.new(C(230, 248, 255)),
					})
					geysers[i] = {jet = jet, ice = ice, light = vl, next = rnd(2, 9), burstEnd = 0}
				end
				onUpdate(function(t)
					for _, g in ipairs(geysers) do
						if t > g.next then
							g.next = t + rnd(7, 15)
							g.burstEnd = t + 1.1
						end
						local on = t < g.burstEnd
						g.jet.Rate = on and 90 or 0
						g.ice.Rate = on and 40 or 0
						g.light.Brightness = on and 3 or 0
					end
				end)
			end)

			section("rochas", function()
				for _ = 1, 50 do
					local x, z = rnd(-700, 700), rnd(-700, 700)
					if clear(x, z, 6) then
						local s = rnd(3, 9)
						mk(model, V3(s * 1.4, s, s * 1.2), CF(W(x, s * 0.2, z)) * ANG(rnd(-0.3, 0.3), rnd(0, 6), rnd(-0.3, 0.3)),
							C(78, 88, 104), ROCK, {solid = true, shadow = false})
						mk(model, V3(s * 1.5, s * 0.35, s * 1.3), CF(W(x, s * 0.7, z)), WHITE, SNOW, {ellipsoid = true, shadow = false})
					end
				end
			end)

			local ribbons = {}
			section("aurora", function()
				local defs = {
					{a0 = 0.0, span = 1.6, R = 780, y = 210, hue = 0.38},
					{a0 = 2.2, span = 1.3, R = 840, y = 250, hue = 0.52},
					{a0 = -2.1, span = 1.4, R = 820, y = 230, hue = 0.72},
				}
				for ri, d in ipairs(defs) do
					local segs = {}
					for i = 1, 26 do
						local lo = mk(model, V3(1, 1, 0.5), CF(O), CYAN, NEON, {trans = 0.6, shadow = false})
						local hi = mk(model, V3(1, 1, 0.5), CF(O), CYAN, NEON, {trans = 0.85, shadow = false})
						segs[i] = {lo = lo, hi = hi}
					end
					ribbons[ri] = {d = d, segs = segs}
				end
			end)
			local auroraT = 0
			onUpdate(function(t, dt, lp)
				if t - auroraT < 0.033 then return end
				auroraT = t
				for ri, rb in ipairs(ribbons) do
					local d, n = rb.d, #rb.segs
					for i, sg in ipairs(rb.segs) do
						local u = (i - 1) / (n - 1)
						local a = d.a0 + (u - 0.5) * d.span
						local wave = sin(u * 7 + t * 0.35 + ri) * 55 + sin(u * 13 - t * 0.5) * 18
						local rad = d.R + wave
						local h = 90 + 55 * (0.5 + 0.5 * sin(u * 5 + t * 0.6 + ri * 2)) + 22 * sin(t * 1.3 + u * 20)
						local y0 = d.y + sin(u * 3 + t * 0.25) * 14
						local pos = V3(sin(a) * rad, y0, cos(a) * rad)
						local w = (d.span * d.R / n) * 1.25
						local hue = (d.hue + 0.14 * sin(u * 4 + t * 0.2) + 0.04 * sin(t * 0.7)) % 1
						local col = Color3.fromHSV(hue, 0.6, 1)
						local look = O + V3(0, y0, 0)
						local c0 = W(pos.X, pos.Y, pos.Z)
						local base = CFrame.lookAt(c0, look)
						sg.lo.Size = V3(w, h * 0.55, 0.5)
						sg.lo.CFrame = base * CF(0, h * 0.275, 0)
						sg.lo.Color = col
						sg.hi.Size = V3(w, h * 0.55, 0.5)
						sg.hi.CFrame = base * CF(0, h * 0.55 + h * 0.275, 0)
						sg.hi.Color = col:Lerp(C(190, 140, 255), 0.5)
						local fl = 0.55 + 0.2 * sin(t * 1.1 + u * 9 + ri)
						sg.lo.Transparency = fl
						sg.hi.Transparency = 0.82 + 0.1 * sin(t * 0.8 + u * 6)
					end
				end
			end)

			local meteor, meteorTrail
			section("ceu", function()
				ball(model, 420, W(-520, 330, 860), C(190, 215, 240), SMOOTH, {shadow = false})
				ball(model, 440, W(-520, 330, 860), C(150, 190, 235), NEON, {trans = 0.88, shadow = false})
				for i = 1, 64 do
					local a = i / 64 * 2 * pi
					mk(model, V3(22, 1.2, 16), CF(W(-520, 330, 860)) * ANG(0.45, 0, 0.3) * CF(cos(a) * 300, 0, sin(a) * 300) * ANG(0, -a, 0),
						(i % 5 == 0) and C(180, 205, 235) or C(225, 235, 250), NEON, {trans = 0.45 + (i % 3) * 0.1, shadow = false})
				end
				ball(model, 90, W(480, 420, 800), C(250, 245, 230), SMOOTH, {shadow = false})
				ball(model, 100, W(480, 420, 800), C(255, 250, 235), NEON, {trans = 0.9, shadow = false})
				ball(model, 30, W(120, 520, 900), C(255, 190, 150), NEON, {trans = 0.2, shadow = false})
				meteor = mk(model, V3(2, 2, 40), CF(O), WHITE, NEON, {shadow = false, trans = 1})
				meteorTrail = emit(meteor, {
					Texture = SPARK, Rate = 0, Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(0, 3),
					Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 0)}),
					Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
					Color = ColorSequence.new(AQUA), LightEmission = 1,
				})
			end)
			local mt, mFrom, mTo, mNext = nil, nil, nil, 3
			onUpdate(function(t)
				if not meteor then return end
				if not mt and t > mNext then
					mt = t
					local a = rnd(0, 2 * pi)
					mFrom = W(sin(a) * 700, rnd(420, 560), cos(a) * 700)
					mTo = mFrom + V3(rnd(-300, 300), -rnd(150, 260), rnd(-300, 300))
				end
				if mt then
					local k = (t - mt) / 1.2
					if k >= 1 then
						mt = nil
						mNext = t + rnd(5, 13)
						meteor.Transparency = 1
						meteorTrail.Rate = 0
					else
						local p = mFrom:Lerp(mTo, k)
						meteor.CFrame = CFrame.lookAt(p, mTo)
						meteor.Transparency = 0.1
						meteorTrail.Rate = 70
					end
				end
			end)

			local snowP, dustP, glitP, snowE, dustE, glitE
			section("neve", function()
				snowP = mk(model, V3(200, 1, 200), CF(O + V3(0, 70, 0)), WHITE, SMOOTH, {trans = 1, shadow = false})
				snowE = emit(snowP, {
					Rate = 170, Lifetime = NumberRange.new(6, 8), Speed = NumberRange.new(8, 12),
					EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(12, 12),
					Acceleration = V3(5, 0, 2), Drag = 0.2,
					Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0.4)}),
					Transparency = NumberSequence.new(0.15), RotSpeed = NumberRange.new(-60, 60), Rotation = NumberRange.new(0, 360),
					Color = ColorSequence.new(WHITE), LightEmission = 0.35, LightInfluence = 0.5,
				})
				dustP = mk(model, V3(240, 1, 240), CF(O + V3(0, 3, 0)), WHITE, SMOOTH, {trans = 1, shadow = false})
				dustE = emit(dustP, {
					Texture = SMOKE, Rate = 22, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(1, 3),
					EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10), Acceleration = V3(18, 0, 6), Drag = 0.4,
					Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 14), NumberSequenceKeypoint.new(1, 30)}),
					Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.82), NumberSequenceKeypoint.new(1, 1)}),
					Color = ColorSequence.new(C(225, 240, 255)), LightInfluence = 0.6,
				})
				glitP = mk(model, V3(160, 24, 160), CF(O + V3(0, 12, 0)), WHITE, SMOOTH, {trans = 1, shadow = false})
				glitE = emit(glitP, {
					Texture = SPARK, Rate = 28, Lifetime = NumberRange.new(2.5, 4.5), Speed = NumberRange.new(0.5, 2),
					SpreadAngle = Vector2.new(180, 180), Acceleration = V3(2, 0.4, 1),
					Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 0)}),
					Color = ColorSequence.new(AQUA), LightEmission = 1,
				})
			end)
			onUpdate(function(t, dt, lp)
				if not snowP then return end
				local gust = 0.5 + 0.5 * sin(t * 0.13)
				local g2 = max(0, sin(t * 0.07 + 1.3)) ^ 2
				local pos = rootPart.Position
				snowP.Position = V3(pos.X, O.Y + 70, pos.Z)
				dustP.Position = V3(pos.X, O.Y + 3, pos.Z)
				glitP.Position = V3(pos.X, O.Y + 12, pos.Z)
				local wx = 5 + gust * 10 + g2 * 55
				snowE.Acceleration = V3(wx, 0, 2 + g2 * 14)
				snowE.Rate = 150 + g2 * 360
				dustE.Acceleration = V3(18 + g2 * 60, 0, 6 + g2 * 18)
				dustE.Rate = 18 + g2 * 55
			end)

			section("pegadas", function()
				local pool, idx, side = {}, 0, 1
				for i = 1, 36 do
					local p = mk(model, V3(0.9, 0.08, 1.6), CF(O + V3(0, -50, 0)), C(150, 190, 225), SNOW, {shadow = false, trans = 1})
					pool[i] = {p = p, born = -100}
				end
				local last = nil
				local kickP = mk(model, V3(1, 1, 1), CF(O), WHITE, SMOOTH, {trans = 1, shadow = false})
				local kick = emit(kickP, {
					Rate = 0, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(2, 5),
					SpreadAngle = Vector2.new(60, 60), EmissionDirection = Enum.NormalId.Top, Acceleration = V3(0, -6, 0),
					Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1)}),
					Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)}),
					Color = ColorSequence.new(WHITE),
				})
				local breath
				pcall(function()
					local head = character and character:FindFirstChild("Head")
					if head then
						local att = new("Attachment", {Position = V3(0, -0.2, -0.9)}, head)
						breath = emit(att, {
							Texture = SMOKE, Rate = 0, Lifetime = NumberRange.new(0.9, 1.5), Speed = NumberRange.new(1, 2.4),
							SpreadAngle = Vector2.new(18, 18), Acceleration = V3(0, 1.2, 0),
							Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1.3)}),
							Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1)}),
							Color = ColorSequence.new(WHITE), LightInfluence = 0.5,
						})
					end
				end)
				local nextBreath = 0
				onUpdate(function(t, dt, lp)
					local wpos = rootPart.Position
					if breath and t > nextBreath then
						nextBreath = t + 2.4
						breath:Emit(5)
					end
					if last then
						local mv = wpos - last
						local flat = V3(mv.X, 0, mv.Z)
						local onGround = abs(wpos.Y - O.Y) < 7
						if onGround and flat.Magnitude >= 2.4 and flat.Magnitude < 40 then
							local dir = flat.Unit
							local right = dir:Cross(V3(0, 1, 0))
							side = -side
							local pos = V3(wpos.X, O.Y + 0.1, wpos.Z) + right * (0.9 * side)
							idx = idx % #pool + 1
							local fp = pool[idx]
							fp.p.CFrame = CFrame.lookAt(pos, pos + dir)
							fp.born = t
							kickP.Position = pos
							kick:Emit(3)
							last = wpos
						elseif flat.Magnitude >= 40 then
							last = wpos
						end
					else
						last = wpos
					end
					for _, f in ipairs(pool) do
						local age = t - f.born
						f.p.Transparency = (age > 16) and 1 or clamp01(0.2 + 0.8 * (age / 16) ^ 2)
					end
				end)
			end)

			section("espiritos", function()
				local motes = {}
				for i = 1, 40 do
					local col = (i % 3 == 0) and C(190, 150, 255) or ((i % 3 == 1) and AQUA or C(150, 255, 210))
					local p = ball(model, rnd(0.8, 1.6), O, col, NEON, {shadow = false, trans = 0.15})
					motes[i] = {p = p, x = rnd(-380, 380), z = rnd(-250, 450), y = rnd(5, 28), sp = rnd(0.2, 0.6), ph = rnd(0, 6.28), rad = rnd(6, 20)}
					if i % 8 == 0 then light(p, col, 1.2, 22) end
				end
				onUpdate(function(t)
					for _, m in ipairs(motes) do
						local a = t * m.sp + m.ph
						m.p.CFrame = CF(O + V3(m.x + cos(a) * m.rad, m.y + sin(t * m.sp * 1.7 + m.ph) * 3, m.z + sin(a * 0.8) * m.rad))
						m.p.Transparency = 0.1 + 0.4 * (0.5 + 0.5 * sin(t * 2.2 + m.ph))
					end
				end)
			end)

			local lastT = nil
			return function(t, pos)
				local dt = lastT and min(t - lastT, 0.1) or 0.016
				lastT = t
				local lp = pos - O
				for i, f in ipairs(ups) do
					if f then
						local ok, e = pcall(f, t, dt, lp)
						if not ok then
							ups[i] = false
							warnRG("gelo/animacao:", e)
						end
					end
				end
			end
		end

		local function buildModelId(assetId)
			return function(model, O, r, def)
				local function fallbackFloor()
					mk(model, Vector3.new(400, 2, 400), O + Vector3.new(0, -1, 0), C(60, 60, 60), M.Concrete, {solid = true})
				end

				local objs
				for _ = 1, 3 do
					local ok, res = pcall(function()
						return game:GetObjects("rbxassetid://" .. tostring(assetId))
					end)
					if ok and res and res[1] then objs = res break end
					task.wait(1)
				end
				if not objs then
					warnRG("nao carregou o modelo " .. tostring(assetId))
					fallbackFloor()
					return
				end

				local m = objs[1]
				if not m:IsA("Model") then
					local w = Instance.new("Model")
					m.Parent = w
					m = w
				end
				m.Parent = model

				local parts, lights, n = {}, 0, 0
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanTouch = false
						d.CastShadow = false
						d.Reflectance = 0
						if d:IsA("MeshPart") then
							pcall(function()
								d.RenderFidelity = Enum.RenderFidelity.Performance
								d.CollisionFidelity = Enum.CollisionFidelity.Box
							end)
						end
						parts[#parts + 1] = d
					elseif d:IsA("BaseScript") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")
						or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") or d:IsA("Sound") then
						pcall(function() d:Destroy() end)
					elseif d:IsA("Light") then
						lights = lights + 1
						pcall(function() d.Shadows = false end)
						pcall(function() if d.Range > 20 then d.Range = 20 end end)
						if lights > 4 then pcall(function() d.Enabled = false end) end
					end
					n = n + 1
					if n % 200 == 0 then task.wait() end
				end

				if def and def.scale and def.scale ~= 1 then
					pcall(function() m:ScaleTo(m:GetScale() * def.scale) end)
				end

				if def and def.cullSize then
					local kept = {}
					for _, d in ipairs(parts) do
						local sz = d.Size
						if d.Parent and math.max(sz.X, sz.Y, sz.Z) < def.cullSize and not d.CanCollide
							and not d:FindFirstChildWhichIsA("BasePart") then
							pcall(function() d:Destroy() end)
						else
							kept[#kept + 1] = d
						end
					end
					parts = kept
				end

				task.spawn(function()
					pcall(function()
						game:GetService("ContentProvider"):PreloadAsync(m:GetDescendants())
					end)
				end)

				local minV, maxV
				for _, d in ipairs(parts) do
					if d.Parent and d.Transparency < 0.95 and d.Size.Magnitude < 300 then
						local sz, cf = d.Size, d.CFrame
						local rv, uv, lv = cf.RightVector, cf.UpVector, cf.LookVector
						local ex = (math.abs(rv.X) * sz.X + math.abs(uv.X) * sz.Y + math.abs(lv.X) * sz.Z) / 2
						local ey = (math.abs(rv.Y) * sz.X + math.abs(uv.Y) * sz.Y + math.abs(lv.Y) * sz.Z) / 2
						local ez = (math.abs(rv.Z) * sz.X + math.abs(uv.Z) * sz.Y + math.abs(lv.Z) * sz.Z) / 2
						local pp = cf.Position
						local lo = Vector3.new(pp.X - ex, pp.Y - ey, pp.Z - ez)
						local hi = Vector3.new(pp.X + ex, pp.Y + ey, pp.Z + ez)
						if minV then
							minV = Vector3.new(math.min(minV.X, lo.X), math.min(minV.Y, lo.Y), math.min(minV.Z, lo.Z))
							maxV = Vector3.new(math.max(maxV.X, hi.X), math.max(maxV.Y, hi.Y), math.max(maxV.Z, hi.Z))
						else
							minV, maxV = lo, hi
						end
					end
				end
				if not minV then
					pcall(function() m:PivotTo(CFrame.new(O)) end)
					fallbackFloor()
					return
				end

				local center = (minV + maxV) / 2
				local delta = O - Vector3.new(center.X, minV.Y, center.Z)
				pcall(function() m:PivotTo(m:GetPivot() + delta) end)
				minV, maxV = minV + delta, maxV + delta
				local size = maxV - minV
				warnRG(string.format("garagem: %d partes, %.0f x %.0f x %.0f studs", #parts, size.X, size.Y, size.Z))

				local gx, gz = math.max(size.X, 20), math.max(size.Z, 20)
				local fd = (def and def.frontDir) or Vector3.new(0, 0, -1)
				local fwdIsX = math.abs(fd.X) > 0.5
				local depthF = math.max(fwdIsX and size.X or size.Z, 20)
				local widthF = math.max(fwdIsX and size.Z or size.X, 20)
				local envCF = CFrame.lookAt(O, O + fd)
				local function envPart(sz, lx, ly, lz, color, mat)
					return mk(model, sz, envCF * CFrame.new(lx, ly, lz), color, mat, {shadow = false})
				end

				mk(model, Vector3.new(1900, 4, 1900), O + Vector3.new(0, -2.02, 0), C(82, 140, 70), M.Grass, {solid = true, shadow = false})
				envPart(Vector3.new(widthF * 0.9, 0.2, 45), 0, 0.05, -(depthF / 2 + 22.5), C(150, 150, 150), M.Concrete)
				envPart(Vector3.new(1900, 0.2, 28), 0, 0.05, -(depthF / 2 + 59), C(55, 55, 58), M.Asphalt)
				envPart(Vector3.new(1900, 0.22, 0.6), 0, 0.06, -(depthF / 2 + 59), C(240, 200, 60), M.SmoothPlastic)
				for _ = 1, 14 do
					local ang = r:NextNumber(0, math.pi * 2)
					local dist = r:NextNumber(math.max(gx, gz) / 2 + 25, 260)
					local rel = Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
					if rel:Dot(fd) < depthF / 2 + 30 then
						local h = r:NextNumber(9, 16)
						local tp = Vector3.new(O.X + rel.X, O.Y, O.Z + rel.Z)
						mk(model, Vector3.new(1.6, h, 1.6), tp + Vector3.new(0, h / 2, 0), C(100, 70, 40), M.Wood, {shadow = false})
						ball(model, h * 0.9, tp + Vector3.new(0, h + h * 0.2, 0), C(60, 130, 55), M.Grass, {shadow = false})
					end
				end

				if def then
					local sign = (def.arriveWall == "back") and -1 or 1
					local inset = math.clamp(depthF * 0.12, 3, 6)
					local pos = O + fd * sign * (depthF / 2 - inset) + Vector3.new(0, 5.05, 0) + (def.arriveShift or Vector3.zero)
					def.arriveCF = CFrame.lookAt(pos, pos - fd * sign)
				end
			end
		end

		local DEFS = {
			{
				id = "neon", name = "C-35K Neon", info = "Cidade synthwave: avenida, predios neon, sol listrado, carros voadores, letreiros e lasers, Bar do Rick e monotrilho.", build = buildNeon, stars = 4000,
				light = {Ambient = C(70, 30, 110), OutdoorAmbient = C(90, 40, 140), Brightness = 1.2, ClockTime = 0,
					FogColor = C(40, 10, 70), FogStart = 450, FogEnd = 2200, ExposureCompensation = 0.2},
				atmo = {Density = 0.35, Offset = 0.2, Color = C(255, 80, 200), Decay = C(80, 20, 140), Glare = 0.5, Haze = 1.5},
				bloom = {Intensity = 0.8, Size = 32, Threshold = 0.9},
				cc = {Saturation = 0.25, Contrast = 0.1, TintColor = C(255, 230, 255)},
			},
			{
				id = "desert", name = "K-22 Deserto", info = "Dois sois, verme de areia, TV interdimensional e segredos escondidos.", build = buildDesert, stars = 0,
				light = {Ambient = C(128, 86, 62), OutdoorAmbient = C(170, 118, 84), Brightness = 2.6, ClockTime = 16.6,
					FogColor = C(238, 168, 112), FogStart = 280, FogEnd = 4800, ExposureCompensation = 0.15,
					ColorShift_Top = C(255, 196, 130)},
				atmo = {Density = 0.34, Offset = 0.12, Color = C(255, 176, 100), Decay = C(255, 118, 64), Glare = 1.2, Haze = 2.2},
				bloom = {Intensity = 0.55, Size = 30, Threshold = 0.92},
				cc = {Saturation = 0.28, Contrast = 0.12, TintColor = C(255, 232, 210)},
			},
			{
				id = "ice", name = "G-7 Gelo", info = "Planeta de gelo: aurora, lago congelado, caverna, cabana do Rick, mamute e nevasca.", build = buildIce, stars = 5000,
				light = {Ambient = C(84, 118, 160), OutdoorAmbient = C(104, 146, 196), Brightness = 1.5, ClockTime = 23,
					FogColor = C(120, 170, 225), FogStart = 160, FogEnd = 1500, ExposureCompensation = 0.2,
					ColorShift_Top = C(150, 210, 255)},
				atmo = {Density = 0.3, Offset = 0.1, Color = C(150, 205, 255), Decay = C(60, 110, 190), Glare = 0.3, Haze = 1.6},
				bloom = {Intensity = 0.7, Size = 28, Threshold = 0.95},
				cc = {Saturation = 0.15, Contrast = 0.1, TintColor = C(225, 240, 255)},
			},
			{
				id = "garage", name = "Garagem", info = "A garagem do Rick (modelo do Creator Store).",
				build = buildModelId(89126957082495), stars = 0, daySky = true, preload = true,
				scale = 1.3,
				noGlobalShadows = true, cullSize = 0.4,

				frontDir = Vector3.new(-1, 0, 0), arriveWall = "front", arriveShift = Vector3.new(0, 0, 0),
				light = {Ambient = C(125, 125, 130), OutdoorAmbient = C(145, 145, 155), Brightness = 2, ClockTime = 14,
					FogColor = C(190, 205, 225), FogStart = 600, FogEnd = 2500},
			},
		}

		for i, def in ipairs(DEFS) do
			def.index = i
			def.origin = Vector3.new(i * SPACING, FAR_Y, 0)
			Dim.list[i] = def
		end

		function Dim.arrivalCF(def)
			local O = def.origin
			if def.arriveCF then return def.arriveCF end
			return CFrame.lookAt(O + Vector3.new(0, 5.05, -30), O + Vector3.new(0, 5.05, 0))
		end

		function Dim.ensure(def)
			if def.built and def.model and def.model.Parent then return def end
			if def.building then
				while def.building do task.wait() end
				return def
			end
			def.building = true
			if not folder or not folder.Parent then
				folder = Instance.new("Folder")
				folder.Name = "RickDimensions"
				folder.Parent = workspace
			end
			local model = Instance.new("Model")
			model.Name = "Dim_" .. def.id
			local ok, anim = pcall(def.build, model, def.origin, Random.new(def.index * 977 + 5), def)
			if not ok then warnRG("erro ao montar a dimensao " .. def.name .. ":", anim) end
			def.anim = ok and anim or nil
			model.Parent = folder
			def.model = model
			def.built = true
			def.building = false
			return def
		end

		local function clearFX()
			for _, i in ipairs(fxList) do
				pcall(function() i:Destroy() end)
			end
			fxList = {}
		end

		local function mkfx(class, props)
			local i = Instance.new(class)
			for k, v in pairs(props) do
				pcall(function() i[k] = v end)
			end
			i.Parent = Lighting
			fxList[#fxList + 1] = i
			return i
		end

		local function tweenable(t)
			local out = {}
			for k, v in pairs(t) do
				if typeof(v) == "number" or typeof(v) == "Color3" then out[k] = v end
			end
			return out
		end

		local function snapshot()
			if saved then return end
			saved = { props = {}, hidden = {} }
			for _, k in ipairs(LIGHT_PROPS) do
				local ok, v = pcall(function() return Lighting[k] end)
				if ok then saved.props[k] = v end
			end
			for _, ch in ipairs(Lighting:GetChildren()) do
				for _, cls in ipairs(HIDE_CLASSES) do
					if ch:IsA(cls) then
						saved.hidden[#saved.hidden + 1] = ch
						break
					end
				end
			end
			for _, ch in ipairs(saved.hidden) do
				pcall(function() ch.Parent = nil end)
			end
		end

		local function applyDimension(def)
			snapshot()
			clearFX()
			if not def.daySky then
				mkfx("Sky", {
					SkyboxBk = "", SkyboxDn = "", SkyboxFt = "", SkyboxLf = "", SkyboxRt = "", SkyboxUp = "",
					StarCount = def.stars or 3000, CelestialBodiesShown = false,
				})
			end
			if def.noGlobalShadows then pcall(function() Lighting.GlobalShadows = false end) end
			if def.atmo then mkfx("Atmosphere", def.atmo) end
			if def.bloom then mkfx("BloomEffect", def.bloom) end
			if def.cc then mkfx("ColorCorrectionEffect", def.cc) end
			pcall(function()
				TweenService:Create(Lighting, TweenInfo.new(1.4, Enum.EasingStyle.Sine), tweenable(def.light)):Play()
			end)
		end

		local function restoreWorld(instant)
			clearFX()
			if not saved then return end
			local s = saved
			saved = nil
			local function finish()
				for k, v in pairs(s.props) do
					pcall(function() Lighting[k] = v end)
				end
				for _, ch in ipairs(s.hidden) do
					pcall(function() ch.Parent = Lighting end)
				end
			end
			if instant then
				finish()
			else
				pcall(function()
					TweenService:Create(Lighting, TweenInfo.new(1.2, Enum.EasingStyle.Sine), tweenable(s.props)):Play()
				end)
				for _, ch in ipairs(s.hidden) do
					pcall(function() ch.Parent = Lighting end)
				end
				task.delay(1.3, function()
					for k, v in pairs(s.props) do
						pcall(function() Lighting[k] = v end)
					end
				end)
			end
		end

		function Dim.update()
			local pos = rootPart.Position
			local found = nil
			if pos.Y > 5000 then
				for _, def in ipairs(Dim.list) do
					if def.built and math.abs(pos.Y - def.origin.Y) < 1500
						and Vector3.new(pos.X - def.origin.X, 0, pos.Z - def.origin.Z).Magnitude < 1100 then
						found = def
						break
					end
				end
			end
			if found ~= Dim.current then
				Dim.current = found
				if found then
					applyDimension(found)
				else
					restoreWorld(false)
				end
			end
			if found then
				if pos.Y < found.origin.Y - (found.fall or 250) then
					pcall(function() rootPart.AssemblyLinearVelocity = Vector3.zero end)
					local O = found.origin
					if found.arriveCF then
						rootPart.CFrame = found.arriveCF * CFrame.new(0, 3, -4)
					else
						rootPart.CFrame = CFrame.lookAt(O + Vector3.new(0, 8, -30), O + Vector3.new(0, 8, 0))
					end
					pcall(flashAt, rootPart.Position, 1.4)
				end
				if found.anim then pcall(found.anim, os.clock(), pos) end
			end
		end

		function Dim.destroy()
			Dim.current = nil
			restoreWorld(true)
			if folder then pcall(function() folder:Destroy() end) end
			folder = nil
			for _, def in ipairs(Dim.list) do
				def.built = false
				def.model = nil
				def.anim = nil
			end
		end
	end

	local DIM_CHOICES = {}
	for _, def in ipairs(Dim.list) do
		DIM_CHOICES[#DIM_CHOICES + 1] = { def = def, name = def.name, info = def.info }
	end
	DIM_CHOICES[#DIM_CHOICES + 1] = { def = nil, name = "Mundo real (voltar)", info = "Abre um portal de volta ao lugar de onde voce saiu." }
	local v3Mode = "player"
	local dimSel = 1

	local VARIANT_INFO = {
		[1] = "V1 - portal + entrada",
		[1.5] = "V1.5 - atravessa a parede",
		[2] = "V2 - dois portais livres",
		[3] = "V3 - player ou dimensao",
	}
	local variantMenuOpen = false
	local refreshVariantUI, nameBox
	do
	local VARIANT_LIST = {1, 1.5, 2, 3}
	local VARIANT_SHORT = {[1] = "ENTRADA", [1.5] = "ATRAVESSA", [2] = "2 PORTAIS", [3] = "ALVO"}
	local ACCENT = Config.PortalColor
	local DARK = Color3.fromRGB(14, 26, 17)
	local ON_TXT = Color3.fromRGB(6, 30, 8)
	local WHITE = Color3.new(1, 1, 1)

	local DOME_COLORS = {
		Color3.fromRGB(255, 70, 230),
		Color3.fromRGB(255, 170, 50),
		Color3.fromRGB(110, 215, 255),
	}
	local function dimColor(i)
		return DOME_COLORS[i] or ACCENT
	end
	local function dimTitle(i)
		if i == #DIM_CHOICES then return "MUNDO REAL" end
		return string.upper(DIM_CHOICES[i].name)
	end

	local function smallGlass(f, radius)
		f.BackgroundColor3 = WHITE
		f.BackgroundTransparency = 0.1
		f.BorderSizePixel = 0
		glassGradient(f)
		Instance.new("UICorner", f).CornerRadius = radius or UDim.new(0, 10)
	end

	local function glowStroke(f, thickness)
		local st = Instance.new("UIStroke")
		st.Thickness = thickness
		st.Parent = f
		tintStroke(st, ACCENT, true)
		return st
	end

	local function grad(f, c0, c1, rot)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(c0, c1)
		g.Rotation = rot
		g.Parent = f
		return g
	end

	local function fitText(l, maxSize)
		l.TextScaled = true
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = maxSize
		c.MinTextSize = 5
		c.Parent = l
	end

	local function mkLabel(parent, text, font, size, pos, sz, color, align)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Text = text
		l.Font = font
		l.TextSize = size
		l.Position = pos
		l.Size = sz
		l.TextColor3 = color
		l.TextXAlignment = align or Enum.TextXAlignment.Center
		l.Parent = parent
		return l
	end

	local function pressFx(btn)
		local sc = Instance.new("UIScale", btn)
		btn.MouseButton1Down:Connect(function() TweenService:Create(sc, TweenInfo.new(0.07), {Scale = 0.9}):Play() end)
		btn.MouseButton1Up:Connect(function() TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play() end)
		btn.MouseLeave:Connect(function() TweenService:Create(sc, TweenInfo.new(0.12), {Scale = 1}):Play() end)
	end

	local gunHud = Instance.new("Frame")
	gunHud.Name = "RickGunHud"
	gunHud.AnchorPoint = Vector2.new(1, 1)
	gunHud.Position = UDim2.new(1, -196, 1, -96)
	gunHud.Size = UDim2.fromOffset(120, 210)
	gunHud.BackgroundTransparency = 1
	gunHud.Visible = false
	gunHud.Parent = gui

	local function gp(parent, x, y, w, h, color, radius, z)
		local f = Instance.new("Frame")
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(w, h)
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.ZIndex = z or 1
		f.Parent = parent
		Instance.new("UICorner", f).CornerRadius = radius or UDim.new(0, 6)
		return f
	end

	local grip = gp(gunHud, 38, 112, 44, 98, WHITE, UDim.new(0, 10), 1)
	grad(grip, Color3.fromRGB(232, 234, 232), Color3.fromRGB(150, 153, 150), 0)
	for i = 1, 4 do
		local ln = gp(grip, 9, 34 + i * 10, 26, 2, Color3.fromRGB(110, 112, 110), UDim.new(1, 0), 2)
		ln.BackgroundTransparency = 0.35
	end

	local dimDots = {}
	do
		local n = #DIM_CHOICES
		local startX = (44 - (n * 9 - 3)) / 2
		for i = 1, n do
			dimDots[i] = gp(grip, startX + (i - 1) * 9, 10, 6, 6, Color3.fromRGB(90, 92, 90), UDim.new(1, 0), 2)
		end
	end

	local head = gp(gunHud, 4, 40, 112, 80, WHITE, UDim.new(0, 16), 2)
	grad(head, Color3.fromRGB(250, 250, 247), Color3.fromRGB(184, 187, 184), 90)
	do
		local st = Instance.new("UIStroke")
		st.Thickness = 1.8
		st.Parent = head
		tintStroke(st, ACCENT, true)
	end
	local shine = gp(head, 12, 5, 88, 3, WHITE, UDim.new(1, 0), 3)
	shine.BackgroundTransparency = 0.45

	local glow = gp(gunHud, 34, 4, 52, 52, ACCENT, UDim.new(1, 0), 1)
	glow.BackgroundTransparency = 0.78
	TweenService:Create(glow, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.92}):Play()
	local dome = gp(gunHud, 44, 2, 32, 44, ACCENT, UDim.new(0.5, 0), 3)
	dome.BackgroundTransparency = 0.1
	do
		local st = Instance.new("UIStroke")
		st.Thickness = 1.2
		st.Color = Config.PortalLight
		st.Transparency = 0.3
		st.Parent = dome
	end
	local blob = gp(gunHud, 54, 14, 12, 12, WHITE, UDim.new(1, 0), 4)
	TweenService:Create(blob, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(52, 12), BackgroundTransparency = 0.35}):Play()
	local ring = gp(gunHud, 38, 38, 44, 11, WHITE, UDim.new(1, 0), 5)
	grad(ring, Color3.fromRGB(246, 246, 244), Color3.fromRGB(190, 192, 190), 90)
	local domeBtn = Instance.new("TextButton")
	domeBtn.Name = "RickDomeButton"
	domeBtn.Position = UDim2.fromOffset(36, 0)
	domeBtn.Size = UDim2.fromOffset(48, 50)
	domeBtn.BackgroundTransparency = 1
	domeBtn.Text = ""
	domeBtn.ZIndex = 8
	domeBtn.Parent = gunHud

	local redBtn = Instance.new("TextButton")
	redBtn.Name = "RickModeDisplay"
	redBtn.Position = UDim2.fromOffset(12, 54)
	redBtn.Size = UDim2.fromOffset(96, 30)
	redBtn.BackgroundColor3 = WHITE
	redBtn.BorderSizePixel = 0
	redBtn.AutoButtonColor = false
	redBtn.Text = ""
	redBtn.ZIndex = 4
	redBtn.Parent = gunHud
	Instance.new("UICorner", redBtn).CornerRadius = UDim.new(0, 6)
	grad(redBtn, Color3.fromRGB(240, 60, 60), Color3.fromRGB(165, 10, 10), 90)
	do
		local st = Instance.new("UIStroke")
		st.Thickness = 1.2
		st.Color = Color3.fromRGB(100, 6, 6)
		st.Parent = redBtn
	end
	local redMode = mkLabel(redBtn, "V1", Enum.Font.GothamBlack, 17, UDim2.fromOffset(2, 0), UDim2.new(0, 40, 1, 0), Color3.fromRGB(255, 244, 244))
	fitText(redMode, 17)
	local sep = gp(redBtn, 43, 6, 1, 18, Color3.fromRGB(255, 190, 190), UDim.new(1, 0), 2)
	sep.BackgroundTransparency = 0.5
	local redKind = mkLabel(redBtn, "MODO", Enum.Font.Code, 8, UDim2.fromOffset(48, 3), UDim2.new(1, -52, 0, 10), Color3.fromRGB(255, 205, 205), Enum.TextXAlignment.Left)
	local redInfo = mkLabel(redBtn, "", Enum.Font.GothamBold, 11, UDim2.fromOffset(48, 13), UDim2.new(1, -52, 0, 14), Color3.fromRGB(255, 244, 244), Enum.TextXAlignment.Left)
	fitText(redInfo, 11)

	local dial = Instance.new("TextButton")
	dial.Name = "RickDial"
	dial.AnchorPoint = Vector2.new(0.5, 0.5)
	dial.Position = UDim2.fromOffset(60, 102)
	dial.Size = UDim2.fromOffset(32, 32)
	dial.BackgroundColor3 = WHITE
	dial.BorderSizePixel = 0
	dial.AutoButtonColor = false
	dial.Text = ""
	dial.ZIndex = 6
	dial.Parent = gunHud
	Instance.new("UICorner", dial).CornerRadius = UDim.new(1, 0)
	grad(dial, Color3.fromRGB(176, 176, 176), Color3.fromRGB(116, 116, 116), 90)
	do
		local st = Instance.new("UIStroke")
		st.Thickness = 1.5
		st.Color = Color3.fromRGB(70, 70, 70)
		st.Parent = dial
		local inner = gp(dial, 5, 5, 22, 22, Color3.fromRGB(132, 132, 132), UDim.new(1, 0), 2)
		local ist = Instance.new("UIStroke")
		ist.Thickness = 1
		ist.Color = Color3.fromRGB(96, 96, 96)
		ist.Parent = inner
		local tick = gp(dial, 14.5, 3, 3, 10, WHITE, UDim.new(1, 0), 3)
		tick.Name = "Tick"
	end
	pressFx(dial)

	local dialRot, lastVariant = 0, variant
	local function spinDial(deg)
		dialRot = dialRot + deg
		playSound(Config.SoundDial, 1)
		TweenService:Create(dial, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Rotation = dialRot}):Play()
	end

	local nameTag = Instance.new("Frame")
	nameTag.Name = "RickNameTag"
	nameTag.AnchorPoint = Vector2.new(1, 0)
	nameTag.Position = UDim2.fromOffset(34, 140)
	nameTag.Size = UDim2.fromOffset(132, 36)
	nameTag.Visible = false
	nameTag.Parent = gunHud
	smallGlass(nameTag, UDim.new(0, 10))
	glowStroke(nameTag, 1.5)

	nameBox = Instance.new("TextBox")
	nameBox.Name = "PlayerName"
	nameBox.Position = UDim2.fromOffset(6, 5)
	nameBox.Size = UDim2.fromOffset(86, 26)
	nameBox.BackgroundColor3 = DARK
	nameBox.BorderSizePixel = 0
	nameBox.ClearTextOnFocus = false
	nameBox.Text = ""
	nameBox.PlaceholderText = "nome do player"
	nameBox.PlaceholderColor3 = Theme.Muted
	nameBox.TextColor3 = Theme.Text
	nameBox.Font = Enum.Font.Gotham
	nameBox.TextSize = 12
	nameBox.TextXAlignment = Enum.TextXAlignment.Left
	nameBox.ClipsDescendants = true
	nameBox.Parent = nameTag
	Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 7)
	do
		local pad = Instance.new("UIPadding", nameBox)
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 6)
	end
	local okBtn = Instance.new("TextButton")
	okBtn.Name = "ConfirmPlayer"
	okBtn.Position = UDim2.fromOffset(96, 5)
	okBtn.Size = UDim2.fromOffset(30, 26)
	okBtn.BackgroundColor3 = ACCENT
	okBtn.BorderSizePixel = 0
	okBtn.AutoButtonColor = true
	okBtn.Text = "OK"
	okBtn.Font = Enum.Font.GothamBlack
	okBtn.TextSize = 12
	okBtn.TextColor3 = ON_TXT
	okBtn.Parent = nameTag
	Instance.new("UICorner", okBtn).CornerRadius = UDim.new(0, 7)

	for _, l in ipairs({redMode, redKind, redInfo}) do UIAnim.watchText(l) end
	setStatus = function() end

	function refreshVariantUI()
		local isV3 = variant == 3
		local isDim = v3Mode == "dim"
		gunHud.Visible = (isEquipped == true)
		redMode.Text = "V" .. tostring(variant)
		if isV3 then
			if isDim then
				redKind.Text = "DIMENSAO"
				redInfo.Text = dimTitle(dimSel)
			else
				redKind.Text = "PLAYER"
				redInfo.Text = targetPlayer and string.upper(targetPlayer.DisplayName) or "NENHUM"
			end
		else
			redKind.Text = "MODO"
			redInfo.Text = VARIANT_SHORT[variant] or ""
		end
		local domeColor = (isV3 and isDim) and dimColor(dimSel) or ACCENT
		TweenService:Create(dome, TweenInfo.new(0.35), {BackgroundColor3 = domeColor}):Play()
		TweenService:Create(glow, TweenInfo.new(0.35), {BackgroundColor3 = domeColor}):Play()
		for i, d in ipairs(dimDots) do
			d.BackgroundColor3 = (isV3 and i == dimSel) and dimColor(i) or Color3.fromRGB(90, 92, 90)
		end
		nameTag.Visible = (isEquipped == true) and isV3 and not isDim
		if variant ~= lastVariant then
			lastVariant = variant
			spinDial(60)
		end
	end

	local function setVariant(n)
		if variant ~= n then
			variant = n
			closeAllPortals()
		end
		nextSlot = 1
		variantMenuOpen = false
		pcall(function() nameBox:ReleaseFocus() end)
		refreshVariantUI()
	end

	local function confirmTarget()
		local p, why = resolvePlayer(nameBox.Text)
		if p then
			targetPlayer = p
			nameBox.Text = p.Name
			setStatus("Selecionado: " .. p.DisplayName .. " (@" .. p.Name .. ")", true)
		else
			targetPlayer = nil
			setStatus(why or "Player nao encontrado", false)
		end
		refreshVariantUI()
	end

	local function nextMode()
		local idx = 1
		for i, v in ipairs(VARIANT_LIST) do
			if v == variant then idx = i end
		end
		local n = VARIANT_LIST[idx % #VARIANT_LIST + 1]
		setVariant(n)
		setStatus(VARIANT_INFO[n], true)
	end

	local function stepDim(dir)
		if variant ~= 3 then
			setStatus("Dimensoes so na V3 (toque na caixa vermelha)", false)
			return
		end
		v3Mode = "dim"
		dimSel = dimSel + dir
		if dimSel < 1 then dimSel = #DIM_CHOICES end
		if dimSel > #DIM_CHOICES then dimSel = 1 end
		pcall(function() nameBox:ReleaseFocus() end)
		spinDial(dir * 90)
		setStatus(DIM_CHOICES[dimSel].info, true)
		refreshVariantUI()
		local pre = DIM_CHOICES[dimSel].def
		if pre and pre.preload then task.spawn(Dim.ensure, pre) end
	end

	local function toggleDest()
		if variant ~= 3 then
			setStatus("Destino so na V3 (toque na caixa vermelha)", false)
			return
		end
		if v3Mode == "dim" then
			v3Mode = "player"
			setStatus(targetPlayer and ("Selecionado: " .. targetPlayer.DisplayName) or "Digite o nome no cabo e toque em OK", targetPlayer ~= nil)
		else
			v3Mode = "dim"
			setStatus(DIM_CHOICES[dimSel].info, true)
		end
		pcall(function() nameBox:ReleaseFocus() end)
		refreshVariantUI()
	end

	redBtn.MouseButton1Click:Connect(nextMode)
	dial.MouseButton1Click:Connect(function() stepDim(1) end)
	domeBtn.MouseButton1Click:Connect(toggleDest)
	pressFx(redBtn)
	okBtn.MouseButton1Click:Connect(confirmTarget)
	nameBox.FocusLost:Connect(function(enter)
		if enter then confirmTarget() end
	end)
	track(Players.PlayerRemoving:Connect(function(p)
		if p == targetPlayer then
			targetPlayer = nil
			setStatus("O player saiu do jogo", false)
			refreshVariantUI()
		end
	end))
	refreshVariantUI()
	end

	local hotbarFrame = Instance.new("Frame")
	hotbarFrame.Size = UDim2.fromOffset(38, 40)
	hotbarFrame.Position = UDim2.new(1, -98, 1, -72)
	hotbarFrame.BackgroundTransparency = 1
	hotbarFrame.Parent = hotbarGui

	local slotBtn = Instance.new("TextButton")
	slotBtn.Name = "Slot_RickPortalGun"
	slotBtn.Size = UDim2.fromOffset(32, 32)
	slotBtn.Position = UDim2.fromOffset(4, 4)
	slotBtn.BackgroundColor3 = Color3.fromRGB(12, 22, 14)
	slotBtn.BorderSizePixel = 0
	slotBtn.Text = ""
	slotBtn.AutoButtonColor = false
	slotBtn.Parent = hotbarFrame
	Instance.new("UICorner", slotBtn).CornerRadius = UDim.new(0, 10)
	local slotStroke = Instance.new("UIStroke")
	slotStroke.Thickness = 2
	slotStroke.Parent = slotBtn
	tintStroke(slotStroke, Config.PortalColor, true)
	local slotIcon = Instance.new("TextLabel")
	slotIcon.Size = UDim2.fromScale(1, 1)
	slotIcon.BackgroundTransparency = 1
	slotIcon.Text = "🟢"
	slotIcon.TextSize = 18
	slotIcon.Parent = slotBtn
	local selectedFrame = Instance.new("Frame")
	selectedFrame.Size = UDim2.fromScale(1, 1)
	selectedFrame.BackgroundTransparency = 1
	selectedFrame.Visible = false
	selectedFrame.Parent = slotBtn
	local selStroke = Instance.new("UIStroke")
	selStroke.Color = Color3.new(1, 1, 1)
	selStroke.Thickness = 2.5
	selStroke.Parent = selectedFrame
	Instance.new("UICorner", selectedFrame).CornerRadius = UDim.new(0, 10)

	slotBtn.MouseEnter:Connect(function()
		TweenService:Create(slotBtn, TweenInfo.new(0.12), {Size = UDim2.fromOffset(34, 34)}):Play()
	end)
	slotBtn.MouseLeave:Connect(function()
		TweenService:Create(slotBtn, TweenInfo.new(0.12), {Size = UDim2.fromOffset(32, 32)}):Play()
	end)
	slotBtn.MouseButton1Click:Connect(function()
		pcall(function()
			if tool.Parent == character then
				humanoid:UnequipTools()
			else
				humanoid:EquipTool(tool)
			end
		end)
	end)

	local flashFrame = Instance.new("Frame")
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.BackgroundColor3 = Config.PortalLight
	flashFrame.BackgroundTransparency = 1
	flashFrame.BorderSizePixel = 0
	flashFrame.Parent = flashGui
	local function screenFlash()
		flashFrame.BackgroundTransparency = 0.45
		TweenService:Create(flashFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
	end

	local function zoneOf(P, pos, tight)
		local portal = P.model:FindFirstChild("Portal")
		if not portal then return false, nil end
		local cf = portal.CFrame
		local lp = cf:PointToObjectSpace(pos)
		local horizontal = math.abs(cf.LookVector.Y) > 0.7
		local front = horizontal and 4.0 or 2.3
		local margin = 0.3
		if not tight then
			front = front + 1.2
			margin = 1.2
		end
		local inside = lp.Z > -front and lp.Z < 1.2 and inOpening(lp, portal.Size.X / 2, portal.Size.Y / 2, margin)
		return inside, lp
	end

	local SCALE_NAMES = {"BodyWidthScale", "BodyHeightScale", "BodyDepthScale"}
	local baseScales = nil
	local scaleTweens = {}
	local scaleToken = 0
	local passing = false
	local fovBase, fovTween = nil, nil

	local function getScaleValues()
		local t = {}
		for _, n in ipairs(SCALE_NAMES) do
			local v = humanoid:FindFirstChild(n)
			if not (v and v:IsA("NumberValue")) then return nil end
			t[#t + 1] = v
		end
		return t
	end

	local function stopScaleTweens()
		for _, tw in ipairs(scaleTweens) do pcall(function() tw:Cancel() end) end
		scaleTweens = {}
	end

	local function restoreScale()
		scaleToken = scaleToken + 1
		stopScaleTweens()
		local vals = getScaleValues()
		if vals and baseScales then
			for i, v in ipairs(vals) do v.Value = baseScales[i] end
		end
		baseScales = nil
	end

	local function applyScale(mult, info)
		local vals = getScaleValues()
		if not vals then return end
		if not baseScales then baseScales = {vals[1].Value, vals[2].Value, vals[3].Value} end
		scaleToken = scaleToken + 1
		stopScaleTweens()
		local m = {mult.X, mult.Y, mult.Z}
		for i, v in ipairs(vals) do
			if info then
				local tw = TweenService:Create(v, info, {Value = baseScales[i] * m[i]})
				scaleTweens[#scaleTweens + 1] = tw
				tw:Play()
			else
				v.Value = baseScales[i] * m[i]
			end
		end
	end

	local function fovPunch()
		if Config.ElasticFOV <= 0 or not camera then return end
		if not fovBase then fovBase = camera.FieldOfView end
		if fovTween then pcall(function() fovTween:Cancel() end) end
		local base = fovBase
		camera.FieldOfView = math.clamp(base + Config.ElasticFOV, 1, 120)
		local tw = TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {FieldOfView = base})
		fovTween = tw
		tw.Completed:Connect(function()
			if fovTween == tw then fovTween = nil; fovBase = nil end
		end)
		tw:Play()
	end

	local function wobblePortal(P, isExit)
		if not (P and P.model and P.model.Parent) then return end
		local outer = P.model:FindFirstChild("OuterRing")
		local core = P.model:FindFirstChild("PortalCore")
		local portal = P.model:FindFirstChild("Portal")

		if outer then
			for _, e in ipairs(outer:GetChildren()) do
				if e:IsA("ParticleEmitter") then pcall(function() e:Emit(e.Name == "EdgeSparks" and 26 or 8) end) end
			end
		end

		if not Config.PortalBoing then return end
		if os.clock() - (P.opened or 0) < 0.9 then return end

		P.boingId = (P.boingId or 0) + 1
		local id = P.boingId
		local amp = isExit and Config.PortalBoingExit or Config.PortalBoingEnter

		local baseSize = P.size or Config.PortalSize
		local layers = {
			{ part = outer, size = baseSize, step = 0 },
			{ part = core, size = baseSize * Vector3.new(0.88, 0.88, 0.55), step = 1 },
			{ part = portal, size = baseSize * Vector3.new(0.88, 0.88, 0.5), step = 2 },
		}
		local freq, damp = Config.PortalBoingFrequency, Config.PortalBoingDamping
		local jelly = Config.PortalBoingJelly or 0
		local jelFreq = Config.PortalBoingJellyFreq or 1.45
		local gap = Config.PortalBoingCascade or 0
		task.spawn(function()
			local t0 = os.clock()
			while Z.alive and P.boingId == id and P.model.Parent do
				local t = os.clock() - t0
				local done = t >= Config.PortalBoingDuration + gap * 2
				for _, L in ipairs(layers) do
					local part = L.part
					if part and part.Parent then
						local sx, sy = 1, 1
						local tl = t - L.step * gap
						if not done and tl > 0 then

							local u = amp * math.exp(-damp * tl) * math.cos(freq * tl * math.pi * 2)
							local j = jelly * math.abs(amp) * math.exp(-damp * 0.85 * tl) * math.sin(freq * jelFreq * tl * math.pi * 2)
							sx, sy = 1 + u + j, 1 + u - j
						end
						part.Size = Vector3.new(L.size.X * sx, L.size.Y * sy, L.size.Z)
					end
				end
				if done then break end
				RunService.Heartbeat:Wait()
			end
		end)
	end

	local PortalWalk = {
		Clones = {},
		Disabled = {},
		Hidden = {},
		PrevPos = nil,
		CharParts = {},
		CharPartsT = 0,
	}

	local Rig = {type = "Unknown", set = {}, list = {}, stamp = -1, kids = {}, prevLTM = {}, sevGen = {}}
	local Severed = {}
	Rig.sevList = {}
	local Regrowing = {}
	local SeverImmune = {}
	local SEVER_HIDE_BIND = "RickPortalSeverHide"
	function Rig.kidsOf(part)
		local list = Rig.kids[part]
		if not list then
			list = {}
			for _, d in ipairs(part:GetDescendants()) do
				if d:IsA("BasePart") then list[#list + 1] = d end
			end
			Rig.kids[part] = list
		end
		return list
	end

	function Rig.resetLTM(part)
		local function restore(inst)
			local v = Rig.prevLTM[inst]
			Rig.prevLTM[inst] = nil
			pcall(function() inst.LocalTransparencyModifier = v or 0 end)
		end
		restore(part)
		local k = Rig.kids[part]
		if k then
			for _, c in ipairs(k) do
				if c.Parent then restore(c) else Rig.prevLTM[c] = nil end
			end
		end
		Rig.kids[part] = nil
	end

	pcall(function() RunService:UnbindFromRenderStep(SEVER_HIDE_BIND) end)
	RunService:BindToRenderStep(SEVER_HIDE_BIND, Enum.RenderPriority.Last.Value, function()
		if not Z.alive then return end
		for part in pairs(Severed) do
			if part.Parent then
				local alpha = Severed[part]
				local v = (type(alpha) == "number") and alpha or 1
				if Rig.prevLTM[part] == nil then

					Rig.prevLTM[part] = PortalWalk.Hidden[part] and 0 or part.LocalTransparencyModifier
				end
				part.LocalTransparencyModifier = v
				for _, c in ipairs(Rig.kidsOf(part)) do
					if c.Parent then
						if Rig.prevLTM[c] == nil then
							Rig.prevLTM[c] = PortalWalk.Hidden[c] and 0 or c.LocalTransparencyModifier
						end
						c.LocalTransparencyModifier = v
					end
				end
			else
				Severed[part] = nil
				Rig.kids[part] = nil
				Rig.prevLTM[part] = nil
			end
		end
	end)

	local function releaseSevered()
		for _, stop in pairs(Regrowing) do pcall(stop) end
		Regrowing = {}
		pcall(function() RunService:UnbindFromRenderStep(SEVER_HIDE_BIND) end)
		for part in pairs(Severed) do
			if part.Parent then Rig.resetLTM(part) end
		end
		Severed = {}
		Rig.sevList = {}
		Rig.kids = {}
		Rig.prevLTM = {}
	end

	local PORTAL_CLONE_JUNK = {"Script", "LocalScript", "ModuleScript", "Sound", "ParticleEmitter", "Trail", "Beam", "Highlight", "BillboardGui", "ForceField", "Fire", "Smoke", "Sparkles", "PointLight", "SpotLight", "SurfaceLight", "BodyMover", "VectorForce", "Animator"}

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

	local function releasePortalWalk()
		restoreCollisions(nil)
		unhideBody()
		for model in pairs(PortalWalk.Clones) do
			destroyPortalClone(model)
		end
		PortalWalk.PrevPos = nil
	end

	local CAM_PRE_BIND = "RickPortalCamSlidePre"
	local CAM_POST_BIND = "RickPortalCamSlidePost"
	local camSlide = nil

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
		return TweenService:GetValue(a, Config.CamSlideStyle, Config.CamSlideDirection)
	end

	local function rotateAbout(cf, pivot, yaw)
		return CFrame.new(pivot) * CFrame.Angles(0, yaw, 0) * CFrame.new(-pivot) * cf
	end

	local function stopCamSlide()
		local s = camSlide
		camSlide = nil
		pcall(function() RunService:UnbindFromRenderStep(CAM_PRE_BIND) end)
		pcall(function() RunService:UnbindFromRenderStep(CAM_POST_BIND) end)
		if s and s.dirty then
			local c = workspace.CurrentCamera
			if c then pcall(function() c.CFrame = s.real end) end
		end
	end

	local function startCamSlide(realNew, visualOld, pivot, dur)
		if not Config.CamSlide then return end
		dur = math.max(dur or Config.CamSlideDuration, 0.05)

		pcall(function() RunService:UnbindFromRenderStep(CAM_PRE_BIND) end)
		pcall(function() RunService:UnbindFromRenderStep(CAM_POST_BIND) end)

		local yawOff = wrapAngle(camYaw(visualOld) - camYaw(realNew))
		local rotated = rotateAbout(realNew, pivot, yawOff)
		local posOff = visualOld.Position - rotated.Position

		local state = {real = realNew, posOff = posOff, yawOff = yawOff, t0 = os.clock(), dur = dur, dirty = true}
		camSlide = state

		RunService:BindToRenderStep(CAM_PRE_BIND, Enum.RenderPriority.Camera.Value - 1, function()
			local c = workspace.CurrentCamera
			if camSlide == state and c and state.dirty then
				c.CFrame = state.real
			end
		end)

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

	local function crossPortal(fromP, toP, fromCF, toCF)
		local rootCF = rootPart.CFrame
		local newCF = toCF * (FLIP * fromCF:ToObjectSpace(rootCF))
		local newPos = newCF.Position

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

		local v = rootPart.AssemblyLinearVelocity
		local nv = toCF:VectorToWorldSpace(FLIP:VectorToWorldSpace(fromCF:VectorToObjectSpace(v)))
		local out = toCF.LookVector
		local along = nv:Dot(out)
		if along < Config.MinExitSpeed then
			nv = nv + out * (Config.MinExitSpeed - along)
		end
		if not isFiniteVec3(newPos) or not isFiniteVec3(nv) then return end

		local T = toCF * FLIP * fromCF:Inverse()
		local visualOld = camera.CFrame
		local realOld = camSlide and camSlide.real or visualOld
		local realNew = T * realOld
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CFrame = realNew
			pcall(startCamSlide, realNew, visualOld, newPos, Config.CamSlideDuration)
		end

		rootPart.CFrame = newCF
		rootPart.AssemblyLinearVelocity = nv
		PortalWalk.PrevPos = newPos

		State.lastActivity = os.clock()
		playSound(Config.SoundTeleport, 1.1, rootPart)
		Z.fala.dizer("tp")
		State.mortyEvent("onTeleport", fromCF.Position, toCF.Position)
		if Config.Elastic then
			pcall(wobblePortal, fromP, false)
			pcall(wobblePortal, toP, true)
		end
	end

	local function checkPortalTouch()
		if not rootPart or not rootPart.Parent then return end

		local rootPos = rootPart.Position
		local prevPos = PortalWalk.PrevPos or rootPos
		PortalWalk.PrevPos = rootPos

		local a, b = entrance, exitP
		local aPart = a and a.model.Parent and a.model:FindFirstChild("Portal")
		local bPart = b and b.model.Parent and b.model:FindFirstChild("Portal")
		if not (aPart and bPart) or humanoid.Health <= 0 then
			if next(PortalWalk.Disabled) or next(PortalWalk.Clones) or next(PortalWalk.Hidden) then
				releasePortalWalk()
			end
			return
		end

		local links = {
			{P = a, part = aPart, otherP = b, otherPart = bPart},
			{P = b, part = bPart, otherP = a, otherPart = aPart},
		}

		if (rootPos - prevPos).Magnitude < Config.MaxStep and not humanoid.SeatPart then
			for _, l in ipairs(links) do
				local fromCF = l.part.CFrame
				local zPrev = fromCF:PointToObjectSpace(prevPos).Z
				local zNow = fromCF:PointToObjectSpace(rootPos).Z
				if zPrev < 0 and zNow >= 0 then
					local t = zPrev / (zPrev - zNow)
					local hit = fromCF:PointToObjectSpace(prevPos:Lerp(rootPos, t))
					if inOpening(hit, l.part.Size.X / 2, l.part.Size.Y / 2, 0.5) then
						crossPortal(l.P, l.otherP, fromCF, l.otherPart.CFrame)
						rootPos = rootPart.Position
						break
					end
				end
			end
		end

		local nearAny = (rootPos - aPart.Position).Magnitude < 22 or (rootPos - bPart.Position).Magnitude < 22
		if not nearAny then
			if next(PortalWalk.Disabled) or next(PortalWalk.Clones) or next(PortalWalk.Hidden) then
				restoreCollisions(nil)
				unhideBody()
				for model in pairs(PortalWalk.Clones) do
					destroyPortalClone(model)
				end
			end
			return
		end

		local wantDisabled = {}
		local hideFrom = nil

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = {character}
		local standing = workspace:Raycast(rootPos, Vector3.new(0, -5, 0), rayParams)
		local standingPart = standing and standing.Instance

		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = {character, a.model, b.model}
		for _, c in pairs(PortalWalk.Clones) do
			table.insert(ignore, c.model)
		end
		overlap.FilterDescendantsInstances = ignore

		for _, l in ipairs(links) do
			local cf = l.part.CFrame
			local halfW, halfH = l.part.Size.X / 2, l.part.Size.Y / 2
			local lp = cf:PointToObjectSpace(rootPos)

			if lp.Z > -Config.ZoneFront and lp.Z < Config.ZoneBack and inOpening(lp, halfW, halfH, 0) then
				local isFloorOrCeil = math.abs(cf.LookVector.Y) > 0.7
				local boxCF = cf * CFrame.new(0, 0, 1)
				local boxSize = Vector3.new(halfW * 2 + 2, halfH * 2 + 2, 4)
				for _, p in ipairs(workspace:GetPartBoundsInBox(boxCF, boxSize, overlap)) do
					if p.CanCollide or PortalWalk.Disabled[p] then
						if isFloorOrCeil or p ~= standingPart then
							wantDisabled[p] = true
						end
					end
				end
			end

			local inCloneZone = lp.Z > -3.5 and lp.Z < 3.5 and inOpening(lp, halfW, halfH, Config.CloneZoneMargin)
			if inCloneZone then
				hideFrom = hideFrom or cf
				local c = PortalWalk.Clones[l.P.model]
				if not c then
					c = createPortalClone()
					PortalWalk.Clones[l.P.model] = c
				end
				if c then
					local toCF = l.otherPart.CFrame
					for _, pr in ipairs(c.pairs) do
						local gp, op = pr.gp, pr.op
						if gp.Parent and op.Parent then
							local rel = cf:ToObjectSpace(op.CFrame)
							gp.CFrame = toCF * FLIP * rel
							local visible = rel.Position.Z > -0.35 and not Severed[op]
							gp.Transparency = visible and pr.trans or 1
							for _, d in ipairs(pr.decals) do
								d[1].Transparency = visible and d[2] or 1
							end
						end
					end
				end
			else
				destroyPortalClone(l.P.model)
			end
		end

		for p in pairs(wantDisabled) do
			if not PortalWalk.Disabled[p] and p.Parent then
				PortalWalk.Disabled[p] = true
				p.CanCollide = false
			end
		end
		restoreCollisions(wantDisabled)

		if Config.HideInsidePart and hideFrom then
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

	local OffHand = {swapped = false, weld = nil, part0 = nil, c0 = nil, shoulder = nil, sc0 = nil, rot = nil, alpha = 0}

	local function findHandParts()
		local r = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		local l = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
		return r, l
	end

	local function findGripWeld()
		for _, d in ipairs(character:GetDescendants()) do
			if d.Name == "RightGrip" and d:IsA("JointInstance") and d.Part1 == handle then
				return d
			end
		end
		return nil
	end

	local function findLeftShoulder()
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("Motor6D") and d.Part1 and (d.Part1.Name == "LeftUpperArm" or d.Part1.Name == "Left Arm") then
				return d
			end
		end
		return nil
	end

	local function restoreOffHand()
		local O = OffHand
		if O.weld and O.weld.Parent and O.part0 and O.part0.Parent then
			pcall(function()
				O.weld.Part0 = O.part0
				O.weld.C0 = O.c0
			end)
		end
		if O.shoulder and O.shoulder.Parent and O.sc0 then
			pcall(function() O.shoulder.C0 = O.sc0 end)
		end
		O.swapped, O.weld, O.part0, O.c0 = false, nil, nil, nil
		O.shoulder, O.sc0, O.rot, O.alpha = nil, nil, nil, 0
	end

	local function updateOffHand(dt)
		if not Z.alive then return end
		local O = OffHand
		local rHand, lHand = findHandParts()

		if rHand and lHand and Severed[rHand] ~= nil and Severed[lHand] ~= nil then
			if tool.Parent == character then
				restoreOffHand()
				pcall(function() tool.Parent = backpack end)
				setStatus("Sem bracos pra segurar a arma", false)
				playSound(Config.SoundInvalid, 1.1, rootPart)
			end
			return
		end

		local want = tool.Parent == character and humanoid.Health > 0
			and rHand ~= nil and lHand ~= nil
			and Severed[rHand] ~= nil and Severed[lHand] == nil

		if want and not O.swapped then
			local w = findGripWeld()
			if not w then return end
			O.weld, O.part0, O.c0 = w, w.Part0, w.C0
			w.Part0 = lHand

			local sh = findLeftShoulder()
			if sh then
				O.shoulder = sh
				O.sc0 = sh.C0
				local h = sh.C1:Inverse().Position
				local f = sh.C0:VectorToObjectSpace(Vector3.new(0, 0, -1))
				if h.Magnitude > 0.05 and f.Magnitude > 0.5 then
					local hu, fu = h.Unit, f.Unit
					local axis = hu:Cross(fu)
					if axis.Magnitude > 1e-3 then
						O.rot = CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(hu:Dot(fu), -1, 1)))
					end
				end
			end
			O.swapped = true
			O.alpha = 0
		end

		if not O.swapped then return end

		if not want or not (O.weld and O.weld.Parent) then
			restoreOffHand()
			return
		end

		O.alpha = math.min(O.alpha + dt * 4, 1)
		if O.shoulder and O.shoulder.Parent and O.rot then
			O.shoulder.C0 = O.sc0 * CFrame.new():Lerp(O.rot, O.alpha)
		end
	end

	track(RunService.RenderStepped:Connect(function(dt)
		pcall(updateOffHand, dt)
	end))

	local ArmAim = {joints = nil, dir = {}}
	local ARM_PARTS = {
		right = {"RightUpperArm", "RightLowerArm", "RightHand", "Right Arm"},
		left = {"LeftUpperArm", "LeftLowerArm", "LeftHand", "Left Arm"},
	}
	local DOWN = Vector3.new(0, -1, 0)
	local FORWARD = Vector3.new(0, 0, -1)

	local function collectArmJoints()
		local J = {right = {extra = {}}, left = {extra = {}}}
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("Motor6D") and d.Part0 and d.Part1 then
				local n = d.Part1.Name
				for side, names in pairs(ARM_PARTS) do
					for i, nm in ipairs(names) do
						if n == nm then
							if i == 1 or i == 4 then
								if not J[side].shoulder then J[side].shoulder = d end
							else
								table.insert(J[side].extra, d)
							end
						end
					end
				end
			end
		end
		return J
	end

	local function restoreArmAim()
		ArmAim.joints = nil
		ArmAim.dir = {}
	end

	local function stopHoldAnim()
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then return end
		for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
			local nm = string.lower((t.Animation and t.Animation.Name) or t.Name or "")
			if string.find(nm, "tool", 1, true) then
				pcall(function() t:Stop(0) end)
			end
		end
	end

	local function clampToCone(d, maxA)
		local ang = math.acos(math.clamp(d:Dot(FORWARD), -1, 1))
		if ang <= maxA then return d end
		local axis = FORWARD:Cross(d)
		if axis.Magnitude < 1e-4 then return FORWARD end
		return CFrame.fromAxisAngle(axis.Unit, maxA):VectorToWorldSpace(FORWARD)
	end

	local function rotationFromDown(d)
		local axis = DOWN:Cross(d)
		local dp = DOWN:Dot(d)
		if axis.Magnitude < 1e-4 then
			if dp > 0 then return CFrame.new() end
			return CFrame.Angles(math.pi, 0, 0)
		end
		return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(dp, -1, 1)))
	end

	local function updateArmAim(dt)
		local A = ArmAim
		local rHand, lHand = findHandParts()

		local side = nil
		if Config.ArmAim and Z.alive and tool.Parent == character and humanoid.Health > 0 then
			if OffHand.swapped then
				if lHand and Severed[lHand] == nil then side = "left" end
			elseif rHand and Severed[rHand] == nil then
				side = "right"
			end
		end
		if not side then
			if A.joints then restoreArmAim() end
			return
		end
		if Config.HideHoldAnim then stopHoldAnim() end
		if not A.joints then A.joints = collectArmJoints() end

		local j = A.joints[side]
		local sh = j.shoulder
		if not (sh and sh.Parent and sh.Part0) then return end

		local maxA = math.rad(Config.ArmAimMaxAngle)
		local target = clampToCone(sh.Part0.CFrame:VectorToObjectSpace(camera.CFrame.LookVector), maxA)
		local cur = A.dir[side]
		if cur then
			cur = cur:Lerp(target, math.min(1, dt * Config.ArmAimSmooth))
			cur = (cur.Magnitude > 1e-3) and cur.Unit or target
		else
			cur = target
		end
		A.dir[side] = cur

		local ref = sh.C0
		if side == "left" and OffHand.swapped and OffHand.shoulder == sh and OffHand.sc0 then
			ref = OffHand.sc0
		end
		local base = ref - ref.Position
		sh.Transform = sh.C0:Inverse() * CFrame.new(ref.Position) * rotationFromDown(cur) * base
		for _, m in ipairs(j.extra) do
			if m.Parent then m.Transform = CFrame.new() end
		end
	end

	function Rig.ragdollStep(e, dt, g, damp, worldOf)
		local jt = e.j
		local p0 = jt.Part0
		local J = (worldOf[p0] or p0.CFrame) * jt.C0
		local Jpos = J.Position
		local Jrot = J - Jpos
		local c1inv = jt.C1:Inverse()
		local aj = c1inv.Position
		local len = aj.Magnitude
		if len < 0.05 then
			aj = Vector3.new(0, -1, 0)
			len = 0.5
		end
		local a0 = Jrot * aj.Unit

		local d = e.d
		if not d then
			local cur = e.p.Position - Jpos
			d = (cur.Magnitude > 0.05) and cur.Unit or a0
			e.dv = Vector3.zero
			e.pp, e.ppp = Jpos, Jpos
		end

		local acc = (Jpos - 2 * e.pp + e.ppp) / (dt * dt)
		if acc.Magnitude > 300 then acc = acc.Unit * 300 end
		e.ppp, e.pp = e.pp, Jpos

		local L = math.max(len * (Config.SeverRagdollLength or 1.6), 0.6)
		local force = g - acc
		local perp = force - force:Dot(d) * d
		local dv = e.dv + perp / L * dt
		dv = dv * math.max(0, 1 - damp * dt)
		d = d + dv * dt
		d = (d.Magnitude > 1e-3) and d.Unit or a0
		dv = dv - dv:Dot(d) * d

		local maxA = math.rad(Config.SeverRagdollMaxAngle or 110)
		if math.acos(math.clamp(d:Dot(a0), -1, 1)) > maxA then
			local ax = a0:Cross(d)
			if ax.Magnitude > 1e-4 then
				d = CFrame.fromAxisAngle(ax.Unit, maxA) * a0
				dv = Vector3.zero
			end
		end
		e.d, e.dv = d, dv

		local axis = a0:Cross(d)
		local R
		if axis.Magnitude < 1e-4 then
			if a0:Dot(d) > 0 then
				R = CFrame.new()
			else
				local pv = (math.abs(a0.X) < 0.9) and Vector3.xAxis or Vector3.yAxis
				R = CFrame.fromAxisAngle(a0:Cross(pv).Unit, math.pi)
			end
		else
			R = CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(a0:Dot(d), -1, 1)))
		end
		local tr = Jrot:Inverse() * R * Jrot
		jt.Transform = tr
		worldOf[e.p] = J * tr * c1inv
	end

	track(RunService.Stepped:Connect(function(_, dt)
		local list = Rig.sevList
		if #list == 0 then return end
		dt = math.clamp(dt or 1 / 60, 1 / 240, 1 / 20)
		local g = Vector3.new(0, -workspace.Gravity, 0) * (Config.SeverRagdollGravity or 0.6)
		local damp = Config.SeverRagdollDamping or 3
		local worldOf = {}
		local i = 1
		while i <= #list do
			local e = list[i]
			if Severed[e.p] == nil or not e.p.Parent or not e.j.Parent then
				table.remove(list, i)
			else
				i = i + 1
				if e.mode == "ragdoll" then
					local okR = pcall(Rig.ragdollStep, e, dt, g, damp, worldOf)
					if not okR then e.j.Transform = CFrame.new() end
				else

					e.j.Transform = CFrame.new()
				end
			end
		end
	end))

	track(RunService.Stepped:Connect(function(_, dt)
		pcall(updateArmAim, dt)
	end))

	local regrowCounter = 0

	local function bloodBurst(pos, count)
		local fx = Instance.new("Part")
		fx.Name = "RickBlood"
		fx.Anchored = true
		fx.CanCollide = false
		fx.CanQuery = false
		fx.CanTouch = false
		fx.CastShadow = false
		fx.Transparency = 1
		fx.Size = Vector3.new(0.2, 0.2, 0.2)
		fx.CFrame = CFrame.new(pos)
		fx.Parent = workspace
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(Color3.fromRGB(190, 20, 35), Color3.fromRGB(110, 8, 20))
		e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0.05)})
		e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.6)})
		e.Lifetime = NumberRange.new(0.5, 1.1)
		e.Rate = 0
		e.Speed = NumberRange.new(6, 16)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, -45, 0)
		e.Parent = fx
		e:Emit(count)
		Debris:AddItem(fx, 1.6)
	end

	local function startRegrow(order, depthOf, jointOf, handles, preDelay, doRegrow, animOverride)
		local list = {}
		for _, p in ipairs(order) do
			if p.Parent then list[#list + 1] = p end
		end
		if #list == 0 then return end

		regrowCounter = regrowCounter + 1
		local id = regrowCounter
		local animTime = math.max(tonumber(animOverride) or Config.SeverRegrowAnimTime, 1)
		local delay = math.max(tonumber(preDelay) or 0, 0)
		local regrow = (doRegrow ~= false)
		local TAU = math.pi * 2
		local rng = Random.new(id * 7919 + 13)
		local CYL = CFrame.Angles(0, 0, math.pi / 2)
		local lod = #list > 6

		local COL = {
			bone = Color3.fromRGB(236, 226, 198),
			dark = Color3.fromRGB(26, 6, 8),
			muscle = {Color3.fromRGB(158, 28, 40), Color3.fromRGB(198, 56, 66), Color3.fromRGB(122, 16, 30)},
			fascia = Color3.fromRGB(224, 132, 140),
			fat = Color3.fromRGB(238, 204, 132),
			artery = Color3.fromRGB(206, 24, 44),
			vein = Color3.fromRGB(78, 56, 146),
			sup = Color3.fromRGB(104, 88, 182),
			tendon = Color3.fromRGB(240, 222, 210),
			blood = Color3.fromRGB(132, 8, 22),
			glow = Color3.fromRGB(255, 120, 130),
		}

		local folder = Instance.new("Folder")
		folder.Name = "RickLimbRegrow"
		folder.Parent = workspace

		local function ph(t, a, b) return math.clamp((t - a) / (b - a), 0, 1) end

		local function mk(kind, color, reflect)
			local q = Instance.new("Part")
			q.Anchored = true
			q.CanCollide = false
			q.CanQuery = false
			q.CanTouch = false
			q.CastShadow = false
			q.Massless = true
			q.Material = Enum.Material.SmoothPlastic
			q.Color = color
			q.Reflectance = reflect or 0
			q.Size = Vector3.new(0.1, 0.1, 0.1)
			q.Transparency = 1
			if kind == "ball" then
				q.Shape = Enum.PartType.Ball
			elseif kind == "cyl" then
				q.Shape = Enum.PartType.Cylinder
			elseif kind == "ell" then
				local m = Instance.new("SpecialMesh")
				m.MeshType = Enum.MeshType.Sphere
				m.Parent = q
			end
			q.Parent = folder
			return q
		end

		local function emitter(parent, size, speed, life, spread, accel)
			local e = Instance.new("ParticleEmitter")
			e.Color = ColorSequence.new(Color3.fromRGB(190, 20, 35), Color3.fromRGB(100, 6, 18))
			e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 0.2)})
			e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 0.7)})
			e.Lifetime = NumberRange.new(life * 0.6, life)
			e.Rate = 0
			e.Speed = NumberRange.new(speed * 0.4, speed)
			e.SpreadAngle = Vector2.new(spread, spread)
			e.Acceleration = Vector3.new(0, accel, 0)
			e.Parent = parent
			return e
		end

		local function setEll(part, base, lx, ly, lz, sx, sy, sz, baseT, vis, rot)
			if vis <= 0.01 or sx < 0.02 or sy < 0.02 or sz < 0.02 then
				part.Transparency = 1
				return
			end
			part.Size = Vector3.new(sx, sy, sz)
			part.CFrame = base * CFrame.new(lx, ly, lz) * (rot or CFrame.identity)
			part.Transparency = 1 - (1 - baseT) * vis
		end

		local function setCyl(part, base, lx, ly, lz, len, dia, baseT, vis)
			if vis <= 0.01 or len < 0.02 or dia < 0.02 then
				part.Transparency = 1
				return
			end
			part.Size = Vector3.new(len, dia, dia)
			part.CFrame = base * CFrame.new(lx, ly, lz) * CYL
			part.Transparency = 1 - (1 - baseT) * vis
		end

		local function setBall(part, base, lx, ly, lz, d, baseT, vis)
			if vis <= 0.01 or d < 0.02 then
				part.Transparency = 1
				return
			end
			part.Size = Vector3.new(d, d, d)
			part.CFrame = base * CFrame.new(lx, ly, lz)
			part.Transparency = 1 - (1 - baseT) * vis
		end

		local VDEF = {
			{layer = 1, rad = 0.30, th = 0.075, col = COL.artery, ph0 = 0.0, turns = 1.3},
			{layer = 1, rad = 0.31, th = 0.085, col = COL.vein, ph0 = 3.1, turns = -1.1},
			{layer = 1, rad = 0.33, th = 0.04, col = COL.tendon, ph0 = 1.6, turns = 0.9},
			{layer = 2, rad = 0.42, th = 0.06, col = COL.sup, ph0 = 1.1, turns = 1.6},
		}

		local function vesselPoint(r, v, q)
			local a = v.ph0 + q * v.turns * TAU
			local rr = v.rad * r.vw * (1 + 0.06 * math.sin(q * 9 + v.ph0))
			return Vector3.new(math.cos(a) * rr, r.ys + r.gy * q * r.L, math.sin(a) * rr)
		end

		local kidsIn = {}
		for _, c in ipairs(list) do
			local jc = jointOf[c]
			if jc and jc.Part0 then
				local t = kidsIn[jc.Part0]
				if not t then
					t = {}
					kidsIn[jc.Part0] = t
				end
				t[#t + 1] = jc
			end
		end

		local function fitLimbToJoints(p, j)
			local S = p.Size
			local prox = j.C1.Position
			local dist
			local kj = kidsIn[p]
			if kj then
				local best = -1
				for _, jc in ipairs(kj) do
					local q = jc.C0.Position
					local dd = (q - prox).Magnitude
					if dd > best then
						best = dd
						dist = q
					end
				end
			end
			if not dist then
				local d
				if prox.Magnitude > 0.05 then
					d = -prox.Unit
				else
					local pl = p.CFrame:PointToObjectSpace(j.Part0.Position)
					d = (pl.Magnitude > 0.05) and -pl.Unit or Vector3.yAxis
				end
				local he = math.abs(d.X) * S.X / 2 + math.abs(d.Y) * S.Y / 2 + math.abs(d.Z) * S.Z / 2
				dist = d * he
			end
			local axis = prox - dist
			local len = axis.Magnitude
			if len < 0.08 then return nil end
			local yv = axis / len
			local ref = (math.abs(yv.Z) < 0.9) and Vector3.zAxis or Vector3.xAxis
			local xv = yv:Cross(ref).Unit
			local fix = CFrame.fromMatrix((prox + dist) / 2, xv, yv)
			local dims = {S.X, S.Y, S.Z}
			table.sort(dims)
			local w = (math.abs(yv.Y) > 0.9) and math.min(S.X, S.Z) or dims[2]
			return len, math.max(w, 0.2), fix
		end

		local recs, recOf = {}, {}
		for idx, p in ipairs(list) do
			local S = p.Size
			local head = (p.Name == "Head")
			local L = math.max(S.Y, 0.1)
			local W = math.max(math.min(S.X, S.Z), 0.2)
			local axisFix = CFrame.identity
			if Rig.type == "Custom" and not head then
				if S.X > S.Y * 1.3 and S.X >= S.Z then
					L = math.max(S.X, 0.1)
					W = math.max(math.min(S.Y, S.Z), 0.2)
					axisFix = CFrame.Angles(0, 0, math.pi / 2)
				elseif S.Z > S.Y * 1.3 and S.Z > S.X then
					L = math.max(S.Z, 0.1)
					W = math.max(math.min(S.X, S.Y), 0.2)
					axisFix = CFrame.Angles(math.pi / 2, 0, 0)
				end
			end
			local sign = 1
			local j = jointOf[p]
			if j then
				local cy = axisFix:PointToObjectSpace(j.C1.Position).Y
				if math.abs(cy) > 0.05 then
					sign = (cy > 0) and 1 or -1
				elseif j.Part0 then
					local lp = (p.CFrame * axisFix):PointToObjectSpace(j.Part0.Position)
					sign = (lp.Y > 0) and 1 or -1
				end
			end

			local fitAllowed = (Rig.type ~= "R6") or Config.SeverRegrowFitJointsR6 == true
			if j and not head and fitAllowed and Config.SeverRegrowFitJoints ~= false then
				local okF, nL, nW, nFix = pcall(fitLimbToJoints, p, j)
				if okF and nFix then
					L, W, axisFix, sign = nL, nW, nFix, 1
				end
			end
			local flat = (not head) and L < 0.6 * W
			local r = {
				p = p, L = L, W = W, ys = sign * L / 2, gy = -sign, axisFix = axisFix,
				head = head, flat = flat, d = depthOf[p] or 0, idx = idx,
				vw = head and W * 1.15 or W,
			}
			r.root = (r.d == 0)

			if head then
				r.skull = mk("ell", COL.bone)
				r.jaw = mk("ell", COL.bone)
				r.eyeA = mk("ell", COL.dark)
				r.eyeB = mk("ell", COL.dark)
			else
				r.shaft = mk("cyl", COL.bone)
				r.epiA = mk("ell", COL.bone)
				r.epiB = mk("ell", COL.bone)
				r.conA = mk("ball", COL.bone)
				r.conB = mk("ball", COL.bone)
			end

			r.nm = head and 0 or ((W >= 0.7 and not flat) and 5 or 3)
			r.muscles = {}
			for k = 1, r.nm do
				r.muscles[k] = {
					part = mk("ell", COL.muscle[(k % 3) + 1], 0.05),
					ang = (k - 1) * TAU / r.nm + rng:NextNumber(-0.25, 0.25),
					rad = W * rng:NextNumber(0.17, 0.22),
					thick = W * rng:NextNumber(0.30, 0.38),
					len = rng:NextNumber(0.9, 1.0),
					off = rng:NextNumber(0, 0.05),
					ph = rng:NextNumber(0, TAU),
					rot = CFrame.Angles(rng:NextNumber(-0.05, 0.05), 0, rng:NextNumber(-0.05, 0.05)),
				}
			end
			r.fascia = mk("ell", COL.fascia, 0.18)

			r.vessels = {}
			local use = lod and {1, 2, 4} or {1, 2, 3, 4}
			local N = math.clamp(math.ceil(L * 4), 5, lod and 7 or 11)
			if flat then N = 4 end
			if head then N = 8 end
			for _, di in ipairs(use) do
				local def = VDEF[di]
				local v = {layer = def.layer, rad = def.rad, th = def.th, ph0 = def.ph0, turns = def.turns, segs = {}}
				for i = 1, N do
					v.segs[i] = mk("cyl", def.col, 0.1)
				end
				r.vessels[#r.vessels + 1] = v
			end

			r.tip = mk("ball", COL.glow)
			r.tip.Material = Enum.Material.Neon
			r.tipEm = emitter(r.tip, 0.12, 2.5, 0.5, 180, -12)

			if r.root then
				r.ring = {}
				for k = 1, 8 do
					local col = (k % 3 == 0) and COL.fat or ((k % 2 == 0) and COL.fascia or COL.muscle[1])
					r.ring[k] = {
						part = mk("ell", col, 0.1),
						ang = (k - 1) * TAU / 8 + rng:NextNumber(-0.2, 0.2),
						rad = W * rng:NextNumber(0.22, 0.36),
						sz = W * rng:NextNumber(0.12, 0.22),
						lift = rng:NextNumber(0.02, 0.14),
						ph = rng:NextNumber(0, TAU),
					}
				end
				r.sinew = {}
				for k = 1, 3 do
					r.sinew[k] = {
						part = mk("cyl", COL.tendon),
						ang = rng:NextNumber(0, TAU),
						rad = W * rng:NextNumber(0.1, 0.3),
						len = rng:NextNumber(0.25, 0.5),
						dx = rng:NextNumber(-0.5, 0.5),
						dz = rng:NextNumber(-0.5, 0.5),
					}
				end
				r.pool = mk("ell", COL.blood, 0.3)
				r.hang = {}
				for k = 1, 2 do
					r.hang[k] = {
						cyl = mk("cyl", COL.blood, 0.25),
						bead = mk("ball", COL.blood, 0.25),
						ox = rng:NextNumber(-0.25, 0.25) * W,
						oz = rng:NextNumber(-0.25, 0.25) * W,
						ph = rng:NextNumber(0, TAU),
					}
				end
				r.dripPart = mk("ball", COL.blood)
				r.dripEm = emitter(r.dripPart, 0.2, 3, 0.8, 40, -45)
			end

			recs[#recs + 1] = r
			recOf[p] = r
		end

		local function span(r)
			if r.s1 then return end
			local j = jointOf[r.p]
			local parent = j and recOf[j.Part0]
			if parent and parent ~= r then
				span(parent)
				r.s0 = parent.s1
				r.top = parent.top
			else
				r.s0 = 0
				r.top = r
			end
			r.s1 = r.s0 + r.L
			r.top.total = math.max(r.top.total or 0, r.s1)
		end
		for _, r in ipairs(recs) do span(r) end
		for _, r in ipairs(recs) do
			local tot = math.max(r.top.total or r.L, 0.01)
			r.n0 = r.s0 / tot
			r.n1 = math.max(r.s1 / tot, r.n0 + 0.001)
		end

		local function updateRec(r, P)
			local p = r.p
			if not p.Parent then return end
			local base = p.CFrame * r.axisFix
			local L, W, ys, gy = r.L, r.W, r.ys, r.gy
			local now = P.now
			local root = r.root
			local function ch(x) return ph(x, r.n0, r.n1) end
			local function yAt(s) return ys + gy * s end

			local vis = 1 - P.fo
			if P.cam then
				local dc = (P.cam.CFrame.Position - p.Position).Magnitude
				vis = vis * math.clamp((dc - 1.2) / 1.6, 0, 1)
			end

			local gb = math.max(ch(P.pb), (root and not r.head) and 0.16 or 0)
			local gm = math.max(ch(P.pm), root and 0.1 or 0)
			local gf = ch(P.pf)
			local hb = 1 + 0.045 * math.max(0, math.sin(now * 7))

			if r.head then
				local hw, hl = W * 1.12, L * 1.12
				setEll(r.skull, base, 0, yAt(hl * 0.55), 0, hw * 0.74 * gb, hl * 0.8 * gb, hw * 0.8 * gb, 0, vis)
				local sj = ph(gb, 0, 0.7)
				setEll(r.jaw, base, 0, yAt(hl * 0.14), -hw * 0.05, hw * 0.5 * sj, hl * 0.26 * sj, hw * 0.52 * sj, 0, vis)
				local se = ph(gb, 0.6, 1)
				setEll(r.eyeA, base, -hw * 0.17, yAt(hl * 0.62), -hw * 0.33, hw * 0.17 * se, hw * 0.17 * se, hw * 0.1 * se, 0, vis)
				setEll(r.eyeB, base, hw * 0.17, yAt(hl * 0.62), -hw * 0.33, hw * 0.17 * se, hw * 0.17 * se, hw * 0.1 * se, 0, vis)
			else
				local bd = math.clamp(0.2 * W, 0.12, 0.34)
				local len = L * gb
				if len > 0.03 then
					setCyl(r.shaft, base, 0, yAt(len / 2), 0, len, bd, 0, vis)
					setEll(r.epiA, base, 0, yAt(0), 0, bd * 2.5, bd * 1.7, bd * 2.1, 0, vis)
					setEll(r.epiB, base, 0, yAt(len), 0, bd * 2.1, bd * 1.6, bd * 1.8, 0, vis)
					setBall(r.conA, base, -bd * 0.55, yAt(len) + gy * bd * 0.6, 0, bd * 1.15, 0, vis)
					setBall(r.conB, base, bd * 0.55, yAt(len) + gy * bd * 0.6, 0, bd * 1.15, 0, vis)
				else
					r.shaft.Transparency = 1
					r.epiA.Transparency = 1
					r.epiB.Transparency = 1
					r.conA.Transparency = 1
					r.conB.Transparency = 1
				end
			end

			for _, v in ipairs(r.vessels) do
				local g = ch(v.layer == 1 and P.pv1 or P.pv2)
				local N = #v.segs
				for i = 1, N do
					local seg = v.segs[i]
					local gs = math.clamp(g * N - (i - 1), 0, 1)
					if gs <= 0 or vis <= 0.01 then
						seg.Transparency = 1
					else
						local q0 = (i - 1) / N
						local a0 = vesselPoint(r, v, q0)
						local a1 = vesselPoint(r, v, q0 + gs / N)
						local len = (a1 - a0).Magnitude
						if len < 0.01 then
							seg.Transparency = 1
						else
							local thick = math.max(v.th * W * (1 + 0.35 * math.max(0, math.sin(now * 9 - q0 * 6))), 0.035)
							seg.Size = Vector3.new(len + thick * 0.6, thick, thick)
							seg.CFrame = base * CFrame.lookAt((a0 + a1) / 2, a1) * CFrame.Angles(0, math.pi / 2, 0)
							seg.Transparency = 1 - 0.9 * vis
						end
					end
				end
			end

			for _, m in ipairs(r.muscles) do
				local len = L * m.len * gm
				if len < 0.03 then
					m.part.Transparency = 1
				else
					local pulse = hb * (1 + 0.03 * math.sin(now * 5 + m.ph))
					local th = m.thick * pulse * (0.35 + 0.65 * math.min(1, gm * 1.6))
					setEll(m.part, base, math.cos(m.ang) * m.rad, yAt(m.off * L + len / 2), math.sin(m.ang) * m.rad, th, len, th * 0.9, 0, vis, m.rot)
				end
			end

			local fcol = COL.fascia:Lerp(p.Color, math.clamp(P.sk * 1.2, 0, 1) * 0.75)
			r.fascia.Color = fcol
			if r.head then
				local hw, hl = W * 1.12, L * 1.12
				setEll(r.fascia, base, 0, yAt(hl * 0.52), 0, hw * 0.92 * gf, hl * 0.96 * gf, hw * 0.92 * gf, 0.28, vis)
			else
				local flen = L * gf
				local fw = W * 0.8 * (1 + 0.03 * math.sin(now * 6 + r.idx))
				setEll(r.fascia, base, 0, yAt(flen / 2), 0, fw, flen, fw, 0.28, vis)
			end

			local lead = r.head and gb or gm
			if lead > 0.03 and lead < 0.97 and not (root and lead <= 0.1) and vis > 0.2 then
				local d = 0.16 * W * (0.8 + 0.4 * math.sin(now * 20 + r.idx))
				r.tip.Size = Vector3.new(d, d, d)
				r.tip.CFrame = base * CFrame.new(0, yAt(L * lead), 0)
				r.tip.Transparency = 0.45
				r.tipEm.Rate = 16
			else
				r.tip.Transparency = 1
				r.tipEm.Rate = 0
			end

			if root then
				local sp = base * CFrame.new(0, ys, 0)
				for _, g in ipairs(r.ring) do
					local sz = g.sz * (1 + 0.12 * math.sin(now * 4 + g.ph))
					setEll(g.part, base, math.cos(g.ang) * g.rad, ys + gy * g.lift, math.sin(g.ang) * g.rad, sz * 1.5, sz * 1.1, sz * 1.4, 0.05, vis)
				end
				local sinVis = vis * (1 - ph(gm, 0.2, 0.6))
				for _, s in ipairs(r.sinew) do
					if sinVis <= 0.01 then
						s.part.Transparency = 1
					else
						local len = s.len * (1 + 0.1 * math.sin(now * 3 + s.ang))
						s.part.Size = Vector3.new(len, 0.045, 0.045)
						s.part.CFrame = base * CFrame.new(math.cos(s.ang) * s.rad, ys + gy * len / 2, math.sin(s.ang) * s.rad) * CFrame.Angles(s.dx * 0.3, 0, s.dz * 0.3) * CYL
						s.part.Transparency = 1 - sinVis
					end
				end
				local pw = W * 0.85 * (1 + 0.04 * math.sin(now * 3))
				setEll(r.pool, base, 0, ys + gy * 0.02, 0, pw, 0.09, pw, 0.15, vis)

				local spPos = sp.Position
				local bl = P.bleed
				for _, h in ipairs(r.hang) do
					if bl < 0.04 or vis <= 0.01 then
						h.cyl.Transparency = 1
						h.bead.Transparency = 1
					else
						local len = (0.18 + 0.5 * (0.5 + 0.5 * math.sin(now * 1.7 + h.ph))) * (0.4 + bl)
						local top = spPos + Vector3.new(h.ox, 0, h.oz)
						h.cyl.Size = Vector3.new(len, 0.05, 0.05)
						h.cyl.CFrame = CFrame.new(top - Vector3.new(0, len / 2, 0)) * CYL
						h.cyl.Transparency = 1 - vis
						local bd = 0.1 + 0.03 * math.sin(now * 5 + h.ph)
						h.bead.Size = Vector3.new(bd, bd, bd)
						h.bead.CFrame = CFrame.new(top - Vector3.new(0, len, 0))
						h.bead.Transparency = 1 - vis
					end
				end
				r.dripPart.CFrame = sp
				r.dripEm.Rate = (vis > 0.3) and 30 * bl or 0
			end
		end

		local t0 = os.clock()
		local conn
		local boneSound, boneSoundPlayed = nil, false
		local function finish(restore)
			if conn then
				conn:Disconnect()
				conn = nil
			end
			if boneSound and boneSound.Parent then boneSound:Destroy() end
			Regrowing[id] = nil
			if restore then
				for _, r in ipairs(recs) do
					if r.root and r.p.Parent then
						pcall(flashAt, r.p.Position, 1.1)
						pcall(bloodBurst, r.p.Position, 10)
					end
				end
			end
			if folder.Parent then folder:Destroy() end

			for _, p in ipairs(list) do
				Severed[p] = nil
				SeverImmune[p] = os.clock() + 1.5
				if p.Parent then Rig.resetLTM(p) end
			end
			for _, hd in ipairs(handles) do
				Severed[hd.h] = nil
				if hd.h.Parent then Rig.resetLTM(hd.h) end
			end
		end
		Regrowing[id] = function() finish(false) end

		conn = RunService.RenderStepped:Connect(function()
			if not Z.alive then finish(false) return end

			local anyLeft = false
			for _, lp in ipairs(list) do
				if lp.Parent then anyLeft = true break end
			end
			if not anyLeft then finish(false) return end
			local now = os.clock()
			local el = now - t0
			local t = regrow and ((el - delay) / animTime) or -1
			if t >= 1 then finish(true) return end

			if t >= 0 and not boneSoundPlayed then
				boneSoundPlayed = true
				if Config.SoundBoneGrow and Config.SoundBoneGrow ~= "" then
					local anchorP
					for _, lp in ipairs(list) do
						if lp.Parent then anchorP = lp break end
					end
					boneSound = playSound(Config.SoundBoneGrow, Config.SoundBoneGrowVolume or 1.2, anchorP)
					if boneSound then pcall(function() Debris:AddItem(boneSound, animTime + 2) end) end
				end
			end

			local bleed
			if t < 0 then
				bleed = (delay > 0) and (1 - 0.65 * math.clamp(el / delay, 0, 1)) or 0.35
			else
				bleed = 0.35 * (1 - ph(t, 0.2, 0.78))
			end

			local P = {
				now = now,
				cam = workspace.CurrentCamera,
				pb = ph(t, 0, 0.28),
				pv1 = ph(t, 0.16, 0.48),
				pm = ph(t, 0.32, 0.62),
				pf = ph(t, 0.48, 0.76),
				pv2 = ph(t, 0.6, 0.84),
				sk = ph(t, 0.76, 0.96),
				fo = ph(t, 0.93, 1),
				bleed = bleed,
			}

			for _, r in ipairs(recs) do
				pcall(updateRec, r, P)
				if t >= 0 and r.p.Parent then
					Severed[r.p] = 1 - ph(P.sk, r.n0, r.n1)
				end
			end
			if t >= 0 then
				for _, hd in ipairs(handles) do
					if hd.h.Parent then Severed[hd.h] = 1 - P.sk end
				end
			end
		end)
	end

	local TAU = math.pi * 2
	local BLOOD_G = 60
	local bloodRng = Random.new()
	local bloodFolder = Instance.new("Folder")
	bloodFolder.Name = "RickBloodStains"
	bloodFolder.Parent = workspace
	Z.bloodFolder = bloodFolder
	local stains = {}

	local function limbWeight(order)
		local w = 0
		for _, p in ipairs(order) do
			local n = p.Name
			if n == "Head" then
				w = w + 1
			elseif n:find("Hand") or n:find("Foot") then
				w = w + 0.35
			elseif n:find("Lower") then
				w = w + 0.7
			elseif n:find("Upper") then
				w = w + 1
			else
				w = w + 1.2
			end
		end
		return w
	end

	local function pruneStains()
		local keep = {}
		for _, s in ipairs(stains) do
			if s.Parent then keep[#keep + 1] = s end
		end
		stains = keep
	end

	local function makeStain(pos, normal, radius, life, pool, color)
		if not Config.BloodStains or not Z.alive or not bloodFolder.Parent then return end
		local maxN = Config.BloodMaxStains or 80
		if #stains >= maxN then
			pruneStains()
			if #stains >= maxN then
				local old = table.remove(stains, 1)
				if old then old:Destroy() end
			end
		end
		local ref = (math.abs(normal.Y) < 0.9) and Vector3.yAxis or Vector3.xAxis
		local up = normal:Cross(ref).Unit
		local basis = CFrame.fromMatrix(Vector3.zero, normal, up, normal:Cross(up))
			* CFrame.Angles(bloodRng:NextNumber(0, TAU), 0, 0)

		local s = Instance.new("Part")
		s.Name = "RickBloodStain"
		s.Shape = Enum.PartType.Cylinder
		s.Anchored = true
		s.CanCollide = false
		s.CanQuery = false
		s.CanTouch = false
		s.CastShadow = false
		s.Material = Enum.Material.SmoothPlastic
		local shade = bloodRng:NextNumber(0, 1)
		s.Color = color or Color3.fromRGB(math.floor(88 + 52 * shade), 4, math.floor(12 + 12 * shade))
		s.Reflectance = pool and 0.18 or 0.1
		s.Transparency = 0.05
		local wR = radius * bloodRng:NextNumber(0.75, 1.25)
		local hR = radius * bloodRng:NextNumber(0.75, 1.25)
		s.Size = Vector3.new(0.03, 0.05, 0.05)
		s.CFrame = CFrame.new(pos + normal * (0.025 + bloodRng:NextNumber(0, 0.02))) * basis
		s.Parent = bloodFolder
		stains[#stains + 1] = s

		TweenService:Create(s, TweenInfo.new(pool and 2.2 or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = Vector3.new(0.03, wR * 2, hR * 2)}):Play()

		life = life or 28
		Debris:AddItem(s, life + 9)
		task.delay(life * 0.15, function()
			if s.Parent then
				TweenService:Create(s, TweenInfo.new(life * 0.8, Enum.EasingStyle.Sine),
					{Color = Color3.fromRGB(52, 6, 10), Reflectance = 0}):Play()
			end
		end)
		task.delay(life, function()
			if s.Parent then
				TweenService:Create(s, TweenInfo.new(8, Enum.EasingStyle.Sine), {Transparency = 1}):Play()
			end
		end)
	end

	local function throwDroplet(origin, vel, ctx)
		local ignore = {character, bloodFolder}
		for _, v in ipairs(ctx.ignore or {}) do
			if typeof(v) == "Instance" then ignore[#ignore + 1] = v end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = true
		params.FilterDescendantsInstances = ignore

		local pos, v, t = origin, vel, 0
		local dt = 0.07
		local g = Vector3.new(0, -BLOOD_G, 0)
		for _ = 1, 20 do
			local nv = v + g * dt
			local step = (v + nv) * 0.5 * dt
			local hit = workspace:Raycast(pos, step, params)
			local tries = 0
			while hit and tries < 3 do
				local inst = hit.Instance
				local skip = false
				if inst:IsA("BasePart") and inst.ClassName ~= "Terrain" then
					local mdl = inst:FindFirstAncestorOfClass("Model")
					skip = inst.Transparency >= 0.9 or not inst.CanCollide
						or (mdl ~= nil and mdl:FindFirstChildOfClass("Humanoid") ~= nil)
				end
				if not skip then break end
				ignore[#ignore + 1] = inst
				params.FilterDescendantsInstances = ignore
				hit = workspace:Raycast(pos, step, params)
				tries = tries + 1
			end
			if hit then
				local frac = (hit.Position - pos).Magnitude / math.max(step.Magnitude, 1e-3)
				return hit, t + dt * frac
			end
			pos, v, t = pos + step, nv, t + dt
		end
		return nil
	end

	local function coneDir(dir, spread)
		local ref = (math.abs(dir.Y) < 0.95) and Vector3.yAxis or Vector3.xAxis
		local u = dir:Cross(ref).Unit
		local w = dir:Cross(u)
		local a = bloodRng:NextNumber(0, TAU)
		local r = math.tan(bloodRng:NextNumber(0, spread))
		return (dir + (u * math.cos(a) + w * math.sin(a)) * r).Unit
	end

	local function splatter(origin, dir, count, vmin, vmax, spread, ctx, rmin, rmax)
		for _ = 1, count do
			local d = coneDir(dir, spread)
			local hit, tt = throwDroplet(origin, d * bloodRng:NextNumber(vmin, vmax), ctx)
			if hit then
				local r = bloodRng:NextNumber(rmin, rmax)
				task.delay(tt, function()
					makeStain(hit.Position, hit.Normal, r, Config.BloodStainLifetime)
				end)
			end
		end
	end

	local function wallSpray(worldPos, ctx, count)
		local cf = ctx.cf
		if not cf or count <= 0 then return end
		local lp = cf:PointToObjectSpace(worldPos)
		if math.abs(lp.Z) > 4 then return end
		local o = cf:PointToWorldSpace(Vector3.new(lp.X, lp.Y, -0.5))
		for _ = 1, count do
			local ld = Vector3.new(bloodRng:NextNumber(-1, 1), bloodRng:NextNumber(-0.7, 1), bloodRng:NextNumber(0.45, 1.1)).Unit
			local hit, tt = throwDroplet(o, cf:VectorToWorldSpace(ld) * bloodRng:NextNumber(7, 16), ctx)
			if hit then
				local hl = cf:PointToObjectSpace(hit.Position)
				if not inOpening(hl, ctx.hw or 5, ctx.hh or 5, 0.4) then
					local r = bloodRng:NextNumber(0.18, 0.55)
					task.delay(tt, function()
						makeStain(hit.Position, hit.Normal, r, Config.BloodStainLifetime)
					end)
				end
			end
		end
	end

	local function startSpurt(part, lpos, ldir, T, power, ctx)
		if not Config.SeverSpurt or not part or not part.Parent then return end
		local att = Instance.new("Attachment")
		att.CFrame = CFrame.lookAt(lpos, lpos + ldir)
		att.Parent = part
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(Color3.fromRGB(205, 24, 38), Color3.fromRGB(112, 6, 18))
		e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.08)})
		e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.5)})
		e.Lifetime = NumberRange.new(0.7, 1.2)
		e.Rate = 0
		e.EmissionDirection = Enum.NormalId.Front
		e.SpreadAngle = Vector2.new(9, 9)
		e.Acceleration = Vector3.new(0, -BLOOD_G, 0)
		e.LightInfluence = 0.4
		e.Parent = att

		task.spawn(function()
			local t0 = os.clock()
			local k = 0
			while Z.alive and att.Parent and part.Parent do
				local t = os.clock() - t0
				if t >= T then break end
				local f = (1 - t / T) ^ 1.3
				local s = power * f
				k = k + 1

				local wp = part.CFrame:PointToWorldSpace(lpos)
				local wd = part.CFrame:VectorToWorldSpace(ldir)
				local biased = (wd + Vector3.new(0, 0.7, 0)).Unit
				pcall(function() att.WorldCFrame = CFrame.lookAt(wp, wp + biased) end)

				local sp = 12 + 16 * s
				e.Speed = NumberRange.new(sp * 0.8, sp)
				e:Emit(math.floor(7 + 12 * s))

				splatter(wp, biased, math.floor(2 + 4 * s), sp * 0.75, sp * 1.1, 0.25, ctx, 0.12, 0.35)
				wallSpray(wp, ctx, math.floor(1 + 2 * s))

				if k % 2 == 1 then
					local hit = throwDroplet(wp, Vector3.new(0, -14, 0), ctx)
					if hit and hit.Normal.Y > 0.5 then
						makeStain(hit.Position, hit.Normal, bloodRng:NextNumber(0.5, 0.9) * (0.7 + s * 0.8),
							Config.BloodStainLifetime, true)
					end
				end

				task.wait(0.26 + 0.3 * (t / T))
			end
			task.wait(1.5)
			if att.Parent then att:Destroy() end
		end)
	end

	local function twitchLimb(model, roots, joints, T)
		if not Config.SeverTwitch then return end
		task.spawn(function()
			task.wait(0.7)
			local t0 = os.clock()
			while Z.alive and model.Parent do
				local t = os.clock() - t0
				if t >= T then break end
				local f = (1 - t / T) ^ 1.1
				local kicks = bloodRng:NextInteger(2, 4)
				for _ = 1, kicks do
					if not (Z.alive and model.Parent) then return end
					for _, c in ipairs(roots) do
						if c.Parent and c.AssemblyLinearVelocity.Magnitude < 12 then
							c.AssemblyLinearVelocity = c.AssemblyLinearVelocity + Vector3.new(
								bloodRng:NextNumber(-3, 3), bloodRng:NextNumber(3, 7), bloodRng:NextNumber(-3, 3)) * f
							c.AssemblyAngularVelocity = Vector3.new(
								bloodRng:NextNumber(-1, 1), bloodRng:NextNumber(-1, 1), bloodRng:NextNumber(-1, 1)) * 10 * f
						end
					end
					for _, jn in ipairs(joints) do
						if jn.child then
							if jn.child.Parent then
								pcall(function()
									jn.child:ApplyAngularImpulse(Vector3.new(
										bloodRng:NextNumber(-1, 1), bloodRng:NextNumber(-1, 1), bloodRng:NextNumber(-1, 1))
										* jn.child.AssemblyMass * 1.6 * f)
								end)
							end
						elseif jn.m.Parent then
							local rot = CFrame.Angles(
								bloodRng:NextNumber(-1, 1) * 0.7 * f,
								bloodRng:NextNumber(-1, 1) * 0.4 * f,
								bloodRng:NextNumber(-1, 1) * 0.7 * f)
							TweenService:Create(jn.m, TweenInfo.new(0.07), {C0 = jn.base * rot}):Play()
						end
					end
					task.wait(bloodRng:NextNumber(0.07, 0.14))
				end
				task.wait(bloodRng:NextNumber(0.3, 0.7) * (1 + t / T))
			end
			for _, jn in ipairs(joints) do
				if jn.m and jn.m.Parent then
					TweenService:Create(jn.m, TweenInfo.new(0.4), {C0 = jn.base}):Play()
				end
			end
		end)
	end

	local DECAY = {
		pale = Color3.fromRGB(176, 170, 156),
		sick = Color3.fromRGB(112, 128, 72),
		rot = Color3.fromRGB(58, 36, 24),
		goo = Color3.fromRGB(34, 18, 14),
	}

	local function decayColor(c0, a)
		local p1 = c0:Lerp(DECAY.pale, 0.65)
		if a < 0.25 then
			return c0:Lerp(p1, a / 0.25)
		elseif a < 0.55 then
			return p1:Lerp(DECAY.sick, (a - 0.25) / 0.3)
		elseif a < 0.85 then
			return DECAY.sick:Lerp(DECAY.rot, (a - 0.55) / 0.3)
		end
		return DECAY.rot:Lerp(DECAY.goo, math.clamp((a - 0.85) / 0.15, 0, 1))
	end

	local function decayLimb(model, anchorPart, T, doDecay)
		if not model then return end
		if not doDecay or not anchorPart then
			task.delay(T, function()
				if model.Parent then model:Destroy() end
			end)
			return
		end

		local parts = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				parts[#parts + 1] = {p = d, c = d.Color, t = d.Transparency}
			end
		end

		local att = Instance.new("Attachment")
		att.Parent = anchorPart
		local fume = Instance.new("ParticleEmitter")
		fume.Color = ColorSequence.new(Color3.fromRGB(120, 140, 80), Color3.fromRGB(70, 80, 50))
		fume.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.7)})
		fume.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 1)})
		fume.Lifetime = NumberRange.new(1.5, 2.5)
		fume.Speed = NumberRange.new(0.8, 1.6)
		fume.SpreadAngle = Vector2.new(25, 25)
		fume.Acceleration = Vector3.new(0, 0.6, 0)
		fume.LightInfluence = 0.5
		fume.Rate = 0
		fume.Parent = att

		local flies = {}
		for i = 1, 5 do
			local f = Instance.new("Part")
			f.Name = "RickFly"
			f.Shape = Enum.PartType.Ball
			f.Size = Vector3.new(0.09, 0.09, 0.09)
			f.Color = Color3.fromRGB(10, 10, 10)
			f.Material = Enum.Material.SmoothPlastic
			f.Anchored = true
			f.CanCollide = false
			f.CanQuery = false
			f.CanTouch = false
			f.CastShadow = false
			f.Transparency = 1
			f.Parent = bloodFolder
			flies[i] = f
		end

		local t0 = os.clock()
		local lastTint = 0
		local pooled = false
		local lastPos = anchorPart.Position
		local conn

		local function cleanup()
			if conn then
				conn:Disconnect()
				conn = nil
			end
			for _, f in ipairs(flies) do
				if f.Parent then f:Destroy() end
			end
			if att.Parent then att:Destroy() end
		end

		conn = RunService.Heartbeat:Connect(function()
			if not Z.alive or not model.Parent then
				cleanup()
				return
			end
			local now = os.clock()
			local a = (now - t0) / T
			if a >= 1 then
				cleanup()
				model:Destroy()
				return
			end
			if anchorPart.Parent then lastPos = anchorPart.Position end

			if now - lastTint > 0.15 then
				lastTint = now
				local k = math.clamp((a - 0.88) / 0.12, 0, 1)
				for _, rec in ipairs(parts) do
					if rec.p.Parent then
						rec.p.Color = decayColor(rec.c, a)
						if k > 0 then rec.p.Transparency = math.max(rec.t, k) end
					end
				end
				fume.Rate = (a > 0.4) and (4 + 6 * a) or 0
			end

			local nFlies = (a > 0.55) and 5 or ((a > 0.3) and 3 or 0)
			for i, f in ipairs(flies) do
				if i <= nFlies and a < 0.92 then
					local tt = now * (2.5 + i * 0.4)
					local off = Vector3.new(
						math.noise(tt, i, 0), math.noise(i, tt, 3), math.noise(tt, 7, i)) * 3.2
					f.Transparency = 0
					f.CFrame = CFrame.new(lastPos + Vector3.new(0, 0.8, 0) + off)
				else
					f.Transparency = 1
				end
			end

			if a > 0.8 and not pooled then
				pooled = true
				local hit = throwDroplet(lastPos, Vector3.new(0, -14, 0), {ignore = {model}})
				if hit and hit.Normal.Y > 0.5 then
					makeStain(hit.Position, hit.Normal, 1.3, Config.BloodStainLifetime, true, Color3.fromRGB(62, 22, 16))
				end
			end
		end)
	end

	local severRng = Random.new()

	Rig.R6_NAMES = {"Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}
	Rig.R15_NAMES = {
		"Head",
		"LeftUpperArm", "LeftLowerArm", "LeftHand",
		"RightUpperArm", "RightLowerArm", "RightHand",
		"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
		"RightUpperLeg", "RightLowerLeg", "RightFoot",
	}
	Rig.JOINT_HINTS = {"shoulder", "hip", "neck", "elbow", "knee", "wrist", "ankle"}
	Rig.NAME_HINTS = {"arm", "hand", "leg", "foot", "head"}
	Rig.NOT_LIMB = {HumanoidRootPart = true, Torso = true, UpperTorso = true, LowerTorso = true}

	Rig.R6_PARENT = {
		["Head"] = "Torso", ["Left Arm"] = "Torso", ["Right Arm"] = "Torso",
		["Left Leg"] = "Torso", ["Right Leg"] = "Torso",
	}
	Rig.R15_PARENT = {
		Head = "UpperTorso",
		LeftUpperArm = "UpperTorso", LeftLowerArm = "LeftUpperArm", LeftHand = "LeftLowerArm",
		RightUpperArm = "UpperTorso", RightLowerArm = "RightUpperArm", RightHand = "RightLowerArm",
		LeftUpperLeg = "LowerTorso", LeftLowerLeg = "LeftUpperLeg", LeftFoot = "LeftLowerLeg",
		RightUpperLeg = "LowerTorso", RightLowerLeg = "RightUpperLeg", RightFoot = "RightLowerLeg",
	}

	Rig.HINT_IGNORE = {
		"handle", "armor", "armour", "legacy", "necklace", "whip", "ship",
		"hitbox", "hurtbox", "headset", "headphone",
	}

	function Rig.find(name)
		local f = character:FindFirstChild(name)
		if f and f:IsA("BasePart") then return f end

		for _, d in ipairs(character:GetDescendants()) do
			if d.Name == name and d:IsA("BasePart")
				and not d:FindFirstAncestorOfClass("Accessory")
				and not d:FindFirstAncestorOfClass("Tool") then
				return d
			end
		end
		return nil
	end

	function Rig.hasHint(text, hints)
		local low = string.lower(text)
		for _, ig in ipairs(Rig.HINT_IGNORE) do
			if string.find(low, ig, 1, true) then return false end
		end
		for _, h in ipairs(hints) do
			if string.find(low, h, 1, true) then return true end
		end
		return false
	end

	function Rig.detect(force)
		local now = os.clock()
		if not force and Rig.type ~= "Unknown" and now - Rig.stamp < 1 then return Rig end
		Rig.stamp = now

		local hasR15 = Rig.find("UpperTorso") ~= nil or Rig.find("LeftUpperArm") ~= nil or Rig.find("RightUpperArm") ~= nil
		local hasR6 = Rig.find("Torso") ~= nil and (Rig.find("Left Arm") ~= nil or Rig.find("Right Arm") ~= nil)
		local rt = nil
		pcall(function() rt = humanoid.RigType end)

		local kind
		if hasR15 and not hasR6 then
			kind = "R15"
		elseif hasR6 and not hasR15 then
			kind = "R6"
		elseif hasR15 and hasR6 then
			kind = (rt == Enum.HumanoidRigType.R6) and "R6" or "R15"
		else
			kind = "Custom"
		end

		local set, list = {}, {}
		local function addLimb(part)
			if part and part:IsA("BasePart") and not set[part] and not Rig.NOT_LIMB[part.Name] then
				set[part] = true
				list[#list + 1] = part
			end
		end

		if kind == "R6" then
			for _, n in ipairs(Rig.R6_NAMES) do addLimb(Rig.find(n)) end
		elseif kind == "R15" then
			for _, n in ipairs(Rig.R15_NAMES) do addLimb(Rig.find(n)) end
		else
			for _, d in ipairs(character:GetDescendants()) do
				if d:IsA("Motor6D") and d.Part1 and d.Part1:IsA("BasePart") and d.Part1.Parent
					and not d.Part1:FindFirstAncestorOfClass("Accessory")
					and not d.Part1:FindFirstAncestorOfClass("Tool") then
					local pn = d.Part1.Name
					if Rig.hasHint(d.Name, Rig.JOINT_HINTS) or Rig.hasHint(pn, Rig.NAME_HINTS) then
						addLimb(d.Part1)
					end
				end
			end
			for _, d in ipairs(character:GetChildren()) do
				if d:IsA("BasePart") and Rig.hasHint(d.Name, Rig.NAME_HINTS) then addLimb(d) end
			end
		end

		Rig.type = kind
		Rig.set = set
		Rig.list = list
		Rig.humanoidType = rt and rt.Name or "?"

		if Config.SeverRigLog and Rig.lastLogged ~= kind then
			Rig.lastLogged = kind
			warnRG("Rig detectado: " .. kind .. " (Humanoid.RigType=" .. tostring(Rig.humanoidType) .. ", membros=" .. tostring(#list) .. ")")
		end
		return Rig
	end

	pcall(Rig.detect, true)
	pcall(function()
		track(humanoid:GetPropertyChangedSignal("RigType"):Connect(function() Rig.stamp = -1 end))
	end)
	pcall(function()
		track(character.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") or d:IsA("Motor6D") then Rig.stamp = -1 end
		end))
		track(character.DescendantRemoving:Connect(function(d)
			if d:IsA("BasePart") or d:IsA("Motor6D") then Rig.stamp = -1 end
		end))
	end)

	function Rig.crossing(d, cf, halfW, halfH)
		local rel = cf:ToObjectSpace(d.CFrame)
		local c = rel.Position
		local centerHit = c.Z > Config.SeverDepth and c.Z < 8 and inOpening(c, halfW, halfH, 0.5)
		if centerHit then return true end
		if Config.SeverPartialCross == false then return false end
		local half = d.Size * 0.5
		local tip = Config.SeverTipDepth or 0.3
		local margin = Config.SeverOpeningMargin or 1
		for sx = -1, 1, 2 do
			for sy = -1, 1, 2 do
				for sz = -1, 1, 2 do
					local pt = rel:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
					if pt.Z > tip and pt.Z < 12 and inOpening(pt, halfW, halfH, margin) then
						return true
					end
				end
			end
		end
		return false
	end

	function Rig.cloneForced(inst)
		local changed = {}
		local function force(o)
			if not o.Archivable then
				changed[#changed + 1] = o
				pcall(function() o.Archivable = true end)
			end
		end
		force(inst)
		for _, d in ipairs(inst:GetDescendants()) do force(d) end
		local okC, c = pcall(function() return inst:Clone() end)
		for _, o in ipairs(changed) do
			pcall(function() o.Archivable = false end)
		end
		if okC and c then return c end
		return nil
	end

	function Rig.keyMap(root)
		local map, used, rev = {}, {}, {}
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
				rev[d] = key
			end
		end
		return map, rev
	end

	function Rig.scrub(i)
		pcall(function() for _, t in ipairs(i:GetTags()) do i:RemoveTag(t) end end)
		pcall(function() for k in pairs(i:GetAttributes()) do i:SetAttribute(k, nil) end end)
	end

	function Rig.buildGhost(model, links)
		local ghost = Rig.cloneForced(character)
		if not ghost then return nil end
		local ghostMap = Rig.keyMap(ghost)
		local _, srcRev = Rig.keyMap(character)

		local pairsList, keep = {}, {}
		for _, ln in ipairs(links) do
			local key = srcRev[ln.orig]
			local gp = key and ghostMap[key]
			if gp then
				keep[gp] = true
				pairsList[#pairsList + 1] = {gp = gp, proxy = ln.proxy}
			end
		end
		if #pairsList == 0 then
			ghost:Destroy()
			return nil
		end

		for _, d in ipairs(ghost:GetDescendants()) do
			if d.Parent and d:IsA("BasePart") and not keep[d] then d:Destroy() end
		end
		for _, d in ipairs(ghost:GetDescendants()) do
			if d.Parent then
				local junk = d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint")
					or d:IsA("NoCollisionConstraint") or d:IsA("HumanoidDescription") or d:IsA("Tool")
				if not junk then
					for _, cls in ipairs(PORTAL_CLONE_JUNK) do
						if d:IsA(cls) then junk = true break end
					end
				end
				if junk then d:Destroy() end
			end
		end
		for _, d in ipairs(ghost:GetChildren()) do
			if d:IsA("Accessory") and not d:FindFirstChildWhichIsA("BasePart", true) then d:Destroy() end
		end

		for _, pr in ipairs(pairsList) do
			local gp = pr.gp
			gp.Anchored = true
			gp.CanCollide = false
			gp.CanQuery = false
			gp.CanTouch = false
			gp.Massless = true
			gp.CastShadow = true
			gp.CFrame = pr.proxy.CFrame
			Rig.scrub(gp)
		end
		Rig.scrub(ghost)

		local hum = ghost:FindFirstChildOfClass("Humanoid")
		if hum then
			pcall(function()
				hum.PlatformStand = true
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
			end)
		end
		ghost.Name = "RickLimbVisual"
		ghost.Parent = model
		if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end) end

		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not Z.alive or not model.Parent or not ghost.Parent then
				conn:Disconnect()
				if ghost.Parent then ghost:Destroy() end
				return
			end
			for _, pr in ipairs(pairsList) do
				if pr.proxy.Parent and pr.gp.Parent then
					pr.gp.CFrame = pr.proxy.CFrame
				end
			end
		end)
		return ghost
	end

	function Rig.fallbackClone(p)
		local okF, c = pcall(function()
			local q = Instance.new("Part")
			q.Name = p.Name
			q.Size = p.Size
			q.Color = p.Color
			q.Material = p.Material
			q.Reflectance = p.Reflectance
			q.Transparency = math.min(p.Transparency, 0.95)
			q.TopSurface = Enum.SurfaceType.Smooth
			q.BottomSurface = Enum.SurfaceType.Smooth
			return q
		end)
		if okF then return c end
		return nil
	end

	severCheck = function(P, otherP)
		if not Config.SeverEnabled or not Z.alive then return end
		if not (P and otherP and P.model and otherP.model) then return end
		local part = P.model.Parent and P.model:FindFirstChild("Portal")
		local oPart = otherP.model.Parent and otherP.model:FindFirstChild("Portal")
		if not (part and oPart) then return end
		if not rootPart.Parent or humanoid.Health <= 0 then return end

		local cf, toCF = part.CFrame, oPart.CFrame
		local halfW, halfH = part.Size.X / 2, part.Size.Y / 2

		if cf:PointToObjectSpace(rootPart.Position).Z > -0.2 then return end

		local inside = {}
		local rigNow = Rig.detect(true)
		for _, d in ipairs(rigNow.list) do
			if d.Parent then
				local immune = SeverImmune[d]
				if immune and immune <= os.clock() then
					SeverImmune[d] = nil
					immune = nil
				end
				if not Severed[d] and not immune and (d.Name ~= "Head" or Config.SeverHead == true) then
					if Rig.crossing(d, cf, halfW, halfH) then
						inside[d] = true
					end
				end
			end
		end
		if next(inside) == nil then return end
		Z.fala.dizer("corte")

		local jointOf, kids, extras = {}, {}, {}
		local limbSet = rigNow.set
		local isCustomRig = (rigNow.type == "Custom")
		for _, j in ipairs(character:GetDescendants()) do
			if j:IsA("Motor6D") and j.Part0 and j.Part1 then
				local p1 = j.Part1

				local isLimb
				if isCustomRig then
					isLimb = not (p1:FindFirstAncestorOfClass("Tool") or p1:FindFirstAncestorOfClass("Accessory"))
				else
					isLimb = limbSet[p1] == true
				end
				if isLimb then
					jointOf[p1] = j
					local list = kids[j.Part0]
					if not list then
						list = {}
						kids[j.Part0] = list
					end
					list[#list + 1] = p1
				elseif limbSet[j.Part0] then
					extras[#extras + 1] = {h = p1, anchor = j.Part0}
				end
			end
		end

		local pmap = (rigNow.type == "R15" and Rig.R15_PARENT) or (rigNow.type == "R6" and Rig.R6_PARENT) or nil
		if pmap then
			for _, lp in ipairs(rigNow.list) do
				if lp.Parent and not jointOf[lp] then
					local pn = pmap[lp.Name]
					local par = pn and Rig.find(pn)
					if par and par ~= lp then
						local lv = lp.CFrame:VectorToObjectSpace(par.Position - lp.Position)
						local c1 = CFrame.new(0, (lv.Y >= 0 and 1 or -1) * lp.Size.Y / 2, 0)
						jointOf[lp] = {
							Name = "Synth" .. lp.Name,
							Part0 = par,
							Part1 = lp,
							C0 = par.CFrame:ToObjectSpace(lp.CFrame * c1),
							C1 = c1,
							Transform = CFrame.identity,
						}
						local list = kids[par]
						if not list then
							list = {}
							kids[par] = list
						end
						list[#list + 1] = lp
					end
				end
			end
		end

		local set, order, depthOf = {}, {}, {}
		local function add(p, d)
			if set[p] or Severed[p] then return end
			set[p] = true
			depthOf[p] = d
			order[#order + 1] = p
			for _, c in ipairs(kids[p] or {}) do add(c, d + 1) end
		end
		for p in pairs(inside) do
			local j = jointOf[p]
			if not (j and inside[j.Part0]) then add(p, 0) end
		end
		if #order == 0 then return end

		local handles, seenHandle = {}, {}
		for _, acc in ipairs(character:GetChildren()) do
			if acc:IsA("Accessory") then
				local h = acc:FindFirstChild("Handle")
				local w = h and h:FindFirstChildWhichIsA("Weld")
				if h and h:IsA("BasePart") and w then
					local other = (w.Part0 == h) and w.Part1 or w.Part0
					if other and set[other] and not seenHandle[h] then
						seenHandle[h] = true
						handles[#handles + 1] = {h = h, anchor = other}
					end
				end
			end
		end
		for _, ex in ipairs(extras) do
			if set[ex.anchor] and ex.h.Parent and not seenHandle[ex.h] and not set[ex.h] then
				seenHandle[ex.h] = true
				handles[#handles + 1] = ex
			end
		end

		local KEEP_CLASSES = {"Attachment", "DataModelMesh", "Decal", "SurfaceAppearance"}
		local function makeClone(p)
			local c = Rig.cloneForced(p) or Rig.fallbackClone(p)
			if not c then return nil end
			for _, d in ipairs(c:GetDescendants()) do
				if d.Parent then
					local keepIt = false
					for _, cls in ipairs(KEEP_CLASSES) do
						if d:IsA(cls) then keepIt = true break end
					end
					if not keepIt then d:Destroy() end
				end
			end
			Rig.scrub(c)
			pcall(function() c.CollisionGroup = "Default" end)
			c.Anchored = false
			c.CanTouch = false
			c.CanQuery = false
			c.Massless = false
			c.CastShadow = true
			return c
		end

		local model = Instance.new("Model")
		model.Name = "RickSeveredLimb"
		local map = {}
		local limbJoints = {}
		for _, p in ipairs(order) do
			local c = makeClone(p)
			if c then
				c.CanCollide = true
				c.CFrame = toCF * FLIP * cf:ToObjectSpace(p.CFrame)
				c.Parent = model
				map[p] = c
			end
		end
		if next(map) == nil then
			model:Destroy()
			return
		end

		do
			local mine = {}
			for _, ch in ipairs(character:GetChildren()) do
				if ch:IsA("BasePart") then mine[#mine + 1] = ch end
			end
			for _, c in pairs(map) do
				for _, ch in ipairs(mine) do
					local nc = Instance.new("NoCollisionConstraint")
					nc.Part0 = c
					nc.Part1 = ch
					nc.Parent = c
				end
			end
		end

		for _, p in ipairs(order) do
			local j = jointOf[p]
			local c = map[p]
			if c and j and set[j.Part0] and map[j.Part0] then

				local poseC0 = j.Part0.CFrame:ToObjectSpace(j.Part1.CFrame) * j.C1
				local m = Instance.new("Motor6D")
				m.Name = j.Name
				m.C0 = poseC0
				m.C1 = j.C1
				m.Part0 = map[j.Part0]
				m.Part1 = c
				m.Parent = map[j.Part0]
				limbJoints[#limbJoints + 1] = {m = m, base = m.C0}
			end
		end

		local hmap = {}
		for _, hd in ipairs(handles) do
			local hc = makeClone(hd.h)
			local ac = map[hd.anchor]
			if hc and ac then
				local rel = hd.anchor.CFrame:ToObjectSpace(hd.h.CFrame)
				hc.CanCollide = false
				hc.Massless = true
				hc.CFrame = ac.CFrame * rel
				hc.Parent = model
				hmap[hd.h] = hc
				local w = Instance.new("Weld")
				w.Part0 = ac
				w.Part1 = hc
				w.C0 = rel
				w.Parent = hc
			end
		end

		model.Parent = workspace
		Debris:AddItem(model, Config.SeverLimbLifetime + 10)

		local out = toCF.LookVector
		local v = out * Config.SeverEjectSpeed + Vector3.new(0, 4, 0)
		local spin = 6
		for _, p in ipairs(order) do
			local c = map[p]
			local j = jointOf[p]
			if c and not (j and set[j.Part0]) then
				c.AssemblyLinearVelocity = v
				c.AssemblyAngularVelocity = Vector3.new(
					severRng:NextNumber(-spin, spin), severRng:NextNumber(-spin, spin), severRng:NextNumber(-spin, spin))
			end
		end

		if Config.SeverFakeGhost ~= false then
			local links = {}
			for _, p in ipairs(order) do
				if map[p] then links[#links + 1] = {orig = p, proxy = map[p]} end
			end
			for _, hd in ipairs(handles) do
				if hmap[hd.h] then links[#links + 1] = {orig = hd.h, proxy = hmap[hd.h]} end
			end
			local okGh, gh = pcall(Rig.buildGhost, model, links)
			if okGh and gh then
				local function hideProxy(c)
					c.Transparency = 1
					c.CastShadow = false
					for _, d in ipairs(c:GetChildren()) do
						if d:IsA("Decal") or d:IsA("SurfaceAppearance") then d:Destroy() end
					end
				end
				for _, c in pairs(map) do hideProxy(c) end
				for _, c in pairs(hmap) do hideProxy(c) end
			elseif not okGh then
				warnRG("erro no visual do membro (usando a peca fisica):", gh)
			end
		end

		local weight = limbWeight(order)
		local sizeK = math.clamp(weight / 2, 0.5, 1.2)
		local power = math.clamp(0.55 + weight * 0.3, 0.6, 1.2)
		local ctxA = {cf = cf, hw = halfW, hh = halfH, ignore = {P.model, otherP.model, model}}
		local ctxB = {cf = toCF, hw = oPart.Size.X / 2, hh = oPart.Size.Y / 2, ignore = {P.model, otherP.model, model}}
		local rootClones = {}
		for _, p in ipairs(order) do
			local j = jointOf[p]
			if j and not set[j.Part0] then
				local c = map[p]
				if c then
					rootClones[#rootClones + 1] = c
					local lp = j.C1.Position
					local ld = (lp.Magnitude > 0.05) and lp.Unit or Vector3.yAxis
					startSpurt(c, lp, ld, (Config.SeverSpurtTime or 6) * sizeK, power, ctxB)
				end
				local body = j.Part0
				if body and body.Parent then
					local bp = j.C0.Position
					local away = p.Position - body.CFrame:PointToWorldSpace(bp)
					local bd = (away.Magnitude > 0.05) and body.CFrame:VectorToObjectSpace(away.Unit) or Vector3.yAxis
					startSpurt(body, bp, bd, (Config.SeverSpurtTime or 6) * sizeK * 0.8, power * 0.9, ctxA)
				end
			end
		end
		twitchLimb(model, rootClones, limbJoints, (Config.SeverTwitchTime or 4.5) * sizeK)

		for _, p in ipairs(order) do
			Severed[p] = 1
			Rig.sevGen[p] = (Rig.sevGen[p] or 0) + 1
			local jr = jointOf[p]
			if typeof(jr) == "Instance" and jr:IsA("Motor6D") then
				local mode
				if Rig.type == "R6" then
					if Config.SeverFreezeAnimR6 ~= false then mode = "freeze" end
				elseif Rig.type == "R15" then
					local n = p.Name
					if Config.SeverRagdollArmsR15 ~= false and (n == "LeftUpperArm" or n == "LeftLowerArm" or n == "LeftHand"
						or n == "RightUpperArm" or n == "RightLowerArm" or n == "RightHand") then
						mode = "ragdoll"
					end
				end
				if mode then Rig.sevList[#Rig.sevList + 1] = {p = p, j = jr, mode = mode} end
			end
		end
		for _, hd in ipairs(handles) do
			Severed[hd.h] = 1
			Rig.sevGen[hd.h] = (Rig.sevGen[hd.h] or 0) + 1
		end

		local sevParts, sevGenAt = {}, {}
		for _, p in ipairs(order) do sevParts[#sevParts + 1] = p end
		for _, hd in ipairs(handles) do sevParts[#sevParts + 1] = hd.h end
		for _, p in ipairs(sevParts) do sevGenAt[p] = Rig.sevGen[p] end
		local function forceRestore()
			for _, p in ipairs(sevParts) do
				if Severed[p] ~= nil and Rig.sevGen[p] == sevGenAt[p] then
					Severed[p] = nil
					SeverImmune[p] = os.clock() + 1.5
					if p.Parent then Rig.resetLTM(p) end
				end
			end
		end
		if Config.SeverRegrow ~= false then
			local est = Config.SeverRegrowAnimTime
			if Config.SeverRegrowScaled then
				est = (Config.SeverRegrowBase or 3) + weight * (Config.SeverRegrowPerWeight or 6)
			end
			local wd = Config.SeverLimbLifetime + 0.65 + Config.SeverRegrowDelay + math.max(est, 1) + 6
			task.delay(wd, function()
				if Z.alive then pcall(forceRestore) end
			end)
		end

		local headPart
		for _, p in ipairs(order) do
			if p.Name == "Head" then headPart = p break end
		end
		for i = 1, 4 do
			task.delay(i * 0.22, function()
				if not Z.alive then return end
				for _, p in ipairs(order) do
					local j = jointOf[p]
					if p.Parent and not (j and set[j.Part0]) then
						bloodBurst(p.Position, headPart and 16 or 8)
					end
				end
			end)
		end
		if headPart and Config.SeverHeadKills and humanoid.Health > 0 then
			task.delay(Config.SeverHeadKillDelay or 0.25, function()
				if not (Z.alive and humanoid.Parent) then return end
				pcall(function() humanoid.Health = 0 end)
				pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Dead) end)
			end)
		end

		flashAt(order[1].Position, 0.9)
		bloodBurst(order[1].Position, headPart and 40 or 18)
		if map[order[1]] then
			flashAt(map[order[1]].Position, 0.9)
			bloodBurst(map[order[1]].Position, 14)
		end

		local preDelay = Config.SeverLimbLifetime + 0.65 + Config.SeverRegrowDelay
		local regrowTime = Config.SeverRegrowAnimTime
		if Config.SeverRegrowScaled then
			regrowTime = (Config.SeverRegrowBase or 3) + weight * (Config.SeverRegrowPerWeight or 6)
		end
		local okR, errR = pcall(startRegrow, order, depthOf, jointOf, handles, preDelay, Config.SeverRegrow, regrowTime)
		if not okR then
			warnRG("erro na regeneracao do membro:", errR)

			task.delay(preDelay, function()
				if Z.alive then pcall(forceRestore) end
			end)
		end

		decayLimb(model, map[order[1]] or model:FindFirstChildWhichIsA("BasePart"), Config.SeverLimbLifetime, Config.SeverDecay ~= false)
	end

	track(character.Destroying:Connect(releasePortalWalk))

	local function shotEffects(muzzlePos)
		flashAt(muzzlePos, 0.6)
		Z.fala.dizer("tiro")
		State.mortyEvent("onShot", muzzlePos)
		pcall(UIAnim.pulse, fireBtn, 1.18)
		playSound(Config.SoundShoot, 0.9, handle)
		task.spawn(playRecoil)
	end

	local function faceToward(pos)
		local d = pos - rootPart.Position
		d = Vector3.new(d.X, 0, d.Z)
		if d.Magnitude > 0.1 and not humanoid.SeatPart then
			rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + d.Unit)
		end
	end

	local function getTargetRoot()
		local tp = targetPlayer
		if not tp or not tp.Parent then return nil, "Escolha um player e toque em OK" end
		local tChar = tp.Character
		local tRoot = tChar and (tChar:FindFirstChild("HumanoidRootPart") or tChar.PrimaryPart)
		local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")
		if not tRoot or not tRoot.Parent then
			return nil, tp.DisplayName .. " nao esta carregado"
		end
		if tHum and tHum.Health <= 0 then
			return nil, tp.DisplayName .. " esta morto"
		end
		return tRoot
	end
	local function fireVariant1()
		if not isEquipped or not Z.alive then return end
		if humanoid.Health <= 0 then return end
		if os.clock() - lastShot < Config.ShotCooldown then return end

		local origin = camera.CFrame.Position
		local direction = camera.CFrame.LookVector * Config.MaxDistance
		local result = castSolid(origin, direction, buildIgnore(character, entrance and entrance.model, exitP and exitP.model))
		if not result or not result.Instance or not result.Instance:IsA("BasePart") then
			playSound(Config.SoundInvalid, 1.1, handle); Z.fala.dizer("erro")
			return
		end

		local hitPos = liftWallPortalAboveFloor(result.Position, result.Normal)
		local normal = result.Normal
		local hitPart = result.Instance

		lastShot = os.clock()
		shotId = shotId + 1
		local myShot = shotId

		local lookDir = hitPos - rootPart.Position
		lookDir = Vector3.new(lookDir.X, 0, lookDir.Z)
		if lookDir.Magnitude > 0.1 and not humanoid.SeatPart then
			rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + lookDir.Unit)
		end

		closePair()

		local muzzlePos = getMuzzlePos()
		flashAt(muzzlePos, 0.6)

		playSound(Config.SoundShoot, 0.9, handle)
		task.spawn(playRecoil)

		launchProjectile(muzzlePos, hitPos, function()
			if myShot ~= shotId or not Z.alive then return end
			flashAt(hitPos, 1.6)
			local exitCF = computeExitCF(hitPos, normal)
			exitP = newPortal(exitCF, hitPart)
			openRipple(exitCF)
			disarmed = nil
			task.delay(Config.EntranceDelay, function()
				if myShot ~= shotId or not Z.alive then return end
				if humanoid.Health <= 0 or not rootPart.Parent then return end
				local entCF = computeEntranceCF()
				entrance = newPortal(entCF, nil)
				openRipple(entCF)
			end)
			State.watchIdle(function() return myShot == shotId and Z.alive end, closeAllPortals)
		end)
	end

	local function fireVariant2()
		if os.clock() - lastShot < Config.Variant2Cooldown then return end

		local origin = camera.CFrame.Position
		local direction = camera.CFrame.LookVector * Config.MaxDistance
		local result = castSolid(origin, direction, buildIgnore(character, entrance and entrance.model, exitP and exitP.model))
		if not result or not result.Instance or not result.Instance:IsA("BasePart") then
			playSound(Config.SoundInvalid, 1.1, handle); Z.fala.dizer("erro")
			return
		end

		local hitPos = liftWallPortalAboveFloor(result.Position, result.Normal)
		local normal = result.Normal
		local hitPart = result.Instance

		lastShot = os.clock()
		local myShot = shotId
		local slot = nextSlot
		nextSlot = (slot == 1) and 2 or 1

		faceToward(hitPos)
		local muzzlePos = getMuzzlePos()
		shotEffects(muzzlePos)

		launchProjectile(muzzlePos, hitPos, function()
			if myShot ~= shotId or not Z.alive then return end
			flashAt(hitPos, 1.6)
			local cf = computeExitCF(hitPos, normal)
			closeSlot(slot)
			local P = newPortal(cf, hitPart)
			if slot == 1 then entrance = P else exitP = P end
			openRipple(cf)
			disarmed = nil
			State.watchIdle(function()
				return Z.alive and ((slot == 1) and entrance or exitP) == P
			end, function() closeSlot(slot) end)
		end)
	end

	local function findBackFace(hitPos, normal, hitPart)
		local T = Config.Variant15MaxThickness
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = {hitPart}
		local res = workspace:Raycast(hitPos - normal * T, normal * (T + 0.5), params)
		if not res then return nil end
		local thickness = (hitPos - res.Position):Dot(normal)
		if thickness < 0.2 then return nil end
		return res
	end

	local function fireVariant15()
		if os.clock() - lastShot < Config.ShotCooldown then return end

		local origin = camera.CFrame.Position
		local direction = camera.CFrame.LookVector * Config.MaxDistance
		local result = castSolid(origin, direction, buildIgnore(character, entrance and entrance.model, exitP and exitP.model))

		local cfA, cfB, hostPart
		local fallback = true
		if result and result.Instance and result.Instance:IsA("BasePart") and math.abs(result.Normal.Y) < 0.7 then
			local back = findBackFace(result.Position, result.Normal, result.Instance)
			if back then
				local aPos = liftWallPortalAboveFloor(result.Position, result.Normal)
				local bPos = liftWallPortalAboveFloor(back.Position, back.Normal)
				cfA = computeExitCF(aPos, result.Normal)
				cfB = computeExitCF(bPos, back.Normal)
				hostPart = result.Instance
				fallback = false
			end
		end
		if fallback then
			cfA, cfB = computeStandingPairCF()
		end

		lastShot = os.clock()
		shotId = shotId + 1
		local myShot = shotId
		closePair()

		faceToward(cfA.Position)
		local muzzlePos = getMuzzlePos()
		shotEffects(muzzlePos)

		launchProjectile(muzzlePos, cfA.Position, function()
			if myShot ~= shotId or not Z.alive then return end
			flashAt(cfA.Position, 1.6)
			entrance = newPortal(cfA, hostPart)
			openRipple(cfA)
			disarmed = nil

			State.watchIdle(function() return myShot == shotId and Z.alive end, closeAllPortals)

			task.delay(Config.Variant15Delay, function()
				if myShot ~= shotId or not Z.alive then return end
				local function openB()
					if myShot ~= shotId or not Z.alive then return end
					flashAt(cfB.Position, 1.6)
					exitP = newPortal(cfB, hostPart)
					openRipple(cfB)
				end
				if fallback then
					launchProjectile(cfA.Position, cfB.Position, openB)
				else
					openB()
				end
			end)
		end)
	end

	local function computeNearAt(cf0)
		local look = cf0.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, -1) end
		flat = flat.Unit
		local pos0 = cf0.Position
		local ignore = buildIgnore(character, entrance and entrance.model, exitP and exitP.model)
		local dist = Config.NearPlayerDistance
		local wall = castSolid(pos0, flat * (dist + 1), ignore)
		if wall then
			dist = math.max(wall.Distance - 1.5, 3.6)
		end
		local base = pos0 + flat * dist
		local down = castSolid(base + Vector3.new(0, 2, 0), Vector3.new(0, -14, 0), ignore)
		local groundY = (down and down.Normal.Y > 0.5) and down.Position.Y or (pos0.Y - 3)
		local center = Vector3.new(base.X, groundY + Config.PortalSize.Y / 2 + 0.05, base.Z)
		return CFrame.lookAt(center, center - flat)
	end

	local function homeCFForReturn()
		if Dim.home then return Dim.home end
		local sp = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		if sp then return sp.CFrame * CFrame.new(0, 4, 0) end
		return CFrame.new(0, 10, 0)
	end

	local function fireVariant3Dim()
		if os.clock() - lastShot < Config.ShotCooldown then return end

		local choice = DIM_CHOICES[dimSel]
		local def = choice.def
		if def then
			if Dim.current == def then
				setStatus("Voce ja esta em " .. def.name, false)
				playSound(Config.SoundInvalid, 1.1, handle); Z.fala.dizer("erro")
				return
			end
		elseif not Dim.current then
			setStatus("Voce ja esta no mundo real", false)
			playSound(Config.SoundInvalid, 1.1, handle); Z.fala.dizer("erro")
			return
		end

		lastShot = os.clock()
		shotId = shotId + 1
		local myShot = shotId
		closePair()

		if def then Dim.ensure(def) end

		local entCF = computeEntranceCF()
		faceToward(entCF.Position)
		local muzzlePos = getMuzzlePos()
		shotEffects(muzzlePos)

		launchProjectile(muzzlePos, entCF.Position, function()
			if myShot ~= shotId or not Z.alive then return end
			if def and not Dim.current then Dim.home = rootPart.CFrame end

			flashAt(entCF.Position, 1.6)
			entrance = newPortal(entCF, nil)
			openRipple(entCF)

			local exitCF = def and Dim.arrivalCF(def) or computeNearAt(homeCFForReturn())
			exitP = newPortal(exitCF, nil)
			openRipple(exitCF)
			disarmed = nil
			setStatus("Portal aberto para " .. choice.name, true)
			Z.fala.dizer("dim", { dim = (choice.name:gsub(" %(voltar%)", "")) })

			State.watchIdle(function() return myShot == shotId and Z.alive end, closeAllPortals)
		end)
	end

	local function fireVariant3()
		if v3Mode == "dim" then return fireVariant3Dim() end
		if os.clock() - lastShot < Config.ShotCooldown then return end

		local tRoot, why = getTargetRoot()
		if not tRoot then
			setStatus(why, false)
			playSound(Config.SoundInvalid, 1.1, handle); Z.fala.dizer("erro")
			return
		end

		lastShot = os.clock()
		shotId = shotId + 1
		local myShot = shotId
		closePair()

		local entCF = computeEntranceCF()
		faceToward(entCF.Position)
		local muzzlePos = getMuzzlePos()
		shotEffects(muzzlePos)

		launchProjectile(muzzlePos, entCF.Position, function()
			if myShot ~= shotId or not Z.alive then return end
			local tRoot2, why2 = getTargetRoot()
			if not tRoot2 then
				setStatus(why2, false)
				playSound(Config.SoundInvalid, 1.1, handle); Z.fala.dizer("erro")
				return
			end
			flashAt(entCF.Position, 1.6)
			entrance = newPortal(entCF, nil)
			openRipple(entCF)

			local exitCF = computeNearPlayerCF(tRoot2)
			exitP = newPortal(exitCF, nil)
			openRipple(exitCF)
			disarmed = nil
			setStatus("Portal aberto ate " .. targetPlayer.DisplayName, true)
			Z.fala.dizer("alvo", { alvo = targetPlayer.DisplayName })

			State.watchIdle(function() return myShot == shotId and Z.alive end, closeAllPortals)
		end)
	end

	State.ship = State.buildShipSystem({
		Z = Z, character = character, humanoid = humanoid, rootPart = rootPart, camera = camera,
		track = track, newGui = newGui, playSound = playSound, flashAt = flashAt,
		createPortalModel = createPortalModel, openRipple = openRipple, closePortal = closePortal,
		wobblePortal = wobblePortal,
		closeAllPortals = closeAllPortals,
		hasPortals = function() return entrance ~= nil or exitP ~= nil end,
	})

	if not pcall(function()
		State.key = State.buildKeySystem({
			Z = Z, character = character, humanoid = humanoid, rootPart = rootPart, backpack = backpack,
			track = track, newGui = newGui, playSound = playSound, flashAt = flashAt,
			closePair = closePair, faceToward = faceToward, launchProjectile = launchProjectile,
		})
	end) then
		warnRG("a Chave da Nave nao carregou")
	end

	local function fire()
		if not isEquipped or not Z.alive then return end
		if humanoid.Health <= 0 then return end
		if variant == 1.5 then
			fireVariant15()
		elseif variant == 2 then
			fireVariant2()
		elseif variant == 3 then
			fireVariant3()
		else
			fireVariant1()
		end
	end

	if Config.MuzzleCalibrate then
		local dot = Instance.new("Part")
		dot.Name = "RickMuzzleDot"
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.new(0.25, 0.25, 0.25)
		dot.Material = Enum.Material.Neon
		dot.Color = Color3.fromRGB(255, 40, 40)
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanQuery = false
		dot.CanTouch = false
		dot.CastShadow = false
		Z.muzzleDot = dot

		track(RunService.RenderStepped:Connect(function()
			if isEquipped and Z.alive and handle and handle.Parent then
				dot.CFrame = CFrame.new(getMuzzlePos())
				dot.Parent = workspace
			else
				dot.Parent = nil
			end
		end))

		local STEP = 0.1
		track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed or not isEquipped then return end
			local k = input.KeyCode
			local o = Config.MuzzleOffset
			local changed = true
			if k == Enum.KeyCode.L then o = o + Vector3.new(STEP, 0, 0)
			elseif k == Enum.KeyCode.J then o = o - Vector3.new(STEP, 0, 0)
			elseif k == Enum.KeyCode.O then o = o + Vector3.new(0, STEP, 0)
			elseif k == Enum.KeyCode.U then o = o - Vector3.new(0, STEP, 0)
			elseif k == Enum.KeyCode.I then o = o + Vector3.new(0, 0, STEP)
			elseif k == Enum.KeyCode.K then o = o - Vector3.new(0, 0, STEP)
			elseif k == Enum.KeyCode.H then Config.MuzzleFlip = not Config.MuzzleFlip
			elseif k == Enum.KeyCode.P then
				local txt = string.format("MuzzleFlip = %s,\nMuzzleOffset = Vector3.new(%.2f, %.2f, %.2f),",
					tostring(Config.MuzzleFlip), o.X, o.Y, o.Z)
				warnRG("valores do muzzle:\n" .. txt)
				pcall(function() setclipboard(txt) end)
				changed = false
			else
				changed = false
			end
			if changed then Config.MuzzleOffset = o end
		end))
	end

	fireBtn.MouseButton1Click:Connect(fire)
	closeBtn.MouseButton1Click:Connect(closeAllPortals)

	track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not isEquipped then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			fire()
		elseif input.KeyCode == Enum.KeyCode.X then
			closeAllPortals()
		end
	end))

	track(tool.Equipped:Connect(function()
		isEquipped = true
		removeHolster()
		aimDot.Visible = true
		fireBtn.Visible = true
		closeBtn.Visible = true
		refreshVariantUI()
		selectedFrame.Visible = true
		playSound(Config.SoundEquip, 1, handle)
		Z.fala.dizer("equip")
	end))

	track(tool.Unequipped:Connect(function()
		isEquipped = false
		aimDot.Visible = false
		fireBtn.Visible = false
		closeBtn.Visible = false
		variantMenuOpen = false
		pcall(function() nameBox:ReleaseFocus() end)
		refreshVariantUI()
		selectedFrame.Visible = false
		createHolster()
	end))

	track(humanoid.Died:Connect(function()
		isEquipped = false
		aimDot.Visible = false
		pcall(function() Z.fala.parar() end)
		pcall(function() if State.ship then State.ship.onDeath() end end)
		closeAllPortals()
		pcall(releasePortalWalk)
		refreshVariantUI()
		removeHolster()
		pcall(restoreScale)
	end))

	local lastErr = 0
	pcall(function() RunService:UnbindFromRenderStep(STEP_NAME) end)
	RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value - 1, function()
		if not Z.alive then return end
		local okStep, err = pcall(function()
			updatePortalsPosition()
			checkPortalTouch()
			Dim.update()
		end)
		if not okStep and os.clock() - lastErr > 5 then
			lastErr = os.clock()
			warnRG("erro no loop:", err)
		end
	end)

	createHolster()

	task.spawn(function()
		while Z.alive and scriptAlive and character and character.Parent do
			task.wait(0.5)
			if not (Z.alive and scriptAlive and character.Parent) then break end
			local needRebuild = false
			local curCam = workspace.CurrentCamera
			if curCam and curCam ~= camera then camera = curCam end
			if State.rebuilds > 0 and os.clock() - (State.lastRebuild or 0) > 30 then State.rebuilds = 0 end

			if tool.Parent ~= backpack and tool.Parent ~= character then
				local okP = pcall(function() tool.Parent = backpack end)
				if not okP or tool.Parent ~= backpack then needRebuild = true end
			end

			if not needRebuild then
				for _, g in ipairs(myGuis) do
					if not g.Parent then parentGui(g) end
					if not g.Parent then needRebuild = true end
				end
			end

			if needRebuild then
				if State.rebuilds < 3 then
					State.rebuilds = State.rebuilds + 1
					State.lastRebuild = os.clock()
					task.defer(safeSetup, character)
				end
				break
			end
		end
	end)

	State.cleanup = function()
		Z.alive = false
		for _, c in ipairs(Z.conns) do
			pcall(function() c:Disconnect() end)
		end
		Z.conns = {}
		pcall(function() RunService:UnbindFromRenderStep(STEP_NAME) end)
		pcall(removeHolster)
		pcall(restoreScale)
		pcall(releasePortalWalk)
		pcall(restoreOffHand)
		pcall(restoreArmAim)
		pcall(releaseSevered)
		pcall(function() if Z.bloodFolder then Z.bloodFolder:Destroy() end end)
		pcall(Dim.destroy)
		pcall(function() if State.key then State.key.destroy(); State.key = nil end end)
		pcall(function() if State.ship then State.ship.destroy(); State.ship = nil end end)
		pcall(function() if State.drinkStop then State.drinkStop() end end)
		State.morty = nil
		pcall(function() Z.fala.destruir() end)
		pcall(stopCamSlide)
		if Z.muzzleDot then pcall(function() Z.muzzleDot:Destroy() end) end
		shotId = shotId + 1
		for _, P in ipairs({entrance, exitP}) do
			if P then pcall(function() P.model:Destroy() end) end
		end
		entrance, exitP = nil, nil
		for _, g in ipairs(myGuis) do
			pcall(function() g:Destroy() end)
		end
		pcall(function() tool:Destroy() end)
	end
end

safeSetup = function(character)
	if not scriptAlive then return end
	local okS, err = pcall(setupRickGun, character)
	if not okS then
		warnRG("erro ao montar a Rick Portal Gun:", err)
	end
end

trackRoot(player.CharacterAdded:Connect(function(char)
	State.rebuilds = 0
	task.spawn(safeSetup, char)
end))

if player.Character then
	task.spawn(safeSetup, player.Character)
end

genv[CLEANUP_KEY] = function()
	scriptAlive = false
	for _, c in ipairs(rootConns) do
		pcall(function() c:Disconnect() end)
	end
	if State.cleanup then
		local f = State.cleanup
		State.cleanup = nil
		pcall(f)
	end
	pcall(function() RunService:UnbindFromRenderStep(STEP_NAME) end)
end

end, function(e) return debug.traceback(tostring(e), 2) end)
if not __ok then pcall(warn, "[RickPortalGun] erro fatal:", __err) end
