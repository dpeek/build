package build;

class Json
{
	public static inline function parse( text : String ) : Dynamic
	{
		return JsonParser.parse(text);
	}

	public static inline function stringify( value : Dynamic, ?replacer:Dynamic -> Dynamic -> Dynamic, ?space : String ) : String
	{
		return JsonPrinter.print(value, replacer, space);
	}
}
