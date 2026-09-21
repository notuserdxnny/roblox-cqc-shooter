--!strict
--[[
	Server entry: remotes, combat, weapons, game modes, shop/data, doors, NPCs.
	Weapons are granted after client Hub StartMatch (not on bare join).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemote(name: string)
	if not remotes:FindFirstChild(name) then
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
end

ensureRemote(Config.Remotes.FireWeapon)
ensureRemote(Config.Remotes.FireResult)
ensureRemote(Config.Remotes.AmmoUpdate)
ensureRemote(Config.Remotes.KillFeed)
ensureRemote(Config.Remotes.StatsUpdate)
ensureRemote(Config.Remotes.ToggleDoor)
ensureRemote(Config.Remotes.StartMatch)
ensureRemote(Config.Remotes.MatchCountdown)
ensureRemote(Config.Remotes.MatchStarted)
ensureRemote(Config.Remotes.MatchEnded)
ensureRemote(Config.Remotes.ReturnToHub)
ensureRemote(Config.Remotes.MeleeAttack)
ensureRemote(Config.Remotes.GetShop)
ensureRemote(Config.Remotes.PurchaseItem)
ensureRemote(Config.Remotes.EquipItem)
ensureRemote(Config.Remotes.CreditsUpdate)
ensureRemote(Config.Remotes.PlayerDataSync)
ensureRemote(Config.Remotes.ShopResult)

local Modules = script.Parent:WaitForChild("Modules")
local CombatService = require(Modules:WaitForChild("CombatService"))
local WeaponService = require(Modules:WaitForChild("WeaponService"))
local GameModeService = require(Modules:WaitForChild("GameModeService"))
local LobbyService = require(Modules:WaitForChild("LobbyService"))
local ShopService = require(Modules:WaitForChild("ShopService"))
local NPCService = require(Modules:WaitForChild("NPCService"))
require(Modules:WaitForChild("DoorService"))

-- Shop/Data first so loadout skins can read profiles
ShopService.Init()
CombatService.Init()
WeaponService.Init()
GameModeService.Init()
LobbyService.Init()

task.defer(function()
	task.wait(0.6)
	local arena = workspace:FindFirstChild("CQCArena")
	local marks = arena and arena:FindFirstChild("NPCSpawnMarks")
	local offsets = {}
	if marks then
		for _, child in marks:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(offsets, Vector3.new(child.Position.X, 0, child.Position.Z))
			end
		end
	end
	if #offsets == 0 then
		offsets = Config.NPC.SpawnOffsets
	end
	Config.NPC.SpawnOffsets = offsets
	NPCService.Init(Vector3.new(0, Config.Arena.SpawnHeight, 0))
end)

print("[CQC] Server Main ready (hub shop/inventory · countdown · OITC · detailed tools).")
