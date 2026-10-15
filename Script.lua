-- LocalScript: put in StarterPlayer > StarterPlayerScripts
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ====== THEME (solid colors, no glow) ======
local ACCENT = Color3.fromRGB(0, 229, 255)
local FRAME_COL = Color3.fromRGB(18, 21, 38)
local KEY_COL = Color3.fromRGB(58, 66, 100)
local KEY_ON = Color3.fromRGB(100, 112, 160)
local PRESSED = Color3.fromRGB(32, 37, 60)
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 214, 102)
local RED = Color3.fromRGB(210, 60, 70)
local FONT = Enum.Font.GothamBold

local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = o
	return c
end

local function stroke(o, col, th)
	local s = Instance.new("UIStroke")
	s.Color = col
	s.Thickness = th
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = o
	return s
end

local function tween(o, t, props)
	TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- ====== WAIT FOR A REAL SCREEN SIZE ======
local cam = workspace.CurrentCamera
local tries = 0
while cam.ViewportSize.X < 200 and tries < 100 do
	task.wait(0.05)
	tries += 1
end
local viewport = cam.ViewportSize
if viewport.X < 200 then
	viewport = Vector2.new(800, 400)
end

-- ====== LAYOUT ======
local W = math.min(viewport.X - 16, 520)
local PAD, GAP, KEY_H = 8, 3, 32
local KEY_W = (W - 2 * PAD - 9 * GAP) / 10
local TITLE_H, ROWS_Y = 26, 30
local ROW_COUNT = 6
local H = ROWS_Y + ROW_COUNT * (KEY_H + GAP) + 4
local SMALL = 48
local XSIZE = 16
local DEFAULT_TITLE = "NEON KEYS  ::  drag me"

local gui = Instance.new("ScreenGui")
gui.Name = "VirtualKeyboard"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Other LocalScripts in YOUR game can listen with:
--   game.Players.LocalPlayer.PlayerGui:WaitForChild("VirtualKeyboard"):WaitForChild("KeyEvent").Event:Connect(function(key, isDown) end)
local keyEvent = Instance.new("BindableEvent")
keyEvent.Name = "KeyEvent"
keyEvent.Parent = gui

-- ====== MAIN FRAME ======
local shownPos = UDim2.new(0.5, 0, 1, -H - 14)
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Size = UDim2.fromOffset(W, H)
frame.Position = UDim2.new(0.5, 0, 1, 30)
frame.BackgroundColor3 = FRAME_COL
frame.BackgroundTransparency = 0
frame.Visible = false
frame.ZIndex = 5
frame.Parent = gui
corner(frame, 14)
stroke(frame, ACCENT, 2)

-- title bar (drag handle)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
titleBar.BackgroundTransparency = 1
titleBar.ZIndex = 6
titleBar.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 1, 0)
title.Position = UDim2.fromOffset(12, 0)
title.BackgroundTransparency = 1
title.Text = DEFAULT_TITLE
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = ACCENT
title.Font = FONT
title.TextSize = 13
title.ZIndex = 7
title.Parent = titleBar

local grip = Instance.new("Frame")
grip.Size = UDim2.fromOffset(40, 4)
grip.Position = UDim2.new(0.5, -20, 0, 8)
grip.BackgroundColor3 = Color3.fromRGB(90, 100, 140)
grip.ZIndex = 7
grip.Parent = titleBar
corner(grip, 2)

-- ====== STATE ======
local held = { W = false, A = false, S = false, D = false, SPACE = false }
local pendingAdd = false
local deleteMode = false
local smalls = {}
local destroyers = {} -- [button] = function that removes that small key
local plusButton, delButton -- set below

-- modifier keys (tap to latch on/off)
local MOD = {
	LSHIFT = "shift", LCTRL = "ctrl", LALT = "alt",
}
local mods = { shift = false, ctrl = false, alt = false }
local modButtons = { shift = {}, ctrl = {}, alt = {} } -- main AND small buttons

local function setMod(name, on)
	mods[name] = on
	for _, b in ipairs(modButtons[name]) do
		b.TextColor3 = on and GOLD or WHITE
		tween(b, 0.12, { BackgroundColor3 = on and KEY_ON or KEY_COL })
	end
	keyEvent:Fire(name:upper(), on)
end

local function setPending(on)
	pendingAdd = on
	if plusButton then
		plusButton.TextColor3 = on and GOLD or WHITE
		tween(plusButton, 0.12, { BackgroundColor3 = on and KEY_ON or KEY_COL })
	end
	title.Text = on and "TAP A KEY TO ADD" or DEFAULT_TITLE
	title.TextColor3 = on and GOLD or ACCENT
end

local function setDeleteMode(on)
	deleteMode = on
	if delButton then
		delButton.TextColor3 = on and GOLD or WHITE
		tween(delButton, 0.12, { BackgroundColor3 = on and KEY_ON or KEY_COL })
	end
	title.Text = on and "TAP A SMALL KEY TO DELETE" or DEFAULT_TITLE
	title.TextColor3 = on and GOLD or ACCENT
end

local function pressKey(key, state)
	if held[key] ~= nil then
		held[key] = state
	end
	keyEvent:Fire(key, state)
end

local function clearSmalls()
	local list = {}
	for _, fn in pairs(destroyers) do
		table.insert(list, fn)
	end
	for _, fn in ipairs(list) do
		fn()
	end
end

local createSmall -- forward declaration

-- ====== INPUT HELPERS ======
local function isPress(input)
	return input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseMovement
end

-- is this input the same finger / mouse button that started the press?
local function sameFinger(active, input)
	if not active then return false end
	if input == active then return true end
	if active.UserInputType == Enum.UserInputType.MouseButton1 then
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseMovement
	end
	return false
end

local function styleKey(btn, textSize)
	btn.BackgroundColor3 = KEY_COL
	btn.BackgroundTransparency = 0
	btn.TextColor3 = WHITE
	btn.Font = FONT
	btn.TextSize = textSize or 14
	btn.AutoButtonColor = false
	corner(btn, 7)
	stroke(btn, Color3.fromRGB(80, 92, 135), 1)
	local sc = Instance.new("UIScale")
	sc.Parent = btn
	return sc
end

-- simple press feedback: shrink + darken (no glow)
local function pressFx(btn, sc, down)
	tween(sc, 0.08, { Scale = down and 0.92 or 1 })
	tween(btn, 0.1, { BackgroundColor3 = down and PRESSED or KEY_COL })
end

-- ====== MAIN KEYS ======
local function makeKey(id, text, x, y, w)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(w, KEY_H)
	btn.Position = UDim2.fromOffset(x, y)
	btn.Text = text
	btn.ZIndex = 6
	btn.Parent = frame
	local sc = styleKey(btn, #text > 2 and 11 or 14)

	local modName = MOD[id]
	if modName then
		table.insert(modButtons[modName], btn)
	end

	local pressed = false

	btn.InputBegan:Connect(function(input)
		if not isPress(input) then return end

		-- "+" toggles add mode
		if id == "+" then
			tween(sc, 0.08, { Scale = 0.92 })
			if not pendingAdd then
				setDeleteMode(false)
			end
			setPending(not pendingAdd)
			return
		end

		-- DEL toggles delete mode
		if id == "DEL" then
			tween(sc, 0.08, { Scale = 0.92 })
			if not deleteMode then
				setPending(false)
			end
			setDeleteMode(not deleteMode)
			return
		end

		-- CLR removes every small key
		if id == "CLR" then
			tween(sc, 0.08, { Scale = 0.92 })
			setPending(false)
			setDeleteMode(false)
			clearSmalls()
			return
		end

		-- add mode: this key (including Shift/Ctrl/Alt) becomes a small on-screen button
		if pendingAdd then
			setPending(false)
			createSmall(id, text, modName)
			return
		end

		if modName then
			tween(sc, 0.08, { Scale = 0.92 })
			setMod(modName, not mods[modName])
			return
		end

		pressed = true
		pressFx(btn, sc, true)
		pressKey(id, true)
	end)

	btn.InputEnded:Connect(function(input)
		if not isPress(input) then return end
		tween(sc, 0.08, { Scale = 1 })
		if pressed then
			pressed = false
			pressKey(id, false)
			tween(btn, 0.1, { BackgroundColor3 = KEY_COL })
		end
	end)
	return btn
end

-- each entry: { id, width in key-units, display text }
local rows = {
	{ {"1",1},{"2",1},{"3",1},{"4",1},{"5",1},{"6",1},{"7",1},{"8",1},{"9",1},{"0",1} },
	{ {"Q",1},{"W",1},{"E",1},{"R",1},{"T",1},{"Y",1},{"U",1},{"I",1},{"O",1},{"P",1} },
	{ {"A",1},{"S",1},{"D",1},{"F",1},{"G",1},{"H",1},{"J",1},{"K",1},{"L",1},{"ENTER",1,"ENTER"} },
	{ {"LSHIFT",1.5,"SHIFT"},{"Z",1},{"X",1},{"C",1},{"V",1},{"B",1},{"N",1},{"M",1},{"BACKSPACE",1.5,"BKSP"} },
	{ {"ESC",1,"ESC"},{"TAB",1,"TAB"},{"LCTRL",1.5,"CTRL"},{"LALT",1.5,"ALT"},{"SPACE",2,"SPACE"},{"+",1},{"DEL",1,"DEL"},{"CLR",1,"CLR"} },
	{ {"LEFT",1,"<"},{"UP",1,"^"},{"DOWN",1,"v"},{"RIGHT",1,">"},{",",1},{".",1},{"/",1},{";",1},{"-",1},{"=",1} },
}

for r, row in ipairs(rows) do
	local total = -GAP
	for _, k in ipairs(row) do
		total += KEY_W * k[2] + (k[2] - 1) * GAP + GAP
	end
	local x = (W - total) / 2
	local y = ROWS_Y + (r - 1) * (KEY_H + GAP)
	for _, k in ipairs(row) do
		local w = KEY_W * k[2] + (k[2] - 1) * GAP
		local btn = makeKey(k[1], k[3] or k[1], x, y, w)
		if k[1] == "+" then
			plusButton = btn
		elseif k[1] == "DEL" then
			delButton = btn
		end
		x += w + GAP
	end
end

-- ====== SMALL KEYS (generated ON THE SCREEN, outside the keyboard) ======
createSmall = function(id, text, modName)
	if #smalls >= 8 then
		title.Text = "MAX 8 SMALL KEYS"
		task.delay(1.5, function()
			if not pendingAdd and not deleteMode then title.Text = DEFAULT_TITLE end
		end)
		return
	end

	local screen = gui.AbsoluteSize
	if screen.X < 100 then screen = viewport end

	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(SMALL, SMALL)
	local startX = math.clamp(60 + #smalls * (SMALL + 8), 0, screen.X - SMALL)
	b.Position = UDim2.fromOffset(startX, screen.Y * 0.3)
	b.Text = id == "SPACE" and "_" or text
	b.ZIndex = 15
	b.Parent = gui -- on the screen, not inside the keyboard
	local sc = styleKey(b, #b.Text > 2 and 12 or 20)
	corner(b, SMALL / 2) -- round
	stroke(b, ACCENT, 2)
	table.insert(smalls, b)

	-- small red X in the top-right corner: tap it to delete this key
	local xBtn = Instance.new("TextButton")
	xBtn.Size = UDim2.fromOffset(XSIZE, XSIZE)
	xBtn.Text = "X"
	xBtn.Font = FONT
	xBtn.TextSize = 9
	xBtn.TextColor3 = WHITE
	xBtn.BackgroundColor3 = RED
	xBtn.AutoButtonColor = false
	xBtn.ZIndex = 16
	xBtn.Parent = gui
	corner(xBtn, XSIZE / 2)

	local function placeX()
		xBtn.Position = UDim2.fromOffset(
			b.Position.X.Offset + SMALL - 10,
			b.Position.Y.Offset - 6
		)
	end
	placeX()

	-- one size animation at a time: a new one always cancels the old one
	local scaleTween
	local function setScale(v, t)
		if scaleTween then scaleTween:Cancel() end
		scaleTween = TweenService:Create(sc,
			TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = v })
		scaleTween:Play()
	end

	-- small modifier keys share the latch state with the main ones
	if modName then
		table.insert(modButtons[modName], b)
		if mods[modName] then
			b.TextColor3 = GOLD
			b.BackgroundColor3 = KEY_ON
		end
	end

	local down, moved, removed = false, false, false
	local activeInput, dragStart, startPos
	local conns = {}

	local function destroyKey()
		if removed then return end
		removed = true
		if down and not modName then
			pressKey(id, false)
		end
		down = false
		activeInput = nil
		for _, c in ipairs(conns) do c:Disconnect() end
		destroyers[b] = nil
		local i = table.find(smalls, b)
		if i then table.remove(smalls, i) end
		if modName then
			local j = table.find(modButtons[modName], b)
			if j then table.remove(modButtons[modName], j) end
		end
		xBtn:Destroy()
		setScale(0, 0.15)
		task.delay(0.16, function() b:Destroy() end)
	end
	destroyers[b] = destroyKey

	xBtn.InputBegan:Connect(function(input)
		if isPress(input) then
			destroyKey()
		end
	end)

	-- finish a press; safe to call more than once
	local function finishPress()
		if not down or removed then return end
		down = false
		activeInput = nil
		setScale(1, 0.08)
		if modName then
			if not moved then
				setMod(modName, not mods[modName])
			end
		else
			tween(b, 0.1, { BackgroundColor3 = KEY_COL })
			pressKey(id, false)
		end
	end

	-- only follow the finger that touched THIS button
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if not down or not sameFinger(activeInput, input) or not isMove(input) then return end
		local d = input.Position - dragStart
		if d.Magnitude > 8 then moved = true end
		if moved then
			local s = gui.AbsoluteSize
			local nx = math.clamp(startPos.X.Offset + d.X, 0, s.X - SMALL)
			local ny = math.clamp(startPos.Y.Offset + d.Y, 0, s.Y - SMALL)
			b.Position = UDim2.fromOffset(nx, ny)
			placeX()
		end
	end))

	b.InputBegan:Connect(function(input)
		if not isPress(input) or removed then return end

		-- delete mode: tapping removes this key, then delete mode switches off
		if deleteMode then
			destroyKey()
			setDeleteMode(false)
			return
		end

		-- recover if a previous press never finished
		if down then finishPress() end

		down, moved = true, false
		activeInput = input
		dragStart = input.Position
		startPos = b.Position

		setScale(0.92, 0.08)
		if not modName then
			tween(b, 0.1, { BackgroundColor3 = PRESSED })
			pressKey(id, true)
		end
	end)

	-- release is detected two ways so a press can never get stuck
	b.InputEnded:Connect(function(input)
		if isPress(input) then
			finishPress()
		end
	end)
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if not down then return end
		if input == activeInput
			or (activeInput and activeInput.UserInputType == Enum.UserInputType.MouseButton1
				and input.UserInputType == Enum.UserInputType.MouseButton1) then
			finishPress()
		end
	end))

	-- pop-in animation
	sc.Scale = 0
	setScale(1, 0.2)
end

-- ====== DRAG THE KEYBOARD ======
do
	local dragging, activeInput, dragStart, startPos = false, nil, nil, nil
	titleBar.InputBegan:Connect(function(input)
		if isPress(input) and not dragging then
			dragging = true
			activeInput = input
			dragStart = input.Position
			startPos = frame.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and isMove(input) and sameFinger(activeInput, input) then
			local d = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y
			)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input == activeInput
			or (activeInput.UserInputType == Enum.UserInputType.MouseButton1
				and input.UserInputType == Enum.UserInputType.MouseButton1)) then
			dragging = false
			activeInput = nil
			shownPos = frame.Position
		end
	end)
end

-- ====== TOGGLE BUTTON ======
local toggle = Instance.new("TextButton")
toggle.Size = UDim2.fromOffset(46, 46)
toggle.Position = UDim2.new(1, -60, 1, -60)
toggle.Text = "KB"
toggle.BackgroundColor3 = KEY_COL
toggle.TextColor3 = WHITE
toggle.Font = FONT
toggle.TextSize = 16
toggle.AutoButtonColor = false
toggle.ZIndex = 20
toggle.Parent = gui
corner(toggle, 23)
stroke(toggle, ACCENT, 2)

local open = false
toggle.Activated:Connect(function()
	open = not open
	if open then
		frame.Visible = true
		frame.Position = UDim2.new(shownPos.X.Scale, shownPos.X.Offset, 1, 30)
		TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = shownPos }):Play()
	else
		-- closing the keyboard cancels add/delete mode so nothing gets left on
		setPending(false)
		setDeleteMode(false)
		shownPos = frame.Position
		TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(shownPos.X.Scale, shownPos.X.Offset, 1, 30) }):Play()
		task.delay(0.21, function()
			if not open then frame.Visible = false end
		end)
	end
end)

-- ====== WASD MOVEMENT, SPACE JUMP, AND VEHICLE DRIVING ======
local wasDriving = false

RunService.RenderStepped:Connect(function()
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local seat = humanoid.SeatPart

	-- sitting in a standard Roblox VehicleSeat: W/S = throttle, A/D = steer
	if seat and seat:IsA("VehicleSeat") then
		local throttle = (held.W and 1 or 0) - (held.S and 1 or 0)
		local steer = (held.D and 1 or 0) - (held.A and 1 or 0)
		if throttle ~= 0 or steer ~= 0 then
			seat.ThrottleFloat = throttle
			seat.SteerFloat = steer
			wasDriving = true
		elseif wasDriving then
			seat.ThrottleFloat = 0
			seat.SteerFloat = 0
			wasDriving = false
		end
		if held.SPACE then
			humanoid.Jump = true -- jump out of the seat
		end
		return
	end
	wasDriving = false

	if held.SPACE then
		humanoid.Jump = true
	end

	if not (held.W or held.A or held.S or held.D) then return end
	local x = (held.D and 1 or 0) - (held.A and 1 or 0)
	local z = (held.S and 1 or 0) - (held.W and 1 or 0)
	local dir = Vector3.new(x, 0, z)
	if dir.Magnitude > 0 then
		humanoid:Move(dir.Unit, true)
	end
end)
