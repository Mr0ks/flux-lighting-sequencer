-- Studio-time source adapter. Contains no native Flux source.
-- Adds cancellation only to macros started by Flux Shows.
local PREFIX = [====[
-- Flux Shows cancellable native macro adapter.
local realTask, realCoroutine = task, coroutine
local scopes, threadScope = {}, setmetatable({}, {__mode="k"})
local taskProxy, coroutineProxy = table.clone(task), table.clone(coroutine)
local function complete(scope)
	for thread in pairs(scope.threads) do
		if realCoroutine.status(thread)=="dead" then scope.threads[thread]=nil;threadScope[thread]=nil end
	end
	if not scope.starting and not next(scope.threads) and scopes[scope.id]==scope then
		scopes[scope.id]=nil
		local remote=game:GetService("ReplicatedStorage"):FindFirstChild("FluxlineSequencer")
		if remote then remote:FireServer("nativeMacroFinished",scope.id) end
	end
end
local function schedule(method, delaySeconds, fn, ...)
	local scope = threadScope[realCoroutine.running()]
	if not scope then
		if method=="delay" then return realTask.delay(delaySeconds,fn,...) end
		return realTask[method](fn,...)
	end
	local args=table.pack(...)
	local function run()
		local thread=realCoroutine.running()
		threadScope[thread]=scope
		scope.threads[thread]=true
		local ok,err=pcall(fn,table.unpack(args,1,args.n))
		scope.threads[thread]=nil;threadScope[thread]=nil
		complete(scope)
		if not ok then error(err,0) end
	end
	local thread
	if type(fn)=="thread" then
		thread=fn;threadScope[thread]=scope
		if method=="delay" then realTask.delay(delaySeconds,fn,...) else realTask[method](fn,...) end
	elseif method=="delay" then thread=realTask.delay(delaySeconds,run)
	else thread=realTask[method](run) end
	if realCoroutine.status(thread)~="dead" then scope.threads[thread]=true end
	return thread
end
taskProxy.spawn=function(fn,...) return schedule("spawn",nil,fn,...) end
taskProxy.defer=function(fn,...) return schedule("defer",nil,fn,...) end
taskProxy.delay=function(seconds,fn,...) return schedule("delay",seconds,fn,...) end
coroutineProxy.create=function(fn)
	local scope=threadScope[realCoroutine.running()]
	if not scope then return realCoroutine.create(fn) end
	local thread=realCoroutine.create(function(...)
		local results=table.pack(pcall(fn,...))
		if scope then scope.threads[realCoroutine.running()]=nil;threadScope[realCoroutine.running()]=nil;complete(scope) end
		if not results[1] then error(results[2],0) end
		return table.unpack(results,2,results.n)
	end)
	if scope then threadScope[thread]=scope;scope.threads[thread]=true end
	return thread
end
coroutineProxy.wrap=function(fn)
	if not threadScope[realCoroutine.running()] then return realCoroutine.wrap(fn) end
	local thread=coroutineProxy.create(fn)
	return function(...)
		local result=table.pack(realCoroutine.resume(thread,...))
		if not result[1] then error(result[2],2) end
		return table.unpack(result,2,result.n)
	end
end
local function loadNative(...)
]====]
local SUFFIX = [====[
end
local environment=setmetatable({task=taskProxy,coroutine=coroutineProxy},{__index=getfenv(loadNative)})
setfenv(loadNative,environment)
local exported=loadNative(...)
local nativeState
local init = exported.init
exported.init = function(context, state, ...)
	nativeState = state
	return init(context, state, ...)
end

function exported.FluxShowsScopeEffect(fixture, source, alias, group)
	local effects = nativeState and nativeState.effects[fixture]
	local preset = effects and effects[source]
	if not preset or type(preset.meta) ~= "table" then return end
	local copy = table.clone(preset)
	copy.hide = true
	copy.meta = {}
	for index, layer in pairs(preset.meta) do
		local scoped = table.clone(layer)
		scoped.group = group
		copy.meta[index] = scoped
	end
	effects[alias] = copy
end

function exported.FluxShowsReleaseEffect(fixture, alias)
	local effects = nativeState and nativeState.effects[fixture]
	if effects then effects[alias] = nil end
end

function exported.FluxShowsCancel(id)
	local scope=scopes[id]
	if not scope then return end
	scopes[id]=nil
	for thread in pairs(scope.threads) do
		if thread~=realCoroutine.running() and realCoroutine.status(thread)~="dead" then pcall(realTask.cancel,thread) end
		threadScope[thread]=nil
	end
end
function exported.FluxShowsMacro(id,fixture,name)
	exported.FluxShowsCancel(id)
	local scope={id=id,threads={},starting=true}
	scopes[id]=scope
	local thread=realCoroutine.running()
	local previous=threadScope[thread]
	threadScope[thread]=scope
	local ok,result=pcall(exported.macro,fixture,name)
	threadScope[thread]=previous
	scope.starting=false
	complete(scope)
	realTask.spawn(function()
		while scopes[id]==scope do complete(scope);realTask.wait(.1) end
	end)
	if not ok then exported.FluxShowsCancel(id);error(result) end
end
script:SetAttribute("FluxShowsMacroAdapterReady",true)
return exported
]====]
return function(original)
    assert(type(original)=="string", "Expected the native functions module source")
    local marker = "-- Flux Shows cancellable native macro adapter."
    if original:sub(1, #marker) == marker then
        local _, first = original:find("local function loadNative(...)\n", 1, true)
        local last = original:find("\nend\nlocal environment=setmetatable", first and first + 1 or 1, true)
        assert(first and last, "Cannot upgrade the existing Flux adapter")
        original = original:sub(first + 1, last - 1)
    end
    return PREFIX .. original .. "\n" .. SUFFIX
end
