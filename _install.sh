(
	cd $mount
	git clone $git etc
	rm -fr etc/{,.git/info/}*
	(cd etc/.git/info && wget -q $git/info/{exclude,world,_gentoo.sh})
	wget -qO- $stage3 | tar xjp
	wget -qO- $portage | tar xJpC var
	ln -sfn `readlink etc/make.profile | sed s/usr/var/` etc/make.profile
	cp {/,}etc/resolv.conf

	mount -t proc{,,}
	mount -R {/,}dev
	chroot . /bin/bash etc/.git/info/_gentoo.sh
	umount dev{/pts,/shm,} proc
) >$mount/out 2>$mount/err
umount $mount
shutdown -h now
