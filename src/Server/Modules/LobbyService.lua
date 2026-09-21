--!strict
--[[
	Lobby vs combat spawn flow.
	- Dedicated Lobby room (built by WorldSetup) is the only Roblox SpawnLocation.
	- Before StartMatch: character stays in Lobby (frozen), no tools.
	- On StartMatch: teleport to combat START pads STILL FROZEN (countdown).
	- After countdown GO: unfreeze, set InMatch (weapons granted by GameMode/WeaponService).
	- On ReturnToHub: strip tools, teleport back to Lobby, freeze again.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local LobbyService = {}

local CombatService: any = nil

local function getCombat()
	if not CombatService then
		CombatService = require(script.Parent:WaitForChild("CombatService"))
	end
	return CombatService
end

local function lobbyFolder(): Folder?
	local arena = workspace:FindFirstChild("CQCArena")
	if not arena then
		return nil
	end
	return arena:FindFirstChild("Lobby") :: Folder?
end

local function getLobbySpawnCFrame(): CFrame
	local lobby = lobbyFolder()
	if lobby then
		local spawn = lobby:FindFirstChild("LobbySpawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
		local pad = lobby:FindFirstChild("LobbyPad")
		if pad and pad:IsA("BasePart") then
			return pad.CFrame + Vector3.new(0, 3, 0)
		end
	end
	local off = Config.Lobby.Offset
	return CFrame.new(off.X, Config.Lobby.FloorY + Config.Lobby.SpawnHeight, off.Z)
end

local function getCombatSpawnCFrames(): { CFrame }
	local result: { CFrame } = {}
	local arena = workspace:FindFirstChild("CQCArena")
	local folder = arena and arena:FindFirstChild("SpawnPoints")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") and (child.Name:match("^SpawnPad") or child:GetAttribute("CombatSpawn") == true) then
				table.insert(result, child.CFrame + Vector3.new(0, 3, 0))
			end
		end
	end
	if #result == 0 then
		-- Fallback: start room center from attributes
		local x = if arena then (arena:GetAttribute("StartRoomX") or 0) else 0
		local z = if arena then (arena:GetAttribute("StartRoomZ") or 0) else 0
		table.insert(result, CFrame.new(x :: number, Config.Map.FloorY + 4, z :: number))
	end
	return result
end

local spawnCursor = 0

local function nextCombatCFrame(): CFrame
	local pads = getCombatSpawnCFrames()
	spawnCursor = (spawnCursor % #pads) + 1
	return pads[spawnCursor]
end

local function getRoot(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function LobbyService.FreezeForLobby(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = Config.Lobby.FreezeWalkSpeed
	pcall(function()
		humanoid.JumpPower = Config.Lobby.FreezeJumpPower
	end)
	pcall(function()
		humanoid.JumpHeight = 0
	end)
	humanoid:SetAttribute("CQCLobbyFrozen", true)
end

function LobbyService.UnfreezeForMatch(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = Config.Lobby.MatchWalkSpeed
	pcall(function()
		humanoid.JumpPower = Config.Lobby.MatchJumpPower
	end)
	pcall(function()
		humanoid.JumpHeight = Config.Lobby.MatchJumpHeight
	end)
	humanoid:SetAttribute("CQCLobbyFrozen", nil)
end

function LobbyService.TeleportToLobby(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local root = getRoot(character)
	if not root then
		return
	end
	local dest = getLobbySpawnCFrame()
	-- Face the lobby backdrop (+Z toward accent wall)
	character:PivotTo(dest * CFrame.Angles(0, math.rad(180), 0))
	LobbyService.FreezeForLobby(player)
	player:SetAttribute("CQCInHub", true)
	player:SetAttribute("CQCCountdown", false)
end

--[[
	Teleport to a combat pad but KEEP frozen (pre-countdown / countdown).
	Does not set CQCInMatch.
]]
function LobbyService.TeleportToCombatFrozen(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local root = getRoot(character)
	if not root then
		return
	end
	local dest = nextCombatCFrame()
	character:PivotTo(dest)
	LobbyService.FreezeForLobby(player)
	player:SetAttribute("CQCInHub", false)
	player:SetAttribute("CQCInMatch", false)
end

function LobbyService.TeleportToCombat(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local root = getRoot(character)
	if not root then
		return
	end
	local dest = nextCombatCFrame()
	character:PivotTo(dest)
	LobbyService.UnfreezeForMatch(player)
	player:SetAttribute("CQCInHub", false)
end

function LobbyService.SendToLobby(player: Player)
	getCombat().SetInMatch(player, false, nil)
	player:SetAttribute("CQCInMatch", false)
	player:SetAttribute("CQCInHub", true)
	player:SetAttribute("CQCCountdown", false)
	if player.Character then
		LobbyService.TeleportToLobby(player)
	end
end

--[[
	Begin countdown phase: leave lobby UI attrs, teleport frozen to combat.
	Combat / InMatch is enabled later via ReleaseForCombat.
]]
function LobbyService.BeginCountdownSpawn(player: Player)
	player:SetAttribute("CQCInHub", false)
	player:SetAttribute("CQCInMatch", false)
	player:SetAttribute("CQCCountdown", true)
	if player.Character then
		LobbyService.TeleportToCombatFrozen(player)
		player:SetAttribute("CQCCountdown", true)
	end
end

--[[
	After GO: unfreeze and mark in-match (WeaponService also sets via SetInMatch).
]]
function LobbyService.ReleaseForCombat(player: Player)
	player:SetAttribute("CQCCountdown", false)
	player:SetAttribute("CQCInHub", false)
	player:SetAttribute("CQCInMatch", true)
	LobbyService.UnfreezeForMatch(player)
end

--[[
	Legacy helper: teleport + unfreeze + in-match (used for mid-match respawn).
]]
function LobbyService.EnterMatch(player: Player)
	player:SetAttribute("CQCInHub", false)
	player:SetAttribute("CQCCountdown", false)
	player:SetAttribute("CQCInMatch", true)
	if player.Character then
		LobbyService.TeleportToCombat(player)
	end
end

local function onCharacter(player: Player, character: Model)
	task.defer(function()
		if not player.Parent or character.Parent == nil then
			return
		end
		local inMatch = player:GetAttribute("CQCInMatch") == true
		local matchOver = player:GetAttribute("CQCMatchOver") == true
		local countdown = player:GetAttribute("CQCCountdown") == true
		if countdown and not matchOver then
			-- Died / respawned during countdown → back to combat pad, still frozen
			LobbyService.TeleportToCombatFrozen(player)
			player:SetAttribute("CQCCountdown", true)
		elseif inMatch and not matchOver then
			-- Respawn mid-match → combat pad
			LobbyService.TeleportToCombat(player)
		else
			LobbyService.TeleportToLobby(player)
		end
	end)

	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		-- Re-apply freeze if something restores WalkSpeed while in lobby / countdown / end
		humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			local frozen = humanoid:GetAttribute("CQCLobbyFrozen")
			local inMatch = player:GetAttribute("CQCInMatch") == true
			local matchOver = player:GetAttribute("CQCMatchOver") == true
			if frozen and (not inMatch or matchOver) then
				if humanoid.WalkSpeed ~= Config.Lobby.FreezeWalkSpeed then
					humanoid.WalkSpeed = Config.Lobby.FreezeWalkSpeed
				end
			end
		end)
	end
end

function LobbyService.Init()
	local function hook(player: Player)
		player:SetAttribute("CQCInHub", true)
		player:SetAttribute("CQCInMatch", false)
		player:SetAttribute("CQCCountdown", false)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return LobbyService
