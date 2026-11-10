"""Helpers for the data files of the themes and tools (theme.toml, tool.toml): texts by language and required keys."""
import os

LANG = os.environ.get('NBKIT_LANG', 'en')


def localized(value):
    """plain text, or a table by language: { en = "...", pt-BR = "..." } (the language, its family, English, the first)"""
    if isinstance(value, dict):
        return value.get(LANG) or value.get(LANG.split('-')[0]) or value.get('en') or next(iter(value.values()), '')
    return value if isinstance(value, str) else ''


def need(table, key, kind, error):
    """table[key], which must exist and be of the kind; otherwise error('missing'|'bad', key)"""
    value = table.get(key)
    if value is None:
        raise error('missing', key)
    if not isinstance(value, kind) or isinstance(value, bool):
        raise error('bad', key)
    return value
