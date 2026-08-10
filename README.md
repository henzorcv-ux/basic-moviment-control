--[[
    Speed Control Pro v2.8 + Infinite Jump + Noclip + Fly
    Design Premium - Textos de status em 10px
--]]

-- ============================================
-- SERVIÇOS E BIBLIOTECAS
-- ============================================

local Players, UIS, CoreGui, RunService, VirtualUser, TweenService, UserInputService = 
    game:GetService("Players"), 
    game:GetService("UserInputService"), 
    game:GetService("CoreGui"), 
    game:GetService("RunService"), 
    game:GetService("VirtualUser"), 
    game:GetService("TweenService"),
    game:GetService("UserInputService")

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
-- SISTEMA DE CONFIGURAÇÃO
-- ============================================

local ConfigManager = {}
ConfigManager.__index = ConfigManager

function ConfigManager.new()
    local self = setmetatable({}, ConfigManager)
    self.data = {
        speed = { value = 16, min = 5, max = 500 },
        flySpeed = { value = 1, min = 1, max = 10 },
        features = { speedControl = false, infiniteJump = false, noclip = false, fly = false },
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
-- MÓDULO DE CONTROLE DE VELOCIDADE
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
        local originalHumanoid = self.humanoid
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
-- MÓDULO DE NOCLIP (CORRIGIDO - SEM BUGS)
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
-- MÓDULO DE VOO (FLY) COM ESCALA DE VELOCIDADE
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
    return 50 + (self.speed * 10)
end

function FlyModule:enable()
    if self.isEnabled then return end
    self.isEnabled = true
    self.isFlying = false
    self.config:set("features.fly", true)
    self:setupFlyControls()
    self:setupKeyToggle()
    print("✈️ Fly ATIVADO! Pressione F para voar. Velocidade base: " .. self:getRealSpeed())
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
    print("✈️ Velocidade do voo ajustada para: " .. self.speed .. " (equivalente a " .. self:getRealSpeed() .. ")")
end

function FlyModule:toggleFly()
    if not self.isEnabled then return end
    
    self.isFlying = not self.isFlying
    
    if self.isFlying then
        self:startFly()
        print("✈️ Voo ATIVADO (F) - Velocidade: " .. self:getRealSpeed())
    else
        self:stopFly()
        print("✈️ Voo DESATIVADO (F)")
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
                
                local mousePos = mouse.Hit.Position
                local targetCFrame = CFrame.new(rootPart.Position, mousePos)
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
-- DESIGN PREMIUM - TEXTOS DE STATUS EM 10px
-- ============================================

local function createUI(speedModule, jumpModule, noclipModule, flyModule)
    local gui = Instance.new("ScreenGui")
    gui.Name, gui.Parent = "SpeedControlGUI", CoreGui
    gui.ResetOnSpawn, gui.IgnoreGuiInset = false, true

    -- ===== TEMA PREMIUM =====
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
        accentDark = Color3.fromRGB(60, 130, 210),
        jumpColor = Color3.fromRGB(255, 100, 150),
        jumpGlow = Color3.fromRGB(255, 50, 120),
        noclipColor = Color3.fromRGB(150, 100, 255),
        noclipGlow = Color3.fromRGB(120, 50, 255),
        flyColor = Color3.fromRGB(0, 230, 255),
        flyGlow = Color3.fromRGB(0, 180, 255),
        gradient1 = Color3.fromRGB(100, 180, 255),
        gradient2 = Color3.fromRGB(180, 100, 255),
    }

    -- ===== JANELA PRINCIPAL =====
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 260, 0, 480)
    mainFrame.Position = UDim2.new(0.5, -130, 0.5, -240)
    mainFrame.BackgroundColor3 = theme.background
    mainFrame.BackgroundTransparency = 0.08
    mainFrame.BorderSizePixel = 1
    mainFrame.BorderColor3 = theme.border
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame

    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.new(1, 16, 1, 16)
    shadow.Position = UDim2.new(0, -8, 0, -8)
    shadow.BackgroundColor3 = theme.shadow
    shadow.BackgroundTransparency = 0.6
    shadow.BorderSizePixel = 0
    shadow.ZIndex = 0
    shadow.Parent = mainFrame

    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 16)
    shadowCorner.Parent = shadow

    -- ===== CABEÇALHO =====
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundColor3 = theme.surface
    header.BackgroundTransparency = 0.5
    header.BorderSizePixel = 0
    header.Parent = mainFrame

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = header

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, theme.gradient1),
        ColorSequenceKeypoint.new(1, theme.gradient2)
    })
    gradient.Rotation = 45
    gradient.Parent = header

    local titleIcon = Instance.new("TextLabel")
    titleIcon.Size = UDim2.new(0, 24, 0, 24)
    titleIcon.Position = UDim2.new(0, 10, 0.5, -12)
    titleIcon.BackgroundTransparency = 1
    titleIcon.Text = "⚡"
    titleIcon.TextColor3 = theme.text
    titleIcon.TextSize = 18
    titleIcon.Font = Enum.Font.GothamBold
    titleIcon.TextXAlignment = Enum.TextXAlignment.Center
    titleIcon.TextYAlignment = Enum.TextYAlignment.Center
    titleIcon.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.5, 0, 1, 0)
    title.Position = UDim2.new(0, 38, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Speed Pro"
    title.TextColor3 = theme.text
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.Parent = header

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(0.5, 0, 1, 0)
    subtitle.Position = UDim2.new(0, 38, 0, 0)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Velocidade • Pulo • Noclip • Fly"
    subtitle.TextColor3 = theme.textSecondary
    subtitle.TextSize = 7
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextYAlignment = Enum.TextYAlignment.Bottom
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
    minCorner.CornerRadius = UDim.new(0, 5)
    minCorner.Parent = minBtn

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(1, -24, 0.5, -11)
    closeBtn.BackgroundColor3 = theme.surface2
    closeBtn.BackgroundTransparency = 0.5
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = theme.textSecondary
    closeBtn.TextSize = 11
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = headerButtons

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 5)
    closeCorner.Parent = closeBtn

    -- ===== CONTEÚDO =====
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -24, 1, -64)
    content.Position = UDim2.new(0, 12, 0, 56)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame

    -- ============================================
    -- SEÇÃO VELOCIDADE
    -- ============================================
    local speedSection = Instance.new("Frame")
    speedSection.Size = UDim2.new(1, 0, 0, 135)
    speedSection.BackgroundTransparency = 1
    speedSection.Parent = content

    local speedTitleContainer = Instance.new("Frame")
    speedTitleContainer.Size = UDim2.new(1, 0, 0, 20)
    speedTitleContainer.BackgroundTransparency = 1
    speedTitleContainer.Parent = speedSection

    local speedTitleIcon = Instance.new("TextLabel")
    speedTitleIcon.Size = UDim2.new(0, 16, 1, 0)
    speedTitleIcon.BackgroundTransparency = 1
    speedTitleIcon.Text = "⚡"
    speedTitleIcon.TextColor3 = theme.accent
    speedTitleIcon.TextSize = 12
    speedTitleIcon.Font = Enum.Font.GothamBold
    speedTitleIcon.TextXAlignment = Enum.TextXAlignment.Center
    speedTitleIcon.TextYAlignment = Enum.TextYAlignment.Center
    speedTitleIcon.Parent = speedTitleContainer

    local speedTitle = Instance.new("TextLabel")
    speedTitle.Size = UDim2.new(1, -20, 1, 0)
    speedTitle.Position = UDim2.new(0, 20, 0, 0)
    speedTitle.BackgroundTransparency = 1
    speedTitle.Text = "VELOCIDADE"
    speedTitle.TextColor3 = theme.textSecondary
    speedTitle.TextSize = 9
    speedTitle.Font = Enum.Font.GothamBold
    speedTitle.TextXAlignment = Enum.TextXAlignment.Left
    speedTitle.TextYAlignment = Enum.TextYAlignment.Center
    speedTitle.Parent = speedTitleContainer

    local speedDisplay = Instance.new("Frame")
    speedDisplay.Size = UDim2.new(0, 96, 0, 50)
    speedDisplay.Position = UDim2.new(0.5, -48, 0, 24)
    speedDisplay.BackgroundColor3 = theme.surface2
    speedDisplay.BackgroundTransparency = 0.3
    speedDisplay.BorderSizePixel = 1
    speedDisplay.BorderColor3 = theme.border
    speedDisplay.Parent = speedSection

    local displayCorner = Instance.new("UICorner")
    displayCorner.CornerRadius = UDim.new(0, 10)
    displayCorner.Parent = speedDisplay

    local speedValue = Instance.new("TextLabel")
    speedValue.Size = UDim2.new(1, 0, 0.6, 0)
    speedValue.Position = UDim2.new(0, 0, 0.1, 0)
    speedValue.BackgroundTransparency = 1
    speedValue.Text = "16"
    speedValue.TextColor3 = theme.accent
    speedValue.TextSize = 26
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
    sliderContainer.ClipsDescendants = true
    sliderContainer.Parent = speedSection

    local minLabel = Instance.new("TextLabel")
    minLabel.Size = UDim2.new(0, 24, 1, 0)
    minLabel.BackgroundTransparency = 1
    minLabel.Text = "5"
    minLabel.TextColor3 = theme.textMuted
    minLabel.TextSize = 8
    minLabel.Font = Enum.Font.Gotham
    minLabel.TextXAlignment = Enum.TextXAlignment.Center
    minLabel.TextYAlignment = Enum.TextYAlignment.Center
    minLabel.Parent = sliderContainer

    local maxLabel = Instance.new("TextLabel")
    maxLabel.Size = UDim2.new(0, 24, 1, 0)
    maxLabel.Position = UDim2.new(1, -24, 0, 0)
    maxLabel.BackgroundTransparency = 1
    maxLabel.Text = "500"
    maxLabel.TextColor3 = theme.textMuted
    maxLabel.TextSize = 8
    maxLabel.Font = Enum.Font.Gotham
    maxLabel.TextXAlignment = Enum.TextXAlignment.Center
    maxLabel.TextYAlignment = Enum.TextYAlignment.Center
    maxLabel.Parent = sliderContainer

    local sliderTrack = Instance.new("Frame")
    sliderTrack.Size = UDim2.new(1, -64, 0, 3)
    sliderTrack.Position = UDim2.new(0, 32, 0.5, -1.5)
    sliderTrack.BackgroundColor3 = theme.surface3
    sliderTrack.BorderSizePixel = 0
    sliderTrack.ClipsDescendants = true
    sliderTrack.Parent = sliderContainer

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(0, 2)
    trackCorner.Parent = sliderTrack

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new(0, 0, 1, 0)
    sliderFill.BackgroundColor3 = theme.accent
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderTrack

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 2)
    fillCorner.Parent = sliderFill

    local sliderButton = Instance.new("TextButton")
    sliderButton.Size = UDim2.new(0, 14, 0, 14)
    sliderButton.Position = UDim2.new(0, 0, 0.5, -7)
    sliderButton.BackgroundColor3 = theme.accent
    sliderButton.BorderSizePixel = 2
    sliderButton.BorderColor3 = theme.background
    sliderButton.Text = ""
    sliderButton.Parent = sliderContainer

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(1, 0)
    buttonCorner.Parent = sliderButton

    local speedToggleContainer = Instance.new("Frame")
    speedToggleContainer.Size = UDim2.new(1, 0, 0, 40)
    speedToggleContainer.Position = UDim2.new(0, 0, 0, 106)
    speedToggleContainer.BackgroundTransparency = 1
    speedToggleContainer.Parent = speedSection

    local speedToggleBtn = Instance.new("TextButton")
    speedToggleBtn.Size = UDim2.new(0, 96, 0, 32)
    speedToggleBtn.Position = UDim2.new(0.5, -48, 0.5, -16)
    speedToggleBtn.BackgroundColor3 = theme.danger
    speedToggleBtn.BackgroundTransparency = 0.15
    speedToggleBtn.Text = "OFF"
    speedToggleBtn.TextColor3 = theme.danger
    speedToggleBtn.TextSize = 14
    speedToggleBtn.Font = Enum.Font.GothamBold
    speedToggleBtn.BorderSizePixel = 2
    speedToggleBtn.BorderColor3 = theme.danger
    speedToggleBtn.Parent = speedToggleContainer

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 8)
    toggleCorner.Parent = speedToggleBtn

    -- ===== DIVISOR 1 =====
    local divider1 = Instance.new("Frame")
    divider1.Size = UDim2.new(1, 0, 0, 1)
    divider1.Position = UDim2.new(0, 0, 0, 138)
    divider1.BackgroundColor3 = theme.border
    divider1.BackgroundTransparency = 0.5
    divider1.BorderSizePixel = 0
    divider1.Parent = content

    -- ============================================
    -- SEÇÃO PULO (TEXTO EM 10px)
    -- ============================================
    local jumpSection = Instance.new("Frame")
    jumpSection.Size = UDim2.new(1, 0, 0, 95)
    jumpSection.Position = UDim2.new(0, 0, 0, 143)
    jumpSection.BackgroundTransparency = 1
    jumpSection.Parent = content

    local jumpTitleContainer = Instance.new("Frame")
    jumpTitleContainer.Size = UDim2.new(1, 0, 0, 18)
    jumpTitleContainer.BackgroundTransparency = 1
    jumpTitleContainer.Parent = jumpSection

    local jumpTitleIcon = Instance.new("TextLabel")
    jumpTitleIcon.Size = UDim2.new(0, 14, 1, 0)
    jumpTitleIcon.BackgroundTransparency = 1
    jumpTitleIcon.Text = "🚀"
    jumpTitleIcon.TextColor3 = theme.jumpColor
    jumpTitleIcon.TextSize = 11
    jumpTitleIcon.Font = Enum.Font.GothamBold
    jumpTitleIcon.TextXAlignment = Enum.TextXAlignment.Center
    jumpTitleIcon.TextYAlignment = Enum.TextYAlignment.Center
    jumpTitleIcon.Parent = jumpTitleContainer

    local jumpTitle = Instance.new("TextLabel")
    jumpTitle.Size = UDim2.new(1, -18, 1, 0)
    jumpTitle.Position = UDim2.new(0, 18, 0, 0)
    jumpTitle.BackgroundTransparency = 1
    jumpTitle.Text = "PULO INFINITO"
    jumpTitle.TextColor3 = theme.textSecondary
    jumpTitle.TextSize = 8
    jumpTitle.Font = Enum.Font.GothamBold
    jumpTitle.TextXAlignment = Enum.TextXAlignment.Left
    jumpTitle.TextYAlignment = Enum.TextYAlignment.Center
    jumpTitle.Parent = jumpTitleContainer

    local jumpToggleContainer = Instance.new("Frame")
    jumpToggleContainer.Size = UDim2.new(1, 0, 0, 36)
    jumpToggleContainer.Position = UDim2.new(0, 0, 0, 20)
    jumpToggleContainer.BackgroundTransparency = 1
    jumpToggleContainer.Parent = jumpSection

    local jumpToggleBtn = Instance.new("TextButton")
    jumpToggleBtn.Size = UDim2.new(0, 96, 0, 32)
    jumpToggleBtn.Position = UDim2.new(0.5, -48, 0.5, -16)
    jumpToggleBtn.BackgroundColor3 = theme.danger
    jumpToggleBtn.BackgroundTransparency = 0.2
    jumpToggleBtn.Text = "OFF"
    jumpToggleBtn.TextColor3 = theme.danger
    jumpToggleBtn.TextSize = 14
    jumpToggleBtn.Font = Enum.Font.GothamBold
    jumpToggleBtn.BorderSizePixel = 2
    jumpToggleBtn.BorderColor3 = theme.danger
    jumpToggleBtn.Parent = jumpToggleContainer

    local jumpBtnCorner = Instance.new("UICorner")
    jumpBtnCorner.CornerRadius = UDim.new(0, 8)
    jumpBtnCorner.Parent = jumpToggleBtn

    -- STATUS DO PULO - TEXTO EM 10px
    local jumpStatusContainer = Instance.new("Frame")
    jumpStatusContainer.Size = UDim2.new(1, 0, 0, 16) -- Aumentado para acomodar texto 10px
    jumpStatusContainer.Position = UDim2.new(0, 0, 0, 60) -- Ajustado
    jumpStatusContainer.BackgroundTransparency = 1
    jumpStatusContainer.Parent = jumpSection

    local jumpStatusLabel = Instance.new("TextLabel")
    jumpStatusLabel.Size = UDim2.new(1, 0, 1, 0)
    jumpStatusLabel.BackgroundTransparency = 1
    jumpStatusLabel.Text = "Espaço para pular"
    jumpStatusLabel.TextColor3 = theme.textMuted
    jumpStatusLabel.TextSize = 10 -- ALTERADO PARA 10px
    jumpStatusLabel.Font = Enum.Font.Gotham
    jumpStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    jumpStatusLabel.TextYAlignment = Enum.TextYAlignment.Center
    jumpStatusLabel.Parent = jumpStatusContainer

    -- ============================================
    -- SEÇÃO NOCLIP (TEXTO EM 10px)
    -- ============================================
    local noclipSection = Instance.new("Frame")
    noclipSection.Size = UDim2.new(1, 0, 0, 85)
    noclipSection.Position = UDim2.new(0, 0, 0, 210)
    noclipSection.BackgroundTransparency = 1
    noclipSection.Parent = content

    local noclipTitleContainer = Instance.new("Frame")
    noclipTitleContainer.Size = UDim2.new(1, 0, 0, 18)
    noclipTitleContainer.BackgroundTransparency = 1
    noclipTitleContainer.Parent = noclipSection

    local noclipTitleIcon = Instance.new("TextLabel")
    noclipTitleIcon.Size = UDim2.new(0, 14, 1, 0)
    noclipTitleIcon.BackgroundTransparency = 1
    noclipTitleIcon.Text = "👻"
    noclipTitleIcon.TextColor3 = theme.noclipColor
    noclipTitleIcon.TextSize = 11
    noclipTitleIcon.Font = Enum.Font.GothamBold
    noclipTitleIcon.TextXAlignment = Enum.TextXAlignment.Center
    noclipTitleIcon.TextYAlignment = Enum.TextYAlignment.Center
    noclipTitleIcon.Parent = noclipTitleContainer

    local noclipTitle = Instance.new("TextLabel")
    noclipTitle.Size = UDim2.new(1, -18, 1, 0)
    noclipTitle.Position = UDim2.new(0, 18, 0, 0)
    noclipTitle.BackgroundTransparency = 1
    noclipTitle.Text = "NOCLIP"
    noclipTitle.TextColor3 = theme.textSecondary
    noclipTitle.TextSize = 8
    noclipTitle.Font = Enum.Font.GothamBold
    noclipTitle.TextXAlignment = Enum.TextXAlignment.Left
    noclipTitle.TextYAlignment = Enum.TextYAlignment.Center
    noclipTitle.Parent = noclipTitleContainer

    local noclipToggleContainer = Instance.new("Frame")
    noclipToggleContainer.Size = UDim2.new(1, 0, 0, 36)
    noclipToggleContainer.Position = UDim2.new(0, 0, 0, 20)
    noclipToggleContainer.BackgroundTransparency = 1
    noclipToggleContainer.Parent = noclipSection

    local noclipToggleBtn = Instance.new("TextButton")
    noclipToggleBtn.Size = UDim2.new(0, 96, 0, 32)
    noclipToggleBtn.Position = UDim2.new(0.5, -48, 0.5, -16)
    noclipToggleBtn.BackgroundColor3 = theme.danger
    noclipToggleBtn.BackgroundTransparency = 0.2
    noclipToggleBtn.Text = "OFF"
    noclipToggleBtn.TextColor3 = theme.danger
    noclipToggleBtn.TextSize = 14
    noclipToggleBtn.Font = Enum.Font.GothamBold
    noclipToggleBtn.BorderSizePixel = 2
    noclipToggleBtn.BorderColor3 = theme.danger
    noclipToggleBtn.Parent = noclipToggleContainer

    local noclipBtnCorner = Instance.new("UICorner")
    noclipBtnCorner.CornerRadius = UDim.new(0, 8)
    noclipBtnCorner.Parent = noclipToggleBtn

    -- STATUS DO NOCLIP - TEXTO EM 10px
    local noclipStatusContainer = Instance.new("Frame")
    noclipStatusContainer.Size = UDim2.new(1, 0, 0, 16) -- Aumentado
    noclipStatusContainer.Position = UDim2.new(0, 0, 0, 60) -- Ajustado
    noclipStatusContainer.BackgroundTransparency = 1
    noclipStatusContainer.Parent = noclipSection

    local noclipStatusLabel = Instance.new("TextLabel")
    noclipStatusLabel.Size = UDim2.new(1, 0, 1, 0)
    noclipStatusLabel.BackgroundTransparency = 1
    noclipStatusLabel.Text = "Atravesse paredes"
    noclipStatusLabel.TextColor3 = theme.textMuted
    noclipStatusLabel.TextSize = 10 -- ALTERADO PARA 10px
    noclipStatusLabel.Font = Enum.Font.Gotham
    noclipStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    noclipStatusLabel.TextYAlignment = Enum.TextYAlignment.Center
    noclipStatusLabel.Parent = noclipStatusContainer

    -- ============================================
    -- SEÇÃO VOO (FLY) - TEXTO EM 10px
    -- ============================================
    local flySection = Instance.new("Frame")
    flySection.Size = UDim2.new(1, 0, 0, 120)
    flySection.Position = UDim2.new(0, 0, 0, 280)
    flySection.BackgroundTransparency = 1
    flySection.Parent = content

    local flyTitleContainer = Instance.new("Frame")
    flyTitleContainer.Size = UDim2.new(1, 0, 0, 18)
    flyTitleContainer.BackgroundTransparency = 1
    flyTitleContainer.Parent = flySection

    local flyTitleIcon = Instance.new("TextLabel")
    flyTitleIcon.Size = UDim2.new(0, 14, 1, 0)
    flyTitleIcon.BackgroundTransparency = 1
    flyTitleIcon.Text = "✈️"
    flyTitleIcon.TextColor3 = theme.flyColor
    flyTitleIcon.TextSize = 11
    flyTitleIcon.Font = Enum.Font.GothamBold
    flyTitleIcon.TextXAlignment = Enum.TextXAlignment.Center
    flyTitleIcon.TextYAlignment = Enum.TextYAlignment.Center
    flyTitleIcon.Parent = flyTitleContainer

    local flyTitle = Instance.new("TextLabel")
    flyTitle.Size = UDim2.new(1, -18, 1, 0)
    flyTitle.Position = UDim2.new(0, 18, 0, 0)
    flyTitle.BackgroundTransparency = 1
    flyTitle.Text = "FLY"
    flyTitle.TextColor3 = theme.textSecondary
    flyTitle.TextSize = 8
    flyTitle.Font = Enum.Font.GothamBold
    flyTitle.TextXAlignment = Enum.TextXAlignment.Left
    flyTitle.TextYAlignment = Enum.TextYAlignment.Center
    flyTitle.Parent = flyTitleContainer

    local flySpeedDisplay = Instance.new("Frame")
    flySpeedDisplay.Size = UDim2.new(0, 80, 0, 30)
    flySpeedDisplay.Position = UDim2.new(0.5, -40, 0, 22)
    flySpeedDisplay.BackgroundColor3 = theme.surface2
    flySpeedDisplay.BackgroundTransparency = 0.3
    flySpeedDisplay.BorderSizePixel = 1
    flySpeedDisplay.BorderColor3 = theme.border
    flySpeedDisplay.Parent = flySection

    local flyDisplayCorner = Instance.new("UICorner")
    flyDisplayCorner.CornerRadius = UDim.new(0, 8)
    flyDisplayCorner.Parent = flySpeedDisplay

    local flySpeedValue = Instance.new("TextLabel")
    flySpeedValue.Size = UDim2.new(1, 0, 0.6, 0)
    flySpeedValue.Position = UDim2.new(0, 0, 0.1, 0)
    flySpeedValue.BackgroundTransparency = 1
    flySpeedValue.Text = tostring(flyModule.speed)
    flySpeedValue.TextColor3 = theme.flyColor
    flySpeedValue.TextSize = 20
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
    flySliderContainer.Position = UDim2.new(0, 8, 0, 56)
    flySliderContainer.BackgroundTransparency = 1
    flySliderContainer.ClipsDescendants = true
    flySliderContainer.Parent = flySection

    local flyMinLabel = Instance.new("TextLabel")
    flyMinLabel.Size = UDim2.new(0, 18, 1, 0)
    flyMinLabel.BackgroundTransparency = 1
    flyMinLabel.Text = "1"
    flyMinLabel.TextColor3 = theme.textMuted
    flyMinLabel.TextSize = 7
    flyMinLabel.Font = Enum.Font.Gotham
    flyMinLabel.TextXAlignment = Enum.TextXAlignment.Center
    flyMinLabel.TextYAlignment = Enum.TextYAlignment.Center
    flyMinLabel.Parent = flySliderContainer

    local flyMaxLabel = Instance.new("TextLabel")
    flyMaxLabel.Size = UDim2.new(0, 18, 1, 0)
    flyMaxLabel.Position = UDim2.new(1, -18, 0, 0)
    flyMaxLabel.BackgroundTransparency = 1
    flyMaxLabel.Text = "10"
    flyMaxLabel.TextColor3 = theme.textMuted
    flyMaxLabel.TextSize = 7
    flyMaxLabel.Font = Enum.Font.Gotham
    flyMaxLabel.TextXAlignment = Enum.TextXAlignment.Center
    flyMaxLabel.TextYAlignment = Enum.TextYAlignment.Center
    flyMaxLabel.Parent = flySliderContainer

    local flySliderTrack = Instance.new("Frame")
    flySliderTrack.Size = UDim2.new(1, -52, 0, 3)
    flySliderTrack.Position = UDim2.new(0, 26, 0.5, -1.5)
    flySliderTrack.BackgroundColor3 = theme.surface3
    flySliderTrack.BorderSizePixel = 0
    flySliderTrack.ClipsDescendants = true
    flySliderTrack.Parent = flySliderContainer

    local flyTrackCorner = Instance.new("UICorner")
    flyTrackCorner.CornerRadius = UDim.new(0, 2)
    flyTrackCorner.Parent = flySliderTrack

    local flySliderFill = Instance.new("Frame")
    flySliderFill.Size = UDim2.new(0, 0, 1, 0)
    flySliderFill.BackgroundColor3 = theme.flyColor
    flySliderFill.BorderSizePixel = 0
    flySliderFill.Parent = flySliderTrack

    local flyFillCorner = Instance.new("UICorner")
    flyFillCorner.CornerRadius = UDim.new(0, 2)
    flyFillCorner.Parent = flySliderFill

    local flySliderButton = Instance.new("TextButton")
    flySliderButton.Size = UDim2.new(0, 12, 0, 12)
    flySliderButton.Position = UDim2.new(0, 0, 0.5, -6)
    flySliderButton.BackgroundColor3 = theme.flyColor
    flySliderButton.BorderSizePixel = 2
    flySliderButton.BorderColor3 = theme.background
    flySliderButton.Text = ""
    flySliderButton.Parent = flySliderContainer

    local flyButtonCorner = Instance.new("UICorner")
    flyButtonCorner.CornerRadius = UDim.new(1, 0)
    flyButtonCorner.Parent = flySliderButton

    local flyToggleContainer = Instance.new("Frame")
    flyToggleContainer.Size = UDim2.new(1, 0, 0, 36)
    flyToggleContainer.Position = UDim2.new(0, 0, 0, 78)
    flyToggleContainer.BackgroundTransparency = 1
    flyToggleContainer.Parent = flySection

    local flyToggleBtn = Instance.new("TextButton")
    flyToggleBtn.Size = UDim2.new(0, 96, 0, 32)
    flyToggleBtn.Position = UDim2.new(0.5, -48, 0.5, -16)
    flyToggleBtn.BackgroundColor3 = theme.danger
    flyToggleBtn.BackgroundTransparency = 0.2
    flyToggleBtn.Text = "OFF"
    flyToggleBtn.TextColor3 = theme.danger
    flyToggleBtn.TextSize = 14
    flyToggleBtn.Font = Enum.Font.GothamBold
    flyToggleBtn.BorderSizePixel = 2
    flyToggleBtn.BorderColor3 = theme.danger
    flyToggleBtn.Parent = flyToggleContainer

    local flyBtnCorner = Instance.new("UICorner")
    flyBtnCorner.CornerRadius = UDim.new(0, 8)
    flyBtnCorner.Parent = flyToggleBtn

    -- STATUS DO FLY - TEXTO EM 10px
    local flyStatusContainer = Instance.new("Frame")
    flyStatusContainer.Size = UDim2.new(1, 0, 0, 16) -- Aumentado
    flyStatusContainer.Position = UDim2.new(0, 0, 0, 116) -- Ajustado
    flyStatusContainer.BackgroundTransparency = 1
    flyStatusContainer.Parent = flySection

    local flyStatusLabel = Instance.new("TextLabel")
    flyStatusLabel.Size = UDim2.new(1, 0, 1, 0)
    flyStatusLabel.BackgroundTransparency = 1
    flyStatusLabel.Text = "Pressione F para voar"
    flyStatusLabel.TextColor3 = theme.textMuted
    flyStatusLabel.TextSize = 10 -- ALTERADO PARA 10px
    flyStatusLabel.Font = Enum.Font.Gotham
    flyStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    flyStatusLabel.TextYAlignment = Enum.TextYAlignment.Center
    flyStatusLabel.Parent = flyStatusContainer

    -- ============================================
    -- LÓGICA DO SLIDER (VELOCIDADE PRINCIPAL)
    -- ============================================

    local isDragging, minValue, maxValue = false, 5, 500
    local currentValue = speedModule.currentSpeed or 16
    local speedIsActive = false

    local function calculateSliderPosition(value)
        return math.clamp((value - minValue) / (maxValue - minValue), 0, 1)
    end

    local function updateSliderUI(value)
        local percent = calculateSliderPosition(value)
        local containerWidth = sliderContainer.AbsoluteSize.X
        local trackWidth = containerWidth - 64
        local buttonPos = percent * trackWidth
        sliderButton.Position = UDim2.new(0, 32 + buttonPos - 7, 0.5, -7)
        sliderFill.Size = UDim2.new(math.clamp(percent, 0, 1), 0, 1, 0)
    end

    local function updateUI(speed)
        speed = speed or currentValue
        currentValue = speed
        speedValue.Text = tostring(math.floor(speed))
        updateSliderUI(speed)
    end

    local function updateSpeed(value)
        value = math.clamp(value, minValue, maxValue)
        currentValue = value
        speedModule:setSpeed(value)
        updateUI(value)
    end

    local function getSpeedFromMousePosition(input)
        local containerPos = sliderContainer.AbsolutePosition.X
        local containerSize = sliderContainer.AbsoluteSize.X
        local trackStart = containerPos + 32
        local trackEnd = containerPos + containerSize - 32
        local mouseX = input.Position.X
        local percent = math.clamp((mouseX - trackStart) / (trackEnd - trackStart), 0, 1)
        return minValue + (maxValue - minValue) * percent
    end

    sliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            updateSpeed(getSpeedFromMousePosition(input))
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateSpeed(getSpeedFromMousePosition(input))
        end
    end)

    sliderButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then 
            isDragging = false 
        end
    end)

    sliderTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local trackPos = sliderTrack.AbsolutePosition.X
            local trackSize = sliderTrack.AbsoluteSize.X
            local mouseX = input.Position.X
            local percent = math.clamp((mouseX - trackPos) / trackSize, 0, 1)
            local newValue = minValue + (maxValue - minValue) * percent
            updateSpeed(newValue)
        end
    end)

    -- ============================================
    -- LÓGICA DO SLIDER DE VELOCIDADE DE VOO
    -- ============================================

    local flyMinVal, flyMaxVal = 1, 10
    local isFlyDragging = false

    local function calculateFlySliderPosition(value)
        return math.clamp((value - flyMinVal) / (flyMaxVal - flyMinVal), 0, 1)
    end

    local function updateFlySliderUI(value)
        local percent = calculateFlySliderPosition(value)
        local containerWidth = flySliderContainer.AbsoluteSize.X
        local trackWidth = containerWidth - 52
        local buttonPos = percent * trackWidth
        flySliderButton.Position = UDim2.new(0, 26 + buttonPos - 6, 0.5, -6)
        flySliderFill.Size = UDim2.new(math.clamp(percent, 0, 1), 0, 1, 0)
        flySpeedValue.Text = tostring(math.floor(value))
    end

    local function updateFlySpeed(value)
        value = math.clamp(value, flyMinVal, flyMaxVal)
        flyModule:setSpeed(value)
        updateFlySliderUI(value)
    end

    local function getFlySpeedFromMousePosition(input)
        local containerPos = flySliderContainer.AbsolutePosition.X
        local containerSize = flySliderContainer.AbsoluteSize.X
        local trackStart = containerPos + 26
        local trackEnd = containerPos + containerSize - 26
        local mouseX = input.Position.X
        local percent = math.clamp((mouseX - trackStart) / (trackEnd - trackStart), 0, 1)
        return flyMinVal + (flyMaxVal - flyMinVal) * percent
    end

    flySliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isFlyDragging = true
            updateFlySpeed(getFlySpeedFromMousePosition(input))
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if isFlyDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateFlySpeed(getFlySpeedFromMousePosition(input))
        end
    end)

    flySliderButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then 
            isFlyDragging = false 
        end
    end)

    flySliderTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local trackPos = flySliderTrack.AbsolutePosition.X
            local trackSize = flySliderTrack.AbsoluteSize.X
            local mouseX = input.Position.X
            local percent = math.clamp((mouseX - trackPos) / trackSize, 0, 1)
            local newValue = flyMinVal + (flyMaxVal - flyMinVal) * percent
            updateFlySpeed(newValue)
        end
    end)

    -- ============================================
    -- LÓGICA DOS TOGGLES (COM ATUALIZAÇÃO DOS TEXTOS)
    -- ============================================

    speedToggleBtn.MouseButton1Click:Connect(function()
        speedIsActive = not speedIsActive
        if speedIsActive then
            speedModule:enable()
            speedToggleBtn.BackgroundColor3 = theme.success
            speedToggleBtn.BackgroundTransparency = 0.15
            speedToggleBtn.Text = "ON"
            speedToggleBtn.TextColor3 = theme.success
            speedToggleBtn.BorderColor3 = theme.success
            speedValue.TextColor3 = theme.success
        else
            speedModule:disable()
            speedToggleBtn.BackgroundColor3 = theme.danger
            speedToggleBtn.BackgroundTransparency = 0.15
            speedToggleBtn.Text = "OFF"
            speedToggleBtn.TextColor3 = theme.danger
            speedToggleBtn.BorderColor3 = theme.danger
            speedValue.TextColor3 = theme.accent
        end
    end)

    local jumpIsActive = false

    jumpToggleBtn.MouseButton1Click:Connect(function()
        jumpIsActive = not jumpIsActive

        if jumpIsActive then
            jumpModule:enable()
            jumpToggleBtn.BackgroundColor3 = theme.success
            jumpToggleBtn.BackgroundTransparency = 0.15
            jumpToggleBtn.Text = "ON"
            jumpToggleBtn.TextColor3 = theme.success
            jumpToggleBtn.BorderColor3 = theme.success
            jumpStatusLabel.Text = "✅ Pulo ativado"
            jumpStatusLabel.TextColor3 = theme.success
            jumpStatusLabel.TextSize = 10 -- Mantém 10px
        else
            jumpModule:disable()
            jumpToggleBtn.BackgroundColor3 = theme.danger
            jumpToggleBtn.BackgroundTransparency = 0.2
            jumpToggleBtn.Text = "OFF"
            jumpToggleBtn.TextColor3 = theme.danger
            jumpToggleBtn.BorderColor3 = theme.danger
            jumpStatusLabel.Text = "Espaço para pular"
            jumpStatusLabel.TextColor3 = theme.textMuted
            jumpStatusLabel.TextSize = 10 -- Mantém 10px
        end
    end)

    local noclipIsActive = false

    noclipToggleBtn.MouseButton1Click:Connect(function()
        noclipIsActive = not noclipIsActive

        if noclipIsActive then
            noclipModule:enable()
            noclipToggleBtn.BackgroundColor3 = theme.success
            noclipToggleBtn.BackgroundTransparency = 0.15
            noclipToggleBtn.Text = "ON"
            noclipToggleBtn.TextColor3 = theme.success
            noclipToggleBtn.BorderColor3 = theme.success
            noclipStatusLabel.Text = "👻 Noclip ativado"
            noclipStatusLabel.TextColor3 = theme.success
            noclipStatusLabel.TextSize = 10 -- Mantém 10px
        else
            noclipModule:disable()
            noclipToggleBtn.BackgroundColor3 = theme.danger
            noclipToggleBtn.BackgroundTransparency = 0.2
            noclipToggleBtn.Text = "OFF"
            noclipToggleBtn.TextColor3 = theme.danger
            noclipToggleBtn.BorderColor3 = theme.danger
            noclipStatusLabel.Text = "Atravesse paredes"
            noclipStatusLabel.TextColor3 = theme.textMuted
            noclipStatusLabel.TextSize = 10 -- Mantém 10px
        end
    end)

    local flyIsActive = false

    flyToggleBtn.MouseButton1Click:Connect(function()
        flyIsActive = not flyIsActive

        if flyIsActive then
            flyModule:enable()
            flyToggleBtn.BackgroundColor3 = theme.success
            flyToggleBtn.BackgroundTransparency = 0.15
            flyToggleBtn.Text = "ON"
            flyToggleBtn.TextColor3 = theme.success
            flyToggleBtn.BorderColor3 = theme.success
            flyStatusLabel.Text = "✈️ Fly ativado (F para voar)"
            flyStatusLabel.TextColor3 = theme.success
            flyStatusLabel.TextSize = 10 -- Mantém 10px
        else
            flyModule:disable()
            flyToggleBtn.BackgroundColor3 = theme.danger
            flyToggleBtn.BackgroundTransparency = 0.2
            flyToggleBtn.Text = "OFF"
            flyToggleBtn.TextColor3 = theme.danger
            flyToggleBtn.BorderColor3 = theme.danger
            flyStatusLabel.Text = "Pressione F para voar"
            flyStatusLabel.TextColor3 = theme.textMuted
            flyStatusLabel.TextSize = 10 -- Mantém 10px
        end
    end)

    -- ============================================
    -- SISTEMA DE MINIMIZAR
    -- ============================================

    local isMinimized, fullSize = false, UDim2.new(0, 260, 0, 480)
    local minimizedSize = UDim2.new(0, 260, 0, 48)

    local function minimizeWindow()
        if isMinimized then return end
        isMinimized = true
        content.Visible = false
        subtitle.Text = "Minimizado"
        TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = minimizedSize}):Play()
        minBtn.Text = "✚"
        minBtn.TextColor3 = theme.success
    end

    local function maximizeWindow()
        if not isMinimized then return end
        isMinimized = false
        content.Visible = true
        subtitle.Text = "Velocidade • Pulo • Noclip • Fly"
        TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = fullSize}):Play()
        minBtn.Text = "−"
        minBtn.TextColor3 = theme.textSecondary
        task.wait(0.4)
        updateSliderUI(currentValue)
        updateFlySliderUI(flyModule.speed)
    end

    minBtn.MouseButton1Click:Connect(function()
        if isMinimized then maximizeWindow() else minimizeWindow() end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        speedModule:disable()
        jumpModule:disable()
        noclipModule:disable()
        flyModule:disable()
        gui:Destroy()
    end)

    -- ============================================
    -- SISTEMA DE ARRASTAR
    -- ============================================

    local isDraggingWindow, dragStartPos, frameStartPos = false, nil, nil

    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDraggingWindow, dragStartPos, frameStartPos = true, input.Position, mainFrame.Position
        end
    end)

    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then 
            isDraggingWindow = false 
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if isDraggingWindow and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStartPos
            mainFrame.Position = UDim2.new(
                frameStartPos.X.Scale, 
                frameStartPos.X.Offset + delta.X, 
                frameStartPos.Y.Scale, 
                frameStartPos.Y.Offset + delta.Y
            )
        end
    end)

    -- ============================================
    -- ATUALIZAÇÃO CONTÍNUA
    -- ============================================

    RunService.Heartbeat:Connect(function()
        if not isDragging then
            updateSliderUI(currentValue)
        end
        if not isFlyDragging then
            updateFlySliderUI(flyModule.speed)
        end
    end)

    -- ============================================
    -- INICIALIZAÇÃO
    -- ============================================

    updateUI(speedModule.currentSpeed)
    updateFlySliderUI(flyModule.speed)

    print("=" .. string.rep("=", 50))
    print("⚡ Speed Control Pro v2.8 - Textos em 10px")
    print("🎨 Design Premium - Textos de status uniformes")
    print("=" .. string.rep("=", 50))

    return gui
end

-- ============================================
-- INICIALIZAÇÃO DO SISTEMA COMPLETO
-- ============================================

print("=" .. string.rep("=", 50))
print("⚡ Speed Control Pro v2.8 - Textos em 10px")
print("📋 Carregando módulos...")
print("=" .. string.rep("=", 50) .. "\n")

local config = ConfigManager.new()
local speedModule = SpeedModule.new(config)
local jumpModule = InfiniteJumpModule.new(config)
local noclipModule = NoclipModule.new(config)
local flyModule = FlyModule.new(config)

speedModule:initialize()

local gui = createUI(speedModule, jumpModule, noclipModule, flyModule)

while true do 
    task.wait(1) 
end
