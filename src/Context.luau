local Players = game:GetService("Players")

local Tubes = script:FindFirstAncestor("Tubes")

local React = require(Tubes.Parent.React)

local LocalPlayer = Players.LocalPlayer

type Destructor = () -> ()

export type ContextType = {
	default: boolean?,

	localUserId: number,
	initialStates: { [string]: any },

	onInitialStateCallback: (callback: (channelId: string, serverState: unknown) -> ()) -> Destructor,
	onReceiveMessageCallback: (callback: (channelId: string, userId: number?, event: unknown) -> ()) -> Destructor,
	onReceiveMessageErrorCallback: (callback: (channelId: string, nonce: string) -> ()) -> Destructor,
	onReceiveMessageSuccessCallback: (callback: (channelId: string, nonce: string) -> ()) -> Destructor,

	sendEventToChannel: (channelId: string, nonce: string, event: unknown) -> (),
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
