local Tubes = script.Parent

local Types = require(Tubes.Types)

local function getShouldSend<ServerState>(
	channelSchema: Types.ChannelSchema<ServerState, any, any, any>?
): (new: ServerState, old: ServerState) -> boolean
	return (channelSchema and channelSchema.shouldSend) or function(x, y)
		return x ~= y
	end :: never
end

return getShouldSend
