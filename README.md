# akogu

**Agent kogu** (工具, *kōgu*: tools). One repository for the skills, configuration, and other tooling shared by coding agents such as Codex and Claude Code.

## Layout

| Path | Contents | Linked into |
| --- | --- | --- |
| `skills/` | Global skills for every agent | `~/.agents/skills`, `~/.claude/skills` |
| `codex/skills/` | Codex-only skills | `~/.agents/skills` |
| `claude/skills/` | Claude Code-only skills | `~/.claude/skills` |
| `projects/<repo>/skills/` | Snapshot copies of a project's local skills | Not linked |
| `sources.json` | Origin and status of every vendored skill | |
| `scripts/` | Linking, upstream comparison, snapshots | |

Codex reads user skills from `~/.agents/skills`; Claude Code reads `~/.claude/skills`. Each skill is linked individually, so skills installed by other tools (for example Claude Code's managed `~/.claude/skills/synced`) sit alongside them untouched.

Agent instructions live in `AGENTS.md` only. Claude Code reads `AGENTS.md` directly when no `CLAUDE.md` exists (v2.1.277+), so there is no `CLAUDE.md`.

## Setup

```sh
git clone <this repo> ~/akogu
~/akogu/scripts/link.sh                   # dry run
~/akogu/scripts/link.sh --apply           # link; back up anything displaced
~/akogu/scripts/link.sh --apply --prune   # also back up skills akogu does not manage
```

Nothing is deleted. Displaced directories, stale links, and `~/.agents/.skill-lock.json` move to `~/.akogu-backup/<timestamp>/`. The lock file is removed because `npx skills update` would otherwise write through the links into this repository; akogu replaces that installer for the skills it vendors.

Override the targets with `AGENTS_SKILLS_DIR`, `CLAUDE_SKILLS_DIR`, and `BACKUP_DIR`.

## Skill sources

`sources.json` records each skill's `status`:

| Status | Meaning |
| --- | --- |
| `pristine` | Identical to upstream at the recorded commit |
| `modified` | Local edits on top of upstream; see `note` |
| `diverged` | Differs from upstream; cause not recorded |
| `local` | No tracked upstream |

Most engineering skills come from [mattpocock/skills](https://github.com/mattpocock/skills). `code-review`, `diagnosing-bugs`, and `implement` are rewritten to be tracker- and stack-agnostic, and `testing` and `second-opinion` originated in project repositories.

### Updating from upstream

```sh
scripts/upstream-diff.sh             # summary for every skill with an upstream
scripts/upstream-diff.sh tdd         # full diff (- upstream, + akogu)
```

Upstream checkouts are cached in `~/.cache/akogu/upstream`.

## Project snapshots

```sh
scripts/snapshot-project.sh ~/some-repo
```

Copies the project's `.agents/skills/*` directories that are missing from, or differ from, `skills/`. A snapshot marked as a variant may be a deliberate project override or simply an older copy of a global skill.
