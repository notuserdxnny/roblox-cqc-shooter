--!strict
--[[
	Server match / mode tracking — OITC-only for now.
	Start flow: teleport frozen → MatchCountdown → GO → pistol+knife loadout + InMatch.
	Win: freeze briefly, MatchEnded overlay (Play Again / Hub). KillsToWin from Config.OITC.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local GameModeService = {}

export type ModeId = string -- "OITC"

local playerMode: { [Player]: ModeId } = {}
local oitcScore: { [Player]: number } = {}
local matchOver: { [Player]: boolean } = {}
local preferredWeapon: { [Player]: string } = {}
local matchStartClock: { [Player]: number } = {}
local countdownToken: { [Player]: number } = {}
local remotesFolder: Folder? = nil
local matchEndedRemote: RemoteEvent? = nil
local matchCountdownRemote: RemoteEvent? = nil
local returnToHubRemote: RemoteEvent? = nil
local statsRemote: RemoteEvent? = nil

local CombatService: any = nil
local WeaponService: any = nil
local LobbyService: any = nil

local function getRemotes()
	if remotesFolder and matchEndedRemote and returnToHubRemote and matchCountdownRemote then
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
	matchCountdownRemote = ensureRemote(Config.Remotes.MatchCountdown)
	returnToHubRemote = ensureRemote(Config.Remotes.ReturnToHub)
	statsRemote = ensureRemote(Config.Remotes.StatsUpdate)
end

local PlayerDataService: any = nil

local function bindDeps()
	if not CombatService then
		CombatService = require(script.Parent:WaitForChild("CombatService"))
	end
	if not WeaponService then
		WeaponService = require(script.Parent:WaitForChild("WeaponService"))
	end
	if not LobbyService then
		LobbyService = require(script.Parent:WaitForChild("LobbyService"))
	end
	if not PlayerDataService then
		PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
	end
end

local function winnerRestartSeconds(): number
	if Config.Match and typeof(Config.Match.WinnerRestartSeconds) == "number" then
		return Config.Match.WinnerRestartSeconds
	end
	return Config.OITC.WinnerRestartSeconds or 20
end

function GameModeService.NormalizeMode(_mode: any): ModeId
	-- OITC-only: ignore client mode payload
	return Config.Modes.OITC
end

function GameModeService.GetMode(player: Player): ModeId
	return playerMode[player] or Config.Modes.OITC
end

function GameModeService.IsOITC(_player: Player): boolean
	return true
end

function GameModeService.GetOITCScore(player: Player): number
	return oitcScore[player] or 0
end

function GameModeService.IsMatchOver(player: Player): boolean
	return matchOver[player] == true
end

function GameModeService.GetKillsToWin(_player: Player): number
	return Config.OITC.KillsToWin
end

function GameModeService.PushModeStats(player: Player)
	getRemotes()
	bindDeps()
	if not statsRemote then
		return
	end
	local mode = Config.Modes.OITC
	local score = oitcScore[player] or 0
	local state = CombatService.GetOrCreateState(player)
	local ammo = 0
	local mag = Config.OITC.MagazineDisplay
	local weaponId = state.preferredWeapon
	local weaponName = ""
	local def = Config.GetWeapon(weaponId)
	if def then
		ammo = state.ammoByWeapon[def.Id] or 0
		weaponName = def.Name
	end
	local meleeReady = ammo <= 0
	local ktw = Config.OITC.KillsToWin
	local credits = 0
	if PlayerDataService then
		credits = PlayerDataService.GetCredits(player)
	elseif typeof(player:GetAttribute("CQCCredits")) == "number" then
		credits = player:GetAttribute("CQCCredits") :: number
	end
	statsRemote:FireClient(player, {
		kills = score,
		oitcScore = score,
		killsToWin = ktw,
		mode = mode,
		ammo = ammo,
		magSize = mag,
		reloading = state.reloadingWeapon == weaponId,
		weaponId = weaponId,
		weaponName = if meleeReady then Config.OITC.MeleeToolName else weaponName,
		inMatch = state.inMatch,
		meleeReady = meleeReady,
		matchOver = matchOver[player] == true,
		countdown = player:GetAttribute("CQCCountdown") == true,
		credits = credits,
	})
end

function GameModeService.ResetPlayer(player: Player)
	oitcScore[player] = 0
	matchOver[player] = false
	matchStartClock[player] = nil
	playerMode[player] = Config.Modes.OITC
	player:SetAttribute("CQCMode", Config.Modes.OITC)
	player:SetAttribute("CQCOITCScore", 0)
	player:SetAttribute("CQCMatchOver", false)
	player:SetAttribute("CQCCountdown", false)
end

function GameModeService.SetMode(player: Player, _mode: ModeId)
	playerMode[player] = Config.Modes.OITC
	player:SetAttribute("CQCMode", Config.Modes.OITC)
end

--[[
	Called by CombatService when killer scores a kill (gun or melee).
	OITC: +1 ammo and score; check Config.OITC.KillsToWin.
]]
function GameModeService.OnKill(killer: Player, _victimName: string, _viaMelee: boolean?)
	bindDeps()
	if matchOver[killer] then
		return
	end
	if not CombatService.IsInMatch(killer) then
		return
	end

	CombatService.AwardOITCAmmo(killer, 1)
	oitcScore[killer] = (oitcScore[killer] or 0) + 1
	killer:SetAttribute("CQCOITCScore", oitcScore[killer])
	if PlayerDataService then
		PlayerDataService.AddCredits(killer, Config.Economy.CreditsPerKill or 25, "kill")
	end
	GameModeService.PushModeStats(killer)
	local need = Config.OITC.KillsToWin
	if oitcScore[killer] >= need then
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
	winner:SetAttribute("CQCCountdown", false)

	local mode = Config.Modes.OITC
	local score = oitcScore[winner] or 0
	local need = Config.OITC.KillsToWin
	local duration = 0
	local started = matchStartClock[winner]
	if typeof(started) == "number" then
		duration = math.max(0, os.clock() - started)
	end

	LobbyService.FreezeForLobby(winner)
	if PlayerDataService then
		PlayerDataService.AddCredits(winner, Config.Economy.CreditsPerWin or 100, "win")
		for _, plr in Players:GetPlayers() do
			if plr ~= winner and CombatService.IsInMatch(plr) then
				PlayerDataService.AddCredits(plr, Config.Economy.CreditsPerMatchPlayed or 10, "match")
			end
		end
	end

	local endFreeze = 1.25
	if Config.Match and typeof(Config.Match.EndFreezeSeconds) == "number" then
		endFreeze = math.max(0, Config.Match.EndFreezeSeconds)
	end

	local token = (countdownToken[winner] or 0) + 1
	countdownToken[winner] = token

	local payloadBase = {
		winnerName = winner.Name,
		winnerUserId = winner.UserId,
		mode = mode,
		kills = score,
		killsToWin = need,
		durationSec = duration,
	}

	task.delay(endFreeze, function()
		if not winner.Parent then
			return
		end
		if countdownToken[winner] ~= token then
			return
		end
		if not matchOver[winner] then
			return
		end
		if matchEndedRemote then
			for _, plr in Players:GetPlayers() do
				matchEndedRemote:FireClient(plr, {
					winnerName = payloadBase.winnerName,
					winnerUserId = payloadBase.winnerUserId,
					mode = payloadBase.mode,
					kills = payloadBase.kills,
					killsToWin = payloadBase.killsToWin,
					durationSec = payloadBase.durationSec,
					youWin = plr.UserId == winner.UserId,
				})
			end
		end
	end)

	local restartSec = winnerRestartSeconds()
	task.delay(endFreeze + restartSec, function()
		if not winner.Parent then
			return
		end
		if countdownToken[winner] ~= token then
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
	countdownToken[player] = (countdownToken[player] or 0) + 1
	CombatService.SetInMatch(player, false, nil)
	WeaponService.StripAll(player)
	GameModeService.ResetPlayer(player)
	playerMode[player] = Config.Modes.OITC
	player:SetAttribute("CQCMode", Config.Modes.OITC)
	player:SetAttribute("CQCInMatch", false)
	player:SetAttribute("CQCInHub", true)
	player:SetAttribute("CQCCountdown", false)
	LobbyService.TeleportToLobby(player)
	if returnToHubRemote then
		returnToHubRemote:FireClient(player, { reason = "hub" })
	end
	GameModeService.PushModeStats(player)
end

local function beginCombatAfterCountdown(player: Player, weaponId: string, token: number)
	bindDeps()
	if not player.Parent then
		return
	end
	if countdownToken[player] ~= token then
		return
	end
	if matchOver[player] then
		return
	end

	LobbyService.ReleaseForCombat(player)
	matchStartClock[player] = os.clock()
	WeaponService.GiveLoadout(player, weaponId, Config.Modes.OITC)
end

function GameModeService.StartMatch(player: Player, _modeRaw: any, _weaponIdRaw: any)
	bindDeps()
	getRemotes()

	local mode = Config.Modes.OITC
	GameModeService.SetMode(player, mode)
	GameModeService.ResetPlayer(player)
	matchOver[player] = false
	player:SetAttribute("CQCMatchOver", false)
	player:SetAttribute("CQCInHub", false)

	local weaponId = Config.OITC.WeaponId
	preferredWeapon[player] = weaponId
	player:SetAttribute("CQCPreferredWeapon", weaponId)

	WeaponService.StripAll(player)
	CombatService.ResetMatchStats(player)
	CombatService.SetInMatch(player, false, weaponId, mode)

	LobbyService.BeginCountdownSpawn(player)

	local seconds = 3
	if Config.Match and typeof(Config.Match.CountdownSeconds) == "number" then
		seconds = math.max(0, math.floor(Config.Match.CountdownSeconds))
	end
	local goHold = 0.85
	if Config.Match and typeof(Config.Match.GoDisplaySeconds) == "number" then
		goHold = math.max(0, Config.Match.GoDisplaySeconds)
	end

	local token = (countdownToken[player] or 0) + 1
	countdownToken[player] = token

	if matchCountdownRemote then
		matchCountdownRemote:FireClient(player, {
			seconds = seconds,
			mode = mode,
			weaponId = weaponId,
			killsToWin = Config.OITC.KillsToWin,
			goDisplaySeconds = goHold,
		})
	end

	local waitTime = seconds + goHold
	task.delay(waitTime, function()
		beginCombatAfterCountdown(player, weaponId, token)
	end)
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
		preferredWeapon[player] = nil
		matchStartClock[player] = nil
		countdownToken[player] = nil
	end)

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("CQCMode", Config.Modes.OITC)
		player:SetAttribute("CQCOITCScore", 0)
		player:SetAttribute("CQCMatchOver", false)
		player:SetAttribute("CQCCountdown", false)
	end)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("CQCMode", Config.Modes.OITC)
		player:SetAttribute("CQCOITCScore", 0)
		player:SetAttribute("CQCMatchOver", false)
		player:SetAttribute("CQCCountdown", false)
	end
end

return GameModeService
