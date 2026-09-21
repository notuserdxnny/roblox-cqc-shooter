--!strict
--[[
	Full-screen professional hub: Play | Shop | Inventory | Settings.
	IgnoreGuiInset, Scale(1,1) dark overlay. Match countdown + end overlay.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

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

--------------------------------------------------------------------------
-- Root full-screen GUI
--------------------------------------------------------------------------
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
dim.BackgroundColor3 = Theme.Overlay
dim.BackgroundTransparency = 0.08
dim.BorderSizePixel = 0
dim.Active = true -- block world clicks
dim.Parent = gui

local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 12, 22)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(6, 8, 14)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 10, 18)),
})
grad.Rotation = 110
grad.Parent = dim

-- Main shell
local shell = Instance.new("Frame")
shell.Name = "Shell"
shell.Size = UDim2.fromScale(1, 1)
shell.BackgroundTransparency = 1
shell.Parent = gui

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 16)
pad.PaddingBottom = UDim.new(0, 16)
pad.PaddingLeft = UDim.new(0, 24)
pad.PaddingRight = UDim.new(0, 24)
pad.Parent = shell

-- Top nav
local nav = Instance.new("Frame")
nav.Name = "Nav"
nav.Size = UDim2.new(1, 0, 0, Theme.NavHeight)
nav.BackgroundColor3 = Theme.Panel
nav.BorderSizePixel = 0
nav.Parent = shell
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, Theme.Radius)
	c.Parent = nav
	local s = Instance.new("UIStroke")
	s.Color = Theme.Stroke
	s.Thickness = 1
	s.Transparency = 0.2
	s.Parent = nav
	local np = Instance.new("UIPadding")
	np.PaddingLeft = UDim.new(0, 16)
	np.PaddingRight = UDim.new(0, 16)
	np.Parent = nav
end

local brand = Instance.new("TextLabel")
brand.BackgroundTransparency = 1
brand.Size = UDim2.fromOffset(220, Theme.NavHeight)
brand.Font = Theme.FontTitle
brand.TextSize = 16
brand.TextXAlignment = Enum.TextXAlignment.Left
brand.TextColor3 = Theme.Text
brand.Text = "OITC  ·  CQC"
brand.Parent = nav

local creditsBadge = Instance.new("TextLabel")
creditsBadge.Name = "Credits"
creditsBadge.AnchorPoint = Vector2.new(1, 0.5)
creditsBadge.Position = UDim2.new(1, 0, 0.5, 0)
creditsBadge.Size = UDim2.fromOffset(150, 32)
creditsBadge.BackgroundColor3 = Theme.PanelAlt
creditsBadge.BorderSizePixel = 0
creditsBadge.Font = Theme.FontTitle
creditsBadge.TextSize = 14
creditsBadge.TextColor3 = Theme.Credits
creditsBadge.Text = "₵ 100"
creditsBadge.Parent = nav
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, Theme.RadiusXs)
	c.Parent = creditsBadge
end

local tabBar = Instance.new("Frame")
tabBar.Name = "Tabs"
tabBar.AnchorPoint = Vector2.new(0.5, 0.5)
tabBar.Position = UDim2.new(0.5, 0, 0.5, 0)
tabBar.Size = UDim2.fromOffset(420, 40)
tabBar.BackgroundTransparency = 1
tabBar.Parent = nav
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.Padding = UDim.new(0, 8)
tabLayout.Parent = tabBar

local content = Instance.new("Frame")
content.Name = "Content"
content.Position = UDim2.fromOffset(0, Theme.NavHeight + 14)
content.Size = UDim2.new(1, 0, 1, -(Theme.NavHeight + 14))
content.BackgroundTransparency = 1
content.Parent = shell

local pages: { [string]: Frame } = {}
local tabButtons: { [string]: TextButton } = {}

local function corner(parent: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or Theme.Radius)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, color: Color3?, thick: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Stroke
	s.Thickness = thick or 1
	s.Transparency = 0.15
	s.Parent = parent
	return s
end

local function makeTab(name: string)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.fromOffset(96, 36)
	btn.BackgroundColor3 = Theme.PanelAlt
	btn.BorderSizePixel = 0
	btn.Font = Theme.FontTitle
	btn.TextSize = 13
	btn.TextColor3 = Theme.TextMuted
	btn.Text = string.upper(name)
	btn.AutoButtonColor = false
	btn.Parent = tabBar
	corner(btn, Theme.RadiusXs)
	tabButtons[name] = btn

	local page = Instance.new("Frame")
	page.Name = name .. "Page"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = content
	pages[name] = page
	return btn, page
end

local playBtn, playPage = makeTab("Play")
local shopBtn, shopPage = makeTab("Shop")
local invBtn, invPage = makeTab("Inventory")
local setBtn, setPage = makeTab("Settings")

local function setTab(name: string)
	activeTab = name
	for n, page in pages do
		page.Visible = n == name
	end
	for n, btn in tabButtons do
		if n == name then
			btn.BackgroundColor3 = Theme.Accent
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundColor3 = Theme.PanelAlt
			btn.TextColor3 = Theme.TextMuted
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
			btn.BackgroundColor3 = Theme.CardHover
		end
	end)
	btn.MouseLeave:Connect(function()
		if activeTab ~= name then
			btn.BackgroundColor3 = Theme.PanelAlt
		end
	end)
end

local function refreshCreditsLabel()
	creditsBadge.Text = string.format("₵ %d", credits)
end

--------------------------------------------------------------------------
-- PLAY PAGE
--------------------------------------------------------------------------
local playCard = Instance.new("Frame")
playCard.AnchorPoint = Vector2.new(0.5, 0.5)
playCard.Position = UDim2.fromScale(0.5, 0.5)
playCard.Size = UDim2.new(0, 640, 0, 480)
playCard.BackgroundColor3 = Theme.Panel
playCard.BorderSizePixel = 0
playCard.Parent = playPage
corner(playCard)
stroke(playCard)
do
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 28)
	p.PaddingBottom = UDim.new(0, 24)
	p.PaddingLeft = UDim.new(0, 32)
	p.PaddingRight = UDim.new(0, 32)
	p.Parent = playCard
end

local badge = Instance.new("Frame")
badge.Size = UDim2.fromOffset(120, 22)
badge.BackgroundColor3 = Theme.OITC
badge.BorderSizePixel = 0
badge.Parent = playCard
corner(badge, 6)
local badgeText = Instance.new("TextLabel")
badgeText.BackgroundTransparency = 1
badgeText.Size = UDim2.fromScale(1, 1)
badgeText.Font = Theme.FontTitle
badgeText.TextSize = 11
badgeText.TextColor3 = Color3.fromRGB(255, 255, 255)
badgeText.Text = "OITC ONLY"
badgeText.Parent = badge

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(0, 32)
title.Size = UDim2.new(1, 0, 0, 36)
title.Font = Theme.FontTitle
title.TextSize = 30
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Theme.Text
title.Text = Config.Hub.Title
title.Parent = playCard

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(0, 70)
subtitle.Size = UDim2.new(1, 0, 0, 22)
subtitle.Font = Theme.FontBody
subtitle.TextSize = 14
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextColor3 = Theme.TextMuted
subtitle.Text = Config.Hub.Subtitle
subtitle.Parent = playCard

local rulesCard = Instance.new("Frame")
rulesCard.Position = UDim2.fromOffset(0, 108)
rulesCard.Size = UDim2.new(1, 0, 0, 180)
rulesCard.BackgroundColor3 = Theme.PanelAlt
rulesCard.BorderSizePixel = 0
rulesCard.Parent = playCard
corner(rulesCard, Theme.RadiusSm)
stroke(rulesCard)
do
	local accentBar = Instance.new("Frame")
	accentBar.Size = UDim2.new(1, 0, 0, 3)
	accentBar.Position = UDim2.new(0, 0, 1, -3)
	accentBar.BackgroundColor3 = Theme.OITC
	accentBar.BorderSizePixel = 0
	accentBar.Parent = rulesCard
	local rp = Instance.new("UIPadding")
	rp.PaddingTop = UDim.new(0, 16)
	rp.PaddingLeft = UDim.new(0, 16)
	rp.PaddingRight = UDim.new(0, 16)
	rp.Parent = rulesCard
end

local rulesBody = Instance.new("TextLabel")
rulesBody.BackgroundTransparency = 1
rulesBody.Size = UDim2.fromScale(1, 1)
rulesBody.Font = Theme.FontBody
rulesBody.TextSize = 14
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
rulesBody.Parent = rulesCard

local howTo = Instance.new("TextLabel")
howTo.BackgroundTransparency = 1
howTo.Position = UDim2.fromOffset(0, 300)
howTo.Size = UDim2.new(1, 0, 0, 52)
howTo.Font = Theme.FontBody
howTo.TextSize = 12
howTo.TextWrapped = true
howTo.TextXAlignment = Enum.TextXAlignment.Left
howTo.TextYAlignment = Enum.TextYAlignment.Top
howTo.TextColor3 = Theme.TextDim
howTo.Text = Config.Hub.HowToOITC or Config.Hub.HowTo
howTo.Visible = false
howTo.Parent = playCard

local footer = Instance.new("Frame")
footer.BackgroundTransparency = 1
footer.AnchorPoint = Vector2.new(0.5, 1)
footer.Position = UDim2.new(0.5, 0, 1, 0)
footer.Size = UDim2.new(1, 0, 0, 56)
footer.Parent = playCard

local howBtn = Instance.new("TextButton")
howBtn.Size = UDim2.fromOffset(130, 48)
howBtn.Position = UDim2.fromOffset(0, 4)
howBtn.BackgroundColor3 = Theme.PanelAlt
howBtn.BorderSizePixel = 0
howBtn.Font = Theme.FontTitle
howBtn.TextSize = 13
howBtn.TextColor3 = Theme.TextMuted
howBtn.Text = "HOW TO PLAY"
howBtn.AutoButtonColor = false
howBtn.Parent = footer
corner(howBtn, Theme.RadiusSm)
stroke(howBtn)

local startBtn = Instance.new("TextButton")
startBtn.AnchorPoint = Vector2.new(1, 0)
startBtn.Position = UDim2.new(1, 0, 0, 0)
startBtn.Size = UDim2.fromOffset(240, 56)
startBtn.BackgroundColor3 = Theme.Success
startBtn.BorderSizePixel = 0
startBtn.Font = Theme.FontTitle
startBtn.TextSize = 20
startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
startBtn.Text = "START"
startBtn.AutoButtonColor = false
startBtn.Parent = footer
corner(startBtn, Theme.RadiusSm)
stroke(startBtn, Color3.fromRGB(100, 220, 150), 1)

howBtn.MouseButton1Click:Connect(function()
	howToExpanded = not howToExpanded
	howTo.Visible = howToExpanded
	howBtn.Text = if howToExpanded then "HIDE TIPS" else "HOW TO PLAY"
end)

startBtn.MouseEnter:Connect(function()
	if startBtn.Active then
		startBtn.BackgroundColor3 = Color3.fromRGB(70, 200, 135)
	end
end)
startBtn.MouseLeave:Connect(function()
	if startBtn.Active then
		startBtn.BackgroundColor3 = Theme.Success
	end
end)

--------------------------------------------------------------------------
-- SHOP + INVENTORY helpers
--------------------------------------------------------------------------
local shopScroll = Instance.new("ScrollingFrame")
shopScroll.Name = "ShopScroll"
shopScroll.Size = UDim2.fromScale(1, 1)
shopScroll.BackgroundColor3 = Theme.Panel
shopScroll.BorderSizePixel = 0
shopScroll.ScrollBarThickness = 6
shopScroll.CanvasSize = UDim2.fromOffset(0, 0)
shopScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopScroll.Parent = shopPage
corner(shopScroll)
stroke(shopScroll)
do
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 16)
	p.PaddingBottom = UDim.new(0, 16)
	p.PaddingLeft = UDim.new(0, 16)
	p.PaddingRight = UDim.new(0, 16)
	p.Parent = shopScroll
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 10)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = shopScroll
end

local invScroll = Instance.new("ScrollingFrame")
invScroll.Name = "InvScroll"
invScroll.Size = UDim2.fromScale(1, 1)
invScroll.BackgroundColor3 = Theme.Panel
invScroll.BorderSizePixel = 0
invScroll.ScrollBarThickness = 6
invScroll.CanvasSize = UDim2.fromOffset(0, 0)
invScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
invScroll.Parent = invPage
corner(invScroll)
stroke(invScroll)
do
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 16)
	p.PaddingBottom = UDim.new(0, 16)
	p.PaddingLeft = UDim.new(0, 16)
	p.PaddingRight = UDim.new(0, 16)
	p.Parent = invScroll
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 10)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = invScroll
end

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.AnchorPoint = Vector2.new(0.5, 1)
statusLabel.Position = UDim2.new(0.5, 0, 1, -4)
statusLabel.Size = UDim2.new(1, -48, 0, 22)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Theme.FontBody
statusLabel.TextSize = 13
statusLabel.TextColor3 = Theme.Warning
statusLabel.Text = ""
statusLabel.ZIndex = 5
statusLabel.Parent = shell

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

local function colorSwatch(parent: Instance, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(36, 36)
	f.BackgroundColor3 = color or Theme.Card
	f.BorderSizePixel = 0
	f.Parent = parent
	corner(f, 6)
	stroke(f, Theme.StrokeBright)
	return f
end

local function clearChildren(frame: Instance)
	for _, c in frame:GetChildren() do
		if c:IsA("Frame") or c:IsA("TextLabel") or c:IsA("TextButton") then
			c:Destroy()
		end
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

local function makeItemRow(parent: Instance, item: any, mode: string, order: number)
	local owned = ownedSet[item.Id] == true or item.Owned == true
	local isEq = equipped[item.Category] == item.Id or item.Equipped == true

	local row = Instance.new("Frame")
	row.Name = item.Id
	row.Size = UDim2.new(1, 0, 0, 72)
	row.BackgroundColor3 = Theme.Card
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.Parent = parent
	corner(row, Theme.RadiusSm)
	stroke(row, if isEq then Theme.Equipped else Theme.Stroke)

	local swatchColor = item.HandleColor or item.TrailColor or item.HitColor or item.TitleColor or Theme.Accent
	local sw = colorSwatch(row, swatchColor)
	sw.Position = UDim2.fromOffset(12, 18)

	local nameL = Instance.new("TextLabel")
	nameL.BackgroundTransparency = 1
	nameL.Position = UDim2.fromOffset(60, 10)
	nameL.Size = UDim2.new(1, -200, 0, 22)
	nameL.Font = Theme.FontTitle
	nameL.TextSize = 15
	nameL.TextXAlignment = Enum.TextXAlignment.Left
	nameL.TextColor3 = Theme.Text
	nameL.Text = item.Name or item.Id
	nameL.Parent = row

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(60, 34)
	desc.Size = UDim2.new(1, -200, 0, 28)
	desc.Font = Theme.FontBody
	desc.TextSize = 12
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextColor3 = Theme.TextDim
	desc.Text = item.Description or item.Category or ""
	desc.Parent = row

	local action = Instance.new("TextButton")
	action.AnchorPoint = Vector2.new(1, 0.5)
	action.Position = UDim2.new(1, -12, 0.5, 0)
	action.Size = UDim2.fromOffset(110, 36)
	action.BorderSizePixel = 0
	action.Font = Theme.FontTitle
	action.TextSize = 13
	action.AutoButtonColor = false
	action.Parent = row
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
		-- inventory: only owned
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
end

local function rebuildShop()
	clearChildren(shopScroll)
	local order = 0
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 28)
	header.BackgroundTransparency = 1
	header.Font = Theme.FontTitle
	header.TextSize = 18
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = Theme.Text
	header.Text = "SHOP  ·  Spend Credits from kills & wins"
	header.LayoutOrder = order
	header.Parent = shopScroll
	order += 1

	for _, cat in CATEGORY_ORDER do
		local catLabel = Instance.new("TextLabel")
		catLabel.Size = UDim2.new(1, 0, 0, 22)
		catLabel.BackgroundTransparency = 1
		catLabel.Font = Theme.FontTitle
		catLabel.TextSize = 12
		catLabel.TextXAlignment = Enum.TextXAlignment.Left
		catLabel.TextColor3 = Theme.TextDim
		catLabel.Text = CATEGORY_LABELS[cat] or cat
		catLabel.LayoutOrder = order
		catLabel.Parent = shopScroll
		order += 1
		for _, item in shopItems do
			if item.Category == cat then
				makeItemRow(shopScroll, item, "shop", order)
				order += 1
			end
		end
	end
end

local function rebuildInventory()
	clearChildren(invScroll)
	local order = 0
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 28)
	header.BackgroundTransparency = 1
	header.Font = Theme.FontTitle
	header.TextSize = 18
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = Theme.Text
	header.Text = "INVENTORY  ·  Equip skins for next match"
	header.LayoutOrder = order
	header.Parent = invScroll
	order += 1

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
			local catLabel = Instance.new("TextLabel")
			catLabel.Size = UDim2.new(1, 0, 0, 22)
			catLabel.BackgroundTransparency = 1
			catLabel.Font = Theme.FontTitle
			catLabel.TextSize = 12
			catLabel.TextXAlignment = Enum.TextXAlignment.Left
			catLabel.TextColor3 = Theme.TextDim
			catLabel.Text = CATEGORY_LABELS[cat] or cat
			catLabel.LayoutOrder = order
			catLabel.Parent = invScroll
			order += 1
			for _, item in ownedInCat do
				makeItemRow(invScroll, item, "inv", order)
				order += 1
			end
		end
	end
	if not any then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 40)
		empty.BackgroundTransparency = 1
		empty.Font = Theme.FontBody
		empty.TextSize = 14
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
-- SETTINGS STUB
--------------------------------------------------------------------------
local setCard = Instance.new("Frame")
setCard.AnchorPoint = Vector2.new(0.5, 0.5)
setCard.Position = UDim2.fromScale(0.5, 0.5)
setCard.Size = UDim2.fromOffset(520, 260)
setCard.BackgroundColor3 = Theme.Panel
setCard.BorderSizePixel = 0
setCard.Parent = setPage
corner(setCard)
stroke(setCard)
do
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 28)
	p.PaddingLeft = UDim.new(0, 28)
	p.PaddingRight = UDim.new(0, 28)
	p.Parent = setCard
end
local setTitle = Instance.new("TextLabel")
setTitle.BackgroundTransparency = 1
setTitle.Size = UDim2.new(1, 0, 0, 28)
setTitle.Font = Theme.FontTitle
setTitle.TextSize = 22
setTitle.TextXAlignment = Enum.TextXAlignment.Left
setTitle.TextColor3 = Theme.Text
setTitle.Text = "SETTINGS"
setTitle.Parent = setCard
local setBody = Instance.new("TextLabel")
setBody.BackgroundTransparency = 1
setBody.Position = UDim2.fromOffset(0, 48)
setBody.Size = UDim2.new(1, 0, 0, 140)
setBody.Font = Theme.FontBody
setBody.TextSize = 14
setBody.TextWrapped = true
setBody.TextXAlignment = Enum.TextXAlignment.Left
setBody.TextYAlignment = Enum.TextYAlignment.Top
setBody.TextColor3 = Theme.TextMuted
setBody.Text =
	"Audio mix, sensitivity, and graphics toggles will land here.\n\nFor now: use Roblox Esc menu for volume / graphics.\nSkins & titles are under Shop / Inventory.\nCredits persist via DataStore (memory fallback in Studio)."
setBody.Parent = setCard

--------------------------------------------------------------------------
-- Countdown + Winner overlays (match hub theme)
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
cdDim.BackgroundTransparency = 0.45
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
winnerDim.BackgroundTransparency = 0.35
winnerDim.BorderSizePixel = 0
winnerDim.Active = true
winnerDim.Parent = winnerGui

local winnerCard = Instance.new("Frame")
winnerCard.AnchorPoint = Vector2.new(0.5, 0.5)
winnerCard.Position = UDim2.fromScale(0.5, 0.5)
winnerCard.Size = UDim2.fromOffset(480, 280)
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
-- Camera / flow helpers
--------------------------------------------------------------------------
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
	startBtn.Text = "START"
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
	local tickId = Config.SoundIds and Config.SoundIds.CountdownTick
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
	scoreLine ..= string.format("\nCredits  ₵ %d", credits)
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
	-- If we already have catalog rows, refresh ownership flags
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
