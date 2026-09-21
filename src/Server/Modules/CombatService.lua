--!strict
--[[
	Server-authoritative combat: validates fire requests, raycasts, applies damage.
	Per-weapon ammo / cooldown based on the equipped Tool (Shotgun / SMG / Pistol).
	Returns FireResult to the shooter so client can play hitmarkers / tracers only on real outcomes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CombatService = {}

export type PlayerCombatState = {
	ammoByWeapon: { [string]: number },
	reloadingWeapon: string?,
	lastFireByWeapon: { [string]: number },
	kills: number,
	inMatch: boolean,
	preferredWeapon: string,
}

local combatState: { [Player]: PlayerCombatState } = {}
local remotesFolder: Folder? = nil
local fireRemote: RemoteEvent? = nil
local fireResultRemote: RemoteEvent? = nil
local ammoRemote: RemoteEvent? = nil
local killFeedRemote: RemoteEvent? = nil
local statsRemote: RemoteEvent? = nil
local matchStartedRemote: RemoteEvent? = nil

local function getRemotes()
	if remotesFolder and fireRemote and fireResultRemote then
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
	fireResultRemote = ensureRemote(Config.Remotes.FireResult)
	ammoRemote = ensureRemote(Config.Remotes.AmmoUpdate)
	killFeedRemote = ensureRemote(Config.Remotes.KillFeed)
	statsRemote = ensureRemote(Config.Remotes.StatsUpdate)
	matchStartedRemote = ensureRemote(Config.Remotes.MatchStarted)
end

local function ensureAmmoTables(state: PlayerCombatState)
	for _, id in Config.WeaponOrder do
		local def = Config.Weapons[id]
		if def then
			if state.ammoByWeapon[id] == nil then
				state.ammoByWeapon[id] = def.MagazineSize
			end
			if state.lastFireByWeapon[id] == nil then
				state.lastFireByWeapon[id] = 0
			end
		end
	end
end

function CombatService.GetOrCreateState(player: Player): PlayerCombatState
	local state = combatState[player]
	if not state then
		state = {
			ammoByWeapon = {},
			reloadingWeapon = nil,
			lastFireByWeapon = {},
			kills = 0,
			inMatch = false,
			preferredWeapon = Config.DefaultWeaponId,
		}
		combatState[player] = state
	end
	ensureAmmoTables(state)
	return state
end

local function equippedWeapon(player: Player): (Config.WeaponDef?, Tool?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			local def = Config.GetWeaponByToolName(child.Name)
			if def then
				return def, child
			end
		end
	end
	return nil, nil
end

local function pushAmmo(player: Player, weaponId: string?)
	getRemotes()
	local state = combatState[player]
	if not state or not ammoRemote then
		return
	end
	local id = weaponId
	if not id then
		local def = equippedWeapon(player)
		id = if def then def.Id else state.preferredWeapon
	end
	local def = Config.GetWeapon(id :: string)
	if not def then
		return
	end
	local ammo = state.ammoByWeapon[def.Id] or def.MagazineSize
	local reloading = state.reloadingWeapon == def.Id
	ammoRemote:FireClient(player, ammo, def.MagazineSize, reloading, def.Id, def.Name)
end

local function pushStats(player: Player, weaponId: string?)
	getRemotes()
	local state = combatState[player]
	if not state or not statsRemote then
		return
	end
	local id = weaponId or state.preferredWeapon
	local def = Config.GetWeapon(id)
	local ammo = if def then (state.ammoByWeapon[def.Id] or def.MagazineSize) else 0
	local mag = if def then def.MagazineSize else 0
	statsRemote:FireClient(player, {
		kills = state.kills,
		ammo = ammo,
		magSize = mag,
		reloading = state.reloadingWeapon == id,
		weaponId = id,
		weaponName = if def then def.Name else "",
		inMatch = state.inMatch,
	})
end

local function sendFireResult(player: Player, payload: { [string]: any })
	getRemotes()
	if fireResultRemote then
		fireResultRemote:FireClient(player, payload)
	end
end

function CombatService.ResetAmmo(player: Player, weaponId: string?)
	local state = CombatService.GetOrCreateState(player)
	if weaponId then
		local def = Config.GetWeapon(weaponId)
		if def then
			state.ammoByWeapon[weaponId] = def.MagazineSize
			if state.reloadingWeapon == weaponId then
				state.reloadingWeapon = nil
			end
		end
	else
		for _, id in Config.WeaponOrder do
			local def = Config.Weapons[id]
			if def then
				state.ammoByWeapon[id] = def.MagazineSize
			end
		end
		state.reloadingWeapon = nil
	end
	pushAmmo(player, weaponId)
	pushStats(player, weaponId)
end

function CombatService.SetInMatch(player: Player, inMatch: boolean, preferredWeapon: string?)
	local state = CombatService.GetOrCreateState(player)
	state.inMatch = inMatch
	if preferredWeapon and Config.GetWeapon(preferredWeapon) then
		state.preferredWeapon = preferredWeapon
	end
	player:SetAttribute("CQCInMatch", inMatch)
	if preferredWeapon then
		player:SetAttribute("CQCPreferredWeapon", preferredWeapon)
	end
	pushStats(player, state.preferredWeapon)
end

function CombatService.IsInMatch(player: Player): boolean
	return CombatService.GetOrCreateState(player).inMatch
end

function CombatService.StartReload(player: Player)
	local state = CombatService.GetOrCreateState(player)
	if not state.inMatch then
		return
	end
	local def = equippedWeapon(player)
	if not def then
		return
	end
	if state.reloadingWeapon ~= nil then
		return
	end
	local ammo = state.ammoByWeapon[def.Id] or 0
	if ammo >= def.MagazineSize then
		return
	end
	state.reloadingWeapon = def.Id
	pushAmmo(player, def.Id)
	pushStats(player, def.Id)
	sendFireResult(player, {
		kind = "reload",
		ammo = ammo,
		weaponId = def.Id,
	})

	local weaponId = def.Id
	local reloadTime = def.ReloadTime
	task.delay(reloadTime, function()
		if not player.Parent then
			return
		end
		local s = combatState[player]
		if not s or s.reloadingWeapon ~= weaponId then
			return
		end
		local wdef = Config.GetWeapon(weaponId)
		if not wdef then
			s.reloadingWeapon = nil
			return
		end
		s.ammoByWeapon[weaponId] = wdef.MagazineSize
		s.reloadingWeapon = nil
		pushAmmo(player, weaponId)
		pushStats(player, weaponId)
		sendFireResult(player, {
			kind = "reloadDone",
			ammo = s.ammoByWeapon[weaponId],
			weaponId = weaponId,
		})
	end)
end

local function damageFalloff(def: Config.WeaponDef, distance: number): number
	if distance <= def.EffectiveRange then
		return def.DamageClose
	end
	if distance >= def.MaxRange then
		return def.DamageFar
	end
	local t = (distance - def.EffectiveRange) / (def.MaxRange - def.EffectiveRange)
	return def.DamageClose + (def.DamageFar - def.DamageClose) * t
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

local function getMuzzleWorld(tool: Tool, def: Config.WeaponDef, fallback: Vector3): Vector3
	local muzzle = tool:FindFirstChild("Muzzle")
	if muzzle and muzzle:IsA("BasePart") then
		return muzzle.Position
	end
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return (handle.CFrame * CFrame.new(def.MuzzleOffset)).Position
	end
	return fallback
end

function CombatService.HandleFire(player: Player, origin: any, lookVector: any)
	getRemotes()
	if typeof(origin) ~= "Vector3" or typeof(lookVector) ~= "Vector3" then
		return
	end
	if lookVector.Magnitude < 0.1 then
		return
	end

	local state = CombatService.GetOrCreateState(player)
	if not state.inMatch then
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

	local def, tool = equippedWeapon(player)
	if not def or not tool then
		return
	end

	local now = os.clock()
	if state.reloadingWeapon == def.Id then
		sendFireResult(player, { kind = "blocked", reason = "reloading", weaponId = def.Id })
		return
	end
	local last = state.lastFireByWeapon[def.Id] or 0
	if now - last < def.FireCooldown then
		return
	end
	local ammo = state.ammoByWeapon[def.Id] or 0
	if ammo <= 0 then
		sendFireResult(player, { kind = "empty", ammo = 0, weaponId = def.Id })
		CombatService.StartReload(player)
		return
	end

	local fireOrigin = origin :: Vector3
	if (fireOrigin - root.Position).Magnitude > Config.Combat.MaxLookDistanceFromCharacter then
		fireOrigin = root.Position + Vector3.new(0, 1.5, 0)
	end

	state.lastFireByWeapon[def.Id] = now
	state.ammoByWeapon[def.Id] = ammo - 1
	pushAmmo(player, def.Id)
	pushStats(player, def.Id)

	local look = (lookVector :: Vector3).Unit
	local pellets = math.max(1, def.PelletCount)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true

	local damagedThisShot: { [Humanoid]: boolean } = {}
	local hits: { [string]: any } = {}
	local tracers: { [string]: any } = {}
	local muzzlePos = getMuzzleWorld(tool, def, fireOrigin)

	for _ = 1, pellets do
		local dir = if pellets > 1 then applyLookSpread(look, def.SpreadDegrees) else look
		-- Single-pellet weapons still get a tiny cone if SpreadDegrees > 0
		if pellets == 1 and def.SpreadDegrees > 0 then
			dir = applyLookSpread(look, def.SpreadDegrees)
		end
		local result = workspace:Raycast(fireOrigin, dir * def.MaxRange, params)
		local endPos = fireOrigin + dir * def.MaxRange
		local hitSomething = false
		local hitHuman = false

		if result then
			endPos = result.Position
			hitSomething = true
			local hitHumanoid, hitModel = resolveHumanoid(result.Instance)
			if hitHumanoid and hitModel then
				local hitPlayer = Players:GetPlayerFromCharacter(hitModel)
				if hitPlayer ~= player and (Config.Combat.FriendlyFire or not hitPlayer) then
					local distance = (result.Position - fireOrigin).Magnitude
					if distance <= def.MaxRange then
						local dmg = damageFalloff(def, distance)
						local isHead = result.Instance.Name == "Head"
						if isHead then
							dmg *= Config.Combat.HeadshotMultiplier
						end
						dmg = math.max(Config.Combat.MinDamage, math.floor(dmg + 0.5))

						hitHuman = true
						local healthBefore = hitHumanoid.Health
						hitHumanoid:TakeDamage(dmg)
						damagedThisShot[hitHumanoid] = true

						table.insert(hits, {
							position = result.Position,
							damage = dmg,
							headshot = isHead,
							partName = result.Instance.Name,
							victim = hitModel.Name,
						})

						if healthBefore > 0 and hitHumanoid.Health <= 0 then
							state.kills += 1
							pushStats(player, def.Id)
							if killFeedRemote then
								local victimName = if hitPlayer then hitPlayer.Name else hitModel.Name
								killFeedRemote:FireAllClients(player.Name, victimName)
							end
						end
					end
				end
			end
		end

		table.insert(tracers, {
			from = muzzlePos,
			to = endPos,
			hit = hitSomething,
			damaged = hitHuman,
		})
	end

	local anyHeadshot = false
	for _, h in hits do
		if h.headshot then
			anyHeadshot = true
			break
		end
	end

	sendFireResult(player, {
		kind = "shot",
		ammo = state.ammoByWeapon[def.Id],
		muzzle = muzzlePos,
		origin = fireOrigin,
		hits = hits,
		tracers = tracers,
		anyHit = #hits > 0,
		anyHeadshot = anyHeadshot,
		weaponId = def.Id,
	})

	if (state.ammoByWeapon[def.Id] or 0) <= 0 then
		CombatService.StartReload(player)
	end
end

function CombatService.PushEquippedAmmo(player: Player)
	local def = equippedWeapon(player)
	if def then
		pushAmmo(player, def.Id)
		pushStats(player, def.Id)
	end
end

function CombatService.NotifyMatchStarted(player: Player, weaponId: string)
	getRemotes()
	if matchStartedRemote then
		matchStartedRemote:FireClient(player, { weaponId = weaponId, inMatch = true })
	end
	pushAmmo(player, weaponId)
	pushStats(player, weaponId)
end

function CombatService.Init()
	getRemotes()
	assert(fireRemote)
	fireRemote.OnServerEvent:Connect(function(player, origin, lookVector)
		CombatService.HandleFire(player, origin, lookVector)
	end)

	Players.PlayerRemoving:Connect(function(player)
		combatState[player] = nil
	end)

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("CQCInMatch", false)
		player:SetAttribute("CQCPreferredWeapon", Config.DefaultWeaponId)
	end)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("CQCInMatch", false)
		player:SetAttribute("CQCPreferredWeapon", Config.DefaultWeaponId)
	end
end

return CombatService
