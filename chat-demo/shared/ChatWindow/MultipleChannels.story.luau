local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChatWindow = require(script.Parent)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.DevPackages.ReactRoblox)
local ServerState = require(ReplicatedStorage.Demo.ServerState)
local Tubes = require(ReplicatedStorage.Packages.Tubes)

local e = React.createElement

return function(target)
	local network, provider = Tubes.createMockNetwork()

	local channel1 = network:createChannel(ServerState.process, ServerState.defaultState, ServerState.serializers)
	channel1:addLocalPlayer()
	channel1:sendEvent({
		type = "addMember",
		userId = network.localUserId,
		name = "You",
	})

	local channel2 = network:createChannel(ServerState.process, ServerState.defaultState, ServerState.serializers)
	channel2:addLocalPlayer()
	channel2:sendEvent({
		type = "addMember",
		userId = network.localUserId,
		name = "You (2)",
	})

	local root = ReactRoblox.createRoot(target)
	root:render(e(
		provider,
		{},
		e(ChatWindow, {
			channelId = channel1.id,
			possibleChannels = {
				channel1.id,
				channel2.id,
			},
		})
	))

	return function()
		root:unmount()
	end
end
