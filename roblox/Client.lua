local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("FluxlineSequencer")

local gui = Instance.new("ScreenGui")
gui.Name = "FluxlineShowsGui"; gui.ResetOnSpawn = false; gui.Enabled = false; gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame"); panel.Size=UDim2.fromOffset(430,440); panel.Position=UDim2.fromScale(.5,.5); panel.AnchorPoint=Vector2.new(.5,.5); panel.BackgroundColor3=Color3.fromRGB(25,22,31); panel.Parent=gui; Instance.new("UICorner",panel).CornerRadius=UDim.new(0,18)
local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,-36,0,58);title.Position=UDim2.fromOffset(18,8);title.BackgroundTransparency=1;title.Text="FLUX SHOWS";title.TextColor3=Color3.fromRGB(232,224,240);title.Font=Enum.Font.GothamBold;title.TextSize=22;title.TextXAlignment=Enum.TextXAlignment.Left;title.Parent=panel
local list=Instance.new("ScrollingFrame");list.Size=UDim2.new(1,-36,1,-122);list.Position=UDim2.fromOffset(18,66);list.BackgroundTransparency=1;list.BorderSizePixel=0;list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.ScrollBarThickness=5;list.Parent=panel;local layout=Instance.new("UIListLayout",list);layout.Padding=UDim.new(0,8)
local stop=Instance.new("TextButton");stop.Size=UDim2.new(1,-36,0,42);stop.Position=UDim2.new(0,18,1,-54);stop.BackgroundColor3=Color3.fromRGB(74,44,128);stop.TextColor3=Color3.fromRGB(232,224,240);stop.Text="STOP SHOW";stop.Font=Enum.Font.GothamBold;stop.TextSize=14;stop.Parent=panel;Instance.new("UICorner",stop).CornerRadius=UDim.new(1,0);stop.Activated:Connect(function()remote:FireServer("stop")end)
local top=Instance.new("TextButton");top.Name="FluxlineTopbarButton";top.Size=UDim2.fromOffset(118,36);top.Position=UDim2.fromOffset(16,8);top.BackgroundColor3=Color3.fromRGB(35,31,43);top.TextColor3=Color3.fromRGB(232,224,240);top.Text="✦  Flux Shows";top.Font=Enum.Font.GothamSemibold;top.TextSize=13;top.Visible=false;top.Parent=player.PlayerGui:FindFirstChild("FluxlineTopbar") or (function()local s=Instance.new("ScreenGui");s.Name="FluxlineTopbar";s.ResetOnSpawn=false;s.DisplayOrder=100;s.Parent=player.PlayerGui;return s end)();Instance.new("UICorner",top).CornerRadius=UDim.new(1,0)
top.Activated:Connect(function() gui.Enabled=not gui.Enabled;if gui.Enabled then remote:FireServer("list") end end)
local function render(shows)
	for _,c in list:GetChildren() do if c:IsA("GuiButton") then c:Destroy() end end
	for _,show in shows do local b=Instance.new("TextButton");b.Size=UDim2.new(1,-6,0,58);b.BackgroundColor3=Color3.fromRGB(48,42,58);b.TextColor3=Color3.fromRGB(232,224,240);b.Text=("  %s\n  %ds  ·  %s BPM"):format(show.name,show.duration,show.bpm);b.TextXAlignment=Enum.TextXAlignment.Left;b.Font=Enum.Font.GothamMedium;b.TextSize=14;b.Parent=list;Instance.new("UICorner",b).CornerRadius=UDim.new(0,10);b.Activated:Connect(function()remote:FireServer("play",show.id)end) end
end
remote.OnClientEvent:Connect(function(action,data) if action=="authorized" then top.Visible=true elseif action=="shows" then top.Visible=true;render(data) elseif action=="playing" then title.Text="PLAYING · "..data.name elseif action=="stopped" then title.Text="FLUX SHOWS" end end)
task.delay(1,function()remote:FireServer("list")end)
