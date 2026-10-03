# akogu

Shared library of agent tooling (skills now; configuration later) for Codex, Claude Code, and other agents. `README.md` covers layout and setup.

## Editing skills

`skills/<group>/*`, `codex/skills/*`, and `claude/skills/*` are symlinked into the user's global skill directories, so every edit is live for every agent on this machine as soon as it is saved. Treat a skill edit as a global behavior change.

- Author skills with the `writing-for-agents` skill.
- A skill in `skills/` must work in every agent. Put a skill used by only one agent in `codex/skills/` or `claude/skills/`.
- Place a global skill in the `skills/` group for the kind of work it supports: `engineering` for working on code, `productivity` for thinking, writing, and agent workflow, or a stack group (`dotnet`, `aspire`, `web`). Keep a vendored skill in its upstream category when one exists. `sources.json` keys each entry by its group directory.
- Declare invocation for both hosts: a user-invoked skill sets `disable-model-invocation: true` in `SKILL.md` (Claude) and `policy.allow_implicit_invocation: false` in `agents/openai.yaml` (Codex).
- Record every added, removed, or edited skill in `sources.json`. Editing a `pristine` skill makes it `modified`; add a `note` naming what changed.
- After adding, removing, or renaming a skill directory, run `scripts/link.sh` and report its dry-run output; run `--apply` only when the user asks.

## Upstream updates

Run `scripts/upstream-diff.sh [skill...]` to compare with upstream. Replace `pristine` skills wholesale. Merge upstream into `modified` skills by hand, keeping local edits, and update the recorded `commit`.

## Project snapshots

`projects/<repo>/skills/` holds reference copies; the project repository owns the real files. Refresh with `scripts/snapshot-project.sh <repo-path>`. These copies are never linked or edited here.
