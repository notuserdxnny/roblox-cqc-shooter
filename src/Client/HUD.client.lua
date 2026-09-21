--!strict
--[[
	HUD: health, ammo/bullets, weapon name, kills / OITC score, kill feed, crosshair.
	Hidden while hub is open (CQCInHub).
	OITC: shows BULLETS + score / KillsToWin; MELEE when empty.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
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

-- Crosshair
local cross = Instance.new("Frame")
cross.Name = "Crosshair"
cross.AnchorPoint = Vector2.new(0.5, 0.5)
cross.Position = UDim2.fromScale(0.5, 0.5)
cross.Size = UDim2.fromOffset(4, 4)
cross.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
cross.BorderSizePixel = 0
cross.Parent = gui
local crossCorner = Instance.new("UICorner")
crossCorner.CornerRadius = UDim.new(1, 0)
crossCorner.Parent = cross

local function arm(dx: number, dy: number, w: number, h: number)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.new(0.5, dx, 0.5, dy)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	f.BorderSizePixel = 0
	f.Parent = gui
end
arm(0, -14, 2, 10)
arm(0, 14, 2, 10)
arm(-14, 0, 10, 2)
arm(14, 0, 10, 2)

-- Bottom-left panel
local panel = Instance.new("Frame")
panel.Name = "StatsPanel"
panel.AnchorPoint = Vector2.new(0, 1)
panel.Position = UDim2.new(0, 24, 1, -24)
panel.Size = UDim2.fromOffset(300, 150)
panel.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel = 0
panel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local healthLabel = Instance.new("TextLabel")
healthLabel.Name = "Health"
healthLabel.BackgroundTransparency = 1
healthLabel.Position = UDim2.fromOffset(14, 8)
healthLabel.Size = UDim2.new(1, -28, 0, 22)
healthLabel.Font = Enum.Font.GothamBold
healthLabel.TextSize = 18
healthLabel.TextXAlignment = Enum.TextXAlignment.Left
healthLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
healthLabel.Text = "HP 100"
healthLabel.Parent = panel

local modeLabel = Instance.new("TextLabel")
modeLabel.Name = "Mode"
modeLabel.BackgroundTransparency = 1
modeLabel.Position = UDim2.fromOffset(14, 30)
modeLabel.Size = UDim2.new(1, -28, 0, 18)
modeLabel.Font = Enum.Font.GothamBold
modeLabel.TextSize = 13
modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.TextColor3 = Color3.fromRGB(140, 180, 220)
modeLabel.Text = "MODE —"
modeLabel.Parent = panel

local weaponLabel = Instance.new("TextLabel")
weaponLabel.Name = "Weapon"
weaponLabel.BackgroundTransparency = 1
weaponLabel.Position = UDim2.fromOffset(14, 50)
weaponLabel.Size = UDim2.new(1, -28, 0, 20)
weaponLabel.Font = Enum.Font.GothamBold
weaponLabel.TextSize = 15
weaponLabel.TextXAlignment = Enum.TextXAlignment.Left
weaponLabel.TextColor3 = Color3.fromRGB(160, 200, 255)
weaponLabel.Text = "WEAPON —"
weaponLabel.Parent = panel

local ammoLabel = Instance.new("TextLabel")
ammoLabel.Name = "Ammo"
ammoLabel.BackgroundTransparency = 1
ammoLabel.Position = UDim2.fromOffset(14, 72)
ammoLabel.Size = UDim2.new(1, -28, 0, 26)
ammoLabel.Font = Enum.Font.GothamBold
ammoLabel.TextSize = 20
ammoLabel.TextXAlignment = Enum.TextXAlignment.Left
ammoLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
ammoLabel.Text = "AMMO — / —"
ammoLabel.Parent = panel

local killsLabel = Instance.new("TextLabel")
killsLabel.Name = "Kills"
killsLabel.BackgroundTransparency = 1
killsLabel.Position = UDim2.fromOffset(14, 104)
killsLabel.Size = UDim2.new(1, -28, 0, 28)
killsLabel.Font = Enum.Font.GothamBold
killsLabel.TextSize = 18
killsLabel.TextXAlignment = Enum.TextXAlignment.Left
killsLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
killsLabel.Text = "KILLS 0"
killsLabel.Parent = panel

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.AnchorPoint = Vector2.new(0.5, 0)
hint.Position = UDim2.new(0.5, 0, 0, 18)
hint.Size = UDim2.fromOffset(720, 28)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 14
hint.TextColor3 = Color3.fromRGB(230, 230, 240)
hint.TextStrokeTransparency = 0.5
hint.Text = "Shotgun · SMG · Pistol · Hold LMB · R reload · Doors · Jump half-walls / slide crawl gaps"
hint.Parent = gui

local feed = Instance.new("Frame")
feed.Name = "KillFeed"
feed.AnchorPoint = Vector2.new(1, 0)
feed.Position = UDim2.new(1, -20, 0, 60)
feed.Size = UDim2.fromOffset(280, 160)
feed.BackgroundTransparency = 1
feed.Parent = gui
local feedLayout = Instance.new("UIListLayout")
feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
feedLayout.Padding = UDim.new(0, 4)
feedLayout.Parent = feed

local ammo = 0
local magSize = 0
local reloading = false
local kills = 0
local weaponName = "—"
local mode = Config.DefaultMode
local oitcScore = 0
local killsToWin = Config.OITC.KillsToWin
local meleeReady = false

local function refreshAmmoText()
	if mode == Config.Modes.OITC then
		if meleeReady or ammo <= 0 then
			ammoLabel.Text = "BULLETS 0 — MELEE"
			ammoLabel.TextColor3 = Color3.fromRGB(255, 120, 100)
		else
			ammoLabel.Text = string.format("BULLETS %d", ammo)
			ammoLabel.TextColor3 = if ammo <= 1
				then Color3.fromRGB(255, 180, 80)
				else Color3.fromRGB(255, 220, 120)
		end
		return
	end
	if reloading then
		ammoLabel.Text = "RELOADING..."
		ammoLabel.TextColor3 = Color3.fromRGB(255, 140, 80)
	else
		ammoLabel.Text = string.format("AMMO %d / %d", ammo, magSize)
		ammoLabel.TextColor3 = if ammo <= 3 and magSize > 0
			then Color3.fromRGB(255, 100, 100)
			else Color3.fromRGB(255, 220, 120)
	end
end

local function refreshWeapon()
	weaponLabel.Text = string.format("WEAPON %s", weaponName)
end

local function refreshMode()
	if mode == Config.Modes.OITC then
		modeLabel.Text = "MODE ONE IN THE CHAMBER"
		modeLabel.TextColor3 = Color3.fromRGB(255, 180, 100)
		hint.Text = string.format(
			"OITC · Pistol · Kill = +1 bullet · Empty = Knife · First to %d · Hold LMB",
			killsToWin
		)
	else
		modeLabel.Text = "MODE CASUAL"
		modeLabel.TextColor3 = Color3.fromRGB(140, 180, 220)
		hint.Text = "Shotgun · SMG · Pistol · Hold LMB · R reload · Doors · Jump half-walls / slide crawl gaps"
	end
end

local function refreshKills()
	if mode == Config.Modes.OITC then
		killsLabel.Text = string.format("SCORE %d / %d", oitcScore, killsToWin)
		killsLabel.TextColor3 = Color3.fromRGB(255, 210, 120)
	else
		killsLabel.Text = string.format("KILLS %d", kills)
		killsLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	end
end

local function syncHudVisible()
	local hide = player:GetAttribute("CQCInHub") == true
	gui.Enabled = not hide
end
syncHudVisible()
player:GetAttributeChangedSignal("CQCInHub"):Connect(syncHudVisible)

local function bindHumanoid(humanoid: Humanoid)
	local function update()
		local hp = math.max(0, math.floor(humanoid.Health + 0.5))
		local max = math.max(1, math.floor(humanoid.MaxHealth + 0.5))
		healthLabel.Text = string.format("HP %d / %d", hp, max)
		local ratio = hp / max
		if ratio > 0.5 then
			healthLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
		elseif ratio > 0.25 then
			healthLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
		else
			healthLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
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
ammoRemote.OnClientEvent:Connect(function(current, max, isReloading, _weaponId, wName)
	ammo = current
	magSize = max
	reloading = isReloading == true
	meleeReady = mode == Config.Modes.OITC and ammo <= 0
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
	if typeof(stats.mode) == "string" then
		mode = stats.mode
		refreshMode()
	end
	if stats.oitcScore ~= nil then
		oitcScore = stats.oitcScore
	end
	if stats.killsToWin ~= nil then
		killsToWin = stats.killsToWin
	end
	if stats.kills ~= nil then
		kills = stats.kills
		if mode == Config.Modes.OITC and stats.oitcScore == nil then
			oitcScore = stats.kills
		end
	end
	if stats.meleeReady ~= nil then
		meleeReady = stats.meleeReady == true
	end
	if stats.ammo ~= nil then
		ammo = stats.ammo
		if mode == Config.Modes.OITC then
			meleeReady = ammo <= 0
		end
	end
	if stats.magSize ~= nil then
		magSize = stats.magSize
	end
	if stats.reloading ~= nil then
		reloading = stats.reloading
	end
	if typeof(stats.weaponName) == "string" and stats.weaponName ~= "" then
		weaponName = stats.weaponName
		refreshWeapon()
	end
	refreshKills()
	refreshAmmoText()
end)

local killFeedRemote = remotes:WaitForChild(Config.Remotes.KillFeed) :: RemoteEvent
killFeedRemote.OnClientEvent:Connect(function(killer, victim)
	local row = Instance.new("TextLabel")
	row.Size = UDim2.new(1, 0, 0, 22)
	row.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	row.BackgroundTransparency = 0.45
	row.BorderSizePixel = 0
	row.Font = Enum.Font.Gotham
	row.TextSize = 14
	row.TextColor3 = Color3.fromRGB(255, 255, 255)
	row.Text = string.format("%s  ✖  %s", tostring(killer), tostring(victim))
	row.Parent = feed
	task.delay(4, function()
		row:Destroy()
	end)
end)

local matchStartedRemote = remotes:WaitForChild(Config.Remotes.MatchStarted) :: RemoteEvent
matchStartedRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) == "table" and typeof(payload.mode) == "string" then
		mode = payload.mode
		if payload.killsToWin then
			killsToWin = payload.killsToWin
		end
		refreshMode()
		refreshKills()
	end
end)

-- Attribute fallbacks
player:GetAttributeChangedSignal("CQCMode"):Connect(function()
	local m = player:GetAttribute("CQCMode")
	if typeof(m) == "string" then
		mode = m
		refreshMode()
		refreshKills()
		refreshAmmoText()
	end
end)
player:GetAttributeChangedSignal("CQCOITCScore"):Connect(function()
	local s = player:GetAttribute("CQCOITCScore")
	if typeof(s) == "number" then
		oitcScore = s
		refreshKills()
	end
end)

refreshMode()
refreshAmmoText()
refreshWeapon()
refreshKills()
