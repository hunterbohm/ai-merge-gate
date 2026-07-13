#!/usr/bin/env bash
# Watch the gate catch real smells, then pass once they're fixed.
#   npm run demo   (or: bash example/run-demo.sh)
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

line() { printf '\n\033[2m%s\033[0m\n' "────────────────────────────────────────────"; }

line; echo "1) Scanning example/bad  (AI 'error handling' — expect RED)"
echo "   error-leaks:"; bash checks/scan-error-leaks.sh example/bad 0 || true
echo "   request-id: ";  bash checks/scan-request-id.sh  example/bad 0 || true

line; echo "2) Scanning example/good  (fixed — expect GREEN)"
echo "   error-leaks:"; bash checks/scan-error-leaks.sh example/good 0
echo "   request-id: ";  bash checks/scan-request-id.sh  example/good 0

line; echo "That's the gate. Point SRC_DIR at your real code in gate.config.sh,"
echo "wire your typecheck/lint/test/build commands, and run ./gate.sh"
