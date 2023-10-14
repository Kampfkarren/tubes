export type ServerState = {
	messages: { Message },
	members: {
		[string]: {
			name: string,
		},
	},
}

export type Message = {
	name: string,
	contents: string,
}

export type Event = {
	type: "addMember",
	userId: number,
	name: string,
} | {
	type: "removeMember",
	userId: number,
} | {
	type: "chat",
	contents: string,
}

local ServerState = {}

local function serverState(x: ServerState)
	return x
end

ServerState.defaultState = serverState({
	messages = {},
	members = {},
})

function ServerState.process(state: ServerState, event: Event, userId: number?): ServerState
	if event.type == "addMember" then
		assert(userId == nil, "Client cannot send addMember")

		state = table.clone(state)
		state.members = table.clone(state.members)
		state.members[tostring(event.userId)] = {
			name = event.name,
		}
		return state
	elseif event.type == "removeMember" then
		assert(userId == nil, "Client cannot send addMember")
		assert(state.members[tostring(event.userId)] ~= nil, "removeMember called for member that doesn't exist")

		state = table.clone(state)
		state.members = table.clone(state.members)
		state.members[tostring(event.userId)] = nil
		return state
	elseif event.type == "chat" then
		assert(userId ~= nil, "Chat message sent without client ID")
		assert(state.members[tostring(userId)] ~= nil, "Chat message sent from unconnected client")
		assert(typeof(event.contents) == "string", "Contents must be a string")

		state = table.clone(state)
		state.messages = table.clone(state.messages)
		table.insert(state.messages, {
			name = state.members[tostring(userId)].name,
			contents = event.contents,
		})
		return state
	else
		local _: never = event.type
		error(`Unexpected event {event.type}`)
	end
end

return ServerState
