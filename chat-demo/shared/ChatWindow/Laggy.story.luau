local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChatWindow = require(script.Parent)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.DevPackages.ReactRoblox)
local ServerState = require(ReplicatedStorage.Demo.ServerState)
local Tubes = require(ReplicatedStorage.Packages.Tubes)

local e = React.createElement

return function(target)
	local network, provider = Tubes.createMockNetwork()
	network.ping = 0.5

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

	local loopTask = task.spawn(function()
		while true do
			channel:sendEvent({
				type = "chat",
				contents = "ME ORC ME SPAM NO MODS NO BAN",
			}, 1)
			task.wait(0.4)
		end
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
		channel:destroy()
		task.cancel(loopTask)
		root:unmount()
	end
end
