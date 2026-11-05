#!/usr/bin/env zsh
# ==============================================================================
# tests/test_cli.sh - CLI & Safety Unit Tests for macos-system-data
# ==============================================================================

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${REPO_ROOT}/bin/macos-system-data"

PASSED=0
FAILED=0

assert_success() {
    local test_name="$1"
    shift
    if "$@"; then
        echo "  ✔ PASS: ${test_name}"
        PASSED=$(( PASSED + 1 ))
    else
        echo "  ✘ FAIL: ${test_name}"
        FAILED=$(( FAILED + 1 ))
    fi
}

assert_exit_code() {
    local expected_code="$1"
    local test_name="$2"
    shift 2
    "$@" >/dev/null 2>&1
    local code=$?
    if [[ $code -eq $expected_code ]]; then
        echo "  ✔ PASS: ${test_name} (code ${code})"
        PASSED=$(( PASSED + 1 ))
    else
        echo "  ✘ FAIL: ${test_name} (expected ${expected_code}, got ${code})"
        FAILED=$(( FAILED + 1 ))
    fi
}

echo "=== Running macos-system-data Test Suite ==="
echo ""

# 1. Syntax check
assert_success "zsh -n syntax validation" zsh -n "$BIN"

# 2. Version flag
assert_success "--version displays version" "$BIN" --version

# 3. Help flag
assert_success "--help displays usage instructions" "$BIN" --help

# 4. Summary mode
assert_success "--summary exits 0 and prints capacity" "$BIN" --summary

# 5. Invalid flag returns code 2
assert_exit_code 2 "Invalid flag exits with code 2" "$BIN" --invalid-flag-test

# 6. Dry run clean tier 1 exits 0
assert_success "--dry-run --clean-tier1 runs safely" "$BIN" --dry-run --clean-tier1

# 7. No color mode
assert_success "--no-color flag runs cleanly" "$BIN" --no-color --summary

echo ""
echo "=== Test Results: ${PASSED} passed, ${FAILED} failed ==="

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
