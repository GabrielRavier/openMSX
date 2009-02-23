# $Id$
# Generates version include file.

from outpututils import createDirFor, rewriteIfChanged
from version import extractRevision, packageVersion, releaseFlag

import sys

def iterVersionInclude():
	revision = extractRevision()

	yield '// Automatically generated by build process.'
	yield 'const bool Version::RELEASE = %s;' % str(releaseFlag).lower()
	yield 'const std::string Version::VERSION = "%s";' % packageVersion
	yield 'const std::string Version::REVISION = "%s";' % revision

if len(sys.argv) == 2:
	rewriteIfChanged(sys.argv[1], iterVersionInclude())
else:
	print >> sys.stderr, \
		'Usage: python version2code.py VERSION_HEADER'
	sys.exit(2)
