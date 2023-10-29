-- Not space (the actual earliest ASCII) for making easier debugging
local EARLIEST_ASCII = 33 -- Exclamation mark
local LATEST_ASCII = 126 -- Tilde

local function nonceToString(nonce: number): string
	local nonceString = ""

	while nonce > 0 do
		local character = string.char(EARLIEST_ASCII + (nonce % (LATEST_ASCII - EARLIEST_ASCII)))
		nonceString ..= character
		nonce = math.floor(nonce / (LATEST_ASCII - EARLIEST_ASCII))
	end

	return nonceString
end

return nonceToString
