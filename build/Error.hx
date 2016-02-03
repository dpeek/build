package build;

import haxe.CallStack;

class Error
{
	public var message(default, null):String;
	public var stack(default, null):Array<StackItem>;

	public function new(message:String)
	{
		this.message = message;
		this.stack = CallStack.callStack();
	}

	public function getPosition()
	{
		var buf = new StringBuf();
		for (i in 3...stack.length)
		{
			switch (stack[i])
			{
				case FilePos(_, path, lineNumber):
					if (StringTools.endsWith(path, '?')) continue;
					var path = haxe.io.Path.normalize(path);
					buf.add('\n@ <path>$path:$lineNumber</path>');
				case Method(className, methodName):
					buf.add('\n@ $className.$methodName');
				default:
			}

		}
		return buf.toString();
	}

	public function toString()
	{
		var name = Type.getClassName(Type.getClass(this)).split('.').pop();
		var position = getPosition();
		return '<error>$name:</error> $message$position';
	}
}
