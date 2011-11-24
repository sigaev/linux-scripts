git=http://sigaev.com/programs/linux/root/.git
prg="
http://sigaev.com/programs/cryptmount/.git
http://sigaev.com/programs/fonts-windows/.git
http://sigaev.com/programs/switch-root/.git
"

. <(wget -qO- $git/scripts/config)
which git || sudo yum -y install git
sudo mkfs.ext4 -m0 $disk
sudo mount $disk $mount || exit 1

(
	cd /tmp
	rm -f _install.sh
	wget -q $git/scripts/_install.sh
	sudo disk=$disk mount=$mount stage3=$stage3 portage=$portage \
		user=$user name="$name" git=$git prg="$prg" arch=$arch \
		setsid nohup bash _install.sh </dev/null >/dev/null 2>&1 &
)
