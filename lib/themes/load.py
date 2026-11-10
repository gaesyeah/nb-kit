"""Reads modules/themes/<id>/theme.toml and prints the bash that registers each theme."""
import glob
import os
import re
import shlex
import sys
import tomllib

from text import T
from theme_colors import COLOR, ThemeError, read_colors
from toml_data import localized as text
from toml_data import need as need_key


def say(text):
    """bash that prints a warning in the terminal"""
    print(f'printf "%s\\n" {shlex.quote(text)} >&2')

def message(e):
    key, values, place, line = e.args
    text = T(key, *values)
    return T('theme.error_at', text, place, line) if place else text


def need(table, key, kind, where):
    return need_key(table, key, kind, lambda k, name: ThemeError('theme.missing_key' if k == 'missing' else 'theme.bad_value',
                                                                 (where + name,)))


q = shlex.quote
for path in sorted(glob.glob(os.path.join(sys.argv[1], '*', 'theme.toml'))):
    folder = os.path.dirname(path)
    tid = os.path.basename(folder)
    try:
        if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', tid):
            raise ThemeError('theme.bad_id')
        try:
            with open(path, 'rb') as f:
                data = tomllib.load(f)
        except tomllib.TOMLDecodeError as e:
            raise ThemeError('theme.toml_syntax', (str(e),), 'theme.toml', '?')
        for name in ('ui.properties', 'colors.toml'):
            if not os.path.isfile(os.path.join(folder, name)):
                raise ThemeError('theme.missing_file', (name,))
        th = data.get('theme', {})
        name = need(th, 'name', str, 'theme.')
        version = need(th, 'version', int, 'theme.')
        profile = th.get('profile', name)
        desc = text(th.get('description', ''))
        conf = [f'THEME_PROFILE={q(profile)}']
        base = data.get('base', {})
        for key, var in (('folder', 'THEME_BASE'), ('name', 'THEME_BASE_NAME'), ('profile', 'THEME_BASE_PROFILE'),
                         ('laf', 'THEME_LAF'), ('laf_file', 'THEME_LAF_FILE')):
            if key in base:
                conf.append(f'{var}={q(need(base, key, str, "base."))}')
        font = data.get('font', {})
        if font:
            fname = need(font, 'name', str, 'font.')
            urls = font.get('urls', [])
            if not isinstance(urls, list) or not all(isinstance(u, str) for u in urls):
                raise ThemeError('theme.bad_value', ('font.urls',))
            conf += [f'THEME_FONT_NAME={q(fname)}',
                     f'THEME_FONT_DIR={q(font.get("dir", fname.replace(" ", "")))}',
                     f'THEME_FONT_SOURCE={q(text(font.get("source", "")))}',
                     'THEME_FONT_URLS=(' + ' '.join(q(u) for u in urls) + ')',
                     f'THEME_FONT_LICENSE={q(font.get("license", ""))}']
        sel = data.get('terminal', {}).get('selection')
        if sel is not None:
            if not isinstance(sel, str) or not COLOR.match(sel):
                raise ThemeError('theme.bad_value', ('terminal.selection',))
            argb = int('ff' + sel[1:], 16)
            conf.append(f'THEME_TERMINAL_SELECTION={argb - (1 << 32)}')     # as NetBeans saves it (signed int)
        read_colors(os.path.join(folder, 'colors.toml'))                     # validates now, not in the middle of an install
    except ThemeError as e:
        say(T('theme.invalid', tid, message(e)))
        continue
    p = 'th_' + tid.replace('-', '_')
    print(f'theme_register {q(tid)} {p} {q(name)} {q(desc)} {version} {q(folder)}')
    print(f'{p}_config() {{\n  ' + '\n  '.join(conf) + '\n}')
    legacy = data.get('legacy', {})
    if legacy:
        vf, mod = q(legacy.get('version_file', '')), q(legacy.get('module', ''))
        print(f'{p}_legacy_version() {{\n  if [ -n {vf} ] && [ -f "$UD"/{vf} ]; then cat "$UD"/{vf}\n'
              f'  elif [ -n {mod} ] && [ -e "$UD/modules/"{mod} ]; then echo "?"\n  fi\n}}')
