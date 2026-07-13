#!/usr/bin/env bash
# scan-error-leaks.sh — flag code that leaks raw errors / stack traces to
# clients or logs. This is smell #1: an AI agent "handles" an error by sending
# err.stack straight back, and now your internals are in someone's network tab.
#
# Heuristic on purpose. It finds candidates; a human confirms. Tune the allowlist
# (ERROR_LEAK_ALLOW) for test files and intentional debug paths.
#
# Args: $1 = src dir   $2 = quiet (1/0)
set -uo pipefail
SRC="${1:-.}"
QUIET="${2:-0}"
ALLOW="${ERROR_LEAK_ALLOW:-}"

# Search for a pattern, excluding node_modules. Works with ripgrep or grep.
if command -v rg >/dev/null 2>&1; then
  search() { rg -n --no-heading -e "$1" --glob '!**/node_modules/**' "$SRC" 2>/dev/null; }
else
  search() { grep -rnE --exclude-dir=node_modules -e "$1" "$SRC" 2>/dev/null; }
fi

# Patterns that usually mean "an error object / stack is going somewhere public".
PATTERNS=(
  'res\.(send|json)\([^)]*\b(err|error|e)\b[^)]*\.(stack|message)'
  'res\.status\([0-9]+\)\.(send|json)\([^)]*\b(err|error|e)\b[^)]*\.(stack|message)'
  '\.(send|json)\(\s*(err|error|e)\s*\)'
  '(console\.(log|error|warn)|logger\.(error|warn|info))\([^)]*\.stack\b'
  'JSON\.stringify\(\s*(err|error|e)\b'
)

tmp="$(mktemp)"
for p in "${PATTERNS[@]}"; do search "$p" >>"$tmp" || true; done

# drop allowlisted paths
if [ -n "$ALLOW" ]; then
  IFS=',' read -ra A <<< "$ALLOW"
  for a in "${A[@]}"; do [ -n "$a" ] && { grep -v -- "$a" "$tmp" > "$tmp.f" 2>/dev/null || true; mv "$tmp.f" "$tmp" 2>/dev/null || true; }; done
fi
sort -u "$tmp" -o "$tmp"
hits=$(grep -c . "$tmp" 2>/dev/null); hits=${hits:-0}

if [ "$hits" -gt 0 ]; then
  [ "$QUIET" -eq 1 ] || { echo "  error-leak candidates ($hits):"; sed 's/^/    /' "$tmp" | head -20; }
  echo "scan:error-leaks found $hits candidate(s) leaking errors/stacks — review or allowlist." >&2
  rm -f "$tmp"; exit 1
fi
[ "$QUIET" -eq 1 ] || echo "  error-leaks: clean"
rm -f "$tmp"; exit 0
