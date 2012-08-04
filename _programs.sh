for i in $git_prg; do
	d=/dev/shm/_gentoo
	git clone $i $d
	(cd $d && make)
	rm -fr $d
done
