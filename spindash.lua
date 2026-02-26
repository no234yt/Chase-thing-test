local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

--// SETTINGS
local ANIM_ID = "rbxassetid://18752189666"
local KEYBIND = Enum.KeyCode.V

local MAX_CHARGE_TIME = 2           -- max time you can hold
local MIN_BOOST_POWER = 60
local MAX_BOOST_POWER = 200

local MIN_DURATION = 0.8
local MAX_DURATION = 3

local COOLDOWN = 1.5

local BOOST_ACCEL = 8
local BOOST_DECAY = 0.985
local JUMP_BOOST = 25
local MAX_SPEED = 250

local FOV_CHARGE = 12
local FOV_BOOST = 8

--// VARIABLES
local character, humanoid, hrp
local animTrack

local isCharging = false
local isRolling = false
local isOnCooldown = false

local chargeStart = 0
local currentCharge = 0
local rollEndTime = 0

local speed = 0
local targetSpeed = 0

local defaultWalkSpeed
local defaultJumpPower
local defaultFov

--// GUI CREATION
local function createChargeGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpindashGui"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0,200,0,20)
	frame.Position = UDim2.new(0.5,-100,0.82,0)
	frame.BackgroundColor3 = Color3.new(0,0,0)
	frame.BorderSizePixel = 2
	frame.Visible = false
	frame.Parent = gui

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0,0,1,0)
	bar.BackgroundColor3 = Color3.new(1,1,1)
	bar.BorderSizePixel = 0
	bar.Parent = frame

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1,0,1,0)
	text.BackgroundTransparency = 1
	text.Text = "SPINDASH"
	text.TextColor3 = Color3.new(1,1,1)
	text.TextStrokeTransparency = 0
	text.Font = Enum.Font.Arcade
	text.TextScaled = true
	text.Parent = frame

	return frame, bar
end

local chargeFrame, chargeBar = createChargeGui()

--// Utility
local function lerp(a,b,t)
	return a + (b-a)*t
end

local function getMoveDirection()
	local look = cam.CFrame.LookVector
	return Vector3.new(look.X,0,look.Z).Unit
end

local function tweenFov(fov,time)
	TweenService:Create(cam,TweenInfo.new(time,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{FieldOfView=fov}):Play()
end

--// STOP
local function stopRoll()
	isRolling = false
	speed = 0
	targetSpeed = 0

	if humanoid then
		humanoid.WalkSpeed = defaultWalkSpeed
		humanoid.JumpPower = defaultJumpPower
		humanoid.AutoRotate = true
	end

	if animTrack then animTrack:Stop() end

	tweenFov(defaultFov,0.3)

	-- cooldown
	isOnCooldown = true
	task.delay(COOLDOWN,function()
		isOnCooldown = false
	end)
end

--// RELEASE
local function releaseRoll()
	isCharging = false
	isRolling = true

	chargeFrame.Visible = false

	local chargePercent = math.clamp(currentCharge / MAX_CHARGE_TIME,0,1)

	targetSpeed = lerp(MIN_BOOST_POWER,MAX_BOOST_POWER,chargePercent)
	speed = targetSpeed

	local duration = lerp(MIN_DURATION,MAX_DURATION,chargePercent)
	rollEndTime = tick() + duration

	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end

	tweenFov(defaultFov + FOV_BOOST,0.25)
end

--// START CHARGE
local function startCharge()
	if isRolling or isCharging or isOnCooldown then return end

	isCharging = true
	chargeStart = tick()
	currentCharge = 0

	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
	end

	animTrack:Play()
	chargeFrame.Visible = true

	tweenFov(defaultFov + FOV_CHARGE,0.2)
end

--// UPDATE LOOP
RunService.Heartbeat:Connect(function(dt)
	if not humanoid or not hrp then return end

	-- Charging logic
	if isCharging then
		currentCharge = math.clamp(tick() - chargeStart,0,MAX_CHARGE_TIME)

		local percent = currentCharge / MAX_CHARGE_TIME
		chargeBar.Size = UDim2.new(percent,0,1,0)

		animTrack:AdjustSpeed(1 + percent*3)

		-- Auto release at max
		if currentCharge >= MAX_CHARGE_TIME then
			releaseRoll()
		end
	end

	-- Rolling logic
	if isRolling then
		if tick() >= rollEndTime then
			stopRoll()
			return
		end

		local dir = getMoveDirection()
		local camLook = dir

		if camLook.Magnitude > 0 then
			hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + camLook)
		end

		speed = lerp(speed,targetSpeed,math.clamp(dt*BOOST_ACCEL,0,1))

		hrp.AssemblyLinearVelocity = Vector3.new(
			dir.X * speed,
			hrp.AssemblyLinearVelocity.Y,
			dir.Z * speed
		)

		targetSpeed = math.clamp(targetSpeed * BOOST_DECAY,0,MAX_SPEED)

		animTrack:AdjustSpeed(math.clamp(speed/30,1,4))
	end
end)

--// INPUT
UserInputService.InputBegan:Connect(function(input,processed)
	if processed then return end
	if input.KeyCode == KEYBIND then
		startCharge()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == KEYBIND then
		if isCharging then
			releaseRoll()
		end
	end
end)

--// CHARACTER SETUP
local function setupCharacter()
	character = player.Character or player.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")
	hrp = character:WaitForChild("HumanoidRootPart")

	local anim = Instance.new("Animation")
	anim.AnimationId = ANIM_ID
	animTrack = humanoid:LoadAnimation(anim)
	animTrack.Looped = true

	defaultWalkSpeed = humanoid.WalkSpeed
	defaultJumpPower = humanoid.JumpPower
	defaultFov = cam.FieldOfView
end

player.CharacterAdded:Connect(function()
	task.wait(0.3)
	setupCharacter()
end)

setupCharacter()
