local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local DistributedNetworks = script:FindFirstAncestor("DistributedNetworks")

local React = require(DistributedNetworks.Parent.React)

local Context = require(DistributedNetworks.Context)
local Signal = require(DistributedNetworks.Signal)
local Types = require(DistributedNetworks.Types)
local createQueuedSignal = require(DistributedNetworks.createQueuedSignal)

local e = React.createElement
local LocalPlayer = Players.LocalPlayer

type Network = {
	createChannel: <ServerState, Event>(
		self: Network,
		processEvent: Types.ProcessEvent<ServerState, Event>,
		defaultState: ServerState
	) -> Channel<ServerState, Event>,
}

type Channel<ServerState, Event> = {
	id: string,
	state: ServerState,

	addPlayer: (self: Channel<ServerState, Event>, player: Player) -> (),

	sendEvent: (self: Channel<ServerState, Event>, event: Event, userId: number?) -> (),
}
