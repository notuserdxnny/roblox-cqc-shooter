--!strict
--[[
	Creates weapon tools (catalog includes Shotgun/SMG for later) and grants OITC loadout after StartMatch.
	OITC-only for now: Pistol + Knife; ammo starts at Config.OITC.StartingAmmo.
	On CharacterAdded while in-match, re-grants OITC loadout (resets to 1 bullet).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))

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
	tool.ManualActivationOnly = false
	tool.ToolTip = def.ToolTip
	tool:SetAttribute("WeaponId", def.Id)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = def.HandleSize
	handle.Color = def.HandleColor
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local tip = Instance.new("Part")
	tip.Name = "Muzzle"
	tip.Size = Vector3.new(0.25, 0.25, 0.4)
	tip.Color = def.TipColor
	tip.Material = Enum.Material.Neon
	tip.CanCollide = false
	tip.Massless = true
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

	return tool
end

local function createKnifeTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = Config.OITC.MeleeToolName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ManualActivationOnly = false
	tool.ToolTip = Config.Melee.ToolTip
	tool:SetAttribute("WeaponId", "Melee")
	tool:SetAttribute("IsMelee", true)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Config.Melee.HandleSize
	handle.Color = Config.Melee.HandleColor
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local tip = Instance.new("Part")
	tip.Name = "Blade"
	tip.Size = Vector3.new(0.18, 0.08, 0.7)
	tip.Color = Config.Melee.TipColor
	tip.Material = Enum.Material.Neon
	tip.CanCollide = false
	tip.Massless = true
	tip.CFrame = handle.CFrame * CFrame.new(0, 0, -Config.Melee.HandleSize.Z * 0.55)
	tip.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = tip
	weld.Parent = tip

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
end

--[[
	Server-side Tool.Activated for Knife — guarantees melee registers even if
	the client MeleeAttack remote path fails silently.
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
	-- OITC-only: always pistol + knife regardless of client payload
	local resolvedMode = Config.Modes.OITC
	local preferred = Config.OITC.WeaponId
	if typeof(preferredWeaponId) == "string" and preferredWeaponId == Config.OITC.WeaponId then
		preferred = preferredWeaponId
	end
	-- mode arg ignored (kept for call-site compatibility)
	local _ = mode

	CombatService.SetMode(player, resolvedMode)
	CombatService.SetInMatch(player, true, preferred, resolvedMode)
	getGameMode().SetMode(player, resolvedMode)

	-- OITC → StartingAmmo on pistol
	CombatService.ResetAmmo(player, nil)

	local function grant()
		task.wait(0.15)
		local backpack = player:FindFirstChildOfClass("Backpack")
		local character = player.Character
		if not character then
			return
		end
		stripWeapons(player)

		local preferredTool: Tool? = nil

		local pistol = getTemplate(Config.OITC.WeaponId):Clone()
		pistol.Parent = backpack or character
		preferredTool = pistol

		local knife = getKnifeTemplate():Clone()
		knife.Parent = backpack or character
		bindKnifeActivated(player, knife)

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
		-- OITC-only: ignore client weapon/mode; GameModeService forces OITC rules
		getGameMode().StartMatch(player, Config.Modes.OITC, Config.OITC.WeaponId)
	end)

	local function hookPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			if CombatService.IsInMatch(player) and not getGameMode().IsMatchOver(player) then
				task.spawn(function()
					-- OITC classic: respawn with starting ammo again
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
