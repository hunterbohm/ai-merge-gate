#!/usr/bin/env bash
# Claude Code Stop hook — won't let the agent declare "done" until the gate is green.
#
# Wired in .claude/settings.json under hooks.Stop. On every stop attempt it runs
# the gate (fast mode: no headless render). If the gate fails, it exits 2 and
# prints the reason to stderr — Claude Code feeds that back to the model and makes
# it keep working instead of stopping on broken code.
#
# Loop guard: if Claude is already inside a Stop-hook-driven continuation
# (stop_hook_active), we don't block again — the human is in control.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# read the Stop event payload from stdin (best-effort; works with or without jq)
payload="$(cat 2>/dev/null || true)"
if command -v jq >/dev/null 2>&1; then
  active="$(printf '%s' "$payload" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"
else
  case "$payload" in *'"stop_hook_active":true'*|*'"stop_hook_active": true'*) active=true ;; *) active=false ;; esac
fi
[ "$active" = "true" ] && exit 0   # already continuing from a prior block — don't loop

if bash ./gate.sh --quiet --no-render >/dev/null 2>/tmp/ai-merge-gate-stop.err; then
  exit 0
fi
echo "ai-merge-gate is red — do not stop yet. $(tail -n 3 /tmp/ai-merge-gate-stop.err | tr '\n' ' ')" >&2
exit 2
