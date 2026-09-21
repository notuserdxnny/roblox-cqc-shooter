--!strict
--[[
	Creates Shotgun / SMG / Pistol tools and grants them after hub StartMatch.
	Does not give weapons on join — Hub → StartMatch → GiveLoadout.
	On CharacterAdded while in-match, re-grants the full loadout.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))

local WeaponService = {}

local templates: { [string]: Tool } = {}

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
	-- Align BEFORE weld — critical to avoid character teleport on equip
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

local function stripWeapons(player: Player)
	local function strip(container: Instance?)
		if not container then
			return
		end
		for _, child in container:GetChildren() do
			if Config.IsWeaponTool(child) then
				child:Destroy()
			end
		end
	end
	strip(player:FindFirstChildOfClass("Backpack"))
	strip(player.Character)
end

function WeaponService.GiveLoadout(player: Player, preferredWeaponId: string?)
	local preferred = preferredWeaponId or Config.DefaultWeaponId
	if not Config.GetWeapon(preferred) then
		preferred = Config.DefaultWeaponId
	end

	CombatService.SetInMatch(player, true, preferred)
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
		for _, id in Config.WeaponOrder do
			local tool = getTemplate(id):Clone()
			tool.Parent = backpack or character
			if id == preferred then
				preferredTool = tool
			end
		end

		-- Equip preferred starter
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and preferredTool then
			task.defer(function()
				if preferredTool and preferredTool.Parent and humanoid.Parent then
					humanoid:EquipTool(preferredTool)
				end
			end)
		end

		CombatService.NotifyMatchStarted(player, preferred)
	end

	if player.Character then
		task.spawn(grant)
	end
end

function WeaponService.Init()
	for _, id in Config.WeaponOrder do
		getTemplate(id)
	end

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

	fire.OnServerEvent:Connect(function(player, a)
		if a == "reload" then
			CombatService.StartReload(player)
		elseif a == "sync" then
			CombatService.PushEquippedAmmo(player)
		end
	end)

	startMatch.OnServerEvent:Connect(function(player, payload)
		local weaponId = Config.DefaultWeaponId
		if typeof(payload) == "string" and Config.GetWeapon(payload) then
			weaponId = payload
		elseif typeof(payload) == "table" and typeof(payload.weaponId) == "string" and Config.GetWeapon(payload.weaponId) then
			weaponId = payload.weaponId
		end
		WeaponService.GiveLoadout(player, weaponId)
	end)

	local function hookPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			if CombatService.IsInMatch(player) then
				local preferred = player:GetAttribute("CQCPreferredWeapon")
				if typeof(preferred) ~= "string" then
					preferred = Config.DefaultWeaponId
				end
				task.spawn(function()
					WeaponService.GiveLoadout(player, preferred :: string)
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
