package build;

class Project
{
	static var validated = false;

	public static function validate(config:Config)
	{
		if (config.getValue('define.noValidate', false)) return;
		var isCI = config.getValue('define.ci', false);

		var localDependencyPath = 'lib';
		Cli.createDirectory(localDependencyPath);

		var home = Cli.userDirectory;
		var globalDependencyPath = '$home/.hxbuild/lib';
		if (isCI) Cli.createDirectory(globalDependencyPath);

		if (validated) return;
		validated = true;

		Log.info('<info>validate</info>');
		var dependencies = config.getValue('dependencies', new Array<OrderedMap>());
		for (dependency in dependencies)
		{
			var name = dependency.get('name');
			var url = dependency.get('url');
			var ref = dependency.get('ref');

			var path = '$localDependencyPath/$name';
			var checkoutPath = isCI ? '$globalDependencyPath/$name' : path;
			var fresh = false;

			if (!Cli.exists(checkoutPath))
			{
				fresh = true;
				Log.info('<action>git</action> clone <path>$url</path> into <path>$checkoutPath</path>');
				var process = new sys.io.Process('git', ['clone', url, checkoutPath, '--progress']);
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
			if (isCI && !Cli.exists(path))
				Cli.cmd('ln', ['-sfF', checkoutPath, Cli.fullPath(path)]);

			var sub = new Repository(path);
			if (sub.isValid(ref))
			{
				Log.info('<path>$path</path> <green>$ref</green>');
			}
			else
			{
				if (!fresh)
				{
					var currentRef = sub.isStable ? sub.tag : sub.hash;
					Log.info('<path>$path</path> <warn>$currentRef => $ref</warn>');
				}
				sub.checkout(ref);
			}

			var infos = ['$path/haxelib.json', '$path/src/haxelib.json'].filter(Cli.exists).map(Cli.fullPath);
			if (infos.length > 0)
			{
				var info = Cli.getJson(infos[0]);
				var name = info.get('name');
				Cli.createDirectory('.haxelib/$name');
				Cli.saveContent('.haxelib/$name/.dev', haxe.io.Path.directory(infos[0]));
			}
		}
	}

	public static function status(config:Config, args:Array<String>)
	{
		Log.info('<info>status</info>');
		var dependencies = config.getValue('dependencies', new Array<OrderedMap>());
		for (dependency in dependencies)
		{
			var name = dependency.get('name');
			var ref = dependency.get('ref');
			var path = 'lib/$name';
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
