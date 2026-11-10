# shellcheck shell=bash
# Status of the modules: the lines of the menu and of "status", and "status --json" for the interface
# (lib/gui/model.py). Used by nbkit.sh.

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
# the module lines of the menu (and of "status")
print_status() {
  local id l w=0
  for id in "${MODS[@]}"; do l="$(mod_label "$id")"; [ ${#l} -gt $w ] && w=${#l}; done
  for id in "${MODS[@]}"; do
    l="$(mod_label "$id")"
    printf '  %s%*s%s\n' "$l" $((w + 3 - ${#l})) '' "$(status_line "$id")"
  done
}
# check makes sense: something installed and NetBeans opened after the install
can_check() {
  local id any=0 log="$UD/var/log/messages.log"
  for id in "${MODS[@]}"; do mod_installed "$id" && any=1; done
  [ $any = 1 ] && [ -e "$log" ] && [ -e "$CORE_JAR" ] && [ "$log" -nt "$CORE_JAR" ]
}
# asks before uninstalling (menu and interface): what each module removes
json_bool() { if "$@"; then echo true; else echo false; fi; }
status_json() {
  local d id s inst sep="" f first
  printf '{"version":%s,"lang":%s,"clone":%s,"userdirs":[' "$(json_str "$NBKIT_VERSION")" "$(json_str "$NBKIT_LANG")" \
    "$(json_bool test -f "$NBKIT_DIR/tests/run.sh")"
  for d in ${UDS[@]+"${UDS[@]}"}; do
    printf '%s{"path":%s,"name":%s,"has_nbkit":%s}' "$sep" "$(json_str "$d")" "$(json_str "NetBeans ${d##*/}")" \
      "$(json_bool test -e "$d/modules/nbkit-core.jar")"
    sep=,
  done
  if [ -z "$UD" ]; then printf '],"userdir":null,"modules":[],"backups":[]}\n'; return 0; fi
  printf '],"userdir":%s,"netbeans_running":%s,"can_check":%s,"modules":[' "$(json_str "$UD")" "$(json_bool nb_running)" "$(json_bool can_check)"
  sep=""
  for id in "${MODS[@]}"; do
    s="$(mod_status "$id")"
    case "$s" in ok) inst="$(json_str "${MOD_VER[$id]}")" ;; no|old:\?) inst=null ;; *) inst="$(json_str "${s#*:}")" ;; esac
    printf '%s{"id":%s,"category":%s,"name":%s,"label":%s,"description":%s,"version":%s,"status":%s,"installed":%s}' "$sep" \
      "$(json_str "$id")" "$(json_str "${MOD_CAT[$id]}")" "$(json_str "${MOD_NAME[$id]}")" "$(json_str "$(mod_label "$id")")" \
      "$(json_str "${MOD_DESC[$id]}")" "$(json_str "${MOD_VER[$id]}")" "$(json_str "${s%%:*}")" "$inst"
    sep=,
  done
  printf '],"backups":['
  sep=""
  while IFS=$'\t' read -r id f; do
    [ -n "$f" ] || continue
    first="$(mod_call "$id" backups | head -1)"
    printf '%s{"module":%s,"file":%s,"date":%s,"size":%s,"description":%s,"original":%s}' "$sep" "$(json_str "$id")" \
      "$(json_str "$f")" "$(json_str "$(bk_date "$f")")" "$(json_str "$(bk_size "$f")")" \
      "$(json_str "$(mod_call "$id" backup_desc "$f")")" "$(json_bool test "$f" = "$first")"
    sep=,
  done < <(all_backups)
  printf ']}\n'
}
