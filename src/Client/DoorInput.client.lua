--!strict
--[[
	FPS-safe door input: E (or gamepad ButtonX) when near a door fires ToggleDoor.
	Hints are non-Active BillboardGuis (no mouse hit targets). Never uses
	ProximityPrompt so LockCenter look is never stolen by door UI.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local toggleDoor = remotes:WaitForChild(Config.Remotes.ToggleDoor) :: RemoteEvent

local interactDistance = (Config.Map and Config.Map.DoorInteractDistance) or 8
local debounceUntil = 0.0

local function inArenaPlay(): boolean
	if player:GetAttribute("CQCInHub") == true then
		return false
	end
	if player:GetAttribute("CQCMatchOver") == true then
		return false
	end
	return player:GetAttribute("CQCInMatch") == true
		or player:GetAttribute("CQCCountdown") == true
end

local function assertMatchMouseLock()
	if player:GetAttribute("CQCInMatch") ~= true then
		return
	end
	if player:GetAttribute("CQCMatchOver") == true or player:GetAttribute("CQCCountdown") == true then
		return
	end
	if player:GetAttribute("CQCInHub") == true then
		return
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	pcall(function()
		GuiService.SelectedObject = nil
	end)
end

local function getDoorsFolder(): Folder?
	local arena = workspace:FindFirstChild("CQCArena")
	if not arena then
		return nil
	end
	local folder = arena:FindFirstChild("Doors")
	if folder and folder:IsA("Folder") then
		return folder
	end
	return nil
end

local function findNearestDoorId(): string?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local doorsFolder = getDoorsFolder()
	if not doorsFolder then
		return nil
	end

	local bestId: string? = nil
	local bestDist = interactDistance
	for _, child in doorsFolder:GetChildren() do
		if child:IsA("BasePart") then
			local id = child:GetAttribute("DoorId")
			if typeof(id) == "string" then
				local delta = root.Position - child.Position
				local flat = Vector3.new(delta.X, 0, delta.Z).Magnitude
				if flat <= bestDist and math.abs(delta.Y) <= interactDistance + 4 then
					bestDist = flat
					bestId = id
				end
			end
		end
	end
	return bestId
end

local function tryToggleDoor()
	if not inArenaPlay() then
		return
	end
	local now = os.clock()
	if now < debounceUntil then
		return
	end
	local doorId = findNearestDoorId()
	if not doorId then
		return
	end
	debounceUntil = now + 0.25
	toggleDoor:FireServer(doorId)
	assertMatchMouseLock()
	task.defer(assertMatchMouseLock)
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
		tryToggleDoor()
	end
end)
