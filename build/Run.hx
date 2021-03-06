package build;

typedef ActionHandler = Config -> Array<String> -> Void;

class Run
{
	static var actions = new Map<String, ActionHandler>();

	public static function register(action:String, handler:ActionHandler)
	{
		actions.set(action, handler);
	}

	public static function main(onConfigure:Config -> Void)
	{
		try run(Sys.args(), onConfigure) catch (e:Error)
		{
			Log.error(e);
			Sys.exit(1);
		}
	}

	static function run(args:Array<String>, onConfigure:Config -> Void)
	{
		var config = new Config();

		var home = Cli.userDirectory;
		if (Cli.exists('$home/.hxbuild/build.json'))
			config.setValues(Cli.getJson('$home/.hxbuild/build.json'));

		if (Cli.exists('build.json'))
			config.setValues(Cli.getJson('build.json'));

		if (Cli.exists('user.json'))
			config.setValues(Cli.getJson('user.json'));

		var project = new Repository('.');
		if (Cli.exists('.git'))
		{
			config.setValue('git.revision', project.hash);
			config.setValue('git.version', project.tag);
		}

		args = args.filter(function (arg) {
			if (arg.charAt(0) != '-') return true;
			var name = arg.substr(1);
			if (name.indexOf('=') == -1)
			{
				config.setValue('define.$name', true);
			}
			else
			{
				var pair = name.split('=');
				name = pair[0];
				config.setValue('define.$name', Util.getStringValue(pair[1]));
			}
			config.setScheme(name);
			return false;
		});

		Log.level = switch (config.getValue('define.log', 'info'))
		{
			case 'none': None;
			case 'error': Error;
			case 'warn': Warn;
			case 'debug': Debug;
			case 'verbose': Verbose;
			default: Info;
		}

		if (onConfigure != null)
			onConfigure(config);

		if (config.getValue('define.clean', false))
			execute(config, ['clean']);

		execute(config, args);
	}

	public static function execute(config:Config, args:Array<String>)
	{
		args = args.copy();
		switch (args.shift())
		{
			case 'test':
				Test.main();
			case 'clean':
				Project.clean(config, args);
			case 'cordova':
				Cordova.run(config, args);
			case 'validate':
				Project.validate(config);
			case 'target':
				Project.validate(config);
				Target.run(config, args);
			case 'status':
				Project.status(config, args);
			case 'print':
				Sys.println(Json.stringify(config.getValue(args.shift()), null, '  '));
			case 'format':
				var formatted = Json.stringify(untyped config.config, null, '  ');
				Sys.println(formatted);
			case action:
				if (actions.exists(action)) actions.get(action)(config, args);
				else throw new Error('Unknown action $action');
		}
	}
}
