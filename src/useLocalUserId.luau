local DistributedNetworks = script:FindFirstAncestor("DistributedNetworks")

local React = require(DistributedNetworks.Parent.React)

local Context = require(DistributedNetworks.Context)

local function useLocalUserId(): number
	local context = React.useContext(Context)
	return context.localUserId
end

return useLocalUserId
