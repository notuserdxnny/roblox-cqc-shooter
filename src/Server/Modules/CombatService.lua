--!strict
--[[
	Server-authoritative combat: validates fire requests, raycasts, applies damage.
	Per-weapon ammo / cooldown based on the equipped Tool (Shotgun / SMG / Pistol).
	OITC: no reload, ammo is bullet count, kills award +1 ammo via GameModeService,
	melee short-range raycast when empty.
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
	lastMelee: number,
	kills: number,
	inMatch: boolean,
	preferredWeapon: string,
	mode: string,
}

local combatState: { [Player]: PlayerCombatState } = {}
local remotesFolder: Folder? = nil
local fireRemote: RemoteEvent? = nil
local fireResultRemote: RemoteEvent? = nil
local ammoRemote: RemoteEvent? = nil
local killFeedRemote: RemoteEvent? = nil
local statsRemote: RemoteEvent? = nil
local matchStartedRemote: RemoteEvent? = nil
local meleeRemote: RemoteEvent? = nil

local GameModeService: any = nil

local function getGameMode()
	if not GameModeService then
		GameModeService = require(script.Parent:WaitForChild("GameModeService"))
	end
	return GameModeService
end

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
	meleeRemote = ensureRemote(Config.Remotes.MeleeAttack)
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
			lastMelee = 0,
			kills = 0,
			inMatch = false,
			preferredWeapon = Config.DefaultWeaponId,
			mode = Config.DefaultMode,
		}
		combatState[player] = state
	end
	ensureAmmoTables(state)
	return state
end

local function isOITC(player: Player): boolean
	local state = combatState[player]
	if state and state.mode == Config.Modes.OITC then
		return true
	end
	return getGameMode().IsOITC(player)
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

local function equippedKnife(player: Player): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	local knifeName = Config.OITC.MeleeToolName
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and (child.Name == knifeName or child:GetAttribute("IsMelee") == true) then
			return child
		end
	end
	return nil
end

local function magDisplay(player: Player, def: Config.WeaponDef): number
	if isOITC(player) then
		return Config.OITC.MagazineDisplay
	end
	return def.MagazineSize
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
	local ammo = state.ammoByWeapon[def.Id] or 0
	local reloading = state.reloadingWeapon == def.Id
	local displayName = def.Name
	if isOITC(player) and ammo <= 0 then
		displayName = Config.OITC.MeleeToolName
	end
	ammoRemote:FireClient(player, ammo, magDisplay(player, def), reloading, def.Id, displayName)
end

local function pushStats(player: Player, weaponId: string?)
	getRemotes()
	local state = combatState[player]
	if not state or not statsRemote then
		return
	end
	local id = weaponId or state.preferredWeapon
	local def = Config.GetWeapon(id)
	local ammo = if def then (state.ammoByWeapon[def.Id] or 0) else 0
	local mag = if def then magDisplay(player, def) else 0
	local mode = state.mode
	local gms = getGameMode()
	local oitcScore = gms.GetOITCScore(player)
	local meleeReady = ammo <= 0
	local displayKills = oitcScore
	local weaponName = if def then def.Name else ""
	if meleeReady then
		weaponName = Config.OITC.MeleeToolName
	end
	local ktw = Config.OITC.KillsToWin
	if typeof(gms.GetKillsToWin) == "function" then
		ktw = gms.GetKillsToWin(player)
	end
	statsRemote:FireClient(player, {
		kills = displayKills,
		oitcScore = oitcScore,
		killsToWin = ktw,
		mode = mode,
		ammo = ammo,
		magSize = mag,
		reloading = state.reloadingWeapon == id,
		weaponId = id,
		weaponName = weaponName,
		inMatch = state.inMatch,
		meleeReady = meleeReady,
		matchOver = gms.IsMatchOver(player),
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
	local oitc = isOITC(player)
	if weaponId then
		local def = Config.GetWeapon(weaponId)
		if def then
			if oitc and weaponId == Config.OITC.WeaponId then
				state.ammoByWeapon[weaponId] = Config.OITC.StartingAmmo
			else
				state.ammoByWeapon[weaponId] = def.MagazineSize
			end
			if state.reloadingWeapon == weaponId then
				state.reloadingWeapon = nil
			end
		end
	else
		for _, id in Config.WeaponOrder do
			local def = Config.Weapons[id]
			if def then
				if id == Config.OITC.WeaponId then
					state.ammoByWeapon[id] = Config.OITC.StartingAmmo
				else
					state.ammoByWeapon[id] = 0
				end
			end
		end
		state.reloadingWeapon = nil
	end
	pushAmmo(player, weaponId)
	pushStats(player, weaponId)
end

function CombatService.AwardOITCAmmo(player: Player, amount: number)
	local state = CombatService.GetOrCreateState(player)
	local wid = Config.OITC.WeaponId
	state.ammoByWeapon[wid] = (state.ammoByWeapon[wid] or 0) + amount
	state.reloadingWeapon = nil
	pushAmmo(player, wid)
	pushStats(player, wid)
	if (state.ammoByWeapon[wid] or 0) > 0 then
		CombatService.TryEquipPistol(player)
	end
end

function CombatService.SetInMatch(player: Player, inMatch: boolean, preferredWeapon: string?, mode: string?)
	local state = CombatService.GetOrCreateState(player)
	state.inMatch = inMatch
	if preferredWeapon and Config.GetWeapon(preferredWeapon) then
		state.preferredWeapon = preferredWeapon
	end
	if mode then
		state.mode = mode
	end
	player:SetAttribute("CQCInMatch", inMatch)
	if preferredWeapon then
		player:SetAttribute("CQCPreferredWeapon", preferredWeapon)
	end
	if mode then
		player:SetAttribute("CQCMode", mode)
	end
	pushStats(player, state.preferredWeapon)
end

function CombatService.SetMode(player: Player, mode: string)
	local state = CombatService.GetOrCreateState(player)
	state.mode = mode
	player:SetAttribute("CQCMode", mode)
end

function CombatService.ResetMatchStats(player: Player)
	local state = CombatService.GetOrCreateState(player)
	state.kills = 0
	state.reloadingWeapon = nil
	state.lastMelee = 0
	for id in state.lastFireByWeapon do
		state.lastFireByWeapon[id] = 0
	end
end

function CombatService.IsInMatch(player: Player): boolean
	return CombatService.GetOrCreateState(player).inMatch
end

function CombatService.StartReload(player: Player)
	local state = CombatService.GetOrCreateState(player)
	if not state.inMatch then
		return
	end
	-- OITC never reloads from reserve — bullets only come from kills / spawn
	if isOITC(player) then
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
		if s.mode == Config.Modes.OITC then
			s.reloadingWeapon = nil
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

local function creditKill(player: Player, state: PlayerCombatState, hitPlayer: Player?, hitModel: Model, viaMelee: boolean, weaponId: string?)
	state.kills += 1
	pushStats(player, weaponId)
	local victimName = if hitPlayer then hitPlayer.Name else hitModel.Name
	if killFeedRemote then
		killFeedRemote:FireAllClients(player.Name, victimName)
	end
	getGameMode().OnKill(player, victimName, viaMelee)
end


function CombatService.TryEquipMelee(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local knifeName = Config.OITC.MeleeToolName
	local knife: Tool? = nil
	for _, c in character:GetChildren() do
		if c:IsA("Tool") and c.Name == knifeName then
			return -- already holding knife
		end
	end
	if backpack then
		local k = backpack:FindFirstChild(knifeName)
		if k and k:IsA("Tool") then
			knife = k
		end
	end
	if knife then
		humanoid:EquipTool(knife)
	end
end

function CombatService.TryEquipPistol(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local pistolName = Config.Weapons.Pistol.Name
	for _, c in character:GetChildren() do
		if c:IsA("Tool") and c.Name == pistolName then
			return
		end
	end
	local pistol: Tool? = nil
	if backpack then
		local k = backpack:FindFirstChild(pistolName)
		if k and k:IsA("Tool") then
			pistol = k
		end
	end
	if pistol then
		humanoid:EquipTool(pistol)
	end
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
	if getGameMode().IsMatchOver(player) then
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
		-- If OITC empty and knife equipped, route to melee
		if isOITC(player) then
			local ammo = state.ammoByWeapon[Config.OITC.WeaponId] or 0
			if ammo <= 0 then
				CombatService.HandleMelee(player, origin, lookVector)
			end
		end
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
		if isOITC(player) then
			-- LMB with empty magazine = melee (classic OITC). Also equip knife.
			CombatService.TryEquipMelee(player)
			CombatService.HandleMelee(player, origin, lookVector)
			return
		end
		sendFireResult(player, { kind = "empty", ammo = 0, weaponId = def.Id, meleeReady = false })
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

	local hits: { [string]: any } = {}
	local tracers: { [string]: any } = {}
	local muzzlePos = getMuzzleWorld(tool, def, fireOrigin)

	for _ = 1, pellets do
		local dir = if pellets > 1 then applyLookSpread(look, def.SpreadDegrees) else look
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
						local isHead = result.Instance.Name == "Head"
						local dmg: number
						if isOITC(player) then
							dmg = Config.OITC.GunDamage
						else
							dmg = damageFalloff(def, distance)
							if isHead then
								dmg *= Config.Combat.HeadshotMultiplier
							end
							dmg = math.max(Config.Combat.MinDamage, math.floor(dmg + 0.5))
						end

						hitHuman = true
						local healthBefore = hitHumanoid.Health
						hitHumanoid:TakeDamage(dmg)

						table.insert(hits, {
							position = result.Position,
							damage = dmg,
							headshot = isHead,
							partName = result.Instance.Name,
							victim = hitModel.Name,
						})

						if healthBefore > 0 and hitHumanoid.Health <= 0 then
							creditKill(player, state, hitPlayer, hitModel, false, def.Id)
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
		meleeReady = isOITC(player) and (state.ammoByWeapon[def.Id] or 0) <= 0,
	})

	if not isOITC(player) and (state.ammoByWeapon[def.Id] or 0) <= 0 then
		CombatService.StartReload(player)
	elseif isOITC(player) and (state.ammoByWeapon[def.Id] or 0) <= 0 then
		CombatService.TryEquipMelee(player)
	end
end

function CombatService.HandleMelee(player: Player, origin: any, lookVector: any)
	getRemotes()
	if typeof(origin) ~= "Vector3" or typeof(lookVector) ~= "Vector3" then
		return
	end
	if lookVector.Magnitude < 0.1 then
		return
	end

	local state = CombatService.GetOrCreateState(player)
	if not state.inMatch or not isOITC(player) then
		return
	end
	if getGameMode().IsMatchOver(player) then
		return
	end

	local ammo = state.ammoByWeapon[Config.OITC.WeaponId] or 0
	local holdingKnife = equippedKnife(player) ~= nil
	-- Allow melee when knife is equipped OR when out of bullets.
	-- (Previously ammo>0 always blocked — knife Tool.Activated did nothing after a kill refill.)
	if ammo > 0 and not holdingKnife then
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

	local now = os.clock()
	if now - state.lastMelee < Config.OITC.MeleeCooldown then
		return
	end
	state.lastMelee = now

	local fireOrigin = origin :: Vector3
	if (fireOrigin - root.Position).Magnitude > Config.Combat.MaxLookDistanceFromCharacter then
		fireOrigin = root.Position + Vector3.new(0, 1.2, 0)
	end
	local look = (lookVector :: Vector3).Unit
	local range = Config.OITC.MeleeRange

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true

	local result = workspace:Raycast(fireOrigin, look * range, params)
	local endPos = fireOrigin + look * range
	local hits: { [string]: any } = {}
	local hitHuman = false

	local function applyMeleeHit(hitResult: RaycastResult)
		endPos = hitResult.Position
		local hitHumanoid, hitModel = resolveHumanoid(hitResult.Instance)
		if hitHumanoid and hitModel then
			local hitPlayer = Players:GetPlayerFromCharacter(hitModel)
			if hitPlayer ~= player and (Config.Combat.FriendlyFire or not hitPlayer) then
				local dmg = Config.OITC.MeleeDamage
				local healthBefore = hitHumanoid.Health
				hitHumanoid:TakeDamage(dmg)
				hitHuman = true
				table.insert(hits, {
					position = hitResult.Position,
					damage = dmg,
					headshot = false,
					partName = hitResult.Instance.Name,
					victim = hitModel.Name,
					melee = true,
				})
				if healthBefore > 0 and hitHumanoid.Health <= 0 then
					creditKill(player, state, hitPlayer, hitModel, true, Config.OITC.WeaponId)
				end
			end
		end
	end

	if result then
		applyMeleeHit(result)
	else
		-- Fallback: forward from HRP (helps if camera origin was clipped)
		local rootLook = root.CFrame.LookVector
		local fallback = workspace:Raycast(root.Position + Vector3.new(0, 1.2, 0), rootLook * range, params)
		if fallback then
			applyMeleeHit(fallback)
		end
	end

	sendFireResult(player, {
		kind = "melee",
		ammo = state.ammoByWeapon[Config.OITC.WeaponId] or 0,
		origin = fireOrigin,
		to = endPos,
		hits = hits,
		anyHit = #hits > 0,
		anyHeadshot = false,
		weaponId = "Melee",
		meleeReady = (state.ammoByWeapon[Config.OITC.WeaponId] or 0) <= 0,
	})
	pushStats(player, Config.OITC.WeaponId)
end

function CombatService.PushEquippedAmmo(player: Player)
	local def = equippedWeapon(player)
	if def then
		pushAmmo(player, def.Id)
		pushStats(player, def.Id)
	elseif isOITC(player) then
		pushAmmo(player, Config.OITC.WeaponId)
		pushStats(player, Config.OITC.WeaponId)
	end
end

function CombatService.NotifyMatchStarted(player: Player, weaponId: string, mode: string?)
	getRemotes()
	local m = mode or CombatService.GetOrCreateState(player).mode
	local ktw = Config.OITC.KillsToWin
	local gms = getGameMode()
	if typeof(gms.GetKillsToWin) == "function" then
		ktw = gms.GetKillsToWin(player)
	end
	if matchStartedRemote then
		matchStartedRemote:FireClient(player, {
			weaponId = weaponId,
			mode = m,
			inMatch = true,
			killsToWin = ktw,
		})
	end
	pushAmmo(player, weaponId)
	pushStats(player, weaponId)
end

function CombatService.Init()
	getRemotes()
	assert(fireRemote)
	fireRemote.OnServerEvent:Connect(function(player, origin, lookVector)
		-- String commands handled in WeaponService; Vector3 fire here
		if typeof(origin) == "Vector3" then
			CombatService.HandleFire(player, origin, lookVector)
		end
	end)

	assert(meleeRemote)
	meleeRemote.OnServerEvent:Connect(function(player, origin, lookVector)
		CombatService.HandleMelee(player, origin, lookVector)
	end)

	Players.PlayerRemoving:Connect(function(player)
		combatState[player] = nil
	end)

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("CQCInMatch", false)
		player:SetAttribute("CQCPreferredWeapon", Config.DefaultWeaponId)
		player:SetAttribute("CQCMode", Config.DefaultMode)
	end)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("CQCInMatch", false)
		player:SetAttribute("CQCPreferredWeapon", Config.DefaultWeaponId)
		player:SetAttribute("CQCMode", Config.DefaultMode)
	end
end

return CombatService
