# ADR-0023: Standalone command lane and naming

## Context and Problem Statement

bebash has three command-like surfaces: sourced shell functions, internal
management verbs, and user-authored standalone executables. Without a naming
rule, reusable user commands can drift into `bebash <sub>` or unnecessary
prefixes.

## Considered Options

- Put every command behind `bebash <sub>`.
- Expose every command with a `bebash-` prefix.
- Keep separate lanes with natural names.

## Decision Outcome

Chosen option: **separate lanes with natural names**. Interactive shell helpers
remain lazy-loaded functions. `bebash <sub>` is reserved for framework
self-management and dispatches private handlers from `libexec/commands/`.
Standalone commands are ordinary executables exposed on `PATH` with natural
names; use a prefix only when it communicates real ecosystem membership or
avoids a collision. This follows Git's split between `git` porcelain and
discoverable `git-<command>` executables
(<https://git-scm.com/docs/git#Documentation/git.txt-codegit-codecommands>).

## Consequences

- Good: management verbs stay compact, while user commands behave like normal
  shell tools.
- Bad: command exposure needs explicit symlink/install discipline outside the
  sourced framework loader.

## Status

Accepted — implemented by the `libexec/commands/` handler lane, the
`functions/` autoload lane, and `init-user` scaffolding of
`$BEBASH_DATA_DIR/commands`.
