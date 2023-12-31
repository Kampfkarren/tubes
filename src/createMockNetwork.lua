local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Tubes = script.Parent

local React = require(Tubes.Parent.React)

local BaseProvider = require(Tubes.BaseProvider)
local Serializers = require(Tubes.Serializers)
local Signal = require(Tubes.Signal)
local Types = require(Tubes.Types)
local createLogger = require(Tubes.createLogger)
local createQueuedSignal = require(Tubes.createQueuedSignal)
local getShouldSend = require(Tubes.getShouldSend)

local e = React.createElement
local LocalPlayer = Players.LocalPlayer

local logger = createLogger("createMockNetwork")

export type Network = {
	createChannel: <ServerState, Event>(
		self: Network,
		processEvent: Types.ProcessEvent<ServerState, Event>,
		defaultState: ServerState,
		schema: Types.ChannelSchema<ServerState, any, Event, any>?
	) -> Channel<ServerState, Event>,

	localUserId: number,
	ping: number,
}

export type Channel<ServerState, Event> = {
	id: string,
	state: ServerState,

	addLocalPlayer: (self: Channel<ServerState, Event>) -> (),
	removeLocalPlayer: (self: Channel<ServerState, Event>) -> (),

	sendEvent: (self: Channel<ServerState, Event>, event: Event, userId: number?) -> ServerState,

	setShouldErrorCallback: (self: Channel<ServerState, Event>, (event: Event) -> boolean) -> (),

	destroy: (self: Channel<ServerState, Event>) -> (),

	onReceiveEvent: Signal.Signal<unknown>,
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

	receiveDisconnectSignal: createQueuedSignal.QueuedSignal<
		string -- Channel ID
	>,
}
	return {
		initialStateSignal = createQueuedSignal(),
		receiveMessageSignal = createQueuedSignal(),
		receiveMessageErrorSignal = createQueuedSignal(),
		receiveMessageSuccessSignal = createQueuedSignal(),
		receiveDisconnectSignal = createQueuedSignal(),
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
		schema: Types.ChannelSchema<ServerState, any, Event, any>?
	): Channel<ServerState, Event>
		local channel = {}

		channel.id = HttpService:GenerateGUID(false)
		channel.state = defaultState

		channel.onReceiveEvent = Signal.new()

		local shouldSend = getShouldSend(schema)

		local tasks: { [thread]: true } = {}

		local function afterPing(callback: () -> ())
			local delayTask

			if network.ping == 0 then
				delayTask = task.defer(function()
					callback()
					tasks[delayTask] = nil
				end)
			else
				delayTask = task.delay(network.ping, function()
					callback()
					tasks[delayTask] = nil
				end)
			end

			tasks[delayTask] = true
		end

		local localPlayerAdded = false
		channel.addLocalPlayer = function(_: Channel<ServerState, Event>)
			assert(not localPlayerAdded, "addLocalPlayer called twice")
			localPlayerAdded = true

			local initialState = channel.state

			afterPing(function()
				signals.initialStateSignal.fire(
					channel.id,
					Serializers.serialize(initialState, schema and schema.stateSerializer)
				)
			end)
		end

		channel.removeLocalPlayer = function(_: Channel<ServerState, Event>)
			assert(localPlayerAdded, "removeLocalPlayer called before addLocalPlayer")
			localPlayerAdded = false

			afterPing(function()
				signals.receiveDisconnectSignal.fire(channel.id)
			end)
		end

		channel.sendEvent = function(_: Channel<ServerState, Event>, event: Event, userId: number?): ServerState
			local success, newState = pcall(processEvent, channel.state, event, userId)
			if not success then
				logger.warn("Event sent by {} resulted in an error:\n{}\nEvent: {}", userId, newState, event)
				return newState
			end

			local shouldSendResult = shouldSend(newState, channel.state)

			channel.state = newState

			if localPlayerAdded and shouldSendResult then
				afterPing(function()
					signals.receiveMessageSignal.fire(
						channel.id,
						userId,
						Serializers.serialize(event, schema and schema.eventSerializer)
					)
				end)
			end

			return newState
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

			channel.onReceiveEvent:Fire(event)

			afterPing(function()
				local deserializedEvent = Serializers.deserialize(event, schema and schema.eventSerializer)

				if shouldErrorCallback(deserializedEvent) then
					signals.receiveMessageErrorSignal.fire(channel.id, nonce)
					return
				end

				local success, newState = pcall(processEvent, channel.state, deserializedEvent, network.localUserId)
				if not success then
					logger.warn("Event received resulted in an error:\n{}\nEvent: {:?}", newState, event)
					signals.receiveMessageErrorSignal.fire(channel.id, nonce)
					return
				end

				channel.state = newState

				signals.receiveMessageSuccessSignal.fire(channel.id, nonce)
			end)
		end

		channel.destroy = function(_: Channel<ServerState, Event>)
			for ongoingTask in tasks do
				task.cancel(ongoingTask)
			end

			channels[channel.id] = nil
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
			onReceiveDisconnectCallback = signals.receiveDisconnectSignal.connect,

			localUserId = network.localUserId,

			sendEventToChannel = sendEventToChannel,
		}, props.children)
	end

	return network, provider
end

return createMockNetwork
