local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.DevPackages.ReactRoblox)
local Tubes = require(ReplicatedStorage.Packages.Tubes)

local ChatWindow = require(ReplicatedStorage.Demo.ChatWindow)

local e = React.createElement
local LocalPlayer = Players.LocalPlayer

local channel1Id = Workspace:GetAttribute("Channel1")
while channel1Id == nil do
	channel1Id = Workspace:GetAttributeChangedSignal("Channel1"):Wait()
end

local channel2Id = Workspace:GetAttribute("Channel2")
while channel2Id == nil do
	channel2Id = Workspace:GetAttributeChangedSignal("Channel2"):Wait()
end

local root = ReactRoblox.createRoot(Instance.new("Folder"))

root:render(ReactRoblox.createPortal(
	e(
		Tubes.RemoteProvider,
		{},
		e(
			"ScreenGui",
			{
				IgnoreGuiInset = true,
				ResetOnSpawn = false,
			},
			e(ChatWindow, {
				channelId = channel1Id,
				possibleChannels = {
					channel1Id,
					channel2Id,
				},

				reconnect = function(channelId)
					ReplicatedStorage.Demo.Reconnect:FireServer(channelId)
				end,
			})
		)
	),
	LocalPlayer:WaitForChild("PlayerGui")
))

repeat
	local success = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
until success
