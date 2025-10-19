local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DEFAULT_JUMPPOWER = 50
local JUMP_COOLDOWN = 0.8
local POWER_LOOP_INTERVAL = 0.1

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

local function disconnectAll()
	for _, c in ipairs(connections) do
		if c and typeof(c) == "RBXScriptConnection" then
			pcall(function() c:Disconnect() end)
		end
	end
	connections = {}
end

local function requestJump()
	if not canJump then return end
	canJump = false

	local char = player.Character or player.CharacterAdded:Wait()
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Jump = true
		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end)
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
	if not btn or btn == currentBtn then return end
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
