#
# Makefile that is used when generating the Debian package
#

PACKAGENAME = metno-metamod-2.10

DEBIANDIR = $(CURDIR)/debian/$(PACKAGENAME)

DESTDIR = $(DEBIANDIR)/opt/$(PACKAGENAME)

BUILDDIR = $(CURDIR)/lib-build

# Build the actual debian package
debian_package:
	fakeroot mkdir -p $(DESTDIR)

	fakeroot rsync -aC $(CURDIR)/app/* $(DESTDIR)/app
	fakeroot rsync -aC $(CURDIR)/base/* $(DESTDIR)/base
	fakeroot rsync -aC $(CURDIR)/catalyst/* $(DESTDIR)/catalyst
	fakeroot rsync -aC $(CURDIR)/common/* $(DESTDIR)/common
	fakeroot rsync -aC $(CURDIR)/config/* $(DESTDIR)/config
	fakeroot rsync -aC $(CURDIR)/docs/* $(DESTDIR)/docs
	fakeroot rsync -aC $(CURDIR)/harvest/* $(DESTDIR)/harvest
	fakeroot rsync -aC $(CURDIR)/upload/* $(DESTDIR)/upload

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


	