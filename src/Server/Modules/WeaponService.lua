--!strict
--[[
	Creates and grants the CQC Tool to players on spawn.
	Firing input is handled by Client/WeaponController.client.lua.
	Muzzle part includes a PointLight slot for client flash FX.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))

local WeaponService = {}

local function createWeaponTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = Config.Weapon.Name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ManualActivationOnly = false
	tool.ToolTip = "Hold LMB fire · R reload · close range"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 2.2)
	handle.Color = Color3.fromRGB(40, 40, 48)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local tip = Instance.new("Part")
	tip.Name = "Muzzle"
	tip.Size = Vector3.new(0.25, 0.25, 0.4)
	tip.Color = Color3.fromRGB(180, 40, 40)
	tip.Material = Enum.Material.Neon
	tip.CanCollide = false
	tip.Massless = true
	tip.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = tip
	weld.Parent = tip
	tip.CFrame = handle.CFrame * CFrame.new(0, 0, -1.2)

	-- Pre-create light (client enables briefly on fire)
	local light = Instance.new("PointLight")
	light.Name = "MuzzleLight"
	light.Brightness = 0
	light.Range = Config.Feel.MuzzleLightRange
	light.Color = Color3.fromRGB(255, 200, 120)
	light.Enabled = false
	light.Parent = tip

	return tool
end

local template: Tool? = nil

local function getTemplate(): Tool
	if template and template.Parent then
		return template
	end
	template = createWeaponTool()
	template.Parent = ReplicatedStorage
	return template
end

function WeaponService.GiveWeapon(player: Player)
	local function onCharacter(_character: Model)
		task.wait(0.15)
		local backpack = player:FindFirstChildOfClass("Backpack")
		local character = player.Character
		if not character then
			return
		end

		if backpack then
			for _, child in backpack:GetChildren() do
				if child.Name == Config.Weapon.Name then
					child:Destroy()
				end
			end
		end
		local existing = character:FindFirstChild(Config.Weapon.Name)
		if existing then
			existing:Destroy()
		end

		local tool = getTemplate():Clone()
		tool.Parent = backpack or character
		CombatService.ResetAmmo(player)
	end

	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

function WeaponService.Init()
	getTemplate()

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	local fire = remotes:FindFirstChild(Config.Remotes.FireWeapon) :: RemoteEvent?
	if not fire then
		fire = Instance.new("RemoteEvent")
		fire.Name = Config.Remotes.FireWeapon
		fire.Parent = remotes
	end

	-- Reload requests (string "reload") — CombatService ignores non-Vector3 origins
	fire.OnServerEvent:Connect(function(player, a)
		if a == "reload" then
			CombatService.StartReload(player)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		WeaponService.GiveWeapon(player)
	end)
	for _, player in Players:GetPlayers() do
		WeaponService.GiveWeapon(player)
	end
end

return WeaponService
