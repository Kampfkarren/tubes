local Tubes = script.Parent

local React = require(Tubes.Parent.React)

local Context = require(Tubes.Context)
local Serializers = require(Tubes.Serializers)
local Types = require(Tubes.Types)
local callStatefulEventCallback = require(Tubes.callStatefulEventCallback)
local createLogger = require(Tubes.createLogger)
local deepFreeze = require(Tubes.deepFreeze)
local getShouldSend = require(Tubes.getShouldSend)
local nonceToString = require(Tubes.nonceToString)
local safeProcessEvent = require(Tubes.safeProcessEvent)

local e = React.createElement

local logger = createLogger("BaseProvider")

type Destructor = () -> ()

local function defaultChannelState(): Context.ChannelState<unknown, unknown>
	return {
		locked = false,
		schema = nil,

		serverState = nil,

		nextNonce = 1,

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

type ChannelStates = { [string]: Context.ChannelState<unknown, unknown> }

local function shiftSendBlocked(userId: number, channelStates: ChannelStates): ChannelStates
	local changed = false

	for index, channelState in channelStates do
		if #channelState.pendingEvents == 0 or not channelState.pendingEvents[1].sendBlocked then
			continue
		end

		if channelState.serverState == nil or channelState.serverState.type ~= "ready" then
			continue
		end
		assert(channelState.serverState ~= nil and channelState.serverState.type == "ready", "Luau")

		assert(channelState.schema ~= nil, "Channel has no schema, but does have pending events and a server state")

		local shouldSend = getShouldSend(channelState.schema.providedSchema)

		if not changed then
			changed = true
			channelStates = table.clone(channelStates)
		end

		local oldestState = channelState.serverState.state
		local currentState = oldestState

		local newChannelState = table.clone(channelState)
		newChannelState.pendingEvents = table.clone(newChannelState.pendingEvents)
		channelStates[index] = newChannelState

		while #newChannelState.pendingEvents > 0 and newChannelState.pendingEvents[1].sendBlocked do
			local blockedPendingEvent = assert(table.remove(newChannelState.pendingEvents, 1), "Luau")

			local stateAfterUpdate =
				safeProcessEvent(currentState, blockedPendingEvent.event, channelState.schema.processEvent, userId)

			if shouldSend(stateAfterUpdate, currentState) then
				logger.warn(
					"{:?} wasn't going to send, but after processing it would've caused a desync. Removing it from pending.",
					blockedPendingEvent.event
				)

				continue
			end

			currentState = stateAfterUpdate
		end

		if currentState ~= oldestState then
			local newState = table.clone(channelState.serverState)
			newState.state = currentState
			newChannelState.serverState = newState
		end
	end

	return channelStates
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
	local channelStates: ChannelStates, setChannelStatesRaw = React.useState(deepFreeze({}))

	local setChannelStates = React.useCallback(
		function(channelStatesOrSetter: ChannelStates | (ChannelStates) -> ChannelStates)
			setChannelStatesRaw(function(currentChannelStates)
				local newChannelStates = if typeof(channelStatesOrSetter) == "function"
					then channelStatesOrSetter(currentChannelStates)
					else currentChannelStates

				if newChannelStates == currentChannelStates then
					return currentChannelStates
				end

				return deepFreeze(shiftSendBlocked(props.localUserId, newChannelStates))
			end)
		end,
		{}
	)

	-- Channel ID -> nonce -> sent?
	-- TODO: Remove successfully sent nonces
	local sentNoncesRef = React.useRef({} :: { [string]: { [string]: boolean } })
	assert(sentNoncesRef.current ~= nil, "Luau")

	React.useEffect(function()
		local disconnectOnInitialStateCallback = props.onInitialStateCallback(function(channelId, serverState)
			sentNoncesRef.current[channelId] = nil

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
							currentState.schema.providedSchema and currentState.schema.providedSchema.stateSerializer
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
					currentState.serverState.state = safeProcessEvent(
						currentState.serverState.state,
						Serializers.deserialize(
							event,
							currentState.schema.providedSchema and currentState.schema.providedSchema.eventSerializer
						),
						currentState.schema.processEvent,
						userId
					)
				end

				currentChannelStates[channelId] = currentState
				return deepFreeze(currentChannelStates)
			end)
		end)

		local disconnectOnReceiveMessageSuccessCallback = props.onReceiveMessageSuccessCallback(
			function(channelId, nonce)
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
					currentState.serverState.state = safeProcessEvent(
						currentState.serverState.state,
						event,
						currentState.schema.processEvent,
						props.localUserId
					)

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

				currentChannelStates[channelId] = nil

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

	local sendEventToChannel = React.useCallback(
		function<ServerState, Event>(channelId: string, event: Event | Types.StatefulEventCallback<ServerState, Event>)
			setChannelStates(function(currentChannelStates)
				currentChannelStates = table.clone(currentChannelStates)

				local currentState = currentChannelStates[channelId]
				if currentState == nil then
					logger.warn("sendEventToChannel called for unknown channel. Event: {:?}", event)
					return currentChannelStates
				end

				currentState = table.clone(currentState)

				local function nextNonce()
					local nonce = nonceToString(currentState.nextNonce)
					currentState.nextNonce += 1
					return nonce
				end

				currentState.pendingEvents = table.clone(currentState.pendingEvents)

				if typeof(event) == "function" then
					assert(
						currentState.serverState ~= nil and currentState.serverState.type == "ready",
						"Stateful event callback needs to have a non-nil state. In the future this may queue."
					)

					assert(currentState.schema ~= nil, "Channel schema doesn't exist")

					local predictedState = currentState.serverState.state
					for _, pendingEvent in currentState.pendingEvents do
						predictedState = safeProcessEvent(
							predictedState,
							pendingEvent.event,
							currentState.schema.processEvent,
							props.localUserId
						)
					end

					local wrappedSafeProcessEvent = function(state, sentEvent, userId: number?)
						return (safeProcessEvent(state, sentEvent, currentState.schema.processEvent, userId))
					end

					callStatefulEventCallback(event, predictedState :: ServerState, function(queuedEvent)
						table.insert(currentState.pendingEvents, {
							event = queuedEvent,
							nonce = nextNonce(),
						})
					end, wrappedSafeProcessEvent :: any, props.localUserId)
				else
					table.insert(currentState.pendingEvents, {
						event = event,
						nonce = nextNonce(),
					})
				end

				currentChannelStates[channelId] = currentState

				return deepFreeze(currentChannelStates)
			end)
		end,
		{}
	)

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
								schema.providedSchema and schema.providedSchema.stateSerializer
							),
						}
						else currentChannel.serverState
				else
					if currentChannel ~= nil and currentChannel.schema ~= nil then
						assert(
							currentChannel.schema.processEvent == schema.processEvent
								and currentChannel.schema.providedSchema == schema.providedSchema,
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
							schema.providedSchema and schema.providedSchema.eventSerializer
						)

						currentChannel.serverState.state = safeProcessEvent(
							currentChannel.serverState.state :: ServerState,
							event,
							schema.processEvent,
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
					if currentChannelStates[channelId] == nil then
						return currentChannelStates
					end

					local currentChannel = table.clone(currentChannelStates[channelId])
					currentChannelStates[channelId] = currentChannel

					assert(currentChannel.locked, "Channel unlocked twice")

					currentChannel.locked = false

					return currentChannelStates
				end)
			end
		end,
		{}
	)

	-- Don't send the event until we actually connect to something.
	React.useEffect(function()
		local didntSend = {}
		local sentNonces = sentNoncesRef.current

		for channelId, channelState in channelStates do
			if channelState.serverState == nil or channelState.serverState.type ~= "ready" then
				continue
			end

			assert(channelState.serverState ~= nil, "Luau")
			assert(channelState.serverState.type == "ready", "Luau")
			assert(channelState.schema ~= nil, "Pending events for channel without schema")

			local expectedState = channelState.serverState.state

			local shouldSend = getShouldSend(channelState.schema.providedSchema)

			for _, pendingEvent in channelState.pendingEvents do
				local oldState = expectedState
				local newState, success = safeProcessEvent(
					expectedState,
					pendingEvent.event,
					channelState.schema.processEvent,
					props.localUserId
				)

				if not success then
					table.insert(didntSend, {
						channelId = channelId,
						pendingEvent = pendingEvent,
					})

					continue
				end

				expectedState = newState

				if
					(sentNonces[channelId] ~= nil and sentNonces[channelId][pendingEvent.nonce])
					or pendingEvent.sendBlocked
				then
					continue
				end

				if not shouldSend(expectedState, oldState) then
					table.insert(didntSend, {
						channelId = channelId,
						pendingEvent = pendingEvent,
					})

					continue
				end

				if sentNonces[channelId] == nil then
					sentNonces[channelId] = {}
				end

				sentNonces[channelId][pendingEvent.nonce] = true

				props.sendEventToChannel(
					channelId,
					pendingEvent.nonce,
					Serializers.serialize(
						pendingEvent.event,
						channelState.schema.providedSchema and channelState.schema.providedSchema.eventSerializer
					)
				)
			end
		end

		if #didntSend > 0 then
			setChannelStates(function(currentChannelStates)
				local newChannelStates = table.clone(currentChannelStates)

				for _, info in didntSend do
					if newChannelStates[info.channelId] == currentChannelStates[info.channelId] then
						newChannelStates[info.channelId] = table.clone(newChannelStates[info.channelId])
						newChannelStates[info.channelId].pendingEvents =
							table.clone(newChannelStates[info.channelId].pendingEvents)
					end

					local pendingEventIndex
					for index, pendingEvent in newChannelStates[info.channelId].pendingEvents do
						if pendingEvent == info.pendingEvent then
							pendingEventIndex = index
							break
						end
					end

					assert(
						pendingEventIndex ~= nil,
						"Couldn't find pending event index of queued pending event that didn't send"
					)

					local newPendingEvent =
						table.clone(newChannelStates[info.channelId].pendingEvents[pendingEventIndex])
					-- TODO: Reuse nonce? I'm thinking a table that we pop from until its empty before making a new nonce.
					-- Otherwise nonces get unnecessarily big faster.
					newPendingEvent.sendBlocked = true
					newChannelStates[info.channelId].pendingEvents[pendingEventIndex] = newPendingEvent
				end

				return shiftSendBlocked(props.localUserId, newChannelStates)
			end)
		end
	end, { channelStates })

	local context: Context.ContextType = {
		localUserId = props.localUserId,

		channelStates = channelStates,

		sendEventToChannel = sendEventToChannel :: any,

		lock = lock,
	}

	return e(Context.Provider, {
		value = context,
	}, props.children)
end

return BaseProvider
