local Tubes = script:FindFirstAncestor("Tubes")

local React = require(Tubes.Parent.React)

local Context = require(Tubes.Context)
local Serializers = require(Tubes.Serializers)
local Types = require(Tubes.Types)
local nonceToString = require(Tubes.nonceToString)

-- You are allowed to change channelId at runtime, but the resulting
-- state will not be updated immediately.
-- initialState, processEvent, and serializers, however, cannot.
-- Does not connect/disconnect from the channel on its own.
-- It is the responsibility of the server to handle that process.
-- Only one useChannel can be active per non-local channel ID.
local function useChannel<ServerState, Event>(
	channelId: string?,
	processEvent: Types.ProcessEvent<ServerState, Event>,
	initialState: ServerState?,
	serializers: Types.ChannelSerializers<ServerState, unknown, Event, unknown>?
): (ServerState?, (Event) -> ())
	local context = React.useContext(Context)

	assert(channelId == nil or not context.default, "Tubes context is not provided, but a channel ID is.")
	assert(channelId ~= nil or initialState ~= nil, "Local channels must provide an initial state")

	local localState, setLocalState = React.useState(initialState)

	local sendLocalEvent = React.useCallback(function(event: Event)
		setLocalState(function(currentLocalState)
			return processEvent(currentLocalState, event, context.localUserId)
		end)
	end, {})

	React.useEffect(function(): (() -> ())?
		setLocalState(initialState)

		if channelId ~= nil then
			return context.lock(channelId, {
				processEvent = processEvent,
				serializers = serializers,
			})
		end

		return nil
	end, { channelId })

	local channelState = if channelId == nil
		then nil
		else (
			context.channelStates[channelId] :: Context.ChannelState<any, any>
		) :: Context.ChannelState<ServerState, Event>

	local sendEvent = React.useCallback(function(event: Event)
		assert(channelId ~= nil, "Networked sendEvent called with local channelId")

		context.sendEventToChannel(
			channelId,
			event,
			Serializers.serialize(event, serializers and serializers.eventSerializer)
		)
	end, { channelId })

	if channelId == nil then
		return localState, sendLocalEvent
	elseif channelState == nil or channelState.serverState == nil or channelState.serverState.type ~= "ready" then
		return nil, sendEvent
	else
		local state = channelState.serverState.state

		for _, pendingEvent in channelState.pendingEvents do
			state = processEvent(state, pendingEvent.event, context.localUserId)
		end

		return state, sendEvent
	end
end

return useChannel
