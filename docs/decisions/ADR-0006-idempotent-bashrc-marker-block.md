# ADR-0006: Idempotent `.bashrc` marker block

## Context and Problem Statement

To load bebash, the user's `~/.bashrc` must source `init.bash`. The installer
should add that line automatically but must never corrupt a hand-maintained
`.bashrc`, never duplicate the line on re-install, and be reversible. A blind
`>>` append fails all three.

## Considered Options

- Blind append of a `source` line on every install.
- Print the line and ask the user to paste it (no automation).
- A guarded, marker-delimited managed block, detected and replaced idempotently.

## Decision Outcome

Chosen option: **managed marker block** — `# >>> bebash >>>` … `# <<< bebash <<<`
delimiters, detected with `grep -qF`. Absent → back up `.bashrc` once, then
append the block. Present → replace in place via a temp file. This is the pattern
conda/nvm/atuin/starship use.

## Consequences

- Good: idempotent (re-runs are no-ops or clean updates); reversible (uninstall
  strips the block); safe (a backup precedes the first write).
- Good: the sourced line is interactive-guarded (`[[ $- == *i* ]]`) so
  non-interactive shells never pay for it.
- Bad: editing another program's rc file is inherently delicate; we accept the
  marker-block convention and a one-time `.bak` as mitigation.

## Status

Accepted — enacted by the `.bashrc`-wiring step of `install.sh`; exact logic in
[reference/installer-and-manifest.md](../reference/installer-and-manifest.md).
