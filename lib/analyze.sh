# shellcheck shell=bash
# JSF tools outside NetBeans: "nbkit analyze jsf <project>" runs the JSF checks on every xhtml of a project
# (nbkit.jsf.Analyze in the module jar) and "nbkit debug jsf on|off|log" turns on the debug of the checks inside
# NetBeans (the file nb/Watcher.java looks for) and shows its lines. Used by nbkit.sh (CLI, menu and interface).

# the file Watcher.java looks for (System user.home, so $HOME and not XDG_CACHE_HOME)
JSF_DEBUG_FILE="$HOME/.cache/nbkit/jsf-debug"
jsf_debug_on() { [ -e "$JSF_DEBUG_FILE" ]; }
jsf_debug_state() { if jsf_debug_on; then t cli.debug_state_on; else t cli.debug_state_off; fi; }

# jsf_debug on|off|log [userdir] (nothing: the state)
jsf_debug() {
  local d f lines found=0
  case "${1:-}" in
    on) mkdir -p "$(dirname "$JSF_DEBUG_FILE")"; : > "$JSF_DEBUG_FILE"; ok "$(t cli.debug_on)" ;;
    off) rm -f "$JSF_DEBUG_FILE"; ok "$(t cli.debug_off)" ;;
    log)
      for d in ${2:-$(list_userdirs)}; do
        f="$d/var/log/messages.log"
        [ -f "$f" ] || continue
        found=1
        # no debug line is not an error (grep says 1, and set -e would end here)
        lines="$(grep 'nbkit JSF debug' "$f" | tail -n 60 || true)"
        echo "  ${B}${f/#$HOME/\~}${N}"
        if [ -n "$lines" ]; then echo "$lines"; else info "$(t cli.debug_log_none)"; fi
        echo
      done
      [ $found = 1 ] || info "$(t cli.debug_log_none)"
      jsf_debug_on || warn "$(t cli.debug_off_now)" ;;
    '') t cli.menu_debug "$(jsf_debug_state)"; echo ;;
    *) die "$(t cli.debug_usage)" ;;
  esac
}

# the web folders where JSF pages live (the same as Workspace.webrootsOf): does this project have xhtml pages?
has_xhtml() {
  [ -n "$(find "$1/src/main/webapp" "$1/src/main/resources/META-INF/resources" "$1/src/main/resources/static" \
    "$1/web" "$1/WebContent" "$1/WebRoot" -name '*.xhtml' -print -quit 2>/dev/null)" ]
}
# the modules of a multi-module project (a monorepo) that have xhtml pages, one per line
jsf_modules() {
  local m
  find "$1" -mindepth 2 -maxdepth 4 \( -name target -o -name node_modules -o -name '.*' \) -prune -o \
    \( -name pom.xml -o -name build.gradle -o -name build.gradle.kts \) -print 2>/dev/null | sed 's#/[^/]*$##' | sort -u \
    | while IFS= read -r m; do if has_xhtml "$m"; then echo "$m"; fi; done
  return 0
}
# a monorepo parent: a build file of its own, or a modules/ folder, with JSF modules under it. A folder that only
# has a project somewhere deep inside (a repo inside it) is not a parent
jsf_parent() {
  if [ -f "$1/pom.xml" ] || [ -f "$1/build.gradle" ] || [ -f "$1/build.gradle.kts" ]; then
    [ -n "$(jsf_modules "$1")" ] && return 0
  fi
  [ -d "$1/modules" ] && [ -n "$(jsf_modules "$1/modules")" ]
}
# path<TAB>name for each path read: the name NetBeans shows (the <name> of the pom, else its artifactId), else the folder
project_names() {
  "$NBKIT_PY" -c '
import sys, os, xml.etree.ElementTree as ET
for p in sys.stdin.read().splitlines():
    name = os.path.basename(p)
    try:
        tags = {c.tag.split("}")[-1]: (c.text or "").strip() for c in ET.parse(os.path.join(p, "pom.xml")).getroot()}
        name = tags.get("name") or tags.get("artifactId") or name
    except (OSError, ET.ParseError):
        pass
    print(p + "\t" + name)
'
}
# the JSF projects (pages in them or in their modules) to offer first, path<TAB>name: the ones open in NetBeans
# (this userdir, in its order), then the other projects in the folders they are in (NetBeansProjects...)
jsf_projects() {
  local f="${UD:-}/config/Preferences/org/netbeans/modules/projectui.properties" p open=()
  [ -n "${UD:-}" ] && [ -f "$f" ] || return 0
  while IFS= read -r p; do
    p="$(printf '%b' "${p//%/\\x}")"; p="${p%/}"
    if [ -d "$p" ]; then open+=("$p"); fi
  done < <(sed -n 's/^openProjectsURLs\.\([0-9]*\)=file:/\1\t/p' "$f" | sort -n | cut -f2-)
  [ ${#open[@]} -gt 0 ] || return 0
  {
    printf 'open\t%s\n' "${open[@]}"
    printf '%s\n' "${open[@]}" | sed 's#/[^/]*$##' | sort -u | while IFS= read -r p; do
      find "$p" -mindepth 1 -maxdepth 1 -type d -not -name '.*' | sort | sed 's/^/sibling\t/'
    done
  } | awk -F'\t' '!seen[$2]++' | while IFS=$'\t' read -r kind p; do
    if [ "$kind" = open ]; then
      if has_xhtml "$p" || [ -n "$(jsf_modules "$p")" ]; then echo "$p"; fi
    elif has_xhtml "$p" || jsf_parent "$p"; then echo "$p"; fi
  done | project_names
  return 0
}

# a java of version 17 or newer (the module jar is built with --release 17): JAVA_HOME, PATH, /usr/lib/jvm
analyze_java() {
  local j v
  for j in ${JAVA_HOME:+"$JAVA_HOME/bin/java"} "$(command -v java 2>/dev/null)" /usr/lib/jvm/*/bin/java; do
    [ -n "$j" ] && [ -x "$j" ] || continue
    v="$("$j" -XshowSettings:properties -version 2>&1 | sed -n 's/^ *java.specification.version = //p')"
    v="${v#1.}"
    if [ -n "$v" ] && [ "${v%%.*}" -ge 17 ] 2>/dev/null; then echo "$j"; return 0; fi
  done
  return 1
}

# the libraries of a Maven project, one per line (Maven itself prints nothing; offline first, it is faster)
# shortcut: one pom only (a multi-module parent gives the classpath of its last module), enough for one web project
analyze_classpath() {
  local dir="$1" mvn="${NBKIT_MVN:-mvn}" out maven_pid
  [ -f "$dir/pom.xml" ] || return 0
  if ! command -v "$mvn" >/dev/null 2>&1; then warn "$(t cli.analyze_no_maven "$(t cli.analyze_maven_missing)")" >&2; return 0; fi
  out="$(mktemp)"
  (
    "$mvn" -o -q -f "$dir/pom.xml" dependency:build-classpath -Dmdep.outputFile="$out" >/dev/null 2>&1 \
      || "$mvn" -q -f "$dir/pom.xml" dependency:build-classpath -Dmdep.outputFile="$out" >/dev/null 2>&1
  ) &
  maven_pid=$!
  analyze_maven_finished() { ! kill -0 "$maven_pid" 2>/dev/null; }
  spin_until "$(t cli.analyze_maven)" analyze_maven_finished "" no yes >&2
  if wait "$maven_pid"; then
    tr ':' '\n' < "$out"
  else
    warn "$(t cli.analyze_no_maven "$(t cli.analyze_maven_failed)")" >&2
  fi
  unset -f analyze_maven_finished
  rm -f "$out"
}

# the analysis of one project, its libraries read from Maven
analyze_one() {
  local cp=() lang=en color=0 rc=0
  mapfile -t cp < <(analyze_classpath "$1")
  echo
  case "$NBKIT_LANG" in pt*) lang=pt ;; esac
  [ -n "$G" ] && color=1
  "$JAVA" -Duser.language=$lang -Dstdout.encoding=UTF-8 -Dnbkit.color=$color ${EXPLAIN:+"-Dnbkit.explain=$EXPLAIN"} \
    ${NBKIT_COLLECTION:+"-Dnbkit.collection.file=$NBKIT_COLLECTION"} ${REPORT:+"-Dnbkit.report=$REPORT"} \
    -cp "$JAR" nbkit.jsf.Analyze "$1" ${cp[@]+"${cp[@]}"} \
    2> >(grep -v '^Picked up JAVA_TOOL_OPTIONS' >&2) || rc=$?
  return "$rc"
}
# ---------- the comparison with NetBeans (what the JSF module collects in NetBeans, nb/Collector) ----------
# the userdir with the JSF module (UD and CORE_JAR, for opening and closing NetBeans); none: 1
collection_ud() {
  local d
  for d in $(list_userdirs); do
    if [ -e "$d/modules/nbkit-jsf.jar" ]; then UD="$d"; CORE_JAR="$UD/modules/nbkit-core.jar"; return 0; fi
  done
  return 1
}
# the collection of a project: "missing", or "ok|stale <date>" and then one change per line (Analyze -Dnbkit.collection.check)
collection_check() {
  local nbv=""
  # a userdir without its log (copied, or never started) must not stop the check: no version, the rest still counts
  if collection_ud; then nbv="$(sed -n 's/^ *Product Version *= *//p' "$UD/var/log/messages.log" 2>/dev/null | tail -1 | sed 's/ *(.*//' || true)"; fi
  "$JAVA" -Dnbkit.collection.check=1 ${NBKIT_COLLECTION:+"-Dnbkit.collection.file=$NBKIT_COLLECTION"} ${nbv:+"-Dnbkit.netbeans=$nbv"} \
    -cp "$JAR" nbkit.jsf.Analyze "$1" 2> >(grep -v '^Picked up JAVA_TOOL_OPTIONS' >&2)
}
# the date of the collection (ISO, UTC) in the reader's local time, in the language's format (cli.date_format)
collect_date() {
  local f="${L[cli.date_format]}" d y mo dy h mi
  d="$(date -d "$1" '+%Y %m %d %H %M' 2>/dev/null)" || { echo "$1"; return; }
  read -r y mo dy h mi <<<"$d"
  f="${f//\{year\}/$y}"; f="${f//\{month\}/$mo}"; f="${f//\{day\}/$dy}"
  f="${f//\{hour\}/$h}"; f="${f//\{minute\}/$mi}"
  echo "$f"
}
# up to 5 names, then "... and N more"
few() {
  local n=$# out
  out="$(printf '%s, ' "${@:1:5}")"; out="${out%, }"
  if [ "$n" -gt 5 ]; then out="$out $(t cli.and_more $((n - 5)))"; fi
  printf '%s' "$out"
}
# what changed since the collection, a line per kind (the lines of collection_check after the first)
collection_changes() {
  local l nb="" changed=() new=() removed=() classes=() moved=() a b c n f folder=""
  for l in "$@"; do
    case "$l" in
      netbeans\ *) nb="${l#netbeans }" ;;
      changed\ *) changed+=("${l#changed }") ;;
      new\ *) new+=("${l#new }") ;;
      removed\ *) removed+=("${l#removed }") ;;
      classes\ *) classes+=("${l#classes }") ;;
      moved\ *)
        l="${l#moved }"; a="${l%%$'\t'*}"; b="${l#*$'\t'}"; moved+=("$a -> $b")
        # the folders that differ: both paths without the names they end with in common, keeping the topmost of
        # those folders (resources/ -> META-INF/resources/ reads better than webapp/ -> webapp/META-INF/)
        f="$a -> $b"; c=""; n=0
        while [ "${a##*/}" = "${b##*/}" ] && [[ $a == */* && $b == */* ]]; do c="${a##*/}"; a="${a%/*}"; b="${b%/*}"; n=$((n + 1)); done
        if [ $n = 1 ]; then f="$a/ -> $b/"; elif [ $n -gt 1 ]; then f="$a/$c/ -> $b/$c/"; fi
        if [ -z "$folder" ] && [ "$f" != "${moved[-1]}" ]; then folder="$f"; elif [ "$folder" != "$f" ]; then folder="-"; fi ;;
    esac
  done
  if [ -n "$nb" ]; then echo "      $(t cli.collect_change_netbeans "${nb% *}" "${nb#* }")"; fi
  if [ ${#changed[@]} -gt 0 ]; then echo "      $(t cli.collect_change_changed ${#changed[@]} "$(few "${changed[@]}")")"; fi
  if [ ${#new[@]} -gt 0 ]; then echo "      $(t cli.collect_change_new ${#new[@]} "$(few "${new[@]}")")"; fi
  if [ ${#removed[@]} -gt 0 ]; then echo "      $(t cli.collect_change_removed ${#removed[@]} "$(few "${removed[@]}")")"; fi
  # all moved from one folder to another: that folder once; otherwise each page, from -> to
  if [ ${#moved[@]} -gt 0 ] && [ "$folder" != "-" ]; then echo "      $(t cli.collect_change_folder ${#moved[@]} "${folder% -> *}" "${folder#* -> }")"
  elif [ ${#moved[@]} -gt 0 ]; then echo "      $(t cli.collect_change_moved ${#moved[@]} "$(few "${moved[@]}")")"; fi
  if [ ${#classes[@]} -gt 0 ]; then echo "      $(t cli.collect_change_classes ${#classes[@]} "$(few "${classes[@]}")")"; fi
  return 0
}
# before analyzing: the projects (one, or the modules of a parent) whose collection is missing or out of date. Menu
# and interface: asks once for all of them, listing each and what changed; --netbeans: collects without asking;
# otherwise (arguments) only warns. A project not collected again is compared with its old collection all the same,
# saying it may be out of date
netbeans_collections() {
  local d lines=() ask=0 need=() label det=""
  declare -A st=() date=() changes=()
  # an analyze stopped in the middle of a no-window collection left NetBeans' project list pending
  if collection_ud; then projects_pending; fi
  for d in "$@"; do
    mapfile -t lines < <(collection_check "$d")
    [ "${lines[0]%% *}" = ok ] && continue
    need+=("$d"); st[$d]="${lines[0]%% *}"; date[$d]="${lines[0]#* }"
    if [ "${st[$d]}" = stale ]; then date[$d]="$(collect_date "${date[$d]}")"; fi
    changes[$d]="$(collection_changes "${lines[@]:1}")"
  done
  [ ${#need[@]} -gt 0 ] || return 0
  { [ "${MENU:-0}" = 1 ] || [ "${NBKIT_TTY:-}" = 1 ]; } && ask=1
  local go=0
  if [ "${NBKIT_NETBEANS:-}" = 1 ]; then
    go=1
  elif [ $ask = 1 ] && collection_ud; then
    echo
    if [ $# = 1 ]; then
      det="${changes[${need[0]}]}"
      if [ -n "$det" ]; then echo "$det"; fi
      if [ "${st[${need[0]}]}" = missing ]; then label="$(t cli.collect_ask_missing)"; else label="$(t cli.collect_ask_stale "${date[${need[0]}]}")"; fi
    else
      det=""
      for d in "${need[@]}"; do
        if [ "${st[$d]}" = missing ]; then
          det+="    $(t cli.collect_module_missing "${d##*/}")"$'\n'
        else
          det+="    $(t cli.collect_module_stale "${d##*/}" "${date[$d]}")"$'\n'
          if [ -n "${changes[$d]}" ]; then det+="${changes[$d]}"$'\n'; fi
        fi
      done
      printf '%s' "$det"
      label="$(t cli.collect_ask_modules "${#need[@]}")"
    fi
    if nb_running; then label="$label $(t cli.collect_nb_open)"
    else label="$label $(t cli.collect_nb_closed)"; fi
    ask_yn "  $label" N "${det%$'\n'}" && go=1
  fi
  COLLECTED=()
  if [ $go = 1 ]; then collect_all $ask "${need[@]}"; fi
  for d in "${need[@]}"; do
    [[ " ${COLLECTED[*]} " == *" $d "* ]] && continue
    [ $# -gt 1 ] && echo "  ${d##*/}"
    if [ "${st[$d]}" = missing ]; then info "$(t cli.collect_missing)"; continue; fi
    warn "$(t cli.collect_stale "${date[$d]}")"
    [ -n "${changes[$d]}" ] && echo "${changes[$d]}"
  done
  return 0
}
# how far the collection of COLLECTING got, from the line the JSF module rewrites before each page:
# "Collecting 120/631 pages, 85 marks (project): page"
collect_progress() {
  local progress="$HOME/.cache/nbkit/collect-progress" pages_done total marks page
  [ -r "$progress" ] || return 0
  IFS=$'\t' read -r pages_done total marks page 2>/dev/null < "$progress" || return 0
  if [ -n "$total" ]; then t cli.collect_progress "$pages_done" "$total" "$marks" "${COLLECTING##*/}" "$page"; fi
}
collect_ended() { [ -f "$HOME/.cache/nbkit/collect-done" ] || [ "$(date +%s)" -ge "$COLLECT_UNTIL" ]; }
# NetBeans' open and recent projects (the no-window NetBeans would add the project it opens to them): kept before it
# starts, put back byte for byte once it is gone. The copy (or .none: there was no list) stays pending until then,
# so an analyze stopped in the middle puts it back the next time
PROJECTUI=config/Preferences/org/netbeans/modules/projectui.properties
projects_keep() {
  local c="$HOME/.cache/nbkit"
  mkdir -p "$c"
  rm -f "$c/collect-projectui.pid"
  if [ -f "$UD/$PROJECTUI" ]; then cp -p "$UD/$PROJECTUI" "$c/collect-projectui.properties"; else : > "$c/collect-projectui.none"; fi
}
# the pids of the no-window NetBeans, with the copy: a next analyze tells whether it still runs
projects_pid() { nb_pids > "$HOME/.cache/nbkit/collect-projectui.pid"; }
projects_forget() { rm -f "$HOME/.cache/nbkit/collect-projectui".{properties,none,pid}; }
# a copy left by an analyze stopped with no chance to clean up (kill -9). Its no-window NetBeans still running: close
# it and put the list back. Gone: NetBeans may have been used since, so never in silence: the menu and the interface
# ask (no: the copy is forgotten); with arguments it stays pending and one line says so
projects_pending() {
  local c="$HOME/.cache/nbkit/collect-projectui" p
  [ -e "$c.properties" ] || [ -e "$c.none" ] || return 0
  for p in $(cat "$c.pid" 2>/dev/null); do
    if tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q 'org.netbeans.Main'; then
      info "$(t cli.collect_left_running)"
      close_nowindow; projects_restore; return 0
    fi
  done
  if [ "${MENU:-0}" = 1 ] || [ "${NBKIT_TTY:-}" = 1 ]; then
    if ask_yn "  $(t cli.collect_restore_ask)" N "$(t cli.collect_restore_detail)"; then projects_restore; else projects_forget; fi
  else
    warn "$(t cli.collect_restore_skipped)"
  fi
}
# the analyze ends in the middle of a no-window collection (Ctrl+C, kill, the terminal closed): through on_exit
nowindow_abort() { close_nowindow; projects_restore; }
# only once NetBeans is gone and its lock with it: it writes the list while it exits
projects_free() { nb_closed && [ ! -e "$UD/lock" ]; }
projects_restore() {
  local c="$HOME/.cache/nbkit" i
  [ -e "$c/collect-projectui.properties" ] || [ -e "$c/collect-projectui.none" ] || return 0
  for ((i = 0; i < 60; i++)); do projects_free && break; sleep 0.5; done
  projects_free || return 0
  if [ -e "$c/collect-projectui.properties" ]; then
    mkdir -p "$(dirname "$UD/$PROJECTUI")" && cp -p "$c/collect-projectui.properties" "$UD/$PROJECTUI" && projects_forget
  else
    rm -f "$UD/$PROJECTUI"; projects_forget
  fi
}
# opens NetBeans once if it is closed, asks the JSF module to collect each project in turn, waiting for each
# (NBKIT_COLLECT_TIMEOUT seconds, 600), and closes NetBeans once at the end if it opened it (asking, when someone can
# answer). COLLECTED: the projects collected
collect_all() {
  local ask="$1" opened=0 nowindow=0 c="$HOME/.cache/nbkit" limit="${NBKIT_COLLECT_TIMEOUT:-600}" d det; shift
  collection_ud || { warn "$(t cli.collect_no_module)"; return 1; }
  if nb_running; then
    # with the same userdir a second NetBeans cannot start: the open one collects
    if [ "${NBKIT_NB_MODE:-auto}" = nowindow ]; then info "$(t cli.collect_nb_open_used)"; fi
  else
    find_launcher || { warn "$(t cli.collect_no_launcher)"; return 1; }
    # closed: with no window (it closes by itself at the end), unless --netbeans=window
    if [ "${NBKIT_NB_MODE:-auto}" = window ]; then open_netbeans
    else projects_keep; EXIT_HOOK=nowindow_abort; open_netbeans --nosplash --nogui -J-Djava.awt.headless=true; nowindow=1; fi
    opened=1
    if ! { spin_until "$(t cli.waiting_open)" nb_running "" yes yes && spin_until "$(t cli.waiting_modules)" nb_loaded "" yes yes; }; then
      if [ $nowindow = 1 ]; then close_nowindow; projects_restore; EXIT_HOOK=""; fi
      return 1
    fi
    if [ $nowindow = 1 ]; then projects_pid; fi
    if [ $nowindow = 1 ]; then info "$(t cli.collect_nowindow)"; fi
  fi
  mkdir -p "$c"
  for d in "$@"; do
    rm -f "$c/collect-done" "$c/collect-progress"; printf '%s\n' "$d" > "$c/collect-request"
    COLLECT_UNTIL=$(( $(date +%s) + limit )); COLLECTING="$d"
    # a key cancels the wait: the rest is not collected
    spin_until "$(t cli.collect_waiting) (${d##*/})" collect_ended collect_progress || { info "$(t cli.cancelled)"; break; }
    if [ -f "$c/collect-done" ]; then ok "$(t cli.collect_done)"; COLLECTED+=("$d"); else warn "$(t cli.collect_timeout "$limit")"; break; fi
  done
  if [ $nowindow = 1 ]; then close_nowindow; projects_restore; EXIT_HOOK=""
  elif [ $opened = 1 ]; then
    if [ "$ask" = 0 ]; then close_netbeans
    else
      det="$(t cli.collect_ask_close_detail)"
      info "$det"
      if ask_yn "  $(t cli.collect_ask_close)" N "$det"; then close_netbeans; fi
    fi
  fi
  return 0
}

# without the compiled classes every bean would be unknown: errors that are not there
not_compiled() { [ -f "$1/pom.xml" ] && [ ! -d "$1/target/classes" ]; }

# jsf_analyze <project folder> [file]: 0 it ran, 2 no xhtml. A folder with no pages of its own (a parent, a monorepo)
# is analyzed module by module. With a file, only that file (in its own project, found from it), also saying how each
# name of its EL was resolved
jsf_analyze() {
  local dir="${1:-}" mods=() m rc=0 REPORT=""
  EXPLAIN="${2:-}"
  # with a file, its own project (the nearest folder above it with a pom.xml or a build.gradle): the module, in a monorepo
  # (with a project given, the file may also be the end of its path: pages/x.xhtml)
  if [ -f "$EXPLAIN" ]; then
    EXPLAIN="$(cd "$(dirname "$EXPLAIN")" && pwd)/${EXPLAIN##*/}"
    dir="$(dirname "$EXPLAIN")"
    while [ "$dir" != / ] && [ ! -f "$dir/pom.xml" ] && [ ! -f "$dir/build.gradle" ] && [ ! -f "$dir/build.gradle.kts" ]; do dir="$(dirname "$dir")"; done
    [ "$dir" != / ] || die "$(t cli.analyze_no_project "${EXPLAIN/#$HOME/\~}")"
  elif [ -n "$EXPLAIN" ] && [ -z "$dir" ]; then
    die "$(t cli.analyze_no_dir "$EXPLAIN")"
  fi
  [ -n "$dir" ] || die "$(t cli.analyze_usage)"
  [ -d "$dir" ] || die "$(t cli.analyze_no_dir "$dir")"
  dir="$(cd "$dir" && pwd)"
  JAVA="$(analyze_java)" || die "$(t cli.analyze_no_java)"
  JAR="${NBKIT_JSF_JAR:-$NBKIT_DIR/modules/tools/jsf/nbkit-jsf.jar}"
  has_xhtml "$dir" || mapfile -t mods < <(jsf_modules "$dir")
  if [ ${#mods[@]} = 0 ]; then
    if not_compiled "$dir"; then die "$(t cli.analyze_no_classes "${dir/#$HOME/\~}")"; fi
    echo "  ${B}$(t cli.menu_analyze)${N}  ${dir/#$HOME/\~}"
    netbeans_collections "$dir"
    report_start "$dir"
    analyze_one "$dir" || rc=$?
    # nothing analyzed (no such file for --explain): no report
    if [ $rc = 2 ]; then rm -f "$REPORT"; else report_end; fi
    return $rc
  fi
  echo "  ${B}$(t cli.menu_analyze)${N}  ${dir/#$HOME/\~}  ${D}$(t cli.analyze_modules "${#mods[@]}")${N}"
  # the collection of what NetBeans marks: all the modules together (one question, NetBeans opened once)
  local compiled=()
  for m in "${mods[@]}"; do not_compiled "$m" || compiled+=("$m"); done
  [ ${#compiled[@]} -gt 0 ] && netbeans_collections "${compiled[@]}"
  report_start "$dir"
  for m in "${mods[@]}"; do
    echo
    echo "  ${BL}${m#"$dir"/}${N}"
    printf '\n%s\n' "${m#"$dir"/}" >> "$REPORT"
    if not_compiled "$m"; then warn "$(t cli.analyze_skip "${m#"$dir"/}")"; rc=1; continue; fi
    analyze_one "$m" || { [ $? = 2 ] || rc=1; }
  done
  report_end
  return $rc
}

# the report: the whole output of the analysis (Analyze -Dnbkit.report, the lists the terminal cuts in full), in
# REPORT under the cache, named after the project (and the page, with --explain) and the time
report_start() {
  local d="${XDG_CACHE_HOME:-$HOME/.cache}/nbkit/analyze" page=""
  [ -n "$EXPLAIN" ] && page="-$(basename "$EXPLAIN" .xhtml)"
  mkdir -p "$d"
  REPORT="$d/${1##*/}$page-$(date +%Y-%m-%d-%H%M%S).txt"
  echo "nbkit analyze jsf $1${EXPLAIN:+ --explain $EXPLAIN}  ($(date '+%Y-%m-%d %H:%M'))" > "$REPORT"
  # only the 10 newest of this project (--explain ones too), told by their first line, not by the name: another
  # project's name may start the same
  local f n=0
  while IFS= read -r f; do
    case "$(head -1 "$f" 2>/dev/null)" in
      "nbkit analyze jsf $1  ("*|"nbkit analyze jsf $1 --explain "*) n=$((n + 1)); [ $n -le 10 ] || rm -f "$f" ;;
    esac
  done < <(ls -t "$d"/*.txt 2>/dev/null)
}
# at the end, a green line with where the report is; the menu and the interface ask whether to open it (Enter opens)
report_end() {
  local shown="${REPORT/#$HOME/\~}"
  sed -i 's/\x1b\[[0-9;]*m//g' "$REPORT"
  echo
  if { [ "${MENU:-0}" = 1 ] || [ "${NBKIT_TTY:-}" = 1 ]; } && command -v xdg-open >/dev/null 2>&1; then
    if ask_yn "  ${G}$(t cli.analyze_report_open "$shown")${N}" Y; then setsid -f xdg-open "$REPORT" >/dev/null 2>&1; fi
  else
    echo "  ${G}$(t cli.analyze_report "$shown")${N}"
  fi
}
