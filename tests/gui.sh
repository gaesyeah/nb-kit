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
# a "netbeans" on the PATH that must never run: the tests may not open a NetBeans of the machine
mkdir -p "$WORK/bin" && printf '#!/bin/sh\ntouch "%s/launched"\n' "$WORK" > "$WORK/bin/netbeans" && chmod +x "$WORK/bin/netbeans"
# green ok and red FAIL, like the other tests, when the output is a terminal (the window runs behind a pipe)
color=0; [ -t 1 ] && color=1
rc=0
for scenario in actions closing dark decline laptop small; do
  # full HD; a laptop screen (1366x768) and a short one (1366x560) for the layout
  case "$scenario" in laptop) screen=1366x768 ;; small) screen=1366x560 ;; *) screen=1920x1080 ;; esac
  new_home "$WORK/home"
  # decline: a NetBeans with a launcher that does nothing, for the scenario where nbkit offers to open it
  if [ "$scenario" = decline ]; then
    rm -rf "$WORK/nb"; cp -r "$TESTS/netbeans" "$WORK/nb"; mkdir -p "$WORK/nb/bin"
    printf '#!/bin/sh\nexit 0\n' > "$WORK/nb/bin/netbeans"; chmod +x "$WORK/nb/bin/netbeans"
    sed -i "s|Installation *=.*|Installation            = $WORK/nb/platform|" "$WORK/home/.netbeans/31/var/log/messages.log"
  fi
  # ">16bit keyvals": GTK on the virtual screen with newer keyboard layouts (Mint 22, KDE), harmless
  NBKIT_TEST_COLOR=$color PATH="$WORK/bin:$PATH" HOME="$WORK/home" GSETTINGS_BACKEND=memory PYTHONPATH="$TESTS/python" PYTHONDONTWRITEBYTECODE=1 GDK_BACKEND=x11 NO_AT_BRIDGE=1 \
    xvfb-run -a -s "-screen 0 ${screen}x24" "$GUI_PY" "$TESTS/python/gui_window.py" "$scenario" 2>&1 </dev/null \
    | grep -v -e 'libEGL warning' -e 'Unable to acquire session bus' -e '>16bit keyvals' -e '^$'
  [ "${PIPESTATUS[0]}" = 0 ] || rc=1
done
if [ -e "$WORK/launched" ]; then fail "no NetBeans of the machine was opened by the tests"; rc=1; fi
exit $rc
