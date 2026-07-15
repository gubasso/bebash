# Reference: Installer and manifest

The exact behavior of `install.sh` / `uninstall.sh`, the manifest, and the
`.bashrc` wiring. Decisions: [ADR-0004](../decisions/ADR-0004-install-with-just-and-install-sh.md),
[ADR-0006](../decisions/ADR-0006-idempotent-bashrc-marker-block.md),
[ADR-0019](../decisions/ADR-0019-payload-init-shell-wiring-and-bebash-lib-root.md).

## Targets

| Artifact         | Path (user install)                                    |
| ---------------- | ------------------------------------------------------ |
| Payload          | `$PREFIX/lib/bebash/` (default `~/.local/lib/bebash`)  |
| `bebash` CLI     | `$PREFIX/bin/bebash` (real executable)                 |
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
4. **Hard-clear the previous payload** (`app_root/bin` — stale from the old
   symlink layout, `app_root/lib`, `app_root/libexec`, `app_root/functions`,
  `app_root/rc.d`, `app_root/templates`, `app_root/man`, `app_root/.shellcheckrc`,
   `app_root/init.bash`,
   `app_root/init-headless.bash`, `app_root/VERSION`) so no stale files survive
   an upgrade. The **overlay is never touched.**
5. **Copy payload** — `lib/`, `libexec/`, `functions/`, `rc.d/`, `templates/`,
   `man/`, `.shellcheckrc`, `init.bash`, `init-headless.bash`, `VERSION`,
   recording each written path into the manifest. The payload no longer carries
   a `bin/` subdir (see step 6).
   `VERSION` is a committed repo file — the authoring source of truth — copied
   into `app_root/VERSION` like any other payload file
   ([ADR-0018](../decisions/ADR-0018-committed-version-is-authoring-sot.md); the
   signed `v*` tag mirrors it).
6. **Install the CLI as a real executable** — `cp "$repo_root/bin/bebash"
   "$PREFIX/bin/bebash"` (mode `0755`), recording it. It self-locates its library root at
   `$bindir/../lib/bebash`, so no symlink hop into the payload is needed
   ([ADR-0025](../decisions/ADR-0025-real-fhs-bin-with-dual-layout-self-location.md)).
7. **Install completion + man page** to their XDG locations (man built from
   `man/bebash.1.scd` via scdoc if a prebuilt `.1` is absent; skipped with a
   warning if scdoc is missing); record them.
8. **Finalize the manifest** — sort-unique; **reconcile** the payload tree (reap any
   file under the installer-owned `app_root` the fresh manifest does not list — closes
   the blind spot where the step-4 hard-clear misses arbitrary top-level leftovers);
   diff against the previous manifest and `rm` any now-stale bebash-owned file, pruning
   empty dirs; move the temp manifest into place at `$state_dir/install-manifest`.
9. **Link overlay commands** — if `$BEBASH_DATA_DIR/commands` exists, run
   `bebash link-commands` (best-effort) to create/prune `$PREFIX/bin/<name> -> bebash-cmd`
   shims ([ADR-0031](../decisions/ADR-0031-non-interactive-command-shims.md)).
10. **Print a summary** — install paths (with payload file count) + the manual
    shell-integration hint. The installer **never** edits `~/.bashrc`
    ([ADR-0033](../decisions/ADR-0033-installer-never-mutates-user-shell-config.md)).

Re-running is idempotent: step 4 clears, steps 5–7 recopy, step 9 reconciles + prunes.

On failure the installer reports the failing line/command (via an `ERR` trap) and
finalizes nothing — the manifest is only moved into place at the very end, so a
previous install is left intact.

## Manifest

- Newline-delimited list of **absolute** paths, one per line, sorted-unique.
- Stored at `$XDG_STATE_HOME/bebash/install-manifest`.

Example (user install):

```text
/home/me/.local/lib/bebash/VERSION
/home/me/.local/lib/bebash/.shellcheckrc
/home/me/.local/lib/bebash/init-headless.bash
/home/me/.local/lib/bebash/init.bash
/home/me/.local/lib/bebash/lib/ui.bash
/home/me/.local/lib/bebash/man/bebash.1.scd
/home/me/.local/bin/bebash
/home/me/.local/share/bash-completion/completions/bebash
/home/me/.local/share/man/man1/bebash.1
```

Only paths under this **whitelist** are eligible for deletion during a re-install
prune or uninstall — a guard against removing anything outside bebash's own trees:

| Root                                                | Holds            |
| --------------------------------------------------- | ---------------- |
| `$PREFIX/lib/bebash/`                               | the payload      |
| `$PREFIX/bin/bebash`                                | the `bebash` CLI  |
| `$XDG_DATA_HOME/bash-completion/completions/bebash` | completion       |
| `$XDG_DATA_HOME/man/man1/bebash.1`                  | man page         |
| `$XDG_STATE_HOME/bebash/`                           | manifest + state |

A manifest path outside every whitelisted root is never deleted, so a mismatched
`PREFIX`/`XDG_*` can never wipe unrelated files. The two paths differ by intent:

- **Re-install** is **self-healing** — an old-manifest path that is no longer
  whitelisted (e.g. a command extracted into its own project between versions) is
  left in place with a note and dropped from the new manifest, so the install never
  fails closed on a stale entry.
- **Uninstall** is **fail-closed** — a manifest with any out-of-whitelist or
  traversal (`..`) path is refused wholesale, mutating nothing (the manifest is the
  authority for what to delete, so a suspicious one must not be acted on).

## Shell integration (not performed by the installer)

The installer **does not write your `~/.bashrc`** — that is user-authored
configuration, and mutating it at runtime violates one-writer-per-file and breaks
on a read-only / Home-Manager-managed rc
([ADR-0033](../decisions/ADR-0033-installer-never-mutates-user-shell-config.md),
superseding [ADR-0006](../decisions/ADR-0006-idempotent-bashrc-marker-block.md)).
Instead it prints the exact line to add and leaves the write to you or your config
manager. Add it near the top of your interactive rc, before personal config:

```bash
[[ $- == *i* ]] && [[ -r "$HOME/.local/lib/bebash/init.bash" ]] &&
  source "$HOME/.local/lib/bebash/init.bash"
```

The `[[ $- == *i* ]]` guard keeps non-interactive shells from paying for it; the
`-r` guard makes the line inert if bebash is removed. The payload `init.bash`
then discovers the overlay at
`${XDG_CONFIG_HOME:-$HOME/.config}/bebash/config.bash`.

## `uninstall.sh`

Reads the manifest, validates each path against the whitelist, `rm -f`s it, and
prunes now-empty bebash dirs. It also removes the `bebash-cmd` command shims it
created (tracked in `$XDG_STATE_HOME/bebash/commands-manifest`, only when they
still point at `bebash-cmd`). It **never** touches your `~/.bashrc` (it never
wrote there); remove the source line yourself. The overlay (`~/.config/bebash/`)
is left intact. It must run with the same `PREFIX`/`XDG_*` as install — if a
manifest path falls outside the expected roots it refuses to proceed (rather than
orphan files), matching the sibling installer's safety gate.
