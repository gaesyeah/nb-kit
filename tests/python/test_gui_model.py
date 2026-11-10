"""lib/gui/model.py: what the interface shows and does, without a screen."""
import os
import subprocess
import tempfile
import unittest

import helpers
from gui import model

THEME = {'id': 'one-dark-pro-mix', 'category': 'theme', 'name': 'One Dark Pro Mix', 'version': '29', 'status': 'no', 'installed': None}
JSF = {'id': 'jsf', 'category': 'tool', 'name': 'JSF checks', 'version': '2', 'status': 'ok', 'installed': '2'}


def mod(base, **kw):
    return dict(base, **kw)


class Status(unittest.TestCase):
    def test_tools_come_before_themes(self):
        self.assertEqual([c for c, _ in model.sections({'modules': [THEME, JSF]})], ['tool', 'theme'])
        self.assertEqual(model.sections({'modules': []}), [])

    def test_status_text(self):
        self.assertEqual(model.status_text(THEME), 'not installed')
        self.assertEqual(model.status_text(JSF), 'installed (v2)')
        self.assertEqual(model.status_text(mod(THEME, status='old', installed='27')), 'outdated: v27, available v29')
        self.assertEqual(model.status_text(mod(THEME, status='old')), 'old version, available v29')
        self.assertEqual(model.status_text(mod(JSF, status='new', installed='5')), 'newer than this nbkit (v5)')

    def test_every_section_and_button_has_a_text(self):
        for key in list(model.SECTION_KEYS.values()) + list(model.ACTION_KEYS.values()):
            self.assertNotEqual(model.T(key), key)

    def test_buttons_follow_the_status(self):
        self.assertEqual(model.actions(THEME), ['install'])
        self.assertEqual(model.actions(mod(THEME, status='old', installed='27')), ['update', 'uninstall'])
        self.assertEqual(model.actions(JSF), ['reinstall', 'uninstall'])
        self.assertEqual(model.actions(mod(JSF, status='new')), ['reinstall', 'uninstall'])

    def test_status_runs_nbkit(self):
        calls = []

        def run(argv, **kw):
            calls.append((argv, kw['env']))
            return subprocess.CompletedProcess(argv, 0, '{"userdir": "/u", "modules": []}', '')
        os.environ['NBKIT_UI_EVENTS'] = '/tmp/leftover'
        try:
            self.assertEqual(model.status('/u', run=run)['userdir'], '/u')
        finally:
            del os.environ['NBKIT_UI_EVENTS']
        argv, env = calls[0]
        self.assertEqual(argv[1:], [model.NBKIT, 'status', '--json', '/u'])
        self.assertNotIn('NBKIT_UI_EVENTS', env)       # status must not write events of an old action

    def test_status_errors(self):
        def failing(argv, **kw):
            return subprocess.CompletedProcess(argv, 1, '', '\x1b[31mError:\x1b[0m userdir not found')

        def garbage(argv, **kw):
            return subprocess.CompletedProcess(argv, 0, 'not json', '')
        with self.assertRaisesRegex(model.StatusError, '^Error: userdir not found$'):
            model.status(run=failing)
        with self.assertRaises(model.StatusError):
            model.status(run=garbage)


class Look(unittest.TestCase):
    def test_dark_preference(self):
        self.assertTrue(model.prefers_dark(1, None))
        self.assertFalse(model.prefers_dark(2, 'prefer-dark'))       # the portal wins
        self.assertTrue(model.prefers_dark(0, 'prefer-dark'))        # no preference in the portal: GNOME
        self.assertTrue(model.prefers_dark(None, 'prefer-dark'))
        self.assertFalse(model.prefers_dark(None, 'default'))
        self.assertFalse(model.prefers_dark())

    def test_terminal_palette(self):
        self.assertEqual(len(model.PALETTE), 16)
        for c in model.PALETTE:
            self.assertRegex(c, r'^#[0-9a-f]{6}$')


class AllAtOnce(unittest.TestCase):
    OTHER = {'id': 'other-theme', 'category': 'theme', 'name': 'Other', 'version': '1', 'status': 'no', 'installed': None}

    def test_install_takes_what_is_missing_or_outdated(self):
        st = {'modules': [THEME, mod(JSF, status='old', installed='1')]}
        self.assertEqual(model.bulk(st), [('install', ['one-dark-pro-mix', 'jsf'])])

    def test_one_theme_at_a_time(self):
        st = {'modules': [THEME, self.OTHER, mod(JSF, status='no', installed=None)]}
        self.assertEqual(model.bulk(st), [('install', ['one-dark-pro-mix', 'jsf'])])

    def test_reinstall_and_uninstall_when_all_are_installed(self):
        st = {'modules': [mod(THEME, status='ok', installed='29'), JSF]}
        self.assertEqual(model.bulk(st), [('reinstall', ['one-dark-pro-mix', 'jsf']), ('uninstall', ['one-dark-pro-mix', 'jsf'])])

    def test_no_button_for_a_single_module(self):
        self.assertEqual(model.bulk({'modules': [THEME, JSF]}), [])
        self.assertEqual(model.bulk({}), [])

    def test_every_button_has_a_text(self):
        for key in model.BULK_KEYS.values():
            self.assertNotEqual(model.T(key), key)


class Commands(unittest.TestCase):
    def test_argv(self):
        self.assertEqual(model.NBKIT, os.path.join(helpers.ROOT, 'nbkit.sh'))
        n = ['bash', model.NBKIT]
        self.assertEqual(model.command('install', '/u', 'jsf'), n + ['install', 'jsf', '/u'])
        self.assertEqual(model.command('update', '/u', 'jsf'), n + ['install', 'jsf', '/u'])
        self.assertEqual(model.command('reinstall', '/u', 'jsf'), n + ['install', 'jsf', '/u'])
        self.assertEqual(model.command('uninstall', '/u', 'jsf'), n + ['uninstall', 'jsf', '/u'])
        self.assertEqual(model.command('install', '/u', ['a', 'b']), n + ['install', 'a', 'b', '/u'])
        self.assertEqual(model.command('check', '/u'), n + ['check', '/u'])
        self.assertEqual(model.command('restore', '/u', '/u/b.tar.gz'), n + ['restore', '/u/b.tar.gz', '/u'])
        self.assertEqual(model.command('test', '/u'), n + ['test'])
        self.assertEqual(model.command('build', '/u'), n + ['build'])

    def test_env_of_an_action(self):
        env = model.child_env('/tmp/e')
        self.assertEqual((env['NBKIT_TTY'], env['NBKIT_UI_EVENTS']), ('1', '/tmp/e'))

    def test_answers_work_in_every_language(self):
        self.assertEqual((model.answer(True), model.answer(False)), (b'y\n', b'n\n'))


class Events(unittest.TestCase):
    def setUp(self):
        fd, self.path = tempfile.mkstemp()
        os.close(fd)
        self.addCleanup(os.unlink, self.path)
        self.events = model.EventFile(self.path)

    def write(self, text):
        with open(self.path, 'a', encoding='utf-8') as f:
            f.write(text)

    def test_reads_only_new_complete_lines(self):
        self.assertEqual(self.events.read(), [])
        self.write('{"ev":"step","n":1,"total":3,"text":"a"}\n{"ev":"ste')
        self.assertEqual([e['n'] for e in self.events.read()], [1])
        self.write('p","n":2,"total":3,"text":"b"}\n')
        self.assertEqual([e['n'] for e in self.events.read()], [2])
        self.assertEqual(self.events.read(), [])

    def test_ignores_what_is_not_an_event(self):
        self.write('garbage\n[1]\n{"no":"ev"}\n{"ev":"answered"}\n')
        self.assertEqual(self.events.read(), [{'ev': 'answered'}])

    def test_missing_file(self):
        self.assertEqual(model.EventFile('/nonexistent/x').read(), [])

    def test_same_format_as_the_python_parts(self):
        import uievents
        os.environ['NBKIT_UI_EVENTS'] = self.path
        try:
            uievents.event(ev='ask', text='Keep?', detail='a\nb', default='N')
        finally:
            del os.environ['NBKIT_UI_EVENTS']
        self.assertEqual(self.events.read(), [{'ev': 'ask', 'text': 'Keep?', 'detail': 'a\nb', 'default': 'N'}])


class Running(unittest.TestCase):
    def test_progress(self):
        r = model.Run()
        self.assertIsNone(r.fraction())                 # pulses until the first step
        self.assertEqual(r.progress_text(), '')
        self.assertEqual(r.apply({'ev': 'step', 'n': 3, 'total': 9, 'text': 'x'}), 'progress')
        self.assertAlmostEqual(r.fraction(), 3 / 9)
        self.assertEqual(r.progress_text(), '3/9')
        r.apply({'ev': 'step', 'n': 10, 'total': 9})
        self.assertEqual(r.fraction(), 1)
        self.assertIsNone(r.apply({'ev': 'step', 'n': 'x', 'total': 9}))

    def test_question_opens_and_closes(self):
        r = model.Run()
        self.assertEqual(r.apply({'ev': 'ask', 'text': '\x1b[1mClose NetBeans?\x1b[0m', 'default': 'Y'}), 'ask')
        self.assertEqual(r.question, {'text': 'Close NetBeans?', 'detail': '', 'default_yes': True})
        self.assertEqual(r.apply({'ev': 'answered'}), 'answered')
        self.assertIsNone(r.question)
        self.assertIsNone(r.apply({'ev': 'other'}))

    def test_result(self):
        self.assertEqual(model.result_text(0), 'Done')
        self.assertEqual(model.result_text(130), 'Finished with an error (code 130)')


if __name__ == '__main__':
    unittest.main()
