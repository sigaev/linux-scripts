umask 022
mkdir $mount/root
(
	cd $mount/root
	git clone -n $git etc
	git clone $git/scripts/.git etc/.git/scripts
	echo \* >>etc/.git/info/exclude
	echo /config >>etc/.git/scripts/.git/info/exclude
	cp /dev/shm/config etc/.git/scripts
	wget -qO- $stage3 | tar xjp
	wget -qO- $portage | tar xJpC var
	ln -sfn `readlink etc/make.profile | sed s/usr/var/` etc/make.profile
	cp {/,}etc/resolv.conf
	cp usr/share/zoneinfo/America/New_York etc/localtime

	mount -t proc{,,}
	mount -R {/,}dev
	[[ x86_64 == `uname -m` ]] && mount -t tmpfs{,} var/tmp
	chroot . /bin/bash etc/.git/scripts/_emerge.sh
	mountpoint -q var/tmp && umount var/tmp
	umount dev{/pts,/shm,} proc
) >$mount/out 2>$mount/err
(
	cd $mount
	for i in out err; do xz -c9 $i >root/var/log/install.$i.xz && rm -f $i; done
	file=`date +%Y-%m-%d`-$arch.sfs
	LD_LIBRARY_PATH=root/lib:root/usr/lib \
		root/usr/bin/mksquashfs root $file -comp xz >>out 2>>err
	md5sum $file >$file.md5
)
shutdown -h now
