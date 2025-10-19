local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
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

local SPINDASH_SOUND = "https://github.com/no234yt/Chase-thing-test/raw/1ce62c4d812569e2355f209a7da46a7e9c284b51/sonic-spindash.mp3"
local JUMP_SOUND = "https://github.com/no234yt/Chase-thing-test/raw/1ce62c4d812569e2355f209a7da46a7e9c284b51/jump.mp3"

local character, humanoid, hrp
local animTrack
local isCharging = false
local isRolling = false
local speed = 0
local targetSpeed = 0
local defaultWalkSpeed, defaultJumpPower, defaultHipHeight, defaultFov = 16, 50, 0, cam.FieldOfView
local spinSound, jumpSound
local rollBtnConnection
local charConnection

local function lerp(a,b,t) return a+(b-a)*t end
local function tweenFov(toFov,time) TweenService:Create(cam,TweenInfo.new(time,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{FieldOfView=toFov}):Play() end
local function getMoveDirection() local v=cam.CFrame.LookVector return Vector3.new(v.X,0,v.Z).Unit end

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
	tweenFov(defaultFov,0.25)
end

local function releaseRoll()
	if not isCharging or not humanoid then return end
	isCharging=false
	isRolling=true
	speed=BOOST_POWER
	targetSpeed=BOOST_POWER
	tweenFov(defaultFov+FOV_BOOST,0.25)
	if spinSound then spinSound:Play() end
	humanoid.HipHeight=-1
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
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
	local startTime=tick()
	while isCharging and tick()-startTime<CHARGE_TIME do
		animTrack:AdjustSpeed(lerp(animTrack.Speed,3,0.1))
		task.wait(0.03)
	end
	if isCharging then releaseRoll() end
end

local function setupSounds()
	if not isfile("spindash.mp3") then writefile("spindash.mp3",game:HttpGet(SPINDASH_SOUND)) end
	if not isfile("jump.mp3") then writefile("jump.mp3",game:HttpGet(JUMP_SOUND)) end
	spinSound=hrp:FindFirstChild("SpindashSound")or Instance.new("Sound")
	spinSound.Name="SpindashSound"
	spinSound.SoundId=getcustomasset("spindash.mp3")
	spinSound.Volume=1
	spinSound.Parent=hrp
	jumpSound=hrp:FindFirstChild("JumpSound")or Instance.new("Sound")
	jumpSound.Name="JumpSound"
	jumpSound.SoundId=getcustomasset("jump.mp3")
	jumpSound.Volume=0.9
	jumpSound.Parent=hrp
end

local function setupRollButton()
	local mainGui=player:WaitForChild("PlayerGui"):WaitForChild("MainGui")
	local mobileGui=mainGui:WaitForChild("Mobile")
	local jumpBtn=mobileGui:WaitForChild("JumpBtn")
	local rollBtn=mobileGui:FindFirstChild("RollBtn")or jumpBtn:Clone()
	rollBtn.Name="RollBtn"
	rollBtn.Position=UDim2.new(0.8175,0,0.75,0)
	rollBtn.Icon.Image="rbxassetid://130774527672418"
	rollBtn.Parent=mobileGui
	if rollBtnConnection then rollBtnConnection:Disconnect() end
	rollBtnConnection=rollBtn.MouseButton1Click:Connect(function()
		if not isRolling and not isCharging then startCharge() else stopRoll() end
	end)
end

local function setupCharacter()
	if charConnection then charConnection:Disconnect() end
	character=player.Character or player.CharacterAdded:Wait()
	humanoid=character:WaitForChild("Humanoid")
	hrp=character:WaitForChild("HumanoidRootPart")
	local anim=Instance.new("Animation")
	anim.AnimationId=ANIM_ID
	animTrack=humanoid:LoadAnimation(anim)
	animTrack.Looped=true
	setupSounds()
	defaultWalkSpeed=humanoid.WalkSpeed
	defaultJumpPower=humanoid.JumpPower
	defaultHipHeight=humanoid.HipHeight or 0
	defaultFov=cam.FieldOfView
	humanoid.Jumping:Connect(function()
		if isRolling then
			targetSpeed=math.clamp(targetSpeed+JUMP_BOOST,0,MAX_SPEED)
			if jumpSound then jumpSound:Play() end
		end
	end)
	humanoid.Died:Connect(stopRoll)
	if UserInputService.TouchEnabled then setupRollButton() end
	charConnection=humanoid.Died:Connect(function()
		stopRoll()
		task.defer(function() player.CharacterAdded:Wait() setupCharacter() end)
	end)
end

RunService.Heartbeat:Connect(function(dt)
	if not humanoid or not hrp then return end
	if isCharging or isRolling then
		local f=Vector3.new(cam.CFrame.LookVector.X,0,cam.CFrame.LookVector.Z).Unit
		hrp.CFrame=CFrame.lookAt(hrp.Position,hrp.Position+f)
		humanoid.HipHeight=-1
	end
	if isRolling then
		speed=lerp(speed,targetSpeed,dt*BOOST_ACCEL)
		local dir=getMoveDirection()
		local vel=dir*speed
		hrp.AssemblyLinearVelocity=Vector3.new(vel.X,hrp.AssemblyLinearVelocity.Y,vel.Z)
		animTrack:AdjustSpeed(math.clamp(speed/20,1,3))
		targetSpeed=math.clamp(targetSpeed*BOOST_DECAY,MIN_SPEED,MAX_SPEED)
	end
end)

UserInputService.InputBegan:Connect(function(i,p)
	if p then return end
	if i.KeyCode==KEYBIND then
		if not isRolling and not isCharging then startCharge() else stopRoll() end
	end
end)

setupCharacter()
