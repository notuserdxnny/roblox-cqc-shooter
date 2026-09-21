--!strict
--[[
	Spawns simple wandering training dummies for solo playtesting.
	Compact welded body (root + torso + head) so they stay upright.
	Placed at Config.NPC.SpawnOffsets (room centers from WorldSetup marks).
	Wander stays near each dummy's spawn room.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local NPCService = {}

local npcFolder: Folder? = nil
local arenaCenter = Vector3.new(0, Config.Arena.SpawnHeight, 0)
local spawnIndex = 0

local function ensureFolder(): Folder
	if npcFolder and npcFolder.Parent then
		return npcFolder
	end
	local folder = Instance.new("Folder")
	folder.Name = "NPCs"
	folder.Parent = workspace
	npcFolder = folder
	return folder
end

local function weld(a: BasePart, b: BasePart)
	-- Align b to intended pose before welding is caller's job; here parts already posed
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function createDummy(name: string, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = name

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(position)
	root.Transparency = 1
	root.CanCollide = true
	root.Parent = model

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.2, 2.2, 1.2)
	torso.Color = Color3.fromRGB(200, 80, 60)
	torso.Material = Enum.Material.SmoothPlastic
	torso.CFrame = root.CFrame
	torso.CanCollide = false
	torso.Massless = true
	torso.Parent = model
	weld(root, torso)

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.3, 1.3, 1.3)
	head.Color = Color3.fromRGB(240, 200, 160)
	head.Material = Enum.Material.SmoothPlastic
	head.CFrame = root.CFrame * CFrame.new(0, 1.7, 0)
	head.CanCollide = false
	head.Massless = true
	head.Parent = model
	weld(root, head)

	local legs = Instance.new("Part")
	legs.Name = "Legs"
	legs.Size = Vector3.new(2, 2, 1)
	legs.Color = Color3.fromRGB(50, 50, 60)
	legs.Material = Enum.Material.SmoothPlastic
	legs.CFrame = root.CFrame * CFrame.new(0, -2, 0)
	legs.CanCollide = false
	legs.Massless = true
	legs.Parent = model
	weld(root, legs)

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = Config.NPC.MaxHealth
	humanoid.Health = Config.NPC.MaxHealth
	humanoid.WalkSpeed = Config.NPC.WalkSpeed
	humanoid.HipHeight = 2
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Subject
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	humanoid.Parent = model

	model.PrimaryPart = root
	model.Parent = ensureFolder()

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.fromOffset(140, 30)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard

	model:SetAttribute("HomeX", position.X)
	model:SetAttribute("HomeZ", position.Z)

	return model
end

local function nextSpawnPosition(): Vector3
	local offsets = Config.NPC.SpawnOffsets
	if offsets and #offsets > 0 then
		spawnIndex = (spawnIndex % #offsets) + 1
		local off = offsets[spawnIndex]
		local jitter = Vector3.new((math.random() - 0.5) * 3, 0, (math.random() - 0.5) * 3)
		-- Offsets may be absolute world XZ (from WorldSetup marks) or relative to arenaCenter
		if math.abs(off.X) > 5 or math.abs(off.Z) > 5 then
			return Vector3.new(off.X, arenaCenter.Y, off.Z) + jitter
		end
		return arenaCenter + Vector3.new(off.X, 0, off.Z) + jitter
	end
	local angle = math.random() * math.pi * 2
	local dist = 4 + math.random() * 6
	return arenaCenter + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
end

local function wanderLoop(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local homeX = model:GetAttribute("HomeX") :: number? or arenaCenter.X
	local homeZ = model:GetAttribute("HomeZ") :: number? or arenaCenter.Z
	local home = Vector3.new(homeX, arenaCenter.Y, homeZ)

	task.spawn(function()
		while model.Parent and humanoid.Parent and humanoid.Health > 0 do
			local angle = math.random() * math.pi * 2
			local radius = math.random() * Config.NPC.WanderRadius
			local target = home + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			humanoid:MoveTo(target)
			task.wait(Config.NPC.WanderInterval + math.random() * 1.5)
		end
	end)

	humanoid.Died:Connect(function()
		local labelName = model.Name
		task.wait(4)
		if model.Parent then
			model:Destroy()
		end
		task.wait(1)
		NPCService.SpawnOne(labelName)
	end)
end

function NPCService.SpawnOne(name: string?): Model
	local n = name or (Config.NPC.Name .. " " .. tostring(math.random(10, 99)))
	local pos = nextSpawnPosition()
	local dummy = createDummy(n, pos)
	wanderLoop(dummy)
	return dummy
end

function NPCService.Init(center: Vector3?)
	if center then
		arenaCenter = center
	end
	spawnIndex = 0
	ensureFolder()
	for i = 1, Config.NPC.Count do
		NPCService.SpawnOne(Config.NPC.Name .. " " .. tostring(i))
	end
end

return NPCService
