"""Merges the theme with the user's customizations (editor font, own entries, tweaks and UI keys)."""
import sys, os, json, re
import xml.dom.minidom as M
from text import T
from uievents import event

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
                event(ev='ask', text=T('theme.merge_ask_keep'), detail=msg, default='N')
                ans = tty.readline().strip().lower()
                event(ev='answered')
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
