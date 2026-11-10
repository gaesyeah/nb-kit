# shellcheck shell=bash
# What the graphical interface (lib/gui) needs: PyGObject, GTK 4 and VTE for GTK 4. Used by nbkit.sh (gui)
# and tests/run.sh (the interface tests).

# a Python that has them: the system one first (python3-gi is built for it)
gui_python() {
  local c
  for c in /usr/bin/python3 "${NBKIT_PY:-python3}" python3 python3.14 python3.13 python3.12 python3.11; do
    if command -v "$c" >/dev/null 2>&1 && "$c" -c "import gi; gi.require_version('Gtk', '4.0'); gi.require_version('Vte', '3.91'); from gi.repository import Gtk, Vte" >/dev/null 2>&1; then
      command -v "$c"; return 0
    fi
  done
  return 1
}
# the packages, in the format of pkg_for (lib/packages.sh): one line each
gui_package_specs() {
  echo "apt:python3-gi dnf:python3-gobject pacman:python-gobject zypper:python3-gobject"
  echo "apt:gir1.2-gtk-4.0 dnf:gtk4 pacman:gtk4 zypper:typelib-1_0-Gtk-4_0"
  echo "apt:gir1.2-vte-3.91 dnf:vte291-gtk4 pacman:vte4 zypper:typelib-1_0-Vte-3_91"
}
