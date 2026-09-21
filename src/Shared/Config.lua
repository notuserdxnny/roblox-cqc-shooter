--!strict
--[[
	Shared game configuration for the CQC arena shooter.
	Tune damage, range, ammo, reload, and arena layout here.
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

-- Arena
Config.Arena = {
	Size = 80, -- floor half-extent is Size/2
	WallHeight = 18,
	WallThickness = 2,
	FloorY = 0,
	SpawnHeight = 4,
	CoverCount = 6,
	CoverSize = Vector3.new(6, 5, 6),
}

-- NPC dummies for solo testing
Config.NPC = {
	Count = 2,
	WalkSpeed = 6,
	WanderRadius = 18,
	WanderInterval = 3.5,
	MaxHealth = 100,
	Name = "Training Dummy",
}

-- HUD / scoring
Config.HUD = {
	UpdateInterval = 0.1,
}

-- Remotes (names under ReplicatedStorage.Remotes)
Config.Remotes = {
	FireWeapon = "FireWeapon",
	AmmoUpdate = "AmmoUpdate",
	KillFeed = "KillFeed",
	StatsUpdate = "StatsUpdate",
}

return Config
