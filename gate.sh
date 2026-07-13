#!/usr/bin/env bash
# ai-merge-gate — the gate between "the agent said it's done" and "this is live."
#
# Runs your real build pipeline fail-fast (typecheck -> lint -> test -> build),
# then a few security smell scans that bit me on real production code, then
# (optionally) screenshots the running app headlessly as merge evidence.
#
# Nothing here is magic. It just refuses to let AI-written code merge on vibes.
#
# Usage:
#   ./gate.sh                 # full gate (pipeline + scans + render evidence)
#   ./gate.sh --quiet         # less output (used by the Claude Code Stop hook)
#   ./gate.sh --no-render     # skip the headless screenshot step
#   ./gate.sh --scans-only    # only run the security smell scans
#   ./gate.sh --help
#
# Config: copy gate.config.example.sh -> gate.config.sh and set YOUR commands.

set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

QUIET=0; NO_RENDER=0; SCANS_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    --no-render) NO_RENDER=1 ;;
    --scans-only) SCANS_ONLY=1 ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 64 ;;
  esac
done

# ---- colors (off when not a tty) ----
if [ -t 1 ] && [ "$QUIET" -eq 0 ]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[34m'; DIM=$'\e[2m'; X=$'\e[0m'
else R=""; G=""; Y=""; B=""; DIM=""; X=""; fi

say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
head() { [ "$QUIET" -eq 1 ] || printf '\n%s==>%s %s\n' "$B" "$X" "$*"; }

# ---- load config ----
TYPECHECK_CMD=""; LINT_CMD=""; TEST_CMD=""; BUILD_CMD=""
SRC_DIR="."; RENDER_URL=""; RENDER_ROUTES="/"; RENDER_START_CMD=""
ERROR_LEAK_ALLOW=""; REQUIRE_REQUEST_ID=1
if [ -f gate.config.sh ]; then
  # shellcheck disable=SC1091
  source gate.config.sh
else
  say "${Y}no gate.config.sh — using gate.config.example.sh defaults${X}"
  say "${DIM}  cp gate.config.example.sh gate.config.sh   # then set your commands${X}"
  # shellcheck disable=SC1091
  source gate.config.example.sh
fi

# A gate that goes green because it scanned nothing is the one failure mode this
# must never have. If SRC_DIR is set but missing, fail loud.
if [ -n "$SRC_DIR" ] && [ ! -d "$SRC_DIR" ]; then
  say "${R}gate: SRC_DIR '$SRC_DIR' does not exist — refusing to pass on an empty scan.${X}"
  echo "ai-merge-gate misconfigured: SRC_DIR '$SRC_DIR' not found." >&2
  exit 1
fi

FAILED=()
PASSED=()
SKIPPED=()

run_stage() {
  local name="$1" cmd="$2"
  if [ -z "$cmd" ]; then SKIPPED+=("$name"); say "${DIM}-- skip ${name} (no command set)${X}"; return 0; fi
  head "$name  ${DIM}\$ ${cmd}${X}"
  if [ "$QUIET" -eq 1 ]; then
    if eval "$cmd" >/tmp/gate-$name.log 2>&1; then PASSED+=("$name"); else FAILED+=("$name"); cat "/tmp/gate-$name.log" >&2; fi
  else
    if eval "$cmd"; then PASSED+=("$name"); say "${G}OK ${name}${X}"; else FAILED+=("$name"); say "${R}FAIL ${name}${X}"; fi
  fi
  # fail-fast: stop at the first red so you fix one thing at a time
  if [ "${#FAILED[@]}" -gt 0 ]; then return 1; fi
}

# ---- 1. the green-bar pipeline (fail-fast) ----
if [ "$SCANS_ONLY" -eq 0 ]; then
  run_stage typecheck "$TYPECHECK_CMD" || true
  [ "${#FAILED[@]}" -eq 0 ] && { run_stage lint  "$LINT_CMD"  || true; }
  [ "${#FAILED[@]}" -eq 0 ] && { run_stage test  "$TEST_CMD"  || true; }
  [ "${#FAILED[@]}" -eq 0 ] && { run_stage build "$BUILD_CMD" || true; }
fi

# ---- 2. security smell scans (only if pipeline is green) ----
if [ "${#FAILED[@]}" -eq 0 ]; then
  head "security smells  ${DIM}(heuristic — flags candidates for human eyes)${X}"
  if ERROR_LEAK_ALLOW="$ERROR_LEAK_ALLOW" bash checks/scan-error-leaks.sh "$SRC_DIR" "$QUIET"; then
    PASSED+=("scan:error-leaks"); else FAILED+=("scan:error-leaks"); fi
  if [ "$REQUIRE_REQUEST_ID" -eq 1 ]; then
    if bash checks/scan-request-id.sh "$SRC_DIR" "$QUIET"; then
      PASSED+=("scan:request-id"); else FAILED+=("scan:request-id"); fi
  fi
fi

# ---- 3. headless render evidence (only if everything above is green) ----
if [ "${#FAILED[@]}" -eq 0 ] && [ "$SCANS_ONLY" -eq 0 ] && [ "$NO_RENDER" -eq 0 ] && [ -n "$RENDER_URL" ]; then
  head "render evidence  ${DIM}(headless — no browser window opens)${X}"
  if RENDER_URL="$RENDER_URL" RENDER_ROUTES="$RENDER_ROUTES" RENDER_START_CMD="$RENDER_START_CMD" \
     node verify-render.mjs; then PASSED+=("render"); else FAILED+=("render"); fi
fi

# ---- summary ----
say ""
say "${DIM}passed:${X} ${PASSED[*]:-none}    ${DIM}skipped:${X} ${SKIPPED[*]:-none}"
if [ "${#FAILED[@]}" -gt 0 ]; then
  say "${R}GATE FAILED${X} -> ${FAILED[*]}"
  # message the Claude Code Stop hook reads off stderr:
  echo "ai-merge-gate failed: ${FAILED[*]}. Fix these before this merges." >&2
  exit 1
fi
say "${G}GATE PASSED${X} — safe to merge."
exit 0
