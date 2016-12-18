# This installs Arch kernel into a newly created temporary directory.
#
# How to use:
# 1. Run.
# 2. Look in /tmp. There should be a new tmp.* directory there (let's call it $DIR).
# 3. Copy $DIR to a new Btrfs snapshot.
# 4. Add the new boot option. See install.sh for an example.

install_log=`mktemp`
(
  set -x

  umask 022
  dir=`mktemp -d`
  mkdir $dir/{r,u,w}
  mount {-t,}overlay -olowerdir=/,upperdir=$dir/u,workdir=$dir/w $dir/r
  rm -fr $dir/r/{usr/lib/firmware,var/cache/pacman/pkg}
  systemd-nspawn -D$dir/r --bind=/usr/lib/modules/pkg:/mnt bash -c \
    'for i in /mnt/*; do tar xOJf $i .PKGINFO; done | grep ^pkgname | cut "-d " -f3 | xargs pacman --noconfirm -Rdd
     pacman --noconfirm -Syu linux nvidia{,-libgl,-settings}'
  umount $dir/r
  (
    cd $dir
    mkdir pkg
    rm -f u/var/cache/pacman/pkg/nvidia-[0-9]*
    mv u/usr/lib/{firmware,modules/*} .
    mv u/boot/initramfs-linux-fallback.img initrd.lz
    mv u/boot/vmlinuz-linux vmlinuz.efi
    mv u/var/cache/pacman/pkg/{libglvnd,libxnvctrl,nvidia}-* pkg/
    rm -fr r u w
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
