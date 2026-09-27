---
name: code-review
description: Review committed or working changes against repository standards and the originating requirements. Use for branch, PR, staged, or uncommitted change reviews.
---

# Code review

Review both correctness against requirements and conformance to documented standards. Keep review read-only unless the user requests repairs.

## Select the actual input

Inspect `git status --short` before selecting a comparison. Honor explicit scope; otherwise an implementation review covers the task's working changes.

| Request | Review input |
| --- | --- |
| Uncommitted changes or implementation handoff | `git diff HEAD --` for tracked changes, plus relevant files from `git ls-files --others --exclude-standard` |
| Staged changes only | `git diff --cached --` |
| Branch or PR against a base | Resolve the base with `git rev-parse --verify`, then `git diff <base>...HEAD --` and `git log <base>..HEAD --oneline` |
| Exact comparison with a commit | `git diff <commit> HEAD --`; do not substitute merge-base semantics |

Quote refs and paths appropriately. If the repository has no HEAD, inspect the staged diff, unstaged diff, and relevant untracked files separately. An empty tracked diff does not mean there is nothing to review. Inspect relevant untracked content directly. Separate unrelated user work from task-owned changes without staging or modifying it. State the selected scope and omissions. Ask about the base only when it cannot be established from the request or branch context.

## Establish requirements and standards

Use the user's task and accepted decisions, an explicitly supplied specification, and relevant current product documentation. Discover the repository's issue tracker and requirement sources from its agent guidance; do not assume a particular tracker or directory. If requirements are absent, perform a correctness and standards review and report that requirement coverage could not be assessed.

Use the repository's documented coding conventions and relevant current architectural decisions, locating them through its agent guidance or documentation index. Read surrounding code and affected consumers before reporting a defect. Distinguish observable bugs and documented-rule conflicts from design preferences. Formatting already enforced by tooling does not need a review finding.

## Review and report

For a non-trivial change, use a bounded independent reviewer when it can catch meaningful defects alongside useful main-session work. Pass the exact comparison, relevant untracked paths, requirement sources, and standards. Keep requirements, decisions, and final approval in the main session. Small changes can be reviewed directly; the workflow must work without subagents.

Check for missing or incorrect behavior, scope expansion, boundary failures, and regression risk. Treat duplication, naming, and abstraction concerns as contextual judgments; repository conventions take precedence over generic code-smell advice.

Validate candidate findings against the full change and surrounding code. Report actionable findings by severity with file/line evidence, the triggering scenario, and its consequence. Identify whether each concerns requirements, correctness, or standards. Remove unsupported and duplicate findings. Report validation performed and limitations; when no findings remain, say so without claiming the change is proven defect-free.
