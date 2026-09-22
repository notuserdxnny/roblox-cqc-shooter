--!strict
--[[
	Client weapon input + gun feel:
	hold LMB to fire, R to reload.
	Camera recoil / FOV kick, muzzle flash, tracers, layered fire sounds.
	Hitmarkers / damage numbers driven by server FireResult (real hits only).

	CRITICAL: recoil ONLY rotates Camera CFrame via a local offset.
	Never writes HumanoidRootPart / character CFrame / Tool grip.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local fireRemote = remotes:WaitForChild(Config.Remotes.FireWeapon) :: RemoteEvent
local fireResultRemote = remotes:WaitForChild(Config.Remotes.FireResult) :: RemoteEvent
local meleeRemote = remotes:WaitForChild(Config.Remotes.MeleeAttack) :: RemoteEvent

local equippedTool: Tool? = nil
local holding = false
local lastLocalFire = 0
local lastLocalMelee = 0
local clientAmmo = 0
local clientMode = Config.DefaultMode
local meleeReady = false
local boundTools: { [Tool]: boolean } = {}
local watchedContainers: { [Instance]: boolean } = {}

local function inMatchLive(): boolean
	return player:GetAttribute("CQCInMatch") == true
		and player:GetAttribute("CQCMatchOver") ~= true
		and player:GetAttribute("CQCCountdown") ~= true
		and player:GetAttribute("CQCInHub") ~= true
end

--[[
	Never unlock the mouse from weapon code. Tool clicks often flip MouseBehavior
	to Default; re-assert LockCenter so look keeps working without re-clicking.
]]
local function keepMouseLocked()
	if not inMatchLive() then
		return
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	pcall(function()
		GuiService.SelectedObject = nil
	end)
end

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

local markArms = {
	makeMarkArm(45, Color3.fromRGB(255, 255, 255)),
	makeMarkArm(-45, Color3.fromRGB(255, 255, 255)),
}

-- Damage taken flash
local damageFlash = Instance.new("Frame")
damageFlash.Name = "DamageFlash"
damageFlash.Size = UDim2.fromScale(1, 1)
damageFlash.BackgroundColor3 = Color3.fromRGB(180, 20, 30)
damageFlash.BackgroundTransparency = 1
damageFlash.BorderSizePixel = 0
damageFlash.ZIndex = 50
damageFlash.Parent = fxGui

local function flashDamage()
	local t = feel.DamageFlashTransparency or 0.72
	damageFlash.BackgroundTransparency = t
	task.spawn(function()
		local t0 = os.clock()
		local dur = feel.DamageFlashSeconds or 0.18
		while true do
			local a = (os.clock() - t0) / dur
			if a >= 1 then
				damageFlash.BackgroundTransparency = 1
				break
			end
			damageFlash.BackgroundTransparency = t + (1 - t) * a
			task.wait()
		end
	end)
end

local function hitColors(): (Color3, Color3)
	local id = player:GetAttribute("CQCHitmarker")
	if typeof(id) == "string" then
		local item = Config.GetShopItem(id)
		if item then
			return item.HitColor or Color3.fromRGB(255, 255, 255), item.HitHeadColor or Color3.fromRGB(255, 70, 70)
		end
	end
	return Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 70, 70)
end

local function isOurTool(tool: Instance?): boolean
	return Config.IsWeaponTool(tool) or Config.IsMeleeTool(tool)
end

local function isMeleeTool(tool: Instance?): boolean
	return Config.IsMeleeTool(tool)
end

local function inOITC(): boolean
	local attr = player:GetAttribute("CQCMode")
	if typeof(attr) == "string" then
		return attr == Config.Modes.OITC
	end
	return clientMode == Config.Modes.OITC
end

local function shouldMelee(): boolean
	if not inOITC() then
		return false
	end
	-- Knife equipped → always melee (even if ammo somehow > 0)
	if equippedTool and isMeleeTool(equippedTool) then
		return true
	end
	if meleeReady or clientAmmo <= 0 then
		return true
	end
	return false
end

local function currentWeaponId(): string?
	if equippedTool then
		local id = equippedTool:GetAttribute("WeaponId")
		if typeof(id) == "string" then
			return id
		end
		local def = Config.GetWeaponByToolName(equippedTool.Name)
		if def then
			return def.Id
		end
	end
	return nil
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
		flash.Anchored = false
		-- Align BEFORE welding so WeldConstraint never yanks the tool/character
		flash.CFrame = muzzle.CFrame
		flash.Parent = tool

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = muzzle
		weld.Part1 = flash
		weld.Parent = flash
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

--[[
	Camera-only recoil: accumulate pitch/yaw radians, apply as a post-camera
	rotation each frame. Never touches character / HRP / Humanoid.CameraOffset
	in a way that moves the body (we leave CameraOffset alone).
]]
local recoilPitch = 0 -- radians, positive = look up
local recoilYaw = 0
local activeFovKick = 0
local baseFov: number? = nil

local function punchRecoil(weaponId: string?)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	if baseFov == nil then
		baseFov = cam.FieldOfView
	end

	local mult = 1
	if weaponId and feel.RecoilByWeapon then
		local m = feel.RecoilByWeapon[weaponId]
		if typeof(m) == "number" then
			mult = m
		end
	end

	local pitch = math.rad(feel.RecoilPitchDegrees * mult * (0.75 + math.random() * 0.5))
	local yaw = math.rad(feel.RecoilYawDegrees * mult * (math.random() * 2 - 1))
	recoilPitch += pitch
	recoilYaw += yaw
	activeFovKick = feel.FovKick * math.clamp(mult, 0.6, 2.2)
	cam.FieldOfView = (baseFov :: number) + activeFovKick
end

-- Late camera priority so we layer on top of Roblox's LockFirstPerson camera
-- without fighting character position.
RunService:BindToRenderStep("CQC_CameraRecoil", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	if baseFov == nil then
		baseFov = cam.FieldOfView
	end

	-- Apply recoil as camera-space rotation only (does not move HRP)
	if math.abs(recoilPitch) > 1e-5 or math.abs(recoilYaw) > 1e-5 then
		cam.CFrame = cam.CFrame * CFrame.Angles(recoilPitch, recoilYaw, 0)
	end

	-- Recover offsets toward zero (camera will follow next frame)
	if recoilPitch ~= 0 or recoilYaw ~= 0 then
		local recover = dt / math.max(0.01, feel.RecoilRecoverSeconds)
		local decay = math.clamp(recover, 0, 1)
		recoilPitch *= (1 - decay)
		recoilYaw *= (1 - decay)
		if math.abs(recoilPitch) < 1e-4 then
			recoilPitch = 0
		end
		if math.abs(recoilYaw) < 1e-4 then
			recoilYaw = 0
		end
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
	local body, head = hitColors()
	local color = if headshot then head else body
	for _, arm in markArms do
		arm.BackgroundColor3 = color
	end
	hitMarker.Visible = true
	hitMarker.Size = UDim2.fromOffset(if headshot then 38 else 28, if headshot then 38 else 28)
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
	local tool: Tool? = equippedTool
	if not tool and char then
		for _, child in char:GetChildren() do
			if Config.IsWeaponTool(child) then
				tool = child :: Tool
				break
			end
		end
	end

	if kind == "empty" then
		local parent: Instance = (tool and getMuzzlePart(tool)) or (char and char:FindFirstChild("HumanoidRootPart")) or fxGui
		playSoundAt(parent, soundIds.Empty, volumes.Empty, 1)
		if payload.meleeReady == true then
			meleeReady = true
			clientAmmo = 0
		end
		return
	end

	if kind == "melee" then
		local parent: Instance = (tool and getMuzzlePart(tool)) or (char and char:FindFirstChild("HumanoidRootPart")) or fxGui
		playSoundAt(parent, soundIds.KnifeWhoosh or soundIds.Empty, volumes.KnifeWhoosh or 0.35, 0.9 + math.random() * 0.15)
		playSoundAt(parent, soundIds.Melee or soundIds.HitConfirm, volumes.Melee or volumes.HitConfirm, 1.1)
		if typeof(payload.ammo) == "number" then
			clientAmmo = payload.ammo
			meleeReady = clientAmmo <= 0
		end
		if payload.anyHit == true and typeof(payload.hits) == "table" then
			showHitMarker(false)
			for _, hit in payload.hits do
				if typeof(hit) == "table" and typeof(hit.position) == "Vector3" and typeof(hit.damage) == "number" then
					spawnDamageNumber(hit.position, hit.damage, false)
				end
			end
		end
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

	if typeof(payload.ammo) == "number" then
		clientAmmo = payload.ammo
		meleeReady = inOITC() and clientAmmo <= 0
	end
	if payload.meleeReady == true then
		meleeReady = true
	end

	local wid = if typeof(payload.weaponId) == "string" then payload.weaponId else currentWeaponId()
	punchRecoil(wid)
	if tool then
		flashMuzzle(tool)
		local muzzle = getMuzzlePart(tool)
		if muzzle then
			playSoundAt(muzzle, soundIds.Fire, volumes.Fire)
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


local lastHp = 100
local function watchDamage(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	lastHp = humanoid.Health
	humanoid.HealthChanged:Connect(function(hp)
		if hp < lastHp - 0.5 then
			flashDamage()
		end
		lastHp = hp
	end)
end
if player.Character then
	task.spawn(watchDamage, player.Character)
end
player.CharacterAdded:Connect(watchDamage)

fireResultRemote.OnClientEvent:Connect(onFireResult)

local function tryMelee()
	if player:GetAttribute("CQCInHub") == true then
		return
	end
	if player:GetAttribute("CQCInMatch") ~= true then
		return
	end
	local now = os.clock()
	if now - lastLocalMelee < Config.OITC.MeleeCooldown * 0.85 then
		return
	end
	lastLocalMelee = now
	local origin, look = getLook()
	meleeRemote:FireServer(origin, look)
end

local function tryFire()
	if player:GetAttribute("CQCInHub") == true then
		return
	end
	if player:GetAttribute("CQCInMatch") ~= true then
		return
	end

	-- OITC empty / knife: short-range melee instead of gun fire
	if shouldMelee() then
		tryMelee()
		return
	end

	if not equippedTool then
		return
	end
	if isMeleeTool(equippedTool) then
		tryMelee()
		return
	end
	local def = Config.GetWeaponByToolName(equippedTool.Name)
	local cooldown = if def then def.FireCooldown else 0.2
	local now = os.clock()
	if now - lastLocalFire < cooldown * 0.85 then
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
		fireRemote:FireServer("sync")
	end)
	tool.Unequipped:Connect(function()
		if equippedTool == tool then
			equippedTool = nil
			holding = false
		end
	end)
	-- ManualActivationOnly tools still fire Activated if we call Activate();
	-- primary path is InputBegan. Never change MouseBehavior to Default here.
	tool.Activated:Connect(function()
		if equippedTool == tool then
			holding = true
			keepMouseLocked()
			tryFire()
			keepMouseLocked()
		end
	end)
	tool.Deactivated:Connect(function()
		holding = false
		keepMouseLocked()
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
	recoilPitch = 0
	recoilYaw = 0
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
		-- Even if a GUI ate the click, keep mouse locked while live so look doesn't freeze
		if inMatchLive() then
			keepMouseLocked()
		end
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- Primary fire path (ManualActivationOnly tools). Never unlock mouse.
		if player:GetAttribute("CQCInHub") == true or player:GetAttribute("CQCInMatch") ~= true then
			return
		end
		if player:GetAttribute("CQCCountdown") == true then
			return
		end
		holding = true
		keepMouseLocked()
		tryFire()
		keepMouseLocked()
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		if inOITC() then
			return -- no reload in OITC
		end
		if not equippedTool then
			return
		end
		fireRemote:FireServer("reload")
	end
end)

UserInputService.InputEnded:Connect(function(input, _gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holding = false
		keepMouseLocked()
		task.defer(keepMouseLocked)
	end
end)

-- Track ammo/mode from server for melee gating
local ammoRemote = remotes:WaitForChild(Config.Remotes.AmmoUpdate) :: RemoteEvent
ammoRemote.OnClientEvent:Connect(function(current, _max, _reloading, _weaponId, _wName)
	if typeof(current) == "number" then
		clientAmmo = current
		meleeReady = inOITC() and clientAmmo <= 0
	end
end)

local statsRemote = remotes:WaitForChild(Config.Remotes.StatsUpdate) :: RemoteEvent
statsRemote.OnClientEvent:Connect(function(stats)
	if typeof(stats) ~= "table" then
		return
	end
	if typeof(stats.mode) == "string" then
		clientMode = stats.mode
	end
	if typeof(stats.ammo) == "number" then
		clientAmmo = stats.ammo
	end
	if stats.meleeReady ~= nil then
		meleeReady = stats.meleeReady == true
	elseif inOITC() then
		meleeReady = clientAmmo <= 0
	end
end)

player:GetAttributeChangedSignal("CQCMode"):Connect(function()
	local m = player:GetAttribute("CQCMode")
	if typeof(m) == "string" then
		clientMode = m
	end
end)

RunService.RenderStepped:Connect(function()
	if inMatchLive() then
		keepMouseLocked()
	end
	if holding and (equippedTool or shouldMelee()) then
		tryFire()
	end
end)
