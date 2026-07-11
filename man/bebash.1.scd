BEBASH(1)

# NAME

bebash - manage the bebash Bash framework and user overlay

# SYNOPSIS

*bebash* [global flags] <command> [args]

# DESCRIPTION

*bebash* is the management CLI for the bebash Bash framework. It inspects the
installed payload, initializes the user overlay, lists available functions, and
prints machine-readable data for scripts and agents when *--json* is used.

# COMMANDS

*doctor* [*--json*] [*--logs*[=N]] [*--no-tools*] [*--scope* all|payload|user]
	Run environment and artifact verification checks. The verifier checks the
	payload and/or user overlay for bebash conventions, runs *bash -n* over both
	scopes, and presence-gates *shellcheck* and *shfmt* over user artifacts. With
	*--json*, emit an object containing *ok*, *paths*, *summary*, *checks*, and
	*logs*. Warnings do not change the exit status; failures exit 1.

*list*
	List available functions as *name  description  origin*. With *--json*,
	emit an array of objects with *name*, *desc*, and *origin*.

*path*
	Print resolved paths in order: *payload*, *config*, *data*, *log*,
	*manifest*, *completion*, and *man*. With *--json*, emit one object with
	those keys.

*edit* [*--new*] <function>
	Open a function in *$EDITOR*. With *--new*, scaffold a user function under
	*$BEBASH_DATA_DIR/functions* before opening it.

*init* [*--location* xdg|dotfiles|custom] [*--path* DIR] [*--refresh-docs*] [*--no-doctor*]
	Create the user overlay skeleton. XDG mode writes the normal config and data
	roots. Dotfiles and custom modes create a tree under DIR and symlink the XDG
	roots to it. Existing non-symlink roots are not replaced. The command deploys
	*config.bash*, *README.md*, and *AGENTS.md*, then runs *doctor --scope user*
	unless *--no-doctor* is set.

*man* [*--source*]
	Print this reference manual as deterministic plain text. With *--source*,
	print the selected scdoc source unchanged.

*version*
	Print the installed version string from *VERSION*.

*help* [command]
	Show general usage or command-specific usage.

# CONVENTIONS

The verifier emits stable codes with severity *ok*, *warn*, or *fail*.

*ENV001* fail
	Bash must be at least 4.4.
*ENV002* fail
	Payload root must contain the installed bebash payload.
*ENV003* fail
	Config root must exist.
*ENV004* fail
	Data root must exist.
*ENV005* fail
	*bebash* should be available on PATH or from its resolved bin dir.
*ENV006* fail
	Log path must be writable.
*ENV007* warn
	Optional tools *fzf*, *scdoc*, and *git-cliff* are reported when missing.
*ENV008* warn
	Old config-root code directories are stale.
*SRC001* fail
	Sourced files start with *# shellcheck shell=bash*.
*SRC002* fail
	Line 2 is a non-empty *desc:* marker.
*SRC003* fail
	Sourced files end in *.bash*.
*SRC004* fail
	*bash -n* succeeds.
*FUNC001* fail
	Function filenames are valid public names.
*FUNC002* fail
	Function files define the matching public function.
*FUNC003* fail
	Function files define exactly one public function.
*LIB001* fail
	Lib filenames are valid internal names.
*LIB002* fail
	Lib files use the required bebash lib load guard.
*LIB003* fail
	Lib files define no unprefixed public functions.
*CMD001* fail
	Command files are named cmd_<sub>.bash.
*CMD002* fail
	Command files define bebash::cmd::<sub>.
*CMD003* fail
	Command files define a usage function.
*CMD004* fail
	Command registry and command files match.
*RC001* warn
	rc.d files are named NN-<topic>.bash.
*RC002* fail
	*rc.d* files define no unprefixed public functions.
*CONFIG001* fail
	config.bash follows sourced-file headers.
*DISABLED001* warn
	disabled.d basenames are valid public names.
*DISABLED002* warn
	disabled.d entries are files or symlinks.
*STANDALONE001* fail
	Standalone commands are executable.
*STANDALONE002* fail
	Standalone commands have a shebang.
*STANDALONE003* warn
	Standalone command basenames do not end in .bash.
*AGENTDOC001* warn
	AGENTS.md exists in the config root.
*AGENTDOC002* warn
	AGENTS.md carries marker bebash-agent-doc-version: 1.
*TOOL001* warn
	*shellcheck* is missing; user shellcheck is skipped.
*TOOL002* fail
	*shellcheck -x --rcfile "$BEBASH_LIB/.shellcheckrc"* reports user issues.
*TOOL003* warn
	*shfmt* is missing; user format check is skipped.
*TOOL004* fail
	*shfmt -i 2 -ci -bn -s -d* reports user formatting differences.

# GLOBAL FLAGS

*-h*, *--help*
	Show usage and exit 0.

*--version*
	Print the version and exit 0.

*-y*, *--yes*
	Auto-confirm prompts.

*--non-interactive*
	Never prompt.

*--json*
	Emit structured stdout where supported.

*-v*, *-vv*
	Show info or debug-level terminal UX.

*-q*, *--quiet*
	Show only terminal errors.

*--silent*
	Suppress terminal UX. File logging still follows *BEBASH_LOG_LEVEL*.

*--color* auto|always|never
	Override terminal color behavior.

# ENVIRONMENT

*BEBASH_LIB*
	Payload root containing *init.bash*, *VERSION*, *lib/*, and templates.

*BEBASH_CONFIG_DIR*
	User config root. Defaults to *$XDG_CONFIG_HOME/bebash*.

*BEBASH_DATA_DIR*
	User code root for functions, libs, rc.d, and standalone command sources.
	Defaults to *$XDG_DATA_HOME/bebash*.

*BEBASH_LOG_LEVEL*
	Log file threshold. Defaults to *warn*.

*BEBASH_LOG_STDERR*
	When non-empty, mirror log records to stderr.

*BEBASH_LOG_FILE*
	Override the log file path.

*NO_COLOR*, *FORCE_COLOR*, *CLICOLOR_FORCE*
	Disable or force color for human-facing terminal output.

*XDG_CONFIG_HOME*
	Base directory for the user config overlay.

*XDG_STATE_HOME*
	Base directory for logs and the install manifest.

*XDG_DATA_HOME*
	Base directory for the user code overlay and for completion and man page
	install targets.

# FILES

*$BEBASH_LIB/init.bash*
	Shell payload entry point.

*$BEBASH_LIB/.shellcheckrc*
	Shellcheck config used by *doctor* for user artifacts.

*$BEBASH_LIB/man/bebash.1.scd*
	Manual source used by *bebash man*.

*$BEBASH_LIB/libexec/commands/cmd_<name>.bash*
	CLI subcommand handlers, loaded on dispatch.

*$XDG_CONFIG_HOME/bebash/config.bash*
	User config sourced by the shell payload.

*$XDG_CONFIG_HOME/bebash/AGENTS.md*
	Lean pointer for coding agents. It directs agents to this CLI reference.

*$XDG_DATA_HOME/bebash/functions/<name>.bash*
	User function overrides and additions.

*$XDG_STATE_HOME/bebash/bebash.log*
	Default log file.

*$XDG_STATE_HOME/bebash/install-manifest*
	Installer manifest path.

*$XDG_DATA_HOME/bash-completion/completions/bebash*
	Completion install path.

*$XDG_DATA_HOME/man/man1/bebash.1*
	Man page install path.

# EXIT STATUS

*0*
	Success.

*1*
	Operational failure, such as a required *doctor* check failing.

*2*
	Usage error: unknown command, unknown flag, missing argument, or invalid
	argument.

*66*
	Manual source or input file not found.

*69*
	Required service or tool unavailable, such as missing *EDITOR* for *edit*.

*70*
	Internal packaging or command handler error.

*73*
	Could not create an output file, directory, or symlink.

# SEE ALSO

*bash*(1), *scdoc*(5), *sysexits*(3)
