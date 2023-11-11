local Tubes = script.Parent

local Types = require(Tubes.Types)
local createLogger = require(Tubes.createLogger)

local logger = createLogger("safeProcessEvent")

local warnedAbout: { [any]: true } = {}

local function safeProcessEvent<NetworkState, Event>(
	state: NetworkState,
	event: Event,
	processEvent: Types.ProcessEvent<NetworkState, Event>,
	userId: number?
): (NetworkState, boolean)
	local success, newState = pcall(processEvent, state, event, userId)
	if success then
		return newState, true
	else
		if not warnedAbout[event] then
			logger.warn("Event being processed on the client resulted in an error:\n{}\nEvent: {:?}", newState, event)
			warnedAbout[event] = true

			task.delay(10, function()
				warnedAbout[event] = nil
			end)
		end

		return state, false
	end
end

return safeProcessEvent
