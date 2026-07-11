# ADR-0030: Defer Bebash Skills

## Context

A future "skills" scaffold could generate richer reusable overlays or agent
workflows, but the current CLI already has a function generator through
`bebash edit --new` and `templates/`.

## Decision

The skills scaffolding and generator concept is deferred. `bebash edit --new`
and existing templates remain the only generator surface for now.

## Consequences

No skills registry, artifact format, or generator command ships in this change.
The idea can be revisited with a dedicated specification and follow-up ADR when
the required behavior is clearer.

## Status

Proposed
