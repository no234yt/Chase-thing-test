local EMOTES = {
	["Rainbow Wave"] = {
		Animation = "rbxassetid://75513960644342",
		SongURL = "https://raw.githubusercontent.com/no234yt/Chase-thing-test/30769b73aefa8a64ef230b0a907b434c8f8ea821/Llitloan.ogg%20(1).mp3",
		FileName = "RainbowWave.ogg",
		Traversal = true,
		UseRobloxAsset = false
	},
	["Monster Mash"] = {
		Animation = "rbxassetid://97879766889620",
		SongURL = "https://raw.githubusercontent.com/no234yt/Chase-thing-test/d27af63329decef04d44db0b4431173b5f257f9b/Monstermashing.ogg.wav",
		FileName = "MonsterMash.ogg",
		Traversal = false,
		UseRobloxAsset = false
	},
	["DanDance"] = {
		Animation = "rbxassetid://71254066167629",
		SongURL = "rbxassetid://126321480580756",
		FileName = nil,
		Traversal = false,
		UseRobloxAsset = true
	}
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("MainGui")
local gui = mainGui:WaitForChild("EmoteSelection")
local emoteFolder = gui:WaitForChild("Frame"):WaitForChild("Folder")
local mobile = mainGui:WaitForChild("Mobile")
local emoteBtn = mobile:WaitForChild("EmoteBtn")

local humanoid, animTrack, soundObj
local activeEmote = nil
local originalWalkSpeed = nil
local lastClick = 0
local speedLoopConnection = nil
local visibleConnection = nil
local overrideActive = false

local function ensureLocalSong(fileName, url)
	if not fileName or fileName == "" then return nil end
	if not isfile(fileName) then
		local ok, resp = pcall(function() return game:HttpGet(url) end)
		if not ok then return nil end
		writefile(fileName, resp)
	end
	return getcustomasset(fileName)
end

local function cleanupSoundAndAnim()
	if speedLoopConnection then speedLoopConnection:Disconnect() speedLoopConnection = nil end
	if animTrack then pcall(function() animTrack:Stop() end) animTrack = nil end
	if soundObj then pcall(function() soundObj:Stop() end) pcall(function() soundObj:Destroy() end) soundObj = nil end
end

local function startBlockingGui()
	if visibleConnection then return end
	if gui.Visible then gui.Visible = false end
	visibleConnection = gui:GetPropertyChangedSignal("Visible"):Connect(function()
		if overrideActive and gui.Visible then gui.Visible = false end
	end)
end

local function stopBlockingGui()
	if visibleConnection then visibleConnection:Disconnect() visibleConnection = nil end
end

local function setupCharacter(char)
	cleanupSoundAndAnim()
	overrideActive = false
	stopBlockingGui()
	activeEmote = nil
	originalWalkSpeed = nil
	pcall(function() humanoid = char:WaitForChild("Humanoid", 5) end)
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then setupCharacter(player.Character) end

local function stopEmote()
	if not activeEmote then return end
	cleanupSoundAndAnim()
	if humanoid and originalWalkSpeed then pcall(function() humanoid.WalkSpeed = originalWalkSpeed end) end
	originalWalkSpeed = nil
	activeEmote = nil
end

local function playEmote(name, data)
	if not humanoid then return end
	stopEmote()
	activeEmote = name
	originalWalkSpeed = humanoid.WalkSpeed or 16
	soundObj = Instance.new("Sound")
	soundObj.Name = name .. "Sound"
	soundObj.Looped = true
	soundObj.Volume = 1
	soundObj.RollOffMode = Enum.RollOffMode.InverseTapered
	soundObj.RollOffMaxDistance = 30
	if data.UseRobloxAsset then
		soundObj.SoundId = data.SongURL
	else
		local asset = ensureLocalSong(data.FileName, data.SongURL)
		if asset then soundObj.SoundId = asset else soundObj.SoundId = "" end
	end
	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then soundObj.Parent = char.HumanoidRootPart else soundObj.Parent = workspace end
	local anim = Instance.new("Animation")
	anim.AnimationId = data.Animation
	animTrack = humanoid:LoadAnimation(anim)
	animTrack.Priority = Enum.AnimationPriority.Action
	animTrack.Looped = true
	pcall(function() soundObj:Play() end)
	pcall(function() animTrack:Play() end)
	if speedLoopConnection then speedLoopConnection:Disconnect() speedLoopConnection = nil end
	speedLoopConnection = RunService.RenderStepped:Connect(function()
		if activeEmote ~= name then return end
		if not humanoid then return end
		if data.Traversal then
			pcall(function() humanoid.WalkSpeed = math.max(0, originalWalkSpeed / 2) end)
		else
			pcall(function() humanoid.WalkSpeed = 0 end)
		end
	end)
end

for emoteName, data in pairs(EMOTES) do
	local button = emoteFolder:FindFirstChild(emoteName)
	if not button then
		local dance = emoteFolder:FindFirstChild("Dance")
		if dance then
			button = dance:Clone()
			button.Name = emoteName
			button.Parent = emoteFolder
		else
			button = Instance.new("ImageButton")
			button.Name = emoteName
			button.Size = UDim2.new(0,64,0,64)
			button.Parent = emoteFolder
		end
	end
	button.MouseButton1Click:Connect(function()
		if tick() - lastClick < 0.2 then return end
		lastClick = tick()
		gui.Visible = false
		overrideActive = true
		startBlockingGui()
		if activeEmote == emoteName then
			stopEmote()
		else
			playEmote(emoteName, data)
		end
	end)
end

emoteBtn.MouseButton1Click:Connect(function()
	if tick() - lastClick < 0.2 then return end
	lastClick = tick()
	if not overrideActive then return end
	if activeEmote then
		stopEmote()
	else
		overrideActive = false
		stopBlockingGui()
	end
end)

local msg = Instance.new("Message", workspace)
msg.Text = "script made by oneshotmix !! ^^ \nalso its wip, so there might be bugs or the emotes are too little..\nenjoy!"
task.delay(1.95, function() msg:Destroy() end)
