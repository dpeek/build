package build;

class Config
{
	static var TOKEN = ~/\${([^}]+)}/g;

	public function new() {}

	var config = new OrderedMap();

	public function setValues(fromConfig:OrderedMap)
	{
		Util.mergeFields(fromConfig, config);
	}

	public function setValue(keyPath:String, value:Dynamic)
	{
		var keys = keyPath.split('.');
		var parent = config;
		while (keys.length > 1)
		{
			var key = keys.shift();
			if (!parent.exists(key))
				parent.set(key, new OrderedMap());
			parent = parent.get(key);
			if (!Std.is(parent, OrderedMap))
				throw new Error('Cannot set $keyPath, value for $key is not an object');
		}
		parent.set(keys[0], value);
	}

	public function getValue<T>(keyPath:String, ?orUseValue:T, ?resolveValue:Bool=true):T
	{
		var keys = keyPath.split('.');
		var value = config;
		while (keys.length > 0)
		{
			var key = keys.shift();
			if (!value.exists(key))
			{
				value = null;
				break;
			}
			value = value.get(key);
			if (keys.length > 1 && !Std.is(value, OrderedMap))
				throw new Error('Cannot get $keyPath, value for $key is not an object');
		}
		if (value == null)
		{
			if (orUseValue == null)
				throw new Error('Value $keyPath not found in config and no default provided.');
			return orUseValue;
		}
		if (resolveValue) return resolve(value);
		else return cast value;
	}

	public function resolveString(value:String):Dynamic
	{
		if (!TOKEN.match(value)) return value;

		var pos = TOKEN.matchedPos();
		if (pos.pos == 0 && pos.len == value.length)
		{
			value = getValue(TOKEN.matched(1));
		}
		else
		{
			value = TOKEN.map(value, function(e){
				return getValue(e.matched(1));
			});
		}

		return resolve(value);
	}

	public function clone()
	{
		var clone = new Config();
		clone.config = config.clone();
		return clone;
	}

	public function setScheme(name:String)
	{
		setValues(getValue('scheme.$name', new OrderedMap(), false));
	}

	public function resolve(value:Dynamic):Dynamic
	{
		if (Std.is(value, String))
		{
			return resolveString(value);
		}
		else if (Std.is(value, Array))
		{
			return value.map(resolve);
		}
		else if (Std.is(value, OrderedMap))
		{
			var map = (value:OrderedMap);
			var resolved = new OrderedMap();
			for (key in map.keys())
				resolved.set(key, resolve(map.get(key)));
			return resolved;
		}
		else if (Type.typeof(value) == TObject)
		{
			var resolved = {};
			for (field in Reflect.fields(value))
				Reflect.setField(resolved, field, resolve(Reflect.field(value, field)));
			return resolved;
		}
		return value;
	}
}
