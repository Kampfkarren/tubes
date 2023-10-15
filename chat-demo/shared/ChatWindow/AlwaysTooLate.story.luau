local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChatWindow = require(script.Parent)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.DevPackages.ReactRoblox)
local ServerState = require(ReplicatedStorage.Demo.ServerState)
local Tubes = require(ReplicatedStorage.Packages.Tubes)

local e = React.createElement

return function(target)
	local network, provider = Tubes.createMockNetwork()

	local channel = network:createChannel(ServerState.process, ServerState.defaultState, ServerState.serializers)
	channel:addLocalPlayer()

	channel:sendEvent({
		type = "addMember",
		userId = network.localUserId,
		name = "You",
	})

	channel:sendEvent({
		type = "addMember",
		userId = 1,
		name = "Chatterbox",
	})

	channel.onReceiveEvent:Connect(function()
		channel:sendEvent({
			type = "chat",
			contents = "Too slow!",
		}, 1)
	end)

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
