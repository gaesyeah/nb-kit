#!/usr/bin/env bash
# Runs every nbkit test: lint (shellcheck, pyflakes), Python unit tests, the end-to-end engine tests,
# the JSF checks and the graphical interface (on a virtual screen). Missing tools are offered for install first (with a terminal to ask); a part whose tool
# is still missing is skipped with a warning. Also: bash nbkit.sh test
#   bash tests/run.sh <file>: only the tests of that file, while working on something (the whole suite runs once at the
#   end): a test of tests/python, tests/engine.sh, jsf.sh, gui.sh, runner.sh, or a Run*.java of src/nbkit-jsf/test (they
#   run inside jsf.sh, a few seconds). Only here, not in the menu nor the interface: in v5 the tests are written again in
#   Java (JaCoCo), and that is when to decide.
set -uo pipefail
# the file, as given from where you are (before the cd below)
FILE=""; [ $# -gt 0 ] && FILE="$(realpath -m -- "$1")"
TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NBKIT_DIR="$(dirname "$TESTS")"
cd "$NBKIT_DIR" || exit 1
# shellcheck disable=SC1091
source "$NBKIT_DIR/lib/terminal.sh"
# shellcheck disable=SC1091
source "$NBKIT_DIR/lib/packages.sh"
# shellcheck disable=SC1091
source "$NBKIT_DIR/lib/gui.sh"
PY="${NBKIT_PY:-python3}"
export PYTHONDONTWRITEBYTECODE=1
# run from the interface ("Run the tests"): the nbkit runs inside the tests must not send it their steps nor wait for its answers
unset NBKIT_UI_EVENTS NBKIT_TTY NBKIT_INTERACTIVE
failed=(); skipped=()

# ---------- tools ----------
has_shellcheck() { command -v shellcheck >/dev/null 2>&1; }
# pyflakes of the Python nbkit uses, or of the system python3 (the package installs it there)
pyflakes_cmd() {
  local p
  for p in "$PY" python3; do
    if "$p" -m pyflakes --version >/dev/null 2>&1; then echo "$p"; return 0; fi
  done
  return 1
}
has_jdk() { jdk_ok; }
# offers to install, in one question, every tool that is missing
install_tools() {
  local m names=() specs=() p pkgs=()
  has_shellcheck || { names+=(shellcheck); specs+=("apt:shellcheck dnf:ShellCheck pacman:shellcheck zypper:ShellCheck"); }
  pyflakes_cmd >/dev/null || { names+=(pyflakes); specs+=("apt:python3-pyflakes dnf:python3-pyflakes pacman:python-pyflakes zypper:python3-pyflakes"); }
  has_jdk || { names+=(JDK); specs+=("$JDK_SPEC"); }
  if ! gui_python >/dev/null; then
    names+=("GTK 4/VTE")
    while IFS= read -r p; do specs+=("$p"); done < <(gui_package_specs)
  fi
  command -v xvfb-run >/dev/null 2>&1 || { names+=(xvfb-run); specs+=("apt:xvfb dnf:xorg-x11-server-Xvfb pacman:xorg-server-xvfb zypper:xvfb-run"); }
  [ ${#names[@]} -gt 0 ] || return 0
  t test.missing_tools "$(IFS=,; echo "${names[*]}" | sed 's/,/, /g')"; echo
  m="$(pkg_manager)" || return 0
  for p in "${specs[@]}"; do
    # shellcheck disable=SC2086
    pkgs+=("$(pkg_for "$m" $p)")
  done
  pkg_run "$(IFS=,; echo "${names[*]}" | sed 's/,/, /g')" "${pkgs[@]}" || true
  echo
}

# ---------- parts ----------
part() {
  local name="$1" rc; shift
  echo "${B}== $name${N}"
  "$@"; rc=$?
  case $rc in 0) ;; 3) skipped+=("$name") ;; *) failed+=("$name") ;; esac
  echo
}
lint_shell() {
  has_shellcheck || { t test.skipped_tool shellcheck; echo; return 3; }
  shellcheck -S warning -e SC2034,SC1090,SC2154,SC2010 nbkit.sh lib/*.sh src/build.sh tests/*.sh && echo "  ${G}ok${N}    $(t test.no_warnings)"
}
lint_python() {
  local p
  p="$(pyflakes_cmd)" || { t test.skipped_tool pyflakes; echo; return 3; }
  "$p" -m pyflakes lib/*.py lib/themes/*.py lib/tools/*.py lib/gui/*.py tests/python/*.py && echo "  ${G}ok${N}    $(t test.no_warnings)"
}
# unittest's own "OK" / "FAILED" lines, in green and red like the rest; $1: only that file (test_x.py)
python_tests() {
  "$PY" -m unittest discover -s tests/python -t tests/python -p "${1:-test*.py}" 2>&1 \
    | sed -e "s/^OK/${G}OK${N}/" -e "s/^\(FAILED\|FAIL:\|ERROR:\)/${R}\1${N}/"
  return "${PIPESTATUS[0]}"
}
jsf_tests() {
  has_jdk || { t test.skipped_tool "JDK 17+"; echo; return 3; }
  bash "${NBKIT_TEST_JSF:-tests/jsf.sh}"
}

if [ -n "$FILE" ]; then
  [ -e "$FILE" ] || { echo "${R}$(t test.no_file "$FILE")${N}"; exit 2; }
  case "$FILE" in
    "$TESTS"/python/test_*.py) part "${FILE#"$NBKIT_DIR"/}" python_tests "$(basename "$FILE")" ;;
    "$TESTS"/engine.sh|"$TESTS"/gui.sh|"$TESTS"/runner.sh) part "${FILE#"$NBKIT_DIR"/}" bash "$FILE" ;;
    "$TESTS"/jsf.sh|"$NBKIT_DIR"/src/nbkit-jsf/test/Run*.java) part "tests/jsf.sh" jsf_tests ;;
    *) echo "${R}$(t test.not_a_test "$FILE")${N}"; exit 2 ;;
  esac
else
install_tools
part "shellcheck" lint_shell
part "pyflakes" lint_python
part "$(t test.part_python)" python_tests
part "$(t test.part_engine)" bash tests/engine.sh
part "$(t test.part_jsf)" jsf_tests
part "$(t test.part_gui)" bash tests/gui.sh
part "$(t test.part_runner)" bash tests/runner.sh
fi

if [ ${#skipped[@]} -gt 0 ]; then echo "${Y}$(t test.skipped)${N} ${skipped[*]}"; fi
if [ ${#failed[@]} -gt 0 ]; then echo "${R}${B}$(t test.failed)${N} ${failed[*]}"; exit 1; fi
echo "${G}${B}$(t test.all_passed)${N}"
