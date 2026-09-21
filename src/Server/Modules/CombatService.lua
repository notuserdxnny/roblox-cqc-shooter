--!strict
--[[
	Server-authoritative combat: validates fire requests, raycasts, applies damage.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CombatService = {}

export type PlayerWeaponState = {
	ammo: number,
	reloading: boolean,
	lastFireTime: number,
	kills: number,
}

local weaponState: { [Player]: PlayerWeaponState } = {}
local remotesFolder: Folder? = nil
local fireRemote: RemoteEvent? = nil
local ammoRemote: RemoteEvent? = nil
local killFeedRemote: RemoteEvent? = nil
local statsRemote: RemoteEvent? = nil

local function getRemotes()
	if remotesFolder then
		return
	end
	remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
	end

	local function ensureRemote(name: string): RemoteEvent
		local existing = remotesFolder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotesFolder
		return r
	end

	fireRemote = ensureRemote(Config.Remotes.FireWeapon)
	ammoRemote = ensureRemote(Config.Remotes.AmmoUpdate)
	killFeedRemote = ensureRemote(Config.Remotes.KillFeed)
	statsRemote = ensureRemote(Config.Remotes.StatsUpdate)
end

local function pushAmmo(player: Player)
	getRemotes()
	local state = weaponState[player]
	if state and ammoRemote then
		ammoRemote:FireClient(player, state.ammo, Config.Weapon.MagazineSize, state.reloading)
	end
end

local function pushStats(player: Player)
	getRemotes()
	local state = weaponState[player]
	if state and statsRemote then
		statsRemote:FireClient(player, {
			kills = state.kills,
			ammo = state.ammo,
			magSize = Config.Weapon.MagazineSize,
			reloading = state.reloading,
		})
	end
end

function CombatService.GetOrCreateState(player: Player): PlayerWeaponState
	local state = weaponState[player]
	if not state then
		state = {
			ammo = Config.Weapon.MagazineSize,
			reloading = false,
			lastFireTime = 0,
			kills = 0,
		}
		weaponState[player] = state
	end
	return state
end

function CombatService.ResetAmmo(player: Player)
	local state = CombatService.GetOrCreateState(player)
	state.ammo = Config.Weapon.MagazineSize
	state.reloading = false
	pushAmmo(player)
	pushStats(player)
end

function CombatService.StartReload(player: Player)
	local state = CombatService.GetOrCreateState(player)
	if state.reloading then
		return
	end
	if state.ammo >= Config.Weapon.MagazineSize then
		return
	end
	state.reloading = true
	pushAmmo(player)
	pushStats(player)

	task.delay(Config.Weapon.ReloadTime, function()
		if not player.Parent then
			return
		end
		local s = weaponState[player]
		if not s or not s.reloading then
			return
		end
		s.ammo = Config.Weapon.MagazineSize
		s.reloading = false
		pushAmmo(player)
		pushStats(player)
	end)
end

local function damageFalloff(distance: number): number
	local w = Config.Weapon
	if distance <= w.EffectiveRange then
		return w.DamageClose
	end
	if distance >= w.MaxRange then
		return w.DamageFar
	end
	local t = (distance - w.EffectiveRange) / (w.MaxRange - w.EffectiveRange)
	return w.DamageClose + (w.DamageFar - w.DamageClose) * t
end

local function resolveHumanoid(part: BasePart): (Humanoid?, Model?)
	local model = part:FindFirstAncestorOfClass("Model")
	if not model then
		return nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid, model
	end
	return nil, nil
end

local function applyLookSpread(look: Vector3, degrees: number): Vector3
	if degrees <= 0 then
		return look.Unit
	end
	local rad = math.rad(degrees)
	local axis = if math.abs(look.Y) < 0.99 then Vector3.yAxis else Vector3.xAxis
	local right = look:Cross(axis).Unit
	local up = right:Cross(look).Unit
	local yaw = (math.random() * 2 - 1) * rad
	local pitch = (math.random() * 2 - 1) * rad
	local dir = (look + right * math.tan(yaw) + up * math.tan(pitch)).Unit
	return dir
end

function CombatService.HandleFire(player: Player, origin: any, lookVector: any)
	getRemotes()
	if typeof(origin) ~= "Vector3" or typeof(lookVector) ~= "Vector3" then
		return
	end
	if lookVector.Magnitude < 0.1 then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end

	-- Must be holding the tool
	local tool = character:FindFirstChild(Config.Weapon.Name)
	if not tool or not tool:IsA("Tool") then
		return
	end

	local state = CombatService.GetOrCreateState(player)
	local now = os.clock()
	if state.reloading then
		return
	end
	if now - state.lastFireTime < Config.Weapon.FireCooldown then
		return
	end
	if state.ammo <= 0 then
		CombatService.StartReload(player)
		return
	end

	-- Origin must be near the character (anti-cheat lite)
	if (origin :: Vector3 - root.Position).Magnitude > Config.Combat.MaxLookDistanceFromCharacter then
		origin = root.Position + Vector3.new(0, 1.5, 0)
	end

	state.lastFireTime = now
	state.ammo -= 1
	pushAmmo(player)
	pushStats(player)

	local look = (lookVector :: Vector3).Unit
	local pellets = math.max(1, Config.Weapon.PelletCount)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true

	local damagedThisShot: { [Humanoid]: boolean } = {}

	for _ = 1, pellets do
		local dir = if pellets > 1 then applyLookSpread(look, Config.Weapon.SpreadDegrees) else look
		local result = workspace:Raycast(origin :: Vector3, dir * Config.Weapon.MaxRange, params)
		if not result then
			continue
		end

		local hitHumanoid, hitModel = resolveHumanoid(result.Instance)
		if not hitHumanoid or not hitModel or damagedThisShot[hitHumanoid] then
			continue
		end

		-- Optional: skip same team / self
		local hitPlayer = Players:GetPlayerFromCharacter(hitModel)
		if hitPlayer == player then
			continue
		end
		if not Config.Combat.FriendlyFire and hitPlayer then
			continue
		end

		local distance = (result.Position - (origin :: Vector3)).Magnitude
		if distance > Config.Weapon.MaxRange then
			continue
		end

		local dmg = damageFalloff(distance)
		local isHead = result.Instance.Name == "Head"
		if isHead then
			dmg *= Config.Combat.HeadshotMultiplier
		end
		dmg = math.max(Config.Combat.MinDamage, math.floor(dmg + 0.5))

		damagedThisShot[hitHumanoid] = true
		local wasAlive = hitHumanoid.Health > 0
		hitHumanoid:TakeDamage(dmg)

		if wasAlive and hitHumanoid.Health <= 0 then
			state.kills += 1
			pushStats(player)
			if killFeedRemote then
				local victimName = if hitPlayer then hitPlayer.Name else hitModel.Name
				killFeedRemote:FireAllClients(player.Name, victimName)
			end
		end
	end

	if state.ammo <= 0 then
		CombatService.StartReload(player)
	end
end

function CombatService.Init()
	getRemotes()
	assert(fireRemote)
	fireRemote.OnServerEvent:Connect(function(player, origin, lookVector)
		CombatService.HandleFire(player, origin, lookVector)
	end)

	Players.PlayerRemoving:Connect(function(player)
		weaponState[player] = nil
	end)
end

return CombatService
