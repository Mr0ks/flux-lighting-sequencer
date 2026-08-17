local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local root = script.Parent
local Config = require(root.Config)
local Shows = root.Shows
local remote = ReplicatedStorage:FindFirstChild("FluxlineSequencer") or Instance.new("RemoteEvent")
remote.Name = "FluxlineSequencer"
remote.Parent = ReplicatedStorage

local activeToken = 0
local base = setmetatable({}, { __mode = "k" })

local function allowed(player)
	if player.UserId == game.CreatorId then return true end
	return table.find(Config.Whitelist, player.UserId) ~= nil
end

local function findKit()
	for _, d in workspace:GetDescendants() do
		if d.Name == "flux kit" and d:FindFirstChild("kits") then
			return d.kits:FindFirstChild(Config.KitName) or d.kits:FindFirstChildWhichIsA("Folder")
		end
	end
end

local function fixtures(target)
	local kind, selector = target:match("^(.+):([^:]+)$")
	local kit = findKit()
	local main = kit and kit:FindFirstChild("fixtures") and kit.fixtures:FindFirstChild("main")
	local folder = main and main:FindFirstChild(kind)
	if not folder then return {} end
	local matches = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and (selector == "all" or child.Name == selector) then table.insert(matches, child) end
	end
	table.sort(matches, function(a, b) return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0) end)
	return matches
end

local function tween(object, duration, goal)
	if duration and duration > 0 then
		TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Linear), goal):Play()
	else
		for key, value in goal do object[key] = value end
	end
end

local function eachEmitter(model, callback, filter)
	for _, d in model:GetDescendants() do
		if (d:IsA("Light") or d:IsA("Beam")) and (not filter or filter(d)) then callback(d) end
	end
end

local function setLevel(model, value, duration, filter)
	value = math.clamp(tonumber(value) or 0, 0, 1)
	eachEmitter(model, function(d)
		if not base[d] then base[d] = d.Brightness > 0 and d.Brightness or (d:IsA("Beam") and 1 or 4) end
		d.Enabled = true
		tween(d, duration, { Brightness = base[d] * value })
	end, filter)
end

local function setColor(model, rgb, duration)
	local color = Color3.fromRGB(rgb[1] or 255, rgb[2] or 255, rgb[3] or 255)
	for _, d in model:GetDescendants() do
		if d:IsA("Light") then tween(d, duration, { Color = color })
		elseif d:IsA("Beam") then d.Color = ColorSequence.new(color)
		elseif (d:IsA("BasePart") or d:IsA("MeshPart")) and (d.Name == "lamp" or d.Name == "panel") then tween(d, duration, { Color = color }) end
	end
end

local function motor(model, name)
	local use = model:FindFirstChild("use")
	local motors = use and use:FindFirstChild("motors")
	local found = motors and motors:FindFirstChild(name, true)
	return found and found:IsA("Motor6D") and found or nil
end

local AXIS = { pan = Vector3.new(0,1,0), tilt = Vector3.new(1,0,0), spin = Vector3.new(0,0,1), pitch = Vector3.new(1,0,0) }
local function move(model, action, value, duration)
	local m = motor(model, action == "pitch" and "tilt" or action)
	if not m then return end
	if not base[m] then base[m] = m.Transform end
	local v = AXIS[action] * math.rad(tonumber(value) or 0)
	tween(m, duration, { Transform = base[m] * CFrame.Angles(v.X, v.Y, v.Z) })
end

local function apply(event, token)
	if event.action == "pyro" then
		local kit = findKit()
		local folder = kit and kit.fixtures.pyrotechnics:FindFirstChild(tostring(event.value))
		if not folder then return end
		for _, d in folder:GetDescendants() do
			if d:IsA("ParticleEmitter") then d:Emit(math.max(1, d:GetAttribute("FluxlineEmitCount") or 30)) end
		end
		return
	end
	local action, value, duration = event.action, event.value, tonumber(event.duration) or 0
	for _, model in fixtures(event.target) do
	if action == "level" or action == "intensity" then setLevel(model, value, duration)
	elseif action == "reset" then setLevel(model, 0, duration); move(model, "pan", 0, duration); move(model, "tilt", 0, duration)
	elseif action == "color" then setColor(model, value, duration)
	elseif action == "pan" or action == "tilt" or action == "spin" or action == "pitch" then move(model, action, value, duration)
	elseif action == "beam intensity" then setLevel(model, value, duration, function(d) return d:GetFullName():lower():find(".beam", 1, true) ~= nil end)
	elseif action == "gobo intensity" then setLevel(model, value, duration, function(d) return d:GetFullName():lower():find(".gobo", 1, true) ~= nil end)
	elseif action == "iris" or action == "width" then
		local n = math.clamp(tonumber(value) or 0, 0, 1)
		eachEmitter(model, function(d)
			if d:IsA("Light") then tween(d, duration, { Angle = 1 + n * 119 })
			elseif d:IsA("Beam") then tween(d, duration, { Width0 = .02 + n * 2, Width1 = .02 + n * 2 }) end
		end)
	elseif action == "shutter" then eachEmitter(model, function(d) d.Enabled = value ~= 0 end)
	elseif action == "strobe" then
		local hz = math.clamp(tonumber(value) or 10, 1, 30)
		task.spawn(function()
			local untilTime = os.clock() + math.max(duration, .1)
			local on = false
			while activeToken == token and os.clock() < untilTime do on = not on; setLevel(model, on and 1 or 0, 0); task.wait(1/(hz*2)) end
			if activeToken == token then setLevel(model, 1, 0) end
		end)
	end
	end
end

local function listShows()
	local result = {}
	for _, module in Shows:GetChildren() do
		if module:IsA("ModuleScript") then
			local ok, show = pcall(require, module)
			if ok and type(show) == "table" and type(show.events) == "table" then
				table.insert(result, { id = module.Name, name = show.name or module.Name, duration = show.duration or 0, bpm = show.bpm or 0 })
			end
		end
	end
	table.sort(result, function(a,b) return a.name < b.name end)
	return result
end

local function stop()
	activeToken += 1
	local sound = SoundService:FindFirstChild("FluxlineShowAudio")
	if sound then sound:Stop() end
	remote:FireAllClients("stopped")
end

local function play(player, id)
	if not allowed(player) then return end
	local module = Shows:FindFirstChild(id)
	if not module or not module:IsA("ModuleScript") then return end
	local ok, show = pcall(require, module)
	if not ok or type(show) ~= "table" or type(show.events) ~= "table" then return end
	stop(); local token = activeToken
	local sound = SoundService:FindFirstChild("FluxlineShowAudio") or Instance.new("Sound")
	sound.Name = "FluxlineShowAudio"; sound.Parent = SoundService
	if tostring(show.songId or "") ~= "" then sound.SoundId = "rbxassetid://" .. tostring(show.songId); sound.TimePosition = 0; sound:Play() end
	local started = workspace:GetServerTimeNow()
	remote:FireAllClients("playing", { id=id, name=show.name or id, started=started, duration=show.duration or 0 })
	for _, event in show.events do
		task.delay(math.max(0, tonumber(event.t) or 0), function() if activeToken == token then apply(event, token) end end)
	end
end

remote.OnServerEvent:Connect(function(player, action, value)
	if not allowed(player) then return end
	if action == "list" then remote:FireClient(player, "shows", listShows())
	elseif action == "play" then play(player, tostring(value))
	elseif action == "stop" then stop() end
end)

Players.PlayerAdded:Connect(function(player) if allowed(player) then remote:FireClient(player, "authorized") end end)
