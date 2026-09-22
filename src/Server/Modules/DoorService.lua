--!strict
--[[
	Server-authoritative door open/close.
	WorldSetup registers door models; client fires ToggleDoor (E near door).
	No ProximityPrompt — FPS LockCenter must never unlock on door UI hover.

	Open direction is chosen from the triggering player's side (and facing as
	tie-break): the leaf swings away from the player so the path clears.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DoorService = {}

export type DoorRecord = {
	id: string,
	doorPart: BasePart,
	hingeCFrame: CFrame,
	leafOffset: CFrame,
	closedCFrame: CFrame,
	openAngle: number, -- radians magnitude
	isOpen: boolean,
	openDir: number, -- +1 or -1 while open / last used
	busy: boolean,
	hintLabel: TextLabel?,
}

local doors: { [string]: DoorRecord } = {}
local toggleRemote: RemoteEvent? = nil
local remoteConnected = false
local interactDistance = 8

local function setHintText(rec: DoorRecord)
	local label = rec.hintLabel
	if label then
		label.Text = if rec.isOpen then "[E] Close" else "[E] Open"
	end
end

local function cframeForDir(rec: DoorRecord, dir: number): CFrame
	return rec.hingeCFrame * CFrame.Angles(0, dir * rec.openAngle, 0) * rec.leafOffset
end

--[[
	Pick ±openAngle so the open leaf moves away from the player.
	Uses flattened hinge→player vs hinge→openCenter dots; facing breaks ties.
]]
local function chooseOpenDir(rec: DoorRecord, player: Player): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return if rec.openDir ~= 0 then rec.openDir else 1
	end

	local hingePos = rec.hingeCFrame.Position
	local toPlayer = root.Position - hingePos
	toPlayer = Vector3.new(toPlayer.X, 0, toPlayer.Z)

	local plusCF = cframeForDir(rec, 1)
	local minusCF = cframeForDir(rec, -1)
	local plusDisp = plusCF.Position - hingePos
	local minusDisp = minusCF.Position - hingePos

	-- Smaller (more negative) dot ⇒ open displacement more opposite the player
	local plusDot = plusDisp:Dot(toPlayer)
	local minusDot = minusDisp:Dot(toPlayer)

	if plusDot < minusDot - 0.05 then
		return 1
	elseif minusDot < plusDot - 0.05 then
		return -1
	end

	-- Nearly in the door plane: clear the path in the direction the player faces
	local look = root.CFrame.LookVector
	local lookFlat = Vector3.new(look.X, 0, look.Z)
	if lookFlat.Magnitude < 0.05 then
		return 1
	end
	lookFlat = lookFlat.Unit
	local plusAlign = plusDisp:Dot(lookFlat)
	local minusAlign = minusDisp:Dot(lookFlat)
	return if plusAlign >= minusAlign then 1 else -1
end

local function tweenDoor(rec: DoorRecord, open: boolean, dir: number?)
	if rec.busy then
		return
	end
	if rec.isOpen == open then
		return
	end
	rec.busy = true

	local goalCF: CFrame
	if open then
		local useDir = dir or 1
		rec.openDir = useDir
		goalCF = cframeForDir(rec, useDir)
	else
		goalCF = rec.closedCFrame
	end

	local info = TweenInfo.new(
		Config.Map.DoorTweenSeconds,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	-- While moving, keep collide so players can't clip through mid-swing;
	-- when fully open, disable collide for easy passage.
	rec.doorPart.CanCollide = true
	rec.doorPart.CanQuery = true

	-- Soft door whoosh
	local snd = Instance.new("Sound")
	snd.SoundId = (Config.SoundIds and Config.SoundIds.Door) or "rbxassetid://9113895097"
	snd.Volume = (Config.SoundVolumes and Config.SoundVolumes.Door) or 0.28
	snd.PlaybackSpeed = if open then 1.05 else 0.9
	snd.Parent = rec.doorPart
	snd:Play()
	game:GetService("Debris"):AddItem(snd, 2)

	local tw = TweenService:Create(rec.doorPart, info, { CFrame = goalCF })
	tw:Play()
	tw.Completed:Wait()

	rec.isOpen = open
	if open then
		rec.doorPart.CanCollide = false
		-- Open doors should not block bullets or movement
		rec.doorPart.CanQuery = false
	else
		rec.doorPart.CanCollide = true
		rec.doorPart.CanQuery = true
		-- Keep openDir as last swing so a re-open without player still has a default
	end
	rec.doorPart:SetAttribute("IsOpen", open)
	rec.doorPart:SetAttribute("OpenDir", rec.openDir)
	setHintText(rec)
	rec.busy = false
end

local function playerWithinRange(player: Player, doorPart: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local delta = root.Position - doorPart.Position
	-- Slightly taller allowance so crouch / jump still works
	local flat = Vector3.new(delta.X, 0, delta.Z)
	return flat.Magnitude <= interactDistance and math.abs(delta.Y) <= interactDistance + 4
end

local function toggleFromPlayer(player: Player, doorId: string)
	local r = doors[doorId]
	if not r then
		return
	end
	if r.busy then
		return
	end
	if not playerWithinRange(player, r.doorPart) then
		return
	end
	-- Only while live match / countdown in arena (not hub overlay)
	if player:GetAttribute("CQCInHub") == true then
		return
	end
	if player:GetAttribute("CQCMatchOver") == true then
		return
	end
	if player:GetAttribute("CQCInMatch") ~= true and player:GetAttribute("CQCCountdown") ~= true then
		return
	end

	if r.isOpen then
		tweenDoor(r, false, nil)
	else
		local dir = chooseOpenDir(r, player)
		tweenDoor(r, true, dir)
	end
end

function DoorService.RegisterDoor(
	id: string,
	doorPart: BasePart,
	hingeCFrame: CFrame,
	closedCFrame: CFrame,
	openAngleRadians: number,
	hintLabel: TextLabel?
)
	local leafOffset = hingeCFrame:ToObjectSpace(closedCFrame)
	local rec: DoorRecord = {
		id = id,
		doorPart = doorPart,
		hingeCFrame = hingeCFrame,
		leafOffset = leafOffset,
		closedCFrame = closedCFrame,
		openAngle = openAngleRadians,
		isOpen = false,
		openDir = 1,
		busy = false,
		hintLabel = hintLabel,
	}
	doors[id] = rec
	doorPart:SetAttribute("DoorId", id)
	doorPart:SetAttribute("IsOpen", false)
	doorPart:SetAttribute("OpenDir", 1)
	setHintText(rec)
end

function DoorService.Init()
	doors = {}
	interactDistance = (Config.Map and Config.Map.DoorInteractDistance) or 8

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	local existing = remotes:FindFirstChild(Config.Remotes.ToggleDoor)
	if existing and existing:IsA("RemoteEvent") then
		toggleRemote = existing
	else
		local r = Instance.new("RemoteEvent")
		r.Name = Config.Remotes.ToggleDoor
		r.Parent = remotes
		toggleRemote = r
	end

	assert(toggleRemote)
	if not remoteConnected then
		remoteConnected = true
		toggleRemote.OnServerEvent:Connect(function(player: Player, doorId: unknown)
			if typeof(doorId) ~= "string" then
				return
			end
			toggleFromPlayer(player, doorId :: string)
		end)
	end
end

return DoorService
