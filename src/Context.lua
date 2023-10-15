local Players = game:GetService("Players")

local Tubes = script.Parent

local React = require(Tubes.Parent.React)

local Types = require(Tubes.Types)

local LocalPlayer = Players.LocalPlayer

type Destructor = () -> ()

export type ChannelSchema<ServerState, Event> = {
	processEvent: Types.ProcessEvent<ServerState, Event>,
	serializers: Types.ChannelSerializers<ServerState, any, Event, any>?,
}

export type PendingEvent<Event> = {
	event: Event,
	nonce: string,
}

export type ChannelState<ServerState, Event> = {
	-- If a useChannel is actively using this
	locked: boolean,

	-- Once set, no part of this can change
	schema: ChannelSchema<ServerState, Event>?,

	serverState: {
		type: "ready",
		state: ServerState,
	} | {
		type: "waitingForSchema",
		serializedState: unknown,
	} | nil,

	pendingEvents: { PendingEvent<Event> },

	-- Events sent from the server before we know how to deserialize them, thus serialized.
	pendingServerEvents: {
		{
			event: unknown,
			userId: number?,
		}
	},
}

export type ContextType = {
	default: boolean?,

	localUserId: number,

	channelStates: {
		[string]: ChannelState<unknown, unknown>,
	},

	sendEventToChannel: (channelId: string, event: unknown, serializedEvent: unknown) -> (),

	lock: <ServerState, Event>(channelId: string, schema: ChannelSchema<ServerState, Event>) -> Destructor,
}

local default: ContextType = {
	default = true,
	localUserId = if LocalPlayer then LocalPlayer.UserId else 1,
	channelStates = {},
	sendEventToChannel = nil :: never,
	setChannelSchema = nil :: never,
	lock = nil :: never,
}

local Context: React.Context<ContextType> = React.createContext(default)

return Context
