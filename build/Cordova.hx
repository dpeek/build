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

		var plugins = config.getValue('cordova.plugins', new Array<{id:String, ?path:String, ?args:Array<String>}>());
		for (plugin in plugins)
			if (plugin.path != null && Cli.exists(plugin.path))
				plugin.path = Cli.fullPath(plugin.path);

		var platformPath = '$path/platforms/$platform';

		if (!Cli.exists(platformPath))
			cordova(path, ['platform', 'add', platform]);

		for (plugin in plugins)
		{
			if (Cli.exists('$path/plugins/${plugin.id}')) continue;
			var path = plugin.path == null ? plugin.id : plugin.path;
			var args = ['plugin', 'add', path];
			if (plugin.args != null)
				args = args.concat(plugin.args);
			cordova(path, args);
		}
	}
}
