# shellcheck shell=bash
# NetBeans itself: its userdirs, whether it is open, how to open and close it, the Java it runs on and
# the base module nbkit.core (closes NetBeans from the terminal). Used by nbkit.sh.

# ---------- userdir ----------
list_userdirs() {
  local d
  ls -d "$HOME"/.netbeans/*/ "$HOME"/snap/netbeans/common/data/*/ 2>/dev/null | grep -E '/[0-9][0-9.]*/$' \
    | awk -F/ '{print $(NF-1) "\t" $0}' | sort -Vr | cut -f2 | while IFS= read -r d; do
      [ -d "$d/config" ] && echo "${d%/}"
    done
  return 0
}

# ---------- NetBeans open/closed ----------
# NetBeans processes using this userdir (the launcher passes --userdir to java)
nb_pids() {
  local p
  for p in $(pgrep -f 'org.netbeans.Main' 2>/dev/null || true); do
    [ -r "/proc/$p/cmdline" ] || continue
    if tr '\0' '\n' < "/proc/$p/cmdline" 2>/dev/null \
       | grep -xF -e "$UD" -e "-XX:HeapDumpPath=$UD/var/log/heapdump.hprof" >/dev/null; then echo "$p"; fi
  done
  return 0
}
nb_running() {
  if command -v pgrep >/dev/null 2>&1; then [ -n "$(nb_pids)" ]; else [ -e "$UD/lock" ]; fi
}
nb_closed() { ! nb_running; }
# the log of this session already listed the enabled modules (and is newer than the install)
nb_loaded() {
  local l="$UD/var/log/messages.log"
  [ -e "$l" ] && [ "$l" -nt "$CORE_JAR" ] && grep -q 'Turning on modules' "$l"
}

# how to open the NetBeans that last used this userdir (command in LAUNCH)
find_launcher() {
  local f inst=""
  LAUNCH=()
  if [ -n "${NB_HOME:-}" ] && [ -x "$NB_HOME/bin/netbeans" ]; then LAUNCH=("$NB_HOME/bin/netbeans"); fi
  if [ ${#LAUNCH[@]} -eq 0 ]; then
    for f in "$UD/var/log/messages.log" "$UD/var/log/messages.log.1"; do
      [ -f "$f" ] && inst="$(sed -n 's/^ *Installation *= *//p' "$f" | tail -1)"
      [ -n "$inst" ] && break
    done
    case "$inst" in
      /app/netbeans/*) if command -v flatpak >/dev/null 2>&1; then LAUNCH=(flatpak run org.apache.netbeans); fi ;;
      /snap/*) if [ -x /snap/bin/netbeans ]; then LAUNCH=(/snap/bin/netbeans); fi ;;
      ?*) if [ -x "$(dirname "$inst")/bin/netbeans" ]; then LAUNCH=("$(dirname "$inst")/bin/netbeans"); fi ;;
    esac
  fi
  if [ ${#LAUNCH[@]} -eq 0 ] && command -v netbeans >/dev/null 2>&1; then LAUNCH=("$(command -v netbeans)"); fi
  [ ${#LAUNCH[@]} -gt 0 ] || return 1
  # the launcher alone picks the system java, which may be too old (the menu shortcut may use another one);
  # use the same Java NetBeans ran with last time. Flatpak and Snap bring their own Java.
  case "${LAUNCH[0]}" in flatpak|/snap/*) ;; *)
    local jdk; jdk="$(nb_java_home)"
    if [ -n "$jdk" ]; then LAUNCH+=(--jdkhome "$jdk"); fi ;;
  esac
  return 0
}
# NetBeans Java: the one of the open process (kept in NB_JDK) or the "Java Home" of the last run's log
NB_JDK=""
remember_java() {
  local p j
  for p in $(nb_pids); do
    j="$(readlink -f "/proc/$p/exe" 2>/dev/null || true)"
    case "$j" in */bin/java) NB_JDK="${j%/bin/java}"; return 0 ;; esac
  done
  return 0
}
nb_java_home() {
  local f j
  if [ -n "$NB_JDK" ] && [ -x "$NB_JDK/bin/java" ]; then echo "$NB_JDK"; return 0; fi
  for f in "$UD/var/log/messages.log" "$UD/var/log/messages.log.1"; do
    [ -f "$f" ] || continue
    j="$(sed -n 's/^ *Java Home *= *//p' "$f" | tail -1)"
    if [ -n "$j" ] && [ -x "$j/bin/java" ]; then echo "$j"; return 0; fi
  done
  return 0
}
open_netbeans() {
  (cd "$HOME" && setsid "${LAUNCH[@]}" >/dev/null 2>&1 </dev/null &)
  ok "$(t cli.opening_netbeans)"
}

# asks NetBeans to close as in File > Exit: it asks about unsaved files and running processes itself.
# 1) the --nbkit-close option of the base module (or --onedark-close of old theme versions), through the launcher;
# 2) wmctrl, if present: closes the main window like the window's X;
# 3) with neither: asks you to close it.
close_option() {
  if grep -aqs 'nbkit/core/CloseOption' "$CORE_JAR"; then echo --nbkit-close
  elif grep -aqs 'onedarkmix/netbeans/CloseOption' "$UD/modules/com-onedarkmix-netbeans.jar"; then echo --onedark-close
  fi
}
nb_windows() {
  local pid
  command -v wmctrl >/dev/null 2>&1 || return 0
  for pid in $(nb_pids); do wmctrl -lp 2>/dev/null | awk -v p="$pid" '$3 == p && /NetBeans/ {print $1}'; done
  return 0
}
can_close() {
  [ -e "$UD/lock" ] && [ -n "$(close_option)" ] && find_launcher && return 0
  command -v wmctrl >/dev/null 2>&1 && [ -n "$(nb_windows)" ]
}
close_netbeans() {
  local how="" id opt
  opt="$(close_option)"
  if [ -e "$UD/lock" ] && [ -n "$opt" ] && find_launcher; then
    if (cd "$HOME" && timeout 90 "${LAUNCH[@]}" --userdir "$UD" "$opt" </dev/null >/dev/null 2>&1); then how=module; fi
  fi
  if [ -z "$how" ]; then
    for id in $(nb_windows); do wmctrl -i -c "$id" && how=wm; done
  fi
  if [ -n "$how" ]; then
    info "$(t cli.asked_to_close)"
    info "$(t cli.answer_there)"
    spin_until "$(t cli.waiting_close)" nb_closed
  else
    info "$(t cli.could_not_ask)"
    spin_until "$(t cli.close_to_continue)" nb_closed
  fi
}
# makes sure NetBeans is closed before touching files
ensure_closed() {
  nb_running || return 0
  remember_java
  [ $INTERACTIVE = 1 ] || die "$(t cli.nb_open_die)"
  if can_close; then
    if [ "${NBKIT_CLOSE:-}" != 1 ] && ! ask_yn "$(t cli.ask_close)" Y; then
      t cli.nothing_changed; echo; exit 0
    fi
    close_netbeans || { t cli.cancelled; echo; exit 0; }
  else
    spin_until "$(t cli.nb_open_close_it)" nb_closed || { t cli.cancelled; echo; exit 0; }
  fi
  ok "$(t cli.nb_closed)"
  echo
}

# ---------- base module (nbkit.core): only the option to close NetBeans from the terminal ----------
core_install() {
  mkdir -p "$UD/modules" "$C/Modules"
  jar_copy nbkit-core.jar "$CORE_JAR" || die "$(t cli.core_corrupt)"
  module_xml nbkit.core > "$CORE_XML"
  touch "$UD/.lastModified"
}
core_uninstall() {
  rm -f "$CORE_JAR" "$CORE_XML"
  rmdir "$STATEDIR" 2>/dev/null || true
  touch "$UD/.lastModified"
}
