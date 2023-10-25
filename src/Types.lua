export type ProcessEvent<ServerState, Event> = (
	currentState: ServerState,
	event: Event,
	userId: number?
) -> ServerState

export type Serializer<T, TSerialized...> = {
	serialize: (T) -> TSerialized...,
	deserialize: (TSerialized...) -> T,
}

export type ChannelSerializers<ServerState, ServerStateSerialized, Event, EventSerialized> = {
	eventSerializer: Serializer<Event, EventSerialized>?,
	stateSerializer: Serializer<ServerState, ServerStateSerialized>?,
}

-- These take in a message and Rust-style format strings.
-- E.g. `logger.debug("Hello {}", "world")`
-- https://github.com/rojo-rbx/rojo/blob/master/plugin/fmt/init.lua has the implementation of formatting.
export type Logger = {
	debug: (message: string, ...any) -> (),
	warn: (message: string, ...any) -> (),
	error: (message: string, ...any) -> (),
}

export type StatefulEventCallback<ServerState, Event> = (
	serverState: ServerState,
	queueEvent: (Event) -> ServerState
) -> ()

return {}
