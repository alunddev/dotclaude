---
description: Explain a piece of code, file, module, or system in layered detail. Adapts to the user's depth — high-level by default, drill-down on request.
argument-hint: "<file_or_path_or_symbol>"
---

# /explain — Code explanation

Explain `$ARGUMENTS` clearly and at the right depth. Default: 3-layer explanation.

## Layers

### Layer 1 — One paragraph (always)
What this code/file/system **does** and **why it exists**. No implementation detail. If the user just wants this, stop here.

### Layer 2 — Structural breakdown (default)
- Inputs / outputs / side effects
- Key types and data flow
- External dependencies (DB, API, queue, etc.)
- Where it fits in the larger system (callers, callees, related modules)

### Layer 3 — Line-by-line (on request)
Drill into the implementation. Quote specific lines (`path/to/file.ts:42`). Explain non-obvious choices: why a `Map` not a `Record`, why `Promise.allSettled` not `Promise.all`, etc.

## Rules

- **No hand-waving.** "It handles authentication" is not an explanation — say *how* (token validation, session lookup, etc.).
- **Quote real code**, don't paraphrase. Use ``code spans`` for symbols and `file:line` for navigation.
- **Surface bugs you notice**, but in a separate "Side notes" section at the bottom. Don't conflate explanation with critique.
- **Adapt to the asker.** If they're clearly new to the codebase, lead with vocabulary (what's an "Aggregate" in this codebase, what's a "Worker"). If they wrote it 2 weeks ago, skip the basics.

## When the target is large

If the file/module is too big to explain in one response:
1. Print Layer 1 only for the whole thing.
2. List the major sub-parts and ask which one to drill into.
3. Don't try to cram a 2000-line file into one response.

## When to delegate

For broad-codebase questions ("how does the auth flow work?", "where does X come from?"), delegate to the `Explore` agent for a thorough search before explaining. For deep architectural questions, consider `architect-reviewer`.
