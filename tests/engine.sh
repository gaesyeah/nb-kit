#!/usr/bin/env bash
# End-to-end tests of nbkit against the fake NetBeans in tests/netbeans: install, reinstall keeping
# the user's customizations, check, uninstall, rollback on failure and broken theme/module files.
#   bash tests/engine.sh            run
#   bash tests/engine.sh --update   write tests/expected/install.sha1 again (after changing a theme on purpose)
set -uo pipefail
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
H="$WORK/home"; U="$H/.netbeans/31"
nbkit() { HOME="$H" bash "$NBKIT_DIR/nbkit.sh" "$@" </dev/null 2>&1; }
EXPECTED="$TESTS/expected/install.sha1"

echo "Install"
new_home "$H"
before="$(fingerprint "$H")"
out="$(nbkit install)"; rc=$?
check "install exits with 0" test "$rc" = 0
contains "install says what was installed" "$out" "Installed: Theme One Dark Pro Mix; JSF checks"
lacks "install shows no error" "$out" "Error:"
if [ "${1:-}" = --update ]; then
  fingerprint "$H" > "$EXPECTED"
  echo "  written: tests/expected/install.sha1 ($(wc -l < "$EXPECTED") files)"
fi
diff_out="$(diff "$EXPECTED" <(fingerprint "$H"))"
if [ -z "$diff_out" ]; then pass "installed files are exactly the expected ones ($(wc -l < "$EXPECTED"))"
else fail "installed files are exactly the expected ones" "$(head -20 <<<"$diff_out")"; fi
check "user key kept in the UI file" grep -qx '@myKey=#123456' "$U/config/LookAndFeel/FlatDarkLaf.properties"
check "base profile left untouched" cmp -s "$U/config/Editors/FontsColors/FlatLafDark/org-netbeans-modules-editor-settings-CustomFontsColors-tokenColorings.xml" \
  "$U/config/Editors/text/x-java/FontsColors/FlatLafDark/org-netbeans-modules-editor-settings-CustomFontsColors-tokenColorings.xml"
check "a backup of the original state was made" ls "$U"/nbkit-theme-backup-*.tar.gz

echo "Reinstall"
installed="$(fingerprint "$H")"
out="$(nbkit install)"; rc=$?
check "reinstall exits with 0" test "$rc" = 0
check "reinstall gives the same files" test "$(fingerprint "$H")" = "$installed"
check "reinstall makes no second backup" test "$(find "$U" -maxdepth 1 -name 'nbkit-theme-backup-*' | wc -l)" = 1

echo "Customizations survive a reinstall"
P="$U/config/Editors/FontsColors/One Dark Pro Mix/org-netbeans-modules-editor-settings-CustomFontsColors-tokenColorings.xml"
sed -i 's|</fontscolors>|    <fontcolor name="comment" foreColor="ff00ff00"/>\n</fontscolors>|' "$P"
echo '@anotherKey=#abcdef' >> "$U/config/LookAndFeel/FlatDarkLaf.properties"
out="$(nbkit install)"
check "editor color tweak kept" grep -q 'name="comment" foreColor="ff00ff00"' "$P"
check "own UI keys kept" grep -qx '@anotherKey=#abcdef' "$U/config/LookAndFeel/FlatDarkLaf.properties"

echo "Check (NetBeans open)"
nb_opened "$H" nbkit.colors nbkit.core nbkit.jsf
out="$(nbkit check)"; rc=$?
check "check exits with 0 when everything loaded" test "$rc" = 0
contains "check says all good" "$out" "All good."
nb_opened "$H" nbkit.colors nbkit.core
out="$(nbkit check)"; rc=$?
check "check exits with 1 when a module did not load" test "$rc" = 1
contains "check points at the missing module" "$out" "PROBLEM  the module is not among the enabled modules"

echo "Uninstall"
out="$(nbkit uninstall)"; rc=$?
check "uninstall exits with 0" test "$rc" = 0
check "uninstall brings back exactly the original files" test "$(fingerprint "$H")" = "$before"

echo "Rollback on failure"
before="$(fingerprint "$H")"
for n in 2 6 9; do
  out="$(NBKIT_TEST_FAIL_STEP=$n nbkit install)"; rc=$?
  check "failure at step $n exits with an error" test "$rc" != 0
  check "failure at step $n changes nothing" test "$(fingerprint "$H")" = "$before"
done
contains "rollback is reported" "$out" "nothing was changed in NetBeans."

echo "Broken files"
K="$WORK/kit"
cp -r "$NBKIT_DIR" "$K"
mkdir -p "$K/modules/themes/broken" "$K/modules/bad"
printf '[theme]\nname = "Broken"\nversion = 1\n' > "$K/modules/themes/broken/theme.toml"
touch "$K/modules/themes/broken/ui.properties"
printf '[all]\ndefault = "#d4d4d4 on #1e1e1e"\ncomment = "#6a9955 itallic"\n' > "$K/modules/themes/broken/colors.toml"
printf '[module]\nname = "Bad"\nversion = 1\njar = "x.jar"\ncodename = "a.b"\n' > "$K/modules/bad/module.toml"
out="$(HOME="$H" bash "$K/nbkit.sh" --help </dev/null 2>&1)"
contains "broken theme is skipped with file, place and line" "$out" 'theme "broken" skipped: unknown word: "itallic" (in all / comment, line 3)'
contains "broken module is skipped with the reason" "$out" 'module "bad" skipped: "sha256" is missing in module.toml'
contains "the other modules still load" "$out" "Modules: one-dark-pro-mix jsf"
printf 'x' >> "$K/modules/jsf/nbkit-jsf.jar"
out="$(HOME="$H" bash "$K/nbkit.sh" install jsf </dev/null 2>&1)"; rc=$?
check "corrupted jar stops the install" test "$rc" != 0
check "corrupted jar changes nothing" test "$(fingerprint "$H")" = "$before"

echo "Languages"
out="$(HOME="$H" NBKIT_LANG='' LC_ALL='' LANG=pt_BR.UTF-8 bash "$NBKIT_DIR/nbkit.sh" --help </dev/null 2>&1)"
contains "Portuguese from the system language" "$out" "módulos para o NetBeans"
out="$(HOME="$H" NBKIT_LANG='' LC_ALL='' LANG=en_US.UTF-8 bash "$NBKIT_DIR/nbkit.sh" --help --lang pt-BR </dev/null 2>&1)"
contains "--lang wins over the system language" "$out" "módulos para o NetBeans"

finish
