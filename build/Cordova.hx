package build;

import haxe.xml.Fast;

using Lambda;

class Cordova
{
	static function cordova(path:String, args:Array<String>)
	{
		Cli.cmd('cordova', args, {logCommand:true, logOutput:true, workingDirectory:path});
	}

	public static function run(config:Config, args:Array<String>)
	{
		switch (args[0])
		{
			case 'prepare': prepare(config);
			case 'build': build(config);
		}
	}

	static function build(config:Config)
	{
		var platform = config.getValue('cordova.platform');
		var path = config.getValue('cordova.path');
		var debug = config.getValue('define.debug', false) ? 'debug' : 'release';
		var emulator = config.getValue('define.emulator', false) ? 'emulator' : 'device';
		var prepare = config.getValue('define.prepare', false);
		var action = config.getValue('define.run', false) ? 'run' : 'build';
		if (prepare) cordova(path, ['prepare', platform]);
		else cordova(path, [action, platform, '--$debug', '--$emulator']);
	}

	static function prepare(config:Config)
	{
		var refresh = config.getValue('define.refreshPlugin', 'none');
		var platform = config.getValue('cordova.platform');
		var path = config.getValue('cordova.path');
		var pluginConfigs = config.getValue('cordova.plugins', new Array<OrderedMap>());
		var plugins = pluginConfigs.map(function(plugin){
			var id = plugin.get('id');
			var args = plugin.get('args');
			var path = plugin.get('path');
			if (path != null && Cli.exists(path))
				path = Cli.fullPath(path);
			return {id:id, path:path, args:args};
		});

		var platformPath = '$path/platforms/$platform';

		if (!Cli.exists(platformPath))
			cordova(path, ['platform', 'add', platform]);

		for (plugin in plugins)
		{
			var exists = Cli.exists('$path/plugins/${plugin.id}');
			var shouldRefresh = refresh == 'all' || refresh == plugin.id;
			if (exists && !shouldRefresh) continue;
			var pluginPath = plugin.path == null ? plugin.id : plugin.path;
			if (exists) cordova(path, ['plugin', 'remove', plugin.id]);
			var args = ['plugin', 'add', pluginPath];
			if (plugin.args != null)
				args = args.concat(plugin.args);
			cordova(path, args);
		}
	}
}
