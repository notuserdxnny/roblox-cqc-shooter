--!strict
--[[
	Full-bleed game hub (Valorant/Fortnite-lite lobby menu).
	Opaque root Frame Size(1,1) — zero world visibility.
	Left sidebar nav + main content region. Shop/Inventory as card grids.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Theme"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local startMatchRemote = remotes:WaitForChild(Config.Remotes.StartMatch) :: RemoteEvent
local matchCountdownRemote = remotes:WaitForChild(Config.Remotes.MatchCountdown) :: RemoteEvent
local matchStartedRemote = remotes:WaitForChild(Config.Remotes.MatchStarted) :: RemoteEvent
local matchEndedRemote = remotes:WaitForChild(Config.Remotes.MatchEnded) :: RemoteEvent
local returnToHubRemote = remotes:WaitForChild(Config.Remotes.ReturnToHub) :: RemoteEvent
local getShopRemote = remotes:WaitForChild(Config.Remotes.GetShop) :: RemoteEvent
local purchaseRemote = remotes:WaitForChild(Config.Remotes.PurchaseItem) :: RemoteEvent
local equipRemote = remotes:WaitForChild(Config.Remotes.EquipItem) :: RemoteEvent
local creditsRemote = remotes:WaitForChild(Config.Remotes.CreditsUpdate) :: RemoteEvent
local dataSyncRemote = remotes:WaitForChild(Config.Remotes.PlayerDataSync) :: RemoteEvent
local shopResultRemote = remotes:WaitForChild(Config.Remotes.ShopResult) :: RemoteEvent

player:SetAttribute("CQCInHub", true)

local started = false
local countdownGen = 0
local howToExpanded = false
local activeTab = "Play"
local credits = Config.Economy.StartingCredits
local shopItems: { any } = {}
local ownedSet: { [string]: boolean } = {}
local equipped: { [string]: string } = {
	PistolSkin = "pistol_default",
	KnifeSkin = "knife_default",
	Trail = "trail_none",
	Hitmarker = "hit_default",
	Title = "title_none",
}
local statusMsg = ""
local hubCamConn: RBXScriptConnection? = nil

local SIDEBAR_W = Theme.SidebarWidth or 248
local CONTENT_PAD = Theme.ContentPad or 40

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------
local function corner(parent: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or Theme.Radius)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, color: Color3?, thick: number?, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Stroke
	s.Thickness = thick or 1
	s.Transparency = transparency or 0.15
	s.Parent = parent
	return s
end

local function clearChildren(frame: Instance)
	for _, c in frame:GetChildren() do
		if c:IsA("Frame") or c:IsA("TextLabel") or c:IsA("TextButton") or c:IsA("ScrollingFrame")
			or c:IsA("UIListLayout") or c:IsA("UIGridLayout") then
			c:Destroy()
		end
	end
end

--------------------------------------------------------------------------
-- Root: fully opaque full-bleed ScreenGui
--------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "CQCHub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Opaque full-bleed root — NOTHING of the 3D world shows through
local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.Position = UDim2.fromScale(0, 0)
root.BackgroundColor3 = Theme.Bg
root.BackgroundTransparency = 0 -- fully opaque
root.BorderSizePixel = 0
root.Active = true
root.ZIndex = 1
root.Parent = gui

local rootGrad = Instance.new("UIGradient")
rootGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 10, 18)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(6, 8, 14)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 8, 16)),
})
rootGrad.Rotation = 125
rootGrad.Parent = root

--------------------------------------------------------------------------
-- Left sidebar
--------------------------------------------------------------------------
local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, 0)
sidebar.Position = UDim2.fromScale(0, 0)
sidebar.BackgroundColor3 = Theme.Sidebar
sidebar.BackgroundTransparency = 0
sidebar.BorderSizePixel = 0
sidebar.ZIndex = 2
sidebar.Parent = root

local sideGrad = Instance.new("UIGradient")
sideGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 14, 24)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 10, 18)),
})
sideGrad.Rotation = 180
sideGrad.Parent = sidebar

-- Right edge accent line on sidebar
local sideEdge = Instance.new("Frame")
sideEdge.Name = "Edge"
sideEdge.AnchorPoint = Vector2.new(1, 0)
sideEdge.Position = UDim2.new(1, 0, 0, 0)
sideEdge.Size = UDim2.new(0, 1, 1, 0)
sideEdge.BackgroundColor3 = Theme.Stroke
sideEdge.BackgroundTransparency = 0.35
sideEdge.BorderSizePixel = 0
sideEdge.ZIndex = 3
sideEdge.Parent = sidebar

local sidePad = Instance.new("UIPadding")
sidePad.PaddingTop = UDim.new(0, 28)
sidePad.PaddingBottom = UDim.new(0, 24)
sidePad.PaddingLeft = UDim.new(0, 20)
sidePad.PaddingRight = UDim.new(0, 20)
sidePad.Parent = sidebar

-- Logo / brand block
local brandBlock = Instance.new("Frame")
brandBlock.Name = "Brand"
brandBlock.Size = UDim2.new(1, 0, 0, 72)
brandBlock.BackgroundTransparency = 1
brandBlock.Parent = sidebar

local logoMark = Instance.new("Frame")
logoMark.Size = UDim2.fromOffset(36, 36)
logoMark.BackgroundColor3 = Theme.OITC
logoMark.BorderSizePixel = 0
logoMark.Parent = brandBlock
corner(logoMark, 8)
local logoMarkGrad = Instance.new("UIGradient")
logoMarkGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 50)),
})
logoMarkGrad.Rotation = 135
logoMarkGrad.Parent = logoMark

local logoLetter = Instance.new("TextLabel")
logoLetter.BackgroundTransparency = 1
logoLetter.Size = UDim2.fromScale(1, 1)
logoLetter.Font = Theme.FontTitle
logoLetter.TextSize = 18
logoLetter.TextColor3 = Color3.fromRGB(255, 255, 255)
logoLetter.Text = "1"
logoLetter.Parent = logoMark

local brandTitle = Instance.new("TextLabel")
brandTitle.BackgroundTransparency = 1
brandTitle.Position = UDim2.fromOffset(48, 2)
brandTitle.Size = UDim2.new(1, -48, 0, 20)
brandTitle.Font = Theme.FontTitle
brandTitle.TextSize = 15
brandTitle.TextXAlignment = Enum.TextXAlignment.Left
brandTitle.TextColor3 = Theme.Text
brandTitle.Text = "OITC"
brandTitle.Parent = brandBlock

local brandSub = Instance.new("TextLabel")
brandSub.BackgroundTransparency = 1
brandSub.Position = UDim2.fromOffset(48, 22)
brandSub.Size = UDim2.new(1, -48, 0, 16)
brandSub.Font = Theme.FontBody
brandSub.TextSize = 11
brandSub.TextXAlignment = Enum.TextXAlignment.Left
brandSub.TextColor3 = Theme.TextDim
brandSub.Text = "CQC SHOOTER"
brandSub.Parent = brandBlock

-- Nav buttons container
local navList = Instance.new("Frame")
navList.Name = "Nav"
navList.Position = UDim2.fromOffset(0, 96)
navList.Size = UDim2.new(1, 0, 1, -180)
navList.BackgroundTransparency = 1
navList.Parent = sidebar

local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection = Enum.FillDirection.Vertical
navLayout.Padding = UDim.new(0, 6)
navLayout.SortOrder = Enum.SortOrder.LayoutOrder
navLayout.Parent = navList

-- Credits at bottom of sidebar
local creditsPanel = Instance.new("Frame")
creditsPanel.Name = "CreditsPanel"
creditsPanel.AnchorPoint = Vector2.new(0, 1)
creditsPanel.Position = UDim2.new(0, 0, 1, 0)
creditsPanel.Size = UDim2.new(1, 0, 0, 64)
creditsPanel.BackgroundColor3 = Theme.SidebarAlt
creditsPanel.BorderSizePixel = 0
creditsPanel.Parent = sidebar
corner(creditsPanel, Theme.RadiusSm)
stroke(creditsPanel, Theme.StrokeSoft, 1, 0.4)

local creditsLabel = Instance.new("TextLabel")
creditsLabel.BackgroundTransparency = 1
creditsLabel.Position = UDim2.fromOffset(14, 10)
creditsLabel.Size = UDim2.new(1, -28, 0, 14)
creditsLabel.Font = Theme.FontBody
creditsLabel.TextSize = 11
creditsLabel.TextXAlignment = Enum.TextXAlignment.Left
creditsLabel.TextColor3 = Theme.TextDim
creditsLabel.Text = "CREDITS"
creditsLabel.Parent = creditsPanel

local creditsBadge = Instance.new("TextLabel")
creditsBadge.Name = "Credits"
creditsBadge.BackgroundTransparency = 1
creditsBadge.Position = UDim2.fromOffset(14, 28)
creditsBadge.Size = UDim2.new(1, -28, 0, 26)
creditsBadge.Font = Theme.FontTitle
creditsBadge.TextSize = 22
creditsBadge.TextXAlignment = Enum.TextXAlignment.Left
creditsBadge.TextColor3 = Theme.Credits
creditsBadge.Text = "₵ 100"
creditsBadge.Parent = creditsPanel

--------------------------------------------------------------------------
-- Main content area (fills remaining width/height)
--------------------------------------------------------------------------
local main = Instance.new("Frame")
main.Name = "Main"
main.Position = UDim2.fromOffset(SIDEBAR_W, 0)
main.Size = UDim2.new(1, -SIDEBAR_W, 1, 0)
main.BackgroundTransparency = 1
main.ZIndex = 2
main.Parent = root

local mainPad = Instance.new("UIPadding")
mainPad.PaddingTop = UDim.new(0, CONTENT_PAD)
mainPad.PaddingBottom = UDim.new(0, CONTENT_PAD)
mainPad.PaddingLeft = UDim.new(0, CONTENT_PAD)
mainPad.PaddingRight = UDim.new(0, CONTENT_PAD)
mainPad.Parent = main

local pages: { [string]: Frame } = {}
local tabButtons: { [string]: TextButton } = {}
local tabIndicators: { [string]: Frame } = {}

local function makeNavTab(name: string, order: number, iconText: string)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(1, 0, 0, 44)
	btn.BackgroundColor3 = Theme.Sidebar
	btn.BackgroundTransparency = 1
	btn.BorderSizePixel = 0
	btn.Font = Theme.FontTitle
	btn.TextSize = 13
	btn.TextColor3 = Theme.TextMuted
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.LayoutOrder = order
	btn.Parent = navList
	corner(btn, Theme.RadiusSm)

	local indicator = Instance.new("Frame")
	indicator.Name = "Indicator"
	indicator.Size = UDim2.new(0, 3, 0, 22)
	indicator.Position = UDim2.new(0, 0, 0.5, -11)
	indicator.BackgroundColor3 = Theme.Accent
	indicator.BorderSizePixel = 0
	indicator.Visible = false
	indicator.Parent = btn
	corner(indicator, 2)

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromOffset(16, 0)
	icon.Size = UDim2.fromOffset(24, 44)
	icon.Font = Theme.FontTitle
	icon.TextSize = 14
	icon.TextColor3 = Theme.TextDim
	icon.Text = iconText
	icon.Parent = btn

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(44, 0)
	label.Size = UDim2.new(1, -52, 1, 0)
	label.Font = Theme.FontTitle
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Theme.TextMuted
	label.Text = string.upper(name)
	label.Parent = btn

	tabButtons[name] = btn
	tabIndicators[name] = indicator

	local page = Instance.new("Frame")
	page.Name = name .. "Page"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = main
	pages[name] = page

	return btn, page
end

local playBtn, playPage = makeNavTab("Play", 1, "▸")
local shopBtn, shopPage = makeNavTab("Shop", 2, "◆")
local invBtn, invPage = makeNavTab("Inventory", 3, "▣")
local setBtn, setPage = makeNavTab("Settings", 4, "⚙")

local function setTab(name: string)
	activeTab = name
	for n, page in pages do
		page.Visible = n == name
	end
	for n, btn in tabButtons do
		local label = btn:FindFirstChild("Label") :: TextLabel?
		local icon = btn:FindFirstChild("Icon") :: TextLabel?
		local ind = tabIndicators[n]
		if n == name then
			btn.BackgroundTransparency = 0
			btn.BackgroundColor3 = Theme.PanelAlt
			if label then
				label.TextColor3 = Theme.Text
			end
			if icon then
				icon.TextColor3 = Theme.AccentGlow
			end
			if ind then
				ind.Visible = true
			end
		else
			btn.BackgroundTransparency = 1
			if label then
				label.TextColor3 = Theme.TextMuted
			end
			if icon then
				icon.TextColor3 = Theme.TextDim
			end
			if ind then
				ind.Visible = false
			end
		end
	end
	if name == "Shop" or name == "Inventory" then
		getShopRemote:FireServer()
	end
end

for name, btn in tabButtons do
	btn.MouseButton1Click:Connect(function()
		setTab(name)
	end)
	btn.MouseEnter:Connect(function()
		if activeTab ~= name then
			btn.BackgroundTransparency = 0
			btn.BackgroundColor3 = Color3.fromRGB(16, 20, 32)
		end
	end)
	btn.MouseLeave:Connect(function()
		if activeTab ~= name then
			btn.BackgroundTransparency = 1
		end
	end)
end

local function refreshCreditsLabel()
	creditsBadge.Text = string.format("₵ %d", credits)
end

--------------------------------------------------------------------------
-- PLAY PAGE — hero + wide rules + bottom CTA bar
--------------------------------------------------------------------------
local playHero = Instance.new("Frame")
playHero.Name = "Hero"
playHero.Size = UDim2.new(1, 0, 0, 120)
playHero.BackgroundTransparency = 1
playHero.Parent = playPage

local oitcBadge = Instance.new("Frame")
oitcBadge.Size = UDim2.fromOffset(110, 24)
oitcBadge.BackgroundColor3 = Theme.OITC
oitcBadge.BorderSizePixel = 0
oitcBadge.Parent = playHero
corner(oitcBadge, 6)
local oitcBadgeGrad = Instance.new("UIGradient")
oitcBadgeGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 80)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 40)),
})
oitcBadgeGrad.Parent = oitcBadge
local oitcBadgeText = Instance.new("TextLabel")
oitcBadgeText.BackgroundTransparency = 1
oitcBadgeText.Size = UDim2.fromScale(1, 1)
oitcBadgeText.Font = Theme.FontTitle
oitcBadgeText.TextSize = 11
oitcBadgeText.TextColor3 = Color3.fromRGB(255, 255, 255)
oitcBadgeText.Text = "OITC ONLY"
oitcBadgeText.Parent = oitcBadge

local heroTitle = Instance.new("TextLabel")
heroTitle.BackgroundTransparency = 1
heroTitle.Position = UDim2.fromOffset(0, 36)
heroTitle.Size = UDim2.new(1, 0, 0, 48)
heroTitle.Font = Theme.FontTitle
heroTitle.TextSize = 42
heroTitle.TextXAlignment = Enum.TextXAlignment.Left
heroTitle.TextColor3 = Theme.Text
heroTitle.Text = Config.Hub.Title
heroTitle.Parent = playHero

local heroSub = Instance.new("TextLabel")
heroSub.BackgroundTransparency = 1
heroSub.Position = UDim2.fromOffset(0, 88)
heroSub.Size = UDim2.new(1, 0, 0, 22)
heroSub.Font = Theme.FontBody
heroSub.TextSize = 15
heroSub.TextXAlignment = Enum.TextXAlignment.Left
heroSub.TextColor3 = Theme.TextMuted
heroSub.Text = Config.Hub.Subtitle
heroSub.Parent = playHero

-- Wide rules panel
local rulesPanel = Instance.new("Frame")
rulesPanel.Name = "Rules"
rulesPanel.Position = UDim2.fromOffset(0, 140)
rulesPanel.Size = UDim2.new(1, 0, 0, 220)
rulesPanel.BackgroundColor3 = Theme.Panel
rulesPanel.BorderSizePixel = 0
rulesPanel.Parent = playPage
corner(rulesPanel, Theme.Radius)
stroke(rulesPanel, Theme.Stroke, 1, 0.25)

local rulesGrad = Instance.new("UIGradient")
rulesGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 24, 38)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 16, 26)),
})
rulesGrad.Rotation = 110
rulesGrad.Parent = rulesPanel

local rulesAccent = Instance.new("Frame")
rulesAccent.Size = UDim2.new(0, 4, 1, 0)
rulesAccent.BackgroundColor3 = Theme.OITC
rulesAccent.BorderSizePixel = 0
rulesAccent.Parent = rulesPanel
corner(rulesAccent, 2)

local rulesPad = Instance.new("UIPadding")
rulesPad.PaddingTop = UDim.new(0, 24)
rulesPad.PaddingBottom = UDim.new(0, 24)
rulesPad.PaddingLeft = UDim.new(0, 28)
rulesPad.PaddingRight = UDim.new(0, 28)
rulesPad.Parent = rulesPanel

local rulesHeading = Instance.new("TextLabel")
rulesHeading.BackgroundTransparency = 1
rulesHeading.Size = UDim2.new(1, 0, 0, 20)
rulesHeading.Font = Theme.FontTitle
rulesHeading.TextSize = 13
rulesHeading.TextXAlignment = Enum.TextXAlignment.Left
rulesHeading.TextColor3 = Theme.OITC
rulesHeading.Text = "MATCH RULES"
rulesHeading.Parent = rulesPanel

local rulesBody = Instance.new("TextLabel")
rulesBody.BackgroundTransparency = 1
rulesBody.Position = UDim2.fromOffset(0, 28)
rulesBody.Size = UDim2.new(1, 0, 1, -28)
rulesBody.Font = Theme.FontBody
rulesBody.TextSize = 15
rulesBody.TextWrapped = true
rulesBody.TextXAlignment = Enum.TextXAlignment.Left
rulesBody.TextYAlignment = Enum.TextYAlignment.Top
rulesBody.TextColor3 = Theme.TextMuted
rulesBody.Text = string.format(
	"%s\n\n• Pistol only  ·  1 bullet in the chamber\n• Kill (gun or knife) = +1 bullet  ·  +%d Credits\n• Empty ammo = Knife melee\n• First to %d kills wins  ·  +%d Credits\n• Death respawns with 1 bullet",
	Config.Hub.ModeOITCBlurb or "One bullet. One pistol. Knife when empty.",
	Config.Economy.CreditsPerKill,
	Config.OITC.KillsToWin,
	Config.Economy.CreditsPerWin
)
rulesBody.Parent = rulesPanel

-- Expandable how-to
local howTo = Instance.new("TextLabel")
howTo.BackgroundTransparency = 1
howTo.Position = UDim2.fromOffset(0, 376)
howTo.Size = UDim2.new(1, 0, 0, 48)
howTo.Font = Theme.FontBody
howTo.TextSize = 13
howTo.TextWrapped = true
howTo.TextXAlignment = Enum.TextXAlignment.Left
howTo.TextYAlignment = Enum.TextYAlignment.Top
howTo.TextColor3 = Theme.TextDim
howTo.Text = Config.Hub.HowToOITC or Config.Hub.HowTo
howTo.Visible = false
howTo.Parent = playPage

-- Bottom action bar spanning content
local playBar = Instance.new("Frame")
playBar.Name = "ActionBar"
playBar.AnchorPoint = Vector2.new(0, 1)
playBar.Position = UDim2.new(0, 0, 1, 0)
playBar.Size = UDim2.new(1, 0, 0, 72)
playBar.BackgroundColor3 = Theme.Panel
playBar.BorderSizePixel = 0
playBar.Parent = playPage
corner(playBar, Theme.Radius)
stroke(playBar, Theme.Stroke, 1, 0.3)

local barPad = Instance.new("UIPadding")
barPad.PaddingLeft = UDim.new(0, 20)
barPad.PaddingRight = UDim.new(0, 20)
barPad.Parent = playBar

local howBtn = Instance.new("TextButton")
howBtn.Size = UDim2.fromOffset(140, 48)
howBtn.Position = UDim2.new(0, 0, 0.5, -24)
howBtn.BackgroundColor3 = Theme.PanelAlt
howBtn.BorderSizePixel = 0
howBtn.Font = Theme.FontTitle
howBtn.TextSize = 13
howBtn.TextColor3 = Theme.TextMuted
howBtn.Text = "HOW TO PLAY"
howBtn.AutoButtonColor = false
howBtn.Parent = playBar
corner(howBtn, Theme.RadiusSm)
stroke(howBtn, Theme.Stroke, 1, 0.3)

local startBtn = Instance.new("TextButton")
startBtn.AnchorPoint = Vector2.new(1, 0.5)
startBtn.Position = UDim2.new(1, 0, 0.5, 0)
startBtn.Size = UDim2.fromOffset(280, 52)
startBtn.BackgroundColor3 = Theme.Success
startBtn.BorderSizePixel = 0
startBtn.Font = Theme.FontTitle
startBtn.TextSize = 20
startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
startBtn.Text = "START MATCH"
startBtn.AutoButtonColor = false
startBtn.Parent = playBar
corner(startBtn, Theme.RadiusSm)
stroke(startBtn, Color3.fromRGB(100, 220, 150), 1, 0.35)

local startGrad = Instance.new("UIGradient")
startGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 200, 135)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 150, 100)),
})
startGrad.Rotation = 90
startGrad.Parent = startBtn

howBtn.MouseButton1Click:Connect(function()
	howToExpanded = not howToExpanded
	howTo.Visible = howToExpanded
	howBtn.Text = if howToExpanded then "HIDE TIPS" else "HOW TO PLAY"
end)

startBtn.MouseEnter:Connect(function()
	if startBtn.Active then
		startBtn.BackgroundColor3 = Theme.SuccessHover
	end
end)
startBtn.MouseLeave:Connect(function()
	if startBtn.Active then
		startBtn.BackgroundColor3 = Theme.Success
	end
end)

--------------------------------------------------------------------------
-- SHOP + INVENTORY — grid of item cards filling main area
--------------------------------------------------------------------------
local function makePageHeader(parent: Frame, titleText: string, subText: string): Frame
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 64)
	header.BackgroundTransparency = 1
	header.Parent = parent

	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, 32)
	t.Font = Theme.FontTitle
	t.TextSize = 28
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = Theme.Text
	t.Text = titleText
	t.Parent = header

	local s = Instance.new("TextLabel")
	s.BackgroundTransparency = 1
	s.Position = UDim2.fromOffset(0, 36)
	s.Size = UDim2.new(1, 0, 0, 20)
	s.Font = Theme.FontBody
	s.TextSize = 14
	s.TextXAlignment = Enum.TextXAlignment.Left
	s.TextColor3 = Theme.TextMuted
	s.Text = subText
	s.Parent = header
	return header
end

makePageHeader(shopPage, "SHOP", "Spend Credits from kills & wins on cosmetics")
makePageHeader(invPage, "INVENTORY", "Equip owned skins for your next match")

local shopScroll = Instance.new("ScrollingFrame")
shopScroll.Name = "ShopScroll"
shopScroll.Position = UDim2.fromOffset(0, 76)
shopScroll.Size = UDim2.new(1, 0, 1, -76)
shopScroll.BackgroundTransparency = 1
shopScroll.BorderSizePixel = 0
shopScroll.ScrollBarThickness = 5
shopScroll.ScrollBarImageColor3 = Theme.StrokeBright
shopScroll.CanvasSize = UDim2.fromOffset(0, 0)
shopScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopScroll.Parent = shopPage

local shopList = Instance.new("UIListLayout")
shopList.Padding = UDim.new(0, 20)
shopList.SortOrder = Enum.SortOrder.LayoutOrder
shopList.Parent = shopScroll

local invScroll = Instance.new("ScrollingFrame")
invScroll.Name = "InvScroll"
invScroll.Position = UDim2.fromOffset(0, 76)
invScroll.Size = UDim2.new(1, 0, 1, -76)
invScroll.BackgroundTransparency = 1
invScroll.BorderSizePixel = 0
invScroll.ScrollBarThickness = 5
invScroll.ScrollBarImageColor3 = Theme.StrokeBright
invScroll.CanvasSize = UDim2.fromOffset(0, 0)
invScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
invScroll.Parent = invPage

local invList = Instance.new("UIListLayout")
invList.Padding = UDim.new(0, 20)
invList.SortOrder = Enum.SortOrder.LayoutOrder
invList.Parent = invScroll

-- Status toast along bottom of main
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.AnchorPoint = Vector2.new(0.5, 1)
statusLabel.Position = UDim2.new(0.5, 0, 1, -8)
statusLabel.Size = UDim2.new(1, -16, 0, 22)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Theme.FontBody
statusLabel.TextSize = 13
statusLabel.TextColor3 = Theme.Warning
statusLabel.Text = ""
statusLabel.ZIndex = 10
statusLabel.Parent = main

local function setStatus(msg: string, ok: boolean?)
	statusMsg = msg
	statusLabel.Text = msg
	statusLabel.TextColor3 = if ok == false then Theme.Danger elseif ok == true then Theme.Success else Theme.Warning
	if msg ~= "" then
		task.delay(2.5, function()
			if statusLabel.Text == msg then
				statusLabel.Text = ""
			end
		end)
	end
end

local CATEGORY_ORDER = { "PistolSkin", "KnifeSkin", "Trail", "Hitmarker", "Title" }
local CATEGORY_LABELS = {
	PistolSkin = "PISTOL SKINS",
	KnifeSkin = "KNIFE SKINS",
	Trail = "TRAILS",
	Hitmarker = "HITMARKERS",
	Title = "TITLES",
}

local CARD_H = Theme.CardHeight or 168
local GRID_GAP = Theme.GridGap or 14

local function makeItemCard(parent: Instance, item: any, mode: string, order: number)
	local owned = ownedSet[item.Id] == true or item.Owned == true
	local isEq = equipped[item.Category] == item.Id or item.Equipped == true

	local card = Instance.new("Frame")
	card.Name = item.Id
	card.Size = UDim2.new(0, 210, 0, CARD_H)
	card.BackgroundColor3 = if isEq then Theme.CardSelected else Theme.Card
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.Active = true
	card.Parent = parent
	corner(card, Theme.RadiusSm)
	stroke(card, if isEq then Theme.Equipped else Theme.Stroke, 1, if isEq then 0.05 else 0.3)

	-- Color preview block
	local swatchColor = item.HandleColor or item.TrailColor or item.HitColor or item.TitleColor or Theme.Accent
	local preview = Instance.new("Frame")
	preview.Size = UDim2.new(1, -20, 0, 56)
	preview.Position = UDim2.fromOffset(10, 10)
	preview.BackgroundColor3 = swatchColor
	preview.BorderSizePixel = 0
	preview.Parent = card
	corner(preview, Theme.RadiusXs)
	local tipCol = item.TipColor or item.HitHeadColor or Theme.AccentGlow
	local tipBar = Instance.new("Frame")
	tipBar.AnchorPoint = Vector2.new(0, 1)
	tipBar.Position = UDim2.new(0, 0, 1, 0)
	tipBar.Size = UDim2.new(1, 0, 0, 6)
	tipBar.BackgroundColor3 = tipCol
	tipBar.BorderSizePixel = 0
	tipBar.Parent = preview

	local nameL = Instance.new("TextLabel")
	nameL.BackgroundTransparency = 1
	nameL.Position = UDim2.fromOffset(12, 74)
	nameL.Size = UDim2.new(1, -24, 0, 20)
	nameL.Font = Theme.FontTitle
	nameL.TextSize = 14
	nameL.TextXAlignment = Enum.TextXAlignment.Left
	nameL.TextTruncate = Enum.TextTruncate.AtEnd
	nameL.TextColor3 = Theme.Text
	nameL.Text = item.Name or item.Id
	nameL.Parent = card

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(12, 94)
	desc.Size = UDim2.new(1, -24, 0, 28)
	desc.Font = Theme.FontBody
	desc.TextSize = 11
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextColor3 = Theme.TextDim
	desc.Text = item.Description or item.Category or ""
	desc.Parent = card

	local action = Instance.new("TextButton")
	action.Position = UDim2.fromOffset(10, CARD_H - 42)
	action.Size = UDim2.new(1, -20, 0, 32)
	action.BorderSizePixel = 0
	action.Font = Theme.FontTitle
	action.TextSize = 12
	action.AutoButtonColor = false
	action.Parent = card
	corner(action, Theme.RadiusXs)

	if mode == "shop" then
		if owned then
			if isEq then
				action.Text = "EQUIPPED"
				action.BackgroundColor3 = Theme.Equipped
				action.TextColor3 = Color3.fromRGB(255, 255, 255)
				action.Active = false
			else
				action.Text = "EQUIP"
				action.BackgroundColor3 = Theme.Accent
				action.TextColor3 = Color3.fromRGB(255, 255, 255)
				action.MouseButton1Click:Connect(function()
					equipRemote:FireServer(item.Id)
				end)
			end
		else
			action.Text = string.format("₵ %d", item.Price or 0)
			action.BackgroundColor3 = Theme.Warning
			action.TextColor3 = Color3.fromRGB(30, 24, 10)
			action.MouseButton1Click:Connect(function()
				purchaseRemote:FireServer(item.Id)
			end)
		end
	else
		if isEq then
			action.Text = "EQUIPPED"
			action.BackgroundColor3 = Theme.Equipped
			action.TextColor3 = Color3.fromRGB(255, 255, 255)
			action.Active = false
		else
			action.Text = "EQUIP"
			action.BackgroundColor3 = Theme.Success
			action.TextColor3 = Color3.fromRGB(255, 255, 255)
			action.MouseButton1Click:Connect(function()
				equipRemote:FireServer(item.Id)
			end)
		end
	end

	-- Hover lift
	card.MouseEnter:Connect(function()
		if not isEq then
			card.BackgroundColor3 = Theme.CardHover
		end
	end)
	card.MouseLeave:Connect(function()
		if not isEq then
			card.BackgroundColor3 = Theme.Card
		end
	end)
end

local function makeCategorySection(parent: Instance, cat: string, items: { any }, mode: string, order: number): number
	if #items == 0 then
		return order
	end

	local section = Instance.new("Frame")
	section.Name = cat
	section.Size = UDim2.new(1, 0, 0, 0)
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.BackgroundTransparency = 1
	section.LayoutOrder = order
	section.Parent = parent
	order += 1

	local catLabel = Instance.new("TextLabel")
	catLabel.Size = UDim2.new(1, 0, 0, 22)
	catLabel.BackgroundTransparency = 1
	catLabel.Font = Theme.FontTitle
	catLabel.TextSize = 12
	catLabel.TextXAlignment = Enum.TextXAlignment.Left
	catLabel.TextColor3 = Theme.TextDim
	catLabel.Text = CATEGORY_LABELS[cat] or cat
	catLabel.Parent = section

	local gridWrap = Instance.new("Frame")
	gridWrap.Name = "Grid"
	gridWrap.Position = UDim2.fromOffset(0, 28)
	gridWrap.Size = UDim2.new(1, 0, 0, 0)
	gridWrap.AutomaticSize = Enum.AutomaticSize.Y
	gridWrap.BackgroundTransparency = 1
	gridWrap.Parent = section

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(210, CARD_H)
	grid.CellPadding = UDim2.fromOffset(GRID_GAP, GRID_GAP)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.FillDirectionMaxCells = 0 -- fill available width
	grid.Parent = gridWrap

	for i, item in items do
		makeItemCard(gridWrap, item, mode, i)
	end

	return order
end

local function rebuildShop()
	clearChildren(shopScroll)
	-- re-add layout
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 20)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = shopScroll

	local order = 0
	for _, cat in CATEGORY_ORDER do
		local list = {}
		for _, item in shopItems do
			if item.Category == cat then
				table.insert(list, item)
			end
		end
		order = makeCategorySection(shopScroll, cat, list, "shop", order)
	end
end

local function rebuildInventory()
	clearChildren(invScroll)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 20)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = invScroll

	local order = 0
	local any = false
	for _, cat in CATEGORY_ORDER do
		local ownedInCat = {}
		for _, item in shopItems do
			if item.Category == cat and (ownedSet[item.Id] or item.Owned) then
				table.insert(ownedInCat, item)
			end
		end
		if #ownedInCat > 0 then
			any = true
			order = makeCategorySection(invScroll, cat, ownedInCat, "inv", order)
		end
	end
	if not any then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 48)
		empty.BackgroundTransparency = 1
		empty.Font = Theme.FontBody
		empty.TextSize = 15
		empty.TextColor3 = Theme.TextMuted
		empty.Text = "No items yet — visit the Shop."
		empty.LayoutOrder = order
		empty.Parent = invScroll
	end
end

local function applyShopPayload(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	if typeof(payload.Credits) == "number" then
		credits = payload.Credits
		refreshCreditsLabel()
	end
	if typeof(payload.Equipped) == "table" then
		for k, v in payload.Equipped do
			if typeof(v) == "string" then
				equipped[k] = v
			end
		end
	end
	ownedSet = {}
	if typeof(payload.Items) == "table" then
		shopItems = payload.Items
		for _, item in shopItems do
			if item.Owned then
				ownedSet[item.Id] = true
			end
		end
	end
	rebuildShop()
	rebuildInventory()
end

--------------------------------------------------------------------------
-- SETTINGS — full-width panel (not a tiny centered card)
--------------------------------------------------------------------------
local setHeader = makePageHeader(setPage, "SETTINGS", "Audio, sensitivity, and graphics")

local setPanel = Instance.new("Frame")
setPanel.Position = UDim2.fromOffset(0, 76)
setPanel.Size = UDim2.new(1, 0, 0, 220)
setPanel.BackgroundColor3 = Theme.Panel
setPanel.BorderSizePixel = 0
setPanel.Parent = setPage
corner(setPanel, Theme.Radius)
stroke(setPanel, Theme.Stroke, 1, 0.25)

local setPad = Instance.new("UIPadding")
setPad.PaddingTop = UDim.new(0, 28)
setPad.PaddingLeft = UDim.new(0, 28)
setPad.PaddingRight = UDim.new(0, 28)
setPad.Parent = setPanel

local setBody = Instance.new("TextLabel")
setBody.BackgroundTransparency = 1
setBody.Size = UDim2.new(1, 0, 1, -28)
setBody.Font = Theme.FontBody
setBody.TextSize = 15
setBody.TextWrapped = true
setBody.TextXAlignment = Enum.TextXAlignment.Left
setBody.TextYAlignment = Enum.TextYAlignment.Top
setBody.TextColor3 = Theme.TextMuted
setBody.Text =
	"Audio mix, sensitivity, and graphics toggles will land here.\n\nFor now: use Roblox Esc menu for volume / graphics.\nSkins & titles are under Shop / Inventory.\nCredits persist via DataStore (memory fallback in Studio)."
setBody.Parent = setPanel

--------------------------------------------------------------------------
-- Countdown + Winner overlays
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
cdDim.BackgroundTransparency = 0.35
cdDim.BorderSizePixel = 0
cdDim.Active = true
cdDim.Parent = countdownGui

local cdLabel = Instance.new("TextLabel")
cdLabel.Name = "Count"
cdLabel.AnchorPoint = Vector2.new(0.5, 0.5)
cdLabel.Position = UDim2.fromScale(0.5, 0.48)
cdLabel.Size = UDim2.fromOffset(600, 180)
cdLabel.BackgroundTransparency = 1
cdLabel.Font = Theme.FontTitle
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
cdSub.Font = Theme.FontBody
cdSub.TextSize = 16
cdSub.TextColor3 = Theme.TextMuted
cdSub.Text = "GET READY"
cdSub.Parent = countdownGui

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
winnerDim.BackgroundTransparency = 0.2
winnerDim.BorderSizePixel = 0
winnerDim.Active = true
winnerDim.Parent = winnerGui

local winnerCard = Instance.new("Frame")
winnerCard.AnchorPoint = Vector2.new(0.5, 0.5)
winnerCard.Position = UDim2.fromScale(0.5, 0.5)
winnerCard.Size = UDim2.fromOffset(520, 300)
winnerCard.BackgroundColor3 = Theme.Panel
winnerCard.BorderSizePixel = 0
winnerCard.Parent = winnerGui
corner(winnerCard)
stroke(winnerCard)
do
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 28)
	p.PaddingBottom = UDim.new(0, 24)
	p.PaddingLeft = UDim.new(0, 28)
	p.PaddingRight = UDim.new(0, 28)
	p.Parent = winnerCard
end

local winnerTitle = Instance.new("TextLabel")
winnerTitle.BackgroundTransparency = 1
winnerTitle.Size = UDim2.new(1, 0, 0, 22)
winnerTitle.Font = Theme.FontTitle
winnerTitle.TextSize = 12
winnerTitle.TextXAlignment = Enum.TextXAlignment.Left
winnerTitle.TextColor3 = Theme.TextDim
winnerTitle.Text = "ONE IN THE CHAMBER"
winnerTitle.Parent = winnerCard

local winnerHeadline = Instance.new("TextLabel")
winnerHeadline.BackgroundTransparency = 1
winnerHeadline.Position = UDim2.fromOffset(0, 28)
winnerHeadline.Size = UDim2.new(1, 0, 0, 40)
winnerHeadline.Font = Theme.FontTitle
winnerHeadline.TextSize = 32
winnerHeadline.TextXAlignment = Enum.TextXAlignment.Left
winnerHeadline.TextColor3 = Theme.Warning
winnerHeadline.Text = "YOU WIN"
winnerHeadline.Parent = winnerCard

local winnerBody = Instance.new("TextLabel")
winnerBody.BackgroundTransparency = 1
winnerBody.Position = UDim2.fromOffset(0, 78)
winnerBody.Size = UDim2.new(1, 0, 0, 56)
winnerBody.Font = Theme.FontBody
winnerBody.TextSize = 15
winnerBody.TextWrapped = true
winnerBody.TextXAlignment = Enum.TextXAlignment.Left
winnerBody.TextYAlignment = Enum.TextYAlignment.Top
winnerBody.TextColor3 = Theme.TextMuted
winnerBody.Text = ""
winnerBody.Parent = winnerCard

local endFooter = Instance.new("Frame")
endFooter.BackgroundTransparency = 1
endFooter.AnchorPoint = Vector2.new(0.5, 1)
endFooter.Position = UDim2.new(0.5, 0, 1, 0)
endFooter.Size = UDim2.new(1, 0, 0, 48)
endFooter.Parent = winnerCard

local playAgainBtn = Instance.new("TextButton")
playAgainBtn.Size = UDim2.fromOffset(190, 46)
playAgainBtn.BackgroundColor3 = Theme.Success
playAgainBtn.BorderSizePixel = 0
playAgainBtn.Font = Theme.FontTitle
playAgainBtn.TextSize = 14
playAgainBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
playAgainBtn.Text = "PLAY AGAIN"
playAgainBtn.AutoButtonColor = false
playAgainBtn.Parent = endFooter
corner(playAgainBtn, Theme.RadiusSm)

local hubAgainBtn = Instance.new("TextButton")
hubAgainBtn.AnchorPoint = Vector2.new(1, 0)
hubAgainBtn.Position = UDim2.new(1, 0, 0, 0)
hubAgainBtn.Size = UDim2.fromOffset(190, 46)
hubAgainBtn.BackgroundColor3 = Theme.Accent
hubAgainBtn.BorderSizePixel = 0
hubAgainBtn.Font = Theme.FontTitle
hubAgainBtn.TextSize = 14
hubAgainBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hubAgainBtn.Text = "HUB"
hubAgainBtn.AutoButtonColor = false
hubAgainBtn.Parent = endFooter
corner(hubAgainBtn, Theme.RadiusSm)

--------------------------------------------------------------------------
-- Camera: Scriptable fixed on dark void while hub open
--------------------------------------------------------------------------
local matchLoopSound: Sound? = nil

local function playLocalSound(soundId: string?, volume: number?, playbackSpeed: number?)
	if typeof(soundId) ~= "string" or soundId == "" or soundId == "rbxassetid://0" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume or 0.5
	s.PlaybackSpeed = playbackSpeed or 1
	s.Parent = playerGui
	s:Play()
	Debris:AddItem(s, 5)
end

local function stopMatchLoop()
	if matchLoopSound then
		matchLoopSound:Stop()
		matchLoopSound:Destroy()
		matchLoopSound = nil
	end
end

local function startMatchLoop()
	stopMatchLoop()
	local id = (Config.Match and Config.Match.MatchLoopSoundId)
		or (Config.SoundIds and Config.SoundIds.MatchLoop)
	if typeof(id) ~= "string" or id == "" then
		return
	end
	local vol = (Config.Match and Config.Match.MatchLoopVolume)
		or (Config.SoundVolumes and Config.SoundVolumes.MatchLoop)
		or 0.18
	local s = Instance.new("Sound")
	s.Name = "CQCMatchLoop"
	s.SoundId = id
	s.Volume = vol
	s.Looped = true
	s.Parent = playerGui
	s:Play()
	matchLoopSound = s
end

local function playWinSting()
	local id = (Config.Match and Config.Match.WinStingSoundId)
		or (Config.SoundIds and Config.SoundIds.WinSting)
	local vol = (Config.Match and Config.Match.WinStingVolume)
		or (Config.SoundVolumes and Config.SoundVolumes.WinSting)
		or 0.6
	playLocalSound(id, vol, 1)
end

local function unlockMouse()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

local HUB_CAM_CF = CFrame.new(0, 5000, 0) -- far above map, dark void

local function stopHubCamera()
	if hubCamConn then
		hubCamConn:Disconnect()
		hubCamConn = nil
	end
end

local function startHubCamera()
	stopHubCamera()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = HUB_CAM_CF
	cam.FieldOfView = 70
	hubCamConn = RunService.RenderStepped:Connect(function()
		local c = Workspace.CurrentCamera
		if c and gui.Enabled then
			c.CameraType = Enum.CameraType.Scriptable
			c.CFrame = HUB_CAM_CF
		end
	end)
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
		startHubCamera()
	else
		stopHubCamera()
		local cam = Workspace.CurrentCamera
		if cam then
			cam.CameraType = Enum.CameraType.Custom
		end
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
	stopHubCamera()
end

local function showHub()
	stopMatchLoop()
	started = false
	startBtn.Text = "START MATCH"
	startBtn.Active = true
	startBtn.BackgroundColor3 = Theme.Success
	winnerGui.Enabled = false
	countdownGui.Enabled = false
	gui.Enabled = true
	applyHubCamera(true)
	setTab("Play")
	getShopRemote:FireServer()
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

startBtn.MouseButton1Click:Connect(function()
	if started then
		return
	end
	requestStart()
end)

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
	stopMatchLoop()

	task.spawn(function()
		for i = seconds, 1, -1 do
			if countdownGen ~= gen then
				return
			end
			cdLabel.Text = tostring(i)
			cdLabel.TextColor3 = Theme.Text
			cdLabel.TextSize = 120
			-- Punchy 3-2-1: distinct IDs when set, else CountdownTick with rising pitch
			local key = "Countdown" .. tostring(i)
			local ids = Config.SoundIds
			local vols = Config.SoundVolumes
			local sid = ids and (ids[key] or ids.CountdownTick)
			local svol = (vols and (vols[key] or vols.CountdownTick)) or 0.4
			-- Higher pitch as we approach GO (3→1)
			local speed = 0.85 + (seconds - i) * 0.18
			playLocalSound(sid, svol, speed)
			task.wait(1)
		end
		if countdownGen ~= gen then
			return
		end
		cdLabel.Text = "GO!"
		cdLabel.TextColor3 = Theme.Success
		cdLabel.TextSize = 110
		cdSub.Text = "FIGHT"
		local startId = (Config.SoundIds and Config.SoundIds.CountdownGo)
			or (Config.Match and Config.Match.RoundStartSoundId)
			or (Config.SoundIds and Config.SoundIds.RoundStart)
		local startVol = (Config.SoundVolumes and Config.SoundVolumes.CountdownGo)
			or (Config.Match and Config.Match.RoundStartSoundVolume)
			or (Config.SoundVolumes and Config.SoundVolumes.RoundStart)
			or 0.65
		playLocalSound(startId, startVol, 1.05)
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
	startMatchLoop()
end)

matchEndedRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	countdownGen += 1
	countdownGui.Enabled = false
	stopMatchLoop()
	playWinSting()

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
	scoreLine ..= string.format("\nCredits  ₵ %d", credits)
	winnerBody.Text = scoreLine

	winnerGui.Enabled = true
	unlockMouse()
	stopHubCamera()
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
	end
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
	stopMatchLoop()
	showHub()
end)

getShopRemote.OnClientEvent:Connect(applyShopPayload)
dataSyncRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if typeof(payload.Credits) == "number" then
		credits = payload.Credits
		refreshCreditsLabel()
	end
	if typeof(payload.OwnedItems) == "table" then
		ownedSet = {}
		for _, id in payload.OwnedItems do
			if typeof(id) == "string" then
				ownedSet[id] = true
			end
		end
	end
	if typeof(payload.Equipped) == "table" then
		for k, v in payload.Equipped do
			if typeof(v) == "string" then
				equipped[k] = v
			end
		end
	end
	if #shopItems > 0 then
		for _, item in shopItems do
			item.Owned = ownedSet[item.Id] == true
			item.Equipped = equipped[item.Category] == item.Id
		end
		rebuildShop()
		rebuildInventory()
	end
end)

creditsRemote.OnClientEvent:Connect(function(amount)
	if typeof(amount) == "number" then
		credits = amount
		refreshCreditsLabel()
	end
end)

shopResultRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	setStatus(tostring(payload.message or ""), payload.ok == true)
	if typeof(payload.shop) == "table" then
		applyShopPayload(payload.shop)
	end
end)

player:GetAttributeChangedSignal("CQCCredits"):Connect(function()
	local c = player:GetAttribute("CQCCredits")
	if typeof(c) == "number" then
		credits = c
		refreshCreditsLabel()
	end
end)

setTab("Play")
refreshCreditsLabel()
getShopRemote:FireServer()

if player:GetAttribute("CQCInMatch") == true then
	started = true
	hideHub()
	applyHubCamera(false)
end
