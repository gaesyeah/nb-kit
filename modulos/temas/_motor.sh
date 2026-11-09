# Motor de temas do nbkit: tudo o que qualquer tema precisa, sem nenhuma cor.
# Um tema (ex.: one-dark-pro-mix.sh) carrega este arquivo, chama tema_registrar e define:
#   <prefixo>_config     variáveis TEMA_* (perfil, base, visual, fonte, terminal)
#   <prefixo>_interface  conteúdo do arquivo de propriedades do FlatLaf (cores da interface)
#   <prefixo>_cores      cores do editor: cores_tokens, cores_destaques, cores_anotacoes,
#                        cores_linguagem <mime> e cores_extras <mime> (categorias do módulo de coloração)
# Opcional: <prefixo>_versao_legada (versão instalada por um instalador antigo, para oferecer atualização).
# Veja a seção "Criar um tema" no README.

[ -n "${NBKIT_MOTOR_TEMAS:-}" ] && return 0
NBKIT_MOTOR_TEMAS=1

# ---------- registro ----------
# tema_registrar <id> <prefixo> "<nome>" "<descrição>" <versão>
# cria as funções do contrato do nbkit (<prefixo>_instalar etc.) apontando para o motor
tema_registrar() {
  local id="$1" p="$2" f
  nbkit_registrar "$id" "$p" tema "$3" "$4" "$5"
  for f in status caminhos resumo_desinstalar rollback backups backup_desc passos_instalar passos_desinstalar \
           passos_restaurar instalar desinstalar restaurar conferir; do
    eval "${p}_$f() { tema_usar $id $p; tema_$f \"\$@\"; }"
  done
}

# padrões (um tema muda o que precisar em <prefixo>_config)
tema_padroes() {
  TEMA_PERFIL=""                                   # nome do perfil de cores criado
  TEMA_BASE="FlatLafDark"                          # perfil do NetBeans copiado como base (pasta)
  TEMA_BASE_NOME="FlatLaf Dark"                    # nome dele nas mensagens
  TEMA_BASE_PERFIL="FlatLaf Dark"                  # perfil selecionado ao desinstalar, se não havia outro
  TEMA_LAF="com.formdev.flatlaf.FlatDarkLaf"       # visual selecionado
  TEMA_LAF_ARQ="FlatDarkLaf.properties"            # arquivo de propriedades desse visual
  TEMA_TERMINAL_SELECAO=""                         # cor de seleção do terminal (inteiro ARGB, como o NetBeans grava)
  TEMA_FONTE_NOME=""                               # fonte do editor (vazio: não mexe)
  TEMA_FONTE_PASTA=""                              # pasta em ~/.local/share/fonts
  TEMA_FONTE_URLS=()                               # arquivos .ttf para baixar se a fonte faltar
  TEMA_FONTE_LICENCA=""                            # licença baixada junto
  TEMA_FONTE_ORIGEM=""                             # de onde vem (mensagem)
  # linguagens cujas cores do perfil base entram no backup
  TEMA_MIMES="text/css text/html text/javascript text/textmate text/x-apache-conf text/x-diff text/x-el text/x-env text/x-java text/x-jflex text/x-json text/x-jsp text/x-markdown text/x-nbs text/x-neon text/x-oql text/x-php5 text/x-properties text/x-repl text/x-sql text/x-tag text/x-terraform+x-hcl text/x-tfvars+x-hcl text/x-toml text/x-tpl text/xhtml text/xml text/xml-external-parsed-entity"
}

tema_usar() {
  TEMA_ID="$1"; TEMA_P="$2"
  tema_padroes
  "${2}_config"
  CORES_JAR="$UD/modules/nbkit-cores.jar"
  CORES_XML="$UD/config/Modules/nbkit-cores.xml"
  TERMPREF="$UD/config/Preferences/org/netbeans/modules/terminal/nb.properties"
  LAFT="config/LookAndFeel/$TEMA_LAF_ARQ"
  TEMA_ESTADO="$UD/nbkit/tema-estado.json"
  TEMA_MANIFEST="$UD/nbkit/tema-manifest.json"
  export NBKIT_TEMA_ESTADO="$TEMA_ESTADO" NBKIT_TEMA_MANIFEST="$TEMA_MANIFEST" NBKIT_TEMA_BASE="$TEMA_BASE" \
    NBKIT_TEMA_BASE_NOME="$TEMA_BASE_NOME" NBKIT_TEMA_BASE_PERFIL="$TEMA_BASE_PERFIL" NBKIT_TEMA_PERFIL="$TEMA_PERFIL" \
    NBKIT_TEMA_LAF="$TEMA_LAF"
  # o que o tema altera no perfil base e na interface (backup e restauração)
  TARGETS=("$LAFT" "config/Editors/FontsColors/$TEMA_BASE")
  local m
  for m in $TEMA_MIMES; do TARGETS+=("config/Editors/$m/FontsColors/$TEMA_BASE"); done
}

# nomes antigos (instalador One Dark Pro Mix, antes do nbkit) passam para os novos
tema_migrar() {
  mkdir -p "$UD/nbkit"
  [ -f "$UD/onedark-state.json" ] && [ ! -f "$TEMA_ESTADO" ] && mv "$UD/onedark-state.json" "$TEMA_ESTADO"
  [ -f "$UD/onedark-manifest.json" ] && [ ! -f "$TEMA_MANIFEST" ] && mv "$UD/onedark-manifest.json" "$TEMA_MANIFEST"
  rm -f "$UD/onedark-state.json" "$UD/onedark-manifest.json"
  return 0
}

tema_marcado() { grep -qsE '^# (nbkit tema|One Dark Pro Mix)' "$UD/$LAFT"; }
tema_fonte_marcada() {
  local d="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/$TEMA_FONTE_PASTA"
  [ -n "$TEMA_FONTE_PASTA" ] && { [ -e "$d/.nbkit-installed" ] || [ -e "$d/.onedark-installed" ]; }
}

# ---------- contrato do nbkit ----------
tema_status() {
  local legada=""
  if declare -F "${TEMA_P}_versao_legada" >/dev/null; then legada="$("${TEMA_P}_versao_legada")"; fi
  if [ -d "$UD/config/Editors/FontsColors/$TEMA_PERFIL" ] || [ -f "$(mod_version_file "$TEMA_ID")" ] || [ -n "$legada" ]; then
    version_status "$TEMA_ID" "$legada"
  else
    echo nao
  fi
}

tema_caminhos() {
  printf '%s\n' config/Editors config/LookAndFeel config/.nbattrs config/Preferences/laf.properties \
    config/Preferences/org/netbeans/modules/terminal/nb.properties config/Modules/nbkit-cores.xml modules/nbkit-cores.jar \
    config/Modules/com-onedarkmix-netbeans.xml modules/com-onedarkmix-netbeans.jar onedark-manifest.json onedark-state.json \
    onedark-version
}

tema_resumo_desinstalar() {
  echo "    ${B}Sai:${N}   perfil \"$TEMA_PERFIL\", módulo de coloração, interface do tema${TEMA_TERMINAL_SELECAO:+, cor de seleção do terminal}"
  echo "    ${B}Volta:${N} o visual e o perfil de cores que você usava antes"
  if tema_fonte_marcada; then
    echo "    ${B}Fica:${N}  o perfil $TEMA_BASE_NOME, como sempre esteve ${D}(a $TEMA_FONTE_NOME sai: foi o nbkit que instalou)${N}"
  elif [ -n "$TEMA_FONTE_NOME" ]; then
    echo "    ${B}Fica:${N}  o perfil $TEMA_BASE_NOME, como sempre esteve, e a fonte $TEMA_FONTE_NOME"
  else
    echo "    ${B}Fica:${N}  o perfil $TEMA_BASE_NOME, como sempre esteve"
  fi
}

TEMA_BK=""
tema_rollback() {
  if [ -n "$TEMA_BK" ]; then rm -f "$TEMA_BK"; fi
}

# backups do estado de antes do tema, do mais antigo para o mais novo (inclui os do instalador antigo)
tema_backups() {
  ls -1 "$UD"/nbkit-tema-backup-*.tar.gz "$UD"/onedark-backup-*.tar.gz 2>/dev/null \
    | awk -F'-backup-' '{print $NF "\t" $0}' | sort | cut -f2
  return 0
}

declare -A TEMA_BKDESC=()
# o que tem dentro: interface e/ou cores do perfil base
tema_backup_desc() {
  local l n p=()
  if [ -z "${TEMA_BKDESC[$1]:-}" ]; then
    l="$(tar -tzf "$1" 2>/dev/null || true)"
    if grep -qx "$LAFT" <<<"$l"; then p+=("interface ($TEMA_LAF_ARQ)"); fi
    n="$(grep -oE "^config/Editors/[^/]+/[^/]+/FontsColors/$TEMA_BASE/" <<<"$l" | sort -u | wc -l || true)"
    if [ "${n:-0}" -gt 0 ]; then p+=("cores do $TEMA_BASE_NOME ($n linguagens)")
    elif grep -q "^config/Editors/FontsColors/$TEMA_BASE/" <<<"$l"; then p+=("cores do $TEMA_BASE_NOME"); fi
    [ ${#p[@]} -gt 0 ] || p=("vazio")
    TEMA_BKDESC[$1]="$(IFS=+; echo "${p[*]}" | sed 's/+/ + /g')"
  fi
  echo "${TEMA_BKDESC[$1]}"
}

tema_passos_instalar() { echo 9; }
tema_passos_desinstalar() { echo 3; }
tema_passos_restaurar() { if [ "$(tema_status)" != nao ]; then echo 4; else echo 2; fi; }

# ---------- ajudantes ----------
tema_backup() {
  local existing=() t
  # reinstalação: não faz backup do próprio tema (senão o desinstalar restauraria ele)
  if tema_marcado; then return; fi
  for t in "${TARGETS[@]}"; do [ -e "$UD/$t" ] && existing+=("$t"); done
  if [ ${#existing[@]} -gt 0 ]; then
    TEMA_BK="$UD/nbkit-tema-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$TEMA_BK" -C "$UD" "${existing[@]}"
    ok "salvo em ${TEMA_BK/#$HOME/\~}"
  else
    ok "nada para salvar (sem configurações de cor ou interface ainda)"
  fi
}

tema_remove_targets() {
  local t
  for t in "${TARGETS[@]}"; do rm -rf "${UD:?}/$t"; done
}

# volta as configurações cobertas pelo backup exatamente como estavam nele
tema_restore_backup() {
  local d; d="$(bk_date "$1")"
  tema_remove_targets
  tar -xzf "$1" -C "$UD"
  touch "$UD/.lastModified"
  ok "$(tema_backup_desc "$1") como em $d"
}

# visual e perfil atuais: guarda (select) ou volta (restore)
tema_select_state() {
  python3 - "$UD" "$1" "$2" "$3" <<'PY'
import sys, os, json, re, xml.dom.minidom as M
ud, mode, laf, profile = sys.argv[1:5]
attrs = os.path.join(ud, 'config', '.nbattrs')
lafp = os.path.join(ud, 'config', 'Preferences', 'laf.properties')
state = os.environ['NBKIT_TEMA_ESTADO']
def get_profile():
    if os.path.exists(attrs):
        for fo in M.parse(attrs).getElementsByTagName('fileobject'):
            if fo.getAttribute('name') == 'Editors':
                for a in fo.getElementsByTagName('attr'):
                    if a.getAttribute('name') == 'currentFontColorProfile':
                        return a.getAttribute('stringvalue')
    return None
def set_profile(value):
    if os.path.exists(attrs):
        doc = M.parse(attrs)
    else:
        doc = M.parseString('<attributes version="1.0"/>')
    root = doc.documentElement
    fo = next((f for f in root.getElementsByTagName('fileobject') if f.getAttribute('name') == 'Editors'), None)
    if fo is None:
        fo = doc.createElement('fileobject'); fo.setAttribute('name', 'Editors'); root.appendChild(fo)
    for a in list(fo.getElementsByTagName('attr')):
        if a.getAttribute('name') == 'currentFontColorProfile':
            fo.removeChild(a)
    if value is not None:
        a = doc.createElement('attr'); a.setAttribute('name', 'currentFontColorProfile'); a.setAttribute('stringvalue', value)
        fo.appendChild(a)
    body = ''.join(n.toxml() for n in root.childNodes if n.nodeType == 1)
    with open(attrs, 'w') as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE attributes PUBLIC "-//NetBeans//DTD DefaultAttributes 1.0//EN" '
                '"http://www.netbeans.org/dtds/attributes-1_0.dtd">\n<attributes version="1.0">\n' + body + '\n</attributes>\n')
def get_laf():
    if os.path.exists(lafp):
        for l in open(lafp).read().splitlines():
            m = re.match(r'^laf=(.*)$', l)
            if m:
                return m.group(1)
    return None
def set_laf(value):
    lines = open(lafp).read().splitlines() if os.path.exists(lafp) else []
    lines = [l for l in lines if not l.startswith('laf=')] + ([f'laf={value}'] if value else [])
    os.makedirs(os.path.dirname(lafp), exist_ok=True)
    with open(lafp, 'w') as f:
        f.write('\n'.join(lines) + ('\n' if lines else ''))
if mode == 'select':
    if not os.path.exists(state):
        json.dump({'laf': get_laf(), 'profile': get_profile()}, open(state, 'w'))
    set_laf(laf)
    set_profile(profile)
else:
    st = json.load(open(state)) if os.path.exists(state) else {'laf': None, 'profile': os.environ.get('NBKIT_TEMA_BASE_PERFIL', 'FlatLaf Dark')}
    set_laf(st.get('laf'))
    set_profile(st.get('profile'))
    if os.path.exists(state):
        os.remove(state)
PY
}

# fonte do editor configurada hoje (para avisar ao desinstalar)
tema_current_font() {
  python3 - "$1" <<'PY' 2>/dev/null || true
import sys, xml.dom.minidom as M
for e in M.parse(sys.argv[1]).getElementsByTagName('fontcolor'):
    f = e.getElementsByTagName('font')
    if e.getAttribute('name') == 'default' and f and f[0].getAttribute('name'):
        print(f[0].getAttribute('name'), f[0].getAttribute('size'))
PY
}

# constrói o perfil (modo check: só valida a instalação do NetBeans)
tema_builder() {
  python3 - "$@" <<'PY'
import sys, os, re, json, glob, zipfile
import xml.dom.minidom as M

UD, STAGE, PROFILE, FONTJSON = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
BASE = os.environ.get('NBKIT_TEMA_BASE', 'FlatLafDark')            # pasta do perfil do NetBeans copiado
BASE_NOME = os.environ.get('NBKIT_TEMA_BASE_NOME', 'FlatLaf Dark')  # nome dele nas mensagens
EDITORS = os.path.join(UD, 'config', 'Editors')
HDR = ('<?xml version="1.0" encoding="UTF-8"?>\n'
       '<!DOCTYPE fontscolors PUBLIC "-//NetBeans//DTD Editor Fonts and Colors settings 1.2//EN" '
       '"https://netbeans.apache.org/dtds/EditorFontsColors-1_2.dtd">\n')
NBATTRS_HDR = ('<?xml version="1.0" encoding="UTF-8"?>\n'
               '<!DOCTYPE attributes PUBLIC "-//NetBeans//DTD DefaultAttributes 1.0//EN" '
               '"http://www.netbeans.org/dtds/attributes-1_0.dtd">\n')
TYPE_ATTR = 'nbeditor-settings-ColoringType'
USERFILE = 'org-netbeans-modules-editor-settings-CustomFontsColors-tokenColorings.xml'

def die(msg):
    print('Erro: ' + msg, file=sys.stderr)
    sys.exit(2)

# ---------- 1. Onde o NetBeans esta instalado (clusters) ----------
def clusters():
    found = []
    env = os.environ.get('NB_HOME')
    if env:
        found += [d for d in glob.glob(os.path.join(env, '*')) if os.path.isdir(os.path.join(d, 'modules'))]
    log = os.path.join(UD, 'var', 'log', 'messages.log')
    if not found and os.path.exists(log):
        lines = open(log, errors='replace').read().splitlines()
        for i, l in enumerate(lines):
            m = re.match(r'\s*Installation\s*=\s*(\S.*)$', l)
            if m:
                found = [m.group(1).strip()]
                for nxt in lines[i + 1:]:
                    if '=' in nxt or not nxt.strip().startswith('/'):
                        break
                    found.append(nxt.strip())
        hosts = ['/var/lib/flatpak/app/org.apache.netbeans/current/active/files/netbeans',
                 os.path.expanduser('~/.local/share/flatpak/app/org.apache.netbeans/current/active/files/netbeans')]
        mapped = []
        for d in found:
            if d.startswith('/app/netbeans/'):   # Flatpak: caminho de dentro do sandbox
                mapped += [h + d[len('/app/netbeans'):] for h in hosts]
            else:
                mapped.append(d)
        found = [d for d in mapped if os.path.isdir(os.path.join(d, 'modules'))]
    if not found:
        for root in ['/usr/lib/apache-netbeans', '/usr/share/netbeans', '/opt/netbeans', '/opt/apache-netbeans',
                     os.path.expanduser('~/.local/opt/netbeans'), os.path.expanduser('~/netbeans'), '/snap/netbeans/current/netbeans',
                 '/var/lib/flatpak/app/org.apache.netbeans/current/active/files/netbeans',
                 os.path.expanduser('~/.local/share/flatpak/app/org.apache.netbeans/current/active/files/netbeans')]:
            found += [d for d in glob.glob(os.path.join(root, '*')) if os.path.isdir(os.path.join(d, 'modules'))]
    return found

jars = []
for c in clusters():
    jars += glob.glob(os.path.join(c, 'modules', '*.jar')) + glob.glob(os.path.join(c, 'core', '*.jar'))
if not jars:
    die('não achei a instalação do NetBeans. Rode de novo com NB_HOME=/caminho/do/netbeans (a pasta que tem platform/, ide/, java/...).')

# ---------- 2. Arquivos do perfil FlatLaf Dark de todos os modulos ----------
zips = {}
def zf(path):
    if path not in zips:
        try:
            zips[path] = zipfile.ZipFile(path)
        except Exception:
            zips[path] = None
    return zips[path]

def read_res(jar, res):
    z = zf(jar)
    if z is not None and res in z.namelist():
        return z.read(res)
    for j in jars:
        z = zf(j)
        if z is not None and res in z.namelist():
            return z.read(res)
    return None

def layers(jar):
    z = zf(jar)
    if z is None:
        return []
    out = []
    try:
        mf = z.read('META-INF/MANIFEST.MF').decode('utf-8', 'replace').replace('\r\n', '\n').replace('\n ', '')
        m = re.search(r'^OpenIDE-Module-Layer:\s*(\S+)', mf, re.M)
        if m and m.group(1) in z.namelist():
            out.append(m.group(1))
    except KeyError:
        pass
    if 'META-INF/generated-layer.xml' in z.namelist():
        out.append('META-INF/generated-layer.xml')
    return out

base = []   # (mime, nome do arquivo, tipo, conteudo)
def walk(node, path, jar, layer):
    for c in node.childNodes:
        if c.nodeType != 1:
            continue
        if c.tagName == 'folder':
            walk(c, path + [c.getAttribute('name')], jar, layer)
        elif c.tagName == 'file' and len(path) >= 4 and path[0] == 'Editors' and path[-3:] == ['FontsColors', BASE, 'Defaults']:
            name = c.getAttribute('name')
            url = c.getAttribute('url')
            if not url or name.endswith('_hidden'):
                continue
            if url.startswith('nbres:') or url.startswith('nbresloc:'):
                res = url.split(':', 1)[1].lstrip('/')
            else:
                res = os.path.normpath(os.path.join(os.path.dirname(layer), url)).replace(os.sep, '/')
            data = read_res(jar, res)
            if data is None:
                continue
            typ = None
            for a in c.getElementsByTagName('attr'):
                if a.getAttribute('name') == TYPE_ATTR:
                    typ = a.getAttribute('stringvalue')
            if typ is None:
                typ = 'highlight' if name == 'editorColoring.xml' else 'token'
            base.append(('/'.join(path[1:-3]), name, typ, data))

for j in jars:
    for l in layers(j):
        try:
            doc = M.parseString(zf(j).read(l))
        except Exception:
            continue
        walk(doc.documentElement, [], j, l)
if not any(m == '' for m, *_ in base):
    die(f'não achei as cores do {BASE_NOME} na instalação do NetBeans.')
if len(sys.argv) > 5 and sys.argv[5] == 'check':
    # ---- validacao: os tokens que o modulo usa ainda existem nos lexers desta versao? ----
    import struct
    NEEDED = {
        'Java': ('org/netbeans/api/java/lexer/JavaTokenId.class',
                 'LPAREN RPAREN LBRACE RBRACE LBRACKET RBRACKET'),
        'JavaScript/JSON': ('org/netbeans/modules/javascript2/lexer/api/JsTokenId.class',
                 'IDENTIFIER PRIVATE_IDENTIFIER WHITESPACE EOL BRACKET_LEFT_PAREN BRACKET_RIGHT_PAREN '
                 'BRACKET_LEFT_CURLY BRACKET_RIGHT_CURLY BRACKET_LEFT_BRACKET BRACKET_RIGHT_BRACKET '
                 'OPERATOR_DOT OPERATOR_OPTIONAL_ACCESS OPERATOR_ARROW OPERATOR_ASSIGNMENT OPERATOR_COMMA '
                 'OPERATOR_SEMICOLON OPERATOR_COLON KEYWORD_INSTANCEOF KEYWORD_VAR RESERVED_LET KEYWORD_CONST '
                 'KEYWORD_FUNCTION KEYWORD_CATCH KEYWORD_CLASS KEYWORD_THIS KEYWORD_SUPER KEYWORD_TRUE '
                 'KEYWORD_FALSE KEYWORD_NULL TEMPLATE_EXP_BEGIN TEMPLATE_EXP_END'),
        'CSS/SCSS/LESS': ('org/netbeans/modules/css/lib/api/CssTokenId.class',
                 'IDENT LPAREN RPAREN LBRACE RBRACE LBRACKET RBRACKET SEMI DOT COLON DCOLON HASH HASH_SYMBOL '
                 'LESS_AND MINUS PERCENTAGE_SYMBOL WS NL COMMENT LINE_COMMENT URI URL OPEQ INCLUDES DASHMATCH '
                 'BEGINS ENDS CONTAINS SASS_INCLUDE SASS_MIXIN SASS_FUNCTION SASS_VAR VARIABLE IMPORTANT_SYM '
                 'KEYFRAMES_SYM PERCENTAGE LENGTH EMS REM DIMENSION STAR GREATER TILDE PLUS CP_EQ CP_NOT_EQ'),
        'EL': ('org/netbeans/modules/el/lexer/api/ELTokenId.class',
                 'IDENTIFIER DOT LPAREN RPAREN LBRACKET RBRACKET WHITESPACE EOL TRUE_KEYWORD FALSE_KEYWORD NULL_KEYWORD'),
        'HTML': ('org/netbeans/api/html/lexer/HTMLTokenId.class', 'DECLARATION'),
    }
    problems = []
    for lang, (cls, names) in NEEDED.items():
        data = None
        for j in jars:
            z = zf(j)
            if z is not None and cls in z.namelist():
                data = z.read(cls)
                break
        if data is None:
            continue                                   # linguagem nao instalada: nada a colorir
        missing = [n for n in names.split() if struct.pack('>H', len(n)) + n.encode() not in data]
        if missing:
            problems.append(f'  {lang}: {", ".join(missing)}')
    if problems:
        print('Aviso: esta versão do NetBeans não tem alguns tokens que o módulo usa; essas regras vão parar de pintar:')
        print('\n'.join(problems))
    # ---- validacao: versao do Java com que o NetBeans roda ----
    log = os.path.join(UD, 'var', 'log', 'messages.log')
    if os.path.exists(log):
        m = re.search(r'Java; VM; Vendor\s*=\s*(\d+)', open(log, errors='replace').read())
        if m and int(m.group(1)) < 17:
            print(f'Aviso: o NetBeans roda com Java {m.group(1)}; o módulo exige Java 17 ou mais novo e vai ficar desativado '
                  '(as cores do perfil continuam funcionando).')
    sys.exit(0)

# ---------- 3. Cores do tema (preparadas em STAGE no formato antigo) ----------
def ftype(dirpath, fn):
    attrs = os.path.join(dirpath, '.nbattrs')
    if os.path.exists(attrs):
        for fo in M.parse(attrs).getElementsByTagName('fileobject'):
            if fo.getAttribute('name') == fn:
                for a in fo.getElementsByTagName('attr'):
                    if a.getAttribute('name') == TYPE_ATTR:
                        return a.getAttribute('stringvalue')
    return 'highlight' if fn.endswith('-highlights.xml') else 'annotation' if fn.endswith('-annotations.xml') else 'token'

over = {}   # (mime, tipo) -> {nome: elemento}
sroot = os.path.join(STAGE, 'config', 'Editors')
for dirpath, _, files in os.walk(sroot):
    rel = os.path.relpath(dirpath, sroot).replace(os.sep, '/')
    m = re.match(r'^(?:(.*)/)?FontsColors/' + re.escape(BASE) + r'(?:/Defaults)?$', rel) if rel != '.' else None
    if not m:
        continue
    mime = m.group(1) or ''
    for fn in files:
        if not fn.endswith('.xml'):
            continue
        d = over.setdefault((mime, ftype(dirpath, fn)), {})
        for e in M.parse(os.path.join(dirpath, fn)).getElementsByTagName('fontcolor'):
            d[e.getAttribute('name')] = e

THEMEFONT = os.environ.get('NBKIT_TEMA_FONTE', '')
THEMESIZE = '13'
if THEMEFONT and ('', 'token') in over and 'default' in over[('', 'token')]:
    d = over[('', 'token')]['default']
    for f in d.getElementsByTagName('font'):
        d.removeChild(f)
    fe = d.ownerDocument.createElement('font')
    fe.setAttribute('name', THEMEFONT)
    fe.setAttribute('size', THEMESIZE)
    d.appendChild(fe)

def merged(orig, new):
    """Entrada do tema no lugar da do FlatLaf Dark, herdando 'default' e a fonte quando o tema nao define."""
    if orig is not None:
        if not new.hasAttribute('default') and orig.hasAttribute('default'):
            new.setAttribute('default', orig.getAttribute('default'))
        if not new.getElementsByTagName('font') and orig.getElementsByTagName('font'):
            new.appendChild(orig.getElementsByTagName('font')[0].cloneNode(True))
    return new

def write_xml(path, elements):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write(HDR + '<fontscolors>\n' + ''.join('    ' + e.toxml() + '\n' for e in elements) + '</fontscolors>\n')

def write_types(folder, types):
    with open(os.path.join(folder, '.nbattrs'), 'w') as f:
        f.write(NBATTRS_HDR + '<attributes version="1.0">\n')
        for fn, t in sorted(types.items()):
            f.write(f'    <fileobject name="{fn}">\n        <attr name="{TYPE_ATTR}" stringvalue="{t}"/>\n    </fileobject>\n')
        f.write('</attributes>\n')

# ---------- 4. Perfil novo: copia do FlatLaf Dark + cores do tema ----------
def profile_dir(mime, defaults=True):
    parts = [EDITORS] + ([mime] if mime else []) + ['FontsColors', PROFILE] + (['Defaults'] if defaults else [])
    return os.path.join(*parts)

used = set()
types_by_dir = {}
flatlaf_default = None
for mime, fn, typ, data in base:
    doc = M.parseString(data)
    out = []
    for e in doc.getElementsByTagName('fontcolor'):
        nm = e.getAttribute('name')
        if mime == '' and typ == 'token' and nm == 'default':
            flatlaf_default = e.cloneNode(True)
        o = over.get((mime, typ), {}).get(nm)
        if o is not None:
            out.append(merged(e, o.cloneNode(True)))
            used.add((mime, typ, nm))
        else:
            out.append(e)
    folder = profile_dir(mime)
    target = fn
    while os.path.exists(os.path.join(folder, target)):     # dois modulos com o mesmo nome de arquivo
        target = 'x-' + target
    write_xml(os.path.join(folder, target), out)
    types_by_dir.setdefault(folder, {})[target] = typ
for (mime, typ), d in over.items():
    rest = [merged(None, e.cloneNode(True)) for nm, e in d.items() if (mime, typ, nm) not in used]
    if rest:
        folder = profile_dir(mime)
        target = f'nbkit-tema-{typ}.xml'
        write_xml(os.path.join(folder, target), rest)
        types_by_dir.setdefault(folder, {})[target] = typ
for folder, types in types_by_dir.items():
    write_types(folder, types)
if len(sys.argv) <= 5:
    langs = len({m for m, *_ in base})
    print(f'\u2713 {len(base)} arquivos de cores do {BASE_NOME} copiados ({langs} linguagens), {len(used)} cores substituídas pelo tema')

# ---------- 5. Fonte ----------
font = json.loads(FONTJSON) if FONTJSON else None      # fonte que voce usava no FlatLaf Dark

def ask(question):
    try:
        with open('/dev/tty') as tty, open('/dev/tty', 'w') as out:
            out.write('      ' + question + ' [s/N] '); out.flush()
            return tty.readline().strip().lower() in ('s', 'sim', 'y', 'yes')
    except OSError:
        print(question + ' (sem terminal para perguntar: usando a do tema)')
        return False

def read_user(path):
    if not os.path.exists(path):
        return [], None
    entries = list(M.parse(path).getElementsByTagName('fontcolor'))
    d = next((e for e in entries if e.getAttribute('name') == 'default'), None)
    return entries, d

def font_of(e):
    f = e.getElementsByTagName('font') if e is not None else []
    if f and f[0].getAttribute('name'):
        return {k: v for k, v in f[0].attributes.items() if k in ('name', 'size', 'style')}
    return None

def with_font(base, fnt):
    d = base.cloneNode(True)
    for f in d.getElementsByTagName('font'):
        d.removeChild(f)
    fe = d.ownerDocument.createElement('font')
    for k, v in fnt.items():
        fe.setAttribute(k, v)
    d.appendChild(fe)
    return d

def put_font(userfile, base_default, fnt):
    """Grava a fonte na entrada default do arquivo de usuario (com as cores da base quando ainda nao existe)."""
    if not fnt or base_default is None:
        return
    entries, d = read_user(userfile)
    rest = [e for e in entries if e.getAttribute('name') != 'default']
    write_xml(userfile, [with_font(d if d is not None else base_default, fnt)] + rest)

theme_default = over.get(('', 'token'), {}).get('default')
if theme_default is not None:
    theme_default = merged(flatlaf_default, theme_default.cloneNode(True))
pfile = os.path.join(profile_dir('', False), USERFILE)
_, pdef = read_user(pfile)
cur = font_of(pdef)                       # fonte escolhida no proprio perfil
mine = cur or font                        # senao, a que voce usava no FlatLaf Dark

if not THEMEFONT:
    if mine and not cur:
        put_font(pfile, theme_default, mine)
        print('fonte do editor levada para o perfil novo: ' + ' '.join(mine.values()))
elif mine and mine.get('name') != THEMEFONT:
    desc = mine['name'] + (' ' + mine['size'] if mine.get('size') else '')
    if ask(f'Você usa a fonte {desc}; o tema usa {THEMEFONT}. Manter a sua?'):
        if not cur:
            put_font(pfile, theme_default, mine)
        print('fonte mantida: ' + desc)
    else:
        if cur:
            put_font(pfile, theme_default, dict(cur, name=THEMEFONT))
        elif mine.get('size') and mine['size'] != THEMESIZE:
            put_font(pfile, theme_default, {'name': THEMEFONT, 'size': mine['size']})
        print(f'fonte do tema aplicada: {THEMEFONT}')
elif mine and not cur and mine.get('size') and mine['size'] != THEMESIZE:
    put_font(pfile, theme_default, {'name': THEMEFONT, 'size': mine['size']})   # mesma fonte, seu tamanho

# FlatLaf Dark: se a fonte veio dele (versoes antigas), continua la
if font:
    entries, d = read_user(os.path.join(EDITORS, 'FontsColors', BASE, USERFILE))
    if font_of(d) is None:
        put_font(os.path.join(EDITORS, 'FontsColors', BASE, USERFILE), flatlaf_default, font)
PY
}

# ---------- API de cores (usada em <prefixo>_cores) ----------
CORES_HDR='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fontscolors PUBLIC "-//NetBeans//DTD Editor Fonts and Colors settings 1.2//EN" "https://netbeans.apache.org/dtds/EditorFontsColors-1_2.dtd">'
CORES_PREFIX="org-netbeans-modules-editor-settings-CustomFontsColors"

cores_arquivo() { { echo "$CORES_HDR"; echo "<fontscolors>"; cat; echo "</fontscolors>"; } > "$1"; }
# cores gerais do editor (valem para todas as linguagens)
cores_tokens() { mkdir -p "$FC"; cores_arquivo "$FC/$CORES_PREFIX-tokenColorings.xml"; }
# destaques: seleção, linha atual, busca, números de linha...
cores_destaques() { mkdir -p "$FC"; cores_arquivo "$FC/$CORES_PREFIX-highlights.xml"; }
# anotações: sublinhados de erro e aviso de cada módulo
cores_anotacoes() { mkdir -p "$FC"; cores_arquivo "$FC/$CORES_PREFIX-annotations.xml"; }
# tokens de uma linguagem: cores_linguagem text/css <<'EOF' ... EOF
cores_linguagem() {
  local dir="$EC/Editors/$1/FontsColors/$TEMA_BASE"
  mkdir -p "$dir"
  cores_arquivo "$dir/$CORES_PREFIX-tokenColorings.xml"
}
# categorias que nenhum módulo do NetBeans define (as nbkit-* do módulo de coloração):
# o NetBeans só aceita essas na pasta Defaults
cores_extras() {
  local dir="$EC/Editors/$1/FontsColors/$TEMA_BASE/Defaults"
  mkdir -p "$dir"
  cores_arquivo "$dir/nbkit-tema-tokenColorings.xml"
}

# ---------- fonte ----------
tema_fonte() {
  NBKIT_TEMA_FONTE=""
  export NBKIT_TEMA_FONTE
  if [ -z "$TEMA_FONTE_NOME" ]; then
    info "o tema não define fonte: a sua fica como está"
    return 0
  fi
  local dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/$TEMA_FONTE_PASTA" tmp okf=1 u f
  tema_tem_fonte() {
    # sem grep -q: com pipefail, o grep saindo cedo faria o fc-list falhar (SIGPIPE)
    if command -v fc-list >/dev/null 2>&1; then
      fc-list : family 2>/dev/null | grep -E "(^|,)$TEMA_FONTE_NOME(,|$)" >/dev/null
    else
      local primeiro; primeiro="$(basename "${TEMA_FONTE_URLS[0]:-x}")"
      ls "$dir/$primeiro" "$HOME/.fonts/$primeiro" /usr/share/fonts/*/"$primeiro" /usr/share/fonts/*/*/"$primeiro" \
         /usr/local/share/fonts/*/"$primeiro" >/dev/null 2>&1
    fi
  }
  baixar() {
    if command -v curl >/dev/null 2>&1; then curl -fsSL --max-time 60 -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then wget -q -T 60 -O "$2" "$1"
    else return 1; fi
  }
  if tema_tem_fonte; then
    NBKIT_TEMA_FONTE="$TEMA_FONTE_NOME"
    info "já instalada"
  elif [ ${#TEMA_FONTE_URLS[@]} -gt 0 ]; then
    info "baixando ${TEMA_FONTE_ORIGEM:+do $TEMA_FONTE_ORIGEM }para $dir ..."
    tmp="$(mktemp -d)"
    for u in "${TEMA_FONTE_URLS[@]}"; do
      f="$tmp/$(basename "$u")"
      # confere que veio uma fonte TrueType de verdade (e não uma página de erro)
      if ! baixar "$u" "$f" || [ "$(head -c 4 "$f" | od -An -tx1 | tr -d ' \n')" != "00010000" ]; then okf=0; break; fi
    done
    if [ $okf = 1 ]; then
      mkdir -p "$dir"
      cp "$tmp"/*.ttf "$dir"/
      [ -n "$TEMA_FONTE_LICENCA" ] && { baixar "$TEMA_FONTE_LICENCA" "$dir/$(basename "$TEMA_FONTE_LICENCA")" || true; }
      touch "$dir/.nbkit-installed"
      command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$dir" >/dev/null 2>&1 || true
      if tema_tem_fonte; then NBKIT_TEMA_FONTE="$TEMA_FONTE_NOME"; info "${#TEMA_FONTE_URLS[@]} arquivos instalados, cache de fontes atualizado"; fi
    fi
    rm -rf "$tmp"
    [ -z "$NBKIT_TEMA_FONTE" ] && echo "Aviso: não consegui instalar a $TEMA_FONTE_NOME (sem internet?); a fonte atual fica como está."
  fi
  if [ -n "$NBKIT_TEMA_FONTE" ]; then ok "disponível para o NetBeans"; fi
  return 0
}

# ---------- instalar ----------
tema_instalar() {
  local CURSEL
  tema_migrar
  STAGE="$(tmpdir)"; OLD="$(tmpdir)"
  EC="$STAGE/config"
  FC="$EC/Editors/FontsColors/$TEMA_BASE"

  step "Verificando a instalação do NetBeans (módulos, lexers, Java)"
  tema_builder "$UD" "$STAGE" "$TEMA_PERFIL" "" check
  ok "NetBeans encontrado"

  step "Backup do estado original"
  if tema_marcado; then info "já existe (feito na primeira instalação)"; fi
  tema_backup

  step "Fonte ${TEMA_FONTE_NOME:-do editor}"
  tema_fonte

  step "Conferindo o perfil $TEMA_BASE_NOME"
  # fonte que você usava no perfil base (vai para o perfil novo)
  FONTJSON="$(python3 - "$C/Editors/FontsColors/$TEMA_BASE/$CORES_PREFIX-tokenColorings.xml" <<'PY' 2>/dev/null || true
import sys, json, xml.dom.minidom as M
for e in M.parse(sys.argv[1]).getElementsByTagName('fontcolor'):
    f = e.getElementsByTagName('font')
    if e.getAttribute('name') == 'default' and f and f[0].getAttribute('name'):
        print(json.dumps({k: v for k, v in f[0].attributes.items() if k in ('name', 'size', 'style')}))
PY
)"
  # versões até a v17 do instalador antigo gravavam o tema dentro do FlatLaf Dark: devolve o original
  if [ -e "$C/Editors/FontsColors/FlatLafDark/Defaults/onedark-mix-tokenColorings.xml" ] \
     || [ -e "$C/Editors/text/css/FontsColors/FlatLafDark/Defaults/onedark-mix-tokenColorings.xml" ]; then
    local t first
    for t in "${TARGETS[@]}"; do
      case "$t" in config/Editors/*) rm -rf "${UD:?}/$t" ;; esac
    done
    first="$(tema_backups | head -1)"
    if [ -n "$first" ]; then tar -xzf "$first" -C "$UD" --wildcards 'config/Editors/*' 2>/dev/null || true; fi
    info "tema de versão antiga encontrado no FlatLaf Dark: devolvido ao original"
  fi
  ok "$TEMA_BASE_NOME original preservado"

  step "Preparando as cores do tema"
  # interface: cópia para mesclar suas chaves depois
  if [ -e "$UD/$LAFT" ]; then mkdir -p "$OLD/$(dirname "$LAFT")"; cp -a "$UD/$LAFT" "$OLD/$LAFT"; fi
  rm -f "$UD/$LAFT"
  # o perfil é refeito a cada instalação; seus ajustes (fora de Defaults) ficam
  find "$C/Editors" -depth -type d -path "*/FontsColors/$TEMA_PERFIL/Defaults" -exec rm -rf {} + 2>/dev/null || true
  mkdir -p "$(dirname "$UD/$LAFT")"
  { echo "# nbkit tema: $TEMA_PERFIL"; "${TEMA_P}_interface"; } > "$UD/$LAFT"
  mkdir -p "$FC"
  "${TEMA_P}_cores"
  # o NetBeans identifica o tipo de cada arquivo de cores por este atributo
  cat > "$FC/.nbattrs" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE attributes PUBLIC "-//NetBeans//DTD DefaultAttributes 1.0//EN" "http://www.netbeans.org/dtds/attributes-1_0.dtd">
<attributes version="1.0">
    <fileobject name="$CORES_PREFIX-tokenColorings.xml">
        <attr name="nbeditor-settings-ColoringType" stringvalue="token"/>
    </fileobject>
    <fileobject name="$CORES_PREFIX-highlights.xml">
        <attr name="nbeditor-settings-ColoringType" stringvalue="highlight"/>
    </fileobject>
    <fileobject name="$CORES_PREFIX-annotations.xml">
        <attr name="nbeditor-settings-ColoringType" stringvalue="annotation"/>
    </fileobject>
</attributes>
EOF
  ok "interface, editor e categorias do módulo prontos"

  step "Montando o perfil \"$TEMA_PERFIL\" (cópia do $TEMA_BASE_NOME da sua versão + tema)"
  { tema_builder "$UD" "$STAGE" "$TEMA_PERFIL" "$FONTJSON"; } 2>&1 | sed 's/^/      /'

  step "Instalando o módulo de coloração (chamadas, colchetes, unidades, tags...)"
  mkdir -p "$UD/modules" "$C/Modules"
  # módulo do instalador antigo (com.onedarkmix.netbeans): substituído pelo nbkit.cores
  rm -f "$UD/modules/com-onedarkmix-netbeans.jar" "$C/Modules/com-onedarkmix-netbeans.xml"
  base64 -d > "$CORES_JAR" <<'B64'
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
B64
  echo "0525b3e5505a8e67fe7186d57e84a3f55cab7ab41c293b076c8212d248f12db3  $CORES_JAR" | sha256sum -c --quiet - || die "o módulo de coloração foi corrompido ao copiar o nbkit."
  cat > "$CORES_XML" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE module PUBLIC "-//NetBeans//DTD Module Status 1.0//EN" "http://www.netbeans.org/dtds/module-status-1_0.dtd">
<module name="nbkit.cores">
    <param name="autoload">false</param>
    <param name="eager">false</param>
    <param name="enabled">true</param>
    <param name="jar">modules/nbkit-cores.jar</param>
    <param name="reloadable">false</param>
</module>
EOF
  # faz o NetBeans reler a lista de módulos na próxima abertura
  touch "$UD/.lastModified"
  ok "módulo copiado e verificado (sha256)"

  step "Aplicando a interface e preservando suas personalizações"
  # Mantém: fonte do editor, entradas que o tema não define, ajustes seus em entradas do tema
  # e chaves suas no arquivo da interface.
  {
  python3 - "$UD" "$OLD" "$LAFT" <<'PY'
import sys, os, json, re
import xml.dom.minidom as M

UD, OLD = sys.argv[1], sys.argv[2]
MAN = os.environ['NBKIT_TEMA_MANIFEST']
try:
    man = json.load(open(MAN))
except Exception:
    man = None
LAF = sys.argv[3]
HDR = ('<?xml version="1.0" encoding="UTF-8"?>\n'
       '<!DOCTYPE fontscolors PUBLIC "-//NetBeans//DTD Editor Fonts and Colors settings 1.2//EN" '
       '"https://netbeans.apache.org/dtds/EditorFontsColors-1_2.dtd">\n')
ATTRS = ('default', 'foreColor', 'bgColor', 'underline', 'strikeThrough', 'waveUnderlined')

NAMED = {'black': '000000', 'blue': '0000ff', 'cyan': '00ffff', 'darkGray': '404040', 'gray': '808080',
         'green': '00ff00', 'lightGray': 'c0c0c0', 'magenta': 'ff00ff', 'orange': 'ffc800', 'pink': 'ffafaf',
         'red': 'ff0000', 'white': 'ffffff', 'yellow': 'ffff00'}

def norm(v):
    v = NAMED.get(v, v).lower()
    return ('ff' + v) if len(v) == 6 else v

def key(e):
    # comparacao semantica: o NetBeans regrava cores e fonte em outro formato ao salvar
    # 'default' fica de fora: o NetBeans copia a heranca da categoria ao salvar, sem ser ajuste seu
    a = {k: (v if k == 'name' else norm(v)) for k, v in e.attributes.items() if k != 'default'}
    f = e.getElementsByTagName('font')
    fa = dict(f[0].attributes.items()) if f else {}
    return json.dumps([sorted(a.items()), sorted(fa.items())])

def entries(path):
    d = M.parse(path)
    return {e.getAttribute('name'): e for e in d.getElementsByTagName('fontcolor')}

def ser(e):
    a = ''.join(f' {k}="{e.getAttribute(k)}"' for k in ['name'] + list(ATTRS) if e.hasAttribute(k))
    f = e.getElementsByTagName('font')
    if f and f[0].attributes.length:
        fa = ''.join(f' {k}="{v}"' for k, v in f[0].attributes.items())
        return f'    <fontcolor{a}><font{fa}/></fontcolor>'
    return f'    <fontcolor{a}/>'

notes = []
new_man = {}
for t in sys.argv[3:]:
    p = os.path.join(UD, t)
    if os.path.isfile(p) and t == LAF:
        new_man[LAF] = {m.group(1): m.group(2) for l in open(p) for m in [re.match(r'^\s*([^#!\s=:][^=:\s]*)\s*[=:]\s*(.*?)\s*$', l)] if m}
    elif os.path.isdir(p):
        for fn in os.listdir(p):
            if fn.endswith('.xml'):
                rel = os.path.join(t, fn)
                new_man[rel] = {n: key(e) for n, e in entries(os.path.join(p, fn)).items()}
for root, _, files in os.walk(OLD):
    for fn in files:
        rel = os.path.relpath(os.path.join(root, fn), OLD)
        old, cur = os.path.join(OLD, rel), os.path.join(UD, rel)
        if rel == LAF or fn == '.nbattrs' or '/Defaults/' in rel:
            continue
        if not os.path.exists(cur):          # arquivo que o tema nao escreve: volta como estava
            os.makedirs(os.path.dirname(cur), exist_ok=True)
            open(cur, 'wb').write(open(old, 'rb').read())
            continue
        if not fn.endswith('.xml'):
            continue
        try:
            o = entries(old)
        except Exception:
            continue
        n = entries(cur)
        prev = (man or {}).get(rel, {})
        out = [ser(e) for e in n.values()]
        names = list(n)
        for name, e in o.items():
            mine = name in prev and prev[name] == key(e)
            if name == 'default' and name in n:
                f = e.getElementsByTagName('font')
                if f and f[0].attributes.length:
                    t = n[name]
                    i = names.index(name)
                    fa = ''.join(f' {k}="{v}"' for k, v in f[0].attributes.items())
                    a = ''.join(f' {k}="{t.getAttribute(k)}"' for k in ['name'] + list(ATTRS) if t.hasAttribute(k))
                    out[i] = f'    <fontcolor{a}><font{fa}/></fontcolor>'
                    notes.append('fonte do editor preservada: ' + ' '.join(f[0].getAttribute(k) for k in ('name', 'size') if f[0].getAttribute(k)))
                continue
            if name in n:
                if man is not None and name in prev and not mine:
                    out[names.index(name)] = ser(e)
                    notes.append(f'ajuste seu mantido: {name}')
                continue
            if man is not None and mine:
                continue                     # entrada de versao antiga do tema, aposentada
            out.append(ser(e))
            names.append(name)
        open(cur, 'w').write(HDR + '<fontscolors>\n' + '\n'.join(out) + '\n</fontscolors>\n')

# .nbattrs: une as entradas antigas que o tema nao define
for root, _, files in os.walk(OLD):
    if '.nbattrs' in files:
        rel = os.path.relpath(os.path.join(root, '.nbattrs'), OLD)
        cur = os.path.join(UD, rel)
        if not os.path.exists(cur):
            continue
        od, cd = M.parse(os.path.join(OLD, rel)), M.parse(cur)
        have = {f.getAttribute('name') for f in cd.getElementsByTagName('fileobject')}
        add = [f for f in od.getElementsByTagName('fileobject') if f.getAttribute('name') not in have]
        if add:
            txt = open(cur).read()
            extra = ''.join('    ' + f.toxml() + '\n' for f in add)
            open(cur, 'w').write(txt.replace('</attributes>', extra + '</attributes>'))

# arquivo da interface (FlatDarkLaf.properties ou o do tema)
olaf, claf = os.path.join(OLD, LAF), os.path.join(UD, LAF)
kre = re.compile(r'^\s*([^#!\s=:][^=:\s]*)\s*[=:]\s*(.*?)\s*$')

def props(path):
    d = {}
    for l in open(path).read().splitlines():
        m = kre.match(l)
        if m:
            d[m.group(1)] = m.group(2)   # a ultima definicao vale, como no Java
    return d

if os.path.exists(olaf) and os.path.exists(claf):
    olines = open(olaf).read().splitlines()
    old_is_theme = bool(olines) and olines[0].startswith(('# nbkit tema', '# One Dark Pro Mix'))
    ov, cv = props(olaf), props(claf)
    pm = (man or {}).get(LAF, {})
    prevv = pm if isinstance(pm, dict) else {k: None for k in pm}
    keep = []
    for k, v in ov.items():
        if k in cv:
            continue
        if (man is not None and k not in prevv) or (man is None and not old_is_theme):
            keep.append(f'{k}={v}')          # chave sua que o tema nao define
    if keep:
        notes.append(f'{len(keep)} chave(s) sua(s) preservada(s) na interface')
    # chaves do tema cujo valor voce alterou (precisa do valor gravado no manifesto)
    changed = [k for k, v in ov.items() if k in cv and prevv.get(k) is not None
               and v != prevv[k] and v != cv[k]]
    if changed:
        msg = 'Você alterou chaves da interface que o tema define:\n' + ''.join(
            f'  {k}: seu valor {ov[k]} | tema {cv[k]}\n' for k in changed)
        ans = ''
        try:
            with open('/dev/tty') as tty, open('/dev/tty', 'w') as out:
                out.write(''.join('      ' + l + '\n' for l in msg.splitlines()) + '      Manter os seus valores? [s/N] ')
                out.flush()
                ans = tty.readline().strip().lower()
        except OSError:
            print(msg + '(sem terminal para perguntar: usando os valores do tema)')
        if ans in ('s', 'sim', 'y', 'yes'):
            keep += [f'{k}={ov[k]}' for k in changed]
            notes.append(f'{len(changed)} valor(es) seu(s) mantido(s) na interface')
        else:
            notes.append('valores do tema aplicados na interface')
    if keep:
        open(claf, 'a').write('\n# ---- Personalizacoes suas preservadas ----\n' + '\n'.join(keep) + '\n')

json.dump(new_man, open(MAN, 'w'))
if notes:
    print('\n'.join(notes))
PY
  } 2>&1 | sed 's/^/      /'
  ok "$TEMA_LAF_ARQ gravado"

  step "Selecionando visual, perfil${TEMA_TERMINAL_SELECAO:+ e cor de seleção do terminal}"
  if [ -n "$TEMA_TERMINAL_SELECAO" ]; then
    mkdir -p "$(dirname "$TERMPREF")"
    touch "$TERMPREF"
    CURSEL="$(sed -n 's/^term\.selectionBackground=//p' "$TERMPREF" | tail -1)"
    if [ -z "$CURSEL" ]; then
      echo "term.selectionBackground=$TEMA_TERMINAL_SELECAO" >> "$TERMPREF"
    elif [ "$CURSEL" != "$TEMA_TERMINAL_SELECAO" ]; then
      echo "seleção do terminal: mantida a cor que você escolheu (Tools > Options > Terminal)"
    fi
  fi
  tema_select_state select "$TEMA_LAF" "$TEMA_PERFIL"
  rm -f "$UD/onedark-version"
  ok "$TEMA_BASE_NOME + \"$TEMA_PERFIL\"${TEMA_TERMINAL_SELECAO:+ + terminal}"
}

# ---------- desinstalar ----------
tema_desinstalar() {
  local FONT first t jbm
  tema_migrar
  step "Removendo perfil, interface e módulo"
  FONT="$(tema_current_font "$UD/config/Editors/FontsColors/$TEMA_PERFIL/$CORES_PREFIX-tokenColorings.xml")"
  rm -f "$UD/$LAFT"
  find "$C/Editors" -depth -type d -path "*/FontsColors/$TEMA_PERFIL" -exec rm -rf {} + 2>/dev/null || true
  first="${TEMA_RESTAURAR:-$(tema_backups | head -1)}"
  # tema de versão antiga (até a v17) ainda dentro do FlatLaf Dark: devolve o original
  if [ -e "$C/Editors/FontsColors/FlatLafDark/Defaults/onedark-mix-tokenColorings.xml" ]; then
    for t in "${TARGETS[@]}"; do case "$t" in config/Editors/*) rm -rf "${UD:?}/$t" ;; esac; done
    [ -n "$first" ] && tar -xzf "$first" -C "$UD" --wildcards 'config/Editors/*' 2>/dev/null || true
  fi
  rm -f "$CORES_JAR" "$CORES_XML" "$UD/modules/com-onedarkmix-netbeans.jar" "$C/Modules/com-onedarkmix-netbeans.xml"
  ok "perfil \"$TEMA_PERFIL\", $TEMA_LAF_ARQ e módulo removidos"

  step "Voltando o visual e o perfil que estavam antes"
  tema_select_state restore "" ""
  ok "seleção anterior restaurada"

  step "Fonte"
  jbm="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/$TEMA_FONTE_PASTA"
  if tema_fonte_marcada; then
    rm -rf "$jbm"; command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1 || true
    ok "$TEMA_FONTE_NOME removida (tinha sido instalada pelo nbkit)"
  elif [ -n "$TEMA_FONTE_NOME" ]; then
    info "$TEMA_FONTE_NOME mantida (não foi o nbkit que instalou)"
  fi
  rm -f "$TEMA_MANIFEST" "$UD/onedark-version"
  if [ -n "$TEMA_TERMINAL_SELECAO" ] && [ -f "$TERMPREF" ]; then
    sed -i "/^term\.selectionBackground=$TEMA_TERMINAL_SELECAO\$/d" "$TERMPREF"
  fi
  touch "$UD/.lastModified"
  # restaurando um backup escolhido: o passo seguinte já volta tudo dele
  if [ -z "${TEMA_RESTAURAR:-}" ] && [ -n "$first" ] && tar -tzf "$first" "$LAFT" >/dev/null 2>&1; then
    tar -xzf "$first" -C "$UD" "$LAFT"; info "$TEMA_LAF_ARQ original restaurado"
  fi
  [ -n "$FONT" ] && info "a fonte do perfil removido era: $FONT"
  ok "pronto"
}

# ---------- restaurar um backup ----------
tema_restaurar() {
  if [ "$(tema_status)" != nao ]; then
    TEMA_RESTAURAR="$1"
    tema_desinstalar
    TEMA_RESTAURAR=""
  else
    step "Backup do que você tem hoje"
    tema_backup
  fi
  step "Restaurando o backup de $(bk_date "$1")"
  tema_restore_backup "$1"
}

# ---------- conferir (com o NetBeans aberto) ----------
tema_conferir() {
  local rc=0 stage; stage="$(tmpdir)"
  tema_builder "$UD" "$stage" "$TEMA_PERFIL" "" check >/dev/null 2>&1 || true
  python3 - "$UD" <<'PY' || rc=$?
import sys, os, re, xml.dom.minidom as M
ud = sys.argv[1]
ok = True
def res(good, msg):
    global ok
    ok = ok and good
    print(('  ok       ' if good else '  PROBLEMA ') + msg)
log = os.path.join(ud, 'var', 'log', 'messages.log')
jar = os.path.join(ud, 'modules', 'nbkit-cores.jar')
text = open(log, errors='replace').read()
lines = text.splitlines()
loaded = any(re.match(r'^\s+nbkit\.cores \[', l) for l in lines)
bad = [l.strip() for l in lines if ('nbkit.cores' in l or 'nbkit/cores' in l)
       and re.search(r'could not|cannot|Exception|SEVERE|disabled|requires', l)]
listed = any('Turning on modules' in l for l in lines)
if not listed and not bad:
    print('  info     o log desta sessão não lista os módulos; confira em Tools > Plugins > Installed')
else:
    res(loaded and not bad, 'módulo de coloração carregado' if loaded else 'módulo de coloração não aparece entre os módulos ligados')
for b in bad[:10]:
    print('           ' + b)
prof = None
attrs = os.path.join(ud, 'config', '.nbattrs')
if os.path.exists(attrs):
    for fo in M.parse(attrs).getElementsByTagName('fileobject'):
        if fo.getAttribute('name') == 'Editors':
            for a in fo.getElementsByTagName('attr'):
                if a.getAttribute('name') == 'currentFontColorProfile':
                    prof = a.getAttribute('stringvalue')
PERFIL, LAFCLASS = os.environ['NBKIT_TEMA_PERFIL'], os.environ['NBKIT_TEMA_LAF']
res(prof == PERFIL and os.path.isdir(os.path.join(ud, 'config', 'Editors', 'FontsColors', PERFIL)),
    f'perfil do editor: {prof or "(padrão do NetBeans)"}')
laf = None
lp = os.path.join(ud, 'config', 'Preferences', 'laf.properties')
if os.path.exists(lp):
    for l in open(lp).read().splitlines():
        if l.startswith('laf='):
            laf = l[4:]
res(laf == LAFCLASS, f'visual: {laf or "(padrão do NetBeans)"}')
fixable = not any(re.search(r'requires|Java', b) for b in bad)
sys.exit(0 if ok else (1 if fixable else 2))
PY
  return $rc
}
