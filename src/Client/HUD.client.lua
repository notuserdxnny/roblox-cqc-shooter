--!strict
--[[
	Professional in-match HUD: ammo/score/credits strip, kill feed, crosshair, vignette.
	Hidden while hub (CQCInHub) or end overlay (CQCMatchOver).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "CQCHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 10
gui.Parent = playerGui

-- Soft vignette
local vignette = Instance.new("ImageLabel")
vignette.Name = "Vignette"
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundTransparency = 1
vignette.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
vignette.ImageTransparency = 1
vignette.ZIndex = 0
vignette.Parent = gui
-- Fake vignette with 4 edge gradients via frames
local function edge(anchor: Vector2, pos: UDim2, size: UDim2, rot: number)
	local f = Instance.new("Frame")
	f.AnchorPoint = anchor
	f.Position = pos
	f.Size = size
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BackgroundTransparency = 0.55
	f.ZIndex = 0
	f.Rotation = rot
	f.Parent = gui
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Rotation = 90
	g.Parent = f
end
edge(Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0), UDim2.new(1, 0, 0, 90), 0)
edge(Vector2.new(0.5, 1), UDim2.fromScale(0.5, 1), UDim2.new(1, 0, 0, 110), 180)

-- Crosshair (polished)
local crossRoot = Instance.new("Frame")
crossRoot.Name = "Crosshair"
crossRoot.AnchorPoint = Vector2.new(0.5, 0.5)
crossRoot.Position = UDim2.fromScale(0.5, 0.5)
crossRoot.Size = UDim2.fromOffset(40, 40)
crossRoot.BackgroundTransparency = 1
crossRoot.Parent = gui

local dot = Instance.new("Frame")
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(3, 3)
dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
dot.BorderSizePixel = 0
dot.Parent = crossRoot
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = dot
end

local function arm(dx: number, dy: number, w: number, h: number)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.new(0.5, dx, 0.5, dy)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = Color3.fromRGB(245, 248, 255)
	f.BorderSizePixel = 0
	f.Parent = crossRoot
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 1)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(0, 0, 0)
	s.Thickness = 1
	s.Transparency = 0.55
	s.Parent = f
end
arm(0, -12, 2, 8)
arm(0, 12, 2, 8)
arm(-12, 0, 8, 2)
arm(12, 0, 8, 2)

-- Top hint
local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.AnchorPoint = Vector2.new(0.5, 0)
hint.Position = UDim2.new(0.5, 0, 0, 14)
hint.Size = UDim2.fromOffset(720, 24)
hint.BackgroundTransparency = 1
hint.Font = Theme.FontBody
hint.TextSize = 13
hint.TextColor3 = Theme.TextMuted
hint.TextStrokeTransparency = 0.6
hint.Text = string.format("OITC  ·  First to %d  ·  Kill = +1 bullet  ·  Hold LMB", Config.OITC.KillsToWin)
hint.Parent = gui

-- Bottom strip
local strip = Instance.new("Frame")
strip.Name = "Strip"
strip.AnchorPoint = Vector2.new(0.5, 1)
strip.Position = UDim2.new(0.5, 0, 1, -18)
strip.Size = UDim2.fromOffset(560, 64)
strip.BackgroundColor3 = Theme.Panel
strip.BackgroundTransparency = 0.12
strip.BorderSizePixel = 0
strip.Parent = gui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = strip
	local s = Instance.new("UIStroke")
	s.Color = Theme.Stroke
	s.Thickness = 1
	s.Transparency = 0.25
	s.Parent = strip
end

local function stripCell(xScale: number, label: string, color: Color3): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.new(xScale, 0, 0, 0)
	t.Size = UDim2.new(0.25, 0, 1, 0)
	t.Font = Theme.FontTitle
	t.TextSize = 15
	t.TextColor3 = color
	t.Text = label
	t.Parent = strip
	return t
end

local healthLabel = stripCell(0, "HP 100", Color3.fromRGB(120, 255, 160))
local ammoLabel = stripCell(0.25, "BULLETS 1", Theme.Credits)
local scoreLabel = stripCell(0.5, "SCORE 0/5", Theme.OITC)
local creditsLabel = stripCell(0.75, "₵ 0", Theme.Credits)

local weaponChip = Instance.new("TextLabel")
weaponChip.AnchorPoint = Vector2.new(0, 1)
weaponChip.Position = UDim2.new(0, 18, 1, -90)
weaponChip.Size = UDim2.fromOffset(180, 28)
weaponChip.BackgroundColor3 = Theme.PanelAlt
weaponChip.BackgroundTransparency = 0.15
weaponChip.BorderSizePixel = 0
weaponChip.Font = Theme.FontTitle
weaponChip.TextSize = 13
weaponChip.TextColor3 = Theme.Accent
weaponChip.Text = "PISTOL"
weaponChip.Parent = gui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = weaponChip
end

-- Kill feed
local feed = Instance.new("Frame")
feed.Name = "KillFeed"
feed.AnchorPoint = Vector2.new(1, 0)
feed.Position = UDim2.new(1, -18, 0, 48)
feed.Size = UDim2.fromOffset(300, 180)
feed.BackgroundTransparency = 1
feed.Parent = gui
local feedLayout = Instance.new("UIListLayout")
feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
feedLayout.Padding = UDim.new(0, 5)
feedLayout.Parent = feed

local ammo = 0
local kills = 0
local weaponName = "Pistol"
local oitcScore = 0
local killsToWin = Config.OITC.KillsToWin
local meleeReady = false
local credits = 0

local function refreshAmmoText()
	if meleeReady or ammo <= 0 then
		ammoLabel.Text = "MELEE"
		ammoLabel.TextColor3 = Theme.Danger
	else
		ammoLabel.Text = string.format("BULLETS %d", ammo)
		ammoLabel.TextColor3 = if ammo <= 1 then Theme.Warning else Theme.Credits
	end
end

local function refreshScore()
	scoreLabel.Text = string.format("SCORE %d/%d", oitcScore, killsToWin)
end

local function refreshCredits()
	creditsLabel.Text = string.format("₵ %d", credits)
end

local function refreshWeapon()
	weaponChip.Text = string.upper(weaponName)
end

local function syncHudVisible()
	local hide = player:GetAttribute("CQCInHub") == true or player:GetAttribute("CQCMatchOver") == true
	gui.Enabled = not hide
end
syncHudVisible()
player:GetAttributeChangedSignal("CQCInHub"):Connect(syncHudVisible)
player:GetAttributeChangedSignal("CQCMatchOver"):Connect(syncHudVisible)

local function bindHumanoid(humanoid: Humanoid)
	local function update()
		local hp = math.max(0, math.floor(humanoid.Health + 0.5))
		local max = math.max(1, math.floor(humanoid.MaxHealth + 0.5))
		healthLabel.Text = string.format("HP %d", hp)
		local ratio = hp / max
		if ratio > 0.5 then
			healthLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
		elseif ratio > 0.25 then
			healthLabel.TextColor3 = Theme.Warning
		else
			healthLabel.TextColor3 = Theme.Danger
		end
	end
	update()
	humanoid.HealthChanged:Connect(update)
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	bindHumanoid(humanoid)
end

if player.Character then
	task.spawn(onCharacter, player.Character)
end
player.CharacterAdded:Connect(onCharacter)

local ammoRemote = remotes:WaitForChild(Config.Remotes.AmmoUpdate) :: RemoteEvent
ammoRemote.OnClientEvent:Connect(function(current, _max, _isReloading, _weaponId, wName)
	ammo = current
	meleeReady = ammo <= 0
	if typeof(wName) == "string" and wName ~= "" then
		weaponName = wName
		refreshWeapon()
	end
	refreshAmmoText()
end)

local statsRemote = remotes:WaitForChild(Config.Remotes.StatsUpdate) :: RemoteEvent
statsRemote.OnClientEvent:Connect(function(stats)
	if typeof(stats) ~= "table" then
		return
	end
	if stats.oitcScore ~= nil then
		oitcScore = stats.oitcScore
	end
	if stats.killsToWin ~= nil then
		killsToWin = stats.killsToWin
	end
	if stats.kills ~= nil then
		kills = stats.kills
		if stats.oitcScore == nil then
			oitcScore = stats.kills
		end
	end
	if stats.meleeReady ~= nil then
		meleeReady = stats.meleeReady == true
	end
	if stats.ammo ~= nil then
		ammo = stats.ammo
		meleeReady = ammo <= 0
	end
	if typeof(stats.weaponName) == "string" and stats.weaponName ~= "" then
		weaponName = stats.weaponName
		refreshWeapon()
	end
	if typeof(stats.credits) == "number" then
		credits = stats.credits
		refreshCredits()
	end
	hint.Text = string.format("OITC  ·  First to %d  ·  Kill = +1 bullet  ·  Hold LMB", killsToWin)
	refreshScore()
	refreshAmmoText()
end)

local creditsRemote = remotes:WaitForChild(Config.Remotes.CreditsUpdate) :: RemoteEvent
creditsRemote.OnClientEvent:Connect(function(amount)
	if typeof(amount) == "number" then
		credits = amount
		refreshCredits()
	end
end)

player:GetAttributeChangedSignal("CQCCredits"):Connect(function()
	local c = player:GetAttribute("CQCCredits")
	if typeof(c) == "number" then
		credits = c
		refreshCredits()
	end
end)

local killFeedRemote = remotes:WaitForChild(Config.Remotes.KillFeed) :: RemoteEvent
killFeedRemote.OnClientEvent:Connect(function(killer, victim)
	local isLocal = tostring(killer) == player.Name
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 26)
	row.BackgroundColor3 = if isLocal then Color3.fromRGB(36, 60, 42) else Theme.Panel
	row.BackgroundTransparency = 0.2
	row.BorderSizePixel = 0
	row.Parent = feed
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = row
	local s = Instance.new("UIStroke")
	s.Color = if isLocal then Theme.Success else Theme.Stroke
	s.Thickness = 1
	s.Transparency = 0.3
	s.Parent = row
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Theme.FontTitle
	label.TextSize = if isLocal then 13 else 12
	label.TextColor3 = if isLocal then Theme.Credits else Theme.Text
	label.Text = string.format("  %s  ▸  %s  ", tostring(killer), tostring(victim))
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.Parent = row
	task.delay(4.5, function()
		row:Destroy()
	end)
end)

local matchStartedRemote = remotes:WaitForChild(Config.Remotes.MatchStarted) :: RemoteEvent
matchStartedRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) == "table" and payload.killsToWin then
		killsToWin = payload.killsToWin
		refreshScore()
	end
end)

player:GetAttributeChangedSignal("CQCOITCScore"):Connect(function()
	local s = player:GetAttribute("CQCOITCScore")
	if typeof(s) == "number" then
		oitcScore = s
		refreshScore()
	end
end)

refreshAmmoText()
refreshWeapon()
refreshScore()
refreshCredits()
