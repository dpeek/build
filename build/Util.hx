package build;

class Util
{
	public static function getStringValue(value:String):Dynamic
	{
		var floatValue = Std.parseFloat(value);
		if (!Math.isNaN(floatValue) && Std.string(floatValue) == value) return floatValue;

		var intValue = Std.parseInt(value);
		if (intValue != null) return intValue;

		if (value == 'true') return true;
		if (value == 'false') return false;

		return value;
	}

	// public static function setValue(object:Dynamic, path:String, value:Dynamic):Dynamic
	// {
	// 	var fields = path.split('.');
	// 	while (fields.length > 1)
	// 	{
	// 		var field = fields.shift();
	// 		if (!Reflect.hasField(object, field)) Reflect.setField(object, field, {});
	// 		object = Reflect.field(object, field);
	// 	}
	// 	Reflect.setField(object, fields[0], value);
	// 	return object;
	// }

	public static function mergeFields(fromObject:OrderedMap, intoObject:OrderedMap):OrderedMap
	{
		for (key in fromObject.keys())
		{
			var fromValue:Dynamic = fromObject.get(key);
			var toValue:Dynamic = intoObject.get(key);

			if (Std.is(fromValue, Array) && Std.is(toValue, Array))
			{
				var fromArray:Array<Dynamic> = fromValue;
				var toArray:Array<Dynamic> = toValue;
				intoObject.set(key, toArray.concat(fromArray));
			}
			else if (Std.is(fromValue, OrderedMap))
			{
				if (toValue == null)
				{
					toValue = new OrderedMap();
					intoObject.set(key, toValue);
				}
				mergeFields(fromValue, toValue);
			}
			else
			{
				intoObject.set(key, fromValue);
			}
		}
		return intoObject;
	}
}
