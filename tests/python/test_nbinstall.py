"""lib/themes/nbinstall.py: where the NetBeans installation is, from the userdir log."""
import unittest

import helpers
import nbinstall

LOG = '''  Product Version         = Apache NetBeans IDE 31
  Installation            = /opt/netbeans/nb
                            /opt/netbeans/ergonomics
                            /opt/netbeans/ide
  Boot & Ext. Classpath   = /usr/lib/jvm/x
'''


class Clusters(unittest.TestCase):
    def test_runs_the_nbkit_of_this_folder(self):
        self.assertTrue(nbinstall.__file__.startswith(helpers.LIB))

    def test_every_cluster_of_the_installation_line(self):
        self.assertEqual(nbinstall.logged_clusters(LOG), ['/opt/netbeans/nb', '/opt/netbeans/ergonomics', '/opt/netbeans/ide'])
        self.assertEqual(nbinstall.logged_clusters('nothing here'), [])

    def test_flatpak_paths_go_to_the_flatpak_folders(self):
        out = nbinstall.host_paths(['/app/netbeans/nb', '/opt/netbeans/ide'])
        self.assertEqual(out, [h + '/nb' for h in nbinstall.FLATPAK_HOSTS] + ['/opt/netbeans/ide'])


if __name__ == '__main__':
    unittest.main()
