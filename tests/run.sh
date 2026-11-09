#!/usr/bin/env bash
# Runs every nbkit test: lint (shellcheck, pyflakes), Python unit tests, the end-to-end engine tests and
# the JSF checks. A part whose tool is missing is skipped with a warning. Also: bash nbkit.sh test
set -uo pipefail
TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$TESTS")"
cd "$ROOT" || exit 1
if [ -t 1 ]; then B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'; else B=; G=; Y=; R=; N=; fi
PY="${NBKIT_PY:-python3}"
failed=(); skipped=()

part() {
  local name="$1" rc; shift
  echo "${B}== $name${N}"
  "$@"; rc=$?
  case $rc in 0) ;; 3) skipped+=("$name") ;; *) failed+=("$name") ;; esac
  echo
}
lint_shell() {
  command -v shellcheck >/dev/null 2>&1 || { echo "  skipped: shellcheck not found"; return 3; }
  shellcheck -S warning -e SC2034,SC1090,SC2154,SC2010 nbkit.sh lib/*.sh src/build.sh tests/*.sh && echo "  ok    no warnings"
}
lint_python() {
  "$PY" -m pyflakes --version >/dev/null 2>&1 || { echo "  skipped: pyflakes not found (pip install pyflakes)"; return 3; }
  "$PY" -m pyflakes lib/*.py lib/themes/*.py tests/python/*.py && echo "  ok    no warnings"
}
python_tests() { "$PY" -m unittest discover -s tests/python -t tests/python; }

part "shellcheck" lint_shell
part "pyflakes" lint_python
part "Python unit tests" python_tests
part "Engine (fake NetBeans)" bash tests/engine.sh
part "JSF checks" bash tests/jsf.sh

if [ ${#skipped[@]} -gt 0 ]; then echo "${Y}skipped:${N} ${skipped[*]}"; fi
if [ ${#failed[@]} -gt 0 ]; then echo "${R}${B}failed:${N} ${failed[*]}"; exit 1; fi
echo "${G}${B}all tests passed${N}"
