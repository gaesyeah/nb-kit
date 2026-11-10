"""The interface window, driven like a person would (tests/gui.sh runs it on a virtual screen, Xvfb), against
the fake NetBeans of tests/netbeans in HOME: buttons, terminal, progress, questions, backups, about, closing."""
import hashlib
import os
import subprocess
import sys
import time

import helpers                  # lib/ on the path, English texts
from gui import app
from gi.repository import Gio, GLib, Gtk, Vte

PASS = FAIL = 0
# the same colors as tests/lib.sh: tests/gui.sh asks for them when its output is a terminal
COLOR = os.environ.get('NBKIT_TEST_COLOR') == '1'
G, R, N = ('\033[32m', '\033[31m', '\033[0m') if COLOR else ('', '', '')
U = os.path.join(os.environ['HOME'], '.netbeans', '31')
ctx = GLib.MainContext.default()


def check(desc, ok, detail=''):
    global PASS, FAIL
    if ok:
        PASS += 1
        print(f'  {G}ok{N}    ' + desc)
    else:
        FAIL += 1
        print(f'  {R}FAIL{N}  ' + desc + (('\n        ' + str(detail)) if detail else ''))


def wait(cond, seconds=60):
    end = time.time() + seconds
    while time.time() < end:
        while ctx.pending():
            ctx.iteration(False)
        if cond():
            return True
        time.sleep(0.02)
    return False


def ancestors(widget):
    out, p = [], widget.get_parent()
    while p:
        out.append(p)
        p = p.get_parent()
    return out


def children(box):
    out, c = [], box.get_first_child()
    while c:
        out.append(c)
        c = c.get_next_sibling()
    return out


def bulk_button(w, name):
    return next(b for b in children(w.bulk) if b.get_name() == name)


def status(w, mid):
    return w.rows[mid]['status'].get_text()


def terminal_text(w):
    return w.terminal.get_text_format(1)        # Vte.Format.TEXT


def fingerprint():
    out = []
    for root, dirs, files in os.walk(U):
        dirs[:] = sorted(d for d in dirs if os.path.relpath(os.path.join(root, d), U) != 'var')
        for f in sorted(files):
            if f.endswith('.tar.gz') or f == '.lastModified':
                continue
            p = os.path.join(root, f)
            out.append(os.path.relpath(p, U) + ' ' + hashlib.sha1(open(p, 'rb').read()).hexdigest())
    return out


def finish_waiting(w):
    """after an install nbkit waits for NetBeans to open (Enter cancels); the fake NetBeans never opens"""
    wait(lambda: 'Waiting for NetBeans to open' in terminal_text(w), 30)
    w.terminal.feed_child(b'\n')
    return wait(lambda: not w.busy, 20)


def main():
    scenario = sys.argv[1]
    if scenario == 'dark':
        # the desktop asks for dark mode (GNOME setting; tests/gui.sh keeps settings in memory)
        schema = Gio.SettingsSchemaSource.get_default().lookup('org.gnome.desktop.interface', True)
        if schema is None or not schema.has_key('color-scheme'):
            print('  skipped: no org.gnome.desktop.interface color-scheme setting here')
            return 0
        Gio.Settings(settings_schema=schema).set_string('color-scheme', 'prefer-dark')
        app.apply_dark_preference()
    w = app.Window()
    w.present()
    wait(lambda: False, 0.3)
    {'actions': actions, 'closing': closing, 'dark': dark, 'decline': decline, 'small': small, 'laptop': laptop}[scenario](w)
    print()
    print(f'{G}{PASS} passed{N}' if FAIL == 0 else f'{R}{FAIL} failed{N}, {PASS} passed')
    return 0 if FAIL == 0 else 1


def actions(w):
    print('Window')
    check('runs this nbkit', app.model.ROOT == helpers.ROOT)
    check('shows the userdir', w.userdir == U and w.userdir_drop.get_visible())
    check('tools come before themes', list(w.rows) == ['jsf', 'one-dark-pro-mix'], list(w.rows))
    check('both modules not installed', [status(w, m) for m in w.rows] == ['not installed'] * 2)
    check('development section in a clone', w.dev is not None and w.dev.get_visible())
    natural = w.top.measure(Gtk.Orientation.VERTICAL, w.get_width())[1]
    check('opens with the whole top visible, development included', wait(lambda: w.paned.get_position() >= natural, 3),
          (w.paned.get_position(), natural))
    term = w.terminal.get_allocated_height()
    check('the terminal opens with room for about 16 lines', wait(lambda: w.terminal.get_allocated_height() >= 300, 3),
          w.terminal.get_allocated_height())
    check('its last line is never cut (lines sit at the bottom)', not w.terminal.get_yfill() and w.terminal.get_yalign() == Vte.Align.END, term)
    check('the terminal is whole, inside the window', inside(w))
    check('check and backups start disabled', not w.check_button.get_sensitive() and not w.backups_button.get_sensitive())
    check('a hand on what can be clicked, "not allowed" on what is disabled',
          w.rows['jsf']['buttons']['install'].get_cursor().get_name() == 'pointer'
          and w.backups_button.get_cursor().get_name() == 'not-allowed')
    check('the module buttons are not inside a list (they keep the normal button look)',
          not any(isinstance(p, Gtk.ListBoxRow) for p in ancestors(w.rows['jsf']['buttons']['install'])))
    check('install all is offered for both modules', [b.get_name() for b in children(w.bulk)] == ['install-all'])

    print('Install from a button')
    w.rows['jsf']['buttons']['install'].emit('clicked')
    check('the buttons are disabled while it runs', w.busy and not w.rows['one-dark-pro-mix']['buttons']['install'].get_sensitive())
    check('the cursor shows it is loading', w.top.get_cursor().get_name() == 'progress'
          and w.rows['one-dark-pro-mix']['buttons']['install'].get_cursor().get_name() == 'progress')
    check('the result is above the progress bar, in the type of the titles',
          w.result.get_next_sibling() is w.progress and w.result.has_css_class('heading'))
    check('the terminal runs nbkit.sh', wait(lambda: 'Installed: JSF checks' in terminal_text(w), 30), terminal_text(w)[-400:])
    check('the progress bar reaches the last step', wait(lambda: w.progress.get_text() == '2/2' and w.progress.get_fraction() == 1, 10),
          w.progress.get_text())
    check('the action finishes', finish_waiting(w))
    check('the result is shown', w.result.get_text() == 'Done', w.result.get_text())
    check('after it, the cursor is a hand again', w.top.get_cursor() is None
          and w.rows['jsf']['buttons']['reinstall'].get_cursor().get_name() == 'pointer')
    check('a finished action shows a full bar, without n/total', w.progress.get_fraction() == 1 and w.progress.get_text() == '',
          (w.progress.get_fraction(), w.progress.get_text()))
    check('the status is refreshed', status(w, 'jsf') == 'installed (v2)', status(w, 'jsf'))
    check('the buttons follow the new status', list(w.rows['jsf']['buttons']) == ['reinstall', 'uninstall'])

    print('Copying from the terminal')
    w.terminal.unselect_all()
    w.terminal.activate_action('term.copy', None)
    got = []
    w.terminal.get_clipboard().read_text_async(None, lambda cb, res: got.append(cb.read_text_finish(res)))
    check('copy without a selection takes the whole output', wait(lambda: got, 5) and 'Installed: JSF checks' in (got[0] or ''), got)
    check('the right-click menu has copy and select all', [w.terminal.get_context_menu_model().get_item_attribute_value(i, 'action').unpack()
                                                          for i in range(2)] == ['term.copy', 'term.select-all'])

    print('A question answered in the dialog')
    w.rows['jsf']['buttons']['uninstall'].emit('clicked')
    check('the question opens a dialog', wait(lambda: w.question is not None, 15))
    check('the dialog has the question of the terminal', w.run.question['text'] == 'Uninstall?', w.run.question)
    w.question_buttons['yes'].emit('clicked')
    check('the answer goes to nbkit', wait(lambda: not w.busy, 20) and status(w, 'jsf') == 'not installed', status(w, 'jsf'))

    print('A question answered in the terminal')
    w.rows['one-dark-pro-mix']['buttons']['install'].emit('clicked')
    check('theme install goes step by step', wait(lambda: w.progress.get_text() == '10/10', 60), w.progress.get_text())
    check('theme install finishes', finish_waiting(w) and status(w, 'one-dark-pro-mix') == 'installed (v29)')
    check('the backup shows up', w.backups_button.get_label() == 'Backups (1)' and w.backups_button.get_sensitive())
    w.rows['one-dark-pro-mix']['buttons']['uninstall'].emit('clicked')
    check('the uninstall question opens a dialog', wait(lambda: w.question is not None, 15))
    first = w.question
    w.terminal.feed_child(b'y\n')
    # the next question may come in the same read of the events: the dialog is then replaced right away
    check('typing the answer in the terminal closes the dialog', wait(lambda: w.question is not first, 10))
    check('the next question opens another dialog', wait(lambda: w.question is not None and w.run.question is not None
                                                          and 'Also delete the backups' in w.run.question['text'], 30), w.run.question)
    w.question_buttons['no'].emit('clicked')
    check('uninstall finishes keeping the backup', wait(lambda: not w.busy, 20) and status(w, 'one-dark-pro-mix') == 'not installed'
          and w.backups_button.get_label() == 'Backups (1)')

    print('Backups')
    w.backups_button.emit('clicked')
    wait(lambda: False, 0.3)
    check('the backups window lists the backup', len(w.backup_rows) == 1)
    w.backup_rows[0]['delete'].emit('clicked')
    check('deleting asks first', wait(lambda: w.question is not None, 15) and w.run.question['text'].startswith('Delete the backup of'))
    w.question_buttons['yes'].emit('clicked')
    check('the backup is deleted', wait(lambda: not w.busy, 15) and w.backups_button.get_label() == 'Backups (0)'
          and not [f for f in os.listdir(U) if f.endswith('.tar.gz')])

    print('All at once')
    bulk_button(w, 'install-all').emit('clicked')
    check('install all installs both', finish_waiting(w) and [status(w, m) for m in w.rows] == ['installed (v2)', 'installed (v29)'],
          [status(w, m) for m in w.rows])
    check('then reinstall all and uninstall all are offered', [b.get_name() for b in children(w.bulk)] == ['reinstall-all', 'uninstall-all'])
    bulk_button(w, 'uninstall-all').emit('clicked')
    check('uninstall all asks once', wait(lambda: w.question is not None, 15) and w.run.question['text'] == 'Uninstall?')
    w.question_buttons['yes'].emit('clicked')
    wait(lambda: w.question is not None or not w.busy, 30)
    if w.question is not None:                          # keep the backup of the theme
        w.question_buttons['no'].emit('clicked')
    check('uninstall all removes both', wait(lambda: not w.busy, 20) and [status(w, m) for m in w.rows] == ['not installed'] * 2)

    print('Changes made outside the window')
    subprocess.run(['bash', app.model.NBKIT, 'install', 'jsf'], stdin=subprocess.DEVNULL, capture_output=True)
    check('a module installed from the terminal shows up by itself', wait(lambda: status(w, 'jsf') == 'installed (v2)', 10),
          status(w, 'jsf'))

    print('About')
    w.about_button.emit('clicked')
    wait(lambda: False, 0.3)
    check('about shows the version and the repository', w.about.get_version() == w.st['version'] and 'gaesyeah/nb-kit' in w.about.get_website())
    w.about.destroy()


def inside(w):
    """the terminal ends inside the window (nothing of it cut at the bottom)"""
    _, t = w.terminal.compute_bounds(w)
    _, p = w.paned.compute_bounds(w)
    return t.origin.y + t.size.height <= p.origin.y + p.size.height and t.size.height >= w.TERMINAL_MIN


def laptop(w):
    print('A laptop screen (1366x768)')
    natural = w.top.measure(Gtk.Orientation.VERTICAL, w.get_width())[1]
    check('the whole top is visible, development included', wait(lambda: w.paned.get_position() >= natural, 3),
          (w.paned.get_position(), natural))
    check('and the terminal is whole, inside the window', inside(w))


def small(w):
    print('A short screen')
    check('the terminal is whole, inside the window', wait(lambda: inside(w), 3))
    check('the top scrolls instead', w.paned.get_position() < w.top.measure(Gtk.Orientation.VERTICAL, w.get_width())[1])
    w.set_default_size(w.get_width(), 380)
    wait(lambda: False, 0.5)
    check('making the window shorter by hand does not cut the terminal either', inside(w))


def dark(w):
    print('Colors of the system')
    check('dark mode of the desktop turns the window dark', Gtk.Settings.get_default().get_property('gtk-application-prefer-dark-theme'))
    fg = w.top.get_color()
    check('the window writes in a light color', fg.red + fg.green + fg.blue > 2, fg.to_string())
    check('the terminal has no background of its own (it shows the theme one)', w.terminal.get_color_background_for_draw().alpha == 0,
          w.terminal.get_color_background_for_draw().to_string())


def decline(w):
    print('Not opening NetBeans after an install')
    w.rows['jsf']['buttons']['install'].emit('clicked')
    check('it offers to open NetBeans', wait(lambda: w.question is not None, 30) and w.run.question['text'] == 'Open NetBeans now?', w.run.question)
    w.question_buttons['no'].emit('clicked')
    check('it does not wait for NetBeans', wait(lambda: not w.busy, 10), terminal_text(w)[-300:])
    check('it says how to check later', 'To check later' in terminal_text(w) and 'Waiting for NetBeans' not in terminal_text(w))
    check('the action is done', w.result.get_text() == 'Done', w.result.get_text())


def closing(w):
    print('Closing the window during an install')
    before = fingerprint()
    os.environ['NBKIT_TEST_PAUSE_STEP'] = '6'       # nbkit stops at step 6 (lib/terminal.sh), half-way
    w.rows['one-dark-pro-mix']['buttons']['install'].emit('clicked')
    check('the install reaches step 6', wait(lambda: w.run.step == 6, 60), w.progress.get_text())
    w.close()
    check('the window waits for nbkit to stop', w.closing and w.busy)
    check('nbkit stops', wait(lambda: not w.busy, 30))
    check('it stopped with Ctrl+C', w.last_code == 130, w.last_code)
    check('the terminal says it went back', 'nothing was changed in NetBeans' in terminal_text(w), terminal_text(w)[-600:])
    after = fingerprint()
    check('everything went back', after == before, sorted(set(before) ^ set(after))[:5])


if __name__ == '__main__':
    sys.exit(main())
