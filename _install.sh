(
	cd $mount
	git clone -n $git etc
	mkdir etc/.git/scripts
	echo \* >>etc/.git/info/exclude
	git clone --bare {$git,etc/.git}/scripts/.git
	(cd etc/.git/scripts && git reset --hard)
	wget -qO- $stage3 | tar xjp
	wget -qO- $portage | tar xJpC var
	ln -sfn `readlink etc/make.profile | sed s/usr/var/` etc/make.profile
	cp {/,}etc/resolv.conf

	mount -t proc{,,}
	mount -R {/,}dev
	chroot . /bin/bash etc/.git/scripts/_gentoo.sh
	umount dev{/pts,/shm,} proc
) >$mount/out 2>$mount/err
umount $mount
shutdown -h now
