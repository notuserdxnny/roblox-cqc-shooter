--!strict
--[[
	Force LockFirstPerson for FPS feel AFTER countdown GO / while in match.
	While CQCInHub, CQCMatchOver, or (not in match and not countdown): Classic + unlocked mouse.
	During CQCCountdown: LockFirstPerson so the arena is visible behind the 3…2…1 overlay
	(mouse may still be unlocked by Hub for the overlay).

	CRITICAL (Bug B): Tool clicks / MouseButton1 can unlock MouseBehavior to Default.
	While live InMatch we re-assert LockCenter + hide icon every RenderStepped and on InputEnded.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local camCfg = Config.Camera

local function inCountdown(): boolean
	return player:GetAttribute("CQCCountdown") == true
end

local function inMatchLive(): boolean
	return player:GetAttribute("CQCInMatch") == true
		and player:GetAttribute("CQCMatchOver") ~= true
		and player:GetAttribute("CQCCountdown") ~= true
		and player:GetAttribute("CQCInHub") ~= true
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
		-- Clear GUI selection so clicks don't steal focus from camera look
		pcall(function()
			GuiService.SelectedObject = nil
		end)
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

--[[
	Re-assert mouse lock while live. Tool.Activated / MouseButton1 often flips
	MouseBehavior back to Default; without a per-frame fix, look freezes until re-click.
]]
local function assertMatchMouseLock()
	if not inMatchLive() then
		return
	end
	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
	if UserInputService.MouseIconEnabled then
		UserInputService.MouseIconEnabled = false
	end
	if camCfg.LockFirstPerson and player.CameraMode ~= Enum.CameraMode.LockFirstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMinZoomDistance = camCfg.MinZoom
		player.CameraMaxZoomDistance = camCfg.MaxZoom
	end
	pcall(function()
		if GuiService.SelectedObject ~= nil then
			GuiService.SelectedObject = nil
		end
	end)
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

-- Every frame while live: keep LockCenter (fixes shoot → look freeze)
RunService:BindToRenderStep("CQC_MouseLock", Enum.RenderPriority.Camera.Value + 3, function()
	if inMatchLive() then
		assertMatchMouseLock()
	end
end)

-- After LMB release, Tool click paths often unlock — re-lock immediately
UserInputService.InputEnded:Connect(function(input, _gp)
	if not inMatchLive() then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.MouseButton2
		or input.UserInputType == Enum.UserInputType.Touch
	then
		assertMatchMouseLock()
		task.defer(assertMatchMouseLock)
	end
end)

UserInputService.WindowFocused:Connect(function()
	if inMatchLive() then
		assertMatchMouseLock()
	end
end)

-- Slow hub/countdown hygiene (do NOT unlock live match here)
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
		elseif inMatchLive() then
			assertMatchMouseLock()
			if player.CameraMaxZoomDistance > camCfg.MaxZoom + 0.01 then
				applyCamera()
			end
		end
	end
end)
