# shellcheck shell=bash
# Backups that modules keep of the state before them (<prefix>_backups): list, describe, restore and
# delete, from the menu, the arguments and the interface. Used by nbkit.sh.

bk_date() {
  local b; b="$(basename "$1" .tar.gz)"; b="${b##*-backup-}"
  if [[ "$b" =~ ^([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2})$ ]]; then
    local f="${L[cli.date_format]}"
    f="${f//\{year\}/${BASH_REMATCH[1]}}"; f="${f//\{month\}/${BASH_REMATCH[2]}}"; f="${f//\{day\}/${BASH_REMATCH[3]}}"
    f="${f//\{hour\}/${BASH_REMATCH[4]}}"; f="${f//\{minute\}/${BASH_REMATCH[5]}}"
    echo "$f"
  else echo "$b"; fi
}
bk_size() { local b; b=$(stat -c %s "$1" 2>/dev/null || echo 0); echo "$(( (b + 1023) / 1024 )) KB"; }
# all backups: "id<TAB>file", from the oldest to the newest inside each module
all_backups() {
  local id f
  for id in "${MODS[@]}"; do
    mod_has "$id" backups || continue
    while IFS= read -r f; do [ -n "$f" ] && printf '%s\t%s\n' "$id" "$f"; done < <(mod_call "$id" backups)
  done
  return 0
}
# backup_owner <file>: "id<TAB>file" of the module that keeps this backup
backup_owner() {
  local id f
  while IFS=$'\t' read -r id f; do
    if [ "$(readlink -f "$f")" = "$1" ]; then printf '%s\t%s\n' "$id" "$f"; return 0; fi
  done < <(all_backups)
  return 1
}
# confirm_restore <id> <file> and confirm_delete_backup <id> <file>: explain and ask (menu, arguments and interface)
confirm_restore() {
  t cli.restore_back_to "$(bk_date "$2")" "$(mod_call "$1" backup_desc "$2")"; echo
  if mod_installed "$1"; then t cli.restore_uninstalls_first "$(mod_label "$1")"; echo
  else t cli.restore_makes_backup; echo; fi
  echo
  ask_yn "$(t cli.ask_restore)" N
}
confirm_delete_backup() {
  if [ "$(mod_call "$1" backups | wc -l)" = 1 ] && mod_installed "$1"; then
    t cli.only_backup "$(mod_label "$1")"; echo
    echo
  fi
  ask_yn "$(t cli.ask_delete_backup "$(bk_date "$2")")" N
}
# browses the backups: Enter restores, Del deletes, Esc goes back. A confirmed restore goes to RESTORE_ID/RESTORE_BK
browse_backups() {
  local -a rows; local i=0 n j k rest line id f first mods
  RESTORE_BK=""; RESTORE_ID=""
  printf '\e[?1049h'; trap 'printf "\e[?25h\e[?1049l"; exit 130' INT
  while :; do
    mapfile -t rows < <(all_backups)
    n=${#rows[@]}
    [ "$n" -gt 0 ] || break
    [ "$i" -lt "$n" ] || i=$((n - 1))
    mods="$(printf '%s\n' "${rows[@]}" | cut -f1 | sort -u | wc -l)"
    printf '\e[H\e[2J\e[?25l'
    echo "${B}nbkit${N} ${D}v$NBKIT_VERSION${N}"
    echo "  ${B}$(t cli.backups_title)${N}  ${D}${UD/#$HOME/\~}${N}"
    echo
    for ((j = 0; j < n; j++)); do
      id="${rows[j]%%$'\t'*}"; f="${rows[j]#*$'\t'}"
      line="$(bk_date "$f")   $(printf '%6s' "$(bk_size "$f")")   $(mod_call "$id" backup_desc "$f")"
      [ "$mods" -gt 1 ] && line="$(mod_label "$id"): $line"
      first="$(mod_call "$id" backups | head -1)"
      [ "$f" = "$first" ] && line="$line   ${D}$(t cli.backup_original)${N}"
      if [ $j -eq $i ]; then printf '  %s> %s%s\n' "$BL$B" "$line" "$N"; else printf '    %s\n' "$line"; fi
    done
    echo
    printf '  %s%s%s' "$D" "$(t cli.backups_hint)" "$N"
    IFS= read -rsn1 k </dev/tty || k=q
    if [ "$k" = $'\e' ]; then
      rest=""; IFS= read -rsn2 -t 0.05 rest </dev/tty || true
      case "$rest" in
        '[A'|OA) k=up ;;
        '[B'|OB) k=down ;;
        '[3') IFS= read -rsn1 -t 0.05 j </dev/tty || true; k=del ;;
        '') k=q ;;
        *) k=x ;;
      esac
    fi
    id="${rows[i]%%$'\t'*}"; f="${rows[i]#*$'\t'}"
    case "$k" in
      up|k) i=$(( (i + n - 1) % n )) ;;
      down|j) i=$(( (i + 1) % n )) ;;
      q) break ;;
      del)
        printf '\e[?25h\n\n'
        if confirm_delete_backup "$id" "$f"; then rm -f "$f"; ok "$(t cli.backup_deleted)"; sleep 0.8; fi ;;
      '')
        printf '\e[?25h\n\n'
        if confirm_restore "$id" "$f"; then RESTORE_BK="$f"; RESTORE_ID="$id"; break; fi ;;
    esac
  done
  printf '\e[?25h\e[?1049l'; trap 'exit 130' INT
}
do_restore() {
  local id="$1" f="$2" total
  total="$(mod_call "$id" restore_steps "$f")"
  if [ $HEADER = 0 ]; then header; userdir_line; echo; fi
  ensure_closed
  snapshot "$id"
  TOTAL=$total
  mod_call "$id" restore "$f"
  # a backup is the state before the module: its version file goes too (it alone would count as installed)
  rm -f "$(mod_version_file "$id")"
  local any=0 m
  for m in "${MODS[@]}"; do mod_installed "$m" && any=1; done
  [ $any = 1 ] || core_uninstall
  DONE=1
  echo
  echo "${G}${B}$(t cli.restored)${N}"
  after_change restore
}
