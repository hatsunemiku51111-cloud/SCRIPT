
local ok0, err0 = pcall(function()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
if not game:IsLoaded() then game.Loaded:Wait() end
local player = Players.LocalPlayer
while not player do task.wait(); player = Players.LocalPlayer end

if _G.__MOTO_JXZ_CLEANUP then pcall(_G.__MOTO_JXZ_CLEANUP) end

local Config = {
	Scale = 1.25,
	BodyColor = Color3.fromRGB(70, 12, 120),
	AccentColor = Color3.fromRGB(255, 204, 0),

	TopSpeed = 210,
	Thrust = 34,
	ReverseTop = 28,
	ReverseAccel = 16,
	BrakePower = 80,
	Grip = 9,
	RollK = 0.6,
	StepUp = 1.6,
	GravMul = 1.15,
	SpeedMul = 1.0,

	TurnRate = 2.1,
	TurnSpeedRef = 90,
	ForkSteer = 0.5,
	MaxLean = 0.85,

	Wheelbase = 5.6,

	Jump = { Enabled = true, Tol = 0.8, MinVy = 10, MaxVy = 300, Gain = 1.0, LandLoss = 0.15, LandSus = 40, AirK = 6 },

	Susp = {
		BodyK = 110, BodyC = 9, StopAt = -1.0, StopK = 420, Min = -1.3, Max = 0.9,
		PitchK = 60, PitchC = 7.7,
		RollK = 70, RollC = 8,
		FrontK = 150, FrontC = 11, TravelF = 0.9, ExtendF = 0.4,
		RearK = 180, RearC = 12, TravelR = 0.8, ExtendR = 0.3,
		BrakeTransfer = 0.010,
		AccelTransfer = 0.008,
		LeanP = 0.0012,
	},

	SitRise = 1.05,
	SeatZ = 1.3,
	SitPitch = -0.2,

	LimbAnim = true,
	DriveAnim = {
		Enabled = true,
		GripReach = 1.0,
		BrakeLean = 0.22,
		BrakeArmPull = 0.08,
		LookLean = 1.0,   -- 1.0 = cabeca cancela 100% o lean do tronco (olha pra frente)
		LegBend = 1.0,
	},

	Headlight = { Range = 70, Brightness = 3, Angle = 70 },

	UseHiddenGui = true,
	SoundLand = "rbxassetid://7340406550",
	SoundIdle = "rbxassetid://6399923126",
	SoundRun = "rbxassetid://82036216654849",
	VolIdle = 0.22,
	VolRun = 0.2,
}
local S = Config.Scale

local V3 = Vector3.new
local exp, sin, cos, tan = math.exp, math.sin, math.cos, math.tan
local atan, atan2 = math.atan, math.atan2
local function clamp(x, a, b) return math.max(a, math.min(b, x)) end

local conns = {}
local function track(cn) conns[#conns + 1] = cn return cn end

local function getGuiParent()
	if Config.UseHiddenGui then
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
end
local function playSound(id, vol, pitch)
	if not id then return end
	local snd
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = vol or 0.6
		s.PlaybackSpeed = pitch or 1
		s.Parent = SoundService
		s:Play()
		Debris:AddItem(s, 8)
		snd = s
	end)
	return snd
end
local controls = nil
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
	local x = (UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
	local z = (UIS:IsKeyDown(Enum.KeyCode.S) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.W) and 1 or 0)
	return V3(x, 0, z)
end
local function charParts()
	local ch = player.Character
	if not ch then return nil end
	local hum = ch:FindFirstChildOfClass("Humanoid")
	local rp = ch:FindFirstChild("HumanoidRootPart")
	if hum and rp and hum.Health > 0 then return ch, hum, rp end
	return nil
end

local R = 1.35
local FA, RA = 0.9, 1.15
local FCEN = V3(0, R, -2.8)
local RCEN = V3(0, R, 2.8)
local HEAD = V3(0, 3.7, -1.5)
local dF = FCEN - HEAD
local RAKE = atan2(-dF.Z, -dF.Y)
local FL = dF.Magnitude
local PIV = V3(0, 1.5, 0.9)
local ARM_Z = RCEN.Z - PIV.Z
local ARM_Y = R - PIV.Y
local SEAT_TOP = 3.03
local SHOCK_A = V3(0, 2.55, 0.55)
local SHOCK_B = V3(0, 0.35, 0.55)

local PURPLE = Config.BodyColor
local YEL = Config.AccentColor
local BLACK = Color3.fromRGB(14, 14, 17)
local DARK = Color3.fromRGB(30, 31, 36)
local CARBON = Color3.fromRGB(22, 24, 28)
local CHROME = Color3.fromRGB(196, 200, 207)
local DISC = Color3.fromRGB(150, 152, 158)
local RED_DIM = Color3.fromRGB(70, 0, 0)
local RED_HI = Color3.fromRGB(255, 25, 25)
local WHITE_LED = Color3.fromRGB(235, 245, 255)
local SP = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal
local NEON = Enum.Material.Neon
local CYL = Enum.PartType.Cylinder

local c = nil
local saved = nil
local held = { brake = false, brakeUi = false }
local hud = nil
local sRun, sIdle = nil, nil

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.IgnoreWater = true

local function buildModel()
	local model = Instance.new("Model")
	model.Name = "MotoRoxa_JXz"

	local function sCF(cf)
		local p = cf.Position
		return CFrame.new(p.X * S, p.Y * S, p.Z * S) * (cf - p)
	end
	local function newPart(name, size, color, mat, shape, refl, trans, cls)
		local p = Instance.new(cls or "Part")
		p.Name = name
		p.Size = V3(size.X * S, size.Y * S, size.Z * S)
		p.Color = color
		p.Material = mat or SP
		if shape then p.Shape = shape end
		p.Reflectance = refl or 0
		p.Transparency = trans or 0
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local function weld(p0, p1, c0)
		local w = Instance.new("Weld")
		w.Part0 = p0
		w.Part1 = p1
		w.C0 = c0
		w.Parent = p1
		return w
	end
	local function add(parent, name, size, cf, color, mat, shape, refl, trans)
		local p = newPart(name, size, color, mat, shape, refl, trans)
		local w = weld(parent, p, sCF(cf))
		return p, w
	end
	local function cylX(parent, name, len, d, cf, color, mat, refl)
		return add(parent, name, V3(len, d, d), cf, color, mat, CYL, refl)
	end
	local function cylY(parent, name, len, d, cf, color, mat, refl)
		return add(parent, name, V3(len, d, d), cf * CFrame.Angles(0, 0, math.pi / 2), color, mat, CYL, refl)
	end
	local function cylZ(parent, name, len, d, cf, color, mat, refl)
		return add(parent, name, V3(len, d, d), cf * CFrame.Angles(0, math.pi / 2, 0), color, mat, CYL, refl)
	end
	local function ell(parent, name, size, cf, color, mat, refl, trans)
		local p, w = add(parent, name, size, cf, color, mat, nil, refl, trans)
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
		return p, w
	end
	local function ball(parent, name, d, pos, color, mat, refl)
		return ell(parent, name, V3(d, d, d), CFrame.new(pos), color, mat, refl)
	end
	local function tube(parent, name, p0, p1, d, color, mat, refl)
		local len = (p1 - p0).Magnitude
		if len < 0.001 then return end
		local dir = (p1 - p0) / len
		local upv = math.abs(dir.Y) > 0.98 and V3(0, 0, 1) or V3(0, 1, 0)
		return add(parent, name, V3(len, d, d), CFrame.lookAt((p0 + p1) / 2, p1, upv) * CFrame.Angles(0, math.pi / 2, 0), color, mat, CYL, refl)
	end

	local WTALL = 1
	local function detectWedge()
		pcall(function()
			local w = Instance.new("WedgePart")
			w.Size = V3(2, 2, 2)
			w.Anchored = true
			w.CanQuery = true
			w.CFrame = CFrame.new(0, 30000, 0)
			w.Parent = workspace
			local pr = RaycastParams.new()
			pr.FilterType = Enum.RaycastFilterType.Include
			pr.FilterDescendantsInstances = { w }
			local hb = workspace:Raycast(V3(0, 30010, 0.7), V3(0, -20, 0), pr)
			local hf = workspace:Raycast(V3(0, 30010, -0.7), V3(0, -20, 0), pr)
			w:Destroy()
			if hb and hf then WTALL = (hb.Position.Y > hf.Position.Y) and 1 or -1 end
		end)
	end
	local function wedge(parent, name, size, cf, color, mat, refl, trans)
		local flip = (WTALL == 1) and CFrame.new() or CFrame.Angles(0, math.pi, 0)
		local p = newPart(name, size, color, mat, nil, refl, trans, "WedgePart")
		weld(parent, p, sCF(cf * flip))
		return p
	end
	local function bar(parent, name, p0, p1, th, color, mat, refl)
		local len = (p1 - p0).Magnitude
		if len < 0.001 then return end
		local dir = (p1 - p0) / len
		local upv = math.abs(dir.Y) > 0.98 and V3(0, 0, 1) or V3(0, 1, 0)
		return (add(parent, name, V3(th, th, len), CFrame.lookAt((p0 + p1) / 2, p1, upv), color, mat, nil, refl))
	end

	local HIGH = Color3.fromRGB(135, 52, 215)
	local DEEP = Color3.fromRGB(40, 5, 72)
	local GREY = Color3.fromRGB(120, 122, 128)
	local GOLD = Color3.fromRGB(196, 140, 40)
	local GLASS = Color3.fromRGB(12, 14, 22)
	local ORANGE = Color3.fromRGB(255, 120, 0)

	local M = {}
	M.model = model
	M.leds = {}
	M.tails = {}

	local root = newPart("Root", V3(1, 1, 1), PURPLE, SP, nil, 0, 1)
	root.Anchored = true
	model.PrimaryPart = root
	M.root = root

	local PI = math.pi
	detectWedge()

	wedge(root, "Queixo", V3(0.9, 0.8, 1.7), CFrame.new(0, 2.75, -2.0), CARBON, SP, 0.1)

	add(root, "Quilha", V3(1.0, 0.3, 2.4), CFrame.new(0, 0.85, 0.2), CARBON, SP, nil, 0.1)

	M.leds = {}
	local function ledBar(p0, p1)
		local b = bar(root, "LED", p0, p1, 0.07, WHITE_LED, NEON)
		M.leds[#M.leds + 1] = b
		return b
	end
	for _, sx in ipairs({ -1, 1 }) do
		wedge(root, "Bochecha", V3(0.4, 0.5, 1.0), CFrame.new(sx * 0.82, 3.45, -2.35), PURPLE, METAL, 0.3)
		local a = ledBar(V3(0, 3.22, -3.17), V3(sx * 0.45, 3.25, -3.12))
		ledBar(V3(sx * 0.45, 3.25, -3.12), V3(sx * 0.95, 3.33, -2.88))
		if sx == -1 then M.ledL = a else M.ledR = a end
	end
	local lamp = add(root, "Luz", V3(0.2, 0.2, 0.2), CFrame.new(0, 3.4, -3.2), WHITE_LED, SP, nil, 0, 1)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Range = Config.Headlight.Range
	spot.Brightness = Config.Headlight.Brightness
	spot.Angle = Config.Headlight.Angle
	spot.Color = Color3.fromRGB(235, 244, 255)
	spot.Enabled = false
	spot.Parent = lamp
	M.spot = spot

	local function shield(x, y, z, k, sx)
		local d45 = CFrame.Angles(math.pi / 4, 0, 0)
		add(root, "EmblemaContorno", V3(0.04 * k, 0.42 * k, 0.58 * k), CFrame.new(x, y + 0.13 * k, z), BLACK, SP)
		add(root, "EmblemaContorno", V3(0.04 * k, 0.42 * k, 0.42 * k), CFrame.new(x, y - 0.05 * k, z) * d45, BLACK, SP)
		local xe = x + sx * 0.012 * k
		add(root, "Emblema", V3(0.05 * k, 0.36 * k, 0.5 * k), CFrame.new(xe, y + 0.14 * k, z), YEL, SP)
		add(root, "Emblema", V3(0.05 * k, 0.34 * k, 0.34 * k), CFrame.new(xe, y - 0.04 * k, z) * d45, YEL, SP)
		local hx = x + sx * 0.035 * k
		local function hp(n, s, off, rx)
			add(root, n, V3(0.045 * k, s.Y * k, s.Z * k), CFrame.new(hx, y + off.Y * k, z + off.Z * k) * CFrame.Angles(rx or 0, 0, 0), BLACK, SP)
		end
		hp("CavaloCorpo", V3(0, 0.12, 0.26), V3(0, 0.07, 0.02))
		hp("CavaloPescoco", V3(0, 0.22, 0.07), V3(0, 0.2, -0.1), -0.5)
		hp("CavaloCabeca", V3(0, 0.09, 0.13), V3(0, 0.3, -0.19))
		hp("CavaloPernaT", V3(0, 0.2, 0.055), V3(0, -0.06, 0.13), 0.4)
		hp("CavaloPernaF", V3(0, 0.2, 0.05), V3(0, 0.08, -0.19), -1.0)
		hp("CavaloRabo", V3(0, 0.2, 0.045), V3(0, 0.1, 0.22), 0.9)
	end

	for _, sx in ipairs({ -1, 1 }) do
		add(root, "VentCarbono", V3(0.06, 0.7, 1.1), CFrame.new(sx * 0.95, 2.45, -0.3), CARBON, SP, nil, 0.1)
		for i = 1, 5 do
			add(root, "VentRisco", V3(0.02, 0.03, 0.95), CFrame.new(sx * 0.985, 2.15 + i * 0.11, -0.3) * CFrame.Angles(0.6, 0, 0), GREY, METAL, nil, 0.3)
		end
		shield(sx * 0.93, 2.75, -1.45, 1.0, sx)
		for i = 0, 5 do
			cylX(root, "Rebite", 0.05, 0.07, CFrame.new(sx * 0.93, 2.15, -1.8 + i * 0.45), YEL, SP)
		end
		cylX(root, "Pedaleira", 0.5, 0.2, CFrame.new(sx * 1.05, 1.05, 1.7), BLACK, METAL, 0.3)
		tube(root, "PedaleiraBraco", V3(sx * 0.8, 1.35, 1.5), V3(sx * 0.95, 1.05, 1.7), 0.14, DARK, METAL, 0.2)
		tube(root, "Subchassi", V3(sx * 0.45, 2.7, 0.8), V3(sx * 0.55, 2.55, 3.1), 0.14, DARK, METAL, 0.2)
	end
	add(root, "EmblemaNariz", V3(0.18, 0.03, 0.22), CFrame.new(0, 3.84, -2.3) * CFrame.Angles(-0.494, 0, 0), YEL, SP)

	add(root, "Banco", V3(1.1, 0.28, 1.8), CFrame.new(0, 2.92, 1.2), BLACK, SP, nil, 0.1)
	add(root, "BancoFaixa", V3(0.6, 0.03, 1.5), CFrame.new(0, 3.07, 1.2), DARK, SP)
	add(root, "ParalamaTras", V3(1.6, 0.12, 1.8), CFrame.new(0, 2.9, 3.3), PURPLE, METAL, nil, 0.3)
	add(root, "RabetaFaixa", V3(1.4, 0.22, 0.06), CFrame.new(0, 3.12, 4.21), BLACK, SP, nil, 0.2)
	M.tails = {}
	do
		local pts = { { -0.75, 3.27 }, { -0.4, 3.38 }, { 0, 3.42 }, { 0.4, 3.38 }, { 0.75, 3.27 } }
		for i = 1, 4 do
			local t = bar(root, "Lanterna", V3(pts[i][1], pts[i][2], 4.235), V3(pts[i + 1][1], pts[i + 1][2], 4.235), 0.07, RED_DIM, NEON)
			M.tails[#M.tails + 1] = t
		end
	end
	M.tail = M.tails[1]

	cylX(root, "Carter", 1.4, 1.5, CFrame.new(0, 1.5, 0.2), BLACK, METAL, 0.15)
	for _, sx in ipairs({ -1, 1 }) do
		cylX(root, "CarterTampa", 0.1, 1.3, CFrame.new(sx * 0.74, 1.5, 0.2), BLACK, METAL, 0.25)
		cylX(root, "CarterAnel", 0.06, 1.0, CFrame.new(sx * 0.8, 1.5, 0.2), DARK, METAL, 0.3)
		cylX(root, "CarterCentro", 0.07, 0.44, CFrame.new(sx * 0.82, 1.5, 0.2), YEL, METAL, 0.3)
		add(root, "CarterEstrela", V3(0.075, 0.3, 0.05), CFrame.new(sx * 0.82, 1.5, 0.2), BLACK, SP)
		add(root, "CarterEstrela", V3(0.075, 0.05, 0.3), CFrame.new(sx * 0.82, 1.5, 0.2), BLACK, SP)
		for i = 0, 11 do
			local a = i * (2 * math.pi / 12)
			cylX(root, "CarterParafuso", 0.07, 0.075, CFrame.new(sx * 0.8, 1.5 + 0.58 * cos(a), 0.2 + 0.58 * sin(a)), CHROME, METAL, 0.5)
		end
	end
	for _, d in ipairs({ { -0.6, -0.31 }, { 0.6, 0.71 } }) do
		local pitch, cz = d[1], d[2]
		local cfc = CFrame.new(0, 2.24, cz) * CFrame.Angles(pitch, 0, 0)
		cylY(root, "Cilindro", 1.1, 0.6, cfc, BLACK, METAL, 0.2)
		for f = -2, 2 do
			cylY(root, "CilindroAleta", 0.05, 0.84, cfc * CFrame.new(0, f * 0.2, 0), DARK, METAL, 0.3)
		end
		cylY(root, "CilindroCabeca", 0.18, 0.74, cfc * CFrame.new(0, 0.62, 0), DARK, METAL, 0.3)
		cylY(root, "CilindroTampa", 0.06, 0.46, cfc * CFrame.new(0, 0.73, 0), YEL, METAL, 0.3)
	end
	add(root, "Barriga", V3(1.0, 0.45, 2.4), CFrame.new(0, 0.85, 0.2), CARBON, SP, nil, 0.1)
	for _, sx in ipairs({ -1, 1 }) do
		local pts = {
			V3(sx * 0.4, 2.1, -0.95), V3(sx * 0.58, 1.4, -1.05), V3(sx * 0.75, 0.9, -0.6),
			V3(sx * 1.05, 0.82, 0.1), V3(sx * 1.2, 0.8, 0.8),
		}
		for i = 1, #pts - 1 do
			tube(root, "Coletor", pts[i], pts[i + 1], 0.24, DARK, METAL, 0.3)
			ball(root, "ColetorJunta", 0.25, pts[i + 1], DARK, METAL, 0.3)
		end
		cylZ(root, "Escape", 1.0, 0.44, CFrame.new(sx * 1.2, 0.8, 1.0), BLACK, METAL, 0.25)
		cylZ(root, "PonteiraEscape", 0.2, 0.48, CFrame.new(sx * 1.2, 0.8, 1.6), CHROME, METAL, 0.5)
	end

	local fork = newPart("Fork", V3(0.2, 0.2, 0.2), BLACK, SP, nil, 0, 1)
	M.wFork = weld(root, fork, sCF(CFrame.new(HEAD) * CFrame.Angles(RAKE, 0, 0)))
	local slider = newPart("Slider", V3(0.2, 0.2, 0.2), BLACK, SP, nil, 0, 1)
	M.wSlider = weld(fork, slider, CFrame.new(0, -FL * S, 0))

	local function caliper(parent, sx)
		local xc = 1.1
		add(parent, "PincaCorpo", V3(0.22, 0.62, 0.84), CFrame.new(sx * xc, 0.02, 0.78), YEL, METAL, nil, 0.3)
		add(parent, "PincaTopo", V3(0.4, 0.2, 0.7), CFrame.new(sx * (xc - 0.1), 0.3, 0.78), YEL, METAL, nil, 0.3)
		add(parent, "PincaFaixa", V3(0.02, 0.1, 0.5), CFrame.new(sx * (xc + 0.115), 0.02, 0.78), BLACK, SP)
		for i = -1, 1 do
			cylX(parent, "PincaPistao", 0.05, 0.15, CFrame.new(sx * (xc + 0.1), -0.2 + (i + 1) * 0.23, 0.55), CHROME, METAL, 0.4)
		end
		tube(parent, "Flexivel", V3(sx * 1.14, 0.35, 0.78), V3(sx * 1.14, 1.4, 0.55), 0.06, BLACK, SP)
	end
	for _, sx in ipairs({ -1, 1 }) do
		cylY(fork, "TuboSuperior", 1.9, 0.44, CFrame.new(sx * 1.38, -1.05, 0), BLACK, METAL, 0.25)
		cylY(slider, "PernaInferior", 1.8, 0.3, CFrame.new(sx * 1.38, 0.8, 0), CHROME, METAL, 0.5)
		ball(slider, "EixoLuva", 0.4, V3(sx * 1.3, 0, 0), BLACK, METAL, 0.3)
		cylX(slider, "EixoFrente", 0.5, 0.26, CFrame.new(sx * 1.2, 0, 0), BLACK, METAL, 0.3)
		caliper(slider, sx)
	end
	add(fork, "MesaSuperior", V3(3.3, 0.3, 0.6), CFrame.new(0, -0.1, 0), DARK, METAL, nil, 0.25)
	add(fork, "MesaInferior", V3(3.1, 0.26, 0.5), CFrame.new(0, -0.85, 0), DARK, METAL, nil, 0.25)
	add(fork, "Riser", V3(0.34, 0.5, 0.34), CFrame.new(0, 0.15, 0.1), DARK, METAL, nil, 0.2)

	for _, sx in ipairs({ -1, 1 }) do
		local p0 = V3(sx * 0.1, 0.38, 0.35)
		local p1 = V3(sx * 1.0, 0.42, 0.4)
		local p2 = V3(sx * 1.8, 0.58, 0.66)
		tube(fork, "Guidao", p0, p1, 0.14, BLACK, METAL, 0.2)
		tube(fork, "Guidao", p1, p2, 0.14, BLACK, METAL, 0.2)
		ball(fork, "GuidaoJunta", 0.15, p1, BLACK, METAL, 0.2)
		tube(fork, "Manopla", V3(sx * 1.75, 0.57, 0.65), V3(sx * 2.25, 0.66, 0.85), 0.22, BLACK, SP)
		add(fork, "Comando", V3(0.2, 0.16, 0.34), CFrame.new(sx * 1.1, 0.46, 0.42), BLACK, SP, nil, 0.2)
		tube(fork, "Manete", V3(sx * 1.6, 0.5, 0.5), V3(sx * 1.85, 0.42, -0.2), 0.07, CHROME, METAL, 0.4)
	end
	add(fork, "Painel", V3(0.95, 0.2, 0.6), CFrame.new(0, 0.52, 0.12), BLACK, SP, nil, 0.15)
	ball(fork, "PainelAlerta", 0.07, V3(0.28, 0.65, 0.12), Color3.fromRGB(255, 40, 40), NEON)

	local rakeCF = CFrame.Angles(RAKE, 0, 0)
	local wc = V3(0, -FL, 0)
	local Rf = R + 0.26
	local nSeg = 26
	local a0, a1 = -1.1, 1.6
	local da = (a1 - a0) / nSeg
	local segL = Rf * da * 1.2
	for i = 0, nSeg - 1 do
		local a = a0 + (i + 0.5) * da
		local rot = rakeCF:Inverse() * CFrame.Angles(-a, 0, 0)
		local pw = V3(0, Rf * cos(a), -Rf * sin(a))
		add(fork, "ParalamaArco", V3(1.95, 0.08, segL), CFrame.new(wc + rakeCF:VectorToObjectSpace(pw)) * rot, PURPLE, METAL, nil, 0.3)
		local h = 0.62 * math.max(0.1, cos(((a - 0.25) / 1.35) * (math.pi / 2)))
		local pw2 = V3(0, (Rf - h / 2) * cos(a), -(Rf - h / 2) * sin(a))
		for _, sx in ipairs({ -1, 1 }) do
			add(fork, "ParalamaAba", V3(0.08, h, segL), CFrame.new(wc + rakeCF:VectorToObjectSpace(pw2) + V3(sx * 0.97, 0, 0)) * rot, PURPLE, METAL, nil, 0.3)
		end
	end

	local TIRE = Color3.fromRGB(22, 22, 25)
	local GROOVE = Color3.fromRGB(6, 6, 7)
	local function buildTire(core, A, n, G)
		local Rc = 0.95
		local B = R - Rc
		local w = 2 * A / n
		for i = 1, n do
			local x = -A + (i - 0.5) * w
			local u = x / A
			local rad = Rc + B * math.sqrt(math.max(1 - u * u, 0))
			cylX(core, "Banda", w * 1.12, 2 * rad, CFrame.new(x, 0, 0), TIRE, SP)
		end
		for gi = 0, G - 1 do
			local th0 = gi * (2 * math.pi / G)
			for _, sx in ipairs({ -1, 1 }) do
				local prev = nil
				local off = (sx == 1) and (math.pi / G) or 0
				for k = 0, 5 do
					local t = k / 5
					local phi = 0.08 + t * 1.28
					local th = th0 + off + sx * 0.9 * t * t
					local rho = Rc + B * cos(phi) + 0.012
					local pt = V3(sx * A * sin(phi), rho * cos(th), rho * sin(th))
					if prev then
						local mid = (prev + pt) / 2
						local len = (pt - prev).Magnitude
						add(core, "Sulco", V3(0.05, 0.05, len + 0.03), CFrame.lookAt(mid, pt, V3(1, 0, 0)), GROOVE, SP)
					end
					prev = pt
				end
			end
		end
	end
	local function spokes(core, x, n, r0, r1, wd, th, color)
		for i = 0, n - 1 do
			local a = i * (2 * math.pi / n)
			for _, dd in ipairs({ -0.11, 0.11 }) do
				add(core, "Raio", V3(th, r1 - r0, wd), CFrame.Angles(a + dd, 0, 0) * CFrame.new(x, (r0 + r1) / 2, 0), color, METAL, nil, 0.3)
			end
		end
	end
	local function wheelSide(core, A, sx, kind)
		local function X(d) return sx * (A + d) end
		cylX(core, "Aro", 0.06, 1.94, CFrame.new(X(0.03), 0, 0), DARK, METAL, 0.25)
		cylX(core, "Fundo", 0.05, 1.8, CFrame.new(X(0.06), 0, 0), BLACK, METAL, 0.1)
		if kind == "disc" then
			cylX(core, "Disco", 0.05, 1.66, CFrame.new(X(0.09), 0, 0), DISC, METAL, 0.45)
			cylX(core, "DiscoMiolo", 0.055, 1.14, CFrame.new(X(0.095), 0, 0), GOLD, METAL, 0.45)
			for bi = 0, 9 do
				local ang = bi * (2 * math.pi / 10)
				cylX(core, "DiscoParafuso", 0.02, 0.07, CFrame.new(X(0.13), 0.5 * cos(ang), 0.5 * sin(ang)), BLACK, METAL, 0.3)
			end
			for hi = 0, 23 do
				local ang = hi * (2 * math.pi / 24)
				cylX(core, "Furo", 0.012, 0.075, CFrame.new(X(0.12), 0.65 * cos(ang), 0.65 * sin(ang)), BLACK, SP)
				local ang2 = ang + math.pi / 24
				cylX(core, "Furo", 0.012, 0.05, CFrame.new(X(0.12), 0.76 * cos(ang2), 0.76 * sin(ang2)), BLACK, SP)
			end
			spokes(core, X(0.14), 10, 0.14, 0.6, 0.12, 0.05, DARK)
			for bi = 0, 9 do
				local ang = bi * (2 * math.pi / 10) + 0.18
				cylX(core, "Bobina", 0.06, 0.11, CFrame.new(X(0.145), 0.6 * cos(ang), 0.6 * sin(ang)), CHROME, METAL, 0.5)
			end
		else
			cylX(core, "Coroa", 0.06, 1.56, CFrame.new(X(0.09), 0, 0), BLACK, METAL, 0.3)
			cylX(core, "CoroaMiolo", 0.065, 1.0, CFrame.new(X(0.095), 0, 0), DARK, METAL, 0.2)
			for ti = 0, 35 do
				local a = ti * (2 * math.pi / 36)
				add(core, "Dente", V3(0.07, 0.1, 0.1), CFrame.Angles(a, 0, 0) * CFrame.new(X(0.09), 0.8, 0), BLACK, METAL, nil, 0.2)
			end
			spokes(core, X(0.14), 8, 0.14, 0.5, 0.13, 0.05, DARK)
		end
		cylX(core, "Cubo", 0.14, 0.36, CFrame.new(X(0.14), 0, 0), BLACK, METAL, 0.2)
		cylX(core, "Porca", 0.14, 0.22, CFrame.new(X(0.19), 0, 0), CHROME, METAL, 0.55)
	end

	local fcore = newPart("RodaFrente", V3(0.2, 0.2, 0.2), BLACK, SP, nil, 0, 1)
	M.wFWheel = weld(slider, fcore, CFrame.new())
	buildTire(fcore, FA, 25, 12)
	wheelSide(fcore, FA, -1, "disc")
	wheelSide(fcore, FA, 1, "disc")

	local swing = newPart("Swing", V3(0.2, 0.2, 0.2), BLACK, SP, nil, 0, 1)
	M.wSwing = weld(root, swing, sCF(CFrame.new(PIV)))
	local rcore = newPart("RodaTras", V3(0.2, 0.2, 0.2), BLACK, SP, nil, 0, 1)
	M.wRWheel = weld(swing, rcore, sCF(CFrame.new(0, ARM_Y, ARM_Z)))
	M.rtireBase = CFrame.new(0, ARM_Y * S, ARM_Z * S)
	buildTire(rcore, RA, 29, 14)
	wheelSide(rcore, RA, -1, "sprocket")
	wheelSide(rcore, RA, 1, "disc")

	for _, sx in ipairs({ -1, 1 }) do
		tube(swing, "Braco", V3(sx * 1.56, 0, 0), V3(sx * 1.56, ARM_Y, ARM_Z), 0.34, BLACK, METAL, 0.25)
		cylX(swing, "BracoPivo", 0.4, 0.46, CFrame.new(sx * 1.56, 0, 0), DARK, METAL, 0.3)
		cylX(swing, "BracoEixo", 0.4, 0.44, CFrame.new(sx * 1.56, ARM_Y, ARM_Z), DARK, METAL, 0.3)
	end
	tube(swing, "BracoTravessa", V3(-1.56, 0, 0), V3(1.56, 0, 0), 0.26, BLACK, METAL, 0.25)

	local rod = newPart("AmortHaste", V3(1.0, 0.3, 0.3), DARK, METAL, CYL, 0.3)
	M.wRod = weld(root, rod, CFrame.new())
	M.rod = rod
	local spring = newPart("AmortMola", V3(0.6, 0.46, 0.46), YEL, METAL, CYL, 0.2)
	M.wSpring = weld(root, spring, CFrame.new())
	M.spring = spring

	local BLUE_LED = Color3.fromRGB(150, 205, 255)
	local AMBER = Color3.fromRGB(255, 130, 0)
	local STITCH = Color3.fromRGB(70, 70, 78)

	for _, sx in ipairs({ -1, 1 }) do
		local nC = 20
		local aS, aE = 0.25, 2.0
		local dA = (aE - aS) / nC
		for i = 0, nC - 1 do
			local f = (i + 0.5) / nC
			local a = aS + (i + 0.5) * dA
			local th = 0.12 + 0.62 * math.sin(f * math.pi) ^ 0.8
			local r0 = 1.5
			local rm = r0 + th / 2
			local pos = V3(sx * 0.99, FCEN.Y + rm * cos(a), FCEN.Z + rm * sin(a))
			local cf = CFrame.new(pos) * CFrame.Angles(a, 0, 0)
			add(root, "Crescente", V3(0.12, th, rm * dA * 1.18), cf, PURPLE, METAL, nil, 0.3)
			local ro = r0 + th
			local posO = V3(sx * 1.045, FCEN.Y + ro * cos(a), FCEN.Z + ro * sin(a))
			add(root, "CrescenteBorda", V3(0.03, 0.05, ro * dA * 1.18), CFrame.new(posO) * CFrame.Angles(a, 0, 0), CARBON, SP, nil, 0.1)
			if th > 0.4 then
				local rc = r0 + th * 0.45
				local posC = V3(sx * 1.05, FCEN.Y + rc * cos(a), FCEN.Z + rc * sin(a))
				add(root, "CrescenteCarbono", V3(0.02, th * 0.5, rc * dA * 1.05), CFrame.new(posC) * CFrame.Angles(a, 0, 0), CARBON, SP, nil, 0.05)
				if i % 2 == 0 then
					local rr = r0 + th * 0.8
					local posR = V3(sx * 1.06, FCEN.Y + rr * cos(a), FCEN.Z + rr * sin(a))
					cylX(root, "CrescenteRebite", 0.04, 0.07, CFrame.new(posR), YEL, METAL, 0.3)
				end
			end
		end
		add(root, "CrescenteFundo", V3(0.05, 1.0, 1.2), CFrame.new(sx * 0.88, 1.55, -1.35), BLACK, SP)
	end

	do
		local ctr = V3(0, 4.12, -1.95)
		local rotW = CFrame.Angles(-0.85, 0, 0)
		add(root, "ParaBrisa", V3(1.15, 0.035, 0.85), CFrame.new(ctr) * rotW, GLASS, SP, nil, 0.45, 0.3)
		local zdir = rotW:VectorToWorldSpace(V3(0, 0, 1))
		local pLo = ctr - zdir * 0.425
		local pHi = ctr + zdir * 0.425
		for _, sx in ipairs({ -1, 1 }) do
			bar(root, "ParaBrisaBorda", pLo + V3(sx * 0.575, 0, 0), pHi + V3(sx * 0.575, 0, 0), 0.045, CARBON, SP)
		end
		bar(root, "ParaBrisaTopo", pHi + V3(-0.575, 0, 0), pHi + V3(0.575, 0, 0), 0.045, CARBON, SP)
		bar(root, "ParaBrisaBase", pLo + V3(-0.575, 0, 0), pLo + V3(0.575, 0, 0), 0.06, CARBON, SP)
	end

	for _, sx in ipairs({ -1, 1 }) do
		bar(root, "FarolFundo", V3(0, 3.22, -3.1), V3(sx * 0.45, 3.25, -3.05), 0.17, BLACK, SP, 0.3)
		bar(root, "FarolFundo", V3(sx * 0.45, 3.25, -3.05), V3(sx * 0.95, 3.33, -2.8), 0.17, BLACK, SP, 0.3)
		local b1 = bar(root, "LEDInterno", V3(0.05 * sx, 3.13, -3.15), V3(sx * 0.45, 3.16, -3.1), 0.04, BLUE_LED, NEON)
		local b2 = bar(root, "LEDInterno", V3(sx * 0.45, 3.16, -3.1), V3(sx * 0.9, 3.23, -2.87), 0.04, BLUE_LED, NEON)
		local b3 = bar(root, "LEDPonta", V3(sx * 0.95, 3.33, -2.88), V3(sx * 1.02, 3.42, -2.6), 0.06, WHITE_LED, NEON)
		for _, b in ipairs({ b1, b2, b3 }) do M.leds[#M.leds + 1] = b end
		bar(root, "Sobrancelha", V3(0, 3.38, -3.12), V3(sx * 0.5, 3.4, -3.05), 0.06, CARBON, SP)
		add(root, "EntradaAr", V3(0.02, 0.16, 0.55), CFrame.new(sx * 1.03, 3.45, -2.3) * CFrame.Angles(0.15, 0, 0), BLACK, SP)
		for k = 0, 3 do
			add(root, "EntradaArGrade", V3(0.025, 0.02, 0.5), CFrame.new(sx * 1.035, 3.39 + k * 0.045, -2.3) * CFrame.Angles(0.15, 0, 0), GREY, METAL, nil, 0.3)
		end
	end


	for i = -2, 2 do
		add(root, "BancoCostura", V3(0.02, 0.012, 1.45), CFrame.new(i * 0.2, 3.095, 1.2), STITCH, SP)
	end
	for i = -3, 3 do
		add(root, "BancoCosturaT", V3(0.9, 0.012, 0.02), CFrame.new(0, 3.095, 0.6 + (i + 3) * 0.2), STITCH, SP)
	end
	add(root, "BancoBorda", V3(1.14, 0.03, 1.82), CFrame.new(0, 2.8, 1.2), CARBON, SP, nil, 0.1)

	add(root, "Difusor", V3(1.0, 0.1, 0.9), CFrame.new(0, 2.7, 3.85), CARBON, SP, nil, 0.1)
	for i = -2, 2 do
		add(root, "DifusorAleta", V3(0.03, 0.18, 0.85), CFrame.new(i * 0.2, 2.62, 3.85), CARBON, SP)
	end
	do
		local pts = { { -0.6, 3.2 }, { -0.3, 3.27 }, { 0, 3.3 }, { 0.3, 3.27 }, { 0.6, 3.2 } }
		for i = 1, 4 do
			local t = bar(root, "Lanterna", V3(pts[i][1], pts[i][2], 4.235), V3(pts[i + 1][1], pts[i + 1][2], 4.235), 0.045, RED_DIM, NEON)
			M.tails[#M.tails + 1] = t
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		ell(root, "Pisca", V3(0.12, 0.08, 0.14), CFrame.new(sx * 0.78, 3.12, 4.2), Color3.fromRGB(110, 55, 0), NEON)
		add(root, "RabetaParafuso", V3(0.05, 0.05, 0.02), CFrame.new(sx * 0.55, 3.05, 4.215), CHROME, METAL, nil, 0.5)
	end

	for _, sx in ipairs({ -1, 1 }) do
		cylZ(root, "FiltroOleo", 0.5, 0.34, CFrame.new(sx * 0.32, 0.95, -1.25), GOLD, METAL, 0.45)
		cylZ(root, "FiltroTampa", 0.06, 0.26, CFrame.new(sx * 0.32, 0.95, -1.52), CHROME, METAL, 0.5)
		tube(root, "MangueiraOleo", V3(sx * 0.32, 1.1, -1.1), V3(sx * 0.62, 1.55, -0.75), 0.07, BLACK, SP)
		ball(root, "ConexaoOleo", 0.12, V3(sx * 0.62, 1.55, -0.75), ORANGE, METAL, 0.4)
		tube(root, "CaboVela", V3(sx * 0.18, 2.95, -0.31), V3(sx * 0.5, 2.55, -0.1), 0.04, BLACK, SP)
		tube(root, "CaboVela", V3(sx * 0.18, 2.95, 0.71), V3(sx * 0.5, 2.55, 0.5), 0.04, BLACK, SP)
	end
	for _, d in ipairs({ { -0.6, -0.31 }, { 0.6, 0.71 } }) do
		local cfc = CFrame.new(0, 2.24, d[2]) * CFrame.Angles(d[1], 0, 0)
		for _, sx in ipairs({ -1, 1 }) do
			add(root, "CilindroTirante", V3(0.07, 0.8, 0.07), cfc * CFrame.new(sx * 0.3, 0.15, 0), CHROME, METAL, nil, 0.5)
			cylY(root, "CilindroParafuso", 0.08, 0.1, cfc * CFrame.new(sx * 0.3, 0.7, 0.2), CHROME, METAL, 0.5)
			cylY(root, "CilindroParafuso", 0.08, 0.1, cfc * CFrame.new(sx * 0.3, 0.7, -0.2), CHROME, METAL, 0.5)
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		cylX(root, "CarterAnelOuro", 0.04, 1.2, CFrame.new(sx * 0.785, 1.5, 0.2), GOLD, METAL, 0.45)
		cylX(root, "CarterAnelPreto", 0.05, 1.12, CFrame.new(sx * 0.795, 1.5, 0.2), BLACK, METAL, 0.2)
	end

	for _, sx in ipairs({ -1, 1 }) do
		cylZ(root, "EscapeBanda", 0.08, 0.5, CFrame.new(sx * 1.2, 0.8, 0.65), CHROME, METAL, 0.5)
		cylZ(root, "EscapeBanda", 0.08, 0.5, CFrame.new(sx * 1.2, 0.8, 1.35), CHROME, METAL, 0.5)
		cylZ(root, "EscapeBoca", 0.02, 0.34, CFrame.new(sx * 1.2, 0.8, 1.71), BLACK, SP)
		add(root, "EscapeProtetor", V3(0.05, 0.22, 0.9), CFrame.new(sx * 1.2, 1.07, 1.0), CARBON, SP, nil, 0.1)
		tube(root, "ColetorProtetor", V3(sx * 0.75, 1.0, -0.55), V3(sx * 1.05, 0.95, 0.1), 0.12, CARBON, SP, 0.1)
	end

	for _, sx in ipairs({ -1, 1 }) do
		tube(fork, "EspelhoHaste", V3(sx * 1.55, 0.48, 0.45), V3(sx * 1.75, 0.95, 0.3), 0.05, BLACK, METAL, 0.3)
		ell(fork, "EspelhoCaixa", V3(0.36, 0.2, 0.1), CFrame.new(sx * 1.8, 1.0, 0.3) * CFrame.Angles(-0.3, 0, 0), PURPLE, METAL, 0.3)
		ell(fork, "EspelhoVidro", V3(0.3, 0.15, 0.04), CFrame.new(sx * 1.8, 1.0, 0.345) * CFrame.Angles(-0.3, 0, 0), Color3.fromRGB(150, 160, 175), METAL, 0.6)
		add(fork, "Reservatorio", V3(0.16, 0.14, 0.2), CFrame.new(sx * 1.2, 0.6, 0.5), BLACK, SP, nil, 0.2)
		add(fork, "ReservatorioTampa", V3(0.1, 0.03, 0.12), CFrame.new(sx * 1.2, 0.68, 0.5), YEL, METAL, nil, 0.3)
		for k = 0, 2 do
			ball(fork, "Botao", 0.05, V3(sx * (0.98 + k * 0.1), 0.55, 0.3), CHROME, METAL, 0.5)
		end
		ball(fork, "BotaoInicio", 0.07, V3(sx * 0.9, 0.55, 0.32), Color3.fromRGB(255, 40, 40), NEON)
	end

	for _, sx in ipairs({ -1, 1 }) do
		ball(fork, "TampaGarfo", 0.32, V3(sx * 1.38, -0.08, 0), GOLD, METAL, 0.45)
		cylY(fork, "Ajustador", 0.16, 0.14, CFrame.new(sx * 1.38, 0.06, 0), CHROME, METAL, 0.5)
		cylZ(fork, "ParafusoMesa", 0.12, 0.1, CFrame.new(sx * 1.18, -0.85, 0.3), CHROME, METAL, 0.5)
		cylZ(fork, "ParafusoMesa", 0.12, 0.1, CFrame.new(sx * 1.18, -0.1, 0.3), CHROME, METAL, 0.5)
		cylY(slider, "PernaAnel", 0.06, 0.34, CFrame.new(sx * 1.38, 1.7, 0), GOLD, METAL, 0.4)
		cylY(slider, "PernaAnel", 0.06, 0.34, CFrame.new(sx * 1.38, -0.2, 0), GOLD, METAL, 0.4)
	end
	add(fork, "Painel", V3(0.95, 0.04, 0.6), CFrame.new(0, 0.605, 0.12), CARBON, SP, nil, 0.15)

	do
		local ax, ay, az = 1.34, ARM_Y, ARM_Z
		add(swing, "PincaTras", V3(0.22, 0.42, 0.54), CFrame.new(ax, ay - 0.5, az - 0.5), YEL, METAL, nil, 0.3)
		add(swing, "PincaTrasTopo", V3(0.34, 0.14, 0.46), CFrame.new(ax - 0.08, ay - 0.3, az - 0.5), YEL, METAL, nil, 0.3)
		tube(swing, "PincaBraco", V3(ax, ay, az - 0.1), V3(ax, ay - 0.45, az - 0.55), 0.1, DARK, METAL, 0.3)
		local bx = -1.27
		cylX(swing, "CoroaMotor", 0.1, 0.58, CFrame.new(bx, 0.2, -0.7), CHROME, METAL, 0.5)
		cylX(swing, "EixoMotor", 0.5, 0.16, CFrame.new(-1.0, 0.2, -0.7), DARK, METAL, 0.3)
		bar(swing, "CorreiaTopo", V3(bx, 0.5, -0.7), V3(bx, ay + 0.86, az), 0.09, BLACK, SP)
		bar(swing, "CorreiaBase", V3(bx, -0.1, -0.7), V3(bx, ay - 0.86, az), 0.09, BLACK, SP)
		bar(swing, "ProtetorCorreia", V3(bx - 0.06, 0.64, -0.55), V3(bx - 0.06, ay + 1.0, az - 0.6), 0.1, CARBON, SP, 0.1)
	end

	local function rimBolts(core, A, sx, n)
		for i = 0, n - 1 do
			local a = i * (2 * math.pi / n)
			cylX(core, "AroParafuso", 0.035, 0.07, CFrame.new(sx * (A + 0.065), 0.88 * cos(a), 0.88 * sin(a)), CHROME, METAL, 0.5)
		end
	end
	rimBolts(fcore, FA, -1, 16)
	rimBolts(fcore, FA, 1, 16)
	rimBolts(rcore, RA, -1, 16)
	rimBolts(rcore, RA, 1, 16)

	do
		local tela = add(fork, "PainelTela", V3(0.8, 0.04, 0.46), CFrame.new(0, 0.65, 0.12), Color3.fromRGB(4, 6, 10), SP, nil, 0.1)
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Top
		sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sg.CanvasSize = Vector2.new(420, 240)
		sg.LightInfluence = 0
		sg.Brightness = 1.6
		sg.Parent = tela
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(4, 8, 14)
		bg.BorderSizePixel = 0
		bg.Parent = sg
		local gear = Instance.new("TextLabel")
		gear.Size = UDim2.fromScale(0.3, 0.6)
		gear.Position = UDim2.fromScale(0.35, 0.18)
		gear.BackgroundTransparency = 1
		gear.Font = Enum.Font.GothamBold
		gear.TextScaled = true
		gear.TextColor3 = Color3.fromRGB(255, 255, 255)
		gear.Text = "N"
		gear.Parent = bg
		local spd = Instance.new("TextLabel")
		spd.Size = UDim2.fromScale(0.3, 0.3)
		spd.Position = UDim2.fromScale(0.04, 0.3)
		spd.BackgroundTransparency = 1
		spd.Font = Enum.Font.GothamBold
		spd.TextScaled = true
		spd.TextXAlignment = Enum.TextXAlignment.Left
		spd.TextColor3 = Color3.fromRGB(120, 220, 255)
		spd.Text = "0"
		spd.Parent = bg
		local unit = Instance.new("TextLabel")
		unit.Size = UDim2.fromScale(0.22, 0.12)
		unit.Position = UDim2.fromScale(0.04, 0.6)
		unit.BackgroundTransparency = 1
		unit.Font = Enum.Font.Gotham
		unit.TextScaled = true
		unit.TextXAlignment = Enum.TextXAlignment.Left
		unit.TextColor3 = Color3.fromRGB(150, 160, 175)
		unit.Text = "KM/H"
		unit.Parent = bg
		local red = Instance.new("TextLabel")
		red.Size = UDim2.fromScale(0.12, 0.3)
		red.Position = UDim2.fromScale(0.78, 0.35)
		red.BackgroundTransparency = 1
		red.Font = Enum.Font.GothamBold
		red.TextScaled = true
		red.TextColor3 = Color3.fromRGB(255, 40, 40)
		red.Text = "N"
		red.Parent = bg
		local track = Instance.new("Frame")
		track.Size = UDim2.fromScale(0.92, 0.09)
		track.Position = UDim2.fromScale(0.04, 0.06)
		track.BackgroundColor3 = Color3.fromRGB(24, 30, 40)
		track.BorderSizePixel = 0
		track.Parent = bg
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0.02, 1)
		fill.BackgroundColor3 = Color3.fromRGB(255, 204, 0)
		fill.BorderSizePixel = 0
		fill.Parent = track
		M.dashGear = gear
		M.dashSpeed = spd
		M.dashRev = fill
		M.dashRed = red
		add(fork, "PainelLed", V3(0.8, 0.02, 0.03), CFrame.new(0, 0.67, 0.37), BLUE_LED, NEON)
	end

	local function lerpT(t, z)
		if z <= t[1][1] then return t[1][2] end
		for i = 1, #t - 1 do
			local a, b = t[i], t[i + 1]
			if z <= b[1] then return a[2] + (b[2] - a[2]) * (z - a[1]) / (b[1] - a[1]) end
		end
		return t[#t][2]
	end
	local function shell(top, wid, bot, z0, z1, st, every)
		local n, z = 0, z0
		while z <= z1 do
			n = n + 1
			local yt, W, yb = lerpT(top, z), lerpT(wid, z), lerpT(bot, z)
			local L = st * 1.2
			add(root, "LatariaTopo", V3(W * 0.6, 0.12, L), CFrame.new(0, yt - 0.06, z), PURPLE, METAL, nil, 0.3)
			local h = yt - 0.16 - yb
			for _, sx in ipairs({ -1, 1 }) do
				add(root, "LatariaOmbro", V3(W * 0.22, 0.1, L), CFrame.new(sx * W * 0.38, yt - 0.13, z) * CFrame.Angles(0, 0, -sx * 0.45), PURPLE, METAL, nil, 0.3)
				if h > 0.05 then
					add(root, "LatariaLado", V3(0.1, h, L), CFrame.new(sx * W / 2, yb + h / 2, z), PURPLE, METAL, nil, 0.3)
					add(root, "LatariaBrilho", V3(0.02, 0.04, L), CFrame.new(sx * (W / 2 + 0.05), yt - 0.3, z), HIGH, METAL, nil, 0.5)
					add(root, "LatariaBorda", V3(0.12, 0.04, L), CFrame.new(sx * W / 2, yb, z), CARBON, SP)
					if n % every == 0 then
						add(root, "LatariaJuntaV", V3(0.13, h, 0.025), CFrame.new(sx * W / 2, yb + h / 2, z), BLACK, SP)
						cylX(root, "LatariaRebite", 0.04, 0.07, CFrame.new(sx * (W / 2 + 0.06), yb + 0.12, z), YEL, METAL, 0.3)
					end
				end
			end
			if n % every == 0 then
				add(root, "LatariaJunta", V3(W * 0.95, 0.03, 0.025), CFrame.new(0, yt + 0.002, z), BLACK, SP)
			end
			z = z + st
		end
	end
	shell({ { -3.0, 3.3 }, { -2.8, 3.5 }, { -2.4, 3.75 }, { -2.0, 3.7 }, { -1.5, 3.6 }, { -1.0, 3.7 }, { -0.4, 3.7 }, { 0.1, 3.45 }, { 0.7, 3.15 } },
		{ { -3.0, 0.4 }, { -2.8, 0.8 }, { -2.2, 1.3 }, { -1.45, 1.8 }, { -0.6, 1.7 }, { 0.2, 1.3 }, { 0.7, 0.9 } },
		{ { -3.0, 3.15 }, { -2.6, 3.05 }, { -2.0, 2.7 }, { -1.5, 2.2 }, { -0.6, 1.9 }, { 0.4, 2.4 }, { 0.7, 2.9 } },
		-3.0, 0.7, 0.12, 8)
	shell({ { 2.1, 3.15 }, { 2.8, 3.28 }, { 3.5, 3.5 }, { 4.15, 3.55 } },
		{ { 2.1, 1.0 }, { 2.8, 1.3 }, { 3.5, 1.45 }, { 4.15, 1.2 } },
		{ { 2.1, 2.9 }, { 3.5, 2.95 }, { 4.15, 3.15 } },
		2.1, 4.15, 0.12, 8)
	for _, sx in ipairs({ -1, 1 }) do
		add(root, "MalhaFundo", V3(0.04, 0.85, 1.95), CFrame.new(sx * 0.99, 1.5, 0), CARBON, SP, nil, 0.05)
		for r = 0, 5 do
			for cI = 0, 12 do
				if (r + cI) % 2 == 0 then
					add(root, "MalhaPixel", V3(0.02, 0.11, 0.13), CFrame.new(sx * 1.015, 1.18 + r * 0.13, -0.85 + cI * 0.14), GREY, METAL, nil, 0.4)
				end
			end
		end
		add(root, "MalhaMoldura", V3(0.06, 0.05, 1.99), CFrame.new(sx * 0.99, 1.95, 0), PURPLE, METAL, nil, 0.3)
		add(root, "MalhaMoldura", V3(0.06, 0.05, 1.99), CFrame.new(sx * 0.99, 1.07, 0), PURPLE, METAL, nil, 0.3)
	end
	model.Parent = workspace
	return M
end

local function newState(M, pos, yaw)
	return {
		M = M, model = M.model, root = M.root,
		pos = pos, yaw = yaw, vel = V3(0, 0, 0), vF = 0, vR = 0, vy = 0, vyG = 0,
		grounded = true, landT = 0, up = Vector3.yAxis, aP = 0, aR = 0,
		susY = 0, susV = 0, rkP = 0, rkPV = 0, rkR = 0, rkRV = 0, landPend = nil,
		leanP = 0, leanR = 0, accS = 0, prevVF = 0, steer = 0, yawRate = 0,
		fT = 0, fV = 0, rT = 0, rV = 0, relF = 0, relR = 0,
		spinF = 0, spinR = 0, throttle = 0, brakeIn = 0, stopOnly = false,
		driver = false, cf = CFrame.new(pos), lastChar = nil, safeT = 0, lastSafe = pos,
		headOn = false,
	}
end

local function releaseChar(teleport)
	local ch, hum, rpart = charParts()
	if saved then
		for p, v in pairs(saved.collide) do
			if p.Parent then p.CanCollide = v end
		end
		if hum then
			pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, saved.jump ~= false) end)
			pcall(function() hum.AutoRotate = saved.auto ~= false end)
		end
	end
	saved = nil
	if hum then pcall(function() hum.Sit = false end) end
	if teleport and rpart and c then
		local side = c.cf * CFrame.new(-2.8 * S, 0, 0)
		local pr = RaycastParams.new()
		pr.FilterType = Enum.RaycastFilterType.Exclude
		pr.FilterDescendantsInstances = { c.model, ch }
		local res = workspace:Raycast(side.Position + V3(0, 6, 0), V3(0, -30, 0), pr)
		local p = (res and res.Position or side.Position) + V3(0, 3, 0)
		rpart.CFrame = CFrame.new(p) * CFrame.Angles(0, c.yaw, 0)
		rpart.AssemblyLinearVelocity = V3(0, 0, 0)
		rpart.AssemblyAngularVelocity = V3(0, 0, 0)
	end
end

local function mountBike()
	if not c or c.driver then return end
	local ch, hum, rpart = charParts()
	if not ch then return end
	saved = {
		collide = {},
		jump = hum:GetStateEnabled(Enum.HumanoidStateType.Jumping),
		auto = hum.AutoRotate,
	}
	for _, p in ipairs(ch:GetDescendants()) do
		if p:IsA("BasePart") then
			saved.collide[p] = p.CanCollide
			p.CanCollide = false
		end
	end
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	hum.AutoRotate = false
	hum.Sit = true
	c.driver = true
end

local function dismountBike()
	if not c or not c.driver then return end
	c.driver = false
	pcall(releaseArms)
	releaseChar(true)
end

local function landImpact(cc, imp, gP, gR)
	local J = Config.Jump
	local dP = gP - cc.aP
	cc.rkP = cc.rkP + clamp(cc.aP - gP, -0.5, 0.5)
	cc.rkR = cc.rkR + clamp(cc.aR - gR, -0.4, 0.4)
	cc.aP, cc.aR = gP, gR
	local share = clamp(0.5 + dP * 2.5, 0.08, 0.92)
	local skew = (share - 0.5) * 2
	local dv = math.min(imp * 0.16, J.LandSus)
	cc.susV = cc.susV - dv * 0.6
	cc.rkPV = cc.rkPV - skew * imp * 0.012
	cc.fV = cc.fV + imp * 0.15 * share
	cc.rV = cc.rV + imp * 0.15 * (1 - share)
	cc.landPend = {
		t = 0.07 + 0.05 * (1 - math.abs(skew)),
		sv = dv * 0.4,
		pv = skew * imp * 0.009,
		snd = imp > 60 and clamp(0.25 + imp / 350, 0.3, 0.8) or 0,
	}
	if imp > 35 then
		playSound(Config.SoundLand, clamp(0.45 + imp / 220, 0.5, 1.4), clamp(1.1 - imp / 700, 0.7, 1.0))
	end
	return 1 - clamp((imp - 50) / 900, 0, J.LandLoss)
end

local function gRay(p, oy)
	return workspace:Raycast(V3(p.X, oy, p.Z), V3(0, -(13 * S), 0), rp)
end

local function stepBike(cc, dt)
	local g = workspace.Gravity
	local ch, hum, rpart = charParts()
	if cc.driver and not ch then
		cc.driver = false
		saved = nil
	end
	if cc.lastChar ~= player.Character then
		cc.lastChar = player.Character
		rp.FilterDescendantsInstances = { cc.model, player.Character }
	end
	local driving = cc.driver
	local S2 = Config.Susp

	local throttle, brakeIn, steerIn = 0, 0, 0
	cc.stopOnly = false
	if driving then
		local mv = getMove()
		throttle = clamp(-mv.Z, 0, 1)
		brakeIn = clamp(mv.Z, 0, 1)
		steerIn = clamp(mv.X, -1, 1)
		if held.brake or held.brakeUi then
			brakeIn = 1
			throttle = 0
			cc.stopOnly = true
		end
	end
	cc.throttle, cc.brakeIn = throttle, brakeIn
	cc.steer = cc.steer + (steerIn - cc.steer) * (1 - exp(-9 * dt))

	local yaw = cc.yaw
	local fwd = V3(-sin(yaw), 0, -cos(yaw))
	local right = V3(cos(yaw), 0, -sin(yaw))
	local vel = cc.vel
	local vF, vR = vel:Dot(fwd), vel:Dot(right)
	local grounded = cc.grounded
	local top = Config.TopSpeed

	local acc = 0
	if grounded and driving then
		if throttle > 0 and brakeIn == 0 and vF < top then
			local r = math.max(vF, 0) / top
			acc = Config.Thrust * throttle * math.max(0, 1 - r * r)
		elseif brakeIn > 0 and not cc.stopOnly and vF < 1.5 then
			local r = math.max(-vF, 0) / Config.ReverseTop
			acc = -Config.ReverseAccel * brakeIn * math.max(0, 1 - r * r)
		end
	end
	local resist = 2.5 + 0.00015 * vF * vF
	if throttle == 0 then resist = resist + 6 end
	if not driving then resist = resist + 8 end
	if not grounded then resist = 0.00015 * vF * vF end
	local sgn = vF >= 0 and 1 or -1
	local dec = math.min(resist * dt, math.abs(vF))
	vF = vF + acc * dt - sgn * dec

	if grounded then
		local n = cc.up
		local gt = V3(0, -1, 0) + n * n.Y
		local sa = gt * (g * Config.RollK)
		local spd0 = math.sqrt(vF * vF + vR * vR)
		if not (spd0 < 2 and sa.Magnitude < 7) then
			vF = vF + sa:Dot(fwd) * dt
			vR = vR + sa:Dot(right) * dt
		end
		if brakeIn > 0 and (cc.stopOnly or vF > 1.5) then
			local bd = Config.BrakePower * brakeIn * dt
			if vF > 0 then vF = math.max(vF - bd, 0) else vF = math.min(vF + bd, 0) end
		end
		vR = vR * exp(-Config.Grip * dt)
	end

	local sp = math.abs(vF)
	local rate = Config.TurnRate / (1 + sp / Config.TurnSpeedRef)
	local yawRate = -cc.steer * rate * clamp(sp / 5, 0, 1) * (vF >= 0 and 1 or -1)
	if not grounded then yawRate = yawRate * 0.1 end
	yaw = yaw + yawRate * dt
	fwd = V3(-sin(yaw), 0, -cos(yaw))
	right = V3(cos(yaw), 0, -sin(yaw))
	vel = fwd * vF + right * vR

	local hsp = math.sqrt(vF * vF + vR * vR)
	if hsp > 1 then
		local dir = vel.Unit
		local o = cc.pos + V3(0, 1.4 * S, 0)
		local hit = workspace:Raycast(o, dir * (hsp * dt + (vF >= 0 and 3.4 or 3.0) * S), rp)
		if hit and math.abs(hit.Normal.Y) < 0.55 then
			local into = vel:Dot(hit.Normal)
			if into < 0 then
				if into < -14 then
					cc.susV = cc.susV - clamp(-into * 0.08, 0, 6)
					cc.fV = cc.fV + clamp(-into * 0.05, 0, 4)
					cc.rkPV = cc.rkPV - clamp(-into * 0.01, 0, 0.5)
				end
				vel = vel - hit.Normal * into * 1.2
				vel = V3(vel.X, 0, vel.Z)
				vF, vR = vel:Dot(fwd), vel:Dot(right)
				hsp = math.sqrt(vF * vF + vR * vR)
			end
		end
	end

	local posN = cc.pos + V3(vel.X, 0, vel.Z) * dt

	local WH = Config.Wheelbase * 0.5 * S
	local oy = cc.pos.Y + 3 * S
	local hF = gRay(posN + fwd * WH, oy)
	local hR = gRay(posN - fwd * WH, oy)
	local hC = gRay(posN, oy)
	if hF and hF.Normal.Y <= 0.3 then hF = nil end
	if hR and hR.Normal.Y <= 0.3 then hR = nil end
	if hC and hC.Normal.Y <= 0.3 then hC = nil end
	local yF, yR, nrm
	if hF and hR then
		yF, yR = hF.Position.Y, hR.Position.Y
		nrm = hC and hC.Normal or (hF.Normal + hR.Normal).Unit
	elseif hC then
		yF, yR = hC.Position.Y, hC.Position.Y
		nrm = hC.Normal
	elseif hF or hR then
		local h = hF or hR
		yF, yR = h.Position.Y, h.Position.Y
		nrm = h.Normal
	end
	local tY, gP, gR = nil, 0, 0
	if yF then
		tY = (yF + yR) / 2
		gP = clamp(atan2(yF - yR, 2 * WH), -1.1, 1.1)
		gR = clamp(atan(-(nrm:Dot(right)) / math.max(nrm.Y, 0.2)), -0.8, 0.8)
		local tanP = tan(clamp(cc.aP + cc.rkP, -1.2, 1.2))
		local bodyY = cc.pos.Y + cc.susY
		cc.relF = yF - (bodyY + tanP * WH)
		cc.relR = yR - (bodyY - tanP * WH)
	else
		cc.relF, cc.relR = 0, 0
	end

	local y = cc.pos.Y
	local J = Config.Jump
	local gA = g * Config.GravMul
	if tY then
		if grounded then
			local maxUp = y + Config.StepUp * S + hsp * dt * 3
			if tY > maxUp then tY = maxUp end
		end
		local allow = 0.4 * S + hsp * dt * 0.35
		local launch
		if grounded then
			launch = y > tY + allow
			if J.Enabled and not launch and cc.vyG > J.MinVy and cc.landT < 0.35 then
				local ballY = y + cc.vyG * dt - 0.5 * gA * dt * dt
				launch = ballY > tY + J.Tol * S + hsp * dt * 0.08
			end
		else
			launch = y > tY + allow or (cc.vy > 0 and y > tY)
		end
		if launch then
			if grounded then
				if J.Enabled then
					cc.vy = clamp(cc.vyG * J.Gain, -J.MaxVy, J.MaxVy)
					cc.susV = cc.susV + clamp(cc.vyG * 0.05, 0, 9)
					cc.rkPV = cc.rkPV + clamp(cc.vyG * 0.0035, 0, 0.45)
				else
					cc.vy = clamp(cc.vyG, -60, 80)
				end
				grounded = false
			end
			cc.vy = cc.vy - gA * dt
			y = y + cc.vy * dt
			if y <= tY then
				if cc.vy < -18 then
					local imp = -cc.vy
					if nrm then
						imp = math.max(-(V3(vel.X, cc.vy, vel.Z)):Dot(nrm), 0)
					end
					local m = landImpact(cc, imp, gP, gR)
					vel = vel * m
				else
					cc.susV = cc.susV + clamp(cc.vy * 0.25, -25, 0)
				end
				cc.vy = 0
				cc.vyG = 0
				y = tY
				grounded = true
				cc.landT = 0.5
			end
		else
			if not grounded then cc.vyG = 0 end
			cc.vyG = cc.vyG + (clamp((tY - y) / dt, -400, 400) - cc.vyG) * (1 - exp(-18 * dt))
			y = y + (tY - y) * (1 - exp(-(tY > y and 80 or 30) * dt))
			cc.vy = 0
			grounded = true
		end
		cc.landT = math.max(cc.landT - dt, 0)
	else
		grounded = false
		cc.vy = cc.vy - gA * dt
		y = y + cc.vy * dt
	end

	if grounded then
		local k = (cc.landT > 0) and 18 or clamp(10 + hsp * 0.05, 10, 22)
		local kk = 1 - exp(-k * dt)
		cc.aP = cc.aP + (gP - cc.aP) * kk
		cc.aR = cc.aR + (gR - cc.aR) * kk
	else
		local pw = hsp > 1 and clamp(atan2(cc.vy, hsp), -0.9, 0.9) or 0
		cc.aP = cc.aP + (pw * 0.7 - cc.aP) * (1 - exp(-J.AirK * dt))
		cc.aR = cc.aR + (0 - cc.aR) * (1 - exp(-2 * dt))
	end
	cc.up = (Vector3.yAxis - fwd * tan(cc.aP) - right * tan(cc.aR)).Unit

	if y < workspace.FallenPartsDestroyHeight + 40 then
		posN = cc.lastSafe
		y = posN.Y + 3
		cc.vy = 0
		vel = V3(0, 0, 0)
	end
	if grounded then
		cc.safeT = cc.safeT + dt
		if cc.safeT > 1 then
			cc.safeT = 0
			cc.lastSafe = V3(posN.X, y, posN.Z)
		end
	end

	cc.pos = V3(posN.X, y, posN.Z)
	cc.yaw = yaw
	cc.vel = vel
	cc.grounded = grounded
	cc.vF = vel:Dot(fwd)
	cc.vR = vel:Dot(right)
	cc.yawRate = yawRate

	local accL = (cc.vF - cc.prevVF) / math.max(dt, 1e-3)
	cc.prevVF = cc.vF
	cc.accS = cc.accS + (clamp(accL, -200, 200) - cc.accS) * (1 - exp(-6 * dt))
	local tp = clamp(cc.accS * S2.LeanP, -0.1, 0.1)
	local latA = cc.vF * yawRate
	local tr = grounded and clamp(atan(latA / g) * 1.3, -Config.MaxLean, Config.MaxLean) or 0
	cc.leanP = cc.leanP + (tp - cc.leanP) * (1 - exp(-8 * dt))
	cc.leanR = cc.leanR + (tr - cc.leanR) * (1 - exp(-7 * dt))

	local sa = -S2.BodyK * cc.susY - S2.BodyC * cc.susV
	if cc.susY < S2.StopAt then sa = sa - (cc.susY - S2.StopAt) * S2.StopK end
	cc.susV = cc.susV + sa * dt
	cc.susY = cc.susY + cc.susV * dt
	if cc.susY < S2.Min then
		cc.susY = S2.Min
		if cc.susV < 0 then cc.susV = -cc.susV * 0.25 end
	elseif cc.susY > S2.Max then
		cc.susY = S2.Max
		if cc.susV > 0 then cc.susV = 0 end
	end
	cc.rkPV = cc.rkPV + (-S2.PitchK * cc.rkP - S2.PitchC * cc.rkPV) * dt
	cc.rkP = clamp(cc.rkP + cc.rkPV * dt, -0.6, 0.6)
	cc.rkRV = cc.rkRV + (-S2.RollK * cc.rkR - S2.RollC * cc.rkRV) * dt
	cc.rkR = clamp(cc.rkR + cc.rkRV * dt, -0.5, 0.5)
	local lp = cc.landPend
	if lp then
		lp.t = lp.t - dt
		if lp.t <= 0 then
			cc.susV = cc.susV - lp.sv
			cc.rkPV = cc.rkPV + lp.pv
			if lp.snd > 0 then playSound(Config.SoundLand, lp.snd, 1.15) end
			cc.landPend = nil
		end
	end

	local tF, tR
	if grounded then
		tF = clamp(cc.relF, -S2.ExtendF * S, S2.TravelF * S * 1.3) - cc.accS * S2.BrakeTransfer
		tR = clamp(cc.relR, -S2.ExtendR * S, S2.TravelR * S * 1.3) + cc.accS * S2.AccelTransfer
	else
		tF, tR = -S2.ExtendF * S, -S2.ExtendR * S
	end
	cc.fV = cc.fV + (S2.FrontK * (tF - cc.fT) - S2.FrontC * cc.fV) * dt
	cc.fT = cc.fT + cc.fV * dt
	local maxF, minF = S2.TravelF * S, -S2.ExtendF * S
	if cc.fT > maxF then
		cc.fT = maxF
		if cc.fV > 0 then cc.fV = -cc.fV * 0.3 end
	elseif cc.fT < minF then
		cc.fT = minF
		if cc.fV < 0 then cc.fV = -cc.fV * 0.2 end
	end
	cc.rV = cc.rV + (S2.RearK * (tR - cc.rT) - S2.RearC * cc.rV) * dt
	cc.rT = cc.rT + cc.rV * dt
	local maxR, minR = S2.TravelR * S, -S2.ExtendR * S
	if cc.rT > maxR then
		cc.rT = maxR
		if cc.rV > 0 then cc.rV = -cc.rV * 0.3 end
	elseif cc.rT < minR then
		cc.rT = minR
		if cc.rV < 0 then cc.rV = -cc.rV * 0.2 end
	end
end

local function visualsBike(cc, dt)
	local M = cc.M
	local yaw = cc.yaw
	local f0 = V3(-sin(yaw), 0, -cos(yaw))
	local up = cc.up
	local fwd = f0 - up * f0:Dot(up)
	if fwd.Magnitude < 1e-3 then fwd = f0 end
	fwd = fwd.Unit
	local right = fwd:Cross(up).Unit
	local up2 = right:Cross(fwd)
	local cf = CFrame.fromMatrix(cc.pos + up2 * cc.susY, right, up2, -fwd)
		* CFrame.Angles(cc.leanP + cc.rkP, 0, cc.leanR + cc.rkR)
	cc.cf = cf
	M.root.CFrame = cf

	cc.spinF = (cc.spinF - cc.vF * dt / (R * S)) % (math.pi * 2)
	cc.spinR = (cc.spinR - cc.vF * dt / (R * S)) % (math.pi * 2)
	M.wFWheel.C0 = CFrame.Angles(cc.spinF, 0, 0)

	local steerAng = -cc.steer * Config.ForkSteer * (1 - clamp(math.abs(cc.vF) / 150, 0, 0.6))
	M.wFork.C0 = CFrame.new(HEAD.X * S, HEAD.Y * S, HEAD.Z * S) * CFrame.Angles(RAKE, 0, 0) * CFrame.Angles(0, steerAng, 0)
	M.wSlider.C0 = CFrame.new(0, -(FL * S - cc.fT), 0)

	local th = -cc.rT / (ARM_Z * S)
	local rotS = CFrame.Angles(th, 0, 0)
	M.wSwing.C0 = CFrame.new(PIV.X * S, PIV.Y * S, PIV.Z * S) * rotS
	M.wRWheel.C0 = M.rtireBase * CFrame.Angles(cc.spinR, 0, 0)

	local aW = SHOCK_A * S
	local bW = (PIV + rotS:VectorToWorldSpace(SHOCK_B)) * S
	local len = math.max((bW - aW).Magnitude, 0.2)
	local dir = (bW - aW) / len
	M.rod.Size = V3(len * 0.9, 0.3 * S, 0.3 * S)
	M.wRod.C0 = CFrame.lookAt((aW + bW) / 2, bW) * CFrame.Angles(0, math.pi / 2, 0)
	M.spring.Size = V3(len * 0.55, 0.46 * S, 0.46 * S)
	M.wSpring.C0 = CFrame.lookAt(aW + dir * len * 0.3, bW) * CFrame.Angles(0, math.pi / 2, 0)

	local braking = cc.brakeIn > 0 and cc.driver
	local tcol = braking and RED_HI or RED_DIM
	for _, tp in ipairs(M.tails) do tp.Color = tcol end

	cc.seatCF = cf * CFrame.new(0, SEAT_TOP * S + Config.SitRise, Config.SeatZ * S) * CFrame.Angles(Config.SitPitch, 0, 0)
end


-- ===== Animacao do piloto (sistema estilo Charger) =====
local ARMS = { on = false, w = 0, lean = 0, J = nil, waist = nil, ang = {}, brakeW = 0 }
local GRIP_A = math.rad(55)
local function isJoint(d)
	return d:IsA("Motor6D") or d:IsA("AnimationConstraint")
end
local function armSide(name)
	local n = name:lower():gsub("[%s_]", "")
	if not (n:find("upperarm") or n == "rightarm" or n == "leftarm" or n:find("shoulder")) then return nil end
	if n:find("^right") then return "right" end
	if n:find("^left") then return "left" end
	return nil
end
local function armRotFromTo(a, b)
	a, b = a.Unit, b.Unit
	local axis = a:Cross(b)
	local dp = a:Dot(b)
	if axis.Magnitude < 1e-5 then
		if dp > 0 then return CFrame.new() end
		local perp = math.abs(a.X) < 0.9 and Vector3.xAxis or Vector3.yAxis
		return CFrame.fromAxisAngle(a:Cross(perp).Unit, math.pi)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(clamp(dp, -1, 1)))
end
local function armJoints(ch)
	local J = { right = { extra = {} }, left = { extra = {} } }
	local names = { right = { "RightUpperArm", "Right Arm" }, left = { "LeftUpperArm", "Left Arm" } }
	local motors = {}
	for _, d in ipairs(ch:GetDescendants()) do
		if isJoint(d) and d.Part0 and d.Part1 then
			motors[#motors + 1] = d
			for side, list in pairs(names) do
				if d.Part1.Name == list[1] or d.Part1.Name == list[2] then
					J[side].shoulder = J[side].shoulder or d
				end
			end
		end
	end
	for _, d in ipairs(motors) do
		local side = armSide(d.Part1.Name) or armSide(d.Name)
		if side and not J[side].shoulder then
			local nm = d.Part1.Name:lower()
			if not (nm:find("lower") or nm:find("hand")) then J[side].shoulder = d end
		end
	end
	for _, j in pairs(J) do
		local cur = j.shoulder
		for _ = 1, 2 do
			if not cur then break end
			local nxt
			for _, m in ipairs(motors) do
				if m ~= cur and m.Part0 == cur.Part1 and not m.Part1:IsA("Accessory") then
					local nm = m.Part1.Name:lower()
					if nm:find("arm") or nm:find("hand") or nm:find("elbow") or nm:find("wrist") then nxt = m break end
				end
			end
			if not nxt then break end
			table.insert(j.extra, nxt)
			if not j.elbow then j.elbow = nxt else j.hand = nxt end
			cur = nxt
		end
	end
	return J
end
local function armChain(j)
	local sh = j.shoulder
	if not (sh and sh.Parent and sh.Part0 and sh.Part1) then return nil end
	local function rot(cf) return cf - cf.Position end
	local elbow, hand = j.elbow, j.hand
	if elbow and not (elbow.Parent and elbow.Part0 == sh.Part1 and elbow.Part1) then elbow = nil end
	if hand and not (elbow and hand.Parent and hand.Part0 == elbow.Part1 and hand.Part1) then hand = nil end
	local rrSh = rot(sh.C0) * rot(sh.C1):Inverse()
	local v1 = elbow and (elbow.C0.Position - sh.C1.Position) or V3(0, -1, 0)
	if v1.Magnitude < 1e-3 then v1 = V3(0, -1, 0) end
	local k = { sh = sh, elbow = elbow, rrSh = rrSh, d0 = rrSh * v1, L1 = sh.Part1.Size.Y * 0.95 }
	if elbow then
		k.L1 = (elbow.C0.Position - sh.C1.Position).Magnitude
		k.L2 = elbow.Part1.Size.Y * 0.9
		local v2 = V3(0, -1, 0)
		if hand then
			local hv = hand.C0.Position - elbow.C1.Position
			if hv.Magnitude > 1e-3 then v2 = hv end
			k.L2 = hv.Magnitude + hand.Part1.Size.Y * 0.4
		end
		k.rrEl = rot(elbow.C0) * rot(elbow.C1):Inverse()
		k.d2 = k.rrEl * v2
	end
	k.reach = (k.L2 and (k.L1 + k.L2) or k.L1) * 0.97
	return k
end
local function solveArm(k, p0n, tgt, sgn, bodyRight, bodyUp, bodyBack, ez)
	local sh, elbow = k.sh, k.elbow
	local P = p0n * sh.C0.Position
	local toT = tgt - P
	local dist = toT.Magnitude
	if dist < 0.05 then return end
	local dirT = toT / dist
	local uW, lW = dirT, nil
	if k.L2 then
		local L1, L2 = k.L1, k.L2
		local d = math.min(dist, (L1 + L2) * 0.999)
		local a = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
		local h = math.sqrt(math.max(L1 * L1 - a * a, 0))
		local pole = bodyRight * (0.45 * sgn) - bodyUp + bodyBack * 0.15
		pole = pole - dirT * pole:Dot(dirT)
		pole = pole.Magnitude > 1e-3 and pole.Unit or -bodyUp
		local E = P + dirT * a + pole * h
		uW = (E - P).Unit
		local lv = (P + dirT * d) - E
		lW = lv.Magnitude > 1e-3 and lv.Unit or uW
	end
	local R = armRotFromTo(k.d0, p0n:VectorToObjectSpace(uW))
	local CF1 = CFrame.new(sh.C0.Position) * R * k.rrSh * CFrame.new(-sh.C1.Position)
	local B = sh.C0:Inverse() * CF1 * sh.C1
	sh.Transform = sh.Transform:Lerp(B, ez)
	if elbow and lW and k.d2 then
		local upperCF = p0n * CF1
		local R2 = armRotFromTo(k.d2, upperCF:VectorToObjectSpace(lW))
		local CF2 = CFrame.new(elbow.C0.Position) * R2 * k.rrEl * CFrame.new(-elbow.C1.Position)
		local eb = elbow.C0:Inverse() * CF2 * elbow.C1
		elbow.Transform = CFrame.new():Lerp(eb, ez)
	end
end

local LIMB = { J = nil, ch = nil, cur = {}, jw = {} }
local function limbRot(cf) return cf - cf.Position end
local function limbJoints(ch)
	local map = {
		rh = { "RightUpperLeg", "Right Leg" },
		lh = { "LeftUpperLeg", "Left Leg" },
		rk = { "RightLowerLeg" },
		lk = { "LeftLowerLeg" },
		waist = { "UpperTorso" },
		neck = { "Head" },
	}
	local J = {}
	for _, d in ipairs(ch:GetDescendants()) do
		if isJoint(d) and d.Part0 and d.Part1 then
			for key, names in pairs(map) do
				if not J[key] then
					for _, n in ipairs(names) do
						if d.Part1.Name == n then J[key] = d end
					end
				end
			end
		end
	end
	return J
end
local function releaseLimbs()
	local J = LIMB.J
	if J then
		for key, m in pairs(J) do
			if m.Parent and (LIMB.jw[key] or 0) > 0 then m.Transform = CFrame.new() end
		end
	end
	LIMB.cur, LIMB.jw = {}, {}
end
local function releaseArms()
	if not ARMS.on then return end
	ARMS.on = false
	ARMS.w = 0
	ARMS.ang = {}
	ARMS.brakeW = 0
	if ARMS.lean > 0 then
		ARMS.lean = 0
		if ARMS.waist and ARMS.waist.Parent then ARMS.waist.Transform = CFrame.new() end
	end
	local J = ARMS.J
	ARMS.J = nil
	ARMS.waist = nil
	if J then
		for _, side in pairs(J) do
			if side.shoulder and side.shoulder.Parent then side.shoulder.Transform = CFrame.new() end
			for _, m in ipairs(side.extra) do
				if m.Parent then m.Transform = CFrame.new() end
			end
		end
	end
	releaseLimbs()
end

-- Pontos de manopla no espaco local do Fork (antes da escala; S aplicado no CF do fork)
local GRIP_LOCAL = {
	right = V3(2.05, 0.62, 0.78),
	left  = V3(-2.05, 0.62, 0.78),
}
-- Pedaleiras no espaco do root (antes da escala)
local FOOT_LOCAL = {
	right = V3(1.05, 1.05, 1.7),
	left  = V3(-1.05, 1.05, 1.7),
}

local function driveRider(cc, dt)
	if Config.LimbAnim == false then return end
	local ch, hum, rpart = charParts()
	if not (ch and cc.driver) then
		releaseArms()
		return
	end
	if not ARMS.J or not ARMS.J.right.shoulder or not ARMS.J.right.shoulder.Parent then
		ARMS.J = armJoints(ch)
		ARMS.waist = nil
		ARMS.lean = 0
	end
	local J = ARMS.J
	local chR, chL = armChain(J.right), armChain(J.left)
	if not (chR and chL) then return end

	ARMS.on = true
	ARMS.w = math.min(1, ARMS.w + dt * 4)
	local ez = ARMS.w * ARMS.w * (3 - 2 * ARMS.w)

	local seatW = cc.seatCF
	local rootInv = rpart.CFrame:Inverse()
	local function pw(part) return seatW * (rootInv * part.CFrame) end
	local bodyRight, bodyUp, bodyBack = seatW.RightVector, seatW.UpVector, -seatW.LookVector

	-- CF do guidão (fork) no mundo
	local M = cc.M
	local forkCF = M.root.CFrame * M.wFork.C0
	-- grips seguem a direcao do guidão
	local grips = {
		right = (forkCF * CFrame.new(GRIP_LOCAL.right * S)).Position,
		left  = (forkCF * CFrame.new(GRIP_LOCAL.left * S)).Position,
	}

	-- freio: puxa bracos um pouco pra tras e inclina tronco
	local wantBrake = (cc.brakeIn or 0) > 0.15 and 1 or 0
	ARMS.brakeW = ARMS.brakeW + (wantBrake - ARMS.brakeW) * math.min(1, dt * 8)
	local bw = ARMS.brakeW * ARMS.brakeW * (3 - 2 * ARMS.brakeW)
	local DA = Config.DriveAnim or {}
	local brakePull = (DA.BrakeArmPull or 0.08) * S * bw
	local brakeLean = (DA.BrakeLean or 0.22) * bw
	if bw > 0.01 then
		local back = bodyBack
		grips.right = grips.right + back * brakePull
		grips.left  = grips.left  + back * brakePull
	end

	-- limpa extras (antebraco/mao) antes de aplicar
	for _, side in pairs(J) do
		for _, m in ipairs(side.extra) do
			if m.Parent then m.Transform = CFrame.new() end
		end
	end

	-- waist lean pra alcancar o guidão + freio
	local sr = chR.sh
	local waist = ARMS.waist
	if waist == nil or (waist and (not waist.Parent or waist.Part1 ~= sr.Part0)) then
		waist = false
		local scope = sr.Part0:FindFirstAncestorOfClass("Model") or sr.Part0.Parent
		for _, d in ipairs(scope:GetDescendants()) do
			if isJoint(d) and d.Part1 == sr.Part0 and d.Part0 then waist = d break end
		end
		ARMS.waist = waist
	end
	local prevLean = ARMS.lean
	local spin = nil
	if waist and waist.Parent and waist.Part0 then
		local lowerCF = pw(waist.Part0)
		local Wp = lowerCF * waist.C0.Position
		spin = function(th)
			return CFrame.new(Wp) * CFrame.fromAxisAngle(bodyRight, -th) * CFrame.new(-Wp)
		end
		local p0u = spin(prevLean):Inverse() * pw(sr.Part0)
		local need = 0
		for i = 0, 12 do
			local th = i * 0.04
			need = th
			if ((spin(th) * p0u) * sr.C0.Position - grips.right).Magnitude <= chR.reach then break end
		end
		need = need + brakeLean
		local lean = prevLean + (need * ez - prevLean) * math.min(1, dt * 10)
		if lean > 0.002 then
			local a0 = lowerCF:VectorToObjectSpace(bodyRight)
			local aC = (waist.C0 - waist.C0.Position):Inverse() * a0
			waist.Transform = CFrame.fromAxisAngle(aC, -lean)
		end
		ARMS.lean = lean
	end
	local function p0nOf(sh)
		local p0w = pw(sh.Part0)
		if spin then return spin(ARMS.lean) * (spin(prevLean):Inverse() * p0w) end
		return p0w
	end
	solveArm(chR, p0nOf(chR.sh), grips.right, 1, bodyRight, bodyUp, bodyBack, ez)
	solveArm(chL, p0nOf(chL.sh), grips.left, -1, bodyRight, bodyUp, bodyBack, ez)

	-- pernas sentadas + cabeca pra frente
	if LIMB.ch ~= ch or not LIMB.J then
		LIMB.ch = ch
		LIMB.J = limbJoints(ch)
		LIMB.cur, LIMB.jw = {}, {}
	end
	local lb = (DA.LegBend or 1.0)
	-- cabeca: cancela o lean do tronco e o roll da moto pra olhar pra frente (horizonte)
	local leanRad = ARMS.lean or 0
	local bikeRoll = (cc.leanR or 0) + (cc.rkR or 0)  -- roll da moto (rad)
	local bikePitch = (cc.leanP or 0) + (cc.rkP or 0)
	local lookMul = DA.LookLean
	if lookMul == nil then lookMul = 1.0 end  -- 1.0 = cancela 100% do lean do tronco
	local neckPitch = leanRad * (180 / math.pi) * lookMul   -- sobe a cabeca o mesmo que o tronco desceu
		+ bw * 12                                   -- no freio olha um pouco mais pra frente
		- bikePitch * (180 / math.pi) * 0.35        -- compensa pitch da moto parcialmente
	local neckRoll = -bikeRoll * (180 / math.pi) * 0.85     -- cabeca quase nivelada com o chao na curva
	local tgt = {
		rh = V3(55 * lb, 8, 12),
		rk = V3(-95 * lb, 0, 0),
		lh = V3(55 * lb, -8, -12),
		lk = V3(-95 * lb, 0, 0),
		neck = V3(neckPitch, 0, neckRoll),
	}
	-- waist so e controlado pelo ARMS.lean (nao sobrescrever)
	local k = math.min(1, dt * 12)
	for key, m in pairs(LIMB.J) do
		if m.Parent and m.Part0 and m.Part1 then
			local want = tgt[key]
			local jw = LIMB.jw[key] or 0
			local rate = (key == "neck") and 14 or 8
			jw = jw + ((want and 1 or 0) - jw) * math.min(1, dt * rate)
			if not want and jw < 0.01 then jw = 0 end
			LIMB.jw[key] = jw
			if want then
				local kk = (key == "neck") and math.min(1, dt * 18) or k
				LIMB.cur[key] = (LIMB.cur[key] or want):Lerp(want, kk)
			end
			local cur = LIMB.cur[key]
			if jw > 0 and cur then
				local c0 = limbRot(m.C0)
				local T = c0:Inverse() * CFrame.Angles(math.rad(cur.X), math.rad(cur.Y), math.rad(cur.Z)) * c0
				-- pescoco aplica forte (quase override); pernas suaves
				local e = jw * jw * (3 - 2 * jw)
				if key ~= "neck" then e = e * ez end
				m.Transform = m.Transform:Lerp(T, math.clamp(e, 0, 1))
			end
		end
	end
end


local function holdRider(cc)
	if not cc.driver then return end
	local ch, hum, rpart = charParts()
	if not ch then return end
	rpart.CFrame = cc.seatCF
	rpart.AssemblyLinearVelocity = V3(0, 0, 0)
	rpart.AssemblyAngularVelocity = V3(0, 0, 0)
	if not hum.Sit then hum.Sit = true end
end

local function makeSounds()
	pcall(function()
		sIdle = Instance.new("Sound")
		sIdle.Name = "MotoIdle"
		sIdle.SoundId = Config.SoundIdle
		sIdle.Looped = true
		sIdle.Volume = 0
		sIdle.Parent = SoundService
		sRun = Instance.new("Sound")
		sRun.Name = "MotoRun"
		sRun.SoundId = Config.SoundRun
		sRun.Looped = true
		sRun.Volume = 0
		sRun.Parent = SoundService
	end)
end
local function soundStep(cc)
	if not sRun or not sIdle then return end
	if cc and cc.driver then
		local ratio = clamp(math.abs(cc.vF) / Config.TopSpeed, 0, 1)
		if not sIdle.Playing then sIdle:Play() end
		if not sRun.Playing then sRun:Play() end
		sIdle.Volume = Config.VolIdle * (1 - ratio)
		sRun.Volume = Config.VolRun * (0.35 + 0.65 * math.max(ratio, cc.throttle))
		sRun.PlaybackSpeed = 0.6 + 1.0 * ratio + 0.15 * cc.throttle
	else
		if sIdle.Playing then sIdle:Stop() end
		if sRun.Playing then sRun:Stop() end
	end
end

local function despawnBike()
	if c then
		if c.driver then
			c.driver = false
			releaseChar(true)
		end
		pcall(function() c.model:Destroy() end)
		c = nil
	end
	soundStep(nil)
end

local function spawnBike()
	local ch, hum, rpart = charParts()
	if not ch then return end
	if c then despawnBike() end
	local look = rpart.CFrame.LookVector
	local flat = V3(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then flat = V3(0, 0, -1) else flat = flat.Unit end
	local p = rpart.Position + flat * 12
	local pr = RaycastParams.new()
	pr.FilterType = Enum.RaycastFilterType.Exclude
	pr.FilterDescendantsInstances = { ch }
	local res = workspace:Raycast(p + V3(0, 15, 0), V3(0, -80, 0), pr)
	local gy = res and res.Position.Y or (rpart.Position.Y - 3)
	local yaw = atan2(-flat.X, -flat.Z)
	local M = buildModel()
	c = newState(M, V3(p.X, gy, p.Z), yaw)
	rp.FilterDescendantsInstances = { c.model, ch }
	c.lastChar = ch
	visualsBike(c, 1 / 60)
end

local function buildHud()
	local h = {}
	local g = Instance.new("ScreenGui")
	g.Name = "MotoHUD_JXz"
	g.ResetOnSpawn = false
	g.DisplayOrder = 50
	g.IgnoreGuiInset = true
	parentGui(g)
	h.gui = g

	local function round(o, r)
		local u = Instance.new("UICorner")
		u.CornerRadius = UDim.new(0, r)
		u.Parent = o
	end
	local function outline(o, col, th)
		local s = Instance.new("UIStroke")
		s.Color = col
		s.Thickness = th
		s.Parent = o
	end
	local function mkBtn(text, i)
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(112, 40)
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.new(1, -14, 0.28, (i - 1) * 46)
		b.BackgroundColor3 = Color3.fromRGB(34, 12, 58)
		b.BackgroundTransparency = 0.12
		b.TextColor3 = Color3.fromRGB(255, 204, 0)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 15
		b.Text = text
		b.AutoButtonColor = true
		round(b, 10)
		outline(b, Color3.fromRGB(150, 70, 230), 1.5)
		b.Parent = g
		return b
	end
	h.bCall = mkBtn("MOTO", 1)
	h.bMount = mkBtn("MONTAR", 2)
	h.bLight = mkBtn("FAROL", 3)
	h.bBrake = mkBtn("FREIO", 4)

	local sp = Instance.new("Frame")
	sp.Size = UDim2.fromOffset(150, 52)
	sp.AnchorPoint = Vector2.new(0.5, 1)
	sp.Position = UDim2.new(0.5, 0, 1, -16)
	sp.BackgroundColor3 = Color3.fromRGB(20, 8, 36)
	sp.BackgroundTransparency = 0.2
	round(sp, 12)
	outline(sp, Color3.fromRGB(150, 70, 230), 1.5)
	sp.Parent = g
	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.fromScale(1, 1)
	txt.BackgroundTransparency = 1
	txt.Font = Enum.Font.GothamBold
	txt.TextSize = 26
	txt.TextColor3 = Color3.fromRGB(255, 204, 0)
	txt.Text = "0 km/h"
	txt.Parent = sp
	h.speed = txt
	h.speedFrame = sp

	local function mkBar(label, xoff)
		local f = Instance.new("Frame")
		f.Size = UDim2.fromOffset(16, 52)
		f.AnchorPoint = Vector2.new(0.5, 1)
		f.Position = UDim2.new(0.5, xoff, 1, -16)
		f.BackgroundColor3 = Color3.fromRGB(20, 8, 36)
		f.BackgroundTransparency = 0.2
		round(f, 6)
		outline(f, Color3.fromRGB(150, 70, 230), 1)
		f.Parent = g
		local fill = Instance.new("Frame")
		fill.AnchorPoint = Vector2.new(0, 1)
		fill.Position = UDim2.fromScale(0, 1)
		fill.Size = UDim2.fromScale(1, 0.3)
		fill.BackgroundColor3 = Color3.fromRGB(255, 204, 0)
		fill.BorderSizePixel = 0
		round(fill, 6)
		fill.Parent = f
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromOffset(16, 12)
		l.Position = UDim2.new(0, 0, 0, -13)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBold
		l.TextSize = 11
		l.TextColor3 = Color3.fromRGB(200, 160, 255)
		l.Text = label
		l.Parent = f
		return fill
	end
	h.barF = mkBar("F", -96)
	h.barR = mkBar("T", 96)
	return h
end

local function hudStep(cc)
	if not hud then return end
	local S2 = Config.Susp
	if cc then
		hud.speed.Text = tostring(math.floor(math.abs(cc.vF) * Config.SpeedMul + 0.5)) .. " km/h"
		local Mm = cc.M
		if Mm and Mm.dashSpeed then
			local spd = math.floor(math.abs(cc.vF) * Config.SpeedMul + 0.5)
			local g = spd < 1 and "N" or tostring(clamp(math.floor(spd / (Config.TopSpeed / 6)) + 1, 1, 6))
			Mm.dashSpeed.Text = tostring(spd)
			Mm.dashGear.Text = g
			Mm.dashRed.Visible = (g == "N")
			Mm.dashRev.Size = UDim2.fromScale(clamp(math.abs(cc.vF) / Config.TopSpeed, 0.02, 1), 1)
		end
		local fr = (cc.fT + S2.ExtendF * S) / ((S2.TravelF + S2.ExtendF) * S)
		local rr = (cc.rT + S2.ExtendR * S) / ((S2.TravelR + S2.ExtendR) * S)
		hud.barF.Size = UDim2.fromScale(1, clamp(fr, 0.02, 1))
		hud.barR.Size = UDim2.fromScale(1, clamp(rr, 0.02, 1))
		hud.bMount.Text = cc.driver and "DESCER" or "MONTAR"
		hud.bCall.Text = "GUARDAR"
	else
		hud.speed.Text = "0 km/h"
		hud.barF.Size = UDim2.fromScale(1, 0.3)
		hud.barR.Size = UDim2.fromScale(1, 0.3)
		hud.bMount.Text = "MONTAR"
		hud.bCall.Text = "MOTO"
	end
end

local function toggleCall()
	if c then despawnBike() else spawnBike() end
end
local function toggleMount()
	if not c then spawnBike() return end
	if c.driver then
		dismountBike()
	else
		local ch, hum, rpart = charParts()
		if ch and (rpart.Position - c.pos).Magnitude < 16 * S and math.abs(c.vF) < 12 then
			mountBike()
		end
	end
end
local function toggleLight()
	if not c then return end
	c.headOn = not c.headOn
	c.M.spot.Enabled = c.headOn
	local col = c.headOn and WHITE_LED or Color3.fromRGB(120, 130, 140)
	for _, led in ipairs(c.M.leds) do led.Color = col end
end
local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

hud = buildHud()
makeSounds()
track(hud.bCall.Activated:Connect(toggleCall))
track(hud.bMount.Activated:Connect(toggleMount))
track(hud.bLight.Activated:Connect(toggleLight))
track(hud.bBrake.InputBegan:Connect(function(i) if isPress(i) then held.brakeUi = true end end))
track(hud.bBrake.InputEnded:Connect(function(i) if isPress(i) then held.brakeUi = false end end))

track(UIS.InputBegan:Connect(function(i, gpe)
	if gpe then return end
	if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
	if i.KeyCode == Enum.KeyCode.B then toggleCall()
	elseif i.KeyCode == Enum.KeyCode.E then toggleMount()
	elseif i.KeyCode == Enum.KeyCode.H then toggleLight()
	elseif i.KeyCode == Enum.KeyCode.Space then held.brake = true end
end))
track(UIS.InputEnded:Connect(function(i)
	if i.KeyCode == Enum.KeyCode.Space then held.brake = false end
end))
track(player.CharacterAdded:Connect(function()
	if c and c.driver then c.driver = false end
	saved = nil
	pcall(releaseArms)
	ARMS.J = nil
	ARMS.waist = nil
	LIMB.J, LIMB.ch = nil, nil
	LIMB.cur, LIMB.jw = {}, {}
end))

RunService:BindToRenderStep("MotoJXz", Enum.RenderPriority.Camera.Value - 1, function(dt)
	dt = math.min(dt, 1 / 20)
	if c and c.model.Parent then
		stepBike(c, dt)
		visualsBike(c, dt)
		holdRider(c)
	end
	soundStep(c)
	hudStep(c)
end)

track(RunService.Stepped:Connect(function(_, dt)
	dt = math.clamp(dt or 1 / 60, 1 / 240, 0.05)
	if c and c.model and c.model.Parent and c.driver then
		pcall(driveRider, c, dt)
	elseif ARMS.on then
		pcall(releaseArms)
	end
end))

_G.__MOTO_JXZ_CLEANUP = function()
	pcall(function() RunService:UnbindFromRenderStep("MotoJXz") end)
	pcall(releaseArms)
	for _, cn in ipairs(conns) do pcall(function() cn:Disconnect() end) end
	despawnBike()
	if hud and hud.gui then pcall(function() hud.gui:Destroy() end) end
	if sRun then pcall(function() sRun:Destroy() end) end
	if sIdle then pcall(function() sIdle:Destroy() end) end
	_G.__MOTO_JXZ_CLEANUP = nil
end

end)
if not ok0 then warn("[MOTO] erro: " .. tostring(err0)) end
