export type ProcessEvent<ServerState, Event> = (
	currentState: ServerState,
	event: Event,
	userId: number?
) -> ServerState

-- TODO: Use in useChannel for both events and initial state
export type Serializer<T, TSerialized...> = {
	serialize: (T) -> TSerialized...,
	deserialize: (TSerialized...) -> T,
}

export type ChannelSerializers<ServerState, ServerStateSerialized, Event, EventSerialized> = {
	eventSerializer: Serializer<Event, EventSerialized>?,
	stateSerializer: Serializer<ServerState, ServerStateSerialized>?,
}

return {}
