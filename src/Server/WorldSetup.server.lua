--!strict
--[[
	Builds a readable CQC arena: varied floor, walls + trim, 8–12 cover pieces
	(low walls, crates, L-shapes) that block raycasts, spawn pads, outdoor lighting.
	Safe to run on an empty Baseplate. Leaves movement lanes open.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local arena = Config.Arena
local half = arena.Size / 2
local floorY = arena.FloorY

local folder = Instance.new("Folder")
folder.Name = "CQCArena"
folder.Parent = workspace

local function makePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	parent: Instance?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = true
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or folder
	return p
end

-- Clear default baseplate / spawn so we don't float above missing geometry
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	baseplate:Destroy()
end
local spawnLoc = workspace:FindFirstChild("SpawnLocation")
if spawnLoc then
	spawnLoc:Destroy()
end

-- Outdoor-ish lighting
local lit = Config.Lighting
Lighting.Ambient = lit.Ambient
Lighting.OutdoorAmbient = lit.OutdoorAmbient
Lighting.Brightness = lit.Brightness
Lighting.ClockTime = lit.ClockTime
Lighting.GeographicLatitude = lit.GeographicLatitude
Lighting.GlobalShadows = true
pcall(function()
	Lighting.EnvironmentDiffuseScale = 0.85
	Lighting.EnvironmentSpecularScale = 0.4
end)

-- Main floor
makePart(
	"Floor",
	Vector3.new(arena.Size, 2, arena.Size),
	CFrame.new(0, floorY - 1, 0),
	Color3.fromRGB(48, 52, 58),
	Enum.Material.Slate
)

-- Floor color / material variation tiles (slightly raised decorative, still walkable)
local tileFolder = Instance.new("Folder")
tileFolder.Name = "FloorTiles"
tileFolder.Parent = folder
local tileColors = {
	Color3.fromRGB(62, 66, 72),
	Color3.fromRGB(52, 58, 64),
	Color3.fromRGB(70, 68, 60),
	Color3.fromRGB(55, 60, 68),
}
local tileMats = {
	Enum.Material.Concrete,
	Enum.Material.Slate,
	Enum.Material.Basalt,
	Enum.Material.Asphalt,
}
local tileSize = 12
local tileHalf = math.floor(half / tileSize) * tileSize
for x = -tileHalf + tileSize / 2, tileHalf, tileSize do
	for z = -tileHalf + tileSize / 2, tileHalf, tileSize do
		local idx = (math.floor(x / tileSize) + math.floor(z / tileSize)) % 4
		if idx < 0 then
			idx += 4
		end
		-- Checker of thin overlays (visual only; main Floor collides)
		local overlay = makePart(
			string.format("Tile_%d_%d", x, z),
			Vector3.new(tileSize - 0.4, 0.15, tileSize - 0.4),
			CFrame.new(x, floorY + 0.08, z),
			tileColors[idx + 1],
			tileMats[idx + 1],
			tileFolder
		)
		overlay.CanCollide = false
		overlay.CanQuery = false
	end
end

-- Outer walls
local t = arena.WallThickness
local h = arena.WallHeight
local wallColor = Color3.fromRGB(72, 76, 86)
local trimColor = Color3.fromRGB(110, 115, 128)
makePart("WallNorth", Vector3.new(arena.Size + t * 2, h, t), CFrame.new(0, h / 2, -half), wallColor)
makePart("WallSouth", Vector3.new(arena.Size + t * 2, h, t), CFrame.new(0, h / 2, half), wallColor)
makePart("WallWest", Vector3.new(t, h, arena.Size), CFrame.new(-half, h / 2, 0), wallColor)
makePart("WallEast", Vector3.new(t, h, arena.Size), CFrame.new(half, h / 2, 0), wallColor)

-- Wall top trim (visual rim)
makePart(
	"TrimNorth",
	Vector3.new(arena.Size + t * 2 + 1, 0.6, t + 0.8),
	CFrame.new(0, h + 0.1, -half),
	trimColor,
	Enum.Material.Metal
)
makePart(
	"TrimSouth",
	Vector3.new(arena.Size + t * 2 + 1, 0.6, t + 0.8),
	CFrame.new(0, h + 0.1, half),
	trimColor,
	Enum.Material.Metal
)
makePart(
	"TrimWest",
	Vector3.new(t + 0.8, 0.6, arena.Size + 1),
	CFrame.new(-half, h + 0.1, 0),
	trimColor,
	Enum.Material.Metal
)
makePart(
	"TrimEast",
	Vector3.new(t + 0.8, 0.6, arena.Size + 1),
	CFrame.new(half, h + 0.1, 0),
	trimColor,
	Enum.Material.Metal
)

-- Corner pillars
local pillarColor = Color3.fromRGB(58, 62, 72)
for _, corner in {
	Vector3.new(-half + 2, 0, -half + 2),
	Vector3.new(half - 2, 0, -half + 2),
	Vector3.new(-half + 2, 0, half - 2),
	Vector3.new(half - 2, 0, half - 2),
} do
	makePart(
		"Pillar",
		Vector3.new(3, h, 3),
		CFrame.new(corner.X, h / 2, corner.Z),
		pillarColor,
		Enum.Material.Concrete
	)
end

--[[
	Cover layout — designed, not random.
	All CanCollide + CanQuery so they block movement AND raycasts.
	Heights: low walls ~3.5 (peek), crates ~4–5, L-shapes give corners.
	Lanes kept open along ±X / ±Z corridors and center.
]]
local coverFolder = Instance.new("Folder")
coverFolder.Name = "Cover"
coverFolder.Parent = folder

local wood = Color3.fromRGB(118, 88, 48)
local woodDark = Color3.fromRGB(90, 68, 40)
local concreteLow = Color3.fromRGB(95, 98, 108)
local metalCrate = Color3.fromRGB(80, 88, 98)

local function coverPart(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?)
	return makePart(name, size, cf, color, mat or Enum.Material.Wood, coverFolder)
end

local function placeCrate(name: string, x: number, z: number, size: Vector3, yaw: number?)
	local y = floorY + size.Y / 2
	return coverPart(name, size, CFrame.new(x, y, z) * CFrame.Angles(0, yaw or 0, 0), wood, Enum.Material.Wood)
end

local function placeLowWall(name: string, x: number, z: number, length: number, yaw: number)
	local height = 3.4
	local thickness = 1.6
	local y = floorY + height / 2
	return coverPart(
		name,
		Vector3.new(length, height, thickness),
		CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0),
		concreteLow,
		Enum.Material.Concrete
	)
end

local function placeLCover(name: string, x: number, z: number, yaw: number)
	-- Two segments forming an L; opens toward center when yaw=0
	local hgt = 4.2
	local long = 8
	local short = 5
	local thick = 1.8
	local y = floorY + hgt / 2
	local base = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	coverPart(name .. "_A", Vector3.new(long, hgt, thick), base, woodDark, Enum.Material.Wood)
	coverPart(
		name .. "_B",
		Vector3.new(thick, hgt, short),
		base * CFrame.new(long / 2 - thick / 2, 0, short / 2 - thick / 2),
		woodDark,
		Enum.Material.Wood
	)
end

-- 1–4: corner-ish L covers (facing inward), leave mid lanes
placeLCover("L_NE", 28, -28, math.rad(180))
placeLCover("L_NW", -28, -28, math.rad(-90))
placeLCover("L_SE", 28, 28, math.rad(90))
placeLCover("L_SW", -28, 28, 0)

-- 5–8: low walls forming mid-field peek spots (not a full barrier)
placeLowWall("LowWall_N", 0, -18, 14, 0)
placeLowWall("LowWall_S", 0, 18, 14, 0)
placeLowWall("LowWall_W", -18, 0, 12, math.rad(90))
placeLowWall("LowWall_E", 18, 0, 12, math.rad(90))

-- 9–11: crate clusters (stacked visual via two sizes)
placeCrate("Crate_A1", 12, -8, Vector3.new(5, 4.5, 5), math.rad(15))
placeCrate("Crate_B1", -14, 10, Vector3.new(6, 5, 4.5), math.rad(40))
placeCrate("Crate_D1", 22, 10, Vector3.new(5, 3.8, 5), math.rad(-30))

-- Extra metal box near center-east for variety (12th piece)
coverPart(
	"MetalBox_CenterE",
	Vector3.new(4, 3.2, 7),
	CFrame.new(8, floorY + 1.6, 6) * CFrame.Angles(0, math.rad(25), 0),
	metalCrate,
	Enum.Material.Metal
)

-- Center stays relatively open for CQC; small decorative plate only
makePart(
	"CenterMark",
	Vector3.new(8, 0.12, 8),
	CFrame.new(0, floorY + 0.1, 0),
	Color3.fromRGB(70, 90, 110),
	Enum.Material.Neon
).CanCollide = false

-- Spawn pads + SpawnLocations (on floor, not floating)
local spawnFolder = Instance.new("Folder")
spawnFolder.Name = "SpawnPoints"
spawnFolder.Parent = folder

local spawnOffsets = {
	Vector3.new(-half + 12, 0, -half + 12),
	Vector3.new(half - 12, 0, -half + 12),
	Vector3.new(-half + 12, 0, half - 12),
	Vector3.new(half - 12, 0, half - 12),
	Vector3.new(0, 0, -half + 14), -- mid-north
}

for i, offset in spawnOffsets do
	local padY = floorY + 0.25
	local pad = makePart(
		"SpawnPad" .. i,
		Vector3.new(7, 0.35, 7),
		CFrame.new(offset.X, padY, offset.Z),
		Color3.fromRGB(35, 130, 85),
		Enum.Material.Neon,
		spawnFolder
	)
	pad.CanCollide = true

	-- Thin ring trim
	makePart(
		"SpawnRing" .. i,
		Vector3.new(8.2, 0.15, 8.2),
		CFrame.new(offset.X, padY - 0.1, offset.Z),
		Color3.fromRGB(30, 90, 60),
		Enum.Material.SmoothPlastic,
		spawnFolder
	)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn" .. i
	spawn.Size = Vector3.new(6, 1, 6)
	-- Top of pad: FloorY + pad height/2 + spawn half ≈ FloorY + 0.25 + 0.175 + 0.5
	spawn.CFrame = CFrame.new(offset.X, floorY + 1.1, offset.Z)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Transparency = 0.35
	spawn.BrickColor = BrickColor.new("Bright green")
	spawn.Material = Enum.Material.Neon
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = spawnFolder
end

-- Soft fill light on floor (backup if Lighting is dark)
local fill = Instance.new("PointLight")
fill.Name = "ArenaFill"
fill.Brightness = 0.35
fill.Range = 80
fill.Color = Color3.fromRGB(220, 225, 240)
local floorPart = folder:FindFirstChild("Floor")
if floorPart then
	fill.Parent = floorPart
end

print("[CQCArena] World setup complete — cover + spawns + lighting.")
