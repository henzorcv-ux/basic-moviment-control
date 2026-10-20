--[[
    Basic Settings Control v2.1.0
    Velocidade | Pulo | ESP | Noclip | Auto Presser | Fly (pág.1) | Aim | TP Click | Hitbox | Invisible (pág.2) | Anti-AFK

    v2.1.0:
    - Correção do botão Invisible (estado visual travado)
    - Invisibilidade agressiva: Network Ownership forçado e loop RenderStepped (replica para os outros)
--]]

-- ============================================
-- SERVIÇOS
-- ============================================

local Players, UIS, CoreGui, RunService, VirtualUser, TweenService, VirtualInputManager = 
    game:GetService("Players"), 
    game:GetService("UserInputService"), 
    game:GetService("CoreGui"), 
    game:GetService("RunService"), 
    game:GetService("VirtualUser"), 
    game:GetService("TweenService"),
    game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- ============================================
-- ANTI-AFK
-- ============================================

local antiAfkConnection = player.Idled:Connect(function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

print("🛡️ Anti-AFK ativado (sempre ligado)")

-- ============================================
-- EVENT BUS
-- ============================================

local EventBus = {}
EventBus.__index = EventBus

function EventBus.new()
    local self = setmetatable({}, EventBus)
    self.events = {}
    return self
end

function EventBus:subscribe(event, callback)
    if not self.events[event] then self.events[event] = {} end
    table.insert(self.events[event], callback)
    return function() self:unsubscribe(event, callback) end
end

function EventBus:unsubscribe(event, callback)
    if self.events[event] then
        for i, cb in ipairs(self.events[event]) do
            if cb == callback then table.remove(self.events[event], i) break end
        end
    end
end

function EventBus:emit(event, ...)
    if self.events[event] then
        for _, callback in ipairs(self.events[event]) do
            pcall(callback, ...)
        end
    end
end

-- ============================================
-- CONFIG
-- ============================================

local ConfigManager = {}
ConfigManager.__index = ConfigManager

function ConfigManager.new()
    local self = setmetatable({}, ConfigManager)
    self.data = {
        speed = { value = 25, min = 5, max = 500 },
        flySpeed = { value = 1, min = 1, max = 10 },
        aimbot = { fov = 120, targetPart = "Head", wallCheck = true },
        features = { speedControl = false, infiniteJump = false, noclip = false, fly = false, esp = false, hitbox = false, autoPresser = false, aimbot = false, tpClick = false, invisible = false },
        window = { minimized = false, currentPage = 1 }
    }
    return self
end

function ConfigManager:get(path)
    local keys, current = {}, self.data
    for key in string.gmatch(path, "[^.]+") do table.insert(keys, key) end
    for _, key in ipairs(keys) do
        if current[key] == nil then return nil end
        current = current[key]
    end
    return current
end

function ConfigManager:set(path, value)
    local keys, current = {}, self.data
    for key in string.gmatch(path, "[^.]+") do table.insert(keys, key) end
    for i = 1, #keys - 1 do
        if current[keys[i]] == nil then current[keys[i]] = {} end
        current = current[keys[i]]
    end
    current[keys[#keys]] = value
end

-- ============================================
-- MÓDULO VELOCIDADE
-- ============================================

local SpeedModule = {}
SpeedModule.__index = SpeedModule

function SpeedModule.new(config)
    local self = setmetatable({}, SpeedModule)
    self.config, self.eventBus = config, EventBus.new()
    self.isEnabled, self.currentSpeed = false, config:get("speed.value") or 25
    self.defaultSpeed = 16
    self.character, self.humanoid, self.originalSpeed = nil, nil, nil
    self.velocityCheckConnection = nil
    self.forceSpeedConnection = nil
    self.humanoidChangedConnection = nil
    return self
end

function SpeedModule:initialize() self:setupCharacter() end

function SpeedModule:setupCharacter()
    self.character = player.Character or player.CharacterAdded:Wait()
    self.humanoid = self.character:WaitForChild("Humanoid")
    self.originalSpeed = self.humanoid.WalkSpeed
    self.defaultSpeed = self.originalSpeed

    player.CharacterAdded:Connect(function(character)
        self.character, self.humanoid = character, character:WaitForChild("Humanoid")
        self.originalSpeed = self.humanoid.WalkSpeed
        self.defaultSpeed = self.originalSpeed
        if self.isEnabled then self:enable() end
    end)
end

function SpeedModule:enable() 
    self.isEnabled = true 
    self:applySpeed()
    self:startSpeedProtection()
end

function SpeedModule:disable() 
    self.isEnabled = false 
    self:stopSpeedProtection()
    self:restoreDefaultSpeed() 
end

function SpeedModule:setSpeed(value)
    local minVal, maxVal = self.config:get("speed.min"), self.config:get("speed.max")
    value = math.clamp(value, minVal, maxVal)
    self.currentSpeed = value
    self.config:set("speed.value", value)
    self.eventBus:emit("speedChanged", value)
    if self.isEnabled then self:applySpeed() end
end

function SpeedModule:applySpeed()
    if self.humanoid then pcall(function() self.humanoid.WalkSpeed = self.currentSpeed end) end
end

function SpeedModule:restoreDefaultSpeed()
    if self.humanoid then pcall(function() self.humanoid.WalkSpeed = self.defaultSpeed end) end
end

function SpeedModule:startSpeedProtection()
    self:stopSpeedProtection()
    self.velocityCheckConnection = RunService.Heartbeat:Connect(function()
        if self.isEnabled and self.humanoid and self.humanoid.Parent then
            if self.humanoid.WalkSpeed ~= self.currentSpeed then
                self.humanoid.WalkSpeed = self.currentSpeed
            end
        end
    end)

    self.forceSpeedConnection = RunService.RenderStepped:Connect(function()
        if self.isEnabled and self.humanoid and self.humanoid.Parent then
            self.humanoid.WalkSpeed = self.currentSpeed
        end
    end)

    if self.humanoid then
        local mt = {}
        mt.__index = function(t, k) return rawget(t, k) end
        mt.__newindex = function(t, k, v)
            if k == "WalkSpeed" and self.isEnabled then
                rawset(t, k, self.currentSpeed)
                return
            end
            rawset(t, k, v)
        end
        pcall(function() setmetatable(self.humanoid, mt) end)
    end

    if self.humanoid then
        self.humanoidChangedConnection = self.humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if self.isEnabled and self.humanoid then
                if self.humanoid.WalkSpeed ~= self.currentSpeed then
                    self.humanoid.WalkSpeed = self.currentSpeed
                end
            end
        end)
    end
end

function SpeedModule:stopSpeedProtection()
    if self.velocityCheckConnection then self.velocityCheckConnection:Disconnect() self.velocityCheckConnection = nil end
    if self.forceSpeedConnection then self.forceSpeedConnection:Disconnect() self.forceSpeedConnection = nil end
    if self.humanoidChangedConnection then self.humanoidChangedConnection:Disconnect() self.humanoidChangedConnection = nil end
    pcall(function()
        if self.humanoid then setmetatable(self.humanoid, nil) end
    end)
end

-- ============================================
-- MÓDULO PULO INFINITO
-- ============================================

local InfiniteJumpModule = {}
InfiniteJumpModule.__index = InfiniteJumpModule

function InfiniteJumpModule.new(config)
    local self = setmetatable({}, InfiniteJumpModule)
    self.config = config
    self.isEnabled = false
    self.jumpConnection = nil
    return self
end

function InfiniteJumpModule:enable()
    if self.isEnabled then return end
    self.isEnabled = true
    self:setupJumpListener()
    print("🚀 Pulo Infinito ATIVADO!")
end

function InfiniteJumpModule:disable()
    self.isEnabled = false
    if self.jumpConnection then self.jumpConnection:Disconnect() self.jumpConnection = nil end
    print("🚀 Pulo Infinito DESATIVADO!")
end

function InfiniteJumpModule:setupJumpListener()
    if self.jumpConnection then self.jumpConnection:Disconnect() self.jumpConnection = nil end
    self.jumpConnection = UIS.JumpRequest:Connect(function()
        if not self.isEnabled then return end
        local char = player.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            char:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end

-- ============================================
-- MÓDULO ESP
-- ============================================

local ESPModule = {}
ESPModule.__index = ESPModule

function ESPModule.new(config)
    local self = setmetatable({}, ESPModule)
    self.config = config
    self.isEnabled = false
    self.espObjects = {}
    self.heartbeat = nil
    self.connections = {}
    self.scaleConfig = {
        MIN_TEXT = 8, MAX_TEXT = 13,
        NEAR_DIST = 10, FAR_DIST = 100,
        MIN_WIDTH = 90, MAX_WIDTH = 120,
        MIN_HEIGHT = 14, MAX_HEIGHT = 20,
    }
    return self
end

function ESPModule:createESPForPlayer(targetPlayer)
    if targetPlayer == player then return end
    if self.espObjects[targetPlayer] then return end

    local character = targetPlayer.Character
    if not character then return end
    local head = character:FindFirstChild("Head")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not head or not rootPart then return end

    local nameGui = Instance.new("BillboardGui")
    nameGui.Name = "ESP_Name"
    nameGui.Size = UDim2.new(0, 120, 0, 20)
    nameGui.StudsOffset = Vector3.new(0, 3.2, 0)
    nameGui.AlwaysOnTop = true
    nameGui.LightInfluence = 0
    nameGui.Adornee = head
    nameGui.Parent = head

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = targetPlayer.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.TextSize = 13
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.TextYAlignment = Enum.TextYAlignment.Center
    nameLabel.Parent = nameGui

    local distGui = Instance.new("BillboardGui")
    distGui.Name = "ESP_Distance"
    distGui.Size = UDim2.new(0, 120, 0, 20)
    distGui.StudsOffset = Vector3.new(0, -3.5, 0)
    distGui.AlwaysOnTop = true
    distGui.LightInfluence = 0
    distGui.Adornee = rootPart
    distGui.Parent = rootPart

    local distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(1, 0, 1, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = "0m"
    distLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distLabel.TextSize = 13
    distLabel.Font = Enum.Font.GothamBold
    distLabel.TextXAlignment = Enum.TextXAlignment.Center
    distLabel.TextYAlignment = Enum.TextYAlignment.Center
    distLabel.Parent = distGui

    local highlight
    pcall(function()
        highlight = Instance.new("Highlight")
        highlight.Name = "ESP_Chams"
        highlight.Adornee = character
        highlight.FillColor = Color3.fromRGB(255, 82, 82)
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = character
    end)

    local proxyModel, proxyHighlight
    pcall(function()
        proxyModel = Instance.new("Model")
        proxyModel.Name = "ESP_ProxyModel_" .. targetPlayer.Name
        proxyModel.Parent = workspace

        local proxyPart = Instance.new("Part")
        proxyPart.Name = "ProxyPart"
        proxyPart.Size = Vector3.new(4, 6, 2)
        proxyPart.Transparency = 1
        proxyPart.CanCollide = false
        proxyPart.Anchored = true
        proxyPart.CanQuery = false
        proxyPart.CanTouch = false
        proxyPart.Massless = true
        proxyPart.Parent = proxyModel

        proxyHighlight = Instance.new("Highlight")
        proxyHighlight.Name = "ESP_ProxyHighlight"
        proxyHighlight.Adornee = proxyModel
        proxyHighlight.FillColor = Color3.fromRGB(255, 82, 82)
        proxyHighlight.FillTransparency = 0.5
        proxyHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        proxyHighlight.OutlineTransparency = 0
        proxyHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        proxyHighlight.Parent = proxyModel
    end)

    self.espObjects[targetPlayer] = {
        nameGui = nameGui, nameLabel = nameLabel,
        distGui = distGui, distLabel = distLabel,
        highlight = highlight,
        proxyModel = proxyModel, proxyHighlight = proxyHighlight,
        chamsCharacter = character,
        lastForcedRecreate = tick()
    }
end

function ESPModule:removeESPForPlayer(targetPlayer)
    local esp = self.espObjects[targetPlayer]
    if not esp then return end
    pcall(function() if esp.nameGui then esp.nameGui:Destroy() end end)
    pcall(function() if esp.distGui then esp.distGui:Destroy() end end)
    pcall(function() if esp.highlight then esp.highlight:Destroy() end end)
    pcall(function() if esp.proxyModel then esp.proxyModel:Destroy() end end)
    self.espObjects[targetPlayer] = nil
end

function ESPModule:updateDistances()
    if not self.isEnabled then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local cfg = self.scaleConfig
    local now = tick()

    for targetPlayer, esp in pairs(self.espObjects) do
        local character = targetPlayer.Character
        if character and esp.chamsCharacter ~= character then
            self:removeESPForPlayer(targetPlayer)
            self:createESPForPlayer(targetPlayer)
            continue
        end
        if not character and esp.chamsCharacter then
            self:removeESPForPlayer(targetPlayer)
            continue
        end
        if character then
            local ff = character:FindFirstChildOfClass("ForceField")
            if ff then pcall(function() ff:Destroy() end) end
            for _, obj in ipairs(character:GetChildren()) do
                if obj:IsA("Highlight") and obj.Name ~= "ESP_Chams" then
                    pcall(function() obj:Destroy() end)
                end
            end
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if rootPart and esp.proxyModel then
                local proxyPart = esp.proxyModel:FindFirstChild("ProxyPart")
                if proxyPart then pcall(function() proxyPart.CFrame = rootPart.CFrame end) end
            end
            local needRecreate = (now - (esp.lastForcedRecreate or 0)) > 0.5
            if not esp.highlight or not esp.highlight.Parent then needRecreate = true end
            if not esp.proxyModel or not esp.proxyModel.Parent then needRecreate = true end
            if needRecreate then
                pcall(function() if esp.highlight then esp.highlight:Destroy() end end)
                pcall(function() if esp.proxyModel then esp.proxyModel:Destroy() end end)
                local nh, npm, nph
                pcall(function()
                    nh = Instance.new("Highlight")
                    nh.Name = "ESP_Chams"
                    nh.Adornee = character
                    nh.FillColor = Color3.fromRGB(255, 82, 82)
                    nh.FillTransparency = 0.5
                    nh.OutlineColor = Color3.fromRGB(255, 255, 255)
                    nh.OutlineTransparency = 0
                    nh.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    nh.Parent = character
                end)
                pcall(function()
                    npm = Instance.new("Model")
                    npm.Name = "ESP_ProxyModel_" .. targetPlayer.Name
                    npm.Parent = workspace
                    local pp = Instance.new("Part")
                    pp.Name = "ProxyPart"
                    pp.Size = Vector3.new(4, 6, 2)
                    pp.Transparency = 1
                    pp.CanCollide = false
                    pp.Anchored = true
                    pp.CanQuery = false
                    pp.CanTouch = false
                    pp.Massless = true
                    pp.Parent = npm
                    if rootPart then pp.CFrame = rootPart.CFrame end
                    nph = Instance.new("Highlight")
                    nph.Name = "ESP_ProxyHighlight"
                    nph.Adornee = npm
                    nph.FillColor = Color3.fromRGB(255, 82, 82)
                    nph.FillTransparency = 0.5
                    nph.OutlineColor = Color3.fromRGB(255, 255, 255)
                    nph.OutlineTransparency = 0
                    nph.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    nph.Parent = npm
                end)
                esp.highlight = nh
                esp.proxyModel = npm
                esp.proxyHighlight = nph
                esp.lastForcedRecreate = now
            end
        end
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if character and rootPart and esp.distLabel then
            local distance = (camera.CFrame.Position - rootPart.Position).Magnitude
            esp.distLabel.Text = string.format("%dm", math.floor(distance))
            local factor = 1 - math.clamp((distance - cfg.NEAR_DIST) / (cfg.FAR_DIST - cfg.NEAR_DIST), 0, 1)
            local newTextSize = math.floor(cfg.MIN_TEXT + (cfg.MAX_TEXT - cfg.MIN_TEXT) * factor + 0.5)
            esp.nameLabel.TextSize = newTextSize
            esp.distLabel.TextSize = newTextSize
            local newWidth = math.floor(cfg.MIN_WIDTH + (cfg.MAX_WIDTH - cfg.MIN_WIDTH) * factor + 0.5)
            local newHeight = math.floor(cfg.MIN_HEIGHT + (cfg.MAX_HEIGHT - cfg.MIN_HEIGHT) * factor + 0.5)
            esp.nameGui.Size = UDim2.new(0, newWidth, 0, newHeight)
            esp.distGui.Size = UDim2.new(0, newWidth, 0, newHeight)
        end
    end
end

function ESPModule:enable()
    if self.isEnabled then return end
    self.isEnabled = true
    self.config:set("features.esp", true)

    local function ensure(p)
        if p == player then return end
        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            self:createESPForPlayer(p)
        end
        local conn = p.CharacterAdded:Connect(function(newChar)
            local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
            if not hrp then return end
            task.wait(0.2)
            if not self.isEnabled then return end
            self:removeESPForPlayer(p)
            self:createESPForPlayer(p)
        end)
        table.insert(self.connections, conn)
    end

    for _, p in ipairs(Players:GetPlayers()) do ensure(p) end
    table.insert(self.connections, Players.PlayerAdded:Connect(ensure))
    table.insert(self.connections, Players.PlayerRemoving:Connect(function(p) self:removeESPForPlayer(p) end))

    self.heartbeat = RunService.RenderStepped:Connect(function() self:updateDistances() end)
    print("👁️ ESP ATIVADO! (Nome + Distância + Chams)")
end

function ESPModule:disable()
    self.isEnabled = false
    self.config:set("features.esp", false)
    for _, conn in ipairs(self.connections) do pcall(function() conn:Disconnect() end) end
    self.connections = {}
    if self.heartbeat then self.heartbeat:Disconnect() self.heartbeat = nil end
    for targetPlayer, _ in pairs(self.espObjects) do self:removeESPForPlayer(targetPlayer) end
    self.espObjects = {}
    print("👁️ ESP DESATIVADO! (Tudo removido)")
end

-- ============================================
-- MÓDULO NOCLIP
-- ============================================

local NoclipModule = {}
NoclipModule.__index = NoclipModule

function NoclipModule.new(config)
    local self = setmetatable({}, NoclipModule)
    self.config = config
    self.isEnabled = false
    self.connection = nil
    self.partsWithCollision = {}
    return self
end

function NoclipModule:enable()
    if self.isEnabled then return end
    self.isEnabled = true
    self.config:set("features.noclip", true)
    self:saveCollisionState()
    self:setupNoclip()
    print("👻 Noclip ATIVADO!")
end

function NoclipModule:disable()
    self.isEnabled = false
    self.config:set("features.noclip", false)
    if self.connection then self.connection:Disconnect() self.connection = nil end
    self:restoreCollision()
    print("👻 Noclip DESATIVADO - Colisão restaurada!")
end

function NoclipModule:saveCollisionState()
    self.partsWithCollision = {}
    local character = player.Character
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide == true then
                table.insert(self.partsWithCollision, part)
            end
        end
    end
end

function NoclipModule:restoreCollision()
    for _, part in ipairs(self.partsWithCollision) do
        pcall(function()
            if part and part.Parent then part.CanCollide = true end
        end)
    end
    self.partsWithCollision = {}
end

function NoclipModule:setupNoclip()
    if self.connection then self.connection:Disconnect() self.connection = nil end
    self.connection = RunService.Stepped:Connect(function()
        if not self.isEnabled then return end
        local character = player.Character
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end)
end

-- ============================================
-- MÓDULO AUTO PRESSER
-- ============================================

local AutoPresserModule = {}
AutoPresserModule.__index = AutoPresserModule

function AutoPresserModule.new(config)
    local self = setmetatable({}, AutoPresserModule)
    self.config = config
    self.isEnabled = false
    self.isHolding = false
    self.isKeyHeld = false
    self.pressKey = Enum.KeyCode.E
    self.toggleKey = Enum.KeyCode.R
    self.keyConnection = nil
    self.reinforceThread = nil
    self.windowFocusConn = nil
    return self
end

function AutoPresserModule:_connectKeyToggle()
    if self.keyConnection then return end
    self.keyConnection = UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == self.toggleKey and self.isEnabled then self:toggleHold() end
    end)
end

function AutoPresserModule:_disconnectKeyToggle()
    if self.keyConnection then self.keyConnection:Disconnect() self.keyConnection = nil end
end

function AutoPresserModule:_holdKey()
    pcall(function() VirtualInputManager:SendKeyEvent(true, self.pressKey, false, game) end)
    self.isKeyHeld = true
end

function AutoPresserModule:_releaseKey()
    if not self.isKeyHeld then return end
    pcall(function() VirtualInputManager:SendKeyEvent(false, self.pressKey, false, game) end)
    self.isKeyHeld = false
end

function AutoPresserModule:_startReinforce()
    if self.reinforceThread then return end
    self.reinforceThread = task.spawn(function()
        while self.isHolding do
            task.wait(0.05)
            if self.isHolding then
                pcall(function() VirtualInputManager:SendKeyEvent(true, self.pressKey, false, game) end)
                self.isKeyHeld = true
            end
        end
        self.reinforceThread = nil
    end)
end

function AutoPresserModule:_stopReinforce()
    if self.reinforceThread then
        pcall(function() task.cancel(self.reinforceThread) end)
        self.reinforceThread = nil
    end
end

function AutoPresserModule:toggleHold()
    if not self.isEnabled then return end
    if self.isHolding then
        self.isHolding = false
        self:_stopReinforce()
        self:_releaseKey()
        print("🖱️ Auto Presser: [" .. self.pressKey.Name .. "] SOLTA")
    else
        self.isHolding = true
        self:_holdKey()
        self:_startReinforce()
        print("🖱️ Auto Presser: [" .. self.pressKey.Name .. "] SEGURANDO")
    end
    if self.onHoldChanged then self.onHoldChanged(self.isHolding) end
end

function AutoPresserModule:_connectWindowFocus()
    if self.windowFocusConn then return end
    self.windowFocusConn = UIS.WindowFocused:Connect(function()
        if self.isEnabled and self.isHolding then
            task.wait(0.05)
            if self.isHolding then
                self:_holdKey()
                if not self.reinforceThread then self:_startReinforce() end
            end
        end
    end)
end

function AutoPresserModule:_disconnectWindowFocus()
    if self.windowFocusConn then self.windowFocusConn:Disconnect() self.windowFocusConn = nil end
end

function AutoPresserModule:enable()
    if self.isEnabled then return end
    self.isEnabled = true
    self.config:set("features.autoPresser", true)
    self:_connectKeyToggle()
    self:_connectWindowFocus()
    print("🖱️ Auto Presser ARMADO")
end

function AutoPresserModule:disable()
    if not self.isEnabled then return end
    if self.isHolding then
        self.isHolding = false
        self:_stopReinforce()
        self:_releaseKey()
    end
    self.isEnabled = false
    self.config:set("features.autoPresser", false)
    self:_disconnectKeyToggle()
    self:_disconnectWindowFocus()
    print("🖱️ Auto Presser DESARMADO")
end

function AutoPresserModule:toggle()
    if self.isEnabled then self:disable() else self:enable() end
    return self.isEnabled
end

-- ============================================
-- MÓDULO HITBOX EXPANDER
-- ============================================

local HitboxModule = {}
HitboxModule.__index = HitboxModule

function HitboxModule.new(config)
    local self = setmetatable({}, HitboxModule)
    self.config = config
    self.isEnabled = false
    self.isViewing = false
    self.connection = nil
    self.originalSizes = {}
    self.HITBOX_SIZE = Vector3.new(120, 120, 120)
    self.DEFAULT_SIZE = Vector3.new(2, 2, 1)
    self.VISIBLE_TRANSPARENCY = 0.7
    self.INVISIBLE_TRANSPARENCY = 1
    return self
end

function HitboxModule:_getHRP(character)
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
end

function HitboxModule:_expandHitbox(character)
    local hrp = self:_getHRP(character)
    if not hrp then return end
    if not self.originalSizes[character] then self.originalSizes[character] = hrp.Size end
    hrp.Size = self.HITBOX_SIZE
    hrp.Transparency = self.isViewing and self.VISIBLE_TRANSPARENCY or self.INVISIBLE_TRANSPARENCY
end

function HitboxModule:_restoreHitbox(character)
    local hrp = self:_getHRP(character)
    if not hrp then return end
    if self.originalSizes[character] then
        hrp.Size = self.originalSizes[character]
        self.originalSizes[character] = nil
    else
        hrp.Size = self.DEFAULT_SIZE
    end
    hrp.Transparency = 1
end

function HitboxModule:_applyToAll()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then self:_expandHitbox(p.Character) end
    end
end

function HitboxModule:_restoreAll()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then self:_restoreHitbox(p.Character) end
    end
    self.originalSizes = {}
end

function HitboxModule:enable()
    if self.isEnabled then return end
    self.isEnabled = true
    self.config:set("features.hitbox", true)
    self:_applyToAll()
    self.connection = RunService.Heartbeat:Connect(function()
        if not self.isEnabled then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp and hrp.Size ~= self.HITBOX_SIZE then self:_expandHitbox(p.Character) end
            end
        end
    end)
    print("🎯 Hitbox Expander ATIVADO!")
end

function HitboxModule:disable()
    if not self.isEnabled then return end
    self.isEnabled = false
    self.config:set("features.hitbox", false)
    if self.connection then self.connection:Disconnect() self.connection = nil end
    self:_restoreAll()
    print("🎯 Hitbox Expander DESATIVADO!")
end

function HitboxModule:setViewing(state)
    self.isViewing = state
    if self.isEnabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Transparency = state and self.VISIBLE_TRANSPARENCY or self.INVISIBLE_TRANSPARENCY
                end
            end
        end
    end
end

-- ============================================
-- MÓDULO INVISIBLE (AGGRESSIVE REPLICATION)
-- ============================================

local InvisibleModule = {}
InvisibleModule.__index = InvisibleModule

function InvisibleModule.new(config)
    local self = setmetatable({}, InvisibleModule)
    self.config = config
    self.isEnabled = false
    self.originalData = {}
    self.loopConn = nil
    return self
end

function InvisibleModule:enable()
    if self.isEnabled then return end
    self.isEnabled = true
    self.config:set("features.invisible", true)
    
    local char = player.Character
    if char then
        self.originalData = {}
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                self.originalData[part] = {
                    Transparency = part.Transparency,
                    CanCollide = part.CanCollide,
                    CastShadow = part.CastShadow
                }
                -- Força a propriedade de rede para o cliente (permite replicar a transparência)
                pcall(function() part:SetNetworkOwner(player) end)
            elseif part:IsA("Decal") or part:IsA("Texture") then
                self.originalData[part] = {
                    Transparency = part.Transparency
                }
            end
        end
    end

    -- Loop agressivo para garantir que o servidor não reverta
    if self.loopConn then self.loopConn:Disconnect() end
    self.loopConn = RunService.RenderStepped:Connect(function()
        if not self.isEnabled then return end
        local c = player.Character
        if not c then return end
        
        for _, part in ipairs(c:GetDescendants()) do
            if part:IsA("BasePart") then
                if part.Transparency < 1 then part.Transparency = 1 end
                if part.CastShadow then part.CastShadow = false end
            elseif part:IsA("Decal") or part:IsA("Texture") then
                if part.Transparency < 1 then part.Transparency = 1 end
            end
        end
    end)
    
    print("👤 Invisibilidade ATIVADA!")
end

function InvisibleModule:disable()
    if not self.isEnabled then return end
    self.isEnabled = false
    self.config:set("features.invisible", false)
    
    if self.loopConn then
        self.loopConn:Disconnect()
        self.loopConn = nil
    end
    
    for part, data in pairs(self.originalData) do
        if part and part.Parent then
            part.Transparency = data.Transparency
            if data.CanCollide ~= nil then part.CanCollide = data.CanCollide end
            if data.CastShadow ~= nil then part.CastShadow = data.CastShadow end
        end
    end
    self.originalData = {}
    print("👤 Invisibilidade DESATIVADA!")
end

function InvisibleModule:toggle()
    if self.isEnabled then self:disable() else self:enable() end
    return self.isEnabled
end

-- ============================================
-- MÓDULO FLY
-- ============================================

local FlyModule = {}
FlyModule.__index = FlyModule

function FlyModule.new(config)
    local self = setmetatable({}, FlyModule)
    self.config = config
    self.isEnabled = false
    self.isFlying = false
    self.bodyVelocity = nil
    self.bodyGyro = nil
    self.connections = {}
    self.speed = config:get("flySpeed.value") or 1
    self.fKeyConnection = nil
    return self
end

function FlyModule:getRealSpeed() return 40 + (self.speed * 20) end

function FlyModule:enable()
    if self.isEnabled then return end
    self.isEnabled = true
    self.isFlying = false
    self.config:set("features.fly", true)
    self:setupKeyToggle()
    print("✈️ Fly ATIVADO! Pressione F para voar.")
end

function FlyModule:disable()
    self.isEnabled = false
    self.isFlying = false
    self.config:set("features.fly", false)
    self:cleanupFly()
    if self.fKeyConnection then self.fKeyConnection:Disconnect() self.fKeyConnection = nil end
    print("✈️ Fly DESATIVADO!")
end

function FlyModule:setSpeed(value)
    self.speed = math.clamp(value, 1, 10)
    self.config:set("flySpeed.value", self.speed)
end

function FlyModule:toggleFly()
    if not self.isEnabled then return end
    self.isFlying = not self.isFlying
    if self.isFlying then self:startFly() else self:stopFly() end
end

function FlyModule:setupKeyToggle()
    if self.fKeyConnection then self.fKeyConnection:Disconnect() self.fKeyConnection = nil end
    self.fKeyConnection = UIS.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.F and self.isEnabled then self:toggleFly() end
    end)
end

function FlyModule:startFly()
    if not self.isEnabled then return end
    local character = player.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.PlatformStand = true end

    if not self.bodyVelocity then
        self.bodyVelocity = Instance.new("BodyVelocity")
        self.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        self.bodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        self.bodyVelocity.Parent = rootPart
    end
    if not self.bodyGyro then
        self.bodyGyro = Instance.new("BodyGyro")
        self.bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        self.bodyGyro.Parent = rootPart
    end

    if #self.connections == 0 then
        table.insert(self.connections, RunService.RenderStepped:Connect(function()
            if not self.isFlying or not rootPart.Parent then
                if self.bodyVelocity then self.bodyVelocity.Velocity = Vector3.new(0, 0, 0) end
                return
            end
            local moveDirection = Vector3.new(0, 0, 0)
            if UIS:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + Vector3.new(0, 0, -1) end
            if UIS:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection + Vector3.new(0, 0, 1) end
            if UIS:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection + Vector3.new(-1, 0, 0) end
            if UIS:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + Vector3.new(1, 0, 0) end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then moveDirection = moveDirection + Vector3.new(0, 1, 0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then moveDirection = moveDirection + Vector3.new(0, -1, 0) end
            if moveDirection.Magnitude > 0 then moveDirection = moveDirection.Unit end
            local camera = workspace.CurrentCamera
            if camera then
                local forward = camera.CFrame.LookVector
                local right = camera.CFrame.RightVector
                local up = camera.CFrame.UpVector
                local moveVector = (forward * -moveDirection.Z) + (right * moveDirection.X) + (up * moveDirection.Y)
                self.bodyVelocity.Velocity = moveVector * self:getRealSpeed()
                local lookAtPos = camera.CFrame.Position + (camera.CFrame.LookVector * 100)
                self.bodyGyro.CFrame = CFrame.new(rootPart.Position, lookAtPos)
            end
        end))
    end
end

function FlyModule:stopFly()
    self.isFlying = false
    self:cleanupFly()
end

function FlyModule:cleanupFly()
    for _, conn in ipairs(self.connections) do conn:Disconnect() end
    self.connections = {}
    if self.bodyVelocity then self.bodyVelocity:Destroy() self.bodyVelocity = nil end
    if self.bodyGyro then self.bodyGyro:Destroy() self.bodyGyro = nil end
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.PlatformStand = false end
    end
end

-- ============================================
-- MÓDULO AIMBOT
-- ============================================

local AimbotModule = {}
AimbotModule.__index = AimbotModule

function AimbotModule.new(config)
    local self = setmetatable({}, AimbotModule)
    self.config = config
    self.isEnabled = false
    self.connection = nil
    self.camera = workspace.CurrentCamera
    self.fov = config:get("aimbot.fov") or 120
    self.targetPart = config:get("aimbot.targetPart") or "Head"
    self.wallCheck = config:get("aimbot.wallCheck") ~= false
    self.currentTarget = nil
    self.onFOVChanged = nil
    return self
end

function AimbotModule:_isVisible(part)
    if not self.wallCheck then return true end
    local char = player.Character
    if not char then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char, part.Parent}
    local result = workspace:Raycast(self.camera.CFrame.Position, part.Position - self.camera.CFrame.Position, params)
    return result == nil
end

function AimbotModule:_getTarget()
    local camera = self.camera
    if not camera then return nil end
    local viewportSize = camera.ViewportSize
    local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    local maxDist = self.fov
    local bestTarget = nil

    for _, p in ipairs(Players:GetPlayers()) do
        if p == player then continue end
        local char = p.Character
        if not char then continue end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        local part = char:FindFirstChild(self.targetPart)
        if not part then continue end

        local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
        if onScreen then
            local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
            if dist <= maxDist and self:_isVisible(part) then
                maxDist = dist
                bestTarget = p
            end
        end
    end
    return bestTarget
end

function AimbotModule:_aimAt(target)
    if not target or not target.Character then return end
    local aimPart = target.Character:FindFirstChild(self.targetPart)
    if not aimPart then return end
    self.camera.CFrame = CFrame.new(self.camera.CFrame.Position, aimPart.Position)
end

function AimbotModule:enable()
    if self.isEnabled then return end
    self.isEnabled = true
    self.config:set("features.aimbot", true)
    self.camera = workspace.CurrentCamera

    self.connection = RunService.RenderStepped:Connect(function()
        if not self.isEnabled then return end
        self.camera = workspace.CurrentCamera
        if not self.camera then return end
        local target = self:_getTarget()
        if target then
            self.currentTarget = target
            self:_aimAt(target)
        else
            self.currentTarget = nil
        end
    end)
    print("🤖 Aimbot ATIVADO! FOV: " .. self.fov .. "px")
end

function AimbotModule:disable()
    if not self.isEnabled then return end
    self.isEnabled = false
    self.currentTarget = nil
    self.config:set("features.aimbot", false)
    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end
    print("🤖 Aimbot DESATIVADO!")
end

function AimbotModule:toggle()
    if self.isEnabled then self:disable() else self:enable() end
    return self.isEnabled
end

function AimbotModule:setFOV(sliderValue)
    self.fov = math.clamp(sliderValue * 60, 60, 600)
    self.config:set("aimbot.fov", self.fov)
    if self.onFOVChanged then
        self.onFOVChanged(self.fov)
    end
end

-- ============================================
-- MÓDULO TP CLICK
-- ============================================

local TPClickModule = {}
TPClickModule.__index = TPClickModule

function TPClickModule.new(config)
    local self = setmetatable({}, TPClickModule)
    self.config = config
    self.isEnabled = false
    self.ctrlHeld = false
    self.lastTPTime = 0
    self.COOLDOWN = 0.2
    self.MAX_TP_DISTANCE = 500
    self.MIN_TP_DISTANCE = 2
    self.connections = {}
    return self
end

function TPClickModule:_isMouseOverUI(mousePos)
    local gui = CoreGui:FindFirstChild("BasicSettingsControlGUI")
    if not gui then return false end
    for _, descendant in ipairs(gui:GetDescendants()) do
        if descendant:IsA("GuiObject") and descendant.Visible then
            local pos = descendant.AbsolutePosition
            local size = descendant.AbsoluteSize
            if mousePos.X >= pos.X and mousePos.X <= pos.X + size.X
               and mousePos.Y >= pos.Y and mousePos.Y <= pos.Y + size.Y then
                if descendant:IsA("TextButton") or descendant:IsA("ImageButton") then
                    return true
                end
            end
        end
    end
    return false
end

function TPClickModule:_getGroundOffset()
    local char = player.Character
    if not char then return 3 end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return 3 end
    
    return hum.HipHeight + (hrp.Size.Y / 2)
end

function TPClickModule:_getTargetPosition()
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local hitCFrame = mouse.Hit
    if not hitCFrame then return nil end

    local hitPos = hitCFrame.Position
    local delta = hitPos - hrp.Position
    local horizDelta = Vector3.new(delta.X, 0, delta.Z)

    if horizDelta.Magnitude < self.MIN_TP_DISTANCE then
        return nil
    end

    local finalPos

    if horizDelta.Magnitude > self.MAX_TP_DISTANCE then
        horizDelta = horizDelta.Unit * self.MAX_TP_DISTANCE
        local limitedPos = hrp.Position + horizDelta
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char}
        params.IgnoreWater = true
        local downResult = workspace:Raycast(limitedPos + Vector3.new(0, 500, 0), Vector3.new(0, -2000, 0), params)
        if downResult then
            finalPos = downResult.Position
        else
            finalPos = limitedPos - Vector3.new(0, 3, 0)
        end
    else
        finalPos = hitPos
    end
    
    local groundOffset = self:_getGroundOffset()
    return finalPos + Vector3.new(0, groundOffset + 0.5, 0)
end

function TPClickModule:_teleportTo(position)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp then return end

    pcall(function()
        hrp.CFrame = CFrame.new(position)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        
        if hum then
            if hum:GetState() ~= Enum.HumanoidStateType.Jumping and hum:GetState() ~= Enum.HumanoidStateType.Freefall then
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end
    end)
end

function TPClickModule:enable()
    if self.isEnabled then return end
    self.isEnabled = true
    self.config:set("features.tpClick", true)

    table.insert(self.connections, UIS.InputBegan:Connect(function(input, gp)
        if input.KeyCode == Enum.KeyCode.LeftControl then
            self.ctrlHeld = true
        end
    end))

    table.insert(self.connections, UIS.InputEnded:Connect(function(input, gp)
        if input.KeyCode == Enum.KeyCode.LeftControl then
            self.ctrlHeld = false
        end
    end))

    table.insert(self.connections, UIS.InputBegan:Connect(function(input, gp)
        if not self.isEnabled then return end
        if not self.ctrlHeld then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if gp then return end

        local now = tick()
        if now - self.lastTPTime < self.COOLDOWN then return end

        local char = player.Character
        if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end

        local mousePos = UIS:GetMouseLocation()
        if self:_isMouseOverUI(mousePos) then return end

        local pos = self:_getTargetPosition()
        if not pos then return end

        self.lastTPTime = now
        self:_teleportTo(pos)
    end))

    print("🌀 TP Click ATIVADO! Use Ctrl + Clique Esquerdo.")
end

function TPClickModule:disable()
    if not self.isEnabled then return end
    self.isEnabled = false
    self.ctrlHeld = false
    self.config:set("features.tpClick", false)
    for _, conn in ipairs(self.connections) do
        pcall(function() conn:Disconnect() end)
    end
    self.connections = {}
    print("🌀 TP Click DESATIVADO!")
end

function TPClickModule:toggle()
    if self.isEnabled then self:disable() else self:enable() end
    return self.isEnabled
end

-- ============================================
-- UI
-- ============================================

local function createUI(speedModule, jumpModule, espModule, noclipModule, autoPresserModule, hitboxModule, invisibleModule, flyModule, aimbotModule, tpClickModule)
    local gui = Instance.new("ScreenGui")
    gui.Name = "BasicSettingsControlGUI"
    gui.Parent = CoreGui
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true

    local theme = {
        background = Color3.fromRGB(18, 18, 24),
        surface = Color3.fromRGB(28, 28, 38),
        surface2 = Color3.fromRGB(38, 38, 50),
        surface3 = Color3.fromRGB(48, 48, 62),
        text = Color3.fromRGB(255, 255, 255),
        textSecondary = Color3.fromRGB(180, 185, 200),
        textMuted = Color3.fromRGB(130, 135, 150),
        success = Color3.fromRGB(0, 230, 118),
        danger = Color3.fromRGB(255, 82, 82),
        warning = Color3.fromRGB(255, 215, 0),
        accent = Color3.fromRGB(100, 180, 255),
        jumpColor = Color3.fromRGB(255, 100, 150),
        noclipColor = Color3.fromRGB(150, 100, 255),
        hitboxColor = Color3.fromRGB(255, 200, 80),
        flyColor = Color3.fromRGB(0, 230, 255),
        espColor = Color3.fromRGB(200, 130, 255),
        autoPresserColor = Color3.fromRGB(255, 150, 60),
        aimbotColor = Color3.fromRGB(120, 255, 160),
        tpColor = Color3.fromRGB(80, 200, 255),
        invisibleColor = Color3.fromRGB(200, 200, 200),
        gradient1 = Color3.fromRGB(100, 180, 255),
        gradient2 = Color3.fromRGB(180, 100, 255),
    }

    local CLICK_SOUND_ID = "rbxassetid://452267918"
    local CLICK_VOLUME = 0.5

    local function playClickSound()
        pcall(function()
            local sound = Instance.new("Sound")
            sound.SoundId = CLICK_SOUND_ID
            sound.Volume = CLICK_VOLUME
            sound.Parent = gui
            sound:Play()
            game:GetService("Debris"):AddItem(sound, 2)
        end)
    end

    local fovCircle = Instance.new("Frame")
    fovCircle.Name = "FOV_Circle"
    fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
    fovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
    fovCircle.BackgroundTransparency = 1
    fovCircle.BorderSizePixel = 0
    fovCircle.Visible = false
    fovCircle.ZIndex = 999
    fovCircle.Parent = gui

    local fovCircleCorner = Instance.new("UICorner")
    fovCircleCorner.CornerRadius = UDim.new(1, 0)
    fovCircleCorner.Parent = fovCircle

    local fovCircleStroke = Instance.new("UIStroke")
    fovCircleStroke.Thickness = 2
    fovCircleStroke.Color = theme.aimbotColor
    fovCircleStroke.Transparency = 0.3
    fovCircleStroke.Parent = fovCircle

    local fovCenterDot = Instance.new("Frame")
    fovCenterDot.Size = UDim2.new(0, 4, 0, 4)
    fovCenterDot.AnchorPoint = Vector2.new(0.5, 0.5)
    fovCenterDot.Position = UDim2.new(0.5, 0, 0.5, 0)
    fovCenterDot.BackgroundColor3 = theme.aimbotColor
    fovCenterDot.BackgroundTransparency = 0.3
    fovCenterDot.BorderSizePixel = 0
    fovCenterDot.ZIndex = 1000
    fovCenterDot.Parent = fovCircle

    local fovCenterDotCorner = Instance.new("UICorner")
    fovCenterDotCorner.CornerRadius = UDim.new(1, 0)
    fovCenterDotCorner.Parent = fovCenterDot

    local function updateFovCircleVisual(fov)
        local size = fov * 2
        fovCircle.Size = UDim2.new(0, size, 0, size)
    end

    updateFovCircleVisual(aimbotModule.fov)

    aimbotModule.onFOVChanged = function(fov)
        updateFovCircleVisual(fov)
    end

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 220, 0, 720)
    mainFrame.Position = UDim2.new(0.5, -110, 0.5, -360)
    mainFrame.BackgroundColor3 = theme.background
    mainFrame.BackgroundTransparency = 0.08
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = mainFrame

    local auroraStroke = Instance.new("UIStroke")
    auroraStroke.Thickness = 2
    auroraStroke.Color = theme.accent
    auroraStroke.Transparency = 0.15
    auroraStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    auroraStroke.Parent = mainFrame

    local auroraGradient = Instance.new("UIGradient")
    auroraGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, theme.accent),
        ColorSequenceKeypoint.new(0.25, theme.espColor),
        ColorSequenceKeypoint.new(0.5, theme.flyColor),
        ColorSequenceKeypoint.new(0.75, theme.jumpColor),
        ColorSequenceKeypoint.new(1, theme.accent),
    })
    auroraGradient.Rotation = 0
    auroraGradient.Parent = auroraStroke

    task.spawn(function()
        local rotation = 0
        while gui.Parent do
            rotation = (rotation + 1) % 360
            auroraGradient.Rotation = rotation
            RunService.RenderStepped:Wait()
        end
    end)

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 52)
    header.BackgroundColor3 = theme.surface
    header.BackgroundTransparency = 0.5
    header.BorderSizePixel = 0
    header.Parent = mainFrame

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 14)
    headerCorner.Parent = header

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, theme.gradient1),
        ColorSequenceKeypoint.new(1, theme.gradient2)
    })
    gradient.Rotation = 45
    gradient.Parent = header

    local logoBox = Instance.new("Frame")
    logoBox.Size = UDim2.new(0, 26, 0, 26)
    logoBox.Position = UDim2.new(0, 10, 0.5, -13)
    logoBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    logoBox.BackgroundTransparency = 0.85
    logoBox.BorderSizePixel = 0
    logoBox.Parent = header

    local logoBoxCorner = Instance.new("UICorner")
    logoBoxCorner.CornerRadius = UDim.new(0, 8)
    logoBoxCorner.Parent = logoBox

    local logoBoxStroke = Instance.new("UIStroke")
    logoBoxStroke.Thickness = 1
    logoBoxStroke.Color = Color3.fromRGB(255, 255, 255)
    logoBoxStroke.Transparency = 0.4
    logoBoxStroke.Parent = logoBox

    task.spawn(function()
        while gui.Parent do
            TweenService:Create(logoBoxStroke, TweenInfo.new(1.5), {Transparency = 0.7}):Play()
            task.wait(1.5)
            TweenService:Create(logoBoxStroke, TweenInfo.new(1.5), {Transparency = 0.2}):Play()
            task.wait(1.5)
        end
    end)

    local titleIcon = Instance.new("TextLabel")
    titleIcon.Size = UDim2.new(1, 0, 1, 0)
    titleIcon.BackgroundTransparency = 1
    titleIcon.Text = "⚙"
    titleIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleIcon.TextSize = 15
    titleIcon.Font = Enum.Font.GothamBold
    titleIcon.Parent = logoBox

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.7, 0, 0, 18)
    title.Position = UDim2.new(0, 44, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "Basic Settings Control"
    title.TextColor3 = theme.text
    title.TextSize = 11
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.Parent = header

    local titleGrad = Instance.new("UIGradient")
    titleGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 220, 255)),
    })
    titleGrad.Rotation = 90
    titleGrad.Parent = title

    task.spawn(function()
        local rot = 0
        while gui.Parent do
            rot = (rot + 2) % 360
            titleGrad.Rotation = rot
            RunService.RenderStepped:Wait()
        end
    end)

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(0.7, 0, 0, 14)
    subtitle.Position = UDim2.new(0, 44, 0, 30)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Velocidade • Pulo • ESP • Noclip • Auto • Fly • Aim • TP • Hitbox • Invisible • Anti-AFK"
    subtitle.TextColor3 = theme.textSecondary
    subtitle.TextSize = 7
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = header

    local headerButtons = Instance.new("Frame")
    headerButtons.Size = UDim2.new(0, 56, 1, 0)
    headerButtons.Position = UDim2.new(1, -60, 0, 0)
    headerButtons.BackgroundTransparency = 1
    headerButtons.Parent = header

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 22, 0, 22)
    minBtn.Position = UDim2.new(0, 2, 0.5, -11)
    minBtn.BackgroundColor3 = theme.surface2
    minBtn.BackgroundTransparency = 0.5
    minBtn.Text = "−"
    minBtn.TextColor3 = theme.textSecondary
    minBtn.TextSize = 14
    minBtn.Font = Enum.Font.GothamBold
    minBtn.BorderSizePixel = 0
    minBtn.Parent = headerButtons

    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 6)
    minCorner.Parent = minBtn

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(1, -24, 0.5, -11)
    closeBtn.BackgroundColor3 = theme.surface2
    closeBtn.BackgroundTransparency = 0.5
    closeBtn.Text = "X"
    closeBtn.TextColor3 = theme.textSecondary
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = headerButtons

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn

    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -24, 1, -68)
    content.Position = UDim2.new(0, 12, 0, 60)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame

    local page1 = Instance.new("Frame")
    page1.Size = UDim2.new(1, 0, 1, 0)
    page1.BackgroundTransparency = 1
    page1.Visible = true
    page1.Parent = content

    local page2 = Instance.new("Frame")
    page2.Size = UDim2.new(1, 0, 1, 0)
    page2.BackgroundTransparency = 1
    page2.Visible = false
    page2.Parent = content

    local paginationWidget = Instance.new("Frame")
    paginationWidget.Size = UDim2.new(0, 70, 0, 22)
    paginationWidget.Position = UDim2.new(1, -72, 0, -4)
    paginationWidget.BackgroundColor3 = theme.surface2
    paginationWidget.BackgroundTransparency = 0.3
    paginationWidget.BorderSizePixel = 0
    paginationWidget.ZIndex = 50
    paginationWidget.Parent = content

    local pagCorner = Instance.new("UICorner")
    pagCorner.CornerRadius = UDim.new(0, 6)
    pagCorner.Parent = paginationWidget

    local pagStroke = Instance.new("UIStroke")
    pagStroke.Thickness = 1
    pagStroke.Color = theme.surface3
    pagStroke.Transparency = 0.3
    pagStroke.Parent = paginationWidget

    local prevPageBtn = Instance.new("TextButton")
    prevPageBtn.Size = UDim2.new(0, 18, 1, 0)
    prevPageBtn.BackgroundTransparency = 1
    prevPageBtn.Text = "‹"
    prevPageBtn.TextColor3 = theme.textSecondary
    prevPageBtn.TextSize = 14
    prevPageBtn.Font = Enum.Font.GothamBold
    prevPageBtn.ZIndex = 51
    prevPageBtn.Parent = paginationWidget

    local nextPageBtn = Instance.new("TextButton")
    nextPageBtn.Size = UDim2.new(0, 18, 1, 0)
    nextPageBtn.Position = UDim2.new(1, -18, 0, 0)
    nextPageBtn.BackgroundTransparency = 1
    nextPageBtn.Text = "›"
    nextPageBtn.TextColor3 = theme.textSecondary
    nextPageBtn.TextSize = 14
    nextPageBtn.Font = Enum.Font.GothamBold
    nextPageBtn.ZIndex = 51
    nextPageBtn.Parent = paginationWidget

    local pageIndicator = Instance.new("TextLabel")
    pageIndicator.Size = UDim2.new(1, -36, 1, 0)
    pageIndicator.Position = UDim2.new(0, 18, 0, 0)
    pageIndicator.BackgroundTransparency = 1
    pageIndicator.Text = "1/2"
    pageIndicator.TextColor3 = theme.textMuted
    pageIndicator.TextSize = 10
    pageIndicator.Font = Enum.Font.GothamBold
    pageIndicator.ZIndex = 51
    pageIndicator.Parent = paginationWidget

    local function createSectionIcon(parent, emoji, color)
        local iconBg = Instance.new("Frame")
        iconBg.Size = UDim2.new(0, 20, 0, 20)
        iconBg.Position = UDim2.new(0, 0, 0, 1)
        iconBg.BackgroundColor3 = color
        iconBg.BackgroundTransparency = 0.75
        iconBg.BorderSizePixel = 0
        iconBg.Parent = parent

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = iconBg

        local s = Instance.new("UIStroke")
        s.Thickness = 1
        s.Color = color
        s.Transparency = 0.5
        s.Parent = iconBg

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 1, 0)
        l.BackgroundTransparency = 1
        l.Text = emoji
        l.TextColor3 = color
        l.TextSize = 11
        l.Font = Enum.Font.GothamBold
        l.Parent = iconBg
    end

    local function createAccentBar(parent, color)
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 3, 0, 20)
        bar.Position = UDim2.new(0, 0, 0, 2)
        bar.BackgroundColor3 = color
        bar.BorderSizePixel = 0
        bar.Parent = parent

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 2)
        c.Parent = bar

        local g = Instance.new("UIStroke")
        g.Thickness = 4
        g.Color = color
        g.Transparency = 0.75
        g.Parent = bar

        task.spawn(function()
            while gui.Parent do
                TweenService:Create(g, TweenInfo.new(1.2), {Transparency = 0.9}):Play()
                task.wait(1.2)
                TweenService:Create(g, TweenInfo.new(1.2), {Transparency = 0.6}):Play()
                task.wait(1.2)
            end
        end)
    end

    -- ============================================
    -- VELOCIDADE
    -- ============================================
    local speedSection = Instance.new("Frame")
    speedSection.Size = UDim2.new(1, 0, 0, 132)
    speedSection.Position = UDim2.new(0, 0, 0, 0)
    speedSection.BackgroundTransparency = 1
    speedSection.Parent = page1

    createAccentBar(speedSection, theme.accent)

    local speedTitleContainer = Instance.new("Frame")
    speedTitleContainer.Size = UDim2.new(1, -12, 0, 22)
    speedTitleContainer.Position = UDim2.new(0, 12, 0, 0)
    speedTitleContainer.BackgroundTransparency = 1
    speedTitleContainer.Parent = speedSection

    createSectionIcon(speedTitleContainer, "⚡", theme.accent)

    local speedTitle = Instance.new("TextLabel")
    speedTitle.Size = UDim2.new(1, -30, 1, 0)
    speedTitle.Position = UDim2.new(0, 28, 0, 0)
    speedTitle.BackgroundTransparency = 1
    speedTitle.Text = "VELOCIDADE"
    speedTitle.TextColor3 = theme.textSecondary
    speedTitle.TextSize = 12
    speedTitle.Font = Enum.Font.GothamBold
    speedTitle.TextXAlignment = Enum.TextXAlignment.Left
    speedTitle.Parent = speedTitleContainer

    local speedDisplay = Instance.new("Frame")
    speedDisplay.Size = UDim2.new(0, 90, 0, 46)
    speedDisplay.Position = UDim2.new(0.5, -45, 0, 26)
    speedDisplay.BackgroundColor3 = theme.surface2
    speedDisplay.BackgroundTransparency = 0.3
    speedDisplay.BorderSizePixel = 0
    speedDisplay.Parent = speedSection

    local displayCorner = Instance.new("UICorner")
    displayCorner.CornerRadius = UDim.new(0, 10)
    displayCorner.Parent = speedDisplay

    local displayStroke = Instance.new("UIStroke")
    displayStroke.Thickness = 1
    displayStroke.Color = theme.accent
    displayStroke.Transparency = 0.5
    displayStroke.Parent = speedDisplay

    local speedValue = Instance.new("TextLabel")
    speedValue.Size = UDim2.new(1, 0, 0.7, 0)
    speedValue.Position = UDim2.new(0, 0, 0.15, 0)
    speedValue.BackgroundTransparency = 1
    speedValue.Text = "25"
    speedValue.TextColor3 = theme.accent
    speedValue.TextSize = 24
    speedValue.Font = Enum.Font.GothamBold
    speedValue.Parent = speedDisplay

    local sliderContainer = Instance.new("Frame")
    sliderContainer.Size = UDim2.new(1, -16, 0, 24)
    sliderContainer.Position = UDim2.new(0, 8, 0, 80)
    sliderContainer.BackgroundTransparency = 1
    sliderContainer.Parent = speedSection

    local minLabel = Instance.new("TextLabel")
    minLabel.Size = UDim2.new(0, 22, 1, 0)
    minLabel.BackgroundTransparency = 1
    minLabel.Text = "5"
    minLabel.TextColor3 = theme.textMuted
    minLabel.TextSize = 8
    minLabel.Font = Enum.Font.Gotham
    minLabel.Parent = sliderContainer

    local maxLabel = Instance.new("TextLabel")
    maxLabel.Size = UDim2.new(0, 22, 1, 0)
    maxLabel.Position = UDim2.new(1, -22, 0, 0)
    maxLabel.BackgroundTransparency = 1
    maxLabel.Text = "500"
    maxLabel.TextColor3 = theme.textMuted
    maxLabel.TextSize = 8
    maxLabel.Font = Enum.Font.Gotham
    maxLabel.Parent = sliderContainer

    local sliderTrack = Instance.new("Frame")
    sliderTrack.Size = UDim2.new(1, -56, 0, 4)
    sliderTrack.Position = UDim2.new(0, 28, 0.5, -2)
    sliderTrack.BackgroundColor3 = theme.surface3
    sliderTrack.BorderSizePixel = 0
    sliderTrack.Parent = sliderContainer

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = sliderTrack

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new(0, 0, 1, 0)
    sliderFill.BackgroundColor3 = theme.accent
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderTrack

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = sliderFill

    local sliderButton = Instance.new("TextButton")
    sliderButton.Size = UDim2.new(0, 13, 0, 13)
    sliderButton.Position = UDim2.new(0, 0, 0.5, -6.5)
    sliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sliderButton.BorderSizePixel = 0
    sliderButton.Text = ""
    sliderButton.ZIndex = 5
    sliderButton.Parent = sliderTrack

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(1, 0)
    buttonCorner.Parent = sliderButton

    local buttonStroke = Instance.new("UIStroke")
    buttonStroke.Thickness = 3
    buttonStroke.Color = theme.accent
    buttonStroke.Parent = sliderButton

    local speedToggleBtn = Instance.new("TextButton")
    speedToggleBtn.Size = UDim2.new(0, 90, 0, 30)
    speedToggleBtn.Position = UDim2.new(0.5, -45, 0, 106)
    speedToggleBtn.BackgroundColor3 = theme.danger
    speedToggleBtn.BackgroundTransparency = 0.15
    speedToggleBtn.Text = "OFF"
    speedToggleBtn.TextColor3 = theme.danger
    speedToggleBtn.TextSize = 13
    speedToggleBtn.Font = Enum.Font.GothamBold
    speedToggleBtn.BorderSizePixel = 2
    speedToggleBtn.BorderColor3 = theme.danger
    speedToggleBtn.Parent = speedSection

    local speedToggleCorner = Instance.new("UICorner")
    speedToggleCorner.CornerRadius = UDim.new(0, 8)
    speedToggleCorner.Parent = speedToggleBtn

    -- ============================================
    -- PULO
    -- ============================================
    local jumpSection = Instance.new("Frame")
    jumpSection.Size = UDim2.new(1, 0, 0, 80)
    jumpSection.Position = UDim2.new(0, 0, 0, 144)
    jumpSection.BackgroundTransparency = 1
    jumpSection.Parent = page1

    createAccentBar(jumpSection, theme.jumpColor)

    local jumpTitleContainer = Instance.new("Frame")
    jumpTitleContainer.Size = UDim2.new(1, -12, 0, 22)
    jumpTitleContainer.Position = UDim2.new(0, 12, 0, 0)
    jumpTitleContainer.BackgroundTransparency = 1
    jumpTitleContainer.Parent = jumpSection

    createSectionIcon(jumpTitleContainer, "🚀", theme.jumpColor)

    local jumpTitle = Instance.new("TextLabel")
    jumpTitle.Size = UDim2.new(1, -30, 1, 0)
    jumpTitle.Position = UDim2.new(0, 28, 0, 0)
    jumpTitle.BackgroundTransparency = 1
    jumpTitle.Text = "PULO INFINITO"
    jumpTitle.TextColor3 = theme.textSecondary
    jumpTitle.TextSize = 12
    jumpTitle.Font = Enum.Font.GothamBold
    jumpTitle.TextXAlignment = Enum.TextXAlignment.Left
    jumpTitle.Parent = jumpTitleContainer

    local jumpToggleBtn = Instance.new("TextButton")
    jumpToggleBtn.Size = UDim2.new(0, 90, 0, 30)
    jumpToggleBtn.Position = UDim2.new(0.5, -45, 0, 26)
    jumpToggleBtn.BackgroundColor3 = theme.danger
    jumpToggleBtn.BackgroundTransparency = 0.2
    jumpToggleBtn.Text = "OFF"
    jumpToggleBtn.TextColor3 = theme.danger
    jumpToggleBtn.TextSize = 13
    jumpToggleBtn.Font = Enum.Font.GothamBold
    jumpToggleBtn.BorderSizePixel = 2
    jumpToggleBtn.BorderColor3 = theme.danger
    jumpToggleBtn.Parent = jumpSection

    local jumpBtnCorner = Instance.new("UICorner")
    jumpBtnCorner.CornerRadius = UDim.new(0, 8)
    jumpBtnCorner.Parent = jumpToggleBtn

    local jumpStatusLabel = Instance.new("TextLabel")
    jumpStatusLabel.Size = UDim2.new(1, 0, 0, 16)
    jumpStatusLabel.Position = UDim2.new(0, 0, 0, 62)
    jumpStatusLabel.BackgroundTransparency = 1
    jumpStatusLabel.Text = "Espaço para pular"
    jumpStatusLabel.TextColor3 = theme.textMuted
    jumpStatusLabel.TextSize = 10
    jumpStatusLabel.Font = Enum.Font.Gotham
    jumpStatusLabel.Parent = jumpSection

    -- ============================================
    -- ESP
    -- ============================================
    local espSection = Instance.new("Frame")
    espSection.Size = UDim2.new(1, 0, 0, 84)
    espSection.Position = UDim2.new(0, 0, 0, 232)
    espSection.BackgroundTransparency = 1
    espSection.Parent = page1

    createAccentBar(espSection, theme.espColor)

    local espTitleContainer = Instance.new("Frame")
    espTitleContainer.Size = UDim2.new(1, -12, 0, 22)
    espTitleContainer.Position = UDim2.new(0, 12, 0, 0)
    espTitleContainer.BackgroundTransparency = 1
    espTitleContainer.Parent = espSection

    createSectionIcon(espTitleContainer, "👁", theme.espColor)

    local espTitle = Instance.new("TextLabel")
    espTitle.Size = UDim2.new(1, -30, 1, 0)
    espTitle.Position = UDim2.new(0, 28, 0, 0)
    espTitle.BackgroundTransparency = 1
    espTitle.Text = "ESP"
    espTitle.TextColor3 = theme.textSecondary
    espTitle.TextSize = 12
    espTitle.Font = Enum.Font.GothamBold
    espTitle.TextXAlignment = Enum.TextXAlignment.Left
    espTitle.Parent = espTitleContainer

    local espToggleBtn = Instance.new("TextButton")
    espToggleBtn.Size = UDim2.new(0, 90, 0, 30)
    espToggleBtn.Position = UDim2.new(0.5, -45, 0, 26)
    espToggleBtn.BackgroundColor3 = theme.danger
    espToggleBtn.BackgroundTransparency = 0.2
    espToggleBtn.Text = "OFF"
    espToggleBtn.TextColor3 = theme.danger
    espToggleBtn.TextSize = 13
    espToggleBtn.Font = Enum.Font.GothamBold
    espToggleBtn.BorderSizePixel = 2
    espToggleBtn.BorderColor3 = theme.danger
    espToggleBtn.Parent = espSection

    local espBtnCorner = Instance.new("UICorner")
    espBtnCorner.CornerRadius = UDim.new(0, 8)
    espBtnCorner.Parent = espToggleBtn

    local espStatusLabel = Instance.new("TextLabel")
    espStatusLabel.Size = UDim2.new(1, 0, 0, 16)
    espStatusLabel.Position = UDim2.new(0, 0, 0, 66)
    espStatusLabel.BackgroundTransparency = 1
    espStatusLabel.Text = "Nome • Distância • Chams"
    espStatusLabel.TextColor3 = theme.textMuted
    espStatusLabel.TextSize = 10
    espStatusLabel.Font = Enum.Font.Gotham
    espStatusLabel.Parent = espSection

    -- ============================================
    -- NOCLIP
    -- ============================================
    local noclipSection = Instance.new("Frame")
    noclipSection.Size = UDim2.new(1, 0, 0, 84)
    noclipSection.Position = UDim2.new(0, 0, 0, 320)
    noclipSection.BackgroundTransparency = 1
    noclipSection.Parent = page1

    createAccentBar(noclipSection, theme.noclipColor)

    local noclipTitleContainer = Instance.new("Frame")
    noclipTitleContainer.Size = UDim2.new(1, -12, 0, 22)
    noclipTitleContainer.Position = UDim2.new(0, 12, 0, 0)
    noclipTitleContainer.BackgroundTransparency = 1
    noclipTitleContainer.Parent = noclipSection

    createSectionIcon(noclipTitleContainer, "👻", theme.noclipColor)

    local noclipTitle = Instance.new("TextLabel")
    noclipTitle.Size = UDim2.new(1, -30, 1, 0)
    noclipTitle.Position = UDim2.new(0, 28, 0, 0)
    noclipTitle.BackgroundTransparency = 1
    noclipTitle.Text = "NOCLIP"
    noclipTitle.TextColor3 = theme.textSecondary
    noclipTitle.TextSize = 12
    noclipTitle.Font = Enum.Font.GothamBold
    noclipTitle.TextXAlignment = Enum.TextXAlignment.Left
    noclipTitle.Parent = noclipTitleContainer

    local noclipToggleBtn = Instance.new("TextButton")
    noclipToggleBtn.Size = UDim2.new(0, 90, 0, 30)
    noclipToggleBtn.Position = UDim2.new(0.5, -45, 0, 26)
    noclipToggleBtn.BackgroundColor3 = theme.danger
    noclipToggleBtn.BackgroundTransparency = 0.2
    noclipToggleBtn.Text = "OFF"
    noclipToggleBtn.TextColor3 = theme.danger
    noclipToggleBtn.TextSize = 13
    noclipToggleBtn.Font = Enum.Font.GothamBold
    noclipToggleBtn.BorderSizePixel = 2
    noclipToggleBtn.BorderColor3 = theme.danger
    noclipToggleBtn.Parent = noclipSection

    local noclipBtnCorner = Instance.new("UICorner")
    noclipBtnCorner.CornerRadius = UDim.new(0, 8)
    noclipBtnCorner.Parent = noclipToggleBtn

    local noclipStatusLabel = Instance.new("TextLabel")
    noclipStatusLabel.Size = UDim2.new(1, 0, 0, 16)
    noclipStatusLabel.Position = UDim2.new(0, 0, 0, 66)
    noclipStatusLabel.BackgroundTransparency = 1
    noclipStatusLabel.Text = "Atravesse paredes"
    noclipStatusLabel.TextColor3 = theme.textMuted
    noclipStatusLabel.TextSize = 10
    noclipStatusLabel.Font = Enum.Font.Gotham
    noclipStatusLabel.Parent = noclipSection

    -- ============================================
    -- AUTO PRESSER
    -- ============================================
    local autoSection = Instance.new("Frame")
    autoSection.Size = UDim2.new(1, 0, 0, 128)
    autoSection.Position = UDim2.new(0, 0, 0, 404)
    autoSection.BackgroundTransparency = 1
    autoSection.Parent = page1

    createAccentBar(autoSection, theme.autoPresserColor)

    local autoTitleContainer = Instance.new("Frame")
    autoTitleContainer.Size = UDim2.new(1, -12, 0, 22)
    autoTitleContainer.Position = UDim2.new(0, 12, 0, 0)
    autoTitleContainer.BackgroundTransparency = 1
    autoTitleContainer.Parent = autoSection

    createSectionIcon(autoTitleContainer, "🖱", theme.autoPresserColor)

    local autoTitle = Instance.new("TextLabel")
    autoTitle.Size = UDim2.new(1, -30, 1, 0)
    autoTitle.Position = UDim2.new(0, 28, 0, 0)
    autoTitle.BackgroundTransparency = 1
    autoTitle.Text = "AUTO PRESSER"
    autoTitle.TextColor3 = theme.textSecondary
    autoTitle.TextSize = 12
    autoTitle.Font = Enum.Font.GothamBold
    autoTitle.TextXAlignment = Enum.TextXAlignment.Left
    autoTitle.Parent = autoTitleContainer

    local autoToggleBtn = Instance.new("TextButton")
    autoToggleBtn.Size = UDim2.new(0, 90, 0, 30)
    autoToggleBtn.Position = UDim2.new(0.5, -45, 0, 26)
    autoToggleBtn.BackgroundColor3 = theme.danger
    autoToggleBtn.BackgroundTransparency = 0.2
    autoToggleBtn.Text = "OFF"
    autoToggleBtn.TextColor3 = theme.danger
    autoToggleBtn.TextSize = 13
    autoToggleBtn.Font = Enum.Font.GothamBold
    autoToggleBtn.BorderSizePixel = 2
    autoToggleBtn.BorderColor3 = theme.danger
    autoToggleBtn.Parent = autoSection

    local autoCorner = Instance.new("UICorner")
    autoCorner.CornerRadius = UDim.new(0, 8)
    autoCorner.Parent = autoToggleBtn

    local autoStatusLabel = Instance.new("TextLabel")
    autoStatusLabel.Size = UDim2.new(1, 0, 0, 16)
    autoStatusLabel.Position = UDim2.new(0, 0, 0, 66)
    autoStatusLabel.BackgroundTransparency = 1
    autoStatusLabel.Text = "Ativa/Desativa com [R] • Segura [E]"
    autoStatusLabel.TextColor3 = theme.textMuted
    autoStatusLabel.TextSize = 10
    autoStatusLabel.Font = Enum.Font.Gotham
    autoStatusLabel.Parent = autoSection

    local keySelectorContainer = Instance.new("Frame")
    keySelectorContainer.Size = UDim2.new(1, 0, 0, 42)
    keySelectorContainer.Position = UDim2.new(0, 0, 0, 84)
    keySelectorContainer.BackgroundTransparency = 1
    keySelectorContainer.Parent = autoSection

    local toggleKeyBtn = Instance.new("TextButton")
    toggleKeyBtn.Size = UDim2.new(0.5, -6, 0, 30)
    toggleKeyBtn.BackgroundColor3 = theme.surface2
    toggleKeyBtn.BackgroundTransparency = 0.3
    toggleKeyBtn.Text = "R"
    toggleKeyBtn.TextColor3 = theme.autoPresserColor
    toggleKeyBtn.TextSize = 15
    toggleKeyBtn.Font = Enum.Font.GothamBold
    toggleKeyBtn.BorderSizePixel = 2
    toggleKeyBtn.BorderColor3 = theme.autoPresserColor
    toggleKeyBtn.Parent = keySelectorContainer

    local tKeyCorner = Instance.new("UICorner")
    tKeyCorner.CornerRadius = UDim.new(0, 8)
    tKeyCorner.Parent = toggleKeyBtn

    local tKeyCaption = Instance.new("TextLabel")
    tKeyCaption.Size = UDim2.new(0.5, -6, 0, 12)
    tKeyCaption.Position = UDim2.new(0, 0, 1, -12)
    tKeyCaption.BackgroundTransparency = 1
    tKeyCaption.Text = "TECLA ATIVA"
    tKeyCaption.TextColor3 = theme.textMuted
    tKeyCaption.TextSize = 8
    tKeyCaption.Font = Enum.Font.GothamBold
    tKeyCaption.Parent = keySelectorContainer

    local pressKeyBtn = Instance.new("TextButton")
    pressKeyBtn.Size = UDim2.new(0.5, -6, 0, 30)
    pressKeyBtn.Position = UDim2.new(0.5, 6, 0, 0)
    pressKeyBtn.BackgroundColor3 = theme.surface2
    pressKeyBtn.BackgroundTransparency = 0.3
    pressKeyBtn.Text = "E"
    pressKeyBtn.TextColor3 = theme.autoPresserColor
    pressKeyBtn.TextSize = 15
    pressKeyBtn.Font = Enum.Font.GothamBold
    pressKeyBtn.BorderSizePixel = 2
    pressKeyBtn.BorderColor3 = theme.autoPresserColor
    pressKeyBtn.Parent = keySelectorContainer

    local pKeyCorner = Instance.new("UICorner")
    pKeyCorner.CornerRadius = UDim.new(0, 8)
    pKeyCorner.Parent = pressKeyBtn

    local pKeyCaption = Instance.new("TextLabel")
    pKeyCaption.Size = UDim2.new(0.5, -6, 0, 12)
    pKeyCaption.Position = UDim2.new(0.5, 6, 1, -12)
    pKeyCaption.BackgroundTransparency = 1
    pKeyCaption.Text = "TECLA SEGURA"
    pKeyCaption.TextColor3 = theme.textMuted
    pKeyCaption.TextSize = 8
    pKeyCaption.Font = Enum.Font.GothamBold
    pKeyCaption.Parent = keySelectorContainer

    -- ============================================
    -- FLY
    -- ============================================
    local flySection = Instance.new("Frame")
    flySection.Size = UDim2.new(1, 0, 0, 116)
    flySection.Position = UDim2.new(0, 0, 0, 532)
    flySection.BackgroundTransparency = 1
    flySection.Parent = page1

    createAccentBar(flySection, theme.flyColor)

    local flyTitleContainer = Instance.new("Frame")
    flyTitleContainer.Size = UDim2.new(1, -12, 0, 22)
    flyTitleContainer.Position = UDim2.new(0, 12, 0, 0)
    flyTitleContainer.BackgroundTransparency = 1
    flyTitleContainer.Parent = flySection

    createSectionIcon(flyTitleContainer, "✈", theme.flyColor)

    local flyTitle = Instance.new("TextLabel")
    flyTitle.Size = UDim2.new(1, -30, 1, 0)
    flyTitle.Position = UDim2.new(0, 28, 0, 0)
    flyTitle.BackgroundTransparency = 1
    flyTitle.Text = "FLY"
    flyTitle.TextColor3 = theme.textSecondary
    flyTitle.TextSize = 12
    flyTitle.Font = Enum.Font.GothamBold
    flyTitle.TextXAlignment = Enum.TextXAlignment.Left
    flyTitle.Parent = flyTitleContainer

    local flySpeedValue = Instance.new("TextLabel")
    flySpeedValue.Size = UDim2.new(0, 76, 0, 28)
    flySpeedValue.Position = UDim2.new(0.5, -38, 0, 26)
    flySpeedValue.BackgroundColor3 = theme.surface2
    flySpeedValue.BackgroundTransparency = 0.3
    flySpeedValue.Text = tostring(flyModule.speed)
    flySpeedValue.TextColor3 = theme.flyColor
    flySpeedValue.TextSize = 16
    flySpeedValue.Font = Enum.Font.GothamBold
    flySpeedValue.Parent = flySection

    local flySpeedValueCorner = Instance.new("UICorner")
    flySpeedValueCorner.CornerRadius = UDim.new(0, 8)
    flySpeedValueCorner.Parent = flySpeedValue

    local flySliderContainer = Instance.new("Frame")
    flySliderContainer.Size = UDim2.new(1, -16, 0, 20)
    flySliderContainer.Position = UDim2.new(0, 8, 0, 60)
    flySliderContainer.BackgroundTransparency = 1
    flySliderContainer.Parent = flySection

    local flyMinLabel = Instance.new("TextLabel")
    flyMinLabel.Size = UDim2.new(0, 16, 1, 0)
    flyMinLabel.BackgroundTransparency = 1
    flyMinLabel.Text = "1"
    flyMinLabel.TextColor3 = theme.textMuted
    flyMinLabel.TextSize = 7
    flyMinLabel.Font = Enum.Font.Gotham
    flyMinLabel.Parent = flySliderContainer

    local flyMaxLabel = Instance.new("TextLabel")
    flyMaxLabel.Size = UDim2.new(0, 16, 1, 0)
    flyMaxLabel.Position = UDim2.new(1, -16, 0, 0)
    flyMaxLabel.BackgroundTransparency = 1
    flyMaxLabel.Text = "10"
    flyMaxLabel.TextColor3 = theme.textMuted
    flyMaxLabel.TextSize = 7
    flyMaxLabel.Font = Enum.Font.Gotham
    flyMaxLabel.Parent = flySliderContainer

    local flySliderTrack = Instance.new("Frame")
    flySliderTrack.Size = UDim2.new(1, -44, 0, 4)
    flySliderTrack.Position = UDim2.new(0, 22, 0.5, -2)
    flySliderTrack.BackgroundColor3 = theme.surface3
    flySliderTrack.BorderSizePixel = 0
    flySliderTrack.Parent = flySliderContainer

    local flyTrackCorner = Instance.new("UICorner")
    flyTrackCorner.CornerRadius = UDim.new(1, 0)
    flyTrackCorner.Parent = flySliderTrack

    local flySliderFill = Instance.new("Frame")
    flySliderFill.Size = UDim2.new(0, 0, 1, 0)
    flySliderFill.BackgroundColor3 = theme.flyColor
    flySliderFill.BorderSizePixel = 0
    flySliderFill.Parent = flySliderTrack

    local flyFillCorner = Instance.new("UICorner")
    flyFillCorner.CornerRadius = UDim.new(1, 0)
    flyFillCorner.Parent = flySliderFill

    local flySliderButton = Instance.new("TextButton")
    flySliderButton.Size = UDim2.new(0, 11, 0, 11)
    flySliderButton.Position = UDim2.new(0, 0, 0.5, -5.5)
    flySliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flySliderButton.BorderSizePixel = 0
    flySliderButton.Text = ""
    flySliderButton.ZIndex = 5
    flySliderButton.Parent = flySliderTrack

    local flyButtonCorner = Instance.new("UICorner")
    flyButtonCorner.CornerRadius = UDim.new(1, 0)
    flyButtonCorner.Parent = flySliderButton

    local flyButtonStroke = Instance.new("UIStroke")
    flyButtonStroke.Thickness = 3
    flyButtonStroke.Color = theme.flyColor
    flyButtonStroke.Parent = flySliderButton

    local flyToggleBtn = Instance.new("TextButton")
    flyToggleBtn.Size = UDim2.new(0, 90, 0, 30)
    flyToggleBtn.Position = UDim2.new(0.5, -45, 0, 82)
    flyToggleBtn.BackgroundColor3 = theme.danger
    flyToggleBtn.BackgroundTransparency = 0.2
    flyToggleBtn.Text = "OFF"
    flyToggleBtn.TextColor3 = theme.danger
    flyToggleBtn.TextSize = 13
    flyToggleBtn.Font = Enum.Font.GothamBold
    flyToggleBtn.BorderSizePixel = 2
    flyToggleBtn.BorderColor3 = theme.danger
    flyToggleBtn.Parent = flySection

    local flyBtnCorner = Instance.new("UICorner")
    flyBtnCorner.CornerRadius = UDim.new(0, 8)
    flyBtnCorner.Parent = flyToggleBtn

    -- ============================================
    -- AIMBOT (página 2) — Y=0 — emoji 🤖
    -- ============================================
    local aimbotSection = Instance.new("Frame")
    aimbotSection.Size = UDim2.new(1, 0, 0, 130)
    aimbotSection.Position = UDim2.new(0, 0, 0, 0)
    aimbotSection.BackgroundTransparency = 1
    aimbotSection.Parent = page2

    createAccentBar(aimbotSection, theme.aimbotColor)

    local aimbotTitleContainer = Instance.new("Frame")
    aimbotTitleContainer.Size = UDim2.new(1, -12, 0, 22)
    aimbotTitleContainer.Position = UDim2.new(0, 12, 0, 0)
    aimbotTitleContainer.BackgroundTransparency = 1
    aimbotTitleContainer.Parent = aimbotSection

    createSectionIcon(aimbotTitleContainer, "🤖", theme.aimbotColor)

    local aimbotTitle = Instance.new("TextLabel")
    aimbotTitle.Size = UDim2.new(1, -30, 1, 0)
    aimbotTitle.Position = UDim2.new(0, 28, 0, 0)
    aimbotTitle.BackgroundTransparency = 1
    aimbotTitle.Text = "AIMBOT"
    aimbotTitle.TextColor3 = theme.textSecondary
    aimbotTitle.TextSize = 12
    aimbotTitle.Font = Enum.Font.GothamBold
    aimbotTitle.TextXAlignment = Enum.TextXAlignment.Left
    aimbotTitle.Parent = aimbotTitleContainer

    local aimbotContent = Instance.new("Frame")
    aimbotContent.Size = UDim2.new(1, 0, 0, 88)
    aimbotContent.Position = UDim2.new(0, 0, 0, 26)
    aimbotContent.BackgroundTransparency = 1
    aimbotContent.Parent = aimbotSection

    local aimbotToggleBtn = Instance.new("TextButton")
    aimbotToggleBtn.Size = UDim2.new(0, 90, 0, 34)
    aimbotToggleBtn.Position = UDim2.new(0, 20, 0.5, -17)
    aimbotToggleBtn.BackgroundColor3 = theme.danger
    aimbotToggleBtn.BackgroundTransparency = 0.2
    aimbotToggleBtn.Text = "OFF"
    aimbotToggleBtn.TextColor3 = theme.danger
    aimbotToggleBtn.TextSize = 14
    aimbotToggleBtn.Font = Enum.Font.GothamBold
    aimbotToggleBtn.BorderSizePixel = 2
    aimbotToggleBtn.BorderColor3 = theme.danger
    aimbotToggleBtn.Parent = aimbotContent

    local aimbotBtnCorner = Instance.new("UICorner")
    aimbotBtnCorner.CornerRadius = UDim.new(0, 8)
    aimbotBtnCorner.Parent = aimbotToggleBtn

    local fovShowBtn = Instance.new("TextButton")
    fovShowBtn.Size = UDim2.new(0, 26, 0, 28)
    fovShowBtn.Position = UDim2.new(0, 112, 0.5, -14)
    fovShowBtn.BackgroundColor3 = theme.surface2
    fovShowBtn.BackgroundTransparency = 0.3
    fovShowBtn.Text = "◯"
    fovShowBtn.TextColor3 = theme.textMuted
    fovShowBtn.TextSize = 14
    fovShowBtn.Font = Enum.Font.GothamBold
    fovShowBtn.BorderSizePixel = 2
    fovShowBtn.BorderColor3 = theme.aimbotColor
    fovShowBtn.Parent = aimbotContent

    local fovShowBtnCorner = Instance.new("UICorner")
    fovShowBtnCorner.CornerRadius = UDim.new(0, 8)
    fovShowBtnCorner.Parent = fovShowBtn

    local aimbotSliderColumn = Instance.new("Frame")
    aimbotSliderColumn.Size = UDim2.new(0, 44, 0, 88)
    aimbotSliderColumn.Position = UDim2.new(1, -52, 0, 0)
    aimbotSliderColumn.BackgroundTransparency = 1
    aimbotSliderColumn.Parent = aimbotContent

    local aimbotValueLabel = Instance.new("TextLabel")
    aimbotValueLabel.Size = UDim2.new(0, 32, 0, 16)
    aimbotValueLabel.Position = UDim2.new(0.5, -16, 0, 0)
    aimbotValueLabel.BackgroundColor3 = theme.surface2
    aimbotValueLabel.BackgroundTransparency = 0.3
    aimbotValueLabel.Text = "2"
    aimbotValueLabel.TextColor3 = theme.aimbotColor
    aimbotValueLabel.TextSize = 12
    aimbotValueLabel.Font = Enum.Font.GothamBold
    aimbotValueLabel.Parent = aimbotSliderColumn

    local aimbotValueCorner = Instance.new("UICorner")
    aimbotValueCorner.CornerRadius = UDim.new(0, 6)
    aimbotValueCorner.Parent = aimbotValueLabel

    local aimbotValueStroke = Instance.new("UIStroke")
    aimbotValueStroke.Thickness = 1
    aimbotValueStroke.Color = theme.aimbotColor
    aimbotValueStroke.Transparency = 0.5
    aimbotValueStroke.Parent = aimbotValueLabel

    local aimbotSliderTrack = Instance.new("Frame")
    aimbotSliderTrack.Size = UDim2.new(0, 4, 0, 44)
    aimbotSliderTrack.Position = UDim2.new(0, 8, 0, 20)
    aimbotSliderTrack.BackgroundColor3 = theme.surface3
    aimbotSliderTrack.BorderSizePixel = 0
    aimbotSliderTrack.ClipsDescendants = false
    aimbotSliderTrack.Parent = aimbotSliderColumn

    local aimbotTrackCorner = Instance.new("UICorner")
    aimbotTrackCorner.CornerRadius = UDim.new(1, 0)
    aimbotTrackCorner.Parent = aimbotSliderTrack

    local aimbotSliderFill = Instance.new("Frame")
    aimbotSliderFill.AnchorPoint = Vector2.new(0, 1)
    aimbotSliderFill.Size = UDim2.new(1, 0, 0, 0)
    aimbotSliderFill.Position = UDim2.new(0, 0, 1, 0)
    aimbotSliderFill.BackgroundColor3 = theme.aimbotColor
    aimbotSliderFill.BorderSizePixel = 0
    aimbotSliderFill.Parent = aimbotSliderTrack

    local aimbotFillCorner = Instance.new("UICorner")
    aimbotFillCorner.CornerRadius = UDim.new(1, 0)
    aimbotFillCorner.Parent = aimbotSliderFill

    local aimbotSliderButton = Instance.new("TextButton")
    aimbotSliderButton.Size = UDim2.new(0, 11, 0, 11)
    aimbotSliderButton.AnchorPoint = Vector2.new(0.5, 0.5)
    aimbotSliderButton.Position = UDim2.new(0.5, 0, 1, 0)
    aimbotSliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    aimbotSliderButton.BorderSizePixel = 0
    aimbotSliderButton.Text = ""
    aimbotSliderButton.ZIndex = 5
    aimbotSliderButton.Parent = aimbotSliderTrack

    local aimbotButtonCorner = Instance.new("UICorner")
    aimbotButtonCorner.CornerRadius = UDim.new(1, 0)
    aimbotButtonCorner.Parent = aimbotSliderButton

    local aimbotButtonStroke = Instance.new("UIStroke")
    aimbotButtonStroke.Thickness = 3
    aimbotButtonStroke.Color = theme.aimbotColor
    aimbotButtonStroke.Parent = aimbotSliderButton

    local aimbotMaxLabel = Instance.new("TextLabel")
    aimbotMaxLabel.Size = UDim2.new(0, 20, 0, 10)
    aimbotMaxLabel.Position = UDim2.new(0, 16, 0, 18)
    aimbotMaxLabel.BackgroundTransparency = 1
    aimbotMaxLabel.Text = "10"
    aimbotMaxLabel.TextColor3 = theme.textMuted
    aimbotMaxLabel.TextSize = 7
    aimbotMaxLabel.Font = Enum.Font.Gotham
    aimbotMaxLabel.TextXAlignment = Enum.TextXAlignment.Left
    aimbotMaxLabel.Parent = aimbotSliderColumn

    local aimbotMinLabel = Instance.new("TextLabel")
    aimbotMinLabel.Size = UDim2.new(0, 20, 0, 10)
    aimbotMinLabel.Position = UDim2.new(0, 16, 0, 56)
    aimbotMinLabel.BackgroundTransparency = 1
    aimbotMinLabel.Text = "1"
    aimbotMinLabel.TextColor3 = theme.textMuted
    aimbotMinLabel.TextSize = 7
    aimbotMinLabel.Font = Enum.Font.Gotham
    aimbotMinLabel.TextXAlignment = Enum.TextXAlignment.Left
    aimbotMinLabel.Parent = aimbotSliderColumn

    local aimbotCaption = Instance.new("TextLabel")
    aimbotCaption.Size = UDim2.new(1, 0, 0, 10)
    aimbotCaption.Position = UDim2.new(0, 0, 1, -10)
    aimbotCaption.BackgroundTransparency = 1
    aimbotCaption.Text = "FOV"
    aimbotCaption.TextColor3 = theme.textMuted
    aimbotCaption.TextSize = 7
    aimbotCaption.Font = Enum.Font.GothamBold
    aimbotCaption.Parent = aimbotSliderColumn

    local aimbotStatusLabel = Instance.new("TextLabel")
    aimbotStatusLabel.Size = UDim2.new(1, 0, 0, 14)
    aimbotStatusLabel.Position = UDim2.new(0, 0, 0, 116)
    aimbotStatusLabel.BackgroundTransparency = 1
    aimbotStatusLabel.Text = "Aimbot sempre ativo quando ligado"
    aimbotStatusLabel.TextColor3 = theme.textMuted
    aimbotStatusLabel.TextSize = 10
    aimbotStatusLabel.Font = Enum.Font.Gotham
    aimbotStatusLabel.Parent = aimbotSection

    -- ============================================
    -- TP CLICK (página 2) — Y=142
    -- ============================================
    local tpSection = Instance.new("Frame")
    tpSection.Size = UDim2.new(1, 0, 0, 110)
    tpSection.Position = UDim2.new(0, 0, 0, 142)
    tpSection.BackgroundTransparency = 1
    tpSection.Parent = page2

    createAccentBar(tpSection, theme.tpColor)

    local tpTitleContainer = Instance.new("Frame")
    tpTitleContainer.Size = UDim2.new(1, -12, 0, 22)
    tpTitleContainer.Position = UDim2.new(0, 12, 0, 0)
    tpTitleContainer.BackgroundTransparency = 1
    tpTitleContainer.Parent = tpSection

    createSectionIcon(tpTitleContainer, "🌀", theme.tpColor)

    local tpTitle = Instance.new("TextLabel")
    tpTitle.Size = UDim2.new(1, -30, 1, 0)
    tpTitle.Position = UDim2.new(0, 28, 0, 0)
    tpTitle.BackgroundTransparency = 1
    tpTitle.Text = "TP CLICK"
    tpTitle.TextColor3 = theme.textSecondary
    tpTitle.TextSize = 12
    tpTitle.Font = Enum.Font.GothamBold
    tpTitle.TextXAlignment = Enum.TextXAlignment.Left
    tpTitle.Parent = tpTitleContainer

    local tpContent = Instance.new("Frame")
    tpContent.Size = UDim2.new(1, 0, 0, 68)
    tpContent.Position = UDim2.new(0, 0, 0, 26)
    tpContent.BackgroundTransparency = 1
    tpContent.Parent = tpSection

    local tpToggleBtn = Instance.new("TextButton")
    tpToggleBtn.Size = UDim2.new(0, 90, 0, 34)
    tpToggleBtn.Position = UDim2.new(0.5, -45, 0, 0)
    tpToggleBtn.BackgroundColor3 = theme.danger
    tpToggleBtn.BackgroundTransparency = 0.2
    tpToggleBtn.Text = "OFF"
    tpToggleBtn.TextColor3 = theme.danger
    tpToggleBtn.TextSize = 14
    tpToggleBtn.Font = Enum.Font.GothamBold
    tpToggleBtn.BorderSizePixel = 2
    tpToggleBtn.BorderColor3 = theme.danger
    tpToggleBtn.Parent = tpContent

    local tpBtnCorner = Instance.new("UICorner")
    tpBtnCorner.CornerRadius = UDim.new(0, 8)
    tpBtnCorner.Parent = tpToggleBtn

    local tpStatusLabel = Instance.new("TextLabel")
    tpStatusLabel.Size = UDim2.new(1, 0, 0, 14)
    tpStatusLabel.Position = UDim2.new(0, 0, 0, 42)
    tpStatusLabel.BackgroundTransparency = 1
    tpStatusLabel.Text = "Ctrl + Clique Esquerdo"
    tpStatusLabel.TextColor3 = theme.textMuted
    tpStatusLabel.TextSize = 10
    tpStatusLabel.Font = Enum.Font.Gotham
    tpStatusLabel.Parent = tpContent

    -- ============================================
    -- HITBOX (página 2) — Y=238 — emoji 🎯
    -- ============================================
    local hitboxSection = Instance.new("Frame")
    hitboxSection.Size = UDim2.new(1, 0, 0, 84)
    hitboxSection.Position = UDim2.new(0, 0, 0, 238)
    hitboxSection.BackgroundTransparency = 1
    hitboxSection.Parent = page2

    createAccentBar(hitboxSection, theme.hitboxColor)

    local hitboxTitleContainer = Instance.new("Frame")
    hitboxTitleContainer.Size = UDim2.new(1, -12, 0, 22)
    hitboxTitleContainer.Position = UDim2.new(0, 12, 0, 0)
    hitboxTitleContainer.BackgroundTransparency = 1
    hitboxTitleContainer.Parent = hitboxSection

    createSectionIcon(hitboxTitleContainer, "🎯", theme.hitboxColor)

    local hitboxTitle = Instance.new("TextLabel")
    hitboxTitle.Size = UDim2.new(1, -30, 1, 0)
    hitboxTitle.Position = UDim2.new(0, 28, 0, 0)
    hitboxTitle.BackgroundTransparency = 1
    hitboxTitle.Text = "HITBOX EXPANDER"
    hitboxTitle.TextColor3 = theme.textSecondary
    hitboxTitle.TextSize = 12
    hitboxTitle.Font = Enum.Font.GothamBold
    hitboxTitle.TextXAlignment = Enum.TextXAlignment.Left
    hitboxTitle.Parent = hitboxTitleContainer

    local hitboxToggleBtn = Instance.new("TextButton")
    hitboxToggleBtn.Size = UDim2.new(0, 90, 0, 30)
    hitboxToggleBtn.Position = UDim2.new(0.5, -48, 0, 26)
    hitboxToggleBtn.BackgroundColor3 = theme.danger
    hitboxToggleBtn.BackgroundTransparency = 0.2
    hitboxToggleBtn.Text = "OFF"
    hitboxToggleBtn.TextColor3 = theme.danger
    hitboxToggleBtn.TextSize = 13
    hitboxToggleBtn.Font = Enum.Font.GothamBold
    hitboxToggleBtn.BorderSizePixel = 2
    hitboxToggleBtn.BorderColor3 = theme.danger
    hitboxToggleBtn.Parent = hitboxSection

    local hitboxBtnCorner = Instance.new("UICorner")
    hitboxBtnCorner.CornerRadius = UDim.new(0, 8)
    hitboxBtnCorner.Parent = hitboxToggleBtn

    local hitboxViewBtn = Instance.new("TextButton")
    hitboxViewBtn.Size = UDim2.new(0, 30, 0, 30)
    hitboxViewBtn.Position = UDim2.new(0.5, 48, 0, 26)
    hitboxViewBtn.BackgroundColor3 = theme.surface2
    hitboxViewBtn.BackgroundTransparency = 0.3
    hitboxViewBtn.Text = "👁"
    hitboxViewBtn.TextColor3 = theme.textMuted
    hitboxViewBtn.TextSize = 16
    hitboxViewBtn.Font = Enum.Font.GothamBold
    hitboxViewBtn.BorderSizePixel = 2
    hitboxViewBtn.BorderColor3 = theme.danger
    hitboxViewBtn.Parent = hitboxSection

    local hitboxViewCorner = Instance.new("UICorner")
    hitboxViewCorner.CornerRadius = UDim.new(0, 8)
    hitboxViewCorner.Parent = hitboxViewBtn

    local xOverlay1 = Instance.new("Frame")
    xOverlay1.Size = UDim2.new(0, 20, 0, 2)
    xOverlay1.Position = UDim2.new(0.5, -10, 0.5, -1)
    xOverlay1.BackgroundColor3 = Color3.fromRGB(255, 82, 82)
    xOverlay1.BorderSizePixel = 0
    xOverlay1.Rotation = 45
    xOverlay1.ZIndex = 3
    xOverlay1.Parent = hitboxViewBtn

    local xOverlay1Corner = Instance.new("UICorner")
    xOverlay1Corner.CornerRadius = UDim.new(1, 0)
    xOverlay1Corner.Parent = xOverlay1

    local xOverlay2 = Instance.new("Frame")
    xOverlay2.Size = UDim2.new(0, 20, 0, 2)
    xOverlay2.Position = UDim2.new(0.5, -10, 0.5, -1)
    xOverlay2.BackgroundColor3 = Color3.fromRGB(255, 82, 82)
    xOverlay2.BorderSizePixel = 0
    xOverlay2.Rotation = -45
    xOverlay2.ZIndex = 3
    xOverlay2.Parent = hitboxViewBtn

    local xOverlay2Corner = Instance.new("UICorner")
    xOverlay2Corner.CornerRadius = UDim.new(1, 0)
    xOverlay2Corner.Parent = xOverlay2

    local hitboxStatusLabel = Instance.new("TextLabel")
    hitboxStatusLabel.Size = UDim2.new(1, 0, 0, 16)
    hitboxStatusLabel.Position = UDim2.new(0, 0, 0, 66)
    hitboxStatusLabel.BackgroundTransparency = 1
    hitboxStatusLabel.Text = "Expanda a hitbox dos jogadores"
    hitboxStatusLabel.TextColor3 = theme.textMuted
    hitboxStatusLabel.TextSize = 10
    hitboxStatusLabel.Font = Enum.Font.Gotham
    hitboxStatusLabel.Parent = hitboxSection

    -- ============================================
    -- INVISIBLE (página 2) — Y=322
    -- ============================================
    local invisibleSection = Instance.new("Frame")
    invisibleSection.Size = UDim2.new(1, 0, 0, 84)
    invisibleSection.Position = UDim2.new(0, 0, 0, 322)
    invisibleSection.BackgroundTransparency = 1
    invisibleSection.Parent = page2

    createAccentBar(invisibleSection, theme.invisibleColor)

    local invisibleTitleContainer = Instance.new("Frame")
    invisibleTitleContainer.Size = UDim2.new(1, -12, 0, 22)
    invisibleTitleContainer.Position = UDim2.new(0, 12, 0, 0)
    invisibleTitleContainer.BackgroundTransparency = 1
    invisibleTitleContainer.Parent = invisibleSection

    createSectionIcon(invisibleTitleContainer, "👤", theme.invisibleColor)

    local invisibleTitle = Instance.new("TextLabel")
    invisibleTitle.Size = UDim2.new(1, -30, 1, 0)
    invisibleTitle.Position = UDim2.new(0, 28, 0, 0)
    invisibleTitle.BackgroundTransparency = 1
    invisibleTitle.Text = "INVISIBLE"
    invisibleTitle.TextColor3 = theme.textSecondary
    invisibleTitle.TextSize = 12
    invisibleTitle.Font = Enum.Font.GothamBold
    invisibleTitle.TextXAlignment = Enum.TextXAlignment.Left
    invisibleTitle.Parent = invisibleTitleContainer

    local invisibleToggleBtn = Instance.new("TextButton")
    invisibleToggleBtn.Size = UDim2.new(0, 90, 0, 30)
    invisibleToggleBtn.Position = UDim2.new(0.5, -45, 0, 26)
    invisibleToggleBtn.BackgroundColor3 = theme.danger
    invisibleToggleBtn.BackgroundTransparency = 0.2
    invisibleToggleBtn.Text = "OFF"
    invisibleToggleBtn.TextColor3 = theme.danger
    invisibleToggleBtn.TextSize = 13
    invisibleToggleBtn.Font = Enum.Font.GothamBold
    invisibleToggleBtn.BorderSizePixel = 2
    invisibleToggleBtn.BorderColor3 = theme.danger
    invisibleToggleBtn.Parent = invisibleSection

    local invisibleBtnCorner = Instance.new("UICorner")
    invisibleBtnCorner.CornerRadius = UDim.new(0, 8)
    invisibleBtnCorner.Parent = invisibleToggleBtn

    local invisibleStatusLabel = Instance.new("TextLabel")
    invisibleStatusLabel.Size = UDim2.new(1, 0, 0, 16)
    invisibleStatusLabel.Position = UDim2.new(0, 0, 0, 66)
    invisibleStatusLabel.BackgroundTransparency = 1
    invisibleStatusLabel.Text = "Deixe seu personagem invisível"
    invisibleStatusLabel.TextColor3 = theme.textMuted
    invisibleStatusLabel.TextSize = 10
    invisibleStatusLabel.Font = Enum.Font.Gotham
    invisibleStatusLabel.Parent = invisibleSection

    -- ============================================
    -- SLIDERS
    -- ============================================

    local speedIsActive = false
    local speedMin, speedMax = 5, 500
    local currentSpeedValue = speedModule.currentSpeed or 25
    local speedDragging = false
    local speedDragConn, speedReleaseConn = nil, nil

    local function updateSpeedVisual(value)
        local percent = math.clamp((value - speedMin) / (speedMax - speedMin), 0, 1)
        sliderFill.Size = UDim2.new(percent, 0, 1, 0)
        local tw = sliderTrack.AbsoluteSize.X
        local bw = sliderButton.AbsoluteSize.X
        if tw > 0 and bw > 0 then
            sliderButton.Position = UDim2.new(0, percent * (tw - bw), 0.5, -bw / 2)
        end
        speedValue.Text = tostring(math.floor(value))
    end

    local function setSpeedFromX(x)
        local tl = sliderTrack.AbsolutePosition.X
        local tw = sliderTrack.AbsoluteSize.X
        local bw = sliderButton.AbsoluteSize.X
        if tw <= 0 then return end
        local maxX = tw - bw
        if maxX <= 0 then return end
        local rel = x - tl - (bw / 2)
        local p = math.clamp(rel / maxX, 0, 1)
        local v = speedMin + p * (speedMax - speedMin)
        currentSpeedValue = v
        speedModule:setSpeed(v)
        updateSpeedVisual(v)
    end

    task.spawn(function()
        while sliderTrack.AbsoluteSize.X <= 0 do RunService.RenderStepped:Wait() end
        updateSpeedVisual(currentSpeedValue)
    end)

    sliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            speedDragging = true
            speedDragConn = UIS.InputChanged:Connect(function(mi)
                if (mi.UserInputType == Enum.UserInputType.MouseMovement or mi.UserInputType == Enum.UserInputType.Touch) and speedDragging then
                    setSpeedFromX(mi.Position.X)
                end
            end)
            speedReleaseConn = UIS.InputEnded:Connect(function(ei)
                if ei.UserInputType == Enum.UserInputType.MouseButton1 or ei.UserInputType == Enum.UserInputType.Touch then
                    speedDragging = false
                    if speedDragConn then speedDragConn:Disconnect() speedDragConn = nil end
                    if speedReleaseConn then speedReleaseConn:Disconnect() speedReleaseConn = nil end
                end
            end)
        end
    end)

    sliderTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            setSpeedFromX(input.Position.X)
        end
    end)

    local flyMin, flyMax = 1, 10
    local currentFlyValue = flyModule.speed or 1
    local flyDragging = false
    local flyDragConn, flyReleaseConn = nil, nil

    local function updateFlyVisual(value)
        local percent = math.clamp((value - flyMin) / (flyMax - flyMin), 0, 1)
        flySliderFill.Size = UDim2.new(percent, 0, 1, 0)
        local tw = flySliderTrack.AbsoluteSize.X
        local bw = flySliderButton.AbsoluteSize.X
        if tw > 0 and bw > 0 then
            flySliderButton.Position = UDim2.new(0, percent * (tw - bw), 0.5, -bw / 2)
        end
        flySpeedValue.Text = tostring(math.floor(value))
    end

    local function setFlyFromX(x)
        local tl = flySliderTrack.AbsolutePosition.X
        local tw = flySliderTrack.AbsoluteSize.X
        local bw = flySliderButton.AbsoluteSize.X
        if tw <= 0 then return end
        local maxX = tw - bw
        if maxX <= 0 then return end
        local rel = x - tl - (bw / 2)
        local p = math.clamp(rel / maxX, 0, 1)
        local v = math.floor(flyMin + p * (flyMax - flyMin) + 0.5)
        currentFlyValue = v
        flyModule:setSpeed(v)
        updateFlyVisual(v)
    end

    task.spawn(function()
        while flySliderTrack.AbsoluteSize.X <= 0 do RunService.RenderStepped:Wait() end
        updateFlyVisual(currentFlyValue)
    end)

    flySliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            flyDragging = true
            flyDragConn = UIS.InputChanged:Connect(function(mi)
                if (mi.UserInputType == Enum.UserInputType.MouseMovement or mi.UserInputType == Enum.UserInputType.Touch) and flyDragging then
                    setFlyFromX(mi.Position.X)
                end
            end)
            flyReleaseConn = UIS.InputEnded:Connect(function(ei)
                if ei.UserInputType == Enum.UserInputType.MouseButton1 or ei.UserInputType == Enum.UserInputType.Touch then
                    flyDragging = false
                    if flyDragConn then flyDragConn:Disconnect() flyDragConn = nil end
                    if flyReleaseConn then flyReleaseConn:Disconnect() flyReleaseConn = nil end
                end
            end)
        end
    end)

    flySliderTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            setFlyFromX(input.Position.X)
        end
    end)

    local aimbotMin, aimbotMax = 1, 10
    local currentAimbotValue = math.clamp(math.floor((aimbotModule.fov or 120) / 60 + 0.5), 1, 10)
    local aimbotDragging = false
    local aimbotDragConn, aimbotReleaseConn = nil, nil

    local function updateAimbotVisual(value)
        local percent = math.clamp((value - aimbotMin) / (aimbotMax - aimbotMin), 0, 1)
        aimbotSliderFill.Size = UDim2.new(1, 0, percent, 0)
        aimbotSliderButton.Position = UDim2.new(0.5, 0, 1 - percent, 0)
        aimbotValueLabel.Text = tostring(math.floor(value))
    end

    local function setAimbotFromY(y)
        local tt = aimbotSliderTrack.AbsolutePosition.Y
        local th = aimbotSliderTrack.AbsoluteSize.Y
        if th <= 0 then return end
        local rel = y - tt
        local p = 1 - math.clamp(rel / th, 0, 1)
        local v = math.floor(aimbotMin + p * (aimbotMax - aimbotMin) + 0.5)
        currentAimbotValue = v
        aimbotModule:setFOV(v)
        updateAimbotVisual(v)
    end

    updateAimbotVisual(currentAimbotValue)

    aimbotSliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            aimbotDragging = true
            aimbotDragConn = UIS.InputChanged:Connect(function(mi)
                if (mi.UserInputType == Enum.UserInputType.MouseMovement or mi.UserInputType == Enum.UserInputType.Touch) and aimbotDragging then
                    setAimbotFromY(mi.Position.Y)
                end
            end)
            aimbotReleaseConn = UIS.InputEnded:Connect(function(ei)
                if ei.UserInputType == Enum.UserInputType.MouseButton1 or ei.UserInputType == Enum.UserInputType.Touch then
                    aimbotDragging = false
                    if aimbotDragConn then aimbotDragConn:Disconnect() aimbotDragConn = nil end
                    if aimbotReleaseConn then aimbotReleaseConn:Disconnect() aimbotReleaseConn = nil end
                end
            end)
        end
    end)

    aimbotSliderTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            setAimbotFromY(input.Position.Y)
        end
    end)

    local isShowingFOV = false
    fovShowBtn.MouseButton1Click:Connect(function()
        playClickSound()
        isShowingFOV = not isShowingFOV
        fovCircle.Visible = isShowingFOV
        if isShowingFOV then
            fovShowBtn.Text = "◉"
            fovShowBtn.TextColor3 = theme.aimbotColor
            fovShowBtn.BackgroundColor3 = theme.aimbotColor
            fovShowBtn.BackgroundTransparency = 0.85
            fovShowBtn.BorderColor3 = theme.success
        else
            fovShowBtn.Text = "◯"
            fovShowBtn.TextColor3 = theme.textMuted
            fovShowBtn.BackgroundColor3 = theme.surface2
            fovShowBtn.BackgroundTransparency = 0.3
            fovShowBtn.BorderColor3 = theme.aimbotColor
        end
    end)

    -- ============================================
    -- PAGINAÇÃO
    -- ============================================
    local currentPage = 1
    local totalPages = 2

    local function updatePaginationVisuals()
        pageIndicator.Text = currentPage .. "/" .. totalPages
        prevPageBtn.TextColor3 = (currentPage == 1) and Color3.fromRGB(60, 60, 75) or theme.textSecondary
        nextPageBtn.TextColor3 = (currentPage == 2) and Color3.fromRGB(60, 60, 75) or theme.textSecondary
    end

    local function switchPage(newPage)
        if newPage < 1 or newPage > totalPages then return end
        if newPage == currentPage then return end
        local oldPage = currentPage
        currentPage = newPage
        local oldFrame = (oldPage == 1) and page1 or page2
        local newFrame = (newPage == 1) and page1 or page2
        oldFrame.Visible = false
        newFrame.Visible = true
        updatePaginationVisuals()
        if newPage == 2 then
            task.defer(function()
                updateAimbotVisual(currentAimbotValue)
            end)
        end
    end

    prevPageBtn.MouseButton1Click:Connect(function()
        playClickSound()
        if currentPage > 1 then switchPage(currentPage - 1) end
    end)
    nextPageBtn.MouseButton1Click:Connect(function()
        playClickSound()
        if currentPage < totalPages then switchPage(currentPage + 1) end
    end)

    updatePaginationVisuals()

    -- ============================================
    -- HANDLER AUTO PRESSER
    -- ============================================
    local function updateAutoStatus()
        local kT = autoPresserModule.toggleKey.Name
        local kP = autoPresserModule.pressKey.Name
        if not autoPresserModule.isEnabled then
            autoToggleBtn.Text = "OFF"
            autoToggleBtn.TextColor3 = theme.danger
            autoToggleBtn.BackgroundColor3 = theme.danger
            autoToggleBtn.BackgroundTransparency = 0.2
            autoToggleBtn.BorderColor3 = theme.danger
            local g = autoToggleBtn:FindFirstChildOfClass("UIGradient")
            if g then g:Destroy() end
            autoStatusLabel.Text = string.format("Ativa/Desativa com [%s] • Segura [%s]", kT, kP)
            autoStatusLabel.TextColor3 = theme.textMuted
        else
            autoToggleBtn.Text = "ON"
            autoToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            autoToggleBtn.BackgroundColor3 = theme.success
            autoToggleBtn.BackgroundTransparency = 0.15
            autoToggleBtn.BorderColor3 = theme.success
            local g = autoToggleBtn:FindFirstChildOfClass("UIGradient")
            if not g then g = Instance.new("UIGradient") g.Parent = autoToggleBtn end
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 230, 118)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 150, 80)),
            })
            g.Rotation = 90
            if autoPresserModule.isHolding then
                autoStatusLabel.Text = string.format("Pressione [%s] para parar • Segurando [%s]", kT, kP)
                autoStatusLabel.TextColor3 = Color3.fromRGB(180, 255, 210)
            else
                autoStatusLabel.Text = string.format("Pressione [%s] para segurar [%s]", kT, kP)
                autoStatusLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
            end
        end
    end

    autoPresserModule.onHoldChanged = function() updateAutoStatus() end

    autoToggleBtn.MouseButton1Click:Connect(function()
        playClickSound()
        autoPresserModule:toggle()
        updateAutoStatus()
    end)

    local capturingFor = nil
    local captureConnection = nil

    local function stopCapturing()
        if captureConnection then captureConnection:Disconnect() captureConnection = nil end
        capturingFor = nil
        toggleKeyBtn.Text = autoPresserModule.toggleKey.Name
        toggleKeyBtn.TextColor3 = theme.autoPresserColor
        toggleKeyBtn.BorderColor3 = theme.autoPresserColor
        toggleKeyBtn.TextSize = 15
        pressKeyBtn.Text = autoPresserModule.pressKey.Name
        pressKeyBtn.TextColor3 = theme.autoPresserColor
        pressKeyBtn.BorderColor3 = theme.autoPresserColor
        pressKeyBtn.TextSize = 15
    end

    local function startCapturing(mode)
        if capturingFor then stopCapturing() end
        capturingFor = mode
        if mode == "toggle" then
            toggleKeyBtn.Text = "..."
            toggleKeyBtn.TextColor3 = theme.warning
            toggleKeyBtn.BorderColor3 = theme.warning
            toggleKeyBtn.TextSize = 13
        else
            pressKeyBtn.Text = "..."
            pressKeyBtn.TextColor3 = theme.warning
            pressKeyBtn.BorderColor3 = theme.warning
            pressKeyBtn.TextSize = 13
        end
        captureConnection = UIS.InputBegan:Connect(function(input, gp)
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if input.KeyCode == Enum.KeyCode.Escape then stopCapturing() return end
            if capturingFor == "toggle" then
                autoPresserModule.toggleKey = input.KeyCode
            else
                autoPresserModule.pressKey = input.KeyCode
            end
            if autoPresserModule.isEnabled then
                autoPresserModule:_disconnectKeyToggle()
                autoPresserModule:_connectKeyToggle()
            end
            updateAutoStatus()
            stopCapturing()
        end)
    end

    toggleKeyBtn.MouseButton1Click:Connect(function()
        playClickSound()
        startCapturing("toggle")
    end)
    pressKeyBtn.MouseButton1Click:Connect(function()
        playClickSound()
        startCapturing("press")
    end)

    -- ============================================
    -- HANDLERS DOS TOGGLES
    -- ============================================
    local function toggleVisual(btn, isOn)
        playClickSound()
        if isOn then
            btn.Text = "ON"
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.BackgroundColor3 = theme.success
            btn.BackgroundTransparency = 0.15
            btn.BorderColor3 = theme.success
            local g = btn:FindFirstChildOfClass("UIGradient")
            if not g then g = Instance.new("UIGradient") g.Parent = btn end
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 230, 118)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 150, 80)),
            })
            g.Rotation = 90
        else
            btn.Text = "OFF"
            btn.TextColor3 = theme.danger
            btn.BackgroundColor3 = theme.danger
            btn.BackgroundTransparency = 0.2
            btn.BorderColor3 = theme.danger
            local g = btn:FindFirstChildOfClass("UIGradient")
            if g then g:Destroy() end
        end
    end

    speedToggleBtn.MouseButton1Click:Connect(function()
        speedIsActive = not speedIsActive
        if speedIsActive then speedModule:enable() else speedModule:disable() end
        toggleVisual(speedToggleBtn, speedIsActive)
    end)

    jumpToggleBtn.MouseButton1Click:Connect(function()
        if jumpModule.isEnabled then jumpModule:disable() else jumpModule:enable() end
        toggleVisual(jumpToggleBtn, jumpModule.isEnabled)
    end)

    espToggleBtn.MouseButton1Click:Connect(function()
        if espModule.isEnabled then espModule:disable() else espModule:enable() end
        toggleVisual(espToggleBtn, espModule.isEnabled)
    end)

    noclipToggleBtn.MouseButton1Click:Connect(function()
        if noclipModule.isEnabled then noclipModule:disable() else noclipModule:enable() end
        toggleVisual(noclipToggleBtn, noclipModule.isEnabled)
    end)

    hitboxToggleBtn.MouseButton1Click:Connect(function()
        if hitboxModule.isEnabled then hitboxModule:disable() else hitboxModule:enable() end
        toggleVisual(hitboxToggleBtn, hitboxModule.isEnabled)
    end)

    hitboxViewBtn.MouseButton1Click:Connect(function()
        playClickSound()
        hitboxModule:setViewing(not hitboxModule.isViewing)
        if hitboxModule.isViewing then
            xOverlay1.Visible = false
            xOverlay2.Visible = false
            hitboxViewBtn.BorderColor3 = theme.success
            hitboxViewBtn.TextColor3 = theme.text
        else
            xOverlay1.Visible = true
            xOverlay2.Visible = true
            hitboxViewBtn.BorderColor3 = theme.danger
            hitboxViewBtn.TextColor3 = theme.textMuted
        end
    end)

    -- CORREÇÃO DO BOTÃO INVISIBLE: Estado Local Explicito
    local isInvisibleActive = false
    invisibleToggleBtn.MouseButton1Click:Connect(function()
        isInvisibleActive = not isInvisibleActive
        
        -- Atualiza a UI na hora, independente do módulo
        if isInvisibleActive then
            toggleVisual(invisibleToggleBtn, true)
            invisibleStatusLabel.Text = "Personagem Invisível"
            invisibleStatusLabel.TextColor3 = theme.success
            invisibleModule:enable()
        else
            toggleVisual(invisibleToggleBtn, false)
            invisibleStatusLabel.Text = "Deixe seu personagem invisível"
            invisibleStatusLabel.TextColor3 = theme.textMuted
            invisibleModule:disable()
        end
    end)

    flyToggleBtn.MouseButton1Click:Connect(function()
        if flyModule.isEnabled then flyModule:disable() else flyModule:enable() end
        toggleVisual(flyToggleBtn, flyModule.isEnabled)
    end)

    aimbotToggleBtn.MouseButton1Click:Connect(function()
        local isOn = aimbotModule:toggle()
        toggleVisual(aimbotToggleBtn, isOn)
        if isOn then
            aimbotStatusLabel.Text = "Aimbot ativo — FOV: " .. aimbotModule.fov .. "px"
            aimbotStatusLabel.TextColor3 = Color3.fromRGB(180, 255, 210)
        else
            aimbotStatusLabel.Text = "Aimbot desligado"
            aimbotStatusLabel.TextColor3 = theme.textMuted
        end
    end)

    tpToggleBtn.MouseButton1Click:Connect(function()
        local isOn = tpClickModule:toggle()
        toggleVisual(tpToggleBtn, isOn)
        if isOn then
            tpStatusLabel.Text = "Ativo — Ctrl + Clique Esquerdo"
            tpStatusLabel.TextColor3 = Color3.fromRGB(180, 230, 255)
        else
            tpStatusLabel.Text = "Ctrl + Clique Esquerdo"
            tpStatusLabel.TextColor3 = theme.textMuted
        end
    end)

    -- ============================================
    -- MINIMIZAR
    -- ============================================
    local isMinimized = false
    minBtn.MouseButton1Click:Connect(function()
        playClickSound()
        isMinimized = not isMinimized
        if isMinimized then
            content.Visible = false
            TweenService:Create(mainFrame, TweenInfo.new(0.25), {Size = UDim2.new(0, 220, 0, 52)}):Play()
            minBtn.Text = "+"
        else
            content.Visible = true
            TweenService:Create(mainFrame, TweenInfo.new(0.25), {Size = UDim2.new(0, 220, 0, 720)}):Play()
            minBtn.Text = "−"
        end
    end)

    -- ============================================
    -- FECHAR
    -- ============================================
    closeBtn.MouseButton1Click:Connect(function()
        playClickSound()
        pcall(function() speedModule:disable() end)
        pcall(function() jumpModule:disable() end)
        pcall(function() espModule:disable() end)
        pcall(function() noclipModule:disable() end)
        pcall(function() autoPresserModule:disable() end)
        pcall(function() hitboxModule:disable() end)
        pcall(function() invisibleModule:disable() end)
        pcall(function() flyModule:disable() end)
        pcall(function() aimbotModule:disable() end)
        pcall(function() tpClickModule:disable() end)
        gui:Destroy()
        print("❌ Painel fechado — todos os módulos desligados.")
    end)

    mainFrame.BackgroundTransparency = 1
    mainFrame.Size = UDim2.new(0, 200, 0, 660)
    mainFrame.Position = UDim2.new(0.5, -100, 0.5, -330)

    task.spawn(function()
        task.wait(0.1)
        TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 220, 0, 720),
            Position = UDim2.new(0.5, -110, 0.5, -360),
            BackgroundTransparency = 0.08,
        }):Play()
    end)

    return gui
end

-- ============================================
-- INICIALIZAÇÃO
-- ============================================

local config = ConfigManager.new()
local speedModule = SpeedModule.new(config)
local jumpModule = InfiniteJumpModule.new(config)
local espModule = ESPModule.new(config)
local noclipModule = NoclipModule.new(config)
local autoPresserModule = AutoPresserModule.new(config)
local hitboxModule = HitboxModule.new(config)
local invisibleModule = InvisibleModule.new(config)
local flyModule = FlyModule.new(config)
local aimbotModule = AimbotModule.new(config)
local tpClickModule = TPClickModule.new(config)

speedModule:initialize()

local ok, err = pcall(function()
    createUI(speedModule, jumpModule, espModule, noclipModule, autoPresserModule, hitboxModule, invisibleModule, flyModule, aimbotModule, tpClickModule)
end)

if ok then
    print("✅ Basic Settings Control v2.1.0 carregado!")
    print("👤 Invisibilidade agressiva (Network Ownership + Loop)")
    print("🌀 TP Click corrigido (Teleporte não trava mais)")
    print("🛡️ Anti-AFK ativo")
else
    warn("❌ Erro ao criar UI: " .. tostring(err))
end
