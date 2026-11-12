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
      contains "a variable used outside its loop goes to the loop" "$out" "«row»  → pages/customers.xhtml:27"
      contains "a repeated id goes to the first one" "$out" "«dup»  → pages/customers.xhtml:36"
      contains "an id repeated by c:forEach goes to the c:forEach" "$out" "«repeated»  → pages/customers.xhtml:35"
      contains "an update of a component with rendered goes to it" "$out" "«panel»  → pages/customers.xhtml:17"
      contains "a bundle from an included file goes to its f:loadBundle" "$out" "«tips»  → pages/bundled-part.xhtml:2"
      # in the Java source: the member, the getter whose setter is missing, the enum constant suggested
      contains "a method used as a property goes to the method" "$out" "«save»  → ../java/app/CustomerVM.java:10"
      contains "a property with no setter goes to its getter" "$out" "«code»  → ../java/app/Customer.java:6"
      contains "an interface property with no setter goes to the interface" "$out" "«note»  → ../java/app/Contact.java:8"
      contains "a misspelled member goes to the one suggested" "$out" "«titl»  → ../java/app/CustomerVM.java:12  ⇒ title"
      contains "a misspelled enum constant goes to the enum" "$out" "«'ACTIVEE'»  → ../java/app/Status.java:2  ⇒ 'ACTIVE'"
      # "Replace with": exactly the marked text becomes the suggestion
      contains "a misspelled bean is replaced by the close one" "$out" "«customerVn»  ⇒ customerVM"
      contains "a misspelled id is replaced, keeping where it is" "$out" "«tablee»  → pages/customers.xhtml:27  ⇒ table"
      contains "a misspelled keyword keeps its @" "$out" "«@from»  ⇒ @form"
      contains "a misspelled ajax event is replaced" "$out" "«rowSelecte»  ⇒ rowSelect"
      contains "a misspelled ui:define name is replaced" "$out" "«footerr»  → WEB-INF/templates/main.xhtml:9  ⇒ footer"
      contains "a misspelled cc.attrs name is replaced" "$out" "«labell»  → resources/comp/field.xhtml:3  ⇒ label"
      contains "a misspelled CSS class is replaced" "$out" "«buton-row»  → resources/css/app.css:4  ⇒ button-row"
    fi
  done
done

# nbkit analyze jsf <project>: the same checks without NetBeans, on a compiled copy of the sample project
quiet "$JAR" cf "$W/nbkit-jsf.jar" -C "$W/nbkit" .
cp -r "$J/test/fixture" "$W/proj"
mkdir -p "$W/proj/target" && cp -r "$W/app" "$W/proj/target/classes"
# no Maven here (NBKIT_MVN=false): the libraries go in by hand, as Maven would give them
analyze() { NBKIT_JSF_JAR="$W/nbkit-jsf.jar" NBKIT_MVN=false bash "$NBKIT_DIR/nbkit.sh" --lang en analyze jsf "$@" </dev/null 2>&1; }
out="$(analyze "$W/proj")"; rc=$?
check "analyze exits with 0 when it ran" test "$rc" = 0
contains "analyze lists a problem by file, line and column" "$out" "src/main/webapp/pages/orders.xhtml"
contains "analyze gives the message and the rule" "$out" "Property 'numbr' does not exist in OrderPagination. Did you mean 'number'?  [el.member]"
contains "analyze says what Replace with writes" "$out" "Replace with number"
contains "analyze says where Go to goes" "$out" "Go to src/main/java/app/OrderPagination.java:4"
contains "analyze says Maven was not used" "$out" "Without the libraries of the project"
contains "analyze ends with a summary" "$out" "xhtml files,"
rm -rf "$W/proj/target"
out="$(analyze "$W/proj")"; rc=$?
check "analyze refuses a Maven project not compiled" test "$rc" = 1
contains "and says to compile it" "$out" "compile the project first (mvn compile)"
out="$(analyze "$W/nowhere")"; rc=$?
check "analyze refuses a folder that does not exist" test "$rc" = 1
# a monorepo: a parent with no pages of its own, a module with them and one not compiled
mkdir -p "$W/mono/lib" && printf '<project/>' > "$W/mono/pom.xml" && printf '<project/>' > "$W/mono/lib/pom.xml"
cp -r "$J/test/fixture" "$W/mono/site" && mkdir -p "$W/mono/site/target" && cp -r "$W/app" "$W/mono/site/target/classes"
cp -r "$J/test/fixture" "$W/mono/admin"
out="$(analyze "$W/mono")"; rc=$?
contains "a parent is analyzed module by module, only those with JSF pages" "$out" "2 modules with JSF pages"
contains "each module under its name" "$out" "site"
contains "with its own problems" "$out" "Property 'numbr' does not exist in OrderPagination"
contains "a module not compiled is left out, saying so" "$out" "admin is not compiled (no target/classes): skipped"
check "and then the exit code says something was left out" test "$rc" = 1
mkdir -p "$W/empty"
out="$(analyze "$W/empty")"; rc=$?
check "analyze exits with 2 when there is no xhtml" test "$rc" = 2
contains "and says where it looked" "$out" "No xhtml file in the web folders"

# NetBeans' JSF support (what colors EL): turned on once by the module, then only asked about (see JsfSupportMark)
compile -d "$W/mark" "$J/src/nbkit/jsf/nb/JsfSupportMark.java" "$J/test/RunJsfSupportMark.java"
out="$("$JAVA" -cp "$W/mark" RunJsfSupportMark 2>&1 | grep -v '^Picked up JAVA_TOOL_OPTIONS')"
contains "off and never handled: the module turns it on" "$out" "null active=false noask=false -> ACTIVATE"
contains "already on: it only writes that down" "$out" "null active=true noask=false -> MARK_FOUND"
contains "handled and on: nothing" "$out" "activated active=true noask=false -> NOTHING"
contains "handled and turned off later: it asks, never turns it on by itself" "$out" "found active=false noask=false -> ASK"
contains "after Don't ask again: nothing" "$out" "activated active=false noask=true -> NOTHING"
finish
