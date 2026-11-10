"""nbkit graphical interface (bash nbkit.sh gui): GTK 4 and the VTE terminal widget.
On top, the modules from "nbkit.sh status --json"; at the bottom, a terminal where every action runs nbkit.sh
itself. The questions of nbkit also show up as dialogs, the progress bar follows the steps (lib/gui/model.py)."""
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))   # lib/
if not os.environ.get('NBKIT_LANG_FILES'):          # run without nbkit.sh: texts of NBKIT_LANG, or English
    _lang = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'lang')
    os.environ['NBKIT_LANG_FILES'] = '\n'.join(os.path.join(_lang, f + '.lang')
                                               for f in ('pt-BR', os.environ.get('NBKIT_LANG', 'en')))

import gi  # noqa: E402
gi.require_version('Gtk', '4.0')
gi.require_version('Vte', '3.91')
gi.require_version('Gdk', '4.0')
from gi.repository import Gdk, Gio, GLib, Gtk, Pango, Vte  # noqa: E402

from text import T  # noqa: E402
from gui import model  # noqa: E402

# the program name: VTE uses it for the systemd scope of each command it runs (without it GLib warns)
GLib.set_prgname('nbkit')
GLib.set_application_name('nbkit')


def system_prefers_dark():
    """dark preference of the system: plain GTK 4 (without libadwaita) does not read it by itself"""
    portal = gnome = None
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        reply = bus.call_sync('org.freedesktop.portal.Desktop', '/org/freedesktop/portal/desktop',
                              'org.freedesktop.portal.Settings', 'ReadOne',
                              GLib.Variant('(ss)', ('org.freedesktop.appearance', 'color-scheme')),
                              None, Gio.DBusCallFlags.NONE, 1000, None)
        portal = reply.unpack()[0]
    except GLib.Error:
        pass
    source = Gio.SettingsSchemaSource.get_default()
    if portal is None and source and source.lookup('org.gnome.desktop.interface', True):
        schema = Gio.Settings.new('org.gnome.desktop.interface')
        if 'color-scheme' in schema.list_keys():
            gnome = schema.get_string('color-scheme')
    return model.prefers_dark(portal, gnome)


def apply_dark_preference():
    """plain GTK 4 follows the GTK theme; the desktop's dark mode preference has to be asked for"""
    if system_prefers_dark():
        Gtk.Settings.get_default().set_property('gtk-application-prefer-dark-theme', True)


def rgba(color):
    c = Gdk.RGBA()
    c.parse(color)
    return c


def label(text, *classes, wrap=False, xalign=0.0):
    w = Gtk.Label(label=text, xalign=xalign)
    for c in classes:
        w.add_css_class(c)
    if wrap:
        w.set_wrap(True)
        w.set_wrap_mode(Pango.WrapMode.WORD_CHAR)
    return w


def button(text, callback, *args):
    b = Gtk.Button(label=text)
    b.connect('clicked', lambda _b: callback(*args))
    return b


class Window(Gtk.ApplicationWindow):
    def __init__(self, userdir=None, **kw):
        super().__init__(title='nbkit', default_width=860, default_height=720, **kw)
        self.userdir, self.st, self.busy, self.closing = userdir, {}, False, False
        self.events = self.run = self.events_path = self.question = None
        self.action_buttons, self.rows = [], {}
        self.poll_id = self.pulse_id = 0

        header = Gtk.HeaderBar()
        self.about_button = Gtk.Button(label=T('gui.about'))
        self.about_button.connect('clicked', lambda _b: self.show_about())
        self.refresh_button = Gtk.Button(icon_name='view-refresh-symbolic', tooltip_text=T('gui.refresh'))
        self.refresh_button.connect('clicked', lambda _b: self.refresh())
        header.pack_end(self.about_button)
        header.pack_end(self.refresh_button)
        self.set_titlebar(header)

        # top: userdir, notices, modules, actions; it scrolls when the window is small
        self.top = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10, margin_top=12, margin_bottom=12,
                           margin_start=14, margin_end=14)
        self.userdir_list = Gtk.StringList()
        self.userdir_drop = Gtk.DropDown(model=self.userdir_list)
        self.userdir_drop.connect('notify::selected', self.on_userdir)
        self.notice = label('', 'dim-label', wrap=True)
        self.content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.top.append(self.userdir_drop)
        self.top.append(self.notice)
        self.top.append(self.content)
        top_scroll = Gtk.ScrolledWindow(child=self.top, vexpand=True, min_content_height=160)

        # progress: pulses until the first step, then step n of total
        # progress bar and result on one row, so the terminal keeps the room
        self.progress = Gtk.ProgressBar(show_text=True, visible=False, hexpand=True, valign=Gtk.Align.CENTER)
        self.result = label('', 'dim-label', xalign=0.0)
        status_row = Gtk.Box(spacing=12, margin_start=14, margin_end=14)
        status_row.append(self.result)
        status_row.append(self.progress)

        # bottom: the terminal where nbkit.sh runs
        self.terminal = Vte.Terminal(scrollback_lines=10000, vexpand=True)
        self.terminal.set_size(80, 14)
        # the lines sit at the bottom: when the height is not a whole number of lines, the leftover goes on top
        # (blank) instead of cutting the last line; a little padding keeps it off the edge
        self.terminal.set_yfill(False)
        self.terminal.set_yalign(Vte.Align.END)
        css = Gtk.CssProvider()
        css.load_from_data(b'vte-terminal { padding: 2px 6px 6px 6px; }')
        Gtk.StyleContext.add_provider_for_display(self.get_display(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        self.terminal.connect('child-exited', self.on_child_exited)
        self.add_terminal_copy()
        # with nothing running there is nothing to type: no cursor (\e[?25l); each action shows it again
        self.terminal.feed(('\x1b[2m' + T('gui.ready') + '\x1b[0m\r\n\x1b[?25l').encode())
        term_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6, margin_top=6)
        term_box.append(status_row)
        # colors of the system theme: the terminal is transparent over a "view" background (the color of text
        # fields) and writes in the theme's text color; it follows when the theme or the dark mode changes
        # the terminal scrolls by itself (a ScrolledWindow around it can hide the last line): only a scrollbar
        term_view = Gtk.Box(vexpand=True, height_request=self.TERMINAL_MIN)
        term_view.add_css_class('view')
        self.terminal.set_hexpand(True)
        term_view.append(self.terminal)
        term_view.append(Gtk.Scrollbar(orientation=Gtk.Orientation.VERTICAL, adjustment=self.terminal.get_vadjustment()))
        term_box.append(term_view)
        self.terminal.connect('map', lambda *_a: self.sync_terminal_colors())
        for prop in ('gtk-theme-name', 'gtk-application-prefer-dark-theme'):
            Gtk.Settings.get_default().connect('notify::' + prop, lambda *_a: GLib.idle_add(self.sync_terminal_colors))

        paned = Gtk.Paned(orientation=Gtk.Orientation.VERTICAL, start_child=top_scroll, end_child=term_box,
                          resize_start_child=False, resize_end_child=True,
                          shrink_start_child=True, shrink_end_child=False)
        self.paned = paned
        # opens with the whole top visible (as long as the terminal keeps 200 px); the divider moves as usual
        self.connect('map', lambda *_a: GLib.idle_add(self.fit_top))
        self.set_child(paned)
        self.connect('close-request', self.on_close)
        self.refresh()

    # ---------- copying from the terminal: Ctrl+Shift+C, Ctrl+Shift+A and the right-click menu ----------
    def add_terminal_copy(self):
        group = Gio.SimpleActionGroup()
        for name, callback in (('copy', self.copy_terminal), ('select-all', lambda *_a: self.terminal.select_all())):
            action = Gio.SimpleAction.new(name, None)
            action.connect('activate', callback)
            group.add_action(action)
        self.terminal.insert_action_group('term', group)
        menu = Gio.Menu()
        menu.append(T('gui.copy'), 'term.copy')
        menu.append(T('gui.select_all'), 'term.select-all')
        self.terminal.set_context_menu_model(menu)
        keys = Gtk.ShortcutController(scope=Gtk.ShortcutScope.LOCAL)
        for accel, action in (('<Control><Shift>c', 'term.copy'), ('<Control><Shift>a', 'term.select-all')):
            keys.add_shortcut(Gtk.Shortcut(trigger=Gtk.ShortcutTrigger.parse_string(accel),
                                           action=Gtk.NamedAction.new(action)))
        self.terminal.add_controller(keys)

    def copy_terminal(self, *_args):
        # without a selection, copies everything (handy to send the output of an action)
        if not self.terminal.get_has_selection():
            self.terminal.select_all()
        self.terminal.copy_clipboard_format(Vte.Format.TEXT)

    # when it opens: the whole top visible and the terminal with room for about 16 lines; the window grows up to
    # 90% of the screen for that, and on a smaller screen the top scrolls
    TERMINAL_ROOM = 360
    TERMINAL_MIN = 160                     # about 9 lines: the least the terminal gets, even on a short screen

    def fit_top(self):
        _min, natural, _b, _b2 = self.top.measure(Gtk.Orientation.VERTICAL, max(self.get_width(), 1))
        rest = self.get_height() - self.paned.get_allocated_height()          # header bar
        want = rest + natural + self.TERMINAL_ROOM
        monitor = self.get_display().get_monitor_at_surface(self.get_surface()) if self.get_surface() else None
        limit = int(monitor.get_geometry().height * 0.9) if monitor else want
        if self.get_height() < min(want, limit) and not self.is_maximized():
            self.set_default_size(self.get_width(), min(want, limit))
            GLib.timeout_add(50, self.place_divider, natural)
        else:
            self.place_divider(natural)
        return False

    def place_divider(self, natural):
        # the bottom (progress + terminal) never gets less than its minimum, or GTK cuts its last lines: the top,
        # which scrolls, gives up the room instead
        bottom_min = self.paned.get_end_child().measure(Gtk.Orientation.VERTICAL, max(self.get_width(), 1))[0]
        self.paned.set_position(max(0, min(natural, self.paned.get_allocated_height() - bottom_min)))
        return False

    def sync_terminal_colors(self):
        self.terminal.set_colors(self.top.get_color(), rgba('rgba(0,0,0,0)'), [rgba(c) for c in model.PALETTE])
        return False

    # ---------- status ----------
    def refresh(self):
        try:
            self.st = model.status(self.userdir)
        except model.StatusError as e:
            self.st = {}
            self.notice.set_text(T('gui.status_error', str(e)))
            self.build_content()
            return
        self.userdir = self.st.get('userdir')
        self.fill_userdirs()
        if not self.userdir:
            self.notice.set_text(T('gui.no_userdir'))
        elif self.st.get('netbeans_running'):
            self.notice.set_text(T('gui.nb_running'))
        else:
            self.notice.set_text('')
        self.notice.set_visible(bool(self.notice.get_text()))
        self.build_content()

    def fill_userdirs(self):
        self.filling = True
        dirs = self.st.get('userdirs', [])
        self.userdir_list.splice(0, self.userdir_list.get_n_items(),
                                 [f"{d['name']}   {d['path'].replace(os.path.expanduser('~'), '~', 1)}" for d in dirs])
        paths = [d['path'] for d in dirs]
        if self.userdir in paths:
            self.userdir_drop.set_selected(paths.index(self.userdir))
        self.userdir_drop.set_visible(bool(dirs))
        self.filling = False

    def on_userdir(self, drop, _param):
        if getattr(self, 'filling', False) or self.busy:
            return
        dirs = self.st.get('userdirs', [])
        i = drop.get_selected()
        if 0 <= i < len(dirs) and dirs[i]['path'] != self.userdir:
            self.userdir = dirs[i]['path']
            self.refresh()

    def build_content(self):
        child = self.content.get_first_child()
        while child:
            nxt = child.get_next_sibling()
            self.content.remove(child)
            child = nxt
        self.action_buttons, self.rows = [], {}
        for cat, mods in model.sections(self.st):
            self.content.append(label(T(model.SECTION_KEYS[cat]), 'heading'))
            box = Gtk.ListBox(selection_mode=Gtk.SelectionMode.NONE)
            box.add_css_class('frame')
            for m in mods:
                box.append(self.module_row(m))
            self.content.append(box)
        if self.userdir:
            bar = Gtk.Box(spacing=8)
            # the "All" of the menu: install or update, reinstall and uninstall every module at once
            self.bulk = Gtk.Box(spacing=8, hexpand=True)
            for act, ids in model.bulk(self.st):
                b = button(T(model.BULK_KEYS[act]), self.start, act, ids)
                b.set_name(act + '-all')
                self.bulk.append(b)
                self.action_buttons.append(b)
            bar.append(self.bulk)
            n = len(self.st.get('backups', []))
            self.backups_button = button(T('gui.backups', n), self.show_backups)
            self.backups_button.set_sensitive(n > 0)
            self.check_button = button(T('gui.check'), self.start, 'check')
            self.check_button.set_sensitive(bool(self.st.get('can_check')))
            for b in (self.backups_button, self.check_button):
                bar.append(b)
                self.action_buttons.append(b)
            self.content.append(bar)
        # only in a clone of the repository (the release zip has no tests/)
        self.dev = None
        if self.st.get('clone'):
            self.content.append(label(T('gui.section_dev'), 'heading'))
            self.dev = Gtk.Box(spacing=8)
            for key, act in (('gui.test', 'test'), ('gui.build', 'build')):
                b = button(T(key), self.start, act)
                b.set_name(act)
                self.dev.append(b)
                self.action_buttons.append(b)
            self.content.append(self.dev)
        self.set_busy(self.busy)

    def module_row(self, m):
        row = Gtk.Box(spacing=12, margin_top=8, margin_bottom=8, margin_start=10, margin_end=10)
        text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2, hexpand=True)
        text.append(label(m['name'], 'heading'))
        text.append(label(m['description'], 'dim-label', wrap=True))
        status = label(model.status_text(m), 'caption')
        text.append(status)
        row.append(text)
        buttons = {}
        for act in model.actions(m):
            b = button(T(model.ACTION_KEYS[act]), self.start, act, m['id'])
            b.set_valign(Gtk.Align.CENTER)
            if act in ('install', 'update'):
                b.add_css_class('suggested-action')
            row.append(b)
            buttons[act] = b
            self.action_buttons.append(b)
        self.rows[m['id']] = {'status': status, 'buttons': buttons}
        return row

    # ---------- running an action ----------
    def set_busy(self, busy):
        self.busy = busy
        for b in self.action_buttons:
            if busy:
                b.set_sensitive(False)
            elif b is getattr(self, 'backups_button', None):
                b.set_sensitive(bool(self.st.get('backups')))
            elif b is getattr(self, 'check_button', None):
                b.set_sensitive(bool(self.st.get('can_check')))
            else:
                b.set_sensitive(True)
        self.refresh_button.set_sensitive(not busy)
        self.userdir_drop.set_sensitive(not busy)

    def start(self, action, target=None):
        if self.busy:
            return
        fd, self.events_path = tempfile.mkstemp(prefix='nbkit-ui-', suffix='.events')
        os.close(fd)
        self.events, self.run = model.EventFile(self.events_path), model.Run()
        argv = model.command(action, self.userdir, target)
        env = [f'{k}={v}' for k, v in model.child_env(self.events_path).items()]
        self.set_busy(True)
        self.result.set_text(T('gui.running'))
        self.progress.set_visible(True)
        self.progress.set_text('')
        self.progress.set_fraction(0)
        self.pulse_id = GLib.timeout_add(150, self.pulse)
        self.terminal.feed(('\x1b[?25h\r\n\x1b[1m$ nbkit ' + ' '.join(argv[2:]).replace(os.path.expanduser('~'), '~')
                            + '\x1b[0m\r\n').encode())
        self.terminal.spawn_async(Vte.PtyFlags.DEFAULT, model.ROOT, argv, env, GLib.SpawnFlags.DEFAULT,
                                  None, None, -1, None, self.on_spawned)
        self.poll_id = GLib.timeout_add(100, self.poll)
        self.terminal.grab_focus()

    def on_spawned(self, _terminal, pid, error, *_args):
        if error is not None or pid == -1:
            self.finish(127)

    def pulse(self):
        if self.run and self.run.fraction() is None:
            self.progress.pulse()
            return True
        self.pulse_id = 0
        return False

    def poll(self):
        if not self.events:
            return False
        for ev in self.events.read():
            kind = self.run.apply(ev)
            if kind == 'progress':
                self.progress.set_fraction(self.run.fraction())
                self.progress.set_text(self.run.progress_text())
            elif kind == 'ask':
                self.ask(self.run.question)
            elif kind == 'answered':
                self.close_question()
        return True

    def on_child_exited(self, _terminal, status):
        try:
            code = os.waitstatus_to_exitcode(status)
        except ValueError:
            code = status
        self.finish(code)

    def finish(self, code):
        if self.events:
            self.poll()
        for i in ('poll_id', 'pulse_id'):
            if getattr(self, i):
                GLib.source_remove(getattr(self, i))
                setattr(self, i, 0)
        self.close_question()
        if code == 0:
            self.progress.set_fraction(1)
        self.progress.set_text(self.run.progress_text() if self.run else '')
        self.result.set_text(model.result_text(code))
        self.terminal.feed(b'\x1b[?25l')
        self.last_code = code
        if self.events_path:
            try:
                os.unlink(self.events_path)
            except OSError:
                pass
        self.events = self.events_path = None
        self.set_busy(False)
        if self.closing:
            self.destroy()
            return
        self.refresh()

    # ---------- questions: a dialog that answers by typing in the terminal ----------
    def ask(self, q):
        self.close_question()
        d = Gtk.Window(title=T('gui.question'), transient_for=self, modal=True, resizable=False)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12, margin_top=16, margin_bottom=16,
                      margin_start=18, margin_end=18)
        if q['detail']:
            detail = label(q['detail'], 'monospace', wrap=True)
            box.append(detail)
        box.append(label(q['text'], 'heading', wrap=True))
        buttons = Gtk.Box(spacing=8, halign=Gtk.Align.END)
        no, yes = Gtk.Button(label=T('gui.no')), Gtk.Button(label=T('gui.yes'))
        no.connect('clicked', lambda _b: self.reply(False))
        yes.connect('clicked', lambda _b: self.reply(True))
        (yes if q['default_yes'] else no).add_css_class('suggested-action')
        buttons.append(no)
        buttons.append(yes)
        box.append(buttons)
        d.set_child(box)
        d.set_default_widget(yes if q['default_yes'] else no)
        # closing the dialog leaves the question in the terminal, to answer there
        d.connect('close-request', lambda _w: self.forget_question() or False)
        self.question = d
        self.question_buttons = {'yes': yes, 'no': no}
        d.present()

    def reply(self, yes):
        self.terminal.feed_child(model.answer(yes))
        self.close_question()

    def forget_question(self):
        self.question = None

    def close_question(self):
        if self.question is not None:
            d, self.question = self.question, None
            d.destroy()

    # ---------- backups ----------
    def show_backups(self):
        d = Gtk.Window(title=T('gui.backups_title'), transient_for=self, modal=True, default_width=560)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10, margin_top=14, margin_bottom=14,
                      margin_start=14, margin_end=14)
        names = {m['id']: m['name'] for m in self.st.get('modules', [])}
        lst = Gtk.ListBox(selection_mode=Gtk.SelectionMode.NONE)
        lst.add_css_class('frame')
        self.backup_rows = []
        for b in self.st.get('backups', []):
            row = Gtk.Box(spacing=10, margin_top=6, margin_bottom=6, margin_start=8, margin_end=8)
            text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, hexpand=True)
            top = f"{b['date']}   {b['size']}" + (f"   ({T('gui.original')})" if b['original'] else '')
            text.append(label(f"{names.get(b['module'], b['module'])}: {top}", 'heading'))
            text.append(label(b['description'], 'dim-label', wrap=True))
            row.append(text)
            restore = button(T('gui.restore'), self.backup_action, d, 'restore', b['file'])
            delete = button(T('gui.delete'), self.backup_action, d, 'delete-backup', b['file'])
            delete.add_css_class('destructive-action')
            for w in (restore, delete):
                w.set_valign(Gtk.Align.CENTER)
                row.append(w)
            lst.append(row)
            self.backup_rows.append({'file': b['file'], 'restore': restore, 'delete': delete})
        box.append(lst)
        close = button(T('gui.close'), d.destroy)
        close.set_halign(Gtk.Align.END)
        box.append(close)
        d.set_child(box)
        self.backups_window = d
        d.present()

    def backup_action(self, dialog, action, path):
        dialog.destroy()
        self.backups_window = None
        self.start(action, path)

    # ---------- about ----------
    def show_about(self):
        self.about = Gtk.AboutDialog(transient_for=self, modal=True, program_name='nbkit',
                                     version=self.st.get('version', ''), comments=T('gui.about_comments'),
                                     license_type=Gtk.License.MIT_X11, website=model.REPO + '#readme',
                                     website_label=model.REPO.replace('https://', ''),
                                     authors=['Gabriel Goes Santos Rios'],
                                     copyright='© 2026 Gabriel Goes Santos Rios', logo_icon_name='utilities-terminal')
        self.about.present()

    # ---------- closing ----------
    def on_close(self, _w):
        if not self.busy:
            return False
        # an action is running: Ctrl+C makes nbkit undo what it started, then the window closes
        self.closing = True
        self.terminal.feed_child(b'\x03')
        return True


def main():
    app = Gtk.Application(application_id='io.github.gaesyeah.nbkit', flags=Gio.ApplicationFlags.NON_UNIQUE)
    userdir = sys.argv[1] if len(sys.argv) > 1 else None
    apply_dark_preference()
    app.connect('activate', lambda a: Window(userdir, application=a).present())
    return app.run([sys.argv[0]])


if __name__ == '__main__':
    sys.exit(main())
