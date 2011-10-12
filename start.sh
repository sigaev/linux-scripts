disk=/dev/xvdf
mount=/mnt
stage3=http://mirror.mcs.anl.gov/pub/gentoo/releases/x86/current-stage3/stage3-i686-20111004.tar.bz2
portage=http://mirror.mcs.anl.gov/pub/gentoo/snapshots/portage-latest.tar.xz
git=http://sigaev.com/about/laptop/.git

which git || sudo yum -y install git
sudo mkfs.ext4 -m0 $disk
sudo mount $disk $mount || exit 1

(
	cd /tmp
	rm -f _install.sh
	wget -q $git/info/_install.sh
	sudo disk=$disk mount=$mount stage3=$stage3 portage=$portage git=$git \
		setsid nohup bash _install.sh </dev/null >/dev/null 2>&1 &
)
