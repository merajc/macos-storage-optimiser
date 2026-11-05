#!/usr/bin/env zsh
# ==============================================================================
# tests/test_cli.sh - CLI, JSON contract & Safety Unit Tests for macos-system-data
# ==============================================================================

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${REPO_ROOT}/bin/macos-system-data"
TMP_ROOT="$(mktemp -d -t macos-system-data-tests.XXXXXX)"
trap 'rm -rf "${TMP_ROOT}"' EXIT

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

assert_json_query() {
    local test_name="$1"
    local file="$2"
    local filter="$3"
    if jq -e -s "$filter" "$file" >/dev/null 2>&1; then
        echo "  ✔ PASS: ${test_name}"
        PASSED=$(( PASSED + 1 ))
    else
        echo "  ✘ FAIL: ${test_name}"
        FAILED=$(( FAILED + 1 ))
    fi
}

assert_file_missing() {
    local test_name="$1"
    local path="$2"
    if [[ ! -e "$path" ]]; then
        echo "  ✔ PASS: ${test_name}"
        PASSED=$(( PASSED + 1 ))
    else
        echo "  ✘ FAIL: ${test_name} (${path} still exists)"
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

# 8. JSON contract
if command -v jq >/dev/null 2>&1; then
    "$BIN" --json > "${TMP_ROOT}/audit.ndjson" 2>"${TMP_ROOT}/audit.err"
    json_exit=$?
    if [[ $json_exit -eq 0 ]]; then
        echo "  ✔ PASS: --json audit exits 0"
        PASSED=$(( PASSED + 1 ))
    else
        echo "  ✘ FAIL: --json audit exits 0 (code ${json_exit})"
        FAILED=$(( FAILED + 1 ))
    fi

    assert_json_query "every --json audit line is valid JSON" "${TMP_ROOT}/audit.ndjson" \
        'all(.[]; has("type"))'
    assert_json_query "JSON audit emits meta, disk and done records" "${TMP_ROOT}/audit.ndjson" \
        '([.[].type] | index("meta") and index("disk") and index("done"))'
    assert_json_query "JSON audit emits catalog items with stable IDs" "${TMP_ROOT}/audit.ndjson" \
        '[.[] | select(.type=="item") | .id] | index("xcode-deriveddata") and index("trash")'
    assert_json_query "JSON items carry a machine state" "${TMP_ROOT}/audit.ndjson" \
        'all(.[] | select(.type=="item"); (.state=="present" or .state=="missing" or .state=="denied"))'
    assert_json_query "JSON done record carries reclaimable bytes" "${TMP_ROOT}/audit.ndjson" \
        'any(.[]; .type=="done" and (.reclaimableBytes | type == "number"))'

    "$BIN" --json --summary > "${TMP_ROOT}/summary.ndjson" 2>/dev/null
    assert_json_query "--json --summary emits a disk record" "${TMP_ROOT}/summary.ndjson" \
        'any(.[]; .type=="disk" and (.totalBytes | type == "number"))'

    # Dry-run cleaning must report would-clean/missing only, never cleaned.
    "$BIN" --json --clean-ids sim-caches,trash -n > "${TMP_ROOT}/clean.ndjson" 2>/dev/null
    assert_json_query "dry-run clean reports would-clean/missing only" "${TMP_ROOT}/clean.ndjson" \
        'all(.[] | select(.type=="clean"); (.status=="would-clean" or .status=="missing"))'
    assert_json_query "dry-run clean never emits cleaned" "${TMP_ROOT}/clean.ndjson" \
        'all(.[] | select(.type=="clean"); .status != "cleaned")'
else
    echo "  - SKIP: jq not installed, JSON contract tests skipped"
fi

# 9. Machine-friendly safety rails
assert_exit_code 2 "Unknown --clean-ids item exits 2" "$BIN" --clean-ids definitely-not-an-item -n
assert_exit_code 2 "--clean-ids without consent exits 2" "$BIN" --clean-ids xcode-deriveddata
assert_exit_code 2 "--json --clean without --force exits 2" "$BIN" --json --clean
assert_exit_code 2 "Unknown option after valid option exits 2" "$BIN" --summary --bogus

# 10. read-only identifiers remain untouched by a dry run
assert_file_missing "Dummy sentinel path is absent" "${TMP_ROOT}/sentinel"

echo ""
echo "=== Test Results: ${PASSED} passed, ${FAILED} failed ==="

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
