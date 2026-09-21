--!strict
--[[
	Builds a small enclosed CQC arena: floor, walls, cover crates, spawn pads.
	Safe to run on an empty Baseplate.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local arena = Config.Arena
local half = arena.Size / 2
local folder = Instance.new("Folder")
folder.Name = "CQCArena"
folder.Parent = workspace

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.CanCollide = true
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

-- Clear default baseplate if present (optional courtesy)
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	baseplate:Destroy()
end
local spawnLoc = workspace:FindFirstChild("SpawnLocation")
if spawnLoc then
	spawnLoc:Destroy()
end

-- Floor
makePart(
	"Floor",
	Vector3.new(arena.Size, 2, arena.Size),
	CFrame.new(0, arena.FloorY - 1, 0),
	Color3.fromRGB(55, 58, 65),
	Enum.Material.Slate
)

-- Walls (N S E W)
local t = arena.WallThickness
local h = arena.WallHeight
local wallColor = Color3.fromRGB(70, 74, 82)
makePart("WallNorth", Vector3.new(arena.Size + t * 2, h, t), CFrame.new(0, h / 2, -half), wallColor)
makePart("WallSouth", Vector3.new(arena.Size + t * 2, h, t), CFrame.new(0, h / 2, half), wallColor)
makePart("WallWest", Vector3.new(t, h, arena.Size), CFrame.new(-half, h / 2, 0), wallColor)
makePart("WallEast", Vector3.new(t, h, arena.Size), CFrame.new(half, h / 2, 0), wallColor)

-- Cover crates
local rng = Random.new(42)
local coverColor = Color3.fromRGB(120, 90, 50)
for i = 1, arena.CoverCount do
	local x = rng:NextNumber(-half + 12, half - 12)
	local z = rng:NextNumber(-half + 12, half - 12)
	-- Keep center somewhat clear
	if math.abs(x) < 8 and math.abs(z) < 8 then
		x += 14
	end
	local size = arena.CoverSize
	makePart(
		"Cover" .. i,
		size,
		CFrame.new(x, arena.FloorY + size.Y / 2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		coverColor,
		Enum.Material.Wood
	)
end

-- Spawn points (pads + SpawnLocation)
local spawnFolder = Instance.new("Folder")
spawnFolder.Name = "SpawnPoints"
spawnFolder.Parent = folder

local spawnOffsets = {
	Vector3.new(-half + 10, arena.SpawnHeight, -half + 10),
	Vector3.new(half - 10, arena.SpawnHeight, -half + 10),
	Vector3.new(-half + 10, arena.SpawnHeight, half - 10),
	Vector3.new(half - 10, arena.SpawnHeight, half - 10),
	Vector3.new(0, arena.SpawnHeight, 0),
}

for i, offset in spawnOffsets do
	local pad = makePart(
		"SpawnPad" .. i,
		Vector3.new(6, 0.4, 6),
		CFrame.new(offset.X, arena.FloorY + 0.2, offset.Z),
		Color3.fromRGB(40, 120, 80),
		Enum.Material.Neon
	)
	pad.Parent = spawnFolder

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn" .. i
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(offset.X, arena.FloorY + 1, offset.Z)
	spawn.Anchored = true
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Transparency = 0.4
	spawn.BrickColor = BrickColor.new("Bright green")
	spawn.Parent = spawnFolder
end

-- Ambient lighting cue
local light = Instance.new("PointLight")
light.Brightness = 0.4
light.Range = 60
light.Parent = folder:FindFirstChild("Floor")

print("[CQCArena] World setup complete.")
