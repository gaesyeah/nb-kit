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
# the analyze reports in a cache of the test, not in the real home
export XDG_CACHE_HOME="$W/cache"
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
# a library the sample project is built with but that the checks are not given ("class not in the classpath")
mapfile -t src < <(java_files "$J/test/libs/outside")
compile -d "$W/outside" "${src[@]}"
mapfile -t src < <(java_files "$J/test/fixture/src/main/java")
compile -cp "$W/api.jar:$W/outside" -d "$W/app" "${src[@]}"
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
      contains "a converter goes to its class" "$out" "«app.convert.PhoneConverter»  → ../java/app/convert/PhoneConverter.java:7"
      contains "a missing converter id suggests the closest and goes to its class" "$out" "«app.convert.PhoneConvertr»  → ../java/app/convert/PhoneConverter.java:7  ⇒ app.convert.PhoneConverter"
      contains "a missing validator id suggests the closest and goes to its class" "$out" "«app.cfp»  → ../java/app/convert/CpfValidator.java:7  ⇒ app.cpf"
      contains "a CSS class goes to its rule" "$out" "«panel-title»  → resources/css/app.css:3"
      contains "a suggested name goes to where it is" "$out" "«tablee»  → pages/customers.xhtml:27"
      contains "a variable used outside its loop goes to the loop" "$out" "«row»  → pages/customers.xhtml:27"
      contains "a use of that ui:param where the variable does not exist goes to the ui:param" "$out" "'row' (in the ui:param 'archivable' on line 4) only exists inside the h:dataTable on line 7.  «archivable»  → pages/deferred.xhtml:4"
      contains "a file included uses a ui:param of the includer: where it comes from, going to it" "$out" "'archivable' comes from pages/deferred.xhtml, line 4 (ui:param).  «archivable»  → pages/deferred.xhtml:4"
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
      contains "a misspelled resource goes to the file, written as the page writes it" "$out" "«css:ap.css»  → resources/css/app.css:1  ⇒ css:app.css"
      contains "with its library apart, only the name is replaced" "$out" "«aps.css»  → resources/css/app.css:1  ⇒ app.css"
      contains "with no library, the whole path is replaced" "$out" "«css/app.cs»  → resources/css/app.css:1  ⇒ css/app.css"
      contains "a misspelled library goes to the file, with nothing to replace in name" "$out" "«app.css»  → resources/css/app.css:1"
      lacks "(not replaced: the library is another attribute)" "$out" "«app.css»  → resources/css/app.css:1  ⇒"
      contains "a resource with nothing close has no suggestion" "$out" "«css:gone.css»"
      contains "an existing resource goes to its file (blue note)" "$out" "«css:app.css»  → resources/css/app.css:1"
      contains "a ui:param gets the type of its value" "$out" "«totl»  → ../java/app/Order.java:4  ⇒ total"
      contains "a misspelled varStatus property is replaced" "$out" "«indx»  ⇒ index"
      contains "also the LoopTagStatus of c:forEach" "$out" "«cuont»  ⇒ count"
      contains "a method of a text literal is checked as String" "$out" "«concatt»  ⇒ concat"
      contains "a method called with the wrong number of arguments says how many it takes, and goes to it" "$out" \
        "The method 'format' of CustomerVM takes 1 argument, not 2.  «format»  → ../java/app/CustomerVM.java:14"
      contains "with overloads, every number it takes" "$out" "The method 'pick' of CustomerVM takes 1 or 3 arguments, not 2."
      # a fixed key of a bundle: in every .properties, in none, or only in some
      contains "a bundle key goes to where it is" "$out" "«save»  → ../resources/messages.properties:2"
      contains "a key in no file of the bundle is an error, with the close one" "$out" "The key 'savee' is in no file of the bundle messages. Did you mean 'save'"
      contains "and Trocar por" "$out" "«savee»  → ../resources/messages.properties:2  ⇒ save"
      contains "a key only in some files says which ones lack it" "$out" "The key 'onlyBase' of the bundle messages is not in messages_pt.properties."
      contains "a class picked by EL among fixed texts is checked, each in its place" "$out" "«panel-titl»  → resources/css/app.css:3  ⇒ panel-title"
      contains "a class the project's JavaScript uses says where, and goes there" "$out" "«js-hook»  → resources/js/app.js:1"
      contains "also from classList with more than one class" "$out" "«second-arg»  → resources/js/app.js:3"
      contains "and from a script inside a page" "$out" "«inline-hook»  → pages/scripted.xhtml:7"
      contains "a class of a jar's CSS says which jar" "$out" "'ui-widget' comes from primefaces/theme.css in primefaces.jar."
      contains "a class in no CSS and no JavaScript is a warning" "$out" "The class 'nowhere-at-all' has no CSS rule and is not used by the project's JavaScript."
      contains "an outcome returned by an action method is checked, and goes to the method" "$out" \
        "The page 'nowhere.xhtml' does not exist (returned by toNowhere() of CustomerVM).  «#{customerVM.toNowhere}»  → ../java/app/CustomerVM.java:"
      contains "also after another call" "$out" "«toUpperCas»  ⇒ toUpperCase"
      contains "facesContext has its type (as in NetBeans)" "$out" "«requestContextPat»  ⇒ requestContextPath"
      contains "a bean read through its scope is that bean" "$out" "«titel»  → ../java/app/CustomerVM.java:12  ⇒ title"
      contains "list[0] is an item of the list" "$out" "«nmae»  → ../java/app/Customer.java:3  ⇒ name"
      contains "a stream of EL has the methods of EL's Stream" "$out" "«filtr»  ⇒ filter"
      contains "a list literal is a List" "$out" "«stremm»  ⇒ stream"
      contains "a set literal is a Set" "$out" "«containz»  ⇒ contains"
      contains "also from h:outputStylesheet" "$out" "«css/app.css»  → resources/css/app.css:1"
      # a value with no setter on a disabled or readonly input: by where JSF writes it
      contains "never written (disabled true): a blue note that says why" "$out" "But it is never sent enabled (disabled=\"#{true}\" is always true)"
      contains "true in every page that includes it: names the pages and goes to their ui:param" "$out" \
        "is true in pages/ro/create.xhtml, pages/ro/detail.xhtml): JSF never writes it here.  «code»  → ../java/app/LockVM.java:6  → pages/ro/create.xhtml:4  → pages/ro/detail.xhtml:4"
      contains "false in one page: an error that names it and goes to its ui:param" "$out" \
        "In pages/ro/create.xhtml it is sent enabled (disabled=\"#{readOnly}\" is false there): JSF writes it.  «code»  → ../java/app/LockVM.java:6  → pages/ro/create.xhtml:3"
      contains "known only when the page runs: a warning that says so" "$out" "JSF only leaves it alone while disabled=\"#{lockVM.busy}\" is true"
      contains "sent only while disabled: says what sends the form" "$out" "what sends the form only does it while disabled=\"#{lockVM.busy}\" is true"
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
# what the checks could not check, and why (src/nbkit-jsf/test/fixture: S: marks)
contains "then what was not checked, by kind of reason" "$out" "Not checked:"
contains "the limits of any static check" "$out" "Limits of any static check"
contains "and the gaps nbkit can close" "$out" "Gaps nbkit can close"
contains "each reason with its rule and count" "$out" "Map or Object value (the rest of the expression is not checked)  [el.member]:"
contains "and where, file:line:column" "$out" "src/main/webapp/pages/skipped.xhtml:4:"
contains "a page with a stylesheet nbkit does not read leaves its unknown classes unchecked" "$out" "the page loads a stylesheet nbkit does not read (an external href): a class not found is not checked  [css.class]:"
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
# --explain: one file, and how each name was resolved
mkdir -p "$W/proj/target" && cp -r "$W/app" "$W/proj/target/classes"
out="$(analyze "$W/proj" --explain pages/orders.xhtml)"; rc=$?
check "analyze --explain exits with 0" test "$rc" = 0
contains "it says the type of each step, inherited generics resolved" "$out" "orderMB: OrderMB → orderManager: OrderManager → paginationListDataModel: Paged"
contains "a loop variable gets the type of the items" "$out" "order: OrderPagination → number: Integer"
contains "it says where the checking found something missing" "$out" "order: OrderPagination → numbr: does not exist (see the error above)"
contains "a member only an implementation has is said so, not taken as unknown" "$out" "order: OrderPagination → note: only in an implementation, OrderViewModelImpl"
contains "the errors of the file come first" "$out" "Property 'numbr' does not exist in OrderPagination"
out="$(analyze "$W/proj" --explain pages/deferred.xhtml)"
contains "--explain names a primitive the chain ends in" "$out" "customerVM: CustomerVM → canArchive(): boolean"
contains "and the type of a ui:param that holds it" "$out" "archivable: boolean"
contains "a comparison is a boolean" "$out" "named: boolean"
contains "arithmetic is not guessed" "$out" "counted: type unknown"
out="$(analyze "$W/proj" --explain pages/skipped.xhtml)"
contains "--explain lists what was not checked in the file" "$out" "Not checked in this file:"
contains "line by line, with the rule and the reason" "$out" "  4:"
contains "and the text" "$out" "[el.member]  Map or Object value (the rest of the expression is not checked)"
# a reason with more than 20 places: 20 of them, "and N more", and how to see all of one file
for i in $(seq 1 25); do printf '<h:panelGroup xmlns:h="jakarta.faces.html" styleClass="#{customerVM.title}"/>\n'; done \
  | { echo '<ui:composition xmlns="http://www.w3.org/1999/xhtml" xmlns:ui="jakarta.faces.facelets" template="/WEB-INF/templates/main.xhtml"><ui:define name="content">'; cat; echo '</ui:define></ui:composition>'; } > "$W/proj/src/main/webapp/pages/many.xhtml"
out="$(analyze "$W/proj")"
check "a long list stops at 20 places and says how many more" grep -qE '^      and [0-9]+ more$' <<<"$out"
contains "and says how to see everything of one file" "$out" "nbkit analyze jsf $W/proj --explain <file>"
# the whole report goes to a file, said in a green line at the end: every place, no cut, no colors
contains "the report is saved, said at the end" "$(tail -1 <<<"$out")" "Report saved: $W/cache/nbkit/analyze/proj-"
rep="$(sed -n 's/.*Report saved: \(.*\.txt\).*/\1/p' <<<"$out")"
check "the report file exists" test -f "$rep"
check "the terminal cuts the long list" test "$(grep -c 'pages/many.xhtml:' <<<"$out")" -lt 25
check "the report has all 25" test "$(grep -c 'pages/many.xhtml:' "$rep")" = 25
lacks "the report is not cut" "$(cat "$rep")" "Some lists were cut"
check "nor says how many more" bash -c "! grep -qE '^ +and [0-9]+ more$' '$rep'"
check "the report has no colors" bash -c "! grep -q $'\x1b' '$rep'"
contains "the report has the summary" "$(cat "$rep")" "$(grep -m1 -E 'xhtml files, [0-9]+ with something' <<<"$out")"
# --explain too: its report is named after the page
out="$(analyze "$W/proj" --explain pages/many.xhtml)"
contains "--explain saves its report too, named after the page" "$(tail -1 <<<"$out")" "Report saved: $W/cache/nbkit/analyze/proj-many-"
rep="$(sed -n 's/.*Report saved: \(.*\.txt\).*/\1/p' <<<"$out")"
contains "with how each name was resolved" "$(cat "$rep")" "How each expression of src/main/webapp/pages/many.xhtml was resolved:"
rm "$W/proj/src/main/webapp/pages/many.xhtml"
# with a collection of what NetBeans marks (here a fake one, pages/compare.xhtml): the comparison after the summary
compile -cp "$W/nbkit" -d "$W/compare" "$J/test/RunComparison.java"
"$JAVA" -Dnbkit.write="$W/marks.tsv" -cp "$W/nbkit:$W/compare" RunComparison "$W/proj" "$W/app" "$W/api.jar" "$W/primefaces.jar" >/dev/null 2>&1
out="$(NBKIT_COLLECTION="$W/marks.tsv" analyze "$W/proj")"
contains "analyze compares with the collection, saying its date and NetBeans" "$out" "Comparison with NetBeans (collection of 2026-11-16T19:00:00Z, Apache NetBeans IDE 31 31-test):"
contains "with the counts per category" "$out" "agree 2   NetBeans false positives 3   NetBeans catches what nbkit skipped 1   only nbkit"
contains "each NetBeans false positive with nbkit's why" "$out" \
  "src/main/webapp/pages/compare.xhtml:5:"
contains "the why of a false positive comes from how nbkit resolved it" "$out" "Unknown method concat  ← text literal inside a method argument: 'a': String"
contains "what NetBeans catches and nbkit skipped, by the reason" "$out" "Map or Object value (the rest of the expression is not checked): 1"
contains "and what only nbkit marks" "$out" "Only nbkit (to review)"
out="$(NBKIT_COLLECTION="$W/marks.tsv" analyze "$W/proj" --explain pages/compare.xhtml)"
contains "--explain shows cmp.header with date and NetBeans version" "$out" "Comparison with NetBeans (collection of 2026-11-16T19:00:00Z, Apache NetBeans IDE 31 31-test):"
contains "--explain shows cmp.counts with the numbers of this file" "$out" "agree 2   NetBeans false positives 3   NetBeans catches what nbkit skipped 1   only nbkit 1"
contains "--explain shows Not collected with the reason" "$out" "Not collected: the HTML rules (Missing CSS Class) (html-error-checking off text/facelets)"
contains "line by line, with the category" "$out" "  4:"
# --explain on a file without any crossings still shows cmp.header, zero counts and Not collected
out_no="$(NBKIT_COLLECTION="$W/marks.tsv" analyze "$W/proj" --explain pages/standalone.xhtml)"
contains "--explain without crossings shows cmp.header" "$out_no" "Comparison with NetBeans (collection of 2026-11-16T19:00:00Z, Apache NetBeans IDE 31 31-test):"
contains "--explain without crossings shows zero counts" "$out_no" "agree 0   NetBeans false positives 0   NetBeans catches what nbkit skipped 0   only nbkit 0"
contains "--explain without crossings shows Not collected with the reason" "$out_no" "Not collected: the HTML rules (Missing CSS Class) (html-error-checking off text/facelets)"
# whole-project analyze with a collection having marks in more than one file (step 5 regression check)
cp "$W/marks.tsv" "$W/multi-marks.tsv"
printf 'mark\tsrc/main/webapp/pages/orders.xhtml\t5\t36\t419\t424\ttext_x-el_Identifiers\tWARNING\ton\tUnknown property numbr\n' >> "$W/multi-marks.tsv"
out="$(NBKIT_COLLECTION="$W/multi-marks.tsv" analyze "$W/proj")"
lacks "whole-project analyze has no explain.header" "$out" "How each expression of"
lacks "whole-project analyze has no per-file skip block" "$out" "Not checked in this file:"
check "whole-project analyze has cmp.header once" test "$(grep -c 'Comparison with NetBeans (collection of' <<<"$out")" = 1
check "whole-project analyze has cmp.counts once" test "$(grep -cE 'agree [0-9]+   NetBeans false positives [0-9]+' <<<"$out")" = 1
check "each line of the comparison summary appears once" test "$(grep -c 'Unknown method concat' <<<"$out")" = 1
check "the mark of the second file is crossed (one more agree)" test "$(grep -oE "agree [0-9]+" <<<"$out")" = "agree $(( $(NBKIT_COLLECTION="$W/marks.tsv" analyze "$W/proj" | grep -oE "agree [0-9]+" | grep -oE "[0-9]+") + 1 ))"
out="$(NBKIT_COLLECTION="$W/multi-marks.tsv" analyze "$W/proj" --explain pages/compare.xhtml)"
contains "--explain has explain.header" "$out" "How each expression of src/main/webapp/pages/compare.xhtml was resolved:"
contains "--explain has per-file skip block" "$out" "Not checked in this file:"
lacks "--explain has no marks from other files" "$out" "numbr"
# is the collection up to date? (lib/analyze.sh asks this before comparing)
check_col() { "$JAVA" -Dnbkit.collection.check=1 -Dnbkit.collection.file="$W/marks.tsv" "$@" -cp "$W/nbkit-jsf.jar" nbkit.jsf.Analyze "$W/proj" 2>&1 | grep -v '^Picked up'; }
contains "the collection is up to date" "$(check_col)" "ok 2026-11-16T19:00:00Z"
contains "another NetBeans version makes it stale, saying both" "$(check_col -Dnbkit.netbeans="Apache NetBeans IDE 32")" "netbeans 31 32"
echo '<!-- changed -->' >> "$W/proj/src/main/webapp/pages/compare.xhtml"
: > "$W/proj/src/main/webapp/pages/brand-new.xhtml"
touch -d '+5 minutes' "$W/proj/target/classes/app/CustomerVM.class"
out="$(check_col)"
contains "a changed page makes it stale" "$out" "stale 2026-11-16T19:00:00Z"
contains "saying which page" "$out" "changed src/main/webapp/pages/compare.xhtml"
contains "and which page is new" "$out" "new src/main/webapp/pages/brand-new.xhtml"
contains "and which classes were compiled after it" "$out" "classes app.CustomerVM"
rm "$W/proj/src/main/webapp/pages/brand-new.xhtml"
contains "with no collection, nothing to compare" "$("$JAVA" -Dnbkit.collection.check=1 -Dnbkit.collection.file="$W/none.tsv" -cp "$W/nbkit-jsf.jar" nbkit.jsf.Analyze "$W/proj" 2>&1)" "missing"
# the analyze side: with arguments it only warns, about a missing collection or one that may be out of date
CD="$(date -d '2026-11-16T19:00:00Z' '+%Y-%m-%d %H:%M')"
out="$(NBKIT_COLLECTION="$W/none.tsv" analyze "$W/proj")"
contains "with no collection it says how to get one" "$out" "No collection of what NetBeans marks on this project: no comparison."
out="$(NBKIT_COLLECTION="$W/marks.tsv" analyze "$W/proj")"
contains "with an old one it warns, and compares with it anyway" "$out" "The collection of what NetBeans marks ($CD) may be out of date; comparing with it anyway."
contains "saying what changed, with how many" "$out" "changed pages (1): src/main/webapp/pages/compare.xhtml"
contains "and still compares" "$out" "Comparison with NetBeans (collection of"
# a folder moved since the collection (same content, another path): one line with the folder, not each page twice
WA="$W/proj/src/main/webapp"
nres="$(find "$WA/resources" -name '*.xhtml' | wc -l)"
mkdir "$WA/META-INF" && mv "$WA/resources" "$WA/META-INF/resources"
out="$(NBKIT_COLLECTION="$W/marks.tsv" analyze "$W/proj")"
contains "a moved folder is one line, with how many pages" "$out" "$nres pages moved to another folder: src/main/webapp/resources/ -> src/main/webapp/META-INF/resources/"
lacks "its pages are not new" "$out" "new pages"
lacks "nor removed" "$out" "removed pages"
mv "$WA/META-INF/resources" "$WA/resources" && rmdir "$WA/META-INF"
# a page renamed (same content): moved, each with where it went
mv "$WA/pages/standalone.xhtml" "$WA/pages/alone.xhtml"
out="$(NBKIT_COLLECTION="$W/marks.tsv" analyze "$W/proj")"
contains "a renamed page is moved, old -> new" "$out" "moved pages (1): src/main/webapp/pages/standalone.xhtml -> src/main/webapp/pages/alone.xhtml"
# a page gone (no page now with its content): removed
rm "$WA/pages/alone.xhtml"
out="$(NBKIT_COLLECTION="$W/marks.tsv" analyze "$W/proj")"
contains "a page gone is removed" "$out" "removed pages (1): src/main/webapp/pages/standalone.xhtml"
cp "$J/test/fixture/src/main/webapp/pages/standalone.xhtml" "$WA/pages/"
# more than 5 pages of a kind: the first 5, then how many more
for i in 1 2 3 4 5 6 7; do echo "<!-- $i -->" > "$WA/pages/extra-$i.xhtml"; done
out="$(NBKIT_COLLECTION="$W/marks.tsv" analyze "$W/proj")"
contains "over 5 pages: 5 names and how many more" "$out" "new pages (7): src/main/webapp/pages/extra-1.xhtml, src/main/webapp/pages/extra-2.xhtml, src/main/webapp/pages/extra-3.xhtml, src/main/webapp/pages/extra-4.xhtml, src/main/webapp/pages/extra-5.xhtml … and 2 more"
rm "$WA"/pages/extra-*.xhtml
# in a terminal that answers (the interface, the menu) it asks first; no: the old one
# a home whose userdir has the JSF module and no lock: NetBeans is closed, so the question says it opens it
QH="$W/qhome"; mkdir -p "$QH/.netbeans/31/config" "$QH/.netbeans/31/modules" "$QH/.netbeans/31/var/log"
: > "$QH/.netbeans/31/modules/nbkit-jsf.jar"
rm -f "$W/collect-ev"
# a fake xdg-open, to see the report opened
mkdir -p "$W/fakebin"; printf '#!/bin/bash\necho "$1" > "%s/opened"\n' "$W" > "$W/fakebin/xdg-open"; chmod +x "$W/fakebin/xdg-open"
out="$(printf 'n\n\n' | PATH="$W/fakebin:$PATH" HOME="$QH" NBKIT_TTY=1 NBKIT_UI_EVENTS="$W/collect-ev" NBKIT_COLLECTION="$W/marks.tsv" NBKIT_JSF_JAR="$W/nbkit-jsf.jar" NBKIT_MVN=false timeout 60 script -qec "bash '$NBKIT_DIR/nbkit.sh' --lang en analyze jsf '$W/proj'" /dev/null 2>&1 | tr -d '\r')"
contains "the interface or the menu asks whether to collect again, listing what changed" "$out" "The collection of what NetBeans marks ($CD) may be out of date. Collect it again? It opens NetBeans."
check "the dialog gets what changed, from the same list" grep -q 'changed pages (1): src/main/webapp/pages/compare.xhtml' "$W/collect-ev"
contains "no: it compares with the old one, warning" "$out" "may be out of date; comparing with it anyway."
contains "the interface or the menu asks whether to open the report, Enter opens" "$out" "Report saved: $W/cache/nbkit/analyze/proj-"
for _ in $(seq 50); do [ -f "$W/opened" ] && break; sleep 0.1; done
check "Enter opens it" grep -q "$W/cache/nbkit/analyze/proj-.*\.txt" "$W/opened"
# --netbeans: collects without asking, with a NetBeans that only answers the request (and closes it, since it opened it)
FH="$W/fakehome"; FU="$FH/.netbeans/31"
mkdir -p "$FU/modules" "$FU/config" "$FU/var/log" "$W/fakenb/bin"
: > "$FU/modules/nbkit-jsf.jar"; printf 'nbkit/core/CloseOption' > "$FU/modules/nbkit-core.jar"; : > "$FU/var/log/messages.log"
cat > "$W/fakenb/bin/netbeans" <<'X'
#!/bin/bash
# a NetBeans that only answers the collection request of nbkit (tests/jsf.sh)
UD="$HOME/.netbeans/31"
case " $* " in *" --nbkit-close "*) pkill -f "nbkit-fake-""netbeans" ; rm -f "$UD/lock"; exit 0 ;; esac
: > "$UD/lock"
echo "INFO: Turning on modules:" >> "$UD/var/log/messages.log"
nohup bash -c 'while :; do r="$HOME/.cache/nbkit/collect-request"; if [ -f "$r" ]; then rm "$r"; cp "$FAKE_MARKS" "$NBKIT_COLLECTION"; echo "$NBKIT_COLLECTION" > "$HOME/.cache/nbkit/collect-done"; fi; sleep 0.2; done' "nbkit-fake-""netbeans" org.netbeans.Main --userdir "$UD" >/dev/null 2>&1 &
X
chmod +x "$W/fakenb/bin/netbeans"
"$JAVA" -Dnbkit.write="$W/fresh.tsv" -cp "$W/nbkit:$W/compare" RunComparison "$W/proj" "$W/app" "$W/api.jar" "$W/primefaces.jar" >/dev/null 2>&1
out="$(HOME="$FH" NB_HOME="$W/fakenb" FAKE_MARKS="$W/fresh.tsv" NBKIT_COLLECTION="$W/collected.tsv" NBKIT_COLLECT_TIMEOUT=30 analyze "$W/proj" --netbeans)"; rc=$?
check "--netbeans exits with 0" test "$rc" = 0
contains "it opens NetBeans" "$out" "opening NetBeans"
contains "waits for the collection" "$out" "NetBeans collected what it marks."
contains "and compares with the new one" "$out" "Comparison with NetBeans (collection of"
lacks "the new one is up to date" "$out" "may be out of date"
check "and closes NetBeans, since it opened it" bash -c '! pgrep -f "nbkit-fake-""netbeans"'
pkill -f "nbkit-fake-""netbeans" 2>/dev/null
# a project with no compiled classes: its beans are unknown, so unknown names are not checked
mkdir -p "$W/bare/src/main/webapp" "$W/bare/target/classes" && printf '<project/>' > "$W/bare/pom.xml"
printf '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:h="jakarta.faces.html"><h:body><h:outputText value="#{someBean.x}"/></h:body></html>\n' > "$W/bare/src/main/webapp/a.xhtml"
out="$(analyze "$W/bare")"
contains "with no compiled classes, unknown names are a skipped reason" "$out" "no compiled classes: the beans are not known  [el.unknown]: 1"
lacks "and only that file" "$out" "customers.xhtml"
out="$(NBKIT_JSF_JAR="$W/nbkit-jsf.jar" NBKIT_MVN=false bash "$NBKIT_DIR/nbkit.sh" --lang en analyze jsf --explain "$W/proj/src/main/webapp/pages/orders.xhtml" </dev/null 2>&1)"; rc=$?
check "--explain with only the file finds its project" test "$rc" = 0
contains "and explains it" "$out" "order: OrderPagination → number: Integer"
mkdir -p "$W/loose" && : > "$W/loose/a.xhtml"
out="$(NBKIT_JSF_JAR="$W/nbkit-jsf.jar" bash "$NBKIT_DIR/nbkit.sh" --lang en analyze jsf --explain "$W/loose/a.xhtml" </dev/null 2>&1)"; rc=$?
check "a file outside any project is refused" test "$rc" = 1
contains "saying why" "$out" "is not inside a project"
out="$(analyze "$W/proj" --explain pages/nothing.xhtml)"; rc=$?
check "an --explain file that is not there exits with 2" test "$rc" = 2
contains "and says so" "$out" "No file of"
rm -rf "$W/proj/target"
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

# what NetBeans marks, collected by the module on request (nb/Collector) and read by the comparator: request, hash,
# positions and the collection file, all in the core (no NetBeans)
compile -cp "$W/nbkit" -d "$W/marks" "$J/test/RunNetBeansMarks.java"
mkdir -p "$W/cache"
out="$("$JAVA" -cp "$W/nbkit:$W/marks" RunNetBeansMarks "$W/cache" 2>&1 | grep -v '^Picked up JAVA_TOOL_OPTIONS')"
T=$'\t'
contains "the request is ~/.cache/nbkit/collect-request, like the debug file" "$out" "request file: /collect-request"
contains "no request file: nothing to do" "$out" "no request: null"
contains "an empty request: nothing to do" "$out" "empty request: null"
contains "the request is the project path, blanks around it ignored" "$out" "request: /work/my project"
contains "~ in the request is the home folder" "$out" "request with ~: HOME/Documents/app"
contains "the hash of each xhtml is its sha256" "$out" "sha256 abc: ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
contains "offset 0 is line 1, column 1" "$out" "offset 0 -> 1:1"
contains "after a line break, the next line" "$out" "offset 3 -> 2:1"
contains "a CRLF line break counts once" "$out" "offset 7 -> 3:1"
contains "the end of the text is still a position" "$out" "offset 9 -> 3:3"
contains "one collection per project, under collect/" "$out" "output: /collect/my project-"
contains "the same project always writes the same file" "$out" "same project, same output: true"
contains "a project of the same name elsewhere, another file" "$out" "another project, another output: true"
contains "the file starts saying what it is" "$out" "line: # nbkit NetBeans marks 1"
contains "then the versions, date and project, one per line" "$out" "line: info${T}netbeans${T}31"
contains "then each xhtml with its hash" "$out" "line: file${T}src/main/webapp/a.xhtml${T}ba7816bf"
contains "each mark: file, line, column, offsets, rule, severity, on/off in the settings, message" "$out" \
  "line: mark${T}src/main/webapp/a.xhtml${T}2${T}5${T}12${T}20${T}text_x-el_Identifiers${T}WARNING${T}off${T}Unknown property \"x\"\\twith a tab\\nand a line \\\\ backslash"
contains "a rule that is on says so" "$out" "text_html_MissingClassRule${T}WARNING${T}on${T}Class y not found"
contains "reading gives the info back" "$out" "read info: {project=/work/my project, netbeans=31}"
contains "and the hashes" "$out" "read hashes: {src/main/webapp/a.xhtml=ba7816bf"
contains "and exactly the marks written (tabs, line breaks and backslashes too)" "$out" "read back the same marks: true"
contains "it is written whole or not at all (no temporary file left)" "$out" "no temporary file left: true"
contains "the done marker comes after, saying where the collection is" "$out" "done marker: true"

contains "a request is taken: its project, and the request and the old done marker are gone" "$out" \
  "take: /work/next request left: false old done left: false"
contains "a request is answered once" "$out" "take again: null"
contains "an empty request is dropped too" "$out" "take an empty request: null request left: false"
contains "HTML error checking: JSF pages (text/facelets) are off unless turned on" "$out" "setting='' text/facelets: false"
contains "turned on, they are on" "$out" "setting='text/facelets' text/facelets: true"
contains "plain xhtml is on by default" "$out" "setting='' text/xhtml: true"
contains "listed, an HTML mime is turned off" "$out" "setting='text/xhtml;text/facelets' text/xhtml: false"
contains "the collection says whether HTML error checking ran" "$out" "line: info${T}html-error-checking${T}off text/facelets"
contains "and whether the project is a web module" "$out" "line: info${T}web-module${T}no"
contains "read back: the rules that did not run, and why (no marks there is not agreement)" "$out" \
  "not run: {text_html_=html-error-checking off text/facelets, text_x-el_Identifiers=web-module no}"
contains "with both on, every rule ran" "$out" "all ran: {}"
contains "web module: yes when Identifiers applied to some EL of the project" "$out" "web module, Identifiers applied to some EL: yes"
contains "no when there was EL and it never applied" "$out" "web module, EL but Identifiers never applied: no"
contains "unknown with no EL at all" "$out" "web module, no EL: unknown"
contains "unknown is not taken as not run (no EL, no EL marks to miss)" "$out" "unknown web module: {}"
steps="$(grep '^collect step: ' <<<"$out" | paste -sd'|')"
contains "the collection notifies first, saying the project and that NetBeans can still be used" "$out" \
  "collect step: notice nbkit | nbkit: collecting what NetBeans marks on collectproj to compare with analyze. You can keep working."
check "the first notification comes before opening the project" grep -q "^collect step: notice nbkit | nbkit: collecting" <<<"$(grep '^collect step: ' <<<"$out" | head -1)"
contains "then each page in turn, telling how far it got (pages done, of how many, marks so far, the page)" "$out" \
  "collect step: marks of src/main/webapp/b.xhtml, progress 1 2 1 src/main/webapp/b.xhtml"
contains "at the end the first one goes away and the last one says how many marks" "$steps" \
  "collect step: clear nbkit: collecting what NetBeans marks on collectproj to compare with analyze. You can keep working.|collect step: notice nbkit | Collection ready: 2 marks."
contains "after the collection and its done marker are written" "$steps" "Collection ready: 2 marks.|collect step: collection: 2 marks, done marker: true, progress left: false"
# in NetBeans the Workspace lives on: a .js or a .properties that changes must not leave old classes or keys
compile -cp "$W/nbkit" -d "$W/caches" "$J/test/RunWorkspaceCaches.java"
out="$("$JAVA" -cp "$W/nbkit:$W/caches" RunWorkspaceCaches "$W/cacheproj" 2>&1 | grep -v '^Picked up JAVA_TOOL_OPTIONS')"
contains "the classes of the project's JavaScript are read" "$out" "js before: [first]"
contains "and read again when a .js changes" "$out" "js after: [second]"
contains "the keys of a bundle are read again when its .properties changes" "$out" "keys after: [one, two]"
contains "and the signature NetBeans watches changes with them (the open pages are checked again)" "$out" "the files' signature changes: true"

# the comparison with NetBeans: pages/compare.xhtml crossed with a fake collection, one case per category
compile -cp "$W/nbkit" -d "$W/compare" "$J/test/RunComparison.java"
out="$("$JAVA" -Duser.language=en -cp "$W/nbkit:$W/compare" RunComparison "$J/test/fixture" "$W/app" "$W/api.jar" "$W/primefaces.jar" 2>&1 | grep -v '^Picked up JAVA_TOOL_OPTIONS')"
sec="$(sed -n '/^== all rules ran/,/^== HTML checking off/p' <<<"$out")"
contains "both mark the same place: they agree" "$sec" "line 4: AGREE Identifiers / el.member"
contains "nbkit resolves a text literal inside a method argument: a NetBeans false positive, and why" "$sec" \
  "line 5: NETBEANS_FALSE_POSITIVE Identifiers / null why: text literal inside a method argument: 'a': String"
contains "nbkit follows the generics: a NetBeans false positive, and why" "$sec" "line 6: NETBEANS_FALSE_POSITIVE Identifiers / null why: type resolved through generics:"
contains "nbkit skipped it: NetBeans catches what nbkit skipped, with the reason" "$sec" "line 7: NETBEANS_CATCHES_SKIPPED Identifiers / el.member skipped el.dynamic"
contains "only in an implementation: a NetBeans false positive" "$sec" "line 8: NETBEANS_FALSE_POSITIVE Identifiers / null why: only in an implementation"
contains "nbkit marks what NetBeans does not: only nbkit" "$sec" "line 9: NBKIT_ONLY null / el.member"
contains "a missing class both mark: they agree" "$sec" "line 10: AGREE MissingClassRule / css.class"
lacks "a NetBeans rule with no pair in nbkit (the HTML validator) stays out" "$sec" "Other"
sec="$(sed -n '/^== HTML checking off/,/^pairs:/p' <<<"$out")"
contains "a rule NetBeans did not run is not collected, saying why, instead of only nbkit" "$sec" \
  "line 10: NOT_COLLECTED MissingClassRule / css.class why: html-error-checking off text/facelets"
contains "the pairs NetBeans rule -> nbkit rules, and the one nbkit turns off (NetBeansOverrides reads them)" "$out" \
  "MissingClassRule->[css.class] off org/netbeans/modules/csl/api/default/text_html_MissingClassRule"

# tests/jsf-war crossed with a real collection of what NetBeans marks on it (tests/jsf-war/netbeans-marks.tsv, made in
# NetBeans: nbkit.md, How to run): each case of its index.xhtml in the category of the table in the notes
WAR="$NBKIT_DIR/tests/jsf-war"
if [ -f "$WAR/netbeans-marks.tsv" ]; then
  check "the saved collection does not carry the machine path" test -z "$(grep -F $'info\tproject\t/' "$WAR/netbeans-marks.tsv")"
  mkdir -p "$W/war" && cp -r "$WAR/src" "$WAR/pom.xml" "$W/war/" && mkdir -p "$W/war/target/classes"
  mapfile -t src < <(java_files "$W/war/src/main/java")
  compile -cp "$W/api.jar" -d "$W/war/target/classes" "${src[@]}"
  # compiled long ago: the classes are not newer than the collection
  find "$W/war/target/classes" -type f -exec touch -d '2000-01-01' {} +
  # a home with no NetBeans: its version is not compared (the collection may come from another machine's NetBeans)
  mkdir -p "$W/warhome"
  out="$(HOME="$W/warhome" NBKIT_COLLECTION="$WAR/netbeans-marks.tsv" analyze "$W/war" --explain index.xhtml)"
  lacks "jsf-war: the saved collection is up to date with the pages" "$out" "may be out of date"
  contains "case 1 (#{greeter.nmae}): both mark it" "$out" "  9:36  agree"
  contains "case 2 (concat in a method argument): a NetBeans false positive" "$out" "  11:46  NetBeans false positives"
  contains "case 3 (generics): a NetBeans false positive" "$out" "  13:49  NetBeans false positives"
  contains "case 4 (class typo): both mark it" "$out" "  15:17  agree"
  contains "case 4b (styleClass typo): only nbkit" "$out" "  17:31  Only nbkit (to review)"
  contains "case 5 (class with EL): skipped by nbkit" "$out" "  19:31  [css.class]  class with EL, known only at runtime"
  lacks "case 5 (class with EL): no comparison line" \
    "$(grep -E '^  [0-9]+:[0-9]+  (agree|NetBeans false positives|NetBeans catches what nbkit skipped|Only nbkit \(to review\)|not collected)  ' <<<"$out")" "  19:31  "
  contains "case 6 (class in no CSS nor JS): both mark it" "$out" "  21:17  agree"
  contains "case 7 (wrong number of arguments): both mark it" "$out" "  23:36  agree"
  contains "case 8 (only in an implementation): a NetBeans false positive" "$out" "  25:40  NetBeans false positives"
else
  echo "  skipped: jsf-war has no saved NetBeans collection yet (tests/jsf-war/netbeans-marks.tsv, see How to run)"
fi

finish
