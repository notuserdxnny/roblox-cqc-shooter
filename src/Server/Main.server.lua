--!strict
--[[
	Server entry: remotes, combat, weapons, NPCs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

-- Ensure Remotes folder exists early
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
ensureRemote(Config.Remotes.AmmoUpdate)
ensureRemote(Config.Remotes.KillFeed)
ensureRemote(Config.Remotes.StatsUpdate)

local Modules = script.Parent:WaitForChild("Modules")
local CombatService = require(Modules:WaitForChild("CombatService"))
local WeaponService = require(Modules:WaitForChild("WeaponService"))
local NPCService = require(Modules:WaitForChild("NPCService"))

CombatService.Init()
WeaponService.Init()

-- Wait a beat so WorldSetup can finish; NPCs spawn near arena center
task.defer(function()
	task.wait(0.5)
	NPCService.Init(Vector3.new(0, Config.Arena.SpawnHeight, 0))
end)

print("[CQC] Server Main ready.")
