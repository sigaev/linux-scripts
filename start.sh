[[ $1 ]] || exit 1

arch=$1
tgz_config=https://github.com/sigaev/linux-config/tarball/HEAD

umask 022
wget -qO- $tgz_config | tar xzC /dev/shm
cd /dev/shm/*-linux-config-*
. config
which git || sudo yum -y install git
wget -qO- $tgz_scripts | tar xzC ..
sudo arch=$arch mount=$mount stage3=$stage3 txz_portage=$txz_portage \
	user=$user name="$name" cfg=$cfg mail=$mail \
	tgz_prg="$tgz_prg" git_root=$git_root git_root_ssh=$git_root_ssh \
	setsid nohup sh -c 'bash ../*-linux-scripts-*/_install.sh &' \
	</dev/null >/dev/null 2>&1
