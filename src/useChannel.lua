local Tubes = script.Parent

local React = require(Tubes.Parent.React)

local Context = require(Tubes.Context)
local Overrides = require(Tubes.Overrides)
local Types = require(Tubes.Types)
local callStatefulEventCallback = require(Tubes.callStatefulEventCallback)
local safeProcessEvent = require(Tubes.safeProcessEvent)

-- You are allowed to change channelId at runtime, but the resulting
-- state will not be updated immediately.
-- initialState, processEvent, and schema, however, cannot.
-- Does not connect/disconnect from the channel on its own.
-- It is the responsibility of the server to handle that process.
-- Only one useChannel can be active per non-local channel ID.
local function useChannel<ServerState, Event>(
	channelId: string?,
	processEvent: Types.ProcessEvent<ServerState, Event>,
	initialState: ServerState?,
	schema: Types.ChannelSchema<ServerState, any, Event, any>?
): (ServerState?, Types.SendEvent<ServerState, Event>)
	local context = React.useContext(Context)

	assert(channelId == nil or not context.default, "Tubes context is not provided, but a channel ID is.")
	assert(channelId ~= nil or initialState ~= nil, "Local channels must provide an initial state")

	local localState, setLocalState = React.useState(initialState)

	local sendLocalEvent = React.useCallback(function(event: Event | Types.StatefulEventCallback<ServerState, Event>)
		local wrappedSafeProcessEvent = function(state: ServerState, sentEvent: Event, userId: number?)
			return (safeProcessEvent(state, sentEvent, processEvent, userId))
		end

		if typeof(event) == "function" then
			setLocalState(function(currentLocalState)
				return callStatefulEventCallback(
					event,
					currentLocalState,
					function() end,
					wrappedSafeProcessEvent,
					context.localUserId
				)
			end)
		else
			setLocalState(function(currentLocalState)
				return wrappedSafeProcessEvent(currentLocalState, event, context.localUserId)
			end)
		end
	end, {})

	React.useEffect(function(): (() -> ())?
		setLocalState(initialState)

		if channelId ~= nil then
			return context.lock(channelId, {
				processEvent = processEvent,
				providedSchema = schema,
			})
		end

		return nil
	end, { channelId })

	local channelState = if channelId == nil
		then nil
		else (
			context.channelStates[channelId] :: Context.ChannelState<any, any>
		) :: Context.ChannelState<ServerState, Event>

	local sendEvent = React.useCallback(function(event: Event | Types.StatefulEventCallback<ServerState, Event>)
		assert(channelId ~= nil, "Networked sendEvent called with local channelId")

		context.sendEventToChannel(channelId, event)
	end, { channelId })

	local predictedState = React.useMemo(
		function(): ServerState?
			if channelState == nil then
				return nil
			end

			local serverState = channelState.serverState
			if serverState == nil or serverState.type ~= "ready" then
				return nil
			end

			Overrides.onPredictingState:Fire(channelId or "???", channelState.pendingEvents)

			local state = serverState.state

			for _, pendingEvent in channelState.pendingEvents do
				state = safeProcessEvent(state, pendingEvent.event, processEvent, context.localUserId)
			end

			return state
		end,
		{ channelId, channelState and channelState.serverState, channelState and channelState.pendingEvents } :: { unknown }
	)

	if channelId == nil then
		return localState, sendLocalEvent
	elseif channelState == nil or channelState.serverState == nil or channelState.serverState.type ~= "ready" then
		return nil, sendEvent
	else
		return predictedState, sendEvent
	end
end

return useChannel
