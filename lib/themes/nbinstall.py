"""The NetBeans installation a userdir runs with: its clusters, its jars and the base color profile declared in
the layers of its modules (what the theme profile is a copy of)."""
import glob
import os
import re
import xml.dom.minidom as M
import zipfile

TYPE_ATTR = 'nbeditor-settings-ColoringType'
FLATPAK_HOSTS = ['/var/lib/flatpak/app/org.apache.netbeans/current/active/files/netbeans',
                 os.path.expanduser('~/.local/share/flatpak/app/org.apache.netbeans/current/active/files/netbeans')]
USUAL_PLACES = ['/usr/lib/apache-netbeans', '/usr/share/netbeans', '/opt/netbeans', '/opt/apache-netbeans',
                os.path.expanduser('~/.local/opt/netbeans'), os.path.expanduser('~/netbeans'),
                '/snap/netbeans/current/netbeans'] + FLATPAK_HOSTS


def is_cluster(d):
    return os.path.isdir(os.path.join(d, 'modules'))


def logged_clusters(log_text):
    """the clusters the log lists after "Installation =" (the first line and the paths below it)"""
    lines = log_text.splitlines()
    found = []
    for i, line in enumerate(lines):
        m = re.match(r'\s*Installation\s*=\s*(\S.*)$', line)
        if m:
            found = [m.group(1).strip()]
            for nxt in lines[i + 1:]:
                if '=' in nxt or not nxt.strip().startswith('/'):
                    break
                found.append(nxt.strip())
    return found


def host_paths(paths):
    """Flatpak logs the paths inside its sandbox (/app/netbeans): the files are in the Flatpak folders"""
    out = []
    for d in paths:
        if d.startswith('/app/netbeans/'):
            out += [h + d[len('/app/netbeans'):] for h in FLATPAK_HOSTS]
        else:
            out.append(d)
    return out


def clusters(ud):
    """NB_HOME, or what the userdir log says, or the usual places"""
    env = os.environ.get('NB_HOME')
    if env:
        found = [d for d in glob.glob(os.path.join(env, '*')) if is_cluster(d)]
        if found:
            return found
    log = os.path.join(ud, 'var', 'log', 'messages.log')
    if os.path.exists(log):
        with open(log, errors='replace') as f:
            found = [d for d in host_paths(logged_clusters(f.read())) if is_cluster(d)]
        if found:
            return found
    return [d for root in USUAL_PLACES for d in glob.glob(os.path.join(root, '*')) if is_cluster(d)]


class Jars:
    """the jars of the installation, opened once"""
    def __init__(self, ud):
        self.paths = []
        for c in clusters(ud):
            self.paths += glob.glob(os.path.join(c, 'modules', '*.jar')) + glob.glob(os.path.join(c, 'core', '*.jar'))
        self.zips = {}

    def zip(self, path):
        if path not in self.zips:
            try:
                self.zips[path] = zipfile.ZipFile(path)
            except Exception:
                self.zips[path] = None
        return self.zips[path]

    def read(self, res, first=None):
        """a resource, from the jar given first or from any of them"""
        for j in ([first] if first else []) + self.paths:
            z = self.zip(j)
            if z is not None and res in z.namelist():
                return z.read(res)
        return None

    def layers(self, jar):
        """the layer files of a module jar"""
        z = self.zip(jar)
        if z is None:
            return []
        out = []
        try:
            mf = z.read('META-INF/MANIFEST.MF').decode('utf-8', 'replace').replace('\r\n', '\n').replace('\n ', '')
            m = re.search(r'^OpenIDE-Module-Layer:\s*(\S+)', mf, re.M)
            if m and m.group(1) in z.namelist():
                out.append(m.group(1))
        except KeyError:
            pass
        if 'META-INF/generated-layer.xml' in z.namelist():
            out.append('META-INF/generated-layer.xml')
        return out


def base_profile(jars, base):
    """[(mime, file name, type, content)] of the color profile <base> (folder name) as the modules declare it"""
    found = []

    def walk(node, path, jar, layer):
        for c in node.childNodes:
            if c.nodeType != 1:
                continue
            if c.tagName == 'folder':
                walk(c, path + [c.getAttribute('name')], jar, layer)
            elif c.tagName == 'file' and len(path) >= 4 and path[0] == 'Editors' and path[-3:] == ['FontsColors', base, 'Defaults']:
                name, url = c.getAttribute('name'), c.getAttribute('url')
                if not url or name.endswith('_hidden'):
                    continue
                if url.startswith(('nbres:', 'nbresloc:')):
                    res = url.split(':', 1)[1].lstrip('/')
                else:
                    res = os.path.normpath(os.path.join(os.path.dirname(layer), url)).replace(os.sep, '/')
                data = jars.read(res, jar)
                if data is None:
                    continue
                typ = next((a.getAttribute('stringvalue') for a in c.getElementsByTagName('attr')
                            if a.getAttribute('name') == TYPE_ATTR), None)
                if typ is None:
                    typ = 'highlight' if name == 'editorColoring.xml' else 'token'
                found.append(('/'.join(path[1:-3]), name, typ, data))

    for j in jars.paths:
        for layer in jars.layers(j):
            try:
                doc = M.parseString(jars.zip(j).read(layer))
            except Exception:
                continue
            walk(doc.documentElement, [], j, layer)
    return found
