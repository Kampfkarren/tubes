local HttpService = game:GetService("HttpService")

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
		print(event, type(event))
		error(`Unexpected event {event.type}`)
	end
end

-- Example of serializers. Not actually more optimized :)
ServerState.schema = {
	eventSerializer = {
		serialize = function(state: Event)
			return HttpService:JSONEncode(state)
		end,

		deserialize = function(serialized)
			return HttpService:JSONDecode(serialized)
		end,
	},

	stateSerializer = {
		serialize = function(state: ServerState)
			return HttpService:JSONEncode(state)
		end,

		deserialize = function(serialized)
			return HttpService:JSONDecode(serialized)
		end,
	},

	shouldSend = function(newState: ServerState, oldState: ServerState)
		if newState == oldState then
			return false
		end

		local lastNewMessage = newState.messages[#newState.messages]

		if lastNewMessage == nil then
			return true
		end

		return lastNewMessage.contents ~= "nosend"
	end,
}

return ServerState
