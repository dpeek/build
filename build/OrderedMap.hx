package build;

import Map;

class OrderedMap implements IMap<String, Dynamic>
{
	var _keys = new Array<String>();
	var _values = new Array<Dynamic>();

	public function new() {}

	public function get(key:String):Dynamic
	{
		return _values[_keys.indexOf(key)];
	}

	public function set(key:String, value:Dynamic):Void
	{
		remove(key);
		_keys.push(key);
		_values.push(value);
	}

	public function remove(key:String):Bool
	{
		var i = _keys.indexOf(key);
		if (i == -1) return false;
		_keys.splice(i, 1);
		_values.splice(i, 1);
		return true;
	}

	public function exists(key:String):Bool
	{
		return _keys.indexOf(key) > -1;
	}

	public function iterator():Iterator<Dynamic>
	{
		return _values.iterator();
	}

	public function keys():Iterator<String>
	{
		return _keys.iterator();
	}

	public function toString()
	{
		return 'OrderedMap';
	}

	public function clone()
	{
		var clone = new OrderedMap();
		for (i in 0..._keys.length)
		{
			var value:Dynamic = _values[i];
			if (Std.is(value, OrderedMap)) value = value.clone();
			else if (Std.is(value, Array)) value = value.copy();
			clone.set(_keys[i], value);
		}
		return clone;
	}
}
