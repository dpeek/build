package build;

class Repository
{
	// the current commit hash
	public var hash(default, null):String;

	// the closest tag
	public var tag(default, null):String;

	// the number of commits ahead of tag
	public var commitsAheadOfTag(default, null):Int;

	// are we on a tagged release
	public var isStable(default, null):Bool;

	// is the working tree dirty
	public var isClean(default, null):Bool;

	public var isTagged(default, null):Bool;
	public var path(default, null):String;
	public var description(default, null):String;

	var branches:Array<Branch>;

	public function new(path:String)
	{
		this.path = path;
		if (!Cli.exists('$path/.git')) return;

		updateState();
	}

	function updateState()
	{
		// get description in form: {tag}-{commits ahead}-g{commit hash}-dirty
		description = git(['describe', '--tags', '--dirty', '--long', '--always']);
		var parts = description.split('-');

		var branch = getCurrentBranch();
		var branchName = branch == null ? 'no-branch' : branch.localName;

		isTagged = parts.length > 2;
		if (isTagged)
		{
			// get the closest tag
			tag = parts.shift();

			// get number of commits ahead of tag
			commitsAheadOfTag = Std.parseInt(parts.shift());

			// get the number of commits ahead
			isStable = commitsAheadOfTag == 0;
		}
		else
		{
			isStable = false;
			commitsAheadOfTag = 0;
			tag = null;
		}

		// get the short commit hash
		hash = parts.shift();
		if (isTagged) hash = hash.substr(1);

		// get the dirty state
		isClean = parts.shift() != 'dirty';
	}

	public function getVersions():Array<Version>
	{
		return getTags().filter(Version.isValid).map(Version.parse);
	}

	public function tryGetCommit(ref:String):String
	{
		try
		{
			return getCommit(ref);
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	public function getCommit(ref:String):String
	{
		try
		{
			return git(['rev-list', '--abbrev-commit', '-n', '1', ref]);
		}
		catch (e:Dynamic)
		{
			throw new Error('Commit <id>$ref</id> not found in <path>$path</path>');
		}
	}

	public function archive(path:String):Void
	{
		// create git archive
		git(['archive', '-o', path, '-9', 'HEAD']);
	}

	public function isValid(ref:String)
	{
		return hash == tryGetCommit(ref);
	}

	public function checkout(ref:String, ?shouldFetch:Bool=true):Void
	{
		// bail out if there are changes
		if (!isClean)
		{
			Log.warn('<error>skip</error> <path>$path</path> has local changes');
			return;
		}

		// ref can be one of:
		// - branch: feature/something
		// - tag: 1.2.3
		// - hash: 9c9afcd

		var branch = getBranch(ref, true);

		if (branch != null)
		{
			// we either have local or remote branch ref, fetch any changes
			if (shouldFetch) fetch();

			// get the potentially updated hash
			branch = getBranch(ref, true);

			// if we already have the branch checked out at hash bail out
			var current = getCurrentBranch();
			if (current != null && current.localName == branch.localName && branch.hash == current.hash) return;

			// checkout the branch, no-op if already on branch, checkout existing local if there is
			// one of create new local from remote
			git(['checkout', branch.localName]);

			// reset to remote
			git(['reset', '--hard', branch.remoteName]);
			updateState();
			return;
		}

		// either we have a tag/hash or a remote branch that hasn't been fetched yet
		// var hasRef = false;
		var hash:String = null;

		try
		{
			// turn tag into hash if we already have the tag locally
			// if we don't have tag or hash we catch the error and fetch
			hash = getCommit(ref);
		}
		catch (e:Dynamic)
		{
			// if we don't have tag or hash we catch the error and fetch and try again
			fetch();
			hash = getCommit(ref);
		}

		if (hash == this.hash) return;

		// get current branch
		var branch = getCurrentBranch();

		// get branches that contain this commit
		var branches = gitLines(['branch', '--contains', ref, '-r']).map(StringTools.trim);
		if (branch != null && branches.indexOf(branch.remoteName) == -1)
		{
			var remote = null;
			for (branch in branches)
			{
				remote = getRemoteBranch(branch);
				if (remote != null) break;
			}
			if (remote == null) throw new Error('The commit $ref does not exist in any local or remote branches!');
			git(['checkout', remote.localName]);
		}

		git(['reset', '--hard', ref]);
		updateState();
	}

	public function getChanges()
	{
		var color = Sys.getEnv('CLICOLOR') == '1' ? 'always' : 'false';
		var status = git(['-c', 'color.status=$color', 'status', '--branch', '-s']);
		return status == '' ? 'no changes' : status;
	}

	public function getBranches():Array<Branch>
	{
		if (branches != null) return branches;
		return branches = gitLines(['branch', '-avv'])
			.filter(function (line) {
				return line.indexOf('HEAD') == -1;
			}).map(function (line) {
				var parts = ~/ +/g.split(line);
				var name = parts[1];
				var remoteName = name;
				var localName = name;
				var path = name.split('/');
				var remote = null;
				var hash = parts[2];
				var isRemote = path[0] == 'remotes';
				if (isRemote)
				{
					remote = path[1];
					remoteName = path.slice(1).join('/');
					localName = path.slice(2).join('/');
					name = remoteName;
				}
				else
				{
					remoteName = parts[3];
					remoteName = remoteName.substr(1, remoteName.length - 2);
					remote = remoteName.split('/')[0];
				}
				return {
					isCurrent: parts[0] == '*',
					isRemote: isRemote,
					remote: remote,
					remoteName: remoteName,
					localName: localName,
					name: name,
					hash: hash
				}
			});
	}

	public function getBranch(localName:String, ?remote:Bool=false)
	{
		for (branch in getBranches())
			if (branch.isRemote == remote && branch.localName == localName)
				return branch;
		return null;
	}

	public function getRemoteBranch(remoteName:String)
	{
		for (branch in getBranches())
			if (branch.remoteName == remoteName)
				return branch;
		return null;
	}

	public function getCurrentBranch():Branch
	{
		for (branch in getBranches())
			if (branch.isCurrent)
				return branch;
		return null;
	}

	public function isBranch(ref:String):Bool
	{
		for (branch in getBranches())
			if (branch.name == ref) return true;
		return false;
	}

	public function getTags():Array<String>
	{
		return gitLines(['tag']);
	}

	public function fetch()
	{
		git(['fetch']);
	}

	function git(args:Array<String>)
	{
		return Cli.cmd('git', args, {workingDirectory:path});
	}

	function gitLines(args:Array<String>)
	{
		return Cli.splitLines(git(args));
	}
}

typedef Branch = {
	var isCurrent:Bool;
	var isRemote:Bool;
	var remote:String;
	var remoteName:String;
	var localName:String;
	var name:String;
	var hash:String;
}
