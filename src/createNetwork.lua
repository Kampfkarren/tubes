local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tubes = script.Parent

local Remote = require(Tubes.Remote)
local Serializers = require(Tubes.Serializers)
local Types = require(Tubes.Types)
local createLogger = require(Tubes.createLogger)
local getShouldSend = require(Tubes.getShouldSend)
local nonceToString = require(Tubes.nonceToString)

type Network = {
	createChannel: <ServerState, Event>(
		self: Network,
		processEvent: Types.ProcessEvent<ServerState, Event>,
		defaultState: ServerState,
		schema: Types.ChannelSchema<ServerState, any, Event, any>?
	) -> Types.Channel<ServerState, Event>,

	setLogger: (self: Network, logger: Types.Logger) -> (),
}

-- You may only call this once per place.
local function createNetwork(): Network
	assert(
		RunService:IsRunning() and RunService:IsServer(),
		"You can only create networks on a running server. If you're using Hoarcekat, use createMockNetwork instead."
	)

	local remoteEvent = Remote.getOrCreateRemoteEvent()
	local logger = createLogger("Network")

	local channels: { [string]: Types.Channel<any, any> } = {}
	local channelNonce = 0

	remoteEvent.OnServerEvent:Connect(function(player: Player, channelId: string, nonce: string, ...)
		if typeof(channelId) ~= "string" then
			logger.warn("{} sent to channel {} which isn't a string", player, channelId)
			return
		end

		if typeof(nonce) ~= "string" then
			logger.warn("{} sent to channel {} which isn't a string", player, nonce)
			return
		end

		local channel = channels[channelId]

		-- Possible if the player sends a message after it's already destroyed, and before they've gotten that message
		if channel == nil then
			logger.warn("{} sent to channel {} which doesn't exist", player, channelId)
			return
		end

		if channel._players[player] == nil then
			logger.warn("{} sent to channel {} which they aren't in", player, channelId)
			return
		end

		channel:_receiveMessage(player, nonce, ...)
	end)

	local network = {}

	function network.createChannel<ServerState, Event>(
		_network: Network,
		processEvent: Types.ProcessEvent<ServerState, Event>,
		defaultState: ServerState,
		schema: Types.ChannelSchema<ServerState, any, Event, any>?
	): Types.Channel<ServerState, Event>
		local destroyed = false

		local channel = {}
		channel._players = {} :: { [Player]: true }

		channelNonce += 1
		channel.id = nonceToString(channelNonce)

		channel.state = defaultState

		local shouldSend = getShouldSend(schema)

		local function sendRemote(player: Player, packetType: string, ...)
			remoteEvent:FireClient(player, packetType, channel.id, ...)
		end

		function channel.addPlayer(self: Types.Channel<ServerState, Event>, player: Player)
			assert(not self._players[player], "Player is already in channel")
			self._players[player] = true
			sendRemote(
				player,
				Remote.clientPacketTypeSendInitialState,
				Serializers.serialize(self.state, schema and schema.stateSerializer)
			)
		end

		function channel.removePlayer(self: Types.Channel<ServerState, Event>, player: Player)
			if not self._players[player] then
				return
			end

			self._players[player] = nil
			sendRemote(player, Remote.clientPacketTypeDisconnect)
		end

		function channel.sendEvent(_: Types.Channel<ServerState, Event>, event: Event)
			assert(not destroyed, "Channel has been destroyed")

			local newState = processEvent(channel.state, event)
			local shouldSendResult = shouldSend(newState, channel.state)
			channel.state = newState

			if not shouldSendResult then
				return
			end

			for player in channel._players do
				sendRemote(
					player,
					Remote.clientPacketTypeReceiveMessage,
					nil,
					Serializers.serialize(event, schema and schema.eventSerializer)
				)
			end
		end

		function channel.destroy(_: Types.Channel<ServerState, Event>)
			destroyed = true
			channels[channel.id] = nil
		end

		function channel._receiveMessage(
			_: Types.Channel<ServerState, Event>,
			player: Player,
			nonce: string,
			eventSerialized: unknown
		)
			if destroyed then
				logger.warn("{} sent to channel {} which has been destroyed", player, channel.id)
				return
			end

			local successDeserialize, event =
				pcall(Serializers.deserialize, eventSerialized, schema and schema.eventSerializer)
			if not successDeserialize then
				logger.warn(
					"{} sent to channel {} with invalid serialized event:\n{}",
					player,
					channel.id,
					eventSerialized
				)

				sendRemote(player, Remote.clientPacketTypeReceiveMessageError, nonce)
				return
			end

			local successProcess, result = pcall(processEvent, channel.state, event, player.UserId)
			if not successProcess then
				logger.warn(
					"Event sent by {} resulted in an error:\n{}\nDeserialized event: {:#?}",
					player,
					result,
					event
				)

				sendRemote(player, Remote.clientPacketTypeReceiveMessageError, nonce)
				return
			end

			local shouldSendResult = shouldSend(result, channel.state)
			channel.state = result

			for listeningPlayer in channel._players do
				if listeningPlayer == player then
					sendRemote(listeningPlayer, Remote.clientPacketTypeReceiveMessageSuccess, nonce)
				elseif shouldSendResult then
					sendRemote(
						listeningPlayer,
						Remote.clientPacketTypeReceiveMessage,
						player.UserId,
						Serializers.serialize(event, schema and schema.eventSerializer)
					)
				end
			end
		end

		channels[channel.id] = channel

		return channel
	end

	function network.setLogger(_: Network, newLogger: Types.Logger)
		logger = newLogger
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
