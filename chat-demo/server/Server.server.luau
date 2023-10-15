-- TODO: As part of the demo, add a way to disconnect and reconnect to the same channel
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ServerState = require(ReplicatedStorage.Demo.ServerState)
local Tubes = require(ReplicatedStorage.Packages.Tubes)

local network = Tubes.createNetwork()

local function createChannel()
	local channel = network:createChannel(ServerState.process, ServerState.defaultState, ServerState.serializers)

	Players.PlayerAdded:Connect(function(player)
		channel:addPlayer(player)
		channel:sendEvent({
			type = "addMember",
			userId = player.UserId,
			name = player.DisplayName,
		})
	end)

	Players.PlayerRemoving:Connect(function(player)
		channel:sendEvent({
			type = "removeMember",
			userId = player.UserId,
		})
	end)

	return channel.id
end

Workspace:SetAttribute("Channel1", createChannel())
Workspace:SetAttribute("Channel2", createChannel())
