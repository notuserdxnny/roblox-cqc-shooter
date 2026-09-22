--!strict
--[[
	Combat bots for OITC solo / filler play.
	Path between room/cover waypoints, acquire live InMatch players (post-countdown),
	fire server raycast pistol shots with LOS + capped range, melee only with LOS.
	Spawns snap to floor and avoid landing on players.
	Player kill of bot → CombatService kill credit (ammo + score + credits).
	Bot kill of player → ammo refill + kill feed ("Bot killed you").
]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local NPCService = {}

local BOT_ATTR = "CQCBot"

local npcFolder: Folder? = nil
local arenaCenter = Vector3.new(0, Config.Arena.SpawnHeight, 0)
local spawnIndex = 0
local waypoints: { Vector3 } = {}
local activeBots: { Model } = {}
local killFeedRemote: RemoteEvent? = nil

local function getKillFeed(): RemoteEvent?
	if killFeedRemote and killFeedRemote.Parent then
		return killFeedRemote
	end
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if folder then
		local r = folder:FindFirstChild(Config.Remotes.KillFeed)
		if r and r:IsA("RemoteEvent") then
			killFeedRemote = r
			return r
		end
	end
	return nil
end

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
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function collectWaypoints()
	table.clear(waypoints)
	local arena = workspace:FindFirstChild("CQCArena")
	if arena then
		local marks = arena:FindFirstChild("NPCSpawnMarks")
		if marks then
			for _, child in marks:GetChildren() do
				if child:IsA("BasePart") then
					table.insert(waypoints, Vector3.new(child.Position.X, arenaCenter.Y, child.Position.Z))
				end
			end
		end
		local botMarks = arena:FindFirstChild("BotWaypoints")
		if botMarks then
			for _, child in botMarks:GetChildren() do
				if child:IsA("BasePart") then
					table.insert(waypoints, Vector3.new(child.Position.X, arenaCenter.Y, child.Position.Z))
				end
			end
		end
		local cover = arena:FindFirstChild("Cover")
		if cover then
			for _, child in cover:GetChildren() do
				if child:IsA("BasePart") then
					local name = child.Name
					if string.find(name, "HalfWall", 1, true) or string.find(name, "Crate", 1, true) then
						local p = child.Position
						table.insert(waypoints, Vector3.new(p.X + 3, arenaCenter.Y, p.Z + 3))
					end
				end
			end
		end
		local rooms = arena:FindFirstChild("Rooms")
		if rooms then
			for _, room in rooms:GetChildren() do
				local floor = room:FindFirstChild("Floor")
				if floor and floor:IsA("BasePart") then
					table.insert(waypoints, Vector3.new(floor.Position.X, arenaCenter.Y, floor.Position.Z))
				end
			end
		end
	end
	local offsets = Config.NPC.SpawnOffsets
	if #waypoints == 0 and offsets then
		for _, off in offsets do
			table.insert(waypoints, Vector3.new(off.X, arenaCenter.Y, off.Z))
		end
	end
	if #waypoints == 0 then
		table.insert(waypoints, arenaCenter)
	end
end

local function randomWaypoint(exclude: Vector3?): Vector3
	if #waypoints == 0 then
		collectWaypoints()
	end
	if #waypoints == 1 then
		return waypoints[1]
	end
	for _ = 1, 8 do
		local w = waypoints[math.random(1, #waypoints)]
		if not exclude or (w - exclude).Magnitude > 6 then
			return w
		end
	end
	return waypoints[math.random(1, #waypoints)]
end

local function refillAmmo(bot: Model)
	bot:SetAttribute("BotAmmo", Config.NPC.StartingAmmo or 1)
end

local function createBot(name: string, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute(BOT_ATTR, true)
	refillAmmo(model)

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
	torso.Color = Color3.fromRGB(45, 72, 110)
	torso.Material = Enum.Material.SmoothPlastic
	torso.CFrame = root.CFrame
	torso.CanCollide = false
	torso.Massless = true
	torso.Parent = model
	weld(root, torso)

	local vest = Instance.new("Part")
	vest.Name = "Vest"
	vest.Size = Vector3.new(2.0, 1.4, 1.35)
	vest.Color = Color3.fromRGB(28, 36, 48)
	vest.Material = Enum.Material.Metal
	vest.CFrame = root.CFrame * CFrame.new(0, 0.1, 0)
	vest.CanCollide = false
	vest.Massless = true
	vest.Parent = model
	weld(root, vest)

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.25, 1.25, 1.25)
	head.Color = Color3.fromRGB(220, 185, 150)
	head.Material = Enum.Material.SmoothPlastic
	head.CFrame = root.CFrame * CFrame.new(0, 1.65, 0)
	head.CanCollide = false
	head.Massless = true
	head.Parent = model
	weld(root, head)

	local helm = Instance.new("Part")
	helm.Name = "Helmet"
	helm.Size = Vector3.new(1.35, 0.55, 1.35)
	helm.Color = Color3.fromRGB(35, 55, 80)
	helm.Material = Enum.Material.Metal
	helm.CFrame = root.CFrame * CFrame.new(0, 2.15, 0)
	helm.CanCollide = false
	helm.Massless = true
	helm.Parent = model
	weld(root, helm)

	local legs = Instance.new("Part")
	legs.Name = "Legs"
	legs.Size = Vector3.new(2, 2, 1)
	legs.Color = Color3.fromRGB(32, 36, 48)
	legs.Material = Enum.Material.SmoothPlastic
	legs.CFrame = root.CFrame * CFrame.new(0, -2, 0)
	legs.CanCollide = false
	legs.Massless = true
	legs.Parent = model
	weld(root, legs)

	local gun = Instance.new("Part")
	gun.Name = "BotPistol"
	gun.Size = Vector3.new(0.28, 0.35, 1.15)
	gun.Color = Color3.fromRGB(28, 28, 34)
	gun.Material = Enum.Material.Metal
	gun.CFrame = root.CFrame * CFrame.new(1.1, 0.35, -0.7)
	gun.CanCollide = false
	gun.Massless = true
	gun.Parent = model
	weld(root, gun)

	local muzzle = Instance.new("Part")
	muzzle.Name = "Muzzle"
	muzzle.Size = Vector3.new(0.2, 0.2, 0.2)
	muzzle.Transparency = 1
	muzzle.CanCollide = false
	muzzle.Massless = true
	muzzle.CFrame = gun.CFrame * CFrame.new(0, 0, -0.65)
	muzzle.Parent = model
	weld(gun, muzzle)

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
	billboard.Size = UDim2.fromOffset(150, 32)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.fromRGB(120, 190, 255)
	label.TextStrokeTransparency = 0.35
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard

	model:SetAttribute("HomeX", position.X)
	model:SetAttribute("HomeZ", position.Z)

	return model
end

local function snapToFloor(xz: Vector3): Vector3
	local rayH = Config.NPC.SpawnFloorRayHeight or 12
	local origin = Vector3.new(xz.X, (Config.Map and Config.Map.FloorY or 0) + rayH, xz.Z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ensureFolder() }
	params.IgnoreWater = true
	local hit = workspace:Raycast(origin, Vector3.new(0, -rayH * 2, 0), params)
	local hip = 2 -- matches createBot Humanoid.HipHeight
	if hit then
		-- Reject ceiling / high hits (spawn inside geometry)
		local floorY = (Config.Map and Config.Map.FloorY) or 0
		if hit.Position.Y > floorY + 6 then
			return Vector3.new(xz.X, floorY + hip + 0.15, xz.Z)
		end
		return Vector3.new(xz.X, hit.Position.Y + hip + 0.15, xz.Z)
	end
	local floorY = (Config.Map and Config.Map.FloorY) or 0
	return Vector3.new(xz.X, floorY + hip + 0.15, xz.Z)
end

local function tooCloseToPlayers(pos: Vector3): boolean
	local minSep = Config.NPC.MinSpawnSeparationFromPlayers or 16
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			local flat = Vector3.new(hrp.Position.X - pos.X, 0, hrp.Position.Z - pos.Z)
			if flat.Magnitude < minSep then
				return true
			end
		end
	end
	return false
end

local function candidateFromOffset(off: Vector3): Vector3
	local jitter = Vector3.new((math.random() - 0.5) * 4, 0, (math.random() - 0.5) * 4)
	local xz: Vector3
	if math.abs(off.X) > 5 or math.abs(off.Z) > 5 then
		xz = Vector3.new(off.X, 0, off.Z) + jitter
	else
		xz = arenaCenter + Vector3.new(off.X, 0, off.Z) + jitter
	end
	return snapToFloor(xz)
end

local function nextSpawnPosition(): Vector3
	local offsets = Config.NPC.SpawnOffsets
	local tried: { Vector3 } = {}
	if offsets and #offsets > 0 then
		for _ = 1, #offsets do
			spawnIndex = (spawnIndex % #offsets) + 1
			local pos = candidateFromOffset(offsets[spawnIndex])
			table.insert(tried, pos)
			if not tooCloseToPlayers(pos) then
				return pos
			end
		end
	end
	for _ = 1, 10 do
		local wp = randomWaypoint(nil)
		local pos = snapToFloor(wp + Vector3.new((math.random() - 0.5) * 3, 0, (math.random() - 0.5) * 3))
		table.insert(tried, pos)
		if not tooCloseToPlayers(pos) then
			return pos
		end
	end
	if #tried > 0 then
		return tried[1]
	end
	return snapToFloor(arenaCenter)
end

--[[
	Live combat victims only: InMatch, countdown finished, match not over.
]]
local function playerCanBeDamaged(plr: Player): boolean
	if plr:GetAttribute("CQCInMatch") ~= true then
		return false
	end
	if plr:GetAttribute("CQCCountdown") == true then
		return false
	end
	if plr:GetAttribute("CQCMatchOver") == true then
		return false
	end
	if plr:GetAttribute("CQCInHub") == true then
		return false
	end
	return true
end

local function findTarget(bot: Model): (Player?, BasePart?, number)
	local root = bot.PrimaryPart
	if not root then
		return nil, nil, math.huge
	end
	local acquire = Config.NPC.AcquireRange or 42
	local bestPlr: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDist = acquire

	for _, plr in Players:GetPlayers() do
		if playerCanBeDamaged(plr) then
			local char = plr.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hum and hum.Health > 0 and hrp and hrp:IsA("BasePart") then
					local d = (hrp.Position - root.Position).Magnitude
					if d < bestDist then
						bestDist = d
						bestPlr = plr
						bestRoot = hrp
					end
				end
			end
		end
	end
	return bestPlr, bestRoot, bestDist
end

local function faceToward(root: BasePart, target: Vector3)
	local flat = Vector3.new(target.X, root.Position.Y, target.Z)
	if (flat - root.Position).Magnitude < 0.2 then
		return
	end
	root.CFrame = CFrame.lookAt(root.Position, flat)
end

--[[
	True when nothing solid sits between from→to.
	Ignore list should include the bot (and optionally the target character when
	checking "can I see them" — then nil result means clear air to the aim point).
]]
local function hasLineOfSight(fromPos: Vector3, toPos: Vector3, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local dir = toPos - fromPos
	local dist = dir.Magnitude
	if dist < 0.1 then
		return true
	end
	local result = workspace:Raycast(fromPos, dir.Unit * dist, params)
	-- nil = clear air to the aim point (target character should be in ignore list)
	return result == nil
end

local function losToPlayer(bot: Model, targetRoot: BasePart, targetChar: Model?): boolean
	if Config.NPC.RequireLineOfSight == false then
		return true
	end
	local root = bot.PrimaryPart
	if not root then
		return false
	end
	local eye = root.Position + Vector3.new(0, 1.4, 0)
	local aim = targetRoot.Position + Vector3.new(0, 1.2, 0)
	local ignore: { Instance } = { bot }
	if targetChar then
		table.insert(ignore, targetChar)
	end
	return hasLineOfSight(eye, aim, ignore)
end

local function announceKill(killerName: string, victimName: string)
	local feed = getKillFeed()
	if feed then
		feed:FireAllClients(killerName, victimName)
	end
end

local function botMelee(bot: Model, targetPlayer: Player, targetRoot: BasePart)
	local root = bot.PrimaryPart
	local hum = bot:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return
	end
	if not playerCanBeDamaged(targetPlayer) then
		return
	end
	local char = targetPlayer.Character
	if not char then
		return
	end
	local th = char:FindFirstChildOfClass("Humanoid")
	if not th or th.Health <= 0 then
		return
	end
	local dist = (targetRoot.Position - root.Position).Magnitude
	local meleeRange = Config.NPC.MeleeRange or Config.OITC.MeleeRange or 7
	if dist > meleeRange then
		return
	end
	-- Walls / closed doors must block melee (was a major "invisible death" cause)
	if not losToPlayer(bot, targetRoot, char) then
		return
	end
	faceToward(root, targetRoot.Position)
	local dmg = Config.NPC.MeleeDamage or Config.OITC.MeleeDamage or 100
	local before = th.Health
	th:TakeDamage(dmg)
	if before > 0 and th.Health <= 0 then
		if Config.NPC.RefillAmmoOnKill ~= false then
			refillAmmo(bot)
		end
		announceKill(bot.Name, targetPlayer.Name)
	end
end

local function botFire(bot: Model, targetPlayer: Player, targetRoot: BasePart)
	local root = bot.PrimaryPart
	local hum = bot:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return
	end
	if not playerCanBeDamaged(targetPlayer) then
		return
	end
	local ammoAttr = bot:GetAttribute("BotAmmo")
	local ammo = if typeof(ammoAttr) == "number" then ammoAttr :: number else 0
	if ammo <= 0 then
		return
	end

	local char = targetPlayer.Character
	if not char then
		return
	end
	local th = char:FindFirstChildOfClass("Humanoid")
	if not th or th.Health <= 0 then
		return
	end

	-- Pre-check LOS (walls / closed doors) before spending the OITC bullet
	if not losToPlayer(bot, targetRoot, char) then
		return
	end

	local muzzle = bot:FindFirstChild("Muzzle")
	local origin = root.Position + Vector3.new(0, 1.4, 0)
	if muzzle and muzzle:IsA("BasePart") then
		origin = muzzle.Position
	end
	local aimPoint = targetRoot.Position + Vector3.new(0, 1.2, 0)
	local dir = aimPoint - origin
	local maxRange = Config.NPC.FireRange or 36
	if dir.Magnitude < 0.1 or dir.Magnitude > maxRange then
		return
	end

	faceToward(root, targetRoot.Position)
	bot:SetAttribute("BotAmmo", ammo - 1)

	if muzzle and muzzle:IsA("BasePart") then
		local flash = Instance.new("PointLight")
		flash.Brightness = 3
		flash.Range = 8
		flash.Color = Color3.fromRGB(255, 220, 120)
		flash.Parent = muzzle
		task.delay(0.06, function()
			if flash.Parent then
				flash:Destroy()
			end
		end)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { bot }
	params.IgnoreWater = true

	-- Ray only as far as the target (not past them into open space)
	local castDist = math.min(maxRange, dir.Magnitude + 1.5)
	local result = workspace:Raycast(origin, dir.Unit * castDist, params)
	if not result then
		return
	end

	local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
	if not hitModel then
		return
	end
	local hitHum = hitModel:FindFirstChildOfClass("Humanoid")
	local hitPlr = Players:GetPlayerFromCharacter(hitModel)
	if hitHum and hitHum.Health > 0 and hitPlr == targetPlayer and playerCanBeDamaged(targetPlayer) then
		local dmg = Config.NPC.GunDamage or Config.OITC.GunDamage or 100
		local before = hitHum.Health
		hitHum:TakeDamage(dmg)
		if before > 0 and hitHum.Health <= 0 then
			if Config.NPC.RefillAmmoOnKill ~= false then
				refillAmmo(bot)
			end
			announceKill(bot.Name, targetPlayer.Name)
		end
	end
end

local function moveToAsync(humanoid: Humanoid, bot: Model, target: Vector3)
	local root = bot.PrimaryPart
	if not root then
		humanoid:MoveTo(target)
		return
	end
	local usedPath = false
	pcall(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = 1.5,
			AgentHeight = 5,
			AgentCanJump = true,
			WaypointSpacing = 6,
		})
		path:ComputeAsync(root.Position, target)
		if path.Status ~= Enum.PathStatus.Success then
			return
		end
		usedPath = true
		local wps = path:GetWaypoints()
		for _, wp in wps do
			if not bot.Parent or humanoid.Health <= 0 then
				return
			end
			if wp.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
			humanoid:MoveTo(wp.Position)
			local finished = false
			local conn: RBXScriptConnection?
			conn = humanoid.MoveToFinished:Connect(function()
				finished = true
			end)
			local t0 = os.clock()
			while not finished and bot.Parent and humanoid.Health > 0 and os.clock() - t0 < 2.5 do
				task.wait(0.1)
			end
			if conn then
				conn:Disconnect()
			end
		end
	end)
	if not usedPath then
		humanoid:MoveTo(target)
	end
end

local function brainLoop(bot: Model)
	local humanoid = bot:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local lastFire = 0.0
	local lastMelee = 0.0
	local lastPatrol = 0.0
	local emptySince = 0.0

	task.spawn(function()
		while bot.Parent and humanoid.Parent and humanoid.Health > 0 do
			local root = bot.PrimaryPart
			if root then
				local targetPlr, targetRoot, dist = findTarget(bot)
				local now = os.clock()
				local fireCd = Config.NPC.FireCooldown or 0.85
				local meleeRange = Config.NPC.MeleeRange or 7
				local fireRange = Config.NPC.FireRange or 36
				local ammoAttr = bot:GetAttribute("BotAmmo")
				local ammo = if typeof(ammoAttr) == "number" then ammoAttr :: number else 0
				local hasAmmo = ammo > 0

				if not hasAmmo then
					if emptySince == 0 then
						emptySince = now
					elseif now - emptySince >= (Config.NPC.EmptyAmmoRegenSeconds or 8) then
						refillAmmo(bot)
						hasAmmo = true
						emptySince = 0
					end
				else
					emptySince = 0
				end

				if targetPlr and targetRoot and playerCanBeDamaged(targetPlr) then
					local los = losToPlayer(bot, targetRoot, targetPlr.Character)

					if dist <= meleeRange and los then
						humanoid:MoveTo(targetRoot.Position)
						if now - lastMelee >= (Config.NPC.MeleeCooldown or 0.55) then
							lastMelee = now
							botMelee(bot, targetPlr, targetRoot)
						end
					elseif hasAmmo and dist <= fireRange and los then
						if dist > 18 then
							humanoid:MoveTo(targetRoot.Position)
						elseif now - lastPatrol > 1.2 then
							lastPatrol = now
							local side = root.CFrame.RightVector * (if math.random() > 0.5 then 6 else -6)
							humanoid:MoveTo(root.Position + side)
						end
						if now - lastFire >= fireCd then
							lastFire = now
							botFire(bot, targetPlr, targetRoot)
						end
					else
						if now - lastPatrol > (Config.NPC.PathInterval or 2.2) then
							lastPatrol = now
							if los then
								humanoid:MoveTo(targetRoot.Position)
							else
								moveToAsync(humanoid, bot, targetRoot.Position)
							end
						end
					end
				else
					if now - lastPatrol > (Config.NPC.WanderInterval or 3.5) then
						lastPatrol = now
						local dest = randomWaypoint(root.Position)
						moveToAsync(humanoid, bot, dest)
					end
				end
			end
			task.wait(0.2)
		end
	end)

	humanoid.Died:Connect(function()
		local labelName = bot.Name
		for i = #activeBots, 1, -1 do
			if activeBots[i] == bot then
				table.remove(activeBots, i)
				break
			end
		end
		local delaySec = Config.NPC.RespawnDelay or 5
		task.wait(math.min(2, delaySec * 0.4))
		if bot.Parent then
			bot:Destroy()
		end
		task.wait(math.max(0.5, delaySec - 2))
		NPCService.SpawnOne(labelName)
	end)
end

function NPCService.SpawnOne(name: string?): Model
	local n = name or ((Config.NPC.Name or "Bot") .. " " .. tostring(math.random(10, 99)))
	local pos = nextSpawnPosition()
	local bot = createBot(n, pos)
	table.insert(activeBots, bot)
	brainLoop(bot)
	return bot
end

function NPCService.Init(center: Vector3?)
	if center then
		arenaCenter = center
	end
	spawnIndex = 0
	ensureFolder()
	for _, child in ensureFolder():GetChildren() do
		child:Destroy()
	end
	table.clear(activeBots)
	collectWaypoints()
	local count = Config.NPC.Count or 4
	for i = 1, count do
		NPCService.SpawnOne((Config.NPC.Name or "Bot") .. " " .. tostring(i))
	end
	print(string.format("[CQC] Combat bots ready — %d bots, %d waypoints.", count, #waypoints))
end

function NPCService.IsBot(model: Model?): boolean
	return model ~= nil and model:GetAttribute(BOT_ATTR) == true
end

return NPCService
