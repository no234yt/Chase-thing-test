-- wip

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

local ANIM_ID = "rbxassetid://18752189666"
local CHARGE_TIME = 1.25
local BOOST_ACCEL = 6
local BOOST_DECAY = 0.985
local BOOST_POWER = 75
local JUMP_BOOST = 35
local MAX_SPEED = 100
local MIN_SPEED = 60
local FOV_CHARGE = 10
local FOV_BOOST = 5
local KEYBIND = Enum.KeyCode.V
local COOLDOWN_TIME = 1.5
local ICON_ID = "" -- put image id here
local BUTTON_NAME = "Roll"

local character, humanoid, hrp, animTrack
local isCharging = false
local isRolling = false
local onCooldown = false
local speed = 0
local targetSpeed = 0
local defaultWalkSpeed, defaultJumpPower, defaultHipHeight, defaultFov = 16, 50, 0, cam.FieldOfView

local function lerp(a,b,t) return a+(b-a)*t end
local function tweenFov(to,time) TweenService:Create(cam,TweenInfo.new(time,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{FieldOfView=to}):Play() end
local function getDir() local v=cam.CFrame.LookVector return Vector3.new(v.X,0,v.Z).Unit end

local function stopRoll()
	isCharging=false
	isRolling=false
	speed=0
	targetSpeed=0
	if animTrack then animTrack:Stop() end
	if humanoid then
		humanoid.WalkSpeed=defaultWalkSpeed
		humanoid.JumpPower=defaultJumpPower
		humanoid.HipHeight=defaultHipHeight
		humanoid.AutoRotate=true
	end
	tweenFov(defaultFov,0.3)
end

local function releaseRoll()
	if not isCharging then return end
	isCharging=false
	isRolling=true
	speed=BOOST_POWER
	targetSpeed=BOOST_POWER
	tweenFov(defaultFov+FOV_BOOST,0.3)
	if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
end

local function startCharge()
	if isCharging or isRolling or not humanoid then return end
	isCharging=true
	humanoid.WalkSpeed=0
	humanoid.JumpPower=0
	humanoid.AutoRotate=false
	humanoid.HipHeight=-1
	animTrack:Play()
	animTrack:AdjustSpeed(1)
	tweenFov(defaultFov+FOV_CHARGE,0.25)
	local t=tick()
	while isCharging and tick()-t<CHARGE_TIME do
		if animTrack then animTrack:AdjustSpeed(lerp(animTrack.Speed,3,0.1)) end
		task.wait(0.03)
	end
	if isCharging then releaseRoll() end
end

local function setupCharacter()
	character=player.Character or player.CharacterAdded:Wait()
	humanoid=character:WaitForChild("Humanoid")
	hrp=character:WaitForChild("HumanoidRootPart")
	local anim=Instance.new("Animation")
	anim.AnimationId=ANIM_ID
	animTrack=humanoid:LoadAnimation(anim)
	animTrack.Looped=true
	defaultWalkSpeed=humanoid.WalkSpeed
	defaultJumpPower=humanoid.JumpPower
	defaultHipHeight=0
	defaultFov=cam.FieldOfView
	humanoid.Jumping:Connect(function()
		if isRolling then targetSpeed=math.clamp(targetSpeed+JUMP_BOOST,0,MAX_SPEED) end
	end)
	stopRoll()
end

RunService.Heartbeat:Connect(function(dt)
	if not humanoid or not hrp then return end
	if isCharging or isRolling then
		local dir=getDir()
		if dir.Magnitude>0 then hrp.CFrame=CFrame.lookAt(hrp.Position,hrp.Position+dir) end
	end
	if isRolling then
		speed=lerp(speed,targetSpeed,math.clamp(dt*BOOST_ACCEL,0,1))
		local v=getDir()*speed
		hrp.AssemblyLinearVelocity=Vector3.new(v.X,hrp.AssemblyLinearVelocity.Y,v.Z)
		if animTrack then animTrack:AdjustSpeed(math.clamp(speed/20,1,3)) end
		humanoid.HipHeight=-1
		targetSpeed=math.clamp(targetSpeed*BOOST_DECAY,MIN_SPEED,MAX_SPEED)
	end
end)

local function createAbilityButton()
	local mainGui=player:WaitForChild("PlayerGui"):WaitForChild("MainGui")
	local template=mainGui.Client.Modules.Ability:WaitForChild("AbilityTemplate")
	local abilitiesFrame=mainGui.Abilities:WaitForChild("Folder")
	local btn=template:Clone()
	btn.Name=BUTTON_NAME
	btn.Icon.Image=ICON_ID
	btn.Title.Text="Roll"
	btn.Input.Text="V"
	btn.CooldownLabel.Text=""
	btn.Visible=true
	btn.Parent=abilitiesFrame
	local cooldownActive=false
	local function trigger()
		if onCooldown then return end
		if not isRolling and not isCharging then startCharge() else stopRoll() end
		onCooldown=true
		btn.CooldownLabel.Text=tostring(COOLDOWN_TIME)
		local start=tick()
		while tick()-start<COOLDOWN_TIME do
			btn.CooldownLabel.Text=string.format("%.1f",COOLDOWN_TIME-(tick()-start))
			task.wait(0.1)
		end
		btn.CooldownLabel.Text=""
		onCooldown=false
	end
	btn.MouseButton1Click:Connect(trigger)
	UserInputService.InputBegan:Connect(function(input,processed)
		if processed then return end
		if input.KeyCode==KEYBIND then trigger() end
	end)
end

player.CharacterAdded:Connect(function()
	task.wait(0.5)
	setupCharacter()
end)

setupCharacter()
createAbilityButton()
