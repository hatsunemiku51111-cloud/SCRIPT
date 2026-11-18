local ok0, err0 = xpcall(function()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
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

	AccelAnim = {
		Enabled = true,
		AccRef = 30,
		AccelPitch = 0.025,
		BrakePitch = 0.045,
		FrontDive = 0.28,
		RearSquat = 0.1,
		Rate = 7,
		ArmBack = 0.05,
		ArmBrake = 0.12,
		ArmPull = 0.07,
		ThrottleRoll = 0.65,
		LeverPull = 0.4,
		WristRoll = 28,
		WristBrake = 10,
		WristSign = 1,
		HeadTilt = 10,
	},
	FallRescue = false,
	ShiftTime = 0.22,
	SkidMinSpeed = 40,
	SkidSlip = 0.65,
	SkidGrip = 0.3,
	DriftCurve = true,
	DriftSlip = 0.3,
	DriftGrip = 0.45,
	ShiftCooldown = 1.0,
	ShiftJolt = 0.035,
	ScrapeLean = 0.55,
	WheelieMax = 0.55,
	WheelieMinSpeed = 10,
	HudSpeedoPos = UDim2.new(0, 10, 0.2, 0),
	HudKeyPos = UDim2.new(0.5, 0, 1, -130),

	TurnRate = 2.1,
	TurnSpeedRef = 90,
	ForkSteer = 0.5,
	MaxLean = 0.85,

	Wheelbase = 6.2,

	Jump = { Enabled = true, Tol = 0.8, MinVy = 10, MaxVy = 300, Gain = 1.0, LandLoss = 0.15, LandSus = 40, AirK = 6 },

	Susp = {
		BodyK = 110, BodyC = 9, StopAt = -1.0, StopK = 420, Min = -1.3, Max = 0.9,
		PitchK = 60, PitchC = 7.7,
		RollK = 70, RollC = 8,
		FrontK = 150, FrontC = 11, TravelF = 0.9, ExtendF = 0.4,
		RearK = 180, RearC = 12, TravelR = 0.8, ExtendR = 0.3,
		BrakeTransfer = 0.010,
		AccelTransfer = 0.008,
		SquatMax = 0.06,
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
		LookLean = 1.0,
		LegBend = 1.0,
	},

	FootRest = {
		Enabled = true,
		Z = 1.0,
		ZMin = 0.1,
		Inset = 0.2,
		Lift = 0.0,
		Splay = 12,
		KneeOut = 0.3,
		Mode = "pivo",
		PivotZ = -0.15,
	},

	Park = {
		Enabled = true,
		Delay = 0.35,
		StopSpeed = 1.5,
		LeaveSpeed = 4,
		Time = 0.55,
		RetractTime = 0.35,
		Lean = 0.45,
		LeanExtra = 0.2,
		Steer = 0.7,
		Shift = 0.35,
		MaxDrop = 0.9,
		Reach = 0.97,
		FootOut = 0.3,
		ToeDown = 0.5,
		Splay = 15,
		PushTime = 0.35,
		PushDist = 0.9,
		PushKick = 4,
		PushUpright = 0.6,
		HangFoot = 0,
	},

	WheelieVariant = {
		Mode = "random",
		PullBack = 0.45,
		PullUp = 0.25,
		PullTilt = 0.18,
	},

	WheelieStand = {
		Enabled = true,
		StartAt = 0.4,
		EndAt = 0.30,
		Time = 0.8,
		Upright = 0.6,
		Straight = 0.93,
		FootX = 0.3,
		FrontZ = 1.0,
		BackZ = 1.8,
		Splay = 10,
	},

	Headlight = { Range = 70, Brightness = 3, Angle = 70 },

	MountRadius = 16,
	KeyHotkey = Enum.KeyCode.B,
	KeyToolName = "Chave da Moto",
	KeyAccessoryId = 71337506344769,
	KeyLength = 1.6,
	KeyGrip = Vector3.new(0, 0, 0),
	KeyRotation = Vector3.new(0, 0, 0),
	KeyCooldown = 0.9,

	Neon = {
		Enabled = true,
		HueRate = 0.35,
		Radius = 0.77,
		Segments = 36,
		Thickness = 0.08,
		Persist = 0.1,
		LightRange = 8,
	},
	KeyIcon = "\u{1F511}",
	SoundKeyEquip = "rbxassetid://9113849492",

	EnginePerf = { Enabled = true, Hz = 20, LodDist = 120, Spin = true, Chain = true },
	CacheDisk = true,
	CheapGlass = true,
	LiteMode = "off",

	UseHiddenGui = true,
	SoundLand = "rbxassetid://7340406550",
	SoundIdle = "rbxassetid://6399923126",
	SoundRun = "rbxassetid://82036216654849",
	VolIdle = 0.22,
	VolRun = 0.2,
	SoundSkid = "rbxassetid://103305629439898",
	VolSkid = 0.5,

	Arrive = {
		Enabled = true,
		Distance = 80,
		Side = 20,
		SideOffset = 5,
		Speed = 55,
		Accel = 60,
		Decel = 32,
		FadeIn = 0.5,
	},

	Kickstand = {
		Enabled = true,
		Lean = 0.30,
		Steer = 0.5,
		Time = 0.45,
		RetractTime = 0.35,
		SpringK = 55,
		SpringC = 9,
		StopSpeed = 1.5,
		IdleDelay = 0.6,
		Pivot = Vector3.new(-1.0, 1.0, 0.6),
		Out = 0.6,
		Forward = 0.2,
	},

	Dismount = {
		Enabled = true,
		MaxSpeed = 25,
		StopSpeed = 1.2,
		StopTimeout = 3,
		PlantTime = 0.35,
		LegTime = 1.0,
		OverX = 0.8,
		StepOut = 0.9,
		StepLift = 0.35,
		FeetGap = 0.95,
		FootBack = 0.35,
		TailX = -0.1,
		TailY = 3.9,
		TailZ = 3.0,
		ForwardShift = 0.5,
		ArmTime = 0.4,
		MaxDrop = 3.0,
		LeanTime = 0.35,
		KickWait = 0.25,
		KickTimeout = 2.5,
		TorsoLean = 0.45,
		TorsoTwist = 0.3,
		HeadYaw = 30,
		HeadDown = 20,
		SettleTime = 0.5,
		FootTime = 0.3,
		SeatHoldZ = 1.9,
		Smooth = 7,
	},

	Anim = {
		Enabled = true,
		MaxFly = 170,
		MaxFlyWheel = 70,
		BreakTime = 0.6,
		GatherTime = 0.7,
		BoxShake = 1.1,
		Confetti = 160,
		BlastRadius = 45,
		BlastPush = 95,
		SoundExplode = "rbxasset://sounds/impact_explosion_03.mp3",
	},
}
local S = Config.Scale
local LITE = Config.LiteMode ~= "off"
local LITE_SKIP = {
	AroParafuso = true, MalhaPixel = true, CoroaMotorDente = true, EntradaArGrade = true, CarterNervura = true,
	ParafusoMesa = true, CilindroParafuso = true, Porca = true, EixoPorca = true, OrelhaFio = true, Furo = true,
}
local LITE_SKIP2 = {
	Sulco = true, Dente = true, OrelhaBorda = true, OrelhaPonta = true, PernaAnel = true, PodLed = true, PodAnel = true,
	ManetePino = true, RabetaFio = true, ParalamaFio = true, TanqueFio = true, NarizFio = true,
	EmblemaContorno = true, CavaloMini = true,
}
local TIRE_PARTS = { Banda = true, Parede = true }

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
local FA, RA = 0.66, 0.82
local FX = 1.15
local DF, DR = 0.3, 0.34
local SWX = RA + 0.48
local FCEN = V3(0, R, -2.8)
local RCEN = V3(0, R, 3.4)
local HEAD = V3(0, 3.7, -1.5)
local dF = FCEN - HEAD
local RAKE = atan2(-dF.Z, -dF.Y)
local FL = dF.Magnitude
local PIV = V3(0, 1.5, 0.9)
local ARM_Z = RCEN.Z - PIV.Z
local ARM_Y = R - PIV.Y
local SEAT_TOP = 2.94
local SHOCK_A = V3(0, 2.55, 0.55)
local SHOCK_B = V3(0, 0.35, 0.55)

local CH = { NR = 36, NM = 14, rR = 0.78 }
CH.XC = -(RA + 0.08)
CH.pitch = 2 * math.pi * CH.rR / CH.NR
CH.rM = CH.NM * CH.pitch / (2 * math.pi)
CH.mc = V3(CH.XC, 1.7, 0.2)

local function chainPath(A, B, r1, r2)
	local dz, dy = B.Z - A.Z, B.Y - A.Y
	local d = math.sqrt(dz * dz + dy * dy)
	local uz, uy = dz / d, dy / d
	local nz, ny = -uy, uz
	local k = clamp((r1 - r2) / d, -0.95, 0.95)
	local beta = math.acos(k)
	local run = d * math.sin(beta)
	local l2 = r2 * 2 * beta
	local l4 = r1 * (2 * math.pi - 2 * beta)
	return { Az = A.Z, Ay = A.Y, Bz = B.Z, By = B.Y, r1 = r1, r2 = r2, uz = uz, uy = uy, nz = nz, ny = ny,
		beta = beta, run = run, l2 = l2, l4 = l4, L = 2 * run + l2 + l4 }
end

local function chainPos(P, s)
	s = s % P.L
	local cb, sb = math.cos(P.beta), math.sin(P.beta)
	if s < P.run then
		local mz, my = P.uz * cb + P.nz * sb, P.uy * cb + P.ny * sb
		local z1, y1 = P.Az + P.r1 * mz, P.Ay + P.r1 * my
		local z2, y2 = P.Bz + P.r2 * mz, P.By + P.r2 * my
		local t = s / P.run
		return z1 + (z2 - z1) * t, y1 + (y2 - y1) * t, (z2 - z1) / P.run, (y2 - y1) / P.run
	elseif s < P.run + P.l2 then
		local phi = P.beta - (s - P.run) / P.r2
		local c, sn = math.cos(phi), math.sin(phi)
		return P.Bz + P.r2 * (P.uz * c + P.nz * sn), P.By + P.r2 * (P.uy * c + P.ny * sn), P.uz * sn - P.nz * c, P.uy * sn - P.ny * c
	elseif s < 2 * P.run + P.l2 then
		local mz, my = P.uz * cb - P.nz * sb, P.uy * cb - P.ny * sb
		local z2, y2 = P.Bz + P.r2 * mz, P.By + P.r2 * my
		local z1, y1 = P.Az + P.r1 * mz, P.Ay + P.r1 * my
		local t = (s - P.run - P.l2) / P.run
		return z2 + (z1 - z2) * t, y2 + (y1 - y2) * t, (z1 - z2) / P.run, (y1 - y2) / P.run
	else
		local phi = -P.beta - (s - 2 * P.run - P.l2) / P.r1
		local c, sn = math.cos(phi), math.sin(phi)
		return P.Az + P.r1 * (P.uz * c + P.nz * sn), P.Ay + P.r1 * (P.uy * c + P.ny * sn), P.uz * sn - P.nz * c, P.uy * sn - P.ny * c
	end
end
local function chainPathAt(rotS)
	local Aw = V3(CH.mc.X * S, CH.mc.Y * S, CH.mc.Z * S)
	local Bw = V3(PIV.X * S, PIV.Y * S, PIV.Z * S) + rotS:VectorToWorldSpace(V3(0, ARM_Y * S, ARM_Z * S))
	return Aw, chainPath(Aw, Bw, CH.rM * S, CH.rR * S)
end

local function updateChain(cc, M, dt, rotS, th)
	if not M.chain then return end
	local n = #M.chain
	if n == 0 then return end
	local E = Config.EnginePerf
	cc._chAcc = (cc._chAcc or 0) + dt
	cc._chDsp = (cc._chDsp or 0) - cc.vF * dt / (R * S)
	local interval = (E.Enabled and E.Hz and E.Hz > 0) and (1 / E.Hz) or 0
	local first = M.chainLocal == nil
	local due = first or cc._chAcc >= interval
	if due then
		local dsp = cc._chDsp
		cc._chAcc, cc._chDsp = 0, 0
		local calc = first or E.Chain ~= false
		if calc and (first or dsp ~= 0 or math.abs(th - (cc._chTh or th)) > 0.002) then
			local Aw, P = chainPathAt(rotS)
			if E.Spin ~= false then
				cc.mAng = ((cc.mAng or 0) + dsp * CH.NR / CH.NM) % (2 * math.pi)
			end
			cc.chS = ((cc.chS or 0) + dsp * CH.rR * S) % P.L
			M.wMotor.C0 = CFrame.new(Aw) * CFrame.Angles(cc.mAng or 0, 0, 0)
			local loc = M.chainLocal or table.create(n, CFrame.new())
			local x = CH.XC * S
			for i = 1, n do
				local pz, py, dz, dy = chainPos(P, cc.chS + (i - 1) * P.L / n)
				local pp = V3(x, py, pz)
				if i % 2 == 1 then
					loc[i] = CFrame.new(pp)
				else
					loc[i] = CFrame.lookAt(pp, pp + V3(0, dy, dz), V3(1, 0, 0))
				end
			end
			M.chainLocal = loc
			cc._chTh = th
			cc._chDirty = true
		end
	end
	local rootCF = M.root.CFrame
	if not cc._chDirty and rootCF == cc._chRoot then return end
	if E.Enabled and not due then
		local cam = workspace.CurrentCamera
		if cam and (cam.CFrame.Position - rootCF.Position).Magnitude > E.LodDist then return end
	end
	local cfs, loc = M.chainCF, M.chainLocal
	for i = 1, n do cfs[i] = rootCF * loc[i] end
	workspace:BulkMoveTo(M.chain, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	cc._chRoot, cc._chDirty = rootCF, false
end

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
local held = { brake = false, brakeUi = false, wheelUi = false }
local hud = nil
local sRun, sIdle, sSkid = nil, nil, nil

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
		if Config.CheapGlass and p.Material == Enum.Material.Glass then p.Material = SP end
		if shape then p.Shape = shape end
		p.Reflectance = refl or 0
		p.Transparency = trans or 0
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		if Config.LiteMode == "super" or (p.Size.Magnitude < 1.6 * S and not TIRE_PARTS[name]) then p.CastShadow = false end
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
		if LITE and (LITE_SKIP[name] or (Config.LiteMode == "super" and LITE_SKIP2[name])) then return nil, nil end
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

	local BLUEL = Color3.fromRGB(150, 205, 255)
	local STCH = Color3.fromRGB(70, 70, 78)
	local function cr(p0, p1, p2, p3, t)
		return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t)
	end
	local function smooth(list, sub)
		local out = {}
		for i = 1, #list - 1 do
			local p0, p1, p2, p3 = list[math.max(i - 1, 1)], list[i], list[i + 1], list[math.min(i + 2, #list)]
			for s = 0, sub - 1 do
				local row = {}
				for k = 1, #p1 do row[k] = cr(p0[k], p1[k], p2[k], p3[k], s / sub) end
				out[#out + 1] = row
			end
		end
		out[#out + 1] = list[#list]
		return out
	end
	local function tri(parent, a, b, c, th, color, mat, refl, trans)
		local ab, ac, bc = b - a, c - a, c - b
		local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
		if abd > acd and abd > bcd then c, a = a, c elseif acd > bcd and acd > abd then a, b = b, a end
		ab, ac, bc = b - a, c - a, c - b
		local rc = ac:Cross(ab)
		if rc.Magnitude < 1e-5 or bc.Magnitude < 1e-5 then return end
		local right = rc.Unit
		local up = bc:Cross(right).Unit
		local back = bc.Unit
		local height = math.abs(ab:Dot(up))
		local flip = (WTALL == 1) and CFrame.new() or CFrame.Angles(0, math.pi, 0)
		local l1, l2 = math.abs(ab:Dot(back)), math.abs(ac:Dot(back))
		if height < 0.004 then return end
		if l1 > 0.004 then
			local p = newPart("Cunha", V3(th, height, l1), color, mat, nil, refl, trans, "WedgePart")
			weld(parent, p, sCF(CFrame.fromMatrix((a + b) / 2, right, up, back) * flip))
		end
		if l2 > 0.004 then
			local p = newPart("Cunha", V3(th, height, l2), color, mat, nil, refl, trans, "WedgePart")
			weld(parent, p, sCF(CFrame.fromMatrix((a + c) / 2, -right, up, -back) * flip))
		end
	end
	local function mq(parent, a, b, c, d, th, color, mat, refl, trans)
		tri(parent, a, b, c, th, color, mat, refl, trans)
		tri(parent, a, c, d, th, color, mat, refl, trans)
	end
	local function quad(a, b, c, d, th, color, mat, refl, trans)
		mq(root, a, b, c, d, th, color, mat or METAL, refl or 0.3, trans)
	end

	local function band(sx, pts, ws, th, color, lipCol, mat, refl, bulge, surf, soff)
		local L = {}
		for i = 1, #pts do L[i] = { pts[i][1], pts[i][2], ws[i], pts[i][3] } end
		local S2 = smooth(L, 3)
		local N = #S2
		local us = { -1, 0.1, 0.6, 1 }
		local hs = { 0, 1, 0.45, 0 }
		local function cp(i, u, h, dx)
			local p = S2[i]
			local a, b = S2[math.max(i - 1, 1)], S2[math.min(i + 1, N)]
			local tz, ty = b[1] - a[1], b[2] - a[2]
			local l = math.sqrt(tz * tz + ty * ty)
			tz, ty = tz / l, ty / l
			local env = math.max(0, math.sin(math.pi * (i - 1) / (N - 1))) ^ 0.5
			local zz, yy = p[1] - u * ty * p[3] / 2, p[2] + u * tz * p[3] / 2
			local bx = surf and (surf(zz, yy) + soff) or p[4]
			return V3(sx * (bx + bulge * h * env + (dx or 0)), yy, zz)
		end
		for i = 1, N - 1 do
			for j = 1, #us - 1 do
				quad(cp(i, us[j], hs[j]), cp(i + 1, us[j], hs[j]), cp(i + 1, us[j + 1], hs[j + 1]), cp(i, us[j + 1], hs[j + 1]), th, color, mat, refl)
			end
			for _, u in ipairs({ -1, 1 }) do
				quad(cp(i, u, 0), cp(i + 1, u, 0), cp(i + 1, u, 0, -0.12), cp(i, u, 0, -0.12), 0.05, lipCol, mat, refl)
			end
		end
	end

	local function pan(pts, th, color, ridgeCol, mat, refl, camber)
		local S2 = smooth(pts, 3)
		local N = #S2
		local us = { -1, -0.5, 0, 0.5, 1 }
		local function cp(i, u)
			local p = S2[i]
			return V3(u * p[3] / 2, p[2] + camber * (1 - u * u), p[1])
		end
		for i = 1, N - 1 do
			for j = 1, #us - 1 do
				local col = (j == 2 or j == 3) and ridgeCol or color
				mq(root, cp(i, us[j]), cp(i + 1, us[j]), cp(i + 1, us[j + 1]), cp(i, us[j + 1]), th, col, mat, refl)
			end
		end
	end
	local function loft(st, sub, nT, n, colSide, colTop, mat, refl, capFront, edgeCol)
		local rows = smooth(st, sub)
		local rings = {}
		for i, s in ipairs(rows) do
			local r = {}
			for k = 0, nT do
				local t = math.pi * k / nT
				local c, sn = math.cos(t), math.sin(t)
				local x = s[2] * (c < 0 and -1 or 1) * math.abs(c) ^ (2 / n)
				local y = s[4] + (s[3] - s[4]) * math.abs(sn) ^ (2 / n)
				r[k] = V3(x, y, s[1])
			end
			rings[i] = r
		end
		for i = 1, #rings - 1 do
			for k = 0, nT - 1 do
				local mid = (k + 0.5) / nT
				local col = (mid > 0.3 and mid < 0.7) and colTop or colSide
				mq(root, rings[i][k], rings[i + 1][k], rings[i + 1][k + 1], rings[i][k + 1], 0.1, col, mat, refl)
			end
			if false then
				tube(root, "LoftBorda", rings[i][0], rings[i + 1][0], 0.07, edgeCol, SP)
				tube(root, "LoftBorda", rings[i][nT], rings[i + 1][nT], 0.07, edgeCol, SP)
			end
		end
		if capFront then
			local r, s = rings[1], rows[1]
			local ctr = V3(0, (s[3] + s[4]) / 2, s[1] - 0.01)
			for k = 0, nT - 1 do tri(root, ctr, r[k], r[k + 1], 0.1, colSide, mat, refl) end
		end
		return rows, rings
	end
	local function rowAt(rows, z)
		for i = 1, #rows - 1 do
			if z <= rows[i + 1][1] then
				local t = (z - rows[i][1]) / (rows[i + 1][1] - rows[i][1])
				local o = {}
				for k = 1, 4 do o[k] = rows[i][k] + (rows[i + 1][k] - rows[i][k]) * t end
				return o
			end
		end
		return rows[#rows]
	end
	local function surfX(rows, n, z, y)
		local s = rowAt(rows, z)
		local f = math.clamp((y - s[4]) / (s[3] - s[4]), 0, 1)
		local sn = f ^ (n / 2)
		return s[2] * math.sqrt(math.max(1 - sn * sn, 0)) ^ (2 / n)
	end
	local function spline(parent, name, pts, d, color, mat, refl, sub)
		local L = {}
		for i, p in ipairs(pts) do L[i] = { p.X, p.Y, p.Z } end
		local S2 = smooth(L, sub or 4)
		for i = 1, #S2 - 1 do
			tube(parent, name, V3(S2[i][1], S2[i][2], S2[i][3]), V3(S2[i + 1][1], S2[i + 1][2], S2[i + 1][3]), d, color, mat, refl)
			ball(parent, name .. "J", d * 1.02, V3(S2[i + 1][1], S2[i + 1][2], S2[i + 1][3]), color, mat, refl)
		end
	end
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

	local NB = 2.8
	local bodyRows, bodyRings = loft({
		{ -1.9, 0.95, 3.85, 3.0 }, { -1.2, 0.92, 3.78, 2.95 }, { -0.6, 0.9, 3.68, 2.9 }, { 0.0, 0.85, 3.5, 2.85 }, { 0.5, 0.75, 3.32, 2.85 },
	}, 3, 8, NB, PURPLE, HIGH, METAL, 0.35, false, CARBON)

	pan({ { -1.00, 0.84, 0.90 }, { -0.40, 0.82, 0.90 }, { 0.40, 0.78, 1.00 }, { 1.20, 0.80, 0.90 }, { 1.50, 0.86, 0.60 } },
		0.1, CARBON, DEEP, SP, 0.1, -0.1)

	do
		local R0 = bodyRings[1]
		local Vt = {
			B = V3(0, 3.74, -2.5), C = V3(0, 3.56, -3.05), D = V3(0, 3.44, -3.22), E = V3(0, 3.1, -3.02), F = V3(0, 2.9, -2.45),
			H = V3(0.5, 3.68, -2.55), H2 = V3(0.52, 3.52, -3.0), I = V3(0.92, 3.6, -2.45), J = V3(0.97, 3.48, -2.4),
			K = V3(0.86, 3.44, -3.0), K2 = V3(0.82, 3.28, -2.85), L = V3(0.98, 3.0, -2.3), M = V3(0.5, 3.3, -3.1), N2 = V3(0.55, 3.0, -2.7),
		}
		local function pb(pts, d, col, mat, nm)
			local out = {}
			for i = 1, #pts - 1 do
				local br = bar(root, nm, pts[i], pts[i + 1], d, col, mat)
				if br then out[#out + 1] = br end
				out[#out + 1] = ball(root, nm, d, pts[i + 1], col, mat)
			end
			return out
		end
		for _, sx in ipairs({ -1, 1 }) do
			local function P(k) local v = Vt[k] return V3(sx * v.X, v.Y, v.Z) end
			local function r(k) return sx == 1 and R0[k] or R0[8 - k] end
			local function g(a, b, c, d, col) mq(root, a, b, c, d, 0.1, col, METAL, 0.35) end
			local function t3(a, b, c, col) tri(root, a, b, c, 0.1, col, METAL, 0.3) end
			g(r(4), P("B"), P("H"), r(3), HIGH)
			g(P("B"), P("C"), P("H2"), P("H"), HIGH)
			g(r(3), P("H"), P("I"), r(2), PURPLE)
			g(P("H"), P("H2"), P("K"), P("I"), HIGH)
			g(r(2), P("I"), P("J"), r(1), PURPLE)
			g(r(1), P("J"), P("L"), r(0), PURPLE)

			g(P("H2"), P("K"), P("K2"), P("M"), PURPLE)
			t3(P("C"), P("D"), P("H2"), HIGH)
			t3(P("D"), P("M"), P("H2"), DEEP)
			t3(P("D"), P("E"), P("M"), DEEP)
			t3(P("E"), P("N2"), P("M"), CARBON)
			t3(P("M"), P("K2"), P("N2"), CARBON)
			t3(P("E"), P("F"), P("N2"), CARBON)
			for _, e in ipairs({ { "B", "C" }, { "C", "D" }, { "D", "H2" }, { "H2", "K" }, { "D", "M" }, { "M", "K2" }, { "I", "K" }, { "H", "I" }, { "K", "L" } }) do
				tube(root, "NarizVinco", P(e[1]), P(e[2]), 0.05, CARBON, SP)
			end
			tube(root, "NarizFio", P("I") + V3(0, 0.03, 0), P("K") + V3(0, 0.03, 0), 0.04, YEL, METAL, 0.3)

			do
				local function E(x, y, z) return V3(sx * x, y, z) end
				local O1 = E(0.46, 3.70, -2.80)
				local O2 = E(0.60, 4.02, -2.55)
				local O3 = E(1.04, 4.30, -1.92)
				local O4 = E(1.03, 3.62, -1.85)
				local O5 = E(0.99, 3.58, -2.50)
				local O6 = E(0.50, 3.80, -1.90)
				tri(root, O1, O2, O5, 0.1, HIGH, METAL, 0.35)
				mq(root, O2, O3, O4, O5, 0.1, PURPLE, METAL, 0.35)
				mq(root, O1, O2, O3, O6, 0.1, DEEP, METAL, 0.3)
				tri(root, O1, O6, O4, 0.1, CARBON, SP)
				tube(root, "OrelhaBorda", O1, O2, 0.05, CARBON, SP)
				tube(root, "OrelhaBorda", O2, O3, 0.05, CARBON, SP)
				tube(root, "OrelhaBorda", O3, O4, 0.05, CARBON, SP)
				tube(root, "OrelhaBorda", O2, O5, 0.05, CARBON, SP)
				tube(root, "OrelhaFio", O2 + V3(0, 0.03, 0), O3 + V3(0, 0.03, 0), 0.035, YEL, METAL, 0.3)
				ball(root, "OrelhaPonta", 0.07, O3, CARBON, SP)
			end
			local o = V3(0, 0, -0.035)
			pb({ P("D") + V3(0, 0.0, -0.03), P("H2") + V3(0, 0.005, -0.035), P("K") + V3(0, 0.01, -0.035) }, 0.13, BLACK, SP, "FarolFundo")
			local l1 = pb({ P("D") + V3(0, 0.0, -0.085), P("H2") + V3(0, 0.005, -0.085), P("K") + V3(0, 0.01, -0.08) }, 0.07, WHITE_LED, NEON, "LED")
			local l2 = pb({ P("D"):Lerp(P("M"), 0.1) + o, P("M") + o, P("K2") + o }, 0.045, BLUEL, NEON, "LEDInterno")
			for _, b in ipairs(l1) do M.leds[#M.leds + 1] = b end
			for _, b in ipairs(l2) do M.leds[#M.leds + 1] = b end
			if sx == -1 then M.ledL = l1[1] else M.ledR = l1[1] end
			add(root, "EntradaAr", V3(0.02, 0.16, 0.5), CFrame.new(sx * 0.995, 3.2, -2.1), BLACK, SP)
			for k = 0, 3 do
				add(root, "EntradaArGrade", V3(0.025, 0.02, 0.45), CFrame.new(sx * 1.005, 3.14 + k * 0.045, -2.1), GREY, METAL, nil, 0.3)
			end
			shield(sx * 0.99, 3.22, -2.3, 0.55, sx)
			tube(root, "TanqueFio", V3(sx * (surfX(bodyRows, NB, -1.8, 3.6) + 0.05), 3.6, -1.8), V3(sx * (surfX(bodyRows, NB, -0.3, 3.4) + 0.05), 3.4, -0.3), 0.05, YEL, METAL, 0.3)
		end
	end
	local lamp = add(root, "Luz", V3(0.2, 0.2, 0.2), CFrame.new(0, 3.45, -3.25), WHITE_LED, SP, nil, 0, 1)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Range = Config.Headlight.Range
	spot.Brightness = Config.Headlight.Brightness
	spot.Angle = Config.Headlight.Angle
	spot.Color = Color3.fromRGB(235, 244, 255)
	spot.Enabled = false
	spot.Parent = lamp
	M.spot = spot

	M.setLight = function(on)
		spot.Enabled = on
		for _, led in ipairs(M.leds) do
			local onCol = (led.Name == "LEDInterno") and BLUEL or WHITE_LED
			led.Color = on and onCol or Color3.fromRGB(58, 64, 76)
			led.Material = on and NEON or SP
			led.Reflectance = on and 0 or 0.25
		end
	end
	M.setLight(false)
	add(root, "EmblemaNariz", V3(0.18, 0.03, 0.22), CFrame.new(0, 3.72, -2.72) * CFrame.Angles(-0.3, 0, 0), YEL, SP)
	add(root, "TanqueTampa", V3(0.3, 0.04, 0.3), CFrame.new(0, rowAt(bodyRows, -1.15)[3] + 0.025, -1.15) * CFrame.Angles(0.05, 0, 0), CARBON, METAL, nil, 0.4)

	for _, sx in ipairs({ -1, 1 }) do

		band(sx, { { -3.00, 3.40, 0.86 }, { -2.70, 3.36, 0.92 }, { -2.40, 3.30, 0.96 }, { -2.10, 3.28, 0.90 }, { -1.45, 2.98, 0.84 }, { -0.90, 2.26, 0.76 }, { -0.80, 1.38, 0.66 }, { -0.60, 0.89, 0.58 }, { -0.10, 0.68, 0.54 }, { 0.80, 0.64, 0.52 }, { 1.40, 0.68, 0.52 }, { 1.60, 0.72, 0.52 } },
			{ 0.22, 0.60, 0.62, 0.60, 0.68, 0.84, 0.66, 0.52, 0.40, 0.32, 0.22, 0.08 }, 0.1, PURPLE, DEEP, METAL, 0.3, 0.06)
		add(root, "MalhaFundo", V3(0.04, 0.7, 1.4), CFrame.new(sx * 0.62, 1.5, -1.0), DARK, SP, nil, 0.05)
		for r = 0, 4 do
			for cI = 0, 8 do
				if (r + cI) % 2 == 0 then
					cylX(root, "MalhaPixel", 0.02, 0.11, CFrame.new(sx * 0.645, 1.2 + r * 0.12, -1.55 + cI * 0.14), GREY, METAL, 0.4)
				end
			end
		end
		cylX(root, "Pedaleira", 0.5, 0.2, CFrame.new(sx * 1.05, 1.05, 1.7), BLACK, METAL, 0.3)
		tube(root, "PedaleiraBraco", V3(sx * 0.8, 1.35, 1.5), V3(sx * 0.95, 1.05, 1.7), 0.14, DARK, METAL, 0.2)
		tube(root, "PedaleiraSuporte", V3(sx * 0.5, 1.25, 0.6), V3(sx * 0.82, 1.35, 1.5), 0.18, DARK, METAL, 0.2)
		ball(root, "PedaleiraJunta", 0.2, V3(sx * 0.82, 1.35, 1.5), DARK, METAL, 0.2)
		tube(root, "Subchassi", V3(sx * 0.45, 2.7, 0.8), V3(sx * 0.55, 2.82, 3.0), 0.14, DARK, METAL, 0.2)
		spline(root, "Chassi", { V3(sx * 0.4, 3.0, -1.0), V3(sx * 0.45, 2.0, -0.9), V3(sx * 0.5, 1.0, 0.4) }, 0.16, DARK, METAL, 0.2, 4)
	end

	M.seatRows = loft({ { 0.3, 0.45, 3.18, 2.9 }, { 0.9, 0.55, 3.04, 2.85 }, { 1.4, 0.56, 2.94, 2.72 }, { 1.9, 0.54, 2.95, 2.74 }, { 2.3, 0.5, 2.98, 2.76 } },
		3, 8, 3, BLACK, DARK, SP, 0.1, false, CARBON)

	loft({ { 0.5, 0.75, 3.32, 2.85 }, { 0.92, 0.58, 3.07, 2.82 } }, 1, 8, NB, PURPLE, HIGH, METAL, 0.35, false, CARBON)
	do

		local st = { { 2.3, 0.5, 2.98, 0.03 }, { 2.8, 0.56, 3.06, 0.05 }, { 3.4, 0.62, 3.14, 0.06 }, { 4.0, 0.66, 3.22, 0.06 }, { 4.5, 0.58, 3.32, 0.04 }, { 4.75, 0.32, 3.38, 0.02 } }
		local rows = smooth(st, 3)
		local function pt(r, f, dy) return V3(r[2] * f, r[3] + r[4] * (1 - f * f) + dy, r[1]) end

		local function pl(r, f) return V3(r[2] * f * 0.8, r[3] - 0.26 + r[4] * 0.5 * (1 - f * f), r[1] - 0.05) end
		local F = { -1, -0.66, -0.33, 0, 0.33, 0.66, 1 }
		for i = 1, #rows - 1 do
			for j = 1, #F - 1 do
				mq(root, pt(rows[i], F[j], 0), pt(rows[i + 1], F[j], 0), pt(rows[i + 1], F[j + 1], 0), pt(rows[i], F[j + 1], 0), 0.08, (j == 3 or j == 4) and HIGH or PURPLE, METAL, 0.3)
				mq(root, pl(rows[i], F[j]), pl(rows[i + 1], F[j]), pl(rows[i + 1], F[j + 1]), pl(rows[i], F[j + 1]), 0.08, CARBON, SP, 0.1)
			end
			for _, sx in ipairs({ -1, 1 }) do
				local e0, e1 = pt(rows[i], sx, 0), pt(rows[i + 1], sx, 0)
				mq(root, e0, e1, pl(rows[i + 1], sx), pl(rows[i], sx), 0.08, PURPLE, METAL, 0.3)
				tube(root, "RabetaFio", e0 + V3(0, 0.03, 0), e1 + V3(0, 0.03, 0), 0.04, YEL, METAL, 0.3)
			end
		end
		local L = {}
		local n0 = #rows - 5
		for i = n0, #rows do local v = pt(rows[i], -1, -0.1) L[#L + 1] = { v.X, v.Y, v.Z } end
		local le = rows[#rows]
		L[#L + 1] = { 0, le[3] + le[4] - 0.08, le[1] + 0.05 }
		for i = #rows, n0, -1 do local v = pt(rows[i], 1, -0.1) L[#L + 1] = { v.X, v.Y, v.Z } end
		local sm = smooth(L, 2)
		for i = 1, #sm - 1 do
			local a, b = V3(sm[i][1], sm[i][2], sm[i][3]), V3(sm[i + 1][1], sm[i + 1][2], sm[i + 1][3])
			local t = bar(root, "Lanterna", a, b, 0.07, RED_DIM, NEON)
			if t then M.tails[#M.tails + 1] = t end
			M.tails[#M.tails + 1] = ball(root, "Lanterna", 0.07, b, RED_DIM, NEON)
		end
		M.tail = M.tails[1]
		for _, sx in ipairs({ -1, 1 }) do
			ell(root, "Pisca", V3(0.12, 0.08, 0.14), CFrame.new(sx * 0.6, 3.12, 4.3), Color3.fromRGB(110, 55, 0), NEON)
			tube(root, "RabetaApoio", V3(sx * 0.5, 2.75, 2.2), V3(sx * 0.58, 2.88, 3.3), 0.09, DARK, METAL, 0.2)
		end

		do
			local H = V3(0, 3.1, 4.78)
			local pc = V3(0, 2.78, 4.81)
			local pcf = CFrame.lookAt(pc, pc + V3(0, 0, 1))
			cylX(root, "PlacaDobradica", 0.52, 0.07, CFrame.new(H), DARK, METAL, 0.4)
			for _, sx in ipairs({ -1, 1 }) do
				add(root, "PlacaClip", V3(0.1, 0.1, 0.14), CFrame.new(sx * 0.3, H.Y + 0.03, H.Z - 0.02), DARK, METAL, nil, 0.3)
				ball(root, "PlacaOrelha", 0.1, V3(sx * 0.2, H.Y - 0.03, H.Z), CHROME, METAL, 0.4)
			end
			add(root, "PlacaChapa", V3(0.84, 0.5, 0.04), pcf * CFrame.new(0, 0, 0.04), BLACK, METAL, nil, 0.2)
			local face = add(root, "PlacaFace", V3(0.9, 0.56, 0.02), pcf, WHITE_LED, SP, nil, 0, 1)
			if face then
				local sg = Instance.new("SurfaceGui")
				sg.Face = Enum.NormalId.Front
				sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
				sg.CanvasSize = Vector2.new(360, 225)
				sg.LightInfluence = 0.6
				sg.Parent = face
				local function rc(o, r) local u = Instance.new("UICorner") u.CornerRadius = UDim.new(0, r) u.Parent = o end
				local outer = Instance.new("Frame")
				outer.Size = UDim2.fromScale(1, 1)
				outer.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
				outer.BorderSizePixel = 0
				outer.Parent = sg
				rc(outer, 30)
				local inner = Instance.new("Frame")
				inner.AnchorPoint = Vector2.new(0.5, 0.5)
				inner.Position = UDim2.fromScale(0.5, 0.5)
				inner.Size = UDim2.fromScale(0.95, 0.9)
				inner.BackgroundColor3 = Color3.fromRGB(244, 244, 240)
				inner.BorderSizePixel = 0
				inner.Parent = outer
				rc(inner, 22)
				local band = Instance.new("Frame")
				band.Size = UDim2.fromScale(1, 0.27)
				band.BackgroundColor3 = Color3.fromRGB(0, 56, 168)
				band.BorderSizePixel = 0
				band.Parent = inner
				rc(band, 22)
				local patch = Instance.new("Frame")
				patch.Position = UDim2.fromScale(0, 0.14)
				patch.Size = UDim2.fromScale(1, 0.13)
				patch.BackgroundColor3 = Color3.fromRGB(0, 56, 168)
				patch.BorderSizePixel = 0
				patch.Parent = inner
				local br = Instance.new("TextLabel")
				br.Position = UDim2.fromScale(0.2, 0.04)
				br.Size = UDim2.fromScale(0.6, 0.2)
				br.BackgroundTransparency = 1
				br.Font = Enum.Font.GothamBold
				br.TextScaled = true
				br.TextColor3 = Color3.fromRGB(255, 255, 255)
				br.Text = "BRASIL"
				br.Parent = inner
				local num = Instance.new("TextLabel")
				num.Name = "PlacaNum"
				num.Position = UDim2.fromScale(0.04, 0.28)
				num.Size = UDim2.fromScale(0.92, 0.5)
				num.BackgroundTransparency = 1
				num.Font = Enum.Font.GothamBlack
				num.TextScaled = true
				num.TextColor3 = Color3.fromRGB(16, 16, 18)
				num.Text = "ABC1D23"
				num.Parent = inner
				local nm = Instance.new("TextLabel")
				nm.Position = UDim2.fromScale(0.25, 0.8)
				nm.Size = UDim2.fromScale(0.5, 0.13)
				nm.BackgroundTransparency = 1
				nm.Font = Enum.Font.GothamMedium
				nm.TextScaled = true
				nm.TextColor3 = Color3.fromRGB(70, 70, 76)
				nm.Text = "Carlinhos"
				nm.Parent = inner
			end
		end
	end

	do
	local function seatSurf(z, x)
		local sr = rowAt(M.seatRows, z)
		local cc = math.min(math.abs(x) / sr[2], 1) ^ 1.5
		local sn = math.sqrt(math.max(1 - cc * cc, 0))
		return sr[4] + (sr[3] - sr[4]) * sn ^ (2 / 3)
	end
	for i = -2, 2 do
		local x = i * 0.2
		local zz = 0.95
		while zz < 2.05 do
			local z2 = zz + 0.22
			tube(root, "BancoCostura", V3(x, seatSurf(zz, x) + 0.012, zz), V3(x, seatSurf(z2, x) + 0.012, z2), 0.025, STCH, SP)
			zz = z2
		end
	end
	end

	cylX(root, "Carter", 1.4, 1.5, CFrame.new(0, 1.5, 0.2), BLACK, METAL, 0.15)
	add(root, "Caixa", V3(1.1, 0.9, 1.6), CFrame.new(0, 1.2, 0.1), DARK, METAL, nil, 0.2)
	for _, sx in ipairs({ -1, 1 }) do
		cylX(root, "CarterTampa", 0.1, 1.3, CFrame.new(sx * 0.74, 1.5, 0.2), BLACK, METAL, 0.25)
		cylX(root, "CarterAnel", 0.06, 1.1, CFrame.new(sx * 0.8, 1.5, 0.2), DARK, METAL, 0.3)
		cylX(root, "CarterAnelOuro", 0.04, 1.2, CFrame.new(sx * 0.785, 1.5, 0.2), GOLD, METAL, 0.45)
		cylX(root, "CarterCentro", 0.07, 0.5, CFrame.new(sx * 0.84, 1.5, 0.2), YEL, METAL, 0.3)
		for i = 0, 15 do
			local a = i * (math.pi / 8)
			add(root, "CarterNervura", V3(0.05, 0.3, 0.06), CFrame.new(sx * 0.83, 1.5, 0.2) * CFrame.Angles(a, 0, 0) * CFrame.new(0, 0.42, 0), BLACK, METAL, nil, 0.2)
			cylX(root, "CarterParafuso", 0.07, 0.075, CFrame.new(sx * 0.82, 1.5 + 0.6 * cos(a), 0.2 + 0.6 * sin(a)), CHROME, METAL, 0.5)
		end
		add(root, "CavaloMini", V3(0.03, 0.22, 0.12), CFrame.new(sx * 0.885, 1.5, 0.2), BLACK, SP)
		add(root, "CavaloMini", V3(0.03, 0.08, 0.22), CFrame.new(sx * 0.885, 1.43, 0.2), BLACK, SP)

		for _, zz in ipairs({ -1.0, -0.75 }) do
			cylY(root, "AmortHasteMotor", 0.95, 0.12, CFrame.new(sx * 0.58, 2.5, zz), CHROME, METAL, 0.5)
			for i = 0, 7 do cylY(root, "AmortMolaMotor", 0.05, 0.3, CFrame.new(sx * 0.58, 2.1 + i * 0.09, zz), i % 2 == 0 and GOLD or DARK, METAL, 0.4) end
			cylY(root, "AmortTopo", 0.12, 0.2, CFrame.new(sx * 0.58, 3.0, zz), YEL, METAL, 0.3)
		end
		for _, zz in ipairs({ 0.5, 0.8 }) do
			cylY(root, "AmortHasteMotor", 0.6, 0.1, CFrame.new(sx * 0.32, 2.52, zz), CHROME, METAL, 0.5)
		end
		cylZ(root, "FiltroBase", 0.45, 0.22, CFrame.new(sx * 0.32, 0.95, -0.85), DARK, METAL, 0.3)
		cylZ(root, "FiltroOleo", 0.5, 0.34, CFrame.new(sx * 0.32, 0.95, -1.25), GOLD, METAL, 0.45)
		cylZ(root, "FiltroTampa", 0.06, 0.26, CFrame.new(sx * 0.32, 0.95, -1.52), CHROME, METAL, 0.5)
		tube(root, "MangueiraOleo", V3(sx * 0.32, 1.1, -1.1), V3(sx * 0.62, 1.5, -0.52), 0.09, BLACK, SP)
		ball(root, "ConexaoOleo", 0.14, V3(sx * 0.62, 1.5, -0.52), ORANGE, METAL, 0.4)
	end
	for _, d in ipairs({ { -0.6, -0.31 }, { 0.6, 0.71 } }) do
		local pitch, cz = d[1], d[2]
		local cfc = CFrame.new(0, 2.24, cz) * CFrame.Angles(pitch, 0, 0)
		cylY(root, "Cilindro", 1.1, 0.6, cfc, BLACK, METAL, 0.2)
		for f = -2, 2 do cylY(root, "CilindroAleta", 0.05, 0.84, cfc * CFrame.new(0, f * 0.2, 0), DARK, METAL, 0.3) end
		cylY(root, "CilindroCabeca", 0.18, 0.74, cfc * CFrame.new(0, 0.62, 0), DARK, METAL, 0.3)
		cylY(root, "CilindroTampa", 0.06, 0.46, cfc * CFrame.new(0, 0.73, 0), YEL, METAL, 0.3)
		for _, sx in ipairs({ -1, 1 }) do
			add(root, "CilindroTirante", V3(0.07, 0.8, 0.07), cfc * CFrame.new(sx * 0.3, 0.15, 0), CHROME, METAL, nil, 0.5)
			cylY(root, "CilindroParafuso", 0.08, 0.1, cfc * CFrame.new(sx * 0.3, 0.7, 0.2), CHROME, METAL, 0.5)
			cylY(root, "CilindroParafuso", 0.08, 0.1, cfc * CFrame.new(sx * 0.3, 0.7, -0.2), CHROME, METAL, 0.5)
			tube(root, "CaboVela", V3(sx * 0.18, 2.95, cz), V3(sx * 0.5, 2.55, cz + 0.2), 0.04, BLACK, SP)
		end
	end
	ell(root, "Airbox", V3(0.7, 0.4, 0.8), CFrame.new(0, 2.9, 0.2), CARBON, METAL, 0.2)

	for _, sx in ipairs({ -1, 1 }) do
		local pts = { V3(sx * 0.58, 2.55, -0.55), V3(sx * 1.0, 2.35, -0.3), V3(sx * 1.2, 1.7, -0.05), V3(sx * 1.2, 1.05, 0.1), V3(sx * 1.25, 0.6, 0.55) }
		spline(root, "Coletor", pts, 0.26, DARK, METAL, 0.3, 4)
		ball(root, "ColetorFlange", 0.36, pts[1], CHROME, METAL, 0.5)
		for i = 2, 4 do
			local dd = (pts[i + 1] - pts[i - 1]).Unit
			tube(root, "ColetorBanda", pts[i] - dd * 0.05, pts[i] + dd * 0.05, 0.32, CHROME, METAL, 0.5)
		end

		local I, E = pts[5], V3(sx * 1.28, 0.7, 2.3)
		local dir = (E - I).Unit
		local function at(t) return I + (E - I) * t end
		tube(root, "EscapeBanda", I - dir * 0.04, I + dir * 0.04, 0.34, CHROME, METAL, 0.5)
		tube(root, "EscapeCone", at(0), at(0.1), 0.3, DARK, METAL, 0.3)
		tube(root, "EscapeCone", at(0.1), at(0.2), 0.4, DARK, METAL, 0.3)
		tube(root, "Escape", at(0.2), at(0.92), 0.46, CARBON, METAL, 0.25)
		for _, t in ipairs({ 0.2, 0.5, 0.8 }) do
			tube(root, "EscapeBanda", at(t - 0.015), at(t + 0.015), 0.5, CHROME, METAL, 0.5)
		end
		tube(root, "EscapeFio", at(0.62), at(0.66), 0.485, YEL, METAL, 0.3)
		tube(root, "PonteiraEscape", at(0.92), at(1.0), 0.54, CHROME, METAL, 0.55)
		tube(root, "EscapeBoca", at(0.99), at(1.0) + dir * 0.015, 0.38, BLACK, SP)

		local sb = at(0.5) + V3(0, 0.2, 0)
		tube(root, "EscapeSuporteBraco", sb, V3(sx * 0.82, 1.35, 1.5), 0.08, DARK, METAL, 0.3)
		ball(root, "EscapeSuporteJunta", 0.14, sb, CHROME, METAL, 0.5)
	end
	local fork = newPart("Fork", V3(0.2, 0.2, 0.2), BLACK, SP, nil, 0, 1)
	M.wFork = weld(root, fork, sCF(CFrame.new(HEAD) * CFrame.Angles(RAKE, 0, 0)))
	local slider = newPart("Slider", V3(0.2, 0.2, 0.2), BLACK, SP, nil, 0, 1)
	M.wSlider = weld(fork, slider, CFrame.new(0, -FL * S, 0))

	local function brakeCaliper(parent, cy, cz, A, rI, rO, aDeg, anchor, hoseTo)
		local base = CFrame.new(0, cy, cz) * CFrame.Angles(math.rad(aDeg), 0, 0)
		local xd = A + 0.04
		local rc = (rI + rO) / 2 + 0.03
		add(parent, "PincaCorpo", V3(0.11, 0.27, 0.34), base * CFrame.new(xd + 0.095, rc, 0), YEL, METAL, nil, 0.3)
		add(parent, "PincaInterna", V3(0.07, 0.25, 0.3), base * CFrame.new(xd - 0.065, rc - 0.01, 0), DARK, METAL, nil, 0.3)
		add(parent, "PincaPonte", V3(0.27, 0.07, 0.34), base * CFrame.new(xd + 0.015, rO + 0.065, 0), YEL, METAL, nil, 0.3)
		add(parent, "PincaFaixa", V3(0.015, 0.2, 0.025), base * CFrame.new(xd + 0.152, rc, 0), BLACK, SP)
		for _, rr in ipairs({ -0.065, 0.065 }) do
			for _, tt in ipairs({ -0.085, 0.085 }) do
				cylX(parent, "PincaPistao", 0.03, 0.085, base * CFrame.new(xd + 0.155, rc + rr, tt), CHROME, METAL, 0.4)
			end
		end
		local p1 = (base * CFrame.new(xd + 0.15, rc, 0)).Position
		tube(parent, "PincaSuporte", p1, anchor, 0.14, DARK, METAL, 0.3)
		if hoseTo then
			tube(parent, "Flexivel", (base * CFrame.new(xd + 0.06, rO + 0.1, 0.05)).Position, hoseTo, 0.07, BLACK, SP)
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		cylY(fork, "TuboSuperior", 1.9, 0.44, CFrame.new(sx * FX, -1.05, 0), BLACK, METAL, 0.25)
		cylY(slider, "PernaInferior", 1.8, 0.3, CFrame.new(sx * FX, 0.8, 0), CHROME, METAL, 0.5)
		ball(slider, "EixoLuva", 0.4, V3(sx * (FX - 0.08), 0, 0), BLACK, METAL, 0.3)
		cylX(slider, "EixoFrente", FX + 0.25 - (FA + 0.05), 0.26, CFrame.new(sx * ((FA + 0.05 + FX + 0.25) / 2), 0, 0), BLACK, METAL, 0.3)
		if sx == 1 then brakeCaliper(slider, 0, 0, FA, 0.45, 0.66, 80, V3(FX - 0.05, 0.05, 0.1), V3(FX - 0.1, 1.3, 0.1)) end
	end
	add(fork, "MesaSuperior", V3(2 * FX + 0.5, 0.3, 0.6), CFrame.new(0, -0.1, 0), DARK, METAL, nil, 0.25)
	add(fork, "MesaInferior", V3(2 * FX + 0.3, 0.26, 0.5), CFrame.new(0, -0.85, 0), DARK, METAL, nil, 0.25)

	for _, sx in ipairs({ -1, 1 }) do
		local p0 = V3(sx * 0.8, 0.3, 0.1)
		local p1 = V3(sx * 1.15, 0.4, 0.34)
		local p2 = V3(sx * 1.38, 0.5, 0.56)
		cylY(fork, "GuidaoCubo", 0.2, 0.5, CFrame.new(sx * FX, 0.18, 0.04), DARK, METAL, 0.3)
		cylY(fork, "GuidaoCuboAnel", 0.04, 0.54, CFrame.new(sx * FX, 0.28, 0.04), CHROME, METAL, 0.5)
		tube(fork, "Guidao", p0, p1, 0.1, BLACK, METAL, 0.2)
		tube(fork, "Guidao", p1, p2, 0.1, BLACK, METAL, 0.2)
		ball(fork, "GuidaoJunta", 0.12, p1, BLACK, METAL, 0.2)
		ball(fork, "GuidaoPonta", 0.11, p0, CHROME, METAL, 0.5)
		tube(fork, "GuidaoLigacao", V3(sx * 0.12, 0.26, 0.1), p0, 0.1, BLACK, METAL, 0.2)

		local g0, g1 = p2, V3(sx * 1.8, 0.57, 0.73)
		local gd = (g1 - g0).Unit
		tube(fork, "Manopla", g0, g1, 0.19, BLACK, SP)
		for k = 1, 4 do
			local c = g0 + (g1 - g0) * (0.15 + k * 0.17)
			tube(fork, "ManoplaAnel", c - gd * 0.015, c + gd * 0.015, 0.21, DARK, SP)
		end
		ball(fork, "ManoplaPeso", 0.17, g1 + gd * 0.02, CHROME, METAL, 0.5)
		if sx == 1 then tube(fork, "AceleradorFlange", g0 + gd * 0.01, g0 + gd * 0.06, 0.25, DARK, METAL, 0.3) end

		local cb = p1:Lerp(p2, 0.55)
		add(fork, "Comando", V3(0.2, 0.12, 0.22), CFrame.new(cb), BLACK, SP, nil, 0.2)
		for k = -1, 1 do
			ball(fork, "Botao", 0.04, cb + V3(sx * k * 0.055, 0.07, 0.02), CHROME, METAL, 0.5)
		end
		ball(fork, "BotaoInicio", 0.05, cb + V3(0, 0.0, 0.115), (sx == 1) and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(255, 130, 0), NEON)

		do
			local bp = p1:Lerp(p2, 0.85)
			local ext = (sx == 1) and 0.05 or 0
			add(fork, "ManeteBase", V3(0.2, 0.14, 0.2), CFrame.new(bp), DARK, METAL, nil, 0.3)
			add(fork, "Reservatorio", V3(0.11, 0.09, 0.13), CFrame.new(bp + V3(0, 0.1, 0)), BLACK, SP, nil, 0.2)
			add(fork, "ReservatorioTampa", V3(0.07, 0.02, 0.09), CFrame.new(bp + V3(0, 0.15, 0)), YEL, METAL, nil, 0.3)
			local A = bp + V3(0, -0.03, -0.09)
			local B = V3(sx * 1.4, 0.43, 0.27)
			local C = V3(sx * (1.66 + ext), 0.47, 0.4)
			tube(fork, "Manete", A, B, 0.06, CHROME, METAL, 0.4)
			ball(fork, "ManeteJunta", 0.07, B, CHROME, METAL, 0.4)
			tube(fork, "Manete", B, C, 0.05, CHROME, METAL, 0.4)
			ball(fork, "ManetePonta", 0.08, C, CHROME, METAL, 0.4)
		end
	end

	local rakeCF = CFrame.Angles(RAKE, 0, 0)
	local wc = V3(0, -FL, 0)
	local Rf = R + 0.26

	do
		local nA = 16
		local a0, a1 = -0.57, 0.65
		local Rg = R + 0.12
		local fr = { -1, -0.72, -0.34, 0, 0.34, 0.72, 1 }
		local dr = { 1, 0.7, 0.2, 0, 0.2, 0.7, 1 }
		local NC = #fr
		local function wfOf(u)
			local w = 0.92 + 0.08 * math.min(u / 0.25, 1)
			if u > 0.7 then
				local k = (u - 0.7) / 0.3
				w = w * (0.55 + 0.45 * math.sqrt(math.max(1 - k * k, 0)))
			end
			return w
		end
		local function fp(i, j, e)
			local u = i / nA
			local a = a0 + (a1 - a0) * u
			local wf = wfOf(u)
			local t = (a - 0.3) / 0.9
			local h = 0.10 + 0.14 * math.max(0, cos(t * (math.pi / 2)))
			local lip = 0
			local rad = Rg + 0.07 * (1 - dr[j]) + lip - h * dr[j] * (0.5 + 0.5 * wf) + (e or 0)
			return wc + rakeCF:VectorToObjectSpace(V3((FA + 0.12) * wf * fr[j], rad * cos(a), -rad * sin(a)))
		end
		for i = 0, nA - 1 do
			for j = 1, NC - 1 do
				local mid = (j == 3 or j == 4)
				mq(fork, fp(i, j), fp(i + 1, j), fp(i + 1, j + 1), fp(i, j + 1), 0.08, mid and HIGH or PURPLE, METAL, 0.3)
			end
			tube(fork, "ParalamaBorda", fp(i, 1), fp(i + 1, 1), 0.06, CARBON, SP)
			tube(fork, "ParalamaBorda", fp(i, NC), fp(i + 1, NC), 0.06, CARBON, SP)
			tube(fork, "ParalamaFio", fp(i, 4, 0.04), fp(i + 1, 4, 0.04), 0.04, YEL, METAL, 0.3)
			tube(fork, "ParalamaVinco", fp(i, 2), fp(i + 1, 2), 0.035, CARBON, SP)
			tube(fork, "ParalamaVinco", fp(i, NC - 1), fp(i + 1, NC - 1), 0.035, CARBON, SP)
		end
		tube(fork, "ParalamaPonta", fp(nA, 1), fp(nA, NC), 0.07, CARBON, SP)
		tube(fork, "ParalamaPonta", fp(0, 1), fp(0, NC), 0.07, CARBON, SP)

		local iS = math.clamp(math.floor(nA * ((-RAKE) - a0) / (a1 - a0) + 0.5), 0, nA)
		for _, jj in ipairs({ 1, NC }) do
			local pe = fp(iS, jj)
			local sx = (jj == 1) and -1 or 1
			local pl = V3(sx * FX, pe.Y, 0)
			tube(fork, "ParalamaApoio", pe, pl, 0.2, DARK, METAL, 0.25)
			ball(fork, "ParalamaApoioJunta", 0.26, pl, DARK, METAL, 0.25)
		end
	end

	local TIRE = Color3.fromRGB(22, 22, 25)
	local GROOVE = Color3.fromRGB(6, 6, 7)

	local function shell(core, name, pts, nR, th, color, mat, refl)
		for k = 1, #pts - 1 do
			local x0, r0, x1, r1 = pts[k][1], pts[k][2], pts[k + 1][1], pts[k + 1][2]
			local dx, dr = x1 - x0, r1 - r0
			local L = math.sqrt(dx * dx + dr * dr)
			if L > 0.001 then
				local xm, rm = (x0 + x1) / 2, (r0 + r1) / 2
				local tang = 2 * math.pi * math.max(r0, r1) / nR * 1.1
				for i = 0, nR - 1 do
					local a = (i + 0.5) * (2 * math.pi / nR)
					local ca, sa = cos(a), sin(a)
					local ex, er, et = V3(1, 0, 0), V3(0, ca, sa), V3(0, -sa, ca)
					local n = (ex * (-dr) + er * dx) / L
					add(core, name, V3(tang, th, L * 1.06), CFrame.fromMatrix(V3(xm, rm * ca, rm * sa), et, n), color, mat, nil, refl)
				end
			end
		end
	end
	local function buildTire(core, A, n, G, D)
		local Rc = 0.95
		local B = R - Rc
		local Ac = A - D

		local nT = 8
		local tp = {}
		for i = 0, nT do
			local x = -Ac + (2 * Ac) * i / nT
			local u = x / A
			tp[#tp + 1] = { x, Rc + B * math.sqrt(math.max(1 - u * u, 0)) }
		end
		shell(core, "Banda", tp, 44, 0.12, TIRE, SP, 0)

		local function prof(x)
			local u = x / A
			return Rc + B * math.sqrt(math.max(1 - u * u, 0))
		end
		for _, sx in ipairs({ -1, 1 }) do
			local xa, xb = Ac + D * 0.5, A - 0.03
			shell(core, "Parede", {
				{ sx * Ac, prof(Ac) }, { sx * xa, prof(xa) }, { sx * xb, prof(xb) }, { sx * A, 0.96 },
			}, 40, 0.08, TIRE, SP, 0)
		end
		-- sulcos pretos removidos do pneu
	end
	local function spokes(core, x, n, r0, r1, wd, th, color)
		for i = 0, n - 1 do
			local a = i * (2 * math.pi / n)
			for _, dd in ipairs({ -0.09, 0.09 }) do
				add(core, "Raio", V3(th, r1 - r0, wd), CFrame.Angles(a + dd, 0, 0) * CFrame.new(x, (r0 + r1) / 2, 0), color, METAL, nil, 0.3)
			end
		end
	end

	local function ringX(core, name, x, rIn, rOut, n, th, color, refl)
		local rm = (rIn + rOut) / 2
		local tang = 2 * math.pi * rm / n * 1.1
		for i = 0, n - 1 do
			local a = i * (2 * math.pi / n)
			add(core, name, V3(th, rOut - rIn, tang), CFrame.Angles(a, 0, 0) * CFrame.new(x, rm, 0), color, METAL, nil, refl)
		end
	end

	local function ySpokes(core, x, n, hubR, forkR, rimR, color)
		for i = 0, n - 1 do
			local a = i * (2 * math.pi / n)
			local a1 = a + 0.1
			local function P(r, ang) return V3(x, r * cos(ang), r * sin(ang)) end
			bar(core, "Raio", P(hubR, a), P(forkR, a1), 0.1, color, METAL, 0.3)
			bar(core, "Raio", P(forkR - 0.02, a1), P(rimR, a1 + 0.2), 0.055, color, METAL, 0.3)
			bar(core, "Raio", P(forkR - 0.02, a1), P(rimR, a1 - 0.2), 0.055, color, METAL, 0.3)
		end
	end
	local function wheelSide(core, A, sx, kind, D, ds)

		local function X(d) return sx * (A - D + d) end
		local function XO(d) return sx * (A + d) end
		shell(core, "AroBarril", { { sx * (A - D + 0.05), 0.915 }, { 0, 0.915 } }, 40, 0.05, DISC, METAL, 0.4)
		shell(core, "AroTambor", { { sx * (A - 0.02), 0.95 }, { sx * (A - D + 0.05), 0.915 } }, 40, 0.05, DISC, METAL, 0.55)
		ySpokes(core, X(0.12), 10, 0.2, 0.52, 0.91, BLACK)
		cylX(core, "Cubo", 0.2, 0.46, CFrame.new(X(0.12), 0, 0), BLACK, METAL, 0.25)
		cylX(core, "CuboTubo", D + 0.12, 0.26, CFrame.new(sx * (A - D / 2 + 0.06), 0, 0), BLACK, METAL, 0.2)
		cylX(core, "Porca", 0.14, 0.22, CFrame.new(XO(0.1), 0, 0), CHROME, METAL, 0.55)
		if kind == "disc" then

			local k = ds or 1
			local rI, rO = 0.45 * k, 0.66 * k
			local DISC_D = Color3.fromRGB(112, 115, 122)
			shell(core, "Disco", { { XO(0.04), rI }, { XO(0.04), rO } }, 48, 0.035, DISC_D, METAL, 0.3)
			for hi = 0, 23 do
				local ang = hi * (2 * math.pi / 24)
				local ang2 = ang + math.pi / 24
				local r1 = rI + (rO - rI) * 0.3
				local r2 = rI + (rO - rI) * 0.7
				cylX(core, "Furo", 0.012, 0.05, CFrame.new(XO(0.059), r1 * cos(ang), r1 * sin(ang)), BLACK, SP)
				cylX(core, "Furo", 0.012, 0.05, CFrame.new(XO(0.059), r2 * cos(ang2), r2 * sin(ang2)), BLACK, SP)
			end
			shell(core, "DiscoCubo", { { XO(0.075), 0.24 }, { XO(0.075), 0.34 } }, 24, 0.05, DARK, METAL, 0.3)
			for bi = 0, 5 do
				local ang = bi * (2 * math.pi / 6)
				local re = rI + 0.03
				local ae = ang + 0.35
				bar(core, "DiscoBraco", V3(XO(0.06), 0.3 * cos(ang), 0.3 * sin(ang)), V3(XO(0.05), re * cos(ae), re * sin(ae)), 0.08, BLACK, METAL, 0.3)
				cylX(core, "DiscoBobina", 0.08, 0.075, CFrame.new(XO(0.07), re * cos(ae), re * sin(ae)), CHROME, METAL, 0.5)
				cylX(core, "DiscoParafuso", 0.03, 0.05, CFrame.new(XO(0.1), 0.3 * cos(ang), 0.3 * sin(ang)), CHROME, METAL, 0.5)
			end
		elseif kind == "sprocket" then

			local xs = XO(0.08)
			shell(core, "CoroaPlaca", { { xs, 0.46 }, { xs, 0.76 } }, 36, 0.06, GREY, METAL, 0.35)
			for ti = 0, 35 do
				local a = ti * (2 * math.pi / 36)
				add(core, "Dente", V3(0.05, 0.14, 0.075), CFrame.Angles(a, 0, 0) * CFrame.new(xs, 0.79, 0), GREY, METAL, nil, 0.35)
			end
			for hi = 0, 11 do
				local a = hi * (2 * math.pi / 12) + 0.26
				cylX(core, "CoroaFuro", 0.012, 0.15, CFrame.new(xs + sx * 0.033, 0.61 * cos(a), 0.61 * sin(a)), BLACK, SP)
			end
			for bi = 0, 7 do
				local ang = bi * (2 * math.pi / 8)
				tube(core, "CoroaBraco", V3(xs, 0.2 * cos(ang), 0.2 * sin(ang)), V3(xs, 0.5 * cos(ang + 0.12), 0.5 * sin(ang + 0.12)), 0.08, GREY, METAL, 0.35)
			end
		end
	end

	local fcore = newPart("RodaFrente", V3(0.2, 0.2, 0.2), BLACK, SP, nil, 0, 1)
	M.wFWheel = weld(slider, fcore, CFrame.new())
	buildTire(fcore, FA, 45, 12, DF)
	wheelSide(fcore, FA, -1, "plain", DF)
	wheelSide(fcore, FA, 1, "disc", DF)

	local swing = newPart("Swing", V3(0.2, 0.2, 0.2), BLACK, SP, nil, 0, 1)
	M.wSwing = weld(root, swing, sCF(CFrame.new(PIV)))
	local rcore = newPart("RodaTras", V3(0.2, 0.2, 0.2), BLACK, SP, nil, 0, 1)
	M.wRWheel = weld(swing, rcore, sCF(CFrame.new(0, ARM_Y, ARM_Z)))
	M.rtireBase = CFrame.new(0, ARM_Y * S, ARM_Z * S)
	buildTire(rcore, RA, 53, 14, DR)
	wheelSide(rcore, RA, -1, "sprocket", DR)
	wheelSide(rcore, RA, 1, "disc", DR, 0.85)

	local armSt = {
		{ 0.0, 0.10, 0.34, 0.20 },
		{ 0.9, 0.03, 0.31, 0.18 },
		{ 1.8, -0.07, 0.27, 0.16 },
		{ ARM_Z, ARM_Y, 0.24, 0.14 },
	}

	local function hub(parent, x0, x1, cy, cz, r, col, capCol)
		local n = 8
		local function P(x, k)
			local a = (k + 0.5) * 2 * math.pi / n
			return V3(x, cy + r * math.cos(a), cz + r * math.sin(a))
		end
		local c = V3(x1, cy, cz)
		for k = 0, n - 1 do
			mq(parent, P(x0, k), P(x1, k), P(x1, k + 1), P(x0, k + 1), 0.06, col, METAL, 0.3)
			tri(parent, c, P(x1, k), P(x1, k + 1), 0.06, capCol or col, METAL, 0.3)
		end
	end
	local function disc(parent, x, cy, cz, r, col)
		local c = V3(x, cy, cz)
		for k = 0, 7 do
			local a0, a1 = (k + 0.5) * math.pi / 4, (k + 1.5) * math.pi / 4
			tri(parent, c, V3(x, cy + r * math.cos(a0), cz + r * math.sin(a0)), V3(x, cy + r * math.cos(a1), cz + r * math.sin(a1)), 0.05, col, METAL, 0.45)
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		local rings = {}
		for i, st in ipairs(armSt) do
			local z, yc, hh, wx = st[1], st[2], st[3], st[4]
			local xo, xi = sx * (SWX + wx), sx * (SWX - wx)
			local yT, yB = yc + hh, yc - hh
			rings[i] = {
				V3(xo, yB, z), V3(xo, yT - 0.07, z), V3(xo - sx * 0.06, yT, z),
				V3(sx * SWX, yT + 0.04, z), V3(xi, yT, z), V3(xi, yB, z),
			}
		end
		local cols = { PURPLE, HIGH, HIGH, HIGH, CARBON, CARBON }
		for i = 1, #rings - 1 do
			for k = 1, 6 do
				local k2 = (k % 6) + 1
				mq(swing, rings[i][k], rings[i + 1][k], rings[i + 1][k2], rings[i][k2], 0.08, cols[k], METAL, 0.3)
			end
			tube(swing, "BracoFio", rings[i][4] + V3(0, 0.03, 0), rings[i + 1][4] + V3(0, 0.03, 0), 0.03, YEL, METAL, 0.3)
		end

		for _, ri in ipairs({ rings[1], rings[#rings] }) do
			mq(swing, ri[1], ri[2], ri[3], ri[4], 0.08, CARBON, METAL, 0.3)
			mq(swing, ri[1], ri[4], ri[5], ri[6], 0.08, CARBON, METAL, 0.3)
		end
		hub(swing, sx * (SWX - 0.2), sx * (SWX + 0.24), 0, 0, 0.30, DARK, CARBON)
		disc(swing, sx * (SWX + 0.27), 0, 0, 0.2, GOLD)
		hub(swing, sx * (SWX - 0.2), sx * (SWX + 0.14), ARM_Y, ARM_Z, 0.26, DARK, CARBON)
		cylX(swing, "EixoTras", 0.7, 0.24, CFrame.new(sx * 1.1, ARM_Y, ARM_Z), DARK, METAL, 0.3)
		add(swing, "BracoPlaca", V3(0.06, 0.52, 0.8), CFrame.new(sx * (SWX + 0.17), ARM_Y, ARM_Z - 0.1), DARK, METAL, nil, 0.3)
		for _, dz in ipairs({ -0.38, 0.18 }) do
			cylX(swing, "BracoParafuso", 0.1, 0.12, CFrame.new(sx * (SWX + 0.22), ARM_Y, ARM_Z - 0.1 + dz), CHROME, METAL, 0.5)
		end
		cylX(swing, "EixoPorca", 0.1, 0.34, CFrame.new(sx * (SWX + 0.32), ARM_Y, ARM_Z), CHROME, METAL, 0.5)
	end

	cylX(swing, "BracoPivoEixo", 2 * SWX, 0.3, CFrame.new(0, 0, 0), DARK, METAL, 0.3)
	add(swing, "BracoPivoCaixa", V3(1.2, 0.5, 0.45), CFrame.new(0, 0.05, 0.05), DARK, METAL, nil, 0.3)
	add(swing, "BracoTravessa", V3(2 * SWX - 0.3, 0.3, 0.42), CFrame.new(0, 0.08, 0.38), CARBON, METAL, nil, 0.25)
	add(swing, "AmortApoio", V3(0.3, 0.36, 0.3), CFrame.new(0, 0.2, 0.55), DARK, METAL, nil, 0.3)

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
		ball(fork, "TampaGarfo", 0.32, V3(sx * FX, -0.08, 0), GOLD, METAL, 0.45)
		cylY(fork, "Ajustador", 0.16, 0.14, CFrame.new(sx * FX, 0.06, 0), CHROME, METAL, 0.5)
		cylZ(fork, "ParafusoMesa", 0.12, 0.1, CFrame.new(sx * (FX - 0.2), -0.85, 0.3), CHROME, METAL, 0.5)
		cylZ(fork, "ParafusoMesa", 0.12, 0.1, CFrame.new(sx * (FX - 0.2), -0.1, 0.3), CHROME, METAL, 0.5)
		cylY(slider, "PernaAnel", 0.06, 0.34, CFrame.new(sx * FX, 1.7, 0), GOLD, METAL, 0.4)
		cylY(slider, "PernaAnel", 0.06, 0.34, CFrame.new(sx * FX, -0.2, 0), GOLD, METAL, 0.4)
	end

	do
		brakeCaliper(swing, ARM_Y, ARM_Z, RA, 0.45 * 0.85, 0.66 * 0.85, 225, V3(RA + 0.3, ARM_Y, ARM_Z), nil)

		cylX(root, "EixoMotor", 0.2, 0.16, CFrame.new(CH.XC + 0.03, CH.mc.Y, CH.mc.Z), DARK, METAL, 0.3)
		local mcore = newPart("CoroaMotorCore", V3(0.2, 0.2, 0.2), BLACK, SP, nil, 0, 1)
		M.wMotor = weld(root, mcore, sCF(CFrame.new(CH.mc)))
		shell(mcore, "CoroaMotorPlaca", { { 0, 0.1 }, { 0, CH.rM - 0.04 } }, 24, 0.06, GREY, METAL, 0.35)
		for ti = 0, CH.NM - 1 do
			local a = ti * (2 * math.pi / CH.NM)
			add(mcore, "CoroaMotorDente", V3(0.05, 0.12, 0.08), CFrame.Angles(a, 0, 0) * CFrame.new(0, CH.rM + 0.01, 0), GREY, METAL, nil, 0.35)
		end
		cylX(mcore, "CoroaMotorCubo", 0.14, 0.24, CFrame.new(-0.04, 0, 0), CHROME, METAL, 0.5)

		local _, P0 = chainPathAt(CFrame.new())
		local NL = math.floor(P0.L / (CH.pitch * S) + 0.5)
		M.chain = {}
		local SILVER2 = Color3.fromRGB(168, 173, 181)
		for i = 1, (Config.LiteMode == "super") and 0 or NL * 2 do
			local lk
			if i % 2 == 1 then
				lk = newPart("EloRolete", V3(0.1, 0.1, 0.1), CHROME, METAL, CYL, 0.5)
			else
				lk = newPart("EloPlaca", V3(0.07, 0.06, CH.pitch * 0.95), SILVER2, METAL, nil, 0.5)
			end
			lk.Anchored = true
			M.chain[i] = lk
		end
		M.chainCF = table.create(NL * 2, CFrame.new())
	end

	local function rimBolts(core, A, sx, n)
		for i = 0, n - 1 do
			local a = i * (2 * math.pi / n)
			cylX(core, "AroParafuso", 0.035, 0.07, CFrame.new(sx * (A - 0.005), 0.9 * cos(a), 0.9 * sin(a)), CHROME, METAL, 0.5)
		end
	end

	do
		add(fork, "Riser", V3(0.22, 0.3, 0.22), CFrame.new(0, 0.2, 0.1), DARK, METAL, nil, 0.2)
		add(fork, "Painel", V3(0.6, 0.13, 0.38), CFrame.new(0, 0.45, 0.12), BLACK, SP, nil, 0.15)
		add(fork, "Painel", V3(0.6, 0.025, 0.38), CFrame.new(0, 0.53, 0.12), CARBON, SP, nil, 0.15)
		local tela = add(fork, "PainelTela", V3(0.5, 0.025, 0.29), CFrame.new(0, 0.56, 0.12), Color3.fromRGB(4, 6, 10), SP, nil, 0.1)
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
		add(fork, "PainelLed", V3(0.5, 0.012, 0.02), CFrame.new(0, 0.575, 0.3), BLUE_LED, NEON)
		ball(fork, "PainelAlerta", 0.045, V3(0.27, 0.56, 0.0), Color3.fromRGB(255, 40, 40), NEON)

		for _, sx in ipairs({ -1, 1 }) do
			local pc = CFrame.new(sx * 0.42, 0.47, 0.12)
			cylY(fork, "Pod", 0.14, 0.24, pc, CARBON, METAL, 0.3)
			cylY(fork, "PodAnel", 0.02, 0.26, pc * CFrame.new(0, 0.07, 0), CHROME, METAL, 0.55)
			ball(fork, "PodCentro", 0.07, (pc * CFrame.new(0, 0.07, 0)).Position, DARK, METAL, 0.3)
			ball(fork, "Botao", 0.035, (pc * CFrame.new(sx * 0.07, 0.07, -0.04)).Position, YEL, METAL, 0.3)
			ball(fork, "Botao", 0.035, (pc * CFrame.new(sx * 0.07, 0.07, 0.05)).Position, CHROME, METAL, 0.5)
			tube(fork, "PodSuporte", (pc * CFrame.new(0, -0.05, 0)).Position, V3(sx * 0.95, 0.22, 0.1), 0.12, DARK, METAL, 0.25)
		end
	end
	model.Parent = workspace
	return M
end

local CACHE_VER = "m12"
local CACHE_DIR = "MOTO_SCRIPT/modelos"
local bikeTpl = nil
local BLUEL_C = Color3.fromRGB(150, 205, 255)
local function cachePath()
	return CACHE_DIR .. "/moto_" .. CACHE_VER .. "_s" .. tostring(S) .. "_g" .. tostring(Config.CheapGlass and 1 or 0)
		.. "_l" .. tostring(Config.LiteMode) .. "_b" .. Config.BodyColor:ToHex() .. "_a" .. Config.AccentColor:ToHex() .. ".rbxm"
end
local function tagK(o, k)
	if o then o:SetAttribute("K", k) end
end
local function tagBike(M)
	tagK(M.root, "root")
	tagK(M.wFork, "wFork")
	tagK(M.wSlider, "wSlider")
	tagK(M.wFWheel, "wFWheel")
	tagK(M.wSwing, "wSwing")
	tagK(M.wRWheel, "wRWheel")
	tagK(M.wRod, "wRod")
	tagK(M.rod, "rod")
	tagK(M.wSpring, "wSpring")
	tagK(M.spring, "spring")
	tagK(M.wMotor, "wMotor")
	tagK(M.spot, "spot")
	tagK(M.dashGear, "dG")
	tagK(M.dashSpeed, "dS")
	tagK(M.dashRev, "dV")
	tagK(M.dashRed, "dR")
	for i, p in ipairs(M.tails) do tagK(p, "tl:" .. i) end
	for i, p in ipairs(M.leds) do tagK(p, "ld:" .. i) end
	for i, p in ipairs(M.chain or {}) do tagK(p, "ch:" .. i) end
end
local function bindBike(model)
	local K = {}
	for _, d in ipairs(model:GetDescendants()) do
		local k = d:GetAttribute("K")
		if k then K[k] = d end
	end
	local root = model.PrimaryPart or K.root
	assert(root and K.wFork and K.wSlider and K.wFWheel and K.wSwing and K.wRWheel and K.wRod and K.rod
		and K.wSpring and K.spring and K.wMotor and K.spot and K.dG and K.dS and K.dV and K.dR)
	model.PrimaryPart = root
	local M = { model = model, root = root, leds = {}, tails = {}, chain = {} }
	M.wFork, M.wSlider, M.wFWheel = K.wFork, K.wSlider, K.wFWheel
	M.wSwing, M.wRWheel, M.wRod, M.rod = K.wSwing, K.wRWheel, K.wRod, K.rod
	M.wSpring, M.spring, M.wMotor, M.spot = K.wSpring, K.spring, K.wMotor, K.spot
	M.dashGear, M.dashSpeed, M.dashRev, M.dashRed = K.dG, K.dS, K.dV, K.dR
	M.rtireBase = CFrame.new(0, ARM_Y * S, ARM_Z * S)
	local function list(prefix, out)
		local i = 1
		while K[prefix .. i] do
			out[i] = K[prefix .. i]
			i = i + 1
		end
	end
	list("tl:", M.tails)
	list("ld:", M.leds)
	list("ch:", M.chain)
	M.tail = M.tails[1]
	M.chainCF = table.create(#M.chain, CFrame.new())
	local spot = M.spot
	M.setLight = function(on)
		spot.Enabled = on
		for _, led in ipairs(M.leds) do
			local onCol = (led.Name == "LEDInterno") and BLUEL_C or WHITE_LED
			led.Color = on and onCol or Color3.fromRGB(58, 64, 76)
			led.Material = on and NEON or SP
			led.Reflectance = on and 0 or 0.25
		end
	end
	M.setLight(false)
	model.Parent = workspace
	return M
end
local function loadDisk()
	if Config.CacheDisk == false then return nil end
	if not (isfile and readfile and getcustomasset) then return nil end
	local path = cachePath()
	local okF, has = pcall(isfile, path)
	if not (okF and has) then return nil end
	local ok, objs = pcall(function() return game:GetObjects(getcustomasset(path)) end)
	if ok and type(objs) == "table" and objs[1] and objs[1]:IsA("Model") then return objs[1] end
	if delfile then pcall(delfile, path) end
	return nil
end
local function saveDisk(m)
	if Config.CacheDisk == false then return end
	if not (saveinstance and isfile and writefile) then return end
	pcall(function()
		if makefolder and isfolder then
			if not isfolder("MOTO_SCRIPT") then makefolder("MOTO_SCRIPT") end
			if not isfolder(CACHE_DIR) then makefolder(CACHE_DIR) end
		end
	end)
	local path = cachePath()
	local okH, has = pcall(isfile, path)
	if okH and has then return end
	local base = string.gsub(path, "%.rbxm$", "")
	local attempts = {
		{ Object = m, FilePath = base, FileName = base, IsModel = true, Decompile = false, SaveBytecode = false, ShowStatus = false, mode = "optimized" },
		{ Object = m, FileName = path, IsModel = true, Decompile = false },
	}
	m.Parent = workspace
	for _, opt in ipairs(attempts) do
		pcall(saveinstance, opt)
		local ok, h = pcall(isfile, path)
		if ok and h then break end
	end
	m.Parent = nil
end

local function collectHandles(M)
	local fork = M.wFork and M.wFork.Part1
	if not fork then return end
	local H = { thr = {}, brk = {} }
	for _, d in ipairs(M.model:GetDescendants()) do
		if d:IsA("BasePart") then
			local w = d:FindFirstChildOfClass("Weld")
			if w and w.Part0 == fork and w.C0.Position.X > 0.5 * S then
				if d.Name == "Manopla" or d.Name == "ManoplaAnel" then
					H.thr[#H.thr + 1] = { w = w, c0 = w.C0 }
				elseif d.Name == "Manete" or d.Name == "ManeteJunta" or d.Name == "ManetePonta" then
					H.brk[#H.brk + 1] = { w = w, c0 = w.C0 }
				end
			end
		end
	end
	M.handles = H
	local PL = {}
	for _, d in ipairs(M.model:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == "PlacaChapa" or d.Name == "PlacaFace" or d.Name == "PlacaOrelha") then
			local w = d:FindFirstChildOfClass("Weld")
			if w and w.Part0 == M.root then PL[#PL + 1] = { w = w, c0 = w.C0 } end
		end
	end
	M.plate = PL
	M.platePivot = V3(0, 3.1, 4.78) * S
end

local function randomPlate()
	local L = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	local function l() local i = math.random(1, 26) return L:sub(i, i) end
	return l() .. l() .. l() .. math.random(0, 9) .. l() .. math.random(0, 9) .. math.random(0, 9)
end

local function setPlate(M)
	for _, d in ipairs(M.model:GetDescendants()) do
		if d:IsA("TextLabel") and d.Name == "PlacaNum" then d.Text = randomPlate() end
	end
end

local function buildBikeInner()
	if not bikeTpl then bikeTpl = loadDisk() end
	if bikeTpl then
		local ok, M = pcall(function() return bindBike(bikeTpl:Clone()) end)
		if ok and M then return M end
		bikeTpl = nil
		if delfile then pcall(delfile, cachePath()) end
	end
	local M = buildModel()
	pcall(tagBike, M)
	pcall(function() bikeTpl = M.model:Clone() end)
	if bikeTpl then
		local tpl = bikeTpl
		task.delay(4, function() pcall(saveDisk, tpl) end)
	end
	return M
end

local function buildBike()
	local M = buildBikeInner()
	pcall(collectHandles, M)
	pcall(setPlate, M)
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
		park = 0, parkE = 0, parkOn = false, parkT = 0, parkSide = -1, parkRoll = 0, parkSteer = 0, parkDrop = 0, parkLeanX = 0, pushing = false, pushT = 0, pushU = 0,
		kickE = 0, kickL = 0, kickLV = 0, kickRoll = 0, kickSteer = 0, kickIdle = 0,
		gear = 0, shiftT = 0, shiftCool = 0, skid = 0, lock = false, shiftPuff = false, shiftJolt = false, wheelP = 0, fx = nil,
	}
end

local Kick = {}
do
	function Kick.wrap(a)
		return (a + math.pi) % (2 * math.pi) - math.pi
	end

	function Kick.build(M)
		local KS = Config.Kickstand
		if not (KS and KS.Enabled) then return nil end
		local th = KS.Lean or 0.3
		local piv = KS.Pivot or V3(-1.0, 1.0, 0.6)
		local fx = piv.X - (KS.Out or 0.6)
		local F = V3(fx, -fx * tan(th), piv.Z - (KS.Forward or 0.2))
		local d1 = F - piv
		local L = d1.Magnitude
		if L < 0.2 then return nil end
		d1 = d1 / L
		local d0 = V3(0, 0.35, 1).Unit

		local function mk(name, size, shape, color, mat)
			local p = Instance.new("Part")
			p.Name = name
			p.Size = V3(size.X * S, size.Y * S, size.Z * S)
			p.Color = color
			p.Material = mat
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.CastShadow = false
			if shape then p.Shape = shape end
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Parent = M.model
			return p
		end
		local function wld(p1, c0)
			local w = Instance.new("Weld")
			w.Part0 = M.root
			w.Part1 = p1
			w.C0 = c0
			w.Parent = p1
			return w
		end
		local ks = { P = piv * S, L = L * S, d0 = d0, d1 = d1 }

		local hinge = mk("KickHinge", V3(0.26, 0.26, 0.26), Enum.PartType.Ball, CHROME, METAL)
		wld(hinge, CFrame.new(ks.P))
		local bx0 = -0.55
		local brk = mk("KickBracket", V3(math.abs(piv.X - bx0), 0.16, 0.16), CYL, DARK, METAL)
		wld(brk, CFrame.new(((piv.X + bx0) / 2) * S, piv.Y * S, piv.Z * S))

		local strut = mk("KickStrut", V3(L, 0.14, 0.14), CYL, DARK, METAL)
		ks.wStrut = wld(strut, CFrame.new(ks.P))
		local pad = mk("KickPad", V3(0.42, 0.07, 0.55), nil, BLACK, SP)
		ks.wPad = wld(pad, CFrame.new(ks.P))
		ks.rotStow = CFrame.lookAt(Vector3.zero, d0)
		ks.rotFlat = CFrame.Angles(0, 0, -th)
		ks.e = nil
		return ks
	end

	function Kick.pose(cc)
		local ks = cc.kick
		if not ks then return end
		local e = cc.kickE or 0
		if ks.e == e then return end
		ks.e = e
		local s = e * e * (3 - 2 * e)
		local dir = (ks.d0 * (1 - s) + ks.d1 * s).Unit
		local base = CFrame.lookAt(ks.P, ks.P + dir)
		ks.wStrut.C0 = base * CFrame.new(0, 0, -ks.L / 2) * CFrame.Angles(0, math.pi / 2, 0)
		ks.wPad.C0 = CFrame.new(ks.P + dir * ks.L) * ks.rotStow:Lerp(ks.rotFlat, s)
	end

	function Kick.eval(A, s)
		local cum, n = A.cum, A.n
		local i = 1
		while i < n and cum[i + 1] < s do i = i + 1 end
		local c0, c1 = cum[i], cum[i + 1]
		local f = (c1 > c0) and clamp((s - c0) / (c1 - c0), 0, 1) or 0
		local u = ((i - 1) + f) / n
		local iu = 1 - u
		local S0, C, E = A.S0, A.C, A.E
		local px = iu * iu * S0.X + 2 * iu * u * C.X + u * u * E.X
		local pz = iu * iu * S0.Z + 2 * iu * u * C.Z + u * u * E.Z
		local tx = 2 * iu * (C.X - S0.X) + 2 * u * (E.X - C.X)
		local tz = 2 * iu * (C.Z - S0.Z) + 2 * u * (E.Z - C.Z)
		local m = math.sqrt(tx * tx + tz * tz)
		if m < 1e-6 then tx, tz = A.fx, A.fz else tx, tz = tx / m, tz / m end
		return px, pz, tx, tz
	end

	function Kick.finish(cc)
		local A = cc.arrive
		if A and A.hl then pcall(function() A.hl:Destroy() end) end
		cc.arrive = nil
		cc.kickIdle = 99
		pcall(function() cc.M.setLight(cc.headOn == true) end)
	end

	function Kick.startArrive(cc, E, yaw)
		local AC = Config.Arrive
		local fx, fz = -sin(yaw), -cos(yaw)
		local rx, rz = cos(yaw), -sin(yaw)
		local D = AC.Distance or 80
		local side = (math.random() < 0.5 and -1 or 1) * (AC.Side or 20)
		local S0 = V3(E.X - fx * D + rx * side, 0, E.Z - fz * D + rz * side)
		local C = V3(E.X - fx * D * 0.5, 0, E.Z - fz * D * 0.5)
		local Ef = V3(E.X, 0, E.Z)
		local A = {
			S0 = S0, C = C, E = Ef, fx = fx, fz = fz, yawEnd = yaw,
			phase = "drive", t = 0, s = 0, v = (AC.Speed or 55) * 0.6, thr = 1, brk = 0, steer = 0,
		}

		local n = 48
		local cum = { 0 }
		local px, pz = S0.X, S0.Z
		for k = 1, n do
			local u = k / n
			local iu = 1 - u
			local x = iu * iu * S0.X + 2 * iu * u * C.X + u * u * Ef.X
			local z = iu * iu * S0.Z + 2 * iu * u * C.Z + u * u * Ef.Z
			cum[k + 1] = cum[k] + math.sqrt((x - px) * (x - px) + (z - pz) * (z - pz))
			px, pz = x, z
		end
		A.cum, A.n, A.len = cum, n, cum[n + 1]

		local gy = E.Y
		local res = workspace:Raycast(V3(S0.X, E.Y + 50, S0.Z), V3(0, -160, 0), rp)
		if res then gy = res.Position.Y end
		local _, _, tx, tz = Kick.eval(A, 0)
		cc.pos = V3(S0.X, gy, S0.Z)
		cc.lastSafe = cc.pos
		cc.yaw = atan2(-tx, -tz)
		cc.vel = V3(tx * A.v, 0, tz * A.v)
		cc.vF = A.v
		cc.prevVF = A.v

		pcall(function()
			local hl = Instance.new("Highlight")
			hl.Name = "MotoArriveHL"
			hl.FillColor = Color3.new(1, 1, 1)
			hl.OutlineColor = Color3.new(1, 1, 1)
			hl.FillTransparency = 0.2
			hl.OutlineTransparency = 0
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.Adornee = cc.model
			hl.Parent = cc.model
			A.hl = hl
		end)
		cc.headOn = false
		pcall(function() cc.M.setLight(false) end)
		cc.arrive = A
	end

	function Kick.autoStep(cc, dt)
		local A = cc.arrive
		if not A then return end
		if cc.driver then Kick.finish(cc) return end
		local AC = Config.Arrive
		A.t = A.t + dt
		if A.hl then
			local k = clamp(A.t / (AC.FadeIn or 0.5), 0, 1)
			if k >= 1 then
				pcall(function() A.hl:Destroy() end)
				A.hl = nil
			else
				A.hl.FillTransparency = 0.2 + 0.8 * k
				A.hl.OutlineTransparency = k
			end
		end
		if A.phase == "drive" then
			local vMax = AC.Speed or 55
			local dec = AC.Decel or 32
			local d = A.len - A.s
			local vT = math.min(vMax, math.sqrt(2 * dec * math.max(d, 0)) + 1.5)
			A.v = A.v + clamp(vT - A.v, -dec * 1.8 * dt, (AC.Accel or 60) * dt)
			local px, pz, tx, tz = Kick.eval(A, A.s)
			local psi = atan2(-tx, -tz)

			local la = math.max(A.v * dt * 4, 0.6)
			local _, _, tx2, tz2 = Kick.eval(A, math.min(A.s + la, A.len))
			local yawRate = Kick.wrap(atan2(-tx2, -tz2) - psi) * A.v / la
			local rate = Config.TurnRate / (1 + A.v / Config.TurnSpeedRef)
			A.steer = clamp(-yawRate / (rate * clamp(A.v / 5, 0.05, 1)), -1, 1)
			A.thr = clamp((vT - A.v) / 8, 0, 1)
			A.brk = (vT < vMax - 2) and 1 or 0
			cc.pos = V3(px, cc.pos.Y, pz)
			cc.yaw = psi
			cc.vel = V3(tx * A.v, 0, tz * A.v)
			cc.vF = A.v
			A.s = A.s + A.v * dt
			local rem = A.len - A.s
			if rem <= 0.05 or (A.v < 2 and rem < 1.5) then
				A.phase = "stand"
				A.v, A.thr, A.brk, A.steer = 0, 0, 0, 0
				A.settle, A.t2 = 0, 0
			end
		else
			cc.pos = V3(A.E.X, cc.pos.Y, A.E.Z)
			cc.yaw = A.yawEnd
			cc.vel = V3(0, 0, 0)
			cc.vF = 0
			A.t2 = (A.t2 or 0) + dt
			local KS = Config.Kickstand
			if KS and KS.Enabled then
				if cc.kickE >= 0.99 and cc.kickL >= 0.97 and math.abs(cc.kickLV) < 0.35 then
					A.settle = A.settle + dt
				else
					A.settle = 0
				end
				if A.settle > 0.25 or A.t2 > 3 then Kick.finish(cc) end
			else
				if A.t2 > 0.3 then Kick.finish(cc) end
			end
		end
	end

	function Kick.step(cc, dt)
		local KS = Config.Kickstand
		if not (KS and KS.Enabled) then
			cc.kickE, cc.kickL, cc.kickLV, cc.kickRoll, cc.kickSteer = 0, 0, 0, 0, 0
			return
		end
		local want
		if cc.driver and cc.dis and cc.dis.kick then
			cc.kickIdle = 0
			want = true
		elseif cc.driver then
			cc.kickIdle = 0
			want = false
		elseif cc.arrive then
			want = (cc.arrive.phase == "stand")
		elseif cc.grounded and math.abs(cc.vF) < (KS.StopSpeed or 1.5) then
			cc.kickIdle = (cc.kickIdle or 0) + dt
			want = cc.kickIdle >= (KS.IdleDelay or 0.6)
		else
			cc.kickIdle = 0
			want = false
		end
		local e, L, lv = cc.kickE, cc.kickL, cc.kickLV
		local eT, lT
		if want then
			eT = 1
			lT = (e >= 0.97) and 1 or 0
		else
			lT = 0
			if cc.driver then eT = 0 else eT = (L < 0.08) and 0 or 1 end
		end
		local rOut = 1 / math.max(KS.Time or 0.45, 0.05)
		local rIn = 1 / math.max(KS.RetractTime or 0.35, 0.05)
		e = clamp(e + clamp(eT - e, -rIn * dt, rOut * dt), 0, 1)
		lv = lv + ((KS.SpringK or 55) * (lT - L) - (KS.SpringC or 9) * lv) * dt
		L = clamp(L + lv * dt, -0.1, 1.3)
		if lT == 0 and math.abs(L) < 0.004 and math.abs(lv) < 0.02 then L, lv = 0, 0 end
		cc.kickE, cc.kickL, cc.kickLV = e, L, lv
		cc.kickRoll = (KS.Lean or 0.3) * L
		cc.kickSteer = (KS.Steer or 0.5) * L
	end
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

local mountBlock = 0

local function mountBike()
	if not c or c.driver or c.anim then return end
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
	hum.AutoRotate = false
	c.driver = true
	c.mountT = os.clock()
end

local function dismountBike(noTeleport)
	if not c or not c.driver then return end
	c.driver = false
	c.dis = nil
	c.disLeg, c.disStep, c.disOver, c.disArmR, c.disArmL = 0, 0, 0, 0, 0
	c.disLean, c.disTwist, c.disHeadYaw, c.disHeadPitch, c.disKickFoot = 0, 0, 0, 0, 0
	mountBlock = os.clock() + 0.8
	pcall(releaseArms)
	releaseChar(not noTeleport)
end

local function autoMount()
	if not c or c.driver or os.clock() < mountBlock then return end
	local ch, hum, rpart = charParts()
	if not ch then return end
	local sitting = hum.Sit or hum:GetState() == Enum.HumanoidStateType.Seated
	if sitting and hum.SeatPart == nil
		and (rpart.Position - c.pos).Magnitude < Config.MountRadius * S
		and math.abs(c.vF) < 12 then
		mountBike()
	end
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
		snd = 0,
	}
	if imp > 35 and os.clock() - (cc.lastLandSnd or 0) > 0.4 then
		cc.lastLandSnd = os.clock()
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
		cc.dis = nil
		saved = nil
	end
	if cc.lastChar ~= player.Character then
		cc.lastChar = player.Character
		rp.FilterDescendantsInstances = { cc.model, player.Character }
	end
	Kick.autoStep(cc, dt)
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
	if driving and cc.dis then
		throttle, steerIn = 0, 0
		if cc.dis.phase == "stop" then
			brakeIn = 1
			cc.stopOnly = true
		else
			brakeIn = 0
		end
	end
	if cc.arrive and not driving then
		local A = cc.arrive
		throttle, brakeIn, steerIn = A.thr or 0, A.brk or 0, A.steer or 0
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

	local slip, gripK, skid = 0, 1, 0
	if driving and grounded then
		local locked = cc.stopOnly and vF > Config.SkidMinSpeed
		if locked then
			skid = clamp((vF - Config.SkidMinSpeed) / 80, 0.35, 1)
			if math.abs(cc.steer) > 0.3 then
				slip = Config.SkidSlip * math.abs(cc.steer)
				gripK = Config.SkidGrip
			end
		elseif Config.DriftCurve and throttle > 0.5 and vF > top * 0.6 and math.abs(cc.steer) > 0.6 then
			slip = Config.DriftSlip * math.abs(cc.steer)
			gripK = Config.DriftGrip
			skid = 0.5
		end
	end
	cc.lock = (driving and grounded and cc.stopOnly and vF > Config.SkidMinSpeed) and true or false
	cc.skid = skid

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

	if cc.shiftT > 0 then cc.shiftT = math.max(cc.shiftT - dt, 0) end
	if cc.shiftCool > 0 then cc.shiftCool = math.max(cc.shiftCool - dt, 0) end
	if driving and grounded then
		local spdK = math.abs(vF) * Config.SpeedMul
		local stepK = Config.TopSpeed / 6
		local gN = spdK < 1 and 0 or clamp(math.floor(spdK / stepK) + 1, 1, 6)
		if gN > cc.gear then
			if cc.gear >= 1 and throttle > 0 and cc.shiftT <= 0 and cc.shiftCool <= 0 then
				cc.shiftT = Config.ShiftTime
				cc.shiftCool = Config.ShiftCooldown
				cc.shiftJolt = true
				cc.shiftPuff = true
				cc.rkPV = cc.rkPV - 0.3
			end
			cc.gear = gN
		elseif gN < cc.gear and (gN == 0 or spdK < (cc.gear - 1) * stepK - math.max(8, stepK * 0.3)) then
			cc.gear = gN
		end
	elseif not driving then
		cc.gear = 0
	end
	if cc.shiftT > 0 then acc = acc * (1 - cc.shiftT / Config.ShiftTime) end
	local resist = 2.5 + 0.00015 * vF * vF
	if throttle == 0 then resist = resist + 6 end
	if not driving then resist = resist + 8 end
	if not grounded then resist = 0.00015 * vF * vF end
	local sgn = vF >= 0 and 1 or -1
	local dec = math.min(resist * dt, math.abs(vF))
	vF = vF + acc * dt - sgn * dec
	if cc.shiftJolt then
		cc.shiftJolt = false
		vF = vF * (1 - Config.ShiftJolt)
	end

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
		vR = vR * exp(-Config.Grip * gripK * dt)
	end

	local sp = math.abs(vF)
	local rate = Config.TurnRate / (1 + sp / Config.TurnSpeedRef)
	local yawRate = -cc.steer * rate * clamp(sp / 5, 0, 1) * (vF >= 0 and 1 or -1)
	if not grounded then yawRate = yawRate * 0.1 end
	yaw = yaw + yawRate * dt
	if slip > 0 then vR = vR + vF * sin(yawRate * dt) * slip end
	fwd = V3(-sin(yaw), 0, -cos(yaw))
	right = V3(cos(yaw), 0, -sin(yaw))
	vel = fwd * vF + right * vR

	local hsp = math.sqrt(vF * vF + vR * vR)
	if hsp > 1 then
		local dir = vel.Unit
		local o = cc.pos + V3(0, 1.4 * S, 0)
		local hit = workspace:Raycast(o, dir * (hsp * dt + (vF >= 0 and 3.4 or 3.6) * S), rp)
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

	local WHF = -FCEN.Z * S
	local WHR = RCEN.Z * S
	local oy = cc.pos.Y + 3 * S
	local hF = gRay(posN + fwd * WHF, oy)
	local hR = gRay(posN - fwd * WHR, oy)
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
		tY = (yF * WHR + yR * WHF) / (WHF + WHR)
		gP = clamp(atan2(yF - yR, WHF + WHR), -1.1, 1.1)
		gR = clamp(atan(-(nrm:Dot(right)) / math.max(nrm.Y, 0.2)), -0.8, 0.8)
		local tanP = tan(clamp(cc.aP + cc.rkP, -1.2, 1.2))
		local bodyY = cc.pos.Y + cc.susY
		cc.relF = yF - (bodyY + tanP * WHF)
		cc.relR = yR - (bodyY - tanP * WHR)
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

	if Config.FallRescue and y < workspace.FallenPartsDestroyHeight + 40 then
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

	do
		local AA = Config.AccelAnim
		local aT = 0
		if AA and AA.Enabled ~= false and grounded and not cc.dis and (cc.wheelP or 0) < 0.05 then
			aT = clamp(cc.accS / (AA.AccRef or 30), -1, 1)
			if cc.brakeIn > 0.1 and cc.vF > 3 then aT = math.min(aT, -cc.brakeIn * clamp(cc.vF / 25, 0.2, 1)) end
			if cc.throttle > 0.1 and cc.vF > -1 then
				aT = math.max(aT, cc.throttle * 0.7 * (1 - clamp(cc.vF / math.max(top, 1), 0, 0.85)))
			end
		end
		local rate = (AA and AA.Rate) or 7
		cc.aniAcc = (cc.aniAcc or 0) + (aT - (cc.aniAcc or 0)) * (1 - exp(-rate * dt))
	end
	local latA = cc.vF * yawRate
	local tr = grounded and clamp(atan(latA / g) * 1.3, -Config.MaxLean, Config.MaxLean) or 0
	cc.leanP = cc.leanP + (tp - cc.leanP) * (1 - exp(-8 * dt))
	cc.leanR = cc.leanR + (tr - cc.leanR) * (1 - exp(-7 * dt))
	local wT = (driving and grounded and held.wheelUi and cc.vF > Config.WheelieMinSpeed) and Config.WheelieMax or 0
	cc.wheelP = cc.wheelP + (wT - cc.wheelP) * (1 - exp(-(wT > cc.wheelP and 3.2 or 2.2) * dt))

	do
		local PK = Config.Park or {}
		local pushTime = PK.PushTime or 0.35
		if PK.Enabled and driving and cc.dis then

			cc.pushing = false
			cc.pushU = 0
			cc.parkT = 0
			cc.parkOn = (cc.dis.want == true)
		elseif PK.Enabled and driving then
			local spdA = math.abs(cc.vF)
			if cc.pushing then

				cc.pushT = cc.pushT + dt
				cc.pushU = clamp(cc.pushT / math.max(pushTime, 0.05), 0, 1)
				if (not grounded) or cc.pushT >= pushTime then cc.pushing = false end
			elseif cc.parkOn then
				if (not grounded) or cc.wheelP > 0.05 then
					cc.parkOn = false
					cc.parkT = 0
				elseif throttle > 0.05 or spdA > (PK.LeaveSpeed or 4) then
					cc.parkOn = false
					cc.parkT = 0
					if cc.park > 0.8 and pushTime > 0 then
						cc.pushing = true
						cc.pushT = 0
						cc.pushU = 0

						local kick = PK.PushKick or 4
						if throttle > 0.05 and kick ~= 0 and spdA < 8 then cc.vel = cc.vel + fwd * kick end
					end
				end
			elseif grounded and throttle <= 0.05 and spdA < (PK.StopSpeed or 1.5) and cc.wheelP < 0.02 then
				cc.parkT = cc.parkT + dt
				if cc.parkT >= (PK.Delay or 0.35) then
					cc.parkOn = true
					cc.pushU = 0

					if cc.park < 0.05 then cc.parkSide = (math.random() < 0.5) and -1 or 1 end
				end
			else
				cc.parkT = 0
			end
		else
			cc.parkOn = false
			cc.parkT = 0
			cc.pushing = false
			cc.pushU = 0
		end
		if not driving then
			cc.park = 0
		else
			local pT = (cc.parkOn or cc.pushing) and 1 or 0
			local pRate = (pT == 1) and (1 / math.max(PK.Time or 0.55, 0.1)) or (1 / math.max(PK.RetractTime or 0.35, 0.1))
			if cc.dis then pRate = 1 / math.max((Config.Dismount and Config.Dismount.PlantTime) or 0.35, 0.1) end
			cc.park = clamp(cc.park + clamp(pT - cc.park, -pRate * dt, pRate * dt), 0, 1)
		end
		local pk = cc.park
		local pE = pk * pk * (3 - 2 * pk)
		cc.parkE = pE

		local pu = cc.pushU or 0
		local lW = pE * (1 - (PK.PushUpright or 0.6) * pu * pu * (3 - 2 * pu))
		local sd = cc.parkSide or -1

		local parkLean = (PK.Lean or 0.45) + (cc.parkLeanX or 0)
		if cc.dis then

			local KSl = (Config.Kickstand and Config.Kickstand.Lean) or 0.3
			parkLean = parkLean + (KSl - parkLean) * clamp(cc.dis.kb or 0, 0, 1)
			lW = lW * (1 - clamp(cc.kickL or 0, 0, 1))
		end
		cc.parkRoll = -sd * parkLean * lW
		cc.parkSteer = -sd * (PK.Steer or 0.7) * lW
		if pE <= 0 then cc.parkDrop = 0; cc.parkLeanX = 0 end
	end

	do
		local WV = Config.WheelieVariant
		local act = driving and wT > 0
		if act and not cc._wAct then
			local mode = WV and WV.Mode or "random"
			if mode == "off" then cc.wheelVar = 0
			elseif mode == "v1" then cc.wheelVar = 1
			elseif mode == "v2" then cc.wheelVar = 2
			else cc.wheelVar = (math.random() < 0.5) and 1 or 2 end
			cc.pullKick = 1
		end
		cc._wAct = act
		cc.pullKick = math.max((cc.pullKick or 0) - dt * 3.5, 0)
		local pt = (driving and cc.wheelVar == 1 and wT > 0) and 1 or 0
		local pl = cc.pull or 0
		pl = pl + (pt - pl) * (1 - exp(-(pt > pl and 9 or 3) * dt))
		cc.pull = pl
		if driving and cc.wheelVar == 1 then
			cc.pullAmt = clamp(pl * 0.7 + cc.pullKick * 0.45, 0, 1)
		else
			cc.pullAmt = 0
		end
	end

	do
		local WS = Config.WheelieStand
		if WS and WS.Enabled and driving and cc.wheelVar == 2 then
			local frac = cc.wheelP / math.max(Config.WheelieMax, 0.01)
			if not cc.standOn and frac >= (WS.StartAt or 0.65) then cc.standOn = true
			elseif cc.standOn and frac <= (WS.EndAt or 0.3) then cc.standOn = false end
			local st = cc.stand or 0
			local step = dt / math.max(WS.Time or 1.6, 0.2)
			cc.stand = clamp(st + clamp((cc.standOn and 1 or 0) - st, -step, step), 0, 1)
		else
			cc.standOn = false
			cc.stand = 0
		end
	end

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
		local accR = cc.accS * S2.AccelTransfer
		local AA = Config.AccelAnim
		if AA and AA.Enabled ~= false then
			local a = cc.aniAcc or 0
			tF = tF - a * (AA.FrontDive or 0.28) * S
			accR = accR + a * (AA.RearSquat or 0.1) * S
		end
		-- limita o afundamento da traseira por aceleracao p/ a roda nao encostar na rabeta/banco
		accR = math.min(accR, (S2.SquatMax or 0.06) * S)
		tR = clamp(cc.relR, -S2.ExtendR * S, S2.TravelR * S * 1.3) + accR
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
		* CFrame.Angles(cc.leanP + cc.rkP + (function()
			local AA, a = Config.AccelAnim, cc.aniAcc or 0
			if not (AA and AA.Enabled ~= false) then return 0 end
			return a * ((a > 0) and (AA.AccelPitch or 0.025) or (AA.BrakePitch or 0.045))
		end)(), 0, cc.leanR + cc.rkR + (cc.parkRoll or 0) + (cc.kickRoll or 0))
	local wp = cc.wheelP or 0
	if wp > 0.001 then
		local pv = V3(0, 0, RCEN.Z * S)
		cf = cf * CFrame.new(pv) * CFrame.Angles(wp, 0, 0) * CFrame.new(-pv)
	end
	cc.cf = cf
	M.root.CFrame = cf

	cc.spinF = (cc.spinF - cc.vF * dt / (R * S)) % (math.pi * 2)
	cc.spinR = (cc.spinR - (cc.lock and 0 or (cc.vF * dt / (R * S)))) % (math.pi * 2)
	M.wFWheel.C0 = CFrame.Angles(cc.spinF, 0, 0)

	local steerAng = -(cc.steer + (cc.parkSteer or 0) + (cc.kickSteer or 0)) * Config.ForkSteer * (1 - clamp(math.abs(cc.vF) / 150, 0, 0.6))
	M.wFork.C0 = CFrame.new(HEAD.X * S, HEAD.Y * S, HEAD.Z * S) * CFrame.Angles(RAKE, 0, 0) * CFrame.Angles(0, steerAng, 0)
	M.wSlider.C0 = CFrame.new(0, -(FL * S - cc.fT), 0)

	do
		local Hh, AA = M.handles, Config.AccelAnim
		if Hh and AA and AA.Enabled ~= false then
			local active = (cc.driver or cc.arrive ~= nil) and not cc.dis
			local thT = active and (cc.throttle or 0) or 0
			local brT = active and (cc.brakeIn or 0) or 0
			local kk = 1 - exp(-12 * dt)
			cc.thrW = (cc.thrW or 0) + (thT - (cc.thrW or 0)) * kk
			cc.levW = (cc.levW or 0) + (brT - (cc.levW or 0)) * kk
			if math.abs(cc.thrW - (cc._thrA or -1)) > 0.002 then
				cc._thrA = cc.thrW
				local pv = V3(1.38, 0.5, 0.56) * S
				local ax = V3(0.42, 0.07, 0.17).Unit
				local rot = CFrame.new(pv) * CFrame.fromAxisAngle(ax, cc.thrW * (AA.ThrottleRoll or 0.65)) * CFrame.new(-pv)
				for _, r in ipairs(Hh.thr) do if r.w.Parent then r.w.C0 = rot * r.c0 end end
			end
			if math.abs(cc.levW - (cc._levA or -1)) > 0.002 then
				cc._levA = cc.levW
				local pv = V3(1.15, 0.4, 0.34):Lerp(V3(1.38, 0.5, 0.56), 0.85) * S
				local rot = CFrame.new(pv) * CFrame.Angles(0, -cc.levW * (AA.LeverPull or 0.4), 0) * CFrame.new(-pv)
				for _, r in ipairs(Hh.brk) do if r.w.Parent then r.w.C0 = rot * r.c0 end end
			end
		end
	end

	local th = -cc.rT / (ARM_Z * S)
	local rotS = CFrame.Angles(th, 0, 0)
	M.wSwing.C0 = CFrame.new(PIV.X * S, PIV.Y * S, PIV.Z * S) * rotS
	M.wRWheel.C0 = M.rtireBase * CFrame.Angles(cc.spinR, 0, 0)
	updateChain(cc, M, dt, rotS, th)

	if cc._shTh == nil or math.abs(th - cc._shTh) > 0.0015 then
		cc._shTh = th
		local aW = SHOCK_A * S
		local bW = (PIV + rotS:VectorToWorldSpace(SHOCK_B)) * S
		local len = math.max((bW - aW).Magnitude, 0.2)
		local dir = (bW - aW) / len
		M.rod.Size = V3(len * 0.9, 0.3 * S, 0.3 * S)
		M.wRod.C0 = CFrame.lookAt((aW + bW) / 2, bW) * CFrame.Angles(0, math.pi / 2, 0)
		M.spring.Size = V3(len * 0.55, 0.46 * S, 0.46 * S)
		M.wSpring.C0 = CFrame.lookAt(aW + dir * len * 0.3, bW) * CFrame.Angles(0, math.pi / 2, 0)
	end

	local braking = cc.brakeIn > 0 and (cc.driver or cc.arrive ~= nil)
	if cc._brk ~= braking then
		cc._brk = braking
		local tcol = braking and RED_HI or RED_DIM
		for _, tp in ipairs(M.tails) do tp.Color = tcol end
	end

	do
		local PL = M.plate
		if PL and #PL > 0 then
			local st = cc.plt
			if not st then
				st = { p = 0, pv = 0, z = 0, zv = 0 }
				cc.plt = st
			end
			local AAx = Config.AccelAnim
			local an = cc.aniAcc or 0
			local aniP = 0
			if AAx and AAx.Enabled ~= false then
				aniP = an * ((an > 0) and (AAx.AccelPitch or 0.025) or (AAx.BrakePitch or 0.045))
			end
			local g = workspace.Gravity
			local sk = clamp(cc.vF / Config.TopSpeed, 0, 1)
			local pitchT = cc.leanP + cc.rkP + aniP + (cc.wheelP or 0)
			local rollT = cc.leanR + cc.rkR + (cc.parkRoll or 0) + (cc.kickRoll or 0)
			local latA = cc.vF * (cc.yawRate or 0)
			local tP = pitchT + clamp(cc.accS / g, -0.5, 0.5) * 1.6 + (sk ^ 1.4) * 0.9
			local tZ = clamp(math.atan(latA / g) - rollT, -0.45, 0.45)
			if not cc.grounded then tP = tP * 0.4 end
			local dtp = math.min(dt, 0.05)
			local steps = dtp > 0.012 and 2 or 1
			local h = dtp / steps
			for _ = 1, steps do
				st.pv = st.pv + (-121 * (st.p - tP) - 4.2 * st.pv + cc.rV * 0.6) * h
				st.p = st.p + st.pv * h
				if st.p < -0.35 then
					st.p = -0.35
					if st.pv < 0 then st.pv = -st.pv * 0.3 end
				elseif st.p > 1.3 then
					st.p = 1.3
					if st.pv > 0 then st.pv = -st.pv * 0.3 end
				end
				st.zv = st.zv + (-150 * (st.z - tZ) - 5 * st.zv) * h
				st.z = st.z + st.zv * h
			end
			local fl = (cc.grounded and sk > 0.15) and math.sin(os.clock() * 55) * 0.03 * sk * sk or 0
			local pv = M.platePivot
			local rot = CFrame.new(pv) * CFrame.Angles(-(st.p + fl), 0, st.z) * CFrame.new(-pv)
			for _, r in ipairs(PL) do
				if r.w.Parent then r.w.C0 = rot * r.c0 end
			end
		end
	end

	cc.seatCF = cf * CFrame.new(0, SEAT_TOP * S + Config.SitRise, Config.SeatZ * S) * CFrame.Angles(Config.SitPitch, 0, 0)
	Kick.pose(cc)
end

local ARMS = { on = false, w = 0, lean = 0, twist = 0, J = nil, waist = nil, ang = {}, brakeW = 0 }
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
local LEGIK = { ch = nil, R = nil, L = nil, joints = {} }
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
	for _, m in ipairs(LEGIK.joints) do
		if m.Parent then m.Transform = CFrame.new() end
	end
	LEGIK.ch, LEGIK.R, LEGIK.L, LEGIK.joints = nil, nil, nil, {}
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
	if ARMS.lean > 0 or math.abs(ARMS.twist or 0) > 0 then
		ARMS.lean = 0
		ARMS.twist = 0
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

local GRIP_LOCAL = {
	right = V3(1.64, 0.54, 0.68),
	left  = V3(-1.64, 0.54, 0.68),
}

local FOOT_LOCAL = {
	right = V3(1.05, 1.05, 1.7),
	left  = V3(-1.05, 1.05, 1.7),
}

local function sm01(x) x = clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local SEAT_TOPY = { { 0.3, 3.18 }, { 0.9, 3.04 }, { 1.4, 2.94 }, { 1.9, 2.95 }, { 2.3, 2.98 } }
local function seatSurfY(z)
	z = clamp(z, SEAT_TOPY[1][1], SEAT_TOPY[#SEAT_TOPY][1])
	for i = 1, #SEAT_TOPY - 1 do
		local a, b = SEAT_TOPY[i], SEAT_TOPY[i + 1]
		if z <= b[1] then
			return a[2] + (b[2] - a[2]) * ((z - a[1]) / (b[1] - a[1]))
		end
	end
	return SEAT_TOPY[#SEAT_TOPY][2]
end
local function riderBase(cc)
	local base = cc.seatCF

	local WV = Config.WheelieVariant
	local pa = cc.pullAmt or 0
	if WV and pa > 0.001 then
		base = base * CFrame.new(0, (WV.PullUp or 0.25) * S * pa, (WV.PullBack or 0.45) * S * pa)
			* CFrame.Angles((WV.PullTilt or 0.18) * pa, 0, 0)
	end
	local WS = Config.WheelieStand
	local s = (WS and WS.Enabled) and (cc.stand or 0) or 0
	if s > 0.001 and cc.M and cc.M.root then
		local e = sm01((s - 0.45) / 0.55)
		local rise = (cc.standRise or 0) * e
		local rootCF = cc.M.root.CFrame
		base = base + rootCF.UpVector * rise
		local counter = (cc.wheelP or 0) * (WS.Upright or 0.6) * e
		if counter > 0.001 then
			local pivot = rootCF * CFrame.new(0, SEAT_TOP * S + rise, 1.4 * S)
			base = pivot * CFrame.Angles(-counter, 0, 0) * pivot:Inverse() * base
		end
	end

	local pe = cc.parkE or 0
	if pe > 0.001 then
		local PK = Config.Park or {}
		base = base + base.RightVector * ((PK.Shift or 0.2) * S * pe * (cc.parkSide or -1))
			- V3(0, (cc.parkDrop or 0) * pe, 0)
	end

	local DD = cc.dis
	if DD then
		local ov = cc.disOver or 0
		do
			local fwS = math.sin(math.pi * clamp(cc.disLeg or 0, 0, 1))
			if fwS > 0.001 then
				local DMf = Config.Dismount or {}
				base = base + base.LookVector * ((DMf.ForwardShift or 0.5) * S * fwS)
			end
		end
		if ov > 0.001 then
			local DM = Config.Dismount or {}
			base = base - base.RightVector * ((DM.OverX or 0.8) * S * ov)
			local upr = CFrame.new(base.Position) * CFrame.Angles(0, cc.yaw, 0)
			base = base:Lerp(upr, sm01((ov - 0.3) / 0.7))
		end
		if DD.freeze then base = DD.freeze end
	end
	return base
end

local ARM_TOP = { { 0, 0.48 }, { 0.9, 0.38 }, { 1.8, 0.24 }, { ARM_Z, 0.13 } }
local function armTopY(z)
	z = clamp(z, 0, ARM_Z)
	for i = 1, #ARM_TOP - 1 do
		local a, b = ARM_TOP[i], ARM_TOP[i + 1]
		if z <= b[1] then
			return a[2] + (b[2] - a[2]) * ((z - a[1]) / math.max(b[1] - a[1], 1e-4))
		end
	end
	return ARM_TOP[#ARM_TOP][2]
end

local function findAnkle(ch, footName)
	for _, d in ipairs(ch:GetDescendants()) do
		if isJoint(d) and d.Part0 and d.Part1 and d.Part1.Name == footName then return d end
	end
	return nil
end

local function prepLegIK(ch)
	local FR = Config.FootRest
	if not (FR and FR.Enabled) then return nil end
	if LEGIK.ch ~= ch or not LEGIK.R then
		LEGIK.ch, LEGIK.R, LEGIK.L, LEGIK.joints = ch, nil, nil, {}
		local J = LIMB.J
		if not J then return nil end
		local function build(hip, knee, footName)
			if not (hip and knee) then return nil end
			local ankle = findAnkle(ch, footName)
			if not ankle then return nil end
			local k = armChain({ shoulder = hip, elbow = knee, hand = ankle })
			if not (k and k.elbow and k.L2) then return nil end
			k.ankle = ankle
			LEGIK.joints[#LEGIK.joints + 1] = hip
			LEGIK.joints[#LEGIK.joints + 1] = knee
			LEGIK.joints[#LEGIK.joints + 1] = ankle
			return k
		end
		LEGIK.R = build(J.rh, J.rk, "RightFoot")
		LEGIK.L = build(J.lh, J.lk, "LeftFoot")
		if not (LEGIK.R and LEGIK.L) then
			LEGIK.R, LEGIK.L = nil, nil
			LEGIK.joints = {}
		end
	end
	if LEGIK.R and LEGIK.L and LEGIK.R.sh.Parent and LEGIK.L.sh.Parent then return LEGIK end
	return nil
end

local function solveLeg(k, p0n, tgt, sgn, bodyRight, bodyUp, bodyFront, ez, footRotW, kneeOut)
	local hip, knee, ankle = k.sh, k.elbow, k.ankle
	local P = p0n * hip.C0.Position
	local toT = tgt - P
	local dist = toT.Magnitude
	if dist < 0.05 then return end
	local dirT = toT / dist
	local L1, L2 = k.L1, k.L2
	local d = math.min(dist, (L1 + L2) * 0.999)
	local a = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
	local h = math.sqrt(math.max(L1 * L1 - a * a, 0))

	local pole = bodyFront + bodyRight * (kneeOut * sgn) + bodyUp * 0.1
	pole = pole - dirT * pole:Dot(dirT)
	pole = pole.Magnitude > 1e-3 and pole.Unit or bodyFront
	local E = P + dirT * a + pole * h
	local uW = (E - P).Unit
	local lv = (P + dirT * d) - E
	local lW = lv.Magnitude > 1e-3 and lv.Unit or uW

	local Ru = armRotFromTo(k.d0, p0n:VectorToObjectSpace(uW))
	local CF1 = CFrame.new(hip.C0.Position) * Ru * k.rrSh * CFrame.new(-hip.C1.Position)
	hip.Transform = hip.Transform:Lerp(hip.C0:Inverse() * CF1 * hip.C1, ez)

	local upperCF = p0n * CF1
	local R2 = armRotFromTo(k.d2, upperCF:VectorToObjectSpace(lW))
	local CF2 = CFrame.new(knee.C0.Position) * R2 * k.rrEl * CFrame.new(-knee.C1.Position)
	knee.Transform = CFrame.new():Lerp(knee.C0:Inverse() * CF2 * knee.C1, ez)

	if ankle and ankle.Parent and footRotW then
		local lowerCF = upperCF * CF2
		local function rot(cf) return cf - cf.Position end
		local T = rot(ankle.C0):Inverse() * rot(lowerCF):Inverse() * footRotW * rot(ankle.C1)
		ankle.Transform = CFrame.new():Lerp(T, ez)
	end
end

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

	local seatW = riderBase(cc)
	local rootInv = rpart.CFrame:Inverse()
	local function pw(part) return seatW * (rootInv * part.CFrame) end
	local bodyRight, bodyUp, bodyBack = seatW.RightVector, seatW.UpVector, -seatW.LookVector

	local M = cc.M
	local forkCF = M.root.CFrame * M.wFork.C0

	local grips = {
		right = (forkCF * CFrame.new(GRIP_LOCAL.right * S)).Position,
		left  = (forkCF * CFrame.new(GRIP_LOCAL.left * S)).Position,
	}

	local wantBrake = ((cc.brakeIn or 0) > 0.15 and not cc.dis) and 1 or 0
	ARMS.brakeW = ARMS.brakeW + (wantBrake - ARMS.brakeW) * math.min(1, dt * 8)
	local bw = ARMS.brakeW * ARMS.brakeW * (3 - 2 * ARMS.brakeW)
	local DA = Config.DriveAnim or {}
	local brakePull = (DA.BrakeArmPull or 0.08) * S * bw
	local brakeLean = (DA.BrakeLean or 0.22) * bw

	local AA = Config.AccelAnim
	local aniA = (AA and AA.Enabled ~= false and not cc.dis) and (cc.aniAcc or 0) or 0
	local accW, brkW = math.max(aniA, 0), math.max(-aniA, 0)
	local accLeanAdj = 0
	if AA then
		accLeanAdj = -(AA.ArmBack or 0.05) * accW + (AA.ArmBrake or 0.12) * brkW
		brakePull = brakePull + (AA.ArmPull or 0.07) * S * brkW
	end
	if bw > 0.01 then
		local back = bodyBack
		grips.right = grips.right + back * brakePull
		grips.left  = grips.left  + back * brakePull
	end

	for _, side in pairs(J) do
		for _, m in ipairs(side.extra) do
			if m.Parent then m.Transform = CFrame.new() end
		end
	end

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
	local prevTw = ARMS.twist or 0
	local spin = nil
	if waist and waist.Parent and waist.Part0 then
		local lowerCF = pw(waist.Part0)
		local Wp = lowerCF * waist.C0.Position
		local tw = (cc.disTwist or 0) * ez
		spin = function(th, twA)
			return CFrame.new(Wp) * CFrame.fromAxisAngle(bodyUp, twA or 0) * CFrame.fromAxisAngle(bodyRight, -th) * CFrame.new(-Wp)
		end
		local p0u = spin(prevLean, prevTw):Inverse() * pw(sr.Part0)
		local need = 0
		for i = 0, 12 do
			local th = i * 0.04
			need = th
			if ((spin(th, tw) * p0u) * sr.C0.Position - grips.right).Magnitude <= chR.reach then break end
		end
		need = math.max(need + brakeLean + accLeanAdj, 0)
		if cc.dis then need = need * (1 - sm01(cc.disOver or 0)) + (cc.disLean or 0) end
		local lean = prevLean + (need * ez - prevLean) * math.min(1, dt * 10)
		if lean > 0.002 or math.abs(tw) > 0.002 then
			local wRot = (waist.C0 - waist.C0.Position):Inverse()
			local aC = wRot * lowerCF:VectorToObjectSpace(bodyRight)
			local aU = wRot * lowerCF:VectorToObjectSpace(bodyUp)
			waist.Transform = CFrame.fromAxisAngle(aU, tw) * CFrame.fromAxisAngle(aC, -lean)
		end
		ARMS.lean = lean
		ARMS.twist = tw
	end
	local function p0nOf(sh)
		local p0w = pw(sh.Part0)
		if spin then return spin(ARMS.lean, ARMS.twist) * (spin(prevLean, prevTw):Inverse() * p0w) end
		return p0w
	end

	local gR, gL = grips.right, grips.left
	local relR, relL = cc.disArmR or 0, cc.disArmL or 0
	if cc.dis and (relR > 0.001 or relL > 0.001) then
		local function restPos(chA, sgnA)
			local sp = p0nOf(chA.sh) * chA.sh.C0.Position
			return sp + bodyUp * (-0.92 * chA.reach) + bodyRight * (sgnA * 0.12 * chA.reach) - bodyBack * (0.05 * chA.reach)
		end

		if relR > 0.001 then
			local zH = (Config.Dismount and Config.Dismount.SeatHoldZ) or 1.9
			local seatPt = M.root.CFrame:PointToWorldSpace(V3(0.05 * S, seatSurfY(zH) * S + 0.1 * S, zH * S))
			gR = gR:Lerp(seatPt, sm01(relR))
		end
		if relL > 0.001 then
			gR = gR:Lerp(restPos(chR, 1), sm01(relL))
			gL = gL:Lerp(restPos(chL, -1), sm01(relL))
		end
	end
	solveArm(chR, p0nOf(chR.sh), gR, 1, bodyRight, bodyUp, bodyBack, ez)

	do
		local hj = J.right.hand
		if hj and hj.Parent and AA and AA.Enabled ~= false and not cc.dis then
			local roll = ((AA.WristRoll or 28) * (cc.thrW or 0) - (AA.WristBrake or 10) * (cc.levW or 0)) * (AA.WristSign or 1)
			hj.Transform = CFrame.new():Lerp(CFrame.Angles(math.rad(roll), 0, 0), ez)
		end
	end
	solveArm(chL, p0nOf(chL.sh), gL, -1, bodyRight, bodyUp, bodyBack, ez)

	if LIMB.ch ~= ch or not LIMB.J then
		LIMB.ch = ch
		LIMB.J = limbJoints(ch)
		LIMB.cur, LIMB.jw = {}, {}
	end
	local lb = (DA.LegBend or 1.0)

	local leanRad = ARMS.lean or 0
	local bikeRoll = (cc.leanR or 0) + (cc.rkR or 0)
	local bikePitch = (cc.leanP or 0) + (cc.rkP or 0)
	local lookMul = DA.LookLean
	if lookMul == nil then lookMul = 1.0 end
	local neckPitch = leanRad * (180 / math.pi) * lookMul
		+ bw * 12
		+ ((AA and AA.HeadTilt or 0) * (accW * 0.8 - brkW * 0.6))
		- bikePitch * (180 / math.pi) * 0.35
	local neckRoll = -bikeRoll * (180 / math.pi) * 0.85
	local tgt = {
		rh = V3(55 * lb, 8, 12),
		rk = V3(-95 * lb, 0, 0),
		lh = V3(55 * lb, -8, -12),
		lk = V3(-95 * lb, 0, 0),
		neck = V3(neckPitch + (cc.disHeadPitch or 0), cc.disHeadYaw or 0, neckRoll),
	}

	local legIK = prepLegIK(ch)
	if legIK then
		tgt.rh, tgt.rk, tgt.lh, tgt.lk = nil, nil, nil, nil
	end

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

				local e = jw * jw * (3 - 2 * jw)
				if key ~= "neck" then e = e * ez end
				m.Transform = m.Transform:Lerp(T, math.clamp(e, 0, 1))
			end
		end
	end

	if legIK then
		local FR = Config.FootRest
		local WS = Config.WheelieStand
		local standOn = WS and WS.Enabled
		local s = standOn and (cc.stand or 0) or 0
		local rootCF = M.root.CFrame
		local rootRot = rootCF - rootCF.Position
		local swCF = rootCF * M.wSwing.C0
		local swRot = swCF - swCF.Position
		local bodyFront = seatW.LookVector
		local wSide = { [-1] = sm01(s / 0.3), [1] = sm01((s - 0.2) / 0.3) }

		local PK = Config.Park or {}
		local pe = cc.parkE or 0
		local pSide = cc.parkSide or -1
		local rightH = V3(cos(cc.yaw), 0, -sin(cc.yaw))
		local dropT = 0
		local D = cc.dis
		local DM = Config.Dismount or {}
		for _, side in ipairs({ { legIK.R, 1 }, { legIK.L, -1 } }) do
			local k, sgn = side[1], side[2]
			local p0n = pw(k.sh.Part0)
			local hipPos = p0n * k.sh.C0.Position
			local footRotW = swRot * CFrame.Angles(0, -sgn * math.rad(FR.Splay or 0), 0)
			local lift = (k.ankle.Part1.Size.Y * 0.5 + 0.05) + (FR.Lift or 0) * S
			local x = sgn * (SWX - (FR.Inset or 0))
			local tgtPos
			if (FR.Mode or "pivo") == "pivo" then

				local lp = V3(sgn * (SWX + 0.02), 0.30, FR.PivotZ or -0.15) * S
				tgtPos = swCF:PointToWorldSpace(lp) + footRotW.UpVector * lift
			else
				local z = FR.Z or 1.0
				local zMin = FR.ZMin or 0.1
				while true do
					local lp = V3(x, armTopY(z), z) * S
					tgtPos = swCF:PointToWorldSpace(lp) + footRotW.UpVector * lift
					if (tgtPos - hipPos).Magnitude <= k.reach or z <= zMin then break end
					z = math.max(z - 0.1, zMin)
				end
			end
			if standOn then
				local w = wSide[sgn]
				if w > 0.001 then
					local zS = (sgn == -1) and (WS.FrontZ or 1.0) or (WS.BackZ or 1.8)
					local stPos = rootCF:PointToWorldSpace(V3(sgn * (WS.FootX or 0.3) * S, seatSurfY(zS) * S + lift, zS * S))
					local stRot = rootRot * CFrame.Angles(0, -sgn * math.rad(WS.Splay or 0), 0)
					tgtPos = tgtPos:Lerp(stPos, w) + rootCF.UpVector * (math.sin(math.pi * w) * 0.7 * S)
					footRotW = footRotW:Lerp(stRot, w)
				end

				local seatedHip = (cc.seatCF * (rootInv * k.sh.Part0.CFrame)) * k.sh.C0.Position
				local hipY = rootCF:PointToObjectSpace(seatedHip).Y
				local avgSurf = (seatSurfY(WS.FrontZ or 1.0) + seatSurfY(WS.BackZ or 1.8)) * 0.5 * S
				cc.standRise = math.max(avgSurf + lift + (WS.Straight or 0.93) * (k.L1 + k.L2) - hipY, 0)
			end
			if pe > 0.001 then
				if sgn == pSide then

					local fpH = V3(hipPos.X, 0, hipPos.Z) + rightH * (sgn * (PK.FootOut or 0.3) * S)
					local stepLift = 0
					if D and D.legOn then

						if not D.footStart then
							D.footStart = fpH
							D.footEnd = fpH - rightH * ((DM.StepOut or 0.9) * S)
						end
						local su = cc.disStep or 0
						fpH = D.footStart:Lerp(D.footEnd, su)
						stepLift = math.sin(math.pi * su) * (DM.StepLift or 0.35) * S
					end
					local rr = workspace:Raycast(V3(fpH.X, hipPos.Y + 2 * S, fpH.Z), V3(0, -80, 0), rp)
					local gy = rr and rr.Position.Y or cc.pos.Y
					local toe = PK.ToeDown or 0.5
					local gT = V3(fpH.X, gy + lift + math.sin(toe) * k.ankle.Part1.Size.Z * 0.3 + stepLift, fpH.Z)

					local hipTop = hipPos + V3(0, (cc.parkDrop or 0) * pe, 0)
					local hh = V3(gT.X - hipPos.X, 0, gT.Z - hipPos.Z).Magnitude
					local Ld = k.reach * (PK.Reach or 0.97)
					local need = hipTop.Y - gT.Y - math.sqrt(math.max(Ld * Ld - hh * hh, 0))
					local dropCap = (PK.MaxDrop or 0.9) * S
					if D then dropCap = (DM.MaxDrop or 3.0) * S end
					local pu = cc.pushU or 0
					dropT = (pe > 0.5) and clamp(need, 0, dropCap) * (1 - pu) or 0

					if pe > 0.9 and cc.parkOn then
						cc.parkLeanX = clamp((cc.parkLeanX or 0) + (need - dropCap) * dt * 0.5, 0, PK.LeanExtra or 0.2)
					elseif pu > 0 then
						cc.parkLeanX = math.max((cc.parkLeanX or 0) - dt * 0.6, 0)
					end

					if pu > 0 then
						local fwdH = V3(-sin(cc.yaw), 0, -cos(cc.yaw))
						gT = gT - fwdH * ((PK.PushDist or 0.9) * S * pu * pu * (3 - 2 * pu))
					end
					tgtPos = tgtPos:Lerp(gT, pe) + V3(0, math.sin(math.pi * pe) * 0.6 * S, 0)
					local gRot = CFrame.Angles(0, cc.yaw, 0) * CFrame.Angles(0, -sgn * math.rad(PK.Splay or 15), 0)
						* CFrame.Angles(-toe, 0, 0)
					footRotW = footRotW:Lerp(gRot, pe)
				else

					local hf = clamp(PK.HangFoot or 0, 0, 1)
					if hf > 0 then
						local hang = hipPos + V3(0, -k.reach * 0.8, 0) + bodyFront * (0.3 * S)
						tgtPos = tgtPos:Lerp(hang, pe * hf)
					end
				end
			end

			if D and D.legOn and sgn == 1 and D.footEnd then
				local u = cc.disLeg or 0
				local rch = k.reach
				local P0 = tgtPos
				local fwdH = V3(-sin(cc.yaw), 0, -cos(cc.yaw))
				local pf = D.footEnd + rightH * ((DM.FeetGap or 0.95) * S) - fwdH * ((DM.FootBack or 0.35) * S)
				local rr2 = workspace:Raycast(V3(pf.X, hipPos.Y + 2 * S, pf.Z), V3(0, -80, 0), rp)
				local gy2 = rr2 and rr2.Position.Y or cc.pos.Y
				local toe2 = PK.ToeDown or 0.5
				local Pf = V3(pf.X, gy2 + lift + math.sin(toe2) * k.ankle.Part1.Size.Z * 0.3, pf.Z)

				local Pm = M.root.CFrame:PointToWorldSpace(V3((DM.TailX or -0.1) * S, (DM.TailY or 3.9) * S, (DM.TailZ or 3.0) * S))
				local vPm = Pm - hipPos
				if vPm.Magnitude > rch * 0.97 then Pm = hipPos + vPm.Unit * (rch * 0.97) end
				local Cc = Pm * 2 - (P0 + Pf) * 0.5
				local iu = 1 - u
				tgtPos = P0 * (iu * iu) + Cc * (2 * iu * u) + Pf * (u * u)
				local gRot2 = CFrame.Angles(0, cc.yaw, 0) * CFrame.Angles(0, -sgn * math.rad(PK.Splay or 15), 0) * CFrame.Angles(-toe2, 0, 0)
				footRotW = footRotW:Lerp(gRot2, sm01((u - 0.5) / 0.5))

				local fwK = cc.disKickFoot or 0
				if fwK > 0.001 and cc.kick then
					local ks = cc.kick
					local eK = cc.kickE or 0
					local sK = eK * eK * (3 - 2 * eK)
					local dirK = (ks.d0 * (1 - sK) + ks.d1 * sK).Unit
					local padW = M.root.CFrame:PointToWorldSpace(ks.P + dirK * ks.L)
					local padTop = padW + V3(0, lift + 0.04 * S, 0)
					local wK = sm01(fwK)
					tgtPos = tgtPos:Lerp(padTop, wK)
					footRotW = footRotW:Lerp(CFrame.Angles(0, cc.yaw, 0) * CFrame.Angles(0, -sgn * math.rad(PK.Splay or 15), 0), wK)
				end
			end
			solveLeg(k, p0n, tgtPos, sgn, bodyRight, bodyUp, bodyFront, ez, footRotW, FR.KneeOut or 0.3)
		end
		cc.parkDrop = (cc.parkDrop or 0) + (dropT - (cc.parkDrop or 0)) * math.min(1, dt * 5)
	end
end

local Dis = {}
do
	local function ease(x) x = clamp(x, 0, 1) return x * x * (3 - 2 * x) end

	function Dis.can(cc)
		local DM = Config.Dismount
		if not (DM and DM.Enabled) then return false end
		local PK = Config.Park
		if not (PK and PK.Enabled) then return false end
		if cc.dis or cc.anim or cc.arrive then return false end
		if Config.LimbAnim == false then return false end
		if not (LEGIK.R and LEGIK.L) then return false end
		if not cc.grounded then return false end
		if math.abs(cc.vF or 0) > (DM.MaxSpeed or 25) then return false end
		if (cc.wheelP or 0) > 0.05 or (cc.stand or 0) > 0.01 then return false end
		return true
	end

	function Dis.begin(cc)
		cc.dis = { phase = "stop", t = 0, want = (cc.parkOn == true), legOn = false, kb = 0, kick = false }
		cc.disLeg, cc.disStep, cc.disOver, cc.disArmR, cc.disArmL = 0, 0, 0, 0, 0
		cc.disLean, cc.disTwist, cc.disHeadYaw, cc.disHeadPitch, cc.disKickFoot = 0, 0, 0, 0, 0
	end

	function Dis.finish(cc)
		local D = cc.dis
		cc.kickIdle = 99
		dismountBike(true)
	end

	function Dis.step(cc, dt)
		local D = cc.dis
		if not D then return end
		local DM = Config.Dismount or {}
		local ch, hum, rpart = charParts()
		if not (ch and hum and rpart) or hum.Health <= 0 then
			dismountBike()
			return
		end

		if not hum.Sit then hum.Sit = true end
		pcall(function() hum.Jump = false end)
		D.t = D.t + dt
		local ph = D.phase
		if (ph == "stop" or ph == "plant") and getMove().Z < -0.6 then

			cc.dis = nil
			cc.disLeg, cc.disStep, cc.disOver, cc.disArmR, cc.disArmL = 0, 0, 0, 0, 0
			cc.disLean, cc.disTwist, cc.disHeadYaw, cc.disHeadPitch, cc.disKickFoot = 0, 0, 0, 0, 0
			return
		end

		do
			local lt, tw, hy, hp = 0, 0, 0, 0
			local hd = DM.HeadDown or 20
			if ph == "plant" then
				lt, hy, hp = 0.12, 15, -hd * 0.5
			elseif ph == "over" then
				local uo = clamp(D.t / math.max(DM.LegTime or 1.0, 0.2), 0, 1)
				if uo < 0.5 then
					lt, tw, hy, hp = DM.TorsoLean or 0.3, (DM.TorsoTwist or 0.3) * 0.5, (DM.HeadYaw or 30) * 0.5, -hd * 0.5
				else
					lt, tw, hy, hp = 0.15, DM.TorsoTwist or 0.3, DM.HeadYaw or 30, -hd * 0.7
				end
			elseif ph == "armR" then
				lt, tw, hy, hp = 0.05, 0.15, 15, -hd * 0.25
			elseif ph == "armL" then
				lt, tw, hy, hp = 0.05, 0, 10, -hd * 0.25
			elseif ph == "lean" then
				hy, hp = 20, -hd * 0.5
			elseif ph == "foot" then
				lt, hy, hp = 0.12, 25, -hd
			elseif ph == "kick" then
				lt, hy, hp = 0.12, 25, -hd
			end
			local kS = math.min(1, dt * (DM.Smooth or 7))
			cc.disLean = (cc.disLean or 0) + (lt - (cc.disLean or 0)) * kS
			cc.disTwist = (cc.disTwist or 0) + (tw - (cc.disTwist or 0)) * kS
			cc.disHeadYaw = (cc.disHeadYaw or 0) + (hy - (cc.disHeadYaw or 0)) * kS
			cc.disHeadPitch = (cc.disHeadPitch or 0) + (hp - (cc.disHeadPitch or 0)) * kS
			local kf = cc.disKickFoot or 0
			local kfT = (ph == "foot" or ph == "kick") and 1 or 0
			local kfStep = dt / math.max(DM.FootTime or 0.3, 0.05)
			cc.disKickFoot = clamp(kf + clamp(kfT - kf, -kfStep, kfStep), 0, 1)
		end
		if ph == "stop" then
			if (cc.grounded and math.abs(cc.vF or 0) < (DM.StopSpeed or 1.2)) or D.t > (DM.StopTimeout or 3) then
				D.phase, D.t = "plant", 0
			end
		elseif ph == "plant" then
			if (cc.parkSide or -1) == 1 and (cc.park or 0) > 0.02 then

				D.want = false
			else
				cc.parkSide = -1
				D.want = true
				if (cc.park or 0) >= 0.97 or D.t > 2 then D.phase, D.t = "over", 0 end
			end
		elseif ph == "over" then
			D.legOn = true
			local u = clamp(D.t / math.max(DM.LegTime or 1.0, 0.2), 0, 1)
			cc.disLeg = ease(u / 0.8)
			cc.disStep = ease((u - 0.05) / 0.4)
			cc.disOver = ease((u - 0.25) / 0.75)
			if u >= 1 then D.phase, D.t = "armR", 0 end
		elseif ph == "armR" then
			cc.disArmR = clamp(D.t / math.max(DM.ArmTime or 0.4, 0.05), 0, 1)
			if cc.disArmR >= 1 then
				D.freeze = nil
				D.freeze = riderBase(cc)
				D.phase, D.t = "lean", 0
			end
		elseif ph == "lean" then
			D.kb = clamp(D.t / math.max(DM.LeanTime or 0.35, 0.05), 0, 1)
			if D.kb >= 1 then D.phase, D.t = "foot", 0 end
		elseif ph == "foot" then

			if (cc.disKickFoot or 0) >= 0.99 or D.t > 1 then D.phase, D.t = "kick", 0 D.kick = true D.hold = 0 end
		elseif ph == "kick" then
			local KS = Config.Kickstand
			local settled = true
			if KS and KS.Enabled then
				settled = (cc.kickE or 0) >= 0.99 and (cc.kickL or 0) >= 0.95 and math.abs(cc.kickLV or 0) < 0.35
			end
			if settled then D.hold = (D.hold or 0) + dt else D.hold = 0 end
			if D.hold >= (DM.KickWait or 0.25) or D.t > (DM.KickTimeout or 2.5) then
				D.phase, D.t = "settle", 0
			end
		elseif ph == "settle" then

			cc.disArmL = clamp(D.t / math.max(DM.SettleTime or 0.5, 0.05), 0, 1)
			if D.t >= (DM.SettleTime or 0.5) then Dis.finish(cc) end
		end
	end
end

local function holdRider(cc, dt)
	if not cc.driver then return end
	local ch, hum, rpart = charParts()
	if not ch then return end

	if cc.dis then
		Dis.step(cc, dt or (1 / 60))
		if not cc.driver or not cc.dis then
			if cc.driver then rpart.CFrame = riderBase(cc) end
			return
		end
		rpart.CFrame = riderBase(cc)
		rpart.AssemblyLinearVelocity = V3(0, 0, 0)
		rpart.AssemblyAngularVelocity = V3(0, 0, 0)
		return
	end

	if not hum.Sit and os.clock() - (cc.mountT or 0) > 0.35 then
		if Dis.can(cc) then
			Dis.begin(cc)
			hum.Sit = true
			rpart.CFrame = riderBase(cc)
			return
		end
		dismountBike()
		return
	end
	rpart.CFrame = riderBase(cc)
	rpart.AssemblyLinearVelocity = V3(0, 0, 0)
	rpart.AssemblyAngularVelocity = V3(0, 0, 0)
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
		sSkid = Instance.new("Sound")
		sSkid.Name = "MotoSkid"
		sSkid.SoundId = Config.SoundSkid
		sSkid.Looped = true
		sSkid.Volume = 0
		sSkid.Parent = SoundService
	end)
end
local sndMix, sndPitch, sndT, sndSkid = 0, 0.8, os.clock(), 0
local function soundStep(cc)
	if not sRun or not sIdle then return end
	local now = os.clock()
	local dt = math.min(now - sndT, 0.1)
	sndT = now
	if sSkid then
		local want = (cc and cc.driver and cc.grounded) and clamp(cc.skid or 0, 0, 1) or 0
		sndSkid = sndSkid + (want - sndSkid) * (1 - math.exp(-(want > sndSkid and 14 or 7) * dt))
		sSkid.Volume = Config.VolSkid * sndSkid
		if sndSkid > 0.03 then
			if not sSkid.Playing then sSkid:Play() end
		elseif sSkid.Playing then
			sSkid:Stop()
		end
	end
	if cc and (cc.driver or cc.arrive) then
		local ratio = clamp(math.abs(cc.vF) / Config.TopSpeed, 0, 1)
		if not sIdle.Playing then sIdle:Play() end
		if not sRun.Playing then sRun:Play() end

		local thr = cc.throttle
		local targetMix = clamp(math.max(ratio * 2.5, thr), 0, 1)
		local k = 1 - math.exp(-(targetMix > sndMix and 10 or 5) * dt)
		sndMix = sndMix + (targetMix - sndMix) * k
		local targetPitch = 0.8 + 0.9 * ratio + 0.15 * thr - ((cc.shiftT or 0) > 0 and 0.3 or 0)
		sndPitch = sndPitch + (targetPitch - sndPitch) * (1 - math.exp(-8 * dt))
		sIdle.Volume = Config.VolIdle * (1 - sndMix)
		sRun.Volume = Config.VolRun * sndMix * (0.5 + 0.5 * math.max(ratio, thr))
		sRun.PlaybackSpeed = sndPitch
	else
		sndMix, sndPitch = 0, 0.8
		if sIdle.Playing then sIdle:Stop() end
		if sRun.Playing then sRun:Stop() end
	end
end

local function newSmoke(att, sizeMul, life)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(205, 205, 212))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.4, 0.8), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 * S * sizeMul), NumberSequenceKeypoint.new(1, 1.3 * S * sizeMul) })
	e.Lifetime = life
	e.Speed = NumberRange.new(3, 6)
	e.SpreadAngle = Vector2.new(8, 8)
	e.Acceleration = V3(0, 2, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.LightEmission = 0
	e.Rate = 0
	e.Parent = att
	return e
end

local function makeFx(cc)
	if LITE then return nil end
	local fx = { ex = {}, spark = {}, pegSmoke = {}, tire = nil, trail = nil }
	pcall(function()
		local t0, t1 = Instance.new("Attachment"), Instance.new("Attachment")
		t0.Name, t1.Name = "FxMarcaE", "FxMarcaD"
		t0.CFrame = CFrame.new(V3(-0.72, 0.06, 3.4) * S)
		t1.CFrame = CFrame.new(V3(0.72, 0.06, 3.4) * S)
		t0.Parent, t1.Parent = cc.root, cc.root
		local tr = Instance.new("Trail")
		tr.Name = "MarcaPneu"
		tr.Attachment0, tr.Attachment1 = t0, t1
		tr.FaceCamera = false
		tr.Lifetime = 5
		tr.MinLength = 0.2
		tr.LightEmission = 0
		tr.LightInfluence = 1
		tr.Color = ColorSequence.new(Color3.fromRGB(12, 12, 12))
		tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.6, 0.55), NumberSequenceKeypoint.new(1, 1) })
		tr.Enabled = false
		tr.Parent = cc.root
		fx.trail = tr
		local ta = Instance.new("Attachment")
		ta.Name = "FxPneu"
		ta.CFrame = CFrame.new(V3(0, 0.25, 3.4) * S)
		ta.Parent = cc.root
		local te = newSmoke(ta, 2.2, NumberRange.new(0.6, 1.2))
		te.Color = ColorSequence.new(Color3.fromRGB(235, 235, 240))
		te.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 1) })
		te.Speed = NumberRange.new(2, 5)
		te.SpreadAngle = Vector2.new(25, 25)
		te.EmissionDirection = Enum.NormalId.Top
		fx.tire = te
		for _, sx in ipairs({ -1, 1 }) do
			local a = Instance.new("Attachment")
			a.Name = "FxEscape"
			a.CFrame = CFrame.new(V3(sx * 1.28, 0.7, 2.36) * S)
			a.Parent = cc.root
			local e = newSmoke(a, 1, NumberRange.new(0.45, 0.9))
			e.EmissionDirection = Enum.NormalId.Back
			fx.ex[#fx.ex + 1] = e
		end
		for i, sx in ipairs({ -1, 1 }) do
			local a = Instance.new("Attachment")
			a.Name = "FxPedaleira"
			a.CFrame = CFrame.new(V3(sx * 1.2, 0.8, 1.7) * S)
			a.Parent = cc.root
			local sp = Instance.new("ParticleEmitter")
			sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			sp.Color = ColorSequence.new(Color3.fromRGB(255, 225, 120), Color3.fromRGB(255, 120, 20))
			sp.LightEmission = 1
			sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
			sp.Lifetime = NumberRange.new(0.18, 0.4)
			sp.Speed = NumberRange.new(14, 28)
			sp.SpreadAngle = Vector2.new(30, 30)
			sp.Acceleration = V3(0, -45, 0)
			sp.EmissionDirection = Enum.NormalId.Bottom
			sp.Rate = 0
			sp.Parent = a
			fx.spark[i] = sp
			local sm = newSmoke(a, 0.6, NumberRange.new(0.3, 0.6))
			sm.EmissionDirection = Enum.NormalId.Bottom
			fx.pegSmoke[i] = sm
		end
	end)
	return fx
end

local function fxStep(cc)
	local fx = cc and cc.fx
	if not fx or not fx.ex[1] then return end
	local drv = cc.driver == true or cc.arrive ~= nil
	local ratio = clamp(math.abs(cc.vF) / Config.TopSpeed, 0, 1)
	local rate = drv and (3 + cc.throttle * 16 + ratio * 8) or 0
	for _, e in ipairs(fx.ex) do e.Rate = rate end
	if fx.trail then fx.trail.Enabled = drv and cc.grounded and (cc.skid or 0) > 0.25 end
	if fx.tire then fx.tire.Rate = (drv and cc.grounded) and (cc.skid or 0) * 55 or 0 end
	if cc.shiftPuff then
		cc.shiftPuff = false
		for _, e in ipairs(fx.ex) do e:Emit(5) end
	end
	local lean = cc.leanR or 0
	local over = 0
	if drv and cc.grounded and math.abs(cc.vF) > 25 then
		over = clamp((math.abs(lean) - Config.ScrapeLean) / 0.25, 0, 1)
	end
	for i, sx in ipairs({ -1, 1 }) do
		local on = over > 0 and ((lean > 0 and sx == -1) or (lean < 0 and sx == 1))
		fx.spark[i].Rate = on and (30 + 70 * over) or 0
		fx.pegSmoke[i].Rate = on and (8 + 14 * over) or 0
	end
end

local Anim = {}
do
	local AC = Config.Anim
	local rnd = Random.new()
	local WHITE = Color3.new(1, 1, 1)
	local jobs, jobConn = {}, nil

	local function easeOut(k) k = 1 - k return 1 - k * k * k end
	local function backOut(k) k = k - 1 return 1 + 2.70158 * k * k * k + 1.70158 * k * k end
	local function vol(p) local s = p.Size return s.X * s.Y * s.Z end
	local function rndDir()
		local v = V3(rnd:NextNumber(-1, 1), rnd:NextNumber(-1, 1), rnd:NextNumber(-1, 1))
		if v.Magnitude < 0.1 then return V3(0, 1, 0) end
		return v.Unit
	end

	local function slice(list, i, fn, budget)
		local n, t0, cnt = #list, os.clock(), 0
		while i <= n do
			pcall(fn, list[i])
			i = i + 1
			cnt = cnt + 1
			if cnt >= 6 and os.clock() - t0 > budget then break end
		end
		return i
	end

	local function startJob(job)
		jobs[#jobs + 1] = job
		if jobConn then return end
		jobConn = RunService.RenderStepped:Connect(function(dt)
			local i = 1
			while i <= #jobs do
				local j = jobs[i]
				local ok, done = pcall(j.step, dt)
				if (not ok) or done then
					table.remove(jobs, i)
					pcall(j.cleanup)
				else
					i = i + 1
				end
			end
			if #jobs == 0 and jobConn then
				jobConn:Disconnect()
				jobConn = nil
			end
		end)
	end
	function Anim.killAll()
		local list = jobs
		jobs = {}
		if jobConn then jobConn:Disconnect() jobConn = nil end
		for _, j in ipairs(list) do pcall(j.cleanup) end
	end

	local function collect(model)
		local parts, weldOf, guis, lights = {}, {}, {}, {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				parts[#parts + 1] = d
			elseif d:IsA("Weld") then
				if d.Part1 then weldOf[d.Part1] = d end
			elseif d:IsA("SurfaceGui") then
				guis[#guis + 1] = d
			elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Light") then
				lights[#lights + 1] = d
			end
		end
		return parts, weldOf, guis, lights
	end

	local function makeHighlight(model)
		local hl = Instance.new("Highlight")
		hl.Name = "MotoAnimHL"
		hl.FillColor = WHITE
		hl.OutlineColor = WHITE
		hl.FillTransparency = 0.1
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Adornee = model
		hl.Parent = model
		return hl
	end

	local function makeTrail(p)
		local s = p.Size
		local h = clamp(math.max(s.X, s.Y, s.Z) * 0.5, 0.25, 1.2)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position = V3(0, h, 0)
		a1.Position = V3(0, -h, 0)
		a0.Parent, a1.Parent = p, p
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Color = ColorSequence.new(WHITE)
		tr.LightEmission = 1
		tr.LightInfluence = 0
		tr.Lifetime = 0.32
		tr.MinLength = 0.05
		tr.FaceCamera = true
		tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
		tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
		tr.Parent = p
		return { tr = tr, a0 = a0, a1 = a1 }
	end
	local function endTrail(t)
		pcall(function() t.tr.Enabled = false end)
		Debris:AddItem(t.tr, 0.6)
		Debris:AddItem(t.a0, 0.6)
		Debris:AddItem(t.a1, 0.6)
	end
	local function glowPart(size, shape)
		local p = Instance.new("Part")
		p.Name = "MotoFxGlow"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = WHITE
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then p.Shape = shape end
		p.Size = size
		p.Transparency = 1
		p.Parent = workspace
		return p
	end

	function Anim.despawn(cc)
		local model, root = cc.model, cc.root
		local rootCF = cc.cf
		local gy = cc.pos.Y
		local maxFly = LITE and 90 or (AC.MaxFly + AC.MaxFlyWheel)
		local TA, TB = AC.BreakTime, AC.GatherTime
		local TC = TA + TB
		local TD = TC + AC.BoxShake
		local parts, weldOf, guis, lights = collect(model)
		for _, g in ipairs(guis) do g.Enabled = false end
		for _, l in ipairs(lights) do pcall(function() l.Enabled = false end) end

		local pool = {}
		for _, p in ipairs(parts) do
			if p ~= root and p.Transparency < 1 then pool[#pool + 1] = { p = p, v = vol(p) } end
		end
		table.sort(pool, function(a, b) return a.v > b.v end)
		local fl, destroyQ = {}, {}
		for i, it in ipairs(pool) do
			if i <= maxFly then fl[#fl + 1] = it else destroyQ[#destroyQ + 1] = it.p end
		end
		for _, p in ipairs(destroyQ) do p.Transparency = 1 end

		local B = 1.3 * S
		local hB, hL = 0.62 * B, 0.2 * B
		local boxCenter = V3(cc.pos.X, gy + hB / 2 + 0.15, cc.pos.Z)
		local boxCF = CFrame.new(boxCenter) * CFrame.Angles(0, cc.yaw, 0)
		local cen = rootCF.Position + rootCF.UpVector * (1.6 * S)

		for _, it in ipairs(fl) do
			local p = it.p
			local w = weldOf[p]
			if w then w.Enabled = false end
			p.Anchored = true
			local cf = p.CFrame
			it.pos = cf.Position
			it.rot = cf - cf.Position
			local d = it.pos - cen
			local flat = V3(d.X, 0, d.Z)
			if flat.Magnitude < 0.05 then flat = V3(rnd:NextNumber(-1, 1), 0, rnd:NextNumber(-1, 1)) end
			if flat.Magnitude < 0.05 then flat = V3(1, 0, 0) end
			flat = flat.Unit
			it.vel = flat * (9 + rnd:NextNumber() * 20) + V3(0, 9 + rnd:NextNumber() * 17, 0) + rndDir() * 3
			it.axis = rndDir()
			it.w = (rnd:NextNumber() * 2 - 1) * 10
		end

		local hl = makeHighlight(model)
		local gold = Config.AccentColor
		local bodyC = Config.BodyColor
		local extras = {}
		local folder = Instance.new("Folder")
		folder.Name = "MotoGift"
		folder.Parent = workspace

		local function giftPart(name, size, color, sphere)
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size
			p.Color = color
			p.Material = Enum.Material.SmoothPlastic
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.CastShadow = false
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Transparency = 1
			if sphere then
				local m = Instance.new("SpecialMesh")
				m.MeshType = Enum.MeshType.Sphere
				m.Parent = p
			end
			p.Parent = folder
			return p
		end
		local yb = -hB / 2
		local top = hB / 2 + hL
		local specs = {
			{ "Base", V3(B, hB, B), V3(0, 0, 0), 0, bodyC, false, false, false },
			{ "Lid", V3(1.1 * B, hL, 1.1 * B), V3(0, hB / 2 + hL / 2, 0), 0, bodyC:Lerp(WHITE, 0.15), false, true, false },
			{ "RibbonA", V3(0.2 * B, hB + hL + 0.02 * B, 1.12 * B), V3(0, yb + (hB + hL + 0.02 * B) / 2, 0), 0, gold, false, false, true },
			{ "RibbonB", V3(1.12 * B, hB + hL + 0.01 * B, 0.2 * B), V3(0, yb + (hB + hL + 0.01 * B) / 2, 0), 0, gold, false, false, true },
			{ "BowL", V3(0.42 * B, 0.24 * B, 0.2 * B), V3(-0.2 * B, top + 0.1 * B, 0), 0.55, gold, true, true, true },
			{ "BowR", V3(0.42 * B, 0.24 * B, 0.2 * B), V3(0.2 * B, top + 0.1 * B, 0), -0.55, gold, true, true, true },
			{ "Knot", V3(0.17 * B, 0.17 * B, 0.17 * B), V3(0, top + 0.06 * B, 0), 0, gold:Lerp(WHITE, 0.25), true, true, true },
		}
		local G = {}
		for _, sp in ipairs(specs) do
			G[#G + 1] = { p = giftPart(sp[1], sp[2], sp[5], sp[6]), size = sp[2], off = sp[3], rz = sp[4], hop = sp[7], flash = sp[8], col = sp[5] }
		end
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 225, 160)
		glow.Range = 30
		glow.Brightness = 0
		glow.Parent = G[1].p
		local function setBox(cf, sc, hop, flash)
			sc = math.max(0.05, sc)
			for _, g in ipairs(G) do
				local off = g.off * sc
				if g.hop then off = off + V3(0, hop, 0) end
				g.p.Size = g.size * sc
				g.p.CFrame = cf * CFrame.new(off) * CFrame.Angles(0, 0, g.rz)
				if g.flash then g.p.Color = g.col:Lerp(WHITE, flash) end
			end
		end
		setBox(boxCF, 0.05, 0, 0)

		local function mkPart(pos)
			local ep = Instance.new("Part")
			ep.Name = "MotoFx"
			ep.Anchored = true
			ep.CanCollide = false
			ep.CanQuery = false
			ep.CanTouch = false
			ep.CastShadow = false
			ep.Transparency = 1
			ep.Size = V3(1, 1, 1)
			ep.CFrame = CFrame.new(pos)
			ep.Parent = workspace
			extras[#extras + 1] = ep
			return ep
		end
		local function mkSmoke(parent, n, big)
			local sm = Instance.new("ParticleEmitter")
			sm.Texture = "rbxasset://textures/particles/smoke_main.dds"
			sm.Color = ColorSequence.new(Color3.fromRGB(215, 215, 220), Color3.fromRGB(95, 95, 100))
			sm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
			sm.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5 * S * big), NumberSequenceKeypoint.new(1, 9 * S * big) })
			sm.Lifetime = NumberRange.new(0.9, 1.5)
			sm.Speed = NumberRange.new(8, 22)
			sm.SpreadAngle = Vector2.new(180, 180)
			sm.Rate = 0
			sm.Parent = parent
			sm:Emit(n)
		end
		pcall(function() mkSmoke(mkPart(cen), LITE and 8 or 18, 0.8) end)

		local bp, bc, lastN = {}, {}, 0
		local stage, boxShown, ph = 1, false, 0
		local exploded, T4, ring = false, 0, nil
		local di = 1
		local dead = false
		local T0 = os.clock()
		local function cleanup()
			if dead then return end
			dead = true
			pcall(function() hl:Destroy() end)
			pcall(function() model:Destroy() end)
			pcall(function() folder:Destroy() end)
			for _, e in ipairs(extras) do pcall(function() e:Destroy() end) end
		end

		local function explode()
			exploded = true
			local ep = mkPart(boxCenter + V3(0, 0.5 * B, 0))
			local conf = Instance.new("ParticleEmitter")
			conf.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			conf.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, gold),
				ColorSequenceKeypoint.new(0.5, WHITE),
				ColorSequenceKeypoint.new(1, bodyC:Lerp(WHITE, 0.3)),
			})
			conf.LightEmission = 1
			conf.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.8 * S), NumberSequenceKeypoint.new(1, 0) })
			conf.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
			conf.Lifetime = NumberRange.new(0.9, 1.7)
			conf.Speed = NumberRange.new(40, 120)
			conf.SpreadAngle = Vector2.new(180, 180)
			conf.Acceleration = V3(0, -50, 0)
			conf.Drag = 1.5
			conf.Rotation = NumberRange.new(0, 360)
			conf.RotSpeed = NumberRange.new(-240, 240)
			conf.Rate = 0
			conf.Parent = ep
			conf:Emit(LITE and 35 or AC.Confetti)
			pcall(mkSmoke, ep, LITE and 14 or 30, 2.2)

			pcall(function()
				local ex = Instance.new("Explosion")
				ex.Position = boxCenter
				ex.BlastRadius = AC.BlastRadius * 0.5
				ex.BlastPressure = 0
				ex.DestroyJointRadiusPercent = 0
				ex.ExplosionType = Enum.ExplosionType.NoCraters
				ex.Parent = workspace
			end)
			pcall(function()
				local ch, hum, rpart = charParts()
				if not (ch and hum and rpart) then return end
				local d = rpart.Position - boxCenter
				local dist = d.Magnitude
				if dist >= AC.BlastRadius then return end
				local dir = (dist < 0.1) and V3(0, 1, 0) or (d / dist)
				local power = AC.BlastPush * (1 - dist / AC.BlastRadius)
				dir = (V3(dir.X, 0, dir.Z).Unit * 0.8 + V3(0, 0.6, 0)).Unit
				if dir ~= dir then dir = V3(0, 1, 0) end
				hum:ChangeState(Enum.HumanoidStateType.Freefall)
				rpart.AssemblyLinearVelocity = rpart.AssemblyLinearVelocity + dir * power
				rpart.AssemblyAngularVelocity = rpart.AssemblyAngularVelocity + V3(rnd:NextNumber(-1, 1), 0, rnd:NextNumber(-1, 1)) * (power * 0.05)
			end)
			pcall(function()
				local snd = Instance.new("Sound")
				snd.SoundId = AC.SoundExplode
				snd.Volume = 1.5
				snd.RollOffMaxDistance = 300
				snd.Parent = ep
				snd:Play()
			end)
			ring = mkPart(boxCenter)
			ring.Shape = Enum.PartType.Ball
			ring.Material = Enum.Material.Neon
			ring.Color = WHITE
			ring.Transparency = 0.2

			for _, g in ipairs(G) do
				local cf = g.p.CFrame
				g.pos = cf.Position
				g.rot = cf - cf.Position
				g.vel = ((g.pos - boxCenter) + rndDir() * 0.6).Unit * (22 + rnd:NextNumber() * 22) + V3(0, 18 + rnd:NextNumber() * 16, 0)
				g.axis = rndDir()
				g.w = (rnd:NextNumber() * 2 - 1) * 12
			end
			glow.Brightness = 10
		end

		local job = {}
		job.cleanup = cleanup
		job.step = function(dt)
			if dead then return true end
			dt = math.min(dt, 1 / 30)
			local t = os.clock() - T0

			if di <= #destroyQ then
				di = slice(destroyQ, di, function(p) p:Destroy() end, 0.004)
			end
			if hl then
				local k = clamp(t / 0.45, 0, 1)
				hl.FillTransparency = 0.1 + 0.9 * k
				hl.OutlineTransparency = k
				if k >= 1 then hl:Destroy() hl = nil end
			end

			if t < TC then
				local gather = t >= TA
				if gather and stage == 1 then
					stage = 2
					for _, it in ipairs(fl) do
						it.p1 = it.pos
						it.tgt = boxCenter + rndDir() * (0.3 * B * rnd:NextNumber())
					end
				end
				local k = gather and clamp((t - TA) / TB, 0, 1) or 0
				local n = 0
				for _, it in ipairs(fl) do
					if not it.hid then
						if not gather then
							local v = it.vel + V3(0, -48 * dt, 0)
							local pos = it.pos + v * dt
							if pos.Y < gy + 0.25 then
								pos = V3(pos.X, gy + 0.25, pos.Z)
								v = V3(v.X * 0.7, math.abs(v.Y) * 0.3, v.Z * 0.7)
							end
							it.vel, it.pos = v, pos
						else
							it.pos = it.p1:Lerp(it.tgt, k * k)
							if k > 0.92 then
								it.hid = true
								it.p.Transparency = 1
							end
						end
						it.rot = CFrame.fromAxisAngle(it.axis, it.w * dt) * it.rot
						n = n + 1
						bp[n] = it.p
						bc[n] = CFrame.new(it.pos) * it.rot
					end
				end
				for j = n + 1, lastN do bp[j] = nil bc[j] = nil end
				lastN = n
				if n > 0 then workspace:BulkMoveTo(bp, bc, Enum.BulkMoveMode.FireCFrameChanged) end
			elseif stage < 3 then
				stage = 3
				for _, it in ipairs(fl) do
					it.p.Transparency = 1
					destroyQ[#destroyQ + 1] = it.p
				end
				for j = 1, lastN do bp[j] = nil bc[j] = nil end
				lastN = 0
			end

			if t >= TA + 0.3 and t < TD then
				if not boxShown then
					boxShown = true
					for _, g in ipairs(G) do g.p.Transparency = 0 end
				end
				local sc, hop, flash, rotC = 1, 0, 0, CFrame.new()
				if t < TC then
					sc = backOut(clamp((t - TA - 0.3) / 0.45, 0, 1))
				else
					local kc = clamp((t - TC) / AC.BoxShake, 0, 1)
					ph = ph + dt * (9 + 38 * kc)
					local amp = 0.03 + 0.2 * kc * kc
					rotC = CFrame.Angles(math.sin(ph) * amp, math.sin(ph * 0.7) * amp * 0.5, math.cos(ph * 1.1) * amp)
					sc = 1 + 0.07 * kc + 0.04 * kc * math.sin(ph * 2)
					hop = math.max(0, math.sin(ph * 1.3)) * 0.1 * B * kc
					flash = (0.5 + 0.5 * math.sin(ph * 2)) * kc
					glow.Brightness = 3 * kc
				end
				setBox(boxCF * rotC, sc, hop, flash)
			end

			if t >= TD then
				if not exploded then
					T4 = t
					explode()
				end
				local te = t - T4
				glow.Brightness = 10 * (1 - clamp(te / 0.5, 0, 1))
				if ring then
					local k = clamp(te / 0.45, 0, 1)
					local d = 2 * AC.BlastRadius * easeOut(k) + 1
					ring.Size = V3(d, d, d)
					ring.Transparency = 0.2 + 0.8 * k
				end
				local fade = clamp((te - 0.8) / 0.5, 0, 1)
				for _, g in ipairs(G) do
					local v = g.vel + V3(0, -55 * dt, 0)
					local pos = g.pos + v * dt
					if pos.Y < gy + 0.2 then
						pos = V3(pos.X, gy + 0.2, pos.Z)
						v = V3(v.X * 0.6, math.abs(v.Y) * 0.35, v.Z * 0.6)
					end
					g.vel, g.pos = v, pos
					g.rot = CFrame.fromAxisAngle(g.axis, g.w * dt) * g.rot
					g.p.CFrame = CFrame.new(pos) * g.rot
					g.p.Transparency = fade
				end
				if te >= 2.2 then
					cleanup()
					return true
				end
			end
			return false
		end
		startJob(job)
	end
end

local function despawnBike(instant)
	if c then
		local cc = c
		if cc.driver then
			cc.driver = false
			releaseChar(true)
		end
		if cc.anim then pcall(cc.anim.abort) end
		if cc.arrive then pcall(Kick.finish, cc) end
		c = nil
		local animated = false
		if not instant and Config.Anim.Enabled and cc.model and cc.model.Parent then
			animated = pcall(Anim.despawn, cc)
		end
		if not animated then
			pcall(function() cc.model:Destroy() end)
		end
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
	local yaw = atan2(-flat.X, -flat.Z)
	local AR = Config.Arrive
	local useArrive = AR and AR.Enabled
	local rgt = V3(cos(yaw), 0, -sin(yaw))

	local p = rpart.Position + flat * 12 + rgt * (useArrive and (AR.SideOffset or 0) or 0)
	local pr = RaycastParams.new()
	pr.FilterType = Enum.RaycastFilterType.Exclude
	pr.FilterDescendantsInstances = { ch }
	local res = workspace:Raycast(p + V3(0, 15, 0), V3(0, -80, 0), pr)
	local gy = res and res.Position.Y or (rpart.Position.Y - 3)
	local E = V3(p.X, gy, p.Z)
	local M = buildBike()
	c = newState(M, E, yaw)
	c.fx = makeFx(c)
	rp.FilterDescendantsInstances = { c.model, ch }
	c.lastChar = ch
	local okK, ks = pcall(Kick.build, M)
	c.kick = okK and ks or nil
	if useArrive then
		local okA = pcall(Kick.startArrive, c, E, yaw)
		if not okA then
			pcall(Kick.finish, c)
			c.pos, c.yaw, c.vel, c.vF = E, yaw, V3(0, 0, 0), 0
		end
	end
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

	local ACC = Config.AccentColor
	local OFFC = Color3.fromRGB(150, 162, 176)
	local METALC = Color3.fromRGB(150, 160, 172)
	local GREENC = Color3.fromRGB(90, 235, 130)
	local REDC = Color3.fromRGB(255, 70, 70)
	local LEDW = Color3.fromRGB(235, 245, 255)
	local LEDB = Color3.fromRGB(150, 205, 255)
	local LAMPC = Color3.fromRGB(255, 226, 130)
	h.anim = {}
	local function isPress2(i)
		return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
	end
	local function line(parent, x1, y1, x2, y2, th, col)
		local dx, dy = x2 - x1, y2 - y1
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
		f.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + th * 0.6, th)
		f.Rotation = math.deg(math.atan2(dy, dx))
		f.BackgroundColor3 = col
		local cn = Instance.new("UICorner")
		cn.CornerRadius = UDim.new(1, 0)
		cn.Parent = f
		f.Parent = parent
		return f
	end
	local function circ(parent, x, y, d, col, tr)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(d, d)
		f.BackgroundColor3 = col
		f.BackgroundTransparency = tr or 0
		local cn = Instance.new("UICorner")
		cn.CornerRadius = UDim.new(1, 0)
		cn.Parent = f
		f.Parent = parent
		return f
	end
	local function arc(parent, cx, cy, r, n, th, col, a0, a1)
		local out, prev = {}, nil
		for i = 0, n do
			local a = math.rad(a0 + (a1 - a0) * i / n)
			local x, y = cx + r * math.sin(a), cy - r * math.cos(a)
			if prev then out[#out + 1] = line(parent, prev[1], prev[2], x, y, th, col) end
			prev = { x, y }
		end
		return out
	end
	local function shell(w, hh, caption)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.BorderSizePixel = 0
		b.Text = ""
		b.ClipsDescendants = true
		b.Size = UDim2.fromOffset(w, hh)
		b.BackgroundTransparency = 1
		local sc = Instance.new("UIScale")
		sc.Parent = b
		local ic = Instance.new("Frame")
		ic.BackgroundTransparency = 1
		ic.BorderSizePixel = 0
		ic.Size = UDim2.fromOffset(w, hh - 14)
		ic.ZIndex = 3
		ic.Parent = b
		local lb = Instance.new("TextLabel")
		lb.BackgroundTransparency = 1
		lb.Position = UDim2.fromOffset(0, hh - 15)
		lb.Size = UDim2.fromOffset(w, 12)
		lb.Font = Enum.Font.GothamBold
		lb.TextSize = 9
		lb.TextColor3 = METALC
		lb.Text = caption
		lb.ZIndex = 3
		lb.Parent = b
		local function paint(k)
			TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = k }):Play()
		end
		local hover = false
		track(b.MouseEnter:Connect(function() hover = true paint(1.06) end))
		track(b.MouseLeave:Connect(function() hover = false paint(1) end))
		track(b.InputBegan:Connect(function(i) if isPress2(i) then paint(0.92) end end))
		track(b.InputEnded:Connect(function(i) if isPress2(i) then paint(hover and 1.06 or 1) end end))
		b.Parent = g
		return b, ic
	end

	do
		local b, ic = shell(58, 60, "SENTAR")
		b.AnchorPoint = Vector2.new(0, 0.5)
		b.Position = UDim2.new(0, 10, 0.5, 0)
		b.Visible = false
		local ag = Instance.new("Frame")
		ag.BackgroundTransparency = 1
		ag.BorderSizePixel = 0
		ag.Size = UDim2.fromOffset(58, 46)
		ag.Parent = ic
		local al = {
			line(ag, 29, 6, 29, 34, 3.2, GREENC),
			line(ag, 19, 24, 29, 34, 3.2, GREENC),
			line(ag, 29, 34, 39, 24, 3.2, GREENC),
		}
		h.anim[#h.anim + 1] = function(t)
			if not b.Visible then return end
			local p = (t * 0.9) % 1
			ag.Position = UDim2.fromOffset(0, p * 8 - 3)
			local tr = 0
			if p > 0.65 then tr = (p - 0.65) / 0.35 elseif p < 0.15 then tr = (0.15 - p) / 0.15 end
			for _, l in ipairs(al) do l.BackgroundTransparency = tr end
		end
		h.sitBtn = b
	end

	do
		local b, ic = shell(58, 60, "FAROL  (H)")
		b.AnchorPoint = Vector2.new(0.5, 0)
		b.Position = UDim2.new(0.5, 0, 0, 6)
		b.Visible = false
		local glow = circ(ic, 29, 25, 46, LAMPC, 1)
		local parts = {}
		local function seg(x1, y1, x2, y2, th, onCol, offCol, offTr)
			local f = line(ic, x1, y1, x2, y2, th, offCol)
			f.BackgroundTransparency = offTr or 0
			parts[#parts + 1] = { f = f, on = onCol, off = offCol, offTr = offTr or 0 }
		end
		for _, sx in ipairs({ -1, 1 }) do
			local function X(x) return 29 + sx * (x - 29) end

			seg(X(31), 27, X(41), 22, 3.2, LEDW, OFFC)
			seg(X(41), 22, X(52), 27, 3.2, LEDW, OFFC)

			seg(X(32), 30, X(40), 35, 2.2, LEDB, OFFC, 0.35)
			seg(X(40), 35, X(51), 36, 2.2, LEDB, OFFC, 0.35)

			seg(X(38), 19, X(47), 8, 2.2, ACC, OFFC)
			seg(X(47), 8, X(54), 17, 2.2, ACC, OFFC)
		end
		seg(29, 14, 29, 27, 2.2, ACC, OFFC)
		local lampOn = false
		h.setHl = function(on)
			lampOn = on and true or false
			for _, p in ipairs(parts) do
				p.f.BackgroundColor3 = lampOn and p.on or p.off
				p.f.BackgroundTransparency = lampOn and 0 or p.offTr
			end
			if not lampOn then glow.BackgroundTransparency = 1 end
		end
		h.anim[#h.anim + 1] = function(t)
			if lampOn and b.Visible then glow.BackgroundTransparency = 0.8 + 0.08 * math.sin(t * 4) end
		end
		h.bLight = b
	end

	do
		local b, ic = shell(58, 60, "FREIO  (ESPACO)")
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.new(1, -41, 0.28, 52)
		b.Visible = false
		local cx, cy = 29, 23
		local glow = circ(ic, cx, cy, 36, REDC, 1)
		local discs = {}
		for _, f in ipairs(arc(ic, cx, cy, 15, 28, 2.4, OFFC, 0, 360)) do discs[#discs + 1] = f end
		for _, f in ipairs(arc(ic, cx, cy, 8.5, 20, 1.8, OFFC, 0, 360)) do discs[#discs + 1] = f end
		discs[#discs + 1] = circ(ic, cx, cy, 5, OFFC, 0)
		for i = 0, 9 do
			local a = math.rad(i * 36 + 18)
			discs[#discs + 1] = circ(ic, cx + 11.8 * math.sin(a), cy - 11.8 * math.cos(a), 2.6, OFFC, 0)
		end
		local cal = arc(ic, cx, cy, 14.5, 8, 6, OFFC, 28, 82)
		local braking = false
		h.setBrake = function(on)
			on = on and true or false
			if on == braking then return end
			braking = on
			for _, f in ipairs(discs) do f.BackgroundColor3 = on and REDC or OFFC end
			for _, f in ipairs(cal) do f.BackgroundColor3 = on and REDC or ACC end
			if not on then glow.BackgroundTransparency = 1 end
		end
		for _, f in ipairs(cal) do f.BackgroundColor3 = ACC end
		h.anim[#h.anim + 1] = function(t)
			if braking and b.Visible then glow.BackgroundTransparency = 0.8 + 0.1 * math.sin(t * 10) end
		end
		h.bBrake = b
	end

	do
		local b, ic = shell(58, 60, "EMPINAR")
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.new(1, -41, 0.28, 118)
		b.Visible = false
		local parts = {}
		for _, f in ipairs(arc(ic, 18, 34, 7, 14, 2.2, OFFC, 0, 360)) do parts[#parts + 1] = f end
		for _, f in ipairs(arc(ic, 44, 14, 7, 14, 2.2, OFFC, 0, 360)) do parts[#parts + 1] = f end
		local body = {
			line(ic, 18, 34, 31, 24, 3, ACC),
			line(ic, 31, 24, 44, 14, 3, ACC),
			line(ic, 31, 24, 25, 20, 3, ACC),
			line(ic, 44, 14, 41, 7, 2.4, ACC),
		}
		local wOn = false
		h.setWheelie = function(on)
			on = on and true or false
			if on == wOn then return end
			wOn = on
			for _, f in ipairs(parts) do f.BackgroundColor3 = on and GREENC or OFFC end
			for _, f in ipairs(body) do f.BackgroundColor3 = on and GREENC or ACC end
		end
		h.bWheelie = b
	end

	local YEL2 = Color3.fromRGB(255, 210, 31)
	local ORG2 = Color3.fromRGB(255, 138, 31)
	local RED2 = Color3.fromRGB(255, 61, 61)
	local TRK2 = Color3.fromRGB(70, 48, 100)
	local LBL = Color3.fromRGB(201, 167, 245)
	local sp = Instance.new("Frame")
	sp.Name = "Velocimetro"
	sp.Size = UDim2.fromOffset(160, 104)
	sp.AnchorPoint = Vector2.new(0, 0)
	sp.Position = Config.HudSpeedoPos
	sp.BackgroundTransparency = 1
	sp.BorderSizePixel = 0
	sp.Visible = false
	sp.Parent = g
	h.speedFrame = sp
	local function lbl(text, size, col, font, y, hgt)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = font
		l.TextSize = size
		l.TextColor3 = col
		l.Text = text
		l.Position = UDim2.fromOffset(0, y)
		l.Size = UDim2.fromOffset(160, hgt)
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.TextStrokeColor3 = Color3.new(0, 0, 0)
		l.TextStrokeTransparency = 0.5
		l.Parent = sp
		return l
	end
	local NSEG = 36
	local trackSegs = arc(sp, 80, 82, 62, NSEG, 8, TRK2, -90, 90)
	local fillSegs = arc(sp, 80, 82, 62, NSEG, 8, YEL2, -90, 90)
	for _, f in ipairs(trackSegs) do f.BackgroundTransparency = 0.35 end
	for _, f in ipairs(fillSegs) do f.Visible = false; f.ZIndex = 2 end
	h.speed = lbl("0", 34, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack, 38, 38)
	h.speed.ZIndex = 3
	lbl("KM/H", 11, LBL, Enum.Font.GothamBold, 74, 14).ZIndex = 3
	h.gear = lbl("N", 15, YEL2, Enum.Font.GothamBlack, 88, 16)
	h.gear.ZIndex = 3
	local arcLit, arcCol = -1, nil
	h.setArc = function(r)
		local lit = math.floor(clamp(r, 0, 1) * NSEG + 0.5)
		local col = (r > 0.85) and RED2 or ((r > 0.65) and ORG2 or YEL2)
		if lit == arcLit and col == arcCol then return end
		if col ~= arcCol then
			arcCol = col
			for _, f in ipairs(fillSegs) do f.BackgroundColor3 = col end
		end
		if lit ~= arcLit then
			arcLit = lit
			for i, f in ipairs(fillSegs) do f.Visible = i <= lit end
		end
	end
	return h
end

local function setTxt(o, t)
	if o.Text ~= t then o.Text = t end
end
local function hudStep(cc)
	if not hud then return end
	local S2 = Config.Susp
	if cc then
		local spd = math.floor(math.abs(cc.vF) * Config.SpeedMul + 0.5)
		setTxt(hud.speed, tostring(spd))
		local gHud = spd < 1 and "N" or tostring(clamp(math.floor(spd / (Config.TopSpeed / 6)) + 1, 1, 6))
		setTxt(hud.gear, gHud)
		local rvH = math.floor(clamp(math.abs(cc.vF) / Config.TopSpeed, 0.02, 1) * 100 + 0.5) / 100
		if hud._rvh ~= rvH then
			hud._rvh = rvH
			hud.setArc(rvH)
		end
		local Mm = cc.M
		if Mm and Mm.dashSpeed then
			local g = spd < 1 and "N" or tostring(clamp(math.floor(spd / (Config.TopSpeed / 6)) + 1, 1, 6))
			setTxt(Mm.dashSpeed, tostring(spd))
			setTxt(Mm.dashGear, g)
			local isN = (g == "N")
			if Mm.dashRed.Visible ~= isN then Mm.dashRed.Visible = isN end
			local rv = math.floor(clamp(math.abs(cc.vF) / Config.TopSpeed, 0.02, 1) * 100 + 0.5) / 100
			if cc._rv ~= rv then
				cc._rv = rv
				Mm.dashRev.Size = UDim2.fromScale(rv, 1)
			end
		end
	else
		setTxt(hud.speed, "0")
		setTxt(hud.gear, "N")
		if hud._rvh ~= 0.02 then hud._rvh = 0.02; hud.setArc(0.02) end
	end
	if hud.sitBtn then
		local show = false
		if cc and not cc.driver then
			local ch, hum, rp = charParts()
			if ch and not hum.Sit and (rp.Position - cc.pos).Magnitude < Config.MountRadius * S and math.abs(cc.vF) < 12 then
				show = true
			end
		end
		if hud.sitBtn.Visible ~= show then hud.sitBtn.Visible = show end
	end
	local drv = (cc ~= nil and cc.driver == true)
	if hud.speedFrame.Visible ~= drv then hud.speedFrame.Visible = drv end
	if hud.bLight.Visible ~= drv then hud.bLight.Visible = drv end
	if hud.bBrake.Visible ~= drv then
		hud.bBrake.Visible = drv
		if not drv then held.brakeUi = false end
	end
	if hud.bWheelie.Visible ~= drv then
		hud.bWheelie.Visible = drv
		if not drv then held.wheelUi = false end
	end
	hud.setWheelie(drv and held.wheelUi)
	local on = (cc ~= nil and cc.headOn == true)
	if hud._hl ~= on then
		hud._hl = on
		hud.setHl(on)
	end
	hud.setBrake(drv and (held.brake or held.brakeUi or (cc.brakeIn or 0) > 0))
	local t = os.clock()
	for _, f in ipairs(hud.anim) do f(t) end
end

local function toggleCall()
	if c then despawnBike() else spawnBike() end
end
local function toggleLight()
	if not c then return end
	c.headOn = not c.headOn
	c.M.setLight(c.headOn)
end
local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

hud = buildHud()
makeSounds()
track(hud.bLight.Activated:Connect(toggleLight))
track(hud.sitBtn.Activated:Connect(function()
	if not c or c.driver then return end
	local ch, hum, rpart = charParts()
	if not ch then return end
	if (rpart.Position - c.pos).Magnitude < Config.MountRadius * S and math.abs(c.vF) < 12 then
		hum.Sit = true
		mountBike()
	end
end))
track(hud.bBrake.InputBegan:Connect(function(i) if isPress(i) then held.brakeUi = true end end))
track(hud.bBrake.InputEnded:Connect(function(i) if isPress(i) then held.brakeUi = false end end))
track(hud.bWheelie.InputBegan:Connect(function(i) if isPress(i) then held.wheelUi = true end end))
track(hud.bWheelie.InputEnded:Connect(function(i) if isPress(i) then held.wheelUi = false end end))

track(UIS.InputBegan:Connect(function(i, gpe)
	if gpe then return end
	if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
	if i.KeyCode == Config.KeyHotkey then toggleCall()
	elseif i.KeyCode == Enum.KeyCode.H then toggleLight()
	elseif i.KeyCode == Enum.KeyCode.Space then held.brake = true end
end))
track(UIS.InputEnded:Connect(function(i)
	if i.KeyCode == Enum.KeyCode.Space then held.brake = false end
end))
track(player.CharacterAdded:Connect(function()
	if c and not (c.model and c.model.Parent) then c = nil end
	if c and c.driver then c.driver = false end
	if c then c.dis = nil end
	saved = nil
	pcall(releaseArms)
	ARMS.J = nil
	ARMS.waist = nil
	LIMB.J, LIMB.ch = nil, nil
	LIMB.cur, LIMB.jw = {}, {}
end))

local KEY = { alive = true }
do
	local KEYDIR = "MOTO_SCRIPT"
	local ACC = Config.AccentColor
	local keyTpl, keyAxis, keyTried = nil, Vector3.zAxis, false
	local keyTool = nil
	local function keyPath(name)
		pcall(function()
			if makefolder and isfolder then
				if not isfolder(KEYDIR) then makefolder(KEYDIR) end
				if not isfolder(KEYDIR .. "/modelos") then makefolder(KEYDIR .. "/modelos") end
			end
		end)
		return KEYDIR .. "/modelos/" .. name
	end
	local function fromDisk(id)
		assert(writefile and readfile and isfile and getcustomasset)
		local path = keyPath(tostring(id) .. ".rbxm")
		for tentativa = 1, 2 do
			if not isfile(path) then
				local data = game:HttpGet("https://assetdelivery.roblox.com/v1/asset/?id=" .. tostring(id))
				assert(type(data) == "string" and #data > 100)
				writefile(path, data)
			end
			local okO, objs = pcall(function() return game:GetObjects(getcustomasset(path)) end)
			if okO and type(objs) == "table" and objs[1] then return objs[1] end
			if delfile then pcall(delfile, path) end
			if tentativa == 2 then error(0) end
		end
	end
	local function fetchModel(id)
		local lastErr = "desconhecido"
		for attempt = 1, 3 do
			local okD, m = pcall(fromDisk, id)
			if okD and m then return m end
			if not okD then lastErr = tostring(m) end
			local okG, objs = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(id)) end)
			if okG and type(objs) == "table" and objs[1] then return objs[1] end
			if not okG then lastErr = tostring(objs) end
			if attempt < 3 then task.wait(1) end
		end
		return nil, lastErr
	end
	local function fallbackKey()
		local L = Config.KeyLength
		local h = Instance.new("Part")
		h.Name = "Handle"
		h.Size = Vector3.new(0.22, 0.22, L)
		h.Material = Enum.Material.Neon
		h.Color = ACC
		h.Anchored = false
		h.CanCollide = false
		h.CanQuery = false
		h.CanTouch = false
		h.Massless = true
		local function piece(size, off, shape)
			local q = Instance.new("Part")
			q.Size = size
			q.Shape = shape or Enum.PartType.Block
			q.Material = Enum.Material.Neon
			q.Color = ACC
			q.CanCollide = false
			q.CanQuery = false
			q.CanTouch = false
			q.Massless = true
			q.CFrame = h.CFrame * CFrame.new(off)
			local w = Instance.new("WeldConstraint")
			w.Part0 = h
			w.Part1 = q
			w.Parent = q
			q.Parent = h
		end
		piece(Vector3.new(0.7, 0.7, 0.7), Vector3.new(0, 0, -L / 2), Enum.PartType.Ball)
		piece(Vector3.new(0.5, 0.2, 0.2), Vector3.new(0.3, 0, L / 2 - 0.1))
		piece(Vector3.new(0.4, 0.2, 0.2), Vector3.new(0.25, 0, L / 2 - 0.4))
		keyAxis = Vector3.zAxis
		return h
	end
	local function loadTemplate()
		if keyTried then return keyTpl end
		keyTried = true
		local id = Config.KeyAccessoryId
		if id then
			local model, err = fetchModel(id)
			if model then
				local h
				if model:IsA("BasePart") then
					h = model
				else
					h = model:FindFirstChild("Handle", true) or model:FindFirstChildWhichIsA("BasePart", true)
				end
				if h then
					local cl = h:Clone()
					pcall(function() model:Destroy() end)
					for _, d in ipairs(cl:GetDescendants()) do
						if d:IsA("Attachment") or d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Script")
							or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Motor6D") or d:IsA("Sound")
							or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Fire") or d:IsA("Smoke")
							or d:IsA("Sparkles") or d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") or d:IsA("Highlight") then
							d:Destroy()
						end
					end
					cl.Name = "Handle"
					cl.Anchored = false
					cl.CanCollide = false
					cl.CanQuery = false
					cl.CanTouch = false
					cl.Massless = true
					cl.CastShadow = true
					local sz = cl.Size
					local f = Config.KeyLength / math.max(math.max(sz.X, sz.Y, sz.Z), 0.01)
					cl.Size = sz * f
					local sm = cl:FindFirstChildOfClass("SpecialMesh")
					if sm then sm.Scale = sm.Scale * f end
					local ns = cl.Size
					if ns.X >= ns.Y and ns.X >= ns.Z then
						keyAxis = Vector3.xAxis
					elseif ns.Y >= ns.Z then
						keyAxis = Vector3.yAxis
					else
						keyAxis = Vector3.zAxis
					end
					keyTpl = cl
					return cl
				end
				pcall(function() model:Destroy() end)
			end
		end
		keyTpl = fallbackKey()
		return keyTpl
	end
	local slotBtn = Instance.new("TextButton")
	slotBtn.Name = "Slot_ChaveDaMoto"
	slotBtn.AutoButtonColor = false
	slotBtn.BorderSizePixel = 0
	slotBtn.BackgroundTransparency = 1
	slotBtn.Text = ""
	slotBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	slotBtn.Position = Config.HudKeyPos
	slotBtn.Size = UDim2.fromOffset(52, 52)
	do
		local cn = Instance.new("UICorner")
		cn.CornerRadius = UDim.new(0, 14)
		cn.Parent = slotBtn
	end
	local slotStroke = Instance.new("UIStroke")
	slotStroke.Color = ACC
	slotStroke.Thickness = 2.5
	slotStroke.Transparency = 0.1
	slotStroke.Parent = slotBtn
	slotBtn.Parent = hud.gui
	local slotIcon = Instance.new("TextLabel")
	slotIcon.BackgroundTransparency = 1
	slotIcon.Size = UDim2.fromScale(1, 1)
	slotIcon.Text = Config.KeyIcon
	slotIcon.TextSize = 26
	slotIcon.Parent = slotBtn
	if Config.KeyAccessoryId then
		local img = Instance.new("ImageLabel")
		img.Name = "KeyThumb"
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.new(1, -10, 1, -10)
		img.ScaleType = Enum.ScaleType.Fit
		img.Visible = false
		img.Image = "rbxthumb://type=Asset&id=" .. tostring(Config.KeyAccessoryId) .. "&w=150&h=150"
		img.Parent = slotBtn
		task.spawn(function()
			for _ = 1, 24 do
				if not (KEY.alive and img.Parent) then return end
				if img.IsLoaded then
					img.Visible = true
					slotIcon.Visible = false
					return
				end
				task.wait(0.25)
			end
		end)
	end
	do
		local lb = Instance.new("TextLabel")
		lb.BackgroundTransparency = 1
		lb.AnchorPoint = Vector2.new(0.5, 0)
		lb.Position = UDim2.new(Config.HudKeyPos.X.Scale, Config.HudKeyPos.X.Offset, Config.HudKeyPos.Y.Scale, Config.HudKeyPos.Y.Offset + 30)
		lb.Size = UDim2.fromOffset(70, 12)
		lb.Font = Enum.Font.GothamBold
		lb.TextSize = 9
		lb.TextColor3 = Color3.fromRGB(200, 160, 255)
		lb.Text = "CHAVE  (" .. Config.KeyHotkey.Name .. ")"
		lb.Parent = hud.gui
	end
	local keyLast = 0
	local function keyUse()
		local ch = charParts()
		if not ch then return end
		if c and c.driver then return end
		if os.clock() - keyLast < Config.KeyCooldown then return end
		keyLast = os.clock()
		pcall(function()
			TweenService:Create(slotBtn, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
				{ Size = UDim2.fromOffset(60, 60) }):Play()
		end)
		toggleCall()
	end
	local function setupKey()
		local ch, hum = charParts()
		if not ch then return end
		local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
		if not backpack then return end
		for _, v in ipairs(backpack:GetChildren()) do
			if v.Name == Config.KeyToolName then pcall(function() v:Destroy() end) end
		end
		local old = ch:FindFirstChild(Config.KeyToolName)
		if old then pcall(function() old:Destroy() end) end
		if keyTool then pcall(function() keyTool:Destroy() end) end
		local tpl = loadTemplate()
		if not tpl then return end
		local tool = Instance.new("Tool")
		tool.Name = Config.KeyToolName
		tool.ToolTip = "Chama a moto"
		tool.RequiresHandle = true
		tool.CanBeDropped = false
		local handle = tpl:Clone()
		handle.Name = "Handle"
		handle.Parent = tool
		local rot = CFrame.new()
		if keyAxis == Vector3.xAxis then
			rot = CFrame.Angles(0, math.rad(90), 0)
		elseif keyAxis == Vector3.yAxis then
			rot = CFrame.Angles(math.rad(90), 0, 0)
		end
		local e = Config.KeyRotation
		tool.Grip = CFrame.new(Config.KeyGrip) * rot * CFrame.Angles(math.rad(e.X), math.rad(e.Y), math.rad(e.Z))
		tool.Activated:Connect(keyUse)
		tool.Equipped:Connect(function()
			KEY.keyOn = true
			slotStroke.Color = Color3.new(1, 1, 1)
			playSound(Config.SoundKeyEquip, 0.5)
		end)
		tool.Unequipped:Connect(function()
			KEY.keyOn = false
			slotStroke.Color = ACC
		end)
		pcall(function() tool.Parent = backpack end)
		keyTool = tool
	end
	track(slotBtn.Activated:Connect(function()
		local ch, hum = charParts()
		if not (ch and hum and keyTool) then return end
		pcall(function()
			if keyTool.Parent == ch then hum:UnequipTools() else hum:EquipTool(keyTool) end
		end)
	end))
	track(player.CharacterAdded:Connect(function()
		task.wait(0.8)
		if KEY.alive and keyTpl then setupKey() end
	end))
	task.spawn(function()
		pcall(loadTemplate)
		if KEY.alive then setupKey() end
		while KEY.alive do
			task.wait(1)
			local bp, ch = player:FindFirstChildOfClass("Backpack"), player.Character
			if keyTool and bp and ch and keyTool.Parent ~= bp and keyTool.Parent ~= ch then
				pcall(function() keyTool.Parent = bp end)
			end
		end
	end)
	function KEY.destroy()
		KEY.alive = false
		if keyTool then pcall(function() keyTool:Destroy() end) end
	end
end

do
	local LITE_NAMES = { off = "LITE DESATIVADO (visual completo)", lite = "MODO LITE ATIVADO", super = "MODO SUPER LITE ATIVADO" }
	local function say(msg)
		pcall(function()
			game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", { Text = "[Moto] " .. msg, Color = Color3.fromRGB(80, 170, 255) })
		end)
		pcall(function()
			local TCS = game:GetService("TextChatService")
			local ch = TCS:FindFirstChild("TextChannels") and TCS.TextChannels:FindFirstChild("RBXGeneral")
			if ch then ch:DisplaySystemMessage("[Moto] " .. msg) end
		end)
	end
	local lastCmd, lastT = nil, 0
	local function liteCmd(text)
		text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if text == "-4" then
			Config.FallRescue = not Config.FallRescue
			say("Anti void (volta pro ultimo ponto seguro ao cair no vazio): " .. (Config.FallRescue and "LIGADO" or "DESLIGADO"))
			return
		end
		local mode = (text == "-1" and "off") or (text == "-2" and "lite") or (text == "-3" and "super") or nil
		if not mode then return end
		local now = os.clock()
		if lastCmd == text and now - lastT < 0.6 then return end
		lastCmd, lastT = text, now
		Config.LiteMode = mode
		LITE = mode ~= "off"
		bikeTpl = nil
		if c and not c.driver then
			spawnBike()
			say(LITE_NAMES[mode] .. " - moto reconstruida.")
		elseif c then
			say(LITE_NAMES[mode] .. " - vale a partir do proximo spawn.")
		else
			say(LITE_NAMES[mode] .. ".")
		end
	end
	track(player.Chatted:Connect(liteCmd))
	pcall(function()
		local TCS = game:GetService("TextChatService")
		track(TCS.MessageReceived:Connect(function(m)
			if m.TextSource and m.TextSource.UserId == player.UserId then liteCmd(m.Text) end
		end))
	end)
	task.delay(3, function()
		local mname = (Config.LiteMode == "super" and "3 (SUPER LITE)") or (Config.LiteMode == "lite" and "2 (LITE)") or "1 (COMPLETO)"
		say("Modo atual: " .. mname .. ". Digite no chat para trocar:")
		say("-1 = COMPLETO: todos os detalhes da moto.")
		say("-2 = LITE: tira detalhes pequenos (parafusos, furos dos discos, malha). Visual quase igual, mais leve.")
		say("-3 = SUPER LITE: tira mais detalhes (frisos, desenho do pneu, dentes), sem sombras e sem a corrente. Para celular fraco.")
		say("A moto e reconstruida ao trocar.")
		say("-4 = ANTI VOID liga/desliga: ao cair no vazio a moto volta pro ultimo ponto seguro (padrao: desligado).")
	end)
end

do
	local list, seen = {}, {}
	local function add(v)
		if type(v) == "string" and v:find("^rbx") and not seen[v] then
			seen[v] = true
			list[#list + 1] = v
		end
	end
	for k, v in pairs(Config) do
		if type(v) == "string" and tostring(k):find("Sound") then add(v) end
	end
	add("rbxasset://textures/particles/smoke_main.dds")
	local total = #list
	if total > 0 then
		local PANEL, AMBER, DIMC, GREEN = Color3.fromRGB(20, 8, 36), Config.AccentColor, Color3.fromRGB(24, 30, 40), Color3.fromRGB(60, 220, 120)
		local box = Instance.new("Frame")
		box.Name = "PreloadBox"
		box.AnchorPoint = Vector2.new(0.5, 0)
		box.Position = UDim2.new(0.5, 0, 0, 70)
		box.Size = UDim2.fromOffset(290, 62)
		box.BackgroundColor3 = PANEL
		box.BackgroundTransparency = 0.12
		box.BorderSizePixel = 0
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 10)
		bc.Parent = box
		local bs = Instance.new("UIStroke")
		bs.Color = AMBER
		bs.Thickness = 1.5
		bs.Parent = box
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Position = UDim2.fromOffset(10, 6)
		lbl.Size = UDim2.new(1, -20, 0, 28)
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 15
		lbl.TextColor3 = Color3.fromRGB(235, 235, 235)
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = "Moto: carregando recursos 0/" .. total
		lbl.Parent = box
		local barBg = Instance.new("Frame")
		barBg.Position = UDim2.fromOffset(10, 40)
		barBg.Size = UDim2.new(1, -20, 0, 8)
		barBg.BackgroundColor3 = DIMC
		barBg.BorderSizePixel = 0
		local bgc = Instance.new("UICorner")
		bgc.CornerRadius = UDim.new(1, 0)
		bgc.Parent = barBg
		barBg.Parent = box
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(0, 1)
		bar.BackgroundColor3 = AMBER
		bar.BorderSizePixel = 0
		local brc = Instance.new("UICorner")
		brc.CornerRadius = UDim.new(1, 0)
		brc.Parent = bar
		bar.Parent = barBg
		box.Parent = hud.gui
		task.spawn(function()
			local done = 0
			pcall(function()
				game:GetService("ContentProvider"):PreloadAsync(list, function()
					done = done + 1
					if box.Parent then
						lbl.Text = "Moto: carregando recursos " .. math.min(done, total) .. "/" .. total
						bar.Size = UDim2.fromScale(math.clamp(done / total, 0, 1), 1)
					end
				end)
			end)
			if box.Parent then
				lbl.Text = "Moto: tudo carregado!"
				bar.Size = UDim2.fromScale(1, 1)
				bar.BackgroundColor3 = GREEN
				task.wait(1.5)
				pcall(function()
					TweenService:Create(box, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
					TweenService:Create(lbl, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
					TweenService:Create(bs, TweenInfo.new(0.5), { Transparency = 1 }):Play()
					TweenService:Create(barBg, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
					TweenService:Create(bar, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
				end)
				task.wait(0.6)
				box:Destroy()
			end
		end)
	end
end

local NEON = { idx = 1, hue = 0, col = nil, rainbow = false, wheels = nil, tint = {}, lights = {}, mdl = nil, btn = nil }
do
  local TAU = math.pi * 2
  local SILVER = Color3.fromRGB(205, 210, 218)
  local PAL = {
    { "CINZA", Color3.fromRGB(150, 152, 158) },
    { "AZUL", Color3.fromRGB(0, 110, 255) },
    { "VERMELHO", Color3.fromRGB(255, 30, 40) },
    { "DOURADO", Color3.fromRGB(255, 190, 0) },
    { "VERDE", Color3.fromRGB(40, 255, 90) },
    { "ROXO", Color3.fromRGB(170, 60, 255) },
    { "ROSA", Color3.fromRGB(255, 60, 200) },
    { "CIANO", Color3.fromRGB(0, 235, 255) },
    { "LARANJA", Color3.fromRGB(255, 120, 0) },
    { "BRANCO", Color3.fromRGB(255, 255, 255) },
    { "ARCO-IRIS", nil },
  }
  NEON.col = PAL[NEON.idx][2]

  local function mkPart(name, size, col)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Color = col
    p.Material = Enum.Material.Neon
    p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
    p.CastShadow = false
    p.Massless = true
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    return p
  end
  local function weldTo(core, part, localCF)
    part.CFrame = core.CFrame * localCF
    part.Parent = core.Parent
    local w = Instance.new("WeldConstraint")
    w.Part0, w.Part1 = core, part
    w.Parent = part
  end

  -- tampa de valvula estilo "bala": corpo colorido, 2 listras prateadas e cupula
  local function buildCap(core, sx, A, D)
    local xc = sx * (A - D + 0.2) -- na lateral do aro, visivel por fora
    local rb = 0.925 -- base colada no aro
    local dir = V3(0, -1, 0)
    local function atT(t) return V3(xc * S, (rb - t) * S, 0) end
    local function cyl(name, t0, t1, dia, col, mat, tinted, refl)
      local p = mkPart(name, V3((t1 - t0) * S, dia * S, dia * S), col)
      p.Shape = Enum.PartType.Cylinder
      p.Material = mat
      if refl then p.Reflectance = refl end
      local pos = atT((t0 + t1) / 2)
      weldTo(core, p, CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.pi / 2, 0))
      if tinted then NEON.tint[#NEON.tint + 1] = p end
      return p
    end
    local M = Enum.Material.Metal
    local N = Enum.Material.Neon
    local W = 0.072 -- diametro do corpo (mais fino)
    cyl("BicoBase", 0, 0.015, W * 0.8, SILVER, M, false, 0.5)
    cyl("BicoCorpo", 0.015, 0.04, W, NEON.col, N, true)
    cyl("BicoListra", 0.04, 0.048, W + 0.008, SILVER, M, false, 0.6)
    cyl("BicoCorpo", 0.048, 0.072, W, NEON.col, N, true)
    cyl("BicoListra", 0.072, 0.08, W + 0.008, SILVER, M, false, 0.6)
    cyl("BicoCorpo", 0.08, 0.095, W, NEON.col, N, true)
    -- ponta curtinha e achatada (ogiva baixa)
    local t0, H, steps = 0.095, 0.03, 5
    local tip
    for i = 1, steps do
      local u0, u1 = (i - 1) / steps, i / steps
      local um = (u0 + u1) / 2
      local dia = math.max(W * (1 - um ^ 2) ^ 0.55, 0.012)
      tip = cyl("BicoPonta", t0 + H * u0, t0 + H * u1 + 0.001, dia, NEON.col, N, true)
    end
    return xc
  end

  local function neonBuild(cc)
    local NC = Config.Neon
    NEON.mdl = cc.model
    NEON.tint, NEON.lights, NEON.wheels = {}, {}, {}
    local N = NC.Segments
    local rr = 0.8625 * S -- mesmo raio do centro da tampinha (rb 0.925 - meio do comprimento 0.125)
    local th = NC.Thickness * S
    local segLen = (TAU * rr / N) * 1.15
    local defs = {
      { core = cc.M.wFWheel.Part1, A = 0.66, D = 0.3 },
      { core = cc.M.wRWheel.Part1, A = 0.82, D = 0.34 },
    }
    for _, d in ipairs(defs) do
      local wh = { segs = {} }
      for _, sx in ipairs({ -1, 1 }) do -- pino e circulo dos dois lados
        local xc
        if sx == 1 then
          xc = buildCap(d.core, sx, d.A, d.D) -- so 1 pino por roda (lado direito)
        else
          xc = sx * (d.A - d.D + 0.2)
        end
        for i = 1, N do
          local a = (i - 1) * TAU / N
          local pos = V3(xc * S, rr * math.cos(a), rr * math.sin(a))
          local tan = V3(0, -math.sin(a), math.cos(a))
          local seg = mkPart("NeonAro", V3(th, th, segLen), NEON.col)
          seg.Transparency = 1
          weldTo(d.core, seg, CFrame.lookAt(pos, pos + tan))
          NEON.tint[#NEON.tint + 1] = seg
          wh.segs[#wh.segs + 1] = { p = seg, a = a, last = 1 }
        end
      end
      NEON.wheels[#NEON.wheels + 1] = wh
    end
  end

  function NEON.paint()
    for _, p in ipairs(NEON.tint) do p.Color = NEON.col end
    for _, l in ipairs(NEON.lights) do l.Color = NEON.col end
    if NEON.btn then
      local e = PAL[NEON.idx]
      NEON.btn.Text = "COR: " .. e[1]
      NEON.btn.BackgroundColor3 = NEON.col
      local c = NEON.col
      local lum = 0.3 * c.R + 0.59 * c.G + 0.11 * c.B
      NEON.btn.TextColor3 = lum > 0.55 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
    end
  end
  function NEON.apply()
    local e = PAL[NEON.idx]
    NEON.rainbow = (e[2] == nil)
    if e[2] then NEON.col = e[2] end
    NEON.paint()
  end

  local function mkBtn()
    if not (hud and hud.gui) then return end
    local b = Instance.new("TextButton")
    b.Name = "NeonCor"
    b.AutoButtonColor = false
    b.AnchorPoint = Vector2.new(0.5, 0.5)
    local kp = Config.HudKeyPos
    b.Position = UDim2.new(kp.X.Scale, kp.X.Offset, kp.Y.Scale, kp.Y.Offset - 66)
    b.Size = UDim2.fromOffset(150, 34)
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.Text = ""
    b.Visible = false
    local cn = Instance.new("UICorner")
    cn.CornerRadius = UDim.new(1, 0)
    cn.Parent = b
    local st = Instance.new("UIStroke")
    st.Color = Color3.new(1, 1, 1)
    st.Thickness = 2
    st.Parent = b
    b.Parent = hud.gui
    track(b.Activated:Connect(function()
      NEON.idx = NEON.idx % #PAL + 1
      NEON.apply()
    end))
    NEON.btn = b
    NEON.paint()
  end

  function NEON.step(cc, dt)
    local NC = Config.Neon
    if not (NC and NC.Enabled) then return end

    -- botao de cor: aparece so enquanto a chave esta na mao
    if not (NEON.btn and NEON.btn.Parent) then
      NEON.btn = nil
      mkBtn()
    end
    if NEON.btn then
      local ch = player.Character
      NEON.btn.Visible = (ch and ch:FindFirstChild(Config.KeyToolName)) ~= nil
    end

    if not (cc and cc.model and cc.model.Parent and cc.M and cc.M.wFWheel and cc.M.wRWheel) then return end
    if NEON.mdl ~= cc.model or not NEON.wheels or not (NEON.tint[1] and NEON.tint[1].Parent) then
      neonBuild(cc)
      NEON.apply()
    end

    if NEON.rainbow then
      NEON.hue = (NEON.hue + dt * NC.HueRate) % 1
      NEON.col = Color3.fromHSV(NEON.hue, 1, 1)
      NEON.paint()
    end

    -- quanto mais rapido a roda gira, mais o rastro do bico alonga ate fechar o circulo perfeito
    local vF = cc.vF or 0
    local omega = math.abs(vF) / (R * S)
    local tailLen = clamp(omega * NC.Persist, 0, TAU)
    local closed = clamp((tailLen - TAU * 0.82) / (TAU * 0.18), 0, 1)
    local dir = vF >= 0 and 1 or -1
    for _, wh in ipairs(NEON.wheels) do
      for _, sg in ipairs(wh.segs) do
        local f = 0
        if tailLen > 0.05 then
          local dd = (dir * sg.a) % TAU
          if dd < tailLen then f = 1 - dd / tailLen end
          f = f + (1 - f) * closed
        end
        local tr = 1 - f * 0.9
        if f < 0.02 then tr = 1 end
        if math.abs(tr - sg.last) > 0.01 then
          sg.last = tr
          sg.p.Transparency = tr
        end
      end
    end
  end
end

RunService:BindToRenderStep("MotoJXz", Enum.RenderPriority.Camera.Value - 1, function(dt)
	dt = math.min(dt, 1 / 20)
	if c and c.model.Parent then
		if not c.anim then
			autoMount()
			stepBike(c, dt)
			Kick.step(c, dt)
			visualsBike(c, dt)
			fxStep(c)
			pcall(NEON.step, c, dt)
			holdRider(c, dt)
		end
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
	pcall(KEY.destroy)
	for _, cn in ipairs(conns) do pcall(function() cn:Disconnect() end) end
	pcall(Anim.killAll)
	despawnBike(true)
	if hud and hud.gui then pcall(function() hud.gui:Destroy() end) end
	if sRun then pcall(function() sRun:Destroy() end) end
	if sIdle then pcall(function() sIdle:Destroy() end) end
	if sSkid then pcall(function() sSkid:Destroy() end) end
	_G.__MOTO_JXZ_CLEANUP = nil
end

end, debug.traceback)
if not ok0 then
	pcall(function()
		game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", { Text = "[Moto] ERRO FATAL: " .. tostring(err0), Color = Color3.fromRGB(255, 80, 80) })
	end)
	warn("[MOTO] erro: " .. tostring(err0))
end
