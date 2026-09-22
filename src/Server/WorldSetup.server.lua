--!strict
--[[
	Builds a CQC room complex: grid of square rooms with doorways,
	server-tweened doors (E-key / BillboardGui hint, no ProximityPrompt), waist-high half-walls / crawl gaps, per-room lighting,
	varied floor colors, spawn in start room, NPC spawn markers.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local DoorService = require(script.Parent:WaitForChild("Modules"):WaitForChild("DoorService"))

local map = Config.Map
local floorY = map.FloorY
local roomSize = map.RoomSize
local wallH = map.WallHeight
local wallT = map.WallThickness
local doorW = map.DoorWidth
local doorH = map.DoorHeight
local cols = map.GridCols
local rows = map.GridRows

-- Pitch between room centers (= room size; shared walls)
local pitch = roomSize

DoorService.Init()

local folder = Instance.new("Folder")
folder.Name = "CQCArena"
folder.Parent = workspace

local roomsFolder = Instance.new("Folder")
roomsFolder.Name = "Rooms"
roomsFolder.Parent = folder

local doorsFolder = Instance.new("Folder")
doorsFolder.Name = "Doors"
doorsFolder.Parent = folder

local coverFolder = Instance.new("Folder")
coverFolder.Name = "Cover"
coverFolder.Parent = folder

local spawnFolder = Instance.new("Folder")
spawnFolder.Name = "SpawnPoints"
spawnFolder.Parent = folder

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

-- Clear default baseplate / spawn
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	baseplate:Destroy()
end
local spawnLoc = workspace:FindFirstChild("SpawnLocation")
if spawnLoc then
	spawnLoc:Destroy()
end

-- Indoor lighting
local lit = Config.Lighting
Lighting.Ambient = lit.Ambient
Lighting.OutdoorAmbient = lit.OutdoorAmbient
Lighting.Brightness = lit.Brightness
Lighting.ClockTime = lit.ClockTime
Lighting.GeographicLatitude = lit.GeographicLatitude
Lighting.GlobalShadows = true
pcall(function()
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.25
end)

-- Gentle post for readable CQC
local post = Config.Lighting.Post
if post then
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "CQCColorCorrection"
		cc.Parent = Lighting
	end
	if post.ColorCorrection then
		cc.Brightness = post.ColorCorrection.Brightness or 0.02
		cc.Contrast = post.ColorCorrection.Contrast or 0.08
		cc.Saturation = post.ColorCorrection.Saturation or 0.05
		cc.TintColor = post.ColorCorrection.TintColor or Color3.fromRGB(245, 248, 255)
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "CQCBloom"
		bloom.Parent = Lighting
	end
	if post.Bloom then
		bloom.Intensity = post.Bloom.Intensity or 0.35
		bloom.Size = post.Bloom.Size or 18
		bloom.Threshold = post.Bloom.Threshold or 1.1
	end
end

--[[
	Distinct per-room art themes (colors, materials, lamps, trim, floor pattern).
	Gameplay (doors / half-walls / spawns) unchanged.
]]
local roomThemes = {
	{ -- 1,1 START — briefing blue
		Name = "Briefing",
		Floor = Color3.fromRGB(48, 58, 78),
		FloorMat = Enum.Material.DiamondPlate,
		FloorAccent = Color3.fromRGB(70, 110, 180),
		Wall = Color3.fromRGB(72, 82, 102),
		WallInner = Color3.fromRGB(58, 68, 88),
		Trim = Color3.fromRGB(120, 160, 220),
		Ceiling = Color3.fromRGB(32, 38, 52),
		Lamp = Color3.fromRGB(180, 210, 255),
		LampBright = 2.0,
	},
	{ -- 1,2 — locker green
		Name = "Lockers",
		Floor = Color3.fromRGB(42, 58, 48),
		FloorMat = Enum.Material.Slate,
		FloorAccent = Color3.fromRGB(60, 140, 90),
		Wall = Color3.fromRGB(58, 78, 68),
		WallInner = Color3.fromRGB(48, 64, 56),
		Trim = Color3.fromRGB(90, 180, 120),
		Ceiling = Color3.fromRGB(28, 36, 32),
		Lamp = Color3.fromRGB(200, 255, 210),
		LampBright = 1.7,
	},
	{ -- 1,3 — server / cold
		Name = "Server",
		Floor = Color3.fromRGB(40, 48, 58),
		FloorMat = Enum.Material.Metal,
		FloorAccent = Color3.fromRGB(80, 200, 255),
		Wall = Color3.fromRGB(50, 60, 72),
		WallInner = Color3.fromRGB(40, 50, 62),
		Trim = Color3.fromRGB(60, 180, 220),
		Ceiling = Color3.fromRGB(24, 28, 36),
		Lamp = Color3.fromRGB(140, 220, 255),
		LampBright = 1.9,
	},
	{ -- 2,1 — armory warm
		Name = "Armory",
		Floor = Color3.fromRGB(72, 52, 42),
		FloorMat = Enum.Material.Concrete,
		FloorAccent = Color3.fromRGB(200, 120, 60),
		Wall = Color3.fromRGB(88, 68, 58),
		WallInner = Color3.fromRGB(72, 54, 46),
		Trim = Color3.fromRGB(220, 150, 70),
		Ceiling = Color3.fromRGB(40, 30, 26),
		Lamp = Color3.fromRGB(255, 210, 150),
		LampBright = 1.8,
	},
	{ -- 2,2 CENTER — ops orange
		Name = "Ops",
		Floor = Color3.fromRGB(58, 50, 42),
		FloorMat = Enum.Material.DiamondPlate,
		FloorAccent = Color3.fromRGB(255, 140, 50),
		Wall = Color3.fromRGB(70, 62, 52),
		WallInner = Color3.fromRGB(58, 50, 42),
		Trim = Color3.fromRGB(255, 160, 60),
		Ceiling = Color3.fromRGB(36, 32, 28),
		Lamp = Color3.fromRGB(255, 190, 120),
		LampBright = 2.1,
	},
	{ -- 2,3 — med bay white/cyan
		Name = "MedBay",
		Floor = Color3.fromRGB(200, 210, 220),
		FloorMat = Enum.Material.SmoothPlastic,
		FloorAccent = Color3.fromRGB(80, 200, 200),
		Wall = Color3.fromRGB(210, 220, 230),
		WallInner = Color3.fromRGB(190, 200, 210),
		Trim = Color3.fromRGB(60, 180, 190),
		Ceiling = Color3.fromRGB(230, 235, 240),
		Lamp = Color3.fromRGB(230, 255, 255),
		LampBright = 2.2,
	},
	{ -- 3,1 — storage wood
		Name = "Storage",
		Floor = Color3.fromRGB(78, 62, 42),
		FloorMat = Enum.Material.WoodPlanks,
		FloorAccent = Color3.fromRGB(160, 110, 50),
		Wall = Color3.fromRGB(92, 78, 58),
		WallInner = Color3.fromRGB(78, 64, 48),
		Trim = Color3.fromRGB(180, 140, 70),
		Ceiling = Color3.fromRGB(50, 42, 32),
		Lamp = Color3.fromRGB(255, 220, 160),
		LampBright = 1.6,
	},
	{ -- 3,2 — range dark
		Name = "Range",
		Floor = Color3.fromRGB(36, 38, 42),
		FloorMat = Enum.Material.Asphalt,
		FloorAccent = Color3.fromRGB(220, 60, 60),
		Wall = Color3.fromRGB(48, 50, 56),
		WallInner = Color3.fromRGB(38, 40, 46),
		Trim = Color3.fromRGB(200, 70, 70),
		Ceiling = Color3.fromRGB(22, 24, 28),
		Lamp = Color3.fromRGB(255, 180, 160),
		LampBright = 1.5,
	},
	{ -- 3,3 — vault purple
		Name = "Vault",
		Floor = Color3.fromRGB(48, 40, 62),
		FloorMat = Enum.Material.Metal,
		FloorAccent = Color3.fromRGB(160, 80, 255),
		Wall = Color3.fromRGB(58, 48, 78),
		WallInner = Color3.fromRGB(46, 38, 64),
		Trim = Color3.fromRGB(170, 100, 255),
		Ceiling = Color3.fromRGB(28, 22, 40),
		Lamp = Color3.fromRGB(200, 160, 255),
		LampBright = 1.9,
	},
}

local wallColor = Color3.fromRGB(90, 94, 104)
local wallInner = Color3.fromRGB(78, 82, 92)
local trimColor = Color3.fromRGB(120, 124, 136)
local doorColor = Color3.fromRGB(110, 70, 45)
local halfWallColor = Color3.fromRGB(95, 98, 108)
local crawlColor = Color3.fromRGB(70, 74, 84)

local function themeFor(col: number, row: number)
	local idx = ((col - 1) + (row - 1) * cols) % #roomThemes + 1
	return roomThemes[idx]
end

local function addFloorPattern(roomFolder: Folder, center: Vector3, theme: any)
	-- Checker / stripe accents (non-colliding) for readable CQC floors
	local tile = 4
	local half = roomSize / 2 - 1.5
	local accent = theme.FloorAccent :: Color3
	local base = theme.Floor :: Color3
	local n = 0
	for x = -half, half, tile do
		for z = -half, half, tile do
			n += 1
			if (math.floor((x + half) / tile) + math.floor((z + half) / tile)) % 2 == 0 then
				local p = makePart(
					"FloorTile" .. n,
					Vector3.new(tile - 0.35, 0.06, tile - 0.35),
					CFrame.new(center.X + x, floorY + 0.08, center.Z + z),
					accent:Lerp(base, 0.55),
					Enum.Material.SmoothPlastic,
					roomFolder
				)
				p.CanCollide = false
				p.CanQuery = false
				p.Transparency = 0.35
			end
		end
	end
	-- Center accent disc
	local disc = makePart(
		"FloorCenter",
		Vector3.new(6, 0.08, 6),
		CFrame.new(center.X, floorY + 0.1, center.Z),
		accent,
		Enum.Material.Neon,
		roomFolder
	)
	disc.CanCollide = false
	disc.CanQuery = false
	disc.Transparency = 0.55
end

local function addCeilingLamp(roomFolder: Folder, center: Vector3, theme: any)
	-- Fixture housing
	local housing = makePart(
		"LampHousing",
		Vector3.new(3.2, 0.35, 1.4),
		CFrame.new(center.X, floorY + wallH - 0.4, center.Z),
		Color3.fromRGB(40, 44, 52),
		Enum.Material.Metal,
		roomFolder
	)
	housing.CanCollide = false
	housing.CanQuery = false
	-- Neon tube
	local tube = makePart(
		"LampTube",
		Vector3.new(2.8, 0.22, 0.55),
		CFrame.new(center.X, floorY + wallH - 0.55, center.Z),
		theme.Lamp,
		Enum.Material.Neon,
		roomFolder
	)
	tube.CanCollide = false
	tube.CanQuery = false
	local pl = Instance.new("PointLight")
	pl.Brightness = theme.LampBright or 1.8
	pl.Range = roomSize * 0.9
	pl.Color = theme.Lamp
	pl.Parent = tube
	-- Soft fill
	local fill = Instance.new("SpotLight")
	fill.Brightness = 0.8
	fill.Range = roomSize
	fill.Angle = 90
	fill.Face = Enum.NormalId.Bottom
	fill.Color = theme.Lamp
	fill.Parent = tube
end

local function addWallTrim(roomFolder: Folder, center: Vector3, theme: any)
	local half = roomSize / 2
	local trimH = 0.35
	local y = floorY + 3.2
	local tcol = theme.Trim
	-- Mid-wall rail strips (N/S/E/W), non-blocking
	local rails = {
		{ Vector3.new(roomSize - 2, trimH, 0.2), Vector3.new(center.X, y, center.Z - half + 0.35) },
		{ Vector3.new(roomSize - 2, trimH, 0.2), Vector3.new(center.X, y, center.Z + half - 0.35) },
		{ Vector3.new(0.2, trimH, roomSize - 2), Vector3.new(center.X - half + 0.35, y, center.Z) },
		{ Vector3.new(0.2, trimH, roomSize - 2), Vector3.new(center.X + half - 0.35, y, center.Z) },
	}
	for i, rail in rails do
		local p = makePart("WallTrim" .. i, rail[1], CFrame.new(rail[2]), tcol, Enum.Material.Metal, roomFolder)
		p.CanCollide = false
		p.CanQuery = false
	end
	-- Baseboard
	local baseY = floorY + 0.35
	for i, rail in rails do
		local size = Vector3.new(rail[1].X, 0.5, rail[1].Z)
		local pos = Vector3.new(rail[2].X, baseY, rail[2].Z)
		local p = makePart("Baseboard" .. i, size, CFrame.new(pos), tcol:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.SmoothPlastic, roomFolder)
		p.CanCollide = false
		p.CanQuery = false
	end
end

local function roomCenter(col: number, row: number): Vector3
	-- col/row 1-based; origin at room (1,1) center
	local x = (col - 1) * pitch
	local z = (row - 1) * pitch
	return Vector3.new(x, floorY, z)
end

local function roomKey(col: number, row: number): string
	return string.format("%d_%d", col, row)
end

local function inList(list: { { number } }, col: number, row: number): boolean
	for _, pair in list do
		if pair[1] == col and pair[2] == row then
			return true
		end
	end
	return false
end

-- Build each room: floor, ceiling, 4 walls with doorway gaps toward neighbors
local roomCenters: { [string]: Vector3 } = {}
local doorIdCounter = 0

local function wallSegmentsWithDoor(
	roomFolder: Folder,
	namePrefix: string,
	-- wall runs along axis; center of full wall edge
	edgeCenter: Vector3,
	along: Vector3, -- unit along wall length
	outward: Vector3, -- unit outward (thickness)
	fullLength: number,
	hasDoor: boolean
)
	--[[
		Full wall length = roomSize. If hasDoor, leave doorW gap in the middle
		and place two side segments + optional lintel above door.
	]]
	local yMid = floorY + wallH / 2
	local thick = wallT

	if not hasDoor then
		makePart(
			namePrefix,
			Vector3.new(
				if math.abs(along.X) > 0.5 then fullLength else thick,
				wallH,
				if math.abs(along.Z) > 0.5 then fullLength else thick
			),
			CFrame.new(edgeCenter.X, yMid, edgeCenter.Z),
			wallColor,
			Enum.Material.Concrete,
			roomFolder
		)
		return
	end

	local sideLen = (fullLength - doorW) / 2
	-- Left segment center: from edge center, move -along * (doorW/2 + sideLen/2)
	local leftCenter = edgeCenter - along * (doorW / 2 + sideLen / 2)
	local rightCenter = edgeCenter + along * (doorW / 2 + sideLen / 2)

	local function segSize(): Vector3
		if math.abs(along.X) > 0.5 then
			return Vector3.new(sideLen, wallH, thick)
		end
		return Vector3.new(thick, wallH, sideLen)
	end

	makePart(namePrefix .. "_L", segSize(), CFrame.new(leftCenter.X, yMid, leftCenter.Z), wallColor, Enum.Material.Concrete, roomFolder)
	makePart(namePrefix .. "_R", segSize(), CFrame.new(rightCenter.X, yMid, rightCenter.Z), wallColor, Enum.Material.Concrete, roomFolder)

	-- Lintel above doorway
	local lintelH = wallH - doorH
	if lintelH > 0.2 then
		local lintelY = floorY + doorH + lintelH / 2
		local lintelSize = if math.abs(along.X) > 0.5
			then Vector3.new(doorW, lintelH, thick)
			else Vector3.new(thick, lintelH, doorW)
		makePart(
			namePrefix .. "_Lintel",
			lintelSize,
			CFrame.new(edgeCenter.X, lintelY, edgeCenter.Z),
			wallInner,
			Enum.Material.Concrete,
			roomFolder
		)
	end
end

local function createDoor(
	id: string,
	hingeWorld: CFrame,
	closedCFrame: CFrame,
	size: Vector3
)
	local door = makePart("Door_" .. id, size, closedCFrame, doorColor, Enum.Material.Wood, doorsFolder)
	door.CanCollide = true
	door.CanQuery = true

	-- Hinge marker at hinge world position (relative to door part)
	local hinge = Instance.new("Attachment")
	hinge.Name = "Hinge"
	hinge.Parent = door
	hinge.WorldCFrame = hingeWorld

	-- Non-Active BillboardGui hint — no GuiButton / no mouse capture (FPS LockCenter safe)
	local hintMax = map.DoorHintMaxDistance or 10
	local bb = Instance.new("BillboardGui")
	bb.Name = "DoorHint"
	bb.Size = UDim2.fromOffset(110, 36)
	bb.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.15, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = hintMax
	bb.Active = false
	bb.ResetOnSpawn = false
	bb.Parent = door

	local label = Instance.new("TextLabel")
	label.Name = "Hint"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
	label.BackgroundTransparency = 0.35
	label.BorderSizePixel = 0
	label.Text = "[E] Open"
	label.TextColor3 = Color3.fromRGB(230, 235, 245)
	label.TextStrokeTransparency = 0.55
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Active = false
	label.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = label

	-- Directional open: DoorService picks ±angle from triggering player side
	DoorService.RegisterDoor(
		id,
		door,
		hingeWorld,
		closedCFrame,
		math.rad(map.DoorOpenAngleDegrees),
		label
	)
end

--[[
	For shared walls between rooms: only the lower-index room builds the wall+door,
	so we don't double thickness. Outer perimeter always built by that room.
]]
local builtEastDoor: { [string]: boolean } = {} -- "col_row" means door on east of that room built
local builtSouthDoor: { [string]: boolean } = {}

for col = 1, cols do
	for row = 1, rows do
		local center = roomCenter(col, row)
		roomCenters[roomKey(col, row)] = center

		local roomFolder = Instance.new("Folder")
		roomFolder.Name = "Room_" .. roomKey(col, row)
		roomFolder.Parent = roomsFolder

		local theme = themeFor(col, row)
		-- Apply theme wall colors for this room's wallSegmentsWithDoor calls
		wallColor = theme.Wall
		wallInner = theme.WallInner
		trimColor = theme.Trim

		-- Floor
		makePart(
			"Floor",
			Vector3.new(roomSize, 1.2, roomSize),
			CFrame.new(center.X, floorY - 0.6, center.Z),
			theme.Floor,
			theme.FloorMat or Enum.Material.Slate,
			roomFolder
		)

		-- Thin plate + pattern
		local plate = makePart(
			"FloorPlate",
			Vector3.new(roomSize - 1, 0.1, roomSize - 1),
			CFrame.new(center.X, floorY + 0.05, center.Z),
			theme.Floor:Lerp(Color3.new(1, 1, 1), 0.06),
			Enum.Material.SmoothPlastic,
			roomFolder
		)
		plate.CanCollide = false
		plate.CanQuery = false
		addFloorPattern(roomFolder, center, theme)

		-- Ceiling
		if map.Ceiling then
			local ceil = makePart(
				"Ceiling",
				Vector3.new(roomSize, 1, roomSize),
				CFrame.new(center.X, floorY + wallH + 0.5, center.Z),
				theme.Ceiling,
				Enum.Material.Concrete,
				roomFolder
			)
			ceil.CanQuery = true
		end

		addCeilingLamp(roomFolder, center, theme)
		addWallTrim(roomFolder, center, theme)

		-- Room label (theme name)
		local labelPart = makePart(
			"Label",
			Vector3.new(0.2, 0.2, 0.2),
			CFrame.new(center.X, floorY + 0.2, center.Z),
			Color3.new(1, 1, 1),
			Enum.Material.SmoothPlastic,
			roomFolder
		)
		labelPart.CanCollide = false
		labelPart.CanQuery = false
		labelPart.Transparency = 1
		local bill = Instance.new("BillboardGui")
		bill.Size = UDim2.fromOffset(140, 28)
		bill.StudsOffset = Vector3.new(0, 3, 0)
		bill.AlwaysOnTop = false
		bill.Parent = labelPart
		local lab = Instance.new("TextLabel")
		lab.Size = UDim2.fromScale(1, 1)
		lab.BackgroundTransparency = 1
		lab.Text = if col == map.StartCol and row == map.StartRow
			then "START · " .. theme.Name
			else theme.Name
		lab.TextColor3 = theme.Trim
		lab.TextStrokeTransparency = 0.45
		lab.Font = Enum.Font.GothamBold
		lab.TextScaled = true
		lab.Parent = bill

		local half = roomSize / 2
		-- Edges: N (-Z), S (+Z), W (-X), E (+X)
		local hasNorthNeighbor = row > 1
		local hasSouthNeighbor = row < rows
		local hasWestNeighbor = col > 1
		local hasEastNeighbor = col < cols

		-- Outer walls always solid (no door). Shared walls: door toward neighbor,
		-- built only by the "owner" room (west room owns east wall, north room owns south wall).
		-- North wall
		do
			local edge = Vector3.new(center.X, floorY, center.Z - half)
			if hasNorthNeighbor then
				-- southern room of the pair is `row`; north neighbor owns the shared wall — skip
				-- actually: room above (row-1) owns south wall. So we skip north wall when neighbor exists.
			else
				wallSegmentsWithDoor(roomFolder, "WallN", edge, Vector3.xAxis, -Vector3.zAxis, roomSize, false)
			end
		end

		-- West wall
		do
			local edge = Vector3.new(center.X - half, floorY, center.Z)
			if not hasWestNeighbor then
				wallSegmentsWithDoor(roomFolder, "WallW", edge, Vector3.zAxis, -Vector3.xAxis, roomSize, false)
			end
		end

		-- East wall (owner of shared wall with east neighbor)
		do
			local edge = Vector3.new(center.X + half, floorY, center.Z)
			local key = roomKey(col, row)
			if hasEastNeighbor then
				wallSegmentsWithDoor(roomFolder, "WallE", edge, Vector3.zAxis, Vector3.xAxis, roomSize, true)
				-- Door in opening — hinge on +Z side; open ±yaw chosen by player side
				doorIdCounter += 1
				local id = string.format("E_%s", key)
				local hingePos = Vector3.new(center.X + half, floorY + doorH / 2, center.Z + doorW / 2 - 0.15)
				-- Door fills opening; thickness along X
				local size = Vector3.new(map.DoorThickness, doorH, doorW - 0.2)
				local hingeCF = CFrame.new(hingePos)
				local closed = hingeCF * CFrame.new(0, 0, -(doorW - 0.2) / 2)
				createDoor(id, hingeCF, closed, size)
				builtEastDoor[key] = true

				-- Prompt-friendly doorframe trim
				makePart(
					"DoorTrimE",
					Vector3.new(wallT + 0.4, 0.4, doorW + 0.6),
					CFrame.new(center.X + half, floorY + doorH + 0.2, center.Z),
					trimColor,
					Enum.Material.Metal,
					roomFolder
				)
			else
				wallSegmentsWithDoor(roomFolder, "WallE", edge, Vector3.zAxis, Vector3.xAxis, roomSize, false)
			end
		end

		-- South wall (owner of shared wall with south neighbor)
		do
			local edge = Vector3.new(center.X, floorY, center.Z + half)
			local key = roomKey(col, row)
			if hasSouthNeighbor then
				wallSegmentsWithDoor(roomFolder, "WallS", edge, Vector3.xAxis, Vector3.zAxis, roomSize, true)
				doorIdCounter += 1
				local id = string.format("S_%s", key)
				local hingePos = Vector3.new(center.X + doorW / 2 - 0.15, floorY + doorH / 2, center.Z + half)
				local size = Vector3.new(doorW - 0.2, doorH, map.DoorThickness)
				local hingeCF = CFrame.new(hingePos)
				local closed = hingeCF * CFrame.new(-(doorW - 0.2) / 2, 0, 0)
				createDoor(id, hingeCF, closed, size)
				builtSouthDoor[key] = true

				makePart(
					"DoorTrimS",
					Vector3.new(doorW + 0.6, 0.4, wallT + 0.4),
					CFrame.new(center.X, floorY + doorH + 0.2, center.Z + half),
					trimColor,
					Enum.Material.Metal,
					roomFolder
				)
			else
				wallSegmentsWithDoor(roomFolder, "WallS", edge, Vector3.xAxis, Vector3.zAxis, roomSize, false)
			end
		end
	end
end

-- Corner pillars at each room corner (shared visually ok)
for col = 1, cols + 1 do
	for row = 1, rows + 1 do
		local x = (col - 1) * pitch - roomSize / 2
		local z = (row - 1) * pitch - roomSize / 2
		makePart(
			"Pillar",
			Vector3.new(wallT + 0.8, wallH, wallT + 0.8),
			CFrame.new(x, floorY + wallH / 2, z),
			Color3.fromRGB(60, 64, 74),
			Enum.Material.Concrete,
			folder
		)
	end
end

-- Half-walls (waist-high, jump over) and crawl gaps
local function addWallTrim(wall: BasePart)
	local trim = makePart(
		wall.Name .. "_Trim",
		Vector3.new(wall.Size.X + 0.15, 0.18, wall.Size.Z + 0.15),
		wall.CFrame * CFrame.new(0, wall.Size.Y / 2 + 0.05, 0),
		trimColor,
		Enum.Material.Metal,
		wall.Parent
	)
	trim.CanCollide = false
end

local halfWallH = 2.8 -- waist-ish; jumpable
local crawlOpenH = 3.0 -- opening height at floor for slide/duck

local function placeHalfWalls(col: number, row: number)
	local c = roomCenter(col, row)
	-- Two waist-high barriers forming a partial lane
	local hwA = makePart(
		"HalfWall_A",
		Vector3.new(10, halfWallH, 1.4),
		CFrame.new(c.X - 4, floorY + halfWallH / 2, c.Z - 5),
		halfWallColor,
		Enum.Material.Concrete,
		coverFolder
	)
	addWallTrim(hwA)
	local hwB = makePart(
		"HalfWall_B",
		Vector3.new(1.4, halfWallH, 10),
		CFrame.new(c.X + 6, floorY + halfWallH / 2, c.Z + 2),
		halfWallColor,
		Enum.Material.Concrete,
		coverFolder
	)
	addWallTrim(hwB)
	-- Low crate
	makePart(
		"Crate",
		Vector3.new(4, 2.5, 4),
		CFrame.new(c.X - 7, floorY + 1.25, c.Z + 7),
		Color3.fromRGB(118, 88, 48),
		Enum.Material.Wood,
		coverFolder
	)
end

local function placeCrawlGap(col: number, row: number)
	local c = roomCenter(col, row)
	-- Barrier with a ~3 stud high floor opening in the middle (two side pillars + top beam)
	local barrierZ = c.Z + 3
	local totalW = 14
	local gapW = 5
	local sideW = (totalW - gapW) / 2
	local topH = 4
	-- Left / right full-height-ish low walls with gap
	makePart(
		"CrawlSideL",
		Vector3.new(sideW, halfWallH + 1.5, 1.5),
		CFrame.new(c.X - gapW / 2 - sideW / 2, floorY + (halfWallH + 1.5) / 2, barrierZ),
		crawlColor,
		Enum.Material.Concrete,
		coverFolder
	)
	makePart(
		"CrawlSideR",
		Vector3.new(sideW, halfWallH + 1.5, 1.5),
		CFrame.new(c.X + gapW / 2 + sideW / 2, floorY + (halfWallH + 1.5) / 2, barrierZ),
		crawlColor,
		Enum.Material.Concrete,
		coverFolder
	)
	-- Top beam leaves crawlOpenH clearance at floor
	makePart(
		"CrawlBeam",
		Vector3.new(gapW, topH, 1.5),
		CFrame.new(c.X, floorY + crawlOpenH + topH / 2, barrierZ),
		crawlColor,
		Enum.Material.Concrete,
		coverFolder
	)
	-- Second half-wall elsewhere in room
	local hwC = makePart(
		"HalfWall_CrawlRoom",
		Vector3.new(8, halfWallH, 1.3),
		CFrame.new(c.X + 2, floorY + halfWallH / 2, c.Z - 8),
		halfWallColor,
		Enum.Material.Concrete,
		coverFolder
	)
	addWallTrim(hwC)

	-- Slide/crawl trigger: briefly lowers HipHeight so players fit under ~3-stud opening
	local trigger = makePart(
		"CrawlTrigger",
		Vector3.new(gapW - 0.5, crawlOpenH - 0.2, 4),
		CFrame.new(c.X, floorY + (crawlOpenH - 0.2) / 2, barrierZ),
		Color3.fromRGB(80, 120, 180),
		Enum.Material.ForceField,
		coverFolder
	)
	trigger.CanCollide = false
	trigger.CanQuery = false
	trigger.Transparency = 0.85
	trigger.Touched:Connect(function(hit)
		local model = hit:FindFirstAncestorOfClass("Model")
		if not model then
			return
		end
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			return
		end
		if hum:GetAttribute("CQCSliding") then
			return
		end
		hum:SetAttribute("CQCSliding", true)
		local prevHip = hum.HipHeight
		local prevSpeed = hum.WalkSpeed
		hum.HipHeight = math.min(prevHip, 0.5)
		hum.WalkSpeed = prevSpeed + 6
		task.delay(0.85, function()
			if hum.Parent then
				hum.HipHeight = prevHip
				hum.WalkSpeed = prevSpeed
				hum:SetAttribute("CQCSliding", nil)
			end
		end)
	end)
end

for _, pair in map.HalfWallRooms do
	placeHalfWalls(pair[1], pair[2])
end
for _, pair in map.CrawlGapRooms do
	placeCrawlGap(pair[1], pair[2])
end

-- Combat teleport pads in start room (NOT Roblox SpawnLocations — lobby owns spawn)
local startCenter = roomCenter(map.StartCol, map.StartRow)
local spawnOffsets = {
	Vector3.new(-6, 0, -6),
	Vector3.new(6, 0, -6),
	Vector3.new(-6, 0, 6),
	Vector3.new(0, 0, 0),
}

for i, offset in spawnOffsets do
	local pos = startCenter + offset
	local padY = floorY + 0.25
	local pad = makePart(
		"SpawnPad" .. i,
		Vector3.new(6, 0.35, 6),
		CFrame.new(pos.X, padY, pos.Z),
		Color3.fromRGB(35, 130, 85),
		Enum.Material.Neon,
		spawnFolder
	)
	pad.CanCollide = true
	pad:SetAttribute("CombatSpawn", true)
end

-- Publish room centers for NPC placement (attribute on folder)
folder:SetAttribute("StartRoomX", startCenter.X)
folder:SetAttribute("StartRoomZ", startCenter.Z)
folder:SetAttribute("RoomPitch", pitch)

-- NPC-friendly world positions (room centers for (3,1), (1,3), (2,2) center — Main uses Config offsets)
-- Update Config-compatible centers via a ModuleScript value folder
local npcMarks = Instance.new("Folder")
npcMarks.Name = "NPCSpawnMarks"
npcMarks.Parent = folder
local npcRooms = {
	{ 3, 1 },
	{ 1, 3 },
	{ 3, 3 },
	{ 2, 2 },
}
for i, pair in npcRooms do
	local c = roomCenter(pair[1], pair[2])
	local mark = Instance.new("Part")
	mark.Name = "NPCMark" .. i
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanQuery = false
	mark.Transparency = 1
	mark.Size = Vector3.new(1, 1, 1)
	mark.Position = Vector3.new(c.X, floorY + Config.Arena.SpawnHeight, c.Z)
	mark.Parent = npcMarks
end

-- Extra bot patrol waypoints (cover corners + mid-doors)
local botWp = Instance.new("Folder")
botWp.Name = "BotWaypoints"
botWp.Parent = folder
local wpIndex = 0
local function addBotWp(pos: Vector3)
	wpIndex += 1
	local mark = Instance.new("Part")
	mark.Name = "BotWP" .. wpIndex
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanQuery = false
	mark.Transparency = 1
	mark.Size = Vector3.new(1, 1, 1)
	mark.Position = Vector3.new(pos.X, floorY + Config.Arena.SpawnHeight, pos.Z)
	mark.Parent = botWp
end
for col = 1, cols do
	for row = 1, rows do
		local c = roomCenter(col, row)
		addBotWp(c + Vector3.new(-8, 0, -8))
		addBotWp(c + Vector3.new(8, 0, 8))
	end
end


--[[
	Dedicated Lobby room — separate from the combat grid so hub players
	cannot free-roam the map or shoot NPCs before StartMatch.
	Only Roblox SpawnLocation lives here.
]]
do
	local lobbyCfg = Config.Lobby
	local lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "Lobby"
	lobbyFolder.Parent = folder

	local lx = lobbyCfg.Offset.X
	local lz = lobbyCfg.Offset.Z
	local ly = lobbyCfg.FloorY
	local rs = lobbyCfg.RoomSize
	local wh = lobbyCfg.WallHeight
	local half = rs / 2

	-- Floor platform
	makePart(
		"LobbyFloor",
		Vector3.new(rs, 1.2, rs),
		CFrame.new(lx, ly - 0.6, lz),
		lobbyCfg.PlatformColor,
		Enum.Material.Slate,
		lobbyFolder
	)
	local plate = makePart(
		"LobbyPlate",
		Vector3.new(rs - 2, 0.12, rs - 2),
		CFrame.new(lx, ly + 0.06, lz),
		Color3.fromRGB(40, 48, 64),
		Enum.Material.SmoothPlastic,
		lobbyFolder
	)
	plate.CanCollide = false
	plate.CanQuery = false

	-- Ceiling
	makePart(
		"LobbyCeiling",
		Vector3.new(rs, 1, rs),
		CFrame.new(lx, ly + wh + 0.5, lz),
		Color3.fromRGB(22, 26, 34),
		Enum.Material.Concrete,
		lobbyFolder
	)

	-- Enclosed walls (no doors to combat)
	local wallCol = Color3.fromRGB(28, 34, 48)
	makePart("LobbyWallN", Vector3.new(rs, wh, 1.5), CFrame.new(lx, ly + wh / 2, lz - half), wallCol, Enum.Material.Concrete, lobbyFolder)
	makePart("LobbyWallS", Vector3.new(rs, wh, 1.5), CFrame.new(lx, ly + wh / 2, lz + half), wallCol, Enum.Material.Concrete, lobbyFolder)
	makePart("LobbyWallW", Vector3.new(1.5, wh, rs), CFrame.new(lx - half, ly + wh / 2, lz), wallCol, Enum.Material.Concrete, lobbyFolder)
	makePart("LobbyWallE", Vector3.new(1.5, wh, rs), CFrame.new(lx + half, ly + wh / 2, lz), wallCol, Enum.Material.Concrete, lobbyFolder)

	-- Accent backdrop wall (menu camera faces this)
	local backdrop = makePart(
		"LobbyBackdrop",
		Vector3.new(rs - 4, wh - 2, 0.6),
		CFrame.new(lx, ly + (wh - 2) / 2 + 1, lz - half + 1.2),
		lobbyCfg.BackdropColor,
		Enum.Material.SmoothPlastic,
		lobbyFolder
	)
	backdrop.CanQuery = false
	local accent = makePart(
		"LobbyAccent",
		Vector3.new(rs - 8, 0.4, 0.65),
		CFrame.new(lx, ly + wh - 2.5, lz - half + 1.2),
		lobbyCfg.AccentColor,
		Enum.Material.Neon,
		lobbyFolder
	)
	accent.CanCollide = false
	accent.CanQuery = false

	-- Soft fill light
	local lightAnchor = makePart(
		"LobbyLight",
		Vector3.new(1.2, 0.4, 1.2),
		CFrame.new(lx, ly + wh - 1.5, lz),
		Color3.fromRGB(180, 210, 255),
		Enum.Material.Neon,
		lobbyFolder
	)
	lightAnchor.CanCollide = false
	lightAnchor.CanQuery = false
	lightAnchor.Transparency = 0.4
	local pl = Instance.new("PointLight")
	pl.Brightness = 2.2
	pl.Range = rs * 0.9
	pl.Color = Color3.fromRGB(200, 220, 255)
	pl.Parent = lightAnchor

	-- Title billboard
	local titlePart = makePart(
		"LobbyTitle",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(lx, ly + 6, lz - half + 2),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		lobbyFolder
	)
	titlePart.Transparency = 1
	titlePart.CanCollide = false
	titlePart.CanQuery = false
	local bill = Instance.new("BillboardGui")
	bill.Size = UDim2.fromOffset(320, 64)
	bill.StudsOffset = Vector3.new(0, 0, 0)
	bill.AlwaysOnTop = false
	bill.Parent = titlePart
	local lab = Instance.new("TextLabel")
	lab.Size = UDim2.fromScale(1, 1)
	lab.BackgroundTransparency = 1
	lab.Text = "LOBBY"
	lab.TextColor3 = Color3.fromRGB(220, 230, 255)
	lab.TextStrokeTransparency = 0.4
	lab.Font = Enum.Font.GothamBold
	lab.TextScaled = true
	lab.Parent = bill

	-- Pad + the only SpawnLocation in the place
	local pad = makePart(
		"LobbyPad",
		Vector3.new(10, 0.4, 10),
		CFrame.new(lx, ly + 0.2, lz + 2),
		Color3.fromRGB(50, 90, 160),
		Enum.Material.Neon,
		lobbyFolder
	)
	pad.CanCollide = true

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(lx, ly + 1.1, lz + 2)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Enabled = true
	spawn.Transparency = 0.4
	spawn.BrickColor = BrickColor.new("Bright blue")
	spawn.Material = Enum.Material.Neon
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobbyFolder

	folder:SetAttribute("LobbyX", lx)
	folder:SetAttribute("LobbyZ", lz)

	-- Weapon showcase stands (Parts only)
	local display = Instance.new("Folder")
	display.Name = "WeaponDisplay"
	display.Parent = lobbyFolder

	local function stand(name: string, pos: Vector3, color: Color3)
		local _base = makePart(
			name .. "Base",
			Vector3.new(2.2, 0.35, 2.2),
			CFrame.new(pos),
			Color3.fromRGB(28, 32, 44),
			Enum.Material.SmoothPlastic,
			display
		)
		local _pillar = makePart(
			name .. "Pillar",
			Vector3.new(0.35, 3.2, 0.35),
			CFrame.new(pos + Vector3.new(0, 1.7, 0)),
			Color3.fromRGB(40, 46, 60),
			Enum.Material.Metal,
			display
		)
		local _plate = makePart(
			name .. "Plate",
			Vector3.new(1.6, 0.12, 0.7),
			CFrame.new(pos + Vector3.new(0, 3.5, 0)) * CFrame.Angles(math.rad(-18), 0, 0),
			color,
			Enum.Material.Neon,
			display
		)
		local labelPart = makePart(
			name .. "LabelAnchor",
			Vector3.new(0.2, 0.2, 0.2),
			CFrame.new(pos + Vector3.new(0, 4.1, 0)),
			Color3.fromRGB(255, 255, 255),
			Enum.Material.SmoothPlastic,
			display
		)
		labelPart.Transparency = 1
		labelPart.CanCollide = false
		local bill = Instance.new("BillboardGui")
		bill.Size = UDim2.fromOffset(120, 28)
		bill.StudsOffset = Vector3.new(0, 0.4, 0)
		bill.AlwaysOnTop = false
		bill.Parent = labelPart
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBold
		t.TextSize = 14
		t.TextColor3 = Color3.fromRGB(220, 230, 245)
		t.TextStrokeTransparency = 0.5
		t.Text = name
		t.Parent = bill
		return plate
	end

	stand("PISTOL", Vector3.new(lx - 6, ly + 0.2, lz - 4), Color3.fromRGB(220, 200, 80))
	stand("KNIFE", Vector3.new(lx + 6, ly + 0.2, lz - 4), Color3.fromRGB(220, 40, 40))

	-- Desk / counter for hub feel
	makePart(
		"LobbyDesk",
		Vector3.new(10, 1.2, 2.4),
		CFrame.new(lx, ly + 1.4, lz - 8),
		Color3.fromRGB(36, 42, 56),
		Enum.Material.SmoothPlastic,
		lobbyFolder
	)
	makePart(
		"LobbyDeskTop",
		Vector3.new(10.4, 0.2, 2.8),
		CFrame.new(lx, ly + 2.1, lz - 8),
		Color3.fromRGB(55, 64, 88),
		Enum.Material.Metal,
		lobbyFolder
	)
end

-- Invisible safety slab under arena + lobby so players never fall into the void
do
	local safety = makePart(
		"VoidSafety",
		Vector3.new(420, 2, 280),
		CFrame.new(-40, -18, 20),
		Color3.fromRGB(10, 10, 14),
		Enum.Material.SmoothPlastic,
		folder
	)
	safety.Transparency = 1
	safety.CanQuery = false
	safety.CanTouch = false
end

print(string.format(
	"[CQCArena] Room complex ready — %dx%d rooms, %d doors, lobby + combat pads.",
	cols,
	rows,
	doorIdCounter
))
