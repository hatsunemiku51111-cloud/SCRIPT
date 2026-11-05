local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local rad, sin, cos, clamp = math.rad, math.sin, math.cos, math.clamp

local SMOOTH_FACTOR = 0.25
local loopConnectionRender = nil
local loopConnectionStepped = nil

local typingMode = false
local typingTimer = 0
local currentEmote = nil
local emoteTimer = 0
local emoteDuration = 3

local apontarCamera = false
local APONTAR_MAX_YAW = 90
local APONTAR_MAX_PITCH = 90

local freezeEmote = false

local animConfig = {
	direita = true,
	esquerda = true,
	torso = false,
	cabeca = false,
	pernas = false,
}

local EMOTES_TOGGLE = {
	Dancinha = true, ["Braços Cruzados"] = true, ["Deitado de Frente"] = true,
	Sentar = true, Ajoelhar = true, Dormir = true, Dormir2 = true, Siririca = true,
	["Chupada de Dedo"] = true, ["De Quatro"] = true, Socar = true,
}

local EMOTES_IMOVEIS = {
	Sentido = true, Dancinha = true, ["Braços Cruzados"] = true, ["Deitado de Frente"] = true,
	Sentar = true, Ajoelhar = true, Dormir = true, Dormir2 = true, Siririca = true,
	["Chupada de Dedo"] = true, ["De Quatro"] = true, Socar = true, Kamehameha = true,
}

local EMOTES_CORPO = {
	Bow = true, ["Deitado de Frente"] = true, Sentar = true, Ajoelhar = true, Dormir = true, Dormir2 = true,
	["De Quatro"] = true,
}

local EMOTES_BAIXOS = {
	Sentar = -1.5, Ajoelhar = -1.2, Dormir = -2.5, Dormir2 = -2.5,
	["De Quatro"] = -0.9,
}

local DORMIR = {
	emotes = { Dormir = true, Dormir2 = true },
	zzzQtd = 3,
	zzzTempo = 3.2,
	zzzAltura = 3.5,
	zzzTamanho = 1.6,
	zzzCor = Color3.fromRGB(190, 220, 255),
	zzzContorno = Color3.fromRGB(45, 75, 150),
}

local GOZAR = {
	emotes = { Siririca = true },
	delay = 10,
	buildup = 12,
	maxRate = 45,
	minRate = 3,
	partSize = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.14),
		NumberSequenceKeypoint.new(0.4, 0.22),
		NumberSequenceKeypoint.new(1, 0.06),
	}),
	lifetime = NumberRange.new(0.5, 1.1),

	speed = NumberRange.new(0.8, 2.2),
	spread = 10,
	cor = Color3.fromRGB(255, 250, 245),

	texturaParticula = "rbxassetid://128887072856049",

	transparencia = 0.28,

	texturaChao = "rbxassetid://116805447475504",
	pocasMax = 14,
	pocaDuracao = 4.5,
	pocaSpawnInterval = 0.16,
	pocaTamanhoMin = 0.28,
	pocaTamanhoMax = 0.55,

	rubExtra = 0.14,
	rubVelExtra = 5,
	tremor = 0.035,

	soundId = "rbxassetid://122039713538884",
	soundVolume = 0.5,
}

local siriricaTempo = 0
local siriricaSoundPlayed = false

-- Kamehameha: fases por keyframe (tempos em segundos, iguais aos "t" dos frames do emote)
--  fase 1 = KF1 ao KF3  (t 0 ate antes de 0.85): anda normalmente
--  fase 2 = KF4 ao KF9  (t 0.85 ate antes de 2.7): parado + som de recarga
--  fase 3 = KF10 ao KF11 (t 2.7 ate 5): parado + som de disparo
local KAME = {
	ciclo = 5,            -- mesma duracao do emote
	tFase2 = 0.85,        -- tempo do KF4
	tFase3 = 2.7,         -- tempo do KF10
	somRecarga = "rbxassetid://1370232812",
	somDisparo = "rbxassetid://79853512837585",
	volume = 1,

	-- fade dos sons (segundos)
	fadeEntrada = 0.18,   -- sobe o volume no inicio de cada som
	fadeSaida = 0.45,     -- desce o volume antes do fim da fase (nao corta mais seco)
	fadeParar = 0.3,      -- fade ao interromper (emote cancelado / troca de fase)

	-- VFX
	cor = Color3.fromRGB(70, 180, 255),
	corNucleo = Color3.fromRGB(235, 250, 255),
	alcance = 80,         -- tamanho maximo do feixe (studs)
	raio = 3.2,           -- espessura do feixe (studs)
	bolaMax = 3.4,        -- tamanho da esfera de energia carregada
	trailTex = "rbxassetid://6561033515", -- imagem dos mini trails sugados pra bola
	trailQtd = 28,        -- quantidade de mini trails ao mesmo tempo
	trailRaio = 5,        -- distancia de onde os trails comecam (studs)
	trailTransp = 0.35,   -- transparencia inicial do trail (0 = opaco)
	-- camera ao disparar
	camDur = 0.55,        -- duracao do efeito de camera (s)
	fovPuxa = 14,         -- quanto o FOV fecha no disparo (graus), da o efeito de puxar a camera
	camPuxa = 1.2,        -- quanto a camera avanca na direcao do disparo (studs)
	shakeForca = 0.18,    -- tremor da camera (studs)
	shakeAng = 0.012,     -- tremor de rotacao (radianos)
	ventoQtd = 22,        -- riscos de vento em volta do feixe
	ventoCasca = 0.82,    -- transparencia da casca de ar (ForceField) em volta do feixe (1 = some)
	-- fling em quem passar pelo feixe
	flingForca = 250,     -- velocidade empurrando na direcao do feixe (studs/s)
	flingCima = 60,       -- velocidade pra cima (studs/s)
	flingGiro = 30,       -- giro aleatorio (rad/s)
	-- bola mudando de cor (azul -> quase branca ao carregar)
	bolaCorFim = Color3.fromRGB(240, 252, 255),
	-- recuo ao disparar
	recuoVel = 32,        -- velocidade inicial do recuo (studs/s), ~3.4 studs de deslize
	recuoDur = 0.32,      -- duracao do recuo (s)
	-- feixe com textura animada
	feixeTex = "rbxassetid://6561033515", -- troque pelo id da textura de energia que preferir
	feixeTexLen = 6,      -- comprimento (studs) de cada repeticao da textura
	feixeTexVel = 10,     -- velocidade da textura correndo pelo feixe
	-- repulsao das pecas soltas no ponto atingido
	repelRaio = 14,       -- alcance da repulsao (studs)
	repelForca = 90,      -- velocidade de afastamento (studs/s)
	repelGiro = 15,       -- giro aleatorio (rad/s)
	bolaFrente = 0,       -- desloca a bola para frente do ponto entre as maos (0 = exatamente no meio)
	fxEntrada = 0.25,
	fxSaida = 0.4,
}

local Pegar = {
	ativo = false,
	pesado = false,
	usaDireita = false,
	usaEsquerda = false,
	alvoDir = Vector3.new(1.5, 0.6, -2),
	alvoEsq = Vector3.new(-1.5, 0.6, -2),

	massaLeve = 40,
	massaMax = 50000,
	puxarTempo = 0.2,
	somPouso = "rbxassetid://83323788759262",
	volumePouso = 0.3,
	alcance = 2.4,
	lentidaoLeve = 0.9,
	lentidaoPesado = 0.6,
}

local CITACAO_AMP = 0.3
local CITACAO_VEL = 6

local defaultEmotes = {
	["Tchau"] = {
		dir = { x = 4, y = -78, z = 180, px = 0.4, py = 0.3, pz = 0.5 }, palmaDir = { x = 0, y = 0, z = 0 },
		dedosDir = { {0,0}, {0,0}, {0,0}, {0,0}, {0,0} }, afastDir = 0,
		esq = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, palmaEsq = { x = 0, y = 0, z = 0 },
		dedosEsq = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastEsq = 0
	},
	["Paz"] = {
		dir = { x = 43, y = 69, z = 120, px = 0.0, py = -0.6, pz = 0.0 }, palmaDir = { x = 0, y = 0, z = 0 },
		dedosDir = { {53,65}, {0,0}, {0,0}, {85,90}, {85,90} }, afastDir = 20,
		esq = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, palmaEsq = { x = 0, y = 0, z = 0 },
		dedosEsq = { {0,0}, {0,0}, {0,0}, {0,0}, {0,0} }, afastEsq = 0
	},
	["Sim"] = {
		dir = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, palmaDir = { x = 0, y = 0, z = 0 },
		dedosDir = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastDir = 0,
		esq = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, palmaEsq = { x = 0, y = 0, z = 0 },
		dedosEsq = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastEsq = 0
	},
	["Maçaneta"] = {
		dir = { x = 45, y = 29, z = 26, px = 0, py = 0, pz = 0 }, palmaDir = { x = 0, y = 0, z = 0 },
		dedosDir = { {5,70}, {18,71}, {17,72}, {17,71}, {18,70} }, afastDir = 0,
		esq = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, palmaEsq = { x = 0, y = 0, z = 0 },
		dedosEsq = { {15,15}, {15,15}, {15,15}, {15,15}, {15,15} }, afastEsq = 0,
		cabeca = { x = 0, y = 0, z = 0 }, torso = { x = 0, y = 0, z = 0 },
		pernaDir = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, pernaEsq = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }
	},
	["Bow"] = {
		animado = true, duracao = 1, loop = true, suave = true,
		usa = { cabeca = true, torso = true, pernas = true },
		frames = {
			{ t = 0,
				dir = { x = -11, y = 0, z = 165, px = 0.58, py = -1.28, pz = -1.16 }, palmaDir = { x = 0, y = 0, z = -7 },
				dedosDir = { {34,56,-247,10,0,0,0,0}, {6,46}, {0,64}, {8,55}, {10,36} }, afastDir = 0,
				esq = { x = -11, y = 0, z = -165, px = -0.58, py = -1.28, pz = -1.16 }, palmaEsq = { x = 0, y = 0, z = 7 },
				dedosEsq = { {34,56,-247,10,0,0,0,0}, {6,46}, {0,64}, {8,55}, {10,36} }, afastEsq = 0,
				cabeca = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, torso = { x = -16, y = 0, z = 0, px = 0, py = 0, pz = -1.45 },
				pernaDir = { x = 3, y = 21, z = -106, px = 0.37, py = -0.17, pz = 0.16 }, pernaEsq = { x = 3, y = -21, z = 106, px = -0.37, py = -0.17, pz = 0.16 } },
			{ t = 0.3,
				dir = { x = -15.25, y = 12, z = 155, px = 0.66, py = -1.31, pz = -0.94 }, palmaDir = { x = 10, y = 0, z = 0 },
				dedosDir = { {34,56,-247,10,0,0,0,0}, {24,31}, {25,34}, {27,36}, {21,43} }, afastDir = 0,
				esq = { x = -15.25, y = -12, z = -155, px = -0.66, py = -1.31, pz = -0.94 }, palmaEsq = { x = 10, y = 0, z = 0 },
				dedosEsq = { {34,56,-247,10,0,0,0,0}, {24,31}, {25,34}, {27,36}, {21,43} }, afastEsq = 0,
				cabeca = { x = 16, y = 0, z = 0, px = 0, py = -0.15, pz = 0.01 }, torso = { x = -8.87, y = 0, z = 0, px = 0, py = 0.06, pz = -1.45 },
				pernaDir = { x = 3, y = 21, z = -98.87, px = 0.51, py = -0.11, pz = 0.16 }, pernaEsq = { x = 3, y = -21, z = 98.87, px = -0.51, py = -0.11, pz = 0.16 } },
			{ t = 0.6,
				dir = { x = -13, y = 0, z = 165, px = 0.5, py = -1.31, pz = -1.12 }, palmaDir = { x = 0, y = 0, z = 10 },
				dedosDir = { {34,56,-247,10,0,0,0,0}, {41,24}, {36,33.99}, {38,35.99}, {50,23} }, afastDir = 0,
				esq = { x = -27.99, y = 0, z = -165, px = -0.65, py = -1.34, pz = -0.53 }, palmaEsq = { x = 0, y = 0, z = -10 },
				dedosEsq = { {34,56,-247,10,0,0,0,0}, {41,24}, {36,33.99}, {38,35.99}, {50,23} }, afastEsq = 0,
				cabeca = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, torso = { x = -8.87, y = 0, z = 0, px = 0, py = 0.06, pz = -1.45 },
				pernaDir = { x = 3, y = 21, z = -98.87, px = 0.51, py = -0.11, pz = 0.16 }, pernaEsq = { x = 3, y = -21, z = 98.87, px = -0.51, py = -0.11, pz = 0.16 } },
		},
	},
	["Dedo"] = {
		dir = { x = 66, y = 72, z = 107, px = 0.04, py = -0.97, pz = 0 }, palmaDir = { x = 0, y = 4, z = 0 },
		dedosDir = { {60,70}, {90,90}, {0,0}, {90,90}, {90,90} }, afastDir = 0,
		esq = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, palmaEsq = { x = 0, y = 0, z = 0 },
		dedosEsq = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastEsq = 0,
		cabeca = { x = 0, y = 0, z = 0 }, torso = { x = 0, y = 0, z = 0 },
		pernaDir = { x = 0, y = 0, z = 0 }, pernaEsq = { x = 0, y = 0, z = 0 }
	},
	["Citação"] = {
		dir = { x = 0, y = 64, z = 80, px = 0.45, py = -0.24, pz = 0.47 }, palmaDir = { x = 0, y = 90, z = 0 },
		dedosDir = { {90,90}, {0,0}, {90,90}, {90,90}, {90,90} }, afastDir = 0,
		esq = { x = 0, y = -23, z = -80, px = 0, py = 0, pz = 0 }, palmaEsq = { x = 0, y = -90, z = 0 },
		dedosEsq = { {28,31}, {28,60}, {0,0}, {0,0}, {0,0} }, afastEsq = 0,
		cabeca = { x = 0, y = 0, z = 0 }, torso = { x = 0, y = 0, z = 0 },
		pernaDir = { x = 0, y = 0, z = 0 }, pernaEsq = { x = 0, y = 0, z = 0 }
	},
	["Sentido"] = {
		dir = { x = -23, y = -61, z = -42, px = -0.01, py = -0.24, pz = -0.6 }, palmaDir = { x = 0, y = 0, z = 0 },
		dedosDir = { {0,0}, {0,0}, {0,0}, {0,0}, {0,0} }, afastDir = 0,
		esq = { x = -7, y = 61, z = 29, px = 0.27, py = -0.16, pz = -0.39 }, palmaEsq = { x = 0, y = 0, z = 0 },
		dedosEsq = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastEsq = 0,
		cabeca = { x = -19, y = 0, z = 0 }, torso = { x = 13, y = 0, z = 0 },
		pernaDir = { x = 2, y = -20, z = 11 }, pernaEsq = { x = -3, y = 20, z = -11 }
	},
	["Convidando"] = {
		dir = { x = -30, y = 6, z = 110, px = 0.2, py = -0.58, pz = -0.29 }, palmaDir = { x = 0, y = -90, z = 0 },
		dedosDir = { {60,60}, {40,40}, {90,90}, {90,90}, {90,90} }, afastDir = 0,
		esq = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, palmaEsq = { x = 0, y = 0, z = 0 },
		dedosEsq = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastEsq = 0,
		cabeca = { x = 0, y = 0, z = 0 }, torso = { x = 0, y = 0, z = 0 },
		pernaDir = { x = 0, y = 0, z = 0 }, pernaEsq = { x = 0, y = 0, z = 0 }
	},
	["Dancinha"] = {
		dir = { x = -25, y = 0, z = 0, px = 0, py = 0, pz = 0 }, palmaDir = { x = 0, y = 0, z = 0 },
		dedosDir = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastDir = 0,
		esq = { x = -25, y = 0, z = 0, px = 0, py = 0, pz = 0 }, palmaEsq = { x = 0, y = 0, z = 0 },
		dedosEsq = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastEsq = 0,
		cabeca = { x = 0, y = 0, z = -12 }, torso = { x = 0, y = 0, z = 16 },
		pernaDir = { x = 0, y = 0, z = 0 }, pernaEsq = { x = 0, y = 0, z = 0 }
	},
	["Cala a Boca"] = {
		dir = { x = -39, y = -5, z = 144, px = 0.13, py = -1.35, pz = -0.55 }, palmaDir = { x = 0, y = 0, z = 0 },
		dedosDir = { {60,60}, {0,0}, {90,90}, {90,90}, {90,90} }, afastDir = 0,
		esq = { x = 0, y = -15, z = -122, px = 0, py = 0, pz = 0 }, palmaEsq = { x = -2, y = -90, z = 0 },
		dedosEsq = { {20,25}, {40,35}, {40,35}, {40,35}, {40,35} }, afastEsq = 0,
		cabeca = { x = -3, y = 0, z = 0 }, torso = { x = 0, y = 0, z = 0 },
		pernaDir = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, pernaEsq = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }
	},
	["Deitado de Frente"] = {
		dir = { x = -180, y = -118, z = -59, px = 0.21, py = 0, pz = 0 }, palmaDir = { x = 0, y = 0, z = 0 },
		dedosDir = { {15,20}, {25,35}, {25,35}, {25,35}, {25,35} }, afastDir = 0,
		esq = { x = -180, y = 119, z = 39, px = -0.33, py = 0.27, pz = 0 }, palmaEsq = { x = 0, y = 0, z = 0 },
		dedosEsq = { {15,20}, {25,35}, {25,35}, {25,35}, {25,35} }, afastEsq = 0,
		cabeca = { x = -86, y = 0, z = 0 }, torso = { x = 90, y = 0, z = 0 },
		pernaDir = { x = -25, y = 0, z = 15, px = 0, py = 0.3, pz = 0.07 }, pernaEsq = { x = -25, y = 0, z = -13, px = 0, py = 0.3, pz = 0.07 }
	},
	["Sentar"] = {
		dir = { x = -27, y = -2, z = 14, px = 0, py = -0.65, pz = 0 }, palmaDir = { x = 0, y = 0, z = 0 },
		dedosDir = { {10,10,0,0,41,0,0,0}, {10,10,0,0,7,0,0,0}, {10,10,0,0,35,0,0,0}, {10,13,0,0,35,0,0,0}, {0,8,0,0,24,0,0,0} }, afastDir = 0,
		esq = { x = -27, y = 2, z = -14, px = 0, py = -0.65, pz = 0 }, palmaEsq = { x = 0, y = 0, z = 0 },
		dedosEsq = { {10,10,0,0,41,0,0,0}, {10,10,0,0,7,0,0,0}, {10,10,0,0,35,0,0,0}, {10,13,0,0,35,0,0,0}, {0,8,0,0,24,0,0,0} }, afastEsq = 0,
		cabeca = { x = 0, y = 0, z = 0 }, torso = { x = 0, y = 0, z = 0 },
		pernaDir = { x = -4, y = -22, z = 90, px = 0, py = 0, pz = 0 }, pernaEsq = { x = -4, y = 22, z = -90, px = 0, py = 0, pz = 0 }
	},
	["Ajoelhar"] = {
		dir = { x = -6, y = 0, z = 10, px = 0.03, py = -0.22, pz = 0 }, palmaDir = { x = 0, y = 0, z = 0 },
		dedosDir = { {0,9,0,0,-9,0,0,0}, {10,10}, {10,10}, {10,10}, {10,10} }, afastDir = 0,
		esq = { x = -20, y = -46, z = -77, px = -0.17, py = -0.25, pz = 0 }, palmaEsq = { x = 14, y = 1, z = 11 },
		dedosEsq = { {25,23,0,-90,0,0,0,0}, {10,10,0,0,-35,0,0,0}, {10,10,0,0,-39,0,0,0}, {10,10,0,0,-43,0,0,0}, {10,10,0,0,-56,0,0,0} }, afastEsq = 11,
		cabeca = { x = 7, y = -1, z = 4 }, torso = { x = 10, y = 0, z = 0 },
		pernaDir = { x = -2, y = 14, z = -85, px = 1.03, py = -0.36, pz = -0.01 }, pernaEsq = { x = 0, y = -1, z = 7, px = -1.15, py = 1.05, pz = 0 }
	},
	["Dormir"] = {
		animado = true, duracao = 60, loop = true, suave = true,
		usa = { cabeca = true, torso = true, pernas = true },
		frames = {
			{ t = 0,
				dir = { x = -6, y = 0, z = 0, px = 0, py = 0, pz = 0 }, palmaDir = { x = 0, y = 0, z = 0 },
				dedosDir = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastDir = 0,
				esq = { x = -6, y = 0, z = 0, px = 0, py = 0, pz = 0 }, palmaEsq = { x = 0, y = 0, z = 0 },
				dedosEsq = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastEsq = 0,
				cabeca = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, torso = { x = -90, y = 0, z = 0, px = 0, py = 0, pz = 0 },
				pernaDir = { x = -5, y = 0, z = 0, px = 0, py = 0, pz = 0 }, pernaEsq = { x = -5, y = 0, z = 0, px = 0, py = 0, pz = 0 } },
			{ t = 0.3,
				dir = { x = -57, y = -4, z = 190, px = -0.24, py = -0.3, pz = 0.08 }, palmaDir = { x = 0, y = 0, z = 0 },
				dedosDir = { {10,10}, {6,38}, {10,36}, {10,28}, {10,23} }, afastDir = 0,
				esq = { x = -57, y = 4, z = -190, px = 0.24, py = -0.3, pz = 0.08 }, palmaEsq = { x = 0, y = 0, z = 0 },
				dedosEsq = { {10,10}, {6,38}, {10,36}, {10,28}, {10,23} }, afastEsq = 0,
				cabeca = { x = 16, y = 0, z = 0, px = 0, py = -0.06, pz = 0 }, torso = { x = -80, y = 0, z = 0, px = 0, py = 0, pz = 0 },
				pernaDir = { x = -5, y = 0, z = 9, px = 0, py = 0, pz = 0 }, pernaEsq = { x = -5, y = 0, z = -9, px = 0, py = 0, pz = 0 } },
			{ t = 60,
				dir = { x = -57, y = -4, z = 190, px = -0.24, py = -0.3, pz = 0.08 }, palmaDir = { x = 0, y = 0, z = 0 },
				dedosDir = { {10,10}, {6,38}, {10,36}, {10,28}, {10,23} }, afastDir = 0,
				esq = { x = -57, y = 4, z = -190, px = 0.24, py = -0.3, pz = 0.08 }, palmaEsq = { x = 0, y = 0, z = 0 },
				dedosEsq = { {10,10}, {6,38}, {10,36}, {10,28}, {10,23} }, afastEsq = 0,
				cabeca = { x = 16, y = 0, z = 0, px = 0, py = -0.06, pz = 0 }, torso = { x = -80, y = 0, z = 0, px = 0, py = 0, pz = 0 },
				pernaDir = { x = -5, y = 0, z = 9, px = 0, py = 0, pz = 0 }, pernaEsq = { x = -5, y = 0, z = -9, px = 0, py = 0, pz = 0 } },
		},
	},
	["Dormir2"] = {
		dir = { x = 43, y = 67, z = 36, px = 0, py = 0, pz = 0 }, palmaDir = { x = -4, y = 0, z = 0 },
		dedosDir = { {70,90}, {17,13}, {20,10}, {14,19}, {17,29} }, afastDir = 0,
		esq = { x = 56, y = -107, z = -134, px = 0, py = 0, pz = 0 }, palmaEsq = { x = 0, y = 180, z = 1 },
		dedosEsq = { {90,8,-1,-78,-13,0.02,-0.08,0}, {10,22,-26,4,0,0,0,0}, {12,17,-29,9,0,0,0,0}, {14,44,-39,0,0,0,0,0}, {90,90} }, afastEsq = 6,
		cabeca = { x = -6, y = -25, z = 9, px = -0.05, py = 0, pz = 0 }, torso = { x = -78, y = 0, z = 90, px = 0, py = 0, pz = 0 },
		pernaDir = { x = -14, y = 15, z = 19, px = 0.01, py = -0.02, pz = 0.12 }, pernaEsq = { x = 13, y = 0, z = 0, px = 0, py = 0, pz = 0 },
		itens = {
			{ tipo = "acessorio", id = "17135170320", parte = "Left Arm", pos = { x = -0.05, y = -0.41, z = 0.48 }, rot = { x = -36, y = 85, z = 12 }, size = { x = 1, y = 1, z = 1 } },
		}
	},
	["Braços Cruzados"] = {
		dir = { x = -20, y = 60, z = 88, px = 0.23, py = -0.31, pz = -0.29 }, palmaDir = { x = 0, y = 0, z = 0 },
		dedosDir = { {40,50}, {40,50}, {40,50}, {40,50}, {40,50} }, afastDir = 0,
		esq = { x = 0, y = -60, z = -82, px = -0.38, py = -0.35, pz = -0.11 }, palmaEsq = { x = 0, y = 0, z = 0 },
		dedosEsq = { {40,50}, {40,50}, {40,50}, {40,50}, {40,50} }, afastEsq = 0,
		cabeca = { x = -6, y = 8, z = 0 }, torso = { x = 0, y = 0, z = 0 },
		pernaDir = { x = -3, y = -12, z = 0, px = 0, py = 0, pz = 0 }, pernaEsq = { x = -2, y = 14, z = 0, px = 0, py = 0, pz = 0 }
	},
	["Siririca"] = {
		dir = { x = -84, y = 103, z = 98, px = 0.14, py = 0.14, pz = -0.19 }, palmaDir = { x = 10, y = 4, z = 0 },
		dedosDir = { {70,55}, {26,46,17,0,0,0,0,0}, {16,50}, {50,60}, {40,50} }, afastDir = 0,
		esq = { x = 171, y = 180, z = -143, px = 0.61, py = -0.6, pz = -0.36 }, palmaEsq = { x = 0, y = -20, z = -5 },
		dedosEsq = { {27,32,0,0,30,0,0,0}, {0,80,0,0,90,0,0,0}, {0,65,0,0,75,0,0,0}, {0,60,0,0,52,0,0,0}, {0,39,0,0,11,0,0,0} }, afastEsq = 8,
		cabeca = { x = 12, y = -5, z = 0 }, torso = { x = -16, y = 0, z = 0, px = 0, py = 0, pz = -1.15 },
		pernaDir = { x = -19, y = -60, z = -6, px = 0.09, py = 0.86, pz = 0 }, pernaEsq = { x = -19, y = 60, z = 6, px = -0.09, py = 0.91, pz = 0 }
	},

	["Chupada de Dedo"] = {
		dir = { x = 69, y = 96, z = 81, px = 0.05, py = -1.16, pz = -0.39 }, palmaDir = { x = 0, y = 0, z = 0 },
		dedosDir = { {50,55}, {18,63}, {70,80}, {75,85}, {80,90} }, afastDir = 0,
		esq = { x = 19, y = -23, z = -12, px = 0.31, py = -0.02, pz = -0.15 }, palmaEsq = { x = 0, y = 0, z = 0 },
		dedosEsq = { {12,12}, {4,12,-10,0,20,0,0,0}, {12,12,-6,-7,42,0,0,0}, {12,12,-9,-8,39,0,0,0}, {30,9,-5,-23,52,0,0,0} }, afastEsq = 0,
		cabeca = { x = -8, y = 12, z = 0 }, torso = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 },
		pernaDir = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, pernaEsq = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }
	},

	["De Quatro"] = {
		animado = true, duracao = 1, loop = true, suave = true,
		usa = { cabeca = true, torso = true, pernas = true },
		frames = {
			{ t = 0,
				dir = { x = -82, y = -106, z = 74, px = 0.78, py = 0.58, pz = 0.25 }, palmaDir = { x = 0, y = 0, z = -8 },
				dedosDir = { {90,79,0,23,-50,0,0,0}, {90,90,8,2,54,0,0,0}, {90,90,1,1,38,0,0,0}, {90,90,1,4,37,0,0,0}, {90,90,0,6,43,0,0,0} }, afastDir = 0,
				esq = { x = -82, y = 106, z = -74, px = -0.78, py = 0.58, pz = 0.25 }, palmaEsq = { x = 0, y = 0, z = 8 },
				dedosEsq = { {90,79,0,23,-50,0,0,0}, {90,90,8,2,54,0,0,0}, {90,90,1,1,38,0,0,0}, {90,90,1,4,37,0,0,0}, {90,90,0,6,43,0,0,0} }, afastEsq = 0,
				cabeca = { x = -109, y = 0, z = 0, px = 0, py = 0, pz = 0.35 }, torso = { x = 115, y = 0, z = -1, px = 0, py = 0, pz = -0.74 },
				pernaDir = { x = -15, y = -9, z = 117, px = -0.14, py = -0.18, pz = 0.19 }, pernaEsq = { x = -15, y = 9, z = -117, px = 0.14, py = -0.18, pz = 0.19 } },
			{ t = 0.5,
				dir = { x = -90, y = -119, z = 92, px = 0.75, py = 0.85, pz = 0.25 }, palmaDir = { x = 0, y = 0, z = -8 },
				dedosDir = { {90,79,0,23,-50,0,0,0}, {90,90,8,2,54,0,0,0}, {90,90,1,1,38,0,0,0}, {90,90,1,4,37,0,0,0}, {90,90,0,6,43,0,0,0} }, afastDir = 0,
				esq = { x = -90, y = 119, z = -92, px = -0.75, py = 0.85, pz = 0.25 }, palmaEsq = { x = 0, y = 0, z = 8 },
				dedosEsq = { {90,79,0,23,-50,0,0,0}, {90,90,8,2,54,0,0,0}, {90,90,1,1,38,0,0,0}, {90,90,1,4,37,0,0,0}, {90,90,0,6,43,0,0,0} }, afastEsq = 0,
				cabeca = { x = -109, y = 0, z = 0, px = 0, py = 0, pz = 0.35 }, torso = { x = 120.99, y = 0, z = -1, px = 0, py = -0.28, pz = -0.74 },
				pernaDir = { x = -15, y = -9, z = 114.01, px = -0.01, py = -0.18, pz = 0.19 }, pernaEsq = { x = -15, y = 9, z = -114.01, px = 0.01, py = -0.18, pz = 0.19 } },
		},
	},

	["Socar"] = {
		animado = true, duracao = 1, loop = true, suave = true,
		usa = { cabeca = true, torso = true, pernas = true },
		frames = {
			{ t = 0,
				dir = { x = -4, y = 27, z = 50, px = -0.06, py = -0.22, pz = 0.1 }, palmaDir = { x = 0, y = 0, z = 0 },
				dedosDir = { {17,20,0,-14,-64,0,0,0}, {10,17,0,-11,41,0,0,0}, {10,22,-8,-4,39,0,0,0}, {10,34,-16,-11,0,0,0,0}, {10,28,-20,-13,-17,0,0,0} }, afastDir = 0,
				esq = { x = -4, y = -27, z = -50, px = 0.06, py = -0.22, pz = 0.1 }, palmaEsq = { x = 0, y = 0, z = 0 },
				dedosEsq = { {17,22,0,-14,-64,0,0,0}, {10,17,0,-11,41,0,0,0}, {10,26,-8,-4,39,0,0,0}, {10,34,-16,-11,0,0,0,0}, {10,28,-20,-13,-17,0,0,0} }, afastEsq = 0,
				cabeca = { x = -17, y = 0, z = 0, px = 0, py = 0, pz = 0 }, torso = { x = 20, y = 0, z = 0, px = 0, py = 0, pz = 0 },
				pernaDir = { x = -1, y = 1, z = 31, px = 0.02, py = -0.01, pz = 0 }, pernaEsq = { x = -1, y = -1, z = -31, px = -0.02, py = -0.01, pz = 0 } },
			{ t = 0.5,
				dir = { x = -1, y = 33, z = 22, px = 0, py = -0.26, pz = 0 }, palmaDir = { x = 0, y = 0, z = 0 },
				dedosDir = { {10,34,0,0,-71,0,0,0}, {10,26,0,0,35,0,0,0}, {10,22,0,0,27,0,0,0}, {10,34,-25,-7,0,0,0,0}, {10,36,-28,-4,-19,0,0,0} }, afastDir = 0,
				esq = { x = -1, y = -33, z = -22, px = 0, py = -0.26, pz = 0 }, palmaEsq = { x = 0, y = 0, z = 0 },
				dedosEsq = { {10,34,0,0,-71,0,0,0}, {10,26,0,0,35,0,0,0}, {10,22,0,0,27,0,0,0}, {10,34,-25,-7,0,0,0,0}, {10,36,-28,-4,-19,0,0,0} }, afastEsq = 0,
				cabeca = { x = 18, y = 0, z = 0, px = 0, py = 0, pz = 0 }, torso = { x = -11, y = 0, z = 0, px = 0, py = 0, pz = 0 },
				pernaDir = { x = -1, y = 1, z = -14, px = 0, py = -0.03, pz = 0 }, pernaEsq = { x = -1, y = -1, z = 14, px = 0, py = -0.03, pz = 0 } },
		},
	},

	["Kamehameha"] = {
		animado = true, duracao = 5, loop = true, suave = true,
		usa = { cabeca = true, torso = true, pernas = true },
		frames = {
			{ t = 0,
				dir = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, palmaDir = { x = 0, y = 0, z = 0 },
				dedosDir = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastDir = 0,
				esq = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, palmaEsq = { x = 0, y = 0, z = 0 },
				dedosEsq = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastEsq = 0,
				cabeca = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, torso = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 },
				pernaDir = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, pernaEsq = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 } },
			{ t = 0.3,
				dir = { x = 12, y = 31, z = 91, px = 0, py = -0.8, pz = 0 }, palmaDir = { x = 0, y = 0, z = 0 },
				dedosDir = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastDir = 0,
				esq = { x = -23, y = -46, z = -93, px = -0.1, py = -0.26, pz = -0.13 }, palmaEsq = { x = 0, y = 0, z = 0 },
				dedosEsq = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastEsq = 0,
				cabeca = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, torso = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 },
				pernaDir = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, pernaEsq = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 } },
			{ t = 0.6,
				dir = { x = 39, y = -58, z = 83.5, px = -0.61, py = -0.17, pz = -0.58 }, palmaDir = { x = 0, y = 0, z = 0 },
				dedosDir = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastDir = 0,
				esq = { x = -22, y = -124, z = -85.33, px = -0.81, py = -0.52, pz = -1.17 }, palmaEsq = { x = 0, y = 0, z = 0 },
				dedosEsq = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastEsq = 0,
				cabeca = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, torso = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 },
				pernaDir = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 }, pernaEsq = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 } },
			{ t = 0.85,
				dir = { x = 33, y = -55, z = 89, px = -0.65, py = -0.43, pz = -0.67 }, palmaDir = { x = 0, y = 0, z = 0 },
				dedosDir = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastDir = 0,
				esq = { x = -29, y = -122, z = -92, px = -0.81, py = -0.52, pz = -1.17 }, palmaEsq = { x = 0, y = 0, z = 0 },
				dedosEsq = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastEsq = 0,
				cabeca = { x = -8.95, y = -2, z = 25, px = 0, py = 0, pz = 0 }, torso = { x = 11.06, y = 0, z = 0, px = 0, py = 0, pz = 0 },
				pernaDir = { x = -2.11, y = -10.53, z = 1, px = 0.06, py = 0.02, pz = 0.04 }, pernaEsq = { x = 6.32, y = 40, z = -11, px = 0.02, py = 0, pz = 0.02 } },
			{ t = 1.1,
				dir = { x = 33, y = -55, z = 89, px = -0.65, py = -0.43, pz = -0.67 }, palmaDir = { x = 0, y = 0, z = 0 },
				dedosDir = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastDir = 0,
				esq = { x = -29, y = -122, z = -92, px = -0.81, py = -0.52, pz = -1.17 }, palmaEsq = { x = 0, y = 0, z = 0 },
				dedosEsq = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastEsq = 0,
				cabeca = { x = -8.95, y = -2, z = 25, px = 0, py = 0, pz = 0 }, torso = { x = 11.06, y = 0, z = 0, px = 0, py = 0, pz = 0 },
				pernaDir = { x = -2.11, y = -10.53, z = -1, px = 0.06, py = 0.02, pz = 0.04 }, pernaEsq = { x = 6.32, y = 40, z = -39, px = 0.06, py = -0.01, pz = 0.35 } },
			{ t = 1.4,
				dir = { x = 16, y = -58, z = 83.5, px = -0.68, py = -0.67, pz = -0.76 }, palmaDir = { x = 0, y = 0, z = 0 },
				dedosDir = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastDir = 0,
				esq = { x = -22, y = -124, z = -85.33, px = -0.81, py = -0.52, pz = -1.17 }, palmaEsq = { x = 0, y = 0, z = 0 },
				dedosEsq = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastEsq = 0,
				cabeca = { x = -25, y = 0, z = 25, px = 0, py = 0, pz = 0 }, torso = { x = 21, y = 0, z = 0, px = 0, py = 0, pz = 0 },
				pernaDir = { x = -4, y = -20, z = -8, px = 0.12, py = 0.05, pz = 0.08 }, pernaEsq = { x = 12, y = 28, z = -35, px = -0.3, py = 0.02, pz = 0.37 } },
			{ t = 1.5,
				dir = { x = 16, y = -58, z = 83.5, px = -0.68, py = -0.67, pz = -0.76 }, palmaDir = { x = 0, y = 0, z = 0 },
				dedosDir = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastDir = 0,
				esq = { x = -22, y = -124, z = -85.33, px = -0.81, py = -0.52, pz = -1.17 }, palmaEsq = { x = 0, y = 0, z = 0 },
				dedosEsq = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastEsq = 0,
				cabeca = { x = -20, y = 0, z = 25, px = 0, py = 0, pz = 0 }, torso = { x = 21, y = 0, z = 0, px = 0, py = 0, pz = 0 },
				pernaDir = { x = -4, y = -20, z = -30, px = 0.12, py = -0.22, pz = 0 }, pernaEsq = { x = 5, y = 20, z = -35, px = -0.3, py = 0.02, pz = 0.3 } },
			{ t = 1.9,
				dir = { x = 16, y = -58, z = 83.5, px = -0.68, py = -0.67, pz = -0.76 }, palmaDir = { x = 0, y = 0, z = 0 },
				dedosDir = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastDir = 0,
				esq = { x = -22, y = -124, z = -85.33, px = -0.81, py = -0.52, pz = -1.17 }, palmaEsq = { x = 0, y = 0, z = 0 },
				dedosEsq = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastEsq = 0,
				cabeca = { x = -20, y = 0, z = 25, px = 0, py = 0, pz = 0 }, torso = { x = 21, y = 0, z = 0, px = 0, py = 0, pz = 0 },
				pernaDir = { x = -4, y = -20, z = -30, px = 0.12, py = -0.22, pz = 0 }, pernaEsq = { x = 5, y = 20, z = -35, px = -0.3, py = 0.02, pz = 0.3 } },
			{ t = 2.5,
				dir = { x = 12.06, y = -43.73, z = 62.95, px = -0.51, py = -0.51, pz = -0.57 }, palmaDir = { x = 0, y = 0, z = 0 },
				dedosDir = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastDir = 0,
				esq = { x = -16.59, y = -93.48, z = -64.33, px = -0.61, py = -0.39, pz = -0.88 }, palmaEsq = { x = 0, y = 0, z = 0 },
				dedosEsq = { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} }, afastEsq = 0,
				cabeca = { x = -12.82, y = 0, z = 25, px = 0, py = 0, pz = 0 }, torso = { x = 16, y = 0, z = -22, px = 0, py = 0, pz = 0 },
				pernaDir = { x = 7, y = -7, z = -17, px = -0.06, py = -0.27, pz = 0 }, pernaEsq = { x = 4, y = 35, z = -25, px = -0.21, py = 0.19, pz = 0.45 } },
			{ t = 2.7,
				dir = { x = 20, y = 45, z = 100, px = 0.27, py = -0.71, pz = -0.32 }, palmaDir = { x = 0, y = 0, z = 42 },
				dedosDir = { {10,33,0,-87,-57,0,0.05,-0.08}, {10,10}, {10,10}, {10,10}, {10,10} }, afastDir = 0,
				esq = { x = -30, y = -20, z = -105, px = -0.17, py = -0.05, pz = 0.01 }, palmaEsq = { x = 0, y = 0, z = -26 },
				dedosEsq = { {10,33,0,-87,-57,0,0.05,-0.08}, {10,10}, {10,10}, {10,10}, {10,10} }, afastEsq = 0,
				cabeca = { x = -10, y = 0, z = 15, px = 0, py = 0, pz = 0 }, torso = { x = 16, y = 0, z = -5, px = 0, py = 0, pz = 0 },
				pernaDir = { x = 0, y = 1, z = -29, px = 0.01, py = -0.37, pz = 0.17 }, pernaEsq = { x = 4, y = 15, z = -28, px = -0.21, py = 0.11, pz = 0.35 } },
			{ t = 5,
				dir = { x = 20, y = 45, z = 100, px = 0.27, py = -0.71, pz = -0.32 }, palmaDir = { x = 0, y = 0, z = 42 },
				dedosDir = { {10,33,0,-87,-57,0,0.05,-0.08}, {10,10}, {10,10}, {10,10}, {10,10} }, afastDir = 0,
				esq = { x = -30, y = -20, z = -105, px = -0.17, py = -0.05, pz = 0.01 }, palmaEsq = { x = 0, y = 0, z = -26 },
				dedosEsq = { {10,33,0,-87,-57,0,0.05,-0.08}, {10,10}, {10,10}, {10,10}, {10,10} }, afastEsq = 0,
				cabeca = { x = -10, y = 0, z = 15, px = 0, py = 0, pz = 0 }, torso = { x = 16, y = 0, z = -5, px = 0, py = 0, pz = 0 },
				pernaDir = { x = 0, y = 1, z = -29, px = 0.01, py = -0.37, pz = 0.17 }, pernaEsq = { x = 4, y = 15, z = -28, px = -0.21, py = 0.11, pz = 0.35 } },
		},
	},
}

local function poseMaoVazia()
	return {
		braco = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 },
		palma = { x = 0, y = 0, z = 0 },

		dedos = { { 0, 0, 0, 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0, 0, 0, 0 } },
		afastamento = 0,
	}
end

local customPose = {
	itens = {},
	direita = poseMaoVazia(),
	esquerda = poseMaoVazia(),
	torso = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 },
	cabeca = { x = 0, y = 0, z = 0 },
	pernaDir = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 },
	pernaEsq = { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 },
}

local function criarMola(stiffness, damping)
	return {
		x = 0, v = 0, t = 0,
		s = stiffness or 250,
		d = damping or 15,
		update = function(self, dt)
			local f = (self.t - self.x) * self.s - self.v * self.d
			self.v = self.v + f * dt
			self.x = self.x + self.v * dt
			return self.x
		end,
	}
end

local molaBracoDireito = criarMola(250, 15)
local molaBracoEsquerdo = criarMola(250, 15)
local molaCabeca = criarMola(250, 15)
local molaCorpo = criarMola(250, 15)
local molaPernas = criarMola(250, 15)

local PALMA_SIZE = Vector3.new(1, 0.1, 1)

local MESH_DEDO_ID = "rbxassetid://7901148353"
local USAR_MESH_DEDO = true
local meshDedoModelo = nil

local JUNTA_ATIVA = true
local JUNTA_ESCALA = 1.0
local JUNTA_PROFUND = 0.98

local function carregarMeshDedo()
	if not USAR_MESH_DEDO or meshDedoModelo then return end
	local ok, mp = pcall(function()
		return game:GetService("AssetService"):CreateMeshPartAsync(MESH_DEDO_ID)
	end)
	if ok and mp then
		mp.Anchored = false
		mp.CanCollide = false
		mp.CanQuery = false
		mp.CanTouch = false
		mp.Massless = true
		mp.TextureID = ""
		meshDedoModelo = mp
	else
		warn("[Mãos] não consegui carregar a mesh dos dedos, usando o formato antigo:", mp)
	end
end

local function pecaDoMembro(membro, tamanho, isPalma)
	local p
	if isPalma then

		tamanho = Vector3.new(membro.Size.X, tamanho.Y, membro.Size.Z)
	end
	if meshDedoModelo then
		p = meshDedoModelo:Clone()
		p.Name = isPalma and "Palma" or "Dedo"
		p.Size = tamanho
		p.Color = membro.Color
		p.Material = isPalma and Enum.Material.SmoothPlastic or membro.Material
		p.Transparency = 0
		return p
	end
	if membro:IsA("Part") then
		local ok, c = pcall(function() return membro:Clone() end)
		p = ok and c or nil
	end
	if p then
		for _, c in ipairs(p:GetChildren()) do
			if not c:IsA("DataModelMesh") then c:Destroy() end
		end
	else
		p = Instance.new("Part")
	end
	p.Name = isPalma and "Palma" or "Dedo"
	p.Size = tamanho
	p.BrickColor = membro.BrickColor
	p.Material = isPalma and Enum.Material.SmoothPlastic or membro.Material
	p.Transparency = 0
	return p
end

local function juntaDoMembro(membro)
	local function nova()
		local p = Instance.new("WedgePart")
		p.Name = "Junta"
		p.Size = Vector3.new(0.2, 0.01, 0.01)
		p.Color = membro.Color
		p.Material = membro.Material
		p.Transparency = 0
		return p
	end
	return { nova(), nova() }
end

local NOMES_DEDOS = { "Polegar", "Indicador", "Médio", "Anelar", "Mindinho" }

local CONFIG_DEDOS = {
	{ tampBase = Vector3.new(0.24, 0.24, 0.24), tampPonta = Vector3.new(0.24, 0.22, 0.24) },
	{ tampBase = Vector3.new(0.22, 0.29, 0.22), tampPonta = Vector3.new(0.22, 0.26, 0.22) },
	{ tampBase = Vector3.new(0.23, 0.34, 0.23), tampPonta = Vector3.new(0.23, 0.30, 0.23) },
	{ tampBase = Vector3.new(0.22, 0.30, 0.22), tampPonta = Vector3.new(0.22, 0.28, 0.22) },
	{ tampBase = Vector3.new(0.19, 0.24, 0.19), tampPonta = Vector3.new(0.19, 0.22, 0.19) },
}

local CONFIG_POS = {
	Direita = {
		{ pos = Vector3.new(-0.35, -0.05, -0.38), eixo = Vector3.new(0, 0, 1), dir = 1 },
		{ pos = Vector3.new(0.38, -0.05, -0.36), eixo = Vector3.new(0, 0, 1), dir = -1 },
		{ pos = Vector3.new(0.38, -0.05, -0.12), eixo = Vector3.new(0, 0, 1), dir = -1 },
		{ pos = Vector3.new(0.38, -0.05, 0.12), eixo = Vector3.new(0, 0, 1), dir = -1 },
		{ pos = Vector3.new(0.38, -0.05, 0.36), eixo = Vector3.new(0, 0, 1), dir = -1 },
	},
	Esquerda = {
		{ pos = Vector3.new(0.35, -0.05, -0.38), eixo = Vector3.new(0, 0, 1), dir = -1 },
		{ pos = Vector3.new(-0.38, -0.05, -0.36), eixo = Vector3.new(0, 0, 1), dir = 1 },
		{ pos = Vector3.new(-0.38, -0.05, -0.12), eixo = Vector3.new(0, 0, 1), dir = 1 },
		{ pos = Vector3.new(-0.38, -0.05, 0.12), eixo = Vector3.new(0, 0, 1), dir = 1 },
		{ pos = Vector3.new(-0.38, -0.05, 0.36), eixo = Vector3.new(0, 0, 1), dir = 1 },
	},
}

local ANG_AFASTAR = { -45, -18, 0, 18, 40 }

local function afastGraus(id, ehDireito, afastVal)
	local a = (ANG_AFASTAR[id] / 45) * afastVal
	if not ehDireito then a = -a end
	return a
end

local function copiaDedo(t)
	t = t or {}
	return { t[1] or 0, t[2] or 0, t[3] or 0, t[4] or 0, t[5] or 0, t[6] or 0, t[7] or 0, t[8] or 0 }
end

local function dedoTemExtra(t)
	if not t then return false end
	for i = 3, 8 do
		if (t[i] or 0) ~= 0 then return true end
	end
	return false
end

-- ===================== ITENS DO EMOTE (acessórios / roupas / mesh pelo ID) =====================
-- Cada emote pode ter:  itens = { { tipo = "acessorio" | "roupa" | "mesh", id = "123", parte = "Head",
--                                   pos = { x, y, z }, rot = { x, y, z }, size = { x, y, z }, tex = "456" }, ... }
-- parte = Head, Torso, Right Arm, Left Arm, Right Leg ou Left Leg (nomes do R6; no R15 usa a parte equivalente).
-- Acessório: ID do catálogo (usa o Handle; se tiver attachment já encaixa na parte). Roupa 2D (camisa/calça/camiseta):
-- troca a textura enquanto o emote toca. Mesh: MeshId (+ tex = TextureId opcional) vira uma peça com SpecialMesh.
-- Acessório e roupa precisam do game:GetObjects (executor). Tudo é só local (só você vê).
local ItensEmote = { MAX = 12, orig = {} }
ItensEmote.TIPOS = {
	{ id = "acessorio", nome = "Acessório" },
	{ id = "roupa", nome = "Roupa" },
	{ id = "mesh", nome = "Mesh" },
}
ItensEmote.PARTES = {
	{ id = "Head", nome = "Cabeça" }, { id = "Torso", nome = "Torso" },
	{ id = "Right Arm", nome = "Braço D" }, { id = "Left Arm", nome = "Braço E" },
	{ id = "Right Leg", nome = "Perna D" }, { id = "Left Leg", nome = "Perna E" },
}
ItensEmote.ESPELHO = {
	["Right Arm"] = "Left Arm", ["Left Arm"] = "Right Arm",
	["Right Leg"] = "Left Leg", ["Left Leg"] = "Right Leg",
}
function ItensEmote.status(it) end -- a aba Itens do DEV troca isso pra atualizar o texto de status
ItensEmote.aoKind = nil -- idem: a aba Itens redesenha quando descobre que o item é roupa

do
	local TIPO_OK, PARTE_OK = {}, {}
	for _, t in ipairs(ItensEmote.TIPOS) do TIPO_OK[t.id] = true end
	for _, p in ipairs(ItensEmote.PARTES) do PARTE_OK[p.id] = true end
	local R15 = {
		Head = "Head", Torso = "UpperTorso",
		["Right Arm"] = "RightUpperArm", ["Left Arm"] = "LeftUpperArm",
		["Right Leg"] = "RightUpperLeg", ["Left Leg"] = "LeftUpperLeg",
	}

	local function v3(t, padrao, lo, hi)
		t = type(t) == "table" and t or {}
		local function n(v)
			v = tonumber(v)
			if not v or v ~= v then return padrao end
			return clamp(v, lo, hi)
		end
		return { x = n(t.x), y = n(t.y), z = n(t.z) }
	end

	-- copia + valida uma lista de itens (usada ao carregar emote, importar código e desfazer)
	function ItensEmote.copiar(lista)
		local r = {}
		if type(lista) ~= "table" then return r end
		for _, it in ipairs(lista) do
			if type(it) == "table" and #r < ItensEmote.MAX then
				local id = tostring(it.id or ""):match("%d+")
				if id and #id <= 20 then
					local tex = tostring(it.tex or ""):match("%d+")
					r[#r + 1] = {
						tipo = TIPO_OK[it.tipo] and it.tipo or "acessorio",
						id = id,
						parte = PARTE_OK[it.parte] and it.parte or "Head",
						tex = (tex and #tex <= 20) and tex or "",
						pos = v3(it.pos, 0, -50, 50),
						rot = v3(it.rot, 0, -720, 720),
						size = v3(it.size, 1, 0.01, 50),
						kind = (it.kind == "roupa") and "roupa" or nil,
					}
				end
			end
		end
		return r
	end

	-- texto do "itens = { ... }" pros Exportar (nil quando o emote não tem itens)
	function ItensEmote.texto(lista, ind)
		if type(lista) ~= "table" or #lista == 0 then return nil end
		local function f(n)
			n = math.floor((tonumber(n) or 0) * 100 + 0.5) / 100 + 0
			return tostring(n)
		end
		local function v(t) return string.format("{ x = %s, y = %s, z = %s }", f(t.x), f(t.y), f(t.z)) end
		local l = {}
		l[#l + 1] = ind .. "itens = {"
		for _, it in ipairs(lista) do
			local tex = (it.tex and it.tex ~= "") and (' tex = "' .. it.tex .. '",') or ""
			l[#l + 1] = string.format('%s\t{ tipo = "%s", id = "%s", parte = "%s",%s pos = %s, rot = %s, size = %s },',
				ind, it.tipo, it.id, it.parte, tex, v(it.pos), v(it.rot), v(it.size))
		end
		l[#l + 1] = ind .. "}"
		return table.concat(l, "\n")
	end

	function ItensEmote.parteDoChar(char, nome)
		return char:FindFirstChild(nome) or char:FindFirstChild(R15[nome] or "")
	end

	-- ---------- carregar o asset pelo ID (com cache) ----------
	local cache = {}

	local function classificar(obj)
		if obj:IsA("Accessory") then return { kind = "acc", inst = obj } end
		if obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then return { kind = "roupa", inst = obj } end
		if obj:IsA("BasePart") then return { kind = "parte", inst = obj } end
		for _, d in ipairs(obj:GetDescendants()) do
			if d:IsA("Accessory") then return { kind = "acc", inst = d } end
		end
		for _, d in ipairs(obj:GetDescendants()) do
			if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then return { kind = "roupa", inst = d } end
		end
		for _, d in ipairs(obj:GetDescendants()) do
			if d:IsA("BasePart") then return { kind = "parte", inst = d } end
		end
		return nil
	end

	local function carregar(id, cb)
		local c = cache[id]
		if c then
			if c.estado == "carregando" then c.espera[#c.espera + 1] = cb else cb(c.res) end
			return
		end
		c = { estado = "carregando", espera = { cb } }
		cache[id] = c
		task.spawn(function()
			local obj
			local ok, r = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
			if ok and type(r) == "table" then obj = r[1] end
			if not obj then
				local ok2, r2 = pcall(function() return game:GetService("InsertService"):LoadAsset(tonumber(id)) end)
				if ok2 then obj = r2 end
			end
			local res = obj and classificar(obj) or nil
			c.res = res
			c.estado = res and "ok" or "erro"
			local espera = c.espera
			c.espera = nil
			for _, f in ipairs(espera) do pcall(f, res) end
			if not res then
				task.delay(5, function() if cache[id] == c then cache[id] = nil end end)
			end
		end)
	end

	local function limparClone(raiz)
		for _, d in ipairs(raiz:GetDescendants()) do
			if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("BaseScript") or d:IsA("Sound")
				or d:IsA("WrapLayer") or d:IsA("WrapTarget") or d:IsA("Constraint") then
				d:Destroy()
			end
		end
	end

	local function objDe(peca, atts)
		local o = { peca = peca, base = peca.Size, atts = atts, meshes = {} }
		for _, m in ipairs(peca:GetChildren()) do
			if m:IsA("SpecialMesh") then o.meshes[#o.meshes + 1] = { m = m, base = m.Scale } end
		end
		return o
	end

	-- cb(obj, kind): obj = { peca, base, atts, meshes } (peça nova) ou { roupa = Shirt/Pants/ShirtGraphic }; nil se falhou
	function ItensEmote.criar(it, cb)
		if it.tipo == "mesh" then
			local p = Instance.new("Part")
			p.Name = "EMOTEZ_ITEM"
			p.Size = Vector3.new(1, 1, 1)
			local m = Instance.new("SpecialMesh")
			m.MeshType = Enum.MeshType.FileMesh
			m.MeshId = "rbxassetid://" .. it.id
			if it.tex and it.tex ~= "" then m.TextureId = "rbxassetid://" .. it.tex end
			m.Scale = Vector3.new(1, 1, 1)
			m.Parent = p
			cb(objDe(p, nil), "mesh")
			return
		end
		carregar(it.id, function(res)
			if not res then cb(nil, "erro") return end
			if res.kind == "roupa" then cb({ roupa = res.inst }, "roupa") return end
			local h = res.inst
			if res.kind == "acc" then
				h = res.inst:FindFirstChild("Handle")
				if not (h and h:IsA("BasePart")) then
					h = nil
					for _, d in ipairs(res.inst:GetDescendants()) do
						if d:IsA("BasePart") then h = d break end
					end
				end
			end
			if not h then cb(nil, "erro") return end
			h.Archivable = true
			local p = h:Clone()
			if not p then cb(nil, "erro") return end
			local atts = {}
			for _, a in ipairs(p:GetChildren()) do
				if a:IsA("Attachment") then atts[a.Name] = a.CFrame end
			end
			limparClone(p)
			for _, a in ipairs(p:GetChildren()) do
				if a:IsA("Attachment") then a:Destroy() end
			end
			p.Name = "EMOTEZ_ITEM"
			if res.kind == "acc" then cb(objDe(p, atts), "acessorio") else cb(objDe(p, nil), "parte") end
		end)
	end

	function ItensEmote.tamanho(obj, s)
		local v = Vector3.new(clamp(s.x, 0.01, 50), clamp(s.y, 0.01, 50), clamp(s.z, 0.01, 50))
		if obj.ultimo == v then return end
		obj.ultimo = v
		obj.peca.Size = obj.base * v
		for _, mm in ipairs(obj.meshes) do mm.m.Scale = mm.base * v end
	end

	-- troca a textura da camisa/calça/camiseta e devolve a função que desfaz
	local function aplicarRoupa(raiz, modelo, real)
		local classe = modelo.ClassName
		local prop = (classe == "Shirt" and "ShirtTemplate") or (classe == "Pants" and "PantsTemplate") or "Graphic"
		local novo = modelo[prop]
		local orig = ItensEmote.orig
		local atual = raiz:FindFirstChildOfClass(classe)
		if atual then
			local antigo = atual[prop]
			if real then
				if orig[classe] == nil then orig[classe] = antigo end
			elseif orig[classe] ~= nil then
				antigo = (orig[classe] == false) and "" or orig[classe]
			end
			atual[prop] = novo
			return function()
				if atual.Parent then atual[prop] = antigo end
				if real and orig[classe] == antigo then orig[classe] = nil end
			end
		end
		if real and orig[classe] == nil then orig[classe] = false end
		local c = Instance.new(classe)
		c[prop] = novo
		c.Parent = raiz
		return function()
			c:Destroy()
			if real and orig[classe] == false then orig[classe] = nil end
		end
	end

	-- modo "weld": peças coladas (Weld) no personagem de verdade | outro modo: peças ancoradas no boneco do preview
	function ItensEmote.novo(modo, resolver)
		local A = { vivos = {}, assin = "", raiz = nil, ger = 0, undo = {}, pasta = nil, lista = nil }
		local real = (modo == "weld")

		local function limpar()
			A.ger += 1
			for i = #A.undo, 1, -1 do pcall(A.undo[i]) end
			A.undo = {}
			for _, v in pairs(A.vivos) do pcall(function() v.peca:Destroy() end) end
			A.vivos = {}
			if A.pasta then
				pcall(function() A.pasta:Destroy() end)
				A.pasta = nil
			end
			A.assin, A.raiz = "", nil
		end
		A.limpar = limpar

		local function pastaDe()
			if not A.pasta then
				local f = Instance.new("Folder")
				f.Name = "EMOTEZ_ITENS"
				f.Parent = workspace
				A.pasta = f
			end
			return A.pasta
		end

		function A.sincronizar(raiz, lista)
			A.lista = lista
			if not raiz or not raiz.Parent or type(lista) ~= "table" or #lista == 0 then
				if A.raiz ~= nil then limpar() end
				return
			end
			local s = {}
			for i, it in ipairs(lista) do s[i] = it.tipo .. "|" .. it.id .. "|" .. it.parte .. "|" .. (it.tex or "") end
			local assin = table.concat(s, ";")
			if A.raiz == raiz and A.assin == assin then return end

			limpar()
			A.raiz, A.assin = raiz, assin
			local ger = A.ger
			for i, it0 in ipairs(lista) do
				it0.status = "carregando…"
				ItensEmote.status(it0)
				ItensEmote.criar(it0, function(obj, kind)
					if ger ~= A.ger or not raiz.Parent then return end
					local it = (A.lista and A.lista[i]) or it0
					if not obj then
						it.status = "falhou: ID inválido, sem permissão ou executor sem GetObjects"
						ItensEmote.status(it)
						return
					end
					local k0 = it.kind
					it.kind = (kind == "roupa") and "roupa" or nil
					if obj.roupa then
						A.undo[#A.undo + 1] = aplicarRoupa(raiz, obj.roupa, real)
						it.status = "roupa aplicada (textura 2D: sem posição/rotação/tamanho)"
					else
						local body = resolver(raiz, it.parte)
						if not body then
							it.status = "parte do corpo não encontrada"
							ItensEmote.status(it)
							return
						end
						local peca = obj.peca
						peca.Anchored = not real
						peca.CanCollide = false
						peca.CanQuery = false
						peca.CanTouch = false
						peca.Massless = true
						local v = { peca = peca, obj = obj, body = body, base = CFrame.new() }
						if obj.atts then
							for nome, ha in pairs(obj.atts) do
								local b = body:FindFirstChild(nome)
								if b and b:IsA("Attachment") then
									v.base = b.CFrame * ha:Inverse()
									break
								end
							end
						end
						if real then
							local w = Instance.new("Weld")
							w.Part0 = body
							w.Part1 = peca
							w.Parent = peca
							v.weld = w
							peca.Parent = pastaDe()
						else
							peca.Parent = raiz
						end
						A.vivos[i] = v
						it.status = "ok"
					end
					ItensEmote.status(it)
					if k0 ~= it.kind and ItensEmote.aoKind then ItensEmote.aoKind() end
				end)
			end
		end

		function A.atualizar(lista)
			A.lista = lista
			if A.raiz == nil or type(lista) ~= "table" then return end
			for i, v in pairs(A.vivos) do
				local it = lista[i]
				if it and v.peca.Parent then
					ItensEmote.tamanho(v.obj, it.size)
					local p, r = it.pos, it.rot
					local cf = v.base * CFrame.new(p.x, p.y, p.z) * CFrame.Angles(rad(r.x), rad(r.y), rad(r.z))
					if v.weld then v.weld.C0 = cf else v.peca.CFrame = v.body.CFrame * cf end
				end
			end
		end

		return A
	end

	ItensEmote.real = ItensEmote.novo("weld", ItensEmote.parteDoChar)

	function ItensEmote.novoPreview()
		return ItensEmote.novo("preview", function(m, n) return m:FindFirstChild(n) end)
	end

	-- lista que o preview deve mostrar: a do editor (DEV) ou a do emote escolhido no menu
	function ItensEmote.listaPreview(custom, emote)
		if custom then return customPose.itens end
		local d = (type(emote) == "string") and defaultEmotes[emote] or nil
		return d and d.itens or nil
	end
end
-- ==============================================================================================

-- ===================== EMOTES ANIMADOS (keyframes do EMOTE CRIADOR) =====================
-- Cada emote com animado = true tem seus campos dir/esq/dedos/corpo atualizados a cada frame
-- com a pose interpolada dos keyframes. Assim o resto do script lê defaultEmotes[nome] normalmente.
-- De Quatro fica parado no 1o keyframe ate alguem entrar atras (tp). inicio = nil -> parado.
local deQuatroSync = { inicio = nil, pendente = false, fase = 0, ultimo = 0, emote = "Socar" }
local SYNC_ACELERA_APOS = 10   -- segundos ate acelerar
local SYNC_VELOCIDADE = 1.25   -- multiplicador depois disso

local emoteAnimado
do
local emoteAnimInicio = 0
local emoteAnimUltimo = nil

function emoteAnimado(nome)
	local d = nome and defaultEmotes[nome]
	return d ~= nil and d.animado == true
end

local function n6(t)
	t = t or {}
	return { x = t.x or 0, y = t.y or 0, z = t.z or 0, px = t.px or 0, py = t.py or 0, pz = t.pz or 0 }
end

local function n3(t)
	t = t or {}
	return { x = t.x or 0, y = t.y or 0, z = t.z or 0 }
end

local function lerpAnim(a, b, t)
	if type(a) == "number" then
		if type(b) == "number" then return a + (b - a) * t end
		return a
	end
	local r = {}
	for k, v in pairs(a) do
		if b[k] ~= nil then r[k] = lerpAnim(v, b[k], t) else r[k] = v end
	end
	return r
end

local function prepararEmoteAnimado(d)
	d.usa = d.usa or {}
	d.duracao = d.duracao or 1
	for _, f in ipairs(d.frames) do
		f.t = f.t or 0
		f.dir, f.esq = n6(f.dir), n6(f.esq)
		f.palmaDir, f.palmaEsq = n3(f.palmaDir), n3(f.palmaEsq)
		f.cabeca, f.torso = n6(f.cabeca), n6(f.torso)
		f.pernaDir, f.pernaEsq = n6(f.pernaDir), n6(f.pernaEsq)
		f.afastDir, f.afastEsq = f.afastDir or 0, f.afastEsq or 0
		f.dedosDir, f.dedosEsq = f.dedosDir or {}, f.dedosEsq or {}
		for i = 1, 5 do
			f.dedosDir[i] = copiaDedo(f.dedosDir[i])
			f.dedosEsq[i] = copiaDedo(f.dedosEsq[i])
		end
	end
	table.sort(d.frames, function(a, b) return a.t < b.t end)
end

local function amostrarFrame(d, tempo)
	local ks = d.frames
	local n = #ks
	local function suav(u)
		if d.suave then return u * u * (3 - 2 * u) end
		return u
	end
	if n == 1 or tempo <= ks[1].t then return ks[1] end
	local ultimo = ks[n]
	if tempo >= ultimo.t then
		if d.loop and d.duracao > ultimo.t + 0.001 then
			local u = clamp((tempo - ultimo.t) / (d.duracao - ultimo.t), 0, 1)
			return lerpAnim(ultimo, ks[1], suav(u))
		end
		return ultimo
	end
	for i = 1, n - 1 do
		local a, b = ks[i], ks[i + 1]
		if tempo >= a.t and tempo <= b.t then
			local u = (tempo - a.t) / math.max(b.t - a.t, 0.0001)
			return lerpAnim(a, b, suav(u))
		end
	end
	return ultimo
end

KAME.amostrar = amostrarFrame -- usado pelos clones (cada clone tem o proprio relogio)

local function atualizarEmotesAnimados()
	local agora = os.clock()
	if currentEmote ~= emoteAnimUltimo then
		emoteAnimUltimo = currentEmote
		emoteAnimInicio = agora
	end
	if deQuatroSync.pendente and currentEmote == deQuatroSync.emote then
		deQuatroSync.inicio = emoteAnimInicio -- mesmo instante em que o Socar comeca
		deQuatroSync.fase = 0
		deQuatroSync.ultimo = agora
		deQuatroSync.pendente = false
	end
	if deQuatroSync.inicio then
		local dtSync = agora - deQuatroSync.ultimo
		deQuatroSync.ultimo = agora
		local vel = (agora - deQuatroSync.inicio >= SYNC_ACELERA_APOS) and SYNC_VELOCIDADE or 1
		deQuatroSync.fase = deQuatroSync.fase + dtSync * vel
	end
	for nome, d in pairs(defaultEmotes) do
		if d.animado and d.frames and #d.frames > 0 then
			local tempo = agora - ((nome == currentEmote) and emoteAnimInicio or 0)
			if nome == "De Quatro" then
				tempo = deQuatroSync.inicio and deQuatroSync.fase or 0
			elseif nome == "Socar" then
				if deQuatroSync.inicio then
					tempo = deQuatroSync.fase
				elseif currentEmote ~= "Socar" then
					tempo = 0 -- Socar no clone fica parado no 1o keyframe ate o tp
				end
			end
			if d.loop and d.duracao > 0 then
				tempo = tempo % d.duracao
			else
				tempo = clamp(tempo, 0, d.duracao)
			end
			local f = amostrarFrame(d, tempo)
			d.dir, d.esq = f.dir, f.esq
			d.palmaDir, d.palmaEsq = f.palmaDir, f.palmaEsq
			d.dedosDir, d.dedosEsq = f.dedosDir, f.dedosEsq
			d.afastDir, d.afastEsq = f.afastDir, f.afastEsq
			d.cabeca, d.torso = f.cabeca, f.torso
			d.pernaDir, d.pernaEsq = f.pernaDir, f.pernaEsq
		end
	end
end

for _, d in pairs(defaultEmotes) do
	if d.animado and d.frames and #d.frames > 0 then
		prepararEmoteAnimado(d)
		local f = d.frames[1]
		d.dir, d.esq = f.dir, f.esq
		d.palmaDir, d.palmaEsq = f.palmaDir, f.palmaEsq
		d.dedosDir, d.dedosEsq = f.dedosDir, f.dedosEsq
		d.afastDir, d.afastEsq = f.afastDir, f.afastEsq
		d.cabeca, d.torso = f.cabeca, f.torso
		d.pernaDir, d.pernaEsq = f.pernaDir, f.pernaEsq
	end
end

pcall(function() RunService:UnbindFromRenderStep("EmotesAnimados") end)
RunService:BindToRenderStep("EmotesAnimados", Enum.RenderPriority.First.Value, atualizarEmotesAnimados)
end
-- =========================================================================================

-- ===================== PONTE EMOTEZ+HANDS -> EMOTE CRIADOR =====================
-- Deixa o EMOTE CRIADOR listar e puxar qualquer emote daqui (parado ou animado),
-- sem copiar/colar. Funciona quando os dois scripts rodam na mesma sessão do executor.
do
	local function f2(n)
		n = math.floor((tonumber(n) or 0) * 100 + 0.5) / 100 + 0
		return tostring(n)
	end
	local function v3s(t)
		t = t or {}
		return string.format("{ x = %s, y = %s, z = %s }", f2(t.x), f2(t.y), f2(t.z))
	end
	local function b6s(t)
		t = t or {}
		return string.format("{ x = %s, y = %s, z = %s, px = %s, py = %s, pz = %s }",
			f2(t.x), f2(t.y), f2(t.z), f2(t.px), f2(t.py), f2(t.pz))
	end
	local function dedosS(lista)
		local s = {}
		for i = 1, 5 do
			local d = copiaDedo(lista and lista[i])
			if dedoTemExtra(d) then
				s[i] = string.format("{%s,%s,%s,%s,%s,%s,%s,%s}", f2(d[1]), f2(d[2]), f2(d[3]), f2(d[4]), f2(d[5]), f2(d[6]), f2(d[7]), f2(d[8]))
			else
				s[i] = string.format("{%s,%s}", f2(d[1]), f2(d[2]))
			end
		end
		return "{ " .. table.concat(s, ", ") .. " }"
	end
	local function linhasPose(d, ind)
		return string.format(
			"%sdir = %s, palmaDir = %s,\n%sdedosDir = %s, afastDir = %s,\n%sesq = %s, palmaEsq = %s,\n%sdedosEsq = %s, afastEsq = %s,\n%scabeca = %s, torso = %s,\n%spernaDir = %s, pernaEsq = %s",
			ind, b6s(d.dir), v3s(d.palmaDir),
			ind, dedosS(d.dedosDir), f2(d.afastDir),
			ind, b6s(d.esq), v3s(d.palmaEsq),
			ind, dedosS(d.dedosEsq), f2(d.afastEsq),
			ind, b6s(d.cabeca), b6s(d.torso),
			ind, b6s(d.pernaDir), b6s(d.pernaEsq))
	end
	local function emoteParaTexto(nome, d)
		local nm = tostring(nome):gsub('"', "'")
		if d.animado and d.frames and #d.frames > 0 then
			local u = d.usa or {}
			local l = {}
			l[#l + 1] = string.format('["%s"] = {', nm)
			l[#l + 1] = string.format("\tanimado = true, duracao = %s, loop = %s, suave = %s,", f2(d.duracao or 1), tostring(d.loop == true), tostring(d.suave == true))
			l[#l + 1] = string.format("\tusa = { cabeca = %s, torso = %s, pernas = %s },", tostring(u.cabeca == true), tostring(u.torso == true), tostring(u.pernas == true))
			local itensTxt = ItensEmote.texto(d.itens, "\t")
			if itensTxt then l[#l + 1] = itensTxt .. "," end
			l[#l + 1] = "\tframes = {"
			for _, f in ipairs(d.frames) do
				l[#l + 1] = string.format("\t\t{ t = %s,", f2(f.t))
				l[#l + 1] = linhasPose(f, "\t\t\t") .. " },"
			end
			l[#l + 1] = "\t},"
			l[#l + 1] = "},"
			return table.concat(l, "\n")
		end
		local corpo = linhasPose(d, "\t")
		local itensTxt = ItensEmote.texto(d.itens, "\t")
		if itensTxt then corpo = corpo .. ",\n" .. itensTxt end
		return string.format('["%s"] = {\n%s\n},', nm, corpo)
	end

	local e = (getgenv and getgenv()) or _G
	e.EMOTEZ_PONTE = {
		listar = function()
			local n = {}
			for nome, d in pairs(defaultEmotes) do
				if type(d) == "table" and (d.dir or d.frames) then n[#n + 1] = nome end
			end
			table.sort(n)
			return n
		end,
		animado = function(nome)
			local d = defaultEmotes[nome]
			return d ~= nil and d.animado == true
		end,
		texto = function(nome)
			local d = defaultEmotes[nome]
			if not d then return nil end
			return emoteParaTexto(nome, d)
		end,
	}
end
-- ===============================================================================

local function extraDedoEmote(emote, id, ehDireito, frame)
	local d = frame or (emote and defaultEmotes[emote])
	if not d then return nil end
	local lista = ehDireito and d.dedosDir or d.dedosEsq
	return lista and lista[id] or nil
end

local function calcFingerCFrames(id, ehDireito, angBase, angPonta, afastDeg, ext)
	local c = CONFIG_DEDOS[id]
	local l = (ehDireito and CONFIG_POS.Direita or CONFIG_POS.Esquerda)[id]
	local radBase = rad(angBase * l.dir)
	local radPonta = rad(angPonta * l.dir)
	local rot = CFrame.fromAxisAngle(l.eixo, radBase)
	if afastDeg and afastDeg ~= 0 then
		rot = CFrame.Angles(rad(afastDeg), 0, 0) * rot
	end
	local origem = l.pos
	if ext then
		local m = ehDireito and 1 or -1
		local rx, ry, rz = ext[3] or 0, ext[4] or 0, ext[5] or 0
		local px, py, pz = ext[6] or 0, ext[7] or 0, ext[8] or 0
		origem = l.pos + Vector3.new(px * m, py, pz)
		rot = CFrame.Angles(rad(rx), rad(ry * m), rad(rz * m)) * rot
	end
	local baseCF = CFrame.new(origem) * rot * CFrame.new(0, -c.tampBase.Y / 2, 0)
	local pivot = baseCF * CFrame.new(0, -c.tampBase.Y / 2, 0)
	local pontaCF = pivot * CFrame.fromAxisAngle(l.eixo, radPonta) * CFrame.new(0, -c.tampPonta.Y / 2, 0)
	return baseCF, pontaCF, pivot
end

local function calcJuntaCFrames(id, ehDireito, angPonta, pivotCF)
	local c = CONFIG_DEDOS[id]
	local l = (ehDireito and CONFIG_POS.Direita or CONFIG_POS.Esquerda)[id]
	local th = rad(angPonta * l.dir)
	th = clamp(th, rad(-170), rad(170))
	local lado = (th > 0) and -1 or 1
	local r = (c.tampBase.X / 2) * JUNTA_ESCALA
	local prof = c.tampBase.Z * JUNTA_PROFUND

	local P = Vector3.new(0, 0, 0)
	local A = Vector3.new(lado * r, 0, 0)
	local C = Vector3.new(lado * r * cos(th), lado * r * sin(th), 0)
	local M = (A + C) / 2

	local back = (M - P).Unit
	local perp = Vector3.new(-back.Y, back.X, 0)
	local up1 = ((A - M):Dot(perp) >= 0) and perp or -perp
	local up2 = -up1

	local a = (M - P).Magnitude
	local b = (A - M).Magnitude
	a, b = math.max(a, 0.001), math.max(b, 0.001)

	local cf1 = pivotCF * CFrame.fromMatrix((A + P) / 2, up1:Cross(back), up1, back)
	local cf2 = pivotCF * CFrame.fromMatrix((C + P) / 2, up2:Cross(back), up2, back)
	return cf1, Vector3.new(prof, b, a), cf2, Vector3.new(prof, b, a)
end

local function alvoDedosEmote(emote, id, ehDireito, frame)
	if emoteAnimado(emote) then
		local d = frame or defaultEmotes[emote]
		local f = (ehDireito and d.dedosDir or d.dedosEsq)[id]
		return f[1], f[2]
	elseif emote == "Tchau" then
		return math.random(-5, 5), 0
	elseif emote == "Paz" then
		if id == 1 then
			return 53, 65
		elseif ehDireito and (id == 2 or id == 3) then
			return 0, 0
		end
		return 85, 90
	elseif emote == "Apontar" then
		if id == 2 and ehDireito then return 0, 0 end
		return 90, 90
	elseif emote == "Bow" then
		return 30, 80
	elseif emote == "Dancinha" then
		return 10, 10
	elseif emote == "Cala a Boca" then
		if ehDireito then

			if id == 2 then return 0, 0 end
			if id == 1 then return 60, 60 end
			return 90, 90
		end

		local k = 0.5 + 0.5 * sin(tick() * 10)
		if id == 1 then return 10 + 25 * k, 10 + 25 * k end
		return 5 + 55 * k, 5 + 45 * k
	elseif emote == "Braços Cruzados" then
		local d = defaultEmotes["Braços Cruzados"]
		local f = (ehDireito and d.dedosDir or d.dedosEsq)[id]
		return f[1], f[2]
	elseif emote == "Maçaneta" or emote == "Deitado de Frente" or emote == "Sentar" or emote == "Ajoelhar" or emote == "Dormir" or emote == "Dormir2"
		or emote == "De Quatro" or emote == "Socar" then

		local d = defaultEmotes[emote]
		local f = (ehDireito and d.dedosDir or d.dedosEsq)[id]
		return f[1], f[2]
	elseif emote == "Chupada de Dedo" then

		local d = defaultEmotes["Chupada de Dedo"]
		local f = (ehDireito and d.dedosDir or d.dedosEsq)[id]
		if ehDireito and id == 2 then
			local k = 0.5 + 0.5 * sin(tick() * 7)
			return (f[1] or 18) + 6 * k, (f[2] or 63) + 4 * k
		end
		return f[1], f[2]
	elseif emote == "Dedo" then
		if not ehDireito then return 10, 10 end
		if id == 3 then return 0, 0 end
		if id == 1 then return 60, 70 end
		return 90, 90
	elseif emote == "Citação" then
		if ehDireito then
			if id == 2 then return 0, 0 end
			return 90, 90
		end

		if id == 1 then return 28, 31 end
		if id == 2 then return 28, 60 end
		return 0, 0
	elseif emote == "Sentido" then
		if not ehDireito then return 10, 10 end
		return 0, 0
	elseif emote == "Convidando" then
		if not ehDireito then return 10, 10 end
		if id == 2 then
			local c = 40 + 40 * sin(tick() * 8)
			return c, c
		elseif id == 1 then
			return 60, 60
		end
		return 90, 90
	elseif emote == "Siririca" then
		local d = defaultEmotes["Siririca"]
		local f = (ehDireito and d.dedosDir or d.dedosEsq)[id]
		if not ehDireito then return f[1], f[2] end

		local inten = 0
		if siriricaTempo > GOZAR.delay then
			inten = clamp((siriricaTempo - GOZAR.delay) / GOZAR.buildup, 0, 1)
		end
		local vel = 9 + GOZAR.rubVelExtra * inten
		local k = 0.5 + 0.5 * sin(tick() * vel)
		local ampBase = 12 + 10 * inten
		local ampPonta = 10 + 8 * inten
		if id == 2 or id == 3 then
			return f[1] + ampBase * k, f[2] + ampPonta * k
		end
		return f[1], f[2]
	end
	return nil
end

local function poseVazia()
	return {
		wR = 0, wL = 0, wN = 0, wB = 0, wP = 0,
		R = CFrame.new(), L = CFrame.new(), N = CFrame.new(), B = CFrame.new(),
		PR = CFrame.new(), PL = CFrame.new(),
	}
end

local function cfBraco(p)
	return CFrame.new(p.px, p.py, p.pz) * CFrame.Angles(rad(p.x), rad(p.y), rad(p.z))
end

local function cfRot(p)
	return CFrame.new(p.px or 0, p.py or 0, p.pz or 0) * CFrame.Angles(rad(p.x), rad(p.y), rad(p.z))
end

local function cfPerna(p)
	return CFrame.new(p.px or 0, p.py or 0, p.pz or 0) * CFrame.Angles(rad(p.x), rad(p.y), rad(p.z))
end

local C0_R6 = {
	root = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	neck = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	rs = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	ls = CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	rh = CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	lh = CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
}

local function fixaNoMundo(c0, T, D)
	local R = C0_R6.root
	return c0:Inverse() * R * D:Inverse() * R:Inverse() * c0 * T
end

local function calcularPoseCustom()
	local P = poseVazia()
	if animConfig.direita then
		P.wR = 1
		P.R = cfBraco(customPose.direita.braco)
	end
	if animConfig.esquerda then
		P.wL = 1
		P.L = cfBraco(customPose.esquerda.braco)
	end
	if animConfig.cabeca then
		P.wN = 1
		P.N = cfRot(customPose.cabeca)
	end
	if animConfig.torso then
		P.wB = 1
		P.B = cfPerna(customPose.torso)
	end
	if animConfig.pernas then
		P.wP = 1
		P.PR = cfPerna(customPose.pernaDir)
		P.PL = cfPerna(customPose.pernaEsq)
	end
	return P
end

local function calcularPoseEmote(emote, tempo, usar, frame)
	local P = poseVazia()
	local dirOn = (not usar) or animConfig.direita
	local esqOn = (not usar) or animConfig.esquerda

	if emoteAnimado(emote) then
		local d0 = defaultEmotes[emote]
		local d = frame or d0
		local u = d0.usa or {}
		if dirOn then
			P.wR = 1
			P.R = cfBraco(d.dir)
		end
		if esqOn then
			P.wL = 1
			P.L = cfBraco(d.esq)
		end
		if u.cabeca then
			P.wN = 1
			P.N = cfRot(d.cabeca)
		end
		if u.torso then
			P.wB = 1
			P.B = cfPerna(d.torso)
		end
		if u.pernas then
			P.wP = 1
			P.PR = cfPerna(d.pernaDir)
			P.PL = cfPerna(d.pernaEsq)
		end
	elseif emote == "Tchau" then
		if dirOn then
			P.wR = 1
			P.R = CFrame.new(0.4, 0.3, 0.5) * CFrame.Angles(rad(4), rad(-78), rad(180) + rad(30) * sin(tempo * 12))
		end
	elseif emote == "Paz" then
		if dirOn then
			P.wR = 1
			P.R = CFrame.new(0.0, -0.6, 0.0) * CFrame.Angles(rad(43), rad(69), rad(120))
		end
	elseif emote == "Sim" then
		if dirOn then
			P.wN = 1
			P.N = CFrame.Angles(rad(22) * sin(tempo * 10), 0, 0)
		end
	elseif emote == "Maçaneta" then

		local d = defaultEmotes["Maçaneta"]
		if dirOn then
			P.wR = 1
			P.R = cfBraco(d.dir) * CFrame.Angles(0, 0, rad(20) * sin(tempo * 12))
		end
	elseif emote == "Apontar" then
		if dirOn then
			P.wR = 1
			P.R = CFrame.Angles(0, 0, rad(90))
		end
	elseif emote == "Dedo" then
		if dirOn then
			P.wR = 1
			P.R = CFrame.new(0.04, -0.97, 0) * CFrame.Angles(rad(66), rad(72), rad(107))
		end
	elseif emote == "Citação" then
		if dirOn then
			P.wR = 1
			P.R = CFrame.new(0.45, -0.24, 0.47 + CITACAO_AMP * sin(tempo * CITACAO_VEL)) * CFrame.Angles(0, rad(64), rad(80))
		end
		if esqOn then
			P.wL = 1
			P.L = CFrame.Angles(0, rad(-23), rad(-80))
		end
	elseif emote == "Sentido" then
		if dirOn then
			P.wR = 1
			P.R = CFrame.new(-0.01, -0.24, -0.6) * CFrame.Angles(rad(-23), rad(-61), rad(-42))
		end
		if esqOn then
			P.wL = 1
			P.L = CFrame.new(0.27, -0.16, -0.39) * CFrame.Angles(rad(-7), rad(61), rad(29))
		end
		P.wN = 1
		P.wB = 1
		P.wP = 1
		P.N = CFrame.Angles(rad(-19), 0, 0)
		P.B = CFrame.Angles(rad(13), 0, 0)
		P.PR = CFrame.Angles(rad(2), rad(-20), rad(11))
		P.PL = CFrame.Angles(rad(-3), rad(20), rad(-11))
	elseif emote == "Convidando" then
		if dirOn then
			P.wR = 1
			P.R = CFrame.new(0.2, -0.58, -0.29) * CFrame.Angles(rad(-30), rad(6), rad(110))
		end
	elseif emote == "Dancinha" then
		local s, c = sin(tempo * 5), cos(tempo * 5)
		if dirOn then
			P.wR = 1
			P.R = CFrame.Angles(rad(-25 - 8 * s), 0, 0)
		end
		if esqOn then
			P.wL = 1
			P.L = CFrame.Angles(rad(-25 + 8 * s), 0, 0)
		end
		P.wN = 1
		P.wB = 1
		P.wP = 1
		P.B = CFrame.Angles(0, rad(10 * s), rad(16 * c))
		P.N = CFrame.Angles(0, rad(-6 * s), rad(-12 * c))
		P.PR = CFrame.Angles(rad(7 * s), 0, 0)
		P.PL = CFrame.Angles(rad(-7 * s), 0, 0)
	elseif emote == "Cala a Boca" then

		local d = defaultEmotes["Cala a Boca"]
		if dirOn then
			P.wR = 1
			P.R = cfBraco(d.dir)
		end
		if esqOn then
			P.wL = 1
			P.L = cfBraco(d.esq)
		end
		P.wN = 1
		P.N = CFrame.new(d.cabeca.px or 0, d.cabeca.py or 0, d.cabeca.pz or 0) * CFrame.Angles(rad(d.cabeca.x + 3 * sin(tempo * 10)), rad(d.cabeca.y), rad(d.cabeca.z))
	elseif emote == "Braços Cruzados" then

		local d = defaultEmotes["Braços Cruzados"]
		if dirOn then
			P.wR = 1
			P.R = cfBraco(d.dir)
		end
		if esqOn then
			P.wL = 1
			P.L = cfBraco(d.esq)
		end
		P.wN = 1
		P.wP = 1
		P.N = cfRot(d.cabeca)
		P.PR = cfPerna(d.pernaDir)
		P.PL = cfPerna(d.pernaEsq)
	elseif emote == "Deitado de Frente" then

		local d = defaultEmotes["Deitado de Frente"]
		if dirOn then
			P.wR = 1
			P.R = cfBraco(d.dir)
		end
		if esqOn then
			P.wL = 1
			P.L = cfBraco(d.esq)
		end
		P.wN = 1
		P.wB = 1
		P.wP = 1
		P.N = cfRot(d.cabeca)
		P.B = cfPerna(d.torso)
		P.PR = cfPerna(d.pernaDir)
		P.PL = cfPerna(d.pernaEsq)
	elseif emote == "Sentar" or emote == "Ajoelhar" or emote == "Dormir" or emote == "Dormir2" then

		local d = defaultEmotes[emote]
		if dirOn then
			P.wR = 1
			P.R = cfBraco(d.dir)
		end
		if esqOn then
			P.wL = 1
			P.L = cfBraco(d.esq)
		end
		P.wN = 1
		P.wB = 1
		P.wP = 1

		local respiro = (emote == "Sentar") and rad(1.5 * sin(tempo * 1.6)) or 0
		P.N = cfRot(d.cabeca) * CFrame.Angles(respiro, 0, 0)
		P.B = cfPerna(d.torso)
		P.PR = cfPerna(d.pernaDir)
		P.PL = cfPerna(d.pernaEsq)
	elseif emote == "Bow" then

		local d = defaultEmotes["Bow"]
		if dirOn then
			P.wR = 1
			P.R = cfBraco(d.dir)
		end
		if esqOn then
			P.wL = 1
			P.L = cfBraco(d.esq)
		end
		P.wN = 1
		P.wB = 1
		P.wP = 1
		local bob = sin(tempo * 7.2) * 26
		P.N = cfRot(d.cabeca) * CFrame.Angles(rad(-bob), rad(8 * sin(tempo * 4)), 0)
		P.B = cfPerna(d.torso) * CFrame.Angles(0, 0, rad(8 * cos(tempo * 2.5)))
		P.PR = cfPerna(d.pernaDir)
		P.PL = cfPerna(d.pernaEsq)
	elseif emote == "Siririca" then

		local d = defaultEmotes["Siririca"]
		local inten = 0
		if siriricaTempo > GOZAR.delay then
			inten = clamp((siriricaTempo - GOZAR.delay) / GOZAR.buildup, 0, 1)
		end
		if dirOn then
			P.wR = 1
			local amp = 0.06 + GOZAR.rubExtra * inten
			local vel = 9 + GOZAR.rubVelExtra * inten
			local rub = amp * sin(tempo * vel)
			P.R = CFrame.new(d.dir.px, d.dir.py + rub, d.dir.pz) * CFrame.Angles(rad(d.dir.x), rad(d.dir.y), rad(d.dir.z))
		end
		if esqOn then
			P.wL = 1
			P.L = cfBraco(d.esq)
		end
		P.wN = 1
		P.wB = 1
		P.wP = 1

		local tr = GOZAR.tremor * inten
		local shakeX = tr * sin(tempo * 22)
		local shakeZ = tr * cos(tempo * 18)
		P.N = cfRot(d.cabeca) * CFrame.Angles(shakeX * 1.4, 0, shakeZ)
		P.B = cfPerna(d.torso) * CFrame.Angles(shakeX * 0.6, 0, shakeZ * 0.8)
		P.PR = cfPerna(d.pernaDir)
		P.PL = cfPerna(d.pernaEsq)
	elseif emote == "Chupada de Dedo" then
		local d = defaultEmotes["Chupada de Dedo"]
		if dirOn then
			P.wR = 1
			P.R = cfBraco(d.dir)
		end
		if esqOn then
			P.wL = 1
			P.L = cfBraco(d.esq)
		end
		P.wN = 1

		P.N = cfRot(d.cabeca) * CFrame.Angles(rad(3 * sin(tempo * 7)), rad(2 * cos(tempo * 5)), 0)
	elseif emote == "De Quatro" then
		local d = defaultEmotes["De Quatro"]

		local SWAY_YAW, SWAY_ROLL = 0, 0
		local D = CFrame.Angles(0, rad(SWAY_YAW * sin(tempo * 4.2)), rad(SWAY_ROLL * cos(tempo * 3)))
		if dirOn then
			P.wR = 1
			P.R = fixaNoMundo(C0_R6.rs, cfBraco(d.dir), D)
		end
		if esqOn then
			P.wL = 1
			P.L = fixaNoMundo(C0_R6.ls, cfBraco(d.esq), D)
		end
		P.wN = 1
		P.wB = 1
		P.wP = 1
		P.N = cfRot(d.cabeca)
		P.B = cfPerna(d.torso) * D
		P.PR = fixaNoMundo(C0_R6.rh, cfPerna(d.pernaDir), D)
		P.PL = fixaNoMundo(C0_R6.lh, cfPerna(d.pernaEsq), D)
	elseif emote == "Socar" then

		local d = defaultEmotes["Socar"]
		local t = tempo * 8.2
		local s = sin(t)
		local c = cos(t)
		local thrust = 0.48 * s
		local bob = 0.07 * c
		local pitch = rad(8 * s)
		local roll = rad(2.5 * c)
		local D = CFrame.new(0, bob, thrust) * CFrame.Angles(pitch, 0, roll)

		local spring = sin(t - 0.35)
		local springC = cos(t - 0.35)
		local legCompress = 0.055 * spring
		local legBend = rad(6 * spring)
		local legPush = 0.04 * spring
		local legRoll = rad(1.8 * springC)

		if dirOn then
			P.wR = 1
			P.R = fixaNoMundo(C0_R6.rs, cfBraco(d.dir), D)
		end
		if esqOn then
			P.wL = 1
			P.L = fixaNoMundo(C0_R6.ls, cfBraco(d.esq), D)
		end
		P.wN = 1
		P.wB = 1
		P.wP = 1

		P.N = cfRot(d.cabeca) * CFrame.Angles(rad(7 * s), rad(3 * c), 0)
		P.B = cfPerna(d.torso) * D

		local legExtraR = CFrame.new(0.02 * spring, legCompress, legPush) * CFrame.Angles(legBend, 0, legRoll)
		local legExtraL = CFrame.new(-0.02 * spring, legCompress, legPush) * CFrame.Angles(legBend, 0, -legRoll)
		P.PR = fixaNoMundo(C0_R6.rh, cfPerna(d.pernaDir) * legExtraR, D)
		P.PL = fixaNoMundo(C0_R6.lh, cfPerna(d.pernaEsq) * legExtraL, D)
	end
	return P
end

local function ligarCorpoDev(P, cabeca, torso, pernas)
	local cp = customPose
	if cabeca then P.wN = 1; P.N = cfRot(cp.cabeca) end
	if torso then P.wB = 1; P.B = cfPerna(cp.torso) end
	if pernas then
		P.wP = 1
		P.PR = cfPerna(cp.pernaDir)
		P.PL = cfPerna(cp.pernaEsq)
	end
end

local function calcularPoseCustomAnimada(emote, tempo)
	local P = calcularPoseCustom()
	if not emote then return P end
	local cp = customPose
	local dirOn, esqOn = animConfig.direita, animConfig.esquerda

	if emote == "Tchau" then
		if dirOn then
			P.R = cfBraco(cp.direita.braco) * CFrame.Angles(0, 0, rad(30) * sin(tempo * 12))
		end
	elseif emote == "Maçaneta" then
		if dirOn then
			P.R = cfBraco(cp.direita.braco) * CFrame.Angles(0, 0, rad(20) * sin(tempo * 12))
		end
	elseif emote == "Citação" then
		if dirOn then
			P.R = CFrame.new(0, 0, CITACAO_AMP * sin(tempo * CITACAO_VEL)) * cfBraco(cp.direita.braco)
		end
	elseif emote == "Sim" then
		ligarCorpoDev(P, true, false, false)
		P.N = cfRot(cp.cabeca) * CFrame.Angles(rad(22) * sin(tempo * 10), 0, 0)
	elseif emote == "Dancinha" then

		local s, c = sin(tempo * 5), cos(tempo * 5)
		ligarCorpoDev(P, true, true, true)
		if dirOn then P.R = cfBraco(cp.direita.braco) * CFrame.Angles(rad(-8 * s), 0, 0) end
		if esqOn then P.L = cfBraco(cp.esquerda.braco) * CFrame.Angles(rad(8 * s), 0, 0) end
		local t, h = cp.torso, cp.cabeca
		P.B = CFrame.new(t.px or 0, t.py or 0, t.pz or 0) * CFrame.Angles(rad(t.x), rad(t.y + 10 * s), rad(t.z * c))
		P.N = CFrame.new(h.px or 0, h.py or 0, h.pz or 0) * CFrame.Angles(rad(h.x), rad(h.y - 6 * s), rad(h.z * c))
		P.PR = cfPerna(cp.pernaDir) * CFrame.Angles(rad(7 * s), 0, 0)
		P.PL = cfPerna(cp.pernaEsq) * CFrame.Angles(rad(-7 * s), 0, 0)
	elseif emote == "Cala a Boca" then
		ligarCorpoDev(P, true, false, false)
		P.N = cfRot(cp.cabeca) * CFrame.Angles(rad(3 * sin(tempo * 10)), 0, 0)
	elseif emote == "Sentar" then
		ligarCorpoDev(P, true, true, true)
		P.N = cfRot(cp.cabeca) * CFrame.Angles(rad(1.5 * sin(tempo * 1.6)), 0, 0)
	elseif emote == "Bow" then
		ligarCorpoDev(P, true, true, true)
		local bob = sin(tempo * 7.2) * 26
		P.N = cfRot(cp.cabeca) * CFrame.Angles(rad(-bob), rad(8 * sin(tempo * 4)), 0)
		P.B = cfPerna(cp.torso) * CFrame.Angles(0, 0, rad(8 * cos(tempo * 2.5)))
	elseif emote == "Siririca" then
		local inten = 0
		if siriricaTempo > GOZAR.delay then
			inten = clamp((siriricaTempo - GOZAR.delay) / GOZAR.buildup, 0, 1)
		end
		ligarCorpoDev(P, true, true, true)
		if dirOn then
			local amp = 0.06 + GOZAR.rubExtra * inten
			local vel = 9 + GOZAR.rubVelExtra * inten
			P.R = CFrame.new(0, amp * sin(tempo * vel), 0) * cfBraco(cp.direita.braco)
		end
		local tr = GOZAR.tremor * inten
		local shakeX, shakeZ = tr * sin(tempo * 22), tr * cos(tempo * 18)
		P.N = cfRot(cp.cabeca) * CFrame.Angles(shakeX * 1.4, 0, shakeZ)
		P.B = cfPerna(cp.torso) * CFrame.Angles(shakeX * 0.6, 0, shakeZ * 0.8)
	elseif emote == "Chupada de Dedo" then
		ligarCorpoDev(P, true, false, false)
		P.N = cfRot(cp.cabeca) * CFrame.Angles(rad(3 * sin(tempo * 7)), rad(2 * cos(tempo * 5)), 0)
	elseif emote == "De Quatro" then

		local D = CFrame.Angles(0, 0, 0)
		ligarCorpoDev(P, true, true, true)
		if dirOn then P.R = fixaNoMundo(C0_R6.rs, cfBraco(cp.direita.braco), D) end
		if esqOn then P.L = fixaNoMundo(C0_R6.ls, cfBraco(cp.esquerda.braco), D) end
		P.B = cfPerna(cp.torso) * D
		P.PR = fixaNoMundo(C0_R6.rh, cfPerna(cp.pernaDir), D)
		P.PL = fixaNoMundo(C0_R6.lh, cfPerna(cp.pernaEsq), D)
	elseif emote == "Socar" then

		local t = tempo * 8.2
		local s = sin(t)
		local c = cos(t)
		local thrust = 0.48 * s
		local bob = 0.07 * c
		local pitch = rad(8 * s)
		local roll = rad(2.5 * c)
		local D = CFrame.new(0, bob, thrust) * CFrame.Angles(pitch, 0, roll)

		local spring = sin(t - 0.35)
		local springC = cos(t - 0.35)
		local legCompress = 0.055 * spring
		local legBend = rad(6 * spring)
		local legPush = 0.04 * spring
		local legRoll = rad(1.8 * springC)

		ligarCorpoDev(P, true, true, true)
		if dirOn then P.R = fixaNoMundo(C0_R6.rs, cfBraco(cp.direita.braco), D) end
		if esqOn then P.L = fixaNoMundo(C0_R6.ls, cfBraco(cp.esquerda.braco), D) end
		P.N = cfRot(cp.cabeca) * CFrame.Angles(rad(7 * s), rad(3 * c), 0)
		P.B = cfPerna(cp.torso) * D

		local legExtraR = CFrame.new(0.02 * spring, legCompress, legPush) * CFrame.Angles(legBend, 0, legRoll)
		local legExtraL = CFrame.new(-0.02 * spring, legCompress, legPush) * CFrame.Angles(legBend, 0, -legRoll)
		P.PR = fixaNoMundo(C0_R6.rh, cfPerna(cp.pernaDir) * legExtraR, D)
		P.PL = fixaNoMundo(C0_R6.lh, cfPerna(cp.pernaEsq) * legExtraL, D)
	end
	return P
end

local function dedoAnimadoDev(emote, id, ehDireito, b, p, tempo)
	if emote == "Tchau" then
		return b + math.random(-5, 5), p
	elseif emote == "Cala a Boca" then
		if not ehDireito then

			local k = 0.5 + 0.5 * sin(tempo * 10) - 0.5
			if id == 1 then return b + 25 * k, p + 25 * k end
			return b + 55 * k, p + 45 * k
		end
	elseif emote == "Convidando" then
		if ehDireito and id == 2 then
			local c = 40 * sin(tempo * 8)
			return b + c, p + c
		end
	elseif emote == "Chupada de Dedo" then
		if ehDireito and id == 2 then
			local k = 0.5 + 0.5 * sin(tempo * 7)
			return b + 6 * k, p + 4 * k
		end
	elseif emote == "Siririca" then
		if ehDireito and (id == 2 or id == 3) then
			local inten = 0
			if siriricaTempo > GOZAR.delay then
				inten = clamp((siriricaTempo - GOZAR.delay) / GOZAR.buildup, 0, 1)
			end
			local k = 0.5 + 0.5 * sin(tempo * (9 + GOZAR.rubVelExtra * inten))
			return b + (12 + 10 * inten) * k, p + (10 + 8 * inten) * k
		end
	end
	return b, p
end

local ZERO3 = { x = 0, y = 0, z = 0 }
local function copia3(t)
	t = t or ZERO3
	return { x = t.x, y = t.y, z = t.z }
end
local function naoZero(t)
	return t.x ~= 0 or t.y ~= 0 or t.z ~= 0 or (t.px or 0) ~= 0 or (t.py or 0) ~= 0 or (t.pz or 0) ~= 0
end

local function copiaPerna(t)
	t = t or ZERO3
	return { x = t.x, y = t.y, z = t.z, px = t.px or 0, py = t.py or 0, pz = t.pz or 0 }
end

local function copiaProfunda(v)
	if type(v) ~= "table" then return v end
	local c = {}
	for k, x in pairs(v) do c[k] = copiaProfunda(x) end
	return c
end

local historicoPose = {}
local HISTORICO_MAX = 20

local function salvarSnapshotPose()
	if not currentEmote then return end
	table.insert(historicoPose, {
		emote = currentEmote,
		pose = copiaProfunda(customPose),
		anim = copiaProfunda(animConfig),
	})
	if #historicoPose > HISTORICO_MAX then table.remove(historicoPose, 1) end
end

local function restaurarSnapshotPose()
	local snap = table.remove(historicoPose)
	if not snap then return nil end
	currentEmote = snap.emote
	freezeEmote = true

	for _, lado in ipairs({ "direita", "esquerda" }) do
		for k, v in pairs(snap.pose[lado]) do customPose[lado][k] = v end
	end
	for _, parte in ipairs({ "cabeca", "torso", "pernaDir", "pernaEsq", "itens" }) do
		customPose[parte] = snap.pose[parte] or customPose[parte]
	end
	for k, v in pairs(snap.anim) do animConfig[k] = v end
	return snap.emote
end

local function carregarEmote(nome)
	local d = defaultEmotes[nome]
	if not d then return false end
	salvarSnapshotPose()
	currentEmote = nome
	freezeEmote = true

	local D, E = customPose.direita, customPose.esquerda
	D.braco = { x = d.dir.x, y = d.dir.y, z = d.dir.z, px = d.dir.px, py = d.dir.py, pz = d.dir.pz }
	D.palma = copia3(d.palmaDir)
	D.afastamento = d.afastDir
	E.braco = { x = d.esq.x, y = d.esq.y, z = d.esq.z, px = d.esq.px, py = d.esq.py, pz = d.esq.pz }
	E.palma = copia3(d.palmaEsq)
	E.afastamento = d.afastEsq
	for j = 1, 5 do
		D.dedos[j] = copiaDedo(d.dedosDir[j])
		E.dedos[j] = copiaDedo(d.dedosEsq[j])
	end

	customPose.cabeca = copiaPerna(d.cabeca)
	customPose.torso = copiaPerna(d.torso)
	customPose.pernaDir = copiaPerna(d.pernaDir)
	customPose.pernaEsq = copiaPerna(d.pernaEsq)
	customPose.itens = ItensEmote.copiar(d.itens)

	animConfig.direita = true
	animConfig.esquerda = true
	animConfig.cabeca = naoZero(customPose.cabeca)
	animConfig.torso = naoZero(customPose.torso)
	animConfig.pernas = naoZero(customPose.pernaDir) or naoZero(customPose.pernaEsq)
	return true
end

local function resetarParte(parte)
	local d = currentEmote and defaultEmotes[currentEmote]
	if not d then return false end
	salvarSnapshotPose()

	local D, E = customPose.direita, customPose.esquerda
	if parte == "bracos" then
		D.braco = { x = d.dir.x, y = d.dir.y, z = d.dir.z, px = d.dir.px or 0, py = d.dir.py or 0, pz = d.dir.pz or 0 }
		E.braco = { x = d.esq.x, y = d.esq.y, z = d.esq.z, px = d.esq.px or 0, py = d.esq.py or 0, pz = d.esq.pz or 0 }
	elseif parte == "maos" then
		D.palma = copia3(d.palmaDir)
		E.palma = copia3(d.palmaEsq)
		D.afastamento = d.afastDir or 0
		E.afastamento = d.afastEsq or 0
		for j = 1, 5 do
			D.dedos[j] = copiaDedo(d.dedosDir[j])
			E.dedos[j] = copiaDedo(d.dedosEsq[j])
		end
	elseif parte == "torso" then
		customPose.torso = copiaPerna(d.torso)
	elseif parte == "cabeca" then
		customPose.cabeca = copiaPerna(d.cabeca)
	elseif parte == "pernas" then
		customPose.pernaDir = copiaPerna(d.pernaDir)
		customPose.pernaEsq = copiaPerna(d.pernaEsq)
	elseif parte == "itens" then
		customPose.itens = ItensEmote.copiar(d.itens)
	else
		return false
	end
	return true
end

local T = {
	bg = Color3.fromRGB(15, 17, 24),
	surface = Color3.fromRGB(22, 25, 35),
	surface2 = Color3.fromRGB(30, 34, 47),
	surface3 = Color3.fromRGB(42, 47, 64),
	stroke = Color3.fromRGB(52, 58, 80),
	text = Color3.fromRGB(236, 239, 247),
	sub = Color3.fromRGB(152, 160, 184),
	dim = Color3.fromRGB(104, 112, 136),
	accent = Color3.fromRGB(124, 108, 255),
	accentSoft = Color3.fromRGB(46, 41, 98),
	ok = Color3.fromRGB(62, 200, 128),
	danger = Color3.fromRGB(236, 86, 92),
	warn = Color3.fromRGB(246, 182, 70),
	ax = { Color3.fromRGB(240, 98, 98), Color3.fromRGB(80, 200, 130), Color3.fromRGB(88, 140, 250) },
}

local F = Enum.Font
local LEFT, CENTER, RIGHT = Enum.TextXAlignment.Left, Enum.TextXAlignment.Center, Enum.TextXAlignment.Right

local function new(class, props, kids)
	local o = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else o[k] = v end
	end
	for _, c in ipairs(kids or {}) do c.Parent = o end
	if parent then o.Parent = parent end
	return o
end

local function merge(base, props)
	for k, v in pairs(props or {}) do base[k] = v end
	return base
end

local function frame(props, kids)
	return new("Frame", merge({ BorderSizePixel = 0, BackgroundColor3 = T.surface }, props), kids)
end

local function txt(props, kids)
	return new("TextLabel", merge({
		BackgroundTransparency = 1, BorderSizePixel = 0, Font = F.Gotham, TextColor3 = T.text,
		TextSize = 12, TextXAlignment = LEFT, Text = "",
	}, props), kids)
end

local function btn(props, kids)
	return new("TextButton", merge({
		AutoButtonColor = false, BorderSizePixel = 0, Text = "", BackgroundColor3 = T.surface2,
		Font = F.GothamMedium, TextColor3 = T.text, TextSize = 12,
	}, props), kids)
end

local function round(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function outline(color, th, tr)
	return new("UIStroke", {
		Color = color or T.stroke, Thickness = th or 1, Transparency = tr or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function padding(l, t, r, b)
	t = t or l; r = r or l; b = b or t
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b),
	})
end

local function lista(gap, dir, align)
	return new("UIListLayout", {
		Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = dir or Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

local function tw(o, t, props, style, dir)
	local tween = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

local function hoverFX(b, normal, over)
	b.MouseEnter:Connect(function() tw(b, 0.12, { BackgroundColor3 = over }) end)
	b.MouseLeave:Connect(function() tw(b, 0.12, { BackgroundColor3 = normal }) end)
end

local function makeDraggable(root, handle)
	local dragging, dragStart, startPos = false, nil, nil
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = root.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local oldGui = PlayerGui:FindFirstChild("DynamicHandsGUI")
if oldGui then oldGui:Destroy() end

local MainGui = new("ScreenGui", {
	Name = "DynamicHandsGUI", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10, Parent = PlayerGui,
})

local function ajustarEscala(uiScale, w, h)
	local function aplicar()
		local vp = MainGui.AbsoluteSize
		if vp.X <= 0 or vp.Y <= 0 then return end
		uiScale.Scale = math.min(1, (vp.X - 24) / w, (vp.Y - 24) / h)
	end
	MainGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(aplicar)
	aplicar()
end

-- ===== minimizar / fechar / reabrir (com animação) =====
-- cfg: win, head, scale, w, h, headH, posMin, posX, size, radius, ativo(), btnX (opcional),
--      semChip (opcional), onHide, onShow, onMin(min)
local function janelaControles(cfg)
	local win, head, scale = cfg.win, cfg.head, cfg.scale
	local fullW, fullH, headH = cfg.w, cfg.h, cfg.headH or 34
	local sz = cfg.size or 26
	local minimizado, fechada, animando = false, false, false
	local curH = fullH
	local guardados = {}
	local clipOriginal = win.ClipsDescendants

	local btnMin = btn({ Text = "", TextSize = 16, TextColor3 = T.sub, Size = UDim2.fromOffset(sz, sz), Position = cfg.posMin, Parent = head }, { round(cfg.radius or 8) })
	hoverFX(btnMin, T.surface2, T.surface3)
	T.Icones.centro(btnMin, "_min", 14, 2)
	local btnX = cfg.btnX
	if not btnX then
		btnX = btn({ Text = "", TextSize = 13, TextColor3 = T.danger, Size = UDim2.fromOffset(sz, sz), Position = cfg.posX, Parent = head }, { round(cfg.radius or 8) })
		hoverFX(btnX, T.surface2, T.danger)
		T.Icones.centro(btnX, "_fechar_r", 14, 2)
	end

	-- quadradinho para reabrir (aparece quando a janela é fechada no X)
	local chip
	if not cfg.semChip then
		chip = btn({
			Text = "", TextSize = 18, TextColor3 = T.accent, Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = T.surface, Visible = false, ZIndex = 40, Parent = MainGui,
		}, { round(10), outline(T.stroke, 1, 0.1) })
		hoverFX(chip, T.surface, T.surface3)
		T.Icones.centro(chip, "_restaurar", 18, 41)
	end
	local function atualizarChip()
		if chip then chip.Visible = fechada and ((not cfg.ativo) or cfg.ativo()) end
	end

	local function minimizar(min)
		if animando or fechada then return end
		animando = true
		minimizado = min
		T.Icones.centro(btnMin, min and "_restaurar" or "_min", 14, 2)
		if cfg.onMin then cfg.onMin(min) end

		local novaH = min and headH or fullH
		local novaPos = cfg.fixaBase and win.Position or (win.Position + UDim2.fromOffset(0, win.AnchorPoint.Y * (novaH - curH) * scale.Scale))
		curH = novaH
		win.ClipsDescendants = true
		if not min then
			for o, vis in pairs(guardados) do
				if o.Parent then o.Visible = vis end
			end
			guardados = {}
		end
		local t = tw(win, 0.22, { Size = UDim2.fromOffset(fullW, novaH), Position = novaPos }, Enum.EasingStyle.Quint)
		t.Completed:Once(function()
			if min then
				for _, o in ipairs(win:GetChildren()) do
					if o:IsA("GuiObject") and o ~= head then
						guardados[o] = o.Visible
						o.Visible = false
					end
				end
			else
				win.ClipsDescendants = clipOriginal
			end
			animando = false
		end)
	end

	local function fechar()
		if animando or fechada then return end
		fechada = true
		animando = true
		local base = scale.Scale
		if chip then
			local ap = win.AbsolutePosition
			chip.Position = UDim2.fromOffset(ap.X, ap.Y)
		end
		local t = tw(scale, 0.16, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		t.Completed:Once(function()
			win.Visible = false
			scale.Scale = base
			animando = false
			if cfg.onHide then cfg.onHide() end
			atualizarChip()
		end)
	end

	local function abrir()
		if animando or not fechada then return end
		fechada = false
		if chip then chip.Visible = false end
		local base = scale.Scale
		scale.Scale = 0
		win.Visible = true
		tw(scale, 0.22, { Scale = base }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		if cfg.onShow then cfg.onShow() end
	end

	btnMin.MouseButton1Click:Connect(function() minimizar(not minimizado) end)

	-- começa minimizada (sem animação)
	if cfg.iniciarMin then
		minimizado = true
		T.Icones.centro(btnMin, "_restaurar", 14, 2)
		curH = headH
		win.ClipsDescendants = true
		win.Size = UDim2.fromOffset(fullW, headH)
		if not cfg.fixaBase then
			win.Position = win.Position + UDim2.fromOffset(0, win.AnchorPoint.Y * (headH - fullH) * scale.Scale)
		end
		for _, o in ipairs(win:GetChildren()) do
			if o:IsA("GuiObject") and o ~= head then
				guardados[o] = o.Visible
				o.Visible = false
			end
		end
		if cfg.onMin then cfg.onMin(true) end
	end
	if not cfg.btnX then btnX.MouseButton1Click:Connect(fechar) end
	if chip then chip.MouseButton1Click:Connect(abrir) end

	-- se algo reabrir a janela por fora (ex.: abrir outro emote), limpa o estado de "fechada"
	win:GetPropertyChangedSignal("Visible"):Connect(function()
		if win.Visible and fechada and not animando then fechada = false end
		atualizarChip()
	end)
	if cfg.ativo and cfg.pai then
		cfg.pai:GetPropertyChangedSignal("Visible"):Connect(atualizarChip)
	end
end

local J_R6 = {
	root = { CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	neck = { CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	rs = { CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	ls = { CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
	rh = { CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	lh = { CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
}

local function aplicarJ(j, p0, p1, transform)
	p1.CFrame = p0.CFrame * j[1] * transform * j[2]:Inverse()
end

local CORPO_R6 = { Head = true, Torso = true, ["Right Arm"] = true, ["Left Arm"] = true, ["Right Leg"] = true, ["Left Leg"] = true }

local function criarPreview(viewport)
	local self = {}
	local cam = Instance.new("Camera")
	cam.FieldOfView = 38
	cam.Parent = viewport
	viewport.CurrentCamera = cam
	viewport.Ambient = Color3.fromRGB(150, 150, 168)
	viewport.LightColor = Color3.fromRGB(255, 252, 246)
	viewport.LightDirection = Vector3.new(-0.35, -0.55, 0.9)

	local rig, rigChar = nil, nil
	local emote, custom, active = nil, false, false
	local animar = true
	local theta, dist = 0.35, 9.5
	local lastTry = 0
	local CENTRO = Vector3.new(0, -0.4, 0)
	local itensPrev = ItensEmote.novoPreview()

	local function destruir()
		itensPrev.limpar()
		if rig then rig.model:Destroy() end
		rig, rigChar = nil, nil
	end

	local function limparJoints(raiz)
		for _, d in ipairs(raiz:GetDescendants()) do
			if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("BaseScript") or d:IsA("Sound")
				or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Fire") or d:IsA("Smoke")
				or d:IsA("Sparkles") or d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
				d:Destroy()
			end
		end
	end

	local function prepararPeca(p)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.LocalTransparencyModifier = 0
	end

	local function clonar(inst)
		local wasArch = inst.Archivable
		inst.Archivable = true
		local ok, c = pcall(function() return inst:Clone() end)
		inst.Archivable = wasArch
		if ok then return c end
		return nil
	end

	local function construir()
		destruir()
		local char = LocalPlayer.Character
		if not char then return end

		local model = Instance.new("Model")
		model.Name = "PreviewRig"
		local pt = {}

		for nome in pairs(CORPO_R6) do
			local src = char:FindFirstChild(nome)
			if not (src and src:IsA("BasePart")) then model:Destroy() return end
			local c = clonar(src)
			if not c then model:Destroy() return end
			limparJoints(c)
			prepararPeca(c)
			c.Transparency = 0
			c.CFrame = CFrame.new()
			c.Parent = model
			pt[nome] = c
		end

		for _, ch in ipairs(char:GetChildren()) do
			if ch:IsA("Shirt") or ch:IsA("Pants") or ch:IsA("ShirtGraphic") or ch:IsA("BodyColors") or ch:IsA("CharacterMesh") then
				local c = clonar(ch)
				if c then c.Parent = model end
			end
		end

		local accs = {}
		for _, a in ipairs(char:GetChildren()) do
			if a:IsA("Accessory") then
				local ac = clonar(a)
				local handle = ac and ac:FindFirstChild("Handle")
				if handle and handle:IsA("BasePart") then
					limparJoints(ac)
					for _, d in ipairs(ac:GetDescendants()) do
						if d:IsA("BasePart") then prepararPeca(d) end
					end
					prepararPeca(handle)
					local achou = nil
					for _, att in ipairs(handle:GetChildren()) do
						if att:IsA("Attachment") then
							for _, parte in pairs(pt) do
								local b = parte:FindFirstChild(att.Name)
								if b and b:IsA("Attachment") then
									achou = { handle = handle, body = parte, ba = b.CFrame, ha = att.CFrame }
									break
								end
							end
						end
						if achou then break end
					end
					if achou then
						table.insert(accs, achou)
						ac.Parent = model
					else
						ac:Destroy()
					end
				elseif ac then
					ac:Destroy()
				end
			end
		end

		local hum = Instance.new("Humanoid")
		hum.RigType = Enum.HumanoidRigType.R6
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.Parent = model

		local function mk(size, brace, isPalma)
			local p = pecaDoMembro(brace, size, isPalma)
			prepararPeca(p)
			p.Parent = model
			return p
		end

		local function criarMao(brace, ehDireito)
			local h = { arm = brace, ehDireito = ehDireito, palma = mk(PALMA_SIZE, brace, true), dedos = {} }
			for id = 1, 5 do
				h.dedos[id] = {
					base = mk(CONFIG_DEDOS[id].tampBase, brace, false),
					ponta = mk(CONFIG_DEDOS[id].tampPonta, brace, false),
					ab = 0, ap = 0,
				}
				if JUNTA_ATIVA then
					local j = juntaDoMembro(brace)
					for _, cunha in ipairs(j) do
						prepararPeca(cunha)
						cunha.Parent = model
					end
					h.dedos[id].junta = j
				end
			end
			return h
		end

		rig = {
			model = model, pt = pt, accs = accs,
			hands = { criarMao(pt["Right Arm"], true), criarMao(pt["Left Arm"], false) },
			cur = { R = CFrame.new(), L = CFrame.new(), N = CFrame.new(), B = CFrame.new(), PR = CFrame.new(), PL = CFrame.new() },
		}
		rigChar = char
		model.Parent = viewport

		limparJoints(model)
		task.defer(function() if model.Parent then limparJoints(model) end end)
		print(("[Preview] boneco montado: %d acessórios"):format(#accs))
	end

	local function alvo(cf, w)
		return CFrame.new():Lerp(cf, clamp(w, 0, 1))
	end

	local function atualizar()
		local t = tick()
		local P
		if custom then
			if animar and currentEmote then
				P = calcularPoseCustomAnimada(currentEmote, t)
			else
				P = calcularPoseCustom()
			end
		else
			P = calcularPoseEmote(emote, t, false)
		end

		local c = rig.cur
		c.R = c.R:Lerp(alvo(P.R, P.wR), 0.25)
		c.L = c.L:Lerp(alvo(P.L, P.wL), 0.25)
		c.N = c.N:Lerp(alvo(P.N, P.wN), 0.25)
		c.B = c.B:Lerp(alvo(P.B, P.wB), 0.25)
		c.PR = c.PR:Lerp(alvo(P.PR, P.wP), 0.25)
		c.PL = c.PL:Lerp(alvo(P.PL, P.wP), 0.25)

		local pt = rig.pt
		pt.Torso.CFrame = J_R6.root[1] * c.B * J_R6.root[2]:Inverse()
		aplicarJ(J_R6.rs, pt.Torso, pt["Right Arm"], c.R)
		aplicarJ(J_R6.ls, pt.Torso, pt["Left Arm"], c.L)
		aplicarJ(J_R6.neck, pt.Torso, pt.Head, c.N)
		aplicarJ(J_R6.rh, pt.Torso, pt["Right Leg"], c.PR)
		aplicarJ(J_R6.lh, pt.Torso, pt["Left Leg"], c.PL)

		for _, a in ipairs(rig.accs) do
			a.handle.CFrame = a.body.CFrame * a.ba * a.ha:Inverse()
		end

		local listaItens = ItensEmote.listaPreview(custom, emote)
		itensPrev.sincronizar(rig.model, listaItens)
		itensPrev.atualizar(listaItens)

		for _, h in ipairs(rig.hands) do
			if h then
				local pm = h.ehDireito and customPose.direita or customPose.esquerda
				local ativo
				if h.ehDireito then ativo = animConfig.direita else ativo = animConfig.esquerda end
				local palmaCF = h.arm.CFrame * CFrame.new(0, -1.0, 0)
				local modoCustom = custom and ativo
				if modoCustom then
					palmaCF = palmaCF * CFrame.Angles(rad(pm.palma.x), rad(pm.palma.y), rad(pm.palma.z))
				end
				h.palma.CFrame = palmaCF

				for id = 1, 5 do
					local d = h.dedos[id]
					local alvoB, alvoP = 0, 0
					local afast = 0
					local ext = nil
					if modoCustom then
						alvoB, alvoP = pm.dedos[id][1], pm.dedos[id][2]
						if animar and currentEmote then
							alvoB, alvoP = dedoAnimadoDev(currentEmote, id, h.ehDireito, alvoB, alvoP, t)
						end
						afast = afastGraus(id, h.ehDireito, pm.afastamento)
						ext = pm.dedos[id]
					elseif (not custom) and emote then
						local b, p = alvoDedosEmote(emote, id, h.ehDireito)
						alvoB, alvoP = b or 0, p or 0
						ext = extraDedoEmote(emote, id, h.ehDireito)
					else
						local curva = (id == 1) and 3 or (id * 3)
						alvoB = curva + sin(t * 2 - id * 0.3) * 3
						alvoP = curva * 0.8 + cos(t * 2 - id * 0.3) * 2
					end
					d.ab = d.ab + (alvoB - d.ab) * SMOOTH_FACTOR
					d.ap = d.ap + (alvoP - d.ap) * SMOOTH_FACTOR
					local baseCF, pontaCF, pivotCF = calcFingerCFrames(id, h.ehDireito, d.ab, d.ap, afast, ext)
					d.base.CFrame = palmaCF * baseCF
					d.ponta.CFrame = palmaCF * pontaCF
					if d.junta then
						local cf1, s1, cf2, s2 = calcJuntaCFrames(id, h.ehDireito, d.ap, palmaCF * pivotCF)
						d.junta[1].Size, d.junta[1].CFrame = s1, cf1
						d.junta[2].Size, d.junta[2].CFrame = s2, cf2
					end
				end
			end
		end
	end

	RunService.RenderStepped:Connect(function()
		if not active or not viewport.Visible or viewport.AbsoluteSize.X <= 0 then return end

		if (not rig) or rigChar ~= LocalPlayer.Character or not rigChar.Parent then
			if tick() - lastTry < 0.5 then return end
			lastTry = tick()
			construir()
			if not rig then return end
		end

		local pos = CENTRO + Vector3.new(sin(theta), 0.12, -cos(theta)).Unit * dist
		cam.CFrame = CFrame.lookAt(pos, CENTRO)
		atualizar()
	end)

	local arrastando = false
	local pinchBase = nil
	viewport.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			arrastando = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			arrastando = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if arrastando and not pinchBase and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			theta = theta - input.Delta.X * 0.012
		end
	end)
	viewport.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			dist = clamp(dist - input.Position.Z * 0.8, 5, 16)
		end
	end)
	-- celular: pinça com dois dedos em cima do preview = zoom
	UserInputService.TouchPinch:Connect(function(pos, escala, _, estado)
		if estado == Enum.UserInputState.Begin then
			pinchBase = nil
			local p = pos[1]
			if p and pos[2] then p = (pos[1] + pos[2]) / 2 end
			if p and active and viewport.Visible then
				local a, sz = viewport.AbsolutePosition, viewport.AbsoluteSize
				-- folga de 60px por causa da diferença de offset da barra superior entre toque e GUI
				if p.X >= a.X - 20 and p.X <= a.X + sz.X + 20 and p.Y >= a.Y - 60 and p.Y <= a.Y + sz.Y + 60 then
					pinchBase = dist
				end
			end
		elseif estado == Enum.UserInputState.Change then
			if pinchBase then dist = clamp(pinchBase / math.max(escala, 0.1), 5, 16) end
		else
			pinchBase = nil
		end
	end)

	function self.setEmote(nome) emote = nome end
	function self.setCustom(b) custom = b end
	function self.setActive(b) active = b end
	function self.setAnimar(b) animar = b end
	function self.resetCamera() theta, dist = 0.35, 9.5 end
	function self.girar() theta = theta + math.pi end
	function self.rebuild() lastTry = 0; destruir() end
	return self
end

local function novoViewport(props)
	return new("ViewportFrame", merge({
		BackgroundColor3 = T.surface, BorderSizePixel = 0, Ambient = Color3.fromRGB(150, 150, 168),
	}, props), { round(10) })
end

local Ragdoll = (function()
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local api = {}
local KEYBIND = nil

local SOUNDS_RAGDOLL = {
    "83123564520089",
    "91358197736651",
    "125172888675723",
    "70742968288690",
}
local SOUND_GETUP = "136774133309136"
local SOUND_JUMP = "73013473893740"
local SOUND_VOLUME = 1
local GETUP_TIME = 0.7

local JUMP_POWER = 70
local JUMP_PUSH = 30

local IMPACT_MIN_SPEED = 6
local IMPACT_COOLDOWN = 0.25
local JUMP_COOLDOWN = 0.6
local JUMP_NEEDS_GROUND = true

local function playSound(ids, parent)
    if not parent then return end
    local id = type(ids) == "table" and ids[math.random(#ids)] or ids
    local ok = pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://" .. id
        s.Volume = SOUND_VOLUME
        s.RollOffMaxDistance = 120
        s.Parent = parent
        s:Play()
        Debris:AddItem(s, 10)
    end)
    return ok
end

local env = (getgenv and getgenv()) or _G
if env.__RagdollCleanup then
    pcall(env.__RagdollCleanup)
end

local LIMITS = {
    Neck = {cone = 50, twist = 40},
    Shoulder = {cone = 110, twist = 60},
    Hip = {cone = 80, twist = 35},
    Knee = {cone = 70, twist = 10},
    Elbow = {cone = 80, twist = 10},
    Ankle = {cone = 35, twist = 15},
    Wrist = {cone = 40, twist = 20},
    Waist = {cone = 35, twist = 20},
    Default = {cone = 50, twist = 25},
}

local JOINT_FREEDOM = 1.3
local USE_HINGES = true
local MOMENTUM_KEEP = 1
local SPIN_DAMPING = 0.8
local LIMB_FRICTION = 0.8
local LIMB_ELASTICITY = 0.05
local DENSITY = {Head = 1.0, Torso = 1.0, Limb = 0.6}
local NEVER_STAND = true
local STAND_LIMIT = 0.4
local TIP_TORQUE = 38
local TIP_MAX_SPIN = 7
local FLAT_SLOPE = 0.03
local TIP_GROUND_RANGE = 7
local SELF_COLLIDE = false

local VFX_ENABLED = true
local AIR_VFX_MIN_SPEED = 35
local IMPACT_VFX_MIN_SPEED = 14
local TRAIL_DELAY = 2
local TRAIL_FADE = 1.5
local AUTO_RAGDOLL = true
local AUTO_RAGDOLL_DELAY = TRAIL_DELAY
local SHAKE_POWER = 1
local AIR_SHAKE = 0.25
local FOV_BOOST = 12
local STABLE_CAMERA = true

local function getLimits(name)
    local base = LIMITS.Default
    for key, v in pairs(LIMITS) do
        if key ~= "Default" and name:find(key) then
            base = v
            break
        end
    end
    return {
        cone = math.min(base.cone * JOINT_FREEDOM, 175),
        twist = math.min(base.twist * JOINT_FREEDOM, 175),
    }
end

local function getDensity(partName)
    if partName == "Head" then return DENSITY.Head end
    if partName:find("Torso") then return DENSITY.Torso end
    return DENSITY.Limb
end

local ragdolled = false
local gettingUp = false
local lastImpact = 0
local lastGroundTouch = 0
local ragConns = {}
local created = {}
local motors = {}
local collideBackup = {}
local physBackup = {}
local connections = {}

local ui = {}
local setRagdoll
local camSubjectBackup = nil

local function getChar()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return char, hum, root
end

local vfx = {
    air = 0,
    shake = 0,
    airTime = 0,
    trail = 0,
    rayParams = nil,
    trails = {},
    trailChar = nil,
    fovActive = false,
    baseFov = 70,
    folder = nil,
}

local function fxFolder()
    if not vfx.folder or not vfx.folder.Parent then
        local f = Instance.new("Folder")
        f.Name = "RagdollFX"
        f.Parent = workspace
        vfx.folder = f
    end
    return vfx.folder
end

local TRAIL_PARTS = {
    "Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot",
    "Left Arm", "Right Arm", "Left Leg", "Right Leg",
}

local function clearTrails()
    for _, inst in ipairs(vfx.trails) do
        if inst and inst.Parent then inst:Destroy() end
    end
    table.clear(vfx.trails)
    vfx.trailChar = nil
end

local function ensureTrails(char)
    if vfx.trailChar == char then return end
    clearTrails()
    vfx.trailChar = char
    for _, name in ipairs(TRAIL_PARTS) do
        local p = char:FindFirstChild(name)
        if p and p:IsA("BasePart") then
            local a0 = Instance.new("Attachment")
            a0.Name = "FXTrailA0"
            a0.Position = Vector3.new(0, p.Size.Y * 0.35, 0)
            a0.Parent = p

            local a1 = Instance.new("Attachment")
            a1.Name = "FXTrailA1"
            a1.Position = Vector3.new(0, -p.Size.Y * 0.35, 0)
            a1.Parent = p

            local t = Instance.new("Trail")
            t.Name = "FXTrail"
            t.Attachment0 = a0
            t.Attachment1 = a1
            t.Lifetime = 0.3
            t.MinLength = 0.05
            t.FaceCamera = true
            t.LightEmission = 0.5
            t.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
            t.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.35),
                NumberSequenceKeypoint.new(1, 1),
            })
            t.WidthScale = NumberSequence.new(1, 0.2)
            t.Enabled = false
            t.Parent = p

            table.insert(vfx.trails, a0)
            table.insert(vfx.trails, a1)
            table.insert(vfx.trails, t)
        end
    end
end

local function spawnDust(pos, normal, speed, color)
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Transparency = 1
    part.Size = Vector3.new(1, 1, 1)
    part.CFrame = CFrame.new(pos, pos + normal) * CFrame.Angles(-math.pi / 2, 0, 0)
    part.Parent = fxFolder()

    local s = math.clamp(speed / 30, 0.6, 2)
    local e = Instance.new("ParticleEmitter")
    e.Texture = "rbxasset://textures/particles/smoke_main.dds"
    e.Color = ColorSequence.new(color:Lerp(Color3.fromRGB(190, 190, 190), 0.5))
    e.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8 * s),
        NumberSequenceKeypoint.new(1, 2.8 * s),
    })
    e.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.35),
        NumberSequenceKeypoint.new(1, 1),
    })
    e.Lifetime = NumberRange.new(0.5, 1.1)
    e.Speed = NumberRange.new(5 * s, 12 * s)
    e.SpreadAngle = Vector2.new(75, 75)
    e.Drag = 3
    e.Rotation = NumberRange.new(0, 360)
    e.RotSpeed = NumberRange.new(-90, 90)
    e.EmissionDirection = Enum.NormalId.Top
    e.Rate = 0
    e.Parent = part
    e:Emit(math.clamp(math.floor(speed * 0.6), 6, 30))

    Debris:AddItem(part, 2)
end

local function vfxImpactAt(pos, normal, speed, color)
    spawnDust(pos, normal, speed, color)
    if speed >= 20 then
        vfx.shake = math.max(vfx.shake, math.clamp(speed / 70, 0.15, 1) * SHAKE_POWER)
    end
end

local function vfxImpact(part, other, speed, char)
    if not VFX_ENABLED or speed < IMPACT_VFX_MIN_SPEED then return end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char, fxFolder()}
    local res = workspace:Raycast(part.Position + Vector3.new(0, 1, 0), Vector3.new(0, -6, 0), params)
    local pos = res and res.Position or part.Position
    local normal = res and res.Normal or Vector3.yAxis
    vfxImpactAt(pos, normal, speed, other.Color)
end

local function vfxStep(dt)
    local cam = workspace.CurrentCamera
    local char, hum, root = getChar()

    if char and hum and root and hum.Health > 0 then
        if not vfx.rayParams then
            vfx.rayParams = RaycastParams.new()
            vfx.rayParams.FilterType = Enum.RaycastFilterType.Exclude
        end
        vfx.rayParams.FilterDescendantsInstances = {char, fxFolder()}
        local airborne = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), vfx.rayParams) == nil
        if airborne and not ragdolled then

            airborne = hum:GetState() == Enum.HumanoidStateType.Freefall
        end
        if airborne and not gettingUp then
            vfx.airTime = vfx.airTime + dt
        else
            vfx.airTime = 0
        end

        if AUTO_RAGDOLL and not ragdolled and not gettingUp
            and not (api.blocked and api.blocked())
            and vfx.airTime >= AUTO_RAGDOLL_DELAY then
            setRagdoll(true)
        end
    else
        vfx.airTime = 0
    end

    local active = char and root and VFX_ENABLED and ragdolled
    local target = 0
    local trailTarget = 0
    if active then
        ensureTrails(char)
        local speed = root.AssemblyLinearVelocity.Magnitude
        target = math.clamp((speed - AIR_VFX_MIN_SPEED) / 50, 0, 1)
        trailTarget = math.clamp((vfx.airTime - TRAIL_DELAY) / TRAIL_FADE, 0, 1)
    elseif vfx.trailChar then
        clearTrails()
    end

    vfx.air = vfx.air + (target - vfx.air) * math.min(1, dt * 8)
    vfx.trail = vfx.trail + (trailTarget - vfx.trail) * math.min(1, dt * 8)

    local t = vfx.trail
    local on = t > 0.03
    local seq = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1 - 0.65 * t),
        NumberSequenceKeypoint.new(1, 1),
    })
    for _, inst in ipairs(vfx.trails) do
        if inst:IsA("Trail") then
            inst.Enabled = on
            inst.Lifetime = 0.12 + 0.3 * t
            inst.Transparency = seq
        end
    end

    if cam then
        if vfx.air > 0.02 then
            if not vfx.fovActive then
                vfx.baseFov = cam.FieldOfView
                vfx.fovActive = true
            end
            cam.FieldOfView = vfx.baseFov + FOV_BOOST * vfx.air
        elseif vfx.fovActive then
            cam.FieldOfView = vfx.baseFov
            vfx.fovActive = false
        end

        local s = math.max(vfx.shake, vfx.air * AIR_SHAKE)
        if s > 0.01 then

            cam.CFrame = cam.CFrame
                * CFrame.new((math.random() - 0.5) * s * 0.6, (math.random() - 0.5) * s * 0.6, 0)
        end
        vfx.shake = vfx.shake * math.max(0, 1 - 7 * dt)
    end
end

local function vfxCleanup()
    pcall(function() RunService:UnbindFromRenderStep("RagdollFX") end)
    clearTrails()
    local cam = workspace.CurrentCamera
    if cam and vfx.fovActive then cam.FieldOfView = vfx.baseFov end
    if vfx.folder then vfx.folder:Destroy() end
end

local function enableRagdoll()
    local char, hum, root = getChar()
    if not (char and hum and root) or hum.Health <= 0 then return false end

    local jointParts, extras = {}, {}
    for _, d in ipairs(char:GetDescendants()) do
        local p0, p1, jc0, jc1, own0, own1
        if d:IsA("AnimationConstraint") then
            own0, own1 = d.Attachment0, d.Attachment1
            if own0 and own1 then p0, p1 = own0.Parent, own1.Parent end
        elseif d:IsA("Motor6D") or d:IsA("Weld") then
            p0, p1, jc0, jc1 = d.Part0, d.Part1, d.C0, d.C1
        elseif d:IsA("WeldConstraint") then
            p0, p1 = d.Part0, d.Part1
            if p0 and p1 then
                jc0 = p0.CFrame:Inverse() * p1.CFrame
                jc1 = CFrame.new()
            end
        end

        if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart")
            and p0.Name ~= "HumanoidRootPart" and p1.Name ~= "HumanoidRootPart"
            and p0.Parent == char and p1.Parent == char then

            local lim = getLimits(d.Name)

            local a0, a1 = own0, own1
            if not a0 then
                a0 = Instance.new("Attachment")
                a0.Name = "RagA0"
                a0.CFrame = jc0
                a0.Parent = p0

                a1 = Instance.new("Attachment")
                a1.Name = "RagA1"
                a1.CFrame = jc1
                a1.Parent = p1

                table.insert(created, a0)
                table.insert(created, a1)
            end

            local isR15 = hum.RigType == Enum.HumanoidRigType.R15
            local isKnee = d.Name:find("Knee") ~= nil
            local isElbow = d.Name:find("Elbow") ~= nil

            local joint
            if USE_HINGES and isR15 and (isKnee or isElbow) then
                local hinge = Instance.new("HingeConstraint")
                hinge.Name = "RagConstraint"
                hinge.Attachment0 = a0
                hinge.Attachment1 = a1
                hinge.LimitsEnabled = true
                if isKnee then
                    hinge.LowerAngle = -140
                    hinge.UpperAngle = 5
                else
                    hinge.LowerAngle = -5
                    hinge.UpperAngle = 140
                end
                hinge.Restitution = 0
                joint = hinge
            else
                local bs = Instance.new("BallSocketConstraint")
                bs.Name = "RagConstraint"
                bs.Attachment0 = a0
                bs.Attachment1 = a1
                bs.LimitsEnabled = true
                bs.UpperAngle = lim.cone
                bs.TwistLimitsEnabled = true
                bs.TwistLowerAngle = -lim.twist
                bs.TwistUpperAngle = lim.twist
                bs.Restitution = 0
                joint = bs
            end
            joint.Parent = p0

            local nc = Instance.new("NoCollisionConstraint")
            nc.Name = "RagNoCollide"
            nc.Part0 = p0
            nc.Part1 = p1
            nc.Parent = p0

            table.insert(created, joint)
            table.insert(created, nc)
            jointParts[p0] = true
            jointParts[p1] = true

            d.Enabled = false
            table.insert(motors, d)
        end
    end

    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BallSocketConstraint") and d.Name ~= "RagConstraint" and d.Enabled then
            d.Enabled = false
            table.insert(motors, d)
        end
    end

    if not SELF_COLLIDE then
        local list = {}
        for part in pairs(jointParts) do list[#list + 1] = part end
        for i = 1, #list do
            for j = i + 1, #list do
                local pair = Instance.new("NoCollisionConstraint")
                pair.Name = "RagNoCollide"
                pair.Part0, pair.Part1 = list[i], list[j]
                pair.Parent = list[i]
                table.insert(created, pair)
            end
        end
    end

    local startVel = root.AssemblyLinearVelocity

    table.insert(ragConns, RunService.Heartbeat:Connect(function()
        if not ragdolled or gettingUp then return end
        for _, m in ipairs(motors) do
            if m.Parent and m.Enabled then m.Enabled = false end
        end
        if root.CanCollide then root.CanCollide = false end
        for _, x in ipairs(extras) do
            if x.Parent and x.CanCollide then x.CanCollide = false end
        end
        if not hum.PlatformStand then hum.PlatformStand = true end
    end))

    local onlyJointParts = next(jointParts) ~= nil
    for _, p in ipairs(char:GetChildren()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            collideBackup[p] = p.CanCollide
            if onlyJointParts and not jointParts[p] then
                p.CanCollide = false
                table.insert(extras, p)
            else
                p.CanCollide = true
                physBackup[p] = {p.CustomPhysicalProperties}
                p.CustomPhysicalProperties = PhysicalProperties.new(
                    getDensity(p.Name), LIMB_FRICTION, LIMB_ELASTICITY, 50, 50
                )
            end
        end
    end
    root.CanCollide = false

    hum.AutoRotate = false
    hum.PlatformStand = true
    hum:ChangeState(Enum.HumanoidStateType.Physics)

    if STABLE_CAMERA then
        local cam = workspace.CurrentCamera
        local subject = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        if cam and subject then
            camSubjectBackup = cam.CameraSubject
            cam.CameraSubject = subject
        end
    end

    for _, p in ipairs(char:GetChildren()) do
        if p:IsA("BasePart") then
            p.AssemblyLinearVelocity = startVel * MOMENTUM_KEEP
        end
    end

    if SPIN_DAMPING > 0 then
        table.insert(ragConns, RunService.Heartbeat:Connect(function(dt)
            if not ragdolled or gettingUp then return end
            local f = math.max(0, 1 - SPIN_DAMPING * dt)
            for _, p in ipairs(char:GetChildren()) do
                if p:IsA("BasePart") then
                    p.AssemblyAngularVelocity = p.AssemblyAngularVelocity * f
                end
            end
        end))
    end

    if NEVER_STAND then
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char, fxFolder()}

        local function newRandomDir()
            local a = math.random() * math.pi * 2
            return Vector3.new(math.cos(a), 0, math.sin(a))
        end
        local randomDir = newRandomDir()

        if torso then
            table.insert(ragConns, RunService.Heartbeat:Connect(function(dt)
                if not ragdolled or gettingUp or not torso.Parent then return end

                local up = torso.CFrame.UpVector
                if up.Y <= STAND_LIMIT then
                    randomDir = newRandomDir()
                    return
                end
                if torso.AssemblyLinearVelocity.Y > 30 then return end

                local hit = workspace:Raycast(torso.Position, Vector3.new(0, -TIP_GROUND_RANGE, 0), params)
                if not hit then return end

                local slope = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
                local lean = Vector3.new(up.X, 0, up.Z)
                local dir
                if slope.Magnitude > FLAT_SLOPE then
                    dir = slope.Unit
                elseif lean.Magnitude > 0.12 then
                    dir = lean.Unit
                else
                    dir = randomDir
                end

                local axis = Vector3.yAxis:Cross(dir)
                if axis.Magnitude < 1e-3 then return end
                axis = axis.Unit

                local ang = torso.AssemblyAngularVelocity
                if ang:Dot(axis) < TIP_MAX_SPIN then
                    local strength = 0.3 + 0.7 * up.Y
                    torso.AssemblyAngularVelocity = ang + axis * TIP_TORQUE * strength * dt
                end
            end))
        end
    end

    table.insert(ragConns, hum.StateChanged:Connect(function(_, new)
        if ragdolled and new ~= Enum.HumanoidStateType.Physics
            and new ~= Enum.HumanoidStateType.Dead then
            hum:ChangeState(Enum.HumanoidStateType.Physics)
        end
    end))

    for _, p in ipairs(char:GetChildren()) do
        if p:IsA("BasePart") then
            table.insert(ragConns, p.Touched:Connect(function(other)
                if not ragdolled or gettingUp then return end
                if not other.CanCollide or other:IsDescendantOf(char) then return end
                lastGroundTouch = os.clock()
                local speed = (p.AssemblyLinearVelocity - other.AssemblyLinearVelocity).Magnitude
                if speed < IMPACT_MIN_SPEED then return end
                if os.clock() - lastImpact < IMPACT_COOLDOWN then return end
                lastImpact = os.clock()
                playSound(SOUNDS_RAGDOLL, p)
                vfxImpact(p, other, speed, char)
            end))
        end
    end

    return true
end

local function disableRagdoll(instant)
    local char, hum, root = getChar()

    if camSubjectBackup then
        local cam = workspace.CurrentCamera
        if cam and hum and hum.Parent then cam.CameraSubject = hum end
        camSubjectBackup = nil
    end

    for _, c in ipairs(ragConns) do c:Disconnect() end
    table.clear(ragConns)

    for _, inst in ipairs(created) do
        if inst and inst.Parent then inst:Destroy() end
    end
    table.clear(created)

    local motorList = motors
    motors = {}

    local function finish()
        for p, v in pairs(collideBackup) do
            if p and p.Parent then p.CanCollide = v end
        end
        table.clear(collideBackup)
        for p, v in pairs(physBackup) do
            if p and p.Parent then p.CustomPhysicalProperties = v[1] end
        end
        table.clear(physBackup)
        if root and root.Parent then root.CanCollide = true end
        if hum and hum.Parent then
            hum.PlatformStand = false
            hum.AutoRotate = true
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        gettingUp = false
    end

    if instant or not (char and hum and root) then
        for _, m in ipairs(motorList) do
            if m and m.Parent then m.Enabled = true end
        end
        if root then
            local _, yaw = root.CFrame:ToEulerAnglesYXZ()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.CFrame = CFrame.new(root.Position + Vector3.new(0, 3, 0)) * CFrame.Angles(0, yaw, 0)
        end
        finish()
        return
    end

    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or root
    local faceUp = torso.CFrame.LookVector.Y > 0
    local head = Vector3.new(torso.CFrame.UpVector.X, 0, torso.CFrame.UpVector.Z)
    local yawCF
    if head.Magnitude > 0.2 then
        yawCF = CFrame.lookAt(Vector3.zero, faceUp and -head.Unit or head.Unit)
    else
        local _, yaw = root.CFrame:ToEulerAnglesYXZ()
        yawCF = CFrame.Angles(0, yaw, 0)
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}
    local origin = root.Position
    local hit = workspace:Raycast(origin, Vector3.new(0, -25, 0), params)
    local groundY = hit and hit.Position.Y or (origin.Y - 2.5)
    local r6Extra = (hum.RigType == Enum.HumanoidRigType.R6) and 2 or 0
    local standY = groundY + hum.HipHeight + root.Size.Y / 2 + r6Extra + 0.2

    local sc = 1
    pcall(function() sc = char:GetScale() end)
    local pitch = math.rad(faceUp and 90 or -90)
    local startCF = CFrame.new(origin.X, groundY + 1.1 * sc, origin.Z) * yawCF * CFrame.Angles(pitch, 0, 0)
    local endCF = CFrame.new(origin.X, standY, origin.Z) * yawCF

    local origC0, rnd = {}, {}
    for _, m in ipairs(motorList) do
        if m and m.Parent then
            if m:IsA("Motor6D") or m:IsA("Weld") then origC0[m] = m.C0 end
            rnd[m] = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2
            m.Enabled = true
        end
    end

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = startCF

    playSound(SOUND_GETUP, root)

    task.spawn(function()
        local t0 = os.clock()
        while true do
            if not (root and root.Parent and hum and hum.Parent) then break end
            local a = math.clamp((os.clock() - t0) / GETUP_TIME, 0, 1)
            local e = 1 - (1 - a) ^ 3
            local k = math.rad(45) * (1 - e)

            root.CFrame = startCF:Lerp(endCF, e)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero

            for m, c0 in pairs(origC0) do
                if m.Parent then
                    local r = rnd[m]
                    m.C0 = c0 * CFrame.Angles(r.X * k, r.Y * k * 0.5, r.Z * k * 0.5)
                end
            end

            if a >= 1 then break end
            RunService.Heartbeat:Wait()
        end

        for m, c0 in pairs(origC0) do
            if m.Parent then m.C0 = c0 end
        end
        if root and root.Parent then root.CFrame = endCF end
        finish()
    end)
end

local lastJump = 0

local function ragdollJump()
    if not ragdolled or gettingUp then return end
    if os.clock() - lastJump < JUMP_COOLDOWN then return end

    local char, hum, root = getChar()
    if not (char and hum and root) then return end

    if JUMP_NEEDS_GROUND and os.clock() - lastGroundTouch > 0.3 then
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char, fxFolder()}
        local sc = 1
        pcall(function() sc = char:GetScale() end)
        local len = 4.5 * sc
        local grounded = false
        for _, name in ipairs({"HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso",
            "Head", "LeftFoot", "RightFoot", "Left Leg", "Right Leg"}) do
            local part = char:FindFirstChild(name)
            if part and workspace:Raycast(part.Position, Vector3.new(0, -len, 0), params) then
                grounded = true
                break
            end
        end
        if not grounded then return end
    end

    lastJump = os.clock()
    playSound(SOUND_JUMP, root)

    local v = root.AssemblyLinearVelocity
    local dir = hum.MoveDirection
    local launch = Vector3.new(
        v.X + dir.X * JUMP_PUSH,
        JUMP_POWER,
        v.Z + dir.Z * JUMP_PUSH
    )

    for _, p in ipairs(char:GetChildren()) do
        if p:IsA("BasePart") then
            p.AssemblyLinearVelocity = launch
        end
    end

    root.AssemblyAngularVelocity = Vector3.new(
        math.random(-4, 4), math.random(-2, 2), math.random(-4, 4)
    )
end

local function refreshUI()
    if api.onChange then api.onChange() end
end

function setRagdoll(state)
    if state == ragdolled or gettingUp then return end
    if state then
        ragdolled = enableRagdoll()
        if ragdolled then
            local ponte = _G.__DedosRagdoll
            if ponte and ponte.ligar then pcall(ponte.ligar) end
        end
    else
        ragdolled = false
        gettingUp = true
        local ponte = _G.__DedosRagdoll
        if ponte and ponte.desligar then pcall(ponte.desligar) end
        disableRagdoll()
    end
    refreshUI()
end

RunService:BindToRenderStep("RagdollFX", Enum.RenderPriority.Camera.Value + 1, vfxStep)

local function userToggle()
    if api.request then api.request() else setRagdoll(not ragdolled) end
end

local persistent = {}

table.insert(persistent, UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if KEYBIND and input.KeyCode == KEYBIND then
        userToggle()
    end
end))

table.insert(persistent, UIS.JumpRequest:Connect(ragdollJump))

table.insert(persistent, UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space and not UIS:GetFocusedTextBox() then
        ragdollJump()
    end
end))

local function hookJump(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    table.insert(persistent, hum:GetPropertyChangedSignal("Jump"):Connect(function()
        if hum.Jump and ragdolled then
            ragdollJump()
            hum.Jump = false
        end
    end))
end
task.spawn(function()
    if player.Character then hookJump(player.Character) end
end)
table.insert(persistent, player.CharacterAdded:Connect(hookJump))

table.insert(persistent, player.CharacterAdded:Connect(function(char)
    ragdolled = false
    gettingUp = false
    camSubjectBackup = nil
    for _, c in ipairs(ragConns) do c:Disconnect() end
    table.clear(ragConns)
    table.clear(created); table.clear(motors); table.clear(collideBackup); table.clear(physBackup)
    refreshUI()
    local hum = char:WaitForChild("Humanoid", 10)
    if hum then
        hum.Died:Connect(function()
            ragdolled = false
            refreshUI()
        end)
    end
end))

env.__RagdollCleanup = function()
    do
        local ponte = _G.__DedosRagdoll
        if ponte and ponte.desligar then pcall(ponte.desligar) end
    end
    if ragdolled then pcall(disableRagdoll, true) end
    pcall(vfxCleanup)
    for _, c in ipairs(ragConns) do c:Disconnect() end
    for _, c in ipairs(persistent) do c:Disconnect() end
    for _, c in ipairs(connections) do c:Disconnect() end
    if ui.gui then ui.gui:Destroy() end
end

api.set = setRagdoll
api.toggle = function() setRagdoll(not ragdolled) end
api.isOn = function() return ragdolled end
api.busy = function() return gettingUp end
return api
end)()

-- ===== ÍCONES DESENHADOS (sem emoji, sem imagem): tudo feito com Frames + UICorner =====
-- Cada ícone é uma lista de formas numa grade 24x24: r = retângulo, c = círculo, l = linha (ponta redonda),
-- a = arco, q = retângulo girado. Usa só Scale, então o ícone escala para qualquer tamanho sem falhas.
T.Icones = (function()
	local M = {}
	local c3 = Color3.fromRGB
	local PAL = {
		blue = c3(88, 140, 250),
		blueD = c3(52, 92, 190),
		blueO = c3(24, 40, 100),
		blueL = c3(150, 190, 255),
		grnL = c3(150, 235, 185),
		pinkL = c3(255, 185, 200),
		orgL = c3(255, 195, 130),
		redL = c3(255, 150, 150),
		blush = c3(255, 150, 120),
		brn = c3(176, 120, 74),
		brnD = c3(124, 80, 46),
		brnO = c3(62, 38, 22),
		cyan = c3(120, 230, 255),
		cyanD = c3(40, 170, 230),
		cyanL = c3(200, 246, 255),
		cyanO = c3(14, 70, 120),
		dk = c3(40, 30, 40),
		gold = c3(255, 206, 70),
		goldD = c3(214, 150, 30),
		goldO = c3(110, 70, 10),
		grn = c3(62, 200, 128),
		grnD = c3(36, 140, 86),
		grnO = c3(14, 70, 44),
		gry = c3(200, 206, 222),
		gryD = c3(140, 148, 172),
		gryL = c3(236, 240, 250),
		gryO = c3(52, 58, 80),
		hole = c3(20, 22, 32),
		night = c3(34, 40, 86),
		org = c3(255, 150, 60),
		orgD = c3(220, 100, 30),
		orgO = c3(110, 50, 14),
		pink = c3(255, 130, 150),
		pinkD = c3(214, 84, 110),
		pinkO = c3(130, 40, 66),
		pur = c3(150, 110, 255),
		purD = c3(96, 64, 200),
		purL = c3(196, 170, 255),
		purO = c3(40, 24, 98),
		red = c3(236, 86, 92),
		redD = c3(176, 48, 60),
		redO = c3(100, 22, 34),
		skin = c3(255, 212, 166),
		skinD = c3(226, 164, 116),
		skinL = c3(255, 236, 208),
		skinO = c3(120, 70, 48),
		wh = c3(255, 255, 255),
		yel = c3(255, 214, 72),
		yelD = c3(240, 170, 40),
		yelL = c3(255, 240, 170),
		yelO = c3(122, 78, 20),
		pants = c3(92, 108, 176),
		pantsD = c3(60, 72, 132),
		nightD = c3(20, 24, 62),
		nightO = c3(10, 12, 38),
		brnL = c3(214, 160, 108),
		cheek = c3(255, 140, 120),
	}
	local DADOS = {
		["Tchau"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"blueD",0.9,"blueO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"blue",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"blueL",false,false},
			{"c",10.6,4.6,1.3,"blueL",false,false},
			{"a",12,11.4,9.6,158,205,1.2,"blueL",false,false},
			{"a",12,11.4,9.6,-25,22,1.2,"blueL",false,false},
			{"a",12,11.4,7.6,165,200,1,"blueL",false,false},
			{"a",12,11.4,7.6,-20,15,1,"blueL",false,false},
			{"l",8.49,17.55,17.01,16.35,2.6,"wh","T0.8","blueO"},
			{"q",12.08,12.19,8.4,7.6,-8,2.8,"skin","T0.8","blueO"},
			{"l",8.6,9.65,6.65,4.83,2.3,"skin","T0.8","blueO"},
			{"l",10.63,9.37,9.34,3.3,2.3,"skin","T0.8","blueO"},
			{"l",12.71,9.08,12.4,3.29,2.3,"skin","T0.8","blueO"},
			{"l",14.74,8.79,15.27,4.42,2.3,"skin","T0.8","blueO"},
			{"l",8.94,14.25,5.18,11.95,2.5,"skin","T0.8","blueO"},
		},
		["Paz"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"purD",0.9,"purO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"pur",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"purL",false,false},
			{"c",10.6,4.6,1.3,"purL",false,false},
			{"l",7.7,17.2,16.3,17.2,2.6,"wh","T0.8","purO"},
			{"q",12,12.4,8.4,7.6,0,2.8,"skin","T0.8","purO"},
			{"l",8.9,9.2,8.9,7.6,2.3,"skin","T0.8","purO"},
			{"l",10.95,9.4,9.58,2.94,2.3,"skin","T0.8","purO"},
			{"l",13.05,9.4,14.42,2.94,2.3,"skin","T0.8","purO"},
			{"l",15.1,9.2,15.1,7.6,2.3,"skin","T0.8","purO"},
			{"l",8.6,14,8.4,12.2,2.5,"skin","T0.8","purO"},
			{"q",5,6,1.09,2.6,0,0.52,"purL",false,false},
			{"q",5,6,2.6,1.09,0,0.52,"purL",false,false},
			{"q",19.4,5.4,0.84,2,0,0.4,"purL",false,false},
			{"q",19.4,5.4,2,0.84,0,0.4,"purL",false,false},
		},
		["Sim"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"grnD",0.9,"grnO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"grn",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"grnL",false,false},
			{"c",10.6,4.6,1.3,"grnL",false,false},
			{"q",10,11.2,12.6,12.6,0,4.03,"yel","T0.8","grnO"},
			{"r",6.2,8.6,2,3.4,1,"dk","D",false},
			{"r",11.8,8.6,2,3.4,1,"dk","D",false},
			{"c",7.2,9.4,0.9,"wh","D",false},
			{"c",12.8,9.4,0.9,"wh","D",false},
			{"a",10,11.8,3.4,25,155,1.5,"dk","D",false},
			{"c",4.8,13.4,2.4,"cheek","D",false},
			{"c",15.2,13.4,2.4,"cheek","D",false},
			{"l",18.2,8.6,19.8,7,1.3,"grnL",false,false},
			{"l",19.8,7,21.4,8.6,1.3,"grnL",false,false},
			{"l",18.2,13.6,19.8,15.2,1.3,"grnL",false,false},
			{"l",19.8,15.2,21.4,13.6,1.3,"grnL",false,false},
		},
		["Maçaneta"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"orgD",0.9,"orgO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"org",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"orgL",false,false},
			{"c",10.6,4.6,1.3,"orgL",false,false},
			{"q",12,11.4,13.4,13.4,0,4.29,"yel","T0.8","orgO"},
			{"r",6.4,10,4.6,3,1.2,"wh","D",false},
			{"r",13,10,4.6,3,1.2,"wh","D",false},
			{"c",9.6,11.6,1.7,"dk","D",false},
			{"c",16.2,11.6,1.7,"dk","D",false},
			{"r",6,8.8,5.4,1.5,0.6,"yelD","D",false},
			{"r",12.6,8.8,5.4,1.5,0.6,"yelD","D",false},
			{"l",13.4,7.2,18,6,1.1,"yelO","D",false},
			{"l",7.4,7.6,10.8,7.6,1.1,"yelO","D",false},
			{"l",8.4,16.2,14,15.4,1.1,"dk","D",false},
			{"l",14,15.4,15.6,14.2,1.1,"dk","D",false},
			{"c",5.8,14.8,2.2,"cheek","D",false},
		},
		["Apontar"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"blueD",0.9,"cyanO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"cyanD",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"cyanL",false,false},
			{"c",10.6,4.6,1.3,"cyanL",false,false},
			{"l",3.8,7.5,3.8,16.1,2.6,"wh","T0.8","cyanO"},
			{"q",8.6,11.8,8.4,7.6,90,2.8,"skin","T0.8","cyanO"},
			{"l",11.8,8.7,13.4,8.7,2.3,"skin","T0.8","cyanO"},
			{"l",11.6,10.75,18.8,10.75,2.3,"skin","T0.8","cyanO"},
			{"l",11.8,12.85,13.4,12.85,2.3,"skin","T0.8","cyanO"},
			{"l",11.8,14.9,13.4,14.9,2.3,"skin","T0.8","cyanO"},
			{"l",7,15.2,10.6,12.4,2.5,"skin","T0.8","cyanO"},
			{"a",20.2,8.6,1.8,-50,50,1,"cyanL",false,false},
			{"a",20.2,8.6,3.4,-50,50,1,"cyanL",false,false},
		},
		["Bow"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"blueD",0.9,"blueO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"blue",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"blueL",false,false},
			{"c",10.6,4.6,1.3,"blueL",false,false},
			{"l",10,13.4,10,18.4,2.8,"pants","T0.8","blueO"},
			{"r",8.6,17.8,4.6,2,1,"wh","T0.8","blueO"},
			{"q",13.2,11.6,6.4,4.6,-30,1.5,"wh","T0.8","blueO"},
			{"q",18.4,10,5.2,5.2,24,1.66,"yel","T0.8","blueO"},
			{"c",20,10.6,0.95,"dk","D",false},
			{"l",15,11.2,16.2,16,2.2,"yel","T0.8","blueO"},
			{"q",5.4,7,1.09,2.6,0,0.52,"blueL",false,false},
			{"q",5.4,7,2.6,1.09,0,0.52,"blueL",false,false},
			{"q",8.6,3.8,0.67,1.6,0,0.32,"blueL",false,false},
			{"q",8.6,3.8,1.6,0.67,0,0.32,"blueL",false,false},
		},
		["Dedo"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"redD",0.9,"redO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"red",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"redL",false,false},
			{"c",10.6,4.6,1.3,"redL",false,false},
			{"l",7.7,17.8,16.3,17.8,2.6,"wh","T0.8","redO"},
			{"q",12,13,8.4,7.6,0,2.8,"skin","T0.8","redO"},
			{"l",8.9,9.8,8.9,8.2,2.3,"skin","T0.8","redO"},
			{"l",10.95,10,10.95,4,2.3,"skin","T0.8","redO"},
			{"l",13.05,9.8,13.05,8.2,2.3,"skin","T0.8","redO"},
			{"l",15.1,9.8,15.1,8.2,2.3,"skin","T0.8","redO"},
			{"l",8.6,14.6,8.5,12.6,2.5,"skin","T0.8","redO"},
		},
		["Citação"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"pinkD",0.9,"pinkO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"pink",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"pinkL",false,false},
			{"c",10.6,4.6,1.3,"pinkL",false,false},
			{"l",8.13,17.49,16.71,18.09,2.6,"wh","T0.8","pinkO"},
			{"q",12.76,13,8.4,7.6,4,2.8,"skin","T0.8","pinkO"},
			{"l",11.92,9.93,11.92,3.53,2.3,"skin","T0.8","pinkO"},
			{"l",14.01,10.08,15.09,3.97,2.3,"skin","T0.8","pinkO"},
			{"l",16.06,10.22,17.7,5.71,2.3,"skin","T0.8","pinkO"},
			{"c",10.04,8.8,6.6,"skin","T0.8","pinkO"},
			{"c",10.04,8.8,3,"pink","D",false},
			{"c",8.34,6.9,1,"skinL","D",false},
			{"q",19.6,4.8,0.92,2.2,0,0.44,"pinkL",false,false},
			{"q",19.6,4.8,2.2,0.92,0,0.44,"pinkL",false,false},
		},
		["Sentido"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"goldD",0.9,"goldO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"gold",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"yelL",false,false},
			{"c",10.6,4.6,1.3,"yelL",false,false},
			{"l",9.6,9.8,6.4,12.6,2.4,"yel","T0.8","goldO"},
			{"l",6.4,12.6,10.6,13.4,2.4,"yel","T0.8","goldO"},
			{"l",14.4,9.8,17.6,12.6,2.4,"yel","T0.8","goldO"},
			{"l",17.6,12.6,13.4,13.4,2.4,"yel","T0.8","goldO"},
			{"l",10.4,14,10.4,18.2,2.8,"pants","T0.8","goldO"},
			{"l",13.6,14,13.6,18.2,2.8,"pants","T0.8","goldO"},
			{"r",8.6,17.8,3.8,1.9,0.9,"wh","T0.8","goldO"},
			{"r",13,17.8,3.8,1.9,0.9,"wh","T0.8","goldO"},
			{"q",12,11.4,6.8,6.2,0,1.8,"wh","T0.8","goldO"},
			{"c",14.2,10.6,1.8,"gold","D",false},
			{"c",14.2,10.6,0.8,"goldD","D",false},
			{"l",9.4,9.6,14.6,9.6,0.5,"gry","D",false},
			{"q",12,6.2,5.6,5.6,0,1.79,"yel","T0.8","goldO"},
			{"q",12,3.4,6.8,3,0,1.4,"redD","T0.8","goldO"},
			{"r",9.6,2.2,4.8,1,0.5,"red","D",false},
			{"c",10.4,6.8,0.95,"dk","D",false},
			{"c",13.6,6.8,0.95,"dk","D",false},
			{"l",11,8.4,13,8.4,0.7,"dk","D",false},
		},
		["Convidando"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"purD",0.9,"purO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"pur",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"purL",false,false},
			{"c",10.6,4.6,1.3,"purL",false,false},
			{"l",6.89,19.82,15.44,18.92,2.6,"wh","T0.8","purO"},
			{"q",10.66,14.6,8.4,7.6,-6,2.8,"skin","T0.8","purO"},
			{"l",7.25,11.74,7.08,10.15,2.3,"skin","T0.8","purO"},
			{"l",9.28,11.52,9.12,9.93,2.3,"skin","T0.8","purO"},
			{"l",11.37,11.3,11.21,9.71,2.3,"skin","T0.8","purO"},
			{"l",13.41,11.09,13.24,9.5,2.3,"skin","T0.8","purO"},
			{"l",7.45,16.54,7.35,13.74,2.5,"skin","T0.8","purO"},
			{"l",9.3,11.72,8.89,7.74,2.3,"skin","T0.8","purO"},
			{"l",8.89,7.74,12.15,5.79,2.3,"skin","T0.8","purO"},
			{"a",18,7.4,3.4,-70,70,1.1,"purL",false,false},
			{"a",18,7.4,5.4,-60,60,1,"purL",false,false},
		},
		["Dancinha"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"pinkD",0.9,"pinkO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"pink",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"pinkL",false,false},
			{"c",10.6,4.6,1.3,"pinkL",false,false},
			{"l",10.4,13.4,8,16,2.8,"pants","T0.8","pinkO"},
			{"l",8,16,6.6,18.8,2.8,"pants","T0.8","pinkO"},
			{"l",13,13.4,16,15.4,2.8,"pants","T0.8","pinkO"},
			{"l",16,15.4,14.4,18.4,2.8,"pants","T0.8","pinkO"},
			{"q",11.8,11,4.6,5.4,-6,1.5,"wh","T0.8","pinkO"},
			{"l",9.8,9.6,6.6,11.2,2.4,"yel","T0.8","pinkO"},
			{"l",6.6,11.2,5.2,14,2.4,"yel","T0.8","pinkO"},
			{"l",14,9.6,16.8,6.4,2.4,"yel","T0.8","pinkO"},
			{"l",16.8,6.4,18.4,3.8,2.4,"yel","T0.8","pinkO"},
			{"q",11.6,5.6,5.4,5.4,-8,1.73,"yel","T0.8","pinkO"},
			{"c",10.5,5.54,0.95,"dk","D",false},
			{"c",12.64,5.24,0.95,"dk","D",false},
			{"a",11.74,6.45,0.92,20,160,0.8,"dk","D",false},
			{"c",4.4,6.4,2,"gold","D",false},
			{"l",5.2,6.4,5.2,2.2,0.8,"gold","D",false},
			{"l",5.2,2.2,7,3,0.8,"gold","D",false},
		},
		["Cala a Boca"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"blueD",0.9,"cyanO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"cyanD",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"cyanL",false,false},
			{"c",10.6,4.6,1.3,"cyanL",false,false},
			{"q",12,8.6,13.2,13.2,0,4.22,"yel","T0.8","cyanO"},
			{"c",8.4,6.8,3,"wh","D",false},
			{"c",15.6,6.8,3,"wh","D",false},
			{"c",9,7,1.5,"dk","D",false},
			{"c",16.2,7,1.5,"dk","D",false},
			{"c",5.4,10.6,2,"cheek","D",false},
			{"c",18.6,10.6,2,"cheek","D",false},
			{"l",7.6,12.2,10.4,12.2,0.9,"dk","D",false},
			{"l",13.6,12.2,16.4,12.2,0.9,"dk","D",false},
			{"l",8.35,20.99,15.65,20.99,2.21,"wh","T0.8","cyanO"},
			{"q",12,16.91,7.14,6.46,0,2.38,"skin","T0.8","cyanO"},
			{"l",9.37,14.19,9.37,12.83,1.95,"skin","T0.8","cyanO"},
			{"l",11.11,14.36,11.11,11.3,1.95,"skin","T0.8","cyanO"},
			{"l",12.89,14.19,12.89,12.83,1.95,"skin","T0.8","cyanO"},
			{"l",14.63,14.19,14.63,12.83,1.95,"skin","T0.8","cyanO"},
			{"l",9.11,18.27,8.94,16.91,2.12,"skin","T0.8","cyanO"},
			{"a",20.4,5.2,2.2,-60,60,1,"cyanL",false,false},
		},
		["Braços Cruzados"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"gryO",0.9,"gryO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"gryD",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"gryL",false,false},
			{"c",10.6,4.6,1.3,"gryL",false,false},
			{"q",12,14.6,10.8,8.4,0,3,"wh","T0.8","gryO"},
			{"q",12,6.4,6.4,6.4,0,2.05,"yel","T0.8","gryO"},
			{"r",8.6,5,2.6,2,0.8,"wh","D",false},
			{"r",12.8,5,2.6,2,0.8,"wh","D",false},
			{"c",9.9,6.2,1,"dk","D",false},
			{"c",14.1,6.2,1,"dk","D",false},
			{"l",8.4,4.8,11.4,4.8,0.8,"yelD","D",false},
			{"l",12.6,4.8,15.6,4.8,0.8,"yelD","D",false},
			{"l",10.2,8.6,13.8,8.6,0.8,"dk","D",false},
			{"l",7,11.8,16.4,15.6,2.8,"yel","T0.8","gryO"},
			{"l",17,11.8,7.6,15.6,2.8,"yel","T0.8","gryO"},
			{"c",16.8,15.8,3,"yel","T0.8","gryO"},
			{"c",7.2,15.8,3,"yel","T0.8","gryO"},
		},
		["Deitado de Frente"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"orgD",0.9,"orgO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"org",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"orgL",false,false},
			{"c",10.6,4.6,1.3,"orgL",false,false},
			{"q",12.6,15.4,9.4,4.4,0,1.5,"wh","T0.8","orgO"},
			{"l",16.6,15.6,20.6,15.6,2.8,"pants","T0.8","orgO"},
			{"l",20.6,15.6,20.4,11.8,2.8,"pants","T0.8","orgO"},
			{"l",7.6,14.6,7.8,18.2,2.4,"yel","T0.8","orgO"},
			{"q",5.8,11.4,5.4,5.4,-6,1.73,"yel","T0.8","orgO"},
			{"c",4.4,11.2,0.95,"dk","D",false},
			{"l",3.6,13,4.8,13,0.7,"dk","D",false},
		},
		["Sentar"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"orgD",0.9,"orgO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"org",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"orgL",false,false},
			{"c",10.6,4.6,1.3,"orgL",false,false},
			{"l",5.6,4.8,5.6,18.6,1.8,"brnL","T0.8","orgO"},
			{"l",5.6,13.8,16.6,13.8,2,"brnL","T0.8","orgO"},
			{"l",15.6,13.8,15.6,19,1.8,"brnL","T0.8","orgO"},
			{"l",6,14,6,19,1.8,"brnL","T0.8","orgO"},
			{"q",10,10,4.6,5.6,0,1.5,"wh","T0.8","orgO"},
			{"l",10.2,12.6,16.2,12.4,2.8,"pants","T0.8","orgO"},
			{"l",16.2,12.6,16.6,17.8,2.6,"pants","T0.8","orgO"},
			{"r",15.4,17.4,4.6,2,1,"wh","T0.8","orgO"},
			{"l",10.4,9.2,13.2,11.6,2.2,"yel","T0.8","orgO"},
			{"q",10.8,4.8,5.2,5.2,0,1.66,"yel","T0.8","orgO"},
			{"c",12.6,4.6,0.95,"dk","D",false},
		},
		["Ajoelhar"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"grnD",0.9,"grnO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"grn",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"grnL",false,false},
			{"c",10.6,4.6,1.3,"grnL",false,false},
			{"q",9.8,10,4.6,5.6,0,1.5,"wh","T0.8","grnO"},
			{"l",9.6,12.8,14.4,13.2,2.8,"pants","T0.8","grnO"},
			{"l",14.4,13.4,14.8,18.2,2.6,"pants","T0.8","grnO"},
			{"r",14,17.8,4.6,2,1,"wh","T0.8","grnO"},
			{"l",9.2,13,8.4,17.6,2.8,"pants","T0.8","grnO"},
			{"l",8.4,17.8,3.6,17.8,2.6,"pants","T0.8","grnO"},
			{"l",10.2,9.2,13.6,11.8,2.2,"yel","T0.8","grnO"},
			{"q",10.6,4.8,5.2,5.2,0,1.66,"yel","T0.8","grnO"},
			{"c",12.4,4.6,0.95,"dk","D",false},
		},
		["Dormir"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"nightD",0.9,"nightO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"night",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"purL",false,false},
			{"c",10.6,4.6,1.3,"purL",false,false},
			{"r",3.2,7.8,2.2,10.6,0.8,"brnL","T0.8","nightO"},
			{"r",3.2,16.4,17.6,2.2,0.8,"brnL","T0.8","nightO"},
			{"r",18.6,12.8,2.2,5.8,0.8,"brnL","T0.8","nightO"},
			{"r",5.2,11,6.6,3.4,1.4,"wh","T0.8","nightO"},
			{"q",8,11.2,4.6,4.6,0,1.47,"yel","T0.8","nightO"},
			{"a",8.6,11.2,1,20,160,0.7,"dk","D",false},
			{"r",9.8,11.6,9.6,5,2,"blue","T0.8","nightO"},
			{"l",11.4,13.4,18,13.4,0.7,"blueD","D",false},
			{"l",12.4,4,15.4,4,1,"cyanL","D",false},
			{"l",15.4,4,12.4,7,1,"cyanL","D",false},
			{"l",12.4,7,15.4,7,1,"cyanL","D",false},
			{"l",17,7.4,19.2,7.4,1,"cyanL","D",false},
			{"l",19.2,7.4,17,9.6,1,"cyanL","D",false},
			{"l",17,9.6,19.2,9.6,1,"cyanL","D",false},
		},
		["Dormir2"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"nightD",0.9,"nightO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"night",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"purL",false,false},
			{"c",10.6,4.6,1.3,"purL",false,false},
			{"c",10.6,11.6,13.4,"gold","T0.8","nightO"},
			{"c",15,9.4,11,"night","D",false},
			{"r",7.6,12.4,3,0.1,0.1,"goldD","D",false},
			{"a",7.4,12.6,1.5,20,160,0.8,"goldO","D",false},
			{"c",5.6,14.6,1.9,"orgL","D",false},
			{"q",17.4,5.2,1.09,2.6,0,0.52,"yelL","D",false},
			{"q",17.4,5.2,2.6,1.09,0,0.52,"yelL","D",false},
			{"q",19.6,13,0.76,1.8,0,0.36,"yelL","D",false},
			{"q",19.6,13,1.8,0.76,0,0.36,"yelL","D",false},
			{"q",13.8,17,0.67,1.6,0,0.32,"yelL","D",false},
			{"q",13.8,17,1.6,0.67,0,0.32,"yelL","D",false},
			{"l",16,16.4,18.6,16.4,0.9,"cyanL","D",false},
			{"l",18.6,16.4,16,19,0.9,"cyanL","D",false},
			{"l",16,19,18.6,19,0.9,"cyanL","D",false},
		},
		["Ragdoll"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"purD",0.9,"purO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"pur",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"purL",false,false},
			{"c",10.6,4.6,1.3,"purL",false,false},
			{"l",10.2,13.6,7,16.4,2.8,"pants","T0.8","purO"},
			{"l",7,16.4,9.6,19,2.8,"pants","T0.8","purO"},
			{"l",12.4,14.2,16.2,15.4,2.8,"pants","T0.8","purO"},
			{"l",16.2,15.4,14.6,18.8,2.8,"pants","T0.8","purO"},
			{"q",11.6,10.6,4.6,5.4,32,1.5,"wh","T0.8","purO"},
			{"l",9.4,9,5.4,6.6,2.4,"yel","T0.8","purO"},
			{"l",5.4,6.6,4.2,10.4,2.4,"yel","T0.8","purO"},
			{"l",14,11,18.4,12.6,2.4,"yel","T0.8","purO"},
			{"l",18.4,12.6,20,8.6,2.4,"yel","T0.8","purO"},
			{"q",14.2,5.4,5.4,5.4,28,1.73,"yel","T0.8","purO"},
			{"l",12.2,4.4,13.8,6,0.8,"purD","D",false},
			{"l",12.2,6,13.8,4.4,0.8,"purD","D",false},
			{"l",14.8,5,16.4,6.6,0.8,"purD","D",false},
			{"l",14.8,6.6,16.4,5,0.8,"purD","D",false},
			{"q",5.2,4.6,0.84,2,0,0.4,"yelL",false,false},
			{"q",5.2,4.6,2,0.84,0,0.4,"yelL",false,false},
			{"q",19.8,15.8,0.67,1.6,0,0.32,"yelL",false,false},
			{"q",19.8,15.8,1.6,0.67,0,0.32,"yelL",false,false},
		},
		["Siririca"] = {
			{"c",12,12,22.6,"blue",0.9,"blueO"},
			{"a",12,12,9.6,20,95,1.7,"blueD",false,false},
			{"a",12,12,9.6,205,250,1.2,"blueL",false,false},
			{"q",8.8,12.2,5.4,5.4,45,0.6,"cyanL","T0.8","blueO"},
			{"c",8.8,14.4,8.6,"cyanL","T0.8","blueO"},
			{"q",16.6,7.4,3.6,3.6,45,0.4,"cyanL","T0.8","blueO"},
			{"c",16.6,9,6,"cyanL","T0.8","blueO"},
			{"q",16.4,16.2,3,3,45,0.3,"cyanL","T0.8","blueO"},
			{"c",16.4,17.6,5,"cyanL","T0.8","blueO"},
			{"a",8.8,14.4,3.4,20,80,0.9,"cyanD","D",false},
			{"c",7.2,12.8,1.6,"wh","D",false},
		},
		["De Quatro"] = {
			{"c",12,12,22.6,"org",0.9,"orgO"},
			{"a",12,12,9.6,20,95,1.7,"orgD",false,false},
			{"a",12,12,9.6,205,250,1.2,"orgL",false,false},
			{"l",4.4,20.4,19.6,20.4,1.6,"gryL","T0.8","orgO"},
			{"l",7.4,19,7.4,13.4,2.6,"wh","T0.8","orgO"},
			{"l",15,19,15,13.4,2.6,"wh","T0.8","orgO"},
			{"l",7.4,12.8,15,12.8,4.4,"wh","T0.8","orgO"},
			{"c",18.6,10.8,5.2,"wh","T0.8","orgO"},
			{"l",19.6,11.2,19.6,11.3,1,"dk","D",false},
		},
		["Socar"] = {
			{"c",12,12,22.6,"yel",0.9,"yelO"},
			{"a",12,12,9.6,20,95,1.7,"yelD",false,false},
			{"a",12,12,9.6,205,250,1.2,"yelL",false,false},
			{"l",7.6,17,14.2,10.4,7.6,"pur","T0.8","purO"},
			{"l",8.8,15.6,11.8,12.6,1.3,"purL","D",false},
			{"q",16.6,7.6,6.4,3.8,-45,1.8,"grn","T0.8","grnO"},
			{"l",17.4,6.8,20,4.2,1.8,"grn","T0.8","grnO"},
			{"l",16.4,7.4,18.2,9.2,0.7,"grnD","D",false},
		},
		["Kamehameha"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"nightD",0.9,"nightO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"night",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"purL",false,false},
			{"c",10.6,4.6,1.3,"purL",false,false},
			{"r",8,8.6,14,6.8,3,"cyanD",0,false},
			{"r",8,9.6,14.2,4.8,2.2,"cyan",0,false},
			{"r",8,10.6,14.4,2.8,1.4,"cyanL",0,false},
			{"r",8,11.4,14.4,1.2,0.6,"wh",0,false},
			{"c",8.6,12,11.6,"cyanD",0,false},
			{"c",8.6,12,9.2,"cyan",0,false},
			{"c",8.6,12,6.4,"cyanL",0,false},
			{"c",8.6,12,3.4,"wh",0,false},
			{"l",15.2,12,17.2,12,1,"cyanL",false,false},
			{"l",13.27,16.67,14.68,18.08,1,"cyanL",false,false},
			{"l",8.6,18.6,8.6,20.6,1,"cyanL",false,false},
			{"l",3.93,16.67,2.52,18.08,1,"cyanL",false,false},
			{"l",2,12,0,12,1,"cyanL",false,false},
			{"l",3.93,7.33,2.52,5.92,1,"cyanL",false,false},
			{"l",8.6,5.4,8.6,3.4,1,"cyanL",false,false},
			{"l",13.27,7.33,14.68,5.92,1,"cyanL",false,false},
			{"l",15,5.6,21,5.6,0.9,"cyanL",false,false},
			{"l",16.6,17.2,21,17.2,0.9,"cyanL",false,false},
		},
		["Pegar"] = {
			{"r",1.4,1.4,21.2,21.2,6.4,"orgD",0.9,"orgO"},
			{"r",1.4,1.4,21.2,18.4,6.4,"org",0,false},
			{"l",4.8,4.6,8.2,4.6,1.3,"orgL",false,false},
			{"c",10.6,4.6,1.3,"orgL",false,false},
			{"r",6,4.6,12,11.8,1.6,"brnL","T0.8","orgO"},
			{"r",10.8,4.6,2.4,11.8,0.4,"brn","D",false},
			{"l",6.8,7.8,17.2,7.8,0.6,"brn","D",false},
			{"r",2.2,10,4,7,2,"skin","T0.8","orgO"},
			{"r",17.8,10,4,7,2,"skin","T0.8","orgO"},
			{"l",5.2,10.4,8.2,10.4,2.4,"skin","T0.8","orgO"},
			{"l",18.8,10.4,15.8,10.4,2.4,"skin","T0.8","orgO"},
			{"l",5.2,14.2,8.2,14.2,2.4,"skin","T0.8","orgO"},
			{"l",18.8,14.2,15.8,14.2,2.4,"skin","T0.8","orgO"},
			{"q",12,2.4,0.76,1.8,0,0.36,"orgL",false,false},
			{"q",12,2.4,1.8,0.76,0,0.36,"orgL",false,false},
		},
		["_star_on"] = {
			{"l",12,13.2,12,8.69,5,"gold",0.9,"goldO"},
			{"l",12,13.2,12,7.3,3.8,"gold",0.9,"goldO"},
			{"l",12,13.2,12,5.98,2.6,"gold",0.9,"goldO"},
			{"l",12,13.2,12,5,1.5,"gold",0.9,"goldO"},
			{"l",12,13.2,16.29,11.81,5,"gold",0.9,"goldO"},
			{"l",12,13.2,17.62,11.38,3.8,"gold",0.9,"goldO"},
			{"l",12,13.2,18.86,10.97,2.6,"gold",0.9,"goldO"},
			{"l",12,13.2,19.8,10.67,1.5,"gold",0.9,"goldO"},
			{"l",12,13.2,14.65,16.85,5,"gold",0.9,"goldO"},
			{"l",12,13.2,15.47,17.98,3.8,"gold",0.9,"goldO"},
			{"l",12,13.2,16.24,19.04,2.6,"gold",0.9,"goldO"},
			{"l",12,13.2,16.82,19.83,1.5,"gold",0.9,"goldO"},
			{"l",12,13.2,9.35,16.85,5,"gold",0.9,"goldO"},
			{"l",12,13.2,8.53,17.98,3.8,"gold",0.9,"goldO"},
			{"l",12,13.2,7.76,19.04,2.6,"gold",0.9,"goldO"},
			{"l",12,13.2,7.18,19.83,1.5,"gold",0.9,"goldO"},
			{"l",12,13.2,7.71,11.81,5,"gold",0.9,"goldO"},
			{"l",12,13.2,6.38,11.38,3.8,"gold",0.9,"goldO"},
			{"l",12,13.2,5.14,10.97,2.6,"gold",0.9,"goldO"},
			{"l",12,13.2,4.2,10.67,1.5,"gold",0.9,"goldO"},
			{"c",12,13.2,8.4,"gold",0.9,"goldO"},
			{"l",9.6,8.6,10.8,6.8,0.8,"yelL",false,false},
			{"a",12,13.2,4.2,200,250,0.9,"yelL",false,false},
		},
		["_star_off"] = {
			{"l",12,13.2,12,8.69,5,"gryO",0.9,"gryD"},
			{"l",12,13.2,12,7.3,3.8,"gryO",0.9,"gryD"},
			{"l",12,13.2,12,5.98,2.6,"gryO",0.9,"gryD"},
			{"l",12,13.2,12,5,1.5,"gryO",0.9,"gryD"},
			{"l",12,13.2,16.29,11.81,5,"gryO",0.9,"gryD"},
			{"l",12,13.2,17.62,11.38,3.8,"gryO",0.9,"gryD"},
			{"l",12,13.2,18.86,10.97,2.6,"gryO",0.9,"gryD"},
			{"l",12,13.2,19.8,10.67,1.5,"gryO",0.9,"gryD"},
			{"l",12,13.2,14.65,16.85,5,"gryO",0.9,"gryD"},
			{"l",12,13.2,15.47,17.98,3.8,"gryO",0.9,"gryD"},
			{"l",12,13.2,16.24,19.04,2.6,"gryO",0.9,"gryD"},
			{"l",12,13.2,16.82,19.83,1.5,"gryO",0.9,"gryD"},
			{"l",12,13.2,9.35,16.85,5,"gryO",0.9,"gryD"},
			{"l",12,13.2,8.53,17.98,3.8,"gryO",0.9,"gryD"},
			{"l",12,13.2,7.76,19.04,2.6,"gryO",0.9,"gryD"},
			{"l",12,13.2,7.18,19.83,1.5,"gryO",0.9,"gryD"},
			{"l",12,13.2,7.71,11.81,5,"gryO",0.9,"gryD"},
			{"l",12,13.2,6.38,11.38,3.8,"gryO",0.9,"gryD"},
			{"l",12,13.2,5.14,10.97,2.6,"gryO",0.9,"gryD"},
			{"l",12,13.2,4.2,10.67,1.5,"gryO",0.9,"gryD"},
			{"c",12,13.2,8.4,"gryO",0.9,"gryD"},
			{"l",9.6,8.6,10.8,6.8,0.7,"gryD",false,false},
		},
		["_todos"] = {
			{"r",2.8,2.8,8.4,8.4,2.4,"blue",0.9,"blueO"},
			{"r",12.8,2.8,8.4,8.4,2.4,"pink",0.9,"pinkO"},
			{"r",2.8,12.8,8.4,8.4,2.4,"grn",0.9,"grnO"},
			{"r",12.8,12.8,8.4,8.4,2.4,"yel",0.9,"yelO"},
			{"l",4.2,4.4,4.2,6.6,0.8,"wh",false,false},
			{"l",14.2,4.4,14.2,6.6,0.8,"wh",false,false},
			{"l",4.2,14.4,4.2,16.6,0.8,"wh",false,false},
			{"l",14.2,14.4,14.2,16.6,0.8,"wh",false,false},
		},
		["_clone"] = {
			{"c",8.2,6.6,6.2,"gry",0.9,"gryO"},
			{"r",3.6,12.4,9.2,8.6,3.6,"gry",0.9,"gryO"},
			{"c",15.4,9.2,7.6,"skin","T0.9","skinO"},
			{"a",15.4,8.8,3.6,180,350,2.2,"brnD","D",false},
			{"r",9.6,16.6,11.8,6,3.4,"blue","T0.9","blueO"},
			{"l",14,9.8,14,9.8,0.9,"dk","D",false},
			{"l",17.2,9.8,17.2,9.8,0.9,"dk","D",false},
		},
		["_plus18"] = {
			{"r",1.6,5.2,20.8,13.6,5.4,"red",0.9,"redO"},
			{"a",12,12,8.2,205,250,0.9,"pink",false,false},
			{"l",4.6,12,8.4,12,1.5,"wh",false,false},
			{"l",6.5,10.1,6.5,13.9,1.5,"wh",false,false},
			{"l",11.3,9,11.3,15,1.5,"wh",false,false},
			{"l",9.8,10.2,11.3,9,1.2,"wh",false,false},
			{"a",16.6,10.6,1.5,0,360,1.15,"wh",false,false},
			{"a",16.6,13.5,1.9,0,360,1.15,"wh",false,false},
		},
		["_importar"] = {
			{"l",3.8,14,3.8,19,2.6,"gry",0.9,"gryO"},
			{"l",20.2,14,20.2,19,2.6,"gry",0.9,"gryO"},
			{"l",3.8,19.2,20.2,19.2,2.8,"gry",0.9,"gryO"},
			{"l",12,3.4,12,12.4,3.6,"cyan","T0.9","cyanO"},
			{"l",12,15.2,7.4,10.4,3.2,"cyan","T0.9","cyanO"},
			{"l",12,15.2,16.6,10.4,3.2,"cyan","T0.9","cyanO"},
			{"l",12,12,12,12.6,3.4,"cyan","D",false},
			{"l",10.8,4.6,10.8,10,0.8,"cyanL","D",false},
		},
		["_colar"] = {
			{"r",4.4,4.2,15.2,17.6,2.8,"brn",0.9,"brnO"},
			{"r",6.8,7.2,10.4,12.8,1.4,"gryL",0.9,"gryO"},
			{"l",8.6,11,15.4,11,0.9,"gryD",false,false},
			{"l",8.6,13.8,15.4,13.8,0.9,"gryD",false,false},
			{"l",8.6,16.6,12.6,16.6,0.9,"gryD",false,false},
			{"r",8.2,2.4,7.6,4.6,1.8,"gry","T0.9","gryO"},
			{"c",12,4.7,1.4,"gryO","D",false},
		},
		["_play"] = {
			{"l",8.2,6.6,8.2,17.4,3.4,"grn",0.9,"grnO"},
			{"l",8.2,17.4,16.8,12,3.4,"grn",0.9,"grnO"},
			{"l",16.8,12,8.2,6.6,3.4,"grn",0.9,"grnO"},
			{"r",8.2,6.75,0.2,0.9,0,"grn",0,false},
			{"r",8.2,7.55,1.57,0.9,0,"grn",0,false},
			{"r",8.2,8.35,2.93,0.9,0,"grn",0,false},
			{"r",8.2,9.15,4.3,0.9,0,"grn",0,false},
			{"r",8.2,9.95,5.67,0.9,0,"grn",0,false},
			{"r",8.2,10.75,7.03,0.9,0,"grn",0,false},
			{"r",8.2,11.55,8.4,0.9,0,"grn",0,false},
			{"r",8.2,12.35,7.03,0.9,0,"grn",0,false},
			{"r",8.2,13.15,5.67,0.9,0,"grn",0,false},
			{"r",8.2,13.95,4.3,0.9,0,"grn",0,false},
			{"r",8.2,14.75,2.93,0.9,0,"grn",0,false},
			{"r",8.2,15.55,1.57,0.9,0,"grn",0,false},
			{"l",9.2,7.6,9.2,11.6,0.8,"wh","D",false},
		},
		["_stop"] = {
			{"r",5.4,5.4,13.2,13.2,3,"red",0.9,"redO"},
			{"l",7.4,7.6,7.4,11.2,0.8,"pink",false,false},
		},
		["_trocar"] = {
			{"l",4,8,18.6,8,2.4,"cyan",0.9,"cyanO"},
			{"l",19.2,8,15,4.2,2.4,"cyan",0.9,"cyanO"},
			{"l",19.2,8,15,11.8,2.4,"cyan",0.9,"cyanO"},
			{"l",20,16,5.4,16,2.4,"pur",0.9,"purO"},
			{"l",4.8,16,9,12.2,2.4,"pur",0.9,"purO"},
			{"l",4.8,16,9,19.8,2.4,"pur",0.9,"purO"},
		},
		["_check"] = {
			{"l",5,12.8,9.8,17.6,3.6,"grn",0.9,"grnO"},
			{"l",9.8,17.6,19.4,6.6,3.6,"grn",0.9,"grnO"},
			{"l",6.2,12,9.8,15.6,0.8,"wh",false,false},
		},
		["_fechar"] = {
			{"l",6.4,6.4,17.6,17.6,3.2,"gry",0.9,"gryO"},
			{"l",17.6,6.4,6.4,17.6,3.2,"gry",0.9,"gryO"},
		},
		["_fechar_r"] = {
			{"l",6.4,6.4,17.6,17.6,3.4,"red",0.9,"redO"},
			{"l",17.6,6.4,6.4,17.6,3.4,"red",0.9,"redO"},
			{"l",7.2,8,8.6,9.4,0.8,"pink",false,false},
		},
		["_min"] = {
			{"l",5.6,12,18.4,12,3.6,"gry",0.9,"gryO"},
			{"l",7,11,12,11,0.8,"gryL",false,false},
		},
		["_restaurar"] = {
			{"r",4.4,4.4,15.2,15.2,3.6,"cyan",0.9,"cyanO"},
			{"r",8.6,8.6,6.8,6.8,1.4,"hole",false,false},
			{"l",6.2,7,6.2,11,0.8,"cyanL",false,false},
		},
		["_mais"] = {
			{"l",12,4.8,12,19.2,4,"wh",0.9,"purO"},
			{"l",4.8,12,19.2,12,4,"wh",0.9,"purO"},
		},
		["_pause"] = {
			{"r",5.6,4.6,5,14.8,1.8,"yel",0.9,"yelO"},
			{"r",13.4,4.6,5,14.8,1.8,"yel",0.9,"yelO"},
			{"l",7,6.6,7,11,0.8,"yelL",false,false},
			{"l",14.8,6.6,14.8,11,0.8,"yelL",false,false},
		},
		["_prev"] = {
			{"l",13.04,6.6,13.04,17.4,3.4,"cyan",0.9,"cyanO"},
			{"l",13.04,17.4,6.16,12,3.4,"cyan",0.9,"cyanO"},
			{"l",6.16,12,13.04,6.6,3.4,"cyan",0.9,"cyanO"},
			{"r",12.88,6.75,0.16,0.9,0,"cyan",0,false},
			{"r",11.78,7.55,1.26,0.9,0,"cyan",0,false},
			{"r",10.7,8.35,2.34,0.9,0,"cyan",0,false},
			{"r",9.6,9.15,3.44,0.9,0,"cyan",0,false},
			{"r",8.5,9.95,4.54,0.9,0,"cyan",0,false},
			{"r",7.42,10.75,5.62,0.9,0,"cyan",0,false},
			{"r",6.32,11.55,6.72,0.9,0,"cyan",0,false},
			{"r",7.42,12.35,5.62,0.9,0,"cyan",0,false},
			{"r",8.5,13.15,4.54,0.9,0,"cyan",0,false},
			{"r",9.6,13.95,3.44,0.9,0,"cyan",0,false},
			{"r",10.7,14.75,2.34,0.9,0,"cyan",0,false},
			{"r",11.78,15.55,1.26,0.9,0,"cyan",0,false},
			{"r",3.2,5.6,3,12.8,1.2,"cyan",0.9,"cyanO"},
		},
		["_next"] = {
			{"l",5.36,6.6,5.36,17.4,3.4,"cyan",0.9,"cyanO"},
			{"l",5.36,17.4,12.24,12,3.4,"cyan",0.9,"cyanO"},
			{"l",12.24,12,5.36,6.6,3.4,"cyan",0.9,"cyanO"},
			{"r",5.36,6.75,0.16,0.9,0,"cyan",0,false},
			{"r",5.36,7.55,1.26,0.9,0,"cyan",0,false},
			{"r",5.36,8.35,2.34,0.9,0,"cyan",0,false},
			{"r",5.36,9.15,3.44,0.9,0,"cyan",0,false},
			{"r",5.36,9.95,4.54,0.9,0,"cyan",0,false},
			{"r",5.36,10.75,5.62,0.9,0,"cyan",0,false},
			{"r",5.36,11.55,6.72,0.9,0,"cyan",0,false},
			{"r",5.36,12.35,5.62,0.9,0,"cyan",0,false},
			{"r",5.36,13.15,4.54,0.9,0,"cyan",0,false},
			{"r",5.36,13.95,3.44,0.9,0,"cyan",0,false},
			{"r",5.36,14.75,2.34,0.9,0,"cyan",0,false},
			{"r",5.36,15.55,1.26,0.9,0,"cyan",0,false},
			{"r",17.8,5.6,3,12.8,1.2,"cyan",0.9,"cyanO"},
		},
		["_copiar"] = {
			{"r",3.6,3.4,11.4,14.6,2.4,"gry",0.9,"gryO"},
			{"r",9.2,7.2,11.4,14.6,2.4,"gryL","T0.9","gryO"},
			{"l",11.4,11.4,17.8,11.4,0.9,"gryD","D",false},
			{"l",11.4,14.4,17.8,14.4,0.9,"gryD","D",false},
			{"l",11.4,17.4,15.2,17.4,0.9,"gryD","D",false},
		},
		["_chev_down"] = {
			{"l",6.4,9,12,15,3,"gryL",0.9,"gryO"},
			{"l",17.6,9,12,15,3,"gryL",0.9,"gryO"},
		},
		["_chev_right"] = {
			{"l",9,6.4,15,12,3,"gryL",0.9,"gryO"},
			{"l",9,17.6,15,12,3,"gryL",0.9,"gryO"},
		},
		["_gear"] = {
			{"q",20.2,12,4.2,4.6,90,0.9,"gry",0.9,"gryO"},
			{"q",17.8,17.8,4.2,4.6,135,0.9,"gry",0.9,"gryO"},
			{"q",12,20.2,4.2,4.6,180,0.9,"gry",0.9,"gryO"},
			{"q",6.2,17.8,4.2,4.6,225,0.9,"gry",0.9,"gryO"},
			{"q",3.8,12,4.2,4.6,270,0.9,"gry",0.9,"gryO"},
			{"q",6.2,6.2,4.2,4.6,315,0.9,"gry",0.9,"gryO"},
			{"q",12,3.8,4.2,4.6,360,0.9,"gry",0.9,"gryO"},
			{"q",17.8,6.2,4.2,4.6,405,0.9,"gry",0.9,"gryO"},
			{"c",12,12,14,"gry",0.9,"gryO"},
			{"a",12,12,5.6,200,260,1,"gryL",false,false},
			{"c",12,12,6.2,"hole",false,false},
		},
		["_menu"] = {
			{"c",11.6,13,16.6,"yel",1,"yelO"},
			{"a",11.6,13,7,25,85,1.1,"yelD",false,false},
			{"a",11.6,13,7,205,250,1,"yelL",false,false},
			{"r",7.85,10.8,1.7,2.8,0.85,"dk",false,false},
			{"r",13.65,10.8,1.7,2.8,0.85,"dk",false,false},
			{"c",8.7,11.6,0.7,"wh",false,false},
			{"c",14.5,11.6,0.7,"wh",false,false},
			{"a",11.6,12,4.8,38,142,1.3,"dk",false,false},
			{"c",7.2,14.8,2.2,"blush",false,false},
			{"c",16,14.8,2.2,"blush",false,false},
			{"q",19.6,4.6,1.5,3.6,0,0.75,"wh",1,"purO"},
			{"q",19.6,4.6,3.6,1.5,0,0.75,"wh",1,"purO"},
			{"q",21,10,0.8,1.92,0,0.4,"yelL",false,false},
			{"q",21,10,1.92,0.8,0,0.4,"yelL",false,false},
		},
		["_lock"] = {
			{"a",12,10.6,4.2,180,360,2.2,"gry",0.9,"gryO"},
			{"l",7.8,10.6,7.8,12,2.2,"gry",0.9,"gryO"},
			{"l",16.2,10.6,16.2,12,2.2,"gry",0.9,"gryO"},
			{"r",5.2,11,13.6,10.6,2.6,"gold",0.9,"goldO"},
			{"c",12,15.2,2.8,"dk",false,false},
			{"l",12,15.6,12,18.2,1.4,"dk",false,false},
			{"l",7.2,12.6,7.2,19,0.7,"yelL",false,false},
		},
		["_nenhum"] = {
			{"a",12,12,8.6,0,360,2.4,"red",0.9,"redO"},
			{"l",6.6,17.4,17.4,6.6,2.4,"red",0.9,"redO"},
		},
		["_novo"] = {
			{"q",11,12,3.6,8.64,0,1.8,"gold",0.9,"goldO"},
			{"q",11,12,8.64,3.6,0,1.8,"gold",0.9,"goldO"},
			{"q",19,5.2,1.6,3.84,0,0.8,"yelL",0.9,"goldO"},
			{"q",19,5.2,3.84,1.6,0,0.8,"yelL",0.9,"goldO"},
			{"q",18.4,18.6,1.2,2.88,0,0.6,"cyanL",0.9,"cyanO"},
			{"q",18.4,18.6,2.88,1.2,0,0.6,"cyanL",0.9,"cyanO"},
		},
	}

	local mrad, mcos, msin, msqrt, matan2, mdeg, mmax, mmin, mfloor, mabs =
		math.rad, math.cos, math.sin, math.sqrt, math.atan2, math.deg, math.max, math.min, math.floor, math.abs
	local MODELOS = {}
	local PX_BASE = 36

	local function expandirArco(p, out)
		local cx, cy, r, a1, a2, th, col, o, oc = p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9], p[10]
		local n = mmax(3, mfloor(mabs(a2 - a1) / 14) + 1)
		for i = 0, n - 1 do
			local s = a1 + (a2 - a1) * i / n
			local e = a1 + (a2 - a1) * (i + 1) / n
			out[#out + 1] = {
				"l", cx + r * mcos(mrad(s)), cy + r * msin(mrad(s)),
				cx + r * mcos(mrad(e)), cy + r * msin(mrad(e)), th, col, o, oc,
			}
		end
	end

	-- devolve cx, cy, w, h, rot, rad, cor, o, oc
	local function normalizar(p)
		local k = p[1]
		if k == "r" then
			return p[2] + p[4] / 2, p[3] + p[5] / 2, p[4], p[5], 0, p[6], p[7], p[8], p[9]
		elseif k == "c" then
			return p[2], p[3], p[4], p[4], 0, p[4] / 2, p[5], p[6], p[7]
		elseif k == "l" then
			local dx, dy = p[4] - p[2], p[5] - p[3]
			local dist = msqrt(dx * dx + dy * dy)
			return (p[2] + p[4]) / 2, (p[3] + p[5]) / 2, dist + p[6], p[6], mdeg(matan2(dy, dx)), p[6] / 2, p[7], p[8], p[9]
		end
		return p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9], p[10] -- q
	end

	local function peca(root, cx, cy, w, h, rot, rad, cor, z, minU)
		if w < minU then w = minU end
		if h < minU then h = minU end
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = cor
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(cx / 24, cy / 24)
		f.Size = UDim2.fromScale(w / 24, h / 24)
		f.Rotation = rot
		f.ZIndex = z
		local m = mmin(w, h)
		if rad > 0 then
			local u = Instance.new("UICorner")
			u.CornerRadius = UDim.new(mmin(0.5, rad / m), 0)
			u.Parent = f
		end
		f.Parent = root
	end

	local function montar(nome)
		local dados = DADOS[nome] or DADOS._novo
		local root = Instance.new("Frame")
		root.Name = "Icone"
		root.BackgroundTransparency = 1
		root.BorderSizePixel = 0
		root.Size = UDim2.fromOffset(PX_BASE, PX_BASE)
		local minU = 1.1 / (PX_BASE / 24)
		local lista = {}
		for _, p in ipairs(dados) do
			if p[1] == "a" then expandirArco(p, lista) else lista[#lista + 1] = p end
		end
		for _, p in ipairs(lista) do
			local cx, cy, w, h, rot, rad, col, o, oc = normalizar(p)
			local cor = PAL[col]
			if o == false then
				peca(root, cx, cy, w, h, rot, rad, cor, 4, minU) -- detalhe
			elseif o == 0 then
				peca(root, cx, cy, w, h, rot, rad, cor, 3, minU) -- preenchimento sem contorno
			elseif o == -1 then
				peca(root, cx, cy, w, h, rot, rad, cor, 1, minU) -- fundo
			elseif type(o) == "string" then
				if o:sub(1, 1) == "T" then -- por cima de tudo, com contorno
					local ow = tonumber(o:sub(2)) or 0
					if ow > 0 then
						peca(root, cx, cy, w + 2 * ow, h + 2 * ow, rot, rad + ow, PAL[oc], 5, minU)
					end
					peca(root, cx, cy, w, h, rot, rad, cor, 6, minU)
				else -- detalhe por cima de tudo
					peca(root, cx, cy, w, h, rot, rad, cor, 7, minU)
				end
			else
				peca(root, cx, cy, w + 2 * o, h + 2 * o, rot, rad + o, PAL[oc], 2, minU) -- contorno
				peca(root, cx, cy, w, h, rot, rad, cor, 3, minU)
			end
		end
		return root
	end

	-- Icones.criar(nome, pai, tamanhoEmPixels, { Position = ..., ZIndex = ..., Name = ... })
	-- emotes que ficam só com texto (sem ícone)
	local SEM_ICONE = { ["Chupada de Dedo"] = true }
	function M.semIcone(nome) return SEM_ICONE[nome] == true end

	function M.criar(nome, pai, px, props)
		if SEM_ICONE[nome] then -- frame vazio invisível: quem chama não precisa tratar nada
			local vazio = Instance.new("Frame")
			vazio.BackgroundTransparency = 1
			vazio.BorderSizePixel = 0
			vazio.Size = UDim2.fromOffset(0, 0)
			for k, v in pairs(props or {}) do if k ~= "Position" then vazio[k] = v end end
			vazio.Parent = pai
			return vazio
		end
		local modelo = MODELOS[nome]
		if not modelo then
			modelo = montar(nome)
			MODELOS[nome] = modelo
		end
		local f = modelo:Clone()
		f.Size = UDim2.fromOffset(px, px)
		for k, v in pairs(props or {}) do f[k] = v end
		f.Parent = pai
		return f
	end

	-- ---- helpers: trocam o ícone de um botão (texto vira ícone) ----
	local function limpar(pai)
		local ant = pai:FindFirstChild("IcBtn")
		if ant then ant:Destroy() end
	end
	function M.centro(pai, nome, px, z)
		limpar(pai)
		return M.criar(nome, pai, px, { Name = "IcBtn", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = z or 2 })
	end
	function M.lado(pai, nome, px, z, recuo)
		limpar(pai)
		return M.criar(nome, pai, px, { Name = "IcBtn", Position = UDim2.new(0, -recuo, 0.5, -math.floor(px / 2)), ZIndex = z or 2 })
	end
	function M.direita(pai, nome, px, z, folga)
		limpar(pai)
		return M.criar(nome, pai, px, { Name = "IcBtn", Position = UDim2.new(1, -(px + (folga or 0)), 0.5, -math.floor(px / 2)), ZIndex = z or 2 })
	end
	function M.limpar(pai) limpar(pai) end

	function M.tem(nome) return DADOS[nome] ~= nil end

	return M
end)()

local EMOTES = {
	{ nome = "Tchau", icone = "👋", cat = "Cumprimentos" },
	{ nome = "Paz", icone = "✌️", cat = "Cumprimentos" },
	{ nome = "Sim", icone = "🙂", cat = "Gestos" },
	{ nome = "Maçaneta", icone = "😏", cat = "+18" },
	{ nome = "Apontar", icone = "👉", cat = "Gestos", toggle = true },
	{ nome = "Bow", icone = "🙇", cat = "+18" },
	{ nome = "Dedo", icone = "🖕", cat = "Gestos" },
	{ nome = "Citação", icone = "👌", cat = "+18" },
	{ nome = "Sentido", icone = "🎖️", cat = "Gestos" },
	{ nome = "Convidando", icone = "😈", cat = "+18" },
	{ nome = "Dancinha", icone = "💃", cat = "Gestos", toggle = true },
	{ nome = "Cala a Boca", icone = "🤫", cat = "Gestos" },
	{ nome = "Braços Cruzados", icone = "😒", cat = "Gestos", toggle = true },
	{ nome = "Deitado de Frente", icone = "🐾", cat = "Gestos", toggle = true },
	{ nome = "Sentar", icone = "🪑", cat = "Gestos", toggle = true },
	{ nome = "Ajoelhar", icone = "🧎", cat = "Gestos", toggle = true },
	{ nome = "Dormir", icone = "🛌", cat = "Gestos", toggle = true },
	{ nome = "Dormir2", icone = "🛏️", cat = "Gestos", toggle = true },
	{ nome = "Ragdoll", icone = "🤸", cat = "Gestos", toggle = true },
	{ nome = "Pegar", icone = "🤲", cat = "Gestos", toggle = true },
	{ nome = "Siririca", icone = "💦", cat = "+18", toggle = true },
	{ nome = "Chupada de Dedo", icone = "👅", cat = "+18", toggle = true },
	{ nome = "De Quatro", icone = "🐕", cat = "+18", toggle = true },
	{ nome = "Socar", icone = "🍆", cat = "+18", toggle = true },
	{ nome = "Kamehameha", icone = "🌀", cat = "Gestos" },
}
local EMOTE_POR_NOME = {}
for _, e in ipairs(EMOTES) do EMOTE_POR_NOME[e.nome] = e end

local favList = { "Tchau", "Bow", "Paz" }
local favSet = {}
for _, n in ipairs(favList) do favSet[n] = true end

local ativoRefreshers = {}
local favRefreshers = {}

local SENHA_18 = "0000"
local lockRefreshers = {}
local function liberado18()
	return LocalPlayer:GetAttribute("Emote18Liberado") == true
end
local function liberar18()
	LocalPlayer:SetAttribute("Emote18Liberado", true)
	for _, f in ipairs(lockRefreshers) do f() end
end

local function refreshAtivos()
	for _, f in ipairs(ativoRefreshers) do f() end
end

local function emoteAtivo(nome)
	if nome == "Apontar" then return apontarCamera end
	if nome == "Ragdoll" then return Ragdoll.isOn() end
	if nome == "Pegar" then return Pegar.ativo == true end
	if EMOTES_TOGGLE[nome] then return currentEmote == nome and emoteTimer > 0 end
	return currentEmote == nome and (emoteTimer > 0 or freezeEmote)
end

local function tocarEmote(nome)
	local def = EMOTE_POR_NOME[nome]
	if def and def.cat == "+18" and not liberado18() then return end
	if nome == "Pegar" then -- pegar/soltar objeto agora é um emote do menu
		if Pegar.ativo then Pegar.soltar() else Pegar.pegar() end
		refreshAtivos()
		return
	end
	if nome == "Ragdoll" then
		local querLigar = not Ragdoll.isOn()
		local emoteAntes = currentEmote
		currentEmote = nil
		emoteTimer = 0
		siriricaTempo = 0
		task.spawn(function()
			if querLigar and emoteAntes ~= nil then

				RunService.RenderStepped:Wait()
				RunService.RenderStepped:Wait()
			end
			Ragdoll.set(querLigar)
		end)
		refreshAtivos()
		return
	end
	if Ragdoll.isOn() and (EMOTES_CORPO[nome] or EMOTES_IMOVEIS[nome]) then
		return
	end
	if nome == "Apontar" then
		apontarCamera = not apontarCamera
		if apontarCamera then
			currentEmote = nil
			emoteTimer = 0
			siriricaTempo = 0
		end
	elseif EMOTES_TOGGLE[nome] then

		if currentEmote == nome and emoteTimer > 0 then
			currentEmote = nil
			emoteTimer = 0
			siriricaTempo = 0
		else
			if nome ~= "Siririca" then siriricaTempo = 0 end
			currentEmote = nome
			emoteTimer = math.huge
			if nome == "Siririca" then siriricaTempo = 0 end
		end
	else
		if nome == "Kamehameha" and currentEmote == nome and emoteTimer > 0 then return end -- nao reinicia no meio do ciclo
		if nome ~= "Siririca" then siriricaTempo = 0 end
		currentEmote = nome
		emoteTimer = (nome == "Kamehameha") and KAME.ciclo or emoteDuration -- toca o ciclo inteiro uma vez
		if nome == "Siririca" then siriricaTempo = 0 end
	end
	refreshAtivos()
end

Ragdoll.onChange = refreshAtivos
Ragdoll.blocked = function() return currentEmote ~= nil and EMOTES_CORPO[currentEmote] == true end
Ragdoll.request = function() tocarEmote("Ragdoll") end

local function toggleFav(nome)
	if favSet[nome] then
		favSet[nome] = nil
		local i = table.find(favList, nome)
		if i then table.remove(favList, i) end
	else
		favSet[nome] = true
		table.insert(favList, nome)
	end
	for _, f in ipairs(favRefreshers) do f() end
end

local toggleMenu
local abrirPainelDev -- definido junto do painel dev
local configPreviewDev = false -- config: preview do Painel Dev (desativado por padrão)
local aoMudarPreviewDev -- definido junto do painel dev (mostra/esconde o preview na hora)
do
local MENU_W, MENU_H = 480, 320
local menuAberto = false
local catAtual = "Todos"
local CATEGORIAS = { "Todos", "Favoritos", "Clone", "+18" }

local Menu = new("CanvasGroup", {
	Name = "EmoteMenu", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(MENU_W, MENU_H), BackgroundColor3 = T.bg, GroupTransparency = 1,
	Visible = false, Parent = MainGui,
}, { round(18), outline(T.stroke, 1, 0.1) })
local menuScale = new("UIScale", { Parent = Menu })
ajustarEscala(menuScale, MENU_W, MENU_H)

-- título "Emotes" = botão disfarçado que abre o Painel Dev (parece só um texto)
btn({
	Text = "Emotes", Font = F.GothamBold, TextSize = 17, TextColor3 = T.text, TextXAlignment = LEFT,
	BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(80, 22), Parent = Menu,
}).MouseButton1Click:Connect(function() if abrirPainelDev then abrirPainelDev() end end)
txt({ Text = "Passe o mouse para ver o preview", TextSize = 10, TextColor3 = T.dim, Position = UDim2.fromOffset(16, 32), Size = UDim2.fromOffset(300, 14), Parent = Menu })

local closeMenuBtn = btn({
	Text = "", TextSize = 13, TextColor3 = T.sub, Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -38, 0, 10), Parent = Menu,
}, { round(13) })
hoverFX(closeMenuBtn, T.surface2, T.surface3)
T.Icones.centro(closeMenuBtn, "_fechar", 14, 2)

-- ===== configurações =====
local configBtn = btn({
	Text = "", TextSize = 15, TextColor3 = T.sub, Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -70, 0, 10), Parent = Menu,
}, { round(13) })
hoverFX(configBtn, T.surface2, T.surface3)
T.Icones.criar("_gear", configBtn, 18, { Position = UDim2.fromOffset(4, 4) })

local configOverlay = frame({
	BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1),
	Visible = false, ZIndex = 60, Active = true, Parent = Menu,
}, { round(18) })
local configCard = frame({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(300, 132),
	BackgroundColor3 = T.surface, ZIndex = 61, Parent = configOverlay,
}, { round(14), outline(T.stroke, 1, 0.2) })
txt({ Text = "Configurações", Font = F.GothamBold, TextSize = 14, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -60, 0, 18), ZIndex = 62, Parent = configCard })
local configClose = btn({
	Text = "", TextSize = 12, TextColor3 = T.sub, Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -36, 0, 10), ZIndex = 62, Parent = configCard,
}, { round(12) })
hoverFX(configClose, T.surface2, T.surface3)
T.Icones.centro(configClose, "_fechar", 12, 63)

local cfgRow = frame({
	BackgroundColor3 = T.surface2, Position = UDim2.fromOffset(12, 44), Size = UDim2.new(1, -24, 0, 56), ZIndex = 62, Parent = configCard,
}, { round(10) })
txt({ Text = "Preview do Painel Dev", Font = F.GothamMedium, TextSize = 12, Position = UDim2.fromOffset(12, 9), Size = UDim2.new(1, -76, 0, 16), ZIndex = 63, Parent = cfgRow })
txt({ Text = "mostra o boneco ao editar emotes", TextSize = 10, TextColor3 = T.dim, Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -76, 0, 14), ZIndex = 63, Parent = cfgRow })
local cfgSwitch = btn({
	BackgroundColor3 = T.surface3, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(40, 22), ZIndex = 63, Parent = cfgRow,
}, { round(11) })
local cfgKnob = frame({
	BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(16, 16), ZIndex = 64, Parent = cfgSwitch,
}, { round(8) })

local function pintarSwitch()
	local on = configPreviewDev
	tw(cfgSwitch, 0.12, { BackgroundColor3 = on and T.ok or T.surface3 })
	tw(cfgKnob, 0.12, { Position = UDim2.new(0, on and 21 or 3, 0.5, 0) })
end
pintarSwitch()

cfgSwitch.MouseButton1Click:Connect(function()
	configPreviewDev = not configPreviewDev
	pintarSwitch()
	if aoMudarPreviewDev then aoMudarPreviewDev(configPreviewDev) end
end)
configBtn.MouseButton1Click:Connect(function() configOverlay.Visible = not configOverlay.Visible end)
configClose.MouseButton1Click:Connect(function() configOverlay.Visible = false end)

local chipsBar = frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 54), Size = UDim2.new(1, -32, 0, 24), Parent = Menu }, {
	lista(6, Enum.FillDirection.Horizontal),
})
local chipRefs = {}

local GridScroll = new("ScrollingFrame", {
	BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 88), Size = UDim2.new(0, 286, 1, -88 - 34),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
	ScrollBarImageColor3 = T.stroke, Parent = Menu,
}, {
	new("UIGridLayout", { CellSize = UDim2.fromOffset(84, 88), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	padding(2, 2, 6, 6),
})
local semFavLabel = txt({
	Text = "Nenhum favorito ainda.\nToque na estrela de um emote para fixar.", TextWrapped = true, TextSize = 12, TextColor3 = T.dim,
	TextXAlignment = CENTER, Position = UDim2.fromOffset(16, 120), Size = UDim2.fromOffset(286, 40), Visible = false, Parent = Menu,
})

local previewPane = frame({
	Position = UDim2.fromOffset(MENU_W - 16 - 150, 88), Size = UDim2.new(0, 150, 1, -88 - 34), Parent = Menu,
}, { round(14), outline(T.stroke, 1, 0.5) })
local previewVP = novoViewport({ Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 136), BackgroundColor3 = T.bg, Parent = previewPane })
local menuPreview = criarPreview(previewVP)
local previewNome = txt({ Text = "—", Font = F.GothamBold, TextSize = 14, Position = UDim2.fromOffset(40, 148), Size = UDim2.new(1, -50, 0, 18), Parent = previewPane })
local previewCat = txt({ Text = "", TextSize = 11, TextColor3 = T.dim, Position = UDim2.fromOffset(40, 166), Size = UDim2.new(1, -50, 0, 14), Parent = previewPane })

local clonePanel, atualizarClonePanel = (function()
	local function CS() return _G.__ClonesHands end

	local painel = frame({
		BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 88), Size = UDim2.new(1, -32, 1, -88 - 34),
		Visible = false, Parent = Menu,
	})

	local skinBox = new("TextBox", {
		BackgroundColor3 = T.surface2, BorderSizePixel = 0, Font = F.Gotham, TextSize = 12, TextColor3 = T.text,
		PlaceholderText = "Skin de quem? (vazio = a minha)", PlaceholderColor3 = T.dim,
		ClearTextOnFocus = false, Text = "", TextXAlignment = LEFT, ClipsDescendants = true,
		Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -196, 0, 30), Parent = painel,
	}, { round(8), padding(10, 0, 10, 0), outline(T.stroke, 1, 0.5) })

	local criarBtn = btn({
		Text = "Criar", TextSize = 12, Font = F.GothamBold, BackgroundColor3 = T.accent, TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(1, -188, 0, 0), Size = UDim2.fromOffset(90, 30), Parent = painel,
	}, { round(8), padding(22, 0, 6, 0) })
	T.Icones.lado(criarBtn, "_mais", 14, 2, 18)
	hoverFX(criarBtn, T.accent, Color3.fromRGB(148, 134, 255))

	local removerTodosBtn = btn({
		Text = "Remover todos", TextSize = 11, TextColor3 = T.sub,
		Position = UDim2.new(1, -92, 0, 0), Size = UDim2.fromOffset(92, 30), Parent = painel,
	}, { round(8) })
	hoverFX(removerTodosBtn, T.surface2, T.surface3)

	local status = txt({
		Text = "O clone aparece só pra você. Skin de outro jogador funciona mesmo fora do servidor.",
		TextSize = 10, TextColor3 = T.dim, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(2, 34), Size = UDim2.new(1, -4, 0, 14), Parent = painel,
	})

	local listaFrame = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.stroke, Parent = painel,
	}, { lista(6), padding(0, 0, 6, 0) })

	local vazioLabel = txt({
		Text = "Nenhum clone ainda.\nDigite um usuário (ou deixe vazio) e toque em Criar.", TextWrapped = true,
		TextSize = 12, TextColor3 = T.dim, TextXAlignment = CENTER,
		Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 40), Visible = false, Parent = painel,
	})

	local pickerOverlay = btn({
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1),
		Visible = false, ZIndex = 20, Parent = painel,
	}, { round(10) })
	local pickerCard = frame({
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(230, 182),
		BackgroundColor3 = T.surface, ZIndex = 21, Active = true, Parent = pickerOverlay,
	}, { round(12), outline(T.stroke, 1, 0.3) })
	txt({
		Text = "Emote do clone", Font = F.GothamBold, TextSize = 13, Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 18), ZIndex = 22, Parent = pickerCard,
	})
	local pickerLista = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 30), Size = UDim2.new(1, -16, 1, -38),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.stroke, ZIndex = 22, Parent = pickerCard,
	}, { lista(3), padding(0, 0, 4, 0) })
	local pickerAlvo = nil

	local function fecharPicker()
		pickerOverlay.Visible = false
		pickerAlvo = nil
	end
	pickerOverlay.MouseButton1Click:Connect(fecharPicker)

	local function abrirPicker(cloneId)
		pickerAlvo = cloneId
		for _, ch in ipairs(pickerLista:GetChildren()) do
			if ch:IsA("GuiObject") then ch:Destroy() end
		end
		local function item(rotulo, nome, ordem, ic)
			local b = btn({
				Text = "", BackgroundColor3 = T.surface2, LayoutOrder = ordem,
				Size = UDim2.new(1, 0, 0, 26), ZIndex = 23, Parent = pickerLista,
			}, { round(7) })
			T.Icones.criar(ic, b, 20, { Position = UDim2.fromOffset(6, 3), ZIndex = 24 })
			txt({ Text = rotulo, Font = F.GothamMedium, TextSize = 12, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -38, 1, 0), ZIndex = 24, Parent = b })
			hoverFX(b, T.surface2, T.surface3)
			b.MouseButton1Click:Connect(function()
				local cs = CS()
				if cs and pickerAlvo then cs.setEmote(pickerAlvo, nome) end
				fecharPicker()
			end)
		end
		item("Nenhum", nil, 0, "_nenhum")
		local cs = CS()
		if cs then
			for i, e in ipairs(cs.emotesDisponiveis()) do
				item(e.nome, e.nome, i, e.nome)
			end
		end
		pickerLista.CanvasPosition = Vector2.zero
		pickerOverlay.Visible = true
	end

	local function atualizar()
		local cs = CS()
		for _, ch in ipairs(listaFrame:GetChildren()) do
			if ch:IsA("GuiObject") then ch:Destroy() end
		end
		local lst = cs and cs.lista() or {}
		vazioLabel.Visible = (#lst == 0)

		for i, c in ipairs(lst) do
			local linha = frame({
				BackgroundColor3 = T.surface, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 40), Parent = listaFrame,
			}, { round(10), outline(T.stroke, 1, 0.5) })

			txt({
				Text = c.nome, Font = F.GothamBold, TextSize = 12, Position = UDim2.fromOffset(10, 5),
				Size = UDim2.fromOffset(104, 16), TextTruncate = Enum.TextTruncate.AtEnd, Parent = linha,
			})
			txt({
				Text = c.skin, TextSize = 9, TextColor3 = T.dim, Position = UDim2.fromOffset(10, 21),
				Size = UDim2.fromOffset(104, 13), TextTruncate = Enum.TextTruncate.AtEnd, Parent = linha,
			})

			local emoteDef = c.emote and EMOTE_POR_NOME[c.emote]
			local emoteBtn = btn({
				Text = emoteDef and c.emote or "Emote: nenhum", TextSize = 11,
				TextColor3 = c.emote and T.text or T.sub, BackgroundColor3 = c.emote and T.accentSoft or T.surface2,
				TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(120, 6), Size = UDim2.fromOffset(140, 28),
				Parent = linha,
			}, { round(8), padding(emoteDef and 30 or 8, 0, 8, 0) })
			hoverFX(emoteBtn, c.emote and T.accentSoft or T.surface2, T.surface3)
			if emoteDef then T.Icones.criar(emoteDef.nome, emoteBtn, 18, { Position = UDim2.new(0, -24, 0.5, -9) }) end
			emoteBtn.MouseButton1Click:Connect(function() abrirPicker(c.id) end)

			local seguirBtn = btn({
				Text = c.seguir and "Parar" or "Seguir", TextSize = 11, Font = F.GothamBold,
				TextColor3 = c.seguir and Color3.new(1, 1, 1) or T.text,
				BackgroundColor3 = c.seguir and T.accent or T.surface2,
				Position = UDim2.fromOffset(266, 6), Size = UDim2.fromOffset(78, 28), Parent = linha,
			}, { round(8), padding(22, 0, 6, 0) })
			T.Icones.criar(c.seguir and "_stop" or "_play", seguirBtn, 16, { Position = UDim2.new(0, -17, 0.5, -8), ZIndex = 3 })
			hoverFX(seguirBtn, c.seguir and T.accent or T.surface2, c.seguir and Color3.fromRGB(148, 134, 255) or T.surface3)
			seguirBtn.MouseButton1Click:Connect(function()
				local cs2 = CS()
				if cs2 then cs2.setSeguir(c.id, not c.seguir) end
			end)

			local removerBtn = btn({
				Text = "Remover", TextSize = 11, TextColor3 = T.danger, BackgroundColor3 = T.surface2,
				Position = UDim2.fromOffset(350, 6), Size = UDim2.fromOffset(78, 28), Parent = linha,
			}, { round(8) })
			hoverFX(removerBtn, T.surface2, T.surface3)
			removerBtn.MouseButton1Click:Connect(function()
				local cs2 = CS()
				if cs2 then cs2.remover(c.id) end
			end)
		end
	end

	local criando = false
	local function tentarCriar()
		local cs = CS()
		if not cs or criando then return end
		criando = true
		status.TextColor3 = T.sub
		status.Text = "Criando clone..."
		task.spawn(function()
			local ok, msg = cs.criar(skinBox.Text)
			criando = false
			if ok then
				status.TextColor3 = msg and T.warn or T.ok
				status.Text = msg or "Clone criado!"
			else
				status.TextColor3 = T.danger
				status.Text = msg or "Não deu pra criar o clone."
			end
		end)
	end
	criarBtn.MouseButton1Click:Connect(tentarCriar)
	skinBox.FocusLost:Connect(function(enter)
		if enter then tentarCriar() end
	end)

	removerTodosBtn.MouseButton1Click:Connect(function()
		local cs = CS()
		if cs then cs.removerTodos() end
		status.TextColor3 = T.dim
		status.Text = "Clones removidos."
	end)

	local function registrar()
		local cs = CS()
		if cs then cs.onChange = atualizar end
		atualizar()
	end

	return painel, registrar
end)()

local function mostrarPreview(e)
	if not e then return end
	previewNome.Text = e.nome
	local antigo = previewPane:FindFirstChild("IconeAtual")
	if antigo then antigo:Destroy() end
	T.Icones.criar(e.nome, previewPane, 24, { Name = "IconeAtual", Position = UDim2.fromOffset(10, 152) })
	previewCat.Text = e.cat .. (e.toggle and " • liga/desliga" or "")
	menuPreview.setEmote(e.nome)
end

local cardRefs = {}

local function passaFiltro(e)
	local bloqueado = (e.cat == "+18" and not liberado18())
	if catAtual == "Todos" then return e.cat ~= "+18" end
	if catAtual == "Favoritos" then return favSet[e.nome] == true and not bloqueado end
	return e.cat == catAtual and not bloqueado
end

local function atualizarCards()
	for nome, r in pairs(cardRefs) do
		local ativo = emoteAtivo(nome)
		r.card.BackgroundColor3 = ativo and T.accentSoft or T.surface
		r.stroke.Color = ativo and T.accent or T.stroke
		r.stroke.Transparency = ativo and 0 or 0.5
		r.dot.Visible = ativo
		local fav = favSet[nome] and true or false
		local sOn, sOff = r.star:FindFirstChild("On"), r.star:FindFirstChild("Off")
		if sOn then sOn.Visible = fav end
		if sOff then sOff.Visible = not fav end
	end
end

local function construirCards()
	for _, c in ipairs(GridScroll:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	cardRefs = {}

	local modoClone = (catAtual == "Clone")
	GridScroll.Visible = not modoClone
	previewPane.Visible = not modoClone
	clonePanel.Visible = modoClone
	if modoClone then
		semFavLabel.Visible = false
		atualizarClonePanel()
		return
	end
	local n = 0
	for i, e in ipairs(EMOTES) do
		if passaFiltro(e) then
			n += 1
			local card = btn({ BackgroundColor3 = T.surface, LayoutOrder = i, Parent = GridScroll }, { round(14) })
			local st = outline(T.stroke, 1, 0.5)
			st.Parent = card
			T.Icones.criar(e.nome, card, 36, { Position = UDim2.new(0.5, -18, 0, 9) })
			local soTexto = T.Icones.semIcone(e.nome)
			txt({ Text = e.nome, Font = F.GothamMedium, TextSize = soTexto and 13 or 11, TextXAlignment = CENTER, Position = UDim2.fromOffset(0, soTexto and 26 or 48), Size = UDim2.new(1, 0, 0, 16), Parent = card })
			txt({ Text = e.cat, TextSize = 9, TextColor3 = T.dim, TextXAlignment = CENTER, Position = UDim2.fromOffset(0, soTexto and 44 or 65), Size = UDim2.new(1, 0, 0, 14), Parent = card })
			local dot = frame({ BackgroundColor3 = T.ok, Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(10, 10), Visible = false, Parent = card }, { round(4) })
			local star = btn({
				BackgroundTransparency = 1, Text = "", TextSize = 16, Size = UDim2.fromOffset(26, 26),
				Position = UDim2.new(1, -28, 0, 2), ZIndex = 3, Parent = card,
			})
			T.Icones.criar("_star_on", star, 18, { Name = "On", Position = UDim2.fromOffset(4, 4), ZIndex = 4, Visible = false })
			T.Icones.criar("_star_off", star, 18, { Name = "Off", Position = UDim2.fromOffset(4, 4), ZIndex = 4 })
			star.MouseButton1Click:Connect(function() toggleFav(e.nome) end)
			card.MouseEnter:Connect(function()
				if not emoteAtivo(e.nome) then tw(card, 0.12, { BackgroundColor3 = T.surface2 }) end
				mostrarPreview(e)
			end)
			card.MouseLeave:Connect(function() atualizarCards() end)
			card.MouseButton1Click:Connect(function()
				tocarEmote(e.nome)
				task.defer(function() toggleMenu(false) end)
			end)
			cardRefs[e.nome] = { card = card, stroke = st, dot = dot, star = star }
		end
	end
	semFavLabel.Visible = (n == 0 and catAtual == "Favoritos")
	atualizarCards()
end

local function atualizarChips()
	for nome, r in pairs(chipRefs) do
		local sel = (nome == catAtual)
		r.BackgroundColor3 = sel and T.accent or T.surface2
		r.TextColor3 = sel and Color3.new(1, 1, 1) or T.sub
	end
end

local senhaOverlay = frame({
	BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1),
	Active = true, Visible = false, ZIndex = 50, Parent = Menu,
})
local senhaCard = frame({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(260, 156),
	BackgroundColor3 = T.surface, ZIndex = 51, Parent = senhaOverlay,
}, { round(14), outline(T.stroke, 1, 0.3) })
T.Icones.criar("_lock", senhaCard, 20, { Position = UDim2.fromOffset(20, 13), ZIndex = 52 })
txt({ Text = "Categoria +18", Font = F.GothamBold, TextSize = 14, Position = UDim2.fromOffset(46, 14), Size = UDim2.new(1, -66, 0, 18), ZIndex = 52, Parent = senhaCard })
txt({ Text = "Digite a senha para liberar", TextSize = 11, TextColor3 = T.dim, Position = UDim2.fromOffset(20, 34), Size = UDim2.new(1, -40, 0, 14), ZIndex = 52, Parent = senhaCard })
local senhaBox = new("TextBox", {
	BackgroundColor3 = T.surface3, BorderSizePixel = 0, Font = F.Code, TextSize = 14, TextColor3 = T.text,
	PlaceholderText = "Senha", PlaceholderColor3 = T.dim, ClearTextOnFocus = false, Text = "",
	Position = UDim2.fromOffset(20, 58), Size = UDim2.new(1, -40, 0, 30), ZIndex = 52, Parent = senhaCard,
}, { round(8) })
local senhaErro = txt({ Text = "", TextSize = 11, TextColor3 = T.danger, Position = UDim2.fromOffset(20, 92), Size = UDim2.new(1, -40, 0, 14), ZIndex = 52, Parent = senhaCard })
local senhaCancelar = btn({
	Text = "Cancelar", TextSize = 12, TextColor3 = T.sub, Position = UDim2.fromOffset(20, 114), Size = UDim2.new(0.5, -26, 0, 28), ZIndex = 52, Parent = senhaCard,
}, { round(8) })
local senhaEntrar = btn({
	Text = "Entrar", TextSize = 12, Font = F.GothamBold, BackgroundColor3 = T.accent, TextColor3 = Color3.new(1, 1, 1),
	Position = UDim2.new(0.5, 6, 0, 114), Size = UDim2.new(0.5, -26, 0, 28), ZIndex = 52, Parent = senhaCard,
}, { round(8) })
hoverFX(senhaCancelar, T.surface2, T.surface3)
hoverFX(senhaEntrar, T.accent, Color3.fromRGB(148, 134, 255))

local function abrirSenha()
	senhaBox.Text = ""
	senhaErro.Text = ""
	senhaOverlay.Visible = true
	task.defer(function() senhaBox:CaptureFocus() end)
end
local function fecharSenha()
	senhaBox:ReleaseFocus()
	senhaOverlay.Visible = false
end
local function tentarSenha()
	if senhaBox.Text == SENHA_18 then
		liberar18()
		fecharSenha()
		catAtual = "+18"
		atualizarChips()
		construirCards()
	else
		senhaErro.Text = "Senha incorreta"
		senhaBox.Text = ""
		task.defer(function() senhaBox:CaptureFocus() end)
	end
end
senhaEntrar.MouseButton1Click:Connect(tentarSenha)
senhaCancelar.MouseButton1Click:Connect(fecharSenha)
senhaBox.FocusLost:Connect(function(enter) if enter then tentarSenha() end end)

for i, nome in ipairs(CATEGORIAS) do
	local chip = btn({
		Text = nome, TextSize = 10, Font = F.GothamMedium, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0), LayoutOrder = i, Parent = chipsBar,
	}, { round(12), padding(nome == "+18" and 10 or 28, 0, 10, 0) })
	local icAba = ({ Todos = "_todos", Favoritos = "_star_on", Clone = "_clone" })[nome]
	if icAba then T.Icones.criar(icAba, chip, 14, { Name = "IconeAba", Position = UDim2.new(0, -19, 0.5, -7), ZIndex = 3 }) end
	chip.MouseButton1Click:Connect(function()
		if nome == "+18" and not liberado18() then abrirSenha() return end
		catAtual = nome
		atualizarChips()
		construirCards()
	end)
	chipRefs[nome] = chip
end
atualizarChips()

local function atualizarLockChip()
	local chip18 = chipRefs["+18"]
	chip18.Text = "+18"
	local trava = chip18:FindFirstChild("Trava")
	local pad = chip18:FindFirstChildOfClass("UIPadding")
	if liberado18() then
		if trava then trava:Destroy() end
		if pad then pad.PaddingLeft = UDim.new(0, 28) end
		if not chip18:FindFirstChild("Mais18") then T.Icones.criar("_plus18", chip18, 16, { Name = "Mais18", Position = UDim2.new(0, -20, 0.5, -8), ZIndex = 3 }) end
	else
		local m18 = chip18:FindFirstChild("Mais18")
		if m18 then m18:Destroy() end
		if pad then pad.PaddingLeft = UDim.new(0, 28) end
		if not trava then T.Icones.criar("_lock", chip18, 14, { Name = "Trava", Position = UDim2.new(0, -19, 0.5, -7) }) end
	end
end
atualizarLockChip()
table.insert(lockRefreshers, atualizarLockChip)

table.insert(ativoRefreshers, atualizarCards)
table.insert(favRefreshers, function() construirCards() end)

function toggleMenu(abrir)
	if abrir == nil then abrir = not menuAberto end
	if abrir == menuAberto then return end
	menuAberto = abrir
	if abrir then
		Menu.Visible = true
		Menu.Position = UDim2.new(0.5, 0, 0.5, 14)
		Menu.GroupTransparency = 1
		tw(Menu, 0.22, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quint)
		construirCards()
		menuPreview.setActive(true)
		menuPreview.setCustom(false)
		mostrarPreview(EMOTE_POR_NOME[currentEmote or ""] or EMOTES[1])
	else
		senhaOverlay.Visible = false
		configOverlay.Visible = false
		tw(Menu, 0.16, { GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 10) })
		menuPreview.setActive(false)
		task.delay(0.17, function()
			if not menuAberto then Menu.Visible = false end
		end)
	end
end
closeMenuBtn.MouseButton1Click:Connect(function() toggleMenu(false) end)
end

local EmoteButton = btn({
	Text = "", BackgroundColor3 = Color3.new(1, 1, 1),
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 64), Size = UDim2.fromOffset(48, 48), Parent = MainGui,
}, {
	round(10), -- cantos do botão (troque por round(0) para quadrado puro)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(152, 136, 255), Color3.fromRGB(98, 80, 232)) }),
	outline(Color3.fromRGB(196, 186, 255), 1.5, 0.3),
	new("UIScale", { Name = "Escala" }),
})
T.Icones.criar("_menu", EmoteButton, 36, { Position = UDim2.fromOffset(6, 6) })
do
	local esc = EmoteButton.Escala
	EmoteButton.MouseEnter:Connect(function() tw(esc, 0.12, { Scale = 1.07 }) end)
	EmoteButton.MouseLeave:Connect(function() tw(esc, 0.12, { Scale = 1 }) end)
	EmoteButton.MouseButton1Down:Connect(function() tw(esc, 0.08, { Scale = 0.92 }) end)
	EmoteButton.MouseButton1Up:Connect(function() tw(esc, 0.1, { Scale = 1 }) end)
end
EmoteButton.MouseButton1Click:Connect(function() toggleMenu() end)

-- o "Pegar" agora é um emote dentro do menu (veja tocarEmote / EMOTES)

do
	-- aviso rápido (toast) no lugar do texto do antigo botão
	local avisoCard = frame({
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), Size = UDim2.fromOffset(190, 34),
		BackgroundColor3 = T.bg, BackgroundTransparency = 0.08, Visible = false, ZIndex = 40, Parent = MainGui,
	}, { round(12), outline(T.stroke, 1, 0.2) })
	local avisoTxt = txt({ Font = F.GothamBold, TextSize = 13, TextXAlignment = CENTER, Size = UDim2.fromScale(1, 1), ZIndex = 41, Parent = avisoCard })

	function Pegar.atualizarBotao()
		refreshAtivos() -- atualiza o card "Pegar" no menu
	end

	function Pegar.aviso(msg)
		Pegar.avisoId = (Pegar.avisoId or 0) + 1
		local id = Pegar.avisoId
		avisoTxt.Text = msg
		avisoCard.Visible = true
		task.delay(1.3, function()
			if Pegar.avisoId == id then avisoCard.Visible = false end
		end)
	end

	local function distSuperficie(p, pos)
		local o = p.CFrame:PointToObjectSpace(pos)
		local h = p.Size * 0.5
		local c = Vector3.new(clamp(o.X, -h.X, h.X), clamp(o.Y, -h.Y, h.Y), clamp(o.Z, -h.Z, h.Z))
		return (o - c).Magnitude
	end

	local function ehPersonagem(p)
		local a = p.Parent
		while a and a ~= workspace do
			if a:IsA("Model") and a:FindFirstChildOfClass("Humanoid") then return true end
			a = a.Parent
		end
		return false
	end

	local function achar(char, root)
		local excluir = { char }
		for _, n in ipairs({ "DynamicFingersFolder", "PegarFolder" }) do
			local f = workspace:FindFirstChild(n)
			if f then excluir[#excluir + 1] = f end
		end

		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Exclude
		op.FilterDescendantsInstances = excluir

		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = { char }
		local chao = workspace:Raycast(root.Position, Vector3.new(0, -4.5, 0), rp)
		local chaoRaiz = chao and chao.Instance and chao.Instance.AssemblyRootPart

		local centro = (root.CFrame * CFrame.new(0, 0, -Pegar.alcance)).Position
		local melhor, melhorD = nil, nil
		for _, p in ipairs(workspace:GetPartBoundsInRadius(centro, Pegar.alcance + 0.4, op)) do
			if not p.Anchored and (p.CanCollide or p.Transparency < 0.95) then
				local raiz = p.AssemblyRootPart
				if raiz and not raiz.Anchored and raiz ~= chaoRaiz and not ehPersonagem(p) then
					local d = distSuperficie(p, centro)
					if d <= 2.8 and (not melhorD or d < melhorD) then
						melhor, melhorD = raiz, d
					end
				end
			end
		end
		return melhor
	end

	-- caixa que envolve o conjunto inteiro, no espaço do personagem
	local function medir(raiz, cfRoot)
		local conjunto, preso = {}, false
		local minV = Vector3.new(math.huge, math.huge, math.huge)
		local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, q in ipairs(raiz:GetConnectedParts(true)) do
			if q.AssemblyRootPart == raiz then
				conjunto[#conjunto + 1] = q
				local r = cfRoot:ToObjectSpace(q.CFrame)
				local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = r:GetComponents()
				local s = q.Size
				local hx = (math.abs(r00) * s.X + math.abs(r01) * s.Y + math.abs(r02) * s.Z) * 0.5
				local hy = (math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z) * 0.5
				local hz = (math.abs(r20) * s.X + math.abs(r21) * s.Y + math.abs(r22) * s.Z) * 0.5
				local pos = r.Position
				minV = Vector3.new(math.min(minV.X, pos.X - hx), math.min(minV.Y, pos.Y - hy), math.min(minV.Z, pos.Z - hz))
				maxV = Vector3.new(math.max(maxV.X, pos.X + hx), math.max(maxV.Y, pos.Y + hy), math.max(maxV.Z, pos.Z + hz))
			elseif q.AssemblyRootPart and q.AssemblyRootPart.Anchored then
				preso = true
			end
		end
		return conjunto, maxV - minV, (minV + maxV) * 0.5, preso
	end

	-- poeira + som quando um objeto pesado encosta no chão depois de solto
	local function poeira(pos, normal, cor, tam, vel)
		local fx, fz = clamp(tam.X, 2, 10), clamp(tam.Z, 2, 10)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(fx, 0.2, fz)
		part.CFrame = CFrame.new(pos, pos + normal) * CFrame.Angles(-math.pi / 2, 0, 0)
		part.Parent = workspace:FindFirstChild("PegarFolder") or workspace

		local s = clamp(vel / 25, 0.8, 2)
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(cor:Lerp(Color3.fromRGB(190, 190, 190), 0.5))
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.0 * s),
			NumberSequenceKeypoint.new(1, 3.5 * s),
		})
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Lifetime = NumberRange.new(0.6, 1.3)
		e.Speed = NumberRange.new(4 * s, 10 * s)
		e.SpreadAngle = Vector2.new(80, 80)
		e.Drag = 3
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-90, 90)
		e.EmissionDirection = Enum.NormalId.Top
		e.Rate = 0
		e.Parent = part
		e:Emit(clamp(math.floor(10 + fx * fz * 0.5), 12, 45))

		local som = Instance.new("Sound")
		som.SoundId = Pegar.somPouso
		som.Volume = Pegar.volumePouso
		som.RollOffMaxDistance = 80
		som.Parent = part
		som:Play()

		task.delay(6, function()
			if part.Parent then part:Destroy() end
		end)
	end

	function Pegar.efeitoPouso(raiz, tam, conjunto, char)
		local excluir = { char }
		for _, q in ipairs(conjunto) do excluir[#excluir + 1] = q end
		for _, n in ipairs({ "DynamicFingersFolder", "PegarFolder" }) do
			local f = workspace:FindFirstChild(n)
			if f then excluir[#excluir + 1] = f end
		end
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = excluir

		local meioY = tam.Y * 0.5
		local t0 = os.clock()
		local velAnt = 0
		local conn
		conn = RunService.Heartbeat:Connect(function()
			if not raiz.Parent or os.clock() - t0 > 4 then
				conn:Disconnect()
				return
			end
			local res = workspace:Raycast(raiz.Position, Vector3.new(0, -(meioY + 0.5), 0), rp)
			if res then
				conn:Disconnect()
				poeira(res.Position, res.Normal, res.Instance.Color, tam, math.max(velAnt, 12))
				return
			end
			velAnt = math.abs(math.min(raiz.AssemblyLinearVelocity.Y, 0))
		end)
	end

	function Pegar.soltar()
		if not Pegar.ativo then return end
		local raizSolta, eraPesado, tamSolta, conjSolto = Pegar.raiz, Pegar.pesado, Pegar.tam, Pegar.conjunto
		local charSolto = LocalPlayer.Character
		Pegar.ativo = false
		Pegar.pesado = false
		Pegar.usaDireita = false
		Pegar.usaEsquerda = false

		if Pegar.conn then Pegar.conn:Disconnect(); Pegar.conn = nil end
		if Pegar.conn2 then Pegar.conn2:Disconnect(); Pegar.conn2 = nil end
		for _, i in ipairs(Pegar.inst or {}) do i:Destroy() end
		Pegar.inst = nil

		local cons = Pegar.cons
		Pegar.cons = nil
		if cons then
			task.delay(0.7, function()
				for _, c in ipairs(cons) do c:Destroy() end
			end)
		end

		local hum = Pegar.hum
		if hum and hum.Parent and Pegar.velAplicada and math.abs(hum.WalkSpeed - Pegar.velAplicada) < 0.01 then
			hum.WalkSpeed = Pegar.velBase
		end
		Pegar.hum = nil
		Pegar.raiz, Pegar.tam, Pegar.conjunto = nil, nil, nil

		Pegar.atualizarBotao()

		if eraPesado and raizSolta and raizSolta.Parent and charSolto then
			Pegar.efeitoPouso(raizSolta, tamSolta, conjSolto, charSolto)
		end
	end

	function Pegar.pegar()
		if Pegar.ativo then return end
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local bD = char and char:FindFirstChild("Right Arm")
		local bE = char and char:FindFirstChild("Left Arm")
		if not (hum and root and bD and bE) or hum.Health <= 0 then return end

		if currentEmote ~= nil then Pegar.aviso("Em emote"); return end

		local raiz = achar(char, root)
		if not raiz then Pegar.aviso("Nada perto"); return end

		local livreD = bD:FindFirstChild("RightGrip") == nil
		local livreE = bE:FindFirstChild("LeftGrip") == nil
		if not livreD and not livreE then Pegar.aviso("Mãos ocupadas"); return end

		local massa = raiz.AssemblyMass
		if massa > Pegar.massaMax then Pegar.aviso("Muito pesado"); return end
		local pesado = massa > Pegar.massaLeve
		if pesado and not (livreD and livreE) then Pegar.aviso("Precisa das 2 mãos"); return end

		local cfRoot = root.CFrame
		local conjunto, tam, centroBox, preso = medir(raiz, cfRoot)
		if preso then Pegar.aviso("Está preso"); return end

		local usaD, usaE
		if pesado then
			usaD, usaE = true, true
		elseif livreD and (centroBox.X >= 0 or not livreE) then
			usaD, usaE = true, false
		else
			usaD, usaE = false, true
		end

		-- posição de carregamento (espaço do personagem): face de perto fica na altura das mãos
		local meio = tam * 0.5
		local pertoZ = pesado and -1.6 or -1.7
		local cx = pesado and 0 or (usaD and 1.5 or -1.5)
		local cy = math.max(pesado and 0.2 or 0.6, meio.Y - 2.9)
		local cz = pertoZ - meio.Z
		local relRaiz = cfRoot:ToObjectSpace(raiz.CFrame)
		local alvoCF = CFrame.new(Vector3.new(cx, cy, cz) - centroBox) * relRaiz

		local hy = math.max(cy - meio.Y, math.min(cy + meio.Y, 0.6))
		if pesado then
			local hx = math.max(0.4, math.min(1.4, meio.X * 0.8))
			Pegar.alvoDir = Vector3.new(hx, hy, pertoZ)
			Pegar.alvoEsq = Vector3.new(-hx, hy, pertoZ)
		elseif usaD then
			Pegar.alvoDir = Vector3.new(1.5, hy, pertoZ)
		else
			Pegar.alvoEsq = Vector3.new(-1.5, hy, pertoZ)
		end

		local pasta = workspace:FindFirstChild("PegarFolder")
		if not pasta then
			pasta = Instance.new("Folder")
			pasta.Name = "PegarFolder"
			pasta.Parent = workspace
		end

		local cons = {}
		local partesChar = {}
		for _, c in ipairs(char:GetChildren()) do
			if c:IsA("BasePart") then partesChar[#partesChar + 1] = c end
		end
		for i = 1, math.min(#conjunto, 30) do
			for _, c in ipairs(partesChar) do
				local n = Instance.new("NoCollisionConstraint")
				n.Part0, n.Part1 = conjunto[i], c
				n.Parent = pasta
				cons[#cons + 1] = n
			end
		end

		Pegar.ativo = true
		Pegar.pesado = pesado
		Pegar.usaDireita = usaD
		Pegar.usaEsquerda = usaE
		Pegar.inst = {}
		Pegar.raiz, Pegar.tam, Pegar.conjunto = raiz, tam, conjunto
		Pegar.cons = cons

		Pegar.hum = hum
		Pegar.velBase = hum.WalkSpeed
		hum.WalkSpeed = Pegar.velBase * (pesado and Pegar.lentidaoPesado or Pegar.lentidaoLeve)
		Pegar.velAplicada = hum.WalkSpeed

		-- posição rígida: o objeto é colado na mão a cada frame (sem atraso), com um puxão rápido no início
		local cfIni = raiz.CFrame
		local inicio = os.clock()
		local ultimoCF = cfIni
		local function atualizar()
			if not root.Parent or hum.Health <= 0 or not raiz.Parent or raiz.Anchored then
				Pegar.soltar()
				return
			end
			local t = clamp((os.clock() - inicio) / Pegar.puxarTempo, 0, 1)
			if t >= 1 and (raiz.Position - ultimoCF.Position).Magnitude > 6 then
				Pegar.soltar()
				Pegar.aviso("Perdeu o objeto")
				return
			end
			local e = 1 - (1 - t) * (1 - t)
			local alvoMundo = root.CFrame * alvoCF
			ultimoCF = cfIni:Lerp(alvoMundo, e)
			raiz.CFrame = ultimoCF
			raiz.AssemblyLinearVelocity = root.AssemblyLinearVelocity
			raiz.AssemblyAngularVelocity = Vector3.zero
		end
		Pegar.conn = RunService.RenderStepped:Connect(atualizar)
		Pegar.conn2 = RunService.Stepped:Connect(atualizar)

		Pegar.atualizarBotao()
	end

	-- pose dos braços apontando para onde estão as mãos no objeto
	function Pegar.pose(P)
		local function angulos(alvo, lado)
			local d = alvo - Vector3.new(lado * 1.5, 0.5, 0)
			return math.atan2(d.X, -d.Z), math.atan2(d.Y, math.sqrt(d.X * d.X + d.Z * d.Z))
		end
		if Pegar.usaDireita then
			local yaw, pitch = angulos(Pegar.alvoDir, 1)
			P.wR = 1
			P.R = CFrame.Angles(0, -yaw, rad(90) + pitch)
		end
		if Pegar.usaEsquerda then
			local yaw, pitch = angulos(Pegar.alvoEsq, -1)
			P.wL = 1
			P.L = CFrame.Angles(0, -yaw, -(rad(90) + pitch))
		end
		return P
	end

end

local acumAtivo = 0
RunService.Heartbeat:Connect(function(dt)
	acumAtivo += dt
	if acumAtivo >= 0.15 then
		acumAtivo = 0
		refreshAtivos()
	end
end)

local function montarDevPanel()
local DEV_W, DEV_H = 320, 548
local devTab = "Bracos"
local currentHand = "direita"
local secOpen = {}
local rebuildTab

local DevPanel = frame({
	Name = "DevPanel", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(DEV_W, DEV_H),
	BackgroundColor3 = T.bg, Visible = false, Parent = MainGui,
}, { round(16), outline(T.stroke, 1, 0.1) })
local devScale = new("UIScale", { Parent = DevPanel })
ajustarEscala(devScale, DEV_W + 24, DEV_H + 24)

local devHead = frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), Parent = DevPanel })
makeDraggable(DevPanel, devHead)
local badge = frame({ BackgroundColor3 = Color3.fromRGB(64, 48, 14), Size = UDim2.fromOffset(40, 22), Position = UDim2.fromOffset(14, 15), Parent = devHead }, { round(7) })
txt({ Text = "DEV", Font = F.GothamBold, TextSize = 11, TextColor3 = T.warn, TextXAlignment = CENTER, Size = UDim2.fromScale(1, 1), Parent = badge })
txt({ Text = "Editor de pose", Font = F.GothamBold, TextSize = 14, Position = UDim2.fromOffset(64, 8), Size = UDim2.new(1, -196, 0, 20), Parent = devHead })
local devTitle = txt({ Text = "—", TextSize = 11, TextColor3 = T.sub, Position = UDim2.fromOffset(64, 28), Size = UDim2.new(1, -196, 0, 16), Parent = devHead })

local trocarBtn = btn({ Text = "", TextSize = 15, TextColor3 = T.sub, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -114, 0, 11), Parent = devHead }, { round(15) })
T.Icones.criar("_trocar", trocarBtn, 18, { Position = UDim2.fromOffset(6, 6), ZIndex = 3 })
local closeDevBtn = btn({ Text = "", Font = F.GothamBold, TextSize = 13, TextColor3 = T.sub, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -42, 0, 11), Parent = devHead }, { round(15) })
hoverFX(trocarBtn, T.surface2, T.surface3)
hoverFX(closeDevBtn, T.surface2, T.danger)
T.Icones.centro(closeDevBtn, "_fechar", 14, 2)
-- minimizar (- / □) com animação; o X continua fechando o editor inteiro
janelaControles({
	win = DevPanel, head = devHead, scale = devScale, w = DEV_W, h = DEV_H, headH = 52,
	posMin = UDim2.new(1, -78, 0, 11), size = 30, radius = 15, btnX = closeDevBtn, semChip = true,
})

local statusCard = frame({ Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 186), Parent = DevPanel }, { round(12), outline(T.stroke, 1, 0.5) })
txt({ Text = "STATUS", Font = F.GothamBold, TextSize = 10, TextColor3 = T.dim, Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(80, 14), Parent = statusCard })
local liveDot = frame({ BackgroundColor3 = T.ok, Size = UDim2.fromOffset(6, 6), Position = UDim2.new(1, -62, 0, 12), Parent = statusCard }, { round(3) })
txt({ Text = "ao vivo", TextSize = 10, TextColor3 = T.dim, Position = UDim2.new(1, -52, 0, 8), Size = UDim2.fromOffset(44, 14), Parent = statusCard })

local function criarColunaStatus(titulo, x, ehDireito)
	local col = frame({ BackgroundColor3 = T.surface2, Position = UDim2.new(x, x == 0 and 8 or 3, 0, 28), Size = UDim2.new(0.5, -11, 0, 100), Parent = statusCard }, { round(9) })
	local dot = frame({ BackgroundColor3 = T.ok, Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(9, 9), Parent = col }, { round(3) })
	txt({ Text = titulo, Font = F.GothamBold, TextSize = 10, Position = UDim2.fromOffset(20, 4), Size = UDim2.fromOffset(70, 14), Parent = col })
	local afs = txt({ Font = F.Code, TextSize = 10, TextColor3 = T.dim, TextXAlignment = RIGHT, Position = UDim2.new(1, -60, 0, 4), Size = UDim2.fromOffset(52, 14), Parent = col })
	local lines = txt({
		Font = F.Code, TextSize = 10, TextColor3 = T.sub, TextYAlignment = Enum.TextYAlignment.Top, RichText = true,
		Position = UDim2.fromOffset(9, 22), Size = UDim2.new(1, -18, 0, 50), Parent = col,
	})
	local bars = frame({ BackgroundTransparency = 1, Position = UDim2.new(0, 9, 1, -22), Size = UDim2.new(1, -18, 0, 18), Parent = col }, { lista(3, Enum.FillDirection.Horizontal) })
	local fills = {}
	for i = 1, 5 do
		local bg = frame({ BackgroundColor3 = T.surface3, Size = UDim2.new(0.2, -3, 1, 0), LayoutOrder = i, Parent = bars }, { round(3) })
		fills[i] = frame({ BackgroundColor3 = T.accent, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), Parent = bg }, { round(3) })
	end
	return { dot = dot, lines = lines, afs = afs, fills = fills, ehDireito = ehDireito }
end

local colDir = criarColunaStatus("DIREITA", 0, true)
local colEsq = criarColunaStatus("ESQUERDA", 0.5, false)
local statusFoot = txt({
	Font = F.Code, TextSize = 10, TextColor3 = T.sub, RichText = true,
	Position = UDim2.new(0, 12, 1, -56), Size = UDim2.new(1, -24, 0, 52), Parent = statusCard,
})

local function hex(c) return c:ToHex() end
local function f0(n) return string.format("%4.0f", n) end

local function pintarColuna(col, pose, ativo)
	col.dot.BackgroundColor3 = ativo and T.ok or T.danger
	local ax = { hex(T.ax[1]), hex(T.ax[2]), hex(T.ax[3]) }
	local function tri(a, b, c, fmt)
		return string.format('<font color="#%s">' .. fmt .. '</font><font color="#%s">' .. fmt .. '</font><font color="#%s">' .. fmt .. '</font>', ax[1], a, ax[2], b, ax[3], c)
	end
	local b, p = pose.braco, pose.palma
	col.afs.Text = string.format("AFS %.0f", pose.afastamento)

	local extras = {}
	for i = 1, 5 do
		if dedoTemExtra(pose.dedos[i]) then extras[#extras + 1] = tostring(i) end
	end
	col.lines.Text = string.format(
		"ROT %s\nPOS %s\nPLM %s\nEXT %s",
		tri(b.x, b.y, b.z, "%4.0f"),
		tri(b.px, b.py, b.pz, "%5.1f"),
		tri(p.x, p.y, p.z, "%4.0f"),
		#extras > 0 and ('<font color="#' .. hex(T.warn) .. '">' .. table.concat(extras, " ") .. "</font>") or "—"
	)
	for i = 1, 5 do
		local v = (pose.dedos[i][1] + pose.dedos[i][2]) / 180
		col.fills[i].Size = UDim2.fromScale(1, clamp(v, 0, 1))
		col.fills[i].BackgroundColor3 = dedoTemExtra(pose.dedos[i]) and T.warn or T.accent
	end
end

local function parteFoot(nome, t, ligado)
	local cor = ligado and hex(T.text) or hex(T.dim)
	return string.format('<font color="#%s">%s %.0f,%.0f,%.0f</font>', cor, nome, t.x, t.y, t.z)
end

local function parteFootPerna(nome, t, ligado)
	local cor = ligado and hex(T.text) or hex(T.dim)
	return string.format('<font color="#%s">%s %.0f,%.0f,%.0f | %.2f,%.2f,%.2f</font>', cor, nome, t.x, t.y, t.z, t.px or 0, t.py or 0, t.pz or 0)
end

local acumStatus = 0
RunService.RenderStepped:Connect(function(dt)
	if not DevPanel.Visible then return end
	acumStatus += dt
	if acumStatus < 0.08 then return end
	acumStatus = 0
	pintarColuna(colDir, customPose.direita, animConfig.direita)
	pintarColuna(colEsq, customPose.esquerda, animConfig.esquerda)
	statusFoot.Text = parteFootPerna("TOR", customPose.torso, animConfig.torso) .. "\n"
		.. parteFootPerna("CAB", customPose.cabeca, animConfig.cabeca) .. "\n"
		.. parteFootPerna("PD", customPose.pernaDir, animConfig.pernas) .. "\n"
		.. parteFootPerna("PE", customPose.pernaEsq, animConfig.pernas)
end)

local TABS = {
	{ id = "Bracos", nome = "Braços" },
	{ id = "Maos", nome = "Mãos" },
	{ id = "Torso", nome = "Torso" },
	{ id = "Cabeca", nome = "Cabeça" },
	{ id = "Pernas", nome = "Pernas" },
	{ id = "Itens", nome = "Itens" },
}
local tabBar = frame({ BackgroundColor3 = T.surface, Position = UDim2.fromOffset(12, 250), Size = UDim2.new(1, -24, 0, 34), Parent = DevPanel }, { round(10), padding(3), lista(2, Enum.FillDirection.Horizontal) })
local tabBtns = {}
for i, tb in ipairs(TABS) do
	local b = btn({ Text = tb.nome, Font = F.GothamBold, TextSize = 10, BackgroundTransparency = 1, TextColor3 = T.sub, Size = UDim2.new(1 / #TABS, -2, 1, 0), LayoutOrder = i, Parent = tabBar }, { round(8) })
	b.MouseButton1Click:Connect(function()
		devTab = tb.id
		rebuildTab()
	end)
	tabBtns[tb.id] = b
end

local Content = new("ScrollingFrame", {
	BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 292), Size = UDim2.new(1, -24, 1, -292 - 62),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = T.stroke,
	Parent = DevPanel,
}, { lista(8), padding(0, 0, 6, 4) })

local activeSlider = nil
UserInputService.InputChanged:Connect(function(input)
	if activeSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		activeSlider(input.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		activeSlider = nil
	end
end)

local function criarSlider(parent, o)
	local dec = o.dec or 0
	local mult = 10 ^ dec
	local function arred(v) return math.floor(v * mult + 0.5) / mult end
	local cor = o.axis and T.ax[o.axis] or T.accent

	local c = frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = o.order or 0, Parent = parent })
	local x0 = 0
	if o.axis then
		local chip = frame({ BackgroundColor3 = cor, BackgroundTransparency = 0.78, Size = UDim2.fromOffset(18, 18), Parent = c }, { round(5) })
		txt({ Text = ({ "X", "Y", "Z" })[o.axis], Font = F.GothamBold, TextSize = 10, TextColor3 = cor, TextXAlignment = CENTER, Size = UDim2.fromScale(1, 1), Parent = chip })
		x0 = 26
	end
	txt({ Text = o.label, TextSize = 11, TextColor3 = T.sub, Position = UDim2.fromOffset(x0, 0), Size = UDim2.new(1, -(x0 + 62), 0, 18), Parent = c })
	local box = new("TextBox", {
		BackgroundColor3 = T.surface3, BorderSizePixel = 0, Font = F.Code, TextSize = 11, TextColor3 = T.text,
		ClearTextOnFocus = false, Size = UDim2.fromOffset(54, 20), Position = UDim2.new(1, -54, 0, -1), Parent = c,
	}, { round(6) })

	local track = frame({ BackgroundColor3 = T.surface3, Size = UDim2.new(1, 0, 0, 6), Position = UDim2.fromOffset(0, 28), Parent = c }, { round(3) })
	local fill = frame({ BackgroundColor3 = cor, Size = UDim2.fromScale(0, 1), Parent = track }, { round(3) })
	local knob = frame({ BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14), Position = UDim2.fromScale(0, 0.5), Parent = track }, { round(7) })

	local function visual(v)
		local r = clamp((v - o.min) / (o.max - o.min), 0, 1)
		fill.Size = UDim2.fromScale(r, 1)
		knob.Position = UDim2.fromScale(r, 0.5)
		box.Text = string.format("%." .. dec .. "f", v)
	end
	visual(o.value)

	local function porX(x)
		local r = clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local v = arred(o.min + r * (o.max - o.min))
		visual(v)
		o.onChange(v)
	end

	local hit = btn({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 20), Parent = c })
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			activeSlider = porX
			porX(input.Position.X)
		end
	end)
	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)
		if n then
			n = arred(clamp(n, o.min, o.max))
			visual(n)
			o.onChange(n)
		else
			box.Text = string.format("%." .. dec .. "f", o.value)
		end
	end)
	return c
end

local function criarToggle(parent, texto, get, set, order)
	local row = frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order or 0, Parent = parent })
	txt({ Text = texto, TextSize = 12, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -52, 1, 0), Parent = row })
	local sw = btn({ BackgroundColor3 = get() and T.ok or T.surface3, Size = UDim2.fromOffset(38, 20), Position = UDim2.new(1, -38, 0.5, -10), Parent = row }, { round(10) })
	local knob = frame({ BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(14, 14), Position = get() and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7), Parent = sw }, { round(7) })
	sw.MouseButton1Click:Connect(function()
		set(not get())
		local on = get()
		tw(sw, 0.15, { BackgroundColor3 = on and T.ok or T.surface3 })
		tw(knob, 0.15, { Position = on and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7) })
	end)
	return row
end

local function criarSegmentado(parent, opcoes, atual, onSelect, order)
	local seg = frame({ BackgroundColor3 = T.surface, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = order or 0, Parent = parent }, { round(10), padding(3), lista(3, Enum.FillDirection.Horizontal) })
	for i, op in ipairs(opcoes) do
		local sel = (op.id == atual)
		local b = btn({
			Text = op.nome, Font = F.GothamBold, TextSize = 11, BackgroundColor3 = sel and T.accent or T.surface,
			BackgroundTransparency = sel and 0 or 1, TextColor3 = sel and Color3.new(1, 1, 1) or T.sub,
			Size = UDim2.new(1 / #opcoes, -3, 1, 0), LayoutOrder = i, Parent = seg,
		}, { round(8) })
		b.MouseButton1Click:Connect(function() onSelect(op.id) end)
	end
	return seg
end

local function criarSecao(parent, key, titulo, cor, order, abertaPadrao)
	if secOpen[key] == nil then secOpen[key] = (abertaPadrao ~= false) end
	local wrap = frame({
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order or 0, Parent = parent,
	}, { round(12), outline(T.stroke, 1, 0.55), lista(0) })
	local head = btn({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 1, Parent = wrap })
	frame({ BackgroundColor3 = cor or T.accent, Size = UDim2.fromOffset(3, 14), Position = UDim2.fromOffset(12, 11), Parent = head }, { round(2) })
	txt({ Text = titulo, Font = F.GothamBold, TextSize = 11, Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -50, 1, 0), Parent = head })
	local chev = txt({ Text = "", TextSize = 12, TextColor3 = T.dim, TextXAlignment = RIGHT, Size = UDim2.new(1, -12, 1, 0), Parent = head })
	local body = frame({
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2,
		Visible = secOpen[key], Parent = wrap,
	}, { padding(12, 2, 12, 12), lista(6) })
	T.Icones.direita(chev, secOpen[key] and "_chev_down" or "_chev_right", 12, 2, 4)
	head.MouseButton1Click:Connect(function()
		secOpen[key] = not secOpen[key]
		body.Visible = secOpen[key]
		T.Icones.direita(chev, secOpen[key] and "_chev_down" or "_chev_right", 12, 2, 4)
	end)
	return body
end

local function seletorMao(parent, order)
	return criarSegmentado(parent, { { id = "direita", nome = "Mão direita" }, { id = "esquerda", nome = "Mão esquerda" } }, currentHand, function(id)
		currentHand = id
		rebuildTab()
	end, order)
end

local espelhar = false

local function espelharPose(maoOrigem, pernaOrigem)
	if not espelhar then return end
	if maoOrigem then
		local de = customPose[maoOrigem]
		local para = customPose[maoOrigem == "direita" and "esquerda" or "direita"]
		if devTab == "Bracos" then
			local b, d = de.braco, para.braco
			d.x, d.y, d.z = b.x, 0 - b.y, 0 - b.z
			d.px, d.py, d.pz = 0 - (b.px or 0), b.py or 0, b.pz or 0
		elseif devTab == "Maos" then
			para.palma.x, para.palma.y, para.palma.z = de.palma.x, 0 - de.palma.y, 0 - de.palma.z
			para.afastamento = de.afastamento
			for i = 1, 5 do
				for k = 1, 8 do para.dedos[i][k] = de.dedos[i][k] or 0 end
			end
		end
	end
	if pernaOrigem then
		local de = customPose[pernaOrigem]
		local para = customPose[pernaOrigem == "pernaDir" and "pernaEsq" or "pernaDir"]
		para.x, para.y, para.z = de.x, 0 - de.y, 0 - de.z
		para.px, para.py, para.pz = 0 - (de.px or 0), de.py or 0, de.pz or 0
	end
end

local function ecoMao() espelharPose(currentHand, nil) end

-- ESPELHAR V2: troca os lados só da categoria aberta (Braços, Mãos, Torso, Cabeça ou Pernas).
-- Os eixos laterais (y, z, px) são invertidos para a pose ficar espelhada de verdade.
local function trocarLados()
	salvarSnapshotPose()
	local D, E = customPose.direita, customPose.esquerda

	local function invRot(t)
		return { x = t.x, y = 0 - t.y, z = 0 - t.z, px = 0 - (t.px or 0), py = t.py or 0, pz = t.pz or 0 }
	end
	local function invPalma(p) return { x = p.x, y = 0 - p.y, z = 0 - p.z } end
	local function copiaDedos(h)
		local out = {}
		for i = 1, 5 do
			out[i] = {}
			for k = 1, 8 do out[i][k] = h.dedos[i][k] or 0 end
		end
		return out
	end

	if devTab == "Bracos" then
		local bD, bE = invRot(D.braco), invRot(E.braco)
		D.braco, E.braco = bE, bD
		animConfig.direita, animConfig.esquerda = animConfig.esquerda, animConfig.direita
	elseif devTab == "Maos" then
		local pD, pE = invPalma(D.palma), invPalma(E.palma)
		local dD, dE = copiaDedos(D), copiaDedos(E)
		local aD, aE = D.afastamento, E.afastamento
		D.palma, E.palma = pE, pD
		D.dedos, E.dedos = dE, dD
		D.afastamento, E.afastamento = aE, aD
	elseif devTab == "Torso" then
		customPose.torso = invRot(customPose.torso)
	elseif devTab == "Cabeca" then
		customPose.cabeca = invRot(customPose.cabeca)
	elseif devTab == "Pernas" then
		local pd, pe = invRot(customPose.pernaDir), invRot(customPose.pernaEsq)
		customPose.pernaDir, customPose.pernaEsq = pe, pd
	elseif devTab == "Itens" then
		for _, it in ipairs(customPose.itens) do
			it.parte = ItensEmote.ESPELHO[it.parte] or it.parte
			it.pos.x = 0 - it.pos.x
			it.rot.y, it.rot.z = 0 - it.rot.y, 0 - it.rot.z
		end
	end
end

local function slidersRot(parent, getTabela, dec, min, max, labels, prefix, aoMudar)
	for i, eixo in ipairs({ "x", "y", "z" }) do
		criarSlider(parent, {
			label = labels[i], axis = i, min = min, max = max, dec = dec, order = i,
			value = getTabela()[prefix and (prefix .. eixo) or eixo],
			onChange = function(v) getTabela()[prefix and (prefix .. eixo) or eixo] = v; if aoMudar then aoMudar() end end,
		})
	end
end

local ROT_LABELS = { "Pitch — frente / trás", "Yaw — para os lados", "Roll — girar" }

local function botaoResetParte(parte, rotulo)
	local b = btn({
		Text = "⟲  Resetar " .. rotulo, Font = F.GothamBold, TextSize = 11, TextColor3 = T.sub,
		BackgroundColor3 = T.surface2, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 0, Parent = Content,
	}, { round(9), outline(T.stroke, 1, 0.3) })
	hoverFX(b, T.surface2, T.surface3)
	b.MouseButton1Click:Connect(function()
		if resetarParte(parte) then rebuildTab() end
	end)
	return b
end

local function montarBracos()
	botaoResetParte("bracos", "braços")
	local S1 = criarSecao(Content, "br_ativ", "ATIVAÇÃO", T.ok, 1)
	criarToggle(S1, "Animar braço direito", function() return animConfig.direita end, function(v) animConfig.direita = v end, 1)
	criarToggle(S1, "Animar braço esquerdo", function() return animConfig.esquerda end, function(v) animConfig.esquerda = v end, 2)
	seletorMao(Content, 2)
	local pose = customPose[currentHand]
	local S2 = criarSecao(Content, "br_rot", "ROTAÇÃO DO BRAÇO", T.ax[1], 3)
	slidersRot(S2, function() return pose.braco end, 0, -360, 360, ROT_LABELS, nil, ecoMao)
	local S3 = criarSecao(Content, "br_pos", "POSIÇÃO DO BRAÇO", T.ax[3], 4)
	for i, k in ipairs({ "px", "py", "pz" }) do
		criarSlider(S3, {
			label = ({ "Lado", "Cima / baixo", "Frente / trás" })[i], axis = i, min = -2, max = 2, dec = 2, order = i,
			value = pose.braco[k], onChange = function(v) pose.braco[k] = v; ecoMao() end,
		})
	end
end

local function montarMaos()
	botaoResetParte("maos", "mãos e dedos")
	seletorMao(Content, 1)
	local pose = customPose[currentHand]
	local S1 = criarSecao(Content, "mao_palma", "PALMA", T.ax[2], 2)
	slidersRot(S1, function() return pose.palma end, 0, -360, 360, ROT_LABELS, nil, ecoMao)
	local S2 = criarSecao(Content, "mao_afast", "ABERTURA DOS DEDOS", T.warn, 3)
	criarSlider(S2, { label = "Afastamento total", min = 0, max = 90, dec = 0, value = pose.afastamento, onChange = function(v) pose.afastamento = v; ecoMao() end })
	for i = 1, 5 do
		local S = criarSecao(Content, "dedo" .. i, "DEDO " .. i .. " — " .. string.upper(NOMES_DEDOS[i]), T.accent, 3 + i, false)
		criarSlider(S, { label = "Base", min = 0, max = 90, order = 1, value = pose.dedos[i][1], onChange = function(v) pose.dedos[i][1] = v; ecoMao() end })
		criarSlider(S, { label = "Ponta", min = 0, max = 90, order = 2, value = pose.dedos[i][2], onChange = function(v) pose.dedos[i][2] = v; ecoMao() end })

		local ROT_DEDO = { "Rot X — abrir / fechar lado", "Rot Y — girar no eixo", "Rot Z — dobrar extra" }
		local POS_DEDO = { "Pos X — dentro / fora", "Pos Y — punho / ponta", "Pos Z — entre dedos" }
		for k = 1, 3 do
			criarSlider(S, {
				label = ROT_DEDO[k], axis = k, min = -360, max = 360, dec = 0, order = 2 + k,
				value = pose.dedos[i][2 + k] or 0, onChange = function(v) pose.dedos[i][2 + k] = v; ecoMao() end,
			})
		end
		for k = 1, 3 do
			criarSlider(S, {
				label = POS_DEDO[k], axis = k, min = -0.5, max = 0.5, dec = 2, order = 5 + k,
				value = pose.dedos[i][5 + k] or 0, onChange = function(v) pose.dedos[i][5 + k] = v; ecoMao() end,
			})
		end
	end
end

local function montarTorso()
	botaoResetParte("torso", "torso")
	local S1 = criarSecao(Content, "to_ativ", "ATIVAÇÃO", T.ok, 1)
	criarToggle(S1, "Controlar torso", function() return animConfig.torso end, function(v) animConfig.torso = v end, 1)
	local S2 = criarSecao(Content, "to_rot", "ROTAÇÃO DO TORSO", T.ax[1], 2)
	slidersRot(S2, function() return customPose.torso end, 0, -360, 360, ROT_LABELS)
	local S3 = criarSecao(Content, "to_pos", "POSIÇÃO DO TORSO", T.ax[3], 3)
	for i, k in ipairs({ "px", "py", "pz" }) do
		criarSlider(S3, {
			label = ({ "Lado", "Frente / trás", "Cima / baixo" })[i], axis = i, min = -2, max = 2, dec = 2, order = i,
			value = customPose.torso[k] or 0, onChange = function(v) customPose.torso[k] = v end,
		})
	end
end

local function montarCabeca()
	botaoResetParte("cabeca", "cabeça")
	local S1 = criarSecao(Content, "ca_ativ", "ATIVAÇÃO", T.ok, 1)
	criarToggle(S1, "Controlar cabeça", function() return animConfig.cabeca end, function(v) animConfig.cabeca = v end, 1)
	local S2 = criarSecao(Content, "ca_rot", "ROTAÇÃO DA CABEÇA", T.ax[1], 2)
	slidersRot(S2, function() return customPose.cabeca end, 0, -360, 360, { "Pitch — olhar cima / baixo", "Yaw — virar", "Roll — inclinar" })
	local S3 = criarSecao(Content, "ca_pos", "POSIÇÃO DA CABEÇA", T.ax[3], 3)
	for i, k in ipairs({ "px", "py", "pz" }) do
		criarSlider(S3, {
			label = ({ "Lado", "Frente / trás", "Cima / baixo" })[i], axis = i, min = -2, max = 2, dec = 2, order = i,
			value = customPose.cabeca[k] or 0, onChange = function(v) customPose.cabeca[k] = v end,
		})
	end
end

local function slidersPosPerna(parent, getTabela, aoMudar)
	local t = getTabela()
	for i, k in ipairs({ "px", "py", "pz" }) do
		criarSlider(parent, {
			label = ({ "Frente / trás", "Cima / baixo", "Lado" })[i], axis = i, min = -2, max = 2, dec = 2, order = 3 + i,
			value = t[k] or 0, onChange = function(v) getTabela()[k] = v; if aoMudar then aoMudar() end end,
		})
	end
end

local function montarPernas()
	botaoResetParte("pernas", "pernas")
	local S1 = criarSecao(Content, "pe_ativ", "ATIVAÇÃO", T.ok, 1)
	criarToggle(S1, "Controlar pernas", function() return animConfig.pernas end, function(v) animConfig.pernas = v end, 1)
	local S2 = criarSecao(Content, "pe_dir", "ROTAÇÃO — PERNA DIREITA", T.ax[1], 2)
	slidersRot(S2, function() return customPose.pernaDir end, 0, -360, 360, ROT_LABELS, nil, function() espelharPose(nil, "pernaDir") end)
	local S3 = criarSecao(Content, "pe_esq", "ROTAÇÃO — PERNA ESQUERDA", T.ax[3], 3)
	slidersRot(S3, function() return customPose.pernaEsq end, 0, -360, 360, ROT_LABELS, nil, function() espelharPose(nil, "pernaEsq") end)
	local S4 = criarSecao(Content, "pe_dir_pos", "POSIÇÃO — PERNA DIREITA", T.ax[1], 4)
	slidersPosPerna(S4, function() return customPose.pernaDir end, function() espelharPose(nil, "pernaDir") end)
	local S5 = criarSecao(Content, "pe_esq_pos", "POSIÇÃO — PERNA ESQUERDA", T.ax[3], 5)
	slidersPosPerna(S5, function() return customPose.pernaEsq end, function() espelharPose(nil, "pernaEsq") end)
end

-- ===== aba ITENS: acessórios / roupas / mesh pelo ID (posição, rotação e tamanho) =====
local ITU = { tipo = "acessorio", parte = "Head", id = "", tex = "", aberto = 1, refs = setmetatable({}, { __mode = "k" }) }

ItensEmote.status = function(it)
	local l = ITU.refs[it]
	if l and l.Parent then l.Text = it.status or "" end
end
ItensEmote.aoKind = function()
	if devTab == "Itens" then rebuildTab() end
end

local function itemBox(parent, placeholder, texto, order, aoMudar)
	local b = new("TextBox", {
		BackgroundColor3 = T.surface3, BorderSizePixel = 0, Font = F.Code, TextSize = 11, TextColor3 = T.text,
		PlaceholderText = placeholder, PlaceholderColor3 = T.dim, Text = texto, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order, Parent = parent,
	}, { round(7), padding(8, 0, 8, 0) })
	b:GetPropertyChangedSignal("Text"):Connect(function() aoMudar(b.Text) end)
	return b
end

local function seletorParte(parent, atual, aoEscolher, order)
	local w = frame({
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order, Parent = parent,
	}, { lista(4) })
	local P = ItensEmote.PARTES
	criarSegmentado(w, { P[1], P[2], P[3] }, atual, aoEscolher, 1)
	criarSegmentado(w, { P[4], P[5], P[6] }, atual, aoEscolher, 2)
	return w
end

local function nomeDe(opcoes, id)
	for _, x in ipairs(opcoes) do
		if x.id == id then return x.nome end
	end
	return id
end

local function montarItens()
	botaoResetParte("itens", "itens")

	local S1 = criarSecao(Content, "it_add", "ADICIONAR ITEM (POR ID)", T.ok, 1)
	criarSegmentado(S1, ItensEmote.TIPOS, ITU.tipo, function(id)
		ITU.tipo = id
		rebuildTab()
	end, 1)
	itemBox(S1, ITU.tipo == "mesh" and "MeshId (número)" or "ID do asset (número)", ITU.id, 2, function(s) ITU.id = s end)
	if ITU.tipo == "mesh" then
		itemBox(S1, "TextureId (opcional)", ITU.tex, 3, function(s) ITU.tex = s end)
	end
	txt({ Text = "Parte do corpo", TextSize = 11, TextColor3 = T.sub, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 4, Parent = S1 })
	seletorParte(S1, ITU.parte, function(id)
		ITU.parte = id
		rebuildTab()
	end, 5)
	local addBtn = btn({
		Text = "Adicionar", Font = F.GothamBold, TextSize = 12, BackgroundColor3 = T.accent, TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 6, Parent = S1,
	}, { round(9), padding(24, 0, 8, 0) })
	T.Icones.lado(addBtn, "_mais", 14, 2, 20)
	hoverFX(addBtn, T.accent, Color3.fromRGB(148, 134, 255))
	local aviso = txt({ Text = "", TextSize = 10, TextColor3 = T.danger, TextWrapped = true, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 7, Parent = S1 })
	txt({
		Text = "Acessório e Roupa: ID do catálogo (precisa de executor com GetObjects). Mesh: MeshId, e TextureId se quiser textura. Os Exportar já levam os itens.",
		TextSize = 10, TextColor3 = T.dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 8, Parent = S1,
	})
	addBtn.MouseButton1Click:Connect(function()
		local id = ITU.id:match("%d+")
		if not id or #id > 20 then
			aviso.Text = "Digite o número do ID."
			return
		end
		if #customPose.itens >= ItensEmote.MAX then
			aviso.Text = "Máximo de " .. ItensEmote.MAX .. " itens por emote."
			return
		end
		salvarSnapshotPose()
		local tex = (ITU.tipo == "mesh") and ITU.tex:match("%d+") or nil
		table.insert(customPose.itens, {
			tipo = ITU.tipo, id = id, parte = ITU.parte, tex = tex or "",
			pos = { x = 0, y = 0, z = 0 }, rot = { x = 0, y = 0, z = 0 }, size = { x = 1, y = 1, z = 1 },
		})
		ITU.id, ITU.tex = "", ""
		ITU.aberto = #customPose.itens
		rebuildTab()
	end)

	if #customPose.itens == 0 then
		txt({ Text = "Nenhum item neste emote ainda.", TextSize = 11, TextColor3 = T.dim, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 2, Parent = Content })
	end

	for i, it in ipairs(customPose.itens) do
		local titulo = string.format("#%d  %s  •  %s  →  %s", i, nomeDe(ItensEmote.TIPOS, it.tipo), it.id, nomeDe(ItensEmote.PARTES, it.parte))
		local B = criarSecao(Content, "it_item" .. i, titulo, T.warn, 10 + i, i == ITU.aberto)
		ITU.refs[it] = txt({
			Text = it.status or "", TextSize = 10, TextColor3 = T.dim, TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, Parent = B,
		})

		if it.kind ~= "roupa" then
			seletorParte(B, it.parte, function(id)
				salvarSnapshotPose()
				it.parte = id
				rebuildTab()
			end, 2)

			local function cabecalho(texto, ordem)
				txt({ Text = texto, Font = F.GothamBold, TextSize = 10, TextColor3 = T.dim, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = ordem, Parent = B })
			end
			local EIXOS = { "x", "y", "z" }
			cabecalho("POSIÇÃO", 3)
			for k, eixo in ipairs(EIXOS) do
				criarSlider(B, {
					label = ({ "Lado", "Cima / baixo", "Frente / trás" })[k], axis = k, min = -5, max = 5, dec = 2, order = 3 + k,
					value = it.pos[eixo], onChange = function(v) it.pos[eixo] = v end,
				})
			end
			cabecalho("ROTAÇÃO", 7)
			for k, eixo in ipairs(EIXOS) do
				criarSlider(B, {
					label = ROT_LABELS[k], axis = k, min = -360, max = 360, dec = 0, order = 7 + k,
					value = it.rot[eixo], onChange = function(v) it.rot[eixo] = v end,
				})
			end
			cabecalho("TAMANHO", 11)
			for k, eixo in ipairs(EIXOS) do
				criarSlider(B, {
					label = ({ "Largura (X)", "Altura (Y)", "Profundidade (Z)" })[k], axis = k, min = 0.05, max = 6, dec = 2, order = 11 + k,
					value = it.size[eixo], onChange = function(v) it.size[eixo] = v end,
				})
			end
		end

		local linha = frame({
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 20, Parent = B,
		}, { lista(6, Enum.FillDirection.Horizontal) })
		if it.kind ~= "roupa" then
			local igualar = btn({
				Text = "Igualar tamanho (X)", Font = F.GothamBold, TextSize = 10, TextColor3 = T.sub, BackgroundColor3 = T.surface2,
				Size = UDim2.new(0.5, -3, 1, 0), LayoutOrder = 1, Parent = linha,
			}, { round(9), outline(T.stroke, 1, 0.3) })
			hoverFX(igualar, T.surface2, T.surface3)
			igualar.MouseButton1Click:Connect(function()
				salvarSnapshotPose()
				it.size.y, it.size.z = it.size.x, it.size.x
				rebuildTab()
			end)
		end
		local remover = btn({
			Text = "Remover", Font = F.GothamBold, TextSize = 10, TextColor3 = T.danger, BackgroundColor3 = T.surface2,
			Size = it.kind ~= "roupa" and UDim2.new(0.5, -3, 1, 0) or UDim2.new(1, 0, 1, 0), LayoutOrder = 2, Parent = linha,
		}, { round(9), outline(T.stroke, 1, 0.3) })
		hoverFX(remover, T.surface2, T.surface3)
		remover.MouseButton1Click:Connect(function()
			salvarSnapshotPose()
			table.remove(customPose.itens, i)
			ITU.refs[it] = nil
			rebuildTab()
		end)
	end
end

local MONTADORES = { Bracos = montarBracos, Maos = montarMaos, Torso = montarTorso, Cabeca = montarCabeca, Pernas = montarPernas, Itens = montarItens }

function rebuildTab()
	for _, c in ipairs(Content:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	for id, b in pairs(tabBtns) do
		local sel = (id == devTab)
		b.BackgroundTransparency = sel and 0 or 1
		b.BackgroundColor3 = T.accent
		b.TextColor3 = sel and Color3.new(1, 1, 1) or T.sub
	end
	Content.CanvasPosition = Vector2.new(0, 0)
	MONTADORES[devTab]()
end

local devFoot = frame({ BackgroundTransparency = 1, Position = UDim2.new(0, 12, 1, -54), Size = UDim2.new(1, -24, 0, 42), Parent = DevPanel }, { lista(8, Enum.FillDirection.Horizontal) })
local resetBtn = btn({ Text = "Resetar pose", Font = F.GothamBold, TextSize = 11, Size = UDim2.new(0.19, -6, 1, 0), LayoutOrder = 1, Parent = devFoot }, { round(11), outline(T.stroke, 1, 0.3) })
local exportBtn = btn({ Text = "Exportar", Font = F.GothamBold, TextSize = 11, BackgroundColor3 = T.accent, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.new(0.2, -6, 1, 0), LayoutOrder = 5, Parent = devFoot }, { round(11) })
hoverFX(resetBtn, T.surface2, T.surface3)
local desfazerBtn = btn({ Text = "Desfazer", Font = F.GothamBold, TextSize = 11, Size = UDim2.new(0.17, -6, 1, 0), LayoutOrder = 2, Parent = devFoot }, { round(11), outline(T.stroke, 1, 0.3) })
hoverFX(desfazerBtn, T.surface2, T.surface3)
hoverFX(exportBtn, T.accent, Color3.fromRGB(148, 134, 255))

local espelharBtn = btn({ Text = "Espelhar", Font = F.GothamBold, TextSize = 11, Size = UDim2.new(0.2, -6, 1, 0), LayoutOrder = 3, Parent = devFoot }, { round(11), outline(T.stroke, 1, 0.3) })
local espelharV2Btn = btn({ Text = "Espelhar V2", Font = F.GothamBold, TextSize = 11, Size = UDim2.new(0.24, -8, 1, 0), LayoutOrder = 4, Parent = devFoot }, { round(11), outline(T.stroke, 1, 0.3) })
hoverFX(espelharV2Btn, T.surface2, T.surface3)
espelharV2Btn.MouseButton1Click:Connect(function()
	trocarLados()
	rebuildTab()
end)
local function pintarEspelhar()
	espelharBtn.BackgroundColor3 = espelhar and T.ok or T.surface2
	espelharBtn.TextColor3 = espelhar and T.bg or T.sub
	espelharBtn.Text = "Espelhar"
	if espelhar then T.Icones.direita(espelharBtn, "_check", 12, 3, 6) else T.Icones.limpar(espelharBtn) end
end
pintarEspelhar()
espelharBtn.MouseButton1Click:Connect(function()
	espelhar = not espelhar
	pintarEspelhar()
	if espelhar then

		espelharPose(currentHand, devTab == "Pernas" and "pernaDir" or nil)
		rebuildTab()
	end
end)

local function fmt(n)
	n = math.floor(n * 100 + 0.5) / 100 + 0
	return tostring(n)
end

local function gerarLuaBase()
	local function v3(t) return string.format("{ x = %s, y = %s, z = %s }", fmt(t.x), fmt(t.y), fmt(t.z)) end
	local function br(t) return string.format("{ x = %s, y = %s, z = %s, px = %s, py = %s, pz = %s }", fmt(t.x), fmt(t.y), fmt(t.z), fmt(t.px or 0), fmt(t.py or 0), fmt(t.pz or 0)) end
	local function dedos(h)
		local s = {}
		for i = 1, 5 do
			local d = h.dedos[i]
			if dedoTemExtra(d) then

				s[i] = string.format("{%s,%s,%s,%s,%s,%s,%s,%s}", fmt(d[1]), fmt(d[2]), fmt(d[3] or 0), fmt(d[4] or 0), fmt(d[5] or 0), fmt(d[6] or 0), fmt(d[7] or 0), fmt(d[8] or 0))
			else
				s[i] = string.format("{%s,%s}", fmt(d[1]), fmt(d[2]))
			end
		end
		return "{ " .. table.concat(s, ", ") .. " }"
	end
	local D, E = customPose.direita, customPose.esquerda
	return string.format(
		'["%s"] = {\n\tdir = %s, palmaDir = %s,\n\tdedosDir = %s, afastDir = %s,\n\tesq = %s, palmaEsq = %s,\n\tdedosEsq = %s, afastEsq = %s,\n\tcabeca = %s, torso = %s,\n\tpernaDir = %s, pernaEsq = %s\n},',
		currentEmote or "Nenhum",
		br(D.braco), v3(D.palma), dedos(D), fmt(D.afastamento),
		br(E.braco), v3(E.palma), dedos(E), fmt(E.afastamento),
		br(customPose.cabeca), br(customPose.torso), br(customPose.pernaDir), br(customPose.pernaEsq)
	)
end

local function gerarLua()
	local s = gerarLuaBase()
	local itensTxt = ItensEmote.texto(customPose.itens, "\t")
	if itensTxt then s = s:sub(1, -4) .. ",\n" .. itensTxt .. "\n}," end
	return s
end

local ExportModal = frame({
	BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 20, Parent = DevPanel,
}, { round(16) })
local exportCard = frame({
	BackgroundColor3 = T.surface, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -28, 0, 330), ZIndex = 21, Parent = ExportModal,
}, { round(14), outline(T.stroke, 1, 0.1) })
txt({ Text = "Exportar pose", Font = F.GothamBold, TextSize = 14, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 20), ZIndex = 22, Parent = exportCard })
txt({ Text = "Selecione tudo e copie. Cole dentro de defaultEmotes.\nDedo: {base, ponta} ou {base, ponta, rotX, rotY, rotZ, posX, posY, posZ}", TextSize = 11, TextColor3 = T.dim, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(16, 32), Size = UDim2.new(1, -32, 0, 30), ZIndex = 22, Parent = exportCard })
local exportBox = new("TextBox", {
	BackgroundColor3 = T.bg, BorderSizePixel = 0, Font = F.Code, TextSize = 10, TextColor3 = T.ok, TextXAlignment = LEFT,
	TextYAlignment = Enum.TextYAlignment.Top, MultiLine = true, TextEditable = false, ClearTextOnFocus = false, TextWrapped = true,
	Position = UDim2.fromOffset(14, 68), Size = UDim2.new(1, -28, 1, -122), ZIndex = 22, Parent = exportCard,
}, { round(8), padding(8) })
local exportClose = btn({ Text = "Fechar", Font = F.GothamBold, TextSize = 12, Size = UDim2.new(1, -28, 0, 34), Position = UDim2.new(0, 14, 1, -46), ZIndex = 22, Parent = exportCard }, { round(10) })
hoverFX(exportClose, T.surface2, T.surface3)
exportClose.MouseButton1Click:Connect(function() ExportModal.Visible = false end)

do
	local e = (getgenv and getgenv()) or _G
	if e.EMOTEZ_PONTE then
		e.EMOTEZ_PONTE.textoDev = function()
			if not (currentEmote and DevPanel.Visible) then return nil end
			return gerarLua()
		end
		e.EMOTEZ_PONTE.nomeDev = function()
			if currentEmote and DevPanel.Visible then return currentEmote end
			return nil
		end
	end
end

exportBtn.MouseButton1Click:Connect(function()
	local s = gerarLua()
	exportBox.Text = s
	ExportModal.Visible = true
	print("========== COPIE A POSE ABAIXO ==========")
	print(s)
	print("=========================================")
	pcall(function() setclipboard(s) end)
end)

resetBtn.MouseButton1Click:Connect(function()
	if currentEmote and defaultEmotes[currentEmote] then
		carregarEmote(currentEmote)
		rebuildTab()
	end
end)

local prevNome
desfazerBtn.MouseButton1Click:Connect(function()
	local nome = restaurarSnapshotPose()
	if not nome then return end
	devTitle.Text = nome
	prevNome.Text = nome
	rebuildTab()
end)

local PREV_W, PREV_H = 230, 250
local ANIM_H_REF = 238 -- altura do animador (TL_H): o preview fica logo acima dele
local DevPreviewWin = frame({
	Name = "DevPreview", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -(12 + ANIM_H_REF + 8)), Size = UDim2.fromOffset(PREV_W, PREV_H),
	BackgroundColor3 = T.bg, Visible = false, Parent = MainGui,
}, { round(16), outline(T.stroke, 1, 0.1) })
local prevScale = new("UIScale", { Parent = DevPreviewWin })
prevScale.Scale = 1
do
	local function aplicar()
		local vp = MainGui.AbsoluteSize
		if vp.X > 0 then prevScale.Scale = math.min(1, (vp.X - 24) / PREV_W, (vp.Y - 24) / PREV_H) end
	end
	MainGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(aplicar)
	aplicar()
end
local prevHead = frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = DevPreviewWin })
makeDraggable(DevPreviewWin, prevHead)
txt({ Text = "PREVIEW", Font = F.GothamBold, TextSize = 10, TextColor3 = T.dim, Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(100, 14), Parent = prevHead })
prevNome = txt({ Text = "—", Font = F.GothamBold, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(16, 21), Size = UDim2.new(1, -146, 0, 16), Parent = prevHead })
local prevReset = btn({ Text = "180°", Font = F.GothamBold, TextSize = 10, TextColor3 = T.sub, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -94, 0, 6), Parent = prevHead }, { round(14) })
hoverFX(prevReset, T.surface2, T.surface3)
local prevAnim = btn({ Text = "", TextSize = 13, TextColor3 = T.ok, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -124, 0, 6), Parent = prevHead }, { round(14) })
hoverFX(prevAnim, T.surface2, T.surface3)
T.Icones.centro(prevAnim, "_play", 14, 2)
local devVP = novoViewport({ Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 1, -44 - 34), BackgroundColor3 = T.surface, Parent = DevPreviewWin })
local devPreview = criarPreview(devVP)
devPreview.setCustom(true)
prevReset.MouseButton1Click:Connect(function() devPreview.girar() end)
do
	local animando = true
	devPreview.setAnimar(true)
	prevAnim.MouseButton1Click:Connect(function()
		animando = not animando
		devPreview.setAnimar(animando)
		T.Icones.centro(prevAnim, animando and "_play" or "_pause", 14, 2)
		prevAnim.TextColor3 = animando and T.ok or T.dim
	end)
end
txt({ Text = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) and "arraste para girar • pinça = zoom" or "arraste para girar • scroll = zoom", TextSize = 10, TextColor3 = T.dim, TextXAlignment = CENTER, Position = UDim2.new(0, 0, 1, -26), Size = UDim2.new(1, 0, 0, 16), Parent = DevPreviewWin })
janelaControles({
	win = DevPreviewWin, head = prevHead, scale = prevScale, w = PREV_W, h = PREV_H, headH = 40,
	posMin = UDim2.new(1, -64, 0, 7), posX = UDim2.new(1, -34, 0, 7), size = 26,
	iniciarMin = true, fixaBase = true,
	ativo = function() return DevPanel.Visible end, pai = DevPanel,
	onMin = function(min) devPreview.setActive((not min) and DevPanel.Visible) end,
	onHide = function() devPreview.setActive(false) end,
	onShow = function() devPreview.setActive(DevPanel.Visible) end,
})

local SEL_W, SEL_H = 230, 374
local DevSelector = frame({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(SEL_W, SEL_H),
	BackgroundColor3 = T.bg, Visible = false, ZIndex = 30, Parent = MainGui,
}, { round(14), outline(T.stroke, 1, 0.1), padding(10) })
local selScale = new("UIScale", { Parent = DevSelector })
ajustarEscala(selScale, SEL_W + 24, SEL_H + 24)
local selHead = frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 0), ZIndex = 30, Parent = DevSelector })
local selList = new("ScrollingFrame", {
	BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 108), Size = UDim2.new(1, 0, 1, -108),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
	ScrollBarImageColor3 = T.stroke, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 30, Parent = DevSelector,
}, { lista(4), padding(0, 0, 6, 2) })
makeDraggable(DevSelector, selHead)
local selBadge = frame({ BackgroundColor3 = Color3.fromRGB(64, 48, 14), Size = UDim2.fromOffset(36, 20), Position = UDim2.fromOffset(0, 5), ZIndex = 31, Parent = selHead }, { round(7) })
txt({ Text = "DEV", Font = F.GothamBold, TextSize = 11, TextColor3 = T.warn, TextXAlignment = CENTER, Size = UDim2.fromScale(1, 1), ZIndex = 32, Parent = selBadge })
txt({ Text = "Escolha o emote", Font = F.GothamBold, TextSize = 12, Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -80, 1, 0), ZIndex = 31, Parent = selHead })
local closeSel = btn({ Text = "", TextSize = 13, TextColor3 = T.sub, Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -26, 0, 2), ZIndex = 31, Parent = selHead }, { round(13) })
hoverFX(closeSel, T.surface2, T.danger)
T.Icones.centro(closeSel, "_fechar", 14, 32)
closeSel.MouseButton1Click:Connect(function() DevSelector.Visible = false end)

local animNovo -- definido no bloco do ANIMADOR (zera a timeline e põe o nome do emote novo)
local animCarregar -- definido no bloco do ANIMADOR (importa os keyframes de um emote animado já existente)

-- ---------- CRIAR EMOTE (nome + pose em branco + animador zerado) ----------
local criarNomeBox = new("TextBox", {
	BackgroundColor3 = T.surface3, BorderSizePixel = 0, Font = F.Code, TextSize = 11, TextColor3 = T.text,
	PlaceholderText = "nome do novo emote", PlaceholderColor3 = T.dim, Text = "", ClearTextOnFocus = false,
	TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, -78, 0, 28), ZIndex = 31, Parent = DevSelector,
}, { round(7), padding(8, 0, 8, 0) })
local criarBtn = btn({
	Text = "Criar", Font = F.GothamBold, TextSize = 11, BackgroundColor3 = T.accent, TextColor3 = Color3.new(1, 1, 1),
	Position = UDim2.new(1, -72, 0, 34), Size = UDim2.fromOffset(72, 28), ZIndex = 31, Parent = DevSelector,
}, { round(7), padding(20, 0, 4, 0) })
T.Icones.lado(criarBtn, "_mais", 14, 32, 17)
hoverFX(criarBtn, T.accent, Color3.fromRGB(148, 134, 255))
local criarMsg = txt({
	Text = "", TextSize = 10, TextColor3 = T.danger, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 12), ZIndex = 31, Parent = DevSelector,
})

local function poseEmBranco()
	local function b6() return { x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0 } end
	local function v3() return { x = 0, y = 0, z = 0 } end
	local function mao() return { {10,10}, {10,10}, {10,10}, {10,10}, {10,10} } end
	return {
		dir = b6(), palmaDir = v3(), dedosDir = mao(), afastDir = 0,
		esq = b6(), palmaEsq = v3(), dedosEsq = mao(), afastEsq = 0,
		cabeca = b6(), torso = b6(), pernaDir = b6(), pernaEsq = b6(),
	}
end

local abrirDev
local adicionarLinhaDev

local function criarEmoteNovo()
	local n = criarNomeBox.Text:gsub('["\\%c]', ""):gsub("^%s+", ""):gsub("%s+$", "")
	if n == "" then
		criarMsg.Text = "Digite um nome para o emote."
		return
	end
	if defaultEmotes[n] or EMOTE_POR_NOME[n] then
		criarMsg.Text = "Já existe um emote com esse nome."
		return
	end
	criarMsg.Text = ""
	defaultEmotes[n] = poseEmBranco()
	criarNomeBox.Text = ""
	adicionarLinhaDev(n, "✨")
	abrirDev(n)
	if animNovo then animNovo(n) end
end

criarBtn.MouseButton1Click:Connect(criarEmoteNovo)
criarNomeBox.FocusLost:Connect(function(enter)
	if enter then criarEmoteNovo() end
end)
criarNomeBox:GetPropertyChangedSignal("Text"):Connect(function() criarMsg.Text = "" end)

-- ---------- IMPORTAR ANIMAÇÃO (cola o código feito por outra pessoa → vira emote no DEV) ----------
-- Aceita o mesmo texto que o "Exportar" gera (pose ou animação com keyframes, do DEV ou do EMOTE CRIADOR):
--   ["Nome"] = { ... },        { ... }        defaultEmotes["Nome"] = { ... }        e vários emotes de uma vez.
-- O texto colado NÃO é executado: ele só é lido como dados (tabelas, números, textos, true/false).
do
	local function lerTabelaLua(src)
		src = src:gsub("%-%-%[(=*)%[.-%]%1%]", " "):gsub("%-%-[^\n]*", " ")
		src = src:gsub("^%s*return%s+", "")
		src = src:gsub("^%s*local%s+[%w_]+%s*=%s*", "")
		src = src:gsub("^%s*defaultEmotes%s*%[", "[")
		if #src > 400000 then error("código grande demais", 0) end
		local ini = src:find("%S")
		if not ini then error("cole o código da animação primeiro", 0) end
		if src:sub(ini, ini) ~= "{" then
			src = "{" .. src .. "\n}"
			ini = 1
		end

		local len = #src
		local pos = ini

		local function erro(msg)
			error("linha " .. select(2, src:sub(1, pos):gsub("\n", "\n")) + 1 .. ": " .. msg, 0)
		end
		local function pular()
			pos = src:find("%S", pos) or (len + 1)
		end

		local parseValor

		local function parseString()
			local q = src:sub(pos, pos)
			local i = pos + 1
			local buf = {}
			while i <= len do
				local c = src:sub(i, i)
				if c == "\\" then
					local n = src:sub(i + 1, i + 1)
					if n == "n" then buf[#buf + 1] = "\n"
					elseif n == "t" then buf[#buf + 1] = "\t"
					else buf[#buf + 1] = n end
					i = i + 2
				elseif c == q then
					pos = i + 1
					return table.concat(buf)
				else
					buf[#buf + 1] = c
					i = i + 1
				end
			end
			erro("texto sem fechar as aspas")
		end

		local function parseTabela(prof)
			if prof > 16 then erro("tabelas aninhadas demais") end
			pos = pos + 1
			local t, n = {}, 0
			while true do
				pular()
				if pos > len then erro("faltou fechar uma chave }") end
				local c = src:sub(pos, pos)
				if c == "}" then
					pos = pos + 1
					return t
				elseif c == "," or c == ";" then
					pos = pos + 1
				elseif c == "[" then
					pos = pos + 1
					local chave = parseValor(prof + 1)
					pular()
					if src:sub(pos, pos) ~= "]" then erro("esperava ]") end
					pos = pos + 1
					pular()
					if src:sub(pos, pos) ~= "=" then erro("esperava =") end
					pos = pos + 1
					local v = parseValor(prof + 1)
					if chave == nil then erro("nome vazio") end
					t[chave] = v
				else
					local nome = src:match("^[%a_][%w_]*", pos)
					local eq = nome and src:match("^%s*()=", pos + #nome)
					if eq then
						pos = eq + 1
						t[nome] = parseValor(prof + 1)
					else
						n = n + 1
						t[n] = parseValor(prof + 1)
					end
				end
			end
		end

		function parseValor(prof)
			pular()
			local c = src:sub(pos, pos)
			if c == "{" then
				return parseTabela(prof)
			elseif c == '"' or c == "'" then
				return parseString()
			elseif c ~= "" and c:match("[%d%-%.]") then
				local s = src:match("^%-?%d+%.?%d*[eE][%+%-]?%d+", pos) or src:match("^%-?%d+%.?%d*", pos) or src:match("^%-?%.%d+", pos)
				if not s then erro("número inválido") end
				pos = pos + #s
				return tonumber(s)
			end
			local nome = src:match("^[%a_][%w_]*", pos)
			if nome == "true" then pos = pos + 4 return true end
			if nome == "false" then pos = pos + 5 return false end
			if nome == "nil" then pos = pos + 3 return nil end
			erro("não entendi '" .. src:sub(pos, pos + 12) .. "' (só aceito tabelas, números, textos e true/false)")
		end

		return parseTabela(1)
	end

	-- ---------- deixa tudo no formato que o script espera (campos que faltam viram 0) ----------
	local function num(v, padrao)
		if type(v) == "number" and v == v and v > -1e6 and v < 1e6 then return v end
		return padrao or 0
	end
	local function b6(t)
		t = type(t) == "table" and t or {}
		return { x = num(t.x), y = num(t.y), z = num(t.z), px = num(t.px), py = num(t.py), pz = num(t.pz) }
	end
	local function b3(t)
		t = type(t) == "table" and t or {}
		return { x = num(t.x), y = num(t.y), z = num(t.z) }
	end
	local function mao(t)
		local r = {}
		for i = 1, 5 do
			local s = type(t) == "table" and type(t[i]) == "table" and t[i] or nil
			if s then
				local d = {}
				for k = 1, 8 do d[k] = num(s[k]) end
				r[i] = d
			else
				r[i] = { 10, 10, 0, 0, 0, 0, 0, 0 }
			end
		end
		return r
	end
	local function poseDe(s)
		return {
			dir = b6(s.dir), palmaDir = b3(s.palmaDir), dedosDir = mao(s.dedosDir), afastDir = num(s.afastDir),
			esq = b6(s.esq), palmaEsq = b3(s.palmaEsq), dedosEsq = mao(s.dedosEsq), afastEsq = num(s.afastEsq),
			cabeca = b6(s.cabeca), torso = b6(s.torso), pernaDir = b6(s.pernaDir), pernaEsq = b6(s.pernaEsq),
		}
	end

	local function emoteDe(s)
		if type(s.frames) == "table" then
			local frames = {}
			for _, f in ipairs(s.frames) do
				if type(f) == "table" and #frames < 200 then
					local p = poseDe(f)
					p.t = math.max(num(f.t), 0)
					frames[#frames + 1] = p
				end
			end
			if #frames > 0 then
				table.sort(frames, function(a, b) return a.t < b.t end)
				local ultimo = frames[#frames].t
				local usa
				if type(s.usa) == "table" then
					usa = { cabeca = s.usa.cabeca == true, torso = s.usa.torso == true, pernas = s.usa.pernas == true }
				else
					usa = { cabeca = false, torso = false, pernas = false }
					for _, f in ipairs(frames) do
						if naoZero(f.cabeca) then usa.cabeca = true end
						if naoZero(f.torso) then usa.torso = true end
						if naoZero(f.pernaDir) or naoZero(f.pernaEsq) then usa.pernas = true end
					end
				end
				local d = {
					animado = true,
					duracao = math.max(num(s.duracao, ultimo > 0 and ultimo or 1), ultimo, 0.1),
					loop = s.loop ~= false,
					suave = s.suave ~= false,
					usa = usa,
					frames = frames,
					itens = ItensEmote.copiar(s.itens),
				}
				local f = frames[1]
				d.dir, d.esq = f.dir, f.esq
				d.palmaDir, d.palmaEsq = f.palmaDir, f.palmaEsq
				d.dedosDir, d.dedosEsq = f.dedosDir, f.dedosEsq
				d.afastDir, d.afastEsq = f.afastDir, f.afastEsq
				d.cabeca, d.torso = f.cabeca, f.torso
				d.pernaDir, d.pernaEsq = f.pernaDir, f.pernaEsq
				return d
			end
		end
		local p = poseDe(s)
		p.itens = ItensEmote.copiar(s.itens)
		return p
	end

	local function ehEmote(t)
		return type(t) == "table" and (t.dir ~= nil or t.esq ~= nil or t.frames ~= nil or t.animado ~= nil)
	end

	-- devolve { {nome = "...", dados = tabela}, ... }
	local function acharEmotes(src)
		local raw = lerTabelaLua(src)
		local lista = {}
		if ehEmote(raw) then
			lista[1] = { nome = nil, dados = raw }
		else
			local nomes, soltos = {}, {}
			for k, v in pairs(raw) do
				if ehEmote(v) then
					if type(k) == "string" then nomes[#nomes + 1] = k else soltos[#soltos + 1] = v end
				end
			end
			table.sort(nomes)
			for _, k in ipairs(nomes) do lista[#lista + 1] = { nome = k, dados = raw[k] } end
			for _, v in ipairs(soltos) do lista[#lista + 1] = { nome = nil, dados = v } end
		end
		if #lista == 0 then error("não achei nenhuma animação nesse código", 0) end
		if #lista > 30 then error("emotes demais de uma vez (máximo 30)", 0) end
		return lista
	end

	local function limparNome(s)
		local n = (s or ""):gsub('[%c"\\]', ""):gsub("^%s+", ""):gsub("%s+$", "")
		return n
	end

	local function nomeLivre(base)
		base = limparNome(base)
		if base == "" then base = "Importada" end
		local nome, i = base, 1
		while defaultEmotes[nome] or EMOTE_POR_NOME[nome] do
			i = i + 1
			nome = base .. " (" .. i .. ")"
		end
		return nome
	end

	-- ---------- janela de importar ----------
	local IMP_W, IMP_H = 300, 364
	local ImpModal = frame({
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1),
		Active = true, Visible = false, ZIndex = 40, Parent = MainGui,
	})
	local impCard = frame({
		BackgroundColor3 = T.bg, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(IMP_W, IMP_H), ZIndex = 41, Parent = ImpModal,
	}, { round(14), outline(T.stroke, 1, 0.1), padding(12) })
	local impScale = new("UIScale", { Parent = impCard })
	ajustarEscala(impScale, IMP_W + 24, IMP_H + 24)

	local impHead = frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), ZIndex = 41, Parent = impCard })
	makeDraggable(impCard, impHead)
	local impBadge = frame({ BackgroundColor3 = Color3.fromRGB(64, 48, 14), Size = UDim2.fromOffset(36, 20), Position = UDim2.fromOffset(0, 3), ZIndex = 42, Parent = impHead }, { round(7) })
	txt({ Text = "DEV", Font = F.GothamBold, TextSize = 11, TextColor3 = T.warn, TextXAlignment = CENTER, Size = UDim2.fromScale(1, 1), ZIndex = 43, Parent = impBadge })
	txt({ Text = "Importar animação", Font = F.GothamBold, TextSize = 13, Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -80, 1, 0), ZIndex = 42, Parent = impHead })
	local impX = btn({ Text = "", TextSize = 13, TextColor3 = T.sub, Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -26, 0, 0), ZIndex = 42, Parent = impHead }, { round(13) })
	hoverFX(impX, T.surface2, T.danger)
	T.Icones.centro(impX, "_fechar", 14, 43)

	txt({
		Text = "Cole o código da animação (o texto do Exportar: [\"Nome\"] = { ... }). Ele vira um emote aqui no DEV pra você ver e editar. O texto colado não é executado.",
		TextSize = 10, TextColor3 = T.dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 38), ZIndex = 42, Parent = impCard,
	})

	local impNome = new("TextBox", {
		BackgroundColor3 = T.surface3, BorderSizePixel = 0, Font = F.Code, TextSize = 11, TextColor3 = T.text,
		PlaceholderText = "nome (opcional)", PlaceholderColor3 = T.dim, Text = "", ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, -84, 0, 28), ZIndex = 42, Parent = impCard,
	}, { round(7), padding(8, 0, 8, 0) })
	local impColar = btn({
		Text = "Colar", Font = F.GothamBold, TextSize = 11, Position = UDim2.new(1, -78, 0, 72), Size = UDim2.fromOffset(78, 28), ZIndex = 42, Parent = impCard,
	}, { round(7), outline(T.stroke, 1, 0.3), padding(20, 0, 4, 0) })
	T.Icones.criar("_colar", impColar, 16, { Position = UDim2.new(0, -17, 0.5, -8), ZIndex = 43 })
	hoverFX(impColar, T.surface2, T.surface3)

	local impCodigo = new("TextBox", {
		BackgroundColor3 = T.surface, BorderSizePixel = 0, Font = F.Code, TextSize = 10, TextColor3 = T.ok,
		PlaceholderText = "[\"MinhaAnimacao\"] = {\n\tanimado = true, duracao = 1, ...", PlaceholderColor3 = T.dim,
		Text = "", ClearTextOnFocus = false, MultiLine = true, TextWrapped = true, ClipsDescendants = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 106), Size = UDim2.new(1, 0, 0, 164), ZIndex = 42, Parent = impCard,
	}, { round(8), padding(8), outline(T.stroke, 1, 0.4) })

	local impMsg = txt({
		Text = "", TextSize = 10, TextColor3 = T.danger, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 274), Size = UDim2.new(1, 0, 0, 28), ZIndex = 42, Parent = impCard,
	})
	local function msg(t, cor)
		impMsg.Text = t
		impMsg.TextColor3 = cor or T.danger
	end

	local impCancelar = btn({
		Text = "Cancelar", Font = F.GothamBold, TextSize = 12, Position = UDim2.new(0, 0, 0, 306), Size = UDim2.new(0.4, -4, 0, 34), ZIndex = 42, Parent = impCard,
	}, { round(10), outline(T.stroke, 1, 0.3) })
	local impOk = btn({
		Text = "Importar", Font = F.GothamBold, TextSize = 12, BackgroundColor3 = T.accent, TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(0.4, 4, 0, 306), Size = UDim2.new(0.6, -4, 0, 34), ZIndex = 42, Parent = impCard,
	}, { round(10) })
	hoverFX(impCancelar, T.surface2, T.surface3)
	hoverFX(impOk, T.accent, Color3.fromRGB(148, 134, 255))

	local function fecharImportar() ImpModal.Visible = false end
	impX.MouseButton1Click:Connect(fecharImportar)
	impCancelar.MouseButton1Click:Connect(fecharImportar)

	impCodigo:GetPropertyChangedSignal("Text"):Connect(function() msg("") end)

	-- celular: o teclado cobre metade da tela, então a janela sobe pro topo enquanto você digita/cola
	if UserInputService.TouchEnabled then
		local function topo(sobe)
			impCard.AnchorPoint = sobe and Vector2.new(0.5, 0) or Vector2.new(0.5, 0.5)
			impCard.Position = sobe and UDim2.new(0.5, 0, 0, 8) or UDim2.fromScale(0.5, 0.5)
		end
		for _, caixa in ipairs({ impCodigo, impNome }) do
			caixa.Focused:Connect(function() topo(true) end)
			caixa.FocusLost:Connect(function() topo(false) end)
		end
	end

	impColar.MouseButton1Click:Connect(function()
		local ok, t = pcall(function() return getclipboard() end)
		if ok and type(t) == "string" and t:find("%S") then
			impCodigo.Text = t
			msg("Colado do clipboard.", T.ok)
		else
			msg("Não consegui ler o clipboard. Toque no campo e cole com Ctrl+V / segurar e colar.", T.warn)
		end
	end)

	local function fazerImportar()
		local ok, lista = pcall(acharEmotes, impCodigo.Text)
		if not ok then
			msg("Código inválido: " .. tostring(lista))
			return
		end
		local manual = limparNome(impNome.Text)
		local primeiro
		for _, e in ipairs(lista) do
			local base = e.nome
			if #lista == 1 and manual ~= "" then base = manual end
			local nome = nomeLivre(base or manual)
			local okE, dados = pcall(emoteDe, e.dados)
			if okE then
				defaultEmotes[nome] = dados
				adicionarLinhaDev(nome, "📥")
				primeiro = primeiro or nome
			else
				msg("Não consegui ler '" .. nome .. "': " .. tostring(dados))
			end
		end
		if not primeiro then return end
		impCodigo.Text = ""
		impNome.Text = ""
		ImpModal.Visible = false
		abrirDev(primeiro)
	end
	impOk.MouseButton1Click:Connect(fazerImportar)

	-- botão dentro do seletor de emotes do DEV
	local importarBtn = btn({
		Text = "Importar animação (colar código)", Font = F.GothamBold, TextSize = 11, TextColor3 = T.ok,
		Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 26), ZIndex = 31, Parent = DevSelector,
	}, { round(7), outline(T.stroke, 1, 0.3), padding(24, 0, 6, 0) })
	T.Icones.criar("_importar", importarBtn, 16, { Position = UDim2.new(0, -19, 0.5, -8), ZIndex = 32 })
	hoverFX(importarBtn, T.surface2, T.surface3)
	importarBtn.MouseButton1Click:Connect(function()
		msg("")
		ImpModal.Visible = true
	end)
end

function abrirDev(nome)
	if not carregarEmote(nome) then return end
	if animCarregar then animCarregar(nome) end
	devTitle.Text = nome
	prevNome.Text = nome
	DevPanel.Visible = true
	DevPreviewWin.Visible = configPreviewDev
	devPreview.setActive(configPreviewDev)
	ExportModal.Visible = false
	DevSelector.Visible = false
	toggleMenu(false)
	rebuildTab()
end

local function fecharDev()
	DevPanel.Visible = false
	DevPreviewWin.Visible = false
	devPreview.setActive(false)
	ExportModal.Visible = false
	freezeEmote = false
end

closeDevBtn.MouseButton1Click:Connect(fecharDev)
trocarBtn.MouseButton1Click:Connect(function() DevSelector.Visible = true end)

-- ===================== ANIMADOR (linha do tempo no modo dev) =====================
do
	local TL_W, TL_H = 380, 238
	local anim = {
		nome = "MinhaAnimacao",
		duracao = 2,
		loop = true,
		suave = true,
		keys = {},
		tempo = 0,
		tocando = false,
		sel = nil,
	}

	local TLWin = frame({
		Name = "AnimadorTL", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(TL_W, TL_H),
		BackgroundColor3 = T.bg, Visible = false, Parent = MainGui,
	}, { round(16), outline(T.stroke, 1, 0.1) })
	local tlScale = new("UIScale", { Parent = TLWin })
	ajustarEscala(tlScale, TL_W + 24, TL_H + 24)

	local tlHead = frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = TLWin })
	makeDraggable(TLWin, tlHead)
	txt({ Text = "ANIMADOR", Font = F.GothamBold, TextSize = 11, TextColor3 = T.warn, Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(100, 14), Parent = tlHead })
	local info = txt({ Text = "0 keys", TextSize = 10, TextColor3 = T.dim, TextXAlignment = RIGHT, Position = UDim2.new(1, -176, 0, 10), Size = UDim2.fromOffset(100, 14), Parent = tlHead })

	local function caixa(props)
		return new("TextBox", merge({
			BackgroundColor3 = T.surface3, BorderSizePixel = 0, Font = F.Code, TextSize = 11, TextColor3 = T.text,
			ClearTextOnFocus = false, Parent = TLWin,
		}, props), { round(6) })
	end

	local nomeBox = caixa({ Text = anim.nome, PlaceholderText = "nome", Position = UDim2.fromOffset(12, 40), Size = UDim2.fromOffset(150, 26) })
	local durBox = caixa({ Text = "2.0s", Position = UDim2.fromOffset(170, 40), Size = UDim2.fromOffset(56, 26) })
	local loopBtn = btn({ Text = "Loop", TextSize = 11, Position = UDim2.fromOffset(232, 40), Size = UDim2.fromOffset(68, 26), Parent = TLWin }, { round(6) })
	local suaveBtn = btn({ Text = "Suave", TextSize = 11, Position = UDim2.fromOffset(306, 40), Size = UDim2.fromOffset(62, 26), Parent = TLWin }, { round(6) })
	hoverFX(loopBtn, T.surface2, T.surface3)
	hoverFX(suaveBtn, T.surface2, T.surface3)

	local track = frame({ BackgroundColor3 = T.surface3, Position = UDim2.fromOffset(18, 86), Size = UDim2.new(1, -36, 0, 6), Parent = TLWin }, { round(3) })
	local cursor = frame({
		BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(4, 22),
		Position = UDim2.fromScale(0, 0.5), ZIndex = 3, Parent = track,
	}, { round(2) })
	local hit = btn({ BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 74), Size = UDim2.new(1, -16, 0, 30), ZIndex = 2, Parent = TLWin })
	local marcas = frame({ BackgroundTransparency = 1, Position = track.Position, Size = track.Size, ZIndex = 4, Parent = TLWin })

	txt({ Text = "Tempo", TextSize = 11, TextColor3 = T.sub, Position = UDim2.fromOffset(14, 116), Size = UDim2.fromOffset(40, 18), Parent = TLWin })
	local timeBox = caixa({ Text = "0.00", Position = UDim2.fromOffset(56, 112), Size = UDim2.fromOffset(60, 26) })
	local durLbl = txt({ Text = "/ 2.00s", TextSize = 11, TextColor3 = T.sub, Position = UDim2.fromOffset(124, 116), Size = UDim2.fromOffset(80, 18), Parent = TLWin })

	local prevBtn = btn({ Text = "", TextSize = 13, Position = UDim2.fromOffset(12, 146), Size = UDim2.fromOffset(38, 30), Parent = TLWin }, { round(8) })
	T.Icones.centro(prevBtn, "_prev", 16, 2)
	local playBtn = btn({ Text = "", TextSize = 14, TextColor3 = T.ok, Position = UDim2.fromOffset(56, 146), Size = UDim2.fromOffset(46, 30), Parent = TLWin }, { round(8) })
	T.Icones.centro(playBtn, "_play", 16, 2)
	local nextBtn = btn({ Text = "", TextSize = 12, Position = UDim2.fromOffset(108, 146), Size = UDim2.fromOffset(38, 30), Parent = TLWin }, { round(8) })
	T.Icones.centro(nextBtn, "_next", 16, 2)
	local addBtn = btn({ Text = "Key", Font = F.GothamBold, TextSize = 12, BackgroundColor3 = T.accent, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(154, 146), Size = UDim2.fromOffset(76, 30), Parent = TLWin }, { round(8), padding(22, 0, 4, 0) })
	T.Icones.lado(addBtn, "_mais", 14, 2, 18)
	local delBtn = btn({ Text = "Apagar", TextSize = 11, TextColor3 = T.danger, Position = UDim2.fromOffset(236, 146), Size = UDim2.fromOffset(54, 30), Parent = TLWin }, { round(8) })
	local expBtn = btn({ Text = "Exportar", Font = F.GothamBold, TextSize = 11, TextColor3 = T.ok, Position = UDim2.fromOffset(296, 146), Size = UDim2.fromOffset(72, 30), Parent = TLWin }, { round(8) })
	for _, b in ipairs({ prevBtn, playBtn, nextBtn, delBtn, expBtn }) do hoverFX(b, T.surface2, T.surface3) end
	hoverFX(addBtn, T.accent, Color3.fromRGB(148, 134, 255))

	txt({ Text = "Faça a pose nos sliders → escolha o tempo → Key", TextSize = 10, TextColor3 = T.dim, TextXAlignment = CENTER, Position = UDim2.fromOffset(0, 218), Size = UDim2.new(1, 0, 0, 14), Parent = TLWin })

	local moveBtn = btn({ Text = "Mover key", TextSize = 11, Position = UDim2.fromOffset(12, 182), Size = UDim2.fromOffset(114, 28), Parent = TLWin }, { round(8), padding(22, 0, 4, 0) })
	T.Icones.lado(moveBtn, "_trocar", 16, 2, 19)
	local copyBtn = btn({ Text = "Copiar", TextSize = 11, Position = UDim2.fromOffset(133, 182), Size = UDim2.fromOffset(114, 28), Parent = TLWin }, { round(8), padding(22, 0, 4, 0) })
	T.Icones.lado(copyBtn, "_copiar", 16, 2, 19)
	local pasteBtn = btn({ Text = "Colar", TextSize = 11, TextColor3 = T.dim, Position = UDim2.fromOffset(254, 182), Size = UDim2.fromOffset(114, 28), Parent = TLWin }, { round(8), padding(20, 0, 4, 0) })
	T.Icones.criar("_colar", pasteBtn, 16, { Position = UDim2.new(0, -19, 0.5, -8), ZIndex = 3 })
	for _, b in ipairs({ moveBtn, copyBtn, pasteBtn }) do hoverFX(b, T.surface2, T.surface3) end
	local clipPose = nil -- pose copiada (persiste entre emotes)

	-- ---------- interpolação ----------
	local function lerpTab(a, b, t)
		if type(a) == "number" then
			if type(b) == "number" then return a + (b - a) * t end
			return a
		end
		local r = {}
		for k, v in pairs(a) do
			if b[k] ~= nil then r[k] = lerpTab(v, b[k], t) else r[k] = copiaProfunda(v) end
		end
		return r
	end

	local function suavizar(u)
		if anim.suave then return u * u * (3 - 2 * u) end
		return u
	end

	local function ordenar()
		table.sort(anim.keys, function(a, b) return a.t < b.t end)
	end

	local function poseEm(tempo)
		local ks = anim.keys
		local n = #ks
		if n == 0 then return nil end
		if n == 1 or tempo <= ks[1].t then return ks[1].pose end
		local ultimo = ks[n]
		if tempo >= ultimo.t then
			if anim.loop and anim.duracao > ultimo.t + 0.001 then
				local u = clamp((tempo - ultimo.t) / (anim.duracao - ultimo.t), 0, 1)
				return lerpTab(ultimo.pose, ks[1].pose, suavizar(u))
			end
			return ultimo.pose
		end
		for i = 1, n - 1 do
			local a, b = ks[i], ks[i + 1]
			if tempo >= a.t and tempo <= b.t then
				local u = (tempo - a.t) / math.max(b.t - a.t, 0.0001)
				return lerpTab(a.pose, b.pose, suavizar(u))
			end
		end
		return ultimo.pose
	end

	local function aplicarPose(p)
		if not p then return end
		for _, lado in ipairs({ "direita", "esquerda" }) do
			for k, v in pairs(p[lado]) do customPose[lado][k] = copiaProfunda(v) end
		end
		for _, parte in ipairs({ "cabeca", "torso", "pernaDir", "pernaEsq" }) do
			customPose[parte] = copiaProfunda(p[parte])
		end
	end

	-- ---------- UI ----------
	local irPara

	local function atualizarPlay()
		T.Icones.centro(playBtn, anim.tocando and "_pause" or "_play", 16, 2)
	end

	local function desenhar()
		for _, c in ipairs(marcas:GetChildren()) do c:Destroy() end
		for _, k in ipairs(anim.keys) do
			local m = btn({
				BackgroundColor3 = (k == anim.sel) and T.warn or T.accent, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45,
				Position = UDim2.new(clamp(k.t / anim.duracao, 0, 1), 0, 0.5, 0), Size = UDim2.fromOffset(13, 13), ZIndex = 5, Parent = marcas,
			}, { round(2) })
			m.MouseButton1Click:Connect(function()
				anim.tocando = false
				atualizarPlay()
				anim.sel = k
				desenhar()
				irPara(k.t, true)
			end)
		end
		info.Text = #anim.keys .. (#anim.keys == 1 and " key" or " keys")
		durLbl.Text = string.format("/ %.2fs", anim.duracao)
		durBox.Text = string.format("%.1fs", anim.duracao)
	end

	function irPara(tempo, reconstruir)
		anim.tempo = clamp(tempo, 0, anim.duracao)
		aplicarPose(poseEm(anim.tempo))
		cursor.Position = UDim2.fromScale(clamp(anim.tempo / anim.duracao, 0, 1), 0.5)
		timeBox.Text = string.format("%.2f", anim.tempo)
		if reconstruir then rebuildTab() end
	end

	-- ---------- controles ----------
	nomeBox.FocusLost:Connect(function()
		local n = nomeBox.Text:gsub('["\\%c]', ""):gsub("^%s+", ""):gsub("%s+$", "")
		if n == "" then n = "MinhaAnimacao" end
		anim.nome = n
		nomeBox.Text = n
	end)

	durBox.FocusLost:Connect(function()
		local v = tonumber((durBox.Text:gsub("[^%d%.]", "")))
		if v then
			anim.duracao = clamp(v, 0.2, 60)
			for _, k in ipairs(anim.keys) do k.t = math.min(k.t, anim.duracao) end
		end
		desenhar()
		irPara(anim.tempo, false)
	end)

	timeBox.FocusLost:Connect(function()
		local v = tonumber(timeBox.Text)
		anim.tocando = false
		atualizarPlay()
		irPara(v or anim.tempo, true)
	end)

	local function atualizarToggles()
		loopBtn.Text = "Loop"
		T.Icones.direita(loopBtn, anim.loop and "_check" or "_fechar_r", 12, 2, 8)
		loopBtn.TextColor3 = anim.loop and T.ok or T.dim
		suaveBtn.Text = anim.suave and "Suave" or "Linear"
		suaveBtn.TextColor3 = anim.suave and T.ok or T.sub
	end
	atualizarToggles()
	loopBtn.MouseButton1Click:Connect(function() anim.loop = not anim.loop; atualizarToggles() end)
	suaveBtn.MouseButton1Click:Connect(function() anim.suave = not anim.suave; atualizarToggles() end)

	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			anim.tocando = false
			atualizarPlay()
			local function porX(x)
				local r = clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
				irPara(r * anim.duracao, false)
			end
			activeSlider = porX
			porX(input.Position.X)
		end
	end)
	hit.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			rebuildTab()
		end
	end)

	playBtn.MouseButton1Click:Connect(function()
		if #anim.keys == 0 then return end
		anim.tocando = not anim.tocando
		if anim.tocando and anim.tempo >= anim.duracao - 0.001 then anim.tempo = 0 end
		if not anim.tocando then rebuildTab() end
		atualizarPlay()
	end)

	local function saltar(dir)
		local alvo
		local ks = anim.keys
		if dir < 0 then
			for i = #ks, 1, -1 do
				if ks[i].t < anim.tempo - 0.005 then
					alvo = ks[i]
					break
				end
			end
		else
			for i = 1, #ks do
				if ks[i].t > anim.tempo + 0.005 then
					alvo = ks[i]
					break
				end
			end
		end
		if alvo then
			anim.tocando = false
			atualizarPlay()
			anim.sel = alvo
			desenhar()
			irPara(alvo.t, true)
		end
	end
	prevBtn.MouseButton1Click:Connect(function() saltar(-1) end)
	nextBtn.MouseButton1Click:Connect(function() saltar(1) end)

	addBtn.MouseButton1Click:Connect(function()
		anim.tocando = false
		atualizarPlay()
		local t = math.floor(anim.tempo * 100 + 0.5) / 100
		local existente
		for _, k in ipairs(anim.keys) do
			if math.abs(k.t - t) < 0.02 then existente = k end
		end
		if existente then
			existente.pose = copiaProfunda(customPose)
			anim.sel = existente
		else
			local k = { t = t, pose = copiaProfunda(customPose) }
			table.insert(anim.keys, k)
			ordenar()
			anim.sel = k
		end
		desenhar()
	end)

	delBtn.MouseButton1Click:Connect(function()
		local alvo = anim.sel
		if not alvo then
			for _, k in ipairs(anim.keys) do
				if math.abs(k.t - anim.tempo) < 0.02 then alvo = k end
			end
		end
		if not alvo then return end
		for i, k in ipairs(anim.keys) do
			if k == alvo then table.remove(anim.keys, i) break end
		end
		anim.sel = nil
		desenhar()
	end)

	local function keyNoTempo(t, ignorar)
		for _, k in ipairs(anim.keys) do
			if k ~= ignorar and math.abs(k.t - t) < 0.02 then return k end
		end
	end

	-- Mover: leva a key selecionada (ou a do tempo atual) para a posição do cursor
	moveBtn.MouseButton1Click:Connect(function()
		anim.tocando = false
		atualizarPlay()
		local alvo = anim.sel
		if not alvo or not table.find(anim.keys, alvo) then return end
		local t = math.floor(anim.tempo * 100 + 0.5) / 100
		local outro = keyNoTempo(t, alvo)
		if outro then
			local i = table.find(anim.keys, outro)
			if i then table.remove(anim.keys, i) end
		end
		alvo.t = t
		ordenar()
		desenhar()
		irPara(t, true)
	end)

	-- Copiar: guarda a pose da key selecionada, da key no tempo atual ou, sem key, a pose atual dos sliders
	copyBtn.MouseButton1Click:Connect(function()
		local fonte = anim.sel
		if not fonte or not table.find(anim.keys, fonte) then fonte = keyNoTempo(anim.tempo) end
		clipPose = copiaProfunda(fonte and fonte.pose or customPose)
		pasteBtn.TextColor3 = T.ok
		copyBtn.Text = "Copiado"
		T.Icones.lado(copyBtn, "_check", 16, 2, 19)
		task.delay(0.8, function()
			copyBtn.Text = "Copiar"
			T.Icones.lado(copyBtn, "_copiar", 16, 2, 19)
		end)
	end)

	-- Colar: cria (ou sobrescreve) uma key no tempo atual com a pose copiada
	pasteBtn.MouseButton1Click:Connect(function()
		if not clipPose then return end
		anim.tocando = false
		atualizarPlay()
		local t = math.floor(anim.tempo * 100 + 0.5) / 100
		local k = keyNoTempo(t)
		if k then
			k.pose = copiaProfunda(clipPose)
		else
			k = { t = t, pose = copiaProfunda(clipPose) }
			table.insert(anim.keys, k)
			ordenar()
		end
		anim.sel = k
		desenhar()
		irPara(t, true)
	end)

	-- ---------- exportar ----------
	local function gerarAnimLua()
		if #anim.keys == 0 then return "-- adicione pelo menos 1 keyframe (Key)" end

		local function v3(t) return string.format("{ x = %s, y = %s, z = %s }", fmt(t.x), fmt(t.y), fmt(t.z)) end
		local function br(t) return string.format("{ x = %s, y = %s, z = %s, px = %s, py = %s, pz = %s }", fmt(t.x), fmt(t.y), fmt(t.z), fmt(t.px or 0), fmt(t.py or 0), fmt(t.pz or 0)) end
		local function dedos(h)
			local o = {}
			for i = 1, 5 do
				local d = h.dedos[i]
				if dedoTemExtra(d) then
					o[i] = string.format("{%s,%s,%s,%s,%s,%s,%s,%s}", fmt(d[1]), fmt(d[2]), fmt(d[3] or 0), fmt(d[4] or 0), fmt(d[5] or 0), fmt(d[6] or 0), fmt(d[7] or 0), fmt(d[8] or 0))
				else
					o[i] = string.format("{%s,%s}", fmt(d[1]), fmt(d[2]))
				end
			end
			return "{ " .. table.concat(o, ", ") .. " }"
		end

		local linhas = {}
		linhas[#linhas + 1] = string.format('["%s"] = {', anim.nome)
		linhas[#linhas + 1] = string.format("\tanimado = true, duracao = %s, loop = %s, suave = %s,", fmt(anim.duracao), tostring(anim.loop), tostring(anim.suave))
		linhas[#linhas + 1] = string.format("\tusa = { cabeca = %s, torso = %s, pernas = %s },", tostring(animConfig.cabeca == true), tostring(animConfig.torso == true), tostring(animConfig.pernas == true))
		local itensTxt = ItensEmote.texto(customPose.itens, "\t")
		if itensTxt then linhas[#linhas + 1] = itensTxt .. "," end
		linhas[#linhas + 1] = "\tframes = {"
		for _, k in ipairs(anim.keys) do
			local P = k.pose
			local D, E = P.direita, P.esquerda
			linhas[#linhas + 1] = string.format("\t\t{ t = %s,", fmt(k.t))
			linhas[#linhas + 1] = string.format("\t\t\tdir = %s, palmaDir = %s,", br(D.braco), v3(D.palma))
			linhas[#linhas + 1] = string.format("\t\t\tdedosDir = %s, afastDir = %s,", dedos(D), fmt(D.afastamento))
			linhas[#linhas + 1] = string.format("\t\t\tesq = %s, palmaEsq = %s,", br(E.braco), v3(E.palma))
			linhas[#linhas + 1] = string.format("\t\t\tdedosEsq = %s, afastEsq = %s,", dedos(E), fmt(E.afastamento))
			linhas[#linhas + 1] = string.format("\t\t\tcabeca = %s, torso = %s,", br(P.cabeca), br(P.torso))
			linhas[#linhas + 1] = string.format("\t\t\tpernaDir = %s, pernaEsq = %s },", br(P.pernaDir), br(P.pernaEsq))
		end
		linhas[#linhas + 1] = "\t},"
		linhas[#linhas + 1] = "},"
		return table.concat(linhas, "\n")
	end

	expBtn.MouseButton1Click:Connect(function()
		anim.tocando = false
		atualizarPlay()
		local out = gerarAnimLua()
		print("========== COPIE A ANIMAÇÃO ABAIXO ==========")
		print(out)
		print("=============================================")
		-- copia direto pro clipboard, sem abrir a janelinha (ela fica só pro Exportar do painel de pose)
		local ok = pcall(function() setclipboard(out) end)
		if ok then
			expBtn.Text = "Copiado!"
			task.delay(1.5, function() expBtn.Text = "Exportar" end)
		else
			-- executor sem setclipboard: abre a janelinha pra você copiar na mão
			exportBox.Text = out
			ExportModal.Visible = true
		end
	end)

	-- ---------- reprodução ----------
	RunService.RenderStepped:Connect(function(dt)
		if not anim.tocando then return end
		if not TLWin.Visible or #anim.keys == 0 then
			anim.tocando = false
			atualizarPlay()
			return
		end
		local t = anim.tempo + dt
		if t >= anim.duracao then
			if anim.loop then
				t = t % anim.duracao
			else
				t = anim.duracao
				anim.tocando = false
				atualizarPlay()
			end
		end
		irPara(t, false)
	end)

	function animNovo(nome)
		anim.tocando = false
		atualizarPlay()
		anim.nome = nome
		nomeBox.Text = nome
		anim.keys = {}
		anim.sel = nil
		anim.tempo = 0
		cursor.Position = UDim2.fromScale(0, 0.5)
		timeBox.Text = "0.00"
		desenhar()
	end

	-- Abre um emote existente no animador: se ele for animado, importa os keyframes dele
	-- (duração, loop, suave e os frames); se não for, só zera a timeline (como um emote novo).
	function animCarregar(nome)
		local d = defaultEmotes[nome]
		if not (d and d.animado and d.frames and #d.frames > 0) then
			animNovo(nome)
			return
		end

		anim.tocando = false
		atualizarPlay()
		anim.nome = nome
		nomeBox.Text = nome
		anim.duracao = d.duracao or 1
		anim.loop = d.loop == true
		anim.suave = d.suave == true
		atualizarToggles()

		local function lado(braco, palma, dedos, afast)
			local h = { braco = copiaProfunda(braco), palma = copiaProfunda(palma), dedos = {}, afastamento = afast or 0 }
			for i = 1, 5 do h.dedos[i] = copiaDedo(dedos and dedos[i]) end
			return h
		end

		anim.keys = {}
		for _, f in ipairs(d.frames) do
			table.insert(anim.keys, {
				t = f.t,
				pose = {
					direita = lado(f.dir, f.palmaDir, f.dedosDir, f.afastDir),
					esquerda = lado(f.esq, f.palmaEsq, f.dedosEsq, f.afastEsq),
					cabeca = copiaProfunda(f.cabeca),
					torso = copiaProfunda(f.torso),
					pernaDir = copiaProfunda(f.pernaDir),
					pernaEsq = copiaProfunda(f.pernaEsq),
				},
			})
		end
		ordenar()

		local u = d.usa or {}
		animConfig.cabeca = u.cabeca == true
		animConfig.torso = u.torso == true
		animConfig.pernas = u.pernas == true

		anim.sel = anim.keys[1]
		desenhar()
		irPara(0, false)
	end

	TLWin.Visible = DevPanel.Visible
	DevPanel:GetPropertyChangedSignal("Visible"):Connect(function()
		TLWin.Visible = DevPanel.Visible
		if not DevPanel.Visible then
			anim.tocando = false
			atualizarPlay()
		end
	end)

	janelaControles({
		win = TLWin, head = tlHead, scale = tlScale, w = TL_W, h = TL_H, headH = 34,
		posMin = UDim2.new(1, -66, 0, 4), posX = UDim2.new(1, -34, 0, 4), size = 26,
		ativo = function() return DevPanel.Visible end, pai = DevPanel,
		onHide = function() anim.tocando = false; atualizarPlay() end,
	})

	desenhar()
end

local emotesDev = {
	"Tchau", "Paz", "Sim", "Maçaneta", "Bow", "Dedo", "Citação", "Sentido", "Convidando",
	"Dancinha", "Cala a Boca", "Braços Cruzados", "Deitado de Frente", "Sentar", "Ajoelhar",
	"Dormir", "Dormir2", "Siririca",
	"Chupada de Dedo", "De Quatro", "Socar", "Kamehameha",
}
local ordemLinhaDev = 0
function adicionarLinhaDev(nome, icone)
	ordemLinhaDev = ordemLinhaDev + 1
	local row = btn({ BackgroundColor3 = T.surface, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = ordemLinhaDev, ZIndex = 30, Parent = selList }, { round(8) })
	T.Icones.criar((not T.Icones.tem(nome) and icone == "📥") and "_importar" or nome, row, 24, { Position = UDim2.fromOffset(5, 3), ZIndex = 31 })
	txt({ Text = nome, Font = F.GothamMedium, TextSize = 12, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -44, 1, 0), ZIndex = 31, Parent = row })
	hoverFX(row, T.surface, T.surface3)
	row.MouseButton1Click:Connect(function() abrirDev(nome) end)
end
local jaNaListaDev = {}
for _, nome in ipairs(emotesDev) do
	jaNaListaDev[nome] = true
	adicionarLinhaDev(nome, EMOTE_POR_NOME[nome].icone)
end
-- qualquer emote novo colado em defaultEmotes que não esteja na lista acima aparece sozinho aqui
do
	local extras = {}
	for nome, d in pairs(defaultEmotes) do
		if not jaNaListaDev[nome] and type(d) == "table" and (d.dir or d.frames) then extras[#extras + 1] = nome end
	end
	table.sort(extras)
	for _, nome in ipairs(extras) do
		jaNaListaDev[nome] = true
		adicionarLinhaDev(nome, EMOTE_POR_NOME[nome] and EMOTE_POR_NOME[nome].icone or "✨")
	end
end

abrirPainelDev = function()
	DevSelector.Visible = true
	toggleMenu(false)
end
aoMudarPreviewDev = function(on)
	if DevPanel.Visible then
		DevPreviewWin.Visible = on
		devPreview.setActive(on)
	end
end
end
montarDevPanel()

local function limparAgachamentoBow(character)
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		local originalHeight = character:GetAttribute("OriginalHipHeight")
		humanoid.HipHeight = originalHeight or 2
		humanoid.AutoRotate = true
		humanoid.PlatformStand = false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		local bodyVelocity = rootPart:FindFirstChild("BowVelocityLock")
		local bodyGyro = rootPart:FindFirstChild("BowGyroLock")
		if bodyVelocity then bodyVelocity:Destroy() end
		if bodyGyro then bodyGyro:Destroy() end
	end
end

local function aplicarCorpoBow(character, humanoid, rootPart, comTravas, emote)
	if not character:GetAttribute("OriginalHipHeight") then
		character:SetAttribute("OriginalHipHeight", humanoid.HipHeight)
	end

	local altura = emote and EMOTES_BAIXOS[emote]
	if altura then
		humanoid.HipHeight = altura
		humanoid.AutoRotate = false
		humanoid.PlatformStand = false
	else
		humanoid.HipHeight = 0.5
		humanoid.AutoRotate = false
		humanoid.PlatformStand = true
	end

	if comTravas and rootPart then
		local bodyVelocity = rootPart:FindFirstChild("BowVelocityLock")
		local bodyGyro = rootPart:FindFirstChild("BowGyroLock")
		if not bodyVelocity then
			bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.Name = "BowVelocityLock"
			bodyVelocity.MaxForce = Vector3.new(1, 0, 1) * 10000
			bodyVelocity.Velocity = Vector3.new(0, 0, 0)
			bodyVelocity.Parent = rootPart
		end
		if not bodyGyro then
			bodyGyro = Instance.new("BodyGyro")
			bodyGyro.Name = "BowGyroLock"
			bodyGyro.MaxTorque = Vector3.new(4000, 4000, 4000)
			bodyGyro.D = 1000
			bodyGyro.P = 10000
			bodyGyro.CFrame = rootPart.CFrame
			bodyGyro.Parent = rootPart
		end
	end
end

-- ===== KAME.criar(ctx): sistema completo do Kamehameha (sons, falas, VFX, feixe, fling, recuo) =====
-- Usado pelo jogador (criarMaoDinamica) e por cada clone. ctx:
--   character, rootPart, rightArm, leftArm, folder (onde o VFX nasce), partesMao (lista com braco/palma/pBase/pPonta),
--   ehLocal (true = camera do jogador treme/puxa), filtro (opcional: funcao que devolve o que o feixe ignora)
function KAME.criar(ctx)
	local character, rootPart = ctx.character, ctx.rootPart
	local rightArm, leftArm = ctx.rightArm, ctx.leftArm
	local folder, partesMao, ehLocal = ctx.folder, ctx.partesMao, ctx.ehLocal == true
	local kameSnds = {}

	local function kameSomParar(imediato)
		local agora = os.clock()
		for i = #kameSnds, 1, -1 do
			local e = kameSnds[i]
			if imediato or not (e.inst and e.inst.Parent) then
				pcall(function() e.inst:Stop() e.inst:Destroy() end)
				table.remove(kameSnds, i)
			elseif not e.morrendo then
				e.morrendo = true
				e.mInicio = agora
				e.mVol = e.inst.Volume
			end
		end
	end

	-- fimClock: os.clock() em que a fase termina (o volume desce suave ate la)
	local function kameSomTocar(id, fimClock)
		kameSomParar()
		if not (rootPart and rootPart.Parent) then return end
		local s = Instance.new("Sound")
		s.Name = "SomKamehameha"
		s.SoundId = id
		s.Volume = 0
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.MaxDistance = 120
		s.Parent = rootPart
		s:Play()
		game:GetService("Debris"):AddItem(s, 10)
		table.insert(kameSnds, { inst = s, inicio = os.clock(), fim = fimClock })
	end

	local function kameSomAtualizar()
		local agora = os.clock()
		for i = #kameSnds, 1, -1 do
			local e = kameSnds[i]
			local s = e.inst
			if not (s and s.Parent) then
				table.remove(kameSnds, i)
			elseif e.morrendo then
				local a = (agora - e.mInicio) / KAME.fadeParar
				if a >= 1 then
					pcall(function() s:Stop() s:Destroy() end)
					table.remove(kameSnds, i)
				else
					s.Volume = e.mVol * (1 - a)
				end
			else
				local v = clamp((agora - e.inicio) / KAME.fadeEntrada, 0, 1)
				if e.fim then v = v * clamp((e.fim - agora) / KAME.fadeSaida, 0, 1) end
				v = v * v * (3 - 2 * v)
				s.Volume = KAME.volume * v
			end
		end
	end

	-- ===== Kamehameha: FALAS do Goku =====
	-- Mesmo sistema de falas do SANDEVISTAN: 1 BillboardGui sobre a cabeca, 1 TextLabel por letra,
	-- tamanho fixo em pixels, digitacao letra por letra, tremor/pulso por emocao.
	-- Fase 1 = frase curta | Fase 2 = "KA... ME... HA... ME..." | Fase 3 = grito "HAAAAA!!!"
	local kameFala = (function()
		local TextService = game:GetService("TextService")

		local ATIVO = true
		local TAM_BASE = 16          -- tamanho da letra (pixels)
		local LARGURA_MAX = 260      -- largura maxima antes de quebrar linha
		local ALTURA_CABECA = 2.1    -- studs acima da cabeca

		-- Emocoes: cor, velocidade de digitacao, tremor, pulso e extras
		local EMOCOES = {
			calmo = { cor = Color3.fromRGB(255, 190, 80),  vel = 0.035, tremor = 0,   pulso = 0.02 },
			carga = { cor = Color3.fromRGB(110, 200, 255), vel = 0.022, tremor = 0.8, pulso = 0.06 },
			grito = { cor = Color3.fromRGB(235, 250, 255), vel = 0.014, tremor = 2.0, pulso = 0.12, pulo = true },
		}

		-- Fase 1 (anda): frase curta aleatoria  {texto, emocao}
		local FALAS_INICIO = {
			{ "Preste atenção!", "calmo" },
			{ "Olha só isso!", "calmo" },
			{ "Vou te mostrar!", "calmo" },
			{ "Hora do meu golpe!", "calmo" },
		}

		-- Fase 2 (carregando): silabas. t = segundos depois do inicio da fase 2 (dura 1.85s)
		--  {t, texto, emocao, intensidade 1-3, tempo de leitura}
		local SILABAS = {
			{ 0.00, "KA...", "carga", 1, 0.35 },
			{ 0.45, "ME...", "carga", 1, 0.35 },
			{ 0.90, "HA...", "carga", 2, 0.35 },
			{ 1.40, "ME...", "carga", 2, 0.35 },
		}

		-- Fase 3 (disparo): grito aleatorio
		local FALAS_DISPARO = {
			{ "HAAAAAAAAAAAA!!!", "grito", 3 },
			{ "KAMEHAMEHAAAAA!!!", "grito", 3 },
			{ "HAAAAAAAAAA!!!", "grito", 3 },
		}

		local S = { gui = nil, caixa = nil, token = 0, ciclo = 0, ultimo = nil }

		local function garantirGui()
			local head = character and character:FindFirstChild("Head")
			if not head then return nil end
			if S.gui and S.gui.Parent then
				if S.gui.Adornee ~= head then S.gui.Adornee = head end
				return S.gui
			end
			local gui = Instance.new("BillboardGui")
			gui.Name = "GokuFalas"
			gui.Adornee = head
			gui.AlwaysOnTop = true
			gui.LightInfluence = 0
			gui.ResetOnSpawn = false
			gui.Active = false
			gui.Size = UDim2.fromOffset(40, 24) -- OFFSET = pixels, ignora zoom/distancia
			gui.StudsOffsetWorldSpace = Vector3.new(0, ALTURA_CABECA, 0)
			gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

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
			S.token += 1
			S.ciclo += 1 -- cancela silabas agendadas
			if S.caixa then
				S.caixa.Visible = false
				S.caixa:ClearAllChildren()
			end
		end

		local function mostrar(texto, emo, inten, ler)
			if not ATIVO then return end
			local gui = garantirGui()
			if not gui then return end
			local caixa = S.caixa
			local e = EMOCOES[emo] or EMOCOES.calmo
			inten = math.clamp(inten or 1, 1, 3)

			S.token += 1
			local meuToken = S.token
			local tam = TAM_BASE + (inten - 1) * 4
			local altLinha = tam + 4

			caixa:ClearAllChildren()

			-- 1) mede cada letra e quebra em linhas
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
					table.insert(chars, { ch = ch, w = lw })
					larg += lw
				end
				table.insert(palavras, { chars = chars, w = larg })
			end

			local espaco = larguraChar(" ")
			local linhas, atual, atualW = {}, {}, 0
			for _, p in ipairs(palavras) do
				local extra = (#atual > 0) and espaco or 0
				if #atual > 0 and atualW + extra + p.w > LARGURA_MAX then
					table.insert(linhas, { palavras = atual, w = atualW })
					atual, atualW, extra = {}, 0, 0
				end
				table.insert(atual, p)
				atualW += extra + p.w
			end
			if #atual > 0 then table.insert(linhas, { palavras = atual, w = atualW }) end

			local larguraTotal = 0
			for _, l in ipairs(linhas) do larguraTotal = math.max(larguraTotal, l.w) end
			local alturaTotal = #linhas * altLinha

			-- 2) 1 TextLabel por letra, centralizado por linha
			local letras = {}
			for li, l in ipairs(linhas) do
				local x = (larguraTotal - l.w) / 2
				local y = (li - 1) * altLinha
				for pi, p in ipairs(l.palavras) do
					for _, c in ipairs(p.chars) do
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
						table.insert(letras, { lbl = lbl, ch = c.ch, bx = x - 2, by = y, dx = 0, dy = 0, fase = math.random() * 6.28 })
						x += c.w
					end
					if pi < #l.palavras then x += espaco end
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
			local amp = e.tremor * inten * 0.8 -- tremor de CADA letra

			task.spawn(function()
				local t0 = os.clock()
				local proxTremor = 0
				while S.token == meuToken do
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

							-- grito: onda pulando letra por letra
							if e.pulo then dy -= math.abs(math.sin(t * 9 + i * 0.55)) * 2.2 * inten end

							-- cada letra entra de baixo com um pulinho
							local entra = math.clamp(tLetra / 0.1, 0, 1)
							dy += (1 - entra) * 5

							lbl.Position = UDim2.fromOffset(L.bx + dx, L.by + dy)

							local pulso = e.pulso * inten * math.sin(t * 11 + L.fase)
							lbl.TextSize = tam * (1 + pulso) * (0.8 + 0.2 * entra)

							lbl.TextTransparency = fadeK + (1 - entra) * (1 - fadeK)
							lbl.TextStrokeTransparency = 0.35 + 0.65 * lbl.TextTransparency
						end
					end

					RunService.RenderStepped:Wait()
				end
				if S.token == meuToken then
					caixa.Visible = false
					caixa:ClearAllChildren()
				end
			end)
		end

		-- sorteia sem repetir a ultima
		local function sortear(lista)
			local f = lista[math.random(1, #lista)]
			if f[1] == S.ultimo and #lista > 1 then
				f = lista[(table.find(lista, f) % #lista) + 1]
			end
			S.ultimo = f[1]
			return f
		end

		-- chamada quando a fase da Kamehameha muda (t = tempo atual dentro do ciclo)
		local function entrar(fase, t)
			if not ATIVO then return end
			S.ciclo += 1
			local meu = S.ciclo

			if fase == 1 then
				local f = sortear(FALAS_INICIO)
				mostrar(f[1], f[2], 1, 0.4)

			elseif fase == 2 then
				for _, s in ipairs(SILABAS) do
					task.spawn(function()
						local espera = (KAME.tFase2 + s[1]) - t
						if espera < -0.25 then return end -- silaba ja passou
						if espera > 0 then task.wait(espera) end
						if S.ciclo ~= meu then return end
						mostrar(s[2], s[3], s[4], s[5])
					end)
				end

			elseif fase == 3 then
				local f = sortear(FALAS_DISPARO)
				local ler = math.max(0.6, KAME.ciclo - t - 0.8) -- segura o grito ate o fim do disparo
				mostrar(f[1], f[2], f[3], ler)
			end
		end

		return {
			entrar = entrar, parar = parar,
			destruir = function()
				parar()
				if S.gui then S.gui:Destroy() S.gui = nil S.caixa = nil end
			end,
		}
	end)()

	-- ===== Kamehameha VFX =====
	local kameFX = nil
	local kameRay = RaycastParams.new()
	kameRay.FilterType = Enum.RaycastFilterType.Exclude
	kameRay.FilterDescendantsInstances = ctx.filtro and ctx.filtro() or { character, folder }

	local function kameParte(nome, forma)
		local p = Instance.new("Part")
		p.Name = nome
		p.Shape = forma or Enum.PartType.Ball
		p.Material = Enum.Material.Neon
		p.Color = KAME.cor
		p.Size = Vector3.new(1, 1, 1)
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		return p
	end

	local function kameEmissor(pai, cfg)
		local e = Instance.new("ParticleEmitter")
		e.Texture = cfg.tex or "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(cfg.cor or KAME.cor)
		e.LightEmission = cfg.luz or 1
		e.Lifetime = cfg.vida
		e.Speed = cfg.vel
		e.Size = cfg.tam
		e.Transparency = cfg.transp or NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.7, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Rate = 0
		e.Rotation = NumberRange.new(0, 360)
		e.Acceleration = cfg.acel or Vector3.new(0, 0, 0)
		e.Drag = cfg.drag or 0
		e.Shape = cfg.forma or Enum.ParticleEmitterShape.Box
		e.ShapeInOut = cfg.dentro or Enum.ParticleEmitterShapeInOut.Outward
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.SpreadAngle = cfg.spread or Vector2.new(0, 0)
		e.EmissionDirection = cfg.dir or Enum.NormalId.Top
		e.Parent = pai
		return e
	end

	local function kameVfxCriar()
		local pasta = Instance.new("Folder")
		pasta.Name = "KamehamehaFX"
		pasta.Parent = folder

		local fx = { pasta = pasta, g = 0, ondas = {}, raios = {}, disparou = false }
		local function nova(nome, forma)
			local p = kameParte(nome, forma)
			p.Parent = pasta
			return p
		end

		-- esfera de energia
		fx.brilho = nova("Brilho")
		fx.nucleo = nova("Nucleo")
		fx.nucleo.Color = KAME.corNucleo
		fx.luz = Instance.new("PointLight")
		fx.luz.Color = KAME.cor
		fx.luz.Range = 24
		fx.luz.Brightness = 0
		fx.luz.Shadows = false
		fx.luz.Parent = fx.brilho

		-- raios de luz saindo da esfera
		for i = 1, 9 do
			local p = nova("Raio", Enum.PartType.Block)
			p.Color = (i % 2 == 0) and KAME.corNucleo or KAME.cor
			fx.raios[i] = {
				p = p,
				d0 = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1).Unit,
				vel = (math.random() * 2 - 1) * 2.4,
				ph = math.random() * 6.28,
				esp = 0.08 + math.random() * 0.1,
			}
		end

		-- particulas convergindo pra esfera + explosao de faiscas
		fx.conv = nova("Ancora")
		-- mini trails semi transparentes sendo sugados pra esfera (no lugar das estrelinhas)
		fx.sugados = {}
		fx.sugAcc = 0
		for i = 1, KAME.trailQtd do
			local tp = nova("Sugado")
			tp.Size = Vector3.new(0.2, 0.2, 0.2)
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 0.15, 0)
			a0.Parent = tp
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -0.15, 0)
			a1.Parent = tp
			local tr = Instance.new("Trail")
			tr.Texture = KAME.trailTex
			tr.TextureMode = Enum.TextureMode.Stretch
			tr.Attachment0 = a0
			tr.Attachment1 = a1
			tr.Lifetime = 0.25
			tr.MinLength = 0.02
			tr.FaceCamera = true
			tr.LightEmission = 1
			tr.Color = ColorSequence.new(KAME.cor, KAME.corNucleo)
			tr.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, KAME.trailTransp),
				NumberSequenceKeypoint.new(1, 1),
			})
			tr.WidthScale = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0),
			})
			tr.Enabled = false
			tr.Parent = tp
			fx.sugados[i] = { p = tp, tr = tr, vivo = false, t = 0, dur = 0.5, d = Vector3.new(0, 1, 0), r = 0, giro = 0 }
		end
		fx.conv.Size = Vector3.new(7, 7, 7)

		-- feixe (3 camadas)
		fx.feixeFora = nova("FeixeFora", Enum.PartType.Cylinder)
		fx.feixeMeio = nova("FeixeMeio", Enum.PartType.Cylinder)
		fx.feixeNucleo = nova("FeixeNucleo", Enum.PartType.Cylinder)
		fx.feixeNucleo.Color = KAME.corNucleo
		fx.feixeMeio.Color = Color3.fromRGB(150, 220, 255)

		-- camadas com textura animada correndo pelo feixe
		fx.feixeIni = nova("FeixeIni")
		fx.feixeFim = nova("FeixeFim")
		fx.beams = {}
		local function criarBeam(k, vel, transp)
			local a0 = Instance.new("Attachment")
			a0.Parent = fx.feixeIni
			local a1 = Instance.new("Attachment")
			a1.Parent = fx.feixeFim
			local b = Instance.new("Beam")
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.Texture = KAME.feixeTex
			b.TextureMode = Enum.TextureMode.Wrap
			b.TextureLength = KAME.feixeTexLen
			b.TextureSpeed = vel
			b.LightEmission = 1
			b.LightInfluence = 0
			b.FaceCamera = true
			b.Segments = 1
			b.Color = ColorSequence.new(KAME.cor, KAME.corNucleo)
			b.Transparency = NumberSequence.new(transp)
			b.Width0 = 0
			b.Width1 = 0
			b.Enabled = false
			b.Parent = fx.feixeIni
			table.insert(fx.beams, { b = b, k = k })
		end
		criarBeam(1.5, KAME.feixeTexVel, 0.25)
		criarBeam(2.2, KAME.feixeTexVel * 0.6, 0.55)

		-- vento cortado pelo feixe: casca de ar + riscos de vento correndo em volta
		fx.ventoCasca = nova("VentoCasca", Enum.PartType.Cylinder)
		fx.ventoCasca.Material = Enum.Material.ForceField
		fx.ventoCasca.Color = Color3.fromRGB(215, 240, 255)
		fx.ventoLigado = false
		fx.vento = {}
		for i = 1, KAME.ventoQtd do
			local vp = nova("Vento")
			vp.Size = Vector3.new(0.2, 0.2, 0.2)
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 0.12, 0)
			a0.Parent = vp
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -0.12, 0)
			a1.Parent = vp
			local tr = Instance.new("Trail")
			tr.Texture = KAME.trailTex
			tr.TextureMode = Enum.TextureMode.Stretch
			tr.Attachment0 = a0
			tr.Attachment1 = a1
			tr.Lifetime = 0.2
			tr.MinLength = 0.02
			tr.FaceCamera = true
			tr.LightEmission = 0.5
			tr.Color = ColorSequence.new(Color3.fromRGB(235, 248, 255), Color3.fromRGB(160, 215, 255))
			tr.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			})
			tr.WidthScale = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0),
			})
			tr.Enabled = false
			tr.Parent = vp
			fx.vento[i] = { p = vp, tr = tr, s = 0, ang = 0, rad = 1, vel = 80, giro = 0 }
		end

		-- impacto do feixe
		fx.imp = nova("Impacto")
		fx.impBola = nova("ImpactoBola")
		fx.impLuz = Instance.new("PointLight")
		fx.impLuz.Color = KAME.cor
		fx.impLuz.Range = 28
		fx.impLuz.Brightness = 0
		fx.impLuz.Shadows = false
		fx.impLuz.Parent = fx.imp
		fx.impPoeiraE = kameEmissor(fx.imp, {
			tex = "rbxasset://textures/particles/smoke_main.dds", luz = 0.5,
			vida = NumberRange.new(0.8, 1.5), vel = NumberRange.new(10, 22), drag = 2,
			spread = Vector2.new(80, 80),
			tam = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) }),
			transp = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
		})

		kameFX = fx
		return fx
	end

	-- ===== camera do disparo: FOV puxa pra direcao do feixe + mini shake =====
	local kameCam = nil
	local KAME_CAM_NOME = "KamehamehaCam"

	local function kameCamParar()
		local st = kameCam
		if not st then return end
		kameCam = nil
		pcall(function() RunService:UnbindFromRenderStep(KAME_CAM_NOME) end)
		local cam = workspace.CurrentCamera
		if cam then cam.FieldOfView = st.baseFov end
	end

	local function kameCamPasso()
		local st = kameCam
		local cam = workspace.CurrentCamera
		if not st or not cam then kameCamParar() return end
		local agora = os.clock()
		local a = (agora - st.t0) / KAME.camDur
		if a >= 1 then kameCamParar() return end

		-- sobe rapido (18% inicial) e volta suave
		local env
		if a < 0.18 then env = a / 0.18 else env = (1 - (a - 0.18) / 0.82) ^ 2 end
		local amp = (1 - a) ^ 2

		cam.FieldOfView = st.baseFov - KAME.fovPuxa * env
		local off = Vector3.new(math.sin(agora * 71), math.sin(agora * 89 + 1.3), math.sin(agora * 53 + 2.1)) * (KAME.shakeForca * amp)
		local rot = Vector3.new(math.sin(agora * 77 + 0.7), math.sin(agora * 61 + 2.4), math.sin(agora * 47)) * (KAME.shakeAng * amp)
		cam.CFrame = CFrame.new(st.dir * (KAME.camPuxa * env)) * cam.CFrame * CFrame.new(off) * CFrame.Angles(rot.X, rot.Y, rot.Z)
	end

	local function kameCamIniciar(dir)
		local cam = workspace.CurrentCamera
		if not cam then return end
		kameCamParar()
		kameCam = { t0 = os.clock(), dir = dir, baseFov = cam.FieldOfView }
		RunService:BindToRenderStep(KAME_CAM_NOME, Enum.RenderPriority.Camera.Value + 2, kameCamPasso)
	end

	local function kameVfxDestruir()
		kameCamParar()
		if kameFX then
			pcall(function() kameFX.pasta:Destroy() end)
			kameFX = nil
		end
	end

	-- centro real da mao (palma + dedos), em vez da ponta do braco: a mao fica alem da ponta
	local function kameMaoPonta(braco)
		local soma, n, vistos = Vector3.new(0, 0, 0), 0, {}
		for _, m in ipairs(partesMao) do
			if m.braco == braco then
				for _, p in ipairs({ m.palma, m.pBase, m.pPonta }) do
					if p and p.Parent and not vistos[p] then
						vistos[p] = true
						soma = soma + p.Position
						n = n + 1
					end
				end
			end
		end
		if n == 0 then
			return (braco.CFrame * CFrame.new(0, -1, 0)).Position
		end
		return soma / n
	end

	local function kameOnda(fx, pos, anel, s0, s1, dur, tr0, normal)
		local p = kameParte(anel and "Anel" or "Onda", anel and Enum.PartType.Cylinder or Enum.PartType.Ball)
		p.Material = Enum.Material.ForceField
		p.Transparency = tr0
		if anel and normal then
			p.CFrame = CFrame.lookAt(pos, pos + normal) * CFrame.Angles(0, math.pi / 2, 0)
		else
			p.CFrame = anel and (CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)) or CFrame.new(pos)
		end
		p.Parent = fx.pasta
		table.insert(fx.ondas, { p = p, t0 = os.clock(), dur = dur, s0 = s0, s1 = s1, tr0 = tr0, anel = anel })
	end

	local function kameVentoSortear(v, s0)
		v.s = s0
		v.ang = math.random() * math.pi * 2
		v.rad = 0.9 + math.random() * 1.0 -- multiplicador da espessura do feixe
		v.vel = 70 + math.random() * 50
		v.giro = (math.random() * 2 - 1) * 2.5
	end

	local function kameVentoAtualizar(fx, origem, dir, len, esp, dt, ligado)
		if not ligado then
			fx.ventoCasca.Transparency = 1
			if fx.ventoLigado then
				fx.ventoLigado = false
				for _, v in ipairs(fx.vento) do v.tr.Enabled = false end
			end
			return
		end

		local base = CFrame.lookAt(origem, origem + dir)
		local dirDe, cimaDe = base.RightVector, base.UpVector

		-- casca de ar translucida em volta do feixe
		local mid = origem + dir * (len / 2)
		local cf = CFrame.lookAt(mid, mid + dir) * CFrame.Angles(0, math.pi / 2, 0)
		fx.ventoCasca.Size = Vector3.new(len, esp * 2.8, esp * 2.8)
		fx.ventoCasca.CFrame = cf
		fx.ventoCasca.Transparency = KAME.ventoCasca

		-- riscos de vento correndo no sentido do feixe
		local primeiro = not fx.ventoLigado
		fx.ventoLigado = true
		for _, v in ipairs(fx.vento) do
			if primeiro then
				kameVentoSortear(v, math.random() * len)
				v.tr.Enabled = true
				v.tr:Clear()
			end
			v.s = v.s + v.vel * dt
			v.ang = v.ang + v.giro * dt
			if v.s > len then
				kameVentoSortear(v, 0)
				v.tr.Enabled = false
				v.tr.Enabled = true
				v.tr:Clear()
			end
			local r = esp * v.rad
			local pos = origem + dir * v.s + (dirDe * math.cos(v.ang) + cimaDe * math.sin(v.ang)) * r
			v.p.CFrame = CFrame.lookAt(pos, pos + dir)
		end
	end

	local function kameVfxAtualizar(fase, t, dt)
		local ativo = (fase == 2 or fase == 3)
		if ativo and not kameFX then kameVfxCriar() end
		local fx = kameFX
		if not fx then return end
		if not fx.pasta.Parent then kameFX = nil return end

		-- fade geral do efeito
		local alvo = ativo and 1 or 0
		local passo = dt / (ativo and KAME.fxEntrada or KAME.fxSaida)
		fx.g = fx.g + clamp(alvo - fx.g, -passo, passo)
		if not ativo and fx.g <= 0.001 then kameVfxDestruir() return end
		local g = fx.g
		local agora = os.clock()

		local dir = rootPart.CFrame.LookVector
		local origem = (kameMaoPonta(rightArm) + kameMaoPonta(leftArm)) / 2 + dir * KAME.bolaFrente

		local prog = 0
		local tr = 0
		if fase == 2 then
			prog = clamp((t - KAME.tFase2) / (KAME.tFase3 - KAME.tFase2), 0, 1)
		elseif fase == 3 then
			prog = 1
			tr = t - KAME.tFase3
		end
		local fimFade = (fase == 3) and clamp((KAME.ciclo - t) / 0.5, 0, 1) or 1

		-- esfera de energia
		local pulso = 1 + 0.07 * math.sin(agora * 32)
		local diam = KAME.bolaMax * (0.15 + 0.85 * prog ^ 1.4)
		if fase == 3 then
			diam = KAME.bolaMax * (1.1 - 0.25 * clamp(tr / 0.5, 0, 1))
		end
		diam = math.max(diam * g * fimFade * pulso, 0.05)
		fx.brilho.Size = Vector3.new(diam, diam, diam)
		fx.brilho.CFrame = CFrame.new(origem)
		fx.brilho.Transparency = 0.45 + (1 - g) * 0.55
		local corBola = KAME.cor:Lerp(KAME.bolaCorFim, prog ^ 1.2)
		fx.brilho.Color = corBola
		fx.luz.Color = corBola
		fx.nucleo.Size = Vector3.new(diam * 0.62, diam * 0.62, diam * 0.62)
		fx.nucleo.CFrame = CFrame.new(origem)
		fx.nucleo.Transparency = (1 - g)
		fx.luz.Brightness = (2 + 4 * prog) * g * fimFade

		-- raios de luz
		local raioAmt = (fase == 2) and prog or (fase == 3 and (1 - clamp(tr / 0.5, 0, 1)) or 0)
		for _, r in ipairs(fx.raios) do
			local d = CFrame.Angles(0, agora * r.vel, 0):VectorToWorldSpace(r.d0)
			local flick = 0.55 + 0.45 * math.abs(math.sin(agora * 14 + r.ph))
			local len = math.max((1.5 + 5.5 * raioAmt) * flick * g, 0.05)
			local pos = origem + d * (diam * 0.4 + len / 2)
			r.p.Size = Vector3.new(r.esp, r.esp, len)
			r.p.CFrame = CFrame.lookAt(pos, pos + d)
			r.p.Transparency = 1 - clamp(raioAmt * 1.6, 0, 0.85) * g
		end

		-- particulas
		fx.conv.CFrame = CFrame.new(origem)
		-- mini trails sendo sugados pra esfera
		local taxaSug = (fase == 2) and (25 + 35 * prog) * g or 0
		fx.sugAcc = fx.sugAcc + taxaSug * dt
		for _, sg in ipairs(fx.sugados) do
			if not sg.vivo and fx.sugAcc >= 1 then
				fx.sugAcc = fx.sugAcc - 1
				sg.vivo = true
				sg.t = 0
				sg.dur = 0.35 + math.random() * 0.25
				sg.d = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1).Unit
				sg.r = KAME.trailRaio * (0.7 + 0.5 * math.random())
				sg.giro = (math.random() * 2 - 1) * 2.5
				sg.p.CFrame = CFrame.new(origem + sg.d * sg.r)
				sg.tr:Clear()
				sg.tr.Enabled = true
			end
			if sg.vivo then
				sg.t = sg.t + dt / sg.dur
				if sg.t >= 1 then
					sg.vivo = false
					sg.tr.Enabled = false
				else
					local e = sg.t ^ 1.6
					local dd = CFrame.Angles(0, sg.giro * sg.t, 0):VectorToWorldSpace(sg.d)
					sg.p.CFrame = CFrame.new(origem + dd * (sg.r * (1 - e)))
				end
			end
		end

		-- disparo
		if fase == 3 and not fx.disparou then
			fx.disparou = true
			if ehLocal then kameCamIniciar(dir) end -- camera so mexe pro jogador
			local plano = Vector3.new(dir.X, 0, dir.Z)
			if plano.Magnitude > 0.01 then
				fx.recuoDir = -plano.Unit
				fx.recuoT0 = agora
			end
		elseif fase ~= 3 then
			fx.disparou = false
		end

		-- recuo: desliza pra tras ao soltar o feixe
		if fx.recuoT0 then
			local a = (agora - fx.recuoT0) / KAME.recuoDur
			if a >= 1 then
				fx.recuoT0 = nil
			else
				local v = KAME.recuoVel * (1 - a) ^ 2
				local vy = rootPart.AssemblyLinearVelocity.Y
				rootPart.AssemblyLinearVelocity = Vector3.new(fx.recuoDir.X * v, vy, fx.recuoDir.Z * v)
			end
		end

		-- ondas de choque
		for i = #fx.ondas, 1, -1 do
			local o = fx.ondas[i]
			local a = (agora - o.t0) / o.dur
			if a >= 1 then
				o.p:Destroy()
				table.remove(fx.ondas, i)
			else
				local e = 1 - (1 - a) ^ 3
				local s = o.s0 + (o.s1 - o.s0) * e
				o.p.Size = o.anel and Vector3.new(0.4, s, s) or Vector3.new(s, s, s)
				o.p.Transparency = o.tr0 + (1 - o.tr0) * a
			end
		end

		-- feixe
		local visivel = false
		local ventoLen, ventoEsp = 0, 0
		if fase == 3 then
			if ctx.filtro then kameRay.FilterDescendantsInstances = ctx.filtro() end
			local res = workspace:Raycast(origem, dir * KAME.alcance, kameRay)
			local alc = res and (res.Position - origem).Magnitude or KAME.alcance
			local cresce = 1 - (1 - clamp(tr / 0.3, 0, 1)) ^ 3
			local len = math.max(alc * cresce, 0.1)
			local esp = KAME.raio * (1 + 0.08 * math.sin(agora * 45)) * fimFade * clamp(tr / 0.12, 0, 1)
			if esp > 0.05 then
				visivel = true
				ventoLen, ventoEsp = len, esp
				local mid = origem + dir * (len / 2)
				local cf = CFrame.lookAt(mid, mid + dir) * CFrame.Angles(0, math.pi / 2, 0)
				fx.feixeNucleo.Size = Vector3.new(len, esp * 0.55, esp * 0.55)
				fx.feixeMeio.Size = Vector3.new(len, esp * 0.9, esp * 0.9)
				fx.feixeFora.Size = Vector3.new(len, esp * 1.6, esp * 1.6)
				fx.feixeNucleo.CFrame = cf
				fx.feixeMeio.CFrame = cf
				fx.feixeFora.CFrame = cf
				fx.feixeNucleo.Transparency = 0
				fx.feixeMeio.Transparency = 0.2
				fx.feixeFora.Transparency = 0.6

				-- textura animada
				fx.feixeIni.CFrame = CFrame.new(origem)
				fx.feixeFim.CFrame = CFrame.new(origem + dir * len)
				for _, bm in ipairs(fx.beams) do
					bm.b.Enabled = true
					bm.b.Width0 = esp * bm.k
					bm.b.Width1 = esp * bm.k
				end

				-- fling: blocos, itens e pecas soltas (nao ancoradas) que encostam no feixe sao arremessados
				local op = fx.flingParams
				if not op then
					op = OverlapParams.new()
					op.FilterType = Enum.RaycastFilterType.Exclude
					op.FilterDescendantsInstances = ctx.filtro and ctx.filtro() or { character, folder }
					fx.flingParams = op
					fx.flingTempo = setmetatable({}, { __mode = "k" })
				end
				local caixa = CFrame.lookAt(mid, mid + dir)
				local partes = workspace:GetPartBoundsInBox(caixa, Vector3.new(esp * 1.6, esp * 1.6, len), op)
				local feitos = {}
				for _, part in ipairs(partes) do
					-- ignora personagens / humanoides (jogadores e NPCs): so blocos, itens e pecas soltas
					local modelo = part:FindFirstAncestorOfClass("Model")
					if modelo and modelo:FindFirstChildOfClass("Humanoid") then continue end
					local raiz = part.AssemblyRootPart or part
					if feitos[raiz] or raiz.Anchored then continue end
					local dono = raiz:FindFirstAncestorOfClass("Model")
					if dono and dono:FindFirstChildOfClass("Humanoid") then continue end
					feitos[raiz] = true

					local ultimo = fx.flingTempo[raiz]
					local novo = (not ultimo) or (agora - ultimo > 0.4)
					fx.flingTempo[raiz] = agora

					pcall(function()
						raiz.AssemblyLinearVelocity = dir * KAME.flingForca + Vector3.new(0, KAME.flingCima, 0)
						if novo then
							-- impulso extra proporcional a massa: tira ate peca pesada do chao (atrito)
							raiz:ApplyImpulse(Vector3.new(0, raiz.AssemblyMass * KAME.flingCima, 0))
							raiz.AssemblyAngularVelocity = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1) * KAME.flingGiro
						end
					end)
				end
			end

			-- impacto
			if res and visivel and cresce >= 0.98 then
				local ip = res.Position + res.Normal * 0.6
				local ib = esp * 2.4 * (1 + 0.1 * math.sin(agora * 38))
				fx.imp.CFrame = CFrame.lookAt(ip, ip + res.Normal)
				fx.impBola.Size = Vector3.new(ib, ib, ib)
				fx.impBola.CFrame = CFrame.new(ip)
				fx.impBola.Transparency = 0.35
				fx.impLuz.Brightness = 5 * fimFade
				fx.impPoeiraE.Rate = 18 * fimFade

				-- repelicao: aneis de choque saindo do ponto atingido, na direcao da superficie
				if agora - (fx.repelT or 0) > 0.16 then
					fx.repelT = agora
					kameOnda(fx, res.Position + res.Normal * 0.2, true, 2, 16, 0.5, 0.3, res.Normal)

					-- repele blocos, itens e pecas soltas ao redor do ponto atingido
					local repelidos = {}
					local ao_redor = workspace:GetPartBoundsInRadius(res.Position, KAME.repelRaio, fx.flingParams)
					for _, part in ipairs(ao_redor) do
						local modelo = part:FindFirstAncestorOfClass("Model")
						if modelo and modelo:FindFirstChildOfClass("Humanoid") then continue end
						local raiz = part.AssemblyRootPart or part
						if repelidos[raiz] or raiz.Anchored then continue end
						local dono = raiz:FindFirstAncestorOfClass("Model")
						if dono and dono:FindFirstChildOfClass("Humanoid") then continue end
						repelidos[raiz] = true

						local fora = raiz.Position - res.Position
						if fora.Magnitude < 0.1 then fora = res.Normal end
						local d = (fora.Unit + res.Normal * 0.6).Unit
						pcall(function()
							raiz.AssemblyLinearVelocity = d * KAME.repelForca
							raiz:ApplyImpulse(Vector3.new(0, raiz.AssemblyMass * 20, 0))
							raiz.AssemblyAngularVelocity = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1) * KAME.repelGiro
						end)
					end
				end
			else
				fx.impBola.Transparency = 1
				fx.impLuz.Brightness = 0
				fx.impPoeiraE.Rate = 0
			end
		end
		if not visivel then
			for _, bm in ipairs(fx.beams) do bm.b.Enabled = false end
			fx.feixeNucleo.Transparency = 1
			fx.feixeMeio.Transparency = 1
			fx.feixeFora.Transparency = 1
			fx.impBola.Transparency = 1
			fx.impLuz.Brightness = 0
			fx.impPoeiraE.Rate = 0
		end
		kameVentoAtualizar(fx, origem, dir, ventoLen, ventoEsp, dt, visivel)
	end

	return {
		somParar = kameSomParar, somTocar = kameSomTocar, somAtualizar = kameSomAtualizar,
		fala = kameFala, vfxAtualizar = kameVfxAtualizar, vfxDestruir = kameVfxDestruir,
		destruir = function()
			kameSomParar(true)
			kameFala.destruir()
			kameVfxDestruir()
		end,
	}
end

do
	local antigo = _G.__ClonesHands
	if antigo and antigo.destruir then pcall(antigo.destruir) end
end

_G.__ClonesHands = (function()
	local PathfindingService = game:GetService("PathfindingService")
	local api = {}
	local clones = {}
	local proxId = 0
	local conexoes = {}

	local MAX_CLONES = 8
	local DIST_SEGUIR = 7
	local DIST_PARAR = 7.3
	local DIST_ANDAR = 8.6
	local DIST_TELEPORTE = 110
	local EMOTES_OCULTOS = { Ragdoll = true, Apontar = true, Pegar = true }

	local NOMES_CLONE = { "HumanoidRootPart", "Torso", "Head", "Left Leg", "Right Leg" }
	local NOMES_MEUS = { "HumanoidRootPart", "Torso", "Head", "Left Leg", "Right Leg", "Left Arm", "Right Arm" }

	local pasta = Instance.new("Folder")
	pasta.Name = "DynamicClonesFolder"
	pasta.Parent = workspace

	local function avisar()
		if api.onChange then pcall(api.onChange) end
	end

	local function clonarInst(inst)
		local arq = inst.Archivable
		inst.Archivable = true
		local ok, c = pcall(function() return inst:Clone() end)
		inst.Archivable = arq
		if ok then return c end
		return nil
	end

	local function limparModelo(model)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BaseScript") or d:IsA("Tool") or d:IsA("ForceField") or d:IsA("Sound")
				or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("BillboardGui") then
				d:Destroy()
			elseif d:IsA("Weld") and (d.Name == "RightGrip" or d.Name == "LeftGrip") then
				d:Destroy()
			end
		end
	end

	local function modeloDeUsuario(nome)
		local ok, userId = pcall(function()
			return tonumber(nome) or Players:GetUserIdFromNameAsync(nome)
		end)
		if not (ok and userId) then return nil end
		if userId == 7547934481 then return nil end
		local ok2, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(userId) end)
		if not (ok2 and desc) then return nil end
		local ok3, m = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6) end)
		if ok3 and m then return m end
		return nil
	end

	local function semColisao(c)
		if c.ncc then
			for _, x in ipairs(c.ncc) do x:Destroy() end
		end
		c.ncc = {}
		local meu = LocalPlayer.Character
		if not meu then return end
		for _, a in ipairs(NOMES_CLONE) do
			local pa = c.model:FindFirstChild(a)
			if pa and pa:IsA("BasePart") then
				for _, b in ipairs(NOMES_MEUS) do
					local pb = meu:FindFirstChild(b)
					if pb and pb:IsA("BasePart") then
						local n = Instance.new("NoCollisionConstraint")
						n.Part0, n.Part1 = pa, pb
						n.Parent = c.model
						table.insert(c.ncc, n)
					end
				end
			end
		end
	end

	local function montarMao(model, membro, ehDireito, lista)
		local function criarPeca(tamanho, isPalma)
			local p = pecaDoMembro(membro, tamanho, isPalma)
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.Parent = model
			return p
		end
		local function criarWeld(part0, peca, c0)
			local w = Instance.new("Weld")
			w.Part0 = part0
			w.Part1 = peca
			w.C0 = c0 or CFrame.new()
			w.Parent = peca
			return w
		end

		local palma = criarPeca(PALMA_SIZE, true)
		local palmaWeld = criarWeld(membro, palma, CFrame.new(0, -1.0, 0))

		for id = 1, 5 do
			local cfg = CONFIG_DEDOS[id]
			local dedoBase = criarPeca(cfg.tampBase, false)
			local dedoPonta = criarPeca(cfg.tampPonta, false)
			local baseWeld = criarWeld(palma, dedoBase)
			local pontaWeld = criarWeld(palma, dedoPonta)

			local juntaWeld = nil
			if JUNTA_ATIVA then
				juntaWeld = {}
				for i, cunha in ipairs(juntaDoMembro(membro)) do
					cunha.Anchored = false
					cunha.CanCollide = false
					cunha.CanQuery = false
					cunha.CanTouch = false
					cunha.Massless = true
					cunha.Parent = model
					juntaWeld[i] = criarWeld(palma, cunha)
				end
			end

			table.insert(lista, {
				palmaWeld = palmaWeld, baseWeld = baseWeld, pontaWeld = pontaWeld, juntaWeld = juntaWeld,
				id = id, ehDireito = ehDireito, ab = 0, ap = 0,
				braco = membro, palma = palma, pBase = dedoBase, pPonta = dedoPonta,
			})
		end
	end

	function api.criar(nomeSkin)
		if #clones >= MAX_CLONES then return false, "Limite de " .. MAX_CLONES .. " clones" end
		nomeSkin = (nomeSkin or ""):match("^%s*(.-)%s*$")

		local PROIBIDOS = { baiquinha90 = true }
		local PROIBIDOS_ID = { [7547934481] = true }
		if PROIBIDOS[string.lower(nomeSkin)] or PROIBIDOS_ID[tonumber(nomeSkin)] then
			return false, "Esse usuário não existe"
		end

		local model, skinUsada, aviso = nil, "minha skin", nil
		if nomeSkin ~= "" then
			model = modeloDeUsuario(nomeSkin)
			if model then
				skinUsada = nomeSkin
			else
				aviso = "Usuário não encontrado: usei a sua skin"
			end
		end

		local meu = LocalPlayer.Character
		local meuRoot = meu and meu:FindFirstChild("HumanoidRootPart")
		if not meuRoot then
			if model then model:Destroy() end
			return false, "Seu personagem não está pronto"
		end
		if not model then model = clonarInst(meu) end
		if not model then return false, "Não consegui copiar seu personagem" end

		local hum = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		local torso = model:FindFirstChild("Torso")
		local bracoD, bracoE = model:FindFirstChild("Right Arm"), model:FindFirstChild("Left Arm")
		if not (hum and root and torso and bracoD and bracoE) then
			model:Destroy()
			return false, "Modelo R6 inválido"
		end

		limparModelo(model)
		for _, n in ipairs({ "BowVelocityLock", "BowGyroLock" }) do
			local x = root:FindFirstChild(n)
			if x then x:Destroy() end
		end
		local orig = model:GetAttribute("OriginalHipHeight")
		if orig then hum.HipHeight = orig end
		model:SetAttribute("OriginalHipHeight", hum.HipHeight)
		hum.PlatformStand = false
		hum.AutoRotate = true
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false
		hum.MaxHealth = 1e9
		hum.Health = 1e9
		hum.WalkSpeed = 16
		hum.UseJumpPower = true
		hum.JumpPower = 50

		proxId += 1
		model.Name = "Clone" .. proxId
		model.PrimaryPart = root
		model:PivotTo(meuRoot.CFrame * CFrame.new(0, 0, DIST_SEGUIR))

		local dedos = {}
		montarMao(model, bracoD, true, dedos)
		montarMao(model, bracoE, false, dedos)
		model.Parent = pasta

		local c = {
			id = proxId, nome = "Clone " .. proxId, skin = skinUsada,
			model = model, hum = hum, root = root, torso = torso, dedos = dedos,
			bracoD = bracoD, bracoE = bracoE,
			emote = nil, seguir = false, movendo = false,
			fase = 0, amp = 0, corpoAplicado = false, travado = false,
			cur = { R = CFrame.new(), L = CFrame.new(), N = CFrame.new(), B = CFrame.new(), PR = CFrame.new(), PL = CFrame.new() },
			joints = {
				rs = torso:FindFirstChild("Right Shoulder"), ls = torso:FindFirstChild("Left Shoulder"),
				neck = torso:FindFirstChild("Neck"), rh = torso:FindFirstChild("Right Hip"),
				lh = torso:FindFirstChild("Left Hip"), root = root:FindFirstChild("RootJoint"),
			},
			ultimaPos = root.Position, tStuck = 0, stuck = 0,
			waypoints = nil, wpIdx = 1, pathGoal = nil, proxPath = 0, pathBusy = false, forcaPath = false,
			tLos = 0, bloqueado = false,
		}
		table.insert(clones, c)
		semColisao(c)
		avisar()
		return true, aviso
	end

	local function limparKame(c)
		if c.kame then
			pcall(c.kame.destruir)
			c.kame = nil
		end
		if c.kameFolder then
			pcall(function() c.kameFolder:Destroy() end)
			c.kameFolder = nil
		end
	end

	function api.remover(id)
		for i, c in ipairs(clones) do
			if c.id == id then
				limparKame(c)
				if c.model then c.model:Destroy() end
				table.remove(clones, i)
				break
			end
		end
		avisar()
	end

	function api.removerTodos()
		for _, c in ipairs(clones) do
			limparKame(c)
			if c.model then c.model:Destroy() end
		end
		table.clear(clones)
		avisar()
	end

	local function achar(id)
		for _, c in ipairs(clones) do
			if c.id == id then return c end
		end
		return nil
	end

	function api.setEmote(id, nome)
		local c = achar(id)
		if not c then return end
		if nome == nil or nome == "" then c.emote = nil else c.emote = nome end
		avisar()
	end

	function api.setSeguir(id, ligado)
		local c = achar(id)
		if not c then return end
		c.seguir = ligado == true
		if not c.seguir then
			c.waypoints = nil
			c.movendo = false
			if c.root.Parent then c.hum:MoveTo(c.root.Position) end
		end
		avisar()
	end

	function api.lista() return clones end

	function api.emotesDisponiveis()
		local r = {}
		local liberado = liberado18()
		for _, e in ipairs(EMOTES) do
			if not EMOTES_OCULTOS[e.nome] and (e.cat ~= "+18" or liberado) then
				table.insert(r, e)
			end
		end
		return r
	end

	function api.max() return MAX_CLONES end

	local function pedirCaminho(c, goal)
		if c.pathBusy then return end
		c.pathBusy = true
		c.proxPath = os.clock() + 0.8
		task.spawn(function()
			local ok, path = pcall(function()
				local p = PathfindingService:CreatePath({
					AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4,
				})
				p:ComputeAsync(c.root.Position, goal)
				return p
			end)
			c.pathBusy = false
			if ok and path and path.Status == Enum.PathStatus.Success then
				c.waypoints = path:GetWaypoints()
				c.wpIdx = 2
				c.pathGoal = goal
			else
				c.waypoints = nil
			end
		end)
	end

	-- Kamehameha do clone: mesmas fases do jogador (KF1-3 anda, KF4-9 parado + recarga, KF10-11 parado + disparo),
	-- mas com o relogio proprio de cada clone. Repete a cada KAME.ciclo ate o emote ser trocado.
	local function kameClone(c, dt)
		local emote = c.emote
		local agora = os.clock()
		local fase, t = nil, 0

		if emote == "Kamehameha" then
			if not c.kame then
				local pf = Instance.new("Folder")
				pf.Name = "KameFX" .. c.id
				pf.Parent = pasta
				c.kameFolder = pf
				c.kame = KAME.criar({
					character = c.model, rootPart = c.root, rightArm = c.bracoD, leftArm = c.bracoE,
					folder = pf, partesMao = c.dedos, ehLocal = false,
					filtro = function() return { c.model, pf, pasta, LocalPlayer.Character } end,
				})
			end
			if c.kameUltimoEmote ~= "Kamehameha" then
				c.kameInicio = agora
				c.kameFase = nil
			end
			t = (agora - c.kameInicio) % KAME.ciclo
			fase = (t < KAME.tFase2) and 1 or ((t < KAME.tFase3) and 2 or 3)
			if fase ~= c.kameFase then
				c.kameFase = fase
				c.kame.fala.entrar(fase, t)
				if fase == 2 then
					c.kame.somTocar(KAME.somRecarga, agora + (KAME.tFase3 - t))
				elseif fase == 3 then
					c.kame.somTocar(KAME.somDisparo, agora + (KAME.ciclo - t))
				else
					c.kame.somParar()
				end
			end
			c.kameFrame = KAME.amostrar(defaultEmotes["Kamehameha"], t)
		else
			if c.kameFase ~= nil and c.kame then
				c.kame.somParar()
				c.kame.fala.parar()
			end
			c.kameFase = nil
			c.kameFrame = nil
		end
		c.kameUltimoEmote = emote

		if c.kame then
			c.kame.somAtualizar()
			c.kame.vfxAtualizar(fase, t, dt) -- fase nil = fade out do VFX
		end
	end

	local function ia(c, dt, agora)
		local hum, root = c.hum, c.root
		local meu = LocalPlayer.Character
		local meuRoot = meu and meu:FindFirstChild("HumanoidRootPart")
		local meuHum = meu and meu:FindFirstChildOfClass("Humanoid")
		local emote = c.emote
		local parado = emote ~= nil and (EMOTES_IMOVEIS[emote] == true or EMOTES_CORPO[emote] == true)
		if emote == "Kamehameha" then parado = (c.kameFase or 1) ~= 1 end -- fase 1 (KF1-3) ainda anda

		if parado then
			if not c.travado then
				c.travado = true
				hum.JumpPower = 0
				hum.JumpHeight = 0
			end
			hum.WalkSpeed = 0
			hum.AutoRotate = false
			if c.movendo then
				hum:MoveTo(root.Position)
				c.movendo = false
				c.waypoints = nil
			end
			return
		elseif c.travado then
			c.travado = false
			hum.WalkSpeed = 16
			hum.JumpPower = 50
			hum.JumpHeight = 7.2
			hum.AutoRotate = true
		end

		if not c.seguir or not meuRoot then return end

		local delta = meuRoot.Position - root.Position
		local plano = Vector3.new(delta.X, 0, delta.Z)
		local dist = plano.Magnitude

		if dist > DIST_TELEPORTE or root.Position.Y < workspace.FallenPartsDestroyHeight + 40 then
			c.model:PivotTo(meuRoot.CFrame * CFrame.new(0, 0, DIST_SEGUIR))
			c.waypoints = nil
			c.movendo = false
			return
		end

		if c.movendo then
			if dist <= DIST_PARAR then
				c.movendo = false
				c.waypoints = nil
				hum:MoveTo(root.Position)
				return
			end
		else
			if dist > DIST_ANDAR then
				c.movendo = true
			else
				return
			end
		end

		local dirParaMim = plano.Magnitude > 0.01 and plano.Unit or Vector3.zAxis
		local goal = meuRoot.Position - dirParaMim * DIST_SEGUIR

		local vMeu = meuHum and meuHum.WalkSpeed or 16
		hum.WalkSpeed = clamp(vMeu + math.max(0, dist - 10) * 0.6, 8, 45)

		if agora - c.tLos > 0.25 then
			c.tLos = agora
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Exclude
			rp.FilterDescendantsInstances = { c.model, meu, pasta }
			local origem = root.Position + Vector3.new(0, 0.5, 0)
			local alvoRay = Vector3.new(goal.X, origem.Y, goal.Z)
			c.bloqueado = workspace:Raycast(origem, alvoRay - origem, rp) ~= nil
		end

		if c.waypoints and c.pathGoal and (goal - c.pathGoal).Magnitude > 12 then
			c.waypoints = nil
		end
		if (c.bloqueado or c.forcaPath) and not c.waypoints and agora >= c.proxPath then
			c.forcaPath = false
			pedirCaminho(c, goal)
		end
		if not c.bloqueado and not c.forcaPath then
			c.waypoints = nil
		end

		local alvoMover = goal
		if c.waypoints then
			local wp = c.waypoints[c.wpIdx]
			if wp then
				local d = Vector3.new(wp.Position.X - root.Position.X, 0, wp.Position.Z - root.Position.Z).Magnitude
				if d < 3.2 then
					c.wpIdx += 1
					wp = c.waypoints[c.wpIdx]
				end
			end
			if wp then
				alvoMover = wp.Position
				if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
			else
				c.waypoints = nil
			end
		end
		hum:MoveTo(alvoMover)

		if agora - c.tStuck > 0.6 then
			local d = (root.Position - c.ultimaPos).Magnitude
			if c.movendo and d < 0.5 then
				hum.Jump = true
				c.stuck += 1
				if c.stuck >= 2 then
					c.waypoints = nil
					c.proxPath = 0
					c.forcaPath = true
				end
			else
				c.stuck = 0
			end
			c.ultimaPos = root.Position
			c.tStuck = agora
		end
	end

	local function animar(c, dt, t)
		local hum, root = c.hum, c.root
		local emote = c.emote

		local corpo = emote ~= nil and EMOTES_CORPO[emote] == true
		if corpo then
			aplicarCorpoBow(c.model, hum, root, true, emote)
			c.corpoAplicado = true
		elseif c.corpoAplicado then
			limparAgachamentoBow(c.model)
			c.corpoAplicado = false
		end

		local v = root.AssemblyLinearVelocity
		local vel = Vector3.new(v.X, 0, v.Z).Magnitude
		local noAr = hum.FloorMaterial == Enum.Material.Air
		c.amp = c.amp + (clamp(vel / 6, 0, 1) - c.amp) * clamp(dt * 10, 0, 1)
		c.fase = c.fase + dt * clamp(vel, 0, 40) * 0.55
		local s = sin(c.fase) * c.amp

		local kf = (emote == "Kamehameha") and c.kameFrame or nil -- pose pelo relogio do proprio clone
		local P = emote and calcularPoseEmote(emote, t, false, kf) or poseVazia()
		local ident = CFrame.new()

		local andarBraco = CFrame.Angles(0, 0, -rad(40) * s)
		local andarPerna = CFrame.Angles(0, 0, rad(50) * s)

		local k = clamp(dt * 14, 0, 1)
		local cur = c.cur
		cur.R = cur.R:Lerp(P.wR > 0.01 and P.R or andarBraco, k)
		cur.L = cur.L:Lerp(P.wL > 0.01 and P.L or andarBraco, k)
		cur.N = cur.N:Lerp(P.wN > 0.01 and P.N or ident, k)
		cur.B = cur.B:Lerp(P.wB > 0.01 and P.B or ident, k)
		cur.PR = cur.PR:Lerp(P.wP > 0.01 and P.PR or andarPerna, k)
		cur.PL = cur.PL:Lerp(P.wP > 0.01 and P.PL or andarPerna, k)

		local j = c.joints
		if j.rs then j.rs.Transform = cur.R end
		if j.ls then j.ls.Transform = cur.L end
		if j.neck then j.neck.Transform = cur.N end
		if j.root then j.root.Transform = cur.B end
		if j.rh then j.rh.Transform = cur.PR end
		if j.lh then j.lh.Transform = cur.PL end

		local kd = clamp(dt * 15, 0, 1)
		local defE = kf or (emote and defaultEmotes[emote])
		for _, art in ipairs(c.dedos) do
			local alvoB, alvoP, ext = 0, 0, nil
			local pp = defE and (art.ehDireito and defE.palmaDir or defE.palmaEsq)
			if pp then
				art.palmaWeld.C0 = CFrame.new(0, -1.0, 0) * CFrame.Angles(rad(pp.x), rad(pp.y), rad(pp.z))
			else
				art.palmaWeld.C0 = CFrame.new(0, -1.0, 0)
			end

			if emote then
				local b, p = alvoDedosEmote(emote, art.id, art.ehDireito, kf)
				alvoB, alvoP = b or 0, p or 0
				ext = extraDedoEmote(emote, art.id, art.ehDireito, kf)
			elseif noAr then
				alvoB, alvoP = -15, -10
			elseif vel > 18 then
				alvoB = 45 + sin(t * 15) * 5
				alvoP = 50 + cos(t * 15) * 5
			elseif vel > 0.5 then
				local curva = (art.id == 1) and 5 or (art.id * 4)
				local atraso = art.id * 0.25
				alvoB = curva + sin(t * 10 - atraso) * 12
				alvoP = (curva * 0.8) + cos(t * 10 - atraso) * 10
			else
				local curva = (art.id == 1) and 3 or (art.id * 3)
				local atraso = art.id * 0.3
				alvoB = curva + sin(t * 2 - atraso) * 3
				alvoP = (curva * 0.8) + cos(t * 2 - atraso) * 2
			end

			art.ab = art.ab + (alvoB - art.ab) * kd
			art.ap = art.ap + (alvoP - art.ap) * kd

			local baseCF, pontaCF, pivotCF = calcFingerCFrames(art.id, art.ehDireito, art.ab, art.ap, 0, ext)
			art.baseWeld.C0 = baseCF
			art.pontaWeld.C0 = pontaCF
			if art.juntaWeld then
				local cf1, s1, cf2, s2 = calcJuntaCFrames(art.id, art.ehDireito, art.ap, pivotCF)
				art.juntaWeld[1].Part1.Size, art.juntaWeld[1].C0 = s1, cf1
				art.juntaWeld[2].Part1.Size, art.juntaWeld[2].C0 = s2, cf2
			end
		end
	end

	conexoes[#conexoes + 1] = RunService.RenderStepped:Connect(function(dt)
		local t = tick()
		local agora = os.clock()
		for i = #clones, 1, -1 do
			local c = clones[i]
			if not (c.model and c.model.Parent and c.root.Parent) then
				limparKame(c)
				table.remove(clones, i)
				avisar()
			else
				local ok, err = pcall(kameClone, c, dt)
				if not ok then warn("[Clone] Kamehameha:", err) end
				ok, err = pcall(ia, c, dt, agora)
				if not ok then warn("[Clone] IA:", err) end
				ok, err = pcall(animar, c, dt, t)
				if not ok then warn("[Clone] animação:", err) end
			end
		end
	end)

	conexoes[#conexoes + 1] = LocalPlayer.CharacterAdded:Connect(function()
		task.wait(1.2)
		for _, c in ipairs(clones) do
			if c.model.Parent then semColisao(c) end
		end
	end)

	function api.destruir()
		for _, cn in ipairs(conexoes) do cn:Disconnect() end
		table.clear(conexoes)
		for _, c in ipairs(clones) do limparKame(c) end
		table.clear(clones)
		if pasta then pasta:Destroy() end
	end

	return api
end)()

local function limparMaos()
	Pegar.soltar()
	ItensEmote.real.limpar()
	if loopConnectionRender then loopConnectionRender:Disconnect(); loopConnectionRender = nil end
	if loopConnectionStepped then loopConnectionStepped:Disconnect(); loopConnectionStepped = nil end
	local antigo = workspace:FindFirstChild("DynamicFingersFolder")
	if antigo then antigo:Destroy() end
end

local function calcularEspessuraCabo(tool)
	local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildOfClass("MeshPart") or tool:FindFirstChildOfClass("Part")
	if handle then
		return 90 - clamp(math.min(handle.Size.X, handle.Size.Z) * 35, 10, 60)
	end
	return 75
end

local function tweenValue(current, target, factor)
	return current + (target - current) * factor
end

local function criarMaoDinamica(character)
	do
		local ponte = _G.__DedosRagdoll
		if ponte and ponte.desligar then pcall(ponte.desligar) end
	end
	limparMaos()

	local rightArm = character:WaitForChild("Right Arm", 2)
	local leftArm = character:WaitForChild("Left Arm", 2)
	local torso = character:WaitForChild("Torso", 2)
	local humanoid = character:WaitForChild("Humanoid", 2)
	local rootPart = character:WaitForChild("HumanoidRootPart", 2)

	if not rightArm or not leftArm or not humanoid or not rootPart or not torso then return end

	local folder = Instance.new("Folder")
	folder.Name = "DynamicFingersFolder"
	folder.Parent = workspace

	local partesMao = {}

	local function criarPeca(tamanho, membro, isPalma)
		local p = pecaDoMembro(membro, tamanho, isPalma)
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.Parent = folder
		return p
	end

	local function criarWeld(part0, peca, c0)
		local w = Instance.new("Weld")
		w.Part0 = part0
		w.Part1 = peca
		w.C0 = c0 or CFrame.new()
		w.Parent = peca
		return w
	end

	local function montarMaoBruta(membro, ehDireito)
		local palma = criarPeca(PALMA_SIZE, membro, true)
		local palmaWeld = criarWeld(membro, palma, CFrame.new(0, -1.0, 0))

		for id = 1, 5 do
			local c = CONFIG_DEDOS[id]
			local dedoBase = criarPeca(c.tampBase, membro, false)
			local dedoPonta = criarPeca(c.tampPonta, membro, false)

			local baseWeld = criarWeld(palma, dedoBase)
			local pontaWeld = criarWeld(palma, dedoPonta)

			local junta, juntaWeld = nil, nil
			if JUNTA_ATIVA then
				junta = juntaDoMembro(membro)
				juntaWeld = {}
				for i, cunha in ipairs(junta) do
					cunha.Anchored = false
					cunha.CanCollide = false
					cunha.CanQuery = false
					cunha.CanTouch = false
					cunha.Massless = true
					cunha.Parent = folder
					juntaWeld[i] = criarWeld(palma, cunha)
				end
			end

			local trail = nil
			if ehDireito and id == 2 then
				local a0 = Instance.new("Attachment", dedoPonta)
				a0.Position = Vector3.new(0, c.tampPonta.Y / 2, 0)
				local a1 = Instance.new("Attachment", dedoPonta)
				a1.Position = Vector3.new(0, -c.tampPonta.Y / 2, 0)

				trail = Instance.new("Trail", dedoPonta)
				trail.Attachment0 = a0
				trail.Attachment1 = a1
				trail.Color = ColorSequence.new(Color3.fromRGB(150, 150, 150))
				trail.Transparency = NumberSequence.new(0.5, 1)
				trail.Lifetime = 0.25
				trail.Enabled = false
			end

			table.insert(partesMao, {
				pBase = dedoBase, pPonta = dedoPonta,
				baseWeld = baseWeld, pontaWeld = pontaWeld, juntaWeld = juntaWeld,
				palmaWeld = palmaWeld, palma = palma,
				trail = trail, braco = membro,
				angBase = 0, angPonta = 0,
				id = id, ehDireito = ehDireito,
				origTamanhoPonta = c.tampPonta,
			})
		end
	end

	montarMaoBruta(rightArm, true)
	montarMaoBruta(leftArm, false)

	local DEDOS_RAGDOLL = {
		ativo = true,
		colidirPonta = true,
		densidade = 3,
		amortecimento = 6,
		limBase = { -25, 100 },
		limPonta = { -10, 115 },
	}

	local dedosRagdollAtivo = false
	local ragdollDedosConn = nil
	local ragdollDedosCriados = {}

	local function limitesDobradica(cur, amin, amax, dir)
		local a, b = amin * dir, amax * dir

		local lo = math.min(a, b, cur)
		local hi = math.max(a, b, cur)
		return clamp(lo, -180, 180), clamp(hi, -180, 180)
	end

	local function ragdollDedosDesligar()
		if not dedosRagdollAtivo then return end
		dedosRagdollAtivo = false
		if ragdollDedosConn then ragdollDedosConn:Disconnect(); ragdollDedosConn = nil end

		for _, inst in ipairs(ragdollDedosCriados) do
			if inst and inst.Parent then inst:Destroy() end
		end
		table.clear(ragdollDedosCriados)

		for _, art in ipairs(partesMao) do
			if art.baseWeld and art.baseWeld.Parent then art.baseWeld.Enabled = true end
			if art.pontaWeld and art.pontaWeld.Parent then art.pontaWeld.Enabled = true end
			if art.juntaWeld then
				for _, w in ipairs(art.juntaWeld) do
					if w.Parent and art.palma and art.palma.Parent then w.Part0 = art.palma end
				end
			end
			for _, p in ipairs({ art.pBase, art.pPonta }) do
				if p and p.Parent then
					p.CanCollide = false
					p.Massless = true
					p.CustomPhysicalProperties = nil
				end
			end
			if art.pPonta and art.pPonta.Parent then art.pPonta.Size = art.origTamanhoPonta end
		end
	end

	local function ragdollDedosLigar()
		if dedosRagdollAtivo or not DEDOS_RAGDOLL.ativo then return end
		dedosRagdollAtivo = true

		local HO = CFrame.fromMatrix(Vector3.zero, Vector3.zAxis, Vector3.yAxis)

		local function novoAttachment(parte, cf)
			local a = Instance.new("Attachment")
			a.Name = "RagDedoAtt"
			a.CFrame = cf
			a.Parent = parte
			table.insert(ragdollDedosCriados, a)
			return a
		end

		local function novaDobradica(a0, a1, lo, hi, pai)
			local h = Instance.new("HingeConstraint")
			h.Name = "RagDedoHinge"
			h.Attachment0 = a0
			h.Attachment1 = a1
			h.LimitsEnabled = true
			h.LowerAngle = lo
			h.UpperAngle = hi
			h.Restitution = 0
			h.Parent = pai
			table.insert(ragdollDedosCriados, h)
			return h
		end

		for _, art in ipairs(partesMao) do
			if not (art.braco and art.braco.Parent and art.palma and art.palma.Parent) then continue end

			local l = (art.ehDireito and CONFIG_POS.Direita or CONFIG_POS.Esquerda)[art.id]
			local c = CONFIG_DEDOS[art.id]
			local dir = l.dir
			local hb, hp = c.tampBase.Y, c.tampPonta.Y
			local pBase, pPonta, palma = art.pBase, art.pPonta, art.palma
			art.ragDir, art.ragHb = dir, hb

			pPonta.Size = art.origTamanhoPonta

			local curBase = art.angBase * dir
			local curPonta = art.angPonta * dir

			local K = art.baseWeld.C0 * CFrame.new(0, hb / 2, 0)
			local Ks = K * CFrame.Angles(0, 0, -rad(curBase))

			art.baseWeld.Enabled = false
			art.pontaWeld.Enabled = false
			pPonta.CFrame = pBase.CFrame
				* CFrame.new(0, -hb / 2, 0)
				* CFrame.Angles(0, 0, rad(curPonta))
				* CFrame.new(0, -hp / 2, 0)

			for _, p in ipairs({ pBase, pPonta }) do
				p.Massless = false
				p.CustomPhysicalProperties = PhysicalProperties.new(DEDOS_RAGDOLL.densidade, 0.8, 0, 1, 1)
			end
			pPonta.CanCollide = DEDOS_RAGDOLL.colidirPonta

			local lo1, hi1 = limitesDobradica(curBase, DEDOS_RAGDOLL.limBase[1], DEDOS_RAGDOLL.limBase[2], dir)
			local a0 = novoAttachment(palma, Ks * HO)
			local a1 = novoAttachment(pBase, CFrame.new(0, hb / 2, 0) * HO)
			novaDobradica(a0, a1, lo1, hi1, pBase)

			local lo2, hi2 = limitesDobradica(curPonta, DEDOS_RAGDOLL.limPonta[1], DEDOS_RAGDOLL.limPonta[2], dir)
			local a2 = novoAttachment(pBase, CFrame.new(0, -hb / 2, 0) * HO)
			local a3 = novoAttachment(pPonta, CFrame.new(0, hp / 2, 0) * HO)
			novaDobradica(a2, a3, lo2, hi2, pPonta)

			if art.juntaWeld then
				for _, w in ipairs(art.juntaWeld) do w.Part0 = pBase end
			end

			local v, w = palma.AssemblyLinearVelocity, palma.AssemblyAngularVelocity
			pBase.AssemblyLinearVelocity, pPonta.AssemblyLinearVelocity = v, v
			pBase.AssemblyAngularVelocity, pPonta.AssemblyAngularVelocity = w, w
		end

		if DEDOS_RAGDOLL.colidirPonta then
			local outros, vistos = {}, {}
			for _, d in ipairs(character:GetDescendants()) do
				if d:IsA("BasePart") then table.insert(outros, d); vistos[d] = true end
			end
			for _, art in ipairs(partesMao) do
				for _, p in ipairs({ art.pBase, art.pPonta, art.palma }) do
					if p and not vistos[p] then table.insert(outros, p); vistos[p] = true end
				end
			end
			for _, art in ipairs(partesMao) do
				if art.pPonta and art.pPonta.Parent then
					for _, q in ipairs(outros) do
						if q ~= art.pPonta then
							local nc = Instance.new("NoCollisionConstraint")
							nc.Name = "RagDedoNoCollide"
							nc.Part0, nc.Part1 = art.pPonta, q
							nc.Parent = art.pPonta
							table.insert(ragdollDedosCriados, nc)
						end
					end
				end
			end
		end

		ragdollDedosConn = RunService.Heartbeat:Connect(function(dt)
			if not folder.Parent or not dedosRagdollAtivo then
				if ragdollDedosConn then ragdollDedosConn:Disconnect(); ragdollDedosConn = nil end
				return
			end
			local f = math.max(0, 1 - DEDOS_RAGDOLL.amortecimento * dt)
			for _, art in ipairs(partesMao) do
				local pBase, pPonta = art.pBase, art.pPonta
				if pBase and pPonta and pBase.Parent and pPonta.Parent then
					pBase.AssemblyAngularVelocity = pBase.AssemblyAngularVelocity * f
					pPonta.AssemblyAngularVelocity = pPonta.AssemblyAngularVelocity * f

					if art.juntaWeld and art.ragDir then
						local rel = pBase.CFrame:ToObjectSpace(pPonta.CFrame)
						local th = math.deg(math.atan2(rel.RightVector.Y, rel.RightVector.X))
						local cf1, s1, cf2, s2 = calcJuntaCFrames(
							art.id, art.ehDireito, th * art.ragDir, CFrame.new(0, -art.ragHb / 2, 0)
						)
						art.juntaWeld[1].Part1.Size, art.juntaWeld[1].C0 = s1, cf1
						art.juntaWeld[2].Part1.Size, art.juntaWeld[2].C0 = s2, cf2
					end
				end
			end
		end)
	end

	_G.__DedosRagdoll = { ligar = ragdollDedosLigar, desligar = ragdollDedosDesligar }

	local rightShoulder = torso:FindFirstChild("Right Shoulder")
	local leftShoulder = torso:FindFirstChild("Left Shoulder")
	local neck = torso:FindFirstChild("Neck")
	local rightHip = torso:FindFirstChild("Right Hip")
	local leftHip = torso:FindFirstChild("Left Hip")
	local rootJoint = rootPart:FindFirstChild("RootJoint")

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character, folder }

	local atualTargetRight, atualTargetLeft = CFrame.new(), CFrame.new()
	local atualTargetNeck, atualTargetRoot = CFrame.new(), CFrame.new()
	local atualTargetHipR, atualTargetHipL = CFrame.new(), CFrame.new()

	loopConnectionStepped = RunService.Stepped:Connect(function(_, dt)
		if not character or humanoid.Health <= 0 then return end

		local pesoD = molaBracoDireito:update(dt)
		local pesoE = molaBracoEsquerdo:update(dt)
		local pesoC = molaCabeca:update(dt)
		local pesoB = molaCorpo:update(dt)
		local pesoP = molaPernas:update(dt)

		if rightShoulder and math.abs(pesoD) > 0.001 then
			rightShoulder.Transform = rightShoulder.Transform:Lerp(atualTargetRight, clamp(pesoD, 0, 1.5))
		end
		if leftShoulder and math.abs(pesoE) > 0.001 then
			leftShoulder.Transform = leftShoulder.Transform:Lerp(atualTargetLeft, clamp(pesoE, 0, 1.5))
		end
		if neck and math.abs(pesoC) > 0.001 then
			neck.Transform = neck.Transform:Lerp(atualTargetNeck, clamp(pesoC, 0, 1.5))
		end
		if rootJoint and math.abs(pesoB) > 0.001 then
			rootJoint.Transform = rootJoint.Transform:Lerp(atualTargetRoot, clamp(pesoB, 0, 1.5))
		end
		if math.abs(pesoP) > 0.001 then
			if rightHip then rightHip.Transform = rightHip.Transform:Lerp(atualTargetHipR, clamp(pesoP, 0, 1.5)) end
			if leftHip then leftHip.Transform = leftHip.Transform:Lerp(atualTargetHipL, clamp(pesoP, 0, 1.5)) end
		end
	end)

	local dormirFX = nil

	local function dormirLigar()
		if dormirFX and dormirFX.pasta.Parent then return end

		local pasta = Instance.new("Folder")
		pasta.Name = "DormirFX"
		pasta.Parent = folder

		local function peca(nome)
			local p = Instance.new("Part")
			p.Name = nome
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Massless = true
			p.Parent = pasta
			return p
		end

		local ancora = peca("ZzzAncora")
		ancora.Size = Vector3.new(0.2, 0.2, 0.2)
		ancora.Transparency = 1

		local zs = {}
		for i = 1, DORMIR.zzzQtd do
			local bb = Instance.new("BillboardGui")
			bb.Name = "Z" .. i
			bb.Adornee = ancora
			bb.Size = UDim2.fromScale(0.5, 0.5)
			bb.LightInfluence = 0
			bb.AlwaysOnTop = false
			bb.MaxDistance = 120
			bb.Parent = ancora

			local lbl = Instance.new("TextLabel")
			lbl.BackgroundTransparency = 1
			lbl.Size = UDim2.fromScale(1, 1)
			lbl.AnchorPoint = Vector2.new(0.5, 0.5)
			lbl.Position = UDim2.fromScale(0.5, 0.5)
			lbl.Text = "Z"
			lbl.Font = Enum.Font.FredokaOne
			lbl.TextScaled = true
			lbl.TextColor3 = DORMIR.zzzCor
			lbl.TextStrokeColor3 = DORMIR.zzzContorno
			lbl.TextStrokeTransparency = 0.2
			lbl.TextTransparency = 1
			lbl.Parent = bb

			zs[i] = { bb = bb, lbl = lbl }
		end

		dormirFX = { pasta = pasta, ancora = ancora, zs = zs }
	end

	local function dormirDesligar()
		if dormirFX then
			dormirFX.pasta:Destroy()
			dormirFX = nil
		end
	end

	local function dormirAtualizar(tempo)
		local fx = dormirFX
		local head = character:FindFirstChild("Head")
		if not fx or not head then return end

		local up = torso.CFrame.UpVector
		local dir = Vector3.new(up.X, 0, up.Z)
		if dir.Magnitude < 0.3 then
			local l = rootPart.CFrame.LookVector
			dir = Vector3.new(l.X, 0, l.Z)
		end
		if dir.Magnitude < 0.001 then dir = Vector3.new(0, 0, -1) end
		dir = dir.Unit
		local right = dir:Cross(Vector3.yAxis)
		local hp = head.Position

		local origem = hp + Vector3.yAxis * 0.9 + dir * 0.2
		fx.ancora.CFrame = CFrame.new(origem)
		local n = #fx.zs
		for i, z in ipairs(fx.zs) do
			local fase = (tempo / DORMIR.zzzTempo + (i - 1) / n) % 1
			local sobe = fase * DORMIR.zzzAltura
			local lado = sin(fase * 6.28 * 1.5 + i * 1.7) * 0.35 + fase * 0.9
			z.bb.StudsOffsetWorldSpace = Vector3.yAxis * sobe + right * lado + dir * (fase * 0.4)
			local tam = 0.5 + (DORMIR.zzzTamanho - 0.5) * fase
			z.bb.Size = UDim2.fromScale(tam, tam)
			z.lbl.Rotation = sin(fase * 6.28 * 2 + i) * 12
			local a = clamp(fase / 0.15, 0, 1) * clamp((1 - fase) / 0.35, 0, 1)
			z.lbl.TextTransparency = 1 - a
			z.lbl.TextStrokeTransparency = 1 - a * 0.8
		end
	end

	local gozarFX = nil
	local gozarRayParams = RaycastParams.new()
	gozarRayParams.FilterType = Enum.RaycastFilterType.Exclude
	gozarRayParams.FilterDescendantsInstances = { character, folder }

	local function gozarLigar()
		if gozarFX and gozarFX.pasta.Parent then return end

		local pasta = Instance.new("Folder")
		pasta.Name = "GozarFX"
		pasta.Parent = folder

		local ancora = Instance.new("Part")
		ancora.Name = "GozarAncora"
		ancora.Anchored = true
		ancora.CanCollide = false
		ancora.CanQuery = false
		ancora.CanTouch = false
		ancora.CastShadow = false
		ancora.Massless = true
		ancora.Size = Vector3.new(0.25, 0.25, 0.25)
		ancora.Transparency = 1
		ancora.Parent = pasta

		local att = Instance.new("Attachment")
		att.Name = "GozarAtt"

		att.CFrame = CFrame.Angles(rad(90), 0, 0)
		att.Parent = ancora

		local tr0 = GOZAR.transparencia
		local function criarEmitter(nome, sizeSeq, speedRange, spread)
			local pe = Instance.new("ParticleEmitter")
			pe.Name = nome
			pe.Texture = GOZAR.texturaParticula
			pe.Color = ColorSequence.new(GOZAR.cor)
			pe.Size = sizeSeq
			pe.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, tr0),
				NumberSequenceKeypoint.new(0.45, tr0 + 0.15),
				NumberSequenceKeypoint.new(1, 1),
			})
			pe.Lifetime = GOZAR.lifetime
			pe.Speed = speedRange
			pe.SpreadAngle = Vector2.new(spread, spread)

			pe.Acceleration = Vector3.new(0, -22, 0)
			pe.Drag = 0.8
			pe.Rate = 0
			pe.Rotation = NumberRange.new(0, 360)
			pe.RotSpeed = NumberRange.new(-60, 60)
			pe.LightEmission = 0.2
			pe.LightInfluence = 0.12
			pe.EmissionDirection = Enum.NormalId.Front
			pe.Enabled = true
			pe.Parent = att
			return pe
		end

		local pe = criarEmitter(
			"Gozar",
			GOZAR.partSize,
			GOZAR.speed,
			GOZAR.spread
		)
		local pe2 = criarEmitter(
			"Gozar2",
			NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(0.5, 0.16),
				NumberSequenceKeypoint.new(1, 0.04),
			}),
			NumberRange.new(0.5, 1.6),
			8
		)

		local pocasPasta = Instance.new("Folder")
		pocasPasta.Name = "Pocas"
		pocasPasta.Parent = pasta

		gozarFX = {
			pasta = pasta,
			ancora = ancora,
			pe = pe,
			pe2 = pe2,
			pocas = pocasPasta,
			pocasAtivas = {},
			acumPoca = 0,
		}
	end

	local function gozarDesligar()
		if gozarFX then
			gozarFX.pasta:Destroy()
			gozarFX = nil
		end
	end

	local function spawnPoca(hitPos, hitNormal, inten)
		local fx = gozarFX
		if not fx then return end

		while #fx.pocasAtivas >= GOZAR.pocasMax do
			local antiga = table.remove(fx.pocasAtivas, 1)
			if antiga and antiga.Parent then antiga:Destroy() end
		end

		local tam = GOZAR.pocaTamanhoMin + (GOZAR.pocaTamanhoMax - GOZAR.pocaTamanhoMin) * (0.35 + 0.65 * inten)
		tam = tam * (0.85 + math.random() * 0.3)

		local poca = Instance.new("Part")
		poca.Name = "Poca"
		poca.Anchored = true
		poca.CanCollide = false
		poca.CanQuery = false
		poca.CanTouch = false
		poca.CastShadow = false
		poca.Massless = true
		poca.Material = Enum.Material.SmoothPlastic
		poca.Color = Color3.fromRGB(255, 252, 248)
		poca.Transparency = 1
		poca.Size = Vector3.new(tam, 0.04, tam)

		local up = hitNormal.Magnitude > 0.01 and hitNormal.Unit or Vector3.yAxis
		local cf = CFrame.lookAt(hitPos + up * 0.025, hitPos + up * 0.025 + up)

		poca.CFrame = cf * CFrame.Angles(rad(-90), rad(math.random() * 360), 0)
		poca.Parent = fx.pocas

		local trBase = GOZAR.transparencia
		local decal = Instance.new("Decal")
		decal.Name = "Textura"
		decal.Face = Enum.NormalId.Top
		decal.Texture = GOZAR.texturaChao
		decal.Transparency = trBase
		decal.Parent = poca

		table.insert(fx.pocasAtivas, poca)

		local dur = GOZAR.pocaDuracao * (0.85 + math.random() * 0.3)
		task.spawn(function()
			local t0 = tick()
			while poca.Parent do
				local t = tick() - t0
				if t >= dur then break end
				local fade = clamp((t - dur * 0.55) / (dur * 0.45), 0, 1)
				decal.Transparency = trBase + (1 - trBase) * fade

				local s = 1 - 0.25 * fade
				poca.Size = Vector3.new(tam * s, 0.04, tam * s)
				task.wait(0.08)
			end
			if poca.Parent then poca:Destroy() end

			if fx.pocasAtivas then
				local i = table.find(fx.pocasAtivas, poca)
				if i then table.remove(fx.pocasAtivas, i) end
			end
		end)
	end

	local function gozarAtualizar(inten, dt)
		local fx = gozarFX
		if not fx then return end

		local torsoPart = character:FindFirstChild("Torso")
		if not torsoPart then return end

		local origem = torsoPart.CFrame * CFrame.new(0, -0.85, -0.55)
		fx.ancora.CFrame = origem

		local rate = GOZAR.minRate + (GOZAR.maxRate - GOZAR.minRate) * inten
		fx.pe.Rate = rate
		fx.pe2.Rate = rate * 0.55

		local velExtra = 0.6 * inten
		fx.pe.Acceleration = Vector3.new(0, -22 - 6 * inten, 0)
		fx.pe.Speed = NumberRange.new(0.8 + velExtra * 0.3, 2.2 + velExtra)
		fx.pe2.Speed = NumberRange.new(0.5 + velExtra * 0.2, 1.6 + velExtra * 0.7)
		fx.pe.SpreadAngle = Vector2.new(GOZAR.spread, GOZAR.spread)
		fx.pe2.SpreadAngle = Vector2.new(8, 8)

		fx.acumPoca = (fx.acumPoca or 0) + (dt or 0.03)
		local intervalo = GOZAR.pocaSpawnInterval / (0.4 + 0.6 * inten)
		if fx.acumPoca >= intervalo then
			fx.acumPoca = 0
			local look = torsoPart.CFrame.LookVector
			local right = torsoPart.CFrame.RightVector
			for _ = 1, (inten > 0.6 and 2 or 1) do
				local ox = (math.random() - 0.5) * 0.55
				local oz = -0.15 - math.random() * 0.45
				local origemRay = origem.Position + right * ox + look * oz + Vector3.yAxis * 0.15
				local hit = workspace:Raycast(origemRay, Vector3.new(0, -8, 0), gozarRayParams)
				if hit then
					spawnPoca(hit.Position, hit.Normal, inten)
				end
			end
		end
	end

	local imovelOrig = nil
	local corpoAplicado = false
	local function travarImovel(ligar)
		if ligar then
			if not imovelOrig then
				imovelOrig = {
					ws = humanoid.WalkSpeed, jp = humanoid.JumpPower,
					jh = humanoid.JumpHeight, ar = humanoid.AutoRotate,
				}
				humanoid.JumpPower = 0
				humanoid.JumpHeight = 0
				humanoid.AutoRotate = false
			end
			humanoid.WalkSpeed = 0
		elseif imovelOrig then
			humanoid.WalkSpeed = imovelOrig.ws
			humanoid.JumpPower = imovelOrig.jp
			humanoid.JumpHeight = imovelOrig.jh
			humanoid.AutoRotate = imovelOrig.ar
			imovelOrig = nil
		end
	end

	-- Kamehameha: estado, sons (com fade) e VFX
	local kameFase, kameInicio, kameUltimoEmote = nil, 0, nil
	local kameFxFase, kameFxT = nil, 0
	local kame = KAME.criar({
		character = character, rootPart = rootPart, rightArm = rightArm, leftArm = leftArm,
		folder = folder, partesMao = partesMao, ehLocal = true,
	})
	local kameSomParar, kameSomTocar, kameSomAtualizar = kame.somParar, kame.somTocar, kame.somAtualizar
	local kameFala = kame.fala
	local kameVfxAtualizar, kameVfxDestruir = kame.vfxAtualizar, kame.vfxDestruir

	loopConnectionRender = RunService.RenderStepped:Connect(function(dt)
		if not character or not character.Parent or humanoid.Health <= 0 then
			dormirDesligar()
			gozarDesligar()
			siriricaTempo = 0
			siriricaSoundPlayed = false
			travarImovel(false)
			kameSomParar(true)
			kameFala.parar()
			kameVfxDestruir()
			limparMaos(); return
		end

		if typingTimer > 0 then typingTimer -= dt else typingMode = false end

		if emoteTimer > 0 then
			emoteTimer -= dt
		else
			if currentEmote ~= nil then
				if EMOTES_CORPO[currentEmote] then
					limparAgachamentoBow(character)
				end
			end
			if not freezeEmote then
				currentEmote = nil
			end
		end

		-- Kamehameha: KF1-3 anda, KF4-9 parado + som de recarga, KF10-11 parado + som de disparo
		local kameParado = false
		kameFxFase, kameFxT = nil, 0
		if currentEmote == "Kamehameha" and not freezeEmote and emoteTimer > 0 then
			if kameUltimoEmote ~= "Kamehameha" then kameInicio = os.clock() end
			local t = (os.clock() - kameInicio) % KAME.ciclo
			local fase = (t < KAME.tFase2) and 1 or ((t < KAME.tFase3) and 2 or 3)
			kameParado = (fase ~= 1)
			kameFxFase, kameFxT = fase, t
			if fase ~= kameFase then
				kameFase = fase
				kameFala.entrar(fase, t)
				if fase == 2 then
					kameSomTocar(KAME.somRecarga, os.clock() + (KAME.tFase3 - t))
				elseif fase == 3 then
					kameSomTocar(KAME.somDisparo, os.clock() + (KAME.ciclo - t))
				else
					kameSomParar()
				end
			end
		elseif kameFase ~= nil then
			kameFase = nil
			kameSomParar()
			kameFala.parar()
		end
		kameUltimoEmote = currentEmote
		kameSomAtualizar()
		kameVfxAtualizar(kameFxFase, kameFxT, dt)

		local devBaixo = freezeEmote and currentEmote ~= nil and EMOTES_BAIXOS[currentEmote] ~= nil
		local travar = currentEmote ~= nil and EMOTES_IMOVEIS[currentEmote] == true and ((not freezeEmote and emoteTimer > 0) or devBaixo)
		if currentEmote == "Kamehameha" and not freezeEmote then
			travar = travar and kameParado
		end
		travarImovel(travar)

		local tempo = tick()

		do
			-- itens do emote (acessórios / roupas / mesh): no DEV mostra os que você está editando; fora dele, os do emote
			local listaItens = nil
			if currentEmote ~= nil then
				if freezeEmote then
					listaItens = customPose.itens
				elseif emoteTimer > 0 then
					local dEmote = defaultEmotes[currentEmote]
					listaItens = dEmote and dEmote.itens
				end
			end
			ItensEmote.real.sincronizar(character, listaItens)
			ItensEmote.real.atualizar(listaItens)
		end

		if currentEmote ~= nil and DORMIR.emotes[currentEmote] then
			dormirLigar()
			dormirAtualizar(tempo)
		elseif dormirFX then
			dormirDesligar()
		end

		if currentEmote == "Siririca" and (emoteTimer > 0 or freezeEmote) then
			siriricaTempo = siriricaTempo + dt
			local inten = 0
			if siriricaTempo > GOZAR.delay then
				inten = clamp((siriricaTempo - GOZAR.delay) / GOZAR.buildup, 0, 1)
				gozarLigar()
				gozarAtualizar(inten, dt)

				if inten >= 1 and not siriricaSoundPlayed then
					siriricaSoundPlayed = true
					local s = Instance.new("Sound")
					s.Name = "SiriricaNivel3"
					s.SoundId = GOZAR.soundId
					s.Volume = GOZAR.soundVolume or 0.5
					s.RollOffMode = Enum.RollOffMode.InverseTapered
					s.MaxDistance = 80
					s.Parent = rootPart
					s:Play()
					s.Ended:Connect(function()
						if s and s.Parent then s:Destroy() end
					end)
					task.delay(12, function()
						if s and s.Parent then s:Destroy() end
					end)
				end
			end
		else
			if siriricaTempo > 0 then
				siriricaTempo = 0
			end
			siriricaSoundPlayed = false
			if gozarFX then
				gozarDesligar()
			end
		end

		local toolEquipada = character:FindFirstChildOfClass("Tool")

		local rightGrip = rightArm:FindFirstChild("RightGrip")
		local leftGrip = leftArm:FindFirstChild("LeftGrip")
		local segurandoToolRight = (rightGrip ~= nil)
		local segurandoToolLeft = (leftGrip ~= nil)
		local anguloAdaptativo = toolEquipada and calcularEspessuraCabo(toolEquipada) or 0

		if Pegar.ativo and (currentEmote ~= nil or (Pegar.usaDireita and segurandoToolRight) or (Pegar.usaEsquerda and segurandoToolLeft)) then
			Pegar.soltar()
		end

		local P
		local corpoAtivo = currentEmote ~= nil and EMOTES_CORPO[currentEmote] == true

		if corpoAplicado and not corpoAtivo then
			limparAgachamentoBow(character)
			corpoAplicado = false
		end
		if freezeEmote and currentEmote then
			P = calcularPoseCustom()
			if corpoAtivo then

				aplicarCorpoBow(character, humanoid, rootPart, EMOTES_BAIXOS[currentEmote] ~= nil, currentEmote)
				corpoAplicado = true
			end
		elseif currentEmote then
			P = calcularPoseEmote(currentEmote, tempo, true)
			if corpoAtivo then
				aplicarCorpoBow(character, humanoid, rootPart, true, currentEmote)
				corpoAplicado = true
			end
		elseif Pegar.ativo then
			P = Pegar.pose(poseVazia())
		elseif apontarCamera then
			P = poseVazia()
			if animConfig.direita then
				local camLook = Camera.CFrame.LookVector
				local charCF = rootPart.CFrame

				local rightComp = camLook:Dot(charCF.RightVector)
				local upComp = camLook:Dot(charCF.UpVector)
				local fwdComp = camLook:Dot(charCF.LookVector)

				local pitch = math.atan2(upComp, math.sqrt(rightComp ^ 2 + fwdComp ^ 2))
				local yaw = math.atan2(rightComp, fwdComp)

				yaw = clamp(yaw, rad(-APONTAR_MAX_YAW), rad(APONTAR_MAX_YAW))
				pitch = clamp(pitch, rad(-APONTAR_MAX_PITCH), rad(APONTAR_MAX_PITCH))

				P.wR = 1
				P.R = CFrame.Angles(0, -yaw, rad(90) + pitch)
			end
		else
			P = poseVazia()
		end

		molaBracoDireito.t = P.wR
		molaBracoEsquerdo.t = P.wL
		molaCabeca.t = P.wN
		molaCorpo.t = P.wB
		molaPernas.t = P.wP

		atualTargetRight = atualTargetRight:Lerp(P.R, 0.18)
		atualTargetLeft = atualTargetLeft:Lerp(P.L, 0.18)
		atualTargetNeck = atualTargetNeck:Lerp(P.N, 0.18)
		atualTargetRoot = atualTargetRoot:Lerp(P.B, 0.18)
		atualTargetHipR = atualTargetHipR:Lerp(P.PR, 0.18)
		atualTargetHipL = atualTargetHipL:Lerp(P.PL, 0.18)

		local velY = rootPart.Velocity.Y
		local noAr = (velY > 5 or velY < -15)
		local velocidade = humanoid.MoveDirection.Magnitude
		local isRunning = (velocidade > 0 and humanoid.WalkSpeed > 16)

		for _, art in ipairs(partesMao) do
			if not art.braco or not art.braco.Parent then continue end
			if dedosRagdollAtivo then continue end

			if art.trail then
				art.trail.Enabled = (currentEmote == "Apontar" or (apontarCamera and not Pegar.ativo))
			end

			local alvoBase, alvoPonta = 0, 0
			local ext = nil
			local poseMao = art.ehDireito and customPose.direita or customPose.esquerda
			local bracoAtivo
			if art.ehDireito then bracoAtivo = animConfig.direita else bracoAtivo = animConfig.esquerda end
			local modoDev = (freezeEmote and currentEmote ~= nil and bracoAtivo)

			if modoDev then
				art.palmaWeld.C0 = CFrame.new(0, -1.0, 0) * CFrame.Angles(rad(poseMao.palma.x), rad(poseMao.palma.y), rad(poseMao.palma.z))
			else
				local defE = currentEmote and bracoAtivo and defaultEmotes[currentEmote]
				if defE then
					local pp = art.ehDireito and defE.palmaDir or defE.palmaEsq
					art.palmaWeld.C0 = CFrame.new(0, -1.0, 0) * CFrame.Angles(rad(pp.x), rad(pp.y), rad(pp.z))
				else
					art.palmaWeld.C0 = CFrame.new(0, -1.0, 0)
				end
			end

			if modoDev then
				local dedoConfig = poseMao.dedos[art.id]
				alvoBase = dedoConfig[1]
				alvoPonta = dedoConfig[2]
				ext = dedoConfig

			elseif currentEmote and bracoAtivo then
				local b, p = alvoDedosEmote(currentEmote, art.id, art.ehDireito)
				alvoBase, alvoPonta = b or 0, p or 0
				ext = extraDedoEmote(currentEmote, art.id, art.ehDireito)

			elseif (art.ehDireito and Pegar.usaDireita) or (not art.ehDireito and Pegar.usaEsquerda) then
				if art.id == 1 then
					alvoBase, alvoPonta = 12, 18
				elseif Pegar.pesado then
					alvoBase, alvoPonta = 18, 24
				else
					alvoBase, alvoPonta = 28, 38
				end

			elseif apontarCamera and not Pegar.ativo and bracoAtivo then
				if art.id == 2 and art.ehDireito then
					alvoBase, alvoPonta = 0, 0
				else
					alvoBase, alvoPonta = 90, 90
				end

			elseif typingMode and bracoAtivo then
				alvoBase = math.random(-10, 30)
				alvoPonta = math.random(-10, 30)

			elseif (art.ehDireito and segurandoToolRight) or (not art.ehDireito and segurandoToolLeft) then
				if art.id == 1 then
					alvoBase, alvoPonta = anguloAdaptativo * 0.6, anguloAdaptativo * 0.5
				else
					alvoBase, alvoPonta = anguloAdaptativo, anguloAdaptativo * 1.05
				end

			elseif noAr then
				alvoBase, alvoPonta = -15, -10

			elseif isRunning then
				alvoBase = 45 + sin(tempo * 15) * 5
				alvoPonta = 50 + cos(tempo * 15) * 5

			elseif velocidade > 0 then
				local curva = (art.id == 1) and 5 or (art.id * 4)
				local atraso = art.id * 0.25
				alvoBase = curva + sin(tempo * 10 - atraso) * 12
				alvoPonta = (curva * 0.8) + cos(tempo * 10 - atraso) * 10

			else
				local curva = (art.id == 1) and 3 or (art.id * 3)
				local atraso = art.id * 0.3
				alvoBase = curva + sin(tempo * 2 - atraso) * 3
				alvoPonta = (curva * 0.8) + cos(tempo * 2 - atraso) * 2
			end

			art.angBase = tweenValue(art.angBase, alvoBase, SMOOTH_FACTOR)
			art.angPonta = tweenValue(art.angPonta, alvoPonta, SMOOTH_FACTOR)

			local afast = 0
			if modoDev then
				afast = afastGraus(art.id, art.ehDireito, poseMao.afastamento)
			end

			local localBaseCF, localPontaCF, localPivotCF = calcFingerCFrames(art.id, art.ehDireito, art.angBase, art.angPonta, afast, ext)
			art.baseWeld.C0 = localBaseCF
			if art.juntaWeld then
				local cf1, s1, cf2, s2 = calcJuntaCFrames(art.id, art.ehDireito, art.angPonta, localPivotCF)
				art.juntaWeld[1].Part1.Size, art.juntaWeld[1].C0 = s1, cf1
				art.juntaWeld[2].Part1.Size, art.juntaWeld[2].C0 = s2, cf2
			end

			local pontaWorldCFrame = art.palma.CFrame * localPontaCF
			local raio = workspace:Raycast(pontaWorldCFrame.Position, pontaWorldCFrame.UpVector * -0.3, rayParams)
			if raio then
				art.pPonta.Size = Vector3.new(art.origTamanhoPonta.X, art.origTamanhoPonta.Y * 0.7, art.origTamanhoPonta.Z)
				art.pontaWeld.C0 = localPontaCF * CFrame.new(0, art.origTamanhoPonta.Y * 0.15, 0)
			else
				art.pPonta.Size = art.origTamanhoPonta
				art.pontaWeld.C0 = localPontaCF
			end
		end
	end)

	humanoid.Died:Connect(limparMaos)
end

carregarMeshDedo()

if LocalPlayer.Character then criarMaoDinamica(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(char)
	task.wait(1)
	criarMaoDinamica(char)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		typingMode = true
		typingTimer = 3
	end
end)

-- Mini TP:
--  * clicar em quem esta "De Quatro" te teleporta atras dela e liga o seu Socar
--    (so funciona se voce ja estiver atras dela, dentro da area)
--  * clicar em um clone com "Socar" te teleporta na frente dele e liga o seu De Quatro
--    (so funciona se voce ja estiver na frente dele, dentro da area)
do
	local TP_DIST_MAX = 3.5   -- distancia maxima pra o tp funcionar
	local TP_DIST_ATRAS = 2.5 -- distancia final atras dela

	local function cloneDoModelo(char)
		local cs = _G.__ClonesHands
		if not (cs and cs.lista) then return nil end
		for _, c in ipairs(cs.lista()) do
			if c.model == char then return c end
		end
		return nil
	end

	local function estaDeQuatro(char)
		local clone = cloneDoModelo(char)
		if clone then return clone.emote == "De Quatro" end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
		local raiz = char:FindFirstChild("HumanoidRootPart")
		if not (hum and torso and raiz) or hum.Health <= 0 then return false end
		-- torso inclinado pra frente (de quatro). Ajuste os limites se precisar.
		local up = torso.CFrame.UpVector.Y
		return up < 0.5 and up > -0.85
	end

	local alvoAtual = nil -- quem estou "acompanhando" depois do tp
	local modoAtual = nil -- "tras" (eu faco Socar) ou "frente" (eu faco De Quatro)

	local function estaComSocar(char)
		local clone = cloneDoModelo(char)
		return clone ~= nil and clone.emote == "Socar"
	end

	local SOM_ID = "rbxassetid://18609250427"
	local somAtual = nil
	local function pararSom()
		deQuatroSync.inicio = nil
		deQuatroSync.pendente = false
		if somAtual then
			pcall(function() somAtual:Stop() somAtual:Destroy() end)
			somAtual = nil
		end
	end
	local function iniciarSom()
		pararSom()
		local raiz = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not raiz then return end
		local snd = Instance.new("Sound")
		snd.Name = "SomDeQuatro"
		snd.SoundId = SOM_ID
		snd.Looped = true
		snd.Volume = 0.1
		snd.Parent = raiz
		snd:Play()
		somAtual = snd
	end

	local function tentarTP(alvoChar)
		local meu = LocalPlayer.Character
		local meuRoot = meu and meu:FindFirstChild("HumanoidRootPart")
		local alvoRoot = alvoChar:FindFirstChild("HumanoidRootPart")
		if not (meuRoot and alvoRoot) then return end
		if currentEmote ~= nil then return end

		local frente = Vector3.new(alvoRoot.CFrame.LookVector.X, 0, alvoRoot.CFrame.LookVector.Z)
		if frente.Magnitude < 0.01 then return end
		frente = frente.Unit

		local delta = meuRoot.Position - alvoRoot.Position
		local plano = Vector3.new(delta.X, 0, delta.Z)
		if plano.Magnitude > TP_DIST_MAX then return end
		local lado = plano:Dot(frente) -- >0 = estou na frente dela, <0 = estou atras

		local destino, olhar, meuEmote, modo
		if lado < 0 and estaDeQuatro(alvoChar) then
			modo, meuEmote = "tras", "Socar"
			destino = alvoRoot.Position - frente * TP_DIST_ATRAS
			olhar = frente
		elseif lado > 0 and estaComSocar(alvoChar) then
			modo, meuEmote = "frente", "De Quatro"
			destino = alvoRoot.Position + frente * TP_DIST_ATRAS
			olhar = frente -- de costas pra ela
		else
			return
		end

		destino = Vector3.new(destino.X, meuRoot.Position.Y, destino.Z)
		meuRoot.CFrame = CFrame.lookAt(destino, destino + olhar)
		alvoAtual = alvoChar
		modoAtual = modo
		tocarEmote(meuEmote)
		iniciarSom()
		deQuatroSync.emote = meuEmote
		deQuatroSync.pendente = true
	end

	RunService.Heartbeat:Connect(function()
		if not alvoAtual then
			if somAtual then pararSom() end
			return
		end
		local meuEmote = deQuatroSync.emote
		if currentEmote ~= meuEmote then alvoAtual = nil pararSom() return end -- voce mesmo parou/trocou
		local aindaOk = alvoAtual.Parent ~= nil
			and ((modoAtual == "tras" and estaDeQuatro(alvoAtual)) or (modoAtual == "frente" and estaComSocar(alvoAtual)))
		if not aindaOk then
			alvoAtual = nil
			pararSom()
			tocarEmote(meuEmote) -- toggle: desliga
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local cam = workspace.CurrentCamera
		local pos = UserInputService:GetMouseLocation()
		if input.UserInputType == Enum.UserInputType.Touch then pos = Vector2.new(input.Position.X, input.Position.Y) end
		local ray = cam:ViewportPointToRay(pos.X, pos.Y)
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = { LocalPlayer.Character }
		local res = workspace:Raycast(ray.Origin, ray.Direction * 500, rp)
		if not (res and res.Instance) then return end
		local char = res.Instance:FindFirstAncestorOfClass("Model")
		if not char then return end
		local plr = Players:GetPlayerFromCharacter(char)
		if (plr and plr ~= LocalPlayer) or cloneDoModelo(char) then tentarTP(char) end
	end)
end
