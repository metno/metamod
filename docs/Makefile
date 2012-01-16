html :
	mkdir -p html/upgrade
	for f in *.pod upgrade/*.pod; do g=`echo $f|sed 's/\.pod//'`;pod2html $f > html/$g.html; done

clean :
	rm -f *.tmp *~
