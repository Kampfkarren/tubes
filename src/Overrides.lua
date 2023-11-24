-- Anything in this file can be overridden by the consumer.
-- These APIs are considered stable.
local Tubes = script.Parent

local Context = require(Tubes.Context)
local Signal = require(Tubes.Signal)

local Overrides = {}

-- Fired when calculating the value of useChannel
Overrides.onPredictingState = Signal.new() :: Signal.Signal<
	string, -- channelId
	{ Context.PendingEvent<unknown> } -- events
>

return Overrides
