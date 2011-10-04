#
# Make file for building the Metamod database dependency package.
#

PACKAGENAME = metno-metamoddb-2.10

DEBIANDIR = $(CURDIR)/debian/$(PACKAGENAME)

# Build the actual debian package
debian_package:
	fakeroot mkdir -p $(DEBIANDIR)

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
	rm -rf $(DEBIANDIR)