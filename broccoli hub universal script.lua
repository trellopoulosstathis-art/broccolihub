local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TOGGLE_KEY = Enum.KeyCode.Tab
local PANEL_NAME = "Broccoli Universal FE v1.0.1"

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

------------------------------------------------------------
-- State
------------------------------------------------------------
local settings = { speed = nil, jump = nil }
local espEnabled = false
local distanceEnabled = false
local autoLock = false
local selectedTarget = nil
local highlights = {}
local labels = {}
local flying, flySpeed = false, 50
local noclip, infJump = false, false
local clickTP = false
local flyBV, flyBG

local ESP_FILL = Color3.fromRGB(40, 140, 255)
local ESP_OUTLINE = Color3.fromRGB(160, 220, 255)
local DIST_COLOR = Color3.fromRGB(80, 170, 255)

local function getChar() return player.Character end
local function getHum()
	local c = getChar()
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
	local c = getChar()
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function getCharacterParts(target)
	local character = target.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then return end
	return character, root
end

------------------------------------------------------------
-- Camera controller (for autolock)
------------------------------------------------------------
local cameraController

local function findController()
	local playerScripts = player:FindFirstChild("PlayerScripts") or player:WaitForChild("PlayerScripts", 5)
	if not playerScripts then return nil end
	local controllers = playerScripts:FindFirstChild("Controllers")
	if not controllers then return nil end
	local module = controllers:FindFirstChild("CameraController")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then return result end
	end
	return nil
end

cameraController = findController()

------------------------------------------------------------
-- UI
------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = PANEL_NAME
gui.ResetOnSpawn = false
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 400, 0, 340)
main.Position = UDim2.new(0.5, -200, 0.5, -170)
main.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
main.BorderSizePixel = 0
main.Visible = false
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
title.BorderSizePixel = 0
title.Text = "  " .. PANEL_NAME .. "  (Tab to toggle)"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = main
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

local input = Instance.new("TextBox")
input.Size = UDim2.new(1, -20, 0, 30)
input.Position = UDim2.new(0, 10, 0, 40)
input.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
input.TextColor3 = Color3.new(1, 1, 1)
input.PlaceholderText = "Type a command and press Enter (e.g. speed 50)"
input.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
input.Font = Enum.Font.Code
input.TextSize = 15
input.TextXAlignment = Enum.TextXAlignment.Left
input.ClearTextOnFocus = false
input.Text = ""
input.Parent = main
Instance.new("UICorner", input).CornerRadius = UDim.new(0, 6)
Instance.new("UIPadding", input).PaddingLeft = UDim.new(0, 8)

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -20, 1, -125)
list.Position = UDim2.new(0, 10, 0, 78)
list.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
list.BorderSizePixel = 0
list.ScrollBarThickness = 5
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = main
Instance.new("UICorner", list).CornerRadius = UDim.new(0, 6)

local layout = Instance.new("UIListLayout", list)
layout.Padding = UDim.new(0, 2)
layout.SortOrder = Enum.SortOrder.LayoutOrder

local listPad = Instance.new("UIPadding", list)
listPad.PaddingTop = UDim.new(0, 4)
listPad.PaddingLeft = UDim.new(0, 4)
listPad.PaddingRight = UDim.new(0, 4)

local output = Instance.new("TextLabel")
output.Size = UDim2.new(1, -20, 0, 30)
output.Position = UDim2.new(0, 10, 1, -38)
output.BackgroundTransparency = 1
output.TextColor3 = Color3.fromRGB(120, 220, 140)
output.TextXAlignment = Enum.TextXAlignment.Left
output.TextWrapped = true
output.Font = Enum.Font.Code
output.TextSize = 13
output.Text = ""
output.Parent = main

local function notify(msg)
	output.Text = msg
	task.delay(5, function()
		if output.Text == msg then output.Text = "" end
	end)
end

-- Dragging
do
	local dragging, dragStart, startPos
	title.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, i.Position, main.Position
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function findPlayer(query)
	if not query then return nil end
	query = query:lower()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():sub(1, #query) == query or p.DisplayName:lower():sub(1, #query) == query then
			return p
		end
	end
end

local function applyStats()
	local hum = getHum()
	if not hum then return end
	if settings.speed then hum.WalkSpeed = settings.speed end
	if settings.jump then
		hum.UseJumpPower = true
		hum.JumpPower = settings.jump
	end
end

local function getNearestPlayer()
	local myRoot = getRoot()
	if not myRoot then return nil end
	local nearest, shortest = nil, math.huge
	for _, target in ipairs(Players:GetPlayers()) do
		if target ~= player then
			local _, root = getCharacterParts(target)
			if root then
				local d = (myRoot.Position - root.Position).Magnitude
				if d < shortest then
					shortest = d
					nearest = target
				end
			end
		end
	end
	return nearest
end

------------------------------------------------------------
-- ESP + Distance
------------------------------------------------------------
local function clearESP(target)
	if highlights[target] then
		highlights[target]:Destroy()
		highlights[target] = nil
	end
	if labels[target] then
		labels[target]:Destroy()
		labels[target] = nil
	end
end

local function updateESP(target)
	local character, root = getCharacterParts(target)
	if not character then
		clearESP(target)
		return
	end

	if espEnabled and not highlights[target] then
		local highlight = Instance.new("Highlight")
		highlight.FillColor = ESP_FILL
		highlight.OutlineColor = ESP_OUTLINE
		highlight.FillTransparency = 0.55
		highlight.OutlineTransparency = 0.1
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Adornee = character
		highlight.Parent = character
		highlights[target] = highlight
	elseif espEnabled and highlights[target] then
		highlights[target].FillColor = ESP_FILL
		highlights[target].OutlineColor = ESP_OUTLINE
	end

	if not espEnabled and highlights[target] then
		highlights[target]:Destroy()
		highlights[target] = nil
	end

	if distanceEnabled and not labels[target] then
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(130, 28)
		billboard.StudsOffset = Vector3.new(0, 3.2, 0)
		billboard.AlwaysOnTop = true
		billboard.Adornee = root
		billboard.Parent = playerGui

		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextColor3 = DIST_COLOR
		text.TextStrokeTransparency = 0.3
		text.TextStrokeColor3 = Color3.fromRGB(0, 20, 50)
		text.Font = Enum.Font.GothamBold
		text.TextSize = 13
		text.Parent = billboard

		labels[target] = billboard
	end

	if not distanceEnabled and labels[target] then
		labels[target]:Destroy()
		labels[target] = nil
	end

	if labels[target] then
		local myRoot = getRoot()
		if myRoot then
			local distance = (myRoot.Position - root.Position).Magnitude
			labels[target].TextLabel.Text = math.floor(distance) .. " studs"
			labels[target].TextLabel.TextColor3 = DIST_COLOR
		end
	end
end

RunService.Heartbeat:Connect(function()
	for _, target in ipairs(Players:GetPlayers()) do
		if target ~= player then
			updateESP(target)
		end
	end
end)

Players.PlayerRemoving:Connect(function(target)
	clearESP(target)
	if selectedTarget == target then
		selectedTarget = nil
	end
end)

-- Fly
local function stopFly()
	flying = false
	if flyBV then flyBV:Destroy() flyBV = nil end
	if flyBG then flyBG:Destroy() flyBG = nil end
	local hum = getHum()
	if hum then hum.PlatformStand = false end
end

local function startFly()
	local root, hum = getRoot(), getHum()
	if not root or not hum then return end
	stopFly()
	flying = true
	hum.PlatformStand = true
	flyBV = Instance.new("BodyVelocity")
	flyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
	flyBV.Velocity = Vector3.zero
	flyBV.Parent = root
	flyBG = Instance.new("BodyGyro")
	flyBG.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
	flyBG.P = 9e4
	flyBG.CFrame = root.CFrame
	flyBG.Parent = root
end

RunService.RenderStepped:Connect(function()
	if not flying or not flyBV or not flyBG then return end
	if input:IsFocused() then
		flyBV.Velocity = Vector3.zero
		return
	end
	local cam = workspace.CurrentCamera
	local dir = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
	flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * flySpeed or Vector3.zero
	flyBG.CFrame = cam.CFrame
end)

-- Noclip
RunService.Stepped:Connect(function()
	if not noclip then return end
	local c = getChar()
	if not c then return end
	for _, part in ipairs(c:GetDescendants()) do
		if part:IsA("BasePart") then part.CanCollide = false end
	end
end)

-- Infinite jump
UserInputService.JumpRequest:Connect(function()
	if infJump then
		local hum = getHum()
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

-- Click teleport
local mouse = player:GetMouse()
UserInputService.InputBegan:Connect(function(inp, processed)
	if processed or not clickTP then return end
	if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	local root = getRoot()
	if root and mouse.Hit then
		root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
	end
end)

player.CharacterAdded:Connect(function()
	flying = false
	flyBV, flyBG = nil, nil
	task.wait(0.5)
	applyStats()
end)

------------------------------------------------------------
-- Autolock camera
------------------------------------------------------------
RunService:BindToRenderStep(
	"BroccoliUniversalAutoLock",
	Enum.RenderPriority.Camera.Value + 1,
	function()
		if not autoLock then return end
		if not cameraController then
			cameraController = findController()
			return
		end
		local target = selectedTarget or getNearestPlayer()
		if not target then return end
		local _, root = getCharacterParts(target)
		if not root then return end
		local camera = workspace.CurrentCamera
		if not camera then return end
		local direction = (root.Position - camera.CFrame.Position).Unit
		local pitch = math.asin(math.clamp(direction.Y, -1, 1))
		local yaw = math.atan2(-direction.X, -direction.Z)
		if cameraController.SetRotation then
			cameraController:SetRotation(Vector2.new(pitch, yaw))
		end
	end
)

------------------------------------------------------------
-- Commands
------------------------------------------------------------
local commandList = {}
local lookup = {}
local rows = {}

local function addCommand(name, usage, desc, fn)
	local entry = { name = name, usage = usage, desc = desc, fn = fn }
	table.insert(commandList, entry)
	lookup[name] = entry
end

addCommand("speed", "speed <number>", "Set your WalkSpeed", function(args)
	settings.speed = tonumber(args[1]) or 16
	applyStats()
	notify("WalkSpeed = " .. settings.speed)
end)

addCommand("jump", "jump <number>", "Set your JumpPower", function(args)
	settings.jump = tonumber(args[1]) or 50
	applyStats()
	notify("JumpPower = " .. settings.jump)
end)

addCommand("fly", "fly [speed]", "Fly with WASD, Space up, LeftCtrl down", function(args)
	flySpeed = tonumber(args[1]) or flySpeed
	startFly()
	notify("Fly on (speed " .. flySpeed .. ")")
end)

addCommand("unfly", "unfly", "Stop flying", function()
	stopFly()
	notify("Fly off")
end)

addCommand("noclip", "noclip", "Walk through walls", function()
	noclip = true
	notify("Noclip on")
end)

addCommand("clip", "clip", "Turn noclip off", function()
	noclip = false
	notify("Noclip off")
end)

addCommand("infjump", "infjump", "Toggle infinite jump", function()
	infJump = not infJump
	notify("Infinite jump " .. (infJump and "on" or "off"))
end)

addCommand("esp", "esp", "Blue ESP highlights through walls", function()
	espEnabled = true
	notify("ESP on")
end)

addCommand("unesp", "unesp", "Remove player highlights", function()
	espEnabled = false
	for p in pairs(highlights) do clearESP(p) end
	notify("ESP off")
end)

addCommand("distance", "distance", "Toggle distance labels over players", function()
	distanceEnabled = not distanceEnabled
	if not distanceEnabled then
		for p in pairs(labels) do
			if labels[p] then labels[p]:Destroy() labels[p] = nil end
		end
	end
	notify("Distance " .. (distanceEnabled and "on" or "off"))
end)

addCommand("undistance", "undistance", "Turn distance labels off", function()
	distanceEnabled = false
	for p in pairs(labels) do
		if labels[p] then labels[p]:Destroy() labels[p] = nil end
	end
	notify("Distance off")
end)

addCommand("autolock", "autolock [player]", "Lock camera on nearest or named player", function(args)
	if args[1] then
		local t = findPlayer(args[1])
		if not t then
			notify("Player not found")
			return
		end
		selectedTarget = t
		autoLock = true
		notify("Autolock on → " .. t.Name)
	else
		autoLock = not autoLock
		if autoLock and not selectedTarget then
			selectedTarget = getNearestPlayer()
		end
		if autoLock then
			notify("Autolock on → " .. (selectedTarget and selectedTarget.Name or "nearest"))
		else
			notify("Autolock off")
		end
	end
end)

addCommand("unautolock", "unautolock", "Stop camera lock", function()
	autoLock = false
	notify("Autolock off")
end)

addCommand("target", "target <player>", "Set autolock target (partial names work)", function(args)
	local t = findPlayer(args[1])
	if not t then
		notify("Player not found")
		return
	end
	selectedTarget = t
	notify("Target = " .. t.Name)
end)

addCommand("tp", "tp <player>", "Teleport to a player (partial names work)", function(args)
	local target = findPlayer(args[1])
	local root = getRoot()
	local tRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if root and tRoot then
		root.CFrame = tRoot.CFrame * CFrame.new(0, 0, 3)
		notify("Teleported to " .. target.Name)
	else
		notify("Player not found")
	end
end)

addCommand("clicktp", "clicktp", "Toggle click teleport", function()
	clickTP = not clickTP
	notify("Click teleport " .. (clickTP and "on" or "off"))
end)

addCommand("gravity", "gravity <number>", "Set workspace gravity (default 196.2)", function(args)
	workspace.Gravity = tonumber(args[1]) or 196.2
	notify("Gravity = " .. workspace.Gravity)
end)

addCommand("fov", "fov <number>", "Set camera field of view", function(args)
	workspace.CurrentCamera.FieldOfView = tonumber(args[1]) or 70
	notify("FOV = " .. workspace.CurrentCamera.FieldOfView)
end)

addCommand("reset", "reset", "Reset your character", function()
	local hum = getHum()
	if hum then hum.Health = 0 end
end)

------------------------------------------------------------
-- Build command list UI
------------------------------------------------------------
local function esc(s)
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

for i, entry in ipairs(commandList) do
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, -4, 0, 24)
	row.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
	row.BorderSizePixel = 0
	row.AutoButtonColor = true
	row.RichText = true
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Font = Enum.Font.Code
	row.TextSize = 13
	row.TextColor3 = Color3.new(1, 1, 1)
	row.Text = string.format(' <b>%s</b>  <font color="#8a8a96">%s</font>', esc(entry.usage), esc(entry.desc))
	row.LayoutOrder = i
	row.Parent = list
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
	rows[entry] = row
	row.MouseButton1Click:Connect(function()
		input.Text = entry.name .. " "
		input:CaptureFocus()
	end)
end

input:GetPropertyChangedSignal("Text"):Connect(function()
	local word = (input.Text:match("^%s*(%S*)") or ""):lower()
	for entry, row in pairs(rows) do
		row.Visible = word == "" or entry.name:find(word, 1, true) ~= nil
	end
end)

local function run(text)
	local args = (text:gsub("^%s+", "")):split(" ")
	local name = table.remove(args, 1)
	if not name or name == "" then return end
	local entry = lookup[name:lower()]
	if not entry then
		notify("Unknown command: " .. name)
		return
	end
	local ok, err = pcall(entry.fn, args)
	if not ok then notify("Error: " .. tostring(err)) end
end

input.FocusLost:Connect(function(enterPressed)
	if enterPressed and input.Text ~= "" then
		run(input.Text)
		input.Text = ""
	end
end)

UserInputService.InputBegan:Connect(function(key, processed)
	if key.KeyCode ~= TOGGLE_KEY then return end
	local focused = UserInputService:GetFocusedTextBox()
	if focused and focused ~= input then return end
	main.Visible = not main.Visible
	if main.Visible then
		task.defer(function()
			input.Text = ""
			input:CaptureFocus()
		end)
	else
		input:ReleaseFocus()
	end
end)

notify("Broccoli Universal FE v1.0.1 loaded. Tab to toggle.")
print("Broccoli Universal FE v1.0.1 loaded!")
