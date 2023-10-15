local Players = game:GetService("Players")

local Tubes = script:FindFirstAncestor("Tubes")

local React = require(Tubes.Parent.React)

local Context = require(Tubes.Context)
local Remote = require(Tubes.Remote)
local Signal = require(Tubes.Signal)

local e = React.createElement
local LocalPlayer = Players.LocalPlayer

local function useSignal<T...>(): (Signal.Signal<T...>, ((T...) -> ()) -> () -> ())
	local signal = React.useRef(Signal.new())
	assert(signal.current ~= nil, "Luau")

	return signal.current,
		React.useCallback(function(callback)
			local connection = signal.current:Connect(callback)

			return function()
				connection:Disconnect()
			end
		end, {})
end

local function RemoteProvider(props: {
	children: React.ReactNode,
})
	local existingContext = React.useContext(Context)
	assert(existingContext.default, "You cannot mount two Tubes providers")

	local initialStates, setInitialStates = React.useState({})

	local initialStateSignal, onInitialStateCallback = useSignal()
	local receiveMessageSignal, onReceiveMessageCallback = useSignal()
	local receiveMessageErrorSignal, onReceiveMessageErrorCallback = useSignal()
	local receiveMessageSuccessSignal, onReceiveMessageSuccessCallback = useSignal()

	local remoteEventRef = React.useRef(nil :: RemoteEvent?)
	React.useEffect(function()
		local onClientEventConnection: RBXScriptConnection?

		task.spawn(function()
			local remoteEvent = Remote.getRemoteEventAsync()
			remoteEventRef.current = remoteEvent

			onClientEventConnection = remoteEvent.OnClientEvent:Connect(function(packetType, ...)
				if packetType == Remote.clientPacketTypeReceiveMessage then
					receiveMessageSignal:Fire(...)
				elseif packetType == Remote.clientPacketTypeReceiveMessageSuccess then
					receiveMessageSuccessSignal:Fire(...)
				elseif packetType == Remote.clientPacketTypeReceiveMessageError then
					receiveMessageErrorSignal:Fire(...)
				elseif packetType == Remote.clientPacketTypeSendInitialState then
					local channelId, state = ...

					setInitialStates(function(currentInitialStates)
						currentInitialStates = table.clone(currentInitialStates)
						currentInitialStates[channelId] = state
						return currentInitialStates
					end)

					initialStateSignal:Fire(...)
				else
					error(`Unknown packet type sent from server: {packetType}`)
				end
			end)
		end)

		return function()
			if onClientEventConnection ~= nil then
				onClientEventConnection:Disconnect()
			end
		end
	end, {})

	local sendEventToChannel = React.useCallback(function(channelId: string, nonce: string, event: unknown)
		local remoteEvent = remoteEventRef.current
		assert(remoteEvent ~= nil, "Sending event to channel without the RemoteEvent being created yet")

		remoteEvent:FireServer(channelId, nonce, event)
	end, {})

	local context: Context.ContextType = {
		localUserId = LocalPlayer.UserId,
		initialStates = initialStates,

		onInitialStateCallback = onInitialStateCallback,
		onReceiveMessageCallback = onReceiveMessageCallback,
		onReceiveMessageErrorCallback = onReceiveMessageErrorCallback,
		onReceiveMessageSuccessCallback = onReceiveMessageSuccessCallback,

		sendEventToChannel = sendEventToChannel,
	}

	return e(Context.Provider, {
		value = context,
	}, props.children)
end

return RemoteProvider
