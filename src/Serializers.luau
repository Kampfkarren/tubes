local DistributedNetworks = script:FindFirstAncestor("DistributedNetworks")

local Types = require(DistributedNetworks.Types)

local Serializers = {}

function Serializers.serialize<T, TSerialized>(value: T, serializer: Types.Serializer<T, TSerialized>?): unknown
	if serializer == nil then
		return value
	end

	return serializer.serialize(value :: T)
end

function Serializers.deserialize<T, TSerialized>(value: unknown, serializer: Types.Serializer<T, TSerialized>?): T
	if serializer == nil then
		return value :: T
	end

	return serializer.deserialize(value :: TSerialized)
end

return Serializers
