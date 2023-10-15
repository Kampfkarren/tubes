local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChatWindow = require(script.Parent)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.DevPackages.ReactRoblox)

local e = React.createElement

return function(target)
	local root = ReactRoblox.createRoot(target)
	root:render(e(ChatWindow, {}))

	return function()
		root:unmount()
	end
end
