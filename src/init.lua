local Tubes = {}

local Types = require(script.Types)
local createMockNetwork = require(script.createMockNetwork)

Tubes.useChannel = require(script.useChannel)

Tubes.useIsChannelLoaded = require(script.useIsChannelIdLoaded)
Tubes.useLocalUserId = require(script.useLocalUserId)

Tubes.RemoteProvider = require(script.RemoteProvider)

Tubes.createNetwork = require(script.createNetwork)

Tubes.createMockNetwork = createMockNetwork
export type MockNetwork = createMockNetwork.Network
export type MockChannel<ServerState, Event> = createMockNetwork.Channel<ServerState, Event>

export type Channel<ServerState, Event> = Types.Channel<ServerState, Event>
export type SendEvent<ServerState, Event> = Types.SendEvent<ServerState, Event>

export type ChannelSchema<ServerState, ServerStateSerialized, Event, EventSerialized> = Types.ChannelSchema<
	ServerState,
	ServerStateSerialized,
	Event,
	EventSerialized
>

return Tubes
