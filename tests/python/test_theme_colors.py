"""colors.toml: the color format and the NetBeans lines it becomes."""
import os
import tempfile
import unittest

import helpers
from theme_colors import ThemeError, parse_value, read_colors, to_xml


class ParseValue(unittest.TestCase):
    def test_text_color(self):
        self.assertEqual(parse_value('#61AFEF'), ({'foreColor': 'ff61afef'}, None))

    def test_every_part_in_any_order(self):
        attrs, style = parse_value('bold italic wave #c24038 on #282c34 #e06c75 inherits comment underline #111111 strike #222222')
        self.assertEqual(style, 'bold+italic')
        self.assertEqual(attrs, {'foreColor': 'ffe06c75', 'bgColor': 'ff282c34', 'waveUnderlined': 'ffc24038',
                                 'underline': 'ff111111', 'strikeThrough': 'ff222222', 'default': 'comment'})

    def test_styles(self):
        for text, style in (('bold', 'bold'), ('italic', 'italic'), ('plain', 'plain'), ('bold italic', 'bold+italic')):
            self.assertEqual(parse_value(text)[1], style)

    def test_empty_value_is_allowed(self):
        self.assertEqual(parse_value(''), ({}, None))

    def test_errors(self):
        cases = {'#abb2bf on 282c34': 'theme.color_expected', '#c678dd bolt': 'theme.unknown_word',
                 '#111111 #222222': 'theme.color_twice', 'inherits': 'theme.token_expected', 'wave': 'theme.color_expected'}
        for text, key in cases.items():
            with self.subTest(text=text), self.assertRaises(ThemeError) as e:
                parse_value(text)
            self.assertEqual(e.exception.args[0], key)


class ToXml(unittest.TestCase):
    def test_attribute_order_and_style(self):
        self.assertEqual(to_xml('keyword', {'foreColor': 'ffc678dd', 'default': 'x'}, 'bold'),
                         '<fontcolor name="keyword" default="x" foreColor="ffc678dd"><font style="bold"/></fontcolor>')
        self.assertEqual(to_xml('x', {}, None), '<fontcolor name="x"/>')


class ReadColors(unittest.TestCase):
    def read(self, text):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, 'colors.toml')
            helpers.write(p, text)
            return read_colors(p)

    def test_places(self):
        got = self.read('[all]\ndefault = "#abb2bf"\n[highlights]\nselection = "on #3e4451"\n'
                        '["text/css"]\nkeyword = "#c678dd"\n["text/css".extra]\nnbkit-unit = "#d19a66"\n')
        self.assertEqual([p for p, _ in got], ['all', 'highlights', 'text/css', 'text/css extra'])
        self.assertEqual(got[3][1], [('nbkit-unit', '<fontcolor name="nbkit-unit" foreColor="ffd19a66"/>')])

    def test_error_points_at_table_and_line(self):
        with self.assertRaises(ThemeError) as e:
            self.read('[all]\nkeyword = "#c678dd"\n\n["text/x-java"]\nkeyword = "#c678dd bolt"\n')
        self.assertEqual(e.exception.args, ('theme.unknown_word', ('bolt',), 'text/x-java / keyword', 5))

    def test_value_must_be_text(self):
        with self.assertRaises(ThemeError) as e:
            self.read('[all]\nx = 3\n')
        self.assertEqual(e.exception.args[0], 'theme.not_text')

    def test_extra_only_under_a_language(self):
        with self.assertRaises(ThemeError):
            self.read('[all.extra]\nx = "#ffffff"\n')

    def test_toml_syntax_error(self):
        with self.assertRaises(ThemeError) as e:
            self.read('[all]\ndefault = "#abb2bf"\ndefault = "#ffffff"\n')
        self.assertEqual(e.exception.args[0], 'theme.toml_syntax')

    def test_one_dark_pro_mix_reads_without_errors(self):
        got = read_colors(os.path.join(helpers.ROOT, 'modules', 'themes', 'one-dark-pro-mix', 'colors.toml'))
        self.assertGreater(sum(len(items) for _, items in got), 250)


if __name__ == '__main__':
    unittest.main()
