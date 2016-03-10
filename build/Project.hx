package build;

class Project
{
	static var validated = false;

	public static function validate(config:Config)
	{
		var dependencies = config.getValue('dependencies', new Array<OrderedMap>());
		var dependencyPath = config.getValue('app.dependencyPath', 'lib');

		for (dependency in dependencies)
		{
			var name = dependency.get('name');
			config.setValue('lib.$name.path', '$dependencyPath/$name');
		}

		if (config.getValue('define.noValidate', false)) return;
		var isCI = config.getValue('define.ci', false);
		Cli.createDirectory(dependencyPath);

		if (validated) return;
		validated = true;

		Log.info('<info>validate</info>');
		for (dependency in dependencies)
		{
			var name = dependency.get('name');
			var url = dependency.get('url');
			var ref = dependency.get('ref');

			var path = '$dependencyPath/$name';
			var fresh = false;

			if (!Cli.exists(path))
			{
				fresh = true;
				Log.info('<action>git</action> clone <path>$url</path> into <path>$path</path>');
				var process = new sys.io.Process('git', ['clone', url, path, '--progress']);
				var line = '';
				while (!isCI && true)
				{
					var byte = 0;
					try byte = process.stderr.readByte() catch (e:Dynamic) break;
					line = line + String.fromCharCode(byte);
					if (byte == 0x0D || byte == 0x0A)
					{
						Sys.print(line);
						line = '';
					}
				}
				if (process.exitCode() != 0)
					throw new Error('Could not clone dependency <id>$name</id> from <path>$url</path>');
			}

			var sub = new Repository(path);
			if (sub.isValid(ref))
			{
				Log.info('$name <green>$ref</green>');
			}
			else
			{
				if (!fresh)
				{
					var currentRef = sub.isStable ? sub.tag : sub.hash;
					Log.info('$name <warn>$currentRef => $ref</warn>');
				}
				sub.checkout(ref);
			}
			addHaxelib(path);
		}
		addHaxelib('.');
	}

	static function addHaxelib(path:String)
	{
		var infos = ['$path/haxelib.json', '$path/src/haxelib.json'].filter(Cli.exists);
		if (infos.length > 0)
		{
			var info = Cli.getJson(infos[0]);
			var name = info.get('name');
			Cli.createDirectory('.haxelib/$name');
			Cli.saveContent('.haxelib/$name/.dev', haxe.io.Path.directory(infos[0]));
		}
	}

	public static function status(config:Config, args:Array<String>)
	{
		var dependencyPath = config.getValue('app.dependencyPath', 'lib');

		Log.info('<info>status</info>');
		var dependencies = config.getValue('dependencies', new Array<OrderedMap>());
		for (dependency in dependencies)
		{
			var name = dependency.get('name');
			var ref = dependency.get('ref');
			var path = '$dependencyPath/$name';
			var sub = new Repository(path);
			var version = sub.hash;

			var isValid = sub.isValid(ref);
			var state = 'green';

			if (!isValid || !sub.isClean) state = 'red';
			else if (!sub.isStable) state = 'yellow';

			if (sub.isTagged)
			{
				version = sub.tag;
				if (!sub.isStable)
					version += '+' + sub.commitsAheadOfTag;
			}

			Log.info('$name <$state>$version</$state>');

			if (!sub.isClean)
			{
				Log.startGroup();
				Log.info(sub.getChanges());
				Log.endGroup();
			}
		}
	}

	public static function clean(config:Config, args:Array<String>)
	{
		Log.info('<info>clean</info>');
		Cli.cmd('rm', ['-rf', 'bin']);
	}
}
