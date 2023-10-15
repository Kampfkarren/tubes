-- TODO: createLogger and such for all these error and warn
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tubes = script:FindFirstAncestor("Tubes")

local Remote = require(Tubes.Remote)
local Serializers = require(Tubes.Serializers)
local Types = require(Tubes.Types)
local nonceToString = require(Tubes.nonceToString)

type Network = {
	createChannel: <ServerState, Event>(
		self: Network,
		processEvent: Types.ProcessEvent<ServerState, Event>,
		defaultState: ServerState,
		serializers: Types.ChannelSerializers<ServerState, unknown, Event, unknown>?
	) -> Channel<ServerState, Event>,
}

type Channel<ServerState, Event> = {
	id: string,
	state: ServerState,

	addPlayer: (self: Channel<ServerState, Event>, player: Player) -> (),
	removePlayer: (self: Channel<ServerState, Event>, player: Player) -> (),

	destroy: (self: Channel<ServerState, Event>) -> (),
	sendEvent: (self: Channel<ServerState, Event>, event: Event) -> (),

	-- TODO: With serialization, this must become the serialized representation
	_receiveMessage: (self: Channel<ServerState, Event>, player: Player, nonce: string, event: Event) -> (),
	_players: { [Player]: true },
}

local function createNetwork(): Network
	assert(
		RunService:IsRunning() and RunService:IsServer(),
		"You can only create networks on a running server. If you're using Hoarcekat, use createMockNetwork instead."
	)

	local remoteEvent = Remote.getOrCreateRemoteEvent()

	local channels: { [string]: Channel<any, any> } = {}

	remoteEvent.OnServerEvent:Connect(function(player: Player, channelId: string, nonce: string, ...)
		assert(typeof(channelId) == "string", "Expected channelId to be a string")
		assert(typeof(nonce) == "string", "Expected nonce to be a string")

		local channel = channels[channelId]

		-- Possible if the player sends a message after it's already destroyed, and before they've gotten that message
		if channel == nil then
			warn(`{player} sent to channel {channelId} which doesn't exist`)
			return
		end

		channel:_receiveMessage(player, nonce, ...)
	end)

	local channelNonce = 0

	local network = {}

	function network.createChannel<ServerState, Event>(
		_network: Network,
		processEvent: Types.ProcessEvent<ServerState, Event>,
		defaultState: ServerState,
		serializers: Types.ChannelSerializers<
			ServerState,
			unknown,
			Event,
			unknown
		>?
	): Channel<ServerState, Event>
		local destroyed = false

		local channel = {}
		channel._players = {} :: { [Player]: true }

		channelNonce += 1
		channel.id = nonceToString(channelNonce)

		channel.state = defaultState

		local function sendRemote(player: Player, packetType: string, ...)
			remoteEvent:FireClient(player, packetType, channel.id, ...)
		end

		function channel.addPlayer(self: Channel<ServerState, Event>, player: Player)
			assert(not self._players[player], "Player is already in channel")
			self._players[player] = true
			sendRemote(
				player,
				Remote.clientPacketTypeSendInitialState,
				Serializers.serialize(self.state, serializers and serializers.stateSerializer)
			)
		end

		function channel.removePlayer(self: Channel<ServerState, Event>, player: Player)
			-- TODO: This should send a remote event too so we can clear the initial state
			self._players[player] = nil
		end

		function channel.sendEvent(_: Channel<ServerState, Event>, event: Event)
			assert(not destroyed, "Channel has been destroyed")
			channel.state = processEvent(channel.state, event)

			for player in channel._players do
				sendRemote(
					player,
					Remote.clientPacketTypeReceiveMessage,
					nil,
					Serializers.serialize(event, serializers and serializers.eventSerializer)
				)
			end
		end

		function channel.destroy(_: Channel<ServerState, Event>)
			destroyed = true
			channels[channel.id] = nil
		end

		function channel._receiveMessage(
			_: Channel<ServerState, Event>,
			player: Player,
			nonce: string,
			eventSerialized: Event
		)
			if destroyed then
				warn(`{player} sent to channel {channel.id} which has been destroyed`)
				return
			end

			local successDeserialize, event =
				pcall(Serializers.deserialize, eventSerialized, serializers and serializers.eventSerializer)
			if not successDeserialize then
				warn(`{player} sent to channel {channel.id} with invalid serialized event:\n{eventSerialized}`)
				sendRemote(player, Remote.clientPacketTypeReceiveMessageError, nonce)
				return
			end

			local successProcess, result = pcall(processEvent, channel.state, event, player.UserId)
			if not successProcess then
				-- TODO: Include event data as {:?}
				warn(`Event sent by {player} resulted in an error:\n{result}`)
				sendRemote(player, Remote.clientPacketTypeReceiveMessageError, nonce)
				return
			end

			channel.state = result

			for listeningPlayer in channel._players do
				if listeningPlayer == player then
					sendRemote(listeningPlayer, Remote.clientPacketTypeReceiveMessageSuccess, nonce)
				else
					sendRemote(
						listeningPlayer,
						Remote.clientPacketTypeReceiveMessage,
						player.UserId,
						Serializers.serialize(event, serializers and serializers.eventSerializer)
					)
				end
			end
		end

		channels[channel.id] = channel

		return channel
	end

	Players.PlayerRemoving:Connect(function(player)
		for _, channel in channels do
			if not channel._players[player] then
				continue
			end

			channel:removePlayer(player)
		end
	end)

	return network
end

return createNetwork
