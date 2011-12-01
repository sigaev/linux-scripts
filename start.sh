git=http://sigaev.com/programs/linux/root/.git

wget -qO/dev/shm/config $git/scripts/config
. /dev/shm/config
which git || sudo yum -y install git
sudo mkfs.ext4 -m0 $disk
sudo mount $disk $mount || exit 1
wget -qO/dev/shm/_install.sh $git/scripts/_install.sh
sudo arch=$arch disk=$disk mount=$mount stage3=$stage3 portage=$portage \
	user=$user name="$name" cfg=$cfg prg="$prg" git=$git \
	setsid nohup bash /dev/shm/_install.sh </dev/null >/dev/null 2>&1 &
