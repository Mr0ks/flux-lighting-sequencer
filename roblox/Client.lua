local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local root = script.Parent
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("FluxlineSequencer")
local Icon = require(root:WaitForChild("TopbarPlus"):WaitForChild("Icon"))
local localSound = Instance.new("Sound")
localSound.Name = "FluxlineLocalShowAudio"
localSound.Looped = false
localSound.Parent = SoundService
local audioRequestId = nil
local pendingStart = nil
local audioGeneration = 0

local function syncLocalAudio(data)
	if not data or not data.songId then return end
	audioGeneration += 1
	local generation = audioGeneration
	task.spawn(function()
		while generation == audioGeneration and workspace:GetServerTimeNow() < data.started do
			task.wait()
		end
		if generation ~= audioGeneration then return end
		localSound.TimePosition = math.max(0, workspace:GetServerTimeNow() - data.started)
		localSound:Play()
	end)
end

local COLORS = {
	background = Color3.fromRGB(13, 13, 13),
	surface = Color3.fromRGB(25, 25, 25),
	surfaceHigh = Color3.fromRGB(35, 35, 35),
	line = Color3.fromRGB(57, 57, 57),
	text = Color3.fromRGB(245, 245, 245),
	muted = Color3.fromRGB(166, 166, 166),
	white = Color3.fromRGB(255, 255, 255),
	black = Color3.fromRGB(8, 8, 8),
	success = Color3.fromRGB(186, 255, 199),
}

local function create(className, properties, parent)
	local object = Instance.new(className)
	for property, value in properties do
		object[property] = value
	end
	object.Parent = parent
	return object
end

local function round(object, radius)
	create("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, object)
end

local function outline(object, color)
	create("UIStroke", {
		Color = color or COLORS.line,
		Thickness = 1,
		Transparency = 0,
	}, object)
end

local gui = create("ScreenGui", {
	Name = "FluxlineShowsGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	Enabled = false,
	DisplayOrder = 50,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

local shadow = create("Frame", {
	Name = "Shadow",
	Size = UDim2.new(1, -24, 1, -48),
	Position = UDim2.new(0.5, 5, 0.5, 9),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.new(),
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
}, gui)
round(shadow, 25)
create("UISizeConstraint", {
	MinSize = Vector2.new(300, 300),
	MaxSize = Vector2.new(412, 384),
}, shadow)

local panel = create("Frame", {
	Name = "Panel",
	Size = UDim2.new(1, -24, 1, -48),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = COLORS.background,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, gui)
round(panel, 24)
outline(panel, Color3.fromRGB(71, 71, 71))
create("UISizeConstraint", {
	MinSize = Vector2.new(300, 300),
	MaxSize = Vector2.new(412, 384),
}, panel)

local header = create("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 66),
	BackgroundTransparency = 1,
	Active = true,
}, panel)

local mark = create("Frame", {
	Size = UDim2.fromOffset(36, 36),
	Position = UDim2.fromOffset(16, 15),
	BackgroundColor3 = COLORS.white,
	BorderSizePixel = 0,
}, header)
round(mark, 12)
create("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "F",
	TextColor3 = COLORS.black,
	Font = Enum.Font.GothamBlack,
	TextSize = 17,
}, mark)

local eyebrow = create("TextLabel", {
	Size = UDim2.fromOffset(205, 18),
	Position = UDim2.fromOffset(62, 13),
	BackgroundTransparency = 1,
	Text = "FLUX SEQUENCER",
	TextColor3 = COLORS.muted,
	Font = Enum.Font.GothamBold,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local title = create("TextLabel", {
	Size = UDim2.fromOffset(205, 25),
	Position = UDim2.fromOffset(62, 29),
	BackgroundTransparency = 1,
	Text = "Shows",
	TextColor3 = COLORS.text,
	Font = Enum.Font.GothamBold,
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local statusPill = create("Frame", {
	Size = UDim2.fromOffset(78, 28),
	Position = UDim2.new(1, -122, 0, 19),
	BackgroundColor3 = Color3.fromRGB(24, 42, 29),
	BorderSizePixel = 0,
}, header)
round(statusPill, 14)
local statusDot = create("Frame", {
	Size = UDim2.fromOffset(7, 7),
	Position = UDim2.fromOffset(11, 11),
	BackgroundColor3 = COLORS.success,
	BorderSizePixel = 0,
}, statusPill)
round(statusDot, 4)
local statusText = create("TextLabel", {
	Size = UDim2.new(1, -25, 1, 0),
	Position = UDim2.fromOffset(24, 0),
	BackgroundTransparency = 1,
	Text = "READY",
	TextColor3 = COLORS.success,
	Font = Enum.Font.GothamBold,
	TextSize = 9,
	TextXAlignment = Enum.TextXAlignment.Left,
}, statusPill)

local closeButton = create("TextButton", {
	Size = UDim2.fromOffset(30, 30),
	Position = UDim2.new(1, -38, 0, 18),
	BackgroundColor3 = COLORS.surface,
	BorderSizePixel = 0,
	Text = "×",
	TextColor3 = COLORS.text,
	Font = Enum.Font.GothamMedium,
	TextSize = 19,
	AutoButtonColor = false,
}, header)
round(closeButton, 15)
outline(closeButton)

local tabRail = create("Frame", {
	Size = UDim2.new(1, -32, 0, 40),
	Position = UDim2.fromOffset(16, 68),
	BackgroundColor3 = COLORS.surface,
	BorderSizePixel = 0,
}, panel)
round(tabRail, 14)
outline(tabRail)

local tabShows = create("TextButton", {
	Size = UDim2.new(0.5, -3, 1, -6),
	Position = UDim2.fromOffset(3, 3),
	BackgroundColor3 = COLORS.white,
	BorderSizePixel = 0,
	Text = "SHOWS",
	TextColor3 = COLORS.black,
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	AutoButtonColor = false,
}, tabRail)
round(tabShows, 11)

local tabExport = create("TextButton", {
	Size = UDim2.new(0.5, -3, 1, -6),
	Position = UDim2.new(0.5, 0, 0, 3),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "DATASTORE",
	TextColor3 = COLORS.muted,
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	AutoButtonColor = false,
}, tabRail)
round(tabExport, 11)

local showsPage = create("Frame", {
	Size = UDim2.new(1, -32, 1, -126),
	Position = UDim2.fromOffset(16, 116),
	BackgroundTransparency = 1,
}, panel)

local list = create("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, -48),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = Color3.fromRGB(120, 120, 120),
	ScrollBarImageTransparency = 0.2,
}, showsPage)
local layout = create("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, list)

local stop = create("TextButton", {
	Size = UDim2.new(1, 0, 0, 40),
	Position = UDim2.new(0, 0, 1, -40),
	BackgroundColor3 = COLORS.surface,
	BorderSizePixel = 0,
	Text = "■  STOP SHOW",
	TextColor3 = COLORS.text,
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	AutoButtonColor = false,
}, showsPage)
round(stop, 13)
outline(stop)

local exportPage = create("Frame", {
	Size = showsPage.Size,
	Position = showsPage.Position,
	BackgroundTransparency = 1,
	Visible = false,
}, panel)

local help = create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundTransparency = 1,
	Text = "Export the Flux setup, then copy this read-only JSON into the website.",
	TextWrapped = true,
	TextColor3 = COLORS.muted,
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, exportPage)

local jsonBox = create("TextBox", {
	Size = UDim2.new(1, 0, 1, -86),
	Position = UDim2.fromOffset(0, 38),
	BackgroundColor3 = COLORS.surface,
	BorderSizePixel = 0,
	TextColor3 = COLORS.text,
	PlaceholderColor3 = COLORS.muted,
	ClearTextOnFocus = false,
	MultiLine = true,
	TextEditable = false,
	Text = "Your Flux DataStore export will appear here.",
	Font = Enum.Font.Code,
	TextSize = 11,
	TextWrapped = false,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, exportPage)
round(jsonBox, 14)
outline(jsonBox)
create("UIPadding", {
	PaddingTop = UDim.new(0, 12),
	PaddingBottom = UDim.new(0, 12),
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
}, jsonBox)

local exportButton = create("TextButton", {
	Size = UDim2.new(1, 0, 0, 40),
	Position = UDim2.new(0, 0, 1, -40),
	BackgroundColor3 = COLORS.white,
	BorderSizePixel = 0,
	Text = "EXPORT FLUX DATASTORE",
	TextColor3 = COLORS.black,
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	AutoButtonColor = false,
}, exportPage)
round(exportButton, 13)

local dragging = false
local dragStart
local panelStart
local function clampPanelPosition(position)
	local camera = workspace.CurrentCamera
	if not camera then return position end
	local viewport = camera.ViewportSize
	local half = panel.AbsoluteSize / 2
	local x = position.X.Scale * viewport.X + position.X.Offset
	local y = position.Y.Scale * viewport.Y + position.Y.Offset
	local minX, minY = math.min(viewport.X / 2, half.X + 8), math.min(viewport.Y / 2, half.Y + 8)
	local maxX, maxY = math.max(minX, viewport.X - half.X - 8), math.max(minY, viewport.Y - half.Y - 8)
	x = math.clamp(x, minX, maxX)
	y = math.clamp(y, minY, maxY)
	return UDim2.fromOffset(x, y)
end

header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		panelStart = panel.Position
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		panel.Position = clampPanelPosition(UDim2.new(panelStart.X.Scale, panelStart.X.Offset + delta.X, panelStart.Y.Scale, panelStart.Y.Offset + delta.Y))
		shadow.Position = UDim2.new(panel.Position.X.Scale, panel.Position.X.Offset + 5, panel.Position.Y.Scale, panel.Position.Y.Offset + 9)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

local icon = Icon.new()
	:setName("FluxlineShows")
	:setLabel("Flux Shows")
	:setCaption("Open Flux shows and DataStore exporter")
icon:setEnabled(false)

local function setStatus(text, playing)
	statusText.Text = text
	statusPill.BackgroundColor3 = playing and Color3.fromRGB(48, 48, 48) or Color3.fromRGB(24, 42, 29)
	statusText.TextColor3 = playing and COLORS.text or COLORS.success
	statusDot.BackgroundColor3 = playing and COLORS.white or COLORS.success
end

local function selectPage(exporting)
	showsPage.Visible = not exporting
	exportPage.Visible = exporting
	tabShows.BackgroundTransparency = exporting and 1 or 0
	tabShows.BackgroundColor3 = COLORS.white
	tabShows.TextColor3 = exporting and COLORS.muted or COLORS.black
	tabExport.BackgroundTransparency = exporting and 0 or 1
	tabExport.BackgroundColor3 = COLORS.white
	tabExport.TextColor3 = exporting and COLORS.black or COLORS.muted
	title.Text = exporting and "DataStore export" or "Shows"
end

local function render(shows)
	for _, child in list:GetChildren() do
		if child ~= layout then child:Destroy() end
	end
	for order, show in shows do
		local button = create("TextButton", {
			LayoutOrder = order,
			Size = UDim2.new(1, -5, 0, 60),
			BackgroundColor3 = COLORS.surface,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
		}, list)
		round(button, 15)
		outline(button)
		create("TextLabel", {
			Size = UDim2.new(1, -86, 0, 22),
			Position = UDim2.fromOffset(14, 9),
			BackgroundTransparency = 1,
			Text = tostring(show.name),
			TextColor3 = COLORS.text,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, button)
		create("TextLabel", {
			Size = UDim2.new(1, -86, 0, 18),
			Position = UDim2.fromOffset(14, 32),
			BackgroundTransparency = 1,
			Text = ("%ds  ·  %s BPM"):format(show.duration or 0, show.bpm or 0),
			TextColor3 = COLORS.muted,
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, button)
		local playChip = create("TextLabel", {
			Size = UDim2.fromOffset(54, 32),
			Position = UDim2.new(1, -66, 0.5, -16),
			BackgroundColor3 = COLORS.white,
			BorderSizePixel = 0,
			Text = "PLAY",
			TextColor3 = COLORS.black,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
		}, button)
		round(playChip, 12)
		button.MouseEnter:Connect(function() button.BackgroundColor3 = COLORS.surfaceHigh end)
		button.MouseLeave:Connect(function() button.BackgroundColor3 = COLORS.surface end)
		button.Activated:Connect(function()
			setStatus("LOADING", true)
			remote:FireServer("play", show.id)
		end)
	end
end

icon.selected:Connect(function()
	gui.Enabled = true
	remote:FireServer("list")
end)
icon.deselected:Connect(function() gui.Enabled = false end)
closeButton.Activated:Connect(function()
	gui.Enabled = false
	icon:deselect()
end)
tabShows.Activated:Connect(function() selectPage(false) end)
tabExport.Activated:Connect(function() selectPage(true) end)
stop.Activated:Connect(function() remote:FireServer("stop") end)
exportButton.Activated:Connect(function()
	exportButton.Text = "EXPORTING…"
	exportButton.Active = false
	remote:FireServer("export")
end)

remote.OnClientEvent:Connect(function(action, data)
	if action == "authorized" then
		icon:setEnabled(true)
	elseif action == "shows" then
		icon:setEnabled(true)
		render(data)
	elseif action == "prepareAudio" then
		title.Text = data.name or "Loading"
		eyebrow.Text = "PREPARING AUDIO"
		setStatus("LOADING", true)
		audioGeneration += 1
		audioRequestId = data.requestId
		pendingStart = nil
		localSound:Stop()
		localSound.SoundId = "rbxassetid://" .. tostring(data.songId)
		localSound.TimePosition = 0
		task.spawn(function()
			local requestId = data.requestId
			local ok, message = pcall(function()
				ContentProvider:PreloadAsync({ localSound })
			end)
			if not ok then warn("Fluxline client audio preload failed:", message) end
			if audioRequestId ~= requestId then return end
			remote:FireServer("audioReady", requestId)
			if pendingStart and pendingStart.requestId == requestId then syncLocalAudio(pendingStart) end
		end)
	elseif action == "playing" then
		title.Text = data.name or "Playing"
		eyebrow.Text = "NOW PLAYING"
		setStatus("PLAYING", true)
		pendingStart = data
		if data.songId then syncLocalAudio(data) end
	elseif action == "stopped" then
		audioGeneration += 1
		audioRequestId = nil
		pendingStart = nil
		localSound:Stop()
		localSound.TimePosition = 0
		title.Text = "Shows"
		eyebrow.Text = "FLUX SEQUENCER"
		setStatus("READY", false)
	elseif action == "exportResult" then
		exportButton.Active = true
		exportButton.Text = "EXPORT FLUX DATASTORE"
		if data.ok then
			jsonBox.Text = data.json
			title.Text = "Export ready"
		else
			jsonBox.Text = "Export failed: " .. tostring(data.error)
			title.Text = "Export failed"
		end
	end
end)

task.delay(1, function() remote:FireServer("list") end)
