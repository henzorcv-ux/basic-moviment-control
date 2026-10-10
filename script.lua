--[[
    Basic Settings Control v4.9.1
    Velocidade | Pulo | ESP | Noclip | Auto Presser | Hitbox Expander | Fly

    v4.9.1:
    - Botão de fechar corrigido: exibe "X" em vez de um quadrado
    - Tamanho: 240 × 830px
    - Todas as melhorias visuais da v4.9 mantidas
--]]

-- ============================================
-- SERVIÇOS E BIBLIOTECAS
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
-- SISTEMA DE EVENTOS
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
        speed = { value = 16, min = 5, max = 500 },
        flySpeed = { value = 1, min = 1, max = 10 },
        features = { speedControl = false, infiniteJump = false, noclip = false, fly = false, esp = false, hitbox = false, autoPresser = false },
        window = { minimized = false }
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
-- MÓDULO DE VELOCIDADE
-- ============================================

local SpeedModule = {}
SpeedModule.__index = SpeedModule

function SpeedModule.new(config)
    local self = setmetatable({}, SpeedModule)
    self.config, self.eventBus = config, EventBus.new()
    self.isEnabled, self.currentSpeed = false, config:get("speed.value") or 16
    self.defaultSpeed = 16
    self.character, self.humanoid, self.originalSpeed = nil, nil, nil
    self.velocityCheckConnection = nil
    self.forceSpeedConnection = nil
    return self
end

function SpeedModule:initialize()
    self:setupCharacter()
end

function SpeedModule:setupCharacter()
    self.character = player.Character or player.CharacterAdded:Wait()
    self.humanoid = self.character:WaitForChild("Humanoid")
    self.originalSpeed = self.humanoid.WalkSpeed
    self.defaultSpeed = self.originalSpeed

    player.CharacterAdded:Connect(function(character)
        self.character, self.humanoid = character, character:WaitForChild("Humanoid")
        self.originalSpeed = self.humanoid.WalkSpeed
        self.defaultSpeed = self.originalSpeed
        if self.isEnabled then 
            self:enable()
        end
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
    if self.isEnabled then 
        self:applySpeed()
    end
end

function SpeedModule:applySpeed()
    if self.humanoid then 
        pcall(function() 
            self.humanoid.WalkSpeed = self.currentSpeed 
        end) 
    end
end

function SpeedModule:restoreDefaultSpeed()
    if self.humanoid then 
        pcall(function() 
            self.humanoid.WalkSpeed = self.defaultSpeed 
        end) 
    end
end

function SpeedModule:startSpeedProtection()
    self:stopSpeedProtection()
    self.velocityCheckConnection = RunService.Heartbeat:Connect(function()
        if self.isEnabled and self.humanoid and self.humanoid.Parent then
            local currentWalkSpeed = self.humanoid.WalkSpeed
            if currentWalkSpeed ~= self.currentSpeed then
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
        local humanoidMetatable = {}
        humanoidMetatable.__index = function(table, key)
            return rawget(table, key)
        end
        humanoidMetatable.__newindex = function(table, key, value)
            if key == "WalkSpeed" and self.isEnabled then
                rawset(table, key, self.currentSpeed)
                return
            end
            rawset(table, key, value)
        end
        pcall(function()
            setmetatable(self.humanoid, humanoidMetatable)
        end)
    end

    self.humanoidChangedConnection = self.humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if self.isEnabled and self.humanoid then
            local currentSpeed = self.humanoid.WalkSpeed
            if currentSpeed ~= self.currentSpeed then
                self.humanoid.WalkSpeed = self.currentSpeed
            end
        end
    end)
end

function SpeedModule:stopSpeedProtection()
    if self.velocityCheckConnection then
        self.velocityCheckConnection:Disconnect()
        self.velocityCheckConnection = nil
    end
    if self.forceSpeedConnection then
        self.forceSpeedConnection:Disconnect()
        self.forceSpeedConnection = nil
    end
    if self.humanoidChangedConnection then
        self.humanoidChangedConnection:Disconnect()
        self.humanoidChangedConnection = nil
    end
    pcall(function()
        if self.humanoid then
            setmetatable(self.humanoid, nil)
        end
    end)
end

-- ============================================
-- MÓDULO DE PULO INFINITO
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
    if self.jumpConnection then
        self.jumpConnection:Disconnect()
        self.jumpConnection = nil
    end
    print("🚀 Pulo Infinito DESATIVADO!")
end

function InfiniteJumpModule:setupJumpListener()
    if self.jumpConnection then
        self.jumpConnection:Disconnect()
        self.jumpConnection = nil
    end

    self.jumpConnection = UIS.JumpRequest:Connect(function()
        if not self.isEnabled then return end

        local char = player.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end

-- ============================================
-- MÓDULO DE ESP
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
    nameLabel.TextScaled = false
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
    distLabel.TextScaled = false
    distLabel.TextXAlignment = Enum.TextXAlignment.Center
    distLabel.TextYAlignment = Enum.TextYAlignment.Center
    distLabel.Parent = distGui

    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Chams"
    highlight.Adornee = character
    highlight.FillColor = Color3.fromRGB(255, 82, 82)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = character

    self.espObjects[targetPlayer] = {
        nameGui = nameGui,
        nameLabel = nameLabel,
        distGui = distGui,
        distLabel = distLabel,
        highlight = highlight
    }

    local charConn
    charConn = targetPlayer.CharacterAdded:Connect(function(newChar)
        task.wait(0.3)
        self:removeESPForPlayer(targetPlayer)
        if self.isEnabled then
            self:createESPForPlayer(targetPlayer)
        end
    end)
    table.insert(self.connections, charConn)
end

function ESPModule:removeESPForPlayer(targetPlayer)
    local esp = self.espObjects[targetPlayer]
    if not esp then return end

    pcall(function() if esp.nameGui then esp.nameGui:Destroy() end end)
    pcall(function() if esp.distGui then esp.distGui:Destroy() end end)
    pcall(function() if esp.highlight then esp.highlight:Destroy() end end)

    self.espObjects[targetPlayer] = nil
end

function ESPModule:updateDistances()
    if not self.isEnabled then return end

    local camera = workspace.CurrentCamera
    if not camera then return end

    local cfg = self.scaleConfig

    for targetPlayer, esp in pairs(self.espObjects) do
        local character = targetPlayer.Character
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

    for _, p in ipairs(Players:GetPlayers()) do
        self:createESPForPlayer(p)
    end

    local addedConn = Players.PlayerAdded:Connect(function(p)
        task.wait(1)
        if self.isEnabled then
            self:createESPForPlayer(p)
        end
    end)
    table.insert(self.connections, addedConn)

    local removingConn = Players.PlayerRemoving:Connect(function(p)
        self:removeESPForPlayer(p)
    end)
    table.insert(self.connections, removingConn)

    self.heartbeat = RunService.RenderStepped:Connect(function()
        self:updateDistances()
    end)

    print("👁️ ESP ATIVADO! (Nome + Distância + Chams)")
end

function ESPModule:disable()
    self.isEnabled = false
    self.config:set("features.esp", false)

    for _, conn in ipairs(self.connections) do
        pcall(function() conn:Disconnect() end)
    end
    self.connections = {}

    if self.heartbeat then
        self.heartbeat:Disconnect()
        self.heartbeat = nil
    end

    for targetPlayer, _ in pairs(self.espObjects) do
        self:removeESPForPlayer(targetPlayer)
    end
    self.espObjects = {}

    print("👁️ ESP DESATIVADO! (Tudo removido)")
end

-- ============================================
-- MÓDULO DE NOCLIP
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
    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end
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
            if part and part.Parent then
                part.CanCollide = true
            end
        end)
    end
    self.partsWithCollision = {}
end

function NoclipModule:setupNoclip()
    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end

    self.connection = RunService.Stepped:Connect(function()
        if not self.isEnabled then return end
        local character = player.Character
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
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
    return self
end

function AutoPresserModule:_connectKeyToggle()
    if self.keyConnection then return end
    self.keyConnection = UIS.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == self.toggleKey and self.isEnabled then
            self:toggleHold()
        end
    end)
end

function AutoPresserModule:_disconnectKeyToggle()
    if self.keyConnection then
        self.keyConnection:Disconnect()
        self.keyConnection = nil
    end
end

function AutoPresserModule:_holdKey()
    if self.isKeyHeld then return end
    VirtualInputManager:SendKeyEvent(true, self.pressKey, false, game)
    self.isKeyHeld = true
end

function AutoPresserModule:_releaseKey()
    if not self.isKeyHeld then return end
    VirtualInputManager:SendKeyEvent(false, self.pressKey, false, game)
    self.isKeyHeld = false
end

function AutoPresserModule:_startReinforce()
    if self.reinforceThread then return end
    self.reinforceThread = task.spawn(function()
        while self.isHolding do
            task.wait(0.5)
            if self.isHolding and self.isKeyHeld then
                VirtualInputManager:SendKeyEvent(true, self.pressKey, false, game)
            end
        end
        self.reinforceThread = nil
    end)
end

function AutoPresserModule:_stopReinforce()
    self.reinforceThread = nil
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

    if self.onHoldChanged then
        self.onHoldChanged(self.isHolding)
    end
end

function AutoPresserModule:enable()
    if self.isEnabled then return end
    self.isEnabled = true
    self.config:set("features.autoPresser", true)
    self:_connectKeyToggle()
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
    print("🖱️ Auto Presser DESARMADO")
end

function AutoPresserModule:toggle()
    if self.isEnabled then
        self:disable()
    else
        self:enable()
    end
    return self.isEnabled
end

-- ============================================
-- MÓDULO DE HITBOX EXPANDER
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

    if not self.originalSizes[character] then
        self.originalSizes[character] = hrp.Size
    end

    hrp.Size = self.HITBOX_SIZE

    if self.isViewing then
        hrp.Transparency = self.VISIBLE_TRANSPARENCY
    else
        hrp.Transparency = self.INVISIBLE_TRANSPARENCY
    end
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
        if p ~= player and p.Character then
            self:_expandHitbox(p.Character)
        end
    end
end

function HitboxModule:_restoreAll()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            self:_restoreHitbox(p.Character)
        end
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
                if hrp and hrp.Size ~= self.HITBOX_SIZE then
                    self:_expandHitbox(p.Character)
                end
            end
        end
    end)

    print("🎯 Hitbox Expander ATIVADO!")
end

function HitboxModule:disable()
    if not self.isEnabled then return end
    self.isEnabled = false
    self.config:set("features.hitbox", false)

    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end

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
                    if state then
                        hrp.Transparency = self.VISIBLE_TRANSPARENCY
                    else
                        hrp.Transparency = self.INVISIBLE_TRANSPARENCY
                    end
                end
            end
        end
    end
end

-- ============================================
-- MÓDULO DE VOO (FLY)
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

function FlyModule:getRealSpeed()
    return 40 + (self.speed * 20)
end

function FlyModule:enable()
    if self.isEnabled then return end
    self.isEnabled = true
    self.isFlying = false
    self.config:set("features.fly", true)
    self:setupFlyControls()
    self:setupKeyToggle()
    print("✈️ Fly ATIVADO! Pressione F para voar.")
end

function FlyModule:disable()
    self.isEnabled = false
    self.isFlying = false
    self.config:set("features.fly", false)
    self:cleanupFly()
    if self.fKeyConnection then
        self.fKeyConnection:Disconnect()
        self.fKeyConnection = nil
    end
    print("✈️ Fly DESATIVADO!")
end

function FlyModule:setSpeed(value)
    self.speed = math.clamp(value, 1, 10)
    self.config:set("flySpeed.value", self.speed)
end

function FlyModule:toggleFly()
    if not self.isEnabled then return end

    self.isFlying = not self.isFlying

    if self.isFlying then
        self:startFly()
    else
        self:stopFly()
    end
end

function FlyModule:setupKeyToggle()
    if self.fKeyConnection then
        self.fKeyConnection:Disconnect()
        self.fKeyConnection = nil
    end

    self.fKeyConnection = UIS.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.F and self.isEnabled then
            self:toggleFly()
        end
    end)
end

function FlyModule:startFly()
    if not self.isEnabled then return end

    local character = player.Character
    if not character then return end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = true
    end

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
        local flyConnection = RunService.RenderStepped:Connect(function()
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

            if moveDirection.Magnitude > 0 then
                moveDirection = moveDirection.Unit
            end

            local camera = workspace.CurrentCamera
            if camera then
                local forward = camera.CFrame.LookVector
                local right = camera.CFrame.RightVector
                local up = camera.CFrame.UpVector

                local moveVector = (forward * -moveDirection.Z) + (right * moveDirection.X) + (up * moveDirection.Y)
                self.bodyVelocity.Velocity = moveVector * self:getRealSpeed()

                local lookAtPosition = camera.CFrame.Position + (camera.CFrame.LookVector * 100)
                local targetCFrame = CFrame.new(rootPart.Position, lookAtPosition)
                self.bodyGyro.CFrame = targetCFrame
            end
        end)
        table.insert(self.connections, flyConnection)
    end
end

function FlyModule:stopFly()
    self.isFlying = false
    self:cleanupFly()
end

function FlyModule:setupFlyControls()
end

function FlyModule:cleanupFly()
    for _, conn in ipairs(self.connections) do
        conn:Disconnect()
    end
    self.connections = {}

    if self.bodyVelocity then
        self.bodyVelocity:Destroy()
        self.bodyVelocity = nil
    end

    if self.bodyGyro then
        self.bodyGyro:Destroy()
        self.bodyGyro = nil
    end

    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
        end
    end
end

-- ============================================
-- DESIGN PREMIUM v4.9.1
-- ============================================

local function createUI(speedModule, jumpModule, espModule, noclipModule, autoPresserModule, hitboxModule, flyModule)
    local gui = Instance.new("ScreenGui")
    gui.Name, gui.Parent = "BasicSettingsControlGUI", CoreGui
    gui.ResetOnSpawn, gui.IgnoreGuiInset = false, true

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
        border = Color3.fromRGB(55, 55, 72),
        shadow = Color3.fromRGB(0, 0, 0),
        accent = Color3.fromRGB(100, 180, 255),
        jumpColor = Color3.fromRGB(255, 100, 150),
        noclipColor = Color3.fromRGB(150, 100, 255),
        hitboxColor = Color3.fromRGB(255, 200, 80),
        flyColor = Color3.fromRGB(0, 230, 255),
        espColor = Color3.fromRGB(200, 130, 255),
        autoPresserColor = Color3.fromRGB(255, 150, 60),
        gradient1 = Color3.fromRGB(100, 180, 255),
        gradient2 = Color3.fromRGB(180, 100, 255),
    }

    -- ===== CONTAINER PRINCIPAL (240 × 830) =====
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 240, 0, 830)
    mainFrame.Position = UDim2.new(0.5, -120, 0.5, -415)
    mainFrame.BackgroundColor3 = theme.background
    mainFrame.BackgroundTransparency = 0.08
    mainFrame.BorderSizePixel = 1
    mainFrame.BorderColor3 = theme.border
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = mainFrame

    -- Sombra dupla
    local shadow1 = Instance.new("Frame")
    shadow1.Size = UDim2.new(1, 30, 1, 30)
    shadow1.Position = UDim2.new(0, -15, 0, -15)
    shadow1.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow1.BackgroundTransparency = 0.7
    shadow1.BorderSizePixel = 0
    shadow1.ZIndex = -2
    shadow1.Parent = mainFrame

    local shadow1Corner = Instance.new("UICorner")
    shadow1Corner.CornerRadius = UDim.new(0, 20)
    shadow1Corner.Parent = shadow1

    local shadow2 = Instance.new("Frame")
    shadow2.Size = UDim2.new(1, 16, 1, 16)
    shadow2.Position = UDim2.new(0, -8, 0, -8)
    shadow2.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow2.BackgroundTransparency = 0.5
    shadow2.BorderSizePixel = 0
    shadow2.ZIndex = -1
    shadow2.Parent = mainFrame

    local shadow2Corner = Instance.new("UICorner")
    shadow2Corner.CornerRadius = UDim.new(0, 16)
    shadow2Corner.Parent = shadow2

    -- ===== CABEÇALHO =====
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

    local headerLine = Instance.new("Frame")
    headerLine.Size = UDim2.new(1, 0, 0, 1)
    headerLine.Position = UDim2.new(0, 0, 1, -1)
    headerLine.BackgroundColor3 = theme.gradient2
    headerLine.BackgroundTransparency = 0.3
    headerLine.BorderSizePixel = 0
    headerLine.Parent = header

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

    local titleIcon = Instance.new("TextLabel")
    titleIcon.Size = UDim2.new(1, 0, 1, 0)
    titleIcon.BackgroundTransparency = 1
    titleIcon.Text = "⚙"
    titleIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleIcon.TextSize = 15
    titleIcon.Font = Enum.Font.GothamBold
    titleIcon.TextXAlignment = Enum.TextXAlignment.Center
    titleIcon.TextYAlignment = Enum.TextYAlignment.Center
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
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 220, 255)),
    })
    titleGrad.Rotation = 90
    titleGrad.Parent = title

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(0.7, 0, 0, 14)
    subtitle.Position = UDim2.new(0, 44, 0, 30)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Velocidade • Pulo • ESP • Noclip • Auto • Hitbox • Fly"
    subtitle.TextColor3 = theme.textSecondary
    subtitle.TextSize = 7
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextYAlignment = Enum.TextYAlignment.Center
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

    -- ✅ Botão fechar com "X" literal
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

    minBtn.MouseEnter:Connect(function()
        TweenService:Create(minBtn, TweenInfo.new(0.15), {BackgroundColor3 = theme.surface3, BackgroundTransparency = 0.2}):Play()
    end)
    minBtn.MouseLeave:Connect(function()
        TweenService:Create(minBtn, TweenInfo.new(0.15), {BackgroundColor3 = theme.surface2, BackgroundTransparency = 0.5}):Play()
    end)
    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = theme.danger, BackgroundTransparency = 0.2, TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = theme.surface2, BackgroundTransparency = 0.5, TextColor3 = theme.textSecondary}):Play()
    end)

    -- Drag
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil

    local function updateDrag(input)
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end

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
        if input == dragInput and dragging then updateDrag(input) end
    end)

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -24, 1, -68)
    content.Position = UDim2.new(0, 12, 0, 60)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame

    -- ============================================
    -- SEÇÃO VELOCIDADE
    -- ============================================
    local speedSection = Instance.new("Frame")
    speedSection.Size = UDim2.new(1, 0, 0, 132)
    speedSection.Position = UDim2.new(0, 0, 0, 0)
    speedSection.BackgroundTransparency = 1
    speedSection.Parent = content

    local speedAccentBar = Instance.new("Frame")
    speedAccentBar.Size = UDim2.new(0, 3, 0, 20)
    speedAccentBar.Position = UDim2.new(0, 0, 0, 2)
    speedAccentBar.BackgroundColor3 = theme.accent
    speedAccentBar.BorderSizePixel = 0
    speedAccentBar.Parent = speedSection

    local speedAccentCorner = Instance.new("UICorner")
    speedAccentCorner.CornerRadius = UDim.new(0, 2)
    speedAccentCorner.Parent = speedAccentBar

    local speedAccentGlow = Instance.new("UIStroke")
    speedAccentGlow.Thickness = 4
    speedAccentGlow.Color = theme.accent
    speedAccentGlow.Transparency = 0.75
    speedAccentGlow.Parent = speedAccentBar

    local speedTitleContainer = Instance.new("Frame")
    speedTitleContainer.Size = UDim2.new(1, -12, 0, 22)
    speedTitleContainer.Position = UDim2.new(0, 12, 0, 0)
    speedTitleContainer.BackgroundTransparency = 1
    speedTitleContainer.Parent = speedSection

    local speedTitleIcon = Instance.new("TextLabel")
    speedTitleIcon.Size = UDim2.new(0, 18, 1, 0)
    speedTitleIcon.BackgroundTransparency = 1
    speedTitleIcon.Text = "⚡"
    speedTitleIcon.TextColor3 = theme.accent
    speedTitleIcon.TextSize = 14
    speedTitleIcon.Font = Enum.Font.GothamBold
    speedTitleIcon.TextXAlignment = Enum.TextXAlignment.Center
    speedTitleIcon.TextYAlignment = Enum.TextYAlignment.Center
    speedTitleIcon.Parent = speedTitleContainer

    local speedTitle = Instance.new("TextLabel")
    speedTitle.Size = UDim2.new(1, -22, 1, 0)
    speedTitle.Position = UDim2.new(0, 22, 0, 0)
    speedTitle.BackgroundTransparency = 1
    speedTitle.Text = "VELOCIDADE"
    speedTitle.TextColor3 = theme.textSecondary
    speedTitle.TextSize = 12
    speedTitle.Font = Enum.Font.GothamBold
    speedTitle.TextXAlignment = Enum.TextXAlignment.Left
    speedTitle.TextYAlignment = Enum.TextYAlignment.Center
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
    displayStroke.Color = theme.border
    displayStroke.Transparency = 0.3
    displayStroke.Parent = speedDisplay

    local speedValue = Instance.new("TextLabel")
    speedValue.Size = UDim2.new(1, 0, 0.6, 0)
    speedValue.Position = UDim2.new(0, 0, 0.1, 0)
    speedValue.BackgroundTransparency = 1
    speedValue.Text = "16"
    speedValue.TextColor3 = theme.accent
    speedValue.TextSize = 24
    speedValue.Font = Enum.Font.GothamBold
    speedValue.TextXAlignment = Enum.TextXAlignment.Center
    speedValue.TextYAlignment = Enum.TextYAlignment.Bottom
    speedValue.Parent = speedDisplay

    local speedUnit = Instance.new("TextLabel")
    speedUnit.Size = UDim2.new(1, 0, 0.3, 0)
    speedUnit.Position = UDim2.new(0, 0, 0.65, 0)
    speedUnit.BackgroundTransparency = 1
    speedUnit.Text = "VEL"
    speedUnit.TextColor3 = theme.textMuted
    speedUnit.TextSize = 7
    speedUnit.Font = Enum.Font.Gotham
    speedUnit.TextXAlignment = Enum.TextXAlignment.Center
    speedUnit.TextYAlignment = Enum.TextYAlignment.Top
    speedUnit.Parent = speedDisplay

    local sliderContainer = Instance.new("Frame")
    sliderContainer.Size = UDim2.new(1, -16, 0, 24)
    sliderContainer.Position = UDim2.new(0, 8, 0, 80)
    sliderContainer.BackgroundTransparency = 1
    sliderContainer.ClipsDescendants = false
    sliderContainer.Parent = speedSection

    local minLabel = Instance.new("TextLabel")
    minLabel.Size = UDim2.new(0, 22, 1, 0)
    minLabel.BackgroundTransparency = 1
    minLabel.Text = "5"
    minLabel.TextColor3 = theme.textMuted
    minLabel.TextSize = 8
    minLabel.Font = Enum.Font.Gotham
    minLabel.TextXAlignment = Enum.TextXAlignment.Center
    minLabel.TextYAlignment = Enum.TextYAlignment.Center
    minLabel.Parent = sliderContainer

    local maxLabel = Instance.new("TextLabel")
    maxLabel.Size = UDim2.new(0, 22, 1, 0)
    maxLabel.Position = UDim2.new(1, -22, 0, 0)
    maxLabel.BackgroundTransparency = 1
    maxLabel.Text = "500"
    maxLabel.TextColor3 = theme.textMuted
    maxLabel.TextSize = 8
    maxLabel.Font = Enum.Font.Gotham
    maxLabel.TextXAlignment = Enum.TextXAlignment.Center
    maxLabel.TextYAlignment = Enum.TextYAlignment.Center
    maxLabel.Parent = sliderContainer

    local sliderTrack = Instance.new("Frame")
    sliderTrack.Size = UDim2.new(1, -56, 0, 4)
    sliderTrack.Position = UDim2.new(0, 28, 0.5, -2)
    sliderTrack.BackgroundColor3 = theme.surface3
    sliderTrack.BorderSizePixel = 0
    sliderTrack.ClipsDescendants = false
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

    local fillGrad = Instance.new("UIGradient")
    fillGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, theme.accent),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 140, 255)),
    })
    fillGrad.Parent = sliderFill

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

    local speedToggleContainer = Instance.new("Frame")
    speedToggleContainer.Size = UDim2.new(1, 0, 0, 38)
    speedToggleContainer.Position = UDim2.new(0, 0, 0, 106)
    speedToggleContainer.BackgroundTransparency = 1
    speedToggleContainer.Parent = speedSection

    local speedToggleBtn = Instance.new("TextButton")
    speedToggleBtn.Size = UDim2.new(0, 90, 0, 30)
    speedToggleBtn.Position = UDim2.new(0.5, -45, 0.5, -15)
    speedToggleBtn.BackgroundColor3 = theme.danger
    speedToggleBtn.BackgroundTransparency = 0.15
    speedToggleBtn.Text = "OFF"
    speedToggleBtn.TextColor3 = theme.danger
    speedToggleBtn.TextSize = 13
    speedToggleBtn.Font = Enum.Font.GothamBold
    speedToggleBtn.BorderSizePixel = 2
    speedToggleBtn.BorderColor3 = theme.danger
    speedToggleBtn.Parent = speedToggleContainer

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 8)
    toggleCorner.Parent = speedToggleBtn

    local divider1 = Instance.new("Frame")
    divider1.Size = UDim2.new(1, 0, 0, 1)
    divider1.Position = UDim2.new(0, 0, 0, 136)
    divider1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    divider1.BackgroundTransparency = 0.5
    divider1.BorderSizePixel = 0
    divider1.Parent = content

    local dividerGrad1 = Instance.new("UIGradient")
    dividerGrad1.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
    dividerGrad1.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, theme.border),
        ColorSequenceKeypoint.new(0.5, theme.jumpColor),
        ColorSequenceKeypoint.new(1, theme.border),
    })
    dividerGrad1.Parent = divider1

    -- ============================================
    -- SEÇÃO PULO
    -- ============================================
    local jumpSection = Instance.new("Frame")
    jumpSection.Size = UDim2.new(1, 0, 0, 80)
    jumpSection.Position = UDim2.new(0, 0, 0, 144)
    jumpSection.BackgroundTransparency = 1
    jumpSection.Parent = content

    local jumpAccentBar = Instance.new("Frame")
    jumpAccentBar.Size = UDim2.new(0, 3, 0, 20)
    jumpAccentBar.Position = UDim2.new(0, 0, 0, 2)
    jumpAccentBar.BackgroundColor3 = theme.jumpColor
    jumpAccentBar.BorderSizePixel = 0
    jumpAccentBar.Parent = jumpSection

    local jumpAccentCorner = Instance.new("UICorner")
    jumpAccentCorner.CornerRadius = UDim.new(0, 2)
    jumpAccentCorner.Parent = jumpAccentBar

    local jumpAccentGlow = Instance.new("UIStroke")
    jumpAccentGlow.Thickness = 4
    jumpAccentGlow.Color = theme.jumpColor
    jumpAccentGlow.Transparency = 0.75
    jumpAccentGlow.Parent = jumpAccentBar

    local jumpTitleContainer = Instance.new("Frame")
    jumpTitleContainer.Size = UDim2.new(1, -12, 0, 22)
    jumpTitleContainer.Position = UDim2.new(0, 12, 0, 0)
    jumpTitleContainer.BackgroundTransparency = 1
    jumpTitleContainer.Parent = jumpSection

    local jumpTitleIcon = Instance.new("TextLabel")
    jumpTitleIcon.Size = UDim2.new(0, 18, 1, 0)
    jumpTitleIcon.BackgroundTransparency = 1
    jumpTitleIcon.Text = "🚀"
    jumpTitleIcon.TextColor3 = theme.jumpColor
    jumpTitleIcon.TextSize = 14
    jumpTitleIcon.Font = Enum.Font.GothamBold
    jumpTitleIcon.TextXAlignment = Enum.TextXAlignment.Center
    jumpTitleIcon.TextYAlignment = Enum.TextYAlignment.Center
    jumpTitleIcon.Parent = jumpTitleContainer

    local jumpTitle = Instance.new("TextLabel")
    jumpTitle.Size = UDim2.new(1, -22, 1, 0)
    jumpTitle.Position = UDim2.new(0, 22, 0, 0)
    jumpTitle.BackgroundTransparency = 1
    jumpTitle.Text = "PULO INFINITO"
    jumpTitle.TextColor3 = theme.textSecondary
    jumpTitle.TextSize = 12
    jumpTitle.Font = Enum.Font.GothamBold
    jumpTitle.TextXAlignment = Enum.TextXAlignment.Left
    jumpTitle.TextYAlignment = Enum.TextYAlignment.Center
    jumpTitle.Parent = jumpTitleContainer

    local jumpToggleContainer = Instance.new("Frame")
    jumpToggleContainer.Size = UDim2.new(1, 0, 0, 34)
    jumpToggleContainer.Position = UDim2.new(0, 0, 0, 26)
    jumpToggleContainer.BackgroundTransparency = 1
    jumpToggleContainer.Parent = jumpSection

    local jumpToggleBtn = Instance.new("TextButton")
    jumpToggleBtn.Size = UDim2.new(0, 90, 0, 30)
    jumpToggleBtn.Position = UDim2.new(0.5, -45, 0.5, -15)
    jumpToggleBtn.BackgroundColor3 = theme.danger
    jumpToggleBtn.BackgroundTransparency = 0.2
    jumpToggleBtn.Text = "OFF"
    jumpToggleBtn.TextColor3 = theme.danger
    jumpToggleBtn.TextSize = 13
    jumpToggleBtn.Font = Enum.Font.GothamBold
    jumpToggleBtn.BorderSizePixel = 2
    jumpToggleBtn.BorderColor3 = theme.danger
    jumpToggleBtn.Parent = jumpToggleContainer

    local jumpBtnCorner = Instance.new("UICorner")
    jumpBtnCorner.CornerRadius = UDim.new(0, 8)
    jumpBtnCorner.Parent = jumpToggleBtn

    local jumpStatusContainer = Instance.new("Frame")
    jumpStatusContainer.Size = UDim2.new(1, 0, 0, 16)
    jumpStatusContainer.Position = UDim2.new(0, 0, 0, 62)
    jumpStatusContainer.BackgroundTransparency = 1
    jumpStatusContainer.Parent = jumpSection

    local jumpStatusLabel = Instance.new("TextLabel")
    jumpStatusLabel.Size = UDim2.new(1, 0, 1, 0)
    jumpStatusLabel.BackgroundTransparency = 1
    jumpStatusLabel.Text = "Espaço para pular"
    jumpStatusLabel.TextColor3 = theme.textMuted
    jumpStatusLabel.TextSize = 10
    jumpStatusLabel.Font = Enum.Font.Gotham
    jumpStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    jumpStatusLabel.TextYAlignment = Enum.TextYAlignment.Center
    jumpStatusLabel.Parent = jumpStatusContainer

    -- ============================================
    -- SEÇÃO ESP
    -- ============================================
    local espSection = Instance.new("Frame")
    espSection.Size = UDim2.new(1, 0, 0, 84)
    espSection.Position = UDim2.new(0, 0, 0, 232)
    espSection.BackgroundTransparency = 1
    espSection.Parent = content

    local espAccentBar = Instance.new("Frame")
    espAccentBar.Size = UDim2.new(0, 3, 0, 20)
    espAccentBar.Position = UDim2.new(0, 0, 0, 2)
    espAccentBar.BackgroundColor3 = theme.espColor
    espAccentBar.BorderSizePixel = 0
    espAccentBar.Parent = espSection

    local espAccentCorner = Instance.new("UICorner")
    espAccentCorner.CornerRadius = UDim.new(0, 2)
    espAccentCorner.Parent = espAccentBar

    local espAccentGlow = Instance.new("UIStroke")
    espAccentGlow.Thickness = 4
    espAccentGlow.Color = theme.espColor
    espAccentGlow.Transparency = 0.75
    espAccentGlow.Parent = espAccentBar

    local espTitleContainer = Instance.new("Frame")
    espTitleContainer.Size = UDim2.new(1, -12, 0, 22)
    espTitleContainer.Position = UDim2.new(0, 12, 0, 0)
    espTitleContainer.BackgroundTransparency = 1
    espTitleContainer.Parent = espSection

    local espTitleIcon = Instance.new("TextLabel")
    espTitleIcon.Size = UDim2.new(0, 18, 1, 0)
    espTitleIcon.BackgroundTransparency = 1
    espTitleIcon.Text = "👁️"
    espTitleIcon.TextColor3 = theme.espColor
    espTitleIcon.TextSize = 14
    espTitleIcon.Font = Enum.Font.GothamBold
    espTitleIcon.TextXAlignment = Enum.TextXAlignment.Center
    espTitleIcon.TextYAlignment = Enum.TextYAlignment.Center
    espTitleIcon.Parent = espTitleContainer

    local espTitle = Instance.new("TextLabel")
    espTitle.Size = UDim2.new(1, -22, 1, 0)
    espTitle.Position = UDim2.new(0, 22, 0, 0)
    espTitle.BackgroundTransparency = 1
    espTitle.Text = "ESP"
    espTitle.TextColor3 = theme.textSecondary
    espTitle.TextSize = 12
    espTitle.Font = Enum.Font.GothamBold
    espTitle.TextXAlignment = Enum.TextXAlignment.Left
    espTitle.TextYAlignment = Enum.TextYAlignment.Center
    espTitle.Parent = espTitleContainer

    local espToggleContainer = Instance.new("Frame")
    espToggleContainer.Size = UDim2.new(1, 0, 0, 34)
    espToggleContainer.Position = UDim2.new(0, 0, 0, 26)
    espToggleContainer.BackgroundTransparency = 1
    espToggleContainer.Parent = espSection

    local espToggleBtn = Instance.new("TextButton")
    espToggleBtn.Size = UDim2.new(0, 90, 0, 30)
    espToggleBtn.Position = UDim2.new(0.5, -45, 0.5, -15)
    espToggleBtn.BackgroundColor3 = theme.danger
    espToggleBtn.BackgroundTransparency = 0.2
    espToggleBtn.Text = "OFF"
    espToggleBtn.TextColor3 = theme.danger
    espToggleBtn.TextSize = 13
    espToggleBtn.Font = Enum.Font.GothamBold
    espToggleBtn.BorderSizePixel = 2
    espToggleBtn.BorderColor3 = theme.danger
    espToggleBtn.Parent = espToggleContainer

    local espBtnCorner = Instance.new("UICorner")
    espBtnCorner.CornerRadius = UDim.new(0, 8)
    espBtnCorner.Parent = espToggleBtn

    local espStatusContainer = Instance.new("Frame")
    espStatusContainer.Size = UDim2.new(1, 0, 0, 16)
    espStatusContainer.Position = UDim2.new(0, 0, 0, 66)
    espStatusContainer.BackgroundTransparency = 1
    espStatusContainer.Parent = espSection

    local espStatusLabel = Instance.new("TextLabel")
    espStatusLabel.Size = UDim2.new(1, 0, 1, 0)
    espStatusLabel.BackgroundTransparency = 1
    espStatusLabel.Text = "Nome • Distância • Chams"
    espStatusLabel.TextColor3 = theme.textMuted
    espStatusLabel.TextSize = 10
    espStatusLabel.Font = Enum.Font.Gotham
    espStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    espStatusLabel.TextYAlignment = Enum.TextYAlignment.Center
    espStatusLabel.Parent = espStatusContainer

    -- ============================================
    -- SEÇÃO NOCLIP
    -- ============================================
    local noclipSection = Instance.new("Frame")
    noclipSection.Size = UDim2.new(1, 0, 0, 84)
    noclipSection.Position = UDim2.new(0, 0, 0, 320)
    noclipSection.BackgroundTransparency = 1
    noclipSection.Parent = content

    local noclipAccentBar = Instance.new("Frame")
    noclipAccentBar.Size = UDim2.new(0, 3, 0, 20)
    noclipAccentBar.Position = UDim2.new(0, 0, 0, 2)
    noclipAccentBar.BackgroundColor3 = theme.noclipColor
    noclipAccentBar.BorderSizePixel = 0
    noclipAccentBar.Parent = noclipSection

    local noclipAccentCorner = Instance.new("UICorner")
    noclipAccentCorner.CornerRadius = UDim.new(0, 2)
    noclipAccentCorner.Parent = noclipAccentBar

    local noclipAccentGlow = Instance.new("UIStroke")
    noclipAccentGlow.Thickness = 4
    noclipAccentGlow.Color = theme.noclipColor
    noclipAccentGlow.Transparency = 0.75
    noclipAccentGlow.Parent = noclipAccentBar

    local noclipTitleContainer = Instance.new("Frame")
    noclipTitleContainer.Size = UDim2.new(1, -12, 0, 22)
    noclipTitleContainer.Position = UDim2.new(0, 12, 0, 0)
    noclipTitleContainer.BackgroundTransparency = 1
    noclipTitleContainer.Parent = noclipSection

    local noclipTitleIcon = Instance.new("TextLabel")
    noclipTitleIcon.Size = UDim2.new(0, 18, 1, 0)
    noclipTitleIcon.BackgroundTransparency = 1
    noclipTitleIcon.Text = "👻"
    noclipTitleIcon.TextColor3 = theme.noclipColor
    noclipTitleIcon.TextSize = 14
    noclipTitleIcon.Font = Enum.Font.GothamBold
    noclipTitleIcon.TextXAlignment = Enum.TextXAlignment.Center
    noclipTitleIcon.TextYAlignment = Enum.TextYAlignment.Center
    noclipTitleIcon.Parent = noclipTitleContainer

    local noclipTitle = Instance.new("TextLabel")
    noclipTitle.Size = UDim2.new(1, -22, 1, 0)
    noclipTitle.Position = UDim2.new(0, 22, 0, 0)
    noclipTitle.BackgroundTransparency = 1
    noclipTitle.Text = "NOCLIP"
    noclipTitle.TextColor3 = theme.textSecondary
    noclipTitle.TextSize = 12
    noclipTitle.Font = Enum.Font.GothamBold
    noclipTitle.TextXAlignment = Enum.TextXAlignment.Left
    noclipTitle.TextYAlignment = Enum.TextYAlignment.Center
    noclipTitle.Parent = noclipTitleContainer

    local noclipToggleContainer = Instance.new("Frame")
    noclipToggleContainer.Size = UDim2.new(1, 0, 0, 34)
    noclipToggleContainer.Position = UDim2.new(0, 0, 0, 26)
    noclipToggleContainer.BackgroundTransparency = 1
    noclipToggleContainer.Parent = noclipSection

    local noclipToggleBtn = Instance.new("TextButton")
    noclipToggleBtn.Size = UDim2.new(0, 90, 0, 30)
    noclipToggleBtn.Position = UDim2.new(0.5, -45, 0.5, -15)
    noclipToggleBtn.BackgroundColor3 = theme.danger
    noclipToggleBtn.BackgroundTransparency = 0.2
    noclipToggleBtn.Text = "OFF"
    noclipToggleBtn.TextColor3 = theme.danger
    noclipToggleBtn.TextSize = 13
    noclipToggleBtn.Font = Enum.Font.GothamBold
    noclipToggleBtn.BorderSizePixel = 2
    noclipToggleBtn.BorderColor3 = theme.danger
    noclipToggleBtn.Parent = noclipToggleContainer

    local noclipBtnCorner = Instance.new("UICorner")
    noclipBtnCorner.CornerRadius = UDim.new(0, 8)
    noclipBtnCorner.Parent = noclipToggleBtn

    local noclipStatusContainer = Instance.new("Frame")
    noclipStatusContainer.Size = UDim2.new(1, 0, 0, 16)
    noclipStatusContainer.Position = UDim2.new(0, 0, 0, 66)
    noclipStatusContainer.BackgroundTransparency = 1
    noclipStatusContainer.Parent = noclipSection

    local noclipStatusLabel = Instance.new("TextLabel")
    noclipStatusLabel.Size = UDim2.new(1, 0, 1, 0)
    noclipStatusLabel.BackgroundTransparency = 1
    noclipStatusLabel.Text = "Atravesse paredes"
    noclipStatusLabel.TextColor3 = theme.textMuted
    noclipStatusLabel.TextSize = 10
    noclipStatusLabel.Font = Enum.Font.Gotham
    noclipStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    noclipStatusLabel.TextYAlignment = Enum.TextYAlignment.Center
    noclipStatusLabel.Parent = noclipStatusContainer

    -- ============================================
    -- SEÇÃO AUTO PRESSER
    -- ============================================
    local autoPresserSection = Instance.new("Frame")
    autoPresserSection.Size = UDim2.new(1, 0, 0, 128)
    autoPresserSection.Position = UDim2.new(0, 0, 0, 404)
    autoPresserSection.BackgroundTransparency = 1
    autoPresserSection.Parent = content

    local autoPresserAccentBar = Instance.new("Frame")
    autoPresserAccentBar.Size = UDim2.new(0, 3, 0, 20)
    autoPresserAccentBar.Position = UDim2.new(0, 0, 0, 2)
    autoPresserAccentBar.BackgroundColor3 = theme.autoPresserColor
    autoPresserAccentBar.BorderSizePixel = 0
    autoPresserAccentBar.Parent = autoPresserSection

    local autoPresserAccentCorner = Instance.new("UICorner")
    autoPresserAccentCorner.CornerRadius = UDim.new(0, 2)
    autoPresserAccentCorner.Parent = autoPresserAccentBar

    local autoPresserAccentGlow = Instance.new("UIStroke")
    autoPresserAccentGlow.Thickness = 4
    autoPresserAccentGlow.Color = theme.autoPresserColor
    autoPresserAccentGlow.Transparency = 0.75
    autoPresserAccentGlow.Parent = autoPresserAccentBar

    local autoPresserTitleContainer = Instance.new("Frame")
    autoPresserTitleContainer.Size = UDim2.new(1, -12, 0, 22)
    autoPresserTitleContainer.Position = UDim2.new(0, 12, 0, 0)
    autoPresserTitleContainer.BackgroundTransparency = 1
    autoPresserTitleContainer.Parent = autoPresserSection

    local autoPresserTitleIcon = Instance.new("TextLabel")
    autoPresserTitleIcon.Size = UDim2.new(0, 18, 1, 0)
    autoPresserTitleIcon.BackgroundTransparency = 1
    autoPresserTitleIcon.Text = "🖱️"
    autoPresserTitleIcon.TextColor3 = theme.autoPresserColor
    autoPresserTitleIcon.TextSize = 14
    autoPresserTitleIcon.Font = Enum.Font.GothamBold
    autoPresserTitleIcon.TextXAlignment = Enum.TextXAlignment.Center
    autoPresserTitleIcon.TextYAlignment = Enum.TextYAlignment.Center
    autoPresserTitleIcon.Parent = autoPresserTitleContainer

    local autoPresserTitle = Instance.new("TextLabel")
    autoPresserTitle.Size = UDim2.new(1, -22, 1, 0)
    autoPresserTitle.Position = UDim2.new(0, 22, 0, 0)
    autoPresserTitle.BackgroundTransparency = 1
    autoPresserTitle.Text = "AUTO PRESSER"
    autoPresserTitle.TextColor3 = theme.textSecondary
    autoPresserTitle.TextSize = 12
    autoPresserTitle.Font = Enum.Font.GothamBold
    autoPresserTitle.TextXAlignment = Enum.TextXAlignment.Left
    autoPresserTitle.TextYAlignment = Enum.TextYAlignment.Center
    autoPresserTitle.Parent = autoPresserTitleContainer

    local autoPresserToggleContainer = Instance.new("Frame")
    autoPresserToggleContainer.Size = UDim2.new(1, 0, 0, 34)
    autoPresserToggleContainer.Position = UDim2.new(0, 0, 0, 26)
    autoPresserToggleContainer.BackgroundTransparency = 1
    autoPresserToggleContainer.Parent = autoPresserSection

    local autoPresserToggleBtn = Instance.new("TextButton")
    autoPresserToggleBtn.Size = UDim2.new(0, 90, 0, 30)
    autoPresserToggleBtn.Position = UDim2.new(0.5, -45, 0.5, -15)
    autoPresserToggleBtn.BackgroundColor3 = theme.danger
    autoPresserToggleBtn.BackgroundTransparency = 0.2
    autoPresserToggleBtn.Text = "OFF"
    autoPresserToggleBtn.TextColor3 = theme.danger
    autoPresserToggleBtn.TextSize = 13
    autoPresserToggleBtn.Font = Enum.Font.GothamBold
    autoPresserToggleBtn.BorderSizePixel = 2
    autoPresserToggleBtn.BorderColor3 = theme.danger
    autoPresserToggleBtn.Parent = autoPresserToggleContainer

    local autoPresserBtnCorner = Instance.new("UICorner")
    autoPresserBtnCorner.CornerRadius = UDim.new(0, 8)
    autoPresserBtnCorner.Parent = autoPresserToggleBtn

    local autoPresserStatusContainer = Instance.new("Frame")
    autoPresserStatusContainer.Size = UDim2.new(1, 0, 0, 16)
    autoPresserStatusContainer.Position = UDim2.new(0, 0, 0, 66)
    autoPresserStatusContainer.BackgroundTransparency = 1
    autoPresserStatusContainer.Parent = autoPresserSection

    local autoPresserStatusLabel = Instance.new("TextLabel")
    autoPresserStatusLabel.Size = UDim2.new(1, 0, 1, 0)
    autoPresserStatusLabel.BackgroundTransparency = 1
    autoPresserStatusLabel.Text = "Ativa/Desativa com [R] • Segura [E]"
    autoPresserStatusLabel.TextColor3 = theme.textMuted
    autoPresserStatusLabel.TextSize = 10
    autoPresserStatusLabel.Font = Enum.Font.Gotham
    autoPresserStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    autoPresserStatusLabel.TextYAlignment = Enum.TextYAlignment.Center
    autoPresserStatusLabel.Parent = autoPresserStatusContainer

    local keySelectorContainer = Instance.new("Frame")
    keySelectorContainer.Size = UDim2.new(1, 0, 0, 42)
    keySelectorContainer.Position = UDim2.new(0, 0, 0, 84)
    keySelectorContainer.BackgroundTransparency = 1
    keySelectorContainer.Parent = autoPresserSection

    local toggleKeyBtn = Instance.new("TextButton")
    toggleKeyBtn.Size = UDim2.new(0.5, -6, 0, 30)
    toggleKeyBtn.Position = UDim2.new(0, 0, 0, 0)
    toggleKeyBtn.BackgroundColor3 = theme.surface2
    toggleKeyBtn.BackgroundTransparency = 0.3
    toggleKeyBtn.Text = "R"
    toggleKeyBtn.TextColor3 = theme.autoPresserColor
    toggleKeyBtn.TextSize = 15
    toggleKeyBtn.Font = Enum.Font.GothamBold
    toggleKeyBtn.BorderSizePixel = 2
    toggleKeyBtn.BorderColor3 = theme.autoPresserColor
    toggleKeyBtn.Parent = keySelectorContainer

    local toggleKeyBtnCorner = Instance.new("UICorner")
    toggleKeyBtnCorner.CornerRadius = UDim.new(0, 8)
    toggleKeyBtnCorner.Parent = toggleKeyBtn

    local toggleKeyCaption = Instance.new("TextLabel")
    toggleKeyCaption.Size = UDim2.new(0.5, -6, 0, 12)
    toggleKeyCaption.Position = UDim2.new(0, 0, 1, -12)
    toggleKeyCaption.BackgroundTransparency = 1
    toggleKeyCaption.Text = "TECLA ATIVA"
    toggleKeyCaption.TextColor3 = theme.textMuted
    toggleKeyCaption.TextSize = 8
    toggleKeyCaption.Font = Enum.Font.GothamBold
    toggleKeyCaption.TextXAlignment = Enum.TextXAlignment.Center
    toggleKeyCaption.Parent = keySelectorContainer

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

    local pressKeyBtnCorner = Instance.new("UICorner")
    pressKeyBtnCorner.CornerRadius = UDim.new(0, 8)
    pressKeyBtnCorner.Parent = pressKeyBtn

    local pressKeyCaption = Instance.new("TextLabel")
    pressKeyCaption.Size = UDim2.new(0.5, -6, 0, 12)
    pressKeyCaption.Position = UDim2.new(0.5, 6, 1, -12)
    pressKeyCaption.BackgroundTransparency = 1
    pressKeyCaption.Text = "TECLA SEGURA"
    pressKeyCaption.TextColor3 = theme.textMuted
    pressKeyCaption.TextSize = 8
    pressKeyCaption.Font = Enum.Font.GothamBold
    pressKeyCaption.TextXAlignment = Enum.TextXAlignment.Center
    pressKeyCaption.Parent = keySelectorContainer

    -- ============================================
    -- SEÇÃO HITBOX EXPANDER
    -- ============================================
    local hitboxSection = Instance.new("Frame")
    hitboxSection.Size = UDim2.new(1, 0, 0, 84)
    hitboxSection.Position = UDim2.new(0, 0, 0, 532)
    hitboxSection.BackgroundTransparency = 1
    hitboxSection.Parent = content

    local hitboxAccentBar = Instance.new("Frame")
    hitboxAccentBar.Size = UDim2.new(0, 3, 0, 20)
    hitboxAccentBar.Position = UDim2.new(0, 0, 0, 2)
    hitboxAccentBar.BackgroundColor3 = theme.hitboxColor
    hitboxAccentBar.BorderSizePixel = 0
    hitboxAccentBar.Parent = hitboxSection

    local hitboxAccentCorner = Instance.new("UICorner")
    hitboxAccentCorner.CornerRadius = UDim.new(0, 2)
    hitboxAccentCorner.Parent = hitboxAccentBar

    local hitboxAccentGlow = Instance.new("UIStroke")
    hitboxAccentGlow.Thickness = 4
    hitboxAccentGlow.Color = theme.hitboxColor
    hitboxAccentGlow.Transparency = 0.75
    hitboxAccentGlow.Parent = hitboxAccentBar

    local hitboxTitleContainer = Instance.new("Frame")
    hitboxTitleContainer.Size = UDim2.new(1, -12, 0, 22)
    hitboxTitleContainer.Position = UDim2.new(0, 12, 0, 0)
    hitboxTitleContainer.BackgroundTransparency = 1
    hitboxTitleContainer.Parent = hitboxSection

    local hitboxTitleIcon = Instance.new("TextLabel")
    hitboxTitleIcon.Size = UDim2.new(0, 18, 1, 0)
    hitboxTitleIcon.BackgroundTransparency = 1
    hitboxTitleIcon.Text = "🎯"
    hitboxTitleIcon.TextColor3 = theme.hitboxColor
    hitboxTitleIcon.TextSize = 14
    hitboxTitleIcon.Font = Enum.Font.GothamBold
    hitboxTitleIcon.TextXAlignment = Enum.TextXAlignment.Center
    hitboxTitleIcon.TextYAlignment = Enum.TextYAlignment.Center
    hitboxTitleIcon.Parent = hitboxTitleContainer

    local hitboxTitle = Instance.new("TextLabel")
    hitboxTitle.Size = UDim2.new(1, -22, 1, 0)
    hitboxTitle.Position = UDim2.new(0, 22, 0, 0)
    hitboxTitle.BackgroundTransparency = 1
    hitboxTitle.Text = "HITBOX EXPANDER"
    hitboxTitle.TextColor3 = theme.textSecondary
    hitboxTitle.TextSize = 12
    hitboxTitle.Font = Enum.Font.GothamBold
    hitboxTitle.TextXAlignment = Enum.TextXAlignment.Left
    hitboxTitle.TextYAlignment = Enum.TextYAlignment.Center
    hitboxTitle.Parent = hitboxTitleContainer

    local hitboxToggleContainer = Instance.new("Frame")
    hitboxToggleContainer.Size = UDim2.new(1, 0, 0, 34)
    hitboxToggleContainer.Position = UDim2.new(0, 0, 0, 26)
    hitboxToggleContainer.BackgroundTransparency = 1
    hitboxToggleContainer.Parent = hitboxSection

    local hitboxToggleBtn = Instance.new("TextButton")
    hitboxToggleBtn.Size = UDim2.new(0, 90, 0, 30)
    hitboxToggleBtn.Position = UDim2.new(0.5, -48, 0.5, -15)
    hitboxToggleBtn.BackgroundColor3 = theme.danger
    hitboxToggleBtn.BackgroundTransparency = 0.2
    hitboxToggleBtn.Text = "OFF"
    hitboxToggleBtn.TextColor3 = theme.danger
    hitboxToggleBtn.TextSize = 13
    hitboxToggleBtn.Font = Enum.Font.GothamBold
    hitboxToggleBtn.BorderSizePixel = 2
    hitboxToggleBtn.BorderColor3 = theme.danger
    hitboxToggleBtn.Parent = hitboxToggleContainer

    local hitboxBtnCorner = Instance.new("UICorner")
    hitboxBtnCorner.CornerRadius = UDim.new(0, 8)
    hitboxBtnCorner.Parent = hitboxToggleBtn

    local hitboxViewBtn = Instance.new("TextButton")
    hitboxViewBtn.Size = UDim2.new(0, 30, 0, 30)
    hitboxViewBtn.Position = UDim2.new(0.5, 48, 0.5, -15)
    hitboxViewBtn.BackgroundColor3 = theme.surface2
    hitboxViewBtn.BackgroundTransparency = 0.3
    hitboxViewBtn.Text = "👁"
    hitboxViewBtn.TextColor3 = theme.textMuted
    hitboxViewBtn.TextSize = 16
    hitboxViewBtn.Font = Enum.Font.GothamBold
    hitboxViewBtn.BorderSizePixel = 2
    hitboxViewBtn.BorderColor3 = theme.danger
    hitboxViewBtn.Parent = hitboxToggleContainer

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
    xOverlay1.Visible = true
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
    xOverlay2.Visible = true
    xOverlay2.Parent = hitboxViewBtn

    local xOverlay2Corner = Instance.new("UICorner")
    xOverlay2Corner.CornerRadius = UDim.new(1, 0)
    xOverlay2Corner.Parent = xOverlay2

    local hitboxStatusContainer = Instance.new("Frame")
    hitboxStatusContainer.Size = UDim2.new(1, 0, 0, 16)
    hitboxStatusContainer.Position = UDim2.new(0, 0, 0, 66)
    hitboxStatusContainer.BackgroundTransparency = 1
    hitboxStatusContainer.Parent = hitboxSection

    local hitboxStatusLabel = Instance.new("TextLabel")
    hitboxStatusLabel.Size = UDim2.new(1, 0, 1, 0)
    hitboxStatusLabel.BackgroundTransparency = 1
    hitboxStatusLabel.Text = "Expanda a hitbox dos jogadores"
    hitboxStatusLabel.TextColor3 = theme.textMuted
    hitboxStatusLabel.TextSize = 10
    hitboxStatusLabel.Font = Enum.Font.Gotham
    hitboxStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    hitboxStatusLabel.TextYAlignment = Enum.TextYAlignment.Center
    hitboxStatusLabel.Parent = hitboxStatusContainer

    -- ============================================
    -- SEÇÃO FLY
    -- ============================================
    local flySection = Instance.new("Frame")
    flySection.Size = UDim2.new(1, 0, 0, 116)
    flySection.Position = UDim2.new(0, 0, 0, 616)
    flySection.BackgroundTransparency = 1
    flySection.Parent = content

    local flyAccentBar = Instance.new("Frame")
    flyAccentBar.Size = UDim2.new(0, 3, 0, 20)
    flyAccentBar.Position = UDim2.new(0, 0, 0, 2)
    flyAccentBar.BackgroundColor3 = theme.flyColor
    flyAccentBar.BorderSizePixel = 0
    flyAccentBar.Parent = flySection

    local flyAccentCorner = Instance.new("UICorner")
    flyAccentCorner.CornerRadius = UDim.new(0, 2)
    flyAccentCorner.Parent = flyAccentBar

    local flyAccentGlow = Instance.new("UIStroke")
    flyAccentGlow.Thickness = 4
    flyAccentGlow.Color = theme.flyColor
    flyAccentGlow.Transparency = 0.75
    flyAccentGlow.Parent = flyAccentBar

    local flyTitleContainer = Instance.new("Frame")
    flyTitleContainer.Size = UDim2.new(1, -12, 0, 22)
    flyTitleContainer.Position = UDim2.new(0, 12, 0, 0)
    flyTitleContainer.BackgroundTransparency = 1
    flyTitleContainer.Parent = flySection

    local flyTitleIcon = Instance.new("TextLabel")
    flyTitleIcon.Size = UDim2.new(0, 18, 1, 0)
    flyTitleIcon.BackgroundTransparency = 1
    flyTitleIcon.Text = "✈️"
    flyTitleIcon.TextColor3 = theme.flyColor
    flyTitleIcon.TextSize = 14
    flyTitleIcon.Font = Enum.Font.GothamBold
    flyTitleIcon.TextXAlignment = Enum.TextXAlignment.Center
    flyTitleIcon.TextYAlignment = Enum.TextYAlignment.Center
    flyTitleIcon.Parent = flyTitleContainer

    local flyTitle = Instance.new("TextLabel")
    flyTitle.Size = UDim2.new(1, -22, 1, 0)
    flyTitle.Position = UDim2.new(0, 22, 0, 0)
    flyTitle.BackgroundTransparency = 1
    flyTitle.Text = "FLY"
    flyTitle.TextColor3 = theme.textSecondary
    flyTitle.TextSize = 12
    flyTitle.Font = Enum.Font.GothamBold
    flyTitle.TextXAlignment = Enum.TextXAlignment.Left
    flyTitle.TextYAlignment = Enum.TextYAlignment.Center
    flyTitle.Parent = flyTitleContainer

    local flySpeedDisplay = Instance.new("Frame")
    flySpeedDisplay.Size = UDim2.new(0, 76, 0, 28)
    flySpeedDisplay.Position = UDim2.new(0.5, -38, 0, 26)
    flySpeedDisplay.BackgroundColor3 = theme.surface2
    flySpeedDisplay.BackgroundTransparency = 0.3
    flySpeedDisplay.BorderSizePixel = 0
    flySpeedDisplay.Parent = flySection

    local flyDisplayCorner = Instance.new("UICorner")
    flyDisplayCorner.CornerRadius = UDim.new(0, 8)
    flyDisplayCorner.Parent = flySpeedDisplay

    local flyDisplayStroke = Instance.new("UIStroke")
    flyDisplayStroke.Thickness = 1
    flyDisplayStroke.Color = theme.border
    flyDisplayStroke.Transparency = 0.3
    flyDisplayStroke.Parent = flySpeedDisplay

    local flySpeedValue = Instance.new("TextLabel")
    flySpeedValue.Size = UDim2.new(1, 0, 0.6, 0)
    flySpeedValue.Position = UDim2.new(0, 0, 0.1, 0)
    flySpeedValue.BackgroundTransparency = 1
    flySpeedValue.Text = tostring(flyModule.speed)
    flySpeedValue.TextColor3 = theme.flyColor
    flySpeedValue.TextSize = 18
    flySpeedValue.Font = Enum.Font.GothamBold
    flySpeedValue.TextXAlignment = Enum.TextXAlignment.Center
    flySpeedValue.TextYAlignment = Enum.TextYAlignment.Bottom
    flySpeedValue.Parent = flySpeedDisplay

    local flySpeedUnit = Instance.new("TextLabel")
    flySpeedUnit.Size = UDim2.new(1, 0, 0.3, 0)
    flySpeedUnit.Position = UDim2.new(0, 0, 0.65, 0)
    flySpeedUnit.BackgroundTransparency = 1
    flySpeedUnit.Text = "FLY VEL"
    flySpeedUnit.TextColor3 = theme.textMuted
    flySpeedUnit.TextSize = 6
    flySpeedUnit.Font = Enum.Font.Gotham
    flySpeedUnit.TextXAlignment = Enum.TextXAlignment.Center
    flySpeedUnit.TextYAlignment = Enum.TextYAlignment.Top
    flySpeedUnit.Parent = flySpeedDisplay

    local flySliderContainer = Instance.new("Frame")
    flySliderContainer.Size = UDim2.new(1, -16, 0, 20)
    flySliderContainer.Position = UDim2.new(0, 8, 0, 60)
    flySliderContainer.BackgroundTransparency = 1
    flySliderContainer.ClipsDescendants = false
    flySliderContainer.Parent = flySection

    local flyMinLabel = Instance.new("TextLabel")
    flyMinLabel.Size = UDim2.new(0, 16, 1, 0)
    flyMinLabel.BackgroundTransparency = 1
    flyMinLabel.Text = "1"
    flyMinLabel.TextColor3 = theme.textMuted
    flyMinLabel.TextSize = 7
    flyMinLabel.Font = Enum.Font.Gotham
    flyMinLabel.TextXAlignment = Enum.TextXAlignment.Center
    flyMinLabel.TextYAlignment = Enum.TextYAlignment.Center
    flyMinLabel.Parent = flySliderContainer

    local flyMaxLabel = Instance.new("TextLabel")
    flyMaxLabel.Size = UDim2.new(0, 16, 1, 0)
    flyMaxLabel.Position = UDim2.new(1, -16, 0, 0)
    flyMaxLabel.BackgroundTransparency = 1
    flyMaxLabel.Text = "10"
    flyMaxLabel.TextColor3 = theme.textMuted
    flyMaxLabel.TextSize = 7
    flyMaxLabel.Font = Enum.Font.Gotham
    flyMaxLabel.TextXAlignment = Enum.TextXAlignment.Center
    flyMaxLabel.TextYAlignment = Enum.TextYAlignment.Center
    flyMaxLabel.Parent = flySliderContainer

    local flySliderTrack = Instance.new("Frame")
    flySliderTrack.Size = UDim2.new(1, -44, 0, 4)
    flySliderTrack.Position = UDim2.new(0, 22, 0.5, -2)
    flySliderTrack.BackgroundColor3 = theme.surface3
    flySliderTrack.BorderSizePixel = 0
    flySliderTrack.ClipsDescendants = false
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

    local flyToggleContainer = Instance.new("Frame")
    flyToggleContainer.Size = UDim2.new(1, 0, 0, 34)
    flyToggleContainer.Position = UDim2.new(0, 0, 0, 82)
    flyToggleContainer.BackgroundTransparency = 1
    flyToggleContainer.Parent = flySection

    local flyToggleBtn = Instance.new("TextButton")
    flyToggleBtn.Size = UDim2.new(0, 90, 0, 30)
    flyToggleBtn.Position = UDim2.new(0.5, -45, 0.5, -15)
    flyToggleBtn.BackgroundColor3 = theme.danger
    flyToggleBtn.BackgroundTransparency = 0.2
    flyToggleBtn.Text = "OFF"
    flyToggleBtn.TextColor3 = theme.danger
    flyToggleBtn.TextSize = 13
    flyToggleBtn.Font = Enum.Font.GothamBold
    flyToggleBtn.BorderSizePixel = 2
    flyToggleBtn.BorderColor3 = theme.danger
    flyToggleBtn.Parent = flyToggleContainer

    local flyBtnCorner = Instance.new("UICorner")
    flyBtnCorner.CornerRadius = UDim.new(0, 8)
    flyBtnCorner.Parent = flyToggleBtn

    local flyStatusContainer = Instance.new("Frame")
    flyStatusContainer.Size = UDim2.new(1, 0, 0, 16)
    flyStatusContainer.Position = UDim2.new(0, 0, 0, 116)
    flyStatusContainer.BackgroundTransparency = 1
    flyStatusContainer.Parent = flySection

    local flyStatusLabel = Instance.new("TextLabel")
    flyStatusLabel.Size = UDim2.new(1, 0, 1, 0)
    flyStatusLabel.BackgroundTransparency = 1
    flyStatusLabel.Text = "Pressione F para voar"
    flyStatusLabel.TextColor3 = theme.textMuted
    flyStatusLabel.TextSize = 10
    flyStatusLabel.Font = Enum.Font.Gotham
    flyStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    flyStatusLabel.TextYAlignment = Enum.TextYAlignment.Center
    flyStatusLabel.Parent = flyStatusContainer

    -- ============================================
    -- ESPAÇO EXTRA
    -- ============================================
    local bottomSpacer = Instance.new("Frame")
    bottomSpacer.Size = UDim2.new(1, 0, 0, 15)
    bottomSpacer.Position = UDim2.new(0, 0, 0, 735)
    bottomSpacer.BackgroundTransparency = 1
    bottomSpacer.Parent = content

    -- ============================================
    -- LÓGICA DOS SLIDERS
    -- ============================================
    local speedIsActive = false
    local speedMin, speedMax = 5, 500
    local currentSpeedValue = speedModule.currentSpeed or 16
    local speedDragging = false
    local speedDragConnection, speedReleaseConnection = nil, nil

    local function updateSpeedSliderVisual(value)
        local percent = math.clamp((value - speedMin) / (speedMax - speedMin), 0, 1)
        sliderFill.Size = UDim2.new(percent, 0, 1, 0)
        local trackWidth = sliderTrack.AbsoluteSize.X
        local thumbWidth = sliderButton.AbsoluteSize.X
        if trackWidth > 0 and thumbWidth > 0 then
            local maxX = trackWidth - thumbWidth
            sliderButton.Position = UDim2.new(0, percent * maxX, 0.5, -thumbWidth / 2)
        end
        speedValue.Text = tostring(math.floor(value))
    end

    local function setSpeedValueFromInput(inputX)
        local trackLeft = sliderTrack.AbsolutePosition.X
        local trackWidth = sliderTrack.AbsoluteSize.X
        local thumbWidth = sliderButton.AbsoluteSize.X
        if trackWidth <= 0 then return end
        local maxX = trackWidth - thumbWidth
        if maxX <= 0 then return end
        local relativeX = inputX - trackLeft - (thumbWidth / 2)
        local percent = math.clamp(relativeX / maxX, 0, 1)
        local value = speedMin + percent * (speedMax - speedMin)
        currentSpeedValue = value
        speedModule:setSpeed(value)
        updateSpeedSliderVisual(value)
    end

    task.spawn(function()
        while sliderTrack.AbsoluteSize.X <= 0 do RunService.RenderStepped:Wait() end
        updateSpeedSliderVisual(currentSpeedValue)
    end)

    sliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            speedDragging = true
            speedDragConnection = UIS.InputChanged:Connect(function(moveInput)
                if (moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch) and speedDragging then
                    setSpeedValueFromInput(moveInput.Position.X)
                end
            end)
            speedReleaseConnection = UIS.InputEnded:Connect(function(endInput)
                if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
                    speedDragging = false
                    if speedDragConnection then speedDragConnection:Disconnect() speedDragConnection = nil end
                    if speedReleaseConnection then speedReleaseConnection:Disconnect() speedReleaseConnection = nil end
                end
            end)
        end
    end)

    sliderTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            setSpeedValueFromInput(input.Position.X)
        end
    end)

    -- Slider Fly
    local flyMin, flyMax = 1, 10
    local currentFlyValue = flyModule.speed or 1
    local flyDragging = false
    local flyDragConnection, flyReleaseConnection = nil, nil

    local function updateFlySliderVisual(value)
        local percent = math.clamp((value - flyMin) / (flyMax - flyMin), 0, 1)
        flySliderFill.Size = UDim2.new(percent, 0, 1, 0)
        local trackWidth = flySliderTrack.AbsoluteSize.X
        local thumbWidth = flySliderButton.AbsoluteSize.X
        if trackWidth > 0 and thumbWidth > 0 then
            local maxX = trackWidth - thumbWidth
            flySliderButton.Position = UDim2.new(0, percent * maxX, 0.5, -thumbWidth / 2)
        end
        flySpeedValue.Text = tostring(math.floor(value))
    end

    local function setFlyValueFromInput(inputX)
        local trackLeft = flySliderTrack.AbsolutePosition.X
        local trackWidth = flySliderTrack.AbsoluteSize.X
        local thumbWidth = flySliderButton.AbsoluteSize.X
        if trackWidth <= 0 then return end
        local maxX = trackWidth - thumbWidth
        if maxX <= 0 then return end
        local relativeX = inputX - trackLeft - (thumbWidth / 2)
        local percent = math.clamp(relativeX / maxX, 0, 1)
        local value = math.floor(flyMin + percent * (flyMax - flyMin) + 0.5)
        currentFlyValue = value
        flyModule:setSpeed(value)
        updateFlySliderVisual(value)
    end

    task.spawn(function()
        while flySliderTrack.AbsoluteSize.X <= 0 do RunService.RenderStepped:Wait() end
        updateFlySliderVisual(currentFlyValue)
    end)

    flySliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            flyDragging = true
            flyDragConnection = UIS.InputChanged:Connect(function(moveInput)
                if (moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch) and flyDragging then
                    setFlyValueFromInput(moveInput.Position.X)
                end
            end)
            flyReleaseConnection = UIS.InputEnded:Connect(function(endInput)
                if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
                    flyDragging = false
                    if flyDragConnection then flyDragConnection:Disconnect() flyDragConnection = nil end
                    if flyReleaseConnection then flyReleaseConnection:Disconnect() flyReleaseConnection = nil end
                end
            end)
        end
    end)

    flySliderTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            setFlyValueFromInput(input.Position.X)
        end
    end)

    -- ============================================
    -- HANDLERS DO AUTO PRESSER
    -- ============================================
    local function updateAutoPresserStatus()
        local keyT = autoPresserModule.toggleKey.Name
        local keyP = autoPresserModule.pressKey.Name

        if not autoPresserModule.isEnabled then
            autoPresserToggleBtn.Text = "OFF"
            autoPresserToggleBtn.TextColor3 = theme.danger
            autoPresserToggleBtn.BackgroundColor3 = theme.danger
            autoPresserToggleBtn.BackgroundTransparency = 0.2
            autoPresserToggleBtn.BorderColor3 = theme.danger
            autoPresserStatusLabel.Text = string.format("Ativa/Desativa com [%s] • Segura [%s]", keyT, keyP)
            autoPresserStatusLabel.TextColor3 = theme.textMuted
        elseif autoPresserModule.isHolding then
            autoPresserToggleBtn.Text = "ON"
            autoPresserToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            autoPresserToggleBtn.BackgroundColor3 = theme.success
            autoPresserToggleBtn.BackgroundTransparency = 0.3
            autoPresserToggleBtn.BorderColor3 = theme.success
            autoPresserStatusLabel.Text = string.format("Pressione [%s] para parar • Segurando [%s]", keyT, keyP)
            autoPresserStatusLabel.TextColor3 = Color3.fromRGB(180, 255, 210)
        else
            autoPresserToggleBtn.Text = "ON"
            autoPresserToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            autoPresserToggleBtn.BackgroundColor3 = theme.success
            autoPresserToggleBtn.BackgroundTransparency = 0.3
            autoPresserToggleBtn.BorderColor3 = theme.success
            autoPresserStatusLabel.Text = string.format("Pressione [%s] para segurar [%s]", keyT, keyP)
            autoPresserStatusLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
        end
    end

    autoPresserModule.onHoldChanged = function() updateAutoPresserStatus() end

    autoPresserToggleBtn.MouseButton1Click:Connect(function()
        autoPresserModule:toggle()
        updateAutoPresserStatus()
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
        captureConnection = UIS.InputBegan:Connect(function(input, gameProcessed)
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
            updateAutoPresserStatus()
            stopCapturing()
        end)
    end

    toggleKeyBtn.MouseButton1Click:Connect(function() startCapturing("toggle") end)
    pressKeyBtn.MouseButton1Click:Connect(function() startCapturing("press") end)

    -- ============================================
    -- HANDLERS DOS OUTROS BOTÕES
    -- ============================================
    speedToggleBtn.MouseButton1Click:Connect(function()
        speedIsActive = not speedIsActive
        if speedIsActive then
            speedModule:enable()
            speedToggleBtn.Text = "ON"
            speedToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            speedToggleBtn.BackgroundColor3 = theme.success
            speedToggleBtn.BackgroundTransparency = 0.15
            speedToggleBtn.BorderColor3 = theme.success
            local g = speedToggleBtn:FindFirstChildOfClass("UIGradient")
            if not g then g = Instance.new("UIGradient") g.Parent = speedToggleBtn end
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 230, 118)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 150, 80)),
            })
            g.Rotation = 90
        else
            speedModule:disable()
            speedToggleBtn.Text = "OFF"
            speedToggleBtn.TextColor3 = theme.danger
            speedToggleBtn.BackgroundColor3 = theme.danger
            speedToggleBtn.BackgroundTransparency = 0.15
            speedToggleBtn.BorderColor3 = theme.danger
            local g = speedToggleBtn:FindFirstChildOfClass("UIGradient")
            if g then g:Destroy() end
        end
    end)

    jumpToggleBtn.MouseButton1Click:Connect(function()
        if jumpModule.isEnabled then
            jumpModule:disable()
            jumpToggleBtn.Text = "OFF"
            jumpToggleBtn.TextColor3 = theme.danger
            jumpToggleBtn.BackgroundColor3 = theme.danger
            jumpToggleBtn.BackgroundTransparency = 0.2
            jumpToggleBtn.BorderColor3 = theme.danger
            local g = jumpToggleBtn:FindFirstChildOfClass("UIGradient")
            if g then g:Destroy() end
        else
            jumpModule:enable()
            jumpToggleBtn.Text = "ON"
            jumpToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            jumpToggleBtn.BackgroundColor3 = theme.success
            jumpToggleBtn.BackgroundTransparency = 0.15
            jumpToggleBtn.BorderColor3 = theme.success
            local g = Instance.new("UIGradient")
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 230, 118)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 150, 80)),
            })
            g.Rotation = 90
            g.Parent = jumpToggleBtn
        end
    end)

    espToggleBtn.MouseButton1Click:Connect(function()
        if espModule.isEnabled then
            espModule:disable()
            espToggleBtn.Text = "OFF"
            espToggleBtn.TextColor3 = theme.danger
            espToggleBtn.BackgroundColor3 = theme.danger
            espToggleBtn.BackgroundTransparency = 0.2
            espToggleBtn.BorderColor3 = theme.danger
            local g = espToggleBtn:FindFirstChildOfClass("UIGradient")
            if g then g:Destroy() end
        else
            espModule:enable()
            espToggleBtn.Text = "ON"
            espToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            espToggleBtn.BackgroundColor3 = theme.success
            espToggleBtn.BackgroundTransparency = 0.15
            espToggleBtn.BorderColor3 = theme.success
            local g = Instance.new("UIGradient")
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 230, 118)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 150, 80)),
            })
            g.Rotation = 90
            g.Parent = espToggleBtn
        end
    end)

    noclipToggleBtn.MouseButton1Click:Connect(function()
        if noclipModule.isEnabled then
            noclipModule:disable()
            noclipToggleBtn.Text = "OFF"
            noclipToggleBtn.TextColor3 = theme.danger
            noclipToggleBtn.BackgroundColor3 = theme.danger
            noclipToggleBtn.BackgroundTransparency = 0.2
            noclipToggleBtn.BorderColor3 = theme.danger
            local g = noclipToggleBtn:FindFirstChildOfClass("UIGradient")
            if g then g:Destroy() end
        else
            noclipModule:enable()
            noclipToggleBtn.Text = "ON"
            noclipToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            noclipToggleBtn.BackgroundColor3 = theme.success
            noclipToggleBtn.BackgroundTransparency = 0.15
            noclipToggleBtn.BorderColor3 = theme.success
            local g = Instance.new("UIGradient")
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 230, 118)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 150, 80)),
            })
            g.Rotation = 90
            g.Parent = noclipToggleBtn
        end
    end)

    hitboxToggleBtn.MouseButton1Click:Connect(function()
        if hitboxModule.isEnabled then
            hitboxModule:disable()
            hitboxToggleBtn.Text = "OFF"
            hitboxToggleBtn.TextColor3 = theme.danger
            hitboxToggleBtn.BackgroundColor3 = theme.danger
            hitboxToggleBtn.BackgroundTransparency = 0.2
            hitboxToggleBtn.BorderColor3 = theme.danger
            local g = hitboxToggleBtn:FindFirstChildOfClass("UIGradient")
            if g then g:Destroy() end
        else
            hitboxModule:enable()
            hitboxToggleBtn.Text = "ON"
            hitboxToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            hitboxToggleBtn.BackgroundColor3 = theme.success
            hitboxToggleBtn.BackgroundTransparency = 0.15
            hitboxToggleBtn.BorderColor3 = theme.success
            local g = Instance.new("UIGradient")
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 230, 118)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 150, 80)),
            })
            g.Rotation = 90
            g.Parent = hitboxToggleBtn
        end
    end)

    hitboxViewBtn.MouseButton1Click:Connect(function()
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

    flyToggleBtn.MouseButton1Click:Connect(function()
        if flyModule.isEnabled then
            flyModule:disable()
            flyToggleBtn.Text = "OFF"
            flyToggleBtn.TextColor3 = theme.danger
            flyToggleBtn.BackgroundColor3 = theme.danger
            flyToggleBtn.BackgroundTransparency = 0.2
            flyToggleBtn.BorderColor3 = theme.danger
            local g = flyToggleBtn:FindFirstChildOfClass("UIGradient")
            if g then g:Destroy() end
        else
            flyModule:enable()
            flyToggleBtn.Text = "ON"
            flyToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            flyToggleBtn.BackgroundColor3 = theme.success
            flyToggleBtn.BackgroundTransparency = 0.15
            flyToggleBtn.BorderColor3 = theme.success
            local g = Instance.new("UIGradient")
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 230, 118)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 150, 80)),
            })
            g.Rotation = 90
            g.Parent = flyToggleBtn
        end
    end)

    -- ============================================
    -- MINIMIZAR
    -- ============================================
    local isMinimized = false

    minBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        if isMinimized then
            content.Visible = false
            TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 240, 0, 52)
            }):Play()
            minBtn.Text = "+"
        else
            content.Visible = true
            TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 240, 0, 830)
            }):Play()
            minBtn.Text = "−"
        end
    end)

    -- ============================================
    -- FECHAR
    -- ============================================
    closeBtn.MouseButton1Click:Connect(function()
        pcall(function() speedModule:disable() end)
        pcall(function() jumpModule:disable() end)
        pcall(function() espModule:disable() end)
        pcall(function() noclipModule:disable() end)
        pcall(function() autoPresserModule:disable() end)
        pcall(function() hitboxModule:disable() end)
        pcall(function() flyModule:disable() end)
        gui:Destroy()
        print("❌ Painel fechado — todos os módulos desligados.")
    end)

    -- ============================================
    -- EFEITO DE ENTRADA
    -- ============================================
    mainFrame.BackgroundTransparency = 1
    mainFrame.Size = UDim2.new(0, 220, 0, 770)
    mainFrame.Position = UDim2.new(0.5, -110, 0.5, -385)

    task.spawn(function()
        task.wait(0.1)
        TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 240, 0, 830),
            Position = UDim2.new(0.5, -120, 0.5, -415),
            BackgroundTransparency = 0.08,
        }):Play()
    end)
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
local flyModule = FlyModule.new(config)

speedModule:initialize()

createUI(speedModule, jumpModule, espModule, noclipModule, autoPresserModule, hitboxModule, flyModule)

print("✅ Basic Settings Control v4.9.1 carregado!")
print("📏 Tamanho: 240 × 830px")
print("🎨 Melhorias visuais mantidas")
print("🖱️ Botão de fechar agora exibe X corretamente")
