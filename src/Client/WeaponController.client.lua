--!strict
--[[
	Client weapon input: hold LMB to fire (sends look to server), R to reload.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local fireRemote = remotes:WaitForChild(Config.Remotes.FireWeapon) :: RemoteEvent

local equippedTool: Tool? = nil
local holding = false
local lastLocalFire = 0
local boundTools: { [Tool]: boolean } = {}
local watchedContainers: { [Instance]: boolean } = {}

local function isOurTool(tool: Instance?): boolean
	return tool ~= nil and tool:IsA("Tool") and tool.Name == Config.Weapon.Name
end

local function getLook(): (Vector3, Vector3)
	local cam = workspace.CurrentCamera
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	local origin = if head then head.Position else (if cam then cam.CFrame.Position else Vector3.zero)
	local look = if cam then cam.CFrame.LookVector else Vector3.zAxis
	return origin, look
end

local function tryFire()
	if not equippedTool then
		return
	end
	local now = os.clock()
	if now - lastLocalFire < Config.Weapon.FireCooldown * 0.85 then
		return
	end
	lastLocalFire = now
	local origin, look = getLook()
	fireRemote:FireServer(origin, look)
end

local function bindTool(tool: Tool)
	if boundTools[tool] then
		return
	end
	boundTools[tool] = true
	tool.Destroying:Connect(function()
		boundTools[tool] = nil
		if equippedTool == tool then
			equippedTool = nil
			holding = false
		end
	end)
	tool.Equipped:Connect(function()
		equippedTool = tool
	end)
	tool.Unequipped:Connect(function()
		if equippedTool == tool then
			equippedTool = nil
			holding = false
		end
	end)
	tool.Activated:Connect(function()
		if equippedTool == tool then
			holding = true
			tryFire()
		end
	end)
	tool.Deactivated:Connect(function()
		holding = false
	end)
end

local function watchContainer(container: Instance)
	if watchedContainers[container] then
		-- Still pick up any new tools already present
		for _, child in container:GetChildren() do
			if isOurTool(child) then
				bindTool(child :: Tool)
			end
		end
		return
	end
	watchedContainers[container] = true
	for _, child in container:GetChildren() do
		if isOurTool(child) then
			bindTool(child :: Tool)
		end
	end
	container.ChildAdded:Connect(function(child)
		if isOurTool(child) then
			bindTool(child :: Tool)
		end
	end)
end

local function onCharacter(character: Model)
	equippedTool = nil
	holding = false
	watchContainer(character)
	local backpack = player:FindFirstChild("Backpack") or player:WaitForChild("Backpack")
	watchContainer(backpack)
end

if player.Character then
	onCharacter(player.Character)
end
player.CharacterAdded:Connect(onCharacter)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if not equippedTool then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		fireRemote:FireServer("reload")
	end
end)

RunService.RenderStepped:Connect(function()
	if holding and equippedTool then
		tryFire()
	end
end)
