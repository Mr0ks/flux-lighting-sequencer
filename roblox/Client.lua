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
	if not data or not data.songId or pendingStart ~= data then return end
	pendingStart = nil
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
	background = Color3.fromRGB(11, 11, 12),
	surface = Color3.fromRGB(19, 19, 20),
	surfaceHigh = Color3.fromRGB(40, 40, 43),
	line = Color3.fromRGB(57, 57, 60),
	text = Color3.fromRGB(241, 241, 243),
	muted = Color3.fromRGB(170, 168, 175),
	white = Color3.fromRGB(255, 255, 255),
	black = Color3.fromRGB(8, 8, 8),
	success = Color3.fromRGB(213, 213, 218),
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
outline(panel)
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
	Font = Enum.Font.RobotoMono,
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
	BackgroundColor3 = Color3.fromRGB(29, 29, 31),
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
	statusPill.BackgroundColor3 = playing and Color3.fromRGB(40, 40, 43) or Color3.fromRGB(24, 42, 29)
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
			Font = Enum.Font.RobotoMono,
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

-- Uses Flux's own per-module update functions; never writes lamps, beams or motors directly.
local NativePlayback = {}
local nativeJobs = {}
local nativeKit, nativeShared
local nativeGeneration = 0
local nativeValues = setmetatable({}, {__mode="k"})

local function nativeContext(kitName)
	if nativeKit and nativeKit.Parent and nativeKit.Name == kitName then return nativeKit, nativeShared end
	for _, folder in workspace:GetDescendants() do
		if folder.Name == "flux kit" and folder:FindFirstChild("kits") then
			local kit = folder.kits:FindFirstChild(kitName)
			if kit then
				nativeKit, nativeShared = kit, require(folder.components.scripts.shared)
				return nativeKit, nativeShared
			end
		end
	end
	error("Configured Flux kit is unavailable: " .. tostring(kitName))
end

local function nativeOrdered(folder)
	local decorated={}
	for index,model in folder:GetChildren() do
		if model:IsA("Model") then table.insert(decorated,{model=model,index=index}) end
	end
	table.sort(decorated, function(a,b)
		local an,bn=tonumber(a.model.Name),tonumber(b.model.Name)
		if an and bn and an~=bn then return an<bn end
		if an~=nil and bn==nil then return true end
		if an==nil and bn~=nil then return false end
		if a.model.Name~=b.model.Name then return a.model.Name<b.model.Name end
		return a.index<b.index
	end)
	local result={}
	for _,entry in decorated do table.insert(result,entry.model) end
	return result
end

function NativePlayback.stop()
	nativeGeneration += 1
	table.clear(nativeJobs)
	table.clear(nativeValues)
end

local function nativeRead(target, definition, attribute, fixture)
	if attribute == "pan" or attribute == "tilt" then
		return math.deg(target.motors[attribute].CurrentAngle) / 100
	end
	local value = definition.getVal(target, attribute)
	if type(value) ~= "number" then return nil end
	if attribute:find("intensity", 1, true) then return 1-value end
	if attribute == "iris" then
		local zoom=fixture.zoom
		assert(zoom and zoom[2]~=zoom[1], "Flux iris range unavailable")
		return (value-zoom[1])/(zoom[2]-zoom[1])
	end
	if attribute == "shutter" then return value*4 end
	return value
end

local function nativeSet(target, definition, attribute, value)
	definition.update[attribute](target, value)
end

local function nativeAttributes(event, definition)
	local action=event.action
	local values={}
	if action=="color" then
		local v=event.value
		local c
		if typeof(v)=="Color3" then c=v
		elseif type(v)=="string" then c=Color3.fromHex(v:gsub("#", ""))
		elseif type(v)=="table" then c=Color3.fromRGB(v[1] or v.r or 255,v[2] or v.g or 255,v[3] or v.b or 255) end
		assert(c,"Invalid color cue")
		values={red=c.R,green=c.G,blue=c.B}
	elseif action=="level" or action=="intensity" or action=="flash" or action=="reset" or action=="strobe" then
		local v=action=="reset" and 0 or (action=="flash" or action=="strobe") and 1 or math.clamp(tonumber(event.value) or 0,0,1)
		if event.channel=="beam" then values["beam intensity"]=v
		elseif event.channel=="gobo" then values["gobo intensity"]=v
		else
			for _,a in {"intensity","beam intensity","gobo intensity"} do if definition.update[a] then values[a]=v end end
		end
		if action=="reset" and not event.module and not event.channel then
			if definition.update.pan then values.pan=0 end
			if definition.update.tilt then values.tilt=0 end
		end
	else
		local v=assert(tonumber(event.value),"Cue requires a numeric value")
		if action=="pan" or action=="tilt" or action=="spin" or action=="pitch" then v/=100 end
		values[action]=v
	end
	return values
end

function NativePlayback.cancel(kind, attributes)
	for target, jobs in pairs(nativeJobs) do
		for attribute, job in pairs(jobs) do
			if job.kind==kind and (not attributes or attributes[attribute]) then jobs[attribute]=nil end
		end
		if next(jobs)==nil then nativeJobs[target]=nil end
	end
	-- A native preset may change values outside this scheduler.
	table.clear(nativeValues)
end

function NativePlayback.cue(data)
	local event=data.event
	NativePlayback.token=data.token
	local kit,shared=nativeContext(data.kitName)
	local kind,selector=tostring(event.target):match("^([^:]+):(.+)$")
	assert(kind,"Invalid cue target")
	local fixture=assert(shared.fixt[kind],"Unknown Flux fixture: "..kind)
	local folder=assert(kit.fixtures.main:FindFirstChild(kind),"Fixture not installed: "..kind)
	local selected={}
	for _,item in event.selection or {} do
		local id=type(item)=="table" and (item[1] or item.fixture or item.index) or item
		selected[tostring(id)]=true
	end
	local hasSelection=next(selected)~=nil
	local count=0
	local now=workspace:GetServerTimeNow()
	local started=data.started or now
	for index,model in nativeOrdered(folder) do
		if not model:IsA("Model") then continue end
		if hasSelection and not selected[tostring(index)] then continue end
		if not hasSelection and selector~="all" and selector~="channel" and selector~="group" and selector~=tostring(index) and selector~=model.Name then continue end
		for module,definition in pairs(fixture.module) do
			if event.module and tostring(event.module)~=tostring(module) then continue end
			local targets={}
			if definition.kind=="p" then
				local pixels=model.use:FindFirstChild("pixels")
				local channel=pixels and pixels:FindFirstChild(tostring(module))
				if channel then targets=channel:GetChildren() end
			else targets={model.use} end
			local values=nativeAttributes(event,definition)
			for attribute,value in pairs(values) do
				if not definition.update[attribute] then continue end
				for _,target in targets do
					count+=1
					local jobs=nativeJobs[target] or {}
					nativeJobs[target]=jobs
					local duration=math.max(0,tonumber(event.duration) or 0)
					local previous=nativeValues[target]
					local from=previous and previous[attribute]
					if event.automationFrom ~= nil then
						from=nativeAttributes({action=event.action,value=event.automationFrom,channel=event.channel},definition)[attribute]
					elseif from==nil then
						from=nativeRead(target,definition,attribute,fixture)
					end
					if duration>0 then assert(from~=nil,"Flux does not expose a numeric start value for "..attribute) end
					jobs[attribute]={kind=kind,definition=definition,attribute=attribute,from=from or value,value=value,
						start=started,duration=duration,flashTiming=event.flashTiming,action=event.action,mode=event.value,generation=nativeGeneration}
				end
			end
		end
	end
	assert(count>0,"No native Flux controls match cue: "..tostring(event.label or event.action))
end

game:GetService("RunService").Heartbeat:Connect(function()
	local now=workspace:GetServerTimeNow()
	for target,jobs in pairs(nativeJobs) do
		for attribute,job in pairs(jobs) do
			local elapsed=math.max(0,now-job.start)
			local duration=job.duration
			local progress=duration>0 and math.clamp(elapsed/duration,0,1) or 1
			local value=job.from+(job.value-job.from)*progress
			local done=progress>=1
			if job.action=="flash" then
				local release=(job.mode=="fade-out" or job.mode=="fade-both") and math.min(duration*.35,1) or 0
				local attack=job.mode=="fade-in" and duration or job.mode=="fade-both" and math.min(duration*.35,1) or 0
				local timing=job.flashTiming
				if type(timing)=="table" then
					local fadeIn=math.max(0,tonumber(timing[1]) or 0)
					local hold=math.max(0,tonumber(timing[2]) or 0)
					local fadeOut=math.max(0,tonumber(timing[3]) or 0)
					local total=fadeIn+hold+fadeOut
					if total>0 then
						attack=duration*fadeIn/total
						release=duration*fadeOut/total
					end
				end
				value=attack>0 and math.min(1,elapsed/attack) or 1
				if release>0 and elapsed>=duration-release then value=math.max(0,(duration-elapsed)/release) end
				if done then value=0 end
			elseif job.action=="strobe" then
				value=done and job.from or (math.floor(elapsed*math.clamp(tonumber(job.mode) or 10,1,30)*2)%2==0 and 1 or 0)
			end
			local ok,err=pcall(nativeSet,target,job.definition,attribute,value)
			if ok then
				local values=nativeValues[target] or {}
				nativeValues[target]=values
				values[attribute]=value
			end
			if not ok then
				warn("Flux Shows native playback: "..tostring(err))
				game.ReplicatedStorage.FluxlineSequencer:FireServer("nativeFault",{token=NativePlayback.token,message=tostring(err)})
			end
			if done or not ok then jobs[attribute]=nil end
		end
		if next(jobs)==nil then nativeJobs[target]=nil end
	end
end)


remote.OnClientEvent:Connect(function(action, data)
	if action == "nativeCue" then
		local ok, failure = pcall(NativePlayback.cue, data)
		if not ok then
			NativePlayback.stop()
			warn("Flux Shows: " .. tostring(failure))
			setStatus("CUE FAILED", false)
			remote:FireServer("nativeFault", {token=data.token, message=tostring(failure)})
		end
		return
	elseif action == "nativeCancel" then
		NativePlayback.cancel(data.kind, data.attributes)
		return
	elseif action == "playbackError" then
		NativePlayback.stop()
		setStatus("SHOW FAILED", false)
		title.Text = tostring(data)
		return
	end
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
			if audioRequestId ~= requestId then return end
			if not ok or not localSound.IsLoaded then
				warn("Fluxline client audio failed to load:", data.songId, message)
				setStatus("AUDIO FAILED", false)
				remote:FireServer("audioFailed", requestId)
				return
			end
			remote:FireServer("audioReady", requestId)
			if pendingStart and pendingStart.requestId == requestId then syncLocalAudio(pendingStart) end
		end)
	elseif action == "playing" then
		title.Text = data.name or "Playing"
		eyebrow.Text = "NOW PLAYING"
		setStatus("PLAYING", true)
		pendingStart = data
		if data.songId and localSound.IsLoaded then syncLocalAudio(data) end
	elseif action == "stopped" then
		NativePlayback.stop()
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
