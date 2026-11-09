"""Texts of lang/<language>.lang for the Python parts (nbkit passes the files in NBKIT_LANG_FILES)."""
import os

_TEXTS = None
def T(key, *args):
    """Text of the key in lang/<language>.lang (nbkit passes the files in NBKIT_LANG_FILES, one per line)."""
    global _TEXTS
    if _TEXTS is None:
        _TEXTS = {}
        for path in os.environ.get('NBKIT_LANG_FILES', '').split('\n'):
            if path and os.path.exists(path):
                for line in open(path, encoding='utf-8'):
                    line = line.rstrip('\n')
                    if line and not line.startswith('#') and '=' in line:
                        k, v = line.split('=', 1)
                        _TEXTS[k] = v
    text = _TEXTS.get(key, key).replace('\\n', '\n')
    return text % args if args else text.replace('%%', '%')
