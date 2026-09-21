--!strict
--[[
	Simple HUD: health, ammo, kills, kill feed, crosshair.
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
panel.Size = UDim2.fromOffset(260, 110)
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
healthLabel.Position = UDim2.fromOffset(14, 10)
healthLabel.Size = UDim2.new(1, -28, 0, 28)
healthLabel.Font = Enum.Font.GothamBold
healthLabel.TextSize = 20
healthLabel.TextXAlignment = Enum.TextXAlignment.Left
healthLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
healthLabel.Text = "HP 100"
healthLabel.Parent = panel

local ammoLabel = Instance.new("TextLabel")
ammoLabel.Name = "Ammo"
ammoLabel.BackgroundTransparency = 1
ammoLabel.Position = UDim2.fromOffset(14, 42)
ammoLabel.Size = UDim2.new(1, -28, 0, 28)
ammoLabel.Font = Enum.Font.GothamBold
ammoLabel.TextSize = 20
ammoLabel.TextXAlignment = Enum.TextXAlignment.Left
ammoLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
ammoLabel.Text = string.format("AMMO %d / %d", Config.Weapon.MagazineSize, Config.Weapon.MagazineSize)
ammoLabel.Parent = panel

local killsLabel = Instance.new("TextLabel")
killsLabel.Name = "Kills"
killsLabel.BackgroundTransparency = 1
killsLabel.Position = UDim2.fromOffset(14, 72)
killsLabel.Size = UDim2.new(1, -28, 0, 28)
killsLabel.Font = Enum.Font.GothamBold
killsLabel.TextSize = 18
killsLabel.TextXAlignment = Enum.TextXAlignment.Left
killsLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
killsLabel.Text = "KILLS 0"
killsLabel.Parent = panel

-- Hint
local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.AnchorPoint = Vector2.new(0.5, 0)
hint.Position = UDim2.new(0.5, 0, 0, 18)
hint.Size = UDim2.fromOffset(520, 28)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 16
hint.TextColor3 = Color3.fromRGB(230, 230, 240)
hint.TextStrokeTransparency = 0.5
hint.Text = "FPS lock-on · CQC Blaster · Hold LMB · R reload · Doors: ProximityPrompt · Jump half-walls / slide crawl gaps"
hint.Parent = gui

-- Kill feed
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

local ammo = Config.Weapon.MagazineSize
local magSize = Config.Weapon.MagazineSize
local reloading = false
local kills = 0

local function refreshAmmoText()
	if reloading then
		ammoLabel.Text = "RELOADING..."
		ammoLabel.TextColor3 = Color3.fromRGB(255, 140, 80)
	else
		ammoLabel.Text = string.format("AMMO %d / %d", ammo, magSize)
		ammoLabel.TextColor3 = if ammo <= 3 then Color3.fromRGB(255, 100, 100) else Color3.fromRGB(255, 220, 120)
	end
end

local function refreshKills()
	killsLabel.Text = string.format("KILLS %d", kills)
end

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
ammoRemote.OnClientEvent:Connect(function(current, max, isReloading)
	ammo = current
	magSize = max
	reloading = isReloading == true
	refreshAmmoText()
end)

local statsRemote = remotes:WaitForChild(Config.Remotes.StatsUpdate) :: RemoteEvent
statsRemote.OnClientEvent:Connect(function(stats)
	if typeof(stats) ~= "table" then
		return
	end
	if stats.kills ~= nil then
		kills = stats.kills
		refreshKills()
	end
	if stats.ammo ~= nil then
		ammo = stats.ammo
	end
	if stats.magSize ~= nil then
		magSize = stats.magSize
	end
	if stats.reloading ~= nil then
		reloading = stats.reloading
	end
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

refreshAmmoText()
refreshKills()
