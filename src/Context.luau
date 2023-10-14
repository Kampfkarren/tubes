local Players = game:GetService("Players")

local DistributedNetworks = script:FindFirstAncestor("DistributedNetworks")

local React = require(DistributedNetworks.Parent.React)

local LocalPlayer = Players.LocalPlayer

type Destructor = () -> ()

export type ContextType = {
	default: boolean?,

	localUserId: number,
	initialStates: { [string]: any },

	onInitialStateCallback: <ServerState>(callback: (channelId: string, serverState: ServerState) -> ()) -> Destructor,
	onReceiveMessageCallback: <Event>(callback: (channelId: string, event: Event, userId: number?) -> ()) -> Destructor,
	onReceiveMessageErrorCallback: (callback: (channelId: string, nonce: number) -> ()) -> Destructor,
	onReceiveMessageSuccessCallback: (callback: (channelId: string, nonce: number) -> ()) -> Destructor,

	sendEventToChannel: <Event>(channelId: string, nonce: number, event: Event) -> (),
}

local default: ContextType = {
	default = true,

	localUserId = if LocalPlayer then LocalPlayer.UserId else 1,
	initialStates = {},

	onInitialStateCallback = nil :: never,
	onReceiveMessageCallback = nil :: never,
	onReceiveMessageErrorCallback = nil :: never,
	onReceiveMessageSuccessCallback = nil :: never,

	sendEventToChannel = nil :: never,
}

local Context: React.Context<ContextType> = React.createContext(default)

return Context
