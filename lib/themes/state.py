"""Look and feel and editor profile: keeps the current ones and selects the theme's (select), or brings the kept ones
back (restore). The kept state is in NBKIT_THEME_STATE."""
import json
import os
import sys
import xml.dom.minidom as M

from nbfiles import ATTRIBUTES_HEADER, attributes_path, current_laf, current_profile, laf_path


def set_profile(ud, value):
    """selects the editor color profile (None: the NetBeans default); removes .nbattrs when nothing is left in it"""
    path = attributes_path(ud)
    doc = M.parse(path) if os.path.exists(path) else M.parseString('<attributes version="1.0"/>')
    root = doc.documentElement
    fo = next((f for f in root.getElementsByTagName('fileobject') if f.getAttribute('name') == 'Editors'), None)
    if fo is None:
        fo = doc.createElement('fileobject')
        fo.setAttribute('name', 'Editors')
        root.appendChild(fo)
    for a in list(fo.getElementsByTagName('attr')):
        if a.getAttribute('name') == 'currentFontColorProfile':
            fo.removeChild(a)
    if value is not None:
        a = doc.createElement('attr')
        a.setAttribute('name', 'currentFontColorProfile')
        a.setAttribute('stringvalue', value)
        fo.appendChild(a)
    elif not any(n.nodeType == 1 for n in fo.childNodes):
        root.removeChild(fo)
    body = ''.join(n.toxml() for n in root.childNodes if n.nodeType == 1)
    if not body:
        # nothing left: the file did not exist before the theme
        if os.path.exists(path):
            os.remove(path)
        return
    with open(path, 'w') as f:
        f.write(ATTRIBUTES_HEADER + '<attributes version="1.0">\n' + body + '\n</attributes>\n')


def set_laf(ud, value):
    """selects the look and feel (None: the default); removes laf.properties when nothing is left in it"""
    path = laf_path(ud)
    lines = []
    if os.path.exists(path):
        with open(path) as f:
            lines = f.read().splitlines()
    lines = [line for line in lines if not line.startswith('laf=')] + ([f'laf={value}'] if value else [])
    if not lines:
        # nothing left: the file did not exist before the theme
        if os.path.exists(path):
            os.remove(path)
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write('\n'.join(lines) + '\n')


def main():
    ud, mode, laf, profile = sys.argv[1:5]
    state = os.environ['NBKIT_THEME_STATE']
    if mode == 'select':
        if not os.path.exists(state):
            with open(state, 'w') as f:
                json.dump({'laf': current_laf(ud), 'profile': current_profile(ud)}, f)
        set_laf(ud, laf)
        set_profile(ud, profile)
        return
    kept = {'laf': None, 'profile': os.environ.get('NBKIT_THEME_BASE_PROFILE', 'FlatLaf Dark')}
    if os.path.exists(state):
        with open(state) as f:
            kept = json.load(f)
    set_laf(ud, kept.get('laf'))
    set_profile(ud, kept.get('profile'))
    if os.path.exists(state):
        os.remove(state)


main()
