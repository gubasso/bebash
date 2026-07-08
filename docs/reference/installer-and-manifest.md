# Reference: Installer and manifest

The exact behavior of `install.sh` / `uninstall.sh`, the manifest, and the
`.bashrc` wiring. Decisions: [ADR-0004](../decisions/ADR-0004-install-with-just-and-install-sh.md),
[ADR-0006](../decisions/ADR-0006-idempotent-bashrc-marker-block.md),
[ADR-0019](../decisions/ADR-0019-payload-init-shell-wiring-and-bebash-lib-root.md).

## Targets

| Artifact         | Path (user install)                                    |
| ---------------- | ------------------------------------------------------ |
| Payload          | `$PREFIX/lib/bebash/` (default `~/.local/lib/bebash`)  |
| CLI symlink      | `$PREFIX/bin/bebash` -> payload `bin/bebash`           |
| Completion       | `$XDG_DATA_HOME/bash-completion/completions/bebash`    |
| Man page         | `$XDG_DATA_HOME/man/man1/bebash.1`                     |
| Manifest + state | `$XDG_STATE_HOME/bebash/`                              |

Root install (`EUID 0`) uses system paths (`$PREFIX/lib`, `/usr/local/bin`,
`share/man`); detected via `[[ $EUID -eq 0 ]]`. `PREFIX`/`XDG_*` override both.

## `install.sh` step sequence

1. **Resolve repo root** through symlinks (works under stow / `ln -s` / copies).
2. **Resolve targets** — `PREFIX` (default `~/.local`), `XDG_*` defaults;
   `app_root=$PREFIX/lib/bebash`, `state_dir=$XDG_STATE_HOME/bebash`.
3. **Open a temp manifest** under `state_dir` with an `EXIT` trap to clean it.
4. **Hard-clear the previous payload** (`app_root/bin`, `app_root/lib`,
   `app_root/init.bash`, `app_root/VERSION`) so no stale files survive an upgrade.
   The **overlay is never touched.**
5. **Copy payload** — `bin/`, `lib/`, `init.bash`, `VERSION`, recording each
   written path into the manifest. `VERSION` is a committed repo file — the
   authoring source of truth — copied into `app_root/VERSION` like any other
   payload file
   ([ADR-0018](../decisions/ADR-0018-committed-version-is-authoring-sot.md); the
   signed `v*` tag mirrors it).
6. **Symlink the CLI** — `ln -sfn "$app_root/bin/bebash" "$PREFIX/bin/bebash"`;
   record it.
7. **Install completion + man page** to their XDG locations (man built from
   `man/bebash.1.scd` via scdoc if a prebuilt `.1` is absent; skipped with a
   warning if scdoc is missing); record them.
8. **Wire `~/.bashrc`** (next section).
9. **Finalize the manifest** — sort-unique; diff against the previous manifest and
   `rm` any now-stale bebash-owned file, pruning empty dirs; move the temp manifest
   into place at `$state_dir/install-manifest`.
10. **Print a summary** — install paths + the activation hint.

Re-running is idempotent: step 4 clears, steps 5–7 recopy, step 9 prunes.

## Manifest

- Newline-delimited list of **absolute** paths, one per line, sorted-unique.
- Stored at `$XDG_STATE_HOME/bebash/install-manifest`.

Example (user install):

```text
/home/me/.local/lib/bebash/VERSION
/home/me/.local/lib/bebash/bin/bebash
/home/me/.local/lib/bebash/init.bash
/home/me/.local/lib/bebash/lib/ui.bash
/home/me/.local/bin/bebash
/home/me/.local/share/bash-completion/completions/bebash
/home/me/.local/share/man/man1/bebash.1
```

Only paths under this **whitelist** are eligible for deletion during a re-install
prune or uninstall — a guard against removing anything outside bebash's own trees:

| Root                                                | Holds            |
| --------------------------------------------------- | ---------------- |
| `$PREFIX/lib/bebash/`                               | the payload      |
| `$PREFIX/bin/bebash`                                | the CLI symlink  |
| `$XDG_DATA_HOME/bash-completion/completions/bebash` | completion       |
| `$XDG_DATA_HOME/man/man1/bebash.1`                  | man page         |
| `$XDG_STATE_HOME/bebash/`                           | manifest + state |

A manifest path outside every whitelisted root is refused (not deleted), so a
mismatched `PREFIX`/`XDG_*` can never orphan or wipe unrelated files.

## `.bashrc` wiring (marker block)

Idempotent, backup-first, never a blind append:

```bash
begin="# >>> bebash >>>"; end="# <<< bebash <<<"
block=$'# >>> bebash >>>\n'
block+=$'[[ $- == *i* ]] && '
block+=$'[[ -r "/home/me/.local/lib/bebash/init.bash" ]] &&\n'
block+=$'  source "/home/me/.local/lib/bebash/init.bash"\n'
block+=$'# <<< bebash <<<'

if grep -qF "$begin" "$HOME/.bashrc" 2>/dev/null; then
  tmp=$(mktemp) || exit 1
  sed "/^$begin\$/,/^$end\$/d" "$HOME/.bashrc" > "$tmp"
  printf '\n%s\n' "$block" >> "$tmp"
  mv "$tmp" "$HOME/.bashrc"                 # replace existing block in place
else
  cp "$HOME/.bashrc" "$HOME/.bashrc.bebash.bak"   # back up once
  printf '\n%s\n' "$block" >> "$HOME/.bashrc"      # first install
fi
```

The sourced line is interactive-guarded (`[[ $- == *i* ]]`) so non-interactive
shells skip it. The example path is illustrative: the installer writes the
actual resolved `$app_root/init.bash` path at install time, not a literal
`$PREFIX` expression, because `PREFIX` and `XDG_*` are not reliable in a fresh
login shell. The payload `init.bash` then discovers the overlay at
`${XDG_CONFIG_HOME:-$HOME/.config}/bebash/config.bash`.

## `uninstall.sh`

Reads the manifest, validates each path against the whitelist, `rm -f`s it, prunes
now-empty bebash dirs, then strips the `.bashrc` marker block. The overlay
(`~/.config/bebash/`) is left intact. It must run with the same `PREFIX`/`XDG_*`
as install — if a manifest path falls outside the expected roots it refuses to
proceed (rather than orphan files), matching the sibling installer's safety gate.
