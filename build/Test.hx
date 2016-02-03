package build;

class Test
{
	static macro function throws(expr:haxe.macro.Expr)
	{
		return macro try $expr catch (error:Error) Log.info(error);
	}

	inline static function passes(output:String)
	{
		Sys.println(output);
	}

	public static function main()
	{
		Log.level = Verbose;

		var base = 'test';
		Sys.command('rm', ['-rf', base]);
		Cli.createDirectory(base);
		var owd = Cli.getCwd();
		Cli.setCwd(base);
		var cwd = Cli.getCwd();

		// setup

		Cli.saveContent('file', 'file');
		Cli.createDirectory('empty-directory');
		Cli.createDirectory('directory-with-file');
		Cli.createDirectory('directory-with-linked-directory');
		Cli.saveContent('directory-with-file/file', 'file');

		Sys.command('ln', ['-s', '$cwd/file', 'linked-file']);
		Sys.command('ln', ['-s', '$cwd/directory-with-file', 'linked-directory']);
		Sys.command('ln', ['-s', '$cwd/empty-directory', 'directory-with-linked-directory/linked-directory']);

		// failing tests
		passes(Cli.getCwd());

		throws(Cli.setCwd(null));
		throws(Cli.setCwd('non-existing'));
		throws(Cli.setCwd('file'));

		throws(Cli.fullPath(null));
		passes(Cli.fullPath('fullPath'));
		passes(Cli.fullPath('../fullPath'));

		throws(Cli.saveContent(null, 'file'));
		throws(Cli.saveContent('directory-with-file/file', null));
		throws(Cli.saveContent('non-existing/file', 'file'));
		throws(Cli.saveContent('file/file', 'file'));
		throws(Cli.saveContent('directory-with-file', ''));

		throws(Cli.deleteDirectory(null));
		throws(Cli.deleteDirectory('non-existing'));
		throws(Cli.deleteDirectory('file'));
		throws(Cli.deleteDirectory('directory-with-file'));
		throws(Cli.deleteDirectory('linked-directory'));

		throws(Cli.deleteFile(null));
		throws(Cli.deleteFile('non-existing'));

		// passing tests
		Cli.deleteDirectoryRecursive('directory-with-linked-directory');
		Cli.deleteDirectoryRecursive('directory-with-file');
		Cli.deleteDirectoryRecursive('empty-directory');
		Cli.deleteFile('file');
		Cli.deleteFile('linked-directory');
		Cli.deleteFile('linked-file');
		Cli.setCwd(owd);
		Cli.deleteDirectory(base);
	}
}
