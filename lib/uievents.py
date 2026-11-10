"""Events for the graphical interface (lib/gui): nbkit passes its file in NBKIT_UI_EVENTS; without it, nothing."""
import json
import os


def event(**data):
    """appends one event (one JSON object per line), the same format as ui_event in lib/terminal.sh"""
    path = os.environ.get('NBKIT_UI_EVENTS')
    if path:
        with open(path, 'a', encoding='utf-8') as f:
            f.write(json.dumps(data, ensure_ascii=False) + '\n')
