---
name: testing
description: Use when adding, changing, debugging, reviewing, or running tests, or when establishing or updating a repository's testing conventions.
---

# Testing

Follow the repository's testing conventions and validate behavior at the appropriate test level.

## Workflow

1. Read repository guidance and existing testing documentation.
2. Inspect representative tests and test infrastructure as needed to resolve conventions.
3. Infer conventions from repository evidence. Do not assume a language, framework, or library.
4. Put each behavior at the cheapest test level that reliably owns its failure mode.
5. Use the relevant references when designing tests, choosing test doubles, or deciding what to run.
6. Report what was tested, skipped, or left as a coverage gap.

## Repository testing guide

Prefer an existing `testing.md`, `TESTING.md`, `docs/testing.md`, or equivalent. Do not create a competing document.

Create or update testing guidance only when conventions are missing, materially outdated, or the task establishes new conventions.

Keep it concise and project-specific. Record only stable conventions the repository actually uses, such as:

- test framework, runner, assertion, mocking, and test-data libraries
- test levels and ownership
- folder and naming conventions
- database, container, HTTP, or application-host test infrastructure
- fixtures, collections, and time-testing conventions
- test and verification commands
- known framework-specific exceptions

Avoid duplicating generic testing rules from this skill or its references.

## Test design

Test observable behavior through stable public seams rather than implementation details.

Keep one authoritative test level for each behavior. Add higher-level coverage only when that boundary introduces a distinct failure mode.

## TDD

Use TDD when a failing test helps define the contract or reproduce a bug. Do not require it for every change.

Work one behavior at a time:

1. Write one failing test for the next behavior and confirm it fails for the intended reason.
2. Make the smallest change that passes it.
3. Refactor without changing behavior.
4. Repeat.

## References

- [Focused testing](references/focused-testing.md) — read when choosing which tests and verification scopes to run.
- [Test design](references/tests.md) — read when adding, changing, or reviewing tests.
- [Mocking](references/mocking.md) — read when deciding whether or where to use test doubles.
