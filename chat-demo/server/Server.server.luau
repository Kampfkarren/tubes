-- TODO: As part of the demo, add a way to disconnect and reconnect to the same channel
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DistributedNetworks = require(ReplicatedStorage.Packages.DistributedNetworks)
local ServerState = require(ReplicatedStorage.Demo.ServerState)

local network = DistributedNetworks.createNetwork()

local generalChannel = network:createChannel(ServerState.process, ServerState.defaultState)
Workspace:SetAttribute("GeneralChannel", generalChannel.id)

Players.PlayerAdded:Connect(function(player)
	generalChannel:addPlayer(player)
	generalChannel:sendEvent({
		type = "addMember",
		userId = player.UserId,
		name = player.DisplayName,
	})
end)

Players.PlayerRemoving:Connect(function(player)
	generalChannel:sendEvent({
		type = "removeMember",
		userId = player.UserId,
	})
end)
