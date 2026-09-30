#!/usr/bin/env bash
# Run Codex non-interactively as a sub-agent and collect its result.
#
# Usage:
#   codex-run.sh read   <brief-file> [codex args...]   read-only investigation / opinion
#   codex-run.sh write  <brief-file> [codex args...]   edits in a new managed git worktree
#   codex-run.sh review <brief-file> [codex args...]   built-in reviewer; pass --uncommitted | --base <b> | --commit <sha>
#   codex-run.sh resume <session-id> <brief-file> [dir] follow-up in an existing session (dir: worktree to run in)
#
# Options (before the mode):
#   --model sol|luna   sol = gpt-6.1-sol (default), luna = gpt-6-luna for trivial tasks
#   --effort <level>   sol: medium|high (default high for review, else medium); luna: high|xhigh (default high)
#
# Run from the repository root (except resume).
# Prints the run directory, session id, worktree path (write mode) and Codex's final message.
set -euo pipefail

usage() { sed -n '4,14p' "$0" >&2; exit 2; }

tier=sol
effort=""
while [[ ${1:-} == --* ]]; do
  case $1 in
    --model)  tier=${2:-}; shift 2 || usage ;;
    --effort) effort=${2:-}; shift 2 || usage ;;
    *) usage ;;
  esac
done
[[ $# -ge 2 ]] || usage
mode=$1; shift

case $tier in
  sol)
    model=gpt-6.1-sol; allowed="medium high"
    [[ $mode == review ]] && effort=${effort:-high} || effort=${effort:-medium} ;;
  luna) model=gpt-6-luna; effort=${effort:-high}; allowed="high xhigh" ;;
  *) echo "model must be sol or luna, got: $tier" >&2; exit 2 ;;
esac
[[ " $allowed " == *" $effort "* ]] || { echo "effort for $tier must be one of: $allowed (got: $effort)" >&2; exit 2; }

session=""
if [[ $mode == resume ]]; then
  session=$1; shift
fi
brief=$1; shift
[[ -f $brief ]] || { echo "brief file not found: $brief" >&2; exit 2; }

run_dir=$(mktemp -d "${TMPDIR:-/tmp}/codex-run.XXXXXX")
common=(--json -o "$run_dir/final.md" -m "$model" -c "model_reasoning_effort=\"$effort\"")

case $mode in
  read)   cmd=(codex exec --sandbox read-only "${common[@]}" "$@" -) ;;
  write)  cmd=(codex exec --worktree --sandbox workspace-write "${common[@]}" "$@" -) ;;
  review) cmd=(codex exec review "${common[@]}" "$@" -) ;;
  resume)
    [[ $# -ge 1 ]] && cd "$1"
    cmd=(codex exec resume "${common[@]}" -c 'sandbox_mode="workspace-write"' "$session" -) ;;
  *) usage ;;
esac

worktrees() { git worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | sort; }
before=$(worktrees)

status=0
"${cmd[@]}" <"$brief" >"$run_dir/events.jsonl" 2>"$run_dir/stderr.log" || status=$?

thread=$(jq -r 'select(.type=="thread.started") | .thread_id' "$run_dir/events.jsonl" 2>/dev/null | head -1)
new_worktree=""
[[ $mode == write ]] && new_worktree=$(comm -13 <(echo "$before") <(worktrees) | head -1)

echo "exit:      $status"
echo "run_dir:   $run_dir"
echo "model:     $model ($effort)"
echo "session:   ${thread:-${session:-unknown}}"
[[ -n $new_worktree ]] && echo "worktree:  $new_worktree"
tokens=$(jq -r 'select(.type=="turn.completed") | .usage | "\(.input_tokens) in / \(.output_tokens) out"' "$run_dir/events.jsonl" 2>/dev/null | tail -1)
[[ -n $tokens ]] && echo "tokens:    $tokens"
echo "----- final message -----"
if [[ -s $run_dir/final.md ]]; then
  cat "$run_dir/final.md"; echo
else
  echo "(no final message; see $run_dir/stderr.log)"
  tail -20 "$run_dir/stderr.log"
fi
exit "$status"
