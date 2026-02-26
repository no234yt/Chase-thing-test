local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

-- Configuration
local CONFIG = {
	ANIM_ID = "rbxassetid://18752189666",
	
	-- Charge settings
	MAX_CHARGE_TIME = 2.5, -- Maximum charge time in seconds
	MIN_CHARGE_TIME = 1, -- Minimum charge for activation
	
	-- Speed settings
	MIN_BOOST_POWER = 60, 
	MAX_BOOST_POWER = 120, 
	BOOST_ACCEL = 6,
	BOOST_DECAY = 0.15,
	MIN_SPEED = 45,
	JUMP_BOOST = 35,
	
	-- Duration settings
	BASE_DURATION = 6, -- Base duration in seconds
	MAX_DURATION = 10, -- Maximum duration at full charge
	
	-- Visual settings
	FOV_CHARGE = 10,
	FOV_BOOST = 5,
	
	-- Controls
	KEYBIND = Enum.KeyCode.V,
	COOLDOWN_TIME = 45,
	
	-- Assets
	SPINDASH_SOUND = "https://github.com/no234yt/Chase-thing-test/raw/1ce62c4d812569e2355f209a7da46a7e9c284b51/sonic-spindash.mp3",
	JUMP_SOUND = "https://github.com/no234yt/Chase-thing-test/raw/1ce62c4d812569e2355f209a7da46a7e9c284b51/jump.mp3",
	ICON_URL = "https://raw.githubusercontent.com/no234yt/Chase-thing-test/c49e870a8db6d450d0af4c5f51c2ad6401a8be6c/Tak%20berjudul50_20251021221343.png",
	ICON_FILE = "spindash_icon.png",
	
	BUTTON_NAME = "Spindash"
}

-- State variables
local State = {
	character = nil,
	humanoid = nil,
	hrp = nil,
	animTrack = nil,
	spinSound = nil,
	jumpSound = nil,
	highlight = nil,
	abilityButton = nil,
	
	isCharging = false,
	isRolling = false,
	onCooldown = false,
	
	chargePercent = 0, -- 0 to 1
	chargeStartTime = 0,
	rollStartTime = 0,
	rollDuration = 0,
	
	speed = 0,
	targetSpeed = 0,
	
	defaultWalkSpeed = 16,
	defaultJumpPower = 50,
	defaultHipHeight = 0,
	defaultFov = 70
}

-- Utility functions
local function lerp(a, b, t)
	return a + (b - a) * t
end

local function getDirection()
	local lookVector = cam.CFrame.LookVector
	return Vector3.new(lookVector.X, 0, lookVector.Z).Unit
end

local function ensureFile(filename, url)
	if not isfile(filename) then
		writefile(filename, game:HttpGet(url))
	end
	return getcustomasset(filename)
end

local function calculateBoostPower(chargePercent)
	return lerp(CONFIG.MIN_BOOST_POWER, CONFIG.MAX_BOOST_POWER, chargePercent)
end

local function calculateDuration(chargePercent)
	return lerp(CONFIG.BASE_DURATION, CONFIG.MAX_DURATION, chargePercent)
end

-- Highlight effects
local function removeHighlight()
	if State.highlight then
		State.highlight:Destroy()
		State.highlight = nil
	end
end

local function createHighlight()
	removeHighlight()
	State.highlight = Instance.new("Highlight")
	State.highlight.Parent = State.character
	State.highlight.FillColor = Color3.fromRGB(255, 100, 100)
	State.highlight.OutlineColor = Color3.new(1, 1, 1)
	State.highlight.FillTransparency = 0.5
	State.highlight.OutlineTransparency = 0
end

local function flashHighlight()
	if not State.highlight then return end
	
	task.spawn(function()
		while State.isCharging and State.highlight do
			State.highlight.Enabled = not State.highlight.Enabled
			-- Flash faster as charge increases
			local flashSpeed = lerp(0.15, 0.05, State.chargePercent)
			task.wait(flashSpeed)
		end
		if State.highlight then
			State.highlight.Enabled = true
		end
	end)
end

-- FOV management
local function updateFOV()
	task.spawn(function()
		while State.isCharging or State.isRolling do
			if State.isCharging then
				local fovBoost = lerp(0, CONFIG.FOV_CHARGE, State.chargePercent)
				cam.FieldOfView = State.defaultFov + fovBoost
			elseif State.isRolling then
				cam.FieldOfView = State.defaultFov + CONFIG.FOV_BOOST
			end
			task.wait(0.016)
		end
		cam.FieldOfView = State.defaultFov
	end)
end

-- Button text management
local function updateButtonText()
	if not State.abilityButton then return end
	
	local titleLabel = State.abilityButton:FindFirstChild("Title")
	if not titleLabel then return end
	
	if State.isRolling then
		titleLabel.Text = "Cancel"
		titleLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	elseif State.isCharging then
		local chargePercentDisplay = math.floor(State.chargePercent * 100)
		titleLabel.Text = string.format("Roll [%d%%]", chargePercentDisplay)
		titleLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	else
		titleLabel.Text = "Charge (Hold)"
		titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

-- Core ability functions
local function stopRoll()
	State.isCharging = false
	State.isRolling = false
	State.speed = 0
	State.targetSpeed = 0
	State.chargePercent = 0
	
	if State.animTrack then
		State.animTrack:Stop()
	end
	
	if State.humanoid then
		State.humanoid.WalkSpeed = State.defaultWalkSpeed
		State.humanoid.JumpPower = State.defaultJumpPower
		State.humanoid.HipHeight = State.defaultHipHeight
		State.humanoid.AutoRotate = true
	end
	
	removeHighlight()
	cam.FieldOfView = State.defaultFov
	updateButtonText()
end

local function startRoll()
	if State.chargePercent < (CONFIG.MIN_CHARGE_TIME / CONFIG.MAX_CHARGE_TIME) then
		-- Not enough charge
		stopRoll()
		return
	end
	
	State.isCharging = false
	State.isRolling = true
	State.rollStartTime = tick()
	
	-- Calculate power and duration based on charge
	local boostPower = calculateBoostPower(State.chargePercent)
	State.rollDuration = calculateDuration(State.chargePercent)
	State.speed = boostPower
	State.targetSpeed = boostPower
	
	if State.spinSound then
		State.spinSound:Play()
	end
	
	updateFOV()
	updateButtonText()
	
	if State.humanoid then
		State.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
	
	-- Killer collision detection
	task.spawn(function()
		while State.isRolling do
			for _, v in pairs(workspace:GetChildren()) do
				if v:IsA("Model") and 
				   ReplicatedStorage.GameAssets.Teams.Killer:FindFirstChild(v.Name) and 
				   v:FindFirstChild("HumanoidRootPart") then
					local distance = (v.HumanoidRootPart.Position - State.hrp.Position).Magnitude
					if distance < 6 then
						stopRoll()
						break
					end
				end
			end
			task.wait(0.05)
		end
	end)
	
	-- Duration timer
	task.spawn(function()
		while State.isRolling do
			local elapsed = tick() - State.rollStartTime
			if elapsed >= State.rollDuration then
				stopRoll()
				break
			end
			task.wait(0.1)
		end
	end)
end

local function startCharge()
	if State.isCharging or State.isRolling or not State.humanoid or State.onCooldown then
		return
	end
	
	State.isCharging = true
	State.chargeStartTime = tick()
	State.chargePercent = 0
	
	State.humanoid.WalkSpeed = 0
	State.humanoid.JumpPower = 0
	State.humanoid.AutoRotate = false
	State.humanoid.HipHeight = -1
	
	State.animTrack:Play()
	State.animTrack:AdjustSpeed(1)
	
	createHighlight()
	flashHighlight()
	updateFOV()
	updateButtonText()
	
	-- Charge loop
	task.spawn(function()
		while State.isCharging do
			local elapsed = tick() - State.chargeStartTime
			State.chargePercent = math.clamp(elapsed / CONFIG.MAX_CHARGE_TIME, 0, 1)
			
			-- Speed up animation as charge increases
			if State.animTrack then
				local animSpeed = lerp(1, 3, State.chargePercent)
				State.animTrack:AdjustSpeed(animSpeed)
			end
			
			updateButtonText()
			task.wait(0.03)
		end
	end)
end

local function releaseCharge()
	if State.isCharging then
		startRoll()
	end
end

local function cancelRoll()
	if State.isRolling then
		stopRoll()
	end
end

local function triggerAbility()
	if State.onCooldown then return end
	
	if State.isRolling then
		-- Cancel if rolling
		cancelRoll()
		startCooldown()
	elseif State.isCharging then
		-- Release charge if charging
		releaseCharge()
	else
		-- Start charging
		startCharge()
	end
end

local function onInputBegan(input, processed)
	if processed then return end
	if input.KeyCode ~= CONFIG.KEYBIND then return end
	
	if not State.isCharging and not State.isRolling then
		startCharge()
	end
end

local function onInputEnded(input, processed)
	if processed then return end
	if input.KeyCode ~= CONFIG.KEYBIND then return end
	
	if State.isCharging then
		releaseCharge()
		startCooldown()
	elseif State.isRolling then
		cancelRoll()
		startCooldown()
	end
end

function startCooldown()
	State.onCooldown = true
	
	local cooldownText = State.abilityButton:FindFirstChild("CooldownLabel")
	local cooldownOverlay = State.abilityButton:FindFirstChild("Cooldown")
	
	if cooldownText then cooldownText.Visible = true end
	if cooldownOverlay then cooldownOverlay.Visible = true end
	
	local startTime = tick()
	task.spawn(function()
		while tick() - startTime < CONFIG.COOLDOWN_TIME do
			if cooldownText then
				cooldownText.Text = string.format("%.1f", CONFIG.COOLDOWN_TIME - (tick() - startTime))
			end
			task.wait(0.05)
		end
		
		if cooldownText then cooldownText.Visible = false end
		if cooldownOverlay then cooldownOverlay.Visible = false end
		State.onCooldown = false
		updateButtonText()
	end)
end

-- Sound setup
local function setupSounds()
	if not State.hrp then return end
	
	-- Spindash sound
	if not isfile("spindash.mp3") then
		writefile("spindash.mp3", game:HttpGet(CONFIG.SPINDASH_SOUND))
	end
	
	State.spinSound = State.hrp:FindFirstChild("SpindashSound") or Instance.new("Sound")
	State.spinSound.Name = "SpindashSound"
	State.spinSound.SoundId = getcustomasset("spindash.mp3")
	State.spinSound.Volume = 1
	State.spinSound.Parent = State.hrp
	
	-- Jump sound
	if not isfile("jump.mp3") then
		writefile("jump.mp3", game:HttpGet(CONFIG.JUMP_SOUND))
	end
	
	State.jumpSound = State.hrp:FindFirstChild("JumpSound") or Instance.new("Sound")
	State.jumpSound.Name = "JumpSound"
	State.jumpSound.SoundId = getcustomasset("jump.mp3")
	State.jumpSound.Volume = 0.9
	State.jumpSound.Parent = State.hrp
end

-- Character setup
local function setupCharacter()
	State.character = player.Character or player.CharacterAdded:Wait()
	State.humanoid = State.character:WaitForChild("Humanoid")
	State.hrp = State.character:WaitForChild("HumanoidRootPart")
	
	local anim = Instance.new("Animation")
	anim.AnimationId = CONFIG.ANIM_ID
	State.animTrack = State.humanoid:LoadAnimation(anim)
	State.animTrack.Looped = true
	
	setupSounds()
	
	State.defaultWalkSpeed = State.humanoid.WalkSpeed
	State.defaultJumpPower = State.humanoid.JumpPower
	State.defaultHipHeight = 0
	State.defaultFov = cam.FieldOfView
	
	-- Jump boost
	State.humanoid.Jumping:Connect(function()
		if State.isRolling then
			State.targetSpeed = math.clamp(State.targetSpeed + CONFIG.JUMP_BOOST, 0, CONFIG.MAX_BOOST_POWER)
			if State.jumpSound then
				State.jumpSound:Play()
			end
		end
	end)
	
	stopRoll()
end

-- Movement update
RunService.Heartbeat:Connect(function(dt)
	if not State.humanoid or not State.hrp then return end
	
	-- Handle rotation
	if State.isCharging or State.isRolling then
		local direction = getDirection()
		if direction.Magnitude > 0 then
			State.hrp.CFrame = CFrame.lookAt(State.hrp.Position, State.hrp.Position + direction)
		end
	end
	
	-- Handle rolling movement
	if State.isRolling then
		State.speed = lerp(State.speed, State.targetSpeed, math.clamp(dt * CONFIG.BOOST_ACCEL, 0, 1))
		
		local velocity = getDirection() * State.speed
		State.hrp.AssemblyLinearVelocity = Vector3.new(velocity.X, State.hrp.AssemblyLinearVelocity.Y, velocity.Z)
		
		if State.animTrack then
			State.animTrack:AdjustSpeed(math.clamp(State.speed / 20, 1, 3))
		end
		
		State.humanoid.HipHeight = -1
		State.targetSpeed = math.clamp(State.targetSpeed * CONFIG.BOOST_DECAY, CONFIG.MIN_SPEED, CONFIG.MAX_BOOST_POWER)
	end
end)

-- UI setup
local function createAbilityButton()
	local mainGui = player:WaitForChild("PlayerGui"):WaitForChild("MainGui")
	local template = mainGui.Client.Modules.Ability:WaitForChild("AbilityTemplate")
	local abilitiesFrame = mainGui.Abilities:WaitForChild("Folder")
	
	local btn = template:Clone()
	btn.Name = CONFIG.BUTTON_NAME
	btn.Icon.Image = ensureFile(CONFIG.ICON_FILE, CONFIG.ICON_URL)
	btn.Title.Text = "Charge (Hold)"
	btn.Input.Text = "V"
	btn.Visible = true
	btn.Parent = abilitiesFrame
	
	State.abilityButton = btn
	
	-- Button click handler
	btn.MouseButton1Click:Connect(triggerAbility)
	
	return btn
end

-- Initialize
setupCharacter()
createAbilityButton()

-- Input handlers
UserInputService.InputBegan:Connect(onInputBegan)
UserInputService.InputEnded:Connect(onInputEnded)

-- Character respawn handler
player.CharacterAdded:Connect(function()
	task.wait(0.5)
	setupCharacter()
end)

print("Enhanced Spindash System loaded!")
