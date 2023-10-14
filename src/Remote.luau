local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remote = {}

Remote.clientPacketTypeSendInitialState = "a"
Remote.serverPacketTypeSendMessage = "b"
Remote.clientPacketTypeReceiveMessage = "c"
Remote.clientPacketTypeReceiveMessageSuccess = "d"
Remote.clientPacketTypeReceiveMessageError = "e"

local REMOTE_EVENT_NAME = "DistributedNetworksManagedRemoteEvent"

function Remote.getRemoteEventAsync(): RemoteEvent
	-- Hoarcekat
	assert(RunService:IsRunning(), "Can't call getRemoteEventAsync unless the server is running")

	if RunService:IsServer() then
		local remoteEvent = ReplicatedStorage:FindFirstChild(REMOTE_EVENT_NAME)
		if remoteEvent ~= nil then
			return remoteEvent
		end

		remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = REMOTE_EVENT_NAME
		remoteEvent.Parent = ReplicatedStorage
		return remoteEvent
	else
		return ReplicatedStorage:WaitForChild(REMOTE_EVENT_NAME)
	end
end

return Remote
