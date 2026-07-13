# ai-merge-gate config — copy this to gate.config.sh and set YOUR commands.
#   cp gate.config.example.sh gate.config.sh
#
# Anything left empty is skipped (with a notice), so you can adopt the gate one
# stage at a time. These defaults assume an npm project; change them.

# --- the green-bar pipeline (run fail-fast, in this order) ---
TYPECHECK_CMD="npm run typecheck"   # e.g. tsc --noEmit | pnpm typecheck | mypy .
LINT_CMD="npm run lint"             # e.g. eslint . | ruff check | golangci-lint run
TEST_CMD="npm test"                 # e.g. vitest run | pytest -q | go test ./...
BUILD_CMD="npm run build"           # e.g. next build | vite build | go build ./...

# --- where your source lives (the security scans read this tree) ---
SRC_DIR="src"

# --- security smell scans ---
# Comma-separated substrings to ignore in the error-leak scan (e.g. test files).
ERROR_LEAK_ALLOW=".test.,.spec.,/tests/,/__tests__/"
# Set to 0 if your project has no server handlers (pure frontend/library).
REQUIRE_REQUEST_ID=1

# --- headless render evidence (optional; leave RENDER_URL empty to skip) ---
# If set, gate.sh boots your app and screenshots these routes to ./evidence/.
RENDER_START_CMD=""                 # e.g. "npm run preview"  (no trailing &; gate.sh backgrounds it)
RENDER_URL=""                       # e.g. "http://localhost:4173"
RENDER_ROUTES="/"                   # comma-separated: "/,/login,/dashboard"
