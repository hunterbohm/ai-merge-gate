#!/usr/bin/env bash
# scan-request-id.sh — smell #2: server handlers with no request/correlation id.
# When something breaks in prod at 2am, "an error happened somewhere" is useless.
# A request id on every server log line is the difference between a 5-minute fix
# and an hour of guessing. AI scaffolds rarely add it; this nudges you to.
#
# Heuristic: if there ARE server handlers but NO sign of a request/correlation id
# anywhere in the tree, fail. If your project is pure frontend/library, set
# REQUIRE_REQUEST_ID=0 in gate.config.sh and this never runs.
#
# Args: $1 = src dir   $2 = quiet (1/0)
set -uo pipefail
SRC="${1:-.}"
QUIET="${2:-0}"

# Count files matching a pattern, excluding node_modules. Works with ripgrep or grep.
if command -v rg >/dev/null 2>&1; then
  countfiles() { rg -l "$@" --glob '!**/node_modules/**' "$SRC" 2>/dev/null | wc -l | tr -d ' '; }
else
  countfiles() { grep -rlE --exclude-dir=node_modules "$@" "$SRC" 2>/dev/null | wc -l | tr -d ' '; }
fi

# Does this tree even have server-side request handlers? (case-sensitive: HTTP verbs)
SERVER_SIGNS='(export (async )?function (GET|POST|PUT|PATCH|DELETE)|app\.(get|post|put|patch|delete)\(|router\.(get|post|put|patch|delete)\(|@(Get|Post|Put|Patch|Delete)\(|def \w+\(request)'
servers=$(countfiles -e "$SERVER_SIGNS"); servers=${servers:-0}

if [ "$servers" -eq 0 ]; then
  [ "$QUIET" -eq 1 ] || echo "  request-id: no server handlers detected — skipped"
  exit 0
fi

# Is there any request/correlation id in play? (case-insensitive)
REQID_SIGNS='(x-request-id|x-correlation-id|request[_-]?id|correlation[_-]?id|crypto\.randomUUID\(\))'
reqids=$(countfiles -i -e "$REQID_SIGNS"); reqids=${reqids:-0}

if [ "$reqids" -eq 0 ]; then
  echo "scan:request-id found server handlers but no request/correlation id anywhere — add one to your logger/middleware (or set REQUIRE_REQUEST_ID=0)." >&2
  exit 1
fi
[ "$QUIET" -eq 1 ] || echo "  request-id: present ($reqids file(s))"
exit 0
