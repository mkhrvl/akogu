#!/usr/bin/env bash
# Link akogu skills into each agent's user skill directory.
#
#   scripts/link.sh            dry run: print what would change
#   scripts/link.sh --apply    create links; move displaced entries to a backup
#   scripts/link.sh --apply --prune
#                              also move entries akogu does not manage to the backup
#
# skills/*        -> $AGENTS_SKILLS_DIR and $CLAUDE_SKILLS_DIR
# codex/skills/*  -> $AGENTS_SKILLS_DIR only (read by Codex)
# claude/skills/* -> $CLAUDE_SKILLS_DIR only
set -euo pipefail

AKOGU="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_SKILLS_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.akogu-backup/$(date +%Y%m%d-%H%M%S)}"
# Claude Code manages synced/ itself.
CLAUDE_RESERVED=(synced)

apply=false
prune=false
for arg in "$@"; do
  case "$arg" in
    --apply) apply=true ;;
    --prune) prune=true ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

run() {
  if $apply; then "$@"; fi
}

backup() {
  local path="$1" bucket="$2"
  echo "  backup  $path -> $BACKUP_DIR/$bucket/"
  run mkdir -p "$BACKUP_DIR/$bucket"
  run mv "$path" "$BACKUP_DIR/$bucket/"
}

link_into() {
  local src_root="$1" dest_root="$2" bucket="$3"
  run mkdir -p "$dest_root"
  for src in "$src_root"/*/; do
    src="${src%/}"
    local name dest
    name="$(basename "$src")"
    dest="$dest_root/$name"
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
      continue
    fi
    if [[ -L "$dest" ]]; then
      echo "  relink  $dest (was -> $(readlink "$dest"))"
      run rm "$dest"
    elif [[ -e "$dest" ]]; then
      backup "$dest" "$bucket"
    else
      echo "  link    $dest"
    fi
    run ln -s "$src" "$dest"
  done
}

is_managed() {
  local name="$1"; shift
  local root
  for root in "$@"; do
    [[ -d "$root/$name" ]] && return 0
  done
  return 1
}

report_unmanaged() {
  local dest_root="$1" bucket="$2"; shift 2
  local reserved=() managed_roots=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do managed_roots+=("$1"); shift; done
  [[ $# -gt 0 ]] && shift
  reserved=("$@")
  [[ -d "$dest_root" ]] || return 0
  local entry name r skip
  for entry in "$dest_root"/*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    name="$(basename "$entry")"
    skip=false
    for r in "${reserved[@]}"; do [[ "$name" == "$r" ]] && skip=true; done
    $skip && continue
    if [[ -L "$entry" && "$(readlink "$entry")" == "$AKOGU"/* ]]; then
      [[ -e "$entry" ]] && continue
    elif is_managed "$name" "${managed_roots[@]}"; then
      continue
    fi
    if $prune; then
      backup "$entry" "$bucket"
    else
      echo "  unmanaged  $entry"
    fi
  done
}

$apply || echo "Dry run. Re-run with --apply to make changes."

echo "$AGENTS_SKILLS_DIR"
link_into "$AKOGU/skills" "$AGENTS_SKILLS_DIR" agents
link_into "$AKOGU/codex/skills" "$AGENTS_SKILLS_DIR" agents
report_unmanaged "$AGENTS_SKILLS_DIR" agents "$AKOGU/skills" "$AKOGU/codex/skills" --
# Left in place, `npx skills update` would write through the links into akogu.
skill_lock="$(dirname "$AGENTS_SKILLS_DIR")/.skill-lock.json"
if [[ -e "$skill_lock" ]]; then
  if $prune; then backup "$skill_lock" agents; else echo "  unmanaged  $skill_lock"; fi
fi

echo "$CLAUDE_SKILLS_DIR"
link_into "$AKOGU/skills" "$CLAUDE_SKILLS_DIR" claude
link_into "$AKOGU/claude/skills" "$CLAUDE_SKILLS_DIR" claude
report_unmanaged "$CLAUDE_SKILLS_DIR" claude "$AKOGU/skills" "$AKOGU/claude/skills" -- "${CLAUDE_RESERVED[@]}"
