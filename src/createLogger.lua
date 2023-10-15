local Tubes = script.Parent

local Types = require(Tubes.Types)
local fmt = require(Tubes.fmt)

local LOG_FORMAT = "[%s] [%s] [%s] %s"

local function createLogger(key): Types.Logger
	local function logWithLevel(level: string, callback: (string, ...any) -> ())
		return function(...)
			local dateTime = DateTime.now()

			local text = fmt.fmt(...)
			callback(LOG_FORMAT:format(dateTime:FormatUniversalTime("HH:mm:ss:SSS", "en-us"), key, level, text))
		end
	end

	return {
		debug = logWithLevel("DEBUG", print),
		error = logWithLevel("ERROR", function(message)
			error(message, 2)
		end),
		warn = logWithLevel("WARN", warn),
	}
end

return createLogger
