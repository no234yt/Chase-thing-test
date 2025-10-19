local AIR_DASH_SPEED = 80
local AIR_DASH_TIME = 0.2
local AIR_DASH_COOLDOWN = 0.5
local AIR_DASH_ANIM_ID = "rbxassetid://18331407599"
local canAirDash = true
local airDashTrack

-- Load air dash animation
local function loadAirDashAnim()
	if humanoid then
		local anim = Instance.new("Animation")
		anim.AnimationId = AIR_DASH_ANIM_ID
		airDashTrack = humanoid:LoadAnimation(anim)
	end
end

-- Air dash function
local function doAirDash()
	if not humanoid or not hrp then return end
	if not canAirDash or humanoid.FloorMaterial ~= Enum.Material.Air or isRolling then return end

	canAirDash = false
	if airDashTrack then
		airDashTrack:Play()
		airDashTrack:AdjustSpeed(1)
	end
	if jumpSound then jumpSound:Play() end

	local dashDir = getMoveDirection()
	local startTime = tick()
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if tick() - startTime > AIR_DASH_TIME then
			connection:Disconnect()
			return
		end
		-- Move player forward without affecting Y velocity
		local vel = dashDir * AIR_DASH_SPEED
		hrp.AssemblyLinearVelocity = Vector3.new(vel.X, hrp.AssemblyLinearVelocity.Y, vel.Z)
	end)

	-- Cooldown
	task.delay(AIR_DASH_COOLDOWN, function()
		canAirDash = true
	end)
end

-- Modify jump input
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == KEYBIND then
		if not isRolling and not isCharging then
			startCharge()
		else
			stopRoll()
		end
	elseif input.KeyCode == Enum.KeyCode.Space then
		doAirDash()
	end
end)

-- Also trigger on humanoid.Jumping
humanoid.Jumping:Connect(function()
	if isRolling then
		targetSpeed = math.clamp(targetSpeed + JUMP_BOOST, 0, MAX_SPEED)
		if jumpSound then jumpSound:Play() end
	else
		doAirDash()
	end
end)

-- Call this after setupCharacter()
loadAirDashAnim()
