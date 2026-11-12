#!/usr/bin/env bash
# nbkit: kit of modules for Apache NetBeans on Linux (themes and checks).
# This file is the CLI: arguments, menu and actions (install, uninstall, check, restore). The rest is in lib/:
# the module registry, NetBeans (userdirs, open/close), the restore point, backups, status, the theme and tool
# engines, the Python parts, the interface and the base jars. The modules are data in modules/:
# one folder per theme (modules/themes/<id>) and per tool (modules/tools/<id>). See modules/README.md.
# Everything shown in the terminal comes from lang/<language>.lang (see "t" below).
set -euo pipefail
# Ctrl+C exits with code 130 (the exit trap uses it to undo a half-done install)
trap 'exit 130' INT TERM HUP
NBKIT_VERSION=3.2.0
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

# shellcheck disable=SC1091
source "$NBKIT_DIR/lib/packages.sh"

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
  info "$(t cli.python_using "$NBKIT_PY")"
  echo
fi
export NBKIT_PY
# the Python parts import lib/text.py (texts of lang/); no __pycache__ inside the nbkit folder
export PYTHONPATH="$NBKIT_DIR/lib${PYTHONPATH:+:$PYTHONPATH}" PYTHONDONTWRITEBYTECODE=1

usage() {
  local ids; ids="$(printf '%s ' "${MODS[@]}")"
  t cli.usage "$NBKIT_VERSION" "$ME" "$ME" "$ME" "$ME" "$ME" "$ME" "$ME" "$ME" "$ME" "$ME" "$ME" "$ME" "$ME" "$ME" "$ME" "$ME" "$ME" "${ids% }" "$ME"
}

# ---------- the parts of the CLI (lib/) ----------
# shellcheck disable=SC1091
source "$NBKIT_DIR/lib/registry.sh"
# shellcheck disable=SC1091
source "$NBKIT_DIR/lib/netbeans.sh"
# shellcheck disable=SC1091
source "$NBKIT_DIR/lib/restore.sh"
# shellcheck disable=SC1091
source "$NBKIT_DIR/lib/backups.sh"
# shellcheck disable=SC1091
source "$NBKIT_DIR/lib/status.sh"
# shellcheck disable=SC1091
source "$NBKIT_DIR/lib/selfinstall.sh"
# shellcheck disable=SC1091
source "$NBKIT_DIR/lib/analyze.sh"

# ---------- loads the modules (themes first) ----------
[ -d "$NBKIT_DIR/modules" ] && [ -d "$NBKIT_DIR/lib" ] || die "$(t cli.no_modules_dir "$ME")"
# shellcheck disable=SC1091
source "$NBKIT_DIR/lib/themes.sh"     # every folder in modules/themes/
# shellcheck disable=SC1091
source "$NBKIT_DIR/lib/tools.sh"      # every folder in modules/tools/
[ ${#MODS[@]} -gt 0 ] || die "$(t cli.no_modules "$NBKIT_DIR/modules")"

# ---------- arguments ----------
# analyze jsf <project> and debug jsf on|off|log [userdir]: their own arguments (a folder here is not a userdir)
case "${1:-}" in
  analyze)
    # analyze jsf <project> | analyze jsf <project> --explain <file> | analyze jsf --explain <file> (project found from the file)
    [ "${2:-}" = jsf ] || die "$(t cli.analyze_usage)"
    if [ "${3:-}" = --explain ] && [ $# = 4 ]; then header; jsf_analyze "" "$4"; exit $?; fi
    { [ $# -le 3 ] || { [ $# = 5 ] && [ "$4" = --explain ]; }; } || die "$(t cli.analyze_usage)"
    header; jsf_analyze "${3:-}" "${5:-}"; exit $? ;;
  debug)
    [ "${2:-}" = jsf ] && [ $# -le 4 ] || die "$(t cli.debug_usage)"
    jsf_debug "${3:-}" "${4:-}"; exit 0 ;;
esac
ACTION=""; UD=""; SEL=(); JSON=0; BKF=""
for a in "$@"; do
  case "$a" in
    -h|--help|help) usage; exit 0 ;;
    install|uninstall|check|status|restore|delete-backup|gui|test|build|install-self|uninstall-self|update-self)
      [ -z "$ACTION" ] && ACTION="$a" || die "$(t cli.repeated_command "$a")" ;;
    --json) JSON=1 ;;
    all|todos) SEL=("${MODS[@]}") ;;
    *)
      if [ -n "${MOD_FN[$a]:-}" ]; then SEL+=("$a")
      elif [ -d "$a" ]; then UD="$(cd "$a" && pwd)"      # the path as you see it (~/... stays ~/... with links)
      elif [ -f "$a" ]; then BKF="$(readlink -f "$a")"
      else echo "${R}$(t cli.unknown_arg "$a")${N}" >&2; echo >&2; usage >&2; exit 1; fi ;;
  esac
done

MENU=0; INTERACTIVE=0
if [ -t 0 ] && [ -t 1 ]; then
  if [ $# -eq 0 ]; then MENU=1; INTERACTIVE=1; elif [ "${NBKIT_TTY:-}" = 1 ]; then INTERACTIVE=1; fi
fi
# the questions the theme scripts ask follow the same rule (with arguments and no NBKIT_TTY: no questions)
export NBKIT_INTERACTIVE=$INTERACTIVE
# no command: the menu in a terminal; without one (a pipe, a file, a script) only the status, so nothing changes
# that was not asked for; modules or a userdir alone still mean install
if [ -z "$ACTION" ]; then if [ $# -eq 0 ]; then ACTION=status; else ACTION=install; fi; fi
# tests: they live in the repository, not in the release zip
if [ "$ACTION" = test ]; then
  [ -f "$NBKIT_DIR/tests/run.sh" ] || die "$(t cli.no_tests)"
  exec bash "$NBKIT_DIR/tests/run.sh"
fi
# rebuilds the NetBeans modules from src/ (see src/build.sh)
if [ "$ACTION" = build ]; then exec bash "$NBKIT_DIR/src/build.sh"; fi
# nbkit itself on the system (lib/selfinstall.sh): needs no NetBeans
if [ "$ACTION" = install-self ]; then header; install_self; exit 0; fi
if [ "$ACTION" = update-self ]; then header; update_self; exit 0; fi
if [ "$ACTION" = uninstall-self ]; then
  header
  # with a terminal to answer (the menu, the interface): asks first
  if [ $INTERACTIVE = 1 ]; then ask_yn "$(t cli.ask_uninstall_self)" N || { t cli.nothing_changed; echo; exit 0; }; fi
  uninstall_self; exit 0
fi

# ---------- graphical interface (lib/gui): GTK 4 and VTE through PyGObject ----------
if [ "$ACTION" = gui ]; then
  # shellcheck disable=SC1091
  source "$NBKIT_DIR/lib/gui.sh"
  GUI_PY="$(gui_python || true)"
  if [ -z "$GUI_PY" ]; then
    t cli.gui_missing; echo
    if m="$(pkg_manager)"; then
      pkgs=()
      while IFS= read -r spec; do
        # shellcheck disable=SC2086
        pkgs+=("$(pkg_for "$m" $spec)")
      done < <(gui_package_specs)
      if pkg_run "$(t cli.gui_packages)" "${pkgs[@]}"; then GUI_PY="$(gui_python || true)"; fi
    fi
    [ -n "$GUI_PY" ] || die "$(t cli.gui_manual)"
  fi
  # a menu entry, so the desktop shows the nbkit icon in the taskbar (it matches the window by the app id);
  # rewritten each time, so it follows this folder if it moves; once installed, it stays on the installed one
  if ! self_installed || [ "$NBKIT_DIR" = "$(readlink -f "$SELF_DEST")" ]; then write_desktop "$NBKIT_DIR"; fi
  # in its own session: the terminal is free at once, and closing the window ends it; messages go to a log
  log="${XDG_CACHE_HOME:-$HOME/.cache}/nbkit/gui.log"
  mkdir -p "$(dirname "$log")"
  setsid -f "$GUI_PY" "$NBKIT_DIR/lib/gui/app.py" ${UD:+"$UD"} </dev/null >"$log" 2>&1
  t cli.gui_started "${log/#$HOME/\~}"; echo
  exit 0
fi

# ---------- userdir ----------
mapfile -t UDS < <(list_userdirs)
# a userdir given as argument that is not in the usual places also goes to the list
if [ -n "$UD" ] && [[ " ${UDS[*]} " != *" $UD "* ]]; then UDS=("$UD" ${UDS[@]+"${UDS[@]}"}); fi
if [ -z "$UD" ]; then
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
# status --json also answers without a userdir (the interface shows that NetBeans was not found)
[ -n "$UD" ] || [ "$ACTION$JSON" = status1 ] || die "$(t cli.no_userdir)"
[ -z "$UD" ] || [ -d "$UD/config" ] || die "$(t cli.not_userdir "$UD")"
C="$UD/config"
STATEDIR="$UD/nbkit"
CORE_JAR="$UD/modules/nbkit-core.jar"
CORE_XML="$C/Modules/nbkit-core.xml"

# ---------- install / uninstall / check ----------
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
  exec 9>&-                       # the change is done: the lock goes (NetBeans opened here must not keep it)
  if [ $INTERACTIVE != 1 ]; then
    if [ "$1" = install ]; then t cli.check_later "$ME"; else t cli.open_nb; fi
    echo
    exit 0
  fi
  echo
  # waits for NetBeans to check by itself, unless you said not to open it now
  local wait=1
  if find_launcher; then
    if ask_yn "$(t cli.ask_open)" Y; then open_netbeans; else wait=0; fi
  fi
  if [ "$1" = install ] && [ $wait = 0 ]; then t cli.check_later_menu "$(t cli.menu_check)"; echo; exit 0; fi
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
  echo "${R}$(t cli.problems_above)${N}"
  if [ ${#fix[@]} -gt 0 ] && [ $INTERACTIVE = 1 ]; then
    echo
    if ask_yn "$(t cli.ask_reinstall)" Y; then echo; exec env NBKIT_TTY=1 NBKIT_CLOSE=1 bash "$SELF" install "${fix[@]}" "$UD"; fi
  else
    t cli.send_output; echo
  fi
  exit "$worst"
}

# ---------- menu ----------
confirm_uninstall() {
  local id
  for id in "$@"; do
    echo "  ${B}$(mod_label "$id")${N}"
    mod_call "$id" uninstall_summary
  done
  echo
  ask_yn "$(t cli.ask_uninstall)" N
}
# status --json: what the interface shows (userdirs, modules, backups), see lib/gui/model.py
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
  print_status
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
    # by subject: the modules, nbkit itself, development (only in a clone), quit
    if [ ${#current[@]} -gt 0 ]; then opts+=("$(t cli.menu_reinstall)"); acts+=(reinstall); fi
    if [ ${#installed[@]} -gt 0 ]; then opts+=("$(t cli.menu_uninstall)"); acts+=(uninstall); fi
    if can_check; then opts+=("$(t cli.menu_check)"); acts+=(check); fi
    opts+=("$(t cli.menu_analyze)"); acts+=(analyze)
    nbk="$(all_backups | wc -l)"
    if [ "$nbk" -gt 0 ]; then opts+=("$(t cli.menu_backups "$nbk")"); acts+=(backups); fi
    if self_installed; then
      opts+=("$(t cli.menu_update_self)"); acts+=(update-self)
      opts+=("$(t cli.menu_uninstall_self)"); acts+=(uninstall-self)
    else
      opts+=("$(t cli.menu_install_self)"); acts+=(install-self)
    fi
    # the release zip has no tests/
    if [ -f "$NBKIT_DIR/tests/run.sh" ]; then
      opts+=("$(t cli.menu_test)"); acts+=(test)
      opts+=("$(t cli.menu_build)"); acts+=(build)
      if jsf_debug_on; then st="${G}$(jsf_debug_state)${N}"; else st="${D}$(jsf_debug_state)${N}"; fi
      opts+=("$(t cli.menu_debug "$st")"); acts+=(debug)
      opts+=("$(t cli.menu_debug_log)"); acts+=(debug-log)
    fi
    opts+=("$(t cli.menu_quit)"); acts+=(quit)
    # what each option does, below the menu (the same texts as the tooltips of the interface, where they fit)
    MENU_TIPS=()
    for a in "${acts[@]}"; do
      case "$a" in
        install) k=cli.tip_install ;;
        reinstall) k=cli.tip_reinstall ;;
        uninstall) k=cli.tip_uninstall ;;
        quit) k="" ;;
        *) k="gui.tip_${a//-/_}" ;;
      esac
      MENU_TIPS+=("${k:+$(t "$k")}")
    done
    menu "${opts[@]}"
    MENU_TIPS=()
    [ "$MENU_IDX" -lt 0 ] && { echo; exit 0; }
    act="${acts[$MENU_IDX]}"
    MENU_START=$MENU_IDX
    back() { printf '\e[%dA\r\e[J' "${#opts[@]}"; }
    case "$act" in
      quit) echo; exit 0 ;;
      test) echo; echo; exec bash "$NBKIT_DIR/tests/run.sh" ;;
      install-self) echo; echo; install_self; exit 0 ;;
      update-self) echo; echo; update_self; exit 0 ;;
      uninstall-self)
        echo; echo
        if ask_yn "$(t cli.ask_uninstall_self)" N; then uninstall_self; else t cli.nothing_changed; echo; fi
        exit 0 ;;
      build) echo; echo; exec bash "$NBKIT_DIR/src/build.sh" ;;
      check) echo; echo; do_check ;;
      analyze)
        # the projects open in NetBeans first, then any folder (typed, Tab completes)
        mapfile -t projs < <(jsf_projects)
        dir=""
        if [ ${#projs[@]} -gt 0 ]; then
          back
          labels=()
          # name and path in one line of the terminal: a wrapped line would break the redrawing of the menu
          cols=$(tput cols 2>/dev/null || echo 80)
          for p in "${projs[@]}"; do
            name="${p#*$'\t'}"; path="${p%%$'\t'*}"; path="${path/#$HOME/\~}"; room=$(( cols - 10 - ${#name} ))
            if [ ${#path} -gt $room ]; then
              if [ $room -ge 12 ]; then path="…${path: -$(( room - 1 ))}"; else path=""; fi
            fi
            labels+=("${name:0:$(( cols - 7 ))}   ${D}${path}${N}")
          done
          labels+=("$(t cli.analyze_other)")
          echo "  ${B}$(t cli.menu_analyze)${N}"
          MENU_START=0 MENU_HINT="$(t cli.submenu_hint)" menu "${labels[@]}"
          if [ "$MENU_IDX" -lt 0 ]; then printf '\e[%dA\r\e[J' "$(( ${#labels[@]} + 1 ))"; continue; fi
          [ "$MENU_IDX" -lt ${#projs[@]} ] && dir="${projs[$MENU_IDX]%%$'\t'*}"
        fi
        echo; echo
        if [ -z "$dir" ]; then
          read -r -e -p "  $(t cli.analyze_ask): " -i "$PWD/" dir || { echo; exit 0; }
          echo
          dir="${dir/#\~/$HOME}"
        fi
        # with or without the explanation of one file (how each name of its EL was resolved)
        file=""
        if ask_yn "  $(t cli.analyze_explain_ask)" N; then
          read -r -e -p "  $(t cli.analyze_explain_file): " -i "${dir%/}/" file || { echo; exit 0; }
          file="${file/#\~/$HOME}"
        fi
        echo
        rc=0; jsf_analyze "$dir" "$file" || rc=$?
        exit $rc ;;
      debug)
        if jsf_debug_on; then jsf_debug off >/dev/null; else jsf_debug on >/dev/null; fi
        back; continue ;;
      debug-log) echo; echo; jsf_debug log; exit 0 ;;
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
          confirm_uninstall "${PICK[@]}" || { t cli.nothing_changed; echo; exit 0; }
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
  status)
    if [ $JSON = 1 ]; then status_json; else header; userdir_line; print_status; fi ;;
  restore|delete-backup)
    [ -n "$BKF" ] || die "$(t cli.need_backup "$ACTION")"
    row="$(backup_owner "$BKF")" || die "$(t cli.not_a_backup "$BKF")"
    id="${row%%$'\t'*}"; f="${row#*$'\t'}"
    header; userdir_line; echo
    if [ $INTERACTIVE = 1 ]; then
      if [ "$ACTION" = restore ]; then confirm_restore "$id" "$f" || { t cli.nothing_changed; echo; exit 0; }
      else confirm_delete_backup "$id" "$f" || { t cli.nothing_changed; echo; exit 0; }; fi
      echo
    fi
    if [ "$ACTION" = restore ]; then do_restore "$id" "$f"; else rm -f "$f"; ok "$(t cli.backup_deleted)"; fi ;;
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
    # with a terminal to answer (the interface): asks first, like the menu
    if [ $INTERACTIVE = 1 ]; then
      header; userdir_line; echo
      confirm_uninstall "${SEL[@]}" || { t cli.nothing_changed; echo; exit 0; }
      echo
    fi
    do_uninstall "${SEL[@]}" ;;
esac
