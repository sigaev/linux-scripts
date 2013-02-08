mail() {
	local div=------------------------------------------------------------------------------
	{
		echo -e "To: $mail\nSubject: Gentoo $arch build $1\n"
		[[ $2 ]] && echo -e "Try in a terminal: gentoo `basename $2`\nDownload: $2\n$div"
		tail -500 err
		echo $div
		tail -500 out
		echo $div
		dmesg | tail -100
	} | sendmail -t
}

umask 022
cd $mount
rm -fr root
mkdir root
(
	cd root
	git clone -n $git_root etc
	wget -qO- $stage3 | tar xjp
	wget -qO- $txz_portage | tar xJpC var
	cd etc
	cp /etc/resolv.conf .
	cp ../usr/share/zoneinfo/America/New_York localtime
	ln -sfn `readlink portage/make.profile | sed s,usr,var,` portage/make.profile
	cp -a /dev/shm/*-linux-scripts-* .git/scripts
	cp -a /dev/shm/*-linux-config-* .git/scripts/config
	chmod -R go-w .git/scripts
	chown -R root:root .git/scripts
	echo \* >>.git/info/exclude
	. .git/scripts/_emerge_setup.sh

	cd ..
	mount -t proc{,,}
	mount -B {/,}dev
	if mountpoint -q /dev/shm; then
		mount -B {/,}dev/shm
	else
		mount -B {/,}run
		mount -B {/,}run/shm
	fi
	mount -B {/,}dev/pts
	[[ 6000000 -lt `sed -n '/MemTotal/{s,[^0-9],,g;p}' /proc/meminfo` ]] \
		&& mount -t tmpfs{,} var/tmp
	chroot . bash etc/.git/scripts/_emerge.sh
	e=$?
	mountpoint -q var/tmp && umount var/tmp
	if mountpoint -q /dev/shm; then
		umount dev{/pts,/shm,} proc
	else
		umount dev{/pts,} run{/shm,} proc
	fi
	exit $e
) >out 2>err && (
	for i in out err; do xz -c9 $i >root/var/log/install.$i.xz; done
	file=`date +%Y-%m-%d`-$arch.sfs
	root/lib/ld-2* --library-path root/lib:root/usr/lib root/usr/bin/mksquashfs \
		root $file -no-progress -comp xz >out 2>>err || exit 1
	(su -c "root/usr/local/bin/aws put 'x-amz-acl: public-read' 'x-amz-storage-class: REDUCED_REDUNDANCY' $user/linux/$file $file" \
			ec2-user && \
		wget -S --spider s3.amazonaws.com/$user/linux/$file 2>&1 | \
			sed -n "/ETag/{s:[^\"]*\"::;s:\":  $file:;p}" | \
			md5sum -c) >>out 2>>err || exit 1
	mail SUCCEDED s3.amazonaws.com/$user/linux/$file
	exit 0
) || mail FAILED
rm -fr /dev/shm/*-linux-{config,scripts}-*
[[ ${arch/-j} != $arch ]] || shutdown -h now
