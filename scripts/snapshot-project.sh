#!/usr/bin/env bash
# Snapshot a project's local skills into projects/<repo-name>/skills/.
#
#   scripts/snapshot-project.sh ~/some-repo
#
# Copies each real skill directory under <repo>/.agents/skills that is missing
# from, or differs from, akogu's global skills. The previous snapshot is replaced.
set -euo pipefail

AKOGU="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo="$(cd "${1:?usage: snapshot-project.sh <repo-path>}" && pwd)"
src="$repo/.agents/skills"
dest="$AKOGU/projects/$(basename "$repo")/skills"

[[ -d "$src" ]] || { echo "no $src" >&2; exit 1; }

rm -rf "$dest"
mkdir -p "$dest"
for dir in "$src"/*/; do
  dir="${dir%/}"
  name="$(basename "$dir")"
  [[ -L "$dir" ]] && continue
  global=("$AKOGU"/skills/*/"$name")
  if [[ -d "${global[0]}" ]] && diff -rq "$dir" "${global[0]}" >/dev/null; then
    continue
  fi
  cp -r "$dir" "$dest/"
  if [[ -d "${global[0]}" ]]; then
    echo "  variant  $name"
  else
    echo "  local    $name"
  fi
done
