local Tubes = script.Parent

local Types = require(Tubes.Types)

local function callStatefulEventCallback<ServerState, Event>(
	statefulEventCallback: Types.StatefulEventCallback<ServerState, Event>,
	currentState: ServerState,
	queueEvent: (Event) -> (),
	processEvent: Types.ProcessEvent<ServerState, Event>,
	userId: number
): ServerState
	local queueEventForCallback = function(event)
		currentState = processEvent(currentState, event, userId)
		queueEvent(event)
		return currentState
	end

	statefulEventCallback(currentState, queueEventForCallback)
	return currentState
end

return callStatefulEventCallback
