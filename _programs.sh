d=/dev/shm/_gentoo
rm -fr $d
for i in $tgz_prg; do
	mkdir $d
	wget -qO- $i | tar xzC $d
	(cd $d/* && exec make) || exit 1
	rm -fr $d
done
