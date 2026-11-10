#!/usr/bin/env bash
# Runs every nbkit test: lint (shellcheck, pyflakes), Python unit tests, the end-to-end engine tests,
# the JSF checks and the graphical interface (on a virtual screen). Missing tools are offered for install first (with a terminal to ask); a part whose tool
# is still missing is skipped with a warning. Also: bash nbkit.sh test
set -uo pipefail
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
python_tests() { "$PY" -m unittest discover -s tests/python -t tests/python; }
jsf_tests() {
  has_jdk || { t test.skipped_tool "JDK 17+"; echo; return 3; }
  bash tests/jsf.sh
}

install_tools
part "shellcheck" lint_shell
part "pyflakes" lint_python
part "$(t test.part_python)" python_tests
part "$(t test.part_engine)" bash tests/engine.sh
part "$(t test.part_jsf)" jsf_tests
part "$(t test.part_gui)" bash tests/gui.sh

if [ ${#skipped[@]} -gt 0 ]; then echo "${Y}$(t test.skipped)${N} ${skipped[*]}"; fi
if [ ${#failed[@]} -gt 0 ]; then echo "${R}${B}$(t test.failed)${N} ${failed[*]}"; exit 1; fi
echo "${G}${B}$(t test.all_passed)${N}"
