(
	umask 022
	cd $mount
	git clone -n $git etc
	git clone $git/scripts/.git etc/.git/scripts
	echo \* >>etc/.git/info/exclude
	wget -qO- $stage3 | tar xjp
	wget -qO- $portage | tar xJpC var
	ln -sfn `readlink etc/make.profile | sed s/usr/var/` etc/make.profile
	cp {/,}etc/resolv.conf

	mount -t proc{,,}
	mount -R {/,}dev
	chroot . /bin/bash etc/.git/scripts/_gentoo_emerge.sh
	umount dev{/pts,/shm,} proc
) >$mount/out 2>$mount/err
mount -roremount $mount
umount $mount
shutdown -h now
