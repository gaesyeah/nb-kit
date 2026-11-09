# nbkit theme engine: everything any theme needs, without a single color.
# A theme (e.g. one-dark-pro-mix.sh) sources this file, calls theme_register and defines:
#   <prefix>_config     THEME_* variables (profile, base, look and feel, font, terminal)
#   <prefix>_ui         content of the FlatLaf properties file (UI colors)
#   <prefix>_colors     editor colors: colors_tokens, colors_highlights, colors_annotations,
#                       colors_language <mime> and colors_extras <mime> (categories of the coloring module)
# Optional: <prefix>_legacy_version (version installed by an old installer, to offer the update).
# See the "Creating a theme" section of the README.

[ -n "${NBKIT_THEME_ENGINE:-}" ] && return 0
NBKIT_THEME_ENGINE=1

# ---------- registration ----------
# theme_register <id> <prefix> "<name>" "<description>" <version>
# creates the nbkit contract functions (<prefix>_install etc.) pointing to the engine
theme_register() {
  local id="$1" p="$2" f
  nbkit_register "$id" "$p" theme "$3" "$4" "$5"
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
  THEME_ID="$1"; THEME_P="$2"
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

# old names (v28 and the One Dark Pro Mix installer, before nbkit) move to the new ones
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
# coloring module of this version and of older ones (nbkit v28: nbkit.cores; old installer: com.onedarkmix.netbeans)
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
  python3 - "$UD" "$1" "$2" "$3" <<'PY'
import sys, os, json, re, xml.dom.minidom as M
ud, mode, laf, profile = sys.argv[1:5]
attrs = os.path.join(ud, 'config', '.nbattrs')
lafp = os.path.join(ud, 'config', 'Preferences', 'laf.properties')
state = os.environ['NBKIT_THEME_STATE']
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
    st = json.load(open(state)) if os.path.exists(state) else {'laf': None, 'profile': os.environ.get('NBKIT_THEME_BASE_PROFILE', 'FlatLaf Dark')}
    set_laf(st.get('laf'))
    set_profile(st.get('profile'))
    if os.path.exists(state):
        os.remove(state)
PY
}

# editor font configured today (to tell on uninstall)
theme_current_font() {
  python3 - "$1" <<'PY' 2>/dev/null || true
import sys, xml.dom.minidom as M
for e in M.parse(sys.argv[1]).getElementsByTagName('fontcolor'):
    f = e.getElementsByTagName('font')
    if e.getAttribute('name') == 'default' and f and f[0].getAttribute('name'):
        print(f[0].getAttribute('name'), f[0].getAttribute('size'))
PY
}

# builds the profile (check mode: only validates the NetBeans installation)
theme_builder() {
  python3 - "$@" <<'PY'
import sys, os, re, json, glob, zipfile
import xml.dom.minidom as M


_TEXTS = None
def T(key, *args):
    """Text of the key in lang/<language>.lang (nbkit passes the files in NBKIT_LANG_FILES, one per line)."""
    global _TEXTS
    if _TEXTS is None:
        _TEXTS = {}
        for path in os.environ.get('NBKIT_LANG_FILES', '').split('\n'):
            if path and os.path.exists(path):
                for line in open(path, encoding='utf-8'):
                    line = line.rstrip('\n')
                    if line and not line.startswith('#') and '=' in line:
                        k, v = line.split('=', 1)
                        _TEXTS[k] = v
    text = _TEXTS.get(key, key).replace('\\n', '\n')
    return text % args if args else text.replace('%%', '%')

UD, STAGE, PROFILE, FONTJSON = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
BASE = os.environ.get('NBKIT_THEME_BASE', 'FlatLafDark')            # folder of the NetBeans profile that is copied
BASE_NAME = os.environ.get('NBKIT_THEME_BASE_NAME', 'FlatLaf Dark')  # its name in the messages
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
    print(T('cli.error') + ' ' + msg, file=sys.stderr)
    sys.exit(2)

# ---------- 1. Where NetBeans is installed (clusters) ----------
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
            if d.startswith('/app/netbeans/'):   # Flatpak: path inside the sandbox
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
    die(T('theme.no_netbeans'))

# ---------- 2. Files of the base profile from all modules ----------
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

base = []   # (mime, file name, type, content)
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
    die(T('theme.no_base_colors', BASE_NAME))
if len(sys.argv) > 5 and sys.argv[5] == 'check':
    # ---- check: do the tokens the module uses still exist in the lexers of this version? ----
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
            continue                                   # language not installed: nothing to color
        missing = [n for n in names.split() if struct.pack('>H', len(n)) + n.encode() not in data]
        if missing:
            problems.append(f'  {lang}: {", ".join(missing)}')
    if problems:
        print(T('theme.tokens_missing'))
        print('\n'.join(problems))
    # ---- check: Java version NetBeans runs with ----
    log = os.path.join(UD, 'var', 'log', 'messages.log')
    if os.path.exists(log):
        m = re.search(r'Java; VM; Vendor\s*=\s*(\d+)', open(log, errors='replace').read())
        if m and int(m.group(1)) < 17:
            print(T('theme.old_java', m.group(1)))
    sys.exit(0)

# ---------- 3. Theme colors (prepared in STAGE in the old format) ----------
def ftype(dirpath, fn):
    attrs = os.path.join(dirpath, '.nbattrs')
    if os.path.exists(attrs):
        for fo in M.parse(attrs).getElementsByTagName('fileobject'):
            if fo.getAttribute('name') == fn:
                for a in fo.getElementsByTagName('attr'):
                    if a.getAttribute('name') == TYPE_ATTR:
                        return a.getAttribute('stringvalue')
    return 'highlight' if fn.endswith('-highlights.xml') else 'annotation' if fn.endswith('-annotations.xml') else 'token'

over = {}   # (mime, type) -> {name: element}
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

THEMEFONT = os.environ.get('NBKIT_THEME_FONT', '')
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
    """Theme entry in place of the base profile one, inheriting 'default' and the font when the theme does not define them."""
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

# ---------- 4. New profile: copy of the base profile + theme colors ----------
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
    while os.path.exists(os.path.join(folder, target)):     # two modules with the same file name
        target = 'x-' + target
    write_xml(os.path.join(folder, target), out)
    types_by_dir.setdefault(folder, {})[target] = typ
for (mime, typ), d in over.items():
    rest = [merged(None, e.cloneNode(True)) for nm, e in d.items() if (mime, typ, nm) not in used]
    if rest:
        folder = profile_dir(mime)
        target = f'nbkit-theme-{typ}.xml'
        write_xml(os.path.join(folder, target), rest)
        types_by_dir.setdefault(folder, {})[target] = typ
for folder, types in types_by_dir.items():
    write_types(folder, types)
if len(sys.argv) <= 5:
    langs = len({m for m, *_ in base})
    print('\u2713 ' + T('theme.profile_copied', len(base), BASE_NAME, langs, len(used)))

# ---------- 5. Font ----------
font = json.loads(FONTJSON) if FONTJSON else None      # font you used in the base profile

def ask(question):
    try:
        with open('/dev/tty') as tty, open('/dev/tty', 'w') as out:
            out.write('      ' + question + ' ' + T('cli.yn_no') + ' '); out.flush()
            return tty.readline().strip().lower() in ('s', 'sim', 'y', 'yes')
    except OSError:
        print(question + ' ' + T('theme.no_tty_font'))
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
    """Writes the font in the default entry of the user file (with the base colors when it does not exist yet)."""
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
cur = font_of(pdef)                       # font chosen in the profile itself
mine = cur or font                        # otherwise, the one you used in the base profile

if not THEMEFONT:
    if mine and not cur:
        put_font(pfile, theme_default, mine)
        print(T('theme.font_carried', ' '.join(mine.values())))
elif mine and mine.get('name') != THEMEFONT:
    desc = mine['name'] + (' ' + mine['size'] if mine.get('size') else '')
    if ask(T('theme.ask_keep_font', desc, THEMEFONT)):
        if not cur:
            put_font(pfile, theme_default, mine)
        print(T('theme.font_kept', desc))
    else:
        if cur:
            put_font(pfile, theme_default, dict(cur, name=THEMEFONT))
        elif mine.get('size') and mine['size'] != THEMESIZE:
            put_font(pfile, theme_default, {'name': THEMEFONT, 'size': mine['size']})
        print(T('theme.font_applied', THEMEFONT))
elif mine and not cur and mine.get('size') and mine['size'] != THEMESIZE:
    put_font(pfile, theme_default, {'name': THEMEFONT, 'size': mine['size']})   # same font, your size

# base profile: if the font came from it (old versions), it stays there
if font:
    entries, d = read_user(os.path.join(EDITORS, 'FontsColors', BASE, USERFILE))
    if font_of(d) is None:
        put_font(os.path.join(EDITORS, 'FontsColors', BASE, USERFILE), flatlaf_default, font)
PY
}

# ---------- colors API (used in <prefix>_colors) ----------
COLORS_HDR='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fontscolors PUBLIC "-//NetBeans//DTD Editor Fonts and Colors settings 1.2//EN" "https://netbeans.apache.org/dtds/EditorFontsColors-1_2.dtd">'
COLORS_PREFIX="org-netbeans-modules-editor-settings-CustomFontsColors"

colors_file() { { echo "$COLORS_HDR"; echo "<fontscolors>"; cat; echo "</fontscolors>"; } > "$1"; }
# general editor colors (valid for all languages)
colors_tokens() { mkdir -p "$FC"; colors_file "$FC/$COLORS_PREFIX-tokenColorings.xml"; }
# highlights: selection, current line, search, line numbers...
colors_highlights() { mkdir -p "$FC"; colors_file "$FC/$COLORS_PREFIX-highlights.xml"; }
# annotations: error and warning underlines of each module
colors_annotations() { mkdir -p "$FC"; colors_file "$FC/$COLORS_PREFIX-annotations.xml"; }
# tokens of one language: colors_language text/css <<'EOF' ... EOF
colors_language() {
  local dir="$EC/Editors/$1/FontsColors/$THEME_BASE"
  mkdir -p "$dir"
  colors_file "$dir/$COLORS_PREFIX-tokenColorings.xml"
}
# categories no NetBeans module defines (the nbkit-* ones of the coloring module):
# NetBeans only accepts them in the Defaults folder
colors_extras() {
  local dir="$EC/Editors/$1/FontsColors/$THEME_BASE/Defaults"
  mkdir -p "$dir"
  colors_file "$dir/nbkit-theme-tokenColorings.xml"
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
  elif [ ${#THEME_FONT_URLS[@]} -gt 0 ]; then
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
  theme_builder "$UD" "$STAGE" "$THEME_PROFILE" "" check
  ok "$(t theme.nb_found)"

  step "$(t theme.step_backup)"
  if theme_marked; then info "$(t theme.backup_exists)"; fi
  theme_backup

  if [ -n "$THEME_FONT_NAME" ]; then step "$(t theme.step_font "$THEME_FONT_NAME")"; else step "$(t theme.step_font_editor)"; fi
  theme_font

  step "$(t theme.step_base "$THEME_BASE_NAME")"
  # font you used in the base profile (goes to the new profile)
  FONTJSON="$(python3 - "$C/Editors/FontsColors/$THEME_BASE/$COLORS_PREFIX-tokenColorings.xml" <<'PY' 2>/dev/null || true
import sys, json, xml.dom.minidom as M
for e in M.parse(sys.argv[1]).getElementsByTagName('fontcolor'):
    f = e.getElementsByTagName('font')
    if e.getAttribute('name') == 'default' and f and f[0].getAttribute('name'):
        print(json.dumps({k: v for k, v in f[0].attributes.items() if k in ('name', 'size', 'style')}))
PY
)"
  # versions up to v17 of the old installer wrote the theme inside FlatLaf Dark: bring the original back
  if [ -e "$C/Editors/FontsColors/FlatLafDark/Defaults/onedark-mix-tokenColorings.xml" ] \
     || [ -e "$C/Editors/text/css/FontsColors/FlatLafDark/Defaults/onedark-mix-tokenColorings.xml" ]; then
    local t first
    for t in "${TARGETS[@]}"; do
      case "$t" in config/Editors/*) rm -rf "${UD:?}/$t" ;; esac
    done
    first="$(theme_backups | head -1)"
    if [ -n "$first" ]; then tar -xzf "$first" -C "$UD" --wildcards 'config/Editors/*' 2>/dev/null || true; fi
    info "$(t theme.legacy_fixed)"
  fi
  ok "$(t theme.base_kept "$THEME_BASE_NAME")"

  step "$(t theme.step_colors)"
  # UI: copy to merge your keys later
  if [ -e "$UD/$LAFT" ]; then mkdir -p "$OLD/$(dirname "$LAFT")"; cp -a "$UD/$LAFT" "$OLD/$LAFT"; fi
  rm -f "$UD/$LAFT"
  # the profile is rebuilt on each install; your tweaks (outside Defaults) stay
  find "$C/Editors" -depth -type d -path "*/FontsColors/$THEME_PROFILE/Defaults" -exec rm -rf {} + 2>/dev/null || true
  mkdir -p "$(dirname "$UD/$LAFT")"
  { echo "# nbkit theme: $THEME_PROFILE"; "${THEME_P}_ui"; } > "$UD/$LAFT"
  mkdir -p "$FC"
  "${THEME_P}_colors"
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
  base64 -d > "$COLORS_JAR" <<'B64'
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
szsLcQuGDUGXVeVf/cywkcNe0UWHPSGEKDbBGYzC6xoHcmosh0jyot3rjC1fifeGtnY3+sVjHf46
/PrbsqqCC5HUQjNj9DTTFYd4yqwn1r5CCTcQuFD+QStsz+m0U42OhEahZ8unZBWpvT7ohHQKPhX9
3DlV0Ta38/KwCiqidFePydZgxwlXMCWcEj64w5TDtqcmHZz19jHwv5HuVMD1n/YDUEsHCIzRex8o
AQAAfQcAAFBLAQIKAAoAAAgAAOqFaV0AAAAAAAAAAAAAAAAJAAQAAAAAAAAAAAAAAAAAAABNRVRB
LUlORi/+ygAAUEsBAhQAFAAICAgA6oVpXbmcL3EOAQAAOgIAABQAAAAAAAAAAAAAAAAAKwAAAE1F
VEEtSU5GL01BTklGRVNULk1GUEsBAgoACgAACAAA6YVpXQAAAAAAAAAAAAAAAAYAAAAAAAAAAAAA
AAAAewEAAG5ia2l0L1BLAQIKAAoAAAgAAOmFaV0AAAAAAAAAAAAAAAANAAAAAAAAAAAAAAAAAJ8B
AABuYmtpdC9jb2xvcnMvUEsBAhQAFAAICAgA6YVpXZYZVfqaAAAA0gAAAB4AAAAAAAAAAAAAAAAA
ygEAAG5ia2l0L2NvbG9ycy9CdW5kbGUucHJvcGVydGllc1BLAQIUABQACAgIAOmFaV3rLIP9oAAA
ANsAAAAhAAAAAAAAAAAAAAAAALACAABuYmtpdC9jb2xvcnMvQnVuZGxlX3B0LnByb3BlcnRpZXNQ
SwECFAAUAAgICADphWld6hv6vYYFAAAdDAAAKgAAAAAAAAAAAAAAAACfAwAAbmJraXQvY29sb3Jz
L1BhdHRlcm5zRmFjdG9yeSRQYWludGVyLmNsYXNzUEsBAhQAFAAICAgA6YVpXSPg9dpwAQAAPAIA
ACYAAAAAAAAAAAAAAAAAfQkAAG5ia2l0L2NvbG9ycy9QYXR0ZXJuc0ZhY3RvcnkkVG9rLmNsYXNz
UEsBAhQAFAAICAgA6YVpXRG+hy1FMAAA7mIAACIAAAAAAAAAAAAAAAAAQQsAAG5ia2l0L2NvbG9y
cy9QYXR0ZXJuc0ZhY3RvcnkuY2xhc3NQSwECFAAUAAgICADphWldjNF7HygBAAB9BwAAFgAAAAAA
AAAAAAAAAADWOwAAbmJraXQvY29sb3JzL2xheWVyLnhtbFBLBQYAAAAACgAKAMcCAABCPQAAAAA=
B64
  echo "794668cb8281f98aa673b34741855f4722f15a23df6746f8974224d5e7a8e7a1  $COLORS_JAR" | sha256sum -c --quiet - || die "$(t theme.module_corrupt)"
  cat > "$COLORS_XML" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE module PUBLIC "-//NetBeans//DTD Module Status 1.0//EN" "http://www.netbeans.org/dtds/module-status-1_0.dtd">
<module name="nbkit.colors">
    <param name="autoload">false</param>
    <param name="eager">false</param>
    <param name="enabled">true</param>
    <param name="jar">modules/nbkit-colors.jar</param>
    <param name="reloadable">false</param>
</module>
EOF
  # makes NetBeans read the module list again on the next start
  touch "$UD/.lastModified"
  ok "$(t theme.module_copied)"

  step "$(t theme.step_ui)"
  # Keeps: editor font, entries the theme does not define, your tweaks to theme entries
  # and your keys in the UI file.
  {
  python3 - "$UD" "$OLD" "$LAFT" <<'PY'
import sys, os, json, re
import xml.dom.minidom as M


_TEXTS = None
def T(key, *args):
    """Text of the key in lang/<language>.lang (nbkit passes the files in NBKIT_LANG_FILES, one per line)."""
    global _TEXTS
    if _TEXTS is None:
        _TEXTS = {}
        for path in os.environ.get('NBKIT_LANG_FILES', '').split('\n'):
            if path and os.path.exists(path):
                for line in open(path, encoding='utf-8'):
                    line = line.rstrip('\n')
                    if line and not line.startswith('#') and '=' in line:
                        k, v = line.split('=', 1)
                        _TEXTS[k] = v
    text = _TEXTS.get(key, key).replace('\\n', '\n')
    return text % args if args else text.replace('%%', '%')

UD, OLD = sys.argv[1], sys.argv[2]
MAN = os.environ['NBKIT_THEME_MANIFEST']
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
    # semantic comparison: NetBeans rewrites colors and fonts in another format when saving
    # 'default' is left out: NetBeans copies the category inheritance when saving, it is not your tweak
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
        if not os.path.exists(cur):          # file the theme does not write: goes back as it was
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
                    notes.append(T('theme.merge_font_kept', ' '.join(f[0].getAttribute(k) for k in ('name', 'size') if f[0].getAttribute(k))))
                continue
            if name in n:
                if man is not None and name in prev and not mine:
                    out[names.index(name)] = ser(e)
                    notes.append(T('theme.merge_tweak_kept', name))
                continue
            if man is not None and mine:
                continue                     # entry from an old theme version, retired
            out.append(ser(e))
            names.append(name)
        open(cur, 'w').write(HDR + '<fontscolors>\n' + '\n'.join(out) + '\n</fontscolors>\n')

# .nbattrs: merges the old entries the theme does not define
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

# UI file (FlatDarkLaf.properties or the theme's)
olaf, claf = os.path.join(OLD, LAF), os.path.join(UD, LAF)
kre = re.compile(r'^\s*([^#!\s=:][^=:\s]*)\s*[=:]\s*(.*?)\s*$')

def props(path):
    d = {}
    for l in open(path).read().splitlines():
        m = kre.match(l)
        if m:
            d[m.group(1)] = m.group(2)   # the last definition wins, as in Java
    return d

if os.path.exists(olaf) and os.path.exists(claf):
    olines = open(olaf).read().splitlines()
    old_is_theme = bool(olines) and olines[0].startswith(('# nbkit theme', '# nbkit tema', '# One Dark Pro Mix'))
    ov, cv = props(olaf), props(claf)
    pm = (man or {}).get(LAF, {})
    prevv = pm if isinstance(pm, dict) else {k: None for k in pm}
    keep = []
    for k, v in ov.items():
        if k in cv:
            continue
        if (man is not None and k not in prevv) or (man is None and not old_is_theme):
            keep.append(f'{k}={v}')          # your key the theme does not define
    if keep:
        notes.append(T('theme.merge_keys_kept', len(keep)))
    # theme keys whose value you changed (needs the value saved in the manifest)
    changed = [k for k, v in ov.items() if k in cv and prevv.get(k) is not None
               and v != prevv[k] and v != cv[k]]
    if changed:
        msg = T('theme.merge_changed') + '\n' + ''.join(
            '  ' + T('theme.merge_changed_line', k, ov[k], cv[k]) + '\n' for k in changed)
        ans = ''
        try:
            with open('/dev/tty') as tty, open('/dev/tty', 'w') as out:
                out.write(''.join('      ' + l + '\n' for l in msg.splitlines()) + '      ' + T('theme.merge_ask_keep') + ' ' + T('cli.yn_no') + ' ')
                out.flush()
                ans = tty.readline().strip().lower()
        except OSError:
            print(msg + T('theme.merge_no_tty'))
        if ans in ('s', 'sim', 'y', 'yes'):
            keep += [f'{k}={ov[k]}' for k in changed]
            notes.append(T('theme.merge_values_kept', len(changed)))
        else:
            notes.append(T('theme.merge_values_applied'))
    if keep:
        open(claf, 'a').write('\n# ---- Your preserved customizations ----\n' + '\n'.join(keep) + '\n')

json.dump(new_man, open(MAN, 'w'))
if notes:
    print('\n'.join(notes))
PY
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
  local FONT first t fontdir
  theme_migrate
  step "$(t theme.step_remove)"
  FONT="$(theme_current_font "$UD/config/Editors/FontsColors/$THEME_PROFILE/$COLORS_PREFIX-tokenColorings.xml")"
  rm -f "$UD/$LAFT"
  find "$C/Editors" -depth -type d -path "*/FontsColors/$THEME_PROFILE" -exec rm -rf {} + 2>/dev/null || true
  first="${THEME_RESTORE:-$(theme_backups | head -1)}"
  # theme of an old version (up to v17) still inside FlatLaf Dark: bring the original back
  if [ -e "$C/Editors/FontsColors/FlatLafDark/Defaults/onedark-mix-tokenColorings.xml" ]; then
    for t in "${TARGETS[@]}"; do case "$t" in config/Editors/*) rm -rf "${UD:?}/$t" ;; esac; done
    [ -n "$first" ] && tar -xzf "$first" -C "$UD" --wildcards 'config/Editors/*' 2>/dev/null || true
  fi
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
  local rc=0 stage; stage="$(tmpdir)"
  theme_builder "$UD" "$stage" "$THEME_PROFILE" "" check >/dev/null 2>&1 || true
  python3 - "$UD" <<'PY' || rc=$?
import sys, os, re, xml.dom.minidom as M
_TEXTS = None
def T(key, *args):
    """Text of the key in lang/<language>.lang (nbkit passes the files in NBKIT_LANG_FILES, one per line)."""
    global _TEXTS
    if _TEXTS is None:
        _TEXTS = {}
        for path in os.environ.get('NBKIT_LANG_FILES', '').split('\n'):
            if path and os.path.exists(path):
                for line in open(path, encoding='utf-8'):
                    line = line.rstrip('\n')
                    if line and not line.startswith('#') and '=' in line:
                        k, v = line.split('=', 1)
                        _TEXTS[k] = v
    text = _TEXTS.get(key, key).replace('\\n', '\n')
    return text % args if args else text.replace('%%', '%')
ud = sys.argv[1]
ok = True
def res(good, msg):
    global ok
    ok = ok and good
    print('  ' + T('cli.res_ok' if good else 'cli.res_problem').ljust(9) + msg)
log = os.path.join(ud, 'var', 'log', 'messages.log')
jar = os.path.join(ud, 'modules', 'nbkit-colors.jar')
text = open(log, errors='replace').read()
lines = text.splitlines()
loaded = any(re.match(r'^\s+nbkit\.colors \[', l) for l in lines)
bad = [l.strip() for l in lines if ('nbkit.colors' in l or 'nbkit/colors' in l)
       and re.search(r'could not|cannot|Exception|SEVERE|disabled|requires', l)]
listed = any('Turning on modules' in l for l in lines)
if not listed and not bad:
    print('  ' + T('cli.res_info').ljust(9) + T('theme.check_not_listed'))
else:
    res(loaded and not bad, T('theme.check_loaded') if loaded else T('theme.check_missing'))
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
PROFILE, LAFCLASS = os.environ['NBKIT_THEME_PROFILE'], os.environ['NBKIT_THEME_LAF']
res(prof == PROFILE and os.path.isdir(os.path.join(ud, 'config', 'Editors', 'FontsColors', PROFILE)),
    T('theme.check_profile', prof or T('theme.check_default')))
laf = None
lp = os.path.join(ud, 'config', 'Preferences', 'laf.properties')
if os.path.exists(lp):
    for l in open(lp).read().splitlines():
        if l.startswith('laf='):
            laf = l[4:]
res(laf == LAFCLASS, T('theme.check_laf', laf or T('theme.check_default')))
fixable = not any(re.search(r'requires|Java', b) for b in bad)
sys.exit(0 if ok else (1 if fixable else 2))
PY
  return $rc
}
