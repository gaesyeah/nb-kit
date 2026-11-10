"""With NetBeans open: checks that the coloring module loaded and that the profile and look and feel are selected.
Exits 0 (ok), 1 (reinstalling fixes it) or 2 (it does not), like the check of every module."""
import os
import re
import sys

from nbfiles import current_laf, current_profile
from text import T

G, R, D, N = (os.environ.get(k, '') for k in ('NBKIT_G', 'NBKIT_R', 'NBKIT_D', 'NBKIT_N'))


def line(color, label, msg):
    """the same "  ok       ..." lines as res in lib/registry.sh"""
    print('  ' + color + T(label).ljust(9) + N + msg)


def main():
    ud = sys.argv[1]
    profile, laf_class = os.environ['NBKIT_THEME_PROFILE'], os.environ['NBKIT_THEME_LAF']
    with open(os.path.join(ud, 'var', 'log', 'messages.log'), errors='replace') as f:
        lines = f.read().splitlines()
    good = True

    def res(ok, msg):
        nonlocal good
        good = good and ok
        line(G if ok else R, 'cli.res_ok' if ok else 'cli.res_problem', msg)

    loaded = any(re.match(r'^\s+nbkit\.colors \[', ln) for ln in lines)
    bad = [ln.strip() for ln in lines if ('nbkit.colors' in ln or 'nbkit/colors' in ln)
           and re.search(r'could not|cannot|Exception|SEVERE|disabled|requires', ln)]
    if not any('Turning on modules' in ln for ln in lines) and not bad:
        line(D, 'cli.res_info', T('theme.check_not_listed'))
    else:
        res(loaded and not bad, T('theme.check_loaded') if loaded else T('theme.check_missing'))
    for b in bad[:10]:
        print('           ' + b)
    prof = current_profile(ud)
    res(prof == profile and os.path.isdir(os.path.join(ud, 'config', 'Editors', 'FontsColors', profile)),
        T('theme.check_profile', prof or T('theme.check_default')))
    laf = current_laf(ud)
    res(laf == laf_class, T('theme.check_laf', laf or T('theme.check_default')))
    fixable = not any(re.search(r'requires|Java', b) for b in bad)
    sys.exit(0 if good else (1 if fixable else 2))


main()
