package build;

import haxe.macro.Context;
import haxe.macro.Expr;

class ConfigMacro
{
	static function build()
	{
		var fields = Context.getBuildFields();
		var json = Cli.getJson('build.json');
		for (field in Reflect.fields(json))
		{
			var value = Reflect.field(json, field);
			var type = getType(value);
			fields.push({access:[APublic], name:field, pos:Context.currentPos(), kind:FVar(type, null)});
		}
		return fields;
	}

	static function getType(value:Dynamic):ComplexType
	{
		if (Std.is(value, String)) return TPath({pack:[], name:'String'});
		if (Std.is(value, Int)) return TPath({pack:[], name:'Int'});
		if (Std.is(value, Float)) return TPath({pack:[], name:'Float'});
		if (Std.is(value, Bool)) return TPath({pack:[], name:'Bool'});
		if (Std.is(value, Array))
		{
			var array = (value:Array<String>);
			var elementType = TPath({pack:[], name:'Dynamic'});
			if (array.length > 0)
			{
				elementType = getType(array[0]);
				for (i in 1...array.length)
					mergeType(getType(array[i]), elementType);
			}
			return TPath({pack:[], name:'Array', params:[TPType(elementType)]});
		}
		if (Type.typeof(value) == TObject)
		{
			var fields = [];
			for (field in Reflect.fields(value))
			{
				var field = {
					access:null,
					doc:null,
					meta:null,
					name:field,
					pos:Context.currentPos(),
					kind:FVar(getType(Reflect.field(value, field)), null)
				};
				fields.push(field);
			}
			return TAnonymous(fields);
		}
		return TPath({pack:[], name:'Dynamic'});
	}

	static function mergeType(type:ComplexType, intoType:ComplexType)
	{
		switch ([type, intoType])
		{
			case [TPath(path), TPath(intoPath)]:

			case [TAnonymous(fields), TAnonymous(intoFields)]:
				var intoMap = new Map();
				for (field in intoFields)
					intoMap.set(field.name, field);
				for (field in fields)
				{
					if (intoMap.exists(field.name))
						mergeType(getVarType(field.kind), getVarType(intoMap.get(field.name).kind));
					else intoFields.push(field);
				}
			case [type, intoType]:
				throw 'cannot merge $type into $intoType';
		}
	}

	static function getVarType(kind:FieldType)
	{
		return switch (kind)
		{
			case FVar(type, _): type;
			default: throw 'wtf';
		}
	}
}
