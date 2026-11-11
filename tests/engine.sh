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
# the jars are compared with the ones in this folder, not by a fixed hash: src/build.sh rebuilds them
golden() { fingerprint "$H" | sed -E 's#^[0-9a-f]{40}  (\./modules/[^/]*\.jar)$#jar-of-this-nbkit  \1#'; }
if [ "${1:-}" = --update ]; then
  golden > "$EXPECTED"
  echo "  written: tests/expected/install.sha1 ($(wc -l < "$EXPECTED") files)"
fi
diff_out="$(diff "$EXPECTED" <(golden))"
if [ -z "$diff_out" ]; then pass "installed files are exactly the expected ones ($(wc -l < "$EXPECTED"))"
else fail "installed files are exactly the expected ones" "$(head -20 <<<"$diff_out")"; fi
same_jars() {
  cmp -s "$U/modules/nbkit-jsf.jar" "$NBKIT_DIR/modules/tools/jsf/nbkit-jsf.jar" \
    && cmp -s "$U/modules/nbkit-core.jar" "$NBKIT_DIR/lib/jars/nbkit-core.jar" \
    && cmp -s "$U/modules/nbkit-colors.jar" "$NBKIT_DIR/lib/jars/nbkit-colors.jar"
}
check "the installed jars are the ones of this nbkit" same_jars
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

echo "A theme key you changed"
sed -i 's/^@background=.*/@background=#000000/' "$U/config/LookAndFeel/FlatDarkLaf.properties"
# without a terminal (setsid): the question about the key is not asked, as on GitHub Actions
out="$(HOME="$H" setsid -w bash "$NBKIT_DIR/nbkit.sh" install one-dark-pro-mix </dev/null 2>&1)"; rc=$?
check "reinstall with a changed theme key exits with 0" test "$rc" = 0
contains "it lists the key you changed" "$out" "@background"
check "without a terminal to ask, the theme value is applied" test "$(grep -c '^@background=#000000' "$U/config/LookAndFeel/FlatDarkLaf.properties")" = 0

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
mkdir -p "$K/modules/themes/broken" "$K/modules/tools/bad"
printf '[theme]\nname = "Broken"\nversion = 1\n' > "$K/modules/themes/broken/theme.toml"
touch "$K/modules/themes/broken/ui.properties"
printf '[all]\ndefault = "#d4d4d4 on #1e1e1e"\ncomment = "#6a9955 itallic"\n' > "$K/modules/themes/broken/colors.toml"
printf '[tool]\nname = "Bad"\nversion = 1\n[netbeans_module]\njar = "x.jar"\ncodename = "a.b"\n' > "$K/modules/tools/bad/tool.toml"
out="$(HOME="$H" bash "$K/nbkit.sh" --help </dev/null 2>&1)"
contains "broken theme is skipped with file, place and line" "$out" 'theme "broken" skipped: unknown word: "itallic" (in all / comment, line 3)'
contains "broken tool is skipped with the reason" "$out" 'tool "bad" skipped: "netbeans_module.sha256" is missing in tool.toml'
contains "the other modules still load" "$out" "Modules: one-dark-pro-mix jsf"
printf 'x' >> "$K/modules/tools/jsf/nbkit-jsf.jar"
out="$(HOME="$H" bash "$K/nbkit.sh" install jsf </dev/null 2>&1)"; rc=$?
check "corrupted jar stops the install" test "$rc" != 0
check "corrupted jar changes nothing" test "$(fingerprint "$H")" = "$before"

echo "Languages"
out="$(HOME="$H" NBKIT_LANG='' LC_ALL='' LANG=pt_BR.UTF-8 bash "$NBKIT_DIR/nbkit.sh" --help </dev/null 2>&1)"
contains "Portuguese from the system language" "$out" "módulos para o NetBeans"
out="$(HOME="$H" NBKIT_LANG='' LC_ALL='' LANG=en_US.UTF-8 bash "$NBKIT_DIR/nbkit.sh" --help --lang pt-BR </dev/null 2>&1)"
contains "--lang wins over the system language" "$out" "módulos para o NetBeans"


echo "Status and events for the interface"
PY="${NBKIT_PY:-python3}"
# jget <json> <python expression on d>
jget() { "$PY" -c 'import json, sys; d = json.loads(sys.argv[1]); print(eval(sys.argv[2]))' "$1" "$2" 2>&1; }
new_home "$H"
json="$(nbkit status --json)"; rc=$?
check "status --json exits with 0" test "$rc" = 0
check "status --json is valid JSON" test "$(jget "$json" "type(d).__name__")" = dict
check "status --json finds the userdir" test "$(jget "$json" "d['userdir'] == '$U' and [u['path'] for u in d['userdirs']] == ['$U']")" = True
check "status --json lists the modules, not installed" test "$(jget "$json" "[(m['id'], m['status'], m['installed']) for m in d['modules']]")" = "[('one-dark-pro-mix', 'no', None), ('jsf', 'no', None)]"
check "status --json knows it runs from a clone" test "$(jget "$json" "d['clone'], d['netbeans_running'], d['can_check'], d['backups']")" = "(True, False, False, [])"
E="$WORK/events"
out="$(NBKIT_UI_EVENTS="$E" nbkit install)"; rc=$?
check "install with events exits with 0" test "$rc" = 0
# "n/total" of each step event, and how many other events there were
steps="$("$PY" - "$E" <<'X' 2>&1
import json, sys
events = [json.loads(line) for line in open(sys.argv[1])]
print(' '.join('%d/%d' % (e['n'], e['total']) for e in events if e['ev'] == 'step'), len([e for e in events if e['ev'] != 'step']))
X
)"
check "one step event per step, up to the total" test "$steps" = "1/11 2/11 3/11 4/11 5/11 6/11 7/11 8/11 9/11 10/11 11/11 0"
json="$(nbkit status --json)"
check "status --json after the install" test "$(jget "$json" "[(m['status'], m['installed']) for m in d['modules']]")" = "[('ok', '29'), ('ok', '2')]"
check "status --json lists the backup, marked as the original" test "$(jget "$json" "[(b['module'], b['original'], b['file'] .startswith('$U/nbkit-theme-backup-')) for b in d['backups']]")" = "[('one-dark-pro-mix', True, True)]"
out="$(nbkit status)"
contains "status without --json is for people" "$out" "JSF checks"
out="$(HOME="$WORK/empty" bash "$NBKIT_DIR/nbkit.sh" status --json </dev/null 2>&1)"; rc=$?
check "status --json without NetBeans still answers" test "$rc/$(jget "$out" "d['userdir'], d['modules']")" = "0/(None, [])"
out="$(HOME="$WORK/empty" bash "$NBKIT_DIR/nbkit.sh" status </dev/null 2>&1)"; rc=$?
check "status without NetBeans is an error" test "$rc" = 1
rm -f "$E"
rc=0; NBKIT_UI_EVENTS="$E" NBKIT_DIR="$NBKIT_DIR" setsid -w bash -c 'source "$NBKIT_DIR/lib/terminal.sh"; ask_yn "Go on?" Y' </dev/null >/dev/null 2>&1 || rc=$?
check "a question without a terminal takes the default" test "$rc" = 0
check "a question is an ask event, then answered" test "$(cat "$E")" = '{"ev":"ask","text":"Go on?","default":"Y"}
{"ev":"answered"}'

echo "Restore and delete a backup from the arguments"
B="$(ls "$U"/nbkit-theme-backup-*.tar.gz)"
out="$(nbkit restore)"; rc=$?
check "restore without the file is an error" test "$rc" = 1
contains "restore says what it needs" "$out" "restore needs the backup file"
out="$(nbkit delete-backup "$NBKIT_DIR/LICENSE")"; rc=$?
check "a file that is not a backup is refused" test "$rc" = 1
contains "a file that is not a backup is named" "$out" "is not a backup of any module of this userdir"
out="$(nbkit restore "$B")"; rc=$?
check "restore exits with 0" test "$rc" = 0
json="$(nbkit status --json)"
check "after restoring the original the theme is not installed" test "$(jget "$json" "[m['status'] for m in d['modules']]")" = "['no', 'ok']"
check "the restored UI file is the original one" grep -qx 'Component.arc=8' "$U/config/LookAndFeel/FlatDarkLaf.properties"
out="$(nbkit delete-backup "$B")"; rc=$?
check "delete-backup exits with 0" test "$rc" = 0
check "delete-backup deletes the file" test ! -e "$B"

echo "Tools engine (a tool made only of tool.sh)"
K2="$WORK/kit2"
cp -r "$NBKIT_DIR" "$K2"
mkdir -p "$K2/modules/tools/notes" "$K2/modules/tools/empty"
printf '[tool]\nname = "Notes"\nversion = 3\n[uninstall]\ngoes = "the notes folder"\n' > "$K2/modules/tools/notes/tool.toml"
cat > "$K2/modules/tools/notes/tool.sh" <<'X'
# a tool without a NetBeans module: writes a folder in config/ (the engine gives it everything else)
tool_notes_paths() { echo config/nbkit-notes; }
tool_notes_install() { step "Notes"; mkdir -p "$C/nbkit-notes"; echo hi > "$C/nbkit-notes/a.txt"; ok "notes written"; }
tool_notes_uninstall() { step "Notes"; rm -rf "$C/nbkit-notes"; ok "notes removed"; }
X
printf '[tool]\nname = "Empty"\nversion = 1\n' > "$K2/modules/tools/empty/tool.toml"
kit2() { HOME="$H" bash "$K2/nbkit.sh" "$@" </dev/null 2>&1; }
# the JSON alone (the warning about the "empty" tool goes to stderr)
kit2_json() { HOME="$H" bash "$K2/nbkit.sh" status --json </dev/null 2>/dev/null; }
new_home "$H"
out="$(kit2 --help)"
contains "the tool shows up" "$out" "Modules: one-dark-pro-mix jsf notes"
contains "a tool that installs nothing is skipped with the reason" "$out" 'tool "empty" skipped: tool.toml has no [netbeans_module] and there is no tool.sh'
before="$(fingerprint "$H")"
out="$(NBKIT_TEST_FAIL_STEP=1 kit2 install notes)"; rc=$?
check "a failure in tool.sh changes nothing" test "$rc/$(fingerprint "$H")" = "1/$before"
out="$(kit2 install notes)"; rc=$?
check "the tool installs with its tool.sh" test "$rc/$(cat "$U/config/nbkit-notes/a.txt" 2>&1)" = "0/hi"
check "the engine records its version" test "$(cat "$U/nbkit/notes.version" 2>&1)" = 3
contains "the engine gives it the status" "$(kit2 status)" "Notes"
check "status --json says it is installed" test "$(jget "$(kit2_json)" "[m['status'] for m in d['modules'] if m['id'] == 'notes']")" = "['ok']"
out="$(kit2 uninstall notes)"; rc=$?
check "the tool uninstalls with its tool.sh" test "$rc" = 0 -a ! -e "$U/config/nbkit-notes"
check "after uninstalling, it is not installed" test "$(jget "$(kit2_json)" "[m['status'] for m in d['modules'] if m['id'] == 'notes']")" = "['no']"

echo "Older versions (the installer before nbkit)"
new_home "$H"
P0="config/Editors/FontsColors/FlatLafDark/org-netbeans-modules-editor-settings-CustomFontsColors-tokenColorings.xml"
(cd "$U" && tar -czf onedark-backup-20250101-000000.tar.gz "$P0")
original="$(sha1sum < "$U/$P0")"
mkdir -p "$U/config/Editors/FontsColors/FlatLafDark/Defaults"
echo '<fontscolors/>' > "$U/config/Editors/FontsColors/FlatLafDark/Defaults/onedark-mix-tokenColorings.xml"
echo 'changed' > "$U/$P0"
out="$(nbkit install one-dark-pro-mix)"; rc=$?
check "install over a theme written inside FlatLaf Dark exits with 0" test "$rc" = 0
contains "it says it fixed the base profile" "$out" "$(sed -n 's/^theme.legacy_fixed=//p' "$NBKIT_DIR/lang/en.lang")"
check "the old theme files leave FlatLaf Dark" test ! -e "$U/config/Editors/FontsColors/FlatLafDark/Defaults/onedark-mix-tokenColorings.xml"
check "FlatLaf Dark comes back from the old backup" test "$(sha1sum < "$U/$P0")" = "$original"
check "the old backup is listed first, as the original" test "$(jget "$(nbkit status --json)" "[(b['file'].split('/')[-1][:15], b['original']) for b in d['backups']]")" = "[('onedark-backup-', True), ('nbkit-theme-bac', False)]"

echo "Run from the interface"
E2="$WORK/outer-events"
: > "$E2"
NBKIT_UI_EVENTS="$E2" NBKIT_TTY=1 bash -c 'source "$1/tests/lib.sh"; echo "${NBKIT_UI_EVENTS:-}${NBKIT_TTY:-}"' _ "$NBKIT_DIR" > "$WORK/env-seen"
check "the tests do not send their steps to the interface that runs them" test -z "$(cat "$WORK/env-seen" "$E2")"

echo "Help"
out="$(nbkit --help)"
contains "help shows the interface" "$out" "nbkit.sh gui"
# the interface leaves the terminal free: nbkit.sh gui returns at once (here without a screen, the window
# itself fails at once too, into the log)
# shellcheck disable=SC1091
if (source "$NBKIT_DIR/lib/gui.sh"; gui_python >/dev/null); then
  start=$SECONDS
  out="$(HOME="$H" DISPLAY="" WAYLAND_DISPLAY="" timeout 20 bash "$NBKIT_DIR/nbkit.sh" gui </dev/null 2>&1)"; rc=$?
  check "nbkit.sh gui gives the terminal back at once" test "$rc" = 0 -a $((SECONDS - start)) -lt 10
  contains "and says where its messages go" "$out" "Interface opened (messages in ~/.cache/nbkit/gui.log)"
  d="$H/.local/share/applications/io.github.gaesyeah.nbkit.desktop"
  check "it adds the menu entry, with the nbkit icon, for the taskbar" grep -q "^Icon=$NBKIT_DIR/lib/gui/icons/hicolor/scalable/apps/io.github.gaesyeah.nbkit.svg\$" "$d"
  check "the icon exists" test -s "$NBKIT_DIR/lib/gui/icons/hicolor/scalable/apps/io.github.gaesyeah.nbkit.svg"
  check "the entry opens this nbkit" grep -qx "Exec=bash \"$NBKIT_DIR/nbkit.sh\" gui" "$d"
fi
out="$(bash "$NBKIT_DIR/src/build.sh" --help 2>&1)"; rc=$?
check "build.sh --help exits with 0" test "$rc" = 0
contains "build.sh --help explains --test" "$out" "runs the JSF tests"
out="$(bash "$NBKIT_DIR/src/build.sh" --nope 2>&1)"; rc=$?
check "build.sh refuses an unknown option" test "$rc" = 1
contains "build.sh names the unknown option" "$out" "unknown option: --nope"
if command -v javac >/dev/null 2>&1; then
  # NetBeans from Flatpak: the log says /app/netbeans, the files are in ~/.local/share/flatpak
  new_home "$H"
  F="$H/.local/share/flatpak/app/org.apache.netbeans/current/active/files/netbeans"
  mkdir -p "$F/platform"
  sed -i "s|Installation *=.*|Installation            = /app/netbeans/nb|" "$U/var/log/messages.log"
  out="$(HOME="$H" NB_HOME='' bash "$NBKIT_DIR/src/build.sh" 2>&1)"
  contains "build.sh finds NetBeans installed with Flatpak" "$out" "NetBeans: $F"
  # Flatpak keeps NetBeans in a long folder: hundreds of jars there make a classpath too big for one argument
  L="$F/$(printf 'x%.0s' $(seq 200))"
  mkdir -p "$L/modules"
  for i in $(seq 1500); do : > "$L/modules/org-netbeans-modules-some-long-module-name-$i.jar"; done
  out="$(HOME="$H" NB_HOME='' bash "$NBKIT_DIR/src/build.sh" 2>&1 </dev/null)"
  lacks "build.sh compiles with a classpath of hundreds of long paths" "$out" "Argument list too long"
  rm -rf "$L"
  out="$(HOME="$H" NB_HOME='' JAVA_HOME="$WORK/no-jdk" bash "$NBKIT_DIR/src/build.sh" 2>&1 </dev/null)"; rc=$?
  contains "build.sh without a JDK says it needs one" "$out" "needs a JDK 17 or newer"
  check "and, with nothing installed, stops with an error" test "$rc" = 1
  # ~/.netbeans as a link to another folder, as on machines where the home folder is elsewhere
  new_home "$WORK/real"
  rm -rf "$H"; mkdir -p "$H"; ln -s "$WORK/real/.netbeans" "$H/.netbeans"
  out="$(HOME="$H" NB_HOME='' bash "$NBKIT_DIR/src/build.sh" 2>&1 </dev/null)"
  contains "build.sh finds NetBeans with ~/.netbeans as a link" "$out" "NetBeans: $(readlink -f "$TESTS/netbeans")"
fi

echo "Questions of the theme only when interactive"
# the font of the theme installed on the machine: the build asks whether to keep yours, but only with the
# menu or NBKIT_TTY=1; with arguments it must not wait on the terminal (it used to, from the tests)
new_home "$H"
mkdir -p "$WORK/bin"
printf '#!/bin/sh\necho "JetBrains Mono"\n' > "$WORK/bin/fc-list"; chmod +x "$WORK/bin/fc-list"
# with a terminal (script), as when you run the tests yourself
out="$(HOME="$H" PATH="$WORK/bin:$PATH" timeout 60 script -qec "bash '$NBKIT_DIR/nbkit.sh' install one-dark-pro-mix" /dev/null </dev/null 2>&1)"; rc=$?
check "install with arguments does not wait for an answer" test "$rc" = 0
contains "and keeps the theme font without asking" "$out" "no terminal to ask: using the theme's"
TP="$U/config/Preferences/org/netbeans/modules/terminal/nb.properties"
check "the NetBeans terminal gets the theme font" grep -qx 'term.fontFamily=JetBrains Mono' "$TP"
HOME="$H" PATH="$WORK/bin:$PATH" bash "$NBKIT_DIR/nbkit.sh" uninstall one-dark-pro-mix </dev/null >/dev/null 2>&1
check "uninstalling takes the font out of the terminal" test ! -e "$TP"
new_home "$H"
mkdir -p "$(dirname "$TP")"; echo 'term.fontFamily=Hack' > "$TP"
out="$(HOME="$H" PATH="$WORK/bin:$PATH" bash "$NBKIT_DIR/nbkit.sh" install one-dark-pro-mix </dev/null 2>&1)"
check "a terminal font you chose is kept" grep -qx 'term.fontFamily=Hack' "$TP"
contains "and the install says so" "$out" "terminal font: kept the one you chose"
HOME="$H" PATH="$WORK/bin:$PATH" bash "$NBKIT_DIR/nbkit.sh" uninstall one-dark-pro-mix </dev/null >/dev/null 2>&1
check "and uninstalling leaves it" grep -qx 'term.fontFamily=Hack' "$TP"
rm -rf "${WORK:?}/bin"

echo "Colors in a terminal"
new_home "$H"
# in a terminal (script): every ✓ in green, every error in red; in a pipe or a file, no colors at all
tty_out() { HOME="$H" timeout 120 script -qec "bash '$NBKIT_DIR/nbkit.sh' $*" /dev/null </dev/null 2>&1 | tr -d '\r'; }
out="$(tty_out install)"
check "every ✓ of the install is green" test -z "$(grep '✓' <<<"$out" | grep -v $'\e\\[32m✓')"
contains "an unknown argument is red" "$(tty_out bogus)" $'\e[31mUnknown argument: bogus'
lacks "without a terminal there are no colors" "$(nbkit status)" $'\e['

echo "Without a command and without a terminal"
new_home "$H"
before="$(fingerprint "$H")"
out="$(HOME="$H" bash "$NBKIT_DIR/nbkit.sh" </dev/null 2>&1)"; rc=$?
check "it exits with 0" test "$rc" = 0
contains "it only shows the status" "$out" "not installed"
check "and changes nothing (it used to install everything)" test "$before" = "$(fingerprint "$H")"

echo "The menu"
new_home "$H"
nbkit install >/dev/null
# the options of the menu in a terminal (script), then Esc to quit; one line, in order
menu_items() {
  printf '\033' | HOME="$H" timeout 30 script -qec "bash '$1'" /dev/null 2>&1 | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' \
    | tr -d '\r' | sed -n 's/^  [> ] \([A-Z]\)/\1/p' | sed 's/ (.*//' | paste -sd '|'
}
items="$(menu_items "$NBKIT_DIR/nbkit.sh")"
contains "by subject: the modules, nbkit itself, development, quit" "$items" \
  "Reinstall|Uninstall|Backups|Put nbkit on the system|Run the tests|Build the modules|Quit"
HOME="$H" bash "$NBKIT_DIR/nbkit.sh" install-self </dev/null >/dev/null 2>&1
contains "once nbkit is on the system, updating and taking it out take its place" "$(menu_items "$NBKIT_DIR/nbkit.sh")" \
  "Reinstall|Uninstall|Backups|Update nbkit|Take nbkit out of the system|Run the tests|Build the modules|Quit"
HOME="$H" bash "$NBKIT_DIR/nbkit.sh" uninstall-self </dev/null >/dev/null 2>&1

echo "nbkit on the system (install-self)"
new_home "$H"
SD="$H/.local/share/nbkit"
out="$(HOME="$H" PATH="/usr/bin:/bin" bash "$NBKIT_DIR/nbkit.sh" install-self </dev/null 2>&1)"; rc=$?
check "install-self exits with 0" test "$rc" = 0
check "it copies nbkit to ~/.local/share/nbkit, as in the release zip (no history, no tests)" test -f "$SD/nbkit.sh" -a ! -e "$SD/.git" -a ! -e "$SD/tests"
check "the nbkit command works from ~/.local/bin" bash -c "HOME='$H' '$H/.local/bin/nbkit' --help | grep -q '^nbkit v'"
check "the menu entry opens the installed copy" grep -qx "Exec=bash \"$SD/nbkit.sh\" gui" "$H/.local/share/applications/io.github.gaesyeah.nbkit.desktop"
contains "without ~/.local/bin in the PATH, it says how to add it" "$out" "fish_add_path ~/.local/bin"
out="$(HOME="$H" DISPLAY="" WAYLAND_DISPLAY="" bash "$NBKIT_DIR/nbkit.sh" gui </dev/null 2>&1)"
check "a gui run from elsewhere keeps the menu entry on the installed copy" grep -qx "Exec=bash \"$SD/nbkit.sh\" gui" "$H/.local/share/applications/io.github.gaesyeah.nbkit.desktop"
out="$(HOME="$H" bash "$H/.local/bin/nbkit" uninstall-self </dev/null 2>&1)"; rc=$?
check "uninstall-self exits with 0" test "$rc" = 0
check "it takes out the command, the menu entry and the copy" test ! -e "$H/.local/bin/nbkit" -a ! -e "$H/.local/share/applications/io.github.gaesyeah.nbkit.desktop" -a ! -e "$SD"
mkdir -p "$SD"; echo x > "$SD/mine"
out="$(HOME="$H" bash "$NBKIT_DIR/nbkit.sh" install-self </dev/null 2>&1)"; rc=$?
check "install-self never writes over a folder that is not an nbkit" test "$rc" = 1 -a -f "$SD/mine"
rm -rf "$SD"
check "status --json says when nbkit is not on the system" bash -c "HOME='$H' bash '$NBKIT_DIR/nbkit.sh' status --json </dev/null | grep -q '\"self_installed\":false'"
HOME="$H" bash "$NBKIT_DIR/nbkit.sh" install-self </dev/null >/dev/null 2>&1
check "and when it is, running from that copy" bash -c "HOME='$H' '$H/.local/bin/nbkit' status --json </dev/null | grep -q '\"self_installed\":true,\"self_running\":true'"
check "the installed copy is not a clone (no tests, no development section)" test ! -e "$SD/tests"
# a newer release, served from a file: the zip of a copy with another version
mkdir -p "$WORK/rel/nbkit"
tar -C "$NBKIT_DIR" --exclude=./.git -cf - . | tar -C "$WORK/rel/nbkit" -xf -
sed -i 's/^NBKIT_VERSION=.*/NBKIT_VERSION=9.9.9/' "$WORK/rel/nbkit/nbkit.sh"
(cd "$WORK/rel" && python3 -c 'import shutil; shutil.make_archive("nbkit", "zip", ".", "nbkit")')
mkdir -p "$WORK/tmp"
out="$(HOME="$H" TMPDIR="$WORK/tmp" NBKIT_OFFLINE='' NBKIT_RELEASE_URL="file://$WORK/rel/nbkit.zip" "$H/.local/bin/nbkit" update-self </dev/null 2>&1)"; rc=$?
check "update-self exits with 0" test "$rc" = 0
check "and leaves no download behind" test -z "$(ls -A "$WORK/tmp")"
check "it installs the latest release over the copy" bash -c "HOME='$H' '$H/.local/bin/nbkit' --help | grep -q '^nbkit v9.9.9'"
out="$(HOME="$H" TMPDIR="$WORK/tmp" NBKIT_OFFLINE='' NBKIT_RELEASE_URL="file://$WORK/rel/nbkit.zip" "$H/.local/bin/nbkit" update-self </dev/null 2>&1)"
contains "with nothing newer, it says it is up to date" "$out" "already the latest version (v9.9.9)"
check "(and leaves no download behind)" test -z "$(ls -A "$WORK/tmp")"
out="$(HOME="$H" TMPDIR="$WORK/tmp" NBKIT_OFFLINE='' NBKIT_RELEASE_URL="file://$WORK/rel/missing.zip" "$H/.local/bin/nbkit" update-self </dev/null 2>&1)"; rc=$?
check "a failed download stops update-self and leaves nothing behind" test "$rc" = 1 -a -z "$(ls -A "$WORK/tmp")"
mkdir -p "$WORK/bad/nbkit"; printf 'NBKIT_VERSION=9.9.10\nexit 3\n' > "$WORK/bad/nbkit/nbkit.sh"
(cd "$WORK/bad" && python3 -c 'import shutil; shutil.make_archive("nbkit", "zip", ".", "nbkit")')
out="$(HOME="$H" TMPDIR="$WORK/tmp" NBKIT_OFFLINE='' NBKIT_RELEASE_URL="file://$WORK/bad/nbkit.zip" "$H/.local/bin/nbkit" update-self </dev/null 2>&1)"; rc=$?
check "a release that fails to install stops update-self and leaves nothing behind" test "$rc" != 0 -a -z "$(ls -A "$WORK/tmp")"
check "(the installed copy stays as it was)" bash -c "HOME='$H' '$H/.local/bin/nbkit' --help | grep -q '^nbkit v9.9.9'"
# Ctrl+C in the middle of it (the downloaded install-self interrupts the update-self that runs it)
printf 'NBKIT_VERSION=9.9.11\nkill -INT $PPID\n' > "$WORK/bad/nbkit/nbkit.sh"; rm -f "$WORK/bad/nbkit.zip"
(cd "$WORK/bad" && python3 -c 'import shutil; shutil.make_archive("nbkit", "zip", ".", "nbkit")')
out="$(HOME="$H" TMPDIR="$WORK/tmp" NBKIT_OFFLINE='' NBKIT_RELEASE_URL="file://$WORK/bad/nbkit.zip" "$H/.local/bin/nbkit" update-self </dev/null 2>&1)"; rc=$?
check "Ctrl+C in the middle of update-self leaves nothing behind either" test "$rc" = 130 -a -z "$(ls -A "$WORK/tmp")"
out="$(HOME="$H" "$H/.local/bin/nbkit" update-self </dev/null 2>&1)"; rc=$?
check "offline, update-self stops and says why" test "$rc" = 1
contains "(it needs the internet)" "$out" "updating needs the internet"
HOME="$H" "$H/.local/bin/nbkit" uninstall-self </dev/null >/dev/null 2>&1
rm -rf "$WORK/rel" "$WORK/bad" "$WORK/tmp"

echo "One change at a time in a userdir"
new_home "$H"
before="$(fingerprint "$H")"
mkdir -p "$WORK/run"
# another nbkit in the middle of a change: it holds the userdir lock while this one runs
lock="$WORK/run/nbkit-$(printf %s "$U" | md5sum | cut -c1-16).lock"
out="$(XDG_RUNTIME_DIR="$WORK/run" flock "$lock" bash -c 'HOME="$1" bash "$2" install </dev/null 2>&1' _ "$H" "$NBKIT_DIR/nbkit.sh")"; rc=$?
check "with another nbkit changing the userdir, install stops" test "$rc" = 1
contains "and says why" "$out" "another nbkit is already changing this userdir"
check "(it changed nothing)" test "$before" = "$(fingerprint "$H")"
out="$(XDG_RUNTIME_DIR="$WORK/run" nbkit install)"; rc=$?
check "once the other is done, it installs" test "$rc" = 0
rm -rf "$WORK/run"

echo "NetBeans open, with ~/.netbeans as a link"
# as on machines where the home folder is elsewhere: NetBeans says the userdir one way, the interface another
new_home "$WORK/real"
rm -rf "$H"; mkdir -p "$H"; ln -s "$WORK/real/.netbeans" "$H/.netbeans"
# its own output elsewhere: a process left behind would hold the pipe of whoever reads the tests (tee)
bash -c 'sleep 60; :' org.netbeans.Main --userdir "$H/.netbeans/31" </dev/null >/dev/null 2>&1 &
fake=$!
sleep 0.3
for ud in "$H/.netbeans/31" "$WORK/real/.netbeans/31"; do
  out="$(HOME="$H" setsid -w bash "$NBKIT_DIR/nbkit.sh" install jsf "$ud" </dev/null 2>&1)"
  contains "NetBeans is seen open with the userdir as ${ud#"$WORK"/}" "$out" "NetBeans seems to be open"
done
out="$(HOME="$H" bash "$NBKIT_DIR/nbkit.sh" check "$H/.netbeans/31" </dev/null 2>&1)"
contains "a userdir given through the link keeps its ~ path" "$out" "userdir  ~/.netbeans/31"
pkill -P "$fake" 2>/dev/null; kill "$fake" 2>/dev/null; wait "$fake" 2>/dev/null

finish
