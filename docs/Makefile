html :
	mkdir -p html/upgrade
	for f in *.pod upgrade/*.pod; do g=`echo $f|sed 's/\.pod//'`;pod2html $f > html/$g.html; done
	cp ../CHANGES ../README ../LICENCE html/

clean :
	rm -f *.tmp *~
