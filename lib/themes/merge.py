"""Merges the theme just written with what the user had before it (kept in OLD by lib/themes.sh): the editor font,
color files and entries the theme does not write, tweaks to theme entries, .nbattrs entries and the user's keys
in the UI file. The manifest (NBKIT_THEME_MANIFEST) remembers what the theme wrote, to tell the user's changes
from an older theme version.
    merge.py <userdir> <old copy> <UI file, relative to the userdir>"""
import json
import os
import re
import sys
import xml.dom.minidom as M

from nbfiles import FONTSCOLORS_HEADER as HDR
from text import T
from uievents import event

ATTRS = ('default', 'foreColor', 'bgColor', 'underline', 'strikeThrough', 'waveUnderlined')
# colors Java writes by name in older files
NAMED = {'black': '000000', 'blue': '0000ff', 'cyan': '00ffff', 'darkGray': '404040', 'gray': '808080',
         'green': '00ff00', 'lightGray': 'c0c0c0', 'magenta': 'ff00ff', 'orange': 'ffc800', 'pink': 'ffafaf',
         'red': 'ff0000', 'white': 'ffffff', 'yellow': 'ffff00'}
PROPERTY = re.compile(r'^\s*([^#!\s=:][^=:\s]*)\s*[=:]\s*(.*?)\s*$')
THEME_MARKS = ('# nbkit theme', '# nbkit tema', '# One Dark Pro Mix')     # first line of a UI file the theme wrote


# ---------- color entries ----------
def norm(color):
    """a color as aarrggbb, whatever way NetBeans saved it"""
    v = NAMED.get(color, color).lower()
    return ('ff' + v) if len(v) == 6 else v


def key(e):
    """an entry compared by meaning (NetBeans rewrites colors and fonts in another format when saving);
    'default' is left out: NetBeans copies the category inheritance when saving, it is not a tweak"""
    a = {k: (v if k == 'name' else norm(v)) for k, v in e.attributes.items() if k != 'default'}
    f = e.getElementsByTagName('font')
    fa = dict(f[0].attributes.items()) if f else {}
    return json.dumps([sorted(a.items()), sorted(fa.items())])


def entries(path):
    return {e.getAttribute('name'): e for e in M.parse(path).getElementsByTagName('fontcolor')}


def ser(e, font=None):
    """the entry as a line of a color file; font: the <font> to use instead of its own"""
    a = ''.join(f' {k}="{e.getAttribute(k)}"' for k in ['name'] + list(ATTRS) if e.hasAttribute(k))
    f = font if font is not None else (e.getElementsByTagName('font') or [None])[0]
    if f is not None and f.attributes.length:
        fa = ''.join(f' {k}="{v}"' for k, v in f.attributes.items())
        return f'    <fontcolor{a}><font{fa}/></fontcolor>'
    return f'    <fontcolor{a}/>'


def merge_color_file(old_path, cur_path, man, prev, notes):
    """the theme file with the user's font, tweaks and own entries from the old one"""
    try:
        old = entries(old_path)
    except Exception:
        return
    new = entries(cur_path)
    out = [ser(e) for e in new.values()]
    names = list(new)
    for name, e in old.items():
        mine = name in prev and prev[name] == key(e)
        if name == 'default' and name in new:
            f = e.getElementsByTagName('font')
            if f and f[0].attributes.length:
                out[names.index(name)] = ser(new[name], font=f[0])
                notes.append(T('theme.merge_font_kept', ' '.join(f[0].getAttribute(k) for k in ('name', 'size') if f[0].getAttribute(k))))
            continue
        if name in new:
            if man is not None and name in prev and not mine:
                out[names.index(name)] = ser(e)
                notes.append(T('theme.merge_tweak_kept', name))
            continue
        if man is not None and mine:
            continue                     # entry from an old theme version, retired
        out.append(ser(e))
        names.append(name)
    with open(cur_path, 'w') as f:
        f.write(HDR + '<fontscolors>\n' + '\n'.join(out) + '\n</fontscolors>\n')


def merge_color_files(ud, old_root, laf, man, notes):
    for root, _, files in os.walk(old_root):
        for fn in files:
            rel = os.path.relpath(os.path.join(root, fn), old_root)
            old, cur = os.path.join(old_root, rel), os.path.join(ud, rel)
            if rel == laf or fn == '.nbattrs' or '/Defaults/' in rel:
                continue
            if not os.path.exists(cur):          # file the theme does not write: goes back as it was
                os.makedirs(os.path.dirname(cur), exist_ok=True)
                with open(old, 'rb') as src, open(cur, 'wb') as dst:
                    dst.write(src.read())
                continue
            if fn.endswith('.xml'):
                merge_color_file(old, cur, man, (man or {}).get(rel, {}), notes)


def merge_attributes(ud, old_root):
    """.nbattrs: the old entries the theme does not define go back"""
    for root, _, files in os.walk(old_root):
        if '.nbattrs' not in files:
            continue
        rel = os.path.relpath(os.path.join(root, '.nbattrs'), old_root)
        cur = os.path.join(ud, rel)
        if not os.path.exists(cur):
            continue
        od, cd = M.parse(os.path.join(old_root, rel)), M.parse(cur)
        have = {f.getAttribute('name') for f in cd.getElementsByTagName('fileobject')}
        add = [f for f in od.getElementsByTagName('fileobject') if f.getAttribute('name') not in have]
        if add:
            with open(cur) as f:
                txt = f.read()
            extra = ''.join('    ' + f.toxml() + '\n' for f in add)
            with open(cur, 'w') as f:
                f.write(txt.replace('</attributes>', extra + '</attributes>'))


# ---------- UI file (FlatDarkLaf.properties or the theme's) ----------
def props(path):
    """key -> value of a .properties file; the last definition wins, as in Java"""
    d = {}
    with open(path) as f:
        for line in f.read().splitlines():
            m = PROPERTY.match(line)
            if m:
                d[m.group(1)] = m.group(2)
    return d


def ask_keep(msg):
    """asks whether to keep the values the user changed (default: no)"""
    try:
        if os.environ.get('NBKIT_INTERACTIVE') != '1':
            raise OSError('not interactive')       # same answer as with no terminal
        with open('/dev/tty') as tty, open('/dev/tty', 'w') as out:
            out.write(''.join('      ' + line + '\n' for line in msg.splitlines()) + '      ' + T('theme.merge_ask_keep')
                      + ' ' + T('cli.yn_no') + ' ')
            out.flush()
            event(ev='ask', text=T('theme.merge_ask_keep'), detail=msg, default='N')
            answer = tty.readline().strip().lower()
            event(ev='answered')
            return answer in ('s', 'sim', 'y', 'yes')
    except OSError:
        print(msg + T('theme.merge_no_tty'))
        return False


def merge_ui(old_path, cur_path, man, laf, notes):
    """keys of the user the theme does not define are appended; theme keys the user changed are kept if asked"""
    if not (os.path.exists(old_path) and os.path.exists(cur_path)):
        return
    with open(old_path) as f:
        first = f.readline()
    old_is_theme = first.startswith(THEME_MARKS)
    ov, cv = props(old_path), props(cur_path)
    pm = (man or {}).get(laf, {})
    prevv = pm if isinstance(pm, dict) else {k: None for k in pm}
    keep = [f'{k}={v}' for k, v in ov.items() if k not in cv
            and ((man is not None and k not in prevv) or (man is None and not old_is_theme))]
    if keep:
        notes.append(T('theme.merge_keys_kept', len(keep)))
    # theme keys whose value you changed (needs the value saved in the manifest)
    changed = [k for k, v in ov.items() if k in cv and prevv.get(k) is not None and v != prevv[k] and v != cv[k]]
    if changed:
        msg = T('theme.merge_changed') + '\n' + ''.join('  ' + T('theme.merge_changed_line', k, ov[k], cv[k]) + '\n' for k in changed)
        if ask_keep(msg):
            keep += [f'{k}={ov[k]}' for k in changed]
            notes.append(T('theme.merge_values_kept', len(changed)))
        else:
            notes.append(T('theme.merge_values_applied'))
    if keep:
        with open(cur_path, 'a') as f:
            f.write('\n# ---- Your preserved customizations ----\n' + '\n'.join(keep) + '\n')


def main():
    ud, old_root, laf = sys.argv[1:4]
    manifest = os.environ['NBKIT_THEME_MANIFEST']
    try:
        with open(manifest) as f:
            man = json.load(f)
    except Exception:
        man = None
    # what the theme writes now, for the next install (before the user's keys are appended)
    new_man = {}
    cur_laf = os.path.join(ud, laf)
    if os.path.isfile(cur_laf):
        new_man[laf] = props(cur_laf)
    notes = []
    merge_color_files(ud, old_root, laf, man, notes)
    merge_attributes(ud, old_root)
    merge_ui(os.path.join(old_root, laf), cur_laf, man, laf, notes)
    with open(manifest, 'w') as f:
        json.dump(new_man, f)
    if notes:
        print('\n'.join(notes))


if __name__ == '__main__':
    main()
