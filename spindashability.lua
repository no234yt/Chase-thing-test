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

	-- Endlag: only used on CANCEL
	ENDLAG_DURATION        = 0.4,
	ENDLAG_HIP_RETURN_TIME = 0.3,

	-- Tired state: triggered on natural end and killer collision
	TIRED_SLOWDOWN_TIME = 0.9,
	TIRED_DURATION      = 2.2,

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

	-- ── Knockback (direct proximity — replaces old spike loop) ───────────────
	-- KNOCKBACK_FORCE:    base horizontal impulse at max rolling speed (studs/s)
	-- KNOCKBACK_UP:       vertical component of the impulse
	-- KNOCKBACK_RADIUS:   how close (studs) a target must be to receive a hit
	-- KNOCKBACK_COOLDOWN: seconds before the same target can be hit again
	KNOCKBACK_FORCE    = 75,
	KNOCKBACK_UP       = 30,
	KNOCKBACK_RADIUS   = 5,
	KNOCKBACK_COOLDOWN = 0.25,

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

	flickerCoroutine      = nil,
	cooldownCoroutine     = nil,
	rollUpdateConnection  = nil,  -- RenderStepped: jump-button + jump-height
	rollPhysicsConnection = nil,  -- Heartbeat:     speed decay + BodyVelocity drive
	knockbackConnection   = nil,  -- Heartbeat:     proximity knockback scanner

	bodyVelocity = nil,

	jumpBtn         = nil,
	jumpConnections = {},
	canJump         = true,
}

-- Per-target knockback cooldown:  model → timestamp of last hit
-- Declared at module level so stopRoll can wipe it by reassignment.
local knockedTargets = {}

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

-- ── Button text (defined early — referenced by startCooldown) ─────────────────

local function updateButtonText()
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

-- ── Cooldown ──────────────────────────────────────────────────────────────────

function startCooldown(cooldownType)
	if State.cooldownCoroutine then
		task.cancel(State.cooldownCoroutine)
		State.cooldownCoroutine = nil
	end
	State.onCooldown = true

	local cooldownText    = State.abilityButton and State.abilityButton:FindFirstChild("CooldownLabel")
	local cooldownOverlay = State.abilityButton and State.abilityButton:FindFirstChild("Cooldown")

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

-- ── Tired state — natural/collision end ──────────────────────────────────────

local function applyTiredState()
	State.isTired = true
	updateButtonText()

	local startSpeed = State.speed
	local startTime  = tick()

	task.spawn(function()
		-- Phase 1: coast to a stop
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

-- ── Knockback — direct proximity (THE FIX) ────────────────────────────────────
--
--  OLD APPROACH (removed):
--    Every frame: spike hrp.Velocity × 12.5, wait a RenderStepped, restore.
--    Problems: the BodyVelocity constraint fights the spike immediately; the
--    spike window is too short for the physics engine to register a collision
--    impulse; .Velocity is deprecated and behaves inconsistently.
--
--  NEW APPROACH:
--    A Heartbeat scanner (started with the roll, stopped on stopRoll) checks
--    every model within KNOCKBACK_RADIUS studs and calls AssemblyLinearVelocity
--    directly on their HumanoidRootPart.  A per-model timestamp prevents
--    rapid-fire re-hits on the same target (KNOCKBACK_COOLDOWN seconds).
--
--    Force is proportional to current rolling speed so a full-charge roll
--    hits harder than a half-charge one.
--

local function applyDirectKnockback(targetHRP)
	if not targetHRP or not State.hrp then return end

	local model = targetHRP.Parent
	local now   = tick()

	-- Respect per-target cooldown
	if knockedTargets[model] and now - knockedTargets[model] < CONFIG.KNOCKBACK_COOLDOWN then
		return
	end
	knockedTargets[model] = now

	-- Direction: flat vector from us toward the target
	local diff = targetHRP.Position - State.hrp.Position
	local flat = Vector3.new(diff.X, 0, diff.Z)
	if flat.Magnitude < 0.01 then
		flat = getDirection()   -- fallback: push in our travel direction
	end
	flat = flat.Unit

	-- Scale with rolling speed (0 → MIN_BOOST_POWER  ..  1 → MAX_BOOST_POWER)
	local speedFactor = math.clamp(
		(State.speed - CONFIG.MIN_BOOST_POWER) / (CONFIG.MAX_BOOST_POWER - CONFIG.MIN_BOOST_POWER),
		0, 1
	)
	local force = lerp(CONFIG.KNOCKBACK_FORCE * 0.5, CONFIG.KNOCKBACK_FORCE, speedFactor)

	targetHRP.AssemblyLinearVelocity = Vector3.new(
		flat.X * force,
		CONFIG.KNOCKBACK_UP,
		flat.Z * force
	)
end

-- ── Bounce away from killer ───────────────────────────────────────────────────

local function bounceAwayFrom(killerHRP)
	if not State.hrp or not State.humanoid then return end

	local diff = State.hrp.Position - killerHRP.Position
	local flat = Vector3.new(diff.X, 0, diff.Z)
	if flat.Magnitude < 0.1 then
		flat = -getDirection()
	end
	flat = flat.Unit

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

	-- ── Knockback cleanup ─────────────────────────────────────────────────────
	knockedTargets = {}   -- reset per-target cooldown table

	if State.knockbackConnection then
		State.knockbackConnection:Disconnect()
		State.knockbackConnection = nil
	end

	-- ── Physics cleanup ───────────────────────────────────────────────────────
	if State.rollPhysicsConnection then
		State.rollPhysicsConnection:Disconnect()
		State.rollPhysicsConnection = nil
	end

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
		destroyBodyVelocity()
		applyTiredState()

	elseif endType == "collision" then
		-- bounceAwayFrom already destroyed BV; just apply tired on top
		applyTiredState()

	elseif endType == "cancel" then
		destroyBodyVelocity()
		applyEndlag()

	else -- "reset" / fallback
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

	local boostPower   = calculateBoostPower(State.chargePercent)
	State.rollDuration = calculateDuration(State.chargePercent)
	State.speed        = boostPower
	State.targetSpeed  = boostPower

	createBodyVelocity()

	-- ── Jump button / jump-height (RenderStepped) ─────────────────────────────
	State.rollUpdateConnection = RunService.RenderStepped:Connect(function()
		if not State.isRolling then return end
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
	end)

	-- ── Roll physics: speed decay + BodyVelocity drive (Heartbeat) ────────────
	State.rollPhysicsConnection = RunService.Heartbeat:Connect(function()
		if not State.isRolling then return end

		local elapsed = tick() - State.rollStartTime
		local t       = math.clamp(elapsed / State.rollDuration, 0, 1)

		-- Smooth quadratic decay from targetSpeed → MIN_SPEED
		State.speed = lerp(State.targetSpeed, CONFIG.MIN_SPEED, t * t)

		-- Drive BodyVelocity along the camera's flat forward direction
		if State.bodyVelocity then
			State.bodyVelocity.Velocity = getDirection() * State.speed
		end

		-- Crouching: lower hip height as we go
		if State.humanoid then
			State.humanoid.HipHeight = lerp(
				State.defaultHipHeight, -1,
				math.clamp(elapsed / 0.25, 0, 1)
			)
		end

		-- Natural duration end
		if elapsed >= State.rollDuration then
			stopRoll("complete")
			startCooldown("complete")
		end
	end)

	-- ── Proximity knockback scanner (Heartbeat) ────────────────────────────────
	--  Checks ALL nearby models every physics step and pushes them away.
	--  applyDirectKnockback handles per-target cooldowns internally.
	State.knockbackConnection = RunService.Heartbeat:Connect(function()
		if not State.isRolling or not State.hrp then return end

		local myPos = State.hrp.Position

		for _, model in ipairs(workspace:GetChildren()) do
			if model:IsA("Model") and model ~= State.character then
				local targetHRP = model:FindFirstChild("HumanoidRootPart")
				if targetHRP then
					local dist = (targetHRP.Position - myPos).Magnitude
					if dist <= CONFIG.KNOCKBACK_RADIUS then
						applyDirectKnockback(targetHRP)
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
			task.wait()
		end
	end)
end

-- ── Start charging ────────────────────────────────────────────────────────────

local function startCharge()
	if State.onCooldown or State.isRolling or State.isCharging
		or State.isEndlag or State.isTired then
		return
	end
	if not State.character or not State.humanoid or not State.hrp then return end

	State.isCharging      = true
	State.chargePercent   = 0
	State.chargeStartTime = tick()

	State.humanoid.AutoRotate = false
	State.humanoid.WalkSpeed  = 0
	State.humanoid.JumpPower  = 0

	if State.animTrack then State.animTrack:Play() end

	createHighlight()
	updateFOV()
	flickerHighlight()
	updateButtonText()

	if State.spinSound then State.spinSound:Play() end

	-- Charge progress loop
	task.spawn(function()
		while State.isCharging do
			local elapsed = tick() - State.chargeStartTime
			State.chargePercent = math.clamp(elapsed / CONFIG.MAX_CHARGE_TIME, 0, 1)
			updateButtonText()
			task.wait()
		end
	end)
end

-- ── Sound setup ───────────────────────────────────────────────────────────────

local function setupSounds()
	-- Destroy old instances so we don't stack them on respawn
	for _, key in ipairs({"spinSound","jumpSound","flickerSound","cancelSound"}) do
		if State[key] then
			State[key]:Destroy()
			State[key] = nil
		end
	end

	local soundRoot = State.hrp or workspace

	local function makeSound(url, volume)
		local filename = url:match("[^/]+$")
		local s = Instance.new("Sound")
		s.SoundId             = ensureFile(filename, url)
		s.Volume              = volume or 1
		s.RollOffMaxDistance  = 0
		s.Parent              = soundRoot
		return s
	end

	State.spinSound    = makeSound(CONFIG.SPINDASH_SOUND, 1)
	State.jumpSound    = makeSound(CONFIG.JUMP_SOUND,     1)
	State.flickerSound = makeSound(CONFIG.FLICKER_SOUND,  0.7)
	State.cancelSound  = makeSound(CONFIG.CANCEL_SOUND,   1)
end

-- ── Character setup ───────────────────────────────────────────────────────────

local function setupCharacter(character)
	-- Disconnect any lingering connections from before respawn
	if State.rollUpdateConnection  then State.rollUpdateConnection:Disconnect()  end
	if State.rollPhysicsConnection then State.rollPhysicsConnection:Disconnect() end
	if State.knockbackConnection   then State.knockbackConnection:Disconnect()   end
	destroyBodyVelocity()
	knockedTargets = {}

	State.character = character
	State.humanoid  = character:WaitForChild("Humanoid")
	State.hrp       = character:WaitForChild("HumanoidRootPart")

	State.defaultWalkSpeed = State.humanoid.WalkSpeed
	State.defaultJumpPower = State.humanoid.JumpPower
	State.defaultHipHeight = State.humanoid.HipHeight
	State.defaultFov       = cam.FieldOfView

	-- Load spin animation
	local anim = Instance.new("Animation")
	anim.AnimationId = CONFIG.ANIM_ID
	State.animTrack  = State.humanoid.Animator:LoadAnimation(anim)
	State.animTrack.Priority = Enum.AnimationPriority.Action
	State.animTrack.Looped   = true

	setupSounds()

	-- Reset volatile state
	State.isCharging  = false
	State.isRolling   = false
	State.isEndlag    = false
	State.isTired     = false
	State.onCooldown  = false
	State.speed       = 0
	State.targetSpeed = 0
end

-- ── Input handling ────────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= CONFIG.KEYBIND then return end

	if State.isRolling then
		if State.cancelSound then State.cancelSound:Play() end
		stopRoll("cancel")
		startCooldown("cancel")
	else
		startCharge()
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode ~= CONFIG.KEYBIND then return end
	if State.isCharging then
		startRoll()
	end
end)

-- ── GUI setup ─────────────────────────────────────────────────────────────────

local function setupGui()
	local old = playerGui:FindFirstChild("SpindashGui")
	if old then old:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name            = "SpindashGui"
	screenGui.ResetOnSpawn    = false
	screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
	screenGui.Parent          = playerGui

	local btn = Instance.new("ImageButton")
	btn.Name             = CONFIG.BUTTON_NAME
	btn.Size             = UDim2.new(0, 80, 0, 80)
	btn.Position         = UDim2.new(1, -100, 1, -180)
	btn.AnchorPoint      = Vector2.new(0.5, 0.5)
	btn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	btn.BorderSizePixel  = 0
	btn.Image            = ensureFile(CONFIG.ICON_FILE, CONFIG.ICON_URL)
	btn.Parent           = screenGui
	State.abilityButton  = btn

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent       = btn

	-- Label showing current state
	local title = Instance.new("TextLabel")
	title.Name                   = "Title"
	title.Size                   = UDim2.new(1, 0, 0.45, 0)
	title.Position               = UDim2.new(0, 0, 0.55, 0)
	title.BackgroundTransparency = 1
	title.Text                   = "Spindash (Hold)"
	title.TextColor3             = Color3.fromRGB(255, 255, 255)
	title.TextScaled             = true
	title.Font                   = Enum.Font.GothamBold
	title.Parent                 = btn

	-- Cooldown darkening overlay
	local overlay = Instance.new("Frame")
	overlay.Name                   = "Cooldown"
	overlay.Size                   = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3       = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.Visible                = false
	overlay.ZIndex                 = 2
	overlay.Parent                 = btn

	local oCorner = Instance.new("UICorner")
	oCorner.CornerRadius = UDim.new(0, 14)
	oCorner.Parent       = overlay

	-- Countdown label inside overlay
	local cdLabel = Instance.new("TextLabel")
	cdLabel.Name                   = "CooldownLabel"
	cdLabel.Size                   = UDim2.new(1, 0, 1, 0)
	cdLabel.BackgroundTransparency = 1
	cdLabel.Text                   = ""
	cdLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
	cdLabel.TextScaled             = true
	cdLabel.Font                   = Enum.Font.GothamBold
	cdLabel.Visible                = false
	cdLabel.ZIndex                 = 3
	cdLabel.Parent                 = overlay

	-- Mobile: hold to charge, release to launch, tap during roll to cancel
	local holdActive = false

	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			if State.isRolling then
				if State.cancelSound then State.cancelSound:Play() end
				stopRoll("cancel")
				startCooldown("cancel")
			else
				holdActive = true
				startCharge()
			end
		end
	end)

	btn.InputEnded:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1)
			and holdActive
		then
			holdActive = false
			if State.isCharging then
				startRoll()
			end
		end
	end)
end

-- ── Initialization ────────────────────────────────────────────────────────────

setupGui()

local character = player.Character or player.CharacterAdded:Wait()
setupCharacter(character)

player.CharacterAdded:Connect(function(newCharacter)
	task.wait()  -- let the character finish loading
	setupCharacter(newCharacter)
end)
