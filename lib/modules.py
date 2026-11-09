"""Reads modules/<id>/module.toml and prints the bash that registers each NetBeans module."""
import glob
import os
import re
import shlex
import sys
import tomllib
from text import T

LANG = os.environ.get('NBKIT_LANG', 'en')
q = shlex.quote


class ModuleError(Exception):
    pass


def text(value):
    """plain text, or a table by language: { en = "...", pt-BR = "..." }"""
    if isinstance(value, dict):
        return value.get(LANG) or value.get(LANG.split('-')[0]) or value.get('en') or next(iter(value.values()), '')
    return value if isinstance(value, str) else ''


def need(table, key, kind):
    value = table.get(key)
    if value is None:
        raise ModuleError(T('mod.missing_key', key))
    if not isinstance(value, kind) or isinstance(value, bool):
        raise ModuleError(T('mod.bad_value', key))
    return value


for path in sorted(glob.glob(os.path.join(sys.argv[1], '*', 'module.toml'))):
    folder = os.path.dirname(path)
    mid = os.path.basename(folder)
    try:
        if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', mid):
            raise ModuleError(T('theme.bad_id'))
        try:
            with open(path, 'rb') as f:
                data = tomllib.load(f)
        except tomllib.TOMLDecodeError as e:
            raise ModuleError(T('theme.toml_syntax', str(e)))
        mod = data.get('module', {})
        name = text(need(mod, 'name', (str, dict)))
        desc = text(mod.get('description', ''))
        version = need(mod, 'version', int)
        jar = need(mod, 'jar', str)
        codename = need(mod, 'codename', str)
        sha = need(mod, 'sha256', str)
        if not re.fullmatch(r'[0-9a-f]{64}', sha):
            raise ModuleError(T('mod.bad_value', 'sha256'))
        if not re.fullmatch(r'[A-Za-z0-9_.]+', codename):
            raise ModuleError(T('mod.bad_value', 'codename'))
        if not os.path.isfile(os.path.join(folder, jar)):
            raise ModuleError(T('theme.missing_file', jar))
        hint = text(mod.get('hint', ''))
        uninstall = data.get('uninstall', {})
        goes, stays = text(uninstall.get('goes', '')), text(uninstall.get('stays', ''))
    except ModuleError as e:
        print(f'printf "%s\\n" {q(T("mod.invalid", mid, str(e)))} >&2')
        continue
    p = 'nm_' + mid.replace('-', '_')
    print('nbmod_register ' + ' '.join(q(str(v)) for v in (mid, p, name, desc, version, folder, jar, codename, sha, hint, goes, stays)))
