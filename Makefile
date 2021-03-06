#
# Makefile that is used when generating the Debian package
#

PACKAGENAME = metno-metamod-2.14

OSVERSION := $(shell lsb_release -rs)

DEBIANDIR = $(CURDIR)/debian/$(PACKAGENAME)

DESTDIR = $(DEBIANDIR)/opt/$(PACKAGENAME)

BUILDDIR = $(CURDIR)/lib-build

# this only works locally, not when checked out from svn
VERSION: debian/changelog
	debian/checkVersion.pl -u

LIBDEPS="local/lib/perl5:local/lib/perl5/x86_64-linux-gnu-thread-multi"

.PHONY: test
# so "make test" is not dependent of the "test" directory
test:
	PERL5LIB="local/lib/perl5:local/lib/perl5/x86_64-linux-gnu-thread-multi" ./run_automatic_tests.pl

apidocs:
	mkdir -p docs/html/api
	perl -MPod::Simple::HTMLBatch -e Pod::Simple::HTMLBatch::go \
	"catalyst/lib:common/lib:base/scripts:common/scripts:virtualenv:lsconf" \
	docs/html/api
	cp docs/apidocs.css docs/html/api/_blkbluw.css
# ok, the last one is a hack... write perl script later

# needs to maintain different snapshot files per OS version - FIXME
cpanfile.snapshot:
	ln -s cpanfile.snapshot.$(OSVERSION) cpanfile.snapshot

deps: cpanfile.snapshot
	vendor/bin/carton install

bundle: cpanfile.snapshot
	vendor/bin/carton bundle --no-fatpack

deployment: cpanfile.snapshot
	vendor/bin/carton install --deployment --cached

# Build the actual debian package
# It is a requirement that this should not produce any svn diffs
debian_package: deployment apidocs
	debian/checkVersion.pl -u

	fakeroot mkdir -p $(DESTDIR)

	fakeroot rsync -aC $(CURDIR)/app/* $(DESTDIR)/app
	fakeroot rsync -aC $(CURDIR)/base/* $(DESTDIR)/base
	fakeroot rsync -aC $(CURDIR)/catalyst/* $(DESTDIR)/catalyst
	fakeroot rsync -aC $(CURDIR)/common/* $(DESTDIR)/common
	fakeroot rsync -aC $(CURDIR)/docs/* $(DESTDIR)/docs
	fakeroot rsync -aC $(CURDIR)/harvest/* $(DESTDIR)/harvest
	fakeroot rsync -aC $(CURDIR)/upload/* $(DESTDIR)/upload
	fakeroot rsync -aC $(CURDIR)/thredds/* $(DESTDIR)/thredds
	fakeroot rsync -a  $(CURDIR)/local/* $(DESTDIR)/local
	fakeroot rsync -aC $(CURDIR)/activate_env $(DESTDIR)/
	fakeroot rsync -aC $(CURDIR)/LICENCE $(DESTDIR)/
	fakeroot rsync -aC $(CURDIR)/README $(DESTDIR)/
	fakeroot rsync -aC $(CURDIR)/VERSION $(DESTDIR)/
	fakeroot rsync -aC $(CURDIR)/install_jobs.sh $(DESTDIR)/
	fakeroot rsync -aC $(CURDIR)/lsconf $(DESTDIR)/
	fakeroot rsync -aC $(CURDIR)/virtualenv.pl $(DESTDIR)/

	fakeroot dh_fixperms
	fakeroot dh_gencontrol
	fakeroot dh_md5sums

	dpkg-deb --build debian/$(PACKAGENAME) .
	dpkg-genchanges -b -u. > ./$(PACKAGENAME).changes

# Cleanup everything done by 'debian_package'
debian_clean:
	rm -f *.changes
	rm -f *.deb
	rm -f $(CURDIR)/debian/files
	rm -rf $(DESTDIR)
