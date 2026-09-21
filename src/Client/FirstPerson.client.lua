--!strict
--[[
	Force LockFirstPerson for FPS feel AFTER hub Start / while in match.
	While CQCInHub (or not CQCInMatch): Classic camera, unlocked mouse for UI.
	Re-applies on CharacterAdded / attribute changes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local camCfg = Config.Camera

local function inHub(): boolean
	if player:GetAttribute("CQCInHub") == true then
		return true
	end
	-- Treat "not in match" as hub for camera/mouse
	if player:GetAttribute("CQCInMatch") ~= true then
		return true
	end
	return false
end

local function applyHubCamera()
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = camCfg.HubMinZoom or 8
	player.CameraMaxZoomDistance = camCfg.HubMaxZoom or 20
	pcall(function()
		player.DevEnableMouseLock = false
	end)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true

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

local function applyMatchCamera()
	if camCfg.LockFirstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end
	player.CameraMinZoomDistance = camCfg.MinZoom
	player.CameraMaxZoomDistance = camCfg.MaxZoom
	pcall(function()
		player.DevEnableMouseLock = camCfg.EnableMouseLock == true
	end)
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

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

local function applyCamera()
	if inHub() then
		applyHubCamera()
	else
		applyMatchCamera()
	end
end

applyCamera()

player:GetAttributeChangedSignal("CQCInHub"):Connect(function()
	applyCamera()
	task.defer(applyCamera)
end)

player:GetAttributeChangedSignal("CQCInMatch"):Connect(function()
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
		task.wait(1.5)
		if inHub() then
			-- Keep mouse free while hub is up (Roblox may re-lock)
			if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				UserInputService.MouseIconEnabled = true
			end
			if player.CameraMode == Enum.CameraMode.LockFirstPerson then
				applyHubCamera()
			end
		else
			if player.CameraMode ~= Enum.CameraMode.LockFirstPerson and camCfg.LockFirstPerson then
				applyCamera()
			end
			if player.CameraMaxZoomDistance > camCfg.MaxZoom + 0.01 then
				applyCamera()
			end
		end
	end
end)
