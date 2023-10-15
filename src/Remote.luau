local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remote = {}

Remote.clientPacketTypeSendInitialState = "a"
Remote.clientPacketTypeReceiveMessage = "c"
Remote.clientPacketTypeReceiveMessageSuccess = "d"
Remote.clientPacketTypeReceiveMessageError = "e"
Remote.clientPacketTypeDisconnect = "f"

local REMOTE_EVENT_NAME = "TubesManagedRemoteEvent"

function Remote.getOrCreateRemoteEvent(): RemoteEvent
	assert(RunService:IsRunning(), "Can't call getOrCreateRemoteEvent unless the server is running")
	assert(RunService:IsServer(), "Can't call getOrCreateRemoteEvent on the client")

	local remoteEvent = ReplicatedStorage:FindFirstChild(REMOTE_EVENT_NAME)
	if remoteEvent ~= nil then
		return remoteEvent
	end

	remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = REMOTE_EVENT_NAME
	remoteEvent.Parent = ReplicatedStorage
	return remoteEvent
end

function Remote.getRemoteEventAsync(): RemoteEvent
	-- Hoarcekat
	assert(RunService:IsRunning(), "Can't call getRemoteEventAsync unless the server is running")
	assert(RunService:IsClient(), "Can't call getRemoteEventAsync on the server")

	return ReplicatedStorage:WaitForChild(REMOTE_EVENT_NAME)
end

return Remote
