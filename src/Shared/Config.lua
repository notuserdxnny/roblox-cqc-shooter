--!strict
--[[
	Shared game configuration for the CQC arena shooter.
	Tune damage, range, ammo, reload, feel, sounds, and arena layout here.
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
	Gun feel (client). Recoil recovers quickly; FOV kick is subtle.
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

-- Arena (readable CQC layout with lanes)
Config.Arena = {
	Size = 96, -- floor width/depth
	WallHeight = 16,
	WallThickness = 2.5,
	FloorY = 0,
	SpawnHeight = 4,
	CoverPieces = 10, -- designed cover count (not random soup)
}

-- Outdoor-ish lighting (also set in default.project.json; WorldSetup reinforces)
Config.Lighting = {
	Ambient = Color3.fromRGB(90, 95, 110),
	OutdoorAmbient = Color3.fromRGB(120, 125, 140),
	Brightness = 2.2,
	ClockTime = 14.5,
	GeographicLatitude = 25,
}

-- NPC dummies for solo testing
Config.NPC = {
	Count = 3,
	WalkSpeed = 6,
	WanderRadius = 22,
	WanderInterval = 3.5,
	MaxHealth = 100,
	Name = "Training Dummy",
	-- Fixed-ish spawn offsets from arena center (sensible cover-adjacent spots)
	SpawnOffsets = {
		Vector3.new(18, 0, -12),
		Vector3.new(-16, 0, 14),
		Vector3.new(8, 0, 20),
	},
}

-- HUD / scoring
Config.HUD = {
	UpdateInterval = 0.1,
}

-- Remotes (names under ReplicatedStorage.Remotes)
Config.Remotes = {
	FireWeapon = "FireWeapon",
	FireResult = "FireResult", -- server → shooter: hit/miss juice payload
	AmmoUpdate = "AmmoUpdate",
	KillFeed = "KillFeed",
	StatsUpdate = "StatsUpdate",
}

return Config
