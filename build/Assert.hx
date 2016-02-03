package build;

import haxe.PosInfos;

class Assert
{
	static var ERROR_ARGUMENT_NULL = "The argument <id>${argument}</id> to <id>${pos.className}.${pos.methodName}</id> can not be <constant>null</constant>";

	inline public static function argumentNotNull(value:Dynamic, argument:String, ?pos:PosInfos)
	{
		return if (value == null) throw new Error(replaceTokens(ERROR_ARGUMENT_NULL, {argument:argument, pos:pos}));
	}

	inline public static function isTrue(assertion:Bool, message:String, ?context:Dynamic)
	{
		return if (!assertion) throw new Error(replaceTokens('$message', context));
	}

	static function replaceTokens(string:String, ?context:Dynamic)
	{
		if (context == null) return string;
		return ~/\${([\w.]+)}/g.map(string, function (e){
			return resolvePath(e.matched(1), context);
		});
	}

	static function resolvePath(path:String, value:Dynamic)
	{
		var fields = path.split('.');
		while (fields.length > 0)
			value = Reflect.field(value, fields.shift());
		return value;
	}
}
