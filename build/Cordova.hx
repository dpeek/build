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
		cordova(path, ['build', platform, '-device']);
	}

	static function prepare(config:Config)
	{
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
			if (Cli.exists('$path/plugins/${plugin.id}')) continue;
			var pluginPath = plugin.path == null ? plugin.id : plugin.path;
			var args = ['plugin', 'add', pluginPath];
			if (plugin.args != null)
				args = args.concat(plugin.args);
			cordova(path, args);
		}
	}
}
