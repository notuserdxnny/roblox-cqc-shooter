--!strict
--[[
	Creates Shotgun / SMG / Pistol tools (and Knife for OITC) and grants loadouts after StartMatch.
	Casual: all three guns. OITC: Pistol only + Knife; ammo starts at Config.OITC.StartingAmmo.
	On CharacterAdded while in-match, re-grants the mode-appropriate loadout (OITC resets to 1 bullet).
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

function WeaponService.GiveLoadout(player: Player, preferredWeaponId: string?, mode: string?)
	local resolvedMode = mode or getGameMode().GetMode(player) or Config.DefaultMode
	if resolvedMode ~= Config.Modes.OITC and resolvedMode ~= Config.Modes.Casual then
		resolvedMode = Config.DefaultMode
	end

	local preferred = preferredWeaponId or Config.DefaultWeaponId
	if resolvedMode == Config.Modes.OITC then
		preferred = Config.OITC.WeaponId
	elseif not Config.GetWeapon(preferred) then
		preferred = Config.DefaultWeaponId
	end

	CombatService.SetMode(player, resolvedMode)
	CombatService.SetInMatch(player, true, preferred, resolvedMode)
	getGameMode().SetMode(player, resolvedMode)

	-- Reset ammo for mode (OITC → StartingAmmo on pistol)
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

		if resolvedMode == Config.Modes.OITC then
			local pistol = getTemplate(Config.OITC.WeaponId):Clone()
			pistol.Parent = backpack or character
			preferredTool = pistol

			local knife = getKnifeTemplate():Clone()
			knife.Parent = backpack or character
		else
			for _, id in Config.WeaponOrder do
				local tool = getTemplate(id):Clone()
				tool.Parent = backpack or character
				if id == preferred then
					preferredTool = tool
				end
			end
		end

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

	startMatch.OnServerEvent:Connect(function(player, payload)
		local weaponId = Config.DefaultWeaponId
		local mode = Config.DefaultMode
		if typeof(payload) == "string" and Config.GetWeapon(payload) then
			weaponId = payload
		elseif typeof(payload) == "table" then
			if typeof(payload.weaponId) == "string" and Config.GetWeapon(payload.weaponId) then
				weaponId = payload.weaponId
			end
			if typeof(payload.mode) == "string" then
				mode = getGameMode().NormalizeMode(payload.mode)
			end
		end
		getGameMode().StartMatch(player, mode, weaponId)
	end)

	local function hookPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			if CombatService.IsInMatch(player) and not getGameMode().IsMatchOver(player) then
				local preferred = player:GetAttribute("CQCPreferredWeapon")
				if typeof(preferred) ~= "string" then
					preferred = Config.DefaultWeaponId
				end
				local mode = player:GetAttribute("CQCMode")
				if typeof(mode) ~= "string" then
					mode = getGameMode().GetMode(player)
				end
				task.spawn(function()
					-- OITC classic: respawn with starting ammo again
					WeaponService.GiveLoadout(player, preferred :: string, mode :: string)
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
