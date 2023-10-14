export type QueuedSignal<T...> = {
	fire: (T...) -> (),
	connect: (callback: (T...) -> ()) -> () -> (),
}

-- Waits until something else listens to this, just like RemoteEvent
local function createQueuedSignal<T...>(): QueuedSignal<T...>
	local callbacks: { (T...) -> () } = {}

	local sentQueue = false
	local queue: { { any } } = {}

	return {
		fire = function(...)
			if sentQueue then
				for _, callback in callbacks do
					callback(...)
				end
			else
				table.insert(queue, table.pack(...))
			end
		end,

		connect = function(callback)
			table.insert(callbacks, callback)

			if not sentQueue then
				sentQueue = true

				for _, queueItem in queue do
					callback(table.unpack(queueItem))
				end

				table.clear(queue)
			end

			return function()
				table.remove(callbacks, (assert(table.find(callbacks, callback), "Can't find callback")))
			end
		end,
	}
end

return createQueuedSignal
