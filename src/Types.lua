export type ProcessEvent<ServerState, Event> = (
	currentState: ServerState,
	event: Event,
	userId: number?
) -> ServerState

return {}
