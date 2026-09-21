--!strict
--[[
	Lobby / hub ScreenGui before combat.
	Mode select: Casual (three guns + starter pick) vs One in the Chamber (pistol only).
	On Start: fire StartMatch { weaponId, mode }, hide hub, unlock combat.
	ReturnToHub / MatchEnded can re-show the hub.
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
local matchEndedRemote = remotes:WaitForChild(Config.Remotes.MatchEnded) :: RemoteEvent
local returnToHubRemote = remotes:WaitForChild(Config.Remotes.ReturnToHub) :: RemoteEvent

player:SetAttribute("CQCInHub", true)

local selectedId = Config.DefaultWeaponId
local selectedMode = Config.DefaultMode
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
card.Size = UDim2.fromOffset(580, 600)
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
title.Position = UDim2.fromOffset(28, 18)
title.Size = UDim2.new(1, -56, 0, 32)
title.Font = Enum.Font.GothamBold
title.TextSize = 26
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(240, 244, 255)
title.Text = Config.Hub.Title
title.Parent = card

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(28, 50)
subtitle.Size = UDim2.new(1, -56, 0, 22)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 14
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextColor3 = Color3.fromRGB(170, 180, 200)
subtitle.Text = Config.Hub.Subtitle
subtitle.Parent = card

-- Mode row
local modeLabel = Instance.new("TextLabel")
modeLabel.BackgroundTransparency = 1
modeLabel.Position = UDim2.fromOffset(28, 82)
modeLabel.Size = UDim2.new(1, -56, 0, 20)
modeLabel.Font = Enum.Font.GothamBold
modeLabel.TextSize = 15
modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
modeLabel.Text = "GAME MODE"
modeLabel.Parent = card

local modeRow = Instance.new("Frame")
modeRow.Name = "ModeRow"
modeRow.BackgroundTransparency = 1
modeRow.Position = UDim2.fromOffset(28, 106)
modeRow.Size = UDim2.new(1, -56, 0, 48)
modeRow.Parent = card
local modeLayout = Instance.new("UIListLayout")
modeLayout.FillDirection = Enum.FillDirection.Horizontal
modeLayout.Padding = UDim.new(0, 12)
modeLayout.Parent = modeRow

local modeButtons: { [string]: TextButton } = {}
local refreshLoadoutVisibility: () -> ()
local howTo: TextLabel

local function refreshModes()
	for id, btn in modeButtons do
		local on = id == selectedMode
		btn.BackgroundColor3 = if on then Color3.fromRGB(70, 120, 90) else Color3.fromRGB(34, 40, 54)
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if on then Color3.fromRGB(120, 220, 160) else Color3.fromRGB(55, 62, 80)
		end
	end
end

local function makeModeButton(id: string, label: string, order: number)
	local btn = Instance.new("TextButton")
	btn.Name = id
	btn.Size = UDim2.new(0.5, -6, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(34, 40, 54)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 16
	btn.TextColor3 = Color3.fromRGB(230, 235, 245)
	btn.Text = label
	btn.LayoutOrder = order
	btn.Parent = modeRow
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(55, 62, 80)
	stroke.Parent = btn
	btn.MouseButton1Click:Connect(function()
		selectedMode = id
		refreshModes()
		if refreshLoadoutVisibility then
			refreshLoadoutVisibility()
		end
	end)
	modeButtons[id] = btn
end

makeModeButton(Config.Modes.Casual, "Casual", 1)
makeModeButton(Config.Modes.OITC, "One in the Chamber", 2)
refreshModes()

local loadoutLabel = Instance.new("TextLabel")
loadoutLabel.BackgroundTransparency = 1
loadoutLabel.Position = UDim2.fromOffset(28, 168)
loadoutLabel.Size = UDim2.new(1, -56, 0, 20)
loadoutLabel.Font = Enum.Font.GothamBold
loadoutLabel.TextSize = 15
loadoutLabel.TextXAlignment = Enum.TextXAlignment.Left
loadoutLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
loadoutLabel.Text = "STARTER WEAPON (all three go to your hotbar)"
loadoutLabel.Parent = card

local list = Instance.new("Frame")
list.Name = "WeaponList"
list.BackgroundTransparency = 1
list.Position = UDim2.fromOffset(28, 192)
list.Size = UDim2.new(1, -56, 0, 200)
list.Parent = card
local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local oitcInfo = Instance.new("TextLabel")
oitcInfo.Name = "OITCInfo"
oitcInfo.BackgroundColor3 = Color3.fromRGB(34, 40, 54)
oitcInfo.Position = UDim2.fromOffset(28, 192)
oitcInfo.Size = UDim2.new(1, -56, 0, 200)
oitcInfo.Font = Enum.Font.Gotham
oitcInfo.TextSize = 15
oitcInfo.TextWrapped = true
oitcInfo.TextXAlignment = Enum.TextXAlignment.Left
oitcInfo.TextYAlignment = Enum.TextYAlignment.Top
oitcInfo.TextColor3 = Color3.fromRGB(210, 215, 230)
oitcInfo.Text = string.format(
	"  Pistol only · magazine = 1 bullet (reserve 0)\n  Kill (gun or knife) = +1 bullet\n  Empty ammo = Knife melee (short range)\n  First to %d kills wins\n  Death respawns you with 1 bullet again\n  No Shotgun / SMG in this mode",
	Config.OITC.KillsToWin
)
oitcInfo.Visible = false
oitcInfo.Parent = card
local oitcCorner = Instance.new("UICorner")
oitcCorner.CornerRadius = UDim.new(0, 8)
oitcCorner.Parent = oitcInfo
local oitcPad = Instance.new("UIPadding")
oitcPad.PaddingTop = UDim.new(0, 14)
oitcPad.PaddingLeft = UDim.new(0, 8)
oitcPad.PaddingRight = UDim.new(0, 8)
oitcPad.Parent = oitcInfo

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

refreshLoadoutVisibility = function()
	local casual = selectedMode == Config.Modes.Casual
	list.Visible = casual
	loadoutLabel.Visible = true
	if casual then
		loadoutLabel.Text = "STARTER WEAPON (all three go to your hotbar)"
		oitcInfo.Visible = false
	else
		loadoutLabel.Text = "ONE IN THE CHAMBER — Pistol locked"
		oitcInfo.Visible = true
	end
	howTo.Text = if casual then Config.Hub.HowTo else Config.Hub.HowToOITC
end

for i, id in Config.WeaponOrder do
	local def = Config.Weapons[id]
	if def then
		local btn = Instance.new("TextButton")
		btn.Name = id
		btn.Size = UDim2.new(1, 0, 0, 58)
		btn.BackgroundColor3 = Color3.fromRGB(34, 40, 54)
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = true
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 15
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

howTo = Instance.new("TextLabel")
howTo.BackgroundTransparency = 1
howTo.Position = UDim2.fromOffset(28, 408)
howTo.Size = UDim2.new(1, -56, 0, 70)
howTo.Font = Enum.Font.Gotham
howTo.TextSize = 13
howTo.TextWrapped = true
howTo.TextXAlignment = Enum.TextXAlignment.Left
howTo.TextYAlignment = Enum.TextYAlignment.Top
howTo.TextColor3 = Color3.fromRGB(160, 170, 190)
howTo.Text = Config.Hub.HowTo
howTo.Parent = card

refreshLoadoutVisibility()

local startBtn = Instance.new("TextButton")
startBtn.Name = "Start"
startBtn.AnchorPoint = Vector2.new(0.5, 1)
startBtn.Position = UDim2.new(0.5, 0, 1, -22)
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

-- Winner overlay (shown after OITC win, then hub returns)
local winnerGui = Instance.new("ScreenGui")
winnerGui.Name = "CQCWinner"
winnerGui.ResetOnSpawn = false
winnerGui.IgnoreGuiInset = true
winnerGui.DisplayOrder = 120
winnerGui.Enabled = false
winnerGui.Parent = playerGui

local winnerDim = Instance.new("Frame")
winnerDim.Size = UDim2.fromScale(1, 1)
winnerDim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
winnerDim.BackgroundTransparency = 0.4
winnerDim.BorderSizePixel = 0
winnerDim.Parent = winnerGui

local winnerCard = Instance.new("Frame")
winnerCard.AnchorPoint = Vector2.new(0.5, 0.5)
winnerCard.Position = UDim2.fromScale(0.5, 0.5)
winnerCard.Size = UDim2.fromOffset(420, 200)
winnerCard.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
winnerCard.BorderSizePixel = 0
winnerCard.Parent = winnerGui
local wc = Instance.new("UICorner")
wc.CornerRadius = UDim.new(0, 12)
wc.Parent = winnerCard

local winnerTitle = Instance.new("TextLabel")
winnerTitle.BackgroundTransparency = 1
winnerTitle.Position = UDim2.fromOffset(20, 28)
winnerTitle.Size = UDim2.new(1, -40, 0, 40)
winnerTitle.Font = Enum.Font.GothamBold
winnerTitle.TextSize = 28
winnerTitle.TextColor3 = Color3.fromRGB(255, 220, 100)
winnerTitle.Text = "WINNER"
winnerTitle.Parent = winnerCard

local winnerBody = Instance.new("TextLabel")
winnerBody.BackgroundTransparency = 1
winnerBody.Position = UDim2.fromOffset(20, 78)
winnerBody.Size = UDim2.new(1, -40, 0, 50)
winnerBody.Font = Enum.Font.Gotham
winnerBody.TextSize = 18
winnerBody.TextWrapped = true
winnerBody.TextColor3 = Color3.fromRGB(220, 225, 240)
winnerBody.Text = ""
winnerBody.Parent = winnerCard

local hubAgainBtn = Instance.new("TextButton")
hubAgainBtn.AnchorPoint = Vector2.new(0.5, 1)
hubAgainBtn.Position = UDim2.new(0.5, 0, 1, -20)
hubAgainBtn.Size = UDim2.fromOffset(180, 40)
hubAgainBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 200)
hubAgainBtn.BorderSizePixel = 0
hubAgainBtn.Font = Enum.Font.GothamBold
hubAgainBtn.TextSize = 16
hubAgainBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hubAgainBtn.Text = "BACK TO HUB"
hubAgainBtn.Parent = winnerCard
local habCorner = Instance.new("UICorner")
habCorner.CornerRadius = UDim.new(0, 8)
habCorner.Parent = hubAgainBtn

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

local function showHub()
	started = false
	startBtn.Text = "START"
	startBtn.Active = true
	winnerGui.Enabled = false
	gui.Enabled = true
	applyHubCamera(true)
	howTo.Text = if selectedMode == Config.Modes.OITC then Config.Hub.HowToOITC else Config.Hub.HowTo
end

local function onStart()
	if started then
		return
	end
	started = true
	startBtn.Text = "LOADING..."
	startBtn.Active = false
	local weaponId = if selectedMode == Config.Modes.OITC then Config.OITC.WeaponId else selectedId
	startMatchRemote:FireServer({ weaponId = weaponId, mode = selectedMode })
end

startBtn.MouseButton1Click:Connect(onStart)

hubAgainBtn.MouseButton1Click:Connect(function()
	returnToHubRemote:FireServer()
	showHub()
end)

matchStartedRemote.OnClientEvent:Connect(function(_payload)
	started = true
	winnerGui.Enabled = false
	hideHub()
end)

matchEndedRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local name = tostring(payload.winnerName or "?")
	local kills = tonumber(payload.kills) or 0
	local need = tonumber(payload.killsToWin) or Config.OITC.KillsToWin
	winnerTitle.Text = "ONE IN THE CHAMBER"
	winnerBody.Text = string.format("%s wins!\n%d / %d kills", name, kills, need)
	winnerGui.Enabled = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end)

returnToHubRemote.OnClientEvent:Connect(function()
	showHub()
end)

-- If server already marked in-match (rare reconnect), skip hub
if player:GetAttribute("CQCInMatch") == true then
	started = true
	hideHub()
end
