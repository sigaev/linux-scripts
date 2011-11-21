d=`perl -e 'require SVN::Core' 2>&1 | head -1 | sed 's/.*\(\/usr[^ ]*SVN\).*/\1/'`
[[ $d ]] && find $d -name \*.so | while read f; do
	d=`dirname $f` f=`basename $f`
	mv $d/{,lib}$f
	ld -s -shared -o$d/$f -{L,rpath}=$d -l${f%.so} -lsvn_swig_perl-1
done
