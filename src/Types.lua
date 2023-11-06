local Tubes = script.Parent

local Signal = require(Tubes.Signal)

export type Channel<ServerState, Event> = {
	id: string,
	state: ServerState,

	addPlayer: (self: Channel<ServerState, Event>, player: Player) -> (),
	removePlayer: (self: Channel<ServerState, Event>, player: Player) -> (),

	destroy: (self: Channel<ServerState, Event>) -> (),
	sendEvent: (self: Channel<ServerState, Event>, event: Event) -> (),

	onReceiveEvent: Signal.Signal<Player, Event>,

	_receiveMessage: (self: Channel<ServerState, Event>, player: Player, nonce: string, event: unknown) -> (),
	_players: { [Player]: true },
}

export type ProcessEvent<ServerState, Event> = (
	currentState: ServerState,
	event: Event,
	userId: number?
) -> ServerState

export type Serializer<T, TSerialized...> = {
	serialize: (T) -> TSerialized...,
	deserialize: (TSerialized...) -> T,
}

export type ChannelSchema<ServerState, ServerStateSerialized, Event, EventSerialized> = {
	eventSerializer: Serializer<Event, EventSerialized>?,
	stateSerializer: Serializer<ServerState, ServerStateSerialized>?,

	shouldSend: ((newState: ServerState, oldState: ServerState) -> boolean)?,
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

export type SendEvent<ServerState, Event> = (Event | StatefulEventCallback<ServerState, Event>) -> ()

return {}
