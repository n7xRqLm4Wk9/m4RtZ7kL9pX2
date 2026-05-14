local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Window = Rayfield:CreateWindow({
    Name = "[👮] tactical swat simulator (beta)",
    LoadingTitle = "Welcome!",
    LoadingSubtitle = "Loading script shortly...",
    ConfigurationSaving = { Enabled = false, FolderName = nil, FileName = "GameHub" }
})

local MovementTab = Window:CreateTab("movement", 4483362458)
local VisualsTab = Window:CreateTab("visuals", 4483362458)
local CombatTab = Window:CreateTab("combat", 4483362458)
local ObjectivesTab = Window:CreateTab("objectives", 4483362458)

local CustomWalkSpeedEnabled = false
local WalkSpeedValue = 16
local JumpEnabled = false
local JumpPowerValue = 50
local ESPEnabled = false

local AimbotEnabled = false
local AimbotFOV = 150
local AimbotSmoothness = 5
local aimbotConn = nil

local AntiDeathEnabled = false
local antiDeathTriggered = false

local function isHostile(npc)
    local state = npc:GetAttribute("State")
    local nonTargetable = {"Idle", "Surrendered", "Hesitating", "ShoutHesitation", "Stunned", "Down", "Tased"}
    for _, s in ipairs(nonTargetable) do
        if state == s then return false end
    end
    return true
end

local mt = getrawmetatable(game)
local oldNewIndex = mt.__newindex
if setreadonly then setreadonly(mt, false) end

mt.__newindex = newcclosure(function(t, k, v)
    if not checkcaller() and typeof(t) == "Instance" and t:IsA("Humanoid") then
        if k == "WalkSpeed" and CustomWalkSpeedEnabled then
            return oldNewIndex(t, k, WalkSpeedValue)
        end
        if k == "JumpPower" and JumpEnabled then
            return oldNewIndex(t, k, JumpPowerValue)
        end
    end
    return oldNewIndex(t, k, v)
end)

if setreadonly then setreadonly(mt, true) end

RunService.RenderStepped:Connect(function()
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            if CustomWalkSpeedEnabled then humanoid.WalkSpeed = WalkSpeedValue end
            if JumpEnabled then humanoid.UseJumpPower = true; humanoid.JumpPower = JumpPowerValue end
        end
    end
end)

local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "ModMenuESPFolder"
local success, result = pcall(function() return CoreGui end)
ESPFolder.Parent = (success and result) and CoreGui or player:WaitForChild("PlayerGui")
local espObjects = {}

local function createESPObjects(npc)
    if espObjects[npc] then return espObjects[npc] end
    local rootPart = npc:WaitForChild("HumanoidRootPart", 5)
    if not rootPart then return nil end
    local objects = {}

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP"; billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 100, 0, 50); billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Adornee = rootPart; billboard.Parent = ESPFolder

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0); textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.new(1, 0.2, 0.2); textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0); textLabel.TextScaled = false
    textLabel.TextSize = 14; textLabel.Font = Enum.Font.Code; textLabel.Parent = billboard

    local highlight = Instance.new("Highlight")
    highlight.Name = "ESPHighlight"; highlight.FillColor = Color3.new(1, 0, 0)
    highlight.OutlineColor = Color3.new(1, 1, 1); highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0.2; highlight.Adornee = npc; highlight.Parent = ESPFolder

    objects.Billboard = billboard; objects.TextLabel = textLabel; objects.Highlight = highlight
    espObjects[npc] = objects
    return objects
end

local function cleanESP(npc)
    if espObjects[npc] then
        espObjects[npc].Billboard:Destroy(); espObjects[npc].Highlight:Destroy()
        espObjects[npc] = nil
    end
end

local function updateESP()
    local camera = workspace.CurrentCamera; if not camera then return end
    for _, npc in ipairs(workspace:GetChildren()) do
        if npc.Name == "NPC" then
            local humanoid = npc:FindFirstChild("Humanoid")
            local rootPart = npc:FindFirstChild("HumanoidRootPart")
            local isValid = ESPEnabled and rootPart and humanoid
            if isValid then
                local objects = createESPObjects(npc)
                if objects then
                    objects.Billboard.Enabled = true; objects.Highlight.Enabled = true
                    local dist = math.floor((rootPart.Position - camera.CFrame.Position).Magnitude)
                    local state = npc:GetAttribute("State")
                    local stateName = state and tostring(state) or "Hostile"
                    if humanoid.Health <= 0 then stateName = "Dead" end
                    objects.TextLabel.Text = stateName .. "\n[" .. dist .. "m]"
                    local espColor
                    if humanoid.Health <= 0 then espColor = Color3.new(0.5, 0.5, 0.5)
                    elseif not isHostile(npc) then espColor = Color3.new(0, 1, 0)
                    elseif state == "Investigating" then espColor = Color3.new(1, 0.3, 0)
                    else espColor = Color3.new(1, 0, 0) end
                    objects.TextLabel.TextColor3 = espColor; objects.Highlight.FillColor = espColor
                end
            else
                if espObjects[npc] then
                    espObjects[npc].Billboard.Enabled = false; espObjects[npc].Highlight.Enabled = false
                end
            end
        end
    end
    for npc, objects in pairs(espObjects) do
        if typeof(npc) == "Instance" then if not npc.Parent then cleanESP(npc) end else cleanESP(npc) end
    end
end
RunService.RenderStepped:Connect(updateESP)

local function isTargetVisible(targetPart, targetModel)
    if not targetPart or not targetModel then return false end
    local origin = Camera.CFrame.Position; local direction = targetPart.Position - origin
    if direction.Magnitude == 0 then return false end
    local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {player.Character or {}, targetModel}
    return Workspace:Raycast(origin, direction.Unit * direction.Magnitude, params) == nil
end

local function getClosestNPCInFOV()
    if not Camera then return nil end
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local closestDist = AimbotFOV; local closestHead = nil
    for _, npc in ipairs(workspace:GetChildren()) do
        if npc.Name == "NPC" then
            local head = npc:FindFirstChild("Head")
            local humanoid = npc:FindFirstChild("Humanoid")
            local rootPart = npc:FindFirstChild("HumanoidRootPart")
            if head and humanoid and rootPart and humanoid.Health > 0 and isHostile(npc) then
                local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local distFromCenter = (Vector2.new(headPos.X, headPos.Y) - screenCenter).Magnitude
                    if distFromCenter < closestDist and isTargetVisible(head, npc) then
                        closestDist = distFromCenter; closestHead = head
                    end
                end
            end
        end
    end
    return closestHead
end

local function startAimbot()
    if aimbotConn then aimbotConn:Disconnect() end
    aimbotConn = RunService.RenderStepped:Connect(function()
        if not AimbotEnabled then return end
        local target = getClosestNPCInFOV()
        if target then
            local lookAt = CFrame.new(Camera.CFrame.Position, target.Position)
            local alpha = math.clamp(AimbotSmoothness * 0.1, 0.01, 1)
            Camera.CFrame = Camera.CFrame:Lerp(lookAt, alpha)
        end
    end)
end

local function stopAimbot()
    AimbotEnabled = false
    if aimbotConn then aimbotConn:Disconnect(); aimbotConn = nil end
end

local function antiDeathLoop()
    while AntiDeathEnabled do
        task.wait(0.5)
        local char = player.Character
        if char and not antiDeathTriggered then
            local hum = char:FindFirstChild("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.Health > 0 and hum.Health <= 20 then
                antiDeathTriggered = true
                local originalY = root.Position.Y
                root.CFrame = root.CFrame + Vector3.new(0, 200, 0)
                Rayfield:Notify({ Title = "AntiDeath", Content = "Teleported 200 studs up! Returning in 10 seconds.", Duration = 5, Image = 4483362458 })
                task.delay(10, function()
                    if root and root.Parent then
                        root.CFrame = CFrame.new(root.Position.X, originalY, root.Position.Z)
                        Rayfield:Notify({ Title = "AntiDeath", Content = "Returned to original height.", Duration = 3, Image = 4483362458 })
                    end
                    antiDeathTriggered = false
                end)
            end
        end
    end
end

local function startAntiDeath()
    AntiDeathEnabled = true
    antiDeathTriggered = false
    task.spawn(antiDeathLoop)
end

local function stopAntiDeath()
    AntiDeathEnabled = false
    antiDeathTriggered = false
end

MovementTab:CreateSection("speed and jump")
MovementTab:CreateToggle({ Name = "custom walkspeed", CurrentValue = false, Callback = function(v) CustomWalkSpeedEnabled = v end })
MovementTab:CreateSlider({ Name = "walkspeed", Range = {16, 200}, Increment = 1, Suffix = "", CurrentValue = 16, Callback = function(v) WalkSpeedValue = v end })
MovementTab:CreateToggle({ Name = "custom jumping", CurrentValue = false, Callback = function(v) JumpEnabled = v end })
MovementTab:CreateSlider({ Name = "jumppower", Range = {50, 500}, Increment = 1, Suffix = "", CurrentValue = 50, Callback = function(v) JumpPowerValue = v end })

VisualsTab:CreateSection("enemy esp")
VisualsTab:CreateToggle({ Name = "enable esp", CurrentValue = false, Callback = function(v) ESPEnabled = v; if not v then for _, o in pairs(espObjects) do o.Billboard.Enabled = false; o.Highlight.Enabled = false end end end })

CombatTab:CreateSection("aimbot")
CombatTab:CreateToggle({ Name = "enable aimbot", CurrentValue = false, Callback = function(v) AimbotEnabled = v; if v then startAimbot() else stopAimbot() end end })
CombatTab:CreateSlider({ Name = "fov radius", Range = {50, 500}, Increment = 10, Suffix = "", CurrentValue = 150, Callback = function(v) AimbotFOV = v end })
CombatTab:CreateSlider({ Name = "smoothness", Range = {1, 10}, Increment = 1, CurrentValue = 5, Callback = function(v) AimbotSmoothness = v end })

ObjectivesTab:CreateSection("survival")
ObjectivesTab:CreateToggle({ Name = "antideath", CurrentValue = false, Callback = function(v) if v then startAntiDeath() else stopAntiDeath() end end })
