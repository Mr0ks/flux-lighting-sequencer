local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local playRequest = 0
local lastRequest = setmetatable({}, { __mode = "k" })
local pendingAudio = nil

local function allowed(player)
	if player.UserId == game.CreatorId then return true end
	return table.find(Config.Whitelist, player.UserId) ~= nil
end

local function findKit()
	for _, d in workspace:GetDescendants() do
		if d.Name == "flux kit" and d:FindFirstChild("kits") then
			return d.kits:FindFirstChild(Config.KitName)
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

-- Native presets use the same remotes as Flux's panel. Ordinary timeline cues
-- use the shared Flux renderer on each client, preserving authored durations.
local nativeEffects = {}

local function nativeDirect()
	local kit=assert(findKit(), "Configured Flux kit is missing")
	return kit.components.remotes.direct
end

local function effectKey(fixture,name) return fixture.."\0"..name end

local function stopNativeEffects(kind, attributes)
	local off={}
	for key,effect in pairs(nativeEffects) do
		local overlaps=not attributes
		if attributes then
			for _,meta in effect.metas do if attributes[meta.attribute] then overlaps=true end end
		end
		if (not kind or kind==effect.fixture) and overlaps then
			table.insert(off,{effect.fixture,effect.name})
			nativeEffects[key]=nil
		end
	end
	if #off>0 then nativeDirect().effects:FireAllClients(off,"off") end
end

local function eventAttributes(event)
	local action=event.action
	if action=="level" or action=="intensity" or action=="flash" or action=="strobe" then
		return {["intensity"]=true,["beam intensity"]=event.channel~="gobo",["gobo intensity"]=event.channel~="beam"}
	elseif action=="color" then return {red=true,green=true,blue=true,hue=true}
	elseif action=="reset" then return nil end
	return {[action]=true}
end

local function nativeMetas(payload)
	assert(type(payload)=="table","Missing native preset payload")
	local result={}
	local function walk(value)
		if type(value)~="table" then return end
		if value.attribute or value.effect then table.insert(result,value);return end
		for _,child in pairs(value) do if type(child)=="table" then walk(child) end end
	end
	walk(payload.meta or (payload[2] and payload[2].meta))
	return result
end

local function validateNativeShow(events)
	local scopes={}
	local function check(event)
		if event.action=="block" then for _,child in event.actions or {} do check(child) end;return end
		local scope=({["flux-effect"]="effects",["flux-position"]="positions",["flux-macro"]="macros"})[event.action]
		if scope then
			local native=assert(event.native,"Missing native preset data")
			if not scopes[scope] then
				scopes[scope]=DataStoreService:GetDataStore(Config.FluxDataStoreName,scope):GetAsync(Config.FluxShowKey) or {}
			end
			local fixture=native.fixture or tostring(event.target):match("^([^:]+):")
			local installed=scopes[scope][fixture]
			assert(installed and installed[native.name],"Flux "..scope.." preset is missing: "..tostring(fixture).." / "..tostring(native.name)..". Refresh the sequencer's Flux import.")
			-- Use the current game preset for conflict ownership as well as execution.
			event.native=table.clone(native)
			event.native.payload=installed[native.name]
			if scope=="macros" then
				for _,meta in nativeMetas(installed[native.name]) do
					assert(not meta.delay and not meta.effect and meta.speed=="snap",
						"Timed Flux macro '"..native.name.."' cannot yet be safely cancelled by Stop. Use timeline cues or a native effect instead.")
				end
			end
		elseif event.action=="pyro" or tostring(event.action):sub(1,5)=="flux-" then
			error("Native command is not verified for "..tostring(event.action))
		end
	end
	for _,event in events do check(event) end
end

local function apply(event, token, started)
	if event.action=="block" then
		for _,child in event.actions or {} do
			local nested=table.clone(child)
			for _,key in {"target","selection","module","channel"} do if nested[key]==nil then nested[key]=event[key] end end
			apply(nested,token,started)
		end
		return
	end
	local kind=tostring(event.target):match("^([^:]+):")
	assert(kind,"Invalid show target")
	if event.action=="flux-effect" then
		local native=assert(event.native,"Effect data missing")
		local fixture=native.fixture or kind
		local metas=nativeMetas(native.payload)
		local attributes={}
		for _,meta in metas do attributes[meta.attribute]=true end
		stopNativeEffects(fixture,attributes)
		remote:FireAllClients("nativeCancel",{kind=fixture,attributes=attributes})
		local key=effectKey(fixture,native.name)
		local effect={fixture=fixture,name=native.name,metas=metas}
		nativeEffects[key]=effect
		nativeDirect().effects:FireAllClients({{fixture,native.name}},"on")
		task.delay(math.max(0,(started or workspace:GetServerTimeNow())+(tonumber(event.duration) or 0)-workspace:GetServerTimeNow()),function()
			if activeToken==token and nativeEffects[key]==effect then
				nativeEffects[key]=nil
				nativeDirect().effects:FireAllClients({{fixture,native.name}},"off")
			end
		end)
	elseif event.action=="flux-position" or event.action=="flux-macro" then
		local native=assert(event.native)
		local fixture=native.fixture or kind
		local attributes={}
		for _,meta in nativeMetas(native.payload) do if meta.attribute then attributes[meta.attribute]=true end end
		stopNativeEffects(fixture,attributes)
		remote:FireAllClients("nativeCancel",{kind=fixture,attributes=attributes})
		findKit().components.remotes.call.functions:FireAllClients(event.action=="flux-position" and "position" or "macro",fixture,native.name)
	elseif event.action=="pyro" or tostring(event.action):sub(1,5)=="flux-" then
		error("Native dispatch is not verified for "..tostring(event.action).."; cue was not approximated")
	else
		stopNativeEffects(kind,eventAttributes(event))
		remote:FireAllClients("nativeCue",{event=event,kitName=Config.KitName,started=started,token=token})
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
	playRequest += 1
	activeToken += 1
	pendingAudio = nil
	stopNativeEffects()
	remote:FireAllClients("stopped")
end

local function play(player, id)
	if not allowed(player) then return end
	playRequest += 1
	local request = playRequest
	local module = Shows:FindFirstChild(id)
	if not module or not module:IsA("ModuleScript") then return end
	local ok, show = pcall(require, module)
	if not ok or type(show) ~= "table" or type(show.events) ~= "table" then return end
	if #show.events > math.max(1, tonumber(Config.MaxShowEvents) or 10000) then
		warn(("Fluxline refused %s: %d events exceeds the configured limit"):format(id, #show.events))
		return
	end

	local valid, validationError = pcall(validateNativeShow, show.events)
	if request ~= playRequest then return end
	if not valid then
		stop()
		remote:FireClient(player,"playbackError",tostring(validationError))
		return
	end
	stop()
	local token = activeToken
	local songId = tostring(show.songId or ""):match("%d+")
	local hasAudio = songId ~= nil
	local requestId = nil
	if hasAudio then
		requestId = HttpService:GenerateGUID(false)
		pendingAudio = { id = requestId, ready = {}, failed = {}, requester = player }
		remote:FireAllClients("prepareAudio", {
			id = id,
			name = show.name or id,
			songId = songId,
			requestId = requestId,
		})
		local deadline = os.clock() + math.max(10, tonumber(Config.AudioReadyTimeout) or 10)
		while activeToken == token and os.clock() < deadline do
			if pendingAudio and pendingAudio.id == requestId and (pendingAudio.ready[player] or pendingAudio.failed[player]) then break end
			RunService.Heartbeat:Wait()
		end
		if activeToken ~= token then return end
		if not pendingAudio or not pendingAudio.ready[player] then
			stop()
			remote:FireClient(player,"playbackError","Audio could not load. Check the song's permission for this experience, then try again.")
			return
		end
	end

	local events = table.clone(show.events)
	local authoredOrder = {}
	for index, event in events do
		authoredOrder[event] = index
	end
	table.sort(events, function(a, b)
		local aTime, bTime = tonumber(a.t) or 0, tonumber(b.t) or 0
		if aTime == bTime then return authoredOrder[a] < authoredOrder[b] end
		return aTime < bTime
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
				local event = events[nextEvent]
				local success, failure = pcall(apply, event, token, started + (tonumber(event.t) or 0))
				if not success then
					stop()
					remote:FireAllClients("playbackError", tostring(failure))
					warn("Flux Shows stopped: " .. tostring(failure))
					return
				end
				nextEvent += 1
			end
			RunService.Heartbeat:Wait()
		end
		local endsAt = started + math.max(0, tonumber(show.duration) or 0)
		for _, event in events do endsAt = math.max(endsAt, started + (tonumber(event.t) or 0) + (tonumber(event.duration) or 0)) end
		while activeToken == token and workspace:GetServerTimeNow() < endsAt do RunService.Heartbeat:Wait() end
		if activeToken == token then stop() end
	end)
end

remote.OnServerEvent:Connect(function(player, action, value)
	if type(action) ~= "string" then return end
	if action == "audioFailed" then
		if pendingAudio and tostring(value) == pendingAudio.id then pendingAudio.failed[player] = true end
		return
	end
	if action == "audioReady" then
		if pendingAudio and tostring(value) == pendingAudio.id then
			pendingAudio.ready[player] = true
		end
		return
	end
	if not allowed(player) then return end
	if action == "nativeFault" then
		if type(value) == "table" and value.token == activeToken then
			stop()
			remote:FireAllClients("playbackError", tostring(value.message):sub(1,300))
		end
		return
	end
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
