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
	["Chupada de Dedo"] = true, ["De Quatro"] = true, Socar = true,
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

local function extraDedoEmote(emote, id, ehDireito)
	local d = emote and defaultEmotes[emote]
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

local function alvoDedosEmote(emote, id, ehDireito)
	if emoteAnimado(emote) then
		local d = defaultEmotes[emote]
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

local function calcularPoseEmote(emote, tempo, usar)
	local P = poseVazia()
	local dirOn = (not usar) or animConfig.direita
	local esqOn = (not usar) or animConfig.esquerda

	if emoteAnimado(emote) then
		local d = defaultEmotes[emote]
		local u = d.usa or {}
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

	local btnMin = btn({ Text = "-", TextSize = 16, TextColor3 = T.sub, Size = UDim2.fromOffset(sz, sz), Position = cfg.posMin, Parent = head }, { round(cfg.radius or 8) })
	hoverFX(btnMin, T.surface2, T.surface3)
	local btnX = cfg.btnX
	if not btnX then
		btnX = btn({ Text = "X", TextSize = 13, TextColor3 = T.danger, Size = UDim2.fromOffset(sz, sz), Position = cfg.posX, Parent = head }, { round(cfg.radius or 8) })
		hoverFX(btnX, T.surface2, T.danger)
	end

	-- quadradinho para reabrir (aparece quando a janela é fechada no X)
	local chip
	if not cfg.semChip then
		chip = btn({
			Text = "□", TextSize = 18, TextColor3 = T.accent, Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = T.surface, Visible = false, ZIndex = 40, Parent = MainGui,
		}, { round(10), outline(T.stroke, 1, 0.1) })
		hoverFX(chip, T.surface, T.surface3)
	end
	local function atualizarChip()
		if chip then chip.Visible = fechada and ((not cfg.ativo) or cfg.ativo()) end
	end

	local function minimizar(min)
		if animando or fechada then return end
		animando = true
		minimizado = min
		btnMin.Text = min and "□" or "-"
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
		btnMin.Text = "□"
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
	{ nome = "Siririca", icone = "💦", cat = "+18", toggle = true },
	{ nome = "Chupada de Dedo", icone = "👅", cat = "+18", toggle = true },
	{ nome = "De Quatro", icone = "🐕", cat = "+18", toggle = true },
	{ nome = "Socar", icone = "🍆", cat = "+18", toggle = true },
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
	if EMOTES_TOGGLE[nome] then return currentEmote == nome and emoteTimer > 0 end
	return currentEmote == nome and (emoteTimer > 0 or freezeEmote)
end

local function tocarEmote(nome)
	local def = EMOTE_POR_NOME[nome]
	if def and def.cat == "+18" and not liberado18() then return end
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
		if nome ~= "Siririca" then siriricaTempo = 0 end
		currentEmote = nome
		emoteTimer = emoteDuration
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
	Text = "X", TextSize = 13, TextColor3 = T.sub, Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -38, 0, 10), Parent = Menu,
}, { round(13) })
hoverFX(closeMenuBtn, T.surface2, T.surface3)

-- ===== configurações =====
local configBtn = btn({
	Text = "⚙", TextSize = 15, TextColor3 = T.sub, Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -70, 0, 10), Parent = Menu,
}, { round(13) })
hoverFX(configBtn, T.surface2, T.surface3)

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
	Text = "X", TextSize = 12, TextColor3 = T.sub, Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -36, 0, 10), ZIndex = 62, Parent = configCard,
}, { round(12) })
hoverFX(configClose, T.surface2, T.surface3)

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
	Text = "Nenhum favorito ainda.\nToque na ★ de um emote para fixar.", TextWrapped = true, TextSize = 12, TextColor3 = T.dim,
	TextXAlignment = CENTER, Position = UDim2.fromOffset(16, 120), Size = UDim2.fromOffset(286, 40), Visible = false, Parent = Menu,
})

local previewPane = frame({
	Position = UDim2.fromOffset(MENU_W - 16 - 150, 88), Size = UDim2.new(0, 150, 1, -88 - 34), Parent = Menu,
}, { round(14), outline(T.stroke, 1, 0.5) })
local previewVP = novoViewport({ Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 136), BackgroundColor3 = T.bg, Parent = previewPane })
local menuPreview = criarPreview(previewVP)
local previewNome = txt({ Text = "—", Font = F.GothamBold, TextSize = 14, Position = UDim2.fromOffset(12, 148), Size = UDim2.new(1, -24, 0, 18), Parent = previewPane })
local previewCat = txt({ Text = "", TextSize = 11, TextColor3 = T.dim, Position = UDim2.fromOffset(12, 166), Size = UDim2.new(1, -24, 0, 14), Parent = previewPane })

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
		Text = "＋ Criar", TextSize = 12, Font = F.GothamBold, BackgroundColor3 = T.accent, TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(1, -188, 0, 0), Size = UDim2.fromOffset(90, 30), Parent = painel,
	}, { round(8) })
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
		local function item(rotulo, nome, ordem)
			local b = btn({
				Text = rotulo, TextSize = 12, TextXAlignment = LEFT, BackgroundColor3 = T.surface2, LayoutOrder = ordem,
				Size = UDim2.new(1, 0, 0, 26), ZIndex = 23, Parent = pickerLista,
			}, { round(7), padding(10, 0, 6, 0) })
			hoverFX(b, T.surface2, T.surface3)
			b.MouseButton1Click:Connect(function()
				local cs = CS()
				if cs and pickerAlvo then cs.setEmote(pickerAlvo, nome) end
				fecharPicker()
			end)
		end
		item("🚫  Nenhum", nil, 0)
		local cs = CS()
		if cs then
			for i, e in ipairs(cs.emotesDisponiveis()) do
				item(e.icone .. "  " .. e.nome, e.nome, i)
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
				Text = emoteDef and (emoteDef.icone .. " " .. c.emote) or "Emote: nenhum", TextSize = 11,
				TextColor3 = c.emote and T.text or T.sub, BackgroundColor3 = c.emote and T.accentSoft or T.surface2,
				TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(120, 6), Size = UDim2.fromOffset(140, 28),
				Parent = linha,
			}, { round(8), padding(8, 0, 8, 0) })
			hoverFX(emoteBtn, c.emote and T.accentSoft or T.surface2, T.surface3)
			emoteBtn.MouseButton1Click:Connect(function() abrirPicker(c.id) end)

			local seguirBtn = btn({
				Text = c.seguir and "⏹ Parar" or "▶ Seguir", TextSize = 11, Font = F.GothamBold,
				TextColor3 = c.seguir and Color3.new(1, 1, 1) or T.text,
				BackgroundColor3 = c.seguir and T.accent or T.surface2,
				Position = UDim2.fromOffset(266, 6), Size = UDim2.fromOffset(78, 28), Parent = linha,
			}, { round(8) })
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
	previewNome.Text = e.icone .. "  " .. e.nome
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
		r.star.Text = favSet[nome] and "★" or "☆"
		r.star.TextColor3 = favSet[nome] and T.warn or T.dim
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
			txt({ Text = e.icone, TextSize = 26, TextXAlignment = CENTER, Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 34), Parent = card })
			txt({ Text = e.nome, Font = F.GothamMedium, TextSize = 11, TextXAlignment = CENTER, Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 16), Parent = card })
			txt({ Text = e.cat, TextSize = 9, TextColor3 = T.dim, TextXAlignment = CENTER, Position = UDim2.fromOffset(0, 65), Size = UDim2.new(1, 0, 0, 14), Parent = card })
			local dot = frame({ BackgroundColor3 = T.ok, Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(10, 10), Visible = false, Parent = card }, { round(4) })
			local star = btn({
				BackgroundTransparency = 1, Text = "☆", TextSize = 16, Size = UDim2.fromOffset(26, 26),
				Position = UDim2.new(1, -28, 0, 2), ZIndex = 3, Parent = card,
			})
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
txt({ Text = "🔒  Categoria +18", Font = F.GothamBold, TextSize = 14, Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 18), ZIndex = 52, Parent = senhaCard })
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
	}, { round(12), padding(10, 0, 10, 0) })
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
	chipRefs["+18"].Text = liberado18() and "+18" or "🔒 +18"
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
	Text = "✦  Emotes", Font = F.GothamBold, TextSize = 13, BackgroundColor3 = T.accent, TextColor3 = Color3.new(1, 1, 1),
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 64), Size = UDim2.fromOffset(112, 38), Parent = MainGui,
}, { round(19) })
hoverFX(EmoteButton, T.accent, Color3.fromRGB(148, 134, 255))
EmoteButton.MouseButton1Click:Connect(function() toggleMenu() end)

Pegar.botao = btn({
	Text = "Pegar", Font = F.GothamBold, TextSize = 13, BackgroundColor3 = T.ok, TextColor3 = Color3.new(1, 1, 1),
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 110), Size = UDim2.fromOffset(112, 38), Parent = MainGui,
}, { round(19) })

do
	local function corBotao()
		return Pegar.ativo and T.danger or T.ok
	end

	function Pegar.atualizarBotao()
		Pegar.botao.Text = Pegar.ativo and "Soltar" or "Pegar"
		tw(Pegar.botao, 0.15, { BackgroundColor3 = corBotao() })
	end

	function Pegar.aviso(msg)
		Pegar.avisoId = (Pegar.avisoId or 0) + 1
		local id = Pegar.avisoId
		Pegar.botao.Text = msg
		task.delay(1.3, function()
			if Pegar.avisoId == id then Pegar.atualizarBotao() end
		end)
	end

	Pegar.botao.MouseEnter:Connect(function()
		tw(Pegar.botao, 0.12, { BackgroundColor3 = corBotao():Lerp(Color3.new(1, 1, 1), 0.18) })
	end)
	Pegar.botao.MouseLeave:Connect(function()
		tw(Pegar.botao, 0.12, { BackgroundColor3 = corBotao() })
	end)

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

	Pegar.botao.MouseButton1Click:Connect(function()
		if Pegar.ativo then Pegar.soltar() else Pegar.pegar() end
	end)
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

local trocarBtn = btn({ Text = "⇄", TextSize = 15, TextColor3 = T.sub, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -114, 0, 11), Parent = devHead }, { round(15) })
local closeDevBtn = btn({ Text = "X", Font = F.GothamBold, TextSize = 13, TextColor3 = T.sub, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -42, 0, 11), Parent = devHead }, { round(15) })
hoverFX(trocarBtn, T.surface2, T.surface3)
hoverFX(closeDevBtn, T.surface2, T.danger)
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
	local chev = txt({ Text = secOpen[key] and "▾" or "▸", TextSize = 12, TextColor3 = T.dim, TextXAlignment = RIGHT, Size = UDim2.new(1, -12, 1, 0), Parent = head })
	local body = frame({
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2,
		Visible = secOpen[key], Parent = wrap,
	}, { padding(12, 2, 12, 12), lista(6) })
	head.MouseButton1Click:Connect(function()
		secOpen[key] = not secOpen[key]
		body.Visible = secOpen[key]
		chev.Text = secOpen[key] and "▾" or "▸"
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
		Text = "＋ Adicionar", Font = F.GothamBold, TextSize = 12, BackgroundColor3 = T.accent, TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 6, Parent = S1,
	}, { round(9) })
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
	espelharBtn.Text = espelhar and "Espelhar ✓" or "Espelhar"
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
local prevAnim = btn({ Text = "▶", TextSize = 13, TextColor3 = T.ok, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -124, 0, 6), Parent = prevHead }, { round(14) })
hoverFX(prevAnim, T.surface2, T.surface3)
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
		prevAnim.Text = animando and "▶" or "⏸"
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
local closeSel = btn({ Text = "X", TextSize = 13, TextColor3 = T.sub, Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -26, 0, 2), ZIndex = 31, Parent = selHead }, { round(13) })
hoverFX(closeSel, T.surface2, T.danger)
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
	Text = "＋ Criar Emote", Font = F.GothamBold, TextSize = 10, BackgroundColor3 = T.accent, TextColor3 = Color3.new(1, 1, 1),
	Position = UDim2.new(1, -72, 0, 34), Size = UDim2.fromOffset(72, 28), ZIndex = 31, Parent = DevSelector,
}, { round(7) })
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
	local impX = btn({ Text = "X", TextSize = 13, TextColor3 = T.sub, Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -26, 0, 0), ZIndex = 42, Parent = impHead }, { round(13) })
	hoverFX(impX, T.surface2, T.danger)

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
		Text = "📋 Colar", Font = F.GothamBold, TextSize = 11, Position = UDim2.new(1, -78, 0, 72), Size = UDim2.fromOffset(78, 28), ZIndex = 42, Parent = impCard,
	}, { round(7), outline(T.stroke, 1, 0.3) })
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
		Text = "📥 Importar animação (colar código)", Font = F.GothamBold, TextSize = 11, TextColor3 = T.ok,
		Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 26), ZIndex = 31, Parent = DevSelector,
	}, { round(7), outline(T.stroke, 1, 0.3) })
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
	local loopBtn = btn({ Text = "Loop ✓", TextSize = 11, Position = UDim2.fromOffset(232, 40), Size = UDim2.fromOffset(68, 26), Parent = TLWin }, { round(6) })
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

	local prevBtn = btn({ Text = "◀", TextSize = 13, Position = UDim2.fromOffset(12, 146), Size = UDim2.fromOffset(38, 30), Parent = TLWin }, { round(8) })
	local playBtn = btn({ Text = "▶", TextSize = 14, TextColor3 = T.ok, Position = UDim2.fromOffset(56, 146), Size = UDim2.fromOffset(46, 30), Parent = TLWin }, { round(8) })
	local nextBtn = btn({ Text = "▶|", TextSize = 12, Position = UDim2.fromOffset(108, 146), Size = UDim2.fromOffset(38, 30), Parent = TLWin }, { round(8) })
	local addBtn = btn({ Text = "＋ Key", Font = F.GothamBold, TextSize = 12, BackgroundColor3 = T.accent, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(154, 146), Size = UDim2.fromOffset(76, 30), Parent = TLWin }, { round(8) })
	local delBtn = btn({ Text = "Apagar", TextSize = 11, TextColor3 = T.danger, Position = UDim2.fromOffset(236, 146), Size = UDim2.fromOffset(54, 30), Parent = TLWin }, { round(8) })
	local expBtn = btn({ Text = "Exportar", Font = F.GothamBold, TextSize = 11, TextColor3 = T.ok, Position = UDim2.fromOffset(296, 146), Size = UDim2.fromOffset(72, 30), Parent = TLWin }, { round(8) })
	for _, b in ipairs({ prevBtn, playBtn, nextBtn, delBtn, expBtn }) do hoverFX(b, T.surface2, T.surface3) end
	hoverFX(addBtn, T.accent, Color3.fromRGB(148, 134, 255))

	txt({ Text = "Faça a pose nos sliders → escolha o tempo → ＋ Key", TextSize = 10, TextColor3 = T.dim, TextXAlignment = CENTER, Position = UDim2.fromOffset(0, 218), Size = UDim2.new(1, 0, 0, 14), Parent = TLWin })

	local moveBtn = btn({ Text = "⇆ Mover key", TextSize = 11, Position = UDim2.fromOffset(12, 182), Size = UDim2.fromOffset(114, 28), Parent = TLWin }, { round(8) })
	local copyBtn = btn({ Text = "⧉ Copiar", TextSize = 11, Position = UDim2.fromOffset(133, 182), Size = UDim2.fromOffset(114, 28), Parent = TLWin }, { round(8) })
	local pasteBtn = btn({ Text = "📋 Colar", TextSize = 11, TextColor3 = T.dim, Position = UDim2.fromOffset(254, 182), Size = UDim2.fromOffset(114, 28), Parent = TLWin }, { round(8) })
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
		playBtn.Text = anim.tocando and "⏸" or "▶"
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
		loopBtn.Text = anim.loop and "Loop ✓" or "Loop ✗"
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
		copyBtn.Text = "✓ Copiado"
		task.delay(0.8, function() copyBtn.Text = "⧉ Copiar" end)
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
		if #anim.keys == 0 then return "-- adicione pelo menos 1 keyframe (＋ Key)" end

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
	"Chupada de Dedo", "De Quatro", "Socar",
}
local ordemLinhaDev = 0
function adicionarLinhaDev(nome, icone)
	ordemLinhaDev = ordemLinhaDev + 1
	local row = btn({ BackgroundColor3 = T.surface, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = ordemLinhaDev, ZIndex = 30, Parent = selList }, { round(8) })
	txt({ Text = icone, TextSize = 15, TextXAlignment = CENTER, Position = UDim2.fromOffset(4, 0), Size = UDim2.fromOffset(26, 30), ZIndex = 31, Parent = row })
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
	local EMOTES_OCULTOS = { Ragdoll = true, Apontar = true }

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

	function api.remover(id)
		for i, c in ipairs(clones) do
			if c.id == id then
				if c.model then c.model:Destroy() end
				table.remove(clones, i)
				break
			end
		end
		avisar()
	end

	function api.removerTodos()
		for _, c in ipairs(clones) do
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

	local function ia(c, dt, agora)
		local hum, root = c.hum, c.root
		local meu = LocalPlayer.Character
		local meuRoot = meu and meu:FindFirstChild("HumanoidRootPart")
		local meuHum = meu and meu:FindFirstChildOfClass("Humanoid")
		local emote = c.emote
		local parado = emote ~= nil and (EMOTES_IMOVEIS[emote] == true or EMOTES_CORPO[emote] == true)

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

		local P = emote and calcularPoseEmote(emote, t, false) or poseVazia()
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
		local defE = emote and defaultEmotes[emote]
		for _, art in ipairs(c.dedos) do
			local alvoB, alvoP, ext = 0, 0, nil
			local pp = defE and (art.ehDireito and defE.palmaDir or defE.palmaEsq)
			if pp then
				art.palmaWeld.C0 = CFrame.new(0, -1.0, 0) * CFrame.Angles(rad(pp.x), rad(pp.y), rad(pp.z))
			else
				art.palmaWeld.C0 = CFrame.new(0, -1.0, 0)
			end

			if emote then
				local b, p = alvoDedosEmote(emote, art.id, art.ehDireito)
				alvoB, alvoP = b or 0, p or 0
				ext = extraDedoEmote(emote, art.id, art.ehDireito)
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
				table.remove(clones, i)
				avisar()
			else
				local ok, err = pcall(ia, c, dt, agora)
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

	loopConnectionRender = RunService.RenderStepped:Connect(function(dt)
		if not character or not character.Parent or humanoid.Health <= 0 then
			dormirDesligar()
			gozarDesligar()
			siriricaTempo = 0
			siriricaSoundPlayed = false
			travarImovel(false)
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

		local devBaixo = freezeEmote and currentEmote ~= nil and EMOTES_BAIXOS[currentEmote] ~= nil
		travarImovel(currentEmote ~= nil and EMOTES_IMOVEIS[currentEmote] == true and ((not freezeEmote and emoteTimer > 0) or devBaixo))

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
