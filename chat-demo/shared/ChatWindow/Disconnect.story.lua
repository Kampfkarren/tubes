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

	local reconnectTask: thread?

	local root = ReactRoblox.createRoot(target)
	root:render(e(
		provider,
		{},
		e(ChatWindow, {
			channelId = channel.id,
			reconnect = function()
				if reconnectTask ~= nil then
					return
				end

				channel:removeLocalPlayer()

				reconnectTask = task.delay(0.3, function()
					reconnectTask = nil
					channel:addLocalPlayer()
				end)
			end,
		})
	))

	return function()
		channel:destroy()
		root:unmount()

		if reconnectTask ~= nil then
			task.cancel(reconnectTask)
		end
	end
end
