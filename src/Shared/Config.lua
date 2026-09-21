--!strict
--[[
	Shared game configuration for the CQC room shooter.
	Tune weapons, feel, sounds, room layout, and hub here.
]]

local Config = {}

export type WeaponDef = {
	Id: string,
	Name: string,
	DamageClose: number,
	DamageFar: number,
	MaxRange: number,
	EffectiveRange: number,
	FireCooldown: number,
	MagazineSize: number,
	ReloadTime: number,
	PelletCount: number,
	SpreadDegrees: number,
	MuzzleOffset: Vector3,
	HandleSize: Vector3,
	HandleColor: Color3,
	TipColor: Color3,
	ToolTip: string,
	Blurb: string,
}

--[[
	Three distinct CQC tools. Shotgun = pellet spread; SMG = rapid; Pistol = hard hits.
]]
Config.Weapons = {
	Shotgun = {
		Id = "Shotgun",
		Name = "Shotgun",
		DamageClose = 16,
		DamageFar = 3,
		MaxRange = 38,
		EffectiveRange = 12,
		FireCooldown = 0.78,
		MagazineSize = 6,
		ReloadTime = 2.3,
		PelletCount = 8,
		SpreadDegrees = 7.5,
		MuzzleOffset = Vector3.new(0, 0, -1.6),
		HandleSize = Vector3.new(0.45, 0.45, 2.4),
		HandleColor = Color3.fromRGB(55, 42, 32),
		TipColor = Color3.fromRGB(200, 90, 40),
		ToolTip = "Pellet spread · Hold LMB · R reload",
		Blurb = "Devastating up close. 8 pellets, slow pump.",
	} :: WeaponDef,
	SMG = {
		Id = "SMG",
		Name = "SMG",
		DamageClose = 14,
		DamageFar = 5,
		MaxRange = 55,
		EffectiveRange = 22,
		FireCooldown = 0.09,
		MagazineSize = 30,
		ReloadTime = 1.55,
		PelletCount = 1,
		SpreadDegrees = 3.2,
		MuzzleOffset = Vector3.new(0, 0, -1.5),
		HandleSize = Vector3.new(0.35, 0.35, 2.0),
		HandleColor = Color3.fromRGB(40, 44, 52),
		TipColor = Color3.fromRGB(80, 160, 220),
		ToolTip = "Full-auto spray · Hold LMB · R reload",
		Blurb = "High fire rate, large mag, light per-shot damage.",
	} :: WeaponDef,
	Pistol = {
		Id = "Pistol",
		Name = "Pistol",
		DamageClose = 34,
		DamageFar = 12,
		MaxRange = 70,
		EffectiveRange = 28,
		FireCooldown = 0.26,
		MagazineSize = 12,
		ReloadTime = 1.35,
		PelletCount = 1,
		SpreadDegrees = 1.1,
		MuzzleOffset = Vector3.new(0, 0, -1.1),
		HandleSize = Vector3.new(0.32, 0.4, 1.3),
		HandleColor = Color3.fromRGB(32, 32, 38),
		TipColor = Color3.fromRGB(220, 200, 80),
		ToolTip = "Precise punches · Hold LMB · R reload",
		Blurb = "Accurate single shots with strong falloff damage.",
	} :: WeaponDef,
}

-- Hotbar / hub order
Config.WeaponOrder = { "Shotgun", "SMG", "Pistol" }

-- Default starting weapon when hub starts the match
Config.DefaultWeaponId = "SMG"

function Config.GetWeapon(id: string): WeaponDef?
	return Config.Weapons[id]
end

function Config.GetWeaponByToolName(name: string): WeaponDef?
	for _, def in Config.Weapons do
		if def.Name == name then
			return def
		end
	end
	return nil
end

function Config.IsWeaponTool(tool: Instance?): boolean
	return tool ~= nil and tool:IsA("Tool") and Config.GetWeaponByToolName(tool.Name) ~= nil
end

-- Legacy single-weapon alias (SMG) for any leftover reads
Config.Weapon = Config.Weapons.SMG

-- Combat validation
Config.Combat = {
	MaxLookDistanceFromCharacter = 8,
	MinDamage = 1,
	HeadshotMultiplier = 1.35,
	FriendlyFire = true,
}

--[[
	Gun feel (client). Recoil is CAMERA-ONLY (pitch/yaw offset).
	Never writes HumanoidRootPart / character CFrame.
]]
Config.Feel = {
	RecoilPitchDegrees = 1.35,
	RecoilYawDegrees = 0.35,
	RecoilRecoverSeconds = 0.12,
	FovKick = 1.8,
	FovRecoverSeconds = 0.14,
	MuzzleFlashSeconds = 0.06,
	MuzzleLightBrightness = 4,
	MuzzleLightRange = 10,
	TracerDuration = 0.08,
	TracerWidth = 0.12,
	HitMarkerSeconds = 0.12,
	HeadshotMarkerSeconds = 0.18,
	DamageNumberLifetime = 0.9,
	DamageNumberRise = 2.5,
	-- Per-weapon feel multipliers (applied client-side on shot)
	RecoilByWeapon = {
		Shotgun = 2.2,
		SMG = 0.85,
		Pistol = 1.35,
	},
}

Config.SoundIds = {
	Fire = "rbxassetid://9114224527",
	FireAlt = "rbxassetid://9114226351",
	Reload = "rbxassetid://9111680145",
	Empty = "rbxassetid://9113895097",
	HitConfirm = "rbxassetid://9114221327",
	Headshot = "rbxassetid://9114222212",
}

Config.SoundVolumes = {
	Fire = 0.55,
	FireAlt = 0.28,
	Reload = 0.5,
	Empty = 0.45,
	HitConfirm = 0.55,
	Headshot = 0.7,
}

Config.Arena = {
	Size = 96,
	WallHeight = 14,
	WallThickness = 1.5,
	FloorY = 0,
	SpawnHeight = 4,
	CoverPieces = 0,
}

Config.Map = {
	GridCols = 3,
	GridRows = 3,
	RoomSize = 30,
	WallHeight = 14,
	WallThickness = 1.5,
	DoorWidth = 6,
	DoorHeight = 9,
	DoorThickness = 0.6,
	FloorY = 0,
	Ceiling = true,
	StartCol = 1,
	StartRow = 1,
	HalfWallRooms = {
		{ 2, 1 },
		{ 1, 2 },
		{ 3, 2 },
		{ 2, 3 },
	},
	CrawlGapRooms = {
		{ 2, 2 },
		{ 3, 1 },
	},
	DoorTweenSeconds = 0.35,
	DoorOpenAngleDegrees = 95,
}

Config.Lighting = {
	Ambient = Color3.fromRGB(55, 58, 70),
	OutdoorAmbient = Color3.fromRGB(40, 42, 50),
	Brightness = 1.4,
	ClockTime = 22,
	GeographicLatitude = 25,
}

Config.NPC = {
	Count = 3,
	WalkSpeed = 6,
	WanderRadius = 10,
	WanderInterval = 3.5,
	MaxHealth = 100,
	Name = "Training Dummy",
	SpawnOffsets = {
		Vector3.new(60, 0, 0),
		Vector3.new(0, 0, 60),
		Vector3.new(60, 0, 60),
	},
}

Config.HUD = {
	UpdateInterval = 0.1,
}

Config.Camera = {
	LockFirstPerson = true,
	MinZoom = 0.5,
	MaxZoom = 0.5,
	EnableMouseLock = false,
}

Config.Hub = {
	Title = "CQC ROOM SHOOTER",
	Subtitle = "Pick a starter weapon, then clear the rooms.",
	HowTo = "Hold LMB to fire · R reload · Hotbar 1–3 switch guns · Doors open away from you · Jump half-walls · Slide crawl gaps",
}

-- Remotes (names under ReplicatedStorage.Remotes)
Config.Remotes = {
	FireWeapon = "FireWeapon",
	FireResult = "FireResult",
	AmmoUpdate = "AmmoUpdate",
	KillFeed = "KillFeed",
	StatsUpdate = "StatsUpdate",
	ToggleDoor = "ToggleDoor",
	StartMatch = "StartMatch", -- C→S { weaponId: string }
	MatchStarted = "MatchStarted", -- S→C { weaponId: string }
}

return Config
