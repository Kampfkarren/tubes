local DistributedNetworks = script:FindFirstAncestor("DistributedNetworks")

local React = require(DistributedNetworks.Parent.React)

local Context = require(DistributedNetworks.Context)
local Types = require(DistributedNetworks.Types)

type PendingEvent<Event> = {
	event: Event,
	nonce: number,
}

type NetworkState<ServerState, Event> = {
	channelId: string?,

	-- Last known good server state
	serverState: ServerState?,

	pendingEvents: { PendingEvent<Event> },
}

local function defaultNetworkState<ServerState, Event>(channelId: string?, initialState: ServerState?): NetworkState<ServerState, Event>
	return {
		channelId = channelId,
		serverState = if channelId == nil then initialState else nil,
		pendingEvents = {},
	}
end

-- You are allowed to change channelId at runtime, but the resulting
-- state will not be updated immediately.
-- initialState and processEvent, however, cannot.
-- Does not connect/disconnect from the channel on its own.
-- It is the responsibility of the server to handle that process.
local function useChannel<ServerState, Event>(
	channelId: string?,
	processEvent: Types.ProcessEvent<ServerState, Event>,
	initialState: ServerState?
): (ServerState?, (Event) -> ())
	local context = React.useContext(Context)
	assert(channelId == nil or not context.default, "DistributedNetworks context is not provided, but a channel ID is.")

	assert(channelId ~= nil or initialState ~= nil, "Local channels must provide an initial state")

	local networkState: NetworkState<ServerState, Event>, setNetworkState =
		React.useState(defaultNetworkState(channelId, initialState))

	React.useEffect(function(): (() -> ())?
		if channelId == nil then
			return nil
		end

		setNetworkState(function(currentNetworkState)
			currentNetworkState = table.clone(currentNetworkState)

			if currentNetworkState.channelId ~= channelId then
				currentNetworkState.pendingEvents = {}
			elseif channelId ~= nil then
				assert(
					#currentNetworkState.pendingEvents == 0,
					"TODO: Send previously pending events (and make sure this only happens once)"
				)
			end

			currentNetworkState.channelId = channelId

			currentNetworkState.serverState = if channelId == nil
				then initialState
				else context.initialStates[channelId]

			return currentNetworkState
		end)

		local disconnectOnInitialState = context.onInitialStateCallback(function(receiveChannelId, state)
			setNetworkState(function(currentState)
				if currentState.channelId ~= receiveChannelId then
					return currentState
				end

				assert(currentState.serverState == nil, "Server state is not nil when receiving initial state")

				currentState = table.clone(currentState)
				currentState.serverState = state
				return currentState
			end)
		end)

		local disconnectOnReceiveMessage = context.onReceiveMessageCallback(function(receiveChannelId, event, userId)
			if receiveChannelId ~= channelId then
				return
			end

			setNetworkState(function(currentState)
				if currentState.channelId ~= channelId then
					return currentState
				end

				assert(currentState.serverState ~= nil, "Server state is nil when receiving a message")

				currentState = table.clone(currentState)
				currentState.serverState = processEvent(currentState.serverState, event, userId)
				return currentState
			end)
		end)

		local disconnectOnReceiveMessageSuccess = context.onReceiveMessageSuccessCallback(
			function(receiveChannelId, nonce)
				if receiveChannelId ~= channelId then
					return
				end

				setNetworkState(function(currentState)
					if currentState.channelId ~= channelId then
						return currentState
					end

					local pendingEventIndex = nil
					for index, pendingEvent in currentState.pendingEvents do
						if pendingEvent.nonce == nonce then
							pendingEventIndex = index
							break
						end
					end

					assert(currentState.serverState ~= nil, "Server state is nil when receiving a message")
					assert(pendingEventIndex ~= nil, "Received message success for nonce that is not pending")

					currentState = table.clone(currentState)
					currentState.pendingEvents = table.clone(currentState.pendingEvents)
					local pendingEvent = assert(
						table.remove(currentState.pendingEvents, pendingEventIndex),
						"pendingEventIndex couldn't be removed"
					)
					currentState.serverState =
						processEvent(currentState.serverState, pendingEvent.event, context.localUserId)

					return currentState
				end)
			end
		)

		local disconnectOnReceiveMessageError = context.onReceiveMessageErrorCallback(function(receiveChannelId, nonce)
			error("NYI: Message errors")
		end)

		return function()
			disconnectOnInitialState()
			disconnectOnReceiveMessage()
			disconnectOnReceiveMessageSuccess()
			disconnectOnReceiveMessageError()
		end
	end, { channelId })

	local nonceRef = React.useRef(0)
	assert(nonceRef.current ~= nil, "Luau")
	local nextNonce = React.useCallback(function(): number
		nonceRef.current += 1
		return nonceRef.current
	end, {})

	-- Add this to the list of pending events, then send it to the server if one exists.
	-- If given a channel ID, will wait until we are connected (sent initial state) to send
	-- the events.
	local sendEvent = React.useCallback(function(event: Event)
		local nonce = nextNonce()

		setNetworkState(function(currentNetworkState)
			currentNetworkState = table.clone(currentNetworkState)

			if currentNetworkState.channelId == nil then
				assert(currentNetworkState.serverState ~= nil, "Server state is nil in locally simulated channel")
				currentNetworkState.serverState =
					processEvent(currentNetworkState.serverState, event, context.localUserId)
			else
				currentNetworkState.pendingEvents = table.clone(currentNetworkState.pendingEvents)

				table.insert(currentNetworkState.pendingEvents, {
					event = event,
					nonce = nonce,
				})
			end

			return currentNetworkState
		end)

		-- I think there's a world where you can change channel and send event at the same time?
		if channelId ~= nil then
			context.sendEventToChannel(channelId, nonce, event)
		end
	end, { channelId })

	-- TODO: Validate that this works in React 17 and not just 18
	if channelId ~= networkState.channelId then
		setNetworkState(defaultNetworkState(channelId, initialState))
		return if channelId == nil then initialState else nil, sendEvent
	end

	local predictedState = networkState.serverState
	if predictedState ~= nil then
		for _, pendingEvent in networkState.pendingEvents do
			predictedState = processEvent(predictedState, pendingEvent.event, context.localUserId)
		end
	end

	return predictedState, sendEvent
end

return useChannel
