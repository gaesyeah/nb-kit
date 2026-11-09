"""lang/*.lang: same keys and placeholders in every language, and every key the code uses exists."""
import glob
import os
import re
import unittest

import helpers


def load(path):
    out = {}
    with open(path, encoding='utf-8') as f:
        lines = f.readlines()
    for line in lines:
        line = line.rstrip('\n')
        if line and not line.startswith('#'):
            k, v = line.split('=', 1)
            out[k] = v
    return out


LANGS = {os.path.basename(p)[:-5]: load(p) for p in glob.glob(os.path.join(helpers.ROOT, 'lang', '*.lang'))}
REF = LANGS['pt-BR']


class Lang(unittest.TestCase):
    def test_same_keys(self):
        for name, texts in LANGS.items():
            with self.subTest(lang=name):
                self.assertEqual(sorted(set(REF) - set(texts)), [], 'missing')
                self.assertEqual(sorted(set(texts) - set(REF)), [], 'not in pt-BR')

    def test_same_placeholders(self):
        for name, texts in LANGS.items():
            for k, v in texts.items():
                with self.subTest(lang=name, key=k):
                    # %s keep their order; {named} marks may move
                    self.assertEqual(re.findall(r'%[s%]', v), re.findall(r'%[s%]', REF[k]))
                    self.assertEqual(sorted(re.findall(r'\{[A-Za-z]+\}', v)), sorted(re.findall(r'\{[A-Za-z]+\}', REF[k])))

    def test_every_key_used_exists(self):
        code = ''
        for p in glob.glob(os.path.join(helpers.ROOT, '**', '*.sh'), recursive=True) + \
                 glob.glob(os.path.join(helpers.ROOT, 'lib', '**', '*.py'), recursive=True):
            if '/tests/' not in p:
                with open(p, encoding='utf-8') as f:
                    code += f.read()
        used = set(re.findall(r'\bt ((?:cli|theme|mod|build)\.[a-z_]+)', code))
        used |= set(re.findall(r"""['"]((?:cli|theme|mod|build)\.[a-z_]+)['"]""", code))
        used -= {'theme.toml', 'module.toml'}   # file names, not keys
        self.assertGreater(len(used), 100)
        self.assertEqual(sorted(used - set(REF)), [])


if __name__ == '__main__':
    unittest.main()
