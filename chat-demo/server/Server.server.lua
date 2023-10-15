local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ServerState = require(ReplicatedStorage.Demo.ServerState)
local Tubes = require(ReplicatedStorage.Packages.Tubes)

local network = Tubes.createNetwork()

local channels = {}

local function createChannel()
	local channel = network:createChannel(ServerState.process, ServerState.defaultState, ServerState.serializers)
	channels[channel.id] = channel

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

local reconnecting = {}

ReplicatedStorage.Demo.Reconnect.OnServerEvent:Connect(function(player, channelId)
	local channel = channels[channelId]
	if channel == nil then
		return
	end

	if reconnecting[player] then
		return
	end

	reconnecting[player] = true
	channel:removePlayer(player)

	task.delay(1, function()
		reconnecting[player] = nil
		channel:addPlayer(player)
	end)
end)
