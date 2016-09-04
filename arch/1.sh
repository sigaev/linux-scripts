(
  host=lug.mtu.edu
  url=$host/archlinux/iso/2016.08.01/archlinux-bootstrap-2016.08.01-x86_64.tar.gz
  mounts="proc dev sys etc/resolv.conf"
  wifi=wlp3s0

  cd `mktemp -d`
  wget -qO- $url | tar xz
  cd *
  dir=`mktemp -dp tmp`
  mount {-t,}tmpfs $dir
  sed -i /$host/s,^.,, etc/pacman.d/mirrorlist
  sed -i 's,^SigLevel.*,SigLevel = Optional TrustAll,' etc/pacman.conf
  for i in $mounts; do mount -B {/,}$i; done
  chroot . bash <(cat <<EOF
    pacman-key --init
    pacstrap $dir base
EOF
  )
  while true; do
    kills=`find /proc -maxdepth 2 -name root | xargs ls -Udo 2>/dev/null | grep tmp | cut -d/ -f3`
    if [[ -z $kills ]]; then break; fi
    kill $kills
  done
  mkdir /$dir
  mount -M {,/}$dir
  umount $mounts && cd .. && rm -fr `pwd`

  cd /$dir
  cat >etc/systemd/system/kexec-reload.service <<EOF
[Unit]
Description=restart the current kernel
Documentation=man:kexec(8)
DefaultDependencies=no
Before=shutdown.target umount.target final.target

[Service]
Type=oneshot
ExecStart=/usr/bin/kexec -l /boot/vmlinuz.efi --initrd=/boot/initrd.lz --reuse-cmdline

[Install]
WantedBy=kexec.target
EOF
  for i in $mounts; do mount -B {/,}$i; done
  chroot . bash <(cat <<EOF
    pacman-key --populate archlinux
    pacman --noconfirm -Syu
    pacman --noconfirm -S iw wpa_supplicant ntp alsa-utils base-devel vim xfce4 xorg-server kexec-tools git cpio wget xf86-input-libinput
    systemctl enable ntpd wpa_supplicant@$wifi systemd-networkd kexec-reload
    groupadd -g 5000 eng
    useradd -mg eng -u 172504 sigaev
    (
      cd /tmp
      curl -Ls https://github.com/sigaev/nvidia/tarball/HEAD | tar xz
      cd sigaev-nvidia-*
      install -m755 xorg.conf /etc/X11/xorg.conf
      make
      cd /usr/lib64
      tar c * | tar xC ../lib
      cd /usr/lib/opengl/nvidia/lib
      mv * /usr/lib/
      cd ../extensions
      mv * /usr/lib/xorg/modules/extensions/

      cd /tmp
      curl -Ls https://github.com/sigaev/fonts-windows/tarball/HEAD | tar xz
      cd sigaev-fonts-windows-*
      make
    )
    rm -fr /usr/lib{64,/opengl} /tmp/sigaev-{nvidia,fonts-windows}-*
EOF
  )
  while true; do
    kills=`find /proc -maxdepth 2 -name root | xargs ls -Udo 2>/dev/null | grep tmp | cut -d/ -f3`
    if [[ -z $kills ]]; then break; fi
    kill $kills
  done
  umount $mounts
  mv lib/modules{,~}
  ln -sfn /boot lib/modules
  ln -sfn /mnt/secret/etc/wpa_supplicant/wpa_supplicant.conf etc/wpa_supplicant/wpa_supplicant-$wifi.conf
  ln -sfn ../usr/share/zoneinfo/America/New_York etc/localtime
  cat >>etc/fstab <<EOF
LABEL=root /     auto  noatime,ssd,discard,compress=zlib  0 1
LABEL=home /mnt  auto  noatime,ssd,discard,compress=zlib  0 1
EOF
  cat >etc/systemd/network/wireless.network <<EOF
[Match]
Name=$wifi

[Network]
DHCP=ipv4
EOF
  cp usr/lib/systemd/system/getty\@.service etc/systemd/system/autologin\@.service
  (
    cd etc/systemd/system
    ln -sfn /etc/systemd/system/autologin\@.service getty.target.wants/getty\@tty1.service
    git apply <<EOF
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
