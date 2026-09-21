--!strict
--[[
	Professional lobby / hub ScreenGui.
	Dark modern panel, mode cards, Casual loadout row, primary START.
	While open: Classic camera + unlocked mouse (CQCInHub).
	On Start: StartMatch remote → hide hub → LockFirstPerson (FirstPerson.client).
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

-- Theme
local Theme = {
	Bg = Color3.fromRGB(10, 12, 18),
	Panel = Color3.fromRGB(18, 22, 32),
	PanelAlt = Color3.fromRGB(24, 30, 44),
	Card = Color3.fromRGB(28, 34, 50),
	CardHover = Color3.fromRGB(34, 42, 60),
	Stroke = Color3.fromRGB(55, 64, 88),
	StrokeSelected = Color3.fromRGB(90, 160, 255),
	Text = Color3.fromRGB(236, 240, 250),
	TextMuted = Color3.fromRGB(150, 160, 184),
	TextDim = Color3.fromRGB(110, 120, 145),
	Accent = Color3.fromRGB(70, 140, 230),
	AccentSoft = Color3.fromRGB(50, 90, 150),
	Success = Color3.fromRGB(56, 170, 110),
	SuccessDark = Color3.fromRGB(40, 120, 80),
	Warning = Color3.fromRGB(230, 180, 80),
	OITC = Color3.fromRGB(220, 120, 70),
	Radius = 12,
	RadiusSm = 8,
}

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
dim.BackgroundColor3 = Theme.Bg
dim.BackgroundTransparency = 0.35
dim.BorderSizePixel = 0
dim.Parent = gui

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.fromOffset(640, 620)
card.BackgroundColor3 = Theme.Panel
card.BorderSizePixel = 0
card.Parent = gui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, Theme.Radius)
	c.Parent = card
	local s = Instance.new("UIStroke")
	s.Color = Theme.Stroke
	s.Thickness = 1.25
	s.Transparency = 0.15
	s.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 28)
	pad.PaddingBottom = UDim.new(0, 24)
	pad.PaddingLeft = UDim.new(0, 32)
	pad.PaddingRight = UDim.new(0, 32)
	pad.Parent = card
end

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 34)
title.Font = Enum.Font.GothamBold
title.TextSize = 28
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Theme.Text
title.Text = Config.Hub.Title
title.Parent = card

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(0, 36)
subtitle.Size = UDim2.new(1, 0, 0, 22)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 14
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextColor3 = Theme.TextMuted
subtitle.Text = Config.Hub.Subtitle
subtitle.Parent = card

local sectionMode = Instance.new("TextLabel")
sectionMode.BackgroundTransparency = 1
sectionMode.Position = UDim2.fromOffset(0, 72)
sectionMode.Size = UDim2.new(1, 0, 0, 18)
sectionMode.Font = Enum.Font.GothamBold
sectionMode.TextSize = 12
sectionMode.TextXAlignment = Enum.TextXAlignment.Left
sectionMode.TextColor3 = Theme.TextDim
sectionMode.Text = "GAME MODE"
sectionMode.Parent = card

local modeRow = Instance.new("Frame")
modeRow.Name = "ModeRow"
modeRow.BackgroundTransparency = 1
modeRow.Position = UDim2.fromOffset(0, 96)
modeRow.Size = UDim2.new(1, 0, 0, 100)
modeRow.Parent = card
local modeLayout = Instance.new("UIListLayout")
modeLayout.FillDirection = Enum.FillDirection.Horizontal
modeLayout.Padding = UDim.new(0, 12)
modeLayout.Parent = modeRow

local modeButtons: { [string]: TextButton } = {}
local modeDescLabels: { [string]: TextLabel } = {}
local refreshLoadoutVisibility: () -> ()
local howTo: TextLabel
local howToExpanded = false

local function styleModeCard(id: string, on: boolean)
	local btn = modeButtons[id]
	if not btn then
		return
	end
	btn.BackgroundColor3 = if on then Theme.AccentSoft else Theme.Card
	local stroke = btn:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if on then Theme.StrokeSelected else Theme.Stroke
		stroke.Thickness = if on then 2 else 1
	end
	local check = btn:FindFirstChild("SelectedDot")
	if check and check:IsA("Frame") then
		check.BackgroundColor3 = if on then Theme.Accent else Theme.Stroke
	end
end

local function refreshModes()
	for id in modeButtons do
		styleModeCard(id, id == selectedMode)
	end
end

local function makeModeCard(id: string, label: string, blurb: string, order: number, accent: Color3)
	local btn = Instance.new("TextButton")
	btn.Name = id
	btn.Size = UDim2.new(0.5, -6, 1, 0)
	btn.BackgroundColor3 = Theme.Card
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.LayoutOrder = order
	btn.Parent = modeRow
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.RadiusSm)
	corner.Parent = btn
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Theme.Stroke
	stroke.Parent = btn

	local dot = Instance.new("Frame")
	dot.Name = "SelectedDot"
	dot.Size = UDim2.fromOffset(8, 8)
	dot.Position = UDim2.fromOffset(14, 16)
	dot.BackgroundColor3 = Theme.Stroke
	dot.BorderSizePixel = 0
	dot.Parent = btn
	local dc = Instance.new("UICorner")
	dc.CornerRadius = UDim.new(1, 0)
	dc.Parent = dot

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(30, 10)
	name.Size = UDim2.new(1, -44, 0, 22)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 16
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = Theme.Text
	name.Text = label
	name.Parent = btn

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(14, 38)
	desc.Size = UDim2.new(1, -28, 0, 52)
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 12
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextColor3 = Theme.TextMuted
	desc.Text = blurb
	desc.Parent = btn
	modeDescLabels[id] = desc

	local accentBar = Instance.new("Frame")
	accentBar.Size = UDim2.new(1, 0, 0, 3)
	accentBar.Position = UDim2.new(0, 0, 1, -3)
	accentBar.BackgroundColor3 = accent
	accentBar.BorderSizePixel = 0
	accentBar.Parent = btn

	btn.MouseEnter:Connect(function()
		if selectedMode ~= id then
			btn.BackgroundColor3 = Theme.CardHover
		end
	end)
	btn.MouseLeave:Connect(function()
		styleModeCard(id, selectedMode == id)
	end)
	btn.MouseButton1Click:Connect(function()
		selectedMode = id
		refreshModes()
		if refreshLoadoutVisibility then
			refreshLoadoutVisibility()
		end
	end)
	modeButtons[id] = btn
end

makeModeCard(
	Config.Modes.Casual,
	"Casual",
	Config.Hub.ModeCasualBlurb or "Full loadout. Train freely.",
	1,
	Theme.Accent
)
makeModeCard(
	Config.Modes.OITC,
	"One in the Chamber",
	Config.Hub.ModeOITCBlurb or "One bullet. Knife when empty.",
	2,
	Theme.OITC
)
refreshModes()

local loadoutLabel = Instance.new("TextLabel")
loadoutLabel.BackgroundTransparency = 1
loadoutLabel.Position = UDim2.fromOffset(0, 212)
loadoutLabel.Size = UDim2.new(1, 0, 0, 18)
loadoutLabel.Font = Enum.Font.GothamBold
loadoutLabel.TextSize = 12
loadoutLabel.TextXAlignment = Enum.TextXAlignment.Left
loadoutLabel.TextColor3 = Theme.TextDim
loadoutLabel.Text = "STARTER WEAPON"
loadoutLabel.Parent = card

local list = Instance.new("Frame")
list.Name = "WeaponList"
list.BackgroundTransparency = 1
list.Position = UDim2.fromOffset(0, 236)
list.Size = UDim2.new(1, 0, 0, 168)
list.Parent = card
local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local oitcInfo = Instance.new("Frame")
oitcInfo.Name = "OITCInfo"
oitcInfo.BackgroundColor3 = Theme.PanelAlt
oitcInfo.Position = UDim2.fromOffset(0, 236)
oitcInfo.Size = UDim2.new(1, 0, 0, 168)
oitcInfo.Visible = false
oitcInfo.BorderSizePixel = 0
oitcInfo.Parent = card
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, Theme.RadiusSm)
	c.Parent = oitcInfo
	local s = Instance.new("UIStroke")
	s.Color = Theme.Stroke
	s.Thickness = 1
	s.Parent = oitcInfo
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 16)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = oitcInfo
end

local oitcBody = Instance.new("TextLabel")
oitcBody.BackgroundTransparency = 1
oitcBody.Size = UDim2.fromScale(1, 1)
oitcBody.Font = Enum.Font.Gotham
oitcBody.TextSize = 14
oitcBody.TextWrapped = true
oitcBody.TextXAlignment = Enum.TextXAlignment.Left
oitcBody.TextYAlignment = Enum.TextYAlignment.Top
oitcBody.TextColor3 = Theme.TextMuted
oitcBody.Text = string.format(
	"Pistol only  ·  magazine = 1 bullet\nKill (gun or knife) = +1 bullet\nEmpty ammo = Knife melee (short range)\nFirst to %d kills wins\nDeath respawns with 1 bullet  ·  no Shotgun / SMG",
	Config.OITC.KillsToWin
)
oitcBody.Parent = oitcInfo

local weaponButtons: { [string]: TextButton } = {}

local function refreshSelection()
	for id, btn in weaponButtons do
		local on = id == selectedId
		btn.BackgroundColor3 = if on then Theme.AccentSoft else Theme.Card
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if on then Theme.StrokeSelected else Theme.Stroke
			stroke.Thickness = if on then 2 else 1
		end
		local mark = btn:FindFirstChild("Check")
		if mark and mark:IsA("TextLabel") then
			mark.TextColor3 = if on then Theme.Accent else Theme.Stroke
			mark.Text = if on then "●" else "○"
		end
	end
end

refreshLoadoutVisibility = function()
	local casual = selectedMode == Config.Modes.Casual
	list.Visible = casual
	oitcInfo.Visible = not casual
	if casual then
		loadoutLabel.Text = "STARTER WEAPON  ·  all three go to your hotbar"
	else
		loadoutLabel.Text = "LOADOUT  ·  pistol locked"
	end
	howTo.Text = if casual then Config.Hub.HowTo else Config.Hub.HowToOITC
end

for i, id in Config.WeaponOrder do
	local def = Config.Weapons[id]
	if def then
		local btn = Instance.new("TextButton")
		btn.Name = id
		btn.Size = UDim2.new(1, 0, 0, 48)
		btn.BackgroundColor3 = Theme.Card
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.Text = ""
		btn.LayoutOrder = i
		btn.Parent = list
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, Theme.RadiusSm)
		corner.Parent = btn
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.Color = Theme.Stroke
		stroke.Parent = btn

		local check = Instance.new("TextLabel")
		check.Name = "Check"
		check.BackgroundTransparency = 1
		check.Position = UDim2.fromOffset(12, 0)
		check.Size = UDim2.new(0, 20, 1, 0)
		check.Font = Enum.Font.GothamBold
		check.TextSize = 14
		check.TextColor3 = Theme.Stroke
		check.Text = "○"
		check.Parent = btn

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(36, 4)
		name.Size = UDim2.new(1, -48, 0, 20)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 14
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = Theme.Text
		name.Text = def.Name
		name.Parent = btn

		local blurb = Instance.new("TextLabel")
		blurb.BackgroundTransparency = 1
		blurb.Position = UDim2.fromOffset(36, 24)
		blurb.Size = UDim2.new(1, -48, 0, 18)
		blurb.Font = Enum.Font.Gotham
		blurb.TextSize = 12
		blurb.TextXAlignment = Enum.TextXAlignment.Left
		blurb.TextColor3 = Theme.TextMuted
		blurb.Text = def.Blurb
		blurb.Parent = btn

		btn.MouseEnter:Connect(function()
			if selectedId ~= id then
				btn.BackgroundColor3 = Theme.CardHover
			end
		end)
		btn.MouseLeave:Connect(function()
			refreshSelection()
		end)
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
howTo.Position = UDim2.fromOffset(0, 416)
howTo.Size = UDim2.new(1, 0, 0, 48)
howTo.Font = Enum.Font.Gotham
howTo.TextSize = 12
howTo.TextWrapped = true
howTo.TextXAlignment = Enum.TextXAlignment.Left
howTo.TextYAlignment = Enum.TextYAlignment.Top
howTo.TextColor3 = Theme.TextDim
howTo.Text = Config.Hub.HowTo
howTo.Visible = false
howTo.Parent = card

refreshLoadoutVisibility()

-- Footer buttons
local footer = Instance.new("Frame")
footer.Name = "Footer"
footer.BackgroundTransparency = 1
footer.AnchorPoint = Vector2.new(0.5, 1)
footer.Position = UDim2.new(0.5, 0, 1, 0)
footer.Size = UDim2.new(1, 0, 0, 52)
footer.Parent = card

local howBtn = Instance.new("TextButton")
howBtn.Name = "HowTo"
howBtn.Size = UDim2.fromOffset(120, 44)
howBtn.Position = UDim2.fromOffset(0, 4)
howBtn.BackgroundColor3 = Theme.PanelAlt
howBtn.BorderSizePixel = 0
howBtn.Font = Enum.Font.GothamBold
howBtn.TextSize = 13
howBtn.TextColor3 = Theme.TextMuted
howBtn.Text = "HOW TO PLAY"
howBtn.AutoButtonColor = false
howBtn.Parent = footer
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, Theme.RadiusSm)
	c.Parent = howBtn
	local s = Instance.new("UIStroke")
	s.Color = Theme.Stroke
	s.Thickness = 1
	s.Parent = howBtn
end

local startBtn = Instance.new("TextButton")
startBtn.Name = "Start"
startBtn.AnchorPoint = Vector2.new(1, 0)
startBtn.Position = UDim2.new(1, 0, 0, 0)
startBtn.Size = UDim2.fromOffset(200, 52)
startBtn.BackgroundColor3 = Theme.Success
startBtn.BorderSizePixel = 0
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 18
startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
startBtn.Text = "START MATCH"
startBtn.AutoButtonColor = false
startBtn.Parent = footer
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, Theme.RadiusSm)
	c.Parent = startBtn
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(100, 220, 150)
	s.Thickness = 1
	s.Transparency = 0.4
	s.Parent = startBtn
end

howBtn.MouseButton1Click:Connect(function()
	howToExpanded = not howToExpanded
	howTo.Visible = howToExpanded
	howBtn.Text = if howToExpanded then "HIDE TIPS" else "HOW TO PLAY"
	howBtn.TextColor3 = if howToExpanded then Theme.Text else Theme.TextMuted
end)

startBtn.MouseEnter:Connect(function()
	if startBtn.Active then
		startBtn.BackgroundColor3 = Color3.fromRGB(66, 190, 125)
	end
end)
startBtn.MouseLeave:Connect(function()
	if startBtn.Active then
		startBtn.BackgroundColor3 = Theme.Success
	end
end)

-- Winner overlay (same theme)
local winnerGui = Instance.new("ScreenGui")
winnerGui.Name = "CQCWinner"
winnerGui.ResetOnSpawn = false
winnerGui.IgnoreGuiInset = true
winnerGui.DisplayOrder = 120
winnerGui.Enabled = false
winnerGui.Parent = playerGui

local winnerDim = Instance.new("Frame")
winnerDim.Size = UDim2.fromScale(1, 1)
winnerDim.BackgroundColor3 = Theme.Bg
winnerDim.BackgroundTransparency = 0.45
winnerDim.BorderSizePixel = 0
winnerDim.Parent = winnerGui

local winnerCard = Instance.new("Frame")
winnerCard.AnchorPoint = Vector2.new(0.5, 0.5)
winnerCard.Position = UDim2.fromScale(0.5, 0.5)
winnerCard.Size = UDim2.fromOffset(440, 220)
winnerCard.BackgroundColor3 = Theme.Panel
winnerCard.BorderSizePixel = 0
winnerCard.Parent = winnerGui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, Theme.Radius)
	c.Parent = winnerCard
	local s = Instance.new("UIStroke")
	s.Color = Theme.Stroke
	s.Thickness = 1.25
	s.Parent = winnerCard
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 28)
	pad.PaddingBottom = UDim.new(0, 24)
	pad.PaddingLeft = UDim.new(0, 28)
	pad.PaddingRight = UDim.new(0, 28)
	pad.Parent = winnerCard
end

local winnerTitle = Instance.new("TextLabel")
winnerTitle.BackgroundTransparency = 1
winnerTitle.Size = UDim2.new(1, 0, 0, 28)
winnerTitle.Font = Enum.Font.GothamBold
winnerTitle.TextSize = 13
winnerTitle.TextXAlignment = Enum.TextXAlignment.Left
winnerTitle.TextColor3 = Theme.TextDim
winnerTitle.Text = "ONE IN THE CHAMBER"
winnerTitle.Parent = winnerCard

local winnerHeadline = Instance.new("TextLabel")
winnerHeadline.BackgroundTransparency = 1
winnerHeadline.Position = UDim2.fromOffset(0, 32)
winnerHeadline.Size = UDim2.new(1, 0, 0, 36)
winnerHeadline.Font = Enum.Font.GothamBold
winnerHeadline.TextSize = 28
winnerHeadline.TextXAlignment = Enum.TextXAlignment.Left
winnerHeadline.TextColor3 = Theme.Warning
winnerHeadline.Text = "VICTORY"
winnerHeadline.Parent = winnerCard

local winnerBody = Instance.new("TextLabel")
winnerBody.BackgroundTransparency = 1
winnerBody.Position = UDim2.fromOffset(0, 76)
winnerBody.Size = UDim2.new(1, 0, 0, 44)
winnerBody.Font = Enum.Font.Gotham
winnerBody.TextSize = 16
winnerBody.TextWrapped = true
winnerBody.TextXAlignment = Enum.TextXAlignment.Left
winnerBody.TextColor3 = Theme.TextMuted
winnerBody.Text = ""
winnerBody.Parent = winnerCard

local hubAgainBtn = Instance.new("TextButton")
hubAgainBtn.AnchorPoint = Vector2.new(0.5, 1)
hubAgainBtn.Position = UDim2.new(0.5, 0, 1, 0)
hubAgainBtn.Size = UDim2.fromOffset(200, 44)
hubAgainBtn.BackgroundColor3 = Theme.Accent
hubAgainBtn.BorderSizePixel = 0
hubAgainBtn.Font = Enum.Font.GothamBold
hubAgainBtn.TextSize = 14
hubAgainBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hubAgainBtn.Text = "BACK TO LOBBY"
hubAgainBtn.Parent = winnerCard
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, Theme.RadiusSm)
	c.Parent = hubAgainBtn
end

local function applyHubCamera(inHub: boolean)
	player:SetAttribute("CQCInHub", inHub)
	if inHub then
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = Config.Camera.HubMinZoom or 8
		player.CameraMaxZoomDistance = Config.Camera.HubMaxZoom or 20
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		pcall(function()
			player.DevEnableMouseLock = false
		end)
	else
		if Config.Camera.LockFirstPerson then
			player.CameraMode = Enum.CameraMode.LockFirstPerson
		end
		player.CameraMinZoomDistance = Config.Camera.MinZoom
		player.CameraMaxZoomDistance = Config.Camera.MaxZoom
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end
end

applyHubCamera(true)

local function hideHub()
	gui.Enabled = false
	applyHubCamera(false)
end

local function showHub()
	started = false
	startBtn.Text = "START MATCH"
	startBtn.Active = true
	startBtn.BackgroundColor3 = Theme.Success
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
	startBtn.Text = "LOADING…"
	startBtn.Active = false
	startBtn.BackgroundColor3 = Theme.SuccessDark
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
	winnerHeadline.Text = "VICTORY"
	winnerBody.Text = string.format("%s wins with %d / %d kills", name, kills, need)
	winnerGui.Enabled = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end)

returnToHubRemote.OnClientEvent:Connect(function()
	showHub()
end)

if player:GetAttribute("CQCInMatch") == true then
	started = true
	hideHub()
end
