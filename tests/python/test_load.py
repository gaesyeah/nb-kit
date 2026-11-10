"""theme.toml and tool.toml: what is registered and what is skipped, with the reason."""
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


class Tools(unittest.TestCase):
    SHA = '0' * 64

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def tool(self, tid, toml, files=()):
        helpers.write(os.path.join(self.root, tid, 'tool.toml'), toml)
        for f in files:
            helpers.write(os.path.join(self.root, tid, f), '')

    def load(self):
        rc, out, err = helpers.run('tools/load.py', self.root)
        self.assertEqual(rc, 0, err)
        return out

    def test_real_tool_loads(self):
        rc, out, err = helpers.run('tools/load.py', os.path.join(helpers.ROOT, 'modules', 'tools'))
        self.assertEqual(rc, 0, err)
        self.assertIn("tool_register jsf 'JSF checks'", out)
        self.assertIn('nbkit-jsf.jar nbkit.jsf', out)
        self.assertNotIn('skipped', out)

    def test_netbeans_module_tool(self):
        self.tool('a', f'[tool]\nname = "A"\nversion = 2\nhint = {{ en = "Hint", pt-BR = "Dica" }}\n'
                       f'[netbeans_module]\njar = "a.jar"\ncodename = "a.b"\nsha256 = "{self.SHA}"\n', ['a.jar'])
        out = self.load()
        self.assertIn("tool_register a A '' 2 ", out)
        self.assertIn(f' Hint a.jar a.b {self.SHA} ', out)
        self.assertNotIn('source', out)

    def test_tool_sh_is_loaded_after_registering(self):
        self.tool('b', '[tool]\nname = "B"\nversion = 1\n', ['tool.sh'])
        out = self.load().splitlines()
        self.assertTrue(out[0].startswith('tool_register b B'), out)
        self.assertEqual(out[1], 'source ' + os.path.join(self.root, 'b', 'tool.sh'))

    def test_skipped_with_reason(self):
        cases = {
            'no-version': ('[tool]\nname = "X"\n', '"tool.version" is missing in tool.toml'),
            'no-sha': ('[tool]\nname = "X"\nversion = 1\n[netbeans_module]\njar = "x.jar"\ncodename = "a.b"\n',
                       '"netbeans_module.sha256" is missing in tool.toml'),
            'bad-sha': ('[tool]\nname = "X"\nversion = 1\n[netbeans_module]\njar = "x.jar"\ncodename = "a.b"\nsha256 = "abc"\n',
                        'invalid value for "netbeans_module.sha256"'),
            'no-jar': (f'[tool]\nname = "X"\nversion = 1\n[netbeans_module]\njar = "x.jar"\ncodename = "a.b"\nsha256 = "{self.SHA}"\n',
                       'file x.jar is missing'),
            'nothing': ('[tool]\nname = "X"\nversion = 1\n', 'the tool installs nothing'),
            'Bad_Id': ('[tool]\nname = "X"\nversion = 1\n', 'only have lowercase letters'),
        }
        for tid, (toml, _) in cases.items():
            self.tool(tid, toml)
        self.tool('good', '[tool]\nname = "Good"\nversion = 1\n', ['tool.sh'])
        out = self.load()
        for tid, (_, reason) in cases.items():
            with self.subTest(tool=tid):
                self.assertIn(f'tool "{tid}" skipped', out)
                self.assertIn(reason, out)
        self.assertIn('tool_register good', out)


if __name__ == '__main__':
    unittest.main()
