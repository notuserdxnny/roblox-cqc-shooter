--!strict
--[[
	Force LockFirstPerson for FPS feel AFTER countdown GO / while in match.
	While CQCInHub, CQCMatchOver, or (not in match and not countdown): Classic + unlocked mouse.
	During CQCCountdown: LockFirstPerson so the arena is visible behind the 3…2…1 overlay
	(mouse may still be unlocked by Hub for the overlay).
	Re-applies on CharacterAdded / attribute changes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local camCfg = Config.Camera

local function inCountdown(): boolean
	return player:GetAttribute("CQCCountdown") == true
end

local function inMatchLive(): boolean
	return player:GetAttribute("CQCInMatch") == true and player:GetAttribute("CQCMatchOver") ~= true
end

local function wantsHubCamera(): boolean
	if player:GetAttribute("CQCMatchOver") == true then
		return true
	end
	if player:GetAttribute("CQCInHub") == true then
		return true
	end
	-- Countdown uses match (FP) camera
	if inCountdown() then
		return false
	end
	if not inMatchLive() then
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

local function applyMatchCamera(lockMouse: boolean)
	if camCfg.LockFirstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end
	player.CameraMinZoomDistance = camCfg.MinZoom
	player.CameraMaxZoomDistance = camCfg.MaxZoom
	pcall(function()
		player.DevEnableMouseLock = camCfg.EnableMouseLock == true
	end)
	if lockMouse then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	else
		-- Countdown: FP view but free mouse so overlay feels clickable / readable
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end

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
	if wantsHubCamera() then
		applyHubCamera()
	elseif inCountdown() then
		applyMatchCamera(false)
	else
		applyMatchCamera(true)
	end
end

applyCamera()

local function hookAttr(name: string)
	player:GetAttributeChangedSignal(name):Connect(function()
		applyCamera()
		task.defer(applyCamera)
	end)
end

hookAttr("CQCInHub")
hookAttr("CQCInMatch")
hookAttr("CQCCountdown")
hookAttr("CQCMatchOver")

player.CharacterAdded:Connect(function()
	applyCamera()
	task.defer(applyCamera)
	task.delay(0.1, applyCamera)
	task.delay(0.5, applyCamera)
end)

task.spawn(function()
	while true do
		task.wait(1.5)
		if wantsHubCamera() then
			if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				UserInputService.MouseIconEnabled = true
			end
			if player.CameraMode == Enum.CameraMode.LockFirstPerson then
				applyHubCamera()
			end
		elseif inCountdown() then
			applyMatchCamera(false)
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
