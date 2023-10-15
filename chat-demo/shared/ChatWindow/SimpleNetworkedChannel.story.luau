local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChatWindow = require(script.Parent)
local DistributedNetworks = require(ReplicatedStorage.Packages.DistributedNetworks)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.DevPackages.ReactRoblox)
local ServerState = require(ReplicatedStorage.Demo.ServerState)

local e = React.createElement

return function(target)
	local network, provider = DistributedNetworks.createMockNetwork()

	local channel = network:createChannel(ServerState.process, ServerState.defaultState, ServerState.serializers)
	channel:addLocalPlayer()
	channel:sendEvent({
		type = "addMember",
		userId = network.localUserId,
		name = "You",
	})

	local root = ReactRoblox.createRoot(target)
	root:render(e(
		provider,
		{},
		e(ChatWindow, {
			channelId = channel.id,
		})
	))

	return function()
		root:unmount()
	end
end
