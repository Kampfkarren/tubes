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

	local root = ReactRoblox.createRoot(target)
	root:render(e(
		provider,
		{},
		e(ChatWindow, {
			possibleChannels = {
				channel.id,
			},

			replaceSendEvent = function(sendEvent, contents)
				sendEvent(function(state, queueEvent)
					if #state.messages > 0 then
						queueEvent({
							type = "chat",
							contents = state.messages[#state.messages].contents:upper(),
						})
					end

					queueEvent({
						type = "chat",
						contents = contents,
					})
				end)
			end,
		})
	))

	return function()
		channel:destroy()
		root:unmount()
	end
end
