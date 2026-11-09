"""With NetBeans open: checks that the coloring module loaded and that the profile and look and feel are selected."""
import sys, os, re, xml.dom.minidom as M
from text import T
ud = sys.argv[1]
ok = True
def res(good, msg):
    global ok
    ok = ok and good
    color = os.environ.get('NBKIT_G' if good else 'NBKIT_R', '')
    print('  ' + color + T('cli.res_ok' if good else 'cli.res_problem').ljust(9) + os.environ.get('NBKIT_N', '') + msg)
log = os.path.join(ud, 'var', 'log', 'messages.log')
jar = os.path.join(ud, 'modules', 'nbkit-colors.jar')
text = open(log, errors='replace').read()
lines = text.splitlines()
loaded = any(re.match(r'^\s+nbkit\.colors \[', l) for l in lines)
bad = [l.strip() for l in lines if ('nbkit.colors' in l or 'nbkit/colors' in l)
       and re.search(r'could not|cannot|Exception|SEVERE|disabled|requires', l)]
listed = any('Turning on modules' in l for l in lines)
if not listed and not bad:
    print('  ' + os.environ.get('NBKIT_D', '') + T('cli.res_info').ljust(9) + os.environ.get('NBKIT_N', '') + T('theme.check_not_listed'))
else:
    res(loaded and not bad, T('theme.check_loaded') if loaded else T('theme.check_missing'))
for b in bad[:10]:
    print('           ' + b)
prof = None
attrs = os.path.join(ud, 'config', '.nbattrs')
if os.path.exists(attrs):
    for fo in M.parse(attrs).getElementsByTagName('fileobject'):
        if fo.getAttribute('name') == 'Editors':
            for a in fo.getElementsByTagName('attr'):
                if a.getAttribute('name') == 'currentFontColorProfile':
                    prof = a.getAttribute('stringvalue')
PROFILE, LAFCLASS = os.environ['NBKIT_THEME_PROFILE'], os.environ['NBKIT_THEME_LAF']
res(prof == PROFILE and os.path.isdir(os.path.join(ud, 'config', 'Editors', 'FontsColors', PROFILE)),
    T('theme.check_profile', prof or T('theme.check_default')))
laf = None
lp = os.path.join(ud, 'config', 'Preferences', 'laf.properties')
if os.path.exists(lp):
    for l in open(lp).read().splitlines():
        if l.startswith('laf='):
            laf = l[4:]
res(laf == LAFCLASS, T('theme.check_laf', laf or T('theme.check_default')))
fixable = not any(re.search(r'requires|Java', b) for b in bad)
sys.exit(0 if ok else (1 if fixable else 2))
