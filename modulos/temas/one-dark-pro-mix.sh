# Tema One Dark Pro Mix para o nbkit (carregado pelo nbkit.sh com source).
# Cria o perfil de cores "One Dark Pro Mix" (copia do FlatLaf Dark da sua versao + cores do tema),
# seleciona o visual FlatLaf Dark e esse perfil, instala a fonte JetBrains Mono e o modulo de coloracao.
# O perfil FlatLaf Dark original nao e alterado.

nbkit_registrar one-dark-pro-mix odpm tema "One Dark Pro Mix" "Cores do One Dark Pro Mix (VS Code), FlatLaf Dark e JetBrains Mono" 27

odpm_vars() {
  MODJAR="$UD/modules/com-onedarkmix-netbeans.jar"
  MODXML="$UD/config/Modules/com-onedarkmix-netbeans.xml"
  # selecao do terminal: terminal.selectionBackground do Mix (#abb2bf30 sobre #282c34 = #41454e), como o NetBeans grava
  TERMPREF="$UD/config/Preferences/org/netbeans/modules/terminal/nb.properties"
  TERMSEL=-12499634
  PROFILE="One Dark Pro Mix"
  LAFPREF="$UD/config/Preferences/laf.properties"
  LAFCLASS="com.formdev.flatlaf.FlatDarkLaf"
  STATE="$UD/onedark-state.json"
  MIMES="text/css text/html text/javascript text/textmate text/x-apache-conf text/x-diff text/x-el text/x-env text/x-java text/x-jflex text/x-json text/x-jsp text/x-markdown text/x-nbs text/x-neon text/x-oql text/x-php5 text/x-properties text/x-repl text/x-sql text/x-tag text/x-terraform+x-hcl text/x-tfvars+x-hcl text/x-toml text/x-tpl text/xhtml text/xml text/xml-external-parsed-entity"
  TARGETS=("config/LookAndFeel/FlatDarkLaf.properties" "config/Editors/FontsColors/FlatLafDark")
  local m
  for m in $MIMES; do TARGETS+=("config/Editors/$m/FontsColors/FlatLafDark"); done
}

# ---------- contrato do nbkit ----------
odpm_status() {
  odpm_vars
  if [ -e "$MODJAR" ] || [ -d "$UD/config/Editors/FontsColors/$PROFILE" ]; then
    version_status one-dark-pro-mix "$(cat "$UD/onedark-version" 2>/dev/null || true)"
  else
    echo nao
  fi
}

odpm_caminhos() {
  printf '%s\n' config/Editors config/LookAndFeel config/.nbattrs config/Preferences/laf.properties \
    config/Preferences/org/netbeans/modules/terminal/nb.properties config/Modules/com-onedarkmix-netbeans.xml \
    modules/com-onedarkmix-netbeans.jar onedark-manifest.json onedark-state.json onedark-version
}

odpm_resumo_desinstalar() {
  echo "    ${B}Sai:${N}   perfil \"One Dark Pro Mix\", módulo de coloração, interface do tema, cor de seleção do terminal"
  echo "    ${B}Volta:${N} o visual e o perfil de cores que você usava antes"
  if [ -e "${XDG_DATA_HOME:-$HOME/.local/share}/fonts/JetBrainsMono/.onedark-installed" ]; then
    echo "    ${B}Fica:${N}  o perfil FlatLaf Dark, como sempre esteve ${D}(a JetBrains Mono sai: foi o nbkit que instalou)${N}"
  else
    echo "    ${B}Fica:${N}  o perfil FlatLaf Dark, como sempre esteve, e a fonte JetBrains Mono"
  fi
}

ODPM_BK=""
odpm_rollback() {
  if [ -n "$ODPM_BK" ]; then rm -f "$ODPM_BK"; fi
}

odpm_backups() { ls -1 "$UD"/onedark-backup-*.tar.gz 2>/dev/null | sort; return 0; }

declare -A ODPM_BKDESC=()
# o que tem dentro: interface (FlatDarkLaf.properties) e/ou cores do FlatLaf Dark
odpm_backup_desc() {
  local l n p=()
  if [ -z "${ODPM_BKDESC[$1]:-}" ]; then
    l="$(tar -tzf "$1" 2>/dev/null || true)"
    if grep -qx 'config/LookAndFeel/FlatDarkLaf.properties' <<<"$l"; then p+=("interface (FlatDarkLaf.properties)"); fi
    n="$(grep -oE '^config/Editors/[^/]+/[^/]+/FontsColors/FlatLafDark/' <<<"$l" | sort -u | wc -l || true)"
    if [ "${n:-0}" -gt 0 ]; then p+=("cores do FlatLaf Dark ($n linguagens)")
    elif grep -q '^config/Editors/FontsColors/FlatLafDark/' <<<"$l"; then p+=("cores do FlatLaf Dark"); fi
    [ ${#p[@]} -gt 0 ] || p=("vazio")
    ODPM_BKDESC[$1]="$(IFS=+; echo "${p[*]}" | sed 's/+/ + /g')"
  fi
  echo "${ODPM_BKDESC[$1]}"
}

odpm_passos_instalar() { echo 9; }
odpm_passos_desinstalar() { echo 3; }
odpm_passos_restaurar() { if [ "$(odpm_status)" != nao ]; then echo 4; else echo 2; fi; }

# ---------- ajudantes ----------
odpm_backup() {
  local existing=() t
  # reinstalacao: nao faz backup do proprio tema (senao o desinstalar restauraria ele)
  if grep -qs '^# One Dark Pro Mix' "$UD/config/LookAndFeel/FlatDarkLaf.properties"; then return; fi
  for t in "${TARGETS[@]}"; do [ -e "$UD/$t" ] && existing+=("$t"); done
  if [ ${#existing[@]} -gt 0 ]; then
    ODPM_BK="$UD/onedark-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$ODPM_BK" -C "$UD" "${existing[@]}"
    ok "salvo em ${ODPM_BK/#$HOME/\~}"
  else
    ok "nada para salvar (sem configurações de cor ou interface ainda)"
  fi
}

odpm_remove_targets() {
  local t
  for t in "${TARGETS[@]}"; do rm -rf "${UD:?}/$t"; done
}

# volta as configuracoes cobertas pelo backup exatamente como estavam nele
odpm_restore_backup() {
  local d; d="$(bk_date "$1")"
  odpm_remove_targets
  tar -xzf "$1" -C "$UD"
  touch "$UD/.lastModified"
  ok "$(odpm_backup_desc "$1") como em $d"
}

# perfil atual do editor: atributo currentFontColorProfile da pasta Editors (config/.nbattrs)
odpm_select_state() {
  python3 - "$UD" "$1" "$2" "$3" <<'PY'
import sys, os, json, re, xml.dom.minidom as M
ud, mode, laf, profile = sys.argv[1:5]
attrs = os.path.join(ud, 'config', '.nbattrs')
lafp = os.path.join(ud, 'config', 'Preferences', 'laf.properties')
state = os.path.join(ud, 'onedark-state.json')
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
    st = json.load(open(state)) if os.path.exists(state) else {'laf': None, 'profile': 'FlatLaf Dark'}
    set_laf(st.get('laf'))
    set_profile(st.get('profile'))
    if os.path.exists(state):
        os.remove(state)
PY
}

# fonte do editor configurada hoje (para avisar ao desinstalar)
odpm_current_font() {
  python3 - "$1" <<'PY' 2>/dev/null || true
import sys, xml.dom.minidom as M
for e in M.parse(sys.argv[1]).getElementsByTagName('fontcolor'):
    f = e.getElementsByTagName('font')
    if e.getAttribute('name') == 'default' and f and f[0].getAttribute('name'):
        print(f[0].getAttribute('name'), f[0].getAttribute('size'))
PY
}

# constroi o perfil (modo check: so valida a instalacao do NetBeans)
odpm_builder() {
  python3 - "$@" <<'PY'
import sys, os, re, json, glob, zipfile
import xml.dom.minidom as M

UD, STAGE, PROFILE, FONTJSON = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
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
        elif c.tagName == 'file' and len(path) >= 4 and path[0] == 'Editors' and path[-3:] == ['FontsColors', 'FlatLafDark', 'Defaults']:
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
    die('não achei as cores do FlatLaf Dark na instalação do NetBeans.')
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
    m = re.match(r'^(?:(.*)/)?FontsColors/FlatLafDark(?:/Defaults)?$', rel) if rel != '.' else None
    if not m:
        continue
    mime = m.group(1) or ''
    for fn in files:
        if not fn.endswith('.xml'):
            continue
        d = over.setdefault((mime, ftype(dirpath, fn)), {})
        for e in M.parse(os.path.join(dirpath, fn)).getElementsByTagName('fontcolor'):
            d[e.getAttribute('name')] = e

THEMEFONT = os.environ.get('ONEDARK_FONT', '')
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
        target = f'onedark-mix-{typ}.xml'
        write_xml(os.path.join(folder, target), rest)
        types_by_dir.setdefault(folder, {})[target] = typ
for folder, types in types_by_dir.items():
    write_types(folder, types)
if len(sys.argv) <= 5:
    langs = len({m for m, *_ in base})
    print(f'\u2713 {len(base)} arquivos de cores do FlatLaf Dark copiados ({langs} linguagens), {len(used)} cores substituídas pelo tema')

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
    entries, d = read_user(os.path.join(EDITORS, 'FontsColors', 'FlatLafDark', USERFILE))
    if font_of(d) is None:
        put_font(os.path.join(EDITORS, 'FontsColors', 'FlatLafDark', USERFILE), flatlaf_default, font)
PY
}

# ---------- instalar ----------
odpm_instalar() {
  odpm_vars
  STAGE="$(tmpdir)"; OLD="$(tmpdir)"
  EC="$STAGE/config"
  FC="$EC/Editors/FontsColors/FlatLafDark"
  step "Verificando a instalação do NetBeans (módulos, lexers, Java)"
  odpm_builder "$UD" "$STAGE" "$PROFILE" "" check
  ok "NetBeans encontrado"
  step "Backup do estado original"
  if grep -qs '^# One Dark Pro Mix' "$UD/config/LookAndFeel/FlatDarkLaf.properties"; then info "já existe (feito na primeira instalação)"; fi
  odpm_backup
  step "Fonte JetBrains Mono"
  # ---------- Fonte JetBrains Mono (o NetBeans nao traz; instala para o seu usuario se faltar) ----------
  FONTDIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/JetBrainsMono"
  has_jbm() {
    if command -v fc-list >/dev/null 2>&1; then
      # sem grep -q: com pipefail, o grep saindo cedo faria o fc-list falhar (SIGPIPE)
      fc-list : family 2>/dev/null | grep -E '(^|,)JetBrains Mono(,|$)' >/dev/null
    else
      ls "$FONTDIR"/JetBrainsMono-Regular.ttf "$HOME"/.fonts/JetBrainsMono-Regular.ttf \
         /usr/share/fonts/*/JetBrainsMono-Regular.ttf /usr/share/fonts/*/*/JetBrainsMono-Regular.ttf \
         /usr/local/share/fonts/*/JetBrainsMono-Regular.ttf >/dev/null 2>&1
    fi
  }
  fetch() {
    if command -v curl >/dev/null 2>&1; then curl -fsSL --max-time 60 -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then wget -q -T 60 -O "$2" "$1"
    else return 1; fi
  }
  ONEDARK_FONT=""
  if has_jbm; then
    ONEDARK_FONT="JetBrains Mono"
    info "já instalada"
  else
    info "baixando do repositório oficial da JetBrains para $FONTDIR ..."
    TMPF="$(mktemp -d)"
    okf=1
    for v in Regular Bold Italic BoldItalic; do
      if ! fetch "https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/ttf/JetBrainsMono-$v.ttf" "$TMPF/JetBrainsMono-$v.ttf" \
         || [ "$(head -c 4 "$TMPF/JetBrainsMono-$v.ttf" | od -An -tx1 | tr -d ' \n')" != "00010000" ]; then
        okf=0; break
      fi
    done
    if [ $okf = 1 ]; then
      mkdir -p "$FONTDIR"
      cp "$TMPF"/*.ttf "$FONTDIR"/
      fetch "https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/OFL.txt" "$FONTDIR/OFL.txt" || true
      touch "$FONTDIR/.onedark-installed"
      command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$FONTDIR" >/dev/null 2>&1 || true
      if has_jbm; then ONEDARK_FONT="JetBrains Mono"; info "4 arquivos instalados, cache de fontes atualizado"; fi
    fi
    rm -rf "$TMPF"
    [ -z "$ONEDARK_FONT" ] && echo "Aviso: não consegui instalar a JetBrains Mono (sem internet?); a fonte atual fica como está."
  fi
  export ONEDARK_FONT
  [ -n "$ONEDARK_FONT" ] && ok "disponível para o NetBeans"

  step "Conferindo o perfil FlatLaf Dark"
  # versoes ate a v17 gravavam o tema dentro do perfil FlatLaf Dark: devolve o FlatLaf Dark ao original
  FONTJSON="$(python3 - "$C/Editors/FontsColors/FlatLafDark/org-netbeans-modules-editor-settings-CustomFontsColors-tokenColorings.xml" <<'PY' 2>/dev/null || true
import sys, json, xml.dom.minidom as M
for e in M.parse(sys.argv[1]).getElementsByTagName('fontcolor'):
    f = e.getElementsByTagName('font')
    if e.getAttribute('name') == 'default' and f and f[0].getAttribute('name'):
        print(json.dumps({k: v for k, v in f[0].attributes.items() if k in ('name', 'size', 'style')}))
PY
  )"
  if [ -e "$C/Editors/FontsColors/FlatLafDark/Defaults/onedark-mix-tokenColorings.xml" ] \
     || [ -e "$C/Editors/text/css/FontsColors/FlatLafDark/Defaults/onedark-mix-tokenColorings.xml" ]; then
    for t in "${TARGETS[@]}"; do
      case "$t" in config/Editors/*) rm -rf "${UD:?}/$t" ;; esac
    done
    FIRST=$(ls -1 "$UD"/onedark-backup-*.tar.gz 2>/dev/null | sort | head -1 || true)
    if [ -n "$FIRST" ]; then tar -xzf "$FIRST" -C "$UD" --wildcards 'config/Editors/*' 2>/dev/null || true; fi
    info "tema de versão antiga encontrado no FlatLaf Dark: devolvido ao original"
  fi

  ok "FlatLaf Dark original preservado"
  step "Preparando as cores do tema"
  # interface: copia para mesclar suas chaves no FlatDarkLaf.properties
  LAFT="config/LookAndFeel/FlatDarkLaf.properties"
  if [ -e "$UD/$LAFT" ]; then mkdir -p "$OLD/$(dirname "$LAFT")"; cp -a "$UD/$LAFT" "$OLD/$LAFT"; fi
  rm -f "$UD/$LAFT"
  # o perfil e refeito a cada instalacao; seus ajustes (fora de Defaults) ficam
  find "$C/Editors" -depth -type d -path "*/FontsColors/$PROFILE/Defaults" -exec rm -rf {} + 2>/dev/null || true

  HDR='<?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE fontscolors PUBLIC "-//NetBeans//DTD Editor Fonts and Colors settings 1.2//EN" "https://netbeans.apache.org/dtds/EditorFontsColors-1_2.dtd">'
  PREFIX="org-netbeans-modules-editor-settings-CustomFontsColors"

  # tokens por linguagem: write_mime <mime> <<EOF ...fontcolor lines... EOF
  write_mime() {
    local dir="$EC/Editors/$1/FontsColors/FlatLafDark"
    mkdir -p "$dir"
    { echo "$HDR"; echo "<fontscolors>"; cat; echo "</fontscolors>"; } > "$dir/$PREFIX-tokenColorings.xml"
  }

  # categorias que nenhum modulo define: o NetBeans so as aceita na pasta Defaults
  write_defaults() {
    local dir="$EC/Editors/$1/FontsColors/FlatLafDark/Defaults"
    mkdir -p "$dir"
    { echo "$HDR"; echo "<fontscolors>"; cat; echo "</fontscolors>"; } > "$dir/onedark-mix-tokenColorings.xml"
  }

  # ---------- Interface (FlatLaf) ----------
  mkdir -p "$C/LookAndFeel"
  cat > "$C/LookAndFeel/FlatDarkLaf.properties" <<'EOF'
# One Dark Pro Mix para NetBeans (FlatLaf Dark)
# So chaves com equivalente direto no tema do VS Code (chave do Mix ao lado).
# Salve e reinicie o NetBeans para aplicar.

nb.preferred.color.profile=One Dark Pro Mix

# sideBar.background
@background=#21252b
# foreground (Mix nao define: padrao do VS Code)
@foreground=#cccccc
# button.secondaryBackground (botoes comuns); button.background (botao padrao)
@buttonBackground=#30333d
@accentButtonDefaultBackground=#404754
# list.activeSelection*, list.inactiveSelection*
@selectionBackground=#2c313a
@selectionForeground=#d7dae0
@selectionInactiveBackground=#323842
@selectionInactiveForeground=#d7dae0
# focusBorder, textLink.foreground, tab.activeBorder
@accentFocusColor=#3e4452c3
@accentLinkColor=#61afef
@accentUnderlineColor=#b4b4b4

# input.background, dropdown.background
TextField.background=#1d1f23
PasswordField.background=#1d1f23
FormattedTextField.background=#1d1f23
Spinner.background=#1d1f23
ComboBox.background=#21252b

# sideBar.background
List.background=@background
Tree.background=@background

# scrollbarSlider.background / hoverBackground
ScrollBar.thumb=#323741
ScrollBar.hoverThumbColor=#3e4450
# scrollbarSlider.activeBackground
ScrollBar.pressedThumbColor=#4b515e

# editorHoverWidget.background
ToolTip.background=#21252b

# editor.background, tab.*
Nb.EmptyEditorArea.background=#282c34
EditorTab.background=#21252b
EditorTab.activeBackground=#21252b
EditorTab.selectedBackground=#282c34
EditorTab.selectedForeground=#dcdcdc
EditorTab.hoverBackground=#323842
EditorTab.underlineColor=#b4b4b4
EditorTab.tabSeparatorColor=#181a1f

# list.warningForeground, textLink.foreground
nb.warningForeground=#d19a66
nb.html.link.foreground=#61afef

# Output: o painel do VS Code usa o fundo e a selecao do editor
nb.output.background=#282c34
nb.output.backgorund=#282c34
nb.output.selectionBackground=#404859

# gitDecoration.ignoredResourceForeground (Mix)
nb.versioning.ignored.color=#636b78
# diffEditor.insertedLineBackground (padrao VS Code)
nb.diff.added.color=#3f483b
# texto original no popup da barra lateral = linhas removidas: diffEditor.removedLineBackground (padrao VS Code)
nb.diff.sidebar.changed.color=#53232a
nb.diff.sidebar.deleted.color=#53232a

# ---- Padroes do VS Code para chaves que o Mix nao define ----
# sideBar.foreground (Mix, #abb2bfc4 sobre o fundo)
Tree.foreground=#8b919d
List.foreground=#8b919d
# menu.foreground (Mix)
Menu.foreground=#abb2bf
MenuItem.foreground=#abb2bf
CheckBoxMenuItem.foreground=#abb2bf
RadioButtonMenuItem.foreground=#abb2bf
# menu.background -> dropdown.background (Mix)
@menuBackground=#21252b
# input.foreground (Mix)
TextField.foreground=#abb2bf
PasswordField.foreground=#abb2bf
FormattedTextField.foreground=#abb2bf
Spinner.foreground=#abb2bf
# dropdown.foreground (padrao VS Code)
ComboBox.foreground=#f0f0f0
# button.secondaryForeground (Mix); button.foreground (padrao VS Code)
Button.foreground=#c0bdbd
Button.default.foreground=#ffffff
# editorHoverWidget.foreground -> foreground (padrao VS Code)
ToolTip.foreground=#cccccc
# checkbox.border (Mix), checkbox.background -> dropdown.background (Mix), checkbox.foreground (padrao VS Code)
CheckBox.icon.borderColor=#404754
CheckBox.icon.selectedBorderColor=#404754
CheckBox.icon.background=#21252b
CheckBox.icon.selectedBackground=#21252b
CheckBox.icon.checkmarkColor=#f0f0f0
# progressBar.background (padrao VS Code)
ProgressBar.foreground=#0e70c0
# tab.inactiveForeground = tab.activeForeground a 50% (padrao VS Code); tab.hoverForeground nulo = nao muda
EditorTab.foreground=#7e8084
EditorTab.activeForeground=#7e8084
EditorTab.hoverForeground=#7e8084
# errorForeground (padrao VS Code)
nb.errorForeground=#f48771
# Output = Debug Console: debugConsole.errorForeground / warningForeground
nb.output.err.foreground=#f48771
nb.output.warning.foreground=#d19a66
# textLink.foreground (Mix)
nb.output.link.foreground=#61afef
nb.output.link.foreground.important=#61afef
# gitDecoration.* (padrao VS Code)
nb.versioning.added.color=#81b88b
nb.versioning.modified.color=#e2c08d
nb.versioning.deleted.color=#c74e39
nb.versioning.conflicted.color=#e4676b
# diffEditor.removedLineBackground (padrao VS Code)
nb.diff.deleted.color=#53232a
EOF

  # ---------- Editor: tokens gerais ----------
  mkdir -p "$FC"
  cat > "$FC/$PREFIX-tokenColorings.xml" <<EOF
$HDR
<fontscolors>
    <fontcolor name="default" foreColor="ffabb2bf" bgColor="ff282c34"/>
    <fontcolor name="comment" foreColor="ff7f848e"/>
    <fontcolor name="keyword" foreColor="ffc678dd"/>
    <fontcolor name="string" foreColor="ff98c379"/>
    <fontcolor name="char" foreColor="ff98c379"/>
    <fontcolor name="number" foreColor="ffd19a66"/>
    <fontcolor name="operator" foreColor="ff56b6c2"/>
    <fontcolor name="separator" foreColor="ffabb2bf"/>
    <fontcolor name="identifier" foreColor="ffe06c75"/>
    <fontcolor name="field" foreColor="ffe06c75"/>
    <fontcolor name="method" foreColor="ff61afef"><font style="bold"/></fontcolor>
    <fontcolor name="markup-element" foreColor="ffe06c75"/>
    <fontcolor name="markup-attribute" foreColor="ffd19a66"/>
    <fontcolor name="markup-attribute-value" foreColor="ff98c379"/>
    <fontcolor name="url" foreColor="ff61afef" underline="ff61afef"/>
    <fontcolor name="whitespace" foreColor="ff40444b"/>
    <fontcolor name="mark-occurrences" bgColor="ff474d59"/>
    <fontcolor name="error" bgColor="ff372e34" waveUnderlined="ffc24038"/>
    <fontcolor name="warning" bgColor="ff393739" waveUnderlined="ffd19a66"/>
</fontscolors>
EOF

  # ---------- Editor: highlights ----------
  cat > "$FC/$PREFIX-highlights.xml" <<EOF
$HDR
<fontscolors>
    <fontcolor name="caret-color-insert-mode" foreColor="ff528bff"/>
    <fontcolor name="caret-color-overwrite-mode" foreColor="ff528bff"/>
    <fontcolor name="selection" bgColor="ff404859"/>
    <fontcolor name="highlight-caret-row" bgColor="ff2c313c"/>
    <fontcolor name="highlight-search" bgColor="ff45484f"/>
    <fontcolor name="line-number" foreColor="ff495162" bgColor="ff282c34"/>
    <fontcolor name="indent-guide-lines" foreColor="ff3b4048"/>
    <fontcolor name="text-limit-line-color" foreColor="ff3c4049"/>
    <fontcolor name="nbeditor-bracesMatching-match" bgColor="ff515a6b"/>
    <fontcolor name="nbeditor-bracesMatching-match-multichar" bgColor="ff515a6b"/>
    <fontcolor name="nbeditor-bracesMatching-mismatch"/>
    <fontcolor name="synchronized-text-blocks-ext" bgColor="ff393e49"/>
    <fontcolor name="synchronized-text-blocks-ext-slave" bgColor="ff393e49"/>
    <fontcolor name="nbeditor-bracesMatching-mismatch-multichar"/>
    <fontcolor name="hyperlinks" foreColor="ff61afef" underline="ff61afef"/>
    <fontcolor name="block-search" bgColor="ff2f3339"/>
    <fontcolor name="inc-search" bgColor="ff554941"/>
    <fontcolor name="code-folding" foreColor="ff808080" bgColor="ff3a3a3a"/>
    <fontcolor name="code-folding-bar" foreColor="ffc5c5c5"/>
    <fontcolor name="code-folding-border" foreColor="ffc5c5c5"/>
    <fontcolor name="coverage-covered" bgColor="ff203d49"/>
    <fontcolor name="coverage-uncovered" bgColor="ff53232a"/>
</fontscolors>
EOF

  # ---------- Editor: annotations (sublinhados de erro/aviso) ----------
  cat > "$FC/$PREFIX-annotations.xml" <<EOF
$HDR
<fontscolors>
    <fontcolor name="org-netbeans-modules-cnd-cpp-parser_annotation_err" waveUnderlined="ffc24038"/>
    <fontcolor name="org-netbeans-modules-web-core-syntax-JspParserErrorAnnotation" waveUnderlined="ffc24038"/>
    <fontcolor name="PHPError" waveUnderlined="ffc24038"/>
    <fontcolor name="PHPNotice" waveUnderlined="ffd19a66"/>
    <fontcolor name="PHPWarning" waveUnderlined="ffd19a66"/>
    <fontcolor name="CurrentPC" bgColor="ff53562a"/>
    <fontcolor name="CurrentPCLinePart" bgColor="ff53562a"/>
    <fontcolor name="CallSite" bgColor="ff415849"/>
    <fontcolor name="CurrentExpression" bgColor="ff53562a"/>
    <fontcolor name="CurrentExpressionLine" bgColor="ff53562a"/>
    <fontcolor name="CurrentExpressionLine_BP" bgColor="ff53562a"/>
    <fontcolor name="CurrentExpressionLine_CBP" bgColor="ff53562a"/>
    <fontcolor name="CurrentExpressionLine_DBP" bgColor="ff53562a"/>
    <fontcolor name="CurrentExpressionLine_DCBP" bgColor="ff53562a"/>
    <fontcolor name="Dbx_PC" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_BP" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_BP_broken" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_BP_stroke" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_CBP" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_CBP_broken" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_CBP_stroke" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_DBP" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_DBP_stroke" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_DCBP" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_DCBP_stroke" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_mixedBP" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_mixedBP_broken" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_multi_BPCBP" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_multi_BPCBP_broken" bgColor="ff53562a"/>
    <fontcolor name="debugger-PC_multi_DBPCBP" bgColor="ff53562a"/>
</fontscolors>
EOF

  # O NetBeans identifica o tipo do arquivo por este atributo
  cat > "$FC/.nbattrs" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE attributes PUBLIC "-//NetBeans//DTD DefaultAttributes 1.0//EN" "http://www.netbeans.org/dtds/attributes-1_0.dtd">
<attributes version="1.0">
    <fileobject name="$PREFIX-tokenColorings.xml">
        <attr name="nbeditor-settings-ColoringType" stringvalue="token"/>
    </fileobject>
    <fileobject name="$PREFIX-highlights.xml">
        <attr name="nbeditor-settings-ColoringType" stringvalue="highlight"/>
    </fileobject>
    <fileobject name="$PREFIX-annotations.xml">
        <attr name="nbeditor-settings-ColoringType" stringvalue="annotation"/>
    </fileobject>
</attributes>
EOF

  # ---------- Editor: por linguagem ----------
  write_mime text/css <<'EOF'
    <fontcolor name="at_rule_symbol" foreColor="ffc678dd"/>
    <fontcolor name="identifiers" foreColor="ffd19a66"/>
    <fontcolor name="mod-method" foreColor="ffd19a66"/>
    <fontcolor name="mod-custom1" foreColor="ffabb2bf"/>
    <fontcolor name="mod-custom2" foreColor="ff56b6c2"><font style="italic"/></fontcolor>
    <fontcolor name="mod-custom3" foreColor="ffabb2bf"><font style="italic"/></fontcolor>
    <fontcolor name="mod-class" foreColor="ff56b6c2"><font style="italic"/></fontcolor>
    <fontcolor name="mod-constructor" foreColor="ffabb2bf"><font style="bold"/></fontcolor>
    <fontcolor name="mod-local-variable" foreColor="ffe06c75"/>
    <fontcolor name="mod-private" foreColor="ff61afef"><font style="bold"/></fontcolor>
EOF

  write_defaults text/css <<'EOF'
    <fontcolor name="keywords" foreColor="ffc678dd"/>
    <fontcolor name="errors" foreColor="ffffffff"/>
    <fontcolor name="IMPORTANT_SYM" foreColor="ffc678dd"><font style="bold"/></fontcolor>
    <fontcolor name="CP_EQ" foreColor="ff56b6c2"/>
    <fontcolor name="CP_NOT_EQ" foreColor="ff56b6c2"/>
    <fontcolor name="VARIABLE" foreColor="ffe06c75"/>
    <fontcolor name="SASS_VAR" foreColor="ffe06c75"/>
    <fontcolor name="LESS_AND" foreColor="ffe06c75"/>
    <fontcolor name="STAR" foreColor="ffe06c75"/>
    <fontcolor name="GREATER" foreColor="ffabb2bf"/>
    <fontcolor name="TILDE" foreColor="ffabb2bf"/>
    <fontcolor name="PLUS" foreColor="ffabb2bf"/>
    <fontcolor name="INCLUDES" foreColor="ffabb2bf"/>
    <fontcolor name="DASHMATCH" foreColor="ffabb2bf"/>
    <fontcolor name="BEGINS" foreColor="ffabb2bf"/>
    <fontcolor name="ENDS" foreColor="ffabb2bf"/>
    <fontcolor name="CONTAINS" foreColor="ffabb2bf"/>
    <fontcolor name="onedark-unit" foreColor="ffe06c75"/>
    <fontcolor name="onedark-function" foreColor="ff56b6c2"/>
    <fontcolor name="onedark-tag" foreColor="ffe06c75"/>
    <fontcolor name="onedark-id" foreColor="ff61afef"/>
    <fontcolor name="onedark-bracket1" foreColor="ffd19a66"/>
    <fontcolor name="onedark-bracket2" foreColor="ffc678dd"/>
    <fontcolor name="onedark-bracket3" foreColor="ff56b6c2"/>
    <fontcolor name="onedark-bracket-unexpected" foreColor="ffd41719"/>
    <fontcolor name="onedark-attribute" foreColor="ffd19a66"/>
    <fontcolor name="onedark-string" foreColor="ff98c379"/>
    <fontcolor name="onedark-plain" foreColor="ffabb2bf"/>
    <fontcolor name="onedark-url-parameter" foreColor="ffe06c75"/>
EOF

  write_mime text/html <<'EOF'
    <fontcolor name="character" foreColor="ffe06c75"><font style="plain"/></fontcolor>
    <fontcolor name="mod-class" waveUnderlined="ffc24038"/>
    <fontcolor name="el-content" default="default" foreColor="ffabb2bf"/>
EOF

  write_mime text/javascript <<'EOF'
    <fontcolor name="COMMENT_HTML" foreColor="ff7f848e"><font style="bold"/></fontcolor>
    <fontcolor name="COMMENT_KEYWORD" foreColor="ffc678dd"><font style="bold"/></fontcolor>
    <fontcolor name="keyword" foreColor="ffc678dd"><font style="plain"/></fontcolor>
    <fontcolor name="mod-method" foreColor="ff61afef"><font style="bold"/></fontcolor>
    <fontcolor name="mod-regexp" foreColor="ffe06c75"/>
    <fontcolor name="mod-unused" waveUnderlined="ffd19a66"/>
EOF

  write_defaults text/javascript <<'EOF'
    <fontcolor name="KEYWORD_TRUE" foreColor="ffd19a66"><font style="plain"/></fontcolor>
    <fontcolor name="KEYWORD_FALSE" foreColor="ffd19a66"><font style="plain"/></fontcolor>
    <fontcolor name="KEYWORD_NULL" foreColor="ffd19a66"><font style="plain"/></fontcolor>
    <fontcolor name="KEYWORD_THIS" foreColor="ffe5c07b"><font style="plain"/></fontcolor>
    <fontcolor name="KEYWORD_SUPER" foreColor="ffe5c07b"><font style="plain"/></fontcolor>
    <fontcolor name="onedark-call" foreColor="ff61afef"><font style="bold"/></fontcolor>
    <fontcolor name="onedark-object" foreColor="ffe5c07b"/>
    <fontcolor name="onedark-type" foreColor="ffe5c07b"/>
    <fontcolor name="onedark-constant" foreColor="ffd19a66"/>
    <fontcolor name="onedark-library" foreColor="ffe5c07b"/>
    <fontcolor name="onedark-readonly" foreColor="ffe5c07b"/>
    <fontcolor name="onedark-library-function" foreColor="ff56b6c2"/>
    <fontcolor name="onedark-bracket1" foreColor="ffd19a66"/>
    <fontcolor name="onedark-bracket2" foreColor="ffc678dd"/>
    <fontcolor name="onedark-bracket3" foreColor="ff56b6c2"/>
    <fontcolor name="onedark-bracket-unexpected" foreColor="ffd41719"/>
EOF

  write_mime text/textmate <<'EOF'
    <fontcolor name="mod-class" foreColor="ffe5c07b"/>
    <fontcolor name="mod-class-declaration" foreColor="ffe5c07b"/>
    <fontcolor name="mod-enum" foreColor="ffe5c07b"/>
    <fontcolor name="mod-enum-declaration" foreColor="ffe5c07b"/>
    <fontcolor name="mod-struct" foreColor="ffe5c07b"/>
    <fontcolor name="mod-struct-declaration" foreColor="ffe5c07b"/>
    <fontcolor name="mod-typeAlias" foreColor="ffe5c07b"/>
    <fontcolor name="mod-typeAlias-declaration" foreColor="ffe5c07b"/>
    <fontcolor name="mod-typeParameter" foreColor="ffe5c07b"/>
    <fontcolor name="mod-typeParameter-declaration" foreColor="ffe5c07b"/>
    <fontcolor name="mod-enumMember" foreColor="ff56b6c2"/>
    <fontcolor name="mod-enumMember-declaration" foreColor="ff56b6c2"/>
    <fontcolor name="mod-macro" foreColor="ffd19a66"/>
    <fontcolor name="mod-macro-declaration" foreColor="ffd19a66"/>
    <fontcolor name="mod-namespace" foreColor="ffa9b7c6"/>
    <fontcolor name="mod-namespace-declaration" foreColor="ffa9b7c6"/>
    <fontcolor name="mod-package" foreColor="ffa9b7c6"/>
    <fontcolor name="mod-package-declaration" foreColor="ffa9b7c6"/>
    <fontcolor name="constant.other" foreColor="ffd19a66"/>
    <fontcolor name="support.function" foreColor="ff56b6c2"/>
    <fontcolor name="markup.heading" foreColor="ffe06c75"><font style="bold"/></fontcolor>
    <fontcolor name="markup.bold" foreColor="ffd19a66"><font style="bold"/></fontcolor>
    <fontcolor name="markup.italic" foreColor="ffc678dd"><font style="italic"/></fontcolor>
EOF

  write_mime text/x-apache-conf <<'EOF'
    <fontcolor name="variable" foreColor="ffa9b7c6"/>
EOF

  write_mime text/x-diff <<'EOF'
    <fontcolor name="added" foreColor="ff98c379"/>
    <fontcolor name="removed" foreColor="ffe06c75"/>
    <fontcolor name="filename" foreColor="ff61afef"><font style="bold+italic"/></fontcolor>
EOF

  write_mime text/x-el <<'EOF'
    <fontcolor name="identifier" foreColor="ffe06c75"/>
    <fontcolor name="keywords" foreColor="ffc678dd"><font style="plain"/></fontcolor>
    <fontcolor name="tag-lib-prefix" default="default" foreColor="ffe5c07b"><font style="plain"/></fontcolor>
EOF

  write_defaults text/x-el <<'EOF'
    <fontcolor name="TRUE_KEYWORD" foreColor="ffd19a66"><font style="plain"/></fontcolor>
    <fontcolor name="FALSE_KEYWORD" foreColor="ffd19a66"><font style="plain"/></fontcolor>
    <fontcolor name="NULL_KEYWORD" foreColor="ffd19a66"><font style="plain"/></fontcolor>
    <fontcolor name="onedark-call" foreColor="ff61afef"><font style="bold"/></fontcolor>
    <fontcolor name="onedark-object" foreColor="ffe5c07b"/>
    <fontcolor name="onedark-library" foreColor="ffe5c07b"/>
    <fontcolor name="onedark-bracket1" foreColor="ffd19a66"/>
    <fontcolor name="onedark-bracket2" foreColor="ffc678dd"/>
    <fontcolor name="onedark-bracket3" foreColor="ff56b6c2"/>
    <fontcolor name="onedark-bracket-unexpected" foreColor="ffd41719"/>
EOF

  write_mime text/x-env <<'EOF'
    <fontcolor name="key" foreColor="ffa9b7c6"/>
EOF

  write_mime text/x-java <<'EOF'
    <fontcolor name="literal" foreColor="ffd19a66"/>
    <fontcolor name="string-escape" foreColor="ff56b6c2"/>
    <fontcolor name="character-escape" foreColor="ff56b6c2"><font style="bold"/></fontcolor>
    <fontcolor name="javadoc-tag" foreColor="ffc678dd"><font style="bold"/></fontcolor>
    <fontcolor name="javadoc-identifier" foreColor="ff7f848e"/>
    <fontcolor name="html-tag" foreColor="ff7f848e"><font style="italic"/></fontcolor>
    <fontcolor name="mod-class" foreColor="ffe5c07b"/>
    <fontcolor name="mod-class-declaration" foreColor="ffe5c07b"><font style="bold"/></fontcolor>
    <fontcolor name="mod-interface" foreColor="ffe5c07b"/>
    <fontcolor name="mod-interface-declaration" foreColor="ffe5c07b"><font style="bold"/></fontcolor>
    <fontcolor name="mod-enum" foreColor="ffe5c07b"/>
    <fontcolor name="mod-enum-declaration" foreColor="ffe5c07b"><font style="bold"/></fontcolor>
    <fontcolor name="mod-record-declaration" foreColor="ffe5c07b"><font style="bold"/></fontcolor>
    <fontcolor name="mod-annotation-type" foreColor="ffe5c07b"/>
    <fontcolor name="mod-annotation-type-declaration" foreColor="ffe5c07b"><font style="bold"/></fontcolor>
    <fontcolor name="mod-constructor" foreColor="ffe5c07b"/>
    <fontcolor name="mod-constructor-declaration" foreColor="ff61afef"><font style="bold"/></fontcolor>
    <fontcolor name="mod-method" foreColor="ff61afef"><font style="bold"/></fontcolor>
    <fontcolor name="mod-method-declaration" foreColor="ff61afef"><font style="bold"/></fontcolor>
    <fontcolor name="mod-field" foreColor="ffe06c75"/>
    <fontcolor name="mod-field-declaration" foreColor="ffe06c75"/>
    <fontcolor name="mod-local-variable" foreColor="ffe06c75"/>
    <fontcolor name="mod-local-variable-declaration" foreColor="ffe06c75"/>
    <fontcolor name="mod-parameter" foreColor="ffe06c75"/>
    <fontcolor name="mod-parameter-declaration" foreColor="ffe06c75"/>
    <fontcolor name="string-escape-invalid" waveUnderlined="ffc24038"/>
    <fontcolor name="mod-record" foreColor="ffe5c07b"/>
    <fontcolor name="mod-unused"/>
EOF

  write_mime text/x-jflex <<'EOF'
    <fontcolor name="directive_value" foreColor="ffa9b7c6"><font style="bold"/></fontcolor>
EOF

  write_mime text/x-json <<'EOF'
    <fontcolor name="COMMENT_HTML" foreColor="ff7f848e"><font style="bold"/></fontcolor>
    <fontcolor name="COMMENT_KEYWORD" foreColor="ffc678dd"><font style="bold"/></fontcolor>
    <fontcolor name="mod-class" foreColor="ffe5c07b"><font style="bold"/></fontcolor>
    <fontcolor name="mod-method" foreColor="ff61afef"><font style="bold"/></fontcolor>
    <fontcolor name="mod-regexp" foreColor="ffe06c75"/>
    <fontcolor name="mod-unused" waveUnderlined="ffd19a66"/>
EOF

  write_defaults text/x-json <<'EOF'
    <fontcolor name="KEYWORD_TRUE" foreColor="ffd19a66"><font style="plain"/></fontcolor>
    <fontcolor name="KEYWORD_FALSE" foreColor="ffd19a66"><font style="plain"/></fontcolor>
    <fontcolor name="KEYWORD_NULL" foreColor="ffd19a66"><font style="plain"/></fontcolor>
    <fontcolor name="onedark-bracket1" foreColor="ffd19a66"/>
    <fontcolor name="onedark-bracket2" foreColor="ffc678dd"/>
    <fontcolor name="onedark-bracket3" foreColor="ff56b6c2"/>
    <fontcolor name="onedark-bracket-unexpected" foreColor="ffd41719"/>
EOF

  write_mime text/x-jsp <<'EOF'
    <fontcolor name="attribute-value" foreColor="ff98c379"/>
    <fontcolor name="comment" foreColor="ff7f848e"/>
    <fontcolor name="endtag" foreColor="ffe06c75"><font style="bold"/></fontcolor>
    <fontcolor name="tag-directive" foreColor="ffc678dd"><font style="bold"/></fontcolor>
    <fontcolor name="error" foreColor="ffffffff"><font style="bold"/></fontcolor>
    <fontcolor name="expression-language" default="default"/>
    <fontcolor name="scriptlet" default="default"/>
    <fontcolor name="scriptlet-delimiter" default="default"/>
EOF

  write_mime text/x-yaml <<'EOF'
    <fontcolor name="RUBYCOMMENT" default="comment"/>
EOF

  write_mime text/x-markdown <<'EOF'
    <fontcolor name="header" foreColor="ffe06c75"><font style="bold"/></fontcolor>
    <fontcolor name="header2" foreColor="ffe06c75"/>
    <fontcolor name="header3" foreColor="ffe06c75"/>
    <fontcolor name="header4" foreColor="ffe06c75"/>
    <fontcolor name="header5" foreColor="ffe06c75"/>
    <fontcolor name="header6" foreColor="ffe06c75"/>
    <fontcolor name="bulletlist" foreColor="ffe5c07b"/>
    <fontcolor name="orderedlist" foreColor="ffe5c07b"/>
    <fontcolor name="emph" foreColor="ffc678dd"><font style="italic"/></fontcolor>
    <fontcolor name="strong" foreColor="ffd19a66"><font style="bold"/></fontcolor>
    <fontcolor name="strikethrough"/>
EOF

  write_mime text/x-nbs <<'EOF'
    <fontcolor name="identifier" foreColor="ffa9b7c6"/>
EOF

  write_mime text/x-neon <<'EOF'
    <fontcolor name="literal" foreColor="ffa9b7c6"/>
EOF

  write_mime text/x-oql <<'EOF'
    <fontcolor name="clazz" foreColor="ffa9b7c6"><font style="italic"/></fontcolor>
EOF

  write_mime text/x-php5 <<'EOF'
    <fontcolor name="mod-method" foreColor="ff61afef"><font style="bold"/></fontcolor>
    <fontcolor name="phpopenclose" foreColor="ffbe5046"><font style="bold"/></fontcolor>
    <fontcolor name="variable" foreColor="ffe06c75"/>
    <fontcolor name="mod-custom1" foreColor="ffa9b7c6"/>
    <fontcolor name="keyword" foreColor="ffc678dd"><font style="plain"/></fontcolor>
    <fontcolor name="mod-unused" waveUnderlined="ffd19a66"/>
    <fontcolor name="mod-deprecated" strikeThrough="ffc3c3c3"/>
EOF

  write_mime text/x-properties <<'EOF'
    <fontcolor name="properties-equal-sign" foreColor="ffabb2bf"/>
EOF

  write_mime text/x-repl <<'EOF'
    <fontcolor name="command" foreColor="ffa9b7c6"><font style="bold"/></fontcolor>
    <fontcolor name="command-option" foreColor="ffa9b7c6"><font style="bold"/></fontcolor>
    <fontcolor name="prompt" foreColor="ffa9b7c6"><font style="bold"/></fontcolor>
EOF

  write_mime text/x-sql <<'EOF'
    <fontcolor name="sql-identifier" foreColor="ffabb2bf"/>
EOF

  write_mime text/x-tag <<'EOF'
    <fontcolor name="attribute-value" foreColor="ff98c379"/>
    <fontcolor name="comment" foreColor="ff7f848e"><font style="bold"/></fontcolor>
    <fontcolor name="endtag" foreColor="ffe06c75"><font style="bold"/></fontcolor>
    <fontcolor name="tag-directive" foreColor="ffc678dd"><font style="bold"/></fontcolor>
    <fontcolor name="error" foreColor="ffffffff"><font style="bold"/></fontcolor>
    <fontcolor name="expression-language" default="default"/>
    <fontcolor name="scriptlet" default="default"/>
    <fontcolor name="scriptlet-delimiter" default="default"/>
EOF

  write_mime text/x-terraform+x-hcl <<'EOF'
    <fontcolor name="mod-field" foreColor="ff9876aa"/>
EOF

  write_mime text/x-tfvars+x-hcl <<'EOF'
    <fontcolor name="mod-field" foreColor="ff9876aa"/>
EOF

  write_mime text/x-toml <<'EOF'
    <fontcolor name="mod-global" foreColor="ffa9b7c6"><font style="bold"/></fontcolor>
    <fontcolor name="string-escape" foreColor="ff56b6c2"/>
    <fontcolor name="table-mark" foreColor="ffa9b7c6"><font style="bold"/></fontcolor>
EOF

  write_mime text/x-tpl <<'EOF'
    <fontcolor name="error" waveUnderlined="ffc24038"/>
    <fontcolor name="smarty" default="default"/>
EOF

  write_mime text/xml <<'EOF'
    <fontcolor name="xml-doctype" foreColor="ffc678dd"/>
    <fontcolor name="xml-operator" foreColor="ffabb2bf"/>
    <fontcolor name="xml-value" foreColor="ff98c379"/>
    <fontcolor name="xml-pi-start" foreColor="ffabb2bf"/>
    <fontcolor name="xml-pi-end" foreColor="ffabb2bf"/>
    <fontcolor name="xml-pi-target" foreColor="ffe06c75"/>
EOF

  write_mime text/xml-external-parsed-entity <<'EOF'
    <fontcolor name="xml-doctype" foreColor="ffc678dd"><font style="bold"/></fontcolor>
    <fontcolor name="xml-value" foreColor="ff98c379"/>
    <fontcolor name="xml-pi-start" foreColor="ffabb2bf"><font style="bold"/></fontcolor>
    <fontcolor name="xml-pi-end" foreColor="ffabb2bf"><font style="bold"/></fontcolor>
    <fontcolor name="xml-pi-target" foreColor="ffe06c75"><font style="bold"/></fontcolor>
    <fontcolor name="xml-cdata-section" foreColor="ff98c379"/>
EOF

  write_mime text/xhtml <<'EOF'
    <fontcolor name="expression-language" default="default"/>
EOF

  write_defaults text/x-java <<'EOF'
    <fontcolor name="onedark-bracket1" foreColor="ffd19a66"/>
    <fontcolor name="onedark-bracket2" foreColor="ffc678dd"/>
    <fontcolor name="onedark-bracket3" foreColor="ff56b6c2"/>
    <fontcolor name="onedark-bracket-unexpected" foreColor="ffd41719"/>
EOF

  write_defaults text/html <<'EOF'
    <fontcolor name="onedark-plain" foreColor="ffabb2bf"/>
    <fontcolor name="onedark-doctype" foreColor="ffe06c75"/>
    <fontcolor name="onedark-attribute" foreColor="ffd19a66"/>
    <fontcolor name="onedark-string" foreColor="ff98c379"/>
EOF

  write_defaults text/xml <<'EOF'
    <fontcolor name="onedark-plain" foreColor="ffabb2bf"/>
    <fontcolor name="onedark-attribute" foreColor="ffd19a66"/>
    <fontcolor name="onedark-string" foreColor="ff98c379"/>
    <fontcolor name="onedark-keyword" foreColor="ffc678dd"/>
    <fontcolor name="onedark-documentroot" foreColor="ffe5c07b"/>
    <fontcolor name="onedark-doctype" foreColor="ffe06c75"/>
EOF

  write_defaults text/xml-external-parsed-entity <<'EOF'
    <fontcolor name="onedark-plain" foreColor="ffabb2bf"/>
    <fontcolor name="onedark-attribute" foreColor="ffd19a66"/>
    <fontcolor name="onedark-string" foreColor="ff98c379"/>
    <fontcolor name="onedark-keyword" foreColor="ffc678dd"/>
    <fontcolor name="onedark-documentroot" foreColor="ffe5c07b"/>
    <fontcolor name="onedark-doctype" foreColor="ffe06c75"/>
EOF

  ok "interface, editor e categorias do módulo prontos"
  step "Montando o perfil \"$PROFILE\" (cópia do FlatLaf Dark da sua versão + tema)"
  # ---------- Perfil "One Dark Pro Mix": copia do FlatLaf Dark da sua instalacao + cores do tema ----------

  { odpm_builder "$UD" "$STAGE" "$PROFILE" "$FONTJSON"; } 2>&1 | sed 's/^/      /'

  step "Instalando o módulo de coloração (chamadas, colchetes, unidades, tags...)"
  # ---------- Modulo de coloracao por padrao ----------
  mkdir -p "$UD/modules" "$C/Modules"
  base64 -d > "$MODJAR" <<'B64'
UEsDBAoAAAgAABZ/aV0AAAAAAAAAAAAAAAAJAAQATUVUQS1JTkYv/soAAFBLAwQUAAgICAAWf2ld
AAAAAAAAAAAAAAAAFAAAAE1FVEEtSU5GL01BTklGRVNULk1GhZJNS8NAEIbvgfyHOSo0m6YgSg49
2AoqrS0UvU93x3ToZifsbiT995JaP6N4Wth95nl5mV2i42cKMXsiH1hcCYUap8mqIXc3v8mWYlpL
JWiplTgy6Pc1d8pR3BK68BPMNg1pfmaNkcV9dV4M0AesqYSVI5ij38PaCyy5g1uudparXfxFvhMf
szkF7bmJR/FMrHjUKNCIhwaNRwFDEKmLAmf3mxHcLEZpAjDbbM77GoABtHgKYGSQPohc4IH8sX7+
WT9/r5/b/ll1tR0MrtutZZ2tUe+xolBCNkDu8QWzOTXkDDnNPdRfwRSKywF8Or7j4quPVaj6SARF
hqN4ZXk7yQuY9t0LNR79DlvqyOeTPvNP5iSs0wS4Jiuyb5ve/P9IoBjZVeE7LU2aADk2pNrIVr0Z
YQpX/c+becJIJrs+lDAp1FgVE1XA2eO2dbE9T5M0eQVQSwcIWT1/ZVIBAACzAgAAUEsDBAoAAAgA
ABZ/aV0AAAAAAAAAAAAAAAAEAAAAY29tL1BLAwQKAAAIAAAWf2ldAAAAAAAAAAAAAAAADwAAAGNv
bS9vbmVkYXJrbWl4L1BLAwQKAAAIAAAWf2ldAAAAAAAAAAAAAAAAGAAAAGNvbS9vbmVkYXJrbWl4
L25ldGJlYW5zL1BLAwQUAAgICAAWf2ldAAAAAAAAAAAAAAAAOgAAAGNvbS9vbmVkYXJrbWl4L25l
dGJlYW5zL01peEhpZ2hsaWdodHNGYWN0b3J5JFBhaW50ZXIuY2xhc3Odlu1zU8cVxn/Hsn2NuK6F
CaQmCSREJJJscqFNmxeBARuI3UiGYONA+rqW1tLF0r3KvSvbtGlDX9LXpE37sf9APmcGbF5m+rGd
6fQv6nQ6nb2SsXmJof6i1e4+e85znj3n3P3nf+/+DTjJX9L0kHLodemjX8hcU8vKa6ig5l1YuKYr
Rug/4Qe+GRdSufz8LgbY5ZB22Y0rvF4Jm14Y6KqKlpr+qhdos6BVEHtlf3XKr9Ubfq1u4vOqYsLo
evai8gOjIyFVDSvCcyXrbNWLV/yg5hm9aryzYaXd1IEpOnxNeCOMapsm45bv6apvwsirb5i2B+N2
qxVGxruwuBhrE0+oWppBMjagPcLB3DZeOvHsdXmGfUJqQdWEt0o79Fp0eFbYs9XbnN/U0TAw4nKA
54QhVTF+GFzU0WIYNXVVeD9X2omGxXwSlqdWjKeXdWC8M4nlkh8bHeiomGY/L1gNDgov56afgO4I
8aLLSxwW+ozlLewtPRJMYjfrcoRXhHSszSXd0srEQm/ug/z8bnLkHQouo4wJI18pvbBXVasbsw0e
wqsPXleH7MOwYn7e0njNxbM52xcbFRm7ctzlG3bFiXSyNozwusu3+LaQitqB8MkO5d5xUnTvKamo
S+0gUAsNXbQyvenyFm8L/ZEOqjb0Z3OPg9pQBznhcpJxYTDWZpOkcCK3c2KJ4dMuZxLFqn5cUVE1
zSRnHc65nOcd4cgD1lXL9xp6VUfeXLikgylfRyqq1K8LqZo2wtlta630VLaKlsG0y3d4Vxg0dm9W
f9jWQUULudz2VjaQRYdytxS9tvEb3pSK62XVSlMiZcW/6PIel4RdNW1KOqiZetLepu3enMtl5gWn
ps2cXjXC/tz09NZ7nDWRH9SKaa5w1eEDl+/yPWHs/0ksYUA3SmFFNWJbn48a7/pL2M9qkzj7gcsP
+ZHQu6IaS8KN3NOJseMU2UKhrFrFhxjl5x0WhAMPJK3tHOdWK7pl24tDVTjySEpMqKqN3CLuQ9MM
sOhS61bvYqTjuoMvHH5yOxB6J8OqFoZKfqBn2s0FHc3Z4hFcP4h1ZC63qspoIbtddzm33PkkCG6k
m+Gy3jg1WKmroKarG/NMQzUXqirbpZk9LgzOGlVZKqtW4tchFrJPczcObWHvpoL39RDcrpdAr2SP
CYdyj2/hm6zTs2E7qujzvg185HFJ95q1IAzM6NhMhbERMhNhaGITqVZZm3pYjTOsDPXxM3sdH7ss
s5Khf6iPX9iFX7q0GB/q55M0v+Y3Dr91+R2/795RJwA/WA6XtFdKuJe1UYsb+b67uXX2r60p3z3U
oTClgmpDx9lSGC61N5Jua2V81cG56y29s82Oy+3P5h/dnVSNxqxvdFFwp4NAR5MNFcc6FpzuZ8Ph
j90CeGKgDp8LB7eHCv0dMMcYoAehToqMfYoBGfuKScaXOAw4YJ9ACNcAQx89wOnCOlIYvYVTuMfg
1dF1hm4xXLjH/qt7ZKxwl6/DOs/f4lDhJodSa7w8WrjDqz3Y6RpHvwSEJeAwA8Db9FJkFyfYx0ny
jHOcU7zJaU5xBqFBs8vgRSRhMNCxdGzTUj8CTCIET40+ixDeR49AgpaHYefANpUu7D1SCSxvQy/c
xFlnqGTHwuhdvgl3eCMJdHh0jeLoGqc2ze2nD5jCZZrnmSPLZXLMZ3psTXTN/5V+ehONb+LcZqI8
9g8c+QJnbI2pmaN/58jR0XuUrq4zYxEp+3OHC8IdZlPc5v3bfP8LestfJiSLjKO6Y4WehMXB5Fbf
ZYAS+ygzwgxFLjHORU4xy4fAM/T9h4zD5KRD9G9emXAwZHpsMXd5vtDVtq+whn5YsZP0sprIeZ0f
J+MVfpII0MOvSPERP+Wj5N8Nfs4N/gAM08MAV/iUA3zGn/gzI/8DUEsHCLeVPriPBQAAYgwAAFBL
AwQUAAgICAAWf2ldAAAAAAAAAAAAAAAANgAAAGNvbS9vbmVkYXJrbWl4L25ldGJlYW5zL01peEhp
Z2hsaWdodHNGYWN0b3J5JFRvay5jbGFzc5WQy27TUBRF17GTODUONWl5pFCg0EqpiUhhymNSqWqk
UgaNOq6TXDm3ca4l+xaFf2KC1IDEgA/goxCyQUJQJoy2tI/24+xv3798BV6x4+PgetQC6jSE8Dx+
F/fT2CT9t6NzNbZC46U22r4W3O7u6QpNVjz8gGsEwt44m/czoyZxPpvrRd8oO1KxKfpv9OJQJ9NU
J1NbHMRjm+Xvt4fZTHD0RGgf/c45sbk2yYvS+XrAamlbs2phS+JGQJs1oV7YOLeCDHxucsvjdsAd
On/0/ekjNFJlEjut+g6Ebvdq1lVmsHsq1PaziRJWj7RRxxfzkcqH8ShVgqvMRPBPsot8rA50SXX+
9eHT0ldoHqvCHmaF9Xgk9P5nIyEYGKPy/TQuClUI7jCbsUcTB3AJy92BsByqwjZrUF3rbCDcBXo4
1ID16DMSPVniRb0lrWhzSfgREO4BDQR4BmzS+aXcwanYVnRJGF3S+sT62Ye/JM9xuV+FPuBhhVs8
BnyEJltss/EDUEsHCINauZ9/AQAAYQIAAFBLAwQUAAgICAAWf2ldAAAAAAAAAAAAAAAAMgAAAGNv
bS9vbmVkYXJrbWl4L25ldGJlYW5zL01peEhpZ2hsaWdodHNGYWN0b3J5LmNsYXNz1XwJeFTV+ffv
PefO3DuTm2SSywADhH1JJhkWlwgJAiFMIJrNTACHxTAklzAwmYkzExbFHdfaaltbG7RqURu0rdVg
Y6itW11au9rVLtZq7WZrd/9VBPI959w7ySSAon+/r8/Hg+Ys7znnfd/z7ueG54999TEAZ/Pn3GDg
KhQdDjgJnm2RHZF5sUi8Y17j5m1mW5rgXByNR9NLCLy4ZI0bGlwq3DpyoBOqE8mOeXEzvdmMxFPz
Ul3ReWZ7NJ1Iztsa7dgai3ZsTUfjHfNWZTqpushuM1kTaUsnkrtnVifiaXNXmpDTYaZXJNq6O814
mlBUXFInsNg1L7VTrBYw8zLTlSryCGe0JTrnJeJmeyS5vTO6axiD+uiu4cMy5zRFovG0mcyBBwUq
CnUYGEPwnfQMC6GmZKLLTKZ3E2YX143mSmXJ8UNu5GKsYOM4wuTidyGhZI1AxadjAiYScrq6s86a
c4KzTnD6GhVFhDM+CPdVTCGUvR8GujEN01XM0DETswj5w+hUxyKpFEHtMNMNkU6TMKY4mzGhdDIa
76h0YQ6KVZTo8KOUUHpKWK9rTLabSUJOKNzQUnV+a3NV9bmEQN37WFzpxhwEdMzFPELOlkSyKZGK
pqOJOGF+cW3J+9rKhVws0HEaTifwzZEOwqJTW5/q7upKJNPzGrdsSZnp1PJIR6Ubk3CmjnKcRXC2
Jc1I2iT0FR/PuPeF4bpTgx6+XaF+kWjcTFaeIitGCVKlikWEAol1dzoam7cqktoaMtNuLAR3YTIW
6zgbSwhqsK51RbC6juCrG4ZOmh3mrnlNkXTaTMYr3ViGKhXLdVRjBWHcSeAIamck3bZVSMbp2Ryr
3hpJhswLu814m5lRzqzl9daiSjdqsFLFKh21OOcEx9RnNle2ROPt0uStE2vqdNSjgeDoSCa6uwhe
IT/H3VcOmnCeimYdIbQQcod3D5lpAo+0t4ulJ9DndSrWEIzhBVXJZGR3XTSVdmM1uBthrFOxXscG
YaRnjriuSFd0XszcZSbntSS2m/EMFwiuzsQOM5SOJNNi/QU6WgXNmhhtMHfJwYiOzWgjONJiKWFq
8ShZGLV5pQqTMP99md+WxHY3OrBVRVTHNmwnTHq3Iwgs2k6Y/h6Y1LZX5qATcRUJHV3CLk1+d3CC
Eo90mgKVpI4U0gTFcj8TRhitEZKUgx3YqWKXjt3iiLEnBiNo6YQlA4KpF+vYg0sIzoTUeSlFtW60
4zLhHS4nFJ9I148bqRV+4kohUFcR8oZFw5KKMK7WcQ2uJWhm52azvd1sFxu/O9OG6BLrr9dxAz5C
0MSh3ZEOkzDj5OvrbKBKNz6Kj6m4ScfNgiVT3gNeCFy002zZ3WWKQz+h45O4haBnDm2KpLcKt/ee
BwvASjc+jVtVfEZHjzh8ximssREQzUIAt+m4HZ8lOCJdXbHdhCnF2dZiS3e8TXiIeTV2ozIHd+Iu
FZ/TsR93j9Dp+kgXIb8t0dnVnTZrt1RtTsnYofqkHvwkJ5wglBCH3qvj80Jf1Wgq2NmV3u3GAdyn
4n4dXxDC5RktLwRtayS1tTrRbmr4EiFfBh0CKtWWjHalxfov63hQWCaneWF3JJbS0EdwSbhdATOm
4WEhyaLblkpp6M9Mbk13xjQMZCZ3id5XCVMyvYC5SxjnSCzQFUmmzPaAGU9HBcaT8TUdX8djBLYt
RVhfXDdSjE/Rw53Ah9aNuIdKEZhOxhM6nsRTBGbGCNv+rx1WN8Ku22c/reMZQShvS6VE/zkd3xR9
RTBPDDyv49sSQLLvu4Qcm/FiNw3fzxpIJeJixQs6fihWaJuTkbbtZjolzMGPdfwEPyVo0bSZjKQT
ScLYESJca49X5uBF/FzFL3T8UshR4fEgBHVrJCV8gYB9Scev8bIwk9IqjgzlhmLcyXhFx6v4LUHZ
GYltJ1xefGom5/8a91X87rgwpD7S5cZrwnH+EX9S8bqOP+MvhMBxmNo4CAsRSyS2d3fNq492mnWy
SXB1mOlMO3ACo20ZrUSXGY+2m7akSfBKFX8lnHay41JmWlCbmleTiKerE7FEMmSPuPF3/EPFP3X8
C/8mjDvJ/gRnzG7MGhEGiYD8RBZFxGP/o+M/eIvgaKiqD4YIxvrjKXLjDRzW8Q6OEAo7zLS8wyEs
U6OiriE2HJfsVKXTyejm7rQp7kiYs2M6BgkE3tWdJiw8tTTnhJaRmE5cZHC8w0yr5CAUvevxblJJ
U8mlk5tyCGd9QDkk6JH29qHwhjCzuLb2PQgvWaNRLsG9dlVtSzDUVFUd1CifwIONdRoVENTqxvr6
YEOLGwfI0GkMeYU7j7en1kaF4/KeiNfrXGincTq20XhC4fEAGk0guGtXBBtaamtqg80aTSIUNjXX
rqlqCbZmj08m6I1Nweaqlsbm1hWNLRpNJYwfGmlsaqltbKiqa62qrg6GQjm4kqbrNEM4HyUVvcgU
A7N04jT7uHh42FpQsU4l5JdurLZdOsgzi+veb/xYWbJOozICNJpLyBtCsbqxrrFBnDJfpwWCeY5o
akUiLTh0uo4UjdfoTOHqU7vjbRqdRfCcGwyvbWxe0VqzuqFakKfRouwNq5qbG9dqVEkoXC4yzmBL
a12wpqW1qao52KDR2QQjM95cu3KVPSEwWKrTMqoiqG2xREq644XHOaDaUwn7RKg4map1WiEIcm5L
hbZHuzSqIeRkkF9T1azRKoLeHAwFm9cEV7TWBVs0OoeQmwGpbmwItWhURxgzghC7o1HDaBKrVzfX
hTVqInhHkji0pPk46uUagW6LTqtpDUFvS8RiZpusBqSEihzHgtrj7LdG5xOM4SsIhWpXNlhaMZnW
6bSeNhByM3HTmkisWxYajtu5ZJ3Iv36sUStBzyZNaFdEp82Cn+6UyIekfmnUTsgdQZBGW0aKV319
lUZbCYVDY6Fgfa0UO422EcivUSyb7VUt1as0imcP1VWFQhp1EQozQ7UNoZaqhupgY40gMalTitIE
dzTVbKYSsR0ikj/vpCnCEOfeV1cyh3botFPEf1qblfunXJhMu3W6iC4m5NTVLrewFc4hf9QGAvIS
nS4VkJqAXFPVHNLocoJua3IgvbvLFKp3pU5X0V6CQ/KaQCL5oWt0ulbYDm7G2wXZ1+t0A32E4OgS
5TlCa/GHGyGMSKVqhZh9NAvXtkgsptFNBE9mJGlG2hPx2G6NPk7Iz4zGopuTkeRuQf0ndbpFUO8S
1Av7EdLo04Txo0ADGUkVaz6jU49Yo58TslSyqqElpNFtWee2JeKpdCSeFjz5rE530J12nN0p60KX
fXhsed9Wd906wbbPEfSM5Lasqg0Juu7W6R5BV97KusblVXWtjcvPCVYLyj5PyMtQlpBeQKMDBGed
bUHvJ/AVjS1ijy/q9CUpd8G61tr6prra6toWjb5MYGtDGj1EYA11Gh0kKK2hcL1GXyFoVS2WB9Po
EYIjVBUKtWp0iKDJprSLjxJ02VsRrKlaXdei0ddFFVGMWMhq9DghVw5kXJxGTxJ8cih4fkuwYUVr
Y0NduDUUrAtWtzQ2a/QNQYIwFUGNniHkrKoKrRJYLReO/DmhEUNW8lsEZ7NN7bcJWvPQzHfFjNzE
Td+nH6j0gk4/pB9lglcpsLXxtNkhClDqDmHoGreI8H6Eb7UhKjX6CUER5kjs9jOdXhTapUXjaWki
hXf+hU6/FPUiR1vMjCQ1eskySzXNIv4T6AvL+LJOO+k3hIknL6etc9Or9FuVXhP4/m4EvssTiZgZ
iQss12VjaY9XipTlXoHLH3X6k4gUnElTFKCEtP9Zp7/IiCeaqko3d8dMccxfdfqbSFf0zdYOkhgB
/Q+d/img1baU7RL/TXDY0vA/BHdTsLk62NBStTKo0VuE3IwYdsUiUamMh3V6RypwdSjUurqhtkWK
8lGdjokqpbNhdf3yYLMbNXSNGwcY6YzJKk7MjHekt2pMyTIf3fFo2oXJzKkzVepBfe35tQ2ttpqE
NObK0vCMQdBYDqEgMxrJBIoayyUojU3B8zSWT9BqG6rrVq8IhjRWQHCtqAqtqpdehRkE5/LgytqG
kMa8BCXYIE4aR9CqGxtaquS4L0v/UtL4aWwiwWG5LFZEcK6w21OE2AZDodaqhhUam0Zw1Nc2rA5p
bAahYJiZGTFnswg5Q6Y+0qGxOQRFKILGSgjuzFS0XTCmVGdlLEBwNFXVNo9yJ8IYCZh5Opsv8hFn
XXBNsE5cBjtNZ6cLfqrVdY2hYHNIY2cSJmS2tvPgQHfc3NVltqXNdo2dReCrm2s1tkg26sQulTpb
LK7Utbq5rrWl8VwRodWwJTpbKgsqVgU5JcaqdLqKLScoxbUi7qphK3S6li0X91+js5VslajQb40k
q9IWTLXGziF4h8QgKUsekU4zbSY1Vkdwnl9f19okQjjWoLNG1kRw7OqMNUUJl3yAuPfDq49orJmQ
I8rwVc1VMvJlLQTX4mkrGqtbwk1BQfIana1l5xNyk2ZHNBG3iuEpgq943QlC19pakYtMZut0tl5w
W7d3EjFxi+DlRp2uwiUaa83yp+2JNitMmMwiOtssnweaauUSjbULLa4VjrIl2CB8BNuisw4BkyPY
au+vsWjWhtvN3TsTyXaNbSeMyTpFPrUlEwmppp06i4ttPFnbtDYHQxLNLp1dyJLSMnXIx6Gi4tra
kz8haCxN6NywuXhpxY5Ics+OSDKUjqS7UyUbUv6zN6T866fP2Vi8viqwLhK4qHXmxvUbds7c6C8R
o3sWd0crpLhs2Lz+giUb/Us3bBYl6fdc6MYytkNnO9kuYf4SnV3RmHmygsTJHlg0dlGWSbI1aYHG
9hw/eprGLj1+9HSNXU5wdcfbzS3RuFC9Kwm8IdKgsb3CasW3iGfi3TloYtfo7Fp2HYElthBWnlKq
f9LkfygA1dgNBOfOaLw9sVNjNxK0zC1r7GOSL/FUImZq7GaCKx7ZEe0QJS6NfUJUuBNtEcsC3yJq
XtGUUDCNfVrUoRNtkVgonUhGOkyNfYaQlzJTqWgiPjS2j+DuiCU2R2ItW6Mpjd0u8l8ztkVjdxCU
+ojwDXcRlHNCQqn2E5TaeDqmsXsIarO5RaRDGvs8Qa1KJzqjbSmNiYAo1ZY0zbjG7hcvwGZySyLZ
GYm3mRr7onwU3N2VTghWPiBY+WWRSa0/FRY9RHBakxo7SHDIZySNfYXgDNne4BHh6ro7NwuDdYig
2p5aY48SlBUR4Y++LgIVsyO4q0tjjwsFTSY6oylTY08SeH2kS2PfIPCQmdbYMwR1rRnZLkefszty
5lsERzCZFFfwbYJLPADY3e8S3M2ReEemL0qfod3xdGSXPfCCQHd35+ZETGM/Ek4v2lErrvknwp8k
E7t2a+xnBK1myK/+nJC/urkuZEaSbVubhIalNPZLAZJIdq6IpCMae0mgs0NKy8uEnOruVDrRaQ+8
Qsg7v75uVTrd1SyCnlRaY78VwUWnFIDfEZTlscRmjf2BoNREhZD9ieAWrWYz0i44+WeCukq2Uxp7
Q968vdHfRAxoproSccHBfxDyqzYnkmnx+poUyXJSY/8ieOq701JEGzenzOQOMfomYYwI9pIps23k
zH8Iec2mqMEMj71NUBpE7Z+9I15cY6alGUdFsNpSXzc0MEjQMl8iaJwIzrWWSnEusmMz3RLtNBPd
aY07CDkpMy1R2BGJaVwV+b2IJIdAXIRcOTIMlEPwJi3aq+LRTklTjfCQGs8ljGkTQh4bPSPCHvl0
IK6ZFxDcslcTS0TSGjdkXUdYGm5FizXC0pgaH0coNONtiXZzdXNtdaKzKxGXVPkIhe3m8eMTCa4h
eI0XEVxDYBqfIipFMTOZ1vg0y55siSY7NT6D4OxKJjq70hqfRXBsMdNtWzU+h5B3YbfZbdZH25KJ
dCS1XeMlhPxUOtndlu5Omu3VsUTc1HgpQYmkE5s1HiAom9OJiMbnETwdZrraejxqD6V3x0yNLyC4
ZXBSb7ZHIxo/naCYkqtnElhbm8bPIrjahglaRNC3RNrMlP0pjcYrCarNfo2fTVBta6bxpYQc8eYV
tU0hr5K5dzLSqfFqYYREU0bbKY0HCc6tlmjzlQTdamdma4WJSiS2R02Nn0twietosnaqJyg7ouZO
jTcSXKIVakt0mRo/j6DbiNkjIYKesbXWyGqCJwtFe3St4Hksktqq8TBBS5qpRHeyzdT4eol1hzlE
/EaCSwzYC1tF+FxbH2wIiXCHR2Sk2bCyZZXG20QRtj6kcVM0zg9pvENYy4aVdUGNRwlKS219UOPb
hb43B8/TeKewWcFQY91qGTvxBIE3B+tz0MQv1Nm1PEl45gM6uv/uyHE+hKcJUy9YXxrYuLR4Q7t/
w9wN7aV7NrSXlhSbclA0l2p8RybNttMVje8iuOWIzIU0flEmyx6qtfI9hMKWYH1TnShFB89vapXp
jMZFuDFiPNiwIgd38st1fgW/kuCUyXCKMH7EU1e1VWwUj6huLOR7dTj41SJcPTFMyRqNXyu+LFga
LbmguDsZKyneUFxSvCHlLyme619qtzaUlMzU+PWEMgFXvHhayZ5iO2Qs2VM8ff0F0zf6py8t2VO8
/oINqSXTN5aW7CleUqLxjxBWFy/esLSkeH2gNRK4qCqwbn5g0cbSkqV7ijcsXZK1ds+c9RfM2eif
Izex472KjesDVnN+YFFrxdyNfvuEjSUa/yjhDAvpxdNKhpAp3pAqLSleX2HvsDHTEhvMDWz0i1u6
SXyKdsJzL9iQmj5nY2mJyj9OqPxffMZHcIWiHfGIMHmEGSPFafHxIeqSSsKZI9OTE0CdeJ0iXrdF
MhmNm1YM0xLZLGJh3fqMSuKVIlx6ikWzd/8wsbJk/Qf7MEoIfjrSJoIiGz/NjNWJQDMlvrF497Bd
KCHhrPeGOglv3zi199jF/iUfVnZ50ut7L4CTP5wtqVxSeQrUlqyRnsh6mXwvxoo8WBX1hjXvDfhB
MCZ84sOq1X6Q409c9SbERr+ULH7/ZYglp/p09aEdV3uKt7/qwzmuZB3hqQ9lq/+iBAh+fO49341O
yMr/ZyCC0X3/VTX5QK8ghN/9/y4dp6RQKv8Cga2vJTz436tWflDZ1xa3xexfVXCHZI5QIwtlvhMh
PFfsSMhpMFPpevEFpXAhnuWJRDqVTka66s301kR7yoMx+U7+sBuT+Vd0fge/08PvzHfyATc/xL+q
8kd1/jX+dcL0YYSj8R2J7ea8ukjn5vZIvZmObMmESTmd2b3vZCuqvcg6dFUk3h4zUzPtL4ne1fCO
WChKLB9s0jry3deWHD9bHYnFQtG0WUnQa+NxMyk/PxJxujr0ux2q/dsXBN6S2K7ybxBmnRLhKn+G
MPndQUVGJ4GxAJPBQPxmGJggPjsHMEF87iR+ijdYEP8EAMY/iQniFXtE/6JR/VtG9e8Z1f/SqP47
o/rHrPPF21D2uHgSGerfggnirWPE/HwLX/F6IX+ut39utn922D/j8ud4kPilHRD/FIAiiM+rAIf/
EdBDAIh/GhDTAKaC+K38MzboLVDhANBY2g+1vqww9xDyGRoCTyK3B+7AE8jtRc6jyA2XPQJvhVJW
mOtTDmE8h/J1TArzwsn9mNqH2QXqD/pRxn3Kw5g/gDNCD0o6xKGToQKYCQdmIQ+zMRtzMB/FWIgS
NKCY9wDIBzuKSSo8KthKFblw8338NjCJ4Y3g4AAWPoqF4UdQUdeHSn8/ltaX9SPYg+mlZUo/zn0W
OfJnL7QyRz/OPYRGhrW9gy+VDqMyVlJ6ATS0woNNGIcIytEmUZgN5ag4v0lFzVoVTYNQxO9CHbBG
wOTPA5p9QbfDLT58tDDkG+BEDsAuehSrw49gbYWSaTj8/Tjf34+NPVjl78emCqdPeRTtYZ+zH1sO
IUYQrQsPoZvg78dFj+DSQ7iCYa2/H3srVJ/6LHJ9Dp9qDfYOPuLvx3X9uLHC6e/Hx/vxqQq1zKd+
FfuAQ7iD4wncWaH5tEO4h7CPnvI5K1ys3O1z9aP3C5B/BK3Oxy9dWQ8g9vjeK8SvftU9PenZaQA2
PF005kwAe448HRI/b7xs3NqbACz2uQq/2I8HerCGl7t70eRzFT4k+zWK6C/zuQoPyn65Q/Tn+1yF
X5H92U7Rn+pzFT4i+2NV0ff4XIWHZN+plbu97vsBbLTQkzc0C8B8cS6AlQCaxX8+pdSnDeBRsb1o
BgbweC9m2sPf6IXPbj7bizy7+a1e8BPw4Apxjk172qa9/e+dZ+4GcMbfO3ctBdBi077C5yr8jkUr
z9Bq8aJcydD6PYtWR4ZWixdjnRlaLV451QytZTatCoBpo/+zUf+BQN1xCD8iVLh8rkP4GaEHE0Tr
V4QnEK5w+9ylZYEB/KZ38NWHhmQ8jokAOuDCVhQiirHYhiJsxwzEcA460YQ4ViOBVlyIzUhiu/j1
B6RxDbpxM3bQBuykDuyiFHbTpbiIrsfFdAsuZStwOavDFawRV7M4rmE7cC3bjeuk7mzAhKMYq+JK
FVe+g1VsEN3IURFWSVVxp9ScK+XfA/LvnSoOEJAv/uiz3Tlu99twH8VSMSzHpr8N9xFoKl48jKm2
xn0WbuFzbZtwPzg0AOc9itfCj+D3df4B/KHwjX787Qm8UV/2LBb14c2GwGPlCi93eB1eZT/mBLyO
0yqcZULh3rZUK6/U5xS6dZRj7V4H9Q6+mGUsZsMlzaOGT8GLT8OHW7EAn8Ei9GAJ9qEWt6IRd0gG
TAQfxEw4M+S9ofK7iICZb8Fh4/85uMU3Tjb+IShwitsuLTtExPAEKRUOn+NZFHqVonug+4u8is/R
T87hiy2U4rIfOu7GONyDqfi8PFsDHcFUlRT7oP1wi88FbfO+SnhCYX/9Bun9eGAfxvkNypOtXL9B
nn4q7IGq9ELhXxw6y3IUX5D7O8En82UEt/h20951hb3rVP/DNNYgn9zOY3UmSmE/8Y5PZ3acYO24
YAjPJfaOE/wGFQ1hN+Vd9vpmZq8x1l7LqMpm7j4wydwWXq5MFNfvP0TTCPuxwu91HKKZDE+g/WEa
WyZ3d+1VqBczRk4F5FTeXmXQq+yD0+v4opSPR9gwFtOlAH4XHN9DAb6P2fgByvACavFD1OF7aMZP
JIa6cCxOollTDg8Jw91wi28kbXz/aAvzTRPLFa8yaT+u83uVDDIDNKcHF3oVZVOGirF+0ctCthdO
g0orHF7lDmuy/fhJp89hkKCqXPWq+zDV5xygefswPpB11MN0muU1BUcGdz00ShV+ARd+iQn4FZbi
JWzAr7EFLyOF3+A6/AIfw2u2KqhHwKl8uYoDR+BTcUC0DiMwTP09cIsPOS3q6XQoUrJ/NFHZdPak
DJGT/JOy0DLoDMuE7mVkg3wODv7FbKCxBpVLIIeSNS7ZVzJpmHtF/kkjmGfQwuNXyfEKOX62f5JB
FQYtHqAlS4ruQGnR8F5T/EUn3MsW2CyRLUeuvGgFf8JMvI45+AsW4A2cjr+hFn/HufgnLsO/cAXe
xK34H9yN/+AFvC05Wig4Oodyxp15BPW0jA4DNiPvhVv8Ro3FyJyXoMILqHE7+GjwW95DEQGb9B6z
RUt6j3ZhbR6msQO0fB/0gHA0VoDx04CkrVyxg60KR6bhzDTUTEPj5S6vy6vs508FvK4sPgjXZFBQ
qrFPNFfKZp5o1goO0ZcyzfIcr0vZVK57da+ynz4Z8OqZfSpyM+fk+XLlNfp8eb7cISH16sqm8vxe
RMTYWIPOlWcU2L16eUx11lwPXAY1SnU4r8IT8OpyzucZoCXlBd6C2+HsJSMgdvUW+PIGKOQtEAd4
823nkT/iotfKHT0Bb/4AhTM3Xu7x5R2ijYSKAl+BzfP5oiV5fqCi0OvpgeZTe5HvzREtZy8cPoev
MBOsfoeXF3jzbW4gksUNwdVCX6FBF/TTJmG0CqgXFWKgTQ4UeAv2wdmLwN6CwV5ME71JYta0bL5o
dlgq1AvXXp16B++wDpk68hBrRY8FcyzWS6+Im7IU6zZ5VTneHLGuKODNGaGhUVtDc8gCCGQByOub
5FNHrrGNTWbBohGzQwo4PeDNGdJAwZo7kB/w5iibvLrPMUChXloiULQ0r8frugO3BLyuYRtYkePL
kecbPocvZ+jYXmwTvbEGLZYrN/ByXSwrz/Xm3oaGgDc3m/V5vrwMoOQM5ogBC8FJe/VBr74PYwLe
XGWT2MPCC669uYO9gwd78VmB4HYJHPK6HJsEtecIJDedgN4FAQEygnOTfY4Rg1lELBdbd8qFZ4kN
xdZzR2wtd5jo00adl+G+i3qPnM3LXVwEp0KXFwS87mzeSdQSFulKuauXuyU/92GMnBNuhP2Hl7t6
2T+8bguBsQHROt4J6T7dorI816cP0LzyPK/7DiFJ7hEua4DmDWlUvoBYNBrCksh9mHT8RGeWBS73
eF09uKC0TN67zyGiPZ82QBf2oNynWcJA3Qz7MKePdmX3x/XRnuy+SpKEy8TYFb6cfrp6gK7rpUFv
/j6ypKqiQCi3s5f+7FN9BXJZD8aXlhl046hFz/s0G2AfPOLcEdCjj7jd5xgCcPbSR33OkfAfGwUf
E5iPgLh5FMQ5ffSJkRCfGgVR3Ee3joTYNwrCKXjqzfXmDdDtvXjL6xYm1NF+G84NeAuOv8wzA2I2
SyLl1WUNyau7y9avgmO9gw8HvAVDUljoKxwC2IfJvkIp0xPE6Mhbta/d8Br7UDACxdXe3B409dF+
ucgmbaq3wOt2tN8lrvsTw9c9tM+Y0jLvGOk3PiWvf+RN7nVT75HvDUVJbCyuBnAUGo5hNgaxgIAK
YjibOILkQAM5sZZUbCINUXIhRW5cRTm4h3Q8QLl4mPLxKHnwTSrAC2Tg5zQGvycv/kZjKYfG0Uwa
T6eTjxbSBKqkSbSSiqieptHFNJ320QwaoJn0KM2mx2gOPUXF9C0qoZ+Tn16jUnqdyuhNCtBhmktH
aT7jtIBNptPYNDqDzaQz2RwqZ0E6i62ihexcWszCdDZrpSXsElrKLqcq9hlazh6gavYQBdn3qYa9
RCvZq7SK/ZXO5UR13EP1fDw18GJq5OXUxBfReXwFNfMWCvFWauEmrea7aA2/htby6+k8fhOt50/T
Bv5D2sjfoAuUMdSqlJFLOY22KGdSh7KUtip1FFXW0TZlI21XNlGnspXiSooSym5KKfsordxD3coX
aIfyXdrpyKHdDg9d5Cikix1T6CLHYrrYYdJFjq20x7GdLnV00WWOnXS5Yw9d4biMrnR8hK5y3EV7
HYfoasf36BrHS3Sd4090veMY3eDMoY84p9KNzgB91LmcPuZspJuc7fRxZ4I+6UzSp5076Fbn4/QZ
5zO0z/lDus35Kt2uMvqsqtIdqpfuVCfQXeo59Dm1gzrUTrpXxHCsCnWyunSlihdLDoMNYi7comtn
yFeSzJLtvwQcwVkqDhxFPtFRVKhoV9E00RCh9DGMh8iUB1Fg7XjiLQQIWesI8C+jo3CTihePYIqK
A64qFU0yy3bSEcxRcaDQUXQYjkHMEJn7u2wKsCNYQPMPYzE7gnIV7UcxlugIZskwf8ZbcLB3sO4w
lhyG4ygcZO3fPn6ihfwCidgyOoKFxJfRIBrEP8RzsgMtCg4QEYFZMINgp7qCZ2AO5B+BoeLA1PFj
8qZOmzbtMHJFkvIOVjmO4EwV7VwgNIYWCITy4D2l7UVzJFrva90wcoPQ343pBAznTp+HW/yGmJ05
doPJgtnKUr/tUCrKMq35gUxrtk/JNCf20Z5MO7+PdvlHGLzhfCVPVFzpAAJ0H2rogF1o4O+gii/L
FKl74Ra/oWSj0gqHRCVQ1IOx/lKDbix7mK4osx0GxnuVHhhi/N6s8YdGlmbpASj0ZYyjBzGJHkIZ
HZQHK2DjxtiHHoBb/F6/dSh7AQ7kAfTyUOHVznkcIqOR8fdC0bJzHqfPKf2IVQiZaPfsYohP8Tkz
WdDTsmrkU6w8j670KcPVgaFdrKqHs5c2eh3KpgwwxgngE0U/qk81qFdEP5po3SdaLq/jDlHy8zpG
hTH3ZYcxbq97H1YGxLmnDYUC+H0ffSF7yHb2TuGinBm+P1la5nN6Na9LesGDXoeI34WjPtuneHNO
eOgMMTPKNfts15xzrHfwKTE/xA3dp2dBzAqIbiZqMgSG+nFuNdeba7nnYcQmeLUeeK1oKZsAUXU5
llWJuBRTAHoMLnocc+gJVNOTqKdvoImeRis9g056FhfTc7iUvoV76Xl8mb6NQ/QdvEzfxWv0PbxJ
PyAHvUAT6Ec0i35CxfQzKqMXqYN+Tp30S7qYfkU30Uv0AP2aDtLL9CT9hp6lV+hFepp+Ta/Z1c4x
Ry0LhBcrDwtzyOgI/Crap1kmbuGQiRtHM21Ds+wIFg3bmUGMFcXCK7MLpCPU/D64xW84naCI98BQ
Ee/BUyni0V9HFfH+MrTrdfaua/wG9fVT4T7U+g16WO661G9Qv0wsF/kNGpBj8/wGfVW2ZvkN+pql
Q36DHrMSb79BT8jWaDxk4ZL+iTL6F86hf2M1/XPYnjRJrMQ/l2GptPoSHBgDOC61iixLir7mrlDE
/xy83MnL1YymW8WHov1U5D9B7eEpSxpFNjjVn50NSll9Olu5cgR8r8TcEM1nZVMTCbprr5N6US1G
vzlczHh+uJhhPQxM9zrvQNFe56DP4XV51UaflOrv2cYEO0407HXuw8YMpvbGPx698WLxkiPMme7T
bXM2SbSEOaPv99NPy3N9ijfX62rsHfyNTztEPyfIHF0Vad2x32aWD78fTMy8H1jL3T7F6y5q7B18
hZc7M5xVebnm1Yr286N+rzak5y6f6zjuapK72v+Ku3e/F3fzBHdde52DvXzL8OHVvFz3ObzaXGFN
vNp+TPfq/hE5u0G/6qdfX16u782l3sGXfKpXH6BX7EvhE4cPmOZTD9HvCfu4SCRUKXaCpD8IQPZP
n+LV5hbtxzS/bI044alsUnVenmuhlOfNk7D7UezVe0RtOW9ERvS6TKVzRYUgj3oHfyyAdGEU7Z3y
vHk98GfQwtQRaIl96NV+eiMrR9Zk4Vc7UeHXI4ZFdnYbivzDOZXE4+8y2xrsHXxNTI8ZOW2vL/Tm
92Cu4Na/hm/mTUm3dDj/EXJxhc+VyQyf6qO3fW7b4Ff30RExf1o/llYYPkM82NJdPqOfBq1hhv10
c2mZwbi1jZjZNLxZd+bcHtR4NWVT0X4sEXSOrJv0WuLYx0QlTXoeWiz21EahNsebJ/31FCFRNw9v
PUNUx54dIom5R67D34ZBX/MVGswKH0TxjVmxwzzR9MjmTNEstMW50GBjbKYVGmys3GG/OGH8qBM+
OnyC6fNYjngf1vk8Bpsgm42iOUk2V4jmZNlcJJpTZXOuWPa0bM4Qo9NlU5Izc9RhU31ug82WhwmP
y4pHzO/VqPcIH/K4tAVhgN6CSoeh0zsooKMYQ8cwjgYxlQEljLCIMUQZx16m4AbmwIPMiYNMxVeZ
hueYC8+zHLzAdPya5ZLC8mg2y6cA89B8VkBnsUI6m4GqmZdMNpa2s3EUZz66kE2gi9hEuopNoptZ
Ed3KJtNzbAq9yqbSH9k0lsemswI2g41hM9kUNotNZ7PZfDaH1bLZrJGVsA3Mz1pZKdvGyliaBdh1
7DTWx05nX2FnsG+zM9nLrJy9ys5iv2NnsD+zCnaEVfJSdjZfxZbwBraUd7BlvJMt59exIL+b1fCv
sJV8gJ3Dn2Hn8h+yOv46q1ccrFlZwELKEtaihFhYOZ+tU9azDcomdoGyg7UqH2GblK+xiPIi26y8
wbY4DNbhOINtdQRZ1LGObXOYbLtjJ5vouITFpUd8BaeLBGw4MSSV36/y+0XKcKVMCkWAIUKISeSY
OnlR5o10+tvQD8NhdQcxLSu2sHcAjiFP7nIUNVYqktnGLe6TDmPWYeQXz15Gx5BDRMWH4cgVIAEZ
yPhouUxHVRHaTPZajzuTVBwY8w7q3kG9Ou8d1I15B7FBTBL/Juwo/EeHN5+HW/xzVnYU/w+o4vMJ
+tnJHi7o8eyHiz7ml28X1sMpDoiA/Fn4S8v62Fzr9cLZdZqAuEK8oAqZDgxF9pTsYwvs1dJCbQvY
RrYuEBhhYnFAgkk1mZ81J7zCuxzVSx6hU2eMHMQ7cjODlduPFFbPqlm/3McqxIA0kqpP7Wdn9+D5
7BMqNMucyT1VpZ8t2zTcrt40QNeVlvky046saYc97VPVfpwrfHg/g+NzKPK5eD8LeqbfiTy7Oeeu
oWyjtMzrFlUvNl74AFZrb6Zmbawef67HmTUvOhKg99jZw9H7FvgAthcauxqz2TVYyK7F2ew6nM+u
Rzu7AWn2EfSwG3GAfRTPspvwS/Zx/Id9khR2C+nsUzSBfZoq2K0UZp+hCOuha9k+upPdRl9m+6iP
3U4/YnfST9ldUpduhz5UcTmKkCXz7yAyZuIxXKcKJRAfI3Ar4R+Rfat40YIeghqR5L8nbHZiXwnH
KHChBixLDb6ZUQO6AU75zvqmJf4NATtm+0NgSPYVnyIFx3rPyvUppWUDrL538Gf2+HlifPBbonea
wg0W4h5XP1stvN7gwT4WlhNCzEQw7XPI76euFoNCVNmGTeVqpkODm8o1n0N8UfUcdJ9Dk59YFUqP
71W9mpTqlT6HQ45PEOGsdCYX2JNKuVM8kjicQ+vY+KF1+dLLZrqDu3sHxw4LyRrxiMl6MZEdQAm7
D/PZ/TidfREt7EtYy76MdvYgOthDSLA+XM8O4jb2MO5nX8EA68fT7BE8zwbwI3YIr7JH8Vf2dfyD
PYZ/s8elUMxBzhFhw148glIV7TOOIl9FDR3F6UR5U8a9jZy3wEbcj/i1fft+Jtpfyj3Sxzb5LT42
BCQLe/0P0xXlSsD6Dm2JxSTRZcs2WT+lLgQsZu2w+KQEHPZ8Rkt7sT6gSpBJFr+UgLgU8YMGLYCK
gDYM4D4BgC9z+KiJwfOHOVwhaibsOeSwb6KQfQvj2fOYyr6Nhew7WMa+i/Xs+2hjP8Ae9gL2sh/i
s+zHOMh+in72M/tB2nlEqEHNETTS1KmH4c0w7Itwi3/Y0GbYX6GKb/9o8kiBJs/xAt02UqDxerZA
41d9zBwWXSm3UqQfsgJQS2QtszjUts2TwbbaY46s+SG76LD4PUMAbrMn1SzAjJ3rY7EhBJw+p1QQ
a4ChnyXWio+Kgj04XRQ1LCnImM8Mfk5xIZlm5lK+3XvsjeF7aYABsJcwkf0aJexlnM5+gyr2ChrY
q1jDfosw+x12s9+jh/0B+9kf8RR7Hd9nf8ar7C94nb1BDvZXGsPeoAnsH1TErCR7G1zZEi/LtDXv
YKssA9cMilpyloGyjFmN9cHjkMU7CcSwnXsLE7OVRuNfynyJ6qiCW37p9ozBUgOs+yAqPWO/jgNh
btCNobBi0L2hsMOgy0Jhp0H7QmHVoJtDYc2gj4XCHqdBnwqFParBeCjs0QymhcIel8FmhsIet8GK
Q2FPjsF2h8Ie3WAXh8KeXINdEgp78gx2RijsyTeYOxT2eAw2PhT2FBj0n1DYU2iw2lDYYxjsglDY
M8ZgW0Nhj9dg20IH8abBLjPYFQa7aoBdfZBu9RRaqLLrBarsIwJV9lGBKrtJoMo+LlBln5SoMhvV
Wy1UeyxUb7NQ/ayF6p0Wqp+zUL3bQvVeC9VeC9X7JKrsC6EB9qWDtMfjt1F4UKLQJ1F4WKLQL1EY
kCh81ULhaxYKj1koPGGh8JSFwtMWCs9aKHzTQuF5C4XvWCh8z0LhBxYKP7S49WOLWz+1uLXQ4taL
obBnrMF+EQp7xhnsV6GwZ7zBfh0Ke3wG+00o7JlgsFdDYc9Eg70WCnsmGez3obCnyGB/DIU9kw32
eijsmWKwv4TCnqkG+2so7JlmsL+Hwp7pBvtnKOyZYbB/h8KemQb7n1DYM8tgb4XCntkGOxwKe+YY
7Ego7Ck22LFQ2FNicFis2uXxWaziTLCKK4JV3ClYxTXBKu4WrOK6ZBXPk6ziHskqXihZxcdIVvGx
klV8vGQVnyBZxSdJVvHJklV8qmQVny5ZxWdKVvHZklW8WLKK+yWreJlkFZ8rWcXnS1bx0yycP2Gw
6w3WY7DbpMDt93htEs6QJJRLEhZKEiokCYslCUssEpZZJCy3SFhhkVBjkbDKIuEci4Q6i4QGi4Qm
i4Rmi4QWi4Q1FgnnWySss0jYYKH5BYNfYPBNBt9s8HaDbzH4VoNvM3jM4HGD3hzgXQfpbYNLBacj
Bu82+E6D7xY0MYf9heZB5u9jfoN6Dfqm9cWl7D5l0Heyus8a9HxWV3z1kdWtN+i8rO65BjUOd/nF
Br/E6ooPh/qY/xC/jPAIv+ogW+C0tWi31KKLpRZdEjrI5hr8GoE1qzD4dbIRNvgNsrHJ4DfKhmnw
j8lGbPhL+m2YACAMF27AvXgAD+MhOgtfYZvxNT4WT/JZNMC/Tn/kr9Dr/HX6M3+bJRXOupVCtkOZ
xnYq89luZSm7SGlgFysb2R4lxi5VLmWXKbeyy5W72D3KfewbSh/7ufIo+wUU/oA0rF/mD8pKLkMu
2mWGroP4I+C8jx/k/fwx+VGiAo3fzB+HD7mYzJ/ABLRjMn8SE/hT/Gn+LHz/B1BLBwjMcGhaTzAA
AO9jAABQSwMEFAAICAgAFn9pXQAAAAAAAAAAAAAAACEAAABjb20vb25lZGFya21peC9uZXRiZWFu
cy9sYXllci54bWzNlT1vAjEMhvf7FWn2XApTVR0g8aVWaikDDJ1QejF3aXPJKbYg/PsK0eooDB3J
aL+v4keWHRej2Fi2g4DGuwHv5fecgSu9Nq4a8PVqLh74aJgVd9O3yep9OWNbYwEPSNCw5Xr88jxh
XEi5ABqDcijldDVl887Ty/tSzhac8ZqofZRyv9/nDujj6M59qKQmjbJ7VfQ2/VyT5sOs6LLDjDHG
iq23GgJzqoEBn2lDPiA/adc6QaQz8doQG3uhnzzGwo+j9I3wDrQKX42J4pdbvJr4ZKramqomnKuS
fDjkxiEpVwKXF0Xlqeo/KAIiQXDKilYFBC3AkaFDMoTiU+1UQjToXSo0x85gGUx7OW83IyoRU0GJ
ApJZs5oSWvmUYDChgbGQDsvxn2nTgSFV3Qbmb6aLCnl+o78BUEsHCFQXP9I2AQAATQgAAFBLAQIK
AAoAAAgAABZ/aV0AAAAAAAAAAAAAAAAJAAQAAAAAAAAAAAAAAAAAAABNRVRBLUlORi/+ygAAUEsB
AhQAFAAICAgAFn9pXVk9f2VSAQAAswIAABQAAAAAAAAAAAAAAAAAKwAAAE1FVEEtSU5GL01BTklG
RVNULk1GUEsBAgoACgAACAAAFn9pXQAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAvwEAAGNvbS9Q
SwECCgAKAAAIAAAWf2ldAAAAAAAAAAAAAAAADwAAAAAAAAAAAAAAAADhAQAAY29tL29uZWRhcmtt
aXgvUEsBAgoACgAACAAAFn9pXQAAAAAAAAAAAAAAABgAAAAAAAAAAAAAAAAADgIAAGNvbS9vbmVk
YXJrbWl4L25ldGJlYW5zL1BLAQIUABQACAgIABZ/aV23lT64jwUAAGIMAAA6AAAAAAAAAAAAAAAA
AEQCAABjb20vb25lZGFya21peC9uZXRiZWFucy9NaXhIaWdobGlnaHRzRmFjdG9yeSRQYWludGVy
LmNsYXNzUEsBAhQAFAAICAgAFn9pXYNauZ9/AQAAYQIAADYAAAAAAAAAAAAAAAAAOwgAAGNvbS9v
bmVkYXJrbWl4L25ldGJlYW5zL01peEhpZ2hsaWdodHNGYWN0b3J5JFRvay5jbGFzc1BLAQIUABQA
CAgIABZ/aV3McGhaTzAAAO9jAAAyAAAAAAAAAAAAAAAAAB4KAABjb20vb25lZGFya21peC9uZXRi
ZWFucy9NaXhIaWdobGlnaHRzRmFjdG9yeS5jbGFzc1BLAQIUABQACAgIABZ/aV1UFz/SNgEAAE0I
AAAhAAAAAAAAAAAAAAAAAM06AABjb20vb25lZGFya21peC9uZXRiZWFucy9sYXllci54bWxQSwUG
AAAAAAkACQCtAgAAUjwAAAAA
B64
  echo "0c6fc024f31af75e4b28a04a7f18a73372510b54c4cec97e05a6bb2c12a191ac  $MODJAR" | sha256sum -c --quiet - || die "o módulo do tema foi corrompido ao copiar o nbkit."
  cat > "$MODXML" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE module PUBLIC "-//NetBeans//DTD Module Status 1.0//EN" "http://www.netbeans.org/dtds/module-status-1_0.dtd">
<module name="com.onedarkmix.netbeans">
    <param name="autoload">false</param>
    <param name="eager">false</param>
    <param name="enabled">true</param>
    <param name="jar">modules/com-onedarkmix-netbeans.jar</param>
    <param name="reloadable">false</param>
</module>
EOF
  # faz o NetBeans reler a lista de modulos na proxima abertura
  touch "$UD/.lastModified"

  ok "módulo copiado e verificado (sha256)"
  step "Aplicando a interface e preservando suas personalizações"
  # ---------- Mescla com suas personalizacoes ----------
  # Mantem: fonte do editor, entradas que o tema nao define, ajustes seus em entradas do tema
  # e chaves suas no FlatDarkLaf.properties.
  {
  python3 - "$UD" "$OLD" "$LAFT" <<'PY'
import sys, os, json, re
import xml.dom.minidom as M

UD, OLD = sys.argv[1], sys.argv[2]
MAN = os.path.join(UD, 'onedark-manifest.json')
try:
    man = json.load(open(MAN))
except Exception:
    man = None
LAF = 'config/LookAndFeel/FlatDarkLaf.properties'
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

# FlatDarkLaf.properties
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
    old_is_theme = bool(olines) and olines[0].startswith('# One Dark Pro Mix')
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

  ok "FlatDarkLaf.properties gravado"
  step "Selecionando visual, perfil e cor de seleção do terminal"
  # ---------- Selecao do terminal ----------
  mkdir -p "$(dirname "$TERMPREF")"
  touch "$TERMPREF"
  CURSEL="$(sed -n 's/^term\.selectionBackground=//p' "$TERMPREF" | tail -1)"
  if [ -z "$CURSEL" ]; then
    echo "term.selectionBackground=$TERMSEL" >> "$TERMPREF"
  elif [ "$CURSEL" != "$TERMSEL" ]; then
    echo "seleção do terminal: mantida a cor que você escolheu (Tools > Options > Terminal)"
  fi

  # ---------- Seleciona o visual FlatLaf Dark e o perfil novo ----------
  odpm_select_state select "$LAFCLASS" "$PROFILE"


  rm -f "$UD/onedark-version"
  ok "FlatLaf Dark + \"$PROFILE\" + terminal"
}

# ---------- desinstalar ----------
odpm_desinstalar() {
  odpm_vars
  step "Removendo perfil, interface e módulo"
  FONT="$(odpm_current_font "$UD/config/Editors/FontsColors/$PROFILE/org-netbeans-modules-editor-settings-CustomFontsColors-tokenColorings.xml")"
  rm -f "$UD/config/LookAndFeel/FlatDarkLaf.properties"
  find "$C/Editors" -depth -type d -path "*/FontsColors/$PROFILE" -exec rm -rf {} + 2>/dev/null || true
  FIRST="${ODPM_RESTORE:-$(ls -1 "$UD"/onedark-backup-*.tar.gz 2>/dev/null | sort | head -1 || true)}"
  # tema de versao antiga (ate a v17) ainda dentro do FlatLaf Dark: devolve o original
  if [ -e "$C/Editors/FontsColors/FlatLafDark/Defaults/onedark-mix-tokenColorings.xml" ]; then
    for t in "${TARGETS[@]}"; do case "$t" in config/Editors/*) rm -rf "${UD:?}/$t" ;; esac; done
    [ -n "$FIRST" ] && tar -xzf "$FIRST" -C "$UD" --wildcards 'config/Editors/*' 2>/dev/null || true
  fi
  ok "perfil \"$PROFILE\", FlatDarkLaf.properties e módulo removidos"
  step "Voltando o visual e o perfil que estavam antes"
  odpm_select_state restore "" ""
  ok "seleção anterior restaurada"
  step "Fonte"
  JBM="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/JetBrainsMono"
  if [ -e "$JBM/.onedark-installed" ]; then
    rm -rf "$JBM"; command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1 || true
    ok "JetBrains Mono removida (tinha sido instalada pelo nbkit)"
  else
    info "JetBrains Mono mantida (não foi o nbkit que instalou)"
  fi
  rm -f "$UD/onedark-manifest.json" "$UD/onedark-version" "$MODJAR" "$MODXML"
  [ -f "$TERMPREF" ] && sed -i "/^term\.selectionBackground=$TERMSEL\$/d" "$TERMPREF"
  touch "$UD/.lastModified"
  # restaurando um backup escolhido: o passo seguinte ja volta tudo dele
  if [ -z "${ODPM_RESTORE:-}" ] && [ -n "$FIRST" ] && tar -tzf "$FIRST" config/LookAndFeel/FlatDarkLaf.properties >/dev/null 2>&1; then
    tar -xzf "$FIRST" -C "$UD" config/LookAndFeel/FlatDarkLaf.properties; info "FlatDarkLaf.properties original restaurado"
  fi
  ok "pronto"
}

# ---------- restaurar um backup ----------
odpm_restaurar() {
  odpm_vars
  if [ "$(odpm_status)" != nao ]; then
    ODPM_RESTORE="$1"
    odpm_desinstalar
    ODPM_RESTORE=""
  else
    step "Backup do que você tem hoje"
    odpm_backup
  fi
  step "Restaurando o backup de $(bk_date "$1")"
  odpm_restore_backup "$1"
}

# ---------- conferir (com o NetBeans aberto) ----------
odpm_conferir() {
  odpm_vars
  local rc=0 stage; stage="$(tmpdir)"
  odpm_builder "$UD" "$stage" "$PROFILE" "" check >/dev/null 2>&1 || true
  python3 - "$UD" <<'PY' || rc=$?
import sys, os, re, xml.dom.minidom as M
ud = sys.argv[1]
ok = True
def res(good, msg):
    global ok
    ok = ok and good
    print(('  ok       ' if good else '  PROBLEMA ') + msg)
log = os.path.join(ud, 'var', 'log', 'messages.log')
jar = os.path.join(ud, 'modules', 'com-onedarkmix-netbeans.jar')
text = open(log, errors='replace').read()
lines = text.splitlines()
loaded = any(re.match(r'^\s+com\.onedarkmix\.netbeans \[', l) for l in lines)
bad = [l.strip() for l in lines if ('onedarkmix' in l or 'One Dark Pro Mix Highlights' in l)
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
res(prof == 'One Dark Pro Mix' and os.path.isdir(os.path.join(ud, 'config', 'Editors', 'FontsColors', 'One Dark Pro Mix')),
    f'perfil do editor: {prof or "(padrão do NetBeans)"}')
laf = None
lp = os.path.join(ud, 'config', 'Preferences', 'laf.properties')
if os.path.exists(lp):
    for l in open(lp).read().splitlines():
        if l.startswith('laf='):
            laf = l[4:]
res(laf == 'com.formdev.flatlaf.FlatDarkLaf', f'visual: {laf or "(padrão do NetBeans)"}')
fixable = not any(re.search(r'requires|Java', b) for b in bad)
sys.exit(0 if ok else (1 if fixable else 2))
PY
  return $rc
}
