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

local generalChannelId = Workspace:GetAttribute("GeneralChannel")
while generalChannelId == nil do
	generalChannelId = Workspace:GetAttributeChangedSignal("GeneralChannel"):Wait()
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
				channelId = generalChannelId,
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
