# This installs Arch kernel into a newly created temporary directory.
#
# How to use:
# 1. Update "nvidia" below.
# 2. Run.
# 3. Look in /tmp. There should be a new tmp.* directory there (let's call it $DIR).
# 4. Copy $DIR to a new Btrfs snapshot.
# 5. Add the new boot option. See install.sh for an example.

install_log=`mktemp`
(
  set -x
  nvidia=http://us.download.nvidia.com/XFree86/Linux-x86_64/375.26/NVIDIA-Linux-x86_64-375.26.run

  umask 022
  dir=`mktemp -d`
  mkdir $dir/{r,u,w}
  mount {-t,}overlay -olowerdir=/,upperdir=$dir/u,workdir=$dir/w $dir/r
  rm -f $dir/r/usr/lib/firmware
  systemd-nspawn -D$dir/r pacman --noconfirm -Syu linux
  umount $dir/r
  (
    cd $dir
    mv u/usr/lib/{firmware,modules/*} .
    mv u/boot/initramfs-linux-fallback.img initrd.lz
    mv u/boot/vmlinuz-linux vmlinuz.efi
    rm -fr r u w
    mkdir pkg
    curl -Lopkg/`basename $nvidia` $nvidia
  )

  echo $dir
) 2>&1 | tee $install_log
(
  umask 022
  install_log_xz=`tail -n1 $install_log`/install.log.xz
  xz -c $install_log >$install_log_xz
  rm -f $install_log
  chmod 755 `dirname $install_log_xz`
)
