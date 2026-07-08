# Agent Guidelines — bebash

The single source of truth for **how agents work in this project**. `CLAUDE.md` imports it with
`@AGENTS.md`, so Claude Code and the `AGENTS.md`-native tools (Codex, Cursor, and others) read one
authored document. This file owns working conventions only — it does not restate the design or
specs, which live in the [`docs/`](docs/README.md) shelf.

## Scope

bebash is a self-contained, XDG-friendly Bash **framework** (lazy-autoloaded functions + `rc.d`
modules + a split `__ui_*`/`__log_*` output layer) that **also** ships a small `bebash` management
CLI. Cloned and installed with `just install`; users layer their own functions and config on top
via an overlay directory.

## Entry point

Start at [`docs/AGENTS.md`](docs/AGENTS.md) — the docs digest that **maps** the shelf — then read
the `docs/` zone that owns the change. The digest does not restate the zones; **when the digest and
a zone file disagree, the zone file wins.** `docs/` is the design + spec source of truth that drives
the runtime, CLI, installer, and tests.

## Working Conventions

- **Self-containment.** Non-negotiable — load-bearing knowledge lives in-repo; external references
  are public links/citations for further reading only. Decision record:
  [ADR-0020](docs/decisions/ADR-0020-repository-self-containment.md).
- **Decisions.** Record every significant, hard-to-reverse decision as an ADR under
  [`docs/decisions/`](docs/decisions/), one per file, using
  [`template.md`](docs/decisions/template.md) (MADR-minimal, ≤350 words). Accepted ADRs are never
  deleted — a changed decision gets a new superseding ADR.
- **Lint and test through the task runner, never directly.** Run `just lint` and `just test`; both
  drive pre-commit inside the pinned Nix devShell. Every check bebash owns is a pre-commit hook
  (see [`docs/reference/tooling.md`](docs/reference/tooling.md)).
- **Conventional Commits** ([ADR-0013](docs/decisions/ADR-0013-conventional-commits-and-semver.md))
  gate every commit message; the release flow derives the version and changelog from them.
- **`master` is written only by CI** ([ADR-0015](docs/decisions/ADR-0015-develop-integrates-master-mirrors.md)).
  Integrate on `develop`; never commit to `master` by hand.
- Keep changes scoped and reversible; prefer editing existing files over adding new ones. Rationale
  lives beside the code it describes.
