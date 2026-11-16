"""Writes tests/expected/netbeans-fod.txt from a NetBeans installation: the modules nbkit must not depend on, because
NetBeans' Features on Demand can keep them from loading, and a module that depends on them would not load either.

  python3 tests/python/netbeans_fod.py <netbeans folder> > tests/expected/netbeans-fod.txt
  python3 tests/python/netbeans_fod.py --check <list> <manifest.mf>...   (tests/engine.sh: prints each bad dependency)

Run it again when NetBeans changes version, and commit the list (tests/engine.sh checks the src/*/manifest.mf against it).

How NetBeans decides (its source, apache/netbeans): the "ergonomics" cluster ships config/Modules/<module>.xml with
enabled=false for the modules of the features not activated yet (Java SE, Java EE, PHP...), so a new userdir starts
with them off. When a module is enabled, ModuleManager enables its autoload dependencies by itself, but a dependency
that is a regular module and is off makes the enable fail ("The module X would also need to be installed"). So a module
is listed when it is one of those, or when anything it needs, through autoloads, is one of those.
"""
import glob
import os
import re
import sys
import zipfile


def manifest(path):
    try:
        text = zipfile.ZipFile(path).read('META-INF/MANIFEST.MF').decode('utf-8', 'replace')
    except (OSError, KeyError, zipfile.BadZipFile):
        return None
    return re.sub(r'\r?\n ', '', text)


def cnb(spec):
    """org.netbeans.modules.csl.api/2 > 2.0 -> org.netbeans.modules.csl.api"""
    return re.split(r'[\s/>=]', spec.strip())[0]


def modules(nb):
    """{code name base: (regular module, [dependencies])} and the regular modules Features on Demand ships off"""
    found, off = {}, set()
    for xml in glob.glob(os.path.join(nb, '*', 'config', 'Modules', '*.xml')):
        text = open(xml, encoding='utf-8').read()
        cluster = os.path.dirname(os.path.dirname(os.path.dirname(xml)))
        if os.path.basename(cluster) == 'ergonomics':
            if re.search(r'name="enabled">false', text):
                off.add(os.path.basename(xml)[:-4])
            continue
        jar = re.search(r'name="jar">([^<]+)', text)
        m = manifest(os.path.join(cluster, jar.group(1))) if jar else None
        name = re.search(r'^OpenIDE-Module: ([^\s/]+)', m or '', re.M)
        if not name:
            continue
        deps = re.search(r'^OpenIDE-Module-Module-Dependencies: (.*)$', m, re.M)
        regular = not re.search(r'name="autoload">true', text)
        found[name.group(1)] = (regular, os.path.basename(xml)[:-4], [cnb(d) for d in deps.group(1).split(',')] if deps else [])
    return found, off


def risky(found, off):
    """the modules whose dependencies (themselves included) reach a regular module that starts off"""
    memo = {}

    def reaches(name, path):
        if name in memo:
            return memo[name]
        if name not in found or name in path:
            return False
        regular, file, deps = found[name]
        memo[name] = (regular and file in off) or any(reaches(d, path | {name}) for d in deps)
        return memo[name]
    return sorted(n for n in found if reaches(n, frozenset()))


def version(nb):
    m = manifest(os.path.join(nb, 'platform', 'lib', 'boot.jar')) or ''
    v = re.search(r'^OpenIDE-Module-Implementation-Version: (\S+)', m, re.M)
    return v.group(1) if v else 'unknown'


def check(listed, manifests):
    """'<module folder>: <dependency>' for each dependency of the manifests that is in the list"""
    off = {line.strip() for line in open(listed, encoding='utf-8') if line.strip() and not line.startswith('#')}
    for mf in manifests:
        text = re.sub(r'\n ', ' ', open(mf, encoding='utf-8').read())
        deps = re.search(r'^OpenIDE-Module-Module-Dependencies:(.*)$', text, re.M)
        for d in deps.group(1).split(',') if deps else []:
            if cnb(d) in off:
                print(os.path.basename(os.path.dirname(os.path.abspath(mf))) + ': ' + cnb(d))


if __name__ == '__main__' and sys.argv[1] == '--check':
    check(sys.argv[2], sys.argv[3:])
elif __name__ == '__main__':
    nb = sys.argv[1]
    found, off = modules(nb)
    print('# Modules nbkit must not depend on: Features on Demand can keep them (or a regular module they need) off')
    print('# in a new userdir, and then a module depending on them does not load. Written by tests/python/netbeans_fod.py')
    print('# from NetBeans ' + version(nb) + '; checked by tests/engine.sh. Run it again when NetBeans changes version.')
    for n in risky(found, off):
        print(n)
