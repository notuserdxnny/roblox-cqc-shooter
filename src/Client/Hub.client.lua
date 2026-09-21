--!strict
--[[
	Lobby / hub ScreenGui before combat.
	Select starter weapon (Shotgun / SMG / Pistol), read how-to, press Start.
	On Start: fire StartMatch, hide hub, unlock combat (server grants all three tools).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local startMatchRemote = remotes:WaitForChild(Config.Remotes.StartMatch) :: RemoteEvent
local matchStartedRemote = remotes:WaitForChild(Config.Remotes.MatchStarted) :: RemoteEvent

player:SetAttribute("CQCInHub", true)

local selectedId = Config.DefaultWeaponId
local started = false

local gui = Instance.new("ScreenGui")
gui.Name = "CQCHub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
dim.BackgroundTransparency = 0.25
dim.BorderSizePixel = 0
dim.Parent = gui

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.fromOffset(560, 520)
card.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
card.BorderSizePixel = 0
card.Parent = gui
local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 14)
cardCorner.Parent = card
local cardStroke = Instance.new("UIStroke")
cardStroke.Color = Color3.fromRGB(70, 80, 110)
cardStroke.Thickness = 1.5
cardStroke.Parent = card

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(28, 22)
title.Size = UDim2.new(1, -56, 0, 36)
title.Font = Enum.Font.GothamBold
title.TextSize = 28
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(240, 244, 255)
title.Text = Config.Hub.Title
title.Parent = card

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(28, 58)
subtitle.Size = UDim2.new(1, -56, 0, 24)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 15
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextColor3 = Color3.fromRGB(170, 180, 200)
subtitle.Text = Config.Hub.Subtitle
subtitle.Parent = card

local loadoutLabel = Instance.new("TextLabel")
loadoutLabel.BackgroundTransparency = 1
loadoutLabel.Position = UDim2.fromOffset(28, 100)
loadoutLabel.Size = UDim2.new(1, -56, 0, 22)
loadoutLabel.Font = Enum.Font.GothamBold
loadoutLabel.TextSize = 16
loadoutLabel.TextXAlignment = Enum.TextXAlignment.Left
loadoutLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
loadoutLabel.Text = "STARTER WEAPON (all three go to your hotbar)"
loadoutLabel.Parent = card

local list = Instance.new("Frame")
list.Name = "WeaponList"
list.BackgroundTransparency = 1
list.Position = UDim2.fromOffset(28, 130)
list.Size = UDim2.new(1, -56, 0, 210)
list.Parent = card
local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Padding = UDim.new(0, 10)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local weaponButtons: { [string]: TextButton } = {}

local function refreshSelection()
	for id, btn in weaponButtons do
		local on = id == selectedId
		btn.BackgroundColor3 = if on then Color3.fromRGB(50, 90, 150) else Color3.fromRGB(34, 40, 54)
		btn.TextColor3 = if on then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(210, 215, 230)
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if on then Color3.fromRGB(120, 180, 255) else Color3.fromRGB(55, 62, 80)
		end
	end
end

for i, id in Config.WeaponOrder do
	local def = Config.Weapons[id]
	if def then
		local btn = Instance.new("TextButton")
		btn.Name = id
		btn.Size = UDim2.new(1, 0, 0, 60)
		btn.BackgroundColor3 = Color3.fromRGB(34, 40, 54)
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = true
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 16
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.TextColor3 = Color3.fromRGB(210, 215, 230)
		btn.Text = string.format("  %s\n  %s", def.Name, def.Blurb)
		btn.LayoutOrder = i
		btn.Parent = list
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = btn
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.5
		stroke.Color = Color3.fromRGB(55, 62, 80)
		stroke.Parent = btn
		btn.MouseButton1Click:Connect(function()
			selectedId = id
			refreshSelection()
		end)
		weaponButtons[id] = btn
	end
end
refreshSelection()

local howTo = Instance.new("TextLabel")
howTo.BackgroundTransparency = 1
howTo.Position = UDim2.fromOffset(28, 350)
howTo.Size = UDim2.new(1, -56, 0, 56)
howTo.Font = Enum.Font.Gotham
howTo.TextSize = 14
howTo.TextWrapped = true
howTo.TextXAlignment = Enum.TextXAlignment.Left
howTo.TextYAlignment = Enum.TextYAlignment.Top
howTo.TextColor3 = Color3.fromRGB(160, 170, 190)
howTo.Text = Config.Hub.HowTo
howTo.Parent = card

local startBtn = Instance.new("TextButton")
startBtn.Name = "Start"
startBtn.AnchorPoint = Vector2.new(0.5, 1)
startBtn.Position = UDim2.new(0.5, 0, 1, -24)
startBtn.Size = UDim2.fromOffset(220, 48)
startBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 100)
startBtn.BorderSizePixel = 0
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 20
startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
startBtn.Text = "START"
startBtn.AutoButtonColor = true
startBtn.Parent = card
local startCorner = Instance.new("UICorner")
startCorner.CornerRadius = UDim.new(0, 10)
startCorner.Parent = startBtn

local function applyHubCamera(inHub: boolean)
	player:SetAttribute("CQCInHub", inHub)
	if inHub then
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 24
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	else
		if Config.Camera.LockFirstPerson then
			player.CameraMode = Enum.CameraMode.LockFirstPerson
		end
		player.CameraMinZoomDistance = Config.Camera.MinZoom
		player.CameraMaxZoomDistance = Config.Camera.MaxZoom
	end
end

applyHubCamera(true)

local function hideHub()
	gui.Enabled = false
	applyHubCamera(false)
end

local function onStart()
	if started then
		return
	end
	started = true
	startBtn.Text = "LOADING..."
	startBtn.Active = false
	startMatchRemote:FireServer({ weaponId = selectedId })
end

startBtn.MouseButton1Click:Connect(onStart)

matchStartedRemote.OnClientEvent:Connect(function(_payload)
	started = true
	hideHub()
end)

-- If server already marked in-match (rare reconnect), skip hub
if player:GetAttribute("CQCInMatch") == true then
	started = true
	hideHub()
end
