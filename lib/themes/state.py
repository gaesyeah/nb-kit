"""Look and feel and editor profile: keeps the current ones (select) or brings them back (restore)."""
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
    elif not any(n.nodeType == 1 for n in fo.childNodes):
        root.removeChild(fo)
    body = ''.join(n.toxml() for n in root.childNodes if n.nodeType == 1)
    if not body:
        # nothing left: the file did not exist before the theme
        if os.path.exists(attrs):
            os.remove(attrs)
        return
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
    if not lines:
        # nothing left: the file did not exist before the theme
        if os.path.exists(lafp):
            os.remove(lafp)
        return
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
