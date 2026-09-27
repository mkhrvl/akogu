---
name: maintain-codex-config
description: Maintain and validate authored Codex configuration. Use when editing global instructions, custom agents, rules, maintenance scripts, or personal skills; do not use for ordinary project work merely performed with Codex.
---

# Maintain Codex configuration

Apply this workflow only to the user's Codex configuration and personal skills placed in scope.

## Edit boundaries

- Limit changes to authored configuration, agent definitions, instructions, rules, maintenance scripts, documentation, and personal skills in scope.
- Treat credentials, session history, logs, caches, state databases, installed plugin caches, and generated assets as runtime state unless the user explicitly targets them.
- Keep credential values and other secrets out of commands, patches, validation output, and final responses.
- Make mandatory local skill and document references resolve. State the condition for repository-provided or optional references.
- When subagent routing or descriptions change, review `agents/evals.md` under the active Codex home and keep every configured role covered.

## Validate changes

Resolve the active Codex home before running its local checks:

```bash
codex_config_root="${CODEX_HOME:-$HOME/.codex}"
```

- After changing `config.toml`, `AGENTS.md`, files under `agents/`, or their validator, run:

  ```bash
  python3 "$codex_config_root/scripts/validate-agent-config.py" --root "$codex_config_root"
  codex doctor --summary --no-color
  ```

- After creating or changing a skill, run the installed skill validator against that skill directory:

  ```bash
  python3 "$codex_config_root/skills/.system/skill-creator/scripts/quick_validate.py" <skill-directory>
  ```

- Report configuration failures separately from provider reachability, WebSocket, optional MCP, stale app-server, and other environment-only doctor findings. Do not change unrelated configuration merely to clear those findings.
- Tell the user to start a fresh Codex session after changing global instructions, custom agents, or personal skills.
