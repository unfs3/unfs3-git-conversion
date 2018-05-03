#!/usr/bin/python
# -*- coding: utf-8 -*-

import sys

authors = {
    # cvs2svn artifacts?
    '(no author)': 'Unknown Author <no author>',
    'root':  'Unknown Author <root>',
    'nobody': 'Unknown Author <nobody>',
    # actual persons
    'peter': 'Peter Åstrand <astrand@cendio.se>',
    'astrand': 'Peter Åstrand <astrand@cendio.se>',
    'derfian': 'Karl Mikaelsson <derfian@cendio.se>',
    '_cvs_pascal': 'Pascal Schmidt <unfs3-server@ewetel.net>',
}

try:
    print authors[sys.argv[1]]
except:
    print >>sys.stderr, "Failed to find author '%s'" % sys.argv[1]
    sys.exit(1)
