"""Reads modules/tools/<id>/tool.toml and prints the bash that registers each tool (lib/tools.sh)."""
import glob
import os
import re
import shlex
import sys
import tomllib

from text import T
from toml_data import localized, need

q = shlex.quote


class ToolError(Exception):
    pass


def key_error(kind, key):
    return ToolError(T('tool.missing_key' if kind == 'missing' else 'tool.bad_value', key))


def read_tool(folder):
    """the values of tool_register for one folder, or ToolError with the reason"""
    tid = os.path.basename(folder)
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', tid):
        raise ToolError(T('theme.bad_id'))
    try:
        with open(os.path.join(folder, 'tool.toml'), 'rb') as f:
            data = tomllib.load(f)
    except tomllib.TOMLDecodeError as e:
        raise ToolError(T('theme.toml_syntax', str(e)))
    tool = data.get('tool', {})
    name = localized(need(tool, 'name', (str, dict), lambda k, key: key_error(k, 'tool.' + key)))
    version = need(tool, 'version', int, lambda k, key: key_error(k, 'tool.' + key))
    desc, hint = localized(tool.get('description', '')), localized(tool.get('hint', ''))
    jar = codename = sha = ''
    module = data.get('netbeans_module')
    if module is not None:
        err = lambda k, key: key_error(k, 'netbeans_module.' + key)     # noqa: E731
        jar, codename, sha = need(module, 'jar', str, err), need(module, 'codename', str, err), need(module, 'sha256', str, err)
        if not re.fullmatch(r'[0-9a-f]{64}', sha):
            raise key_error('bad', 'netbeans_module.sha256')
        if not re.fullmatch(r'[A-Za-z0-9_.]+', codename):
            raise key_error('bad', 'netbeans_module.codename')
        if not os.path.isfile(os.path.join(folder, jar)):
            raise ToolError(T('theme.missing_file', jar))
    script = os.path.join(folder, 'tool.sh')
    if module is None and not os.path.isfile(script):
        raise ToolError(T('tool.nothing'))
    uninstall = data.get('uninstall', {})
    return (tid, name, desc, version, folder, hint, jar, codename, sha,
            localized(uninstall.get('goes', '')), localized(uninstall.get('stays', '')))


for path in sorted(glob.glob(os.path.join(sys.argv[1], '*', 'tool.toml'))):
    folder = os.path.dirname(path)
    try:
        values = read_tool(folder)
    except ToolError as e:
        print(f'printf "%s%s%s\\n" "$Y" {q(T("tool.invalid", os.path.basename(folder), str(e)))} "$N" >&2')
        continue
    print('tool_register ' + ' '.join(q(str(v)) for v in values))
    if os.path.isfile(os.path.join(folder, 'tool.sh')):
        print(f'source {q(os.path.join(folder, "tool.sh"))}')
