local Tubes = script.Parent

local React = require(Tubes.Parent.React)

local Context = require(Tubes.Context)

local function useIsChannelIdLoaded(channelId: string?): boolean
	local context = React.useContext(Context)

	if channelId == nil then
		return true
	end

	assert(not context.default, "useIsChannelIdLoaded called with no Tubes context provider")

	local channelState = context.channelStates[channelId]
	return channelState ~= nil and channelState.serverState ~= nil
end

return useIsChannelIdLoaded
