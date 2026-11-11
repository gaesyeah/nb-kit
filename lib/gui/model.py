"""What the interface shows and does, without GTK, so it can be tested without a screen
(tests/python/test_gui_model.py). The work is always nbkit.sh's: the interface reads "status --json",
runs the actions in its terminal and follows the events they write (ui_event in lib/terminal.sh)."""
import json
import os
import re
import subprocess

from text import T

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
NBKIT = os.path.join(ROOT, 'nbkit.sh')
REPO = 'https://github.com/gaesyeah/nb-kit'
ANSI = re.compile(r'\x1b\[[0-9;?]*[A-Za-z]')


def plain(text):
    """text without the terminal colors"""
    return ANSI.sub('', text)


def child_env(events=None):
    """environment of nbkit.sh: with a terminal to answer (NBKIT_TTY) and, for an action, the events file"""
    env = {k: v for k, v in os.environ.items() if k != 'NBKIT_UI_EVENTS'}
    env['NBKIT_TTY'] = '1'
    if events:
        env['NBKIT_UI_EVENTS'] = events
    return env


# ANSI colors of the terminal: the Tango palette (GNOME Terminal's), readable on light and dark backgrounds;
# the text and background colors come from the system theme (lib/gui/app.py)
PALETTE = ['#2e3436', '#cc0000', '#4e9a06', '#c4a000', '#3465a4', '#75507b', '#06989a', '#d3d7cf',
           '#555753', '#ef2929', '#8ae234', '#fce94f', '#729fcf', '#ad7fa8', '#34e2e2', '#eeeeec']


def prefers_dark(portal=None, gnome=None):
    """the system asks for dark: the desktop portal (org.freedesktop.appearance color-scheme: 1 dark, 2 light,
    0 no preference) or, without it, the GNOME setting (org.gnome.desktop.interface color-scheme)"""
    if portal in (1, 2):
        return portal == 1
    return gnome == 'prefer-dark'


class StatusError(Exception):
    pass


def status(userdir=None, run=subprocess.run):
    """nbkit.sh status --json, as a dict"""
    argv = ['bash', NBKIT, 'status', '--json'] + ([userdir] if userdir else [])
    p = run(argv, capture_output=True, text=True, stdin=subprocess.DEVNULL, env=child_env())
    if p.returncode != 0:
        raise StatusError(plain(p.stderr or p.stdout).strip())
    try:
        return json.loads(p.stdout)
    except ValueError as e:
        raise StatusError(str(e))


SECTION_KEYS = {'tool': 'gui.section_tool', 'theme': 'gui.section_theme'}
ACTION_KEYS = {'install': 'gui.install', 'update': 'gui.update', 'reinstall': 'gui.reinstall', 'uninstall': 'gui.uninstall'}


def sections(st):
    """[(category, [modules])]: tools first, then themes; only categories that have modules"""
    out = []
    for cat in SECTION_KEYS:
        mods = [m for m in st.get('modules', []) if m['category'] == cat]
        if mods:
            out.append((cat, mods))
    return out


def status_text(m):
    s, inst, ver = m['status'], m.get('installed'), m['version']
    if s == 'ok':
        return T('gui.status_ok', inst)
    if s == 'old':
        return T('gui.status_old', inst, ver) if inst else T('gui.status_old_unknown', ver)
    if s == 'new':
        return T('gui.status_new', inst)
    return T('gui.status_no')


def actions(m):
    """the buttons of a module: install | update | reinstall, and uninstall when installed"""
    s = m['status']
    if s == 'no':
        return ['install']
    if s == 'old':
        return ['update', 'uninstall']
    return ['reinstall', 'uninstall']


# tooltips of the buttons (lang/), by action
TIP_KEYS = {'install': 'gui.tip_install', 'update': 'gui.tip_update', 'reinstall': 'gui.tip_reinstall',
            'uninstall': 'gui.tip_uninstall', 'install-all': 'gui.tip_install_all', 'reinstall-all': 'gui.tip_reinstall_all',
            'uninstall-all': 'gui.tip_uninstall_all', 'backups': 'gui.tip_backups', 'check': 'gui.tip_check',
            'test': 'gui.tip_test', 'build': 'gui.tip_build', 'restore': 'gui.tip_restore', 'delete': 'gui.tip_delete'}
BULK_KEYS = {'install': 'gui.install_all', 'reinstall': 'gui.reinstall_all', 'uninstall': 'gui.uninstall_all'}


def bulk(st):
    """[(action, [ids])] for the "all" buttons, like "All" in the menu: only when it covers two modules or more.
    install takes what is missing or outdated (one theme at a time: the first), reinstall what is current,
    uninstall what is installed"""
    mods = st.get('modules', [])
    pending, theme = [], None
    for m in mods:
        if m['status'] in ('no', 'old'):
            if m['category'] == 'theme':
                if theme:
                    continue
                theme = m['id']
            pending.append(m['id'])
    groups = [('install', pending), ('reinstall', [m['id'] for m in mods if m['status'] in ('ok', 'new')]),
              ('uninstall', [m['id'] for m in mods if m['status'] != 'no'])]
    return [(act, ids) for act, ids in groups if len(ids) >= 2]


def command(action, userdir=None, target=None):
    """argv of nbkit.sh for an action; target is the module id (or a list of them) or the backup file"""
    verb = {'update': 'install', 'reinstall': 'install'}.get(action, action)
    argv = ['bash', NBKIT, verb]
    if isinstance(target, list):
        argv += target
    elif target:
        argv.append(target)
    if userdir and verb not in ('test', 'build', 'update-self', 'uninstall-self'):
        argv.append(userdir)
    return argv


def answer(yes):
    """what the dialog types in the terminal (ask_yn and the Python questions accept y in every language)"""
    return b'y\n' if yes else b'n\n'


class EventFile:
    """follows the events file of a running action: read() returns the events written since the last call"""
    def __init__(self, path):
        self.path, self.pos, self.rest = path, 0, ''

    def read(self):
        try:
            with open(self.path, encoding='utf-8') as f:
                f.seek(self.pos)
                data = f.read()
                self.pos = f.tell()
        except OSError:
            return []
        lines = (self.rest + data).split('\n')
        self.rest = lines.pop()          # a line still being written
        out = []
        for line in lines:
            try:
                ev = json.loads(line)
            except ValueError:
                continue
            if isinstance(ev, dict) and 'ev' in ev:
                out.append(ev)
        return out


class Run:
    """state of a running action, from its events: progress (step n of total) and the open question"""
    def __init__(self):
        self.step, self.total, self.question = 0, 0, None

    def apply(self, ev):
        """updates the state; returns 'progress', 'ask', 'answered' or None"""
        kind = ev.get('ev')
        if kind == 'step' and isinstance(ev.get('n'), int) and isinstance(ev.get('total'), int):
            self.step, self.total = ev['n'], ev['total']
            return 'progress'
        if kind == 'ask':
            self.question = {'text': plain(ev.get('text', '')), 'detail': plain(ev.get('detail', '')),
                             'default_yes': ev.get('default') == 'Y'}
            return 'ask'
        if kind == 'answered':
            self.question = None
            return 'answered'
        return None

    def fraction(self):
        """0..1, or None before the first step (the bar pulses)"""
        if self.total <= 0:
            return None
        return min(self.step, self.total) / self.total

    def progress_text(self):
        return f'{self.step}/{self.total}' if self.total > 0 else ''


def result_text(code):
    return T('gui.done') if code == 0 else T('gui.failed', code)
