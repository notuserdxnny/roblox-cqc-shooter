--!strict
--[[
	Shared game configuration for the CQC room shooter.
	Tune weapons, feel, sounds, room layout, hub, and OITC here.
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

-- Weapon catalog order (Shotgun/SMG kept for later; OITC only grants Pistol)
Config.WeaponOrder = { "Shotgun", "SMG", "Pistol" }

-- Active match weapon (OITC-only for now)
Config.DefaultWeaponId = "Pistol"

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

function Config.IsMeleeTool(tool: Instance?): boolean
	return tool ~= nil and tool:IsA("Tool") and tool.Name == "Knife"
end

-- Legacy single-weapon alias (Pistol / OITC) for leftover reads
Config.Weapon = Config.Weapons.Pistol

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

--[[
	Sound catalog (document IDs here — replace with your own uploads if needed).
	Countdown / stingers / match loop used by Hub.client.lua.
]]
Config.SoundIds = {
	Fire = "rbxassetid://9114224527",
	FireAlt = "rbxassetid://9114226351",
	Reload = "rbxassetid://9111680145",
	Empty = "rbxassetid://9113895097",
	HitConfirm = "rbxassetid://9114221327",
	Headshot = "rbxassetid://9114222212",
	Melee = "rbxassetid://9114221327",
	-- Announcer / round flow
	CountdownTick = "rbxassetid://9113895097", -- punchy beep (playback speed varies 3→1)
	Countdown3 = "rbxassetid://9113895097", -- optional distinct; falls back to CountdownTick
	Countdown2 = "rbxassetid://9113895097",
	Countdown1 = "rbxassetid://9113895097",
	CountdownGo = "rbxassetid://9113824583", -- GO! sting
	RoundStart = "rbxassetid://9113824583", -- alias / match start sting
	MatchLoop = "rbxassetid://1848354536", -- quiet looping bed during match
	WinSting = "rbxassetid://5852410825", -- victory sting on MatchEnded
}

Config.SoundVolumes = {
	Fire = 0.55,
	FireAlt = 0.28,
	Reload = 0.5,
	Empty = 0.45,
	HitConfirm = 0.55,
	Headshot = 0.7,
	Melee = 0.6,
	RoundStart = 0.55,
	CountdownTick = 0.4,
	Countdown3 = 0.45,
	Countdown2 = 0.5,
	Countdown1 = 0.55,
	CountdownGo = 0.65,
	MatchLoop = 0.18, -- keep quiet under gunfire
	WinSting = 0.6,
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
	DoorInteractDistance = 8, -- client E + server range check (no ProximityPrompt)
	DoorHintMaxDistance = 10, -- BillboardGui MaxDistance for "[E] Open/Close"
}

Config.Lighting = {
	Ambient = Color3.fromRGB(55, 58, 70),
	OutdoorAmbient = Color3.fromRGB(40, 42, 50),
	Brightness = 1.4,
	ClockTime = 22,
	GeographicLatitude = 25,
}

--[[
	Combat bots (replaces passive Training Dummies).
	OITC-style: 1 bullet, server raycast gun, melee when close, refill on kill.
]]
Config.NPC = {
	Count = 4,
	Name = "Bot",
	WalkSpeed = 14,
	MaxHealth = 100,
	StartingAmmo = 1,
	-- CQC engagement: short enough that bots cannot snipe across the 3x3 grid
	AcquireRange = 42,
	FireRange = 36,
	MeleeRange = 7,
	GunDamage = 100, -- OITC one-shot
	MeleeDamage = 100,
	FireCooldown = 0.85,
	MeleeCooldown = 0.55,
	PathInterval = 2.2,
	WanderInterval = 3.5,
	EmptyAmmoRegenSeconds = 8, -- if they miss forever, slowly re-arm
	RespawnDelay = 5,
	RefillAmmoOnKill = true,
	RequireLineOfSight = true, -- walls / closed doors block gun + melee
	MinSpawnSeparationFromPlayers = 16,
	SpawnFloorRayHeight = 12,
	SpawnOffsets = {
		Vector3.new(60, 0, 0),
		Vector3.new(0, 0, 60),
		Vector3.new(60, 0, 60),
		Vector3.new(30, 0, 30),
	},
}

Config.HUD = {
	UpdateInterval = 0.1,
}

Config.Camera = {
	-- Applied after countdown GO / while CQCInMatch (not during hub or end overlay)
	LockFirstPerson = true,
	MinZoom = 0.5,
	MaxZoom = 0.5,
	EnableMouseLock = false,
	-- While hub / lobby (before Start)
	HubMinZoom = 8,
	HubMaxZoom = 20,
	HubDefaultZoom = 14,
}

Config.Hub = {
	Title = "ONE IN THE CHAMBER",
	Subtitle = "Pistol · 1 bullet · Knife when empty — Start for countdown, then fight.",
	HowTo = "Pistol only · 1 bullet · Kill = +1 ammo · Empty = Knife melee · First to KillsToWin wins · Respawn resets to 1 bullet · Doors · Jump half-walls · Slide crawl gaps",
	HowToOITC = "Pistol only · 1 bullet · Kill = +1 ammo · Empty = Knife melee · First to KillsToWin wins · Respawn resets to 1 bullet",
	ModeOITCBlurb = "One bullet. One pistol. Knife when empty. First to the kill goal wins.",
}

--[[
	Dedicated Lobby (separate from the combat room grid).
	Players spawn here before StartMatch; combat map is unreachable until Start.
]]
Config.Lobby = {
	-- World offset so the lobby sits clear of the 3x3 combat grid
	Offset = Vector3.new(-180, 0, -40),
	RoomSize = 28,
	WallHeight = 12,
	FloorY = 0,
	SpawnHeight = 4,
	FreezeWalkSpeed = 0,
	FreezeJumpPower = 0,
	MatchWalkSpeed = 16,
	MatchJumpPower = 50,
	MatchJumpHeight = 7.2,
	BackdropColor = Color3.fromRGB(18, 22, 32),
	AccentColor = Color3.fromRGB(70, 140, 220),
	PlatformColor = Color3.fromRGB(32, 38, 52),
}

--[[
	Match start countdown (OITC).
	After hub Start: teleport frozen → 3…2…1…GO! → unfreeze + weapons + InMatch.
]]
Config.Match = {
	CountdownSeconds = 3,
	GoDisplaySeconds = 0.85,
	EndFreezeSeconds = 1.25,
	-- Auto return to hub if player ignores end-screen buttons
	WinnerRestartSeconds = 20,
	-- Round-start sting on GO (Hub prefers SoundIds.CountdownGo / RoundStart)
	RoundStartSoundId = "rbxassetid://9113824583",
	RoundStartSoundVolume = 0.55,
	-- Match bed music (Hub starts on MatchStarted, stops on MatchEnded / Hub)
	MatchLoopSoundId = "rbxassetid://1848354536",
	MatchLoopVolume = 0.18,
	WinStingSoundId = "rbxassetid://5852410825",
	WinStingVolume = 0.6,
}

--[[
	Game is OITC-only for now. Modes table kept for attribute / remote payloads.
	One in the Chamber = pistol + 1 bullet, kill awards ammo, melee when empty.
]]
Config.Modes = {
	OITC = "OITC",
}

Config.DefaultMode = "OITC"

--[[
	One in the Chamber rules (classic).
]]
Config.OITC = {
	KillsToWin = 5,
	StartingAmmo = 1,
	-- Display mag size while in OITC (ammo is free-form count of bullets)
	MagazineDisplay = 1,
	WeaponId = "Pistol",
	AllowReload = false,
	ResetAmmoOnSpawn = true,
	GunDamage = 100, -- one-shot in OITC (classic)
	MeleeRange = 8,
	MeleeDamage = 100,
	MeleeCooldown = 0.5,
	MeleeToolName = "Knife",
	-- Prefer Config.Match.WinnerRestartSeconds; kept as fallback alias
	WinnerRestartSeconds = 20,
}

Config.Melee = {
	HandleSize = Vector3.new(0.28, 0.28, 1.4),
	HandleColor = Color3.fromRGB(180, 180, 190),
	TipColor = Color3.fromRGB(220, 40, 40),
	ToolTip = "Melee · LMB when out of bullets",
}

-- Remotes (names under ReplicatedStorage.Remotes)
Config.Remotes = {
	FireWeapon = "FireWeapon",
	FireResult = "FireResult",
	AmmoUpdate = "AmmoUpdate",
	KillFeed = "KillFeed",
	StatsUpdate = "StatsUpdate",
	ToggleDoor = "ToggleDoor",
	StartMatch = "StartMatch", -- C→S { } begin OITC match (also Play Again)
	MatchCountdown = "MatchCountdown", -- S→C { seconds, mode, weaponId } begin 3…2…1
	MatchStarted = "MatchStarted", -- S→C { weaponId, mode, inMatch } after GO — combat live
	MatchEnded = "MatchEnded", -- S→C { winnerName, mode, kills, youWin, durationSec }
	ReturnToHub = "ReturnToHub", -- C→S request hub / S→C force hub
	MeleeAttack = "MeleeAttack", -- C→S origin + look (OITC empty ammo)
}



-- ============================================================================
-- Economy / Credits (server-authoritative awards)
-- ============================================================================
Config.Economy = {
	StartingCredits = 100,
	CreditsPerKill = 25,
	CreditsPerWin = 100,
	CreditsPerMatchPlayed = 10, -- consolation if not winner
	DataStoreName = "CQCPlayerData_v1",
	DataStoreKeyPrefix = "plr_",
	SaveDebounceSeconds = 4,
}

--[[
	Shop catalog — Parts/Color3 only (no MeshAssets).
	Categories: PistolSkin, KnifeSkin, Trail, Hitmarker, Title
	Default items are free + owned on first join.
]]
Config.ShopItems = {
	-- Pistol skins
	{
		Id = "pistol_default",
		Name = "Stock Iron",
		Category = "PistolSkin",
		Price = 0,
		Default = true,
		HandleColor = Color3.fromRGB(32, 32, 38),
		TipColor = Color3.fromRGB(220, 200, 80),
		DisplayName = "Pistol",
		Description = "Factory finish.",
	},
	{
		Id = "pistol_crimson",
		Name = "Crimson Edge",
		Category = "PistolSkin",
		Price = 150,
		HandleColor = Color3.fromRGB(90, 18, 28),
		TipColor = Color3.fromRGB(255, 60, 70),
		DisplayName = "Crimson Pistol",
		Description = "Blood-red grip and neon tip.",
	},
	{
		Id = "pistol_arctic",
		Name = "Arctic Frost",
		Category = "PistolSkin",
		Price = 200,
		HandleColor = Color3.fromRGB(200, 220, 235),
		TipColor = Color3.fromRGB(100, 200, 255),
		DisplayName = "Arctic Pistol",
		Description = "Ice-white frame, cyan muzzle.",
	},
	{
		Id = "pistol_gold",
		Name = "Gilded Chamber",
		Category = "PistolSkin",
		Price = 350,
		HandleColor = Color3.fromRGB(180, 140, 40),
		TipColor = Color3.fromRGB(255, 220, 80),
		DisplayName = "Gold Pistol",
		Description = "Flashy gold plating.",
	},
	{
		Id = "pistol_void",
		Name = "Void Protocol",
		Category = "PistolSkin",
		Price = 300,
		HandleColor = Color3.fromRGB(20, 12, 40),
		TipColor = Color3.fromRGB(160, 80, 255),
		DisplayName = "Void Pistol",
		Description = "Deep purple neon accents.",
	},
	{
		Id = "pistol_neon",
		Name = "Toxic Neon",
		Category = "PistolSkin",
		Price = 250,
		HandleColor = Color3.fromRGB(20, 40, 24),
		TipColor = Color3.fromRGB(80, 255, 120),
		DisplayName = "Neon Pistol",
		Description = "Toxic green glow tip.",
	},
	-- Knife skins
	{
		Id = "knife_default",
		Name = "Standard Blade",
		Category = "KnifeSkin",
		Price = 0,
		Default = true,
		HandleColor = Color3.fromRGB(180, 180, 190),
		TipColor = Color3.fromRGB(220, 40, 40),
		DisplayName = "Knife",
		Description = "Issue combat knife.",
	},
	{
		Id = "knife_blood",
		Name = "Bloodletter",
		Category = "KnifeSkin",
		Price = 175,
		HandleColor = Color3.fromRGB(60, 20, 24),
		TipColor = Color3.fromRGB(255, 40, 60),
		DisplayName = "Blood Knife",
		Description = "Dark grip, glowing red blade.",
	},
	{
		Id = "knife_chrome",
		Name = "Chrome Edge",
		Category = "KnifeSkin",
		Price = 200,
		HandleColor = Color3.fromRGB(210, 215, 225),
		TipColor = Color3.fromRGB(240, 245, 255),
		DisplayName = "Chrome Knife",
		Description = "Mirror-finish steel.",
	},
	{
		Id = "knife_ember",
		Name = "Ember Fang",
		Category = "KnifeSkin",
		Price = 275,
		HandleColor = Color3.fromRGB(50, 28, 18),
		TipColor = Color3.fromRGB(255, 140, 40),
		DisplayName = "Ember Knife",
		Description = "Smoldering orange blade.",
	},
	-- Trails (color applied to character Trail on match start)
	{
		Id = "trail_none",
		Name = "No Trail",
		Category = "Trail",
		Price = 0,
		Default = true,
		TrailColor = Color3.fromRGB(255, 255, 255),
		TrailEnabled = false,
		Description = "No movement trail.",
	},
	{
		Id = "trail_cyan",
		Name = "Cyan Wake",
		Category = "Trail",
		Price = 125,
		TrailColor = Color3.fromRGB(60, 200, 255),
		TrailEnabled = true,
		Description = "Bright cyan movement trail.",
	},
	{
		Id = "trail_gold",
		Name = "Gold Wake",
		Category = "Trail",
		Price = 200,
		TrailColor = Color3.fromRGB(255, 200, 60),
		TrailEnabled = true,
		Description = "Golden movement trail.",
	},
	-- Hitmarker styles (client FX tint)
	{
		Id = "hit_default",
		Name = "Classic X",
		Category = "Hitmarker",
		Price = 0,
		Default = true,
		HitColor = Color3.fromRGB(255, 255, 255),
		HitHeadColor = Color3.fromRGB(255, 70, 70),
		Description = "Standard white hitmarker.",
	},
	{
		Id = "hit_lime",
		Name = "Lime Confirm",
		Category = "Hitmarker",
		Price = 100,
		HitColor = Color3.fromRGB(120, 255, 80),
		HitHeadColor = Color3.fromRGB(255, 220, 40),
		Description = "Lime body / yellow head.",
	},
	{
		Id = "hit_magenta",
		Name = "Magenta Pulse",
		Category = "Hitmarker",
		Price = 150,
		HitColor = Color3.fromRGB(255, 80, 200),
		HitHeadColor = Color3.fromRGB(255, 40, 120),
		Description = "Hot magenta markers.",
	},
	-- Lobby / match titles (Billboard above head)
	{
		Id = "title_none",
		Name = "No Title",
		Category = "Title",
		Price = 0,
		Default = true,
		TitleText = "",
		TitleColor = Color3.fromRGB(200, 200, 210),
		Description = "No title above your name.",
	},
	{
		Id = "title_rookie",
		Name = "Rookie",
		Category = "Title",
		Price = 50,
		TitleText = "ROOKIE",
		TitleColor = Color3.fromRGB(140, 180, 220),
		Description = "Starter lobby title.",
	},
	{
		Id = "title_chamber",
		Name = "One Chamber",
		Category = "Title",
		Price = 175,
		TitleText = "ONE CHAMBER",
		TitleColor = Color3.fromRGB(255, 180, 80),
		Description = "OITC-flavored title.",
	},
	{
		Id = "title_ace",
		Name = "Ace",
		Category = "Title",
		Price = 300,
		TitleText = "ACE",
		TitleColor = Color3.fromRGB(255, 220, 80),
		Description = "Gold Ace title.",
	},
}

function Config.GetShopItem(id: string): any?
	for _, item in Config.ShopItems do
		if item.Id == id then
			return item
		end
	end
	return nil
end

function Config.GetShopItemsByCategory(category: string): { any }
	local list = {}
	for _, item in Config.ShopItems do
		if item.Category == category then
			table.insert(list, item)
		end
	end
	return list
end

function Config.GetDefaultShopIds(): { [string]: string }
	local defaults = {
		PistolSkin = "pistol_default",
		KnifeSkin = "knife_default",
		Trail = "trail_none",
		Hitmarker = "hit_default",
		Title = "title_none",
	}
	for _, item in Config.ShopItems do
		if item.Default == true and defaults[item.Category] == nil then
			defaults[item.Category] = item.Id
		elseif item.Default == true then
			defaults[item.Category] = item.Id
		end
	end
	return defaults
end

-- Tuned volumes + knife whoosh / door
Config.SoundIds.KnifeWhoosh = "rbxassetid://9113895097"
Config.SoundIds.Door = "rbxassetid://9113895097"
Config.SoundVolumes.Fire = 0.48
Config.SoundVolumes.FireAlt = 0.22
Config.SoundVolumes.Reload = 0.45
Config.SoundVolumes.Empty = 0.4
Config.SoundVolumes.HitConfirm = 0.5
Config.SoundVolumes.Headshot = 0.65
Config.SoundVolumes.Melee = 0.55
Config.SoundVolumes.KnifeWhoosh = 0.35
Config.SoundVolumes.Door = 0.28
Config.SoundVolumes.RoundStart = 0.5
Config.SoundVolumes.CountdownTick = 0.35
Config.SoundVolumes.CountdownGo = 0.65
Config.SoundVolumes.MatchLoop = 0.18
Config.SoundVolumes.WinSting = 0.6

-- Match lighting / post (gentle, keep CQC readable)
Config.Lighting.Post = {
	ColorCorrection = {
		Brightness = 0.02,
		Contrast = 0.08,
		Saturation = 0.05,
		TintColor = Color3.fromRGB(245, 248, 255),
	},
	Bloom = {
		Intensity = 0.35,
		Size = 18,
		Threshold = 1.1,
	},
}

-- Extra remotes for shop / data
Config.Remotes.GetShop = "GetShop"
Config.Remotes.PurchaseItem = "PurchaseItem"
Config.Remotes.EquipItem = "EquipItem"
Config.Remotes.CreditsUpdate = "CreditsUpdate"
Config.Remotes.PlayerDataSync = "PlayerDataSync"
Config.Remotes.ShopResult = "ShopResult"

Config.Feel.HitMarkerSeconds = 0.14
Config.Feel.HeadshotMarkerSeconds = 0.2
Config.Feel.DamageFlashSeconds = 0.18
Config.Feel.DamageFlashTransparency = 0.72

return Config
