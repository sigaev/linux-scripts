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
  kernel_pkg=`for i in /usr/lib/modules/pkg/*; do
                tar xOJf $i .PKGINFO
              done | grep ^pkgname | cut -d\  -f3 | xargs`
  systemd-nspawn -D$dir/r bash -c "pacman --noconfirm -Rdd $kernel_pkg
                                   pacman --noconfirm -Syu linux nvidia-390xx{,-settings}"
  umount $dir/r

  cd $dir
  mkdir pkg
  rm -f u/var/cache/pacman/pkg/nvidia-390xx-[0-9]*
  mv u/usr/lib/{firmware,modules/*} .
  mv u/boot/initramfs-linux-fallback.img initrd.lz
  mv u/boot/vmlinuz-linux vmlinuz.efi
  mv u/var/cache/pacman/pkg/{libxnvctrl,nvidia}-* pkg/
  rm -fr r u w

  systemd-nspawn -xD/ --bind-ro={/usr/lib/modules,$dir/pkg:/mnt} bash -c \
    "echo -e '\n'THIS COMMAND MUST REPLACE ALL OF THESE, WITHOUT DOWNLOADING ANYTHING: $kernel_pkg'\n'
     yes | pacman --confirm -U /mnt/*
     echo -e '\n'THIS COMMAND MUST REMOVE ALL THE PACKAGES JUST INSTALLED, AND RESTORE ALL OF THESE, WITHOUT DOWNLOADING ANYTHING: $kernel_pkg'\n'
     yes | pacman --confirm -U /usr/lib/modules/pkg/*"

  echo $dir
) 2>&1 | tee $install_log
(
  umask 022
  install_log_xz=`tail -n1 $install_log`/install.log.xz
  xz -c $install_log >$install_log_xz
  rm -f $install_log
  chmod 755 `dirname $install_log_xz`
)
