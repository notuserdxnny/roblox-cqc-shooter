--!strict
--[[
	Creates detailed Part-assembled weapon tools and grants OITC loadout after StartMatch.
	Applies equipped shop skins (Handle/parts colors, tool DisplayName, title billboard, trail).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local WeaponModels = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponModels"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local WeaponService = {}

local templates: { [string]: Tool } = {}
local knifeTemplate: Tool? = nil
local GameModeService: any = nil

local function getGameMode()
	if not GameModeService then
		GameModeService = require(script.Parent:WaitForChild("GameModeService"))
	end
	return GameModeService
end

local function createWeaponTool(def: Config.WeaponDef): Tool
	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true
	tool.ToolTip = def.ToolTip
	tool:SetAttribute("WeaponId", def.Id)

	if def.Id == "Pistol" then
		local colors = WeaponModels.SkinFromItem(nil, def.HandleColor, def.TipColor)
		WeaponModels.BuildPistol(tool, colors)
	else
		-- Fallback simple body for unused Shotgun/SMG catalog entries
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = def.HandleSize
		handle.Color = def.HandleColor
		handle.Material = Enum.Material.Metal
		handle.CanCollide = false
		handle.Massless = true
		handle:SetAttribute("SkinRole", "Primary")
		handle.Parent = tool

		local tip = Instance.new("Part")
		tip.Name = "Muzzle"
		tip.Size = Vector3.new(0.25, 0.25, 0.4)
		tip.Color = def.TipColor
		tip.Material = Enum.Material.Neon
		tip.CanCollide = false
		tip.Massless = true
		tip:SetAttribute("SkinRole", "Accent")
		local muzzleZ = -def.HandleSize.Z * 0.45
		tip.CFrame = handle.CFrame * CFrame.new(0, 0, muzzleZ)
		tip.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = tip
		weld.Parent = tip
		local light = Instance.new("PointLight")
		light.Name = "MuzzleLight"
		light.Brightness = 0
		light.Range = Config.Feel.MuzzleLightRange
		light.Color = Color3.fromRGB(255, 200, 120)
		light.Enabled = false
		light.Parent = tip
	end

	return tool
end

local function createKnifeTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = Config.OITC.MeleeToolName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true
	tool.ToolTip = Config.Melee.ToolTip
	tool:SetAttribute("WeaponId", "Melee")
	tool:SetAttribute("IsMelee", true)

	local colors = WeaponModels.SkinFromItem(nil, Config.Melee.HandleColor, Config.Melee.TipColor)
	WeaponModels.BuildKnife(tool, colors)
	return tool
end

local function getTemplate(weaponId: string): Tool
	local existing = templates[weaponId]
	if existing and existing.Parent then
		return existing
	end
	local def = Config.GetWeapon(weaponId)
	assert(def, "Unknown weapon " .. weaponId)
	local folder = ReplicatedStorage:FindFirstChild("WeaponTemplates")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "WeaponTemplates"
		folder.Parent = ReplicatedStorage
	end
	local tool = createWeaponTool(def)
	tool.Parent = folder
	templates[weaponId] = tool
	return tool
end

local function getKnifeTemplate(): Tool
	if knifeTemplate and knifeTemplate.Parent then
		return knifeTemplate
	end
	local folder = ReplicatedStorage:FindFirstChild("WeaponTemplates")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "WeaponTemplates"
		folder.Parent = ReplicatedStorage
	end
	local tool = createKnifeTool()
	tool.Parent = folder
	knifeTemplate = tool
	return tool
end

local function stripWeapons(player: Player)
	local function strip(container: Instance?)
		if not container then
			return
		end
		for _, child in container:GetChildren() do
			if Config.IsWeaponTool(child) or Config.IsMeleeTool(child) then
				child:Destroy()
			end
		end
	end
	strip(player:FindFirstChildOfClass("Backpack"))
	strip(player.Character)
end

function WeaponService.StripAll(player: Player)
	stripWeapons(player)
	WeaponService.ClearCosmetics(player)
end

function WeaponService.ClearCosmetics(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local existing = character:FindFirstChild("CQCTitleBillboard")
	if existing then
		existing:Destroy()
	end
	local trail = character:FindFirstChild("CQCTrail", true)
	if trail then
		trail:Destroy()
	end
	local att0 = character:FindFirstChild("CQCTrailA0", true)
	if att0 then
		att0:Destroy()
	end
	local att1 = character:FindFirstChild("CQCTrailA1", true)
	if att1 then
		att1:Destroy()
	end
end

local function applyToolSkin(tool: Tool, itemId: string?, fallbackPrimary: Color3, fallbackAccent: Color3, displayName: string?)
	local item = if itemId then Config.GetShopItem(itemId) else nil
	local colors = WeaponModels.SkinFromItem(item, fallbackPrimary, fallbackAccent)
	WeaponModels.ApplySkin(tool, colors)
	if item and typeof(item.DisplayName) == "string" and item.DisplayName ~= "" then
		tool.ToolTip = item.DisplayName .. " · " .. (tool.ToolTip or "")
	elseif displayName then
		-- keep
	end
	if itemId then
		tool:SetAttribute("SkinId", itemId)
	end
end

local function applyTitleBillboard(character: Model, titleItemId: string?)
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local old = character:FindFirstChild("CQCTitleBillboard")
	if old then
		old:Destroy()
	end
	local item = if titleItemId then Config.GetShopItem(titleItemId) else nil
	if not item or typeof(item.TitleText) ~= "string" or item.TitleText == "" then
		return
	end
	local bill = Instance.new("BillboardGui")
	bill.Name = "CQCTitleBillboard"
	bill.Size = UDim2.fromOffset(160, 28)
	bill.StudsOffset = Vector3.new(0, 2.4, 0)
	bill.AlwaysOnTop = true
	bill.MaxDistance = 60
	bill.Parent = character
	bill.Adornee = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = item.TitleColor or Color3.fromRGB(200, 200, 210)
	label.TextStrokeTransparency = 0.5
	label.Text = item.TitleText
	label.Parent = bill
end

local function applyTrail(character: Model, trailItemId: string?)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local old = root:FindFirstChild("CQCTrail")
	if old then
		old:Destroy()
	end
	local a0 = root:FindFirstChild("CQCTrailA0")
	if a0 then
		a0:Destroy()
	end
	local a1 = root:FindFirstChild("CQCTrailA1")
	if a1 then
		a1:Destroy()
	end
	local item = if trailItemId then Config.GetShopItem(trailItemId) else nil
	if not item or item.TrailEnabled ~= true then
		return
	end
	local att0 = Instance.new("Attachment")
	att0.Name = "CQCTrailA0"
	att0.Position = Vector3.new(0, 0.5, 0)
	att0.Parent = root
	local att1 = Instance.new("Attachment")
	att1.Name = "CQCTrailA1"
	att1.Position = Vector3.new(0, -0.8, 0)
	att1.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "CQCTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	local col = item.TrailColor or Color3.fromRGB(100, 200, 255)
	trail.Color = ColorSequence.new(col)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.35
	trail.MinLength = 0.1
	trail.FaceCamera = true
	trail.LightEmission = 0.4
	trail.Parent = root
end

function WeaponService.ApplyEquippedCosmetics(player: Player, pistol: Tool?, knife: Tool?)
	local eq = PlayerDataService.GetEquipped(player)
	local pistolDef = Config.Weapons.Pistol
	if pistol then
		applyToolSkin(pistol, eq.PistolSkin, pistolDef.HandleColor, pistolDef.TipColor, pistolDef.Name)
	end
	if knife then
		applyToolSkin(knife, eq.KnifeSkin, Config.Melee.HandleColor, Config.Melee.TipColor, Config.OITC.MeleeToolName)
	end
	local character = player.Character
	if character then
		applyTitleBillboard(character, eq.Title)
		applyTrail(character, eq.Trail)
	end
end

--[[
	Server-side Tool.Activated for Knife.
]]
local function bindKnifeActivated(player: Player, knife: Tool)
	if knife:GetAttribute("CQCMeleeBound") == true then
		return
	end
	knife:SetAttribute("CQCMeleeBound", true)
	knife.Activated:Connect(function()
		if not CombatService.IsInMatch(player) then
			return
		end
		local character = player.Character
		if not character or knife.Parent ~= character then
			return
		end
		local head = character:FindFirstChild("Head") :: BasePart?
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local origin = if head then head.Position elseif root then root.Position + Vector3.new(0, 1.2, 0) else Vector3.zero
		local look = if root then root.CFrame.LookVector else Vector3.zAxis
		CombatService.HandleMelee(player, origin, look)
	end)
end

function WeaponService.GiveLoadout(player: Player, preferredWeaponId: string?, mode: string?)
	local resolvedMode = Config.Modes.OITC
	local preferred = Config.OITC.WeaponId
	if typeof(preferredWeaponId) == "string" and preferredWeaponId == Config.OITC.WeaponId then
		preferred = preferredWeaponId
	end
	local _ = mode

	CombatService.SetMode(player, resolvedMode)
	CombatService.SetInMatch(player, true, preferred, resolvedMode)
	getGameMode().SetMode(player, resolvedMode)
	CombatService.ResetAmmo(player, nil)

	local function grant()
		task.wait(0.15)
		local backpack = player:FindFirstChildOfClass("Backpack")
		local character = player.Character
		if not character then
			return
		end
		stripWeapons(player)
		WeaponService.ClearCosmetics(player)

		local preferredTool: Tool? = nil

		local pistol = getTemplate(Config.OITC.WeaponId):Clone()
		pistol.Parent = backpack or character
		preferredTool = pistol

		local knife = getKnifeTemplate():Clone()
		knife.Parent = backpack or character
		bindKnifeActivated(player, knife)

		WeaponService.ApplyEquippedCosmetics(player, pistol, knife)

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and preferredTool then
			task.defer(function()
				if preferredTool and preferredTool.Parent and humanoid.Parent then
					humanoid:EquipTool(preferredTool)
				end
			end)
		end

		CombatService.NotifyMatchStarted(player, preferred, resolvedMode)
	end

	if player.Character then
		task.spawn(grant)
	end
end

function WeaponService.Init()
	for _, id in Config.WeaponOrder do
		getTemplate(id)
	end
	getKnifeTemplate()

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local function ensureRemote(name: string): RemoteEvent
		local existing = remotes:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
		return r
	end

	local fire = ensureRemote(Config.Remotes.FireWeapon)
	local startMatch = ensureRemote(Config.Remotes.StartMatch)
	ensureRemote(Config.Remotes.MatchCountdown)
	ensureRemote(Config.Remotes.MatchStarted)
	ensureRemote(Config.Remotes.MatchEnded)
	ensureRemote(Config.Remotes.ReturnToHub)
	ensureRemote(Config.Remotes.MeleeAttack)

	fire.OnServerEvent:Connect(function(player, a)
		if a == "reload" then
			CombatService.StartReload(player)
		elseif a == "sync" then
			CombatService.PushEquippedAmmo(player)
		end
	end)

	startMatch.OnServerEvent:Connect(function(player, _payload)
		getGameMode().StartMatch(player, Config.Modes.OITC, Config.OITC.WeaponId)
	end)

	local function hookPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			if CombatService.IsInMatch(player) and not getGameMode().IsMatchOver(player) then
				task.spawn(function()
					WeaponService.GiveLoadout(player, Config.OITC.WeaponId, Config.Modes.OITC)
				end)
			end
		end)
	end

	Players.PlayerAdded:Connect(hookPlayer)
	for _, player in Players:GetPlayers() do
		hookPlayer(player)
	end
end

return WeaponService
