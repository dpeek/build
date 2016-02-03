package build;

import haxe.PosInfos;
import haxe.io.Output;

class Log
{
	public static var level = LogLevel.Info;
	public static var clients(default, null) = new Array<LogClient>();

	#if (macro || neko)
	public static var output(default, null) = new LogOutput(Sys.stdout(), Sys.stderr());
	#else
	public static var console(default, null) = new LogConsole();
	#end

	#if (log_remote && !macro)
	public static var remote(default, null) = new LogRemote();
	#end

	static var indent = 0;
	@:keep static var running = start();

	public static function startGroup()
	{
		indent += 1;
	}

	public static function endGroup()
	{
		if (indent > 0) indent -= 1;
	}

	static function start()
	{
		haxe.Log.trace = logTrace;

		#if (macro || neko)
		addClient(output);
		#else
		addClient(console);
		#end

		#if (log_remote && !macro)
		addClient(remote);
		#end

		return true;
	}

	public static function addClient(client:LogClient)
	{
		clients.push(client);
	}

	public static function removeClient(client:LogClient)
	{
		clients.remove(client);
	}

	public static function logMessage(message:LogMessage)
	{
		if ((message.level:Int) > (level:Int)) return;
		for (client in clients) client.onMessage(message);
	}

	static function logTrace(value:Dynamic, ?info:PosInfos)
	{
		var tags = ['trace'];
		if (info.customParams != null) tags = tags.concat(cast info.customParams);
		logMessage({date:Date.now(), level:LogLevel.Info, value:value, tags:tags, indent:indent, info:info});
	}

	inline public static function error(value:Dynamic, ?tags:Array<String>, ?info:PosInfos)
	{
		#if (!log_level || log_level > 0)
		logMessage({date:Date.now(), level:LogLevel.Error, value:value, tags:tags, indent:indent, info:info});
		#end
	}

	inline public static function warn(value:Dynamic, ?tags:Array<String>, ?info:PosInfos)
	{
		#if (!log_level || log_level > 1)
		logMessage({date:Date.now(), level:LogLevel.Warn, value:value, tags:tags, indent:indent, info:info});
		#end
	}

	inline public static function info(value:Dynamic, ?tags:Array<String>, ?info:PosInfos)
	{
		#if (!log_level || log_level > 2)
		logMessage({date:Date.now(), level:LogLevel.Info, value:value, tags:tags, indent:indent, info:info});
		#end
	}

	inline public static function debug(value:Dynamic, ?tags:Array<String>, ?info:PosInfos)
	{
		#if (!log_level || log_level > 3)
		logMessage({date:Date.now(), level:LogLevel.Debug, value:value, tags:tags, indent:indent, info:info});
		#end
	}

	inline public static function verbose(value:Dynamic, ?tags:Array<String>, ?info:PosInfos)
	{
		#if (!log_level || log_level > 4)
		logMessage({date:Date.now(), level:LogLevel.Verbose, value:value, tags:tags, indent:indent, info:info});
		#end
	}
}

@:enum abstract LogLevel(Int) from Int to Int
{
	var None = 0;
	var Error = 1;
	var Warn = 2;
	var Info = 3;
	var Debug = 4;
	var Verbose = 5;

	@:op(A > B) function gt(b):Bool;
	@:op(A < B) function lt(b):Bool;
	@:op(A >= B) function gteq(b):Bool;
	@:op(A <= B) function lteq(b):Bool;
	@:op(A == B) function eq(b):Bool;
	@:op(A != B) function neq(b):Bool;
}

typedef LogMessage =
{
	var date:Date;
	var level:LogLevel;
	var value:Dynamic;
	var info:PosInfos;
	var indent:Int;
	var tags:Null<Array<String>>;
}

interface LogClient
{
	function onMessage(message:LogMessage):Void;
}

class LogFormatter
{
	public var indent = '  ';

	var wrapColumn = 80;

	var codes = [
		'underline' => [4,24],
		'bold' => [1,22],
		'italic' => [3,23],
		'inverse' => [7,27],
		'black' => [30, 39],
		'red' => [31, 39],
		'green' => [32, 39],
		'yellow' => [33, 39],
		'blue' => [34, 39],
		'magenta' => [35, 39],
		'cyan' => [36, 39],
		'light_gray' => [37, 39],
		'dark_gray' => [90, 39],
		'light_red' => [91, 39],
		'light_green' => [92, 39],
		'light_yellow' => [93, 39],
		'light_blue' => [94, 39],
		'light_magenta' => [95, 39],
		'light_cyan' => [96, 39],
		'white' => [97, 39],
	];

	var styles = [
		'constant' => ['light_magenta'],
		'id' => ['green'],
		'path' => ['underline'],
		'target' => ['light_blue'],
		'line' => ['line'],
		'code' => ['italic'],
		'error' => ['red'],
		'action' => ['yellow'],
		'task' => ['light_blue'],
		'info' => ['light_blue'],
		'question' => ['green'],
		'ok' => ['green'],
		'warn' => ['yellow'],
	];

	public var styleOutput = true;
	public var htmlOutput = false;

	public function new()
	{
		#if sys
		styleOutput = Sys.getEnv('CLICOLOR') == '1';
		#end

		#if js
		htmlOutput = true;
		#end
	}

	public function format(message:LogMessage):String
	{
		var currentIndent = StringTools.rpad('', indent, message.indent * indent.length);

		var tags = message.tags == null ? [] : message.tags;
		var string:String;
		if (tags.indexOf('table') > -1) string = layoutTable(message.value);
		else string = Std.string(message.value);
		string = wrap(string);
		if (tags.indexOf('trace') > -1) string = '<green>${message.info.fileName}</green> $string';
		if (tags.indexOf('no-style') < 0) string = style(string);
		if (tags.indexOf('no-indent') < 0)
			string = currentIndent + string.split('\n').join('\n' + currentIndent);
		if (tags.indexOf('no-newline') < 0) string += '\n';
		return string;
	}

	function wrap(message:String)
	{
		return ~/<wrap>([.\n]+?)<\/wrap>/g.map(message, function (ereg) {
			var chunk = ereg.matched(1);
			var paras = chunk.split('\n\n');
			paras = paras.map(function (para) return para.split('\n').join(' '));
			paras = paras.map(function (para) {
				var column = 0;
				return ~/ ?[^ ]+/g.map(para, function (ereg) {
					var match = ereg.matched(0);
					var content = ~/<(\/?)(\w+)>/g.replace(match, '');
					if (column + content.length > wrapColumn)
					{
						if (match.charAt(0) == ' ') match = match.substr(1);
						if (content.charAt(0) == ' ') content = content.substr(1);
						match = '\n$match';
						column = 0;
					}

					column += content.length;
					return match;
				});
			});
			return paras.join('\n\n');
		});
	}

	function style(message:String):String
	{
		return ~/<(\/?)(\w+)>/g.map(message, function (ereg){
			var open = ereg.matched(1) == '';
			var name = ereg.matched(2);

			var names = [name];
			if (styles.exists(name)) names = styles.get(name);

			var codes = names.map(function (name) {
				var code = 0;
				if (codes.exists(name))
				{
					var pair = codes.get(name);
					code = open ? pair[0] : pair[1];
				}
				var tag = '';
				if (code != 0 && styleOutput)
				{
					if (htmlOutput)
					{
						if (open) tag = '<span class="$name">';
						else tag = '</span>';
					}
					else
					{
						tag = '\033[${code}m';
					}
				}

				return tag;
			});

			return codes.join('');
		});
	}

	function layoutTable(table:Array<Array<String>>):String
	{
		var buf = new StringBuf();
		var lens = [ for (col in 0...table[0].length)
			Lambda.fold(table, function(row,len) return Math.max(row[col].length, len), 0) ];
		for (row in 0...table.length)
		{
			var cols = [];
			for (col in 0...table[row].length)
			{
				var cell = table[row][col];
				if (col < table[row].length - 1)
					cell = StringTools.rpad(cell, ' ', Std.int(lens[col]));
				cols.push(cell);
			}
			buf.add(cols.join('  '));
			if (row < table.length - 1) buf.add('\n');
		}
		return buf.toString();
	}
}

class LogOutput implements LogClient
{
	var formatter = new LogFormatter();
	var html:Bool;
	var output:Output;
	var error:Output;

	public function new(output:Output, ?error:Output)
	{
		this.output = output;
		this.error = error == null ? output : error;
	}

	public function onMessage(message:LogMessage)
	{
		var string = formatter.format(message);
		var output = message.level == Error ? this.error : this.output;
		output.writeString(string);
		output.flush();
	}
}
