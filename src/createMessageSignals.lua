local DistributedNetworks = script:FindFirstAncestor("DistributedNetworks")

local createQueuedSignal = require(DistributedNetworks.createQueuedSignal)

local function createMessageSignals(): {
	initialStateSignal: createQueuedSignal.QueuedSignal<
		string, -- Channel ID
		any -- Initial data
	>,

	receiveMessageSignal: createQueuedSignal.QueuedSignal<
		string, -- Channel ID
		any, -- Event
		number? -- User ID
	>,

	receiveMessageErrorSignal: createQueuedSignal.QueuedSignal<
		string, -- Channel ID
		number -- Nonce
	>,

	receiveMessageSuccessSignal: createQueuedSignal.QueuedSignal<
		string, -- Channel ID
		number -- Nonce
	>,
}
	return {
		initialStateSignal = createQueuedSignal(),
		receiveMessageSignal = createQueuedSignal(),
		receiveMessageErrorSignal = createQueuedSignal(),
		receiveMessageSuccessSignal = createQueuedSignal(),
	}
end

return createMessageSignals
