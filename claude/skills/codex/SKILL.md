---
name: codex
description: Delegate work to OpenAI Codex (the `codex` CLI) as a sub-agent — code review and second opinions, implementation in an isolated git worktree, or codebase research/debugging — then verify and integrate its result. Use whenever the user mentions Codex ("ask codex", "have codex do/review/check", "get codex's take", "run it by codex", "codex as a subagent"). Also use proactively when an independent model's view adds real value: reviewing a non-trivial diff or plan before calling it done, breaking a debugging deadlock after two failed hypotheses, or cross-checking a risky design decision.
---

# Codex as a sub-agent

Codex is a separate agent from a different model family. It is useful because its mistakes are uncorrelated with yours: a finding you both agree on is stronger, and a disagreement points to something worth checking. Treat its output as a colleague's report. Verify it before relaying or acting on it.

All runs go through `scripts/codex-run.sh` (next to this file). It closes stdin (otherwise `codex exec` waits on it), captures the final message and JSONL events, and reports the session id and any new worktree.

## 1. Pick a mode

| Need | Mode | Effect |
|---|---|---|
| Opinion, research, debugging hypotheses, plan critique | `read` | read-only sandbox in the current repo |
| Review of a diff | `review` | Codex's built-in reviewer, plus `--uncommitted`, `--base <branch>` or `--commit <sha>` |
| Code changes | `write` | new detached worktree under `~/.codex/worktrees/`. Your working tree is never touched |
| Follow-up on a previous run | `resume` | continues the same session and keeps its context |

Only use `write` when the user asked for Codex to implement something. For proactive use (you decided to consult Codex), stay in `read` or `review`, and tell the user in one line that you're doing it, since it costs time and tokens.

## 2. Pick a model and reasoning effort

Pick by the kind of task, not by how important it sounds.

| Model / effort | Use for |
|---|---|
| `--model luna` (`gpt-6-luna`), `high` (default) or `xhigh` | Trivial tasks: "where is X handled", listing call sites, a one-line fact about the repo, renames and other mechanical edits. It's a lighter model, so run it at `high`, and use `xhigh` when the trivial task is fiddly (many small spots to get right) |
| `sol` (`gpt-5.6-sol`, default), `medium` | Everything that is not a review or second opinion: investigations, debugging, research, implementation |
| `sol`, `high` | Reviews and second opinions only: `review` mode (where it is the default), plus `read` or `resume` runs whose brief asks Codex to critique a diff, plan, design, or decision |

sol accepts only `medium` or `high`, and luna only `high` or `xhigh`. The script rejects anything else. Don't raise non-review work to `high`; if a result comes back shallow, follow up with `resume` and a sharper brief. `resume` uses whatever `--model` you pass (default sol), so pass `--model luna` again to stay on luna, or omit it to move a luna session up to sol.

## 3. Write a self-contained brief

Codex has not seen this conversation. Write the brief to a file in your scratchpad, and don't paste it into the shell, which avoids quoting problems. A good brief includes:

- **Goal**: the one question or task, stated first.
- **Context**: the relevant files and paths, the decisions already made, the constraints (repo conventions, ADRs, what not to change), and what you already tried or ruled out. Point to files; don't paste them. Codex can read the repo.
- **Deliverable**: the exact shape you want back, e.g. "a ranked list of findings with file:line and a failure scenario", "a root-cause hypothesis with evidence", or "implement X, run `<test command>`, and report what changed and the test results".
- **Scope limits** for `write`: which files or areas it may touch, and "do not commit" (you review first).

For second opinions, don't lead with your own conclusion. Ask the open question first, and only then, optionally, give your current view and ask for a challenge. Otherwise it tends to agree with you.

## 4. Run it

From the repo root:

```bash
~/.claude/skills/codex/scripts/codex-run.sh --model luna    read   <brief.md>
~/.claude/skills/codex/scripts/codex-run.sh                 read   <brief.md>
~/.claude/skills/codex/scripts/codex-run.sh --effort high   read   <second-opinion-brief.md>
~/.claude/skills/codex/scripts/codex-run.sh                 review <brief.md> --uncommitted
~/.claude/skills/codex/scripts/codex-run.sh                 write  <brief.md>
~/.claude/skills/codex/scripts/codex-run.sh                 resume <session-id> <brief.md> [<worktree>]
```

- Choose the model and effort only through `--model`/`--effort`. Don't pass `-m` or `model_reasoning_effort` yourself. Other extra args pass through to `codex exec`.
- Runs take from about 30 seconds to many minutes. For anything beyond a quick question, run the Bash call with `run_in_background: true` and keep working, since you'll be notified when it exits. Otherwise set a generous `timeout` (up to 600000).
- Run it outside the Bash sandbox if the sandbox blocks network access. Codex has to reach its model provider.
- Several independent `read` runs can go in parallel.

## 5. Verify, then integrate

- **Findings and opinions**: check each claim against the code before repeating it. Keep what holds, drop what doesn't, and say which you dropped and why. When Codex and you disagree, look into it rather than picking a side.
- **Write-mode results**: inspect the worktree the script printed:
  ```bash
  git -C <worktree> status --short && git -C <worktree> diff
  ```
  Review the diff as you would a PR, and run the relevant tests yourself. To bring the changes over, apply the diff to the user's tree (`git -C <worktree> diff | git apply`, plus copies of any untracked files it lists). Or, if the user prefers, commit in the worktree on a new branch and merge. Then remove the worktree with `git worktree remove --force <worktree>`, and tell the user if you're leaving it in place.
- **Follow-ups**: use `resume` with the session id so Codex keeps its context. For a write session, pass the worktree path so it keeps editing there.

## 6. Report

Give the user Codex's conclusion as you verified it, with your own agreement or disagreement, not a raw paste. Mention the run directory (`final.md`, `events.jsonl`) in case they want the full transcript.

## Failure modes

- Non-zero exit or empty final message: read `stderr.log` in the run directory. Auth and provider errors show up there. Report them; don't retry blindly.
- Not a git repo: `write` and `review` need one. For `read` outside a repo, add `--skip-git-repo-check`.
- Codex claims tests pass: re-run them yourself before saying so.
