#!/usr/bin/env bash
# Tests the graphical interface (lib/gui) on a virtual screen (xvfb-run): the window driven like a person would,
# against the fake NetBeans of tests/netbeans. The interface model is also in tests/python/test_gui_model.py.
set -uo pipefail
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck disable=SC1091
source "$NBKIT_DIR/lib/gui.sh"
GUI_PY="$(gui_python)" || { echo "  skipped: PyGObject, GTK 4 or VTE not found"; exit 3; }
command -v xvfb-run >/dev/null 2>&1 || { echo "  skipped: xvfb-run not found"; exit 3; }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# a NetBeans launcher that does nothing, for the scenario where nbkit offers to open NetBeans
mkdir -p "$WORK/bin" && printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/netbeans" && chmod +x "$WORK/bin/netbeans"
rc=0
for scenario in actions closing dark decline; do
  new_home "$WORK/home"
  path="$PATH"; [ "$scenario" = decline ] && path="$WORK/bin:$PATH"
  PATH="$path" HOME="$WORK/home" GSETTINGS_BACKEND=memory PYTHONPATH="$TESTS/python" PYTHONDONTWRITEBYTECODE=1 GDK_BACKEND=x11 NO_AT_BRIDGE=1 \
    xvfb-run -a "$GUI_PY" "$TESTS/python/gui_window.py" "$scenario" 2>&1 </dev/null \
    | grep -v -e 'libEGL warning' -e 'Unable to acquire session bus' -e '^$'
  [ "${PIPESTATUS[0]}" = 0 ] || rc=1
done
exit $rc
