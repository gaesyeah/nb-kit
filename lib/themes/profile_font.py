"""Prints the editor font set in a profile color file (to tell it on uninstall)."""
import sys, xml.dom.minidom as M
for e in M.parse(sys.argv[1]).getElementsByTagName('fontcolor'):
    f = e.getElementsByTagName('font')
    if e.getAttribute('name') == 'default' and f and f[0].getAttribute('name'):
        print(f[0].getAttribute('name'), f[0].getAttribute('size'))
