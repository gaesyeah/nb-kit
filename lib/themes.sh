# shellcheck shell=bash
# nbkit theme engine: everything any theme needs, without a single color.
# Each theme is a folder in modules/themes/ with only data, no code:
#   theme.toml      name, version, profile, font, terminal selection color
#   ui.properties   FlatLaf keys (UI colors), copied as they are
#   colors.toml     editor colors
# The Python parts are in lib/themes/. nbkit.sh loads this file; it registers every theme folder it finds.
# See "Creating a theme" in the README.

[ -n "${NBKIT_THEME_ENGINE:-}" ] && return 0
NBKIT_THEME_ENGINE=1
THEMES_LIB="$NBKIT_DIR/lib/themes"

# ---------- registration ----------
# theme_register <id> <prefix> "<name>" "<description>" <version> <folder>
# creates the nbkit contract functions (<prefix>_install etc.) pointing to the engine
declare -A THEME_DIRS=()
theme_register() {
  local id="$1" p="$2" f
  nbkit_register "$id" "$p" theme "$3" "$4" "$5"
  THEME_DIRS[$id]="$6"
  for f in status paths uninstall_summary rollback backups backup_desc install_steps uninstall_steps \
           restore_steps install uninstall restore check; do
    eval "${p}_$f() { theme_use $id $p; theme_$f \"\$@\"; }"
  done
}

# defaults (a theme changes what it needs in <prefix>_config)
theme_defaults() {
  THEME_PROFILE=""                                 # name of the color profile created
  THEME_BASE="FlatLafDark"                         # NetBeans profile copied as the base (folder)
  THEME_BASE_NAME="FlatLaf Dark"                   # its name in the messages
  THEME_BASE_PROFILE="FlatLaf Dark"                # profile selected on uninstall, if there was no other
  THEME_LAF="com.formdev.flatlaf.FlatDarkLaf"      # look and feel selected
  THEME_LAF_FILE="FlatDarkLaf.properties"          # properties file of that look and feel
  THEME_TERMINAL_SELECTION=""                      # terminal selection color (ARGB integer, as NetBeans saves it)
  THEME_FONT_NAME=""                               # editor font (empty: left alone)
  THEME_FONT_DIR=""                                # folder in ~/.local/share/fonts
  THEME_FONT_URLS=()                               # .ttf files to download if the font is missing
  THEME_FONT_LICENSE=""                            # license downloaded with it
  THEME_FONT_SOURCE=""                             # where it comes from (message)
  # languages whose base profile colors go into the backup
  THEME_MIMES="text/css text/html text/javascript text/textmate text/x-apache-conf text/x-diff text/x-el text/x-env text/x-java text/x-jflex text/x-json text/x-jsp text/x-markdown text/x-nbs text/x-neon text/x-oql text/x-php5 text/x-properties text/x-repl text/x-sql text/x-tag text/x-terraform+x-hcl text/x-tfvars+x-hcl text/x-toml text/x-tpl text/xhtml text/xml text/xml-external-parsed-entity"
}

theme_use() {
  THEME_ID="$1"; THEME_P="$2"; THEME_DIR="${THEME_DIRS[$1]}"
  theme_defaults
  "${2}_config"
  COLORS_JAR="$UD/modules/nbkit-colors.jar"
  COLORS_XML="$UD/config/Modules/nbkit-colors.xml"
  TERMPREF="$UD/config/Preferences/org/netbeans/modules/terminal/nb.properties"
  LAFT="config/LookAndFeel/$THEME_LAF_FILE"
  THEME_STATE="$UD/nbkit/theme-state.json"
  THEME_MANIFEST="$UD/nbkit/theme-manifest.json"
  export NBKIT_THEME_STATE="$THEME_STATE" NBKIT_THEME_MANIFEST="$THEME_MANIFEST" NBKIT_THEME_BASE="$THEME_BASE" \
    NBKIT_THEME_BASE_NAME="$THEME_BASE_NAME" NBKIT_THEME_BASE_PROFILE="$THEME_BASE_PROFILE" NBKIT_THEME_PROFILE="$THEME_PROFILE" \
    NBKIT_THEME_LAF="$THEME_LAF"
  # what the theme changes in the base profile and in the UI (backup and restore)
  TARGETS=("$LAFT" "config/Editors/FontsColors/$THEME_BASE")
  local m
  for m in $THEME_MIMES; do TARGETS+=("config/Editors/$m/FontsColors/$THEME_BASE"); done
}

# ---------- older versions ----------
# The One Dark Pro Mix installer (netbeans-onedark.sh, before nbkit) and the first nbkit versions (v28, names in
# Portuguese) were published too; what they left in a userdir is recognized and moved or cleaned here and in
# theme_marked, theme_font_marked, theme_remove_modules, theme_paths and theme_backups.

# versions up to v17 of the installer wrote the theme inside FlatLaf Dark itself
theme_legacy_inside_base() {
  [ -e "$C/Editors/FontsColors/FlatLafDark/Defaults/onedark-mix-tokenColorings.xml" ] \
    || [ -e "$C/Editors/text/css/FontsColors/FlatLafDark/Defaults/onedark-mix-tokenColorings.xml" ]
}
# theme_legacy_restore_base <first backup>: brings the original colors of the base profile back from it
theme_legacy_restore_base() {
  local t
  for t in "${TARGETS[@]}"; do case "$t" in config/Editors/*) rm -rf "${UD:?}/$t" ;; esac; done
  if [ -n "$1" ]; then tar -xzf "$1" -C "$UD" --wildcards 'config/Editors/*' 2>/dev/null || true; fi
}

# state files with old names move to the new ones
theme_migrate() {
  local old
  mkdir -p "$UD/nbkit"
  for old in "$UD/nbkit/tema-estado.json" "$UD/onedark-state.json"; do
    if [ -f "$old" ] && [ ! -f "$THEME_STATE" ]; then mv "$old" "$THEME_STATE"; fi
  done
  for old in "$UD/nbkit/tema-manifest.json" "$UD/onedark-manifest.json"; do
    if [ -f "$old" ] && [ ! -f "$THEME_MANIFEST" ]; then mv "$old" "$THEME_MANIFEST"; fi
  done
  rm -f "$UD/nbkit/tema-estado.json" "$UD/onedark-state.json" "$UD/nbkit/tema-manifest.json" "$UD/onedark-manifest.json"
  return 0
}

theme_marked() { grep -qsE '^# (nbkit theme|nbkit tema|One Dark Pro Mix)' "$UD/$LAFT"; }
theme_font_marked() {
  local d="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/$THEME_FONT_DIR"
  [ -n "$THEME_FONT_DIR" ] && { [ -e "$d/.nbkit-installed" ] || [ -e "$d/.onedark-installed" ]; }
}
# coloring module of this version and of older ones (theme v28: nbkit.cores; old installer: com.onedarkmix.netbeans)
theme_remove_modules() {
  rm -f "$COLORS_JAR" "$COLORS_XML" "$UD/modules/nbkit-cores.jar" "$UD/config/Modules/nbkit-cores.xml" \
    "$UD/modules/com-onedarkmix-netbeans.jar" "$UD/config/Modules/com-onedarkmix-netbeans.xml"
}

# ---------- nbkit contract ----------
theme_status() {
  local legacy=""
  if declare -F "${THEME_P}_legacy_version" >/dev/null; then legacy="$("${THEME_P}_legacy_version")"; fi
  if [ -d "$UD/config/Editors/FontsColors/$THEME_PROFILE" ] || [ -f "$(mod_version_file "$THEME_ID")" ] || [ -n "$legacy" ]; then
    version_status "$THEME_ID" "$legacy"
  else
    echo no
  fi
}

theme_paths() {
  printf '%s\n' config/Editors config/LookAndFeel config/.nbattrs config/Preferences/laf.properties \
    config/Preferences/org/netbeans/modules/terminal/nb.properties config/Modules/nbkit-colors.xml modules/nbkit-colors.jar \
    config/Modules/nbkit-cores.xml modules/nbkit-cores.jar \
    config/Modules/com-onedarkmix-netbeans.xml modules/com-onedarkmix-netbeans.jar onedark-manifest.json onedark-state.json \
    onedark-version
}

theme_uninstall_summary() {
  local term=""
  [ -n "$THEME_TERMINAL_SELECTION" ] && term="$(t theme.summary_out_terminal)"
  t theme.summary_out "$THEME_PROFILE" "$term"; echo
  t theme.summary_back; echo
  if theme_font_marked; then
    t theme.summary_stays_font_out "$THEME_BASE_NAME" "$THEME_FONT_NAME"; echo
  elif [ -n "$THEME_FONT_NAME" ]; then
    t theme.summary_stays_font "$THEME_BASE_NAME" "$THEME_FONT_NAME"; echo
  else
    t theme.summary_stays "$THEME_BASE_NAME"; echo
  fi
}

THEME_BK=""
theme_rollback() {
  if [ -n "$THEME_BK" ]; then rm -f "$THEME_BK"; fi
}

# backups of the state before the theme, from the oldest to the newest (includes those of older versions)
theme_backups() {
  ls -1 "$UD"/nbkit-theme-backup-*.tar.gz "$UD"/nbkit-tema-backup-*.tar.gz "$UD"/onedark-backup-*.tar.gz 2>/dev/null \
    | awk -F'-backup-' '{print $NF "\t" $0}' | sort | cut -f2
  return 0
}

declare -A THEME_BKDESC=()
# what is inside: UI and/or base profile colors
theme_backup_desc() {
  local l n p=()
  if [ -z "${THEME_BKDESC[$1]:-}" ]; then
    l="$(tar -tzf "$1" 2>/dev/null || true)"
    if grep -qx "$LAFT" <<<"$l"; then p+=("$(t theme.bk_ui "$THEME_LAF_FILE")"); fi
    n="$(grep -oE "^config/Editors/[^/]+/[^/]+/FontsColors/$THEME_BASE/" <<<"$l" | sort -u | wc -l || true)"
    if [ "${n:-0}" -gt 0 ]; then p+=("$(t theme.bk_colors_n "$THEME_BASE_NAME" "$n")")
    elif grep -q "^config/Editors/FontsColors/$THEME_BASE/" <<<"$l"; then p+=("$(t theme.bk_colors "$THEME_BASE_NAME")"); fi
    [ ${#p[@]} -gt 0 ] || p=("$(t theme.bk_empty)")
    THEME_BKDESC[$1]="$(IFS=+; echo "${p[*]}" | sed 's/+/ + /g')"
  fi
  echo "${THEME_BKDESC[$1]}"
}

theme_install_steps() { echo 9; }
theme_uninstall_steps() { echo 3; }
theme_restore_steps() { if [ "$(theme_status)" != no ]; then echo 4; else echo 2; fi; }

# ---------- helpers ----------
theme_backup() {
  local existing=() t
  # reinstall: no backup of the theme itself (otherwise uninstalling would restore it)
  if theme_marked; then return; fi
  for t in "${TARGETS[@]}"; do [ -e "$UD/$t" ] && existing+=("$t"); done
  if [ ${#existing[@]} -gt 0 ]; then
    THEME_BK="$UD/nbkit-theme-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$THEME_BK" -C "$UD" "${existing[@]}"
    ok "$(t theme.backup_saved "${THEME_BK/#$HOME/\~}")"
  else
    ok "$(t theme.backup_nothing)"
  fi
}

theme_remove_targets() {
  local t
  for t in "${TARGETS[@]}"; do rm -rf "${UD:?}/$t"; done
}

# brings the settings covered by the backup back exactly as they were in it
theme_restore_backup() {
  local d; d="$(bk_date "$1")"
  theme_remove_targets
  tar -xzf "$1" -C "$UD"
  touch "$UD/.lastModified"
  ok "$(t theme.restored_as "$(theme_backup_desc "$1")" "$d")"
}

# current look and feel and profile: keeps them (select) or brings them back (restore)
theme_select_state() {
  "$NBKIT_PY" "$THEMES_LIB/state.py" "$UD" "$1" "$2" "$3"
}

# editor font configured today (to tell on uninstall)
theme_current_font() {
  "$NBKIT_PY" "$THEMES_LIB/font.py" text "$1" 2>/dev/null || true
}

# builds the profile (lib/themes/build.py)
theme_builder() {
  "$NBKIT_PY" "$THEMES_LIB/build.py" "$@"
}

# ---------- colors (colors.toml -> NetBeans color files) ----------
COLORS_PREFIX="org-netbeans-modules-editor-settings-CustomFontsColors"
theme_colors() {
  "$NBKIT_PY" "$THEMES_LIB/write_colors.py" "$THEME_DIR" "$FC" "$EC" "$THEME_BASE" "$COLORS_PREFIX"
}

# ---------- font ----------
theme_font() {
  NBKIT_THEME_FONT=""
  export NBKIT_THEME_FONT
  if [ -z "$THEME_FONT_NAME" ]; then
    info "$(t theme.font_none)"
    return 0
  fi
  local dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/$THEME_FONT_DIR" tmp okf=1 u f
  theme_has_font() {
    # no grep -q: with pipefail, grep exiting early would make fc-list fail (SIGPIPE)
    if command -v fc-list >/dev/null 2>&1; then
      fc-list : family 2>/dev/null | grep -E "(^|,)$THEME_FONT_NAME(,|$)" >/dev/null
    else
      local first; first="$(basename "${THEME_FONT_URLS[0]:-x}")"
      ls "$dir/$first" "$HOME/.fonts/$first" /usr/share/fonts/*/"$first" /usr/share/fonts/*/*/"$first" \
         /usr/local/share/fonts/*/"$first" >/dev/null 2>&1
    fi
  }
  download() {
    if command -v curl >/dev/null 2>&1; then curl -fsSL --max-time 60 -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then wget -q -T 60 -O "$2" "$1"
    else return 1; fi
  }
  if theme_has_font; then
    NBKIT_THEME_FONT="$THEME_FONT_NAME"
    info "$(t theme.font_present)"
  elif [ -n "${NBKIT_OFFLINE:-}" ]; then
    info "$(t theme.font_offline)"
  elif [ ${#THEME_FONT_URLS[@]} -gt 0 ]; then
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
      pkg_install curl apt:curl dnf:curl pacman:curl zypper:curl || true
    fi
    if [ -n "$THEME_FONT_SOURCE" ]; then info "$(t theme.font_downloading_from "$THEME_FONT_SOURCE" "$dir")"
    else info "$(t theme.font_downloading "$dir")"; fi
    tmp="$(mktemp -d)"
    for u in "${THEME_FONT_URLS[@]}"; do
      f="$tmp/$(basename "$u")"
      # checks that a real TrueType font came (and not an error page)
      if ! download "$u" "$f" || [ "$(head -c 4 "$f" | od -An -tx1 | tr -d ' \n')" != "00010000" ]; then okf=0; break; fi
    done
    if [ $okf = 1 ]; then
      mkdir -p "$dir"
      cp "$tmp"/*.ttf "$dir"/
      [ -n "$THEME_FONT_LICENSE" ] && { download "$THEME_FONT_LICENSE" "$dir/$(basename "$THEME_FONT_LICENSE")" || true; }
      touch "$dir/.nbkit-installed"
      command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$dir" >/dev/null 2>&1 || true
      if theme_has_font; then NBKIT_THEME_FONT="$THEME_FONT_NAME"; info "$(t theme.font_installed "${#THEME_FONT_URLS[@]}")"; fi
    fi
    rm -rf "$tmp"
    [ -z "$NBKIT_THEME_FONT" ] && t theme.font_failed "$THEME_FONT_NAME" && echo
  fi
  if [ -n "$NBKIT_THEME_FONT" ]; then ok "$(t theme.font_ready)"; fi
  return 0
}

# ---------- install ----------
theme_install() {
  local CURSEL
  theme_migrate
  STAGE="$(tmpdir)"; OLD="$(tmpdir)"
  EC="$STAGE/config"
  FC="$EC/Editors/FontsColors/$THEME_BASE"

  step "$(t theme.step_verify)"
  "$NBKIT_PY" "$THEMES_LIB/verify.py" "$UD"
  ok "$(t theme.nb_found)"

  step "$(t theme.step_backup)"
  if theme_marked; then info "$(t theme.backup_exists)"; fi
  theme_backup

  if [ -n "$THEME_FONT_NAME" ]; then step "$(t theme.step_font "$THEME_FONT_NAME")"; else step "$(t theme.step_font_editor)"; fi
  theme_font

  step "$(t theme.step_base "$THEME_BASE_NAME")"
  # font you used in the base profile (goes to the new profile)
  FONTJSON="$("$NBKIT_PY" "$THEMES_LIB/font.py" json "$C/Editors/FontsColors/$THEME_BASE/$COLORS_PREFIX-tokenColorings.xml" 2>/dev/null || true)"
  if theme_legacy_inside_base; then theme_legacy_restore_base "$(theme_backups | head -1)"; info "$(t theme.legacy_fixed)"; fi
  ok "$(t theme.base_kept "$THEME_BASE_NAME")"

  step "$(t theme.step_colors)"
  # UI: copy to merge your keys later
  if [ -e "$UD/$LAFT" ]; then mkdir -p "$OLD/$(dirname "$LAFT")"; cp -a "$UD/$LAFT" "$OLD/$LAFT"; fi
  rm -f "$UD/$LAFT"
  # the profile is rebuilt on each install; your tweaks (outside Defaults) stay
  find "$C/Editors" -depth -type d -path "*/FontsColors/$THEME_PROFILE/Defaults" -exec rm -rf {} + 2>/dev/null || true
  mkdir -p "$(dirname "$UD/$LAFT")"
  { echo "# nbkit theme: $THEME_PROFILE"; cat "$THEME_DIR/ui.properties"; } > "$UD/$LAFT"
  mkdir -p "$FC"
  theme_colors || die "$(t theme.colors_failed "$THEME_DIR/colors.toml")"
  # NetBeans identifies the type of each color file by this attribute
  cat > "$FC/.nbattrs" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE attributes PUBLIC "-//NetBeans//DTD DefaultAttributes 1.0//EN" "http://www.netbeans.org/dtds/attributes-1_0.dtd">
<attributes version="1.0">
    <fileobject name="$COLORS_PREFIX-tokenColorings.xml">
        <attr name="nbeditor-settings-ColoringType" stringvalue="token"/>
    </fileobject>
    <fileobject name="$COLORS_PREFIX-highlights.xml">
        <attr name="nbeditor-settings-ColoringType" stringvalue="highlight"/>
    </fileobject>
    <fileobject name="$COLORS_PREFIX-annotations.xml">
        <attr name="nbeditor-settings-ColoringType" stringvalue="annotation"/>
    </fileobject>
</attributes>
EOF
  ok "$(t theme.colors_ready)"

  step "$(t theme.step_profile "$THEME_PROFILE" "$THEME_BASE_NAME")"
  { theme_builder "$UD" "$STAGE" "$THEME_PROFILE" "$FONTJSON"; } 2>&1 | sed 's/^/      /'

  step "$(t theme.step_module)"
  mkdir -p "$UD/modules" "$C/Modules"
  theme_remove_modules
  jar_copy nbkit-colors.jar "$COLORS_JAR" || die "$(t theme.module_corrupt)"
  module_xml nbkit.colors > "$COLORS_XML"
  # makes NetBeans read the module list again on the next start
  touch "$UD/.lastModified"
  ok "$(t theme.module_copied)"

  step "$(t theme.step_ui)"
  # Keeps: editor font, entries the theme does not define, your tweaks to theme entries
  # and your keys in the UI file.
  {
  "$NBKIT_PY" "$THEMES_LIB/merge.py" "$UD" "$OLD" "$LAFT"
  } 2>&1 | sed 's/^/      /'
  ok "$(t theme.ui_written "$THEME_LAF_FILE")"

  if [ -n "$THEME_TERMINAL_SELECTION" ]; then step "$(t theme.step_select_terminal)"; else step "$(t theme.step_select)"; fi
  if [ -n "$THEME_TERMINAL_SELECTION" ]; then
    mkdir -p "$(dirname "$TERMPREF")"
    touch "$TERMPREF"
    CURSEL="$(sed -n 's/^term\.selectionBackground=//p' "$TERMPREF" | tail -1)"
    if [ -z "$CURSEL" ]; then
      echo "term.selectionBackground=$THEME_TERMINAL_SELECTION" >> "$TERMPREF"
    elif [ "$CURSEL" != "$THEME_TERMINAL_SELECTION" ]; then
      t theme.terminal_kept; echo
    fi
  fi
  theme_select_state select "$THEME_LAF" "$THEME_PROFILE"
  rm -f "$UD/onedark-version"
  if [ -n "$THEME_TERMINAL_SELECTION" ]; then ok "$(t theme.selected_terminal "$THEME_BASE_NAME" "$THEME_PROFILE")"
  else ok "$(t theme.selected "$THEME_BASE_NAME" "$THEME_PROFILE")"; fi
}

# ---------- uninstall ----------
theme_uninstall() {
  local FONT first fontdir
  theme_migrate
  step "$(t theme.step_remove)"
  FONT="$(theme_current_font "$UD/config/Editors/FontsColors/$THEME_PROFILE/$COLORS_PREFIX-tokenColorings.xml")"
  rm -f "$UD/$LAFT"
  find "$C/Editors" -depth -type d -path "*/FontsColors/$THEME_PROFILE" -exec rm -rf {} + 2>/dev/null || true
  first="${THEME_RESTORE:-$(theme_backups | head -1)}"
  if theme_legacy_inside_base; then theme_legacy_restore_base "$first"; fi
  theme_remove_modules
  ok "$(t theme.removed "$THEME_PROFILE" "$THEME_LAF_FILE")"

  step "$(t theme.step_back)"
  theme_select_state restore "" ""
  ok "$(t theme.back_done)"

  step "$(t theme.step_font_plain)"
  fontdir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/$THEME_FONT_DIR"
  if theme_font_marked; then
    rm -rf "$fontdir"; command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1 || true
    ok "$(t theme.font_removed "$THEME_FONT_NAME")"
  elif [ -n "$THEME_FONT_NAME" ]; then
    info "$(t theme.font_kept_uninstall "$THEME_FONT_NAME")"
  fi
  rm -f "$THEME_MANIFEST" "$UD/onedark-version"
  if [ -n "$THEME_TERMINAL_SELECTION" ] && [ -f "$TERMPREF" ]; then
    sed -i "/^term\.selectionBackground=$THEME_TERMINAL_SELECTION\$/d" "$TERMPREF"
    # empty: the file did not exist before the theme
    [ -s "$TERMPREF" ] || rm -f "$TERMPREF"
  fi
  touch "$UD/.lastModified"
  # restoring a chosen backup: the next step brings everything back from it
  if [ -z "${THEME_RESTORE:-}" ] && [ -n "$first" ] && tar -tzf "$first" "$LAFT" >/dev/null 2>&1; then
    tar -xzf "$first" -C "$UD" "$LAFT"; info "$(t theme.ui_restored "$THEME_LAF_FILE")"
  fi
  [ -n "$FONT" ] && info "$(t theme.removed_font_was "$FONT")"
  ok "$(t theme.done)"
}

# ---------- restore a backup ----------
theme_restore() {
  if [ "$(theme_status)" != no ]; then
    THEME_RESTORE="$1"
    theme_uninstall
    THEME_RESTORE=""
  else
    step "$(t theme.step_backup_now)"
    theme_backup
  fi
  step "$(t theme.step_restore "$(bk_date "$1")")"
  theme_restore_backup "$1"
}

# ---------- check (with NetBeans open) ----------
theme_check() {
  local rc=0
  "$NBKIT_PY" "$THEMES_LIB/check.py" "$UD" || rc=$?
  return $rc
}

# ---------- registers every theme folder ----------
theme_load_all() {
  "$NBKIT_PY" "$THEMES_LIB/load.py" "$1"
}
eval "$(theme_load_all "$NBKIT_DIR/modules/themes")"
