package build;

class Version
{
	public static var MAX = 9999;

	public static function isValid(version:String):Bool
	{
		var pattern = ~/^(\d+)\.(\d+)\.(\d+)(-.+)?$/;
		return pattern.match(version);
	}

	public static function parse(version:String):Version
	{
		var pattern = ~/^(\d+)\.(\d+)\.(\d+)(-.+)?$/;
		if (!pattern.match(version))
			throw new Error('"$version" is not a valid version');

		return new Version(
			Std.parseInt(pattern.matched(1)),
			Std.parseInt(pattern.matched(2)),
			Std.parseInt(pattern.matched(3)),
			pattern.matched(4)
		);
	}

	public static function compare(a:Version, b:Version):Int
	{
		if (a.major == b.major)
		{
			if (a.minor == b.minor)
			{
				if (a.patch == b.patch)
				{
					var a = a.build == '' ? 'z' : a.build;
					var b = b.build == '' ? 'z' : b.build;
					return Reflect.compare(a, b);
				}

				return a.patch < b.patch ? -1 : 1;
			}

			return a.minor < b.minor ? -1 : 1;
		}

		return a.major < b.major ? -1 : 1;
	}

	public var major(default, null):Int;
	public var minor(default, null):Int;
	public var patch(default, null):Int;
	public var build(default, null):String;

	public function new(major:Int, minor:Int, patch:Int, ?build:String)
	{
		this.major = major;
		this.minor = minor;
		this.patch = patch;
		this.build = build == null ? '' : build;
	}

	public function getNext(part:Release):Version
	{
		return switch (part)
		{
			case Major: new Version(major + 1, 0, 0);
			case Minor: new Version(major, minor + 1, 0);
			case Patch: new Version(major, minor, patch + 1);
		}
	}

	public function getPrevious():Version
	{
		if (patch > 0) return new Version(major, minor, patch - 1);
		if (minor > 0) return new Version(major, minor - 1, MAX);
		if (major > 0) return new Version(major - 1, MAX, MAX);
		return new Version(0, 0, 0);
	}

	public function toString():String
	{
		return '$major.$minor.$patch$build';
	}
}

enum Release
{
	Major;
	Minor;
	Patch;
}
