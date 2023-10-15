local Tubes = script:FindFirstAncestor("Tubes")

local React = require(Tubes.Parent.React)

local Context = require(Tubes.Context)

local function useLocalUserId(): number
	local context = React.useContext(Context)
	return context.localUserId
end

return useLocalUserId
