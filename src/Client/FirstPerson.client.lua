--!strict
--[[
	Force LockFirstPerson for FPS feel. Re-applies on CharacterAdded.
	Shift-lock left optional/off. Crosshair stays screen-center (HUD).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local camCfg = Config.Camera

local function applyFirstPerson()
	if camCfg.LockFirstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end
	player.CameraMinZoomDistance = camCfg.MinZoom
	player.CameraMaxZoomDistance = camCfg.MaxZoom
	-- Shift-lock optional off
	pcall(function()
		player.DevEnableMouseLock = camCfg.EnableMouseLock == true
	end)

	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
	end
end

applyFirstPerson()

player.CharacterAdded:Connect(function()
	-- Camera can reset briefly on respawn; re-lock next frames
	applyFirstPerson()
	task.defer(applyFirstPerson)
	task.delay(0.1, applyFirstPerson)
	task.delay(0.5, applyFirstPerson)
end)

-- Periodically reinforce in case something else changes zoom/mode
task.spawn(function()
	while true do
		task.wait(2)
		if player.CameraMode ~= Enum.CameraMode.LockFirstPerson and camCfg.LockFirstPerson then
			applyFirstPerson()
		end
		if player.CameraMaxZoomDistance > camCfg.MaxZoom + 0.01 then
			applyFirstPerson()
		end
	end
end)
