--!strict
--[[
	Server match / mode tracking.
	Modes: Casual (three-gun freeplay) vs One in the Chamber (OITC).
	OITC: track kills toward Config.OITC.KillsToWin, award ammo on kill, end match on win.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local GameModeService = {}

export type ModeId = string -- "Casual" | "OITC"

local playerMode: { [Player]: ModeId } = {}
local oitcScore: { [Player]: number } = {}
local matchOver: { [Player]: boolean } = {}
local remotesFolder: Folder? = nil
local matchEndedRemote: RemoteEvent? = nil
local returnToHubRemote: RemoteEvent? = nil
local statsRemote: RemoteEvent? = nil

-- Late-bound to avoid circular require at load time
local CombatService: any = nil
local WeaponService: any = nil

local function getRemotes()
	if remotesFolder and matchEndedRemote and returnToHubRemote then
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
	matchEndedRemote = ensureRemote(Config.Remotes.MatchEnded)
	returnToHubRemote = ensureRemote(Config.Remotes.ReturnToHub)
	statsRemote = ensureRemote(Config.Remotes.StatsUpdate)
end

local function bindDeps()
	if not CombatService then
		CombatService = require(script.Parent:WaitForChild("CombatService"))
	end
	if not WeaponService then
		WeaponService = require(script.Parent:WaitForChild("WeaponService"))
	end
end

function GameModeService.NormalizeMode(mode: any): ModeId
	if mode == Config.Modes.OITC or mode == "OITC" or mode == "OneInTheChamber" then
		return Config.Modes.OITC
	end
	return Config.Modes.Casual
end

function GameModeService.GetMode(player: Player): ModeId
	return playerMode[player] or Config.DefaultMode
end

function GameModeService.IsOITC(player: Player): boolean
	return GameModeService.GetMode(player) == Config.Modes.OITC
end

function GameModeService.GetOITCScore(player: Player): number
	return oitcScore[player] or 0
end

function GameModeService.IsMatchOver(player: Player): boolean
	return matchOver[player] == true
end

function GameModeService.PushModeStats(player: Player)
	getRemotes()
	bindDeps()
	if not statsRemote then
		return
	end
	local mode = GameModeService.GetMode(player)
	local score = oitcScore[player] or 0
	local state = CombatService.GetOrCreateState(player)
	local ammo = 0
	local mag = 0
	local weaponId = state.preferredWeapon
	local weaponName = ""
	local def = Config.GetWeapon(weaponId)
	if def then
		ammo = state.ammoByWeapon[def.Id] or 0
		mag = if mode == Config.Modes.OITC then Config.OITC.MagazineDisplay else def.MagazineSize
		weaponName = def.Name
	end
	local meleeReady = mode == Config.Modes.OITC and ammo <= 0
	statsRemote:FireClient(player, {
		kills = if mode == Config.Modes.OITC then score else state.kills,
		oitcScore = score,
		killsToWin = Config.OITC.KillsToWin,
		mode = mode,
		ammo = ammo,
		magSize = mag,
		reloading = state.reloadingWeapon == weaponId,
		weaponId = weaponId,
		weaponName = if meleeReady then Config.OITC.MeleeToolName else weaponName,
		inMatch = state.inMatch,
		meleeReady = meleeReady,
		matchOver = matchOver[player] == true,
	})
end

function GameModeService.ResetPlayer(player: Player)
	oitcScore[player] = 0
	matchOver[player] = false
	player:SetAttribute("CQCMode", playerMode[player] or Config.DefaultMode)
	player:SetAttribute("CQCOITCScore", 0)
	player:SetAttribute("CQCMatchOver", false)
end

function GameModeService.SetMode(player: Player, mode: ModeId)
	playerMode[player] = mode
	player:SetAttribute("CQCMode", mode)
end

--[[
	Called by CombatService when killer scores a kill (gun or melee).
	Awards +1 OITC ammo and increments OITC score toward win.
]]
function GameModeService.OnKill(killer: Player, _victimName: string, _viaMelee: boolean?)
	bindDeps()
	if matchOver[killer] then
		return
	end
	if not GameModeService.IsOITC(killer) then
		return
	end

	-- Award bullet
	CombatService.AwardOITCAmmo(killer, 1)

	oitcScore[killer] = (oitcScore[killer] or 0) + 1
	killer:SetAttribute("CQCOITCScore", oitcScore[killer])
	GameModeService.PushModeStats(killer)

	if oitcScore[killer] >= Config.OITC.KillsToWin then
		GameModeService.EndMatch(killer)
	end
end

function GameModeService.EndMatch(winner: Player)
	getRemotes()
	bindDeps()
	if matchOver[winner] then
		return
	end
	matchOver[winner] = true
	winner:SetAttribute("CQCMatchOver", true)

	local score = oitcScore[winner] or 0
	local mode = GameModeService.GetMode(winner)

	-- Notify all clients (or at least winner); FireAllClients keeps spectators informed
	if matchEndedRemote then
		matchEndedRemote:FireAllClients({
			winnerName = winner.Name,
			winnerUserId = winner.UserId,
			mode = mode,
			kills = score,
			killsToWin = Config.OITC.KillsToWin,
		})
	end

	-- Strip weapons / stop combat for winner after a beat; optional auto-return
	task.delay(Config.OITC.WinnerRestartSeconds, function()
		if not winner.Parent then
			return
		end
		if matchOver[winner] then
			GameModeService.ReturnPlayerToHub(winner)
		end
	end)
end

function GameModeService.ReturnPlayerToHub(player: Player)
	bindDeps()
	getRemotes()
	CombatService.SetInMatch(player, false, nil)
	WeaponService.StripAll(player)
	GameModeService.ResetPlayer(player)
	playerMode[player] = Config.DefaultMode
	player:SetAttribute("CQCMode", Config.DefaultMode)
	player:SetAttribute("CQCInMatch", false)
	if returnToHubRemote then
		returnToHubRemote:FireClient(player, { reason = "hub" })
	end
	GameModeService.PushModeStats(player)
end

function GameModeService.StartMatch(player: Player, modeRaw: any, weaponIdRaw: any)
	bindDeps()
	getRemotes()
	local mode = GameModeService.NormalizeMode(modeRaw)
	GameModeService.SetMode(player, mode)
	GameModeService.ResetPlayer(player)
	matchOver[player] = false
	player:SetAttribute("CQCMatchOver", false)

	local weaponId = Config.DefaultWeaponId
	if mode == Config.Modes.OITC then
		weaponId = Config.OITC.WeaponId
	elseif typeof(weaponIdRaw) == "string" and Config.GetWeapon(weaponIdRaw) then
		weaponId = weaponIdRaw
	end

	WeaponService.GiveLoadout(player, weaponId, mode)
end

function GameModeService.Init()
	getRemotes()
	bindDeps()

	assert(returnToHubRemote)
	returnToHubRemote.OnServerEvent:Connect(function(player)
		GameModeService.ReturnPlayerToHub(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerMode[player] = nil
		oitcScore[player] = nil
		matchOver[player] = nil
	end)

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("CQCMode", Config.DefaultMode)
		player:SetAttribute("CQCOITCScore", 0)
		player:SetAttribute("CQCMatchOver", false)
	end)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("CQCMode", Config.DefaultMode)
		player:SetAttribute("CQCOITCScore", 0)
		player:SetAttribute("CQCMatchOver", false)
	end
end

return GameModeService
