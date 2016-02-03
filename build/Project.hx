package build;

class Project
{
	static var validated = false;

	public static function validate(config:Config)
	{
		if (config.getValue('define.noValidate', false)) return;

		if (validated) return;
		validated = true;

		Log.info('<info>validate</info>');
		var dependencies = config.getValue('dependencies', new Array<Dependency>());
		for (dependency in dependencies)
		{
			var name = dependency.name;
			var path = 'lib/$name';

			if (!Cli.exists(path))
			{
				var process = new sys.io.Process('git', ['clone', dependency.url, path, '--progress']);
				var line = '';
				while (true)
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
			}

			var sub = new Repository(path);
			sub.checkout(dependency.ref);

			var infos = ['$path/haxelib.json', '$path/src/haxelib.json'].filter(Cli.exists).map(Cli.fullPath);
			if (infos.length > 0)
			{
				var info = Cli.getJson(infos[0]);
				var name = info.name;
				Cli.createDirectory('.haxelib/$name');
				Cli.saveContent('.haxelib/$name/.dev', haxe.io.Path.directory(infos[0]));
			}
		}
	}

	public static function status(config:Config, args:Array<String>)
	{
		Log.info('<info>status</info>');
		var dependencies = config.getValue('dependencies', new Array<Dependency>());
		for (dependency in dependencies)
		{
			var name = dependency.name;
			var path = 'lib/$name';
			var sub = new Repository(path);
			var version = sub.hash;

			var isValid = sub.isValid(dependency.ref);
			var state = 'green';

			if (!isValid || !sub.isClean) state = 'red';
			else if (!sub.isStable) state = 'yellow';

			if (sub.isTagged)
			{
				version = sub.tag;
				if (!sub.isStable)
					version += '+' + sub.commitsAheadOfTag;
			}

			Log.info('<path>$path</path> <$state>$version</$state>');

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
		if (Cli.exists('bin'))
			Cli.deleteDirectoryRecursive('bin');
	}
}
