BEBASH(1)

# NAME

bebash - manage the bebash Bash framework and user overlay

# SYNOPSIS

*bebash* [global flags] <command> [args]

# DESCRIPTION

*bebash* is the management CLI for the bebash Bash framework. It inspects the
installed payload, scaffolds the XDG user overlay, lists available functions,
and prints machine-readable data for scripts when *--json* is used.

# COMMANDS

*doctor*
	Run health checks for Bash, payload, overlay, PATH, log writability, and
	optional tools.

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

*init-user*
	Create or verify the user overlay skeleton. It creates the config skeleton
	(*disabled.d/* and *config.bash*) under *$XDG_CONFIG_HOME/bebash* and the
	data skeleton (*functions/*, *lib/*, *rc.d/*, *commands/*) under
	*$XDG_DATA_HOME/bebash*, without clobbering existing files.

*version*
	Print the installed version string from *VERSION*.

*help* [command]
	Show general usage or command-specific usage.

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
	Payload root containing *init.bash*, *VERSION*, and *lib/*.

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

$BEBASH_LIB/libexec/commands/cmd_<name>.bash
	CLI subcommand handlers, loaded on dispatch.

*$XDG_CONFIG_HOME/bebash/config.bash*
	User config sourced by the shell payload.

$XDG_DATA_HOME/bebash/functions/<name>.bash
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

*69*
	Required service or tool unavailable, such as missing *EDITOR* for *edit*.

*70*
	Internal packaging or command handler error.

*73*
	Could not create an output file or directory.

# SEE ALSO

*bash*(1), *scdoc*(5), *sysexits*(3)
