"""Builds the theme profile as a copy of the base profile of this NetBeans version (check mode: only validates)."""
import sys, os, re, json, glob, zipfile
import xml.dom.minidom as M
from text import T
from uievents import event

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
    print(os.environ.get('NBKIT_R', '') + T('cli.error') + os.environ.get('NBKIT_N', '') + ' ' + msg, file=sys.stderr)
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
            event(ev='ask', text=question, default='N')
            answer = tty.readline()
            event(ev='answered')
            return answer.strip().lower() in ('s', 'sim', 'y', 'yes')
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
