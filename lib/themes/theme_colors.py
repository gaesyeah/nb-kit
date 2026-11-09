"""colors.toml -> NetBeans <fontcolor> lines."""
import re
import tomllib


COLOR = re.compile(r'#([0-9a-fA-F]{6})$')
STYLES = {'plain': 'plain', 'bold': 'bold', 'italic': 'italic'}
ORDER = ('default', 'foreColor', 'bgColor', 'underline', 'strikeThrough', 'waveUnderlined')
FIXED = ('all', 'highlights', 'annotations')


class ThemeError(Exception):
    """(key of the text in lang/, (values...), place or None, line or None)"""
    def __init__(self, key, values=(), place=None, line=None):
        super().__init__(key, values, place, line)


def parse_value(value):
    """'#61afef on #282c34 bold wave #c24038 inherits comment' -> (attributes, style)"""
    words = value.split()
    attrs, style, i = {}, None, 0

    def color(j, after):
        if j >= len(words) or not COLOR.match(words[j]):
            raise ThemeError('theme.color_expected', (after,))
        return 'ff' + words[j][1:].lower()

    while i < len(words):
        w = words[i]
        if COLOR.match(w):
            if 'foreColor' in attrs:
                raise ThemeError('theme.color_twice', (w,))
            attrs['foreColor'] = color(i, w)
            i += 1
        elif w == 'on':
            attrs['bgColor'] = color(i + 1, w)
            i += 2
        elif w in ('underline', 'wave', 'strike'):
            key = {'underline': 'underline', 'wave': 'waveUnderlined', 'strike': 'strikeThrough'}[w]
            attrs[key] = color(i + 1, w)
            i += 2
        elif w == 'bold' and i + 1 < len(words) and words[i + 1] == 'italic':
            style = 'bold+italic'
            i += 2
        elif w in STYLES:
            style = STYLES[w]
            i += 1
        elif w == 'inherits':
            if i + 1 >= len(words):
                raise ThemeError('theme.token_expected', (w,))
            attrs['default'] = words[i + 1]
            i += 2
        else:
            raise ThemeError('theme.unknown_word', (w,))
    return attrs, style


def to_xml(name, attrs, style):
    a = ''.join(f' {k}="{attrs[k]}"' for k in ORDER if k in attrs)
    if style:
        return f'<fontcolor name="{name}"{a}><font style="{style}"/></fontcolor>'
    return f'<fontcolor name="{name}"{a}/>'


def key_lines(path):
    """(table, key) -> line number, to point at the error"""
    lines, table = {}, ''
    with open(path, encoding='utf-8') as f:
        text = f.read().splitlines()
    for n, l in enumerate(text, 1):
        h = re.match(r'\s*\[\s*(.+?)\s*\]\s*(#.*)?$', l)
        if h:
            table = '.'.join(p.strip().strip('"') for p in re.findall(r'"[^"]*"|[^.]+', h.group(1)))
            continue
        m = re.match(r'\s*("([^"]+)"|[A-Za-z0-9_-]+)\s*=', l)
        if m:
            lines.setdefault((table, m.group(2) or m.group(1)), n)
    return lines


def read_colors(path):
    """reads colors.toml: list of (place, [(name, xml)]); place = all | highlights | annotations | <mime> | <mime> extra"""
    try:
        with open(path, 'rb') as f:
            data = tomllib.load(f)
    except tomllib.TOMLDecodeError as e:
        raise ThemeError('theme.toml_syntax', (str(e),))
    lines = key_lines(path)
    out = []

    def items(place, table, prefix):
        got = []
        for name, value in table.items():
            if isinstance(value, dict):
                continue
            where = lines.get((prefix, name), '?')
            if not isinstance(value, str):
                raise ThemeError('theme.not_text', (), f'{place} / {name}', where)
            try:
                attrs, style = parse_value(value)
            except ThemeError as e:
                raise ThemeError(e.args[0], e.args[1], f'{place} / {name}', where)
            got.append((name, to_xml(name, attrs, style)))
        out.append((place, got))

    for key, table in data.items():
        if not isinstance(table, dict):
            raise ThemeError('theme.not_table', (key,), None, lines.get(('', key)))
        items(key, table, key)
        for sub, value in table.items():
            if isinstance(value, dict):
                if sub != 'extra' or key in FIXED:
                    raise ThemeError('theme.not_table', (f'{key}.{sub}',))
                items(f'{key} extra', value, f'{key}.extra')
    return out
