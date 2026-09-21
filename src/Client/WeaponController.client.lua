--!strict
--[[
	Client weapon input + gun feel:
	hold LMB to fire, R to reload.
	Camera recoil / FOV kick, muzzle flash, tracers, layered fire sounds.
	Hitmarkers / damage numbers driven by server FireResult (real hits only).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local fireRemote = remotes:WaitForChild(Config.Remotes.FireWeapon) :: RemoteEvent
local fireResultRemote = remotes:WaitForChild(Config.Remotes.FireResult) :: RemoteEvent

local equippedTool: Tool? = nil
local holding = false
local lastLocalFire = 0
local boundTools: { [Tool]: boolean } = {}
local watchedContainers: { [Instance]: boolean } = {}

local feel = Config.Feel
local soundIds = Config.SoundIds
local volumes = Config.SoundVolumes

-- Hitmarker GUI
local fxGui = Instance.new("ScreenGui")
fxGui.Name = "CQCWeaponFX"
fxGui.ResetOnSpawn = false
fxGui.IgnoreGuiInset = true
fxGui.DisplayOrder = 20
fxGui.Parent = playerGui

local hitMarker = Instance.new("Frame")
hitMarker.Name = "HitMarker"
hitMarker.AnchorPoint = Vector2.new(0.5, 0.5)
hitMarker.Position = UDim2.fromScale(0.5, 0.5)
hitMarker.Size = UDim2.fromOffset(28, 28)
hitMarker.BackgroundTransparency = 1
hitMarker.Visible = false
hitMarker.Parent = fxGui

local function makeMarkArm(rot: number, color: Color3): Frame
	local arm = Instance.new("Frame")
	arm.AnchorPoint = Vector2.new(0.5, 0.5)
	arm.Position = UDim2.fromScale(0.5, 0.5)
	arm.Size = UDim2.fromOffset(14, 3)
	arm.BackgroundColor3 = color
	arm.BorderSizePixel = 0
	arm.Rotation = rot
	arm.Parent = hitMarker
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 1)
	c.Parent = arm
	return arm
end

-- X-shaped hitmarker arms (will recolor for headshot)
local markArms = {
	makeMarkArm(45, Color3.fromRGB(255, 255, 255)),
	makeMarkArm(-45, Color3.fromRGB(255, 255, 255)),
}

local function isOurTool(tool: Instance?): boolean
	return tool ~= nil and tool:IsA("Tool") and tool.Name == Config.Weapon.Name
end

local function getLook(): (Vector3, Vector3)
	local cam = workspace.CurrentCamera
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	local origin = if head then head.Position else (if cam then cam.CFrame.Position else Vector3.zero)
	local look = if cam then cam.CFrame.LookVector else Vector3.zAxis
	return origin, look
end

local function playSoundAt(parent: Instance, soundId: string, volume: number, playbackSpeed: number?)
	if soundId == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume
	s.PlaybackSpeed = playbackSpeed or (0.95 + math.random() * 0.1)
	s.RollOffMaxDistance = 80
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 3)
end

local function getMuzzlePart(tool: Tool): BasePart?
	local m = tool:FindFirstChild("Muzzle")
	if m and m:IsA("BasePart") then
		return m
	end
	local h = tool:FindFirstChild("Handle")
	if h and h:IsA("BasePart") then
		return h
	end
	return nil
end

local function flashMuzzle(tool: Tool)
	local muzzle = getMuzzlePart(tool)
	if not muzzle then
		return
	end

	local flash = muzzle:FindFirstChild("MuzzleFlashPart") :: Part?
	if not flash then
		flash = Instance.new("Part")
		flash.Name = "MuzzleFlashPart"
		flash.Size = Vector3.new(0.35, 0.35, 0.35)
		flash.Shape = Enum.PartType.Ball
		flash.Material = Enum.Material.Neon
		flash.Color = Color3.fromRGB(255, 200, 80)
		flash.CanCollide = false
		flash.CanQuery = false
		flash.Massless = true
		flash.CastShadow = false
		flash.Parent = tool

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = muzzle
		weld.Part1 = flash
		weld.Parent = flash
		flash.CFrame = muzzle.CFrame
	end

	flash.Transparency = 0.15
	flash.Color = Color3.fromRGB(255, 220, 100)

	local light = flash:FindFirstChildOfClass("PointLight")
	if not light then
		light = Instance.new("PointLight")
		light.Parent = flash
	end
	light.Brightness = feel.MuzzleLightBrightness
	light.Range = feel.MuzzleLightRange
	light.Color = Color3.fromRGB(255, 200, 120)
	light.Enabled = true

	task.delay(feel.MuzzleFlashSeconds, function()
		if flash.Parent then
			flash.Transparency = 1
		end
		if light.Parent then
			light.Enabled = false
		end
	end)
end

local activeRecoil = 0
local activeFovKick = 0
local baseFov: number? = nil

local function punchRecoil()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	if baseFov == nil then
		baseFov = cam.FieldOfView
	end

	local pitch = math.rad(feel.RecoilPitchDegrees * (0.75 + math.random() * 0.5))
	local yaw = math.rad(feel.RecoilYawDegrees * (math.random() * 2 - 1))
	-- Apply immediate camera punch
	cam.CFrame = cam.CFrame * CFrame.Angles(pitch, yaw, 0)
	activeRecoil = 1
	activeFovKick = feel.FovKick
	cam.FieldOfView = (baseFov :: number) + activeFovKick
end

RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	if baseFov == nil then
		baseFov = cam.FieldOfView
	end

	if activeRecoil > 0 then
		local recover = dt / math.max(0.01, feel.RecoilRecoverSeconds)
		local step = math.min(activeRecoil, recover)
		-- Ease camera back down slightly (complement punch)
		cam.CFrame = cam.CFrame * CFrame.Angles(-math.rad(feel.RecoilPitchDegrees) * step * 0.85, 0, 0)
		activeRecoil = math.max(0, activeRecoil - recover)
	end

	if activeFovKick > 0 and baseFov then
		local recover = dt / math.max(0.01, feel.FovRecoverSeconds)
		activeFovKick = math.max(0, activeFovKick - feel.FovKick * recover)
		cam.FieldOfView = baseFov + activeFovKick
	end
end)

local function spawnTracer(fromPos: Vector3, toPos: Vector3, damaged: boolean)
	local dist = (toPos - fromPos).Magnitude
	if dist < 0.5 then
		return
	end

	local att0Parent = Instance.new("Part")
	att0Parent.Name = "TracerAnchor"
	att0Parent.Anchored = true
	att0Parent.CanCollide = false
	att0Parent.CanQuery = false
	att0Parent.Transparency = 1
	att0Parent.Size = Vector3.new(0.1, 0.1, 0.1)
	att0Parent.Position = fromPos
	att0Parent.Parent = workspace

	local att1Parent = Instance.new("Part")
	att1Parent.Name = "TracerEnd"
	att1Parent.Anchored = true
	att1Parent.CanCollide = false
	att1Parent.CanQuery = false
	att1Parent.Transparency = 1
	att1Parent.Size = Vector3.new(0.1, 0.1, 0.1)
	att1Parent.Position = toPos
	att1Parent.Parent = workspace

	local a0 = Instance.new("Attachment")
	a0.Parent = att0Parent
	local a1 = Instance.new("Attachment")
	a1.Parent = att1Parent

	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = feel.TracerWidth
	beam.Width1 = feel.TracerWidth * 0.4
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	if damaged then
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 180, 60))
	else
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140))
	end
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 0.55),
	})
	beam.Parent = att0Parent

	Debris:AddItem(att0Parent, feel.TracerDuration + 0.05)
	Debris:AddItem(att1Parent, feel.TracerDuration + 0.05)
end

local function showHitMarker(headshot: boolean)
	local color = if headshot then Color3.fromRGB(255, 70, 70) else Color3.fromRGB(255, 255, 255)
	for _, arm in markArms do
		arm.BackgroundColor3 = color
	end
	hitMarker.Visible = true
	hitMarker.Size = UDim2.fromOffset(if headshot then 34 else 26, if headshot then 34 else 26)
	local dur = if headshot then feel.HeadshotMarkerSeconds else feel.HitMarkerSeconds
	task.delay(dur, function()
		hitMarker.Visible = false
	end)
end

local function spawnDamageNumber(worldPos: Vector3, damage: number, headshot: boolean)
	local part = Instance.new("Part")
	part.Name = "DmgAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Position = worldPos + Vector3.new(0, 1.2, 0)
	part.Parent = workspace

	local bill = Instance.new("BillboardGui")
	bill.Size = UDim2.fromOffset(80, 36)
	bill.StudsOffset = Vector3.new((math.random() - 0.5) * 1.2, 0, 0)
	bill.AlwaysOnTop = true
	bill.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = if headshot then 26 else 22
	label.TextStrokeTransparency = 0.4
	label.TextColor3 = if headshot then Color3.fromRGB(255, 90, 90) else Color3.fromRGB(255, 230, 120)
	label.Text = if headshot then string.format("%d HS", damage) else tostring(damage)
	label.Parent = bill

	local start = part.Position
	local goal = start + Vector3.new(0, feel.DamageNumberRise, 0)
	local t0 = os.clock()
	local conn: RBXScriptConnection?
	conn = RunService.RenderStepped:Connect(function()
		local alpha = (os.clock() - t0) / feel.DamageNumberLifetime
		if alpha >= 1 then
			if conn then
				conn:Disconnect()
			end
			part:Destroy()
			return
		end
		part.Position = start:Lerp(goal, alpha)
		label.TextTransparency = math.max(0, (alpha - 0.45) / 0.55)
		label.TextStrokeTransparency = 0.4 + 0.6 * math.max(0, (alpha - 0.45) / 0.55)
	end)
end

local function onFireResult(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	local char = player.Character
	local tool = equippedTool or (char and char:FindFirstChild(Config.Weapon.Name) :: Tool?)

	if kind == "empty" then
		local parent: Instance = (tool and getMuzzlePart(tool)) or (char and char:FindFirstChild("HumanoidRootPart")) or fxGui
		playSoundAt(parent, soundIds.Empty, volumes.Empty, 1)
		return
	end

	if kind == "reload" then
		local parent: Instance = (tool and getMuzzlePart(tool)) or (char and char:FindFirstChild("HumanoidRootPart")) or fxGui
		playSoundAt(parent, soundIds.Reload, volumes.Reload, 1)
		return
	end

	if kind == "reloadDone" or kind == "blocked" then
		return
	end

	if kind ~= "shot" then
		return
	end

	-- Confirmed shot: recoil, flash, sounds, tracers
	punchRecoil()
	if tool then
		flashMuzzle(tool)
		local muzzle = getMuzzlePart(tool)
		if muzzle then
			playSoundAt(muzzle, soundIds.Fire, volumes.Fire)
			-- Layered crack for weight
			task.delay(0.02, function()
				if muzzle.Parent then
					playSoundAt(muzzle, soundIds.FireAlt, volumes.FireAlt, 1.05 + math.random() * 0.1)
				end
			end)
		end
	end

	if typeof(payload.tracers) == "table" then
		for _, tr in payload.tracers do
			if typeof(tr) == "table" and typeof(tr.from) == "Vector3" and typeof(tr.to) == "Vector3" then
				spawnTracer(tr.from, tr.to, tr.damaged == true)
			end
		end
	end

	-- Hit feedback only when server confirms
	if payload.anyHit == true and typeof(payload.hits) == "table" then
		local headshot = payload.anyHeadshot == true
		showHitMarker(headshot)
		local parent: Instance = fxGui
		if tool then
			local m = getMuzzlePart(tool)
			if m then
				parent = m
			end
		end
		if headshot then
			playSoundAt(parent, soundIds.Headshot, volumes.Headshot, 1)
		else
			playSoundAt(parent, soundIds.HitConfirm, volumes.HitConfirm, 1)
		end
		for _, hit in payload.hits do
			if typeof(hit) == "table" and typeof(hit.position) == "Vector3" and typeof(hit.damage) == "number" then
				spawnDamageNumber(hit.position, hit.damage, hit.headshot == true)
			end
		end
	end
end

fireResultRemote.OnClientEvent:Connect(onFireResult)

local function tryFire()
	if not equippedTool then
		return
	end
	local now = os.clock()
	if now - lastLocalFire < Config.Weapon.FireCooldown * 0.85 then
		return
	end
	lastLocalFire = now
	local origin, look = getLook()
	fireRemote:FireServer(origin, look)
end

local function bindTool(tool: Tool)
	if boundTools[tool] then
		return
	end
	boundTools[tool] = true
	tool.Destroying:Connect(function()
		boundTools[tool] = nil
		if equippedTool == tool then
			equippedTool = nil
			holding = false
		end
	end)
	tool.Equipped:Connect(function()
		equippedTool = tool
	end)
	tool.Unequipped:Connect(function()
		if equippedTool == tool then
			equippedTool = nil
			holding = false
		end
	end)
	tool.Activated:Connect(function()
		if equippedTool == tool then
			holding = true
			tryFire()
		end
	end)
	tool.Deactivated:Connect(function()
		holding = false
	end)
end

local function watchContainer(container: Instance)
	if watchedContainers[container] then
		for _, child in container:GetChildren() do
			if isOurTool(child) then
				bindTool(child :: Tool)
			end
		end
		return
	end
	watchedContainers[container] = true
	for _, child in container:GetChildren() do
		if isOurTool(child) then
			bindTool(child :: Tool)
		end
	end
	container.ChildAdded:Connect(function(child)
		if isOurTool(child) then
			bindTool(child :: Tool)
		end
	end)
end

local function onCharacter(character: Model)
	equippedTool = nil
	holding = false
	watchContainer(character)
	local backpack = player:FindFirstChild("Backpack") or player:WaitForChild("Backpack")
	watchContainer(backpack)
end

if player.Character then
	onCharacter(player.Character)
end
player.CharacterAdded:Connect(onCharacter)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if not equippedTool then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		fireRemote:FireServer("reload")
	end
end)

RunService.RenderStepped:Connect(function()
	if holding and equippedTool then
		tryFire()
	end
end)
