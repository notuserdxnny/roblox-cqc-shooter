--!strict
--[[
	OITC-only lobby / hub ScreenGui + match countdown + end overlay.
	Branding + rules card + primary START (+ how-to). No mode picker / Casual loadout.
	While open: Classic camera + unlocked mouse (CQCInHub).
	On Start: StartMatch → teleport (server) → MatchCountdown 3…2…1…GO! → MatchStarted.
	On win: end overlay with Play Again (countdown) and Hub.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local startMatchRemote = remotes:WaitForChild(Config.Remotes.StartMatch) :: RemoteEvent
local matchCountdownRemote = remotes:WaitForChild(Config.Remotes.MatchCountdown) :: RemoteEvent
local matchStartedRemote = remotes:WaitForChild(Config.Remotes.MatchStarted) :: RemoteEvent
local matchEndedRemote = remotes:WaitForChild(Config.Remotes.MatchEnded) :: RemoteEvent
local returnToHubRemote = remotes:WaitForChild(Config.Remotes.ReturnToHub) :: RemoteEvent

player:SetAttribute("CQCInHub", true)

local Theme = {
	Bg = Color3.fromRGB(10, 12, 18),
	Panel = Color3.fromRGB(18, 22, 32),
	PanelAlt = Color3.fromRGB(24, 30, 44),
	Card = Color3.fromRGB(28, 34, 50),
	Stroke = Color3.fromRGB(55, 64, 88),
	Text = Color3.fromRGB(236, 240, 250),
	TextMuted = Color3.fromRGB(150, 160, 184),
	TextDim = Color3.fromRGB(110, 120, 145),
	Accent = Color3.fromRGB(70, 140, 230),
	Success = Color3.fromRGB(56, 170, 110),
	SuccessDark = Color3.fromRGB(40, 120, 80),
	Warning = Color3.fromRGB(230, 180, 80),
	OITC = Color3.fromRGB(220, 120, 70),
	Radius = 12,
	RadiusSm = 8,
}

local started = false
local countdownGen = 0
local howToExpanded = false

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
card.Size = UDim2.fromOffset(560, 440)
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

local badge = Instance.new("Frame")
badge.Name = "Badge"
badge.Size = UDim2.fromOffset(140, 22)
badge.BackgroundColor3 = Theme.OITC
badge.BorderSizePixel = 0
badge.Parent = card
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = badge
end

local badgeText = Instance.new("TextLabel")
badgeText.BackgroundTransparency = 1
badgeText.Size = UDim2.fromScale(1, 1)
badgeText.Font = Enum.Font.GothamBold
badgeText.TextSize = 11
badgeText.TextColor3 = Color3.fromRGB(255, 255, 255)
badgeText.Text = "OITC ONLY"
badgeText.Parent = badge

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(0, 30)
title.Size = UDim2.new(1, 0, 0, 34)
title.Font = Enum.Font.GothamBold
title.TextSize = 28
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Theme.Text
title.Text = Config.Hub.Title
title.Parent = card

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(0, 66)
subtitle.Size = UDim2.new(1, 0, 0, 22)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 14
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextColor3 = Theme.TextMuted
subtitle.Text = Config.Hub.Subtitle
subtitle.Parent = card

local sectionRules = Instance.new("TextLabel")
sectionRules.BackgroundTransparency = 1
sectionRules.Position = UDim2.fromOffset(0, 104)
sectionRules.Size = UDim2.new(1, 0, 0, 18)
sectionRules.Font = Enum.Font.GothamBold
sectionRules.TextSize = 12
sectionRules.TextXAlignment = Enum.TextXAlignment.Left
sectionRules.TextColor3 = Theme.TextDim
sectionRules.Text = "RULES"
sectionRules.Parent = card

local oitcInfo = Instance.new("Frame")
oitcInfo.Name = "OITCInfo"
oitcInfo.BackgroundColor3 = Theme.PanelAlt
oitcInfo.Position = UDim2.fromOffset(0, 128)
oitcInfo.Size = UDim2.new(1, 0, 0, 160)
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
	local accentBar = Instance.new("Frame")
	accentBar.Size = UDim2.new(1, 0, 0, 3)
	accentBar.Position = UDim2.new(0, 0, 1, -3)
	accentBar.BackgroundColor3 = Theme.OITC
	accentBar.BorderSizePixel = 0
	accentBar.Parent = oitcInfo
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
	"%s\n\nPistol only  ·  magazine = 1 bullet\nKill (gun or knife) = +1 bullet\nEmpty ammo = Knife melee (short range)\nFirst to %d kills wins\nDeath respawns with 1 bullet",
	Config.Hub.ModeOITCBlurb or "One bullet. One pistol. Knife when empty.",
	Config.OITC.KillsToWin
)
oitcBody.Parent = oitcInfo

local howTo = Instance.new("TextLabel")
howTo.BackgroundTransparency = 1
howTo.Position = UDim2.fromOffset(0, 300)
howTo.Size = UDim2.new(1, 0, 0, 48)
howTo.Font = Enum.Font.Gotham
howTo.TextSize = 12
howTo.TextWrapped = true
howTo.TextXAlignment = Enum.TextXAlignment.Left
howTo.TextYAlignment = Enum.TextYAlignment.Top
howTo.TextColor3 = Theme.TextDim
howTo.Text = Config.Hub.HowToOITC or Config.Hub.HowTo
howTo.Visible = false
howTo.Parent = card

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

--------------------------------------------------------------------------
-- Countdown overlay
--------------------------------------------------------------------------
local countdownGui = Instance.new("ScreenGui")
countdownGui.Name = "CQCCountdown"
countdownGui.ResetOnSpawn = false
countdownGui.IgnoreGuiInset = true
countdownGui.DisplayOrder = 110
countdownGui.Enabled = false
countdownGui.Parent = playerGui

local cdDim = Instance.new("Frame")
cdDim.Size = UDim2.fromScale(1, 1)
cdDim.BackgroundColor3 = Theme.Bg
cdDim.BackgroundTransparency = 0.55
cdDim.BorderSizePixel = 0
cdDim.Parent = countdownGui

local cdLabel = Instance.new("TextLabel")
cdLabel.Name = "Count"
cdLabel.AnchorPoint = Vector2.new(0.5, 0.5)
cdLabel.Position = UDim2.fromScale(0.5, 0.48)
cdLabel.Size = UDim2.fromOffset(600, 180)
cdLabel.BackgroundTransparency = 1
cdLabel.Font = Enum.Font.GothamBold
cdLabel.TextSize = 120
cdLabel.TextColor3 = Theme.Text
cdLabel.TextStrokeTransparency = 0.4
cdLabel.Text = "3"
cdLabel.Parent = countdownGui

local cdSub = Instance.new("TextLabel")
cdSub.AnchorPoint = Vector2.new(0.5, 0)
cdSub.Position = UDim2.new(0.5, 0, 0.48, 70)
cdSub.Size = UDim2.fromOffset(480, 28)
cdSub.BackgroundTransparency = 1
cdSub.Font = Enum.Font.Gotham
cdSub.TextSize = 16
cdSub.TextColor3 = Theme.TextMuted
cdSub.Text = "GET READY"
cdSub.Parent = countdownGui

--------------------------------------------------------------------------
-- Winner / end overlay
--------------------------------------------------------------------------
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
winnerDim.BackgroundTransparency = 0.4
winnerDim.BorderSizePixel = 0
winnerDim.Parent = winnerGui

local winnerCard = Instance.new("Frame")
winnerCard.AnchorPoint = Vector2.new(0.5, 0.5)
winnerCard.Position = UDim2.fromScale(0.5, 0.5)
winnerCard.Size = UDim2.fromOffset(480, 280)
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
winnerTitle.Size = UDim2.new(1, 0, 0, 22)
winnerTitle.Font = Enum.Font.GothamBold
winnerTitle.TextSize = 12
winnerTitle.TextXAlignment = Enum.TextXAlignment.Left
winnerTitle.TextColor3 = Theme.TextDim
winnerTitle.Text = "ONE IN THE CHAMBER"
winnerTitle.Parent = winnerCard

local winnerHeadline = Instance.new("TextLabel")
winnerHeadline.BackgroundTransparency = 1
winnerHeadline.Position = UDim2.fromOffset(0, 28)
winnerHeadline.Size = UDim2.new(1, 0, 0, 40)
winnerHeadline.Font = Enum.Font.GothamBold
winnerHeadline.TextSize = 32
winnerHeadline.TextXAlignment = Enum.TextXAlignment.Left
winnerHeadline.TextColor3 = Theme.Warning
winnerHeadline.Text = "YOU WIN"
winnerHeadline.Parent = winnerCard

local winnerBody = Instance.new("TextLabel")
winnerBody.BackgroundTransparency = 1
winnerBody.Position = UDim2.fromOffset(0, 78)
winnerBody.Size = UDim2.new(1, 0, 0, 56)
winnerBody.Font = Enum.Font.Gotham
winnerBody.TextSize = 15
winnerBody.TextWrapped = true
winnerBody.TextXAlignment = Enum.TextXAlignment.Left
winnerBody.TextYAlignment = Enum.TextYAlignment.Top
winnerBody.TextColor3 = Theme.TextMuted
winnerBody.Text = ""
winnerBody.Parent = winnerCard

local endFooter = Instance.new("Frame")
endFooter.Name = "EndFooter"
endFooter.BackgroundTransparency = 1
endFooter.AnchorPoint = Vector2.new(0.5, 1)
endFooter.Position = UDim2.new(0.5, 0, 1, 0)
endFooter.Size = UDim2.new(1, 0, 0, 48)
endFooter.Parent = winnerCard

local playAgainBtn = Instance.new("TextButton")
playAgainBtn.Name = "PlayAgain"
playAgainBtn.Size = UDim2.fromOffset(190, 46)
playAgainBtn.Position = UDim2.fromOffset(0, 0)
playAgainBtn.BackgroundColor3 = Theme.Success
playAgainBtn.BorderSizePixel = 0
playAgainBtn.Font = Enum.Font.GothamBold
playAgainBtn.TextSize = 14
playAgainBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
playAgainBtn.Text = "PLAY AGAIN"
playAgainBtn.AutoButtonColor = false
playAgainBtn.Parent = endFooter
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, Theme.RadiusSm)
	c.Parent = playAgainBtn
end

local hubAgainBtn = Instance.new("TextButton")
hubAgainBtn.Name = "Hub"
hubAgainBtn.AnchorPoint = Vector2.new(1, 0)
hubAgainBtn.Position = UDim2.new(1, 0, 0, 0)
hubAgainBtn.Size = UDim2.fromOffset(190, 46)
hubAgainBtn.BackgroundColor3 = Theme.Accent
hubAgainBtn.BorderSizePixel = 0
hubAgainBtn.Font = Enum.Font.GothamBold
hubAgainBtn.TextSize = 14
hubAgainBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hubAgainBtn.Text = "HUB"
hubAgainBtn.AutoButtonColor = false
hubAgainBtn.Parent = endFooter
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, Theme.RadiusSm)
	c.Parent = hubAgainBtn
end

local function playLocalSound(soundId: string?, volume: number?)
	if typeof(soundId) ~= "string" or soundId == "" or soundId == "rbxassetid://0" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume or 0.5
	s.Parent = playerGui
	s:Play()
	Debris:AddItem(s, 4)
end

local function unlockMouse()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

local function applyHubCamera(inHub: boolean)
	player:SetAttribute("CQCInHub", inHub)
	if inHub then
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = Config.Camera.HubMinZoom or 8
		player.CameraMaxZoomDistance = Config.Camera.HubMaxZoom or 20
		unlockMouse()
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
end

local function showHub()
	started = false
	startBtn.Text = "START MATCH"
	startBtn.Active = true
	startBtn.BackgroundColor3 = Theme.Success
	winnerGui.Enabled = false
	countdownGui.Enabled = false
	gui.Enabled = true
	applyHubCamera(true)
	howTo.Text = Config.Hub.HowToOITC or Config.Hub.HowTo
end

local function formatDuration(sec: number): string
	local s = math.max(0, math.floor(sec + 0.5))
	local m = math.floor(s / 60)
	local r = s % 60
	if m > 0 then
		return string.format("%d:%02d", m, r)
	end
	return string.format("%ds", r)
end

local function requestStart()
	started = true
	startBtn.Text = "LOADING…"
	startBtn.Active = false
	startBtn.BackgroundColor3 = Theme.SuccessDark
	winnerGui.Enabled = false
	hideHub()
	unlockMouse()
	player:SetAttribute("CQCInHub", false)
	startMatchRemote:FireServer({
		weaponId = Config.OITC.WeaponId,
		mode = Config.Modes.OITC,
	})
end

local function onStart()
	if started then
		return
	end
	requestStart()
end

startBtn.MouseButton1Click:Connect(onStart)

playAgainBtn.MouseButton1Click:Connect(function()
	countdownGen += 1
	winnerGui.Enabled = false
	started = false
	requestStart()
end)

hubAgainBtn.MouseButton1Click:Connect(function()
	countdownGen += 1
	returnToHubRemote:FireServer()
	showHub()
end)

local function runCountdownVisual(payload: any)
	countdownGen += 1
	local gen = countdownGen
	local seconds = 3
	if typeof(payload) == "table" and typeof(payload.seconds) == "number" then
		seconds = math.max(0, math.floor(payload.seconds))
	end
	local goHold = 0.85
	if typeof(payload) == "table" and typeof(payload.goDisplaySeconds) == "number" then
		goHold = math.max(0.2, payload.goDisplaySeconds)
	end

	winnerGui.Enabled = false
	hideHub()
	countdownGui.Enabled = true
	unlockMouse()
	player:SetAttribute("CQCInHub", false)
	if Config.Camera.LockFirstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMinZoomDistance = Config.Camera.MinZoom
		player.CameraMaxZoomDistance = Config.Camera.MaxZoom
	end

	cdSub.Text = "ONE IN THE CHAMBER  ·  GET READY"
	local tickId = (Config.SoundIds and Config.SoundIds.CountdownTick) or nil
	local tickVol = (Config.SoundVolumes and Config.SoundVolumes.CountdownTick) or 0.35

	task.spawn(function()
		for i = seconds, 1, -1 do
			if countdownGen ~= gen then
				return
			end
			cdLabel.Text = tostring(i)
			cdLabel.TextColor3 = Theme.Text
			cdLabel.TextSize = 120
			playLocalSound(tickId, tickVol)
			task.wait(1)
		end
		if countdownGen ~= gen then
			return
		end
		cdLabel.Text = "GO!"
		cdLabel.TextColor3 = Theme.Success
		cdLabel.TextSize = 110
		cdSub.Text = "FIGHT"
		local startId = Config.Match and Config.Match.RoundStartSoundId
		if typeof(startId) ~= "string" or startId == "" then
			startId = Config.SoundIds and Config.SoundIds.RoundStart
		end
		local startVol = (Config.Match and Config.Match.RoundStartSoundVolume)
			or (Config.SoundVolumes and Config.SoundVolumes.RoundStart)
			or 0.55
		playLocalSound(startId, startVol)
		task.wait(goHold)
		if countdownGen ~= gen then
			return
		end
		if countdownGui.Enabled then
			countdownGui.Enabled = false
		end
	end)
end

matchCountdownRemote.OnClientEvent:Connect(function(payload)
	started = true
	runCountdownVisual(payload)
end)

matchStartedRemote.OnClientEvent:Connect(function(_payload)
	started = true
	countdownGen += 1
	countdownGui.Enabled = false
	winnerGui.Enabled = false
	hideHub()
	applyHubCamera(false)
end)

matchEndedRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	countdownGen += 1
	countdownGui.Enabled = false

	local name = tostring(payload.winnerName or "?")
	local kills = tonumber(payload.kills) or 0
	local need = tonumber(payload.killsToWin) or Config.OITC.KillsToWin
	local youWin = payload.youWin == true or payload.winnerUserId == player.UserId
	local duration = tonumber(payload.durationSec) or 0

	winnerTitle.Text = "ONE IN THE CHAMBER"
	if youWin then
		winnerHeadline.Text = "YOU WIN"
		winnerHeadline.TextColor3 = Theme.Warning
	else
		winnerHeadline.Text = "MATCH OVER"
		winnerHeadline.TextColor3 = Theme.Text
	end

	local scoreLine = string.format("%s  ·  %d / %d kills", name, kills, need)
	if duration > 0 then
		scoreLine ..= string.format("\nTime  %s", formatDuration(duration))
	end
	winnerBody.Text = scoreLine

	winnerGui.Enabled = true
	unlockMouse()
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = Config.Camera.HubMinZoom or 8
	player.CameraMaxZoomDistance = Config.Camera.HubMaxZoom or 20
	pcall(function()
		player.DevEnableMouseLock = false
	end)
end)

returnToHubRemote.OnClientEvent:Connect(function()
	countdownGen += 1
	countdownGui.Enabled = false
	showHub()
end)

if player:GetAttribute("CQCInMatch") == true then
	started = true
	hideHub()
	applyHubCamera(false)
end
