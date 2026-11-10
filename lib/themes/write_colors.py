"""Writes the colors of colors.toml as NetBeans color files."""
import os
import sys

from nbfiles import FONTSCOLORS_HEADER as HDR
from text import T
from theme_colors import ThemeError, read_colors

THEME_DIR, FC, EC, BASE, PREFIX = sys.argv[1:6]
try:
    places = read_colors(os.path.join(THEME_DIR, 'colors.toml'))
except ThemeError as e:
    key, values, place, line = e.args
    text = T(key, *values)
    print(T('theme.error_at', text, place, line) if place else text, file=sys.stderr)
    sys.exit(1)
for place, items in places:
    if place in ('all', 'highlights', 'annotations'):
        kind = {'all': 'tokenColorings', 'highlights': 'highlights', 'annotations': 'annotations'}[place]
        path = os.path.join(FC, f'{PREFIX}-{kind}.xml')
    elif place.endswith(' extra'):
        # names NetBeans does not declare for the language: only accepted in the Defaults folder
        path = os.path.join(EC, 'Editors', place[:-6], 'FontsColors', BASE, 'Defaults', 'nbkit-theme-tokenColorings.xml')
    else:
        path = os.path.join(EC, 'Editors', place, 'FontsColors', BASE, f'{PREFIX}-tokenColorings.xml')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(HDR + '<fontcolors>\n' + ''.join(f'    {x}\n' for _, x in items) + '</fontcolors>\n')
