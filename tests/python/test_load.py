"""theme.toml and module.toml: what is registered and what is skipped, with the reason."""
import os
import tempfile
import unittest

import helpers


def theme(root, tid, toml, colors='[all]\ndefault = "#ffffff"\n', ui='@background=#000000\n'):
    d = os.path.join(root, tid)
    helpers.write(os.path.join(d, 'theme.toml'), toml)
    if colors is not None:
        helpers.write(os.path.join(d, 'colors.toml'), colors)
    if ui is not None:
        helpers.write(os.path.join(d, 'ui.properties'), ui)


class Themes(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def load(self):
        rc, out, err = helpers.run('themes/load.py', self.root)
        self.assertEqual(rc, 0, err)
        return out

    def test_minimal_theme(self):
        theme(self.root, 'my-theme', '[theme]\nname = "My Theme"\nversion = 3\n')
        out = self.load()
        self.assertIn("theme_register my-theme th_my_theme 'My Theme' '' 3", out)
        self.assertIn("THEME_PROFILE='My Theme'", out)

    def test_texts_by_language_and_terminal_color(self):
        theme(self.root, 'x', '[theme]\nname = "X"\nversion = 1\ndescription = { en = "English", pt-BR = "Português" }\n'
                              '[terminal]\nselection = "#41454e"\n')
        out = self.load()
        self.assertIn(' English ', out)
        self.assertNotIn('Português', out)
        self.assertIn('THEME_TERMINAL_SELECTION=-12499634', out)

    def test_font_and_base(self):
        theme(self.root, 'x', '[theme]\nname = "X"\nversion = 1\n[font]\nname = "Fira Code"\nurls = ["https://a/b.ttf"]\n'
                              '[base]\nfolder = "FlatLafLight"\n')
        out = self.load()
        self.assertIn("THEME_FONT_NAME='Fira Code'", out)
        self.assertIn('THEME_FONT_DIR=FiraCode', out)
        self.assertIn("THEME_FONT_URLS=(https://a/b.ttf)", out)
        self.assertIn('THEME_BASE=FlatLafLight', out)

    def test_legacy(self):
        theme(self.root, 'x', '[theme]\nname = "X"\nversion = 1\n[legacy]\nversion_file = "old-version"\n')
        self.assertIn('x_legacy_version() {', self.load().replace('th_x', 'x'))

    def test_skipped_with_reason(self):
        cases = {
            'no-name': ('[theme]\nversion = 1\n', '"theme.name" is missing in theme.toml'),
            'bad-version': ('[theme]\nname = "X"\nversion = "1"\n', 'invalid value for "theme.version"'),
            'Bad_Id': ('[theme]\nname = "X"\nversion = 1\n', 'only have lowercase letters'),
            'bad-terminal': ('[theme]\nname = "X"\nversion = 1\n[terminal]\nselection = "41454e"\n', 'terminal.selection'),
            'bad-colors': ('[theme]\nname = "X"\nversion = 1\n', 'unknown word: "itallic" (in all / comment, line 2)'),
        }
        for tid, (toml, _) in cases.items():
            theme(self.root, tid, toml, colors='[all]\ncomment = "#6a9955 itallic"\n' if tid == 'bad-colors' else '[all]\n')
        theme(self.root, 'no-ui', '[theme]\nname = "X"\nversion = 1\n', ui=None)
        theme(self.root, 'good', '[theme]\nname = "Good"\nversion = 1\n')
        out = self.load()
        for tid, (_, reason) in cases.items():
            with self.subTest(theme=tid):
                self.assertIn(f'theme "{tid}" skipped', out)
                self.assertIn(reason, out)
        self.assertIn('file ui.properties is missing', out)
        self.assertIn('theme_register good', out)

    def test_real_theme_loads(self):
        rc, out, err = helpers.run('themes/load.py', os.path.join(helpers.ROOT, 'modules', 'themes'))
        self.assertEqual(rc, 0, err)
        self.assertIn('theme_register one-dark-pro-mix', out)
        self.assertNotIn('skipped', out)


class Modules(unittest.TestCase):
    def test_real_module_loads(self):
        rc, out, err = helpers.run('modules.py', os.path.join(helpers.ROOT, 'modules'))
        self.assertEqual(rc, 0, err)
        self.assertIn("nbmod_register jsf nm_jsf 'JSF checks'", out)

    def test_skipped_with_reason(self):
        with tempfile.TemporaryDirectory() as root:
            helpers.write(os.path.join(root, 'a', 'module.toml'), '[module]\nname = "A"\nversion = 1\njar = "a.jar"\ncodename = "a.b"\n')
            helpers.write(os.path.join(root, 'b', 'module.toml'),
                          '[module]\nname = "B"\nversion = 1\njar = "b.jar"\ncodename = "b.c"\nsha256 = "' + '0' * 64 + '"\n')
            rc, out, _ = helpers.run('modules.py', root)
        self.assertIn('module "a" skipped: "sha256" is missing in module.toml', out)
        self.assertIn('module "b" skipped: file b.jar is missing', out)


if __name__ == '__main__':
    unittest.main()
