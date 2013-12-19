#
# Makefile that is used when generating the Debian package
#

PACKAGENAME = metno-metamod-2.13

DEBIANDIR = $(CURDIR)/debian/$(PACKAGENAME)

DESTDIR = $(DEBIANDIR)/opt/$(PACKAGENAME)

BUILDDIR = $(CURDIR)/lib-build

# this only works locally, not when checked out from svn
VERSION: debian/changelog
	debian/checkVersion.pl -u

deps:
	carton install

bundle:
	carton bundle --no-fatpack

deployment:
	carton install --deployment --cached

# Build the actual debian package
# It is a requirement that this should not produce any svn diffs
debian_package: deployment
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
