local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local DistributedNetworks = script:FindFirstAncestor("DistributedNetworks")

local React = require(DistributedNetworks.Parent.React)

local Context = require(DistributedNetworks.Context)
local Serializers = require(DistributedNetworks.Serializers)
local Signal = require(DistributedNetworks.Signal)
local Types = require(DistributedNetworks.Types)
local createQueuedSignal = require(DistributedNetworks.createQueuedSignal)

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

	receiveEvent: (self: Channel<ServerState, Event>, event: Event, nonce: string) -> (),
	onReceiveEvent: Signal.Signal<Event>,
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
		_self: Network,
		processEvent: Types.ProcessEvent<ServerState, Event>,
		defaultState: ServerState,
		serializers: Types.ChannelSerializers<
			ServerState,
			unknown,
			Event,
			unknown
		>?
	): Channel<ServerState, Event>
		local channelId = HttpService:GenerateGUID()

		local channel = {
			id = channelId,
			state = defaultState,

			addLocalPlayer = function(self: Channel<ServerState, Event>)
				task.delay(network.ping, function()
					signals.initialStateSignal.fire(
						self.id,
						Serializers.serialize(self.state, serializers and serializers.stateSerializer)
					)
				end)
			end,

			sendEvent = function(self: Channel<ServerState, Event>, event: Event, userId: number?)
				self.state = processEvent(self.state, event, userId)

				task.delay(network.ping, function()
					signals.receiveMessageSignal.fire(
						self.id,
						userId,
						Serializers.serialize(event, serializers and serializers.eventSerializer)
					)
				end)
			end,

			receiveEvent = function(self: Channel<ServerState, Event>, event: Event, nonce: string)
				self.onReceiveEvent:Fire(event)

				task.delay(network.ping, function()
					event = Serializers.deserialize(event, serializers and serializers.eventSerializer)
					self.state = processEvent(self.state, event, network.localUserId)
					signals.receiveMessageSuccessSignal.fire(self.id, nonce)
				end)
			end,

			onReceiveEvent = Signal.new(),
		}

		channels[channelId] = channel

		return channel
	end

	local function provider(props: {
		children: React.ReactNode,
	}): React.ReactNode
		local initialStates, setInitialStates = React.useState({})

		React.useEffect(function()
			return signals.initialStateSignal.connect(function(channelId, initialState)
				setInitialStates(function(currentInitialStates)
					assert(
						currentInitialStates[channelId] == nil,
						"Already sent initial state for channel ID. Are you calling addLocalPlayer twice?"
					)

					currentInitialStates = table.clone(currentInitialStates)
					currentInitialStates[channelId] = initialState :: any
					return currentInitialStates
				end)
			end)
		end, {})

		local sendEventToChannel = React.useCallback(function(channelId: string, nonce: string, event: unknown)
			local channel = assert(channels[channelId], "Channel doesn't exist")
			channel:receiveEvent(event, nonce)
		end, {})

		local context: Context.ContextType = {
			localUserId = network.localUserId,
			initialStates = initialStates,

			onInitialStateCallback = signals.initialStateSignal.connect,
			onReceiveMessageCallback = signals.receiveMessageSignal.connect,
			onReceiveMessageErrorCallback = signals.receiveMessageErrorSignal.connect,
			onReceiveMessageSuccessCallback = signals.receiveMessageSuccessSignal.connect,

			sendEventToChannel = sendEventToChannel,
		}

		return e(Context.Provider, {
			value = context,
		}, props.children)
	end

	return network, provider
end

return createMockNetwork
