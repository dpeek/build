package build;

import haxe.Json;
import haxe.io.Path;

import sys.FileSystem;
import sys.io.File;

class Target
{
	public static function run(config:Config, args:Array<String>)
	{
		var name = args[0];

		Log.info('<info>target</info> $name');
		var debug = config.getValue('define.debug', false);

		var targets = config.getValue('targets', new Array<Dynamic>());
		var targetsByName = new Map();
		for (target in targets)
			targetsByName.set(target.name, target);

		if (!targetsByName.exists(name))
			throw new Error('There is no target named "$name"');

		var targetConfig = targetsByName.get(name);
		var targetConfigs = [targetConfig];
		while (targetConfig.parent != null)
		{
			targetConfig = targetsByName.get(targetConfig.parent);
			targetConfigs.unshift(targetConfig);
		}

		var target = new Config();
		for (targetConfig in targetConfigs)
			target.setValues(targetConfig);

		var outputPath = target.getValue('path');
		FileSystem.createDirectory(outputPath);
		if (!config.getValue('define.noHaxe', false))
		{
			var haxeTargets = target.getValue('haxeTargets');
			for (name in Reflect.fields(haxeTargets))
			{
				var targetPath = null;
				var rawArgs = target.getValue('haxeTargets.$name').split(' ');
				var args = [];
				while (rawArgs.length > 0)
				{
					switch (rawArgs.shift())
					{
						case '-js', '-swf', '-php', '-neko', '-cpp', '-python', '-cs', '-java':
							targetPath = '$outputPath/' + rawArgs.shift();
							Cli.createDirectory(haxe.io.Path.directory(targetPath));
							args.push('-js');
							args.push(targetPath);
						case arg:
							args.push(arg);
					}
				}

				if (debug) args.push('-debug');
				else args.push('--no-traces');

				Cli.cmd('haxe', args, {logCommand:true, logOutput:true});
				if (!debug) minify(targetPath);
			}
		}

		var sources = target.getValue('sources', new Array<String>());
		var files = getFiles(sources);


		files = processFiles(files, ~/^asset/, function (files) {
			if (files.length == 0) return;
			Log.info('<action>process</action> assets');
			buildLibrary(outputPath, files);
		});

		if (files.length > 0)
		{
			Log.info('<action>process</action> resources');
			for (file in files)
				Cli.copyFile(file.sourcePath, '$outputPath/${file.localPath}');
		}

		var templates = target.getValue('templates', new Array<String>());
		if (templates.length > 0)
		{
			Log.info('<action>process</action> templates');
			for (template in templates)
				replaceTokens('$outputPath/$template', config);
		}

		var variants = target.getValue('variants', new Array<{input:String, output:String, schemes:Array<String>}>());
		if (variants.length > 0)
		{
			Log.info('<action>process</action> variants');
			for (variant in variants)
			{
				var variantConfig = config.clone();
				for (scheme in variant.schemes) variantConfig.setScheme(scheme);
				var output = '$outputPath/${variant.output}';
				Cli.copyFile(variant.input, output);
				replaceTokens(output, variantConfig);
			}
		}

		var after = target.getValue('after', new Array<Array<String>>());
		for (args in after) Run.execute(config, args);
	}

	public static function replaceTokens(path:String, config:Config)
	{
		var content = Cli.getContent(path);
		try
		{
			content = config.resolveString(content);
		}
		catch (e:Dynamic)
		{
			throw new Error('Unable to replace token in <path>$path</path>');
		}
		Cli.saveContent(path, content);
	}

	static function getFiles(sources:Array<String>)
	{
		var files = [];
		for (source in sources)
		{
			for (sourcePath in Cli.readDirectoryRecursive(source))
			{
				if (sourcePath.indexOf('.DS_Store') > -1) continue;
				var localPath = sourcePath.substr(source.length + 1);
				files.push({
					sourcePath: sourcePath,
					localPath: localPath
				});
			}
		}
		return files;
	}

	static function processFiles(files:Array<BuildFile>, pattern:EReg, process:Array<BuildFile> -> Void):Array<BuildFile>
	{
		var matched = [];
		var unmatched = [];
		for (file in files)
			if (pattern.match(file.localPath)) matched.push(file);
			else unmatched.push(file);
		process(matched);
		return unmatched;
	}

	static function minify(path:String)
	{
		var bin = 'bin/vendor/closure/compiler.jar';
		if (!FileSystem.exists(bin))
		{
			var http = new haxe.Http('http://dl.google.com/closure-compiler/compiler-latest.zip');
			Cli.download(http, 'closure.zip');
			Cli.unzip('closure.zip', 'bin/vendor/closure');
			Cli.deleteFile('closure.zip');
		}

		var outputPath = Path.withExtension(path, 'min.js');
		var args = ['-jar', bin, '--js', path, '--js_output_file', outputPath, '--warning_level', 'QUIET'];
		Cli.cmd('java', args, {logCommand:true});
		Cli.rename(outputPath, path);
	}

	static function buildLibrary(path:String, files:Array<BuildFile>)
	{
		var manifest = [];
		for (file in files)
		{
			var localPath = file.localPath.substr('asset/'.length);
			if (Path.extension(localPath) == 'json') continue;

			var parts = [];
			var partsPath = Path.withExtension(file.sourcePath, 'json');
			if (Cli.isFile(partsPath)) parts = Cli.getJson(partsPath);

			var size = Image.getSize(file.sourcePath);
			var info = {
				id:localPath,
				width:size.width,
				height:size.height,
				parts:parts
			};
			manifest.push(info);

			Cli.copy(file.sourcePath, '$path/asset/$localPath');
		}
		Cli.saveContent('$path/asset/manifest.json', haxe.Json.stringify(manifest));
	}
}

typedef BuildFile =
{
	var sourcePath:String;
	var localPath:String;
}
