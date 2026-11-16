"""What is specific to a theme backup, read-only: interface keys and editor colors that are not NetBeans' own
FlatLaf Dark defaults, split into the old installer's and yours (bash already classified each color file,
read-only, with the same signature theme_legacy_custom_out uses to clean them up); the editor font it held.
Reuses merge.py (props, entries, key, ATTRS, THEME_MARKS), nbfiles.default_font (font.py's own font-reading
logic) and nbinstall.Jars/base_profile (the same NetBeans defaults build.py and verify.py read).
    backup_detail.py <userdir> <extracted dir> <base folder> <colors prefix> <laf relative path> <color manifest>

The color manifest (written by theme_backup_detail) has one line per color file found in the backup:
"<1 if written by the old installer, else 0><TAB><mime, empty for the base><TAB><token|highlight|annotation>
<TAB><path relative to the extracted dir>". Missing or empty: no colors to analyze.
"""
import os
import sys
import xml.dom.minidom as M

from merge import ATTRS, THEME_MARKS, entries, key, props
from nbfiles import default_font
from nbinstall import Jars, base_profile
from text import T

CAP = 10


def cap(items):
    """the first 10 items and how many are left out"""
    return items[:CAP], max(0, len(items) - CAP)


def list_lines(items):
    shown, more = cap(items)
    lines = list(shown)
    if more:
        lines.append(T('theme.bd_and_more', more))
    return lines


def ui_section(path):
    """lines about the interface keys the backup holds (yours, or the old installer's), or [] without them"""
    if not os.path.isfile(path):
        return []
    with open(path) as f:
        first = f.readline()
    items = [f'{k}={v}' for k, v in props(path).items()]
    if not items:
        return []
    if first.startswith(THEME_MARKS):
        header = T('theme.bd_ui_installer')
    elif len(items) == 1:
        header = T('theme.bd_ui_key_one')
    else:
        header = T('theme.bd_ui_key_many', len(items))
    return [header] + ['  ' + i for i in list_lines(items)]


def entries_from_bytes(data):
    """merge.entries, but from the bytes of a NetBeans resource instead of a path on disk"""
    return {e.getAttribute('name'): e for e in M.parseString(data).getElementsByTagName('fontcolor')}


def format_entry(mime, e):
    """"<language>: name: attr=value ... font Name size", the same mime names colors.toml uses ("all" for the
    base profile); the names repeat across languages, so the language is what tells them apart"""
    parts = [f'{k}={e.getAttribute(k)}' for k in ATTRS if e.hasAttribute(k)]
    f = e.getElementsByTagName('font')
    if f and f[0].attributes.length:
        parts.append('font ' + ' '.join(f[0].getAttribute(k) for k in ('name', 'size') if f[0].getAttribute(k)))
    return (mime or 'all') + ': ' + e.getAttribute('name') + ': ' + ' '.join(parts)


def stock_index(jars, base):
    """{(mime, type, name): element} of the NetBeans defaults of the base profile, as the modules declare them"""
    out = {}
    for mime, _fn, typ, data in base_profile(jars, base):
        try:
            for name, e in entries_from_bytes(data).items():
                out[(mime, typ, name)] = e
        except Exception:
            continue
    return out


def color_sections(ud, root, base, manifest):
    """lines about the backup's colors: only those different from the NetBeans defaults, split into the old
    installer's (just the total: those are discarded automatically when the theme installs, so the entries
    themselves are not worth listing) and yours (listed, with the language they belong to); without an
    installation to compare with, every color found is listed as yours, uncertain"""
    if not os.path.isfile(manifest):
        return []
    with open(manifest) as f:
        rows = [line.rstrip('\n').split('\t', 3) for line in f if line.strip()]
    if not rows:
        return []
    jars = Jars(ud)
    stock = stock_index(jars, base) if jars.paths else None
    installer, yours = 0, []
    for legacy, mime, typ, rel in rows:
        try:
            ents = entries(os.path.join(root, rel))
        except Exception:
            continue
        for name, e in ents.items():
            if stock is not None:
                ref = stock.get((mime, typ, name))
                if ref is not None and key(e) == key(ref):
                    continue                       # identical to the NetBeans default: not a change
            if legacy == '1':
                installer += 1
            else:
                yours.append(format_entry(mime, e))
    out = [] if stock is not None else [T('theme.bd_no_stock')]
    if stock is not None and (installer or yours):
        out.append(T('theme.bd_stock_note'))
    if installer:
        out.append(T('theme.bd_color_installer_one') if installer == 1 else T('theme.bd_color_installer_many', installer))
    if yours:
        out.append(T('theme.bd_color_yours_one') if len(yours) == 1 else T('theme.bd_color_yours_many', len(yours)))
        out += ['  ' + i for i in list_lines(yours)]
    return out


def font_section(root, base, colors_prefix):
    """the editor font this backup held, read the same way font.py reads it for the uninstall message"""
    path = os.path.join(root, 'config', 'Editors', 'FontsColors', base, colors_prefix + '-tokenColorings.xml')
    if not os.path.isfile(path):
        return []
    font = default_font(path)
    if not font:
        return []
    return [T('theme.bd_font', ' '.join(font[k] for k in ('name', 'size') if font.get(k)))]


def main():
    ud, root, base, colors_prefix, laf, manifest = sys.argv[1:7]
    lines = ui_section(os.path.join(root, laf)) + color_sections(ud, root, base, manifest) + \
        font_section(root, base, colors_prefix)
    if lines:
        print('\n'.join(lines))


if __name__ == '__main__':
    main()
