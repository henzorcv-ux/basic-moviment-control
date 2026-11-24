-- Basic Settings Control v2 | Painel animado (somente interface)
-- As funções reais ficam nos callbacks "onChange" (por enquanto vazios)

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local RS = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Onde colocar o painel: um container que fica ACIMA de tudo, inclusive do menu do Roblox
local parent = playerGui
do
	local ok, container = pcall(function()
		if gethui then return gethui() end
		return game:GetService("CoreGui")
	end)
	if ok and container then parent = container end
end

for _, p in ipairs({playerGui, parent}) do
	local old = p:FindFirstChild("BasicSettingsControl")
	if old then old:Destroy() end
end

------------------------------------------------------------
-- ANTI-AFK (sempre ativo)
------------------------------------------------------------
if not _G.__BSC_AntiAFK_Installed then
	_G.__BSC_AntiAFK_Installed = true

	local VirtualUser = game:GetService("VirtualUser")
	local PULSE_INTERVAL = 60

	player.Idled:Connect(function()
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end)

	local acc, lastPos = 0, nil
	RS.Heartbeat:Connect(function(dt)
		local ch = player.Character
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local pos = root.Position
		if lastPos and (pos - lastPos).Magnitude > 1 then
			acc = 0
		else
			acc += dt
			if acc >= PULSE_INTERVAL then
				acc = 0
				local hum = ch:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 and not hum.PlatformStand and not hum.Sit then
					hum.Jump = true
				end
			end
		end
		lastPos = pos
	end)
end

------------------------------------------------------------
-- AUTO-REJOIN (sempre ativo)
------------------------------------------------------------
if not _G.__BSC_AutoRejoin_Installed then
	_G.__BSC_AutoRejoin_Installed = true

	local TeleportService = game:GetService("TeleportService")
	local placeId = game.PlaceId
	local jobId = game.JobId

	local function attemptRejoin()
		pcall(function()
			if jobId and jobId ~= "" then
				TeleportService:TeleportToPlaceInstance(placeId, jobId, player)
			else
				TeleportService:Teleport(placeId, player)
			end
		end)
	end

	local function watchPrompt(prompt)
		prompt.ChildAdded:Connect(function(child)
			if child.Name == "ErrorFrame" then
				task.wait(0.5)
				attemptRejoin()
			end
		end)
	end

	task.spawn(function()
		local coreGui
		pcall(function()
			coreGui = gethui and gethui() or game:GetService("CoreGui")
		end)
		if not coreGui then return end

		local promptGui = coreGui:FindFirstChild("RobloxPromptGui")
		if not promptGui then
			promptGui = coreGui:WaitForChild("RobloxPromptGui", 15)
		end
		if not promptGui then return end

		local overlay = promptGui:FindFirstChild("promptOverlay")
		if overlay then
			watchPrompt(overlay)
		else
			promptGui.ChildAdded:Connect(function(child)
				if child.Name == "promptOverlay" then
					watchPrompt(child)
				end
			end)
		end
	end)
end

------------------------------------------------------------
-- Paleta
------------------------------------------------------------
local C = {
	bg1 = Color3.fromRGB(24, 24, 32),
	bg2 = Color3.fromRGB(16, 16, 22),
	header = Color3.fromRGB(30, 30, 40),
	card1 = Color3.fromRGB(40, 40, 54),
	card2 = Color3.fromRGB(32, 32, 44),
	line = Color3.fromRGB(70, 70, 92),
	off = Color3.fromRGB(226, 85, 85),
	on = Color3.fromRGB(70, 210, 125),
	text = Color3.fromRGB(240, 240, 248),
	sub = Color3.fromRGB(135, 135, 155),
	track = Color3.fromRGB(58, 58, 74),
	dotOff = Color3.fromRGB(90, 90, 105),
	blue = Color3.fromRGB(80, 165, 255),
	pink = Color3.fromRGB(240, 85, 120),
	purple = Color3.fromRGB(165, 115, 240),
	violet = Color3.fromRGB(130, 95, 235),
	orange = Color3.fromRGB(245, 155, 65),
	cyan = Color3.fromRGB(45, 205, 225),
}

local W = 250
local cardW = 222

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end

local function corner(r) return new("UICorner", {CornerRadius = UDim.new(0, r or 8)}) end
local function stroke(col, t, tr) return new("UIStroke", {Color = col, Thickness = t or 1, Transparency = tr or 0}) end

local function tw(o, t, props, style, dir)
	local tween = TS:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

local function softPop(sc, amount)
	local tok = (sc:GetAttribute("tok") or 0) + 1
	sc:SetAttribute("tok", tok)
	local up = tw(sc, 0.12, {Scale = amount or 1.1}, Enum.EasingStyle.Sine)
	up.Completed:Connect(function()
		if sc:GetAttribute("tok") == tok then
			tw(sc, 0.5, {Scale = 1}, Enum.EasingStyle.Sine)
		end
	end)
end

local function label(p, text, size, pos, sz, color, bold, align)
	return new("TextLabel", {
		Parent = p, BackgroundTransparency = 1, Text = text, TextSize = size,
		Position = pos, Size = sz, TextColor3 = color or C.text,
		Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		TextXAlignment = align or Enum.TextXAlignment.Center,
	})
end

local rainbows, bars, pulseStrokes, activeDots = {}, {}, {}, {}

local function addRainbow(grad, phase)
	table.insert(rainbows, {grad = grad, phase = phase or 0})
end

------------------------------------------------------------
-- Janela principal
------------------------------------------------------------
local gui = new("ScreenGui", {
	Name = "BasicSettingsControl", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 2147483647, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
do
	local ok = pcall(function() gui.Parent = parent end)
	if not ok or not gui.Parent then gui.Parent = playerGui end
end

local viewH = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 800
local H = 800

local RADIUS = 28

local main = new("Frame", {
	Parent = gui, Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.fromOffset(40, 40),
	BackgroundColor3 = C.bg1, BackgroundTransparency = 1, BorderSizePixel = 0,
}, {
	corner(RADIUS),
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(C.bg1, C.bg2)}),
})
local mainScale = new("UIScale", {Parent = main, Scale = 0.7})

local mainStroke = stroke(Color3.new(1, 1, 1), 2, 1)
mainStroke.Parent = main
local mainStrokeGrad = new("UIGradient", {Parent = mainStroke})
addRainbow(mainStrokeGrad, 0)

local content = new("CanvasGroup", {
	Parent = main, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	BorderSizePixel = 0, GroupTransparency = 1,
}, {corner(RADIUS)})

------------------------------------------------------------
-- Header
------------------------------------------------------------
local header = new("Frame", {
	Parent = content, Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = C.header, BorderSizePixel = 0, ZIndex = 3,
}, {
	corner(RADIUS),
	new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(42, 42, 56), C.header)}),
})
local headerFill = new("Frame", {
	Parent = header, Position = UDim2.new(0, 0, 1, -RADIUS), Size = UDim2.new(1, 0, 0, RADIUS),
	BackgroundColor3 = C.header, BorderSizePixel = 0, ZIndex = 1,
})

local gearBox = new("Frame", {
	Parent = header, Position = UDim2.fromOffset(10, 13), Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = C.card1, ZIndex = 4,
}, {corner(9), stroke(C.line, 1, 0.3)})
local gear = new("TextLabel", {
	Parent = gearBox, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "⚙",
	TextSize = 18, TextColor3 = C.blue, Font = Enum.Font.GothamBold, ZIndex = 5,
})

label(header, "Basic Settings Control", 13, UDim2.fromOffset(48, 9), UDim2.fromOffset(140, 18), C.text, true, Enum.TextXAlignment.Left).ZIndex = 4
label(header, "Velocidade · Pulo · ESP · Noclip · Auto · Fly", 8, UDim2.fromOffset(48, 29), UDim2.fromOffset(150, 12), C.sub, false, Enum.TextXAlignment.Left).ZIndex = 4

local minBtn = new("TextButton", {
	Parent = header, Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -54, 0, 8),
	BackgroundColor3 = C.card1, BackgroundTransparency = 1, Text = "–", TextColor3 = C.text,
	TextSize = 16, Font = Enum.Font.GothamBold, AutoButtonColor = false, ZIndex = 4,
}, {corner(6)})
local closeBtn = new("TextButton", {
	Parent = header, Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -28, 0, 8),
	BackgroundColor3 = C.off, BackgroundTransparency = 1, Text = "X", TextColor3 = C.text,
	TextSize = 13, Font = Enum.Font.GothamBold, AutoButtonColor = false, ZIndex = 4,
}, {corner(6)})

local function hoverBtn(b, col)
	b.MouseEnter:Connect(function() tw(b, 0.15, {BackgroundTransparency = 0.2, BackgroundColor3 = col}) end)
	b.MouseLeave:Connect(function() tw(b, 0.2, {BackgroundTransparency = 1}) end)
end
hoverBtn(minBtn, C.card1)
hoverBtn(closeBtn, C.off)

local hLine = new("Frame", {
	Parent = header, Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2),
	BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4,
})
addRainbow(new("UIGradient", {Parent = hLine}), 0.3)

do
	local dragging, dragStart, startPos
	header.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, i.Position, main.Position
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

------------------------------------------------------------
-- Área rolável (Páginas 1, 2 e 3)
------------------------------------------------------------
local pageHost = new("ScrollingFrame", {
	Parent = content, Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58),
	BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
	ScrollingEnabled = false, ScrollBarThickness = 0, CanvasSize = UDim2.new(),
	ElasticBehavior = Enum.ElasticBehavior.Never,
})

local scroll = new("ScrollingFrame", {
	Parent = pageHost, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(W, 700),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
	ScrollBarImageColor3 = C.line, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
})

local cursor = 10
local cardList = {}

-- Página 2
local scroll2 = new("ScrollingFrame", {
	Parent = pageHost, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(W, 700),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
	ScrollingEnabled = false, ScrollBarImageColor3 = C.line, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
	Visible = false,
})
local page2 = {scroll = scroll2, cursor = 10, list = {}}

-- Página 3
local scroll3 = new("ScrollingFrame", {
	Parent = pageHost, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(W, 700),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
	ScrollBarImageColor3 = C.line, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
	Visible = false,
})
local page3 = {scroll = scroll3, cursor = 10, list = {}}

local pages = {scroll, scroll2, scroll3}
local pageLists = {cardList, page2.list, page3.list}

local VEIL_COLOR = Color3.fromRGB(2, 2, 3)

local function card(h, accent, title, icon, pg)
	local sc, cur, list = scroll, cursor, cardList
	if pg then sc, cur, list = pg.scroll, pg.cursor, pg.list end
	local cg = new("Frame", {
		Parent = sc, Position = UDim2.fromOffset(14, cur + 14), Size = UDim2.fromOffset(cardW, h),
		BackgroundColor3 = C.card1, BorderSizePixel = 0,
	}, {
		corner(12),
		new("UIGradient", {Rotation = 90, Color = ColorSequence.new(C.card1, C.card2)}),
	})
	local veil = new("Frame", {
		Parent = cg, Size = UDim2.fromScale(1, 1), BackgroundColor3 = VEIL_COLOR,
		BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 100,
	}, {corner(12)})
	local st = stroke(C.line, 1, 0.5)
	st.Parent = cg
	cg.MouseEnter:Connect(function() tw(st, 0.2, {Color = accent, Transparency = 0.15}) end)
	cg.MouseLeave:Connect(function() tw(st, 0.3, {Color = C.line, Transparency = 0.5}) end)

	local bar = new("Frame", {
		Parent = cg, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(3, 24),
		BackgroundColor3 = accent, BorderSizePixel = 0,
	}, {corner(2)})
	table.insert(bars, bar)

	new("TextLabel", {
		Parent = cg, Position = UDim2.fromOffset(17, 7), Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = C.bg2, Text = icon, TextSize = 13, TextColor3 = accent, Font = Enum.Font.GothamBold,
	}, {corner(8)})
	label(cg, title, #title > 14 and 11 or 12, UDim2.fromOffset(50, 7), UDim2.fromOffset(150, 26), C.text, true, Enum.TextXAlignment.Left)

	local dot = new("Frame", {
		Parent = cg, Position = UDim2.fromOffset(cardW - 20, 16), Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = C.dotOff, BorderSizePixel = 0,
	}, {corner(4)})

	local final = UDim2.fromOffset(14, cur)
	table.insert(list, {cg = cg, final = final, stroke = st, veil = veil})
	if pg then pg.cursor = cur + h + 10 else cursor = cur + h + 10 end
	return {frame = cg, dot = dot, accent = accent}
end

local function toggle(c, x, y, w, h, cb)
	local state, hover = false, false
	local b = new("TextButton", {
		Parent = c.frame, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = C.off, Text = "OFF", TextColor3 = Color3.new(1, 1, 1), TextSize = 13,
		Font = Enum.Font.GothamBold, AutoButtonColor = false,
	}, {
		corner(9),
		new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205))}),
	})
	local sc = new("UIScale", {Parent = b})
	local st = stroke(C.off, 1.5, 0.6)
	st.Parent = b

	local function paint()
		local base = state and C.on or C.off
		tw(b, 0.2, {BackgroundColor3 = hover and base:Lerp(Color3.new(1, 1, 1), 0.14) or base})
		tw(st, 0.2, {Color = base, Transparency = state and 0.15 or 0.6})
		tw(c.dot, 0.2, {BackgroundColor3 = state and C.on or C.dotOff})
		if state then
			activeDots[c.dot] = true
		else
			activeDots[c.dot] = nil
			c.dot.BackgroundTransparency = 0
		end
	end

	b.MouseEnter:Connect(function() hover = true; paint() end)
	b.MouseLeave:Connect(function() hover = false; paint() end)
	b.MouseButton1Click:Connect(function()
		state = not state
		b.Text = state and "ON" or "OFF"
		sc.Scale = 0.92
		tw(sc, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
		paint()
		if cb then cb(state) end
	end)
	return b
end

local function valueBox(c, x, y, w, h, text, color, size)
	local box = new("Frame", {
		Parent = c.frame, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = C.bg2,
	}, {corner(9)})
	local st = stroke(color, 1.5, 0.3)
	st.Parent = box
	table.insert(pulseStrokes, st)
	local lbl = label(box, text, size or 20, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), color, true)
	local sc = new("UIScale", {Parent = lbl})
	return function(t)
		lbl.Text = t
		softPop(sc, 1.1)
	end
end

local function textInput(c, x, y, w, h, defaultText, placeholder, align)
	local tb = new("TextBox", {
		Parent = c.frame, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = C.bg2, Text = defaultText, PlaceholderText = placeholder,
		PlaceholderColor3 = C.sub, TextColor3 = C.pink, TextSize = 11,
		Font = Enum.Font.GothamBold, TextXAlignment = align or Enum.TextXAlignment.Center,
		ClearTextOnFocus = false, BorderSizePixel = 0,
	}, {
		corner(8),
		new("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4)}),
	})
	local st = stroke(C.line, 1, 0.4)
	st.Parent = tb
	tb.Focused:Connect(function() tw(st, 0.2, {Color = C.pink, Transparency = 0.1}) end)
	tb.FocusLost:Connect(function() tw(st, 0.2, {Color = C.line, Transparency = 0.4}) end)
	return tb
end

local function slider(c, y, minV, maxV, startV, cb)
	local f = c.frame
	label(f, tostring(minV), 8, UDim2.fromOffset(8, y - 5), UDim2.fromOffset(26, 12), C.sub, false, Enum.TextXAlignment.Left)
	label(f, tostring(maxV), 8, UDim2.fromOffset(cardW - 34, y - 5), UDim2.fromOffset(26, 12), C.sub, false, Enum.TextXAlignment.Right)

	local track = new("Frame", {
		Parent = f, Position = UDim2.fromOffset(38, y), Size = UDim2.fromOffset(cardW - 76, 4),
		BackgroundColor3 = C.track, BorderSizePixel = 0,
	}, {corner(2)})
	local fill = new("Frame", {
		Parent = track, Size = UDim2.fromScale(0, 1), BackgroundColor3 = c.accent, BorderSizePixel = 0,
	}, {corner(2), new("UIGradient", {Color = ColorSequence.new(c.accent:Lerp(Color3.new(1, 1, 1), 0.35), c.accent)})})
	local knob = new("Frame", {
		Parent = track, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12),
		Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2,
	}, {corner(8), stroke(c.accent, 2, 0)})
	local hit = new("TextButton", {
		Parent = f, Position = UDim2.fromOffset(32, y - 10), Size = UDim2.fromOffset(cardW - 64, 24),
		BackgroundTransparency = 1, Text = "",
	})

	local current
	local function setValue(v)
		v = math.clamp(math.floor(v + 0.5), minV, maxV)
		local a = (v - minV) / (maxV - minV)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		if v ~= current then
			current = v
			if cb then cb(v) end
		end
	end
	setValue(startV)

	local dragging = false
	local function update(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		setValue(minV + a * (maxV - minV))
	end
	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			tw(knob, 0.15, {Size = UDim2.fromOffset(17, 17)}, Enum.EasingStyle.Back)
			update(i.Position.X)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			tw(knob, 0.2, {Size = UDim2.fromOffset(12, 12)}, Enum.EasingStyle.Back)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			update(i.Position.X)
		end
	end)

	return setValue
end

local function hint(c, text, y)
	return label(c.frame, text, 9, UDim2.fromOffset(0, y), UDim2.fromOffset(cardW, 14), C.sub)
end

------------------------------------------------------------
-- Paginação (1/3, 2/3, 3/3)
------------------------------------------------------------
local PAGE_COUNT = 3
local Pager = {current = 1, busy = false, widgets = {}}

local SLIDE = 12
local Anim = {untilT = 0}

local function playEntrance(list, dirX, startDelay)
	startDelay = startDelay or 0.05
	local total = 0
	for i, item in ipairs(list) do
		item.veil.BackgroundTransparency = 0
		item.stroke.Transparency = 1
		if dirX then
			item.cg.Position = UDim2.fromOffset(item.final.X.Offset + dirX * SLIDE, item.final.Y.Offset)
		else
			item.cg.Position = UDim2.fromOffset(item.final.X.Offset, item.final.Y.Offset + 14)
		end

		local d = startDelay + i * 0.04
		total = math.max(total, d + 0.35)
		task.delay(d, function()
			if item.cg.Parent then
				tw(item.cg, 0.35, {Position = item.final}, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
				tw(item.veil, 0.35, {BackgroundTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
				tw(item.stroke, 0.35, {Transparency = 0.5}, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			end
		end)
	end
	Anim.untilT = math.max(Anim.untilT, os.clock() + total + 0.15)
	return total
end

local function navColor(delta)
	local ok = (delta < 0 and Pager.current > 1) or (delta > 0 and Pager.current < PAGE_COUNT)
	return ok and C.text or C.line
end

local function refreshNav()
	for _, w in ipairs(Pager.widgets) do
		w.label.Text = Pager.current .. "/" .. PAGE_COUNT
		softPop(w.scale, 1.15)
		tw(w.prev, 0.2, {TextColor3 = navColor(-1)})
		tw(w.next, 0.2, {TextColor3 = navColor(1)})
	end
end

function Pager.go(n)
	n = math.clamp(n, 1, PAGE_COUNT)
	if n == Pager.current or Pager.busy then return end
	Pager.busy = true

	local oldIdx = Pager.current
	local old, new = pages[oldIdx], pages[n]
	local dir = n > oldIdx and 1 or -1
	Pager.current = n
	refreshNav()

	local outList = pageLists[oldIdx]
	local outTotal = 0
	for i, item in ipairs(outList) do
		local d = (i - 1) * 0.025
		outTotal = math.max(outTotal, d + 0.22)
		task.delay(d, function()
			if item.cg.Parent then
				tw(item.cg, 0.22, {
					Position = UDim2.fromOffset(item.final.X.Offset - dir * SLIDE, item.final.Y.Offset),
				}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				tw(item.veil, 0.22, {BackgroundTransparency = 0}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				tw(item.stroke, 0.22, {Transparency = 1}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			end
		end)
	end

	Anim.untilT = os.clock() + outTotal + 0.6

	task.delay(outTotal + 0.02, function()
		old.Visible = false
		new.Visible = true
		local total = playEntrance(pageLists[n], dir, 0)
		task.delay(total, function() Pager.busy = false end)
	end)
end

local function navWidget(c)
	local pill = new("Frame", {
		Parent = c.frame, Position = UDim2.fromOffset(136, 8), Size = UDim2.fromOffset(62, 24),
		BackgroundColor3 = C.bg2,
	}, {corner(8), stroke(C.line, 1, 0.4)})

	local lbl = label(pill, Pager.current .. "/" .. PAGE_COUNT, 10, UDim2.fromOffset(16, 0), UDim2.fromOffset(30, 24), C.text, true)
	local sc = new("UIScale", {Parent = lbl})

	local function arrow(txt, x, delta)
		local b = new("TextButton", {
			Parent = pill, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(16, 24),
			BackgroundTransparency = 1, Text = txt, TextColor3 = navColor(delta), TextSize = 15,
			Font = Enum.Font.GothamBold, AutoButtonColor = false,
		})
		b.MouseEnter:Connect(function()
			if navColor(delta) == C.text then tw(b, 0.15, {TextColor3 = c.accent}) end
		end)
		b.MouseLeave:Connect(function() tw(b, 0.2, {TextColor3 = navColor(delta)}) end)
		b.MouseButton1Click:Connect(function() Pager.go(Pager.current + delta) end)
		return b
	end

	table.insert(Pager.widgets, {label = lbl, scale = sc, prev = arrow("‹", 2, -1), next = arrow("›", 44, 1)})
end

------------------------------------------------------------
-- LÓGICA: VELOCIDADE
------------------------------------------------------------
local AntiHit = {enabled = false}
local Force = {enabled = false}
local Speed = {enabled = false, value = 25, original = 16, flying = false}
do
	local function getHumanoid()
		local ch = player.Character
		return ch and ch:FindFirstChildOfClass("Humanoid")
	end

	function Speed.apply()
		local h = getHumanoid()
		if h then h.WalkSpeed = Speed.value end
	end

	function Speed.enforce()
		if not Speed.enabled then return end
		local h = getHumanoid()
		if h and h.WalkSpeed ~= Speed.value then h.WalkSpeed = Speed.value end
	end

	function Speed.restore()
		local h = getHumanoid()
		if h then h.WalkSpeed = Speed.original end
	end

	function Speed.setEnabled(on)
		if on then
			local h = getHumanoid()
			if h then Speed.original = h.WalkSpeed end
			Speed.enabled = true
			Speed.apply()
		else
			Speed.enabled = false
			Speed.restore()
		end
		AntiHit.setEnabled(on)
		Force.setEnabled(on)
	end

	function Speed.setValue(v)
		Speed.value = v
		if Speed.enabled then Speed.apply() end
	end

	function Speed.shutdown()
		AntiHit.setEnabled(false)
		Force.setEnabled(false)
		if Speed.charConn then Speed.charConn:Disconnect() end
		if Speed.enabled then
			Speed.enabled = false
			Speed.restore()
		end
	end

	Speed.charConn = player.CharacterAdded:Connect(function(ch)
		local h = ch:WaitForChild("Humanoid", 10)
		if h then
			Speed.original = h.WalkSpeed
			if Speed.enabled then h.WalkSpeed = Speed.value end
		end
	end)
end

------------------------------------------------------------
-- LÓGICA: ANTI-RAGDOLL + ANTI-STUN + FORÇA
------------------------------------------------------------
do
	local function getParts()
		local ch = player.Character
		if not ch then return end
		return ch, ch:FindFirstChildOfClass("Humanoid"), ch:FindFirstChild("HumanoidRootPart")
	end

	local BLOCKED_STATES = {
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Physics,
	}
	local joints = setmetatable({}, {__mode = "k"})
	local lastHum
	local origJumpPower, origJumpHeight = 50, 7.2
	local lastScan = 0

	local function snapshot(ch)
		for _, d in ipairs(ch:GetDescendants()) do
			if d:IsA("Motor6D") and d.Part0 and d.Part1 and not joints[d] then
				joints[d] = {d.Part0, d.Part1}
			end
		end
	end

	local function isFlagName(name)
		name = name:lower()
		return name:find("stun", 1, true) ~= nil or name:find("ragdoll", 1, true) ~= nil
	end

	function AntiHit.setEnabled(on)
		AntiHit.enabled = on
		lastHum = nil
		if not on then
			local _, hum = getParts()
			if hum then
				for _, st in ipairs(BLOCKED_STATES) do hum:SetStateEnabled(st, true) end
			end
		end
	end

	function AntiHit.update()
		if not AntiHit.enabled then return end
		local ch, hum, root = getParts()
		if not hum or not root or hum.Health <= 0 then return end

		if hum ~= lastHum then
			lastHum = hum
			joints = setmetatable({}, {__mode = "k"})
			snapshot(ch)
			if hum.JumpPower > 0 then origJumpPower = hum.JumpPower end
			if hum.JumpHeight > 0 then origJumpHeight = hum.JumpHeight end
		end

		for _, st in ipairs(BLOCKED_STATES) do
			if hum:GetStateEnabled(st) then hum:SetStateEnabled(st, false) end
		end
		local state = hum:GetState()
		if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown
			or state == Enum.HumanoidStateType.Physics then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		if not Speed.flying and hum.PlatformStand then hum.PlatformStand = false end
		for m, info in pairs(joints) do
			if m.Parent then
				if m.Part0 ~= info[1] then m.Part0 = info[1] end
				if m.Part1 ~= info[2] then m.Part1 = info[2] end
			end
		end

		if not hum.AutoRotate then hum.AutoRotate = true end
		if root.Anchored then root.Anchored = false end
		if hum.UseJumpPower then
			if hum.JumpPower <= 0 then hum.JumpPower = origJumpPower end
		elseif hum.JumpHeight <= 0 then
			hum.JumpHeight = origJumpHeight
		end

		local now = os.clock()
		if now - lastScan < 0.25 then return end
		lastScan = now
		for _, d in ipairs(ch:GetDescendants()) do
			if d:IsA("BallSocketConstraint") then
				d:Destroy()
			elseif d:IsA("BoolValue") and d.Value and isFlagName(d.Name) then
				d.Value = false
			end
		end
		for _, holder in ipairs({ch, hum}) do
			for name, v in pairs(holder:GetAttributes()) do
				if v == true and isFlagName(name) then holder:SetAttribute(name, false) end
			end
		end
	end

	local FORCE = 1e15
	local bv

	local function removeBV()
		if bv then bv:Destroy(); bv = nil end
	end

	function Force.setEnabled(on)
		Force.enabled = on
		if not on then removeBV() end
	end

	function Force.update()
		if not Force.enabled or Fling.enabled then return end
		local _, hum, root = getParts()
		if not hum or not root or hum.Health <= 0 or Speed.flying then
			removeBV()
			return
		end

		if not bv or bv.Parent ~= root then
			removeBV()
			bv = Instance.new("BodyVelocity")
			bv.Name = "BSC_Force"
			bv.P = 1e6
			bv.MaxForce = Vector3.zero
			bv.Velocity = Vector3.zero
			bv.Parent = root
		end

		local md = hum.MoveDirection
		if md.Magnitude > 0.01 then
			bv.MaxForce = Vector3.new(FORCE, 0, FORCE)
			bv.Velocity = Vector3.new(md.X, 0, md.Z) * hum.WalkSpeed
		else
			bv.MaxForce = Vector3.zero
		end
	end
end

------------------------------------------------------------
-- LÓGICA: PULO INFINITO
------------------------------------------------------------
local InfJump = {enabled = false, last = 0}
do
	local TAP_COOLDOWN = 0.05

	local function getParts()
		local ch = player.Character
		if not ch then return end
		return ch:FindFirstChildOfClass("Humanoid"), ch:FindFirstChild("HumanoidRootPart")
	end

	local function jumpVelocity(hum)
		if hum.UseJumpPower then
			return hum.JumpPower
		end
		return math.sqrt(2 * workspace.Gravity * hum.JumpHeight)
	end

	local function airJump()
		local hum, root = getParts()
		if not hum or not root or hum.Health <= 0 or hum.Sit then return end
		if hum.FloorMaterial ~= Enum.Material.Air then return end

		InfJump.last = os.clock()
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, jumpVelocity(hum), v.Z)
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end

	function InfJump.setEnabled(on)
		InfJump.enabled = on
	end

	function InfJump.update()
		if not InfJump.enabled or InfJump.suspended then return end
		if UIS:GetFocusedTextBox() then return end

		local hum = getParts()
		if not hum then return end
		local holding = UIS:IsKeyDown(Enum.KeyCode.Space) or hum.Jump
		if holding then airJump() end
	end

	InfJump.conn = UIS.JumpRequest:Connect(function()
		if not InfJump.enabled or InfJump.suspended then return end
		if os.clock() - InfJump.last < TAP_COOLDOWN then return end
		airJump()
	end)

	function InfJump.shutdown()
		InfJump.enabled = false
		if InfJump.conn then InfJump.conn:Disconnect() end
	end
end

------------------------------------------------------------
-- LÓGICA: ESP
------------------------------------------------------------
local ESP = {enabled = false, entries = {}, conns = {}}
do
	local MIN_SIZE = 7
	local MAX_SIZE = 16
	local FAR = 250

	local folder = new("Folder", {Name = "ESP", Parent = gui})

	local function colorFor(plr)
		if plr.Team and not plr.Neutral then
			return plr.TeamColor.Color
		end
		return C.purple
	end

	local function clear(plr)
		local e = ESP.entries[plr]
		if not e then return end
		if e.highlight then e.highlight:Destroy() end
		if e.tag then e.tag:Destroy() end
		ESP.entries[plr] = nil
	end

	local building = {}

	local function buildNow(plr, char)
		local head = char:WaitForChild("Head", 5)
		local root = char:WaitForChild("HumanoidRootPart", 5)

		local waited = 0
		while not char:IsDescendantOf(workspace) and waited < 5 and plr.Character == char do
			task.wait(0.1)
			waited += 0.1
		end
		if not head or not root or not ESP.enabled or plr.Character ~= char
			or not char:IsDescendantOf(workspace) then
			return
		end

		clear(plr)
		local col = colorFor(plr)

		local hl = new("Highlight", {
			Parent = char, Adornee = char, FillColor = col, FillTransparency = 0.5,
			OutlineColor = Color3.new(1, 1, 1), OutlineTransparency = 0,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		})

		local tag = new("BillboardGui", {
			Parent = folder, Adornee = head, AlwaysOnTop = true, LightInfluence = 0,
			Size = UDim2.fromOffset(220, 50), StudsOffset = Vector3.new(0, 2.6, 0), ResetOnSpawn = false,
		})
		local nameLbl = new("TextLabel", {
			Parent = tag, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0.6, 0),
			Text = plr.DisplayName, Font = Enum.Font.GothamBold, TextSize = MAX_SIZE,
			TextColor3 = Color3.new(1, 1, 1), TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0.2, TextYAlignment = Enum.TextYAlignment.Bottom,
		})
		local distLbl = new("TextLabel", {
			Parent = tag, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0.6, 0), Size = UDim2.new(1, 0, 0.4, 0),
			Text = "", Font = Enum.Font.Gotham, TextSize = MAX_SIZE * 0.7,
			TextColor3 = col, TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0.3, TextYAlignment = Enum.TextYAlignment.Top,
		})

		ESP.entries[plr] = {
			highlight = hl, tag = tag, nameLbl = nameLbl, distLbl = distLbl,
			root = root, char = char, size = -1,
		}
	end

	local function build(plr, char)
		if building[plr] == char then return end
		building[plr] = char
		pcall(buildNow, plr, char)
		if building[plr] == char then building[plr] = nil end
	end

	local function track(plr)
		if plr == player or ESP.conns[plr] then return end
		local list = {}
		ESP.conns[plr] = list
		table.insert(list, plr.CharacterAdded:Connect(function(ch) task.spawn(build, plr, ch) end))
		table.insert(list, plr.CharacterRemoving:Connect(function() clear(plr) end))
		if plr.Character then task.spawn(build, plr, plr.Character) end
	end

	local function untrack(plr)
		clear(plr)
		local list = ESP.conns[plr]
		if list then
			for _, cn in ipairs(list) do cn:Disconnect() end
		end
		ESP.conns[plr] = nil
	end

	function ESP.setEnabled(on)
		ESP.enabled = on
		if on then
			for _, p in ipairs(Players:GetPlayers()) do track(p) end
			ESP.addConn = Players.PlayerAdded:Connect(track)
			ESP.remConn = Players.PlayerRemoving:Connect(untrack)
		else
			if ESP.addConn then ESP.addConn:Disconnect(); ESP.addConn = nil end
			if ESP.remConn then ESP.remConn:Disconnect(); ESP.remConn = nil end
			for p in pairs(ESP.conns) do untrack(p) end
		end
	end

	local function reconcile()
		for plr in pairs(ESP.conns) do
			local ch = plr.Character
			if ch then
				local e = ESP.entries[plr]
				if not e or e.char ~= ch or not e.highlight.Parent or not e.tag.Parent or not e.root.Parent then
					task.spawn(build, plr, ch)
				else
					local hl = e.highlight
					if hl.Parent ~= ch then hl.Parent = ch end
					if hl.Adornee ~= ch then hl.Adornee = ch end
					if not hl.Enabled then hl.Enabled = true end
					if hl.FillTransparency ~= 0.5 then hl.FillTransparency = 0.5 end
					if hl.OutlineTransparency ~= 0 then hl.OutlineTransparency = 0 end
					if hl.DepthMode ~= Enum.HighlightDepthMode.AlwaysOnTop then
						hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					end
				end
			end
		end
	end

	ESP.renderConn = RS.RenderStepped:Connect(function()
		if ESP.enabled then pcall(reconcile) end
	end)

	function ESP.update()
		if not ESP.enabled then return end

		reconcile()

		local ch = player.Character
		local myRoot = ch and ch:FindFirstChild("HumanoidRootPart")
		local origin = myRoot and myRoot.Position
			or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position)
		if not origin then return end

		for _, e in pairs(ESP.entries) do
			if e.root.Parent then
				local dist = (e.root.Position - origin).Magnitude
				local t = math.clamp(dist / FAR, 0, 1)
				local s = math.floor(MIN_SIZE + (MAX_SIZE - MIN_SIZE) * (1 - t) + 0.5)
				if s ~= e.size then
					e.size = s
					e.nameLbl.TextSize = s
					e.distLbl.TextSize = math.max(7, math.floor(s * 0.7 + 0.5))
				end
				e.distLbl.Text = math.floor(dist + 0.5) .. "m"
			end
		end
	end

	function ESP.shutdown()
		if ESP.renderConn then ESP.renderConn:Disconnect(); ESP.renderConn = nil end
		if ESP.enabled then ESP.setEnabled(false) end
	end
end

------------------------------------------------------------
-- LÓGICA: NOCLIP
------------------------------------------------------------
local Noclip = {enabled = false, grounded = false, hum = nil, lastGroundY = nil, lastGroundTime = 0}
Noclip.changed = setmetatable({}, {__mode = "k"})
do
	local RISE_SPEED = 30
	local SNAP = 0.3
	local STEP_FRACTION = 0.85
	local BIG_FRACTION = 1.5
	local WIDE_R = 2.5
	local RAISE = 2.5
	local OFFSETS = {
		Vector3.new(0, 0, 0),
		Vector3.new(0.8, 0, 0), Vector3.new(-0.8, 0, 0),
		Vector3.new(0, 0, 0.8), Vector3.new(0, 0, -0.8),
	}

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.RespectCanCollide = true

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.RespectCanCollide = true
	overlap.MaxParts = 1

	local function isInsideSolid(point, char)
		overlap.FilterDescendantsInstances = {char}
		return #workspace:GetPartBoundsInRadius(point, 0.1, overlap) > 0
	end

	local WIDE_DIRS = {
		Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
		Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
	}
	local function isWide(origin, y, reach, char)
		local okX, okZ = false, false
		for i, d in ipairs(WIDE_DIRS) do
			params.FilterDescendantsInstances = {char}
			local res = workspace:Raycast(origin + d * WIDE_R, Vector3.new(0, -reach, 0), params)
			if res and math.abs(res.Position.Y - y) <= 0.4 then
				if i <= 2 then okX = true else okZ = true end
			end
		end
		return okX and okZ
	end

	local function findSurface(origin, reach, char, ref, maxTop, bigTop, rootY)
		local restricted = isInsideSolid(origin, char)
		local ignore = {char}
		local dir = Vector3.new(0, -reach, 0)
		for _ = 1, 8 do
			params.FilterDescendantsInstances = ignore
			local res = workspace:Raycast(origin, dir, params)
			if not res then return nil end

			local y = res.Position.Y
			if y <= ref + SNAP then return y end
			if res.Instance:IsA("Terrain") then return y end
			if not restricted then
				if y <= maxTop then return y end
				if y <= bigTop and y <= rootY + 2.2 and isWide(origin, y, reach, char) then
					return y
				end
			end
			table.insert(ignore, res.Instance)
			restricted = true
		end
		return nil
	end

	local function getParts()
		local ch = player.Character
		if not ch then return end
		return ch:FindFirstChildOfClass("Humanoid"), ch:FindFirstChild("HumanoidRootPart")
	end

	local function standHeight(hum, root, char)
		local legs = 0
		if hum.RigType == Enum.HumanoidRigType.R6 then
			local leg = char:FindFirstChild("Left Leg")
			legs = leg and leg.Size.Y or 2
		end
		return hum.HipHeight + legs + root.Size.Y / 2
	end

	local function jumpVelocity(hum)
		if hum.UseJumpPower then
			return hum.JumpPower
		end
		return math.sqrt(2 * workspace.Gravity * hum.JumpHeight)
	end

	local function setGrounded(g, hum)
		if g == Noclip.grounded then return end
		Noclip.grounded = g
		hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, not g)
		if g then hum:ChangeState(Enum.HumanoidStateType.Running) end
	end

	local function jump(hum, root)
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, jumpVelocity(hum), v.Z)
		hum.Jump = false
		setGrounded(false, hum)
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end

	local function disableCollisions(char)
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then
				Noclip.changed[p] = true
				p.CanCollide = false
			end
		end
	end

	local function step(dt)
		local hum, root = getParts()
		if not hum or not root or hum.Health <= 0 then
			Noclip.grounded = false
			return
		end
		if hum ~= Noclip.hum then
			Noclip.hum = hum
			Noclip.grounded = false
			Noclip.lastGroundY = nil
		end

		local char = hum.Parent
		disableCollisions(char)
		if Noclip.suspendGround then
			setGrounded(false, hum)
			return
		end
		if hum.Sit then return end

		local stand = standHeight(hum, root, char)
		local pos = root.Position
		local vel = root.AssemblyLinearVelocity
		local reach = stand + 1.5 + RAISE + math.max(0, -vel.Y) * dt * 2
		local feetY = pos.Y - stand

		local ref = feetY
		if Noclip.lastGroundY and os.clock() - Noclip.lastGroundTime < 2 then
			ref = math.max(feetY, Noclip.lastGroundY)
		end
		local maxTop = ref + stand * STEP_FRACTION
		local bigTop = ref + stand * BIG_FRACTION

		local best
		for _, off in ipairs(OFFSETS) do
			local y = findSurface(pos + off + Vector3.new(0, RAISE, 0), reach, char, ref, maxTop, bigTop, pos.Y)
			if y and (not best or y > best) then best = y end
		end

		local grounded = false
		if best then
			local desired = best + stand
			local y = pos.Y
			if y < desired - 0.05 then
				local dy = math.min(desired - y, RISE_SPEED * dt)
				root.CFrame = root.CFrame + Vector3.new(0, dy, 0)
				if vel.Y < 0 then
					root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
				end
				grounded = true
			elseif y <= desired + SNAP and vel.Y <= 0.5 then
				root.CFrame = root.CFrame + Vector3.new(0, desired - y, 0)
				root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
				grounded = true
			end
		end
		setGrounded(grounded, hum)
		if grounded and best then
			Noclip.lastGroundY = best
			Noclip.lastGroundTime = os.clock()
		end

		if grounded and not UIS:GetFocusedTextBox()
			and (UIS:IsKeyDown(Enum.KeyCode.Space) or hum.Jump) then
			jump(hum, root)
		end
	end

	function Noclip.setEnabled(on)
		if on == Noclip.enabled then return end
		Noclip.enabled = on

		if on then
			Noclip.stepConn = RS.Stepped:Connect(function(_, dt) step(dt) end)
			Noclip.jumpConn = UIS.JumpRequest:Connect(function()
				if not Noclip.grounded then return end
				local hum, root = getParts()
				if hum and root then jump(hum, root) end
			end)
		else
			if Noclip.stepConn then Noclip.stepConn:Disconnect(); Noclip.stepConn = nil end
			if Noclip.jumpConn then Noclip.jumpConn:Disconnect(); Noclip.jumpConn = nil end

			for p in pairs(Noclip.changed) do
				if p.Parent then p.CanCollide = true end
				Noclip.changed[p] = nil
			end
			local hum = getParts()
			if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true) end
			Noclip.grounded = false
			Noclip.hum = nil
			Noclip.lastGroundY = nil
		end
	end

	function Noclip.shutdown()
		Noclip.setEnabled(false)
	end
end

------------------------------------------------------------
-- LÓGICA: FLING (PUNCH)
------------------------------------------------------------
local Fling = {enabled = false, power = 1000000, x = 0, y = 1, z = 0, punch = false, noclip = false, conn = nil, anim = nil}
do
	local function getRoot(char)
		if not char then return nil end
		return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
	end

	local function disCol(char, state)
		if not char then return end
		for _, p in pairs(char:GetChildren()) do
			if p:IsA("BasePart") then
				p.CanCollide = state
			end
		end
	end

	local function getVel()
		local dir = Vector3.new(Fling.x, Fling.y, Fling.z)
		if dir.Magnitude > 0 then dir = dir.Unit end
		return dir * Fling.power
	end

	local function playAnim()
		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)

		local isR15 = char:FindFirstChild("UpperTorso") ~= nil
		local id = isR15 and "rbxassetid://94235564114426" or "rbxassetid://204062532"

		if Fling.anim then
			Fling.anim:Stop()
			Fling.anim:Destroy()
		end

		local a = Instance.new("Animation")
		a.AnimationId = id
		Fling.anim = animator:LoadAnimation(a)
		Fling.anim.Looped = true
		Fling.anim:Play()
	end

	local function stopAnim()
		if Fling.anim then
			Fling.anim:Stop()
			Fling.anim:Destroy()
			Fling.anim = nil
		end
	end

	RS.Stepped:Connect(function()
		if Fling.enabled and Fling.noclip and player.Character then
			disCol(player.Character, false)
		end
	end)

	function Fling.start()
		if Fling.conn then return end
		Fling.enabled = true
		if Fling.punch then playAnim() end

		local ml = 0.1
		Fling.conn = RS.Heartbeat:Connect(function()
			local char = player.Character
			local root = getRoot(char)
			if not (char and char.Parent and root and root.Parent) then return end

			local lv = root.AssemblyLinearVelocity
			local fv = getVel()

			root.AssemblyLinearVelocity = fv
			RS.RenderStepped:Wait()

			if char and char.Parent and root and root.Parent then
				root.AssemblyLinearVelocity = lv
			end
			RS.Stepped:Wait()
			if char and char.Parent and root and root.Parent then
				root.AssemblyLinearVelocity = lv + Vector3.new(0, ml, 0)
				ml = ml * -1
			end
		end)
	end

	function Fling.stop()
		if Fling.conn then
			Fling.conn:Disconnect()
			Fling.conn = nil
		end
		Fling.enabled = false
		stopAnim()
		if player.Character and Fling.noclip then
			disCol(player.Character, true)
		end
	end

	function Fling.setEnabled(on)
		if on then Fling.start() else Fling.stop() end
	end

	function Fling.setPunch(on)
		Fling.punch = on
		if Fling.enabled then
			if on then playAnim() else stopAnim() end
		end
	end

	function Fling.setNoclip(on)
		Fling.noclip = on
		if player.Character and not on then
			disCol(player.Character, true)
		end
	end

	player.CharacterAdded:Connect(function()
		if Fling.enabled then
			Fling.stop()
		end
	end)

	function Fling.shutdown()
		Fling.stop()
	end
end

------------------------------------------------------------
-- PÁGINA 1: VELOCIDADE · PULO · ESP · NOCLIP
------------------------------------------------------------
do
	local c = card(158, C.blue, "VELOCIDADE", "⚡")
	navWidget(c)

	local setBox = valueBox(c, 52, 42, cardW - 64, 38, "25", C.blue, 22)

	-- BOTÃO 25 (Fundo Azul Forte com Texto Branco para destaque)
	local BTN25_BG = Color3.fromRGB(55, 135, 230) -- Azul idêntico ao da imagem
	local btn25 = new("TextButton", {
		Parent = c.frame, Position = UDim2.fromOffset(12, 42), Size = UDim2.fromOffset(34, 38),
		BackgroundColor3 = BTN25_BG, Text = "25", TextColor3 = Color3.new(1, 1, 1), TextSize = 15,
		Font = Enum.Font.GothamBold, AutoButtonColor = false,
	}, {corner(9)})
	local btn25st = stroke(BTN25_BG:Lerp(Color3.new(1, 1, 1), 0.3), 1.5, 0) -- Borda sutil clareada
	btn25st.Parent = btn25

	btn25.MouseEnter:Connect(function()
		tw(btn25, 0.15, {BackgroundColor3 = BTN25_BG:Lerp(Color3.new(1, 1, 1), 0.2)})
	end)
	btn25.MouseLeave:Connect(function()
		tw(btn25, 0.2, {BackgroundColor3 = BTN25_BG})
	end)

	local sliderSet
	sliderSet = slider(c, 96, 5, 500, 25, function(v)
		setBox(tostring(v))
		Speed.setValue(v)
	end)

	btn25.MouseButton1Click:Connect(function()
		sliderSet(25)
	end)

	toggle(c, 30, 108, cardW - 60, 26, function(on)
		Speed.setEnabled(on)
	end)
	hint(c, "Anti-ragdoll · Anti-stun · Força", 140)
end

do
	local c = card(92, C.pink, "PULO INFINITO", "🚀")
	toggle(c, 30, 40, cardW - 60, 28, function(on)
		InfJump.setEnabled(on)
	end)
	hint(c, "Espaço para pular", 72)
end

do
	local c = card(92, C.purple, "ESP", "👁")
	toggle(c, 30, 40, cardW - 60, 28, function(on)
		ESP.setEnabled(on)
	end)
	hint(c, "Nome · Distância · Chams", 72)
end

do
	local c = card(92, C.violet, "NOCLIP", "👻")
	toggle(c, 30, 40, cardW - 60, 28, function(on)
		Noclip.setEnabled(on)
	end)
	hint(c, "Atravesse paredes", 72)
end

------------------------------------------------------------
-- LÓGICA: AUTOPRESSER / CLICKER
------------------------------------------------------------
local AutoP = {enabled = false, mode = "click", active = false, capturing = false, lastClick = 0}
-- Teclas padrão: Click = E | HoldAct = R | HoldKey = E
AutoP.keys = {click = Enum.KeyCode.E, holdAct = Enum.KeyCode.R, holdKey = Enum.KeyCode.E}
do
	local CPS = 2000
	local CLICK_INTERVAL = 1 / CPS
	local MAX_PER_FRAME = 100
	local ignoreUntil = 0
	local holding = nil

	local VIM
	pcall(function() VIM = game:GetService("VirtualInputManager") end)

	local function mouseOverPanel(m)
		local p, sz = main.AbsolutePosition, main.AbsoluteSize
		return m.X >= p.X and m.X <= p.X + sz.X and m.Y >= p.Y and m.Y <= p.Y + sz.Y
	end

	local function clickAtMouse(n)
		local m = UIS:GetMouseLocation()
		if mouseOverPanel(m) then return end
		local ok = false
		if VIM then
			ok = pcall(function()
				for _ = 1, n do
					VIM:SendMouseButtonEvent(m.X, m.Y, 0, true, game, 1)
					VIM:SendMouseButtonEvent(m.X, m.Y, 0, false, game, 1)
				end
			end)
		end
		if not ok and mouse1click then
			for _ = 1, n do pcall(mouse1click) end
		end
	end

	local function sendKey(code, down)
		if not VIM then return end
		ignoreUntil = os.clock() + 0.15
		pcall(function() VIM:SendKeyEvent(down, code, false, game) end)
	end

	local function notify()
		if AutoP.onChange then AutoP.onChange() end
	end

	local function stopAll()
		AutoP.active = false
		if holding then
			sendKey(holding, false)
			holding = nil
		end
		notify()
	end

	local function start()
		AutoP.active = true
		AutoP.lastClick = os.clock()
		if AutoP.mode == "hold" then
			holding = AutoP.keys.holdKey
			sendKey(holding, true)
		end
		notify()
	end

	function AutoP.setEnabled(on)
		AutoP.enabled = on
		if not on then stopAll() end
	end

	function AutoP.setMode(m)
		if m == AutoP.mode then return end
		stopAll()
		AutoP.mode = m
		notify()
	end

	function AutoP.setKey(slot, code)
		if AutoP.active then stopAll() end
		AutoP.keys[slot] = code
		notify()
	end

	function AutoP.update()
		if not (AutoP.enabled and AutoP.active and AutoP.mode == "click") then return end
		local now = os.clock()
		local n = math.floor((now - AutoP.lastClick) * CPS)
		if n < 1 then return end
		if n > MAX_PER_FRAME then
			n = MAX_PER_FRAME
			AutoP.lastClick = now
		else
			AutoP.lastClick = AutoP.lastClick + n * CLICK_INTERVAL
		end
		clickAtMouse(n)
	end

	AutoP.conn = UIS.InputBegan:Connect(function(input)
		if not AutoP.enabled or AutoP.capturing then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if UIS:GetFocusedTextBox() then return end
		if os.clock() < ignoreUntil then return end
		local act = AutoP.mode == "click" and AutoP.keys.click or AutoP.keys.holdAct
		if input.KeyCode == act then
			if AutoP.active then stopAll() else start() end
		end
	end)

	function AutoP.shutdown()
		AutoP.enabled = false
		stopAll()
		if AutoP.conn then AutoP.conn:Disconnect() end
	end
end

do
	local c = card(138, C.orange, "AUTOPRESSER / CLICKER", "🖱")
	toggle(c, 12, 40, 108, 40, function(on) AutoP.setEnabled(on) end)

	local function newKeyBtn(x, w)
		local b = new("TextButton", {
			Parent = c.frame, Position = UDim2.fromOffset(x, 106), Size = UDim2.fromOffset(w, 24),
			BackgroundColor3 = C.bg2, Text = "", TextColor3 = C.text, TextSize = 13,
			Font = Enum.Font.GothamBold, AutoButtonColor = false, ClipsDescendants = true,
		}, {corner(8), stroke(C.line, 1, 0.4)})
		b.MouseEnter:Connect(function() tw(b, 0.15, {BackgroundColor3 = C.card1}) end)
		b.MouseLeave:Connect(function() tw(b, 0.2, {BackgroundColor3 = C.bg2}) end)
		return b
	end
	local kA = newKeyBtn(12, 198)
	local kB = newKeyBtn(117, 93)
	kB.Visible = false

	local function slotOf(btn)
		if btn == kB then return "holdKey" end
		return AutoP.mode == "click" and "click" or "holdAct"
	end

	local function showKey(btn)
		local name = AutoP.keys[slotOf(btn)].Name
		btn.Text = name
		btn.TextSize = #name > 6 and 10 or 13
	end

	local hintLbl = hint(c, "", 86)
	local function refresh()
		local k = AutoP.keys
		if AutoP.active then
			local act = AutoP.mode == "click" and k.click.Name or k.holdAct.Name
			hintLbl.Text = "● ATIVO · aperte [" .. act .. "] para parar"
			hintLbl.TextColor3 = C.orange
		elseif AutoP.mode == "click" then
			hintLbl.Text = "[" .. k.click.Name .. "] liga/desliga · clica onde o mouse está"
			hintLbl.TextColor3 = C.sub
		else
			hintLbl.Text = "[" .. k.holdAct.Name .. "] segura [" .. k.holdKey.Name .. "] · de novo solta"
			hintLbl.TextColor3 = C.sub
		end
		showKey(kA)
		showKey(kB)
	end
	AutoP.onChange = refresh

	local function layout(animate)
		local hold = AutoP.mode == "hold"
		local t = animate and 0.25 or 0
		if hold then
			kB.Visible = true
			kB.Size = UDim2.fromOffset(animate and 0 or 93, 24)
			tw(kA, t, {Size = UDim2.fromOffset(93, 24)}, Enum.EasingStyle.Quint)
			tw(kB, t, {Size = UDim2.fromOffset(93, 24)}, Enum.EasingStyle.Quint)
		else
			tw(kA, t, {Size = UDim2.fromOffset(198, 24)}, Enum.EasingStyle.Quint)
			tw(kB, t, {Size = UDim2.fromOffset(0, 24)}, Enum.EasingStyle.Quint)
			task.delay(t, function()
				if AutoP.mode == "click" then kB.Visible = false end
			end)
		end
	end

	local pills = {}
	local modes = {"click", "hold"}
	local function paintPills()
		for j, p in ipairs(pills) do
			local on = modes[j] == AutoP.mode
			tw(p, 0.2, {
				BackgroundColor3 = on and C.orange or C.bg2,
				TextColor3 = on and Color3.new(1, 1, 1) or C.sub,
			})
		end
	end
	for i, name in ipairs({"CLICK", "HOLD"}) do
		local p = new("TextButton", {
			Parent = c.frame, Position = UDim2.fromOffset(130, 40 + (i - 1) * 22), Size = UDim2.fromOffset(80, 18),
			BackgroundColor3 = C.bg2, Text = name, TextColor3 = C.sub, TextSize = 9,
			Font = Enum.Font.GothamBold, AutoButtonColor = false,
		}, {corner(9)})
		pills[i] = p
		p.MouseButton1Click:Connect(function()
			AutoP.setMode(modes[i])
			paintPills()
			layout(true)
		end)
	end

	local function bind(btn)
		btn.MouseButton1Click:Connect(function()
			if AutoP.capturing then return end
			AutoP.capturing = true
			btn.Text = "..."
			btn.TextSize = 13
			local conn
			conn = UIS.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Keyboard then
					conn:Disconnect()
					if input.KeyCode ~= Enum.KeyCode.Escape then
						AutoP.setKey(slotOf(btn), input.KeyCode)
					end
					showKey(btn)
					task.defer(function() AutoP.capturing = false end)
				end
			end)
		end)
	end
	bind(kA)
	bind(kB)

	paintPills()
	layout(false)
	refresh()
end

------------------------------------------------------------
-- LÓGICA: FLY (clássico)
------------------------------------------------------------
local Fly = {enabled = false, active = false, value = 1}
do
	local FLY_MULT = 3
	local MAX_SPEED = 2000
	local FLY_KEY = Enum.KeyCode.F
	local bv, bg

	local function getParts()
		local ch = player.Character
		if not ch then return end
		return ch:FindFirstChildOfClass("Humanoid"), ch:FindFirstChild("HumanoidRootPart")
	end

	local function notify()
		if Fly.onChange then Fly.onChange() end
	end

	local function stop()
		if not Fly.active then return end
		Fly.active = false
		Noclip.suspendGround = false
		InfJump.suspended = false
		Speed.flying = false
		if bv then bv:Destroy(); bv = nil end
		if bg then bg:Destroy(); bg = nil end

		local hum, root = getParts()
		if hum then hum.PlatformStand = false end
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			local look = root.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.01 then
				root.CFrame = CFrame.new(root.Position, root.Position + flat)
			end
		end
		notify()
	end

	local function start()
		local hum, root = getParts()
		if not hum or not root or hum.Health <= 0 then return end
		Fly.active = true
		Noclip.suspendGround = true
		InfJump.suspended = true
		Speed.flying = true
		hum.PlatformStand = true

		bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
		bv.Velocity = Vector3.zero
		bv.Parent = root

		bg = Instance.new("BodyGyro")
		bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
		bg.P = 9e4
		bg.D = 1000
		bg.CFrame = root.CFrame
		bg.Parent = root
		notify()
	end

	function Fly.setEnabled(on)
		Fly.enabled = on
		if not on then stop() end
	end

	function Fly.setValue(v)
		Fly.value = v
	end

	function Fly.update()
		if not Fly.active then return end
		local hum, root = getParts()
		if not hum or not root or hum.Health <= 0 or not bv or bv.Parent ~= root then
			stop()
			return
		end
		local cam = workspace.CurrentCamera
		if not cam then return end

		local look, right = cam.CFrame.LookVector, cam.CFrame.RightVector
		local dir = Vector3.zero
		if not UIS:GetFocusedTextBox() then
			if UIS:IsKeyDown(Enum.KeyCode.W) then dir += look end
			if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= look end
			if UIS:IsKeyDown(Enum.KeyCode.D) then dir += right end
			if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= right end
			if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
			if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
				dir -= Vector3.yAxis
			end
		end

		if dir.Magnitude == 0 then
			local md = hum.MoveDirection
			if md.Magnitude > 0 then
				local flat = Vector3.new(look.X, 0, look.Z)
				if flat.Magnitude > 0.01 then
					local fwd = md:Dot(flat.Unit)
					local tilt = math.clamp(look.Y / flat.Magnitude, -3, 3)
					dir = md + Vector3.new(0, fwd * tilt, 0)
				else
					dir = md
				end
			end
		end

		local speed = math.min(Fly.value * FLY_MULT * hum.WalkSpeed, MAX_SPEED)
		bv.Velocity = dir.Magnitude > 0 and dir.Unit * speed or Vector3.zero
		bg.CFrame = cam.CFrame
	end

	Fly.conn = UIS.InputBegan:Connect(function(input)
		if not Fly.enabled then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard or input.KeyCode ~= FLY_KEY then return end
		if UIS:GetFocusedTextBox() then return end
		if Fly.active then stop() else start() end
	end)

	function Fly.shutdown()
		Fly.enabled = false
		stop()
		if Fly.conn then Fly.conn:Disconnect() end
	end
end

do
	local c = card(158, C.cyan, "FLY", "✈")
	local setBox = valueBox(c, 50, 42, cardW - 100, 36, "1", C.cyan, 20)
	slider(c, 96, 1, 10, 1, function(v)
		setBox(tostring(v))
		Fly.setValue(v)
	end)
	toggle(c, 30, 108, cardW - 60, 26, function(on) Fly.setEnabled(on) end)

	local hintLbl = hint(c, "", 140)
	local function refresh()
		if Fly.active then
			hintLbl.Text = "● VOANDO · [F] para pousar"
			hintLbl.TextColor3 = C.cyan
		else
			hintLbl.Text = "[F] liga/desliga · Espaço sobe · Shift desce"
			hintLbl.TextColor3 = C.sub
		end
	end
	Fly.onChange = refresh
	refresh()
end

------------------------------------------------------------
-- LÓGICA: AIMBOT
------------------------------------------------------------
local Aimbot = {enabled = false, teamCheck = false, autoShot = false, showFov = false, fov = 2, target = nil}
do
	local PX_PER_LEVEL = 50
	local WALL_CHECK = true
	local SHOT_CPS = 12
	local SHOT_TOLERANCE = 35
	local BIND_NAME = "BSC_Aimbot"

	local VIM
	pcall(function() VIM = game:GetService("VirtualInputManager") end)
	local GuiService = game:GetService("GuiService")

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
	rayParams.RespectCanCollide = true

	local function isDead()
		local ch = player.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		return not hum or hum.Health <= 0
	end

	local function mouseOverPanel(m)
		local p, sz = main.AbsolutePosition, main.AbsoluteSize
		return m.X >= p.X and m.X <= p.X + sz.X and m.Y >= p.Y and m.Y <= p.Y + sz.Y
	end

	local function overGuiButton(m)
		local ok, objs = pcall(function()
			local inset = GuiService:GetGuiInset()
			return playerGui:GetGuiObjectsAtPosition(m.X - inset.X, m.Y - inset.Y)
		end)
		if not ok then return false end
		for _, o in ipairs(objs) do
			if o:IsA("GuiButton") and o.Visible then return true end
		end
		return false
	end

	local function diameter(level) return 2 * level * PX_PER_LEVEL end

	local fovCircle = new("Frame", {
		Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(diameter(Aimbot.fov), diameter(Aimbot.fov)),
		BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
	}, {
		new("UICorner", {CornerRadius = UDim.new(1, 0)}),
		stroke(C.on, 1.5, 0.35),
	})

	local function evaluate(plr)
		if plr == player then return end
		if Aimbot.teamCheck and plr.Team ~= nil and plr.Team == player.Team then return end

		local ch = plr.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		local head = ch and ch:FindFirstChild("Head")
		if not hum or not head or hum.Health <= 0 then return end

		local cam = workspace.CurrentCamera
		if not cam then return end
		local pos, onScreen = cam:WorldToViewportPoint(head.Position)
		if not onScreen then return end

		local d = (Vector2.new(pos.X, pos.Y) - cam.ViewportSize / 2).Magnitude
		if d > Aimbot.fov * PX_PER_LEVEL then return end

		if WALL_CHECK then
			rayParams.FilterDescendantsInstances = {player.Character}
			local origin = cam.CFrame.Position
			local res = workspace:Raycast(origin, head.Position - origin, rayParams)
			if res and not res.Instance:IsDescendantOf(ch) then return end
		end
		return d, head
	end

	local function pickTarget()
		local cur = Aimbot.target
		if cur then
			local d, head = evaluate(cur)
			if d then return cur, head end
		end
		local best, bestHead, bestD
		for _, plr in ipairs(Players:GetPlayers()) do
			local d, head = evaluate(plr)
			if d and (not bestD or d < bestD) then
				best, bestHead, bestD = plr, head, d
			end
		end
		return best, bestHead
	end

	local lastShot = 0
	local function fire()
		local now = os.clock()
		if now - lastShot < 1 / SHOT_CPS then return end
		lastShot = now
		local c = UIS:GetMouseLocation()
		local ok = false
		if VIM then
			ok = pcall(function()
				VIM:SendMouseButtonEvent(c.X, c.Y, 0, true, game, 1)
				VIM:SendMouseButtonEvent(c.X, c.Y, 0, false, game, 1)
			end)
		end
		if not ok and mouse1click then pcall(mouse1click) end
	end

	local function step(dt)
		local cam = workspace.CurrentCamera
		if not cam then return end

		if isDead() or GuiService.MenuIsOpen then
			Aimbot.target = nil
			return
		end

		local plr, head = pickTarget()
		Aimbot.target = plr
		if not plr then return end

		cam.CFrame = CFrame.lookAt(cam.CFrame.Position, head.Position)

		if Aimbot.autoShot then
			local pos = cam:WorldToViewportPoint(head.Position)
			if (Vector2.new(pos.X, pos.Y) - cam.ViewportSize / 2).Magnitude <= SHOT_TOLERANCE then
				local m = UIS:GetMouseLocation()
				if not mouseOverPanel(m) and not overGuiButton(m) then
					fire()
				end
			end
		end
	end

	function Aimbot.setEnabled(on)
		if on == Aimbot.enabled then return end
		Aimbot.enabled = on
		if on then
			RS:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, step)
		else
			pcall(function() RS:UnbindFromRenderStep(BIND_NAME) end)
			Aimbot.target = nil
		end
	end

	function Aimbot.setShowFov(on)
		Aimbot.showFov = on
		fovCircle.Visible = on
	end

	function Aimbot.setFov(v)
		Aimbot.fov = v
		tw(fovCircle, 0.2, {Size = UDim2.fromOffset(diameter(v), diameter(v))})
	end

	function Aimbot.shutdown()
		Aimbot.setEnabled(false)
	end
end

------------------------------------------------------------
-- LÓGICA: TP CLICK
------------------------------------------------------------
local TPClick = {enabled = false}
do
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local function standHeight(hum, root, char)
		local legs = 0
		if hum.RigType == Enum.HumanoidRigType.R6 then
			local leg = char:FindFirstChild("Left Leg")
			legs = leg and leg.Size.Y or 2
		end
		return hum.HipHeight + legs + root.Size.Y / 2
	end

	local function mouseOverPanel(m)
		local p, sz = main.AbsolutePosition, main.AbsoluteSize
		return m.X >= p.X and m.X <= p.X + sz.X and m.Y >= p.Y and m.Y <= p.Y + sz.Y
	end

	function TPClick.setEnabled(on)
		TPClick.enabled = on
	end

	TPClick.conn = UIS.InputBegan:Connect(function(input, gp)
		if not TPClick.enabled then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not UIS:IsKeyDown(Enum.KeyCode.LeftControl) then return end
		if gp or UIS:GetFocusedTextBox() then return end

		local m = UIS:GetMouseLocation()
		if mouseOverPanel(m) then return end

		local cam = workspace.CurrentCamera
		local ch = player.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		if not cam or not hum or not root or hum.Health <= 0 then return end

		local ray = cam:ViewportPointToRay(m.X, m.Y)
		params.FilterDescendantsInstances = {ch}
		local res = workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
		if not res then return end

		local pos
		if res.Normal.Y > 0.5 then
			pos = res.Position + Vector3.new(0, standHeight(hum, root, ch), 0)
		else
			pos = res.Position + res.Normal * 2
		end

		root.CFrame = CFrame.new(pos) * (root.CFrame - root.CFrame.Position)
		root.AssemblyLinearVelocity = Vector3.zero
		Noclip.lastGroundY = nil
	end)

	function TPClick.shutdown()
		TPClick.enabled = false
		if TPClick.conn then TPClick.conn:Disconnect() end
	end
end

------------------------------------------------------------
-- LÓGICA: TP JOGADOR
------------------------------------------------------------
local TPPlayer = {enabled = true, conns = {}}
do
	local BEHIND = 3

	function TPPlayer.teleportTo(plr)
		if not TPPlayer.enabled then return false end
		local ch = player.Character
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		local tch = plr.Character
		local troot = tch and tch:FindFirstChild("HumanoidRootPart")
		if not root or not troot then return false end

		root.CFrame = troot.CFrame * CFrame.new(0, 0, BEHIND)
		root.AssemblyLinearVelocity = Vector3.zero
		Noclip.lastGroundY = nil
		return true
	end

	function TPPlayer.shutdown()
		TPPlayer.enabled = false
		for _, cn in ipairs(TPPlayer.conns) do cn:Disconnect() end
		TPPlayer.conns = {}
	end
end

------------------------------------------------------------
-- LÓGICA: HITBOX EXPANDER
------------------------------------------------------------
local Hitbox = {enabled = false, showBox = false}
do
	local EXPANDED = Vector3.new(120, 120, 120)
	local BOX_COLOR = Color3.new(1, 1, 1)
	local state = setmetatable({}, {__mode = "k"})

	local function stateOf(root)
		local st = state[root]
		if not st then
			st = {expanded = false}
			state[root] = st
		end
		return st
	end

	local function restore(root, st)
		if st.expanded and root.Parent then
			root.Size = st.origSize
			root.CanCollide = st.origCollide
		end
		st.expanded = false
	end

	function Hitbox.update()
		if not (Hitbox.enabled or Hitbox.showBox) then return end

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player then
				local ch = plr.Character
				local root = ch and ch:FindFirstChild("HumanoidRootPart")
				if root then
					local st = stateOf(root)

					if Hitbox.enabled then
						if not st.expanded then
							st.origSize = root.Size
							st.origCollide = root.CanCollide
							st.expanded = true
						end
						if root.Size ~= EXPANDED then root.Size = EXPANDED end
						if root.CanCollide then root.CanCollide = false end
					elseif st.expanded then
						restore(root, st)
					end

					if Hitbox.showBox then
						if not st.adorn or not st.adorn.Parent then
							st.adorn = new("BoxHandleAdornment", {
								Parent = root, Adornee = root, Size = root.Size, Color3 = BOX_COLOR,
								Transparency = 0.93, AlwaysOnTop = true, ZIndex = 1,
							})
						end
						if st.adorn.Size ~= root.Size then st.adorn.Size = root.Size end
					elseif st.adorn then
						st.adorn:Destroy()
						st.adorn = nil
					end
				end
			end
		end
	end

	function Hitbox.setEnabled(on)
		Hitbox.enabled = on
		if not on then
			for root, st in pairs(state) do restore(root, st) end
		end
	end

	function Hitbox.setShowBox(on)
		Hitbox.showBox = on
		if not on then
			for _, st in pairs(state) do
				if st.adorn then st.adorn:Destroy(); st.adorn = nil end
			end
		end
	end

	function Hitbox.shutdown()
		Hitbox.setEnabled(false)
		Hitbox.setShowBox(false)
	end
end

------------------------------------------------------------
-- LÓGICA: FULLBRIGHT
------------------------------------------------------------
local Fullbright = {enabled = false, orig = {}}
do
	local Lighting = game:GetService("Lighting")

	function Fullbright.setEnabled(on)
		if on == Fullbright.enabled then return end
		Fullbright.enabled = on

		if on then
			Fullbright.orig.GlobalShadows = Lighting.GlobalShadows
			Lighting.GlobalShadows = false
		else
			Lighting.GlobalShadows = Fullbright.orig.GlobalShadows
		end
	end

	function Fullbright.enforce()
		if not Fullbright.enabled then return end
		if Lighting.GlobalShadows then
			Lighting.GlobalShadows = false
		end
	end

	function Fullbright.shutdown()
		Fullbright.setEnabled(false)
	end
end

------------------------------------------------------------
-- PÁGINA 2: AIMBOT · HITBOX · TP CLICK · TP JOGADOR · FULLBRIGHT · FLING
------------------------------------------------------------
local function vslider(c, x, y, h, minV, maxV, startV, cb)
	local f = c.frame
	local track = new("Frame", {
		Parent = f, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(4, h),
		BackgroundColor3 = C.track, BorderSizePixel = 0,
	}, {corner(2)})
	local fill = new("Frame", {
		Parent = track, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0), BackgroundColor3 = c.accent, BorderSizePixel = 0,
	}, {corner(2)})
	local knob = new("Frame", {
		Parent = track, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12),
		Position = UDim2.fromScale(0.5, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2,
	}, {corner(8), stroke(c.accent, 2, 0)})
	local hit = new("TextButton", {
		Parent = knob, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Text = "", ZIndex = 3,
	})

	local current
	local function setValue(v)
		v = math.clamp(math.floor(v + 0.5), minV, maxV)
		local a = (v - minV) / (maxV - minV)
		fill.Size = UDim2.fromScale(1, a)
		knob.Position = UDim2.fromScale(0.5, 1 - a)
		if v ~= current then
			current = v
			if cb then cb(v) end
		end
	end
	setValue(startV)

	local dragging = false
	local grab = 0
	local function update()
		local my = UIS:GetMouseLocation().Y - grab
		local a = 1 - math.clamp((my - track.AbsolutePosition.Y) / track.AbsoluteSize.Y, 0, 1)
		setValue(minV + a * (maxV - minV))
	end
	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			grab = UIS:GetMouseLocation().Y - (knob.AbsolutePosition.Y + knob.AbsoluteSize.Y / 2)
			tw(knob, 0.15, {Size = UDim2.fromOffset(17, 17)}, Enum.EasingStyle.Back)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			tw(knob, 0.2, {Size = UDim2.fromOffset(12, 12)}, Enum.EasingStyle.Back)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			update()
		end
	end)
end

-- AIMBOT ------------------------------------------------------
do
	local c = card(150, C.on, "AIMBOT", "🤖", page2)
	navWidget(c)
	toggle(c, 12, 44, 104, 32, function(on) Aimbot.setEnabled(on) end)

	local fovBtn = new("TextButton", {
		Parent = c.frame, Position = UDim2.fromOffset(122, 44), Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = C.bg2, Text = "", AutoButtonColor = false,
	}, {corner(9)})
	local fovStroke = stroke(C.line, 1.5, 0.2)
	fovStroke.Parent = fovBtn
	local ringStroke = stroke(C.sub, 2, 0)
	local ring = new("Frame", {
		Parent = fovBtn, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1,
	}, {new("UICorner", {CornerRadius = UDim.new(1, 0)}), ringStroke})

	local fovOn, fovHover = false, false
	local function paintFov()
		tw(ringStroke, 0.2, {Color = fovOn and C.on or C.sub})
		tw(fovStroke, 0.2, {Color = fovOn and C.on or C.line, Transparency = fovOn and 0.1 or 0.2})
		tw(ring, 0.25, {Size = fovOn and UDim2.fromOffset(18, 18) or UDim2.fromOffset(16, 16)}, Enum.EasingStyle.Back)
		tw(fovBtn, 0.2, {BackgroundColor3 = fovHover and C.card1 or C.bg2})
	end
	fovBtn.MouseEnter:Connect(function() fovHover = true; paintFov() end)
	fovBtn.MouseLeave:Connect(function() fovHover = false; paintFov() end)
	fovBtn.MouseButton1Click:Connect(function()
		fovOn = not fovOn
		paintFov()
		Aimbot.setShowFov(fovOn)
	end)

	local shot = new("TextButton", {
		Parent = c.frame, Position = UDim2.fromOffset(12, 86), Size = UDim2.fromOffset(104, 28),
		BackgroundColor3 = C.bg2, Text = "AUTO SHOT", TextColor3 = C.text, TextSize = 11,
		Font = Enum.Font.GothamBold, AutoButtonColor = false, ClipsDescendants = true,
	}, {corner(8)})
	local shotStroke = stroke(C.line, 1, 0.3)
	shotStroke.Parent = shot
	new("TextLabel", {
		Parent = shot, BackgroundTransparency = 1, Position = UDim2.new(1, -26, 0, 0), Size = UDim2.fromOffset(24, 28),
		Text = "🔫", TextSize = 12, TextTransparency = 0.55,
	})
	local shotOn = false
	shot.MouseEnter:Connect(function() tw(shot, 0.15, {BackgroundColor3 = C.card1}) end)
	shot.MouseLeave:Connect(function() tw(shot, 0.2, {BackgroundColor3 = C.bg2}) end)
	shot.MouseButton1Click:Connect(function()
		shotOn = not shotOn
		tw(shot, 0.2, {TextColor3 = shotOn and C.on or C.text})
		tw(shotStroke, 0.2, {Color = shotOn and C.on or C.line, Transparency = shotOn and 0.1 or 0.3})
		Aimbot.autoShot = shotOn
	end)

	local fovBox = label(c.frame, "2", 14, UDim2.fromOffset(150, 40), UDim2.fromOffset(46, 18), C.on, true)
	local fovSc = new("UIScale", {Parent = fovBox})
	label(c.frame, "10", 8, UDim2.fromOffset(178, 62), UDim2.fromOffset(20, 10), C.sub, false, Enum.TextXAlignment.Left)
	vslider(c, 171, 64, 44, 1, 10, 2, function(v)
		fovBox.Text = tostring(v)
		softPop(fovSc, 1.1)
		Aimbot.setFov(v)
	end)
	label(c.frame, "FOV", 8, UDim2.fromOffset(150, 112), UDim2.fromOffset(46, 12), C.sub, true)

	hint(c, "Aimbot sempre ativo quando ligado", 128)
end

-- HITBOX EXPANDER ----------------------------------------------
do
	local c = card(100, Color3.fromRGB(245, 200, 70), "HITBOX EXPANDER", "🎯", page2)
	toggle(c, 24, 40, 112, 30, function(on) Hitbox.setEnabled(on) end)

	local eye = new("TextButton", {
		Parent = c.frame, Position = UDim2.fromOffset(152, 40), Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = C.bg2, Text = "👁", TextSize = 15, TextColor3 = C.text, AutoButtonColor = false,
	}, {corner(8)})
	local eyeStroke = stroke(C.off, 1.5, 0.3)
	eyeStroke.Parent = eye
	local slash = new("Frame", {
		Parent = eye, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(28, 2), Rotation = -45, BackgroundColor3 = C.off, BorderSizePixel = 0,
	})
	local shown = false
	eye.MouseEnter:Connect(function() tw(eye, 0.15, {BackgroundColor3 = C.card1}) end)
	eye.MouseLeave:Connect(function() tw(eye, 0.2, {BackgroundColor3 = C.bg2}) end)
	eye.MouseButton1Click:Connect(function()
		shown = not shown
		slash.Visible = not shown
		tw(eyeStroke, 0.2, {Color = shown and C.on or C.off})
		Hitbox.setShowBox(shown)
	end)

	hint(c, "Expanda a hitbox dos jogadores (120x120)", 78)
end

-- TP CLICK ----------------------------------------------------
do
	local c = card(92, C.blue, "TP CLICK", "📍", page2)
	toggle(c, 30, 40, cardW - 60, 28, function(on) TPClick.setEnabled(on) end)
	hint(c, "Ctrl + Clique Esquerdo", 72)
end

-- TP JOGADOR ---------------------------------------------------
do
	local c = card(194, C.purple, "TP JOGADOR", "👥", page2)
	local listEmpty
	local entries = {}

	c.dot.BackgroundColor3 = C.on
	activeDots[c.dot] = true

	local searchBox = new("TextBox", {
		Parent = c.frame, Position = UDim2.fromOffset(12, 40), Size = UDim2.fromOffset(cardW - 24, 24),
		BackgroundColor3 = C.bg2, Text = "", PlaceholderText = "Pesquisar jogador...",
		PlaceholderColor3 = C.sub, TextColor3 = C.text, TextSize = 11, Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, BorderSizePixel = 0,
	}, {
		corner(8),
		new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}),
	})
	local searchStroke = stroke(C.line, 1, 0.4)
	searchStroke.Parent = searchBox
	searchBox.Focused:Connect(function() tw(searchStroke, 0.2, {Color = C.purple, Transparency = 0.1}) end)
	searchBox.FocusLost:Connect(function() tw(searchStroke, 0.2, {Color = C.line, Transparency = 0.4}) end)

	local listFrame = new("ScrollingFrame", {
		Parent = c.frame, Position = UDim2.fromOffset(12, 70), Size = UDim2.fromOffset(cardW - 24, 100),
		BackgroundColor3 = C.bg2, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.line,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, {
		corner(8),
		new("UIPadding", {
			PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6),
		}),
		new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.Name}),
	})

	local SCROLL_STEP = 16
	local ROW_H, ROW_GAP, LIST_PAD, LIST_H = 24, 4, 8, 100
	listFrame.ScrollingEnabled = false

	local function maxScroll()
		local n = 0
		for _, b in pairs(entries) do
			if b.Visible then n += 1 end
		end
		local content = n * ROW_H + math.max(0, n - 1) * ROW_GAP + LIST_PAD
		return math.max(0, content - LIST_H)
	end

	local scrollTarget = 0
	local scrollTween
	local function scrollTo(y)
		y = math.clamp(y, 0, maxScroll())
		scrollTarget = y
		if scrollTween then scrollTween:Cancel() end
		scrollTween = tw(listFrame, 0.18, {CanvasPosition = Vector2.new(0, y)}, Enum.EasingStyle.Quad)
	end

	local function onWheel(input)
		if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
		scrollTo(scrollTarget - input.Position.Z * SCROLL_STEP)
	end
	listFrame.InputChanged:Connect(onWheel)

	local function clampScrollTarget()
		scrollTo(scrollTarget)
	end

	listEmpty = label(c.frame, "Nenhum outro jogador no servidor", 9, UDim2.fromOffset(12, 112), UDim2.fromOffset(cardW - 24, 14), C.sub)

	local query = ""
	local function matches(plr)
		if query == "" then return true end
		return plr.Name:lower():find(query, 1, true) ~= nil
			or plr.DisplayName:lower():find(query, 1, true) ~= nil
	end

	local function refreshEmpty()
		local total, shown = 0, 0
		for plr, b in pairs(entries) do
			total += 1
			local ok = matches(plr)
			b.Visible = ok
			if ok then shown += 1 end
		end
		listEmpty.Visible = shown == 0
		listEmpty.Text = total == 0 and "Nenhum outro jogador no servidor" or "Nenhum jogador encontrado"
	end

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		query = searchBox.Text:lower():match("^%s*(.-)%s*$")
		refreshEmpty()
		clampScrollTarget()
	end)

	local function flash(b, col)
		b.BackgroundColor3 = col
		tw(b, 0.45, {BackgroundColor3 = C.card1})
	end

	local function addPlayer(plr)
		if plr == player or entries[plr] then return end
		local text = plr.DisplayName == plr.Name and plr.Name or (plr.DisplayName .. "  @" .. plr.Name)
		local b = new("TextButton", {
			Parent = listFrame, Name = plr.Name:lower(), Size = UDim2.new(1, 0, 0, 24),
			BackgroundColor3 = C.card1, Text = text, TextColor3 = TPPlayer.enabled and C.text or C.sub,
			TextSize = 11, Font = Enum.Font.GothamMedium, AutoButtonColor = false,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		}, {
			corner(6),
			new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}),
		})
		b.MouseEnter:Connect(function()
			if TPPlayer.enabled then tw(b, 0.15, {BackgroundColor3 = C.line}) end
		end)
		b.MouseLeave:Connect(function() tw(b, 0.2, {BackgroundColor3 = C.card1}) end)
		b.InputChanged:Connect(onWheel)
		b.MouseButton1Click:Connect(function()
			if TPPlayer.teleportTo(plr) then
				flash(b, C.on)
			else
				flash(b, C.off)
			end
			searchBox:ReleaseFocus()
			searchBox.Text = ""
		end)
		entries[plr] = b
		refreshEmpty()
		clampScrollTarget()
	end

	local function removePlayer(plr)
		local b = entries[plr]
		if b then b:Destroy() end
		entries[plr] = nil
		refreshEmpty()
		clampScrollTarget()
	end

	for _, plr in ipairs(Players:GetPlayers()) do addPlayer(plr) end
	refreshEmpty()
	table.insert(TPPlayer.conns, Players.PlayerAdded:Connect(addPlayer))
	table.insert(TPPlayer.conns, Players.PlayerRemoving:Connect(removePlayer))

	hint(c, "Clique no nome para teleportar", 176)
end

-- FULLBRIGHT ---------------------------------------------------
do
	local c = card(92, Color3.fromRGB(255, 220, 100), "FULLBRIGHT", "💡", page2)
	toggle(c, 30, 40, cardW - 60, 28, function(on)
		Fullbright.setEnabled(on)
	end)
	hint(c, "Remove todas as sombras", 72)
end

-- FLING (PUNCH) --------------------------------------------------
do
	local c = card(160, C.pink, "FLING (PUNCH)", "🥊", page2)

	toggle(c, 30, 40, cardW - 60, 28, function(on) Fling.setEnabled(on) end)

	local powBox = textInput(c, 12, 80, 90, 24, "1000000", "Power")
	local xBox = textInput(c, 108, 80, 32, 24, "0", "X")
	local yBox = textInput(c, 144, 80, 32, 24, "1", "Y")
	local zBox = textInput(c, 180, 80, 32, 24, "0", "Z")

	powBox:GetPropertyChangedSignal("Text"):Connect(function()
		Fling.power = tonumber(powBox.Text) or 1
	end)
	xBox:GetPropertyChangedSignal("Text"):Connect(function()
		Fling.x = tonumber(xBox.Text) or 0
	end)
	yBox:GetPropertyChangedSignal("Text"):Connect(function()
		Fling.y = tonumber(yBox.Text) or 0
	end)
	zBox:GetPropertyChangedSignal("Text"):Connect(function()
		Fling.z = tonumber(zBox.Text) or 0
	end)

	local function miniBtn(x, text, activeColor, onClick)
		local b = new("TextButton", {
			Parent = c.frame, Position = UDim2.fromOffset(x, 115), Size = UDim2.fromOffset(99, 26),
			BackgroundColor3 = C.bg2, Text = text, TextColor3 = C.sub, TextSize = 10,
			Font = Enum.Font.GothamBold, AutoButtonColor = false,
		}, {corner(8)})
		local st = stroke(C.line, 1, 0.3)
		st.Parent = b

		local state = false
		local function paint()
			tw(b, 0.2, {BackgroundColor3 = state and activeColor or C.bg2})
			tw(b, 0.2, {TextColor3 = state and Color3.new(1,1,1) or C.sub})
			tw(st, 0.2, {Color = state and activeColor or C.line, Transparency = state and 0.1 or 0.3})
		end

		b.MouseEnter:Connect(function() if not state then tw(b, 0.15, {BackgroundColor3 = C.card1}) end end)
		b.MouseLeave:Connect(function() if not state then tw(b, 0.2, {BackgroundColor3 = C.bg2}) end end)

		b.MouseButton1Click:Connect(function()
			state = not state
			paint()
			onClick(state)
		end)
	end

	miniBtn(12, "PUNCH MODE", C.on, function(on) Fling.setPunch(on) end)
	miniBtn(117, "NOCLIP", C.violet, function(on) Fling.setNoclip(on) end)

end

scroll2.CanvasSize = UDim2.fromOffset(0, page2.cursor + 20)

------------------------------------------------------------
-- PÁGINA 3: (vazia, reservada para o futuro)
------------------------------------------------------------
do
	local navHost = new("Frame", {
		Parent = scroll3, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(cardW, 40),
		BackgroundTransparency = 1,
	})
	navWidget({frame = navHost, accent = C.sub})
	label(scroll3, "Reservado para novas funções", 10, UDim2.fromOffset(14, 60), UDim2.fromOffset(cardW, 16), C.sub)
	page3.cursor = 80
end
scroll3.CanvasSize = UDim2.fromOffset(0, page3.cursor + 20)

------------------------------------------------------------
-- Rodapé (espaço extra no final)
------------------------------------------------------------
do
	local line = new("Frame", {
		Parent = scroll, Position = UDim2.fromOffset(40, cursor + 6), Size = UDim2.fromOffset(W - 80, 2),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, {corner(1)})
	addRainbow(new("UIGradient", {Parent = line}), 0.6)
	label(scroll, "Basic Settings · v2.0", 9, UDim2.fromOffset(0, cursor + 16), UDim2.fromOffset(W, 14), C.sub)
	cursor = cursor + 64
end
scroll.CanvasSize = UDim2.fromOffset(0, cursor)

local totalH = 58 + cursor
local UI_SCALE = 0.85
local fit = math.clamp((viewH - 30) / totalH, 0.55, UI_SCALE)
H = math.min(totalH, (viewH - 30) / fit)
main.Size = UDim2.fromOffset(W, H)
scroll.Size = UDim2.fromOffset(W, H - 58)
scroll2.Size = UDim2.fromOffset(W, H - 58)
scroll3.Size = UDim2.fromOffset(W, H - 58)
main.Position = UDim2.fromOffset(40, math.max(10, math.floor((viewH - H * fit) / 2)))

------------------------------------------------------------
-- Animação contínua
------------------------------------------------------------
local closing = false
local lastHeal = 0
local function healUI()
	if closing then return end
	local now = os.clock()
	if now - lastHeal < 0.5 or now < Anim.untilT or Pager.busy then return end
	lastHeal = now

	if content.GroupTransparency > 0.01 then content.GroupTransparency = 0 end
	if main.BackgroundTransparency > 0.01 then main.BackgroundTransparency = 0 end
	if mainStroke.Transparency > 0.2 then mainStroke.Transparency = 0.15 end
	for _, item in ipairs(pageLists[Pager.current]) do
		if item.veil.BackgroundTransparency < 0.99 then item.veil.BackgroundTransparency = 1 end
		if item.stroke.Transparency > 0.6 then item.stroke.Transparency = 0.5 end
		if item.cg.Position ~= item.final then item.cg.Position = item.final end
	end
end

local updaters = {Speed.enforce, InfJump.update, ESP.update, AutoP.update, Fly.update, Hitbox.update, Fullbright.enforce, healUI}

local t0 = os.clock()
local conn = RS.Heartbeat:Connect(function()
	local t = os.clock() - t0
	for _, r in ipairs(rainbows) do
		local h = (t * 0.07 + r.phase) % 1
		r.grad.Color = ColorSequence.new(Color3.fromHSV(h, 0.6, 1), Color3.fromHSV((h + 0.25) % 1, 0.6, 1))
	end
	for _, fn in ipairs(updaters) do pcall(fn) end
	mainStrokeGrad.Rotation = (t * 50) % 360
	gear.Rotation = (t * 45) % 360
	for i, b in ipairs(bars) do
		b.BackgroundTransparency = 0.05 + 0.3 * (0.5 + 0.5 * math.sin(t * 2.2 + i))
	end
	for i, s in ipairs(pulseStrokes) do
		s.Transparency = 0.2 + 0.4 * (0.5 + 0.5 * math.sin(t * 2 + i))
	end
	for d in pairs(activeDots) do
		d.BackgroundTransparency = 0.45 * (0.5 + 0.5 * math.sin(t * 5))
	end
end)
gui.Destroying:Connect(function()
	conn:Disconnect()
	setZoomLock(false)
	Speed.shutdown()
	InfJump.shutdown()
	ESP.shutdown()
	Noclip.shutdown()
	AutoP.shutdown()
	Fly.shutdown()
	Aimbot.shutdown()
	TPClick.shutdown()
	TPPlayer.shutdown()
	Hitbox.shutdown()
	Fullbright.shutdown()
	Fling.shutdown()
end)

------------------------------------------------------------
-- Trava de zoom: enquanto o mouse estiver sobre o painel, o zoom da câmera do jogo
-- fica travado (distância mínima = máxima = distância atual). Ao sair do painel, volta ao normal.
------------------------------------------------------------
local ZoomLock = {locked = false, savedMin = nil, savedMax = nil}

local function setZoomLock(on)
	local lp = player
	if on and not ZoomLock.locked then
		local cam = workspace.CurrentCamera
		if not cam then return end
		local ok = pcall(function()
			ZoomLock.savedMin = lp.CameraMinZoomDistance
			ZoomLock.savedMax = lp.CameraMaxZoomDistance
			local cur = (cam.CFrame.Position - cam.Focus.Position).Magnitude
			lp.CameraMinZoomDistance = cur
			lp.CameraMaxZoomDistance = cur
		end)
		ZoomLock.locked = ok
	elseif not on and ZoomLock.locked then
		pcall(function()
			lp.CameraMinZoomDistance = ZoomLock.savedMin
			lp.CameraMaxZoomDistance = ZoomLock.savedMax
		end)
		ZoomLock.locked = false
	end
end

main.MouseEnter:Connect(function() setZoomLock(true) end)
main.MouseLeave:Connect(function() setZoomLock(false) end)

------------------------------------------------------------
-- Minimizar / Fechar / Entrada
------------------------------------------------------------
local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	if minimized then
		tw(main, 0.35, {Size = UDim2.fromOffset(W, 56)}, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
		task.delay(0.36, function()
			if minimized then
				pages[Pager.current].Visible = false
				headerFill.Visible = false
			end
		end)
	else
		pages[Pager.current].Visible = true
		headerFill.Visible = true
		tw(main, 0.4, {Size = UDim2.fromOffset(W, H)}, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	closing = true
	tw(mainScale, 0.3, {Scale = 0.8 * fit}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	tw(content, 0.3, {GroupTransparency = 1})
	tw(main, 0.3, {BackgroundTransparency = 1})
	tw(mainStroke, 0.3, {Transparency = 1})
	task.delay(0.32, function() gui:Destroy() end)
end)

tw(content, 0.35, {GroupTransparency = 0})
tw(main, 0.35, {BackgroundTransparency = 0})
tw(mainStroke, 0.35, {Transparency = 0.15})
tw(mainScale, 0.5, {Scale = fit}, Enum.EasingStyle.Back)

playEntrance(cardList)
