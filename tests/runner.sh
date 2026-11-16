#!/usr/bin/env bash
# Tests "bash tests/run.sh <file>": only the tests of that file run (to save time while working on something; the whole
# suite runs once at the end), and a file that is not a test fails, saying so.
set -uo pipefail
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() { (cd "$TESTS" && bash run.sh "$@" </dev/null 2>&1); }

echo "Running the tests of one file"
out="$(run python/test_lang.py)"; rc=$?
check "a Python test file, given relative to where you are: exits with 0" test "$rc" = 0
alone="$(cd "$TESTS/python" && python3 -m unittest test_lang 2>&1 | grep -o '^Ran [0-9]* tests')"
contains "runs only that file's tests" "$out" "$alone"
lacks "and no other part (lint, engine)" "$out" "== shellcheck"
lacks "nor the engine" "$out" "Engine (fake NetBeans)"
contains "and says the result" "$out" "all tests passed"

out="$(run "$NBKIT_DIR/src/nbkit-jsf/test/RunNetBeansMarks.java")"; rc=$?
if [ "$rc" = 0 ] && grep -q "skipped" <<<"$out"; then
  pass "a Run*.java of the JSF: skipped, no JDK here"
else
  check "a Run*.java of the JSF runs the JSF tests, which compile and check it: exits with 0" test "$rc" = 0
  contains "only the JSF tests" "$out" "== tests/jsf.sh"
  lacks "nothing else" "$out" "== shellcheck"
fi

out="$(run "$NBKIT_DIR/nbkit.sh")"; rc=$?
check "a file that is not a test fails" test "$rc" = 2
contains "saying so" "$out" "Not a test file: $NBKIT_DIR/nbkit.sh"
out="$(run python/test_nothing.py)"; rc=$?
check "a file that does not exist fails" test "$rc" = 2
contains "saying so" "$out" "No such file: $TESTS/python/test_nothing.py"
finish
