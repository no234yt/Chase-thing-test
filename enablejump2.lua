local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DEFAULT_JUMPPOWER = 50
local JUMP_COOLDOWN = 0.8
local POWER_LOOP_INTERVAL = 0.1
local DASH_ANIM_ID = "rbxassetid://18331407599"
local DASH_SPEED = 100
local DASH_DURATION = 0.3

-- Keep track of roll/dash state (assumes your roll script sets these)
local isRolling = false
local humanoid, hrp
local dashAnimTrack

local function findJumpBtn()
	local main = playerGui:FindFirstChild("MainGui")
	if not main then return nil end
	local mobile = main:FindFirstChild("Mobile")
	if not mobile then return nil end
	local btn = mobile:FindFirstChild("JumpBtn")
	if btn and btn:IsA("GuiObject") then
		return btn
	end
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
	btn.Visible = true
	btn.Parent = mobile
	return btn
end

local currentBtn
local connections = {}
local canJump = true
local isDashing = false

local function disconnectAll()
	for _, c in ipairs(connections) do
		if c and typeof(c) == "RBXScriptConnection" then
			pcall(function() c:Disconnect() end)
		end
	end
	connections = {}
end

-- DASH FUNCTION
local function dashForward()
	if not humanoid or not hrp then return end
	if isDashing then return end
	isDashing = true

	-- Load animation if not loaded
	if not dashAnimTrack then
		local anim = Instance.new("Animation")
		anim.AnimationId = DASH_ANIM_ID
		dashAnimTrack = humanoid:LoadAnimation(anim)
		dashAnimTrack.Priority = Enum.AnimationPriority.Action
	end

	dashAnimTrack:Play()

	local camLook = Vector3.new(workspace.CurrentCamera.CFrame.LookVector.X, 0, workspace.CurrentCamera.CFrame.LookVector.Z)
	if camLook.Magnitude == 0 then camLook = Vector3.new(0,0,1) end
	local dashDir = camLook.Unit

	local startTime = tick()
	while tick() - startTime < DASH_DURATION do
		if hrp then
			hrp.AssemblyLinearVelocity = Vector3.new(dashDir.X * DASH_SPEED, hrp.AssemblyLinearVelocity.Y, dashDir.Z * DASH_SPEED)
		end
		task.wait()
	end

	isDashing = false
end

local function requestJump()
	if not canJump then return end
	canJump = false

	local char = player.Character or player.CharacterAdded:Wait()
	humanoid = humanoid or char:FindFirstChildOfClass("Humanoid")
	hrp = hrp or char:FindFirstChild("HumanoidRootPart")

	if humanoid then
		if isRolling and not humanoid.FloorMaterial:IsDescendantOf(workspace.Terrain) then
			-- Player is in air while rolling → dash
			dashForward()
		else
			humanoid.Jump = true
			pcall(function()
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end)
		end
	end

	if currentBtn then
		currentBtn.ImageTransparency = 0.5
		task.delay(JUMP_COOLDOWN, function()
			currentBtn.ImageTransparency = 0
		end)
	end

	task.delay(JUMP_COOLDOWN, function()
		canJump = true
	end)
end

local function bindButton(btn)
	if not btn or btn.Name ~= "JumpBtn" or btn == currentBtn then return end
	disconnectAll()
	currentBtn = btn

	table.insert(connections, btn.Activated:Connect(requestJump))
	table.insert(connections, btn.MouseButton1Click:Connect(requestJump))
	table.insert(connections, btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			requestJump()
		end
	end))
end

RunService.RenderStepped:Connect(function()
	local btn = findJumpBtn()
	if not btn then
		btn = makeBackupButton()
	end
	if btn ~= currentBtn then
		bindButton(btn)
	end
	if btn and not btn.Visible then
		btn.Visible = true
	end
	if btn.Parent == nil then
		makeBackupButton()
	end
end)

-- Restore jump power loop
task.spawn(function()
	while true do
		task.wait(POWER_LOOP_INTERVAL)
		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				if hum.UseJumpPower then
					hum.JumpPower = DEFAULT_JUMPPOWER
				else
					hum.JumpHeight = 7.2
				end
			end
		end
	end
end)
