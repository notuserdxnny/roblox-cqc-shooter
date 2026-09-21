--!strict
--[[
	Force LockFirstPerson for FPS feel after hub Start.
	While CQCInHub, leave Classic camera so the lobby UI is clickable.
	Re-applies on CharacterAdded / attribute changes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local camCfg = Config.Camera

local function inHub(): boolean
	return player:GetAttribute("CQCInHub") == true
end

local function applyCamera()
	if inHub() then
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 24
		pcall(function()
			player.DevEnableMouseLock = false
		end)
		return
	end

	if camCfg.LockFirstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end
	player.CameraMinZoomDistance = camCfg.MinZoom
	player.CameraMaxZoomDistance = camCfg.MaxZoom
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

applyCamera()

player:GetAttributeChangedSignal("CQCInHub"):Connect(function()
	applyCamera()
	task.defer(applyCamera)
end)

player.CharacterAdded:Connect(function()
	applyCamera()
	task.defer(applyCamera)
	task.delay(0.1, applyCamera)
	task.delay(0.5, applyCamera)
end)

task.spawn(function()
	while true do
		task.wait(2)
		if not inHub() then
			if player.CameraMode ~= Enum.CameraMode.LockFirstPerson and camCfg.LockFirstPerson then
				applyCamera()
			end
			if player.CameraMaxZoomDistance > camCfg.MaxZoom + 0.01 then
				applyCamera()
			end
		end
	end
end)
