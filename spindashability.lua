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
	BOOST_ACCEL     = 6,
	BOOST_DECAY     = 0.17,
	MIN_SPEED       = 47,
	JUMP_BOOST      = 30,

	BASE_DURATION = 5,
	MAX_DURATION  = 7,

	-- Endlag: only used on CANCEL now
	ENDLAG_DURATION        = 0.4,
	ENDLAG_HIP_RETURN_TIME = 0.3,

	-- Tired state: triggered on natural end and killer collision
	TIRED_SLOWDOWN_TIME = 0.9,  -- seconds to coast to a stop
	TIRED_DURATION      = 2.2,  -- seconds frozen after stopping

	FOV_CHARGE = 10,
	FOV_BOOST  = 5,

	FLICKER_MIN_TRANSPARENCY  = 0.35,
	FLICKER_SNAP_TRANSPARENCY = 0.5,
	FLICKER_MAX_TRANSPARENCY  = 1.0,
	FLICKER_FADE_TIME         = 0.15,

	FLICKER_BASE_PITCH = 0.8,
	FLICKER_MAX_PITCH  = 1.2,

	KEYBIND = Enum.KeyCode.V,

	COOLDOWN_COMPLETE     = 45,
	COOLDOWN_CANCEL       = 25,
	COOLDOWN_INSUFFICIENT = 10,

	JUMP_HEIGHT   = 7.2,
	JUMP_COOLDOWN = 1.5,

	KNOCKBACK_MULTIPLIER = 12.5,
	KNOCKBACK_UP         = 30,
	KNOCKBACK_MOVE       = 0.1,

	-- Bounce away when you hit a killer
	BOUNCE_SPEED = 32,
	BOUNCE_UP    = 28,

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
	isTired    = false,
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

	knockbackActive = false,

	bodyVelocity = nil,

	jumpBtn         = nil,
	jumpConnections = {},
	canJump         = true,
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function getDirection()
	local lv = cam.CFrame.LookVector
	return Vector3.new(lv.X, 0, lv.Z).Unit
end

local function ensureFile(filename, url)
	if not isfile(filename) then
		writefile(filename, game:HttpGet(url))
	end
	return getcustomasset(filename)
end

local function calculateBoostPower(cp)
	return lerp(CONFIG.MIN_BOOST_POWER, CONFIG.MAX_BOOST_POWER, cp)
end

local function calculateDuration(cp)
	return lerp(CONFIG.BASE_DURATION, CONFIG.MAX_DURATION, cp)
end

-- ── BodyVelocity ──────────────────────────────────────────────────────────────

local function createBodyVelocity()
	if State.bodyVelocity then
		State.bodyVelocity:Destroy()
		State.bodyVelocity = nil
	end
	if not State.hrp then return end
	local bv = Instance.new("BodyVelocity")
	bv.Name     = "SpindashBV"
	bv.MaxForce = Vector3.new(1e5, 0, 1e5)
	bv.Velocity = Vector3.new(0, 0, 0)
	bv.Parent   = State.hrp
	State.bodyVelocity = bv
end

local function destroyBodyVelocity()
	if State.bodyVelocity then
		State.bodyVelocity:Destroy()
		State.bodyVelocity = nil
	end
end

-- ── Jump button ───────────────────────────────────────────────────────────────

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
		mobile.Size = UDim2.new(1,0,1,0)
		mobile.BackgroundTransparency = 1
		mobile.Parent = main
	end
	local btn = Instance.new("ImageButton")
	btn.Name = "JumpBtn"
	btn.Size = UDim2.new(0,70,0,70)
	btn.Position = UDim2.new(1,-90,1,-90)
	btn.AnchorPoint = Vector2.new(1,1)
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

-- ── Cooldown ──────────────────────────────────────────────────────────────────

local function updateButtonText() end -- forward declaration

function startCooldown(cooldownType)
	if State.cooldownCoroutine then
		task.cancel(State.cooldownCoroutine)
		State.cooldownCoroutine = nil
	end
	State.onCooldown = true

	local cooldownText    = State.abilityButton:FindFirstChild("CooldownLabel")
	local cooldownOverlay = State.abilityButton:FindFirstChild("Cooldown")

	local cooldownDuration
	if     cooldownType == "complete"      then cooldownDuration = CONFIG.COOLDOWN_COMPLETE
	elseif cooldownType == "cancel"        then cooldownDuration = CONFIG.COOLDOWN_CANCEL
	elseif cooldownType == "insufficient"  then cooldownDuration = CONFIG.COOLDOWN_INSUFFICIENT
	else                                        cooldownDuration = CONFIG.COOLDOWN_COMPLETE
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

-- ── Highlight ─────────────────────────────────────────────────────────────────

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
	State.highlight.OutlineColor        = Color3.new(1,1,1)
	State.highlight.FillTransparency    = 0.5
	State.highlight.OutlineTransparency = 0
end

local function flickerHighlight()
	if not State.highlight or not State.flickerSound then return end
	if State.flickerCoroutine then task.cancel(State.flickerCoroutine) end

	State.flickerCoroutine = task.spawn(function()
		while State.isCharging and State.highlight and State.flickerSound do
			local flickerInterval = lerp(0.25, 0.08, State.chargePercent)
			local pitch           = lerp(CONFIG.FLICKER_BASE_PITCH, CONFIG.FLICKER_MAX_PITCH, State.chargePercent)

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

-- ── FOV ───────────────────────────────────────────────────────────────────────

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

-- ── Button text ───────────────────────────────────────────────────────────────

function updateButtonText()
	if not State.abilityButton then return end
	local titleLabel = State.abilityButton:FindFirstChild("Title")
	if not titleLabel then return end

	if State.isTired then
		titleLabel.Text       = "Exhausted..."
		titleLabel.TextColor3 = Color3.fromRGB(150, 150, 255)
	elseif State.isRolling then
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

-- ── Endlag — cancel only ──────────────────────────────────────────────────────

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

-- ── Tired state ───────────────────────────────────────────────────────────────
-- skipSlowdown = true  →  bounce/collision path: let physics handle deceleration
--                          naturally; don't overwrite AssemblyLinearVelocity.
-- skipSlowdown = false →  normal path: coast to a stop, then freeze.

local function applyTiredState(skipSlowdown)
	State.isTired = true
	updateButtonText()

	task.spawn(function()
		if not skipSlowdown then
			-- Phase 1: coast to a stop over TIRED_SLOWDOWN_TIME seconds
			local startSpeed = State.speed
			local startTime  = tick()

			while tick() - startTime < CONFIG.TIRED_SLOWDOWN_TIME do
				local t   = (tick() - startTime) / CONFIG.TIRED_SLOWDOWN_TIME
				local spd = lerp(startSpeed, 0, t)
				if State.hrp then
					local dir = getDirection()
					State.hrp.AssemblyLinearVelocity = Vector3.new(
						dir.X * spd,
						State.hrp.AssemblyLinearVelocity.Y,
						dir.Z * spd
					)
				end
				task.wait()
			end

			-- Full stop
			if State.hrp then
				State.hrp.AssemblyLinearVelocity =
					Vector3.new(0, State.hrp.AssemblyLinearVelocity.Y, 0)
			end
		else
			-- Bounce path: physics + friction handle deceleration naturally.
			-- We just wait the same window so the freeze timing stays consistent.
			task.wait(CONFIG.TIRED_SLOWDOWN_TIME)
		end

		-- Reset hip height (applies to both paths)
		if State.humanoid then
			State.humanoid.HipHeight = State.defaultHipHeight
		end

		-- Phase 2: frozen
		if State.humanoid then
			State.humanoid.WalkSpeed = 0
			State.humanoid.JumpPower = 0
		end

		task.wait(CONFIG.TIRED_DURATION)

		if State.humanoid then
			State.humanoid.WalkSpeed = State.defaultWalkSpeed
			State.humanoid.JumpPower = State.defaultJumpPower
		end
		State.isTired = false
		updateButtonText()
	end)
end

-- ── Knockback loop ────────────────────────────────────────────────────────────
--
--  FIXES vs original:
--  1. Use AssemblyLinearVelocity instead of the deprecated .Velocity property.
--  2. Temporarily zero the BodyVelocity MaxForce during the spike so it cannot
--     counteract the knockback impulse.  The MaxForce is restored immediately
--     after the spike frames so normal rolling movement is unaffected.
--  3. Hold the spike for TWO consecutive Stepped frames instead of one.
--     This gives the physics engine a larger window to register the collision
--     and transfer the impulse to nearby characters — the main reason knockback
--     was unreliable before.
--  4. stopKnockbackLoop() now also restores MaxForce in case the loop was
--     interrupted mid-spike.

local function startKnockbackLoop()
	State.knockbackActive = true

	task.spawn(function()
		while State.knockbackActive do
			local hrp = State.hrp
			local bv  = State.bodyVelocity
			if hrp then
				local vel = hrp.AssemblyLinearVelocity

				-- Release BodyVelocity so it doesn't fight the spike
				if bv then bv.MaxForce = Vector3.new(0, 0, 0) end

				local spikeVel = Vector3.new(
					vel.X * CONFIG.KNOCKBACK_MULTIPLIER,
					CONFIG.KNOCKBACK_UP,
					vel.Z * CONFIG.KNOCKBACK_MULTIPLIER
				)

				-- Hold spike across 2 physics steps for consistent collision detection
				hrp.AssemblyLinearVelocity = spikeVel
				RunService.Stepped:Wait()
				if hrp and hrp.Parent then
					hrp.AssemblyLinearVelocity = spikeVel
				end
				RunService.Stepped:Wait()

				-- Restore character velocity and re-enable BodyVelocity driving
				if hrp and hrp.Parent then
					hrp.AssemblyLinearVelocity = vel
				end
				if bv and bv.Parent then
					bv.MaxForce = Vector3.new(1e5, 0, 1e5)
				end
			end

			-- Brief pause between spikes so BodyVelocity can reassert movement
			RunService.Heartbeat:Wait()
			RunService.Heartbeat:Wait()
			RunService.Heartbeat:Wait()
			-- Flag checked here — always AFTER the full spike+restore cycle
		end
	end)
end

local function stopKnockbackLoop()
	State.knockbackActive = false
	-- Restore MaxForce immediately in case the loop was mid-spike when we stopped
	if State.bodyVelocity and State.bodyVelocity.Parent then
		State.bodyVelocity.MaxForce = Vector3.new(1e5, 0, 1e5)
	end
end

-- ── Bounce away from killer ───────────────────────────────────────────────────
--
--  FIX: destroyBodyVelocity() is called before setting AssemblyLinearVelocity
--  so there is nothing to counteract the bounce impulse.  The stopRoll()
--  "collision" path now passes skipSlowdown=true to applyTiredState() so the
--  slowdown loop never overwrites the bounce velocity.

local function bounceAwayFrom(killerHRP)
	if not State.hrp or not State.humanoid then return end

	local diff = State.hrp.Position - killerHRP.Position
	local flat = Vector3.new(diff.X, 0, diff.Z)
	if flat.Magnitude < 0.1 then
		flat = -getDirection()
	end
	flat = flat.Unit

	-- Destroy BodyVelocity before applying bounce so they don't fight
	destroyBodyVelocity()

	State.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	State.hrp.AssemblyLinearVelocity = Vector3.new(
		flat.X * CONFIG.BOUNCE_SPEED,
		CONFIG.BOUNCE_UP,
		flat.Z * CONFIG.BOUNCE_SPEED
	)
end

-- ── Stop roll ─────────────────────────────────────────────────────────────────

local function stopRoll(endType)
	endType = endType or "complete"

	State.isCharging    = false
	State.isRolling     = false
	State.chargePercent = 0

	stopKnockbackLoop()

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
	end

	if endType == "complete" then
		-- Natural duration end: slowdown then tired freeze
		destroyBodyVelocity()
		applyTiredState(false)

	elseif endType == "collision" then
		-- Killer hit: bounceAwayFrom already destroyed BV.
		-- Pass skipSlowdown=true so applyTiredState does NOT overwrite the
		-- bounce velocity — physics handles deceleration naturally.
		applyTiredState(true)

	elseif endType == "cancel" then
		-- Manual cancel: endlag ramp-down, NOT tired
		destroyBodyVelocity()
		applyEndlag()

	else
		-- "reset" / fallback
		destroyBodyVelocity()
		if State.humanoid then State.humanoid.HipHeight = State.defaultHipHeight end
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

	local boostPower      = calculateBoostPower(State.chargePercent)
	State.rollDuration    = calculateDuration(State.chargePercent)
	State.speed           = boostPower
	State.targetSpeed     = boostPower

	createBodyVelocity()

	-- Movement & jump-height update loop
	State.rollUpdateConnection = RunService.RenderStepped:Connect(function()
		if not State.isRolling then return end

		showJumpButton()

		-- Update movement direction and speed
		if State.bodyVelocity then
			State.speed = math.max(State.speed - CONFIG.BOOST_DECAY, CONFIG.MIN_SPEED)
			local dir = getDirection()
			State.bodyVelocity.Velocity = dir * State.speed
		end

		-- Keep jump height consistent while rolling
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
	end)

	if State.spinSound then State.spinSound:Play() end

	updateFOV()

	if State.humanoid then
		State.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end

	-- Start knockback loop from the first frame of rolling
	startKnockbackLoop()

	-- Button text ticker
	task.spawn(function()
		while State.isRolling do
			updateButtonText()
			task.wait(0.1)
		end
	end)

	-- Killer proximity: bounce away then enter tired state
	task.spawn(function()
		while State.isRolling do
			for _, v in pairs(workspace:GetChildren()) do
				if v:IsA("Model")
					and ReplicatedStorage.GameAssets.Teams.Killer:FindFirstChild(v.Name)
					and v:FindFirstChild("HumanoidRootPart")
				then
					local killerHRP = v.HumanoidRootPart
					local distance  = (killerHRP.Position - State.hrp.Position).Magnitude
					if distance < 6 then
						bounceAwayFrom(killerHRP)
						stopRoll("collision")
						startCooldown("complete")
						return
					end
				end
			end
			task.wait(0.1)
		end
	end)

	-- Natural roll duration timer
	task.delay(State.rollDuration, function()
		if State.isRolling then
			stopRoll("complete")
			startCooldown("complete")
		end
	end)
end

-- ── Start charge ──────────────────────────────────────────────────────────────

local function startCharge()
	if State.onCooldown or State.isCharging or State.isRolling
		or State.isEndlag or State.isTired then return end
	if not State.character or not State.humanoid or not State.hrp then return end

	State.isCharging    = true
	State.chargeStartTime = tick()
	State.chargePercent = 0

	if State.humanoid then
		State.humanoid.WalkSpeed = 0
		State.humanoid.HipHeight = -1
	end

	createHighlight()
	flickerHighlight()
	updateFOV()

	if State.animTrack then State.animTrack:Play() end
	if State.spinSound  then State.spinSound:Play() end

	-- Charge percentage update
	task.spawn(function()
		while State.isCharging do
			local elapsed = tick() - State.chargeStartTime
			State.chargePercent = math.min(elapsed / CONFIG.MAX_CHARGE_TIME, 1)
			updateButtonText()
			task.wait(0.05)
		end
	end)

	updateButtonText()
end

local function stopCharge()
	if not State.isCharging then return end
	startRoll()
end

-- ── Character init ────────────────────────────────────────────────────────────

local function initCharacter(character)
	-- Clean up any previous roll state
	if State.isRolling or State.isCharging then
		stopRoll("reset")
	end
	destroyBodyVelocity()
	removeHighlight()

	State.character = character
	State.humanoid  = character:WaitForChild("Humanoid")
	State.hrp       = character:WaitForChild("HumanoidRootPart")

	State.defaultWalkSpeed = State.humanoid.WalkSpeed
	State.defaultJumpPower = State.humanoid.JumpPower
	State.defaultHipHeight = State.humanoid.HipHeight
	State.defaultFov       = cam.FieldOfView

	State.isCharging    = false
	State.isRolling     = false
	State.isEndlag      = false
	State.isTired       = false
	State.knockbackActive = false
	State.speed         = 0
	State.targetSpeed   = 0
	State.canJump       = true

	-- Load animation
	local anim = Instance.new("Animation")
	anim.AnimationId = CONFIG.ANIM_ID
	State.animTrack = State.humanoid:LoadAnimation(anim)

	-- Load sounds (exploit-context custom assets)
	local function loadSound(filename, url)
		local snd = Instance.new("Sound")
		snd.Parent = State.hrp
		pcall(function()
			snd.SoundId = ensureFile(filename, url)
		end)
		return snd
	end

	State.spinSound    = loadSound("spindash_sound.mp3",  CONFIG.SPINDASH_SOUND)
	State.jumpSound    = loadSound("jump_sound.mp3",      CONFIG.JUMP_SOUND)
	State.flickerSound = loadSound("flicker_sound.mp3",   CONFIG.FLICKER_SOUND)
	State.cancelSound  = loadSound("cancel_sound.mp3",    CONFIG.CANCEL_SOUND)

	updateButtonText()
end

-- ── Input ─────────────────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == CONFIG.KEYBIND then
		startCharge()
	end
end)

UserInputService.InputEnded:Connect(function(input, _gameProcessed)
	if input.KeyCode == CONFIG.KEYBIND then
		if State.isCharging then
			stopCharge()
		elseif State.isRolling then
			stopRoll("cancel")
			startCooldown("cancel")
		end
	end
end)

-- ── Ability button wiring ─────────────────────────────────────────────────────
-- Hooks into the EXISTING button that is already in the GUI; nothing is created
-- or restyled here — only the press/release logic is connected.

local function wireAbilityButton()
	-- Walk up to the button however the GUI is structured
	local function findButton()
		for _, gui in ipairs(playerGui:GetChildren()) do
			local found = gui:FindFirstChild(CONFIG.BUTTON_NAME, true)
			if found then return found end
		end
		return nil
	end

	local btn = findButton()
	if not btn then
		-- Retry once the GUI has loaded
		task.delay(2, function()
			btn = findButton()
			if btn then
				State.abilityButton = btn
				updateButtonText()
			end
		end)
		return
	end

	State.abilityButton = btn

	-- Desktop: MouseButton1
	btn.MouseButton1Down:Connect(startCharge)
	btn.MouseButton1Up:Connect(function()
		if State.isCharging then
			stopCharge()
		elseif State.isRolling then
			stopRoll("cancel")
			startCooldown("cancel")
		end
	end)

	-- Mobile: Touch
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			startCharge()
		end
	end)
	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			if State.isCharging then
				stopCharge()
			elseif State.isRolling then
				stopRoll("cancel")
				startCooldown("cancel")
			end
		end
	end)

	updateButtonText()
end

-- ── Bootstrap ─────────────────────────────────────────────────────────────────

player.CharacterAdded:Connect(function(character)
	initCharacter(character)
end)

if player.Character then
	initCharacter(player.Character)
end

wireAbilityButton()
