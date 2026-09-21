--!strict
--[[
	Shared game configuration for the CQC room shooter.
	Tune damage, range, ammo, reload, feel, sounds, and room layout here.
]]

local Config = {}

-- Weapon (close-range SMG / shotgun hybrid)
Config.Weapon = {
	Name = "CQC Blaster",
	DamageClose = 28, -- damage at point-blank
	DamageFar = 6, -- damage near max range
	MaxRange = 55, -- studs; beyond this, raycast is rejected
	EffectiveRange = 25, -- within this, full close damage
	FireCooldown = 0.18, -- seconds between shots
	MagazineSize = 12,
	ReloadTime = 1.6, -- seconds
	PelletCount = 1, -- 1 = SMG beam; raise for shotgun spread
	SpreadDegrees = 2.5, -- cone half-angle when PelletCount > 1
	MuzzleOffset = Vector3.new(0, 0, -1.5),
}

-- Combat validation
Config.Combat = {
	MaxLookDistanceFromCharacter = 8, -- how far origin can be from humanoid root
	MinDamage = 1,
	HeadshotMultiplier = 1.35,
	FriendlyFire = true, -- players can damage each other
}

--[[
	Gun feel (client). Recoil is CAMERA-ONLY (pitch/yaw offset).
	Never writes HumanoidRootPart / character CFrame.
	Server still owns damage — client only plays juice from FireResult.
]]
Config.Feel = {
	RecoilPitchDegrees = 1.35, -- camera punch up
	RecoilYawDegrees = 0.35, -- slight random left/right
	RecoilRecoverSeconds = 0.12, -- how fast punch returns
	FovKick = 1.8, -- temporary FOV increase on fire
	FovRecoverSeconds = 0.14,
	MuzzleFlashSeconds = 0.06,
	MuzzleLightBrightness = 4,
	MuzzleLightRange = 10,
	TracerDuration = 0.08, -- Beam lifetime
	TracerWidth = 0.12,
	HitMarkerSeconds = 0.12,
	HeadshotMarkerSeconds = 0.18,
	DamageNumberLifetime = 0.9, -- Billboard lifetime
	DamageNumberRise = 2.5, -- studs upward
}

--[[
	Roblox library / well-known free SoundIds.
	These are common public toolbox IDs that usually resolve in Studio.
	Swap any ID in Studio if a sound fails to load for your account.
	Format: rbxassetid://NUMBER
]]
Config.SoundIds = {
	Fire = "rbxassetid://9114224527", -- short gunshot / blaster-like
	FireAlt = "rbxassetid://9114226351", -- layered secondary crack
	Reload = "rbxassetid://9111680145", -- mechanical reload / insert
	Empty = "rbxassetid://9113895097", -- dry click / empty chamber
	HitConfirm = "rbxassetid://9114221327", -- soft hit tick
	Headshot = "rbxassetid://9114222212", -- sharper confirm
}

Config.SoundVolumes = {
	Fire = 0.55,
	FireAlt = 0.28,
	Reload = 0.5,
	Empty = 0.45,
	HitConfirm = 0.55,
	Headshot = 0.7,
}

--[[
	Indoor room complex (replaces open arena).
	Grid of square rooms with doorways + swinging doors between neighbors.
]]
Config.Arena = {
	-- Kept for NPCService / legacy references; map uses Config.Map
	Size = 96,
	WallHeight = 14,
	WallThickness = 1.5,
	FloorY = 0,
	SpawnHeight = 4,
	CoverPieces = 0,
}

Config.Map = {
	GridCols = 3, -- X
	GridRows = 3, -- Z
	RoomSize = 30, -- interior square (studs)
	WallHeight = 14,
	WallThickness = 1.5,
	DoorWidth = 6,
	DoorHeight = 9,
	DoorThickness = 0.6,
	FloorY = 0,
	Ceiling = true,
	-- Start room grid index (1-based): southwest corner
	StartCol = 1,
	StartRow = 1,
	-- Rooms that get waist-high cover / crawl gaps (col,row)
	HalfWallRooms = {
		{ 2, 1 },
		{ 1, 2 },
		{ 3, 2 },
		{ 2, 3 },
	},
	CrawlGapRooms = {
		{ 2, 2 }, -- center
		{ 3, 1 },
	},
	-- Door tween
	DoorTweenSeconds = 0.35,
	DoorOpenAngleDegrees = 95,
}

-- Indoor lighting (WorldSetup also places per-room PointLights)
Config.Lighting = {
	Ambient = Color3.fromRGB(55, 58, 70),
	OutdoorAmbient = Color3.fromRGB(40, 42, 50),
	Brightness = 1.4,
	ClockTime = 22,
	GeographicLatitude = 25,
}

-- NPC dummies for solo testing (placed in specific rooms via WorldSetup offsets)
Config.NPC = {
	Count = 3,
	WalkSpeed = 6,
	WanderRadius = 10,
	WanderInterval = 3.5,
	MaxHealth = 100,
	Name = "Training Dummy",
	-- World positions filled by map (room centers); WorldSetup / Main may override via Init(center)
	-- Offsets relative to map origin (start room center-ish); Main passes room centers from Config
	SpawnOffsets = {
		-- Room (3,1) and (1,3) and (3,3) approx — refined in WorldSetup comments / Main
		Vector3.new(60, 0, 0),
		Vector3.new(0, 0, 60),
		Vector3.new(60, 0, 60),
	},
}

-- HUD / scoring
Config.HUD = {
	UpdateInterval = 0.1,
}

-- First-person lock
Config.Camera = {
	LockFirstPerson = true,
	MinZoom = 0.5,
	MaxZoom = 0.5,
	EnableMouseLock = false, -- shift-lock optional off
}

-- Remotes (names under ReplicatedStorage.Remotes)
Config.Remotes = {
	FireWeapon = "FireWeapon",
	FireResult = "FireResult", -- server → shooter: hit/miss juice payload
	AmmoUpdate = "AmmoUpdate",
	KillFeed = "KillFeed",
	StatsUpdate = "StatsUpdate",
	ToggleDoor = "ToggleDoor", -- C→S request; server owns door state
}

return Config
