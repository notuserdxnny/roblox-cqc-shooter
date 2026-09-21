--!strict
--[[
	Server-authoritative door open/close.
	WorldSetup registers door models; ProximityPrompt.Triggered tweens
	door CFrame + CanCollide on the server so all clients see the same state.

	Open direction is chosen from the triggering player's side (and facing as
	tie-break): the leaf swings away from the player so the path clears.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	prompt: ProximityPrompt,
}

local doors: { [string]: DoorRecord } = {}

local function setPromptText(rec: DoorRecord)
	rec.prompt.ActionText = if rec.isOpen then "Close" else "Open"
	rec.prompt.ObjectText = "Door"
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
	setPromptText(rec)
	rec.busy = false
end

function DoorService.RegisterDoor(
	id: string,
	doorPart: BasePart,
	hingeCFrame: CFrame,
	closedCFrame: CFrame,
	openAngleRadians: number,
	prompt: ProximityPrompt
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
		prompt = prompt,
	}
	doors[id] = rec
	doorPart:SetAttribute("DoorId", id)
	doorPart:SetAttribute("IsOpen", false)
	doorPart:SetAttribute("OpenDir", 1)
	setPromptText(rec)

	prompt.Triggered:Connect(function(player: Player)
		local r = doors[id]
		if not r then
			return
		end
		if r.isOpen then
			tweenDoor(r, false, nil)
		else
			local dir = chooseOpenDir(r, player)
			tweenDoor(r, true, dir)
		end
	end)
end

function DoorService.Init()
	-- Doors are registered by WorldSetup as it builds the map.
	doors = {}
end

return DoorService
