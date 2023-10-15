-- TODO: Rename to Tubes
local DistributedNetworks = {}

local Types = require(script.Types)

DistributedNetworks.useChannel = require(script.useChannel)
DistributedNetworks.useLocalUserId = require(script.useLocalUserId)

DistributedNetworks.RemoteProvider = require(script.RemoteProvider)

DistributedNetworks.createNetwork = require(script.createNetwork)
DistributedNetworks.createMockNetwork = require(script.createMockNetwork)

export type ChannelSerializers<ServerState, ServerStateSerialized, Event, EventSerialized> = Types.ChannelSerializers<
	ServerState,
	ServerStateSerialized,
	Event,
	EventSerialized
>

return DistributedNetworks
