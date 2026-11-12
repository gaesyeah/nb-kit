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
    printf '%s\n' "${open[@]}"
    printf '%s\n' "${open[@]}" | sed 's#/[^/]*$##' | sort -u | while IFS= read -r p; do
      find "$p" -mindepth 1 -maxdepth 1 -type d -not -name '.*' | sort
    done
  } | awk '!seen[$0]++' | while IFS= read -r p; do
    if has_xhtml "$p" || [ -n "$(jsf_modules "$p")" ]; then echo "$p"; fi
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
  local dir="$1" mvn="${NBKIT_MVN:-mvn}" out
  [ -f "$dir/pom.xml" ] || return 0
  if ! command -v "$mvn" >/dev/null 2>&1; then warn "$(t cli.analyze_no_maven "$(t cli.analyze_maven_missing)")" >&2; return 0; fi
  info "$(t cli.analyze_maven)" >&2
  out="$(mktemp)"
  if "$mvn" -o -q -f "$dir/pom.xml" dependency:build-classpath -Dmdep.outputFile="$out" >/dev/null 2>&1 \
    || "$mvn" -q -f "$dir/pom.xml" dependency:build-classpath -Dmdep.outputFile="$out" >/dev/null 2>&1; then
    tr ':' '\n' < "$out"
  else
    warn "$(t cli.analyze_no_maven "$(t cli.analyze_maven_failed)")" >&2
  fi
  rm -f "$out"
}

# the analysis of one project, its libraries read from Maven
analyze_one() {
  local cp=() lang=en color=0 rc=0
  mapfile -t cp < <(analyze_classpath "$1")
  echo
  case "$NBKIT_LANG" in pt*) lang=pt ;; esac
  [ -n "$G" ] && color=1
  "$JAVA" -Duser.language=$lang -Dstdout.encoding=UTF-8 -Dnbkit.color=$color -cp "$JAR" nbkit.jsf.Analyze "$1" ${cp[@]+"${cp[@]}"} \
    2> >(grep -v '^Picked up JAVA_TOOL_OPTIONS' >&2) || rc=$?
  return "$rc"
}
# without the compiled classes every bean would be unknown: errors that are not there
not_compiled() { [ -f "$1/pom.xml" ] && [ ! -d "$1/target/classes" ]; }

# jsf_analyze <project folder>: 0 it ran, 2 no xhtml. A folder with no pages of its own (a parent, a monorepo)
# is analyzed module by module
jsf_analyze() {
  local dir="${1:-}" mods=() m rc=0
  [ -n "$dir" ] || die "$(t cli.analyze_usage)"
  [ -d "$dir" ] || die "$(t cli.analyze_no_dir "$dir")"
  dir="$(cd "$dir" && pwd)"
  JAVA="$(analyze_java)" || die "$(t cli.analyze_no_java)"
  JAR="${NBKIT_JSF_JAR:-$NBKIT_DIR/modules/tools/jsf/nbkit-jsf.jar}"
  has_xhtml "$dir" || mapfile -t mods < <(jsf_modules "$dir")
  if [ ${#mods[@]} = 0 ]; then
    if not_compiled "$dir"; then die "$(t cli.analyze_no_classes "${dir/#$HOME/\~}")"; fi
    echo "  ${B}$(t cli.menu_analyze)${N}  ${dir/#$HOME/\~}"
    analyze_one "$dir"; return $?
  fi
  echo "  ${B}$(t cli.menu_analyze)${N}  ${dir/#$HOME/\~}  ${D}$(t cli.analyze_modules "${#mods[@]}")${N}"
  for m in "${mods[@]}"; do
    echo
    echo "  ${BL}${m#"$dir"/}${N}"
    if not_compiled "$m"; then warn "$(t cli.analyze_skip "${m#"$dir"/}")"; rc=1; continue; fi
    analyze_one "$m" || { [ $? = 2 ] || rc=1; }
  done
  return $rc
}
