for i in $tgz_prg; do
	d=/dev/shm/_gentoo
	wget -qO- $i | tar xzC $d
	(cd $d/* && exec make) || exit 1
	rm -fr $d
done
