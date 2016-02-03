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

	public static function mergeFields(fromObject:Dynamic, intoObject:Dynamic):Dynamic
	{
		for (field in Reflect.fields(fromObject))
		{
			var fromValue:Dynamic = Reflect.field(fromObject, field);
			var toValue:Dynamic = Reflect.field(intoObject, field);

			if (Std.is(fromValue, Array) && Std.is(toValue, Array))
			{
				var fromArray:Array<Dynamic> = fromValue;
				var toArray:Array<Dynamic> = toValue;
				Reflect.setField(intoObject, field, fromArray.concat(toArray));
			}
			else if (Type.typeof(fromValue) == TObject)
			{
				if (toValue == null)
				{
					toValue = {};
					Reflect.setField(intoObject, field, toValue);
				}
				else
				{
					// prevent overwrite
				}
				mergeFields(fromValue, toValue);
			}
			else
			{
				Reflect.setField(intoObject, field, fromValue);
			}
		}
		return intoObject;
	}
}
