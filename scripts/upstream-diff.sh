#!/usr/bin/env bash
# Compare vendored skills with their upstream HEAD, using sources.json.
#
#   scripts/upstream-diff.sh               summary for every skill with an upstream
#   scripts/upstream-diff.sh tdd grilling  full diff for the named skills
#
# Diff direction is upstream -> akogu: `-` lines are upstream, `+` lines are ours.
set -euo pipefail

AKOGU="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="${AKOGU_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/akogu/upstream}"

entries() {
  jq -r 'to_entries[] | .key as $root | .value | to_entries[]
    | select(.value.upstream.repo != null)
    | [$root, .key, .value.status, .value.upstream.repo, .value.upstream.path] | @tsv' \
    "$AKOGU/sources.json"
}

repo_dir() {
  echo "$CACHE/$(echo "$1" | sed -E 's#^https://github.com/##; s#\.git$##; s#/#__#g')"
}

fetch() {
  local dir
  dir="$(repo_dir "$1")"
  if [[ -d "$dir/.git" ]]; then
    git -C "$dir" fetch -q --depth 1 origin HEAD && git -C "$dir" reset -q --hard FETCH_HEAD
  else
    mkdir -p "$CACHE"
    git clone -q --depth 1 "$1" "$dir"
  fi
}

while read -r repo; do fetch "$repo"; done < <(entries | cut -f4 | sort -u)

filter=("$@")
while IFS=$'\t' read -r root name status repo path; do
  if [[ ${#filter[@]} -gt 0 && ! " ${filter[*]} " =~ " $name " ]]; then
    continue
  fi
  dir="$(repo_dir "$repo")"
  ours="$AKOGU/$root/$name"
  theirs="$dir/$path"
  head="$(git -C "$dir" rev-parse --short HEAD)"
  if [[ ! -d "$theirs" ]]; then
    printf '%-36s %-9s removed upstream (%s)\n' "$name" "$status" "$head"
  elif diff -rq -x evals "$theirs" "$ours" >/dev/null; then
    printf '%-36s %-9s same as upstream %s\n' "$name" "$status" "$head"
  elif [[ ${#filter[@]} -gt 0 ]]; then
    diff -ru -x evals "$theirs" "$ours" | sed "s#$dir/#upstream/#; s#$AKOGU/#akogu/#" || true
  else
    printf '%-36s %-9s differs from upstream %s\n' "$name" "$status" "$head"
  fi
done < <(entries)
