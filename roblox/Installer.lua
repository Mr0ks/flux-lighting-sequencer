-- Flux Sequencer one-folder installer
-- Run this once from Roblox Studio's Command Bar (View -> Command Bar).
-- It creates Workspace.Fluxline and keeps any existing install as a backup.

local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")

local SOURCE_ROOT = "https://raw.githubusercontent.com/Mr0ks/flux-lighting-sequencer/main/roblox/"
local TOPBAR_PLUS_ASSET_ID = 92368439343389

local function fetch(fileName)
	local ok, result = pcall(function()
		return HttpService:GetAsync(SOURCE_ROOT .. fileName, true)
	end)
	assert(ok, ("Could not download %s. Enable Game Settings -> Security -> Allow HTTP Requests, then try again.\n%s"):format(fileName, tostring(result)))
	return result
end

local sources = {
	Server = fetch("Server.lua"),
	Client = fetch("Client.lua"),
	Config = fetch("Config.lua"),
	ExampleShow = fetch("ExampleShow.lua"),
}

local previous = workspace:FindFirstChild("Fluxline")
if previous then
	previous.Name = "Fluxline_Backup_" .. os.date("!%Y%m%d_%H%M%S")
	warn("The previous Fluxline folder was kept as " .. previous.Name)
end

local root = Instance.new("Folder")
root.Name = "Fluxline"
root.Parent = workspace

local config = Instance.new("ModuleScript")
config.Name = "Config"
config.Source = sources.Config
config.Parent = root

local shows = Instance.new("Folder")
shows.Name = "Shows"
shows.Parent = root

local example = Instance.new("ModuleScript")
example.Name = "ExampleShow"
example.Source = sources.ExampleShow
example.Parent = shows

local server = Instance.new("Script")
server.Name = "Server"
server.RunContext = Enum.RunContext.Server
server.Source = sources.Server
server.Parent = root

local client = Instance.new("Script")
client.Name = "Client"
client.RunContext = Enum.RunContext.Client
client.Source = sources.Client
client.Parent = root

local loaded = InsertService:LoadAsset(TOPBAR_PLUS_ASSET_ID)
local icon = loaded:FindFirstChild("Icon", true)
assert(icon and icon:IsA("ModuleScript"), "The official TopbarPlus asset did not contain its Icon module.")
local topbar = Instance.new("Folder")
topbar.Name = "TopbarPlus"
topbar.Parent = root
icon:Clone().Parent = topbar
loaded:Destroy()

print("Flux Sequencer installed at Workspace.Fluxline")
print("Edit Workspace.Fluxline.Config, then press Play to test the TopbarPlus icon.")
return root
