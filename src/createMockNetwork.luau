local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Tubes = script:FindFirstAncestor("Tubes")

local React = require(Tubes.Parent.React)

local BaseProvider = require(Tubes.BaseProvider)
local Context = require(Tubes.Context)
local Serializers = require(Tubes.Serializers)
local Signal = require(Tubes.Signal)
local Types = require(Tubes.Types)
local createQueuedSignal = require(Tubes.createQueuedSignal)

local e = React.createElement
local LocalPlayer = Players.LocalPlayer

type Network = {
	createChannel: <ServerState, Event>(
		self: Network,
		processEvent: Types.ProcessEvent<ServerState, Event>,
		defaultState: ServerState,
		serializers: Types.ChannelSerializers<ServerState, unknown, Event, unknown>?
	) -> Channel<ServerState, Event>,

	localUserId: number,
	ping: number,
}

type Channel<ServerState, Event> = {
	id: string,
	state: ServerState,

	addLocalPlayer: (self: Channel<ServerState, Event>) -> (),

	sendEvent: (self: Channel<ServerState, Event>, event: Event, userId: number?) -> (),

	setShouldErrorCallback: (self: Channel<ServerState, Event>, (event: Event) -> boolean) -> (),

	_receiveEvent: (self: Channel<ServerState, Event>, nonce: string, event: Event) -> (),
}

-- Trying to simulate RemoteEvents being fired before the UI mounts
local function createMessageSignals(): {
	initialStateSignal: createQueuedSignal.QueuedSignal<
		string, -- Channel ID
		any -- Initial data
	>,

	receiveMessageSignal: createQueuedSignal.QueuedSignal<
		string, -- Channel ID
		number?, -- User ID
		any -- Event
	>,

	receiveMessageErrorSignal: createQueuedSignal.QueuedSignal<
		string, -- Channel ID
		string -- Nonce
	>,

	receiveMessageSuccessSignal: createQueuedSignal.QueuedSignal<
		string, -- Channel ID
		string -- Nonce
	>,
}
	return {
		initialStateSignal = createQueuedSignal(),
		receiveMessageSignal = createQueuedSignal(),
		receiveMessageErrorSignal = createQueuedSignal(),
		receiveMessageSuccessSignal = createQueuedSignal(),
	}
end

local function createMockNetwork(): (Network, React.ComponentType<{
	children: React.ReactNode,
}>)
	local network = {}
	network.ping = 0
	network.localUserId = if LocalPlayer then LocalPlayer.UserId else 0

	local channels: { [string]: Channel<any, any> } = {}

	local signals = createMessageSignals()

	function network.createChannel<ServerState, Event>(
		_: Network,
		processEvent: Types.ProcessEvent<ServerState, Event>,
		defaultState: ServerState,
		serializers: Types.ChannelSerializers<
			ServerState,
			unknown,
			Event,
			unknown
		>?
	): Channel<ServerState, Event>
		local channel = {}

		channel.id = HttpService:GenerateGUID(false)
		channel.state = defaultState

		local localPlayerAdded = false
		channel.addLocalPlayer = function(_: Channel<ServerState, Event>)
			assert(not localPlayerAdded, "addLocalPlayer called twice")
			localPlayerAdded = true

			task.delay(network.ping, function()
				signals.initialStateSignal.fire(
					channel.id,
					Serializers.serialize(channel.state, serializers and serializers.stateSerializer)
				)
			end)
		end

		channel.sendEvent = function(_: Channel<ServerState, Event>, event: Event, userId: number?)
			channel.state = processEvent(channel.state, event, userId)

			task.delay(network.ping, function()
				signals.receiveMessageSignal.fire(
					channel.id,
					userId,
					Serializers.serialize(event, serializers and serializers.eventSerializer)
				)
			end)
		end

		local shouldErrorCallback = function(_: Event)
			return false
		end

		channel.setShouldErrorCallback = function(
			_: Channel<ServerState, Event>,
			newShouldErrorCallback: (event: Event) -> boolean
		)
			shouldErrorCallback = newShouldErrorCallback
		end

		channel._receiveEvent = function(_: Channel<ServerState, Event>, nonce: string, event: unknown)
			assert(localPlayerAdded, "Event sent to channel before local player added")

			task.delay(network.ping, function()
				local deserializedEvent = Serializers.deserialize(event, serializers and serializers.eventSerializer)

				if shouldErrorCallback(deserializedEvent) then
					signals.receiveMessageErrorSignal.fire(channel.id, nonce)
					return
				end

				channel.state = processEvent(channel.state, deserializedEvent, network.localUserId)

				signals.receiveMessageSuccessSignal.fire(channel.id, nonce)
			end)
		end

		channels[channel.id] = channel

		return channel
	end

	local function sendEventToChannel(channelId: string, nonce: string, event: unknown)
		assert(channels[channelId] ~= nil, "sendEventToChannel called for unknown channel")

		local channel = channels[channelId]
		channel:_receiveEvent(nonce, event)
	end

	local function provider(props: {
		children: React.ReactNode,
	})
		return e(BaseProvider, {
			onInitialStateCallback = signals.initialStateSignal.connect,
			onReceiveMessageCallback = signals.receiveMessageSignal.connect,
			onReceiveMessageErrorCallback = signals.receiveMessageErrorSignal.connect,
			onReceiveMessageSuccessCallback = signals.receiveMessageSuccessSignal.connect,

			localUserId = network.localUserId,

			sendEventToChannel = sendEventToChannel,
		}, props.children)
	end

	return network, provider
end

return createMockNetwork
