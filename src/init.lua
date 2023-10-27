local Tubes = {}

local Types = require(script.Types)

Tubes.useChannel = require(script.useChannel)
Tubes.useLocalUserId = require(script.useLocalUserId)

Tubes.RemoteProvider = require(script.RemoteProvider)

Tubes.createNetwork = require(script.createNetwork)
Tubes.createMockNetwork = require(script.createMockNetwork)

export type ChannelSchema<ServerState, ServerStateSerialized, Event, EventSerialized> = Types.ChannelSchema<
	ServerState,
	ServerStateSerialized,
	Event,
	EventSerialized
>

return Tubes
