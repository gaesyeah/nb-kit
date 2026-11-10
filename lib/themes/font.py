"""The editor font of a color file: "json" (to carry it to the new profile on install) or "text" (to tell it on
uninstall). Prints nothing when the file has no font."""
import json
import sys

from nbfiles import default_font

mode, path = sys.argv[1], sys.argv[2]
font = default_font(path)
if font:
    print(json.dumps(font) if mode == 'json' else ' '.join(font[k] for k in ('name', 'size') if font.get(k)))
