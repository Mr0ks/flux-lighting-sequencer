local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local root = script.Parent
local Config = require(root.Config)
local Shows = root.Shows
local remote = ReplicatedStorage:FindFirstChild("FluxlineSequencer") or Instance.new("RemoteEvent")
remote.Name = "FluxlineSequencer"
remote.Parent = ReplicatedStorage

local activeToken = 0
local base = setmetatable({}, { __mode = "k" })
local activeTweens = setmetatable({}, { __mode = "k" })
local emitterSerial = setmetatable({}, { __mode = "k" })
local lastRequest = setmetatable({}, { __mode = "k" })
local pendingAudio = nil

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

-- Flux permits duplicate Model names. Physical order, not Model.Name, is the
-- only safe way to address an exact fixture exported by this package.
local function orderedModels(folder)
	local decorated = {}
	for originalIndex, child in folder:GetChildren() do
		if child:IsA("Model") then
			table.insert(decorated, { model = child, originalIndex = originalIndex })
		end
	end
	table.sort(decorated, function(a, b)
		local an, bn = tonumber(a.model.Name), tonumber(b.model.Name)
		if an and bn and an ~= bn then return an < bn end
		if an ~= nil and bn == nil then return true end
		if an == nil and bn ~= nil then return false end
		if a.model.Name ~= b.model.Name then return a.model.Name < b.model.Name end
		return a.originalIndex < b.originalIndex
	end)
	local models = {}
	for _, item in decorated do table.insert(models, item.model) end
	return models
end

local function fixtures(target, selection)
	local kind, selector = target:match("^([^:]+):([^:]+)")
	local kit = findKit()
	local main = kit and kit:FindFirstChild("fixtures") and kit.fixtures:FindFirstChild("main")
	local folder = main and main:FindFirstChild(kind)
	if not folder then return {} end
	local selected = {}
	for _, pair in selection or {} do
		local index = type(pair) == "table" and (pair[1] or pair.fixture or pair.index) or pair
		selected[tonumber(index)] = true
	end
	local matches = {}
	local useSelection = selection and #selection > 0
	for index, child in orderedModels(folder) do
		if (useSelection and selected[index])
			or (not useSelection and (
				selector == "all"
				or selector == "channel"
				or selector == "group"
				or tonumber(selector) == index
				or child.Name == selector
			)) then
			table.insert(matches, child)
		end
	end
	return matches
end

local function tween(object, duration, goal)
	local previous = activeTweens[object]
	if previous then previous:Cancel() end
	if duration and duration > 0 then
		local created = TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Linear), goal)
		activeTweens[object] = created
		created.Completed:Once(function()
			if activeTweens[object] == created then activeTweens[object] = nil end
		end)
		created:Play()
	else
		for key, value in goal do object[key] = value end
	end
end

local function cancelTweens()
	for object, current in activeTweens do
		current:Cancel()
		activeTweens[object] = nil
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
		emitterSerial[d] = (emitterSerial[d] or 0) + 1
		local serial = emitterSerial[d]
		if not base[d] then
			local configured = d:GetAttribute("FluxlineBaseBrightness")
			base[d] = type(configured) == "number" and math.max(0, configured)
				or (d.Brightness > 0 and d.Brightness or 1)
		end
		local seconds = math.max(0, tonumber(duration) or 0)
		if value > 0 or seconds > 0 then d.Enabled = true end
		tween(d, seconds, { Brightness = base[d] * value })
		if value == 0 then
			if seconds == 0 then
				d.Enabled = false
			else
				task.delay(seconds, function()
					if emitterSerial[d] == serial and d.Brightness <= .001 then d.Enabled = false end
				end)
			end
		end
	end, filter)
end

local function captureEmitterSerial(model, filter)
	local captured = {}
	eachEmitter(model, function(d) captured[d] = emitterSerial[d] or 0 end, filter)
	return captured
end

local function emitterSerialIsCurrent(captured)
	for emitter, serial in captured do
		if emitterSerial[emitter] ~= serial then return false end
	end
	return next(captured) ~= nil
end

-- A flash owns the affected emitters only until another cue touches them.
-- This prevents an older flash's delayed off from cancelling a newer cue.
local function flash(model, mode, duration, filter, token)
	local total = math.max(.05, tonumber(duration) or 1)
	mode = tostring(mode or "snap")
	local attack = mode == "fade-both" and math.min(total * .35, 1) or 0
	local release = mode == "snap" and 0 or math.min(total * .35, 1)
	if attack > 0 then setLevel(model, 0, 0, filter) end
	setLevel(model, 1, attack, filter)
	local captured = captureEmitterSerial(model, filter)
	task.spawn(function()
		task.wait(math.max(0, total - release))
		if activeToken ~= token or not emitterSerialIsCurrent(captured) then return end
		setLevel(model, 0, release, filter)
	end)
end

local function readColor(value)
	if typeof(value) == "Color3" then return value end
	if type(value) == "string" then
		local hex = value:match("^#?(%x%x%x%x%x%x)$")
		if hex then
			return Color3.fromRGB(
				tonumber(hex:sub(1, 2), 16),
				tonumber(hex:sub(3, 4), 16),
				tonumber(hex:sub(5, 6), 16)
			)
		end
	end
	if type(value) == "table" then
		return Color3.fromRGB(
			tonumber(value[1] or value.r) or 255,
			tonumber(value[2] or value.g) or 255,
			tonumber(value[3] or value.b) or 255
		)
	end
	return Color3.new(1, 1, 1)
end

local function setColor(model, rgb, duration, filter)
	local color = readColor(rgb)
	for _, d in model:GetDescendants() do
		if (not filter or filter(d)) then
			if d:IsA("Light") then tween(d, duration, { Color = color })
			elseif d:IsA("Beam") then d.Color = ColorSequence.new(color)
			elseif (d:IsA("BasePart") or d:IsA("MeshPart")) and (d.Name == "lamp" or d.Name == "panel") then tween(d, duration, { Color = color }) end
		end
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

local function moduleFilter(model, module)
	if module == nil then return nil end
	local use = model:FindFirstChild("use")
	local pixels = use and use:FindFirstChild("pixels")
	local channel = pixels and pixels:FindFirstChild(tostring(module))
	if not channel then return function() return false end end
	return function(object)
		return object == channel or object:IsDescendantOf(channel)
	end
end

local function namedChannelFilter(model, channel)
	if channel == nil then return nil end
	local use = model:FindFirstChild("use")
	local lamps = use and use:FindFirstChild("lamps")
	local root
	if channel == "beam" then
		root = lamps and lamps:FindFirstChild("beam")
	elseif channel == "gobo" then
		root = lamps and lamps:FindFirstChild("gobo")
	end
	if not root then return function() return false end end
	return function(object)
		return object == root or object:IsDescendantOf(root)
	end
end

local SPEED_SECONDS = {
	snap = 0,
	fade = 1,
	dim = 1,
	color = 2,
	movement = 2,
	iris = 1.5,
	strobe = .12,
}

local function combineFilter(first, second)
	if not first then return second end
	if not second then return first end
	return function(object) return first(object) and second(object) end
end

local function nativeFilter(model, meta)
	local filter = moduleFilter(model, meta.module)
	if type(meta.selection) ~= "table" or #meta.selection == 0 then return filter end
	local use = model:FindFirstChild("use")
	local pixels = use and use:FindFirstChild("pixels")
	local channel = pixels and pixels:FindFirstChild(tostring(meta.module))
	if not channel then return function() return false end end
	local selected = {}
	for _, number in meta.selection do selected[tonumber(number)] = true end
	return combineFilter(filter, function(object)
		for _, pixel in channel:GetChildren() do
			if selected[tonumber(pixel.Name)] and (object == pixel or object:IsDescendantOf(pixel)) then return true end
		end
		return false
	end)
end

local function componentColor(model, filter, component, value)
	value = math.clamp((tonumber(value) or 0) / 100, 0, 1)
	eachEmitter(model, function(emitter)
		local current = emitter:IsA("Beam") and emitter.Color.Keypoints[1].Value or emitter.Color
		local color
		if component == "hue" then
			local _, saturation, brightness = current:ToHSV()
			color = Color3.fromHSV(value, math.max(saturation, 1), math.max(brightness, 1))
		elseif component == "red" then color = Color3.new(value, current.G, current.B)
		elseif component == "green" then color = Color3.new(current.R, value, current.B)
		else color = Color3.new(current.R, current.G, value) end
		if emitter:IsA("Beam") then emitter.Color = ColorSequence.new(color) else emitter.Color = color end
	end, filter)
end

local function nativeNumber(value, fallback)
	local direct = tonumber(value)
	if direct ~= nil then return direct end
	local symbolic = type(value) == "string" and value:lower() or ""
	if symbolic:match("^h[%s_-]") or symbolic:find("high", 1, true) then return 100 end
	if symbolic:match("^l[%s_-]") or symbolic:find("low", 1, true) then return 0 end
	return fallback or 0
end

local function applyNativeAttribute(model, meta, value, duration)
	local attribute = tostring(meta.attribute or ""):lower()
	local filter = nativeFilter(model, meta)
	if attribute == "intensity" then setLevel(model, nativeNumber(value, 0) / 100, duration, filter)
	elseif attribute == "hue" or attribute == "red" or attribute == "green" or attribute == "blue" then componentColor(model, filter, attribute, nativeNumber(value, 0))
	elseif attribute == "pan" or attribute == "tilt" or attribute == "spin" or attribute == "pitch" then move(model, attribute, nativeNumber(value, 0), duration)
	elseif attribute == "beam intensity" then setLevel(model, nativeNumber(value, 0) / 100, duration, combineFilter(filter, function(d) return d:GetFullName():lower():find(".beam", 1, true) ~= nil end))
	elseif attribute == "gobo intensity" then setLevel(model, nativeNumber(value, 0) / 100, duration, combineFilter(filter, function(d) return d:GetFullName():lower():find(".gobo", 1, true) ~= nil end))
	elseif attribute == "iris" or attribute == "width" then
		local n = math.clamp(nativeNumber(value, 0) / 100, 0, 1)
		eachEmitter(model, function(d)
			if d:IsA("Light") then tween(d, duration, { Angle = 1 + n * 119 })
			elseif d:IsA("Beam") then tween(d, duration, { Width0 = .02 + n * 2, Width1 = .02 + n * 2 }) end
		end, filter)
	elseif attribute == "shutter" then eachEmitter(model, function(d) d.Enabled = nativeNumber(value, 0) > 0 end, filter)
	end
end

local function nativeMeta(payload)
	if type(payload) ~= "table" then return {} end
	if type(payload.meta) == "table" then return payload.meta end
	if type(payload[2]) == "table" and type(payload[2].meta) == "table" then
		local flattened = {}
		for _, layer in payload[2].meta do
			if type(layer) == "table" then
				if layer.attribute then table.insert(flattened, layer)
				else for _, item in layer do if type(item) == "table" then table.insert(flattened, item) end end end
			end
		end
		return flattened
	end
	return {}
end

local function speedSeconds(speed)
	if type(speed) == "number" then return math.max(.02, (101 - math.clamp(speed, 1, 100)) / 50) end
	return SPEED_SECONDS[tostring(speed)] or 1
end

local function waveform(form, phase)
	local turn = (phase / (math.pi * 2)) % 1
	if form == "ramp+" or form == "ramp" then return turn
	elseif form == "ramp-" then return 1 - turn
	elseif form == "pwm" then return turn < .5 and 1 or 0
	elseif form == "phase 1" then return turn < .5 and 1 or 0
	elseif form == "phase 2" then return turn < .5 and 0 or 1
	elseif form == "flat+" then return 1
	elseif form == "cosine" then return (math.cos(phase) + 1) / 2
	elseif form == "bump" then return math.max(0, math.sin(phase)) ^ 2
	elseif form == "swing" then return math.abs(math.sin(phase))
	elseif form == "random" or form == "rand" then return (math.noise(phase * 3.1) + 1) / 2
	else return (math.sin(phase) + 1) / 2 end
end

local function applyNative(event, token)
	local native = event.native
	if type(native) ~= "table" then return end
	local metas = nativeMeta(native.payload)
	local models = fixtures(event.target, event.selection)
	if event.action == "flux-effect" then
		local duration = math.max(.05, tonumber(event.duration) or 4)
		for modelIndex, model in models do
			for _, meta in metas do
				task.spawn(function()
					local started = os.clock()
					local cycle = speedSeconds(meta.speed)
					local phaseRange = type(meta.phase) == "table" and meta.phase or { 0, 360 }
					local lowHigh = type(meta.lh) == "table" and meta.lh or { 0, 100 }
					local low = nativeNumber(lowHigh[1], 0)
					local high = nativeNumber(lowHigh[2], 100)
					local offset = #models > 1 and (modelIndex - 1) / #models or 0
					while activeToken == token and os.clock() - started <= duration do
						local elapsed = os.clock() - started
						local degrees = (tonumber(phaseRange[1]) or 0) + ((tonumber(phaseRange[2]) or 360) - (tonumber(phaseRange[1]) or 0)) * offset
						local phase = elapsed / cycle * math.pi * 2 + math.rad(degrees)
						applyNativeAttribute(model, meta, low + (high - low) * waveform(tostring(meta.form), phase), 0)
						RunService.Heartbeat:Wait()
					end
				end)
			end
		end
	else
		for _, model in models do
			for _, meta in metas do
				task.spawn(function()
					local delayValue = type(meta.delay) == "number" and meta.delay or (meta.delay and speedSeconds(meta.delay) or 0)
					if delayValue > 0 then task.wait(delayValue) end
					if activeToken ~= token then return end
					local points = type(meta.points) == "table" and meta.points or { nil, 0 }
					local value = points[2]
					if value == nil then value = points[1] end
					applyNativeAttribute(model, meta, value or 0, speedSeconds(meta.speed))
				end)
			end
		end
	end
end

local function apply(event, token)
	if type(event.action) == "string" and event.action:sub(1, 5) == "flux-" then
		applyNative(event, token)
		return
	end
	if event.action == "block" and type(event.actions) == "table" then
		for _, child in event.actions do
			local nested = table.clone(child)
			nested.target = nested.target or event.target
			nested.selection = nested.selection or event.selection
			nested.module = nested.module or event.module
			nested.channel = nested.channel or event.channel
			apply(nested, token)
		end
		return
	end
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
	for _, model in fixtures(event.target, event.selection) do
	local channelFilter = event.channel ~= nil
		and namedChannelFilter(model, event.channel)
		or moduleFilter(model, event.module)
	if action == "level" or action == "intensity" then setLevel(model, value, duration, channelFilter)
	elseif action == "flash" then flash(model, value, duration, channelFilter, token)
	elseif action == "reset" then setLevel(model, 0, duration, channelFilter); if not event.module then move(model, "pan", 0, duration); move(model, "tilt", 0, duration) end
	elseif action == "color" then
		local colorFilter = channelFilter
		if event.module == nil and model.Parent and model.Parent.Name == "jdc1" then
			colorFilter = moduleFilter(model, 2)
		end
		setColor(model, value, duration, colorFilter)
	elseif action == "pan" or action == "tilt" or action == "spin" or action == "pitch" then move(model, action, value, duration)
	elseif action == "beam intensity" then setLevel(model, value, duration, function(d) return (not channelFilter or channelFilter(d)) and d:GetFullName():lower():find(".beam", 1, true) ~= nil end)
	elseif action == "gobo intensity" then setLevel(model, value, duration, function(d) return (not channelFilter or channelFilter(d)) and d:GetFullName():lower():find(".gobo", 1, true) ~= nil end)
	elseif action == "iris" or action == "width" then
		local n = math.clamp(tonumber(value) or 0, 0, 1)
		eachEmitter(model, function(d)
			if d:IsA("Light") then tween(d, duration, { Angle = 1 + n * 119 })
			elseif d:IsA("Beam") then tween(d, duration, { Width0 = .02 + n * 2, Width1 = .02 + n * 2 }) end
		end, channelFilter)
	elseif action == "shutter" then eachEmitter(model, function(d) d.Enabled = value ~= 0 end, channelFilter)
	elseif action == "strobe" then
		local hz = math.clamp(tonumber(value) or 10, 1, 30)
		task.spawn(function()
			local untilTime = os.clock() + math.max(duration, .1)
			local on = false
			while activeToken == token and os.clock() < untilTime do on = not on; setLevel(model, on and 1 or 0, 0, channelFilter); task.wait(1/(hz*2)) end
			if activeToken == token then setLevel(model, 1, 0, channelFilter) end
		end)
	end
	end
end

local FIXTURE_CAPABILITIES = {
	profile = { "intensity", "color", "strobe", "pan", "tilt", "iris", "shutter", "spin", "beam intensity", "gobo intensity" },
	wash = { "intensity", "color", "strobe", "pan", "tilt", "iris", "shutter" },
	["magic blade"] = { "intensity", "color", "strobe", "pan", "tilt" },
	["magic panel"] = { "intensity", "color", "strobe", "pan", "tilt" },
	jdc1 = { "intensity", "color", "strobe", "tilt" },
	q7 = { "intensity", "color", "strobe" },
	laser = { "intensity", "color", "strobe", "pan", "tilt", "iris", "width", "spin", "pitch", "shutter" },
	line = { "intensity", "color", "strobe" },
	par = { "intensity", "color", "strobe", "shutter" },
	blinder = { "intensity" },
	atomic = { "intensity", "strobe" },
	display = { "intensity", "color", "strobe" },
	["follow spotlight"] = { "intensity", "color", "strobe", "pan", "tilt", "iris", "shutter" },
}

local function discoverPatch()
	local kit = findKit()
	local main = kit and kit:FindFirstChild("fixtures") and kit.fixtures:FindFirstChild("main")
	local patch = {}
	if not main then return patch end
	for _, folder in main:GetChildren() do
		if not folder:IsA("Folder") then continue end
		local models = orderedModels(folder)
		if #models == 0 then continue end
		local fixture = {
			type = folder.Name,
			count = #models,
			exact = true,
			ids = {},
			capabilities = FIXTURE_CAPABILITIES[folder.Name] or { "intensity", "color", "strobe" },
			channels = {},
		}
		for index, model in models do
			table.insert(fixture.ids, ("%d:%s"):format(index, model.Name))
		end
		local use = models[1]:FindFirstChild("use")
		local pixels = use and use:FindFirstChild("pixels")
		if pixels then
			for _, moduleFolder in pixels:GetChildren() do
				if not moduleFolder:IsA("Folder") then continue end
				local module = tonumber(moduleFolder.Name) or moduleFolder.Name
				local emitterCount = 0
				for _, item in moduleFolder:GetDescendants() do
					if item:IsA("Light") or item:IsA("Beam") then emitterCount += 1 end
				end
				if emitterCount == 0 then continue end
				local label = "Pixels"
				if folder.Name == "jdc1" and module == 2 then label = "Centre pixels"
				elseif folder.Name == "jdc1" and module == 3 then label = "Outer tube"
				else label = ("Pixels · module %s"):format(tostring(module)) end
				local allowed = {}
				for _, capability in fixture.capabilities do allowed[capability] = true end
				local capabilities = {}
				if allowed.intensity then table.insert(capabilities, "intensity") end
				if allowed.strobe then table.insert(capabilities, "strobe") end
				if allowed.color and not (folder.Name == "jdc1" and module == 3) then table.insert(capabilities, "color") end
				table.insert(fixture.channels, {
					id = tostring(module),
					module = module,
					label = label,
					emitterCount = emitterCount,
					capabilities = capabilities,
				})
			end
			table.sort(fixture.channels, function(a, b)
				return (tonumber(a.module) or math.huge) < (tonumber(b.module) or math.huge)
			end)
		end
		if folder.Name == "profile" then
			local lamps = use and use:FindFirstChild("lamps")
			for _, definition in {
				{ id = "beam", label = "Main beam", capabilities = { "intensity", "color", "strobe", "shutter", "beam intensity" } },
				{ id = "gobo", label = "Gobo projection", capabilities = { "intensity", "color", "strobe", "shutter", "gobo intensity" } },
			} do
				local root = lamps and lamps:FindFirstChild(definition.id)
				local emitterCount = 0
				if root then
					for _, item in root:GetDescendants() do
						if item:IsA("Light") or item:IsA("Beam") then emitterCount += 1 end
					end
				end
				if emitterCount > 0 then
					table.insert(fixture.channels, {
						id = definition.id,
						component = definition.id,
						module = 1,
						label = definition.label,
						emitterCount = emitterCount,
						capabilities = definition.capabilities,
					})
				end
			end
		end
		table.insert(patch, fixture)
	end
	table.sort(patch, function(a, b) return a.type < b.type end)
	return patch
end

local function exportFlux()
	local bundle = {
		format = "fluxline-datastore",
		version = 1,
		exportedAt = os.time(),
		source = {
			dataStore = Config.FluxDataStoreName,
			showKey = Config.FluxShowKey,
		},
		data = {},
	}
	for _, scope in Config.FluxScopes do
		local store = DataStoreService:GetDataStore(Config.FluxDataStoreName, scope)
		local ok, value = pcall(function()
			return store:GetAsync(Config.FluxShowKey)
		end)
		if not ok then return false, ("Unable to read %s: %s"):format(scope, tostring(value)) end
		bundle.data[scope] = value or {}
	end
	bundle.patch = discoverPatch()
	local ok, encoded = pcall(function() return HttpService:JSONEncode(bundle) end)
	if not ok then return false, "Unable to encode Flux data: " .. tostring(encoded) end
	return true, encoded
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
	pendingAudio = nil
	cancelTweens()
	remote:FireAllClients("stopped")
end

local function play(player, id)
	if not allowed(player) then return end
	local module = Shows:FindFirstChild(id)
	if not module or not module:IsA("ModuleScript") then return end
	local ok, show = pcall(require, module)
	if not ok or type(show) ~= "table" or type(show.events) ~= "table" then return end
	if #show.events > math.max(1, tonumber(Config.MaxShowEvents) or 10000) then
		warn(("Fluxline refused %s: %d events exceeds the configured limit"):format(id, #show.events))
		return
	end

	stop()
	local token = activeToken
	local songId = tostring(show.songId or ""):match("%d+")
	local hasAudio = songId ~= nil
	local requestId = nil
	if hasAudio then
		requestId = HttpService:GenerateGUID(false)
		pendingAudio = { id = requestId, ready = {}, requester = player }
		remote:FireAllClients("prepareAudio", {
			id = id,
			name = show.name or id,
			songId = songId,
			requestId = requestId,
		})
		local deadline = os.clock() + math.max(.25, tonumber(Config.AudioReadyTimeout) or 2)
		while activeToken == token and os.clock() < deadline do
			if pendingAudio and pendingAudio.id == requestId and pendingAudio.ready[player] then break end
			RunService.Heartbeat:Wait()
		end
		if activeToken ~= token then return end
	end

	local events = table.clone(show.events)
	table.sort(events, function(a, b)
		return (tonumber(a.t) or 0) < (tonumber(b.t) or 0)
	end)

	local started = workspace:GetServerTimeNow() + math.max(.05, tonumber(Config.AudioStartLeadTime) or .2)
	remote:FireAllClients("playing", {
		id = id,
		name = show.name or id,
		started = started,
		duration = show.duration or 0,
		songId = songId,
		requestId = requestId,
	})

	task.spawn(function()
		while activeToken == token and workspace:GetServerTimeNow() < started do
			RunService.Heartbeat:Wait()
		end
		local nextEvent = 1
		while activeToken == token and nextEvent <= #events do
			local showTime = math.max(0, workspace:GetServerTimeNow() - started)
			while nextEvent <= #events and (tonumber(events[nextEvent].t) or 0) <= showTime do
				apply(events[nextEvent], token)
				nextEvent += 1
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

remote.OnServerEvent:Connect(function(player, action, value)
	if type(action) ~= "string" then return end
	if action == "audioReady" then
		if pendingAudio and tostring(value) == pendingAudio.id then
			pendingAudio.ready[player] = true
		end
		return
	end
	if not allowed(player) then return end
	local now = os.clock()
	local cooldown = math.max(0, tonumber(Config.RemoteCooldown) or .08)
	if lastRequest[player] and now - lastRequest[player] < cooldown then return end
	lastRequest[player] = now
	if action == "list" then remote:FireClient(player, "shows", listShows())
	elseif action == "play" then play(player, tostring(value))
	elseif action == "stop" then stop()
	elseif action == "export" then
		local ok, result = exportFlux()
		remote:FireClient(player, "exportResult", ok and { ok = true, json = result } or { ok = false, error = result })
	end
end)

Players.PlayerAdded:Connect(function(player) if allowed(player) then remote:FireClient(player, "authorized") end end)
