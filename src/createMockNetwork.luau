local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local DistributedNetworks = script:FindFirstAncestor("DistributedNetworks")

local React = require(DistributedNetworks.Parent.React)

local Context = require(DistributedNetworks.Context)
local Types = require(DistributedNetworks.Types)
local createMessageSignals = require(DistributedNetworks.createMessageSignals)
local createQueuedSignal = require(DistributedNetworks.createQueuedSignal)

local e = React.createElement

local LocalPlayer = Players.LocalPlayer

type Network = {
	createChannel: <ServerState, Event>(
		self: Network,
		processEvent: Types.ProcessEvent<ServerState, Event>,
		defaultState: ServerState
	) -> Channel<ServerState, Event>,

	localUserId: number,
}

type Channel<ServerState, Event> = {
	id: string,
	state: ServerState,

	addLocalPlayer: (self: Channel<ServerState, Event>) -> (),

	sendEvent: (self: Channel<ServerState, Event>, event: Event, userId: number?) -> (),

	receiveEvent: (self: Channel<ServerState, Event>, event: Event, nonce: number) -> (),
}

local function createMockNetwork(): (Network, React.ComponentType<{
	children: React.ReactNode,
}>)
	local network = {}
	network.localUserId = if LocalPlayer then LocalPlayer.UserId else 0

	local channels: { [string]: Channel<any, any> } = {}

	local signals = createMessageSignals()

	function network.createChannel<ServerState, Event>(
		_self: Network,
		processEvent: Types.ProcessEvent<ServerState, Event>,
		defaultState: ServerState
	): Channel<ServerState, Event>
		local channelId = HttpService:GenerateGUID()

		local channel = {
			id = channelId,
			state = defaultState,

			addLocalPlayer = function(self: Channel<ServerState, Event>)
				signals.initialStateSignal.fire(self.id, self.state)
			end,

			sendEvent = function(self: Channel<ServerState, Event>, event: Event, userId: number?)
				self.state = processEvent(self.state, event)
				signals.receiveMessageSignal.fire(self.id, event, userId)
			end,

			receiveEvent = function(self: Channel<ServerState, Event>, event: Event, nonce: number)
				self.state = processEvent(self.state, event, network.localUserId)
				signals.receiveMessageSuccessSignal.fire(self.id, nonce)
			end,
		}

		channels[channelId] = channel

		return channel
	end

	local function provider(props: {
		children: React.ReactNode,
	}): React.ReactNode
		-- TODO: Add connection to addLocalPlayer to set this
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

		local sendEventToChannel = React.useCallback(function<Event>(channelId: string, nonce: number, event: Event)
			local channel = assert(channels[channelId], "Channel doesn't exist")
			channel:receiveEvent(event, nonce)
		end, {})

		local context: Context.ContextType = {
			localUserId = network.localUserId,
			initialStates = initialStates,

			onInitialStateCallback = signals.initialStateSignal.connect :: any,
			onReceiveMessageCallback = signals.receiveMessageSignal.connect :: any,
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
