package build;

import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

import haxe.Timer;
import haxe.Http;
import haxe.PosInfos;

import haxe.io.Path;
import haxe.io.Output;
import haxe.io.Input;
import haxe.xml.Fast;

import neko.vm.Thread;

class Cli
{
	static var ERROR_GET_CONTENT = "Can not get content of file <path>${path}</path>";
	static var ERROR_DELETE_FILE = "Can not delete file <path>${path}</path>";
	static var ERROR_RENAME = "Can not rename <path>${path}</path> to <path>${newPath}</path>";
	static var ERROR_CREATE_DIRECTORY = "Can not create directory <path>${path}</path>";
	static var ERROR_SAVE_CONTENT = "Can not save content to <path>${path}</path>";
	static var ERROR_CWD = "Can not change current working directory to <path>${path}</path>";
	static var ERROR_IS_LINK = "Can not determine if <path>${path}</path> is a link";
	static var ERROR_IS_DIRECTORY_EMPTY = "Can not determine if <path>${path}</path> is an empty directory";
	static var ERROR_DELETE_DIRECTORY = "Can not delete directory <path>${path}</path>";
	static var ERROR_DELETE_DIRECTORY_RECURSIVE = "Can not delete directory <path>${path}</path> recursively";
	static var ERROR_READ_DIRECTORY = "Can not read directory <path>${path}</path>";
	static var ERROR_ZIP = "Can not create zip from <path>${fromPath}</path> to <path>${toPath}</path>";
	static var ERROR_COPY_FILE = "Can not copy file <path>${path}</path> to <path>${newPath}</path>";

	static var REASON_PATH_NOT_EXIST = "The path <path>${fullPath}</path> does not exist";
	static var REASON_PATH_EXISTS_AND_NOT_FILE = "The path <path>${fullPath}</path> exists and is not a file";
	static var REASON_PATH_NOT_DIRECTORY = "The path <path>${fullPath}</path> is not a directory";
	static var REASON_DIRECTORY_NOT_EMPTY = "The directory <path>${fullPath}</path> is not empty";
	static var REASON_PARENT_DIRECTORY_NOT_EXIST = "The parent directory <path>${parent}</path> does not exist";
	static var REASON_PARENT_DIRECTORY_IS_NOT_DIRECTORY = "The parent directory <path>${parent}</path> is not a directory";
	static var REASON_PATH_EXISTS_AND_NOT_DIRECTORY = "The path <path>${fullPath}</path> exists and is not a directory";

	/**
		Is the application currently running on a Win32 system.
	**/
	public static var isWindows(default, null):Bool = Sys.systemName() == "Windows";

	/**
		Is the application currently running on a Win32 system.
	**/
	public static var isMac(default, null):Bool = Sys.systemName() == "Mac";

	/**
		Is the application currently running on a Linux system.
	**/
	public static var isLinux(default, null):Bool = Sys.systemName() == "Linux";

	/**
		Is the application currently running on a unix like system (Mac or Linux)
	**/
	public static var isUnix(default, null):Bool = isMac || isLinux;

	/**
		Is the application running under cygwin.
	**/
	public static var isCygwin(default, null):Bool = isWindows && Sys.getEnv("QMAKESPEC") != null && Sys.getEnv("QMAKESPEC").indexOf("cygwin") > -1;

	/**
		The users home directory: ~/ on posix systems, \Users\username on Win32 systems.
	**/
	public static var userDirectory(default, null):String = isWindows ? Sys.getEnv("USERPROFILE") : Sys.getEnv("HOME");

	/**
	The system temp directory.
	*/
	public static var tempDirectory(default, null):String =
	{
		if (isWindows) Sys.getEnv("TEMP");
		else if (isUnix) Sys.getEnv("TMPDIR");
		else "/tmp";
	}

	/**
		The system application data directory.
	**/
	public static var dataDirectory(default, null):String =
	{
		if (isWindows) Sys.getEnv("APPDATA");
		else if (isMac) userDirectory + "/Library/Application Support";
		else userDirectory;
	}

	public static function exists(path:String):Bool
	{
		Assert.argumentNotNull(path, 'path');
		return isLink(path) || FileSystem.exists(path);
	}

	public static function isDirectory(path:String):Bool
	{
		Assert.argumentNotNull(path, 'path');
		return exists(path) && !isLink(path) && FileSystem.isDirectory(path);
	}

	public static function isFile(path:String):Bool
	{
		Assert.argumentNotNull(path, 'path');
		return exists(path) && !FileSystem.isDirectory(path);
	}

	public static function isLink(path:String):Bool
	{
		return false;
		// Assert.argumentNotNull(path, 'path');
		// return new Process('test', ['-L', path]).exitCode() == 0;
	}

	public static function isDirectoryEmpty(path:String):Bool
	{
		Assert.argumentNotNull(path, 'path');
		Assert.isTrue(exists(path), '$ERROR_IS_DIRECTORY_EMPTY\n$REASON_PATH_NOT_EXIST', {path: path, fullPath: fullPath(path)});
		Assert.isTrue(isDirectory(path), '$ERROR_IS_DIRECTORY_EMPTY\n$REASON_PATH_NOT_DIRECTORY', {path: path, fullPath: fullPath(path)});
		return readDirectory(path).length == 0;
	}

	public static function getCwd()
	{
		return Path.removeTrailingSlashes(Sys.getCwd());
	}

	public static function setCwd(path:String)
	{
		Assert.argumentNotNull(path, 'path');
		Assert.isTrue(exists(path), '$ERROR_CWD\n$REASON_PATH_NOT_EXIST', {path: path, fullPath: fullPath(path)});
		// Assert.isTrue(isDirectory(path), '$ERROR_CWD\n$REASON_PATH_NOT_DIRECTORY', {path: path, fullPath: fullPath(path)});
		return Sys.setCwd(path);
	}

	public static function fullPath(path:String)
	{
		Assert.argumentNotNull(path, 'path');
		return Path.normalize(getCwd() + '/' + path);
	}

	public static function getContent(path:String):String
	{
		Assert.argumentNotNull(path, 'path');
		Assert.isTrue(exists(path), '$ERROR_GET_CONTENT\n$REASON_PATH_NOT_EXIST', {path: path, fullPath: fullPath(path)});
		return File.getContent(path);
	}

	public static function getJson(path:String):Dynamic
	{
		var json = getContent(path);
		try
		{
			return Json.parse(json);
		}
		catch (e:Dynamic)
		{
			var ereg = ~/Invalid char (\d+) at position (\d+)/;
			if (ereg.match(Std.string(e)))
			{
				var lineNum = 1;
				var char = String.fromCharCode(Std.parseInt(ereg.matched(1)));
				var position = Std.parseInt(ereg.matched(2));
				for (line in json.split('\n'))
				{
					var lineLength = line.length + 1;
					if (position - lineLength < 0) break;
					position -= lineLength;
					lineNum += 1;
				}
				throw new Error('$path:$lineNum invalid character "$char"');
			}
			return null;
		}
	}

	public static function saveContent(path:String, content:String):Void
	{
		Assert.argumentNotNull(path, 'path');
		Assert.argumentNotNull(content, 'content');
		if (exists(path))
			Assert.isTrue(isFile(path), '$ERROR_SAVE_CONTENT\n$REASON_PATH_EXISTS_AND_NOT_FILE', {path: path, fullPath: fullPath(path)});
		var parent = Path.directory(path);
		if (parent.length > 0)
		{
			Assert.isTrue(exists(parent), '$ERROR_SAVE_CONTENT\n$REASON_PARENT_DIRECTORY_NOT_EXIST', {path: path, parent: fullPath(parent)});
			Assert.isTrue(isDirectory(parent), '$ERROR_SAVE_CONTENT\n$REASON_PARENT_DIRECTORY_IS_NOT_DIRECTORY', {path: path, parent: fullPath(parent)});
		}
		Log.verbose('<action>write file</action> <path>$path</path>');
		File.saveContent(path, content);
	}

	public static function deleteDirectory(path:String)
	{
		Assert.argumentNotNull(path, 'path');
		Assert.isTrue(exists(path), '$ERROR_DELETE_DIRECTORY\n$REASON_PATH_NOT_EXIST', {path: path, fullPath: fullPath(path)});
		Assert.isTrue(isDirectory(path), '$ERROR_DELETE_DIRECTORY\n$REASON_PATH_NOT_DIRECTORY', {path: path, fullPath: fullPath(path)});
		Assert.isTrue(isDirectoryEmpty(path), '$ERROR_DELETE_DIRECTORY\n$REASON_DIRECTORY_NOT_EMPTY', {path: path, fullPath: fullPath(path)});
		Log.verbose('<action>delete directory</action> <path>$path</path>');
		if (isLink(path)) deleteFile(path);
		else FileSystem.deleteDirectory(path);
	}

	public static function deleteDirectoryRecursive(path:String)
	{
		Assert.isTrue(exists(path), '$ERROR_DELETE_DIRECTORY_RECURSIVE\n$REASON_PATH_NOT_EXIST', {path: path, fullPath: fullPath(path)});
		Assert.isTrue(isDirectory(path), '$ERROR_DELETE_DIRECTORY_RECURSIVE\n$REASON_PATH_NOT_DIRECTORY', {path: path, fullPath: fullPath(path)});
		if (!isLink(path))
		{
			for (entry in FileSystem.readDirectory(path))
			{
				var path = '$path/$entry';
				if (isDirectory(path) && !isLink(path)) deleteDirectoryRecursive(path);
				else deleteFile(path);
			}
		}
		deleteDirectory(path);
	}

	public static function deleteFile(path:String):Void
	{
		Assert.argumentNotNull(path, 'path');
		Assert.isTrue(exists(path), '$ERROR_DELETE_FILE\n$REASON_PATH_NOT_EXIST', {path:path, fullPath:fullPath(path)});
		Log.verbose('<action>delete file</action> <path>$path</path>');
		FileSystem.deleteFile(path);
	}

	public static function createDirectory(path:String):Void
	{
		Assert.isTrue(!exists(path) || isDirectory(path), '$ERROR_CREATE_DIRECTORY\n$REASON_PATH_EXISTS_AND_NOT_DIRECTORY', {path: path, fullPath: fullPath(path)});
		if (exists(path)) return;
		Log.verbose('<action>create directory</action> <path>$path</path>');
		FileSystem.createDirectory(path);
	}

	public static function readDirectory(path:String):Array<String>
	{
		Assert.argumentNotNull(path, 'path');
		Assert.isTrue(exists(path), '$ERROR_READ_DIRECTORY\n$REASON_PATH_NOT_EXIST', {path: path, fullPath: fullPath(path)});
		Assert.isTrue(isDirectory(path), '$ERROR_READ_DIRECTORY\n$REASON_PATH_NOT_DIRECTORY', {path: path, fullPath: fullPath(path)});
		return FileSystem.readDirectory(path);
	}

	public static function readDirectoryRecursive(path:String, ?files:Array<String>):Array<String>
	{
		Assert.argumentNotNull(path, 'path');
		Assert.isTrue(exists(path), '$ERROR_READ_DIRECTORY\n$REASON_PATH_NOT_EXIST', {path: path, fullPath: fullPath(path)});
		Assert.isTrue(isDirectory(path), '$ERROR_READ_DIRECTORY\n$REASON_PATH_NOT_DIRECTORY', {path: path, fullPath: fullPath(path)});

		path = Path.removeTrailingSlashes(path);
		if (files == null) files = [];
		if (exists(path)) for (file in FileSystem.readDirectory(path))
		{
			var subPath = '$path/$file';
			if (FileSystem.isDirectory(subPath)) readDirectoryRecursive(subPath, files);
			else files.push(subPath);
		}
		return files;
	}

	public static function run(cmd:String, args:Array<String>, onOutput:String -> Void, onError:String -> Void, onExit:Int -> Void):Process
	{
		var process = new Process(cmd, args);
		readSync(process, onOutput, onError, onExit);
		return process;
	}

	public static function cmd(cmd:String, args:Array<String>, ?options:CmdOptions)
	{
		if (options == null) options = {};
		var owd = getCwd();
		if (options.workingDirectory != null)
			setCwd(options.workingDirectory);
		if (options.logCommand) Log.info('<action>$cmd</action> ' + args.join(' '));
		else Log.verbose('<action>$cmd</action> ' + args.join(' '));
		var error = '';
		var output = '';
		run(cmd, args, function (line) {
			output += '$line\n';
			if (options.logOutput) Log.info(line, ['no-style']);
		}, function (line) {
			error += '$line\n';
		}, function (code) {
			setCwd(owd);
			if (code != 0)
				throw new Error('Process <id>$cmd</id> exited with code <const>$code</const>\n$error');
		});
		return StringTools.trim(output);
	}

	public static function getExitCode(cmd:String, args:Array<String>)
	{
		return new Process(cmd, args).exitCode();
	}

	static function readSync(process:Process, onOutput:String -> Void, onError:String -> Void, onExit:Int -> Void):Void
	{
		readInput(process.stdout, onOutput);
		readInput(process.stderr, onError);

		Thread.readMessage(true);
		Thread.readMessage(true);

		onExit(process.exitCode());
	}

	static function readInput(input:haxe.io.Input, output:String ->Void)
	{
		var thread = Thread.create(function(){
			var main = Thread.readMessage(true);
			while (true) try output(input.readLine())
			catch (e:haxe.io.Eof) break;
			main.sendMessage(true);
		});
		thread.sendMessage(Thread.current());
	}

	public static function prompt(message:String, ?secure:Bool):String
	{
		Log.info('<question>$message</question> ', ['no-newline']);
		var text = '';
		while (true)
		{
			var code = Sys.getChar(false);
			var char = String.fromCharCode(code);

			switch (code)
			{
				case 27:
					Sys.print("\n");
					return char;
				case 127:
					if (text.length > 0)
					{
						text = text.substr(0, text.length - 1);
						Sys.stdout().writeByte(0x08);
						Sys.stdout().writeString(' ');
						Sys.stdout().writeByte(0x08);
					}
				case 13:
					break;
				default:
					text += char;
					if (secure) char = '•';
					Sys.print(char);
			}
		}
		Sys.print("\n");
		return text;
	}

	public static function question(message:String):Bool
	{
		return prompt('$message? [y/n]').charAt(0) == 'y';
	}

	public static function splitLines(string:String):Array<String>
	{
		return ~/(\r\n?|\n)/g.split(string);
	}

	public static function cd(path:String, cmd:Void -> Void)
	{
		var owd = Sys.getCwd();
		Log.debug('<action>cd</action> <path>$path</path>');
		Sys.setCwd(path);
		try {
			cmd();
			Sys.setCwd(owd);
		} catch (e:Dynamic) {
			Sys.setCwd(owd);
			#if cpp
			cpp.Lib.rethrow(e);
			#elseif neko
			neko.Lib.rethrow(e);
			#else
			throw e;
			#end
		}
	}

	public static function download(fromHttp:Http, toPath:String):Void
	{
		var fromUrl = fromHttp.url;
		var output = File.write(toPath, true);
		var progress = new ProgressOutput(output, logHttpProgress, logHttpComplete);
		fromHttp.onError = function(e:String) {
			if (e == 'std@host_resolve')
			{
				var host = 'unknown';
				var hostReg = ~/\/\/([^\/]+)/;
				if (hostReg.match(fromUrl))
					host = hostReg.matched(1);
				e = 'Unable to resolve host address <path>$host</path>';
			}
			output.close();
			FileSystem.deleteFile(toPath);
			throw new Error('Could not download file from <path>$fromUrl</path>\n$e');
		};
		Log.info('<action>download</action> <path>$fromUrl</path> to <path>$toPath</path>');
		fromHttp.customRequest(false, progress);
	}

	public static function upload(fromPath:String, toHttp:Http):Void
	{
		var toUrl = toHttp.url;
		var data = sys.io.File.getBytes(fromPath);
		var input = new haxe.io.BytesInput(data);
		var progress = new ProgressInput(input, data.length, logHttpProgress, logHttpComplete);
		toHttp.onError = function (e) {
			throw new Error('could not upload file to <path>$toUrl</path>\nReason: $e');
		}
		toHttp.fileTransfer('file', 'file', progress, data.length, 'multipart/form-data');
		Log.info('<action>upload</action> <path>$fromPath</path> to <path>$toUrl</path>');
		toHttp.request(true);
		progress.close();
	}

	public static function unzip(fromPath:String, toPath:String, ?basePath:String)
	{
		Log.debug('<action>unzip</action> <path>$fromPath</path> to <path>$toPath</path>');

		// read archive
		var input = sys.io.File.read(fromPath, true);
		var zip = haxe.zip.Reader.readZip(input);
		input.close();

		// unzip archive
		for (file in zip)
		{
			var path = file.fileName;

			// skip if directory
			if (file.dataSize == 0) continue;

			// skip if path does not start with basePath
			if (basePath != null && path.indexOf(basePath) == -1) continue;

			// trim basePath
			if (basePath != null) path = path.substr(basePath.length);

			// add to path
			path = '$toPath/$path';

			// create parent directory if needed
			createParentDirectory(path);

			var data = haxe.zip.Reader.unzip(file);
			Log.verbose('<action>write</action> <path>$path</path>');
			sys.io.File.saveBytes(path, data);
		}
	}

	public static function zip(fromPath:String, toPath:String, ?basePath:String)
	{
		Assert.argumentNotNull(fromPath, 'fromPath');
		Assert.argumentNotNull(toPath, 'toPath');
		Assert.isTrue(exists(fromPath), '$ERROR_ZIP\n$REASON_PATH_NOT_EXIST', {fromPath: fromPath, toPath: toPath, fullPath: fullPath(fromPath)});

		Log.debug('<action>zip</action> <path>$fromPath</path> to <path>$toPath</path>');

		var paths = isDirectory(fromPath) ? readDirectoryRecursive(fromPath) : [fromPath];
		var entries = new List<haxe.zip.Entry>();

		for (path in paths)
		{
			// ignore directories
			if (isDirectory(path)) continue;

			// skip if path does not start with basePath
			if (basePath != null && path.indexOf(basePath) == -1) continue;

			// get bytes
			var bytes = File.getBytes(path);

			// trim basePath
			if (basePath != null) path = path.substr(basePath.length);

			// add entry
			var entry = {
				fileName:path,
				fileSize:bytes.length,
				fileTime:Date.now(),
				data:bytes,
				compressed:false,
				dataSize:0,
				crc32:haxe.crypto.Crc32.make(bytes),
				extraFields:new List()
			};
			entries.push(entry);
		}

		// write zip file
		var zip = File.write(toPath, true);
		var writer = new haxe.zip.Writer(zip);
		writer.write(entries);
		zip.close();
	}

	public static function rename(path:String, newPath:String):Void
	{
		Assert.argumentNotNull(path, 'path');
		Assert.argumentNotNull(newPath, 'newPath');
		Assert.isTrue(exists(path), '$ERROR_RENAME\n$REASON_PATH_NOT_EXIST', {path:path, newPath:newPath});
		Assert.isTrue(!exists(newPath) || isFile(newPath), '$ERROR_RENAME\n$REASON_PATH_EXISTS_AND_NOT_FILE', {path:path, newPath:newPath, fullPath:fullPath(newPath)});
		createParentDirectory(newPath);
		Log.verbose('<action>rename</action> <path>$path</path> to <path>$newPath</path>');
		return FileSystem.rename(path, newPath);
	}

	public static function copy(path:String, newPath:String):Void
	{
		if (FileSystem.isDirectory(path)) copyDirectory(path, newPath);
		else copyFile(path, newPath);
	}

	public static function copyFile(path:String, newPath:String):Void
	{
		Assert.argumentNotNull(path, 'path');
		Assert.argumentNotNull(newPath, 'newPath');
		Assert.isTrue(exists(path), '$ERROR_COPY_FILE\n$REASON_PATH_NOT_EXIST', {path:path, newPath:newPath});
		// Assert.isTrue(!FileSystem.isDirectory(path));

		createParentDirectory(newPath);

		Log.verbose('<action>copy file</action> <path>$path</path> to <path>$newPath</path>');
		File.copy(path, newPath);
	}

	public static function copyDirectory(path:String, newPath:String):Void
	{
		// Assert.isTrue(FileSystem.exists(path));
		// Assert.isTrue(FileSystem.isDirectory(path));

		createDirectory(newPath);
		for (file in FileSystem.readDirectory(path))
			copy('$path/$file', '$newPath/$file');
	}

	static function createParentDirectory(path:String)
	{
		var dir = Path.directory(path);
		if (dir != '') createDirectory(dir);
	}

	public static function writeFile(path:String, content:String):Void
	{
		createParentDirectory(path);
		Log.verbose('<action>write</action> <path>$path</path>');
		File.saveContent(path, content);
	}

	static function logHttpProgress(currentBytes:Int, totalBytes:Int)
	{
		var percent = Math.round((currentBytes / totalBytes) * 100) + '%';
		var dots = StringTools.rpad('', '.', Math.round((currentBytes / totalBytes) * 70));
		var spaces = StringTools.rpad('', ' ', 70 - dots.length);
		Log.info('$dots$spaces $percent\r', ['no-newline']);
	}

	static function logHttpComplete(totalBytes:Int, milliseconds:Int):Void
	{
		var kb = Math.round(totalBytes / 1000);
		Log.info('<ok>completed</ok> ${kb}kb in ${milliseconds}ms');
	}
}

class ProgressOutput extends Output
{
	var output:Output;
	var onProgress:Int -> Int -> Void;
	var onComplete:Int -> Int -> Void;

	var startTime:Float;
	var currentBytes:Int;
	var totalBytes:Int;

	public function new(output:Output, onProgress:Int -> Int -> Void, onComplete:Int -> Int -> Void)
	{
		this.output = output;
		this.onProgress = onProgress;
		this.onComplete = onComplete;

		startTime = Timer.stamp();
		currentBytes = 0;
		totalBytes = 1;
	}

	function bytes(n)
	{
		currentBytes += n;
		if (totalBytes == 1) onProgress(0, 1);
		else onProgress(currentBytes, totalBytes);
	}

	public override function writeByte(c)
	{
		output.writeByte(c);
		bytes(1);
	}

	public override function writeBytes(s,p,l)
	{
		var r = output.writeBytes(s,p,l);
		bytes(r);
		return r;
	}

	public override function close()
	{
		super.close();
		output.close();
		onComplete(totalBytes, Std.int((Timer.stamp() - startTime) * 1000));
	}

	public override function prepare(m:Int)
	{
		totalBytes = m;
	}
}

class ProgressInput extends Input
{
	var input:Input;
	var totalBytes:Int;
	var onProgress:Int -> Int -> Void;
	var onComplete:Int -> Int -> Void;

	var startTime:Float;
	var currentBytes:Int;

	public function new(input:Input, totalBytes:Int, onProgress:Int -> Int -> Void, onComplete:Int -> Int -> Void)
	{
		this.input = input;
		this.totalBytes = totalBytes;
		this.onProgress = onProgress;
		this.onComplete = onComplete;

		startTime = Timer.stamp();
		currentBytes = 0;
	}

	public override function readByte()
	{
		var c = input.readByte();
		doRead(1);
		return c;
	}

	public override function readBytes(buf, pos, len)
	{
		var k = input.readBytes(buf,pos,len);
		doRead(k);
		return k;
	}

	function doRead(nbytes:Int)
	{
		currentBytes += nbytes;
		onProgress(currentBytes, totalBytes);
	}

	public override function close()
	{
		super.close();
		input.close();
		onComplete(totalBytes, Std.int((Timer.stamp() - startTime) * 1000));
	}
}

typedef CmdOptions = {
	@:optional var logOutput:Bool;
	@:optional var logCommand:Bool;
	@:optional var workingDirectory:String;
}
