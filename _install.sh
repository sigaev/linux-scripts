umask 022
mkdir $mount/root
(
	cd $mount/root
	git clone -n $git etc
	wget -qO- $stage3 | tar xjp
	wget -qO- $portage | tar xJpC var
	cd etc
	cp /etc/resolv.conf .
	cp ../usr/share/zoneinfo/America/New_York localtime
	ln -sfn `readlink make.profile | sed s,usr,var,` make.profile
	git clone $git/scripts/.git .git/scripts
	echo \* >>.git/info/exclude
	echo /config >>.git/scripts/.git/info/exclude
	cp /dev/shm/config .git/scripts
	. .git/scripts/_emerge_setup.sh

	cd ..
	mount -t proc{,,}
	mount -R {/,}dev
	[[ 6000000 -lt `sed -n '/MemTotal/{s,[^0-9],,g;p}' /proc/meminfo` ]] \
		&& mount -t tmpfs{,} var/tmp
	chroot . bash etc/.git/scripts/_emerge.sh
	e=$?
	mountpoint -q var/tmp && umount var/tmp
	umount dev{/pts,/shm,} proc
	((! e))
) >$mount/out 2>$mount/err && (
	cd $mount
	for i in out err; do xz -c9 $i >root/var/log/install.$i.xz && rm -f $i; done
	file=`date +%Y-%m-%d`-$arch.sfs
	LD_LIBRARY_PATH=root/lib:root/usr/lib \
		root/usr/bin/mksquashfs root $file -comp xz >>out 2>>err
	md5sum $file >$file.md5
)
shutdown -h now
