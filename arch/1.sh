# This installs Arch into a newly created temporary directory.
#
# How to use:
# 1. Update "url" below.
# 2. Run.
# 3. Run "mount". There should be exactly one new mount (let's call it $MNT).
# 4. From AUR, install google-chrome and compiz.
# 5. Copy $MNT to a new Btrfs snapshot.
# 6. Add the new boot option. Example kernel command line:
#    BOOT_IMAGE=/boot/vmlinuz.efi audit=0 \
#    modprobe.blacklist=evbug,nouveau,nvidiafb root=LABEL=root \
#    rootflags=noatime,ssd,discard,compress=zlib,subvol=2016-09-03-arch-rw \
#    systemd.setenv=SUBVOL_BOOT=64-16.04
# 7. Think about how to eliminate step (4).

(
  host=lug.mtu.edu
  url=$host/archlinux/iso/2016.09.03/archlinux-bootstrap-2016.09.03-x86_64.tar.gz
  mounts="proc dev sys etc/resolv.conf"
  wifi=wlp3s0

  kill-chroot-processes() {
    while true; do
      kills=`find /proc -maxdepth 2 -name root | xargs ls -Udo 2>/dev/null | grep tmp | cut -d/ -f3`
      if [[ -z $kills ]]; then break; fi
      kill $kills
    done
  }

  cd `mktemp -d`
  wget -qO- $url | tar xz
  cd *
  dir=`mktemp -dp tmp`
  mount {-t,}tmpfs $dir
  keys_exist=false
  if [[ -e /etc/pacman.d/gnupg ]]; then
    keys_exist=true
    cp -a /etc/pacman.d/gnupg etc/pacman.d/
  fi
  sed -i /$host/s,^.,, etc/pacman.d/mirrorlist
  $keys_exist || sed -i 's,^SigLevel.*,SigLevel = Optional TrustAll,' etc/pacman.conf
  for i in $mounts; do mount -B {/,}$i; done
  chroot . bash <(cat <<EOF
    $keys_exist || pacman-key --init
    pacstrap $dir base
EOF
  )
  kill-chroot-processes
  mkdir /$dir
  mount -M {,/}$dir
  umount $mounts && cd .. && rm -fr `pwd`

  cd /$dir
  $keys_exist && cp -a /etc/pacman.d/gnupg etc/pacman.d/
  cat >etc/systemd/system/boot.mount <<EOF
[Unit]
Description=Boot Directory
DefaultDependencies=no
ConditionVirtualization=!container
Conflicts=umount.target
After=swap.target

[Mount]
What=LABEL=root
Where=/boot
Type=auto
Options=ro,noatime,ssd,discard,compress=zlib

[Install]
RequiredBy=usr-lib-modules.mount
EOF
  cat >etc/systemd/system/usr-lib-modules.mount <<EOF
[Unit]
Description=Modules Directory
DefaultDependencies=no
ConditionVirtualization=!container
Conflicts=umount.target
Before=local-fs.target umount.target kexec.target systemd-udev-trigger.service systemd-udevd.service
After=boot.mount

[Mount]
What=/boot/\${SUBVOL_BOOT}
Where=/usr/lib/modules
Options=bind

[Install]
RequiredBy=systemd-udevd.service
EOF
  cat >etc/systemd/system/kexec-reload.service <<EOF
[Unit]
Description=restart the current kernel
Documentation=man:kexec(8)
DefaultDependencies=no
Before=shutdown.target umount.target final.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash /var/tmp/kexec-reload

[Install]
WantedBy=kexec.target
EOF
  for i in $mounts; do mount -B {/,}$i; done
  chroot . bash <(cat <<EOF
    $keys_exist || pacman-key --populate archlinux
    pacman --noconfirm -Syu iw wpa_supplicant ntp alsa-utils base-devel vim \
                            xfce4 xorg-server kexec-tools git cpio wget \
                            xf86-input-libinput btrfs-progs graphviz xorg-xhost \
                            squashfs-tools rsync
    for i in linux; do
      pacman --noconfirm -Rs \$i --assume-installed \`pacman -Q \$i | tr \\  =\`
    done
    systemctl enable ntpd "wpa_supplicant@$wifi" systemd-networkd {boot,usr-lib-modules}.mount kexec-reload
    groupadd -g 5000 eng
    useradd -g eng -u 172504 sigaev
    for i in nvidia fonts-windows aws; do
    (
      cd /tmp
      curl -Ls https://github.com/sigaev/\$i/tarball/HEAD | tar xz
      cd sigaev-\$i-* && make && rm -fr \`pwd\`
    )
    done
EOF
  )
  kill-chroot-processes
  umount $mounts
  ln -sfn /mnt/secret/etc/wpa_supplicant/wpa_supplicant.conf \
                      etc/wpa_supplicant/wpa_supplicant-$wifi.conf
  ln -sfn ../usr/share/zoneinfo/America/New_York etc/localtime
  mkdir usr/lib/modules
  ln -sfn modules/firmware usr/lib/firmware
  cat >>etc/fstab <<EOF
none       /     auto  noatime,ssd,discard,compress=zlib              0 0
LABEL=home /home auto  noatime,ssd,discard,compress=zlib,subvol=arch  0 2
LABEL=home /mnt  auto  noatime,ssd,discard,compress=zlib              0 2
EOF
  cat >etc/systemd/network/wireless.network <<EOF
[Match]
Name=$wifi

[Network]
DHCP=ipv4
EOF
  cp usr/lib/systemd/system/getty\@.service \
         etc/systemd/system/autologin\@.service
  (
    cd etc/systemd/system
    ln -sfn /etc/systemd/system/autologin\@.service \
             getty.target.wants/getty\@tty1.service
    git apply <<'EOF'
diff --git a/autologin@.service b/autologin@.service
index 9b99f95..2c90aa5 100644
--- a/autologin@.service
+++ b/autologin@.service
@@ -30,7 +30,7 @@ ConditionPathExists=/dev/tty0
 
 [Service]
 # the VT is cleared by TTYVTDisallocate
-ExecStart=-/sbin/agetty --noclear %I $TERM
+ExecStart=-/sbin/agetty -a sigaev --noclear %I $TERM
 Type=idle
 Restart=always
 RestartSec=0
EOF
  )

  rm -fr var/cache/pacman/pkg/*
)
