#!/usr/bin/env bash
# nbkit: kit de módulos para o Apache NetBeans no Linux (temas e verificações).
# Este arquivo é o CLI: menu, status, progresso, fechar/abrir o NetBeans, backups e ponto de restauração.
# Cada módulo fica em modulos/ (temas em modulos/temas/) e é carregado com source. Veja modulos/LEIAME.md.
set -euo pipefail
# Ctrl+C sai com código 130 (o trap de saída usa isso para desfazer uma instalação pela metade)
trap 'exit 130' INT TERM HUP
NBKIT_VERSION=1
SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "$0")"
NBKIT_DIR="$(dirname "$SELF")"
ME="$(basename "$SELF")"

if [ -t 1 ]; then B=$'\e[1m'; BL=$'\e[1;34m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; D=$'\e[2m'; N=$'\e[0m'
else B=; BL=; G=; Y=; R=; D=; N=; fi
die() { echo "${R}Erro:${N} $*" >&2; exit 1; }
STEP=0; TOTAL=0
step() { STEP=$((STEP + 1)); printf '%s[%d/%d]%s %s\n' "$BL" "$STEP" "$TOTAL" "$N" "$*"; }
ok()   { printf '      %s✓%s %s\n' "$G" "$N" "$*"; }
info() { printf '      %s%s%s\n' "$D" "$*" "$N"; }
warn() { printf '      %s!%s %s\n' "$Y" "$N" "$*"; }

# ---------- registro de módulos ----------
# nbkit_registrar <id> <prefixo das funções> <categoria: tema|ferramenta> <nome> <descrição> <versão>
MODS=()
declare -A MOD_FN=() MOD_CAT=() MOD_NAME=() MOD_DESC=() MOD_VER=()
nbkit_registrar() {
  MODS+=("$1"); MOD_FN[$1]="$2"; MOD_CAT[$1]="$3"; MOD_NAME[$1]="$4"; MOD_DESC[$1]="$5"; MOD_VER[$1]="$6"
}
# chama <prefixo>_<função> do módulo; devolve 0 sem fazer nada se o módulo não tiver a função
mod_call() {
  local id="$1" fn="${MOD_FN[$1]}_$2"; shift 2
  if declare -F "$fn" >/dev/null; then "$fn" "$@"; fi
}
mod_has() { declare -F "${MOD_FN[$1]}_$2" >/dev/null; }
mod_status() { mod_call "$1" status; }  # nao | ok | antiga:<v> | nova:<v>
# compara a versão instalada (arquivo nbkit/<id>.version, ou a antiga passada em $2) com a deste nbkit
version_status() {
  local v; v="$(cat "$(mod_version_file "$1")" 2>/dev/null || echo "${2:-}")"
  if [ -z "$v" ]; then echo "antiga:?"
  elif [ "$v" = "${MOD_VER[$1]}" ]; then echo ok
  elif [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -gt "${MOD_VER[$1]}" ]; then echo "nova:$v"
  else echo "antiga:$v"; fi
}
mod_installed() { [ "$(mod_status "$1")" != nao ]; }
mod_label() {
  local id="$1"
  if [ "${MOD_CAT[$id]}" = tema ]; then echo "Tema ${MOD_NAME[$id]}"; else echo "${MOD_NAME[$id]}"; fi
}

usage() {
  local ids; ids="$(printf '%s ' "${MODS[@]}")"
  cat <<EOF
nbkit v$NBKIT_VERSION: módulos para o NetBeans

Uso:
  bash $ME                                menu: mostra o status e o que dá pra fazer
  bash $ME install [módulo...] [userdir]  instala ou atualiza (sem módulo: todos)
  bash $ME uninstall [módulo...] [userdir] remove (sem módulo: todos os instalados)
  bash $ME check [userdir]                depois de abrir o NetBeans: confere se tudo carregou
  bash $ME --help                         esta ajuda

Módulos: ${ids% }
Se a instalação do NetBeans não for achada: NB_HOME=/caminho/do/netbeans bash $ME
EOF
}

# ---------- carrega os módulos (temas primeiro) ----------
declare -A LOADED=()
[ -d "$NBKIT_DIR/modulos" ] || die "pasta modulos/ não encontrada ao lado de $ME. Baixe a pasta nbkit inteira."
for f in "$NBKIT_DIR"/modulos/temas/*.sh "$NBKIT_DIR"/modulos/*.sh "$NBKIT_DIR"/modulos/*/*.sh; do
  case "${f##*/}" in _*) continue ;; esac   # _motor.sh etc.: carregados pelos próprios módulos
  case "$f" in "$NBKIT_DIR"/modulos/temas/*) [ -n "${LOADED[$f]:-}" ] && continue ;; esac
  LOADED[$f]=1
  [ -f "$f" ] || continue
  # shellcheck disable=SC1090
  source "$f"
done
[ ${#MODS[@]} -gt 0 ] || die "nenhum módulo em $NBKIT_DIR/modulos."

# ---------- argumentos ----------
ACTION=""; UD=""; SEL=()
for a in "$@"; do
  case "$a" in
    -h|--help|help) usage; exit 0 ;;
    install|uninstall|check) [ -z "$ACTION" ] && ACTION="$a" || die "comando repetido: $a" ;;
    todos|all) SEL=("${MODS[@]}") ;;
    *)
      if [ -n "${MOD_FN[$a]:-}" ]; then SEL+=("$a")
      elif [ -d "$a" ]; then UD="$(readlink -f "$a")"
      else echo "Argumento desconhecido: $a" >&2; echo >&2; usage >&2; exit 1; fi ;;
  esac
done

MENU=0; INTERACTIVE=0
if [ -t 0 ] && [ -t 1 ]; then
  if [ $# -eq 0 ]; then MENU=1; INTERACTIVE=1; elif [ "${NBKIT_TTY:-}" = 1 ]; then INTERACTIVE=1; fi
fi
[ -n "$ACTION" ] || ACTION=install
command -v python3 >/dev/null || die "python3 não encontrado."

# ---------- terminal ----------
# pergunta s/n; a letra maiúscula é o padrão do Enter
ask_yn() {
  local a hint="[s/N]"; [ "$2" = S ] && hint="[S/n]"
  printf '%s %s ' "$1" "$hint"
  IFS= read -r a </dev/tty || a=""
  a="${a,,}"
  if [ -z "$a" ]; then [ "$2" = S ]; return; fi
  case "$a" in s|sim|y|yes) return 0 ;; *) return 1 ;; esac
}

# menu com setas; resultado em MENU_IDX (-1 = saiu com Esc ou q). MENU_HINT troca a legenda.
menu() {
  local -a o=("$@"); local n=$# i=${MENU_START:-0} j k rest
  [ "$i" -lt "$n" ] || i=0
  printf '\e[?25l'; trap 'printf "\e[?25h\n"; exit 130' INT
  while :; do
    for ((j = 0; j < n; j++)); do
      if [ $j -eq $i ]; then printf '\r\e[K  %s> %s%s\n' "$BL$B" "${o[j]}" "$N"
      else printf '\r\e[K    %s\n' "${o[j]}"; fi
    done
    printf '\r\e[K  %s%s%s' "$D" "${MENU_HINT:-↑↓ navegar   Enter escolher   Esc sair}" "$N"
    IFS= read -rsn1 k </dev/tty || k=q
    if [ "$k" = $'\e' ]; then
      rest=""; IFS= read -rsn2 -t 0.05 rest </dev/tty || true
      case "$rest" in '[A'|OA) k=up ;; '[B'|OB) k=down ;; '') k=q ;; *) k=x ;; esac
    fi
    case "$k" in
      up|k) i=$(( (i + n - 1) % n )) ;;
      down|j) i=$(( (i + 1) % n )) ;;
      '') break ;;
      q) i=-1; break ;;
    esac
    printf '\r\e[%dA' "$n"
  done
  printf '\r\e[K\e[?25h'; trap 'exit 130' INT
  MENU_IDX=$i
}

# spinner até a condição ser verdadeira; qualquer tecla cancela (retorna 1)
spin_until() {
  local sp='|/-\' i=0 k
  printf '\e[?25l'; trap 'printf "\r\e[K\e[?25h"; exit 130' INT
  while ! "$2"; do
    printf '\r\e[K  %s%s%s %s  %s(Enter cancela)%s' "$Y" "${sp:i%4:1}" "$N" "$1" "$D" "$N"; i=$((i + 1))
    if IFS= read -rsn1 -t 0.25 k </dev/tty; then
      IFS= read -rsn5 -t 0.05 k </dev/tty || true
      printf '\r\e[K\e[?25h'; trap 'exit 130' INT; return 1
    fi
  done
  printf '\r\e[K\e[?25h'; trap 'exit 130' INT
}

HEADER=0
header() { [ $HEADER = 1 ] || echo "${B}nbkit${N} ${D}v$NBKIT_VERSION${N}"; HEADER=1; }

# ---------- userdir ----------
list_userdirs() {
  local d
  ls -d "$HOME"/.netbeans/*/ "$HOME"/snap/netbeans/common/data/*/ 2>/dev/null | grep -E '/[0-9][0-9.]*/$' \
    | awk -F/ '{print $(NF-1) "\t" $0}' | sort -Vr | cut -f2 | while IFS= read -r d; do
      [ -d "$d/config" ] && echo "${d%/}"
    done
  return 0
}
if [ -z "$UD" ]; then
  mapfile -t UDS < <(list_userdirs)
  if [ $MENU = 1 ] && [ ${#UDS[@]} -gt 1 ]; then
    header
    echo "Achei mais de um NetBeans. Em qual deles?"
    echo
    labels=()
    for d in "${UDS[@]}"; do
      l="NetBeans ${d##*/}   ${d/#$HOME/\~}"
      [ -e "$d/modules/nbkit-core.jar" ] || [ -e "$d/modules/com-onedarkmix-netbeans.jar" ] && l="$l   (nbkit instalado)"
      labels+=("$l")
    done
    menu "${labels[@]}"
    [ "$MENU_IDX" -lt 0 ] && { echo; exit 0; }
    UD="${UDS[$MENU_IDX]}"
    echo; echo
  else
    UD="${UDS[0]:-}"
  fi
fi
[ -n "$UD" ] || die "userdir não encontrado. Veja em Help > About (User directory) e passe como argumento."
[ -d "$UD/config" ] || die "'$UD' não parece um userdir do NetBeans (sem pasta config/). Abra o NetBeans uma vez antes."
C="$UD/config"
STATEDIR="$UD/nbkit"
mod_version_file() { echo "$STATEDIR/$1.version"; }

# ---------- NetBeans aberto/fechado ----------
# processos do NetBeans que usam este userdir (o launcher passa --userdir para o java)
nb_pids() {
  local p
  for p in $(pgrep -f 'org.netbeans.Main' 2>/dev/null || true); do
    [ -r "/proc/$p/cmdline" ] || continue
    if tr '\0' '\n' < "/proc/$p/cmdline" 2>/dev/null \
       | grep -xF -e "$UD" -e "-XX:HeapDumpPath=$UD/var/log/heapdump.hprof" >/dev/null; then echo "$p"; fi
  done
  return 0
}
nb_running() {
  if command -v pgrep >/dev/null 2>&1; then [ -n "$(nb_pids)" ]; else [ -e "$UD/lock" ]; fi
}
nb_closed() { ! nb_running; }
CORE_JAR="$UD/modules/nbkit-core.jar"
CORE_XML="$C/Modules/nbkit-core.xml"
# o log desta sessão já listou os módulos ligados (e é mais novo que a instalação)
nb_loaded() {
  local l="$UD/var/log/messages.log"
  [ -e "$l" ] && [ "$l" -nt "$CORE_JAR" ] && grep -q 'Turning on modules' "$l"
}

# como abrir o NetBeans que usou este userdir por último (comando em LAUNCH)
find_launcher() {
  local f inst=""
  LAUNCH=()
  if [ -n "${NB_HOME:-}" ] && [ -x "$NB_HOME/bin/netbeans" ]; then LAUNCH=("$NB_HOME/bin/netbeans"); fi
  if [ ${#LAUNCH[@]} -eq 0 ]; then
    for f in "$UD/var/log/messages.log" "$UD/var/log/messages.log.1"; do
      [ -f "$f" ] && inst="$(sed -n 's/^ *Installation *= *//p' "$f" | tail -1)"
      [ -n "$inst" ] && break
    done
    case "$inst" in
      /app/netbeans/*) if command -v flatpak >/dev/null 2>&1; then LAUNCH=(flatpak run org.apache.netbeans); fi ;;
      /snap/*) if [ -x /snap/bin/netbeans ]; then LAUNCH=(/snap/bin/netbeans); fi ;;
      ?*) if [ -x "$(dirname "$inst")/bin/netbeans" ]; then LAUNCH=("$(dirname "$inst")/bin/netbeans"); fi ;;
    esac
  fi
  if [ ${#LAUNCH[@]} -eq 0 ] && command -v netbeans >/dev/null 2>&1; then LAUNCH=("$(command -v netbeans)"); fi
  [ ${#LAUNCH[@]} -gt 0 ] || return 1
  # o launcher sozinho escolhe o java do sistema, que pode ser antigo demais (o atalho do menu pode usar outro);
  # usa o mesmo Java com que o NetBeans rodou da última vez. Flatpak e Snap já trazem o próprio Java.
  case "${LAUNCH[0]}" in flatpak|/snap/*) ;; *)
    local jdk; jdk="$(nb_java_home)"
    if [ -n "$jdk" ]; then LAUNCH+=(--jdkhome "$jdk"); fi ;;
  esac
  return 0
}
# Java do NetBeans: o do processo aberto (guardado em NB_JDK) ou o "Java Home" do log da última execução
NB_JDK=""
remember_java() {
  local p j
  for p in $(nb_pids); do
    j="$(readlink -f "/proc/$p/exe" 2>/dev/null || true)"
    case "$j" in */bin/java) NB_JDK="${j%/bin/java}"; return 0 ;; esac
  done
  return 0
}
nb_java_home() {
  local f j
  if [ -n "$NB_JDK" ] && [ -x "$NB_JDK/bin/java" ]; then echo "$NB_JDK"; return 0; fi
  for f in "$UD/var/log/messages.log" "$UD/var/log/messages.log.1"; do
    [ -f "$f" ] || continue
    j="$(sed -n 's/^ *Java Home *= *//p' "$f" | tail -1)"
    if [ -n "$j" ] && [ -x "$j/bin/java" ]; then echo "$j"; return 0; fi
  done
  return 0
}
open_netbeans() {
  (cd "$HOME" && setsid "${LAUNCH[@]}" >/dev/null 2>&1 </dev/null &)
  ok "abrindo o NetBeans"
}

# pede para o NetBeans fechar como no File > Exit: ele mesmo pergunta sobre arquivos não salvos e processos rodando.
# 1) opção --nbkit-close do módulo base (ou --onedark-close das versões antigas do tema), pelo launcher;
# 2) wmctrl, se existir: fecha a janela principal como o X da janela;
# 3) sem nenhum dos dois: pede para você fechar.
close_option() {
  if grep -aqs 'nbkit/core/CloseOption' "$CORE_JAR"; then echo --nbkit-close
  elif grep -aqs 'onedarkmix/netbeans/CloseOption' "$UD/modules/com-onedarkmix-netbeans.jar"; then echo --onedark-close
  fi
}
nb_windows() {
  local pid
  command -v wmctrl >/dev/null 2>&1 || return 0
  for pid in $(nb_pids); do wmctrl -lp 2>/dev/null | awk -v p="$pid" '$3 == p && /NetBeans/ {print $1}'; done
  return 0
}
can_close() {
  [ -e "$UD/lock" ] && [ -n "$(close_option)" ] && find_launcher && return 0
  command -v wmctrl >/dev/null 2>&1 && [ -n "$(nb_windows)" ]
}
close_netbeans() {
  local how="" id opt
  opt="$(close_option)"
  if [ -e "$UD/lock" ] && [ -n "$opt" ] && find_launcher; then
    if (cd "$HOME" && timeout 90 "${LAUNCH[@]}" --userdir "$UD" "$opt" </dev/null >/dev/null 2>&1); then how=module; fi
  fi
  if [ -z "$how" ]; then
    for id in $(nb_windows); do wmctrl -i -c "$id" && how=wm; done
  fi
  if [ -n "$how" ]; then
    info "pedi para o NetBeans fechar (como no File > Exit)"
    info "se ele perguntar sobre arquivos não salvos ou processos rodando, responda lá"
    spin_until "Esperando o NetBeans fechar" nb_closed
  else
    info "não consegui pedir para ele fechar sozinho"
    spin_until "Feche o NetBeans para continuar" nb_closed
  fi
}
# garante o NetBeans fechado antes de mexer em arquivos
ensure_closed() {
  nb_running || return 0
  remember_java
  [ $INTERACTIVE = 1 ] || die "o NetBeans parece estar aberto. Feche e rode de novo."
  if can_close; then
    if [ "${NBKIT_CLOSE:-}" != 1 ] && ! ask_yn "O NetBeans está aberto. Fechar ele agora para continuar?" S; then
      echo "Nada foi alterado."; exit 0
    fi
    close_netbeans || { echo "Cancelado. Nada foi alterado."; exit 0; }
  else
    spin_until "O NetBeans está aberto. Feche ele para continuar" nb_closed || { echo "Cancelado. Nada foi alterado."; exit 0; }
  fi
  ok "NetBeans fechado"
  echo
}

# ---------- módulo base (nbkit.core): só a opção de fechar o NetBeans pelo terminal ----------
core_install() {
  mkdir -p "$UD/modules" "$C/Modules"
  base64 -d > "$CORE_JAR" <<'B64'
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
LmNsYXNzUEsFBgAAAAAHAAcA3QEAAPQFAAAAAA==
B64
  echo "13ab07f1072413fac2cf36c8d30d60c01dece3df85c90445b25c2ca88cdb3adb  $CORE_JAR" | sha256sum -c --quiet - || die "o módulo base foi corrompido ao copiar o nbkit."
  cat > "$CORE_XML" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE module PUBLIC "-//NetBeans//DTD Module Status 1.0//EN" "http://www.netbeans.org/dtds/module-status-1_0.dtd">
<module name="nbkit.core">
    <param name="autoload">false</param>
    <param name="eager">false</param>
    <param name="enabled">true</param>
    <param name="jar">modules/nbkit-core.jar</param>
    <param name="reloadable">false</param>
</module>
EOF
  touch "$UD/.lastModified"
}
core_uninstall() {
  rm -f "$CORE_JAR" "$CORE_XML"
  rmdir "$STATEDIR" 2>/dev/null || true
  touch "$UD/.lastModified"
}

# ---------- ponto de restauração ----------
CLEAN=(); SNAP=""; SNAP_OK=0; DONE=0; SNAPPATHS=()
on_exit() {
  local rc=$? p
  if [ "$SNAP_OK" = 1 ] && [ "$DONE" != 1 ]; then
    [ -t 1 ] && printf '\e[?25h'
    echo
    if [ $rc = 130 ]; then echo "${Y}Interrompido.${N} Voltando tudo como estava..."
    else echo "${R}Parou com erro${N} (código $rc). Voltando tudo como estava..."; fi
    for p in "${SNAPPATHS[@]}"; do rm -rf "${UD:?}/$p"; done
    tar -xf "$SNAP" -C "$UD" 2>/dev/null || true
    mod_rollback_extra
    touch "$UD/.lastModified"
    echo "${G}✓${N} nada foi alterado no NetBeans."
  fi
  [ ${#CLEAN[@]} -gt 0 ] && rm -rf "${CLEAN[@]}"
  return 0
}
trap on_exit EXIT
# desfaz o que fica fora do userdir (ex.: backup recém-criado); cada módulo pode ter <prefixo>_rollback
mod_rollback_extra() {
  local id
  for id in "${MODS[@]}"; do mod_call "$id" rollback || true; done
}
snapshot() {
  local id p have=()
  SNAPPATHS=(nbkit modules/nbkit-core.jar config/Modules/nbkit-core.xml)
  for id in "$@"; do
    while IFS= read -r p; do [ -n "$p" ] && SNAPPATHS+=("$p"); done < <(mod_call "$id" caminhos)
  done
  SNAP="$(mktemp)"; CLEAN+=("$SNAP")
  for p in "${SNAPPATHS[@]}"; do [ -e "$UD/$p" ] && have+=("$p"); done
  if [ ${#have[@]} -gt 0 ]; then tar -cf "$SNAP" -C "$UD" "${have[@]}"; else tar -cf "$SNAP" -T /dev/null; fi
  SNAP_OK=1
}

# ---------- instalar / desinstalar / conferir ----------
tmpdir() { local d; d="$(mktemp -d)"; CLEAN+=("$d"); echo "$d"; }

do_install() {
  local id other conflicts=() total=1
  # tema: só um ativo por vez; instalar um tema remove o outro
  for id in "$@"; do
    if [ "${MOD_CAT[$id]}" = tema ]; then
      for other in "${MODS[@]}"; do
        if [ "$other" != "$id" ] && [ "${MOD_CAT[$other]}" = tema ] && mod_installed "$other"; then conflicts+=("$other"); fi
      done
    fi
  done
  for id in "${conflicts[@]}"; do total=$((total + $(mod_call "$id" passos_desinstalar))); done
  for id in "$@"; do total=$((total + $(mod_call "$id" passos_instalar))); done
  if [ $HEADER = 0 ]; then header; echo "  ${D}userdir${N}  ${UD/#$HOME/\~}"; echo; fi
  ensure_closed
  snapshot "$@" "${conflicts[@]}"
  TOTAL=$total
  for id in "${conflicts[@]}"; do
    info "trocando de tema: removendo $(mod_label "$id")"
    mod_call "$id" desinstalar
    rm -f "$(mod_version_file "$id")"
  done
  for id in "$@"; do
    mod_call "$id" instalar
    mkdir -p "$STATEDIR"
    echo "${MOD_VER[$id]}" > "$(mod_version_file "$id")"
  done
  step "Módulo base do nbkit"
  core_install
  ok "pronto (permite fechar o NetBeans pelo terminal)"
  DONE=1
  echo
  echo "${G}${B}Instalado:${N} $(for id in "$@"; do printf '%s; ' "$(mod_label "$id")"; done | sed 's/; $//')"
  after_change install
}

do_uninstall() {
  local id total=0 remaining=0
  for id in "$@"; do total=$((total + $(mod_call "$id" passos_desinstalar))); done
  for id in "${MODS[@]}"; do
    if mod_installed "$id" && [[ " $* " != *" $id "* ]]; then remaining=1; fi
  done
  [ $remaining = 1 ] || total=$((total + 1))
  if [ $HEADER = 0 ]; then header; echo "  ${D}userdir${N}  ${UD/#$HOME/\~}"; echo; fi
  ensure_closed
  snapshot "$@"
  TOTAL=$total
  for id in "$@"; do
    mod_call "$id" desinstalar
    rm -f "$(mod_version_file "$id")"
  done
  if [ $remaining = 0 ]; then
    step "Módulo base do nbkit"
    core_uninstall
    ok "removido (nenhum módulo ficou instalado)"
  fi
  DONE=1
  echo
  echo "${G}${B}Removido:${N} $(for id in "$@"; do printf '%s; ' "$(mod_label "$id")"; done | sed 's/; $//')"
  # backups que o módulo guardou: pergunta se apaga
  if [ $INTERACTIVE = 1 ]; then
    for id in "$@"; do
      mod_has "$id" backups || continue
      mapfile -t BKS < <(mod_call "$id" backups)
      [ ${#BKS[@]} -gt 0 ] || continue
      echo
      if [ ${#BKS[@]} = 1 ]; then q="1 arquivo"; else q="${#BKS[@]} arquivos"; fi
      if ask_yn "Apagar também os backups de $(mod_label "$id") ($q no userdir)?" N; then
        rm -f "${BKS[@]}"; ok "backups apagados"
      fi
    done
  fi
  after_change uninstall
}

# depois de instalar/desinstalar: abrir o NetBeans e, na instalação, conferir sozinho
after_change() {
  if [ $INTERACTIVE != 1 ]; then
    if [ "$1" = install ]; then echo "Depois de abrir o NetBeans, confira com: bash $ME check"; else echo "Abra o NetBeans."; fi
    exit 0
  fi
  echo
  if find_launcher && ask_yn "Abrir o NetBeans agora?" S; then open_netbeans; fi
  if [ "$1" = install ]; then
    if spin_until "Esperando o NetBeans abrir para conferir se tudo carregou" nb_running \
       && spin_until "NetBeans abrindo, esperando carregar os módulos" nb_loaded; then
      sleep 2
      echo
      exec env NBKIT_TTY=1 bash "$SELF" check "$UD"
    fi
    echo "Ok. Para conferir depois, rode o nbkit de novo e escolha \"Conferir\"."
  fi
  exit 0
}

# imprime "  ok/PROBLEMA ..."; módulos retornam 0 ok, 1 corrigível reinstalando, 2 não corrigível
res() {
  if [ "$1" = 0 ]; then printf '  %sok%s       %s\n' "$G" "$N" "$2"; else printf '  %sPROBLEMA%s %s\n' "$R" "$N" "$2"; fi
}
log_has_module() { grep -qE "^\s+$1 \[" "$UD/var/log/messages.log" 2>/dev/null; }
log_module_errors() { grep -E "$1" "$UD/var/log/messages.log" 2>/dev/null | grep -E 'could not|cannot|Exception|SEVERE|disabled|requires' | head -5 || true; }

do_check() {
  local id rc worst=0 fix=() log="$UD/var/log/messages.log"
  header
  echo "  ${D}userdir${N}  ${UD/#$HOME/\~}"
  echo
  local any=0
  for id in "${MODS[@]}"; do mod_installed "$id" && any=1; done
  [ $any = 1 ] || { echo "Nenhum módulo do nbkit instalado neste userdir."; exit 3; }
  if [ ! -e "$log" ] || { [ -e "$CORE_JAR" ] && [ ! "$log" -nt "$CORE_JAR" ]; }; then
    echo "Abra o NetBeans depois da instalação e rode o check de novo."; exit 3
  fi
  echo "${B}Conferindo no NetBeans${N}"
  for id in "${MODS[@]}"; do
    mod_installed "$id" || continue
    echo "  ${B}$(mod_label "$id")${N}"
    rc=0; out="$(mod_call "$id" conferir 2>&1)" || rc=$?
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/  /' 
    if [ $rc = 1 ]; then fix+=("$id"); fi
    [ $rc -gt $worst ] && worst=$rc
  done
  local j; j="$(sed -n 's/^ *Java; VM; Vendor *= *\([^;]*\).*/\1/p' "$log" | tail -1)"
  [ -n "$j" ] && printf '  %sinfo%s     Java do NetBeans: %s\n' "$D" "$N" "$j"
  echo
  if [ $worst = 0 ]; then echo "${G}Tudo certo.${N}"; exit 0; fi
  echo "Há problemas acima."
  if [ ${#fix[@]} -gt 0 ] && [ $INTERACTIVE = 1 ]; then
    echo
    if ask_yn "Reinstalar para corrigir?" S; then echo; exec env NBKIT_TTY=1 NBKIT_CLOSE=1 bash "$SELF" install "${fix[@]}" "$UD"; fi
  else
    echo "Se precisar, mande essa saída."
  fi
  exit "$worst"
}

# ---------- backups (módulos que guardam o estado de antes: <prefixo>_backups) ----------
bk_date() {
  local b; b="$(basename "$1" .tar.gz)"; b="${b##*-backup-}"
  if [[ "$b" =~ ^([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2})$ ]]; then
    echo "${BASH_REMATCH[3]}/${BASH_REMATCH[2]}/${BASH_REMATCH[1]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}"
  else echo "$b"; fi
}
bk_size() { local b; b=$(stat -c %s "$1" 2>/dev/null || echo 0); echo "$(( (b + 1023) / 1024 )) KB"; }
# todos os backups: "id<TAB>arquivo", do mais antigo para o mais novo dentro de cada módulo
all_backups() {
  local id f
  for id in "${MODS[@]}"; do
    mod_has "$id" backups || continue
    while IFS= read -r f; do [ -n "$f" ] && printf '%s\t%s\n' "$id" "$f"; done < <(mod_call "$id" backups)
  done
  return 0
}
# navega pelos backups: Enter restaura, Del apaga, Esc volta. Restaurar confirmado fica em RESTORE_ID/RESTORE_BK
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
    echo "  ${B}Backups${N}  ${D}${UD/#$HOME/\~}${N}"
    echo
    for ((j = 0; j < n; j++)); do
      id="${rows[j]%%$'\t'*}"; f="${rows[j]#*$'\t'}"
      line="$(bk_date "$f")   $(printf '%6s' "$(bk_size "$f")")   $(mod_call "$id" backup_desc "$f")"
      [ "$mods" -gt 1 ] && line="$(mod_label "$id"): $line"
      first="$(mod_call "$id" backups | head -1)"
      [ "$f" = "$first" ] && line="$line   ${D}(original, usado ao desinstalar)${N}"
      if [ $j -eq $i ]; then printf '  %s> %s%s\n' "$BL$B" "$line" "$N"; else printf '    %s\n' "$line"; fi
    done
    echo
    printf '  %s↑↓ navegar   Enter restaurar   Del apagar   Esc voltar%s' "$D" "$N"
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
        if [ "$(mod_call "$id" backups | wc -l)" = 1 ] && mod_installed "$id"; then
          echo "  ${Y}É o único backup.${N} Sem ele, desinstalar $(mod_label "$id") não tem como voltar o que você tinha antes."
          echo
        fi
        if ask_yn "Apagar o backup de $(bk_date "$f")?" N; then
          rm -f "$f"; ok "backup apagado"; sleep 0.8
        fi ;;
      '')
        printf '\e[?25h\n\n'
        echo "  Volta como estava em $(bk_date "$f"): $(mod_call "$id" backup_desc "$f")."
        if mod_installed "$id"; then
          echo "  Antes disso, $(mod_label "$id") é desinstalado."
        else
          echo "  O que você tem hoje nessas configurações vira um backup novo, então dá pra desfazer."
        fi
        echo
        if ask_yn "Restaurar este backup?" N; then RESTORE_BK="$f"; RESTORE_ID="$id"; break; fi ;;
    esac
  done
  printf '\e[?25h\e[?1049l'; trap 'exit 130' INT
}
do_restore() {
  local id="$1" f="$2" total
  total="$(mod_call "$id" passos_restaurar "$f")"
  if [ $HEADER = 0 ]; then header; echo "  ${D}userdir${N}  ${UD/#$HOME/\~}"; echo; fi
  ensure_closed
  snapshot "$id"
  TOTAL=$total
  mod_call "$id" restaurar "$f"
  mod_installed "$id" || rm -f "$(mod_version_file "$id")"
  local any=0 m
  for m in "${MODS[@]}"; do mod_installed "$m" && any=1; done
  [ $any = 1 ] || core_uninstall
  DONE=1
  echo
  echo "${G}${B}Restaurado.${N}"
  after_change restore
}

# ---------- status e menu ----------
status_line() {
  local id="$1" s v
  s="$(mod_status "$id")"; v="${MOD_VER[$id]}"
  case "$s" in
    ok) printf '%s● instalado%s %s(v%s)%s' "$G" "$N" "$D" "$v" "$N" ;;
    antiga:\?) printf '%s● instalado (versão anterior), atualização disponível (v%s)%s' "$Y" "$v" "$N" ;;
    antiga:*) printf '%s● instalado (v%s), atualização disponível (v%s)%s' "$Y" "${s#antiga:}" "$v" "$N" ;;
    nova:*) printf '%s● instalado (v%s, mais nova que esta)%s' "$Y" "${s#nova:}" "$N" ;;
    *) printf '○ não instalado' ;;
  esac
}
# submenu de módulos: "Todos" + cada um. Resultado em PICK (lista de ids); vazio = voltou com Esc
pick_modules() {
  local title="$1"; shift
  local ids=("$@") opts=() id
  PICK=()
  if [ ${#ids[@]} = 1 ]; then PICK=("${ids[0]}"); return 0; fi
  opts=("Todos")
  for id in "${ids[@]}"; do opts+=("$(mod_label "$id")"); done
  echo "  ${B}$title${N}"
  MENU_START=0 MENU_HINT="↑↓ navegar   Enter escolher   Esc voltar" menu "${opts[@]}"
  if [ "$MENU_IDX" -lt 0 ]; then
    printf '\e[%dA\r\e[J' "$(( ${#opts[@]} + 1 ))"
    return 0
  fi
  if [ "$MENU_IDX" = 0 ]; then PICK=("${ids[@]}"); else PICK=("${ids[$((MENU_IDX - 1))]}"); fi
  # tema: com "Todos", instala só o primeiro tema da lista (um tema ativo por vez)
  local out=() tema=""
  for id in "${PICK[@]}"; do
    if [ "${MOD_CAT[$id]}" = tema ]; then [ -z "$tema" ] && { tema="$id"; out+=("$id"); }; else out+=("$id"); fi
  done
  PICK=("${out[@]}")
}

if [ $MENU = 1 ]; then
  header
  echo "  ${D}userdir${N}  ${UD/#$HOME/\~}"
  w=0
  for id in "${MODS[@]}"; do l="$(mod_label "$id")"; [ ${#l} -gt $w ] && w=${#l}; done
  for id in "${MODS[@]}"; do
    l="$(mod_label "$id")"
    printf '  %s%*s%s\n' "$l" $((w + 3 - ${#l})) '' "$(status_line "$id")"
  done
  echo
  MENU_START=0
  while :; do
    pending=(); current=(); installed=()
    for id in "${MODS[@]}"; do
      case "$(mod_status "$id")" in
        ok|nova:*) current+=("$id"); installed+=("$id") ;;
        antiga:*) pending+=("$id"); installed+=("$id") ;;
        *) pending+=("$id") ;;
      esac
    done
    opts=(); acts=()
    if [ ${#pending[@]} -gt 0 ]; then
      if [ ${#installed[@]} = 0 ]; then opts+=("Instalar"); else opts+=("Instalar ou atualizar"); fi; acts+=(install)
    fi
    if [ ${#current[@]} -gt 0 ]; then opts+=("Reinstalar"); acts+=(reinstall); fi
    if [ ${#installed[@]} -gt 0 ] && [ -e "$UD/var/log/messages.log" ] && [ -e "$CORE_JAR" ] && [ "$UD/var/log/messages.log" -nt "$CORE_JAR" ]; then
      opts+=("Conferir se carregou no NetBeans"); acts+=(check)
    fi
    nbk="$(all_backups | wc -l)"
    if [ "$nbk" -gt 0 ]; then opts+=("Backups ($nbk)"); acts+=(backups); fi
    if [ ${#installed[@]} -gt 0 ]; then opts+=("Desinstalar"); acts+=(uninstall); fi
    opts+=("Sair"); acts+=(quit)
    menu "${opts[@]}"
    [ "$MENU_IDX" -lt 0 ] && { echo; exit 0; }
    act="${acts[$MENU_IDX]}"
    MENU_START=$MENU_IDX
    back() { printf '\e[%dA\r\e[J' "${#opts[@]}"; }
    case "$act" in
      quit) echo; exit 0 ;;
      check) echo; echo; do_check ;;
      backups)
        browse_backups
        if [ -n "$RESTORE_BK" ]; then echo; echo; do_restore "$RESTORE_ID" "$RESTORE_BK"; fi
        back; continue ;;
      install|reinstall|uninstall)
        if [ "$act" = install ]; then list=("${pending[@]}"); title="Instalar"
        elif [ "$act" = reinstall ]; then list=("${current[@]}"); title="Reinstalar"
        else list=("${installed[@]}"); title="Desinstalar"; fi
        back
        pick_modules "$title" "${list[@]}"
        if [ ${#PICK[@]} = 0 ]; then continue; fi
        echo
        if [ "$act" = uninstall ]; then
          for id in "${PICK[@]}"; do
            echo "  ${B}$(mod_label "$id")${N}"
            mod_call "$id" resumo_desinstalar
          done
          echo
          ask_yn "Desinstalar?" N || { echo "Nada foi alterado."; exit 0; }
          echo
          do_uninstall "${PICK[@]}"
        else
          do_install "${PICK[@]}"
        fi ;;
    esac
  done
fi

# ---------- sem menu (argumentos) ----------
case "$ACTION" in
  check) do_check ;;
  install)
    [ ${#SEL[@]} -gt 0 ] || SEL=("${MODS[@]}")
    # um tema por vez
    sel2=(); tema=""
    for id in "${SEL[@]}"; do
      if [ "${MOD_CAT[$id]}" = tema ]; then [ -z "$tema" ] && { tema="$id"; sel2+=("$id"); }; else sel2+=("$id"); fi
    done
    do_install "${sel2[@]}" ;;
  uninstall)
    if [ ${#SEL[@]} = 0 ]; then for id in "${MODS[@]}"; do mod_installed "$id" && SEL+=("$id"); done; fi
    [ ${#SEL[@]} -gt 0 ] || { echo "Nada instalado."; exit 0; }
    do_uninstall "${SEL[@]}" ;;
esac
