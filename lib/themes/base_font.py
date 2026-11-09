"""Prints, as JSON, the editor font set in the base profile (it goes to the new profile)."""
import sys, json, xml.dom.minidom as M
for e in M.parse(sys.argv[1]).getElementsByTagName('fontcolor'):
    f = e.getElementsByTagName('font')
    if e.getAttribute('name') == 'default' and f and f[0].getAttribute('name'):
        print(json.dumps({k: v for k, v in f[0].attributes.items() if k in ('name', 'size', 'style')}))
