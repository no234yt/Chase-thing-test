local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

local CONFIG = {
	ANIM_ID = "rbxassetid://18752189666",

	MAX_CHARGE_TIME = 2.5,
	MIN_CHARGE_TIME = 1.2,

	MIN_BOOST_POWER = 55,
	MAX_BOOST_POWER = 100,
	BOOST_ACCEL = 6,
	BOOST_DECAY = 0.17,
	MIN_SPEED = 47,
	JUMP_BOOST = 30,

	BASE_DURATION = 5,
	MAX_DURATION = 7,

	ENDLAG_DURATION = 0.4,
	ENDLAG_HIP_RETURN_TIME = 0.3,

	FOV_CHARGE = 10,
	FOV_BOOST = 5,

	FLICKER_MIN_TRANSPARENCY = 0.35,
	FLICKER_SNAP_TRANSPARENCY = 0.5,
	FLICKER_MAX_TRANSPARENCY = 1.0,
	FLICKER_FADE_TIME = 0.15,

	FLICKER_BASE_PITCH = 0.8,
	FLICKER_MAX_PITCH = 1.2,

	KEYBIND = Enum.KeyCode.V,

	COOLDOWN_COMPLETE = 45,
	COOLDOWN_CANCEL = 25,
	COOLDOWN_INSUFFICIENT = 10,

	JUMP_HEIGHT = 7.2,
	JUMP_COOLDOWN = 1.5,

	KNOCKBACK_RANGE = 20,
	KNOCKBACK_FORCE = 350,
	KNOCKBACK_UP    = 155,

	SPINDASH_SOUND = "https://github.com/no234yt/Chase-thing-test/raw/1ce62c4d812569e2355f209a7da46a7e9c284b51/sonic-spindash.mp3",
	JUMP_SOUND     = "https://github.com/no234yt/Chase-thing-test/raw/1ce62c4d812569e2355f209a7da46a7e9c284b51/jump.mp3",
	FLICKER_SOUND  = "https://github.com/no234yt/Chase-thing-test/raw/9dd9b9a348a440bd1a61401b4b571aafe6f11514/electronicpingshort.mp3",
	CANCEL_SOUND   = "https://github.com/no234yt/Chase-thing-test/raw/9dd9b9a348a440bd1a61401b4b571aafe6f11514/cancel.mp3",
	ICON_URL       = "https://raw.githubusercontent.com/no234yt/Chase-thing-test/c49e870a8db6d450d0af4c5f51c2ad6401a8be6c/Tak%20berjudul50_20251021221343.png",
	ICON_FILE      = "spindash_icon.png",

	BUTTON_NAME = "Spindash"
}

local State = {
	character = nil,
	humanoid  = nil,
	hrp       = nil,
	animTrack = nil,
	spinSound    = nil,
	jumpSound    = nil,
	flickerSound = nil,
	cancelSound  = nil,
	highlight    = nil,
	abilityButton = nil,

	isCharging = false,
	isRolling  = false,
	isEndlag   = false,
	onCooldown = false,

	chargePercent   = 0,
	chargeStartTime = 0,
	rollStartTime   = 0,
	rollDuration    = 0,

	speed       = 0,
	targetSpeed = 0,

	defaultWalkSpeed = 16,
	defaultJumpPower = 50,
	defaultHipHeight = 0,
	defaultFov       = 70,

	flickerCoroutine     = nil,
	cooldownCoroutine    = nil,
	rollUpdateConnection = nil,
	knockbackConnection  = nil,   -- NEW: holds the Heartbeat connection for knockback

	jumpBtn         = nil,
	jumpConnections = {},
	canJump         = true,
}

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

local function findJumpBtn()
	local main = playerGui:FindFirstChild("MainGui")
	if not main then return nil end
	local mobile = main:FindFirstChild("Mobile")
	if not mobile then return nil end
	local btn = mobile:FindFirstChild("JumpBtn")
	if btn and btn:IsA("GuiObject") then return btn end
	return nil
end

local function makeBackupButton()
	local main = playerGui:FindFirstChild("MainGui")
	if not main then
		main = Instance.new("ScreenGui")
		main.Name = "MainGui"
		main.ResetOnSpawn = false
		main.Parent = playerGui
	end
	local mobile = main:FindFirstChild("Mobile")
	if not mobile then
		mobile = Instance.new("Frame")
		mobile.Name = "Mobile"
		mobile.Size = UDim2.new(1, 0, 1, 0)
		mobile.BackgroundTransparency = 1
		mobile.Parent = main
	end
	local btn = Instance.new("ImageButton")
	btn.Name = "JumpBtn"
	btn.Size = UDim2.new(0, 70, 0, 70)
	btn.Position = UDim2.new(1, -90, 1, -90)
	btn.AnchorPoint = Vector2.new(1, 1)
	btn.BackgroundTransparency = 1
	btn.Image = ""
	btn.AutoButtonColor = true
	btn.Visible = false
	btn.Parent = mobile
	return btn
end

local function disconnectJumpConnections()
	for _, c in ipairs(State.jumpConnections) do
		if c and typeof(c) == "RBXScriptConnection" then
			pcall(function() c:Disconnect() end)
		end
	end
	State.jumpConnections = {}
end

local function requestJump()
	if not State.canJump or not State.isRolling then return end
	State.canJump = false
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Jump = true
		pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
	end
	if State.jumpBtn then
		State.jumpBtn.ImageTransparency = 0.5
		task.delay(CONFIG.JUMP_COOLDOWN, function()
			if State.jumpBtn then State.jumpBtn.ImageTransparency = 0 end
		end)
	end
	task.delay(CONFIG.JUMP_COOLDOWN, function() State.canJump = true end)
end

local function bindJumpButton(btn)
	if not btn or btn.Name ~= "JumpBtn" or btn == State.jumpBtn then return end
	disconnectJumpConnections()
	State.jumpBtn = btn
	table.insert(State.jumpConnections, btn.Activated:Connect(requestJump))
	table.insert(State.jumpConnections, btn.MouseButton1Click:Connect(requestJump))
	table.insert(State.jumpConnections, btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then requestJump() end
	end))
end

local function showJumpButton()
	local btn = findJumpBtn()
	if not btn then btn = makeBackupButton() end
	if btn ~= State.jumpBtn then bindJumpButton(btn) end
	if btn then btn.Visible = true end
end

local function hideJumpButton()
	local btn = findJumpBtn()
	if btn then btn.Visible = false end
end

function startCooldown(cooldownType)
	if State.cooldownCoroutine then
		task.cancel(State.cooldownCoroutine)
		State.cooldownCoroutine = nil
	end
	State.onCooldown = true

	local cooldownText    = State.abilityButton:FindFirstChild("CooldownLabel")
	local cooldownOverlay = State.abilityButton:FindFirstChild("Cooldown")

	local cooldownDuration
	if     cooldownType == "complete"     then cooldownDuration = CONFIG.COOLDOWN_COMPLETE
	elseif cooldownType == "cancel"       then cooldownDuration = CONFIG.COOLDOWN_CANCEL
	elseif cooldownType == "insufficient" then cooldownDuration = CONFIG.COOLDOWN_INSUFFICIENT
	else                                       cooldownDuration = CONFIG.COOLDOWN_COMPLETE
	end

	if cooldownText    then cooldownText.Visible    = true end
	if cooldownOverlay then cooldownOverlay.Visible = true end

	local startTime = tick()
	State.cooldownCoroutine = task.spawn(function()
		while tick() - startTime < cooldownDuration do
			if cooldownText then
				cooldownText.Text = string.format("%.1f", cooldownDuration - (tick() - startTime))
			end
			task.wait(0.05)
		end
		if cooldownText    then cooldownText.Visible    = false end
		if cooldownOverlay then cooldownOverlay.Visible = false end
		State.onCooldown = false
		State.cooldownCoroutine = nil
		updateButtonText()
	end)
end

local function removeHighlight()
	if State.highlight then
		State.highlight:Destroy()
		State.highlight = nil
	end
end

local function createHighlight()
	removeHighlight()
	State.highlight = Instance.new("Highlight")
	State.highlight.Parent              = State.character
	State.highlight.FillColor           = Color3.fromRGB(255, 100, 100)
	State.highlight.OutlineColor        = Color3.new(1, 1, 1)
	State.highlight.FillTransparency    = 0.5
	State.highlight.OutlineTransparency = 0
end

local function flickerHighlight()
	if not State.highlight or not State.flickerSound then return end
	if State.flickerCoroutine then task.cancel(State.flickerCoroutine) end

	State.flickerCoroutine = task.spawn(function()
		while State.isCharging and State.highlight and State.flickerSound do
			local flickerInterval = lerp(0.25, 0.08, State.chargePercent)
			local pitch            = lerp(CONFIG.FLICKER_BASE_PITCH, CONFIG.FLICKER_MAX_PITCH, State.chargePercent)

			State.highlight.FillTransparency = CONFIG.FLICKER_SNAP_TRANSPARENCY
			State.flickerSound.PlaybackSpeed = pitch
			State.flickerSound:Play()

			local fadeStartTime = tick()
			while tick() - fadeStartTime < CONFIG.FLICKER_FADE_TIME and State.isCharging do
				local fadeProgress = (tick() - fadeStartTime) / CONFIG.FLICKER_FADE_TIME
				State.highlight.FillTransparency = lerp(
					CONFIG.FLICKER_SNAP_TRANSPARENCY,
					CONFIG.FLICKER_MAX_TRANSPARENCY,
					fadeProgress
				)
				task.wait()
			end

			if State.highlight then
				State.highlight.FillTransparency = CONFIG.FLICKER_MAX_TRANSPARENCY
			end
			task.wait(math.max(0, flickerInterval - CONFIG.FLICKER_FADE_TIME))
		end

		if State.highlight then
			State.highlight.Enabled          = true
			State.highlight.FillTransparency = 0.5
		end
	end)
end

local function updateFOV()
	task.spawn(function()
		while State.isCharging or State.isRolling do
			if State.isCharging then
				cam.FieldOfView = State.defaultFov + lerp(0, CONFIG.FOV_CHARGE, State.chargePercent)
			elseif State.isRolling then
				cam.FieldOfView = State.defaultFov + CONFIG.FOV_BOOST
			end
			task.wait(0.016)
		end
		cam.FieldOfView = State.defaultFov
	end)
end

function updateButtonText()
	if not State.abilityButton then return end
	local titleLabel = State.abilityButton:FindFirstChild("Title")
	if not titleLabel then return end

	if State.isRolling then
		local remainingTime = State.rollDuration - (tick() - State.rollStartTime)
		titleLabel.Text       = string.format("Cancel [%.1fs]", math.max(0, remainingTime))
		titleLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	elseif State.isCharging then
		titleLabel.Text       = string.format("Charging... %d%%", math.floor(State.chargePercent * 100))
		titleLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	elseif State.isEndlag then
		titleLabel.Text       = "Recovering..."
		titleLabel.TextColor3 = Color3.fromRGB(200, 200, 100)
	else
		titleLabel.Text       = "Spindash (Hold)"
		titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

local function applyEndlag()
	State.isEndlag = true
	updateButtonText()

	local endlagStartSpeed = State.speed
	local endlagStartTime  = tick()

	task.spawn(function()
		while tick() - endlagStartTime < CONFIG.ENDLAG_DURATION do
			local progress = (tick() - endlagStartTime) / CONFIG.ENDLAG_DURATION
			State.speed    = lerp(endlagStartSpeed, State.defaultWalkSpeed, progress)
			local velocity = getDirection() * State.speed
			if State.hrp then
				State.hrp.AssemblyLinearVelocity =
					Vector3.new(velocity.X, State.hrp.AssemblyLinearVelocity.Y, velocity.Z)
			end
			task.wait()
		end
		State.isEndlag = false
		updateButtonText()
	end)

	task.spawn(function()
		local startHip  = -1
		local startTime = tick()
		while tick() - startTime < CONFIG.ENDLAG_HIP_RETURN_TIME and State.humanoid do
			local progress = (tick() - startTime) / CONFIG.ENDLAG_HIP_RETURN_TIME
			State.humanoid.HipHeight = lerp(startHip, State.defaultHipHeight, progress)
			task.wait()
		end
		if State.humanoid then State.humanoid.HipHeight = State.defaultHipHeight end
	end)
end

-- ── Knockback: runs every Heartbeat using .Velocity like the fling example ───
local function startKnockback()
	-- Disconnect any previous connection first
	if State.knockbackConnection then
		State.knockbackConnection:Disconnect()
		State.knockbackConnection = nil
	end

	State.knockbackConnection = RunService.Heartbeat:Connect(function()
		-- Stop and clean up the moment rolling ends
		if not State.isRolling then
			if State.knockbackConnection then
				State.knockbackConnection:Disconnect()
				State.knockbackConnection = nil
			end
			return
		end

		if not State.hrp then return end

		for _, v in ipairs(Players:GetPlayers()) do
			-- Skip self
			if v == player then continue end

			local char = v.Character
			if not char then continue end

			local targetHrp = char:FindFirstChild("HumanoidRootPart")
			if not targetHrp then continue end

			local diff = targetHrp.Position - State.hrp.Position
			local dist = diff.Magnitude

			if dist < CONFIG.KNOCKBACK_RANGE and dist > 0.1 then
				-- Flat direction away from us
				local flatDir = Vector3.new(diff.X, 0, diff.Z)
				if flatDir.Magnitude < 0.01 then continue end
				flatDir = flatDir.Unit

				-- Re-apply every Heartbeat so the engine can't cancel it out,
				-- same principle as the fling script
				local vel = targetHrp.Velocity
				targetHrp.Velocity = flatDir * CONFIG.KNOCKBACK_FORCE
					+ Vector3.new(0, CONFIG.KNOCKBACK_UP, 0)

				-- Next RenderStepped: restore base so they don't fly forever,
				-- but they've already been pushed outward
				RunService.RenderStepped:Wait()
				if targetHrp and targetHrp.Parent then
					targetHrp.Velocity = flatDir * (CONFIG.KNOCKBACK_FORCE * 0.3)
						+ Vector3.new(0, CONFIG.KNOCKBACK_UP * 0.4, 0)
				end
			end
		end
	end)
end

local function stopKnockback()
	if State.knockbackConnection then
		State.knockbackConnection:Disconnect()
		State.knockbackConnection = nil
	end
end

-- ── Stop roll ─────────────────────────────────────────────────────────────────

local function stopRoll(endType)
	endType = endType or "complete"

	State.isCharging    = false
	State.isRolling     = false
	State.chargePercent = 0

	-- Stop knockback immediately when roll ends
	stopKnockback()

	if State.rollUpdateConnection then
		State.rollUpdateConnection:Disconnect()
		State.rollUpdateConnection = nil
	end

	hideJumpButton()

	if State.flickerCoroutine then
		task.cancel(State.flickerCoroutine)
		State.flickerCoroutine = nil
	end

	if State.animTrack then State.animTrack:Stop() end

	if State.humanoid then
		State.humanoid.WalkSpeed  = State.defaultWalkSpeed
		State.humanoid.JumpPower  = State.defaultJumpPower
		State.humanoid.AutoRotate = true

		if endType == "complete" or endType == "collision" then
			applyEndlag()
		else
			State.humanoid.HipHeight = State.defaultHipHeight
			State.speed       = 0
			State.targetSpeed = 0
		end
	else
		State.speed       = 0
		State.targetSpeed = 0
	end

	removeHighlight()
	cam.FieldOfView = State.defaultFov
	updateButtonText()
end

-- ── Start roll ────────────────────────────────────────────────────────────────

local function startRoll()
	local minChargeRequired = CONFIG.MIN_CHARGE_TIME / CONFIG.MAX_CHARGE_TIME

	if State.chargePercent < minChargeRequired then
		stopRoll("cancel")
		startCooldown("insufficient")
		return
	end

	if State.flickerCoroutine then
		task.cancel(State.flickerCoroutine)
		State.flickerCoroutine = nil
	end

	State.isCharging    = false
	State.isRolling     = true
	State.rollStartTime = tick()

	local boostPower       = calculateBoostPower(State.chargePercent)
	State.rollDuration     = calculateDuration(State.chargePercent)
	State.speed            = boostPower
	State.targetSpeed      = boostPower

	-- Start knockback immediately — runs every Heartbeat for entire roll
	startKnockback()

	State.rollUpdateConnection = RunService.RenderStepped:Connect(function()
		if State.isRolling then
			showJumpButton()
			local char = player.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then
					if hum.UseJumpPower then
						hum.JumpPower = CONFIG.JUMP_HEIGHT * 50 / 7.2
					else
						hum.JumpHeight = CONFIG.JUMP_HEIGHT
					end
				end
			end
		end
	end)

	if State.spinSound then State.spinSound:Play() end

	updateFOV()

	if State.humanoid then
		State.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end

	task.spawn(function()
		while State.isRolling do
			updateButtonText()
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while State.isRolling do
			for _, v in pairs(workspace:GetChildren()) do
				if v:IsA("Model")
					and ReplicatedStorage.GameAssets.Teams.Killer:FindFirstChild(v.Name)
					and v:FindFirstChild("HumanoidRootPart")
				then
					local distance = (v.HumanoidRootPart.Position - State.hrp.Position).Magnitude
					if distance < 6 then
						stopRoll("collision")
						startCooldown("complete")
						break
					end
				end
			end
			task.wait(0.05)
		end
	end)

	task.spawn(function()
		while State.isRolling do
			local elapsed = tick() - State.rollStartTime
			if elapsed >= State.rollDuration then
				stopRoll("complete")
				startCooldown("complete")
				break
			end
			task.wait(0.1)
		end
	end)
end

-- ── Charge ────────────────────────────────────────────────────────────────────

local function startCharge()
	if State.isCharging or State.isRolling or State.isEndlag
		or not State.humanoid or State.onCooldown
	then return end

	State.isCharging      = true
	State.chargeStartTime = tick()
	State.chargePercent   = 0

	State.humanoid.WalkSpeed  = 0
	State.humanoid.JumpPower  = 0
	State.humanoid.AutoRotate = false
	State.humanoid.HipHeight  = -1

	State.animTrack:Play()
	State.animTrack:AdjustSpeed(1)

	createHighlight()
	flickerHighlight()
	updateFOV()
	updateButtonText()

	task.spawn(function()
		while State.isCharging do
			local elapsed       = tick() - State.chargeStartTime
			State.chargePercent = math.clamp(elapsed / CONFIG.MAX_CHARGE_TIME, 0, 1)

			if State.animTrack then
				State.animTrack:AdjustSpeed(lerp(1, 3, State.chargePercent))
			end

			if State.chargePercent >= 1.0 then
				startRoll()
				break
			end

			updateButtonText()
			task.wait(0.03)
		end
	end)
end

local function releaseCharge()
	if State.isCharging then startRoll() end
end

local function cancelRoll()
	if State.isRolling then
		if State.cancelSound then State.cancelSound:Play() end
		stopRoll("cancel")
		startCooldown("cancel")
	end
end

-- ── Input ─────────────────────────────────────────────────────────────────────

local function onInputBegan(input, processed)
	if processed then return end
	if input.KeyCode ~= CONFIG.KEYBIND then return end
	if not State.isCharging and not State.isRolling and not State.isEndlag then
		startCharge()
	end
end

local function onInputEnded(input, processed)
	if processed then return end
	if input.KeyCode ~= CONFIG.KEYBIND then return end
	if State.isCharging then
		releaseCharge()
	elseif State.isRolling then
		cancelRoll()
	end
end

-- ── Sounds ────────────────────────────────────────────────────────────────────

local function setupSounds()
	if not State.hrp then return end

	if not isfile("spindash.mp3") then
		writefile("spindash.mp3", game:HttpGet(CONFIG.SPINDASH_SOUND))
	end
	State.spinSound = State.hrp:FindFirstChild("SpindashSound") or Instance.new("Sound")
	State.spinSound.Name    = "SpindashSound"
	State.spinSound.SoundId = getcustomasset("spindash.mp3")
	State.spinSound.Volume  = 1.2
	State.spinSound.Parent  = State.hrp

	if not isfile("jump.mp3") then
		writefile("jump.mp3", game:HttpGet(CONFIG.JUMP_SOUND))
	end
	State.jumpSound = State.hrp:FindFirstChild("JumpSound") or Instance.new("Sound")
	State.jumpSound.Name    = "JumpSound"
	State.jumpSound.SoundId = getcustomasset("jump.mp3")
	State.jumpSound.Volume  = 1.1
	State.jumpSound.Parent  = State.hrp

	if not isfile("flicker.mp3") then
		writefile("flicker.mp3", game:HttpGet(CONFIG.FLICKER_SOUND))
	end
	State.flickerSound = State.hrp:FindFirstChild("FlickerSound") or Instance.new("Sound")
	State.flickerSound.Name    = "FlickerSound"
	State.flickerSound.SoundId = getcustomasset("flicker.mp3")
	State.flickerSound.Volume  = 1
	State.flickerSound.Parent  = State.hrp

	if not isfile("cancel.mp3") then
		writefile("cancel.mp3", game:HttpGet(CONFIG.CANCEL_SOUND))
	end
	State.cancelSound = State.hrp:FindFirstChild("CancelSound") or Instance.new("Sound")
	State.cancelSound.Name    = "CancelSound"
	State.cancelSound.SoundId = getcustomasset("cancel.mp3")
	State.cancelSound.Volume  = 2
	State.cancelSound.Parent  = State.hrp
end

-- ── Character setup ───────────────────────────────────────────────────────────

local function setupCharacter()
	State.character = player.Character or player.CharacterAdded:Wait()
	State.humanoid  = State.character:WaitForChild("Humanoid")
	State.hrp       = State.character:WaitForChild("HumanoidRootPart")

	local anim = Instance.new("Animation")
	anim.AnimationId       = CONFIG.ANIM_ID
	State.animTrack        = State.humanoid:LoadAnimation(anim)
	State.animTrack.Looped = true

	setupSounds()

	State.defaultWalkSpeed = State.humanoid.WalkSpeed
	State.defaultJumpPower = State.humanoid.JumpPower
	State.defaultHipHeight = 0
	State.defaultFov       = cam.FieldOfView

	State.humanoid.Jumping:Connect(function()
		if State.isRolling then
			State.targetSpeed = math.clamp(
				State.targetSpeed + CONFIG.JUMP_BOOST, 0, CONFIG.MAX_BOOST_POWER
			)
			if State.jumpSound then State.jumpSound:Play() end
		end
	end)

	stopRoll("cancel")
end

-- ── Heartbeat ─────────────────────────────────────────────────────────────────

RunService.Heartbeat:Connect(function(dt)
	if not State.humanoid or not State.hrp then return end

	if State.isCharging or State.isRolling then
		local direction = getDirection()
		if direction.Magnitude > 0 then
			State.hrp.CFrame = CFrame.lookAt(State.hrp.Position, State.hrp.Position + direction)
		end
	end

	if State.isRolling then
		State.speed = lerp(State.speed, State.targetSpeed,
			math.clamp(dt * CONFIG.BOOST_ACCEL, 0, 1))

		local velocity = getDirection() * State.speed
		State.hrp.AssemblyLinearVelocity =
			Vector3.new(velocity.X, State.hrp.AssemblyLinearVelocity.Y, velocity.Z)

		if State.animTrack then
			State.animTrack:AdjustSpeed(math.clamp(State.speed / 20, 1, 3))
		end

		State.humanoid.HipHeight = -1
		State.targetSpeed = math.clamp(
			State.targetSpeed * CONFIG.BOOST_DECAY,
			CONFIG.MIN_SPEED,
			CONFIG.MAX_BOOST_POWER
		)
	end
end)

-- ── Ability button ────────────────────────────────────────────────────────────

local function createAbilityButton()
	local mainGui        = player:WaitForChild("PlayerGui"):WaitForChild("MainGui")
	local template       = mainGui.Client.Modules.Ability:WaitForChild("AbilityTemplate")
	local abilitiesFrame = mainGui.Abilities:WaitForChild("Folder")

	local btn = template:Clone()
	btn.Name       = CONFIG.BUTTON_NAME
	btn.Icon.Image = ensureFile(CONFIG.ICON_FILE, CONFIG.ICON_URL)
	btn.Title.Text = "Spindash (Hold)"
	btn.Input.Text = "V"
	btn.Visible    = true
	btn.Parent     = abilitiesFrame

	State.abilityButton = btn

	btn.MouseButton1Down:Connect(function()
		if not State.isCharging and not State.isRolling
			and not State.isEndlag and not State.onCooldown
		then
			startCharge()
		end
	end)

	btn.MouseButton1Up:Connect(function()
		if State.isCharging then
			releaseCharge()
		elseif State.isRolling then
			cancelRoll()
		end
	end)

	return btn
end

-- ── Init ──────────────────────────────────────────────────────────────────────

setupCharacter()
createAbilityButton()

hideJumpButton()
UserInputService.InputBegan:Connect(onInputBegan)
UserInputService.InputEnded:Connect(onInputEnded)

player.CharacterAdded:Connect(function()
	task.wait(0.5)
	setupCharacter()
end)
