"""lib/themes/backup_detail.py: what is specific to a theme backup read from its extracted files, classified
against the NetBeans defaults (or not, when there is no installation to compare with)."""
import os
import tempfile
import unittest
from unittest.mock import patch

import helpers
import backup_detail as bd

LAF_HEADER = '# One Dark Pro Mix\n'
COLOR_XML = ('<?xml version="1.0" encoding="UTF-8"?>\n<fontscolors>\n%s\n</fontscolors>\n')


def color(name, **attrs):
    a = ''.join(f' {k}="{v}"' for k, v in attrs.items())
    return f'    <fontcolor name="{name}"{a}/>'


class Cap(unittest.TestCase):
    def test_ten_or_fewer_is_not_truncated(self):
        self.assertEqual(bd.cap(list(range(10))), (list(range(10)), 0))

    def test_more_than_ten_is_capped_with_a_count(self):
        shown, more = bd.cap(list(range(15)))
        self.assertEqual((shown, more), (list(range(10)), 5))

    def test_list_lines_adds_the_and_more_line_only_when_truncated(self):
        self.assertEqual(bd.list_lines(['a', 'b']), ['a', 'b'])
        self.assertEqual(bd.list_lines([str(i) for i in range(12)]), [str(i) for i in range(10)] + ['… and 2 more'])


class UiSection(unittest.TestCase):
    def write(self, text):
        d = tempfile.mkdtemp()
        p = os.path.join(d, 'FlatDarkLaf.properties')
        helpers.write(p, text)
        return p

    def test_no_file_is_nothing_to_report(self):
        self.assertEqual(bd.ui_section('/does/not/exist'), [])

    def test_one_key_of_yours_is_singular(self):
        self.assertEqual(bd.ui_section(self.write('@myKey=#123456\n')),
                         ['1 key of yours in the interface, from before nbkit', '  @myKey=#123456'])

    def test_two_keys_of_yours_is_plural(self):
        lines = bd.ui_section(self.write('@myKey=#123456\nComponent.arc=8\n'))
        self.assertEqual(lines[0], '2 keys of yours in the interface, from before nbkit')
        self.assertEqual(lines[1:], ['  @myKey=#123456', '  Component.arc=8'])

    def test_the_old_installer_mark_is_told_apart_from_yours(self):
        lines = bd.ui_section(self.write('# One Dark Pro Mix\n@myKey=#123456\n'))
        self.assertEqual(lines[0], 'these interface keys came from the old installer')

    def test_more_than_ten_keys_are_capped(self):
        text = ''.join(f'k{i}=v{i}\n' for i in range(12))
        lines = bd.ui_section(self.write(text))
        self.assertEqual(lines[0], '12 keys of yours in the interface, from before nbkit')
        self.assertEqual(lines[-1], '  … and 2 more')
        self.assertEqual(len(lines), 1 + 10 + 1)


class ColorSections(unittest.TestCase):
    def manifest(self, root, rows):
        """rows: [(legacy, mime, type, filename, xml)], written under root and listed in the manifest"""
        path = os.path.join(root, 'manifest')
        with open(path, 'w') as f:
            for legacy, mime, typ, fn, xml in rows:
                helpers.write(os.path.join(root, fn), COLOR_XML % xml)
                f.write(f'{legacy}\t{mime}\t{typ}\t{fn}\n')
        return path

    def test_no_manifest_file_is_nothing_to_report(self):
        self.assertEqual(bd.color_sections('/u', '/root', 'FlatLafDark', '/no/such/manifest'), [])

    def test_without_an_installation_the_old_installer_is_still_only_counted(self):
        root = tempfile.mkdtemp()
        manifest = self.manifest(root, [
            ('1', '', 'token', 'legacy.xml', color('keyword', foreColor='ff61afef')),
            ('0', 'text/x-java', 'token', 'mine.xml', color('comment', foreColor='ff5c6370')),
        ])
        with patch.object(bd, 'Jars', lambda ud: type('J', (), {'paths': []})()):
            out = bd.color_sections('/u', root, 'FlatLafDark', manifest)
        self.assertIn("no NetBeans installation to compare with: can't tell your colors from the old installer's "
                      "with certainty", out)
        self.assertIn('1 color from the old installer, discarded automatically when the theme installs', out)
        self.assertNotIn('keyword', '\n'.join(out))          # the old installer's: counted, never listed
        self.assertIn('1 color of yours, different from FlatLaf Dark', out)
        self.assertIn('  text/x-java: comment: foreColor=ff5c6370', out)  # the language tells repeated names apart

    def test_an_entry_identical_to_the_netbeans_default_is_not_reported(self):
        root = tempfile.mkdtemp()
        manifest = self.manifest(root, [
            ('0', '', 'token', 'mine.xml', color('default', foreColor='ffa9b7c6', bgColor='ff2b2b2b') + '\n' +
             color('comment', foreColor='ff5c6370')),
        ])

        class FakeJars:
            def __init__(self, ud):
                self.paths = ['fake.jar']

        def fake_base_profile(jars, base):
            return [('', 'stock-tokenColorings.xml', 'token',
                     (COLOR_XML % color('default', foreColor='ffa9b7c6', bgColor='ff2b2b2b')).encode())]
        with patch.object(bd, 'Jars', FakeJars), patch.object(bd, 'base_profile', fake_base_profile):
            out = bd.color_sections('/u', root, 'FlatLafDark', manifest)
        joined = '\n'.join(out)
        self.assertNotIn('default:', joined)                     # identical to the NetBeans default: not a change
        self.assertIn('all: comment: foreColor=ff5c6370', joined)  # not in the defaults at all: yours; base profile: "all"
        self.assertIn('compared with the FlatLaf Dark defaults', joined)

    def test_more_than_ten_colors_of_yours_are_capped(self):
        root = tempfile.mkdtemp()
        rows = [('0', '', 'token', f'c{i}.xml', color(f'tok{i}', foreColor='ff112233')) for i in range(12)]
        manifest = self.manifest(root, rows)

        class FakeJars:
            def __init__(self, ud):
                self.paths = ['fake.jar']
        with patch.object(bd, 'Jars', FakeJars), patch.object(bd, 'base_profile', lambda jars, base: []):
            out = bd.color_sections('/u', root, 'FlatLafDark', manifest)
        self.assertEqual(out[1], '12 colors of yours, different from FlatLaf Dark')
        self.assertEqual(out[2], '  all: tok0: foreColor=ff112233')
        self.assertEqual(out[-1], '  … and 2 more')

    def test_the_old_installers_colors_are_only_counted_never_listed(self):
        root = tempfile.mkdtemp()
        rows = [('1', '', 'token', f'c{i}.xml', color(f'tok{i}', foreColor='ff112233')) for i in range(15)]
        manifest = self.manifest(root, rows)

        class FakeJars:
            def __init__(self, ud):
                self.paths = ['fake.jar']
        with patch.object(bd, 'Jars', FakeJars), patch.object(bd, 'base_profile', lambda jars, base: []):
            out = bd.color_sections('/u', root, 'FlatLafDark', manifest)
        self.assertEqual(out[1], '15 colors from the old installer, discarded automatically when the theme installs')
        self.assertNotIn('tok', '\n'.join(out))
        self.assertNotIn('… and', '\n'.join(out))


class FontSection(unittest.TestCase):
    def test_no_font_in_the_backup_is_nothing_to_report(self):
        root = tempfile.mkdtemp()
        helpers.write(os.path.join(root, 'config/Editors/FontsColors/FlatLafDark/x-tokenColorings.xml'),
                     COLOR_XML % color('default', foreColor='ffa9b7c6'))
        self.assertEqual(bd.font_section(root, 'FlatLafDark', 'x'), [])

    def test_the_font_held_by_the_backup_is_read_through_nbfiles(self):
        root = tempfile.mkdtemp()
        xml = '<fontcolor name="default"><font name="Fira Code" size="15"/></fontcolor>'
        helpers.write(os.path.join(root, 'config/Editors/FontsColors/FlatLafDark/x-tokenColorings.xml'),
                     COLOR_XML % xml)
        self.assertEqual(bd.font_section(root, 'FlatLafDark', 'x'), ['editor font in this backup: Fira Code 15'])


if __name__ == '__main__':
    unittest.main()
