export type ProcessEvent<ServerState, Event> = (
	currentState: ServerState,
	event: Event,
	userId: number?
) -> ServerState

-- TODO: Use in useChannel for both events and initial state
export type EventSerializer<T, TSerialized...> = {
	serialize: (T) -> TSerialized...,
	deserialize: (TSerialized...) -> T,
}

return {}
