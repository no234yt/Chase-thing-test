local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DEFAULT_JUMPPOWER = 50
local JUMP_COOLDOWN = 0.8
local canJump = true

local function findMainGui()
	return playerGui:FindFirstChild("MainGui")
end

local function ensureJumpButton()
	local main = findMainGui()
	if not main then return nil end
	local btn = main:FindFirstChild("JumpBtn")
	if not btn then
		btn = Instance.new("ImageButton")
		btn.Name = "JumpBtn"
		btn.Size = UDim2.new(0, 80, 0, 80)
		btn.AnchorPoint = Vector2.new(1, 1)
		btn.Position = UDim2.new(1, -90, 1, -90)
		btn.BackgroundTransparency = 1
		btn.Image = ""
		btn.AutoButtonColor = true
		btn.Active = true
		btn.Visible = true
		btn.ZIndex = 10
		btn.Parent = main
	end
	btn.Parent = main
	btn.Visible = true
	return btn
end

local function jump()
	if not canJump then return end
	canJump = false
	local char = player.Character or player.CharacterAdded:Wait()
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.JumpPower = DEFAULT_JUMPPOWER
		hum.Jump = true
		pcall(function()
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end)
	end
	local btn = findMainGui() and findMainGui():FindFirstChild("JumpBtn")
	if btn then
		btn.ImageTransparency = 0.5
		task.delay(JUMP_COOLDOWN, function()
			btn.ImageTransparency = 0
		end)
	end
	task.delay(JUMP_COOLDOWN, function()
		canJump = true
	end)
end

local btn = ensureJumpButton()
btn.MouseButton1Click:Connect(jump)
btn.Activated:Connect(jump)
btn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		jump()
	end
end)

RunService.Heartbeat:Connect(function()
	local main = findMainGui()
	if not main then return end
	local b = main:FindFirstChild("JumpBtn")
	if not b then
		b = ensureJumpButton()
	end
	if b.Visible == false then
		b.Visible = true
	end
	b.Parent = main
end)

task.spawn(function()
	while task.wait(0.05) do
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
