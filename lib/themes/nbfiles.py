"""NetBeans settings files the theme engine reads and writes: their headers, the selected color profile and look
and feel, and the editor font of a color file."""
import os
import re
import xml.dom.minidom as M

FONTSCOLORS_HEADER = ('<?xml version="1.0" encoding="UTF-8"?>\n'
                      '<!DOCTYPE fontscolors PUBLIC "-//NetBeans//DTD Editor Fonts and Colors settings 1.2//EN" '
                      '"https://netbeans.apache.org/dtds/EditorFontsColors-1_2.dtd">\n')
ATTRIBUTES_HEADER = ('<?xml version="1.0" encoding="UTF-8"?>\n'
                     '<!DOCTYPE attributes PUBLIC "-//NetBeans//DTD DefaultAttributes 1.0//EN" '
                     '"http://www.netbeans.org/dtds/attributes-1_0.dtd">\n')


def attributes_path(ud):
    return os.path.join(ud, 'config', '.nbattrs')


def laf_path(ud):
    return os.path.join(ud, 'config', 'Preferences', 'laf.properties')


def current_profile(ud):
    """the editor color profile selected (config/.nbattrs), or None for the NetBeans default"""
    path = attributes_path(ud)
    if os.path.exists(path):
        for fo in M.parse(path).getElementsByTagName('fileobject'):
            if fo.getAttribute('name') == 'Editors':
                for a in fo.getElementsByTagName('attr'):
                    if a.getAttribute('name') == 'currentFontColorProfile':
                        return a.getAttribute('stringvalue')
    return None


def current_laf(ud):
    """the look and feel class selected (config/Preferences/laf.properties), or None for the default"""
    path = laf_path(ud)
    if os.path.exists(path):
        with open(path) as f:
            for line in f.read().splitlines():
                m = re.match(r'^laf=(.*)$', line)
                if m:
                    return m.group(1)
    return None


def default_font(path):
    """{name, size, style} of the font of the 'default' entry of a color file, or None"""
    for e in M.parse(path).getElementsByTagName('fontcolor'):
        f = e.getElementsByTagName('font')
        if e.getAttribute('name') == 'default' and f and f[0].getAttribute('name'):
            return {k: v for k, v in f[0].attributes.items() if k in ('name', 'size', 'style')}
    return None
