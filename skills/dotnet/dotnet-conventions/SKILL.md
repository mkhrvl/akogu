---
name: dotnet-conventions
description: C# and .NET engineering conventions. Use when writing, reviewing, or refactoring C# code, or creating a new .NET project or solution.
---

# .NET conventions

The standard for new .NET projects and the yardstick for improving existing ones.

## Precedence

- A repository's own guides and ADRs override this skill. Read the guidance its `AGENTS.md` points to first; a deviation listed there is settled, not a gap.
- Named libraries and providers are defaults for new projects. An established equivalent in an existing repository is not a gap.
- In an existing repository, established code wins over this skill for the change at hand. Where the repository falls short of a convention here, finish the task in the local style and report the gap as a suggested improvement rather than rewriting unrelated code.
- `Prefer` is the normal default; a justified alternative may fit better. `Avoid` marks a usually harmful choice. `Do not` is a correctness, security, interoperability, or architectural guardrail. `Must` is required to satisfy a contract.

## References

Read every reference whose trigger matches the work before writing code; a change touching several areas reads several.

| Trigger | Read |
| --- | --- |
| Designing types, constructors, members, comments, async work, or cancellation | [C#](references/csharp.md) |
| Placing code in features, laying out slice files, or adding endpoints, commands, queries, handlers, validators, or ports | [Architecture](references/architecture.md) |
| Adding logs, metrics, options, configuration, dependency injection, or abstractions | [Application](references/application.md) |
| Modeling expected failures, validation, entities, value objects, identifiers, enums, time, or money | [Domain](references/domain.md) |
| Changing EF Core models, queries, transactions, or migrations | [Persistence](references/persistence.md) |
| Adding inbound endpoints, shaping error responses, hardening for production, or calling external HTTP systems | [HTTP](references/http.md) |
| Writing or changing FastEndpoints endpoints, validators, or configuration | [FastEndpoints](references/fastendpoints.md) |
| Writing, naming, or structuring .NET tests | [Testing](references/testing.md) |
| Creating a solution or project, or changing build, analyzer, tool, or local-orchestration setup | [Project setup](references/project-setup.md) |

Test design and scope selection beyond the .NET specifics belong to the `testing` skill.
