-- wip
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local ANIM_ID = "rbxassetid://18752189666"
local CHARGE_TIME = 1
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
local SPINDASH_SOUND = "https://github.com/no234yt/Chase-thing-test/raw/1ce62c4d812569e2355f209a7da46a7e9c284b51/sonic-spindash.mp3"
local JUMP_SOUND = "https://github.com/no234yt/Chase-thing-test/raw/1ce62c4d812569e2355f209a7da46a7e9c284b51/jump.mp3"
local ICON_URL = "https://raw.githubusercontent.com/no234yt/Chase-thing-test/c49e870a8db6d450d0af4c5f51c2ad6401a8be6c/Tak%20berjudul50_20251021221343.png"
local ICON_FILE = "metal_spindash_icon.png"
local BUTTON_NAME = "Roll"

local character, humanoid, hrp, animTrack, spinSound, jumpSound, highlight
local isCharging, isRolling, onCooldown = false, false, false
local speed, targetSpeed = 0, 0
local defaultWalkSpeed, defaultJumpPower, defaultHipHeight, defaultFov = 16, 50, 0, cam.FieldOfView

local function lerp(a,b,t) return a+(b-a)*t end
local function getDir() local v=cam.CFrame.LookVector return Vector3.new(v.X,0,v.Z).Unit end

local function ensureFile(fname,url)
	if not isfile(fname) then writefile(fname,game:HttpGet(url)) end
	return getcustomasset(fname)
end

local function forceFovLoop()
	task.spawn(function()
		while isCharging or isRolling do
			if isCharging then cam.FieldOfView=defaultFov+FOV_CHARGE end
			if isRolling then cam.FieldOfView=defaultFov+FOV_BOOST end
			task.wait(0.016)
		end
		cam.FieldOfView=defaultFov
	end)
end

local function removeHighlight()
	if highlight then highlight:Destroy() highlight=nil end
end

local function flashHighlight()
	removeHighlight()
	highlight=Instance.new("Highlight")
	highlight.Parent=character
	highlight.FillColor=Color3.new(1,0,0)
	highlight.OutlineColor=Color3.new(1,1,1)
	highlight.FillTransparency=0.55
	task.spawn(function()
		while isCharging do
			highlight.Enabled=not highlight.Enabled
			task.wait(0.15)
		end
		removeHighlight()
	end)
end

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
	removeHighlight()
	cam.FieldOfView=defaultFov
end

local function releaseRoll()
	if not isCharging then return end
	isCharging=false
	isRolling=true
	speed=BOOST_POWER
	targetSpeed=BOOST_POWER
	if spinSound then spinSound:Play() end
	forceFovLoop()
	if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
	task.spawn(function()
		while isRolling do
			for _,v in pairs(workspace:GetChildren()) do
				if v:IsA("Model") and ReplicatedStorage.GameAssets.Teams.Killer:FindFirstChild(v.Name) and v:FindFirstChild("HumanoidRootPart") then
					if (v.HumanoidRootPart.Position-hrp.Position).Magnitude<6 then stopRoll() end
				end
			end
			task.wait(0.05)
		end
	end)
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
	flashHighlight()
	forceFovLoop()
	local t=tick()
	while isCharging and tick()-t<CHARGE_TIME do
		if animTrack then animTrack:AdjustSpeed(lerp(animTrack.Speed,3,0.1)) end
		task.wait(0.03)
	end
	if isCharging then releaseRoll() end
end

local function setupSounds()
	if hrp then
		if not isfile("spindash.mp3") then writefile("spindash.mp3",game:HttpGet(SPINDASH_SOUND)) end
		if not isfile("jump.mp3") then writefile("jump.mp3",game:HttpGet(JUMP_SOUND)) end
		spinSound=hrp:FindFirstChild("SpindashSound") or Instance.new("Sound")
		spinSound.Name="SpindashSound"
		spinSound.SoundId=getcustomasset("spindash.mp3")
		spinSound.Volume=1
		spinSound.Parent=hrp
		jumpSound=hrp:FindFirstChild("JumpSound") or Instance.new("Sound")
		jumpSound.Name="JumpSound"
		jumpSound.SoundId=getcustomasset("jump.mp3")
		jumpSound.Volume=0.9
		jumpSound.Parent=hrp
	end
end

local function setupCharacter()
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
	defaultHipHeight=0
	defaultFov=cam.FieldOfView
	humanoid.Jumping:Connect(function()
		if isRolling then
			targetSpeed=math.clamp(targetSpeed+JUMP_BOOST,0,MAX_SPEED)
			if jumpSound then jumpSound:Play() end
		end
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
	btn.Icon.Image=ensureFile(ICON_FILE,ICON_URL)
	btn.Title.Text="Roll"
	btn.Input.Text="V"
	btn.Visible=true
	btn.Parent=abilitiesFrame
	local cooldownText=btn.CooldownLabel
	local cooldownOverlay=btn.Cooldown
	local function trigger()
		if onCooldown then return end
		if not isRolling and not isCharging then startCharge() else stopRoll() end
		onCooldown=true
		cooldownText.Visible=true
		cooldownOverlay.Visible=true
		local start=tick()
		while tick()-start<COOLDOWN_TIME do
			cooldownText.Text=string.format("%.1f",COOLDOWN_TIME-(tick()-start))
			task.wait(0.05)
		end
		cooldownText.Visible=false
		cooldownOverlay.Visible=false
		onCooldown=false
	end
	btn.MouseButton1Click:Connect(trigger)
	UserInputService.InputBegan:Connect(function(input,processed)
		if processed then return end
		if input.KeyCode==KEYBIND then trigger() end
	end)
end

setupCharacter()
createAbilityButton()
