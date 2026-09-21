--!strict
--[[
	Server entry: remotes, combat, weapons, doors, NPCs in room complex.
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

local Modules = script.Parent:WaitForChild("Modules")
local CombatService = require(Modules:WaitForChild("CombatService"))
local WeaponService = require(Modules:WaitForChild("WeaponService"))
local NPCService = require(Modules:WaitForChild("NPCService"))
-- DoorService is Init'd by WorldSetup; ensure module loads
require(Modules:WaitForChild("DoorService"))

CombatService.Init()
WeaponService.Init()

-- Wait for WorldSetup room marks, then spawn NPCs in marked rooms
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
	-- Patch config offsets for this session (NPCService reads Config)
	Config.NPC.SpawnOffsets = offsets
	NPCService.Init(Vector3.new(0, Config.Arena.SpawnHeight, 0))
end)

print("[CQC] Server Main ready.")
