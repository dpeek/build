package build;

// @:build(build.ConfigMacro.build())
class Config
{
	static var TOKEN = ~/\${([^}]+)}/g;

	public function new() {}

	public function setValues(fromConfig:Dynamic)
	{
		Util.mergeFields(fromConfig, this);
	}

	public function setValue(path:String, value:Dynamic)
	{
		var parts = path.split('.');
		var parent = this;
		while (parts.length > 1)
		{
			var part = parts.shift();
			if (!Reflect.hasField(parent, part))
				Reflect.setField(parent, part, {});
			parent = Reflect.field(parent, part);
		}
		Reflect.setField(parent, parts[0], value);
	}

	public function getValue<T>(path:String, ?orUseValue:T):T
	{
		var parts = path.split('.');
		var value = this;
		while (parts.length > 0)
		{
			var part = parts.shift();
			value = Reflect.field(value, part);
			if (value == null) break;
		}
		if (value == null)
		{
			if (orUseValue == null)
				throw new Error('Value $path not found in config and no default provided.');
			return orUseValue;
		}
		return resolve(value);
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
		return Reflect.copy(this);
	}

	public function setScheme(name:String)
	{
		setValues(getValue('scheme.$name', {}));
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
