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
    },
    ["SpookyDance"] = {
        Animation = "rbxassetid://89964848616797",
        SongURL = "https://raw.githubusercontent.com/no234yt/Chase-thing-test/1b080d2e41a0a5f9a0110266570040703f627446/Scary_Swings.mp3.mpeg.mp3",
        FileName = "SpookyDance.ogg",
        Traversal = false,
        UseRobloxAsset = false,
        AnimationSpeed = 0.5
    },
    ["GetGriddy"] = {
        Animation = "rbxassetid://106944726972070",
        SongURL = nil,
        FileName = nil,
        Traversal = true,
        FixedWalkSpeed = 7,
        UseRobloxAsset = false
    }
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("MainGui")
local gui = mainGui:WaitForChild("EmoteSelection")
local emoteFolder = gui:WaitForChild("Frame"):WaitForChild("Folder")
local emoteBtn = mainGui.Mobile:WaitForChild("EmoteBtn")
local selectedLabel = gui.Frame:WaitForChild("Selected")
local titleLabel = gui:WaitForChild("Title")

gui.Frame.Position = UDim2.new(0.035,0,0.400641024,0)
selectedLabel.Size = UDim2.new(0.925,0,0.174679399,0)

local humanoid, animTrack, soundObj
local activeEmote = nil
local originalWalkSpeed = nil
local lastClick = 0
local speedLoopConnection = nil
local visibleConnection = nil
local overrideActive = false
local currentPage = 1

local function ensureLocalSong(fileName,url)
    if not fileName or fileName == "" then return nil end
    if not isfile(fileName) then
        local ok, resp = pcall(function() return game:HttpGet(url) end)
        if not ok then return nil end
        writefile(fileName, resp)
    end
    return getcustomasset(fileName)
end

local function cleanupSoundAndAnim()
    if speedLoopConnection then speedLoopConnection:Disconnect() speedLoopConnection=nil end
    if animTrack then pcall(function() animTrack:Stop() end) animTrack=nil end
    if soundObj then pcall(function() soundObj:Stop() end) pcall(function() soundObj:Destroy() end) soundObj=nil end
end

local function startBlockingGui()
    if visibleConnection then return end
    if gui.Visible then gui.Visible=false end
    visibleConnection = gui:GetPropertyChangedSignal("Visible"):Connect(function()
        if overrideActive and gui.Visible then gui.Visible=false end
    end)
end

local function stopBlockingGui()
    if visibleConnection then visibleConnection:Disconnect() visibleConnection=nil end
end

local function setupCharacter(char)
    cleanupSoundAndAnim()
    overrideActive=false
    stopBlockingGui()
    activeEmote=nil
    originalWalkSpeed=nil
    pcall(function() humanoid=char:WaitForChild("Humanoid",5) end)
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then setupCharacter(player.Character) end

local function stopEmote()
    if not activeEmote then return end
    cleanupSoundAndAnim()
    if humanoid and originalWalkSpeed then pcall(function() humanoid.WalkSpeed=originalWalkSpeed end) end
    originalWalkSpeed=nil
    activeEmote=nil
    selectedLabel.Text=""
end

local function playEmote(name,data)
    if not humanoid then return end
    stopEmote()
    activeEmote=name
    selectedLabel.Text=name
    originalWalkSpeed=humanoid.WalkSpeed or 16

    if data.SongURL then
        soundObj=Instance.new("Sound")
        soundObj.Name=name.."Sound"
        soundObj.Looped=true
        soundObj.Volume=1
        soundObj.RollOffMode=Enum.RollOffMode.InverseTapered
        soundObj.RollOffMaxDistance=30
        if data.UseRobloxAsset then soundObj.SoundId=data.SongURL
        else
            local asset=ensureLocalSong(data.FileName,data.SongURL)
            soundObj.SoundId=asset or ""
        end
        local char=player.Character
        soundObj.Parent=char and char:FindFirstChild("HumanoidRootPart") or workspace
        pcall(function() soundObj:Play() end)
    end

    local anim=Instance.new("Animation")
    anim.AnimationId=data.Animation
    animTrack=humanoid:LoadAnimation(anim)
    animTrack.Priority=Enum.AnimationPriority.Action
    animTrack.Looped=true
    if data.AnimationSpeed then animTrack:AdjustSpeed(data.AnimationSpeed) end
    pcall(function() animTrack:Play() end)

    if speedLoopConnection then speedLoopConnection:Disconnect() speedLoopConnection=nil end
    speedLoopConnection=RunService.RenderStepped:Connect(function()
        if activeEmote~=name then return end
        if not humanoid then return end
        if data.Traversal then
            humanoid.WalkSpeed=data.FixedWalkSpeed or math.max(0,originalWalkSpeed/2)
        else
            humanoid.WalkSpeed=0
        end
    end)
end

local normalButtons={}
local customButtons={}

for _,child in pairs(emoteFolder:GetChildren()) do
    if child:IsA("GuiButton") then table.insert(normalButtons,child) end
end

for emoteName,data in pairs(EMOTES) do
    local button=normalButtons[1] and normalButtons[1]:Clone() or Instance.new("ImageButton")
    button.Name=emoteName
    button.Parent=emoteFolder

    -- Setup viewportframe animation for custom emote buttons
    local vp = button:FindFirstChildOfClass("ViewportFrame")
    if vp then
        local wm = vp:FindFirstChildOfClass("WorldModel")
        if wm then
            local rig = wm:FindFirstChild("Civilian")
            if rig and rig:FindFirstChildOfClass("Humanoid") then
                local anim = Instance.new("Animation")
                anim.AnimationId=data.Animation
                local track = rig:FindFirstChildOfClass("Humanoid"):LoadAnimation(anim)
                track.Looped=true
                if data.AnimationSpeed then track:AdjustSpeed(data.AnimationSpeed) end
                track:Play()
            end
        end
    end

    button.MouseButton1Click:Connect(function()
        if tick()-lastClick<0.2 then return end
        lastClick=tick()
        gui.Visible=false
        overrideActive=true
        startBlockingGui()
        if activeEmote==emoteName then stopEmote() else playEmote(emoteName,data) end
    end)
    table.insert(customButtons,button)
end

local page1Btn=Instance.new("TextButton")
page1Btn.Text="<"
page1Btn.Size=UDim2.new(0,30,0,30)
page1Btn.Position=UDim2.new(0,5,1,-35)
page1Btn.Font=Enum.Font.Legacy
page1Btn.BackgroundColor3=Color3.new(0,0,0)
page1Btn.BorderColor3=Color3.new(1,1,1)
page1Btn.BorderSizePixel=1.9
page1Btn.BorderMode=Enum.BorderMode.Outline
page1Btn.TextColor3=Color3.new(1,1,1)
page1Btn.TextSize=15
page1Btn.Parent=emoteFolder

local page2Btn=Instance.new("TextButton")
page2Btn.Text=">"
page2Btn.Size=UDim2.new(0,30,0,30)
page2Btn.Position=UDim2.new(1,-35,1,-35)
page2Btn.Font=Enum.Font.Legacy
page2Btn.BackgroundColor3=Color3.new(0,0,0)
page2Btn.BorderColor3=Color3.new(1,1,1)
page2Btn.BorderSizePixel=1.9
page2Btn.BorderMode=Enum.BorderMode.Outline
page2Btn.TextColor3=Color3.new(1,1,1)
page2Btn.TextSize=15
page2Btn.Parent=emoteFolder

local function updatePage(n)
    currentPage=n
    for i,btn in pairs(normalButtons) do btn.Visible=(n==1) end
    for i,btn in pairs(customButtons) do btn.Visible=(n==2) end
    titleLabel.Text=(n==1 and "Emotes [1/2]" or "Extra Emotes [2/2]")
end

page1Btn.MouseButton1Click:Connect(function() updatePage(1) end)
page2Btn.MouseButton1Click:Connect(function() updatePage(2) end)
updatePage(1)

emoteBtn.MouseButton1Click:Connect(function()
    if tick()-lastClick<0.2 then return end
    lastClick=tick()
    if not overrideActive then return end
    if activeEmote then stopEmote() else overrideActive=false stopBlockingGui() end
end)

UserInputService.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode==Enum.KeyCode.G then
        if not overrideActive then
            emoteBtn:Activate()
        else
            if activeEmote then stopEmote()
            else overrideActive=false stopBlockingGui() end
        end
    end
end)

local msg=Instance.new("Message",workspace)
msg.Text="script made by no234 !! ^^ \nalso its wip, so there might be bugs.. you can report them to no234_2 in discord !!\nenjoy!"
task.delay(1.95,function() msg:Destroy() end)
