--!strict
--[[
	Lobby vs combat spawn flow.
	- Dedicated Lobby room (built by WorldSetup) is the only Roblox SpawnLocation.
	- Before StartMatch: character stays in Lobby (frozen), no tools.
	- On StartMatch: unfreeze, teleport to combat START pads.
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
	if player.Character then
		LobbyService.TeleportToLobby(player)
	end
end

function LobbyService.EnterMatch(player: Player)
	player:SetAttribute("CQCInHub", false)
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
		if inMatch and not matchOver then
			-- Respawn mid-match → combat pad
			LobbyService.TeleportToCombat(player)
		else
			LobbyService.TeleportToLobby(player)
		end
	end)

	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		-- Re-apply freeze if something restores WalkSpeed while in lobby
		humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			if player:GetAttribute("CQCInMatch") ~= true and humanoid:GetAttribute("CQCLobbyFrozen") then
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
