"""Builds the theme profile as a copy of the base profile of this NetBeans version, with the theme colors (written to
<stage> by write_colors.py) and the editor font. Before it, verify.py checks the installation.
    build.py <userdir> <stage> <profile> <font of the base profile, JSON or "">"""
import json
import os
import re
import sys
import xml.dom.minidom as M

from nbfiles import ATTRIBUTES_HEADER as NBATTRS_HDR
from nbinstall import TYPE_ATTR, Jars, base_profile
from nbfiles import FONTSCOLORS_HEADER as HDR
from text import T
from uievents import event

UD, STAGE, PROFILE, FONTJSON = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
BASE = os.environ.get('NBKIT_THEME_BASE', 'FlatLafDark')            # folder of the NetBeans profile that is copied
BASE_NAME = os.environ.get('NBKIT_THEME_BASE_NAME', 'FlatLaf Dark')  # its name in the messages
EDITORS = os.path.join(UD, 'config', 'Editors')
USERFILE = 'org-netbeans-modules-editor-settings-CustomFontsColors-tokenColorings.xml'

def die(msg):
    print(os.environ.get('NBKIT_R', '') + T('cli.error') + os.environ.get('NBKIT_N', '') + ' ' + msg, file=sys.stderr)
    sys.exit(2)

# ---------- 1. The base profile, as the modules of this NetBeans declare it ----------
jars = Jars(UD)
if not jars.paths:
    die(T('theme.no_netbeans'))
base = base_profile(jars, BASE)    # (mime, file name, type, content)
if not any(m == '' for m, *_ in base):
    die(T('theme.no_base_colors', BASE_NAME))

# ---------- 2. Theme colors (prepared in STAGE in the old format) ----------
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

# ---------- 3. New profile: copy of the base profile + theme colors ----------
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
langs = len({m for m, *_ in base})
print('\u2713 ' + T('theme.profile_copied', len(base), BASE_NAME, langs, len(used)))

# ---------- 4. Font ----------
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
