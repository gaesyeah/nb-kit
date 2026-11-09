#!/usr/bin/env bash
# nbkit: kit of modules for Apache NetBeans on Linux (themes and checks).
# This file is the CLI: menu, status, progress, closing/opening NetBeans, backups and restore point.
# The code is in lib/ (theme and module engines, Python parts, base jars) and the modules are data in modules/:
# one folder per NetBeans module (module.toml) and per theme (modules/themes/<id>). See modules/README.md.
# Everything shown in the terminal comes from lang/<language>.lang (see "t" below).
set -euo pipefail
# Ctrl+C exits with code 130 (the exit trap uses it to undo a half-done install)
trap 'exit 130' INT TERM HUP
NBKIT_VERSION=2.2.0
SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "$0")"
NBKIT_DIR="$(dirname "$SELF")"
ME="$(basename "$SELF")"

[ -f "$NBKIT_DIR/lang/pt-BR.lang" ] && [ -f "$NBKIT_DIR/lib/terminal.sh" ] || { echo "nbkit: lang/ or lib/ not found next to $ME. Download the whole nbkit folder." >&2; exit 1; }
# --lang <id> or --lang=<id>, anywhere in the arguments
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --lang=*) NBKIT_LANG="${1#--lang=}" ;;
    --lang) NBKIT_LANG="${2:-}"; [ $# -gt 1 ] && shift ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done
set -- ${ARGS[@]+"${ARGS[@]}"}
# shellcheck disable=SC1091
source "$NBKIT_DIR/lib/terminal.sh"

# ---------- yes/no ----------
# yes/no question; the uppercase letter is the Enter default (Y or N in $2)
ask_yn() {
  local a hint; hint="$(t cli.yn_no)"; [ "$2" = Y ] && hint="$(t cli.yn_yes)"
  printf '%s %s ' "$1" "$hint"
  IFS= read -r a </dev/tty || a=""
  a="${a,,}"
  if [ -z "$a" ]; then [ "$2" = Y ]; return; fi
  case "$a" in s|sim|y|yes) return 0 ;; *) return 1 ;; esac
}

# ---------- system packages ----------
# installs a package with the system package manager, asking first (only with a terminal to ask)
# pkg_install <what> apt:<package> dnf:<package> pacman:<package> zypper:<package>
pkg_install() {
  local what="$1" spec pm pkg cmd=() sudo=()
  shift
  for spec in "$@"; do
    pm="${spec%%:*}"; pkg="${spec#*:}"
    case "$pm" in
      apt) command -v apt-get >/dev/null 2>&1 && cmd=(apt-get install -y "$pkg") ;;
      dnf) command -v dnf >/dev/null 2>&1 && cmd=(dnf install -y "$pkg") ;;
      pacman) command -v pacman >/dev/null 2>&1 && cmd=(pacman -S --needed --noconfirm "$pkg") ;;
      zypper) command -v zypper >/dev/null 2>&1 && cmd=(zypper --non-interactive install "$pkg") ;;
    esac
    [ ${#cmd[@]} -gt 0 ] && break
  done
  [ ${#cmd[@]} -gt 0 ] || return 1
  if [ "$(id -u)" != 0 ]; then command -v sudo >/dev/null 2>&1 || return 1; sudo=(sudo); fi
  { [ -t 0 ] && [ -t 1 ]; } || return 1
  ask_yn "$(t cli.ask_install "$what" "${sudo[*]+${sudo[*]} }${cmd[*]}")" Y || return 1
  if [ "${cmd[0]}" = apt-get ]; then ${sudo[@]+"${sudo[@]}"} apt-get update -qq || true; fi
  ${sudo[@]+"${sudo[@]}"} "${cmd[@]}"
}

# ---------- Python 3.11 or newer (reads the theme TOML files) ----------
find_python() {
  local c
  for c in python3 python3.14 python3.13 python3.12 python3.11; do
    if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>/dev/null; then
      command -v "$c"; return 0
    fi
  done
  return 1
}
NBKIT_PY="$(find_python || true)"
if [ -z "$NBKIT_PY" ]; then
  t cli.python_old "$(python3 --version 2>/dev/null || echo "-")"; echo
  if pkg_install "Python 3.11" apt:python3.11 dnf:python3.11 pacman:python zypper:python311; then
    NBKIT_PY="$(find_python || true)"
  fi
  [ -n "$NBKIT_PY" ] || die "$(t cli.python_manual)"
fi
export NBKIT_PY
# the Python parts import lib/text.py (texts of lang/); no __pycache__ inside the nbkit folder
export PYTHONPATH="$NBKIT_DIR/lib${PYTHONPATH:+:$PYTHONPATH}" PYTHONDONTWRITEBYTECODE=1

# ---------- module registry ----------
# nbkit_register <id> <function prefix> <category: theme|tool> <name> <description> <version>
MODS=()
declare -A MOD_FN=() MOD_CAT=() MOD_NAME=() MOD_DESC=() MOD_VER=()
nbkit_register() {
  MODS+=("$1"); MOD_FN[$1]="$2"; MOD_CAT[$1]="$3"; MOD_NAME[$1]="$4"; MOD_DESC[$1]="$5"; MOD_VER[$1]="$6"
}
# calls <prefix>_<function> of the module; returns 0 doing nothing if the module does not have it
mod_call() {
  local id="$1" fn="${MOD_FN[$1]}_$2"; shift 2
  if declare -F "$fn" >/dev/null; then "$fn" "$@"; fi
}
mod_has() { declare -F "${MOD_FN[$1]}_$2" >/dev/null; }
mod_status() { mod_call "$1" status; }  # no | ok | old:<v> | new:<v>
# compares the installed version (file nbkit/<id>.version, or the legacy one given in $2) with this nbkit's
version_status() {
  local v; v="$(cat "$(mod_version_file "$1")" 2>/dev/null || echo "${2:-}")"
  if [ -z "$v" ]; then echo "old:?"
  elif [ "$v" = "${MOD_VER[$1]}" ]; then echo ok
  elif [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -gt "${MOD_VER[$1]}" ]; then echo "new:$v"
  else echo "old:$v"; fi
}
mod_installed() { [ "$(mod_status "$1")" != no ]; }
mod_label() {
  local id="$1"
  if [ "${MOD_CAT[$id]}" = theme ]; then t cli.theme_label "${MOD_NAME[$id]}"; echo; else echo "${MOD_NAME[$id]}"; fi
}

usage() {
  local ids; ids="$(printf '%s ' "${MODS[@]}")"
  t cli.usage "$NBKIT_VERSION" "$ME" "$ME" "$ME" "$ME" "$ME" "${ids% }" "$ME"
}

# ---------- files shared by the engines ----------
# copies a file and checks its sha256 (catches a broken download of nbkit)
file_copy() { cp "$1" "$2" && echo "$3  $2" | sha256sum -c --quiet -; }
# copies one of the base jars of lib/jars/, checked against lib/jars/SHA256SUMS
jar_copy() {
  local sum; sum="$(awk -v f="$1" '$2 == f {print $1}' "$NBKIT_DIR/lib/jars/SHA256SUMS")"
  [ -n "$sum" ] && file_copy "$NBKIT_DIR/lib/jars/$1" "$2" "$sum"
}
# config/Modules/<name>.xml that turns a module on in NetBeans
module_xml() {
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE module PUBLIC "-//NetBeans//DTD Module Status 1.0//EN" "http://www.netbeans.org/dtds/module-status-1_0.dtd">
<module name="$1">
    <param name="autoload">false</param>
    <param name="eager">false</param>
    <param name="enabled">true</param>
    <param name="jar">modules/${1//./-}.jar</param>
    <param name="reloadable">false</param>
</module>
EOF
}

# ---------- loads the modules (themes first) ----------
[ -d "$NBKIT_DIR/modules" ] && [ -d "$NBKIT_DIR/lib" ] || die "$(t cli.no_modules_dir "$ME")"
# shellcheck disable=SC1091
source "$NBKIT_DIR/lib/themes.sh"     # every folder in modules/themes/
# shellcheck disable=SC1091
source "$NBKIT_DIR/lib/modules.sh"    # every folder in modules/ with a module.toml
# modules written in bash (see modules/README.md)
for f in "$NBKIT_DIR"/modules/*.sh; do
  [ -f "$f" ] || continue
  # shellcheck disable=SC1090
  source "$f"
done
[ ${#MODS[@]} -gt 0 ] || die "$(t cli.no_modules "$NBKIT_DIR/modules")"

# ---------- arguments ----------
ACTION=""; UD=""; SEL=()
for a in "$@"; do
  case "$a" in
    -h|--help|help) usage; exit 0 ;;
    install|uninstall|check) [ -z "$ACTION" ] && ACTION="$a" || die "$(t cli.repeated_command "$a")" ;;
    all|todos) SEL=("${MODS[@]}") ;;
    *)
      if [ -n "${MOD_FN[$a]:-}" ]; then SEL+=("$a")
      elif [ -d "$a" ]; then UD="$(readlink -f "$a")"
      else t cli.unknown_arg "$a" >&2; echo >&2; echo >&2; usage >&2; exit 1; fi ;;
  esac
done

MENU=0; INTERACTIVE=0
if [ -t 0 ] && [ -t 1 ]; then
  if [ $# -eq 0 ]; then MENU=1; INTERACTIVE=1; elif [ "${NBKIT_TTY:-}" = 1 ]; then INTERACTIVE=1; fi
fi
[ -n "$ACTION" ] || ACTION=install

# ---------- terminal ----------
# arrow key menu; result in MENU_IDX (-1 = left with Esc or q). MENU_HINT changes the legend.
menu() {
  local -a o=("$@"); local n=$# i=${MENU_START:-0} j k rest
  [ "$i" -lt "$n" ] || i=0
  printf '\e[?25l'; trap 'printf "\e[?25h\n"; exit 130' INT
  while :; do
    for ((j = 0; j < n; j++)); do
      if [ $j -eq $i ]; then printf '\r\e[K  %s> %s%s\n' "$BL$B" "${o[j]}" "$N"
      else printf '\r\e[K    %s\n' "${o[j]}"; fi
    done
    printf '\r\e[K  %s%s%s' "$D" "${MENU_HINT:-$(t cli.menu_hint)}" "$N"
    IFS= read -rsn1 k </dev/tty || k=q
    if [ "$k" = $'\e' ]; then
      rest=""; IFS= read -rsn2 -t 0.05 rest </dev/tty || true
      case "$rest" in '[A'|OA) k=up ;; '[B'|OB) k=down ;; '') k=q ;; *) k=x ;; esac
    fi
    case "$k" in
      up|k) i=$(( (i + n - 1) % n )) ;;
      down|j) i=$(( (i + 1) % n )) ;;
      '') break ;;
      q) i=-1; break ;;
    esac
    printf '\r\e[%dA' "$n"
  done
  printf '\r\e[K\e[?25h'; trap 'exit 130' INT
  MENU_IDX=$i
}

# spinner until the condition is true; any key cancels (returns 1)
spin_until() {
  local sp='|/-\' i=0 k cancel; cancel="$(t cli.enter_cancels)"
  printf '\e[?25l'; trap 'printf "\r\e[K\e[?25h"; exit 130' INT
  while ! "$2"; do
    printf '\r\e[K  %s%s%s %s  %s%s%s' "$Y" "${sp:i%4:1}" "$N" "$1" "$D" "$cancel" "$N"; i=$((i + 1))
    if IFS= read -rsn1 -t 0.25 k </dev/tty; then
      IFS= read -rsn5 -t 0.05 k </dev/tty || true
      printf '\r\e[K\e[?25h'; trap 'exit 130' INT; return 1
    fi
  done
  printf '\r\e[K\e[?25h'; trap 'exit 130' INT
}

HEADER=0
header() { [ $HEADER = 1 ] || echo "${B}nbkit${N} ${D}v$NBKIT_VERSION${N}"; HEADER=1; }

# ---------- userdir ----------
list_userdirs() {
  local d
  ls -d "$HOME"/.netbeans/*/ "$HOME"/snap/netbeans/common/data/*/ 2>/dev/null | grep -E '/[0-9][0-9.]*/$' \
    | awk -F/ '{print $(NF-1) "\t" $0}' | sort -Vr | cut -f2 | while IFS= read -r d; do
      [ -d "$d/config" ] && echo "${d%/}"
    done
  return 0
}
if [ -z "$UD" ]; then
  mapfile -t UDS < <(list_userdirs)
  if [ $MENU = 1 ] && [ ${#UDS[@]} -gt 1 ]; then
    header
    t cli.which_userdir; echo
    echo
    labels=()
    for d in "${UDS[@]}"; do
      l="NetBeans ${d##*/}   ${d/#$HOME/\~}"
      [ -e "$d/modules/nbkit-core.jar" ] || [ -e "$d/modules/com-onedarkmix-netbeans.jar" ] && l="$l   $(t cli.userdir_has_nbkit)"
      labels+=("$l")
    done
    menu "${labels[@]}"
    [ "$MENU_IDX" -lt 0 ] && { echo; exit 0; }
    UD="${UDS[$MENU_IDX]}"
    echo; echo
  else
    UD="${UDS[0]:-}"
  fi
fi
[ -n "$UD" ] || die "$(t cli.no_userdir)"
[ -d "$UD/config" ] || die "$(t cli.not_userdir "$UD")"
C="$UD/config"
STATEDIR="$UD/nbkit"
mod_version_file() { echo "$STATEDIR/$1.version"; }

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
CORE_JAR="$UD/modules/nbkit-core.jar"
CORE_XML="$C/Modules/nbkit-core.xml"
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

# ---------- restore point ----------
CLEAN=(); SNAP=""; SNAP_OK=0; DONE=0; SNAPPATHS=()
on_exit() {
  local rc=$? p
  if [ "$SNAP_OK" = 1 ] && [ "$DONE" != 1 ]; then
    [ -t 1 ] && printf '\e[?25h'
    echo
    if [ $rc = 130 ]; then t cli.interrupted; echo
    else t cli.stopped_error "$rc"; echo; fi
    for p in "${SNAPPATHS[@]}"; do rm -rf "${UD:?}/$p"; done
    tar -xf "$SNAP" -C "$UD" 2>/dev/null || true
    mod_rollback_extra
    touch "$UD/.lastModified"
    t cli.nothing_changed_nb; echo
  fi
  [ ${#CLEAN[@]} -gt 0 ] && rm -rf "${CLEAN[@]}"
  return 0
}
trap on_exit EXIT
# undoes what lives outside the userdir (e.g. a backup just created); each module may have <prefix>_rollback
mod_rollback_extra() {
  local id
  for id in "${MODS[@]}"; do mod_call "$id" rollback || true; done
}
snapshot() {
  local id p have=()
  SNAPPATHS=(nbkit modules/nbkit-core.jar config/Modules/nbkit-core.xml)
  for id in "$@"; do
    while IFS= read -r p; do [ -n "$p" ] && SNAPPATHS+=("$p"); done < <(mod_call "$id" paths)
  done
  SNAP="$(mktemp)"; CLEAN+=("$SNAP")
  for p in "${SNAPPATHS[@]}"; do [ -e "$UD/$p" ] && have+=("$p"); done
  if [ ${#have[@]} -gt 0 ]; then tar -cf "$SNAP" -C "$UD" "${have[@]}"; else tar -cf "$SNAP" -T /dev/null; fi
  SNAP_OK=1
}

# ---------- install / uninstall / check ----------
tmpdir() { local d; d="$(mktemp -d)"; CLEAN+=("$d"); echo "$d"; }
labels_of() { local id; for id in "$@"; do printf '%s; ' "$(mod_label "$id")"; done | sed 's/; $//'; }
userdir_line() { echo "  ${D}userdir${N}  ${UD/#$HOME/\~}"; }

do_install() {
  local id other conflicts=() total=1
  # theme: only one active at a time; installing a theme removes the other
  for id in "$@"; do
    if [ "${MOD_CAT[$id]}" = theme ]; then
      for other in "${MODS[@]}"; do
        if [ "$other" != "$id" ] && [ "${MOD_CAT[$other]}" = theme ] && mod_installed "$other"; then conflicts+=("$other"); fi
      done
    fi
  done
  for id in "${conflicts[@]}"; do total=$((total + $(mod_call "$id" uninstall_steps))); done
  for id in "$@"; do total=$((total + $(mod_call "$id" install_steps))); done
  if [ $HEADER = 0 ]; then header; userdir_line; echo; fi
  ensure_closed
  snapshot "$@" "${conflicts[@]}"
  TOTAL=$total
  for id in "${conflicts[@]}"; do
    info "$(t cli.switching_theme "$(mod_label "$id")")"
    mod_call "$id" uninstall
    rm -f "$(mod_version_file "$id")"
  done
  for id in "$@"; do
    mod_call "$id" install
    mkdir -p "$STATEDIR"
    echo "${MOD_VER[$id]}" > "$(mod_version_file "$id")"
  done
  step "$(t cli.step_core)"
  core_install
  ok "$(t cli.core_ready)"
  DONE=1
  echo
  t cli.installed "$(labels_of "$@")"; echo
  after_change install
}

do_uninstall() {
  local id total=0 remaining=0 q
  for id in "$@"; do total=$((total + $(mod_call "$id" uninstall_steps))); done
  for id in "${MODS[@]}"; do
    if mod_installed "$id" && [[ " $* " != *" $id "* ]]; then remaining=1; fi
  done
  [ $remaining = 1 ] || total=$((total + 1))
  if [ $HEADER = 0 ]; then header; userdir_line; echo; fi
  ensure_closed
  snapshot "$@"
  TOTAL=$total
  for id in "$@"; do
    mod_call "$id" uninstall
    rm -f "$(mod_version_file "$id")"
  done
  if [ $remaining = 0 ]; then
    step "$(t cli.step_core)"
    core_uninstall
    ok "$(t cli.core_removed)"
  fi
  DONE=1
  echo
  t cli.removed "$(labels_of "$@")"; echo
  # backups the module kept: asks whether to delete them
  if [ $INTERACTIVE = 1 ]; then
    for id in "$@"; do
      mod_has "$id" backups || continue
      mapfile -t BKS < <(mod_call "$id" backups)
      [ ${#BKS[@]} -gt 0 ] || continue
      echo
      if [ ${#BKS[@]} = 1 ]; then q="$(t cli.one_file)"; else q="$(t cli.n_files "${#BKS[@]}")"; fi
      if ask_yn "$(t cli.ask_delete_backups "$(mod_label "$id")" "$q")" N; then
        rm -f "${BKS[@]}"; ok "$(t cli.backups_deleted)"
      fi
    done
  fi
  after_change uninstall
}

# after install/uninstall: open NetBeans and, after an install, check by itself
after_change() {
  if [ $INTERACTIVE != 1 ]; then
    if [ "$1" = install ]; then t cli.check_later "$ME"; else t cli.open_nb; fi
    echo
    exit 0
  fi
  echo
  if find_launcher && ask_yn "$(t cli.ask_open)" Y; then open_netbeans; fi
  if [ "$1" = install ]; then
    if spin_until "$(t cli.waiting_open)" nb_running \
       && spin_until "$(t cli.waiting_modules)" nb_loaded; then
      sleep 2
      echo
      exec env NBKIT_TTY=1 bash "$SELF" check "$UD"
    fi
    t cli.check_later_menu "$(t cli.menu_check)"; echo
  fi
  exit 0
}

# prints "  ok/PROBLEM ..."; modules return 0 ok, 1 fixable by reinstalling, 2 not fixable
res() {
  if [ "$1" = 0 ]; then printf '  %s%-9s%s%s\n' "$G" "$(t cli.res_ok)" "$N" "$2"
  else printf '  %s%-9s%s%s\n' "$R" "$(t cli.res_problem)" "$N" "$2"; fi
}
log_has_module() { grep -qE "^\s+$1 \[" "$UD/var/log/messages.log" 2>/dev/null; }
log_module_errors() { grep -E "$1" "$UD/var/log/messages.log" 2>/dev/null | grep -E 'could not|cannot|Exception|SEVERE|disabled|requires' | head -5 || true; }

do_check() {
  local id rc worst=0 fix=() log="$UD/var/log/messages.log" out
  header
  userdir_line
  echo
  local any=0
  for id in "${MODS[@]}"; do mod_installed "$id" && any=1; done
  [ $any = 1 ] || { t cli.nothing_installed_here; echo; exit 3; }
  if [ ! -e "$log" ] || { [ -e "$CORE_JAR" ] && [ ! "$log" -nt "$CORE_JAR" ]; }; then
    t cli.open_then_check; echo; exit 3
  fi
  echo "${B}$(t cli.checking)${N}"
  for id in "${MODS[@]}"; do
    mod_installed "$id" || continue
    echo "  ${B}$(mod_label "$id")${N}"
    rc=0; out="$(mod_call "$id" check 2>&1)" || rc=$?
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/  /'
    if [ $rc = 1 ]; then fix+=("$id"); fi
    [ $rc -gt $worst ] && worst=$rc
  done
  local j; j="$(sed -n 's/^ *Java; VM; Vendor *= *\([^;]*\).*/\1/p' "$log" | tail -1)"
  [ -n "$j" ] && printf '  %s%-9s%s%s\n' "$D" "$(t cli.res_info)" "$N" "$(t cli.nb_java "$j")"
  if [[ "${j%%.*}" =~ ^[0-9]+$ ]] && [ "${j%%.*}" -lt 17 ]; then
    printf '  %s%-9s%s%s\n' "$Y" "$(t cli.res_warn)" "$N" "$(t cli.java_too_old "$j")"
  fi
  echo
  if [ $worst = 0 ]; then echo "${G}$(t cli.all_good)${N}"; exit 0; fi
  t cli.problems_above; echo
  if [ ${#fix[@]} -gt 0 ] && [ $INTERACTIVE = 1 ]; then
    echo
    if ask_yn "$(t cli.ask_reinstall)" Y; then echo; exec env NBKIT_TTY=1 NBKIT_CLOSE=1 bash "$SELF" install "${fix[@]}" "$UD"; fi
  else
    t cli.send_output; echo
  fi
  exit "$worst"
}

# ---------- backups (modules that keep the previous state: <prefix>_backups) ----------
bk_date() {
  local b; b="$(basename "$1" .tar.gz)"; b="${b##*-backup-}"
  if [[ "$b" =~ ^([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2})$ ]]; then
    local f="${L[cli.date_format]}"
    f="${f//\{year\}/${BASH_REMATCH[1]}}"; f="${f//\{month\}/${BASH_REMATCH[2]}}"; f="${f//\{day\}/${BASH_REMATCH[3]}}"
    f="${f//\{hour\}/${BASH_REMATCH[4]}}"; f="${f//\{minute\}/${BASH_REMATCH[5]}}"
    echo "$f"
  else echo "$b"; fi
}
bk_size() { local b; b=$(stat -c %s "$1" 2>/dev/null || echo 0); echo "$(( (b + 1023) / 1024 )) KB"; }
# all backups: "id<TAB>file", from the oldest to the newest inside each module
all_backups() {
  local id f
  for id in "${MODS[@]}"; do
    mod_has "$id" backups || continue
    while IFS= read -r f; do [ -n "$f" ] && printf '%s\t%s\n' "$id" "$f"; done < <(mod_call "$id" backups)
  done
  return 0
}
# browses the backups: Enter restores, Del deletes, Esc goes back. A confirmed restore goes to RESTORE_ID/RESTORE_BK
browse_backups() {
  local -a rows; local i=0 n j k rest line id f first mods
  RESTORE_BK=""; RESTORE_ID=""
  printf '\e[?1049h'; trap 'printf "\e[?25h\e[?1049l"; exit 130' INT
  while :; do
    mapfile -t rows < <(all_backups)
    n=${#rows[@]}
    [ "$n" -gt 0 ] || break
    [ "$i" -lt "$n" ] || i=$((n - 1))
    mods="$(printf '%s\n' "${rows[@]}" | cut -f1 | sort -u | wc -l)"
    printf '\e[H\e[2J\e[?25l'
    echo "${B}nbkit${N} ${D}v$NBKIT_VERSION${N}"
    echo "  ${B}$(t cli.backups_title)${N}  ${D}${UD/#$HOME/\~}${N}"
    echo
    for ((j = 0; j < n; j++)); do
      id="${rows[j]%%$'\t'*}"; f="${rows[j]#*$'\t'}"
      line="$(bk_date "$f")   $(printf '%6s' "$(bk_size "$f")")   $(mod_call "$id" backup_desc "$f")"
      [ "$mods" -gt 1 ] && line="$(mod_label "$id"): $line"
      first="$(mod_call "$id" backups | head -1)"
      [ "$f" = "$first" ] && line="$line   ${D}$(t cli.backup_original)${N}"
      if [ $j -eq $i ]; then printf '  %s> %s%s\n' "$BL$B" "$line" "$N"; else printf '    %s\n' "$line"; fi
    done
    echo
    printf '  %s%s%s' "$D" "$(t cli.backups_hint)" "$N"
    IFS= read -rsn1 k </dev/tty || k=q
    if [ "$k" = $'\e' ]; then
      rest=""; IFS= read -rsn2 -t 0.05 rest </dev/tty || true
      case "$rest" in
        '[A'|OA) k=up ;;
        '[B'|OB) k=down ;;
        '[3') IFS= read -rsn1 -t 0.05 j </dev/tty || true; k=del ;;
        '') k=q ;;
        *) k=x ;;
      esac
    fi
    id="${rows[i]%%$'\t'*}"; f="${rows[i]#*$'\t'}"
    case "$k" in
      up|k) i=$(( (i + n - 1) % n )) ;;
      down|j) i=$(( (i + 1) % n )) ;;
      q) break ;;
      del)
        printf '\e[?25h\n\n'
        if [ "$(mod_call "$id" backups | wc -l)" = 1 ] && mod_installed "$id"; then
          t cli.only_backup "$(mod_label "$id")"; echo
          echo
        fi
        if ask_yn "$(t cli.ask_delete_backup "$(bk_date "$f")")" N; then
          rm -f "$f"; ok "$(t cli.backup_deleted)"; sleep 0.8
        fi ;;
      '')
        printf '\e[?25h\n\n'
        t cli.restore_back_to "$(bk_date "$f")" "$(mod_call "$id" backup_desc "$f")"; echo
        if mod_installed "$id"; then
          t cli.restore_uninstalls_first "$(mod_label "$id")"; echo
        else
          t cli.restore_makes_backup; echo
        fi
        echo
        if ask_yn "$(t cli.ask_restore)" N; then RESTORE_BK="$f"; RESTORE_ID="$id"; break; fi ;;
    esac
  done
  printf '\e[?25h\e[?1049l'; trap 'exit 130' INT
}
do_restore() {
  local id="$1" f="$2" total
  total="$(mod_call "$id" restore_steps "$f")"
  if [ $HEADER = 0 ]; then header; userdir_line; echo; fi
  ensure_closed
  snapshot "$id"
  TOTAL=$total
  mod_call "$id" restore "$f"
  mod_installed "$id" || rm -f "$(mod_version_file "$id")"
  local any=0 m
  for m in "${MODS[@]}"; do mod_installed "$m" && any=1; done
  [ $any = 1 ] || core_uninstall
  DONE=1
  echo
  echo "${G}${B}$(t cli.restored)${N}"
  after_change restore
}

# ---------- status and menu ----------
status_line() {
  local id="$1" s v
  s="$(mod_status "$id")"; v="${MOD_VER[$id]}"
  case "$s" in
    ok) t cli.status_ok "$v" ;;
    old:\?) t cli.status_old_unknown "$v" ;;
    old:*) t cli.status_old "${s#old:}" "$v" ;;
    new:*) t cli.status_new "${s#new:}" ;;
    *) t cli.status_no ;;
  esac
}
# module submenu: "All" + each one. Result in PICK (list of ids); empty = went back with Esc
pick_modules() {
  local title="$1"; shift
  local ids=("$@") opts=() id
  PICK=()
  if [ ${#ids[@]} = 1 ]; then PICK=("${ids[0]}"); return 0; fi
  opts=("$(t cli.all)")
  for id in "${ids[@]}"; do opts+=("$(mod_label "$id")"); done
  echo "  ${B}$title${N}"
  MENU_START=0 MENU_HINT="$(t cli.submenu_hint)" menu "${opts[@]}"
  if [ "$MENU_IDX" -lt 0 ]; then
    printf '\e[%dA\r\e[J' "$(( ${#opts[@]} + 1 ))"
    return 0
  fi
  if [ "$MENU_IDX" = 0 ]; then PICK=("${ids[@]}"); else PICK=("${ids[$((MENU_IDX - 1))]}"); fi
  # theme: with "All", installs only the first theme of the list (one active theme at a time)
  local out=() theme=""
  for id in "${PICK[@]}"; do
    if [ "${MOD_CAT[$id]}" = theme ]; then [ -z "$theme" ] && { theme="$id"; out+=("$id"); }; else out+=("$id"); fi
  done
  PICK=("${out[@]}")
}

if [ $MENU = 1 ]; then
  header
  userdir_line
  w=0
  for id in "${MODS[@]}"; do l="$(mod_label "$id")"; [ ${#l} -gt $w ] && w=${#l}; done
  for id in "${MODS[@]}"; do
    l="$(mod_label "$id")"
    printf '  %s%*s%s\n' "$l" $((w + 3 - ${#l})) '' "$(status_line "$id")"
  done
  echo
  MENU_START=0
  while :; do
    pending=(); current=(); installed=()
    for id in "${MODS[@]}"; do
      case "$(mod_status "$id")" in
        ok|new:*) current+=("$id"); installed+=("$id") ;;
        old:*) pending+=("$id"); installed+=("$id") ;;
        *) pending+=("$id") ;;
      esac
    done
    opts=(); acts=()
    if [ ${#pending[@]} -gt 0 ]; then
      if [ ${#installed[@]} = 0 ]; then opts+=("$(t cli.menu_install)"); else opts+=("$(t cli.menu_install_update)"); fi; acts+=(install)
    fi
    if [ ${#current[@]} -gt 0 ]; then opts+=("$(t cli.menu_reinstall)"); acts+=(reinstall); fi
    if [ ${#installed[@]} -gt 0 ] && [ -e "$UD/var/log/messages.log" ] && [ -e "$CORE_JAR" ] && [ "$UD/var/log/messages.log" -nt "$CORE_JAR" ]; then
      opts+=("$(t cli.menu_check)"); acts+=(check)
    fi
    nbk="$(all_backups | wc -l)"
    if [ "$nbk" -gt 0 ]; then opts+=("$(t cli.menu_backups "$nbk")"); acts+=(backups); fi
    if [ ${#installed[@]} -gt 0 ]; then opts+=("$(t cli.menu_uninstall)"); acts+=(uninstall); fi
    opts+=("$(t cli.menu_quit)"); acts+=(quit)
    menu "${opts[@]}"
    [ "$MENU_IDX" -lt 0 ] && { echo; exit 0; }
    act="${acts[$MENU_IDX]}"
    MENU_START=$MENU_IDX
    back() { printf '\e[%dA\r\e[J' "${#opts[@]}"; }
    case "$act" in
      quit) echo; exit 0 ;;
      check) echo; echo; do_check ;;
      backups)
        browse_backups
        if [ -n "$RESTORE_BK" ]; then echo; echo; do_restore "$RESTORE_ID" "$RESTORE_BK"; fi
        back; continue ;;
      install|reinstall|uninstall)
        if [ "$act" = install ]; then list=("${pending[@]}"); title="$(t cli.menu_install)"
        elif [ "$act" = reinstall ]; then list=("${current[@]}"); title="$(t cli.menu_reinstall)"
        else list=("${installed[@]}"); title="$(t cli.menu_uninstall)"; fi
        back
        pick_modules "$title" "${list[@]}"
        if [ ${#PICK[@]} = 0 ]; then continue; fi
        echo
        if [ "$act" = uninstall ]; then
          for id in "${PICK[@]}"; do
            echo "  ${B}$(mod_label "$id")${N}"
            mod_call "$id" uninstall_summary
          done
          echo
          ask_yn "$(t cli.ask_uninstall)" N || { t cli.nothing_changed; echo; exit 0; }
          echo
          do_uninstall "${PICK[@]}"
        else
          do_install "${PICK[@]}"
        fi ;;
    esac
  done
fi

# ---------- without the menu (arguments) ----------
case "$ACTION" in
  check) do_check ;;
  install)
    [ ${#SEL[@]} -gt 0 ] || SEL=("${MODS[@]}")
    # one theme at a time
    sel2=(); theme=""
    for id in "${SEL[@]}"; do
      if [ "${MOD_CAT[$id]}" = theme ]; then [ -z "$theme" ] && { theme="$id"; sel2+=("$id"); }; else sel2+=("$id"); fi
    done
    do_install "${sel2[@]}" ;;
  uninstall)
    if [ ${#SEL[@]} = 0 ]; then for id in "${MODS[@]}"; do mod_installed "$id" && SEL+=("$id"); done; fi
    [ ${#SEL[@]} -gt 0 ] || { t cli.nothing_installed; echo; exit 0; }
    do_uninstall "${SEL[@]}" ;;
esac
