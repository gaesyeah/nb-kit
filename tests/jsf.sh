#!/usr/bin/env bash
# Tests the JSF checks: runs the analyzer of src/nbkit-jsf on the sample project in src/nbkit-jsf/test/fixture,
# whose pages mark where each warning must show up, in English and in Portuguese. Needs a JDK 17 or newer.
set -uo pipefail
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
J="$NBKIT_DIR/src/nbkit-jsf"
JAVAC="${JAVA_HOME:+$JAVA_HOME/bin/}javac"; JAR="${JAVA_HOME:+$JAVA_HOME/bin/}jar"; JAVA="${JAVA_HOME:+$JAVA_HOME/bin/}java"
for c in "$JAVAC" "$JAR" "$JAVA"; do
  command -v "$c" >/dev/null 2>&1 || { echo "  skipped: JDK 17 or newer not found (javac, jar, java)"; exit 3; }
done
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
quiet() { "$@" 2>&1 | grep -v '^Picked up JAVA_TOOL_OPTIONS' || true; }
compile() { quiet "$JAVAC" --release 17 -encoding UTF-8 -nowarn "$@"; }
# java_files <folder> [find options]: the .java files under it, one per line
java_files() { find "$@" -name '*.java' | sort; }

echo "JSF checks"
# libraries the sample project uses (Spring and Jakarta annotations, a PrimeFaces component): small stubs
mkdir -p "$W/api" "$W/pf" "$W/app" "$W/nbkit" "$W/run"
mapfile -t src < <(java_files "$J/test/libs/api")
compile -d "$W/api" "${src[@]}"
quiet "$JAR" cf "$W/api.jar" -C "$W/api" .
mapfile -t src < <(java_files "$J/test/libs/primefaces")
compile -cp "$W/api.jar" -d "$W/pf" "${src[@]}"
cp -r "$J/test/libs/primefaces/META-INF" "$W/pf/"
quiet "$JAR" cf "$W/primefaces.jar" -C "$W/pf" .
# the sample project classes, the analyzer (without the NetBeans part in nb/) and the runner
mapfile -t src < <(java_files "$J/test/fixture/src/main/java")
compile -cp "$W/api.jar" -d "$W/app" "${src[@]}"
mapfile -t src < <(java_files "$J/src/nbkit/jsf" -maxdepth 1)
compile -d "$W/nbkit" "${src[@]}"
cp "$J"/res/nbkit/jsf/Bundle*.properties "$W/nbkit/nbkit/jsf/"
compile -cp "$W/nbkit" -d "$W/run" "$J/test/RunFixture.java"
check "analyzer and sample project compile" test -f "$W/run/RunFixture.class"

# fixture-resolver: a project with its own EL resolver, which changes every unknown name of the project
for fx in fixture fixture-resolver; do
  for l in en pt; do
    out="$("$JAVA" -Duser.language=$l -Dstdout.encoding=UTF-8 -cp "$W/nbkit:$W/run" RunFixture \
      "$J/test/$fx" "$W/app" "$W/api.jar" "$W/primefaces.jar" 2>&1 | grep -v '^Picked up JAVA_TOOL_OPTIONS')"
    n="$(grep -c ' ok ' <<<"$out")"
    if [ "$(tail -1 <<<"$out")" = "ALL OK" ]; then pass "$fx: every expected warning, and nothing else ($n checks, language: $l)"
    else fail "$fx: every expected warning, and nothing else (language: $l)" "$(grep -E 'EXTRA|MISSING|DIFFERENCES' <<<"$out")"; fi
    if [ "$fx$l" = fixtureen ]; then
      # where a note or a suggestion points to: "Go to" in NetBeans (Alt+Enter)
      contains "a blue note goes to where the name comes from" "$out" "«kindLabel»  → pages/kinds.xhtml:6"
      contains "a CSS class goes to its rule" "$out" "«panel-title»  → resources/css/app.css:3"
      contains "a suggested name goes to where it is" "$out" "«tablee»  → pages/customers.xhtml:27"
    fi
  done
done

# NetBeans' JSF support (what colors EL): turned on once by the module, then only asked about (see JsfSupportMark)
compile -d "$W/mark" "$J/src/nbkit/jsf/nb/JsfSupportMark.java" "$J/test/RunJsfSupportMark.java"
out="$("$JAVA" -cp "$W/mark" RunJsfSupportMark 2>&1 | grep -v '^Picked up JAVA_TOOL_OPTIONS')"
contains "off and never handled: the module turns it on" "$out" "null active=false noask=false -> ACTIVATE"
contains "already on: it only writes that down" "$out" "null active=true noask=false -> MARK_FOUND"
contains "handled and on: nothing" "$out" "activated active=true noask=false -> NOTHING"
contains "handled and turned off later: it asks, never turns it on by itself" "$out" "found active=false noask=false -> ASK"
contains "after Don't ask again: nothing" "$out" "activated active=false noask=true -> NOTHING"
finish
