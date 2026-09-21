--!strict
--[[
	Server-authoritative door open/close.
	WorldSetup registers door models; ProximityPrompt.Triggered tweens
	door CFrame + CanCollide on the server so all clients see the same state.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DoorService = {}

export type DoorRecord = {
	id: string,
	doorPart: BasePart,
	closedCFrame: CFrame,
	openCFrame: CFrame,
	isOpen: boolean,
	busy: boolean,
	prompt: ProximityPrompt,
}

local doors: { [string]: DoorRecord } = {}

local function setPromptText(rec: DoorRecord)
	rec.prompt.ActionText = if rec.isOpen then "Close" else "Open"
	rec.prompt.ObjectText = "Door"
end

local function tweenDoor(rec: DoorRecord, open: boolean)
	if rec.busy then
		return
	end
	if rec.isOpen == open then
		return
	end
	rec.busy = true
	local goalCF = if open then rec.openCFrame else rec.closedCFrame
	local info = TweenInfo.new(
		Config.Map.DoorTweenSeconds,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	-- While moving, keep collide so players can't clip through mid-swing;
	-- when fully open, disable collide for easy passage.
	rec.doorPart.CanCollide = true
	rec.doorPart.CanQuery = true

	local tw = TweenService:Create(rec.doorPart, info, { CFrame = goalCF })
	tw:Play()
	tw.Completed:Wait()

	rec.isOpen = open
	if open then
		rec.doorPart.CanCollide = false
		-- Still queryable so bullets hit an open door leaf if desired;
		-- for CQC, open doors should not block — disable query too.
		rec.doorPart.CanQuery = false
	else
		rec.doorPart.CanCollide = true
		rec.doorPart.CanQuery = true
	end
	setPromptText(rec)
	rec.busy = false
end

function DoorService.RegisterDoor(
	id: string,
	doorPart: BasePart,
	closedCFrame: CFrame,
	openCFrame: CFrame,
	prompt: ProximityPrompt
)
	local rec: DoorRecord = {
		id = id,
		doorPart = doorPart,
		closedCFrame = closedCFrame,
		openCFrame = openCFrame,
		isOpen = false,
		busy = false,
		prompt = prompt,
	}
	doors[id] = rec
	doorPart:SetAttribute("DoorId", id)
	doorPart:SetAttribute("IsOpen", false)
	setPromptText(rec)

	prompt.Triggered:Connect(function(_player: Player)
		local r = doors[id]
		if not r then
			return
		end
		local wantOpen = not r.isOpen
		tweenDoor(r, wantOpen)
		doorPart:SetAttribute("IsOpen", r.isOpen)
	end)
end

function DoorService.Init()
	-- Doors are registered by WorldSetup as it builds the map.
	doors = {}
end

return DoorService
