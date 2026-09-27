# Skill mechanics

The skill-specific branch of [`writing-for-agents`](SKILL.md): what changes when the document is a skill (frontmatter, the invocation choice, and router skills). Everything else about writing it is the universal reference in `SKILL.md`.

## Invocation

Codex discovers skills through their name and description and loads the body when selected. Write a concise description with the actual task scope.

Use `policy.allow_implicit_invocation: false` in `agents/openai.yaml` for an explicitly invoked skill; normal implicit selection is enabled by default. Preserve the user's intended invocation mode. The SKILL.md field `disable-model-invocation` is not the invocation control documented by OpenAI for Codex. Other hosts may use different metadata.

Explicit invocation remains available. Do not promise a fixed context saving or that metadata disappears from every host's skill catalog. Shared instructions can be linked as ordinary references regardless of invocation policy.

See [OpenAI skill documentation](https://developers.openai.com/codex/skills) for current Codex metadata.

## Splitting by invocation

The invocation cut of splitting (the sequence cut lives in `SKILL.md`): split off a model-invoked skill when you have a distinct leading word that should trigger it on its own (a trigger word you actually use in your prompts), or another skill must reach it. You pay context load for the new always-loaded description, so that independent reach has to be worth it.

## Router skills

A router can list specialized workflows and their selection conditions. Read referenced material through its documented path; do not assume cross-host invocation behavior or create circular routes.
