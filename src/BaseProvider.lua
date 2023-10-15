local Tubes = script.Parent

local React = require(Tubes.Parent.React)

local Context = require(Tubes.Context)
local Serializers = require(Tubes.Serializers)
local deepFreeze = require(Tubes.deepFreeze)
local nonceToString = require(Tubes.nonceToString)

local e = React.createElement

type Destructor = () -> ()

local function defaultChannelState(): Context.ChannelState<unknown, unknown>
	return {
		locked = false,
		schema = nil,

		serverState = nil,

		pendingEvents = {},

		pendingServerEvents = {},
	}
end

local function findByNonce<Event>(pendingEvents: { Context.PendingEvent<Event> }, nonce: string): (number, Event)
	for index, pendingEvent in pendingEvents do
		if pendingEvent.nonce == nonce then
			return index, pendingEvent.event
		end
	end

	error("Received message for unknown nonce")
end

local function BaseProvider(props: {
	localUserId: number,

	onInitialStateCallback: (callback: (channelId: string, serverState: unknown) -> ()) -> Destructor,
	onReceiveMessageCallback: (callback: (channelId: string, userId: number?, event: unknown) -> ()) -> Destructor,
	onReceiveMessageErrorCallback: (callback: (channelId: string, nonce: string) -> ()) -> Destructor,
	onReceiveMessageSuccessCallback: (callback: (channelId: string, nonce: string) -> ()) -> Destructor,
	onReceiveDisconnectCallback: (callback: (channelId: string) -> ()) -> Destructor,

	sendEventToChannel: (channelId: string, nonce: string, serializedEvent: unknown) -> (),

	children: React.ReactNode,
})
	local channelStates: { [string]: Context.ChannelState<unknown, unknown> }, setChannelStates =
		React.useState(deepFreeze({}))

	local sentNoncesRef = React.useRef({} :: { [string]: boolean })
	assert(sentNoncesRef.current ~= nil, "Luau")

	React.useEffect(function()
		local disconnectOnInitialStateCallback = props.onInitialStateCallback(function(channelId, serverState)
			setChannelStates(function(currentChannelStates)
				currentChannelStates = table.clone(currentChannelStates)

				local currentState = currentChannelStates[channelId]
				assert(currentState == nil or currentState.serverState == nil, "Received initial state twice")

				currentState = if currentState then table.clone(currentState) else defaultChannelState()
				currentState.serverState = if currentState.schema
					then {
						type = "ready",
						state = Serializers.deserialize(
							serverState,
							currentState.schema.serializers and currentState.schema.serializers.stateSerializer
						),
					}
					else {
						type = "waitingForSchema",
						serializedState = serverState,
					}

				currentChannelStates[channelId] = currentState

				return deepFreeze(currentChannelStates)
			end)
		end)

		local disconnectOnReceiveMessageCallback = props.onReceiveMessageCallback(function(channelId, userId, event)
			setChannelStates(function(currentChannelStates)
				currentChannelStates = table.clone(currentChannelStates)

				local currentState = currentChannelStates[channelId]
				assert(currentState ~= nil, "Received message for unknown channel")
				currentState = table.clone(currentState)

				if currentState.serverState == nil or currentState.serverState.type ~= "ready" then
					currentState.pendingServerEvents = table.clone(currentState.pendingServerEvents)
					table.insert(currentState.pendingServerEvents, {
						event = event,
						userId = userId,
					})
				else
					assert(
						currentState.schema ~= nil,
						"Received message for channel without schema that was marked as ready"
					)

					currentState.serverState = table.clone(currentState.serverState)
					currentState.serverState.state = currentState.schema.processEvent(
						currentState.serverState.state,
						Serializers.deserialize(
							event,
							currentState.schema.serializers and currentState.schema.serializers.eventSerializer
						),
						userId
					)
				end

				currentChannelStates[channelId] = currentState
				return deepFreeze(currentChannelStates)
			end)
		end)

		local disconnectOnReceiveMessageSuccessCallback = props.onReceiveMessageSuccessCallback(
			function(channelId, nonce)
				sentNoncesRef.current[nonce] = nil

				setChannelStates(function(currentChannelStates)
					currentChannelStates = table.clone(currentChannelStates)

					local currentState = currentChannelStates[channelId]
					assert(currentState ~= nil, "Received message for unknown channel")
					assert(
						currentState.serverState ~= nil
							and currentState.serverState.type == "ready"
							and currentState.schema ~= nil,
						"Received a successful message from a channel we either never received an initial state for, or don't have a schema for"
					)

					currentState = table.clone(currentState)
					currentState.pendingEvents = table.clone(currentState.pendingEvents)

					local index, event = findByNonce(currentState.pendingEvents, nonce)
					table.remove(currentState.pendingEvents, index)

					currentState.serverState = table.clone(currentState.serverState)
					currentState.serverState.state =
						currentState.schema.processEvent(currentState.serverState.state, event, props.localUserId)

					currentChannelStates[channelId] = currentState

					return deepFreeze(currentChannelStates)
				end)
			end
		)

		local disconnectOnReceiveMessageErrorCallback = props.onReceiveMessageErrorCallback(function(channelId, nonce)
			setChannelStates(function(currentChannelStates)
				currentChannelStates = table.clone(currentChannelStates)

				local currentState = currentChannelStates[channelId]
				assert(currentState ~= nil, "Received message for unknown channel")
				assert(
					currentState.serverState ~= nil
						and currentState.serverState.type == "ready"
						and currentState.schema ~= nil,
					"Received a successful message from a channel we either never received an initial state for, or don't have a schema for"
				)

				currentState = table.clone(currentState)
				currentState.pendingEvents = table.clone(currentState.pendingEvents)

				local index = findByNonce(currentState.pendingEvents, nonce)
				table.remove(currentState.pendingEvents, index)

				currentChannelStates[channelId] = currentState

				return deepFreeze(currentChannelStates)
			end)
		end)

		local disconnectOnReceiveDisconnectCallback = props.onReceiveDisconnectCallback(function(channelId)
			setChannelStates(function(currentChannelStates)
				currentChannelStates = table.clone(currentChannelStates)

				local currentState = currentChannelStates[channelId]
				assert(currentState ~= nil, "Received message for unknown channel")

				currentState = table.clone(currentState)
				currentState.serverState = nil
				currentState.pendingServerEvents = {}

				currentChannelStates[channelId] = currentState

				return deepFreeze(currentChannelStates)
			end)
		end)

		return function()
			disconnectOnInitialStateCallback()
			disconnectOnReceiveMessageCallback()
			disconnectOnReceiveMessageSuccessCallback()
			disconnectOnReceiveMessageErrorCallback()
			disconnectOnReceiveDisconnectCallback()
		end
	end, {})

	local nonceRef = React.useRef(0)
	assert(nonceRef.current ~= nil, "Luau")
	local sendEventToChannel = React.useCallback(function(channelId: string, event: unknown)
		local nonce = nonceToString(nonceRef.current)
		nonceRef.current += 1

		-- props.sendEventToChannel(channelId, nonce, serializedEvent)

		setChannelStates(function(currentChannelStates)
			currentChannelStates = table.clone(currentChannelStates)

			local currentState = currentChannelStates[channelId]
			assert(currentState ~= nil, "sendEventToChannel called for unknown channel")

			currentState = table.clone(currentState)
			currentState.pendingEvents = table.clone(currentState.pendingEvents)

			table.insert(currentState.pendingEvents, {
				event = event,
				nonce = nonce,
			})

			currentChannelStates[channelId] = currentState

			return deepFreeze(currentChannelStates)
		end)

		return nonce
	end, {})

	local lock = React.useCallback(
		function<ServerState, Event>(channelId: string, schema: Context.ChannelSchema<ServerState, Event>)
			setChannelStates(function(currentChannelStates)
				currentChannelStates = table.clone(currentChannelStates)
				local currentChannel = currentChannelStates[channelId]

				if currentChannel ~= nil and currentChannel.locked then
					error(
						`{channelId} is already used by something else. You cannot call useChannel twice with the same channel ID.`
					)
				end

				if currentChannel ~= nil and currentChannel.schema == nil then
					assert(
						currentChannel.serverState ~= nil and currentChannel.serverState.type == "waitingForSchema",
						"Cannot change schema after receiving initial state"
					)

					currentChannel = table.clone(currentChannel)
					currentChannel.serverState = if currentChannel.serverState
							and currentChannel.serverState.type == "waitingForSchema"
						then {
							type = "ready",
							state = Serializers.deserialize(
								currentChannel.serverState.serializedState,
								schema.serializers and schema.serializers.stateSerializer
							),
						}
						else currentChannel.serverState
				else
					if currentChannel ~= nil and currentChannel.schema ~= nil then
						assert(
							currentChannel.schema.processEvent == schema.processEvent
								and currentChannel.schema.serializers == schema.serializers,
							"Cannot change schema after passing it to useChannel"
						)
					end

					currentChannel = if currentChannelStates[channelId]
						then table.clone(currentChannelStates[channelId])
						else defaultChannelState()
				end

				currentChannel.schema = schema :: Context.ChannelSchema<any, any>
				currentChannel.locked = true

				if currentChannel.serverState ~= nil then
					assert(
						currentChannel.serverState.type == "ready",
						"Server state should be ready by the time of applying pending server events"
					)

					for _, serializedEvent in currentChannel.pendingServerEvents do
						local event = Serializers.deserialize(
							serializedEvent.event,
							schema.serializers and schema.serializers.eventSerializer
						)

						currentChannel.serverState.state = schema.processEvent(
							currentChannel.serverState.state :: ServerState,
							event,
							serializedEvent.userId
						)
					end

					currentChannel.pendingServerEvents = {}
				end

				currentChannelStates[channelId] = currentChannel

				return deepFreeze(currentChannelStates)
			end)

			return function()
				setChannelStates(function(currentChannelStates)
					currentChannelStates = table.clone(currentChannelStates)

					local currentChannel = table.clone(currentChannelStates[channelId])
					currentChannelStates[channelId] = currentChannel

					assert(currentChannel.locked, "Channel unlocked twice")

					currentChannel.locked = false

					return deepFreeze(currentChannelStates)
				end)
			end
		end,
		{}
	)

	-- Don't send the event until we actually connect to something.
	React.useEffect(function()
		for channelId, channelState in channelStates do
			if channelState.serverState ~= nil and channelState.serverState.type == "ready" then
				assert(channelState.schema ~= nil, "Pending events for channel without schema")

				for _, pendingEvent in channelState.pendingEvents do
					if sentNoncesRef.current[pendingEvent.nonce] then
						continue
					end

					sentNoncesRef.current[pendingEvent.nonce] = true

					props.sendEventToChannel(
						channelId,
						pendingEvent.nonce,
						Serializers.serialize(
							pendingEvent.event,
							channelState.schema.serializers and channelState.schema.serializers.eventSerializer
						)
					)
				end
			end
		end
	end, { channelStates })

	local context: Context.ContextType = {
		localUserId = props.localUserId,

		channelStates = channelStates,

		sendEventToChannel = sendEventToChannel,

		lock = lock,
	}

	return e(Context.Provider, {
		value = context,
	}, props.children)
end

return BaseProvider
